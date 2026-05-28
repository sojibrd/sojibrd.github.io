import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { service } from '@ember/service';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { registerDestructor } from '@ember/destroyable';
import { eq, lte } from 'ember-truth-helpers';
import encryptPassword from 'spordium/utils/encrypt-password';
import config from 'spordium/config/environment';

const OTP_DURATION = 300;

export default class ForgotPasswordComponent extends Component {
  @service toast;

  // Step: 0 = enter contact, 1 = OTP verification, 2 = create new password
  @tracked step = 0;

  // Step 0
  @tracked contactType     = 'email';
  @tracked contactValue    = '';
  @tracked contactError    = '';
  @tracked isRequestingOtp = false;

  // Tokens from API
  @tracked otpToken      = null;
  @tracked verifiedToken = null;

  // OTP
  @tracked otp            = '';
  @tracked otpError       = '';
  @tracked isResending    = false;
  @tracked isVerifyingOtp = false;

  // Password reset
  @tracked newPassword         = '';
  @tracked confirmPassword     = '';
  @tracked showPassword        = false;
  @tracked showConfirmPassword = false;
  @tracked isResetting         = false;
  @tracked resetError          = '';

  // Timer
  @tracked timeLeft     = OTP_DURATION;
  @tracked timerExpired = false;
  #timerId = null;

  constructor(owner, args) {
    super(owner, args);
    if (args.email) this.contactValue = args.email;
    registerDestructor(this, () => this.#clearTimer());
  }

  get isContactValid() {
    const v = this.contactValue.trim();
    if (!v) return false;
    if (this.contactType === 'email') {
      return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v);
    }
    return v.length >= 7;
  }

  get timerDisplay() {
    const m = Math.floor(this.timeLeft / 60).toString().padStart(2, '0');
    const s = (this.timeLeft % 60).toString().padStart(2, '0');
    return `${m}:${s}`;
  }

  get timerProgress() {
    return `${Math.round((this.timeLeft / OTP_DURATION) * 100)}%`;
  }

  get passwordValidations() {
    return [
      {
        text: 'Minimum 6 characters',
        valid: this.newPassword.length >= 6,
        show: this.newPassword.length > 0,
      },
      {
        text: 'Passwords match',
        valid: this.newPassword === this.confirmPassword && this.confirmPassword.length > 0,
        show: this.confirmPassword.length > 0,
      },
    ];
  }

  get hasValidationErrors() {
    return this.passwordValidations.some((v) => v.show && !v.valid);
  }

  #clearTimer() {
    if (this.#timerId) { clearInterval(this.#timerId); this.#timerId = null; }
  }

