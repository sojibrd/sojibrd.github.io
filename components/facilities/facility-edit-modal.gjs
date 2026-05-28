import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { service } from '@ember/service';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { eq } from 'ember-truth-helpers';
import { helper } from '@ember/component/helper';
import lucideIcon from 'spordium/helpers/lucide-icon';
import EmailOtpVerifier from '../clubs/create/email-otp-verifier';
import PhoneOtpVerifier from '../clubs/create/phone-otp-verifier';
import RichTextEditor   from '../clubs/create/rich-text-editor';

const API_BASE = 'https://spordiumapi.adnanfoundation.com';

const FONT_FAMILIES = ['Arial', 'Georgia', 'Times New Roman', 'Courier New', 'Verdana'];
const FONT_SIZES = [
  { label: 'Small',   value: '2' },
  { label: 'Normal',  value: '3' },
  { label: 'Large',   value: '4' },
  { label: 'X-Large', value: '5' },
];

const SPORTS = [
  'football', 'cricket', 'basketball', 'badminton', 'tennis',
  'volleyball', 'hockey', 'rugby', 'baseball', 'swimming',
  'table tennis', 'golf', 'boxing', 'athletics', 'cycling',
];

const TABS = [
  { id: 'basic',    label: 'Basic',    icon: 'info' },
  { id: 'location', label: 'Location', icon: 'map-pin' },
  { id: 'sports',   label: 'Sports',   icon: 'trophy' },
  { id: 'managers', label: 'Managers', icon: 'users' },
  { id: 'content',  label: 'Content',  icon: 'file-text' },
  { id: 'social',   label: 'Social',   icon: 'link' },
];

const sportSelected = helper(([sports, sport]) => (sports ?? []).includes(sport));

export default class FacilityEditModal extends Component {
  @service session;
  @service toast;

  // ── Tab state ──────────────────────────────────────────────────────────────
  @tracked activeTab = 'basic';

  // ── Basic ──────────────────────────────────────────────────────────────────
  @tracked facName             = '';
  @tracked facUrl              = '';
  @tracked facUrlName          = '';
  @tracked facEstablishedDate  = '';
  @tracked facStatus           = false;
  @tracked facCellPhone        = '';
  @tracked facWebsite          = '';

  // ── Location ───────────────────────────────────────────────────────────────
  @tracked facAddress          = '';
  @tracked facCity             = '';
  @tracked facDistrict         = '';
  @tracked facDivision         = '';
  @tracked facCountry          = '';
  @tracked facPostCode         = '';
  @tracked facLat              = '';
  @tracked facLong             = '';
  @tracked googleMapLink       = '';

  // ── Sports ─────────────────────────────────────────────────────────────────
  @tracked facSports           = [];

  // ── Managers ───────────────────────────────────────────────────────────────
  @tracked facManager1         = '';
  @tracked facManager1Name     = '';
  @tracked facManager2         = '';
  @tracked facManager2Name     = '';
  @tracked facManager3         = '';
  @tracked facManager3Name     = '';

  // ── Content ────────────────────────────────────────────────────────────────
  @tracked facDescription      = '';
  @tracked facAboutUs          = '';

  // ── Social ─────────────────────────────────────────────────────────────────
  @tracked facFacebook         = '';
  @tracked facInstagram        = '';
  @tracked facTwitter          = '';
  @tracked facYoutube          = '';
  @tracked facVideoLink        = '';

  // ── Email OTP ──────────────────────────────────────────────────────────────
  @tracked facEmail            = '';
  @tracked emailVerified       = false;
  @tracked emailOtpSent        = false;
  @tracked otpValue            = '';
  @tracked otpError            = null;
  @tracked isSendingOtp        = false;
  @tracked isVerifyingOtp      = false;
  @tracked emailOtpToken       = null;
  @tracked emailVerifiedToken  = null;

  // ── Phone OTP ──────────────────────────────────────────────────────────────
  @tracked phoneVerified       = false;
  @tracked phoneOtpSent        = false;
  @tracked phoneOtpValue       = '';
  @tracked phoneOtpHint        = null;
  @tracked phoneOtpToken       = null;
  @tracked phoneVerifiedToken  = null;
  @tracked phoneOtpError       = null;
  @tracked isSendingPhoneOtp   = false;
  @tracked isVerifyingPhoneOtp = false;

  // ── Submit state ───────────────────────────────────────────────────────────
  @tracked isSaving            = false;

  constructor(owner, args) {
    super(owner, args);
    this.#init();
  }

  // Non-tracked initial HTML — passed once to RichTextEditor's @initialHtml.
  // Keeping these non-tracked prevents the modifier from re-running on edits.
  _initialDescription = '';
  _initialAboutUs     = '';

  #init() {
    const f = this.args.facility;
    if (!f) return;

    this.facEmail           = f.fac_email           ?? '';
    this.facName            = f.fac_name            ?? '';
    this.facUrl             = f.fac_url             ?? '';
    this.facUrlName         = f.fac_url_name        ?? f.fac_url ?? '';
    this.facEstablishedDate = f.fac_established_date ?? '';
    this.facStatus          = f.fac_status          === true || f.fac_status === 'true';
    this.facCellPhone       = f.fac_cell_phone      ?? '';
    this.facWebsite         = f.fac_website         ?? '';

