// ノート → イベントタイムライン。スクリプト出力(generator.ts)と試聴(Rust play)で共有する。
import { noteToFreq, tickToMs, type Project } from './model';

export type EventKind = 'gs_prog' | 'gs_on' | 'gs_off' | 'beep';

export interface TLEvent {
  tMs: number;
  kind: EventKind;
  trackIndex?: number;
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

export interface TimelineOptions {
  beepOverlap?: 'latest' | 'ignore';
}

const RANK: Record<EventKind, number> = { gs_prog: 0, gs_off: 1, gs_on: 2, beep: 2 };

export function buildTimeline(p: Project, options: TimelineOptions = {}): Timeline {
  const beepOverlap = options.beepOverlap ?? 'latest';
  const events: TLEvent[] = [];
  let hasGs = false;
  let hasBeep = false;
  let beepConflicts = 0;

  // GS: トラック単位でProgram Change + NoteOn/Off
  p.tracks.forEach((t, tIdx) => {
    if (t.mute || t.output !== 'gs' || t.notes.length === 0) return;
    hasGs = true;
    events.push({ tMs: 0, kind: 'gs_prog', trackIndex: tIdx, ch: t.channel, program: t.program });
    for (const n of t.notes) {
      const vel = Math.max(1, Math.min(127, Math.round((n.velocity * t.volume) / 100)));
      events.push({
        tMs: Math.round(tickToMs(n.startTick, p.bpm)),
        kind: 'gs_on',
        trackIndex: tIdx,
        ch: t.channel,
        pitch: n.pitch,
        vel
      });
      events.push({
        tMs: Math.round(tickToMs(n.startTick + n.durationTick, p.bpm)),
        kind: 'gs_off',
        trackIndex: tIdx,
        ch: t.channel,
        pitch: n.pitch
      });
    }
  });

  // Beep: 全Beepトラックを1本にまとめ、後から来た音を優先して前の音を切り詰める
  const beepNotes: { note: typeof p.tracks[0]['notes'][0]; trackIndex: number }[] = [];
  p.tracks.forEach((t, tIdx) => {
    if (t.mute || t.output !== 'beep') return;
    for (const n of t.notes) {
      beepNotes.push({ note: n, trackIndex: tIdx });
    }
  });
  beepNotes.sort((a, b) => a.note.startTick - b.note.startTick || b.note.pitch - a.note.pitch);

  const kept: typeof beepNotes = [];
  if (beepOverlap === 'ignore') {
    // 先優先: 発音中の音がある場合、その終了tickより前に開始する後の音は無視する
    let currentEndTick = 0;
    for (const item of beepNotes) {
      if (item.note.startTick < currentEndTick) {
        beepConflicts++;
        continue;
      }
      kept.push(item);
      currentEndTick = item.note.startTick + item.note.durationTick;
    }
    kept.forEach((item) => {
      hasBeep = true;
      const s = Math.round(tickToMs(item.note.startTick, p.bpm));
      const e = Math.round(tickToMs(item.note.startTick + item.note.durationTick, p.bpm));
      events.push({
        tMs: s,
        kind: 'beep',
        trackIndex: item.trackIndex,
        freq: noteToFreq(item.note.pitch),
        durMs: Math.max(1, e - s)
      });
    });
  } else {
    // 後優先: 全Beepトラックを1本にまとめ、後から来た音を優先して前の音を切り詰める
    for (const item of beepNotes) {
      const last = kept[kept.length - 1];
      if (last && last.note.startTick === item.note.startTick) {
        beepConflicts++;
        continue;
      }
      kept.push(item);
    }
    kept.forEach((item, i) => {
      hasBeep = true;
      const next = kept[i + 1];
      let endTick = item.note.startTick + item.note.durationTick;
      if (next && next.note.startTick < endTick) {
        endTick = next.note.startTick;
        beepConflicts++;
      }
      const s = Math.round(tickToMs(item.note.startTick, p.bpm));
      const e = Math.round(tickToMs(endTick, p.bpm));
      events.push({
        tMs: s,
        kind: 'beep',
        trackIndex: item.trackIndex,
        freq: noteToFreq(item.note.pitch),
        durMs: Math.max(1, e - s)
      });
    });
  }

  events.sort((a, b) => a.tMs - b.tMs || RANK[a.kind] - RANK[b.kind]);
  const endMs = events.reduce((m, e) => Math.max(m, e.tMs + (e.durMs ?? 0)), 0);
  return { events, beepConflicts, endMs, hasGs, hasBeep };
}
