export interface Note {
  pitch: number;
  start_beat: number;
  duration_beat: number;
  synth_type: 'beep' | 'synth';
}
