// app/components/tournament/list/all-list.gjs
import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { service } from '@ember/service';
import { task, timeout } from 'ember-concurrency';
import Card from './card';
import CardSkeleton from './card-skeleton';
import EmptyState from './empty-state';
import FilterPanel from './filter-panel';
import Pagonation from '../../pagonation';
import lucideIcon from 'spordium/helpers/lucide-icon';
import { gt } from 'ember-truth-helpers';

const PAGE_SIZE = 50;
const API_BASE = 'https://khelasearch.adnanfoundation.com';
const SEARCH_DEBOUNCE_MS = 500;

const DEFAULT_FILTERS = {
  m_format: '',
  t_m_format: '',
  t_type: '',
  ball_type: '',
  sport: '',
  status: '',
  format: '',
  teamRange: '',
  dateFrom: '',
};

// ══════════════════════════════════════════════════════════════════════════════
export default class TournamentAllList extends Component {
  @service router;
  @service geolocation;
  @service session;

  @tracked tournaments = [];
  @tracked error = null;
  @tracked currentPage = 1;
  @tracked totalCount = 0;
  @tracked searchQuery = '';
  @tracked filterOpen = false;
  @tracked filters = { ...DEFAULT_FILTERS };

  constructor(owner, args) {
    super(owner, args);
    // ✅ Initial load — no debounce needed
    this.fetchTournamentsTask.perform(1, { debounce: false });
  }

  // ── Derived ───────────────────────────────────────────────────────────────
  get totalPages() {
    return Math.max(1, Math.ceil(this.totalCount / PAGE_SIZE));
  }

  get isEmpty() {
    return (
      !this.fetchTournamentsTask.isRunning &&
      !this.error &&
      this.tournaments.length === 0
    );
  }

  get hasResults() {
    return (
      !this.fetchTournamentsTask.isRunning &&
      !this.error &&
      this.tournaments.length > 0
    );
  }

  get activeFilterCount() {
    return Object.values(this.filters).filter(Boolean).length;
  }