  #startTimer() {
    this.#clearTimer();
    this.timeLeft     = OTP_DURATION;
    this.timerExpired = false;
    this.#timerId = setInterval(() => {
      this.timeLeft -= 1;
      if (this.timeLeft <= 0) { this.#clearTimer(); this.timerExpired = true; }
    }, 1000);
  }

  async #sendOtp() {
    const endpoint = this.contactType === 'email'
      ? '/auth_user/send-otp-verified-email/'
      : '/auth_user/reg-send-reset-OTP/';
    const payload = this.contactType === 'email'
      ? { email: this.contactValue.trim(),auth:true }
      : { user_phone: this.contactValue.trim(),auth:true };
    const res  = await fetch(`${config.APP.API_HOST}${endpoint}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body:    JSON.stringify(payload),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(data?.message || data?.detail || 'Failed to send OTP.');
    this.otpToken = data.token ?? null;
    this.#startTimer();
  }

  @action setContactType(type) {
    this.contactType  = type;
    this.contactValue = '';
    this.contactError = '';
  }

  @action updateContactValue(event) {
    this.contactValue = event.target.value;
    this.contactError = '';
  }

  @action async handleRequestOtp(event) {
    event.preventDefault();
    if (!this.contactValue.trim()) {
      this.contactError = this.contactType === 'email'
        ? 'Please enter your email address.'
        : 'Please enter your phone number.';
      return;
    }
    this.isRequestingOtp = true;
    this.contactError    = '';
    try {
      await this.#sendOtp();
      this.step = 1;
    } catch (err) {
      this.contactError = err.message;
    } finally {
      this.isRequestingOtp = false;
    }
  }

  @action updateOtp(event) { this.otp = event.target.value; this.otpError = ''; }

  @action updateField(field, event) { this[field] = event.target.value; this.resetError = ''; }

  @action toggleShowPassword()        { this.showPassword        = !this.showPassword; }
  @action toggleShowConfirmPassword() { this.showConfirmPassword = !this.showConfirmPassword; }

  @action async goToResetPassword(event) {
    event.preventDefault();
    if (!this.otp || this.otp.length < 4) { this.otpError = 'Please enter the OTP sent to you.'; return; }
    this.otpError = '';
    this.isVerifyingOtp = true;
    try {
      const res  = await fetch(`${config.APP.API_HOST}/auth_user/verify-otp-verified-email/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({
          token: this.otpToken,
          otp:   this.otp,
          email: this.contactValue.trim(),
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data?.message || data?.detail || 'Invalid OTP.');
      this.verifiedToken = data.token ?? null;
      this.step = 2;
    } catch (err) {
      this.otpError = err.message;
    } finally {
      this.isVerifyingOtp = false;
    }
  }

  @action async handleResendOtp() {
    if (this.isResending) return;
    this.isResending = true; this.otpError = ''; this.otp = '';
    try { await this.#sendOtp(); this.toast.success('OTP resent successfully.'); }
    catch (err) { this.otpError = err.message; }
    finally { this.isResending = false; }
  }

  @action async handleResetPassword(event) {
    event.preventDefault();
    if (this.hasValidationErrors || !this.newPassword) { this.resetError = 'Please fix the errors above.'; return; }
    this.resetError = ''; this.isResetting = true;
    try {
      const encryptedPassword = await encryptPassword(this.newPassword);
      const res  = await fetch(`${config.APP.API_HOST}/auth_user/forget-password-complete-otp/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({ token: this.verifiedToken, user_email: this.contactValue, password: encryptedPassword }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data?.message || data?.detail || 'Password reset failed.');
      this.#clearTimer();
      this.toast.success('Password changed! Please sign in.');
      this.args.onSuccess?.();
    } catch (err) { this.resetError = err.message; }
    finally { this.isResetting = false; }
  }

  @action goBack() {
    this.#clearTimer();
    this.step = 1; this.otp = ''; this.otpError = ''; this.resetError = '';
  }

  <template>
    <div class="w-full max-w-sm bg-white dark:bg-gray-950 rounded-[2rem] overflow-hidden shadow-2xl">

      {{! ══════════════════════════════════════════
          SHARED COMPACT HERO
      ══════════════════════════════════════════ }}
      <div
        class="relative flex flex-col items-center pt-4 pb-0"
        style="background: radial-gradient(ellipse 110% 80% at 50% 100%, #f97316 0%, #fed7aa 35%, #fff7ed 65%, #ffffff 100%); border-bottom-left-radius: 50% 20px; border-bottom-right-radius: 50% 20px;"
      >
        {{! Back button }}
        <button
          type="button"
          {{on "click" @onBackToLogin}}
          aria-label="Back to login"
          class="absolute top-3.5 left-4 w-8 h-8 rounded-full flex items-center justify-center text-gray-500 hover:text-gray-700 hover:bg-black/8 transition-all z-10"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" d="M15 19l-7-7 7-7"/>
          </svg>
        </button>

        {{! Logo — uses hero variant (always dark blue letters) }}
        <img src="/spordium_text_hero.svg" alt="Spordium" class="h-6 mt-1 mb-3 relative z-10" />

        {{! Key image + elliptic floor shadow }}
        <div class="relative flex items-end justify-center w-full" style="height: 136px;">
          <div
            class="absolute bottom-2 left-1/2 -translate-x-1/2 z-0"
            style="width: 52%; height: 16px; border-radius: 50%; background: radial-gradient(ellipse 100% 100% at 50% 50%, rgba(194,65,12,0.28) 0%, rgba(194,65,12,0.07) 60%, transparent 100%); filter: blur(5px);"
          ></div>
          <img
            src="/assets/login_modal/key_icon.png"
            alt="Key"
            class="relative z-10 h-32 object-contain"
            style="transform: translateY(4px); filter: drop-shadow(0 8px 16px rgba(194,65,12,0.25));"
          />
        </div>
      </div>

      {{! ══════════════════════════════════════════
          STEP 0 — Enter email / phone
      ══════════════════════════════════════════ }}
      {{#if (eq this.step 0)}}
        <div class="px-6 pt-5 pb-6">

          <h2 class="text-center text-[1.15rem] font-black italic text-gray-800 dark:text-white mb-3 tracking-tight">
            Reset Password
          </h2>

          {{! EMAIL / PHONE tabs }}
          <div class="relative flex justify-center mb-4">
            <div class="flex gap-0 border-b border-gray-200 dark:border-gray-700 w-full justify-center">
              <button
                type="button"
                {{on "click" (fn this.setContactType "email")}}
                class="pb-2 px-5 text-xs font-black uppercase tracking-widest transition-all relative
                  {{if (eq this.contactType 'email')
                    'text-indigo-600 dark:text-indigo-400'
                    'text-gray-400 dark:text-gray-500 hover:text-gray-600 dark:hover:text-gray-300'}}"
              >
                Email
                {{#if (eq this.contactType "email")}}
                  <span class="absolute bottom-0 left-0 right-0 h-0.5 bg-indigo-600 dark:bg-indigo-400 rounded-full"></span>
                {{/if}}
              </button>
              {{!-- Phone tab — temporarily disabled, will be re-enabled later
              <button
                type="button"
                {{on "click" (fn this.setContactType "phone")}}
                class="pb-2 px-5 text-xs font-black uppercase tracking-widest transition-all relative
                  {{if (eq this.contactType 'phone')
                    'text-indigo-600 dark:text-indigo-400'
                    'text-gray-400 dark:text-gray-500 hover:text-gray-600 dark:hover:text-gray-300'}}"
              >
                Phone
                {{#if (eq this.contactType "phone")}}
                  <span class="absolute bottom-0 left-0 right-0 h-0.5 bg-indigo-600 dark:bg-indigo-400 rounded-full"></span>
                {{/if}}
              </button>
              --}}
            </div>
          </div>

          {{#if this.contactError}}
            <div class="mb-3 px-4 py-2 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-2xl text-xs text-red-600 dark:text-red-400 text-center">
              {{this.contactError}}
            </div>
          {{/if}}

          <form {{on "submit" this.handleRequestOtp}} class="space-y-3">
            <div class="relative">
              <span class="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400 dark:text-gray-500 pointer-events-none">
                {{#if (eq this.contactType "email")}}
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M21.75 6.75v10.5a2.25 2.25 0 01-2.25 2.25h-15a2.25 2.25 0 01-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25m19.5 0v.243a2.25 2.25 0 01-1.07 1.916l-7.5 4.615a2.25 2.25 0 01-2.36 0L3.32 8.91a2.25 2.25 0 01-1.07-1.916V6.75"/>
                  </svg>
                {{else}}
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 1.5H8.25A2.25 2.25 0 006 3.75v16.5a2.25 2.25 0 002.25 2.25h7.5A2.25 2.25 0 0018 20.25V3.75a2.25 2.25 0 00-2.25-2.25H13.5m-3 0V3h3V1.5m-3 0h3m-3 15.75h3"/>
                  </svg>
                {{/if}}
              </span>
              <input
                type={{if (eq this.contactType "email") "email" "tel"}}
                value={{this.contactValue}}
                {{on "input" this.updateContactValue}}
                autocomplete={{if (eq this.contactType "email") "email" "tel"}}
                placeholder={{if (eq this.contactType "email") "Enter Email" "Enter Phone Number"}}
                class="w-full pl-10 pr-4 py-2.5 rounded-full
                       bg-gray-100 dark:bg-gray-800
                       text-gray-700 dark:text-gray-200
                       placeholder-gray-400 dark:placeholder-gray-500
                       text-sm border-2 border-transparent
                       focus:border-indigo-300 dark:focus:border-indigo-600
                       focus:outline-none transition-colors
                       {{if this.contactError 'border-red-300 dark:border-red-600' ''}}"
              />
            </div>

            <div class="flex justify-center pt-0.5">
              <button
                type="submit"
                disabled={{if this.isContactValid this.isRequestingOtp true}}
                class="w-full py-2.5 text-white font-black rounded-full uppercase tracking-widest text-sm
                       transition-colors disabled:opacity-50 disabled:cursor-not-allowed
                       {{if this.isContactValid
                         'bg-green-500 hover:bg-green-600 active:bg-green-700 shadow-lg shadow-green-500/25'
                         'bg-green-300 dark:bg-green-900 shadow-none'}}"
              >
                {{if this.isRequestingOtp "Requesting…" "Request OTP"}}
              </button>
            </div>
          </form>

        </div>

      {{! ══════════════════════════════════════════
          STEP 1 — OTP Verification
      ══════════════════════════════════════════ }}
      {{else if (lte this.step 1)}}
        <div class="px-6 pt-5 pb-6">

          <h2 class="text-center text-[1.15rem] font-black italic text-gray-800 dark:text-white tracking-tight mb-0.5">
            Verify OTP
          </h2>
          <p class="text-center text-[11px] text-gray-400 dark:text-gray-500 mb-4">
            Code sent to
            <span class="font-bold text-gray-600 dark:text-gray-300">{{this.contactValue}}</span>
          </p>

          {{#if this.otpError}}
            <div class="mb-3 px-4 py-2 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-2xl text-xs text-red-600 dark:text-red-400 text-center">
              {{this.otpError}}
            </div>
          {{/if}}

          {{#if this.timerExpired}}
            <div class="text-center space-y-3">
              <p class="text-xs font-semibold text-amber-500 dark:text-amber-400">OTP expired. Request a new one.</p>
              <button
                type="button"
                {{on "click" this.handleResendOtp}}
                disabled={{this.isResending}}
                class="w-full py-2.5 bg-green-500 hover:bg-green-600 disabled:opacity-60 disabled:cursor-not-allowed
                       text-white font-black rounded-full uppercase tracking-widest text-sm transition-colors
                       shadow-lg shadow-green-500/25"
              >
                {{if this.isResending "Resending…" "Resend OTP"}}
              </button>
            </div>

          {{else}}
            <form {{on "submit" this.goToResetPassword}} class="space-y-2.5">

              {{! OTP input }}
              <div class="relative">
                <span class="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400 dark:text-gray-500 pointer-events-none">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z"/>
                  </svg>
                </span>
                <input
                  type="text"
                  inputmode="numeric"
                  maxlength="8"
                  autocomplete="one-time-code"
                  value={{this.otp}}
                  {{on "input" this.updateOtp}}
                  placeholder="Enter OTP"
                  class="w-full pl-10 pr-4 py-2.5 rounded-full bg-gray-100 dark:bg-gray-800
                         text-gray-700 dark:text-gray-200 placeholder-gray-400 dark:placeholder-gray-500
                         text-sm border-2 border-transparent
                         focus:border-indigo-300 dark:focus:border-indigo-600
                         focus:outline-none transition-colors tracking-[0.35em] text-center font-bold"
                />
              </div>

              {{! Timer bar }}
              <div class="h-1 bg-gray-100 dark:bg-gray-800 rounded-full overflow-hidden">
                <div
                  class="h-full rounded-full transition-all duration-1000 {{if (lte this.timeLeft 60) 'bg-red-400' 'bg-indigo-400'}}"
                  style="width: {{this.timerProgress}}"
                ></div>
              </div>

              {{! Timer + resend }}
              <div class="flex items-center justify-between text-xs px-1">
                <span class="font-black tabular-nums {{if (lte this.timeLeft 60) 'text-red-500 dark:text-red-400' 'text-indigo-600 dark:text-indigo-400'}}">
                  {{this.timerDisplay}}
                </span>
                <button
                  type="button"
                  {{on "click" this.handleResendOtp}}
                  disabled={{this.isResending}}
                  class="font-semibold text-indigo-600 dark:text-indigo-400 hover:underline disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                >
                  {{if this.isResending "Resending…" "Resend OTP"}}
                </button>
              </div>

              {{! Next button }}
              <div class="pt-0.5">
                <button
                  type="submit"
                  disabled={{this.isVerifyingOtp}}
                  class="w-full py-2.5 rounded-full font-black uppercase tracking-widest text-sm text-white transition-colors
                    disabled:opacity-60 disabled:cursor-not-allowed shadow-lg
                    {{if this.otp
                      'bg-green-500 hover:bg-green-600 active:bg-green-700 shadow-green-500/25'
                      'bg-green-300 dark:bg-green-900 cursor-not-allowed shadow-none'}}"
                >
                  {{if this.isVerifyingOtp "Verifying…" "Next"}}
                </button>
              </div>

            </form>
          {{/if}}

          <div class="mt-3 text-center">
            <button
              type="button"
              {{on "click" (fn (mut this.step) 0)}}
              class="text-[11px] font-medium text-gray-400 dark:text-gray-500 hover:text-indigo-500 dark:hover:text-indigo-400 transition-colors"
            >
              ← Change email
            </button>
          </div>

        </div>

      {{! ══════════════════════════════════════════
          STEP 2 — Create New Password
      ══════════════════════════════════════════ }}
      {{else}}
        <div class="px-6 pt-5 pb-6">

          <h2 class="text-center text-[1.15rem] font-black italic text-gray-800 dark:text-white tracking-tight mb-4">
            Create New Password
          </h2>

          {{#if this.resetError}}
            <div class="mb-3 px-4 py-2 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-2xl text-xs text-red-600 dark:text-red-400 text-center">
              {{this.resetError}}
            </div>
          {{/if}}

          <form {{on "submit" this.handleResetPassword}} class="space-y-2.5">

            {{! New Password }}
            <div class="relative">
              <span class="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400 dark:text-gray-500 pointer-events-none">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z"/>
                </svg>
              </span>
              <input
                type={{if this.showPassword "text" "password"}}
                value={{this.newPassword}}
                {{on "input" (fn this.updateField "newPassword")}}
                autocomplete="new-password"
                placeholder="New Password"
                class="w-full pl-10 pr-11 py-2.5 rounded-full bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-200 placeholder-gray-400 dark:placeholder-gray-500 text-sm border-2 border-transparent focus:border-indigo-300 dark:focus:border-indigo-600 focus:outline-none transition-colors"
              />
              <button type="button" {{on "click" this.toggleShowPassword}}
                class="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400 dark:text-gray-500 hover:text-gray-600 dark:hover:text-gray-300 transition-colors"
                aria-label="Toggle password visibility">
                {{#if this.showPassword}}
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 4.411m0 0L21 21"/></svg>
                {{else}}
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/><path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/></svg>
                {{/if}}
              </button>
            </div>

            {{! Confirm Password }}
            <div class="relative">
              <span class="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400 dark:text-gray-500 pointer-events-none">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z"/>
                </svg>
              </span>
              <input
                type={{if this.showConfirmPassword "text" "password"}}
                value={{this.confirmPassword}}
                {{on "input" (fn this.updateField "confirmPassword")}}
                autocomplete="new-password"
                placeholder="Confirm New Password"
                class="w-full pl-10 pr-11 py-2.5 rounded-full bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-200 placeholder-gray-400 dark:placeholder-gray-500 text-sm border-2 border-transparent focus:border-indigo-300 dark:focus:border-indigo-600 focus:outline-none transition-colors"
              />
              <button type="button" {{on "click" this.toggleShowConfirmPassword}}
                class="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400 dark:text-gray-500 hover:text-gray-600 dark:hover:text-gray-300 transition-colors"
                aria-label="Toggle confirm password visibility">
                {{#if this.showConfirmPassword}}
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 4.411m0 0L21 21"/></svg>
                {{else}}
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/><path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/></svg>
                {{/if}}
              </button>
            </div>

            {{! Validation rules }}
            {{#each this.passwordValidations as |rule|}}
              {{#if rule.show}}
                <div class="flex items-center gap-2 ml-1">
                  {{#if rule.valid}}
                    <svg class="w-3 h-3 text-emerald-500 shrink-0" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/></svg>
                    <span class="text-[11px] text-emerald-600 dark:text-emerald-400">{{rule.text}}</span>
                  {{else}}
                    <svg class="w-3 h-3 text-red-500 shrink-0" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/></svg>
                    <span class="text-[11px] text-red-500 dark:text-red-400">{{rule.text}}</span>
                  {{/if}}
                </div>
              {{/if}}
            {{/each}}

            <div class="pt-0.5">
              <button
                type="submit"
                disabled={{this.isResetting}}
                class="w-full py-2.5 rounded-full font-black uppercase tracking-widest text-sm text-white transition-colors
                       disabled:opacity-60 disabled:cursor-not-allowed shadow-lg
                  {{if this.hasValidationErrors
                    'bg-green-300 dark:bg-green-900 cursor-not-allowed shadow-none'
                    'bg-green-500 hover:bg-green-600 active:bg-green-700 shadow-green-500/25'}}"
              >
                {{if this.isResetting "Resetting…" "Reset Password"}}
              </button>
            </div>

          </form>

          <div class="mt-3 text-center">
            <button type="button" {{on "click" this.goBack}}
              class="text-[11px] font-medium text-gray-400 dark:text-gray-500 hover:text-indigo-500 dark:hover:text-indigo-400 transition-colors">
              ← Back to OTP
            </button>
          </div>

        </div>
      {{/if}}

    </div>
  </template>
}
