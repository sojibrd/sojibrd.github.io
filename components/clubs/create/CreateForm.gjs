import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { service } from '@ember/service';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { eq } from 'ember-truth-helpers';
import { htmlSafe } from '@ember/template';
import { getUserLocation } from 'spordium/utils/utility.helper';
import config from 'spordium/config/environment';
import FormStepIndicator from './form-step-indicator';
import FormNavButtons from './form-nav-buttons';
import FormSubmitError from './form-submit-error';
import GeoTextInput from './geo-text-input';
import ImageUploader from './image-uploader';
import ColorPicker from './color-picker';
import RichTextEditor from './rich-text-editor';
import LinkListField from './link-list-field';
import EmailOtpVerifier from './email-otp-verifier';
import ManagerSearch from './manager-search';
import SportsMultiSelect from './sports-multi-select';

const KHELA_API = 'https://khelaapi.adnanfoundation.com';

// ── Google Maps helpers (geo-autofill) ────────────────────────────────────────
const GOOGLE_MAPS_API_KEY = config.APP.GOOGLE_MAPS_API_KEY;
let _geoMapsPromise = null;

function loadGoogleMapsForGeo() {
  if (_geoMapsPromise) return _geoMapsPromise;
  _geoMapsPromise = new Promise((resolve) => {
    if (window.google?.maps) return resolve();
    window.__googleMapsGeoReady = resolve;
    const s = document.createElement('script');
    s.src = `https://maps.googleapis.com/maps/api/js?key=${GOOGLE_MAPS_API_KEY}&libraries=geocoding&loading=async&callback=__googleMapsGeoReady`;
    s.async = true;
    document.head.appendChild(s);
  });
  return _geoMapsPromise;
}

function extractAddressComponents(results) {
  const comps = results[0]?.address_components || [];
  const get = (...types) => {
    const c = comps.find((comp) => types.some((t) => comp.types.includes(t)));
    return c?.long_name || '';
  };
  return {
    address:  results[0]?.formatted_address || '',
    country:  get('country'),
    division: get('administrative_area_level_1'),
    district: get('administrative_area_level_2', 'administrative_area_level_3'),
    city:     get('locality', 'sublocality_level_1', 'administrative_area_level_4'),
    postCode: get('postal_code'),
  };
}

// ── Constants ────────────────────────────────────────────────────────────────
const CLUB_TYPES    = ['Amateur', 'Semi Professional', 'Professional'];
const SPORTS_SCOPES = ['Multi Sports', 'Single Sports'];
const SPORTS_LIST   = ['Cricket', 'Football', 'Basketball', 'Baseball', 'American Football', 'Hockey', 'Table Tennis'];
const DIVISION_LIST = ['Division 1', 'Division 2', 'Division 3', 'Division 4', 'Premier League', 'Championship'];
const FONT_FAMILIES = ['Arial', 'Georgia', 'Times New Roman', 'Courier New', 'Verdana', 'Trebuchet MS'];
const FONT_SIZES    = [
  { label: 'Tiny',   value: '1' },
  { label: 'Small',  value: '2' },
  { label: 'Normal', value: '3' },
  { label: 'Medium', value: '4' },
  { label: 'Large',  value: '5' },
  { label: 'XL',     value: '6' },
  { label: 'XXL',    value: '7' },
];

// ── Component ────────────────────────────────────────────────────────────────
export default class CreateForm extends Component {
  @service session;
  @service router;

  // ── Step management ────────────────────────────────────────────────────────
  @tracked currentStep = 1;
  totalSteps = 4;

  // ── Step 1 · Club Identity ─────────────────────────────────────────────────
  @tracked clubType         = '';
  @tracked sportsScope      = '';
  @tracked selectedSports   = [];
  @tracked sportsDropdownOpen = false;
  @tracked clubName         = '';

  // ── Step 2 · Contact & Location ───────────────────────────────────────────
  @tracked selectedManagers       = [];
  @tracked managerSearchQuery     = '';
  @tracked managerSearchResults   = [];
  @tracked managerSearchOpen      = false;
  @tracked managerSearchLoading   = false;
  _managerSearchTimer             = null;
  @tracked clubEmail        = '';
  @tracked clubPhone        = '';
  @tracked clubAddress      = '';
  @tracked clubCountry      = '';
  @tracked clubDivisionArea = '';
  @tracked clubDistrict     = '';
  @tracked clubCity         = '';
  @tracked clubPostCode     = '';
  @tracked googleMapLink    = '';
  @tracked establishedDate  = '';
  @tracked isGeoFilling     = false;

  // ── Email OTP verification ────────────────────────────────────────────────
  @tracked emailVerified      = false;
  @tracked emailOtpSent       = false;
  @tracked emailOtpToken      = '';
  @tracked emailVerifiedToken = '';
  @tracked otpValue           = '';
  @tracked otpError           = '';
  @tracked isSendingOtp       = false;
  @tracked isVerifyingOtp     = false;

  // ── Step 3 · Media & Branding ─────────────────────────────────────────────
  @tracked bannerFile    = null;
  @tracked bannerPreview = null;
  @tracked bannerError   = '';
  @tracked logoFile      = null;
  @tracked logoPreview   = null;
  @tracked logoError     = '';
  @tracked clubColors    = ['#4f46e5'];
  @tracked description   = '';

  // ── Step 4 · Club Details ─────────────────────────────────────────────────
  @tracked videoLinks        = [''];
  @tracked clubWebsite       = '';
  @tracked socialLinks       = [''];
  @tracked clubUrlName       = '';
  @tracked playerStartingAge = '';
  @tracked playerRetiringAge = '';
  @tracked clubDivision      = '';

  // ── UI state ──────────────────────────────────────────────────────────────
  @tracked errors            = {};
  @tracked isSubmitting      = false;
  @tracked submitted         = false;
  @tracked submitError       = '';
  @tracked submitErrors      = [];   // array of field-level errors from the API
  @tracked submitResponse    = null; // full API response after successful creation
  @tracked redirectCountdown = 12;   // seconds until auto-redirect
  _submitErrorTimer          = null;
  _redirectInterval          = null;

  _setSubmitError(message, errors = []) {
    clearTimeout(this._submitErrorTimer);
    this.submitError  = message;
    this.submitErrors = errors;
    this._submitErrorTimer = setTimeout(() => {
      this.submitError  = '';
      this.submitErrors = [];
    }, 10000);
  }

  @action clearSubmitError() {
    clearTimeout(this._submitErrorTimer);
    this.submitError  = '';
    this.submitErrors = [];
  }

  _startRedirectCountdown() {
    this.redirectCountdown = 12;
    this._redirectInterval = setInterval(() => {
      this.redirectCountdown -= 1;
      if (this.redirectCountdown <= 0) {
        this._clearRedirectInterval();
        this.router.transitionTo('clubs');
      }
    }, 1000);
  }

  _clearRedirectInterval() {
    clearInterval(this._redirectInterval);
    this._redirectInterval = null;
  }

  @action goToClubs() {
    this._clearRedirectInterval();
    this.router.transitionTo('clubs');
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this._clearRedirectInterval();
    clearTimeout(this._submitErrorTimer);
  }

  get redirectProgressStyle() {
    const pct = (this.redirectCountdown / 12) * 100;
    return htmlSafe(`width:${pct}%`);
  }

  // ── Computed ──────────────────────────────────────────────────────────────
  get isFirstStep() { return this.currentStep === 1; }
  get isLastStep()  { return this.currentStep === this.totalSteps; }

  get steps() {
    return [
      { id: 1, label: 'Identity',  iconPath: 'M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z' },
      { id: 2, label: 'Contact',   iconPath: 'M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8z' },
      { id: 3, label: 'Media',     iconPath: 'M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z' },
      { id: 4, label: 'Details',   iconPath: 'M14 2H6a2 2 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z' },
    ];
  }

