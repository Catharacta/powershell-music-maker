use serde::{Deserialize, Serialize};

pub const PPQ: u32 = 480;
pub const BEATS_PER_BAR: u32 = 4;

#[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum Output {
    Beep,
    Gs,
}

impl Default for Output {
    fn default() -> Self {
        Output::Gs
    }
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct Note {
    #[serde(default)]
    pub id: u32,
    pub start_tick: u32,
    pub duration_tick: u32,
    pub pitch: u8,
    #[serde(default = "default_velocity")]
    pub velocity: u8,
}

fn default_velocity() -> u8 {
    100
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct Track {
    #[serde(default)]
    pub id: u32,
    #[serde(default = "default_track_name")]
    pub name: String,
    #[serde(default)]
    pub output: Output,
    #[serde(default)]
    pub channel: u8,
    #[serde(default)]
    pub program: u8,
    #[serde(default = "default_volume")]
    pub volume: u8,
    #[serde(default)]
    pub mute: bool,
    #[serde(default)]
    pub notes: Vec<Note>,
}

fn default_track_name() -> String {
    "Track".to_string()
}

fn default_volume() -> u8 {
    100
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct Project {
    #[serde(default = "default_bpm")]
    pub bpm: f64,
    #[serde(default = "default_bars")]
    pub bars: u32,
    #[serde(default)]
    pub tracks: Vec<Track>,
}

fn default_bpm() -> f64 {
    120.0
}

fn default_bars() -> u32 {
    8
}

impl Default for Project {
    fn default() -> Self {
        Self {
            bpm: default_bpm(),
            bars: default_bars(),
            tracks: Vec::new(),
        }
    }
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ProjectFile {
    pub app: String,
    pub version: u32,
    pub project: Project,
}

impl ProjectFile {
    pub fn new(project: Project) -> Self {
        Self {
            app: "powershell-music-maker".to_string(),
            version: 1,
            project,
        }
    }
}

/// tick -> ms。絶対位置から計算し、誤差を累積させない。
pub fn tick_to_ms(tick: u32, bpm: f64) -> f64 {
    (tick as f64 * 60000.0) / (bpm * PPQ as f64)
}

/// MIDIノート -> 周波数(Hz)。Beepの有効範囲 37〜32767 にクランプ。
pub fn note_to_freq(note: u8) -> u32 {
    let f = (440.0 * 2.0_f64.powf((note as f64 - 69.0) / 12.0)).round() as i32;
    f.clamp(37, 32767) as u32
}

const NOTE_NAMES: [&str; 12] = [
    "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B",
];

pub fn note_name(n: u8) -> String {
    let name = NOTE_NAMES[(n % 12) as usize];
    let oct = (n as i32 / 12) - 1;
    format!("{}{}", name, oct)
}

pub fn is_black_key(n: u8) -> bool {
    matches!(n % 12, 1 | 3 | 6 | 8 | 10)
}

/// ProjectFile (v1) または直接 Project オブジェクトのJSON文字列/Valueをパース・正規化する
pub fn parse_project_json(content: &str) -> Result<Project, String> {
    let val: serde_json::Value =
        serde_json::from_str(content).map_err(|e| format!("JSON syntax error: {e}"))?;

    // ProjectFile 形式かチェック
    if let Some(app) = val.get("app").and_then(|v| v.as_str()) {
        if app == "powershell-music-maker" {
            if let Some(p) = val.get("project") {
                return serde_json::from_value(p.clone())
                    .map_err(|e| format!("Invalid project in project file: {e}"));
            }
        }
    }

    // 直接 Project 形式としてパース
    serde_json::from_value(val).map_err(|e| format!("Invalid project format: {e}"))
}
