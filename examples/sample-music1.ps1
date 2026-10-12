# PowerShell Music Maker generated script (PowerShell 5.1 / 7)
# BPM=105  tracks: Vibraphon[gs]
if (-not ('PsMusic' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Diagnostics;
using System.Threading;
using System.Runtime.InteropServices;

public class TrackState {
  public string Name;
  public string Type;
  public int Channel;
  public double Volume;
  public int Freq;
  public string NoteName = "-";
}
public class PsMusic {
  public static volatile bool Running = false;
  public static volatile bool Loop = false;
  public static volatile bool Paused = false;
  public static bool ShouldLoop() { return Running && Loop; }
  public static void ResetLoop() { Paused = false; if (Sw != null) { Sw.Reset(); Sw.Start(); } else { Sw = Stopwatch.StartNew(); } }
  public static void Wait(int targetMs) {
    while (Running) {
      if (Paused) { Thread.Sleep(20); continue; }
      if (Sw == null) return;
      int d = targetMs - (int)Sw.ElapsedMilliseconds;
      if (d <= 0) break;
      if (d > 15) Thread.Sleep(Math.Min(d - 5, 20));
      else Thread.SpinWait(10);
    }
  }
  [DllImport("kernel32.dll", SetLastError = true)]
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
  }
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
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
  }
  public static void Beep(int f, int d) {
    Thread t = new Thread(delegate() { try { Console.Beep(f, d); } catch (Exception) { } });
    t.IsBackground = true; t.Start();
  }
  public static TrackState[] Tracks;
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
    try { Console.Write("\x1b[?1049h\x1b[?25l\x1b[2J\x1b[H"); } catch {}
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
    sb.Append("\x1b[H");

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
  }
  public static void Close() {
    Running = false;
    Paused = false;
    if (RenderThread != null && RenderThread.IsAlive) { RenderThread.Join(400); }
    try { Console.Write("\x1b[?25h\x1b[?1049l"); } catch {}
    RestoreVT();
    if (hOut != IntPtr.Zero) {
      for (int ch = 0; ch < 16; ch++) Send(0xB0 | ch, 123, 0);
      midiOutClose(hOut); hOut = IntPtr.Zero;
    }
  }
}
'@
}
[PsMusic]::Init(231643, 105, 'Promenade 1, Gnomus', 'Mussorgsky, Modest Petrovich', @('Vibraphon'), @('GS'), @(0))
# Wait until the absolute time (no accumulated drift)
function W([int]$t) { [PsMusic]::Wait($t) }
function Prog($ch, $p) { [PsMusic]::Send((0xC0 -bor $ch), $p, 0) }
function On($tr, $ch, $n, $v) { [PsMusic]::On($tr, $ch, $n, $v) }
function Off($tr, $ch, $n) { [PsMusic]::Off($tr, $ch, $n) }
function B($tr, $f, $d) { [PsMusic]::BeepOn($tr, $f, $d) }
try {
  [PsMusic]::Open()
  [PsMusic]::Start()
  do {
    [PsMusic]::ResetLoop()
    W 0; Prog 0 11
    W 3149; On 0 0 67 81
    W 3375; Off 0 0 67
    W 3702; On 0 0 65 84
    W 3917; Off 0 0 65
    W 4244; On 0 0 70 82
    W 4488; Off 0 0 70
    W 4786; On 0 0 72 93
    W 5042; Off 0 0 72
    W 5054; On 0 0 77 96
    W 5310; Off 0 0 77
    W 5333; On 0 0 74 92
    W 5565; Off 0 0 74
    W 5845; On 0 0 72 90
    W 6089; Off 0 0 72
    W 6095; On 0 0 77 94
    W 6333; Off 0 0 77
    W 6387; On 0 0 74 87
    W 6702; Off 0 0 74
    W 6935; On 0 0 70 82
    W 7244; Off 0 0 70
    W 7476; On 0 0 72 94
    W 7738; Off 0 0 72
    W 8012; On 0 0 67 82
    W 8524; Off 0 0 67
    W 8542; On 0 0 65 83
    W 8774; Off 0 0 65
    W 9113; On 0 0 67 59
    W 9113; On 0 0 58 33
    W 9113; On 0 0 62 51
    W 9113; On 0 0 43 44
    W 9113; On 0 0 55 41
    W 9244; Off 0 0 43
    W 9244; Off 0 0 55
    W 9250; Off 0 0 62
    W 9327; Off 0 0 67
    W 9327; Off 0 0 58
    W 9655; On 0 0 65 68
    W 9655; On 0 0 45 55
    W 9655; On 0 0 60 53
    W 9655; On 0 0 57 51
    W 9696; On 0 0 53 46
    W 9732; Off 0 0 45
    W 9762; Off 0 0 60
    W 9792; Off 0 0 57
    W 9792; Off 0 0 53
    W 9851; Off 0 0 65
    W 10185; On 0 0 70 74
    W 10185; On 0 0 43 45
    W 10185; On 0 0 62 65
    W 10185; On 0 0 58 57
    W 10185; On 0 0 55 41
    W 10280; Off 0 0 43
    W 10280; Off 0 0 62
    W 10280; Off 0 0 55
    W 10339; Off 0 0 58
    W 10381; Off 0 0 70
    W 10714; On 0 0 72 82
    W 10714; On 0 0 60 70
    W 10714; On 0 0 41 47
    W 10714; On 0 0 69 66
    W 10714; On 0 0 53 58
    W 10756; Off 0 0 41
    W 10762; Off 0 0 53
    W 10786; Off 0 0 60
    W 10804; Off 0 0 69
    W 10833; Off 0 0 72
    W 10976; On 0 0 77 90
    W 11083; Off 0 0 77
    W 11262; On 0 0 74 83
    W 11262; On 0 0 65 66
    W 11262; On 0 0 69 73
    W 11262; On 0 0 50 56
    W 11262; On 0 0 38 43
    W 11351; Off 0 0 38
    W 11381; Off 0 0 50
    W 11393; Off 0 0 69
    W 11411; Off 0 0 65
    W 11423; Off 0 0 74
    W 11768; On 0 0 72 87
    W 11768; On 0 0 60 73
    W 11768; On 0 0 69 66
    W 11768; On 0 0 53 58
    W 11768; On 0 0 41 56
    W 11815; Off 0 0 41
    W 11845; Off 0 0 60
    W 11857; Off 0 0 53
    W 11863; Off 0 0 69
    W 11887; Off 0 0 72
    W 12042; On 0 0 77 89
    W 12143; Off 0 0 77
    W 12333; On 0 0 74 86
    W 12333; On 0 0 65 65
    W 12333; On 0 0 46 56
    W 12333; On 0 0 58 50
    W 12333; On 0 0 70 62
    W 12482; Off 0 0 70
    W 12500; Off 0 0 65
    W 12500; Off 0 0 46
    W 12506; Off 0 0 58
    W 12518; Off 0 0 74
    W 12851; On 0 0 70 77
    W 12851; On 0 0 62 67
    W 12851; On 0 0 43 54
    W 12851; On 0 0 55 51
    W 12851; On 0 0 67 56
    W 12940; Off 0 0 55
    W 12952; Off 0 0 43
    W 12994; Off 0 0 62
    W 13000; Off 0 0 67
    W 13113; Off 0 0 70
    W 13375; On 0 0 72 85
    W 13375; On 0 0 64 55
    W 13375; On 0 0 36 53
    W 13375; On 0 0 48 56
    W 13375; On 0 0 67 68
    W 13464; Off 0 0 36
    W 13476; Off 0 0 48
    W 13494; Off 0 0 67
    W 13500; Off 0 0 64
    W 13518; Off 0 0 72
    W 13917; On 0 0 67 72
    W 13917; On 0 0 60 59
    W 13917; On 0 0 52 53
    W 13917; On 0 0 40 46
    W 13917; On 0 0 55 53
    W 14000; Off 0 0 40
    W 14018; Off 0 0 52
    W 14054; Off 0 0 55
    W 14065; Off 0 0 60
    W 14113; Off 0 0 67
    W 14464; On 0 0 65 65
    W 14464; On 0 0 57 41
    W 14464; On 0 0 41 47
    W 14464; On 0 0 53 48
    W 14464; On 0 0 60 47
    W 14649; Off 0 0 41
    W 14673; Off 0 0 53
    W 14690; Off 0 0 57
    W 14702; Off 0 0 60
    W 14774; Off 0 0 65
    W 15060; On 0 0 65 86
    W 15577; Off 0 0 65
    W 15595; On 0 0 67 81
    W 16131; Off 0 0 67
    W 16131; On 0 0 62 79
    W 16530; Off 0 0 62
    W 16661; On 0 0 65 79
    W 16911; On 0 0 67 81
    W 16935; Off 0 0 65
    W 17208; Off 0 0 67
    W 17208; On 0 0 60 80
    W 17524; Off 0 0 60
    W 17750; On 0 0 67 77
    W 18000; On 0 0 69 84
    W 18018; Off 0 0 67
    W 18298; Off 0 0 69
    W 18298; On 0 0 65 82
    W 18530; Off 0 0 65
    W 18869; On 0 0 77 76
    W 18869; On 0 0 65 51
    W 18869; On 0 0 41 43
    W 18869; On 0 0 53 39
    W 18994; Off 0 0 41
    W 19006; Off 0 0 53
    W 19054; Off 0 0 77
    W 19089; Off 0 0 65
    W 19405; On 0 0 74 68
    W 19405; On 0 0 65 47
    W 19405; On 0 0 46 43
    W 19405; On 0 0 58 36
    W 19530; Off 0 0 58
    W 19536; Off 0 0 46
    W 19571; Off 0 0 74
    W 19577; Off 0 0 65
    W 19935; On 0 0 72 77
    W 19935; On 0 0 55 47
    W 19935; On 0 0 43 45
    W 19935; On 0 0 65 52
    W 20036; Off 0 0 43
    W 20048; Off 0 0 55
    W 20089; Off 0 0 72
    W 20089; Off 0 0 65
    W 20196; On 0 0 70 70
    W 20357; Off 0 0 70
    W 20500; On 0 0 65 70
    W 20500; On 0 0 53 45
    W 20500; On 0 0 41 40
    W 20667; Off 0 0 41
    W 20679; Off 0 0 53
    W 20750; Off 0 0 65
    W 21083; On 0 0 65 83
    W 21601; Off 0 0 65
    W 21613; On 0 0 67 84
    W 22149; Off 0 0 67
    W 22149; On 0 0 62 81
    W 22565; Off 0 0 62
    W 22690; On 0 0 65 82
    W 22976; On 0 0 67 87
    W 22982; Off 0 0 65
    W 23286; Off 0 0 67
    W 23292; On 0 0 63 78
    W 23589; Off 0 0 63
    W 23821; On 0 0 70 86
    W 24054; Off 0 0 70
    W 24071; On 0 0 72 99
    W 24351; Off 0 0 72
    W 24351; On 0 0 68 82
    W 24613; Off 0 0 68
    W 24923; On 0 0 80 72
    W 24923; On 0 0 68 39
    W 24923; On 0 0 44 37
    W 24923; On 0 0 56 36
    W 25071; Off 0 0 44
    W 25095; Off 0 0 56
    W 25143; Off 0 0 80
    W 25179; Off 0 0 68
    W 25482; On 0 0 77 74
    W 25482; On 0 0 68 51
    W 25482; On 0 0 49 44
    W 25482; On 0 0 61 44
    W 25595; Off 0 0 61
    W 25601; Off 0 0 49
    W 25673; Off 0 0 77
    W 25696; Off 0 0 68
    W 26012; On 0 0 75 71
    W 26012; On 0 0 46 54
    W 26012; On 0 0 68 45
    W 26012; On 0 0 58 45
    W 26113; Off 0 0 58
    W 26131; Off 0 0 46
    W 26149; Off 0 0 68
    W 26161; Off 0 0 75
    W 26268; On 0 0 73 68
    W 26446; Off 0 0 73
    W 26554; On 0 0 68 63
    W 26554; On 0 0 44 38
    W 26554; On 0 0 56 42
    W 26744; Off 0 0 56
    W 26756; Off 0 0 44
    W 26798; Off 0 0 68
    W 27196; On 0 0 68 63
    W 27196; On 0 0 56 51
    W 27196; On 0 0 30 38
    W 27196; On 0 0 42 51
    W 27196; On 0 0 63 37
    W 27452; Off 0 0 56
    W 27679; Off 0 0 68
    W 27714; On 0 0 70 74
    W 27714; On 0 0 58 52
    W 27935; Off 0 0 58
    W 27970; Off 0 0 42
    W 27994; Off 0 0 30
    W 28095; Off 0 0 70
    W 28173; Off 0 0 63
    W 28250; On 0 0 68 71
    W 28250; On 0 0 41 46
    W 28250; On 0 0 29 36
    W 28250; On 0 0 56 60
    W 28429; Off 0 0 56
    W 28476; Off 0 0 41
    W 28565; Off 0 0 29
    W 28607; Off 0 0 68
    W 28756; On 0 0 70 73
    W 28756; On 0 0 30 48
    W 28756; On 0 0 42 49
    W 28756; On 0 0 63 55
    W 28756; On 0 0 58 58
    W 28845; Off 0 0 63
    W 28857; Off 0 0 58
    W 28863; Off 0 0 70
    W 28887; Off 0 0 30
    W 29000; Off 0 0 42
    W 29006; On 0 0 72 88
    W 29006; On 0 0 60 60
    W 29036; Off 0 0 60
    W 29101; Off 0 0 72
    W 29256; On 0 0 75 83
    W 29256; On 0 0 63 64
    W 29256; On 0 0 30 39
    W 29256; On 0 0 42 44
    W 29298; Off 0 0 63
    W 29321; Off 0 0 30
    W 29339; Off 0 0 42
    W 29345; Off 0 0 75
    W 29506; On 0 0 70 80
    W 29506; On 0 0 58 77
    W 29583; Off 0 0 58
    W 29601; Off 0 0 70
    W 29810; On 0 0 68 72
    W 29810; On 0 0 54 50
    W 29810; On 0 0 42 44
    W 29810; On 0 0 56 69
    W 29964; Off 0 0 56
    W 29976; Off 0 0 42
    W 30006; Off 0 0 54
    W 30024; Off 0 0 68
    W 30280; On 0 0 73 88
    W 30280; On 0 0 65 48
    W 30280; On 0 0 53 74
    W 30280; On 0 0 41 77
    W 30280; On 0 0 68 71
    W 30280; On 0 0 61 77
    W 30315; Off 0 0 65
    W 30327; Off 0 0 41
    W 30339; Off 0 0 53
    W 30345; Off 0 0 68
    W 30345; Off 0 0 61
    W 30381; Off 0 0 73
    W 30542; On 0 0 75 88
    W 30542; On 0 0 63 76
    W 30542; On 0 0 72 82
    W 30542; On 0 0 39 63
    W 30542; On 0 0 51 71
    W 30542; On 0 0 68 62
    W 30571; Off 0 0 72
    W 30571; Off 0 0 51
    W 30571; Off 0 0 68
    W 30577; Off 0 0 39
    W 30613; Off 0 0 63
    W 30661; Off 0 0 75
    W 30827; On 0 0 77 90
    W 30827; On 0 0 49 78
    W 30827; On 0 0 68 65
    W 30827; On 0 0 65 73
    W 30827; On 0 0 73 71
    W 30827; On 0 0 37 69
    W 30863; Off 0 0 37
    W 30881; Off 0 0 49
    W 30881; Off 0 0 65
    W 30887; Off 0 0 68
    W 30923; Off 0 0 77
    W 30923; Off 0 0 73
    W 31095; On 0 0 80 81
    W 31095; On 0 0 68 82
    W 31131; Off 0 0 80
    W 31167; Off 0 0 68
    W 31339; On 0 0 78 83
    W 31339; On 0 0 39 71
    W 31339; On 0 0 51 81
    W 31339; On 0 0 75 69
    W 31339; On 0 0 66 80
    W 31339; On 0 0 70 69
    W 31399; Off 0 0 51
    W 31411; Off 0 0 39
    W 31417; Off 0 0 70
    W 31423; Off 0 0 75
    W 31435; Off 0 0 66
    W 31494; Off 0 0 78
    W 31589; On 0 0 77 90
    W 31589; On 0 0 65 69
    W 31589; On 0 0 53 79
    W 31589; On 0 0 41 72
    W 31589; On 0 0 70 72
    W 31589; On 0 0 73 73
    W 31643; Off 0 0 41
    W 31667; Off 0 0 53
    W 31667; Off 0 0 70
    W 31667; Off 0 0 73
    W 31679; Off 0 0 77
    W 31679; Off 0 0 65
    W 31875; On 0 0 63 72
    W 31875; On 0 0 75 75
    W 31875; On 0 0 56 72
    W 31875; On 0 0 44 68
    W 31875; On 0 0 68 57
    W 31875; On 0 0 72 68
    W 31911; Off 0 0 72
    W 31923; Off 0 0 44
    W 31923; Off 0 0 68
    W 31940; Off 0 0 56
    W 31952; Off 0 0 63
    W 32012; Off 0 0 75
    W 32131; On 0 0 78 80
    W 32131; On 0 0 66 67
    W 32238; Off 0 0 66
    W 32256; Off 0 0 78
    W 32369; On 0 0 77 89
    W 32369; On 0 0 73 67
    W 32369; On 0 0 65 65
    W 32369; On 0 0 70 67
    W 32369; On 0 0 58 67
    W 32369; On 0 0 46 62
    W 32417; Off 0 0 46
    W 32423; Off 0 0 65
    W 32435; Off 0 0 58
    W 32452; Off 0 0 77
    W 32470; Off 0 0 70
    W 32488; Off 0 0 73
    W 32625; On 0 0 73 85
    W 32631; On 0 0 61 77
    W 32702; Off 0 0 61
    W 32756; Off 0 0 73
    W 32905; On 0 0 75 83
    W 32917; On 0 0 63 62
    W 32923; On 0 0 56 63
    W 32929; On 0 0 72 68
    W 32935; On 0 0 44 57
    W 32935; On 0 0 68 61
    W 33006; Off 0 0 56
    W 33030; Off 0 0 44
    W 33042; Off 0 0 75
    W 33042; Off 0 0 63
    W 33042; Off 0 0 72
    W 33065; Off 0 0 68
    W 33470; On 0 0 56 59
    W 33476; On 0 0 68 67
    W 33494; On 0 0 63 44
    W 33500; On 0 0 42 56
    W 33506; On 0 0 30 44
    W 33732; Off 0 0 56
    W 33970; Off 0 0 68
    W 33982; On 0 0 70 76
    W 34000; On 0 0 58 55
    W 34292; Off 0 0 58
    W 34375; Off 0 0 42
    W 34393; Off 0 0 70
    W 34458; Off 0 0 63
    W 34470; Off 0 0 30
    W 34488; On 0 0 68 71
    W 34494; On 0 0 56 61
    W 34536; On 0 0 41 48
    W 34554; On 0 0 29 24
    W 34667; Off 0 0 56
    W 34744; Off 0 0 41
    W 34899; Off 0 0 29
    W 34923; Off 0 0 68
    W 35000; On 0 0 70 77
    W 35000; On 0 0 58 60
    W 35012; On 0 0 63 55
    W 35018; On 0 0 30 53
    W 35030; On 0 0 42 51
    W 35095; Off 0 0 30
    W 35101; Off 0 0 58
    W 35113; Off 0 0 42
    W 35131; Off 0 0 70
    W 35155; Off 0 0 63
    W 35244; On 0 0 72 92
    W 35262; On 0 0 60 67
    W 35327; Off 0 0 60
    W 35363; Off 0 0 72
    W 35506; On 0 0 75 84
    W 35524; On 0 0 63 60
    W 35524; On 0 0 54 59
    W 35542; On 0 0 42 50
    W 35583; Off 0 0 63
    W 35589; Off 0 0 75
    W 35613; Off 0 0 54
    W 35631; Off 0 0 42
    W 35738; On 0 0 70 88
    W 35738; On 0 0 58 80
    W 35810; Off 0 0 58
    W 35863; Off 0 0 70
    W 36089; On 0 0 72 94
    W 36095; On 0 0 60 78
    W 36107; On 0 0 67 65
    W 36119; On 0 0 46 67
    W 36125; On 0 0 34 55
    W 36214; Off 0 0 46
    W 36292; On 0 0 46 13
    W 36339; Off 0 0 60
    W 36571; Off 0 0 72
    W 36631; On 0 0 74 88
    W 36637; On 0 0 62 78
    W 36732; Off 0 0 67
    W 36780; Off 0 0 62
    W 36857; Off 0 0 46
    W 36893; Off 0 0 74
    W 36917; Off 0 0 34
    W 37131; On 0 0 72 80
    W 37149; On 0 0 60 74
    W 37167; On 0 0 45 68
    W 37190; On 0 0 33 43
    W 37333; Off 0 0 60
    W 37464; Off 0 0 45
    W 37530; Off 0 0 33
    W 37583; Off 0 0 72
    W 37685; On 0 0 74 92
    W 37685; On 0 0 62 82
    W 37708; On 0 0 34 58
    W 37714; On 0 0 46 62
    W 37762; Off 0 0 62
    W 37786; Off 0 0 74
    W 37786; Off 0 0 46
    W 37810; Off 0 0 34
    W 37905; On 0 0 77 94
    W 37917; On 0 0 65 82
    W 37982; Off 0 0 65
    W 37994; Off 0 0 77
    W 38167; On 0 0 79 92
    W 38173; On 0 0 34 55
    W 38179; On 0 0 46 58
    W 38185; On 0 0 67 72
    W 38214; Off 0 0 34
    W 38214; Off 0 0 67
    W 38226; Off 0 0 79
    W 38238; Off 0 0 46
    W 38405; On 0 0 74 90
    W 38417; On 0 0 62 70
    W 38452; Off 0 0 62
    W 38476; Off 0 0 74
    W 38708; On 0 0 72 92
    W 38714; On 0 0 60 82
    W 38714; On 0 0 46 63
    W 38720; On 0 0 58 67
    W 38798; Off 0 0 60
    W 38827; Off 0 0 46
    W 38827; Off 0 0 58
    W 38845; Off 0 0 72
    W 39238; On 0 0 77 94
    W 39238; On 0 0 65 82
    W 39238; On 0 0 72 83
    W 39244; On 0 0 69 80
    W 39262; On 0 0 45 79
    W 39262; On 0 0 57 70
    W 39298; Off 0 0 65
    W 39310; Off 0 0 69
    W 39315; Off 0 0 72
    W 39327; Off 0 0 45
    W 39333; Off 0 0 57
    W 39351; Off 0 0 77
    W 39500; On 0 0 79 94
    W 39500; On 0 0 67 88
    W 39506; On 0 0 76 78
    W 39506; On 0 0 72 80
    W 39518; On 0 0 55 78
    W 39524; On 0 0 43 70
    W 39548; Off 0 0 72
    W 39565; Off 0 0 67
    W 39565; Off 0 0 43
    W 39583; Off 0 0 55
    W 39601; Off 0 0 76
    W 39619; Off 0 0 79
    W 39756; On 0 0 81 94
    W 39762; On 0 0 72 84
    W 39762; On 0 0 69 82
    W 39768; On 0 0 77 78
    W 39780; On 0 0 53 76
    W 39786; On 0 0 41 70
    W 39821; Off 0 0 72
    W 39821; Off 0 0 41
    W 39827; Off 0 0 69
    W 39845; Off 0 0 53
    W 39857; Off 0 0 77
    W 39875; Off 0 0 81
    W 40000; On 0 0 84 92
    W 40012; On 0 0 72 90
    W 40071; Off 0 0 84
    W 40077; Off 0 0 72
    W 40244; On 0 0 82 82
    W 40256; On 0 0 79 85
    W 40262; On 0 0 70 85
    W 40274; On 0 0 55 69
    W 40280; On 0 0 43 69
    W 40280; On 0 0 74 63
    W 40310; Off 0 0 74
    W 40321; Off 0 0 43
    W 40333; Off 0 0 79
    W 40345; Off 0 0 55
    W 40351; Off 0 0 70
    W 40357; Off 0 0 82
    W 40518; On 0 0 81 89
    W 40524; On 0 0 77 81
    W 40530; On 0 0 69 74
    W 40536; On 0 0 72 75
    W 40542; On 0 0 57 74
    W 40548; On 0 0 45 74
    W 40571; On 0 0 55 33
    W 40577; Off 0 0 45
    W 40595; Off 0 0 69
    W 40607; Off 0 0 55
    W 40619; Off 0 0 72
    W 40619; Off 0 0 57
    W 40625; Off 0 0 81
    W 40649; Off 0 0 77
    W 40786; On 0 0 79 89
    W 40786; On 0 0 76 81
    W 40798; On 0 0 67 81
    W 40798; On 0 0 72 75
    W 40815; On 0 0 48 79
    W 40815; On 0 0 60 77
    W 40827; Off 0 0 72
    W 40851; Off 0 0 67
    W 40851; Off 0 0 48
    W 40881; Off 0 0 79
    W 40887; Off 0 0 76
    W 40887; Off 0 0 60
    W 41030; On 0 0 82 83
    W 41048; On 0 0 70 71
    W 41113; Off 0 0 70
    W 41149; Off 0 0 82
    W 41292; On 0 0 81 89
    W 41304; On 0 0 77 81
    W 41310; On 0 0 69 74
    W 41315; On 0 0 74 64
    W 41327; On 0 0 62 75
    W 41333; On 0 0 50 68
    W 41351; Off 0 0 74
    W 41375; Off 0 0 50
    W 41381; Off 0 0 69
    W 41387; Off 0 0 81
    W 41387; Off 0 0 77
    W 41387; Off 0 0 62
    W 41554; On 0 0 77 90
    W 41560; On 0 0 65 80
    W 41625; Off 0 0 65
    W 41643; Off 0 0 77
    W 41857; On 0 0 79 89
    W 41857; On 0 0 76 76
    W 41863; On 0 0 67 69
    W 41875; On 0 0 72 64
    W 41881; On 0 0 48 68
    W 41881; On 0 0 60 56
    W 41976; Off 0 0 60
    W 42006; Off 0 0 48
    W 42024; Off 0 0 67
    W 42036; Off 0 0 79
    W 42036; Off 0 0 72
    W 42054; Off 0 0 76
    W 42387; On 0 0 81 84
    W 42411; On 0 0 69 65
    W 42417; On 0 0 72 64
    W 42435; On 0 0 57 52
    W 42452; On 0 0 45 52
    W 42571; Off 0 0 81
    W 42649; Off 0 0 69
    W 42649; Off 0 0 72
    W 42667; On 0 0 76 89
    W 42714; Off 0 0 57
    W 42798; Off 0 0 45
    W 42887; Off 0 0 76
    W 42952; On 0 0 77 88
    W 42964; On 0 0 74 67
    W 42964; On 0 0 65 67
    W 42988; On 0 0 58 51
    W 42994; On 0 0 46 53
    W 43089; Off 0 0 65
    W 43107; Off 0 0 58
    W 43125; Off 0 0 77
    W 43125; Off 0 0 74
    W 43155; Off 0 0 46
    W 43464; On 0 0 81 83
    W 43494; On 0 0 72 75
    W 43494; On 0 0 69 68
    W 43500; On 0 0 41 58
    W 43506; On 0 0 53 56
    W 43589; Off 0 0 72
    W 43595; Off 0 0 69
    W 43595; Off 0 0 41
    W 43601; Off 0 0 81
    W 43601; Off 0 0 53
    W 43970; On 0 0 74 77
    W 43982; On 0 0 64 61
    W 43994; On 0 0 70 58
    W 44006; On 0 0 55 62
    W 44024; On 0 0 43 32
    W 44077; Off 0 0 64
    W 44119; Off 0 0 70
    W 44125; Off 0 0 74
    W 44143; Off 0 0 55
    W 44143; Off 0 0 43
    W 44488; On 0 0 81 81
    W 44512; On 0 0 69 67
    W 44518; On 0 0 72 68
    W 44542; On 0 0 53 53
    W 44548; On 0 0 41 52
    W 44637; Off 0 0 81
    W 44673; Off 0 0 69
    W 44673; Off 0 0 72
    W 44673; Off 0 0 41
    W 44702; Off 0 0 53
    W 45036; On 0 0 74 79
    W 45042; On 0 0 64 62
    W 45048; On 0 0 70 58
    W 45060; On 0 0 55 55
    W 45083; On 0 0 43 49
    W 45208; Off 0 0 55
    W 45214; Off 0 0 70
    W 45220; Off 0 0 64
    W 45250; Off 0 0 43
    W 45310; Off 0 0 74
    W 45560; On 0 0 77 86
    W 45571; On 0 0 69 72
    W 45571; On 0 0 65 67
    W 45589; On 0 0 50 59
    W 45589; On 0 0 38 54
    W 45690; Off 0 0 38
    W 45714; Off 0 0 50
    W 45744; Off 0 0 77
    W 45750; Off 0 0 69
    W 45762; Off 0 0 65
    W 45804; On 0 0 72 96
    W 46024; Off 0 0 72
    W 46083; On 0 0 74 85
    W 46095; On 0 0 70 59
    W 46101; On 0 0 65 62
    W 46113; On 0 0 55 56
    W 46131; On 0 0 43 48
    W 46250; Off 0 0 70
    W 46256; Off 0 0 55
    W 46274; Off 0 0 43
    W 46310; Off 0 0 65
    W 46399; Off 0 0 74
    W 46607; On 0 0 77 86
    W 46619; On 0 0 69 73
    W 46625; On 0 0 65 62
    W 46655; On 0 0 50 54
    W 46661; On 0 0 38 55
    W 46762; Off 0 0 38
    W 46774; Off 0 0 69
    W 46786; Off 0 0 50
    W 46869; Off 0 0 65
    W 46923; Off 0 0 77
    W 47149; On 0 0 74 82
    W 47167; On 0 0 70 60
    W 47167; On 0 0 65 64
    W 47179; On 0 0 55 62
    W 47196; On 0 0 43 54
    W 47274; Off 0 0 55
    W 47315; Off 0 0 70
    W 47315; Off 0 0 43
    W 47363; Off 0 0 65
    W 47381; Off 0 0 74
    W 47643; On 0 0 77 85
    W 47661; On 0 0 69 67
    W 47667; On 0 0 65 63
    W 47679; On 0 0 50 63
    W 47685; On 0 0 38 49
    W 47726; Off 0 0 50
    W 47726; Off 0 0 38
    W 47810; Off 0 0 77
    W 47827; Off 0 0 69
    W 47833; Off 0 0 65
    W 47899; On 0 0 72 94
    W 48083; Off 0 0 72
    W 48179; On 0 0 74 86
    W 48185; On 0 0 70 61
    W 48190; On 0 0 65 60
    W 48202; On 0 0 55 59
    W 48220; On 0 0 43 53
    W 48310; Off 0 0 55
    W 48315; Off 0 0 70
    W 48321; Off 0 0 74
    W 48321; Off 0 0 65
    W 48351; Off 0 0 43
    W 48690; On 0 0 72 79
    W 48708; On 0 0 63 51
    W 48720; On 0 0 67 58
    W 48738; On 0 0 48 58
    W 48744; On 0 0 36 51
    W 48810; Off 0 0 36
    W 48815; Off 0 0 63
    W 48839; Off 0 0 48
    W 48875; Off 0 0 67
    W 48940; Off 0 0 72
    W 48952; On 0 0 64 71
    W 49060; Off 0 0 64
    W 49244; On 0 0 69 80
    W 49262; On 0 0 53 53
    W 49268; On 0 0 65 60
    W 49268; On 0 0 60 55
    W 49280; On 0 0 41 49
    W 49423; Off 0 0 41
    W 49446; Off 0 0 69
    W 49446; Off 0 0 60
    W 49476; Off 0 0 53
    W 49494; Off 0 0 65
    W 49756; On 0 0 70 71
    W 49780; On 0 0 62 61
    W 49780; On 0 0 65 49
    W 49798; On 0 0 55 52
    W 49810; On 0 0 43 47
    W 49881; Off 0 0 65
    W 49887; Off 0 0 62
    W 49899; Off 0 0 55
    W 49946; Off 0 0 43
    W 49994; Off 0 0 70
    W 50268; On 0 0 72 77
    W 50286; On 0 0 67 59
    W 50286; On 0 0 63 43
    W 50292; On 0 0 36 54
    W 50298; On 0 0 48 62
    W 50375; Off 0 0 36
    W 50381; Off 0 0 67
    W 50387; Off 0 0 63
    W 50387; Off 0 0 48
    W 50452; Off 0 0 72
    W 50512; On 0 0 64 70
    W 50619; Off 0 0 64
    W 50804; On 0 0 69 82
    W 50827; On 0 0 65 63
    W 50827; On 0 0 60 47
    W 50839; On 0 0 53 56
    W 50851; On 0 0 41 52
    W 50964; Off 0 0 60
    W 51000; Off 0 0 69
    W 51000; Off 0 0 65
    W 51012; Off 0 0 41
    W 51048; Off 0 0 53
    W 51298; On 0 0 70 77
    W 51304; On 0 0 62 73
    W 51327; On 0 0 55 67
    W 51363; On 0 0 43 33
    W 51405; Off 0 0 55
    W 51429; Off 0 0 43
    W 51452; Off 0 0 62
    W 51494; Off 0 0 70
    W 51565; On 0 0 74 83
    W 51685; Off 0 0 74
    W 51845; On 0 0 72 85
    W 51863; On 0 0 64 63
    W 51863; On 0 0 67 68
    W 51869; On 0 0 48 61
    W 51875; On 0 0 36 55
    W 52018; Off 0 0 67
    W 52024; Off 0 0 72
    W 52048; Off 0 0 64
    W 52280; Off 0 0 36
    W 52357; Off 0 0 48
    W 52363; On 0 0 69 85
    W 52375; On 0 0 60 70
    W 52387; On 0 0 62 61
    W 52387; On 0 0 65 56
    W 52399; On 0 0 41 58
    W 52452; Off 0 0 62
    W 52470; Off 0 0 60
    W 52494; Off 0 0 65
    W 52530; Off 0 0 69
    W 52744; Off 0 0 41
    W 52881; On 0 0 72 86
    W 52905; On 0 0 64 63
    W 52905; On 0 0 67 66
    W 52911; On 0 0 48 63
    W 52917; On 0 0 36 58
    W 53018; Off 0 0 48
    W 53024; Off 0 0 64
    W 53030; Off 0 0 67
    W 53048; Off 0 0 36
    W 53060; Off 0 0 72
    W 53435; On 0 0 77 94
    W 53446; On 0 0 65 81
    W 53476; On 0 0 41 71
    W 53476; On 0 0 29 63
    W 53577; Off 0 0 29
    W 53589; Off 0 0 77
    W 53589; Off 0 0 41
    W 53619; Off 0 0 65
    W 53940; On 0 0 75 91
    W 53946; On 0 0 63 77
    W 53958; On 0 0 67 72
    W 53958; On 0 0 70 64
    W 53970; On 0 0 43 69
    W 53970; On 0 0 31 62
    W 54012; Off 0 0 43
    W 54012; Off 0 0 31
    W 54042; Off 0 0 67
    W 54065; Off 0 0 63
    W 54089; Off 0 0 75
    W 54107; Off 0 0 70
    W 54185; On 0 0 74 86
    W 54190; On 0 0 62 75
    W 54274; Off 0 0 74
    W 54274; Off 0 0 62
    W 54440; On 0 0 72 94
    W 54446; On 0 0 69 74
    W 54446; On 0 0 60 78
    W 54458; On 0 0 65 64
    W 54458; On 0 0 45 72
    W 54464; On 0 0 33 62
    W 54500; Off 0 0 45
    W 54506; Off 0 0 33
    W 54518; Off 0 0 60
    W 54524; Off 0 0 65
    W 54571; Off 0 0 69
    W 54577; Off 0 0 72
    W 54690; On 0 0 70 85
    W 54690; On 0 0 46 78
    W 54690; On 0 0 34 71
    W 54702; On 0 0 62 74
    W 54708; On 0 0 65 73
    W 54750; Off 0 0 46
    W 54762; Off 0 0 34
    W 54792; Off 0 0 62
    W 54815; Off 0 0 65
    W 54857; Off 0 0 70
    W 54976; On 0 0 72 99
    W 54988; On 0 0 60 80
    W 54988; On 0 0 65 83
    W 55000; On 0 0 45 85
    W 55006; On 0 0 33 71
    W 55083; Off 0 0 45
    W 55107; Off 0 0 33
    W 55137; Off 0 0 60
    W 55173; Off 0 0 65
    W 55179; Off 0 0 72
    W 55506; On 0 0 74 99
    W 55506; On 0 0 65 81
    W 55518; On 0 0 62 86
    W 55524; On 0 0 46 79
    W 55530; On 0 0 34 73
    W 55607; Off 0 0 46
    W 55619; Off 0 0 34
    W 55631; Off 0 0 65
    W 55637; Off 0 0 62
    W 55679; Off 0 0 74
    W 56036; On 0 0 77 99
    W 56042; On 0 0 65 85
    W 56048; On 0 0 72 85
    W 56048; On 0 0 69 77
    W 56060; On 0 0 45 76
    W 56065; On 0 0 33 64
    W 56149; Off 0 0 69
    W 56149; Off 0 0 45
    W 56149; Off 0 0 33
    W 56155; Off 0 0 65
    W 56179; Off 0 0 72
    W 56208; Off 0 0 77
    W 56548; On 0 0 79 94
    W 56554; On 0 0 70 75
    W 56554; On 0 0 67 80
    W 56560; On 0 0 75 74
    W 56577; On 0 0 43 70
    W 56589; On 0 0 31 46
    W 56631; Off 0 0 67
    W 56643; Off 0 0 70
    W 56643; Off 0 0 31
    W 56649; Off 0 0 43
    W 56661; Off 0 0 79
    W 56690; Off 0 0 75
    W 56810; On 0 0 82 92
    W 56815; On 0 0 70 89
    W 56881; Off 0 0 82
    W 56881; Off 0 0 70
    W 57095; On 0 0 77 97
    W 57113; On 0 0 65 78
    W 57131; On 0 0 41 71
    W 57137; On 0 0 29 60
    W 57232; Off 0 0 29
    W 57268; Off 0 0 65
    W 57268; Off 0 0 41
    W 57524; Off 0 0 77
    W 57613; On 0 0 79 94
    W 57625; On 0 0 67 78
    W 57637; On 0 0 43 63
    W 57649; On 0 0 31 56
    W 57726; Off 0 0 43
    W 57750; Off 0 0 67
    W 57756; Off 0 0 31
    W 57774; Off 0 0 79
    W 58149; On 0 0 77 100
    W 58161; On 0 0 65 82
    W 58161; On 0 0 41 66
    W 58173; On 0 0 29 56
    W 58333; Off 0 0 29
    W 58339; Off 0 0 77
    W 58345; Off 0 0 41
    W 58393; Off 0 0 65
    W 58679; On 0 0 75 89
    W 58685; On 0 0 63 79
    W 58690; On 0 0 70 77
    W 58702; On 0 0 67 73
    W 58714; On 0 0 31 68
    W 58720; On 0 0 43 75
    W 58780; Off 0 0 43
    W 58798; Off 0 0 67
    W 58798; Off 0 0 31
    W 58804; Off 0 0 63
    W 58839; Off 0 0 75
    W 58905; Off 0 0 70
    W 58935; On 0 0 74 93
    W 58952; On 0 0 62 78
    W 59030; Off 0 0 62
    W 59054; Off 0 0 74
    W 59196; On 0 0 72 94
    W 59202; On 0 0 69 75
    W 59208; On 0 0 60 78
    W 59214; On 0 0 65 68
    W 59220; On 0 0 45 82
    W 59232; On 0 0 33 65
    W 59262; Off 0 0 45
    W 59262; Off 0 0 33
    W 59280; Off 0 0 60
    W 59292; Off 0 0 65
    W 59315; Off 0 0 69
    W 59339; Off 0 0 72
    W 59440; On 0 0 70 85
    W 59458; On 0 0 46 84
    W 59458; On 0 0 62 74
    W 59464; On 0 0 65 74
    W 59464; On 0 0 34 71
    W 59524; Off 0 0 46
    W 59536; Off 0 0 34
    W 59554; Off 0 0 62
    W 59571; Off 0 0 65
    W 59631; Off 0 0 70
    W 59732; On 0 0 72 99
    W 59750; On 0 0 65 82
    W 59750; On 0 0 60 81
    W 59762; On 0 0 45 82
    W 59774; On 0 0 33 67
    W 59887; Off 0 0 60
    W 59929; Off 0 0 65
    W 59935; Off 0 0 72
    W 59940; Off 0 0 45
    W 60012; Off 0 0 33
    W 60262; On 0 0 74 94
    W 60274; On 0 0 62 83
    W 60280; On 0 0 65 74
    W 60286; On 0 0 46 77
    W 60286; On 0 0 34 69
    W 60351; Off 0 0 65
    W 60381; Off 0 0 62
    W 60381; Off 0 0 46
    W 60411; Off 0 0 34
    W 60435; Off 0 0 74
    W 60774; On 0 0 77 94
    W 60780; On 0 0 65 82
    W 60786; On 0 0 72 85
    W 60786; On 0 0 69 72
    W 60810; On 0 0 45 82
    W 60815; On 0 0 33 71
    W 60881; Off 0 0 69
    W 60881; Off 0 0 45
    W 60893; Off 0 0 65
    W 60893; Off 0 0 33
    W 60917; Off 0 0 72
    W 60946; Off 0 0 77
    W 61292; On 0 0 79 96
    W 61304; On 0 0 70 74
    W 61304; On 0 0 75 78
    W 61304; On 0 0 67 82
    W 61327; On 0 0 43 71
    W 61327; On 0 0 31 58
    W 61375; Off 0 0 67
    W 61381; Off 0 0 70
    W 61411; Off 0 0 79
    W 61411; Off 0 0 43
    W 61411; Off 0 0 31
    W 61423; Off 0 0 75
    W 61554; On 0 0 82 86
    W 61565; On 0 0 70 86
    W 61637; Off 0 0 82
    W 61637; Off 0 0 70
    W 61845; On 0 0 77 94
    W 61857; On 0 0 65 77
    W 61875; On 0 0 41 68
    W 61887; On 0 0 29 54
    W 61982; Off 0 0 29
    W 62000; Off 0 0 41
    W 62024; Off 0 0 65
    W 62268; Off 0 0 77
    W 62351; On 0 0 79 99
    W 62363; On 0 0 67 86
    W 62381; On 0 0 43 75
    W 62393; On 0 0 31 68
    W 62476; Off 0 0 43
    W 62476; Off 0 0 31
    W 62494; Off 0 0 67
    W 62500; Off 0 0 79
    W 62917; On 0 0 77 96
    W 62923; On 0 0 65 90
    W 62929; On 0 0 29 71
    W 62935; On 0 0 41 82
    W 63000; Off 0 0 29
    W 63030; Off 0 0 41
    W 63071; Off 0 0 77
    W 63101; Off 0 0 65
    W 63458; On 0 0 67 97
    W 63476; On 0 0 55 90
    W 63595; Off 0 0 55
    W 63821; Off 0 0 67
    W 64024; On 0 0 65 99
    W 64036; On 0 0 53 89
    W 64149; Off 0 0 53
    W 64202; Off 0 0 65
    W 64560; On 0 0 70 85
    W 64560; On 0 0 79 99
    W 64565; On 0 0 67 90
    W 64577; On 0 0 76 72
    W 64583; On 0 0 48 82
    W 64583; On 0 0 36 70
    W 64613; Off 0 0 76
    W 64643; Off 0 0 67
    W 64649; Off 0 0 48
    W 64667; Off 0 0 70
    W 64667; Off 0 0 36
    W 64690; Off 0 0 79
    W 64827; On 0 0 82 89
    W 64839; On 0 0 70 87
    W 64893; Off 0 0 82
    W 64905; Off 0 0 70
    W 65107; On 0 0 77 105
    W 65119; On 0 0 65 87
    W 65137; On 0 0 29 70
    W 65137; On 0 0 41 88
    W 65232; Off 0 0 29
    W 65232; Off 0 0 41
    W 65280; Off 0 0 65
    W 65512; Off 0 0 77
    W 65631; On 0 0 79 100
    W 65637; On 0 0 67 92
    W 65655; On 0 0 43 87
    W 65667; On 0 0 31 75
    W 65744; Off 0 0 31
    W 65750; Off 0 0 43
    W 65774; Off 0 0 67
    W 65786; Off 0 0 79
    W 66202; On 0 0 77 100
    W 66208; On 0 0 65 89
    W 66232; On 0 0 41 89
    W 66238; On 0 0 29 77
    W 66304; Off 0 0 29
    W 66321; Off 0 0 41
    W 66339; Off 0 0 77
    W 66351; Off 0 0 65
    W 66851; On 0 0 67 92
    W 66851; On 0 0 58 77
    W 66857; On 0 0 63 74
    W 66869; On 0 0 51 90
    W 66881; On 0 0 39 75
    W 67101; Off 0 0 63
    W 67113; Off 0 0 67
    W 67113; Off 0 0 58
    W 67113; Off 0 0 39
    W 67149; Off 0 0 51
    W 67452; On 0 0 65 93
    W 67464; On 0 0 57 74
    W 67470; On 0 0 60 82
    W 67482; On 0 0 53 77
    W 67488; On 0 0 41 71
    W 67613; Off 0 0 57
    W 67619; Off 0 0 53
    W 67637; Off 0 0 41
    W 67643; Off 0 0 60
    W 67685; Off 0 0 65
    W 68012; On 0 0 70 93
    W 68018; On 0 0 58 80
    W 68024; On 0 0 65 79
    W 68036; On 0 0 50 74
    W 68042; On 0 0 38 69
    W 68179; Off 0 0 58
    W 68208; Off 0 0 50
    W 68232; Off 0 0 38
    W 68256; Off 0 0 65
    W 68286; Off 0 0 70
    W 68548; On 0 0 72 93
    W 68554; On 0 0 60 83
    W 68554; On 0 0 69 74
    W 68565; On 0 0 65 63
    W 68577; On 0 0 48 83
    W 68583; On 0 0 36 74
    W 68601; Off 0 0 65
    W 68619; Off 0 0 60
    W 68649; Off 0 0 69
    W 68667; Off 0 0 48
    W 68667; Off 0 0 36
    W 68673; Off 0 0 72
    W 68839; On 0 0 77 94
    W 68851; On 0 0 65 78
    W 68881; Off 0 0 65
    W 68899; Off 0 0 77
    W 68946; On 0 0 46 25
    W 68970; Off 0 0 46
    W 69125; On 0 0 74 97
    W 69137; On 0 0 62 81
    W 69137; On 0 0 46 85
    W 69137; On 0 0 70 69
    W 69137; On 0 0 65 67
    W 69143; On 0 0 34 71
    W 69298; Off 0 0 74
    W 69327; Off 0 0 70
    W 69327; Off 0 0 65
    W 69345; Off 0 0 62
    W 69381; Off 0 0 34
    W 69399; Off 0 0 46
    W 69667; On 0 0 60 83
    W 69667; On 0 0 72 92
    W 69673; On 0 0 69 73
    W 69673; On 0 0 65 70
    W 69685; On 0 0 45 88
    W 69690; On 0 0 33 80
    W 69726; Off 0 0 65
    W 69738; Off 0 0 60
    W 69750; Off 0 0 45
    W 69762; Off 0 0 69
    W 69762; Off 0 0 33
    W 69780; Off 0 0 72
    W 69940; On 0 0 77 93
    W 69952; On 0 0 65 82
    W 70006; Off 0 0 65
    W 70012; Off 0 0 77
    W 70232; On 0 0 74 90
    W 70244; On 0 0 31 77
    W 70244; On 0 0 43 87
    W 70244; On 0 0 70 71
    W 70250; On 0 0 65 62
    W 70256; On 0 0 62 70
    W 70363; Off 0 0 31
    W 70369; Off 0 0 74
    W 70381; Off 0 0 65
    W 70393; Off 0 0 43
    W 70393; Off 0 0 70
    W 70417; Off 0 0 62
    W 70804; On 0 0 70 90
    W 70810; On 0 0 58 75
    W 70821; On 0 0 65 70
    W 70827; On 0 0 62 69
    W 70839; On 0 0 55 74
    W 70851; On 0 0 43 65
    W 70923; Off 0 0 62
    W 70923; Off 0 0 55
    W 70946; Off 0 0 43
    W 70952; Off 0 0 65
    W 70958; Off 0 0 58
    W 71018; Off 0 0 70
    W 71345; On 0 0 72 97
    W 71357; On 0 0 67 76
    W 71357; On 0 0 60 81
    W 71357; On 0 0 63 68
    W 71363; On 0 0 48 81
    W 71369; On 0 0 36 70
    W 71446; Off 0 0 36
    W 71452; Off 0 0 48
    W 71482; Off 0 0 67
    W 71494; Off 0 0 72
    W 71494; Off 0 0 63
    W 71500; Off 0 0 60
    W 71905; On 0 0 67 87
    W 71929; On 0 0 55 77
    W 71929; On 0 0 64 72
    W 71929; On 0 0 60 74
    W 71940; On 0 0 52 79
    W 71940; On 0 0 40 72
    W 72030; Off 0 0 52
    W 72036; Off 0 0 40
    W 72048; Off 0 0 55
    W 72048; Off 0 0 64
    W 72077; Off 0 0 60
    W 72149; Off 0 0 67
    W 72494; On 0 0 65 90
    W 72512; On 0 0 53 77
    W 72512; On 0 0 60 74
    W 72518; On 0 0 57 66
    W 72518; On 0 0 41 74
    W 72655; Off 0 0 53
    W 72661; Off 0 0 41
    W 72690; Off 0 0 57
    W 72714; Off 0 0 60
    W 72732; Off 0 0 65
    W 73089; On 0 0 67 96
    W 73095; On 0 0 55 87
    W 73101; On 0 0 62 84
    W 73101; On 0 0 46 103
    W 73101; On 0 0 34 89
    W 73292; Off 0 0 67
    W 73298; Off 0 0 55
    W 73304; Off 0 0 46
    W 73310; Off 0 0 34
    W 73369; Off 0 0 62
    W 73685; On 0 0 65 96
    W 73696; On 0 0 57 81
    W 73696; On 0 0 60 82
    W 73708; On 0 0 45 96
    W 73708; On 0 0 33 80
    W 73845; Off 0 0 57
    W 73857; Off 0 0 45
    W 73863; Off 0 0 33
    W 73869; Off 0 0 60
    W 73899; Off 0 0 65
    W 74238; On 0 0 70 95
    W 74238; On 0 0 58 76
    W 74250; On 0 0 65 79
    W 74268; On 0 0 43 85
    W 74280; On 0 0 31 74
    W 74375; Off 0 0 43
    W 74381; Off 0 0 31
    W 74387; Off 0 0 58
    W 74458; Off 0 0 65
    W 74470; Off 0 0 70
    W 74768; On 0 0 60 87
    W 74774; On 0 0 72 94
    W 74780; On 0 0 69 77
    W 74798; On 0 0 41 88
    W 74798; On 0 0 29 73
    W 74839; Off 0 0 60
    W 74869; Off 0 0 69
    W 74875; Off 0 0 41
    W 74875; Off 0 0 29
    W 74893; Off 0 0 72
    W 75060; On 0 0 77 97
    W 75065; On 0 0 65 87
    W 75119; Off 0 0 77
    W 75119; Off 0 0 65
    W 75363; On 0 0 74 97
    W 75375; On 0 0 70 77
    W 75375; On 0 0 62 80
    W 75381; On 0 0 34 73
    W 75381; On 0 0 46 97
    W 75387; On 0 0 65 69
    W 75506; Off 0 0 34
    W 75506; Off 0 0 46
    W 75524; Off 0 0 74
    W 75536; Off 0 0 65
    W 75548; Off 0 0 62
    W 75554; Off 0 0 70
    W 75964; On 0 0 70 95
    W 75970; On 0 0 58 85
    W 75982; On 0 0 67 82
    W 75982; On 0 0 62 82
    W 75994; On 0 0 55 96
    W 76000; On 0 0 43 92
    W 76083; Off 0 0 43
    W 76095; Off 0 0 55
    W 76107; Off 0 0 62
    W 76119; Off 0 0 58
    W 76173; Off 0 0 67
    W 76202; Off 0 0 70
    W 76625; On 0 0 75 99
    W 76625; On 0 0 67 84
    W 76625; On 0 0 48 103
    W 76625; On 0 0 36 90
    W 76625; On 0 0 72 85
    W 76625; On 0 0 63 88
    W 76702; Off 0 0 36
    W 76732; Off 0 0 48
    W 76774; Off 0 0 67
    W 76792; Off 0 0 72
    W 76792; Off 0 0 63
    W 76810; Off 0 0 75
    W 77327; On 0 0 72 103
    W 77327; On 0 0 65 86
    W 77327; On 0 0 53 92
    W 77327; On 0 0 41 86
    W 77327; On 0 0 69 85
    W 77327; On 0 0 60 92
    W 77560; Off 0 0 41
    W 77565; Off 0 0 69
    W 77577; Off 0 0 53
    W 77595; Off 0 0 60
    W 77601; Off 0 0 65
    W 77625; Off 0 0 72
    W 78190; On 0 0 70 85
    W 78190; On 0 0 62 80
    W 78190; On 0 0 46 83
    W 78190; On 0 0 58 90
    W 78190; On 0 0 65 77
    W 79649; Off 0 0 46
    W 79667; Off 0 0 62
    W 79679; Off 0 0 65
    W 79685; Off 0 0 58
    W 79726; Off 0 0 70
    W 80000; On 0 0 47 78
    W 80000; On 0 0 59 88
    W 80095; Off 0 0 59
    W 80119; Off 0 0 47
    W 80125; On 0 0 51 88
    W 80125; On 0 0 39 68
    W 80244; Off 0 0 51
    W 80244; On 0 0 50 96
    W 80244; On 0 0 38 79
    W 80262; Off 0 0 39
    W 80351; Off 0 0 50
    W 80357; On 0 0 59 92
    W 80357; On 0 0 47 74
    W 80369; Off 0 0 38
    W 80440; Off 0 0 59
    W 80452; Off 0 0 47
    W 80482; On 0 0 58 77
    W 80482; On 0 0 46 72
    W 80601; Off 0 0 58
    W 80601; On 0 0 50 83
    W 80601; On 0 0 38 74
    W 80619; Off 0 0 46
    W 80726; Off 0 0 50
    W 80726; Off 0 0 38
    W 80744; On 0 0 54 86
    W 80744; On 0 0 42 76
    W 82827; Off 0 0 42
    W 83173; Off 0 0 54
    W 83405; On 0 0 59 34
    W 83405; On 0 0 47 36
    W 83458; Off 0 0 59
    W 83554; On 0 0 51 47
    W 83554; On 0 0 39 36
    W 83571; Off 0 0 47
    W 83655; Off 0 0 51
    W 83667; Off 0 0 39
    W 83720; On 0 0 50 52
    W 83720; On 0 0 38 46
    W 83839; Off 0 0 38
    W 83851; Off 0 0 50
    W 83875; On 0 0 47 34
    W 83875; On 0 0 59 44
    W 83970; Off 0 0 47
    W 83970; Off 0 0 59
    W 84065; On 0 0 58 46
    W 84065; On 0 0 46 29
    W 84161; Off 0 0 58
    W 84161; Off 0 0 46
    W 84250; On 0 0 50 50
    W 84250; On 0 0 38 47
    W 84452; Off 0 0 38
    W 84470; Off 0 0 50
    W 84536; On 0 0 54 36
    W 84536; On 0 0 42 32
    W 86327; Off 0 0 54
    W 86429; Off 0 0 42
    W 86565; On 0 0 59 81
    W 86565; On 0 0 47 66
    W 86667; Off 0 0 59
    W 86667; Off 0 0 47
    W 86685; On 0 0 39 65
    W 86685; On 0 0 51 84
    W 86786; Off 0 0 51
    W 86786; On 0 0 50 94
    W 86786; On 0 0 38 66
    W 86845; Off 0 0 39
    W 86893; On 0 0 59 82
    W 86893; On 0 0 47 68
    W 86899; Off 0 0 38
    W 86917; Off 0 0 50
    W 86970; Off 0 0 47
    W 87000; On 0 0 58 77
    W 87000; On 0 0 46 64
    W 87018; Off 0 0 59
    W 87089; On 0 0 50 84
    W 87089; On 0 0 38 77
    W 87107; Off 0 0 58
    W 87143; Off 0 0 46
    W 87185; On 0 0 52 93
    W 87185; On 0 0 40 70
    W 87196; Off 0 0 38
    W 87202; Off 0 0 50
    W 87280; Off 0 0 40
    W 87286; Off 0 0 52
    W 87393; On 0 0 58 83
    W 87393; On 0 0 46 80
    W 87476; Off 0 0 46
    W 87488; Off 0 0 58
    W 87494; On 0 0 47 88
    W 87494; On 0 0 35 80
    W 87595; Off 0 0 35
    W 87595; On 0 0 51 90
    W 87595; On 0 0 39 70
    W 87607; Off 0 0 47
    W 87673; Off 0 0 39
    W 87702; Off 0 0 51
    W 87798; On 0 0 58 77
    W 87798; On 0 0 46 84
    W 87851; Off 0 0 46
    W 87893; Off 0 0 58
    W 87911; On 0 0 46 78
    W 87911; On 0 0 34 73
    W 88012; On 0 0 50 94
    W 88012; On 0 0 38 73
    W 88024; Off 0 0 46
    W 88048; Off 0 0 34
    W 88214; On 0 0 46 88
    W 88214; On 0 0 34 74
    W 88310; Off 0 0 46
    W 88310; Off 0 0 34
    W 88315; Off 0 0 50
    W 88315; Off 0 0 38
    W 88423; On 0 0 70 87
    W 88423; On 0 0 58 89
    W 88423; On 0 0 46 73
    W 88458; Off 0 0 58
    W 88458; Off 0 0 46
    W 88482; Off 0 0 70
    W 88679; On 0 0 94 103
    W 88679; On 0 0 82 99
    W 88679; On 0 0 70 90
    W 88708; Off 0 0 82
    W 88714; Off 0 0 70
    W 88732; Off 0 0 94
    W 90762; On 0 0 59 87
    W 90774; On 0 0 47 76
    W 90857; Off 0 0 59
    W 90881; Off 0 0 47
    W 90887; On 0 0 51 87
    W 90899; On 0 0 39 69
    W 90988; Off 0 0 51
    W 91000; On 0 0 50 96
    W 91024; On 0 0 38 75
    W 91030; Off 0 0 39
    W 91113; Off 0 0 50
    W 91119; On 0 0 59 88
    W 91137; On 0 0 47 66
    W 91155; Off 0 0 38
    W 91190; On 0 0 46 71
    W 91196; Off 0 0 47
    W 91244; Off 0 0 59
    W 91244; On 0 0 58 71
    W 91304; On 0 0 50 70
    W 91339; On 0 0 38 73
    W 91345; Off 0 0 46
    W 91351; Off 0 0 58
    W 91429; On 0 0 54 86
    W 91446; Off 0 0 50
    W 91452; Off 0 0 38
    W 91452; On 0 0 42 78
    W 93315; Off 0 0 54
    W 93315; Off 0 0 42
    W 93339; On 0 0 47 65
    W 93345; On 0 0 59 72
    W 93429; Off 0 0 47
    W 93429; Off 0 0 59
    W 93458; On 0 0 51 80
    W 93464; On 0 0 39 58
    W 93554; Off 0 0 51
    W 93565; On 0 0 50 89
    W 93589; On 0 0 38 60
    W 93601; Off 0 0 39
    W 93673; On 0 0 47 62
    W 93679; On 0 0 59 81
    W 93685; Off 0 0 50
    W 93708; Off 0 0 38
    W 93762; Off 0 0 47
    W 93768; On 0 0 46 63
    W 93780; Off 0 0 59
    W 93804; On 0 0 58 71
    W 93899; Off 0 0 46
    W 93899; On 0 0 50 85
    W 93911; Off 0 0 58
    W 93923; On 0 0 38 67
    W 94000; On 0 0 52 90
    W 94012; Off 0 0 50
    W 94012; On 0 0 40 74
    W 94018; Off 0 0 38
    W 94101; Off 0 0 52
    W 94101; Off 0 0 40
    W 94179; On 0 0 46 72
    W 94214; On 0 0 58 79
    W 94256; Off 0 0 46
    W 94304; Off 0 0 58
    W 94310; On 0 0 35 72
    W 94315; On 0 0 47 85
    W 94405; Off 0 0 35
    W 94405; Off 0 0 47
    W 94411; On 0 0 39 70
    W 94417; On 0 0 51 87
    W 94506; Off 0 0 39
    W 94512; Off 0 0 51
    W 94613; On 0 0 46 78
    W 94625; On 0 0 58 74
    W 94661; Off 0 0 46
    W 94720; Off 0 0 58
    W 94726; On 0 0 34 77
    W 94732; On 0 0 46 79
    W 94810; Off 0 0 46
    W 94815; Off 0 0 34
    W 94815; On 0 0 38 71
    W 94827; On 0 0 50 88
    W 94917; Off 0 0 38
    W 94940; Off 0 0 50
    W 95048; On 0 0 46 90
    W 95065; On 0 0 34 85
    W 95155; Off 0 0 46
    W 95256; On 0 0 58 84
    W 95268; Off 0 0 34
    W 95274; On 0 0 46 88
    W 95304; Off 0 0 58
    W 95304; Off 0 0 46
    W 95506; On 0 0 82 95
    W 95506; On 0 0 70 78
    W 95524; On 0 0 58 89
    W 95536; On 0 0 46 65
    W 95548; Off 0 0 70
    W 95560; Off 0 0 82
    W 95560; Off 0 0 58
    W 95560; Off 0 0 46
    W 95804; On 0 0 82 88
    W 95804; On 0 0 94 102
    W 95804; On 0 0 70 91
    W 95804; On 0 0 58 71
    W 95845; Off 0 0 70
    W 95851; Off 0 0 82
    W 95857; Off 0 0 58
    W 95863; Off 0 0 94
    W 97565; On 0 0 27 61
    W 97595; On 0 0 89 103
    W 97601; On 0 0 78 83
    W 97613; On 0 0 82 77
    W 97625; On 0 0 39 84
    W 97673; Off 0 0 27
    W 97679; Off 0 0 78
    W 97708; Off 0 0 39
    W 97720; Off 0 0 89
    W 97750; Off 0 0 82
    W 97857; On 0 0 87 100
    W 97863; On 0 0 78 91
    W 97869; On 0 0 39 86
    W 97869; On 0 0 82 80
    W 98375; Off 0 0 39
    W 98381; Off 0 0 82
    W 98411; Off 0 0 87
    W 98417; Off 0 0 78
    W 98857; On 0 0 85 99
    W 98863; On 0 0 75 85
    W 98863; On 0 0 78 81
    W 98869; On 0 0 45 89
    W 98940; Off 0 0 75
    W 98982; Off 0 0 78
    W 99000; Off 0 0 85
    W 99101; On 0 0 84 96
    W 99113; On 0 0 75 78
    W 99113; On 0 0 78 74
    W 99208; Off 0 0 75
    W 99232; Off 0 0 78
    W 99244; Off 0 0 84
    W 99500; Off 0 0 45
    W 99607; On 0 0 80 90
    W 99607; On 0 0 54 77
    W 99619; On 0 0 75 71
    W 99625; On 0 0 72 76
    W 99655; Off 0 0 72
    W 99673; Off 0 0 75
    W 99732; Off 0 0 80
    W 99857; On 0 0 78 95
    W 99863; On 0 0 75 77
    W 99869; On 0 0 72 78
    W 99952; Off 0 0 72
    W 99988; Off 0 0 75
    W 99994; Off 0 0 54
    W 100006; Off 0 0 78
    W 100292; On 0 0 27 60
    W 100327; On 0 0 77 97
    W 100333; On 0 0 66 71
    W 100339; On 0 0 70 74
    W 100345; On 0 0 39 99
    W 100399; Off 0 0 70
    W 100405; Off 0 0 27
    W 100411; Off 0 0 66
    W 100417; Off 0 0 39
    W 100423; Off 0 0 77
    W 100583; On 0 0 75 91
    W 100589; On 0 0 66 73
    W 100589; On 0 0 39 90
    W 100595; On 0 0 70 71
    W 100881; Off 0 0 66
    W 100899; Off 0 0 70
    W 100923; Off 0 0 75
    W 100946; Off 0 0 39
    W 101518; On 0 0 73 88
    W 101524; On 0 0 63 72
    W 101536; On 0 0 66 67
    W 101536; On 0 0 45 82
    W 101595; Off 0 0 63
    W 101601; Off 0 0 66
    W 101637; Off 0 0 73
    W 101774; On 0 0 72 90
    W 101780; On 0 0 66 64
    W 101780; On 0 0 63 64
    W 101851; Off 0 0 63
    W 101857; Off 0 0 66
    W 101869; Off 0 0 72
    W 102107; Off 0 0 45
    W 102244; On 0 0 68 88
    W 102244; On 0 0 54 75
    W 102256; On 0 0 63 68
    W 102256; On 0 0 60 72
    W 102292; Off 0 0 60
    W 102310; Off 0 0 63
    W 102345; Off 0 0 68
    W 102518; On 0 0 66 86
    W 102524; On 0 0 63 74
    W 102524; On 0 0 60 73
    W 102601; Off 0 0 60
    W 102619; Off 0 0 63
    W 102649; Off 0 0 66
    W 102655; Off 0 0 54
    W 103345; On 0 0 59 82
    W 103345; On 0 0 47 74
    W 103387; On 0 0 58 79
    W 103393; On 0 0 46 86
    W 103417; Off 0 0 47
    W 103429; Off 0 0 59
    W 103440; Off 0 0 46
    W 103464; Off 0 0 58
    W 103679; On 0 0 47 77
    W 103679; On 0 0 35 63
    W 103720; On 0 0 34 82
    W 103720; On 0 0 46 86
    W 103732; Off 0 0 35
    W 103750; Off 0 0 47
    W 103804; Off 0 0 34
    W 103863; Off 0 0 46
    W 105375; On 0 0 27 34
    W 105399; On 0 0 89 74
    W 105411; On 0 0 78 43
    W 105417; On 0 0 82 51
    W 105440; On 0 0 39 56
    W 105488; Off 0 0 89
    W 105488; Off 0 0 78
    W 105500; Off 0 0 82
    W 105524; Off 0 0 39
    W 105696; On 0 0 87 69
    W 105696; On 0 0 78 47
    W 105702; On 0 0 39 44
    W 105702; On 0 0 82 49
    W 105804; Off 0 0 27
    W 106417; Off 0 0 82
    W 106458; Off 0 0 87
    W 106560; Off 0 0 78
    W 106625; Off 0 0 39
    W 106768; On 0 0 85 74
    W 106780; On 0 0 78 65
    W 106780; On 0 0 75 59
    W 106786; On 0 0 45 64
    W 106827; Off 0 0 75
    W 106833; Off 0 0 78
    W 106845; Off 0 0 85
    W 107060; On 0 0 84 81
    W 107071; On 0 0 75 51
    W 107077; On 0 0 78 55
    W 107315; Off 0 0 78
    W 107333; Off 0 0 84
    W 107363; Off 0 0 75
    W 107482; On 0 0 80 80
    W 107488; On 0 0 54 58
    W 107494; On 0 0 75 61
    W 107494; On 0 0 72 63
    W 107518; Off 0 0 45
    W 107524; Off 0 0 75
    W 107530; Off 0 0 72
    W 107560; Off 0 0 80
    W 107756; On 0 0 78 77
    W 107762; On 0 0 72 60
    W 107768; On 0 0 75 52
    W 107958; Off 0 0 54
    W 107958; Off 0 0 72
    W 107958; Off 0 0 75
    W 107982; Off 0 0 78
    W 108208; On 0 0 77 83
    W 108214; On 0 0 27 43
    W 108220; On 0 0 66 55
    W 108226; On 0 0 70 61
    W 108238; On 0 0 39 71
    W 108268; Off 0 0 70
    W 108280; Off 0 0 66
    W 108286; Off 0 0 77
    W 108310; Off 0 0 39
    W 108494; On 0 0 75 72
    W 108494; On 0 0 66 55
    W 108506; On 0 0 39 55
    W 108506; On 0 0 70 47
    W 108554; Off 0 0 27
    W 109012; Off 0 0 39
    W 109036; Off 0 0 70
    W 109065; Off 0 0 75
    W 109071; Off 0 0 66
    W 109399; On 0 0 73 69
    W 109417; On 0 0 66 54
    W 109423; On 0 0 63 47
    W 109435; On 0 0 45 61
    W 109476; Off 0 0 63
    W 109488; Off 0 0 73
    W 109488; Off 0 0 66
    W 109673; On 0 0 72 73
    W 109685; On 0 0 66 43
    W 109685; On 0 0 63 33
    W 109857; Off 0 0 72
    W 109869; Off 0 0 66
    W 109869; Off 0 0 63
    W 110119; On 0 0 68 60
    W 110131; On 0 0 54 45
    W 110131; On 0 0 63 52
    W 110131; On 0 0 60 58
    W 110167; Off 0 0 63
    W 110167; Off 0 0 60
    W 110185; Off 0 0 68
    W 110333; Off 0 0 45
    W 110399; On 0 0 66 55
    W 110411; On 0 0 60 45
    W 110417; On 0 0 63 32
    W 110548; Off 0 0 60
    W 110565; Off 0 0 63
    W 110577; Off 0 0 66
    W 110607; Off 0 0 54
    W 111238; On 0 0 59 48
    W 111256; On 0 0 47 42
    W 111274; On 0 0 58 62
    W 111286; Off 0 0 59
    W 111292; On 0 0 46 61
    W 111298; Off 0 0 47
    W 111315; Off 0 0 46
    W 111333; Off 0 0 58
    W 111554; On 0 0 47 55
    W 111565; On 0 0 35 49
    W 111619; Off 0 0 35
    W 111619; On 0 0 46 53
    W 111619; On 0 0 34 32
    W 111631; Off 0 0 47
    W 111673; Off 0 0 46
    W 111673; Off 0 0 34
    W 113167; On 0 0 59 89
    W 113173; On 0 0 47 83
    W 113274; Off 0 0 59
    W 113298; Off 0 0 47
    W 113304; On 0 0 39 67
    W 113304; On 0 0 51 87
    W 113411; Off 0 0 51
    W 113423; On 0 0 50 89
    W 113440; Off 0 0 39
    W 113446; On 0 0 38 74
    W 113536; On 0 0 59 87
    W 113554; On 0 0 47 73
    W 113565; Off 0 0 50
    W 113571; Off 0 0 38
    W 113643; Off 0 0 59
    W 113643; Off 0 0 47
    W 113655; On 0 0 46 71
    W 113661; On 0 0 58 75
    W 113780; On 0 0 50 83
    W 113786; Off 0 0 46
    W 113786; Off 0 0 58
    W 113792; On 0 0 38 77
    W 113905; Off 0 0 50
    W 113917; Off 0 0 38
    W 113935; On 0 0 54 90
    W 113940; On 0 0 42 83
    W 114149; Off 0 0 42
    W 114161; Off 0 0 54
    W 114643; On 0 0 47 78
    W 114667; On 0 0 35 60
    W 114702; On 0 0 46 83
    W 114714; Off 0 0 47
    W 114714; On 0 0 34 69
    W 114720; Off 0 0 35
    W 115417; Off 0 0 34
    W 115702; Off 0 0 46
    W 117280; On 0 0 47 77
    W 117292; On 0 0 59 86
    W 117381; Off 0 0 59
    W 117399; Off 0 0 47
    W 117405; On 0 0 39 73
    W 117423; On 0 0 51 83
    W 117512; Off 0 0 51
    W 117530; Off 0 0 39
    W 117530; On 0 0 50 88
    W 117548; On 0 0 38 80
    W 117643; Off 0 0 38
    W 117643; On 0 0 59 84
    W 117655; On 0 0 47 75
    W 117673; Off 0 0 50
    W 117738; Off 0 0 59
    W 117750; On 0 0 58 76
    W 117762; Off 0 0 47
    W 117768; On 0 0 46 67
    W 117869; On 0 0 50 87
    W 117887; Off 0 0 58
    W 117899; Off 0 0 46
    W 117905; On 0 0 38 77
    W 117976; Off 0 0 50
    W 117994; On 0 0 52 94
    W 118000; On 0 0 40 76
    W 118006; Off 0 0 38
    W 118095; Off 0 0 52
    W 118107; Off 0 0 40
    W 118226; On 0 0 46 84
    W 118250; On 0 0 58 77
    W 118304; Off 0 0 46
    W 118333; Off 0 0 58
    W 118357; On 0 0 47 88
    W 118363; On 0 0 35 76
    W 118452; Off 0 0 47
    W 118452; Off 0 0 35
    W 118464; On 0 0 39 78
    W 118464; On 0 0 51 92
    W 118548; Off 0 0 39
    W 118565; Off 0 0 51
    W 118696; On 0 0 46 82
    W 118696; On 0 0 58 74
    W 118744; Off 0 0 46
    W 118792; Off 0 0 58
    W 118815; On 0 0 46 83
    W 118821; On 0 0 34 77
    W 118905; Off 0 0 46
    W 118905; Off 0 0 34
    W 118923; On 0 0 38 83
    W 118935; On 0 0 50 93
    W 119000; Off 0 0 38
    W 119042; Off 0 0 50
    W 119202; On 0 0 34 82
    W 119208; On 0 0 46 93
    W 119292; Off 0 0 34
    W 119292; Off 0 0 46
    W 119905; On 0 0 59 68
    W 119923; On 0 0 47 78
    W 119946; On 0 0 58 83
    W 119964; On 0 0 46 85
    W 119982; Off 0 0 47
    W 119994; Off 0 0 59
    W 120006; Off 0 0 46
    W 120018; Off 0 0 58
    W 120232; On 0 0 47 81
    W 120238; On 0 0 34 56
    W 120256; On 0 0 35 85
    W 120286; On 0 0 46 88
    W 120315; Off 0 0 47
    W 120327; Off 0 0 35
    W 120357; Off 0 0 34
    W 120387; Off 0 0 46
    W 120655; On 0 0 35 88
    W 120655; On 0 0 47 92
    W 122845; On 0 0 34 42
    W 122851; On 0 0 46 33
    W 122923; Off 0 0 47
    W 122929; Off 0 0 35
    W 123929; Off 0 0 34
    W 123940; Off 0 0 46
    W 125810; On 0 0 27 27
    W 125810; On 0 0 51 32
    W 125827; On 0 0 39 23
    W 126202; Off 0 0 51
    W 126244; Off 0 0 27
    W 126274; Off 0 0 39
    W 127173; On 0 0 57 30
    W 127185; On 0 0 69 31
    W 127208; On 0 0 45 25
    W 127232; On 0 0 33 16
    W 127774; Off 0 0 45
    W 127804; Off 0 0 69
    W 127804; Off 0 0 33
    W 127845; Off 0 0 57
    W 128613; On 0 0 51 47
    W 128625; On 0 0 27 38
    W 128631; On 0 0 39 32
    W 129119; Off 0 0 51
    W 129143; Off 0 0 27
    W 129179; Off 0 0 39
    W 129994; On 0 0 58 40
    W 130006; On 0 0 70 49
    W 130030; On 0 0 46 39
    W 130036; On 0 0 34 42
    W 130548; Off 0 0 46
    W 130571; Off 0 0 70
    W 130571; Off 0 0 34
    W 130601; Off 0 0 58
    W 131464; On 0 0 51 56
    W 131464; On 0 0 27 38
    W 131464; On 0 0 39 30
    W 131935; Off 0 0 27
    W 131964; Off 0 0 51
    W 131976; Off 0 0 39
    W 132744; On 0 0 75 83
    W 132744; On 0 0 63 62
    W 132744; On 0 0 48 55
    W 132744; On 0 0 36 34
    W 132929; Off 0 0 48
    W 132935; Off 0 0 36
    W 133065; Off 0 0 63
    W 133071; Off 0 0 75
    W 133429; On 0 0 74 81
    W 133429; On 0 0 35 39
    W 133429; On 0 0 47 39
    W 133429; On 0 0 62 61
    W 133589; Off 0 0 35
    W 133625; Off 0 0 62
    W 133649; Off 0 0 47
    W 133696; Off 0 0 74
    W 134167; On 0 0 76 82
    W 134167; On 0 0 64 63
    W 134167; On 0 0 37 42
    W 134167; On 0 0 49 43
    W 135012; Off 0 0 64
    W 135083; Off 0 0 37
    W 135149; Off 0 0 49
    W 135357; Off 0 0 76
    W 135536; On 0 0 75 57
    W 135536; On 0 0 36 36
    W 135536; On 0 0 48 43
    W 135536; On 0 0 63 34
    W 136095; Off 0 0 48
    W 136119; Off 0 0 36
    W 136167; Off 0 0 75
    W 136173; Off 0 0 63
    W 136946; On 0 0 51 52
    W 136946; On 0 0 27 42
    W 136946; On 0 0 39 27
    W 137089; Off 0 0 51
    W 137125; Off 0 0 27
    W 137125; Off 0 0 39
    W 137643; On 0 0 75 81
    W 137643; On 0 0 48 54
    W 137643; On 0 0 36 42
    W 137643; On 0 0 63 58
    W 137744; Off 0 0 48
    W 137750; Off 0 0 36
    W 137815; Off 0 0 63
    W 137887; Off 0 0 75
    W 138256; On 0 0 74 88
    W 138256; On 0 0 62 70
    W 138256; On 0 0 35 51
    W 138256; On 0 0 47 58
    W 138405; Off 0 0 35
    W 138423; Off 0 0 62
    W 138452; Off 0 0 47
    W 138506; Off 0 0 74
    W 138905; On 0 0 78 85
    W 138929; On 0 0 66 63
    W 138935; On 0 0 51 57
    W 138946; On 0 0 39 50
    W 139202; Off 0 0 39
    W 139280; Off 0 0 66
    W 139304; Off 0 0 51
    W 139315; Off 0 0 78
    W 139565; On 0 0 77 85
    W 139589; On 0 0 65 60
    W 139619; On 0 0 50 59
    W 139649; On 0 0 38 46
    W 139780; Off 0 0 50
    W 139792; Off 0 0 77
    W 139815; Off 0 0 65
    W 139821; Off 0 0 38
    W 140250; On 0 0 70 68
    W 140250; On 0 0 58 54
    W 140250; On 0 0 30 34
    W 140250; On 0 0 42 31
    W 140399; Off 0 0 58
    W 140411; Off 0 0 42
    W 140417; Off 0 0 30
    W 140452; Off 0 0 70
    W 140940; On 0 0 77 83
    W 140940; On 0 0 38 47
    W 140940; On 0 0 50 51
    W 140940; On 0 0 65 62
    W 141714; Off 0 0 38
    W 141774; Off 0 0 65
    W 141821; Off 0 0 77
    W 141827; Off 0 0 50
    W 142292; On 0 0 78 72
    W 142292; On 0 0 66 56
    W 142292; On 0 0 39 44
    W 142292; On 0 0 51 52
    W 142524; Off 0 0 39
    W 142554; Off 0 0 66
    W 142625; Off 0 0 78
    W 142625; Off 0 0 51
    W 142917; On 0 0 77 83
    W 142917; On 0 0 38 40
    W 142917; On 0 0 50 59
    W 142917; On 0 0 65 59
    W 142970; Off 0 0 50
    W 143012; Off 0 0 38
    W 143030; Off 0 0 77
    W 143030; Off 0 0 65
    W 143577; On 0 0 70 70
    W 143577; On 0 0 30 45
    W 143577; On 0 0 58 58
    W 143577; On 0 0 42 34
    W 143685; Off 0 0 58
    W 143708; Off 0 0 70
    W 143720; Off 0 0 30
    W 143720; Off 0 0 42
    W 144250; On 0 0 78 67
    W 144250; On 0 0 39 39
    W 144250; On 0 0 51 40
    W 144250; On 0 0 66 48
    W 144369; Off 0 0 39
    W 144399; Off 0 0 51
    W 144417; Off 0 0 66
    W 144452; Off 0 0 78
    W 145018; On 0 0 59 89
    W 145018; On 0 0 47 84
    W 145119; Off 0 0 59
    W 145131; Off 0 0 47
    W 145137; On 0 0 51 88
    W 145137; On 0 0 39 70
    W 145244; On 0 0 50 93
    W 145244; On 0 0 38 79
    W 145250; Off 0 0 51
    W 145268; Off 0 0 39
    W 145351; On 0 0 59 78
    W 145351; On 0 0 47 70
    W 145369; Off 0 0 50
    W 145411; Off 0 0 38
    W 145464; On 0 0 58 75
    W 145464; On 0 0 46 75
    W 145494; Off 0 0 59
    W 145494; Off 0 0 47
    W 145571; On 0 0 38 72
    W 145571; On 0 0 50 86
    W 145577; Off 0 0 58
    W 145649; Off 0 0 46
    W 145685; On 0 0 42 79
    W 145685; On 0 0 54 95
    W 145690; Off 0 0 38
    W 145702; Off 0 0 50
    W 146857; Off 0 0 42
    W 146863; Off 0 0 54
    W 147804; On 0 0 51 45
    W 147804; On 0 0 27 31
    W 147804; On 0 0 39 26
    W 148298; Off 0 0 51
    W 148327; Off 0 0 27
    W 148381; Off 0 0 39
    W 149262; On 0 0 69 33
    W 149262; On 0 0 57 29
    W 149262; On 0 0 45 31
    W 149262; On 0 0 33 31
    W 149792; Off 0 0 33
    W 149798; Off 0 0 45
    W 149815; Off 0 0 69
    W 149863; Off 0 0 57
    W 150685; On 0 0 51 46
    W 150685; On 0 0 27 32
    W 150685; On 0 0 39 28
    W 151161; Off 0 0 51
    W 151179; Off 0 0 27
    W 151220; Off 0 0 39
    W 152089; On 0 0 70 51
    W 152089; On 0 0 58 34
    W 152089; On 0 0 46 33
    W 152089; On 0 0 34 34
    W 152625; Off 0 0 46
    W 152637; Off 0 0 70
    W 152667; Off 0 0 58
    W 152679; Off 0 0 34
    W 153548; On 0 0 51 51
    W 153548; On 0 0 27 32
    W 153548; On 0 0 39 26
    W 154024; Off 0 0 51
    W 154077; Off 0 0 27
    W 154107; Off 0 0 39
    W 154917; On 0 0 77 69
    W 154917; On 0 0 37 35
    W 154917; On 0 0 49 32
    W 154917; On 0 0 65 48
    W 155137; Off 0 0 77
    W 155161; Off 0 0 37
    W 155179; Off 0 0 49
    W 155179; Off 0 0 65
    W 155613; On 0 0 76 79
    W 155613; On 0 0 48 53
    W 155613; On 0 0 36 48
    W 155613; On 0 0 64 63
    W 155750; Off 0 0 36
    W 155804; Off 0 0 48
    W 155810; Off 0 0 64
    W 155905; Off 0 0 76
    W 156381; On 0 0 80 81
    W 156381; On 0 0 40 32
    W 156381; On 0 0 52 52
    W 156381; On 0 0 68 60
    W 157214; Off 0 0 40
    W 157280; Off 0 0 52
    W 157482; Off 0 0 68
    W 157565; Off 0 0 80
    W 157768; On 0 0 79 70
    W 157768; On 0 0 39 42
    W 157768; On 0 0 67 48
    W 157768; On 0 0 51 43
    W 158399; Off 0 0 51
    W 158417; Off 0 0 79
    W 158446; Off 0 0 67
    W 158470; Off 0 0 39
    W 159173; On 0 0 51 50
    W 159173; On 0 0 39 29
    W 159173; On 0 0 27 35
    W 159339; Off 0 0 51
    W 159369; Off 0 0 27
    W 159381; Off 0 0 39
    W 159863; On 0 0 77 77
    W 159863; On 0 0 65 55
    W 159863; On 0 0 37 40
    W 159863; On 0 0 49 43
    W 160071; Off 0 0 37
    W 160083; Off 0 0 77
    W 160107; Off 0 0 65
    W 160185; Off 0 0 49
    W 160476; On 0 0 76 80
    W 160476; On 0 0 48 61
    W 160476; On 0 0 36 58
    W 160476; On 0 0 64 68
    W 160601; Off 0 0 36
    W 160607; Off 0 0 64
    W 160643; Off 0 0 48
    W 160679; Off 0 0 76
    W 161113; On 0 0 80 82
    W 161113; On 0 0 52 58
    W 161113; On 0 0 40 46
    W 161113; On 0 0 68 57
    W 161381; Off 0 0 52
    W 161399; Off 0 0 40
    W 161494; Off 0 0 68
    W 161506; Off 0 0 80
    W 161756; On 0 0 79 77
    W 161774; On 0 0 67 61
    W 161786; On 0 0 51 49
    W 161815; On 0 0 39 35
    W 161917; Off 0 0 79
    W 161929; Off 0 0 67
    W 161935; Off 0 0 51
    W 161988; Off 0 0 39
    W 162405; On 0 0 61 62
    W 162411; On 0 0 73 71
    W 162458; On 0 0 45 42
    W 162476; On 0 0 33 32
    W 162524; Off 0 0 61
    W 162542; Off 0 0 33
    W 162577; Off 0 0 73
    W 162589; Off 0 0 45
    W 163101; On 0 0 79 81
    W 163101; On 0 0 67 64
    W 163101; On 0 0 51 49
    W 163101; On 0 0 39 45
    W 163863; Off 0 0 67
    W 163869; Off 0 0 39
    W 163952; Off 0 0 79
    W 163958; Off 0 0 51
    W 164494; On 0 0 80 76
    W 164494; On 0 0 68 56
    W 164494; On 0 0 52 58
    W 164494; On 0 0 40 36
    W 164774; Off 0 0 40
    W 164786; Off 0 0 52
    W 164857; Off 0 0 68
    W 164881; Off 0 0 80
    W 165214; On 0 0 79 69
    W 165214; On 0 0 51 47
    W 165214; On 0 0 39 35
    W 165214; On 0 0 67 48
    W 165339; Off 0 0 51
    W 165345; Off 0 0 79
    W 165363; Off 0 0 67
    W 165375; Off 0 0 39
    W 165863; On 0 0 73 64
    W 165863; On 0 0 61 50
    W 165863; On 0 0 45 51
    W 165863; On 0 0 33 39
    W 165935; Off 0 0 33
    W 165988; Off 0 0 61
    W 165988; Off 0 0 45
    W 166060; Off 0 0 73
    W 166589; On 0 0 79 61
    W 166589; On 0 0 39 37
    W 166589; On 0 0 67 47
    W 166607; On 0 0 51 35
    W 166929; Off 0 0 67
    W 166940; Off 0 0 79
    W 166964; Off 0 0 39
    W 166964; Off 0 0 51
    W 167488; On 0 0 64 86
    W 167488; On 0 0 52 80
    W 167589; Off 0 0 64
    W 167619; On 0 0 56 83
    W 167625; On 0 0 44 69
    W 167631; Off 0 0 52
    W 167720; Off 0 0 56
    W 167738; On 0 0 55 87
    W 167750; On 0 0 43 78
    W 167786; Off 0 0 44
    W 167851; Off 0 0 43
    W 167857; On 0 0 64 93
    W 167869; On 0 0 52 80
    W 167887; Off 0 0 55
    W 167964; Off 0 0 64
    W 167970; Off 0 0 52
    W 167976; On 0 0 63 82
    W 167976; On 0 0 51 75
    W 168071; Off 0 0 51
    W 168095; On 0 0 56 90
    W 168107; On 0 0 44 78
    W 168137; Off 0 0 63
    W 168190; Off 0 0 56
    W 168208; Off 0 0 44
    W 168232; On 0 0 59 89
    W 168244; On 0 0 47 87
    W 168798; Off 0 0 47
    W 168821; Off 0 0 59
    W 170369; On 0 0 56 37
    W 170369; On 0 0 32 28
    W 170369; On 0 0 44 22
    W 170762; Off 0 0 32
    W 170768; Off 0 0 56
    W 170810; Off 0 0 44
    W 171917; On 0 0 74 29
    W 171917; On 0 0 38 25
    W 171917; On 0 0 50 21
    W 171917; On 0 0 62 37
    W 172446; Off 0 0 50
    W 172506; Off 0 0 74
    W 172518; Off 0 0 38
    W 172583; Off 0 0 62
    W 173435; On 0 0 56 38
    W 173435; On 0 0 44 22
    W 173435; On 0 0 32 27
    W 174089; Off 0 0 32
    W 174101; Off 0 0 56
    W 174101; Off 0 0 44
    W 174988; On 0 0 75 40
    W 174988; On 0 0 39 25
    W 174988; On 0 0 63 36
    W 174988; On 0 0 51 25
    W 175500; Off 0 0 51
    W 175524; Off 0 0 39
    W 175542; Off 0 0 63
    W 175565; Off 0 0 75
    W 176405; On 0 0 59 78
    W 176405; On 0 0 71 93
    W 176512; Off 0 0 71
    W 176524; On 0 0 51 80
    W 176524; On 0 0 63 84
    W 176548; Off 0 0 59
    W 176649; Off 0 0 63
    W 176649; On 0 0 62 89
    W 176649; On 0 0 50 82
    W 176667; Off 0 0 51
    W 176750; Off 0 0 50
    W 176750; On 0 0 71 92
    W 176756; On 0 0 59 75
    W 176762; Off 0 0 62
    W 176857; Off 0 0 71
    W 176857; On 0 0 58 70
    W 176857; On 0 0 70 80
    W 176863; Off 0 0 59
    W 176970; Off 0 0 58
    W 176976; On 0 0 62 80
    W 176976; On 0 0 50 78
    W 177012; Off 0 0 70
    W 177089; Off 0 0 50
    W 177101; Off 0 0 62
    W 177137; On 0 0 66 92
    W 177137; On 0 0 54 72
    W 177708; Off 0 0 66
    W 177708; Off 0 0 54
    W 178958; On 0 0 63 85
    W 178964; On 0 0 75 91
    W 178982; On 0 0 51 81
    W 178988; On 0 0 39 67
    W 179024; Off 0 0 63
    W 179024; Off 0 0 51
    W 179036; Off 0 0 75
    W 179054; Off 0 0 39
    W 179315; On 0 0 75 88
    W 179327; On 0 0 87 102
    W 179345; On 0 0 39 68
    W 179357; On 0 0 27 76
    W 179405; Off 0 0 39
    W 179405; Off 0 0 27
    W 180089; Off 0 0 75
    W 180101; Off 0 0 87
    W 180464; On 0 0 86 100
    W 180470; On 0 0 74 90
    W 180488; On 0 0 63 82
    W 180488; On 0 0 51 77
    W 180679; Off 0 0 74
    W 180720; Off 0 0 86
    W 181042; On 0 0 90 95
    W 181042; On 0 0 78 88
    W 181327; Off 0 0 51
    W 181387; Off 0 0 63
    W 181387; Off 0 0 78
    W 181405; Off 0 0 90
    W 181625; On 0 0 89 97
    W 181631; On 0 0 77 90
    W 181637; On 0 0 62 76
    W 181661; On 0 0 50 68
    W 181798; Off 0 0 89
    W 181821; Off 0 0 77
    W 182214; On 0 0 70 85
    W 182214; On 0 0 82 90
    W 182321; Off 0 0 70
    W 182369; Off 0 0 82
    W 182405; Off 0 0 62
    W 182417; Off 0 0 50
    W 182827; On 0 0 88 97
    W 182833; On 0 0 76 89
    W 182845; On 0 0 61 70
    W 182857; On 0 0 49 67
    W 183548; Off 0 0 76
    W 183554; Off 0 0 88
    W 183601; Off 0 0 49
    W 183631; Off 0 0 61
    W 183917; On 0 0 87 93
    W 183923; On 0 0 75 87
    W 183946; On 0 0 60 68
    W 183958; On 0 0 48 66
    W 184435; Off 0 0 60
    W 184446; Off 0 0 48
    W 184690; Off 0 0 87
    W 184702; Off 0 0 75
    W 184982; On 0 0 86 93
    W 184994; On 0 0 74 83
    W 184994; On 0 0 59 61
    W 185012; On 0 0 47 59
    W 185161; Off 0 0 86
    W 185214; Off 0 0 74
    W 185542; On 0 0 68 82
    W 185542; On 0 0 80 89
    W 185673; Off 0 0 68
    W 185702; Off 0 0 47
    W 185732; Off 0 0 80
    W 185738; Off 0 0 59
    W 186077; On 0 0 85 89
    W 186083; On 0 0 73 77
    W 186107; On 0 0 58 57
    W 186125; On 0 0 46 56
    W 186268; Off 0 0 85
    W 186274; Off 0 0 73
    W 186595; On 0 0 66 85
    W 186601; On 0 0 78 91
    W 186696; Off 0 0 66
    W 186744; Off 0 0 78
    W 186827; Off 0 0 46
    W 186845; Off 0 0 58
    W 187161; On 0 0 84 100
    W 187167; On 0 0 72 93
    W 187202; On 0 0 57 56
    W 187208; On 0 0 45 62
    W 187827; Off 0 0 57
    W 187827; Off 0 0 45
    W 187976; Off 0 0 84
    W 188036; Off 0 0 72
    W 188286; On 0 0 83 97
    W 188292; On 0 0 71 84
    W 188315; On 0 0 56 62
    W 188321; On 0 0 44 55
    W 188821; Off 0 0 56
    W 188827; Off 0 0 44
    W 188869; Off 0 0 83
    W 188893; Off 0 0 71
    W 189369; On 0 0 82 89
    W 189375; On 0 0 55 66
    W 189381; On 0 0 70 80
    W 189381; On 0 0 43 58
    W 189554; Off 0 0 82
    W 189577; Off 0 0 70
    W 189964; On 0 0 75 91
    W 189964; On 0 0 63 84
    W 190065; Off 0 0 63
    W 190119; Off 0 0 75
    W 190155; Off 0 0 55
    W 190161; Off 0 0 43
    W 190554; On 0 0 81 93
    W 190565; On 0 0 69 82
    W 190571; On 0 0 54 64
    W 190583; On 0 0 42 58
    W 191143; Off 0 0 69
    W 191226; Off 0 0 42
    W 191310; Off 0 0 54
    W 191619; Off 0 0 81
    W 191679; On 0 0 80 85
    W 191679; On 0 0 68 62
    W 191679; On 0 0 53 59
    W 191679; On 0 0 41 53
    W 191905; Off 0 0 80
    W 191935; Off 0 0 68
    W 192107; Off 0 0 53
    W 192125; Off 0 0 41
    W 192262; On 0 0 74 87
    W 192262; On 0 0 62 74
    W 192339; Off 0 0 62
    W 192351; Off 0 0 74
    W 192649; On 0 0 75 90
    W 192649; On 0 0 63 73
    W 192649; On 0 0 39 55
    W 192649; On 0 0 51 95
    W 192702; Off 0 0 51
    W 192708; Off 0 0 63
    W 192720; Off 0 0 75
    W 192720; Off 0 0 39
    W 192976; On 0 0 87 99
    W 192976; On 0 0 75 92
    W 192976; On 0 0 27 60
    W 192976; On 0 0 39 67
    W 193024; Off 0 0 27
    W 193042; Off 0 0 39
    W 193750; Off 0 0 87
    W 193756; Off 0 0 75
    W 194101; On 0 0 86 90
    W 194101; On 0 0 74 86
    W 194101; On 0 0 40 74
    W 194101; On 0 0 52 93
    W 194196; Off 0 0 40
    W 194238; Off 0 0 52
    W 194673; On 0 0 59 83
    W 194685; On 0 0 47 74
    W 194863; Off 0 0 47
    W 194917; Off 0 0 74
    W 194935; Off 0 0 59
    W 194976; Off 0 0 86
    W 195226; On 0 0 85 90
    W 195232; On 0 0 73 85
    W 195244; On 0 0 58 81
    W 195256; On 0 0 46 65
    W 195411; Off 0 0 58
    W 195429; Off 0 0 46
    W 195768; On 0 0 39 74
    W 195768; On 0 0 51 92
    W 195863; Off 0 0 39
    W 195863; Off 0 0 51
    W 196101; Off 0 0 73
    W 196137; Off 0 0 85
    W 196321; On 0 0 84 90
    W 196333; On 0 0 72 82
    W 196345; On 0 0 57 82
    W 196357; On 0 0 45 76
    W 196970; Off 0 0 45
    W 196988; Off 0 0 57
    W 197048; Off 0 0 84
    W 197095; Off 0 0 72
    W 197482; On 0 0 83 92
    W 197494; On 0 0 71 72
    W 197494; On 0 0 56 77
    W 197494; On 0 0 44 67
    W 198048; Off 0 0 44
    W 198071; Off 0 0 71
    W 198101; Off 0 0 56
    W 198107; Off 0 0 83
    W 198554; On 0 0 82 90
    W 198560; On 0 0 70 83
    W 198595; On 0 0 55 78
    W 198601; On 0 0 43 75
    W 198786; Off 0 0 55
    W 198821; Off 0 0 43
    W 199131; On 0 0 49 88
    W 199143; On 0 0 37 67
    W 199333; Off 0 0 37
    W 199399; Off 0 0 49
    W 199494; Off 0 0 70
    W 199506; Off 0 0 82
    W 199690; On 0 0 81 92
    W 199690; On 0 0 69 84
    W 199720; On 0 0 48 89
    W 199726; On 0 0 36 74
    W 199863; Off 0 0 36
    W 199893; Off 0 0 48
    W 200250; On 0 0 54 91
    W 200256; On 0 0 42 77
    W 200446; Off 0 0 42
    W 200488; Off 0 0 69
    W 200542; Off 0 0 54
    W 200649; Off 0 0 81
    W 200863; On 0 0 53 94
    W 200869; On 0 0 80 77
    W 200875; On 0 0 41 76
    W 200875; On 0 0 68 67
    W 201565; Off 0 0 41
    W 201589; Off 0 0 53
    W 201637; Off 0 0 68
    W 201649; Off 0 0 80
    W 202012; On 0 0 79 92
    W 202024; On 0 0 67 80
    W 202030; On 0 0 52 85
    W 202042; On 0 0 40 66
    W 202167; Off 0 0 52
    W 202196; Off 0 0 40
    W 202583; On 0 0 47 88
    W 202583; On 0 0 35 74
    W 202690; Off 0 0 35
    W 202744; Off 0 0 47
    W 202881; Off 0 0 67
    W 203196; On 0 0 78 85
    W 203208; On 0 0 66 62
    W 203208; On 0 0 51 83
    W 203226; On 0 0 39 57
    W 203232; Off 0 0 79
    W 203845; Off 0 0 39
    W 203940; Off 0 0 51
    W 203976; Off 0 0 66
    W 203994; Off 0 0 78
    W 204357; On 0 0 77 88
    W 204357; On 0 0 65 71
    W 204357; On 0 0 38 60
    W 204357; On 0 0 50 76
    W 204863; Off 0 0 38
    W 204869; Off 0 0 50
    W 204958; On 0 0 46 72
    W 204958; On 0 0 34 63
    W 205202; Off 0 0 77
    W 205226; Off 0 0 65
    W 205280; Off 0 0 46
    W 205280; Off 0 0 34
    W 205601; On 0 0 76 83
    W 205601; On 0 0 49 67
    W 205601; On 0 0 37 59
    W 205601; On 0 0 64 67
    W 206196; Off 0 0 64
    W 206208; Off 0 0 76
    W 206208; Off 0 0 49
    W 206208; Off 0 0 37
    W 206714; On 0 0 39 38
    W 206786; Off 0 0 39
    W 206804; On 0 0 40 32
    W 206881; Off 0 0 40
    W 206893; On 0 0 39 37
    W 206952; Off 0 0 39
    W 206970; On 0 0 40 33
    W 207042; Off 0 0 40
    W 207048; On 0 0 39 40
    W 207119; Off 0 0 39
    W 207131; On 0 0 40 41
    W 207208; Off 0 0 40
    W 207214; On 0 0 39 43
    W 207280; Off 0 0 39
    W 207298; On 0 0 40 37
    W 207369; Off 0 0 40
    W 207369; On 0 0 39 44
    W 207446; Off 0 0 39
    W 207458; On 0 0 40 42
    W 207530; Off 0 0 40
    W 207536; On 0 0 39 44
    W 207601; Off 0 0 39
    W 207613; On 0 0 40 45
    W 207685; Off 0 0 40
    W 207690; On 0 0 39 45
    W 207756; Off 0 0 39
    W 207768; On 0 0 40 46
    W 207839; Off 0 0 40
    W 207845; On 0 0 39 47
    W 207917; Off 0 0 39
    W 207929; On 0 0 40 48
    W 208006; Off 0 0 40
    W 208006; On 0 0 39 49
    W 208077; Off 0 0 39
    W 208083; On 0 0 40 51
    W 208155; Off 0 0 40
    W 208161; On 0 0 39 52
    W 208214; Off 0 0 39
    W 208238; On 0 0 40 53
    W 208292; Off 0 0 40
    W 208304; On 0 0 39 54
    W 208351; Off 0 0 39
    W 208369; On 0 0 40 55
    W 208429; Off 0 0 40
    W 208440; On 0 0 41 56
    W 208488; Off 0 0 41
    W 208506; On 0 0 42 57
    W 208548; Off 0 0 42
    W 208565; On 0 0 43 58
    W 208601; Off 0 0 43
    W 208619; On 0 0 44 59
    W 208667; Off 0 0 44
    W 208685; On 0 0 45 60
    W 208744; Off 0 0 45
    W 208768; On 0 0 47 60
    W 208833; Off 0 0 47
    W 208851; On 0 0 45 60
    W 208911; Off 0 0 45
    W 208917; On 0 0 47 60
    W 208982; Off 0 0 47
    W 209006; On 0 0 45 60
    W 209065; Off 0 0 45
    W 209077; On 0 0 47 60
    W 209137; Off 0 0 47
    W 209155; On 0 0 45 60
    W 209214; Off 0 0 45
    W 209226; On 0 0 47 60
    W 209286; Off 0 0 47
    W 209310; On 0 0 45 60
    W 209363; Off 0 0 45
    W 209375; On 0 0 47 60
    W 209440; Off 0 0 47
    W 209458; On 0 0 45 60
    W 209524; Off 0 0 45
    W 209542; On 0 0 47 60
    W 209601; Off 0 0 47
    W 209619; On 0 0 45 60
    W 209679; Off 0 0 45
    W 209690; On 0 0 47 60
    W 209756; Off 0 0 47
    W 209780; On 0 0 45 60
    W 209845; Off 0 0 45
    W 209863; On 0 0 47 60
    W 209917; Off 0 0 47
    W 209935; On 0 0 45 60
    W 209994; Off 0 0 45
    W 210006; On 0 0 47 60
    W 210065; Off 0 0 47
    W 210089; On 0 0 45 60
    W 210143; Off 0 0 45
    W 210155; On 0 0 47 60
    W 210208; Off 0 0 47
    W 210250; On 0 0 45 60
    W 210387; On 0 0 44 59
    W 210393; Off 0 0 45
    W 210440; Off 0 0 44
    W 210452; On 0 0 43 58
    W 210506; On 0 0 42 57
    W 210518; Off 0 0 43
    W 210577; Off 0 0 42
    W 210577; On 0 0 41 56
    W 210595; On 0 0 89 80
    W 210601; On 0 0 78 60
    W 210607; On 0 0 82 64
    W 210613; Off 0 0 41
    W 210631; On 0 0 40 52
    W 210637; Off 0 0 82
    W 210643; Off 0 0 78
    W 210661; Off 0 0 89
    W 210696; On 0 0 39 51
    W 210702; Off 0 0 40
    W 210768; Off 0 0 39
    W 210774; On 0 0 40 50
    W 210839; Off 0 0 40
    W 210845; On 0 0 39 49
    W 210905; Off 0 0 39
    W 210917; On 0 0 40 48
    W 210976; On 0 0 87 71
    W 210988; On 0 0 82 64
    W 210988; On 0 0 78 61
    W 210994; Off 0 0 40
    W 211000; On 0 0 39 46
    W 211060; Off 0 0 39
    W 211071; On 0 0 40 44
    W 211143; Off 0 0 40
    W 211155; On 0 0 39 44
    W 211214; Off 0 0 39
    W 211226; On 0 0 40 41
    W 211298; Off 0 0 40
    W 211304; On 0 0 39 37
    W 211369; Off 0 0 39
    W 211381; On 0 0 40 44
    W 211452; Off 0 0 40
    W 211458; On 0 0 39 39
    W 211518; Off 0 0 39
    W 211536; On 0 0 40 39
    W 211613; Off 0 0 40
    W 211613; On 0 0 39 43
    W 211679; Off 0 0 39
    W 211690; On 0 0 40 44
    W 211768; Off 0 0 40
    W 211780; On 0 0 39 35
    W 211839; Off 0 0 39
    W 211851; Off 0 0 82
    W 211857; On 0 0 40 40
    W 211863; Off 0 0 87
    W 211869; Off 0 0 78
    W 211929; Off 0 0 40
    W 211929; On 0 0 39 40
    W 211988; Off 0 0 39
    W 212000; On 0 0 40 42
    W 212071; Off 0 0 40
    W 212077; On 0 0 39 40
    W 212131; Off 0 0 39
    W 212149; On 0 0 40 47
    W 212214; Off 0 0 40
    W 212220; On 0 0 39 43
    W 212274; Off 0 0 39
    W 212298; On 0 0 40 44
    W 212345; Off 0 0 40
    W 212369; On 0 0 41 44
    W 212411; Off 0 0 41
    W 212435; On 0 0 42 42
    W 212464; Off 0 0 42
    W 212488; On 0 0 43 46
    W 212536; Off 0 0 43
    W 212554; On 0 0 44 40
    W 212595; Off 0 0 44
    W 212595; On 0 0 85 84
    W 212607; On 0 0 75 60
    W 212613; On 0 0 45 68
    W 212613; On 0 0 78 60
    W 212637; Off 0 0 78
    W 212643; Off 0 0 75
    W 212661; Off 0 0 85
    W 212673; Off 0 0 45
    W 212714; On 0 0 47 60
    W 212762; Off 0 0 47
    W 212780; On 0 0 45 60
    W 212839; Off 0 0 45
    W 212851; On 0 0 47 60
    W 212905; Off 0 0 47
    W 212929; On 0 0 45 61
    W 212958; On 0 0 84 89
    W 212970; On 0 0 78 65
    W 212970; On 0 0 75 60
    W 212988; Off 0 0 45
    W 212988; On 0 0 47 60
    W 213048; Off 0 0 47
    W 213071; On 0 0 45 60
    W 213131; Off 0 0 45
    W 213149; On 0 0 47 60
    W 213208; Off 0 0 47
    W 213226; On 0 0 45 60
    W 213256; Off 0 0 78
    W 213286; Off 0 0 45
    W 213292; Off 0 0 75
    W 213298; On 0 0 47 60
    W 213357; Off 0 0 47
    W 213381; On 0 0 45 60
    W 213435; Off 0 0 45
    W 213452; Off 0 0 84
    W 213452; On 0 0 47 60
    W 213500; Off 0 0 47
    W 213536; On 0 0 45 60
    W 213542; On 0 0 80 87
    W 213548; On 0 0 75 72
    W 213560; On 0 0 72 66
    W 213589; Off 0 0 45
    W 213589; Off 0 0 72
    W 213607; Off 0 0 75
    W 213613; On 0 0 47 60
    W 213631; Off 0 0 80
    W 213661; Off 0 0 47
    W 213696; On 0 0 45 60
    W 213744; Off 0 0 45
    W 213768; On 0 0 47 60
    W 213810; Off 0 0 47
    W 213845; On 0 0 45 60
    W 213899; Off 0 0 45
    W 213911; On 0 0 78 76
    W 213917; On 0 0 47 60
    W 213923; On 0 0 75 61
    W 213935; On 0 0 72 60
    W 213946; Off 0 0 47
    W 213976; Off 0 0 72
    W 213976; On 0 0 45 60
    W 214030; Off 0 0 45
    W 214042; On 0 0 72 60
    W 214048; On 0 0 47 60
    W 214101; Off 0 0 47
    W 214125; On 0 0 45 59
    W 214202; Off 0 0 75
    W 214202; Off 0 0 72
    W 214202; On 0 0 44 58
    W 214208; Off 0 0 45
    W 214214; Off 0 0 78
    W 214256; Off 0 0 44
    W 214274; On 0 0 43 57
    W 214327; On 0 0 42 56
    W 214333; Off 0 0 43
    W 214393; On 0 0 41 55
    W 214423; Off 0 0 42
    W 214435; Off 0 0 41
    W 214452; On 0 0 40 54
    W 214518; Off 0 0 40
    W 214518; On 0 0 39 53
    W 214542; On 0 0 77 86
    W 214554; On 0 0 66 61
    W 214554; On 0 0 70 64
    W 214583; Off 0 0 39
    W 214595; Off 0 0 70
    W 214595; On 0 0 40 46
    W 214607; Off 0 0 66
    W 214625; Off 0 0 77
    W 214661; Off 0 0 40
    W 214673; On 0 0 39 37
    W 214738; Off 0 0 39
    W 214750; On 0 0 40 38
    W 214821; Off 0 0 40
    W 214827; On 0 0 39 44
    W 214887; Off 0 0 39
    W 214887; On 0 0 75 77
    W 214893; On 0 0 40 47
    W 214899; On 0 0 66 54
    W 214899; On 0 0 70 56
    W 214970; Off 0 0 40
    W 214976; On 0 0 39 39
    W 215036; Off 0 0 39
    W 215054; On 0 0 40 40
    W 215119; Off 0 0 40
    W 215125; On 0 0 39 36
    W 215190; Off 0 0 39
    W 215202; On 0 0 40 39
    W 215280; Off 0 0 40
    W 215286; On 0 0 39 36
    W 215351; Off 0 0 39
    W 215375; On 0 0 40 30
    W 215435; Off 0 0 70
    W 215440; Off 0 0 66
    W 215440; Off 0 0 40
    W 215446; On 0 0 39 39
    W 215452; Off 0 0 75
    W 215506; Off 0 0 39
    W 215524; On 0 0 40 38
    W 215601; Off 0 0 40
    W 215613; On 0 0 39 35
    W 215673; Off 0 0 39
    W 215690; On 0 0 40 36
    W 215750; Off 0 0 40
    W 215756; On 0 0 39 42
    W 215827; Off 0 0 39
    W 215845; On 0 0 40 38
    W 215917; Off 0 0 40
    W 215923; On 0 0 39 37
    W 215976; Off 0 0 39
    W 216000; On 0 0 40 39
    W 216071; Off 0 0 40
    W 216077; On 0 0 39 48
    W 216125; Off 0 0 39
    W 216149; On 0 0 40 58
    W 216196; Off 0 0 40
    W 216208; On 0 0 41 55
    W 216256; Off 0 0 41
    W 216280; On 0 0 42 35
    W 216304; Off 0 0 42
    W 216327; On 0 0 43 49
    W 216375; Off 0 0 43
    W 216393; On 0 0 44 60
    W 216435; Off 0 0 44
    W 216458; On 0 0 45 60
    W 216476; On 0 0 73 77
    W 216482; On 0 0 63 55
    W 216488; On 0 0 66 55
    W 216512; Off 0 0 66
    W 216518; Off 0 0 63
    W 216524; Off 0 0 45
    W 216536; Off 0 0 73
    W 216542; On 0 0 47 60
    W 216601; Off 0 0 47
    W 216619; On 0 0 45 60
    W 216685; Off 0 0 45
    W 216690; On 0 0 47 60
    W 216750; Off 0 0 47
    W 216768; On 0 0 45 60
    W 216798; On 0 0 72 80
    W 216815; On 0 0 63 58
    W 216815; On 0 0 66 54
    W 216833; Off 0 0 45
    W 216839; On 0 0 47 60
    W 216899; Off 0 0 47
    W 216929; On 0 0 45 60
    W 216982; Off 0 0 45
    W 216994; On 0 0 47 60
    W 217054; Off 0 0 47
    W 217083; On 0 0 45 60
    W 217095; Off 0 0 66
    W 217149; Off 0 0 45
    W 217149; On 0 0 47 60
    W 217161; Off 0 0 63
    W 217220; Off 0 0 47
    W 217244; On 0 0 45 60
    W 217304; Off 0 0 45
    W 217321; On 0 0 47 60
    W 217333; Off 0 0 72
    W 217375; Off 0 0 47
    W 217399; On 0 0 45 60
    W 217417; On 0 0 68 80
    W 217423; On 0 0 63 67
    W 217423; On 0 0 60 68
    W 217458; Off 0 0 60
    W 217464; Off 0 0 45
    W 217464; Off 0 0 63
    W 217470; On 0 0 47 60
    W 217506; Off 0 0 68
    W 217530; Off 0 0 47
    W 217560; On 0 0 45 60
    W 217607; Off 0 0 45
    W 217619; On 0 0 47 60
    W 217667; Off 0 0 47
    W 217702; On 0 0 45 59
    W 217738; On 0 0 66 73
    W 217750; Off 0 0 45
    W 217750; On 0 0 60 42
    W 217756; On 0 0 63 45
    W 217762; On 0 0 47 60
    W 217786; Off 0 0 47
    W 217821; On 0 0 45 60
    W 217875; Off 0 0 45
    W 217887; On 0 0 47 59
    W 217946; Off 0 0 47
    W 217970; On 0 0 45 60
    W 218000; Off 0 0 60
    W 218012; Off 0 0 63
    W 218030; Off 0 0 66
    W 218036; Off 0 0 45
    W 218042; On 0 0 44 59
    W 218095; Off 0 0 44
    W 218113; On 0 0 43 58
    W 218167; On 0 0 42 57
    W 218173; Off 0 0 43
    W 218232; Off 0 0 42
    W 218232; On 0 0 41 56
    W 218268; Off 0 0 41
    W 218280; On 0 0 40 50
    W 218327; On 0 0 65 75
    W 218333; On 0 0 54 57
    W 218345; Off 0 0 40
    W 218351; On 0 0 39 51
    W 218351; On 0 0 58 53
    W 218381; Off 0 0 58
    W 218399; Off 0 0 54
    W 218405; Off 0 0 65
    W 218417; Off 0 0 39
    W 218423; On 0 0 40 45
    W 218488; Off 0 0 40
    W 218500; On 0 0 39 42
    W 218554; Off 0 0 39
    W 218571; On 0 0 40 41
    W 218643; Off 0 0 40
    W 218649; On 0 0 39 43
    W 218679; On 0 0 63 70
    W 218685; On 0 0 54 55
    W 218696; On 0 0 58 51
    W 218708; Off 0 0 39
    W 218720; On 0 0 40 43
    W 218798; Off 0 0 40
    W 218804; On 0 0 39 44
    W 218857; Off 0 0 39
    W 218881; On 0 0 40 42
    W 218940; Off 0 0 40
    W 218952; On 0 0 39 43
    W 219006; Off 0 0 39
    W 219030; On 0 0 40 38
    W 219083; Off 0 0 40
    W 219101; On 0 0 39 37
    W 219125; Off 0 0 58
    W 219131; Off 0 0 54
    W 219149; Off 0 0 63
    W 219155; Off 0 0 39
    W 219173; On 0 0 40 33
    W 219244; Off 0 0 40
    W 219250; On 0 0 39 39
    W 219304; Off 0 0 39
    W 219327; On 0 0 40 33
    W 219387; Off 0 0 40
    W 219399; On 0 0 39 37
    W 219458; Off 0 0 39
    W 219476; On 0 0 40 38
    W 219542; Off 0 0 40
    W 219548; On 0 0 39 45
    W 219613; Off 0 0 39
    W 219625; On 0 0 40 41
    W 219702; Off 0 0 40
    W 219702; On 0 0 39 39
    W 219750; Off 0 0 39
    W 219762; On 0 0 40 38
    W 219827; Off 0 0 40
    W 219839; On 0 0 39 44
    W 219887; Off 0 0 39
    W 219911; On 0 0 40 44
    W 219958; Off 0 0 40
    W 219970; On 0 0 41 46
    W 220018; Off 0 0 41
    W 220036; On 0 0 42 48
    W 220071; Off 0 0 42
    W 220095; On 0 0 43 49
    W 220125; Off 0 0 43
    W 220149; On 0 0 44 50
    W 220185; Off 0 0 44
    W 220208; On 0 0 45 51
    W 220238; On 0 0 61 73
    W 220250; On 0 0 54 55
    W 220256; On 0 0 51 52
    W 220268; Off 0 0 45
    W 220280; Off 0 0 54
    W 220280; On 0 0 47 43
    W 220286; Off 0 0 51
    W 220304; Off 0 0 61
    W 220333; Off 0 0 47
    W 220357; On 0 0 45 52
    W 220417; Off 0 0 45
    W 220423; On 0 0 47 50
    W 220482; Off 0 0 47
    W 220506; On 0 0 45 53
    W 220560; Off 0 0 45
    W 220565; On 0 0 47 51
    W 220571; On 0 0 60 74
    W 220583; On 0 0 51 50
    W 220589; On 0 0 54 48
    W 220607; Off 0 0 47
    W 220637; On 0 0 45 50
    W 220690; Off 0 0 45
    W 220696; On 0 0 47 51
    W 220732; Off 0 0 47
    W 220768; On 0 0 45 50
    W 220810; Off 0 0 45
    W 220821; On 0 0 47 51
    W 220851; Off 0 0 47
    W 220887; On 0 0 45 50
    W 220929; Off 0 0 45
    W 220946; On 0 0 47 51
    W 220970; Off 0 0 47
    W 221018; On 0 0 45 50
    W 221042; Off 0 0 45
    W 221048; On 0 0 47 50
    W 221071; Off 0 0 54
    W 221077; Off 0 0 51
    W 221095; Off 0 0 60
    W 221101; Off 0 0 47
    W 221125; On 0 0 45 51
    W 221208; Off 0 0 45
    W 221214; On 0 0 46 52
    W 221262; Off 0 0 46
    W 221298; On 0 0 47 53
    W 221339; Off 0 0 47
    W 221363; On 0 0 48 54
    W 221405; Off 0 0 48
    W 221423; On 0 0 49 55
    W 221470; Off 0 0 49
    W 221482; On 0 0 50 56
    W 221548; Off 0 0 50
    W 221565; On 0 0 51 57
    W 221619; Off 0 0 51
    W 221643; On 0 0 52 58
    W 221690; Off 0 0 52
    W 221714; On 0 0 53 59
    W 221756; Off 0 0 53
    W 221774; On 0 0 54 59
    W 221833; Off 0 0 54
    W 221851; On 0 0 55 60
    W 221905; Off 0 0 55
    W 221917; On 0 0 56 60
    W 221976; Off 0 0 56
    W 222000; On 0 0 57 60
    W 222083; Off 0 0 57
    W 222083; On 0 0 59 60
    W 222155; Off 0 0 59
    W 222167; On 0 0 57 60
    W 222173; On 0 0 73 84
    W 222185; On 0 0 63 67
    W 222185; On 0 0 66 61
    W 222214; Off 0 0 66
    W 222232; Off 0 0 57
    W 222232; Off 0 0 63
    W 222238; On 0 0 59 60
    W 222256; Off 0 0 73
    W 222298; Off 0 0 59
    W 222310; On 0 0 57 60
    W 222375; Off 0 0 57
    W 222387; On 0 0 59 60
    W 222446; Off 0 0 59
    W 222464; On 0 0 57 59
    W 222524; Off 0 0 57
    W 222530; On 0 0 72 89
    W 222530; On 0 0 63 60
    W 222536; On 0 0 59 60
    W 222536; On 0 0 66 60
    W 222589; Off 0 0 59
    W 222601; On 0 0 57 60
    W 222667; Off 0 0 57
    W 222679; On 0 0 59 60
    W 222738; Off 0 0 59
    W 222750; On 0 0 57 60
    W 222815; Off 0 0 57
    W 222827; On 0 0 59 60
    W 222881; Off 0 0 59
    W 222893; On 0 0 57 60
    W 222964; Off 0 0 57
    W 222970; On 0 0 59 60
    W 223024; Off 0 0 66
    W 223036; Off 0 0 59
    W 223042; Off 0 0 72
    W 223042; Off 0 0 63
    W 223054; On 0 0 57 60
    W 223119; Off 0 0 57
    W 223125; On 0 0 59 60
    W 223185; Off 0 0 59
    W 223202; On 0 0 57 60
    W 223268; Off 0 0 57
    W 223268; On 0 0 59 60
    W 223327; Off 0 0 59
    W 223351; On 0 0 57 60
    W 223411; Off 0 0 57
    W 223417; On 0 0 59 60
    W 223476; Off 0 0 59
    W 223500; On 0 0 57 60
    W 223560; Off 0 0 57
    W 223589; On 0 0 59 49
    W 223655; Off 0 0 59
    W 223690; On 0 0 57 53
    W 223756; Off 0 0 57
    W 223768; On 0 0 59 42
    W 223827; Off 0 0 59
    W 223839; On 0 0 57 44
    W 223893; Off 0 0 57
    W 223911; On 0 0 59 42
    W 223970; Off 0 0 59
    W 223988; On 0 0 56 50
    W 224048; Off 0 0 56
    W 224083; On 0 0 59 59
    W 224083; On 0 0 75 96
    W 224083; On 0 0 63 74
    W 224083; On 0 0 68 77
    W 224083; On 0 0 71 75
    W 224143; Off 0 0 59
    W 224143; Off 0 0 75
    W 224155; Off 0 0 63
    W 224185; Off 0 0 68
    W 224185; Off 0 0 71
    W 224518; On 0 0 56 62
    W 224518; On 0 0 59 65
    W 224518; On 0 0 75 39
    W 224518; On 0 0 71 73
    W 224518; On 0 0 63 54
    W 224518; On 0 0 64 84
    W 224518; On 0 0 68 73
    W 224518; On 0 0 76 95
    W 224577; Off 0 0 75
    W 225167; Off 0 0 71
    W 225214; Off 0 0 68
    W 225220; Off 0 0 59
    W 225232; Off 0 0 56
    W 225238; Off 0 0 63
    W 225256; Off 0 0 64
    W 225262; Off 0 0 76
    W 226190; On 0 0 75 100
    W 226214; On 0 0 68 76
    W 226214; On 0 0 63 65
    W 226226; On 0 0 59 66
    W 226226; On 0 0 56 64
    W 226232; On 0 0 71 68
    W 226833; Off 0 0 75
    W 226946; Off 0 0 71
    W 226994; Off 0 0 68
    W 227042; Off 0 0 56
    W 227054; Off 0 0 63
    W 227060; Off 0 0 59
    W 227196; On 0 0 76 108
    W 227214; On 0 0 68 81
    W 227214; On 0 0 64 92
    W 227214; On 0 0 56 72
    W 227220; On 0 0 63 71
    W 227226; On 0 0 75 59
    W 227232; On 0 0 71 79
    W 227232; On 0 0 59 72
    W 227696; Off 0 0 75
    W 227881; Off 0 0 56
    W 227887; Off 0 0 63
    W 227887; Off 0 0 59
    W 227905; Off 0 0 64
    W 227911; Off 0 0 71
    W 227923; Off 0 0 68
    W 227982; Off 0 0 76
    W 228970; On 0 0 71 62
    W 229077; On 0 0 70 69
    W 229083; On 0 0 66 43
    W 229089; Off 0 0 71
    W 229143; Off 0 0 66
    W 229161; Off 0 0 70
    W 229179; On 0 0 65 66
    W 229179; On 0 0 62 54
    W 229244; Off 0 0 62
    W 229268; Off 0 0 65
    W 229280; On 0 0 66 62
    W 229280; On 0 0 63 36
    W 229351; Off 0 0 66
    W 229363; Off 0 0 63
    W 229375; On 0 0 69 68
    W 229375; On 0 0 59 48
    W 229458; Off 0 0 69
    W 229464; Off 0 0 59
    W 229470; On 0 0 70 67
    W 229470; On 0 0 58 55
    W 229548; Off 0 0 70
    W 229554; Off 0 0 58
    W 229560; On 0 0 62 56
    W 229565; On 0 0 71 64
    W 229649; Off 0 0 62
    W 229655; Off 0 0 71
    W 229661; On 0 0 63 57
    W 229667; On 0 0 69 72
    W 229744; Off 0 0 63
    W 229756; Off 0 0 69
    W 229762; On 0 0 70 73
    W 229762; On 0 0 62 62
    W 229857; Off 0 0 70
    W 229857; On 0 0 59 60
    W 229869; Off 0 0 62
    W 229869; On 0 0 74 66
    W 229958; Off 0 0 59
    W 229958; On 0 0 58 61
    W 229964; Off 0 0 74
    W 229964; On 0 0 75 77
    W 230042; Off 0 0 75
    W 230065; Off 0 0 58
    W 230065; On 0 0 77 81
    W 230065; On 0 0 57 67
    W 230143; Off 0 0 77
    W 230155; On 0 0 78 73
    W 230155; On 0 0 58 65
    W 230167; Off 0 0 57
    W 230238; Off 0 0 58
    W 230244; On 0 0 57 68
    W 230250; Off 0 0 78
    W 230262; On 0 0 77 86
    W 230357; Off 0 0 77
    W 230357; On 0 0 74 75
    W 230357; On 0 0 53 63
    W 230375; Off 0 0 57
    W 230452; Off 0 0 74
    W 230452; On 0 0 75 80
    W 230458; Off 0 0 53
    W 230464; On 0 0 54 58
    W 230536; Off 0 0 75
    W 230554; On 0 0 77 80
    W 230560; Off 0 0 54
    W 230560; On 0 0 50 72
    W 230655; Off 0 0 50
    W 230655; On 0 0 78 76
    W 230661; Off 0 0 77
    W 230667; On 0 0 51 62
    W 230738; Off 0 0 78
    W 230762; Off 0 0 51
    W 230762; On 0 0 81 74
    W 230762; On 0 0 47 62
    W 230833; Off 0 0 81
    W 230851; Off 0 0 47
    W 230851; On 0 0 82 73
    W 230851; On 0 0 46 71
    W 230952; On 0 0 83 89
    W 230958; On 0 0 45 72
    W 230976; Off 0 0 82
    W 231012; Off 0 0 46
    W 231018; Off 0 0 83
    W 231024; Off 0 0 45
    W 231042; On 0 0 47 75
    W 231054; On 0 0 81 82
    W 231125; Off 0 0 47
    W 231137; On 0 0 46 75
    W 231143; Off 0 0 81
    W 231149; On 0 0 82 85
    W 231232; Off 0 0 82
    W 231250; Off 0 0 46
    W 231250; On 0 0 41 76
    W 231256; On 0 0 86 90
    W 231315; Off 0 0 41
    W 231327; Off 0 0 86
    W 231339; On 0 0 42 68
    W 231351; On 0 0 87 77
    W 231405; Off 0 0 87
    W 231411; Off 0 0 42
    W 231417; On 0 0 39 67
    W 231452; On 0 0 46 71
    W 231476; Off 0 0 39
    W 231476; On 0 0 75 87
    W 231500; Off 0 0 46
    W 231500; On 0 0 54 79
    W 231524; Off 0 0 75
    W 231524; Off 0 0 54
    W 231542; On 0 0 82 84
    W 231565; Off 0 0 82
    W 231583; On 0 0 90 110
    W 231643; Off 0 0 90
    W 231643
  } while ([PsMusic]::ShouldLoop())
} finally {
  [PsMusic]::Close()
}
