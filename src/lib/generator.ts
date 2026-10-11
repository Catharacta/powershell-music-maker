// タイムライン → PowerShell 5.1 / 7 両対応の .ps1 文字列
// 出力スクリプトは文字化け防止のため ASCII(英語)のみを使う。
import type { Project } from './model';
import type { Timeline } from './timeline';

/** 非ASCII文字を '?' に置換し、改行を除去する */
function ascii(s: string): string {
  return s.replace(/[\r\n]/g, ' ').replace(/[^\x20-\x7e]/g, '?');
}

export interface GeneratorOptions {
  visualizer?: boolean;
}

export function generateScript(p: Project, tl: Timeline, options: GeneratorOptions = {}): string {
  const visualizer = options.visualizer ?? true;
  const L: string[] = [];

  L.push('# PowerShell Music Maker generated script (PowerShell 5.1 / 7)');
  L.push(`# BPM=${p.bpm}  tracks: ` + p.tracks.map((t) => `${ascii(t.name)}[${t.output}]`).join(', '));
  L.push("if (-not ('PsMusic' -as [type])) {");
  L.push("Add-Type -TypeDefinition @'");
  L.push('using System;');
  L.push('using System.Text;');
  L.push('using System.Diagnostics;');
  L.push('using System.Threading;');
  L.push('using System.Runtime.InteropServices;');

  if (visualizer) {
    L.push(`
public class TrackState {
  public string Name;
  public string Type;
  public int Channel;
  public double Volume;
  public int Freq;
  public string NoteName = "-";
}`);
  }

  L.push('public class PsMusic {');

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

  if (visualizer) {
    // Visualizer fields & methods
    L.push(`  public static TrackState[] Tracks;
  public static int TotalMs;
  public static int Bpm;
  public static Stopwatch Sw;
  private static Thread RenderThread;
  private static volatile bool Running = false;
  private static readonly string[] PitchNames = new string[] {
    "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"
  };

  public static void Init(int totalMs, int bpm, string[] names, string[] types, int[] channels) {
    TotalMs = totalMs;
    Bpm = bpm;
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

      int progLen = 20;
      int filled = (int)(progress * progLen);
      string progBar = "[" + new string('=', filled) + (filled < progLen ? ">" : "") + new string(' ', Math.Max(0, progLen - filled - (filled < progLen ? 1 : 0))) + "]";
      string timeStr = string.Format("TIME: {0:D2}:{1:D2} / {2:D2}:{3:D2}  {4} {5,4:P0}",
        (elapsedMs / 1000) / 60, (elapsedMs / 1000) % 60,
        (TotalMs / 1000) / 60, (TotalMs / 1000) % 60,
        progBar, progress);
      sb.AppendLine(BoxRow(timeStr));
      sb.AppendLine(BoxRow(string.Format("BPM : {0}", Bpm)));
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
  }`);
  }

  // Close method
  L.push(`  public static void Close() {
    ${visualizer ? 'Running = false;' : ''}
    ${visualizer ? 'if (RenderThread != null && RenderThread.IsAlive) { RenderThread.Join(400); }' : ''}
    ${visualizer ? 'try { Console.CursorVisible = true; } catch {}' : ''}
    if (hOut != IntPtr.Zero) {
      for (int ch = 0; ch < 16; ch++) Send(0xB0 | ch, 123, 0);
      midiOutClose(hOut); hOut = IntPtr.Zero;
    }
    ${visualizer ? 'Console.WriteLine();' : ''}
  }`);

  L.push('}');
  L.push("'@");
  L.push('}');

  if (visualizer) {
    const trackNames = p.tracks.map((t) => `'${ascii(t.name).replace(/'/g, "''")}'`).join(', ');
    const trackTypes = p.tracks.map((t) => `'${t.output.toUpperCase()}'`).join(', ');
    const trackChannels = p.tracks.map((t) => t.channel).join(', ');
    L.push(`[PsMusic]::Init(${tl.endMs}, ${p.bpm}, @(${trackNames}), @(${trackTypes}), @(${trackChannels}))`);
  }

  L.push('# Wait until the absolute time with Start-Sleep (no accumulated drift)');
  L.push('$sw = [Diagnostics.Stopwatch]::StartNew()');
  L.push('function W([int]$t) { $d = $t - [int]$sw.ElapsedMilliseconds; if ($d -gt 0) { Start-Sleep -Milliseconds $d } }');

  if (visualizer) {
    L.push('function Prog($ch, $p) { [PsMusic]::Send((0xC0 -bor $ch), $p, 0) }');
    L.push('function On($tr, $ch, $n, $v) { [PsMusic]::On($tr, $ch, $n, $v) }');
    L.push('function Off($tr, $ch, $n) { [PsMusic]::Off($tr, $ch, $n) }');
    L.push('function B($tr, $f, $d) { [PsMusic]::BeepOn($tr, $f, $d) }');
  } else {
    if (tl.hasGs) {
      L.push('function Prog($ch, $p) { [PsMusic]::Send((0xC0 -bor $ch), $p, 0) }');
      L.push('function On($ch, $n, $v) { [PsMusic]::Send((0x90 -bor $ch), $n, $v) }');
      L.push('function Off($ch, $n) { [PsMusic]::Send((0x80 -bor $ch), $n, 0) }');
    }
    if (tl.hasBeep) L.push('function B($f, $d) { [PsMusic]::Beep($f, $d) }');
  }

  L.push('try {');
  if (tl.hasGs) L.push('  [PsMusic]::Open()');
  if (visualizer) L.push('  [PsMusic]::Start()');

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
    L.push(`  W ${e.tMs}; ${cmd}`);
  }
  L.push(`  W ${tl.endMs}`);
  L.push('} finally {');
  L.push('  [PsMusic]::Close()');
  L.push('}');
  return L.join('\r\n') + '\r\n';
}
