import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { service } from '@ember/service';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { LinkTo } from '@ember/routing';
import config from 'spordium/config/environment';

export default class WatchLaterPageComponent extends Component {
  @service api;
  @service session;
  @service router;

  @tracked games = [];
  @tracked isLoading = true;
  @tracked error = null;

  bucket = config.APP.S3_BUCKET_URL;

  constructor() {
    super(...arguments);
    this.loadWatchLater();
  }

  getImageUrl(path) {
    if (!path) return '/images/default-team.png';
    if (path.startsWith('http')) return path;
    const clean = path.startsWith('/') ? path.substring(1) : path;
    return `${this.bucket}/${clean}`;
  }

  formatDate(dateStr) {
    if (!dateStr) return '';
    const d = new Date(dateStr);
    return d.toLocaleDateString('en-US', { day: 'numeric', month: 'short', year: 'numeric' });
  }

  formatTime(dateStr) {
    if (!dateStr) return '';
    const d = new Date(dateStr);
    return d.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: true });
  }

  @action
  async loadWatchLater() {
    this.isLoading = true;
    this.error = null;
    try {
      const userId = this.session.currentUser?.user_id;
      const loca = JSON.stringify({ user_id: userId, limit: 10, offset: 0 });
      const result = await this.api.get(`/home/get_watchlatergame/${loca}/`);
      this.games = (result.data || []).map((g) => ({
        id: g.game_id || g.id,
        name: g.game_name || g.name,
        datetime: g.game_datetime || g.datetime,
        formattedDate: this.formatDate(g.game_datetime || g.datetime),
        formattedTime: this.formatTime(g.game_datetime || g.datetime),
        isStarted: g.is_started || g.is_start || false,
        isFinished: g.is_finished || false,
        matchType: g.match_type || 'tournament',
        team1: {
          name: g.team1_details?.team_name || g.team1_name || 'Team 1',
          logo: this.getImageUrl(g.team1_details?.team_logo || g.team1_logo),
        },
        team2: {
          name: g.team2_details?.team_name || g.team2_name || 'Team 2',
          logo: this.getImageUrl(g.team2_details?.team_logo || g.team2_logo),
        },
      }));
    } catch (e) {
      console.error('Watch later fetch failed:', e);
      this.error = 'Failed to load Watch Later list.';
    } finally {
      this.isLoading = false;
    }
  }

  @action
  goToGame(gameId) {
    this.router.transitionTo('match.match-details', { queryParams: { gameid: gameId } });
  }

  get skeletonArray() {
    return [1, 2, 3, 4, 5, 6];
  }

  <template>
    <div class="min-h-screen bg-gray-50 dark:bg-slate-900 py-6 -mx-4 sm:-mx-6 lg:-mx-8">
      <div class="px-4 sm:px-6 lg:px-8 max-w-5xl mx-auto">

        {{! Header }}
        <div class="flex items-center gap-3 mb-6">
          <div class="w-9 h-9 rounded-xl bg-emerald-500/10 flex items-center justify-center">
            <svg class="w-5 h-5 text-emerald-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <circle cx="12" cy="12" r="10"/>
              <polyline points="12 6 12 12 16 14"/>
            </svg>
          </div>
          <div>
            <h1 class="text-gray-900 dark:text-white text-lg font-bold">Watch Later</h1>
            <p class="text-gray-500 dark:text-gray-400 text-xs">Matches you saved to watch</p>
          </div>
        </div>

        {{! Loading }}
        {{#if this.isLoading}}
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {{#each this.skeletonArray as |_|}}
              <div class="bg-white dark:bg-slate-800 rounded-2xl p-5 animate-pulse border border-gray-200 dark:border-slate-700/50">
                <div class="flex justify-between items-start mb-4">
                  <div class="h-4 bg-gray-200 dark:bg-slate-700 rounded w-24"></div>
                  <div class="h-5 bg-gray-200 dark:bg-slate-700 rounded w-16"></div>
                </div>
                <div class="flex items-center justify-between mb-4">
                  <div class="flex items-center gap-3">
                    <div class="w-11 h-11 bg-gray-200 dark:bg-slate-700 rounded-xl"></div>
                    <div class="h-4 bg-gray-200 dark:bg-slate-700 rounded w-20"></div>
                  </div>
                  <div class="h-4 bg-gray-200 dark:bg-slate-700 rounded w-8"></div>
                  <div class="flex items-center gap-3">
                    <div class="h-4 bg-gray-200 dark:bg-slate-700 rounded w-20"></div>
                    <div class="w-11 h-11 bg-gray-200 dark:bg-slate-700 rounded-xl"></div>
                  </div>
                </div>
              </div>
            {{/each}}
          </div>

        {{! Error }}
        {{else if this.error}}
          <div class="bg-white dark:bg-slate-800 rounded-2xl p-10 text-center border border-gray-200 dark:border-slate-700/50">
            <div class="w-14 h-14 mx-auto mb-4 bg-red-500/10 rounded-full flex items-center justify-center">
              <svg class="w-7 h-7 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/>
              </svg>
            </div>
            <p class="text-gray-900 dark:text-white font-semibold mb-1">Something went wrong</p>
            <p class="text-gray-500 dark:text-gray-400 text-sm mb-4">{{this.error}}</p>
            <button type="button" {{on "click" this.loadWatchLater}}
              class="px-5 py-2 bg-emerald-600 hover:bg-emerald-500 text-white text-sm font-medium rounded-xl transition-colors">
              Try Again
            </button>
          </div>

        {{! Game List }}
        {{else if this.games.length}}
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {{#each this.games as |game|}}
              <div
                role="button"
                tabindex="0"
                class="bg-white dark:bg-slate-800 rounded-2xl p-5 border border-gray-200 dark:border-slate-700/50
                       hover:border-emerald-500/50 hover:shadow-lg hover:shadow-emerald-500/10
                       transition-all cursor-pointer group"
                {{on "click" (fn this.goToGame game.id)}}
              >
                {{! Status + date row }}
                <div class="flex items-center justify-between mb-4">
                  <div>
                    <p class="text-gray-500 dark:text-gray-400 text-xs">{{game.formattedDate}}</p>
                    <p class="text-gray-400 dark:text-gray-500 text-[10px]">{{game.formattedTime}}</p>
                  </div>
                  {{#if game.isFinished}}
                    <span class="px-2.5 py-1 bg-slate-500 text-white text-[10px] font-semibold rounded-full">Finished</span>
                  {{else if game.isStarted}}
                    <span class="inline-flex items-center gap-1.5 px-2.5 py-1 bg-red-500 text-white text-[10px] font-semibold rounded-full">
                      <span class="w-1.5 h-1.5 bg-white rounded-full animate-pulse"></span>LIVE
                    </span>
                  {{else}}
                    <span class="px-2.5 py-1 bg-emerald-500/15 text-emerald-400 border border-emerald-400/30 text-[10px] font-semibold rounded-full">Upcoming</span>
                  {{/if}}
                </div>

                {{! Teams row }}
                <div class="flex items-center justify-between gap-2">
                  <div class="flex items-center gap-2.5 flex-1 min-w-0">
                    <div class="w-10 h-10 rounded-xl overflow-hidden bg-white dark:bg-slate-700 p-1 flex-shrink-0 shadow">
                      <img src={{game.team1.logo}} alt={{game.team1.name}} class="w-full h-full object-contain" />
                    </div>
                    <p class="text-gray-900 dark:text-white text-sm font-semibold truncate">{{game.team1.name}}</p>
                  </div>

                  <span class="text-gray-400 dark:text-slate-500 text-xs font-bold flex-shrink-0">VS</span>

                  <div class="flex items-center gap-2.5 flex-1 min-w-0 justify-end">
                    <p class="text-gray-900 dark:text-white text-sm font-semibold truncate text-right">{{game.team2.name}}</p>
                    <div class="w-10 h-10 rounded-xl overflow-hidden bg-white dark:bg-slate-700 p-1 flex-shrink-0 shadow">
                      <img src={{game.team2.logo}} alt={{game.team2.name}} class="w-full h-full object-contain" />
                    </div>
                  </div>
                </div>

                {{! Game name }}
                <p class="text-gray-400 dark:text-gray-500 text-xs text-center mt-3 truncate group-hover:text-emerald-400 transition-colors">
                  {{game.name}}
                </p>
              </div>
            {{/each}}
          </div>

        {{! Empty }}
        {{else}}
          <div class="bg-white dark:bg-slate-800 rounded-2xl p-10 text-center border border-gray-200 dark:border-slate-700/50">
            <div class="w-14 h-14 mx-auto mb-4 bg-emerald-500/10 rounded-full flex items-center justify-center">
              <svg class="w-7 h-7 text-emerald-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <circle cx="12" cy="12" r="10"/>
                <polyline points="12 6 12 12 16 14"/>
              </svg>
            </div>
            <p class="text-gray-900 dark:text-white font-semibold mb-1">No saved matches</p>
            <p class="text-gray-500 dark:text-gray-400 text-sm mb-4">Tap the clock icon on any upcoming match to save it here.</p>
            <LinkTo @route="match"
              class="inline-block px-5 py-2 bg-emerald-600 hover:bg-emerald-500 text-white text-sm font-medium rounded-xl transition-colors">
              Browse Matches
            </LinkTo>
          </div>

        {{/if}}

      </div>
    </div>
  </template>
}
