import Component from '@glimmer/component';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { tracked } from '@glimmer/tracking';
import { eq } from 'ember-truth-helpers';
import config from 'spordium/config/environment';
import { fn } from '@ember/helper';
import LocationPicker from '../auth/signup/LocationPicker';
import ImageUploader from 'spordium/components/ui/image-uploader';
import PhoneInput from 'spordium/components/teams/ui/phone-input';
import CountrySelector from 'spordium/components/ui/teams/country-selector';

// ── Utilities ─────────────────────────────────────────────────────────────────
function debounce(fn, delay) {
  let timer;
  return function (...args) {
    clearTimeout(timer);
    timer = setTimeout(() => fn.apply(this, args), delay);
  };
}

// ── Location Helpers ──────────────────────────────────────────────────────────

/**
 * Shared shape for location data — every method must produce this.
 */
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

export default class TeamsCreateTeamComponent extends Component {
  @tracked team_name;
  @tracked game_name;
  @tracked team_email;
  @tracked team_mobile;
  @tracked country_of_the_team;
  @tracked country_of_gameplaying;
  @tracked address;
  @tracked team_logo;
  @tracked logoPreviewUrl = null;
  @tracked description;

  // Location state
  _locationData = emptyLocation();
  @tracked placeSuggestions = [];
  @tracked showPlaces = false;
  @tracked placesLoading = false;

  constructor() {
    super(...arguments);
    const team = this.args.team;
    this.team_name = team?.team_name ?? '';
    this.game_name = team?.game_name ?? 'cricket';
    this.team_email = team?.team_email ?? '';
    this.team_mobile = team?.team_mobile ?? '';
    this.country_of_the_team = team?.country_of_the_team ?? '';
    this.country_of_gameplaying = team?.country_of_gameplaying ?? '';
    this.address = team?.game_location?.address ?? '';
    this._locationData = team?.game_location ? { ...emptyLocation(), ...team.game_location } : emptyLocation();
    if (team?.team_logo) {
      this.logoPreviewUrl = `${config.APP.S3_BUCKET_URL}/${team.team_logo}`;
    }
    this.description = team?.description ?? '';
  }

  @action
  updateField(field, event) {
    this[field] = event.target.value;
    if (field === 'address') {
      this._fetchPlaces(event.target.value);
    }
  }

  @action
  handleLogoChange(event) {
    const file = event.target.files[0];
    if (!file) {
      return;
    }
    this.team_logo = file;

    const reader = new FileReader();
    reader.onload = (e) => {
      this.logoPreviewUrl = e.target.result;
    };
    reader.readAsDataURL(file);
  }

