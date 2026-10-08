---
name: powershell-music-output
description: Beep(Console.Beep)とMicrosoft GS Wavetable Synth(winmm)を混在させて演奏するPowerShellスクリプトを生成・修正するときに使う。タイムライン計算、Start-Sleep挿入、周波数変換、Add-Type雛形を含む。
---

# PowerShell 出力スクリプト仕様

## 変換式
- 周波数: `round(440 * 2^((note-69)/12))`、範囲 37〜32767 にクランプ
- ms: `tick * 60000 / (bpm * ppq)`。各イベントは**開始tickから絶対msを算出**し、前イベントとの差を `Start-Sleep -Milliseconds` に使う
- 同時刻のイベント順: NoteOff → NoteOn

## 雛形
```powershell
Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public class Midi {
  [DllImport("winmm.dll")] public static extern int midiOutGetNumDevs();
  [DllImport("winmm.dll", CharSet=CharSet.Auto)] public static extern int midiOutGetDevCaps(int id, ref MIDIOUTCAPS caps, int size);
  [DllImport("winmm.dll")] public static extern int midiOutOpen(out IntPtr h, int id, IntPtr cb, IntPtr inst, int flags);
  [DllImport("winmm.dll")] public static extern int midiOutShortMsg(IntPtr h, uint msg);
  [DllImport("winmm.dll")] public static extern int midiOutClose(IntPtr h);
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Auto)]
  public struct MIDIOUTCAPS { public ushort mid, pid; public uint ver; [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string name; public ushort tech, voices, notes, chanMask; public uint support; }
}
"@
# デバイス名 "Microsoft GS Wavetable Synth" を検索して id を決定、見つからなければ 0
# msg = status | (d1 << 8) | (d2 << 16)  (NoteOn=0x90+ch, NoteOff=0x80+ch, ProgramChange=0xC0+ch)
```
- Beepは呼び出し中ブロックされる → 別Runspace(`[powershell]::Create()` + `BeginInvoke`)で鳴らし、メインのタイムラインを止めない
- 終了時: 全chにCC123(All Notes Off)→ `midiOutClose`(try/finallyで必ず実行)

## 注意
- ドラムは ch index 9
- Beepは同時1音。重なりは「後優先 / 無視」を設定化、GUIで警告
- `Add-Type` はPS 5.1/7両対応の書き方に(`-TypeDefinition`、重複定義はクラス名存在チェック)
- Beepが鳴らない環境がある → アプリのBeepテストで検出
- 文字列埋め込み時はPowerShellの `$`・バッククォート・`"@` をエスケープ
