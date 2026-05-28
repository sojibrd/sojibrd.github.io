import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { service } from '@ember/service';
import { on } from '@ember/modifier';
import { fn, array } from '@ember/helper';
import { eq, not } from 'ember-truth-helpers';
import { modifier } from 'ember-modifier';
import { debounce } from '@ember/runloop';
import config from 'spordium/config/environment';

/*
  <Ui::SelectRoleModal
    @isOpen={{this.showUmpireModal}}
    @role="cricketumipire"
    @title="Select Umpire"
    @onSelect={{this.onUmpireSelected}}
    @onClose={{this.closeUmpireModal}}
  />

  @role    — API role param: "cricketumipire" | "cricketscorer" | "cricketstreamer"
  @title   — Modal header title
  @onSelect(user) — called with { userid, name, avatar, fee }
  @onClose — called when modal is dismissed
*/

// Maps internal role → role name expected by get-accepted-role-person API
const ROLE_API_NAME = {
  cricketumipire:  'CricketUmipire',
  cricketscorer:   'CricketScorer',
  cricketstreamer: 'CricketVideoStreamer',
};

// Maps role → payload key for /role/request-role/
const ROLE_ID_KEY = {
  cricketumipire:  'umpire_id',
  cricketscorer:   'scorer_id',
  cricketstreamer: 'streamer_id',
};

const _initialized = new WeakSet();
const onInsert = modifier((el, [fn]) => {
  if (!_initialized.has(el)) {
    _initialized.add(el);
    fn();
  }
});

// Response types that signal a role was accepted/declined
const ROLE_RESPONSE_TYPES = new Set([
  'umpire_response',
  'scorer_response',
  'streamer_response',
  'active_scorer_request_response',
  'cricketscorer_response',
]);

class SelectRoleModalComponent extends Component {
  @service store;
  @service geolocation;
  @service api;
  @service websocket;

  _wsUnlisten = null;

  // ── Country picker ──────────────────────────────────────────────────────────
  @tracked selectedCountry = { name: 'Bangladesh', code: 'bd', countryCode: 'BD', flag: 'https://flagcdn.com/w40/bd.png' };
  @tracked countriesList = [];
  @tracked showCountryPicker = false;
  @tracked countrySearch = '';

  // ── Role status ─────────────────────────────────────────────────────────────
  @tracked acceptedIds = new Set();
  @tracked requestedIds = new Set();

  // ── Results ─────────────────────────────────────────────────────────────────
  @tracked results = [];
  @tracked selectedIds = new Set();
  @tracked isLoading = false;
  @tracked isSubmitting = false;
  @tracked error = null;
  @tracked searchQuery = '';

  get hasSelection() {
    return this.selectedIds.size > 0;
  }

  // 'accepted' | 'requested' | null
  getUserStatus = (userid) => {
    if (this.acceptedIds.has(userid)) return 'accepted';
    if (this.requestedIds.has(userid)) return 'requested';
    return null;
  }

  get filteredCountries() {
    const q = this.countrySearch.toLowerCase().trim();
    if (!q) return this.countriesList;
    return this.countriesList.filter((c) =>
      c.name.toLowerCase().includes(q) || c.countryCode.toLowerCase().includes(q)
    );
  }

  @action
  async onOpen() {
    await this.loadCountries();
    this.fetchRoleStatus();
    this.fetchResults();
    // Listen for accept/decline responses and refresh status in real-time
    this._wsUnlisten = this.websocket.on('*', this._onWsMessage);
  }

  _onWsMessage = (data) => {
    const payload = data?.payload ?? data;
    const type = payload?.notification_type || payload?.type;
    if (!ROLE_RESPONSE_TYPES.has(type)) return;
    this.fetchRoleStatus();
  };

  async fetchRoleStatus() {
    if (!this.args.gameId) return;
    const roleApiName = ROLE_API_NAME[this.args.role] ?? this.args.role;
    try {
      const results = await this.store.query('accepted-role-person', {
        game_id: this.args.gameId,
        role: roleApiName,
      });
      this.acceptedIds  = new Set(results.filter((r) => r.status === 'accepted').map((r) => r.userid));
      this.requestedIds = new Set(results.filter((r) => r.status === 'requested').map((r) => r.userid));
    } catch {
      // non-critical — list still shows, just without status badges
    }
  }

