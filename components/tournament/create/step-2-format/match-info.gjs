import Component from '@glimmer/component';
import { action } from '@ember/object';
import { fn, array } from '@ember/helper';
import { on } from '@ember/modifier';
import { eq } from 'ember-truth-helpers';

const MATCH_FORMATS = [
  { value: 't10', label: 'T10' },
  { value: 't20', label: 'T20' },
  { value: 'oneDay', label: 'One Day' },
  { value: 'test', label: 'Test' },
  { value: 'fiveOvers', label: 'Five Overs' },
  { value: 'sixASideOrEightASide', label: 'Six-a-Side or Eight-a-Side' },
  { value: 'boxCricket', label: 'Box Cricket' },
  { value: 'superSixes', label: 'Super Sixes' },
  { value: 'other', label: 'Other' },
];

const TOURNAMENT_FORMATS = [
  { value: 'knockout', label: 'Knockout' },
  { value: 'homeAndAway', label: 'Home and Away' },
  { value: 'league', label: 'League' },
];

const BALL_TYPES = [
  { value: 'tennisBall', label: '🎾 Tennis Ball' },
  { value: 'tapeTennisBall', label: '🎾 Tape Tennis Ball' },
  { value: 'duseBall', label: '⚾ Duse Ball' },
  { value: 'cricketBall', label: '🏏 Cricket Ball' },
];

const PITCH_TYPES = [
  { value: 'naturalGrass', label: '🌿 Natural Grass' },
  { value: 'cement', label: '🏗️ Cement' },
  { value: 'mat', label: '🪣 Matting' },
  { value: 'syntheticTurfOrGrass', label: '🟩 Synthetic Turf or Grass' },
  { value: 'hardClay', label: '🟤 Hard Clay' },
  { value: 'boxCricketSurface', label: '🏏 Box Cricket Surface' },
];

// helper
function oversRange() {
  return Array.from({ length: 46 }, (_, i) => i + 5); // [5, 6, 7, ..., 50]
}

export default class MatchInfo extends Component {
  @action
  onOversChange(e) {
    this.args.onUpdate('overs_per_match', Number(e.target.value));
  }

  <template>
    <div class="space-y-5">

      {{! Match Format }}
      <div>
        <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
          Match Format
        </label>
        <div class="flex flex-wrap gap-2">
          {{#each MATCH_FORMATS as |opt|}}
            <button
              type="button"
              {{on "click" (fn @onUpdate "tournament_match_format" opt.value)}}
              class="px-4 py-2 text-sm font-medium rounded-xl border-2 transition-all
                {{if
                  (eq @data.tournament_match_format opt.value)
                  'border-blue-500 bg-blue-50 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300'
                  'border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300 hover:border-blue-300'
                }}"
            >
              {{opt.label}}
            </button>
          {{/each}}
        </div>
      </div>

      {{! Tournament Format }}
      <div>
        <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
          Tournament Format
          <span class="text-red-500">*</span>
        </label>
        <div class="flex flex-wrap gap-2">
          {{#each TOURNAMENT_FORMATS as |opt|}}
            <button
              type="button"
              {{on "click" (fn @onUpdate "tournament_format" opt.value)}}
              class="px-4 py-2 text-sm font-medium rounded-xl border-2 transition-all
                {{if
                  (eq @data.tournament_format opt.value)
                  'border-blue-500 bg-blue-50 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300'
                  'border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300 hover:border-blue-300'
                }}"
            >
              {{opt.label}}
            </button>
          {{/each}}
        </div>
      </div>

      {{! Ball Type }}
      <div>
        <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
          Ball Type
        </label>
        <div class="flex flex-wrap gap-2">
          {{#each BALL_TYPES as |opt|}}
            <button
              type="button"
              {{on "click" (fn @onUpdate "ball_type" opt.value)}}
              class="px-4 py-2 text-sm font-medium rounded-xl border-2 transition-all
                {{if (eq @data.ball_type opt.value) 'border-blue-500 bg-blue-50 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300' 'border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300 hover:border-blue-300'}}"
            >
              {{opt.label}}
            </button>
          {{/each}}
        </div>
      </div>

      {{! Pitch Type }}
      <div>
        <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
          Pitch Type
        </label>
        <div class="flex flex-wrap gap-2">
          {{#each PITCH_TYPES as |opt|}}
            <button
              type="button"
              {{on "click" (fn @onUpdate "pitch_type" opt.value)}}
              class="px-4 py-2 text-sm font-medium rounded-xl border-2 transition-all
                {{if (eq @data.pitch_type opt.value) 'border-blue-500 bg-blue-50 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300' 'border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300 hover:border-blue-300'}}"
            >
              {{opt.label}}
            </button>
          {{/each}}
        </div>
      </div>

      {{! Overs per Match }}
      <div>
        <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
          Overs per Match
        </label>
        <select class="w-32 px-3 py-2 rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 text-sm text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500" {{on "change" this.onOversChange}}>
          <option value="">Select</option>
          {{#each (oversRange) as |n|}}
            <option value={{n}} selected={{eq @data.overs_per_match n}}>{{n}}</option>
          {{/each}}
        </select>
      </div>
    </div>
  </template>
}
