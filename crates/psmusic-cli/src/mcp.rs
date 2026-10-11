use psmusic_core::{
    build_timeline, export_midi, generate_script, parse_midi, parse_project_json, GeneratorOptions,
    Note, Output, Player, Project, ProjectFile, TimelineOptions, Track,
};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::fs;
use std::io::{self, BufRead, Write};
use std::path::{Path, PathBuf};
use std::sync::Mutex;

static LAST_FILE_PATH: Mutex<Option<PathBuf>> = Mutex::new(None);
static GLOBAL_PLAYER: Mutex<Option<Player>> = Mutex::new(None);

fn get_player() -> &'static Mutex<Option<Player>> {
    let mut lock = GLOBAL_PLAYER.lock().unwrap();
    if lock.is_none() {
        *lock = Some(Player::new());
    }
    drop(lock);
    &GLOBAL_PLAYER
}

fn resolve_path(provided: Option<String>) -> Result<PathBuf, String> {
    if let Some(p) = provided {
        let pb = PathBuf::from(&p);
        *LAST_FILE_PATH.lock().unwrap() = Some(pb.clone());
        Ok(pb)
    } else if let Some(last) = LAST_FILE_PATH.lock().unwrap().clone() {
        Ok(last)
    } else {
        let default_p = PathBuf::from("psmusic-project.json");
        *LAST_FILE_PATH.lock().unwrap() = Some(default_p.clone());
        Ok(default_p)
    }
}

fn load_project_from_path(path: &Path) -> Result<Project, String> {
    if !path.exists() {
        return Err(format!("File not found: {}", path.display()));
    }
    let content = fs::read_to_string(path).map_err(|e| format!("Read file error: {e}"))?;
    parse_project_json(&content)
}

fn save_project_to_path(path: &Path, project: &Project) -> Result<(), String> {
    let project_file = ProjectFile::new(project.clone());
    let json_str = serde_json::to_string_pretty(&project_file)
        .map_err(|e| format!("JSON serialize error: {e}"))?;
    fs::write(path, json_str).map_err(|e| format!("Write file error: {e}"))?;
    Ok(())
}

#[derive(Serialize, Deserialize)]
struct JsonRpcRequest {
    jsonrpc: String,
    id: Option<Value>,
    method: String,
    #[serde(default)]
    params: Value,
}

pub fn run_mcp_server() -> io::Result<()> {
    eprintln!("[psmusic-mcp] Server starting via stdio...");

    let stdin = io::stdin();
    let mut stdout = io::stdout();

    for line in stdin.lock().lines() {
        let line = match line {
            Ok(l) => l,
            Err(e) => {
                eprintln!("[psmusic-mcp] Error reading line: {e}");
                break;
            }
        };

        let trimmed = line.trim();
        if trimmed.is_empty() {
            continue;
        }

        let req: JsonRpcRequest = match serde_json::from_str(trimmed) {
            Ok(r) => r,
            Err(e) => {
                eprintln!("[psmusic-mcp] Malformed JSON: {e}");
                continue;
            }
        };

        if let Some(resp) = handle_request(req) {
            let resp_str = serde_json::to_string(&resp).unwrap();
            stdout.write_all(resp_str.as_bytes())?;
            stdout.write_all(b"\n")?;
            stdout.flush()?;
        }
    }

    eprintln!("[psmusic-mcp] Server terminated.");
    Ok(())
}

