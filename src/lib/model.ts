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
