import Component from '@glimmer/component';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { LinkTo } from '@ember/routing';
import config from 'spordium/config/environment';
import { inject as service } from '@ember/service';

function logoUrl(path) {
  if (!path) return '/placeholder.png';
  if (path.startsWith('data:') || path.startsWith('http')) return path;
  return `${config.APP.S3_BUCKET_URL}/${path.replace(/^\//, '')}`;
}

function initials(name) {
  if (!name) return '?';
  return name
    .split(' ')
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase() ?? '')
    .join('');
}

const SPORT_ICONS = {
  cricket: '🏏',
  football: '⚽',
  basketball: '🏀',
};

export default class MyTeamCard extends Component {
  @service router;

  get logo() {
    return logoUrl(this.args.team.team_logo);
  }
  get abbr() {
    return initials(this.args.team.team_name);
  }
  get sport() {
    return this.args.team.game_name?.toLowerCase() ?? 'cricket';
  }
  get emoji() {
    return SPORT_ICONS[this.sport] ?? '🏆';
  }
  get locationInfo() {
    const loc = this.args.team.country_of_gameplaying;
    return loc ? loc : 'Unknown location';
  }

  @action
  async handleEdit(team, event) {
    event.preventDefault();
    event.stopPropagation();
    this.router.transitionTo('teams.team', team.id);
  }

  <template>
    <LinkTo
      @route="teams.team-details"
      @model={{@team.id}}
      class="relative flex flex-col bg-white dark:bg-gray-900 rounded-2xl overflow-hidden border border-gray-100 dark:border-gray-800 shadow-sm transition-all duration-300 hover:shadow-xl hover:-translate-y-1 group"
    >
      {{! Top accent bar }}
      <div class="h-1 w-full bg-gradient-to-r from-emerald-400 via-cyan-500 to-indigo-500 shrink-0"></div>

      {{! Content: horizontal on mobile, vertical on sm+ }}
      <div class="flex flex-row sm:flex-col flex-1">

        {{! Logo zone: fixed width column on mobile, full-width top zone on sm+ }}
        <div class="relative flex items-center justify-center w-24 shrink-0 sm:w-full sm:h-40 bg-gradient-to-br from-slate-50 via-white to-indigo-50/60 dark:from-gray-800 dark:via-gray-900 dark:to-indigo-950/40 overflow-hidden">
          <div class="absolute inset-0 opacity-30" style="background: radial-gradient(circle at 50% 120%, #6366f120 0%, transparent 70%);"></div>

          {{#if this.logo}}
            <img src={{this.logo}} alt={{@team.team_name}} loading="lazy" class="relative z-10 h-14 w-14 sm:h-24 sm:w-24 object-contain drop-shadow-lg" />
          {{else}}
            <div class="relative z-10 h-11 w-11 sm:h-20 sm:w-20 rounded-2xl bg-gradient-to-br from-emerald-500 to-cyan-600 flex items-center justify-center shadow-xl">
              <span class="text-sm sm:text-2xl font-black text-white tracking-tight">{{this.abbr}}</span>
            </div>
          {{/if}}

          <span class="absolute top-2 right-2 text-sm sm:text-lg" title={{@team.game_name}}>
            {{this.emoji}}
          </span>
        </div>

        {{! Info panel }}
        <div class="flex flex-col flex-1 min-w-0 px-3 sm:px-4 py-3 sm:pt-3 sm:pb-4 gap-2 sm:gap-3">

          {{! Name + location }}
          <div class="text-left sm:text-center">
            <h3 class="font-bold text-gray-900 dark:text-white text-sm sm:text-[15px] leading-snug truncate" title={{@team.team_name}}>
              {{@team.team_name}}
            </h3>
            <p class="mt-0.5 text-[11px] text-gray-400 dark:text-gray-500 flex items-center sm:justify-center gap-1">
              <svg class="w-3 h-3 shrink-0 text-emerald-400" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M5.05 4.05a7 7 0 119.9 9.9L10 18.9l-4.95-4.95a7 7 0 010-9.9zM10 11a2 2 0 100-4 2 2 0 000 4z" clip-rule="evenodd" />
              </svg>
              <span class="truncate">{{this.locationInfo}}</span>
            </p>
          </div>

          {{! Stats: hidden on mobile, shown on sm+ }}
          <div class="hidden sm:grid grid-cols-3 gap-1.5 text-center">
            {{#if @team.played}}
              <div class="bg-gray-50 dark:bg-gray-800/60 rounded-xl py-1.5">
                <p class="text-[9px] font-bold uppercase tracking-wider text-gray-400">Match</p>
                <p class="text-sm font-extrabold text-gray-800 dark:text-gray-200">{{@team.played}}</p>
              </div>
            {{/if}}
            {{#if @team.won_games}}
              <div class="bg-emerald-50 dark:bg-emerald-950/30 rounded-xl py-1.5">
                <p class="text-[9px] font-bold uppercase tracking-wider text-emerald-500">Won</p>
                <p class="text-sm font-extrabold text-emerald-700 dark:text-emerald-400">{{@team.won_games}}</p>
              </div>
            {{/if}}
            {{#if @team.lost_games}}
              <div class="bg-red-50 dark:bg-red-950/30 rounded-xl py-1.5">
                <p class="text-[9px] font-bold uppercase tracking-wider text-red-400">Lost</p>
                <p class="text-sm font-extrabold text-red-600 dark:text-red-400">{{@team.lost_games}}</p>
              </div>
            {{/if}}
          </div>

          {{! Actions }}
          <div class="mt-auto flex gap-1.5">
            <LinkTo
              @route="teams.team-details"
              @model={{@team.id}}
              class="flex-1 py-1.5 sm:py-2 rounded-xl text-center text-xs font-bold tracking-wide text-indigo-600 dark:text-indigo-400 bg-indigo-50 dark:bg-indigo-950/40 border border-indigo-100 dark:border-indigo-900/40 hover:bg-indigo-600 hover:text-white hover:border-indigo-600 transition-all duration-200"
            >
              View →
            </LinkTo>

            <button
              type="button"
              class="flex-1 py-1.5 sm:py-2 rounded-xl text-center text-xs font-bold tracking-wide text-violet-600 dark:text-violet-400 bg-violet-50 dark:bg-violet-950/40 border border-violet-100 dark:border-violet-900/40 hover:bg-violet-600 hover:text-white hover:border-violet-600 transition-all duration-200"
              {{on "click" (fn this.handleEdit @team)}}
            >
              Edit
            </button>

            <button
              type="button"
              class="px-2.5 py-1.5 sm:py-2 rounded-xl text-xs font-bold text-red-500 dark:text-red-400 bg-red-50 dark:bg-red-950/30 border border-red-100 dark:border-red-900/40 hover:bg-red-500 hover:text-white hover:border-red-500 transition-all duration-200"
              {{on "click" (fn @onDelete @team)}}
            >
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
              </svg>
            </button>
          </div>
        </div>
      </div>
    </LinkTo>
  </template>
}
