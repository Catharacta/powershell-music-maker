mod mcp;

use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use psmusic_core::{
    build_timeline, export_midi, generate_script, parse_midi, parse_project_json, BeepOverlap,
    GeneratorOptions, Player, Project, ProjectFile, TimelineOptions,
};
use std::fs;
use std::io::{self, Read, Write};
use std::path::PathBuf;

#[derive(Parser)]
#[command(name = "psmusic", author, version, about = "PowerShell Music Maker CLI & MCP Server")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Generate a standalone PowerShell script (.ps1) from a project JSON
    Generate {
        /// Input project file path (or '-' for stdin)
        #[arg(default_value = "-")]
        input: String,

        /// Output .ps1 file path (omit for stdout)
        #[arg(short, long)]
        output: Option<PathBuf>,

        /// Disable console visualizer
        #[arg(long)]
        no_visualizer: bool,

        /// Custom song title for visualizer (defaults to input file name)
        #[arg(long)]
        title: Option<String>,

        /// Custom artist name for visualizer
        #[arg(long)]
        artist: Option<String>,

        /// Beep overlap behavior: 'latest' (cut off previous note) or 'ignore' (keep previous note)
        #[arg(long, default_value = "latest")]
        beep_overlap: String,

        /// Minimum silence gap between consecutive Beep notes in milliseconds
        #[arg(long, default_value_t = 20)]
        beep_min_gap: u32,

        /// Minimum duration for a Beep note in milliseconds
        #[arg(long, default_value_t = 25)]
        beep_min_dur: u32,
    },

    /// Play a project JSON or MIDI file through local PC speakers
    Play {
        /// Input project or MIDI file path (or '-' for stdin)
        #[arg(default_value = "-")]
        input: String,
    },

    /// Run hardware audio tests (Console.Beep on PowerShell/pwsh, GS Wavetable Synth)
    Test {
        /// Shell to test: 'powershell', 'pwsh', or 'both'
        #[arg(default_value = "both")]
        shell: String,

        /// Also test Microsoft GS Wavetable Synth
        #[arg(long, default_value_t = true)]
        gs: bool,
    },

    /// Import a MIDI file and convert to Project JSON
    MidiImport {
        /// Input MIDI file path
        input: PathBuf,

        /// Output Project JSON file path (omit for stdout)
        #[arg(short, long)]
        output: Option<PathBuf>,
    },

    /// Export a Project JSON to a standard MIDI file
    MidiExport {
        /// Input Project JSON file path (or '-' for stdin)
        #[arg(default_value = "-")]
        input: String,

        /// Output MIDI file path
        #[arg(short, long)]
        output: PathBuf,
    },

    /// Create an empty template Project JSON file
    Init {
        /// Output file path
        #[arg(short, long, default_value = "song.json")]
        output: PathBuf,

        /// BPM tempo
        #[arg(long, default_value_t = 120.0)]
        bpm: f64,

        /// Number of bars
        #[arg(long, default_value_t = 8)]
        bars: u32,
    },

    /// Run as an MCP (Model Context Protocol) server via stdio
    Mcp,
}

fn read_input_string(input: &str) -> Result<String> {
    if input == "-" {
        let mut buf = String::new();
        io::stdin()
            .read_to_string(&mut buf)
            .context("Failed to read from stdin")?;
        Ok(buf)
    } else {
        fs::read_to_string(input).with_context(|| format!("Failed to read file: {input}"))
    }
}

fn read_input_bytes(input: &str) -> Result<Vec<u8>> {
    if input == "-" {
        let mut buf = Vec::new();
        io::stdin()
            .read_to_end(&mut buf)
            .context("Failed to read bytes from stdin")?;
        Ok(buf)
    } else {
        fs::read(input).with_context(|| format!("Failed to read file: {input}"))
    }
}

