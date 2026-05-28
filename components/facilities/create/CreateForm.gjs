import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { service } from '@ember/service';
import { getUserLocation } from 'spordium/utils/utility.helper';
import config from 'spordium/config/environment';

import ImageUploader      from '../../clubs/create/image-uploader';
import ManagerSearch      from '../../clubs/create/manager-search';
import EmailOtpVerifier   from '../../clubs/create/email-otp-verifier';
import PhoneOtpVerifier   from '../../clubs/create/phone-otp-verifier';
import GeoTextInput       from '../../clubs/create/geo-text-input';
import LinkListField      from '../../clubs/create/link-list-field';
import RichTextEditor     from '../../clubs/create/rich-text-editor';
import SportsMultiSelect  from '../../clubs/create/sports-multi-select';
import FormFieldError     from '../../clubs/create/form-field-error';
import FacBannerUploader  from './fac-banner-uploader';
import FacPictureGallery  from './fac-picture-gallery';
import FacUrlChecker      from './fac-url-checker';
import lucideIcon         from 'spordium/helpers/lucide-icon';

// ─── Constants ────────────────────────────────────────────────────────────────
const SPORTS = [
  'Football', 'Cricket', 'Basketball', 'Badminton', 'Tennis',
  'Volleyball', 'Hockey', 'Rugby', 'Baseball', 'Swimming',
  'Table Tennis', 'Golf', 'Boxing', 'Athletics', 'Cycling',
];

const FONT_FAMILIES = ['Arial', 'Georgia', 'Times New Roman', 'Courier New', 'Verdana'];
const FONT_SIZES = [
  { label: 'Small',   value: '2' },
  { label: 'Normal',  value: '3' },
  { label: 'Large',   value: '4' },
  { label: 'X-Large', value: '5' },
];

const BANNER_MAX_KB  = 500;
const LOGO_MAX_KB    = 200;
const PICTURE_MAX_KB = 500;
const MAX_SPORTS     = 5;
const MAX_PICTURES   = 10;
const API_BASE       = 'https://spordiumapi.adnanfoundation.com';

// ─── Google Maps geo-autofill ─────────────────────────────────────────────────
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

// ─── Helpers ──────────────────────────────────────────────────────────────────
function readFile(file) {
  return new Promise((resolve) => {
    const reader = new FileReader();
    reader.onload = (e) => resolve(e.target.result);
    reader.readAsDataURL(file);
  });
}

async function sha256Base64(file) {
  const buffer = await file.arrayBuffer();
  const hash   = await crypto.subtle.digest('SHA-256', buffer);
  const bytes  = new Uint8Array(hash);
  let binary   = '';
  bytes.forEach((b) => (binary += String.fromCharCode(b)));
  return btoa(binary);
}

function fileExt(file) {
  return file.name.split('.').pop()?.toLowerCase() || 'png';
}

// ══════════════════════════════════════════════════════════════════════════════
export default class FacilitiesCreateForm extends Component {
  @service session;
  @service router;
  @service toast;

  // ── Image state ─────────────────────────────────────────────────────────────
  @tracked bannerFile    = null;
  @tracked bannerPreview = null;
  @tracked bannerError   = null;

  @tracked logoFile      = null;
  @tracked logoPreview   = null;
  @tracked logoError     = null;

  @tracked pictureFiles    = [];
  @tracked picturePreviews = [];
  @tracked pictureError    = null;

  // ── Basic info ──────────────────────────────────────────────────────────────
  @tracked facilityName = '';

  // ── Manager search ──────────────────────────────────────────────────────────
  @tracked selectedManagers     = [];
  @tracked managerSearchQuery   = '';
  @tracked managerSearchResults = [];
  @tracked managerSearchOpen    = false;
  @tracked managerSearchLoading = false;
  _managerSearchTimer           = null;

  // ── Email OTP ───────────────────────────────────────────────────────────────
  @tracked facilityEmail   = '';
  @tracked emailVerified   = false;
  @tracked emailOtpSent    = false;
  @tracked otpValue        = '';
  @tracked otpError        = null;
  @tracked isSendingOtp    = false;
  @tracked isVerifyingOtp  = false;
  @tracked emailOtpToken      = null;
  @tracked emailVerifiedToken = null;

  // ── Phone OTP ───────────────────────────────────────────────────────────────
  @tracked facilityPhone       = '';
  @tracked phoneVerified        = false;
  @tracked phoneOtpSent         = false;
  @tracked phoneOtpValue        = '';
  @tracked phoneOtpHint         = null;
  @tracked phoneOtpToken        = null;
  @tracked phoneVerifiedToken   = null;
  @tracked phoneOtpError        = null;
  @tracked isSendingPhoneOtp    = false;
  @tracked isVerifyingPhoneOtp  = false;

  // ── Location ────────────────────────────────────────────────────────────────
  @tracked facilityAddress  = '';
  @tracked isGeoFilling     = false;
  @tracked facilityCountry  = '';
  @tracked facilityDivision = '';
  @tracked facilityDistrict = '';
  @tracked facilityCity     = '';
  @tracked facilityPostCode = '';
  @tracked googleMapLink    = '';
  @tracked facilityLat      = '';
  @tracked facilityLong     = '';

  // ── Date ────────────────────────────────────────────────────────────────────
  @tracked establishedDate = '';

  // ── Rich-text editor ────────────────────────────────────────────────────────
  @tracked fontFamilies = FONT_FAMILIES;
  @tracked fontSizes    = FONT_SIZES;

  // ── Sports ──────────────────────────────────────────────────────────────────
  @tracked selectedSports     = [];
  @tracked sportsDropdownOpen = false;

  // ── Links ───────────────────────────────────────────────────────────────────
  @tracked videoLinks      = [''];
  @tracked facilityWebsite = '';
  @tracked socialLinks     = [''];

  // ── URL name ────────────────────────────────────────────────────────────────
  @tracked facilityUrlName = '';
  @tracked urlChecking     = false;
  @tracked urlAvailable    = null;
  @tracked urlChecked      = false;
  @tracked urlCheckError   = null;

