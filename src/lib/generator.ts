// タイムライン → PowerShell 5.1 / 7 両対応の .ps1 文字列
// 出力スクリプトは文字化け防止のため ASCII(英語)のみを使う。
import type { Project } from './model';
import type { Timeline } from './timeline';

const CS_HEAD = `using System;
using System.Runtime.InteropServices;
using System.Threading;
public class PsMusic {`;

const CS_BEEP = `
  public static void Beep(int f, int d) {
    Thread t = new Thread(delegate() { try { Console.Beep(f, d); } catch (Exception) { } });
    t.IsBackground = true; t.Start();
  }`;

// winmm.dll は GS Wavetable Synth を使うトラックがある場合のみ出力する
const CS_GS = `
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
  public static void Close() {
    if (hOut == IntPtr.Zero) return;
    for (int ch = 0; ch < 16; ch++) Send(0xB0 | ch, 123, 0);
    midiOutClose(hOut); hOut = IntPtr.Zero;
  }`;

/** 非ASCII文字を '?' に置換し、改行を除去する */
function ascii(s: string): string {
  return s.replace(/[\r\n]/g, ' ').replace(/[^\x20-\x7e]/g, '?');
}

export function generateScript(p: Project, tl: Timeline): string {
  const L: string[] = [];
  L.push('# PowerShell Music Maker generated script (PowerShell 5.1 / 7)');
  L.push(`# BPM=${p.bpm}  tracks: ` + p.tracks.map((t) => `${ascii(t.name)}[${t.output}]`).join(', '));
  L.push("if (-not ('PsMusic' -as [type])) {");
  L.push("Add-Type -TypeDefinition @'");
  L.push(CS_HEAD + (tl.hasGs ? CS_GS : '') + (tl.hasBeep ? CS_BEEP : '') + '\n}');
  L.push("'@");
  L.push('}');
  L.push('# Wait until the absolute time with Start-Sleep (no accumulated drift)');
  L.push('$sw = [Diagnostics.Stopwatch]::StartNew()');
  L.push('function W([int]$t) { $d = $t - [int]$sw.ElapsedMilliseconds; if ($d -gt 0) { Start-Sleep -Milliseconds $d } }');
  if (tl.hasGs) {
    L.push('function Prog($ch, $p) { [PsMusic]::Send((0xC0 -bor $ch), $p, 0) }');
    L.push('function On($ch, $n, $v) { [PsMusic]::Send((0x90 -bor $ch), $n, $v) }');
    L.push('function Off($ch, $n) { [PsMusic]::Send((0x80 -bor $ch), $n, 0) }');
  }
  if (tl.hasBeep) L.push('function B($f, $d) { [PsMusic]::Beep($f, $d) }');
  L.push('try {');
  if (tl.hasGs) L.push('  [PsMusic]::Open()');
  for (const e of tl.events) {
    let cmd = '';
    switch (e.kind) {
      case 'gs_prog':
        cmd = `Prog ${e.ch} ${e.program}`;
        break;
      case 'gs_on':
        cmd = `On ${e.ch} ${e.pitch} ${e.vel}`;
        break;
      case 'gs_off':
        cmd = `Off ${e.ch} ${e.pitch}`;
        break;
      case 'beep':
        cmd = `B ${e.freq} ${e.durMs}`;
        break;
    }
    L.push(`  W ${e.tMs}; ${cmd}`);
  }
  L.push(`  W ${tl.endMs}`);
  L.push('} finally {');
  if (tl.hasGs) L.push('  [PsMusic]::Close()');
  L.push('}');
  return L.join('\r\n') + '\r\n';
}