fn write_output_string(output: Option<&PathBuf>, content: &str) -> Result<()> {
    if let Some(path) = output {
        fs::write(path, content).with_context(|| format!("Failed to write to {}", path.display()))?;
    } else {
        io::stdout()
            .write_all(content.as_bytes())
            .context("Failed to write to stdout")?;
    }
    Ok(())
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Generate {
            input,
            output,
            no_visualizer,
            title,
            artist,
            beep_overlap,
            beep_min_gap,
            beep_min_dur,
        } => {
            let content = read_input_string(&input)?;
            let project = parse_project_json(&content).map_err(|e| anyhow::anyhow!("{e}"))?;

            let song_title = title.or_else(|| {
                if input != "-" {
                    std::path::Path::new(&input)
                        .file_stem()
                        .and_then(|s| s.to_str())
                        .map(String::from)
                } else {
                    None
                }
            });

            let overlap = match beep_overlap.to_lowercase().as_str() {
                "ignore" => BeepOverlap::Ignore,
                _ => BeepOverlap::Latest,
            };

            let tl = build_timeline(
                &project,
                TimelineOptions {
                    beep_overlap: overlap,
                    beep_min_gap_ms: beep_min_gap,
                    beep_min_dur_ms: beep_min_dur,
                },
            );
            let script = generate_script(
                &project,
                &tl,
                GeneratorOptions {
                    visualizer: !no_visualizer,
                    title: song_title,
                    artist,
                },
            );

            let script_with_bom = format!("\u{feff}{script}");
            write_output_string(output.as_ref(), &script_with_bom)?;
            if let Some(p) = output {
                eprintln!("Successfully generated script: {}", p.display());
            }
        }

        Commands::Play { input } => {
            let project = if input.ends_with(".mid") || input.ends_with(".midi") {
                let bytes = read_input_bytes(&input)?;
                parse_midi(&bytes).map_err(|e| anyhow::anyhow!("{e}"))?
            } else {
                let content = read_input_string(&input)?;
                parse_project_json(&content).map_err(|e| anyhow::anyhow!("{e}"))?
            };

            let tl = build_timeline(&project, TimelineOptions::default());
            eprintln!(
                "Playing project (BPM: {}, Duration: {:.1}s)... Press Ctrl+C to stop.",
                project.bpm,
                tl.end_ms / 1000.0
            );

            let player = Player::new();
            player
                .play(tl.events, true)
                .map_err(|e| anyhow::anyhow!("{e}"))?;
            eprintln!("Playback completed.");
        }

        Commands::Test { shell, gs } => {
            eprintln!("=== Audio Hardware Diagnostics ===");
            if shell == "both" || shell == "powershell" {
                let res = psmusic_core::test_beep("powershell");
                eprintln!(
                    "[PowerShell 5.1 Beep]: {} (Exit: {:?})\n  {}",
                    if res.ok { "OK" } else { "FAIL" },
                    res.exit_code,
                    res.message
                );
            }
            if shell == "both" || shell == "pwsh" {
                let res = psmusic_core::test_beep("pwsh");
                eprintln!(
                    "[PowerShell 7 (pwsh) Beep]: {} (Exit: {:?})\n  {}",
                    if res.ok { "OK" } else { "FAIL" },
                    res.exit_code,
                    res.message
                );
            }
            if gs {
                let res = psmusic_core::test_gs();
                eprintln!(
                    "[Microsoft GS Wavetable Synth]: {}\n  {}",
                    if res.ok { "OK" } else { "FAIL" },
                    res.message
                );
            }
            let devices = psmusic_core::list_midi_devices();
            eprintln!("\nDetected MIDI Devices ({}):", devices.len());
            for d in devices {
                eprintln!("  - {d}");
            }
        }

        Commands::MidiImport { input, output } => {
            let bytes = fs::read(&input)
                .with_context(|| format!("Cannot read MIDI file: {}", input.display()))?;
            let project = parse_midi(&bytes).map_err(|e| anyhow::anyhow!("{e}"))?;
            let project_file = ProjectFile::new(project);
            let json_str = serde_json::to_string_pretty(&project_file)?;

            write_output_string(output.as_ref(), &json_str)?;
            if let Some(p) = output {
                eprintln!("Imported MIDI to {}", p.display());
            }
        }

        Commands::MidiExport { input, output } => {
            let content = read_input_string(&input)?;
            let project = parse_project_json(&content).map_err(|e| anyhow::anyhow!("{e}"))?;
            let bytes = export_midi(&project).map_err(|e| anyhow::anyhow!("{e}"))?;
            fs::write(&output, bytes)
                .with_context(|| format!("Failed to write to {}", output.display()))?;
            eprintln!("Exported project to MIDI: {}", output.display());
        }

        Commands::Init { output, bpm, bars } => {
            let mut project = Project::default();
            project.bpm = bpm;
            project.bars = bars;
            let project_file = ProjectFile::new(project);
            let json_str = serde_json::to_string_pretty(&project_file)?;
            fs::write(&output, json_str)
                .with_context(|| format!("Failed to create {}", output.display()))?;
            eprintln!("Initialized empty project at: {}", output.display());
        }

        Commands::Mcp => {
            mcp::run_mcp_server().context("MCP server terminated with error")?;
        }
    }

    Ok(())
}
