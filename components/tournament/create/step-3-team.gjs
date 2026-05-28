import Component from '@glimmer/component';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import lucideIcon from 'spordium/helpers/lucide-icon';
import { eq, gt } from 'ember-truth-helpers';

const TEAM_COUNTS = [2, 4, 8, 16, 32, 64];
const CURRENCIES = ['BDT', 'USD', 'EUR', 'GBP', 'INR'];
const CURRENCY_SYM = { BDT: '৳', USD: '$', EUR: '€', GBP: '£', INR: '₹' };

function add(a, b) {
  return a + b;
}

// ══════════════════════════════════════════════════════════════════════════════
// Step 3 — Team slots + registration + prize pool
//
// @arg {Object}   data       — wizard shared data object
// @arg {Function} onUpdate   — (key, value) update handler
//
// Team list becomes active only after Step 1 is saved (args.step1Complete).
// For open registration: organiser can pre-seed invited teams.
// For invitation-only:   organiser must add all teams manually.
// ══════════════════════════════════════════════════════════════════════════════
export default class TournamentStep3 extends Component {
  // ── prize rows (local tracked, synced to shared data) ────────────────────
  @tracked prizeRows = this.args.data?.prizeBreakdown?.length ? this.args.data.prizeBreakdown : [{ position: '1st', amount: '' }];

  // ── team list (local tracked, synced to shared data) ─────────────────────
  @tracked teamNameDraft = '';

  // ── getters ───────────────────────────────────────────────────────────────
  get d() {
    return this.args.data ?? {};
  }
  get teamCounts() {
    return TEAM_COUNTS;
  }
  get currencies() {
    return CURRENCIES;
  }

  get feeCurrency() {
    return this.d.registrationFee?.currency ?? 'BDT';
  }
  get feeAmount() {
    return this.d.registrationFee?.amount ?? '';
  }
  get currencySymbol() {
    return CURRENCY_SYM[this.feeCurrency] ?? '৳';
  }

  get teams() {
    return this.d.teams ?? [];
  }

  get isInvitationOnly() {
    return this.d.registrationType === 'invitation';
  }

  get step1Complete() {
    // Step 1 must have a tournament name at minimum to unlock team section
    return !!this.args.data?.name;
  }

  get slotsLeft() {
    const max = parseInt(this.d.maxTeams, 10);
    if (!max) return null;
    return Math.max(0, max - this.teams.length);
  }

  // ── actions — general ─────────────────────────────────────────────────────
  @action
  onInput(key, e) {
    this.args.onUpdate(key, e.target.value);
  }

  @action
  pickTeamCount(n) {
    this.args.onUpdate('maxTeams', n);
  }

  @action
  toggleEntryFee(e) {
    this.args.onUpdate('hasEntryFee', e.target.checked);
  }

  // ── actions — registration fee ────────────────────────────────────────────
  @action
  onFeeAmountInput(e) {
    this.args.onUpdate('registrationFee', {
      currency: this.feeCurrency,
      amount: e.target.value,
    });
  }

  @action
  onFeeCurrencyChange(e) {
    this.args.onUpdate('registrationFee', {
      amount: this.feeAmount,
      currency: e.target.value,
    });
  }

  // ── actions — team list ───────────────────────────────────────────────────
  @action
  onTeamDraftInput(e) {
    this.teamNameDraft = e.target.value;
  }

  @action
  addTeam(e) {
    // support both button click and Enter key
    if (e?.key && e.key !== 'Enter') return;
    const name = this.teamNameDraft.trim();
    if (!name) return;

    const maxTeams = parseInt(this.d.maxTeams, 10);
    if (maxTeams && this.teams.length >= maxTeams) return;

    const updated = [...this.teams, { id: crypto.randomUUID(), name, status: 'invited' }];
    this.args.onUpdate('teams', updated);
    this.teamNameDraft = '';
  }

  @action
  removeTeam(id) {
    this.args.onUpdate(
      'teams',
      this.teams.filter((t) => t.id !== id)
    );
  }

