import Component from '@glimmer/component';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import { eq } from 'ember-truth-helpers';
import lucideIcon from 'spordium/helpers/lucide-icon';

// ─────────────────────────────────────────────────────────────────────────────
const PROVIDERS = [
  { key: 'bkash', label: 'bKash' },
  { key: 'nagad', label: 'Nagad' },
  { key: 'sslcommerz', label: 'SSLCommerz' },
];

const PAYMENT_MODES = [
  { value: 'makePayment', label: 'Make payment' },
  { value: 'sendMoney', label: 'Send money' },
];

// ─────────────────────────────────────────────────────────────────────────────
// PaymentMethod
//
// @arg {Object}   paymentDetails    — {
//                                       provider: 'bkash' | 'nagad' | 'sslcommerz',
//                                       mode: 'makePayment' | 'sendMoney',
//                                       phone: String,
//                                       qrPreview: String,
//                                       qrToken: String,
//                                     }
// @arg {Function} onUpdate          — (paymentDetails: Object) => void
// @arg {Function} onQrUpload        — (file) => Promise<{ previewUrl, objectToken }>
// @arg {Function} onSave            — () => void   (Save button)
// ─────────────────────────────────────────────────────────────────────────────
export default class PaymentMethod extends Component {
  @tracked qrUploading = false;
  @tracked qrError = null;

  get providers() {
    return PROVIDERS;
  }
  get modes() {
    return PAYMENT_MODES;
  }
  get d() {
    return this.args.paymentDetails ?? {};
  }

  get selectedProvider() {
    return this.d.provider ?? 'bkash';
  }
  get selectedMode() {
    return this.d.mode ?? 'makePayment';
  }
  get phone() {
    return this.d.phone ?? '';
  }
  get qrPreview() {
    return this.d.qrPreview ?? null;
  }

  get providerLabel() {
    return PROVIDERS.find((p) => p.key === this.selectedProvider)?.label ?? '';
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  #patch(patch) {
    this.args.onUpdate({ ...this.d, ...patch });
  }

  // ── actions ───────────────────────────────────────────────────────────────

  @action selectProvider(key) {
    this.#patch({ provider: key });
  }
  @action selectMode(value) {
    this.#patch({ mode: value });
  }

  @action onPhoneInput(e) {
    this.#patch({ phone: e.target.value });
  }

  @action removeQr() {
    this.#patch({ qrPreview: null, qrToken: null });
  }

  @action async onQrChange(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    this.qrUploading = true;
    this.qrError = null;
    try {
      await this.args.onQrUpload(file);
    } catch {
      this.qrError = 'Upload failed. Please try again.';
    } finally {
      this.qrUploading = false;
    }
  }

  <template>
    <div class="space-y-5">

      {{! ── Title ──────────────────────────────────────────────────────── }}
      <h3 class="text-base font-bold text-gray-900 dark:text-white text-center">
        Choose Your Payment Receiving Method
      </h3>

      {{! ── Provider logos ──────────────────────────────────────────────── }}
      <div class="flex gap-3">
        {{#each this.providers as |p|}}
          <button
            type="button"
            {{on "click" (fn this.selectProvider p.key)}}
            class="flex-1 h-14 flex items-center justify-center rounded-xl border-2 transition-all overflow-hidden
              {{if (eq this.selectedProvider p.key) 'border-green-500 bg-white dark:bg-gray-800' 'border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 hover:border-gray-300'}}"
          >
            {{#if (eq p.key "bkash")}}
              {{! bKash logo text }}
              <span class="text-sm font-bold" style="color: #E2136E;">bKash</span>
            {{else if (eq p.key "nagad")}}
              <span class="text-sm font-bold" style="color: #F05A28;">নগদ</span>
            {{else}}
              <span class="text-xs font-bold tracking-tight" style="color: #1B3A6B;">SSLCOMMERZ</span>
            {{/if}}
          </button>
        {{/each}}
      </div>

      {{! ── Make payment / Send money toggle ───────────────────────────── }}
      <div class="flex rounded-xl overflow-hidden border border-gray-200 dark:border-gray-600">
        {{#each this.modes as |m|}}
          <button
            type="button"
            {{on "click" (fn this.selectMode m.value)}}
            class="flex-1 py-2.5 text-sm font-medium transition-all {{if (eq this.selectedMode m.value) 'bg-green-500 text-white' 'bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700'}}"
          >
            {{m.label}}
          </button>
        {{/each}}
      </div>

      {{! ── Phone number ─────────────────────────────────────────────────── }}
      <div class="flex items-start gap-4">
        <label class="shrink-0 text-sm font-semibold text-gray-700 dark:text-gray-300 mt-2.5">
          Enter
          {{this.providerLabel}}
          number
        </label>
        <div class="flex-1">
          <p class="text-xs text-gray-400 mb-1">Phone number</p>
          <input
            type="tel"
            value={{this.phone}}
            placeholder="01XXXXXXXXX"
            maxlength="20"
            {{on "input" this.onPhoneInput}}
            class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
      </div>

      {{! ── QR Code ─────────────────────────────────────────────────────── }}
      <div class="flex items-start gap-4">
        <label class="shrink-0 text-sm font-semibold text-gray-700 dark:text-gray-300 mt-2.5">
          Upload QR Code
        </label>
        <div class="flex-1 space-y-3">

          {{! Upload button }}
          <label class="cursor-pointer block">
            <div class="flex items-center justify-center gap-2 py-2.5 px-4 rounded-xl bg-gray-800 dark:bg-gray-700 hover:bg-gray-700 dark:hover:bg-gray-600 transition-colors">
              {{#if this.qrUploading}}
                <div class="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                <span class="text-sm font-medium text-white">Uploading…</span>
              {{else}}
                {{lucideIcon "paperclip" class="w-4 h-4 text-white"}}
                <span class="text-sm font-medium text-white">Upload Qr Code Image</span>
              {{/if}}
            </div>
            <input type="file" accept="image/*" class="hidden" {{on "change" this.onQrChange}} />
          </label>

          {{! QR preview + remove }}
          {{#if this.qrPreview}}
            <div class="relative inline-block">
              <img src={{this.qrPreview}} alt="QR Code" class="w-36 h-36 object-contain rounded-xl border border-gray-200 dark:border-gray-700 bg-white p-1" />
              <button
                type="button"
                {{on "click" this.removeQr}}
                class="absolute -top-2 -right-2 w-6 h-6 flex items-center justify-center rounded-full bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-600 text-gray-500 hover:text-red-500 transition-colors shadow-sm"
                aria-label="Remove QR"
              >
                {{lucideIcon "x" class="w-3.5 h-3.5"}}
              </button>
            </div>
          {{/if}}

          {{#if this.qrError}}
            <p class="text-xs text-red-500">{{this.qrError}}</p>
          {{/if}}

        </div>
      </div>

      {{! ── Save button ──────────────────────────────────────────────────── }}
      <div class="flex justify-end pt-2">
        <button type="button" {{on "click" @onSave}} class="px-8 py-2.5 text-sm font-semibold text-white bg-gray-800 dark:bg-gray-700 hover:bg-gray-700 dark:hover:bg-gray-600 rounded-xl transition-colors">
          Save
        </button>
      </div>

    </div>
  </template>
}
