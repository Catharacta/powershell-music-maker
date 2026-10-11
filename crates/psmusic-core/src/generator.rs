use crate::model::Project;
use crate::timeline::Timeline;

/// 非ASCII文字を '?' に置換し、改行を除去する
fn ascii(s: &str) -> String {
    s.chars()
        .map(|c| {
            if c == '\r' || c == '\n' {
                ' '
            } else if c.is_ascii() && (' '..='~').contains(&c) {
                c
            } else {
                '?'
            }
        })
        .collect()
}

#[derive(Clone, Debug)]
pub struct GeneratorOptions {
    pub visualizer: bool,
    pub title: Option<String>,
    pub artist: Option<String>,
}

impl Default for GeneratorOptions {
    fn default() -> Self {
        Self {
            visualizer: true,
            title: None,
            artist: None,
        }
    }
}

pub fn generate_script(p: &Project, tl: &Timeline, options: GeneratorOptions) -> String {
    let visualizer = options.visualizer;
    let mut lines = Vec::new();

    lines.push("# PowerShell Music Maker generated script (PowerShell 5.1 / 7)".to_string());

    let track_summary = p
        .tracks
        .iter()
        .map(|t| {
            let out_str = match t.output {
                crate::model::Output::Beep => "beep",
                crate::model::Output::Gs => "gs",
            };
            format!("{}[{}]", ascii(&t.name), out_str)
        })
        .collect::<Vec<_>>()
        .join(", ");
    lines.push(format!("# BPM={}  tracks: {}", p.bpm, track_summary));
    lines.push("if (-not ('PsMusic' -as [type])) {".to_string());
    lines.push("Add-Type -TypeDefinition @'".to_string());
    lines.push("using System;".to_string());
    lines.push("using System.Text;".to_string());
    lines.push("using System.Diagnostics;".to_string());
    lines.push("using System.Threading;".to_string());
    lines.push("using System.Runtime.InteropServices;".to_string());

    if visualizer {
        lines.push(
            r#"
public class TrackState {
  public string Name;
  public string Type;
  public int Channel;
  public double Volume;
  public int Freq;
  public string NoteName = "-";
}"#
            .to_string(),
        );
    }

    lines.push("public class PsMusic {".to_string());

    // WinMM MIDI support
    lines.push(
        r#"  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
  public struct MIDIOUTCAPS {
    public ushort wMid; public ushort wPid; public uint vDriverVersion;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string szPname;
    public ushort wTechnology; public ushort wVoices; public ushort wNotes; public ushort wChannelMask; public uint dwSupport;
  }
  [DllImport("winmm.dll")] static extern int midiOutGetNumDevs();
  [DllImport("winmm.dll", CharSet=CharSet.Unicode)] static extern int midiOutGetDevCaps(IntPtr id, ref MIDIOUTCAPS caps, int size);
  [DllImport("winmm.dll")] static extern int midiOutOpen(out IntPtr h, int id, IntPtr cb, IntPtr inst, int flags);
  [DllImport("winmm.dll")] static extern int midiOutShortMsg(IntPtr h, uint msg);
  [DllImport("winmm.dll")] static extern int midiOutClose(IntPtr h);
  static IntPtr hOut = IntPtr.Zero;

  public static void Open() {
    for (int i = 0; i < midiOutGetNumDevs(); i++) {
      MIDIOUTCAPS c = new MIDIOUTCAPS();
      if (midiOutGetDevCaps(new IntPtr(i), ref c, Marshal.SizeOf(c)) == 0 && c.szPname.Contains("GS Wavetable")) {
        if (midiOutOpen(out hOut, i, IntPtr.Zero, IntPtr.Zero, 0) == 0) return;
      }
    }
    throw new Exception("Microsoft GS Wavetable Synth not found");
  }

  public static void Send(int status, int d1, int d2) {
    if (hOut != IntPtr.Zero) midiOutShortMsg(hOut, (uint)(status | (d1 << 8) | (d2 << 16)));
  }"#
        .to_string(),
    );

    // Beep support
    lines.push(
        r#"  public static void Beep(int f, int d) {
    Thread t = new Thread(delegate() { try { Console.Beep(f, d); } catch (Exception) { } });
    t.IsBackground = true; t.Start();
  }"#
        .to_string(),
    );

    if visualizer {
        lines.push(
            r##"  public static TrackState[] Tracks;
  public static int TotalMs;
  public static int Bpm;
  public static string Title;
  public static string Artist;
  public static Stopwatch Sw;
  private static Thread RenderThread;
  private static volatile bool Running = false;
  private static readonly string[] PitchNames = new string[] {
    "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"
  };

  public static void Init(int totalMs, int bpm, string title, string artist, string[] names, string[] types, int[] channels) {
    TotalMs = totalMs;
    Bpm = bpm;
    Title = title;
    Artist = artist;
    Tracks = new TrackState[names.Length];
    for (int i = 0; i < names.Length; i++) {
      Tracks[i] = new TrackState {
        Name = names[i],
        Type = types[i],
        Channel = channels[i],
        Volume = 0,
        Freq = 0
      };
    }
  }

  public static void Start() {
    Sw = Stopwatch.StartNew();
    Running = true;
    try { Console.Clear(); } catch {}
    try { Console.CursorVisible = false; } catch {}
    RenderThread = new Thread(RenderLoop);
    RenderThread.IsBackground = true;
    RenderThread.Start();
  }

  public static void On(int tr, int ch, int pitch, int vel) {
    Send(0x90 | ch, pitch, vel);
    if (Tracks != null && tr >= 0 && tr < Tracks.Length) {
      Tracks[tr].Volume = Math.Min(100, Math.Max(25, vel));
      Tracks[tr].Freq = (int)Math.Round(440.0 * Math.Pow(2.0, (pitch - 69) / 12.0));
      Tracks[tr].NoteName = PitchToName(pitch);
    }
  }

  public static void Off(int tr, int ch, int pitch) {
    Send(0x80 | ch, pitch, 0);
    if (Tracks != null && tr >= 0 && tr < Tracks.Length) {
      Tracks[tr].Volume *= 0.3;
      if (Tracks[tr].Volume < 5) Tracks[tr].NoteName = "-";
    }
  }

  public static void BeepOn(int tr, int freq, int dur) {
    Beep(freq, dur);
    if (Tracks != null && tr >= 0 && tr < Tracks.Length) {
      Tracks[tr].Volume = 100;
      Tracks[tr].Freq = freq;
      Tracks[tr].NoteName = FreqToName(freq);
    }
  }

  private static string PitchToName(int pitch) {
    if (pitch < 0 || pitch > 127) return "?";
    int oct = (pitch / 12) - 1;
    return PitchNames[pitch % 12] + oct;
  }

  private static string FreqToName(int freq) {
    if (freq <= 0) return "-";
    int pitch = (int)Math.Round(69.0 + 12.0 * Math.Log((double)freq / 440.0, 2.0));
    return PitchToName(pitch) + " (" + freq + "Hz)";
  }

  private const int InnerWidth = 58;
  private const string Border = "+------------------------------------------------------------+";

  private static string BoxRow(string text) {
    if (text == null) text = "";
    if (text.Length > InnerWidth) {
      text = text.Substring(0, InnerWidth);
    } else if (text.Length < InnerWidth) {
      text = text.PadRight(InnerWidth);
    }
    return "| " + text + " |";
  }

  private static void RenderLoop() {
    int originTop = 0;
    try { originTop = Console.CursorTop; } catch {}
    double phase = 0;
    char[] waveChars = new char[] { ' ', '.', ':', '-', '=', '#', '%' };
    StringBuilder sb = new StringBuilder();

    while (Running) {
      int elapsedMs = Sw != null ? (int)Sw.ElapsedMilliseconds : 0;
      double progress = Math.Min(1.0, (double)elapsedMs / Math.Max(1, TotalMs));
      sb.Clear();

      sb.AppendLine(Border);
      sb.AppendLine(BoxRow("POWERSHELL MUSIC MAKER"));
      if (!string.IsNullOrEmpty(Title)) {
        sb.AppendLine(BoxRow("TITLE : " + Title));
      }
      if (!string.IsNullOrEmpty(Artist)) {
        sb.AppendLine(BoxRow("ARTIST: " + Artist));
      }

      int progLen = 20;
      int filled = (int)(progress * progLen);
      string progBar = "[" + new string('=', filled) + (filled < progLen ? ">" : "") + new string(' ', Math.Max(0, progLen - filled - (filled < progLen ? 1 : 0))) + "]";
      string timeStr = string.Format("TIME : {0:D2}:{1:D2} / {2:D2}:{3:D2}  {4} {5,4:P0}",
        (elapsedMs / 1000) / 60, (elapsedMs / 1000) % 60,
        (TotalMs / 1000) / 60, (TotalMs / 1000) % 60,
        progBar, progress);
      sb.AppendLine(BoxRow(timeStr));
      sb.AppendLine(BoxRow(string.Format("BPM  : {0}", Bpm)));
      sb.AppendLine(Border);
      sb.AppendLine(BoxRow("WAVEFORM"));

      double totalAmp = 0;
      if (Tracks != null) {
        for (int t = 0; t < Tracks.Length; t++) totalAmp += Tracks[t].Volume;
      }

      int waveWidth = 56;
      StringBuilder wb = new StringBuilder();
      wb.Append("[");
      for (int i = 0; i < waveWidth; i++) {
        if (totalAmp <= 1.0) {
          wb.Append('-');
        } else {
          double sample = 0;
          for (int t = 0; t < Tracks.Length; t++) {
            if (Tracks[t].Volume > 1) {
              double f = Tracks[t].Freq > 0 ? (Tracks[t].Freq / 300.0) : 1.0;
              sample += (Tracks[t].Volume / 100.0) * Math.Sin(phase + i * f * 0.35);
            }
          }
          double norm = sample / Math.Max(1.0, Tracks.Length * 0.8);
          norm = Math.Max(-1.0, Math.Min(1.0, norm));
          int idx = (int)Math.Round((norm + 1.0) / 2.0 * (waveChars.Length - 1));
          idx = Math.Max(0, Math.Min(waveChars.Length - 1, idx));
          wb.Append(waveChars[idx]);
        }
      }
      wb.Append("]");
      sb.AppendLine(BoxRow(wb.ToString()));

      sb.AppendLine(Border);
      sb.AppendLine(BoxRow("TRACKS"));

      if (Tracks != null) {
        for (int t = 0; t < Tracks.Length; t++) {
          TrackState tr = Tracks[t];
          string numStr = string.Format("#{0,-2}", t + 1);
          string trName = tr.Name.Length > 11 ? tr.Name.Substring(0, 11) : tr.Name.PadRight(11);
          int vuLen = 14;
          int vuFilled = (int)Math.Round((tr.Volume / 100.0) * vuLen);
          vuFilled = Math.Max(0, Math.Min(vuLen, vuFilled));
          string vuBar = "[" + new string('#', vuFilled) + new string('-', vuLen - vuFilled) + "]";
          string line = string.Format("{0} {1} [{2,-4}] {3} {4,3:F0}% {5}",
            numStr, trName, tr.Type, vuBar, tr.Volume, tr.NoteName);
          sb.AppendLine(BoxRow(line));
        }
      }
      sb.AppendLine(Border);

      try {
        Console.SetCursorPosition(0, originTop);
        Console.Write(sb.ToString());
      } catch {}

      if (Tracks != null) {
        for (int t = 0; t < Tracks.Length; t++) {
          Tracks[t].Volume = Math.Max(0, Tracks[t].Volume * 0.88);
          if (Tracks[t].Volume < 2) Tracks[t].NoteName = "-";
        }
      }

      phase += 0.35;
      Thread.Sleep(33);
    }
  }"##
            .to_string(),
        );
    }

    // Close method
    let close_body = if visualizer {
        r#"  public static void Close() {
    Running = false;
    if (RenderThread != null && RenderThread.IsAlive) { RenderThread.Join(400); }
    try { Console.CursorVisible = true; } catch {}
    if (hOut != IntPtr.Zero) {
      for (int ch = 0; ch < 16; ch++) Send(0xB0 | ch, 123, 0);
      midiOutClose(hOut); hOut = IntPtr.Zero;
    }
    Console.WriteLine();
  }"#
    } else {
        r#"  public static void Close() {
    if (hOut != IntPtr.Zero) {
      for (int ch = 0; ch < 16; ch++) Send(0xB0 | ch, 123, 0);
      midiOutClose(hOut); hOut = IntPtr.Zero;
    }
  }"#
    };
    lines.push(close_body.to_string());

    lines.push("}".to_string());
    lines.push("'@".to_string());
    lines.push("}".to_string());

    if visualizer {
        let track_names = p
            .tracks
            .iter()
            .map(|t| format!("'{}'", ascii(&t.name).replace('\'', "''")))
            .collect::<Vec<_>>()
            .join(", ");
        let track_types = p
            .tracks
            .iter()
            .map(|t| {
                let s = match t.output {
                    crate::model::Output::Beep => "BEEP",
                    crate::model::Output::Gs => "GS",
                };
                format!("'{}'", s)
            })
            .collect::<Vec<_>>()
            .join(", ");
        let track_channels = p
            .tracks
            .iter()
            .map(|t| t.channel.to_string())
            .collect::<Vec<_>>()
            .join(", ");

        let safe_title = options
            .title
            .as_deref()
            .map(|t| ascii(t).replace('\'', "''"))
            .unwrap_or_default();
        let safe_artist = options
            .artist
            .as_deref()
            .map(|a| ascii(a).replace('\'', "''"))
            .unwrap_or_default();

        lines.push(format!(
            "[PsMusic]::Init({}, {}, '{}', '{}', @({}), @({}), @({}))",
            tl.end_ms.round() as i64,
            p.bpm.round() as i64,
            safe_title,
            safe_artist,
            track_names,
            track_types,
            track_channels
        ));
    }

    lines.push(
        "# Wait until the absolute time with Start-Sleep (no accumulated drift)".to_string(),
    );
    lines.push("$sw = [Diagnostics.Stopwatch]::StartNew()".to_string());
    lines.push("function W([int]$t) { $d = $t - [int]$sw.ElapsedMilliseconds; if ($d -gt 0) { Start-Sleep -Milliseconds $d } }".to_string());

    if visualizer {
        lines.push(
            "function Prog($ch, $p) { [PsMusic]::Send((0xC0 -bor $ch), $p, 0) }".to_string(),
        );
        lines.push(
            "function On($tr, $ch, $n, $v) { [PsMusic]::On($tr, $ch, $n, $v) }".to_string(),
        );
        lines.push("function Off($tr, $ch, $n) { [PsMusic]::Off($tr, $ch, $n) }".to_string());
        lines.push("function B($tr, $f, $d) { [PsMusic]::BeepOn($tr, $f, $d) }".to_string());
    } else {
        if tl.has_gs {
            lines.push(
                "function Prog($ch, $p) { [PsMusic]::Send((0xC0 -bor $ch), $p, 0) }".to_string(),
            );
            lines.push(
                "function On($ch, $n, $v) { [PsMusic]::Send((0x90 -bor $ch), $n, $v) }".to_string(),
            );
            lines.push(
                "function Off($ch, $n) { [PsMusic]::Send((0x80 -bor $ch), $n, 0) }".to_string(),
            );
        }
        if tl.has_beep {
            lines.push("function B($f, $d) { [PsMusic]::Beep($f, $d) }".to_string());
        }
    }

    lines.push("try {".to_string());
    if tl.has_gs {
        lines.push("  [PsMusic]::Open()".to_string());
    }
    if visualizer {
        lines.push("  [PsMusic]::Start()".to_string());
    }

    for e in &tl.events {
        let tr = e.track_index.unwrap_or(0);
        let cmd = match e.kind.as_str() {
            "gs_prog" => format!(
                "Prog {} {}",
                e.ch.unwrap_or(0),
                e.program.unwrap_or(0)
            ),
            "gs_on" => {
                if visualizer {
                    format!(
                        "On {} {} {} {}",
                        tr,
                        e.ch.unwrap_or(0),
                        e.pitch.unwrap_or(60),
                        e.vel.unwrap_or(100)
                    )
                } else {
                    format!(
                        "On {} {} {}",
                        e.ch.unwrap_or(0),
                        e.pitch.unwrap_or(60),
                        e.vel.unwrap_or(100)
                    )
                }
            }
            "gs_off" => {
                if visualizer {
                    format!("Off {} {} {}", tr, e.ch.unwrap_or(0), e.pitch.unwrap_or(60))
                } else {
                    format!("Off {} {}", e.ch.unwrap_or(0), e.pitch.unwrap_or(60))
                }
            }
            "beep" => {
                if visualizer {
                    format!(
                        "B {} {} {}",
                        tr,
                        e.freq.unwrap_or(440),
                        e.dur_ms.unwrap_or(100)
                    )
                } else {
                    format!("B {} {}", e.freq.unwrap_or(440), e.dur_ms.unwrap_or(100))
                }
            }
            _ => String::new(),
        };
        if !cmd.is_empty() {
            lines.push(format!("  W {}; {}", e.t_ms.round() as i64, cmd));
        }
    }

    lines.push(format!("  W {}", tl.end_ms.round() as i64));
    lines.push("} finally {".to_string());
    lines.push("  [PsMusic]::Close()".to_string());
    lines.push("}".to_string());

    lines.join("\r\n") + "\r\n"
}