  get selectedSportsLabel() {
    if (!this.selectedSports.length) return 'Select sports';
    if (this.selectedSports.length <= 2) return this.selectedSports.join(', ');
    return `${this.selectedSports.slice(0, 2).join(', ')} +${this.selectedSports.length - 2} more`;
  }

  get sportsWithSelection() {
    return SPORTS_LIST.map(name => ({
      name,
      selected: this.selectedSports.includes(name),
    }));
  }

  get colorsForDisplay() {
    return this.clubColors.map((color, index) => ({
      color,
      index,
      style: htmlSafe(`background-color:${color}`),
    }));
  }

  get videoLinksForDisplay() {
    return this.videoLinks.map((link, index) => ({ link, index }));
  }

  get socialLinksForDisplay() {
    return this.socialLinks.map((link, index) => ({ link, index }));
  }

  get stepProgressStyle() {
    const pct = ((this.currentStep - 1) / (this.totalSteps - 1)) * 100;
    return htmlSafe(`width:${pct}%`);
  }

  get clubTypeOptions() {
    return CLUB_TYPES.map(v => ({ label: v, value: v }));
  }

  get sportsScopeOptions() {
    return SPORTS_SCOPES.map(v => ({ label: v, value: v }));
  }

  get divisionOptions() {
    return DIVISION_LIST.map(v => ({ label: v, value: v }));
  }

  get fontFamilies() { return FONT_FAMILIES; }
  get fontSizes()    { return FONT_SIZES; }

  // ── Validation ────────────────────────────────────────────────────────────
  validateStep(step) {
    const e = {};

    if (step === 1) {
      if (!this.clubType)
        e.clubType    = 'Please choose a club type to continue.';
      if (!this.sportsScope)
        e.sportsScope = 'Please select whether your club is single or multi-sport.';
      if (!this.selectedSports.length)
        e.sports = 'Select at least one sport for your club.';
      else if (this.sportsScope === 'Single Sports' && this.selectedSports.length > 1)
        e.sports = 'Single Sports clubs can only have one sport. Please remove the extra selection.';
      else if (this.sportsScope === 'Multi Sports' && this.selectedSports.length < 2)
        e.sports = 'Multi Sports clubs must have at least 2 sports selected.';
      if (!this.clubName.trim())
        e.clubName = 'Your club needs a name — what should we call it?';
    }

    if (step === 2) {
      if (!this.selectedManagers.length)
        e.managers = 'Add at least one club manager to continue.';
      if (!this.clubEmail.trim())
        e.clubEmail = 'A club email address is required.';
      else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(this.clubEmail))
        e.clubEmail = 'That doesn\'t look like a valid email. Please double-check it.';
      else if (!this.emailVerified)
        e.clubEmail = 'Please verify your club email before continuing.';
      if (!this.clubPhone.trim())
        e.clubPhone = 'A contact phone number is required.';
      if (!this.clubAddress.trim())
        e.clubAddress = 'Please enter the club\'s street address.';
      if (!this.clubCountry.trim())
        e.clubCountry = 'Country is required.';
      if (!this.clubDivisionArea.trim())
        e.clubDivisionArea = 'Division / state is required.';
      if (!this.clubDistrict.trim())
        e.clubDistrict = 'District is required.';
      if (!this.clubCity.trim())
        e.clubCity = 'Please enter the city where your club is based.';
      if (!this.clubPostCode.trim())
        e.clubPostCode = 'Post code is required for your club\'s location.';
      if (!this.googleMapLink.trim())
        e.googleMapLink = 'Please add a Google Maps link so members can find you.';
      if (!this.establishedDate)
        e.establishedDate = 'When was your club established? This field is required.';
    }

    if (step === 3) {
      if (!this.bannerFile)
        e.banner = 'A cover banner image is required — it\'s the first thing people see!';
      if (!this.logoFile)
        e.logo = 'Your club logo is required.';
      // Read from the live DOM only when step 3 is actually rendered;
      // otherwise fall back to the already-saved tracked value.
      const editorEl = document.getElementById('rich-editor');
      const raw = editorEl ? editorEl.innerHTML : this.description;
      if (editorEl) this.description = raw; // keep tracked value in sync
      if (!raw.replace(/<[^>]*>/g, '').trim())
        e.description = 'Tell people about your club — a description is required.';
    }

    if (step === 4) {
      if (!this.clubDivision)
        e.clubDivision = 'Please select the division your club competes in.';
      const urlRe = /^https?:\/\/.+\..+/;
      if (this.clubWebsite.trim() && !urlRe.test(this.clubWebsite.trim()))
        e.clubWebsite = 'Please enter a valid website URL starting with https:// (e.g. https://yourclub.com)';
      const badVideo = this.videoLinks.findIndex(v => v.trim() && !urlRe.test(v.trim()));
      if (badVideo >= 0)
        e.videoLinks = `Video link #${badVideo + 1} is not a valid URL. Use a full link like https://youtube.com/...`;
      const badSocial = this.socialLinks.findIndex(v => v.trim() && !urlRe.test(v.trim()));
      if (badSocial >= 0)
        e.socialLinks = `Social link #${badSocial + 1} is not a valid URL. Use a full link like https://facebook.com/...`;
    }

