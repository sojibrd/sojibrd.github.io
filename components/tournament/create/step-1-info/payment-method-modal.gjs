import Component from '@glimmer/component';
import { on } from '@ember/modifier';
import { fn, array, hash } from '@ember/helper';
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import { eq } from 'ember-truth-helpers';
import lucideIcon from 'spordium/helpers/lucide-icon';
// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const PROVIDERS = [
  { key: 'bkash', label: 'bKash', logo: '/images/gateway/bkash.png' },
  { key: 'nagad', label: 'নগদ', logo: '/images/gateway/nagad.png' },
  { key: 'sslcommerz', label: 'SSLCommerz', logo: '/images/gateway/sslcommerce.png' },
];

const ACTION_TYPES = [
  { value: 'makePayment', label: 'Make payment' },
  { value: 'sendMoney', label: 'Send money' },
];

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
// payment-method-modal.gjs এ এটা add করো (class এর বাইরে)
function dataFor(providerMap, key) {
  return providerMap[key] ?? { name: key };
}

/** paymentMethods array → { bkash: {...}, nagad: {...}, sslcommerz: {...} } */
function arrayToMap(arr = []) {
  return Object.fromEntries(arr.map((p) => [p.name, p]));
}

/** map → array (for onUpdate) */
function mapToArray(map = {}) {
  return Object.values(map).filter((p) => p.name);
}

// ─────────────────────────────────────────────────────────────────────────────
// PaymentProviderCard
//
// @arg {String}   providerKey        — 'bkash' | 'nagad' | 'sslcommerz'
// @arg {String}   providerLabel      — display name
// @arg {String}   providerLogo       — image src
// @arg {Object}   data               — { name, holder, action_type, qr_image }
// @arg {Boolean}  isSelected         — whether this provider tab is active
// @arg {Function} onSelect           — () => void
// @arg {Function} onFieldUpdate      — (field, value) => void
// @arg {Function} onQrUpload         — (file) => Promise<{ previewUrl, objectToken }>
// ─────────────────────────────────────────────────────────────────────────────
class PaymentProviderCard extends Component {
  @tracked qrUploading = false;
  @tracked qrError = null;

  get data() {
    return this.args.data ?? {};
  }

  get actionType() {
    return this.data.action_type ?? 'makePayment';
  }

  get qrPreview() {
    return this.data.qr_image?.previewUrl ?? null;
  }

  get holderLabel() {
    const map = { bkash: 'bKash', nagad: 'Nagad', sslcommerz: 'SSLCommerz' };
    return map[this.args.providerKey] ?? this.args.providerLabel;
  }

  @action
  selectActionType(value) {
    this.args.onFieldUpdate('action_type', value);
  }

  @action
  onHolderInput(e) {
    this.args.onFieldUpdate('holder', e.target.value);
  }

  @action
  async onQrChange(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    this.qrUploading = true;
    this.qrError = null;
    try {
      const result = await this.args.onQrUpload(file);
      // result: { previewUrl, objectToken }
      this.args.onFieldUpdate('qr_image', {
        previewUrl: result.previewUrl,
        objectToken: result.objectToken,
      });
    } catch {
      this.qrError = 'QR upload failed. Please try again.';
    } finally {
      this.qrUploading = false;
    }
  }

  @action
  removeQr() {
    this.args.onFieldUpdate('qr_image', null);
  }