  // ── Submit state ─────────────────────────────────────────────────────────────
  @tracked isSubmitting   = false;
  @tracked submitProgress = null;
  @tracked isSuccess      = false;

  // ── Validation errors ────────────────────────────────────────────────────────
  @tracked errors = {};

  // ── Computed ────────────────────────────────────────────────────────────────
  get sportsWithSelection() {
    return SPORTS.map((name) => ({ name, selected: this.selectedSports.includes(name) }));
  }

  get authHeaders() {
    return {
      Authorization: `Bearer ${this.session.data?.authenticated?.token ?? this.session.token ?? ''}`,
    };
  }

  // Normalises the raw phone input into E.164 format (+880XXXXXXXXX).
  // Strips any leading zeros so "01601744571" → "+8801601744571" (not "+88001601744571").
  get normalizedPhone() {
    let p = this.facilityPhone.trim().replace(/\D/g, ''); // digits only
    p = p.replace(/^0+/, '');                             // strip leading zeros
    if (p.startsWith('880')) return `+${p}`;              // already has BD country code
    return `+880${p}`;
  }

  get BANNER_MAX_KB()  { return BANNER_MAX_KB; }
  get LOGO_MAX_KB()    { return LOGO_MAX_KB; }
  get MAX_SPORTS()     { return MAX_SPORTS; }
  get MAX_PICTURES()   { return MAX_PICTURES; }

  @action goBack()  { this.router.transitionTo('facilities'); }
  @action cancel()  { this.router.transitionTo('facilities'); }

  // ─── Banner ────────────────────────────────────────────────────────────────
  @action triggerBannerUpload() { document.getElementById('fac-banner-input')?.click(); }

  @action async onBannerChange(event) {
    const file = event.target.files?.[0];
    if (!file) return;
    if (file.size > BANNER_MAX_KB * 1024) { this.bannerError = `Banner must be under ${BANNER_MAX_KB} KB.`; return; }
    this.bannerError   = null;
    this.bannerFile    = file;
    this.bannerPreview = await readFile(file);
  }

  @action removeBanner() {
    this.bannerFile = null; this.bannerPreview = null; this.bannerError = null;
    const input = document.getElementById('fac-banner-input');
    if (input) input.value = '';
  }

  // ─── Logo ──────────────────────────────────────────────────────────────────
  @action triggerLogoUpload() { document.getElementById('fac-logo-input')?.click(); }

  @action async onLogoChange(event) {
    const file = event.target.files?.[0];
    if (!file) return;
    if (file.size > LOGO_MAX_KB * 1024) { this.logoError = `Logo must be under ${LOGO_MAX_KB} KB.`; return; }
    this.logoError   = null;
    this.logoFile    = file;
    this.logoPreview = await readFile(file);
  }

  @action removeLogo() {
    this.logoFile = null; this.logoPreview = null; this.logoError = null;
    const input = document.getElementById('fac-logo-input');
    if (input) input.value = '';
  }

  // ─── Pictures ──────────────────────────────────────────────────────────────
  @action triggerPicturesUpload() { document.getElementById('fac-pictures-input')?.click(); }

  @action async onPicturesChange(event) {
    const files    = Array.from(event.target.files ?? []);
    const toAdd    = files.slice(0, MAX_PICTURES - this.pictureFiles.length);
    for (const file of toAdd) {
      if (file.size > PICTURE_MAX_KB * 1024) { this.pictureError = `Each picture must be under ${PICTURE_MAX_KB} KB.`; return; }
    }
    this.pictureError    = null;
    const newPreviews    = await Promise.all(toAdd.map(readFile));
    this.pictureFiles    = [...this.pictureFiles, ...toAdd];
    this.picturePreviews = [...this.picturePreviews, ...newPreviews];
    const input = document.getElementById('fac-pictures-input');
    if (input) input.value = '';
  }

  @action removePicture(index) {
    this.pictureFiles    = this.pictureFiles.filter((_, i) => i !== index);
    this.picturePreviews = this.picturePreviews.filter((_, i) => i !== index);
  }

  // ─── Field updates ─────────────────────────────────────────────────────────
  @action updateField(field, event) {
    this[field] = event.target.value;
    if (this.errors[field]) this.errors = { ...this.errors, [field]: null };
  }

  // ─── Manager ───────────────────────────────────────────────────────────────
  @action selectManager(user) {
    if (!this.selectedManagers.find((m) => m.userid === user.userid)) {
      this.selectedManagers = [...this.selectedManagers, user];
    }
    this.managerSearchQuery   = '';
    this.managerSearchResults = [];
    this.managerSearchOpen    = false;
    if (this.errors.managers) this.errors = { ...this.errors, managers: null };
  }

  @action removeManager(userid) {
    this.selectedManagers = this.selectedManagers.filter((m) => m.userid !== userid);
  }

  @action onManagerInput(event) {
    const q = event.target.value;
    this.managerSearchQuery   = q;
    this.managerSearchResults = [];
    this.managerSearchOpen    = false;
    clearTimeout(this._managerSearchTimer);
    const token = this.session.data?.authenticated?.token ?? this.session.token;
    const isValidEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(q.trim());
    if (!q.trim() || !token || !isValidEmail) return;
    this._managerSearchTimer = setTimeout(async () => {
      this.managerSearchLoading = true;
      try {
        const loc  = await getUserLocation();
        const lat  = loc?.geo?.lat  ?? 23.79431617060116;
        const long = loc?.geo?.long ?? 90.40723691635932;
        const url  = `https://khelasearch.adnanfoundation.com/search/auth-user-search/?search_data=${encodeURIComponent(q)}&country_code=BD&latitude=${lat}&longitude=${long}`;
        const res  = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
        const data = await res.json();
        const already = this.selectedManagers.map((m) => m.userid);
        this.managerSearchResults = (data.results || []).filter((r) => !already.includes(r.userid));
        this.managerSearchOpen    = this.managerSearchResults.length > 0;
      } catch {
        this.managerSearchResults = [];
        this.managerSearchOpen    = false;
      } finally {
        this.managerSearchLoading = false;
      }
    }, 350);
  }

