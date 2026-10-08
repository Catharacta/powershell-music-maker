# PowerShell Music Maker 設計書

## 目的
ピアノロールGUI(Tauri 2 + Svelte 5 + TypeScript)で作曲し、PowerShellで実行すると演奏される `.ps1` を出力するアプリ。

## 調査結果(要約)
ピアノロール→Beep/GS Wavetable向けPowerShell出力を行う既存ツールは確認できず(検索2回のみ)。類似は手書きサンプルや汎用MIDI変換(miditones等)のみ。

## 核心要件
1. 出力先は**トラック単位**で `beep` / `gs` を選択。1曲内で混在可能(モード切替ではない)。
2. BPM変更可。出力時に音と音の間隔を計算して `Start-Sleep -Milliseconds` を挿入。
3. アプリ内試聴が必須:
   - 全曲試聴(出力スクリプトと同じイベントタイムライン)
   - **Beepテスト**: 実際に `powershell -Command "[Console]::Beep(440,500)"` を起動し、成否(終了コード/stderr)を表示。PS 5.1 と 7(pwsh) 両方
   - GSテスト: デバイス検出とテスト音

## データモデル
- 内部時間は tick(PPQ=480)。
- `Project { bpm, ppq, tracks[] }`
- `Track { id, name, output: 'beep'|'gs', channel(0-15), program(0-127), volume, mute, notes[] }`
- `Note { startTick, durationTick, pitch(0-127), velocity }`
- 変換: `ms = tick * 60000 / (bpm * ppq)`。丸め誤差は累積tickから絶対msを算出して防ぐ(差分を丸めて足さない)。

## イベントタイムライン
全トラックのノートを `NoteOn`/`NoteOff` に展開し、時刻順(同時刻はOff→On)にソート。
`Event { tMs, kind: 'gs_on'|'gs_off'|'beep', ch, pitch, vel, durMs, freq }`
出力スクリプトも試聴(Rust)も**同一のタイムライン生成ロジック**を使う(TS側で生成しRustへ渡す、またはRust実装を単一の真実とする。要決定: 推奨はTS生成→JSONでRustに渡す)。

## 出力スクリプト構造
```powershell
Add-Type @"  # winmm P/Invoke: midiOutOpen/midiOutShortMsg/midiOutClose/midiOutGetDevCaps
"@
# "Microsoft GS Wavetable Synth" をmidiOutGetDevCapsで検索してデバイスID決定
# Program Change送信
$sw = [Diagnostics.Stopwatch]::StartNew()
# イベントごと: 差分をStart-Sleep -Milliseconds で待機 → 発音
# Beepはブロックするため別Runspaceで非同期実行
# 終了時 All Notes Off(CC123) と midiOutClose
```
- 周波数: `440 * 2^((n-69)/12)` を整数に丸め、Beep有効範囲 37〜32767Hz にクランプ。
- Beepは同時1音。重なり時の挙動(後優先/無視)を設定可能、GUIで警告。
- ドラムはGSのチャンネル10(index 9)。
- PS 5.1/7 両対応の `Add-Type`。

## アプリ内試聴(Rust側)
- GS: `windows` クレートで winmm `midiOutShortMsg` を直接呼ぶ。
- Beep: kernel32 `Beep` を別スレッドで呼ぶ。
- Beepテスト: `std::process::Command` で powershell/pwsh を起動し結果を返すTauri command。
- 再生は停止可能に(キャンセルトークン、停止時 All Notes Off)。

## ディレクトリ案
```
src/            Svelte UI (lib/pianoroll, lib/store, lib/generator)
src-tauri/      Rust (commands: play, stop, test_beep, test_gs, list_midi_devices)
docs/           ドキュメント
.agents/skills/ エージェント用スキル
```

## マイルストーン
1. Tauri+Svelte雛形、ピアノロール編集
2. Beep出力のスクリプト生成+実機確認
3. GS出力、トラック、音色、混在タイムライン
4. BPM/クォンタイズ/アプリ内試聴/Beepテスト
5. プロジェクト保存(JSON)、MIDIインポート、MSI配布

## リスク
- 新しいWindowsでConsole.Beepが鳴らない環境あり → Beepテストで検出。
- 実行ポリシー → 貼り付け実行用の出力形式も提供。
- Start-Sleepの精度(約15ms粒度) → Stopwatch絶対時刻同期。

## UIデザイン(ネオブルータリズム)
- **枠・影**: 太い黒枠(3〜4px)、ぼかしなしハードシャドウ(例 `6px 6px 0 #000`)、角丸0
- **配色**: 背景はオフホワイト/クリーム。原色アクセント(黄・ピンク・シアン・ライム)。出力先の色分け: Beep=黄、GS=水色
- **タイポ**: 見出しは極太サンセリフ(Archivo Black / Space Grotesk Bold)、数値(BPM等)は等幅(JetBrains Mono / Space Mono)
- **ピアノロール**: 鍵盤は黒枠ブロック(黒鍵は塗り)。ノートは太枠カラーブロック、選択時はハードシャドウでずらして浮かせる。グリッドは濃い黒、小節線は太・拍線は細。再生位置は太い縦線
- **UI部品**: ボタンは通常時ハードシャドウ、押下で影が消え沈む。Beepテスト結果は大きな緑(成功)/赤(失敗)ラベル
- **実装**: 色・枠・影はCSS変数(`--border`, `--shadow`, `--c-beep`, `--c-gs` 等)に集約。Canvasも同じ変数を読む
- 実装前に画像生成でモックを作り確認する
