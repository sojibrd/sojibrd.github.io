import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { service } from '@ember/service';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { LinkTo } from '@ember/routing';
import { htmlSafe } from '@ember/template';
import { eq } from 'ember-truth-helpers';
import config from 'spordium/config/environment';

const SLIDES = [
  {
    image: '/assets/login_modal/spodium_jersey.png',
    line1: 'Create your Profile',
    line2: '& Share Stats',
    origin:{x:'50%',y:'20%'},
    bg: '#e8fdf5',
    darkBg: '#052e16',
    glow: 'radial-gradient(ellipse at 15% 20%, rgba(255,255,255,1) 1%, rgba(45,212,191,0.75) 45%, rgba(20,184,166,0.2) 40%, rgba(20,184,166,0) 5%)',
    glowDark: 'radial-gradient(ellipse at 15% 20%, rgba(45,212,191,0.18) 1%, rgba(20,184,166,0.09) 15%, rgba(20,184,166,0) 10%)',
  },
  {
    image: '/assets/login_modal/spordium_stadium.png',
    line1: 'Book A Facility',
    line2: 'or Add Yours',
    origin:{x:'50%',y:'20%'},
    bg: '#ecfdf5',
    darkBg: '#052e16',
    glow: 'radial-gradient(ellipse at 15% 20%, rgba(255,255,255,1) 1%, rgba(250,204,21,0.8) 40%, rgba(134,239,172,0.3) 40%, rgba(134,239,172,0) 5%)',
    glowDark: 'radial-gradient(ellipse at 15% 20%, rgba(250,204,21,0.15) 10%, rgba(134,239,172,0.08) 15%, rgba(134,239,172,0) 10%)',
  },
  {
    image: '/assets/login_modal/spordium_tennis.png',
    line1: 'Create Your Club',
    line2: '& Join in 96 Clubs',
    origin:{x:'50%',y:'40%'},
    bg: '#fdf2f8',
    darkBg: '#4c0519',
    glow: 'radial-gradient(ellipse at 15% 20%, rgba(255,255,255,1) 1%, rgba(249,168,212,0.85) 40%, rgba(225,29,72,0.25) 40%, rgba(190,18,60,0) 5%)',
    glowDark: 'radial-gradient(ellipse at 15% 20%, rgba(249,168,212,0.15) 10%, rgba(225,29,72,0.08) 15%, rgba(190,18,60,0) 5%)',
  },
  {
    image: '/assets/login_modal/spordium_team.png',
    line1: 'Create Your Team',
    line2: 'Or Join Other Teams!',
    origin:{x:'50%',y:'100%'},
    bg: '#eef2ff',
    darkBg: '#1e1b4b',
    glow: 'radial-gradient(ellipse at 15% 20%, rgba(255,255,255,1) 1%, rgba(56,189,248,0.75) 40%, rgba(74,222,128,0.3) 40%, rgba(74,222,128,0) 5%)',
    glowDark: 'radial-gradient(ellipse at 15% 20%, rgba(56,189,248,0.15) 1%, rgba(74,222,128,0.08) 15%, rgba(74,222,128,0) 5%)',
  },
  {
    image: '/assets/login_modal/spordium_score.png',
    line1: 'Setup a Match',
    line2: '& Watch Live',
    origin:{x:'50%',y:'120%'},
    bg: '#fff1f2',
    darkBg: '#4c0519',
    glow: 'radial-gradient(ellipse at 15% 20%, rgba(255,255,255,1) 1%, rgba(249,168,212,0.85) 40%, rgba(225,29,72,0.25) 40%, rgba(190,18,60,0) 5%)',
    glowDark: 'radial-gradient(ellipse at 15% 20%, rgba(249,168,212,0.15) 1%, rgba(225,29,72,0.08) 15%, rgba(190,18,60,0) 5%)',
  },
];

export default class LoginFormComponent extends Component {
  @service session;
  @service toast;
  @service socialAuth;
  @service geolocation;

  @tracked email = '';
  @tracked password = '';
  @tracked emailError = '';
  @tracked passwordError = '';
  @tracked errorMessage = '';
  @tracked isSubmitting = false;
  @tracked isGoogleLoading = false;
  @tracked isFacebookLoading = false;
  @tracked currentSlide = 0;
  @tracked showPassword = false;
  @tracked currentStep = 1;
  @tracked otpCode = '';
  @tracked resendCountdown = 0;

