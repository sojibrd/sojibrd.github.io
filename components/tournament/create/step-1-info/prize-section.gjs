import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { action } from '@ember/object';
import { eq } from 'ember-truth-helpers';
import lucideIcon from 'spordium/helpers/lucide-icon';

const FIXED_PRIZE_CATEGORIES = [
  { key: 'tournamentWinnerPrize', label: 'Winner' },
  { key: 'tournamentRunnerupPrize', label: 'Runner-up' },
  { key: 'manOfTheTournamentPrize', label: 'Man of Tournament' },
  { key: 'manOfTheMatchPrize', label: 'Man of Match' },
];

const CURRENCIES = ['BDT', 'USD'];
const FIXED_KEYS = new Set(FIXED_PRIZE_CATEGORIES.map((c) => c.key));

const emptyFixed = () => ({
  prize: '',
  prize_trophy: false,
  prize_money_currency: 'BDT',
});

export default class PrizeSection extends Component {
  constructor(owner, args) {
    super(owner, args);

    const prizes = args.prizes ?? [];

    // Fixed prizes populate
    const fixedMap = new Map();
    const fixedDirty = new Set();

    prizes
      .filter((p) => FIXED_KEYS.has(p.prize_name))
      .forEach((p) => {
        fixedMap.set(p.prize_name, {
          prize: p.prize ?? '',
          prize_trophy: p.prize_trophy ?? false,
          prize_money_currency: p.prize_money_currency ?? 'BDT',
        });
        fixedDirty.add(p.prize_name); // server থেকে আসা মানে already dirty
      });

    this._fixedMap = fixedMap;
    this._fixedDirty = fixedDirty;

    // Custom prizes populate
    this._customPrizes = prizes.filter((p) => !FIXED_KEYS.has(p.prize_name)).map((p) => ({ ...p }));
  }

  // fixed prizes: Map<key, { prize, prize_trophy, prize_money_currency }>
  // dirty: Set<key> — কোনগুলো changed
  @tracked _fixedMap = new Map();
  @tracked _fixedDirty = new Set();

  // custom prizes array
  @tracked _customPrizes = [];

  // delete list (BD... ids)
  @tracked _deletePrizes = [];

  get fixedCategories() {
    return FIXED_PRIZE_CATEGORIES;
  }
  get currencies() {
    return CURRENCIES;
  }
  // ── fixed helpers ─────────────────────────────────────────────────────────

  _getFixed(key) {
    return this._fixedMap.get(key) ?? emptyFixed();
  }

  getFixedAmount = (key) => this._getFixed(key).prize;
  getFixedCurrency = (key) => this._getFixed(key).prize_money_currency;
  getFixedTrophy = (key) => this._getFixed(key).prize_trophy;

  #patchFixed(key, patch) {
    const next = new Map(this._fixedMap);
    next.set(key, { ...this._getFixed(key), ...patch });
    this._fixedMap = next;

    const dirty = new Set(this._fixedDirty);
    dirty.add(key);
    this._fixedDirty = dirty;

