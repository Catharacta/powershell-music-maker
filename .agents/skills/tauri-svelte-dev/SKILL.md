---
name: tauri-svelte-dev
description: このプロジェクトのTauri 2 + Svelte 5 + TypeScriptアプリの構成、Tauriコマンド、ピアノロール実装、試聴/テスト機能を開発・変更するときに使う。
---

# 開発ガイド

## 構成
```
src/lib/model.ts       Project/Track/Note型 (tick, PPQ=480)
src/lib/timeline.ts    ノート→イベントタイムライン(出力と試聴で共有)
src/lib/generator.ts   タイムライン→.ps1文字列
src/lib/pianoroll/     Canvas描画・入力(追加/移動/リサイズ/削除/クォンタイズ)
src/lib/store.svelte.ts  $stateベースのストア(Svelte 5 runes)
src-tauri/src/         Rust: Tauriコマンド
```

## Tauriコマンド(Rust)
| コマンド | 内容 |
|---|---|
| `play(events)` | タイムラインJSONを再生。GS=winmm `midiOutShortMsg`、Beep=kernel32 `Beep`を別スレッド |
| `stop()` | 停止+All Notes Off |
| `test_beep(shell)` | `powershell`/`pwsh` で `[Console]::Beep(440,500)` を起動し `{ok, exitCode, stderr}` を返す |
| `test_gs()` | GSデバイス検出+テスト音 |
| `list_midi_devices()` | winmmデバイス一覧 |

## 方針
- タイムラインはTSで生成しJSONでRustへ(単一の真実)
- 再生はキャンセル可能にし、停止時に必ず All Notes Off
- UIは Svelte 5 runes(`$state`, `$derived`)を使用
- 雛形作成: `npm create tauri-app@latest`(Svelte + TypeScript)
- 検証: `npm run tauri dev`、生成した.ps1を実際にpowershell/pwshで実行して確認
- Windows専用(winmm依存)。他OSではビルドを `cfg(windows)` で分ける
