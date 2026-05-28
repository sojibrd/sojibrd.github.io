import Component from '@glimmer/component';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { eq } from 'ember-truth-helpers';
import lucideIcon from 'spordium/helpers/lucide-icon';

const SPORTS = ['All', 'Cricket', 'Football'];

const MATCH_TYPES = [
  { value: 't10', label: 'T10' },
  { value: 't20', label: 'T20' },
];

const TOURNAMENT_MATCH_TYPES = [
  { value: 'knockout', label: 'Knockout' },
  { value: 'homeAndAway', label: 'Home And Away' },
  { value: 'league', label: 'League' },
];

const TOURNAMENT_TYPES = [
  { value: 'amature', label: 'Amature' },
  { value: 'semiProfessional', label: 'Semi Professional' },
  { value: 'professional', label: 'Professional' },
];

const BALL_TYPES = [
  { value: 'tennisBall', label: 'Tennis Ball' },
  { value: 'tapeTennisBall', label: 'Tape Tennis Ball' },
  { value: 'duseBall', label: 'Duse Ball' },
];

// ══════════════════════════════════════════════════════════════════════════════
// FilterPanel — left sidebar filter UI
//
// @arg {Object}   filters   — current filter values
// @arg {Function} onChange  — called with (key, value)
// @arg {Function} onReset   — clears all filters
// @arg {boolean}  isOpen    — mobile visibility
// @arg {Function} onClose   — close sidebar on mobile
// ══════════════════════════════════════════════════════════════════════════════
export default class TournamentFilterPanel extends Component {
  get filters() {
    return this.args.filters ?? {};
  }

  <template>
    {{! Mobile overlay }}
    {{#if @isOpen}}
      <div
        class="fixed inset-0 bg-black/40 z-30 lg:hidden"
        {{on "click" @onClose}}
      ></div>
    {{/if}}

    <aside
      class="fixed top-0 left-0 h-full w-72 z-40 bg-white dark:bg-gray-900 border-r border-gray-200 dark:border-gray-700 overflow-y-auto transform transition-transform duration-300
        {{if @isOpen '-translate-x-0' '-translate-x-full'}}
        lg:static lg:translate-x-0 lg:h-auto lg:z-auto lg:rounded-2xl lg:border lg:border-gray-200 lg:dark:border-gray-700 lg:overflow-visible"
    >
      {{! Header }}
      <div
        class="flex items-center justify-between p-5 border-b border-gray-100 dark:border-gray-700"
      >
        <span
          class="text-sm font-bold text-gray-900 dark:text-white flex items-center gap-2"
        >
          {{lucideIcon "sliders-horizontal" class="w-4 h-4"}}
          Filters
        </span>
        <div class="flex items-center gap-2">
          <button
            type="button"
            {{on "click" @onReset}}
            class="text-xs text-blue-600 dark:text-blue-400 hover:underline font-medium"
          >
            Reset
          </button>
          <button
            type="button"
            {{on "click" @onClose}}
            class="lg:hidden p-1 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-800"
          >
            {{lucideIcon "x" class="w-4 h-4 text-gray-500"}}
          </button>
        </div>
      </div>

      <div class="p-5 space-y-6">

        {{! Sport }}
        <div>
          <p
            class="text-[10px] font-bold uppercase tracking-widest text-gray-400 mb-2"
          >
            Sport
          </p>
          <div class="flex flex-wrap gap-2">
            {{#each SPORTS as |sport|}}
              <button
                type="button"
                {{on
                  "click"
                  (fn @onChange "sport" (if (eq sport "All") "" sport))
                }}
                class="px-3 py-1.5 text-xs font-medium rounded-full border transition-colors
                  {{if
                    (eq (if (eq sport 'All') '' sport) this.filters.sport)
                    'bg-blue-600 text-white border-blue-600'
                    'bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300
                          border-gray-200 dark:border-gray-600 hover:border-blue-400'
                  }}"
              >
                {{sport}}
              </button>
            {{/each}}
          </div>
        </div>

        {{! Match type }}
        <div>
          <p
            class="text-[10px] font-bold uppercase tracking-widest text-gray-400 mb-2"
          >
            Match Type
          </p>
          <select
            class="w-full px-3 py-2 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500"
            {{on "change" (fn @onChange "m_format")}}
          >
            <option value="">All Match Types</option>
            {{#each MATCH_TYPES as |fmt|}}
              {{#if fmt}}
                <option
                  value={{fmt.label}}
                  selected={{eq fmt.label this.filters.m_format}}
                >{{fmt.label}}</option>
              {{/if}}
            {{/each}}
          </select>
        </div>

        {{! Tournament match type }}
        <div>
          <p
            class="text-[10px] font-bold uppercase tracking-widest text-gray-400 mb-2"
          >
            Tournament Match Type
          </p>
          <select
            class="w-full px-3 py-2 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500"
            {{on "change" (fn @onChange "t_m_format")}}
          >
            <option value="">Tournament Match Types</option>
            {{#each TOURNAMENT_MATCH_TYPES as |fmt|}}
              {{#if fmt}}
                <option
                  value={{fmt.value}}
                  selected={{eq fmt.value this.filters.t_m_format}}
                >
                  {{fmt.label}}
                </option>
              {{/if}}
            {{/each}}
          </select>
        </div>

        {{! Tournament match type }}
        <div>
          <p
            class="text-[10px] font-bold uppercase tracking-widest text-gray-400 mb-2"
          >
            Tournament Type
          </p>
          <select
            class="w-full px-3 py-2 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500"
            {{on "change" (fn @onChange "t_type")}}
          >
            <option value="">Tournament Types</option>
            {{#each TOURNAMENT_TYPES as |fmt|}}
              {{#if fmt}}
                <option
                  value={{fmt.value}}
                  selected={{eq fmt.value this.filters.t_type}}
                >
                  {{fmt.label}}
                </option>
              {{/if}}
            {{/each}}
          </select>
        </div>

        {{! Tournament match type }}
        <div>
          <p
            class="text-[10px] font-bold uppercase tracking-widest text-gray-400 mb-2"
          >
            Ball Type
          </p>
          <select
            class="w-full px-3 py-2 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500"
            {{on "change" (fn @onChange "ball_type")}}
          >
            <option value="">Ball Types</option>
            {{#each BALL_TYPES as |fmt|}}
              {{#if fmt}}
                <option
                  value={{fmt.value}}
                  selected={{eq fmt.value this.filters.ball_type}}
                >
                  {{fmt.label}}
                </option>
              {{/if}}
            {{/each}}
          </select>
        </div>

        {{! Start date (from) }}
        <div>
          <p
            class="text-[10px] font-bold uppercase tracking-widest text-gray-400 mb-2"
          >Start Date (from)</p>
          <input
            type="date"
            value={{this.filters.dateFrom}}
            {{on "change" (fn @onChange "dateFrom")}}
            class="w-full px-3 py-2 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

      </div>
    </aside>
  </template>
}
