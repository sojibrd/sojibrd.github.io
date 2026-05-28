/**
 * EmailOtpVerifier
 * ──────────────────────────────────────────────────────────────────────────────
 * An email input row with a built-in one-time-password (OTP) verification flow:
 *
 *   1. User types an email → "Verify" button appears
 *   2. User clicks Verify → parent calls `sendEmailOtp` API → OTP row appears
 *   3. User enters 6-digit OTP → clicks Confirm → parent calls `verifyEmailOtp`
 *   4. On success the input is disabled and a green "Verified" badge replaces
 *      the Verify button.
 *
 * All network logic lives in the parent. This component is purely presentational.
 *
 * @arg {string}   email         - Controlled email field value.
 * @arg {boolean}  verified      - When true, email is locked & badge shows.
 * @arg {boolean}  otpSent       - When true, the OTP input row is shown.
 * @arg {string}   otpValue      - Current OTP input value.
 * @arg {string}   [otpError]    - Error from the OTP send / verify API.
 * @arg {string}   [error]       - Validation error for the email field itself.
 * @arg {boolean}  isSending     - Disables & animates the Verify/Resend button.
 * @arg {boolean}  isVerifying   - Disables & animates the Confirm button.
 * @arg {boolean}  [required]    - Shows asterisk in the label.
 * @arg {Function} onEmailInput  - Called with the native `input` event on the email field.
 * @arg {Function} onSendOtp     - Called (no args) when Verify / Resend is clicked.
 * @arg {Function} onVerifyOtp   - Called (no args) when Confirm is clicked.
 * @arg {Function} onOtpInput    - Called with the native `input` event on the OTP field.
 *
 * Usage:
 *   <EmailOtpVerifier
 *     @email={{this.clubEmail}}
 *     @verified={{this.emailVerified}}
 *     @otpSent={{this.emailOtpSent}}
 *     @otpValue={{this.otpValue}}
 *     @otpError={{this.otpError}}
 *     @error={{this.errors.clubEmail}}
 *     @isSending={{this.isSendingOtp}}
 *     @isVerifying={{this.isVerifyingOtp}}
 *     @required={{true}}
 *     @onEmailInput={{fn this.updateField 'clubEmail'}}
 *     @onSendOtp={{this.sendEmailOtp}}
 *     @onVerifyOtp={{this.verifyEmailOtp}}
 *     @onOtpInput={{this.updateOtp}}
 *   />
 */
import { on } from '@ember/modifier';
import FormFieldError from './form-field-error';

<template>
  <div>
    <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
      {{if @label @label "Email"}}
      {{#if @required}}<span class="text-rose-500"> *</span>{{/if}}
    </label>

    {{! Email + action button row }}
    <div class="flex gap-2">
      <input
        type="email"
        placeholder="club@example.com"
        value={{@email}}
        disabled={{@verified}}
        {{on "input" @onEmailInput}}
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
        {{! Verified badge }}
        <span class="shrink-0 inline-flex items-center gap-1.5 px-4 py-3 rounded-xl
                     border-2 border-emerald-500 dark:border-emerald-400
                     bg-emerald-50 dark:bg-emerald-900/20
                     text-emerald-600 dark:text-emerald-400 text-sm font-semibold">
          <svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor"
               stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/>
            <polyline points="22 4 12 14.01 9 11.01"/>
          </svg>
          Verified
        </span>
      {{else}}
        {{! Verify / Resend button }}
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
            <svg class="w-3.5 h-3.5 animate-spin" viewBox="0 0 24 24" fill="none"
                 stroke="currentColor" stroke-width="2.5" stroke-linecap="round">
              <path d="M21 12a9 9 0 1 1-6.219-8.56"/>
            </svg>
            Sending…
          {{else}}
            <svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                 stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
              <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/>
              <polyline points="22 4 12 14.01 9 11.01"/>
            </svg>
            {{if @otpSent "Resend" "Verify"}}
          {{/if}}
        </button>
      {{/if}}
    </div>

    {{! OTP input row (shown after OTP has been sent) }}
    {{#if @otpSent}}
      <div class="mt-3 flex gap-2 items-start">
        <div class="flex-1">
          <input
            type="text"
            placeholder="Enter OTP sent to your email"
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
            <svg class="w-3.5 h-3.5 animate-spin" viewBox="0 0 24 24" fill="none"
                 stroke="currentColor" stroke-width="2.5" stroke-linecap="round">
              <path d="M21 12a9 9 0 1 1-6.219-8.56"/>
            </svg>
            Confirming…
          {{else}}
            Confirm
          {{/if}}
        </button>
      </div>

      {{! OTP API error }}
      {{#if @otpError}}
        <p class="mt-1 text-xs text-rose-500 flex items-center gap-1">
          <svg class="w-3 h-3 shrink-0" viewBox="0 0 24 24" fill="currentColor">
            <path d="M12 2a10 10 0 1 0 0 20A10 10 0 0 0 12 2zm1 13H11v-2h2v2zm0-4H11V7h2v4z"/>
          </svg>
          {{@otpError}}
        </p>
      {{/if}}
    {{/if}}

    {{! Email validation error }}
    <FormFieldError @error={{@error}} />
  </div>
</template>
