// データモデル。時間は tick (PPQ=480) で保持する。
export const PPQ = 480;
export const BEATS_PER_BAR = 4;

export type Output = 'beep' | 'gs';

export interface Note {
  id: number;
  startTick: number;
  durationTick: number;
  /** MIDIノート番号 0-127 */
  pitch: number;
  velocity: number;
}

export interface Track {
  id: number;
  name: string;
  /** 出力先はトラック単位 */
  output: Output;
  /** GS用 MIDIチャンネル 0-15 (9=ドラム) */
  channel: number;
  /** GS用 Program 0-127 */
  program: number;
  /** 0-100 (GSではvelocityに乗算) */
  volume: number;
  mute: boolean;
  notes: Note[];
}

export interface Project {
  bpm: number;
  bars: number;
  tracks: Track[];
}

export interface ProjectFile {
  app: 'powershell-music-maker';
  version: 1;
  project: Project;
}

/** プロジェクトファイル形式の検証とパース */
export function validateProjectFile(data: unknown): Project | null {
  if (!data || typeof data !== 'object') return null;
  const obj = data as Record<string, unknown>;

  // ProjectFile (v1) または 直接 Project オブジェクトの両方を許容
  let projectObj: unknown = obj;
  if (obj.app === 'powershell-music-maker' && obj.project && typeof obj.project === 'object') {
    projectObj = obj.project;
  }

  const p = projectObj as Record<string, unknown>;
  if (typeof p.bpm !== 'number' || typeof p.bars !== 'number' || !Array.isArray(p.tracks)) {
    return null;
  }

  const tracks: Track[] = [];
  for (const t of p.tracks) {
    if (!t || typeof t !== 'object') continue;
    const notes: Note[] = [];
    if (Array.isArray(t.notes)) {
      for (const n of t.notes) {
        if (!n || typeof n !== 'object') continue;
        notes.push({
          id: typeof n.id === 'number' ? n.id : 0,
          startTick: Math.max(0, Number(n.startTick) || 0),
          durationTick: Math.max(1, Number(n.durationTick) || 1),
          pitch: Math.min(127, Math.max(0, Number(n.pitch) || 60)),
          velocity: Math.min(127, Math.max(0, Number(n.velocity) || 100))
        });
      }
    }
    tracks.push({
      id: typeof t.id === 'number' ? t.id : 0,
      name: typeof t.name === 'string' ? t.name : 'Track',
      output: t.output === 'beep' ? 'beep' : 'gs',
      channel: Math.min(15, Math.max(0, Number(t.channel) || 0)),
      program: Math.min(127, Math.max(0, Number(t.program) || 0)),
      volume: Math.min(100, Math.max(0, Number(t.volume) ?? 100)),
      mute: Boolean(t.mute),
      notes
    });
  }

  return {
    bpm: Math.min(300, Math.max(30, Number(p.bpm) || 120)),
    bars: Math.min(128, Math.max(1, Number(p.bars) || 8)),
    tracks
  };
}

/** tick → ms。絶対位置から計算し、誤差を累積させない。 */
export function tickToMs(tick: number, bpm: number): number {
  return (tick * 60000) / (bpm * PPQ);
}

/** MIDIノート → 周波数(Hz)。Beepの有効範囲 37〜32767 にクランプ。 */
export function noteToFreq(note: number): number {
  const f = Math.round(440 * Math.pow(2, (note - 69) / 12));
  return Math.min(32767, Math.max(37, f));
}

const NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
export function noteName(n: number): string {
  return NAMES[n % 12] + (Math.floor(n / 12) - 1);
}
export function isBlack(n: number): boolean {
  return [1, 3, 6, 8, 10].includes(n % 12);
}
