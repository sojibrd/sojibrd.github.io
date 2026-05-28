import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { service } from '@ember/service';
import { on } from '@ember/modifier';
import { fn, array } from '@ember/helper';
import { eq } from 'ember-truth-helpers';
import config from 'spordium/config/environment';
import { getUserLocation, onInit } from '../../utils/utility.helper';
import { LinkTo } from '@ember/routing';

const DEFAULT_LAT = 23.79431617060116;
const DEFAULT_LONG = 90.40723691635932;
const DEFAULT_COUNTRY = 'BD';
const PAGE_SIZE = 10;
const IMG_BASE = `${config.APP.S3_BUCKET_URL}/`;

function imgUrl(pic) {
  return pic ? `${IMG_BASE}${pic}` : null;
}

function fullName(player) {
  const first = player?.player_fullname?.first_name?.trim() ?? '';
  const last = player?.player_fullname?.last_name?.trim() ?? '';
  return [first, last].filter(Boolean).join(' ') || player?.user_username || '—';
}

function defaultAvatar() {
  return '/assets/avatar/cricket_player.png';
}

function stat(val) {
  return val != null && val !== '' ? val : 0;
}

function teamRating(player) {
  const r = player?.team_rating;
  return r != null ? r : '0.0';
}

export default class Player extends Component {
  @service router;

  @tracked players = [];
  @tracked isLoading = true;
  @tracked isLoadingMore = false;
  @tracked error = null;
  @tracked totalCount = 0;
  @tracked currentPage = 1;
  @tracked hasMore = true;
  @tracked activeTab = 'cricket';
  @tracked activeGender = 'all';
  @tracked searchQuery = '';

  @tracked searchResults = [];
  @tracked isSearchOpen = false;
  @tracked isSearchLoading = false;
  @tracked highlightedIndex = -1;

  _searchDebounceTimer = null;
  _searchContainerEl = null;
  _sentinelObserver = null;

  constructor(owner, args) {
    super(owner, args);
    this._onDocumentMousedown = this._onDocumentMousedown.bind(this);
    document.addEventListener('mousedown', this._onDocumentMousedown);
    this.fetchPlayers();
  }

  willDestroy() {
    super.willDestroy();
    document.removeEventListener('mousedown', this._onDocumentMousedown);
    clearTimeout(this._searchDebounceTimer);
    if (this._sentinelObserver) {
      this._sentinelObserver.disconnect();
    }
  }

  _onDocumentMousedown(event) {
    if (this._searchContainerEl && !this._searchContainerEl.contains(event.target)) {
      this.isSearchOpen = false;
      this.highlightedIndex = -1;
    }
  }

  get skeletons() {
    return Array.from({ length: PAGE_SIZE }, (_, i) => i);
  }
  get hasPlayers() {
    return !this.isLoading && !this.error && this.players.length > 0;
  }
  get isEmpty() {
    return !this.isLoading && !this.error && this.players.length === 0;
  }
  get hasSearchResults() {
    return this.searchResults.length > 0;
  }

  async _getLocation() {
    let lat = DEFAULT_LAT, long = DEFAULT_LONG;
    try {
      const location = await getUserLocation();
      if (location.status && location.geo?.lat && location.geo?.long) {
        lat = location.geo.lat;
        long = location.geo.long;
      }
    } catch {}
    return { lat, long };
  }

  async fetchPlayers() {
    this.isLoading = true;
    this.error = null;
    this.players = [];
    this.currentPage = 1;
    this.hasMore = true;

    const { lat, long } = await this._getLocation();

    try {
      const sexParam = this.activeGender !== 'all' ? `&user_sex=${this.activeGender}` : '';
      const url = `https://khelasearch.adnanfoundation.com/search/cricket-player-search/?latitude=${lat}&longitude=${long}&limit=${PAGE_SIZE}&offset=0&page=1&country_code=${DEFAULT_COUNTRY}${sexParam}`;
      const res = await fetch(url);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json = await res.json();
      const newPlayers = json.results ?? [];
      this.players = newPlayers;
      this.totalCount = json.total ?? json.count ?? newPlayers.length;
      this.hasMore = newPlayers.length > 0 && this.players.length < this.totalCount;
    } catch {
      this.error = 'Failed to load players. Please try again.';
    } finally {
      this.isLoading = false;
    }
  }