fn handle_request(req: JsonRpcRequest) -> Option<Value> {
    let id = req.id?;

    match req.method.as_str() {
        "initialize" => Some(json!({
            "jsonrpc": "2.0",
            "id": id,
            "result": {
                "protocolVersion": "2024-11-05",
                "capabilities": {
                    "tools": {}
                },
                "serverInfo": {
                    "name": "psmusic-mcp",
                    "version": "0.1.0"
                }
            }
        })),
        "notifications/initialized" => None,
        "tools/list" => Some(json!({
            "jsonrpc": "2.0",
            "id": id,
            "result": {
                "tools": get_tool_definitions()
            }
        })),
        "tools/call" => {
            let tool_name = req.params.get("name").and_then(|v| v.as_str()).unwrap_or("");
            let arguments = req.params.get("arguments").cloned().unwrap_or(json!({}));
            let (is_error, result_text) = call_tool(tool_name, arguments);

            Some(json!({
                "jsonrpc": "2.0",
                "id": id,
                "result": {
                    "content": [
                        {
                            "type": "text",
                            "text": result_text
                        }
                    ],
                    "isError": is_error
                }
            }))
        }
        _ => Some(json!({
            "jsonrpc": "2.0",
            "id": id,
            "error": {
                "code": -32601,
                "message": format!("Method not found: {}", req.method)
            }
        })),
    }
}

fn get_tool_definitions() -> Value {
    json!([
        {
            "name": "psmusic_create_project",
            "description": "Create a new musical project JSON file with specified BPM and number of bars.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "file_path": { "type": "string", "description": "Target project file path (defaults to ./psmusic-project.json)" },
                    "bpm": { "type": "number", "description": "Tempo in BPM (e.g. 120.0)" },
                    "bars": { "type": "integer", "description": "Number of bars (e.g. 8)" }
                }
            }
        },
        {
            "name": "psmusic_add_track",
            "description": "Add a new track to the project (e.g. Beep melody or GS Wavetable instrument/drums).",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "file_path": { "type": "string", "description": "Project file path (optional, uses active project if omitted)" },
                    "name": { "type": "string", "description": "Track name (e.g. 'Lead', 'Bass', 'Drums')" },
                    "output": { "type": "string", "enum": ["beep", "gs"], "description": "Sound engine: 'beep' (Console.Beep) or 'gs' (Microsoft GS Wavetable Synth)" },
                    "channel": { "type": "integer", "description": "MIDI channel 0-15 (Channel 9 is drums for GS)" },
                    "program": { "type": "integer", "description": "General MIDI program number 0-127 (e.g. 0=Acoustic Grand Piano, 24=Acoustic Guitar, 33=Electric Bass)" },
                    "volume": { "type": "integer", "description": "Volume 0-100 (default 100)" }
                },
                "required": ["name", "output"]
            }
        },
        {
            "name": "psmusic_add_notes",
            "description": "Add one or more musical notes to a track in tick units (PPQ=480, 1 beat = 480 ticks, 1 bar = 1920 ticks).",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "file_path": { "type": "string", "description": "Project file path (optional)" },
                    "track_index": { "type": "integer", "description": "0-based index of the target track" },
                    "notes": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "start_tick": { "type": "integer", "description": "Start position in ticks (0 = start of song, 480 = beat 2)" },
                                "duration_tick": { "type": "integer", "description": "Duration in ticks (e.g. 480 for quarter note, 240 for eighth note)" },
                                "pitch": { "type": "integer", "description": "MIDI pitch number 0-127 (e.g. 60=C4, 69=A4, 36=Bass Drum on ch9)" },
                                "velocity": { "type": "integer", "description": "Velocity 1-127 (default 100)" }
                            },
                            "required": ["start_tick", "duration_tick", "pitch"]
                        }
                    }
                },
                "required": ["track_index", "notes"]
            }
        },
        {
            "name": "psmusic_get_project",
            "description": "Get summary and details of the current musical project.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "file_path": { "type": "string", "description": "Project file path (optional)" }
                }
            }
        },
        {
            "name": "psmusic_generate_script",
            "description": "Compile the project into a standalone PowerShell script (.ps1) compatible with PS 5.1 and 7 with live console visualizer.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "file_path": { "type": "string", "description": "Project file path (optional)" },
                    "output_path": { "type": "string", "description": "Destination .ps1 file path (optional)" },
                    "visualizer": { "type": "boolean", "description": "Enable ANSI/ASCII console visualizer (default true)" }
                }
            }
        },
        {
            "name": "psmusic_import_midi",
            "description": "Import a standard MIDI file (.mid) and convert it to a PowerShell Music Maker project JSON.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "midi_path": { "type": "string", "description": "Path to input MIDI file" },
                    "output_path": { "type": "string", "description": "Destination project JSON path (optional)" }
                },
                "required": ["midi_path"]
            }
        },
        {
            "name": "psmusic_export_midi",
            "description": "Export the current project as a standard MIDI file (.mid).",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "file_path": { "type": "string", "description": "Project file path (optional)" },
                    "output_path": { "type": "string", "description": "Path to output MIDI file" }
                },
                "required": ["output_path"]
            }
        },
        {
            "name": "psmusic_play",
            "description": "Immediately preview and playback the project through local Windows PC speakers using WinMM and kernel32 Beep.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "file_path": { "type": "string", "description": "Project file path (optional)" },
                    "blocking": { "type": "boolean", "description": "Wait until playback finishes before returning (default false)" }
                }
            }
        },
        {
            "name": "psmusic_stop",
            "description": "Stop any currently playing music preview.",
            "inputSchema": {
                "type": "object",
                "properties": {}
            }
        },
        {
            "name": "psmusic_test_environment",
            "description": "Diagnose Windows audio capabilities: tests Console.Beep on powershell & pwsh and Microsoft GS Wavetable Synth.",
            "inputSchema": {
                "type": "object",
                "properties": {}
            }
        }
    ])
}

