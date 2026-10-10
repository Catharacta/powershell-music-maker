import { Midi } from '@tonejs/midi';
import { BEATS_PER_BAR, PPQ, type Note, type Track } from './model';

export interface ParsedMidiInfo {
  name: string;
  bpm: number;
  bars: number;
  totalNotes: number;
  tracks: Omit<Track, 'id' | 'notes'>[];
  parsedTracks: {
    name: string;
    channel: number;
    program: number;
    notes: Omit<Note, 'id'>[];
  }[];
}

/**
 * ArrayBuffer から MIDI を解析し、本アプリの PPQ(=480) にスケールしたトラック/ノートデータを返す。
 */
export function parseMidi(data: ArrayBuffer, fileName = 'Imported MIDI'): ParsedMidiInfo {
  const midi = new Midi(data);
  const srcPpq = midi.header.ppq || 480;
  const scale = PPQ / srcPpq;

  // 最初のテンポイベントを採用、なければ 120
  let bpm = 120;
  if (midi.header.tempos && midi.header.tempos.length > 0) {
    bpm = Math.round(midi.header.tempos[0].bpm);
    if (bpm < 20 || bpm > 500) bpm = 120;
  }

  const parsedTracks: ParsedMidiInfo['parsedTracks'] = [];
  let maxTick = 0;
  let totalNotes = 0;

  midi.tracks.forEach((t, idx) => {
    if (!t.notes || t.notes.length === 0) return;

    const trackName = (t.name && t.name.trim().length > 0)
      ? t.name.trim()
      : (t.instrument?.name ? t.instrument.name : `Track ${idx + 1}`);

    const channel = t.instrument?.percussion ? 9 : (t.channel !== undefined ? t.channel : 0);
    const program = t.instrument?.number !== undefined ? Math.min(127, Math.max(0, t.instrument.number)) : 0;

    const notes: Omit<Note, 'id'>[] = [];

    for (const n of t.notes) {
      const startTick = Math.max(0, Math.round(n.ticks * scale));
      const durationTick = Math.max(1, Math.round(n.durationTicks * scale));
      const pitch = Math.min(127, Math.max(0, Math.round(n.midi)));
      const velocity = Math.min(127, Math.max(1, Math.round(n.velocity * 127)));

      notes.push({
        startTick,
        durationTick,
        pitch,
        velocity
      });

      const endTick = startTick + durationTick;
      if (endTick > maxTick) maxTick = endTick;
      totalNotes++;
    }

    parsedTracks.push({
      name: trackName,
      channel,
      program,
      notes
    });
  });

  const ticksPerBar = PPQ * BEATS_PER_BAR;
  const bars = Math.max(4, Math.ceil(maxTick / ticksPerBar) || 4);

  return {
    name: midi.name || fileName.replace(/\.[^/.]+$/, ''),
    bpm,
    bars,
    totalNotes,
    tracks: parsedTracks.map((pt) => ({
      name: pt.name,
      output: 'gs' as const,
      channel: pt.channel,
      program: pt.program,
      volume: 100,
      mute: false
    })),
    parsedTracks
  };
}