  async loadMore() {
    if (!this.hasMore || this.isLoading || this.isLoadingMore) return;
    this.isLoadingMore = true;
    this.currentPage++;

    const { lat, long } = await this._getLocation();

    try {
      const offset = (this.currentPage - 1) * PAGE_SIZE;
      const sexParam = this.activeGender !== 'all' ? `&user_sex=${this.activeGender}` : '';
      const url = `https://khelasearch.adnanfoundation.com/search/cricket-player-search/?latitude=${lat}&longitude=${long}&limit=${PAGE_SIZE}&offset=${offset}&page=${this.currentPage}&country_code=${DEFAULT_COUNTRY}${sexParam}`;
      const res = await fetch(url);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json = await res.json();
      const newPlayers = json.results ?? [];
      this.players = [...this.players, ...newPlayers];
      this.totalCount = json.total ?? json.count ?? this.totalCount;
      this.hasMore = newPlayers.length > 0 && this.players.length < this.totalCount;
    } catch {
      this.currentPage--;
    } finally {
      this.isLoadingMore = false;
    }
  }

  @action retry() { this.fetchPlayers(); }
  @action setTab(tab) { this.activeTab = tab; }
  @action setGender(gender) { this.activeGender = gender; this.fetchPlayers(); }
  @action updateSearch(e) {
    this.searchQuery = e.target.value;
    clearTimeout(this._searchDebounceTimer);
    if (!this.searchQuery.trim()) {
      this.searchResults = [];
      this.isSearchOpen = false;
      this.isSearchLoading = false;
      this.highlightedIndex = -1;
      return;
    }
    this._searchDebounceTimer = setTimeout(() => this.performSearch(), 300);
  }

  @action captureSearchContainer(el) {
    this._searchContainerEl = el;
  }

