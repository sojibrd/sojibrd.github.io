import Component from '@glimmer/component';
import { on } from '@ember/modifier';
import { fn, get } from '@ember/helper';
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import lucideIcon from 'spordium/helpers/lucide-icon';
import { eq } from 'ember-truth-helpers';

// ─────────────────────────────────────────────────────────────────────────────
const POLICY_TABS = [
  {
    key: 'matchRules',
    label: 'Match Rules',
    icon: 'scroll-text',
    placeholder: `e.g.\n• Each team must field at least 11 players.\n• The toss will be held 15 minutes before match start.\n• DLS method applies in case of rain interruption.\n• A player dismissed for misconduct will not be replaced.`,
    hint: 'On-field rules specific to match play',
  },
  {
    key: 'codeOfConduct',
    label: 'Code of Conduct',
    icon: 'shield-check',
    placeholder: `e.g.\n• Players must treat opponents and officials with respect.\n• Physical or verbal abuse will result in immediate disqualification.\n• Teams are responsible for the behaviour of their supporters.\n• All disputes must be raised through the official appeal process.`,
    hint: 'Behavioural guidelines for players and teams',
  },
  {
    key: 'termsAndConditions',
    label: 'Terms & Conditions',
    icon: 'file-text',
    placeholder: `e.g.\n• Registration fees are non-refundable after the deadline.\n• The organiser reserves the right to amend fixtures.\n• Participants consent to photography and media coverage.\n• The organiser is not liable for any injury or loss.`,
    hint: 'Legal and participation terms for the event',
  },
];

// ══════════════════════════════════════════════════════════════════════════════
// Step 5 — Settings + Policy documents + Publish
//
// @arg {Object}   data         — wizard shared data
// @arg {Function} onUpdate     — (key, value)
// @arg {boolean}  isSubmitting — disable buttons while saving
// @arg {string}   submitError  — error message if save failed
// @arg {Function} onSaveDraft  — save as draft
// @arg {Function} onPublish    — publish
// ══════════════════════════════════════════════════════════════════════════════
export default class TournamentStep5 extends Component {
  @tracked activePolicyTab = 'matchRules';

  get d() {
    return this.args.data ?? {};
  }

  get policyTabs() {
    return POLICY_TABS;
  }

  get activeTab() {
    return POLICY_TABS.find((t) => t.key === this.activePolicyTab);
  }

  get activeTabCharCount() {
    return this.d[this.activePolicyTab]?.length ?? 0;
  }

  // ── actions ───────────────────────────────────────────────────────────────
  @action
  toggleBool(key, e) {
    this.args.onUpdate(key, e.target.checked);
  }

  @action
  onInput(key, e) {
    this.args.onUpdate(key, e.target.value);
  }

  @action
  setTab(key) {
    this.activePolicyTab = key;
  }

  <template>
    <div class="space-y-8">

      {{! ── Section header ──────────────────────────────────────────────── }}
      <div>
        <h2 class="text-lg font-bold text-gray-900 dark:text-white">
          Settings &amp; Policies
        </h2>
        <p class="text-sm text-gray-500 dark:text-gray-400 mt-0.5">
          Final options and policy documents before publishing
        </p>
      </div>

      {{! ══════════════════════════════════════════════════════════════════ }}
      {{! VISIBILITY TOGGLES                                                 }}
      {{! ══════════════════════════════════════════════════════════════════ }}
      <div class="space-y-3">
        <p class="text-xs font-bold uppercase tracking-widest text-gray-400">Visibility</p>

        {{! Public }}
        <label
          class="flex items-center justify-between p-4 rounded-2xl border border-gray-200 dark:border-gray-700 cursor-pointer hover:border-blue-300 transition-colors"
        >
          <div>
            <p class="text-sm font-semibold text-gray-900 dark:text-white">
              Public Tournament
            </p>
            <p class="text-xs text-gray-500 dark:text-gray-400">
              Anyone can find and view this tournament
            </p>
          </div>
          <div class="relative ml-4 shrink-0">
            <input type="checkbox" checked={{this.d.isPublic}} {{on "change" (fn this.toggleBool "isPublic")}} class="sr-only peer" />
            <div class="w-10 h-6 rounded-full bg-gray-200 dark:bg-gray-600 peer-checked:bg-blue-600 transition-colors"></div>
            <div class="absolute left-1 top-1 w-4 h-4 rounded-full bg-white shadow peer-checked:translate-x-4 transition-transform"></div>
          </div>
        </label>

        {{! Open registration }}
        <label
          class="flex items-center justify-between p-4 rounded-2xl border border-gray-200 dark:border-gray-700 cursor-pointer hover:border-blue-300 transition-colors"
        >
          <div>
            <p class="text-sm font-semibold text-gray-900 dark:text-white">
              Open Registration
            </p>
            <p class="text-xs text-gray-500 dark:text-gray-400">
              Teams can register without approval
            </p>
          </div>
          <div class="relative ml-4 shrink-0">
            <input type="checkbox" checked={{this.d.openRegistration}} {{on "change" (fn this.toggleBool "openRegistration")}} class="sr-only peer" />
            <div class="w-10 h-6 rounded-full bg-gray-200 dark:bg-gray-600 peer-checked:bg-blue-600 transition-colors"></div>
            <div class="absolute left-1 top-1 w-4 h-4 rounded-full bg-white shadow peer-checked:translate-x-4 transition-transform"></div>
          </div>
        </label>

