// 試聴・テスト用バックエンド。
// タイムライン(Event列)はフロントエンド(TS)が生成し、出力スクリプトと共通のものをここで再生する。
use serde::{Deserialize, Serialize};
use std::process::Command;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

#[cfg(windows)]
mod win {
    use std::ffi::c_void;

    #[repr(C)]
    pub struct MidiOutCapsW {
        pub mid: u16,
        pub pid: u16,
        pub ver: u32,
        pub name: [u16; 32],
        pub tech: u16,
        pub voices: u16,
        pub notes: u16,
        pub chan_mask: u16,
        pub support: u32,
    }

    #[link(name = "winmm")]
    extern "system" {
        pub fn midiOutGetNumDevs() -> u32;
        pub fn midiOutGetDevCapsW(id: usize, caps: *mut MidiOutCapsW, size: u32) -> u32;
        pub fn midiOutOpen(h: *mut *mut c_void, id: u32, cb: usize, inst: usize, flags: u32) -> u32;
        pub fn midiOutShortMsg(h: *mut c_void, msg: u32) -> u32;
        pub fn midiOutClose(h: *mut c_void) -> u32;
    }

    #[link(name = "kernel32")]
    extern "system" {
        pub fn Beep(freq: u32, dur: u32) -> i32;
    }

    /// (id, name) の一覧
    pub fn devices() -> Vec<(u32, String)> {
        let mut v = Vec::new();
        unsafe {
            for i in 0..midiOutGetNumDevs() {
                let mut c: MidiOutCapsW = std::mem::zeroed();
                if midiOutGetDevCapsW(i as usize, &mut c, std::mem::size_of::<MidiOutCapsW>() as u32) == 0 {
                    let n = c.name.iter().position(|&x| x == 0).unwrap_or(32);
                    v.push((i, String::from_utf16_lossy(&c.name[..n])));
                }
            }
        }
        v
    }

    pub fn gs_device_id() -> Option<u32> {
        devices().into_iter().find(|(_, n)| n.contains("GS Wavetable")).map(|(i, _)| i)
    }

    /// MIDI出力ハンドル(スレッド間で使うためusizeで保持)
    pub struct Out(pub usize);
    impl Out {
        pub fn open() -> Result<Out, String> {
            let id = gs_device_id().ok_or("Microsoft GS Wavetable Synth が見つかりません")?;
            let mut h: *mut c_void = std::ptr::null_mut();
            let r = unsafe { midiOutOpen(&mut h, id, 0, 0, 0) };
            if r != 0 {
                return Err(format!("midiOutOpen 失敗 (code {r})"));
            }
            Ok(Out(h as usize))
        }
        pub fn send(&self, status: u8, d1: u8, d2: u8) {
            let msg = status as u32 | ((d1 as u32) << 8) | ((d2 as u32) << 16);
            unsafe { midiOutShortMsg(self.0 as *mut c_void, msg) };
        }
        pub fn all_off(&self) {
            for ch in 0..16u8 {
                self.send(0xB0 | ch, 123, 0);
            }
        }
    }
    impl Drop for Out {
        fn drop(&mut self) {
            unsafe { midiOutClose(self.0 as *mut c_void) };
        }
    }
}

#[derive(Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct Event {
    pub t_ms: f64,
    /// "gs_prog" | "gs_on" | "gs_off" | "beep"
    pub kind: String,
    #[serde(default)]
    pub ch: u8,
    #[serde(default)]
    pub pitch: u8,
    #[serde(default)]
    pub vel: u8,
    #[serde(default)]
    pub program: u8,
    #[serde(default)]
    pub freq: u32,
    #[serde(default)]
    pub dur_ms: u32,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct TestResult {
    pub ok: bool,
    pub exit_code: Option<i32>,
    pub stdout: String,
    pub stderr: String,
    pub message: String,
}

#[derive(Default)]
struct Player {
    stop: Mutex<Option<Arc<AtomicBool>>>,
}

fn stop_current(p: &Player) {
    if let Some(f) = p.stop.lock().unwrap().take() {
        f.store(true, Ordering::SeqCst);
    }
}

#[tauri::command]
fn stop(state: tauri::State<Player>) {
    stop_current(&state);
}

