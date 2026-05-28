import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { eq } from 'ember-truth-helpers';
import { service } from '@ember/service';
import { LinkTo } from '@ember/routing';
import PaymentModal from './payment-modal';
import lucideIcon from 'spordium/helpers/lucide-icon';
import { array, concat } from '@ember/helper';

const API_BASE = 'https://spordiumapi.adnanfoundation.com';

// ── Fallback static plans if API returns nothing ──────────────────────────────
const FALLBACK_PLANS = [
  {
    id: 'basic',
    label: 'Basic',
    amount: 500,
    description: 'Publish 1 tournament',
    features: ['1 tournament slot', 'Up to 16 teams', 'Basic support'],
    highlighted: false,
  },
  {
    id: 'standard',
    label: 'Standard',
    amount: 1200,
    description: 'Most popular plan',
    features: [
      '3 tournament slots',
      'Up to 32 teams',
      'Priority support',
      'Custom badge',
    ],
    highlighted: true,
  },
  {
    id: 'premium',
    label: 'Premium',
    amount: 2500,
    description: 'For professional organizers',
    features: [
      'Unlimited tournaments',
      'Unlimited teams',
      '24/7 support',
      'Featured listing',
      'Analytics dashboard',
    ],
    highlighted: false,
  },
];

// ══════════════════════════════════════════════════════════════════════════════
// PurchasePlan — payment plan selection page
//
// @arg {string} tournamentId — from query param
// ══════════════════════════════════════════════════════════════════════════════
export default class TournamentPurchasePlan extends Component {
  @service session;
  @service router;

  @tracked plans = [];
  @tracked isLoading = true;
  @tracked error = null;
  @tracked selectedPlan = null;
  @tracked showModal = false;

  constructor(owner, args) {
    super(owner, args);
    this.fetchPlans();
  }

  get tournamentId() {
    return this.args.tournamentId ?? null;
  }

  async fetchPlans() {
    this.isLoading = true;
    try {
      const res = await fetch(`${API_BASE}/tournament/plans/`, {
        headers: { Authorization: `Bearer ${this.session.token}` },
      });
      if (!res.ok) throw new Error();
      const json = await res.json();
      this.plans = json.data ?? json.results ?? json ?? [];
      if (!this.plans.length) this.plans = FALLBACK_PLANS;
    } catch {
      this.plans = FALLBACK_PLANS;
    } finally {
      this.isLoading = false;
    }
  }

  @action
  selectPlan(plan) {
    this.selectedPlan = plan;
    this.showModal = true;
  }

  @action
  closeModal() {
    this.showModal = false;
  }

  @action
  onPaymentSuccess() {
    // Redirect happens inside PaymentModal (gateway redirect)
  }

  <template>
    <div class="min-h-screen bg-gray-50 dark:bg-gray-950">

      {{! Header }}
      <div
        class="bg-white dark:bg-gray-900 border-b border-gray-200 dark:border-gray-700"
      >
        <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div class="flex items-center gap-3">
            <LinkTo
              @route="tournament.drafts"
              class="p-2 rounded-xl hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
            >
              {{lucideIcon "arrow-left" class="w-4 h-4 text-gray-500"}}
            </LinkTo>
            <div>
              <h1
                class="text-xl font-extrabold text-gray-900 dark:text-white flex items-center gap-2"
              >
                {{lucideIcon "zap" class="w-5 h-5 text-yellow-500"}}
                Choose a Plan
              </h1>
              <p class="text-xs text-gray-500 dark:text-gray-400 mt-0.5">
                Select a plan to publish your tournament
              </p>
            </div>
          </div>
        </div>
      </div>

      {{! Plans grid }}
      <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-10">

        {{#if this.isLoading}}
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-6">
            {{#each (array 1 2 3) as |i|}}
              <div
                class="bg-white dark:bg-gray-800 rounded-3xl p-6 animate-pulse"
              >
                <div
                  class="h-5 bg-gray-200 dark:bg-gray-700 rounded w-1/2 mb-3"
                ></div>
                <div
                  class="h-8 bg-gray-200 dark:bg-gray-700 rounded w-2/3 mb-4"
                ></div>
                <div class="space-y-2">
                  <div class="h-3 bg-gray-200 dark:bg-gray-700 rounded"></div>
                  <div
                    class="h-3 bg-gray-200 dark:bg-gray-700 rounded w-4/5"
                  ></div>
                  <div
                    class="h-3 bg-gray-200 dark:bg-gray-700 rounded w-3/5"
                  ></div>
                </div>
              </div>
            {{/each}}
          </div>

        {{else}}
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-6 items-stretch">
            {{#each this.plans as |plan|}}
              <div
                class="relative flex flex-col rounded-3xl border-2 overflow-hidden
                  {{if
                    plan.highlighted
                    'border-blue-500 bg-white dark:bg-gray-900 shadow-xl shadow-blue-500/20'
                    'border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900'
                  }}"
              >

                {{#if plan.highlighted}}
                  <div
                    class="bg-blue-600 text-white text-[10px] font-extrabold uppercase tracking-widest text-center py-1.5"
                  >
                    Most Popular
                  </div>
                {{/if}}

                <div class="p-6 flex flex-col flex-1">
                  {{! Plan name + price }}
                  <div class="mb-5">
                    <h3
                      class="text-base font-extrabold text-gray-900 dark:text-white"
                    >
                      {{plan.label}}
                    </h3>
                    <div class="flex items-end gap-1 mt-1">
                      <span
                        class="text-3xl font-black text-gray-900 dark:text-white"
                      >৳{{plan.amount}}</span>
                    </div>
                    <p
                      class="text-xs text-gray-500 dark:text-gray-400 mt-0.5"
                    >{{plan.description}}</p>
                  </div>

                  {{! Features }}
                  <ul class="space-y-2 flex-1 mb-6">
                    {{#each plan.features as |feat|}}
                      <li
                        class="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-300"
                      >
                        {{lucideIcon
                          "check"
                          class="w-4 h-4 text-green-500 shrink-0"
                        }}
                        {{feat}}
                      </li>
                    {{/each}}
                  </ul>

                  {{! CTA }}
                  <button
                    type="button"
                    {{on "click" (fn this.selectPlan plan)}}
                    class="w-full py-3 text-sm font-bold rounded-2xl transition-colors
                      {{if
                        plan.highlighted
                        'bg-blue-600 text-white hover:bg-blue-700'
                        'bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-white hover:bg-gray-200 dark:hover:bg-gray-700'
                      }}"
                  >
                    Choose
                    {{plan.label}}
                  </button>
                </div>
              </div>
            {{/each}}
          </div>
        {{/if}}

      </div>

      {{! Payment modal }}
      <PaymentModal
        @isOpen={{this.showModal}}
        @onClose={{this.closeModal}}
        @plan={{this.selectedPlan}}
        @tournamentId={{this.tournamentId}}
        @onSuccess={{this.onPaymentSuccess}}
      />

    </div>
  </template>
}
