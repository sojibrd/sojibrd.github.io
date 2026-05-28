import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { service } from '@ember/service';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';

export default class ShareButton extends Component {
  // @matchId  — required
  // @matchName — required
  // @dropUp   — boolean, open dropdown upward (default: false)

  @service toast;

  @tracked showMenu = false;

  constructor() {
    super(...arguments);
    this._closeOnDocClick = () => { this.showMenu = false; };
    document.addEventListener('click', this._closeOnDocClick);
  }

  willDestroy() {
    super.willDestroy();
    document.removeEventListener('click', this._closeOnDocClick);
  }

  get url() {
    return `${window.location.origin}/match/match-details?gameid=${this.args.matchId}`;
  }

  get _sportEmoji() {
    const map = { cricket: '🏏', football: '⚽', basketball: '🏀', tennis: '🎾', baseball: '⚾' };
    return map[(this.args.sportType ?? '').toLowerCase()] ?? '🏆';
  }

  get shareText() {
    const name   = this.args.matchName ?? '';
    const date   = this.args.matchDate ?? '';
    const isLive = this.args.isLive    ?? false;

    const lines = [`${this._sportEmoji} ${name}`];
    if (isLive) {
      lines.push('🔴 Live Now');
    } else if (date) {
      lines.push(`📅 ${date}`);
    }
    lines.push('👉 Watch on Spordium');
    return lines.join('\n');
  }

  get twitterText() {
    const name   = this.args.matchName ?? '';
    const isLive = this.args.isLive    ?? false;
    const status = isLive ? '🔴 Live' : '📅 Upcoming';
    return `${this._sportEmoji} ${name} | ${status} on Spordium!`;
  }

  @action
  toggle(event) {
    event.preventDefault();
    event.stopPropagation();
    this.showMenu = !this.showMenu;
    this.args.onMenuChange?.(this.showMenu);
  }

  @action
  shareTo(platform, event) {
    event.preventDefault();
    event.stopPropagation();
    const { url, shareText, twitterText } = this;
    const urls = {
      whatsapp: `https://wa.me/?text=${encodeURIComponent(shareText + '\n' + url)}`,
      facebook: `https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(url)}`,
      twitter:  `https://twitter.com/intent/tweet?url=${encodeURIComponent(url)}&text=${encodeURIComponent(twitterText)}`,
    };
    window.open(urls[platform], '_blank', 'noopener,noreferrer');
    this.showMenu = false;
  }

  @action
  copyLink(event) {
    event.preventDefault();
    event.stopPropagation();
    navigator.clipboard.writeText(this.url);
    this.toast.success('Link copied to clipboard');
    this.showMenu = false;
  }

  <template>
    <div class="relative {{if this.showMenu 'z-50'}}">
      <button
        type="button"
        title="Share"
        {{on "click" this.toggle}}
        class="p-1 rounded-full text-gray-400 dark:text-white/40
               hover:text-gray-700 dark:hover:text-white/80
               hover:bg-gray-100 dark:hover:bg-white/10
               transition-colors duration-150"
      >
        <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/>
          <line x1="8.59" y1="13.51" x2="15.42" y2="17.49"/><line x1="15.41" y1="6.51" x2="8.59" y2="10.49"/>
        </svg>
      </button>

      {{#if this.showMenu}}
        <div class="absolute right-0 z-50 min-w-[140px]
                    {{if @dropUp 'bottom-full mb-1' 'top-full mt-1'}}
                    bg-white dark:bg-[#0f1923]
                    border border-gray-200 dark:border-white/10
                    rounded-xl shadow-2xl py-1 overflow-hidden">

          <button type="button" {{on "click" (fn this.shareTo 'whatsapp')}}
            class="flex items-center gap-2.5 w-full px-3 py-2 text-[11px]
                   text-gray-700 dark:text-white/70
                   hover:text-gray-900 dark:hover:text-white
                   hover:bg-gray-50 dark:hover:bg-white/[0.08] transition-colors">
            <svg class="w-3.5 h-3.5 text-[#25D366] shrink-0" viewBox="0 0 24 24" fill="currentColor">
              <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z"/>
              <path d="M12 0C5.373 0 0 5.373 0 12c0 2.123.553 4.117 1.522 5.847L0 24l6.335-1.502A11.95 11.95 0 0012 24c6.627 0 12-5.373 12-12S18.627 0 12 0zm0 21.818a9.792 9.792 0 01-5.003-1.376l-.36-.213-3.757.891.952-3.653-.234-.376A9.818 9.818 0 012.182 12C2.182 6.57 6.57 2.182 12 2.182S21.818 6.57 21.818 12 17.43 21.818 12 21.818z"/>
            </svg>
            WhatsApp
          </button>

          <button type="button" {{on "click" (fn this.shareTo 'facebook')}}
            class="flex items-center gap-2.5 w-full px-3 py-2 text-[11px]
                   text-gray-700 dark:text-white/70
                   hover:text-gray-900 dark:hover:text-white
                   hover:bg-gray-50 dark:hover:bg-white/[0.08] transition-colors">
            <svg class="w-3.5 h-3.5 text-[#1877F2] shrink-0" viewBox="0 0 24 24" fill="currentColor">
              <path d="M24 12.073C24 5.405 18.627 0 12 0S0 5.405 0 12.073C0 18.1 4.388 23.094 10.125 24v-8.437H7.078v-3.49h3.047V9.41c0-3.025 1.791-4.697 4.533-4.697 1.312 0 2.686.236 2.686.236v2.97h-1.513c-1.491 0-1.956.93-1.956 1.887v2.267h3.328l-.532 3.49h-2.796V24C19.612 23.094 24 18.1 24 12.073z"/>
            </svg>
            Facebook
          </button>

          <button type="button" {{on "click" (fn this.shareTo 'twitter')}}
            class="flex items-center gap-2.5 w-full px-3 py-2 text-[11px]
                   text-gray-700 dark:text-white/70
                   hover:text-gray-900 dark:hover:text-white
                   hover:bg-gray-50 dark:hover:bg-white/[0.08] transition-colors">
            <svg class="w-3.5 h-3.5 text-gray-800 dark:text-white/80 shrink-0" viewBox="0 0 24 24" fill="currentColor">
              <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-4.714-6.231-5.401 6.231H2.744l7.73-8.835L1.254 2.25H8.08l4.253 5.622zm-1.161 17.52h1.833L7.084 4.126H5.117z"/>
            </svg>
            X (Twitter)
          </button>

          <div class="h-px bg-gray-100 dark:bg-white/[0.08] mx-2 my-1"></div>

          <button type="button" {{on "click" this.copyLink}}
            class="flex items-center gap-2.5 w-full px-3 py-2 text-[11px]
                   text-gray-700 dark:text-white/70
                   hover:text-gray-900 dark:hover:text-white
                   hover:bg-gray-50 dark:hover:bg-white/[0.08] transition-colors">
            <svg class="w-3.5 h-3.5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1"/>
            </svg>
            Copy Link
          </button>

        </div>
      {{/if}}
    </div>
  </template>
}
