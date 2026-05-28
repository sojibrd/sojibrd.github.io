import { fn } from '@ember/helper';
import { on } from '@ember/modifier';
import { action } from '@ember/object';
import Component from '@glimmer/component';
import { tracked, cached } from '@glimmer/tracking';
import MatchCard from 'spordium/components/teams/previous-match-card';

// ─── Constants ───────────────────────────────────────────────────────────────
const PER_PAGE = 15;

const RESULT_OPTIONS = [
  { value: 'all', label: 'All Results' },
  { value: 'won', label: 'Won' },
  { value: 'lost', label: 'Lost' },
  { value: 'draw', label: 'Draw' },
];

const DATE_OPTIONS = [
  { value: 'all', label: 'All Time' },
  { value: 'last30', label: 'Last 30 Days' },
  { value: 'last90', label: 'Last 90 Days' },
  { value: 'thisYear', label: 'This Year' },
];

// ─── Pure helpers ─────────────────────────────────────────────────────────────
function getResult(match, teamId) {
  if (!match.winner_team) return 'draw';
  return String(match.winner_team) === String(teamId) ? 'won' : 'lost';
}

function formatDate(dateStr) {
  if (!dateStr) return '—';
  return new Date(dateStr).toLocaleDateString('en-US', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
}

function isWithinDays(dateStr, days) {
  if (!dateStr) return false;
  return Date.now() - new Date(dateStr).getTime() <= days * 86400_000;
}

function isThisYear(dateStr) {
  if (!dateStr) return false;
  return new Date(dateStr).getFullYear() === new Date().getFullYear();
}

// ─── PreviousMatch ────────────────────────────────────────────────────────────
// @matches  — team-details.gjs থেকে pass করা array (already fetched)
// @teamId   — result (won/lost) calculate করতে
// @isLoading — parent loading state
// @error    — parent error state
export default class PreviousMatch extends Component {
  @tracked searchQuery = '';
  @tracked resultFilter = 'all';
  @tracked dateFilter = 'all';
  @tracked currentPage = 1;

  // API [] দিলে dummy দেখাবে, real data আসলে সেটা দেখাবে
  get allMatches() {
    const raw = this.args.matches ?? [];
    return raw.length > 0 ? raw : [];
  }

  @cached
  get filteredMatches() {
    const teamId = this.args.teamId;
    let list = this.allMatches;

    if (this.resultFilter !== 'all') {
      list = list.filter((m) => getResult(m, teamId) === this.resultFilter);
    }

    if (this.dateFilter === 'last30') {
      list = list.filter((m) => isWithinDays(m.game_datetime, 30));
    } else if (this.dateFilter === 'last90') {
      list = list.filter((m) => isWithinDays(m.game_datetime, 90));
    } else if (this.dateFilter === 'thisYear') {
      list = list.filter((m) => isThisYear(m.game_datetime));
    }

    const q = this.searchQuery.trim().toLowerCase();
    if (q) {
      list = list.filter((m) => {
        const t1 = (m.team1_details?.team_name ?? '').toLowerCase();
        const t2 = (m.team2_details?.team_name ?? '').toLowerCase();
        return t1.includes(q) || t2.includes(q);
      });
    }

    return list;
  }

  get totalPages() {
    return Math.max(1, Math.ceil(this.filteredMatches.length / PER_PAGE));
  }

  get pagedMatches() {
    const start = (this.currentPage - 1) * PER_PAGE;
    return this.filteredMatches.slice(start, start + PER_PAGE);
  }

  get pageNumbers() {
    const total = this.totalPages;
    const current = this.currentPage;
    const start = Math.max(1, current - 2);
    const end = Math.min(total, current + 2);
    const pages = [];
    for (let i = start; i <= end; i++) pages.push(i);
    return pages;
  }

  get showingFrom() {
    return (this.currentPage - 1) * PER_PAGE + 1;
  }
  get showingTo() {
    return Math.min(this.currentPage * PER_PAGE, this.filteredMatches.length);
  }
  get isEmpty() {
    return !this.args.isLoading && this.filteredMatches.length === 0;
  }
  get hasFilters() {
    return this.searchQuery.trim() !== '' || this.resultFilter !== 'all' || this.dateFilter !== 'all';
  }

  @action onSearch(e) {
    this.searchQuery = e.target.value;
    this.currentPage = 1;
  }
  @action setResult(e) {
    this.resultFilter = e.target.value;
    this.currentPage = 1;
  }
  @action setDate(e) {
    this.dateFilter = e.target.value;
    this.currentPage = 1;
  }
  @action goToPage(page) {
    if (page >= 1 && page <= this.totalPages) this.currentPage = page;
  }
  @action clearFilters() {
    this.searchQuery = '';
    this.resultFilter = 'all';
    this.dateFilter = 'all';
    this.currentPage = 1;
  }

  <template>
    <div class="space-y-4">

      {{! ── Filter Bar ── }}
      <div class="flex flex-col sm:flex-row gap-2">
        <div class="relative flex-1">
          <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400 pointer-events-none" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          </svg>
          <input
            type="text"
            placeholder="Search opponent team..."
            value={{this.searchQuery}}
            class="w-full pl-9 pr-4 py-2 text-sm border border-gray-200 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-indigo-500/30 focus:border-indigo-500 transition-all"
            {{on "input" this.onSearch}}
          />
        </div>

        <select
          class="py-2 px-3 text-sm border border-gray-200 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 focus:outline-none focus:ring-2 focus:ring-indigo-500/30 focus:border-indigo-500 transition-all"
          {{on "change" this.setResult}}
        >
          {{#each RESULT_OPTIONS as |opt|}}
            <option value={{opt.value}} selected={{isEq opt.value this.resultFilter}}>
              {{opt.label}}
            </option>
          {{/each}}
        </select>

        <select
          class="py-2 px-3 text-sm border border-gray-200 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 focus:outline-none focus:ring-2 focus:ring-indigo-500/30 focus:border-indigo-500 transition-all"
          {{on "change" this.setDate}}
        >
          {{#each DATE_OPTIONS as |opt|}}
            <option value={{opt.value}} selected={{isEq opt.value this.dateFilter}}>
              {{opt.label}}
            </option>
          {{/each}}
        </select>
      </div>

      {{! ── Loading ── }}
      {{#if @isLoading}}
        <div class="space-y-3">
          {{#each (makeArray 5) as |_|}}
            <div class="h-16 rounded-xl bg-gray-100 dark:bg-gray-800/60 animate-pulse"></div>
          {{/each}}
        </div>

        {{! ── Error ── }}
      {{else if @error}}
        <div class="flex flex-col items-center justify-center py-12 text-center">
          <p class="text-sm text-red-500 mb-3">{{@error}}</p>
          <button type="button" class="px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-lg hover:bg-indigo-700 transition-colors" {{on "click" @onRetry}}>Retry</button>
        </div>

        {{! ── Empty ── }}
      {{else if this.isEmpty}}
        <div class="flex flex-col items-center justify-center py-16 text-center">
          <div class="w-14 h-14 mb-4 rounded-2xl bg-gray-100 dark:bg-gray-800 flex items-center justify-center">
            <svg class="w-7 h-7 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
            </svg>
          </div>
          <p class="text-sm font-semibold text-gray-900 dark:text-white mb-1">No matches found</p>
          {{#if this.hasFilters}}
            <p class="text-xs text-gray-500 dark:text-gray-400 mb-3">No results for current filters</p>
            <button type="button" class="text-xs text-indigo-600 dark:text-indigo-400 font-medium hover:underline" {{on "click" this.clearFilters}}>Clear filters</button>
          {{/if}}
        </div>

        {{! ── List ── }}
      {{else}}
        <p class="text-xs text-gray-500 dark:text-gray-400">
          Showing
          <span class="font-semibold text-gray-700 dark:text-gray-300">{{this.showingFrom}}–{{this.showingTo}}</span>
          of
          <span class="font-semibold text-gray-700 dark:text-gray-300">{{this.filteredMatches.length}}</span>
          matches
        </p>

        <div class="space-y-3">
          {{#each this.pagedMatches as |match|}}
            <MatchCard @match={{match}} @teamId={{@teamId}} />
          {{/each}}
        </div>

        {{! ── Pagination ── }}
        {{#if (gt this.totalPages 1)}}
          <div class="flex items-center justify-center gap-1 pt-2">

            <button
              type="button"
              disabled={{isEq this.currentPage 1}}
              class="w-8 h-8 flex items-center justify-center rounded-lg text-sm transition-colors
                {{if (isEq this.currentPage 1) 'text-gray-300 dark:text-gray-600 cursor-not-allowed' 'text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800'}}"
              {{on "click" (fn this.goToPage (dec this.currentPage))}}
            >←</button>

            {{#if (gt (firstOf this.pageNumbers) 1)}}
              <button type="button" class="w-8 h-8 flex items-center justify-center rounded-lg text-sm text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors" {{on "click" (fn this.goToPage 1)}}>1</button>
              {{#if (gt (firstOf this.pageNumbers) 2)}}
                <span class="text-gray-400 px-1 text-sm">…</span>
              {{/if}}
            {{/if}}

            {{#each this.pageNumbers as |page|}}
              <button
                type="button"
                class="w-8 h-8 flex items-center justify-center rounded-lg text-sm font-medium transition-colors
                  {{if (isEq page this.currentPage) 'bg-indigo-600 text-white shadow-sm' 'text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800'}}"
                {{on "click" (fn this.goToPage page)}}
              >{{page}}</button>
            {{/each}}

            {{#if (lt (lastOf this.pageNumbers) this.totalPages)}}
              {{#if (lt (lastOf this.pageNumbers) (dec this.totalPages))}}
                <span class="text-gray-400 px-1 text-sm">…</span>
              {{/if}}
              <button
                type="button"
                class="w-8 h-8 flex items-center justify-center rounded-lg text-sm text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
                {{on "click" (fn this.goToPage this.totalPages)}}
              >{{this.totalPages}}</button>
            {{/if}}

            <button
              type="button"
              disabled={{isEq this.currentPage this.totalPages}}
              class="w-8 h-8 flex items-center justify-center rounded-lg text-sm transition-colors
                {{if (isEq this.currentPage this.totalPages) 'text-gray-300 dark:text-gray-600 cursor-not-allowed' 'text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800'}}"
              {{on "click" (fn this.goToPage (inc this.currentPage))}}
            >→</button>

          </div>
        {{/if}}
      {{/if}}

    </div>
  </template>
}

// ─── Template helpers ─────────────────────────────────────────────────────────
function isEq(a, b) {
  return a === b;
}
function gt(a, b) {
  return a > b;
}
function lt(a, b) {
  return a < b;
}
function inc(n) {
  return n + 1;
}
function dec(n) {
  return n - 1;
}
function firstOf(arr) {
  return arr[0];
}
function lastOf(arr) {
  return arr[arr.length - 1];
}
function makeArray(n) {
  return Array.from({ length: n });
}
