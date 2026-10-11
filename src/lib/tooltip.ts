// ネオブルータリズム・ツールチップ アクション
export type TooltipPosition = 'top' | 'bottom' | 'left' | 'right';

export interface TooltipOptions {
  text?: string;
  pos?: TooltipPosition;
}

let activeTooltipEl: HTMLDivElement | null = null;
let currentTarget: HTMLElement | null = null;
let showTimeout: number | null = null;

function ensureTooltipElement(): HTMLDivElement {
  if (!activeTooltipEl) {
    activeTooltipEl = document.createElement('div');
    activeTooltipEl.className = 'neo-tooltip';
    activeTooltipEl.setAttribute('role', 'tooltip');
    document.body.appendChild(activeTooltipEl);
  }
  return activeTooltipEl;
}

function hideTooltip() {
  if (showTimeout !== null) {
    clearTimeout(showTimeout);
    showTimeout = null;
  }
  if (activeTooltipEl) {
    activeTooltipEl.classList.remove('visible');
    currentTarget = null;
  }
}

function updatePosition(node: HTMLElement, pos: TooltipPosition) {
  if (!activeTooltipEl) return;
  const rect = node.getBoundingClientRect();
  const tipRect = activeTooltipEl.getBoundingClientRect();
  const gap = 6;

  let top = 0;
  let left = 0;

  switch (pos) {
    case 'top':
      top = rect.top - tipRect.height - gap;
      left = rect.left + (rect.width - tipRect.width) / 2;
      break;
    case 'bottom':
      top = rect.bottom + gap;
      left = rect.left + (rect.width - tipRect.width) / 2;
      break;
    case 'left':
      top = rect.top + (rect.height - tipRect.height) / 2;
      left = rect.left - tipRect.width - gap;
      break;
    case 'right':
      top = rect.top + (rect.height - tipRect.height) / 2;
      left = rect.right + gap;
      break;
  }

  // 画面端のクリッピング防止
  const pad = 6;
  if (left < pad) left = pad;
  if (left + tipRect.width > window.innerWidth - pad) {
    left = window.innerWidth - tipRect.width - pad;
  }
  if (top < pad) {
    // 画面上部にはみ出る場合は下に反転
    top = rect.bottom + gap;
  } else if (top + tipRect.height > window.innerHeight - pad) {
    // 画面下部にはみ出る場合は上に反転
    top = rect.top - tipRect.height - gap;
  }

  activeTooltipEl.style.top = `${Math.round(top)}px`;
  activeTooltipEl.style.left = `${Math.round(left)}px`;
}

export function tooltip(node: HTMLElement, options: string | TooltipOptions | undefined) {
  let opts: TooltipOptions = typeof options === 'string' ? { text: options } : (options ?? {});

  function getTooltipText(): string {
    return (opts.text || node.getAttribute('data-tooltip') || '').trim();
  }

  function show() {
    const text = getTooltipText();
    if (!text) return;

    if (showTimeout !== null) clearTimeout(showTimeout);

    // 短い遅延（120ms）で表示
    showTimeout = window.setTimeout(() => {
      const tip = ensureTooltipElement();
      tip.textContent = text;
      currentTarget = node;
      tip.classList.add('visible');
      updatePosition(node, opts.pos ?? 'bottom');
    }, 120);
  }

  function handleMouseEnter() {
    show();
  }

  function handleMouseLeave() {
    hideTooltip();
  }

  function handleFocus() {
    show();
  }

  function handleBlur() {
    hideTooltip();
  }

  node.addEventListener('mouseenter', handleMouseEnter);
  node.addEventListener('mouseleave', handleMouseLeave);
  node.addEventListener('focus', handleFocus);
  node.addEventListener('blur', handleBlur);

  return {
    update(newOptions: string | TooltipOptions | undefined) {
      opts = typeof newOptions === 'string' ? { text: newOptions } : (newOptions ?? {});
      if (currentTarget === node) {
        const text = getTooltipText();
        if (text && activeTooltipEl) {
          activeTooltipEl.textContent = text;
          updatePosition(node, opts.pos ?? 'bottom');
        } else {
          hideTooltip();
        }
      }
    },
    destroy() {
      node.removeEventListener('mouseenter', handleMouseEnter);
      node.removeEventListener('mouseleave', handleMouseLeave);
      node.removeEventListener('focus', handleFocus);
      node.removeEventListener('blur', handleBlur);
      if (currentTarget === node) {
        hideTooltip();
      }
    }
  };
}
