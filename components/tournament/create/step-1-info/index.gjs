import Component from '@glimmer/component';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { action } from '@ember/object';
import { eq } from 'ember-truth-helpers';
import { tracked } from '@glimmer/tracking';

import config from 'spordium/config/environment';
import CoverPhoto from './cover-photo';
import SportSelector from './sport-selector';
import ScheduleSection from './schedule-section';
import PrizeSection from './prize-section';
import TeamRegistration from './team-registration';
import LocationPicker from 'spordium/components/auth/signup/LocationPicker';

const TOURNAMENT_TYPES = [
  { key: 'amature', label: 'Amature' },
  { key: 'semi-professional', label: 'Semi professional' },
  { key: 'semiProfessional', label: 'Semi professional' },
  { key: 'professional', label: 'Professional' },
  { key: 'intermidiate', label: 'Intermediate' },
  { key: 'international', label: 'International' },
  { key: 'schoolLevel', label: 'School level' },
  { key: 'collegeOrUniversityLevel', label: 'College or university level' },
  { key: 'corporate', label: 'Corporate' },
  { key: 'friendlyOrExhibition', label: 'Friendly or exhibition' },
  { key: 'charityOrFundraising', label: 'Charity or fundraising' },
  { key: 'openTournament', label: 'Open tournament' },
  { key: 'communityOrLocalClub', label: 'Community or local club' },
];

// location helpers
async function reverseGeocode(lat, lng, apiKey) {
  const res = await fetch(`https://maps.googleapis.com/maps/api/geocode/json?latlng=${lat},${lng}&key=${apiKey}`);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const data = await res.json();
  if (data.status !== 'OK' || !data.results.length) throw new Error('No results');

  const components = data.results.flatMap((r) => r.address_components);
  const find = (type) => components.find((c) => c.types.includes(type));
  const country = find('country');
  const state = find('administrative_area_level_1');
  const city = find('locality') || find('administrative_area_level_2');

  return {
    lat,
    lng,
    country: country?.long_name || '',
    countryCode: country?.short_name || '',
    state: state?.long_name || '',
    city: city?.long_name || '',
    formattedAddress: data.results[0].formatted_address,
  };
}

function emptyLocation() {
  return {
    lat: null,
    lng: null,
    country: '',
    countryCode: '',
    state: '',
    city: '',
    formattedAddress: '',
  };
}

async function fetchPlaceDetails(placeId, apiKey) {
  const url = `https://places.googleapis.com/v1/places/${placeId}?fields=id,displayName,location,addressComponents,formattedAddress&key=${apiKey}`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const data = await res.json();

  const components = data.addressComponents || [];
  const find = (type) => components.find((c) => c.types.includes(type));
  const country = find('country');
  const state = find('administrative_area_level_1');
  const city = find('locality') || find('administrative_area_level_2');

  return {
    lat: data.location?.latitude || null,
    lng: data.location?.longitude || null,
    country: country?.longText || '',
    countryCode: country?.shortText || '',
    state: state?.longText || '',
    city: city?.longText || '',
    formattedAddress: data.formattedAddress || '',
  };
}

function debounce(fn, delay) {
  let timer;
  return function (...args) {
    clearTimeout(timer);
    timer = setTimeout(() => fn.apply(this, args), delay);
  };
}

// @arg {Object}   data              — wizard shared data object (API shape)
// @arg {Function} onUpdate          — (key, value) => void
// @arg {Function} onPhotoUpload     — (file) => Promise<{ previewUrl, objectToken }>
// @arg {Function} onQrUpload        — (file) => Promise<{ previewUrl, objectToken }>
export default class TournamentStep1 extends Component {
  get d() {
    return this.args.data ?? {};
  }

  get tournamentTypes() {
    return TOURNAMENT_TYPES;
  }

  @action onInput(key, e) {
    this.args.onUpdate(key, e.target.value);
  }

  @action selectSport(sportKey) {
    this.args.onUpdate('tournament_sport', sportKey);
  }

  @action selectTournamentType(key) {
    this.args.onUpdate('tournament_type', key);
  }

  @action onPrizesChange(updatedPrizes) {
    if (updatedPrizes?.tournament_prize?.length) {
      this.args.onUpdate('tournament_prize', updatedPrizes.tournament_prize);
    }

    if (updatedPrizes?.delete_prizes?.length) {
      this.args.onUpdate('delete_prizes', updatedPrizes.delete_prizes);
    }
  }

  @action onPrizesDelete(prizeId) {
    this.args.onUpdate('delete_prizes', [...this.d.delete_prizes, prizeId]);
  }