    this.errors = e;
    return !Object.keys(e).length;
  }

  // Validates every step and jumps to the first one that fails
  validateAll() {
    for (let s = 1; s <= this.totalSteps; s++) {
      if (!this.validateStep(s)) {
        this.currentStep = s;
        window.scrollTo({ top: 0, behavior: 'smooth' });
        return false;
      }
    }
    return true;
  }

  clearError(field) {
    if (this.errors[field]) {
      this.errors = { ...this.errors, [field]: undefined };
    }
  }

  // ── Step navigation ───────────────────────────────────────────────────────
  async autoFillLocationFields() {
    if (this.isGeoFilling) return;
    this.isGeoFilling = true;
    try {
      const location = await getUserLocation();
      if (!location?.status || location.geo?.lat == null || location.geo?.long == null) return;

      const { lat, long: lng } = location.geo;

      if (!this.googleMapLink.trim()) {
        this.googleMapLink = `https://www.google.com/maps?q=${lat},${lng}`;
      }

      await loadGoogleMapsForGeo();

      const results = await new Promise((resolve) => {
        new window.google.maps.Geocoder().geocode(
          { location: { lat, lng } },
          (r, status) => resolve(status === 'OK' ? r : []),
        );
      });

      if (!results.length) return;

      const { address, country, division, district, city, postCode } =
        extractAddressComponents(results);

      if (!this.clubAddress.trim()      && address)  this.clubAddress      = address;
      if (!this.clubCountry.trim()      && country)  this.clubCountry      = country;
      if (!this.clubDivisionArea.trim() && division) this.clubDivisionArea = division;
      if (!this.clubDistrict.trim()     && district) this.clubDistrict     = district;
      if (!this.clubCity.trim()         && city)     this.clubCity         = city;
      if (!this.clubPostCode.trim()     && postCode) this.clubPostCode     = postCode;
    } catch {
      // silently skip if location or geocoding fails
    } finally {
      this.isGeoFilling = false;
    }
  }

  @action nextStep() {
    if (this.validateStep(this.currentStep) && this.currentStep < this.totalSteps) {
      this.currentStep++;
      window.scrollTo({ top: 0, behavior: 'smooth' });
      if (this.currentStep === 2) this.autoFillLocationFields();
    }
  }

  @action prevStep() {
    if (this.currentStep > 1) {
      this.currentStep--;
      this.errors = {};
      window.scrollTo({ top: 0, behavior: 'smooth' });
      if (this.currentStep === 2) this.autoFillLocationFields();
    }
  }

  @action goToStep(step) {
    if (step < this.currentStep) {
      this.currentStep = step;
      this.errors = {};
      if (this.currentStep === 2) this.autoFillLocationFields();
    }
  }

  // ── Field updates ─────────────────────────────────────────────────────────
  @action setClubType(event) {
    this.clubType = event.target.value;
    this.clearError('clubType');
  }

  @action setSportsScope(event) {
    this.sportsScope = event.target.value;
    this.clearError('sportsScope');
    // Enforce single-sport limit immediately on scope change
    if (event.target.value === 'Single Sports' && this.selectedSports.length > 1) {
      this.selectedSports = [this.selectedSports[0]];
    }
    this.clearError('sports');
  }

  @action setClubDivision(event) {
    this.clubDivision = event.target.value;
  }

  @action updateField(field, event) {
    this[field] = event.target.value;
    this.clearError(field);
    if (field === 'clubEmail') {
      this.resetEmailVerification();
    }
  }

  // ── Club Manager Search ───────────────────────────────────────────────────
  @action onManagerInput(event) {
    const q = event.target.value;
    this.managerSearchQuery   = q;
    this.managerSearchResults = [];
    this.managerSearchOpen    = false;

    clearTimeout(this._managerSearchTimer);

    const token = this.session.token;
    const isValidEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(q.trim());
    if (!q.trim() || !token || !isValidEmail) return;

    this._managerSearchTimer = setTimeout(async () => {
      this.managerSearchLoading = true;
      try {
        const loc  = await getUserLocation();
        const lat  = loc?.geo?.lat  ?? 23.79431617060116;
        const long = loc?.geo?.long ?? 90.40723691635932;
        const url  = `https://khelasearch.adnanfoundation.com/search/auth-user-search/?search_data=${encodeURIComponent(q)}&country_code=BD&latitude=${lat}&longitude=${long}`;
        const res  = await fetch(url, {
          headers: { Authorization: `Bearer ${token}` },
        });
        const data = await res.json();
        const already = this.selectedManagers.map(m => m.userid);
        this.managerSearchResults = (data.results || []).filter(r => !already.includes(r.userid));
        this.managerSearchOpen    = this.managerSearchResults.length > 0;
      } catch {
        this.managerSearchResults = [];
        this.managerSearchOpen    = false;
      } finally {
        this.managerSearchLoading = false;
      }
    }, 350);
  }

  @action selectManager(user) {
    if (!this.selectedManagers.find(m => m.userid === user.userid)) {
      this.selectedManagers = [...this.selectedManagers, user];
    }
    this.managerSearchQuery   = '';
    this.managerSearchResults = [];
    this.managerSearchOpen    = false;
  }

  @action removeManager(userid) {
    this.selectedManagers = this.selectedManagers.filter(m => m.userid !== userid);
  }

  @action closeManagerDropdown() {
    this.managerSearchOpen = false;
  }

  // ── Sports multi-select ───────────────────────────────────────────────────
  @action toggleSportsDropdown() {
    this.sportsDropdownOpen = !this.sportsDropdownOpen;
  }

  @action closeSportsDropdown() {
    this.sportsDropdownOpen = false;
  }

  @action toggleSport(sport) {
    if (this.selectedSports.includes(sport)) {
      this.selectedSports = this.selectedSports.filter(s => s !== sport);
    } else {
      if (this.sportsScope === 'Single Sports' && this.selectedSports.length >= 1) {
        // Replace instead of add for single-sport clubs
        this.selectedSports = [sport];
      } else {
        this.selectedSports = [...this.selectedSports, sport];
      }
    }
    this.clearError('sports');
  }

  // ── File uploads ──────────────────────────────────────────────────────────
  @action triggerBannerUpload() {
    document.getElementById('banner-file-input').click();
  }

  @action triggerLogoUpload() {
    document.getElementById('logo-file-input').click();
  }

  @action handleBannerUpload(event) {
    const file = event.target.files[0];
    if (!file) return;
    if (file.size > 200 * 1024) {
      this.bannerError   = 'Banner must be 200 KB or less';
      this.bannerFile    = null;
      this.bannerPreview = null;
      event.target.value = '';
      return;
    }
    this.bannerError = '';
    this.bannerFile  = file;
    const reader = new FileReader();
    reader.onload = (e) => { this.bannerPreview = e.target.result; };
    reader.readAsDataURL(file);
    this.clearError('banner');
  }

  @action handleLogoUpload(event) {
    const file = event.target.files[0];
    if (!file) return;
    if (file.size > 100 * 1024) {
      this.logoError    = 'Logo must be 100 KB or less';
      this.logoFile     = null;
      this.logoPreview  = null;
      event.target.value = '';
      return;
    }
    this.logoError   = '';
    this.logoFile    = file;
    const reader = new FileReader();
    reader.onload = (e) => { this.logoPreview = e.target.result; };
    reader.readAsDataURL(file);
    this.clearError('logo');
  }

  @action removeBanner() {
    this.bannerFile    = null;
    this.bannerPreview = null;
    this.bannerError   = '';
    const el = document.getElementById('banner-file-input');
    if (el) el.value = '';
  }

  @action removeLogo() {
    this.logoFile    = null;
    this.logoPreview = null;
    this.logoError   = '';
    const el = document.getElementById('logo-file-input');
    if (el) el.value = '';
  }

  // ── Club colors ───────────────────────────────────────────────────────────
  @action addColor() {
    this.clubColors = [...this.clubColors, '#6366f1'];
  }

  @action updateColor(index, event) {
    const copy = [...this.clubColors];
    copy[index] = event.target.value;
    this.clubColors = copy;
  }

  @action removeColor(index) {
    if (this.clubColors.length > 1) {
      this.clubColors = this.clubColors.filter((_, i) => i !== index);
    }
  }

  // ── Rich-text editor ──────────────────────────────────────────────────────
  @action fmt(cmd) {
    const el = document.getElementById('rich-editor');
    el?.focus();
    document.execCommand(cmd, false, null);
  }

  @action fmtVal(cmd, event) {
    const el = document.getElementById('rich-editor');
    el?.focus();
    document.execCommand(cmd, false, event.target.value);
  }

  @action setTextColor(event) {
    const el = document.getElementById('rich-editor');
    el?.focus();
    document.execCommand('foreColor', false, event.target.value);
  }

  @action onDescriptionInput(event) {
    this.description = event.target.innerHTML;
    this.clearError('description');
  }

  // ── Dynamic link lists ────────────────────────────────────────────────────
  @action addVideoLink()            { this.videoLinks  = [...this.videoLinks,  '']; }
  @action removeVideoLink(index)    { if (this.videoLinks.length  > 1) this.videoLinks  = this.videoLinks.filter((_,i)  => i !== index); }
  @action updateVideoLink(index, e) { const a = [...this.videoLinks];  a[index] = e.target.value; this.videoLinks  = a; }

  @action addSocialLink()            { this.socialLinks = [...this.socialLinks, '']; }
  @action removeSocialLink(index)    { if (this.socialLinks.length > 1) this.socialLinks = this.socialLinks.filter((_,i) => i !== index); }
  @action updateSocialLink(index, e) { const a = [...this.socialLinks]; a[index] = e.target.value; this.socialLinks = a; }

  // ── Email OTP verification ────────────────────────────────────────────────
  @action async sendEmailOtp() {
    const email = this.clubEmail.trim();
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      this.errors = { ...this.errors, clubEmail: 'Enter a valid email address first' };
      return;
    }
    this.isSendingOtp = true;
    this.otpError = '';
    try {
      const temp_end_point = 'http://192.168.5.241:8000/auth_user/send-otp-verified-email/'
      const main_end_point = 'https://spordiumapi.adnanfoundation.com/auth_user/send-otp-verified-email/'
      const res = await fetch(main_end_point, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email }),
      });
      const data = await res.json();
      if (res.ok) {
        this.emailOtpToken = data.token;
        this.emailOtpSent  = true;
        this.otpValue      = '';
      } else {
        this.otpError = data.message || 'Failed to send OTP. Please try again.';
      }
    } catch {
      this.otpError = 'Network error. Please try again.';
    } finally {
      this.isSendingOtp = false;
    }
  }

  @action async verifyEmailOtp() {
    if (!this.otpValue.trim()) {
      this.otpError = 'Please enter the OTP';
      return;
    }
    this.isVerifyingOtp = true;
    this.otpError = '';
    try {
      const temp_end_point = 'http://192.168.5.241:8000/auth_user/verify-otp-verified-email/'
      const main_end_point = 'https://spordiumapi.adnanfoundation.com/auth_user/verify-otp-verified-email/'
      const res = await fetch(main_end_point, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: this.clubEmail.trim(),
          otp:   this.otpValue.trim(),
          token: this.emailOtpToken,
        }),
      });
      const data = await res.json();
      if (res.ok) {
        this.emailVerified      = true;
        this.emailVerifiedToken = data.token;
        this.emailOtpSent       = false;
        this.otpError           = '';
      } else {
        this.otpError = data.message || 'Invalid OTP. Please try again.';
      }
    } catch {
      this.otpError = 'Network error. Please try again.';
    } finally {
      this.isVerifyingOtp = false;
    }
  }

  @action updateOtp(event) {
    this.otpValue = event.target.value;
    this.otpError = '';
  }

  @action resetEmailVerification() {
    this.emailVerified      = false;
    this.emailOtpSent       = false;
    this.emailOtpToken      = '';
    this.emailVerifiedToken = '';
    this.otpValue           = '';
    this.otpError           = '';
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  @action async handleSubmit() {
    if (!this.validateAll()) return;

    const token = this.session.token;
    if (!token) {
      this._setSubmitError('You must be logged in to create a club. Please sign in and try again.');
      return;
    }

    this.isSubmitting = true;
    clearTimeout(this._submitErrorTimer);
    this.submitError  = '';
    this.submitErrors = [];

    try {
      // Resolve lat/long
      const loc  = await getUserLocation();
      const lat  = loc?.geo?.lat  ?? '23.746466';
      const long = loc?.geo?.long ?? '90.376015';

      const urlRe      = /^https?:\/\/.+\..+/;
      const colorNames = ['home', 'away', 'third', 'fourth', 'fifth'];

      // Build payload JSON — only include optional URL fields when non-empty & valid
      const payload = {
        name:               this.clubName.trim(),
        club_type:          this.clubType,
        sports_scope:       this.sportsScope,
        sports:             this.selectedSports,
        managers:           this.selectedManagers.map(m => m.userid),
        mail:               this.clubEmail.trim(),
        email_verify_token: this.emailVerifiedToken,
        phone:              this.clubPhone.trim(),
        country:            this.clubCountry.trim(),
        division:           this.clubDivisionArea.trim(),
        district:           this.clubDistrict.trim(),
        city:               this.clubCity.trim(),
        address:            this.clubAddress.trim(),
        postcode:           this.clubPostCode.trim(),
        location:           this.googleMapLink.trim(),
        lat_long:           { lat: String(lat), long: String(long) },
        established_date:   this.establishedDate,
        colors:             this.clubColors.map((color, i) => ({
                              name:  colorNames[i] ?? `color${i + 1}`,
                              color,
                            })),
        videos:       this.videoLinks.filter(v => urlRe.test(v.trim())),
        social_links: this.socialLinks.filter(v => urlRe.test(v.trim())),
      };

      // Only include website if the user filled it in
      if (this.clubWebsite.trim()) payload.website = this.clubWebsite.trim();

      const form = new FormData();
      form.append('payload', JSON.stringify(payload));
      form.append('logo',    this.logoFile);
      if (this.bannerFile) form.append('banner', this.bannerFile);
      form.append('content', JSON.stringify({ insert: this.description }));
      const temp_api = 'http://192.168.5.241:8000'
      const res  = await fetch(`${KHELA_API}/clubs/create/`, {
        method:  'POST',
        headers: { Authorization: `Bearer ${token}` },
        body:    form,
      });

      const data = await res.json().catch(() => ({}));

      if (res.ok) {
        this.submitResponse = data;
        this.submitted = true;
        this._startRedirectCountdown();
        window.scrollTo({ top: 0, behavior: 'smooth' });
      } else {
        this._setSubmitError(
          data?.message || data?.detail || 'Something went wrong while creating your club. Please review the errors below.',
          Array.isArray(data?.errors) ? data.errors : [],
        );
      }
    } catch {
      this._setSubmitError('Network error — please check your connection and try again.');
    } finally {
      this.isSubmitting = false;
    }
  }


  // ── Template ──────────────────────────────────────────────────────────────
  <template>
    {{! Hidden file inputs — must live in parent so @onTrigger callbacks can click them }}
    <input id="banner-file-input" type="file" accept="image/*" class="hidden" {{on "change" this.handleBannerUpload}} />
    <input id="logo-file-input"   type="file" accept="image/*" class="hidden" {{on "change" this.handleLogoUpload}} />

    <div class="min-h-screen bg-gradient-to-br from-slate-50 via-indigo-50/30 to-violet-50/20
                dark:from-gray-950 dark:via-indigo-950/30 dark:to-violet-950/20
                py-10 px-4 sm:px-6">
      <div class="max-w-3xl mx-auto">

        {{! ── Success state ─────────────────────────────────────────────────── }}
        {{#if this.submitted}}
          <div class="flex flex-col items-center justify-center py-16 text-center animate-fade-in">

            {{! Club logo with glow ring }}
            <div class="relative mb-8">
              <div class="absolute inset-0 rounded-full bg-indigo-400/30 dark:bg-indigo-500/20 animate-ping scale-110 opacity-40"></div>
              {{#if this.logoPreview}}
                <div class="relative w-28 h-28 rounded-full ring-4 ring-indigo-500/40 shadow-2xl shadow-indigo-500/30 overflow-hidden bg-white dark:bg-gray-800">
                  <img src={{this.logoPreview}} alt="Club logo" class="w-full h-full object-cover" />
                </div>
              {{else}}
                <div class="relative w-28 h-28 rounded-full ring-4 ring-indigo-500/40 shadow-2xl shadow-indigo-500/30
                            bg-gradient-to-br from-indigo-500 via-violet-500 to-fuchsia-500
                            flex items-center justify-center">
                  <svg class="w-14 h-14 text-white" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>
                  </svg>
                </div>
              {{/if}}
              <div class="absolute -bottom-1 -right-1 w-8 h-8 rounded-full bg-emerald-500 border-2 border-white dark:border-gray-950
                          flex items-center justify-center shadow-lg">
                <svg class="w-4 h-4 text-white" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M20 6L9 17l-5-5"/>
                </svg>
              </div>
            </div>

            <h2 class="text-3xl font-extrabold text-gray-900 dark:text-white mb-1 tracking-tight">
              {{this.clubName}}
            </h2>
            <p class="text-sm font-medium text-indigo-500 dark:text-indigo-400 mb-6 tracking-wide uppercase">
              Club Successfully Created
            </p>

            <div class="w-full max-w-md mb-6">
              {{#if this.submitResponse.upstream}}
                <div class="rounded-2xl border border-amber-200 dark:border-amber-700/50 bg-amber-50 dark:bg-amber-900/10 p-4 text-left">
                  <div class="flex items-start gap-3">
                    <svg class="w-5 h-5 text-amber-500 shrink-0 mt-0.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                      <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>
                    </svg>
                    <div class="flex-1 min-w-0">
                      <p class="text-sm font-semibold text-amber-800 dark:text-amber-300 mb-0.5">Partial Success</p>
                      <p class="text-sm text-amber-700 dark:text-amber-400">{{this.submitResponse.message}}</p>
                      {{#if this.submitResponse.data.club_id}}
                        <p class="mt-2 text-xs font-mono text-amber-600/80 dark:text-amber-500/70 bg-amber-100 dark:bg-amber-900/30 rounded px-2 py-1 inline-block">
                          Club ID: {{this.submitResponse.data.club_id}}
                        </p>
                      {{/if}}
                    </div>
                  </div>
                </div>
              {{else}}
                <div class="rounded-2xl border border-emerald-200 dark:border-emerald-700/50 bg-emerald-50 dark:bg-emerald-900/10 p-4 text-left">
                  <div class="flex items-start gap-3">
                    <svg class="w-5 h-5 text-emerald-500 shrink-0 mt-0.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                      <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/>
                    </svg>
                    <div class="flex-1 min-w-0">
                      <p class="text-sm font-semibold text-emerald-800 dark:text-emerald-300 mb-0.5">All Done!</p>
                      <p class="text-sm text-emerald-700 dark:text-emerald-400">
                        {{#if this.submitResponse.message}}
                          {{this.submitResponse.message}}
                        {{else}}
                          Your club has been successfully submitted and is now under review.
                        {{/if}}
                      </p>
                      {{#if this.submitResponse.data.club_id}}
                        <p class="mt-2 text-xs font-mono text-emerald-600/80 dark:text-emerald-500/70 bg-emerald-100 dark:bg-emerald-900/30 rounded px-2 py-1 inline-block">
                          Club ID: {{this.submitResponse.data.club_id}}
                        </p>
                      {{/if}}
                    </div>
                  </div>
                </div>
              {{/if}}
            </div>

            <div class="flex flex-wrap justify-center gap-3">
              <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full
                          bg-emerald-50 dark:bg-emerald-900/20 border border-emerald-200 dark:border-emerald-700/50
                          text-emerald-700 dark:text-emerald-400 text-sm font-semibold">
                <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>
                </svg>
                Under Review
              </div>
              <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full
                          bg-indigo-50 dark:bg-indigo-900/20 border border-indigo-200 dark:border-indigo-700/50
                          text-indigo-700 dark:text-indigo-400 text-sm font-semibold">
                <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
                </svg>
                {{this.selectedSports.length}} Sport(s)
              </div>
            </div>

            {{! Redirect countdown }}
            <div class="mt-10 w-full max-w-sm">
              <div class="relative h-1.5 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden mb-4">
                <div class="absolute inset-y-0 left-0 rounded-full
                            bg-gradient-to-r from-indigo-500 via-violet-500 to-fuchsia-500
                            transition-all duration-1000 ease-linear"
                     style={{this.redirectProgressStyle}}></div>
              </div>
              <p class="text-sm text-gray-400 dark:text-gray-500 mb-4">
                Redirecting to Clubs in
                <span class="font-bold tabular-nums text-indigo-500 dark:text-indigo-400">{{this.redirectCountdown}}s</span>
              </p>
              <button type="button" {{on "click" this.goToClubs}}
                      class="inline-flex items-center gap-2 px-6 py-2.5 rounded-full
                             bg-gradient-to-r from-indigo-500 via-violet-500 to-fuchsia-500
                             text-white text-sm font-semibold shadow-lg shadow-indigo-500/30
                             hover:shadow-xl hover:shadow-indigo-500/40 hover:scale-105
                             active:scale-95 transition-all duration-200 cursor-pointer">
                <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M5 12h14"/><path d="m12 5 7 7-7 7"/>
                </svg>
                Go to Clubs!
              </button>
            </div>

          </div>

        {{else}}

          {{! ── Page header ──────────────────────────────────────────────────── }}
          <div class="text-center mb-8">
            <h1 class="text-3xl sm:text-4xl font-extrabold text-gray-900 dark:text-white mb-2">
              Create Your
              <span class="text-transparent bg-clip-text bg-gradient-to-r from-indigo-500 via-violet-500 to-fuchsia-500">
                Club
              </span>
            </h1>
            <p class="text-gray-500 dark:text-gray-400 text-sm">Fill in the details to register your sports club on Spordium.</p>
          </div>

          {{! ── Step indicator ────────────────────────────────────────────────── }}
          <div class="mb-8">
            <FormStepIndicator
              @steps={{this.steps}}
              @currentStep={{this.currentStep}}
              @progressStyle={{this.stepProgressStyle}}
              @onGoToStep={{this.goToStep}}
            />
          </div>

          {{! ── Form card ────────────────────────────────────────────────────── }}
          <div class="bg-white dark:bg-gray-900 rounded-3xl shadow-2xl shadow-indigo-500/5
                      border border-gray-100 dark:border-gray-700/60 overflow-hidden">

            {{! ════════════════════════════════════════════════════════════════ }}
            {{! STEP 1 — CLUB IDENTITY                                          }}
            {{! ════════════════════════════════════════════════════════════════ }}
            {{#if (eq this.currentStep 1)}}
              <div class="p-6 sm:p-8">

                <div class="flex items-center gap-3 mb-6 pb-4 border-b border-gray-100 dark:border-gray-700/60">
                  <div class="w-9 h-9 rounded-xl bg-indigo-100 dark:bg-indigo-900/40 flex items-center justify-center shrink-0">
                    <svg class="w-4.5 h-4.5 text-indigo-600 dark:text-indigo-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                      <path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/>
                    </svg>
                  </div>
                  <div>
                    <h2 class="text-base font-bold text-gray-900 dark:text-white">Club Identity</h2>
                    <p class="text-xs text-gray-500 dark:text-gray-400">Define your club's type and sports</p>
                  </div>
                </div>

                <div class="space-y-5">

                  {{! Club Type }}
                  <div>
                    <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
                      Club Type <span class="text-rose-500">*</span>
                    </label>
                    <div class="relative">
                      <select
                        value={{this.clubType}}
                        {{on "change" this.setClubType}}
                        class="w-full appearance-none pl-4 pr-10 py-3 rounded-xl
                               border transition-all duration-200
                               {{if this.errors.clubType
                                 'border-rose-400 dark:border-rose-500 bg-rose-50 dark:bg-rose-900/10'
                                 'border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-800
                                  focus:border-indigo-400 dark:focus:border-indigo-500'}}
                               text-gray-900 dark:text-gray-100
                               focus:outline-none focus:ring-2 focus:ring-indigo-400/30 dark:focus:ring-indigo-500/30"
                      >
                        <option value="">Select Club Type</option>
                        {{#each this.clubTypeOptions as |opt|}}
                          <option value={{opt.value}}>{{opt.label}}</option>
                        {{/each}}
                      </select>
                      <div class="pointer-events-none absolute inset-y-0 right-3 flex items-center">
                        <svg class="w-4 h-4 text-gray-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                          <path d="M6 9l6 6 6-6"/>
                        </svg>
                      </div>
                    </div>
                    {{#if this.errors.clubType}}
                      <p class="mt-1 text-xs text-rose-500 flex items-center gap-1">
                        <svg class="w-3 h-3 shrink-0" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a10 10 0 1 0 0 20A10 10 0 0 0 12 2zm1 13H11v-2h2v2zm0-4H11V7h2v4z"/></svg>
                        {{this.errors.clubType}}
                      </p>
                    {{/if}}
                  </div>

                  {{! Sports Scope }}
                  <div>
                    <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
                      Sports Scope <span class="text-rose-500">*</span>
                    </label>
                    <div class="relative">
                      <select
                        value={{this.sportsScope}}
                        {{on "change" this.setSportsScope}}
                        class="w-full appearance-none pl-4 pr-10 py-3 rounded-xl
                               border transition-all duration-200
                               {{if this.errors.sportsScope
                                 'border-rose-400 dark:border-rose-500 bg-rose-50 dark:bg-rose-900/10'
                                 'border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-800
                                  focus:border-indigo-400 dark:focus:border-indigo-500'}}
                               text-gray-900 dark:text-gray-100
                               focus:outline-none focus:ring-2 focus:ring-indigo-400/30 dark:focus:ring-indigo-500/30"
                      >
                        <option value="">Select Sports Scope</option>
                        {{#each this.sportsScopeOptions as |opt|}}
                          <option value={{opt.value}}>{{opt.label}}</option>
                        {{/each}}
                      </select>
                      <div class="pointer-events-none absolute inset-y-0 right-3 flex items-center">
                        <svg class="w-4 h-4 text-gray-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                          <path d="M6 9l6 6 6-6"/>
                        </svg>
                      </div>
                    </div>
                    {{#if this.errors.sportsScope}}
                      <p class="mt-1 text-xs text-rose-500 flex items-center gap-1">
                        <svg class="w-3 h-3 shrink-0" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a10 10 0 1 0 0 20A10 10 0 0 0 12 2zm1 13H11v-2h2v2zm0-4H11V7h2v4z"/></svg>
                        {{this.errors.sportsScope}}
                      </p>
                    {{/if}}
                  </div>

                  {{! Sports multi-select }}
                  <SportsMultiSelect
                    @sportsScope={{this.sportsScope}}
                    @selectedSports={{this.selectedSports}}
                    @sportsWithSelection={{this.sportsWithSelection}}
                    @isOpen={{this.sportsDropdownOpen}}
                    @error={{this.errors.sports}}
                    @required={{true}}
                    @onToggle={{this.toggleSportsDropdown}}
                    @onClose={{this.closeSportsDropdown}}
                    @onToggleSport={{this.toggleSport}}
                  />

                  {{! Club Name }}
                  <div>
                    <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
                      Club Name <span class="text-rose-500">*</span>
                    </label>
                    <input
                      type="text"
                      placeholder="Enter your club's official name"
                      value={{this.clubName}}
                      {{on "input" (fn this.updateField 'clubName')}}
                      class="w-full px-4 py-3 rounded-xl border transition-all duration-200
                             {{if this.errors.clubName
                               'border-rose-400 dark:border-rose-500 bg-rose-50 dark:bg-rose-900/10'
                               'border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-800
                                focus:border-indigo-400 dark:focus:border-indigo-500'}}
                             text-gray-900 dark:text-gray-100 placeholder:text-gray-400 dark:placeholder:text-gray-500
                             focus:outline-none focus:ring-2 focus:ring-indigo-400/30 dark:focus:ring-indigo-500/30"
                    />
                    {{#if this.errors.clubName}}
                      <p class="mt-1 text-xs text-rose-500 flex items-center gap-1">
                        <svg class="w-3 h-3 shrink-0" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a10 10 0 1 0 0 20A10 10 0 0 0 12 2zm1 13H11v-2h2v2zm0-4H11V7h2v4z"/></svg>
                        {{this.errors.clubName}}
                      </p>
                    {{/if}}
                  </div>

                </div>
              </div>
            {{/if}}

            {{! ════════════════════════════════════════════════════════════════ }}
            {{! STEP 2 — CONTACT & LOCATION                                     }}
            {{! ════════════════════════════════════════════════════════════════ }}
            {{#if (eq this.currentStep 2)}}
              <div class="p-6 sm:p-8">

                <div class="flex items-center gap-3 mb-6 pb-4 border-b border-gray-100 dark:border-gray-700/60">
                  <div class="w-9 h-9 rounded-xl bg-violet-100 dark:bg-violet-900/40 flex items-center justify-center shrink-0">
                    <svg class="w-4.5 h-4.5 text-violet-600 dark:text-violet-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                      <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8z"/>
                    </svg>
                  </div>
                  <div>
                    <h2 class="text-base font-bold text-gray-900 dark:text-white">Contact & Location</h2>
                    <p class="text-xs text-gray-500 dark:text-gray-400">How people can reach your club</p>
                  </div>
                </div>

                <div class="space-y-5">

                  <ManagerSearch
                    @selectedManagers={{this.selectedManagers}}
                    @searchQuery={{this.managerSearchQuery}}
                    @searchResults={{this.managerSearchResults}}
                    @searchOpen={{this.managerSearchOpen}}
                    @searchLoading={{this.managerSearchLoading}}
                    @error={{this.errors.managers}}
                    @onInput={{this.onManagerInput}}
                    @onSelect={{this.selectManager}}
                    @onRemove={{this.removeManager}}
                    @onCloseDropdown={{this.closeManagerDropdown}}
                  />

                  <EmailOtpVerifier
                    @email={{this.clubEmail}}
                    @verified={{this.emailVerified}}
                    @otpSent={{this.emailOtpSent}}
                    @otpValue={{this.otpValue}}
                    @otpError={{this.otpError}}
                    @error={{this.errors.clubEmail}}
                    @isSending={{this.isSendingOtp}}
                    @isVerifying={{this.isVerifyingOtp}}
                    @required={{true}}
                    @onEmailInput={{fn this.updateField 'clubEmail'}}
                    @onSendOtp={{this.sendEmailOtp}}
                    @onVerifyOtp={{this.verifyEmailOtp}}
                    @onOtpInput={{this.updateOtp}}
                  />

                  {{! Club Phone — kept inline: has BD flag + +880 prefix specific to this form }}
                  <div>
                    <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
                      Club Cell Phone <span class="text-rose-500">*</span>
                    </label>
                    <div class="flex gap-2">
                      <div class="flex items-center gap-1.5 px-3 py-3 rounded-xl
                                  border border-gray-200 dark:border-gray-600
                                  bg-gray-100 dark:bg-gray-700 shrink-0">
                        <span class="text-base">🇧🇩</span>
                        <span class="text-sm font-medium text-gray-600 dark:text-gray-300">+880</span>
                      </div>
                      <input
                        type="tel"
                        placeholder="01X XXXX XXXX"
                        value={{this.clubPhone}}
                        {{on "input" (fn this.updateField 'clubPhone')}}
                        class="flex-1 px-4 py-3 rounded-xl border transition-all duration-200
                               {{if this.errors.clubPhone
                                 'border-rose-400 dark:border-rose-500 bg-rose-50 dark:bg-rose-900/10'
                                 'border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-800
                                  focus:border-indigo-400 dark:focus:border-indigo-500'}}
                               text-gray-900 dark:text-gray-100 placeholder:text-gray-400 dark:placeholder:text-gray-500
                               focus:outline-none focus:ring-2 focus:ring-indigo-400/30 dark:focus:ring-indigo-500/30"
                      />
                    </div>
                    {{#if this.errors.clubPhone}}
                      <p class="mt-1 text-xs text-rose-500 flex items-center gap-1">
                        <svg class="w-3 h-3 shrink-0" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a10 10 0 1 0 0 20A10 10 0 0 0 12 2zm1 13H11v-2h2v2zm0-4H11V7h2v4z"/></svg>
                        {{this.errors.clubPhone}}
                      </p>
                    {{/if}}
                  </div>

                  {{! Location section divider }}
                  <div class="pt-1 pb-1">
                    <p class="text-xs font-bold tracking-widest uppercase text-gray-400 dark:text-gray-500">Location</p>
                    <div class="mt-2 h-px bg-gray-100 dark:bg-gray-700/60"></div>
                  </div>

                  <GeoTextInput
                    @label="Club Address"
                    @placeholder="Street address"
                    @value={{this.clubAddress}}
                    @error={{this.errors.clubAddress}}
                    @isGeoFilling={{this.isGeoFilling}}
                    @required={{true}}
                    @onInput={{fn this.updateField 'clubAddress'}}
                  />

                  <div class="grid grid-cols-2 gap-4">
                    <GeoTextInput
                      @label="Country"
                      @placeholder="Country"
                      @value={{this.clubCountry}}
                      @error={{this.errors.clubCountry}}
                      @isGeoFilling={{this.isGeoFilling}}
                      @required={{true}}
                      @onInput={{fn this.updateField 'clubCountry'}}
                    />
                    <GeoTextInput
                      @label="Division / State"
                      @placeholder="Division or state"
                      @value={{this.clubDivisionArea}}
                      @error={{this.errors.clubDivisionArea}}
                      @isGeoFilling={{this.isGeoFilling}}
                      @required={{true}}
                      @onInput={{fn this.updateField 'clubDivisionArea'}}
                    />
                  </div>

                  <div class="grid grid-cols-2 gap-4">
                    <GeoTextInput
                      @label="District"
                      @placeholder="District"
                      @value={{this.clubDistrict}}
                      @error={{this.errors.clubDistrict}}
                      @isGeoFilling={{this.isGeoFilling}}
                      @required={{true}}
                      @onInput={{fn this.updateField 'clubDistrict'}}
                    />
                    <GeoTextInput
                      @label="City"
                      @placeholder="City"
                      @value={{this.clubCity}}
                      @error={{this.errors.clubCity}}
                      @isGeoFilling={{this.isGeoFilling}}
                      @required={{true}}
                      @onInput={{fn this.updateField 'clubCity'}}
                    />
                  </div>

                  <div class="grid grid-cols-2 gap-4">
                    <GeoTextInput
                      @label="Post Code"
                      @placeholder="Post code"
                      @value={{this.clubPostCode}}
                      @error={{this.errors.clubPostCode}}
                      @isGeoFilling={{this.isGeoFilling}}
                      @required={{true}}
                      @onInput={{fn this.updateField 'clubPostCode'}}
                    />
                    <GeoTextInput
                      @label="Google Map Link"
                      @placeholder="https://maps.google.com/..."
                      @value={{this.googleMapLink}}
                      @error={{this.errors.googleMapLink}}
                      @isGeoFilling={{this.isGeoFilling}}
                      @type="url"
                      @required={{true}}
                      @onInput={{fn this.updateField 'googleMapLink'}}
                    />
                  </div>

                  {{! Established Date }}
                  <div>
                    <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
                      Club Established Date <span class="text-rose-500">*</span>
                    </label>
                    <input
                      type="date"
                      value={{this.establishedDate}}
                      {{on "input" (fn this.updateField 'establishedDate')}}
                      class="w-full px-4 py-3 rounded-xl border transition-all duration-200
                             {{if this.errors.establishedDate
                               'border-rose-400 dark:border-rose-500 bg-rose-50 dark:bg-rose-900/10'
                               'border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-800
                                focus:border-indigo-400 dark:focus:border-indigo-500'}}
                             text-gray-900 dark:text-gray-100
                             focus:outline-none focus:ring-2 focus:ring-indigo-400/30 dark:focus:ring-indigo-500/30"
                    />
                    {{#if this.errors.establishedDate}}
                      <p class="mt-1 text-xs text-rose-500 flex items-center gap-1">
                        <svg class="w-3 h-3 shrink-0" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a10 10 0 1 0 0 20A10 10 0 0 0 12 2zm1 13H11v-2h2v2zm0-4H11V7h2v4z"/></svg>
                        {{this.errors.establishedDate}}
                      </p>
                    {{/if}}
                  </div>

                </div>
              </div>
            {{/if}}

            {{! ════════════════════════════════════════════════════════════════ }}
            {{! STEP 3 — MEDIA & BRANDING                                       }}
            {{! ════════════════════════════════════════════════════════════════ }}
            {{#if (eq this.currentStep 3)}}
              <div class="p-6 sm:p-8">

                <div class="flex items-center gap-3 mb-6 pb-4 border-b border-gray-100 dark:border-gray-700/60">
                  <div class="w-9 h-9 rounded-xl bg-fuchsia-100 dark:bg-fuchsia-900/40 flex items-center justify-center shrink-0">
                    <svg class="w-4.5 h-4.5 text-fuchsia-600 dark:text-fuchsia-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                      <rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/>
                      <polyline points="21 15 16 10 5 21"/>
                    </svg>
                  </div>
                  <div>
                    <h2 class="text-base font-bold text-gray-900 dark:text-white">Media & Branding</h2>
                    <p class="text-xs text-gray-500 dark:text-gray-400">Upload images and define your club's visual identity</p>
                  </div>
                </div>

                <div class="space-y-6">

                  <ImageUploader
                    @label="Club Banner"
                    @hint="900×300 px · max 200 KB"
                    @preview={{this.bannerPreview}}
                    @fileName={{this.bannerFile.name}}
                    @uploadError={{this.bannerError}}
                    @error={{this.errors.banner}}
                    @inputId="banner-file-input"
                    @required={{true}}
                    @onTrigger={{this.triggerBannerUpload}}
                    @onRemove={{this.removeBanner}}
                  />

                  <ImageUploader
                    @label="Club Logo"
                    @hint="80×60 px · max 100 KB"
                    @preview={{this.logoPreview}}
                    @uploadError={{this.logoError}}
                    @error={{this.errors.logo}}
                    @inputId="logo-file-input"
                    @variant="logo"
                    @required={{true}}
                    @onTrigger={{this.triggerLogoUpload}}
                    @onRemove={{this.removeLogo}}
                  />

                  <ColorPicker
                    @colorsForDisplay={{this.colorsForDisplay}}
                    @colorCount={{this.clubColors.length}}
                    @onAdd={{this.addColor}}
                    @onUpdate={{this.updateColor}}
                    @onRemove={{this.removeColor}}
                  />

                  <RichTextEditor
                    @editorId="rich-editor"
                    @placeholder="Describe your club — its history, goals, achievements…"
                    @fontFamilies={{this.fontFamilies}}
                    @fontSizes={{this.fontSizes}}
                    @error={{this.errors.description}}
                    @required={{true}}
                    @onInput={{this.onDescriptionInput}}
                    @onFmt={{this.fmt}}
                    @onFmtVal={{this.fmtVal}}
                    @onSetTextColor={{this.setTextColor}}
                  />

                </div>
              </div>
            {{/if}}

            {{! ════════════════════════════════════════════════════════════════ }}
            {{! STEP 4 — CLUB DETAILS                                           }}
            {{! ════════════════════════════════════════════════════════════════ }}
            {{#if (eq this.currentStep 4)}}
              <div class="p-6 sm:p-8">

                <div class="flex items-center gap-3 mb-6 pb-4 border-b border-gray-100 dark:border-gray-700/60">
                  <div class="w-9 h-9 rounded-xl bg-amber-100 dark:bg-amber-900/40 flex items-center justify-center shrink-0">
                    <svg class="w-4.5 h-4.5 text-amber-600 dark:text-amber-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
                      <polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/>
                      <line x1="16" y1="17" x2="8" y2="17"/><polyline points="10 9 9 9 8 9"/>
                    </svg>
                  </div>
                  <div>
                    <h2 class="text-base font-bold text-gray-900 dark:text-white">Club Details</h2>
                    <p class="text-xs text-gray-500 dark:text-gray-400">Online presence, age limits and competition tier</p>
                  </div>
                </div>

                <div class="space-y-5">

                  {{! Club URL Name — kept inline: has unique spordium.com/ prefix chrome }}
                  <div>
                    <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
                      Club URL Name <span class="text-rose-500">*</span>
                      <span class="ml-1.5 inline-flex items-center justify-center w-4 h-4 rounded-full
                                   bg-gray-200 dark:bg-gray-600 text-gray-500 dark:text-gray-400
                                   text-[10px] font-bold cursor-help"
                            title="Used in your club's public page URL. Lowercase, numbers, and hyphens only.">i</span>
                    </label>
                    <div class="flex rounded-xl overflow-hidden border transition-all duration-200
                                {{if this.errors.clubUrlName
                                  'border-rose-400 dark:border-rose-500'
                                  'border-gray-200 dark:border-gray-600
                                   focus-within:border-indigo-400 dark:focus-within:border-indigo-500
                                   focus-within:ring-2 focus-within:ring-indigo-400/30'}}">
                      <span class="px-3 py-3 bg-gray-100 dark:bg-gray-700 text-gray-500 dark:text-gray-400 text-sm border-r border-gray-200 dark:border-gray-600 shrink-0">
                        spordium.com/
                      </span>
                      <input
                        type="text"
                        placeholder="my-awesome-club"
                        value={{this.clubUrlName}}
                        {{on "input" (fn this.updateField 'clubUrlName')}}
                        class="flex-1 px-3 py-3 bg-gray-50 dark:bg-gray-800
                               text-gray-900 dark:text-gray-100 text-sm
                               placeholder:text-gray-400 dark:placeholder:text-gray-500
                               focus:outline-none"
                      />
                    </div>
                    {{#if this.errors.clubUrlName}}
                      <p class="mt-1 text-xs text-rose-500 flex items-center gap-1">
                        <svg class="w-3 h-3 shrink-0" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a10 10 0 1 0 0 20A10 10 0 0 0 12 2zm1 13H11v-2h2v2zm0-4H11V7h2v4z"/></svg>
                        {{this.errors.clubUrlName}}
                      </p>
                    {{/if}}
                  </div>

                  {{! Club Website }}
                  <div>
                    <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">Club Website</label>
                    <input
                      type="url"
                      placeholder="https://www.yourclub.com"
                      value={{this.clubWebsite}}
                      {{on "input" (fn this.updateField 'clubWebsite')}}
                      class="w-full px-4 py-3 rounded-xl border transition-all duration-200
                             {{if this.errors.clubWebsite
                               'border-rose-400 dark:border-rose-500 bg-rose-50 dark:bg-rose-900/10'
                               'border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-800
                                focus:border-indigo-400 dark:focus:border-indigo-500'}}
                             text-gray-900 dark:text-gray-100 placeholder:text-gray-400 dark:placeholder:text-gray-500
                             focus:outline-none focus:ring-2 focus:ring-indigo-400/30 dark:focus:ring-indigo-500/30"
                    />
                    {{#if this.errors.clubWebsite}}
                      <p class="mt-1 text-xs text-rose-500 flex items-center gap-1">
                        <svg class="w-3 h-3 shrink-0" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a10 10 0 1 0 0 20A10 10 0 0 0 12 2zm1 13H11v-2h2v2zm0-4H11V7h2v4z"/></svg>
                        {{this.errors.clubWebsite}}
                      </p>
                    {{/if}}
                  </div>

                  <LinkListField
                    @label="Club Video Links"
                    @links={{this.videoLinks}}
                    @error={{this.errors.videoLinks}}
                    @placeholder="YouTube / Vimeo link"
                    @onAdd={{this.addVideoLink}}
                    @onRemove={{this.removeVideoLink}}
                    @onUpdate={{this.updateVideoLink}}
                  />

                  <LinkListField
                    @label="Social Media Links"
                    @links={{this.socialLinks}}
                    @error={{this.errors.socialLinks}}
                    @placeholder="Facebook / Instagram / Twitter link"
                    @onAdd={{this.addSocialLink}}
                    @onRemove={{this.removeSocialLink}}
                    @onUpdate={{this.updateSocialLink}}
                  />

                  {{! Player Ages + Club Division }}
                  <div class="grid grid-cols-3 gap-4">
                    <div>
                      <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">Starting Age</label>
                      <input
                        type="number" min="4" max="100"
                        placeholder="e.g. 16"
                        value={{this.playerStartingAge}}
                        {{on "input" (fn this.updateField 'playerStartingAge')}}
                        class="w-full px-4 py-3 rounded-xl border border-gray-200 dark:border-gray-600
                               bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-gray-100
                               placeholder:text-gray-400 dark:placeholder:text-gray-500
                               focus:outline-none focus:ring-2 focus:ring-indigo-400/30 dark:focus:ring-indigo-500/30
                               focus:border-indigo-400 dark:focus:border-indigo-500 transition-all duration-200"
                      />
                    </div>
                    <div>
                      <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">Retiring Age</label>
                      <input
                        type="number" min="4" max="100"
                        placeholder="e.g. 40"
                        value={{this.playerRetiringAge}}
                        {{on "input" (fn this.updateField 'playerRetiringAge')}}
                        class="w-full px-4 py-3 rounded-xl border border-gray-200 dark:border-gray-600
                               bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-gray-100
                               placeholder:text-gray-400 dark:placeholder:text-gray-500
                               focus:outline-none focus:ring-2 focus:ring-indigo-400/30 dark:focus:ring-indigo-500/30
                               focus:border-indigo-400 dark:focus:border-indigo-500 transition-all duration-200"
                      />
                    </div>
                    <div>
                      <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
                        Club Division <span class="text-rose-500">*</span>
                      </label>
                      <div class="relative">
                        <select
                          value={{this.clubDivision}}
                          {{on "change" this.setClubDivision}}
                          class="w-full appearance-none pl-4 pr-8 py-3 rounded-xl
                                 border transition-all duration-200
                                 {{if this.errors.clubDivision
                                   'border-rose-400 dark:border-rose-500 bg-rose-50 dark:bg-rose-900/10'
                                   'border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-800
                                    focus:border-indigo-400 dark:focus:border-indigo-500'}}
                                 text-gray-900 dark:text-gray-100
                                 focus:outline-none focus:ring-2 focus:ring-indigo-400/30 dark:focus:ring-indigo-500/30"
                        >
                          <option value="">Select division</option>
                          {{#each this.divisionOptions as |opt|}}
                            <option value={{opt.value}}>{{opt.label}}</option>
                          {{/each}}
                        </select>
                        <div class="pointer-events-none absolute inset-y-0 right-2.5 flex items-center">
                          <svg class="w-3.5 h-3.5 text-gray-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M6 9l6 6 6-6"/>
                          </svg>
                        </div>
                      </div>
                      {{#if this.errors.clubDivision}}
                        <p class="mt-1 text-xs text-rose-500 flex items-center gap-1">
                          <svg class="w-3 h-3 shrink-0" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a10 10 0 1 0 0 20A10 10 0 0 0 12 2zm1 13H11v-2h2v2zm0-4H11V7h2v4z"/></svg>
                          {{this.errors.clubDivision}}
                        </p>
                      {{/if}}
                    </div>
                  </div>

                </div>
              </div>
            {{/if}}

            {{! ── Submit error banner ─────────────────────────────────────────── }}
            <FormSubmitError
              @error={{this.submitError}}
              @errors={{this.submitErrors}}
              @onDismiss={{this.clearSubmitError}}
            />

            {{! ── Navigation buttons ─────────────────────────────────────────── }}
            <FormNavButtons
              @currentStep={{this.currentStep}}
              @totalSteps={{this.totalSteps}}
              @isFirstStep={{this.isFirstStep}}
              @isLastStep={{this.isLastStep}}
              @isSubmitting={{this.isSubmitting}}
              @submitLabel="Create Club"
              @onPrev={{this.prevStep}}
              @onNext={{this.nextStep}}
              @onSubmit={{this.handleSubmit}}
            />

          </div>
        {{/if}}

      </div>
    </div>
  </template>
}