  @action closeManagerDropdown() { this.managerSearchOpen = false; }

  // ─── Email OTP ─────────────────────────────────────────────────────────────
  @action onEmailInput(event) {
    this.facilityEmail = event.target.value;
    this.emailVerified = false;
    this.emailOtpSent  = false;
    this.otpError      = null;
    if (this.errors.facilityEmail) this.errors = { ...this.errors, facilityEmail: null };
  }

  @action async sendEmailOtp() {
    const email = this.facilityEmail.trim();
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      this.errors = { ...this.errors, facilityEmail: 'Enter a valid email address first' };
      return;
    }
    this.isSendingOtp = true;
    this.otpError = null;
    try {
      const res = await fetch(`${API_BASE}/auth_user/send-otp-verified-email/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email }),
      });
      const data = await res.json().catch(() => ({}));
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

  @action onOtpInput(event) { this.otpValue = event.target.value; this.otpError = null; }

  @action async verifyEmailOtp() {
    if (!this.otpValue.trim()) {
      this.otpError = 'Please enter the OTP';
      return;
    }
    this.isVerifyingOtp = true;
    this.otpError = null;
    try {
      const res = await fetch(`${API_BASE}/auth_user/verify-otp-verified-email/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: this.facilityEmail.trim(), otp: this.otpValue.trim(), token: this.emailOtpToken }),
      });
      const data = await res.json().catch(() => ({}));
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

  // ─── Phone OTP ─────────────────────────────────────────────────────────────
  @action onPhoneInput(event) {
    this.facilityPhone = event.target.value;
    this.phoneVerified = false; this.phoneOtpSent = false; this.phoneOtpError = null;
    if (this.errors.facilityPhone) this.errors = { ...this.errors, facilityPhone: null };
  }

  @action async sendPhoneOtp() {
    if (!this.facilityPhone) return;
    this.isSendingPhoneOtp = true; this.phoneOtpError = null; this.phoneOtpHint = null;
    try {
      const res = await fetch(`${API_BASE}/auth_user/send-otp-verified-phone/`, {
        method: 'POST',
        headers: { ...this.authHeaders, 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone: this.normalizedPhone }),
      });
      const data = await res.json().catch(() => ({}));
      if (res.ok) {
        this.phoneOtpSent  = true;
        this.phoneOtpToken = data.token ?? null;
        this.phoneOtpHint  = data.otp   ?? null;
      } else { this.phoneOtpError = data.message ?? 'Failed to send OTP.'; }
    } catch { this.phoneOtpError = 'Network error.Please try again.'; }
    finally { this.isSendingPhoneOtp = false; }
  }

  @action onPhoneOtpInput(event) { this.phoneOtpValue = event.target.value; this.phoneOtpError = null; }

  @action async verifyPhoneOtp() {
    if (!this.phoneOtpValue) return;
    this.isVerifyingPhoneOtp = true; this.phoneOtpError = null;
    try {
      const res = await fetch(`${API_BASE}/auth_user/verify-otp-verified-phone/`, {
        method: 'POST',
        headers: { ...this.authHeaders, 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone: this.normalizedPhone, otp: this.phoneOtpValue, token: this.phoneOtpToken }),
      });
      if (res.ok) {
        const d = await res.json().catch(() => ({}));
        this.phoneVerified      = true;
        this.phoneVerifiedToken = d.token ?? null;
        this.phoneOtpSent       = false;
        this.phoneOtpHint       = null;
      } else { const d = await res.json().catch(() => ({})); this.phoneOtpError = d.message ?? 'Invalid OTP.'; }
    } catch { this.phoneOtpError = 'Network error. Please try again.'; }
    finally { this.isVerifyingPhoneOtp = false; }
  }

  // ─── Geolocation ───────────────────────────────────────────────────────────
  @action useGeolocation() { this._autoFillLocationFields(); }

  async _autoFillLocationFields() {
    if (this.isGeoFilling) return;
    this.isGeoFilling = true;
    try {
      const location = await getUserLocation();
      if (!location?.status || location.geo?.lat == null || location.geo?.long == null) return;
      const { lat, long: lng } = location.geo;
      if (!this.facilityLat)  this.facilityLat  = String(lat);
      if (!this.facilityLong) this.facilityLong = String(lng);
      if (!this.googleMapLink.trim()) this.googleMapLink = `https://www.google.com/maps?q=${lat},${lng}`;
      await loadGoogleMapsForGeo();
      const results = await new Promise((resolve) => {
        new window.google.maps.Geocoder().geocode(
          { location: { lat, lng } },
          (r, status) => resolve(status === 'OK' ? r : []),
        );
      });
      if (!results.length) return;
      const { address, country, division, district, city, postCode } = extractAddressComponents(results);
      if (!this.facilityAddress.trim()  && address)  this.facilityAddress  = address;
      if (!this.facilityCountry.trim()  && country)  this.facilityCountry  = country;
      if (!this.facilityDivision.trim() && division) this.facilityDivision = division;
      if (!this.facilityDistrict.trim() && district) this.facilityDistrict = district;
      if (!this.facilityCity.trim()     && city)     this.facilityCity     = city;
      if (!this.facilityPostCode.trim() && postCode) this.facilityPostCode = postCode;
    } catch { /* silently skip */ }
    finally { this.isGeoFilling = false; }
  }

  @action clearAddress() { this.facilityAddress = ''; }

  // ─── Sports ────────────────────────────────────────────────────────────────
  @action toggleSportsDropdown() { this.sportsDropdownOpen = !this.sportsDropdownOpen; }
  @action closeSportsDropdown()  { this.sportsDropdownOpen = false; }

  @action toggleSport(name) {
    if (this.selectedSports.includes(name)) {
      this.selectedSports = this.selectedSports.filter((s) => s !== name);
    } else if (this.selectedSports.length < MAX_SPORTS) {
      this.selectedSports = [...this.selectedSports, name];
    }
    if (this.errors.sports) this.errors = { ...this.errors, sports: null };
  }

  // ─── Video links ───────────────────────────────────────────────────────────
  @action addVideoLink()            { this.videoLinks = [...this.videoLinks, '']; }
  @action removeVideoLink(i)        { this.videoLinks = this.videoLinks.filter((_, idx) => idx !== i); }
  @action updateVideoLink(i, event) { const l = [...this.videoLinks]; l[i] = event.target.value; this.videoLinks = l; }

  // ─── Social links ──────────────────────────────────────────────────────────
  @action addSocialLink()            { this.socialLinks = [...this.socialLinks, '']; }
  @action removeSocialLink(i)        { this.socialLinks = this.socialLinks.filter((_, idx) => idx !== i); }
  @action updateSocialLink(i, event) { const l = [...this.socialLinks]; l[i] = event.target.value; this.socialLinks = l; }

  // ─── URL name check ────────────────────────────────────────────────────────
  @action onUrlNameInput(event) {
    this.facilityUrlName = event.target.value.replace(/\s+/g, '');
    this.urlAvailable = null; this.urlChecked = false; this.urlCheckError = null;
    if (this.errors.facilityUrlName) this.errors = { ...this.errors, facilityUrlName: null };
  }

  @action async checkUrlName() {
    if (!this.facilityUrlName) return;
    this.urlChecking = true; this.urlAvailable = null; this.urlCheckError = null;
    try {
      const res = await fetch(
        `${API_BASE}/facility/check_if_fac_url_name_available/?fac_url_name=${encodeURIComponent(this.facilityUrlName)}`,
        { headers: this.authHeaders }
      );
      const data = await res.json().catch(() => ({}));
      this.urlAvailable = data.success === true;
      this.urlChecked   = true;
    } catch { this.urlCheckError = 'Could not verify URL name.'; }
    finally { this.urlChecking = false; }
  }

  // ─── Rich-text editor ──────────────────────────────────────────────────────
  @action onDescriptionInput() {}
  @action fmt(cmd)            { document.execCommand(cmd, false, null); }
  @action fmtVal(cmd, event)  { document.execCommand(cmd, false, event.target.value); }
  @action setTextColor(event) { document.execCommand('foreColor', false, event.target.value); }

  // ─── Validation ────────────────────────────────────────────────────────────
  _validate() {
    const errs = {};
    if (!this.facilityName.trim())     errs.facilityName    = 'Facility name is required.';
    if (!this.selectedManagers.length) errs.managers        = 'At least one manager is required.';
    if (!this.emailVerified)           errs.facilityEmail   = 'Please verify the facility email.';
    if (!this.facilityPhone.trim())    errs.facilityPhone   = 'Cell phone number is required.';
    else if (!this.phoneVerified)      errs.facilityPhone   = 'Please verify the facility phone number.';
    if (!this.facilityAddress.trim())  errs.facilityAddress = 'Address is required.';
    if (!this.facilityCountry.trim())  errs.facilityCountry = 'Country is required.';
    if (!this.facilityDivision.trim()) errs.facilityDivision = 'Division is required.';
    if (!this.facilityDistrict.trim()) errs.facilityDistrict = 'District is required.';
    if (!this.facilityCity.trim())     errs.facilityCity    = 'City is required.';
    if (!this.facilityPostCode.trim()) errs.facilityPostCode = 'Post code is required.';
    if (!this.establishedDate)         errs.establishedDate = 'Established date is required.';
    if (!this.selectedSports.length)   errs.sports          = 'Select at least one sport.';
    if (!this.facilityUrlName.trim())  errs.facilityUrlName = 'URL name is required.';
    const desc = document.getElementById('fac-rich-editor')?.innerHTML?.trim() ?? '';
    if (!desc || desc === '<br>')      errs.description     = 'Description is required.';
    return errs;
  }

  // ─── Submit ────────────────────────────────────────────────────────────────
  @action async submit(event) {
    event.preventDefault();
    this.submitError = null; this.submitErrors = [];

    if (this.facilityUrlName.trim() && !this.urlChecked) {
      this.toast.warning('Please check URL name availability first.');
      return;
    }

    const errs = this._validate();
    if (Object.keys(errs).length) {
      this.errors = errs;
      this.toast.error('Please fix the errors below before submitting.');
      window.scrollTo({ top: 0, behavior: 'smooth' });
      return;
    }

    this.isSubmitting = true; this.submitProgress = 'Preparing images…';
    try {
      // Step 1 — build image entries
      const imageEntries = [];
      if (this.bannerFile) imageEntries.push({ key: 'fac_banner', file: this.bannerFile });
      if (this.logoFile)   imageEntries.push({ key: 'fac_logo',   file: this.logoFile });
      this.pictureFiles.forEach((f, i) => imageEntries.push({ key: `fac_pic_${i + 1}`, file: f }));

      let objectTokens = {};

      if (imageEntries.length > 0) {
        const images = {}, checksums = {};
        for (const { key, file } of imageEntries) {
          images[key]    = fileExt(file);
          checksums[key] = await sha256Base64(file);
        }

        this.submitProgress = 'Requesting upload slots…';
        const initRes = await fetch(`${API_BASE}/auth_user/initiate-upload-auth/`, {
          method: 'POST',
          headers: { ...this.authHeaders, 'Content-Type': 'application/json' },
          body: JSON.stringify({ type: 'facility', images, checksums }),
        });
        if (!initRes.ok) {
          const d = await initRes.json().catch(() => ({}));
          throw new Error(d.message ?? 'Failed to initiate image upload.');
        }
        const { upload_slots: slots } = await initRes.json();

        this.submitProgress = 'Uploading images…';
        await Promise.all(
          imageEntries.map(({ key, file }) =>
            fetch(slots[key].upload_url, { method: 'PUT', headers: slots[key].headers, body: file })
          )
        );
        for (const { key } of imageEntries) objectTokens[key] = slots[key].object_token;
      }

      // Step 2 — build payload
      this.submitProgress = 'Creating facility…';
      const social  = this.socialLinks.filter(Boolean);
      const byPlat  = (domains) => social.filter((l) => domains.some((d) => l.includes(d)));
      const mgr     = (i) => this.selectedManagers[i];
      const mgrName = (i) => { const m = mgr(i); if (!m) return ''; const f = m.user_fullname; return f ? `${f.first_name ?? ''} ${f.last_name ?? ''}`.trim() : m.user_email ?? ''; };

      const payload = {
        fac_name:           this.facilityName.trim(),
        email_token:        this.emailVerifiedToken ?? '',
        phone_token:        this.phoneVerifiedToken ?? '',
        fac_email:          this.facilityEmail.trim(),
        fac_cell_phone:     this.normalizedPhone,
        fac_manager_1:      mgr(0)?.userid ?? '',
        fac_manager_2:      mgr(1)?.userid ?? '',
        fac_manager_3:      mgr(2)?.userid ?? '',
        fac_manager_1_name: mgrName(0),
        fac_manager_2_name: mgrName(1),
        fac_manager_3_name: mgrName(2),
        fac_country:        this.facilityCountry.trim(),
        fac_division:       this.facilityDivision.trim(),
        fac_district:       this.facilityDistrict.trim(),
        fac_city:           this.facilityCity.trim(),
        fac_address:        this.facilityAddress.trim(),
        fac_post_code:      this.facilityPostCode.trim(),
        google_map_link:    this.googleMapLink.trim(),
        fac_lat:            this.facilityLat,
        fac_long:           this.facilityLong,
        fac_banners:        objectTokens['fac_banner'] ? [objectTokens['fac_banner']] : [],
        fac_logo:           objectTokens['fac_logo'] ?? '',
        fac_pictures:       this.pictureFiles.map((_, i) => objectTokens[`fac_pic_${i + 1}`] ?? ''),
        fac_url:            this.facilityUrlName.trim(),
        fac_url_name:       this.facilityUrlName.trim(),
        fac_sports:         this.selectedSports.map((s) => s.toLowerCase()),
        fac_status:         true,
        fac_del_by:         '',
        fac_established_date: this.establishedDate,
        fac_description:    document.getElementById('fac-rich-editor')?.innerHTML ?? '',
        fac_about_us:       '',
        fac_video_link:     this.videoLinks.filter(Boolean),
        fac_website:        this.facilityWebsite.trim(),
        fac_facebook:       byPlat(['facebook.com']),
        fac_instagram:      byPlat(['instagram.com']),
        fac_twitter:        byPlat(['twitter.com', 'x.com']),
        fac_youtube:        byPlat(['youtube.com', 'youtu.be']),
      };

      const res = await fetch(`${API_BASE}/facility/insert_facilities/`, {
        method: 'POST',
        headers: { ...this.authHeaders, 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });

      if (res.ok) {
        this.toast.success('Facility created successfully!');
        this.isSuccess = true;
        setTimeout(() => this.router.transitionTo('facilities'), 10000);
      } else {
        const data = await res.json().catch(() => ({}));
        this.toast.error(data.message ?? 'Failed to create facility. Please try again.');
      }
    } catch (err) {
      this.toast.error(err.message ?? 'Network error. Please check your connection and try again.');
    } finally {
      this.isSubmitting = false; this.submitProgress = null;
    }
  }

  <template>
    {{#if this.isSuccess}}
      <div class="min-h-screen bg-gray-950 flex items-center justify-center px-4">
        <div class="text-center max-w-md">
          <div class="w-24 h-24 mx-auto mb-6 rounded-full
                      bg-gradient-to-br from-emerald-400 to-teal-500
                      flex items-center justify-center shadow-2xl shadow-emerald-500/30">
            {{lucideIcon "check-circle" size=48 class="text-white"}}
          </div>
          <h2 class="text-3xl font-bold text-white mb-3">Facility Created!</h2>
          <p class="text-gray-400 mb-2">Your facility has been successfully submitted for review.</p>
          <p class="text-sm text-gray-500">Redirecting to facilities page in 10 seconds…</p>
        </div>
      </div>

    {{else}}
    <div class="min-h-screen bg-gray-950 pb-24">

      {{! ── Page header ── }}
      <div class="bg-gradient-to-r from-gray-900 via-gray-900 to-gray-950
                  border-b border-gray-800 sticky top-0 z-30 backdrop-blur-sm">
        <div class="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between">
          <div class="flex items-center gap-3">
            <div class="w-9 h-9 rounded-xl bg-gradient-to-br from-indigo-500 to-violet-600
                        flex items-center justify-center shadow-lg shadow-indigo-500/20">
              {{lucideIcon "home" size=20 class="text-white"}}
            </div>
            <div>
              <h1 class="text-lg font-bold text-white leading-tight">Create Facility</h1>
              <p class="text-xs text-gray-500">Fill in the details below to register your facility</p>
            </div>
          </div>
          <button type="button" {{on "click" this.goBack}}
                  class="inline-flex items-center gap-2 px-3 py-2 rounded-lg
                         text-gray-400 hover:text-white hover:bg-gray-800
                         text-sm font-medium transition-all duration-150">
            {{lucideIcon "arrow-left" size=16}}
            Back
          </button>
        </div>
      </div>

      <form {{on "submit" this.submit}} novalidate>

        {{! Hidden file inputs }}
        <input id="fac-banner-input"   type="file" accept="image/*" class="hidden" {{on "change" this.onBannerChange}} />
        <input id="fac-logo-input"     type="file" accept="image/*" class="hidden" {{on "change" this.onLogoChange}} />
        <input id="fac-pictures-input" type="file" accept="image/*" multiple class="hidden" {{on "change" this.onPicturesChange}} />

        {{! ── Banner upload ── }}
        <div class="max-w-7xl mx-auto px-6 pt-6">
          <FacBannerUploader
            @preview={{this.bannerPreview}}
            @fileName={{this.bannerFile.name}}
            @error={{this.bannerError}}
            @label="Upload Facilities Banner"
            @hint="1920 × 720 pixels · Maximum Size {{this.BANNER_MAX_KB}} KB"
            @onTrigger={{this.triggerBannerUpload}}
            @onRemove={{this.removeBanner}}
          />
        </div>

        {{! ── Two-column grid ── }}
        <div class="max-w-7xl mx-auto px-6 mt-6 grid grid-cols-1 lg:grid-cols-2 gap-6">

          {{! ══ LEFT COLUMN ══ }}
          <div class="space-y-5">

            {{! Basic Info }}
            <div class="rounded-2xl border border-gray-800 bg-gray-900/60 backdrop-blur-sm p-6 space-y-5">
              <div class="flex items-center gap-2.5 pb-3 border-b border-gray-800">
                <div class="w-7 h-7 rounded-lg bg-indigo-500/10 flex items-center justify-center">
                  {{lucideIcon "home" size=16 class="text-indigo-400"}}
                </div>
                <h3 class="text-sm font-bold text-gray-200 tracking-wide uppercase">Basic Information</h3>
              </div>

              <div>
                <label class="block text-sm font-semibold text-gray-300 mb-1.5">
                  Facilities Name <span class="text-rose-500">*</span>
                </label>
                <input type="text" placeholder="Enter Facilities Name"
                       value={{this.facilityName}}
                       {{on "input" (fn this.updateField "facilityName")}}
                       class="w-full px-4 py-3 rounded-xl border transition-all duration-200
                              bg-gray-800 text-gray-100 placeholder:text-gray-500
                              focus:outline-none focus:ring-2 focus:ring-indigo-500/30
                              {{if this.errors.facilityName 'border-rose-500 bg-rose-900/10' 'border-gray-700 focus:border-indigo-500'}}" />
                <FormFieldError @error={{this.errors.facilityName}} />
              </div>

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
            </div>

            {{! Contact }}
            <div class="rounded-2xl border border-gray-800 bg-gray-900/60 backdrop-blur-sm p-6 space-y-5">
              <div class="flex items-center gap-2.5 pb-3 border-b border-gray-800">
                <div class="w-7 h-7 rounded-lg bg-violet-500/10 flex items-center justify-center">
                  {{lucideIcon "phone" size=16 class="text-violet-400"}}
                </div>
                <h3 class="text-sm font-bold text-gray-200 tracking-wide uppercase">Contact Details</h3>
              </div>

              <EmailOtpVerifier
                @label="Facilities eMail"
                @email={{this.facilityEmail}}
                @verified={{this.emailVerified}}
                @otpSent={{this.emailOtpSent}}
                @otpValue={{this.otpValue}}
                @otpError={{this.otpError}}
                @error={{this.errors.facilityEmail}}
                @isSending={{this.isSendingOtp}}
                @isVerifying={{this.isVerifyingOtp}}
                @required={{true}}
                @onEmailInput={{this.onEmailInput}}
                @onSendOtp={{this.sendEmailOtp}}
                @onVerifyOtp={{this.verifyEmailOtp}}
                @onOtpInput={{this.onOtpInput}}
              />

              {{! Phone }}
              <PhoneOtpVerifier
                @label="Facilities Cell Phone"
                @phone={{this.facilityPhone}}
                @verified={{this.phoneVerified}}
                @otpSent={{this.phoneOtpSent}}
                @otpValue={{this.phoneOtpValue}}
                @otpHint={{this.phoneOtpHint}}
                @otpError={{this.phoneOtpError}}
                @error={{this.errors.facilityPhone}}
                @isSending={{this.isSendingPhoneOtp}}
                @isVerifying={{this.isVerifyingPhoneOtp}}
                @required={{true}}
                @onPhoneInput={{this.onPhoneInput}}
                @onSendOtp={{this.sendPhoneOtp}}
                @onVerifyOtp={{this.verifyPhoneOtp}}
                @onOtpInput={{this.onPhoneOtpInput}}
              />
            </div>

            {{! Location }}
            <div class="rounded-2xl border border-gray-800 bg-gray-900/60 backdrop-blur-sm p-6 space-y-5">
              <div class="flex items-center gap-2.5 pb-3 border-b border-gray-800">
                <div class="w-7 h-7 rounded-lg bg-emerald-500/10 flex items-center justify-center">
                  {{lucideIcon "map-pin" size=16 class="text-emerald-400"}}
                </div>
                <h3 class="text-sm font-bold text-gray-200 tracking-wide uppercase">Location</h3>
              </div>

              <div>
                <label class="block text-sm font-semibold text-gray-300 mb-1.5">
                  Facilities Address <span class="text-rose-500">*</span>
                </label>
                <div class="flex gap-2 items-center">
                  <div class="relative flex-1">
                    <input type="text" placeholder="Address"
                           value={{this.facilityAddress}}
                           {{on "input" (fn this.updateField "facilityAddress")}}
                           class="w-full px-4 py-3 pr-10 rounded-xl border transition-all duration-200
                                  bg-gray-800 text-gray-100 placeholder:text-gray-500
                                  focus:outline-none focus:ring-2 focus:ring-indigo-500/30
                                  {{if this.errors.facilityAddress 'border-rose-500' 'border-gray-700 focus:border-indigo-500'}}" />
                    {{#if this.facilityAddress}}
                      <button type="button" {{on "click" this.clearAddress}}
                              class="absolute inset-y-0 right-3 flex items-center
                                     text-gray-500 hover:text-gray-300 transition-colors">
                        {{lucideIcon "x" size=16}}
                      </button>
                    {{/if}}
                  </div>
                  <span class="text-gray-500 text-sm font-medium shrink-0">OR</span>
                  <button type="button" {{on "click" this.useGeolocation}}
                          class="shrink-0 w-11 h-11 rounded-xl border border-gray-700
                                 bg-gray-800 hover:bg-gray-700 hover:border-emerald-500/50
                                 flex items-center justify-center text-emerald-400
                                 transition-all duration-200">
                    {{#if this.isGeoFilling}}
                      {{lucideIcon "loader" size=20 class="animate-spin"}}
                    {{else}}
                      {{lucideIcon "map-pin" size=20}}
                    {{/if}}
                  </button>
                </div>
                <FormFieldError @error={{this.errors.facilityAddress}} />
              </div>

              <GeoTextInput @label="Facilities Country" @placeholder="Facilities Country"
                            @value={{this.facilityCountry}} @isGeoFilling={{this.isGeoFilling}}
                            @error={{this.errors.facilityCountry}} @required={{true}}
                            @onInput={{fn this.updateField "facilityCountry"}} />

              <GeoTextInput @label="Facilities Division" @placeholder="Facilities Division"
                            @value={{this.facilityDivision}} @isGeoFilling={{this.isGeoFilling}}
                            @error={{this.errors.facilityDivision}} @required={{true}}
                            @onInput={{fn this.updateField "facilityDivision"}} />

              <GeoTextInput @label="Facilities District" @placeholder="Facilities District"
                            @value={{this.facilityDistrict}} @isGeoFilling={{this.isGeoFilling}}
                            @error={{this.errors.facilityDistrict}} @required={{true}}
                            @onInput={{fn this.updateField "facilityDistrict"}} />

              <GeoTextInput @label="Facilities City" @placeholder="Facilities City"
                            @value={{this.facilityCity}} @isGeoFilling={{this.isGeoFilling}}
                            @error={{this.errors.facilityCity}} @required={{true}}
                            @onInput={{fn this.updateField "facilityCity"}} />

              <div>
                <label class="block text-sm font-semibold text-gray-300 mb-1.5">
                  Facilities Post Code <span class="text-rose-500">*</span>
                </label>
                <input type="text" placeholder="Enter Post Code"
                       value={{this.facilityPostCode}}
                       {{on "input" (fn this.updateField "facilityPostCode")}}
                       class="w-full px-4 py-3 rounded-xl border transition-all duration-200
                              bg-gray-800 text-gray-100 placeholder:text-gray-500
                              focus:outline-none focus:ring-2 focus:ring-indigo-500/30
                              {{if this.errors.facilityPostCode 'border-rose-500' 'border-gray-700 focus:border-indigo-500'}}" />
                <FormFieldError @error={{this.errors.facilityPostCode}} />
              </div>

              <div>
                <label class="block text-sm font-semibold text-gray-300 mb-1.5">
                  Google Map Link
                </label>
                <input type="url" placeholder="Enter Google Map Link"
                       value={{this.googleMapLink}}
                       {{on "input" (fn this.updateField "googleMapLink")}}
                       class="w-full px-4 py-3 rounded-xl border transition-all duration-200
                              bg-gray-800 text-gray-100 placeholder:text-gray-500
                              focus:outline-none focus:ring-2 focus:ring-indigo-500/30
                              border-gray-700 focus:border-indigo-500" />
              </div>

              <div>
                <label class="block text-sm font-semibold text-gray-300 mb-1.5">
                  Facilities Established Date <span class="text-rose-500">*</span>
                </label>
                <input type="date" value={{this.establishedDate}}
                       {{on "input" (fn this.updateField "establishedDate")}}
                       class="w-full px-4 py-3 rounded-xl border transition-all duration-200
                              bg-gray-800 text-gray-100
                              focus:outline-none focus:ring-2 focus:ring-indigo-500/30
                              {{if this.errors.establishedDate 'border-rose-500' 'border-gray-700 focus:border-indigo-500'}}
                              [color-scheme:dark]" />
                <FormFieldError @error={{this.errors.establishedDate}} />
              </div>
            </div>

          </div>{{! ── END LEFT COLUMN ── }}

          {{! ══ RIGHT COLUMN ══ }}
          <div class="space-y-5">

            {{! Media & Branding }}
            <div class="rounded-2xl border border-gray-800 bg-gray-900/60 backdrop-blur-sm p-6 space-y-6">
              <div class="flex items-center gap-2.5 pb-3 border-b border-gray-800">
                <div class="w-7 h-7 rounded-lg bg-rose-500/10 flex items-center justify-center">
                  {{lucideIcon "image" size=16 class="text-rose-400"}}
                </div>
                <h3 class="text-sm font-bold text-gray-200 tracking-wide uppercase">Media & Branding</h3>
              </div>

              <RichTextEditor
                @editorId="fac-rich-editor"
                @placeholder="Enter Facility's Description / BIO…"
                @fontFamilies={{this.fontFamilies}}
                @fontSizes={{this.fontSizes}}
                @error={{this.errors.description}}
                @required={{true}}
                @onInput={{this.onDescriptionInput}}
                @onFmt={{this.fmt}}
                @onFmtVal={{this.fmtVal}}
                @onSetTextColor={{this.setTextColor}}
              />

              <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                {{! Logo }}
                <div>
                  <label class="block text-sm font-semibold text-gray-300 mb-1.5">Facility's Logo</label>
                  <ImageUploader
                    @label="Upload Facility's Logo"
                    @hint="550 × 550 px · max {{this.LOGO_MAX_KB}} KB"
                    @preview={{this.logoPreview}}
                    @uploadError={{this.logoError}}
                    @inputId="fac-logo-input"
                    @variant="logo"
                    @onTrigger={{this.triggerLogoUpload}}
                    @onRemove={{this.removeLogo}}
                  />
                  <p class="mt-1 text-xs text-gray-500">550 × 550 pixels · Max {{this.LOGO_MAX_KB}} KB</p>
                </div>

                {{! Gallery Pictures }}
                <div>
                  <label class="block text-sm font-semibold text-gray-300 mb-1.5">
                    Facility Pictures
                    <span class="ml-1 text-xs font-normal text-gray-500">
                      ({{this.pictureFiles.length}}/{{this.MAX_PICTURES}})
                    </span>
                  </label>
                  <FacPictureGallery
                    @previews={{this.picturePreviews}}
                    @count={{this.pictureFiles.length}}
                    @maxCount={{this.MAX_PICTURES}}
                    @error={{this.pictureError}}
                    @onTrigger={{this.triggerPicturesUpload}}
                    @onRemove={{this.removePicture}}
                  />
                </div>
              </div>
            </div>

            {{! Links & Online Presence }}
            <div class="rounded-2xl border border-gray-800 bg-gray-900/60 backdrop-blur-sm p-6 space-y-5">
              <div class="flex items-center gap-2.5 pb-3 border-b border-gray-800">
                <div class="w-7 h-7 rounded-lg bg-sky-500/10 flex items-center justify-center">
                  {{lucideIcon "globe" size=16 class="text-sky-400"}}
                </div>
                <h3 class="text-sm font-bold text-gray-200 tracking-wide uppercase">Links & Online Presence</h3>
              </div>

              <LinkListField
                @label="Facility's Video Links"
                @links={{this.videoLinks}}
                @placeholder="Enter Video Link"
                @onAdd={{this.addVideoLink}}
                @onRemove={{this.removeVideoLink}}
                @onUpdate={{this.updateVideoLink}}
              />

              <div>
                <label class="block text-sm font-semibold text-gray-300 mb-1.5">Facility's Website</label>
                <input type="url" placeholder="Enter Facility's Website"
                       value={{this.facilityWebsite}}
                       {{on "input" (fn this.updateField "facilityWebsite")}}
                       class="w-full px-4 py-3 rounded-xl border transition-all duration-200
                              bg-gray-800 text-gray-100 placeholder:text-gray-500
                              focus:outline-none focus:ring-2 focus:ring-indigo-500/30
                              border-gray-700 focus:border-indigo-500" />
              </div>

              <div>
                <LinkListField
                  @label="Facility's Social Links"
                  @links={{this.socialLinks}}
                  @placeholder="Enter Social Media Link"
                  @onAdd={{this.addSocialLink}}
                  @onRemove={{this.removeSocialLink}}
                  @onUpdate={{this.updateSocialLink}}
                />
                <p class="mt-1 text-xs text-gray-500">
                  Only allow facebook, twitter, instagram, linkedin, youtube, tiktok, reddit, pinterest, snapchat, discord
                </p>
              </div>
            </div>

            {{! URL & Sports }}
            <div class="rounded-2xl border border-gray-800 bg-gray-900/60 backdrop-blur-sm p-6 space-y-5">
              <div class="flex items-center gap-2.5 pb-3 border-b border-gray-800">
                <div class="w-7 h-7 rounded-lg bg-amber-500/10 flex items-center justify-center">
                  {{lucideIcon "link" size=16 class="text-amber-400"}}
                </div>
                <h3 class="text-sm font-bold text-gray-200 tracking-wide uppercase">URL & Sports</h3>
              </div>

              {{! URL Name }}
              <FacUrlChecker
                @value={{this.facilityUrlName}}
                @available={{this.urlAvailable}}
                @isChecking={{this.urlChecking}}
                @checkError={{this.urlCheckError}}
                @error={{this.errors.facilityUrlName}}
                @onInput={{this.onUrlNameInput}}
                @onCheck={{this.checkUrlName}}
              />

              {{! Sports }}
              <SportsMultiSelect
                @sportsScope="Multi Sports"
                @selectedSports={{this.selectedSports}}
                @sportsWithSelection={{this.sportsWithSelection}}
                @isOpen={{this.sportsDropdownOpen}}
                @error={{this.errors.sports}}
                @required={{true}}
                @onToggle={{this.toggleSportsDropdown}}
                @onClose={{this.closeSportsDropdown}}
                @onToggleSport={{this.toggleSport}}
              />

              {{! URL info box }}
              <div class="rounded-xl border border-gray-700/50 bg-gray-800/40 px-4 py-3">
                <p class="text-xs text-gray-400 leading-relaxed">
                  This URL Name will appear in the Spordium Platform. If you enter the name of the URL as
                  "My Home Facilities" or "MyHomeFacilities", under the spordium.com domain it will
                  appear as "<span class="text-indigo-400 font-medium">spordium.com/MyHomeFacilities</span>".
                </p>
              </div>
            </div>

          </div>{{! ── END RIGHT COLUMN ── }}

        </div>{{! ── END GRID ── }}

        {{! ── Submit bar ── }}
        <div class="fixed bottom-0 inset-x-0 z-30
                    bg-gray-950/90 backdrop-blur-md border-t border-gray-800
                    flex items-center justify-end px-6 py-4 gap-4">
          <p class="text-xs text-gray-500 flex-1 hidden sm:block">
            All fields marked <span class="text-rose-500">*</span> are required
          </p>
          <button type="button" {{on "click" this.cancel}}
                  class="px-5 py-3 rounded-xl border border-gray-700
                         text-gray-400 hover:text-white hover:border-gray-600
                         text-sm font-semibold transition-all duration-200">
            Cancel
          </button>
          <button type="submit" disabled={{this.isSubmitting}}
                  class="inline-flex items-center gap-2.5 px-8 py-3 rounded-xl
                         bg-gradient-to-r from-indigo-600 to-violet-600
                         hover:from-indigo-500 hover:to-violet-500
                         text-white text-sm font-bold
                         shadow-xl shadow-indigo-500/25
                         disabled:opacity-60 disabled:cursor-not-allowed
                         transition-all duration-200
                         focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2
                         focus:ring-offset-gray-950">
            {{#if this.isSubmitting}}
              {{lucideIcon "loader" size=16 class="animate-spin"}}
              {{if this.submitProgress this.submitProgress "Creating…"}}
            {{else}}
              {{lucideIcon "home" size=16}}
              Create Facilities
            {{/if}}
          </button>
        </div>

      </form>
    </div>
    {{/if}}
  </template>
}
