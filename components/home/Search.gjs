import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { service } from '@ember/service';
import { on } from '@ember/modifier';
import { fn, get } from '@ember/helper';
import config from 'spordium/config/environment';
import { or, gt } from 'ember-truth-helpers';
import lucideIcon from 'spordium/helpers/lucide-icon';

const SEARCH_URL = 'https://khelasearch.adnanfoundation.com/search/global-search/';
const IMG_BASE = `${config.APP.S3_BUCKET_URL}/`;
const LIMIT = 8;

function imgUrl(pic) {
  return pic ? `${IMG_BASE}${pic}` : '/assets/avatar/cricket_player.png';
}

function fullName(obj) {
  const name = obj?.player_fullname ?? obj?.user_fullname;
  const first = name?.first_name?.trim() ?? '';
  const last = name?.last_name?.trim() ?? '';
  return [first, last].filter(Boolean).join(' ') || obj?.user_username || '—';
}

function formatDate(ts) {
  if (!ts) return '';
  return new Date(ts).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
}

export default class SearchBar extends Component {
  @service router;

  @tracked value = '';
  @tracked isFocused = false;
  @tracked results = null;
  @tracked isLoading = false;
  @tracked showDropdown = false;

  _debounceTimer = null;
  _blurTimer = null;
  _cache = new Map();

  willDestroy() {
    super.willDestroy(...arguments);
    this._cache.clear();
    clearTimeout(this._debounceTimer);
    clearTimeout(this._blurTimer);
  }

  @action
  onInput(event) {
    this.value = event.target.value;
    this._scheduleSearch(this.value);
  }

  @action
  onFocus() {
    this.isFocused = true;
    clearTimeout(this._blurTimer);
    if (this.results) this.showDropdown = true;
  }

  @action
  onBlur() {
    this.isFocused = false;
    this._blurTimer = setTimeout(() => {
      this.showDropdown = false;
    }, 200);
  }

  @action
  onKeyDown(event) {
    if (event.key === 'Escape') this.clearSearch();
  }

  @action
  clearSearch() {
    this.value = '';
    this.results = null;
    this.showDropdown = false;
  }

  @action
  preventBlur(event) {
    event.preventDefault();
  }

  @action
  goToGame(gameId) {
    this.showDropdown = false;
    this.value = '';
    this.results = null;
    this.router.transitionTo('match.match-details', { queryParams: { gameid: gameId } });
  }

  @action
  goToPlayer(username) {
    this.showDropdown = false;
    this.value = '';
    this.results = null;
    this.router.transitionTo('player', username);
  }

  _scheduleSearch(query) {
    clearTimeout(this._debounceTimer);
    if (!query.trim()) {
      this.results = null;
      this.showDropdown = false;
      return;
    }
    this._debounceTimer = setTimeout(() => this._doSearch(query), 350);
  }

  async _doSearch(query) {
    const cached = this._cache.get(query);
    if (cached && Date.now() - cached.ts < 60_000) {
      this.results = cached.data;
      this.showDropdown = true;
      return;
    }

    this.isLoading = true;
    try {
      const url = `${SEARCH_URL}?search_data=${encodeURIComponent(query)}&limit=${LIMIT}`;
      const res = await fetch(url);
      if (res.ok) {
        const data = await res.json();
        this._cache.set(query, { data, ts: Date.now() });
        this._evictStaleCache();
        this.results = data;
        this.showDropdown = true;
      } else {
        this.results = null;
      }
    } catch {
      this.results = null;
    } finally {
      this.isLoading = false;
    }
  }

  _evictStaleCache() {
    const cutoff = Date.now() - 60_000;
    for (const [key, entry] of this._cache) {
      if (entry.ts < cutoff) this._cache.delete(key);
    }
  }

  get players() {
    return this.results?.results?.find((r) => r.index === 'players')?.results ?? [];
  }

  get userRoles() {
    return this.results?.results?.find((r) => r.index === 'user_roles')?.results ?? [];
  }

  get games() {
    return this.results?.results?.find((r) => r.index === 'games')?.results ?? [];
  }

  get hasAnyResults() {
    return this.players.length > 0 || this.userRoles.length > 0 || this.games.length > 0;
  }

