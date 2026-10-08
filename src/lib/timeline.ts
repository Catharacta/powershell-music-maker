// ノート → イベントタイムライン。スクリプト出力(generator.ts)と試聴(Rust play)で共有する。
import { noteToFreq, tickToMs, type Project } from './model';

export type EventKind = 'gs_prog' | 'gs_on' | 'gs_off' | 'beep';

export interface TLEvent {
  tMs: number;
  kind: EventKind;
  ch?: number;
  pitch?: number;
  vel?: number;
  program?: number;
  freq?: number;
  durMs?: number;
}

export interface Timeline {
  events: TLEvent[];
  /** Beepは同時1音のため、重なりで切り詰め/破棄したノート数 */
  beepConflicts: number;
  /** 全体の終了時刻(ms) */
  endMs: number;
  hasGs: boolean;
  hasBeep: boolean;
}

const RANK: Record<EventKind, number> = { gs_prog: 0, gs_off: 1, gs_on: 2, beep: 2 };

export function buildTimeline(p: Project): Timeline {
  const events: TLEvent[] = [];
  let hasGs = false;
  let hasBeep = false;
  let beepConflicts = 0;

  // GS: トラック単位でProgram Change + NoteOn/Off
  for (const t of p.tracks) {
    if (t.mute || t.output !== 'gs' || t.notes.length === 0) continue;
    hasGs = true;
    events.push({ tMs: 0, kind: 'gs_prog', ch: t.channel, program: t.program });
    for (const n of t.notes) {
      const vel = Math.max(1, Math.min(127, Math.round((n.velocity * t.volume) / 100)));
      events.push({ tMs: Math.round(tickToMs(n.startTick, p.bpm)), kind: 'gs_on', ch: t.channel, pitch: n.pitch, vel });
      events.push({
        tMs: Math.round(tickToMs(n.startTick + n.durationTick, p.bpm)),
        kind: 'gs_off',
        ch: t.channel,
        pitch: n.pitch
      });
    }
  }

  // Beep: 全Beepトラックを1本にまとめ、後から来た音を優先して前の音を切り詰める
  const beep = p.tracks
    .filter((t) => !t.mute && t.output === 'beep')
    .flatMap((t) => t.notes)
    .sort((a, b) => a.startTick - b.startTick || b.pitch - a.pitch);
  const kept: typeof beep = [];
  for (const n of beep) {
    const last = kept[kept.length - 1];
    if (last && last.startTick === n.startTick) {
      beepConflicts++;
      continue;
    }
    kept.push(n);
  }
  kept.forEach((n, i) => {
    hasBeep = true;
    const next = kept[i + 1];
    let endTick = n.startTick + n.durationTick;
    if (next && next.startTick < endTick) {
      endTick = next.startTick;
      beepConflicts++;
    }
    const s = Math.round(tickToMs(n.startTick, p.bpm));
    const e = Math.round(tickToMs(endTick, p.bpm));
    events.push({ tMs: s, kind: 'beep', freq: noteToFreq(n.pitch), durMs: Math.max(1, e - s) });
  });

  events.sort((a, b) => a.tMs - b.tMs || RANK[a.kind] - RANK[b.kind]);
  const endMs = events.reduce((m, e) => Math.max(m, e.tMs + (e.durMs ?? 0)), 0);
  return { events, beepConflicts, endMs, hasGs, hasBeep };
}
