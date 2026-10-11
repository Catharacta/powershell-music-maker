use serde::{Deserialize, Serialize};
use std::process::Command;
#[cfg(windows)]
use std::thread;
#[cfg(windows)]
use std::time::Duration;

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct TestResult {
    pub ok: bool,
    pub exit_code: Option<i32>,
    pub stdout: String,
    pub stderr: String,
    pub message: String,
}

/// 実際に powershell / pwsh を起動して [Console]::Beep を実行する
pub fn test_beep(shell: &str) -> TestResult {
    let exe = match shell {
        "pwsh" => "pwsh",
        _ => "powershell",
    };
    let r = Command::new(exe)
        .args([
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            "[Console]::Beep(440,500)",
        ])
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
                    format!("{exe}: Succeeded (Please check if you heard the sound)")
                } else {
                    format!("{exe}: Failed")
                },
            }
        }
        Err(e) => TestResult {
            ok: false,
            exit_code: None,
            stdout: String::new(),
            stderr: e.to_string(),
            message: format!("Cannot launch {exe}: {e}"),
        },
    }
}

pub fn test_gs() -> TestResult {
    #[cfg(windows)]
    {
        let out = match crate::player::win::Out::open() {
            Ok(o) => o,
            Err(e) => {
                return TestResult {
                    ok: false,
                    exit_code: None,
                    stdout: String::new(),
                    stderr: e.clone(),
                    message: e,
                }
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
            message: "GS Wavetable Synth: Test note sent successfully".into(),
        }
    }
    #[cfg(not(windows))]
    {
        TestResult {
            ok: false,
            exit_code: None,
            stdout: String::new(),
            stderr: String::new(),
            message: "Windows only".into(),
        }
    }
}

pub fn list_midi_devices() -> Vec<String> {
    #[cfg(windows)]
    {
        crate::player::win::devices()
            .into_iter()
            .map(|(i, n)| format!("{i}: {n}"))
            .collect()
    }
    #[cfg(not(windows))]
    {
        Vec::new()
    }
}
