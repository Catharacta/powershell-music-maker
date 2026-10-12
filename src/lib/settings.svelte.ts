import { PPQ } from './model';

export type Language = 'ja' | 'en';
export type PreferredPs = 'auto' | 'powershell' | 'pwsh';
export type BeepOverlap = 'latest' | 'ignore';
export type DefaultOutput = 'beep' | 'gs';

export interface AppSettings {
  language: Language;
  editor: {
    defaultBpm: number;
    defaultBars: number;
    defaultQuant: number;
    defaultOutput: DefaultOutput;
    loadDemoNotes: boolean;
  };
  script: {
    visualizer: boolean;
    preferredPs: PreferredPs;
    beepOverlap: BeepOverlap;
    beepMinGapMs: number;
    beepMinDurMs: number;
  };
}

const STORAGE_KEY = 'psmm_settings';

export const DEFAULT_SETTINGS: AppSettings = {
  language: 'ja',
  editor: {
    defaultBpm: 120,
    defaultBars: 8,
    defaultQuant: PPQ / 4, // 16分音符
    defaultOutput: 'gs',
    loadDemoNotes: true
  },
  script: {
    visualizer: true,
    preferredPs: 'auto',
    beepOverlap: 'latest',
    beepMinGapMs: 20,
    beepMinDurMs: 25
  }
};

function loadSettings(): AppSettings {
  if (typeof localStorage === 'undefined') return { ...DEFAULT_SETTINGS };
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return { ...DEFAULT_SETTINGS };
    const parsed = JSON.parse(raw);
    return {
      language: parsed.language === 'en' ? 'en' : 'ja',
      editor: {
        defaultBpm: Math.min(300, Math.max(30, Number(parsed.editor?.defaultBpm) || DEFAULT_SETTINGS.editor.defaultBpm)),
        defaultBars: Math.min(1024, Math.max(1, Number(parsed.editor?.defaultBars) || DEFAULT_SETTINGS.editor.defaultBars)),
        defaultQuant: Number(parsed.editor?.defaultQuant) || DEFAULT_SETTINGS.editor.defaultQuant,
        defaultOutput: parsed.editor?.defaultOutput === 'beep' ? 'beep' : 'gs',
        loadDemoNotes: typeof parsed.editor?.loadDemoNotes === 'boolean' ? parsed.editor.loadDemoNotes : DEFAULT_SETTINGS.editor.loadDemoNotes
      },
      script: {
        visualizer: typeof parsed.script?.visualizer === 'boolean' ? parsed.script.visualizer : DEFAULT_SETTINGS.script.visualizer,
        preferredPs: ['powershell', 'pwsh'].includes(parsed.script?.preferredPs) ? parsed.script.preferredPs : 'auto',
        beepOverlap: parsed.script?.beepOverlap === 'ignore' ? 'ignore' : 'latest',
        beepMinGapMs: Math.min(100, Math.max(0, Number(parsed.script?.beepMinGapMs) ?? DEFAULT_SETTINGS.script.beepMinGapMs)),
        beepMinDurMs: Math.min(200, Math.max(10, Number(parsed.script?.beepMinDurMs) ?? DEFAULT_SETTINGS.script.beepMinDurMs))
      }
    };
  } catch (e) {
    console.warn('Failed to load settings from localStorage:', e);
    return { ...DEFAULT_SETTINGS };
  }
}

class SettingsState {
  current = $state<AppSettings>(loadSettings());

  constructor() {
    // 変更を監視して localStorage に保存
    $effect.root(() => {
      $effect(() => {
        if (typeof localStorage !== 'undefined') {
          try {
            localStorage.setItem(STORAGE_KEY, JSON.stringify(this.current));
          } catch (e) {
            console.error('Failed to save settings:', e);
          }
        }
      });
    });
  }

  get language(): Language {
    return this.current.language;
  }
  set language(val: Language) {
    this.current.language = val;
  }

  get editor() {
    return this.current.editor;
  }

  get script() {
    return this.current.script;
  }

  reset() {
    this.current = JSON.parse(JSON.stringify(DEFAULT_SETTINGS));
  }
}

export const settings = new SettingsState();
