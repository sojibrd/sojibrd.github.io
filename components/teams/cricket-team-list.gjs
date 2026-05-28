import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { service } from '@ember/service';
import { on } from '@ember/modifier';
import { modifier } from 'ember-modifier';
import SkeletonCard from './cricket/skeleton-card';
import CricketTeamCard from './cricket/cricket-team-card';

const LIMIT = 10;

function isEmpty(arr) {
  return !arr || arr.length === 0;
}

export default class CricketTeamList extends Component {
  @service store;
  @service geolocation;

  @tracked teams = [];
  @tracked isLoading = true;
  @tracked isLoadingMore = false;
  @tracked error = null;
  @tracked hasMore = false;
  @tracked currentOffset = 0;
  @tracked totalLoaded = 0;

  watchQuery = modifier((_, [query]) => {
    this.teams = [];
    this.currentOffset = 0;
    this.loadInitial(query);
  });

  constructor(owner, args) {
    super(owner, args);
    this.loadInitial();
  }

  async loadInitial(query = '') {
    this.isLoading = true;
    this.error = null;
    this.teams = [];
    this.currentOffset = 0;
    try {
      await this._fetch(0, query);
    } catch (err) {
      this.error = err.message ?? 'Failed to load teams.';
    } finally {
      this.isLoading = false;
    }
  }

  async _fetch(offset, query = '') {
    const coords = await this.geolocation.getCoords();
    const result = await this.store.query('cricket-team', {
      latitude: coords.latitude,
      longitude: coords.longitude,
      limit: LIMIT,
      offset,
      page: Math.floor(offset / LIMIT) + 1,
      country_code: 'BD',
      search_data: query,
    });
    this.teams = [...this.teams, ...Array.from(result)];
    this.totalLoaded = this.teams.length;
    const meta = result.meta ?? {};
    this.hasMore = meta.hasMore ?? false;
    this.currentOffset = meta.nextOffset ?? offset + LIMIT;
  }

  @action
  async loadMore() {
    if (this.isLoadingMore || !this.hasMore) return;
    this.isLoadingMore = true;
    try {
      await this._fetch(this.currentOffset, this.args.searchQuery ?? '');
    } catch (err) {
      console.error('Load more failed:', err);
    } finally {
      this.isLoadingMore = false;
    }
  }

  @action retry() {
    this.loadInitial(this.args.searchQuery ?? '');
  }

  get skeletons() {
    return Array.from({ length: LIMIT });
  }

  <template>
    <div class="min-h-[400px]" {{this.watchQuery @searchQuery}}>
      {{#if this.error}}
        <div class="flex flex-col items-center justify-center py-24 text-center px-4">
          <div class="w-16 h-16 mb-5 rounded-2xl bg-red-50 dark:bg-red-900/20 flex items-center justify-center">
            <svg class="w-8 h-8 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
            </svg>
          </div>
          <p class="text-sm font-bold text-gray-900 dark:text-white mb-1">Failed to load teams</p>
          <p class="text-xs text-gray-400 dark:text-gray-500 mb-5">{{this.error}}</p>
          <button type="button" class="px-6 py-2.5 text-sm font-semibold text-white bg-indigo-600 rounded-xl hover:bg-indigo-700 transition-colors" {{on "click" this.retry}}>Try Again</button>
        </div>

      {{else if this.isLoading}}
        <div class="grid grid-cols-1 gap-3 p-4 sm:grid-cols-2 sm:gap-4 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 sm:p-6">
          {{#each this.skeletons as |_|}}
            <SkeletonCard />
          {{/each}}
        </div>

      {{else}}
        <div class="grid grid-cols-1 gap-3 p-4 sm:grid-cols-2 sm:gap-4 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 sm:p-6">
          {{#each this.teams as |team|}}
            <CricketTeamCard @team={{team}} />
          {{/each}}
          {{#if this.isLoadingMore}}
            {{#each this.skeletons as |_|}}
              <SkeletonCard />
            {{/each}}
          {{/if}}
        </div>

        {{#if this.hasMore}}
          <div class="flex justify-center px-4 pb-10 pt-2">
            <button
              type="button"
              disabled={{this.isLoadingMore}}
              class="group relative inline-flex items-center gap-2.5 px-8 py-3 rounded-2xl text-sm font-bold transition-all duration-200
                {{if this.isLoadingMore 'bg-gray-100 dark:bg-gray-800 text-gray-400 cursor-not-allowed' 'bg-gradient-to-r from-emerald-500 to-cyan-500 text-white shadow-lg shadow-emerald-500/30 hover:shadow-emerald-500/50 hover:-translate-y-0.5'}}"
              {{on "click" this.loadMore}}
            >
              {{#if this.isLoadingMore}}
                <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
                </svg>
                Loading...
              {{else}}
                Load More
                <svg class="w-4 h-4 transition-transform group-hover:translate-y-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M19 9l-7 7-7-7" />
                </svg>
              {{/if}}
            </button>
          </div>
        {{/if}}

        {{#if (isEmpty this.teams)}}
          <div class="flex flex-col items-center justify-center py-24 text-center px-4">
            <div class="w-20 h-20 mb-6 rounded-3xl bg-gradient-to-br from-emerald-100 to-cyan-100 dark:from-emerald-900/30 dark:to-cyan-900/30 flex items-center justify-center">
              <svg class="w-10 h-10 text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="1.5"
                  d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z"
                />
              </svg>
            </div>
            <p class="text-base font-bold text-gray-900 dark:text-white mb-1">No cricket teams found</p>
            <p class="text-sm text-gray-500 dark:text-gray-400">No teams available in your area right now.</p>
          </div>
        {{/if}}
      {{/if}}
    </div>
  </template>
}
