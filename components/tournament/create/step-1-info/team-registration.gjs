import Component from '@glimmer/component';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import { eq } from 'ember-truth-helpers';
import lucideIcon from 'spordium/helpers/lucide-icon';
import PaymentMethodModal from './payment-method-modal';

const REGISTRATION_TYPES = [
  { value: 'publicRegistration', label: 'Open for All' },
  { value: 'preSelectedTeamsOnly', label: 'Pre-selected Teams Only' },
];

// ─────────────────────────────────────────────────────────────────────────────
// @arg {String}   registrationType    — tournament_team_registration_type
// @arg {Number}   registrationFee     — tournament_team_registration_fee
// @arg {String}   registrationDeadline— tournament_team_registration_end_date
// @arg {Array}    paymentMethods      — payment_receiving_details
// @arg {Function} onUpdate            — (key, value) => void  (API keys)
// @arg {Function} onQrUpload
// ─────────────────────────────────────────────────────────────────────────────
export default class TeamRegistration extends Component {
  @tracked isPaymentModalOpen = false;

  get registrationTypes() {
    return REGISTRATION_TYPES;
  }

  get isPublic() {
    return this.args.registrationType === 'publicRegistration';
  }
  get isPreSelected() {
    return this.args.registrationType === 'preSelectedTeamsOnly';
  }

  /** কতটি provider configure করা আছে — button label এ দেখানোর জন্য */
  get configuredPaymentCount() {
    return (this.args.paymentMethods ?? []).length;
  }

  // ── Registration type select ────────────────────────────────────────────────
  @action selectType(value) {
    this.args.onUpdate('tournament_team_registration_type', value);
    if (value === 'preSelectedTeamsOnly') {
      this.args.onUpdate('tournament_team_registration_end_date', null);
      this.args.onUpdate('payment_receiving_details', []);
    }
  }

  @action onFeeInput(e) {
    const val = parseFloat(e.target.value);
    this.args.onUpdate('tournament_team_registration_fee', isNaN(val) ? null : val);
  }

  @action onDeadlineInput(e) {
    this.args.onUpdate('tournament_team_registration_end_date', e.target.value);
  }

  // ── Payment modal ───────────────────────────────────────────────────────────

  @action openPaymentModal() {
    this.isPaymentModalOpen = true;
  }

  @action closePaymentModal() {
    this.isPaymentModalOpen = false;
  }

  /** PaymentMethodModal এর onSave — updated array আসে, parent কে দিই */
  @action onPaymentSave(updatedMethods) {
    this.args.onUpdate('payment_receiving_details', updatedMethods);
  }
  <template>
    <div class="space-y-4">

      {{! ── Registration Type buttons ────────────────────────────────────── }}
      <div>
        <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
          Team Registration
          <span class="text-red-500">*</span>
        </label>
        <div class="flex gap-3">
          {{#each this.registrationTypes as |rt|}}
            <button
              type="button"
              {{on "click" (fn this.selectType rt.value)}}
              class="flex-1 py-2.5 text-sm font-medium rounded-xl border-2 transition-all text-center
                {{if (eq @registrationType rt.value) 'border-blue-500 bg-blue-50 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300' 'border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300 hover:border-blue-300'}}"
            >
              {{rt.label}}
            </button>
          {{/each}}
        </div>
      </div>

      {{! ── Open for All fields ───────────────────────────────────────────── }}
      {{#if this.isPublic}}

        {{! Registration Fee }}
        <div>
          <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
            Registration Fee Per Team
          </label>
          <div class="flex items-center gap-3 max-w-xs">
            <span class="text-sm font-medium text-gray-500 dark:text-gray-400 shrink-0">BDT</span>
            <input
              type="number"
              value={{@registrationFee}}
              min="0"
              placeholder="e.g. 500"
              {{on "input" this.onFeeInput}}
              class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <p class="text-xs text-gray-400 mt-1">Enter 0 for free registration</p>
        </div>

        {{! Registration Deadline }}
        <div>
          <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
            Registration Deadline
            <span class="text-red-500">*</span>
          </label>
          <input
            type="date"
            value={{@registrationDeadline}}
            {{on "input" this.onDeadlineInput}}
            class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        {{! ── Payment Methods button ──────────────────────────────────────── }}
        <div>
          <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
            Payment Receiving Methods
          </label>

          <button
            type="button"
            {{on "click" this.openPaymentModal}}
            class="w-full flex items-center justify-between px-4 py-3 rounded-xl border-2 border-dashed transition-all
              {{if this.configuredPaymentCount 'border-blue-400 bg-blue-50 dark:bg-blue-900/20 text-blue-700 dark:text-blue-300' 'border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-800/50 text-gray-500 dark:text-gray-400 hover:border-blue-400'}}"
          >
            <div class="flex items-center gap-2">
              {{lucideIcon "credit-card" class="w-4 h-4"}}
              {{#if this.configuredPaymentCount}}
                <span class="text-sm font-medium">
                  {{this.configuredPaymentCount}}
                  {{if (eq this.configuredPaymentCount 1) "method" "methods"}}
                  configured
                </span>
              {{else}}
                <span class="text-sm">Configure payment methods</span>
              {{/if}}
            </div>
            {{lucideIcon "chevron-right" class="w-4 h-4"}}
          </button>

          {{! Configured providers summary }}
          {{#if this.configuredPaymentCount}}
            <div class="flex flex-wrap gap-2 mt-2">
              {{#each @paymentMethods as |pm|}}
                <span class="inline-flex items-center gap-1 px-2.5 py-1 text-xs font-medium rounded-lg bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400">
                  {{lucideIcon "check-circle" class="w-3 h-3"}}
                  {{pm.name}}
                </span>
              {{/each}}
            </div>
          {{/if}}
        </div>

      {{/if}}

      {{! ── Pre-selected Teams Only — fee only ────────────────────────────── }}
      {{#if this.isPreSelected}}
        <div>
          <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
            Registration Fee Per Team
            <span class="text-red-500">*</span>
          </label>
          <div class="flex items-center gap-3 max-w-xs">
            <span class="text-sm font-medium text-gray-500 dark:text-gray-400 shrink-0">BDT</span>
            <input
              type="number"
              value={{@registrationFee}}
              min="0"
              placeholder="e.g. 500"
              {{on "input" this.onFeeInput}}
              class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <p class="text-xs text-gray-400 mt-1">Enter 0 for free registration</p>
        </div>
      {{/if}}

    </div>

    {{! ── Payment Method Modal (rendered outside the form flow) ───────────── }}
    <PaymentMethodModal @isOpen={{this.isPaymentModalOpen}} @paymentMethods={{@paymentMethods}} @onClose={{this.closePaymentModal}} @onSave={{this.onPaymentSave}} @onQrUpload={{@onQrUpload}} />
  </template>
}
