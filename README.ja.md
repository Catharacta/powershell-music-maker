<p align="center">
  <img src="docs/images/app-icon.png" width="120" height="120" alt="PowerShell Music Maker アイコン" />
</p>

<h1 align="center">PowerShell Music Maker</h1>

<p align="center">
  <b>ピアノロールGUIで作曲し、単体で鳴る PowerShell スクリプト (.ps1) を出力するデスクトップDAW。</b><br>
  外部シンセや追加ソフトは不要！ Windows標準の <code>[Console]::Beep</code> と Microsoft GS Wavetable Synth だけで音楽を演奏します。
</p>

<p align="center">
  <a href="./README.md"><b>English README is available here</b></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Windows%2010%20%2F%2011-0078D6?style=for-the-badge&logo=windows&logoColor=white" alt="Platform" />
  <img src="https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white" alt="PowerShell" />
  <img src="https://img.shields.io/badge/Tauri-v2-FFC131?style=for-the-badge&logo=tauri&logoColor=black" alt="Tauri" />
  <img src="https://img.shields.io/badge/Svelte-5-FF3E00?style=for-the-badge&logo=svelte&logoColor=white" alt="Svelte" />
  <img src="https://img.shields.io/badge/License-MIT-black?style=for-the-badge" alt="License" />
</p>

---

## 📸 スクリーンショット

![PowerShell Music Maker UI](docs/images/screenshot.png)

---

## ✨ 主な特徴

- **🎛️ トラック単位のハイブリッド音源 (Beep × GS Synth)**
  - トラックごとに出力先音源を **Beep** (`[Console]::Beep`) または **GS** (Microsoft GS Wavetable Synth) から自由に指定可能。
  - レトロな単音Beepのピコピコ感と、128音色のGM音色・和音・ドラムを1曲の中で同時に組み合わせて演奏できます。
- **⏱️ 絶対時刻同期・累積誤差ゼロの正確なタイムライン**
  - 時間管理は高解像度 480 PPQ (Pulse Per Quarter Note) で保持。
  - 差分の丸めによる演奏のズレ（ジッター）を防ぐため、累積tickから絶対ミリ秒を計算し、`[Diagnostics.Stopwatch]` で精密に同期します。
- **💻 依存関係ゼロのピュアな PowerShell (.ps1) スクリプト生成**
  - **Windows PowerShell 5.1** および **PowerShell 7 (pwsh)** の双方でそのまま動作する `Add-Type` 雛形を採用。
  - スクリプト実行時にコンソール画面へ再生アニメーションと音名を表示する「CLIビジュアライザ」機能も搭載。
  - クリップボードへのワンクリックコピー、および UTF-8 BOM付き `.ps1` 保存に対応。
- **🎧 アプリ内試聴 & 実機テスト機能**
  - Tauri (Rust) バックエンドにより、出力スクリプトと**完全に同一のタイムラインロジック**でリアルタイム試聴が可能。
  - お使いのWindows環境で Beep や GS Wavetable Synth が正常に鳴るか確認できる「環境テスト」画面を完備。
- **🎹 ネオブルータリズム調の直感的なピアノロール**
  - 太い黒枠・ハードシャドウ・原色アクセント（Beep=黄、GS=水色）による視認性の高いUIデザイン。
  - ペンツール、矩形選択、ドラッグ移動、Alt+ドラッグ複製、Shift+矢印による音符長伸縮、コピペ（Ctrl+C/V/D）、グリッド吸着など充実した編集機能を搭載。
- **💾 プロジェクト保存・MIDIインポート**
  - 独自形式 `.psmm` でプロジェクトの保存・復元が可能。
  - 標準MIDIファイル (`.mid` / `.midi`) のインポートに対応し、トラックごとに自動展開。
- **🌐 完全多言語対応**
  - 日本語 / 英語をいつでも設定画面から切り替え可能。

---

## 🚀 クイックスタート