  @action
  toggleTeamStatus(id) {
    const updated = this.teams.map((t) => (t.id === id ? { ...t, status: t.status === 'confirmed' ? 'invited' : 'confirmed' } : t));
    this.args.onUpdate('teams', updated);
  }

  // ── actions — prize rows ──────────────────────────────────────────────────
  @action
  addPrizeRow() {
    const positions = ['1st', '2nd', '3rd', '4th', '5th–8th', '9th–16th'];
    const next = positions[this.prizeRows.length] ?? `${this.prizeRows.length + 1}th`;
    this.prizeRows = [...this.prizeRows, { position: next, amount: '' }];
    this.args.onUpdate('prizeBreakdown', this.prizeRows);
  }

  @action
  removePrizeRow(index) {
    this.prizeRows = this.prizeRows.filter((_, i) => i !== index);
    this.args.onUpdate('prizeBreakdown', this.prizeRows);
  }

  @action
  updatePrizeRow(index, key, e) {
    this.prizeRows = this.prizeRows.map((row, i) => (i === index ? { ...row, [key]: e.target.value } : row));
    this.args.onUpdate('prizeBreakdown', this.prizeRows);
  }

  <template>
    <div class="space-y-8">

      {{! ── Section header ──────────────────────────────────────────────── }}
      <div>
        <h2 class="text-lg font-bold text-gray-900 dark:text-white">
          Teams &amp; Registration
        </h2>
        <p class="text-sm text-gray-500 dark:text-gray-400 mt-0.5">
          Slots, fees, prize pool and team roster
        </p>
      </div>

