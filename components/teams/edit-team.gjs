import Component from '@glimmer/component';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { tracked } from '@glimmer/tracking';
import { eq } from 'ember-truth-helpers';
import { fn } from '@ember/helper';
import { inject as service } from '@ember/service';
import { task, timeout } from 'ember-concurrency';
import config from 'spordium/config/environment';
import LocationPicker from '../auth/signup/LocationPicker';
import AssignPlayer from './edit-team/assign-player';
import FormField from 'spordium/components/ui/teams/form-field';
import ImageUploader from 'spordium/components/ui/image-uploader';
import PhoneInput from 'spordium/components/teams/ui/phone-input';
import CountrySelector from 'spordium/components/ui/teams/country-selector';

// ── Utilities ─────────────────────────────────────────────────────────────────
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
    country: country?.long_name ?? '',
    countryCode: country?.short_name ?? '',
    state: state?.long_name ?? '',
    city: city?.long_name ?? '',
    formattedAddress: data.results[0].formatted_address,
  };
}

async function fetchPlaceDetails(placeId, apiKey) {
  const url = `https://places.googleapis.com/v1/places/${placeId}?fields=id,displayName,location,addressComponents,formattedAddress&key=${apiKey}`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const data = await res.json();

  const components = data.addressComponents ?? [];
  const find = (type) => components.find((c) => c.types.includes(type));
  const country = find('country');
  const state = find('administrative_area_level_1');
  const city = find('locality') ?? find('administrative_area_level_2');

  return {
    lat: data.location?.latitude ?? null,
    lng: data.location?.longitude ?? null,
    country: country?.longText ?? '',
    countryCode: country?.shortText ?? '',
    state: state?.longText ?? '',
    city: city?.longText ?? '',
    formattedAddress: data.formattedAddress ?? '',
  };
}

export default class TeamsEditTeamComponent extends Component {
  @service store;
  @service router;
  @service geolocation;
  @service countries;

  config = config;

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

  // Player search state
  @tracked searchQuery = '';
  @tracked searchDropdownList = [];

