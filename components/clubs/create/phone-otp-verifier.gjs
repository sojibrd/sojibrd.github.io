/**
 * PhoneOtpVerifier
 * ──────────────────────────────────────────────────────────────────────────────
 * A phone input row (with +880 BD prefix badge) and a built-in OTP flow:
 *
 *   1. User types a phone number → "Verify" button appears
 *   2. User clicks Verify → parent sends OTP → OTP row + optional hint appear
 *   3. User enters 6-digit OTP → clicks Confirm → parent verifies
 *   4. On success the input is disabled and a green "Verified" badge shows
 *
 * All network logic lives in the parent. This component is purely presentational.
 *
 * @arg {string}   phone          - Controlled phone field value (digits only, no country code).
 * @arg {boolean}  verified       - When true, input is locked & badge shows.
 * @arg {boolean}  otpSent        - When true, the OTP input row is shown.
 * @arg {string}   otpValue       - Current OTP input value.
 * @arg {string}   [otpHint]      - Dev-mode hint showing the OTP plaintext.
 * @arg {string}   [otpError]     - Error from the OTP send / verify API.
 * @arg {string}   [error]        - Validation error for the phone field itself.
 * @arg {boolean}  isSending      - Disables & animates the Verify/Resend button.
 * @arg {boolean}  isVerifying    - Disables & animates the Confirm button.
 * @arg {boolean}  [required]     - Shows asterisk in the label.
 * @arg {string}   [label]        - Label text. Defaults to "Phone Number".
 * @arg {string}   [placeholder]  - Input placeholder. Defaults to "Phone number".
 * @arg {Function} onPhoneInput   - Called with the native `input` event on the phone field.
 * @arg {Function} onSendOtp      - Called (no args) when Verify / Resend is clicked.
 * @arg {Function} onVerifyOtp    - Called (no args) when Confirm is clicked.
 * @arg {Function} onOtpInput     - Called with the native `input` event on the OTP field.
 *
 * Usage:
 *   <PhoneOtpVerifier
 *     @label="Facilities Cell Phone"
 *     @phone={{this.facilityPhone}}
 *     @verified={{this.phoneVerified}}
 *     @otpSent={{this.phoneOtpSent}}
 *     @otpValue={{this.phoneOtpValue}}
 *     @otpHint={{this.phoneOtpHint}}
 *     @otpError={{this.phoneOtpError}}
 *     @error={{this.errors.facilityPhone}}
 *     @isSending={{this.isSendingPhoneOtp}}
 *     @isVerifying={{this.isVerifyingPhoneOtp}}
 *     @required={{true}}
 *     @onPhoneInput={{this.onPhoneInput}}
 *     @onSendOtp={{this.sendPhoneOtp}}
 *     @onVerifyOtp={{this.verifyPhoneOtp}}
 *     @onOtpInput={{this.onPhoneOtpInput}}
 *   />
 */
import { on } from '@ember/modifier';
import FormFieldError from './form-field-error';
import lucideIcon from 'spordium/helpers/lucide-icon';