  _applyLocation(loc) {
    this._locationData = { ...emptyLocation(), ...loc };
    if (loc.formattedAddress) this.address = loc.formattedAddress;
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
  onLogoUploaded(result) {
    console.log('checking', result);

    if (result) {
      this.team_logo = result.objectToken; // বা আপনার প্রয়োজনীয় প্রপার্টি
      this.logoPreviewUrl = result.previewUrl;
    } else {
      this.team_logo = null;
      this.logoPreviewUrl = null;
    }
  }

  @action
  submitForm(event) {
    event.preventDefault();

    console.log('preview', this.logoPreviewUrl);
    console.log('team logo', this.team_logo);

    const data = {
      game_name: this.game_name,
      team_name: this.team_name,
      team_email: this.team_email,
      team_mobile: this.team_mobile,
      country_of_the_team: this.country_of_the_team,
      country_of_gameplaying: this.country_of_gameplaying,
      latitude: this._locationData.lat,
      longitude: this._locationData.lng,
      country_code: this._locationData.countryCode,
      game_location: {
        country: this._locationData.country,
        state: this._locationData.state,
        city: this._locationData.city,
        address: this.address,
      },
      team_logo: this.team_logo ? this.logoPreviewUrl : (this.args.team?.team_logo ?? ''),
      description: this.description,
    };

    if (this.args.onSubmit) {
      this.args.onSubmit(data);
    }
  }

  @action
  handlePhoneChange(data) {
    console.log('data', data);

    this.team_mobile = data.fullNumber;
  }

  @action
  handleCountryOfGameplaying(country) {
    this.country_of_gameplaying = country?.name ?? '';
  }

  <template>
    <div class="relative z-[999]" aria-labelledby="slide-over-title" role="dialog" aria-modal="true">
      {{! Backdrop }}
      <div class="fixed inset-0 bg-black/60 dark:bg-black/75 backdrop-blur-sm transition-opacity"></div>

      <div class="fixed inset-0 overflow-hidden">
        <div class="absolute inset-0 overflow-hidden">
          <div class="pointer-events-none fixed inset-y-0 right-0 flex max-w-full pl-6 sm:pl-10">
            <div class="pointer-events-auto w-screen max-w-md">
              <form class="flex h-full flex-col bg-white dark:bg-gray-950 shadow-2xl" {{on "submit" this.submitForm}}>

                {{! ── Header ── }}
                <div class="relative overflow-hidden bg-gradient-to-br from-indigo-600 via-violet-600 to-fuchsia-600 dark:from-indigo-700 dark:via-violet-700 dark:to-fuchsia-700 px-6 py-7">
                  {{! Dot texture }}
                  <div class="absolute inset-0 opacity-[0.12]" style="background-image: radial-gradient(circle, white 1px, transparent 1px); background-size: 18px 18px;"></div>
                  {{! Glow orb }}
                  <div class="absolute -top-10 -right-10 w-48 h-48 rounded-full bg-white/10 blur-3xl pointer-events-none"></div>

                  <div class="relative flex items-start justify-between gap-4">
                    <div class="flex items-center gap-4">
                      {{! Logo preview in header }}
                      <div class="w-14 h-14 rounded-2xl border-2 border-white/30 overflow-hidden bg-white/20 flex items-center justify-center shrink-0 shadow-lg">
                        {{#if this.logoPreviewUrl}}
                          <img src={{this.logoPreviewUrl}} alt="logo" class="w-full h-full object-cover" />
                        {{else}}
                          <svg class="w-7 h-7 text-white/70" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              d="M18 18.72a9.094 9.094 0 0 0 3.741-.479 3 3 0 0 0-4.682-2.72m.94 3.198.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0 1 12 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 0 1 6 18.719m12 0a5.971 5.971 0 0 0-.941-3.197m0 0A5.995 5.995 0 0 0 12 12.75a5.995 5.995 0 0 0-5.058 2.772m0 0a3 3 0 0 0-4.681 2.72 8.986 8.986 0 0 0 3.74.477m.94-3.197a5.971 5.971 0 0 0-.94 3.197M15 6.75a3 3 0 1 1-6 0 3 3 0 0 1 6 0Zm6 3a2.25 2.25 0 1 1-4.5 0 2.25 2.25 0 0 1 4.5 0Zm-13.5 0a2.25 2.25 0 1 1-4.5 0 2.25 2.25 0 0 1 4.5 0Z"
                            />
                          </svg>
                        {{/if}}
                      </div>
                      <div>
                        <p class="text-xs font-semibold text-white/60 uppercase tracking-widest mb-0.5">
                          {{#if @team}}Editing{{else}}Creating{{/if}}
                        </p>
                        <h2 id="slide-over-title" class="text-xl font-black text-white leading-tight">
                          {{#if @team}}Edit Team{{else}}New Team{{/if}}
                        </h2>
                      </div>
                    </div>
                    <button
                      type="button"
                      aria-label="Close panel"
                      class="shrink-0 w-9 h-9 rounded-xl bg-white/15 hover:bg-white/25 flex items-center justify-center text-white transition-colors focus:outline-none focus:ring-2 focus:ring-white/50"
                      {{on "click" @onClose}}
                    >
                      <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                      </svg>
                    </button>
                  </div>
                </div>

                {{! ── Scrollable body ── }}
                <div class="flex-1 overflow-y-auto">
                  <div class="px-6 py-6 space-y-5">

                    {{! ── Section: Identity ── }}
                    <div class="space-y-4">
                      <div class="flex items-center gap-2 mb-1">
                        <span class="w-5 h-5 rounded-md bg-indigo-100 dark:bg-indigo-900/50 flex items-center justify-center">
                          <svg class="w-3 h-3 text-indigo-600 dark:text-indigo-400" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24">
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z"
                            />
                          </svg>
                        </span>
                        <span class="text-xs font-bold uppercase tracking-widest text-gray-400 dark:text-gray-500">Team Identity</span>
                      </div>

                      {{! Team Name }}
                      <div>
                        <label for="team-name" class="block text-xs font-semibold text-gray-500 dark:text-gray-400 mb-1.5 uppercase tracking-wide">
                          Team Name
                          <span class="text-rose-400">*</span>
                        </label>
                        <div class="relative">
                          <span class="absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none">
                            <svg class="w-4 h-4 text-gray-400 dark:text-gray-500" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z" />
                            </svg>
                          </span>
                          <input
                            type="text"
                            name="team-name"
                            id="team-name"
                            placeholder="e.g. Thunder Warriors"
                            class="w-full pl-10 pr-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 text-gray-900 dark:text-gray-100 placeholder-gray-400 dark:placeholder-gray-600 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400/50 focus:border-indigo-400 dark:focus:border-indigo-500 transition-all"
                            value={{this.team_name}}
                            {{on "input" (fn this.updateField "team_name")}}
                            required
                          />
                        </div>
                      </div>

                      {{! Team Description }}
                      <div>
                        <label for="team-description" class="block text-xs font-semibold text-gray-500 dark:text-gray-400 mb-1.5 uppercase tracking-wide">
                          Description
                        </label>
                        <textarea
                          id="team-description"
                          name="team-description"
                          rows="3"
                          maxlength="500"
                          placeholder="Tell us about your team…"
                          class="w-full px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 text-gray-900 dark:text-gray-100 placeholder-gray-400 dark:placeholder-gray-600 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400/50 focus:border-indigo-400 dark:focus:border-indigo-500 transition-all resize-none"
                          {{on "input" (fn this.updateField "description")}}
                        >{{this.description}}</textarea>
                        <p class="mt-1 text-xs text-gray-400 text-right">{{this.description.length}}/500</p>
                      </div>

                      {{! Sport / Game }}
                      <div>
                        <label for="game-name" class="block text-xs font-semibold text-gray-500 dark:text-gray-400 mb-1.5 uppercase tracking-wide">
                          Sport
                          <span class="text-rose-400">*</span>
                        </label>
                        <div class="relative">
                          <span class="absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none">
                            <svg class="w-4 h-4 text-gray-400 dark:text-gray-500" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                              <path
                                stroke-linecap="round"
                                stroke-linejoin="round"
                                d="M16.5 18.75h-9m9 0a3 3 0 0 1 3 3h-15a3 3 0 0 1 3-3m9 0v-3.375c0-.621-.503-1.125-1.125-1.125h-.871M7.5 18.75v-3.375c0-.621.504-1.125 1.125-1.125h.872m5.007 0H9.497m5.007 0a7.454 7.454 0 0 1-.982-3.172M9.497 14.25a7.454 7.454 0 0 0 .981-3.172M5.25 4.236c-.982.143-1.954.317-2.916.52A6.003 6.003 0 0 0 7.73 9.728M5.25 4.236V4.5c0 2.108.966 3.99 2.48 5.228M5.25 4.236V2.721C7.456 2.41 9.71 2.25 12 2.25c2.291 0 4.545.16 6.75.47v1.516M7.73 9.728a6.726 6.726 0 0 0 2.748 1.35m8.272-6.842V4.5c0 2.108-.966 3.99-2.48 5.228m2.48-5.492a46.32 46.32 0 0 1 2.916.52 6.003 6.003 0 0 1-5.395 4.972m0 0a6.726 6.726 0 0 1-2.749 1.35m0 0a6.772 6.772 0 0 1-3.044 0"
                              />
                            </svg>
                          </span>
                          <select
                            id="game-name"
                            name="game-name"
                            class="w-full pl-10 pr-9 py-2.5 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 text-gray-900 dark:text-gray-100 text-sm appearance-none focus:outline-none focus:ring-2 focus:ring-indigo-400/50 focus:border-indigo-400 dark:focus:border-indigo-500 transition-all"
                            {{on "change" (fn this.updateField "game_name")}}
                          >
                            <option value="cricket" selected={{eq this.game_name "cricket"}}>🏏 Cricket</option>
                            {{!-- <option value="football" selected={{eq this.game_name "football"}}>⚽ Football</option> --}}
                            {{!-- <option value="basketball" selected={{eq this.game_name "basketball"}}>🏀 Basketball</option> --}}
                          </select>
                          <span class="absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none">
                            <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5" />
                            </svg>
                          </span>
                        </div>
                      </div>
                    </div>

                    {{! ── Divider ── }}
                    <div class="border-t border-gray-100 dark:border-gray-800"></div>

                    {{! ── Section: Logo ── }}
                    <div>
                      <div class="w-36">
                        <ImageUploader @type="team_logo" @aspectRatio="1/1" @initialToken={{@team.team_logo}} @onChange={{this.onLogoUploaded}} />
                      </div>
                    </div>

                    {{! ── Divider ── }}
                    <div class="border-t border-gray-100 dark:border-gray-800"></div>

                    {{! ── Section: Contact ── }}
                    <div class="space-y-4">
                      <div class="flex items-center gap-2 mb-1">
                        <span class="w-5 h-5 rounded-md bg-emerald-100 dark:bg-emerald-900/50 flex items-center justify-center">
                          <svg class="w-3 h-3 text-emerald-600 dark:text-emerald-400" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24">
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              d="M21.75 6.75v10.5a2.25 2.25 0 0 1-2.25 2.25h-15a2.25 2.25 0 0 1-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0 0 19.5 4.5h-15a2.25 2.25 0 0 0-2.25 2.25m19.5 0v.243a2.25 2.25 0 0 1-1.07 1.916l-7.5 4.615a2.25 2.25 0 0 1-2.36 0L3.32 8.91a2.25 2.25 0 0 1-1.07-1.916V6.75"
                            />
                          </svg>
                        </span>
                        <span class="text-xs font-bold uppercase tracking-widest text-gray-400 dark:text-gray-500">Contact</span>
                      </div>

                      {{! Email }}
                      <div>
                        <label for="team-email" class="block text-xs font-semibold text-gray-500 dark:text-gray-400 mb-1.5 uppercase tracking-wide">
                          Email
                          <span class="text-rose-400">*</span>
                        </label>
                        <div class="relative">
                          <span class="absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none">
                            <svg class="w-4 h-4 text-gray-400 dark:text-gray-500" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                              <path
                                stroke-linecap="round"
                                stroke-linejoin="round"
                                d="M21.75 6.75v10.5a2.25 2.25 0 0 1-2.25 2.25h-15a2.25 2.25 0 0 1-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0 0 19.5 4.5h-15a2.25 2.25 0 0 0-2.25 2.25m19.5 0v.243a2.25 2.25 0 0 1-1.07 1.916l-7.5 4.615a2.25 2.25 0 0 1-2.36 0L3.32 8.91a2.25 2.25 0 0 1-1.07-1.916V6.75"
                              />
                            </svg>
                          </span>
                          <input
                            type="email"
                            name="team-email"
                            id="team-email"
                            placeholder="team@example.com"
                            class="w-full pl-10 pr-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 text-gray-900 dark:text-gray-100 placeholder-gray-400 dark:placeholder-gray-600 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-400/50 focus:border-emerald-400 dark:focus:border-emerald-500 transition-all"
                            value={{this.team_email}}
                            {{on "input" (fn this.updateField "team_email")}}
                            required
                          />
                        </div>
                      </div>

                      {{! Mobile }}
                      <PhoneInput @onChange={{this.handlePhoneChange}} />
                    </div>

                    {{! ── Divider ── }}
                    <div class="border-t border-gray-100 dark:border-gray-800"></div>

                    {{! ── Section: Location ── }}
                    <div class="space-y-4">
                      <div class="flex items-center gap-2 mb-1">
                        <span class="w-5 h-5 rounded-md bg-rose-100 dark:bg-rose-900/50 flex items-center justify-center">
                          <svg class="w-3 h-3 text-rose-600 dark:text-rose-400" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M15 10.5a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z" />
                            <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1 1 15 0Z" />
                          </svg>
                        </span>
                        <span class="text-xs font-bold uppercase tracking-widest text-gray-400 dark:text-gray-500">Location</span>
                      </div>

                      {{! Team Location (renamed from Game Location) }}
                      <div>
                        <label for="address" class="block text-xs font-semibold text-gray-500 dark:text-gray-400 mb-1.5 uppercase tracking-wide">
                          Team Location
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
                                    <button
                                      type="button"
                                      {{on "click" (fn this.selectPlace suggestion)}}
                                      class="w-full text-left px-4 py-3 text-sm text-gray-700 dark:text-gray-200 hover:bg-indigo-50 dark:hover:bg-indigo-900/30 flex items-center gap-3 transition-colors"
                                    >
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

                      {{! Country of Gameplay }}
                      <div>
                        <label class="block text-xs font-semibold text-gray-500 dark:text-gray-400 mb-1.5 uppercase tracking-wide">
                          Country of Gameplay
                        </label>
                        <div class="relative">
                          <span class="absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none z-10">
                            <svg class="w-4 h-4 text-gray-400 dark:text-gray-500" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                              <path
                                stroke-linecap="round"
                                stroke-linejoin="round"
                                d="M12 21a9.004 9.004 0 0 0 8.716-6.747M12 21a9.004 9.004 0 0 1-8.716-6.747M12 21c2.485 0 4.5-4.03 4.5-9S14.485 3 12 3m0 18c-2.485 0-4.5-4.03-4.5-9S9.515 3 12 3m0 0a8.997 8.997 0 0 1 7.843 4.582M12 3a8.997 8.997 0 0 0-7.843 4.582m15.686 0A11.953 11.953 0 0 1 12 10.5c-2.998 0-5.74-1.1-7.843-2.918m15.686 0A8.959 8.959 0 0 1 21 12c0 .778-.099 1.533-.284 2.253m0 0A17.919 17.919 0 0 1 12 16.5c-3.162 0-6.133-.815-8.716-2.247m0 0A9.015 9.015 0 0 1 3 12c0-1.605.42-3.113 1.157-4.418"
                              />
                            </svg>
                          </span>
                          <CountrySelector @onChange={{this.handleCountryOfGameplaying}} />
                        </div>
                      </div>

                      <div style="height: 10rem;"></div>
                    </div>

                    {{! Bottom padding so content clears the sticky footer }}
                    <div class="h-2"></div>
                  </div>
                </div>

                {{! ── Sticky Footer ── }}
                <div class="shrink-0 border-t border-gray-100 dark:border-gray-800 bg-white dark:bg-gray-950 px-6 py-4">
                  <div class="flex gap-3">
                    <button
                      type="button"
                      class="flex-1 py-2.5 px-4 rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900 text-sm font-semibold text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800 hover:border-gray-300 dark:hover:border-gray-600 transition-all focus:outline-none focus:ring-2 focus:ring-gray-400/40"
                      {{on "click" @onClose}}
                    >
                      Cancel
                    </button>
                    <button
                      type="submit"
                      class="flex-1 py-2.5 px-4 rounded-xl bg-gradient-to-r from-indigo-600 to-violet-600 hover:from-indigo-500 hover:to-violet-500 text-sm font-bold text-white shadow-md shadow-indigo-500/30 dark:shadow-indigo-900/40 transition-all focus:outline-none focus:ring-2 focus:ring-indigo-400/60 active:scale-[0.98]"
                    >
                      {{#if @team}}Update Team{{else}}Create Team{{/if}}
                    </button>
                  </div>
                </div>
              </form>
            </div>
          </div>
        </div>
      </div>
    </div>
  </template>
}
