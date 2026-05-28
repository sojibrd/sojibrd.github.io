import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { eq, or } from 'ember-truth-helpers';
import { service } from '@ember/service';
import Pagonation from '../pagonation';
import lucideIcon from 'spordium/helpers/lucide-icon';

const PAGE_SIZE  = 20;
const IMAGE_BASE = 'https://ag-khela.s3.ap-south-1.amazonaws.com/';

const SPORT_TABS = [
  { id: 'all',        label: 'All' },
  { id: 'football',   label: 'Football' },
  { id: 'cricket',    label: 'Cricket' },
  { id: 'basketball', label: 'Basketball' },
  { id: 'badminton',  label: 'Badminton' },
];

const MATCH_TYPES = [
  'T10', 'T20', 'One Day', 'Test', 'Five Over',
  'Six Aside', 'Eight Aside', 'Box Cricket',
];

const TOURNAMENT_MATCH_TYPES = ['Home And Away', 'Knockout', 'League'];

const TOURNAMENT_TYPES = [
  'Corporate', 'School', 'College', 'University',
  'Community', 'Professional', 'Amateur',
];

const BALL_TYPES = [
  'Red Cricket Ball', 'White Cricket Ball', 'Tape Tennis Ball',
  'Tennis Ball', 'Rubber Ball', 'Leather Ball',
  'Synthetic Ball', 'Hard Ball', 'Soft Ball',
];

const PITCH_TYPES = [
  'Cement', 'Turf', 'Artificial Turf', 'Matting',
  'Grass', 'Sand', 'Indoor', 'Outdoor', 'Clay',
];

const SKELETONS = [1, 2, 3, 4, 5, 6, 7, 8];

// ══════════════════════════════════════════════════════════════════════════════
export default class Facilities extends Component {
  @service session;
  @service router;

  // ── Data state ─────────────────────────────────────────────────────────────
  @tracked facilities  = [];
  @tracked isLoading   = true;
  @tracked error       = null;
  @tracked currentPage = 1;
  @tracked totalCount  = 0;

  // ── Tab / search ───────────────────────────────────────────────────────────
  @tracked activeTab   = 'all';
  @tracked searchQuery = '';

  // ── Filter sidebar ─────────────────────────────────────────────────────────
  @tracked filterOpen              = false;
  @tracked filterMatchType         = '';
  @tracked filterDate              = '';
  @tracked filterTournamentMatch   = '';
  @tracked filterTournamentType    = '';
  @tracked filterBallType          = '';
  @tracked filterPitchType         = '';

  constructor(owner, args) {
    super(owner, args);
    this.fetchFacilities(1);
  }

  // ── Lookups ────────────────────────────────────────────────────────────────
  get matchTypes()            { return MATCH_TYPES; }
  get tournamentMatchTypes()  { return TOURNAMENT_MATCH_TYPES; }
  get tournamentTypes()       { return TOURNAMENT_TYPES; }
  get ballTypes()             { return BALL_TYPES; }
  get pitchTypes()            { return PITCH_TYPES; }
  get sportTabs()             { return SPORT_TABS; }
  get skeletons()             { return SKELETONS; }

  // ── Active filter count badge ───────────────────────────────────────────────
  get activeFilterCount() {
    return [
      this.filterMatchType,
      this.filterDate,
      this.filterTournamentMatch,
      this.filterTournamentType,
      this.filterBallType,
      this.filterPitchType,
    ].filter(Boolean).length;
  }

  get hasActiveFilters() { return this.activeFilterCount > 0; }

  // Common inactive style shared by all filter <select> elements
  get selectInactiveCls() {
    return 'border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800 text-gray-600 dark:text-gray-400';
  }

  // ── Grid column class changes when sidebar is open ─────────────────────────
  get gridCols() {
    return this.filterOpen
      ? 'grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4'
      : 'grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5';
  }

  // ── Pagination ─────────────────────────────────────────────────────────────
  get totalPages() {
    return Math.max(1, Math.ceil(this.totalCount / PAGE_SIZE));
  }