#[tauri::command]
fn play(state: tauri::State<Player>, events: Vec<Event>) -> Result<(), String> {
    stop_current(&state);
    let flag = Arc::new(AtomicBool::new(false));
    *state.stop.lock().unwrap() = Some(flag.clone());

    #[cfg(windows)]
    {
        let needs_gs = events.iter().any(|e| e.kind.starts_with("gs_"));
        let out = if needs_gs { Some(win::Out::open()?) } else { None };
        thread::spawn(move || {
            let start = Instant::now();
            for e in events {
                // 絶対時刻に対して待機(誤差を累積させない)
                loop {
                    if flag.load(Ordering::SeqCst) {
                        if let Some(o) = &out {
                            o.all_off();
                        }
                        return;
                    }
                    let now = start.elapsed().as_secs_f64() * 1000.0;
                    if now >= e.t_ms {
                        break;
                    }
                    thread::sleep(Duration::from_millis(((e.t_ms - now) as u64).clamp(1, 10)));
                }
                match e.kind.as_str() {
                    "gs_prog" => {
                        if let Some(o) = &out {
                            o.send(0xC0 | (e.ch & 15), e.program, 0)
                        }
                    }
                    "gs_on" => {
                        if let Some(o) = &out {
                            o.send(0x90 | (e.ch & 15), e.pitch, e.vel)
                        }
                    }
                    "gs_off" => {
                        if let Some(o) = &out {
                            o.send(0x80 | (e.ch & 15), e.pitch, 0)
                        }
                    }
                    "beep" => {
                        let (f, d) = (e.freq.clamp(37, 32767), e.dur_ms);
                        // Beepはブロックするため別スレッド
                        thread::spawn(move || unsafe {
                            win::Beep(f, d);
                        });
                    }
                    _ => {}
                }
            }
            // 最後のBeepが鳴り終わるまで少し待ってから後始末
            thread::sleep(Duration::from_millis(300));
            if let Some(o) = &out {
                o.all_off();
            }
        });
        Ok(())
    }
    #[cfg(not(windows))]
    {
        let _ = (events, flag);
        Err("Windows専用機能です".into())
    }
}

/// 実際に powershell / pwsh を起動して [Console]::Beep を実行する
#[tauri::command]
fn test_beep(shell: String) -> TestResult {
    let exe = match shell.as_str() {
        "pwsh" => "pwsh",
        _ => "powershell",
    };
    let r = Command::new(exe)
        .args(["-NoProfile", "-NonInteractive", "-Command", "[Console]::Beep(440,500)"])
        .output();
    match r {
        Ok(o) => {
            let ok = o.status.success();
            TestResult {
                ok,
                exit_code: o.status.code(),
                stdout: String::from_utf8_lossy(&o.stdout).into(),
                stderr: String::from_utf8_lossy(&o.stderr).into(),
                message: if ok {
                    format!("{exe}: 実行成功(音が聞こえたか確認してください)")
                } else {
                    format!("{exe}: 実行失敗")
                },
            }
        }
        Err(e) => TestResult {
            ok: false,
            exit_code: None,
            stdout: String::new(),
            stderr: e.to_string(),
            message: format!("{exe} を起動できません"),
        },
    }
}

#[tauri::command]
fn test_gs() -> TestResult {
    #[cfg(windows)]
    {
        let out = match win::Out::open() {
            Ok(o) => o,
            Err(e) => {
                return TestResult { ok: false, exit_code: None, stdout: String::new(), stderr: e.clone(), message: e }
            }
        };
        out.send(0xC0, 0, 0);
        out.send(0x90, 60, 100);
        thread::sleep(Duration::from_millis(500));
        out.send(0x80, 60, 0);
        thread::sleep(Duration::from_millis(100));
        TestResult {
            ok: true,
            exit_code: Some(0),
            stdout: String::new(),
            stderr: String::new(),
            message: "GS Wavetable Synth: テスト音を送信しました".into(),
        }
    }
    #[cfg(not(windows))]
    {
        TestResult { ok: false, exit_code: None, stdout: String::new(), stderr: String::new(), message: "Windows専用".into() }
    }
}

#[tauri::command]
fn list_midi_devices() -> Vec<String> {
    #[cfg(windows)]
    {
        win::devices().into_iter().map(|(i, n)| format!("{i}: {n}")).collect()
    }
    #[cfg(not(windows))]
    {
        Vec::new()
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_opener::init())
        .manage(Player::default())
        .invoke_handler(tauri::generate_handler![play, stop, test_beep, test_gs, list_midi_devices])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
