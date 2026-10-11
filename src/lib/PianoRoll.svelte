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
        const isSelected = active && app.isNoteSelected(n.id);
        const x = n.startTick * PX;
        const y = (PMAX - n.pitch) * ROW;
        const w = Math.max(6, n.durationTick * PX);

        if (active) {
          ctx.fillStyle = ink;
          if (isSelected) {
            // 選択時はハードシャドウを6pxに拡張
            ctx.fillRect(x + 6, y + 6, w, ROW - 2);
          } else {
            ctx.fillRect(x + 4, y + 4, w, ROW - 2);
          }
        }

        // 選択時は本体を左上へ2pxオフセットして浮かせる
        const ox = isSelected ? -2 : 0;
        const oy = isSelected ? -2 : 0;

        ctx.fillStyle = col;
        ctx.fillRect(x + ox, y + 1 + oy, w, ROW - 2);

        if (isSelected) {
          // 選択中はアクセントカラー（--c-accent: #ff4fa3）の内側帯
          ctx.fillStyle = css('--c-accent');
          ctx.fillRect(x + ox + 3, y + 4 + oy, Math.max(2, w - 6), ROW - 8);
        }

        ctx.strokeStyle = ink;
        ctx.lineWidth = isSelected ? 3.5 : 3;
        ctx.strokeRect(x + 1.5 + ox, y + 2.5 + oy, w - 3, ROW - 5);
      }
      ctx.globalAlpha = 1;
    }

    // 範囲選択ボックス (ラバーバンド)
    if (drag && drag.mode === 'box-select') {
      const bx = Math.min(drag.startX, drag.currentX);
      const by = Math.min(drag.startY, drag.currentY);
      const bw = Math.abs(drag.currentX - drag.startX);
      const bh = Math.abs(drag.currentY - drag.startY);

      ctx.save();
      ctx.fillStyle = 'rgba(255, 79, 163, 0.18)';
      ctx.fillRect(bx, by, bw, bh);

      ctx.strokeStyle = ink;
      ctx.lineWidth = 2.5;
      ctx.setLineDash([6, 4]);
      ctx.strokeRect(bx, by, bw, bh);
      ctx.restore();
    }

    // 再生位置
    if (app.playheadMs >= 0) {
      const tick = (app.playheadMs * app.project.bpm * PPQ) / 60000;
      ctx.fillStyle = css('--c-play');
      ctx.fillRect(Math.round(tick * PX) - 2, 0, 4, height);
    }
  }

  $effect(() => {
    // 依存: プロジェクト・グリッド・再生位置・アクティブトラック・表示倍率・選択ノート
    void width;
    void app.pxPerTick;
    void app.selectedNoteIds;
    void app.quant;
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

  // キーボードショートカット (Ctrl+C, Ctrl+V, Ctrl+D, Ctrl+A, Del, 矢印キー移動)
  $effect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement | null;
      if (target && (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.tagName === 'SELECT')) {
        return;
      }

      if (e.ctrlKey || e.metaKey) {
        if (e.key === 'c' || e.key === 'C') {
          e.preventDefault();
          app.copySelected();
        } else if (e.key === 'v' || e.key === 'V') {
          e.preventDefault();
          app.paste();
          draw();
        } else if (e.key === 'd' || e.key === 'D') {
          e.preventDefault();
          app.duplicateSelected();
          draw();
        } else if (e.key === 'a' || e.key === 'A') {
          e.preventDefault();
          app.selectAll();
          draw();
        }
      } else if (e.key === 'Delete' || e.key === 'Backspace') {
        e.preventDefault();
        app.deleteSelected();
        draw();
      } else if (e.key === 'Escape') {
        e.preventDefault();
        app.clearSelection();
        draw();
      } else if (e.key === 'ArrowLeft') {
        e.preventDefault();
        app.nudgeSelected(-app.quant, 0);
        draw();
      } else if (e.key === 'ArrowRight') {
        e.preventDefault();
        app.nudgeSelected(app.quant, 0);
        draw();
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        app.nudgeSelected(0, 1);
        draw();
      } else if (e.key === 'ArrowDown') {
        e.preventDefault();
        app.nudgeSelected(0, -1);
        draw();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => {
      window.removeEventListener('keydown', handleKeyDown);
    };
  });

  type NoteSnapshot = {
    id: number;
    startTick: number;
    pitch: number;
    durationTick: number;
  };

  type Drag =
    | {
        mode: 'move';
        primaryNoteId: number;
        initialClickTick: number;
        initialClickPitch: number;
        snapshots: NoteSnapshot[];
        hasMoved: boolean;
      }
    | {
        mode: 'resize';
        note: Note;
      }
    | {
        mode: 'create';
        note: Note;
      }
    | {
        mode: 'box-select';
        startX: number;
        startY: number;
        currentX: number;
        currentY: number;
        initialSelectedIds: number[];
        isAdditive: boolean;
      };

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
      const isSelected = app.isNoteSelected(n.id);
      const isShift = e.shiftKey;
      const isAlt = e.altKey;

      const nx = n.startTick * PX;
      const nw = Math.max(6, n.durationTick * PX);
      const right = nx + nw;
      const resizeThreshold = Math.min(8, Math.max(3, nw * 0.4));
      const isResize = (right - x) <= resizeThreshold;

      if (isResize) {
        if (!isSelected && !isShift) {
          app.selectNotes([n.id]);
        }
        drag = {
          mode: 'resize',
          note: n
        };
      } else {
        // 移動または複製移動
        if (isShift) {
          app.toggleNoteSelection(n.id);
          if (!app.isNoteSelected(n.id)) {
            draw();
            return;
          }
        } else if (!isSelected) {
          app.selectNotes([n.id]);
        }

        // Alt+ドラッグで選択中ノートを複製して移動
        if (isAlt) {
          const selectedNotes = app.activeTrack.notes.filter((item) => app.isNoteSelected(item.id));
          const duplicated: Note[] = selectedNotes.map((item) => ({
            id: nextId(),
            startTick: item.startTick,
            durationTick: item.durationTick,
            pitch: item.pitch,
            velocity: item.velocity
          }));
          app.activeTrack.notes.push(...duplicated);
          app.selectNotes(duplicated.map((item) => item.id));
        }

        const snapshots: NoteSnapshot[] = app.activeTrack.notes
          .filter((item) => app.isNoteSelected(item.id))
          .map((item) => ({
            id: item.id,
            startTick: item.startTick,
            pitch: item.pitch,
            durationTick: item.durationTick
          }));

        drag = {
          mode: 'move',
          primaryNoteId: n.id,
          initialClickTick: x / PX,
          initialClickPitch: PMAX - Math.floor(y / ROW),
          snapshots,
          hasMoved: false
        };
      }
    } else {
      const isBoxSelect = e.shiftKey || app.toolMode === 'select';
      if (isBoxSelect) {
        drag = {
          mode: 'box-select',
          startX: x,
          startY: y,
          currentX: x,
          currentY: y,
          initialSelectedIds: e.shiftKey ? [...app.selectedNoteIds] : [],
          isAdditive: e.shiftKey
        };
      } else {
        app.clearSelection();
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
        app.selectNotes([note.id]);
        drag = {
          mode: 'create',
          note
        };
      }
    }
    draw();
    canvas.setPointerCapture(e.pointerId);
  }

  function move(e: PointerEvent) {
    if (!drag) return;
    const { x, y } = local(e);

    if (drag.mode === 'move') {
      drag.hasMoved = true;
      const currentTick = x / PX;
      const currentPitch = PMAX - Math.floor(y / ROW);
      const rawDeltaTick = snap(currentTick) - snap(drag.initialClickTick);
      const rawDeltaPitch = currentPitch - drag.initialClickPitch;

      let clampedDeltaTick = rawDeltaTick;
      let clampedDeltaPitch = rawDeltaPitch;

      for (const snapNote of drag.snapshots) {
        if (snapNote.startTick + clampedDeltaTick < 0) {
          clampedDeltaTick = -snapNote.startTick;
        }
        if (snapNote.pitch + clampedDeltaPitch < PMIN) {
          clampedDeltaPitch = PMIN - snapNote.pitch;
        }
        if (snapNote.pitch + clampedDeltaPitch > PMAX) {
          clampedDeltaPitch = PMAX - snapNote.pitch;
        }
      }

      const snapMap = new Map(drag.snapshots.map((s) => [s.id, s]));
      for (const n of app.activeTrack.notes) {
        const s = snapMap.get(n.id);
        if (s) {
          n.startTick = Math.max(0, s.startTick + clampedDeltaTick);
          n.pitch = Math.min(PMAX, Math.max(PMIN, s.pitch + clampedDeltaPitch));
        }
      }
    } else if (drag.mode === 'resize') {
      const q = Math.max(1, app.quant);
      const end = Math.ceil((x / PX) / q) * q;
      drag.note.durationTick = Math.max(q, end - drag.note.startTick);
    } else if (drag.mode === 'create') {
      const q = Math.max(1, app.quant);
      const end = Math.ceil((x / PX) / q) * q;
      drag.note.durationTick = Math.max(q, end - drag.note.startTick);
    } else if (drag.mode === 'box-select') {
      drag.currentX = x;
      drag.currentY = y;

      const minX = Math.min(drag.startX, drag.currentX);
      const maxX = Math.max(drag.startX, drag.currentX);
      const minY = Math.min(drag.startY, drag.currentY);
      const maxY = Math.max(drag.startY, drag.currentY);

      const boxHitIds = app.activeTrack.notes
        .filter((n) => {
          const nx = n.startTick * PX;
          const nw = Math.max(6, n.durationTick * PX);
          const ny = (PMAX - n.pitch) * ROW;
          const nh = ROW;
          return (
            nx + nw >= minX &&
            nx <= maxX &&
            ny + nh >= minY &&
            ny <= maxY
          );
        })
        .map((n) => n.id);

      if (drag.isAdditive) {
        const combined = new Set([...drag.initialSelectedIds, ...boxHitIds]);
        app.selectedNoteIds = Array.from(combined);
      } else {
        app.selectedNoteIds = boxHitIds;
      }
    }
    draw();
  }

  function up() {
    if (drag) {
      if (drag.mode === 'box-select') {
        const dist = Math.hypot(drag.currentX - drag.startX, drag.currentY - drag.startY);
        if (dist < 4 && !drag.isAdditive) {
          app.clearSelection();
        }
      }
      drag = null;
      draw();
    }
  }

  function del(e: MouseEvent) {
    e.preventDefault();
    const r = canvas.getBoundingClientRect();
    const n = hit(e.clientX - r.left, e.clientY - r.top);
    if (n) {
      if (app.isNoteSelected(n.id)) {
        app.deleteSelected();
      } else {
        app.activeTrack.notes = app.activeTrack.notes.filter((m) => m.id !== n.id);
        app.deselectNotes([n.id]);
      }
      draw();
    }
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
