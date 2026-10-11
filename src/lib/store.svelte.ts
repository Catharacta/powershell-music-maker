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

export interface ClipboardNote {
  startTickOffset: number;
  durationTick: number;
  pitch: number;
  velocity: number;
}

class AppState {
  project = $state<Project>(demo());
  activeTrackId = $state(1);
  selectedNoteIds = $state<number[]>([]);
  clipboard = $state<ClipboardNote[] | null>(null);
  toolMode = $state<'draw' | 'select'>('draw');
  /** グリッド/新規ノート長(tick) */
  quant = $state(PPQ / 4);
  /** 表示倍率 (px / tick) デフォルト 0.2 (100%) */
  pxPerTick = $state(0.2);
  playing = $state(false);
  playheadMs = $state(-1);
  showScript = $state(false);
  visualizer = $state(true);
  status = $state('');

  activeTrack = $derived(this.project.tracks.find((t) => t.id === this.activeTrackId) ?? this.project.tracks[0]);
  timeline = $derived(buildTimeline(this.project));
  script = $derived(generateScript(this.project, this.timeline, { visualizer: this.visualizer }));
  totalTicks = $derived(this.project.bars * BEATS_PER_BAR * PPQ);

  setActiveTrack(id: number) {
    if (this.activeTrackId !== id) {
      this.activeTrackId = id;
      this.clearSelection();
    }
  }

  isNoteSelected(id: number): boolean {
    return this.selectedNoteIds.includes(id);
  }

  selectNotes(ids: number[], additive = false) {
    if (additive) {
      const set = new Set([...this.selectedNoteIds, ...ids]);
      this.selectedNoteIds = Array.from(set);
    } else {
      this.selectedNoteIds = [...ids];
    }
  }

  deselectNotes(ids: number[]) {
    const toRemove = new Set(ids);
    this.selectedNoteIds = this.selectedNoteIds.filter((id) => !toRemove.has(id));
  }

  toggleNoteSelection(id: number) {
    if (this.selectedNoteIds.includes(id)) {
      this.selectedNoteIds = this.selectedNoteIds.filter((x) => x !== id);
    } else {
      this.selectedNoteIds = [...this.selectedNoteIds, id];
    }
  }

  clearSelection() {
    this.selectedNoteIds = [];
  }

  selectAll() {
    this.selectedNoteIds = this.activeTrack.notes.map((n) => n.id);
  }

  deleteSelected() {
    if (this.selectedNoteIds.length === 0) return;
    const set = new Set(this.selectedNoteIds);
    this.activeTrack.notes = this.activeTrack.notes.filter((n) => !set.has(n.id));
    this.selectedNoteIds = [];
  }

  copySelected() {
    const selected = this.activeTrack.notes.filter((n) => this.selectedNoteIds.includes(n.id));
    if (selected.length === 0) return;
    const minStart = Math.min(...selected.map((n) => n.startTick));
    this.clipboard = selected.map((n) => ({
      startTickOffset: n.startTick - minStart,
      durationTick: n.durationTick,
      pitch: n.pitch,
      velocity: n.velocity
    }));
  }

  paste(targetTick?: number) {
    if (!this.clipboard || this.clipboard.length === 0) return;
    let baseTick: number;
    if (targetTick !== undefined) {
      baseTick = targetTick;
    } else {
      if (this.selectedNoteIds.length > 0) {
        const selected = this.activeTrack.notes.filter((n) => this.selectedNoteIds.includes(n.id));
        const maxEnd = Math.max(...selected.map((n) => n.startTick + n.durationTick));
        const q = Math.max(1, this.quant);
        baseTick = Math.ceil(maxEnd / q) * q;
      } else if (this.playheadMs >= 0) {
        const phTick = (this.playheadMs * this.project.bpm * PPQ) / 60000;
        const q = Math.max(1, this.quant);
        baseTick = Math.floor(phTick / q) * q;
      } else {
        const maxEnd = this.activeTrack.notes.reduce((max, n) => Math.max(max, n.startTick + n.durationTick), 0);
        const q = Math.max(1, this.quant);
        baseTick = maxEnd > 0 ? Math.ceil(maxEnd / q) * q : 0;
      }
    }

    const newNotes: import('./model').Note[] = this.clipboard.map((item) => ({
      id: nextId(),
      startTick: baseTick + item.startTickOffset,
      durationTick: item.durationTick,
      pitch: item.pitch,
      velocity: item.velocity
    }));

    this.activeTrack.notes.push(...newNotes);
    this.selectedNoteIds = newNotes.map((n) => n.id);
  }

