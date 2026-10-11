<script lang="ts">
  import { settings, type Language, type PreferredPs, type BeepOverlap, type DefaultOutput } from './settings.svelte';
  import { t } from './i18n';
  import { OSS_LICENSES } from './licenses';
  import { PPQ } from './model';
  import { tooltip } from './tooltip';
  import Select from './Select.svelte';
  import {
    X,
    Globe,
    Sliders,
    Terminal,
    FileText,
    ExternalLink,
    ChevronDown,
    ChevronRight,
    RotateCcw,
    Check
  } from '@lucide/svelte';

  interface Props {
    open: boolean;
    onclose: () => void;
  }

  let { open, onclose }: Props = $props();

  type Tab = 'general' | 'editor' | 'script' | 'about';
  let activeTab = $state<Tab>('general');
  let expandedLicense = $state<string | null>(null);
  let showResetConfirm = $state(false);

  function toggleLicense(name: string) {
    expandedLicense = expandedLicense === name ? null : name;
  }

  function handleReset() {
    settings.reset();
    showResetConfirm = true;
    setTimeout(() => {
      showResetConfirm = false;
    }, 2000);
  }

  const quantOptions = $derived([
    { label: t('quant_1_beat'), value: PPQ },
    { label: t('quant_half_beat'), value: PPQ / 2 },
    { label: t('quant_quarter_beat'), value: PPQ / 4 },
    { label: t('quant_eighth_beat'), value: PPQ / 8 }
  ]);

  const defaultOutputOptions = $derived([
    { label: t('track_gs_desc'), value: 'gs' },
    { label: t('track_beep_desc'), value: 'beep' }
  ]);

  const preferredPsOptions = $derived([
    { label: t('settings_ps_auto'), value: 'auto' },
    { label: t('settings_ps_powershell'), value: 'powershell' },
    { label: t('settings_ps_pwsh'), value: 'pwsh' }
  ]);

  const beepOverlapOptions = $derived([
    { label: t('settings_beep_latest'), value: 'latest' },
    { label: t('settings_beep_ignore'), value: 'ignore' }
  ]);
</script>

