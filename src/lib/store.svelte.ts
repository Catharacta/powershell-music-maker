import { invoke } from '@tauri-apps/api/core';
import { save as dialogSave, open as dialogOpen } from '@tauri-apps/plugin-dialog';
import { readTextFile, writeTextFile } from '@tauri-apps/plugin-fs';
import {
  BEATS_PER_BAR,
  PPQ,
  type Output,
  type Project,
  type Track,
  type ProjectFile,
  validateProjectFile
} from './model';
import { buildTimeline } from './timeline';
import { generateScript } from './generator';
import { settings } from './settings.svelte';
import { t } from './i18n';

export interface TestResult {
  ok: boolean;
  exitCode: number | null;
  stdout: string;
  stderr: string;
  message: string;
}

let seq = 100;
export const nextId = () => ++seq;
export const setNextId = (id: number) => {
  if (id > seq) seq = id;
};

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

function initialProject(): Project {
  if (settings.editor.loadDemoNotes) {
    return demo();
  }
  return {
    bpm: settings.editor.defaultBpm,
    bars: settings.editor.defaultBars,
    tracks: [
      {
        id: 1,
        name: 'TRACK 1',
        output: settings.editor.defaultOutput,
        channel: 0,
        program: 0,
        volume: 100,
        mute: false,
        notes: []
      }
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
  project = $state<Project>(initialProject());
  activeTrackId = $state(1);
  selectedNoteIds = $state<number[]>([]);
  clipboard = $state<ClipboardNote[] | null>(null);
  toolMode = $state<'draw' | 'select'>('draw');
  /** グリッド(tick) */
  quant = $state(settings.editor.defaultQuant);
  /** 新規ノート長設定 ('grid' または tick数) */
  noteLengthChoice = $state<'grid' | number>('grid');

  effectiveNoteLength = $derived(
    this.noteLengthChoice === 'grid' ? Math.max(1, this.quant) : this.noteLengthChoice
  );
  /** 表示倍率 (px / tick) デフォルト 0.2 (100%) */
  pxPerTick = $state(0.2);
  playing = $state(false);
  playheadMs = $state(-1);
  showScript = $state(false);
  visualizer = $state(settings.script.visualizer);
  status = $state('');

  currentFilePath = $state<string | null>(null);
  isDirty = $state(false);

  projectName = $derived(
    this.currentFilePath
      ? this.currentFilePath.split(/[\\/]/).pop()?.replace(/\.psmm$/i, '') || 'Untitled'
      : 'Untitled'
  );
  customTitle = $state<string | null>(null);
  scriptTitle = $derived(this.customTitle !== null ? this.customTitle : this.projectName);
  scriptArtist = $state<string>('');

  activeTrack = $derived(this.project.tracks.find((t) => t.id === this.activeTrackId) ?? this.project.tracks[0]);
  timeline = $derived(buildTimeline(this.project, { beepOverlap: settings.script.beepOverlap }));
  script = $derived(
    generateScript(this.project, this.timeline, {
      visualizer: this.visualizer,
      title: this.scriptTitle,
      artist: this.scriptArtist,
    })
  );
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

  setNoteLength(choice: 'grid' | number) {
    this.noteLengthChoice = choice;
    if (this.selectedNoteIds.length > 0) {
      const len = this.effectiveNoteLength;
      for (const n of this.activeTrack.notes) {
        if (this.selectedNoteIds.includes(n.id)) {
          n.durationTick = Math.max(1, len);
        }
      }
    }
  }

  resizeSelected(deltaTick: number) {
    const selected = this.activeTrack.notes.filter((n) => this.selectedNoteIds.includes(n.id));
    if (selected.length === 0) return;
    const minLen = Math.max(1, this.quant > 1 ? this.quant : 1);
    for (const n of selected) {
      n.durationTick = Math.max(minLen, n.durationTick + deltaTick);
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

  addTrack(output?: Output) {
    const out = output ?? settings.editor.defaultOutput;
    const used = new Set(this.project.tracks.map((t) => t.channel));
    let channel = 0;
    while (used.has(channel) && channel < 15) channel++;
    const t: Track = {
      id: nextId(),
      name: `TRACK ${this.project.tracks.length + 1}`,
      output: out,
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
      this.status = `${t('status_play_failed')}: ${e}`;
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

  newProject() {
    this.stop();
    this.clearSelection();
    this.currentFilePath = null;
    this.customTitle = null;
    this.scriptArtist = '';
    this.project = {
      bpm: settings.editor.defaultBpm,
      bars: settings.editor.defaultBars,
      tracks: [
        {
          id: nextId(),
          name: 'TRACK 1',
          output: settings.editor.defaultOutput,
          channel: 0,
          program: 0,
          volume: 100,
          mute: false,
          notes: []
        }
      ]
    };
    this.setActiveTrack(this.project.tracks[0].id);
    this.status = t('status_new_project');
  }

  loadProject(newProject: Project, filePath: string | null = null) {
    this.stop();
    this.clearSelection();
    this.currentFilePath = filePath;
    this.customTitle = null;
    this.scriptArtist = '';

    let maxId = 100;
    for (const t of newProject.tracks) {
      if (t.id > maxId) maxId = t.id;
      for (const n of t.notes) {
        if (n.id > maxId) maxId = n.id;
      }
    }
    setNextId(maxId);

    this.project = newProject;
    const initialTrack = this.project.tracks[0] ?? {
      id: nextId(),
      name: 'TRACK 1',
      output: 'gs',
      channel: 0,
      program: 0,
      volume: 100,
      mute: false,
      notes: []
    };
    if (this.project.tracks.length === 0) {
      this.project.tracks.push(initialTrack);
    }
    this.setActiveTrack(initialTrack.id);
  }

  async openProjectDialog() {
    try {
      const selected = await dialogOpen({
        multiple: false,
        directory: false,
        filters: [{ name: 'PowerShell Music Maker Project', extensions: ['psmm'] }]
      });
      if (!selected || typeof selected !== 'string') return;
      await this.openProjectFile(selected);
    } catch (e) {
      console.error('Failed to open project dialog:', e);
      this.status = `${t('status_open_failed')}: ${e}`;
      alert(`${t('status_open_failed')}: ${e}`);
    }
  }

  async openProjectFile(filePath: string) {
    try {
      const text = await readTextFile(filePath);
      const parsed = JSON.parse(text);
      const proj = validateProjectFile(parsed);
      if (!proj) {
        throw new Error(t('status_invalid_format'));
      }
      this.loadProject(proj, filePath);
      this.status = `${t('status_opened_project')}: ${this.projectName}`;
    } catch (e) {
      console.error('Failed to load project:', e);
      this.status = `${t('status_open_failed')}: ${e}`;
      alert(`${t('status_open_failed')}: ${e}`);
    }
  }

  async saveProject(): Promise<boolean> {
    if (!this.currentFilePath) {
      return this.saveProjectAs();
    }
    return this.writeProjectToFile(this.currentFilePath);
  }

  async saveProjectAs(): Promise<boolean> {
    try {
      const defaultName = (this.projectName || 'project') + '.psmm';
      const filePath = await dialogSave({
        filters: [{ name: 'PowerShell Music Maker Project', extensions: ['psmm'] }],
        defaultPath: defaultName
      });
      if (!filePath) return false;
      const ok = await this.writeProjectToFile(filePath);
      if (ok) {
        this.currentFilePath = filePath;
      }
      return ok;
    } catch (e) {
      console.error('Failed to save project as:', e);
      this.status = `${t('status_save_failed')}: ${e}`;
      alert(`${t('status_save_failed')}: ${e}`);
      return false;
    }
  }

  private async writeProjectToFile(filePath: string): Promise<boolean> {
    try {
      const fileData: ProjectFile = {
        app: 'powershell-music-maker',
        version: 1,
        project: this.project
      };
      const jsonStr = JSON.stringify(fileData, null, 2);
      await writeTextFile(filePath, jsonStr);
      this.status = `${t('status_saved_project')}: ${filePath.split(/[\\/]/).pop()}`;
      return true;
    } catch (e) {
      console.error('Failed to write project file:', e);
      this.status = `${t('status_save_failed')}: ${e}`;
      alert(`${t('status_save_failed')}: ${e}`);
      return false;
    }
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