    this.#notify();
  }

  // ── custom helpers ────────────────────────────────────────────────────────

  #patchCustom(prizeId, patch) {
    this._customPrizes = this._customPrizes.map((p) => (p.prize_id === prizeId ? { ...p, ...patch } : p));
    this.#notify();
  }

  // ── notify parent ─────────────────────────────────────────────────────────

  #notify() {
    // dirty fixed prizes only
    const fixedItems = [...this._fixedDirty].map((key) => ({
      prize_name: key,
      ...this._getFixed(key),
    }));

    // custom prizes — existing ones keep prize_id, new ones don't send prize_id
    const customItems = this._customPrizes.map(({ prize_id, ...rest }) => {
      if (prize_id?.startsWith('BD')) {
        return { prize_id, ...rest };
      }
      return rest; // নতুন custom — prize_id ছাড়া
    });

    this.args.onChange({
      tournament_prize: [...fixedItems, ...customItems],
      delete_prizes: [...this._deletePrizes],
    });
  }

  // ── fixed actions ─────────────────────────────────────────────────────────

  @action onFixedAmountInput(key, e) {
    this.#patchFixed(key, { prize: e.target.value });
  }

  @action onFixedCurrencyChange(key, e) {
    this.#patchFixed(key, { prize_money_currency: e.target.value });
  }

  @action toggleFixedTrophy(key) {
    this.#patchFixed(key, { prize_trophy: !this.getFixedTrophy(key) });
  }

  // ── custom actions ────────────────────────────────────────────────────────

  @action onCustomAmountInput(prizeId, e) {
    this.#patchCustom(prizeId, { prize: e.target.value });
  }

  @action onCustomCurrencyChange(prizeId, e) {
    this.#patchCustom(prizeId, { prize_money_currency: e.target.value });
  }

  @action toggleCustomTrophy(prizeId) {
    const p = this._customPrizes.find((x) => x.prize_id === prizeId);
    this.#patchCustom(prizeId, { prize_trophy: !p?.prize_trophy });
  }

  @action onCustomLabelInput(prizeId, e) {
    this.#patchCustom(prizeId, { prize_name: e.target.value });
  }

  @action addCustomPrize() {
    this._customPrizes = [
      ...this._customPrizes,
      {
        prize_id: crypto.randomUUID(), // temp id, BD দিয়ে শুরু না — payload এ যাবে না
        prize_name: '',
        prize: '',
        prize_trophy: false,
        prize_money_currency: 'BDT',
      },
    ];
    this.#notify();
  }

  @action removeCustomPrize(prizeId) {
    if (prizeId.startsWith('BD')) {
      this._deletePrizes = [...this._deletePrizes, prizeId];
    }
    this._customPrizes = this._customPrizes.filter((p) => p.prize_id !== prizeId);
    this.#notify();
  }

  <template>
    <div>
      <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-3">
        Prizes
      </label>

      <div class="space-y-3">

        {{! ── Fixed prizes ─────────────────────────────────────────────── }}
        {{#each this.fixedCategories as |cat|}}
          <div class="flex items-center gap-3">
            <span class="w-36 text-sm text-gray-600 dark:text-gray-400 shrink-0">{{cat.label}}</span>

            <button
              type="button"
              {{on "click" (fn this.toggleFixedTrophy cat.key)}}
              class="p-2 rounded-lg border-2 transition-all shrink-0 {{if (this.getFixedTrophy cat.key) 'border-yellow-400 bg-yellow-50 dark:bg-yellow-900/20 text-yellow-600' 'border-gray-200 dark:border-gray-600 text-gray-400 hover:border-yellow-300'}}"
            >
              {{lucideIcon "trophy" class="w-4 h-4"}}
            </button>

            <select
              {{on "change" (fn this.onFixedCurrencyChange cat.key)}}
              class="w-20 px-2 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              {{#each this.currencies as |cur|}}
                <option value={{cur}} selected={{eq (this.getFixedCurrency cat.key) cur}}>{{cur}}</option>
              {{/each}}
            </select>

            <input
              type="number"
              value={{this.getFixedAmount cat.key}}
              min="0"
              placeholder="0"
              {{on "input" (fn this.onFixedAmountInput cat.key)}}
              class="flex-1 px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
        {{/each}}

        {{! ── Divider ──────────────────────────────────────────────────── }}
        {{#if this._customPrizes.length}}
          <div class="flex items-center gap-3 py-1">
            <div class="flex-1 h-px bg-gray-200 dark:bg-gray-700"></div>
            <span class="text-xs text-gray-400 shrink-0">Custom Prizes</span>
            <div class="flex-1 h-px bg-gray-200 dark:bg-gray-700"></div>
          </div>
        {{/if}}

        {{! ── Custom prizes ─────────────────────────────────────────────── }}
        {{#each this._customPrizes key="prize_id" as |p|}}
          <div class="flex items-center gap-3 p-3 rounded-xl bg-gray-50 dark:bg-gray-800/50 border border-gray-200 dark:border-gray-700">

            <input
              type="text"
              value={{p.prize_name}}
              placeholder="Prize name…"
              maxlength="60"
              {{on "input" (fn this.onCustomLabelInput p.prize_id)}}
              class="w-36 shrink-0 px-3 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />

            <button
              type="button"
              {{on "click" (fn this.toggleCustomTrophy p.prize_id)}}
              class="p-2 rounded-lg border-2 transition-all shrink-0 {{if p.prize_trophy 'border-yellow-400 bg-yellow-50 dark:bg-yellow-900/20 text-yellow-600' 'border-gray-200 dark:border-gray-600 text-gray-400 hover:border-yellow-300'}}"
            >
              {{lucideIcon "trophy" class="w-4 h-4"}}
            </button>

            <select
              {{on "change" (fn this.onCustomCurrencyChange p.prize_id)}}
              class="w-20 px-2 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              {{#each this.currencies as |cur|}}
                <option value={{cur}} selected={{eq p.prize_money_currency cur}}>{{cur}}</option>
              {{/each}}
            </select>

            <input
              type="number"
              value={{p.prize}}
              min="0"
              placeholder="0"
              {{on "input" (fn this.onCustomAmountInput p.prize_id)}}
              class="flex-1 px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />

            <button type="button" {{on "click" (fn this.removeCustomPrize p.prize_id)}} class="p-2 rounded-lg text-red-400 hover:text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors shrink-0">
              {{lucideIcon "x" class="w-4 h-4"}}
            </button>
          </div>
        {{/each}}

        <button
          type="button"
          {{on "click" this.addCustomPrize}}
          class="w-full py-2.5 flex items-center justify-center gap-2 text-sm font-medium text-blue-600 dark:text-blue-400 border-2 border-dashed border-blue-300 dark:border-blue-700 rounded-xl hover:bg-blue-50 dark:hover:bg-blue-900/20 transition-colors"
        >
          {{lucideIcon "plus" class="w-4 h-4"}}
          Add Prize
        </button>

      </div>
    </div>
  </template>
}