{#if open}
  <div
    class="modal-backdrop"
    onclick={onclose}
    onkeydown={(e) => e.key === 'Escape' && onclose()}
    role="button"
    tabindex="0"
    aria-label="Close modal overlay"
  >
    <div
      class="modal"
      onclick={(e) => e.stopPropagation()}
      onkeydown={(e) => e.stopPropagation()}
      role="dialog"
      tabindex="-1"
      aria-modal="true"
    >
      <header class="modal-header">
        <h2 class="title">{t('settings_title')}</h2>
        <button class="btn btn-icon" onclick={onclose} aria-label={t('settings_close')}>
          <X size={20} strokeWidth={3} />
        </button>
      </header>

      <div class="modal-body">
        <!-- サイドタブナビゲーション -->
        <nav class="tabs-nav" aria-label="Settings tabs">
          <button
            class="tab-btn"
            class:active={activeTab === 'general'}
            onclick={() => (activeTab = 'general')}
          >
            <Globe size={18} strokeWidth={2.5} />
            <span>{t('settings_tab_general')}</span>
          </button>
          <button
            class="tab-btn"
            class:active={activeTab === 'editor'}
            onclick={() => (activeTab = 'editor')}
          >
            <Sliders size={18} strokeWidth={2.5} />
            <span>{t('settings_tab_editor')}</span>
          </button>
          <button
            class="tab-btn"
            class:active={activeTab === 'script'}
            onclick={() => (activeTab = 'script')}
          >
            <Terminal size={18} strokeWidth={2.5} />
            <span>{t('settings_tab_script')}</span>
          </button>
          <button
            class="tab-btn"
            class:active={activeTab === 'about'}
            onclick={() => (activeTab = 'about')}
          >
            <FileText size={18} strokeWidth={2.5} />
            <span>{t('settings_tab_about')}</span>
          </button>
        </nav>

        <!-- タブコンテンツ -->
        <div class="tab-content">
          {#if activeTab === 'general'}
            <section class="section">
              <h3 class="section-title">{t('settings_tab_general')}</h3>

              <div class="setting-item">
                <label class="setting-label" for="lang-select">{t('settings_language')}</label>
                <div class="radio-group" id="lang-select">
                  <button
                    type="button"
                    class="radio-btn"
                    class:selected={settings.language === 'ja'}
                    onclick={() => (settings.language = 'ja')}
                  >
                    {#if settings.language === 'ja'}
                      <Check size={16} strokeWidth={3} />
                    {/if}
                    {t('settings_language_ja')}
                  </button>
                  <button
                    type="button"
                    class="radio-btn"
                    class:selected={settings.language === 'en'}
                    onclick={() => (settings.language = 'en')}
                  >
                    {#if settings.language === 'en'}
                      <Check size={16} strokeWidth={3} />
                    {/if}
                    {t('settings_language_en')}
                  </button>
                </div>
              </div>
            </section>
          {:else if activeTab === 'editor'}
            <section class="section">
              <h3 class="section-title">{t('settings_tab_editor')}</h3>

              <div class="setting-item">
                <label class="setting-label" for="default-bpm">{t('settings_default_bpm')}</label>
                <div class="input-row">
                  <input
                    id="default-bpm"
                    type="number"
                    min="30"
                    max="300"
                    bind:value={settings.editor.defaultBpm}
                    class="input-num"
                  />
                  <span class="unit">BPM (30 - 300)</span>
                </div>
              </div>

              <div class="setting-item">
                <label class="setting-label" for="default-bars">{t('settings_default_bars')}</label>
                <div class="input-row">
                  <input
                    id="default-bars"
                    type="number"
                    min="1"
                    max="128"
                    bind:value={settings.editor.defaultBars}
                    class="input-num"
                  />
                  <span class="unit">{t('bars')} (1 - 128)</span>
                </div>
              </div>

              <div class="setting-item">
                <label class="setting-label" for="default-quant">{t('settings_default_quant')}</label>
                <Select
                  id="default-quant"
                  bind:value={settings.editor.defaultQuant}
                  options={quantOptions}
                  style="max-width: 380px; width: 100%;"
                />
              </div>

              <div class="setting-item">
                <label class="setting-label" for="default-output">{t('settings_default_output')}</label>
                <Select
                  id="default-output"
                  bind:value={settings.editor.defaultOutput}
                  options={defaultOutputOptions}
                  style="max-width: 380px; width: 100%;"
                />
              </div>

              <div class="setting-item">
                <label class="checkbox-label">
                  <input
                    type="checkbox"
                    bind:checked={settings.editor.loadDemoNotes}
                    class="checkbox-input"
                  />
                  <span class="checkbox-custom"></span>
                  <span class="label-bold">{t('settings_load_demo_notes')}</span>
                </label>
                <p class="setting-desc">{t('settings_load_demo_notes_desc')}</p>
              </div>
            </section>
          {:else if activeTab === 'script'}
            <section class="section">
              <h3 class="section-title">{t('settings_tab_script')}</h3>

              <div class="setting-item">
                <label class="checkbox-label">
                  <input
                    type="checkbox"
                    bind:checked={settings.script.visualizer}
                    class="checkbox-input"
                  />
                  <span class="checkbox-custom"></span>
                  <span class="label-bold">{t('settings_visualizer')}</span>
                </label>
                <p class="setting-desc">{t('settings_visualizer_desc')}</p>
              </div>

              <div class="setting-item">
                <label class="setting-label" for="preferred-ps">{t('settings_preferred_ps')}</label>
                <Select
                  id="preferred-ps"
                  bind:value={settings.script.preferredPs}
                  options={preferredPsOptions}
                  style="max-width: 380px; width: 100%;"
                />
              </div>

              <div class="setting-item">
                <label class="setting-label" for="beep-overlap">{t('settings_beep_overlap')}</label>
                <p class="setting-desc">{t('settings_beep_overlap_desc')}</p>
                <Select
                  id="beep-overlap"
                  bind:value={settings.script.beepOverlap}
                  options={beepOverlapOptions}
                  style="max-width: 380px; width: 100%;"
                />
              </div>
            </section>
          {:else if activeTab === 'about'}
            <section class="section">
              <h3 class="section-title">{t('settings_tab_about')}</h3>

              <div class="app-card">
                <div class="app-card-title">{t('app_title')}</div>
                <div class="app-card-version">{t('settings_version')}: 0.1.0</div>
                <p class="app-card-desc">{t('settings_app_desc')}</p>
                <a
                  href="https://github.com/Yuta0401/powershell-music-maker"
                  target="_blank"
                  rel="noreferrer"
                  class="link-btn"
                >
                  <span>{t('settings_repo')}</span>
                  <ExternalLink size={16} strokeWidth={2.5} />
                </a>
              </div>

              <div class="oss-section">
                <h4 class="oss-title">{t('settings_oss_licenses')}</h4>
                <div class="license-list">
                  {#each OSS_LICENSES as lib}
                    <div class="license-card">
                      <div class="license-header">
                        <div class="license-info">
                          <span class="lib-name">{lib.name}</span>
                          {#if lib.version}
                            <span class="lib-version">v{lib.version}</span>
                          {/if}
                          <span class="lib-badge">{lib.license}</span>
                        </div>
                        <div class="license-actions">
                          <a
                            href={lib.url}
                            target="_blank"
                            rel="noreferrer"
                            class="lib-link"
                            use:tooltip={lib.url}
                          >
                            <ExternalLink size={14} strokeWidth={2.5} />
                          </a>
                          <button
                            class="toggle-btn"
                            onclick={() => toggleLicense(lib.name)}
                            aria-label={expandedLicense === lib.name ? t('settings_hide_license') : t('settings_view_license')}
                          >
                            {#if expandedLicense === lib.name}
                              <ChevronDown size={18} strokeWidth={3} />
                            {:else}
                              <ChevronRight size={18} strokeWidth={3} />
                            {/if}
                          </button>
                        </div>
                      </div>

                      {#if expandedLicense === lib.name}
                        <div class="license-body">
                          <div class="copyright-line">{lib.copyright}</div>
                          <pre class="license-text">{lib.text}</pre>
                        </div>
                      {/if}
                    </div>
                  {/each}
                </div>
              </div>
            </section>
          {/if}
        </div>
      </div>

      <footer class="modal-footer">
        <button class="btn btn-secondary" onclick={handleReset}>
          <RotateCcw size={16} strokeWidth={2.5} />
          <span>{showResetConfirm ? t('settings_reset_done') : t('settings_reset')}</span>
        </button>
        <button class="btn btn-primary" onclick={onclose}>
          {t('settings_close')}
        </button>
      </footer>
    </div>
  </div>
{/if}

<style>
  .modal-backdrop {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.7);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
    padding: 16px;
  }

  .modal {
    background: #ffffff;
    border: 3px solid #000000;
    box-shadow: 8px 8px 0 #000000;
    width: 800px;
    max-width: 95vw;
    height: 600px;
    max-height: 90vh;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .modal-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 12px 16px;
    background: #ffee00;
    border-bottom: 3px solid #000000;
  }

  .title {
    margin: 0;
    font-size: 1.25rem;
    font-weight: 900;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .modal-body {
    display: flex;
    flex: 1;
    overflow: hidden;
  }

  .tabs-nav {
    width: 220px;
    background: #f4f4f0;
    border-right: 3px solid #000000;
    display: flex;
    flex-direction: column;
    padding: 8px 0;
    gap: 4px;
  }

  .tab-btn {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 12px 16px;
    background: transparent;
    border: none;
    border-left: 5px solid transparent;
    font-family: inherit;
    font-size: 0.95rem;
    font-weight: 700;
    text-align: left;
    cursor: pointer;
    transition: background 0.1s;
  }

  .tab-btn:hover {
    background: #e8e8e0;
  }

  .tab-btn.active {
    background: #ffffff;
    border-left: 5px solid #000000;
    color: #000000;
  }

  .tab-content {
    flex: 1;
    overflow-y: auto;
    padding: 20px;
    background: #ffffff;
  }

  .section {
    display: flex;
    flex-direction: column;
    gap: 20px;
  }

  .section-title {
    margin: 0 0 4px 0;
    font-size: 1.15rem;
    font-weight: 900;
    border-bottom: 2px solid #000000;
    padding-bottom: 8px;
  }

  .setting-item {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .setting-label {
    font-weight: 800;
    font-size: 0.95rem;
  }

  .setting-desc {
    margin: 0;
    font-size: 0.85rem;
    color: #444444;
    line-height: 1.4;
  }

  .radio-group {
    display: flex;
    gap: 12px;
  }

  .radio-btn {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px 16px;
    background: #ffffff;
    border: 3px solid #000000;
    box-shadow: 4px 4px 0 #000000;
    font-family: inherit;
    font-weight: 800;
    cursor: pointer;
    transition: transform 0.05s, box-shadow 0.05s;
  }

  .radio-btn:hover {
    background: #fafafa;
  }

  .radio-btn.selected {
    background: #00d4ff;
    box-shadow: 2px 2px 0 #000000;
    transform: translate(2px, 2px);
  }

  .input-row {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .input-num {
    width: 120px;
    padding: 8px 12px;
    border: 3px solid #000000;
    font-family: inherit;
    font-size: 1rem;
    font-weight: 700;
    box-shadow: 3px 3px 0 #000000;
  }

  .unit {
    font-size: 0.85rem;
    font-weight: 700;
    color: #555555;
  }

  .select-input {
    width: 100%;
    max-width: 380px;
    padding: 8px 12px;
    border: 3px solid #000000;
    font-family: inherit;
    font-size: 0.95rem;
    font-weight: 700;
    box-shadow: 3px 3px 0 #000000;
    background: #ffffff;
    cursor: pointer;
  }

  .checkbox-label {
    display: flex;
    align-items: center;
    gap: 10px;
    cursor: pointer;
  }

  .checkbox-input {
    width: 20px;
    height: 20px;
    accent-color: #000000;
    cursor: pointer;
  }

  .label-bold {
    font-weight: 800;
    font-size: 1rem;
  }

  .app-card {
    border: 3px solid #000000;
    box-shadow: 5px 5px 0 #000000;
    padding: 16px;
    background: #f9f9f5;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .app-card-title {
    font-size: 1.2rem;
    font-weight: 900;
  }

  .app-card-version {
    font-size: 0.9rem;
    font-family: monospace;
    font-weight: 700;
    background: #00e676;
    border: 2px solid #000000;
    padding: 2px 8px;
    display: inline-block;
    align-self: flex-start;
  }

  .app-card-desc {
    margin: 4px 0;
    font-size: 0.9rem;
    line-height: 1.4;
  }

  .link-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    align-self: flex-start;
    padding: 6px 12px;
    background: #ffffff;
    border: 2px solid #000000;
    box-shadow: 3px 3px 0 #000000;
    text-decoration: none;
    color: #000000;
    font-size: 0.85rem;
    font-weight: 800;
  }

  .link-btn:hover {
    background: #ffee00;
  }

  .oss-section {
    display: flex;
    flex-direction: column;
    gap: 12px;
    margin-top: 10px;
  }

  .oss-title {
    margin: 0;
    font-size: 1rem;
    font-weight: 900;
  }

  .license-list {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .license-card {
    border: 2px solid #000000;
    background: #ffffff;
  }

  .license-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 8px 12px;
    background: #fafaf7;
  }

  .license-info {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
  }

  .lib-name {
    font-weight: 800;
    font-size: 0.95rem;
  }

  .lib-version {
    font-size: 0.8rem;
    font-family: monospace;
    color: #666666;
  }

  .lib-badge {
    background: #ffee00;
    border: 1.5px solid #000000;
    padding: 1px 6px;
    font-size: 0.75rem;
    font-weight: 800;
  }

  .license-actions {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .lib-link {
    color: #000000;
    display: flex;
    align-items: center;
    padding: 4px;
  }

  .toggle-btn {
    background: transparent;
    border: none;
    cursor: pointer;
    display: flex;
    align-items: center;
    padding: 2px;
  }

  .license-body {
    padding: 12px;
    border-top: 2px dashed #000000;
    background: #fdfdfd;
  }

  .copyright-line {
    font-size: 0.8rem;
    font-weight: 700;
    margin-bottom: 8px;
    color: #333333;
  }

  .license-text {
    margin: 0;
    font-family: monospace;
    font-size: 0.75rem;
    line-height: 1.4;
    white-space: pre-wrap;
    background: #f0f0ec;
    border: 2px solid #000000;
    padding: 8px;
    max-height: 180px;
    overflow-y: auto;
  }

  .modal-footer {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 12px 16px;
    background: #f4f4f0;
    border-top: 3px solid #000000;
  }

  .btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 8px 16px;
    border: 3px solid #000000;
    font-family: inherit;
    font-weight: 800;
    font-size: 0.9rem;
    cursor: pointer;
    box-shadow: 4px 4px 0 #000000;
    transition: transform 0.05s, box-shadow 0.05s;
  }

  .btn:active {
    transform: translate(2px, 2px);
    box-shadow: 2px 2px 0 #000000;
  }

  .btn-primary {
    background: #ffee00;
  }

  .btn-secondary {
    background: #ffffff;
  }

  .btn-icon {
    padding: 4px;
    background: #ffffff;
    border: 2px solid #000000;
    box-shadow: 2px 2px 0 #000000;
  }
</style>