  // ── Client-side filter on current page data ────────────────────────────────
  get filteredFacilities() {
    const q   = this.searchQuery.trim().toLowerCase();
    const tab = this.activeTab;
    let list  = this.facilities;

    if (tab !== 'all') {
      list = list.filter((f) =>
        (f.fac_sports ?? []).some((s) => s.toLowerCase().includes(tab))
      );
    }

    if (q) {
      list = list.filter(
        (f) =>
          f.fac_name?.toLowerCase().includes(q) ||
          f.fac_city?.toLowerCase().includes(q) ||
          f.fac_address?.toLowerCase().includes(q)
      );
    }

    // Date filter: keep facilities whose free_from is on or before chosen date
    if (this.filterDate) {
      const chosen = new Date(this.filterDate).getTime();
      list = list.filter((f) => {
        if (!f.free_from) return true;
        return new Date(f.free_from).getTime() <= chosen;
      });
    }

    return list;
  }

  get isEmpty()       { return !this.isLoading && !this.error && this.filteredFacilities.length === 0; }
  get hasFacilities() { return !this.isLoading && !this.error && this.filteredFacilities.length > 0; }

  // ── Helpers ────────────────────────────────────────────────────────────────
  bannerUrl(facility) {
    const path = facility.fac_banners?.[0];
    return path ? `${IMAGE_BASE}${path}` : null;
  }

  formatRating(val) {
    return typeof val === 'number' ? val.toFixed(1) : '0.0';
  }

