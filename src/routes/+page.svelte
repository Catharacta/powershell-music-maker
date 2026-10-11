<script lang="ts">
  import { app, type TestResult } from '$lib/store.svelte';
  import PianoRoll from '$lib/PianoRoll.svelte';
  import { GM_PROGRAMS } from '$lib/gm';
  import { PPQ } from '$lib/model';
  import { getCurrentWindow } from '@tauri-apps/api/window';
  import { save as dialogSave } from '@tauri-apps/plugin-dialog';
  import { writeTextFile } from '@tauri-apps/plugin-fs';
  import { parseMidi, type ParsedMidiInfo } from '$lib/midi';
  import {
    Music,
    Pencil,
    BoxSelect,
    CheckSquare,
    Copy,
    ClipboardPaste,
    CopyPlus,
    Trash2,
    X
  } from '@lucide/svelte';

  const win = getCurrentWindow();
  let showTest = $state(false);
  let beepPs = $state<TestResult | null>(null);
  let beepPwsh = $state<TestResult | null>(null);
  let gsRes = $state<TestResult | null>(null);
  let devices = $state<string[]>([]);
  let copied = $state(false);

  let midiFileInput: HTMLInputElement | undefined = $state();
  let pendingMidi = $state<ParsedMidiInfo | null>(null);

  function triggerMidiFile() {
    midiFileInput?.click();
  }

  async function handleMidiFileChange(e: Event) {
    const input = e.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;
    try {
      const buffer = await file.arrayBuffer();
      const info = parseMidi(buffer, file.name);
      pendingMidi = info;
    } catch (err) {
      console.error('Failed to parse MIDI:', err);
      alert('MIDIファイルの解析に失敗しました: ' + err);
    } finally {
      input.value = '';
    }
  }

  function applyMidiAsNew() {
    if (!pendingMidi) return;
    app.loadMidiAsNew(pendingMidi);
    pendingMidi = null;
  }

  function applyMidiAppend() {
    if (!pendingMidi) return;
    app.appendMidi(pendingMidi);
    pendingMidi = null;
  }

  async function run(fn: () => Promise<TestResult>, set: (r: TestResult) => void) {
    try {
      set(await fn());
    } catch (e) {
      set({ ok: false, exitCode: null, stdout: '', stderr: String(e), message: '呼び出し失敗' });
    }
  }

  async function copy() {
    await navigator.clipboard.writeText(app.script);
    copied = true;
    setTimeout(() => (copied = false), 1500);
  }

  async function save() {
    try {
      const filePath = await dialogSave({
        filters: [{ name: 'PowerShell Script', extensions: ['ps1'] }],
        defaultPath: 'music.ps1'
      });
      if (filePath) {
        // PowerShell 5.1 でも文字化けしないよう UTF-8 BOM 付きで保存
        await writeTextFile(filePath, '\ufeff' + app.script);
      }
    } catch (e) {
      console.error('Failed to save file:', e);
      alert('ファイルの保存に失敗しました');
    }
  }

  const quants = [
    [PPQ, '1/4'],
    [PPQ / 2, '1/8'],
    [PPQ / 4, '1/16'],
    [PPQ / 8, '1/32'],
    [PPQ / 16, '1/64'],
    [PPQ / 32, '1/128'],
    [1, 'OFF']
  ] as const;
</script>