  get coverPhotoUrl() {
    const v = this.d.tournament_logo;
    if (!v) return null;
    if (v.startsWith('data:')) return v;
    return `https://ag-khela.s3.ap-south-1.amazonaws.com/${v}`;
  }

  @action async onPhotoUpload(base64) {
    const data = {
      logo_image: base64,
      logo_extension: 'jpg',
    };
    this.args.onUpdate('upload_tournament_logo', data);
    this.args.onUpdate('tournament_logo', base64);
  }

  get startDate() {
    return this.d.tournament_start_date?.substring(0, 10) ?? '';
  }

  get registrationDeadline() {
    return this.d.tournament_team_registration_end_date?.substring(0, 10) ?? '';
  }

  // ── Location ──────────────────────────────────────────────────────────────
  @tracked _addressOverride = null;

  get address() {
    return this._addressOverride ?? this.args.data.tournament_location?.address ?? '';
  }

  @tracked placeSuggestions = [];
  @tracked showPlaces = false;
  @tracked placesLoading = false;

  @action
  updateField(field, event) {
    if (field === 'address') {
      this._addressOverride = event.target.value;
      this._fetchPlaces(event.target.value);
    }
  }

  @action
  async handleLocationSelect({ lat, lng, address }) {
    try {
      const loc = await reverseGeocode(lat, lng, config.APP.GOOGLE_MAPS_API_KEY);
      this._applyLocation({ ...loc, formattedAddress: address });
    } catch (err) {
      console.error('Reverse geocode error:', err);
      this._applyLocation({
        ...emptyLocation(),
        lat,
        lng,
        formattedAddress: address,
      });
    }
    this.placeSuggestions = [];
    this.showPlaces = false;
  }

  @action
  async selectPlace(suggestion) {
    try {
      const loc = await fetchPlaceDetails(suggestion.placeId, config.APP.GOOGLE_MAPS_API_KEY);
      this._applyLocation({ ...loc, formattedAddress: suggestion.description });
    } catch (err) {
      console.error('Place details error:', err);
      this.address = suggestion.description;
    }
    this.placeSuggestions = [];
    this.showPlaces = false;
  }

