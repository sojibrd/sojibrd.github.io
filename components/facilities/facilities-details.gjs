import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { fn, get } from '@ember/helper';
import { eq } from 'ember-truth-helpers';
import { service } from '@ember/service';
import tuiCalendarModifier from 'spordium/modifiers/tui-calendar';
import PaymentMethodPicker from 'spordium/components/ui/payment-method-picker';
import lucideIcon from 'spordium/helpers/lucide-icon';
import safeHtml from 'spordium/helpers/safe-html';
import FacilityEditModal from './facility-edit-modal';

const API_BASE = 'https://spordiumapi.adnanfoundation.com';

const IMAGE_BASE = 'https://ag-khela.s3.ap-south-1.amazonaws.com/';

const TABS = [
  { id: 'about',      label: 'About Us' },
  { id: 'facilities', label: 'Booking' },
  { id: 'schedule',   label: 'Schedule' },
  { id: 'live',       label: 'Live Match' },
  { id: 'posts',      label: 'Posts' },
  { id: 'gallery',    label: 'Gallery' },
];

const SKELETON_ROWS = [1, 2, 3];

// ══════════════════════════════════════════════════════════════════════════════
export default class FacilitiesDetails extends Component {
  @service router;
  @service session;
  @service toast;

  @tracked facility          = null;
  @tracked isLoading         = true;
  @tracked error             = null;
  @tracked activeTab         = 'about';
  @tracked isFollowing       = false;
  @tracked tabBarAtStart     = true;
  @tracked tabBarAtEnd       = false;

  // ── Facilities-tab data ────────────────────────────────────────────────────
  @tracked facItems          = [];
  @tracked facItemsLoading   = false;
  @tracked facItemsError     = null;
  _facItemsFetched           = false;

  // ── Schedule-tab data ─────────────────────────────────────────────────────
  @tracked scheduleBookings  = [];
  @tracked scheduleLoading   = false;
  @tracked scheduleError     = null;
  _scheduleFetched           = false;

  // ── Edit modal ────────────────────────────────────────────────────────────
  @tracked canEdit           = false;
  @tracked showEditModal     = false;

  // ── Booking modal ──────────────────────────────────────────────────────────
  @tracked showBookingModal       = false;
  @tracked bookingCalInstance     = null;
  @tracked bookingNavDate         = new Date();
  @tracked selectedBookingDate    = null;
  @tracked showTimeSlotPopup      = false;
  @tracked bookingFromTime        = '';
  @tracked bookingToTime          = '';
  @tracked selectedRentIdx        = 0;
  @tracked clockMode              = 'hour';    // 'hour' | 'minute'
  @tracked activeTimeEdit         = 'from';   // 'from' | 'to'

  // ── Booking steps: 1 = time selection, 2 = payment ─────────────────────────
  @tracked bookingStep            = 1;
  @tracked selectedPaymentMethod  = null;
  @tracked bookingUserNote        = '';
  @tracked isBookingSubmitting    = false;

  constructor(owner, args) {
    super(owner, args);
    this.fetchDetails();
  }

  async fetchDetails() {
    this.isLoading = true;
    this.error     = null;
    try {
      const url     = `https://spordiumapi.adnanfoundation.com/facility/get_one_facility/?fac_url_name=${encodeURIComponent(this.args.facUrlName)}`;
      const token   = this.session.data?.authenticated?.token;
      const headers = token ? { Authorization: `Bearer ${token}` } : {};
      const res     = await fetch(url, { headers });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json = await res.json();
      this.facility = json.data;
      this.canEdit = json.message?.can_edit === true;
    } catch {
      this.error = 'Failed to load facility details. Please try again.';
    } finally {
      this.isLoading = false;
    }
  }

  // ── Getters ────────────────────────────────────────────────────────────────
  get tabs()         { return TABS; }
  get skeletonRows() { return SKELETON_ROWS; }

  get established() {
    if (!this.facility?.fac_established_date) return null;
    return new Date(this.facility.fac_established_date).getFullYear();
  }

  get hasSports() { return (this.facility?.fac_sports?.length ?? 0) > 0; }

  get bannerUrl() {
    const path = this.facility?.fac_banners?.[0];
    return path ? `${IMAGE_BASE}${path}` : null;
  }

  get logoUrl() {
    const path = this.facility?.fac_logo;
    return path ? `${IMAGE_BASE}${path}` : null;
  }

  get allGalleryImages() {
    const banners  = (this.facility?.fac_banners  ?? []).map((p) => `${IMAGE_BASE}${p}`);
    const pictures = (this.facility?.fac_pictures ?? []).map((p) => `${IMAGE_BASE}${p}`);
    return [...banners, ...pictures].filter(Boolean);
  }

  get hasPictures() { return this.allGalleryImages.length > 0; }

  get description() {
    const d = this.facility?.fac_description;
    return d?.trim() || null;
  }

  get aboutUs() {
    const a = this.facility?.fac_about_us;
    return a?.trim() || null;
  }

  get managers() {
    const f = this.facility;
    if (!f) return [];
    const list = [];
    if (f.fac_manager_1_name?.trim()) list.push({ name: f.fac_manager_1_name.trim(), id: f.fac_manager_1 });
    if (f.fac_manager_2_name?.trim()) list.push({ name: f.fac_manager_2_name.trim(), id: f.fac_manager_2 });
    if (f.fac_manager_3_name?.trim()) list.push({ name: f.fac_manager_3_name.trim(), id: f.fac_manager_3 });
    return list;
  }

  get hasManagers() { return this.managers.length > 0; }

  get hasSocialLinks() {
    const f = this.facility;
    if (!f) return false;
    return [
      f.fac_facebook?.[0],
      f.fac_twitter?.[0],
      f.fac_instagram?.[0],
      f.fac_youtube?.[0],
      f.fac_website,
    ].some((v) => v?.trim());
  }

  get hasUpcoming() {
    return this.facility?.upcoming_games_info || this.facility?.upcoming_tournament_info;
  }

  get formatRating() {
    const v = this.facility?.platform_ratings;
    return typeof v === 'number' ? v.toFixed(1) : '0.0';
  }

  // ── Booking getters ────────────────────────────────────────────────────────
  get bookingMonthLabel() {
    return new Intl.DateTimeFormat('en-US', { month: 'long', year: 'numeric' }).format(this.bookingNavDate);
  }

  get selectedDateDisplay() {
    if (!this.selectedBookingDate) return '';
    return new Intl.DateTimeFormat('en-US', { month: 'long', day: 'numeric' }).format(this.selectedBookingDate);
  }

  get allRentOptions() {
    const seen = new Set();
    const opts = [];
    for (const item of this.facItems) {
      for (const opt of item.rent_options ?? []) {
        const key = `${opt.time_slot}-${opt.price}`;
        if (!seen.has(key)) {
          seen.add(key);
          // Carry fac_fac_id from the parent facItem so submitBooking can read it directly
          opts.push({ ...opt, fac_fac_id: item.fac_fac_id });
        }
      }
    }
    return opts.length ? opts : [{ time_slot: '1', price: '0', fac_fac_id: '' }];
  }

  get selectedRentOpt() {
    return this.allRentOptions[this.selectedRentIdx] ?? this.allRentOptions[0];
  }