      {{! ── Max teams ───────────────────────────────────────────────────── }}
      <div>
        <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
          Maximum Teams
          <span class="text-red-500">*</span>
        </label>
        <div class="flex flex-wrap gap-2">
          {{#each this.teamCounts as |n|}}
            <button
              type="button"
              {{on "click" (fn this.pickTeamCount n)}}
              class="w-16 h-10 text-sm font-bold rounded-xl border-2 transition-all
                {{if
                  (eq this.d.maxTeams n)
                  'border-blue-500 bg-blue-50 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300'
                  'border-gray-200 dark:border-gray-600 text-gray-600 dark:text-gray-300 hover:border-blue-300'
                }}"
            >
              {{n}}
            </button>
          {{/each}}
          <input
            type="number"
            min="2"
            max="256"
            placeholder="Custom"
            {{on "input" (fn this.onInput "maxTeams")}}
            class="w-24 px-3 py-2 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
      </div>

      {{! ── Registration deadline ────────────────────────────────────────── }}
      <div>
        <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
          Registration Deadline
        </label>
        <input
          type="datetime-local"
          value={{this.d.registrationDeadline}}
          {{on "change" (fn this.onInput "registrationDeadline")}}
          class="w-full sm:w-72 px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>

      {{! ── Registration fee ─────────────────────────────────────────────── }}
      <div class="p-4 rounded-2xl border border-gray-200 dark:border-gray-700 space-y-4">
        {{! Toggle }}
        <label class="flex items-center gap-3 cursor-pointer">
          <div class="relative">
            <input type="checkbox" checked={{this.d.hasEntryFee}} {{on "change" this.toggleEntryFee}} class="sr-only peer" />
            <div class="w-10 h-6 rounded-full bg-gray-200 dark:bg-gray-600 peer-checked:bg-blue-600 transition-colors"></div>
            <div class="absolute left-1 top-1 w-4 h-4 rounded-full bg-white shadow peer-checked:translate-x-4 transition-transform"></div>
          </div>
          <div>
            <p class="text-sm font-semibold text-gray-900 dark:text-white">
              Registration Fee
            </p>
            <p class="text-xs text-gray-500 dark:text-gray-400">
              Teams pay to register
            </p>
          </div>
        </label>

        {{! Fee amount + currency }}
        {{#if this.d.hasEntryFee}}
          <div class="flex items-center gap-2 max-w-xs">
            {{! Currency selector }}
            <select
              {{on "change" this.onFeeCurrencyChange}}
              class="w-24 shrink-0 px-2 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              {{#each this.currencies as |cur|}}
                <option value={{cur}} selected={{eq this.feeCurrency cur}}>
                  {{cur}}
                </option>
              {{/each}}
            </select>
            {{! Amount input }}
            <div class="relative flex-1">
              <span class="absolute left-3 top-1/2 -translate-y-1/2 text-sm font-bold text-gray-400">
                {{this.currencySymbol}}
              </span>
              <input
                type="number"
                min="0"
                step="100"
                value={{this.feeAmount}}
                placeholder="0"
                {{on "input" this.onFeeAmountInput}}
                class="w-full pl-8 pr-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
          </div>
        {{/if}}
      </div>

      {{! ── Team List / Selection ────────────────────────────────────────── }}
      <div class="space-y-3">
        <div class="flex items-center justify-between">
          <div>
            <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300">
              Team List
              {{#if this.isInvitationOnly}}
                <span class="ml-2 text-xs font-medium px-2 py-0.5 rounded-full bg-orange-100 dark:bg-orange-900/30 text-orange-600 dark:text-orange-400">
                  Invitation Only
                </span>
              {{/if}}
            </label>
            <p class="text-xs text-gray-400 mt-0.5">
              {{#if this.isInvitationOnly}}
                Add all teams manually — they will receive invitations
              {{else}}
                Pre-seed teams or leave empty for open registration
              {{/if}}
            </p>
          </div>
          {{#if this.d.maxTeams}}
            <span class="text-xs text-gray-400 shrink-0">
              {{this.teams.length}}
              /
              {{this.d.maxTeams}}
              teams
            </span>
          {{/if}}
        </div>

        {{! Locked state — Step 1 not complete }}
        {{#if (eq this.step1Complete false)}}
          <div class="flex items-center gap-2 px-4 py-3 rounded-xl bg-gray-50 dark:bg-gray-800/50 border border-dashed border-gray-300 dark:border-gray-600">
            {{lucideIcon "lock" class="w-4 h-4 text-gray-400 shrink-0"}}
            <p class="text-sm text-gray-400">
              Complete Step 1 (tournament name) to unlock team management
            </p>
          </div>

        {{else}}
          {{! Add team input }}
          {{#if (eq this.slotsLeft null)}}
            {{! no max set yet, still allow adding }}
            <div class="flex gap-2">
              <input
                type="text"
                value={{this.teamNameDraft}}
                placeholder="Team name…"
                {{on "input" this.onTeamDraftInput}}
                {{on "keydown" this.addTeam}}
                class="flex-1 px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
              <button
                type="button"
                {{on "click" this.addTeam}}
                class="px-4 py-2.5 text-sm font-semibold rounded-xl bg-blue-600 hover:bg-blue-700 text-white transition-colors"
              >
                Add
              </button>
            </div>
          {{else if (gt this.slotsLeft 0)}}
            <div class="flex gap-2">
              <input
                type="text"
                value={{this.teamNameDraft}}
                placeholder="Team name…"
                {{on "input" this.onTeamDraftInput}}
                {{on "keydown" this.addTeam}}
                class="flex-1 px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
              <button
                type="button"
                {{on "click" this.addTeam}}
                class="px-4 py-2.5 text-sm font-semibold rounded-xl bg-blue-600 hover:bg-blue-700 text-white transition-colors"
              >
                Add
              </button>
            </div>
          {{else}}
            <p class="text-xs text-orange-500 dark:text-orange-400 px-1">All slots filled. Increase maximum teams to add more.</p>
          {{/if}}

          {{! Team rows }}
          {{#if (gt this.teams.length 0)}}
            <div class="space-y-2 mt-1">
              {{#each this.teams as |team i|}}
                <div class="flex items-center gap-3 px-3 py-2.5 rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800">
                  {{! Position badge }}
                  <span
                    class="w-6 h-6 rounded-full bg-gray-100 dark:bg-gray-700 text-xs font-bold text-gray-500 dark:text-gray-400 flex items-center justify-center shrink-0"
                  >
                    {{add i 1}}
                  </span>

                  {{! Team name }}
                  <span class="flex-1 text-sm text-gray-900 dark:text-white truncate">
                    {{team.name}}
                  </span>

                  {{! Status badge + toggle }}
                  <button
                    type="button"
                    {{on "click" (fn this.toggleTeamStatus team.id)}}
                    class="text-xs font-medium px-2.5 py-1 rounded-full transition-colors
                      {{if
                        (eq team.status 'confirmed')
                        'bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400'
                        'bg-yellow-100 dark:bg-yellow-900/30 text-yellow-700 dark:text-yellow-400'
                      }}"
                  >
                    {{if (eq team.status "confirmed") "Confirmed" "Invited"}}
                  </button>

                  {{! Remove }}
                  <button
                    type="button"
                    {{on "click" (fn this.removeTeam team.id)}}
                    class="p-1.5 rounded-lg hover:bg-red-50 dark:hover:bg-red-900/20 text-gray-400 hover:text-red-500 transition-colors"
                  >
                    {{lucideIcon "x" class="w-3.5 h-3.5"}}
                  </button>
                </div>
              {{/each}}
            </div>
          {{/if}}
        {{/if}}
      </div>

      {{! ── Prize pool ───────────────────────────────────────────────────── }}
      <div class="space-y-3">
        <label class="text-sm font-semibold text-gray-700 dark:text-gray-300">
          Prize Pool
        </label>

        {{! Total }}
        <div class="relative w-48">
          <span class="absolute left-3 top-1/2 -translate-y-1/2 text-sm font-bold text-gray-400">
            {{this.currencySymbol}}
          </span>
          <input
            type="number"
            min="0"
            step="1000"
            value={{this.d.prizePool}}
            placeholder="Total prize pool"
            {{on "input" (fn this.onInput "prizePool")}}
            class="w-full pl-8 pr-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        {{! Breakdown rows }}
        <div class="space-y-2">
          {{#each this.prizeRows as |row i|}}
            <div class="flex items-center gap-3">
              <div class="flex items-center gap-1.5 w-24 shrink-0">
                {{lucideIcon "medal" class="w-3.5 h-3.5 text-yellow-500 shrink-0"}}
                <input
                  type="text"
                  value={{row.position}}
                  {{on "input" (fn this.updatePrizeRow i "position")}}
                  class="w-full px-2 py-1.5 text-xs rounded-lg border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 focus:outline-none focus:ring-1 focus:ring-blue-500"
                />
              </div>
              <div class="relative flex-1">
                <span class="absolute left-3 top-1/2 -translate-y-1/2 text-xs text-gray-400">
                  {{this.currencySymbol}}
                </span>
                <input
                  type="number"
                  min="0"
                  value={{row.amount}}
                  placeholder="Amount"
                  {{on "input" (fn this.updatePrizeRow i "amount")}}
                  class="w-full pl-7 pr-3 py-1.5 text-xs rounded-lg border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 focus:outline-none focus:ring-1 focus:ring-blue-500"
                />
              </div>
              {{#if (gt this.prizeRows.length 1)}}
                <button
                  type="button"
                  {{on "click" (fn this.removePrizeRow i)}}
                  class="p-1.5 rounded-lg hover:bg-red-50 dark:hover:bg-red-900/20 text-gray-400 hover:text-red-500 transition-colors"
                >
                  {{lucideIcon "trash-2" class="w-3.5 h-3.5"}}
                </button>
              {{/if}}
            </div>
          {{/each}}
        </div>

        <button
          type="button"
          {{on "click" this.addPrizeRow}}
          class="flex items-center gap-1.5 text-xs font-medium text-blue-600 dark:text-blue-400 hover:underline mt-1"
        >
          {{lucideIcon "plus" class="w-3.5 h-3.5"}}
          Add position
        </button>
      </div>

    </div>
  </template>
}