  <template>
    <style>
      @keyframes cursor-blink { 0%,49%{opacity:1} 50%,100%{opacity:0} }
      .animate-cursor { animation: cursor-blink 1s step-start infinite; }
      @keyframes dropdown-in {
        from { opacity: 0; transform: translateY(-6px) scale(0.98); }
        to   { opacity: 1; transform: translateY(0)   scale(1);    }
      }
      .dropdown-animate { animation: dropdown-in 0.15s ease-out forwards; }
      .spord-icon-img { filter: brightness(0) invert(1); }
      @keyframes spord-pulse {
        0%,100% { opacity:.16; transform:scale(1) rotate(0deg); }
        50%      { opacity:.24; transform:scale(1.06) rotate(4deg); }
      }
      @keyframes spord-focus-pop {
        0%   { opacity:.16; transform:scale(1) rotate(0deg); }
        28%  { opacity:.75; transform:scale(1.4) rotate(-22deg); }
        62%  { opacity:.52; transform:scale(1.14) rotate(8deg); }
        82%  { opacity:.47; transform:scale(1.08) rotate(-3deg); }
        100% { opacity:.45; transform:scale(1.1) rotate(0deg); }
      }
      @keyframes spord-spin { to { transform:rotate(360deg); } }
      .spord-idle    { animation: spord-pulse 3s ease-in-out infinite; }
      .spord-focused { animation: spord-focus-pop .48s cubic-bezier(.34,1.56,.64,1) forwards; }
      .spord-loading { opacity:.65; animation: spord-spin .75s linear infinite; }
      @keyframes search-ring {
        0%   { transform:scale(.7); opacity:.65; }
        100% { transform:scale(2.6); opacity:0; }
      }
      @keyframes search-icon-pulse {
        0%,100% { opacity:.6; transform:scale(1); }
        50%     { opacity:1;  transform:scale(1.2); }
      }
      .search-ping-ring  { animation: search-ring 1.1s ease-out infinite; }
      .search-icon-pulse { animation: search-icon-pulse .75s ease-in-out infinite; }
    </style>

    <div class="w-full max-w-xl mx-auto relative">

      {{! ── Search bar ── }}
      <div
        class="flex items-center gap-2.5 px-3.5 py-2 text-white
               bg-white/15 backdrop-blur-md
               border border-white/30
               transition-all duration-150
               {{if this.showDropdown 'rounded-t-xl rounded-b-none border-b-transparent' 'rounded-xl'}}"
      >

