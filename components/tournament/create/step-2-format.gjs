import Component from '@glimmer/component';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import { eq } from 'ember-truth-helpers';

// ─────────────────────────────────────────────────────────────────────────────
const MATCH_FORMATS     = ['T10', 'T20', 'One Day', 'Test', 'Five Over', 'Six Aside', 'Eight Aside', 'Box Cricket'];
const TOURNAMENT_FORMATS = ['Knockout', 'League', 'Home And Away', 'Round Robin', 'Group + Knockout'];
const TOURNAMENT_TYPES  = ['Corporate', 'School', 'College', 'University', 'Community', 'Professional', 'Amateur'];
const BALL_TYPES        = ['Red Cricket Ball', 'White Cricket Ball', 'Tape Tennis Ball', 'Tennis Ball', 'Rubber Ball', 'Leather Ball'];
const PITCH_TYPES       = ['Cement', 'Turf', 'Artificial Turf', 'Matting', 'Grass', 'Sand', 'Indoor', 'Outdoor'];

const TIEBREAKER_OPTIONS = [
  { key: 'nrr',         label: 'Net Run Rate (NRR)' },
  { key: 'headToHead',  label: 'Head to Head' },
  { key: 'mostWins',    label: 'Most Wins' },
  { key: 'mostSixes',   label: 'Most Sixes' },
  { key: 'mostFours',   label: 'Most Fours' },
  { key: 'coinToss',    label: 'Coin Toss' },
];

// Whether tournament format has groups
const GROUP_FORMATS = ['Group + Knockout', 'Round Robin', 'League'];

// ══════════════════════════════════════════════════════════════════════════════
// Step 2 — Format & Rules
//
// @arg {Object}   data      — wizard shared data object
// @arg {Function} onUpdate  — (key, value) update handler
// ══════════════════════════════════════════════════════════════════════════════
export default class TournamentStep2 extends Component {
  get d() {
    return this.args.data ?? {};
  }

  // ── computed ──────────────────────────────────────────────────────────────

  get isCricket() {
    return this.d.sport?.toLowerCase() === 'cricket';
  }

  get hasGroups() {
    return GROUP_FORMATS.includes(this.d.tournamentFormat);
  }

  get tiebreakerRules() {
    return this.d.tiebreakerRules ?? [];
  }

  get scoringRules() {
    return this.d.scoringRules ?? { win: 2, tie: 1, loss: 0 };
  }

  isTiebreakerSelected = (key) => this.tiebreakerRules.includes(key);

  // ── actions ───────────────────────────────────────────────────────────────

  @action
  onInput(key, e) {
    this.args.onUpdate(key, e.target.value);
  }

  @action
  onNumberInput(key, e) {
    const val = parseInt(e.target.value, 10);
    this.args.onUpdate(key, isNaN(val) ? null : val);
  }

  @action
  onSelect(key, e) {
    this.args.onUpdate(key, e.target.value);
  }

  @action
  pick(key, value) {
    this.args.onUpdate(key, value);
  }

  @action
  onAgeLimit(field, e) {
    const val = parseInt(e.target.value, 10);
    const existing = this.d.ageLimit ?? { min: null, max: null };
    this.args.onUpdate('ageLimit', { ...existing, [field]: isNaN(val) ? null : val });
  }

  @action
  onScoringRule(field, e) {
    const val = parseInt(e.target.value, 10);
    this.args.onUpdate('scoringRules', {
      ...this.scoringRules,
      [field]: isNaN(val) ? 0 : val,
    });
  }

  @action
  toggleTiebreaker(key) {
    const current = [...this.tiebreakerRules];
    const idx = current.indexOf(key);
    if (idx === -1) {
      current.push(key);
    } else {
      current.splice(idx, 1);
    }
    this.args.onUpdate('tiebreakerRules', current);
  }

  <template>
    <div class="space-y-8">

      {{! ── Section header ──────────────────────────────────────────────── }}
      <div>
        <h2 class="text-lg font-bold text-gray-900 dark:text-white">
          Format &amp; Rules
        </h2>
        <p class="text-sm text-gray-500 dark:text-gray-400 mt-0.5">
          How the tournament will be structured and played
        </p>
      </div>

