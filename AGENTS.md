# AGENTS.md

PowerShell Music Maker: ピアノロールGUI(Tauri 2 + Svelte 5 + TS)から、Beep / Microsoft GS Wavetable Synth を鳴らす PowerShell スクリプトを出力するアプリ。

必読: [docs/DESIGN.md](docs/DESIGN.md)

## ルール
- 出力先(beep/gs)は**トラック単位**。モード切替にしない。
- 時間は tick(PPQ=480)で保持、ms変換は絶対位置から計算(誤差累積禁止)。
- スクリプト出力と試聴は同一のタイムライン生成ロジックを共有する。
- アプリ内にBeep実機テスト(powershell/pwsh起動)とGSテストを必ず備える。
- 出力 `.ps1` は PowerShell 5.1 / 7 両対応。
- 既存コメントは無関係なら消さない。
- UIはネオブルータリズム(太い黒枠・ハードシャドウ・角丸0・原色)。詳細は docs/DESIGN.md の「UIデザイン」。色・枠・影はCSS変数に集約。

## スキル
- [.agents/skills/powershell-music-output/SKILL.md](.agents/skills/powershell-music-output/SKILL.md): PowerShell出力スクリプト生成の仕様と雛形
- [.agents/skills/tauri-svelte-dev/SKILL.md](.agents/skills/tauri-svelte-dev/SKILL.md): 開発・構成・Tauriコマンド方針
