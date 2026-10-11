# PowerShell Music Maker generated script (PowerShell 5.1 / 7)
# BPM=75  tracks: Horns[gs], Strings 1&2[gs], Strings Viola[gs], Strings Cello&Bass[gs], Bassoon[gs], Trumpet[gs], Vocals[gs], Vocals[gs], Trombones[gs], Tympani[gs]
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
  }
  public static void Close() {
    Running = false;
    if (RenderThread != null && RenderThread.IsAlive) { RenderThread.Join(400); }
    try { Console.CursorVisible = true; } catch {}
    if (hOut != IntPtr.Zero) {
      for (int ch = 0; ch < 16; ch++) Send(0xB0 | ch, 123, 0);
      midiOutClose(hOut); hOut = IntPtr.Zero;
    }
    Console.WriteLine();
  }
}
'@
}
[PsMusic]::Init(128890, 75, '"Confutatis" from Requiem [K.626]', 'Mozart, Wolfgang Amadeus', @('Horns', 'Strings 1&2', 'Strings Viola', 'Strings Cello&Bass', 'Bassoon', 'Trumpet', 'Vocals', 'Vocals', 'Trombones', 'Tympani'), @('GS', 'GS', 'GS', 'GS', 'GS', 'GS', 'GS', 'GS', 'GS', 'GS'), @(0, 1, 2, 3, 4, 5, 6, 7, 8, 10))
# Wait until the absolute time with Start-Sleep (no accumulated drift)
$sw = [Diagnostics.Stopwatch]::StartNew()
function W([int]$t) { $d = $t - [int]$sw.ElapsedMilliseconds; if ($d -gt 0) { Start-Sleep -Milliseconds $d } }
function Prog($ch, $p) { [PsMusic]::Send((0xC0 -bor $ch), $p, 0) }
function On($tr, $ch, $n, $v) { [PsMusic]::On($tr, $ch, $n, $v) }
function Off($tr, $ch, $n) { [PsMusic]::Off($tr, $ch, $n) }
function B($tr, $f, $d) { [PsMusic]::BeepOn($tr, $f, $d) }
try {
  [PsMusic]::Open()
  [PsMusic]::Start()
  W 0; Prog 0 60
  W 0; Prog 1 48
  W 0; Prog 2 48
  W 0; Prog 3 48
  W 0; Prog 4 70
  W 0; Prog 5 56
  W 0; Prog 6 52
  W 0; Prog 7 52
  W 0; Prog 8 60
  W 0; Prog 10 47
  W 3200; On 1 1 57 127
  W 3200; On 3 3 45 124
  W 3200; On 3 3 33 116
  W 3200; On 5 5 69 100
  W 3200; On 9 10 45 124
  W 3217; On 5 5 57 60
  W 3290; Off 1 1 57
  W 3300; Off 3 3 33
  W 3300; On 1 1 59 127
  W 3300; On 3 3 47 108
  W 3300; On 3 3 35 108
  W 3307; Off 3 3 45
  W 3373; Off 1 1 59
  W 3383; Off 3 3 47
  W 3383; Off 3 3 35
  W 3400; On 1 1 60 127
  W 3400; On 3 3 48 100
  W 3400; On 3 3 36 124
  W 3467; Off 1 1 60
  W 3467; Off 3 3 36
  W 3483; Off 3 3 48
  W 3600; On 1 1 60 127
  W 3600; On 3 3 48 112
  W 3600; On 3 3 36 116
  W 3650; Off 1 1 60
  W 3657; Off 3 3 36
  W 3673; Off 3 3 48
  W 3767; Off 9 10 45
  W 3800; On 1 1 60 127
  W 3800; On 3 3 48 124
  W 3800; On 3 3 36 116
  W 3850; Off 1 1 60
  W 3850; Off 3 3 48
  W 3850; Off 3 3 36
  W 3983; Off 5 5 69
  W 3983; Off 5 5 57
  W 4000; On 1 1 60 127
  W 4000; On 3 3 48 124
  W 4000; On 3 3 36 124
  W 4000; On 4 4 57 64
  W 4000; On 6 6 57 120
  W 4000; On 8 8 57 68
  W 4073; Off 3 3 36
  W 4083; Off 1 1 60
  W 4083; Off 3 3 48
  W 4100; On 1 1 59 127
  W 4100; On 3 3 47 112
  W 4100; On 3 3 35 92
  W 4167; Off 3 3 47
  W 4167; Off 3 3 35
  W 4173; Off 1 1 59
  W 4200; On 1 1 57 127
  W 4200; On 3 3 45 120
  W 4200; On 3 3 33 124
  W 4257; Off 3 3 33
  W 4267; Off 1 1 57
  W 4267; Off 3 3 45
  W 4400; On 1 1 57 127
  W 4400; On 3 3 45 124
  W 4400; On 3 3 33 120
  W 4450; Off 3 3 33
  W 4457; Off 1 1 57
  W 4467; Off 3 3 45
  W 4567; Off 8 8 57
  W 4600; Off 6 6 57
  W 4600; On 1 1 57 127
  W 4600; On 3 3 45 124
  W 4600; On 3 3 33 116
  W 4600; On 4 4 52 52
  W 4600; On 6 6 52 120
  W 4600; On 8 8 52 52
  W 4633; Off 4 4 57
  W 4650; Off 3 3 33
  W 4657; Off 1 1 57
  W 4657; Off 3 3 45
  W 4783; Off 8 8 52
  W 4790; On 5 5 69 80
  W 4800; Off 4 4 52
  W 4800; On 1 1 57 127
  W 4800; On 3 3 45 124
  W 4800; On 3 3 33 120
  W 4800; On 4 4 60 80
  W 4800; On 6 6 60 120
  W 4800; On 8 8 60 84
  W 4800; On 9 10 45 124
  W 4807; On 5 5 57 40
  W 4840; Off 6 6 52
  W 4867; Off 1 1 57
  W 4890; Off 3 3 33
  W 4900; On 1 1 59 127
  W 4900; On 3 3 47 116
  W 4900; On 3 3 35 116
  W 4917; Off 3 3 45
  W 4957; Off 1 1 59
  W 4973; Off 3 3 47
  W 4973; Off 3 3 35
  W 5000; On 1 1 60 127
  W 5000; On 3 3 48 104
  W 5000; On 3 3 36 124
  W 5057; Off 3 3 48
  W 5057; Off 3 3 36
  W 5067; Off 1 1 60
  W 5200; On 1 1 60 127
  W 5200; On 3 3 48 116
  W 5200; On 3 3 36 116
  W 5250; Off 3 3 48
  W 5257; Off 1 1 60
  W 5257; Off 3 3 36
  W 5273; Off 9 10 45
  W 5400; On 1 1 60 127
  W 5400; On 3 3 48 124
  W 5400; On 3 3 36 116
  W 5450; Off 3 3 48
  W 5457; Off 1 1 60
  W 5457; Off 3 3 36
  W 5567; Off 6 6 60
  W 5600; Off 4 4 60
  W 5600; Off 8 8 60
  W 5600; On 1 1 60 127
  W 5600; On 3 3 48 124
  W 5600; On 3 3 36 108
  W 5600; On 4 4 60 88
  W 5600; On 4 4 57 80
  W 5600; On 6 6 60 120
  W 5600; On 6 6 57 120
  W 5600; On 8 8 57 68
  W 5600; On 8 8 60 76
  W 5650; Off 5 5 69
  W 5667; Off 5 5 57
  W 5673; Off 3 3 36
  W 5683; Off 3 3 48
  W 5700; On 1 1 59 127
  W 5700; On 3 3 47 96
  W 5700; On 3 3 35 108
  W 5723; Off 1 1 60
  W 5767; Off 3 3 47
  W 5773; Off 1 1 59
  W 5773; Off 3 3 35
  W 5800; On 1 1 57 127
  W 5800; On 3 3 45 104
  W 5800; On 3 3 33 112
  W 5857; Off 3 3 33
  W 5867; Off 1 1 57
  W 5873; Off 3 3 45
  W 6000; On 1 1 59 77
  W 6000; On 1 1 57 127
  W 6000; On 3 3 45 120
  W 6000; On 3 3 33 124
  W 6040; Off 1 1 59
  W 6057; Off 3 3 45
  W 6057; Off 3 3 33
  W 6067; Off 1 1 57
  W 6190; Off 6 6 60
  W 6200; Off 4 4 57
  W 6200; Off 6 6 57
  W 6200; Off 8 8 57
  W 6200; On 1 1 57 127
  W 6200; On 3 3 45 124
  W 6200; On 3 3 33 108
  W 6200; On 4 4 57 76
  W 6200; On 6 6 57 120
  W 6200; On 8 8 57 60
  W 6207; Off 8 8 60
  W 6223; Off 4 4 60
  W 6250; Off 3 3 33
  W 6267; Off 1 1 57
  W 6267; Off 3 3 45
  W 6400; On 1 1 59 127
  W 6400; On 3 3 47 112
  W 6400; On 3 3 35 124
  W 6400; On 4 4 62 84
  W 6400; On 6 6 62 120
  W 6400; On 8 8 62 96
  W 6400; On 9 10 50 112
  W 6407; Off 6 6 57
  W 6407; Off 8 8 57
  W 6417; On 5 5 74 60
  W 6433; Off 4 4 57
  W 6433; On 5 5 62 60
  W 6467; Off 1 1 59
  W 6467; Off 3 3 47
  W 6467; Off 3 3 35
  W 6500; On 1 1 60 127
  W 6500; On 3 3 48 104
  W 6500; On 3 3 36 108
  W 6557; Off 1 1 60
  W 6557; Off 3 3 48
  W 6557; Off 3 3 36
  W 6600; On 1 1 62 127
  W 6600; On 3 3 50 124
  W 6600; On 3 3 38 104
  W 6657; Off 3 3 38
  W 6667; Off 1 1 62
  W 6667; Off 3 3 50
  W 6773; Off 9 10 50
  W 6800; On 1 1 62 127
  W 6800; On 3 3 50 120
  W 6800; On 3 3 38 112
  W 6800; On 3 3 37 52
  W 6807; Off 3 3 37
  W 6857; Off 1 1 62
  W 6857; Off 3 3 50
  W 6857; Off 3 3 38
  W 7000; On 1 1 62 127
  W 7000; On 3 3 50 120
  W 7000; On 3 3 38 124
  W 7050; Off 1 1 62
  W 7050; Off 3 3 50
  W 7050; Off 3 3 38
  W 7157; Off 8 8 62
  W 7200; On 1 1 62 127
  W 7200; On 3 3 50 124
  W 7200; On 3 3 38 124
  W 7200; On 3 3 30 44
  W 7200; On 4 4 56 76
  W 7200; On 6 6 59 120
  W 7200; On 6 6 56 120
  W 7200; On 8 8 59 68
  W 7200; On 8 8 56 56
  W 7207; Off 3 3 30
  W 7207; Off 4 4 62
  W 7207; Off 5 5 62
  W 7217; Off 5 5 74
  W 7223; Off 6 6 62
  W 7273; Off 1 1 62
  W 7300; On 1 1 60 127
  W 7300; On 3 3 48 124
  W 7300; On 3 3 37 84
  W 7300; On 3 3 36 120
  W 7307; Off 3 3 38
  W 7317; Off 3 3 50
  W 7317; Off 3 3 37
  W 7367; Off 1 1 60
  W 7383; Off 3 3 48
  W 7400; On 1 1 59 127
  W 7400; On 3 3 47 100
  W 7400; On 3 3 35 112
  W 7417; Off 3 3 36
  W 7467; Off 1 1 59
  W 7467; Off 3 3 35
  W 7483; Off 3 3 47
  W 7600; On 1 1 59 127
  W 7600; On 3 3 47 100
  W 7600; On 3 3 35 100
  W 7657; Off 3 3 35
  W 7667; Off 1 1 59
  W 7673; Off 3 3 47
  W 7783; Off 4 4 56
  W 7790; Off 8 8 59
  W 7800; On 1 1 59 127
  W 7800; On 3 3 47 116
  W 7800; On 3 3 35 100
  W 7800; On 4 4 52 68
  W 7800; On 6 6 52 120
  W 7800; On 8 8 52 40
  W 7857; Off 1 1 59
  W 7867; Off 3 3 35
  W 7873; Off 3 3 47
  W 7890; Off 6 6 59
  W 7917; Off 6 6 56
  W 7950; Off 8 8 56
  W 8000; Off 4 4 52
  W 8000; On 1 1 59 127
  W 8000; On 3 3 47 124
  W 8000; On 3 3 35 124
  W 8000; On 4 4 62 68
  W 8000; On 6 6 62 120
  W 8000; On 8 8 62 88
  W 8000; On 9 10 50 124
  W 8007; Off 6 6 52
  W 8007; On 5 5 74 64
  W 8023; On 5 5 62 40
  W 8040; Off 8 8 52
  W 8067; Off 1 1 59
  W 8100; Off 3 3 35
  W 8100; On 1 1 60 127
  W 8100; On 3 3 48 108
  W 8100; On 3 3 36 112
  W 8117; Off 3 3 47
  W 8157; Off 1 1 60
  W 8183; Off 3 3 48
  W 8190; Off 3 3 36
  W 8200; On 1 1 62 127
  W 8200; On 3 3 50 112
  W 8200; On 3 3 38 112
  W 8267; Off 1 1 62
  W 8267; Off 3 3 38
  W 8273; Off 3 3 50
  W 8290; Off 9 10 50
  W 8400; On 1 1 62 127
  W 8400; On 3 3 50 88
  W 8400; On 3 3 38 104
  W 8457; Off 1 1 62
  W 8457; Off 3 3 38
  W 8473; Off 3 3 50
  W 8600; On 1 1 62 127
  W 8600; On 3 3 50 104
  W 8600; On 3 3 38 100
  W 8650; Off 3 3 50
  W 8657; Off 1 1 62
  W 8657; Off 3 3 38
  W 8767; Off 5 5 74
  W 8773; Off 8 8 62
  W 8783; Off 5 5 62
  W 8790; Off 6 6 62
  W 8800; Off 4 4 62
  W 8800; On 1 1 62 127
  W 8800; On 3 3 50 124
  W 8800; On 3 3 38 124
  W 8800; On 4 4 56 64
  W 8800; On 4 4 62 84
  W 8800; On 6 6 62 120
  W 8800; On 6 6 56 120
  W 8800; On 8 8 56 76
  W 8800; On 8 8 62 96
  W 8867; Off 1 1 62
  W 8867; Off 3 3 38
  W 8883; Off 3 3 50
  W 8900; On 1 1 60 127
  W 8900; On 3 3 49 108
  W 8900; On 3 3 48 124
  W 8900; On 3 3 36 92
  W 8950; Off 3 3 49
  W 8967; Off 1 1 60
  W 8983; Off 3 3 36
  W 8990; Off 3 3 48
  W 9000; On 1 1 59 127
  W 9000; On 3 3 47 104
  W 9000; On 3 3 35 116
  W 9067; Off 3 3 35
  W 9073; Off 1 1 59
  W 9073; Off 3 3 47
  W 9200; On 1 1 59 127
  W 9200; On 3 3 47 120
  W 9200; On 3 3 35 108
  W 9257; Off 3 3 35
  W 9267; Off 1 1 59
  W 9273; Off 3 3 47
  W 9373; Off 4 4 62
  W 9390; Off 6 6 62
  W 9400; Off 8 8 56
  W 9400; On 1 1 59 127
  W 9400; On 3 3 47 116
  W 9400; On 3 3 35 84
  W 9400; On 4 4 59 76
  W 9400; On 6 6 59 120
  W 9400; On 8 8 56 56
  W 9423; Off 8 8 62
  W 9457; Off 1 1 59
  W 9457; Off 3 3 47
  W 9457; Off 3 3 35
  W 9523; Off 6 6 56
  W 9600; On 1 1 60 127
  W 9600; On 3 3 48 124
  W 9600; On 3 3 36 112
  W 9600; On 4 4 64 80
  W 9600; On 6 6 64 120
  W 9600; On 8 8 64 96
  W 9600; On 9 10 45 124
  W 9607; Off 4 4 59
  W 9607; Off 6 6 59
  W 9617; Off 4 4 56
  W 9633; Off 8 8 56
  W 9633; On 5 5 69 52
  W 9640; On 5 5 76 76
  W 9667; Off 1 1 60
  W 9673; Off 3 3 48
  W 9700; Off 3 3 36
  W 9700; On 1 1 62 127
  W 9700; On 3 3 50 120
  W 9700; On 3 3 38 116
  W 9757; Off 1 1 62
  W 9767; Off 3 3 50
  W 9773; Off 3 3 38
  W 9800; On 1 1 64 127
  W 9800; On 3 3 52 124
  W 9800; On 3 3 40 120
  W 9857; Off 3 3 40
  W 9867; Off 3 3 52
  W 9890; Off 1 1 64
  W 9900; Off 9 10 45
  W 10000; On 1 1 64 127
  W 10000; On 3 3 52 116
  W 10000; On 3 3 40 112
  W 10050; Off 3 3 40
  W 10057; Off 1 1 64
  W 10057; Off 3 3 52
  W 10200; On 1 1 64 127
  W 10200; On 3 3 52 116
  W 10200; On 3 3 40 108
  W 10250; Off 1 1 64
  W 10257; Off 3 3 52
  W 10257; Off 3 3 40
  W 10350; Off 6 6 64
  W 10400; Off 4 4 64
  W 10400; Off 8 8 64
  W 10400; On 1 1 64 127
  W 10400; On 3 3 52 124
  W 10400; On 3 3 40 108
  W 10400; On 3 3 34 32
  W 10400; On 4 4 57 80
  W 10400; On 4 4 64 100
  W 10400; On 6 6 64 120
  W 10400; On 6 6 57 120
  W 10400; On 8 8 64 96
  W 10400; On 8 8 57 64
  W 10407; Off 3 3 34
  W 10440; Off 5 5 69
  W 10450; Off 5 5 76
  W 10467; Off 3 3 40
  W 10473; Off 3 3 52
  W 10483; Off 1 1 64
  W 10500; On 1 1 62 127
  W 10500; On 3 3 52 112
  W 10500; On 3 3 50 96
  W 10500; On 3 3 38 108
  W 10550; Off 3 3 52
  W 10573; Off 1 1 62
  W 10573; Off 3 3 50
  W 10590; Off 3 3 38
  W 10600; On 1 1 60 127
  W 10600; On 3 3 48 84
  W 10600; On 3 3 36 112
  W 10667; Off 1 1 60
  W 10673; Off 3 3 36
  W 10700; Off 3 3 48
  W 10800; On 1 1 60 127
  W 10800; On 3 3 48 116
  W 10800; On 3 3 36 120
  W 10850; Off 3 3 36
  W 10867; Off 1 1 60
  W 10873; Off 3 3 48
  W 10967; Off 4 4 64
  W 10967; Off 6 6 64
  W 11000; On 1 1 60 127
  W 11000; On 3 3 48 108
  W 11000; On 3 3 36 116
  W 11000; On 4 4 62 52
  W 11000; On 6 6 62 120
  W 11000; On 8 8 62 60
  W 11033; Off 8 8 64
  W 11057; Off 3 3 36
  W 11067; Off 1 1 60
  W 11073; Off 3 3 48
  W 11133; Off 4 4 57
  W 11173; Off 6 6 57
  W 11200; Off 8 8 57
  W 11200; On 1 1 66 41
  W 11200; On 1 1 60 127
  W 11200; On 3 3 56 68
  W 11200; On 3 3 53 16
  W 11200; On 3 3 52 24
  W 11200; On 3 3 48 124
  W 11200; On 3 3 36 124
  W 11200; On 4 4 60 88
  W 11200; On 5 5 76 64
  W 11200; On 6 6 60 120
  W 11200; On 8 8 60 60
  W 11200; On 9 10 45 116
  W 11207; Off 1 1 66
  W 11207; On 5 5 69 68
  W 11217; Off 3 3 56
  W 11217; Off 3 3 53
  W 11223; Off 3 3 52
  W 11233; Off 6 6 62
  W 11257; Off 8 8 62
  W 11267; Off 1 1 60
  W 11283; Off 4 4 62
  W 11300; On 1 1 62 127
  W 11300; On 3 3 50 108
  W 11300; On 3 3 38 112
  W 11307; Off 3 3 36
  W 11317; Off 3 3 48
  W 11357; Off 1 1 62
  W 11373; Off 3 3 50
  W 11383; Off 3 3 38
  W 11400; Off 9 10 45
  W 11400; On 1 1 64 127
  W 11400; On 3 3 52 112
  W 11400; On 3 3 51 4
  W 11400; On 3 3 40 112
  W 11400; On 3 3 38 68
  W 11417; Off 3 3 38
  W 11457; Off 3 3 51
  W 11457; Off 3 3 40
  W 11467; Off 3 3 52
  W 11473; Off 1 1 64
  W 11600; On 1 1 64 127
  W 11600; On 3 3 52 108
  W 11600; On 3 3 40 112
  W 11657; Off 1 1 64
  W 11657; Off 3 3 40
  W 11667; Off 3 3 52
  W 11740; Off 8 8 60
  W 11757; Off 4 4 60
  W 11800; On 1 1 64 127
  W 11800; On 3 3 52 96
  W 11800; On 3 3 40 88
  W 11800; On 4 4 59 68
  W 11800; On 6 6 59 120
  W 11800; On 8 8 59 60
  W 11817; Off 6 6 60
  W 11850; Off 1 1 64
  W 11857; Off 3 3 40
  W 11867; Off 3 3 52
  W 12000; On 1 1 64 127
  W 12000; On 3 3 52 124
  W 12000; On 3 3 41 124
  W 12000; On 3 3 40 104
  W 12000; On 3 3 34 16
  W 12000; On 4 4 57 112
  W 12000; On 6 6 57 120
  W 12000; On 8 8 57 76
  W 12007; Off 3 3 34
  W 12023; Off 5 5 69
  W 12023; Off 6 6 59
  W 12040; Off 8 8 59
  W 12050; Off 3 3 41
  W 12057; Off 4 4 59
  W 12073; Off 3 3 40
  W 12083; Off 5 5 76
  W 12090; Off 3 3 52
  W 12100; Off 1 1 64
  W 12100; On 1 1 62 127
  W 12100; On 3 3 50 116
  W 12100; On 3 3 38 108
  W 12157; Off 1 1 62
  W 12167; Off 3 3 50
  W 12200; On 1 1 60 127
  W 12200; On 3 3 48 116
  W 12200; On 3 3 36 112
  W 12207; Off 3 3 38
  W 12257; Off 3 3 36
  W 12273; Off 1 1 60
  W 12283; Off 3 3 48
  W 12400; On 1 1 60 127
  W 12400; On 3 3 48 104
  W 12400; On 3 3 36 112
  W 12457; Off 3 3 36
  W 12467; Off 1 1 60
  W 12473; Off 3 3 48
  W 12583; Off 4 4 57
  W 12583; Off 8 8 57
  W 12590; Off 6 6 57
  W 12600; On 1 1 66 41
  W 12600; On 1 1 60 127
  W 12600; On 3 3 48 112
  W 12600; On 3 3 36 112
  W 12600; On 4 4 55 84
  W 12600; On 6 6 55 120
  W 12600; On 8 8 55 48
  W 12607; Off 1 1 66
  W 12657; Off 3 3 36
  W 12667; Off 1 1 60
  W 12667; Off 3 3 48
  W 12740; On 5 5 74 80
  W 12750; On 5 5 62 52
  W 12800; On 1 1 62 127
  W 12800; On 3 3 50 104
  W 12800; On 3 3 38 124
  W 12800; On 4 4 53 84
  W 12800; On 6 6 53 120
  W 12800; On 8 8 53 84
  W 12800; On 9 10 50 120
  W 12840; Off 6 6 55
  W 12840; Off 8 8 55
  W 12857; Off 1 1 62
  W 12857; Off 4 4 55
  W 12890; Off 3 3 38
  W 12900; On 1 1 64 127
  W 12900; On 3 3 52 116
  W 12900; On 3 3 40 112
  W 12907; Off 3 3 50
  W 12957; Off 1 1 64
  W 12990; Off 3 3 52
  W 12990; Off 3 3 40
  W 13000; On 1 1 65 127
  W 13000; On 3 3 53 108
  W 13000; On 3 3 41 112
  W 13057; Off 3 3 41
  W 13073; Off 3 3 53
  W 13083; Off 1 1 65
  W 13100; Off 9 10 50
  W 13200; On 1 1 65 127
  W 13200; On 3 3 53 108
  W 13200; On 3 3 41 80
  W 13257; Off 1 1 65
  W 13257; Off 3 3 41
  W 13273; Off 3 3 53
  W 13400; On 1 1 65 127
  W 13400; On 3 3 53 104
  W 13400; On 3 3 41 104
  W 13457; Off 1 1 65
  W 13457; Off 3 3 41
  W 13467; Off 3 3 53
  W 13557; Off 4 4 53
  W 13557; Off 5 5 74
  W 13557; Off 8 8 53
  W 13567; Off 5 5 62
  W 13600; On 1 1 65 127
  W 13600; On 3 3 53 124
  W 13600; On 3 3 41 124
  W 13600; On 4 4 65 100
  W 13600; On 4 4 50 64
  W 13600; On 6 6 65 120
  W 13600; On 6 6 50 120
  W 13600; On 8 8 50 88
  W 13600; On 8 8 65 100
  W 13617; Off 6 6 53
  W 13683; Off 3 3 41
  W 13700; Off 1 1 65
  W 13700; Off 3 3 53
  W 13700; On 1 1 64 127
  W 13700; On 3 3 52 108
  W 13700; On 3 3 40 100
  W 13773; Off 1 1 64
  W 13783; Off 3 3 52
  W 13783; Off 3 3 40
  W 13800; On 1 1 62 127
  W 13800; On 3 3 50 108
  W 13800; On 3 3 38 112
  W 13867; Off 3 3 38
  W 13873; Off 1 1 62
  W 13873; Off 3 3 50
  W 14000; On 1 1 62 127
  W 14000; On 3 3 50 108
  W 14000; On 3 3 38 108
  W 14057; Off 3 3 38
  W 14067; Off 1 1 62
  W 14073; Off 3 3 50
  W 14200; Off 4 4 65
  W 14200; On 1 1 62 127
  W 14200; On 3 3 50 116
  W 14200; On 3 3 38 116
  W 14200; On 4 4 64 64
  W 14200; On 6 6 64 120
  W 14200; On 8 8 64 68
  W 14240; Off 8 8 65
  W 14257; Off 3 3 38
  W 14257; Off 6 6 65
  W 14267; Off 1 1 62
  W 14273; Off 3 3 50
  W 14350; Off 6 6 50
  W 14400; On 1 1 62 127
  W 14400; On 3 3 50 120
  W 14400; On 3 3 38 120
  W 14400; On 4 4 62 80
  W 14400; On 6 6 62 120
  W 14400; On 8 8 62 92
  W 14400; On 9 10 50 120
  W 14407; Off 4 4 64
  W 14407; Off 8 8 50
  W 14407; On 5 5 69 88
  W 14417; On 5 5 62 64
  W 14440; Off 4 4 50
  W 14440; Off 6 6 64
  W 14457; Off 1 1 62
  W 14473; Off 8 8 64
  W 14483; Off 3 3 50
  W 14483; Off 3 3 38
  W 14500; On 1 1 64 127
  W 14500; On 3 3 52 96
  W 14500; On 3 3 40 88
  W 14557; Off 1 1 64
  W 14583; Off 3 3 52
  W 14583; Off 3 3 40
  W 14600; On 1 1 65 127
  W 14600; On 3 3 53 96
  W 14600; On 3 3 41 108
  W 14623; Off 9 10 50
  W 14667; Off 3 3 53
  W 14667; Off 3 3 41
  W 14673; Off 1 1 65
  W 14800; On 1 1 65 127
  W 14800; On 3 3 53 108
  W 14800; On 3 3 41 104
  W 14857; Off 1 1 65
  W 14867; Off 3 3 53
  W 14867; Off 3 3 41
  W 14933; Off 4 4 62
  W 14933; Off 6 6 62
  W 15000; On 1 1 65 127
  W 15000; On 3 3 53 112
  W 15000; On 3 3 41 100
  W 15000; On 4 4 60 76
  W 15000; On 6 6 60 120
  W 15000; On 8 8 60 84
  W 15017; Off 8 8 62
  W 15050; Off 1 1 65
  W 15057; Off 3 3 53
  W 15057; Off 3 3 41
  W 15200; On 1 1 65 127
  W 15200; On 3 3 53 124
  W 15200; On 3 3 41 116
  W 15200; On 4 4 59 96
  W 15200; On 4 4 62 100
  W 15200; On 6 6 62 120
  W 15200; On 6 6 59 120
  W 15200; On 8 8 59 100
  W 15200; On 8 8 62 88
  W 15250; Off 8 8 60
  W 15257; Off 4 4 60
  W 15257; Off 6 6 60
  W 15273; Off 5 5 69
  W 15283; Off 5 5 62
  W 15290; Off 3 3 53
  W 15290; Off 3 3 41
  W 15300; Off 1 1 65
  W 15300; On 1 1 64 127
  W 15300; On 3 3 52 104
  W 15300; On 3 3 40 108
  W 15367; Off 1 1 64
  W 15373; Off 3 3 52
  W 15400; On 1 1 62 127
  W 15400; On 3 3 50 100
  W 15400; On 3 3 38 112
  W 15417; Off 3 3 40
  W 15457; Off 3 3 38
  W 15473; Off 1 1 62
  W 15483; Off 3 3 50
  W 15533; Off 8 8 62
  W 15600; On 1 1 62 127
  W 15600; On 3 3 50 112
  W 15600; On 3 3 38 104
  W 15607; Off 4 4 62
  W 15633; Off 6 6 62
  W 15667; Off 3 3 38
  W 15673; Off 1 1 62
  W 15683; Off 3 3 50
  W 15733; Off 4 4 59
  W 15767; Off 8 8 59
  W 15800; On 1 1 62 127
  W 15800; On 3 3 50 112
  W 15800; On 3 3 38 108
  W 15800; On 4 4 57 76
  W 15800; On 4 4 62 68
  W 15800; On 6 6 57 120
  W 15800; On 6 6 62 120
  W 15800; On 8 8 57 60
  W 15800; On 8 8 62 80
  W 15833; Off 6 6 59
  W 15857; Off 3 3 38
  W 15867; Off 1 1 62
  W 15867; Off 3 3 50
  W 15900; Off 6 6 62
  W 15907; Off 8 8 62
  W 15933; Off 4 4 62
  W 16000; Off 6 6 57
  W 16000; On 1 1 64 127
  W 16000; On 3 3 52 112
  W 16000; On 3 3 40 112
  W 16000; On 4 4 56 72
  W 16000; On 4 4 62 104
  W 16000; On 5 5 76 96
  W 16000; On 6 6 62 120
  W 16000; On 6 6 56 120
  W 16000; On 8 8 62 76
  W 16000; On 8 8 56 76
  W 16057; Off 4 4 57
  W 16083; Off 8 8 57
  W 16100; On 1 1 68 127
  W 16100; On 3 3 56 112
  W 16100; On 3 3 44 104
  W 16100; On 3 3 42 56
  W 16107; Off 3 3 42
  W 16117; Off 1 1 64
  W 16117; Off 3 3 52
  W 16140; Off 3 3 40
  W 16157; Off 1 1 68
  W 16183; Off 3 3 56
  W 16200; Off 3 3 44
  W 16200; On 1 1 71 127
  W 16200; On 3 3 59 108
  W 16200; On 3 3 47 112
  W 16257; Off 3 3 47
  W 16267; Off 1 1 71
  W 16273; Off 3 3 59
  W 16400; On 1 1 71 127
  W 16400; On 3 3 59 116
  W 16400; On 3 3 47 108
  W 16457; Off 1 1 71
  W 16457; Off 3 3 59
  W 16457; Off 3 3 47
  W 16473; Off 8 8 62
  W 16500; Off 6 6 56
  W 16520; Off 6 6 62
  W 16533; Off 4 4 62
  W 16540; Off 4 4 56
  W 16600; On 1 1 71 127
  W 16600; On 3 3 59 116
  W 16600; On 3 3 47 104
  W 16600; On 4 4 52 76
  W 16600; On 4 4 52 52
  W 16600; On 6 6 52 120
  W 16600; On 8 8 52 48
  W 16603; Off 4 4 52
  W 16650; Off 1 1 71
  W 16667; Off 3 3 59
  W 16667; Off 3 3 47
  W 16690; Off 8 8 56
  W 16800; Off 6 6 52
  W 16800; On 1 1 71 127
  W 16800; On 3 3 59 124
  W 16800; On 3 3 47 120
  W 16800; On 4 4 62 112
  W 16800; On 4 4 56 88
  W 16800; On 6 6 56 120
  W 16800; On 6 6 62 120
  W 16800; On 8 8 56 68
  W 16800; On 8 8 62 108
  W 16807; Off 8 8 52
  W 16850; Off 4 4 52
  W 16867; Off 5 5 76
  W 16883; Off 1 1 71
  W 16890; Off 3 3 59
  W 16900; On 1 1 68 127
  W 16900; On 3 3 56 112
  W 16900; On 3 3 44 116
  W 16933; Off 3 3 47
  W 16967; Off 1 1 68
  W 16983; Off 3 3 56
  W 16990; Off 3 3 44
  W 17000; On 1 1 62 127
  W 17000; On 1 1 64 127
  W 17000; On 3 3 52 112
  W 17000; On 3 3 42 12
  W 17000; On 3 3 40 112
  W 17007; Off 3 3 42
  W 17057; Off 1 1 62
  W 17067; Off 1 1 64
  W 17090; Off 3 3 52
  W 17090; Off 3 3 40
  W 17173; Off 8 8 62
  W 17200; Off 4 4 62
  W 17200; On 1 1 64 127
  W 17200; On 3 3 52 112
  W 17200; On 3 3 40 92
  W 17267; Off 1 1 64
  W 17267; Off 3 3 40
  W 17273; Off 3 3 52
  W 17317; Off 4 4 56
  W 17363; Off 6 6 56
  W 17397; Off 6 6 62
  W 17400; On 1 1 64 127
  W 17400; On 3 3 52 108
  W 17400; On 3 3 42 36
  W 17400; On 3 3 40 112
  W 17400; On 4 4 62 52
  W 17400; On 4 4 52 76
  W 17400; On 6 6 52 120
  W 17400; On 8 8 62 60
  W 17400; On 8 8 52 48
  W 17407; Off 8 8 56
  W 17417; Off 3 3 42
  W 17467; Off 1 1 64
  W 17467; Off 3 3 52
  W 17467; Off 3 3 40
  W 17523; Off 8 8 62
  W 17583; Off 4 4 62
  W 17583; Off 8 8 52
  W 17600; On 1 1 72 29
  W 17600; On 1 1 64 127
  W 17600; On 3 3 52 120
  W 17600; On 3 3 44 56
  W 17600; On 3 3 42 56
  W 17600; On 3 3 40 112
  W 17600; On 4 4 63 92
  W 17600; On 4 4 60 68
  W 17600; On 6 6 60 120
  W 17600; On 6 6 63 120
  W 17600; On 8 8 60 68
  W 17600; On 8 8 63 76
  W 17600; On 9 10 45 112
  W 17610; Off 6 6 52
  W 17617; Off 1 1 72
  W 17617; Off 3 3 44
  W 17617; On 5 5 69 96
  W 17623; Off 3 3 42
  W 17657; Off 4 4 52
  W 17673; Off 3 3 52
  W 17683; Off 1 1 64
  W 17700; On 1 1 69 127
  W 17700; On 3 3 57 112
  W 17700; On 3 3 45 96
  W 17723; Off 3 3 40
  W 17757; Off 1 1 69
  W 17767; Off 3 3 57
  W 17773; Off 3 3 45
  W 17800; On 1 1 72 127
  W 17800; On 3 3 60 120
  W 17800; On 3 3 48 116
  W 17857; Off 3 3 48
  W 17867; Off 3 3 60
  W 17873; Off 1 1 72
  W 17873; Off 9 10 45
  W 17967; Off 8 8 63
  W 18000; Off 4 4 63
  W 18000; On 1 1 72 127
  W 18000; On 3 3 60 124
  W 18000; On 3 3 48 104
  W 18067; Off 1 1 72
  W 18067; Off 3 3 60
  W 18067; Off 3 3 48
  W 18100; Off 4 4 60
  W 18100; Off 8 8 60
  W 18103; Off 6 6 60
  W 18107; Off 6 6 63
  W 18200; On 1 1 72 127
  W 18200; On 3 3 60 116
  W 18200; On 3 3 48 108
  W 18200; On 4 4 57 80
  W 18200; On 4 4 63 80
  W 18200; On 6 6 52 120
  W 18200; On 8 8 57 48
  W 18200; On 8 8 63 92
  W 18257; Off 1 1 72
  W 18257; Off 3 3 60
  W 18267; Off 3 3 48
  W 18317; Off 8 8 63
  W 18323; Off 4 4 63
  W 18400; On 1 1 72 127
  W 18400; On 3 3 60 120
  W 18400; On 3 3 48 116
  W 18400; On 4 4 63 64
  W 18400; On 4 4 60 88
  W 18400; On 6 6 60 120
  W 18400; On 6 6 63 120
  W 18400; On 8 8 60 80
  W 18400; On 8 8 63 64
  W 18440; Off 6 6 52
  W 18467; Off 4 4 57
  W 18467; Off 8 8 57
  W 18483; Off 1 1 72
  W 18483; Off 3 3 48
  W 18490; Off 3 3 60
  W 18500; On 1 1 69 127
  W 18500; On 3 3 57 104
  W 18500; On 3 3 45 100
  W 18550; Off 5 5 69
  W 18573; Off 1 1 69
  W 18583; Off 3 3 57
  W 18590; Off 3 3 45
  W 18600; On 1 1 64 127
  W 18600; On 3 3 53 12
  W 18600; On 3 3 52 116
  W 18600; On 3 3 40 112
  W 18617; Off 3 3 53
  W 18673; Off 1 1 64
  W 18683; Off 3 3 40
  W 18690; Off 3 3 52
  W 18733; Off 8 8 63
  W 18800; On 1 1 64 127
  W 18800; On 3 3 52 124
  W 18800; On 3 3 40 116
  W 18807; Off 4 4 63
  W 18873; Off 1 1 64
  W 18873; Off 3 3 52
  W 18873; Off 3 3 40
  W 18920; Off 6 6 60
  W 18957; Off 4 4 60
  W 18973; Off 8 8 60
  W 19000; On 1 1 64 121
  W 19000; On 3 3 52 120
  W 19000; On 3 3 40 116
  W 19000; On 4 4 57 60
  W 19000; On 4 4 63 88
  W 19000; On 6 6 57 120
  W 19000; On 8 8 57 52
  W 19000; On 8 8 63 84
  W 19023; Off 6 6 63
  W 19067; Off 3 3 40
  W 19073; Off 3 3 52
  W 19083; Off 1 1 64
  W 19157; Off 8 8 63
  W 19163; Off 6 6 57
  W 19200; On 1 1 56 127
  W 19200; On 1 1 74 121
  W 19200; On 1 1 76 127
  W 19200; On 1 1 64 127
  W 19200; On 1 1 71 127
  W 19200; On 3 3 52 112
  W 19200; On 3 3 40 112
  W 19200; On 4 4 56 88
  W 19200; On 4 4 64 76
  W 19200; On 6 6 64 120
  W 19200; On 8 8 56 60
  W 19200; On 8 8 64 68
  W 19203; On 6 6 56 120
  W 19207; Off 4 4 63
  W 19207; Off 8 8 57
  W 19217; Off 1 1 74
  W 19240; On 5 5 76 96
  W 19273; Off 4 4 57
  W 19440; Off 3 3 52
  W 19440; Off 3 3 40
  W 19507; Off 1 1 76
  W 19507; Off 1 1 64
  W 19523; Off 1 1 71
  W 19583; Off 1 1 56
  W 19997; On 6 6 52 120
  W 20000; Off 4 4 64
  W 20000; Off 6 6 56
  W 20000; On 0 0 64 102
  W 20000; On 3 3 52 121
  W 20000; On 3 3 40 117
  W 20000; On 4 4 67 60
  W 20000; On 4 4 64 88
  W 20017; Off 5 5 76
  W 20017; Off 6 6 64
  W 20023; Off 8 8 64
  W 20033; Off 8 8 56
  W 20050; Off 4 4 56
  W 20217; Off 3 3 52
  W 20217; Off 3 3 40
  W 20730; Off 6 6 52
  W 20773; Off 4 4 64
  W 20800; On 0 0 63 68
  W 20800; On 0 0 66 79
  W 20800; On 3 3 51 87
  W 20800; On 3 3 39 98
  W 20800; On 4 4 66 56
  W 20800; On 4 4 63 68
  W 20817; Off 0 0 64
  W 20833; Off 4 4 67
  W 20990; Off 3 3 39
  W 21017; Off 3 3 51
  W 21200; On 1 1 63 97
  W 21550; Off 0 0 63
  W 21583; Off 4 4 63
  W 21590; Off 1 1 63
  W 21600; Off 0 0 66
  W 21600; On 0 0 62 47
  W 21600; On 0 0 68 71
  W 21600; On 3 3 50 63
  W 21600; On 3 3 38 59
  W 21600; On 4 4 65 64
  W 21600; On 4 4 62 4
  W 21623; Off 4 4 66
  W 21800; Off 3 3 50
  W 21800; Off 3 3 38
  W 22000; On 1 1 62 93
  W 22323; Off 4 4 65
  W 22350; Off 4 4 62
  W 22373; Off 1 1 62
  W 22390; Off 0 0 62
  W 22390; Off 0 0 68
  W 22400; On 1 1 60 110
  W 22400; On 3 3 48 72
  W 22400; On 3 3 36 72
  W 22400; On 6 6 76 120
  W 22400; On 6 6 72 120
  W 22790; On 1 1 64 110
  W 22800; Off 3 3 48
  W 22800; Off 3 3 36
  W 22807; Off 1 1 60
  W 22957; Off 1 1 64
  W 22973; On 1 1 67 110
  W 23183; Off 1 1 67
  W 23183; On 1 1 72 110
  W 23573; On 1 1 71 110
  W 23607; Off 1 1 72
  W 23983; On 1 1 69 110
  W 23990; Off 1 1 71
  W 24373; On 1 1 67 111
  W 24383; Off 1 1 69
  W 24767; Off 1 1 67
  W 24767; On 1 1 65 111
  W 25117; Off 6 6 76
  W 25157; Off 6 6 72
  W 25173; Off 1 1 65
  W 25173; On 1 1 64 111
  W 25200; On 6 6 76 120
  W 25200; On 6 6 72 120
  W 25490; Off 6 6 72
  W 25567; Off 6 6 76
  W 25573; Off 1 1 64
  W 25573; On 1 1 62 111
  W 25600; On 6 6 77 88
  W 25600; On 6 6 72 88
  W 25983; On 1 1 64 111
  W 26000; Off 1 1 62
  W 26157; Off 1 1 64
  W 26167; On 1 1 65 111
  W 26383; Off 1 1 65
  W 26383; On 1 1 67 112
  W 26400; Off 6 6 72
  W 26400; On 6 6 71 89
  W 26717; Off 6 6 77
  W 26740; Off 6 6 71
  W 26757; On 1 1 55 112
  W 26783; Off 1 1 67
  W 26800; On 6 6 77 90
  W 26800; On 6 6 71 90
  W 27123; Off 1 1 55
  W 27140; On 1 1 60 112
  W 27167; Off 6 6 71
  W 27200; Off 6 6 77
  W 27200; On 6 6 76 90
  W 27200; On 6 6 72 90
  W 27573; Off 1 1 60
  W 27573; On 1 1 64 112
  W 27757; Off 1 1 64
  W 27767; On 1 1 67 112
  W 27973; Off 1 1 67
  W 27990; On 1 1 72 112
  W 28067; Off 6 6 76
  W 28073; Off 6 6 72
  W 28390; Off 1 1 72
  W 28390; On 1 1 67 113
  W 28567; Off 1 1 67
  W 28583; On 1 1 64 113
  W 28767; Off 1 1 64
  W 28773; On 1 1 60 113
  W 28800; On 6 6 76 92
  W 28800; On 6 6 72 92
  W 29173; On 1 1 64 113
  W 29217; Off 1 1 60
  W 29357; On 1 1 67 113
  W 29367; Off 1 1 64
  W 29573; On 1 1 72 113
  W 29583; Off 1 1 67
  W 29957; Off 6 6 76
  W 29967; On 1 1 71 113
  W 30000; Off 6 6 72
  W 30000; On 6 6 76 93
  W 30000; On 6 6 72 93
  W 30007; Off 1 1 72
  W 30290; Off 6 6 72
  W 30373; Off 6 6 76
  W 30390; On 1 1 69 114
  W 30400; On 6 6 76 94
  W 30400; On 6 6 72 94
  W 30407; Off 1 1 71
  W 30757; Off 6 6 76
  W 30767; Off 6 6 72
  W 30767; On 1 1 67 114
  W 30783; Off 1 1 69
  W 30800; On 6 6 76 94
  W 30800; On 6 6 72 94
  W 31140; Off 6 6 72
  W 31157; Off 1 1 67
  W 31157; On 1 1 65 114
  W 31183; Off 6 6 76
  W 31200; On 6 6 76 95
  W 31200; On 6 6 72 95
  W 31500; Off 6 6 72
  W 31540; Off 6 6 76
  W 31557; On 1 1 64 114
  W 31583; Off 1 1 65
  W 31600; On 6 6 76 95
  W 31600; On 6 6 72 95
  W 31890; Off 6 6 72
  W 31983; Off 1 1 64
  W 31983; On 1 1 62 114
  W 32000; On 6 6 77 96
  W 32000; On 6 6 72 96
  W 32017; Off 6 6 76
  W 32390; On 1 1 64 115
  W 32423; Off 1 1 62
  W 32583; On 1 1 65 115
  W 32590; Off 1 1 64
  W 32767; Off 6 6 72
  W 32783; Off 1 1 65
  W 32783; On 1 1 67 115
  W 32800; On 6 6 71 97
  W 33173; Off 1 1 67
  W 33183; On 1 1 55 115
  W 33490; Off 1 1 55
  W 33573; Off 6 6 77
  W 33573; On 1 1 60 115
  W 33600; On 6 6 76 98
  W 33600; On 6 6 72 98
  W 33600; On 8 8 48 84
  W 33607; On 8 8 55 84
  W 33617; On 3 3 36 116
  W 33617; On 8 8 60 64
  W 33673; Off 1 1 60
  W 33673; On 1 1 62 115
  W 33690; Off 6 6 71
  W 33717; On 3 3 38 80
  W 33723; Off 3 3 36
  W 33783; Off 1 1 62
  W 33783; On 1 1 64 115
  W 33790; Off 3 3 38
  W 33807; On 3 3 40 112
  W 33850; Off 1 1 64
  W 33873; Off 3 3 40
  W 33967; On 3 3 40 108
  W 33990; On 1 1 64 116
  W 34040; Off 3 3 40
  W 34050; Off 1 1 64
  W 34173; On 3 3 40 124
  W 34200; On 1 1 64 116
  W 34240; Off 3 3 40
  W 34267; Off 1 1 64
  W 34383; On 3 3 39 112
  W 34390; On 8 8 63 88
  W 34407; Off 8 8 60
  W 34417; On 1 1 63 116
  W 34417; On 4 4 55 108
  W 34440; On 7 7 55 116
  W 34457; Off 3 3 39
  W 34457; On 7 7 56 36
  W 34473; Off 7 7 56
  W 34473; On 3 3 38 112
  W 34483; Off 6 6 76
  W 34490; Off 1 1 63
  W 34517; On 1 1 62 116
  W 34523; Off 6 6 72
  W 34540; Off 3 3 38
  W 34567; On 3 3 36 112
  W 34583; Off 1 1 62
  W 34600; On 1 1 60 116
  W 34640; Off 3 3 36
  W 34673; Off 1 1 60
  W 34773; On 3 3 36 104
  W 34790; On 1 1 60 116
  W 34807; On 8 8 60 96
  W 34817; Off 8 8 55
  W 34850; Off 3 3 36
  W 34867; Off 1 1 60
  W 34973; On 3 3 36 112
  W 34990; On 1 1 60 116
  W 35000; On 4 4 60 104
  W 35017; Off 4 4 55
  W 35017; On 7 7 60 116
  W 35033; Off 3 3 36
  W 35033; Off 7 7 55
  W 35050; Off 1 1 60
  W 35190; Off 7 7 60
  W 35190; On 3 3 43 124
  W 35200; On 1 1 55 116
  W 35200; On 8 8 55 64
  W 35217; On 4 4 59 64
  W 35217; On 8 8 59 80
  W 35223; Off 8 8 60
  W 35233; Off 4 4 60
  W 35233; On 7 7 59 116
  W 35233; On 8 8 62 84
  W 35240; Off 8 8 48
  W 35250; Off 3 3 43
  W 35257; Off 8 8 63
  W 35283; On 3 3 45 116
  W 35300; On 1 1 57 116
  W 35307; Off 1 1 55
  W 35340; Off 3 3 45
  W 35383; Off 1 1 57
  W 35383; On 3 3 47 124
  W 35400; On 1 1 59 116
  W 35467; Off 1 1 59
  W 35467; Off 3 3 47
  W 35583; On 3 3 47 124
  W 35590; On 1 1 59 116
  W 35650; Off 3 3 47
  W 35667; Off 1 1 59
  W 35790; On 1 1 59 116
  W 35790; On 3 3 47 124
  W 35850; Off 3 3 47
  W 35867; Off 1 1 59
  W 35990; On 1 1 58 117
  W 36000; On 3 3 46 124
  W 36000; On 4 4 55 80
  W 36007; Off 7 7 59
  W 36017; On 7 7 55 112
  W 36017; On 8 8 58 84
  W 36023; Off 4 4 59
  W 36023; On 4 4 62 108
  W 36033; On 7 7 62 116
  W 36040; Off 8 8 59
  W 36073; Off 3 3 46
  W 36083; Off 1 1 58
  W 36083; On 1 1 57 117
  W 36090; On 3 3 45 96
  W 36150; Off 3 3 45
  W 36167; Off 1 1 57
  W 36173; On 3 3 43 116
  W 36183; On 1 1 55 117
  W 36250; Off 3 3 43
  W 36257; Off 1 1 55
  W 36383; On 1 1 55 117
  W 36383; On 3 3 43 112
  W 36407; On 8 8 67 104
  W 36423; Off 8 8 62
  W 36450; Off 3 3 43
  W 36467; Off 1 1 55
  W 36583; On 1 1 55 117
  W 36583; On 3 3 43 112
  W 36600; On 4 4 67 108
  W 36600; On 7 7 67 112
  W 36617; Off 4 4 62
  W 36617; Off 7 7 62
  W 36633; Off 1 1 55
  W 36640; Off 3 3 43
  W 36773; Off 7 7 55
  W 36773; Off 8 8 55
  W 36783; Off 4 4 55
  W 36783; On 1 1 62 117
  W 36790; On 3 3 38 120
  W 36790; On 5 5 62 80
  W 36790; On 5 5 74 76
  W 36790; On 8 8 66 76
  W 36800; On 4 4 66 80
  W 36800; On 8 8 50 100
  W 36800; On 9 10 50 124
  W 36807; Off 8 8 67
  W 36807; On 8 8 57 88
  W 36817; Off 8 8 58
  W 36817; On 7 7 66 120
  W 36823; Off 4 4 67
  W 36833; Off 7 7 67
  W 36873; Off 3 3 38
  W 36883; On 1 1 64 117
  W 36883; On 3 3 39 72
  W 36890; Off 1 1 62
  W 36890; On 3 3 40 108
  W 36923; Off 3 3 39
  W 36950; Off 3 3 40
  W 36950; Off 9 10 50
  W 36957; Off 1 1 64
  W 36967; On 1 1 66 117
  W 36990; On 3 3 42 104
  W 37000; On 1 1 67 117
  W 37017; Off 1 1 66
  W 37017; Off 1 1 67
  W 37073; Off 3 3 42
  W 37173; On 1 1 66 117
  W 37200; On 3 3 42 124
  W 37240; Off 1 1 66
  W 37273; Off 3 3 42
  W 37373; On 1 1 66 117
  W 37407; On 3 3 42 124
  W 37440; Off 1 1 66
  W 37473; Off 3 3 42
  W 37590; Off 5 5 62
  W 37590; Off 5 5 74
  W 37590; On 1 1 65 117
  W 37600; Off 7 7 66
  W 37600; On 7 7 57 108
  W 37607; On 3 3 41 84
  W 37607; On 7 7 62 84
  W 37623; Off 4 4 66
  W 37623; On 4 4 62 92
  W 37640; Off 8 8 66
  W 37640; On 4 4 57 108
  W 37650; On 8 8 62 64
  W 37667; Off 1 1 65
  W 37683; On 1 1 64 117
  W 37700; Off 3 3 41
  W 37707; On 3 3 40 96
  W 37750; Off 1 1 64
  W 37773; On 1 1 62 118
  W 37800; Off 3 3 40
  W 37817; On 3 3 38 124
  W 37850; Off 1 1 62
  W 37890; Off 3 3 38
  W 37983; On 1 1 62 118
  W 38017; On 3 3 38 120
  W 38040; Off 8 8 62
  W 38040; On 8 8 62 100
  W 38050; Off 8 8 57
  W 38057; Off 1 1 62
  W 38100; Off 3 3 38
  W 38157; Off 7 7 57
  W 38157; Off 7 7 62
  W 38157; On 7 7 62 96
  W 38190; On 1 1 62 118
  W 38200; Off 4 4 62
  W 38200; On 4 4 62 112
  W 38207; On 3 3 38 120
  W 38217; Off 4 4 57
  W 38250; Off 1 1 62
  W 38267; Off 3 3 38
  W 38340; Off 7 7 62
  W 38390; On 5 5 57 80
  W 38390; On 5 5 69 52
  W 38400; On 7 7 61 124
  W 38400; On 8 8 57 80
  W 38400; On 9 10 45 124
  W 38407; On 1 1 57 118
  W 38417; On 4 4 61 92
  W 38433; Off 4 4 62
  W 38433; Off 8 8 50
  W 38433; On 3 3 45 108
  W 38440; On 8 8 61 88
  W 38457; Off 8 8 62
  W 38483; Off 1 1 57
  W 38500; Off 3 3 45
  W 38507; On 1 1 59 118
  W 38523; On 3 3 47 112
  W 38567; Off 1 1 59
  W 38573; Off 3 3 47
  W 38583; Off 9 10 45
  W 38600; On 1 1 61 118
  W 38617; On 3 3 49 120
  W 38657; Off 1 1 61
  W 38683; Off 3 3 49
  W 38790; On 1 1 61 118
  W 38807; On 3 3 49 124
  W 38867; On 8 8 64 88
  W 38873; Off 1 1 61
  W 38873; Off 3 3 49
  W 39000; On 1 1 61 118
  W 39000; On 3 3 49 120
  W 39067; Off 3 3 49
  W 39073; Off 1 1 61
  W 39173; Off 5 5 69
  W 39183; Off 5 5 57
  W 39200; On 3 3 48 108
  W 39207; Off 7 7 61
  W 39207; On 1 1 60 118
  W 39207; On 7 7 64 108
  W 39217; Off 4 4 61
  W 39223; On 4 4 57 108
  W 39223; On 7 7 57 120
  W 39233; On 8 8 60 96
  W 39240; Off 8 8 61
  W 39257; On 4 4 64 120
  W 39267; Off 3 3 48
  W 39290; On 1 1 59 118
  W 39290; On 3 3 47 96
  W 39300; Off 1 1 60
  W 39357; Off 3 3 47
  W 39373; Off 1 1 59
  W 39390; On 1 1 57 118
  W 39390; On 3 3 45 112
  W 39457; Off 3 3 45
  W 39473; Off 1 1 57
  W 39590; On 1 1 57 118
  W 39590; On 3 3 45 116
  W 39590; On 8 8 69 80
  W 39607; Off 8 8 64
  W 39657; Off 3 3 45
  W 39690; Off 1 1 57
  W 39773; On 7 7 69 112
  W 39783; On 1 1 57 119
  W 39783; On 3 3 45 120
  W 39790; Off 7 7 64
  W 39800; On 4 4 69 120
  W 39807; Off 4 4 64
  W 39833; Off 1 1 57
  W 39840; Off 3 3 45
  W 39940; Off 7 7 57
  W 39973; On 3 3 41 112
  W 39973; On 3 3 40 104
  W 39990; On 1 1 64 119
  W 39990; On 3 3 46 32
  W 39990; On 5 5 76 40
  W 40000; Off 8 8 57
  W 40000; On 7 7 68 120
  W 40000; On 8 8 52 88
  W 40000; On 8 8 68 60
  W 40007; Off 3 3 46
  W 40017; On 8 8 59 112
  W 40023; Off 7 7 69
  W 40023; Off 8 8 60
  W 40023; Off 8 8 69
  W 40023; On 4 4 68 120
  W 40033; Off 4 4 57
  W 40040; Off 3 3 41
  W 40040; Off 4 4 69
  W 40057; Off 3 3 40
  W 40067; On 3 3 42 108
  W 40083; Off 1 1 64
  W 40090; On 1 1 66 119
  W 40133; Off 3 3 42
  W 40150; Off 1 1 66
  W 40157; On 3 3 44 100
  W 40173; On 1 1 68 119
  W 40233; Off 3 3 44
  W 40240; Off 1 1 68
  W 40367; On 3 3 44 104
  W 40390; On 1 1 68 119
  W 40440; Off 3 3 44
  W 40457; Off 1 1 68
  W 40573; On 3 3 44 120
  W 40583; On 1 1 68 119
  W 40600; On 3 3 46 4
  W 40607; Off 3 3 46
  W 40650; Off 1 1 68
  W 40650; Off 3 3 44
  W 40673; Off 5 5 76
  W 40783; On 3 3 43 124
  W 40790; On 1 1 67 119
  W 40807; On 4 4 59 112
  W 40817; On 7 7 59 64
  W 40823; Off 7 7 68
  W 40823; On 4 4 64 112
  W 40823; On 7 7 64 116
  W 40823; On 8 8 64 76
  W 40833; Off 8 8 68
  W 40850; Off 4 4 68
  W 40873; Off 1 1 67
  W 40873; Off 3 3 43
  W 40873; On 3 3 42 108
  W 40883; On 1 1 66 119
  W 40950; Off 1 1 66
  W 40950; Off 3 3 42
  W 40967; On 1 1 64 119
  W 40967; On 3 3 40 116
  W 41040; Off 1 1 64
  W 41040; Off 3 3 40
  W 41167; On 3 3 40 112
  W 41173; On 1 1 64 119
  W 41200; Off 8 8 64
  W 41200; On 8 8 64 100
  W 41217; Off 8 8 59
  W 41233; Off 3 3 40
  W 41240; Off 1 1 64
  W 41367; Off 7 7 59
  W 41367; Off 7 7 64
  W 41367; On 3 3 40 104
  W 41367; On 7 7 64 120
  W 41373; Off 4 4 64
  W 41373; On 1 1 64 119
  W 41373; On 4 4 64 108
  W 41383; Off 4 4 59
  W 41423; Off 1 1 64
  W 41423; Off 3 3 40
  W 41517; Off 7 7 64
  W 41550; Off 4 4 64
  W 41573; On 1 1 57 119
  W 41573; On 3 3 45 116
  W 41590; On 5 5 57 48
  W 41590; On 5 5 69 52
  W 41590; On 7 7 64 116
  W 41590; On 7 7 65 120
  W 41600; On 4 4 64 112
  W 41600; On 4 4 65 112
  W 41600; On 8 8 57 52
  W 41600; On 9 10 45 124
  W 41617; Off 8 8 52
  W 41617; On 8 8 65 88
  W 41657; Off 3 3 45
  W 41667; On 1 1 59 110
  W 41673; Off 1 1 57
  W 41673; On 3 3 47 88
  W 41733; Off 3 3 47
  W 41750; Off 1 1 59
  W 41767; Off 9 10 45
  W 41767; On 1 1 60 110
  W 41767; On 3 3 48 116
  W 41833; Off 1 1 60
  W 41833; Off 3 3 48
  W 41957; On 1 1 60 111
  W 41967; On 3 3 48 116
  W 42033; Off 1 1 60
  W 42040; Off 3 3 48
  W 42123; Off 7 7 64
  W 42167; On 1 1 60 112
  W 42173; On 3 3 48 120
  W 42190; On 7 7 57 84
  W 42200; On 4 4 57 116
  W 42207; Off 4 4 64
  W 42233; Off 1 1 60
  W 42240; Off 3 3 48
  W 42307; Off 5 5 69
  W 42317; Off 5 5 57
  W 42367; Off 7 7 57
  W 42367; On 1 1 59 112
  W 42390; On 3 3 47 124
  W 42400; On 8 8 59 76
  W 42400; On 8 8 62 104
  W 42407; On 4 4 62 104
  W 42407; On 7 7 62 124
  W 42417; Off 4 4 57
  W 42417; Off 8 8 57
  W 42423; Off 8 8 64
  W 42450; Off 1 1 59
  W 42457; Off 3 3 47
  W 42457; On 1 1 60 113
  W 42483; On 3 3 48 112
  W 42533; Off 1 1 60
  W 42533; On 1 1 62 113
  W 42550; Off 3 3 48
  W 42573; On 3 3 50 108
  W 42607; Off 1 1 62
  W 42650; Off 3 3 50
  W 42723; On 1 1 62 114
  W 42773; On 3 3 50 112
  W 42773; On 8 8 67 100
  W 42790; Off 1 1 62
  W 42790; Off 8 8 65
  W 42800; On 4 4 67 92
  W 42823; Off 4 4 65
  W 42850; Off 3 3 50
  W 42873; Off 7 7 62
  W 42917; Off 4 4 62
  W 42940; On 1 1 62 114
  W 42957; On 3 3 50 104
  W 42967; On 4 4 62 96
  W 42983; On 7 7 62 116
  W 43000; Off 1 1 62
  W 43000; On 7 7 67 112
  W 43023; Off 3 3 50
  W 43023; Off 7 7 65
  W 43100; Off 4 4 62
  W 43133; Off 7 7 62
  W 43167; On 1 1 60 115
  W 43173; Off 8 8 59
  W 43173; On 4 4 62 104
  W 43183; On 3 3 47 96
  W 43183; On 3 3 48 88
  W 43190; On 7 7 62 104
  W 43190; On 8 8 64 88
  W 43200; Off 7 7 67
  W 43200; Off 8 8 67
  W 43200; On 7 7 64 112
  W 43200; On 8 8 60 76
  W 43207; On 4 4 64 112
  W 43217; Off 4 4 67
  W 43240; Off 3 3 47
  W 43250; Off 3 3 48
  W 43267; On 1 1 62 116
  W 43273; Off 1 1 60
  W 43283; On 3 3 50 108
  W 43340; Off 1 1 62
  W 43350; On 1 1 64 116
  W 43367; On 3 3 52 104
  W 43383; Off 3 3 50
  W 43417; Off 1 1 64
  W 43433; Off 3 3 52
  W 43550; On 1 1 64 117
  W 43567; On 3 3 52 112
  W 43623; Off 1 1 64
  W 43640; Off 3 3 52
  W 43733; Off 7 7 64
  W 43740; Off 4 4 64
  W 43750; Off 7 7 62
  W 43757; On 1 1 64 117
  W 43757; On 3 3 52 104
  W 43790; Off 4 4 62
  W 43790; On 4 4 55 92
  W 43800; On 7 7 64 112
  W 43807; On 4 4 64 112
  W 43817; Off 1 1 64
  W 43817; Off 3 3 52
  W 43823; On 7 7 55 116
  W 43923; Off 4 4 64
  W 43940; Off 7 7 64
  W 43973; Off 8 8 60
  W 43973; On 8 8 60 112
  W 43983; On 1 1 64 118
  W 43983; On 3 3 40 104
  W 43990; On 3 3 41 16
  W 44000; Off 4 4 55
  W 44000; Off 8 8 62
  W 44000; On 4 4 60 104
  W 44000; On 7 7 64 108
  W 44000; On 8 8 52 64
  W 44007; Off 3 3 41
  W 44007; On 4 4 64 124
  W 44017; Off 7 7 55
  W 44017; On 7 7 60 104
  W 44067; On 1 1 65 118
  W 44073; Off 1 1 64
  W 44073; Off 3 3 40
  W 44073; On 3 3 41 108
  W 44133; Off 1 1 65
  W 44133; Off 3 3 41
  W 44157; On 3 3 43 112
  W 44167; On 1 1 67 119
  W 44233; Off 1 1 67
  W 44267; Off 3 3 43
  W 44373; On 1 1 67 120
  W 44373; On 3 3 43 124
  W 44423; On 8 8 65 60
  W 44433; Off 8 8 64
  W 44450; Off 1 1 67
  W 44457; Off 3 3 43
  W 44517; Off 7 7 60
  W 44523; Off 4 4 60
  W 44573; On 1 1 67 120
  W 44573; On 3 3 43 120
  W 44600; On 4 4 60 76
  W 44600; On 7 7 60 112
  W 44607; On 7 7 65 84
  W 44623; On 4 4 65 88
  W 44633; Off 7 7 64
  W 44640; Off 1 1 67
  W 44640; Off 4 4 64
  W 44650; Off 3 3 43
  W 44717; Off 7 7 60
  W 44767; Off 4 4 60
  W 44783; On 1 1 66 121
  W 44783; On 3 3 42 88
  W 44790; On 5 5 62 28
  W 44790; On 5 5 74 52
  W 44800; Off 8 8 65
  W 44800; On 7 7 60 120
  W 44800; On 8 8 54 76
  W 44800; On 9 10 50 124
  W 44807; Off 7 7 65
  W 44807; On 7 7 62 112
  W 44807; On 8 8 62 60
  W 44823; Off 4 4 65
  W 44823; On 4 4 60 100
  W 44823; On 4 4 62 104
  W 44840; Off 8 8 52
  W 44840; Off 9 10 50
  W 44867; Off 1 1 66
  W 44873; Off 3 3 42
  W 44873; On 1 1 67 121
  W 44873; On 3 3 43 100
  W 44940; Off 1 1 67
  W 44967; Off 3 3 43
  W 44967; On 1 1 69 122
  W 44973; On 3 3 45 112
  W 45040; Off 1 1 69
  W 45083; Off 3 3 45
  W 45167; On 3 3 45 88
  W 45173; On 1 1 69 123
  W 45240; Off 1 1 69
  W 45257; Off 3 3 45
  W 45340; Off 4 4 62
  W 45357; On 3 3 45 40
  W 45383; Off 7 7 60
  W 45383; Off 7 7 62
  W 45390; On 1 1 69 123
  W 45400; On 1 1 68 123
  W 45407; Off 4 4 60
  W 45417; Off 1 1 68
  W 45417; On 4 4 54 112
  W 45417; On 4 4 62 108
  W 45417; On 7 7 54 116
  W 45423; On 7 7 62 100
  W 45450; Off 1 1 69
  W 45450; Off 3 3 45
  W 45467; Off 5 5 74
  W 45473; Off 5 5 62
  W 45533; Off 4 4 62
  W 45557; Off 7 7 62
  W 45583; On 3 3 44 60
  W 45600; Off 7 7 54
  W 45600; On 8 8 56 72
  W 45607; On 1 1 68 124
  W 45607; On 8 8 59 96
  W 45617; Off 8 8 60
  W 45617; On 7 7 59 124
  W 45623; On 7 7 62 124
  W 45633; Off 8 8 54
  W 45633; On 4 4 62 120
  W 45650; On 4 4 59 104
  W 45657; Off 4 4 54
  W 45673; Off 3 3 44
  W 45673; On 3 3 45 84
  W 45690; Off 1 1 68
  W 45700; On 1 1 69 124
  W 45767; Off 3 3 45
  W 45773; Off 1 1 69
  W 45773; On 3 3 47 84
  W 45800; On 1 1 71 125
  W 45890; Off 1 1 71
  W 45900; Off 3 3 47
  W 45983; On 3 3 47 96
  W 45990; On 1 1 71 126
  W 46023; On 8 8 64 68
  W 46033; Off 8 8 62
  W 46073; Off 1 1 71
  W 46090; Off 3 3 47
  W 46140; Off 7 7 59
  W 46173; Off 4 4 59
  W 46190; On 3 3 47 104
  W 46200; On 1 1 71 126
  W 46217; On 7 7 59 124
  W 46233; On 4 4 59 84
  W 46250; On 4 4 64 80
  W 46250; On 7 7 64 100
  W 46267; Off 1 1 71
  W 46267; Off 4 4 62
  W 46267; Off 7 7 62
  W 46273; Off 3 3 47
  W 46373; Off 7 7 59
  W 46390; On 5 5 69 44
  W 46390; On 5 5 57 28
  W 46400; On 1 1 69 127
  W 46400; On 8 8 57 64
  W 46400; On 9 10 45 112
  W 46407; On 3 3 45 112
  W 46423; Off 8 8 59
  W 46423; Off 8 8 57
  W 46423; On 8 8 57 104
  W 46433; Off 4 4 59
  W 46433; On 4 4 57 116
  W 46433; On 7 7 57 124
  W 46433; On 8 8 60 88
  W 46440; Off 8 8 56
  W 46440; Off 8 8 64
  W 46450; Off 4 4 64
  W 46450; On 7 7 56 64
  W 46457; Off 7 7 64
  W 46457; On 4 4 60 100
  W 46457; On 7 7 60 112
  W 46467; Off 7 7 56
  W 46490; Off 1 1 69
  W 46490; On 1 1 71 127
  W 46507; On 3 3 47 100
  W 46517; Off 3 3 45
  W 46533; Off 9 10 45
  W 46583; Off 3 3 47
  W 46583; On 1 1 72 127
  W 46590; Off 1 1 71
  W 46600; On 3 3 48 112
  W 46667; Off 1 1 72
  W 46717; Off 3 3 48
  W 46773; On 1 1 72 127
  W 46800; On 3 3 48 112
  W 46857; Off 1 1 72
  W 46890; Off 3 3 48
  W 46907; Off 7 7 57
  W 46940; Off 4 4 57
  W 46950; Off 4 4 60
  W 46950; Off 7 7 60
  W 46973; On 1 1 72 127
  W 46990; On 3 3 48 92
  W 47000; On 7 7 57 96
  W 47000; On 7 7 60 84
  W 47007; On 4 4 60 80
  W 47017; On 4 4 57 84
  W 47057; Off 3 3 48
  W 47073; Off 1 1 72
  W 47157; Off 5 5 57
  W 47173; Off 5 5 69
  W 47173; On 1 1 67 127
  W 47200; Off 7 7 57
  W 47200; On 8 8 55 96
  W 47207; On 7 7 58 112
  W 47217; Off 7 7 60
  W 47217; On 3 3 43 108
  W 47217; On 7 7 61 84
  W 47223; Off 4 4 60
  W 47223; On 8 8 58 112
  W 47223; On 8 8 61 68
  W 47233; On 4 4 61 92
  W 47240; Off 8 8 60
  W 47250; On 4 4 58 96
  W 47257; Off 8 8 57
  W 47273; Off 1 1 67
  W 47273; Off 4 4 57
  W 47273; On 1 1 69 127
  W 47290; Off 3 3 43
  W 47307; On 3 3 45 88
  W 47333; Off 1 1 69
  W 47350; On 1 1 70 127
  W 47373; Off 3 3 45
  W 47400; On 3 3 46 120
  W 47440; Off 1 1 70
  W 47490; Off 3 3 46
  W 47567; On 1 1 70 127
  W 47607; On 3 3 46 104
  W 47640; Off 1 1 70
  W 47683; Off 3 3 46
  W 47717; Off 7 7 61
  W 47733; Off 4 4 58
  W 47740; Off 7 7 58
  W 47767; Off 4 4 61
  W 47767; On 1 1 70 127
  W 47790; On 3 3 46 120
  W 47800; On 4 4 58 84
  W 47800; On 7 7 58 116
  W 47807; On 7 7 61 108
  W 47817; On 4 4 61 92
  W 47833; Off 1 1 70
  W 47850; Off 3 3 46
  W 47967; Off 7 7 58
  W 47973; Off 8 8 55
  W 47983; Off 8 8 61
  W 47990; On 1 1 66 127
  W 47990; On 5 5 62 32
  W 47990; On 5 5 74 60
  W 47990; On 7 7 57 116
  W 47990; On 8 8 62 64
  W 48000; Off 4 4 61
  W 48000; On 3 3 42 92
  W 48000; On 8 8 54 92
  W 48000; On 9 10 50 124
  W 48007; Off 7 7 61
  W 48007; Off 8 8 58
  W 48007; On 7 7 62 112
  W 48007; On 8 8 57 112
  W 48017; Off 4 4 58
  W 48023; On 4 4 57 88
  W 48040; Off 9 10 50
  W 48040; On 4 4 62 96
  W 48083; Off 1 1 66
  W 48083; Off 3 3 42
  W 48083; On 1 1 67 127
  W 48090; On 3 3 43 112
  W 48157; Off 1 1 67
  W 48167; Off 3 3 43
  W 48173; On 1 1 69 127
  W 48190; On 3 3 45 80
  W 48267; Off 1 1 69
  W 48283; Off 3 3 45
  W 48373; On 1 1 69 127
  W 48373; On 3 3 45 100
  W 48440; Off 3 3 45
  W 48457; Off 1 1 69
  W 48523; Off 7 7 57
  W 48523; Off 7 7 62
  W 48540; Off 4 4 57
  W 48550; Off 4 4 62
  W 48573; On 3 3 45 104
  W 48583; On 1 1 69 127
  W 48590; On 7 7 57 120
  W 48623; On 4 4 57 108
  W 48623; On 4 4 62 104
  W 48623; On 7 7 62 116
  W 48633; Off 3 3 45
  W 48673; Off 5 5 62
  W 48683; Off 5 5 74
  W 48690; Off 1 1 69
  W 48740; Off 8 8 57
  W 48757; Off 8 8 62
  W 48767; Off 4 4 62
  W 48773; Off 4 4 57
  W 48783; On 3 3 45 112
  W 48790; Off 7 7 62
  W 48800; On 1 1 69 127
  W 48800; On 8 8 57 116
  W 48817; Off 7 7 57
  W 48817; On 7 7 62 120
  W 48823; On 8 8 62 80
  W 48840; On 4 4 57 116
  W 48840; On 4 4 62 108
  W 48850; On 7 7 57 116
  W 48873; On 3 3 43 92
  W 48873; On 7 7 59 4
  W 48890; Off 3 3 45
  W 48900; Off 7 7 59
  W 48907; On 1 1 67 127
  W 48917; Off 1 1 69
  W 48957; Off 3 3 43
  W 48973; On 3 3 42 112
  W 48990; Off 1 1 67
  W 48990; On 1 1 66 127
  W 49050; Off 3 3 42
  W 49067; Off 1 1 66
  W 49173; On 3 3 42 104
  W 49200; On 1 1 66 127
  W 49250; Off 3 3 42
  W 49267; Off 1 1 66
  W 49323; Off 7 7 62
  W 49350; Off 4 4 62
  W 49357; Off 4 4 57
  W 49357; On 3 3 42 116
  W 49373; Off 7 7 57
  W 49400; On 1 1 66 127
  W 49417; On 7 7 59 120
  W 49423; On 4 4 57 112
  W 49433; Off 3 3 42
  W 49433; On 4 4 62 116
  W 49433; On 8 8 59 108
  W 49450; Off 8 8 57
  W 49457; On 7 7 62 120
  W 49467; Off 1 1 66
  W 49573; On 3 3 41 124
  W 49590; Off 4 4 62
  W 49590; On 5 5 57 24
  W 49590; On 5 5 69 68
  W 49600; On 1 1 65 127
  W 49600; On 8 8 53 68
  W 49600; On 9 10 45 124
  W 49607; Off 4 4 57
  W 49617; Off 7 7 59
  W 49623; Off 7 7 62
  W 49623; On 7 7 60 120
  W 49623; On 8 8 60 112
  W 49633; On 4 4 63 116
  W 49633; On 8 8 63 92
  W 49640; Off 8 8 54
  W 49650; Off 3 3 41
  W 49650; Off 8 8 59
  W 49650; Off 9 10 45
  W 49657; Off 8 8 62
  W 49657; On 4 4 60 104
  W 49657; On 7 7 63 116
  W 49667; On 3 3 43 108
  W 49690; Off 1 1 65
  W 49700; On 1 1 67 127
  W 49733; Off 3 3 43
  W 49757; Off 1 1 67
  W 49767; On 3 3 45 112
  W 49800; On 1 1 69 127
  W 49840; Off 3 3 45
  W 49867; Off 1 1 69
  W 49973; On 3 3 45 112
  W 50000; On 1 1 69 127
  W 50033; Off 3 3 45
  W 50067; Off 1 1 69
  W 50117; Off 4 4 63
  W 50150; Off 4 4 60
  W 50150; Off 7 7 60
  W 50173; Off 7 7 63
  W 50183; On 3 3 45 112
  W 50200; On 4 4 63 112
  W 50207; On 1 1 69 127
  W 50217; On 7 7 60 104
  W 50223; On 7 7 63 116
  W 50240; Off 3 3 45
  W 50250; On 4 4 60 92
  W 50267; Off 1 1 69
  W 50357; Off 4 4 63
  W 50367; Off 7 7 60
  W 50367; Off 7 7 63
  W 50400; On 3 3 45 116
  W 50417; Off 5 5 57
  W 50417; On 1 1 69 127
  W 50417; On 7 7 63 124
  W 50423; On 4 4 63 92
  W 50433; Off 5 5 69
  W 50433; On 7 7 59 124
  W 50433; On 8 8 59 112
  W 50450; Off 4 4 60
  W 50457; Off 8 8 60
  W 50483; On 4 4 59 80
  W 50500; On 3 3 43 120
  W 50517; Off 3 3 45
  W 50517; On 1 1 67 127
  W 50523; Off 1 1 69
  W 50567; Off 3 3 43
  W 50583; Off 1 1 67
  W 50590; On 3 3 41 104
  W 50607; On 1 1 65 127
  W 50657; Off 3 3 41
  W 50683; Off 1 1 65
  W 50807; On 1 1 65 127
  W 50807; On 3 3 41 120
  W 50867; Off 3 3 41
  W 50883; Off 1 1 65
  W 50923; Off 4 4 63
  W 50950; Off 7 7 63
  W 50983; On 1 1 65 127
  W 50990; Off 4 4 59
  W 51000; On 3 3 41 112
  W 51000; On 7 7 63 76
  W 51017; Off 7 7 59
  W 51017; Off 8 8 59
  W 51017; On 3 3 42 16
  W 51017; On 4 4 63 112
  W 51017; On 7 7 57 96
  W 51017; On 8 8 57 92
  W 51023; Off 3 3 42
  W 51033; Off 1 1 65
  W 51033; On 4 4 57 84
  W 51057; Off 3 3 41
  W 51117; Off 7 7 57
  W 51157; Off 7 7 63
  W 51183; Off 4 4 57
  W 51200; On 7 7 64 120
  W 51200; On 8 8 52 52
  W 51207; Off 4 4 63
  W 51223; Off 8 8 57
  W 51223; On 1 1 64 105
  W 51223; On 1 1 71 127
  W 51223; On 3 3 40 124
  W 51223; On 4 4 64 100
  W 51223; On 7 7 56 124
  W 51223; On 8 8 64 64
  W 51223; On 8 8 56 36
  W 51233; Off 8 8 53
  W 51233; On 1 1 76 127
  W 51257; On 4 4 56 108
  W 51267; Off 8 8 63
  W 51400; Off 3 3 40
  W 51507; Off 1 1 76
  W 51517; Off 1 1 64
  W 51517; Off 1 1 71
  W 51600; On 1 1 64 127
  W 51657; Off 8 8 52
  W 51983; Off 1 1 64
  W 51990; Off 4 4 64
  W 52007; Off 7 7 64
  W 52007; Off 7 7 56
  W 52007; On 7 7 52 116
  W 52017; Off 7 7 52
  W 52017; On 3 3 38 116
  W 52017; On 7 7 52 112
  W 52023; Off 4 4 56
  W 52050; Off 8 8 56
  W 52057; Off 8 8 64
  W 52067; On 4 4 56 40
  W 52073; On 0 0 64 88
  W 52073; On 4 4 59 48
  W 52257; Off 3 3 38
  W 52367; On 1 1 62 105
  W 52733; Off 1 1 62
  W 52740; Off 4 4 56
  W 52773; On 4 4 57 40
  W 52783; Off 7 7 52
  W 52783; On 4 4 60 88
  W 52790; Off 4 4 59
  W 52790; On 3 3 36 120
  W 52867; On 0 0 66 84
  W 52867; On 0 0 63 68
  W 52873; Off 0 0 64
  W 53050; Off 3 3 36
  W 53140; On 1 1 60 77
  W 53550; Off 1 1 60
  W 53573; On 3 3 35 100
  W 53590; On 4 4 62 52
  W 53600; Off 0 0 63
  W 53600; On 4 4 59 68
  W 53617; Off 4 4 60
  W 53623; Off 4 4 57
  W 53633; On 0 0 62 32
  W 53633; On 0 0 68 76
  W 53657; Off 0 0 66
  W 53823; Off 3 3 35
  W 53923; On 1 1 59 41
  W 54383; Off 0 0 62
  W 54383; Off 0 0 68
  W 54400; Off 4 4 59
  W 54400; On 0 0 69 100
  W 54400; On 0 0 60 52
  W 54400; On 1 1 57 101
  W 54400; On 3 3 33 80
  W 54400; On 6 6 72 100
  W 54400; On 6 6 69 120
  W 54407; Off 4 4 62
  W 54407; On 4 4 64 108
  W 54407; On 4 4 57 96
  W 54423; Off 1 1 59
  W 54767; Off 1 1 57
  W 54800; Off 3 3 33
  W 54800; On 1 1 60 101
  W 54990; Off 1 1 60
  W 55000; On 1 1 64 89
  W 55200; On 1 1 69 121
  W 55217; Off 1 1 64
  W 55257; Off 0 0 69
  W 55257; Off 0 0 60
  W 55317; Off 4 4 57
  W 55323; Off 4 4 64
  W 55600; On 1 1 67 125
  W 55733; Off 1 1 69
  W 56000; On 1 1 65 93
  W 56007; Off 1 1 67
  W 56400; On 1 1 64 69
  W 56407; Off 1 1 65
  W 56800; On 1 1 62 73
  W 56857; Off 1 1 64
  W 56950; Off 6 6 69
  W 57083; Off 6 6 72
  W 57200; Off 1 1 62
  W 57200; On 1 1 60 69
  W 57200; On 6 6 72 105
  W 57200; On 6 6 69 109
  W 57540; Off 6 6 69
  W 57600; On 1 1 59 77
  W 57600; On 6 6 74 109
  W 57600; On 6 6 69 101
  W 57607; Off 1 1 60
  W 57650; Off 6 6 72
  W 58000; On 1 1 60 89
  W 58017; Off 1 1 59
  W 58200; On 1 1 62 85
  W 58240; Off 1 1 60
  W 58400; On 1 1 64 93
  W 58400; On 6 6 68 93
  W 58407; Off 6 6 69
  W 58433; Off 1 1 62
  W 58600; On 1 1 62 113
  W 58633; Off 1 1 64
  W 58690; Off 6 6 74
  W 58750; Off 6 6 68
  W 58800; On 1 1 64 109
  W 58800; On 6 6 74 93
  W 58800; On 6 6 68 108
  W 58833; Off 1 1 62
  W 59200; Off 6 6 68
  W 59200; On 1 1 57 85
  W 59200; On 6 6 72 80
  W 59200; On 6 6 69 103
  W 59217; Off 1 1 64
  W 59223; Off 6 6 74
  W 59600; On 1 1 67 113
  W 59600; On 6 6 73 103
  W 59623; Off 6 6 72
  W 59650; Off 1 1 57
  W 60000; On 1 1 65 109
  W 60000; On 6 6 74 99
  W 60007; Off 6 6 69
  W 60017; Off 6 6 73
  W 60033; Off 1 1 67
  W 60400; On 1 1 64 105
  W 60400; On 6 6 76 76
  W 60417; Off 6 6 74
  W 60423; Off 1 1 65
  W 60800; Off 1 1 64
  W 60800; On 1 1 62 61
  W 60800; On 6 6 77 114
  W 60800; On 6 6 69 117
  W 60807; Off 6 6 76
  W 61200; On 1 1 65 101
  W 61233; Off 1 1 62
  W 61400; On 1 1 69 105
  W 61433; Off 1 1 65
  W 61583; Off 6 6 77
  W 61600; On 1 1 74 125
  W 61600; On 6 6 77 101
  W 61633; Off 1 1 69
  W 61940; Off 6 6 69
  W 61940; Off 6 6 77
  W 62000; On 1 1 72 127
  W 62000; On 6 6 77 105
  W 62000; On 6 6 69 112
  W 62033; Off 1 1 74
  W 62323; Off 6 6 77
  W 62390; Off 6 6 69
  W 62400; On 1 1 70 101
  W 62400; On 6 6 74 105
  W 62400; On 6 6 77 101
  W 62440; Off 1 1 72
  W 62757; Off 6 6 74
  W 62800; On 1 1 69 105
  W 62800; On 6 6 74 100
  W 62807; Off 1 1 70
  W 63100; Off 6 6 74
  W 63133; Off 6 6 77
  W 63190; Off 1 1 69
  W 63200; On 1 1 67 101
  W 63200; On 6 6 77 111
  W 63200; On 6 6 74 100
  W 63500; Off 6 6 74
  W 63600; On 1 1 65 69
  W 63600; On 6 6 74 78
  W 63607; Off 1 1 67
  W 63890; Off 6 6 74
  W 63990; Off 1 1 65
  W 64000; On 1 1 64 73
  W 64000; On 6 6 74 99
  W 64000; On 6 6 79 110
  W 64050; Off 6 6 77
  W 64400; On 1 1 65 77
  W 64417; Off 1 1 64
  W 64600; On 1 1 67 85
  W 64623; Off 1 1 65
  W 64800; On 1 1 69 85
  W 64800; On 6 6 73 98
  W 64823; Off 1 1 67
  W 64823; Off 6 6 74
  W 65200; On 1 1 57 69
  W 65223; Off 1 1 69
  W 65573; Off 6 6 79
  W 65600; On 1 1 62 85
  W 65600; On 6 6 74 76
  W 65600; On 6 6 77 101
  W 65617; Off 6 6 73
  W 65633; Off 1 1 57
  W 66000; On 1 1 65 77
  W 66040; Off 1 1 62
  W 66200; On 1 1 64 93
  W 66217; Off 1 1 65
  W 66317; Off 6 6 77
  W 66400; On 1 1 62 121
  W 66400; On 6 6 77 108
  W 66407; Off 1 1 64
  W 66450; Off 6 6 74
  W 66800; On 1 1 64 113
  W 66817; Off 1 1 62
  W 67000; On 1 1 65 121
  W 67023; Off 1 1 64
  W 67200; On 1 1 67 93
  W 67240; Off 1 1 65
  W 67600; On 1 1 65 125
  W 67607; Off 1 1 67
  W 67800; On 1 1 67 85
  W 67807; Off 1 1 65
  W 68000; On 1 1 57 69
  W 68000; On 1 1 55 85
  W 68000; On 6 6 71 110
  W 68017; Off 1 1 57
  W 68023; Off 1 1 67
  W 68240; Off 6 6 77
  W 68400; On 1 1 67 113
  W 68400; On 6 6 77 98
  W 68407; Off 1 1 55
  W 68800; On 1 1 60 101
  W 68800; On 6 6 76 102
  W 68807; Off 1 1 67
  W 68823; Off 6 6 77
  W 69200; On 1 1 64 93
  W 69240; Off 1 1 60
  W 69400; On 1 1 62 77
  W 69417; Off 1 1 64
  W 69590; Off 1 1 62
  W 69600; On 1 1 60 85
  W 69607; Off 6 6 76
  W 69900; Off 6 6 71
  W 70000; On 1 1 62 101
  W 70000; On 6 6 71 104
  W 70033; Off 1 1 60
  W 70190; Off 1 1 62
  W 70200; On 1 1 64 73
  W 70373; Off 6 6 71
  W 70400; On 1 1 65 105
  W 70400; On 6 6 69 73
  W 70400; On 6 6 76 93
  W 70450; Off 1 1 64
  W 70800; On 1 1 60 85
  W 70807; Off 1 1 65
  W 71000; Off 1 1 60
  W 71000; On 1 1 57 113
  W 71200; On 1 1 65 121
  W 71223; Off 1 1 57
  W 71250; Off 6 6 69
  W 71267; Off 1 1 65
  W 71507; Off 6 6 76
  W 71600; On 1 1 65 127
  W 71600; On 6 6 76 89
  W 71673; Off 1 1 65
  W 72000; On 1 1 59 93
  W 72000; On 6 6 74 88
  W 72000; On 6 6 69 95
  W 72017; Off 6 6 76
  W 72400; On 1 1 62 77
  W 72407; Off 1 1 59
  W 72600; On 1 1 60 89
  W 72607; Off 1 1 62
  W 72800; On 1 1 59 81
  W 72817; Off 1 1 60
  W 72840; Off 6 6 74
  W 73117; Off 6 6 69
  W 73200; On 1 1 60 105
  W 73200; On 6 6 69 80
  W 73217; Off 1 1 59
  W 73400; Off 1 1 60
  W 73400; On 1 1 62 105
  W 73600; On 1 1 64 85
  W 73600; On 6 6 68 94
  W 73600; On 6 6 74 73
  W 73623; Off 1 1 62
  W 73633; Off 6 6 69
  W 74000; On 1 1 62 105
  W 74040; Off 1 1 64
  W 74317; Off 6 6 68
  W 74400; On 1 1 60 101
  W 74400; On 6 6 68 89
  W 74450; Off 1 1 62
  W 74723; Off 6 6 74
  W 74800; On 1 1 59 81
  W 74800; On 6 6 74 92
  W 74833; Off 1 1 60
  W 75167; Off 6 6 74
  W 75183; Off 1 1 59
  W 75200; On 1 1 57 109
  W 75200; On 6 6 72 55
  W 75200; On 6 6 69 88
  W 75207; Off 6 6 68
  W 75523; Off 6 6 72
  W 75600; On 1 1 67 127
  W 75600; On 6 6 72 55
  W 75607; Off 1 1 57
  W 75940; Off 6 6 69
  W 75983; Off 6 6 72
  W 76000; On 1 1 66 113
  W 76000; On 6 6 69 85
  W 76000; On 6 6 74 78
  W 76040; Off 1 1 67
  W 76350; Off 6 6 74
  W 76400; On 1 1 65 85
  W 76400; On 6 6 74 64
  W 76423; Off 1 1 66
  W 76733; Off 6 6 74
  W 76800; On 1 1 64 105
  W 76800; On 6 6 68 84
  W 76800; On 6 6 74 81
  W 76817; Off 1 1 65
  W 76817; Off 6 6 69
  W 77190; Off 1 1 64
  W 77200; On 1 1 62 105
  W 77400; On 1 1 64 105
  W 77440; Off 1 1 62
  W 77567; Off 6 6 74
  W 77600; On 1 1 65 109
  W 77600; On 6 6 72 89
  W 77600; On 6 6 69 89
  W 77623; Off 6 6 68
  W 77633; Off 1 1 64
  W 78000; On 1 1 64 85
  W 78017; Off 1 1 65
  W 78200; Off 1 1 64
  W 78200; On 1 1 65 93
  W 78400; On 1 1 62 113
  W 78400; On 6 6 71 96
  W 78407; Off 1 1 65
  W 78417; Off 6 6 72
  W 78800; On 1 1 60 101
  W 78807; Off 1 1 62
  W 78990; Off 1 1 60
  W 79000; On 1 1 62 89
  W 79200; On 1 1 64 101
  W 79200; On 6 6 68 82
  W 79207; Off 6 6 69
  W 79240; Off 1 1 62
  W 79600; On 1 1 62 93
  W 79617; Off 1 1 64
  W 79790; Off 1 1 62
  W 79800; On 1 1 64 85
  W 80000; Off 6 6 71
  W 80000; Off 6 6 68
  W 80000; On 0 0 69 64
  W 80000; On 0 0 64 40
  W 80000; On 1 1 57 105
  W 80000; On 1 1 57 93
  W 80000; On 3 3 33 112
  W 80000; On 3 3 45 88
  W 80000; On 6 6 72 87
  W 80000; On 6 6 69 84
  W 80003; Off 1 1 57
  W 80007; Off 1 1 64
  W 80007; On 4 4 60 48
  W 80007; On 4 4 57 44
  W 80040; On 8 8 57 52
  W 80040; On 8 8 64 44
  W 80050; On 8 8 60 80
  W 80090; Off 3 3 33
  W 80090; Off 3 3 45
  W 80100; Off 1 1 57
  W 80200; On 1 1 60 105
  W 80200; On 1 1 64 93
  W 80200; On 1 1 69 127
  W 80267; Off 1 1 60
  W 80273; Off 1 1 64
  W 80273; Off 1 1 69
  W 80400; On 1 1 60 85
  W 80400; On 1 1 64 93
  W 80400; On 1 1 69 127
  W 80483; Off 1 1 60
  W 80483; Off 1 1 64
  W 80490; Off 1 1 69
  W 80600; On 1 1 60 105
  W 80600; On 1 1 64 105
  W 80600; On 1 1 69 121
  W 80673; Off 1 1 60
  W 80673; Off 1 1 64
  W 80683; Off 1 1 69
  W 80800; On 3 3 33 112
  W 80800; On 3 3 45 108
  W 80857; Off 6 6 69
  W 80873; Off 3 3 33
  W 80883; Off 3 3 45
  W 80900; Off 6 6 72
  W 81000; On 1 1 64 105
  W 81000; On 1 1 69 101
  W 81000; On 1 1 72 127
  W 81067; Off 1 1 64
  W 81073; Off 1 1 69
  W 81073; Off 1 1 72
  W 81200; On 1 1 64 125
  W 81200; On 1 1 72 121
  W 81200; On 1 1 69 125
  W 81267; Off 1 1 64
  W 81273; Off 1 1 69
  W 81283; Off 1 1 72
  W 81400; On 1 1 72 127
  W 81400; On 1 1 69 127
  W 81400; On 1 1 64 127
  W 81467; Off 1 1 64
  W 81473; Off 1 1 69
  W 81483; Off 1 1 72
  W 81600; On 1 1 78 41
  W 81600; On 3 3 33 116
  W 81600; On 3 3 45 112
  W 81640; Off 1 1 78
  W 81673; Off 3 3 45
  W 81683; Off 3 3 33
  W 81800; On 1 1 69 127
  W 81800; On 1 1 72 127
  W 81800; On 1 1 76 127
  W 81873; Off 1 1 69
  W 81873; Off 1 1 72
  W 81883; Off 1 1 76
  W 82000; On 1 1 69 127
  W 82000; On 1 1 76 127
  W 82000; On 1 1 72 127
  W 82067; Off 1 1 69
  W 82067; Off 1 1 72
  W 82083; Off 1 1 76
  W 82200; On 1 1 69 127
  W 82200; On 1 1 76 127
  W 82200; On 1 1 72 127
  W 82267; Off 1 1 69
  W 82273; Off 1 1 72
  W 82290; Off 1 1 76
  W 82400; On 3 3 33 112
  W 82400; On 3 3 45 92
  W 82483; Off 3 3 45
  W 82490; Off 3 3 33
  W 82600; On 1 1 72 127
  W 82600; On 1 1 76 127
  W 82600; On 1 1 81 127
  W 82673; Off 1 1 72
  W 82673; Off 1 1 76
  W 82673; Off 1 1 81
  W 82800; On 1 1 81 127
  W 82800; On 1 1 76 127
  W 82800; On 1 1 72 127
  W 82867; Off 1 1 76
  W 82873; Off 1 1 81
  W 82883; Off 1 1 72
  W 83000; On 1 1 81 127
  W 83000; On 1 1 76 127
  W 83000; On 1 1 72 127
  W 83067; Off 1 1 76
  W 83067; Off 1 1 72
  W 83083; Off 1 1 81
  W 83183; Off 4 4 60
  W 83190; Off 4 4 57
  W 83190; Off 8 8 64
  W 83190; Off 8 8 60
  W 83200; Off 0 0 69
  W 83200; On 0 0 66 76
  W 83200; On 0 0 69 96
  W 83200; On 3 3 51 100
  W 83200; On 3 3 39 124
  W 83200; On 7 7 51 120
  W 83207; Off 8 8 57
  W 83207; On 4 4 60 104
  W 83207; On 4 4 51 96
  W 83207; On 8 8 66 76
  W 83207; On 8 8 60 68
  W 83207; On 8 8 51 108
  W 83283; Off 0 0 64
  W 83400; On 1 1 78 127
  W 83400; On 1 1 84 127
  W 83400; On 2 2 69 127
  W 83440; Off 2 2 69
  W 83467; Off 1 1 84
  W 83483; Off 1 1 78
  W 83600; On 1 1 78 127
  W 83600; On 1 1 84 127
  W 83600; On 2 2 69 127
  W 83650; Off 2 2 69
  W 83650; Off 3 3 51
  W 83657; Off 3 3 39
  W 83673; Off 1 1 84
  W 83683; Off 1 1 78
  W 83800; On 1 1 78 127
  W 83800; On 1 1 84 127
  W 83800; On 2 2 69 127
  W 83857; Off 2 2 69
  W 83883; Off 1 1 78
  W 83883; Off 1 1 84
  W 84000; On 3 3 52 68
  W 84000; On 3 3 39 120
  W 84000; On 3 3 51 124
  W 84083; Off 3 3 52
  W 84200; On 1 1 78 127
  W 84200; On 1 1 81 127
  W 84200; On 2 2 72 125
  W 84267; Off 1 1 81
  W 84273; Off 2 2 72
  W 84283; Off 1 1 78
  W 84400; On 1 1 78 127
  W 84400; On 1 1 81 127
  W 84400; On 2 2 72 113
  W 84467; Off 2 2 72
  W 84473; Off 1 1 78
  W 84473; Off 1 1 81
  W 84567; Off 3 3 39
  W 84583; Off 3 3 51
  W 84600; On 1 1 78 127
  W 84600; On 1 1 81 127
  W 84600; On 2 2 72 127
  W 84673; Off 1 1 81
  W 84673; Off 2 2 72
  W 84683; Off 1 1 78
  W 84800; On 3 3 39 120
  W 84800; On 3 3 51 124
  W 84800; On 6 6 66 120
  W 84800; On 6 6 69 120
  W 84800; On 7 7 60 120
  W 85000; On 1 1 72 127
  W 85000; On 1 1 78 127
  W 85000; On 2 2 69 127
  W 85050; Off 2 2 69
  W 85083; Off 1 1 72
  W 85083; Off 1 1 78
  W 85200; On 1 1 72 113
  W 85200; On 1 1 78 127
  W 85200; On 2 2 69 105
  W 85267; Off 2 2 69
  W 85273; Off 1 1 78
  W 85283; Off 1 1 72
  W 85390; Off 3 3 39
  W 85390; Off 3 3 51
  W 85400; On 1 1 72 127
  W 85400; On 1 1 78 127
  W 85400; On 2 2 69 127
  W 85467; Off 2 2 69
  W 85483; Off 1 1 72
  W 85483; Off 1 1 78
  W 85483; Off 7 7 51
  W 85500; Off 6 6 69
  W 85507; Off 7 7 60
  W 85573; Off 6 6 66
  W 85600; On 3 3 39 92
  W 85600; On 3 3 51 116
  W 85600; On 6 6 69 120
  W 85600; On 6 6 66 120
  W 85600; On 7 7 60 120
  W 85600; On 7 7 51 120
  W 85800; On 1 1 69 127
  W 85800; On 1 1 72 127
  W 85800; On 2 2 66 127
  W 85867; Off 2 2 66
  W 85883; Off 1 1 69
  W 85883; Off 1 1 72
  W 86000; On 1 1 69 127
  W 86000; On 1 1 72 121
  W 86000; On 2 2 66 127
  W 86057; Off 2 2 66
  W 86083; Off 1 1 69
  W 86083; Off 1 1 72
  W 86150; Off 3 3 39
  W 86157; Off 3 3 51
  W 86200; On 1 1 69 127
  W 86200; On 1 1 72 127
  W 86200; On 2 2 66 127
  W 86257; Off 2 2 66
  W 86273; Off 1 1 72
  W 86290; Off 1 1 69
  W 86290; Off 4 4 51
  W 86290; Off 8 8 51
  W 86307; Off 7 7 51
  W 86373; Off 6 6 69
  W 86383; Off 6 6 66
  W 86400; On 0 0 70 108
  W 86400; On 0 0 67 96
  W 86400; On 3 3 39 116
  W 86400; On 3 3 51 116
  W 86400; On 6 6 67 120
  W 86400; On 6 6 70 120
  W 86400; On 7 7 61 120
  W 86400; On 7 7 51 120
  W 86407; Off 7 7 60
  W 86407; On 4 4 51 76
  W 86407; On 4 4 61 68
  W 86407; On 8 8 67 60
  W 86407; On 8 8 51 108
  W 86407; On 8 8 58 96
  W 86417; Off 0 0 69
  W 86433; Off 0 0 66
  W 86433; Off 8 8 60
  W 86440; Off 8 8 66
  W 86490; Off 4 4 60
  W 86600; On 1 1 67 127
  W 86600; On 1 1 72 127
  W 86600; On 1 1 73 127
  W 86600; On 2 2 63 127
  W 86623; Off 1 1 72
  W 86657; Off 2 2 63
  W 86667; Off 1 1 73
  W 86683; Off 1 1 67
  W 86800; On 1 1 67 127
  W 86800; On 1 1 73 127
  W 86800; On 2 2 63 127
  W 86857; Off 2 2 63
  W 86867; Off 1 1 67
  W 86867; Off 1 1 73
  W 86973; Off 3 3 51
  W 86990; Off 3 3 39
  W 87000; On 1 1 67 127
  W 87000; On 1 1 74 127
  W 87000; On 1 1 73 127
  W 87000; On 2 2 63 127
  W 87067; Off 1 1 74
  W 87067; Off 1 1 73
  W 87067; Off 2 2 63
  W 87073; Off 1 1 67
  W 87073; Off 7 7 51
  W 87100; Off 6 6 70
  W 87117; Off 6 6 67
  W 87157; Off 7 7 61
  W 87200; On 3 3 39 120
  W 87200; On 3 3 51 104
  W 87200; On 6 6 67 120
  W 87200; On 6 6 70 120
  W 87200; On 7 7 51 120
  W 87200; On 7 7 61 120
  W 87400; On 1 1 67 127
  W 87400; On 1 1 70 127
  W 87400; On 2 2 61 127
  W 87457; Off 2 2 61
  W 87467; Off 1 1 67
  W 87483; Off 1 1 70
  W 87600; On 1 1 67 117
  W 87600; On 1 1 70 127
  W 87600; On 2 2 61 121
  W 87667; Off 1 1 67
  W 87667; Off 2 2 61
  W 87683; Off 1 1 70
  W 87767; Off 3 3 51
  W 87773; Off 3 3 39
  W 87800; On 1 1 67 127
  W 87800; On 1 1 70 127
  W 87800; On 2 2 61 127
  W 87857; Off 2 2 61
  W 87857; Off 7 7 61
  W 87867; Off 1 1 67
  W 87883; Off 1 1 70
  W 87890; Off 7 7 51
  W 87900; Off 6 6 70
  W 87917; Off 6 6 67
  W 88000; On 3 3 39 108
  W 88000; On 3 3 51 104
  W 88000; On 6 6 70 120
  W 88000; On 6 6 67 120
  W 88000; On 7 7 51 120
  W 88000; On 7 7 61 120
  W 88200; On 1 1 61 127
  W 88200; On 1 1 67 127
  W 88200; On 2 2 58 127
  W 88250; Off 2 2 58
  W 88267; Off 1 1 61
  W 88273; Off 1 1 67
  W 88400; On 1 1 61 127
  W 88400; On 1 1 67 127
  W 88400; On 2 2 58 127
  W 88467; Off 2 2 58
  W 88473; Off 1 1 61
  W 88473; Off 1 1 67
  W 88583; Off 3 3 39
  W 88590; Off 3 3 51
  W 88600; On 1 1 61 127
  W 88600; On 1 1 67 127
  W 88600; On 2 2 58 127
  W 88667; Off 2 2 58
  W 88673; Off 1 1 61
  W 88673; Off 6 6 67
  W 88683; Off 1 1 67
  W 88683; Off 6 6 70
  W 88707; Off 7 7 51
  W 88723; Off 7 7 61
  W 88800; On 3 3 39 100
  W 88800; On 3 3 51 112
  W 88800; On 6 6 67 120
  W 88800; On 6 6 70 120
  W 88800; On 7 7 61 120
  W 88800; On 7 7 51 120
  W 89000; On 1 1 58 127
  W 89000; On 1 1 61 127
  W 89000; On 2 2 55 127
  W 89067; Off 2 2 55
  W 89073; Off 1 1 58
  W 89090; Off 1 1 61
  W 89200; On 1 1 58 121
  W 89200; On 1 1 61 127
  W 89200; On 2 2 55 127
  W 89257; Off 2 2 55
  W 89267; Off 1 1 58
  W 89290; Off 1 1 61
  W 89383; Off 3 3 39
  W 89390; Off 3 3 51
  W 89400; On 1 1 58 127
  W 89400; On 1 1 61 127
  W 89400; On 2 2 55 127
  W 89440; Off 4 4 51
  W 89457; Off 2 2 55
  W 89457; Off 7 7 51
  W 89467; Off 1 1 58
  W 89473; Off 0 0 70
  W 89483; Off 0 0 67
  W 89490; Off 1 1 61
  W 89500; Off 8 8 51
  W 89550; Off 4 4 61
  W 89567; Off 6 6 70
  W 89590; Off 7 7 61
  W 89590; Off 8 8 58
  W 89600; On 0 0 70 84
  W 89600; On 0 0 63 80
  W 89600; On 3 3 39 92
  W 89600; On 3 3 51 108
  W 89600; On 6 6 63 120
  W 89600; On 6 6 70 120
  W 89600; On 7 7 51 120
  W 89600; On 7 7 59 120
  W 89607; On 4 4 51 100
  W 89607; On 4 4 59 104
  W 89607; On 8 8 59 100
  W 89607; On 8 8 51 76
  W 89640; Off 6 6 67
  W 89800; On 1 1 58 113
  W 89800; On 1 1 59 127
  W 89800; On 2 2 51 125
  W 89857; Off 2 2 51
  W 89873; Off 1 1 58
  W 89873; Off 1 1 59
  W 90000; On 1 1 58 127
  W 90000; On 1 1 59 127
  W 90000; On 2 2 51 117
  W 90007; On 8 8 68 68
  W 90023; Off 8 8 67
  W 90057; Off 2 2 51
  W 90067; Off 1 1 58
  W 90083; Off 1 1 59
  W 90190; Off 3 3 39
  W 90200; Off 3 3 51
  W 90200; On 1 1 58 127
  W 90200; On 1 1 59 127
  W 90200; On 2 2 51 127
  W 90257; Off 2 2 51
  W 90267; Off 1 1 58
  W 90283; Off 1 1 59
  W 90400; Off 6 6 70
  W 90400; On 0 0 68 100
  W 90400; On 3 3 39 88
  W 90400; On 3 3 51 80
  W 90400; On 6 6 68 120
  W 90417; Off 0 0 70
  W 90600; On 1 1 56 127
  W 90600; On 1 1 59 127
  W 90600; On 2 2 51 127
  W 90650; Off 2 2 51
  W 90683; Off 1 1 56
  W 90683; Off 1 1 59
  W 90800; On 1 1 56 127
  W 90800; On 1 1 59 127
  W 90800; On 2 2 51 127
  W 90867; Off 2 2 51
  W 90873; Off 1 1 56
  W 90883; Off 1 1 59
  W 90940; Off 3 3 39
  W 90967; Off 3 3 51
  W 91000; On 1 1 56 127
  W 91000; On 1 1 59 127
  W 91000; On 2 2 51 127
  W 91050; Off 2 2 51
  W 91057; Off 0 0 63
  W 91057; Off 1 1 56
  W 91073; Off 1 1 59
  W 91173; Off 8 8 59
  W 91200; On 0 0 61 92
  W 91200; On 3 3 39 108
  W 91200; On 3 3 51 80
  W 91200; On 7 7 58 120
  W 91207; On 4 4 58 92
  W 91207; On 8 8 58 100
  W 91223; Off 4 4 59
  W 91240; Off 7 7 59
  W 91400; On 1 1 56 125
  W 91400; On 1 1 58 127
  W 91400; On 2 2 51 113
  W 91457; Off 1 1 56
  W 91457; Off 2 2 51
  W 91473; Off 1 1 58
  W 91600; On 1 1 56 105
  W 91600; On 1 1 58 127
  W 91600; On 2 2 51 121
  W 91667; Off 1 1 56
  W 91667; Off 2 2 51
  W 91673; Off 1 1 58
  W 91757; Off 3 3 39
  W 91800; On 1 1 56 127
  W 91800; On 1 1 58 127
  W 91800; On 2 2 51 127
  W 91867; Off 2 2 51
  W 91873; Off 1 1 56
  W 91873; Off 1 1 58
  W 91873; Off 3 3 51
  W 91950; Off 0 0 68
  W 92000; On 0 0 67 84
  W 92000; On 3 3 51 108
  W 92000; On 3 3 38 80
  W 92000; On 3 3 39 84
  W 92000; On 6 6 67 120
  W 92007; Off 6 6 68
  W 92007; On 8 8 67 80
  W 92033; Off 8 8 68
  W 92067; Off 3 3 39
  W 92073; Off 3 3 38
  W 92200; On 1 1 55 121
  W 92200; On 1 1 58 127
  W 92200; On 2 2 51 117
  W 92257; Off 2 2 51
  W 92273; Off 1 1 58
  W 92283; Off 1 1 55
  W 92400; On 1 1 55 89
  W 92400; On 1 1 58 127
  W 92400; On 2 2 51 117
  W 92400; On 3 3 39 32
  W 92457; Off 2 2 51
  W 92473; Off 1 1 55
  W 92473; Off 1 1 58
  W 92600; On 1 1 55 89
  W 92600; On 1 1 58 127
  W 92600; On 2 2 51 101
  W 92650; Off 1 1 55
  W 92657; Off 2 2 51
  W 92673; Off 0 0 61
  W 92683; Off 1 1 58
  W 92717; Off 6 6 63
  W 92767; Off 8 8 51
  W 92800; Off 3 3 51
  W 92800; On 0 0 63 92
  W 92800; On 0 0 68 72
  W 92800; On 1 1 56 127
  W 92800; On 1 1 56 127
  W 92800; On 2 2 51 125
  W 92800; On 3 3 44 112
  W 92800; On 3 3 32 108
  W 92800; On 6 6 68 120
  W 92800; On 6 6 63 120
  W 92800; On 7 7 56 120
  W 92800; On 7 7 44 120
  W 92803; Off 1 1 56
  W 92807; Off 3 3 39
  W 92807; On 4 4 56 108
  W 92807; On 4 4 59 104
  W 92807; On 8 8 68 56
  W 92807; On 8 8 44 88
  W 92807; On 8 8 56 108
  W 92817; Off 4 4 51
  W 92823; Off 6 6 67
  W 92823; Off 7 7 51
  W 92823; Off 8 8 67
  W 92833; Off 4 4 58
  W 92840; Off 7 7 58
  W 92883; Off 1 1 56
  W 92900; Off 0 0 67
  W 92923; Off 8 8 58
  W 92983; Off 2 2 51
  W 93000; On 1 1 63 125
  W 93000; On 1 1 68 127
  W 93000; On 2 2 59 73
  W 93057; Off 2 2 59
  W 93073; Off 1 1 63
  W 93083; Off 1 1 68
  W 93200; On 1 1 63 81
  W 93200; On 1 1 68 125
  W 93200; On 2 2 59 127
  W 93257; Off 2 2 59
  W 93283; Off 1 1 63
  W 93290; Off 1 1 68
  W 93390; Off 3 3 44
  W 93400; On 1 1 63 113
  W 93400; On 1 1 68 125
  W 93400; On 2 2 59 127
  W 93457; Off 2 2 59
  W 93483; Off 1 1 63
  W 93483; Off 1 1 68
  W 93490; Off 3 3 32
  W 93590; Off 6 6 63
  W 93600; On 3 3 44 108
  W 93600; On 3 3 56 92
  W 93617; Off 6 6 68
  W 93617; Off 7 7 56
  W 93673; Off 7 7 44
  W 93800; On 1 1 68 121
  W 93800; On 1 1 71 127
  W 93800; On 2 2 63 41
  W 93800; On 2 2 64 105
  W 93833; Off 2 2 64
  W 93840; Off 2 2 63
  W 93873; Off 1 1 71
  W 93883; Off 1 1 68
  W 94000; On 1 1 68 127
  W 94000; On 1 1 71 125
  W 94000; On 2 2 63 127
  W 94057; Off 2 2 63
  W 94083; Off 1 1 68
  W 94083; Off 1 1 71
  W 94183; Off 3 3 56
  W 94200; Off 3 3 44
  W 94200; On 1 1 68 127
  W 94200; On 1 1 71 127
  W 94200; On 2 2 63 127
  W 94267; Off 2 2 63
  W 94283; Off 1 1 68
  W 94290; Off 1 1 71
  W 94400; On 3 3 44 84
  W 94400; On 3 3 56 100
  W 94600; On 1 1 71 127
  W 94600; On 1 1 75 113
  W 94600; On 2 2 68 127
  W 94657; Off 2 2 68
  W 94673; Off 1 1 71
  W 94700; Off 1 1 75
  W 94800; On 1 1 71 127
  W 94800; On 1 1 75 127
  W 94800; On 2 2 68 127
  W 94857; Off 2 2 68
  W 94883; Off 1 1 71
  W 94900; Off 1 1 75
  W 95000; On 1 1 71 127
  W 95000; On 1 1 75 127
  W 95000; On 2 2 68 127
  W 95050; Off 2 2 68
  W 95067; Off 3 3 44
  W 95083; Off 1 1 71
  W 95090; Off 1 1 75
  W 95090; Off 3 3 56
  W 95200; On 3 3 44 112
  W 95200; On 3 3 56 108
  W 95400; On 1 1 75 127
  W 95400; On 1 1 80 127
  W 95400; On 2 2 71 127
  W 95457; Off 2 2 71
  W 95490; Off 1 1 75
  W 95490; Off 1 1 80
  W 95600; On 1 1 75 109
  W 95600; On 1 1 80 127
  W 95600; On 2 2 71 127
  W 95657; Off 2 2 71
  W 95690; Off 1 1 75
  W 95690; Off 1 1 80
  W 95690; Off 3 3 56
  W 95800; On 1 1 75 127
  W 95800; On 1 1 80 127
  W 95800; On 2 2 71 127
  W 95817; Off 3 3 44
  W 95833; Off 0 0 68
  W 95840; Off 4 4 59
  W 95857; Off 2 2 71
  W 95883; Off 1 1 80
  W 95890; Off 1 1 75
  W 95990; Off 8 8 56
  W 96000; On 0 0 65 84
  W 96000; On 0 0 68 108
  W 96000; On 3 3 50 124
  W 96000; On 3 3 38 112
  W 96000; On 7 7 50 120
  W 96007; Off 0 0 63
  W 96007; On 4 4 59 108
  W 96007; On 4 4 50 104
  W 96007; On 8 8 65 76
  W 96007; On 8 8 59 80
  W 96007; On 8 8 50 108
  W 96017; Off 8 8 68
  W 96023; Off 4 4 56
  W 96033; Off 8 8 44
  W 96200; On 1 1 77 127
  W 96200; On 1 1 83 127
  W 96200; On 2 2 68 127
  W 96267; Off 2 2 68
  W 96273; Off 1 1 77
  W 96273; Off 1 1 83
  W 96400; On 1 1 77 127
  W 96400; On 1 1 83 127
  W 96400; On 2 2 68 127
  W 96457; Off 1 1 83
  W 96457; Off 2 2 68
  W 96467; Off 1 1 77
  W 96600; On 1 1 77 127
  W 96600; On 1 1 83 127
  W 96600; On 2 2 68 127
  W 96633; Off 3 3 50
  W 96633; Off 3 3 38
  W 96667; Off 1 1 83
  W 96673; Off 2 2 68
  W 96683; Off 1 1 77
  W 96800; On 3 3 50 124
  W 96800; On 3 3 38 112
  W 97000; On 1 1 77 125
  W 97000; On 1 1 80 97
  W 97000; On 2 2 71 127
  W 97067; Off 2 2 71
  W 97073; Off 1 1 80
  W 97083; Off 1 1 77
  W 97200; On 1 1 77 125
  W 97200; On 1 1 80 113
  W 97200; On 2 2 71 127
  W 97267; Off 2 2 71
  W 97273; Off 1 1 77
  W 97283; Off 1 1 80
  W 97400; On 1 1 77 127
  W 97400; On 1 1 80 117
  W 97400; On 2 2 71 127
  W 97423; Off 3 3 38
  W 97433; Off 3 3 50
  W 97457; Off 2 2 71
  W 97483; Off 1 1 77
  W 97500; Off 1 1 80
  W 97600; On 3 3 50 112
  W 97600; On 3 3 38 124
  W 97600; On 6 6 68 120
  W 97600; On 6 6 65 120
  W 97600; On 7 7 59 120
  W 97800; On 1 1 71 121
  W 97800; On 1 1 77 127
  W 97800; On 2 2 68 127
  W 97857; Off 2 2 68
  W 97883; Off 1 1 71
  W 97890; Off 1 1 77
  W 98000; On 1 1 71 125
  W 98000; On 1 1 77 125
  W 98000; On 2 2 68 127
  W 98057; Off 2 2 68
  W 98100; Off 1 1 71
  W 98100; Off 1 1 77
  W 98200; On 1 1 71 113
  W 98200; On 1 1 77 109
  W 98200; On 2 2 68 127
  W 98223; Off 3 3 50
  W 98223; Off 3 3 38
  W 98267; Off 2 2 68
  W 98273; Off 6 6 65
  W 98290; Off 1 1 71
  W 98307; Off 1 1 77
  W 98307; Off 7 7 59
  W 98317; Off 7 7 50
  W 98340; Off 6 6 68
  W 98400; On 3 3 38 104
  W 98400; On 3 3 50 96
  W 98400; On 6 6 68 120
  W 98400; On 6 6 65 120
  W 98400; On 7 7 59 120
  W 98400; On 7 7 50 120
  W 98600; On 1 1 68 127
  W 98600; On 1 1 71 127
  W 98600; On 2 2 65 127
  W 98673; Off 1 1 71
  W 98673; Off 2 2 65
  W 98690; Off 1 1 68
  W 98800; On 1 1 68 109
  W 98800; On 1 1 71 127
  W 98800; On 2 2 65 127
  W 98867; Off 2 2 65
  W 98873; Off 1 1 71
  W 98883; Off 1 1 68
  W 98917; Off 3 3 38
  W 98923; Off 3 3 50
  W 99000; On 1 1 68 127
  W 99000; On 1 1 71 127
  W 99000; On 2 2 65 127
  W 99050; Off 4 4 50
  W 99073; Off 1 1 71
  W 99073; Off 2 2 65
  W 99083; Off 1 1 68
  W 99100; Off 8 8 50
  W 99123; Off 7 7 50
  W 99157; Off 6 6 65
  W 99183; Off 0 0 68
  W 99190; Off 6 6 68
  W 99200; On 0 0 69 108
  W 99200; On 0 0 66 92
  W 99200; On 3 3 38 112
  W 99200; On 3 3 50 108
  W 99200; On 6 6 66 120
  W 99200; On 6 6 69 120
  W 99200; On 7 7 60 120
  W 99200; On 7 7 50 120
  W 99207; On 4 4 50 96
  W 99207; On 4 4 60 104
  W 99207; On 8 8 66 52
  W 99207; On 8 8 60 100
  W 99207; On 8 8 50 64
  W 99217; Off 8 8 59
  W 99223; Off 0 0 65
  W 99240; Off 4 4 59
  W 99250; Off 8 8 65
  W 99273; Off 7 7 59
  W 99400; On 1 1 69 127
  W 99400; On 1 1 72 127
  W 99400; On 2 2 66 125
  W 99450; Off 2 2 66
  W 99483; Off 1 1 72
  W 99490; Off 1 1 69
  W 99600; On 1 1 69 121
  W 99600; On 1 1 72 109
  W 99600; On 2 2 66 121
  W 99667; Off 2 2 66
  W 99673; Off 3 3 38
  W 99683; Off 1 1 72
  W 99690; Off 1 1 69
  W 99700; Off 3 3 50
  W 99800; On 1 1 69 121
  W 99800; On 1 1 72 127
  W 99800; On 2 2 66 121
  W 99867; Off 1 1 69
  W 99873; Off 2 2 66
  W 99883; Off 1 1 72
  W 99890; Off 7 7 50
  W 99917; Off 7 7 60
  W 99940; Off 6 6 66
  W 99940; Off 6 6 69
  W 100000; On 3 3 38 104
  W 100000; On 3 3 50 76
  W 100000; On 6 6 66 120
  W 100000; On 6 6 69 120
  W 100000; On 7 7 60 120
  W 100000; On 7 7 50 120
  W 100200; On 1 1 66 127
  W 100200; On 1 1 69 127
  W 100200; On 2 2 60 127
  W 100273; Off 1 1 66
  W 100273; Off 1 1 69
  W 100273; Off 2 2 60
  W 100400; On 1 1 66 125
  W 100400; On 1 1 69 127
  W 100400; On 2 2 60 127
  W 100467; Off 2 2 60
  W 100473; Off 1 1 66
  W 100473; Off 1 1 69
  W 100507; Off 3 3 38
  W 100523; Off 3 3 50
  W 100600; On 1 1 66 125
  W 100600; On 1 1 69 127
  W 100600; On 2 2 60 127
  W 100667; Off 2 2 60
  W 100673; Off 1 1 69
  W 100683; Off 1 1 66
  W 100690; Off 6 6 66
  W 100690; Off 7 7 50
  W 100700; Off 6 6 69
  W 100700; Off 7 7 60
  W 100800; On 3 3 38 112
  W 100800; On 3 3 50 96
  W 100800; On 6 6 69 120
  W 100800; On 6 6 66 120
  W 100800; On 7 7 60 120
  W 100800; On 7 7 50 120
  W 101000; On 1 1 60 127
  W 101000; On 1 1 66 127
  W 101000; On 2 2 57 127
  W 101073; Off 2 2 57
  W 101083; Off 1 1 60
  W 101090; Off 1 1 66
  W 101200; On 1 1 60 127
  W 101200; On 1 1 66 121
  W 101200; On 2 2 57 121
  W 101273; Off 2 2 57
  W 101290; Off 1 1 60
  W 101290; Off 1 1 66
  W 101367; Off 3 3 38
  W 101390; Off 3 3 50
  W 101400; On 1 1 66 127
  W 101400; On 1 1 60 127
  W 101400; On 2 2 57 127
  W 101467; Off 2 2 57
  W 101490; Off 1 1 66
  W 101500; Off 1 1 60
  W 101517; Off 6 6 69
  W 101517; Off 7 7 50
  W 101523; Off 6 6 66
  W 101540; Off 7 7 60
  W 101600; On 3 3 38 124
  W 101600; On 3 3 50 100
  W 101600; On 6 6 66 120
  W 101600; On 6 6 69 120
  W 101600; On 7 7 50 120
  W 101600; On 7 7 60 120
  W 101800; On 1 1 57 127
  W 101800; On 1 1 60 121
  W 101800; On 2 2 54 127
  W 101873; Off 2 2 54
  W 101883; Off 1 1 60
  W 101890; Off 1 1 57
  W 102000; On 1 1 57 127
  W 102000; On 1 1 60 127
  W 102000; On 2 2 54 127
  W 102057; Off 2 2 54
  W 102083; Off 1 1 60
  W 102090; Off 1 1 57
  W 102200; Off 3 3 38
  W 102200; On 1 1 57 127
  W 102200; On 1 1 60 127
  W 102200; On 2 2 54 127
  W 102217; Off 7 7 50
  W 102223; Off 3 3 50
  W 102257; Off 2 2 54
  W 102283; Off 0 0 69
  W 102283; Off 1 1 57
  W 102283; Off 1 1 60
  W 102283; Off 8 8 50
  W 102323; Off 0 0 66
  W 102323; Off 4 4 50
  W 102323; Off 6 6 69
  W 102333; Off 4 4 60
  W 102357; Off 7 7 60
  W 102400; Off 6 6 66
  W 102400; On 0 0 69 100
  W 102400; On 0 0 62 76
  W 102400; On 3 3 38 120
  W 102400; On 3 3 50 96
  W 102400; On 6 6 62 120
  W 102400; On 6 6 69 120
  W 102400; On 7 7 58 120
  W 102400; On 7 7 50 120
  W 102407; On 4 4 50 88
  W 102407; On 4 4 58 92
  W 102407; On 8 8 58 92
  W 102407; On 8 8 50 80
  W 102433; Off 8 8 60
  W 102600; On 1 1 57 125
  W 102600; On 1 1 58 127
  W 102600; On 2 2 50 127
  W 102667; Off 2 2 50
  W 102683; Off 1 1 57
  W 102683; Off 1 1 58
  W 102800; On 1 1 57 121
  W 102800; On 1 1 58 127
  W 102800; On 2 2 50 127
  W 102807; On 8 8 67 88
  W 102817; Off 8 8 66
  W 102857; Off 2 2 50
  W 102883; Off 1 1 57
  W 102883; Off 1 1 58
  W 102973; Off 3 3 38
  W 103000; Off 3 3 50
  W 103000; On 1 1 57 127
  W 103000; On 1 1 58 127
  W 103000; On 2 2 50 127
  W 103067; Off 2 2 50
  W 103083; Off 1 1 57
  W 103083; Off 1 1 58
  W 103200; Off 6 6 69
  W 103200; On 0 0 67 92
  W 103200; On 3 3 38 96
  W 103200; On 3 3 50 112
  W 103200; On 6 6 67 120
  W 103233; Off 0 0 69
  W 103400; On 1 1 55 127
  W 103400; On 1 1 58 127
  W 103400; On 2 2 50 127
  W 103457; Off 2 2 50
  W 103473; Off 1 1 55
  W 103473; Off 1 1 58
  W 103600; On 1 1 55 127
  W 103600; On 1 1 58 127
  W 103600; On 2 2 50 127
  W 103657; Off 2 2 50
  W 103673; Off 1 1 55
  W 103683; Off 1 1 58
  W 103790; Off 3 3 38
  W 103800; On 1 1 53 127
  W 103800; On 1 1 55 125
  W 103800; On 1 1 58 127
  W 103800; On 2 2 50 127
  W 103807; Off 3 3 50
  W 103850; Off 1 1 53
  W 103857; Off 2 2 50
  W 103867; Off 1 1 55
  W 103883; Off 1 1 58
  W 103967; Off 4 4 58
  W 103983; Off 8 8 58
  W 104000; On 3 3 38 124
  W 104000; On 3 3 50 112
  W 104000; On 7 7 57 120
  W 104007; On 4 4 57 92
  W 104007; On 8 8 57 84
  W 104090; Off 7 7 58
  W 104200; On 1 1 62 127
  W 104200; On 1 1 60 117
  W 104200; On 2 2 57 127
  W 104257; Off 2 2 57
  W 104273; Off 1 1 62
  W 104273; Off 1 1 60
  W 104400; On 1 1 62 127
  W 104400; On 1 1 60 127
  W 104400; On 2 2 57 127
  W 104467; Off 1 1 60
  W 104467; Off 2 2 57
  W 104483; Off 1 1 62
  W 104600; On 1 1 62 127
  W 104600; On 1 1 60 127
  W 104600; On 2 2 57 127
  W 104607; Off 3 3 38
  W 104633; Off 3 3 50
  W 104657; Off 2 2 57
  W 104667; Off 1 1 60
  W 104673; Off 1 1 62
  W 104800; On 0 0 66 104
  W 104800; On 3 3 37 76
  W 104800; On 3 3 38 124
  W 104800; On 3 3 50 120
  W 104800; On 6 6 66 120
  W 104807; Off 8 8 67
  W 104807; On 8 8 66 72
  W 104823; Off 0 0 67
  W 104823; Off 6 6 67
  W 104833; Off 3 3 37
  W 105000; On 1 1 60 127
  W 105000; On 1 1 66 127
  W 105000; On 2 2 57 127
  W 105050; Off 2 2 57
  W 105067; Off 1 1 60
  W 105073; Off 1 1 66
  W 105200; On 1 1 60 127
  W 105200; On 1 1 66 127
  W 105200; On 2 2 57 127
  W 105233; Off 3 3 50
  W 105250; Off 2 2 57
  W 105273; Off 1 1 60
  W 105273; Off 1 1 66
  W 105390; Off 3 3 38
  W 105400; On 1 1 60 127
  W 105400; On 1 1 66 127
  W 105400; On 2 2 57 127
  W 105450; Off 2 2 57
  W 105473; Off 1 1 60
  W 105490; Off 1 1 66
  W 105500; Off 0 0 62
  W 105583; Off 6 6 62
  W 105583; Off 7 7 50
  W 105583; Off 8 8 50
  W 105590; Off 7 7 57
  W 105600; Off 4 4 50
  W 105600; On 0 0 62 80
  W 105600; On 0 0 67 84
  W 105600; On 3 3 31 124
  W 105600; On 3 3 43 124
  W 105600; On 6 6 67 120
  W 105600; On 6 6 62 120
  W 105600; On 7 7 55 120
  W 105600; On 7 7 43 120
  W 105607; On 4 4 58 88
  W 105607; On 4 4 55 108
  W 105607; On 8 8 55 92
  W 105607; On 8 8 43 100
  W 105607; On 8 8 67 68
  W 105617; Off 8 8 57
  W 105617; Off 8 8 66
  W 105640; Off 0 0 66
  W 105640; Off 6 6 66
  W 105667; Off 4 4 57
  W 105800; On 1 1 58 127
  W 105800; On 1 1 67 127
  W 105800; On 2 2 55 127
  W 105867; Off 1 1 58
  W 105867; Off 1 1 67
  W 105873; Off 2 2 55
  W 106000; On 1 1 58 127
  W 106000; On 1 1 67 127
  W 106000; On 2 2 55 101
  W 106067; Off 1 1 67
  W 106067; Off 2 2 55
  W 106073; Off 1 1 58
  W 106183; Off 6 6 67
  W 106200; On 1 1 58 127
  W 106200; On 1 1 67 127
  W 106200; On 2 2 55 127
  W 106267; Off 1 1 67
  W 106273; Off 1 1 58
  W 106273; Off 2 2 55
  W 106307; Off 3 3 43
  W 106367; Off 3 3 31
  W 106400; On 3 3 43 124
  W 106400; On 3 3 55 108
  W 106450; Off 6 6 62
  W 106500; Off 7 7 55
  W 106600; On 1 1 67 127
  W 106600; On 1 1 70 127
  W 106600; On 2 2 62 127
  W 106617; Off 7 7 43
  W 106673; Off 1 1 67
  W 106673; Off 1 1 70
  W 106673; Off 2 2 62
  W 106800; On 1 1 67 127
  W 106800; On 1 1 70 127
  W 106800; On 2 2 62 121
  W 106867; Off 1 1 70
  W 106867; Off 2 2 62
  W 106873; Off 1 1 67
  W 106983; Off 3 3 43
  W 107000; On 1 1 67 127
  W 107000; On 1 1 70 127
  W 107000; On 2 2 62 125
  W 107007; Off 3 3 55
  W 107067; Off 2 2 62
  W 107073; Off 1 1 70
  W 107083; Off 1 1 67
  W 107200; On 3 3 42 52
  W 107200; On 3 3 43 120
  W 107200; On 3 3 55 108
  W 107217; Off 3 3 42
  W 107400; On 1 1 70 127
  W 107400; On 1 1 74 127
  W 107400; On 2 2 67 109
  W 107457; Off 2 2 67
  W 107467; Off 1 1 74
  W 107483; Off 1 1 70
  W 107600; On 1 1 70 127
  W 107600; On 1 1 74 127
  W 107600; On 2 2 67 127
  W 107667; Off 2 2 67
  W 107673; Off 1 1 74
  W 107683; Off 1 1 70
  W 107800; On 1 1 70 127
  W 107800; On 1 1 74 127
  W 107800; On 2 2 67 127
  W 107840; Off 3 3 43
  W 107850; Off 3 3 55
  W 107873; Off 2 2 67
  W 107883; Off 1 1 70
  W 107883; Off 1 1 74
  W 108000; On 3 3 55 124
  W 108000; On 3 3 43 124
  W 108200; On 1 1 74 127
  W 108200; On 1 1 79 127
  W 108200; On 2 2 70 127
  W 108257; Off 2 2 70
  W 108267; Off 1 1 74
  W 108273; Off 1 1 79
  W 108400; On 1 1 74 127
  W 108400; On 1 1 79 127
  W 108400; On 2 2 70 127
  W 108450; Off 2 2 70
  W 108467; Off 1 1 74
  W 108483; Off 1 1 79
  W 108600; On 1 1 74 127
  W 108600; On 1 1 79 127
  W 108600; On 2 2 70 127
  W 108633; Off 3 3 55
  W 108633; Off 3 3 43
  W 108650; Off 2 2 70
  W 108667; Off 1 1 74
  W 108673; Off 1 1 79
  W 108800; Off 0 0 67
  W 108800; On 0 0 64 100
  W 108800; On 0 0 67 108
  W 108800; On 3 3 49 80
  W 108800; On 3 3 37 92
  W 108800; On 7 7 49 120
  W 108807; Off 4 4 58
  W 108807; Off 8 8 43
  W 108807; On 4 4 58 108
  W 108807; On 4 4 49 104
  W 108807; On 8 8 64 116
  W 108807; On 8 8 58 120
  W 108807; On 8 8 49 124
  W 108840; Off 4 4 55
  W 108840; Off 8 8 55
  W 108857; Off 8 8 67
  W 108883; Off 0 0 62
  W 109000; On 1 1 79 127
  W 109000; On 1 1 82 127
  W 109000; On 2 2 64 127
  W 109057; Off 2 2 64
  W 109073; Off 1 1 79
  W 109083; Off 1 1 82
  W 109200; On 1 1 79 127
  W 109200; On 1 1 82 127
  W 109200; On 2 2 64 121
  W 109240; Off 3 3 49
  W 109257; Off 3 3 37
  W 109273; Off 2 2 64
  W 109283; Off 1 1 79
  W 109283; Off 1 1 82
  W 109400; On 1 1 79 127
  W 109400; On 1 1 82 127
  W 109400; On 2 2 64 127
  W 109473; Off 2 2 64
  W 109483; Off 1 1 79
  W 109483; Off 1 1 82
  W 109600; On 3 3 37 116
  W 109600; On 3 3 49 108
  W 109800; On 1 1 79 127
  W 109800; On 1 1 76 117
  W 109800; On 2 2 70 127
  W 109867; Off 2 2 70
  W 109883; Off 1 1 79
  W 109890; Off 1 1 76
  W 110000; On 1 1 79 127
  W 110000; On 1 1 76 127
  W 110000; On 2 2 70 127
  W 110067; Off 2 2 70
  W 110073; Off 3 3 49
  W 110083; Off 1 1 79
  W 110083; Off 3 3 37
  W 110107; Off 1 1 76
  W 110200; On 1 1 79 127
  W 110200; On 1 1 76 121
  W 110200; On 2 2 70 127
  W 110250; Off 2 2 70
  W 110283; Off 1 1 79
  W 110300; Off 1 1 76
  W 110400; On 3 3 49 96
  W 110400; On 3 3 37 100
  W 110400; On 6 6 64 120
  W 110400; On 6 6 67 120
  W 110400; On 6 6 68 120
  W 110400; On 7 7 58 120
  W 110467; Off 6 6 68
  W 110600; On 1 1 70 127
  W 110600; On 1 1 76 125
  W 110600; On 2 2 67 127
  W 110657; Off 2 2 67
  W 110700; Off 1 1 70
  W 110700; Off 1 1 76
  W 110800; On 1 1 70 127
  W 110800; On 1 1 76 121
  W 110800; On 2 2 67 127
  W 110867; Off 2 2 67
  W 110890; Off 1 1 70
  W 110907; Off 1 1 76
  W 110933; Off 3 3 49
  W 110933; Off 3 3 37
  W 111000; On 1 1 70 127
  W 111000; On 1 1 76 127
  W 111000; On 2 2 67 127
  W 111057; Off 2 2 67
  W 111083; Off 7 7 49
  W 111090; Off 1 1 70
  W 111090; Off 7 7 58
  W 111107; Off 1 1 76
  W 111107; Off 6 6 64
  W 111117; Off 6 6 67
  W 111200; On 3 3 49 112
  W 111200; On 3 3 37 88
  W 111200; On 6 6 64 120
  W 111200; On 6 6 67 120
  W 111200; On 7 7 58 120
  W 111200; On 7 7 49 120
  W 111400; On 1 1 67 125
  W 111400; On 1 1 70 127
  W 111400; On 2 2 64 127
  W 111457; Off 2 2 64
  W 111483; Off 1 1 67
  W 111490; Off 1 1 70
  W 111600; On 1 1 67 127
  W 111600; On 1 1 70 127
  W 111600; On 2 2 64 127
  W 111657; Off 2 2 64
  W 111673; Off 1 1 67
  W 111683; Off 1 1 70
  W 111723; Off 3 3 37
  W 111740; Off 3 3 49
  W 111800; On 1 1 67 127
  W 111800; On 1 1 70 127
  W 111800; On 2 2 64 127
  W 111850; Off 7 7 49
  W 111857; Off 2 2 64
  W 111857; Off 4 4 49
  W 111873; Off 1 1 67
  W 111883; Off 8 8 49
  W 111890; Off 1 1 70
  W 111900; Off 4 4 58
  W 112000; On 0 0 68 96
  W 112000; On 0 0 65 112
  W 112000; On 3 3 39 52
  W 112000; On 3 3 49 104
  W 112000; On 3 3 37 112
  W 112000; On 6 6 65 120
  W 112000; On 6 6 68 120
  W 112000; On 7 7 49 120
  W 112000; On 7 7 59 120
  W 112007; On 4 4 59 112
  W 112007; On 4 4 49 112
  W 112007; On 4 4 51 12
  W 112007; On 8 8 49 104
  W 112007; On 8 8 50 96
  W 112007; On 8 8 61 112
  W 112007; On 8 8 65 108
  W 112017; Off 3 3 39
  W 112017; Off 6 6 64
  W 112023; Off 4 4 51
  W 112040; Off 6 6 67
  W 112050; Off 8 8 64
  W 112057; Off 8 8 58
  W 112073; Off 0 0 64
  W 112073; Off 8 8 50
  W 112083; Off 0 0 67
  W 112083; Off 7 7 58
  W 112200; On 1 1 71 121
  W 112200; On 1 1 65 127
  W 112200; On 2 2 59 127
  W 112267; Off 1 1 65
  W 112267; Off 2 2 59
  W 112300; Off 1 1 71
  W 112400; On 1 1 65 127
  W 112400; On 1 1 71 127
  W 112400; On 2 2 59 127
  W 112457; Off 2 2 59
  W 112483; Off 1 1 65
  W 112507; Off 1 1 71
  W 112550; Off 3 3 49
  W 112550; Off 3 3 37
  W 112600; On 1 1 72 29
  W 112600; On 1 1 65 127
  W 112600; On 1 1 71 127
  W 112600; On 2 2 59 127
  W 112623; Off 1 1 72
  W 112650; Off 2 2 59
  W 112683; Off 1 1 65
  W 112733; Off 1 1 71
  W 112800; On 3 3 49 116
  W 112800; On 3 3 37 104
  W 113000; On 1 1 65 127
  W 113000; On 1 1 59 101
  W 113000; On 2 2 59 127
  W 113067; Off 2 2 59
  W 113090; Off 1 1 59
  W 113107; Off 1 1 65
  W 113200; On 1 1 65 105
  W 113200; On 1 1 59 101
  W 113200; On 2 2 59 127
  W 113273; Off 2 2 59
  W 113290; Off 1 1 65
  W 113290; Off 1 1 59
  W 113323; Off 3 3 49
  W 113340; Off 3 3 37
  W 113400; On 1 1 65 127
  W 113400; On 1 1 59 127
  W 113400; On 2 2 59 127
  W 113517; Off 1 1 59
  W 113573; Off 1 1 65
  W 113573; Off 2 2 59
  W 113573; Off 7 7 59
  W 113590; Off 0 0 68
  W 113600; Off 8 8 65
  W 113600; On 0 0 61 92
  W 113600; On 0 0 66 100
  W 113600; On 3 3 49 112
  W 113600; On 3 3 37 104
  W 113600; On 6 6 66 120
  W 113600; On 7 7 57 120
  W 113607; On 4 4 57 100
  W 113607; On 8 8 66 108
  W 113607; On 8 8 57 84
  W 113617; Off 0 0 65
  W 113623; Off 6 6 65
  W 113650; Off 8 8 61
  W 113700; Off 6 6 68
  W 113717; Off 4 4 59
  W 113800; Off 6 6 66
  W 113800; On 1 1 57 127
  W 113800; On 1 1 66 127
  W 113800; On 2 2 57 127
  W 113800; On 6 6 66 120
  W 113873; Off 2 2 57
  W 113883; Off 1 1 57
  W 113923; Off 1 1 66
  W 114000; On 1 1 58 57
  W 114000; On 1 1 57 127
  W 114000; On 1 1 66 121
  W 114000; On 2 2 57 127
  W 114017; Off 1 1 58
  W 114067; Off 2 2 57
  W 114090; Off 1 1 66
  W 114100; Off 1 1 57
  W 114167; Off 3 3 37
  W 114173; Off 3 3 49
  W 114200; On 1 1 57 127
  W 114200; On 1 1 66 127
  W 114200; On 2 2 57 121
  W 114257; Off 2 2 57
  W 114267; Off 7 7 49
  W 114307; Off 1 1 57
  W 114323; Off 1 1 66
  W 114400; On 3 3 39 16
  W 114400; On 3 3 49 80
  W 114400; On 3 3 37 88
  W 114400; On 7 7 49 120
  W 114417; Off 3 3 39
  W 114600; On 1 1 73 127
  W 114600; On 1 1 78 127
  W 114600; On 2 2 69 127
  W 114667; Off 2 2 69
  W 114690; Off 1 1 73
  W 114707; Off 1 1 78
  W 114800; On 1 1 73 127
  W 114800; On 1 1 78 127
  W 114800; On 2 2 69 127
  W 114867; Off 2 2 69
  W 114890; Off 1 1 73
  W 114907; Off 1 1 78
  W 114917; Off 3 3 49
  W 114923; Off 3 3 37
  W 115000; On 1 1 73 113
  W 115000; On 1 1 78 127
  W 115000; On 2 2 69 127
  W 115007; Off 0 0 61
  W 115023; Off 4 4 57
  W 115050; Off 0 0 66
  W 115057; Off 7 7 49
  W 115073; Off 1 1 73
  W 115083; Off 8 8 57
  W 115100; Off 1 1 78
  W 115107; Off 4 4 49
  W 115123; Off 2 2 69
  W 115183; Off 6 6 66
  W 115183; Off 8 8 49
  W 115200; On 0 0 66 108
  W 115200; On 0 0 63 100
  W 115200; On 3 3 48 112
  W 115200; On 3 3 36 120
  W 115200; On 7 7 48 120
  W 115207; On 4 4 48 120
  W 115207; On 4 4 57 112
  W 115207; On 8 8 63 92
  W 115207; On 8 8 48 112
  W 115207; On 8 8 57 120
  W 115250; Off 8 8 66
  W 115283; Off 7 7 57
  W 115400; On 1 1 81 127
  W 115400; On 1 1 78 127
  W 115400; On 2 2 75 127
  W 115467; Off 2 2 75
  W 115473; Off 1 1 78
  W 115483; Off 1 1 81
  W 115600; On 1 1 81 127
  W 115600; On 1 1 78 127
  W 115600; On 2 2 75 125
  W 115657; Off 2 2 75
  W 115673; Off 1 1 78
  W 115683; Off 1 1 81
  W 115707; Off 3 3 36
  W 115717; Off 3 3 48
  W 115800; On 1 1 81 127
  W 115800; On 1 1 78 127
  W 115800; On 2 2 75 127
  W 115857; Off 2 2 75
  W 115873; Off 1 1 81
  W 115883; Off 1 1 78
  W 116000; On 3 3 48 120
  W 116000; On 3 3 36 108
  W 116200; On 1 1 78 127
  W 116200; On 1 1 75 127
  W 116200; On 2 2 69 127
  W 116257; Off 2 2 69
  W 116283; Off 1 1 75
  W 116290; Off 1 1 78
  W 116400; On 1 1 78 127
  W 116400; On 1 1 75 127
  W 116400; On 2 2 69 127
  W 116457; Off 2 2 69
  W 116473; Off 1 1 75
  W 116483; Off 1 1 78
  W 116533; Off 3 3 48
  W 116533; Off 3 3 36
  W 116600; On 1 1 78 127
  W 116600; On 1 1 75 125
  W 116600; On 2 2 69 127
  W 116657; Off 2 2 69
  W 116690; Off 1 1 78
  W 116690; Off 1 1 75
  W 116800; On 3 3 48 116
  W 116800; On 3 3 36 124
  W 116800; On 6 6 66 120
  W 116800; On 6 6 63 120
  W 116800; On 7 7 57 120
  W 117000; On 1 1 75 127
  W 117000; On 1 1 69 127
  W 117000; On 2 2 66 127
  W 117057; Off 2 2 66
  W 117073; Off 1 1 69
  W 117090; Off 1 1 75
  W 117200; On 1 1 75 125
  W 117200; On 1 1 69 127
  W 117200; On 2 2 66 127
  W 117257; Off 2 2 66
  W 117283; Off 1 1 75
  W 117283; Off 1 1 69
  W 117323; Off 3 3 36
  W 117333; Off 3 3 48
  W 117400; On 1 1 75 127
  W 117400; On 1 1 69 127
  W 117400; On 2 2 66 127
  W 117440; Off 6 6 66
  W 117457; Off 2 2 66
  W 117457; Off 7 7 57
  W 117467; Off 6 6 63
  W 117483; Off 1 1 69
  W 117490; Off 1 1 75
  W 117507; Off 7 7 48
  W 117600; On 3 3 48 116
  W 117600; On 3 3 36 124
  W 117600; On 6 6 63 120
  W 117600; On 6 6 66 120
  W 117600; On 7 7 57 120
  W 117600; On 7 7 48 120
  W 117800; On 1 1 69 127
  W 117800; On 1 1 66 127
  W 117800; On 2 2 63 125
  W 117873; Off 2 2 63
  W 117890; Off 1 1 69
  W 117890; Off 1 1 66
  W 118000; On 1 1 69 127
  W 118000; On 1 1 66 127
  W 118000; On 2 2 63 127
  W 118073; Off 2 2 63
  W 118083; Off 1 1 66
  W 118090; Off 1 1 69
  W 118123; Off 3 3 36
  W 118133; Off 3 3 48
  W 118200; Off 7 7 48
  W 118200; On 1 1 69 127
  W 118200; On 1 1 66 127
  W 118200; On 2 2 63 127
  W 118267; Off 8 8 48
  W 118273; Off 2 2 63
  W 118290; Off 1 1 69
  W 118300; Off 1 1 66
  W 118317; Off 4 4 57
  W 118333; Off 4 4 48
  W 118340; Off 0 0 66
  W 118340; Off 0 0 63
  W 118373; Off 6 6 66
  W 118390; Off 8 8 57
  W 118400; On 0 0 67 112
  W 118400; On 0 0 64 96
  W 118400; On 3 3 48 108
  W 118400; On 3 3 39 48
  W 118400; On 3 3 36 120
  W 118400; On 6 6 67 120
  W 118400; On 6 6 64 120
  W 118400; On 7 7 48 120
  W 118400; On 7 7 58 120
  W 118407; Off 3 3 39
  W 118407; Off 7 7 57
  W 118407; On 4 4 48 96
  W 118407; On 4 4 58 112
  W 118407; On 4 4 54 40
  W 118407; On 8 8 48 116
  W 118407; On 8 8 58 116
  W 118407; On 8 8 64 116
  W 118423; Off 4 4 54
  W 118440; Off 6 6 63
  W 118483; Off 8 8 63
  W 118600; On 1 1 70 113
  W 118600; On 1 1 67 127
  W 118600; On 2 2 64 121
  W 118667; Off 2 2 64
  W 118673; Off 1 1 67
  W 118717; Off 1 1 70
  W 118800; On 1 1 70 127
  W 118800; On 1 1 67 127
  W 118800; On 2 2 64 127
  W 118857; Off 2 2 64
  W 118883; Off 1 1 67
  W 118890; Off 1 1 70
  W 118957; Off 3 3 48
  W 118957; Off 3 3 36
  W 119000; On 1 1 70 127
  W 119000; On 1 1 67 127
  W 119000; On 2 2 64 127
  W 119057; Off 2 2 64
  W 119083; Off 1 1 70
  W 119090; Off 1 1 67
  W 119090; Off 7 7 58
  W 119100; Off 6 6 67
  W 119123; Off 6 6 64
  W 119200; On 3 3 48 112
  W 119200; On 3 3 36 104
  W 119200; On 6 6 67 120
  W 119200; On 6 6 64 120
  W 119200; On 7 7 58 120
  W 119400; On 1 1 64 127
  W 119400; On 1 1 58 113
  W 119400; On 2 2 55 127
  W 119473; Off 2 2 55
  W 119483; Off 1 1 58
  W 119490; Off 1 1 64
  W 119600; On 1 1 64 127
  W 119600; On 1 1 58 127
  W 119600; On 2 2 55 127
  W 119667; Off 2 2 55
  W 119683; Off 1 1 58
  W 119690; Off 1 1 64
  W 119717; Off 3 3 48
  W 119717; Off 3 3 36
  W 119800; On 1 1 64 127
  W 119800; On 1 1 58 127
  W 119800; On 2 2 55 127
  W 119873; Off 2 2 55
  W 119873; Off 4 4 58
  W 119883; Off 1 1 58
  W 119900; Off 1 1 64
  W 119933; Off 7 7 48
  W 119967; Off 8 8 64
  W 120000; On 0 0 65 120
  W 120000; On 1 1 66 53
  W 120000; On 3 3 48 112
  W 120000; On 3 3 39 40
  W 120000; On 3 3 36 124
  W 120000; On 6 6 65 120
  W 120000; On 6 6 65 120
  W 120000; On 7 7 48 120
  W 120000; On 7 7 56 120
  W 120003; Off 6 6 65
  W 120007; On 4 4 56 100
  W 120007; On 8 8 56 116
  W 120007; On 8 8 65 108
  W 120017; Off 3 3 39
  W 120023; Off 1 1 66
  W 120033; Off 8 8 58
  W 120040; Off 6 6 64
  W 120040; Off 7 7 58
  W 120050; Off 0 0 64
  W 120050; Off 6 6 67
  W 120057; Off 0 0 67
  W 120200; On 1 1 65 127
  W 120200; On 1 1 56 127
  W 120200; On 2 2 60 127
  W 120257; Off 2 2 60
  W 120283; Off 1 1 56
  W 120290; Off 1 1 65
  W 120400; On 1 1 65 127
  W 120400; On 1 1 56 127
  W 120400; On 2 2 60 127
  W 120457; Off 2 2 60
  W 120473; Off 1 1 56
  W 120483; Off 1 1 65
  W 120550; Off 3 3 48
  W 120550; Off 3 3 36
  W 120600; On 1 1 65 127
  W 120600; On 1 1 56 127
  W 120600; On 2 2 60 125
  W 120650; Off 2 2 60
  W 120683; Off 1 1 65
  W 120683; Off 1 1 56
  W 120707; Off 7 7 56
  W 120800; Off 6 6 65
  W 120800; On 0 0 60 120
  W 120800; On 3 3 48 116
  W 120800; On 3 3 36 120
  W 120800; On 6 6 65 120
  W 120800; On 6 6 60 120
  W 120800; On 7 7 56 120
  W 121000; On 1 1 68 127
  W 121000; On 1 1 60 127
  W 121000; On 2 2 53 117
  W 121023; Off 2 2 53
  W 121073; Off 1 1 60
  W 121083; Off 1 1 68
  W 121200; On 1 1 68 127
  W 121200; On 1 1 60 121
  W 121200; On 2 2 54 81
  W 121200; On 2 2 53 127
  W 121217; Off 2 2 54
  W 121257; Off 2 2 53
  W 121273; Off 1 1 68
  W 121283; Off 1 1 60
  W 121350; Off 3 3 36
  W 121357; Off 3 3 48
  W 121390; Off 8 8 48
  W 121400; On 1 1 68 125
  W 121400; On 1 1 60 127
  W 121400; On 2 2 53 125
  W 121407; Off 4 4 48
  W 121423; Off 7 7 48
  W 121440; Off 6 6 65
  W 121450; Off 4 4 56
  W 121457; Off 2 2 53
  W 121473; Off 1 1 60
  W 121483; Off 6 6 60
  W 121483; Off 8 8 65
  W 121500; Off 0 0 60
  W 121500; Off 1 1 68
  W 121533; Off 0 0 65
  W 121600; On 0 0 65 112
  W 121600; On 0 0 60 104
  W 121600; On 3 3 48 116
  W 121600; On 3 3 39 32
  W 121600; On 3 3 36 112
  W 121600; On 6 6 65 120
  W 121600; On 6 6 60 120
  W 121600; On 7 7 48 120
  W 121607; On 4 4 55 108
  W 121607; On 4 4 48 112
  W 121607; On 8 8 48 124
  W 121607; On 8 8 65 104
  W 121607; On 8 8 55 112
  W 121617; Off 3 3 39
  W 121673; Off 7 7 56
  W 121683; Off 8 8 56
  W 121800; On 1 1 65 127
  W 121800; On 1 1 60 127
  W 121800; On 2 2 55 127
  W 121800; On 7 7 55 120
  W 121857; Off 1 1 60
  W 121867; Off 2 2 55
  W 121873; Off 1 1 65
  W 122000; On 1 1 65 121
  W 122000; On 1 1 60 127
  W 122000; On 2 2 55 127
  W 122057; Off 1 1 60
  W 122057; Off 2 2 55
  W 122090; Off 1 1 65
  W 122157; Off 3 3 36
  W 122167; Off 3 3 48
  W 122200; On 1 1 65 127
  W 122200; On 1 1 60 127
  W 122200; On 2 2 55 127
  W 122250; Off 2 2 55
  W 122267; Off 1 1 60
  W 122307; Off 1 1 65
  W 122400; On 3 3 48 112
  W 122400; On 3 3 36 120
  W 122600; On 1 1 67 127
  W 122600; On 1 1 60 125
  W 122600; On 2 2 58 127
  W 122650; Off 2 2 58
  W 122667; Off 1 1 60
  W 122690; Off 1 1 67
  W 122800; On 1 1 67 127
  W 122800; On 1 1 66 125
  W 122800; On 1 1 60 117
  W 122800; On 2 2 58 127
  W 122840; Off 2 2 58
  W 122867; Off 1 1 60
  W 122883; Off 1 1 66
  W 122890; Off 1 1 67
  W 122950; Off 3 3 48
  W 122967; Off 3 3 36
  W 123000; On 1 1 67 121
  W 123000; On 1 1 60 125
  W 123000; On 2 2 58 127
  W 123050; Off 2 2 58
  W 123067; Off 1 1 60
  W 123107; Off 1 1 67
  W 123200; On 0 0 64 124
  W 123200; On 3 3 48 104
  W 123200; On 3 3 36 120
  W 123200; On 6 6 64 120
  W 123207; On 8 8 64 120
  W 123217; Off 0 0 65
  W 123250; Off 6 6 65
  W 123283; Off 8 8 65
  W 123400; On 1 1 64 127
  W 123400; On 1 1 60 117
  W 123400; On 2 2 55 127
  W 123450; Off 2 2 55
  W 123473; Off 1 1 60
  W 123500; Off 1 1 64
  W 123600; On 1 1 64 127
  W 123600; On 1 1 60 127
  W 123600; On 2 2 55 113
  W 123650; Off 2 2 55
  W 123673; Off 1 1 60
  W 123707; Off 1 1 64
  W 123740; Off 3 3 48
  W 123750; Off 3 3 36
  W 123800; On 1 1 64 127
  W 123800; On 1 1 60 127
  W 123800; On 2 2 55 127
  W 123857; Off 2 2 55
  W 123873; Off 1 1 60
  W 123940; Off 1 1 64
  W 124000; On 3 3 48 112
  W 124000; On 3 3 36 108
  W 124200; On 1 1 67 127
  W 124200; On 1 1 58 127
  W 124200; On 2 2 52 121
  W 124273; Off 2 2 52
  W 124290; Off 1 1 58
  W 124300; Off 1 1 67
  W 124400; On 1 1 67 127
  W 124400; On 1 1 58 127
  W 124400; On 2 2 52 121
  W 124467; Off 2 2 52
  W 124467; Off 3 3 48
  W 124473; Off 1 1 58
  W 124490; Off 1 1 67
  W 124523; Off 3 3 36
  W 124540; Off 0 0 60
  W 124583; Off 0 0 64
  W 124600; On 1 1 67 105
  W 124600; On 1 1 58 121
  W 124600; On 2 2 52 125
  W 124607; Off 6 6 60
  W 124667; Off 2 2 52
  W 124673; Off 1 1 58
  W 124717; Off 1 1 67
  W 124757; Off 8 8 55
  W 124790; Off 6 6 64
  W 124800; On 0 0 65 120
  W 124800; On 0 0 60 124
  W 124800; On 3 3 41 116
  W 124800; On 3 3 29 124
  W 124800; On 6 6 65 120
  W 124800; On 6 6 60 120
  W 124800; On 7 7 53 120
  W 124800; On 7 7 41 120
  W 124807; On 4 4 57 100
  W 124807; On 4 4 53 96
  W 124807; On 8 8 65 96
  W 124807; On 8 8 57 124
  W 124807; On 8 8 41 124
  W 124817; Off 8 8 48
  W 124823; Off 4 4 55
  W 124833; Off 8 8 64
  W 124840; Off 7 7 48
  W 124857; Off 4 4 48
  W 124873; Off 7 7 55
  W 125000; On 1 1 65 127
  W 125000; On 1 1 57 121
  W 125000; On 2 2 53 127
  W 125057; Off 2 2 53
  W 125073; Off 1 1 57
  W 125100; Off 1 1 65
  W 125200; On 1 1 65 121
  W 125200; On 1 1 57 105
  W 125200; On 2 2 53 127
  W 125267; Off 2 2 53
  W 125273; Off 1 1 57
  W 125307; Off 1 1 65
  W 125323; Off 3 3 29
  W 125333; Off 3 3 41
  W 125400; On 1 1 65 127
  W 125400; On 1 1 57 127
  W 125400; On 2 2 53 127
  W 125457; Off 2 2 53
  W 125473; Off 1 1 57
  W 125540; Off 1 1 65
  W 125600; On 3 3 41 116
  W 125600; On 3 3 29 108
  W 125657; Off 7 7 41
  W 125667; Off 7 7 53
  W 125757; Off 6 6 65
  W 125790; Off 6 6 60
  W 125800; On 1 1 60 127
  W 125800; On 1 1 57 117
  W 125800; On 2 2 53 127
  W 125857; Off 1 1 57
  W 125857; Off 2 2 53
  W 125900; Off 1 1 60
  W 126000; On 1 1 60 127
  W 126000; On 1 1 57 125
  W 126000; On 2 2 53 105
  W 126050; Off 2 2 53
  W 126067; Off 3 3 41
  W 126067; Off 3 3 29
  W 126073; Off 1 1 57
  W 126100; Off 1 1 60
  W 126200; On 1 1 60 127
  W 126200; On 1 1 57 127
  W 126200; On 2 2 53 127
  W 126250; Off 2 2 53
  W 126257; Off 1 1 57
  W 126290; Off 1 1 60
  W 126400; On 3 3 41 104
  W 126400; On 3 3 29 120
  W 126600; On 1 1 65 127
  W 126600; On 1 1 57 113
  W 126600; On 2 2 53 117
  W 126640; Off 2 2 53
  W 126650; Off 1 1 57
  W 126700; Off 1 1 65
  W 126800; On 1 1 65 125
  W 126800; On 1 1 57 121
  W 126800; On 2 2 53 127
  W 126850; Off 2 2 53
  W 126857; Off 1 1 57
  W 126857; Off 3 3 29
  W 126873; Off 3 3 41
  W 126890; Off 1 1 65
  W 127000; On 1 1 65 127
  W 127000; On 1 1 57 85
  W 127000; On 2 2 53 105
  W 127040; Off 1 1 57
  W 127050; Off 2 2 53
  W 127107; Off 1 1 65
  W 127200; On 3 3 41 120
  W 127200; On 3 3 29 124
  W 127400; On 1 1 60 127
  W 127400; On 1 1 57 101
  W 127400; On 2 2 53 121
  W 127450; Off 1 1 57
  W 127450; Off 2 2 53
  W 127490; Off 1 1 60
  W 127600; On 1 1 60 127
  W 127600; On 1 1 57 121
  W 127600; On 2 2 53 97
  W 127650; Off 1 1 57
  W 127650; Off 2 2 53
  W 127683; Off 1 1 60
  W 127700; Off 3 3 41
  W 127700; Off 3 3 29
  W 127800; On 1 1 60 125
  W 127800; On 1 1 57 127
  W 127800; On 2 2 53 85
  W 127833; Off 2 2 53
  W 127840; Off 1 1 57
  W 127900; Off 1 1 60
  W 128000; On 1 1 65 117
  W 128000; On 1 1 57 85
  W 128000; On 2 2 53 85
  W 128000; On 3 3 41 100
  W 128000; On 3 3 29 116
  W 128757; Off 1 1 57
  W 128773; Off 2 2 53
  W 128823; Off 8 8 65
  W 128840; Off 0 0 60
  W 128840; Off 4 4 57
  W 128840; Off 4 4 53
  W 128850; Off 0 0 65
  W 128850; Off 1 1 65
  W 128850; Off 8 8 57
  W 128890; Off 3 3 41
  W 128890; Off 3 3 29
  W 128890; Off 8 8 41
  W 128890
} finally {
  [PsMusic]::Close()
}