  // Computes the suggested To time from From + rent slot duration
  #suggestedToTime(fromTime) {
    if (!fromTime || !this.selectedRentOpt) return '';
    const [h, m] = fromTime.split(':').map(Number);
    const totalMins = h * 60 + m + parseFloat(this.selectedRentOpt.time_slot) * 60;
    const th = Math.floor(totalMins / 60) % 24;
    const tm = Math.round(totalMins % 60);
    return `${String(th).padStart(2, '0')}:${String(tm).padStart(2, '0')}`;
  }

  // Minimum selectable To time: 1 minute after From
  get minToTime() {
    if (!this.bookingFromTime) return '';
    const [h, m] = this.bookingFromTime.split(':').map(Number);
    const totalMins = h * 60 + m + 1;
    const th = Math.floor(totalMins / 60) % 24;
    const tm = totalMins % 60;
    return `${String(th).padStart(2, '0')}:${String(tm).padStart(2, '0')}`;
  }

  // True when both times are set and To > From
  get bookingTimeValid() {
    return !!(this.bookingFromTime && this.bookingToTime && this.bookingToTime > this.bookingFromTime);
  }

  // Duration in decimal hours (e.g. 1.5 for 1h30m)
  get bookingDurationHours() {
    if (!this.bookingTimeValid) return 0;
    const toMins = (t) => { const [h, m] = t.split(':').map(Number); return h * 60 + m; };
    return (toMins(this.bookingToTime) - toMins(this.bookingFromTime)) / 60;
  }

  // Amount = duration * 1500 (rounded to nearest whole taka)
  get bookingAmount() {
    return Math.round(this.bookingDurationHours * 1500);
  }

  // ── Analog clock picker helpers ────────────────────────────────────────────
  // The time string currently being edited on the clock
  get activeTime() {
    return this.activeTimeEdit === 'from' ? this.bookingFromTime : this.bookingToTime;
  }

  get activeHour12() {
    const t = this.activeTime;
    if (!t) return null;
    const h = parseInt(t.split(':')[0], 10);
    return h % 12 || 12;
  }

  get activeMinute() {
    const t = this.activeTime;
    if (!t) return null;
    return parseInt(t.split(':')[1], 10);
  }

  get activePeriod() {
    const t = this.activeTime;
    if (!t) return 'AM';
    return parseInt(t.split(':')[0], 10) >= 12 ? 'PM' : 'AM';
  }

  get activeDisplayHour() {
    const t = this.activeTime;
    if (!t) return '--';
    const h = parseInt(t.split(':')[0], 10);
    return String(h % 12 || 12);
  }

  get activeDisplayMinute() {
    const t = this.activeTime;
    if (!t) return '--';
    return t.split(':')[1];
  }

  // Active clock accent colour (indigo for start, violet for end)
  get clockAccent() {
    return this.activeTimeEdit === 'from' ? '#6366f1' : '#8b5cf6';
  }

  get formattedFromTime() {
    if (!this.bookingFromTime) return '--:--';
    const [h, m] = this.bookingFromTime.split(':').map(Number);
    const ampm = h >= 12 ? 'PM' : 'AM';
    const h12  = h % 12 || 12;
    return `${String(h12).padStart(2, '0')}:${String(m).padStart(2, '0')} ${ampm}`;
  }

  get formattedToTime() {
    if (!this.bookingToTime) return '--:--';
    const [h, m] = this.bookingToTime.split(':').map(Number);
    const ampm = h >= 12 ? 'PM' : 'AM';
    const h12  = h % 12 || 12;
    return `${String(h12).padStart(2, '0')}:${String(m).padStart(2, '0')} ${ampm}`;
  }

  // SVG clock face: positions for each hour (1-12) on the dial
  get clockHourData() {
    const cx = 110, cy = 110, r = 78;
    return [12, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11].map((h, i) => {
      const angle = (i * 30 - 90) * Math.PI / 180;
      return { val: h, x: cx + r * Math.cos(angle), y: cy + r * Math.sin(angle) };
    });
  }

  // SVG clock face: positions for each 5-min mark (0,5,10,...,55)
  get clockMinuteData() {
    const cx = 110, cy = 110, r = 78;
    return Array.from({ length: 12 }, (_, i) => {
      const val = i * 5;
      const angle = (i * 30 - 90) * Math.PI / 180;
      return { val, label: String(val).padStart(2, '0'), x: cx + r * Math.cos(angle), y: cy + r * Math.sin(angle) };
    });
  }

  // Endpoint of the clock hand — tracks activeTime + clockMode
  get clockHandX() {
    const cx = 110, r = 78;
    if (this.clockMode === 'hour') {
      const h12 = this.activeHour12;
      if (h12 === null) return cx;
      const i = h12 === 12 ? 0 : h12;
      return cx + r * Math.cos((i * 30 - 90) * Math.PI / 180);
    }
    const m = this.activeMinute ?? 0;
    return cx + r * Math.cos(((m / 5) * 30 - 90) * Math.PI / 180);
  }

  get clockHandY() {
    const cy = 110, r = 78;
    if (this.clockMode === 'hour') {
      const h12 = this.activeHour12;
      if (h12 === null) return cy;
      const i = h12 === 12 ? 0 : h12;
      return cy + r * Math.sin((i * 30 - 90) * Math.PI / 180);
    }
    const m = this.activeMinute ?? 0;
    return cy + r * Math.sin(((m / 5) * 30 - 90) * Math.PI / 180);
  }

  get emptyArray() { return []; }

  get bookingCalTheme() {
    return {
      common: {
        gridSelection: {
          backgroundColor: 'rgba(99, 102, 241, 0.12)',
          border: '2px solid #6366f1',
        },
        today: { color: '#ffffff' },
      },
    };
  }

  managerInitials(name) {
    return name
      .split(' ')
      .map((w) => w[0])
      .join('')
      .slice(0, 2)
      .toUpperCase();
  }

  managerGradient(idx) {
    const GRADS = [
      'from-indigo-500 to-violet-600',
      'from-rose-500 to-pink-600',
      'from-amber-500 to-orange-500',
      'from-teal-500 to-cyan-500',
      'from-fuchsia-500 to-purple-600',
    ];
    return GRADS[idx % GRADS.length];
  }

  async fetchFacItems() {
    if (this.facItemsLoading) return;
    this.facItemsLoading = true;
    this.facItemsError   = null;
    try {
      const facId = this.facility?.fac_id;
      const url   = `https://spordiumapi.adnanfoundation.com/facility/get_facilities_facilities/?fac_id=${encodeURIComponent(facId)}`;
      const res   = await fetch(url);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json  = await res.json();
      this.facItems = json.data ?? [];
    } catch {
      this.facItemsError = 'Failed to load facilities. Please try again.';
    } finally {
      this.facItemsLoading = false;
      this._facItemsFetched = true;
    }
  }

  async fetchSchedule() {
    if (this._scheduleFetched) return;
    this.scheduleLoading = true;
    this.scheduleError   = null;
    try {
      const facId = this.facility?.fac_id;
      const url   = `https://spordiumapi.adnanfoundation.com/facility/get_facility_bookings_list/?fac_id=${encodeURIComponent(facId)}&page=1`;
      const res   = await fetch(url);
      const json  = await res.json();
      if (json.success === false) {
        this.scheduleError   = json.message ?? 'No upcoming bookings found';
        this.scheduleBookings = [];
      } else {
        this.scheduleBookings = Array.isArray(json.results ?? json.data ?? json) ? (json.results ?? json.data ?? json) : [];
      }
    } catch {
      this.scheduleError = 'Failed to load schedule. Please try again.';
    } finally {
      this.scheduleLoading  = false;
      this._scheduleFetched = true;
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  @action openEditModal()  { this.showEditModal = true; }
  @action closeEditModal() { this.showEditModal = false; }
  @action onEditSaved()    { this.showEditModal = false; this.fetchDetails(); }

  @action retry()          { this.fetchDetails(); }
  @action retryFacItems()  { this._facItemsFetched = false; this.fetchFacItems(); }
  @action retrySchedule()  { this._scheduleFetched = false; this.fetchSchedule(); }

  @action setTab(tab, event) {
    this.activeTab = tab;
    if (tab === 'facilities' && !this._facItemsFetched) {
      this.fetchFacItems();
    }
    if (tab === 'schedule' && !this._scheduleFetched) {
      this.fetchSchedule();
    }
    event?.currentTarget?.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'nearest' });
  }

  @action onTabBarScroll(event) {
    const el = event.target;
    this.tabBarAtStart = el.scrollLeft <= 2;
    this.tabBarAtEnd   = el.scrollLeft + el.clientWidth >= el.scrollWidth - 2;
  }

  @action scrollTabsLeft() {
    document.getElementById('fac-tab-bar')?.scrollBy({ left: -200, behavior: 'smooth' });
  }

  @action scrollTabsRight() {
    document.getElementById('fac-tab-bar')?.scrollBy({ left: 200, behavior: 'smooth' });
  }
  @action goBack()       { this.router.transitionTo('facilities'); }
  @action toggleFollow() { this.isFollowing = !this.isFollowing; }

  // ── Booking modal actions ──────────────────────────────────────────────────
  #updateBookingLabel() {
    const raw = this.bookingCalInstance?.getDate?.();
    const d   = raw?.toDate?.() ?? raw ?? new Date();
    this.bookingNavDate = d;
  }

  @action openBookingModal() {
    this.showBookingModal  = true;
    this.bookingNavDate    = new Date();
  }

  @action closeBookingModal() {
    this.showBookingModal      = false;
    this.showTimeSlotPopup     = false;
    this.selectedBookingDate   = null;
    this.bookingFromTime       = '';
    this.bookingToTime         = '';
    this.selectedRentIdx       = 0;
    this.bookingStep           = 1;
    this.selectedPaymentMethod = null;
    this.bookingUserNote       = '';
  }

  @action onBookingCalReady(instance) {
    this.bookingCalInstance = instance;
    instance.on('selectDateTime', ({ start }) => {
      const d = start?.toDate?.() ?? (start instanceof Date ? start : new Date(start));
      this.selectedBookingDate = d;
      this.bookingFromTime     = '';
      this.bookingToTime       = '';
      this.selectedRentIdx     = 0;
      this.clockMode           = 'hour';
      this.activeTimeEdit      = 'from';
      this.showTimeSlotPopup   = true;
    });
  }

  @action calPrev()  { this.bookingCalInstance?.prev();  this.#updateBookingLabel(); }
  @action calNext()  { this.bookingCalInstance?.next();  this.#updateBookingLabel(); }
  @action calToday() { this.bookingCalInstance?.today(); this.#updateBookingLabel(); }

  @action selectRentOpt(idx) {
    this.selectedRentIdx = idx;
    // Re-suggest To time when rent option changes
    if (this.bookingFromTime) {
      this.bookingToTime = this.#suggestedToTime(this.bookingFromTime);
    }
  }

  @action setActiveTimeEdit(slot) {
    this.activeTimeEdit = slot;
    this.clockMode = 'hour';
  }

  @action setClockMode(mode) {
    this.clockMode = mode;
  }

  @action setClockPeriod(period) {
    const current = this.activeTime;
    if (!current) return;
    const [h, m] = current.split(':').map(Number);
    let newH = h;
    if (period === 'PM' && h < 12)  newH = h + 12;
    if (period === 'AM' && h >= 12) newH = h - 12;
    if (newH === h) return;
    const timeStr = `${String(newH).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
    if (this.activeTimeEdit === 'from') {
      this.bookingFromTime = timeStr;
      const suggested = this.#suggestedToTime(timeStr);
      if (!this.bookingToTime || this.bookingToTime <= timeStr) {
        this.bookingToTime = suggested;
      }
    } else {
      this.bookingToTime = timeStr;
    }
  }

  @action selectClockHour(h) {
    const h24 = this.activePeriod === 'AM'
      ? (h === 12 ? 0 : h)
      : (h === 12 ? 12 : h + 12);
    if (this.activeTimeEdit === 'from') {
      const minute = this.bookingFromTime ? this.bookingFromTime.split(':')[1] : '00';
      const timeStr = `${String(h24).padStart(2, '0')}:${minute}`;
      this.bookingFromTime = timeStr;
      const suggested = this.#suggestedToTime(timeStr);
      if (!this.bookingToTime || this.bookingToTime <= timeStr) {
        this.bookingToTime = suggested;
      }
    } else {
      const minute = this.bookingToTime ? this.bookingToTime.split(':')[1] : '00';
      const timeStr = `${String(h24).padStart(2, '0')}:${minute}`;
      this.bookingToTime = timeStr;
    }
    this.clockMode = 'minute';
  }

  @action selectClockMinute(m) {
    if (this.activeTimeEdit === 'from') {
      const hour = this.bookingFromTime ? this.bookingFromTime.split(':')[0] : '06';
      const timeStr = `${hour}:${String(m).padStart(2, '0')}`;
      this.bookingFromTime = timeStr;
      const suggested = this.#suggestedToTime(timeStr);
      if (!this.bookingToTime || this.bookingToTime <= timeStr) {
        this.bookingToTime = suggested;
      }
    } else {
      const hour = this.bookingToTime ? this.bookingToTime.split(':')[0] : '07';
      const timeStr = `${hour}:${String(m).padStart(2, '0')}`;
      this.bookingToTime = timeStr;
    }
  }

  @action setFromTime(e) {
    this.bookingFromTime = e.target.value;
    // Auto-suggest To time based on rent slot duration; reset if To is now in the past
    const suggested = this.#suggestedToTime(e.target.value);
    if (!this.bookingToTime || this.bookingToTime <= e.target.value) {
      this.bookingToTime = suggested;
    }
  }

  @action setToTime(e) {
    const value = e.target.value;
    // Prevent selecting a To time that is at or before From time
    if (this.bookingFromTime && value <= this.bookingFromTime) {
      e.target.value = this.bookingToTime || this.#suggestedToTime(this.bookingFromTime);
      return;
    }
    this.bookingToTime = value;
  }

  @action closeTimeSlot() {
    this.showTimeSlotPopup     = false;
    this.selectedBookingDate   = null;
    this.bookingFromTime       = '';
    this.bookingToTime         = '';
    this.selectedRentIdx       = 0;
    this.clockMode             = 'hour';
    this.activeTimeEdit        = 'from';
    this.bookingStep           = 1;
    this.selectedPaymentMethod = null;
    this.bookingUserNote       = '';
  }

  @action goToPaymentStep() {
    if (!this.bookingTimeValid) return;
    this.bookingStep = 2;
  }

  @action goBackToTimeStep() {
    this.bookingStep = 1;
  }

  @action selectPaymentMethod(key) {
    this.selectedPaymentMethod = key;
  }

  @action updateBookingNote(event) {
    this.bookingUserNote = event.target.value;
  }

  @action async submitBooking() {
    if (!this.bookingTimeValid) return;
    if (!this.selectedPaymentMethod) {
      this.toast.warning('Please select a payment method.');
      return;
    }

    this.isBookingSubmitting = true;
    try {
      const token = this.session.data?.authenticated?.token ?? '';
      const user  = this.session.data?.authenticated?.user ?? {};

      const fullName = [
        user.user_fullname?.first_name,
        user.user_fullname?.last_name,
      ].filter(Boolean).join(' ') || user.user_email || '';

      const d = this.selectedBookingDate instanceof Date
        ? this.selectedBookingDate
        : new Date(this.selectedBookingDate);
      const pad = (n) => String(n).padStart(2, '0');
      const datePrefix = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;

      const payload = {
        fac_id:                               this.facility?.fac_id ?? '',
        fac_fac_id:                           this.selectedRentOpt?.fac_fac_id ?? '',
        fac_type:                             this.facility?.fac_sports?.[0] ?? '',
        book_user_phone:                      user.phone ?? '',
        book_user_name:                       fullName,
        email_token:                          '',
        book_user_email:                      user.user_email ?? '',
        booking_date_time: {
          start_time: `${datePrefix} ${this.bookingFromTime}:00`,
          end_time:   `${datePrefix} ${this.bookingToTime}:00`,
        },
        book_user_note:                       this.bookingUserNote.trim(),
        book_payment_method:                  this.selectedPaymentMethod,
        book_payment_amount:                  this.bookingAmount,
        book_payment_status:                  'pending',
        book_payment_transaction_id:          '',
        book_payment_transaction_account:     '',
        book_payment_transaction_account_name: '',
        book_disposition:                     'pending',
      };

      const res = await fetch(`${API_BASE}/facility/insert_facility_booking/`, {
        method:  'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization:  `Bearer ${token}`,
        },
        body: JSON.stringify(payload),
      });

      const data = await res.json().catch(() => ({}));
      if (res.ok && data.success !== false) {
        this.toast.success('Booking confirmed! We will contact you soon.');
        this.closeBookingModal();
      } else {
        this.toast.error(data.message ?? 'Failed to submit booking. Please try again.');
      }
    } catch (err) {
      this.toast.error(err.message ?? 'Network error. Please try again.');
    } finally {
      this.isBookingSubmitting = false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  <template>
    <div class="w-full min-h-screen bg-gray-50 dark:bg-gray-950">

      {{! ── Loading skeleton ── }}
      {{#if this.isLoading}}
        <div class="px-4 py-8 animate-pulse">
          <div class="h-52 sm:h-72 rounded-2xl bg-gradient-to-br from-gray-200 to-gray-300 dark:from-gray-700 dark:to-gray-600 mb-8"></div>
          <div class="flex flex-col items-center gap-3 mb-8">
            <div class="w-24 h-24 rounded-2xl bg-gray-300 dark:bg-gray-600"></div>
            <div class="h-6 w-48 bg-gray-200 dark:bg-gray-700 rounded-full"></div>
            <div class="h-4 w-32 bg-gray-200 dark:bg-gray-700 rounded-full"></div>
          </div>
          {{#each this.skeletonRows as |_|}}
            <div class="h-24 rounded-2xl bg-gray-200 dark:bg-gray-700 mb-4"></div>
          {{/each}}
        </div>

      {{! ── Error state ── }}
      {{else if this.error}}
        <div class="flex flex-col items-center justify-center min-h-[60vh] text-center px-4">
          <div class="w-16 h-16 mb-5 rounded-2xl bg-rose-100 dark:bg-rose-900/30 flex items-center justify-center">
            {{lucideIcon "alert-circle" size=32 class="text-rose-500"}}
          </div>
          <p class="text-base font-semibold text-gray-900 dark:text-white mb-1">Something went wrong</p>
          <p class="text-sm text-gray-500 dark:text-gray-400 mb-5">{{this.error}}</p>
          <div class="flex gap-3">
            <button type="button" {{on "click" this.retry}}
              class="inline-flex items-center gap-2 px-5 py-2 rounded-xl text-sm font-semibold
                     bg-indigo-600 hover:bg-indigo-500 text-white shadow-sm transition-all duration-150">
              <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                   stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                <path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/>
                <path d="M3 3v5h5"/>
              </svg>
              Try Again
            </button>
            <button type="button" {{on "click" this.goBack}}
              class="inline-flex items-center gap-2 px-5 py-2 rounded-xl text-sm font-semibold
                     bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700
                     text-gray-600 dark:text-gray-300 shadow-sm transition-all duration-150">
              Back
            </button>
          </div>
        </div>

      {{! ── Facility detail ── }}
      {{else if this.facility}}

        {{! ─── HERO BANNER ─── }}
        <div class="relative mt-4">
          <div class="relative">
            <div class="relative h-52 sm:h-80 lg:h-96 overflow-hidden
                        bg-gradient-to-br from-indigo-600 via-violet-600 to-fuchsia-600
                        dark:from-indigo-800 dark:via-violet-800 dark:to-fuchsia-800">
              {{! Back button — absolute top-left over the cover }}
              <button type="button" {{on "click" this.goBack}}
                class="absolute top-4 left-4 z-20
                       inline-flex items-center gap-2 pl-2.5 pr-4 py-2 rounded-xl
                       bg-black/30 hover:bg-black/50 backdrop-blur-sm
                       text-white text-sm font-semibold
                       border border-white/20 hover:border-white/40
                       shadow-lg transition-all duration-200 group">
                <span class="flex items-center justify-center w-6 h-6 rounded-lg
                             bg-white/20 group-hover:bg-white/30 transition-colors duration-200">
                  {{lucideIcon "arrow-left" size=14 class="text-white transition-transform duration-200 group-hover:-translate-x-0.5"}}
                </span>
                Back to Facilities
              </button>

              {{! Dot-grid texture }}
              <div class="absolute inset-0 opacity-[0.15]"
                   style="background-image: radial-gradient(circle, white 1px, transparent 1px); background-size: 20px 20px;"></div>
              <div class="absolute -top-20 -right-20 w-80 h-80 rounded-full bg-white/10 blur-3xl pointer-events-none"></div>
              {{#if this.bannerUrl}}
                <img src={{this.bannerUrl}} alt={{this.facility.fac_name}}
                     class="absolute inset-0 w-full h-full object-cover" />
                <div class="absolute inset-0 bg-gradient-to-t from-black/70 via-black/20 to-transparent"></div>
              {{/if}}
              {{! Sport badges on banner }}
              {{#if this.hasSports}}
                <div class="absolute bottom-4 left-4 flex flex-wrap gap-1.5 z-10">
                  {{#each this.facility.fac_sports as |sport|}}
                    <span class="inline-flex items-center px-2.5 py-1 rounded-full
                                 text-[10px] font-bold uppercase tracking-wider
                                 bg-black/30 backdrop-blur-sm text-white border border-white/20">
                      {{sport}}
                    </span>
                  {{/each}}
                </div>
              {{/if}}
              {{! Status badge }}
              <span class="absolute top-4 right-4 z-10 flex items-center gap-1.5
                           px-3 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider
                           bg-emerald-500/90 backdrop-blur-sm text-white">
                <span class="w-1.5 h-1.5 rounded-full bg-white animate-pulse"></span>
                Open
              </span>
            </div>

            {{! Floating logo }}
            <div class="absolute left-1/2 -translate-x-1/2 bottom-0 translate-y-1/2 z-10">
              <div class="w-24 h-24 sm:w-28 sm:h-28 rounded-2xl
                          border-4 border-white dark:border-gray-950
                          shadow-2xl overflow-hidden
                          bg-white dark:bg-gray-800
                          ring-4 ring-indigo-300/40 dark:ring-indigo-500/30
                          transition-transform duration-300 hover:scale-105">
                {{#if this.logoUrl}}
                  <img src={{this.logoUrl}} alt={{this.facility.fac_name}}
                       class="w-full h-full object-cover" />
                {{else}}
                  <div class="w-full h-full flex items-center justify-center
                              bg-gradient-to-br from-indigo-500 to-violet-600">
                    {{lucideIcon "building" size=40 class="text-white/80"}}
                  </div>
                {{/if}}
              </div>
            </div>
          </div>
        </div>

        {{! ─── IDENTITY SECTION ─── }}
        <div class="px-4">
          <div class="pt-16 sm:pt-20 pb-5 text-center">

            <h1 class="text-xl sm:text-3xl font-black text-gray-900 dark:text-white
                       mb-1.5 leading-tight tracking-tight">
              {{this.facility.fac_name}}
            </h1>

            {{! Location }}
            <div class="flex items-center justify-center gap-1.5
                        text-gray-500 dark:text-gray-400 text-sm mb-4">
              {{lucideIcon "map-pin" size=16 class="text-violet-500 shrink-0"}}
              <span>{{this.facility.fac_city}}, {{this.facility.fac_district}}, {{this.facility.fac_country}}</span>
            </div>

            {{! Stats pills }}
            <div class="flex flex-wrap items-center justify-center gap-2 mb-5">

              {{#if this.established}}
                <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider
                             bg-amber-100 dark:bg-amber-900/30 text-amber-700 dark:text-amber-300
                             border border-amber-200 dark:border-amber-700/40">
                  {{lucideIcon "calendar" size=12}}
                  Est. {{this.established}}
                </span>
              {{/if}}

              <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider
                           bg-violet-100 dark:bg-violet-900/30 text-violet-700 dark:text-violet-300
                           border border-violet-200 dark:border-violet-700/40">
                {{lucideIcon "globe" size=12}}
                {{this.facility.fac_match_played}} Matches
              </span>

              <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider
                           bg-rose-100 dark:bg-rose-900/30 text-rose-700 dark:text-rose-300
                           border border-rose-200 dark:border-rose-700/40">
                <svg class="w-3 h-3" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/>
                </svg>
                {{this.formatRating}} Rating
              </span>

              <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider
                           bg-indigo-100 dark:bg-indigo-900/30 text-indigo-700 dark:text-indigo-300
                           border border-indigo-200 dark:border-indigo-700/40">
                {{lucideIcon "star" size=12}}
                {{this.facility.customer_review}} Reviews
              </span>

            </div>

            {{! Contact row }}
            <div class="flex flex-wrap items-center justify-center gap-x-5 gap-y-2.5 mb-5">

              {{#if this.facility.fac_cell_phone}}
                <a href="tel:{{this.facility.fac_cell_phone}}"
                   class="inline-flex items-center gap-1.5 text-xs text-gray-500 dark:text-gray-400
                          hover:text-emerald-600 dark:hover:text-emerald-400 transition-colors">
                  {{lucideIcon "phone" size=14 class="text-emerald-500"}}
                  {{this.facility.fac_cell_phone}}
                </a>
              {{/if}}

              {{#if this.facility.fac_email}}
                <a href="mailto:{{this.facility.fac_email}}"
                   class="inline-flex items-center gap-1.5 text-xs text-gray-500 dark:text-gray-400
                          hover:text-indigo-600 dark:hover:text-indigo-400 transition-colors">
                  {{lucideIcon "mail" size=14 class="text-indigo-500"}}
                  {{this.facility.fac_email}}
                </a>
              {{/if}}

              {{#if this.facility.fac_website}}
                <a href={{this.facility.fac_website}} target="_blank" rel="noopener noreferrer"
                   class="inline-flex items-center gap-1.5 text-xs text-gray-500 dark:text-gray-400
                          hover:text-cyan-600 dark:hover:text-cyan-400 transition-colors">
                  {{lucideIcon "globe" size=14 class="text-cyan-500"}}
                  Website
                </a>
              {{/if}}

              {{#if this.facility.google_map_link}}
                <a href={{this.facility.google_map_link}} target="_blank" rel="noopener noreferrer"
                   class="inline-flex items-center gap-1.5 text-xs text-gray-500 dark:text-gray-400
                          hover:text-rose-600 dark:hover:text-rose-400 transition-colors">
                  {{lucideIcon "map-pin" size=14 class="text-rose-500"}}
                  View on Map
                </a>
              {{/if}}

            </div>

            {{! Follow Us button }}
            <button
              type="button"
              {{on "click" this.toggleFollow}}
              class="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl text-sm font-bold
                     transition-all duration-200 focus:outline-none
                     {{if this.isFollowing
                       'bg-indigo-600 hover:bg-indigo-500 text-white shadow-md shadow-indigo-500/30'
                       'bg-white dark:bg-gray-800 border-2 border-indigo-500 dark:border-indigo-400
                        text-indigo-600 dark:text-indigo-400
                        hover:bg-indigo-50 dark:hover:bg-indigo-900/20'}}"
            >
              {{#if this.isFollowing}}
                {{lucideIcon "check" size=16}}
                Following
              {{else}}
                <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                     stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M18 8h1a4 4 0 0 1 0 8h-1"/>
                  <path d="M2 8h16v9a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4V8z"/>
                  <line x1="6" y1="1" x2="6" y2="4"/>
                  <line x1="10" y1="1" x2="10" y2="4"/>
                  <line x1="14" y1="1" x2="14" y2="4"/>
                </svg>
                Follow Us
              {{/if}}
            </button>

          </div>
        </div>

        {{! ─── STICKY TAB NAV ─── }}
        <div class="sticky top-0 z-30
                    bg-white/95 dark:bg-gray-900/95 backdrop-blur-md
                    border-b border-gray-200 dark:border-gray-700/60 shadow-sm">

          {{! Tab bar — arrow-scroll on all screen sizes, arrows hidden ≥ 1486px }}
          <div class="flex items-stretch">

            {{! Left scroll arrow — hidden on screens ≥ 1486px }}
            <button
              type="button"
              {{on "click" this.scrollTabsLeft}}
              disabled={{this.tabBarAtStart}}
              class="shrink-0 w-9 flex min-[1486px]:hidden items-center justify-center
                     border-r border-gray-200 dark:border-gray-700/60
                     text-gray-400 dark:text-gray-500
                     hover:text-indigo-600 dark:hover:text-indigo-400
                     hover:bg-gray-50 dark:hover:bg-gray-800/50
                     disabled:opacity-25 disabled:cursor-default
                     transition-all duration-150 focus:outline-none"
            >
              {{lucideIcon "chevron-left" size=16}}
            </button>

            {{! Scrollable tab strip }}
            <div
              id="fac-tab-bar"
              {{on "scroll" this.onTabBarScroll}}
              class="flex-1 flex overflow-x-auto"
              style="scrollbar-width: none; -ms-overflow-style: none; scroll-behavior: smooth;"
            >
              {{! mx-auto centers when tabs fit; min-w-max prevents collapse when they overflow }}
              <div role="tablist" class="flex mx-auto min-w-max">
                {{#each this.tabs as |tab|}}
                  <button
                    type="button"
                    role="tab"
                    {{on "click" (fn this.setTab tab.id)}}
                    class="relative shrink-0 px-5 py-4 text-sm font-semibold
                           whitespace-nowrap transition-colors duration-200 focus:outline-none
                           {{if (eq this.activeTab tab.id)
                             'text-indigo-600 dark:text-indigo-400'
                             'text-gray-500 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200'}}"
                  >
                    {{tab.label}}
                    {{#if (eq this.activeTab tab.id)}}
                      <span class="absolute bottom-0 left-0 right-0 h-0.5 rounded-full
                                   bg-gradient-to-r from-indigo-500 to-violet-600"></span>
                    {{/if}}
                  </button>
                {{/each}}
              </div>
            </div>

            {{! Right scroll arrow — hidden on screens ≥ 1486px }}
            <button
              type="button"
              {{on "click" this.scrollTabsRight}}
              disabled={{this.tabBarAtEnd}}
              class="shrink-0 w-9 flex min-[1486px]:hidden items-center justify-center
                     border-l border-gray-200 dark:border-gray-700/60
                     text-gray-400 dark:text-gray-500
                     hover:text-indigo-600 dark:hover:text-indigo-400
                     hover:bg-gray-50 dark:hover:bg-gray-800/50
                     disabled:opacity-25 disabled:cursor-default
                     transition-all duration-150 focus:outline-none"
            >
              {{lucideIcon "chevron-right" size=16}}
            </button>

          </div>
        </div>

        {{! ─── TAB CONTENT ─── }}
        <div class="px-4 py-6 sm:py-8">

          {{! ══ ABOUT US ══ }}
          {{#if (eq this.activeTab "about")}}
            <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">

              {{! Left: description + info }}
              <div class="lg:col-span-2 space-y-5">

                {{! Description card }}
                <div class="rounded-2xl bg-white dark:bg-gray-900
                            border border-gray-100 dark:border-gray-700/50 shadow-sm overflow-hidden">
                  <div class="flex items-center gap-2.5 px-5 pt-5 pb-4">
                    <div class="w-8 h-8 rounded-xl bg-gradient-to-br from-indigo-500 to-violet-600
                                flex items-center justify-center shrink-0 shadow-sm shadow-indigo-500/25">
                      {{lucideIcon "info" size=16 class="text-white"}}
                    </div>
                    <div class="flex items-center justify-between flex-1">
                      <h3 class="text-sm font-bold text-gray-900 dark:text-white">About the Facility</h3>
                      {{#if this.canEdit}}
                        <button type="button"
                                class="flex items-center gap-1.5 px-3 py-1.5 rounded-xl
                                       bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold
                                       transition-colors shadow-sm shadow-indigo-500/30"
                                {{on "click" this.openEditModal}}>
                          {{lucideIcon "pencil" size=12}}
                          Edit
                        </button>
                      {{/if}}
                    </div>
                  </div>
                  <div class="h-px bg-gradient-to-r from-indigo-500/30 via-violet-400/20 to-transparent mx-5 mb-4"></div>
                  {{#if this.description}}
                    <div class="px-5 pb-5 rich-text prose-sm text-gray-600 dark:text-gray-400 leading-relaxed">
                      {{safeHtml this.description}}
                    </div>
                  {{else if this.aboutUs}}
                    <div class="px-5 pb-5 rich-text prose-sm text-gray-600 dark:text-gray-400 leading-relaxed">
                      {{safeHtml this.aboutUs}}
                    </div>
                  {{else}}
                    <div class="flex flex-col items-center justify-center py-10 px-5 text-center">
                      <div class="w-12 h-12 rounded-2xl bg-gray-100 dark:bg-gray-800 flex items-center justify-center mb-3">
                        {{lucideIcon "info" size=24 class="text-gray-300 dark:text-gray-600"}}
                      </div>
                      <p class="text-sm font-semibold text-gray-400 dark:text-gray-500">No description yet</p>
                    </div>
                  {{/if}}
                </div>

                {{! Facility info grid }}
                <div class="rounded-2xl bg-white dark:bg-gray-900
                            border border-gray-100 dark:border-gray-700/50 shadow-sm p-5">
                  <h3 class="flex items-center gap-2 text-sm font-bold text-gray-900 dark:text-white mb-4">
                    <span class="w-7 h-7 rounded-lg bg-violet-100 dark:bg-violet-900/40 flex items-center justify-center shrink-0">
                      {{lucideIcon "info" size=14 class="text-violet-600 dark:text-violet-400"}}
                    </span>
                    Facility Information
                  </h3>

                  <dl class="grid grid-cols-1 sm:grid-cols-2 gap-3">

                    <div class="flex items-start gap-3 p-3 rounded-xl bg-gray-50 dark:bg-gray-800/60">
                      <div class="w-8 h-8 rounded-lg bg-rose-100 dark:bg-rose-900/30 flex items-center justify-center shrink-0">
                        {{lucideIcon "map-pin" size=16 class="text-rose-500"}}
                      </div>
                      <div class="min-w-0">
                        <dt class="text-[10px] font-bold uppercase tracking-wider text-gray-400 dark:text-gray-500 mb-0.5">Address</dt>
                        <dd class="text-sm font-medium text-gray-700 dark:text-gray-300 truncate">{{this.facility.fac_address}}</dd>
                      </div>
                    </div>

                    <div class="flex items-start gap-3 p-3 rounded-xl bg-gray-50 dark:bg-gray-800/60">
                      <div class="w-8 h-8 rounded-lg bg-indigo-100 dark:bg-indigo-900/30 flex items-center justify-center shrink-0">
                        {{lucideIcon "building" size=16 class="text-indigo-500"}}
                      </div>
                      <div class="min-w-0">
                        <dt class="text-[10px] font-bold uppercase tracking-wider text-gray-400 dark:text-gray-500 mb-0.5">District / Division</dt>
                        <dd class="text-sm font-medium text-gray-700 dark:text-gray-300 truncate">
                          {{this.facility.fac_district}}, {{this.facility.fac_division}}
                        </dd>
                      </div>
                    </div>

                    <div class="flex items-start gap-3 p-3 rounded-xl bg-gray-50 dark:bg-gray-800/60">
                      <div class="w-8 h-8 rounded-lg bg-emerald-100 dark:bg-emerald-900/30 flex items-center justify-center shrink-0">
                        {{lucideIcon "phone" size=16 class="text-emerald-500"}}
                      </div>
                      <div class="min-w-0">
                        <dt class="text-[10px] font-bold uppercase tracking-wider text-gray-400 dark:text-gray-500 mb-0.5">Phone</dt>
                        <dd class="text-sm font-medium text-gray-700 dark:text-gray-300">
                          {{#if this.facility.fac_cell_phone}}{{this.facility.fac_cell_phone}}{{else}}—{{/if}}
                        </dd>
                      </div>
                    </div>

                    <div class="flex items-start gap-3 p-3 rounded-xl bg-gray-50 dark:bg-gray-800/60">
                      <div class="w-8 h-8 rounded-lg bg-amber-100 dark:bg-amber-900/30 flex items-center justify-center shrink-0">
                        {{lucideIcon "calendar" size=16 class="text-amber-500"}}
                      </div>
                      <div class="min-w-0">
                        <dt class="text-[10px] font-bold uppercase tracking-wider text-gray-400 dark:text-gray-500 mb-0.5">Established</dt>
                        <dd class="text-sm font-medium text-gray-700 dark:text-gray-300">
                          {{#if this.established}}{{this.established}}{{else}}—{{/if}}
                        </dd>
                      </div>
                    </div>

                    <div class="flex items-start gap-3 p-3 rounded-xl bg-gray-50 dark:bg-gray-800/60">
                      <div class="w-8 h-8 rounded-lg bg-cyan-100 dark:bg-cyan-900/30 flex items-center justify-center shrink-0">
                        {{lucideIcon "mail" size=16 class="text-cyan-500"}}
                      </div>
                      <div class="min-w-0">
                        <dt class="text-[10px] font-bold uppercase tracking-wider text-gray-400 dark:text-gray-500 mb-0.5">Email</dt>
                        <dd class="text-sm font-medium text-gray-700 dark:text-gray-300 truncate">
                          {{#if this.facility.fac_email}}{{this.facility.fac_email}}{{else}}—{{/if}}
                        </dd>
                      </div>
                    </div>

                    <div class="flex items-start gap-3 p-3 rounded-xl bg-gray-50 dark:bg-gray-800/60">
                      <div class="w-8 h-8 rounded-lg bg-fuchsia-100 dark:bg-fuchsia-900/30 flex items-center justify-center shrink-0">
                        {{lucideIcon "map-pin" size=16 class="text-fuchsia-500"}}
                      </div>
                      <div class="min-w-0">
                        <dt class="text-[10px] font-bold uppercase tracking-wider text-gray-400 dark:text-gray-500 mb-0.5">Post Code</dt>
                        <dd class="text-sm font-medium text-gray-700 dark:text-gray-300">
                          {{#if this.facility.fac_post_code}}{{this.facility.fac_post_code}}{{else}}—{{/if}}
                        </dd>
                      </div>
                    </div>

                  </dl>
                </div>

              </div>

              {{! Right sidebar: managers + social }}
              <div class="space-y-5">

                {{! Managers card }}
                <div class="rounded-2xl bg-white dark:bg-gray-900
                            border border-gray-100 dark:border-gray-700/50 shadow-sm overflow-hidden">
                  <div class="flex items-center gap-2.5 px-5 pt-5 pb-4">
                    <div class="w-8 h-8 rounded-xl bg-gradient-to-br from-violet-500 to-fuchsia-600
                                flex items-center justify-center shrink-0 shadow-sm">
                      {{lucideIcon "users" size=16 class="text-white"}}
                    </div>
                    <h3 class="text-sm font-bold text-gray-900 dark:text-white">Managers</h3>
                  </div>
                  <div class="h-px bg-gradient-to-r from-violet-500/30 via-fuchsia-400/20 to-transparent mx-5 mb-4"></div>

                  {{#if this.hasManagers}}
                    <div class="px-5 pb-5 space-y-3">
                      {{#each this.managers as |mgr idx|}}
                        <div class="flex items-center gap-3 p-3 rounded-xl
                                    bg-gray-50 dark:bg-gray-800/50 group">
                          <div class="w-9 h-9 rounded-xl bg-gradient-to-br {{this.managerGradient idx}}
                                      flex items-center justify-center shrink-0 shadow-sm text-white text-xs font-extrabold">
                            {{this.managerInitials mgr.name}}
                          </div>
                          <div class="min-w-0 flex-1">
                            <p class="text-sm font-semibold text-gray-800 dark:text-gray-200 truncate">
                              {{mgr.name}}
                            </p>
                            <p class="text-[10px] text-gray-400 dark:text-gray-500">Manager</p>
                          </div>
                        </div>
                      {{/each}}
                    </div>
                  {{else}}
                    <div class="flex flex-col items-center py-8 px-5 text-center">
                      <p class="text-sm text-gray-400 dark:text-gray-500">No managers listed</p>
                    </div>
                  {{/if}}
                </div>

                {{! Social links card }}
                <div class="rounded-2xl bg-white dark:bg-gray-900
                            border border-gray-100 dark:border-gray-700/50 shadow-sm p-5">
                  <h3 class="flex items-center gap-2 text-sm font-bold text-gray-900 dark:text-white mb-4">
                    <span class="w-7 h-7 rounded-lg bg-indigo-100 dark:bg-indigo-900/40 flex items-center justify-center shrink-0">
                      {{lucideIcon "share" size=14 class="text-indigo-600 dark:text-indigo-400"}}
                    </span>
                    Social Links
                  </h3>

                  <div class="flex flex-wrap gap-2">

                    {{#if (get this.facility.fac_facebook "0")}}
                      <a href={{get this.facility.fac_facebook "0"}} target="_blank" rel="noopener noreferrer"
                         class="flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-semibold
                                bg-blue-50 dark:bg-blue-900/20 text-blue-700 dark:text-blue-400
                                border border-blue-200 dark:border-blue-700/40
                                hover:bg-blue-100 dark:hover:bg-blue-900/40 transition-colors">
                        <svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="currentColor">
                          <path d="M18 2h-3a5 5 0 0 0-5 5v3H7v4h3v8h4v-8h3l1-4h-4V7a1 1 0 0 1 1-1h3z"/>
                        </svg>
                        Facebook
                      </a>
                    {{/if}}

                    {{#if (get this.facility.fac_twitter "0")}}
                      <a href={{get this.facility.fac_twitter "0"}} target="_blank" rel="noopener noreferrer"
                         class="flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-semibold
                                bg-sky-50 dark:bg-sky-900/20 text-sky-700 dark:text-sky-400
                                border border-sky-200 dark:border-sky-700/40
                                hover:bg-sky-100 dark:hover:bg-sky-900/40 transition-colors">
                        <svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="currentColor">
                          <path d="M23 3a10.9 10.9 0 0 1-3.14 1.53 4.48 4.48 0 0 0-7.86 3v1A10.66 10.66 0 0 1 3 4s-4 9 5 13a11.64 11.64 0 0 1-7 2c9 5 20 0 20-11.5a4.5 4.5 0 0 0-.08-.83A7.72 7.72 0 0 0 23 3z"/>
                        </svg>
                        Twitter
                      </a>
                    {{/if}}

                    {{#if (get this.facility.fac_instagram "0")}}
                      <a href={{get this.facility.fac_instagram "0"}} target="_blank" rel="noopener noreferrer"
                         class="flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-semibold
                                bg-pink-50 dark:bg-pink-900/20 text-pink-700 dark:text-pink-400
                                border border-pink-200 dark:border-pink-700/40
                                hover:bg-pink-100 dark:hover:bg-pink-900/40 transition-colors">
                        <svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none"
                             stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                          <rect x="2" y="2" width="20" height="20" rx="5" ry="5"/>
                          <path d="M16 11.37A4 4 0 1 1 12.63 8 4 4 0 0 1 16 11.37z"/>
                          <line x1="17.5" y1="6.5" x2="17.51" y2="6.5"/>
                        </svg>
                        Instagram
                      </a>
                    {{/if}}

                    {{#if (get this.facility.fac_youtube "0")}}
                      <a href={{get this.facility.fac_youtube "0"}} target="_blank" rel="noopener noreferrer"
                         class="flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-semibold
                                bg-red-50 dark:bg-red-900/20 text-red-700 dark:text-red-400
                                border border-red-200 dark:border-red-700/40
                                hover:bg-red-100 dark:hover:bg-red-900/40 transition-colors">
                        <svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="currentColor">
                          <path d="M22.54 6.42a2.78 2.78 0 0 0-1.95-1.96C18.88 4 12 4 12 4s-6.88 0-8.59.46A2.78 2.78 0 0 0 1.46 6.42 29 29 0 0 0 1 12a29 29 0 0 0 .46 5.58 2.78 2.78 0 0 0 1.95 1.95C5.12 20 12 20 12 20s6.88 0 8.59-.47a2.78 2.78 0 0 0 1.95-1.95A29 29 0 0 0 23 12a29 29 0 0 0-.46-5.58z"/>
                          <polygon points="9.75 15.02 15.5 12 9.75 8.98 9.75 15.02" fill="white"/>
                        </svg>
                        YouTube
                      </a>
                    {{/if}}

                    {{#unless this.hasSocialLinks}}
                      <p class="text-sm text-gray-400 dark:text-gray-500 w-full text-center py-3">No social links yet</p>
                    {{/unless}}

                  </div>
                </div>

              </div>
            </div>

          {{! ══ FACILITIES TAB ══ }}
          {{else if (eq this.activeTab "facilities")}}
            <div class="space-y-6">

              {{! ── Tab header with Book Field button ── }}
              <div class="flex items-center justify-between">
                <div>
                  <h2 class="text-base font-extrabold text-gray-900 dark:text-white">Available Facilities</h2>
                  <p class="text-xs text-gray-500 dark:text-gray-400 mt-0.5">Browse and book fields at this facility</p>
                </div>
                <button
                  type="button"
                  {{on "click" this.openBookingModal}}
                  class="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-bold
                         bg-gradient-to-r from-indigo-600 to-violet-600
                         hover:from-indigo-500 hover:to-violet-500
                         text-white shadow-md shadow-indigo-500/30
                         hover:shadow-lg hover:shadow-indigo-500/40
                         transition-all duration-200 active:scale-95
                         focus:outline-none focus:ring-2 focus:ring-indigo-400 focus:ring-offset-2
                         dark:focus:ring-offset-gray-900"
                >
                  {{lucideIcon "plus" size=16}}
                  Book Field
                </button>
              </div>

              {{! ── Loading skeleton ── }}
              {{#if this.facItemsLoading}}
                <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                  {{#each this.skeletonRows as |_|}}
                    <div class="rounded-2xl bg-white dark:bg-gray-900
                                border border-gray-100 dark:border-gray-700/50 shadow-sm
                                overflow-hidden animate-pulse">
                      <div class="h-2 bg-gradient-to-r from-indigo-300 to-violet-300 dark:from-indigo-700 dark:to-violet-700"></div>
                      <div class="p-5 space-y-4">
                        <div class="flex items-center gap-3">
                          <div class="w-10 h-10 rounded-xl bg-gray-200 dark:bg-gray-700 shrink-0"></div>
                          <div class="flex-1 space-y-2">
                            <div class="h-4 bg-gray-200 dark:bg-gray-700 rounded-full w-3/4"></div>
                            <div class="h-3 bg-gray-200 dark:bg-gray-700 rounded-full w-1/2"></div>
                          </div>
                        </div>
                        <div class="h-px bg-gray-100 dark:bg-gray-800"></div>
                        <div class="grid grid-cols-2 gap-3">
                          <div class="h-14 rounded-xl bg-gray-100 dark:bg-gray-800"></div>
                          <div class="h-14 rounded-xl bg-gray-100 dark:bg-gray-800"></div>
                        </div>
                      </div>
                    </div>
                  {{/each}}
                </div>

              {{! ── Error state ── }}
              {{else if this.facItemsError}}
                <div class="flex flex-col items-center justify-center py-16 text-center">
                  <div class="w-14 h-14 mb-4 rounded-2xl bg-rose-100 dark:bg-rose-900/30
                              flex items-center justify-center">
                    {{lucideIcon "alert-circle" size=28 class="text-rose-500"}}
                  </div>
                  <p class="text-sm font-semibold text-gray-900 dark:text-white mb-1">Failed to load</p>
                  <p class="text-xs text-gray-500 dark:text-gray-400 mb-4">{{this.facItemsError}}</p>
                  <button type="button" {{on "click" this.retryFacItems}}
                    class="inline-flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-semibold
                           bg-indigo-600 hover:bg-indigo-500 text-white shadow-sm transition-all duration-150">
                    <svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                         stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                      <path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/>
                      <path d="M3 3v5h5"/>
                    </svg>
                    Try Again
                  </button>
                </div>

              {{! ── Empty state ── }}
              {{else if (eq this.facItems.length 0)}}
                <div class="flex flex-col items-center justify-center py-20 text-center">
                  <div class="w-20 h-20 mb-6 rounded-3xl
                              bg-gradient-to-br from-indigo-100 to-violet-100
                              dark:from-indigo-900/40 dark:to-violet-900/30
                              flex items-center justify-center">
                    {{lucideIcon "building" size=40 class="text-indigo-400 dark:text-indigo-500"}}
                  </div>
                  <p class="text-base font-bold text-gray-900 dark:text-white mb-1">No Facilities Listed</p>
                  <p class="text-sm text-gray-500 dark:text-gray-400">No sub-facilities have been added yet.</p>
                </div>

              {{! ── Facility items grid ── }}
              {{else}}
                <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-5">
                  {{#each this.facItems as |item|}}

                    <div class="group relative rounded-2xl overflow-hidden
                                bg-white dark:bg-gray-900
                                border border-gray-100 dark:border-gray-700/50
                                shadow-sm hover:shadow-xl hover:shadow-indigo-500/10
                                transition-all duration-300 hover:-translate-y-1">

                      {{! Coloured top accent bar by sport type }}
                      <div class="h-1.5 w-full
                                  bg-gradient-to-r from-indigo-500 via-violet-500 to-fuchsia-500"></div>

                      <div class="p-5">

                        {{! Header: sport icon + name }}
                        <div class="flex items-center gap-3 mb-4">
                          <div class="w-11 h-11 rounded-2xl shrink-0 flex items-center justify-center
                                      bg-gradient-to-br from-indigo-500 to-violet-600
                                      shadow-md shadow-indigo-500/25">
                            {{lucideIcon "globe" size=20 class="text-white"}}
                          </div>
                          <div class="min-w-0 flex-1">
                            <h4 class="text-sm font-extrabold text-gray-900 dark:text-white capitalize leading-snug truncate">
                              {{#if item.fac_fac_name}}{{item.fac_fac_name}}{{else}}{{item.fac_fac_type}}{{/if}}
                            </h4>
                            <span class="inline-flex items-center mt-0.5 px-2 py-0.5 rounded-full
                                         text-[10px] font-bold uppercase tracking-wider
                                         bg-indigo-100 dark:bg-indigo-900/40
                                         text-indigo-600 dark:text-indigo-400">
                              {{item.fac_fac_type}}
                            </span>
                          </div>
                        </div>

                        {{! Divider }}
                        <div class="h-px bg-gradient-to-r from-indigo-200/60 via-violet-200/40 dark:from-indigo-700/40 dark:via-violet-700/30 to-transparent mb-4"></div>

                        {{! Description }}
                        {{#if item.description}}
                          <p class="text-xs text-gray-500 dark:text-gray-400 leading-relaxed mb-4 line-clamp-2">
                            {{item.description}}
                          </p>
                        {{/if}}

                        {{! Rent options }}
                        {{#if item.rent_options.length}}
                          <div class="mb-4">
                            <p class="text-[10px] font-bold uppercase tracking-widest
                                      text-gray-400 dark:text-gray-500 mb-2">Rent Options</p>
                            <div class="grid grid-cols-2 gap-2">
                              {{#each item.rent_options as |opt|}}
                                <div class="flex flex-col items-center justify-center p-2.5 rounded-xl
                                            bg-gradient-to-br from-emerald-50 to-teal-50
                                            dark:from-emerald-900/20 dark:to-teal-900/20
                                            border border-emerald-200/60 dark:border-emerald-700/40">
                                  <span class="text-base font-extrabold text-emerald-700 dark:text-emerald-400 leading-none">
                                    ৳{{opt.price}}
                                  </span>
                                  <span class="text-[10px] font-semibold text-emerald-600/70 dark:text-emerald-500/70 mt-0.5">
                                    / {{opt.time_slot}} hr
                                  </span>
                                </div>
                              {{/each}}
                            </div>
                          </div>
                        {{/if}}

                        {{! Payment methods }}
                        {{#if item.payment_method.length}}
                          <div>
                            <p class="text-[10px] font-bold uppercase tracking-widest
                                      text-gray-400 dark:text-gray-500 mb-2">Payment Methods</p>
                            <div class="flex flex-wrap gap-1.5">
                              {{#each item.payment_method as |pm|}}
                                <span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg
                                             text-[11px] font-semibold capitalize
                                             bg-amber-50 dark:bg-amber-900/20
                                             text-amber-700 dark:text-amber-400
                                             border border-amber-200/60 dark:border-amber-700/40">
                                  <svg class="w-3 h-3 shrink-0" viewBox="0 0 24 24" fill="none"
                                       stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                    <rect x="1" y="4" width="22" height="16" rx="2" ry="2"/>
                                    <line x1="1" y1="10" x2="23" y2="10"/>
                                  </svg>
                                  {{pm.method}}
                                </span>
                              {{/each}}
                            </div>
                          </div>
                        {{/if}}
                      </div>
                    </div>
                  {{/each}}
                </div>
              {{/if}}
            </div>

          {{! ══ SCHEDULE TAB ══ }}
          {{else if (eq this.activeTab "schedule")}}
            <div class="space-y-5">

              {{! Loading skeleton }}
              {{#if this.scheduleLoading}}
                <div class="flex flex-col items-center justify-center py-24 gap-4">
                  <div class="w-10 h-10 rounded-full border-4 border-indigo-200 dark:border-indigo-800
                              border-t-indigo-500 dark:border-t-indigo-400 animate-spin"></div>
                  <p class="text-sm text-gray-400 dark:text-gray-500 font-medium">Loading schedule…</p>
                </div>

              {{! No bookings / API error state }}
              {{else if this.scheduleError}}
                <div class="flex flex-col items-center justify-center py-24 text-center">
                  <div class="relative mb-6">
                    {{! Outer glow ring }}
                    <div class="absolute inset-0 rounded-3xl
                                bg-gradient-to-br from-amber-400/20 to-orange-400/10
                                dark:from-amber-500/15 dark:to-orange-500/10
                                blur-xl scale-110"></div>
                    <div class="relative w-24 h-24 rounded-3xl
                                bg-gradient-to-br from-amber-50 to-orange-50
                                dark:from-amber-900/30 dark:to-orange-900/20
                                border border-amber-100 dark:border-amber-800/40
                                flex items-center justify-center shadow-lg">
                      {{! Calendar with X mark }}
                      <svg class="w-12 h-12 text-amber-500 dark:text-amber-400" viewBox="0 0 24 24" fill="none"
                           stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                        <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
                        <line x1="16" y1="2" x2="16" y2="6"/>
                        <line x1="8" y1="2" x2="8" y2="6"/>
                        <line x1="3" y1="10" x2="21" y2="10"/>
                        <line x1="9" y1="15" x2="15" y2="15"/>
                      </svg>
                      {{! Small badge }}
                      <span class="absolute -top-2 -right-2 w-7 h-7 rounded-full
                                   bg-gradient-to-br from-amber-400 to-orange-500
                                   flex items-center justify-center shadow-md">
                        {{lucideIcon "x" size=14 class="text-white"}}
                      </span>
                    </div>
                  </div>

                  <p class="text-lg font-extrabold text-gray-900 dark:text-white mb-1">
                    No Upcoming Matches
                  </p>
                  <p class="text-sm text-gray-500 dark:text-gray-400 max-w-xs leading-relaxed">
                    There are no scheduled matches or bookings at this facility right now.
                  </p>

                  <button type="button"
                          class="mt-6 inline-flex items-center gap-2 px-5 py-2.5 rounded-2xl
                                 text-sm font-bold
                                 bg-amber-50 dark:bg-amber-900/20
                                 text-amber-700 dark:text-amber-400
                                 border border-amber-200 dark:border-amber-700/50
                                 hover:bg-amber-100 dark:hover:bg-amber-900/40
                                 transition-colors duration-150"
                          {{on "click" this.retrySchedule}}>
                    <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none"
                         stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                      <polyline points="23 4 23 10 17 10"/>
                      <path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/>
                    </svg>
                    Retry
                  </button>
                </div>

              {{! Bookings list }}
              {{else if this.scheduleBookings.length}}
                {{#each this.scheduleBookings as |booking|}}
                  <div class="rounded-2xl bg-white dark:bg-gray-900
                              border border-gray-100 dark:border-gray-700/50 shadow-sm p-5">
                    <pre class="text-xs text-gray-600 dark:text-gray-400 whitespace-pre-wrap">{{booking}}</pre>
                  </div>
                {{/each}}

              {{/if}}

            </div>

          {{! ══ LIVE MATCH TAB ══ }}
          {{else if (eq this.activeTab "live")}}
            <div class="space-y-4">

              {{! Section header }}
              <div class="flex items-center gap-2.5">
                <span class="relative flex h-3 w-3 shrink-0">
                  <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-rose-400 opacity-75"></span>
                  <span class="relative inline-flex rounded-full h-3 w-3 bg-rose-500"></span>
                </span>
                <h3 class="text-sm font-extrabold uppercase tracking-widest text-rose-500 dark:text-rose-400">Live Now</h3>
                <span class="ml-auto text-[11px] font-semibold text-gray-400 dark:text-gray-500">2 matches</span>
              </div>

              {{! ── Match Card 1 ── }}
              <div class="rounded-3xl overflow-hidden ring-1 ring-white/5 shadow-2xl shadow-black/50">

                {{! Tournament banner }}
                <div class="px-4 pt-4 pb-3 bg-gradient-to-br from-gray-900 via-slate-800 to-gray-900">
                  <div class="flex items-start justify-between gap-3">
                    <div class="flex-1 min-w-0">
                      <p class="text-[13px] font-extrabold text-white leading-snug">
                        Shahid Gazi Rahmatullah Khan Sriti Gold Cup Cricket Tournament
                      </p>
                      <p class="text-[11px] text-gray-400 mt-0.5 font-medium">Group Match / Match No.7</p>
                    </div>
                    <span class="shrink-0 flex items-center gap-1.5 px-2.5 py-1 rounded-full
                                 bg-rose-500/20 border border-rose-500/40">
                      <span class="w-1.5 h-1.5 rounded-full bg-rose-400 animate-pulse"></span>
                      <span class="text-[10px] font-bold text-rose-400 uppercase tracking-wider">Live</span>
                    </span>
                  </div>
                  <div class="flex items-center gap-1.5 mt-2.5 text-[11px] text-gray-500 font-medium">
                    {{lucideIcon "clock" size=14 class="shrink-0"}}
                    28.04.2025 &nbsp;·&nbsp; 10:00 AM
                  </div>
                </div>

                {{! Scores }}
                <div class="px-4 py-4 bg-gray-900">
                  <div class="flex items-stretch gap-2">

                    <div class="flex-1 flex items-center gap-3 px-3 py-3 rounded-2xl
                                bg-white/5 ring-1 ring-white/8">
                      <div class="w-12 h-12 rounded-xl shrink-0 overflow-hidden ring-1 ring-white/10
                                  bg-gradient-to-br from-green-900 to-emerald-800 flex items-center justify-center">
                        <svg class="w-8 h-8" viewBox="0 0 32 20" fill="none">
                          <ellipse cx="16" cy="10" rx="15" ry="8" fill="#166534" opacity="0.8"/>
                          <ellipse cx="16" cy="10" rx="5" ry="3" fill="#14532d"/>
                          <line x1="16" y1="2" x2="16" y2="18" stroke="#22c55e" stroke-width="0.5" opacity="0.4"/>
                        </svg>
                      </div>
                      <div>
                        <div class="flex items-baseline gap-1">
                          <span class="text-[28px] font-black text-white leading-none">124</span>
                          <span class="text-base font-bold text-gray-400 leading-none">-1</span>
                        </div>
                        <span class="text-[11px] text-gray-500 font-semibold">(14.1 ov)</span>
                      </div>
                    </div>

                    <div class="flex flex-col items-center justify-center gap-0.5 px-0.5">
                      <div class="w-px h-5 bg-gradient-to-b from-transparent to-gray-600"></div>
                      <span class="text-[11px] font-black text-gray-500">vs</span>
                      <div class="w-px h-5 bg-gradient-to-t from-transparent to-gray-600"></div>
                    </div>

                    <div class="flex-1 flex items-center gap-3 px-3 py-3 rounded-2xl
                                bg-white/5 ring-1 ring-white/8">
                      <div class="w-12 h-12 rounded-xl shrink-0 overflow-hidden ring-1 ring-white/10
                                  bg-gradient-to-br from-emerald-950 to-green-900 flex items-center justify-center">
                        <svg class="w-8 h-8" viewBox="0 0 32 20" fill="none">
                          <ellipse cx="16" cy="10" rx="15" ry="8" fill="#14532d" opacity="0.8"/>
                          <ellipse cx="16" cy="10" rx="5" ry="3" fill="#052e16"/>
                          <line x1="16" y1="2" x2="16" y2="18" stroke="#4ade80" stroke-width="0.5" opacity="0.4"/>
                        </svg>
                      </div>
                      <div>
                        <div class="flex items-baseline gap-1">
                          <span class="text-[28px] font-black text-white leading-none">185</span>
                          <span class="text-base font-bold text-gray-400 leading-none">-4</span>
                        </div>
                        <span class="text-[11px] text-gray-500 font-semibold">(20 ov)</span>
                      </div>
                    </div>
                  </div>

                  <div class="flex items-center justify-center gap-3 mt-3 py-2 rounded-xl bg-white/4 border border-white/5">
                    <span class="text-[11px] font-bold text-amber-400">CR: 6.0</span>
                    <span class="w-px h-3 bg-gray-600"></span>
                    <span class="text-[11px] font-bold text-emerald-400">RR: 7.6</span>
                  </div>
                </div>

                {{! Team names }}
                <div class="grid grid-cols-2 bg-gray-900 border-t border-white/5">
                  <div class="px-4 py-3 border-r border-white/5">
                    <p class="text-[12px] font-bold text-gray-200 leading-snug">
                      Atish Dipankar University of Science &amp; Technology Cricket Club
                    </p>
                    <span class="inline-flex items-center gap-1 mt-1.5 px-2 py-0.5 rounded-full
                                 bg-indigo-500/15 border border-indigo-500/25 text-[10px] font-bold text-indigo-400">
                      ● Batting
                    </span>
                  </div>
                  <div class="px-4 py-3 text-right">
                    <p class="text-[12px] font-bold text-gray-200 leading-snug">
                      BGMEA University of Science and Technology Cricket Club
                    </p>
                    <span class="inline-flex items-center gap-1 mt-1.5 px-2 py-0.5 rounded-full
                                 bg-rose-500/15 border border-rose-500/25 text-[10px] font-bold text-rose-400">
                      Bowled ●
                    </span>
                  </div>
                </div>

                <div class="flex items-center justify-between px-4 py-2.5
                            bg-gradient-to-r from-indigo-900/50 to-violet-900/40
                            border-t border-indigo-800/30">
                  <p class="text-[11px] font-semibold text-indigo-300">Need 62 runs in 35 balls</p>
                  <span class="text-[10px] font-bold text-violet-300 uppercase tracking-wide px-2 py-0.5
                               rounded-full bg-violet-500/20 border border-violet-500/30">2nd Inns</span>
                </div>
              </div>

              {{! ── Match Card 2 ── }}
              <div class="rounded-3xl overflow-hidden ring-1 ring-white/5 shadow-2xl shadow-black/50">

                <div class="px-4 pt-4 pb-3 bg-gradient-to-br from-emerald-950 via-gray-900 to-gray-900">
                  <div class="flex items-start justify-between gap-3">
                    <div class="flex-1 min-w-0">
                      <p class="text-[13px] font-extrabold text-white leading-snug">
                        Inter-University T20 Clash — Spring Edition 2025
                      </p>
                      <p class="text-[11px] text-gray-400 mt-0.5 font-medium">Semi Final</p>
                    </div>
                    <span class="shrink-0 flex items-center gap-1.5 px-2.5 py-1 rounded-full
                                 bg-emerald-500/20 border border-emerald-500/40">
                      <span class="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse"></span>
                      <span class="text-[10px] font-bold text-emerald-400 uppercase tracking-wider">Live</span>
                    </span>
                  </div>
                  <div class="flex items-center gap-1.5 mt-2.5 text-[11px] text-gray-500 font-medium">
                    {{lucideIcon "clock" size=14 class="shrink-0"}}
                    28.04.2025 &nbsp;·&nbsp; 2:00 PM
                  </div>
                </div>

                <div class="px-4 py-4 bg-gray-900">
                  <div class="flex items-stretch gap-2">
                    <div class="flex-1 flex items-center gap-3 px-3 py-3 rounded-2xl bg-white/5 ring-1 ring-white/8">
                      <div class="w-12 h-12 rounded-xl shrink-0 ring-1 ring-white/10
                                  bg-gradient-to-br from-teal-900 to-emerald-800 flex items-center justify-center">
                        <svg class="w-8 h-8" viewBox="0 0 32 20" fill="none">
                          <ellipse cx="16" cy="10" rx="15" ry="8" fill="#134e4a" opacity="0.8"/>
                          <ellipse cx="16" cy="10" rx="5" ry="3" fill="#042f2e"/>
                          <line x1="16" y1="2" x2="16" y2="18" stroke="#2dd4bf" stroke-width="0.5" opacity="0.4"/>
                        </svg>
                      </div>
                      <div>
                        <div class="flex items-baseline gap-1">
                          <span class="text-[28px] font-black text-white leading-none">87</span>
                          <span class="text-base font-bold text-gray-400 leading-none">-3</span>
                        </div>
                        <span class="text-[11px] text-gray-500 font-semibold">(11.3 ov)</span>
                      </div>
                    </div>

                    <div class="flex flex-col items-center justify-center gap-0.5 px-0.5">
                      <div class="w-px h-5 bg-gradient-to-b from-transparent to-gray-600"></div>
                      <span class="text-[11px] font-black text-gray-500">vs</span>
                      <div class="w-px h-5 bg-gradient-to-t from-transparent to-gray-600"></div>
                    </div>

                    <div class="flex-1 flex items-center gap-3 px-3 py-3 rounded-2xl bg-white/5 ring-1 ring-white/8">
                      <div class="w-12 h-12 rounded-xl shrink-0 ring-1 ring-white/10
                                  bg-gradient-to-br from-emerald-950 to-teal-950 flex items-center justify-center">
                        <svg class="w-8 h-8" viewBox="0 0 32 20" fill="none">
                          <ellipse cx="16" cy="10" rx="15" ry="8" fill="#064e3b" opacity="0.8"/>
                          <ellipse cx="16" cy="10" rx="5" ry="3" fill="#022c22"/>
                          <line x1="16" y1="2" x2="16" y2="18" stroke="#34d399" stroke-width="0.5" opacity="0.4"/>
                        </svg>
                      </div>
                      <div>
                        <div class="flex items-baseline gap-1">
                          <span class="text-[28px] font-black text-white leading-none">142</span>
                          <span class="text-base font-bold text-gray-400 leading-none">/8</span>
                        </div>
                        <span class="text-[11px] text-gray-500 font-semibold">(20 ov)</span>
                      </div>
                    </div>
                  </div>

                  <div class="flex items-center justify-center gap-3 mt-3 py-2 rounded-xl bg-white/4 border border-white/5">
                    <span class="text-[11px] font-bold text-amber-400">CR: 7.6</span>
                    <span class="w-px h-3 bg-gray-600"></span>
                    <span class="text-[11px] font-bold text-emerald-400">RR: 5.9</span>
                  </div>
                </div>

                <div class="grid grid-cols-2 bg-gray-900 border-t border-white/5">
                  <div class="px-4 py-3 border-r border-white/5">
                    <p class="text-[12px] font-bold text-gray-200 leading-snug">
                      North South University Cricket Club
                    </p>
                    <span class="inline-flex items-center gap-1 mt-1.5 px-2 py-0.5 rounded-full
                                 bg-indigo-500/15 border border-indigo-500/25 text-[10px] font-bold text-indigo-400">
                      ● Batting
                    </span>
                  </div>
                  <div class="px-4 py-3 text-right">
                    <p class="text-[12px] font-bold text-gray-200 leading-snug">
                      BRAC University Sports Club
                    </p>
                    <span class="inline-flex items-center gap-1 mt-1.5 px-2 py-0.5 rounded-full
                                 bg-rose-500/15 border border-rose-500/25 text-[10px] font-bold text-rose-400">
                      Bowled ●
                    </span>
                  </div>
                </div>

                <div class="flex items-center justify-between px-4 py-2.5
                            bg-gradient-to-r from-emerald-900/50 to-teal-900/40
                            border-t border-emerald-800/30">
                  <p class="text-[11px] font-semibold text-emerald-300">Need 56 runs in 51 balls</p>
                  <span class="text-[10px] font-bold text-teal-300 uppercase tracking-wide px-2 py-0.5
                               rounded-full bg-teal-500/20 border border-teal-500/30">2nd Inns</span>
                </div>
              </div>

            </div>

          {{! ══ POSTS TAB ══ }}
          {{else if (eq this.activeTab "posts")}}
            <div class="flex flex-col items-center justify-center py-24 text-center">
              <div class="w-20 h-20 mb-6 rounded-3xl
                          bg-gradient-to-br from-violet-100 to-fuchsia-100
                          dark:from-violet-900/40 dark:to-fuchsia-900/30
                          flex items-center justify-center">
                <svg class="w-10 h-10 text-violet-400 dark:text-violet-500" viewBox="0 0 24 24" fill="none"
                     stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
                </svg>
              </div>
              <p class="text-base font-bold text-gray-900 dark:text-white mb-1">No Posts Yet</p>
              <p class="text-sm text-gray-500 dark:text-gray-400">This facility hasn't posted anything yet.</p>
            </div>

          {{! ══ GALLERY TAB ══ }}
          {{else if (eq this.activeTab "gallery")}}
            {{#if this.hasPictures}}
              <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3 sm:gap-4">
                {{#each this.allGalleryImages as |img idx|}}
                  <div class="group relative aspect-square rounded-2xl overflow-hidden
                              bg-gray-100 dark:bg-gray-800
                              ring-1 ring-gray-200 dark:ring-gray-700
                              hover:ring-2 hover:ring-indigo-400/60 dark:hover:ring-indigo-500/50
                              transition-all duration-300 shadow-sm hover:shadow-lg">
                    <img src={{img}} alt="Gallery photo"
                         class="w-full h-full object-cover transition-transform duration-500 group-hover:scale-110" />
                    <div class="absolute inset-0 bg-gradient-to-t from-black/40 to-transparent
                                opacity-0 group-hover:opacity-100 transition-opacity duration-300">
                    </div>
                    <div class="absolute bottom-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity duration-300">
                      <div class="w-7 h-7 rounded-lg bg-white/20 backdrop-blur-sm
                                  flex items-center justify-center">
                        <svg class="w-3.5 h-3.5 text-white" viewBox="0 0 24 24" fill="none"
                             stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                          <path d="M15 3h6v6M9 21H3v-6M21 3l-7 7M3 21l7-7"/>
                        </svg>
                      </div>
                    </div>
                  </div>
                {{/each}}
              </div>
            {{else}}
              <div class="flex flex-col items-center justify-center py-24 text-center">
                <div class="w-20 h-20 mb-6 rounded-3xl
                            bg-gradient-to-br from-fuchsia-100 to-pink-100
                            dark:from-fuchsia-900/40 dark:to-pink-900/30
                            flex items-center justify-center">
                  {{lucideIcon "image" size=40 class="text-fuchsia-400 dark:text-fuchsia-500"}}
                </div>
                <p class="text-base font-bold text-gray-900 dark:text-white mb-1">No Gallery Photos</p>
                <p class="text-sm text-gray-500 dark:text-gray-400">No photos have been uploaded yet.</p>
              </div>
            {{/if}}

          {{/if}}
          {{! end tab content }}

        </div>
        {{! end max-w content }}

      {{/if}}
      {{! end facility detail block }}

    </div>

    {{! ══ BOOKING CALENDAR MODAL ══ }}
    {{#if this.showBookingModal}}
      <div class="fixed inset-0 z-50 flex flex-col overflow-hidden">

        {{! Backdrop }}
        <div class="absolute inset-0 bg-gray-950/50 backdrop-blur-md"></div>

        {{! Modal shell }}
        <div class="relative flex flex-col w-full h-full max-w-5xl mx-auto my-4 sm:my-8 rounded-3xl overflow-hidden shadow-2xl
                    bg-white dark:bg-gray-900 ring-1 ring-gray-200/50 dark:ring-white/10">

          {{! ── Header bar ── }}
          <div class="flex items-center gap-3 px-5 py-4
                      bg-gradient-to-r from-indigo-600 via-violet-600 to-purple-700
                      dark:from-indigo-700 dark:via-violet-700 dark:to-purple-800">

            {{! Calendar icon }}
            <div class="flex-shrink-0 w-9 h-9 rounded-xl bg-white/20 flex items-center justify-center">
              {{lucideIcon "calendar" size=20 class="text-white"}}
            </div>

            {{! Month label }}
            <h2 class="flex-1 text-lg font-extrabold text-white tracking-tight">
              {{this.bookingMonthLabel}}
            </h2>

            {{! Nav + close }}
            <div class="flex items-center gap-1.5">
              <button type="button"
                      class="w-9 h-9 rounded-xl bg-white/15 hover:bg-white/30
                             text-white flex items-center justify-center
                             transition-colors duration-150"
                      {{on "click" this.calPrev}}>
                {{lucideIcon "chevron-left" size=16}}
              </button>

              <button type="button"
                      class="px-3 h-9 rounded-xl bg-white/15 hover:bg-white/30
                             text-white text-xs font-bold
                             transition-colors duration-150"
                      {{on "click" this.calToday}}>
                Today
              </button>

              <button type="button"
                      class="w-9 h-9 rounded-xl bg-white/15 hover:bg-white/30
                             text-white flex items-center justify-center
                             transition-colors duration-150"
                      {{on "click" this.calNext}}>
                {{lucideIcon "chevron-right" size=16}}
              </button>

              <div class="w-px h-6 bg-white/20 mx-1"></div>

              <button type="button"
                      class="w-9 h-9 rounded-xl bg-white/15 hover:bg-rose-500/80
                             text-white flex items-center justify-center
                             transition-colors duration-150"
                      {{on "click" this.closeBookingModal}}>
                {{lucideIcon "x" size=16}}
              </button>
            </div>
          </div>

          {{! ── Hint strip ── }}
          <div class="px-5 py-2 bg-indigo-50 dark:bg-indigo-950/40
                      border-b border-indigo-100 dark:border-indigo-900/50
                      flex items-center gap-2">
            {{lucideIcon "info" size=14 class="text-indigo-500 dark:text-indigo-400 shrink-0"}}
            <p class="text-xs text-indigo-600 dark:text-indigo-400 font-medium">
              Click any date to select a booking time slot
            </p>
          </div>

          {{! ── TUI Calendar body ── }}
          <div class="relative flex-1 overflow-hidden">
            <div class="absolute inset-0 p-4"
                 {{tuiCalendarModifier
                   view="month"
                   calendars=this.emptyArray
                   events=this.emptyArray
                   usageStatistics=false
                   useFormPopup=false
                   useDetailPopup=false
                   theme=this.bookingCalTheme
                   onReady=this.onBookingCalReady}}></div>

            {{! ── Time-slot popup — fixed full-viewport overlay ── }}
            {{#if this.showTimeSlotPopup}}
              <div class="fixed inset-0 z-50 flex items-end sm:items-center justify-center"
                   role="dialog" aria-modal="true">

                {{! Backdrop }}
                <div class="absolute inset-0 bg-black/60 backdrop-blur-sm"
                     {{on "click" this.closeTimeSlot}}></div>

                {{! Panel: bottom-sheet on mobile, centered card on sm+ }}
                <div class="relative z-10 w-full sm:max-w-lg lg:max-w-xl
                            bg-white dark:bg-gray-900
                            rounded-t-3xl sm:rounded-3xl
                            shadow-2xl ring-1 ring-gray-200 dark:ring-white/10
                            max-h-[92vh] sm:max-h-[88vh] overflow-y-auto">

                  {{! Drag handle — mobile only }}
                  <div class="sm:hidden flex justify-center pt-3 pb-1">
                    <div class="w-10 h-1 rounded-full bg-gray-300 dark:bg-gray-600"></div>
                  </div>

                  {{! Sticky gradient header }}
                  <div class="sticky top-0 z-10
                              bg-gradient-to-r from-indigo-600 via-violet-600 to-purple-700
                              dark:from-indigo-700 dark:via-violet-700 dark:to-purple-800
                              px-5 pt-4 pb-5 sm:pt-5 sm:pb-6">
                    <div class="flex items-start justify-between">
                      <div>
                        <div class="flex items-center gap-1.5 mb-1">
                          <span class="w-5 h-1.5 rounded-full bg-white"></span>
                          <span class="w-5 h-1.5 rounded-full {{if (eq this.bookingStep 2) 'bg-white' 'bg-white/30'}}"></span>
                        </div>
                        <p class="text-[11px] font-semibold text-indigo-200 uppercase tracking-widest">
                          {{#if (eq this.bookingStep 1)}}Select Time{{else}}Payment{{/if}}
                        </p>
                        <h3 class="text-xl font-extrabold text-white leading-tight mt-0.5">
                          {{this.selectedDateDisplay}}
                        </h3>
                      </div>
                      <button type="button"
                              class="w-8 h-8 rounded-xl bg-white/15 hover:bg-white/30
                                     text-white flex items-center justify-center
                                     transition-colors duration-150 shrink-0"
                              {{on "click" this.closeTimeSlot}}>
                        {{lucideIcon "x" size=16}}
                      </button>
                    </div>
                  </div>

                  {{! ══ STEP 1 — Time Selection ══ }}
                  {{#if (eq this.bookingStep 1)}}
                    <div class="px-4 sm:px-6 py-5 space-y-5">

                      {{! Slot duration chips }}
                      {{#if this.allRentOptions.length}}
                        <div>
                          <p class="text-[10px] font-bold uppercase tracking-widest
                                    text-gray-400 dark:text-gray-500 mb-2.5">Slot Duration</p>
                          <div class="flex flex-wrap gap-2">
                            {{#each this.allRentOptions as |opt idx|}}
                              <button type="button"
                                      class="flex items-center gap-2 px-4 py-2.5 rounded-2xl border-2
                                             transition-all duration-150
                                             {{if (eq idx this.selectedRentIdx)
                                               'border-indigo-500 bg-indigo-50 dark:bg-indigo-950/50 shadow-md shadow-indigo-500/20'
                                               'border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800
                                                hover:border-indigo-300 dark:hover:border-indigo-600'}}"
                                      {{on "click" (fn this.selectRentOpt idx)}}>
                                {{lucideIcon "clock" size=14
                                  class=(if (eq idx this.selectedRentIdx) "text-indigo-500" "text-gray-400")}}
                                <span class="text-sm font-bold
                                             {{if (eq idx this.selectedRentIdx)
                                               'text-indigo-600 dark:text-indigo-400'
                                               'text-gray-700 dark:text-gray-300'}}">
                                  {{opt.time_slot}} hr
                                </span>
                                <span class="text-sm font-extrabold
                                             {{if (eq idx this.selectedRentIdx)
                                               'text-emerald-600 dark:text-emerald-400'
                                               'text-gray-400 dark:text-gray-500'}}">
                                  ৳{{opt.price}}
                                </span>
                              </button>
                            {{/each}}
                          </div>
                        </div>
                      {{/if}}

                      {{! ── Analog clock picker ── }}
                      <div class="rounded-2xl overflow-hidden border border-gray-700/50 bg-gray-900 shadow-xl">

                        {{! ── START / END tab selector ── }}
                        <div class="grid grid-cols-2 border-b border-gray-700/50">
                          <button type="button"
                                  class="flex flex-col items-center gap-1 py-4 px-3 transition-all duration-200
                                         border-b-2 relative
                                         {{if (eq this.activeTimeEdit "from")
                                           'border-indigo-500 bg-indigo-950/60'
                                           'border-transparent hover:bg-gray-800/60'}}"
                                  {{on "click" (fn this.setActiveTimeEdit "from")}}>
                            <div class="flex items-center gap-1.5">
                              <span class="w-2 h-2 rounded-full
                                           {{if (eq this.activeTimeEdit "from") 'bg-indigo-400' 'bg-gray-600'}}"></span>
                              <span class="text-[10px] font-bold uppercase tracking-widest
                                           {{if (eq this.activeTimeEdit "from") 'text-indigo-300' 'text-gray-500'}}">
                                Start Time
                              </span>
                            </div>
                            <span class="text-2xl font-extrabold tabular-nums leading-none
                                         {{if (eq this.activeTimeEdit "from") 'text-white' 'text-gray-500'}}">
                              {{this.formattedFromTime}}
                            </span>
                          </button>
                          <button type="button"
                                  class="flex flex-col items-center gap-1 py-4 px-3 transition-all duration-200
                                         border-b-2 relative
                                         {{if (eq this.activeTimeEdit "to")
                                           'border-violet-500 bg-violet-950/60'
                                           'border-transparent hover:bg-gray-800/60'}}"
                                  {{on "click" (fn this.setActiveTimeEdit "to")}}>
                            <div class="flex items-center gap-1.5">
                              <span class="w-2 h-2 rounded-full
                                           {{if (eq this.activeTimeEdit "to") 'bg-violet-400' 'bg-gray-600'}}"></span>
                              <span class="text-[10px] font-bold uppercase tracking-widest
                                           {{if (eq this.activeTimeEdit "to") 'text-violet-300' 'text-gray-500'}}">
                                End Time
                              </span>
                            </div>
                            <span class="text-2xl font-extrabold tabular-nums leading-none
                                         {{if (eq this.activeTimeEdit "to") 'text-white' 'text-gray-500'}}">
                              {{this.formattedToTime}}
                            </span>
                          </button>
                        </div>

                        {{! ── Clock body: digital + analog ── }}
                        <div class="flex flex-col sm:flex-row">

                          {{! Digital H:M + AM/PM }}
                          <div class="flex flex-col items-center justify-center gap-5 px-6 py-5 sm:w-52 shrink-0">

                            {{! H : M boxes }}
                            <div class="flex items-center gap-2.5">
                              <button type="button"
                                      class="w-[4.5rem] h-[4.5rem] rounded-2xl text-5xl font-extrabold
                                             tabular-nums transition-all duration-200 leading-none
                                             {{if (eq this.clockMode "hour")
                                               (if (eq this.activeTimeEdit "from")
                                                 'bg-indigo-600 text-white shadow-lg shadow-indigo-500/40 scale-105'
                                                 'bg-violet-600 text-white shadow-lg shadow-violet-500/40 scale-105')
                                               'bg-gray-800 text-gray-300 hover:bg-gray-700'}}"
                                      {{on "click" (fn this.setClockMode "hour")}}>
                                {{this.activeDisplayHour}}
                              </button>
                              <span class="text-4xl font-extrabold text-gray-600 select-none leading-none">:</span>
                              <button type="button"
                                      class="w-[4.5rem] h-[4.5rem] rounded-2xl text-5xl font-extrabold
                                             tabular-nums transition-all duration-200 leading-none
                                             {{if (eq this.clockMode "minute")
                                               (if (eq this.activeTimeEdit "from")
                                                 'bg-indigo-600 text-white shadow-lg shadow-indigo-500/40 scale-105'
                                                 'bg-violet-600 text-white shadow-lg shadow-violet-500/40 scale-105')
                                               'bg-gray-800 text-gray-300 hover:bg-gray-700'}}"
                                      {{on "click" (fn this.setClockMode "minute")}}>
                                {{this.activeDisplayMinute}}
                              </button>
                            </div>

                            {{! AM / PM toggle }}
                            <div class="flex w-full rounded-xl overflow-hidden border border-gray-700/80">
                              <button type="button"
                                      class="flex-1 py-2.5 text-sm font-bold transition-all duration-150
                                             {{if (eq this.activePeriod "AM")
                                               (if (eq this.activeTimeEdit "from")
                                                 'bg-indigo-600 text-white'
                                                 'bg-violet-600 text-white')
                                               'bg-gray-800 text-gray-500 hover:bg-gray-700 hover:text-gray-300'}}"
                                      {{on "click" (fn this.setClockPeriod "AM")}}>
                                AM
                              </button>
                              <button type="button"
                                      class="flex-1 py-2.5 text-sm font-bold transition-all duration-150
                                             {{if (eq this.activePeriod "PM")
                                               (if (eq this.activeTimeEdit "from")
                                                 'bg-indigo-600 text-white'
                                                 'bg-violet-600 text-white')
                                               'bg-gray-800 text-gray-500 hover:bg-gray-700 hover:text-gray-300'}}"
                                      {{on "click" (fn this.setClockPeriod "PM")}}>
                                PM
                              </button>
                            </div>
                          </div>

                          {{! Dividers }}
                          <div class="hidden sm:block w-px bg-gray-700/50 self-stretch"></div>
                          <div class="sm:hidden h-px bg-gray-700/50 w-full"></div>

                          {{! SVG Analog Clock Face }}
                          <div class="flex items-center justify-center p-5 sm:flex-1">
                            <svg viewBox="0 0 220 220"
                                 class="w-full max-w-[200px] sm:max-w-[215px] select-none cursor-pointer">

                              {{! Face background }}
                              <circle cx="110" cy="110" r="107" fill="#080f1c" />
                              <circle cx="110" cy="110" r="107" fill="none" stroke="#1e293b" stroke-width="2" />

                              {{! Subtle tick marks }}
                              {{#each this.clockHourData as |item|}}
                                <line
                                  x1={{item.x}} y1={{item.y}}
                                  x2={{item.x}} y2={{item.y}}
                                  stroke="#1e3a5f" stroke-width="1" />
                              {{/each}}

                              {{! Clock hand }}
                              {{#if this.activeTime}}
                                <line x1="110" y1="110"
                                      x2={{this.clockHandX}} y2={{this.clockHandY}}
                                      stroke={{this.clockAccent}}
                                      stroke-width="2.5" stroke-linecap="round" />
                                {{! Outer glow ring }}
                                <circle cx={{this.clockHandX}} cy={{this.clockHandY}}
                                        r="24" fill={{this.clockAccent}} opacity="0.15" />
                                {{! Filled highlight }}
                                <circle cx={{this.clockHandX}} cy={{this.clockHandY}}
                                        r="19" fill={{this.clockAccent}} />
                              {{/if}}

                              {{! Center pivot }}
                              <circle cx="110" cy="110" r="5" fill={{this.clockAccent}} />

                              {{! Hour numbers }}
                              {{#if (eq this.clockMode "hour")}}
                                {{#each this.clockHourData as |item|}}
                                  <g {{on "click" (fn this.selectClockHour item.val)}}
                                     style="cursor:pointer">
                                    <circle cx={{item.x}} cy={{item.y}} r="21"
                                            fill={{if (eq item.val this.activeHour12) this.clockAccent "transparent"}} />
                                    <text x={{item.x}} y={{item.y}}
                                          text-anchor="middle" dominant-baseline="central"
                                          font-size="14" font-weight="700"
                                          fill={{if (eq item.val this.activeHour12) "#ffffff" "#64748b"}}>
                                      {{item.val}}
                                    </text>
                                  </g>
                                {{/each}}
                              {{/if}}

                              {{! Minute numbers }}
                              {{#if (eq this.clockMode "minute")}}
                                {{#each this.clockMinuteData as |item|}}
                                  <g {{on "click" (fn this.selectClockMinute item.val)}}
                                     style="cursor:pointer">
                                    <circle cx={{item.x}} cy={{item.y}} r="21"
                                            fill={{if (eq item.val this.activeMinute) this.clockAccent "transparent"}} />
                                    <text x={{item.x}} y={{item.y}}
                                          text-anchor="middle" dominant-baseline="central"
                                          font-size="12" font-weight="700"
                                          fill={{if (eq item.val this.activeMinute) "#ffffff" "#64748b"}}>
                                      {{item.label}}
                                    </text>
                                  </g>
                                {{/each}}
                              {{/if}}

                            </svg>
                          </div>
                        </div>

                        {{! Duration footer }}
                        {{#if this.bookingTimeValid}}
                          <div class="flex items-center gap-3 px-5 py-3 border-t border-gray-700/50
                                      bg-emerald-950/40">
                            {{lucideIcon "clock" size=14 class="text-emerald-400 shrink-0"}}
                            <span class="text-xs font-semibold text-gray-400">Duration</span>
                            <span class="text-sm font-extrabold text-emerald-400">
                              {{this.bookingDurationHours}} hr
                            </span>
                            <span class="text-gray-600 text-xs">·</span>
                            <span class="text-xs text-gray-400">
                              {{this.formattedFromTime}} → {{this.formattedToTime}}
                            </span>
                          </div>
                        {{/if}}

                      </div>

                      {{! Validation error }}
                      {{#if this.bookingFromTime}}
                        {{#unless this.bookingTimeValid}}
                          <p class="text-[11px] font-medium text-rose-500 dark:text-rose-400
                                    flex items-center gap-1.5 -mt-2">
                            {{lucideIcon "alert-circle" size=14 class="shrink-0"}}
                            End time must be after start time
                          </p>
                        {{/unless}}
                      {{/if}}

                      {{! Amount summary }}
                      {{#if this.bookingTimeValid}}
                        <div class="flex items-center justify-between px-5 py-4 rounded-2xl
                                    bg-gradient-to-r from-emerald-50 to-teal-50
                                    dark:from-emerald-950/40 dark:to-teal-950/40
                                    border border-emerald-100 dark:border-emerald-800/50">
                          <div>
                            <p class="text-[10px] font-bold uppercase tracking-wider
                                      text-emerald-600 dark:text-emerald-400 mb-0.5">Estimated Total</p>
                            <p class="text-xs text-emerald-600/70 dark:text-emerald-500">
                              {{this.bookingDurationHours}} hr × ৳1500
                            </p>
                          </div>
                          <span class="text-3xl font-extrabold text-emerald-600 dark:text-emerald-400">
                            ৳{{this.bookingAmount}}
                          </span>
                        </div>
                      {{/if}}

                      {{! Action buttons }}
                      <div class="flex gap-3">
                        <button type="button"
                                class="flex-1 py-3.5 rounded-2xl text-sm font-bold
                                       bg-gray-100 dark:bg-gray-800
                                       text-gray-600 dark:text-gray-300
                                       hover:bg-gray-200 dark:hover:bg-gray-700
                                       transition-colors duration-150"
                                {{on "click" this.closeTimeSlot}}>
                          Cancel
                        </button>
                        <button type="button"
                                disabled={{unless this.bookingTimeValid true}}
                                class="flex-1 py-3.5 rounded-2xl text-sm font-bold text-white
                                       bg-gradient-to-r from-indigo-600 to-violet-600
                                       hover:from-indigo-500 hover:to-violet-500
                                       shadow-lg shadow-indigo-500/30
                                       transition-all duration-150
                                       disabled:opacity-40 disabled:cursor-not-allowed disabled:shadow-none"
                                {{on "click" this.goToPaymentStep}}>
                          Continue →
                        </button>
                      </div>

                    </div>
                  {{/if}}

                  {{! ══ STEP 2 — Payment ══ }}
                  {{#if (eq this.bookingStep 2)}}
                    <div class="px-4 sm:px-6 py-5 space-y-4">

                      {{! Booking summary banner }}
                      <div class="flex items-center justify-between gap-3 px-4 py-3.5 rounded-2xl
                                  bg-indigo-50 dark:bg-indigo-950/40
                                  border border-indigo-100 dark:border-indigo-800/50">
                        <div class="min-w-0">
                          <p class="text-[10px] font-bold text-indigo-400 uppercase tracking-wider mb-0.5">Booking</p>
                          <p class="text-xs font-semibold text-indigo-700 dark:text-indigo-300 truncate">
                            {{this.selectedDateDisplay}}
                          </p>
                          <p class="text-xs text-indigo-500 dark:text-indigo-400 font-medium mt-0.5">
                            {{this.formattedFromTime}} → {{this.formattedToTime}}
                          </p>
                        </div>
                        <div class="text-right shrink-0">
                          <span class="text-2xl font-extrabold text-indigo-700 dark:text-indigo-300">
                            ৳{{this.bookingAmount}}
                          </span>
                        </div>
                      </div>

                      {{! Payment method picker }}
                      <PaymentMethodPicker
                        @selected={{this.selectedPaymentMethod}}
                        @onChange={{this.selectPaymentMethod}}
                        @disabled={{this.isBookingSubmitting}}
                      />

                      {{! Optional note }}
                      <div>
                        <label class="block text-[10px] font-bold uppercase tracking-widest
                                      text-gray-400 dark:text-gray-500 mb-1.5">
                          Note (Optional)
                        </label>
                        <textarea
                          rows="2"
                          placeholder="Any special request for the facility…"
                          value={{this.bookingUserNote}}
                          {{on "input" this.updateBookingNote}}
                          class="w-full px-3.5 py-3 rounded-xl text-sm resize-none
                                 bg-gray-50 dark:bg-gray-800
                                 border border-gray-200 dark:border-gray-700
                                 text-gray-900 dark:text-white
                                 placeholder:text-gray-400 dark:placeholder:text-gray-600
                                 focus:outline-none focus:ring-2 focus:ring-indigo-500/50 focus:border-indigo-500
                                 transition-colors duration-150"
                        ></textarea>
                      </div>

                      {{! Action buttons }}
                      <div class="flex gap-3">
                        <button type="button"
                                disabled={{this.isBookingSubmitting}}
                                class="flex-1 py-3.5 rounded-2xl text-sm font-bold
                                       bg-gray-100 dark:bg-gray-800
                                       text-gray-600 dark:text-gray-300
                                       hover:bg-gray-200 dark:hover:bg-gray-700
                                       disabled:opacity-50 disabled:cursor-not-allowed
                                       transition-colors duration-150"
                                {{on "click" this.goBackToTimeStep}}>
                          ← Back
                        </button>
                        <button type="button"
                                disabled={{unless this.selectedPaymentMethod true}}
                                class="flex-1 py-3.5 rounded-2xl text-sm font-bold text-white
                                       bg-gradient-to-r from-emerald-600 to-teal-600
                                       hover:from-emerald-500 hover:to-teal-500
                                       shadow-lg shadow-emerald-500/30
                                       transition-all duration-150
                                       disabled:opacity-40 disabled:cursor-not-allowed disabled:shadow-none"
                                {{on "click" this.submitBooking}}>
                          {{#if this.isBookingSubmitting}}
                            Confirming…
                          {{else}}
                            Confirm Booking
                          {{/if}}
                        </button>
                      </div>

                    </div>
                  {{/if}}

                </div>
              </div>
            {{/if}}
            {{! end time-slot popup }}

          </div>
          {{! end calendar body }}

        </div>
        {{! end modal shell }}

      </div>
    {{/if}}
    {{! end booking modal }}

    {{#if this.showEditModal}}
      <FacilityEditModal
        @facility={{this.facility}}
        @onClose={{this.closeEditModal}}
        @onSave={{this.onEditSaved}}
      />
    {{/if}}

  </template>
}
