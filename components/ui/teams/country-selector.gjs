import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { service } from '@ember/service';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { eq } from 'ember-truth-helpers';

export default class CountrySelector extends Component {
  @service countries;

  @tracked selected = null;
  @tracked showPicker = false;
  @tracked search = '';

  constructor() {
    super(...arguments);
    this.setup();
  }

  async setup() {
    await this.countries.load();

    // আগে args থেকে initial value নাও, না থাকলে detected country
    const initialCode = this.args.initialCode ?? this.countries.detectedCode ?? 'bd';
    this.selected = this.countries.findByCode(initialCode);
    this.notifyParent();
  }

  get filteredList() {
    const q = this.search.toLowerCase().trim();
    if (!q) return this.countries.list;
    return this.countries.list.filter((c) => c.name.toLowerCase().includes(q));
  }

  @action
  toggle() {
    this.showPicker = !this.showPicker;
    if (this.showPicker) this.search = '';
  }

  @action
  onSearch(e) {
    this.search = e.target.value;
  }

  @action
  pick(country) {
    this.selected = country;
    this.showPicker = false;
    this.notifyParent();
  }

  notifyParent() {
    this.args.onChange?.(this.selected);
  }

  <template>
    <div class="relative">

      {{! Trigger Button }}
      <button
        type="button"
        {{on "click" this.toggle}}
        class="w-full flex items-center justify-between pl-10 pr-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 text-gray-900 dark:text-gray-100 text-sm focus:outline-none focus:ring-2 focus:ring-rose-400/50 focus:border-rose-400 dark:focus:border-rose-500 transition-all"
      >
        {{#if this.selected}}
          <span class="flex items-center gap-2">
            <img src="https://flagcdn.com/w20/{{this.selected.code}}.png" alt={{this.selected.name}} class="w-5 h-4 rounded-sm object-cover" />

            <span>{{this.selected.name}}</span>
          </span>
        {{else}}
          <span class="text-gray-400 dark:text-gray-600">Select country…</span>
        {{/if}}
        <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      {{! Dropdown }}
      {{#if this.showPicker}}
        <div class="absolute z-50 top-full left-0 mt-1.5 w-full bg-white dark:bg-gray-800 border border-gray-100 dark:border-gray-700 rounded-xl shadow-2xl overflow-hidden">

          <div class="p-2.5 border-b border-gray-100 dark:border-gray-700">
            <input
              type="text"
              value={{this.search}}
              {{on "input" this.onSearch}}
              placeholder="Search country..."
              class="w-full bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-900 dark:text-gray-100 placeholder-gray-400 focus:outline-none focus:border-rose-400 transition-all"
            />
          </div>

          <div class="max-h-60 overflow-y-auto divide-y divide-gray-50 dark:divide-gray-700/60">
            {{#each this.filteredList as |country|}}
              <button type="button" {{on "click" (fn this.pick country)}} class="w-full flex items-center justify-between px-4 py-2.5 hover:bg-rose-50 dark:hover:bg-rose-900/20 transition-colors text-left">
                <span class="flex items-center gap-3">
                  <span class="text-lg">{{country.flag}}</span>
                  {{#if country.flag}}
                    <img src="https://flagcdn.com/w20/{{country.code}}.png" alt={{country.name}} class="w-5 h-4 rounded-sm object-cover" />
                  {{else}}
                    <span class="w-5 h-3.5 bg-slate-600 rounded-sm flex-shrink-0"></span>
                  {{/if}}

                  <span class="text-sm text-gray-800 dark:text-gray-200">{{country.name}}</span>
                </span>
                {{#if (eq this.selected.code country.code)}}
                  <div class="w-2 h-2 rounded-full bg-rose-500"></div>
                {{/if}}
              </button>
            {{else}}
              <div class="p-6 text-center text-sm text-gray-400">No countries found</div>
            {{/each}}
          </div>
        </div>

        <div class="fixed inset-0 z-40" {{on "click" this.toggle}}></div>
      {{/if}}

    </div>
  </template>
}
