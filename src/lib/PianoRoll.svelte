<script lang="ts">
  import { app, nextId } from '$lib/store.svelte';
  import { BEATS_PER_BAR, PPQ, isBlack, noteName, tickToMs, type Note } from '$lib/model';

  const PX = 0.2; // px / tick
  const ROW = 20;
  const PMIN = 36;
  const PMAX = 96;
  const KEYW = 70;
  const pitches = Array.from({ length: PMAX - PMIN + 1 }, (_, i) => PMAX - i);

  let canvas: HTMLCanvasElement;
  const width = $derived(app.totalTicks * PX);
  const height = (PMAX - PMIN + 1) * ROW;

  function css(name: string) {
    return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
  }

  function draw() {
    if (!canvas) return;
    const ctx = canvas.getContext('2d')!;
    const ink = css('--ink');
    const W = width;
    ctx.clearRect(0, 0, W, height);
    // 行(黒鍵は薄く塗る)
    for (let p = PMAX; p >= PMIN; p--) {
      const y = (PMAX - p) * ROW;
      ctx.fillStyle = isBlack(p) ? 'rgba(0,0,0,0.12)' : css('--paper');
      ctx.fillRect(0, y, W, ROW);
      ctx.fillStyle = ink;
      ctx.fillRect(0, y + ROW - 1, W, p % 12 === 0 ? 2 : 1);
    }
    // 縦線: 小節=太, 拍=中, グリッド=細
    for (let t = 0; t <= app.totalTicks; t += app.quant) {
      const x = Math.round(t * PX);
      const bar = t % (PPQ * BEATS_PER_BAR) === 0;
      const beat = t % PPQ === 0;
      ctx.fillStyle = ink;
      ctx.globalAlpha = bar ? 1 : beat ? 0.7 : 0.25;
      ctx.fillRect(x, 0, bar ? 4 : beat ? 2 : 1, height);
      ctx.globalAlpha = 1;
    }
    // ノート(非アクティブトラックは薄く)
    for (const tr of app.project.tracks) {
      if (tr.mute) continue;
      const active = tr.id === app.activeTrack.id;
      const col = css(tr.output === 'beep' ? '--c-beep' : '--c-gs');
      ctx.globalAlpha = active ? 1 : 0.45;
      for (const n of tr.notes) {
        const x = n.startTick * PX;
        const y = (PMAX - n.pitch) * ROW;
        const w = Math.max(4, n.durationTick * PX);
        if (active) {
          ctx.fillStyle = ink;
          ctx.fillRect(x + 4, y + 4, w, ROW - 2);
        }
        ctx.fillStyle = col;
        ctx.fillRect(x, y + 1, w, ROW - 2);
        ctx.strokeStyle = ink;
        ctx.lineWidth = 3;
        ctx.strokeRect(x + 1.5, y + 2.5, w - 3, ROW - 5);
      }
      ctx.globalAlpha = 1;
    }
    // 再生位置
    if (app.playheadMs >= 0) {
      const tick = (app.playheadMs * app.project.bpm * PPQ) / 60000;
      ctx.fillStyle = css('--c-play');
      ctx.fillRect(Math.round(tick * PX) - 2, 0, 4, height);
    }
  }

  $effect(() => {
    // 依存: プロジェクト・グリッド・再生位置・アクティブトラック
    void width;
    draw();
  });

  let scroller: HTMLDivElement;
  // 再生位置が表示範囲の外に出たら、画面内に戻るようスクロールして追従する
  $effect(() => {
    if (app.playheadMs < 0 || !scroller) return;
    const x = (((app.playheadMs * app.project.bpm * PPQ) / 60000) * PX) + KEYW;
    const left = scroller.scrollLeft;
    const view = scroller.clientWidth;
    if (x < left + KEYW || x > left + view - 40) {
      scroller.scrollLeft = Math.max(0, x - KEYW - 40);
    }
  });

  type Drag = { note: Note; mode: 'move' | 'resize'; dx: number };
  let drag: Drag | null = null;

  function local(e: PointerEvent) {
    const r = canvas.getBoundingClientRect();
    return { x: e.clientX - r.left, y: e.clientY - r.top };
  }
  function hit(x: number, y: number) {
    const pitch = PMAX - Math.floor(y / ROW);
    return [...app.activeTrack.notes]
      .reverse()
      .find((n) => n.pitch === pitch && x >= n.startTick * PX && x <= (n.startTick + n.durationTick) * PX);
  }
  const snap = (tick: number) => Math.max(0, Math.floor(tick / app.quant) * app.quant);

  function down(e: PointerEvent) {
    if (e.button !== 0) return;
    const { x, y } = local(e);
    const n = hit(x, y);
    if (n) {
      const right = (n.startTick + n.durationTick) * PX;
      drag = { note: n, mode: right - x < 8 ? 'resize' : 'move', dx: x / PX - n.startTick };
    } else {
      const pitch = PMAX - Math.floor(y / ROW);
      if (pitch < PMIN || pitch > PMAX) return;
      const note: Note = { id: nextId(), startTick: snap(x / PX), durationTick: app.quant, pitch, velocity: 100 };
      app.activeTrack.notes.push(note);
      drag = { note: app.activeTrack.notes[app.activeTrack.notes.length - 1], mode: 'resize', dx: 0 };
    }
    canvas.setPointerCapture(e.pointerId);
  }
  function move(e: PointerEvent) {
    if (!drag) return;
    const { x, y } = local(e);
    if (drag.mode === 'move') {
      drag.note.startTick = snap(x / PX - drag.dx);
      drag.note.pitch = Math.min(PMAX, Math.max(PMIN, PMAX - Math.floor(y / ROW)));
    } else {
      const end = Math.ceil(x / PX / app.quant) * app.quant;
      drag.note.durationTick = Math.max(app.quant, end - drag.note.startTick);
    }
  }
  function up() {
    drag = null;
  }
  function del(e: MouseEvent) {
    e.preventDefault();
    const r = canvas.getBoundingClientRect();
    const n = hit(e.clientX - r.left, e.clientY - r.top);
    if (n) app.activeTrack.notes = app.activeTrack.notes.filter((m) => m !== n);
  }
</script>

<div class="scroll" bind:this={scroller}>
  <div class="inner">
    <div class="keys" style="width:{KEYW}px">
      {#each pitches as p (p)}
        <div class="key" class:black={isBlack(p)} style="height:{ROW}px">
          {#if p % 12 === 0}{noteName(p)}{/if}
        </div>
      {/each}
    </div>
    <canvas
      bind:this={canvas}
      {width}
      {height}
      onpointerdown={down}
      onpointermove={move}
      onpointerup={up}
      oncontextmenu={del}
    ></canvas>
  </div>
</div>

<style>
  .scroll {
    overflow: auto;
    border: var(--border);
    box-shadow: var(--shadow);
    background: var(--paper);
    height: 100%;
  }
  .inner {
    display: flex;
    width: max-content;
  }
  .keys {
    position: sticky;
    left: 0;
    z-index: 2;
    flex: none;
    border-right: var(--border);
    background: var(--paper);
  }
  .key {
    border-bottom: 1px solid var(--ink);
    font-family: var(--font-mono);
    font-size: 11px;
    padding-left: 4px;
    line-height: 20px;
  }
  .key.black {
    background: var(--ink);
    width: 70%;
  }
  canvas {
    display: block;
    cursor: crosshair;
  }
</style>
