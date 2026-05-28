import Component from '@glimmer/component';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { eq } from 'ember-truth-helpers';

const SPORTS = [
  { key: 'cricket', label: 'Cricket', emoji: '🏏' },
  { key: 'football', label: 'Football', emoji: '⚽' },
  { key: 'basketball', label: 'Basketball', emoji: '🏀' },
  { key: 'rugby', label: 'Rugby', emoji: '🏉' },
];

// @arg {String}   selected   — sport key string e.g. "football"
// @arg {Function} onChange   — (sportKey: string) => void
export default class SportSelector extends Component {
  get sports() {
    return SPORTS;
  }

  <template>
    <div>
      <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
        Sport
        <span class="text-red-500">*</span>
      </label>
      <div class="flex flex-wrap gap-2">
        {{#each this.sports as |sport|}}
          <button
            type="button"
            {{on "click" (fn @onChange sport.key)}}
            class="px-4 py-2 text-sm font-medium rounded-xl border-2 transition-all
              {{if (eq @selected sport.key) 'border-blue-500 bg-blue-50 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300' 'border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300 hover:border-blue-300'}}"
          >
            {{sport.emoji}}
            {{sport.label}}
          </button>
        {{/each}}
      </div>
    </div>
  </template>
}
