import { noteToFreq, tickToMs, PPQ, type Project } from './model';

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
  beepMinGapMs?: number;
  beepMinDurMs?: number;
}

const RANK: Record<EventKind, number> = { gs_prog: 0, gs_off: 1, gs_on: 2, beep: 2 };

export function buildTimeline(p: Project, options: TimelineOptions = {}): Timeline {
  const beepOverlap = options.beepOverlap ?? 'latest';
  const minGapMs = Math.max(0, options.beepMinGapMs ?? 20);
  const minDurMs = Math.max(1, options.beepMinDurMs ?? 25);
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
    kept.forEach((item, i) => {
      hasBeep = true;
      const s = Math.round(tickToMs(item.note.startTick, p.bpm));
      let e = Math.round(tickToMs(item.note.startTick + item.note.durationTick, p.bpm));
      const next = kept[i + 1];
      let durMs: number;
      if (next) {
        const nextS = Math.round(tickToMs(next.note.startTick, p.bpm));
        if (nextS - e < minGapMs) {
          e = nextS - minGapMs;
        }
        const avail = Math.max(1, nextS - s - minGapMs);
        durMs = Math.max(1, Math.min(Math.max(e - s, minDurMs), avail));
      } else {
        durMs = Math.max(minDurMs, Math.max(1, e - s));
      }
      events.push({
        tMs: s,
        kind: 'beep',
        trackIndex: item.trackIndex,
        pitch: item.note.pitch,
        freq: noteToFreq(item.note.pitch),
        durMs
      });
    });
  } else {
    // 後優先: 同一時刻の音は高音のみ残し、後から来た音を優先して前の音を切り詰める
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
      let rawE = Math.round(tickToMs(endTick, p.bpm));
      let durMs: number;
      if (next) {
        const nextS = Math.round(tickToMs(next.note.startTick, p.bpm));
        if (nextS - rawE < minGapMs) {
          rawE = nextS - minGapMs;
        }
        const avail = Math.max(1, nextS - s - minGapMs);
        durMs = Math.max(1, Math.min(Math.max(rawE - s, minDurMs), avail));
      } else {
        durMs = Math.max(minDurMs, Math.max(1, rawE - s));
      }
      events.push({
        tMs: s,
        kind: 'beep',
        trackIndex: item.trackIndex,
        pitch: item.note.pitch,
        freq: noteToFreq(item.note.pitch),
        durMs
      });
    });
  }

  events.sort((a, b) => a.tMs - b.tMs || RANK[a.kind] - RANK[b.kind]);
  const endMs = events.reduce((m, e) => Math.max(m, e.tMs + (e.durMs ?? 0)), 0);
  return { events, beepConflicts, endMs, hasGs, hasBeep };
}

export type BeepIssueKind = 'overlap' | 'gap' | 'short' | 'low_pitch' | 'cross_track';

export function detectBeepIssues(
  project: Project,
  options: {
    minGapMs?: number;
    minDurMs?: number;
  } = {}
): Map<number, BeepIssueKind[]> {
  const bpm = project.bpm;
  const minGapMs = options.minGapMs ?? 20;
  const minDurMs = options.minDurMs ?? 25;
  const minGapTick = Math.max(1, Math.round((minGapMs * bpm * PPQ) / 60000));
  const minDurTick = Math.max(1, Math.round((minDurMs * bpm * PPQ) / 60000));

  const issues = new Map<number, Set<BeepIssueKind>>();
  const addIssue = (noteId: number, kind: BeepIssueKind) => {
    let set = issues.get(noteId);
    if (!set) {
      set = new Set();
      issues.set(noteId, set);
    }
    set.add(kind);
  };

  const beepTracks = project.tracks.filter((t) => !t.mute && t.output === 'beep');

  // トラック内の個別チェック
  for (const t of beepTracks) {
    const notes = [...t.notes].sort((a, b) => a.startTick - b.startTick || b.pitch - a.pitch);
    for (let i = 0; i < notes.length; i++) {
      const n = notes[i];
      // 1. 周波数下限チェック (< 26 ≒ 37Hz)
      if (n.pitch < 26) {
        addIssue(n.id, 'low_pitch');
      }
      // 2. 音長不足チェック
      if (n.durationTick < minDurTick) {
        addIssue(n.id, 'short');
      }
      // 3. 次のノートとの関係
      if (i + 1 < notes.length) {
        const next = notes[i + 1];
        if (n.startTick === next.startTick) {
          addIssue(n.id, 'overlap');
          addIssue(next.id, 'overlap');
        } else if (n.startTick + n.durationTick > next.startTick) {
          addIssue(n.id, 'overlap');
          addIssue(next.id, 'overlap');
        } else if (next.startTick - (n.startTick + n.durationTick) < minGapTick) {
          addIssue(n.id, 'gap');
        }
      }
    }
  }

  // 複数Beepトラック間の競合チェック
  if (beepTracks.length > 1) {
    const allNotes: { note: import('./model').Note; trackId: number }[] = [];
    for (const t of beepTracks) {
      for (const n of t.notes) {
        allNotes.push({ note: n, trackId: t.id });
      }
    }
    allNotes.sort((a, b) => a.note.startTick - b.note.startTick);
    for (let i = 0; i < allNotes.length; i++) {
      const a = allNotes[i];
      const aEnd = a.note.startTick + a.note.durationTick;
      for (let j = i + 1; j < allNotes.length; j++) {
        const b = allNotes[j];
        if (b.note.startTick >= aEnd) break;
        if (a.trackId !== b.trackId) {
          addIssue(a.note.id, 'cross_track');
          addIssue(b.note.id, 'cross_track');
        }
      }
    }
  }

  const result = new Map<number, BeepIssueKind[]>();
  issues.forEach((set, id) => {
    result.set(id, Array.from(set));
  });
  return result;
}

export function optimizeBeepNotes(
  notes: import('./model').Note[],
  bpm: number,
  minGapMs: number,
  minDurMs: number
): import('./model').Note[] {
  if (notes.length === 0) return [];
  const minGapTick = Math.max(1, Math.round((minGapMs * bpm * PPQ) / 60000));
  const minDurTick = Math.max(1, Math.round((minDurMs * bpm * PPQ) / 60000));

  // ソート: startTick 昇順、同一時刻なら pitch 降順 (高音優先)
  const sorted = [...notes].sort((a, b) => a.startTick - b.startTick || b.pitch - a.pitch);

  // 同時刻の重なりは最高音のみ残す
  const singleNotes: import('./model').Note[] = [];
  for (const n of sorted) {
    const last = singleNotes[singleNotes.length - 1];
    if (last && last.startTick === n.startTick) {
      continue;
    }
    const pitch = Math.max(26, Math.min(127, n.pitch));
    singleNotes.push({
      ...n,
      pitch
    });
  }

  // ギャップ確保 & 最小音長補正
  const optimized: import('./model').Note[] = [];
  for (let i = 0; i < singleNotes.length; i++) {
    const curr = singleNotes[i];
    const next = singleNotes[i + 1];

    let dur = curr.durationTick;
    if (next) {
      const avail = next.startTick - curr.startTick;
      const maxAllowedDur = Math.max(1, avail - minGapTick);
      dur = Math.min(dur, maxAllowedDur);
      dur = Math.max(1, Math.min(Math.max(dur, minDurTick), maxAllowedDur));
    } else {
      dur = Math.max(minDurTick, dur);
    }

    optimized.push({
      ...curr,
      durationTick: dur
    });
  }

  return optimized;
}
