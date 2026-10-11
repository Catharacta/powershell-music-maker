// 試聴・テスト・スクリプト生成用バックエンド。
// コアロジックは共有クレート `psmusic_core` を使用する。
use psmusic_core::{
    build_timeline, export_midi, generate_script, list_midi_devices as core_list_midi_devices,
    parse_midi, test_beep as core_test_beep, test_gs as core_test_gs, BeepOverlap, GeneratorOptions,
    Player, Project, TLEvent, TestResult, Timeline, TimelineOptions,
};
use std::sync::Mutex;

struct AppState {
    player: Player,
}

#[tauri::command]
fn stop(state: tauri::State<Mutex<AppState>>) {
    if let Ok(app) = state.lock() {
        app.player.stop();
    }
}

#[tauri::command]
fn play(state: tauri::State<Mutex<AppState>>, events: Vec<TLEvent>) -> Result<(), String> {
    let app = state.lock().map_err(|e| e.to_string())?;
    app.player.play(events, false)
}

#[tauri::command]
fn test_beep(shell: String) -> TestResult {
    core_test_beep(&shell)
}

#[tauri::command]
fn test_gs() -> TestResult {
    core_test_gs()
}

#[tauri::command]
fn list_midi_devices() -> Vec<String> {
    core_list_midi_devices()
}

#[tauri::command]
fn generate_ps_script(
    project: Project,
    visualizer: Option<bool>,
    title: Option<String>,
    artist: Option<String>,
    beep_overlap: Option<String>,
) -> Result<String, String> {
    let overlap = match beep_overlap.as_deref() {
        Some("ignore") => BeepOverlap::Ignore,
        _ => BeepOverlap::Latest,
    };
    let tl = build_timeline(&project, TimelineOptions { beep_overlap: overlap });
    let script = generate_script(
        &project,
        &tl,
        GeneratorOptions {
            visualizer: visualizer.unwrap_or(true),
            title,
            artist,
        },
    );
    Ok(script)
}

#[tauri::command]
fn get_project_timeline(project: Project, beep_overlap: Option<String>) -> Timeline {
    let overlap = match beep_overlap.as_deref() {
        Some("ignore") => BeepOverlap::Ignore,
        _ => BeepOverlap::Latest,
    };
    build_timeline(&project, TimelineOptions { beep_overlap: overlap })
}

#[tauri::command]
fn parse_midi_file(bytes: Vec<u8>) -> Result<Project, String> {
    parse_midi(&bytes)
}

#[tauri::command]
fn export_midi_file(project: Project) -> Result<Vec<u8>, String> {
    export_midi(&project)
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_opener::init())
        .manage(Mutex::new(AppState {
            player: Player::new(),
        }))
        .invoke_handler(tauri::generate_handler![
            play,
            stop,
            test_beep,
            test_gs,
            list_midi_devices,
            generate_ps_script,
            get_project_timeline,
            parse_midi_file,
            export_midi_file
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
