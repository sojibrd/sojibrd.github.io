import Component from '@glimmer/component';
import { on } from '@ember/modifier';

const ICONS = {
  success: `<svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>`,
  error: `<svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>`,
  warning: `<svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/></svg>`,
  info: `<svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>`,
};

const STYLES = {
  success: 'bg-emerald-50 border-emerald-200 text-emerald-800',
  error: 'bg-red-50 border-red-200 text-red-800',
  warning: 'bg-amber-50 border-amber-200 text-amber-800',
  info: 'bg-blue-50 border-blue-200 text-blue-800',
};

const ICON_STYLES = {
  success: 'text-emerald-500',
  error: 'text-red-500',
  warning: 'text-amber-500',
  info: 'text-blue-500',
};

const CLOSE_STYLES = {
  success: 'hover:bg-emerald-100 text-emerald-400 hover:text-emerald-600',
  error: 'hover:bg-red-100 text-red-400 hover:text-red-600',
  warning: 'hover:bg-amber-100 text-amber-400 hover:text-amber-600',
  info: 'hover:bg-blue-100 text-blue-400 hover:text-blue-600',
};

export default class ToastItem extends Component {
  get type() {
    return this.args.toast?.type || 'info';
  }

  get containerClass() {
    return STYLES[this.type] || STYLES.info;
  }

  get iconClass() {
    return ICON_STYLES[this.type] || ICON_STYLES.info;
  }

  get closeClass() {
    return CLOSE_STYLES[this.type] || CLOSE_STYLES.info;
  }

  get iconSvg() {
    return ICONS[this.type] || ICONS.info;
  }

  <template>
    <div
      class="flex items-start gap-3 w-80 border rounded-xl px-4 py-3 shadow-lg
        toast-slide-in
        {{this.containerClass}}"
      role="alert"
    >
      {{! Icon }}
      <span class="shrink-0 mt-0.5 {{this.iconClass}}">
        {{{this.iconSvg}}}
      </span>

      {{! Message }}
      <p class="flex-1 text-sm font-medium leading-snug">
        {{@toast.message}}
      </p>

      {{! Close button }}
      <button
        type="button"
        class="shrink-0 -mt-1 -mr-1 p-1 rounded-lg transition-colors
          {{this.closeClass}}"
        {{on "click" @onDismiss}}
      >
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
    </div>
  </template>
}
