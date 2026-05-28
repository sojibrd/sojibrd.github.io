import Component from '@glimmer/component';
import { action } from '@ember/object';
import { fn } from '@ember/helper';
import { on } from '@ember/modifier';
import { eq } from 'ember-truth-helpers';
import { array, hash } from '@ember/helper';

const DEFAULT_TIEBREAKER_RULES = [
  { name: 'Net Run Rate', selected: false },
  { name: 'Head to Head', selected: false },
  { name: 'Run Difference', selected: false },
  { name: 'Custom', selected: false },
];

// helper
function playingSide() {
  return Array.from({ length: 8 }, (_, i) => i + 4);
}

function maximumSquadSize() {
  return Array.from({ length: 17 }, (_, i) => i + 4);
}

export default class PlayerRules extends Component {
  @action
  onAgeLimitChange(key, e) {
    const current = this.args.data.player_age_limit ?? { min: null, max: null };
    this.args.onUpdate('player_age_limit', { ...current, [key]: Number(e.target.value) });
  }

  @action
  onTieBreakerToggle(name) {
    const rules = (this.args.data.tie_breaker_rules ?? DEFAULT_TIEBREAKER_RULES).map((r) => ({
      ...r,
      selected: r.name === name ? !r.selected : false,
    }));
    this.args.onUpdate('tie_breaker_rules', rules);
  }

  get ageLimit() {
    return this.args.data.player_age_limit ?? { min: '', max: '' };
  }

  get tieBreakerRules() {
    const rules = this.args.data.tie_breaker_rules;
    return !rules || rules.length === 0 ? DEFAULT_TIEBREAKER_RULES : rules;
  }

  @action playingSideChange(e) {
    this.args.onUpdate('number_of_players_playing', Number(e.target.value));
  }

  @action maximumSquadSizeChange(e) {
    this.args.onUpdate('maximum_sqad_size_per_team', Number(e.target.value));
  }

  <template>
    <div class="space-y-5">

      {{! Players per side + Squad size }}
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div>
          <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
            Number of Players Playing a Side
          </label>
          <select class="w-full px-3 py-2 rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 text-sm text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500" {{on "change" this.playingSideChange}}>
            <option value="">Select</option>
            {{#each (playingSide) as |n|}}
              <option value={{n}} selected={{eq @data.number_of_players_playing n}}>{{n}}</option>
            {{/each}}
          </select>
        </div>

        <div>
          <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
            Max Squad Size Per Team
          </label>

          <select class="w-full px-3 py-2 rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 text-sm text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500" {{on "change" this.maximumSquadSizeChange}}>
            <option value="">Select</option>
            {{#each (maximumSquadSize) as |n|}}
              <option value={{n}} selected={{eq @data.maximum_sqad_size_per_team n}}>{{n}}</option>
            {{/each}}
          </select>
        </div>
      </div>

      {{! Player Age Limit }}
      <div>
        <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
          Player Age Limit
        </label>
        <div class="flex items-center gap-3">
          <input
            type="number"
            min="0"
            placeholder="Min"
            class="w-24 px-3 py-2 rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 text-sm text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
            value={{this.ageLimit.min}}
            {{on "input" (fn this.onAgeLimitChange "min")}}
          />
          <span class="text-sm text-gray-500">Years To</span>
          <input
            type="number"
            min="0"
            placeholder="Max"
            class="w-24 px-3 py-2 rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 text-sm text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
            value={{this.ageLimit.max}}
            {{on "input" (fn this.onAgeLimitChange "max")}}
          />
          <span class="text-sm text-gray-500">Years</span>
        </div>
      </div>

      {{! Scoring Rules }}
      <div>
        <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-2">
          Scoring Rules
        </label>
        <div class="flex items-center gap-4 flex-wrap">
          {{#each (array (hash label="Win" points=3) (hash label="Tie" points=2) (hash label="Loss" points=1)) as |rule|}}
            <div class="flex items-center gap-2">
              <span class="text-sm font-medium text-gray-600 dark:text-gray-400 w-8">
                {{rule.label}}
              </span>
              <div class="w-16 px-2 py-1.5 rounded-lg border border-gray-200 dark:border-gray-700 bg-gray-100 dark:bg-gray-700 text-sm text-center text-gray-900 dark:text-white select-none cursor-default">
                {{rule.points}}
              </div>
            </div>
          {{/each}}
        </div>
      </div>

      {{! Tie Breaker Rules — pill toggle }}
      <div>
        <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
          Tie/Breaker Rules
        </label>
        <div class="flex flex-wrap gap-2">
          {{#each this.tieBreakerRules as |rule|}}
            <button
              type="button"
              {{on "click" (fn this.onTieBreakerToggle rule.name)}}
              class="px-4 py-2 text-sm font-medium rounded-xl border-2 transition-all
                {{if rule.selected 'border-blue-500 bg-blue-50 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300' 'border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300 hover:border-blue-300'}}"
            >
              {{rule.name}}
            </button>
          {{/each}}
        </div>
      </div>

    </div>
  </template>
}
