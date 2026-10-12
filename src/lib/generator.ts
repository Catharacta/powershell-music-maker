// タイムライン → PowerShell 5.1 / 7 両対応の .ps1 文字列
// 出力スクリプトは UTF-8 BOM付きで保存されるため日本語も完全対応。
import type { Project } from './model';
import type { Timeline } from './timeline';

/** 改行・制御文字を除去し、PowerShell文字列として安全にする */
function sanitizeText(s: string): string {
  return s.replace(/[\r\n]/g, ' ').replace(/[\x00-\x1f\x7f]/g, '').trim();
}

export interface GeneratorOptions {
  visualizer?: boolean;
  title?: string;
  artist?: string;
}

export function generateScript(p: Project, tl: Timeline, options: GeneratorOptions = {}): string {
  const visualizer = options.visualizer ?? true;
  const title = options.title ?? '';
  const artist = options.artist ?? '';
  const hasGs = p.tracks.some((t) => t.output === 'gs') || tl.hasGs;
  const hasBeep = p.tracks.some((t) => t.output === 'beep') || tl.hasBeep;
  const L: string[] = [];

  L.push('# PowerShell Music Maker generated script (PowerShell 5.1 / 7)');
  L.push(`# BPM=${p.bpm}  tracks: ` + p.tracks.map((t) => `${sanitizeText(t.name)}[${t.output}]`).join(', '));
  L.push("if (-not ('PsMusic' -as [type])) {");
  L.push("Add-Type -TypeDefinition @'");
  L.push('using System;');
  L.push('using System.Text;');
  L.push('using System.Diagnostics;');
  L.push('using System.Threading;');
  L.push('using System.Runtime.InteropServices;');

  L.push(`
public class TrackState {
  public string Name;
  public string Type;
  public int Channel;
  public double Volume;
  public int Freq;
  public string NoteName = "-";
}`);

  L.push('public class PsMusic {');
  L.push('  public static volatile bool Running = false;');
  L.push('  public static volatile bool Loop = false;');
  L.push('  public static volatile bool Paused = false;');
  L.push('  public static bool ShouldLoop() { return Running && Loop; }');
  L.push('  public static void ResetLoop() { Paused = false; if (Sw != null) { Sw.Reset(); Sw.Start(); } else { Sw = Stopwatch.StartNew(); } }');
  L.push(`  public static void Wait(int targetMs) {
    while (Running) {
      if (Paused) { Thread.Sleep(20); continue; }
      if (Sw == null) return;
      int d = targetMs - (int)Sw.ElapsedMilliseconds;
      if (d <= 0) break;
      if (d > 15) Thread.Sleep(Math.Min(d - 5, 20));
      else Thread.SpinWait(10);
    }
  }`);

  L.push(`  [DllImport("kernel32.dll", SetLastError = true)]
  private static extern IntPtr GetStdHandle(int nStdHandle);
  [DllImport("kernel32.dll")]
  private static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
  [DllImport("kernel32.dll")]
  private static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);

  private const int STD_OUTPUT_HANDLE = -11;
  private const uint ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004;
  private static uint originalConsoleMode = 0;
  private static bool vtEnabled = false;

  private static void EnableVT() {
    try {
      IntPtr hOut = GetStdHandle(STD_OUTPUT_HANDLE);
      uint mode = 0;
      if (GetConsoleMode(hOut, out mode)) {
        originalConsoleMode = mode;
        SetConsoleMode(hOut, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
        vtEnabled = true;
      }
    } catch {}
  }

  private static void RestoreVT() {
    try {
      if (vtEnabled && originalConsoleMode != 0) {
        IntPtr hOut = GetStdHandle(STD_OUTPUT_HANDLE);
        SetConsoleMode(hOut, originalConsoleMode);
      }
    } catch {}
  }`);

  // WinMM MIDI support
  L.push(`  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
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
  }`);

  // Beep support
  L.push(`  public static void Beep(int f, int d) {
    Thread t = new Thread(delegate() { try { Console.Beep(f, d); } catch (Exception) { } });
    t.IsBackground = true; t.Start();
  }`);

  // Visualizer fields & methods
  L.push(`  public static TrackState[] Tracks;
  public static int TotalMs;
  public static int Bpm;
  public static string Title;
  public static string Artist;
  public static Stopwatch Sw;
  private static Thread RenderThread;
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
    Paused = false;
    Sw = Stopwatch.StartNew();
    Running = true;
    EnableVT();
    try { Console.Write("\\x1b[?1049h\\x1b[?25l\\x1b[2J\\x1b[H"); } catch {}
    RenderThread = new Thread(RenderLoop);
    RenderThread.IsBackground = true;
    RenderThread.Start();
  }

  public static void On(int tr, int ch, int pitch, int vel) {
    ${hasGs ? 'Send(0x90 | ch, pitch, vel);' : ''}
    if (Tracks != null && tr >= 0 && tr < Tracks.Length) {
      Tracks[tr].Volume = Math.Min(100, Math.Max(25, vel));
      Tracks[tr].Freq = (int)Math.Round(440.0 * Math.Pow(2.0, (pitch - 69) / 12.0));
      Tracks[tr].NoteName = PitchToName(pitch);
    }
  }

  public static void Off(int tr, int ch, int pitch) {
    ${hasGs ? 'Send(0x80 | ch, pitch, 0);' : ''}
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

  private static int GetCharWidth(char c) {
    return (c > 0x7F && (c < 0xFF61 || c > 0xFF9F)) ? 2 : 1;
  }

  private static string PadToWidth(string text, int targetWidth) {
    if (text == null) text = "";
    int currentWidth = 0;
    StringBuilder sb = new StringBuilder();
    foreach (char c in text) {
      int cw = GetCharWidth(c);
      if (currentWidth + cw > targetWidth) break;
      sb.Append(c);
      currentWidth += cw;
    }
    if (currentWidth < targetWidth) {
      sb.Append(new string(' ', targetWidth - currentWidth));
    }
    return sb.ToString();
  }

  private const int InnerWidth = 58;
  private const string Border = "+------------------------------------------------------------+";

  private static string BoxRow(string text) {
    return "| " + PadToWidth(text, InnerWidth) + " |";
  }

  private static double phase = 0;
  private static readonly char[] waveChars = new char[] { ' ', '.', ':', '-', '=', '#', '%' };

  private static void DrawUi(int elapsedMs, int totalMs, double progress) {
    StringBuilder sb = new StringBuilder();
    sb.Append("\\x1b[H");

    sb.AppendLine(Border);
    sb.AppendLine(BoxRow("POWERSHELL MUSIC MAKER"));
    if (!string.IsNullOrEmpty(Title)) {
      sb.AppendLine(BoxRow("TITLE : " + Title));
    }
    if (!string.IsNullOrEmpty(Artist)) {
      sb.AppendLine(BoxRow("ARTIST: " + Artist));
    }

    int progLen = 20;
    int filled = (int)Math.Round(progress * progLen);
    filled = Math.Max(0, Math.Min(progLen, filled));
    string progBar = "[" + new string('=', filled) + (filled < progLen ? ">" : "") + new string(' ', Math.Max(0, progLen - filled - (filled < progLen ? 1 : 0))) + "]";
    string timeStr = string.Format("TIME : {0:D2}:{1:D2} / {2:D2}:{3:D2}  {4} {5,4:P0}",
      (elapsedMs / 1000) / 60, (elapsedMs / 1000) % 60,
      (totalMs / 1000) / 60, (totalMs / 1000) % 60,
      progBar, progress);
    sb.AppendLine(BoxRow(timeStr));
    string loopStr = Loop ? "ON " : "OFF";
    string statusHelp = Paused ? "[PAUSED] (Space: Resume, Q: Quit)" : "(Space: Pause, L: Loop, Q: Quit)";
    sb.AppendLine(BoxRow(string.Format("BPM  : {0,-4} LOOP: [{1}] {2}", Bpm, loopStr, statusHelp)));
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
        string trName = PadToWidth(tr.Name, 11);
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
      Console.Write(sb.ToString());
    } catch {}
  }

  private static void RenderLoop() {
    try {
      while (Running) {
        try {
          if (Console.KeyAvailable) {
            var k = Console.ReadKey(true);
            if (k.Key == ConsoleKey.Spacebar || k.Key == ConsoleKey.P) {
              Paused = !Paused;
              if (Paused) {
                if (Sw != null) Sw.Stop();
                if (hOut != IntPtr.Zero) {
                  for (int ch = 0; ch < 16; ch++) Send(0xB0 | ch, 123, 0);
                }
                if (Tracks != null) {
                  for (int t = 0; t < Tracks.Length; t++) {
                    Tracks[t].Volume = 0;
                    Tracks[t].NoteName = "-";
                  }
                }
              } else {
                if (Sw != null) Sw.Start();
              }
            } else if (k.Key == ConsoleKey.L) {
              Loop = !Loop;
            } else if (k.Key == ConsoleKey.Q || k.Key == ConsoleKey.Escape) {
              Running = false;
            }
          }
        } catch {}

        int elapsedMs = Sw != null ? (int)Sw.ElapsedMilliseconds : 0;
        double progress = Math.Min(1.0, (double)elapsedMs / Math.Max(1, TotalMs));
        DrawUi(elapsedMs, TotalMs, progress);

        if (!Paused) {
          if (Tracks != null) {
            for (int t = 0; t < Tracks.Length; t++) {
              Tracks[t].Volume = Math.Max(0, Tracks[t].Volume * 0.88);
              if (Tracks[t].Volume < 2) Tracks[t].NoteName = "-";
            }
          }
          phase += 0.35;
        }

        Thread.Sleep(33);
      }
    } catch {}
  }`);

  L.push(`  public static void Close() {
    Running = false;
    Paused = false;
    if (RenderThread != null && RenderThread.IsAlive) { RenderThread.Join(400); }
    try { Console.Write("\\x1b[?25h\\x1b[?1049l"); } catch {}
    RestoreVT();
    if (hOut != IntPtr.Zero) {
      for (int ch = 0; ch < 16; ch++) Send(0xB0 | ch, 123, 0);
      midiOutClose(hOut); hOut = IntPtr.Zero;
    }
  }`);

  L.push('}');
  L.push("'@");
  L.push('}');

  if (visualizer) {
    const safeTitle = sanitizeText(title).replace(/'/g, "''");
    const safeArtist = sanitizeText(artist).replace(/'/g, "''");
    const trackNames = p.tracks.map((t) => `'${sanitizeText(t.name).replace(/'/g, "''")}'`).join(', ');
    const trackTypes = p.tracks.map((t) => `'${t.output.toUpperCase()}'`).join(', ');
    const trackChannels = p.tracks.map((t) => t.channel).join(', ');
    L.push(`[PsMusic]::Init(${tl.endMs}, ${p.bpm}, '${safeTitle}', '${safeArtist}', @(${trackNames}), @(${trackTypes}), @(${trackChannels}))`);
  }

  L.push('# Wait until the absolute time (no accumulated drift)');
  if (visualizer) {
    L.push('function W([int]$t) { [PsMusic]::Wait($t) }');
  } else {
    L.push('$sw = [Diagnostics.Stopwatch]::StartNew()');
    L.push('function W([int]$t) { $d = $t - [int]$sw.ElapsedMilliseconds; if ($d -gt 0) { Start-Sleep -Milliseconds $d } }');
  }

  if (visualizer) {
    if (hasGs) {
      L.push('function Prog($ch, $p) { [PsMusic]::Send((0xC0 -bor $ch), $p, 0) }');
      L.push('function On($tr, $ch, $n, $v) { [PsMusic]::On($tr, $ch, $n, $v) }');
      L.push('function Off($tr, $ch, $n) { [PsMusic]::Off($tr, $ch, $n) }');
    }
    L.push('function B($tr, $f, $d) { [PsMusic]::BeepOn($tr, $f, $d) }');
  } else {
    if (hasGs) {
      L.push('function Prog($ch, $p) { [PsMusic]::Send((0xC0 -bor $ch), $p, 0) }');
      L.push('function On($ch, $n, $v) { [PsMusic]::Send((0x90 -bor $ch), $n, $v) }');
      L.push('function Off($ch, $n) { [PsMusic]::Send((0x80 -bor $ch), $n, 0) }');
    }
    if (hasBeep) L.push('function B($f, $d) { [PsMusic]::Beep($f, $d) }');
  }

  L.push('try {');
  if (hasGs) {
    L.push('  [PsMusic]::Open()');
  } else if (hasBeep) {
    L.push('  try { [Console]::Beep(37, 1) } catch {}');
  }
  if (visualizer) L.push('  [PsMusic]::Start()');

  L.push('  do {');
  if (!visualizer) {
    L.push('    $sw.Restart()');
  } else {
    L.push('    [PsMusic]::ResetLoop()');
  }

  for (const e of tl.events) {
    let cmd = '';
    const tr = e.trackIndex ?? 0;
    switch (e.kind) {
      case 'gs_prog':
        cmd = `Prog ${e.ch} ${e.program}`;
        break;
      case 'gs_on':
        cmd = visualizer ? `On ${tr} ${e.ch} ${e.pitch} ${e.vel}` : `On ${e.ch} ${e.pitch} ${e.vel}`;
        break;
      case 'gs_off':
        cmd = visualizer ? `Off ${tr} ${e.ch} ${e.pitch}` : `Off ${e.ch} ${e.pitch}`;
        break;
      case 'beep':
        cmd = visualizer ? `B ${tr} ${e.freq} ${e.durMs}` : `B ${e.freq} ${e.durMs}`;
        break;
    }
    L.push(`    W ${e.tMs}; ${cmd}`);
  }
  L.push(`    W ${tl.endMs}`);
  L.push('  } while ([PsMusic]::ShouldLoop())');
  L.push('} finally {');
  L.push('  [PsMusic]::Close()');
  L.push('}');
  return L.join('\r\n') + '\r\n';
}