  // ── ember-concurrency Task ────────────────────────────────────────────────
  /**
   * `restartable` — নতুন perform() call আসলে চলমান task cancel হয়।
   * এতে race condition এবং stale data problem দুটোই solve হয়।
   */
  @task({ restartable: true })
  *fetchTournamentsTask(page = 1, { debounce = true } = {}) {
    // ✅ Search এবং filter change-এ debounce — initial load-এ skip
    if (debounce) {
      yield timeout(SEARCH_DEBOUNCE_MS);
    }

    this.error = null;
    this.currentPage = page;

    const location = yield this.geolocation.getCoords();

    const params = new URLSearchParams({
      longitude: location.longitude,
      latitude: location.latitude,
      offset: page > 1 ? (page - 1) * PAGE_SIZE : 0,
      limit: PAGE_SIZE,
      country_code: 'BD',
      ...(this.searchQuery && { search_data: this.searchQuery }),
      ...(this.filters.sport && { sport: this.filters.sport }),
      ...(this.filters.status && { status: this.filters.status }),
      ...(this.filters.m_format && {
        tournament_match_format: this.filters.m_format,
      }),
      ...(this.filters.t_m_format && {
        tournament_format: this.filters.t_m_format,
      }),
      ...(this.filters.dateFrom && {
        date: Date.parse(this.filters.dateFrom),
      }),
      ...(this.filters.t_type && { tournament_type: this.filters.t_type }),
      ...(this.filters.ball_type && { ball_type: this.filters.ball_type }),
    });

    try {
      const res = yield fetch(
        `${API_BASE}/search/upcomming-tournament-search_v2/?${params}`,
      );
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json = yield res.json();

      this.tournaments = json?.results ?? [];
      this.totalCount = json?.total ?? this.tournaments.length;
    } catch {
      // ✅ Task cancel হলে error set করব না (TaskCancelation is silent)
      this.error = 'Failed to load tournaments. Please try again.';
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  @action
  onSearchInput(e) {
    this.searchQuery = e.target.value;
    // ✅ debounce: true — restartable task পুরনো timeout cancel করবে
    this.fetchTournamentsTask.perform(1, { debounce: true });
  }

  @action
  onSearchKeydown(e) {
    if (e.key === 'Enter') {
      // Enter press-এ সাথে সাথে search — debounce skip
      this.fetchTournamentsTask.perform(1, { debounce: false });
    }
  }

  @action
  clearSearch() {
    this.searchQuery = '';
    this.fetchTournamentsTask.perform(1, { debounce: false });
  }

  @action
  onFilterChange(key, valueOrEvent) {
    const value =
      typeof valueOrEvent === 'string'
        ? valueOrEvent
        : (valueOrEvent?.target?.value ?? '');
    this.filters = { ...this.filters, [key]: value };
    this.fetchTournamentsTask.perform(1, { debounce: false });
  }

  @action
  resetFilters() {
    this.filters = { ...DEFAULT_FILTERS };
    this.fetchTournamentsTask.perform(1, { debounce: false });
  }

  @action
  toggleFilter() {
    this.filterOpen = !this.filterOpen;
  }

  @action
  closeFilter() {
    this.filterOpen = false;
  }

  @action
  openTournament(tournament) {
    this.router.transitionTo('tournament.tournament-details', {
      queryParams: {
        id: tournament.tournament_id ?? tournament.id,
        tab: 'overview',
      },
    });
  }

  @action
  retry() {
    this.fetchTournamentsTask.perform(this.currentPage, { debounce: false });
  }

  // ── Pagination handlers ──────────────────────────────────────────────────
  get onPreviousClick() {
    return () =>
      this.fetchTournamentsTask.perform(this.currentPage - 1, {
        debounce: false,
      });
  }

  get onNextClick() {
    return () =>
      this.fetchTournamentsTask.perform(this.currentPage + 1, {
        debounce: false,
      });
  }

  get onPageIndexClick() {
    return (page) =>
      this.fetchTournamentsTask.perform(page, { debounce: false });
  }

  <template>
    <div class="flex gap-6">

      {{! Filter sidebar }}
      <FilterPanel
        @filters={{this.filters}}
        @onChange={{this.onFilterChange}}
        @onReset={{this.resetFilters}}
        @isOpen={{this.filterOpen}}
        @onClose={{this.closeFilter}}
      />

      {{! Main content }}
      <div class="flex-1 min-w-0">

        {{! Toolbar }}
        <div class="flex items-center gap-3 mb-5">
          {{! Search }}
          <div class="relative flex-1">
            <span
              class="absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none"
            >
              {{lucideIcon "search" class="w-4 h-4 text-gray-400"}}
            </span>
            <input
              type="text"
              placeholder="Search tournaments…"
              value={{this.searchQuery}}
              {{on "input" this.onSearchInput}}
              {{on "keydown" this.onSearchKeydown}}
              class="w-full pl-9 pr-9 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
            {{#if this.searchQuery}}
              <button
                type="button"
                {{on "click" this.clearSearch}}
                class="absolute right-3 top-1/2 -translate-y-1/2"
              >
                {{lucideIcon
                  "x"
                  class="w-3.5 h-3.5 text-gray-400 hover:text-gray-600"
                }}
              </button>
            {{/if}}
          </div>

          {{! Filter toggle }}
          <button
            type="button"
            {{on "click" this.toggleFilter}}
            class="relative flex items-center gap-2 px-4 py-2.5 text-sm font-medium rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:border-blue-400 transition-colors"
          >
            {{lucideIcon "sliders-horizontal" class="w-4 h-4"}}
            Filters
            {{#if this.activeFilterCount}}
              <span
                class="absolute -top-1.5 -right-1.5 w-4 h-4 text-[10px] font-bold rounded-full bg-blue-600 text-white flex items-center justify-center"
              >
                {{this.activeFilterCount}}
              </span>
            {{/if}}
          </button>
        </div>

        {{! Results count }}
        {{#if this.hasResults}}
          <p class="text-xs text-gray-500 dark:text-gray-400 mb-4">
            {{this.totalCount}}
            tournament{{if (gt this.totalCount 1) "s"}}
          </p>
        {{/if}}

        {{! Grid — isLoading এখন task.isRunning থেকে আসছে }}
        {{#if this.fetchTournamentsTask.isRunning}}
          <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">
            <CardSkeleton />
          </div>

        {{else if this.error}}
          <div class="flex flex-col items-center justify-center py-20 gap-3">
            <p class="text-sm text-red-500">{{this.error}}</p>
            <button
              type="button"
              {{on "click" this.retry}}
              class="px-4 py-2 text-sm font-medium rounded-xl bg-blue-600 text-white hover:bg-blue-700"
            >
              Retry
            </button>
          </div>

        {{else if this.isEmpty}}
          <EmptyState
            @heading="No tournaments found"
            @subtext="Try a different search or clear your filters."
            @onReset={{if this.activeFilterCount this.resetFilters}}
          />

        {{else}}
          <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">
            {{#each this.tournaments as |t|}}
              <Card @tournament={{t}} @onClick={{this.openTournament}} />
            {{/each}}
          </div>

          {{#if (gt this.totalPages 1)}}
            <div class="mt-6">
              <Pagonation
                @currentPage={{this.currentPage}}
                @totalPages={{this.totalPages}}
                @onPreviousClick={{this.onPreviousClick}}
                @onNextClick={{this.onNextClick}}
                @onPageIndexClick={{this.onPageIndexClick}}
              />
            </div>
          {{/if}}
        {{/if}}

      </div>
    </div>
  </template>
}