  async loadCountries() {
    if (this.countriesList.length) return;
    try {
      const res = await fetch('https://restcountries.com/v3.1/all?fields=name,idd,cca2');
      const data = await res.json();
      this.countriesList = data
        .filter((c) => c.idd?.root && c.idd?.suffixes?.length)
        .map((c) => ({
          name: c.name.common,
          code: c.cca2.toLowerCase(),
          countryCode: c.cca2,
          flag: `https://flagcdn.com/w40/${c.cca2.toLowerCase()}.png`,
        }))
        .sort((a, b) => a.name.localeCompare(b.name));

      // auto-select from geolocation
      try {
        const coords = await this.geolocation.getCoords();
        const geo = await fetch(
          `https://maps.googleapis.com/maps/api/geocode/json?latlng=${coords.latitude},${coords.longitude}&result_type=country&key=${config.APP.GOOGLE_MAPS_KEY ?? ''}`
        ).then((r) => r.json()).catch(() => null);
        const cc = geo?.results?.[0]?.address_components?.[0]?.short_name;
        if (cc) {
          const match = this.countriesList.find((c) => c.countryCode === cc);
          if (match) this.selectedCountry = match;
        }
      } catch {
        // keep default BD
      }
    } catch {
      // keep default BD
    }
  }

  @action
  toggleCountryPicker() {
    this.showCountryPicker = !this.showCountryPicker;
    if (this.showCountryPicker) this.countrySearch = '';
  }

  @action
  selectCountry(country) {
    this.selectedCountry = country;
    this.showCountryPicker = false;
    this.fetchResults();
  }

  @action
  onCountrySearch(event) {
    this.countrySearch = event.target.value;
  }

  // ── Search ──────────────────────────────────────────────────────────────────
  @action
  onSearchInput(event) {
    this.searchQuery = event.target.value;
    debounce(this, this.fetchResults, 400);
  }

  async fetchResults() {
    this.isLoading = true;
    this.error = null;
    try {
      let lat = 23.7805462;
      let lng = 90.4266584;
      try {
        const coords = await this.geolocation.getCoords();
        lat = coords.latitude;
        lng = coords.longitude;
      } catch { /* use defaults */ }

      this.results = await this.store.query('role-profile', {
        role: this.args.role,
        lat,
        lng,
        country_code: this.selectedCountry.countryCode,
        ...(this.searchQuery.trim() ? { search_data: this.searchQuery.trim() } : {}),
      });
    } catch {
      this.error = 'Could not load results. Please try again.';
    } finally {
      this.isLoading = false;
    }
  }

  @action
  toggleSelect(userid) {
    if (this.getUserStatus(userid)) return; // accepted or requested — cannot select
    const next = new Set(this.selectedIds);
    if (next.has(userid)) {
      next.delete(userid);
    } else {
      next.add(userid);
    }
    this.selectedIds = next;
  }

  isSelected = (userid) => this.selectedIds.has(userid);

  @action
  async handleRequest() {
    if (!this.hasSelection || this.isSubmitting) return;
    this.isSubmitting = true;
    try {
      const idKey = ROLE_ID_KEY[this.args.role] ?? 'umpire_id';
      await this.api.post('/role/request-role/', {
        game_id: this.args.gameId,
        [idKey]: Array.from(this.selectedIds),
      });
      this.args.onSelect?.(Array.from(this.selectedIds));
      this.handleClose();
    } catch (err) {
      this.error = err?.payload?.message || err?.message || 'Request failed. Try again.';
    } finally {
      this.isSubmitting = false;
    }
  }

  @action
  handleClose() {
    this._wsUnlisten?.();
    this._wsUnlisten = null;
    this.searchQuery = '';
    this.results = [];
    this.selectedIds = new Set();
    this.acceptedIds = new Set();
    this.requestedIds = new Set();
    this.showCountryPicker = false;
    this.error = null;
    this.args.onClose?.();
  }

