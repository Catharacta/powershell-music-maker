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
    X,
    FilePlus,
    FolderOpen,
    Save,
    Upload,
    FileCode,
    Settings,
    AlertTriangle,
    Wand2
  } from '@lucide/svelte';
  import SettingsModal from '$lib/SettingsModal.svelte';
  import { t } from '$lib/i18n';
  import { tooltip } from '$lib/tooltip';
  import Select from '$lib/Select.svelte';

  const win = getCurrentWindow();
  let showTest = $state(false);
  let showSettings = $state(false);
  let beepPs = $state<TestResult | null>(null);
  let beepPwsh = $state<TestResult | null>(null);
  let gsRes = $state<TestResult | null>(null);
  let devices = $state<string[]>([]);
  let copied = $state(false);

  let midiFileInput: HTMLInputElement | undefined = $state();
  let pendingMidi = $state<ParsedMidiInfo | null>(null);

  const hasBeepTrack = $derived(app.project.tracks.some((t) => t.output === 'beep'));
  const activeTrackBeepIssuesCount = $derived.by(() => {
    if (app.activeTrack.output !== 'beep') return 0;
    let count = 0;
    for (const n of app.activeTrack.notes) {
      if (app.beepIssues.has(n.id)) count++;
    }
    return count;
  });
  const totalBeepIssuesCount = $derived(app.beepIssues.size);

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
      alert(`${t('alert_midi_parse_fail')}: ${err}`);
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
      set({ ok: false, exitCode: null, stdout: '', stderr: String(e), message: t('test_call_failed') });
    }
  }

  function formatBeepMsg(r: TestResult, shell: string): string {
    if (r.ok) {
      return t('test_beep_ok', { shell });
    }
    const err = r.stderr ? `\n${r.stderr}` : '';
    if (r.exitCode === null) {
      return `${t('test_beep_launch_fail', { shell })}${err}`;
    }
    return `${t('test_beep_ng', { shell })}${err}`;
  }

  function formatGsMsg(r: TestResult): string {
    if (r.ok) {
      return t('test_gs_ok');
    }
    if (r.message && (r.message.includes('not found') || r.message.includes('見つかりません'))) {
      return t('test_gs_not_found');
    }
    return r.message || t('test_call_failed');
  }

  async function copy() {
    await navigator.clipboard.writeText(app.script);
    copied = true;
    setTimeout(() => (copied = false), 1500);
  }

  async function save() {
    try {
      const defaultName = (app.scriptTitle || 'music') + '.ps1';
      const filePath = await dialogSave({
        filters: [{ name: 'PowerShell Script', extensions: ['ps1'] }],
        defaultPath: defaultName
      });
      if (filePath) {
        // PowerShell 5.1 でも文字化けしないよう UTF-8 BOM 付きで保存
        await writeTextFile(filePath, '\ufeff' + app.script);
      }
    } catch (e) {
      console.error('Failed to save file:', e);
      alert(t('status_save_failed'));
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

  const quantSelectOptions = $derived(
    quants.map(([v, l]) => ({ value: v, label: l }))
  );

  const noteLengths = [
    [PPQ * 4, '1/1'],
    [PPQ * 2, '1/2'],
    [PPQ, '1/4'],
    [PPQ / 2, '1/8'],
    [PPQ / 4, '1/16'],
    [PPQ / 8, '1/32'],
    [PPQ / 16, '1/64']
  ] as const;

  const noteLengthSelectOptions = $derived([
    { value: 'grid', label: t('note_len_grid') },
    ...noteLengths.map(([v, l]) => ({ value: v, label: l }))
  ]);

  const gmSelectOptions = GM_PROGRAMS.map((n, i) => ({
    value: i,
    label: `${i} ${n}`
  }));

  const outputSelectOptions = [
    { value: 'beep', label: 'Beep' },
    { value: 'gs', label: 'GS Wavetable' }
  ];

  $effect(() => {
    const handleGlobalKey = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement | null;
      if (target && (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.tagName === 'SELECT')) {
        return;
      }

      if (e.ctrlKey || e.metaKey) {
        if ((e.key === 's' || e.key === 'S') && e.shiftKey) {
          e.preventDefault();
          app.saveProjectAs();
        } else if (e.key === 's' || e.key === 'S') {
          e.preventDefault();
          app.saveProject();
        } else if (e.key === 'o' || e.key === 'O') {
          e.preventDefault();
          app.openProjectDialog();
        } else if (e.key === 'n' || e.key === 'N') {
          e.preventDefault();
          app.newProject();
        }
      }
    };

    window.addEventListener('keydown', handleGlobalKey);
    return () => {
      window.removeEventListener('keydown', handleGlobalKey);
    };
  });
</script>

<div class="app">
  <div class="titlebar" data-tauri-drag-region>
    <span class="logo" data-tauri-drag-region><img src="/app-icon.png" alt="App Icon" class="titlebar-icon-img" data-tauri-drag-region /></span>
    <span class="title" data-tauri-drag-region>
      PowerShell Music Maker
      <span class="project-tag" data-tauri-drag-region>— {app.projectName}.psmm</span>
    </span>
    <span class="spacer" data-tauri-drag-region></span>
    <button class="wbtn min" onclick={() => win.minimize()} use:tooltip={'Minimize'}>_</button>
    <button class="wbtn max" onclick={() => win.toggleMaximize()} use:tooltip={'Maximize'}>□</button>
    <button class="wbtn close" onclick={() => win.close()} use:tooltip={'Close'}>×</button>
  </div>
  <header>
    <div class="header-row">
      <div class="header-group">
        <button class="icon-text-btn" onclick={() => app.newProject()} use:tooltip={t('tooltip_new')}>
          <FilePlus size={14} strokeWidth={2.5} />
          <span>{t('file_new')}</span>
        </button>
        <button class="icon-text-btn" onclick={() => app.openProjectDialog()} use:tooltip={t('tooltip_open')}>
          <FolderOpen size={14} strokeWidth={2.5} />
          <span>{t('file_open')}</span>
        </button>
        <button class="icon-text-btn" onclick={() => app.saveProject()} use:tooltip={t('tooltip_save')}>
          <Save size={14} strokeWidth={2.5} />
          <span>{t('file_save')}</span>
        </button>
        <button class="icon-text-btn" onclick={() => app.saveProjectAs()} use:tooltip={t('tooltip_save_as')}>
          <Save size={14} strokeWidth={2.5} />
          <span>{t('file_save_as')}</span>
        </button>
      </div>
      <span class="header-sep"></span>
      <button onclick={() => app.play()} disabled={app.playing}>{t('play')}</button>
      <button onclick={() => app.stop()}>{t('stop')}</button>
      <button onclick={() => (showTest = true)}>{t('test_env')}</button>

      <span class="spacer"></span>

      <input
        type="file"
        accept=".mid,.midi"
        style="display:none"
        bind:this={midiFileInput}
        onchange={handleMidiFileChange}
      />
      <button class="icon-text-btn" onclick={triggerMidiFile} use:tooltip={t('tooltip_import_midi')}>
        <Upload size={14} strokeWidth={2.5} />
        <span>{t('file_import_midi')}</span>
      </button>
      <button
        class="icon-text-btn export-btn"
        onclick={() => (app.showScript = !app.showScript)}
        use:tooltip={t('tooltip_export_script')}
      >
        <FileCode size={14} strokeWidth={2.5} />
        <span>{t('export_script')}</span>
      </button>
      <button
        class="icon-text-btn settings-btn"
        onclick={() => (showSettings = true)}
        use:tooltip={t('settings')}
      >
        <Settings size={14} strokeWidth={2.5} />
        <span>{t('settings')}</span>
      </button>
    </div>

    <div class="header-row sub-row">
      <label class="bpm"
        >{t('bpm')} <input type="number" min="30" max="300" bind:value={app.project.bpm} /></label
      >
      <label
        >{t('grid')}
        <Select
          bind:value={app.quant}
          options={quantSelectOptions}
          style="min-width: 90px;"
        />
      </label>
      <label
        >{t('note_length')}
        <Select
          value={app.noteLengthChoice}
          options={noteLengthSelectOptions}
          onchange={(val) => {
            app.setNoteLength(val === 'grid' ? 'grid' : Number(val));
          }}
          style="min-width: 100px;"
        />
      </label>
      <span class="header-sep"></span>
      <label
        >{t('bars')} <input type="number" min="1" max="64" bind:value={app.project.bars} style="width:70px" /></label
      >
      <label class="zoom-ctrl"
        >{t('zoom')}
        <button type="button" class="sq-btn" onclick={() => app.zoomOut()} use:tooltip={'Zoom Out (-)'}>-</button>
        <button type="button" class="zoom-val" onclick={() => app.zoomReset()} use:tooltip={'Reset Zoom (100%)'}>
          {Math.round((app.pxPerTick / 0.2) * 100)}%
        </button>
        <button type="button" class="sq-btn" onclick={() => app.zoomIn()} use:tooltip={'Zoom In (+)'}>+</button>
      </label>

      <span class="spacer"></span>

      {#if app.timeline.beepConflicts > 0 || totalBeepIssuesCount > 0}
        <button
          type="button"
          class="result ng conflict-badge-btn"
          onclick={() => app.optimizeAllBeepTracks()}
          use:tooltip={t('beep_conflict_tooltip')}
        >
          <AlertTriangle size={12} strokeWidth={2.5} />
          <span>{t('beep_conflicts')} {totalBeepIssuesCount > 0 ? totalBeepIssuesCount : app.timeline.beepConflicts}</span>
          <span class="badge-action">({t('beep_optimize_btn')})</span>
        </button>
      {/if}
    </div>
  </header>

  <aside>
    <h2>{t('track_title')}</h2>
    {#each app.project.tracks as tr (tr.id)}
      <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
      <div
        class="track"
        class:active={tr.id === app.activeTrack.id}
        style="--tc: var(--c-{tr.output})"
        onclick={() => (app.activeTrackId = tr.id)}
      >
        {#if tr.id === app.activeTrack.id}<span class="editing">{t('editing_badge')}</span>{/if}
        <div class="row">
          <input class="name" bind:value={tr.name} />
          <span class="tag {tr.output}">{tr.output === 'beep' ? 'BEEP' : 'GS'}</span>
        </div>
        <div class="row">
          <button class="sq" class:on={tr.mute} onclick={() => (tr.mute = !tr.mute)} use:tooltip={t('tooltip_mute')}>M</button>
          <div style="flex: 1; min-width: 0;">
            <Select
              bind:value={tr.output}
              options={outputSelectOptions}
              style="width: 100%;"
            />
          </div>
          <button class="sq" onclick={() => app.removeTrack(tr.id)} use:tooltip={t('action_delete')}><X size={14} strokeWidth={2.5} /></button>
        </div>
        {#if tr.output === 'gs'}
          <div class="row">
            <div style="flex: 1; min-width: 0;">
              <Select
                bind:value={tr.program}
                options={gmSelectOptions}
                style="width: 100%;"
              />
            </div>
            <input type="number" min="0" max="15" bind:value={tr.channel} style="width:60px" use:tooltip={t('tooltip_channel')} />
          </div>
        {/if}
        <div class="row">Vol <input type="range" min="0" max="100" bind:value={tr.volume} style="flex:1;min-width:0" /></div>
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
          use:tooltip={t('tooltip_draw')}
        >
          <Pencil size={13} strokeWidth={2.5} />
          <span>{t('tool_draw')}</span>
        </button>
        <button
          class="tool-btn"
          class:on={app.toolMode === 'select'}
          onclick={() => (app.toolMode = 'select')}
          use:tooltip={t('tooltip_select')}
        >
          <BoxSelect size={13} strokeWidth={2.5} />
          <span>{t('tool_select')}</span>
        </button>
        <span class="sep"></span>
        <button class="sq-action" onclick={() => app.selectAll()} use:tooltip={t('tooltip_select_all')}>
          <CheckSquare size={12} strokeWidth={2.5} />
          <span>{t('action_select_all')}</span>
        </button>
        <button
          class="sq-action"
          onclick={() => app.copySelected()}
          disabled={app.selectedNoteIds.length === 0}
          use:tooltip={t('tooltip_copy')}
        >
          <Copy size={12} strokeWidth={2.5} />
          <span>{t('action_copy')}</span>
        </button>
        <button
          class="sq-action"
          onclick={() => app.paste()}
          disabled={!app.clipboard || app.clipboard.length === 0}
          use:tooltip={t('tooltip_paste')}
        >
          <ClipboardPaste size={12} strokeWidth={2.5} />
          <span>{t('action_paste')}</span>
        </button>
        <button
          class="sq-action"
          onclick={() => app.duplicateSelected()}
          disabled={app.selectedNoteIds.length === 0}
          use:tooltip={t('tooltip_duplicate')}
        >
          <CopyPlus size={12} strokeWidth={2.5} />
          <span>{t('action_duplicate')}</span>
        </button>
        <button
          class="sq-action del"
          onclick={() => app.deleteSelected()}
          disabled={app.selectedNoteIds.length === 0}
          use:tooltip={t('tooltip_delete')}
        >
          <Trash2 size={12} strokeWidth={2.5} />
          <span>{t('action_delete')}</span>
        </button>
        {#if app.selectedNoteIds.length > 0}
          <span class="selected-badge">{app.selectedNoteIds.length} sel</span>
        {/if}
        {#if hasBeepTrack}
          <span class="sep"></span>
          <button
            class="sq-action beep-opt-btn"
            class:warn={activeTrackBeepIssuesCount > 0}
            onclick={() => app.optimizeBeepTrack(app.activeTrack.id)}
            disabled={app.activeTrack.output !== 'beep' || app.activeTrack.notes.length === 0}
            use:tooltip={t('beep_optimize_track')}
          >
            {#if activeTrackBeepIssuesCount > 0}
              <AlertTriangle size={12} strokeWidth={2.5} class="warn-icon" />
            {:else}
              <Wand2 size={12} strokeWidth={2.5} />
            {/if}
            <span>{t('beep_optimize_btn')}</span>
            {#if activeTrackBeepIssuesCount > 0}
              <span class="issue-badge">{activeTrackBeepIssuesCount}</span>
            {/if}
          </button>
          <button
            class="sq-action"
            onclick={() => app.optimizeAllBeepTracks()}
            use:tooltip={t('beep_optimize_all')}
          >
            <span>{t('beep_optimize_all')}</span>
          </button>
        {/if}
      </div>
    </div>
    <div class="hint">
      {t('piano_roll_hint')}
    </div>
    <div class="roll"><PianoRoll /></div>
    {#if app.status}<div class="result ng">{app.status}</div>{/if}
  </main>

  {#if app.showScript}
    <div class="modal">
      <div class="panel scriptpanel">
        <div class="row script-header">
          <h2>music.ps1</h2>
          <span class="spacer"></span>
          <button class="sq-btn" onclick={() => (app.showScript = false)} use:tooltip={t('script_modal_close')}>×</button>
        </div>
        <div class="row script-toolbar">
          <label class="title-opt">
            <span>{t('script_modal_song_title')}</span>
            <input
              type="text"
              value={app.scriptTitle}
              oninput={(e) => (app.customTitle = e.currentTarget.value)}
              placeholder="Title"
            />
          </label>
          <label class="title-opt">
            <span>{t('script_modal_artist')}</span>
            <input
              type="text"
              bind:value={app.scriptArtist}
              placeholder="Artist"
            />
          </label>
          <label class="check-opt">
            <input type="checkbox" bind:checked={app.visualizer} />
            {t('settings_visualizer')}
          </label>
          <span class="spacer"></span>
          <button onclick={copy}>{copied ? t('script_modal_copied') : t('script_modal_copy')}</button>
          <button class="action-btn" onclick={save}>{t('script_modal_save')}</button>
        </div>
        <textarea readonly value={app.script}></textarea>
      </div>
    </div>
  {/if}

  {#if pendingMidi}
    <div class="modal">
      <div class="panel midipanel">
        <div class="row">
          <h2>{t('midi_import_title')}</h2>
          <span class="spacer"></span>
          <button onclick={() => (pendingMidi = null)}>{t('cancel')}</button>
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
          <button class="action-btn" onclick={applyMidiAsNew}>{t('midi_import_new')}</button>
          <button class="action-btn" onclick={applyMidiAppend}>{t('midi_import_append')}</button>
          <button onclick={() => (pendingMidi = null)}>{t('cancel')}</button>
        </div>
      </div>
    </div>
  {/if}

  {#if showTest}
    <div class="modal">
      <div class="panel testpanel">
        <div class="row">
          <h2>{t('test_modal_title')}</h2>
          <span class="spacer"></span>
          <button onclick={() => (showTest = false)}>{t('settings_close')}</button>
        </div>
        <div class="tests">
          <div class="row">
            <button onclick={() => run(() => app.testBeep('powershell'), (r) => (beepPs = r))}>{t('test_beep_ps5')}</button>
            {#if beepPs}<span class="result" class:ok={beepPs.ok} class:ng={!beepPs.ok}>{beepPs.ok ? 'OK' : 'NG'}</span>{/if}
          </div>
          {#if beepPs}<div class="msg">{formatBeepMsg(beepPs, 'powershell')}</div>{/if}
          <div class="row">
            <button onclick={() => run(() => app.testBeep('pwsh'), (r) => (beepPwsh = r))}>{t('test_beep_pwsh')}</button>
            {#if beepPwsh}<span class="result" class:ok={beepPwsh.ok} class:ng={!beepPwsh.ok}>{beepPwsh.ok ? 'OK' : 'NG'}</span>{/if}
          </div>
          {#if beepPwsh}<div class="msg">{formatBeepMsg(beepPwsh, 'pwsh')}</div>{/if}
          <div class="row">
            <button onclick={() => run(() => app.testGs(), (r) => (gsRes = r))}>{t('test_gs_title')}</button>
            {#if gsRes}<span class="result" class:ok={gsRes.ok} class:ng={!gsRes.ok}>{gsRes.ok ? 'OK' : 'NG'}</span>{/if}
          </div>
          {#if gsRes}<div class="msg">{formatGsMsg(gsRes)}</div>{/if}
          <div class="row">
            <button onclick={async () => (devices = await app.devices())}>{t('test_midi_devices')}</button>
          </div>
          {#each devices as d (d)}<div class="msg">{d}</div>{/each}
        </div>
      </div>
    </div>
  {/if}

  <SettingsModal open={showSettings} onclose={() => (showSettings = false)} />
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
    flex-direction: column;
    gap: 8px;
    padding: 10px 16px;
    border-bottom: var(--border);
    background: var(--paper);
  }
  .header-row {
    display: flex;
    gap: 12px;
    align-items: center;
    width: 100%;
  }
  .export-btn {
    background: var(--c-beep);
    font-weight: bold;
  }
  .header-group {
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .icon-text-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 6px 10px;
    font-size: 13px;
  }
  .header-sep {
    width: 2px;
    height: 24px;
    background: var(--ink);
    margin: 0 4px;
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
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .project-tag {
    font-family: var(--font-mono);
    font-size: 13px;
    font-weight: normal;
    color: var(--c-beep);
    letter-spacing: normal;
    text-transform: none;
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
  .tests .row button {
    width: 200px;
    text-align: center;
    flex-shrink: 0;
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
  .conflict-badge-btn {
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    gap: 4px;
    background: #fff0f3;
    border: 2px solid var(--ink);
    box-shadow: 2px 2px 0 var(--ink);
    font-weight: 700;
  }
  .conflict-badge-btn:hover {
    background: #ffe3e8;
  }
  .conflict-badge-btn:active {
    transform: translate(2px, 2px);
    box-shadow: none;
  }
  .badge-action {
    font-size: 10px;
    text-decoration: underline;
    opacity: 0.85;
    margin-left: 2px;
  }
  .beep-opt-btn.warn {
    background: #fff0f3;
  }
  :global(.warn-icon) {
    color: #ff2a4b;
    flex-shrink: 0;
  }
  .issue-badge {
    background: #ff2a4b;
    color: #fff;
    font-size: 10px;
    font-family: var(--font-mono);
    font-weight: 700;
    padding: 0 4px;
    border: 1px solid var(--ink);
    margin-left: 2px;
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
  .scriptpanel {
    width: min(1000px, 94vw);
    height: 84vh;
  }
  .script-header {
    border-bottom: 2px solid var(--ink);
    padding-bottom: 8px;
  }
  .script-toolbar {
    flex-wrap: wrap;
    gap: 8px;
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
  .title-opt {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    font-size: 12px;
    font-family: var(--font-head);
    background: var(--paper);
    padding: 4px 10px;
    border: var(--border);
    box-shadow: 2px 2px 0 var(--ink);
  }
  .title-opt input {
    font-family: var(--font-mono);
    font-size: 12px;
    font-weight: bold;
    padding: 3px 6px;
    border: 2px solid var(--ink);
    background: #ffffff;
    width: 140px;
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
  .settings-btn {
    background: #ffffff;
  }
  .settings-btn:hover {
    background: var(--c-beep);
  }
</style>