  @action setupSentinel(el) {
    if (this._sentinelObserver) {
      this._sentinelObserver.disconnect();
    }
    this._sentinelObserver = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting && this.hasMore && !this.isLoading && !this.isLoadingMore) {
          this.loadMore();
        }
      },
      { rootMargin: '200px', threshold: 0 }
    );
    this._sentinelObserver.observe(el);
  }

  @action handleSearchKeydown(event) {
    if (!this.isSearchOpen) return;
    if (event.key === 'ArrowDown') {
      event.preventDefault();
      this.highlightedIndex = Math.min(this.highlightedIndex + 1, this.searchResults.length - 1);
    } else if (event.key === 'ArrowUp') {
      event.preventDefault();
      this.highlightedIndex = Math.max(this.highlightedIndex - 1, -1);
    } else if (event.key === 'Enter') {
      if (this.highlightedIndex >= 0 && this.searchResults[this.highlightedIndex]) {
        this.selectResult(this.searchResults[this.highlightedIndex]);
      }
    } else if (event.key === 'Escape') {
      this.isSearchOpen = false;
      this.highlightedIndex = -1;
    } else if (event.key === 'Tab') {
      this.isSearchOpen = false;
      this.highlightedIndex = -1;
    }
  }

  @action selectResult(player) {
    if (!player?.user_username) return;
    this.isSearchOpen = false;
    this.highlightedIndex = -1;
    this.searchQuery = '';
    this.searchResults = [];
    this.router.transitionTo('player', player.user_username);
  }

  async performSearch() {
    const queryAtCallTime = this.searchQuery;
    this.isSearchLoading = true;
    this.isSearchOpen = true;
    const { lat, long } = await this._getLocation();
    try {
      const url = `https://khelasearch.adnanfoundation.com/search/cricket-player-search/?search_data=${encodeURIComponent(queryAtCallTime)}&latitude=${lat}&longitude=${long}&country_code=${DEFAULT_COUNTRY}`;
      const res = await fetch(url);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json = await res.json();
      if (this.searchQuery !== queryAtCallTime) return;
      this.searchResults = json.results ?? [];
    } catch {
      this.searchResults = [];
      this.isSearchOpen = false;
    } finally {
      this.isSearchLoading = false;
    }
  }

  <template>
    <section class="w-full px-3 sm:px-5 lg:px-8 py-5 sm:py-7 lg:py-8">

      {{! ─── Tabs + Search header ─── }}
      <div class="mb-5 sm:mb-6">

        <div class="relative">
          <div class="absolute bottom-0 left-0 right-0 h-px bg-gray-200 dark:bg-gray-700"></div>
          <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-y-3 sm:gap-4">

            {{! Search — top on mobile, right side on sm+ }}
            <div class="relative pb-1 shrink-0 order-first sm:order-2 w-full sm:w-64 lg:w-72" {{onInit this.captureSearchContainer}}>
              <div class="pointer-events-none absolute inset-y-0 left-3 flex items-center z-10">
                <svg class="w-3.5 h-3.5 text-gray-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                  <circle cx="11" cy="11" r="8" /><path d="M21 21l-4.35-4.35" />
                </svg>
              </div>
              <input type="search" placeholder="Search players…" value={{this.searchQuery}}
                aria-label="Search players"
                {{on "input" this.updateSearch}}
                {{on "keydown" this.handleSearchKeydown}}
                class="w-full pl-8 pr-3 py-1.5 text-sm rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800/80 text-gray-900 dark:text-gray-100 placeholder:text-gray-400 dark:placeholder:text-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-400/50 focus:border-indigo-400 dark:focus:ring-indigo-500/40 dark:focus:border-indigo-500 shadow-sm transition-all duration-200" />

              {{! Search dropdown }}
              <div class="absolute top-full left-0 right-0 mt-2 w-full rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-700/60 shadow-2xl shadow-black/10 dark:shadow-black/40 z-50 overflow-hidden transition-all duration-200 ease-out
                {{if this.isSearchOpen 'opacity-100 translate-y-0 pointer-events-auto' 'opacity-0 -translate-y-1 pointer-events-none'}}">
                {{#if this.isSearchLoading}}
                  <div class="p-3 space-y-2">
                    {{#each (array 1 2 3) as |_|}}
                      <div class="flex items-center gap-3 px-1">
                        <div class="w-9 h-9 rounded-full bg-gray-100 dark:bg-gray-800 animate-pulse shrink-0"></div>
                        <div class="flex-1 space-y-1.5">
                          <div class="h-3 bg-gray-100 dark:bg-gray-800 rounded-full w-3/4 animate-pulse"></div>
                          <div class="h-2.5 bg-gray-100 dark:bg-gray-800 rounded-full w-1/2 animate-pulse"></div>
                        </div>
                      </div>
                    {{/each}}
                  </div>
                {{else if this.hasSearchResults}}
                  <div class="flex items-center justify-between px-3.5 pt-3 pb-1.5">
                    <span class="text-xs font-bold uppercase tracking-widest text-gray-400 dark:text-gray-500">Players</span>
                    <span class="text-xs font-semibold text-indigo-500 dark:text-indigo-400">{{this.searchResults.length}} found</span>
                  </div>
                  <ul class="pb-2 max-h-60 sm:max-h-64 overflow-y-auto">
                    {{#each this.searchResults as |player index|}}
                      <li>
                        <button type="button" {{on "click" (fn this.selectResult player)}}
                          class="w-full flex items-center gap-3 px-3 py-2 text-left transition-all duration-150 group/item
                            {{if (eq this.highlightedIndex index) 'bg-indigo-50 dark:bg-indigo-950/50' 'hover:bg-gray-50 dark:hover:bg-gray-800/50'}}">
                          <div class="relative shrink-0">
                            <img
                              src={{if (imgUrl player.player_primary_pic) (imgUrl player.player_primary_pic) (defaultAvatar)}}
                              alt={{fullName player}}
                              loading="lazy"
                              class="w-9 h-9 rounded-full object-cover object-top ring-2 ring-white dark:ring-gray-800
                                {{if (eq this.highlightedIndex index) 'ring-indigo-200 dark:ring-indigo-800' ''}}"
                            />
                          </div>
                          <div class="min-w-0 flex-1">
                            <p class="text-sm font-bold text-gray-900 dark:text-white truncate leading-tight
                              {{if (eq this.highlightedIndex index) 'text-indigo-700 dark:text-indigo-300' ''}}">
                              {{fullName player}}
                            </p>
                            <span class="text-xs text-gray-400 dark:text-gray-500 truncate">@{{player.user_username}}</span>
                          </div>
                          <svg class="w-3.5 h-3.5 shrink-0 text-gray-300 dark:text-gray-600 opacity-0 group-hover/item:opacity-100 transition-opacity"
                            viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M9 18l6-6-6-6" />
                          </svg>
                        </button>
                      </li>
                    {{/each}}
                  </ul>
                {{else}}
                  <div class="flex flex-col items-center justify-center py-8 px-4 text-center">
                    <div class="w-10 h-10 mb-3 rounded-2xl bg-gray-50 dark:bg-gray-800 flex items-center justify-center">
                      <svg class="w-4 h-4 text-gray-300 dark:text-gray-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                        <circle cx="11" cy="11" r="8" /><path d="M21 21l-4.35-4.35" />
                      </svg>
                    </div>
                    <p class="text-sm font-semibold text-gray-700 dark:text-gray-300">No players found</p>
                    <p class="text-xs text-gray-400 dark:text-gray-500 mt-0.5">Try a different name or username</p>
                  </div>
                {{/if}}
              </div>
            </div>

            {{! Sport tabs — below search on mobile, left side on sm+ }}
            <div class="flex flex-1 min-w-0 items-center gap-0.5 sm:gap-1 overflow-x-auto scrollbar-hide sm:order-1" role="tablist">
              <button type="button" role="tab" {{on "click" (fn this.setTab "cricket")}}
                class="relative flex shrink-0 items-center gap-1.5 sm:gap-2 px-3 sm:px-4 py-2 sm:py-2.5 text-xs sm:text-sm font-semibold transition-colors duration-200 focus:outline-none
                  {{if (eq this.activeTab 'cricket') 'text-indigo-600 dark:text-indigo-400' 'text-gray-500 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200'}}">
                <span class="text-sm sm:text-base">🏏</span>
                Cricket
                {{#if (eq this.activeTab "cricket")}}<span class="absolute bottom-0 left-0 right-0 h-0.5 rounded-full bg-indigo-600 dark:bg-indigo-400"></span>{{/if}}
              </button>
            </div>

          </div>
        </div>

        {{! Gender sub-tabs }}
        <div class="relative mt-1">
          <div class="absolute bottom-0 left-0 right-0 h-px bg-gray-200 dark:bg-gray-700"></div>
          <div class="flex items-center gap-0.5 sm:gap-1 overflow-x-auto scrollbar-hide" role="tablist">
            <button type="button" role="tab" {{on "click" (fn this.setGender "all")}}
              class="relative flex shrink-0 items-center px-2.5 sm:px-3 py-1.5 sm:py-2 text-[11px] sm:text-xs font-semibold transition-colors duration-200 focus:outline-none
                {{if (eq this.activeGender 'all') 'text-indigo-600 dark:text-indigo-400' 'text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300'}}">
              All
              {{#if (eq this.activeGender "all")}}<span class="absolute bottom-0 left-0 right-0 h-0.5 rounded-full bg-indigo-600 dark:bg-indigo-400"></span>{{/if}}
            </button>
            <button type="button" role="tab" {{on "click" (fn this.setGender "male")}}
              class="relative flex shrink-0 items-center gap-1 sm:gap-1.5 px-2.5 sm:px-3 py-1.5 sm:py-2 text-[11px] sm:text-xs font-semibold transition-colors duration-200 focus:outline-none
                {{if (eq this.activeGender 'male') 'text-indigo-600 dark:text-indigo-400' 'text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300'}}">
              <svg class="w-3 h-3 sm:w-3.5 sm:h-3.5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <circle cx="10" cy="14" r="5" /><path d="M19 5l-5.5 5.5" /><path d="M14 5h5v5" />
              </svg>
              Male
              {{#if (eq this.activeGender "male")}}<span class="absolute bottom-0 left-0 right-0 h-0.5 rounded-full bg-indigo-600 dark:bg-indigo-400"></span>{{/if}}
            </button>
            <button type="button" role="tab" {{on "click" (fn this.setGender "female")}}
              class="relative flex shrink-0 items-center gap-1 sm:gap-1.5 px-2.5 sm:px-3 py-1.5 sm:py-2 text-[11px] sm:text-xs font-semibold transition-colors duration-200 focus:outline-none
                {{if (eq this.activeGender 'female') 'text-indigo-600 dark:text-indigo-400' 'text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300'}}">
              <svg class="w-3 h-3 sm:w-3.5 sm:h-3.5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <circle cx="12" cy="8" r="5" /><path d="M12 13v8" /><path d="M9 18h6" />
              </svg>
              Female
              {{#if (eq this.activeGender "female")}}<span class="absolute bottom-0 left-0 right-0 h-0.5 rounded-full bg-indigo-600 dark:bg-indigo-400"></span>{{/if}}
            </button>
          </div>
        </div>
      </div>

      {{! ─── Loading skeleton ─── }}
      {{#if this.isLoading}}
        <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 2xl:grid-cols-6 gap-3 sm:gap-4 lg:gap-5">
          {{#each this.skeletons as |_|}}
            <div class="rounded-2xl bg-white dark:bg-gray-900 ring-2 ring-green-400/30 dark:ring-green-600/20 shadow-md overflow-hidden animate-pulse">
              <div class="aspect-[3/4] sm:aspect-auto sm:h-40 lg:h-44 bg-gradient-to-br from-gray-200 to-gray-300 dark:from-gray-700 dark:to-gray-600"></div>
              <div class="px-3 pb-2.5 pt-2 space-y-1.5">
                <div class="flex justify-center items-center gap-2">
                  <div class="w-7 h-7 sm:w-8 sm:h-8 rounded-full bg-gray-200 dark:bg-gray-700"></div>
                  <div class="w-7 h-7 sm:w-8 sm:h-8 rounded-full bg-gray-200 dark:bg-gray-700"></div>
                  <div class="w-7 h-7 sm:w-8 sm:h-8 rounded-full bg-gray-200 dark:bg-gray-700"></div>
                </div>
                <div class="h-3.5 bg-gray-200 dark:bg-gray-700 rounded-full w-3/4 mx-auto"></div>
                <div class="grid grid-cols-3 gap-1.5">
                  <div class="h-8 bg-gray-200 dark:bg-gray-700 rounded-lg"></div>
                  <div class="h-8 bg-gray-200 dark:bg-gray-700 rounded-lg"></div>
                  <div class="h-8 bg-gray-200 dark:bg-gray-700 rounded-lg"></div>
                </div>
                <div class="h-6 bg-gray-200 dark:bg-gray-700 rounded-full w-24 mx-auto"></div>
              </div>
            </div>
          {{/each}}
        </div>

      {{else if this.error}}
        <div class="flex flex-col items-center justify-center py-16 sm:py-20 text-center px-4">
          <div class="w-14 h-14 sm:w-16 sm:h-16 mb-4 rounded-2xl bg-rose-100 dark:bg-rose-900/30 flex items-center justify-center">
            <svg class="w-7 h-7 sm:w-8 sm:h-8 text-rose-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M12 2a10 10 0 1 0 0 20A10 10 0 0 0 12 2z" /><path d="M12 8v4" /><path d="M12 16h.01" />
            </svg>
          </div>
          <p class="text-sm sm:text-base font-semibold text-gray-900 dark:text-white mb-1">Something went wrong</p>
          <p class="text-xs sm:text-sm text-gray-500 dark:text-gray-400 mb-4">{{this.error}}</p>
          <button type="button" {{on "click" this.retry}}
            class="px-5 py-2 text-sm font-bold text-white bg-indigo-600 hover:bg-indigo-500 rounded-xl transition-colors">
            Try again
          </button>
        </div>

      {{else if this.isEmpty}}
        <div class="flex flex-col items-center justify-center py-16 sm:py-20 text-center px-4">
          <div class="w-14 h-14 sm:w-16 sm:h-16 mb-4 rounded-2xl bg-indigo-100 dark:bg-indigo-900/30 flex items-center justify-center">
            <svg class="w-7 h-7 sm:w-8 sm:h-8 text-indigo-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
              <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /><path d="M23 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" />
            </svg>
          </div>
          <p class="text-sm sm:text-base font-semibold text-gray-900 dark:text-white mb-1">No players found</p>
          <p class="text-xs sm:text-sm text-gray-500 dark:text-gray-400">Try a different area or sport.</p>
        </div>

      {{else if this.hasPlayers}}
        <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 2xl:grid-cols-6 gap-3 sm:gap-4 lg:gap-5">
          {{#each this.players as |player|}}

            <div class="group">
              <LinkTo @route="player" @model={{player.user_username}} class="block">
                <div class="rounded-2xl overflow-hidden bg-white dark:bg-gray-900 ring-2 ring-green-400/60 dark:ring-green-500/40 shadow-md transition-all duration-300 ease-out group-hover:ring-green-500 group-hover:shadow-xl group-hover:shadow-green-400/20 dark:group-hover:shadow-green-600/10 group-hover:-translate-y-1">

                  {{! ── Portrait image ── }}
                  <div class="relative aspect-[3/4] sm:aspect-auto sm:h-40 lg:h-44 overflow-hidden">
                    <img
                      src={{if (imgUrl player.player_primary_pic) (imgUrl player.player_primary_pic) (defaultAvatar)}}
                      alt={{fullName player}}
                      loading="lazy"
                      class="absolute inset-0 w-full h-full object-cover object-top transition-transform duration-500 ease-out will-change-transform group-hover:scale-105"
                    />

                  </div>

                  {{! ── Card body ── }}
                  <div class="px-3 pt-2 pb-2.5">

                    {{! Club / team avatars — evenly spaced }}
                    <div class="flex justify-center items-center gap-2 mb-1.5">
                      <div class="w-7 h-7 sm:w-8 sm:h-8 rounded-full bg-indigo-100 dark:bg-indigo-900/40 ring-2 ring-white dark:ring-gray-900 flex items-center justify-center shrink-0">
                        <svg class="w-3 h-3 sm:w-3.5 sm:h-3.5 text-indigo-500 dark:text-indigo-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                          <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
                        </svg>
                      </div>
                      <div class="w-7 h-7 sm:w-8 sm:h-8 rounded-full bg-orange-100 dark:bg-orange-900/40 ring-2 ring-white dark:ring-gray-900 flex items-center justify-center shrink-0">
                        <svg class="w-3 h-3 sm:w-3.5 sm:h-3.5 text-orange-500 dark:text-orange-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                          <circle cx="12" cy="12" r="10" /><path d="M12 8v4l3 3" />
                        </svg>
                      </div>
                      <div class="w-7 h-7 sm:w-8 sm:h-8 rounded-full bg-sky-100 dark:bg-sky-900/40 ring-2 ring-white dark:ring-gray-900 flex items-center justify-center shrink-0">
                        <svg class="w-3 h-3 sm:w-3.5 sm:h-3.5 text-sky-500 dark:text-sky-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                          <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" />
                        </svg>
                      </div>
                    </div>

                    {{! Player name }}
                    <h3 class="text-center font-extrabold italic text-indigo-900 dark:text-indigo-300 text-xs sm:text-sm leading-tight truncate mb-1.5 px-1" title={{fullName player}}>
                      {{fullName player}}
                    </h3>

                    {{! Stats row: Matches · Runs · Wickets }}
                    <div class="grid grid-cols-3 text-center mb-2">
                      <div>
                        <p class="text-sm sm:text-base font-black text-indigo-900 dark:text-white leading-none">{{stat player.match_count}}</p>
                        <p class="text-[8px] sm:text-[9px] font-semibold text-blue-500 dark:text-blue-400 mt-0.5 uppercase tracking-wide">Matches</p>
                      </div>
                      <div class="border-x border-gray-100 dark:border-gray-800">
                        <p class="text-sm sm:text-base font-black text-indigo-900 dark:text-white leading-none">{{stat player.total_runs}}</p>
                        <p class="text-[8px] sm:text-[9px] font-semibold text-blue-500 dark:text-blue-400 mt-0.5 uppercase tracking-wide">Runs</p>
                      </div>
                      <div>
                        <p class="text-sm sm:text-base font-black text-indigo-900 dark:text-white leading-none">{{stat player.total_wickets}}</p>
                        <p class="text-[8px] sm:text-[9px] font-semibold text-blue-500 dark:text-blue-400 mt-0.5 uppercase tracking-wide">Wickets</p>
                      </div>
                    </div>

                    {{! Team rating pill }}
                    <div class="flex justify-center">
                      <div class="inline-flex items-center gap-1 bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-300 text-[9px] sm:text-[10px] font-semibold px-3 py-1 rounded-full">
                        <span>Team</span>
                        <svg class="w-2.5 h-2.5 text-gray-400 dark:text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                          <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" />
                        </svg>
                        <span>{{teamRating player}}</span>
                      </div>
                    </div>

                  </div>
                </div>
              </LinkTo>
            </div>

          {{/each}}
        </div>

        {{! Infinite scroll sentinel }}
        <div {{onInit this.setupSentinel}} class="h-px"></div>

        {{! Load more spinner }}
        {{#if this.isLoadingMore}}
          <div class="flex items-center justify-center gap-3 py-8 sm:py-10">
            <div class="w-4 h-4 sm:w-5 sm:h-5 border-2 border-green-500 border-t-transparent rounded-full animate-spin"></div>
            <span class="text-xs sm:text-sm text-gray-400 dark:text-gray-500">Loading more players…</span>
          </div>
        {{/if}}

        {{! End of list }}
        {{#unless this.hasMore}}
          <div class="flex items-center justify-center gap-3 py-8 sm:py-10">
            <div class="h-px flex-1 bg-gray-100 dark:bg-gray-800 max-w-16 sm:max-w-24"></div>
            <span class="text-[10px] sm:text-xs text-gray-400 dark:text-gray-500">All players loaded</span>
            <div class="h-px flex-1 bg-gray-100 dark:bg-gray-800 max-w-16 sm:max-w-24"></div>
          </div>
        {{/unless}}

      {{/if}}

    </section>
  </template>
}
