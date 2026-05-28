import Component from '@glimmer/component';
import { eq } from 'ember-truth-helpers';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import config from 'spordium/config/environment';

function isWK(wicketKeeperIds, playerId) {
  return (wicketKeeperIds ?? []).includes(playerId);
}

function formatOrder(order) {
  if (!order) return '-';
  const [val, total] = order.split('/');
  return `${val === 'null' ? '-' : val}/${total ?? '?'}`;
}

export default class AssignPlayerComponent extends Component {
  config = config;

  <template>
    <div class="space-y-6 bg-white dark:bg-gray-900 rounded-2xl shadow-sm border border-gray-200 dark:border-gray-700 mt-4">
      {{! ── Section Header ── }}
      <div class="px-6 pt-6 border-b border-gray-100 dark:border-gray-800 pb-4">
        <div class="flex items-center gap-3">
          <div class="w-8 h-8 rounded-lg bg-indigo-50 dark:bg-indigo-900/40 flex items-center justify-center">
            <svg class="w-4 h-4 text-indigo-600 dark:text-indigo-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"
              />
            </svg>
          </div>
          <div>
            <h3 class="text-base font-semibold text-gray-900 dark:text-gray-100">Manage Players</h3>
            <p class="text-xs text-gray-400 dark:text-gray-500">Search and assign players to your team</p>
          </div>
        </div>
      </div>

      <form class="px-6 pb-6 space-y-6" aria-label="member" {{on "submit" @submitPlayerForm}}>
        {{! ── Add Player ── }}
        <div>
          <p class="text-xs font-semibold uppercase tracking-widest text-gray-400 dark:text-gray-500 mb-3">Add Player</p>
          <div class="relative">
            <label class="absolute -top-2.5 left-3 text-xs font-medium bg-white dark:bg-gray-900 px-1 text-indigo-600 dark:text-indigo-400 z-10">Search Players</label>
            <input
              type="search"
              id="player-search"
              class="block w-full rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-900 text-gray-900 dark:text-gray-100 px-3 pt-4 pb-2 text-sm focus:border-2 focus:border-indigo-500 outline-none transition-all hover:border-gray-400"
              placeholder=" "
              value={{@searchQuery}}
              {{on "input" @handlePlayerSearch}}
              autocomplete="off"
            />