        {{! Scoreboard }}
        <label
          class="flex items-center justify-between p-4 rounded-2xl border border-gray-200 dark:border-gray-700 cursor-pointer hover:border-blue-300 transition-colors"
        >
          <div>
            <p class="text-sm font-semibold text-gray-900 dark:text-white">
              Show Scoreboard
            </p>
            <p class="text-xs text-gray-500 dark:text-gray-400">
              Live scores and standings visible to all
            </p>
          </div>
          <div class="relative ml-4 shrink-0">
            <input type="checkbox" checked={{this.d.showScoreboard}} {{on "change" (fn this.toggleBool "showScoreboard")}} class="sr-only peer" />
            <div class="w-10 h-6 rounded-full bg-gray-200 dark:bg-gray-600 peer-checked:bg-blue-600 transition-colors"></div>
            <div class="absolute left-1 top-1 w-4 h-4 rounded-full bg-white shadow peer-checked:translate-x-4 transition-transform"></div>
          </div>
        </label>
      </div>

      {{! ══════════════════════════════════════════════════════════════════ }}
      {{! POLICY DOCUMENTS — tabbed                                          }}
      {{! ══════════════════════════════════════════════════════════════════ }}
      <div class="space-y-0">
        <p class="text-xs font-bold uppercase tracking-widest text-gray-400 mb-3">Policy Documents
          <span class="normal-case font-normal ml-1">(optional)</span>
        </p>

        {{! Tab bar }}
        <div class="flex border-b border-gray-200 dark:border-gray-700 overflow-x-auto">
          {{#each this.policyTabs as |tab|}}
            <button
              type="button"
              {{on "click" (fn this.setTab tab.key)}}
              class="flex items-center gap-1.5 px-4 py-2.5 text-sm font-medium whitespace-nowrap border-b-2 transition-colors
                {{if
                  (eq this.activePolicyTab tab.key)
                  'border-blue-500 text-blue-600 dark:text-blue-400'
                  'border-transparent text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200 hover:border-gray-300'
                }}"
            >
              {{lucideIcon tab.icon class="w-3.5 h-3.5 shrink-0"}}
              {{tab.label}}
              {{! Filled indicator dot }}
              {{#if (get this.d tab.key)}}
                <span class="w-1.5 h-1.5 rounded-full bg-blue-500 shrink-0"></span>
              {{/if}}
            </button>
          {{/each}}
        </div>

        {{! Active tab content }}
        {{#if this.activeTab}}
          <div class="border border-t-0 border-gray-200 dark:border-gray-700 rounded-b-2xl p-4 bg-white dark:bg-gray-800/40">
            <p class="text-xs text-gray-400 mb-2">
              {{this.activeTab.hint}}
            </p>
            <textarea
              rows="8"
              value={{get this.d this.activePolicyTab}}
              placeholder={{this.activeTab.placeholder}}
              {{on "input" (fn this.onInput this.activePolicyTab)}}
              class="w-full px-4 py-3 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-300 dark:placeholder-gray-600 focus:outline-none focus:ring-2 focus:ring-blue-500 resize-none font-mono leading-relaxed"
            ></textarea>
            <p class="text-xs text-gray-400 mt-1 text-right">
              {{this.activeTabCharCount}}
              characters
            </p>
          </div>
        {{/if}}
      </div>

      {{! ══════════════════════════════════════════════════════════════════ }}
      {{! ADDITIONAL NOTES                                                   }}
      {{! ══════════════════════════════════════════════════════════════════ }}
      <div>
        <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
          Additional Notes
        </label>
        <textarea
          rows="3"
          value={{this.d.notes}}
          placeholder="Any other information for participants…"
          {{on "input" (fn this.onInput "notes")}}
          class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 resize-none"
        ></textarea>
      </div>

      {{! ══════════════════════════════════════════════════════════════════ }}
      {{! SUBMIT ERROR                                                       }}
      {{! ══════════════════════════════════════════════════════════════════ }}
      {{#if @submitError}}
        <div class="p-4 rounded-xl bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-700">
          <p class="text-sm text-red-600 dark:text-red-400 flex items-center gap-2">
            {{lucideIcon "alert-circle" class="w-4 h-4 shrink-0"}}
            {{@submitError}}
          </p>
        </div>
      {{/if}}

      {{! ══════════════════════════════════════════════════════════════════ }}
      {{! ACTION BUTTONS                                                     }}
      {{! ══════════════════════════════════════════════════════════════════ }}
      <div class="flex flex-col sm:flex-row gap-3 pt-2">

        <button
          type="button"
          disabled={{@isSubmitting}}
          {{on "click" @onSaveDraft}}
          class="flex-1 flex items-center justify-center gap-2 px-6 py-3 text-sm font-semibold rounded-xl border-2 border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:border-blue-400 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {{lucideIcon "save" class="w-4 h-4"}}
          Save as Draft
        </button>

        <button
          type="button"
          disabled={{@isSubmitting}}
          {{on "click" @onPublish}}
          class="flex-1 flex items-center justify-center gap-2 px-6 py-3 text-sm font-semibold rounded-xl bg-blue-600 text-white hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {{#if @isSubmitting}}
            <div class="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
            Processing…
          {{else}}
            {{lucideIcon "send" class="w-4 h-4"}}
            {{if this.d.hasEntryFee "Continue to Payment" "Publish Tournament"}}
          {{/if}}
        </button>

      </div>

    </div>
  </template>
}