<div class="app">
  <div class="titlebar" data-tauri-drag-region>
    <span class="logo" data-tauri-drag-region><img src="/app-icon.png" alt="App Icon" class="titlebar-icon-img" data-tauri-drag-region /></span>
    <span class="title" data-tauri-drag-region>PowerShell Music Maker</span>
    <span class="spacer" data-tauri-drag-region></span>
    <button class="wbtn min" onclick={() => win.minimize()} title="Minimize">_</button>
    <button class="wbtn max" onclick={() => win.toggleMaximize()} title="Maximize">□</button>
    <button class="wbtn close" onclick={() => win.close()} title="Close">×</button>
  </div>
  <header>
    <button onclick={() => app.play()} disabled={app.playing}>Play</button>
    <button onclick={() => app.stop()}>Stop</button>
    <button onclick={() => (showTest = true)}>Test</button>
    <label class="bpm"
      >BPM <input type="number" min="30" max="300" bind:value={app.project.bpm} /></label
    >
    <label
      >Grid
      <select bind:value={app.quant}>
        {#each quants as [v, l] (v)}<option value={v}>{l}</option>{/each}
      </select></label
    >
    <label class="zoom-ctrl"
      >Zoom
      <button type="button" class="sq-btn" onclick={() => app.zoomOut()} title="Zoom Out (-)">-</button>
      <button type="button" class="zoom-val" onclick={() => app.zoomReset()} title="Reset Zoom (100%)">
        {Math.round((app.pxPerTick / 0.2) * 100)}%
      </button>
      <button type="button" class="sq-btn" onclick={() => app.zoomIn()} title="Zoom In (+)">+</button>
    </label>
    <label
      >Bars <input type="number" min="1" max="64" bind:value={app.project.bars} style="width:70px" /></label
    >
    <span class="spacer"></span>
    {#if app.timeline.beepConflicts > 0}
      <span class="result ng" title="Beepは同時1音。重なった音は切り詰め/破棄されます"
        >BEEP重なり {app.timeline.beepConflicts}</span
      >
    {/if}
    <input
      type="file"
      accept=".mid,.midi"
      style="display:none"
      bind:this={midiFileInput}
      onchange={handleMidiFileChange}
    />
    <button onclick={triggerMidiFile}>Import MIDI</button>
    <button onclick={() => (app.showScript = !app.showScript)}>Export .ps1</button>
  </header>

  <aside>
    <h2>Tracks</h2>
    {#each app.project.tracks as t (t.id)}
      <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
      <div
        class="track"
        class:active={t.id === app.activeTrack.id}
        style="--tc: var(--c-{t.output})"
        onclick={() => (app.activeTrackId = t.id)}
      >
        {#if t.id === app.activeTrack.id}<span class="editing">EDITING</span>{/if}
        <div class="row">
          <input class="name" bind:value={t.name} />
          <span class="tag {t.output}">{t.output === 'beep' ? 'BEEP' : 'GS'}</span>
        </div>
        <div class="row">
          <button class="sq" class:on={t.mute} onclick={() => (t.mute = !t.mute)} title="Mute">M</button>
          <select bind:value={t.output}>
            <option value="beep">Beep</option>
            <option value="gs">GS Wavetable</option>
          </select>
          <button class="sq" onclick={() => app.removeTrack(t.id)} title="Delete"><X size={14} strokeWidth={2.5} /></button>
        </div>
        {#if t.output === 'gs'}
          <div class="row">
            <select bind:value={t.program}>
              {#each GM_PROGRAMS as n, i (i)}<option value={i}>{i} {n}</option>{/each}
            </select>
            <input type="number" min="0" max="15" bind:value={t.channel} style="width:60px" title="MIDI channel (9=drums)" />
          </div>
        {/if}
        <div class="row">Vol <input type="range" min="0" max="100" bind:value={t.volume} style="flex:1;min-width:0" /></div>
      </div>
    {/each}
    <div class="row">
      <button onclick={() => app.addTrack('beep')}>+ Beep</button>
      <button onclick={() => app.addTrack('gs')}>+ GS</button>
    </div>
  </aside>

  <main>
    <div class="roll-header">
      <h2>Piano Roll — {app.activeTrack.name}</h2>
      <span class="spacer"></span>
      <div class="roll-tools">
        <button
          class="tool-btn"
          class:on={app.toolMode === 'draw'}
          onclick={() => (app.toolMode = 'draw')}
          title="鉛筆ツール (クリックでノート作成、Shift+ドラッグで選択)"
        >
          <Pencil size={13} strokeWidth={2.5} />
          <span>Draw</span>
        </button>
        <button
          class="tool-btn"
          class:on={app.toolMode === 'select'}
          onclick={() => (app.toolMode = 'select')}
          title="選択ツール (ドラッグで範囲選択)"
        >
          <BoxSelect size={13} strokeWidth={2.5} />
          <span>Select</span>
        </button>
        <span class="sep"></span>
        <button class="sq-action" onclick={() => app.selectAll()} title="全選択 (Ctrl+A)">
          <CheckSquare size={12} strokeWidth={2.5} />
          <span>All</span>
        </button>
        <button
          class="sq-action"
          onclick={() => app.copySelected()}
          disabled={app.selectedNoteIds.length === 0}
          title="コピー (Ctrl+C)"
        >
          <Copy size={12} strokeWidth={2.5} />
          <span>Copy</span>
        </button>
        <button
          class="sq-action"
          onclick={() => app.paste()}
          disabled={!app.clipboard || app.clipboard.length === 0}
          title="貼り付け (Ctrl+V)"
        >
          <ClipboardPaste size={12} strokeWidth={2.5} />
          <span>Paste</span>
        </button>
        <button
          class="sq-action"
          onclick={() => app.duplicateSelected()}
          disabled={app.selectedNoteIds.length === 0}
          title="複製 (Ctrl+D)"
        >
          <CopyPlus size={12} strokeWidth={2.5} />
          <span>Dup</span>
        </button>
        <button
          class="sq-action del"
          onclick={() => app.deleteSelected()}
          disabled={app.selectedNoteIds.length === 0}
          title="削除 (Del)"
        >
          <Trash2 size={12} strokeWidth={2.5} />
          <span>Del</span>
        </button>
        {#if app.selectedNoteIds.length > 0}
          <span class="selected-badge">{app.selectedNoteIds.length} sel</span>
        {/if}
      </div>
    </div>
    <div class="hint">
      Shift+ドラッグ: 範囲選択 | ドラッグ: 移動 | Alt+ドラッグ: 複製移動 | 矢印キー: 微移動 | 右クリック: 削除 | Ctrl+C/V/D: コピペ・複製
    </div>
    <div class="roll"><PianoRoll /></div>
    {#if app.status}<div class="result ng">{app.status}</div>{/if}
  </main>

  {#if app.showScript}
    <div class="modal">
      <div class="panel">
        <div class="row">
          <h2>music.ps1</h2>
          <span class="spacer"></span>
          <label class="check-opt">
            <input type="checkbox" bind:checked={app.visualizer} />
            ターミナル演出
          </label>
          <button onclick={copy}>{copied ? 'Copied!' : 'Copy'}</button>
          <button onclick={save}>Save .ps1</button>
          <button onclick={() => (app.showScript = false)}>Close</button>
        </div>
        <textarea readonly value={app.script}></textarea>
      </div>
    </div>
  {/if}

  {#if pendingMidi}
    <div class="modal">
      <div class="panel midipanel">
        <div class="row">
          <h2>MIDI Import Preview</h2>
          <span class="spacer"></span>
          <button onclick={() => (pendingMidi = null)}>Cancel</button>
        </div>
        <div class="midi-meta">
          <div><strong>Name:</strong> {pendingMidi.name}</div>
          <div><strong>Tempo:</strong> {pendingMidi.bpm} BPM</div>
          <div><strong>Length:</strong> {pendingMidi.bars} Bars</div>
          <div><strong>Total Notes:</strong> {pendingMidi.totalNotes}</div>
        </div>
        <h3>Tracks ({pendingMidi.parsedTracks.length})</h3>
        <div class="midi-track-list">
          {#each pendingMidi.parsedTracks as t, i (i)}
            <div class="midi-track-item">
              <span class="tag gs">GS</span>
              <span class="tname">{t.name}</span>
              <span class="tinfo">Ch {t.channel} / Prog {t.program} / {t.notes.length} notes</span>
            </div>
          {/each}
        </div>
        <div class="row" style="margin-top:auto;padding-top:10px;border-top:var(--border);">
          <span class="spacer"></span>
          <button class="action-btn" onclick={applyMidiAsNew}>新規プロジェクトとして開く</button>
          <button class="action-btn" onclick={applyMidiAppend}>現在のプロジェクトに追加</button>
          <button onclick={() => (pendingMidi = null)}>キャンセル</button>
        </div>
      </div>
    </div>
  {/if}

  {#if showTest}
    <div class="modal">
      <div class="panel testpanel">
        <div class="row">
          <h2>Test</h2>
          <span class="spacer"></span>
          <button onclick={() => (showTest = false)}>Close</button>
        </div>
        <div class="tests">
          <div class="row">
            <button onclick={() => run(() => app.testBeep('powershell'), (r) => (beepPs = r))}>Beep (PS 5.1)</button>
            {#if beepPs}<span class="result" class:ok={beepPs.ok} class:ng={!beepPs.ok}>{beepPs.ok ? 'OK' : 'NG'}</span>{/if}
          </div>
          {#if beepPs}<div class="msg">{beepPs.message}{beepPs.stderr ? `\n${beepPs.stderr}` : ''}</div>{/if}
          <div class="row">
            <button onclick={() => run(() => app.testBeep('pwsh'), (r) => (beepPwsh = r))}>Beep (pwsh 7)</button>
            {#if beepPwsh}<span class="result" class:ok={beepPwsh.ok} class:ng={!beepPwsh.ok}>{beepPwsh.ok ? 'OK' : 'NG'}</span>{/if}
          </div>
          {#if beepPwsh}<div class="msg">{beepPwsh.message}{beepPwsh.stderr ? `\n${beepPwsh.stderr}` : ''}</div>{/if}
          <div class="row">
            <button onclick={() => run(() => app.testGs(), (r) => (gsRes = r))}>GS test</button>
            {#if gsRes}<span class="result" class:ok={gsRes.ok} class:ng={!gsRes.ok}>{gsRes.ok ? 'OK' : 'NG'}</span>{/if}
          </div>
          {#if gsRes}<div class="msg">{gsRes.message}</div>{/if}
          <div class="row">
            <button onclick={async () => (devices = await app.devices())}>MIDI devices</button>
          </div>
          {#each devices as d (d)}<div class="msg">{d}</div>{/each}
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  .app {
    display: grid;
    grid-template-columns: 300px 1fr;
    grid-template-rows: auto auto 1fr;
    height: 100vh;
  }
  header {
    grid-column: 1 / 3;
    display: flex;
    gap: 14px;
    align-items: center;
    padding: 12px 16px;
    border-bottom: var(--border);
    flex-wrap: wrap;
  }
  header label {
    font-family: var(--font-head);
    text-transform: uppercase;
    display: flex;
    gap: 6px;
    align-items: center;
  }
  .bpm input {
    width: 90px;
    font-size: 18px;
  }
  .zoom-ctrl {
    display: inline-flex;
    align-items: center;
    gap: 4px;
  }
  .sq-btn {
    width: 32px;
    height: 32px;
    padding: 0;
    display: grid;
    place-items: center;
    font-family: var(--font-head);
    font-size: 16px;
    box-shadow: 2px 2px 0 var(--ink);
  }
  .sq-btn:active {
    transform: translate(2px, 2px);
    box-shadow: none;
  }
  .zoom-val {
    min-width: 54px;
    height: 32px;
    padding: 0 4px;
    font-family: var(--font-mono);
    font-size: 12px;
    text-align: center;
    display: grid;
    place-items: center;
    box-shadow: 2px 2px 0 var(--ink);
    cursor: pointer;
  }
  .zoom-val:active {
    transform: translate(2px, 2px);
    box-shadow: none;
  }
  .spacer {
    flex: 1;
  }
  aside {
    border-right: var(--border);
    padding: 16px 22px 16px 16px;
    overflow: auto;
    display: flex;
    flex-direction: column;
    gap: 14px;
  }
  .track {
    --tc: var(--c-beep);
    position: relative;
    border: var(--border);
    border-left-width: 12px;
    border-left-color: var(--tc);
    background: var(--paper);
    padding: 8px;
    display: flex;
    flex-direction: column;
    gap: 6px;
    min-width: 0;
    cursor: pointer;
  }
  /* 選択中: トラック色で塗り、浮かせて大きな影 + EDITINGラベル */
  .track.active {
    background: color-mix(in srgb, var(--tc) 45%, white);
    border-left-width: 20px;
    transform: translate(-4px, -4px);
    box-shadow: 9px 9px 0 var(--ink);
    padding-top: 18px;
  }
  .editing {
    position: absolute;
    top: -3px;
    right: -3px;
    background: var(--ink);
    color: #fff;
    font-family: var(--font-head);
    font-size: 10px;
    padding: 2px 8px;
    letter-spacing: 0.05em;
  }
  .row {
    display: flex;
    gap: 8px;
    align-items: center;
    min-width: 0;
  }
  .row select {
    flex: 1;
    min-width: 0;
  }
  .row button.sq {
    flex: none;
    width: 34px;
    height: 34px;
    padding: 0;
    display: grid;
    place-items: center;
    box-shadow: 3px 3px 0 var(--ink);
  }
  .row button.sq:active {
    transform: translate(3px, 3px);
  }
  .titlebar {
    grid-column: 1 / 3;
    display: flex;
    align-items: stretch;
    background: var(--ink);
    color: #fff;
    height: 38px;
    user-select: none;
  }
  .logo {
    background: var(--c-beep);
    color: var(--ink);
    font-family: var(--font-head);
    width: 46px;
    display: grid;
    place-items: center;
    font-size: 20px;
    border-right: var(--border);
  }
  .titlebar-icon-img {
    width: 26px;
    height: 26px;
    object-fit: contain;
    pointer-events: none;
  }
  .title {
    font-family: var(--font-head);
    text-transform: uppercase;
    letter-spacing: 0.08em;
    align-self: center;
    padding-left: 14px;
  }
  .wbtn {
    width: 52px;
    height: auto;
    padding: 0;
    border: 0;
    border-left: var(--border);
    box-shadow: none;
    background: var(--paper);
    font-size: 18px;
    line-height: 1;
  }
  .wbtn:active {
    transform: none;
  }
  .wbtn.min:hover {
    background: var(--c-beep);
  }
  .wbtn.max:hover {
    background: var(--c-gs);
  }
  .wbtn.close {
    background: var(--c-ng);
  }
  .wbtn.close:hover {
    background: var(--c-accent);
  }
  .testpanel {
    height: auto;
    width: min(520px, 92vw);
  }
  .name {
    flex: 1;
    min-width: 0;
    font-family: var(--font-head);
  }
  .tests {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .msg {
    font-family: var(--font-mono);
    font-size: 11px;
    white-space: pre-wrap;
  }
  main {
    padding: 12px 16px;
    display: flex;
    flex-direction: column;
    gap: 8px;
    min-height: 0;
    min-width: 0;
  }
  .roll-header {
    display: flex;
    align-items: center;
    gap: 12px;
    flex-wrap: wrap;
  }
  .roll-tools {
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .tool-btn {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    font-size: 11px;
    padding: 3px 8px;
    box-shadow: 2px 2px 0 var(--ink);
  }
  .tool-btn:active {
    transform: translate(2px, 2px);
    box-shadow: none;
  }
  .tool-btn.on {
    background: var(--c-accent);
  }
  .sep {
    width: 2px;
    height: 20px;
    background: var(--ink);
    margin: 0 2px;
  }
  .sq-action {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    font-size: 11px;
    padding: 3px 8px;
    box-shadow: 2px 2px 0 var(--ink);
  }
  .sq-action:active {
    transform: translate(2px, 2px);
    box-shadow: none;
  }
  .sq-action:disabled {
    opacity: 0.4;
    cursor: not-allowed;
    box-shadow: none;
    transform: none;
  }
  .sq-action.del:not(:disabled):hover {
    background: var(--c-ng);
  }
  .selected-badge {
    border: 2px solid var(--ink);
    background: var(--c-beep);
    padding: 2px 6px;
    font-family: var(--font-mono);
    font-size: 11px;
    box-shadow: 2px 2px 0 var(--ink);
  }
  .hint {
    font-size: 12px;
  }
  .roll {
    flex: 1;
    min-height: 0;
    padding-right: 6px;
    padding-bottom: 6px;
  }
  .modal {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.5);
    display: grid;
    place-items: center;
    z-index: 10;
  }
  .panel {
    background: var(--bg);
    border: var(--border);
    box-shadow: 10px 10px 0 var(--ink);
    width: min(900px, 92vw);
    height: 80vh;
    padding: 14px;
    display: flex;
    flex-direction: column;
    gap: 10px;
  }
  .midipanel {
    height: min(600px, 90vh);
    width: min(640px, 94vw);
  }
  .midi-meta {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 8px;
    padding: 10px;
    background: var(--paper);
    border: var(--border);
    font-size: 13px;
  }
  .midi-track-list {
    flex: 1;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: 6px;
    padding: 4px;
    border: var(--border);
    background: var(--paper);
  }
  .midi-track-item {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 6px 8px;
    border-bottom: 1px dashed var(--ink);
    font-size: 13px;
  }
  .midi-track-item:last-child {
    border-bottom: none;
  }
  .midi-track-item .tname {
    font-family: var(--font-head);
    flex: 1;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .midi-track-item .tinfo {
    font-family: var(--font-mono);
    font-size: 11px;
    color: #444;
  }
  .action-btn {
    background: var(--c-gs);
  }
  .action-btn:hover {
    background: var(--c-beep);
  }
  textarea {
    flex: 1;
    font-family: var(--font-mono);
    font-size: 12px;
    border: var(--border);
    background: var(--paper);
    resize: none;
  }
  .check-opt {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    font-size: 12px;
    font-family: var(--font-head);
    user-select: none;
    cursor: pointer;
    background: var(--paper);
    padding: 6px 10px;
    border: var(--border);
    box-shadow: 2px 2px 0 var(--ink);
  }
  .check-opt input {
    cursor: pointer;
    width: 15px;
    height: 15px;
    accent-color: var(--c-beep);
  }
</style>
