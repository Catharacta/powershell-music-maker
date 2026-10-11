<script lang="ts">
  import { onMount, tick } from 'svelte';
  import { ChevronDown } from '@lucide/svelte';

  export interface SelectOption {
    value: string | number;
    label: string;
  }

  let {
    value = $bindable(),
    options = [],
    id = undefined,
    style = undefined,
    className = '',
    onchange = undefined
  }: {
    value: string | number;
    options: SelectOption[];
    id?: string;
    style?: string;
    className?: string;
    onchange?: (val: string | number) => void;
  } = $props();

  let open = $state(false);
  let containerEl = $state<HTMLDivElement | null>(null);
  let menuEl = $state<HTMLDivElement | null>(null);

  const selectedOption = $derived(options.find((opt) => opt.value === value));
  const displayText = $derived(selectedOption ? selectedOption.label : String(value));

  function toggle() {
    open = !open;
  }

  function select(opt: SelectOption) {
    value = opt.value;
    open = false;
    if (onchange) {
      onchange(opt.value);
    }
  }

  function handleKeyDown(e: KeyboardEvent) {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      open = !open;
    } else if (e.key === 'Escape') {
      open = false;
    } else if (e.key === 'ArrowDown') {
      e.preventDefault();
      if (!open) {
        open = true;
      } else {
        const idx = options.findIndex((o) => o.value === value);
        if (idx < options.length - 1) {
          select(options[idx + 1]);
        }
      }
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      if (!open) {
        open = true;
      } else {
        const idx = options.findIndex((o) => o.value === value);
        if (idx > 0) {
          select(options[idx - 1]);
        }
      }
    }
  }

  onMount(() => {
    function handleClickOutside(e: MouseEvent) {
      if (containerEl && !containerEl.contains(e.target as Node)) {
        open = false;
      }
    }
    window.addEventListener('pointerdown', handleClickOutside);
    return () => {
      window.removeEventListener('pointerdown', handleClickOutside);
    };
  });
</script>

<div
  class="neo-select-wrapper {className}"
  {style}
  bind:this={containerEl}
>
  <button
    type="button"
    class="neo-select-trigger"
    class:open
    {id}
    onclick={toggle}
    onkeydown={handleKeyDown}
    aria-haspopup="listbox"
    aria-expanded={open}
  >
    <span class="neo-select-label">{displayText}</span>
    <span class="neo-select-arrow" class:rotated={open}>
      <ChevronDown size={16} strokeWidth={3} />
    </span>
  </button>

  {#if open}
    <div
      class="neo-select-menu"
      role="listbox"
      bind:this={menuEl}
    >
      {#each options as opt (opt.value)}
        <div
          class="neo-select-item"
          class:selected={opt.value === value}
          role="option"
          aria-selected={opt.value === value}
          tabindex="-1"
          onclick={() => select(opt)}
          onkeydown={(e) => {
            if (e.key === 'Enter') select(opt);
          }}
        >
          {opt.label}
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .neo-select-wrapper {
    position: relative;
    display: inline-block;
    vertical-align: middle;
    min-width: 0;
  }

  .neo-select-trigger {
    display: inline-flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
    width: 100%;
    background: var(--paper);
    border: var(--border);
    box-shadow: 3px 3px 0 var(--ink);
    padding: 6px 10px;
    font-family: inherit;
    font-size: 13px;
    font-weight: 700;
    color: var(--ink);
    cursor: pointer;
    text-transform: none;
    text-align: left;
    white-space: nowrap;
    user-select: none;
    transition: none;
  }

  .neo-select-trigger:hover {
    background: #fafaf0;
  }

  .neo-select-trigger.open {
    box-shadow: 1px 1px 0 var(--ink);
    transform: translate(2px, 2px);
    background: var(--paper);
  }

  .neo-select-label {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    flex: 1;
    min-width: 0;
  }

  .neo-select-arrow {
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    transition: transform 0.1s ease;
  }

  .neo-select-arrow.rotated {
    transform: rotate(180deg);
  }

  .neo-select-menu {
    position: absolute;
    top: calc(100% + 4px);
    left: 0;
    min-width: 100%;
    width: max-content;
    max-width: 320px;
    max-height: 240px;
    overflow-y: auto;
    background: var(--paper);
    border: var(--border);
    box-shadow: 6px 6px 0 var(--ink);
    z-index: 100;
    display: flex;
    flex-direction: column;
  }

  .neo-select-item {
    padding: 6px 12px;
    font-family: inherit;
    font-size: 13px;
    font-weight: 700;
    color: var(--ink);
    cursor: pointer;
    white-space: nowrap;
    user-select: none;
    border-bottom: 1px dashed var(--ink);
  }

  .neo-select-item:last-child {
    border-bottom: none;
  }

  .neo-select-item:hover {
    background: var(--c-beep);
  }

  .neo-select-item.selected {
    background: var(--c-gs);
    font-weight: 900;
  }

  .neo-select-item.selected:hover {
    background: var(--c-gs);
  }
</style>
