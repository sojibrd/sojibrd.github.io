import Component from '@glimmer/component';
import { action } from '@ember/object';
import { fn } from '@ember/helper';
import { on } from '@ember/modifier';
import { eq } from 'ember-truth-helpers';

function getGroupOptions(teamCount) {
  if (!teamCount || teamCount < 2) return [];
  const options = [];
  for (let i = 2; i <= teamCount / 2; i += 2) {
    if (teamCount % i === 0) options.push(i);
  }
  return options;
}

function generateGroupName(index) {
  return `Group ${index + 1}`;
}

export default class GroupsConfig extends Component {
  @action
  onGroupCountChange(e) {
    const newCount = Number(e.target.value);

    const existingGroups = this.args.data.tournament_groups ?? [];
    const currentCount = existingGroups.length;

    const toDelete = existingGroups
      // .slice(newCount)
      .map((g) => g.tournament_group_id)
      .filter(Boolean);

    const mergedDeletes = [...new Set([...(this.args.data.delete_groups ?? []), ...toDelete])];

    let newGroups = Array.from({ length: newCount }, (_, i) => ({ tournament_group_name: generateGroupName(i) }));

    this.args.onUpdate('tournament_number_of_groups', newCount);
    this.args.onUpdate('tournament_groups', newGroups);
    this.args.onUpdate('delete_groups', mergedDeletes);
    this.args.onUpdate('number_of_teams_per_groups', null); // reset
  }

  @action
  onTeamsPerGroupSelect(e) {
    const value = Number(e.target.value);
    this.args.onUpdate('number_of_teams_per_groups', value);
  }

  @action
  onGroupNameChange(index, e) {
    const groups = [...(this.args.data.tournament_groups ?? [])];
    groups[index] = { ...groups[index], tournament_group_name: e.target.value };
    this.args.onUpdate('tournament_groups', groups);
  }

  get groupOptions() {
    return getGroupOptions(this.args.paidTeams ?? 0);
  }

  get teamsPerGroupOptions() {
    const paidTeams = this.args.paidTeams ?? 0;
    const groupCount = this.args.data.tournament_number_of_groups;
    if (!groupCount || !paidTeams) return [];
    const perGroup = paidTeams / groupCount;
    return Number.isInteger(perGroup) ? [perGroup] : [];
  }

  get currentGroupCount() {
    return this.args.data.tournament_number_of_groups ?? '';
  }

  get groups() {
    return this.args.data.tournament_groups ?? [];
  }

  <template>
    <div class="space-y-5">

      {{! Number of Groups }}
      <div>
        <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
          Number of Groups
          <span class="text-red-500">*</span>
        </label>
        <select class="w-full px-3 py-2 rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 text-sm text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500" {{on "change" this.onGroupCountChange}}>
          <option value="">Select</option>
          {{#each this.groupOptions as |opt|}}
            <option value={{opt}} selected={{eq this.currentGroupCount opt}}>{{opt}}</option>
          {{/each}}
        </select>
      </div>

      {{! Number of Teams per Group }}
      <div>
        <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
          Number of Teams per Group
          <span class="text-red-500">*</span>
        </label>
        <select class="w-full px-3 py-2 rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 text-sm text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500" {{on "change" this.onTeamsPerGroupSelect}}>
          <option value="">Select</option>
          {{#each this.teamsPerGroupOptions as |opt|}}
            <option value={{opt}} selected={{eq @data.number_of_teams_per_groups opt}}>{{opt}}</option>
          {{/each}}
        </select>
      </div>

      {{! Dynamic Group Name Inputs }}
      {{#if this.groups.length}}
        <div>
          <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-2">
            Group Names
          </label>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            {{#each this.groups key="@index" as |group i|}}
              <input
                type="text"
                class="w-full px-3 py-2 rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 text-sm text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
                value={{group.tournament_group_name}}
                placeholder="Group name"
                {{on "input" (fn this.onGroupNameChange i)}}
              />
            {{/each}}
          </div>
        </div>
      {{/if}}

    </div>
  </template>
}