### 1. ダウンロード
[GitHub Releases](https://github.com/yuta0801/powershell-music-maker/releases) から最新バージョンのインストーラー (`.msi` または `.exe`) をダウンロードしてインストールします。

### 2. 基本的な作曲手順
1. **トラックの作成**: 左側サイドバーからトラックを追加し、音源を選択します。
   - **Beep**: 単音のPCスピーカー音。
   - **GS**: 和音や128種類の音色、チャンネル10のドラムが使用可能。
2. **ノートの入力**: ピアノロール上でクリックしてノートを配置します。端をドラッグして長さを調整できます。
3. **アプリ内で試聴**: ヘッダーの「**再生**」ボタンを押してその場でプレビューします。
4. **スクリプト出力**: 「**スクリプト生成**」ボタンを押し、コードをコピーするか `.ps1` として保存します。

### 3. 生成されたスクリプトの実行
PowerShell コンソールを開いてスクリプトを実行するだけです。

```powershell
powershell -ExecutionPolicy Bypass -File .\music.ps1
```

PowerShell 7 の場合:

```powershell
pwsh -File .\music.ps1
```

> **ヒント**: スクリプトの内容をコピーして PowerShell コンソールにそのまま貼り付けて実行することも可能です。

---

## ⌨️ 主なショートカット・操作一覧

| 操作 / ショートカット | 説明 |
| :--- | :--- |
| **グリッドをクリック** | ノートの配置 / 削除（ペンツール時） |
| **ノートをドラッグ** | 音高・タイミングの移動 |
| **Alt + ドラッグ** | ノートを複製して移動 |
| **Shift + ドラッグ** | 範囲選択（ラバーバンド） |
| **Shift + ← / →** | 選択中のノートの長さをグリッド単位で伸縮 |
| **矢印キー** | 選択中のノートを微調整（音高・時間） |
| **ノートを右クリック** | ノートを削除 |
| **Ctrl + C / Ctrl + V** | ノートのコピー / 貼り付け |
| **Ctrl + D** | 選択中のノートを直後に複製 |
| **Ctrl + A** | アクティブトラックのノートを全選択 |
| **Delete / Backspace** | 選択中のノートを削除 |
| **Ctrl + マウスホイール** | ピアノロールの横方向ズーム |
| **Ctrl + S / Ctrl + Shift + S** | プロジェクト上書き保存 / 名前を付けて保存 (`.psmm`) |
| **Ctrl + O / Ctrl + N** | プロジェクトを開く / 新規作成 |

---

## 🛠️ 開発・ビルド方法

### 前提環境
- [Node.js](https://nodejs.org/) (v18以上)
- [Rust](https://rustup.rs/) (stable ツールチェーン)
- [Visual Studio C++ Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/)

### リポジトリの準備と開発実行
```bash
# リポジトリをクローン
git clone https://github.com/yuta0801/powershell-music-maker.git
cd powershell-music-maker

# 依存パッケージのインストール
npm install

# 開発モードでアプリを起動
npm run tauri dev
```

### インストーラー / バイナリのビルド
```bash
# 本番向けビルド (MSI / EXE 等)
npm run tauri build
```
ビルド結果は `src-tauri/target/release/bundle/` 配下に出力されます。

---

## 🧱 技術スタック & アーキテクチャ

- **UIフレームワーク**: [Svelte 5](https://svelte.dev/) (Runesリアクティビティ) + [SvelteKit](https://kit.svelte.dev/) + TypeScript
- **デザインシステム**: 純粋なCSSによるネオブルータリズム設計（UIライブラリ不使用）
- **アイコン**: [@lucide/svelte](https://lucide.dev/)
- **デスクトップ基盤**: [Tauri v2](https://v2.tauri.app/)
- **ネイティブ音声バックエンド**: Rust (`windows` クレートによる `winmm` GS Synth直接呼び出し、`kernel32::Beep` によるBeep試聴)
- **MIDI解析**: [@tonejs/midi](https://github.com/Tonejs/Midi)

---

## 📄 ライセンス

このプロジェクトは [MIT License](LICENSE) のもとで公開されています。