  duplicateSelected() {
    const selected = this.activeTrack.notes.filter((n) => this.selectedNoteIds.includes(n.id));
    if (selected.length === 0) return;
    const minStart = Math.min(...selected.map((n) => n.startTick));
    const maxEnd = Math.max(...selected.map((n) => n.startTick + n.durationTick));
    const q = Math.max(1, this.quant);
    const rangeSpan = Math.max(q, Math.ceil((maxEnd - minStart) / q) * q);

    const duplicated: import('./model').Note[] = selected.map((n) => ({
      id: nextId(),
      startTick: n.startTick + rangeSpan,
      durationTick: n.durationTick,
      pitch: n.pitch,
      velocity: n.velocity
    }));

    this.activeTrack.notes.push(...duplicated);
    this.selectedNoteIds = duplicated.map((n) => n.id);
  }

  nudgeSelected(deltaTick: number, deltaPitch: number) {
    const selected = this.activeTrack.notes.filter((n) => this.selectedNoteIds.includes(n.id));
    if (selected.length === 0) return;

    let actualDeltaTick = deltaTick;
    let actualDeltaPitch = deltaPitch;

    for (const n of selected) {
      if (n.startTick + actualDeltaTick < 0) {
        actualDeltaTick = -n.startTick;
      }
      if (n.pitch + actualDeltaPitch < 36) {
        actualDeltaPitch = 36 - n.pitch;
      }
      if (n.pitch + actualDeltaPitch > 96) {
        actualDeltaPitch = 96 - n.pitch;
      }
    }

    for (const n of selected) {
      n.startTick = Math.max(0, n.startTick + actualDeltaTick);
      n.pitch = Math.min(96, Math.max(36, n.pitch + actualDeltaPitch));
    }
  }

  zoomIn() {
    this.setPxPerTick(this.pxPerTick * 1.25);
  }

  zoomOut() {
    this.setPxPerTick(this.pxPerTick / 1.25);
  }

  zoomReset() {
    this.pxPerTick = 0.2;
  }

  setPxPerTick(val: number) {
    // 0.04 (20%) 〜 1.6 (800%) にクランプ
    this.pxPerTick = Math.min(1.6, Math.max(0.04, Math.round(val * 1000) / 1000));
  }

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
    this.setActiveTrack(t.id);
  }

  removeTrack(id: number) {
    if (this.project.tracks.length <= 1) return;
    this.project.tracks = this.project.tracks.filter((t) => t.id !== id);
    if (this.activeTrackId === id) {
      this.setActiveTrack(this.project.tracks[0].id);
    } else {
      this.clearSelection();
    }
  }

  loadMidiAsNew(info: import('./midi').ParsedMidiInfo) {
    this.stop();
    this.clearSelection();
    const tracks: Track[] = info.parsedTracks.map((pt) => ({
      id: nextId(),
      name: pt.name,
      output: 'gs',
      channel: pt.channel,
      program: pt.program,
      volume: 100,
      mute: false,
      notes: pt.notes.map((n) => ({
        ...n,
        id: nextId()
      }))
    }));

    this.project = {
      bpm: info.bpm,
      bars: info.bars,
      tracks: tracks.length > 0 ? tracks : [
        {
          id: nextId(),
          name: 'TRACK 1',
          output: 'gs',
          channel: 0,
          program: 0,
          volume: 100,
          mute: false,
          notes: []
        }
      ]
    };
    this.setActiveTrack(this.project.tracks[0].id);
  }

  appendMidi(info: import('./midi').ParsedMidiInfo) {
    this.stop();
    this.clearSelection();
    const used = new Set(this.project.tracks.map((t) => t.channel));
    const newTracks: Track[] = info.parsedTracks.map((pt) => {
      let ch = pt.channel;
      // ドラム(9)以外で重複があれば空きチャンネルを探す
      if (ch !== 9 && used.has(ch)) {
        let candidate = 0;
        while (candidate < 16 && (candidate === 9 || used.has(candidate))) {
          candidate++;
        }
        if (candidate < 16) ch = candidate;
      }
      used.add(ch);

      return {
        id: nextId(),
        name: pt.name,
        output: 'gs',
        channel: ch,
        program: pt.program,
        volume: 100,
        mute: false,
        notes: pt.notes.map((n) => ({
          ...n,
          id: nextId()
        }))
      };
    });

    if (newTracks.length > 0) {
      this.project.tracks.push(...newTracks);
      this.project.bars = Math.max(this.project.bars, info.bars);
      this.setActiveTrack(newTracks[0].id);
    }
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
