import { invoke } from '@tauri-apps/api/core';
import { BEATS_PER_BAR, PPQ, type Output, type Project, type Track } from './model';
import { buildTimeline } from './timeline';
import { generateScript } from './generator';

export interface TestResult {
  ok: boolean;
  exitCode: number | null;
  stdout: string;
  stderr: string;
  message: string;
}

let seq = 100;
export const nextId = () => ++seq;

function demo(): Project {
  const q = PPQ / 2;
  const mel = [60, 62, 64, 65, 67, 65, 64, 62].map((pitch, i) => ({
    id: nextId(),
    startTick: i * q,
    durationTick: q,
    pitch,
    velocity: 100
  }));
  const chord = [48, 52, 55].map((pitch) => ({
    id: nextId(),
    startTick: 0,
    durationTick: PPQ * 4,
    pitch,
    velocity: 90
  }));
  return {
    bpm: 120,
    bars: 8,
    tracks: [
      { id: 1, name: 'MELODY', output: 'beep', channel: 0, program: 0, volume: 100, mute: false, notes: mel },
      { id: 2, name: 'CHORDS', output: 'gs', channel: 1, program: 0, volume: 100, mute: false, notes: chord }
    ]
  };
}

class AppState {
  project = $state<Project>(demo());
  activeTrackId = $state(1);
  /** グリッド/新規ノート長(tick) */
  quant = $state(PPQ / 4);
  playing = $state(false);
  playheadMs = $state(-1);
  showScript = $state(false);
  status = $state('');

  activeTrack = $derived(this.project.tracks.find((t) => t.id === this.activeTrackId) ?? this.project.tracks[0]);
  timeline = $derived(buildTimeline(this.project));
  script = $derived(generateScript(this.project, this.timeline));
  totalTicks = $derived(this.project.bars * BEATS_PER_BAR * PPQ);

  addTrack(output: Output) {
    const used = new Set(this.project.tracks.map((t) => t.channel));
    let channel = 0;
    while (used.has(channel) && channel < 15) channel++;
    const t: Track = {
      id: nextId(),
      name: `TRACK ${this.project.tracks.length + 1}`,
      output,
      channel,
      program: 0,
      volume: 100,
      mute: false,
      notes: []
    };
    this.project.tracks.push(t);
    this.activeTrackId = t.id;
  }

  removeTrack(id: number) {
    if (this.project.tracks.length <= 1) return;
    this.project.tracks = this.project.tracks.filter((t) => t.id !== id);
    if (this.activeTrackId === id) this.activeTrackId = this.project.tracks[0].id;
  }

  private raf = 0;

  async play() {
    this.stop();
    const tl = this.timeline;
    if (tl.events.length === 0) return;
    try {
      await invoke('play', { events: tl.events });
    } catch (e) {
      this.status = `再生失敗: ${e}`;
      return;
    }
    this.status = '';
    this.playing = true;
    const t0 = performance.now();
    const tick = () => {
      const ms = performance.now() - t0;
      if (ms > tl.endMs + 300) {
        this.playing = false;
        this.playheadMs = -1;
        return;
      }
      this.playheadMs = ms;
      this.raf = requestAnimationFrame(tick);
    };
    this.raf = requestAnimationFrame(tick);
  }

  stop() {
    cancelAnimationFrame(this.raf);
    this.playing = false;
    this.playheadMs = -1;
    invoke('stop').catch(() => {});
  }

  testBeep(shell: 'powershell' | 'pwsh') {
    return invoke<TestResult>('test_beep', { shell });
  }
  testGs() {
    return invoke<TestResult>('test_gs');
  }
  devices() {
    return invoke<string[]>('list_midi_devices');
  }
}

export const app = new AppState();