        {{! Magnifier / loader }}
        {{#if this.isLoading}}
          <div class="relative flex-shrink-0 w-4 h-4 flex items-center justify-center">
            <span class="absolute inset-0 rounded-full bg-white/30 search-ping-ring"></span>
            {{lucideIcon "search" size=14 class="text-white/80 relative z-10 search-icon-pulse"}}
          </div>
        {{else}}
          {{lucideIcon "search" size=16 class="text-white/60 flex-shrink-0"}}
        {{/if}}

        {{! Input + blinking cursor }}
        <div class="relative flex-1 flex items-center h-5">
          <input
            type="text"
            aria-label="Search players, games, people"
            placeholder="Search players, games, people…"
            class="absolute inset-0 w-full bg-transparent border-none outline-none ring-0
                   text-sm text-white placeholder-white/40 caret-transparent"
            value={{this.value}}
            {{on "input"   this.onInput}}
            {{on "focus"   this.onFocus}}
            {{on "blur"    this.onBlur}}
            {{on "keydown" this.onKeyDown}}
          />
          {{#if this.isFocused}}
            {{#unless this.value}}
              <span
                aria-hidden="true"
                class="animate-cursor absolute left-0 top-1/2 -translate-y-1/2
                       w-px h-3.5 bg-white/60 rounded-sm pointer-events-none"
              ></span>
            {{/unless}}
          {{/if}}
        </div>

        {{! Clear button or chevron }}
        <div class="flex items-center gap-1.5 flex-shrink-0">
          <div class="w-[18px] h-[18px] {{if this.isLoading 'spord-loading' (if this.isFocused 'spord-focused' 'spord-idle')}}">
            <img src="/spord_ico.svg" class="w-full h-full spord-icon-img" alt="" />
          </div>
          {{#if this.value}}
            <button
              type="button"
              aria-label="Clear search"
              class="text-white/40 hover:text-white/80 transition-colors"
              {{on "click" this.clearSearch}}
            >
              <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          {{/if}}
        </div>

      </div>

      {{! ── Dropdown ── }}
      {{#if this.showDropdown}}
        <div
          class="dropdown-animate absolute left-0 right-0 top-full z-50
                 bg-black/55 backdrop-blur-2xl
                 border border-t-0 border-white/20
                 rounded-b-xl shadow-2xl
                 max-h-[480px] overflow-y-auto"
          {{on "mousedown" this.preventBlur}}
        >

          {{#if this.hasAnyResults}}

            {{! Players }}
            {{#if this.players.length}}
              <div class="px-3 pt-3 pb-1">
                <p class="text-white/35 text-[10px] font-semibold uppercase tracking-widest mb-1.5 px-1">Players</p>
                {{#each this.players as |player|}}
                  <button
                    type="button"
                    class="w-full flex items-center gap-3 px-2 py-2 rounded-lg
                           hover:bg-white/10 active:bg-white/15
                           transition-colors duration-100 text-left"
                    {{on "click" (fn this.goToPlayer player.user_username)}}
                  >
                    <img
                      src={{imgUrl player.player_primary_pic}}
                      alt=""
                      class="w-9 h-9 rounded-full object-cover flex-shrink-0 ring-1 ring-white/20"
                      onerror="this.src='/assets/avatar/cricket_player.png'"
                    />
                    <div class="flex-1 min-w-0">
                      <p class="text-white text-sm font-semibold leading-tight truncate">{{fullName player}}</p>
                      <p class="text-white/40 text-xs truncate">@{{player.user_username}}</p>
                    </div>
                    {{#if player.skills.length}}
                      <span class="hidden sm:block text-[10px] text-indigo-300 bg-indigo-500/20 px-2 py-0.5 rounded-full flex-shrink-0 max-w-[120px] truncate">
                        {{get player.skills 0}}
                      </span>
                    {{/if}}
                  </button>
                {{/each}}
              </div>
            {{/if}}

            {{! Divider between sections }}
            {{#if this.players.length}}
              {{#if (or this.userRoles.length this.games.length)}}
                <div class="mx-3 border-t border-white/10 my-1"></div>
              {{/if}}
            {{/if}}

            {{! People / User Roles }}
            {{#if this.userRoles.length}}
              <div class="px-3 pt-2 pb-1">
                <p class="text-white/35 text-[10px] font-semibold uppercase tracking-widest mb-1.5 px-1">People</p>
                {{#each this.userRoles as |user|}}
                  <button
                    type="button"
                    class="w-full flex items-center gap-3 px-2 py-2 rounded-lg
                           hover:bg-white/10 active:bg-white/15
                           transition-colors duration-100 text-left"
                    {{on "click" (fn this.goToPlayer user.user_username)}}
                  >
                    <img
                      src={{imgUrl user.user_primary_pic}}
                      alt=""
                      class="w-9 h-9 rounded-full object-cover flex-shrink-0 ring-1 ring-white/20"
                      onerror="this.src='/assets/avatar/cricket_player.png'"
                    />
                    <div class="flex-1 min-w-0">
                      <p class="text-white text-sm font-semibold leading-tight truncate">{{fullName user}}</p>
                      <p class="text-white/40 text-xs truncate">@{{user.user_username}}</p>
                    </div>
                    <div class="flex gap-1 flex-shrink-0">
                      {{#if user.cricketumipireprofile}}
                        <span class="text-[10px] text-amber-300 bg-amber-500/15 border border-amber-500/20 px-2 py-0.5 rounded-full">Umpire</span>
                      {{/if}}
                      {{#if user.cricketscorerprofile}}
                        <span class="text-[10px] text-sky-300 bg-sky-500/15 border border-sky-500/20 px-2 py-0.5 rounded-full">Scorer</span>
                      {{/if}}
                    </div>
                  </button>
                {{/each}}
              </div>
            {{/if}}

            {{! Divider }}
            {{#if this.games.length}}
              {{#if (or this.players.length this.userRoles.length)}}
                <div class="mx-3 border-t border-white/10 my-1"></div>
              {{/if}}
            {{/if}}

            {{! Games }}
            {{#if this.games.length}}
              <div class="px-3 pt-2 pb-1">
                <p class="text-white/35 text-[10px] font-semibold uppercase tracking-widest mb-1.5 px-1">Games</p>
                {{#each this.games as |game|}}
                  <button
                    type="button"
                    class="w-full flex items-center gap-3 px-2 py-2 rounded-lg
                           hover:bg-white/10 active:bg-white/15
                           transition-colors duration-100 text-left"
                    {{on "click" (fn this.goToGame game.game_id)}}
                  >
                    <div class="w-9 h-9 rounded-lg bg-emerald-500/15 border border-emerald-500/20 flex items-center justify-center flex-shrink-0">
                      <span class="text-base leading-none">🏏</span>
                    </div>
                    <div class="flex-1 min-w-0">
                      <p class="text-white text-sm font-semibold leading-tight truncate">{{game.game_name}}</p>
                      <p class="text-white/40 text-xs truncate">{{game.gamefield_name}} · {{formatDate game.game_datetime}}</p>
                    </div>
                  </button>
                {{/each}}
              </div>
            {{/if}}

            {{! Footer }}
            <div class="px-4 py-2 mt-1 border-t border-white/10 flex items-center justify-between">
              <p class="text-white/25 text-[10px]">{{this.results.total}} result{{#if (gt this.results.total 1)}}s{{/if}}</p>
              <p class="text-white/25 text-[10px]">
                <kbd class="px-1.5 py-0.5 rounded bg-white/10 text-white/40 font-mono text-[9px]">esc</kbd>
                to close
              </p>
            </div>

          {{else}}
            {{! Empty state }}
            <div class="flex flex-col items-center gap-2.5 py-10 px-4">
              <div class="w-12 h-12 rounded-full bg-white/5 flex items-center justify-center">
                <svg class="w-5 h-5 text-white/25" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                  <circle cx="10.5" cy="10.5" r="6.5" />
                  <path stroke-linecap="round" d="M15.5 15.5L21 21" />
                </svg>
              </div>
              <p class="text-white/40 text-sm text-center">
                No results for
                <span class="text-white/65 font-medium">"{{this.value}}"</span>
              </p>
            </div>
          {{/if}}

        </div>
      {{/if}}

    </div>
  </template>
}
