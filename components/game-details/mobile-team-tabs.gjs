import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { LinkTo } from '@ember/routing';
import { service } from '@ember/service';
import { eq } from 'ember-truth-helpers';

const add = (a, b) => a + b;

export default class MobileTeamTabsComponent extends Component {
  @service api;
  @service router;

  @tracked activeTab = 'team1';
  @tracked navigatingPlayerId = null;

  @action
  selectTeam1() {
    this.activeTab = 'team1';
  }

  @action
  selectTeam2() {
    this.activeTab = 'team2';
  }

  get isTeam1Active() {
    return this.activeTab === 'team1';
  }

  get isTeam2Active() {
    return this.activeTab === 'team2';
  }

  get activeTeam() {
    return this.activeTab === 'team1' ? this.args.team1 : this.args.team2;
  }

  @action
  async goToPlayer(player) {
    if (this.navigatingPlayerId) return;
    this.navigatingPlayerId = player.id;
    try {
      const res = await this.api.get(`/auth_user/get_profile_info/`, { user_id: player.id });
      const username = res?.data?.user_username;
      if (username) {
        this.router.transitionTo('player', username);
      } else {
        this.router.transitionTo('player', player.id);
      }
    } catch {
      this.router.transitionTo('player', player.id);
    } finally {
      this.navigatingPlayerId = null;
    }
  }

  <template>
    <div class="bg-white dark:bg-slate-800 rounded-2xl overflow-hidden shadow-lg border border-gray-200 dark:border-slate-700/50">

      {{! Tab Headers }}
      <div class="flex">
        <button
          type="button"
          class="flex-1 flex items-center justify-center gap-2 py-3.5 px-2 transition-all relative
            {{if this.isTeam1Active 'bg-gray-100 dark:bg-slate-700 text-gray-900 dark:text-white' 'bg-white dark:bg-slate-800/50 text-gray-500 hover:bg-gray-50 dark:hover:bg-slate-700/30'}}"
          {{on "click" this.selectTeam1}}
        >
          {{#if this.isTeam1Active}}
            <div class="absolute bottom-0 left-2 right-2 h-0.5 bg-gradient-to-r from-red-500 to-orange-400 rounded-full"></div>
          {{/if}}
          <div class="w-9 h-9 rounded-lg overflow-hidden bg-white p-0.5 flex-shrink-0 shadow-md border border-gray-200 dark:border-transparent">
            <img src={{@team1.logo}} alt={{@team1.name}} class="w-full h-full object-contain" />
          </div>
          <span class="text-[11px] font-semibold truncate max-w-[80px]">{{@team1.name}}</span>
        </button>

        <div class="w-px bg-gray-200 dark:bg-slate-700"></div>

        <button
          type="button"
          class="flex-1 flex items-center justify-center gap-2 py-3.5 px-2 transition-all relative
            {{if this.isTeam2Active 'bg-gray-100 dark:bg-slate-700 text-gray-900 dark:text-white' 'bg-white dark:bg-slate-800/50 text-gray-500 hover:bg-gray-50 dark:hover:bg-slate-700/30'}}"
          {{on "click" this.selectTeam2}}
        >
          {{#if this.isTeam2Active}}
            <div class="absolute bottom-0 left-2 right-2 h-0.5 bg-gradient-to-r from-cyan-500 to-blue-400 rounded-full"></div>
          {{/if}}
          <div class="w-9 h-9 rounded-lg overflow-hidden bg-white p-0.5 flex-shrink-0 shadow-md border border-gray-200 dark:border-transparent">
            <img src={{@team2.logo}} alt={{@team2.name}} class="w-full h-full object-contain" />
          </div>
          <span class="text-[11px] font-semibold truncate max-w-[80px]">{{@team2.name}}</span>
        </button>
      </div>

      {{! Team Stats }}
      <div class="flex items-center justify-center gap-4 py-3 bg-gray-50 dark:bg-slate-900/50 border-y border-gray-200 dark:border-slate-700/50">
        <LinkTo
          @route="teams.team-details"
          @model={{this.activeTeam.id}}
          class="text-[10px] text-cyan-600 dark:text-cyan-400 bg-gray-100 dark:bg-slate-700/80 px-3 py-1 rounded-md font-medium
                 hover:bg-gray-200 dark:hover:bg-slate-600 transition-colors flex items-center gap-1"
        >
          View Team
          <svg class="w-2.5 h-2.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7"/>
          </svg>
        </LinkTo>
      </div>

      {{! Players List }}
      <div class="p-3 space-y-2.5">
        {{#each this.activeTeam.players as |player index|}}
          <button
            type="button"
            {{on "click" (fn this.goToPlayer player)}}
            class="w-full flex items-center gap-3 bg-gray-50 dark:bg-slate-700/60 hover:bg-gray-100 dark:hover:bg-slate-700 rounded-xl p-3 transition-all border border-gray-200 dark:border-slate-600/30 shadow-sm cursor-pointer text-left"
          >
            <span class="text-gray-400 dark:text-gray-500 text-xs w-5 font-semibold">{{add index 1}}</span>
            <div class="w-11 h-11 rounded-xl overflow-hidden bg-gray-200 dark:bg-slate-600 flex-shrink-0 shadow-inner">
              <img
                src={{player.avatar}}
                alt={{player.name}}
                class="w-full h-full object-cover"
                onerror="this.onerror=null;this.src='/images/default-player.png'"
              />
            </div>
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2">
                <h4 class="text-gray-900 dark:text-white font-semibold text-sm truncate">{{player.name}}</h4>
                {{#if player.is12thMan}}
                  <span class="text-[9px] bg-amber-500/20 text-amber-600 dark:text-amber-400 px-1.5 py-0.5 rounded font-medium">12th</span>
                {{/if}}
                {{#if player.isLeftHanded}}
                  <span class="text-[9px] bg-cyan-500/20 text-cyan-600 dark:text-cyan-400 px-1.5 py-0.5 rounded font-medium">LH</span>
                {{/if}}
              </div>
              <p class="text-gray-500 dark:text-gray-400 text-[11px]">
                {{#if player.role}}{{player.role}}{{/if}}
                {{#if player.style}}
                  <span class="text-gray-400 dark:text-gray-600">•</span> {{player.style}}
                {{/if}}
              </p>
            </div>
            {{#if (eq this.navigatingPlayerId player.id)}}
              <div class="w-4 h-4 border-2 border-indigo-500 border-t-transparent rounded-full animate-spin flex-shrink-0"></div>
            {{/if}}
          </button>
        {{/each}}
      </div>

    </div>
  </template>
}
