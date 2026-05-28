// spordium/components/tournament/detail/teams-tab.gjs

import Component from '@glimmer/component';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { eq } from 'ember-truth-helpers';
import lucideIcon from 'spordium/helpers/lucide-icon';

// ── Helpers ───────────────────────────────────────────────────────────────

/**
 * teams_data এ duplicate entries আছে।
 * team_id + tournament_group_id দিয়ে deduplicate করো।
 */
const deduplicateTeams = (teams = []) => {
  const seen = new Set();
  return teams.filter((t) => {
    const key = `${t.team_id}__${t.tournament_group_id}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
};

/**
 * groups_data আর teams_data মিলিয়ে grouped structure বানাও।
 * Return: [{ groupId, groupName, teams: [...] }]
 */
const buildGroupedTeams = (groupsData = [], teamsData = []) => {
  const unique = deduplicateTeams(teamsData);

  return groupsData.map((group) => {
    const groupTeams = unique
      .filter((t) => t.tournament_group_id === group.tournament_group_id)
      .sort((a, b) => Number(a.tournament_group_slot) - Number(b.tournament_group_slot));

    return {
      groupId: group.tournament_group_id,
      groupName: group.tournament_group_name,
      teams: groupTeams,
    };
  });
};

// ── Slot badge color ───────────────────────────────────────────────────────
const slotColors = ['bg-blue-100 text-blue-700', 'bg-emerald-100 text-emerald-700', 'bg-purple-100 text-purple-700', 'bg-orange-100 text-orange-700'];

const slotColor = (slot) => slotColors[(Number(slot) - 1) % slotColors.length] ?? slotColors[0];

// ── Short ID display ───────────────────────────────────────────────────────
const shortId = (id = '') => id.slice(-6).toUpperCase();

// ── Component ─────────────────────────────────────────────────────────────

/**
 * TeamsTab
 *
 * @arg {Array} teamsData   — raw teams_data array from API
 * @arg {Array} groupsData  — raw groups_data array from API
 */
export default class TeamsTab extends Component {
  get groups() {
    return buildGroupedTeams(this.args.groupsData ?? [], this.args.teamsData ?? []);
  }

  get totalTeams() {
    return this.groups.reduce((sum, g) => sum + g.teams.length, 0);
  }

  <template>
    <div class="space-y-6">

      {{! ── Header ───────────────────────────────────────────────────────── }}
      <div class="flex items-center justify-between">
        <div>
          <h2 class="text-lg font-bold text-gray-900 dark:text-white">Registered Teams</h2>
          <p class="text-sm text-gray-500 dark:text-gray-400 mt-0.5">
            {{this.totalTeams}}
            teams across
            {{this.groups.length}}
            groups
          </p>
        </div>
        <span
          class="flex items-center gap-1.5 text-xs font-medium px-3 py-1.5 rounded-full bg-blue-50 text-blue-600 dark:bg-blue-900/30 dark:text-blue-400"
        >
          {{lucideIcon "users" class="w-3.5 h-3.5"}}
          {{this.totalTeams}}
          Teams
        </span>
      </div>

      {{! ── Groups ────────────────────────────────────────────────────────── }}
      {{#each this.groups as |group|}}
        <div class="bg-white dark:bg-gray-900 rounded-2xl border border-gray-200 dark:border-gray-700 overflow-hidden">

          {{! Group Header }}
          <div class="flex items-center justify-between px-5 py-3.5 bg-gray-50 dark:bg-gray-800 border-b border-gray-200 dark:border-gray-700">
            <div class="flex items-center gap-2">
              {{lucideIcon "layers" class="w-4 h-4 text-blue-500"}}
              <span class="text-sm font-semibold text-gray-800 dark:text-gray-100">{{group.groupName}}</span>
            </div>
            <span class="text-xs text-gray-500 dark:text-gray-400">{{group.teams.length}} teams</span>
          </div>

          {{! Team rows }}
          <div class="divide-y divide-gray-100 dark:divide-gray-800">
            {{#each group.teams as |team|}}
              <div class="flex items-center gap-4 px-5 py-4 hover:bg-gray-50 dark:hover:bg-gray-800/50 transition-colors">

                {{! Slot badge }}
                <span
                  class="w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold shrink-0 {{slotColor team.tournament_group_slot}}"
                >
                  {{team.tournament_group_slot}}
                </span>

                {{! Team avatar placeholder }}
                <div class="w-9 h-9 rounded-xl bg-gradient-to-br from-blue-400 to-blue-600 flex items-center justify-center shrink-0">
                  {{lucideIcon "shield" class="w-4 h-4 text-white"}}
                </div>

                {{! Team info }}
                <div class="flex-1 min-w-0">
                  <p class="text-sm font-semibold text-gray-900 dark:text-white truncate">
                    Team #{{shortId team.team_id}}
                  </p>
                  <p class="text-xs text-gray-400 truncate mt-0.5">
                    ID:
                    {{team.team_id}}
                  </p>
                </div>

                {{! Registration status }}
                {{#if team.registration_completed_by_user}}
                  <span class="flex items-center gap-1 text-xs font-medium text-emerald-600 dark:text-emerald-400 shrink-0">
                    {{lucideIcon "check-circle" class="w-3.5 h-3.5"}}
                    Registered
                  </span>
                {{else}}
                  <span class="flex items-center gap-1 text-xs font-medium text-amber-500 shrink-0">
                    {{lucideIcon "clock" class="w-3.5 h-3.5"}}
                    Pending
                  </span>
                {{/if}}

              </div>
            {{/each}}
          </div>

        </div>
      {{/each}}

      {{! Empty state }}
      {{#if (eq this.totalTeams 0)}}
        <div class="py-16 flex flex-col items-center gap-3 text-center">
          {{lucideIcon "users" class="w-10 h-10 text-gray-300"}}
          <p class="text-sm text-gray-400">No teams registered yet.</p>
        </div>
      {{/if}}

    </div>
  </template>
}
