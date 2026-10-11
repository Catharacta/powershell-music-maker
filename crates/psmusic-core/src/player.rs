use crate::timeline::TLEvent;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

#[cfg(windows)]
pub mod win {
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
            let id = gs_device_id().ok_or("Microsoft GS Wavetable Synth not found")?;
            let mut h: *mut c_void = std::ptr::null_mut();
            let r = unsafe { midiOutOpen(&mut h, id, 0, 0, 0) };
            if r != 0 {
                return Err(format!("midiOutOpen failed (code {r})"));
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

#[derive(Default)]
pub struct Player {
    stop_flag: Mutex<Option<Arc<AtomicBool>>>,
}

impl Player {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn stop(&self) {
        if let Some(f) = self.stop_flag.lock().unwrap().take() {
            f.store(true, Ordering::SeqCst);
        }
    }

    pub fn play(&self, events: Vec<TLEvent>, blocking: bool) -> Result<(), String> {
        self.stop();
        let flag = Arc::new(AtomicBool::new(false));
        *self.stop_flag.lock().unwrap() = Some(flag.clone());

        #[cfg(windows)]
        {
            let needs_gs = events.iter().any(|e| e.kind.starts_with("gs_"));
            let out = if needs_gs { Some(win::Out::open()?) } else { None };

            let handle = thread::spawn(move || {
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
                                o.send(0xC0 | (e.ch.unwrap_or(0) & 15), e.program.unwrap_or(0), 0)
                            }
                        }
                        "gs_on" => {
                            if let Some(o) = &out {
                                o.send(0x90 | (e.ch.unwrap_or(0) & 15), e.pitch.unwrap_or(60), e.vel.unwrap_or(100))
                            }
                        }
                        "gs_off" => {
                            if let Some(o) = &out {
                                o.send(0x80 | (e.ch.unwrap_or(0) & 15), e.pitch.unwrap_or(60), 0)
                            }
                        }
                        "beep" => {
                            let (f, d) = (e.freq.unwrap_or(440).clamp(37, 32767), e.dur_ms.unwrap_or(100));
                            // Beepはブロックするため別スレッド
                            thread::spawn(move || unsafe {
                                win::Beep(f, d);
                            });
                        }
                        _ => {}
                    }
                }
                // 最後の音が鳴り終わるまで少し待ってから後始末
                thread::sleep(Duration::from_millis(300));
                if let Some(o) = &out {
                    o.all_off();
                }
            });

            if blocking {
                let _ = handle.join();
            }
            Ok(())
        }
        #[cfg(not(windows))]
        {
            let _ = (events, blocking, flag);
            Err("Playback is currently supported on Windows only".into())
        }
    }
}