  _slideTimer = null;
  _otpTimer = null;

  #emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

  constructor(owner, args) {
    super(owner, args);
    this.#startAutoSlide();
  }

  willDestroy() {
    super.willDestroy();
    clearInterval(this._slideTimer);
    clearInterval(this._otpTimer);
  }

  get resendDisplay() {
    const m = Math.floor(this.resendCountdown / 60);
    const s = this.resendCountdown % 60;
    return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  }

  #startResendCountdown() {
    this.resendCountdown = 300;
    clearInterval(this._otpTimer);
    this._otpTimer = setInterval(() => {
      this.resendCountdown -= 1;
      if (this.resendCountdown <= 0) {
        this.resendCountdown = 0;
        clearInterval(this._otpTimer);
      }
    }, 1000);
  }

  #startAutoSlide() {
    this._slideTimer = setInterval(() => {
      this.currentSlide = (this.currentSlide + 1) % SLIDES.length;
    }, 5000);
  }

  get slide() {
    return SLIDES[this.currentSlide];
  }

  get slideItems() {
    return SLIDES.map((_, i) => ({ index: i, isActive: i === this.currentSlide, isUp: i % 2 === 1 }));
  }

  get bannerBgStyle() {
    const s = this.slide;
    return htmlSafe(
      `background-color: ${s.bg};` +
      `border-bottom-left-radius: 50% 72px;` +
      `border-bottom-right-radius: 50% 72px;`
    );
  }

  get bannerBgDarkStyle() {
    const s = this.slide;
    return htmlSafe(
      `background-color: ${s.darkBg};` +
      `border-bottom-left-radius: 50% 72px;` +
      `border-bottom-right-radius: 50% 72px;`
    );
  }

  get glowBgStyle() {
    return htmlSafe(`position: absolute; inset: 0; background: ${this.slide.glow};`);
  }

  get glowBgDarkStyle() {
    return htmlSafe(`position: absolute; inset: 0; background: ${this.slide.glowDark};`);
  }

  get dotIndicatorStyle() {
    // Each dot: w-2 = 8px, gap-2.5 = 10px → step = 18px
    // Even-index dots sit 6px above the baseline (isUp), odd-index dots sit at baseline
    const xOffset = this.currentSlide * 18;
    const yOffset = this.currentSlide % 2 === 1 ? -11 : 0;
    return htmlSafe(
      `transform: translate(${xOffset}px, ${yOffset}px);` +
      `transition: transform 500ms cubic-bezier(0.4, 0, 0.2, 1);`
    );
  }

  @action
  goToSlide(index) {
    this.currentSlide = index;
    clearInterval(this._slideTimer);
    this.#startAutoSlide();
  }

  @action
  updateField(field, event) {
    this[field] = event.target.value;
    if (field === 'email') this.emailError = '';
    if (field === 'password') this.passwordError = '';
  }

  @action
  toggleShowPassword() {
    this.showPassword = !this.showPassword;
  }

  #validate() {
    let valid = true;
    if (!this.email.trim()) {
      this.emailError = 'Email is required.';
      valid = false;
    } else if (!this.#emailRegex.test(this.email.trim())) {
      this.emailError = 'Please enter a valid email address.';
      valid = false;
    }
    if (!this.password) {
      this.passwordError = 'Password is required.';
      valid = false;
    } else if (this.password.length < 6) {
      this.passwordError = 'Password must be at least 6 characters.';
      valid = false;
    }
    return valid;
  }

  @action
  async handleSubmit(event) {
    event.preventDefault();
    this.errorMessage = '';
    if (!this.#validate()) return;
    this.isSubmitting = true;
    try {
      await this.session.authenticate('authenticator:credentials', this.email.trim(), this.password);
      this.args.onClose?.();
    } catch (err) {
      this.errorMessage = err?.message || 'Login failed. Please check your credentials.';
    } finally {
      this.isSubmitting = false;
    }
  }

  @action
  goBackToLogin() {
    this.currentStep = 1;
    this.otpCode = '';
    this.resendCountdown = 0;
    clearInterval(this._otpTimer);
  }

  @action
  updateOtpCode(event) {
    this.otpCode = event.target.value;
  }

  @action
  requestOtpAgain() {
    if (this.resendCountdown > 0) return;
    this.otpCode = '';
    this.#startResendCountdown();
  }

  @action
  handleForgotPassword() {
    this.args.onForgotPassword?.(this.email.trim());
  }

  @action
  async handleGoogleSignIn() {
    this.isGoogleLoading = true;
    this.errorMessage = '';
    try {
      const authToken = await this.socialAuth.getGoogleToken();

      // ── Resolve location ────────────────────────────────────────────────────
      const DEFAULT_LAT = 23.790552;
      const DEFAULT_LNG = 90.400084;
      let lat = DEFAULT_LAT;
      let lng = DEFAULT_LNG;

      try {
        const { getUserLocation } = await import('../../utils/utility.helper');
        const mapData = await getUserLocation();
        if (mapData?.geo) {
          lat = mapData.geo.lat;
          lng = mapData.geo.long;
        }
      } catch { /* use default coords */ }

      // ── Reverse geocode ─────────────────────────────────────────────────────
      let country = '', countryCode = '', state = '', city = '', address = '';
      try {
        const apiKey = config.APP.GOOGLE_MAPS_API_KEY;
        if (apiKey) {
          const res = await fetch(
            `https://maps.googleapis.com/maps/api/geocode/json?latlng=${lat},${lng}&key=${apiKey}`
          );
          const geoData = await res.json();
          if (geoData.status === 'OK' && geoData.results.length) {
            const components = geoData.results.flatMap((r) => r.address_components);
            const find = (type) => components.find((c) => c.types.includes(type));
            const countryComp = find('country');
            const stateComp   = find('administrative_area_level_1');
            const cityComp    = find('locality') || find('administrative_area_level_2');
            country     = countryComp?.long_name  || '';
            countryCode = countryComp?.short_name || '';
            state       = stateComp?.long_name    || '';
            city        = cityComp?.long_name     || '';
            address     = geoData.results[0]?.formatted_address || '';
          }
        }
      } catch { /* send empty strings if geocode fails */ }

      const payload = {
        auth_token:          authToken,
        user_country:        country,
        user_state_divition: state,
        user_playing_city:   city,
        address,
        country_code:        countryCode,
        latitude:            String(lat),
        longitude:           String(lng),
      };
      const res = await fetch(`${config.APP.API_HOST}/social_auth/google/`, {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify(payload),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data?.message || data?.detail || 'Google sign-in failed');
      const { tokens, ...user } = data;
      this.session.setAuthenticatedFromTokens(tokens, user);
      this.args.onClose?.();
    } catch (err) {
      this.errorMessage = err.message || 'Google sign-in failed. Please try again.';
    } finally {
      this.isGoogleLoading = false;
    }
  }

  @action
  async handleFacebookSignIn() {
    this.isFacebookLoading = true;
    this.errorMessage = '';
    try {
      const authToken = await this.socialAuth.getFacebookToken();

      // ── Resolve location ────────────────────────────────────────────────────
      const DEFAULT_LAT = 23.790552;
      const DEFAULT_LNG = 90.400084;
      let lat = DEFAULT_LAT;
      let lng = DEFAULT_LNG;

      try {
        const { getUserLocation } = await import('../../utils/utility.helper');
        const mapData = await getUserLocation();
        if (mapData?.geo) {
          lat = mapData.geo.lat;
          lng = mapData.geo.long;
        }
      } catch { /* use default coords */ }

      // ── Reverse geocode ─────────────────────────────────────────────────────
      let country = '', countryCode = '', state = '', city = '', address = '';
      try {
        const apiKey = config.APP.GOOGLE_MAPS_API_KEY;
        if (apiKey) {
          const res = await fetch(
            `https://maps.googleapis.com/maps/api/geocode/json?latlng=${lat},${lng}&key=${apiKey}`
          );
          const geoData = await res.json();
          if (geoData.status === 'OK' && geoData.results.length) {
            const components = geoData.results.flatMap((r) => r.address_components);
            const find = (type) => components.find((c) => c.types.includes(type));
            const countryComp = find('country');
            const stateComp   = find('administrative_area_level_1');
            const cityComp    = find('locality') || find('administrative_area_level_2');
            country     = countryComp?.long_name  || '';
            countryCode = countryComp?.short_name || '';
            state       = stateComp?.long_name    || '';
            city        = cityComp?.long_name     || '';
            address     = geoData.results[0]?.formatted_address || '';
          }
        }
      } catch { /* send empty strings if geocode fails */ }

      const payload = {
        auth_token:          authToken,
        user_country:        country,
        user_state_divition: state,
        user_playing_city:   city,
        address,
        country_code:        countryCode,
        latitude:            String(lat),
        longitude:           String(lng),
      };
      const res = await fetch(`${config.APP.API_HOST}/social_auth/facebook/`, {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify(payload),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data?.message || data?.detail || 'Facebook sign-in failed');
      const { tokens, ...user } = data;
      this.session.setAuthenticatedFromTokens(tokens, user);
      this.args.onClose?.();
    } catch (err) {
      this.errorMessage = err.message || 'Facebook sign-in failed. Please try again.';
    } finally {
      this.isFacebookLoading = false;
    }
  }

  @action
  handleSocialError(message) {
    this.errorMessage = message;
  }

  <template>
    {{! Outer wrapper — page background only on standalone }}
    <div class={{if @isModal "overflow-hidden" "min-h-screen flex items-center justify-center p-3 sm:p-6 overflow-hidden"}}>

      {{! ── Card ── }}
      <div class="w-full max-w-sm bg-white dark:bg-gray-900 rounded-[2rem] overflow-hidden">

      {{! ══════════════════════════════════════════
          STEP 2 — OTP Verification
      ══════════════════════════════════════════ }}
      {{#if (eq this.currentStep 2)}}

        {{! ── OTP hero: Spordium logo + lock image on warm stage ── }}
        <div
          class="relative flex flex-col items-center pt-6 pb-8"
          style="background: radial-gradient(ellipse 100% 75% at 50% 100%, #fde8c0 0%, #fef6e8 45%, #ffffff 100%); border-bottom-left-radius: 50% 32px; border-bottom-right-radius: 50% 32px;"
        >
          {{! Back button }}
          <button
            type="button"
            {{on "click" this.goBackToLogin}}
            aria-label="Back to login"
            class="absolute top-4 left-4 p-1.5 rounded-full text-gray-400 hover:text-gray-600 dark:text-gray-500 dark:hover:text-gray-300 hover:bg-black/5 transition-colors z-10"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M15 19l-7-7 7-7"/>
            </svg>
          </button>

          {{! Spordium logo }}
          <img src="/spordium_text.svg" alt="Spordium" class="h-8 mb-5" />

          {{! Lock image + oval cast shadow ── }}
          <div class="relative flex items-end justify-center w-full" style="height: 180px;">
            {{! Soft oval shadow beneath the lock — the "stage curve" }}
            <div
              class="absolute bottom-0 left-1/2 -translate-x-1/2 z-0"
              style="width: 65%; height: 22px; border-radius: 50%; background: radial-gradient(ellipse 100% 100% at 50% 50%, rgba(234,88,12,0.22) 0%, rgba(234,88,12,0.06) 60%, transparent 100%); filter: blur(6px);"
            ></div>
            <img
              src="/assets/login_modal/otp_lock.png"
              alt="OTP Lock"
              class="relative z-10 h-40 object-contain"
              style="transform: translateY(6px);"
            />
          </div>
        </div>

        {{! ── Form area ── }}
        <div class="bg-white dark:bg-gray-900 px-6 pt-5 pb-7">

          {{! Heading }}
          <h2 class="text-center text-lg font-bold italic text-gray-800 dark:text-gray-100 mb-4">
            Verify With OTP
          </h2>

          {{! OTP input }}
          <div class="relative mb-4">
            <span class="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400 dark:text-gray-500 pointer-events-none">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z"/>
              </svg>
            </span>
            <input
              type="text"
              inputmode="numeric"
              maxlength="6"
              value={{this.otpCode}}
              {{on "input" this.updateOtpCode}}
              placeholder="Enter OTP"
              class="w-full pl-10 pr-4 py-3 rounded-full bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-200 placeholder-gray-400 dark:placeholder-gray-500 text-sm border-2 border-transparent focus:border-indigo-300 dark:focus:border-indigo-600 focus:outline-none transition-colors tracking-widest"
            />
          </div>

          {{! Resend row }}
          <div class="text-center mb-5">
            <p class="text-xs text-gray-500 dark:text-gray-400 mb-1">Didn't Receive Code?</p>
            <div class="flex items-center justify-center gap-1.5">
              {{#if this.resendCountdown}}
                <span class="text-sm font-bold text-indigo-600 dark:text-indigo-400 tabular-nums">
                  {{this.resendDisplay}}
                </span>
                <span class="text-sm text-gray-500 dark:text-gray-400">To Request Again</span>
              {{else}}
                <button
                  type="button"
                  {{on "click" this.requestOtpAgain}}
                  class="text-sm font-bold text-indigo-600 dark:text-indigo-400 hover:underline transition-colors"
                >
                  Resend OTP
                </button>
                <svg class="w-3.5 h-3.5 text-indigo-500 dark:text-indigo-400" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5"/>
                </svg>
              {{/if}}
            </div>
          </div>

          {{! Submit button }}
          <div class="flex justify-center">
            <button
              type="button"
              class="py-3 px-14 rounded-full font-bold uppercase tracking-widest text-sm text-white transition-colors
                {{if this.otpCode
                  'bg-green-500 hover:bg-green-600 active:bg-green-700'
                  'bg-green-300 dark:bg-green-800 cursor-not-allowed'}}"
            >
              Submit
            </button>
          </div>

        </div>

      {{else}}

        {{! ══════════════════════════════════════════
            BANNER — colored bg + convex bottom curve
            Layout (top → bottom):
              1. Logo
              2. Title / subtitle
              3. Image container (overflow-hidden keeps image inside curve)
        ══════════════════════════════════════════ }}

        {{! ── Light-mode banner ── }}
        <div
          class="dark:hidden overflow-hidden"
          style={{this.bannerBgStyle}}
        >
          {{! 1. Logo }}
          <div class="flex justify-center pt-5 pb-1">
            <img src="/spordium_text.svg" alt="Spordium" class="h-8" />
          </div>

          {{! 2. Title + subtitle — always visible, never behind the image }}
          <div class="text-center px-4 mb-3">
            <p class="text-[1.1rem] font-bold italic text-indigo-800 leading-tight">
              {{this.slide.line1}}
            </p>
            <p class="text-sm italic text-indigo-500 leading-tight">
              {{this.slide.line2}}
            </p>
          </div>

          {{! 3. Image container — glow behind, image pushed down into the curve }}
          <div class="relative flex items-end justify-center" style="height: 200px;">
            <div class="z-0 pointer-events-none" style={{this.glowBgStyle}}></div>
            <img
              src={{this.slide.image}}
              alt={{this.slide.line1}}
              class="relative z-10 w-full h-full object-contain object-bottom pointer-events-none"
              style="transform: translateY(28px);"
            />
          </div>
        </div>

        {{! ── Dark-mode banner ── }}
        <div
          class="hidden dark:block overflow-hidden"
          style={{this.bannerBgDarkStyle}}
        >
          {{! 1. Logo }}
          <div class="flex justify-center pt-5 pb-1">
            <img src="/spordium_text.svg" alt="Spordium" class="h-8" />
          </div>

          {{! 2. Title + subtitle }}
          <div class="text-center px-4 mb-3">
            <p class="text-[1.1rem] font-bold italic text-white leading-tight">
              {{this.slide.line1}}
            </p>
            <p class="text-sm italic text-indigo-300 leading-tight">
              {{this.slide.line2}}
            </p>
          </div>

          {{! 3. Image container }}
          <div class="relative flex items-end justify-center" style="height: 200px;">
            <div class="z-0 pointer-events-none" style={{this.glowBgDarkStyle}}></div>
            <img
              src={{this.slide.image}}
              alt={{this.slide.line1}}
              class="relative z-10 w-full h-full object-contain object-bottom pointer-events-none"
              style="transform: translateY(28px);"
            />
          </div>
        </div>

        {{! ── Dot pagination (below curve, white area) ── }}
        <div class="flex items-center justify-center pt-2 pb-1 sm:pt-5 sm:pb-2">
          {{! Extra height so the upper dots aren't clipped }}
          <div class="relative flex items-end gap-2.5" style="height: 20px;">
            {{! Sliding active indicator — translates both X and Y to follow pattern }}
            <div
              class="absolute w-2 h-2 rounded-full bg-indigo-500 dark:bg-indigo-400 pointer-events-none"
              style={{this.dotIndicatorStyle}}
              aria-hidden="true"
            ></div>
            {{! Ghost dots — even indices sit 6px above baseline (triangular pattern) }}
            {{#each this.slideItems as |item|}}
              <button
                type="button"
                {{on "click" (fn this.goToSlide item.index)}}
                aria-label="Go to slide {{item.index}}"
                style={{if item.isUp "transform: translateY(-11px);" "transform: translateY(0);"}}
                class="w-2 h-2 rounded-full border border-gray-400 dark:border-gray-500 bg-transparent hover:border-indigo-400 dark:hover:border-indigo-400 transition-colors duration-200 flex-shrink-0"
              ></button>
            {{/each}}
          </div>
        </div>

        {{! ══════════════════════════════════════════
            FORM SECTION
        ══════════════════════════════════════════ }}
        <div class="px-4 sm:px-7 pt-1 sm:pt-3 pb-4 sm:pb-8">

          {{! Sign In title }}
          <h2 class="text-center text-[1.45rem] font-bold italic text-indigo-700 dark:text-indigo-300 mb-2 sm:mb-5">
            Sign In
          </h2>

          {{#if this.errorMessage}}
            <div class="mb-3 px-4 py-2.5 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-2xl text-sm text-red-600 dark:text-red-400 text-center">
              {{this.errorMessage}}
            </div>
          {{/if}}

          <form {{on "submit" this.handleSubmit}} class="space-y-2 sm:space-y-3">

            {{! Email / Name }}
            <div>
              <div class="relative">
                <span class="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400 dark:text-gray-500 pointer-events-none">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                  </svg>
                </span>
                <input
                  type="email"
                  value={{this.email}}
                  {{on "input" (fn this.updateField "email")}}
                  autocomplete="email"
                  placeholder="Email or Phone"
                  class="w-full pl-10 pr-4 py-3 rounded-full bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-200 placeholder-gray-400 dark:placeholder-gray-500 text-sm border-2 border-transparent focus:border-indigo-300 dark:focus:border-indigo-600 focus:outline-none transition-colors
                    {{if this.emailError 'border-red-300 dark:border-red-600' ''}}"
                />
              </div>
              {{#if this.emailError}}
                <p class="mt-1 ml-4 text-xs text-red-500 dark:text-red-400">{{this.emailError}}</p>
              {{/if}}
            </div>

            {{! Password }}
            <div>
              <div class="relative">
                <span class="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400 dark:text-gray-500 pointer-events-none">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                  </svg>
                </span>
                <input
                  type={{if this.showPassword "text" "password"}}
                  value={{this.password}}
                  {{on "input" (fn this.updateField "password")}}
                  autocomplete="current-password"
                  placeholder="Password"
                  class="w-full pl-10 pr-11 py-3 rounded-full bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-200 placeholder-gray-400 dark:placeholder-gray-500 text-sm border-2 border-transparent focus:border-indigo-300 dark:focus:border-indigo-600 focus:outline-none transition-colors
                    {{if this.passwordError 'border-red-300 dark:border-red-600' ''}}"
                />
                <button
                  type="button"
                  {{on "click" this.toggleShowPassword}}
                  class="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400 dark:text-gray-500 hover:text-gray-500 dark:hover:text-gray-400 transition-colors"
                >
                  {{#if this.showPassword}}
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 4.411m0 0L21 21" />
                    </svg>
                  {{else}}
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                      <path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                    </svg>
                  {{/if}}
                </button>
              </div>
              {{#if this.passwordError}}
                <p class="mt-1 ml-4 text-xs text-red-500 dark:text-red-400">{{this.passwordError}}</p>
              {{/if}}
            </div>

            {{! Forgot password }}
            <div class="text-center pt-0.5">
              <button
                type="button"
                {{on "click" this.handleForgotPassword}}
                class="text-xs font-bold text-indigo-600 dark:text-indigo-400 uppercase tracking-wider hover:underline"
              >
                Forgot Password?
              </button>
            </div>

            {{!-- Social login (kept for future use)
            <div>
              <div class="flex items-center gap-3 mb-2">
                <div class="flex-1 h-px bg-gray-200 dark:bg-gray-700"></div>
                <span class="text-xs text-gray-400 dark:text-gray-500 whitespace-nowrap">Or Continue With</span>
                <div class="flex-1 h-px bg-gray-200 dark:bg-gray-700"></div>
              </div>
              <div class="flex gap-3">
                <button
                  type="button"
                  {{on "click" this.handleGoogleSignIn}}
                  disabled={{this.isGoogleLoading}}
                  class="flex-1 flex items-center justify-center gap-2 py-2 px-3 rounded-full border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors text-sm font-semibold text-gray-700 dark:text-gray-200 disabled:opacity-60 disabled:cursor-not-allowed"
                >
                  <img src="/assets/login_modal/social_google.svg" alt="Google" class="w-4 h-4 shrink-0" />
                  {{if this.isGoogleLoading "..." "Google"}}
                </button>
                <button
                  type="button"
                  {{on "click" this.handleFacebookSignIn}}
                  disabled={{this.isFacebookLoading}}
                  class="flex-1 flex items-center justify-center gap-2 py-2 px-3 rounded-full border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors text-sm font-semibold text-gray-700 dark:text-gray-200 disabled:opacity-60 disabled:cursor-not-allowed"
                >
                  <img src="/assets/login_modal/social_facebook.svg" alt="Facebook" class="w-4 h-4 shrink-0" />
                  {{if this.isFacebookLoading "..." "Facebook"}}
                </button>
              </div>
            </div>
            --}}

            {{! Sign In submit }}
            <div class="flex justify-center">
              <button
                type="submit"
                disabled={{this.isSubmitting}}
                class="py-3.5 px-14 bg-green-500 hover:bg-green-600 active:bg-green-700 disabled:opacity-60 disabled:cursor-not-allowed text-white font-bold rounded-full uppercase tracking-widest text-sm transition-colors"
              >
                {{if this.isSubmitting "Signing In..." "Sign In"}}
              </button>
            </div>

          </form>

          {{! Register section }}
          <p class="mt-2 sm:mt-5 text-center text-sm text-gray-500 dark:text-gray-400">
            Don't have an account?
          </p>
          <div class="mt-1.5 sm:mt-2.5 flex justify-center">
            {{#if @onSwitchToSignup}}
              <button
                type="button"
                {{on "click" @onSwitchToSignup}}
                class="py-2.5 px-10 border-2 border-gray-800 dark:border-gray-400 text-gray-900 dark:text-gray-200 font-bold rounded-full uppercase tracking-widest text-sm hover:border-indigo-500 hover:text-indigo-600 dark:hover:border-indigo-400 dark:hover:text-indigo-400 transition-colors bg-transparent"
              >
                Register
              </button>
            {{else}}
              <LinkTo
                @route="signup"
                class="py-2.5 px-10 border-2 border-gray-800 dark:border-gray-400 text-gray-900 dark:text-gray-200 font-bold rounded-full uppercase tracking-widest text-sm hover:border-indigo-500 hover:text-indigo-600 dark:hover:border-indigo-400 dark:hover:text-indigo-400 transition-colors text-center"
              >
                Register
              </LinkTo>
            {{/if}}
          </div>

          {{! Continue as guest }}
          <div class="mt-2 sm:mt-4 flex items-center justify-center gap-1.5">
            <span class="text-sm text-gray-500 dark:text-gray-400">Or</span>
            <button
              type="button"
              {{on "click" @onClose}}
              class="text-sm font-bold text-indigo-600 dark:text-indigo-400 uppercase tracking-wider hover:underline transition-colors"
            >
              Continue As Guest
            </button>
            <span class="text-sm text-indigo-600 dark:text-indigo-400">&rsaquo;</span>
          </div>

        </div>

      {{/if}}
      </div>
    </div>
  </template>
}