            {{! ✅ @searchLoading = playerSearchTask.isRunning from parent }}
            {{#if @searchLoading}}
              <span class="absolute right-[30px] top-1/2 -translate-y-1/2">
                <svg class="w-4 h-4 text-indigo-500 animate-spin" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"></path>
                </svg>
              </span>
            {{/if}}

            {{#if @searchDropdownList.length}}
              <ul
                class="absolute z-50 top-full mt-1.5 w-full bg-white dark:bg-gray-800 rounded-xl shadow-2xl overflow-hidden divide-y divide-gray-100 dark:divide-gray-700 border border-gray-200 dark:border-gray-700"
              >
                {{#each @searchDropdownList as |player|}}
                  <li>
                    <button
                      type="button"
                      class="w-full text-left px-4 py-3 text-sm text-gray-700 dark:text-gray-200 hover:bg-indigo-50 dark:hover:bg-indigo-900/30 flex items-center gap-3 transition-colors"
                      {{on "click" (fn @addPlayerToTeam player)}}
                    >
                      <img
                        class="h-8 w-8 rounded-full object-cover ring-2 ring-indigo-100 dark:ring-indigo-900 shrink-0"
                        src="{{this.config.APP.S3_BUCKET_URL}}/{{player.player_primary_pic}}"
                        alt="{{player.player_fullname.first_name}}"
                      />
                      <div class="min-w-0">
                        <p class="font-medium truncate text-gray-900 dark:text-gray-100">
                          {{player.player_fullname.first_name}}
                          {{player.player_fullname.last_name}}
                        </p>
                        <p class="text-xs text-gray-400 dark:text-gray-500 truncate">@{{player.user_username}}</p>
                      </div>
                    </button>
                  </li>
                {{/each}}
              </ul>
            {{/if}}
          </div>
        </div>

        {{! ── Player List ── }}
        <div>
          <p class="text-xs font-semibold uppercase tracking-widest text-gray-400 dark:text-gray-500 mb-3">Player List</p>
          <ul role="list" class="divide-y divide-gray-100 dark:divide-gray-800 rounded-xl border border-gray-200 dark:border-gray-700 overflow-hidden">
            {{#each @members as |member|}}
              <li class="flex items-center justify-between px-4 py-3 bg-white dark:bg-gray-900 hover:bg-gray-50 dark:hover:bg-gray-800/50 transition-colors">
                <div class="flex items-center gap-3 min-w-0">
                  <img
                    class="h-10 w-10 rounded-full object-cover ring-2 ring-indigo-100 dark:ring-indigo-900 shrink-0"
                    src="{{this.config.APP.S3_BUCKET_URL}}/{{member.player_primary_pic}}"
                    alt="{{member.PlayerName.first_name}}"
                  />
                  <div class="min-w-0">
                    <div class="flex items-center gap-2 flex-wrap">
                      <p class="text-sm font-medium text-gray-900 dark:text-gray-100">
                        {{member.PlayerName.first_name}}
                        {{member.PlayerName.last_name}}
                      </p>
                      {{#if (eq member.player_id @captainId)}}
                        <span
                          class="inline-flex items-center rounded-full bg-lime-100 dark:bg-lime-900/30 px-2 py-0.5 text-xs font-medium text-lime-800 dark:text-lime-400 border border-lime-300"
                        >Captain</span>
                      {{/if}}
                      {{#if (eq member.player_id @viceCaptainId)}}
                        <span
                          class="inline-flex items-center rounded-full bg-gray-100 dark:bg-gray-700 px-2 py-0.5 text-xs font-medium text-gray-700 dark:text-gray-300 border border-gray-300"
                        >Vice-Captain</span>
                      {{/if}}
                      {{#if (isWK @wicketKeeperIds member.player_id)}}
                        <span
                          class="inline-flex items-center rounded-full bg-sky-100 dark:bg-sky-900/30 px-2 py-0.5 text-xs font-medium text-sky-800 dark:text-sky-400 border border-sky-300"
                        >
                          🧤 WK
                        </span>
                      {{/if}}
                      {{#if member.pending}}
                        <span class="inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full bg-yellow-100 text-yellow-800 border border-yellow-300">
                          Pending
                        </span>
                      {{/if}}

                    </div>
                    <p class="text-xs text-gray-400 dark:text-gray-500">
                      Order:
                      {{formatOrder member.playing_order}}
                    </p>
                  </div>
                </div>

                <div class="flex items-center gap-1.5 shrink-0 ml-3">
                  <button
                    type="button"
                    class="px-2.5 py-1 text-xs font-medium rounded-md text-gray-500 dark:text-gray-400 hover:text-indigo-600 dark:hover:text-indigo-400 hover:bg-indigo-50 dark:hover:bg-indigo-900/30 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
                    disabled={{eq member.player_id @captainId}}
                    {{on "click" (fn @setPlayerRole member "captain")}}
                  >Captain</button>
                  <button
                    type="button"
                    class="px-2.5 py-1 text-xs font-medium rounded-md text-gray-500 dark:text-gray-400 hover:text-indigo-600 dark:hover:text-indigo-400 hover:bg-indigo-50 dark:hover:bg-indigo-900/30 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
                    disabled={{eq member.player_id @viceCaptainId}}
                    {{on "click" (fn @setPlayerRole member "vice_captain")}}
                  >V-Captain</button>
                  <button
                    type="button"
                    class="px-2.5 py-1 text-xs font-medium rounded-md
                      {{if
                        (isWK @wicketKeeperIds member.player_id)
                        'text-sky-600 dark:text-sky-400 bg-sky-50 dark:bg-sky-900/20'
                        'text-gray-500 dark:text-gray-400 hover:text-sky-600 dark:hover:text-sky-400 hover:bg-sky-50'
                      }}
                      transition-colors"
                    {{on "click" (fn @setPlayerRole member "wicket_keeper")}}
                  >
                    {{if (isWK @wicketKeeperIds member.player_id) "✓ WK" "WK"}}
                  </button>
                  <button
                    type="button"
                    class="px-2.5 py-1 text-xs font-medium rounded-md text-red-500 dark:text-red-400 hover:text-red-700 dark:hover:text-red-300 hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors"
                    {{on "click" (fn @removePlayerFromTeam member)}}
                  >Remove</button>
                </div>
              </li>
            {{else}}
              <li class="py-10 text-center text-sm text-gray-400 dark:text-gray-500">
                <svg class="w-8 h-8 mx-auto mb-2 text-gray-300 dark:text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="1.5"
                    d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z"
                  />
                </svg>
                No players added yet
              </li>
            {{/each}}
          </ul>
        </div>

        {{! ── Actions ── }}
        <div class="flex items-center justify-end gap-3 pt-2 border-t border-gray-100 dark:border-gray-800">
          <button
            type="button"
            class="px-4 py-2 text-sm font-medium rounded-lg text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
            {{on "click" @onCloseMember}}
          >Cancel</button>
          <button
            type="submit"
            class="px-5 py-2 text-sm font-semibold rounded-lg bg-indigo-600 hover:bg-indigo-700 active:bg-indigo-800 text-white shadow-sm transition-colors"
          >Update Players</button>
        </div>
      </form>
    </div>
  </template>
}
