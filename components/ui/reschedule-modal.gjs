import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { service } from '@ember/service';
import { modifier } from 'ember-modifier';
import { debounce } from '@ember/runloop';
import config from 'spordium/config/environment';
import LocationPicker from 'spordium/components/auth/signup/LocationPicker';

// ── Location helpers (same as create-match) ────────────────────────────────
function emptyLocation() {
  return { lat: null, lng: null, country: '', countryCode: '', state: '', city: '', formattedAddress: '' };
}

async function reverseGeocode(lat, lng) {
  const res = await fetch(
    `https://maps.googleapis.com/maps/api/geocode/json?latlng=${lat},${lng}&key=${config.APP.GOOGLE_MAPS_API_KEY}`
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
    lat, lng,
    country:     country?.long_name  || '',
    countryCode: country?.short_name || '',
    state:       state?.long_name    || '',
    city:        city?.long_name     || '',
    formattedAddress: data.results[0].formatted_address,
  };
}

async function fetchPlaceDetails(placeId) {
  const url = `https://places.googleapis.com/v1/places/${placeId}?fields=id,displayName,location,addressComponents,formattedAddress&key=${config.APP.GOOGLE_MAPS_API_KEY}`;
  const res  = await fetch(url);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const data = await res.json();
  const components = data.addressComponents || [];
  const find = (type) => components.find(c => c.types.includes(type));
  const country = find('country');
  const state   = find('administrative_area_level_1');
  const city    = find('locality') || find('administrative_area_level_2');
  return {
    lat:         data.location?.latitude  || null,
    lng:         data.location?.longitude || null,
    country:     country?.longText  || '',
    countryCode: country?.shortText || '',
    state:       state?.longText    || '',
    city:        city?.longText     || '',
    formattedAddress: data.formattedAddress || '',
  };
}

// ── One-shot insert modifier ───────────────────────────────────────────────
const _initialized = new WeakSet();
const onInsert = modifier((el, [fn]) => {
  if (!_initialized.has(el)) {
    _initialized.add(el);
    fn();
  }
});

class RescheduleModalComponent extends Component {
  @service api;
  @service toast;

  @tracked date = '';
  @tracked time = '';
  @tracked fieldName = '';
  @tracked locationText = '';
  @tracked placeSuggestions = [];
  @tracked placesLoading = false;
  @tracked isSubmitting = false;

  _locationData = emptyLocation();

  get showPlaces() {
    return this.placeSuggestions.length > 0;
  }