<template>
  <div>
    <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
      {{if @label @label "Phone Number"}}
      {{#if @required}}<span class="text-rose-500"> *</span>{{/if}}
    </label>

    {{! Phone input + badge row }}
    <div class="flex gap-2">
      {{! +880 prefix badge }}
      <div class="shrink-0 flex items-center gap-2 px-3 py-3 rounded-xl
                  border border-gray-200 dark:border-gray-700
                  bg-gray-50 dark:bg-gray-800
                  text-gray-700 dark:text-gray-300 text-sm font-semibold select-none">
        <span class="text-base">🇧🇩</span>
        <span>+880</span>
      </div>

      <input
        type="tel"
        placeholder={{if @placeholder @placeholder "Phone number"}}
        value={{@phone}}
        disabled={{@verified}}
        {{on "input" @onPhoneInput}}
        class="flex-1 px-4 py-3 rounded-xl border transition-all duration-200
               {{if @error
                 'border-rose-400 dark:border-rose-500 bg-rose-50 dark:bg-rose-900/10'
                 'border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-800
                  focus:border-indigo-400 dark:focus:border-indigo-500'}}
               {{if @verified 'opacity-60 cursor-not-allowed' ''}}
               text-gray-900 dark:text-gray-100
               placeholder:text-gray-400 dark:placeholder:text-gray-500
               focus:outline-none focus:ring-2 focus:ring-indigo-400/30 dark:focus:ring-indigo-500/30"
      />

      {{#if @verified}}
        <span class="shrink-0 inline-flex items-center gap-1.5 px-4 py-3 rounded-xl
                     border-2 border-emerald-500 dark:border-emerald-400
                     bg-emerald-50 dark:bg-emerald-900/20
                     text-emerald-600 dark:text-emerald-400 text-sm font-semibold">
          {{lucideIcon "check-circle" size=14}}
          Verified
        </span>
      {{else}}
        <button
          type="button"
          disabled={{@isSending}}
          {{on "click" @onSendOtp}}
          class="shrink-0 inline-flex items-center gap-1.5 px-4 py-3 rounded-xl
                 border-2 border-indigo-500 dark:border-indigo-400
                 text-indigo-600 dark:text-indigo-400 text-sm font-semibold
                 hover:bg-indigo-50 dark:hover:bg-indigo-900/20
                 disabled:opacity-60 disabled:cursor-not-allowed
                 transition-all duration-200
                 focus:outline-none focus:ring-2 focus:ring-indigo-400 focus:ring-offset-1"
        >
          {{#if @isSending}}
            {{lucideIcon "loader" size=14 class="animate-spin"}}
            Sending…
          {{else}}
            {{if @otpSent "Resend" "Verify"}}
          {{/if}}
        </button>
      {{/if}}
    </div>

    {{! Dev-mode OTP hint }}
    {{#if @otpHint}}
      <div class="mt-2 flex items-center gap-2 px-3 py-2 rounded-lg
                  border border-amber-500/30 bg-amber-500/10">
        {{lucideIcon "alert-triangle" size=14 class="text-amber-400 shrink-0"}}
        <p class="text-xs text-amber-300 font-medium">
          Dev mode — OTP:
          <span class="font-bold tracking-widest text-amber-200 ml-1">{{@otpHint}}</span>
        </p>
      </div>
    {{/if}}

    {{! OTP entry row (shown after OTP is sent) }}
    {{#if @otpSent}}
      <div class="mt-3 flex gap-2 items-start">
        <div class="flex-1">
          <input
            type="text"
            placeholder="Enter OTP sent to your phone"
            value={{@otpValue}}
            maxlength="6"
            {{on "input" @onOtpInput}}
            class="w-full px-4 py-2.5 rounded-xl border transition-all duration-200
                   {{if @otpError
                     'border-rose-400 dark:border-rose-500 bg-rose-50 dark:bg-rose-900/10'
                     'border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-800
                      focus:border-indigo-400 dark:focus:border-indigo-500'}}
                   text-gray-900 dark:text-gray-100
                   placeholder:text-gray-400 dark:placeholder:text-gray-500
                   focus:outline-none focus:ring-2 focus:ring-indigo-400/30 dark:focus:ring-indigo-500/30
                   text-sm tracking-widest"
          />
        </div>
        <button
          type="button"
          disabled={{@isVerifying}}
          {{on "click" @onVerifyOtp}}
          class="shrink-0 inline-flex items-center gap-1.5 px-4 py-2.5 rounded-xl
                 bg-indigo-600 hover:bg-indigo-700 dark:bg-indigo-500 dark:hover:bg-indigo-600
                 text-white text-sm font-semibold
                 disabled:opacity-60 disabled:cursor-not-allowed
                 transition-all duration-200
                 focus:outline-none focus:ring-2 focus:ring-indigo-400 focus:ring-offset-1"
        >
          {{#if @isVerifying}}
            {{lucideIcon "loader" size=14 class="animate-spin"}}
            Confirming…
          {{else}}
            Confirm
          {{/if}}
        </button>
      </div>

      {{#if @otpError}}
        <p class="mt-1 text-xs text-rose-500 flex items-center gap-1">
          {{lucideIcon "alert-circle" size=12}}
          {{@otpError}}
        </p>
      {{/if}}
    {{/if}}

    <FormFieldError @error={{@error}} />
  </div>
</template>