  _fetchPlaces = debounce(async function (input) {
    if (!input || input.length < 2) {
      this.placeSuggestions = [];
      this.showPlaces = false;
      return;
    }
    this.placesLoading = true;
    try {
      const res = await fetch('https://places.googleapis.com/v1/places:autocomplete', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': config.APP.GOOGLE_MAPS_API_KEY,
          'X-Goog-FieldMask': 'suggestions.placePrediction.text,suggestions.placePrediction.placeId',
        },
        body: JSON.stringify({ input, includeQueryPredictions: false }),
      });
      if (!res.ok) throw new Error(`Places API ${res.status}`);
      const data = await res.json();
      this.placeSuggestions = (data?.suggestions ?? [])
        .filter((s) => s.placePrediction)
        .map((s) => ({
          description: s.placePrediction.text?.text ?? '',
          placeId: s.placePrediction.placeId,
          mainText: s.placePrediction.text?.text ?? '',
        }));
      this.showPlaces = this.placeSuggestions.length > 0;
    } catch (err) {
      console.error('Places API error:', err);
      this.placeSuggestions = [];
      this.showPlaces = false;
    } finally {
      this.placesLoading = false;
    }
  }, 400);

  _applyLocation(loc) {
    if (loc.formattedAddress) {
      this._addressOverride = loc.formattedAddress; // ← tracked override update
    }

    const stateWithCountry = loc.state && loc.country ? `${loc.state}, ${loc.country}` : loc.country || loc.state || '';

    this.args.onUpdate('tournament_location', {
      address: loc.formattedAddress || '',
      state: stateWithCountry,
      country: loc.country || '',
      city: loc.city || '',
    });
    this.args.onUpdate('tournament_latitude', loc.lat);
    this.args.onUpdate('tournament_longtitude', loc.lng);
  }

  <template>
    <div class="space-y-8">
      <CoverPhoto @coverPhotoPreview={{this.coverPhotoUrl}} @onPhotoUpload={{this.onPhotoUpload}} />
      <div>
        <h2 class="text-lg font-bold text-gray-900 dark:text-white">Tournament Info</h2>
        <p class="text-sm text-gray-500 dark:text-gray-400 mt-0.5">
          Basic details about your tournament
        </p>
      </div>

      <SportSelector @selected={{this.d.tournament_sport}} @onChange={{this.selectSport}} />

      <div>
        <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
          Tournament Name
          <span class="text-red-500">*</span>
        </label>
        <input
          type="text"
          value={{this.d.tournament_name}}
          placeholder="e.g. Spordium Premier League 2025"
          maxlength="120"
          {{on "input" (fn this.onInput "tournament_name")}}
          class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>

      <div>
        <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
          Season
          <span class="text-red-500">*</span>
        </label>
        <input
          type="text"
          value={{this.d.tornament_season}}
          placeholder="e.g. 2025, Season 3, Summer 2025"
          maxlength="60"
          {{on "input" (fn this.onInput "tornament_season")}}
          class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>

      <div>
        <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
          Tournament Type
          <span class="text-red-500">*</span>
        </label>
        <div class="flex gap-2 flex-wrap">
          {{#each this.tournamentTypes as |t|}}
            <button
              type="button"
              {{on "click" (fn this.selectTournamentType t.key)}}
              class="px-4 py-2.5 text-sm font-medium rounded-xl border-2 transition-all text-center
                {{if (eq this.d.tournament_type t.key) 'border-blue-500 bg-blue-50 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300' 'border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300 hover:border-blue-300'}}"
            >
              {{t.label}}
            </button>
          {{/each}}
        </div>
      </div>

      {{! location }}
      <div>
        <label for="address" class="block text-xs font-semibold text-gray-500 dark:text-gray-400 mb-1.5 uppercase tracking-wide">
          Tournament Location
          <span class="text-rose-400">*</span>
        </label>
        <div class="flex gap-2">
          <div class="relative flex-1">
            <span class="absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none">
              <svg class="w-4 h-4 text-gray-400 dark:text-gray-500" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" />
              </svg>
            </span>
            <input
              required
              type="text"
              id="address"
              name="address"
              value={{this.address}}
              {{on "input" (fn this.updateField "address")}}
              autocomplete="off"
              placeholder="Search for an address…"
              class="w-full pl-10 pr-9 py-2.5 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 text-gray-900 dark:text-gray-100 placeholder-gray-400 dark:placeholder-gray-600 text-sm focus:outline-none focus:ring-2 focus:ring-rose-400/50 focus:border-rose-400 dark:focus:border-rose-500 transition-all"
            />

            {{#if this.placesLoading}}
              <span class="absolute right-3 top-1/2 -translate-y-1/2">
                <svg class="w-4 h-4 text-indigo-500 animate-spin" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"></path>
                </svg>
              </span>
            {{/if}}

            {{#if this.showPlaces}}
              <ul class="absolute z-50 top-full mt-1.5 w-full bg-white dark:bg-gray-800 rounded-xl shadow-2xl border border-gray-100 dark:border-gray-700 overflow-hidden divide-y divide-gray-50 dark:divide-gray-700/60">
                {{#each this.placeSuggestions as |suggestion|}}
                  <li>
                    <button type="button" {{on "click" (fn this.selectPlace suggestion)}} class="w-full text-left px-4 py-3 text-sm text-gray-700 dark:text-gray-200 hover:bg-indigo-50 dark:hover:bg-indigo-900/30 flex items-center gap-3 transition-colors">
                      <svg class="w-3.5 h-3.5 shrink-0 text-rose-400" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M5.05 4.05a7 7 0 119.9 9.9L10 18.9l-4.95-4.95a7 7 0 010-9.9zM10 11a2 2 0 100-4 2 2 0 000 4z" clip-rule="evenodd" />
                      </svg>
                      <span class="truncate">{{suggestion.mainText}}</span>
                    </button>
                  </li>
                {{/each}}
              </ul>
            {{/if}}
          </div>

          <LocationPicker @onSelect={{this.handleLocationSelect}} />
        </div>
      </div>

      <TeamRegistration
        @registrationType={{this.d.tournament_team_registration_type}}
        @registrationFee={{this.d.tournament_team_registration_fee}}
        @registrationDeadline={{this.registrationDeadline}}
        @paymentMethods={{this.d.payment_receiving_details}}
        @onUpdate={{@onUpdate}}
        @onQrUpload={{@onQrUpload}}
      />

      <div>
        <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
          Tournament Start Date
          <span class="text-red-500">*</span>
        </label>
        <input
          type="date"
          value={{this.startDate}}
          {{on "input" (fn this.onInput "tournament_start_date")}}
          class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>

      <ScheduleSection @weekdays={{this.d.tournament_match_days}} @matchesPerDay={{this.d.tournament_match_number_per_day}} @matchTimeSlots={{this.d.tournament_match_time_slots}} @onUpdate={{@onUpdate}} />

      {{!-- {{log "prizes" this.d.tournament_prize}} --}}
      {{#if this.d.tournament_prize}}
        <PrizeSection @prizes={{this.d.tournament_prize}} @onChange={{this.onPrizesChange}} />
      {{/if}}

    </div>
  </template>
}