fn call_tool(name: &str, args: Value) -> (bool, String) {
    match name {
        "psmusic_create_project" => {
            let path = match resolve_path(args.get("file_path").and_then(|v| v.as_str()).map(String::from)) {
                Ok(p) => p,
                Err(e) => return (true, e),
            };
            let bpm = args.get("bpm").and_then(|v| v.as_f64()).unwrap_or(120.0);
            let bars = args.get("bars").and_then(|v| v.as_u64()).unwrap_or(8) as u32;

            let mut proj = Project::default();
            proj.bpm = bpm;
            proj.bars = bars;

            if let Err(e) = save_project_to_path(&path, &proj) {
                return (true, e);
            }
            (false, format!("Created project at '{}' with BPM {} and {} bars.", path.display(), bpm, bars))
        }
        "psmusic_add_track" => {
            let path = match resolve_path(args.get("file_path").and_then(|v| v.as_str()).map(String::from)) {
                Ok(p) => p,
                Err(e) => return (true, e),
            };
            let mut proj = match load_project_from_path(&path) {
                Ok(p) => p,
                Err(e) => return (true, e),
            };

            let name = args.get("name").and_then(|v| v.as_str()).unwrap_or("Track").to_string();
            let output_str = args.get("output").and_then(|v| v.as_str()).unwrap_or("gs");
            let output = if output_str == "beep" { Output::Beep } else { Output::Gs };
            let channel = args.get("channel").and_then(|v| v.as_u64()).unwrap_or(0) as u8;
            let program = args.get("program").and_then(|v| v.as_u64()).unwrap_or(0) as u8;
            let volume = args.get("volume").and_then(|v| v.as_u64()).unwrap_or(100) as u8;

            let track_id = (proj.tracks.len() + 1) as u32;
            let track = Track {
                id: track_id,
                name: name.clone(),
                output,
                channel,
                program,
                volume,
                mute: false,
                notes: Vec::new(),
            };
            proj.tracks.push(track);
            let track_index = proj.tracks.len() - 1;

            if let Err(e) = save_project_to_path(&path, &proj) {
                return (true, e);
            }

            (false, format!("Added track '{name}' (Index: {track_index}, Output: {output_str:?}, Ch: {channel}, Prog: {program}) to '{}'.", path.display()))
        }
        "psmusic_add_notes" => {
            let path = match resolve_path(args.get("file_path").and_then(|v| v.as_str()).map(String::from)) {
                Ok(p) => p,
                Err(e) => return (true, e),
            };
            let mut proj = match load_project_from_path(&path) {
                Ok(p) => p,
                Err(e) => return (true, e),
            };

            let track_idx = match args.get("track_index").and_then(|v| v.as_u64()) {
                Some(idx) => idx as usize,
                None => return (true, "Missing required parameter 'track_index'".to_string()),
            };

            if track_idx >= proj.tracks.len() {
                return (true, format!("Track index {track_idx} out of range (total tracks: {})", proj.tracks.len()));
            }

            let notes_arr = match args.get("notes").and_then(|v| v.as_array()) {
                Some(arr) => arr,
                None => return (true, "Missing required parameter 'notes'".to_string()),
            };

            let mut added_count = 0;
            let (track_name, total_notes_in_track) = {
                let track = &mut proj.tracks[track_idx];
                let mut current_id = track.notes.iter().map(|n| n.id).max().unwrap_or(0) + 1;

                for n_val in notes_arr {
                    let start_tick = n_val.get("start_tick").and_then(|v| v.as_u64()).unwrap_or(0) as u32;
                    let duration_tick = n_val.get("duration_tick").and_then(|v| v.as_u64()).unwrap_or(480) as u32;
                    let pitch = n_val.get("pitch").and_then(|v| v.as_u64()).unwrap_or(60) as u8;
                    let velocity = n_val.get("velocity").and_then(|v| v.as_u64()).unwrap_or(100) as u8;

                    track.notes.push(Note {
                        id: current_id,
                        start_tick,
                        duration_tick: duration_tick.max(1),
                        pitch: pitch.min(127),
                        velocity: velocity.clamp(1, 127),
                    });
                    current_id += 1;
                    added_count += 1;
                }

                track.notes.sort_by_key(|n| n.start_tick);
                (track.name.clone(), track.notes.len())
            };

            if let Err(e) = save_project_to_path(&path, &proj) {
                return (true, e);
            }

            (false, format!("Successfully added {added_count} notes to Track #{track_idx} ('{track_name}'). Total notes in track: {total_notes_in_track}"))
        }
        "psmusic_get_project" => {
            let path = match resolve_path(args.get("file_path").and_then(|v| v.as_str()).map(String::from)) {
                Ok(p) => p,
                Err(e) => return (true, e),
            };
            let proj = match load_project_from_path(&path) {
                Ok(p) => p,
                Err(e) => return (true, e),
            };

            let tl = build_timeline(&proj, TimelineOptions::default());
            let summary = json!({
                "filePath": path.display().to_string(),
                "bpm": proj.bpm,
                "bars": proj.bars,
                "durationMs": tl.end_ms,
                "beepConflicts": tl.beep_conflicts,
                "tracks": proj.tracks.iter().enumerate().map(|(i, t)| {
                    json!({
                        "index": i,
                        "name": t.name,
                        "output": match t.output { Output::Beep => "beep", Output::Gs => "gs" },
                        "channel": t.channel,
                        "program": t.program,
                        "volume": t.volume,
                        "notesCount": t.notes.len(),
                    })
                }).collect::<Vec<_>>()
            });

            (false, serde_json::to_string_pretty(&summary).unwrap())
        }
        "psmusic_generate_script" => {
            let path = match resolve_path(args.get("file_path").and_then(|v| v.as_str()).map(String::from)) {
                Ok(p) => p,
                Err(e) => return (true, e),
            };
            let proj = match load_project_from_path(&path) {
                Ok(p) => p,
                Err(e) => return (true, e),
            };

            let visualizer = args.get("visualizer").and_then(|v| v.as_bool()).unwrap_or(true);
            let tl = build_timeline(&proj, TimelineOptions::default());
            let script = generate_script(&proj, &tl, GeneratorOptions { visualizer });

            if let Some(out_p_str) = args.get("output_path").and_then(|v| v.as_str()) {
                let out_p = PathBuf::from(out_p_str);
                if let Err(e) = fs::write(&out_p, &script) {
                    return (true, format!("Failed to write script to {}: {e}", out_p.display()));
                }
                (false, format!("PowerShell script generated and saved to '{}' ({} bytes, duration: {:.1}s).", out_p.display(), script.len(), tl.end_ms / 1000.0))
            } else {
                (false, format!("Generated script ({} bytes, duration: {:.1}s):\n\n{}", script.len(), tl.end_ms / 1000.0, script))
            }
        }
        "psmusic_import_midi" => {
            let midi_path_str = match args.get("midi_path").and_then(|v| v.as_str()) {
                Some(p) => p,
                None => return (true, "Missing 'midi_path'".to_string()),
            };
            let midi_bytes = match fs::read(midi_path_str) {
                Ok(b) => b,
                Err(e) => return (true, format!("Cannot read MIDI file: {e}")),
            };
            let proj = match parse_midi(&midi_bytes) {
                Ok(p) => p,
                Err(e) => return (true, e),
            };

            let out_p = match resolve_path(args.get("output_path").and_then(|v| v.as_str()).map(String::from)) {
                Ok(p) => p,
                Err(e) => return (true, e),
            };

            if let Err(e) = save_project_to_path(&out_p, &proj) {
                return (true, e);
            }

            (false, format!("Successfully imported MIDI from '{}' to '{}' (BPM: {}, Tracks: {}).", midi_path_str, out_p.display(), proj.bpm, proj.tracks.len()))
        }
        "psmusic_export_midi" => {
            let path = match resolve_path(args.get("file_path").and_then(|v| v.as_str()).map(String::from)) {
                Ok(p) => p,
                Err(e) => return (true, e),
            };
            let proj = match load_project_from_path(&path) {
                Ok(p) => p,
                Err(e) => return (true, e),
            };

            let out_path_str = match args.get("output_path").and_then(|v| v.as_str()) {
                Some(p) => p,
                None => return (true, "Missing 'output_path'".to_string()),
            };

            let midi_bytes = match export_midi(&proj) {
                Ok(b) => b,
                Err(e) => return (true, e),
            };

            if let Err(e) = fs::write(out_path_str, midi_bytes) {
                return (true, format!("Cannot write MIDI file: {e}"));
            }

            (false, format!("Successfully exported MIDI to '{}'.", out_path_str))
        }
        "psmusic_play" => {
            let path = match resolve_path(args.get("file_path").and_then(|v| v.as_str()).map(String::from)) {
                Ok(p) => p,
                Err(e) => return (true, e),
            };
            let proj = match load_project_from_path(&path) {
                Ok(p) => p,
                Err(e) => return (true, e),
            };

            let tl = build_timeline(&proj, TimelineOptions::default());
            let blocking = args.get("blocking").and_then(|v| v.as_bool()).unwrap_or(false);

            let player_lock = get_player();
            let player = player_lock.lock().unwrap();
            let res = player.as_ref().unwrap().play(tl.events, blocking);
            drop(player);

            match res {
                Ok(_) => (false, format!("Playback started for '{}' (duration: {:.1}s).", path.display(), tl.end_ms / 1000.0)),
                Err(e) => (true, format!("Playback failed: {e}")),
            }
        }
        "psmusic_stop" => {
            let player_lock = get_player();
            let player = player_lock.lock().unwrap();
            player.as_ref().unwrap().stop();
            drop(player);
            (false, "Playback stopped.".to_string())
        }
        "psmusic_test_environment" => {
            let res_ps = psmusic_core::test_beep("powershell");
            let res_pwsh = psmusic_core::test_beep("pwsh");
            let res_gs = psmusic_core::test_gs();
            let devices = psmusic_core::list_midi_devices();

            let summary = json!({
                "beep_powershell": res_ps,
                "beep_pwsh": res_pwsh,
                "gs_synth": res_gs,
                "midi_devices": devices
            });

            (false, serde_json::to_string_pretty(&summary).unwrap())
        }
        _ => (true, format!("Unknown tool: {name}")),
    }
}