  // ── Fetch ──────────────────────────────────────────────────────────────────
  async fetchFacilities(page) {
    this.isLoading = true;
    this.error     = null;
    try {
      const url  = `https://spordiumapi.adnanfoundation.com/facility/get_bd_facilities/?page_number=${page}&page_size=${PAGE_SIZE}`;
      const res  = await fetch(url);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json = await res.json();
      this.facilities = json.data?.facilities ?? [];
      this.totalCount = json.data?.total_count  ?? 0;
    } catch {
      this.error = 'Failed to load facilities. Please try again.';
    } finally {
      this.isLoading = false;
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  @action retry()            { this.fetchFacilities(this.currentPage); }
  @action toggleFilter()     { this.filterOpen = !this.filterOpen; }
  @action setTab(tab)        { this.activeTab = tab; }
  @action updateSearch(e)    { this.searchQuery = e.target.value; }

  @action setFilter(key, e) {
    this[key] = e.target.value;
  }

  @action resetFilters() {
    this.filterMatchType       = '';
    this.filterDate            = '';
    this.filterTournamentMatch = '';
    this.filterTournamentType  = '';
    this.filterBallType        = '';
    this.filterPitchType       = '';
  }

  @action openFacility(facility) {
    // The list API may return either fac_url_name or fac_url as the slug.
    const urlName = facility.fac_url_name ?? facility.fac_url;
    if (!urlName) return;
    this.router.transitionTo('facilities.details', urlName);
  }

  @action goToCreate() {
    this.router.transitionTo('facilities.create');
  }

  @action goNext() {
    if (this.currentPage < this.totalPages) {
      this.currentPage++;
      this.fetchFacilities(this.currentPage);
    }
  }

  @action goPrev() {
    if (this.currentPage > 1) {
      this.currentPage--;
      this.fetchFacilities(this.currentPage);
    }
  }

  @action goToPage(page) {
    this.currentPage = page;
    this.fetchFacilities(page);
  }

  // ══════════════════════════════════════════════════════════════════════════
  <template>
    <section class="w-full px-4 py-8 sm:px-6 lg:px-8">

      {{! ── Header bar ── }}
      <div class="relative mb-6">
        <div class="absolute bottom-0 left-0 right-0 h-px bg-gray-200 dark:bg-gray-700"></div>

        <div class="flex items-center justify-between gap-3 flex-wrap sm:flex-nowrap">

          {{! Left: filter toggle + sport tabs }}
          <div class="flex items-center gap-1">

            {{! Three-bar toggle button }}
            <button
              type="button"
              {{on "click" this.toggleFilter}}
              class="relative flex items-center justify-center w-9 h-9 rounded-xl
                     border transition-all duration-200 shrink-0 mr-1
                     {{if this.filterOpen
                       'bg-indigo-600 border-indigo-600 text-white shadow-md shadow-indigo-500/30'
                       'bg-white dark:bg-gray-900 border-gray-200 dark:border-gray-700
                        text-gray-500 dark:text-gray-400
                        hover:bg-indigo-50 dark:hover:bg-indigo-900/20
                        hover:border-indigo-300 dark:hover:border-indigo-600
                        hover:text-indigo-600 dark:hover:text-indigo-400'}}"
              title="{{if this.filterOpen 'Hide filters' 'Show filters'}}"
            >
              {{lucideIcon "sliders" size=16}}
              {{#if this.hasActiveFilters}}
                <span class="absolute -top-1.5 -right-1.5 w-4 h-4 rounded-full
                             bg-rose-500 text-white text-[9px] font-bold
                             flex items-center justify-center border-2 border-white dark:border-gray-950">
                  {{this.activeFilterCount}}
                </span>
              {{/if}}
            </button>

            {{! Sport tabs }}
            <div class="flex items-center gap-0.5 overflow-x-auto pb-px scrollbar-none" role="tablist">
              {{#each this.sportTabs as |tab|}}
                <button
                  type="button"
                  role="tab"
                  {{on "click" (fn this.setTab tab.id)}}
                  class="relative flex items-center gap-1.5 px-3 py-2.5 text-sm font-semibold
                         whitespace-nowrap shrink-0 transition-colors duration-200 focus:outline-none
                         {{if (eq this.activeTab tab.id)
                           'text-indigo-600 dark:text-indigo-400'
                           'text-gray-500 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200'}}"
                >
                  {{#if (eq tab.id "all")}}
                    <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                         stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                      <rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/>
                      <rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/>
                    </svg>
                  {{else if (eq tab.id "football")}}
                    <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                         stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                      <circle cx="12" cy="12" r="10"/>
                      <path d="M12 2c0 0-3 4-3 10s3 10 3 10"/><path d="M2 12h20"/>
                      <path d="M4.93 4.93l4.24 4.24"/><path d="M14.83 14.83l4.24 4.24"/>
                      <path d="M4.93 19.07l4.24-4.24"/><path d="M14.83 9.17l4.24-4.24"/>
                    </svg>
                  {{else if (eq tab.id "cricket")}}
                    <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                         stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                      <ellipse cx="12" cy="12" rx="10" ry="10"/>
                      <path d="M5 5l14 14"/><path d="M19 5L5 19"/>
                    </svg>
                  {{else if (eq tab.id "basketball")}}
                    <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                         stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                      <circle cx="12" cy="12" r="10"/>
                      <path d="M4.93 4.93C6.18 7.58 7 10 7 12s-.82 4.42-2.07 7.07"/>
                      <path d="M19.07 4.93C17.82 7.58 17 10 17 12s.82 4.42 2.07 7.07"/>
                      <path d="M2 12h20"/>
                    </svg>
                  {{else if (eq tab.id "badminton")}}
                    <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                         stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                      <path d="M12 2l2 4h4l-3 3 1 4-4-2-4 2 1-4-3-3h4z"/>
                      <line x1="12" y1="11" x2="5" y2="20"/>
                    </svg>
                  {{/if}}
                  {{tab.label}}
                  {{#if (eq this.activeTab tab.id)}}
                    <span class="absolute bottom-0 left-0 right-0 h-0.5 rounded-full bg-indigo-600 dark:bg-indigo-400"></span>
                  {{/if}}
                </button>
              {{/each}}
            </div>
          </div>

          {{! Right: search + actions }}
          <div class="flex items-center gap-2 pb-1 shrink-0 ml-auto">
            <div class="relative">
              <div class="pointer-events-none absolute inset-y-0 left-3 flex items-center">
                {{lucideIcon "search" size=14 class="text-gray-400"}}
              </div>
              <input
                type="search"
                placeholder="Search facilities…"
                value={{this.searchQuery}}
                {{on "input" this.updateSearch}}
                class="w-40 sm:w-48 pl-8 pr-3 py-1.5 text-sm rounded-lg
                       border border-gray-200 dark:border-gray-700
                       bg-gray-50 dark:bg-gray-800
                       text-gray-900 dark:text-gray-100
                       placeholder:text-gray-400 dark:placeholder:text-gray-500
                       focus:outline-none focus:ring-2 focus:ring-indigo-400/60 focus:border-indigo-400
                       dark:focus:ring-indigo-500/40 dark:focus:border-indigo-500
                       transition-all duration-200"
              />
            </div>

            <button
              type="button"
              {{on "click" this.goToCreate}}
              class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-semibold
                     bg-indigo-600 hover:bg-indigo-500 active:bg-indigo-700
                     text-white shadow-sm shadow-indigo-500/25 transition-all duration-150
                     focus:outline-none focus:ring-2 focus:ring-indigo-400 focus:ring-offset-1
                     dark:focus:ring-offset-gray-900"
            >
              {{lucideIcon "plus" size=14}}
              <span class="hidden sm:inline">Create Facilities</span>
              <span class="sm:hidden">Create</span>
            </button>

            <button
              type="button"
              class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-semibold
                     bg-white dark:bg-gray-800
                     border border-indigo-200 dark:border-indigo-700/60
                     text-indigo-600 dark:text-indigo-400
                     hover:bg-indigo-50 dark:hover:bg-indigo-900/20
                     hover:border-indigo-300 dark:hover:border-indigo-500
                     shadow-sm transition-all duration-150
                     focus:outline-none focus:ring-2 focus:ring-indigo-400 focus:ring-offset-1
                     dark:focus:ring-offset-gray-900"
            >
              {{lucideIcon "home" size=14}}
              <span class="hidden sm:inline">My Facilities</span>
              <span class="sm:hidden">Mine</span>
            </button>
          </div>

        </div>
      </div>

      {{! ── Body: sidebar + grid ── }}
      <div class="flex gap-5 items-start">

        {{! ══ FILTER SIDEBAR ══ }}
        {{#if this.filterOpen}}
          <aside
            class="w-64 shrink-0 rounded-2xl overflow-hidden
                   border border-gray-200/80 dark:border-gray-700/60
                   shadow-xl shadow-indigo-500/5
                   bg-white dark:bg-gray-900
                   sticky top-4
                   transition-all duration-300 ease-in-out"
          >

            {{! Sidebar header gradient strip }}
            <div class="relative px-4 py-4
                        bg-gradient-to-r from-indigo-600 via-violet-600 to-fuchsia-600
                        dark:from-indigo-700 dark:via-violet-700 dark:to-fuchsia-700">
              {{! Dot texture }}
              <div class="absolute inset-0 opacity-[0.15]"
                   style="background-image: radial-gradient(circle, white 1px, transparent 1px); background-size: 12px 12px;"></div>
              <div class="relative flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <div class="w-7 h-7 rounded-lg bg-white/20 backdrop-blur-sm
                              flex items-center justify-center">
                    {{lucideIcon "filter" size=16 class="text-white"}}
                  </div>
                  <span class="text-white font-bold text-sm tracking-wide">Filters</span>
                </div>
                {{#if this.hasActiveFilters}}
                  <span class="inline-flex items-center px-2 py-0.5 rounded-full
                               bg-white/25 backdrop-blur-sm text-white text-[10px] font-bold">
                    {{this.activeFilterCount}} active
                  </span>
                {{/if}}
              </div>
            </div>

            {{! Filter fields }}
            <div class="p-4 space-y-5">

              {{! ── Match Type ── }}
              <div class="space-y-1.5">
                <label class="flex items-center gap-1.5 text-[10px] font-bold uppercase tracking-widest
                              text-indigo-500 dark:text-indigo-400">
                  {{lucideIcon "star" size=12}}
                  Match Type
                </label>
                <div class="relative">
                  <select
                    value={{this.filterMatchType}}
                    {{on "change" (fn this.setFilter "filterMatchType")}}
                    class="w-full appearance-none pl-3 pr-8 py-2.5 text-sm rounded-xl
                           border transition-all duration-200
                           {{if this.filterMatchType
                             'border-indigo-400 dark:border-indigo-500 bg-indigo-50 dark:bg-indigo-900/20 text-indigo-700 dark:text-indigo-300 font-semibold'
                             this.selectInactiveCls}}
                           focus:outline-none focus:ring-2 focus:ring-indigo-400/50 focus:border-indigo-400
                           dark:focus:ring-indigo-500/30 dark:focus:border-indigo-500 cursor-pointer"
                  >
                    <option value="">Match type</option>
                    {{#each this.matchTypes as |mt|}}
                      <option value={{mt}}>{{mt}}</option>
                    {{/each}}
                  </select>
                  <div class="pointer-events-none absolute inset-y-0 right-2.5 flex items-center">
                    {{lucideIcon "chevron-down" size=16 class=(if this.filterMatchType "text-indigo-500" "text-gray-400")}}
                  </div>
                </div>
              </div>

              {{! ── Date ── }}
              <div class="space-y-1.5">
                <label class="flex items-center gap-1.5 text-[10px] font-bold uppercase tracking-widest
                              text-violet-500 dark:text-violet-400">
                  {{lucideIcon "calendar" size=12}}
                  Date
                </label>
                <div class="relative">
                  <input
                    type="date"
                    value={{this.filterDate}}
                    {{on "change" (fn this.setFilter "filterDate")}}
                    class="w-full pl-3 pr-3 py-2.5 text-sm rounded-xl
                           border transition-all duration-200
                           {{if this.filterDate
                             'border-violet-400 dark:border-violet-500 bg-violet-50 dark:bg-violet-900/20 text-violet-700 dark:text-violet-300 font-semibold'
                             this.selectInactiveCls}}
                           focus:outline-none focus:ring-2 focus:ring-violet-400/50 focus:border-violet-400
                           dark:focus:ring-violet-500/30 dark:focus:border-violet-500 cursor-pointer"
                  />
                </div>
              </div>

              {{! ── Tournament Match Type ── }}
              <div class="space-y-1.5">
                <label class="flex items-center gap-1.5 text-[10px] font-bold uppercase tracking-widest
                              text-fuchsia-500 dark:text-fuchsia-400">
                  {{lucideIcon "trophy" size=12}}
                  Tournament Match
                </label>
                <div class="relative">
                  <select
                    value={{this.filterTournamentMatch}}
                    {{on "change" (fn this.setFilter "filterTournamentMatch")}}
                    class="w-full appearance-none pl-3 pr-8 py-2.5 text-sm rounded-xl
                           border transition-all duration-200
                           {{if this.filterTournamentMatch
                             'border-fuchsia-400 dark:border-fuchsia-500 bg-fuchsia-50 dark:bg-fuchsia-900/20 text-fuchsia-700 dark:text-fuchsia-300 font-semibold'
                             this.selectInactiveCls}}
                           focus:outline-none focus:ring-2 focus:ring-fuchsia-400/50 focus:border-fuchsia-400
                           dark:focus:ring-fuchsia-500/30 dark:focus:border-fuchsia-500 cursor-pointer"
                  >
                    <option value="">Tournament match type</option>
                    {{#each this.tournamentMatchTypes as |tmt|}}
                      <option value={{tmt}}>{{tmt}}</option>
                    {{/each}}
                  </select>
                  <div class="pointer-events-none absolute inset-y-0 right-2.5 flex items-center">
                    {{lucideIcon "chevron-down" size=16 class=(if this.filterTournamentMatch "text-fuchsia-500" "text-gray-400")}}
                  </div>
                </div>
              </div>

              {{! ── Tournament Type ── }}
              <div class="space-y-1.5">
                <label class="flex items-center gap-1.5 text-[10px] font-bold uppercase tracking-widest
                              text-rose-500 dark:text-rose-400">
                  {{lucideIcon "users" size=12}}
                  Tournament Type
                </label>
                <div class="relative">
                  <select
                    value={{this.filterTournamentType}}
                    {{on "change" (fn this.setFilter "filterTournamentType")}}
                    class="w-full appearance-none pl-3 pr-8 py-2.5 text-sm rounded-xl
                           border transition-all duration-200
                           {{if this.filterTournamentType
                             'border-rose-400 dark:border-rose-500 bg-rose-50 dark:bg-rose-900/20 text-rose-700 dark:text-rose-300 font-semibold'
                             this.selectInactiveCls}}
                           focus:outline-none focus:ring-2 focus:ring-rose-400/50 focus:border-rose-400
                           dark:focus:ring-rose-500/30 dark:focus:border-rose-500 cursor-pointer"
                  >
                    <option value="">Tournament type</option>
                    {{#each this.tournamentTypes as |tt|}}
                      <option value={{tt}}>{{tt}}</option>
                    {{/each}}
                  </select>
                  <div class="pointer-events-none absolute inset-y-0 right-2.5 flex items-center">
                    {{lucideIcon "chevron-down" size=16 class=(if this.filterTournamentType "text-rose-500" "text-gray-400")}}
                  </div>
                </div>
              </div>

              {{! ── Ball Type ── }}
              <div class="space-y-1.5">
                <label class="flex items-center gap-1.5 text-[10px] font-bold uppercase tracking-widest
                              text-amber-500 dark:text-amber-400">
                  {{lucideIcon "tag" size=12}}
                  Ball Type
                </label>
                <div class="relative">
                  <select
                    value={{this.filterBallType}}
                    {{on "change" (fn this.setFilter "filterBallType")}}
                    class="w-full appearance-none pl-3 pr-8 py-2.5 text-sm rounded-xl
                           border transition-all duration-200
                           {{if this.filterBallType
                             'border-amber-400 dark:border-amber-500 bg-amber-50 dark:bg-amber-900/20 text-amber-700 dark:text-amber-300 font-semibold'
                             this.selectInactiveCls}}
                           focus:outline-none focus:ring-2 focus:ring-amber-400/50 focus:border-amber-400
                           dark:focus:ring-amber-500/30 dark:focus:border-amber-500 cursor-pointer"
                  >
                    <option value="">Ball type</option>
                    {{#each this.ballTypes as |bt|}}
                      <option value={{bt}}>{{bt}}</option>
                    {{/each}}
                  </select>
                  <div class="pointer-events-none absolute inset-y-0 right-2.5 flex items-center">
                    {{lucideIcon "chevron-down" size=16 class=(if this.filterBallType "text-amber-500" "text-gray-400")}}
                  </div>
                </div>
              </div>

              {{! ── Pitch Type ── }}
              <div class="space-y-1.5">
                <label class="flex items-center gap-1.5 text-[10px] font-bold uppercase tracking-widest
                              text-emerald-500 dark:text-emerald-400">
                  {{lucideIcon "home" size=12}}
                  Pitch Type
                </label>
                <div class="relative">
                  <select
                    value={{this.filterPitchType}}
                    {{on "change" (fn this.setFilter "filterPitchType")}}
                    class="w-full appearance-none pl-3 pr-8 py-2.5 text-sm rounded-xl
                           border transition-all duration-200
                           {{if this.filterPitchType
                             'border-emerald-400 dark:border-emerald-500 bg-emerald-50 dark:bg-emerald-900/20 text-emerald-700 dark:text-emerald-300 font-semibold'
                             this.selectInactiveCls}}
                           focus:outline-none focus:ring-2 focus:ring-emerald-400/50 focus:border-emerald-400
                           dark:focus:ring-emerald-500/30 dark:focus:border-emerald-500 cursor-pointer"
                  >
                    <option value="">Pitch type</option>
                    {{#each this.pitchTypes as |pt|}}
                      <option value={{pt}}>{{pt}}</option>
                    {{/each}}
                  </select>
                  <div class="pointer-events-none absolute inset-y-0 right-2.5 flex items-center">
                    {{lucideIcon "chevron-down" size=16 class=(if this.filterPitchType "text-emerald-500" "text-gray-400")}}
                  </div>
                </div>
              </div>

              {{! Divider }}
              <div class="h-px bg-gradient-to-r from-transparent via-gray-200 dark:via-gray-700 to-transparent"></div>

              {{! ── Reset button ── }}
              <button
                type="button"
                {{on "click" this.resetFilters}}
                class="w-full flex items-center justify-center gap-2 py-2.5 px-4 rounded-xl text-sm font-semibold
                       transition-all duration-200
                       {{if this.hasActiveFilters
                         'bg-gradient-to-r from-indigo-500 to-violet-600 text-white shadow-md shadow-indigo-500/25 hover:shadow-lg hover:shadow-indigo-500/30 hover:from-indigo-400 hover:to-violet-500'
                         'bg-gray-100 dark:bg-gray-800 text-gray-400 dark:text-gray-500 cursor-default'}}"
              >
                <svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                     stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/>
                  <path d="M3 3v5h5"/>
                </svg>
                Reset Filters
              </button>

            </div>
          </aside>
        {{/if}}

        {{! ══ MAIN CONTENT AREA ══ }}
        <div class="flex-1 min-w-0">

          {{! ── Loading skeleton ── }}
          {{#if this.isLoading}}
            <div class="grid {{this.gridCols}} gap-4 sm:gap-5">
              {{#each this.skeletons as |_|}}
                <div class="rounded-2xl bg-white dark:bg-gray-900
                            border border-gray-100 dark:border-gray-700/50
                            shadow-md overflow-hidden animate-pulse">
                  <div class="h-44 bg-gradient-to-br from-gray-200 to-gray-300 dark:from-gray-700 dark:to-gray-600"></div>
                  <div class="p-4 space-y-3">
                    <div class="h-4 bg-gray-200 dark:bg-gray-700 rounded-full w-3/4"></div>
                    <div class="h-3 bg-gray-200 dark:bg-gray-700 rounded-full w-full"></div>
                    <div class="flex gap-1.5 pt-1">
                      <div class="h-5 w-14 bg-gray-200 dark:bg-gray-700 rounded-full"></div>
                      <div class="h-5 w-14 bg-gray-200 dark:bg-gray-700 rounded-full"></div>
                    </div>
                    <div class="h-px bg-gray-200 dark:bg-gray-700"></div>
                    <div class="flex justify-between">
                      <div class="h-3 w-16 bg-gray-200 dark:bg-gray-700 rounded-full"></div>
                      <div class="h-3 w-16 bg-gray-200 dark:bg-gray-700 rounded-full"></div>
                      <div class="h-3 w-16 bg-gray-200 dark:bg-gray-700 rounded-full"></div>
                    </div>
                  </div>
                </div>
              {{/each}}
            </div>

          {{! ── Error state ── }}
          {{else if this.error}}
            <div class="flex flex-col items-center justify-center py-24 text-center">
              <div class="w-16 h-16 mb-5 rounded-2xl bg-rose-100 dark:bg-rose-900/30 flex items-center justify-center">
                {{lucideIcon "alert-circle" size=32 class="text-rose-500"}}
              </div>
              <p class="text-base font-semibold text-gray-900 dark:text-white mb-1">Something went wrong</p>
              <p class="text-sm text-gray-500 dark:text-gray-400 mb-5">{{this.error}}</p>
              <button
                type="button"
                {{on "click" this.retry}}
                class="inline-flex items-center gap-2 px-5 py-2 rounded-xl text-sm font-semibold
                       bg-indigo-600 hover:bg-indigo-500 text-white shadow-sm transition-all duration-150"
              >
                <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                     stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/>
                  <path d="M3 3v5h5"/>
                </svg>
                Try Again
              </button>
            </div>

          {{! ── Empty state ── }}
          {{else if this.isEmpty}}
            <div class="flex flex-col items-center justify-center py-24 text-center">
              <div class="w-20 h-20 mb-6 rounded-3xl
                          bg-gradient-to-br from-indigo-100 to-violet-100
                          dark:from-indigo-900/40 dark:to-violet-900/30
                          flex items-center justify-center shadow-inner">
                {{lucideIcon "building" size=40 class="text-indigo-400 dark:text-indigo-500"}}
              </div>
              <p class="text-lg font-bold text-gray-900 dark:text-white mb-1">No facilities found</p>
              <p class="text-sm text-gray-500 dark:text-gray-400">Try adjusting your filters or search.</p>
              {{#if this.hasActiveFilters}}
                <button
                  type="button"
                  {{on "click" this.resetFilters}}
                  class="mt-4 inline-flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-semibold
                         bg-indigo-50 dark:bg-indigo-900/30 text-indigo-600 dark:text-indigo-400
                         border border-indigo-200 dark:border-indigo-700/50
                         hover:bg-indigo-100 dark:hover:bg-indigo-900/50 transition-all duration-150"
                >
                  Clear filters
                </button>
              {{/if}}
            </div>

          {{! ── Facility grid ── }}
          {{else if this.hasFacilities}}
            <div class="grid {{this.gridCols}} gap-4 sm:gap-5">
              {{#each this.filteredFacilities as |facility|}}

                <div
                  role="button"
                  tabindex="0"
                  {{on "click" (fn this.openFacility facility)}}
                  class="group relative rounded-2xl overflow-hidden
                         bg-white dark:bg-gray-900
                         border border-gray-100 dark:border-gray-700/50
                         shadow-md hover:shadow-2xl hover:shadow-indigo-500/10
                         transition-all duration-300 ease-out
                         hover:-translate-y-1.5 cursor-pointer flex flex-col"
                >

                  {{! Banner image }}
                  <div class="relative h-44 shrink-0 overflow-hidden
                              bg-gradient-to-br from-indigo-500 via-violet-600 to-fuchsia-600
                              dark:from-indigo-700 dark:via-violet-700 dark:to-fuchsia-700">

                    <div class="absolute inset-0 opacity-[0.18]"
                         style="background-image: radial-gradient(circle, white 1px, transparent 1px); background-size: 16px 16px;"></div>

                    <div class="absolute inset-0 -translate-x-full group-hover:translate-x-full
                                bg-gradient-to-r from-transparent via-white/20 to-transparent
                                transition-transform duration-700 ease-in-out pointer-events-none z-10"></div>

                    {{#if (this.bannerUrl facility)}}
                      <img
                        src={{this.bannerUrl facility}}
                        alt={{facility.fac_name}}
                        class="absolute inset-0 w-full h-full object-cover
                               transition-transform duration-500 group-hover:scale-105"
                      />
                    {{/if}}

                    <div class="absolute inset-0 bg-gradient-to-t from-black/70 via-black/10 to-transparent"></div>

                    {{! Sport badges }}
                    {{#if facility.fac_sports.length}}
                      <div class="absolute top-2.5 left-2.5 flex flex-wrap gap-1 z-10 max-w-[calc(100%-3rem)]">
                        {{#each facility.fac_sports as |sport|}}
                          <span class="inline-flex items-center px-2 py-0.5 rounded-full
                                       text-[9px] font-bold uppercase tracking-wider
                                       bg-black/30 backdrop-blur-sm text-white border border-white/20">
                            {{sport}}
                          </span>
                        {{/each}}
                      </div>
                    {{/if}}

                    {{! Status }}
                    {{#if facility.fac_status}}
                      <span class="absolute top-2.5 right-2.5 z-10
                                   flex items-center gap-1 px-2 py-0.5 rounded-full
                                   text-[9px] font-bold uppercase tracking-wider
                                   bg-emerald-500/90 backdrop-blur-sm text-white">
                        <span class="w-1.5 h-1.5 rounded-full bg-white animate-pulse"></span>
                        Open
                      </span>
                    {{/if}}

                    {{! Name overlay }}
                    <div class="absolute bottom-0 left-0 right-0 p-3 z-10">
                      <h3 class="text-white font-extrabold text-[13px] leading-snug line-clamp-2 drop-shadow-sm">
                        {{facility.fac_name}}, {{facility.fac_city}}, {{facility.fac_district}}
                      </h3>
                    </div>
                  </div>

                  {{! Card body }}
                  <div class="flex flex-col flex-1 p-3.5 pt-3">
                    <div class="flex items-start gap-1.5 mb-3">
                      {{lucideIcon "map-pin" size=14 class="text-indigo-500 dark:text-indigo-400 shrink-0 mt-0.5"}}
                      <span class="text-[11px] font-medium text-indigo-600 dark:text-indigo-400
                                   leading-snug line-clamp-2 hover:underline cursor-pointer">
                        {{facility.fac_address}}
                      </span>
                    </div>

                    {{! Starting price tag }}
                    <div class="mt-auto mb-3">
                      <span class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full
                                   bg-gradient-to-r from-emerald-500 to-teal-500
                                   text-white text-[11px] font-bold tracking-wide shadow-sm
                                   shadow-emerald-500/30">
                        {{lucideIcon "tag" size=11 class="shrink-0"}}
                        Starting From:
                        <span class="font-extrabold">৳{{or facility.min_price 1500}}</span>
                      </span>
                    </div>

                    <div class="h-px bg-gradient-to-r from-transparent via-gray-200 dark:via-gray-700 to-transparent mb-3"></div>

                    <div class="flex items-center justify-between text-[10px] font-semibold gap-1">
                      <div class="flex items-center gap-0.5 text-gray-500 dark:text-gray-400">
                        {{lucideIcon "star" size=12 class="text-violet-400 shrink-0"}}
                        <span>{{facility.customer_review}}</span>
                      </div>
                      <span class="text-gray-300 dark:text-gray-600">·</span>
                      <div class="flex items-center gap-0.5 text-gray-500 dark:text-gray-400">
                        {{lucideIcon "globe" size=12 class="text-emerald-400 shrink-0"}}
                        <span>{{facility.fac_match_played}} matches</span>
                      </div>
                      <span class="text-gray-300 dark:text-gray-600">·</span>
                      <div class="flex items-center gap-0.5 text-gray-500 dark:text-gray-400">
                        <svg class="w-3 h-3 text-rose-400 shrink-0" viewBox="0 0 24 24" fill="currentColor">
                          <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/>
                        </svg>
                        <span class="text-rose-500 dark:text-rose-400 font-bold">
                          {{this.formatRating facility.platform_ratings}}
                        </span>
                      </div>
                    </div>
                  </div>

                </div>
              {{/each}}
            </div>

            <Pagonation
              @currentPage={{this.currentPage}}
              @totalPages={{this.totalPages}}
              @onNextClick={{this.goNext}}
              @onPreviousClick={{this.goPrev}}
              @onPageIndexClick={{this.goToPage}}
            />

          {{/if}}

        </div>
        {{! end main content }}

      </div>
      {{! end flex body }}

    </section>
  </template>
}