  <template>
    {{#if @isOpen}}
      <div
        class="fixed inset-0 z-50 flex items-end sm:items-center justify-center"
        {{onInsert this.onOpen}}
        role="dialog"
        aria-modal="true"
      >
        {{! Backdrop }}
        <div
          class="absolute inset-0 bg-black/60 backdrop-blur-sm"
          role="presentation"
          {{on "click" this.handleClose}}
        ></div>

        {{! Sheet }}
        <div class="relative w-full sm:max-w-sm bg-slate-800 rounded-t-2xl sm:rounded-2xl shadow-2xl border border-slate-700/60 z-10 flex flex-col max-h-[85vh]">

          {{! Header }}
          <div class="px-5 pt-5 pb-4 flex-shrink-0">
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-white font-bold text-lg">{{@title}}</h3>
              <button
                type="button"
                class="w-8 h-8 flex items-center justify-center text-gray-400 hover:text-white rounded-lg hover:bg-slate-700 transition-colors"
                {{on "click" this.handleClose}}
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            {{! Search + Country picker row }}
            <div class="flex gap-2">
              {{! Search input }}
              <div class="flex-1 relative">
                <input
                  type="text"
                  placeholder="Search"
                  value={{this.searchQuery}}
                  class="w-full bg-white dark:bg-slate-900 text-slate-900 dark:text-white placeholder-gray-400 px-4 py-2.5 pr-10 rounded-xl text-sm border border-slate-200 dark:border-slate-700 focus:outline-none focus:border-cyan-500"
                  {{on "input" this.onSearchInput}}
                />
                <svg class="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400 pointer-events-none" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
              </div>

              {{! Country flag button }}
              <button
                type="button"
                class="w-12 h-10 flex items-center justify-center bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-xl hover:border-cyan-500 transition-colors flex-shrink-0 overflow-hidden"
                {{on "click" this.toggleCountryPicker}}
              >
                {{#if this.selectedCountry.flag}}
                  <img src={{this.selectedCountry.flag}} alt={{this.selectedCountry.name}} class="w-7 h-5 object-cover rounded-sm" />
                {{else}}
                  <span class="text-xs font-bold text-gray-300">{{this.selectedCountry.countryCode}}</span>
                {{/if}}
              </button>
            </div>

            {{! Country picker dropdown }}
            {{#if this.showCountryPicker}}
              <div class="mt-2 bg-slate-900 border border-slate-700 rounded-xl shadow-xl overflow-hidden">
                <div class="p-2">
                  <input
                    type="text"
                    placeholder="Search country..."
                    value={{this.countrySearch}}
                    class="w-full bg-slate-800 text-white placeholder-gray-500 px-3 py-2 rounded-lg text-sm focus:outline-none"
                    {{on "input" this.onCountrySearch}}
                  />
                </div>
                <div class="max-h-44 overflow-y-auto">
                  {{#each this.filteredCountries as |country|}}
                    <button
                      type="button"
                      class="w-full flex items-center gap-2.5 px-3 py-2 hover:bg-slate-800 transition-colors text-left
                        {{if (eq this.selectedCountry.code country.code) 'bg-slate-800' ''}}"
                      {{on "click" (fn this.selectCountry country)}}
                    >
                      {{#if country.flag}}
                        <img src={{country.flag}} alt={{country.name}} class="w-6 h-4 object-cover rounded-sm flex-shrink-0" />
                      {{/if}}
                      <span class="text-white text-sm truncate">{{country.name}}</span>
                      <span class="text-gray-500 text-xs ml-auto flex-shrink-0">{{country.countryCode}}</span>
                    </button>
                  {{/each}}
                </div>
              </div>
            {{/if}}
          </div>

          {{! List }}
          <div class="px-5 pb-5 overflow-y-auto flex-1 space-y-2">
            {{#if this.isLoading}}
              {{#each (array 1 2 3 4 5) as |_|}}
                <div class="flex items-center gap-3 p-3 bg-white dark:bg-slate-900 rounded-2xl animate-pulse">
                  <div class="w-12 h-12 rounded-xl bg-slate-700 flex-shrink-0"></div>
                  <div class="flex-1 space-y-2">
                    <div class="h-3.5 bg-slate-700 rounded w-32"></div>
                    <div class="h-3 bg-slate-700 rounded w-20"></div>
                  </div>
                </div>
              {{/each}}

            {{else if this.error}}
              <div class="py-8 text-center">
                <p class="text-red-400 text-sm">{{this.error}}</p>
                <button
                  type="button"
                  class="mt-3 text-cyan-400 text-sm hover:text-cyan-300"
                  {{on "click" this.fetchResults}}
                >
                  Try again
                </button>
              </div>

            {{else if this.results.length}}
              {{#each this.results as |user|}}
                {{#let (this.getUserStatus user.userid) as |status|}}
                <button
                  type="button"
                  class="w-full flex items-center gap-3 p-3 dark:bg-slate-900 rounded-2xl transition-colors text-left border
                    {{if status
                      'bg-slate-50 dark:bg-slate-800/40 border-transparent opacity-70 cursor-default'
                      (if (this.isSelected user.userid)
                        'bg-cyan-50 dark:bg-cyan-900/20 border-cyan-500/50'
                        'bg-white hover:bg-gray-50 dark:hover:bg-slate-700/60 border-transparent hover:border-slate-600')}}"
                  {{on "click" (fn this.toggleSelect user.userid)}}
                >
                  {{! Avatar }}
                  <div class="w-12 h-12 rounded-xl flex-shrink-0 overflow-hidden bg-slate-700 flex items-center justify-center">
                    {{#if user.avatar}}
                      <img src={{user.avatar}} alt={{user.name}} class="w-full h-full object-cover" onerror="this.style.display='none'" />
                    {{else}}
                      <span class="text-white font-bold text-lg">{{user.initial}}</span>
                    {{/if}}
                  </div>

                  {{! Info }}
                  <div class="flex-1 min-w-0">
                    <p class="text-slate-900 dark:text-white font-semibold text-sm truncate">{{user.name}}</p>
                    <p class="text-gray-500 text-xs mt-0.5">Hourly Fee: {{user.fee}}</p>
                  </div>

                  {{! Status badge OR checkbox }}
                  {{#if (eq status "accepted")}}
                    <span class="text-[10px] font-semibold text-green-500 bg-green-500/10 px-2 py-0.5 rounded-full flex-shrink-0">Accepted</span>
                  {{else if (eq status "requested")}}
                    <span class="text-[10px] font-semibold text-amber-400 bg-amber-400/10 px-2 py-0.5 rounded-full flex-shrink-0">Pending</span>
                  {{else}}
                    <div class="w-5 h-5 rounded-full border-2 flex-shrink-0 flex items-center justify-center transition-colors
                      {{if (this.isSelected user.userid) 'border-cyan-400 bg-cyan-400' 'border-gray-500'}}">
                      {{#if (this.isSelected user.userid)}}
                        <svg class="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" />
                        </svg>
                      {{/if}}
                    </div>
                  {{/if}}
                </button>
                {{/let}}
              {{/each}}

            {{else}}
              <div class="py-10 text-center">
                <p class="text-gray-500 text-sm">No results found.</p>
              </div>
            {{/if}}
          </div>

          {{! Footer }}
          <div class="px-5 py-4 border-t border-slate-700/50 flex justify-between items-center flex-shrink-0">
            <button
              type="button"
              class="px-5 py-2 text-sm font-semibold text-gray-300 hover:text-white transition-colors"
              {{on "click" this.handleClose}}
            >
              Cancel
            </button>
            <button
              type="button"
              disabled={{not this.hasSelection}}
              class="flex items-center gap-2 px-5 py-2 rounded-xl text-sm font-semibold transition-colors
                {{if this.hasSelection
                  'bg-cyan-600 hover:bg-cyan-500 text-white'
                  'bg-slate-700 text-gray-500 cursor-not-allowed'}}"
              {{on "click" this.handleRequest}}
            >
              {{#if this.isSubmitting}}
                <div class="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin"></div>
                Requesting...
              {{else}}
                Request
                {{#if this.hasSelection}}
                  <span class="bg-white/20 text-white text-[10px] font-bold w-4 h-4 rounded-full flex items-center justify-center">
                    {{this.selectedIds.size}}
                  </span>
                {{/if}}
              {{/if}}
            </button>
          </div>

        </div>
      </div>
    {{/if}}
  </template>
}

export default SelectRoleModalComponent;
