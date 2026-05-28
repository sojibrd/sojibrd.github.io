// app/components/teams/ui/phone-input.gjs
import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { service } from '@ember/service';
import { fn } from '@ember/helper';
import { eq } from 'ember-truth-helpers';

export default class PhoneInput extends Component {
  @service countries;

  @tracked phoneNumber = '';
  @tracked phoneCountry = { name: 'Bangladesh', code: 'bd', dial: '+880', flag: '🇧🇩' };
  @tracked showCountryPicker = false;
  @tracked countrySearch = '';

  get countriesList() {
    return this.countries.list;
  }

  constructor() {
    super(...arguments);
    this.setup();
  }

  async setup() {
    await this.countries.load();
    const code = this.countries.detectedCode ?? 'bd';
    this.phoneCountry = this.countries.findByCode(code) ?? { name: 'Bangladesh', code: 'bd', dial: '+880', flag: '🇧🇩' };

    console.log('phoneNumber', this.args.initialValue);
    // ── initial value parse করো ──
    if (this.args.initialValue) {
      const raw = this.args.initialValue;

      // সব country dial code দিয়ে match করার চেষ্টা করো
      // দীর্ঘ dial code আগে check করো (e.g. +1868 before +1)
      const sortedCountries = [...this.countries.list].sort((a, b) => b.dial.length - a.dial.length);

      const matched = sortedCountries.find((c) => raw.startsWith(c.dial));

      if (matched) {
        this.phoneCountry = matched;
        this.phoneNumber = raw.slice(matched.dial.length); // +880 = 4 chars, বাকিটা number
      } else {
        this.phoneNumber = raw;
      }
    }
  }

  get filteredCountries() {
    const q = this.countrySearch.toLowerCase().trim();
    if (!q) return this.countriesList;
    return this.countriesList.filter((c) => c.name.toLowerCase().includes(q) || c.dial.includes(q));
  }

  @action
  toggleCountryPicker() {
    this.showCountryPicker = !this.showCountryPicker;
    if (this.showCountryPicker) this.countrySearch = '';
  }

  @action
  onCountrySearch(e) {
    this.countrySearch = e.target.value;
  }

  @action
  handlePhoneInput(e) {
    this.phoneNumber = e.target.value;
    this.notifyParent();
  }

  @action
  selectCountry(country) {
    this.phoneCountry = country;
    this.showCountryPicker = false;
    this.notifyParent();
  }

  notifyParent() {
    this.args.onChange?.({
      number: this.phoneNumber,
      country: this.phoneCountry,
      fullNumber: `${this.phoneCountry.dial}${this.phoneNumber}`,
    });
  }

  <template>
    <div class="space-y-2 relative">
      <label class="block text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">
        Mobile
        <span class="text-rose-400">*</span>
      </label>
      <div class="flex gap-2">
        <button
          type="button"
          {{on "click" this.toggleCountryPicker}}
          class="flex items-center gap-1.5 px-3 py-2.5 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 hover:border-emerald-400 dark:hover:border-emerald-500 text-gray-700 dark:text-gray-200 transition-all focus:outline-none focus:ring-2 focus:ring-emerald-400/50"
        >
          <img src="https://flagcdn.com/w20/{{this.phoneCountry.code}}.png" alt={{this.phoneCountry.name}} class="w-5 h-4 rounded-sm object-cover" />
          <span class="text-sm font-medium">{{this.phoneCountry.dial}}</span>
          <svg class="w-3.5 h-3.5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
          </svg>
        </button>

        <div class="relative flex-1">
          <span class="absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none">
            <svg class="w-4 h-4 text-gray-400 dark:text-gray-500" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 1.5H8.25A2.25 2.25 0 0 0 6 3.75v16.5a2.25 2.25 0 0 0 2.25 2.25h7.5A2.25 2.25 0 0 0 18 20.25V3.75a2.25 2.25 0 0 0-2.25-2.25H13.5m-3 0V3h3V1.5m-3 0h3m-3 18.75h3" />
            </svg>
          </span>
          <input
            type="tel"
            value={{this.phoneNumber}}
            {{on "input" this.handlePhoneInput}}
            placeholder="1XXX XXXXXX"
            class="w-full pl-10 pr-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 text-gray-900 dark:text-gray-100 placeholder-gray-400 dark:placeholder-gray-600 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-400/50 focus:border-emerald-400 dark:focus:border-emerald-500 transition-all"
          />
        </div>
      </div>

      {{#if this.showCountryPicker}}
        <div class="absolute z-50 top-full left-0 mt-1.5 w-72 bg-white dark:bg-gray-800 border border-gray-100 dark:border-gray-700 rounded-xl shadow-2xl overflow-hidden">
          <div class="p-2.5 border-b border-gray-100 dark:border-gray-700">
            <input
              type="text"
              value={{this.countrySearch}}
              {{on "input" this.onCountrySearch}}
              placeholder="Search country..."
              class="w-full bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-900 dark:text-gray-100 placeholder-gray-400 focus:outline-none focus:border-emerald-400 transition-all"
            />
          </div>
          <div class="max-h-60 overflow-y-auto divide-y divide-gray-50 dark:divide-gray-700/60">
            {{#each this.filteredCountries as |country|}}
              <button type="button" {{on "click" (fn this.selectCountry country)}} class="w-full flex items-center justify-between px-4 py-2.5 hover:bg-indigo-50 dark:hover:bg-indigo-900/30 transition-colors text-left">
                <div class="flex items-center gap-3">
                  {{#if this.phoneCountry.flag}}
                    <img src="https://flagcdn.com/w20/{{country.code}}.png" alt={{country.name}} class="w-5 h-4 rounded-sm object-cover" />
                  {{else}}
                    <span class="w-5 h-3.5 bg-slate-600 rounded-sm flex-shrink-0"></span>
                  {{/if}}
                  <div class="flex flex-col">
                    <span class="text-sm font-medium text-gray-800 dark:text-gray-200">{{country.name}}</span>
                    <span class="text-xs text-gray-400 dark:text-gray-500">{{country.dial}}</span>
                  </div>
                </div>
                {{#if (eq this.phoneCountry.code country.code)}}
                  <div class="w-2 h-2 rounded-full bg-emerald-500"></div>
                {{/if}}
              </button>
            {{else}}
              <div class="p-6 text-center text-sm text-gray-400 dark:text-gray-500">
                No countries found
              </div>
            {{/each}}
          </div>
        </div>
        <div class="fixed inset-0 z-40" {{on "click" this.toggleCountryPicker}}></div>
      {{/if}}
    </div>
  </template>
}