      {{! ── Tournament Type ──────────────────────────────────────────────── }}
      <div>
        <label
          class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5"
        >
          Tournament Type
          <span class="text-red-500">*</span>
        </label>
        <div class="flex flex-wrap gap-2">
          {{#each TOURNAMENT_TYPES as |t|}}
            <button
              type="button"
              {{on "click" (fn this.pick "tournamentType" t)}}
              class="px-3 py-1.5 text-xs font-medium rounded-full border-2 transition-all
                {{if
                  (eq this.d.tournamentType t)
                  'border-blue-500 bg-blue-50 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300'
                  'border-gray-200 dark:border-gray-600 text-gray-600 dark:text-gray-300 hover:border-blue-300'
                }}"
            >
              {{t}}
            </button>
          {{/each}}
        </div>
      </div>

      {{! ── Tournament Format ────────────────────────────────────────────── }}
      <div>
        <label
          class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5"
        >
          Tournament Format
          <span class="text-red-500">*</span>
        </label>
        <div class="flex flex-wrap gap-2">
          {{#each TOURNAMENT_FORMATS as |f|}}
            <button
              type="button"
              {{on "click" (fn this.pick "tournamentFormat" f)}}
              class="px-3 py-1.5 text-xs font-medium rounded-full border-2 transition-all
                {{if
                  (eq this.d.tournamentFormat f)
                  'border-blue-500 bg-blue-50 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300'
                  'border-gray-200 dark:border-gray-600 text-gray-600 dark:text-gray-300 hover:border-blue-300'
                }}"
            >
              {{f}}
            </button>
          {{/each}}
        </div>
      </div>

      {{! ── Match Format ─────────────────────────────────────────────────── }}
      <div>
        <label
          class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5"
        >
          Match Format
          <span class="text-red-500">*</span>
        </label>
        <div class="flex flex-wrap gap-2">
          {{#each MATCH_FORMATS as |m|}}
            <button
              type="button"
              {{on "click" (fn this.pick "matchFormat" m)}}
              class="px-3 py-1.5 text-xs font-medium rounded-full border-2 transition-all
                {{if
                  (eq this.d.matchFormat m)
                  'border-blue-500 bg-blue-50 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300'
                  'border-gray-200 dark:border-gray-600 text-gray-600 dark:text-gray-300 hover:border-blue-300'
                }}"
            >
              {{m}}
            </button>
          {{/each}}
        </div>
      </div>

      {{! ── Team & Player counts ─────────────────────────────────────────── }}
      <div class="grid grid-cols-2 gap-4 sm:grid-cols-3">

        <div>
          <label
            class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5"
          >
            Number of Teams
            <span class="text-red-500">*</span>
          </label>
          <input
            type="number"
            value={{this.d.numberOfTeams}}
            min="2"
            max="256"
            placeholder="e.g. 16"
            {{on "input" (fn this.onNumberInput "numberOfTeams")}}
            class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <div>
          <label
            class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5"
          >
            Players per Side
          </label>
          <input
            type="number"
            value={{this.d.playersPerSide}}
            min="1"
            max="15"
            placeholder="e.g. 11"
            {{on "input" (fn this.onNumberInput "playersPerSide")}}
            class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <div>
          <label
            class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5"
          >
            Max Squad Size
          </label>
          <input
            type="number"
            value={{this.d.maxSquadSize}}
            min="1"
            max="30"
            placeholder="e.g. 15"
            {{on "input" (fn this.onNumberInput "maxSquadSize")}}
            class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

      </div>

      {{! ── Group config (conditional) ──────────────────────────────────── }}
      {{#if this.hasGroups}}
        <div class="rounded-2xl border border-blue-100 dark:border-blue-900/40 bg-blue-50/50 dark:bg-blue-900/10 p-4 space-y-4">
          <p class="text-sm font-semibold text-blue-700 dark:text-blue-300">
            Group Stage Configuration
          </p>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label
                class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5"
              >
                Number of Groups
              </label>
              <input
                type="number"
                value={{this.d.numberOfGroups}}
                min="2"
                max="32"
                placeholder="e.g. 4"
                {{on "input" (fn this.onNumberInput "numberOfGroups")}}
                class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
            <div>
              <label
                class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5"
              >
                Teams per Group
              </label>
              <input
                type="number"
                value={{this.d.teamsPerGroup}}
                min="2"
                max="32"
                placeholder="e.g. 4"
                {{on "input" (fn this.onNumberInput "teamsPerGroup")}}
                class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
          </div>
        </div>
      {{/if}}

      {{! ── Cricket-specific ────────────────────────────────────────────── }}
      {{#if this.isCricket}}
        <div class="rounded-2xl border border-gray-200 dark:border-gray-700 p-4 space-y-4">
          <p class="text-sm font-semibold text-gray-700 dark:text-gray-300">
            Cricket Settings
          </p>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">

            <div>
              <label
                class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5"
              >
                Overs per Match
              </label>
              <input
                type="number"
                value={{this.d.oversPerMatch}}
                min="1"
                max="50"
                placeholder="e.g. 20"
                {{on "input" (fn this.onNumberInput "oversPerMatch")}}
                class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>

            <div>
              <label
                class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5"
              >
                Ball Type
              </label>
              <select
                {{on "change" (fn this.onSelect "ballType")}}
                class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                <option value="">Select ball type</option>
                {{#each BALL_TYPES as |b|}}
                  <option value={{b}} selected={{eq this.d.ballType b}}>{{b}}</option>
                {{/each}}
              </select>
            </div>

            <div>
              <label
                class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5"
              >
                Pitch Type
              </label>
              <select
                {{on "change" (fn this.onSelect "pitchType")}}
                class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                <option value="">Select pitch type</option>
                {{#each PITCH_TYPES as |p|}}
                  <option value={{p}} selected={{eq this.d.pitchType p}}>{{p}}</option>
                {{/each}}
              </select>
            </div>

          </div>
        </div>
      {{/if}}

      {{! ── Player Age Limit ─────────────────────────────────────────────── }}
      <div>
        <label
          class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5"
        >
          Player Age Limit
        </label>
        <p class="text-xs text-gray-400 mb-2">Leave blank for no restriction</p>
        <div class="flex items-center gap-3 max-w-xs">
          <input
            type="number"
            value={{this.d.ageLimit.min}}
            min="5"
            max="80"
            placeholder="Min"
            {{on "input" (fn this.onAgeLimit "min")}}
            class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <span class="text-sm text-gray-400 shrink-0">to</span>
          <input
            type="number"
            value={{this.d.ageLimit.max}}
            min="5"
            max="80"
            placeholder="Max"
            {{on "input" (fn this.onAgeLimit "max")}}
            class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <span class="text-sm text-gray-400 shrink-0">yrs</span>
        </div>
      </div>

      {{! ── Scoring Rules ────────────────────────────────────────────────── }}
      <div>
        <label
          class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5"
        >
          Scoring Rules
          <span class="text-xs font-normal text-gray-400 ml-1">(points per result)</span>
        </label>
        <div class="grid grid-cols-3 gap-3 max-w-sm">

          <div class="text-center">
            <p class="text-xs text-gray-500 dark:text-gray-400 mb-1.5">Win</p>
            <input
              type="number"
              value={{this.scoringRules.win}}
              min="0"
              max="10"
              {{on "input" (fn this.onScoringRule "win")}}
              class="w-full px-3 py-2.5 text-sm text-center rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          <div class="text-center">
            <p class="text-xs text-gray-500 dark:text-gray-400 mb-1.5">Tie / NR</p>
            <input
              type="number"
              value={{this.scoringRules.tie}}
              min="0"
              max="10"
              {{on "input" (fn this.onScoringRule "tie")}}
              class="w-full px-3 py-2.5 text-sm text-center rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          <div class="text-center">
            <p class="text-xs text-gray-500 dark:text-gray-400 mb-1.5">Loss</p>
            <input
              type="number"
              value={{this.scoringRules.loss}}
              min="0"
              max="10"
              {{on "input" (fn this.onScoringRule "loss")}}
              class="w-full px-3 py-2.5 text-sm text-center rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

        </div>
      </div>

      {{! ── Tiebreaker Rules ─────────────────────────────────────────────── }}
      <div>
        <label
          class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5"
        >
          Tiebreaker Rules
        </label>
        <p class="text-xs text-gray-400 mb-2">
          Select criteria used to break ties (in priority order)
        </p>
        <div class="flex flex-wrap gap-2">
          {{#each TIEBREAKER_OPTIONS as |opt|}}
            <button
              type="button"
              {{on "click" (fn this.toggleTiebreaker opt.key)}}
              class="px-3 py-2 text-sm font-medium rounded-xl border-2 transition-all
                {{if
                  (this.isTiebreakerSelected opt.key)
                  'border-blue-500 bg-blue-50 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300'
                  'border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300 hover:border-blue-300'
                }}"
            >
              {{opt.label}}
            </button>
          {{/each}}
        </div>
      </div>

      {{! ── Dates ───────────────────────────────────────────────────────── }}
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div>
          <label
            class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5"
          >
            Start Date
            <span class="text-red-500">*</span>
          </label>
          <input
            type="date"
            value={{this.d.startDate}}
            {{on "change" (fn this.onInput "startDate")}}
            class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
        <div>
          <label
            class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5"
          >
            End Date
            <span class="text-red-500">*</span>
          </label>
          <input
            type="date"
            value={{this.d.endDate}}
            min={{this.d.startDate}}
            {{on "change" (fn this.onInput "endDate")}}
            class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
      </div>

      {{! ── Location ─────────────────────────────────────────────────────── }}
      <div class="space-y-3">
        <label
          class="block text-sm font-semibold text-gray-700 dark:text-gray-300"
        >
          Venue / Location
        </label>
        <input
          type="text"
          value={{this.d.address}}
          placeholder="Stadium / venue name and address"
          {{on "input" (fn this.onInput "address")}}
          class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
        <div class="grid grid-cols-2 gap-3">
          <input
            type="text"
            value={{this.d.city}}
            placeholder="City"
            {{on "input" (fn this.onInput "city")}}
            class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <input
            type="text"
            value={{this.d.country}}
            placeholder="Country"
            {{on "input" (fn this.onInput "country")}}
            class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
      </div>

    </div>
  </template>
}
