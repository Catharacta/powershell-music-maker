import React from 'react';
import { Note } from './types';

interface PianoRollProps {
  notes: Note[];
  onAddNote: (pitch: number, beat: number) => void;
  onRemoveNote: (pitch: number, beat: number) => void;
}

const MIN_PITCH = 48; // C3
const MAX_PITCH = 83; // B5
const BEATS = 16;

export const PianoRoll: React.FC<PianoRollProps> = ({ notes, onAddNote, onRemoveNote }) => {
  const pitches = Array.from({ length: MAX_PITCH - MIN_PITCH + 1 }, (_, i) => MAX_PITCH - i);
  const beats = Array.from({ length: BEATS }, (_, i) => i);

  const getNoteAt = (pitch: number, beat: number) => {
    return notes.find(n => n.pitch === pitch && n.start_beat <= beat && n.start_beat + n.duration_beat > beat);
  };

  const handleCellClick = (pitch: number, beat: number) => {
    const existingNote = getNoteAt(pitch, beat);
    if (existingNote) {
      onRemoveNote(pitch, existingNote.start_beat);
    } else {
      onAddNote(pitch, beat);
    }
  };

  const isBlackKey = (pitch: number) => {
    const noteInOctave = pitch % 12;
    return [1, 3, 6, 8, 10].includes(noteInOctave);
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', overflowX: 'auto', border: '1px solid #ccc' }}>
      {pitches.map(pitch => (
        <div key={pitch} style={{ display: 'flex' }}>
          <div style={{
            width: '60px',
            minWidth: '60px',
            height: '24px',
            borderBottom: '1px solid #555',
            backgroundColor: isBlackKey(pitch) ? '#333' : '#fff',
            color: isBlackKey(pitch) ? '#fff' : '#000',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: '12px'
          }}>
            {pitch}
          </div>
          {beats.map(beat => {
            const note = getNoteAt(pitch, beat);
            const isNoteStart = note && note.start_beat === beat;
            return (
              <div
                key={`${pitch}-${beat}`}
                onClick={() => handleCellClick(pitch, beat)}
                style={{
                  width: '40px',
                  minWidth: '40px',
                  height: '24px',
                  borderBottom: '1px solid #eee',
                  borderRight: beat % 4 === 3 ? '2px solid #aaa' : '1px solid #eee',
                  backgroundColor: note ? (note.synth_type === 'beep' ? '#4caf50' : '#2196f3') : '#fafafa',
                  cursor: 'pointer',
                  boxSizing: 'border-box',
                  borderLeft: isNoteStart ? '2px solid #000' : 'none'
                }}
              />
            );
          })}
        </div>
      ))}
    </div>
  );
};
