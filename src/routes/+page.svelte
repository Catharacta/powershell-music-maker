<script lang="ts">
  import { app, type TestResult } from '$lib/store.svelte';
  import PianoRoll from '$lib/PianoRoll.svelte';
  import { GM_PROGRAMS } from '$lib/gm';
  import { PPQ } from '$lib/model';
  import { getCurrentWindow } from '@tauri-apps/api/window';
  import { save as dialogSave } from '@tauri-apps/plugin-dialog';
  import { writeTextFile } from '@tauri-apps/plugin-fs';

  const win = getCurrentWindow();
  let showTest = $state(false);
  let beepPs = $state<TestResult | null>(null);
  let beepPwsh = $state<TestResult | null>(null);
  let gsRes = $state<TestResult | null>(null);
  let devices = $state<string[]>([]);
  let copied = $state(false);

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
    [PPQ / 8, '1/32']
  ] as const;
</script>

<div class="app">
  <div class="titlebar" data-tauri-drag-region>
    <span class="logo" data-tauri-drag-region>♪</span>
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
    <label
      >Bars <input type="number" min="1" max="64" bind:value={app.project.bars} style="width:70px" /></label
    >
    <span class="spacer"></span>
    {#if app.timeline.beepConflicts > 0}
      <span class="result ng" title="Beepは同時1音。重なった音は切り詰め/破棄されます"
        >BEEP重なり {app.timeline.beepConflicts}</span
      >
    {/if}
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
        {#if t.id === app.activeTrack.id}<span class="editing">▶ EDITING</span>{/if}
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
          <button class="sq" onclick={() => app.removeTrack(t.id)} title="Delete">×</button>
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
    <h2>Piano Roll — {app.activeTrack.name}</h2>
    <div class="hint">クリック:追加 / ドラッグ:移動 / 右端ドラッグ:長さ / 右クリック:削除</div>
    <div class="roll"><PianoRoll /></div>
    {#if app.status}<div class="result ng">{app.status}</div>{/if}
  </main>

  {#if app.showScript}
    <div class="modal">
      <div class="panel">
        <div class="row">
          <h2>music.ps1</h2>
          <span class="spacer"></span>
          <button onclick={copy}>{copied ? 'Copied!' : 'Copy'}</button>
          <button onclick={save}>Save .ps1</button>
          <button onclick={() => (app.showScript = false)}>Close</button>
        </div>
        <textarea readonly value={app.script}></textarea>
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
  textarea {
    flex: 1;
    font-family: var(--font-mono);
    font-size: 12px;
    border: var(--border);
    background: var(--paper);
    resize: none;
  }
</style>
