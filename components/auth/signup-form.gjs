import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { service } from '@ember/service';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { LinkTo } from '@ember/routing';
import config from 'spordium/config/environment';
import { eq } from 'ember-truth-helpers';
import { getUserLocation, onInit } from "../../utils/utility.helper";
import encryptPassword from "../../utils/encrypt-password";
import TermsModal from './terms-modal';

// ── Utilities ─────────────────────────────────────────────────────────────────

function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function emptyLocation() {
  return { lat: null, lng: null, country: '', countryCode: '', state: '', city: '' };
}

async function reverseGeocode(lat, lng, apiKey) {
  const res = await fetch(
    `https://maps.googleapis.com/maps/api/geocode/json?latlng=${lat},${lng}&key=${apiKey}`
  );
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const data = await res.json();
  if (data.status !== 'OK' || !data.results.length) throw new Error('No results');

  const components = data.results.flatMap(r => r.address_components);
  const find = (type) => components.find(c => c.types.includes(type));
  const country = find('country');
  const state   = find('administrative_area_level_1');
  const city    = find('locality') || find('administrative_area_level_2');

  return {
    lat,
    lng,
    country:     country?.long_name  || '',
    countryCode: country?.short_name || '',
    state:       state?.long_name    || '',
    city:        city?.long_name     || '',
  };
}

// ── Main Component ────────────────────────────────────────────────────────────

export default class SignupFormComponent extends Component {
  @service session;
  @service router;
  @service toast;
  @service authModal;
  @service socialAuth;

  get documentBody() { return document.body; }

  // ── Form fields ──────────────────────────────────────────────────────────
  @tracked firstName       = '';
  @tracked lastName        = '';
  @tracked email           = '';
  @tracked phone           = '';
  @tracked usePhone        = false;
  @tracked password        = '';
  @tracked confirmPassword = '';
  @tracked errorMessage    = '';
  @tracked isSubmitting    = false;
  @tracked isGoogleLoading   = false;
  @tracked isFacebookLoading = false;

  @tracked emailExists     = null;
  @tracked isCheckingEmail = false;
  _emailCheckTimer = null;

  @tracked phoneExists     = null;
  @tracked isCheckingPhone = false;
  _phoneCheckTimer = null;

  // ── Step control (1 = form, 3 = sport interests, 4 = welcome) ───────────
  @tracked currentStep = 1;

  // ── Terms & age consent ──────────────────────────────────────────────────
  @tracked agreeTerms      = false;
  @tracked isOver13        = false;
  @tracked showTermsModal  = false;

  // ── Sport interests ───────────────────────────────────────────────────────
  @tracked showPassword        = false;
  @tracked showConfirmPassword = false;

  @tracked cricketSelected  = false;
  @tracked footballSelected = false;
  @tracked baseballSelected = false;

  // ── Location ─────────────────────────────────────────────────────────────
  _locationData = emptyLocation();

  // ── Computed / getters ───────────────────────────────────────────────────

  get contactStatus() {
    if (this.usePhone) {
      if (!this.phone) return 'idle';
      return this.phone.trim().length >= 8 ? 'ok' : 'error';
    }
    if (!this.email) return 'idle';
    return isValidEmail(this.email) ? 'ok' : 'error';
  }

  get contactMessage() {
    if (this.contactStatus === 'error') {
      return this.usePhone ? 'Enter a valid phone number (min 8 digits)' : 'Please enter a valid email address';
    }
    return '';
  }

  get passwordError() {
    if (!this.password) return '';
    return this.password.length < 6 ? 'Password must be at least 6 characters' : '';
  }

  get confirmError() {
    if (!this.confirmPassword) return '';
    return this.password !== this.confirmPassword ? 'Passwords do not match' : '';
  }

  get hasSportSelected() {
    return this.cricketSelected || this.footballSelected || this.baseballSelected;
  }