  <template>
    <div class="rounded-2xl border-2 transition-all overflow-hidden {{if @isSelected 'border-blue-500 shadow-md' 'border-gray-200 dark:border-gray-700'}}">
      {{! ── Provider header / tab ─────────────────────────────────────────── }}
      <button type="button" {{on "click" @onSelect}} class="w-full flex items-center gap-3 px-4 py-3 transition-colors {{if @isSelected 'bg-blue-50 dark:bg-blue-900/20' 'bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700/50'}}">
        <img src={{@providerLogo}} alt={{@providerLabel}} class="h-8 w-auto object-contain" />
        <span class="text-sm font-semibold text-gray-800 dark:text-white">{{@providerLabel}}</span>
        <span class="ml-auto">
          {{#if @isSelected}}
            {{lucideIcon "chevron-up" class="w-4 h-4 text-blue-500"}}
          {{else}}
            {{lucideIcon "chevron-down" class="w-4 h-4 text-gray-400"}}
          {{/if}}
        </span>
      </button>

      {{! ── Expanded body ──────────────────────────────────────────────────── }}
      {{#if @isSelected}}
        <div class="px-4 pb-4 space-y-4 bg-white dark:bg-gray-800 border-t border-gray-100 dark:border-gray-700">

          {{! Action Type: Make payment / Send money }}
          <div class="flex gap-3 pt-4">
            {{#each (array (hash value="makePayment" label="Make payment") (hash value="sendMoney" label="Send money")) as |at|}}
              <button
                type="button"
                {{on "click" (fn this.selectActionType at.value)}}
                class="flex-1 py-2 text-sm font-medium rounded-xl border-2 transition-all
                  {{if (eq this.actionType at.value) 'border-green-500 bg-green-500 text-white' 'border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-600 dark:text-gray-300 hover:border-green-300'}}"
              >
                {{at.label}}
              </button>
            {{/each}}
          </div>

          {{! Phone Number }}
          <div>
            <label class="block text-xs font-semibold text-gray-500 dark:text-gray-400 mb-1">
              Phone number
            </label>
            <input
              type="tel"
              value={{this.data.holder}}
              placeholder="01XXXXXXXXX"
              maxlength="20"
              {{on "input" this.onHolderInput}}
              class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          {{! QR Code }}
          <div>
            <label class="block text-xs font-semibold text-gray-500 dark:text-gray-400 mb-1">
              Upload QR Code
            </label>

            {{#if this.qrPreview}}
              <div class="flex items-center gap-3">
                <img src={{this.qrPreview}} alt="QR Code" class="w-20 h-20 rounded-xl object-contain border border-gray-200 dark:border-gray-700 bg-white p-1" />
                <div class="flex flex-col gap-2">
                  <label
                    class="cursor-pointer inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-blue-600 dark:text-blue-400 border border-blue-300 dark:border-blue-600 rounded-lg hover:bg-blue-50 dark:hover:bg-blue-900/20 transition-colors"
                  >
                    {{lucideIcon "upload" class="w-3.5 h-3.5"}}
                    Replace
                    <input type="file" accept="image/*" class="hidden" {{on "change" this.onQrChange}} />
                  </label>
                  <button
                    type="button"
                    {{on "click" this.removeQr}}
                    class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-red-500 border border-red-200 dark:border-red-700 rounded-lg hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors"
                  >
                    {{lucideIcon "x" class="w-3.5 h-3.5"}}
                    Remove
                  </button>
                </div>
              </div>
            {{else}}
              <label class="block cursor-pointer">
                <div class="flex items-center justify-center gap-2 py-3 px-4 rounded-xl border-2 border-dashed border-gray-300 dark:border-gray-600 hover:border-blue-400 transition-colors bg-gray-50 dark:bg-gray-800/50">
                  {{#if this.qrUploading}}
                    <div class="w-4 h-4 border-2 border-blue-500 border-t-transparent rounded-full animate-spin"></div>
                    <span class="text-sm text-gray-500">Uploading…</span>
                  {{else}}
                    {{lucideIcon "paperclip" class="w-4 h-4 text-gray-400"}}
                    <span class="text-sm text-gray-500 dark:text-gray-400">Upload QR Code Image</span>
                  {{/if}}
                </div>
                <input type="file" accept="image/*" class="hidden" {{on "change" this.onQrChange}} />
              </label>
            {{/if}}

            {{#if this.qrError}}
              <p class="text-xs text-red-500 mt-1">{{this.qrError}}</p>
            {{/if}}
          </div>

        </div>
      {{/if}}
    </div>
  </template>
}

// ─────────────────────────────────────────────────────────────────────────────
// PaymentMethodModal
//
// @arg {Array}    paymentMethods     — array of provider objects (API format)
// @arg {Boolean}  isOpen             — show/hide modal
// @arg {Function} onClose            — () => void
// @arg {Function} onSave             — (updatedArray) => void
// @arg {Function} onQrUpload         — (file) => Promise<{ previewUrl, objectToken }>
// ─────────────────────────────────────────────────────────────────────────────
export default class PaymentMethodModal extends Component {
  // local mutable copy — keyed by provider name
  @tracked providerMap = arrayToMap(this.args.paymentMethods);
  @tracked selectedKey = PROVIDERS[0].key;

  get providers() {
    return PROVIDERS;
  }

  @action
  selectProvider(key) {
    this.selectedKey = key;
  }

  /**
   * Update a single field inside a provider's data object.
   * Always keeps `name` intact.
   */
  @action
  updateField(providerKey, field, value) {
    const current = this.providerMap[providerKey] ?? { name: providerKey };
    this.providerMap = {
      ...this.providerMap,
      [providerKey]: { ...current, name: providerKey, [field]: value },
    };
  }

  @action
  save() {
    // Only include providers that have at least a holder number
    const result = mapToArray(this.providerMap).filter((p) => p.holder || p.qr_image);
    this.args.onSave(result);
    this.args.onClose();
  }

  @action
  close() {
    this.args.onClose();
  }

  <template>
    {{#if @isOpen}}
      {{! ── Backdrop ────────────────────────────────────────────────────────── }}
      <div class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm" role="dialog" aria-modal="true">
        {{! ── Modal box ─────────────────────────────────────────────────────── }}
        <div class="w-full max-w-md bg-white dark:bg-gray-900 rounded-2xl shadow-2xl flex flex-col max-h-[90vh]">

          {{! Header }}
          <div class="flex items-center justify-between px-5 py-4 border-b border-gray-100 dark:border-gray-800">
            <h2 class="text-base font-bold text-gray-900 dark:text-white">
              Choose Your Payment Receiving Method
            </h2>
            <button type="button" {{on "click" this.close}} class="p-1.5 rounded-lg text-gray-400 hover:text-gray-600 hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors">
              {{lucideIcon "x" class="w-4 h-4"}}
            </button>
          </div>

          {{! Scrollable body }}
          <div class="overflow-y-auto px-5 py-4 space-y-3 flex-1">
            {{#each this.providers as |provider|}}
              <PaymentProviderCard
                @providerKey={{provider.key}}
                @providerLabel={{provider.label}}
                @providerLogo={{provider.logo}}
                @data={{dataFor this.providerMap provider.key}}
                @isSelected={{eq this.selectedKey provider.key}}
                @onSelect={{fn this.selectProvider provider.key}}
                @onFieldUpdate={{fn this.updateField provider.key}}
                @onQrUpload={{@onQrUpload}}
              />
            {{/each}}
          </div>

          {{! Footer }}
          <div class="px-5 py-4 border-t border-gray-100 dark:border-gray-800">
            <button type="button" {{on "click" this.save}} class="w-full py-2.5 px-6 text-sm font-semibold rounded-xl bg-blue-600 hover:bg-blue-700 text-white transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2">
              Save
            </button>
          </div>

        </div>
      </div>
    {{/if}}
  </template>
}
