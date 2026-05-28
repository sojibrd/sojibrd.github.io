/**
 * PaymentMethodPicker
 * ─────────────────────────────────────────────────────────────────────────────
 * Universal payment method selector for the Spordium platform.
 *
 * @arg {string|null}  selected   — Currently selected method key (e.g. 'bkash')
 * @arg {Function}     onChange   — Called with method key string on selection
 * @arg {boolean}      disabled   — Disables all options when true (default: false)
 * @arg {string}       label      — Optional section label override
 *
 * Method keys:
 *   'bkash'       — bKash mobile banking (Bangladesh)
 *   'nagad'       — Nagad mobile banking (Bangladesh)
 *   'visa'        — Visa credit / debit card
 *   'mastercard'  — Mastercard credit / debit card
 *
 * Usage:
 *   import PaymentMethodPicker from 'spordium/components/ui/payment-method-picker';
 *
 *   <PaymentMethodPicker
 *     @selected={{this.selectedPaymentMethod}}
 *     @onChange={{this.onPaymentMethodChange}}
 *   />
 *
 *   With disabled state:
 *   <PaymentMethodPicker
 *     @selected={{this.method}}
 *     @onChange={{this.setMethod}}
 *     @disabled={{this.isSubmitting}}
 *   />
 * ─────────────────────────────────────────────────────────────────────────────
 */
import Component from '@glimmer/component';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { eq } from 'ember-truth-helpers';

const METHODS = [
  {
    key:        'bkash',
    label:      'bKash',
    subtitle:   'Mobile Banking',
    // Source: Wikimedia Commons — stable public CDN
    logo:       '/bkash.svg',
    logoBg:     'bg-white',
    baseCard:   'bg-pink-50 dark:bg-pink-950/30 border-pink-200 dark:border-pink-700/50',
    selCard:    'bg-pink-100 dark:bg-pink-950/60 border-pink-500 dark:border-pink-400 shadow-lg shadow-pink-500/20',
    labelColor: 'text-pink-700 dark:text-pink-300',
    subColor:   'text-pink-500 dark:text-pink-400',
    check:      'bg-pink-500',
  },
  {
    key:        'nagad',
    label:      'Nagad',
    subtitle:   'Mobile Banking',
    // Source: Wikimedia Commons — stable public CDN
    logo:       '/nagad.svg',
    logoBg:     'bg-white',
    baseCard:   'bg-orange-50 dark:bg-orange-950/30 border-orange-200 dark:border-orange-700/50',
    selCard:    'bg-orange-100 dark:bg-orange-950/60 border-orange-500 dark:border-orange-400 shadow-lg shadow-orange-500/20',
    labelColor: 'text-orange-700 dark:text-orange-300',
    subColor:   'text-orange-500 dark:text-orange-400',
    check:      'bg-orange-500',
  },
  {
    key:        'visa',
    label:      'Visa',
    subtitle:   'Credit / Debit',
    // Source: Wikimedia Commons — stable public CDN
    logo:       '/visa.svg',
    logoBg:     'bg-[#1A1F71]',
    baseCard:   'bg-blue-50 dark:bg-blue-950/30 border-blue-200 dark:border-blue-700/50',
    selCard:    'bg-blue-100 dark:bg-blue-950/60 border-blue-500 dark:border-blue-400 shadow-lg shadow-blue-500/20',
    labelColor: 'text-blue-700 dark:text-blue-300',
    subColor:   'text-blue-500 dark:text-blue-400',
    check:      'bg-blue-500',
  },
  {
    key:        'mastercard',
    label:      'Mastercard',
    subtitle:   'Credit / Debit',
    // Source: Wikimedia Commons — stable public CDN (two-circle mark, 2019 version)
    logo:       'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a4/Mastercard_2019_logo.svg/200px-Mastercard_2019_logo.svg.png',
    logoBg:     'bg-[#252525]',
    baseCard:   'bg-red-50 dark:bg-red-950/30 border-red-200 dark:border-red-700/50',
    selCard:    'bg-red-50 dark:bg-red-950/60 border-red-500 dark:border-red-400 shadow-lg shadow-red-500/20',
    labelColor: 'text-red-700 dark:text-red-300',
    subColor:   'text-red-500 dark:text-red-400',
    check:      'bg-red-500',
  },
];

export default class PaymentMethodPicker extends Component {
  get methods() { return METHODS; }

  get label() { return this.args.label ?? 'Payment Method'; }

  <template>
    <div>
      <p class="text-[10px] font-bold uppercase tracking-widest text-gray-400 dark:text-gray-500 mb-2.5">
        {{this.label}}
      </p>

      <div class="grid grid-cols-2 gap-2">
        {{#each this.methods as |method|}}
          <button
            type="button"
            disabled={{@disabled}}
            {{on "click" (fn @onChange method.key)}}
            class="relative flex items-center gap-2.5 px-3 py-2.5 rounded-2xl border-2
                   transition-all duration-150 text-left
                   disabled:opacity-50 disabled:cursor-not-allowed
                   {{if (eq @selected method.key) method.selCard method.baseCard}}"
          >
            {{! Brand logo box }}
            <div class="shrink-0 w-10 h-10 rounded-xl flex items-center justify-center
                        shadow-sm overflow-hidden {{method.logoBg}}">
              <img
                src={{method.logo}}
                alt={{method.label}}
                class="w-8 h-8 object-contain"
                loading="lazy"
              />
            </div>

            {{! Method name }}
            <div class="min-w-0 flex-1">
              <p class="text-xs font-extrabold leading-tight truncate {{method.labelColor}}">
                {{method.label}}
              </p>
              <p class="text-[10px] font-medium leading-tight {{method.subColor}}">
                {{method.subtitle}}
              </p>
            </div>

            {{! Selected checkmark }}
            {{#if (eq @selected method.key)}}
              <div class="absolute top-1.5 right-1.5 w-4 h-4 rounded-full flex items-center justify-center {{method.check}}">
                <svg class="w-2.5 h-2.5 text-white" viewBox="0 0 24 24" fill="none"
                     stroke="currentColor" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round">
                  <polyline points="20 6 9 17 4 12"/>
                </svg>
              </div>
            {{/if}}
          </button>
        {{/each}}
      </div>
    </div>
  </template>
}
