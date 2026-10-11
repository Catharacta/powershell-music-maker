import { settings } from './settings.svelte';

export const translations = {
  ja: {
    // ヘッダー / ファイル操作
    app_title: 'PowerShell Music Maker',
    file_new: '新規',
    file_open: '開く',
    file_save: '保存',
    file_save_as: '名前を付けて保存',
    file_import_midi: 'MIDIインポート',
    export_script: 'スクリプト生成',
    test_env: 'テスト',
    settings: '設定',

    // トランスポート & エディタツール
    play: '再生',
    stop: '停止',
    bars: '小節',
    bpm: 'BPM',
    zoom: '拡大',
    grid: 'グリッド',
    note_length: '音長',
    note_len_grid: 'グリッド連動',
    tool_draw: 'ペン',
    tool_select: '選択',
    action_select_all: '全選択',
    action_duplicate: '複製',
    action_delete: '削除',
    action_copy: 'コピー',
    action_paste: '貼り付け',
    piano_roll_hint: 'Shift+ドラッグ: 範囲選択 | ドラッグ: 移動 | Alt+ドラッグ: 複製移動 | 矢印キー: 移動 | Shift+←/→: 長さ伸縮 | 右クリック: 削除 | Ctrl+C/V/D: コピペ・複製',
    beep_conflicts: 'BEEP重なり',
    beep_conflict_tooltip: 'Beepは同時1音。重なった音は設定に応じて処理されます',
    editing_badge: '編集中',

    // ツールチップ
    tooltip_new: '新規作成 (Ctrl+N)',
    tooltip_open: 'プロジェクトを開く (Ctrl+O)',
    tooltip_save: '上書き保存 (Ctrl+S)',
    tooltip_save_as: '名前を付けて保存 (Ctrl+Shift+S)',
    tooltip_import_midi: 'MIDIファイルを読み込む',
    tooltip_export_script: 'PowerShellスクリプトを出力',
    tooltip_draw: '鉛筆ツール (クリックでノート作成、Shift+ドラッグで選択)',
    tooltip_select: '選択ツール (ドラッグで範囲選択)',
    tooltip_select_all: '全選択 (Ctrl+A)',
    tooltip_copy: 'コピー (Ctrl+C)',
    tooltip_paste: '貼り付け (Ctrl+V)',
    tooltip_duplicate: '複製 (Ctrl+D)',
    tooltip_delete: '削除 (Del)',
    tooltip_mute: 'ミュート',
    tooltip_channel: 'MIDIチャンネル (9=ドラム)',

    // トラック関連
    track_title: 'トラック',
    add_track: 'トラック追加',
    delete_track: 'トラック削除',
    track_output: '出力',
    track_channel: 'Ch',
    track_program: '音色',
    track_volume: '音量',
    track_mute: 'ミュート',
    track_beep_desc: 'Beep (単音)',
    track_gs_desc: 'GS Wavetable Synth (MIDI和音)',

    // 設定モーダル
    settings_title: '設定',
    settings_tab_general: '一般・言語',
    settings_tab_editor: 'エディタ設定',
    settings_tab_script: 'スクリプト・音源',
    settings_tab_about: 'ライセンス・情報',

    // 設定：一般・言語
    settings_language: '表示言語',
    settings_language_ja: '日本語',
    settings_language_en: 'English',

    // 設定：エディタ
    settings_default_bpm: '新規プロジェクト BPM',
    settings_default_bars: '新規プロジェクト 小節数',
    settings_default_quant: '既定グリッド解像度',
    settings_default_output: '新規トラックの既定音源',
    settings_load_demo_notes: '起動時にサンプル曲を読み込む',
    settings_load_demo_notes_desc: 'アプリ起動時にサンプルノート（メロディとコード）を読み込みます。無効にすると空のトラックで起動します。',
    quant_1_beat: '1拍 (4分音符)',
    quant_half_beat: '1/2拍 (8分音符)',
    quant_quarter_beat: '1/4拍 (16分音符)',
    quant_eighth_beat: '1/8拍 (32分音符)',

    // 設定：スクリプト・音源
    settings_visualizer: 'CLIビジュアライザ',
    settings_visualizer_desc: 'スクリプト実行時、PowerShellコンソールに再生状態と音名のアニメーションを表示します。',
    settings_preferred_ps: '優先PowerShell環境',
    settings_ps_auto: '自動検出 (pwsh > powershell)',
    settings_ps_powershell: 'Windows PowerShell (5.1)',
    settings_ps_pwsh: 'PowerShell 7 (pwsh)',
    settings_beep_overlap: 'Beep同時発音時の挙動',
    settings_beep_overlap_desc: 'Beepは単音発音のみ対応しています。同じタイミングで重なったノートの処理方法を指定します。',
    settings_beep_latest: '後優先 (新しい音で前の音を切り詰める)',
    settings_beep_ignore: '先優先 (発音中の音を維持し、重なった音を無視)',

    // 設定：ライセンス・情報
    settings_app_desc: 'ピアノロールから Beep / Microsoft GS Wavetable Synth を鳴らす PowerShell スクリプトを出力するアプリ',
    settings_version: 'バージョン',
    settings_repo: 'GitHub リポジトリ',
    settings_oss_licenses: 'オープンソースソフトウェア (OSS) ライセンス',
    settings_view_license: 'ライセンス全文を表示',
    settings_hide_license: 'ライセンス全文を閉じる',
    settings_reset: '初期設定に戻す',
    settings_reset_done: 'リセット完了',
    settings_close: '閉じる',

    // スクリプトプレビューモーダル
    script_modal_title: '生成された PowerShell スクリプト',
    script_modal_copy: 'コピー',
    script_modal_copied: 'コピー完了!',
    script_modal_save: '保存 (.ps1)',
    script_modal_close: '閉じる',

    // テストモーダル
    test_modal_title: 'PowerShell / 音源 実機テスト',
    test_run_all: 'すべて実行',
    test_beep_ps5: 'Windows PowerShell (5.1) Beep',
    test_beep_pwsh: 'PowerShell 7 (pwsh) Beep',
    test_gs_title: 'Microsoft GS Wavetable Synth',
    test_midi_devices: '検出されたMIDI出力デバイス',
    test_call_failed: '呼び出し失敗',

    // MIDIインポートダイアログ
    midi_import_title: 'MIDI インポート確認',
    midi_import_desc: 'MIDIファイルの読み込み方法を選択してください。',
    midi_import_new: '新規プロジェクトとして開く',
    midi_import_append: '現在のプロジェクトに追加',
    cancel: 'キャンセル',

    // ステータス・通知
    status_new_project: '新規プロジェクトを作成しました',
    status_opened_project: 'プロジェクトを開きました',
    status_saved_project: 'プロジェクトを保存しました',
    status_open_failed: 'プロジェクトを開けませんでした',
    status_save_failed: 'ファイルの保存に失敗しました',
    status_play_failed: '再生失敗',
    status_invalid_format: 'プロジェクトファイルの形式が不正です',
    alert_midi_parse_fail: 'MIDIファイルの解析に失敗しました'
  },
  en: {
    // Header / File operations
    app_title: 'PowerShell Music Maker',
    file_new: 'New',
    file_open: 'Open',
    file_save: 'Save',
    file_save_as: 'Save As',
    file_import_midi: 'Import MIDI',
    export_script: 'Export Script',
    test_env: 'Test',
    settings: 'Settings',

    // Transport & Editor tools
    play: 'Play',
    stop: 'Stop',
    bars: 'Bars',
    bpm: 'BPM',
    zoom: 'Zoom',
    grid: 'Grid',
    note_length: 'Note Len',
    note_len_grid: 'Follow Grid',
    tool_draw: 'Draw',
    tool_select: 'Select',
    action_select_all: 'Select All',
    action_duplicate: 'Duplicate',
    action_delete: 'Delete',
    action_copy: 'Copy',
    action_paste: 'Paste',
    piano_roll_hint: 'Shift+Drag: Box select | Drag: Move | Alt+Drag: Duplicate & move | Arrow keys: Nudge | Shift+←/→: Resize | Right-click: Delete | Ctrl+C/V/D: Copy/Paste/Duplicate',
    beep_conflicts: 'BEEP Conflicts',
    beep_conflict_tooltip: 'Console.Beep is monophonic. Overlapping notes are resolved based on settings',
    editing_badge: 'EDITING',

    // Tooltips
    tooltip_new: 'New Project (Ctrl+N)',
    tooltip_open: 'Open Project (Ctrl+O)',
    tooltip_save: 'Save Project (Ctrl+S)',
    tooltip_save_as: 'Save Project As (Ctrl+Shift+S)',
    tooltip_import_midi: 'Import MIDI file',
    tooltip_export_script: 'Export PowerShell script',
    tooltip_draw: 'Draw tool (Click to create notes, Shift+drag to select)',
    tooltip_select: 'Select tool (Drag to box select)',
    tooltip_select_all: 'Select All (Ctrl+A)',
    tooltip_copy: 'Copy (Ctrl+C)',
    tooltip_paste: 'Paste (Ctrl+V)',
    tooltip_duplicate: 'Duplicate (Ctrl+D)',
    tooltip_delete: 'Delete (Del)',
    tooltip_mute: 'Mute',
    tooltip_channel: 'MIDI Channel (9=drums)',

    // Tracks
    track_title: 'TRACKS',
    add_track: 'Add Track',
    delete_track: 'Delete Track',
    track_output: 'Output',
    track_channel: 'Ch',
    track_program: 'Patch',
    track_volume: 'Vol',
    track_mute: 'Mute',
    track_beep_desc: 'Beep (Monophonic)',
    track_gs_desc: 'GS Wavetable Synth (Polyphonic)',

    // Settings Modal
    settings_title: 'Settings',
    settings_tab_general: 'General',
    settings_tab_editor: 'Editor',
    settings_tab_script: 'Script & Audio',
    settings_tab_about: 'About & Licenses',

    // Settings: General
    settings_language: 'Language',
    settings_language_ja: '日本語',
    settings_language_en: 'English',

    // Settings: Editor
    settings_default_bpm: 'Default BPM',
    settings_default_bars: 'Default Bars',
    settings_default_quant: 'Default Grid Resolution',
    settings_default_output: 'Default Track Output',
    settings_load_demo_notes: 'Load demo song on startup',
    settings_load_demo_notes_desc: 'Loads pre-placed demo notes (melody and chords) on startup. If disabled, starts with an empty track.',
    quant_1_beat: '1 beat (1/4 Quarter)',
    quant_half_beat: '1/2 beat (1/8 Eighth)',
    quant_quarter_beat: '1/4 beat (1/16 Sixteenth)',
    quant_eighth_beat: '1/8 beat (1/32 Thirty-second)',

    // Settings: Script & Audio
    settings_visualizer: 'CLI Visualizer',
    settings_visualizer_desc: 'Display an interactive playback bar and note animation in the PowerShell console while playing.',
    settings_preferred_ps: 'Preferred PowerShell Shell',
    settings_ps_auto: 'Auto Detect (pwsh > powershell)',
    settings_ps_powershell: 'Windows PowerShell (5.1)',
    settings_ps_pwsh: 'PowerShell 7 (pwsh)',
    settings_beep_overlap: 'Beep Overlap Policy',
    settings_beep_overlap_desc: 'Console.Beep only plays one tone at a time. Choose how to handle overlapping notes.',
    settings_beep_latest: 'Latest (Cut off previous note when new note arrives)',
    settings_beep_ignore: 'Ignore (Keep current note playing, ignore overlapping notes)',

    // Settings: About & Licenses
    settings_app_desc: 'Piano roll editor generating PowerShell scripts using Beep and Microsoft GS Wavetable Synth.',
    settings_version: 'Version',
    settings_repo: 'GitHub Repository',
    settings_oss_licenses: 'Open Source Software (OSS) Licenses',
    settings_view_license: 'View license text',
    settings_hide_license: 'Hide license text',
    settings_reset: 'Reset to Defaults',
    settings_reset_done: 'Reset complete',
    settings_close: 'Close',

    // Script preview modal
    script_modal_title: 'Generated PowerShell Script',
    script_modal_copy: 'Copy',
    script_modal_copied: 'Copied!',
    script_modal_save: 'Save (.ps1)',
    script_modal_close: 'Close',

    // Test modal
    test_modal_title: 'PowerShell & Audio Device Tests',
    test_run_all: 'Run All Tests',
    test_beep_ps5: 'Windows PowerShell (5.1) Beep',
    test_beep_pwsh: 'PowerShell 7 (pwsh) Beep',
    test_gs_title: 'Microsoft GS Wavetable Synth',
    test_midi_devices: 'Detected MIDI Output Devices',
    test_call_failed: 'Call failed',

    // MIDI import dialog
    midi_import_title: 'Import MIDI File',
    midi_import_desc: 'Choose how to import the selected MIDI file.',
    midi_import_new: 'Open as New Project',
    midi_import_append: 'Append to Current Project',
    cancel: 'Cancel',

    // Status & notifications
    status_new_project: 'Created new project',
    status_opened_project: 'Opened project',
    status_saved_project: 'Saved project',
    status_open_failed: 'Failed to open project',
    status_save_failed: 'Failed to save file',
    status_play_failed: 'Playback failed',
    status_invalid_format: 'Invalid project file format',
    alert_midi_parse_fail: 'Failed to parse MIDI file'
  }
} as const;

export type TranslationKey = keyof (typeof translations)['ja'];

export function t(key: TranslationKey): string {
  const lang = settings.language;
  return translations[lang]?.[key] ?? translations['ja'][key] ?? key;
}
