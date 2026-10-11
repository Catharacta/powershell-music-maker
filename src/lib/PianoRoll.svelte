<script lang="ts">
  import { app, nextId } from '$lib/store.svelte';
  import { BEATS_PER_BAR, PPQ, isBlack, noteName, tickToMs, type Note } from '$lib/model';

  const PX = $derived(app.pxPerTick);
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
    // グリッド線間隔が狭すぎる (6px未満) 場合はグリッド細線を間引く
    const quantStep = Math.max(1, app.quant);
    const drawGridLines = app.quant > 1 && (quantStep * PX >= 6);
    const step = drawGridLines ? quantStep : PPQ;

    for (let t = 0; t <= app.totalTicks; t += step) {
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
        const w = Math.max(6, n.durationTick * PX);
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
    // 依存: プロジェクト・グリッド・再生位置・アクティブトラック・表示倍率
    void width;
    void app.pxPerTick;
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

  // Ctrl + ホイールでの横ズーム
  $effect(() => {
    if (!scroller) return;
    const handleWheel = (e: WheelEvent) => {
      if (e.ctrlKey) {
        e.preventDefault();
        const factor = e.deltaY < 0 ? 1.25 : 0.8;
        const rect = scroller.getBoundingClientRect();
        const mouseX = e.clientX - rect.left + scroller.scrollLeft - KEYW;
        const tick = mouseX / PX;

        app.setPxPerTick(PX * factor);

        requestAnimationFrame(() => {
          const newX = tick * app.pxPerTick;
          scroller.scrollLeft = Math.max(0, newX + KEYW - (e.clientX - rect.left));
        });
      }
    };

    scroller.addEventListener('wheel', handleWheel, { passive: false });
    return () => {
      scroller.removeEventListener('wheel', handleWheel);
    };
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
      .find((n) => {
        if (n.pitch !== pitch) return false;
        const nx = n.startTick * PX;
        const nw = Math.max(6, n.durationTick * PX);
        return x >= nx && x <= nx + nw;
      });
  }
  const snap = (tick: number) => {
    const q = Math.max(1, app.quant);
    return Math.max(0, Math.floor(tick / q) * q);
  };

  function down(e: PointerEvent) {
    if (e.button !== 0) return;
    const { x, y } = local(e);
    const n = hit(x, y);
    if (n) {
      const nx = n.startTick * PX;
      const nw = Math.max(6, n.durationTick * PX);
      const right = nx + nw;
      const resizeThreshold = Math.min(8, Math.max(3, nw * 0.4));
      const isResize = (right - x) <= resizeThreshold;
      drag = {
        note: n,
        mode: isResize ? 'resize' : 'move',
        dx: x / PX - n.startTick
      };
    } else {
      const pitch = PMAX - Math.floor(y / ROW);
      if (pitch < PMIN || pitch > PMAX) return;
      const durationTick = Math.max(1, app.quant);
      const note: Note = {
        id: nextId(),
        startTick: snap(x / PX),
        durationTick,
        pitch,
        velocity: 100
      };
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
      const q = Math.max(1, app.quant);
      const end = Math.ceil((x / PX) / q) * q;
      drag.note.durationTick = Math.max(q, end - drag.note.startTick);
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
