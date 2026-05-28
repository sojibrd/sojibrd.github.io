import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { service } from '@ember/service';
import PaymentMethodPicker from 'spordium/components/ui/payment-method-picker';
import lucideIcon from 'spordium/helpers/lucide-icon';
import { not } from 'ember-truth-helpers';

// ══════════════════════════════════════════════════════════════════════════════
// PaymentModal — fee summary popup + gateway selection
//
// @arg {boolean}  isOpen        — controls visibility
// @arg {Function} onClose       — close handler
// @arg {Object}   plan          — { label, amount, description }
// @arg {string}   tournamentId
// @arg {Function} onSuccess     — called after payment redirect initiated
// ══════════════════════════════════════════════════════════════════════════════
export default class TournamentPaymentModal extends Component {
  @service payment;

  @tracked selectedMethod = null;
  @tracked isProcessing = false;
  @tracked error = null;

  get plan() {
    return this.args.plan ?? {};
  }
  get canProceed() {
    return !!this.selectedMethod && !this.isProcessing;
  }

  @action
  selectMethod(method) {
    this.selectedMethod = method;
    this.error = null;
  }

  @action
  async proceed() {
    if (!this.canProceed) return;

    this.isProcessing = true;
    this.error = null;

    try {
      const res = await this.payment.initiateTournamentPayment({
        tournamentId: this.args.tournamentId,
        method: this.selectedMethod,
        planId: this.plan.id ?? null,
      });

      if (res?.payment_url) {
        window.location.href = res.payment_url;
      } else {
        throw new Error('No payment URL received from gateway.');
      }

      this.args.onSuccess?.();
    } catch (err) {
      this.error = err?.message ?? 'Payment failed. Please try again.';
    } finally {
      this.isProcessing = false;
    }
  }

  <template>
    {{#if @isOpen}}
      {{! Backdrop }}
      <div
        class="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-end sm:items-center justify-center p-4"
        {{on "click" @onClose}}
      >
        {{! Modal panel }}
        <div
          class="w-full max-w-md bg-white dark:bg-gray-900 rounded-3xl shadow-2xl overflow-hidden"
          {{on "click" (fn (mut this) this)}}
        >
          {{! Header }}
          <div
            class="flex items-start justify-between p-6 border-b border-gray-100 dark:border-gray-700"
          >
            <div>
              <h2
                class="text-lg font-extrabold text-gray-900 dark:text-white flex items-center gap-2"
              >
                {{lucideIcon "credit-card" class="w-5 h-5 text-blue-600"}}
                Payment
              </h2>
              <p class="text-sm text-gray-500 dark:text-gray-400 mt-0.5">
                {{this.plan.description}}
              </p>
            </div>
            <button
              type="button"
              {{on "click" @onClose}}
              class="p-2 rounded-xl hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
            >
              {{lucideIcon "x" class="w-4 h-4 text-gray-500"}}
            </button>
          </div>

          <div class="p-6 space-y-5">
            {{! Amount summary }}
            <div
              class="flex items-center justify-between p-4 rounded-2xl bg-blue-50 dark:bg-blue-900/20 border border-blue-100 dark:border-blue-800"
            >
              <div>
                <p
                  class="text-xs text-blue-600 dark:text-blue-400 font-semibold uppercase tracking-wide"
                >
                  {{this.plan.label}}
                </p>
                <p
                  class="text-2xl font-extrabold text-blue-700 dark:text-blue-300 mt-0.5"
                >
                  ৳{{this.plan.amount}}
                </p>
              </div>
              {{lucideIcon "trophy" class="w-8 h-8 text-blue-400"}}
            </div>

            {{! Gateway selection }}
            <PaymentMethodPicker
              @selected={{this.selectedMethod}}
              @onChange={{this.selectMethod}}
              @disabled={{this.isProcessing}}
            />

            {{! Error }}
            {{#if this.error}}
              <p class="text-sm text-red-500 flex items-center gap-2">
                {{lucideIcon "alert-circle" class="w-4 h-4 shrink-0"}}
                {{this.error}}
              </p>
            {{/if}}

            {{! Proceed button }}
            <button
              type="button"
              disabled={{not this.canProceed}}
              {{on "click" this.proceed}}
              class="w-full flex items-center justify-center gap-2 px-6 py-3.5 text-sm font-bold rounded-2xl bg-blue-600 text-white hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {{#if this.isProcessing}}
                <div
                  class="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"
                ></div>
                Redirecting to gateway…
              {{else}}
                {{lucideIcon "lock" class="w-4 h-4"}}
                Pay Securely
              {{/if}}
            </button>

            <p class="text-center text-xs text-gray-400">
              You will be redirected to a secure payment page
            </p>
          </div>
        </div>
      </div>
    {{/if}}
  </template>
}