  get isFormValid() {
    const contactOk = this.usePhone
      ? (this.phoneExists === false && !this.isCheckingPhone)
      : (this.emailExists === false && !this.isCheckingEmail);
    return (
      this.firstName.trim().length >= 1 &&
      this.lastName.trim().length >= 1  &&
      this.contactStatus === 'ok'       &&
      this.password.length >= 6         &&
      this.password === this.confirmPassword &&
      this.agreeTerms &&
      this.isOver13   &&
      contactOk        &&
      !this.isSubmitting
    );
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @action async signUpFormStartUp() {
    try {
      const mapData = await getUserLocation();
      if (!mapData?.geo) return;

      const { lat, long: lng } = mapData.geo;
      const loc = await reverseGeocode(lat, lng, config.APP.GOOGLE_MAPS_API_KEY);
      this._locationData = { ...emptyLocation(), ...loc };
    } catch (err) {
      console.warn('Could not auto-detect location:', err);
    }
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  @action updateField(field, event) {
    this[field] = event.target.value;
    if (field === 'email') this._scheduleEmailCheck();
    if (field === 'phone') this._schedulePhoneCheck();
  }

  @action setContactMode(usePhone) {
    if (this.usePhone === usePhone) return;
    this.usePhone = usePhone;
    this.email = '';
    this.phone = '';
    this.emailExists = null;
    this.isCheckingEmail = false;
    clearTimeout(this._emailCheckTimer);
    this.phoneExists = null;
    this.isCheckingPhone = false;
    clearTimeout(this._phoneCheckTimer);
  }

  _scheduleEmailCheck() {
    clearTimeout(this._emailCheckTimer);
    this.emailExists = null;
    if (!isValidEmail(this.email)) return;
    this._emailCheckTimer = setTimeout(() => this._checkEmailExists(), 600);
  }

  async _checkEmailExists() {
    this.isCheckingEmail = true;
    try {
      const res = await fetch(`${config.APP.API_HOST}/auth_user/check_mail/${encodeURIComponent(this.email)}/`);
      if (res.ok) {
        const data = await res.json();
        this.emailExists = data?.data?.exist ?? false;
      } else {
        this.emailExists = false;
      }
    } catch {
      this.emailExists = false;
    } finally {
      this.isCheckingEmail = false;
    }
  }

  _schedulePhoneCheck() {
    clearTimeout(this._phoneCheckTimer);
    this.phoneExists = null;
    if (this.phone.trim().length < 8) return;
    this._phoneCheckTimer = setTimeout(() => this._checkPhoneExists(), 600);
  }

  async _checkPhoneExists() {
    this.isCheckingPhone = true;
    try {
      const res = await fetch(`${config.APP.API_HOST}/auth_user/check_callphone/${encodeURIComponent(this.phone.trim())}/`);
      if (res.ok) {
        const data = await res.json();
        this.phoneExists = data?.data?.exist ?? false;
      } else {
        this.phoneExists = false;
      }
    } catch {
      this.phoneExists = false;
    } finally {
      this.isCheckingPhone = false;
    }
  }

  @action async handleSubmit(event) {
    event.preventDefault();
    this.errorMessage = '';

    if (!this.isFormValid) {
      if (!this.firstName.trim() || !this.lastName.trim()) {
        this.errorMessage = 'Please enter your first and last name';
      } else if (this.contactStatus !== 'ok') {
        this.errorMessage = this.contactMessage || 'Please enter a valid email or phone number';
      } else if (this.password.length < 6) {
        this.errorMessage = 'Password must be at least 6 characters';
      } else if (this.password !== this.confirmPassword) {
        this.errorMessage = 'Passwords do not match';
      } else {
        this.errorMessage = 'Please fill in all required fields';
      }
      return;
    }

    this.isSubmitting = true;
    try {
      const hashedPassword = await encryptPassword(this.password);
      const payload = {
        user_fullname: {
          first_name: this.firstName.trim(),
          last_name:  this.lastName.trim(),
        },
        password:     hashedPassword,
        country_code: this._locationData.countryCode || 'BD',
        latitude:     this._locationData.lat  ? String(this._locationData.lat)  : '',
        longitude:    this._locationData.lng  ? String(this._locationData.lng)  : '',
      };

      if (this.usePhone) {
        payload.user_callphone = this.phone.trim();
      } else {
        payload.user_email = this.email.trim();
      }

      const res  = await fetch(`${config.APP.API_HOST}/auth_user/registration/`, {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify(payload),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data?.message || data?.detail || 'Registration failed');

      const { tokens, ...user } = data;
      this.session.setAuthenticatedFromTokens(tokens, user);
      this.toast.success('Account created successfully!');
      this.currentStep = 3;
    } catch (err) {
      this.errorMessage = err.message || 'Registration failed. Please try again.';
    } finally {
      this.isSubmitting = false;
    }
  }

  @action toggleField(field) {
    this[field] = !this[field];
  }

  @action openTermsModal() {
    this.showTermsModal = true;
  }

  @action acceptTerms() {
    this.agreeTerms    = true;
    this.showTermsModal = false;
  }

  @action declineTerms() {
    this.agreeTerms    = false;
    this.showTermsModal = false;
  }

  @action skipToWelcome() {
    this.currentStep = 4;
  }

  @action goHome() {
    if (this.args.onClose) {
      this.args.onClose();
    } else {
      this.router.transitionTo('index');
    }
  }

  @action goToProfile() {
    const username = this.session.currentUser?.user_username;
    if (this.args.onClose) this.args.onClose();
    if (username) {
      this.router.transitionTo('profile', username);
    }
  }

  @action async handleGoogleSignIn() {
    this.isGoogleLoading = true;
    this.errorMessage = '';
    try {
      const authToken = await this.socialAuth.getGoogleToken();
      const payload = {
        auth_token:          authToken,
        user_country:        this._locationData.country        || '',
        user_state_divition: this._locationData.state          || '',
        user_playing_city:   this._locationData.city           || '',
        country_code:        this._locationData.countryCode    || '',
        latitude:            this._locationData.lat  ? String(this._locationData.lat)  : '',
        longitude:           this._locationData.lng  ? String(this._locationData.lng)  : '',
      };
      const res = await fetch(`${config.APP.API_HOST}/social_auth/google/`, {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify(payload),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data?.message || data?.detail || 'Google sign-in failed');
      this.session.setAuthenticatedFromTokens(data.tokens, data.user ?? null);
      this.args.onClose ? this.args.onClose() : this.router.transitionTo('index');
    } catch (err) {
      this.errorMessage = err.message || 'Google sign-in failed. Please try again.';
    } finally {
      this.isGoogleLoading = false;
    }
  }

  @action async handleFacebookSignIn() {
    this.isFacebookLoading = true;
    this.errorMessage = '';
    try {
      const authToken = await this.socialAuth.getFacebookToken();
      const payload = {
        auth_token:          authToken,
        user_country:        this._locationData.country        || '',
        user_state_divition: this._locationData.state          || '',
        user_playing_city:   this._locationData.city           || '',
        country_code:        this._locationData.countryCode    || '',
        latitude:            this._locationData.lat  ? String(this._locationData.lat)  : '',
        longitude:           this._locationData.lng  ? String(this._locationData.lng)  : '',
      };
      const res = await fetch(`${config.APP.API_HOST}/social_auth/facebook/`, {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify(payload),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data?.message || data?.detail || 'Facebook sign-in failed');
      this.session.setAuthenticatedFromTokens(data.tokens, data.user ?? null);
      this.args.onClose ? this.args.onClose() : this.router.transitionTo('index');
    } catch (err) {
      this.errorMessage = err.message || 'Facebook sign-in failed. Please try again.';
    } finally {
      this.isFacebookLoading = false;
    }
  }

  // ── Template ─────────────────────────────────────────────────────────────

  <template>
    {{! ── Root wrapper ──────────────────────────────────────────────────── }}
    <div
      class={{if @isModal "" "min-h-screen flex items-center justify-center px-3 sm:px-4 py-4 sm:py-10 bg-gradient-to-br from-slate-50 via-blue-50 to-indigo-100 dark:from-gray-950 dark:via-slate-900 dark:to-indigo-950"}}
      {{onInit this.signUpFormStartUp}}
    >

      {{! ═══════════════════════════════════════════════════════════════════ }}
      {{! STEP 1 — Registration form                                         }}
      {{! ═══════════════════════════════════════════════════════════════════ }}
      {{#if (eq this.currentStep 1)}}
        <div class="w-full bg-white dark:bg-gray-900 rounded-3xl overflow-hidden">

          {{! ── Header image ──────────────────────────────────────────────── }}
          <div class="relative w-full overflow-hidden rounded-b-[2.5rem] h-36 sm:h-[200px]">
            <img
              src="/assets/register_modal/register_sports_player.png"
              alt="Sports player"
              class="w-full h-full object-cover object-top"
            />
            <div class="absolute inset-x-0 bottom-0 h-16 bg-gradient-to-t from-white dark:from-gray-900 to-transparent"></div>
          </div>

          {{! ── Logo + heading ────────────────────────────────────────────── }}
          <div class="text-center mt-1 sm:mt-3 mb-2 sm:mb-4 px-4 sm:px-6">
            <img src="/spordium_text.svg" alt="Spordium" class="h-7 mx-auto mb-1" />
            <h2 class="text-lg font-bold italic text-gray-800 dark:text-gray-100">Register</h2>
          </div>

          {{! ── Global error ──────────────────────────────────────────────── }}
          {{#if this.errorMessage}}
            <div class="mx-4 sm:mx-6 mb-3 flex items-start gap-2 px-4 py-2.5 rounded-full bg-red-50 dark:bg-red-950/50 border border-red-200 dark:border-red-800 text-xs text-red-700 dark:text-red-400">
              <svg class="w-3.5 h-3.5 mt-0.5 shrink-0" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm-.75-9.75a.75.75 0 011.5 0v4a.75.75 0 01-1.5 0v-4zm.75 7a.75.75 0 100-1.5.75.75 0 000 1.5z" clip-rule="evenodd"/>
              </svg>
              {{this.errorMessage}}
            </div>
          {{/if}}

          {{! ── Form ─────────────────────────────────────────────────────── }}
          <form {{on "submit" this.handleSubmit}} class="px-4 sm:px-6 space-y-3 sm:space-y-4 pb-5 sm:pb-6">

            {{! First Name + Last Name (side by side) }}
            <div class="grid grid-cols-2 gap-2">

              {{! First Name }}
              <div class="relative flex items-center">
                <span class="absolute left-3 text-gray-400 dark:text-gray-500 pointer-events-none">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z"/>
                  </svg>
                </span>
                <input
                  type="text"
                  id="signup-firstname"
                  value={{this.firstName}}
                  {{on "input" (fn this.updateField "firstName")}}
                  required
                  autocomplete="given-name"
                  placeholder="First Name"
                  class="w-full pl-8 pr-3 py-3 rounded-full bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-200 placeholder-gray-400 text-sm border-2 border-transparent focus:border-indigo-300 dark:focus:border-indigo-600 focus:outline-none transition-colors"
                />
              </div>

              {{! Last Name }}
              <div class="relative flex items-center">
                <span class="absolute left-3 text-gray-400 dark:text-gray-500 pointer-events-none">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z"/>
                  </svg>
                </span>
                <input
                  type="text"
                  id="signup-lastname"
                  value={{this.lastName}}
                  {{on "input" (fn this.updateField "lastName")}}
                  required
                  autocomplete="family-name"
                  placeholder="Last Name"
                  class="w-full pl-8 pr-3 py-3 rounded-full bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-200 placeholder-gray-400 text-sm border-2 border-transparent focus:border-indigo-300 dark:focus:border-indigo-600 focus:outline-none transition-colors"
                />
              </div>

            </div>

            {{! Email / Mobile input with mode toggle }}
            <div>
              {{! Toggle tabs }}
              <div class="flex items-center rounded-full bg-gray-100 dark:bg-gray-800 p-0.5 mb-2">
                <button
                  type="button"
                  {{on "click" (fn this.setContactMode false)}}
                  class="flex-1 text-xs py-1.5 rounded-full font-medium transition-all
                    {{if this.usePhone
                      'text-gray-400 dark:text-gray-500'
                      'bg-white dark:bg-gray-700 text-gray-800 dark:text-gray-100 shadow-sm'}}"
                >
                  Email
                </button>
                <button
                  type="button"
                  {{on "click" (fn this.setContactMode true)}}
                  class="flex-1 text-xs py-1.5 rounded-full font-medium transition-all
                    {{if this.usePhone
                      'bg-white dark:bg-gray-700 text-gray-800 dark:text-gray-100 shadow-sm'
                      'text-gray-400 dark:text-gray-500'}}"
                >
                  Mobile
                </button>
              </div>

              {{! Email input }}
              {{#if this.usePhone}}
                {{! Phone input }}
                <div class="relative flex items-center">
                  <span class="absolute left-4 text-gray-400 dark:text-gray-500 pointer-events-none">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 6.75c0 8.284 6.716 15 15 15h2.25a2.25 2.25 0 002.25-2.25v-1.372c0-.516-.351-.966-.852-1.091l-4.423-1.106c-.44-.11-.902.055-1.173.417l-.97 1.293c-.282.376-.769.542-1.21.38a12.035 12.035 0 01-7.143-7.143c-.162-.441.004-.928.38-1.21l1.293-.97c.363-.271.527-.734.417-1.173L6.963 3.102a1.125 1.125 0 00-1.091-.852H4.5A2.25 2.25 0 002.25 4.5v2.25z"/>
                    </svg>
                  </span>
                  <input
                    type="tel"
                    id="signup-phone"
                    value={{this.phone}}
                    {{on "input" (fn this.updateField "phone")}}
                    autocomplete="tel"
                    placeholder="+880 1234 567890"
                    class="w-full pl-10 pr-10 py-3 rounded-full bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-200 placeholder-gray-400 text-sm border-2 border-transparent focus:border-indigo-300 dark:focus:border-indigo-600 focus:outline-none transition-colors
                      {{if this.phoneExists '!border-red-400 dark:!border-red-500'
                           (if (eq this.contactStatus 'ok') '!border-emerald-400 dark:!border-emerald-500'
                                (if (eq this.contactStatus 'error') '!border-red-400 dark:!border-red-500' ''))}}"
                  />
                  {{#if this.phoneExists}}
                    <span class="absolute right-4 top-1/2 -translate-y-1/2 text-red-400">
                      <svg class="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm-.75-9.75a.75.75 0 011.5 0v4a.75.75 0 01-1.5 0v-4zm.75 7a.75.75 0 100-1.5.75.75 0 000 1.5z" clip-rule="evenodd"/>
                      </svg>
                    </span>
                  {{else if this.isCheckingPhone}}
                    <span class="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400">
                      <svg class="w-3.5 h-3.5 animate-spin" fill="none" viewBox="0 0 24 24">
                        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
                        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
                      </svg>
                    </span>
                  {{else if (eq this.contactStatus 'ok')}}
                    <span class="absolute right-4 top-1/2 -translate-y-1/2 text-emerald-500">
                      <svg class="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
                      </svg>
                    </span>
                  {{else if (eq this.contactStatus 'error')}}
                    <span class="absolute right-4 top-1/2 -translate-y-1/2 text-red-400">
                      <svg class="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm-.75-9.75a.75.75 0 011.5 0v4a.75.75 0 01-1.5 0v-4zm.75 7a.75.75 0 100-1.5.75.75 0 000 1.5z" clip-rule="evenodd"/>
                      </svg>
                    </span>
                  {{/if}}
                </div>
              {{else}}
                <div class="relative flex items-center">
                  <span class="absolute left-4 text-gray-400 dark:text-gray-500 pointer-events-none">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M21.75 6.75v10.5a2.25 2.25 0 01-2.25 2.25h-15a2.25 2.25 0 01-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25m19.5 0v.243a2.25 2.25 0 01-1.07 1.916l-7.5 4.615a2.25 2.25 0 01-2.36 0L3.32 8.91a2.25 2.25 0 01-1.07-1.916V6.75"/>
                    </svg>
                  </span>
                  <input
                    type="email"
                    id="signup-email"
                    value={{this.email}}
                    {{on "input" (fn this.updateField "email")}}
                    autocomplete="email"
                    placeholder="Your Email"
                    class="w-full pl-10 pr-10 py-3 rounded-full bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-200 placeholder-gray-400 text-sm border-2 border-transparent focus:border-indigo-300 dark:focus:border-indigo-600 focus:outline-none transition-colors
                      {{if this.emailExists '!border-red-400 dark:!border-red-500'
                           (if (eq this.contactStatus 'ok') '!border-emerald-400 dark:!border-emerald-500'
                                (if (eq this.contactStatus 'error') '!border-red-400 dark:!border-red-500' ''))}}"
                  />
                  {{#if this.emailExists}}
                    <span class="absolute right-4 top-1/2 -translate-y-1/2 text-red-400">
                      <svg class="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm-.75-9.75a.75.75 0 011.5 0v4a.75.75 0 01-1.5 0v-4zm.75 7a.75.75 0 100-1.5.75.75 0 000 1.5z" clip-rule="evenodd"/>
                      </svg>
                    </span>
                  {{else if this.isCheckingEmail}}
                    <span class="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400">
                      <svg class="w-3.5 h-3.5 animate-spin" fill="none" viewBox="0 0 24 24">
                        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
                        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
                      </svg>
                    </span>
                  {{else if (eq this.contactStatus 'ok')}}
                    <span class="absolute right-4 top-1/2 -translate-y-1/2 text-emerald-500">
                      <svg class="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
                      </svg>
                    </span>
                  {{else if (eq this.contactStatus 'error')}}
                    <span class="absolute right-4 top-1/2 -translate-y-1/2 text-red-400">
                      <svg class="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm-.75-9.75a.75.75 0 011.5 0v4a.75.75 0 01-1.5 0v-4zm.75 7a.75.75 0 100-1.5.75.75 0 000 1.5z" clip-rule="evenodd"/>
                      </svg>
                    </span>
                  {{/if}}
                </div>
              {{/if}}

              {{#if this.emailExists}}
                <p class="mt-1 ml-4 text-xs text-red-500">This email is already taken. Please use a different one.</p>
              {{else if this.phoneExists}}
                <p class="mt-1 ml-4 text-xs text-red-500">This phone number is already registered. Please use a different one.</p>
              {{else if this.contactMessage}}
                <p class="mt-1 ml-4 text-xs text-red-500">{{this.contactMessage}}</p>
              {{/if}}
            </div>

            {{! Password }}
            <div>
              <div class="relative flex items-center">
                <span class="absolute left-4 text-gray-400 dark:text-gray-500 pointer-events-none">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z"/>
                  </svg>
                </span>
                <input
                  type={{if this.showPassword "text" "password"}}
                  id="signup-password"
                  value={{this.password}}
                  {{on "input" (fn this.updateField "password")}}
                  required
                  autocomplete="new-password"
                  placeholder="Password"
                  class="w-full pl-10 pr-10 py-3 rounded-full bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-200 placeholder-gray-400 text-sm border-2 border-transparent focus:border-indigo-300 dark:focus:border-indigo-600 focus:outline-none transition-colors"
                />
                <button
                  type="button"
                  {{on "click" (fn this.toggleField "showPassword")}}
                  class="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400 dark:text-gray-500 hover:text-gray-500 dark:hover:text-gray-400 transition-colors"
                  aria-label={{if this.showPassword "Hide password" "Show password"}}
                >
                  {{#if this.showPassword}}
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 4.411m0 0L21 21"/>
                    </svg>
                  {{else}}
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                      <path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                    </svg>
                  {{/if}}
                </button>
              </div>
              {{#if this.passwordError}}
                <p class="mt-1 ml-4 text-xs text-red-500">{{this.passwordError}}</p>
              {{else if this.password}}
                <p class="mt-1 ml-4 text-xs text-emerald-600 dark:text-emerald-400">Looks good ✓</p>
              {{/if}}
            </div>

            {{! Confirm Password }}
            <div>
              <div class="relative flex items-center">
                <span class="absolute left-4 text-gray-400 dark:text-gray-500 pointer-events-none">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z"/>
                  </svg>
                </span>
                <input
                  type={{if this.showConfirmPassword "text" "password"}}
                  id="signup-confirm-password"
                  value={{this.confirmPassword}}
                  {{on "input" (fn this.updateField "confirmPassword")}}
                  required
                  autocomplete="new-password"
                  placeholder="Re-Type Password"
                  class="w-full pl-10 pr-10 py-3 rounded-full bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-200 placeholder-gray-400 text-sm border-2 border-transparent focus:border-indigo-300 dark:focus:border-indigo-600 focus:outline-none transition-colors
                    {{if this.confirmError '!border-red-400 dark:!border-red-500'
                         (if this.confirmPassword '!border-emerald-400 dark:!border-emerald-500' '')}}"
                />
                <button
                  type="button"
                  {{on "click" (fn this.toggleField "showConfirmPassword")}}
                  class="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400 dark:text-gray-500 hover:text-gray-500 dark:hover:text-gray-400 transition-colors"
                  aria-label={{if this.showConfirmPassword "Hide password" "Show password"}}
                >
                  {{#if this.showConfirmPassword}}
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 4.411m0 0L21 21"/>
                    </svg>
                  {{else}}
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                      <path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                    </svg>
                  {{/if}}
                </button>
              </div>
              {{#if this.confirmError}}
                <p class="mt-1 ml-4 text-xs text-red-500">{{this.confirmError}}</p>
              {{else if this.confirmPassword}}
                <p class="mt-1 ml-4 text-xs text-emerald-600 dark:text-emerald-400">Passwords match ✓</p>
              {{/if}}
            </div>

            {{! ── Checkboxes ────────────────────────────────────────────── }}
            <div class="space-y-2 pt-1">
              {{! Terms & Conditions }}
              <div class="flex items-start gap-2.5 w-full">
                <button
                  type="button"
                  {{on "click" (fn this.toggleField "agreeTerms")}}
                  class="mt-0.5 flex-shrink-0 w-4 h-4 rounded flex items-center justify-center transition-colors
                    {{if this.agreeTerms 'bg-indigo-600' 'bg-gray-200 dark:bg-gray-700 border border-gray-300 dark:border-gray-600'}}"
                  aria-pressed={{if this.agreeTerms "true" "false"}}
                >
                  {{#if this.agreeTerms}}
                    <svg class="w-2.5 h-2.5 text-white" fill="none" stroke="currentColor" stroke-width="3" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/>
                    </svg>
                  {{/if}}
                </button>
                <span class="text-xs text-gray-600 dark:text-gray-300 leading-tight">
                  I Agree With The
                  <button
                    type="button"
                    {{on "click" this.openTermsModal}}
                    class="font-semibold text-indigo-600 dark:text-indigo-400 hover:text-indigo-800 dark:hover:text-indigo-300 underline underline-offset-2 transition-colors"
                  >TERMS &amp; CONDITIONS</button>
                </span>
              </div>

              {{! Age confirmation }}
              <button
                type="button"
                {{on "click" (fn this.toggleField "isOver13")}}
                class="flex items-start gap-2.5 w-full text-left group"
                aria-pressed={{if this.isOver13 "true" "false"}}
              >
                <span class="mt-0.5 flex-shrink-0 w-4 h-4 rounded flex items-center justify-center transition-colors
                  {{if this.isOver13 'bg-indigo-600' 'bg-gray-200 dark:bg-gray-700 border border-gray-300 dark:border-gray-600'}}">
                  {{#if this.isOver13}}
                    <svg class="w-2.5 h-2.5 text-white" fill="none" stroke="currentColor" stroke-width="3" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/>
                    </svg>
                  {{/if}}
                </span>
                <span class="text-xs text-gray-600 dark:text-gray-300 leading-tight">
                  I'm Over 13 Years Old
                </span>
              </button>
            </div>

            {{! ── Register button ──────────────────────────────────────── }}
            <button
              type="submit"
              disabled={{if this.isFormValid false true}}
              class="w-full py-3.5 px-14 rounded-full font-bold italic uppercase tracking-widest text-sm text-white transition-colors
                {{if this.isFormValid
                     'bg-green-500 hover:bg-green-600 active:bg-green-700'
                     'bg-green-300 dark:bg-green-800 cursor-not-allowed opacity-60'}}"
            >
              {{#if this.isSubmitting}}
                <svg class="w-4 h-4 animate-spin inline-block mr-1" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
                </svg>
              {{/if}}
              Register
            </button>

            {{! ── Sign in link ─────────────────────────────────────────── }}
            <div class="flex items-center justify-center gap-1.5">
              <span class="text-xs text-gray-500 dark:text-gray-400">Already have an account?</span>
              {{#if @onSwitchToLogin}}
                <button
                  type="button"
                  {{on "click" @onSwitchToLogin}}
                  class="text-xs font-semibold text-indigo-600 dark:text-indigo-400 hover:text-indigo-800 dark:hover:text-indigo-300 transition-colors"
                >
                  Sign In
                </button>
              {{else}}
                <LinkTo
                  @route="login"
                  class="text-xs font-semibold text-indigo-600 dark:text-indigo-400 hover:text-indigo-800 dark:hover:text-indigo-300 transition-colors"
                >
                  Sign In
                </LinkTo>
              {{/if}}
            </div>

          </form>

          {{! ── Social auth ───────────────────────────────────────────────── }}
          {{!--
          <div class="px-4 sm:px-6 mt-2 sm:mt-4">
            <div class="flex items-center gap-3">
              <div class="flex-1 h-px bg-gray-200 dark:bg-gray-700"></div>
              <span class="text-xs text-gray-400 dark:text-gray-500 whitespace-nowrap">Or Continue With</span>
              <div class="flex-1 h-px bg-gray-200 dark:bg-gray-700"></div>
            </div>

            <div class="flex gap-3 mt-3">
              {{! Google }}
              <button
                type="button"
                {{on "click" this.handleGoogleSignIn}}
                disabled={{this.isGoogleLoading}}
                class="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-full border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors text-sm font-medium text-gray-700 dark:text-gray-200 disabled:opacity-60 disabled:cursor-not-allowed"
              >
                <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none">
                  <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
                  <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
                  <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/>
                  <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
                </svg>
                {{if this.isGoogleLoading "..." "Google"}}
              </button>

              {{! Facebook }}
              <button
                type="button"
                {{on "click" this.handleFacebookSignIn}}
                disabled={{this.isFacebookLoading}}
                class="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-full border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors text-sm font-medium text-gray-700 dark:text-gray-200 disabled:opacity-60 disabled:cursor-not-allowed"
              >
                <svg class="w-4 h-4" viewBox="0 0 24 24" fill="#1877F2">
                  <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/>
                </svg>
                {{if this.isFacebookLoading "..." "Facebook"}}
              </button>
            </div>

            {{! ── Guest / Login row ─────────────────────────────────────── }}
            <div class="flex items-center gap-3 mt-1.5 sm:mt-3 mb-2 sm:mb-4">
              <button
                type="button"
                class="flex-1 py-2.5 border-2 border-gray-800 dark:border-gray-400 text-gray-900 dark:text-gray-200 font-bold rounded-full uppercase tracking-widest text-xs hover:border-indigo-500 hover:text-indigo-600 transition-colors bg-transparent"
              >
                Continue As Guest
              </button>
              <span class="text-xs text-gray-400 dark:text-gray-500">Or</span>
              {{#if @onSwitchToLogin}}
                <button
                  type="button"
                  {{on "click" @onSwitchToLogin}}
                  class="flex-1 py-2.5 border-2 border-gray-800 dark:border-gray-400 text-gray-900 dark:text-gray-200 font-bold rounded-full uppercase tracking-widest text-xs hover:border-indigo-500 hover:text-indigo-600 transition-colors bg-transparent"
                >
                  Login
                </button>
              {{else}}
                <LinkTo
                  @route="login"
                  class="flex-1 py-2.5 border-2 border-gray-800 dark:border-gray-400 text-gray-900 dark:text-gray-200 font-bold rounded-full uppercase tracking-widest text-xs hover:border-indigo-500 hover:text-indigo-600 transition-colors bg-transparent text-center"
                >
                  Login
                </LinkTo>
              {{/if}}
            </div>
          </div>
          --}}

        </div>

      {{!--
        ═══════════════════════════════════════════════════════════════════
        STEP 2 — OTP Verification (commented out: single-API registration)
        ═══════════════════════════════════════════════════════════════════
        {{else if (eq this.currentStep 2)}}
        <div class="w-full bg-white dark:bg-gray-900 rounded-3xl overflow-hidden">
          ... OTP verification UI removed — registration now completes in
          a single POST to /auth_user/registration/ ...
        </div>
      --}}

      {{! ═══════════════════════════════════════════════════════════════════ }}
      {{! STEP 3 — Sport interests                                           }}
      {{! ═══════════════════════════════════════════════════════════════════ }}
      {{else if (eq this.currentStep 3)}}
        <div class="w-full bg-white dark:bg-gray-900 rounded-3xl overflow-hidden">

          {{! Jersey hero with radial green glow }}
          <div class="relative flex items-end justify-center pt-6 sm:pt-8 min-h-[180px] sm:min-h-[220px]" style="background: radial-gradient(ellipse 75% 85% at 50% 55%, #bbf7d0 0%, #dcfce7 45%, #f0fdf4 70%, transparent 100%);">
            <img
              src="/assets/login_modal/spodium_jersey.png"
              alt="Sports jersey"
              class="relative z-10 h-36 sm:h-44 object-contain drop-shadow-xl"
            />
          </div>

          {{! Content }}
          <div class="px-4 sm:px-6 pb-5 sm:pb-7 pt-4 sm:pt-5 flex flex-col items-center text-center">
            <p class="text-sm text-gray-500 dark:text-gray-400 mb-4">I'm interested in</p>

            {{! Sport chips }}
            <div class="flex flex-wrap justify-center gap-2 mb-6">

              {{! Cricket }}
              <button
                type="button"
                {{on "click" (fn this.toggleField "cricketSelected")}}
                class="flex items-center gap-1.5 px-3.5 py-1.5 rounded-full text-xs font-bold uppercase tracking-wide transition-all
                  {{if this.cricketSelected
                    'bg-white dark:bg-gray-800 shadow-md border border-gray-200 dark:border-gray-600 text-gray-800 dark:text-gray-100 scale-105'
                    'bg-gray-100 dark:bg-gray-800 text-gray-400 dark:text-gray-500 border border-transparent'}}"
              >
                <img src="/assets/register_modal/icon_cricketball.svg" alt="Cricket" class="w-5 h-5" />
                Cricket
              </button>

              {{! Football }}
              <button
                type="button"
                {{on "click" (fn this.toggleField "footballSelected")}}
                class="flex items-center gap-1.5 px-3.5 py-1.5 rounded-full text-xs font-bold uppercase tracking-wide transition-all
                  {{if this.footballSelected
                    'bg-white dark:bg-gray-800 shadow-md border border-gray-200 dark:border-gray-600 text-gray-800 dark:text-gray-100 scale-105'
                    'bg-gray-100 dark:bg-gray-800 text-gray-400 dark:text-gray-500 border border-transparent'}}"
              >
                <img src="/assets/register_modal/icon_football.svg" alt="Football" class="w-5 h-5" />
                Football
              </button>

              {{! Baseball }}
              <button
                type="button"
                {{on "click" (fn this.toggleField "baseballSelected")}}
                class="flex items-center gap-1.5 px-3.5 py-1.5 rounded-full text-xs font-bold uppercase tracking-wide transition-all
                  {{if this.baseballSelected
                    'bg-white dark:bg-gray-800 shadow-md border border-gray-200 dark:border-gray-600 text-gray-800 dark:text-gray-100 scale-105'
                    'bg-gray-100 dark:bg-gray-800 text-gray-400 dark:text-gray-500 border border-transparent'}}"
              >
                <img src="/assets/register_modal/icon_baseball.svg" alt="Baseball" class="w-5 h-5" />
                Baseball
              </button>

            </div>

            {{! Done button }}
            <button
              type="button"
              {{on "click" this.skipToWelcome}}
              disabled={{if this.hasSportSelected false true}}
              class="px-14 py-3 rounded-full font-bold italic uppercase tracking-widest text-sm text-white transition-colors
                {{if this.hasSportSelected
                  'bg-green-500 hover:bg-green-600 active:bg-green-700'
                  'bg-gray-200 dark:bg-gray-700 text-gray-400 dark:text-gray-500 cursor-not-allowed'}}"
            >
              Done!
            </button>

            {{! Skip }}
            <button
              type="button"
              {{on "click" this.skipToWelcome}}
              class="mt-4 flex items-center gap-1 text-xs text-gray-400 dark:text-gray-500 hover:text-gray-600 dark:hover:text-gray-300 transition-colors font-medium"
            >
              Skip
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5"/>
              </svg>
            </button>
          </div>

        </div>

      {{! ═══════════════════════════════════════════════════════════════════ }}
      {{! STEP 4 — Welcome aboard                                            }}
      {{! ═══════════════════════════════════════════════════════════════════ }}
      {{else if (eq this.currentStep 4)}}
        <div class="w-full bg-white dark:bg-gray-900 rounded-3xl overflow-hidden">

          <div class="px-4 sm:px-6 pt-5 sm:pt-7 pb-6 sm:pb-8 flex flex-col items-center text-center">

            {{! Logo }}
            <img src="/spordium_text.svg" alt="Spordium" class="h-7 mb-6" />

            {{! Green checkmark hero }}
            <div class="relative flex items-center justify-center mb-4 sm:mb-5 w-40 h-40 sm:w-[200px] sm:h-[200px] rounded-full" style="background: radial-gradient(ellipse 80% 70% at 50% 50%, #bbf7d0 0%, #dcfce7 50%, transparent 100%);">
              <img
                src="/assets/register_modal/Onboarding-Image.png"
                alt="Success"
                class="w-28 h-28 sm:w-36 sm:h-36 object-contain drop-shadow-xl"
              />
            </div>

            {{! Heading }}
            <h2 class="text-xl font-bold italic text-gray-800 dark:text-gray-100 mb-2">
              Welcome Aboard!
            </h2>
            <p class="text-xs text-gray-400 dark:text-gray-500 mb-6 leading-relaxed">
              Continue Exploring<br />or check your profile
            </p>

            {{! Action buttons }}
            <div class="flex gap-3 w-full">
              <button
                type="button"
                {{on "click" this.goToProfile}}
                class="flex-1 py-2.5 border-2 border-gray-700 dark:border-gray-400 text-gray-800 dark:text-gray-200 font-bold rounded-full uppercase tracking-widest text-xs hover:border-indigo-500 hover:text-indigo-600 transition-colors bg-transparent"
              >
                My Profile
              </button>
              <button
                type="button"
                {{on "click" this.goHome}}
                class="flex-1 py-2.5 bg-green-500 hover:bg-green-600 active:bg-green-700 text-white font-bold rounded-full uppercase tracking-widest text-xs transition-colors"
              >
                Home
              </button>
            </div>

          </div>
        </div>
      {{/if}}
    </div>

    {{! ── Terms & Conditions Modal ─────────────────────────────────────── }}
    {{#if this.showTermsModal}}
      {{#in-element this.documentBody insertBefore=null}}
        <TermsModal
          @onAccept={{this.acceptTerms}}
          @onDecline={{this.declineTerms}}
        />
      {{/in-element}}
    {{/if}}
  </template>
}