  @action
  prefill() {
    const model = this.args.model;
    const loc = model?.gameLocation || {};

    if (model?.gameDatetime) {
      const d = new Date(model.gameDatetime);
      const yyyy = d.getFullYear();
      const mm = String(d.getMonth() + 1).padStart(2, '0');
      const dd = String(d.getDate()).padStart(2, '0');
      this.date = `${yyyy}-${mm}-${dd}`;
      this.time = `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
    }
    this.fieldName = '';
    const addr = loc.address || loc.place || '';
    this.locationText = addr;
    this._locationData = {
      ...emptyLocation(),
      lat: model?.latitude || null,
      lng: model?.longitude || null,
      country: loc.country || '',
      state: loc.state || loc.division || '',
      city: loc.city || '',
      formattedAddress: addr,
    };
  }

  @action setDate(e) { this.date = e.target.value; }
  @action setTime(e) { this.time = e.target.value; }
  @action setFieldName(e) { this.fieldName = e.target.value; }

  @action
  setLocationText(e) {
    this.locationText = e.target.value;
    debounce(this, '_performPlacesSearch', e.target.value, 400);
  }

  async _performPlacesSearch(input) {
    if (!input || input.length < 2) {
      this.placeSuggestions = [];
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
      if (this.locationText !== input) return;
      const data = await res.json();
      this.placeSuggestions = (data?.suggestions ?? [])
        .filter(s => s.placePrediction)
        .map(s => ({
          description: s.placePrediction.text?.text ?? '',
          placeId:     s.placePrediction.placeId,
        }));
    } catch {
      this.placeSuggestions = [];
    } finally {
      this.placesLoading = false;
    }
  }

  _commitLocation(text, locData) {
    this._locationData    = locData;
    this.locationText     = text;
    this.placeSuggestions = [];
  }

  @action
  async selectPlace(suggestion) {
    try {
      const loc = await fetchPlaceDetails(suggestion.placeId);
      this._commitLocation(suggestion.description, { ...emptyLocation(), ...loc, formattedAddress: suggestion.description });
    } catch {
      this._commitLocation(suggestion.description, { ...emptyLocation(), formattedAddress: suggestion.description });
    }
  }

  @action
  async handleLocationSelect({ lat, lng, address }) {
    try {
      const loc = await reverseGeocode(lat, lng);
      this._commitLocation(address, { ...emptyLocation(), ...loc, formattedAddress: address });
    } catch {
      this._commitLocation(address, { ...emptyLocation(), lat, lng, formattedAddress: address });
    }
  }

  @action
  async submit() {
    if (this.isSubmitting || !this.date || !this.time) return;
    const model = this.args.model;
    const loc = this._locationData;
    const origLoc = model?.gameLocation || {};

    const [yyyy, mm, dd] = this.date.split('-');
    const apiDate = `${yyyy}-${Number(mm)}-${Number(dd)}`;
    const apiDateTime = `${apiDate} ${this.time}`;

    this.isSubmitting = true;
    try {
      // Step 1: check if match exists on this date
      const checkRes = await this.api.post('/game/match-team-reshedule-exist/', {
        team1: model?.team1?.id,
        team2: model?.team2?.id,
        date_time: apiDate,
        match_countrycode: (model?.countrycode || '').toLowerCase(),
      });

      if (checkRes?.data?.match_exist) {
        this.toast.error('A match between these teams already exists on this date.');
        return;
      }

      // Step 2: create rescheduled match
      const gameConfig = model?.gameConfiguration || {};
      await this.api.post('/game/MatchCreation/', {
        game_id: model?.id,
        Game_DateTime: apiDateTime,
        Game_Location: {
          country:  loc.country  || origLoc.country  || '',
          state:    loc.state    || origLoc.state     || origLoc.division || '',
          division: loc.state    || origLoc.division  || '',
          city:     loc.city     || origLoc.city      || '',
          place:    this.fieldName || origLoc.place   || '',
          address:  this.locationText || origLoc.address || '',
        },
        countrycode: loc.countryCode || model?.countrycode || '',
        long_lati: {
          lati: String(loc.lat || model?.latitude || ''),
          long: String(loc.lng || model?.longitude || ''),
        },
        gamefield_name: this.fieldName,
        Game_Configuration: {
          over: String(gameConfig.over || ''),
          match_prize: gameConfig.match_prize || '',
          number_of_player_in_one_side: String(gameConfig.number_of_player_in_one_side || ''),
          abandoned: new Date().toISOString().replace('Z', '').slice(0, 23) + '.000',
        },
      });

      this.toast.success('Match rescheduled successfully.');
      this.args.onClose?.();
    } catch (e) {
      this.toast.error(e?.payload?.message || 'Failed to reschedule match.');
    } finally {
      this.isSubmitting = false;
    }
  }

  <template>
    {{#if @isOpen}}
      <div class="fixed inset-0 z-50 flex items-center justify-center px-4" role="dialog">
        <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" {{on "click" @onClose}}></div>
        <div class="relative z-10 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-700 rounded-2xl shadow-2xl w-full max-w-sm p-6" {{onInsert this.prefill}}>

          <div class="flex items-center justify-between mb-5">
            <h3 class="text-base font-semibold text-gray-900 dark:text-white">Match Abandoned Popup</h3>
            <button type="button" class="text-gray-400 hover:text-gray-600 dark:hover:text-gray-200" {{on "click" @onClose}}>
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>

          {{! Date }}
          <div class="mb-4">
            <label class="flex items-center gap-1.5 text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">
              Select Date
              <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.75">
                <path stroke-linecap="round" stroke-linejoin="round" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
              </svg>
            </label>
            <input
              type="date"
              class="w-full px-3 py-2 text-sm rounded-xl border border-gray-200 dark:border-slate-600 bg-gray-50 dark:bg-slate-700 text-gray-800 dark:text-gray-200 focus:outline-none focus:ring-2 focus:ring-cyan-500"
              value={{this.date}}
              {{on "change" this.setDate}}
            />
          </div>

          {{! Time }}
          <div class="mb-4">
            <label class="flex items-center gap-1.5 text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">
              Select Time
              <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.75">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
              </svg>
            </label>
            <input
              type="time"
              class="w-full px-3 py-2 text-sm rounded-xl border border-gray-200 dark:border-slate-600 bg-gray-50 dark:bg-slate-700 text-gray-800 dark:text-gray-200 focus:outline-none focus:ring-2 focus:ring-cyan-500"
              value={{this.time}}
              {{on "change" this.setTime}}
            />
          </div>

          {{! Field Name }}
          <div class="mb-4">
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">
              Input Field Name:
            </label>
            <input
              type="text"
              class="w-full px-3 py-2 text-sm rounded-xl border border-gray-200 dark:border-slate-600 bg-gray-50 dark:bg-slate-700 text-gray-800 dark:text-gray-200 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-cyan-500"
              placeholder="Match Field"
              value={{this.fieldName}}
              {{on "input" this.setFieldName}}
            />
          </div>

          {{! Address + LocationPicker }}
          <div class="mb-6">
            <div class="flex items-center gap-2">
              <div class="relative flex-1">
                <input
                  type="text"
                  placeholder="Start typing your address…"
                  value={{this.locationText}}
                  autocomplete="off"
                  class="w-full px-3 py-2 text-sm rounded-xl border border-gray-200 dark:border-slate-600 bg-gray-50 dark:bg-slate-700 text-gray-800 dark:text-gray-200 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-cyan-500 pr-8"
                  {{on "input" this.setLocationText}}
                />
                {{#if this.placesLoading}}
                  <span class="absolute right-2.5 top-1/2 -translate-y-1/2">
                    <svg class="w-3.5 h-3.5 text-cyan-400 animate-spin" fill="none" viewBox="0 0 24 24">
                      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
                      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
                    </svg>
                  </span>
                {{/if}}
                {{#if this.showPlaces}}
                  <ul class="absolute z-50 top-full mt-1 w-full bg-white dark:bg-slate-900 border border-gray-200 dark:border-slate-700 rounded-xl shadow-xl overflow-hidden divide-y divide-gray-100 dark:divide-slate-700/60">
                    {{#each this.placeSuggestions as |suggestion|}}
                      <li>
                        <button
                          type="button"
                          class="w-full text-left px-3 py-2.5 text-xs text-gray-700 dark:text-gray-200 hover:bg-cyan-50 dark:hover:bg-cyan-900/30 flex items-center gap-2 transition-colors"
                          {{on "click" (fn this.selectPlace suggestion)}}
                        >
                          <svg class="w-3.5 h-3.5 shrink-0 text-cyan-500" fill="currentColor" viewBox="0 0 20 20">
                            <path fill-rule="evenodd" d="M5.05 4.05a7 7 0 119.9 9.9L10 18.9l-4.95-4.95a7 7 0 010-9.9zM10 11a2 2 0 100-4 2 2 0 000 4z" clip-rule="evenodd"/>
                          </svg>
                          <span class="truncate">{{suggestion.description}}</span>
                        </button>
                      </li>
                    {{/each}}
                  </ul>
                {{/if}}
              </div>
              <span class="text-xs text-gray-400 flex-shrink-0">OR</span>
              <LocationPicker @onSelect={{this.handleLocationSelect}} />
            </div>
          </div>

          {{! Footer }}
          <div class="flex justify-end">
            <button
              type="button"
              class="px-5 py-1.5 text-sm font-semibold text-cyan-600 dark:text-cyan-400 hover:underline disabled:opacity-50"
              disabled={{this.isSubmitting}}
              {{on "click" this.submit}}
            >
              {{if this.isSubmitting "Saving..." "DONE"}}
            </button>
          </div>

        </div>
      </div>
    {{/if}}
  </template>
}

export default RescheduleModalComponent;