    this.facAddress         = f.fac_address         ?? '';
    this.facCity            = f.fac_city            ?? '';
    this.facDistrict        = f.fac_district        ?? '';
    this.facDivision        = f.fac_division        ?? '';
    this.facCountry         = f.fac_country         ?? '';
    this.facPostCode        = f.fac_post_code        ?? '';
    this.facLat             = f.fac_lat             ?? '';
    this.facLong            = f.fac_long            ?? '';
    this.googleMapLink      = f.google_map_link      ?? '';

    this.facSports          = Array.isArray(f.fac_sports) ? [...f.fac_sports] : [];

    this.facManager1        = f.fac_manager_1       ?? '';
    this.facManager1Name    = f.fac_manager_1_name  ?? '';
    this.facManager2        = f.fac_manager_2       ?? '';
    this.facManager2Name    = f.fac_manager_2_name  ?? '';
    this.facManager3        = f.fac_manager_3       ?? '';
    this.facManager3Name    = f.fac_manager_3_name  ?? '';

    this.facDescription         = f.fac_description ?? '';
    this.facAboutUs             = f.fac_about_us    ?? '';
    this._initialDescription    = this.facDescription;
    this._initialAboutUs        = this.facAboutUs;

    this.facFacebook        = (f.fac_facebook   ?? []).filter(Boolean).join('\n');
    this.facInstagram       = (f.fac_instagram  ?? []).filter(Boolean).join('\n');
    this.facTwitter         = (f.fac_twitter    ?? []).filter(Boolean).join('\n');
    this.facYoutube         = (f.fac_youtube    ?? []).filter(Boolean).join('\n');
    this.facVideoLink       = (f.fac_video_link ?? []).filter(Boolean).join('\n');
  }

  #splitLines(str) {
    return (str ?? '').split('\n').map((l) => l.trim()).filter(Boolean);
  }

  get tabs()        { return TABS; }
  get sports()      { return SPORTS; }
  get fontFamilies(){ return FONT_FAMILIES; }
  get fontSizes()   { return FONT_SIZES; }

  get authHeaders() {
    return {
      Authorization:  `Bearer ${this.session.data?.authenticated?.token ?? ''}`,
      'Content-Type': 'application/json',
    };
  }

  get normalizedPhone() {
    let p = this.facCellPhone.trim().replace(/\D/g, '');
    p = p.replace(/^0+/, '');
    if (p.startsWith('880')) return `+${p}`;
    return `+880${p}`;
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  @action setTab(tabId) {
    this.activeTab = tabId;
  }

  @action set(field, e) {
    this[field] = e.target.value;
  }

  @action toggleStatus() {
    this.facStatus = !this.facStatus;
  }

  @action toggleSport(sport) {
    const current = [...this.facSports];
    const idx = current.indexOf(sport);
    if (idx === -1) {
      current.push(sport);
    } else {
      current.splice(idx, 1);
    }
    this.facSports = current;
  }

  @action handleBackdropClick(e) {
    if (e.target === e.currentTarget) {
      this.args.onClose();
    }
  }

  // ── Email OTP ──────────────────────────────────────────────────────────────
  @action onEmailInput(event) {
    this.facEmail      = event.target.value;
    this.emailVerified = false;
    this.emailOtpSent  = false;
    this.otpError      = null;
  }

  @action async sendEmailOtp() {
    const email = this.facEmail.trim();
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      this.otpError = 'Enter a valid email address first';
      return;
    }
    this.isSendingOtp = true;
    this.otpError     = null;
    try {
      const res  = await fetch(`${API_BASE}/auth_user/send-otp-verified-email/`, {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify({ email }),
      });
      const data = await res.json().catch(() => ({}));
      if (res.ok) {
        this.emailOtpToken = data.token;
        this.emailOtpSent  = true;
        this.otpValue      = '';
      } else {
        this.otpError = data.message ?? 'Failed to send OTP. Please try again.';
      }
    } catch {
      this.otpError = 'Network error. Please try again.';
    } finally {
      this.isSendingOtp = false;
    }
  }

  @action onOtpInput(event) { this.otpValue = event.target.value; this.otpError = null; }

  @action async verifyEmailOtp() {
    if (!this.otpValue.trim()) { this.otpError = 'Please enter the OTP'; return; }
    this.isVerifyingOtp = true;
    this.otpError       = null;
    try {
      const res  = await fetch(`${API_BASE}/auth_user/verify-otp-verified-email/`, {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify({ email: this.facEmail.trim(), otp: this.otpValue.trim(), token: this.emailOtpToken }),
      });
      const data = await res.json().catch(() => ({}));
      if (res.ok) {
        this.emailVerified      = true;
        this.emailVerifiedToken = data.token;
        this.emailOtpSent       = false;
        this.otpError           = '';
      } else {
        this.otpError = data.message ?? 'Invalid OTP. Please try again.';
      }
    } catch {
      this.otpError = 'Network error. Please try again.';
    } finally {
      this.isVerifyingOtp = false;
    }
  }

  // ── Phone OTP ──────────────────────────────────────────────────────────────
  @action onPhoneInput(event) {
    this.facCellPhone  = event.target.value;
    this.phoneVerified = false;
    this.phoneOtpSent  = false;
    this.phoneOtpError = null;
  }

  @action async sendPhoneOtp() {
    if (!this.facCellPhone) return;
    this.isSendingPhoneOtp = true;
    this.phoneOtpError     = null;
    this.phoneOtpHint      = null;
    try {
      const res  = await fetch(`${API_BASE}/auth_user/send-otp-verified-phone/`, {
        method:  'POST',
        headers: this.authHeaders,
        body:    JSON.stringify({ phone: this.normalizedPhone }),
      });
      const data = await res.json().catch(() => ({}));
      if (res.ok) {
        this.phoneOtpSent  = true;
        this.phoneOtpToken = data.token ?? null;
        this.phoneOtpHint  = data.otp   ?? null;
      } else {
        this.phoneOtpError = data.message ?? 'Failed to send OTP.';
      }
    } catch {
      this.phoneOtpError = 'Network error. Please try again.';
    } finally {
      this.isSendingPhoneOtp = false;
    }
  }

  @action onPhoneOtpInput(event) { this.phoneOtpValue = event.target.value; this.phoneOtpError = null; }

  @action async verifyPhoneOtp() {
    if (!this.phoneOtpValue) return;
    this.isVerifyingPhoneOtp = true;
    this.phoneOtpError       = null;
    try {
      const res = await fetch(`${API_BASE}/auth_user/verify-otp-verified-phone/`, {
        method:  'POST',
        headers: this.authHeaders,
        body:    JSON.stringify({ phone: this.normalizedPhone, otp: this.phoneOtpValue, token: this.phoneOtpToken }),
      });
      const data = await res.json().catch(() => ({}));
      if (res.ok) {
        this.phoneVerified      = true;
        this.phoneVerifiedToken = data.token ?? null;
        this.phoneOtpSent       = false;
        this.phoneOtpHint       = null;
      } else {
        this.phoneOtpError = data.message ?? 'Invalid OTP.';
      }
    } catch {
      this.phoneOtpError = 'Network error. Please try again.';
    } finally {
      this.isVerifyingPhoneOtp = false;
    }
  }

  // ── Rich-text editor ──────────────────────────────────────────────────────
  @action onDescriptionInput(event) { this.facDescription = event.target.innerHTML; }
  @action onAboutUsInput(event)     { this.facAboutUs     = event.target.innerHTML; }
  @action fmt(cmd)                  { document.execCommand(cmd, false, null); }
  @action fmtVal(cmd, event)        { document.execCommand(cmd, false, event.target.value); }
  @action setTextColor(event)       { document.execCommand('foreColor', false, event.target.value); }

  @action async save() {
    if (this.isSaving) return;
    this.isSaving = true;

    const token = this.session.data?.authenticated?.token ?? '';

    const payload = {
      fac_id:                this.args.facility.fac_id,
      fac_name:              this.facName.trim(),
      fac_url:               this.facUrl.trim(),
      fac_url_name:          this.facUrl.trim() || this.facUrlName.trim(),
      fac_email:             this.facEmail.trim(),
      email_token:           this.emailVerifiedToken ?? '',
      phone_token:           this.phoneVerifiedToken ?? '',
      fac_cell_phone:        this.normalizedPhone,
      fac_country:           this.facCountry.trim(),
      fac_division:          this.facDivision.trim(),
      fac_district:          this.facDistrict.trim(),
      fac_city:              this.facCity.trim(),
      fac_address:           this.facAddress.trim(),
      fac_post_code:         this.facPostCode.trim(),
      fac_lat:               this.facLat.trim(),
      fac_long:              this.facLong.trim(),
      google_map_link:       this.googleMapLink.trim(),
      fac_sports:            this.facSports,
      fac_status:            this.facStatus,
      fac_del_by:            '',
      fac_manager_1:         this.facManager1.trim(),
      fac_manager_1_name:    this.facManager1Name.trim(),
      fac_manager_2:         this.facManager2.trim(),
      fac_manager_2_name:    this.facManager2Name.trim(),
      fac_manager_3:         this.facManager3.trim(),
      fac_manager_3_name:    this.facManager3Name.trim(),
      fac_established_date:  this.facEstablishedDate,
      fac_description:       this.facDescription,
      fac_about_us:          this.facAboutUs,
      fac_website:           this.facWebsite.trim(),
      fac_facebook:          this.#splitLines(this.facFacebook),
      fac_instagram:         this.#splitLines(this.facInstagram),
      fac_twitter:           this.#splitLines(this.facTwitter),
      fac_youtube:           this.#splitLines(this.facYoutube),
      fac_video_link:        this.#splitLines(this.facVideoLink),
      social_links:          [],
      remove_files:          [],
    };

    try {
      const res = await fetch('https://spordiumapi.adnanfoundation.com/facility/update_facility/', {
        method:  'PATCH',
        headers: {
          Authorization:   `Bearer ${token}`,
          'Content-Type':  'application/json',
        },
        body: JSON.stringify(payload),
      });

      const data = await res.json().catch(() => ({}));

      if (res.ok && data.success !== false) {
        this.toast.success('Facility updated successfully!');
        this.args.onSave();
      } else {
        this.toast.error(data.message ?? 'Failed to update facility.');
      }
    } catch (err) {
      this.toast.error(err.message ?? 'Network error. Please try again.');
    } finally {
      this.isSaving = false;
    }
  }

  <template>
    {{! ── Full-screen overlay ── }}
    <div
      class="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4"
      role="dialog"
      aria-modal="true"
      aria-label="Edit Facility"
      {{on "click" this.handleBackdropClick}}
    >
      {{! Backdrop }}
      <div class="absolute inset-0 bg-black/70 backdrop-blur-sm"></div>

      {{! Modal card }}
      <div class="relative z-10 w-full sm:max-w-3xl lg:max-w-4xl
                  max-h-[92vh] flex flex-col overflow-hidden
                  bg-gray-950 rounded-t-3xl sm:rounded-3xl
                  shadow-2xl shadow-black/60 ring-1 ring-white/10">

        {{! ── Gradient header ── }}
        <div class="bg-gradient-to-r from-indigo-600 via-violet-600 to-purple-700 shrink-0">

          {{! Title row }}
          <div class="flex items-center justify-between px-5 pt-4 pb-3">
            <div class="flex items-center gap-3">
              <div class="w-9 h-9 rounded-xl bg-white/20 flex items-center justify-center shrink-0">
                {{lucideIcon "pencil" size=18 class="text-white"}}
              </div>
              <div>
                <p class="text-base font-extrabold text-white leading-tight">Edit Facility</p>
                <p class="text-[11px] text-white/70 font-medium">Update facility information</p>
              </div>
            </div>
            <button
              type="button"
              aria-label="Close edit modal"
              class="w-8 h-8 rounded-xl bg-white/15 hover:bg-white/25 flex items-center justify-center
                     transition-colors"
              {{on "click" this.args.onClose}}
            >
              {{lucideIcon "x" size=16 class="text-white"}}
            </button>
          </div>

          {{! Tab bar }}
          <div class="flex items-center gap-1 px-4 pb-3 overflow-x-auto scrollbar-none">
            {{#each this.tabs as |tab|}}
              <button
                type="button"
                class="flex items-center gap-1.5 px-3.5 py-1.5 rounded-full text-xs font-bold
                       whitespace-nowrap transition-all duration-150 shrink-0
                       {{if (eq this.activeTab tab.id)
                         'bg-white text-indigo-700 shadow-sm'
                         'text-white/70 hover:text-white hover:bg-white/15'}}"
                {{on "click" (fn this.setTab tab.id)}}
              >
                {{lucideIcon tab.icon size=12}}
                {{tab.label}}
              </button>
            {{/each}}
          </div>
        </div>

        {{! ── Scrollable body ── }}
        <div class="flex-1 overflow-y-auto p-4 sm:p-5 space-y-4">

          {{! ══ BASIC TAB ══ }}
          {{#if (eq this.activeTab "basic")}}
            <div class="bg-gray-800/50 rounded-2xl border border-gray-700/50 p-4 space-y-4">
              <p class="text-[10px] font-bold uppercase tracking-widest text-indigo-400 mb-2">Basic Information</p>

              <div>
                <label class="block text-[10px] font-bold uppercase tracking-widest text-gray-400 mb-1.5">Facility Name</label>
                <input
                  type="text"
                  value={{this.facName}}
                  placeholder="e.g. Green Valley Sports Complex"
                  class="w-full px-4 py-3 rounded-xl bg-gray-800 border border-gray-700
                         text-white placeholder:text-gray-500 text-sm
                         focus:outline-none focus:ring-2 focus:ring-indigo-500/40
                         focus:border-indigo-500 transition-colors"
                  {{on "input" (fn this.set "facName")}}
                />
              </div>

              <div>
                <label class="block text-[10px] font-bold uppercase tracking-widest text-gray-400 mb-1.5">URL Slug</label>
                <input
                  type="text"
                  value={{this.facUrl}}
                  placeholder="e.g. green-valley-sports"
                  class="w-full px-4 py-3 rounded-xl bg-gray-800 border border-gray-700
                         text-white placeholder:text-gray-500 text-sm
                         focus:outline-none focus:ring-2 focus:ring-indigo-500/40
                         focus:border-indigo-500 transition-colors"
                  {{on "input" (fn this.set "facUrl")}}
                />
              </div>

              <div>
                <label class="block text-[10px] font-bold uppercase tracking-widest text-gray-400 mb-1.5">Established Date</label>
                <input
                  type="date"
                  value={{this.facEstablishedDate}}
                  class="w-full px-4 py-3 rounded-xl bg-gray-800 border border-gray-700
                         text-white placeholder:text-gray-500 text-sm
                         focus:outline-none focus:ring-2 focus:ring-indigo-500/40
                         focus:border-indigo-500 transition-colors"
                  {{on "input" (fn this.set "facEstablishedDate")}}
                />
              </div>

              {{! Email with OTP verify }}
              <EmailOtpVerifier
                @label="Facility Email"
                @email={{this.facEmail}}
                @verified={{this.emailVerified}}
                @otpSent={{this.emailOtpSent}}
                @otpValue={{this.otpValue}}
                @otpError={{this.otpError}}
                @isSending={{this.isSendingOtp}}
                @isVerifying={{this.isVerifyingOtp}}
                @onEmailInput={{this.onEmailInput}}
                @onSendOtp={{this.sendEmailOtp}}
                @onVerifyOtp={{this.verifyEmailOtp}}
                @onOtpInput={{this.onOtpInput}}
              />

              {{! Phone with OTP verify }}
              <PhoneOtpVerifier
                @label="Cell Phone"
                @phone={{this.facCellPhone}}
                @verified={{this.phoneVerified}}
                @otpSent={{this.phoneOtpSent}}
                @otpValue={{this.phoneOtpValue}}
                @otpHint={{this.phoneOtpHint}}
                @otpError={{this.phoneOtpError}}
                @isSending={{this.isSendingPhoneOtp}}
                @isVerifying={{this.isVerifyingPhoneOtp}}
                @onPhoneInput={{this.onPhoneInput}}
                @onSendOtp={{this.sendPhoneOtp}}
                @onVerifyOtp={{this.verifyPhoneOtp}}
                @onOtpInput={{this.onPhoneOtpInput}}
              />

              <div>
                <label class="block text-[10px] font-bold uppercase tracking-widest text-gray-400 mb-1.5">Website</label>
                <input
                  type="url"
                  value={{this.facWebsite}}
                  placeholder="https://example.com"
                  class="w-full px-4 py-3 rounded-xl bg-gray-800 border border-gray-700
                         text-white placeholder:text-gray-500 text-sm
                         focus:outline-none focus:ring-2 focus:ring-indigo-500/40
                         focus:border-indigo-500 transition-colors"
                  {{on "input" (fn this.set "facWebsite")}}
                />
              </div>

              {{! Status toggle }}
              <div class="flex items-center justify-between px-4 py-3.5 rounded-xl bg-gray-800 border border-gray-700">
                <div>
                  <p class="text-sm font-bold text-white">Facility Status</p>
                  <p class="text-[11px] text-gray-400 mt-0.5">
                    {{if this.facStatus "Open for bookings" "Temporarily closed"}}
                  </p>
                </div>
                <button
                  type="button"
                  aria-label="Toggle facility status"
                  class="relative w-12 h-6 rounded-full transition-all duration-200
                         {{if this.facStatus 'bg-emerald-500' 'bg-gray-600'}}"
                  {{on "click" this.toggleStatus}}
                >
                  <span
                    class="absolute top-0.5 w-5 h-5 rounded-full bg-white shadow transition-all duration-200
                           {{if this.facStatus 'left-6' 'left-0.5'}}"
                  ></span>
                </button>
              </div>
            </div>

          {{! ══ LOCATION TAB ══ }}
          {{else if (eq this.activeTab "location")}}
            <div class="bg-gray-800/50 rounded-2xl border border-gray-700/50 p-4 space-y-4">
              <p class="text-[10px] font-bold uppercase tracking-widest text-indigo-400 mb-2">Location Details</p>

              <div>
                <label class="block text-[10px] font-bold uppercase tracking-widest text-gray-400 mb-1.5">Address</label>
                <input
                  type="text"
                  value={{this.facAddress}}
                  placeholder="Street address"
                  class="w-full px-4 py-3 rounded-xl bg-gray-800 border border-gray-700
                         text-white placeholder:text-gray-500 text-sm
                         focus:outline-none focus:ring-2 focus:ring-indigo-500/40
                         focus:border-indigo-500 transition-colors"
                  {{on "input" (fn this.set "facAddress")}}
                />
              </div>

              <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label class="block text-[10px] font-bold uppercase tracking-widest text-gray-400 mb-1.5">City</label>
                  <input
                    type="text"
                    value={{this.facCity}}
                    placeholder="Dhaka"
                    class="w-full px-4 py-3 rounded-xl bg-gray-800 border border-gray-700
                           text-white placeholder:text-gray-500 text-sm
                           focus:outline-none focus:ring-2 focus:ring-indigo-500/40
                           focus:border-indigo-500 transition-colors"
                    {{on "input" (fn this.set "facCity")}}
                  />
                </div>
                <div>
                  <label class="block text-[10px] font-bold uppercase tracking-widest text-gray-400 mb-1.5">District</label>
                  <input
                    type="text"
                    value={{this.facDistrict}}
                    placeholder="Dhaka"
                    class="w-full px-4 py-3 rounded-xl bg-gray-800 border border-gray-700
                           text-white placeholder:text-gray-500 text-sm
                           focus:outline-none focus:ring-2 focus:ring-indigo-500/40
                           focus:border-indigo-500 transition-colors"
                    {{on "input" (fn this.set "facDistrict")}}
                  />
                </div>
              </div>

              <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label class="block text-[10px] font-bold uppercase tracking-widest text-gray-400 mb-1.5">Division</label>
                  <input
                    type="text"
                    value={{this.facDivision}}
                    placeholder="Dhaka Division"
                    class="w-full px-4 py-3 rounded-xl bg-gray-800 border border-gray-700
                           text-white placeholder:text-gray-500 text-sm
                           focus:outline-none focus:ring-2 focus:ring-indigo-500/40
                           focus:border-indigo-500 transition-colors"
                    {{on "input" (fn this.set "facDivision")}}
                  />
                </div>
                <div>
                  <label class="block text-[10px] font-bold uppercase tracking-widest text-gray-400 mb-1.5">Country</label>
                  <input
                    type="text"
                    value={{this.facCountry}}
                    placeholder="Bangladesh"
                    class="w-full px-4 py-3 rounded-xl bg-gray-800 border border-gray-700
                           text-white placeholder:text-gray-500 text-sm
                           focus:outline-none focus:ring-2 focus:ring-indigo-500/40
                           focus:border-indigo-500 transition-colors"
                    {{on "input" (fn this.set "facCountry")}}
                  />
                </div>
              </div>

              <div>
                <label class="block text-[10px] font-bold uppercase tracking-widest text-gray-400 mb-1.5">Post Code</label>
                <input
                  type="text"
                  value={{this.facPostCode}}
                  placeholder="1200"
                  class="w-full px-4 py-3 rounded-xl bg-gray-800 border border-gray-700
                         text-white placeholder:text-gray-500 text-sm
                         focus:outline-none focus:ring-2 focus:ring-indigo-500/40
                         focus:border-indigo-500 transition-colors"
                  {{on "input" (fn this.set "facPostCode")}}
                />
              </div>

              <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label class="block text-[10px] font-bold uppercase tracking-widest text-gray-400 mb-1.5">Latitude</label>
                  <input
                    type="text"
                    value={{this.facLat}}
                    placeholder="23.8103"
                    class="w-full px-4 py-3 rounded-xl bg-gray-800 border border-gray-700
                           text-white placeholder:text-gray-500 text-sm
                           focus:outline-none focus:ring-2 focus:ring-indigo-500/40
                           focus:border-indigo-500 transition-colors"
                    {{on "input" (fn this.set "facLat")}}
                  />
                </div>
                <div>
                  <label class="block text-[10px] font-bold uppercase tracking-widest text-gray-400 mb-1.5">Longitude</label>
                  <input
                    type="text"
                    value={{this.facLong}}
                    placeholder="90.4125"
                    class="w-full px-4 py-3 rounded-xl bg-gray-800 border border-gray-700
                           text-white placeholder:text-gray-500 text-sm
                           focus:outline-none focus:ring-2 focus:ring-indigo-500/40
                           focus:border-indigo-500 transition-colors"
                    {{on "input" (fn this.set "facLong")}}
                  />
                </div>
              </div>

              <div>
                <label class="block text-[10px] font-bold uppercase tracking-widest text-gray-400 mb-1.5">Google Map Link</label>
                <input
                  type="url"
                  value={{this.googleMapLink}}
                  placeholder="https://maps.google.com/..."
                  class="w-full px-4 py-3 rounded-xl bg-gray-800 border border-gray-700
                         text-white placeholder:text-gray-500 text-sm
                         focus:outline-none focus:ring-2 focus:ring-indigo-500/40
                         focus:border-indigo-500 transition-colors"
                  {{on "input" (fn this.set "googleMapLink")}}
                />
              </div>
            </div>

          {{! ══ SPORTS TAB ══ }}
          {{else if (eq this.activeTab "sports")}}
            <div class="bg-gray-800/50 rounded-2xl border border-gray-700/50 p-4">
              <p class="text-[10px] font-bold uppercase tracking-widest text-indigo-400 mb-3">Available Sports</p>
              <p class="text-xs text-gray-400 mb-4">Select all sports this facility supports.</p>
              <div class="grid grid-cols-2 sm:grid-cols-3 gap-2.5">
                {{#each this.sports as |sport|}}
                  <button
                    type="button"
                    class="flex items-center gap-2 px-3.5 py-2.5 rounded-xl text-sm font-semibold
                           border transition-all duration-150 capitalize
                           {{if (sportSelected this.facSports sport)
                             'bg-indigo-600/20 border-indigo-500 text-indigo-300'
                             'bg-gray-800 border-gray-700 text-gray-400 hover:border-gray-500 hover:text-gray-300'}}"
                    {{on "click" (fn this.toggleSport sport)}}
                  >
                    {{#if (sportSelected this.facSports sport)}}
                      {{lucideIcon "check" size=13 class="text-indigo-400 shrink-0"}}
                    {{else}}
                      {{lucideIcon "plus" size=13 class="text-gray-500 shrink-0"}}
                    {{/if}}
                    {{sport}}
                  </button>
                {{/each}}
              </div>
            </div>

          {{! ══ MANAGERS TAB ══ }}
          {{else if (eq this.activeTab "managers")}}
            <div class="space-y-4">
              <p class="text-[10px] font-bold uppercase tracking-widest text-indigo-400 px-1">Facility Managers</p>

              {{! Manager 1 }}
              <div class="bg-gray-800/60 rounded-2xl border border-gray-700/60 p-4 space-y-3">
                <p class="text-xs font-bold text-gray-300 flex items-center gap-2">
                  {{lucideIcon "user" size=14 class="text-indigo-400"}}
                  Manager 1
                </p>
                <div>
                  <label class="block text-[10px] font-bold uppercase tracking-widest text-gray-400 mb-1.5">Full Name</label>
                  <input
                    type="text"
                    value={{this.facManager1Name}}
                    placeholder="Manager full name"
                    class="w-full px-4 py-3 rounded-xl bg-gray-800 border border-gray-700
                           text-white placeholder:text-gray-500 text-sm
                           focus:outline-none focus:ring-2 focus:ring-indigo-500/40
                           focus:border-indigo-500 transition-colors"
                    {{on "input" (fn this.set "facManager1Name")}}
                  />
                </div>
                <div>
                  <label class="block text-[10px] font-bold uppercase tracking-widest text-gray-400 mb-1.5">User ID</label>
                  <input
                    type="text"
                    value={{this.facManager1}}
                    placeholder="User account ID"
                    class="w-full px-4 py-3 rounded-xl bg-gray-800 border border-gray-700
                           text-white placeholder:text-gray-500 text-sm
                           focus:outline-none focus:ring-2 focus:ring-indigo-500/40
                           focus:border-indigo-500 transition-colors"
                    {{on "input" (fn this.set "facManager1")}}
                  />
                </div>
              </div>

              {{! Manager 2 }}
              <div class="bg-gray-800/60 rounded-2xl border border-gray-700/60 p-4 space-y-3">
                <p class="text-xs font-bold text-gray-300 flex items-center gap-2">
                  {{lucideIcon "user" size=14 class="text-violet-400"}}
                  Manager 2
                </p>
                <div>
                  <label class="block text-[10px] font-bold uppercase tracking-widest text-gray-400 mb-1.5">Full Name</label>
                  <input
                    type="text"
                    value={{this.facManager2Name}}
                    placeholder="Manager full name"
                    class="w-full px-4 py-3 rounded-xl bg-gray-800 border border-gray-700
                           text-white placeholder:text-gray-500 text-sm
                           focus:outline-none focus:ring-2 focus:ring-indigo-500/40
                           focus:border-indigo-500 transition-colors"
                    {{on "input" (fn this.set "facManager2Name")}}
                  />
                </div>
                <div>
                  <label class="block text-[10px] font-bold uppercase tracking-widest text-gray-400 mb-1.5">User ID</label>
                  <input
                    type="text"
                    value={{this.facManager2}}
                    placeholder="User account ID"
                    class="w-full px-4 py-3 rounded-xl bg-gray-800 border border-gray-700
                           text-white placeholder:text-gray-500 text-sm
                           focus:outline-none focus:ring-2 focus:ring-indigo-500/40
                           focus:border-indigo-500 transition-colors"
                    {{on "input" (fn this.set "facManager2")}}
                  />
                </div>
              </div>

              {{! Manager 3 }}
              <div class="bg-gray-800/60 rounded-2xl border border-gray-700/60 p-4 space-y-3">
                <p class="text-xs font-bold text-gray-300 flex items-center gap-2">
                  {{lucideIcon "user" size=14 class="text-purple-400"}}
                  Manager 3
                </p>
                <div>
                  <label class="block text-[10px] font-bold uppercase tracking-widest text-gray-400 mb-1.5">Full Name</label>
                  <input
                    type="text"
                    value={{this.facManager3Name}}
                    placeholder="Manager full name"
                    class="w-full px-4 py-3 rounded-xl bg-gray-800 border border-gray-700
                           text-white placeholder:text-gray-500 text-sm
                           focus:outline-none focus:ring-2 focus:ring-indigo-500/40
                           focus:border-indigo-500 transition-colors"
                    {{on "input" (fn this.set "facManager3Name")}}
                  />
                </div>
                <div>
                  <label class="block text-[10px] font-bold uppercase tracking-widest text-gray-400 mb-1.5">User ID</label>
                  <input
                    type="text"
                    value={{this.facManager3}}
                    placeholder="User account ID"
                    class="w-full px-4 py-3 rounded-xl bg-gray-800 border border-gray-700
                           text-white placeholder:text-gray-500 text-sm
                           focus:outline-none focus:ring-2 focus:ring-indigo-500/40
                           focus:border-indigo-500 transition-colors"
                    {{on "input" (fn this.set "facManager3")}}
                  />
                </div>
              </div>
            </div>

          {{! ══ CONTENT TAB ══ }}
          {{else if (eq this.activeTab "content")}}
            <div class="bg-gray-800/50 rounded-2xl border border-gray-700/50 p-4 space-y-5">
              <p class="text-[10px] font-bold uppercase tracking-widest text-indigo-400 mb-2">Content</p>

              {{! Description rich-text editor }}
              <div>
                <p class="text-[10px] font-bold uppercase tracking-widest text-gray-400 mb-2">Description</p>
                <RichTextEditor
                  @editorId="edit-fac-description"
                  @placeholder="Describe this facility — what makes it special, what it offers…"
                  @initialHtml={{this._initialDescription}}
                  @fontFamilies={{this.fontFamilies}}
                  @fontSizes={{this.fontSizes}}
                  @onInput={{this.onDescriptionInput}}
                  @onFmt={{this.fmt}}
                  @onFmtVal={{this.fmtVal}}
                  @onSetTextColor={{this.setTextColor}}
                />
              </div>

              {{! About Us rich-text editor }}
              <div>
                <p class="text-[10px] font-bold uppercase tracking-widest text-gray-400 mb-2">About Us</p>
                <RichTextEditor
                  @editorId="edit-fac-about-us"
                  @placeholder="Tell visitors about the organization, history, or mission…"
                  @initialHtml={{this._initialAboutUs}}
                  @fontFamilies={{this.fontFamilies}}
                  @fontSizes={{this.fontSizes}}
                  @onInput={{this.onAboutUsInput}}
                  @onFmt={{this.fmt}}
                  @onFmtVal={{this.fmtVal}}
                  @onSetTextColor={{this.setTextColor}}
                />
              </div>
            </div>

          {{! ══ SOCIAL TAB ══ }}
          {{else if (eq this.activeTab "social")}}
            <div class="bg-gray-800/50 rounded-2xl border border-gray-700/50 p-4 space-y-5">
              <p class="text-[10px] font-bold uppercase tracking-widest text-indigo-400 mb-2">Social Links</p>
              <p class="text-xs text-gray-400 -mt-2">Enter one URL per line for each platform.</p>

              {{! Facebook }}
              <div>
                <label class="block text-[10px] font-bold uppercase tracking-widest text-blue-400 mb-1.5">
                  Facebook
                </label>
                <textarea
                  rows="3"
                  placeholder="https://facebook.com/your-page&#10;(one URL per line)"
                  class="w-full px-4 py-3 rounded-xl bg-gray-800 border border-gray-700
                         text-white placeholder:text-gray-500 text-sm resize-none
                         focus:outline-none focus:ring-2 focus:ring-blue-500/40
                         focus:border-blue-500 transition-colors"
                  {{on "input" (fn this.set "facFacebook")}}
                >{{this.facFacebook}}</textarea>
              </div>

              {{! Instagram }}
              <div>
                <label class="block text-[10px] font-bold uppercase tracking-widest text-pink-400 mb-1.5">
                  Instagram
                </label>
                <textarea
                  rows="3"
                  placeholder="https://instagram.com/your-handle&#10;(one URL per line)"
                  class="w-full px-4 py-3 rounded-xl bg-gray-800 border border-gray-700
                         text-white placeholder:text-gray-500 text-sm resize-none
                         focus:outline-none focus:ring-2 focus:ring-pink-500/40
                         focus:border-pink-500 transition-colors"
                  {{on "input" (fn this.set "facInstagram")}}
                >{{this.facInstagram}}</textarea>
              </div>

              {{! Twitter / X }}
              <div>
                <label class="block text-[10px] font-bold uppercase tracking-widest text-sky-400 mb-1.5">
                  Twitter / X
                </label>
                <textarea
                  rows="3"
                  placeholder="https://twitter.com/your-handle&#10;(one URL per line)"
                  class="w-full px-4 py-3 rounded-xl bg-gray-800 border border-gray-700
                         text-white placeholder:text-gray-500 text-sm resize-none
                         focus:outline-none focus:ring-2 focus:ring-sky-500/40
                         focus:border-sky-500 transition-colors"
                  {{on "input" (fn this.set "facTwitter")}}
                >{{this.facTwitter}}</textarea>
              </div>

              {{! YouTube }}
              <div>
                <label class="block text-[10px] font-bold uppercase tracking-widest text-red-400 mb-1.5">
                  YouTube
                </label>
                <textarea
                  rows="3"
                  placeholder="https://youtube.com/@your-channel&#10;(one URL per line)"
                  class="w-full px-4 py-3 rounded-xl bg-gray-800 border border-gray-700
                         text-white placeholder:text-gray-500 text-sm resize-none
                         focus:outline-none focus:ring-2 focus:ring-red-500/40
                         focus:border-red-500 transition-colors"
                  {{on "input" (fn this.set "facYoutube")}}
                >{{this.facYoutube}}</textarea>
              </div>

              {{! Video Links }}
              <div>
                <label class="block text-[10px] font-bold uppercase tracking-widest text-violet-400 mb-1.5">
                  Video Links
                </label>
                <textarea
                  rows="3"
                  placeholder="https://youtube.com/watch?v=...&#10;(one URL per line)"
                  class="w-full px-4 py-3 rounded-xl bg-gray-800 border border-gray-700
                         text-white placeholder:text-gray-500 text-sm resize-none
                         focus:outline-none focus:ring-2 focus:ring-violet-500/40
                         focus:border-violet-500 transition-colors"
                  {{on "input" (fn this.set "facVideoLink")}}
                >{{this.facVideoLink}}</textarea>
              </div>
            </div>
          {{/if}}
          {{! end tab content }}

        </div>
        {{! end scrollable body }}

        {{! ── Sticky footer ── }}
        <div class="shrink-0 flex items-center gap-3 px-4 sm:px-5 py-4
                    border-t border-gray-800 bg-gray-950">
          <button
            type="button"
            class="flex-1 py-3 rounded-xl text-sm font-bold text-gray-300
                   bg-gray-800 hover:bg-gray-700 transition-colors"
            {{on "click" this.args.onClose}}
          >
            Cancel
          </button>
          <button
            type="button"
            disabled={{this.isSaving}}
            class="flex-1 py-3 rounded-xl text-sm font-bold text-white
                   bg-gradient-to-r from-indigo-600 to-violet-600
                   hover:from-indigo-500 hover:to-violet-500
                   shadow-lg shadow-indigo-500/30
                   disabled:opacity-60 disabled:cursor-not-allowed
                   transition-all duration-150 flex items-center justify-center gap-2"
            {{on "click" this.save}}
          >
            {{#if this.isSaving}}
              <svg class="w-4 h-4 animate-spin text-white/80" viewBox="0 0 24 24" fill="none">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"></path>
              </svg>
              Saving…
            {{else}}
              {{lucideIcon "save" size=15}}
              Save Changes
            {{/if}}
          </button>
        </div>

      </div>
      {{! end modal card }}

    </div>
    {{! end overlay }}
  </template>
}