  // Location state
  _locationData = emptyLocation();
  @tracked placeSuggestions = [];
  @tracked showPlaces = false;

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
      this.logoPreviewUrl = team.team_logo.startsWith('data:') ? team.team_logo : `${config.APP.S3_BUCKET_URL}/${team.team_logo}`;
    }
    this.description = team?.description ?? '';
  }

  // ── Tasks ─────────────────────────────────────────────────────────────────

  @task({ restartable: true })
  *playerSearchTask(query) {
    yield timeout(300);

    const trimmed = query.trim();
    if (trimmed.length < 2) {
      this.searchDropdownList = [];
      return;
    }

    const location = yield this.geolocation.getCoords();
    const params = new URLSearchParams({
      search_data: trimmed,
      longitude: location.longitude,
      latitude: location.latitude,
      country_code: 'BD',
      limit: 10,
      offset: 0,
      page: 1,
    });

    const response = yield fetch(`https://khelasearch.adnanfoundation.com/search/cricket-player-search/?${params}`);
    if (!response.ok) throw new Error(`Player search failed: ${response.statusText}`);

    const data = yield response.json();
    const existingIds = new Set((this.args.members?.team_members ?? []).map((m) => m.player_id));

    this.searchDropdownList = (data.results ?? []).filter((p) => !existingIds.has(p.player_id));
  }

  @task({ restartable: true })
  *fetchPlacesTask(input) {
    if (!input || input.length < 2) {
      this.placeSuggestions = [];
      this.showPlaces = false;
      return;
    }

    yield timeout(400);

    const res = yield fetch('https://places.googleapis.com/v1/places:autocomplete', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': config.APP.GOOGLE_MAPS_API_KEY,
        'X-Goog-FieldMask': 'suggestions.placePrediction.text,suggestions.placePrediction.placeId',
      },
      body: JSON.stringify({ input, includeQueryPredictions: false }),
    });
    if (!res.ok) throw new Error(`Places API ${res.status}`);

    const data = yield res.json();
    this.placeSuggestions = (data?.suggestions ?? [])
      .filter((s) => s.placePrediction)
      .map((s) => ({
        description: s.placePrediction.text?.text ?? '',
        placeId: s.placePrediction.placeId,
        mainText: s.placePrediction.text?.text ?? '',
      }));
    this.showPlaces = this.placeSuggestions.length > 0;
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  @action
  updateField(field, event) {
    this[field] = event.target.value;
    if (field === 'address') {
      this.fetchPlacesTask.perform(event.target.value);
    }
  }

  @action
  handleLogoChange(event) {
    const file = event.target.files[0];
    if (!file) return;
    this.team_logo = file;
    const reader = new FileReader();
    reader.onload = (e) => (this.logoPreviewUrl = e.target.result);
    reader.readAsDataURL(file);
  }

  @action
  handlePlayerSearch(event) {
    this.searchQuery = event.target.value;
    this.playerSearchTask.perform(event.target.value);
  }

  @action
  addPlayerToTeam(player) {
    this.searchQuery = '';
    this.searchDropdownList = [];

    const MEMBER_MODEL = this.args.members;
    const obj = {
      pending: true,
      player_id: player.player_id,
      player_primary_pic: player.player_primary_pic,
      PlayerName: player.player_fullname,
      playing_order: player.playing_order,
    };

    MEMBER_MODEL.team_members = [...(MEMBER_MODEL.team_members ?? []), obj];
    MEMBER_MODEL.added_players = [...MEMBER_MODEL.added_players, player.player_id];
    MEMBER_MODEL.team_name = this.args.team.team_name;
  }

  @action
  removePlayerFromTeam(playerToRemove) {
    const MEMBER_MODEL = this.args.members;

    const removedPlayers = MEMBER_MODEL.removed_players ?? [];
    if (!removedPlayers.includes(playerToRemove.player_id)) {
      MEMBER_MODEL.removed_players = [...removedPlayers, playerToRemove.player_id];
    }

    MEMBER_MODEL.team_members = (MEMBER_MODEL.team_members ?? []).filter((m) => m.player_id !== playerToRemove.player_id);
    MEMBER_MODEL.added_players = (MEMBER_MODEL.added_players ?? []).filter((id) => id !== playerToRemove.player_id);
  }

  @action
  setPlayerRole(player, role) {
    const MEMBER_MODEL = this.args.members;
    const playerId = player.player_id;

    if (role === 'captain') {
      if (MEMBER_MODEL.vice_captain === playerId) MEMBER_MODEL.vice_captain = null;
      MEMBER_MODEL.captain = playerId;
    } else if (role === 'vice_captain') {
      if (MEMBER_MODEL.captain === playerId) MEMBER_MODEL.captain = null;
      MEMBER_MODEL.vice_captain = playerId;
    } else if (role === 'wicket_keeper') {
      const currentWKs = MEMBER_MODEL.wicket_keeper ?? [];
      const isAlreadyWK = currentWKs.includes(playerId);
      MEMBER_MODEL.wicket_keeper = isAlreadyWK ? currentWKs.filter((id) => id !== playerId) : [...currentWKs, playerId];
    }

    MEMBER_MODEL.team_members = [...(MEMBER_MODEL.team_members ?? [])];
  }

  @action
  onCloseMember() {
    this.args.members.rollbackAttributes();
  }

  _applyLocation(loc) {
    this._locationData = { ...emptyLocation(), ...loc };
    if (loc.formattedAddress) this.address = loc.formattedAddress;
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

  @action
  async handleLocationSelect({ lat, lng, address }) {
    try {
      const loc = await reverseGeocode(lat, lng, config.APP.GOOGLE_MAPS_API_KEY);
      this._applyLocation({ ...loc, formattedAddress: address });
    } catch (err) {
      console.error('Reverse geocode error:', err);
      this._applyLocation({ ...emptyLocation(), lat, lng, formattedAddress: address });
    }
    this.placeSuggestions = [];
    this.showPlaces = false;
  }

  // ── FIX: দুটো আলাদা country handler ──────────────────────────────────────

  @action
  handleCountryOfTeam(country) {
    this.country_of_the_team = country?.name ?? '';
  }

  @action
  handleCountryOfGameplaying(country) {
    this.country_of_gameplaying = country?.name ?? '';
  }

  // ── image ─────────────────────────────────────────────────────────────────

  @action
  onLogoUploaded(result) {
    if (result) {
      this.team_logo = result.objectToken;
      this.logoPreviewUrl = result.previewUrl;
    } else {
      this.team_logo = null;
      this.logoPreviewUrl = null;
    }
  }

  @action
  async submitForm(event) {
    event.preventDefault();

    const team_logo = this.team_logo ? this.team_logo : (this.args.team?.team_logo ?? '');
    const ext = team_logo ? team_logo.split('.').pop() : (this.args.team?.team_photopath_extension ?? '');

    const location = await this.geolocation.getCoords();

    const data = {
      game_name: this.game_name,
      team_name: this.team_name,
      team_email: this.team_email,
      team_mobile: this.team_mobile,
      country_of_the_team: this.country_of_the_team, // ✅ handleCountryOfTeam থেকে set
      country_of_gameplaying: this.country_of_gameplaying, // ✅ handleCountryOfGameplaying থেকে set
      latitude: String(location.latitude),
      longitude: String(location.longitude),
      country_code: this._locationData.countryCode,
      game_location: {
        country: this._locationData.country,
        state: this._locationData.state,
        city: this._locationData.city,
        address: this.address,
      },
      team_logo: team_logo,
      team_photopath_extension: ext,
      description: this.description,
    };

    this.args.onSubmit?.(data);
  }

  @action
  submitPlayerForm(event) {
    event.preventDefault();
    this.args.onSubmitMemberForm?.();
  }

  get members() {
    return this.args.members.team_members;
  }

  @action
  handlePhoneChange(data) {
    this.team_mobile = data.fullNumber;
  }

  // country_of_the_team এর initial code বের করার জন্য
  get countryOfTeamCode() {
    return this.countries.list.find((c) => c.name === this.country_of_the_team)?.code ?? 'bd';
  }

  // country_of_gameplaying এর initial code বের করার জন্য
  get countryOfGameplayingCode() {
    return this.countries.list.find((c) => c.name === this.country_of_gameplaying)?.code ?? 'bd';
  }

  <template>
    <div class="space-y-6 bg-white dark:bg-gray-900 rounded-2xl shadow-sm border border-gray-200 dark:border-gray-700">
      {{! ── Section Header ── }}
      <div class="px-6 pt-6 border-b border-gray-100 dark:border-gray-800 pb-4">
        <div class="flex items-center gap-3">
          <div class="w-8 h-8 rounded-lg bg-indigo-50 dark:bg-indigo-900/40 flex items-center justify-center">
            <svg class="w-4 h-4 text-indigo-600 dark:text-indigo-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z"
              />
            </svg>
          </div>
          <div>
            <h3 class="text-base font-semibold text-gray-900 dark:text-gray-100">Edit Team</h3>
            <p class="text-xs text-gray-400 dark:text-gray-500">Update your team's information</p>
          </div>
        </div>
      </div>

      <form class="px-6 pb-6 space-y-6" aria-label="edit team form" {{on "submit" this.submitForm}}>
        {{! ── Basic Info ── }}
        <div>
          <p class="text-xs font-semibold uppercase tracking-widest text-gray-400 dark:text-gray-500 mb-3">Basic Info</p>
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <FormField @id="team-name" @label="Team Name" @value={{this.team_name}} @onInput={{fn this.updateField "team_name"}} @required={{true}} @hint="e.g. Dhaka Tigers" />
            <div class="relative">
              <label class="absolute -top-2.5 left-3 text-xs font-medium bg-white dark:bg-gray-900 px-1 text-indigo-600 dark:text-indigo-400 z-10">Game <span class="text-red-500">*</span></label>
              <select
                id="game-name"
                class="block w-full rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-900 text-gray-900 dark:text-gray-100 px-3 pt-4 pb-2 text-sm focus:border-2 focus:border-indigo-500 outline-none transition-all hover:border-gray-400"
                {{on "change" (fn this.updateField "game_name")}}
              >
                <option value="cricket" selected={{eq this.game_name "cricket"}}>🏏 Cricket</option>
                <option value="football" selected={{eq this.game_name "football"}}>⚽ Football</option>
                <option value="basketball" selected={{eq this.game_name "basketball"}}>🏀 Basketball</option>
              </select>
            </div>
          </div>
        </div>

        {{! ── Description ── }}
        <div>
          <p class="text-xs font-semibold uppercase tracking-widest text-gray-400 dark:text-gray-500 mb-3">Description</p>
          <div class="relative">
            <label class="absolute -top-2.5 left-3 text-xs font-medium bg-white dark:bg-gray-900 px-1 text-indigo-600 dark:text-indigo-400 z-10">
              About the Team
            </label>
            <textarea
              id="team-description"
              rows="3"
              maxlength="500"
              placeholder="Tell us about your team…"
              class="block w-full rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-900 text-gray-900 dark:text-gray-100 px-3 pt-4 pb-2 text-sm focus:border-2 focus:border-indigo-500 outline-none transition-all resize-none"
              {{on "input" (fn this.updateField "description")}}
            >{{this.description}}</textarea>
            <p class="mt-1 text-xs text-gray-400 text-right">{{this.description.length}}/500</p>
          </div>
        </div>

        {{! ── Contact ── }}
        <div>
          <p class="text-xs font-semibold uppercase tracking-widest text-gray-400 dark:text-gray-500 mb-3">Contact</p>
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <FormField @id="team-email" @label="Email" @type="email" @value={{this.team_email}} @onInput={{fn this.updateField "team_email"}} @required={{true}} @hint="e.g. tigers@example.com" />
            <PhoneInput @onChange={{this.handlePhoneChange}} @initialValue={{this.team_mobile}} />
          </div>
        </div>

        {{! ── Location ── }}
        <div>
          <p class="text-xs font-semibold uppercase tracking-widest text-gray-400 dark:text-gray-500 mb-3">Location</p>
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div class="relative">
              <label class="absolute -top-2.5 left-3 text-xs font-medium bg-white dark:bg-gray-900 px-1 text-indigo-600 dark:text-indigo-400 z-10">Team Location <span class="text-red-500">*</span></label>
              <div class="flex gap-2">
                <div class="relative grow">
                  <input
                    required
                    type="text"
                    id="address"
                    value={{this.address}}
                    {{on "input" (fn this.updateField "address")}}
                    autocomplete="off"
                    placeholder=" "
                    class="block w-full rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-900 text-gray-900 dark:text-gray-100 px-3 pt-4 pb-2 text-sm focus:border-2 focus:border-indigo-500 outline-none transition-all"
                  />
                  {{#if this.fetchPlacesTask.isRunning}}
                    <span class="absolute right-2.5 top-1/2 -translate-y-1/2">
                      <svg class="w-4 h-4 text-indigo-500 animate-spin" fill="none" viewBox="0 0 24 24">
                        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"></path>
                      </svg>
                    </span>
                  {{/if}}
                  {{#if this.showPlaces}}
                    <ul class="absolute z-50 top-full mt-1.5 w-full bg-white dark:bg-gray-800 rounded-xl shadow-2xl overflow-hidden divide-y divide-gray-100 dark:divide-gray-700 border border-gray-200 dark:border-gray-700">
                      {{#each this.placeSuggestions as |suggestion|}}
                        <li>
                          <button
                            type="button"
                            {{on "click" (fn this.selectPlace suggestion)}}
                            class="w-full text-left px-4 py-3 text-sm text-gray-700 dark:text-gray-200 hover:bg-indigo-50 dark:hover:bg-indigo-900/30 flex items-center gap-3 transition-colors"
                          >
                            <svg class="w-4 h-4 shrink-0 text-indigo-400" fill="currentColor" viewBox="0 0 20 20">
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

            {{! ── FIX: দুটো CountrySelector-এ সঠিক @onChange দেওয়া হয়েছে ── }}
            <div class="relative">
              <label class="absolute -top-2.5 left-3 text-xs font-medium bg-white dark:bg-gray-900 px-1 text-indigo-600 dark:text-indigo-400 z-10">
                Country of Gameplaying
              </label>
              <CountrySelector @initialCode={{this.countryOfGameplayingCode}} @onChange={{this.handleCountryOfGameplaying}} />
            </div>
          </div>
        </div>

        {{! ── Logo Upload ── }}
        <div>
          <p class="text-xs font-semibold uppercase tracking-widest text-gray-400 dark:text-gray-500 mb-3">
            Team Logo
          </p>
          <div class="w-36">
            <ImageUploader @type="team_logo" @initialToken={{@team.team_logo}} @onChange={{this.onLogoUploaded}} />
          </div>
        </div>

        {{! ── Actions ── }}
        <div class="flex items-center justify-end gap-3 pt-2 border-t border-gray-100 dark:border-gray-800">
          <button type="button" class="px-4 py-2 text-sm font-medium rounded-lg text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors" {{on "click" @onClose}}>Cancel</button>
          <button type="submit" class="px-5 py-2 text-sm font-semibold rounded-lg bg-indigo-600 hover:bg-indigo-700 active:bg-indigo-800 text-white shadow-sm transition-colors">Update Team</button>
        </div>
      </form>
    </div>

    <AssignPlayer
      @searchQuery={{this.searchQuery}}
      @handlePlayerSearch={{this.handlePlayerSearch}}
      @onCloseMember={{this.onCloseMember}}
      @searchLoading={{this.playerSearchTask.isRunning}}
      @searchDropdownList={{this.searchDropdownList}}
      @addPlayerToTeam={{this.addPlayerToTeam}}
      @members={{this.members}}
      @captainId={{@members.captain}}
      @viceCaptainId={{@members.vice_captain}}
      @removePlayerFromTeam={{this.removePlayerFromTeam}}
      @submitPlayerForm={{this.submitPlayerForm}}
      @wicketKeeperIds={{@members.wicket_keeper}}
      @setPlayerRole={{this.setPlayerRole}}
    />
  </template>
}
