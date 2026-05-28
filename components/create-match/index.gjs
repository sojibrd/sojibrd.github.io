import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { service } from '@ember/service';
import { on } from '@ember/modifier';
import { fn, array } from '@ember/helper';
import { eq, gt, lte } from 'ember-truth-helpers';
import { debounce } from '@ember/runloop';
import config from 'spordium/config/environment';
import LocationPicker from '../auth/signup/LocationPicker';
import ImageUploader from '../ui/image-uploader';

const GAME_TYPES = ['T10', 'T20', 'One Day', 'Test', '5 Overs', '6-a-side / 8-a-side', 'Box Cricket', 'Super Sixes', 'Other'];
const BALL_TYPES = ['Leather Ball', 'Tape Tennis Ball', 'Tennis Ball'];

const FB_HOME_AWAY = ['Home', 'Away', 'Neutral'];
const FB_MATCH_TYPES = ['Friendly', 'League', 'Practise', 'Exhibition'];
const FB_MATCH_LEVELS = ['Amateur', 'Semi Professional', 'Professional'];
const FB_SUB_LEVELS = {
  Club: ['First Division', 'Second Division', 'Third Division', 'Other'],
  District: ['League', 'Knockout Cup', 'Other'],
  Divisional: ['Super League', 'Championship', 'Other'],
  National: ['Premier League', 'Federation Cup', 'Other'],
  International: ['Friendly', 'World Cup Qualifier', 'AFC', 'Other'],
  Other: ['Other'],
};
const FB_MULTI_SUB_LEVELS = {
  Amateur: [
    'Friendly',
    'Prize Money Game',
    'Inter School',
    'School Vs School',
    'Inter College',
    'College Vs College',
    'Inter University',
    'University Vs University',
    'Inter Area',
    'Area Vs Area',
    'Inter Club',
    'Club Vs Club',
    'Tournament',
    'Corporate',
    'Practice',
    'Exhibition',
    'League',
    'Inter City',
    'City Vs City',
    'Inter Division',
    'Division Vs Division',
    'Inter State',
    'State Vs State',
    'Inter Country',
    'Country Vs Country',
  ],
  'Semi Professional': [
    'Friendly',
    'Prize Money Game',
    'School Vs School',
    'College Vs College',
    'University Vs University',
    'Inter Area',
    'Area Vs Area',
    'Inter Club',
    'Club Vs Club',
    'Tournament',
    'Corporate',
    'Practice',
    'Exhibition',
    'League',
    'Inter City',
    'City Vs City',
    'Inter Division',
    'Division Vs Division',
    'Inter State',
    'State Vs State',
    'Inter Country',
    'Country Vs Country',
  ],
  Professional: [
    'Friendly',
    'Prize Money Game',
    'Inter Area',
    'Area Vs Area',
    'Inter Club',
    'Club Vs Club',
    'Tournament',
    'Practice',
    'Exhibition',
    'League',
    'Inter City',
    'City Vs City',
    'Inter Division',
    'Division Vs Division',
    'Inter State',
    'State Vs State',
    'Inter Country',
    'Country Vs Country',
  ],
};
const FB_AGE_GROUPS = ['U14', 'U16', 'U18', 'U21', 'U23', 'Open'];
const FB_SQUAD_SIZES = [5, 6, 7, 8, 9, 10, 11];
const FB_FIELD_TYPES = {
  surface: ['Grass', 'Turf', 'Mud', 'Sand'],
  environment: ['Indoor', 'Outdoor'],
};
const FB_FIELD_SIZES = ['105 Meters Long X 68 Meters Wide', '30 Meters X 20 Meters', '50 Meters X 35 Meters'];
const FB_GOAL_BAR_SIZES = [
  '24 Feet Wide X 8 Feet High (7.32 M X 2.44 M)',
  '21 Feet Wide X 7 Feet High (6.4 M X 2.1 M)',
  '12 Feet Wide X 6 Feet High Or 6.5 Feet X 4 Feet',
];
const FB_BALL_TYPES = [
  'Size 5 : 68–70 Cm (27–28 In)',
  'Size 4 : 63.5–66 Cm (25–26 In)',
  'Size 3 : 58.5–61 Cm (23–24 In)',
  'Size 2 : ~55 Cm',
  'Size 1 : ~47 Cm',
];
const FB_HALVES = [1, 2];
const FB_YES_NO = ['Yes', 'No'];
const FB_TIE_BREAKER_WAYS = ['Extra Time & Penalty', 'Extra Time', 'Penalty'];

function includes(arr, item) {
  return Array.isArray(arr) && arr.includes(item);
}

function teamInitials(name) {
  if (!name) return '?';
  return name
    .split(' ')
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase() ?? '')
    .join('');
}

// ── Location helpers ──────────────────────────────────────────────────────────
function emptyLocation() {
  return { lat: null, lng: null, country: '', countryCode: '', state: '', city: '', formattedAddress: '' };
}

async function reverseGeocode(lat, lng) {
  const res = await fetch(`https://maps.googleapis.com/maps/api/geocode/json?latlng=${lat},${lng}&key=${config.APP.GOOGLE_MAPS_API_KEY}`);
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

async function fetchPlaceDetails(placeId) {
  const url = `https://places.googleapis.com/v1/places/${placeId}?fields=id,displayName,location,addressComponents,formattedAddress&key=${config.APP.GOOGLE_MAPS_API_KEY}`;
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

const STEPS = [
  { number: 1, label: 'Your Team' },
  { number: 2, label: 'Opponent' },
  { number: 3, label: 'Match Setup' },
];

function omitEmpty(value) {
  if (value === null || value === undefined || value === '' || (typeof value === 'number' && isNaN(value))) {
    return undefined;
  }
  if (Array.isArray(value)) {
    const cleaned = value.map(omitEmpty).filter((v) => v !== undefined);
    return cleaned.length > 0 ? cleaned : undefined;
  }
  if (typeof value === 'object') {
    const result = {};
    for (const [k, v] of Object.entries(value)) {
      const cleaned = omitEmpty(v);
      if (cleaned !== undefined) result[k] = cleaned;
    }
    return Object.keys(result).length > 0 ? result : undefined;
  }
  return value;
}

export default class CreateMatchComponent extends Component {
  @service router;
  @service session;
  @service geolocation;
  @service api;
  @service toast;
  @service store;

  _coords = null;

  // ── Step management ────────────────────────────────────────────────────────
  @tracked currentStep = 1;

  // ── Step 1 : My Team ──────────────────────────────────────────────────────
  @tracked myTeams = [];
  @tracked isLoadingMyTeams = true;
  @tracked myTeamsError = null;
  @tracked selectedTeamId = null;
  @tracked myTeamInfo = null;
  @tracked isLoadingMyTeamInfo = false;
  @tracked myTeamPlayersExpanded = true;
  @tracked myTeamQuery = '';

  // ── Step 2 : Opponent ─────────────────────────────────────────────────────
  @tracked opponentQuery = '';
  @tracked opponentResults = [];
  @tracked isSearchingOpponent = false;
  @tracked suggestedTeams = [];
  @tracked isLoadingSuggested = false;
  @tracked selectedOpponentId = null;
  @tracked selectedOpponentName = '';
  @tracked selectedOpponentLogo = '';
  @tracked opponentTeamInfo = null;
  @tracked isLoadingOpponentInfo = false;
  @tracked opponentPlayersExpanded = true;

  // ── Step 3 : Configuration ────────────────────────────────────────────────
  @tracked _playersPerSide = 5;
  @tracked photoUploadUrl = null;
  @tracked matchDate = '';
  @tracked matchTime = '';
  @tracked gameType = '';
  @tracked showGameTypePicker = false;
  @tracked showBallTypePicker = false;
  @tracked matchName = '';
  @tracked matchOvers = '';
  @tracked matchPrize = '';
  @tracked ballType = '';
  @tracked phoneNumber = '';
  @tracked phoneCountry = { name: 'Bangladesh', code: 'bd', dial: '+880' };
  @tracked showCountryPicker = false;
  @tracked countrySearch = '';
  @tracked countriesList = [];
  @tracked fieldName = '';
  @tracked locationText = '';

  // ── Football-specific fields ──────────────────────────────────────────────
  @tracked homeAway = '';
  @tracked matchType = '';
  @tracked matchLevel = '';
  @tracked matchSubLevel = '';
  @tracked selectedSubLevels = [];
  @tracked ageGroup = '';
  @tracked _squadSize = 5;
  @tracked fieldType = '';
  @tracked fieldTypeEnv = '';
  @tracked fieldSize = '';
  @tracked fieldSizeCustom = '';
  @tracked goalBarSize = '';
  @tracked goalBarSizeCustom = '';
  @tracked footballBallType = '';
  @tracked bootAllowed = 'Yes';
  @tracked shoeAllowed = 'Yes';
  @tracked jerseyMandatory = 'No';
  @tracked matchDuration = 90;
  @tracked numberOfHalves = 2;
  @tracked tieBreaker = 'No';
  @tracked tieBreakerWays = '';
  @tracked extraTimeHalfDuration = 15;
  @tracked extraTimeNumberOfHalves = 2;
  @tracked coverPhotoUrl = null;
  @tracked note = '';
  @tracked showFieldSizeDropdown = false;
  @tracked showGoalBarDropdown = false;
  @tracked showBallTypeDropdown = false;

  // ── Location (Places autocomplete) ───────────────────────────────────────
  _locationData = emptyLocation();
  @tracked placeSuggestions = [];
  @tracked placesLoading = false;

  // ── Facility search ───────────────────────────────────────────────────────
  @tracked facilityQuery = '';
  @tracked facilityResults = [];
  @tracked facilitySearching = false;
  @tracked selectedFacility = null;
  @tracked showFacilityResults = false;

  get showPlaces() {
    return this.placeSuggestions.length > 0;
  }

  // ── UI state ──────────────────────────────────────────────────────────────
  @tracked errors = {};
  @tracked isSubmitting = false;

  constructor() {
    super(...arguments);
    this.loadMyTeams();
    this.loadCountries();
  }

  async loadCountries() {
    try {
      const res = await fetch('https://restcountries.com/v3.1/all?fields=name,idd,flags,cca2');
      const data = await res.json();
      this.countriesList = data
        .filter((c) => c.idd?.root && c.idd?.suffixes?.length)
        .map((c) => ({
          name: c.name.common,
          code: c.cca2.toLowerCase(),
          dial: c.idd.root + (c.idd.suffixes.length === 1 ? c.idd.suffixes[0] : ''),
          flag: c.flags?.png || '',
        }))
        .filter((c) => c.dial.length > 1)
        .sort((a, b) => a.name.localeCompare(b.name));

      this.autoSelectCountryFromLocation();
    } catch {
      // fallback — keep default BD
    }
  }

  async autoSelectCountryFromLocation() {
    try {
      const coords = await this.geolocation.getCoords();
      const geo = await reverseGeocode(coords.latitude, coords.longitude);
      if (geo?.countryCode) {
        const match = this.countriesList.find((c) => c.code === geo.countryCode.toLowerCase());
        if (match) this.phoneCountry = match;
      }
    } catch {
      // keep default BD
    }
  }

  async loadMyTeams() {
    this.isLoadingMyTeams = true;
    this.myTeamsError = null;
    try {
      const userId = this.session.currentUser?.user_id;
      const data = await this.api.post('/game/get_team_by_specific_creator/', {
        creator_id: userId,
        sport: (this.args.sport || 'Cricket').toLowerCase(),
      });
      this.myTeams = (data.data || []).map((t) => ({
        id: t.team_id,
        name: t.team_name,
        logo: this._teamLogoUrl(t.team_logo),
      }));
    } catch (err) {
      console.error('Failed to load my teams:', err);
      this.myTeamsError = 'Failed to load teams. Please try again.';
    } finally {
      this.isLoadingMyTeams = false;
    }
  }

  // ── Getters ───────────────────────────────────────────────────────────────
  get isFootball() {
    return (this.args.sport || '').toLowerCase() === 'football';
  }

  get footballSubLevelOptions() {
    return FB_SUB_LEVELS[this.matchLevel] ?? [];
  }

  get isMultiSelectLevel() {
    return this.matchLevel in FB_MULTI_SUB_LEVELS;
  }

  get multiSubLevelOptions() {
    return FB_MULTI_SUB_LEVELS[this.matchLevel] ?? [];
  }

  @action
  toggleSubLevel(opt) {
    const current = this.selectedSubLevels;
    if (current.includes(opt)) {
      this.selectedSubLevels = current.filter((s) => s !== opt);
    } else {
      this.selectedSubLevels = [...current, opt];
    }
  }

  @action
  toggleFieldSizeDropdown() {
    this.showFieldSizeDropdown = !this.showFieldSizeDropdown;
  }

  @action
  selectFieldSize(size) {
    this.fieldSize = size;
    this.fieldSizeCustom = size;
    this.showFieldSizeDropdown = false;
    if (this.errors.fieldSize) this.errors = { ...this.errors, fieldSize: null };
  }

  @action
  toggleGoalBarDropdown() {
    this.showGoalBarDropdown = !this.showGoalBarDropdown;
  }

  @action
  selectGoalBarSize(size) {
    this.goalBarSize = size;
    this.goalBarSizeCustom = size;
    this.showGoalBarDropdown = false;
    if (this.errors.goalBarSize) this.errors = { ...this.errors, goalBarSize: null };
  }

  @action
  toggleBallTypeDropdown() {
    this.showBallTypeDropdown = !this.showBallTypeDropdown;
  }

  @action
  selectBallTypeOption(type) {
    this.footballBallType = type;
    this.showBallTypeDropdown = false;
    if (this.errors.footballBallType) this.errors = { ...this.errors, footballBallType: null };
  }

  get selectedTeam() {
    return this.myTeams.find((t) => t.id === this.selectedTeamId) || null;
  }

  get filteredMyTeams() {
    const q = this.myTeamQuery.trim().toLowerCase();
    if (!q) return this.myTeams;
    return this.myTeams.filter((t) => t.name.toLowerCase().includes(q));
  }

  get selectedOpponent() {
    if (!this.selectedOpponentId) return null;
    return { id: this.selectedOpponentId, name: this.selectedOpponentName, logo: this.selectedOpponentLogo };
  }

  get steps() {
    return STEPS;
  }

  get progressPercent() {
    return ((this.currentStep - 1) / (STEPS.length - 1)) * 100;
  }

  // ── Step navigation ───────────────────────────────────────────────────────
  @action
  goNext() {
    const errs = {};
    if (this.currentStep === 1) {
      if (!this.selectedTeamId) {
        errs.team = 'Please select your team to continue';
      } else {
        const count = this.myTeamInfo?.players?.length ?? 0;
        if (count < 5) errs.team = `Your team must have at least 5 players (currently ${count})`;
      }
    } else if (this.currentStep === 2) {
      if (!this.selectedOpponentId) {
        errs.opponent = 'Please select an opponent team';
      } else {
        const count = this.opponentTeamInfo?.players?.length ?? 0;
        if (count < 5) {
          errs.opponent = `Opponent team must have at least 5 players (currently ${count})`;
        } else if (this.duplicatePlayerIds.size > 0) {
          errs.opponent = `${this.duplicatePlayerIds.size} player(s) exist in both teams. Please select a different opponent.`;
        }
      }
    }
    this.errors = errs;
    if (Object.keys(errs).length > 0) return;
    const nextStep = this.currentStep + 1;
    this.currentStep = nextStep;
    window.scrollTo({ top: 0, behavior: 'smooth' });
    if (nextStep === 2 && this.suggestedTeams.length === 0) {
      this.loadSuggestedTeams();
    }
  }

  @action
  goBack() {
    if (this.currentStep === 1) {
      this.router.transitionTo('match.index');
    } else {
      this.currentStep = this.currentStep - 1;
      window.scrollTo({ top: 0, behavior: 'smooth' });
    }
  }

  @action
  goToStep(step) {
    // only allow going back to completed steps
    if (step < this.currentStep) {
      this.currentStep = step;
      window.scrollTo({ top: 0, behavior: 'smooth' });
    }
  }

  // ── Step 1 actions ────────────────────────────────────────────────────────
  @action
  async selectTeam(teamId) {
    this.selectedTeamId = teamId;
    this.myTeamInfo = null;
    if (this.errors.team) this.errors = { ...this.errors, team: null };

    this.isLoadingMyTeamInfo = true;
    try {
      const data = await this.api.post('/game/team_and_player_info/', { team_id: teamId });
      this.myTeamInfo = this._normalizeTeamInfo(data);
      if (this.myTeamInfo.teamLogo) {
        this.myTeams = this.myTeams.map((t) => (t.id === teamId ? { ...t, logo: t.logo || this.myTeamInfo.teamLogo } : t));
      }
    } catch (err) {
      console.error('Failed to load team info:', err);
    } finally {
      this.isLoadingMyTeamInfo = false;
    }
  }

  // ── Step 2 actions ────────────────────────────────────────────────────────
  async loadSuggestedTeams() {
    this.isLoadingSuggested = true;
    try {
      let latitude = 23.8103;
      let longitude = 90.4125;
      try {
        if (!this._coords) {
          this._coords = await this.geolocation.getCoords();
        }
        latitude = this._coords.latitude;
        longitude = this._coords.longitude;
      } catch {
        console.warn('Geolocation failed, using default coords (Dhaka)');
      }
      const sportType = (this.args.sport || 'Cricket').toLowerCase();
      const url = `${config.APP.SEARCH_API_HOST}/search/cricket-team-search/?search_data=a&latitude=${latitude}&longitude=${longitude}&limit=10&offset=0&page=1&country_code=BD&sport_type=${sportType}`;
      const response = await fetch(url, {
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = await response.json();

      this.suggestedTeams = (data.results || [])
        .filter((t) => t.team_id !== this.selectedTeamId)
        .map((t) => ({
          id: t.team_id,
          name: t.team_name,
          logo: this._teamLogoUrl(t.team_logo),
        }));
    } catch (err) {
      console.error('Failed to load suggested teams:', err);
    } finally {
      this.isLoadingSuggested = false;
    }
  }

  @action
  onMyTeamSearch(event) {
    this.myTeamQuery = event.target.value;
  }

  @action
  onOpponentInput(event) {
    this.opponentQuery = event.target.value;
    if (!this.opponentQuery.trim()) {
      this.opponentResults = [];
      this.isSearchingOpponent = false;
      return;
    }
    this.isSearchingOpponent = true;
    debounce(this, this._performOpponentSearch, 400);
  }

  async _performOpponentSearch() {
    const query = this.opponentQuery;
    if (!query.trim()) return;
    try {
      if (!this._coords) {
        this._coords = await this.geolocation.getCoords();
      }
      const { latitude, longitude } = this._coords;
      const sportType = (this.args.sport || 'Cricket').toLowerCase();
      const url = `${config.APP.SEARCH_API_HOST}/search/cricket-team-search/?search_data=${encodeURIComponent(query)}&latitude=${latitude}&longitude=${longitude}&limit=10&offset=0&page=1&country_code=BD&sport_type=${sportType}`;
      const response = await fetch(url, {
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = await response.json();
      // discard stale result if query changed mid-flight
      if (this.opponentQuery !== query) return;
      this.opponentResults = (data.results || [])
        .filter((t) => t.team_id !== this.selectedTeamId)
        .map((t) => ({
          id: t.team_id,
          name: t.team_name,
          logo: this._teamLogoUrl(t.team_logo),
        }));
    } catch (err) {
      console.error('Opponent search error:', err);
      if (this.opponentQuery === query) this.opponentResults = [];
    } finally {
      if (this.opponentQuery === query) this.isSearchingOpponent = false;
    }
  }

  _teamLogoUrl(path) {
    if (!path) return null;
    if (path.startsWith('http')) return path;
    const s3 = config.APP.S3_BUCKET_URL || 'https://spordium.s3.ap-southeast-1.amazonaws.com';
    const clean = path.startsWith('/') ? path.slice(1) : path;
    return `${s3}/${clean}`;
  }

  _normalizeTeamInfo(raw) {
    const info = raw?.data ?? raw ?? {};
    const players = (info.team_players_info || []).map((p) => ({
      id: p.player_id,
      name: `${p.PlayerName?.first_name ?? ''} ${p.PlayerName?.last_name ?? ''}`.trim(),
      logo: this._teamLogoUrl(p.player_primary_pic),
      role: p.has_skill_left_handed_batsman ? 'Left Handed Batsman' : 'Batsman',
    }));
    return {
      teamName: info.team_name,
      teamLogo: this._teamLogoUrl(info.team_logo),
      players,
    };
  }

  @action
  async selectOpponent(team) {
    this.selectedOpponentId = team.id;
    this.selectedOpponentName = team.name;
    this.selectedOpponentLogo = team.logo;
    this.opponentTeamInfo = null;
    if (this.errors.opponent) this.errors = { ...this.errors, opponent: null };

    this.isLoadingOpponentInfo = true;
    try {
      const data = await this.api.post('/game/team_and_player_info/', { team_id: team.id });
      this.opponentTeamInfo = this._normalizeTeamInfo(data);
    } catch (err) {
      console.error('Failed to load opponent team info:', err);
    } finally {
      this.isLoadingOpponentInfo = false;
    }
  }

  @action
  clearOpponent() {
    this.selectedOpponentId = null;
    this.selectedOpponentName = '';
    this.selectedOpponentLogo = '';
    this.opponentTeamInfo = null;
    this.opponentQuery = '';
    this.opponentResults = [];
  }

  @action
  toggleMyTeamPlayers(e) {
    e.stopPropagation();
    this.myTeamPlayersExpanded = !this.myTeamPlayersExpanded;
  }

  @action
  toggleOpponentPlayers(e) {
    e.stopPropagation();
    this.opponentPlayersExpanded = !this.opponentPlayersExpanded;
  }

  // ── Step 3 actions ────────────────────────────────────────────────────────
  @action
  onPhotoUploaded(result) {
    this.photoUploadUrl = result?.objectToken ?? null;
  }

  @action
  onCoverPhotoUploaded(result) {
    this.coverPhotoUrl = result?.objectToken ?? null;
  }

  @action
  openPicker(event) {
    event.currentTarget.querySelector('input')?.showPicker?.();
  }

  @action
  toggleGameTypePicker() {
    this.showGameTypePicker = !this.showGameTypePicker;
  }

  @action
  selectGameType(type) {
    this.gameType = type;
    this.showGameTypePicker = false;
    if (this.errors.gameType) this.errors = { ...this.errors, gameType: null };
  }

  @action
  toggleBallTypePicker() {
    this.showBallTypePicker = !this.showBallTypePicker;
  }

  @action
  selectBallType(type) {
    this.ballType = type;
    this.showBallTypePicker = false;
    if (this.errors.ballType) this.errors = { ...this.errors, ballType: null };
  }

  @action
  onPlayersPerSideChange(event) {
    this._playersPerSide = Number(event.target.value);
  }

  @action
  onSquadSizeChange(event) {
    this._squadSize = Number(event.target.value);
  }

  get duplicatePlayerIds() {
    const myIds = new Set((this.myTeamInfo?.players ?? []).map((p) => p.id));
    const dupIds = new Set();
    for (const p of this.opponentTeamInfo?.players ?? []) {
      if (myIds.has(p.id)) dupIds.add(p.id);
    }
    return dupIds;
  }

  isDuplicate = (playerId) => {
    return this.duplicatePlayerIds.has(playerId);
  };

  get opponentReadyForNext() {
    return (
      Boolean(this.selectedOpponentId) &&
      (this.myTeamInfo?.players?.length ?? 0) >= 5 &&
      (this.opponentTeamInfo?.players?.length ?? 0) >= 5 &&
      this.duplicatePlayerIds.size === 0
    );
  }

  get maxPlayersPerSide() {
    const myCount = this.myTeamInfo?.players?.length ?? 0;
    const oppCount = this.opponentTeamInfo?.players?.length ?? 0;
    if (!myCount || !oppCount) return 0;
    return Math.min(myCount, oppCount);
  }

  get playersPerSide() {
    const max = this.maxPlayersPerSide;
    return max > 0 ? Math.min(this._playersPerSide, max) : this._playersPerSide;
  }

  get playersPerSideOptions() {
    const max = Math.max(5, this.maxPlayersPerSide);
    const opts = [];
    for (let i = 5; i <= max; i++) opts.push(i);
    return opts;
  }

  get footballSquadSize() {
    const max = this.footballMaxSquadSize;
    return max > 0 ? Math.min(this._squadSize, max) : this._squadSize;
  }

  get footballMaxSquadSize() {
    const myCount = this.myTeamInfo?.players?.length ?? 0;
    const oppCount = this.opponentTeamInfo?.players?.length ?? 0;
    if (!myCount || !oppCount) return 0;
    return Math.min(myCount, oppCount, 11);
  }

  get extraTimeHalfDurationCalc() {
    const dur = Number(this.extraTimeHalfDuration) || 0;
    const halves = Number(this.extraTimeNumberOfHalves) || 1;
    return Math.floor(dur / halves);
  }

  get showExtraTimeDuration() {
    return this.tieBreakerWays === 'Extra Time & Penalty' || this.tieBreakerWays === 'Extra Time';
  }

  get halfDuration() {
    const dur = Number(this.matchDuration) || 0;
    const halves = Number(this.numberOfHalves) || 1;
    return Math.floor(dur / halves);
  }

  get footballSquadSizeOptions() {
    const max = Math.max(5, this.footballMaxSquadSize);
    const opts = [];
    for (let i = 5; i <= max; i++) opts.push(i);
    return opts;
  }

  get filteredCountries() {
    const q = this.countrySearch.toLowerCase().trim();
    if (!q) return this.countriesList;
    return this.countriesList.filter((c) => c.name.toLowerCase().includes(q) || c.dial.includes(q));
  }

  @action
  toggleCountryPicker() {
    this.showCountryPicker = !this.showCountryPicker;
    if (this.showCountryPicker) this.countrySearch = '';
  }

  @action
  selectCountry(country) {
    this.phoneCountry = country;
    this.showCountryPicker = false;
    this.countrySearch = '';
  }

  @action
  onCountrySearch(event) {
    this.countrySearch = event.target.value;
  }

  @action
  setField(field, event) {
    const value = event.target.value;
    this[field] = value;
    if (field === 'matchLevel') {
      this.matchSubLevel = '';
      this.selectedSubLevels = [];
    }
    if (this.errors[field]) {
      this.errors = { ...this.errors, [field]: null };
    }
    if (field === 'locationText') {
      debounce(this, '_performPlacesSearch', value, 400);
    }
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
      // Stale-result guard: discard if user has already typed something different
      if (this.locationText !== input) return;
      const data = await res.json();
      this.placeSuggestions = (data?.suggestions ?? [])
        .filter((s) => s.placePrediction)
        .map((s) => ({
          description: s.placePrediction.text?.text ?? '',
          placeId: s.placePrediction.placeId,
        }));
    } catch {
      this.placeSuggestions = [];
    } finally {
      this.placesLoading = false;
    }
  }

  _commitLocation(text, locData) {
    this._locationData = locData;
    this.locationText = text;
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

  // ── Facility search actions ───────────────────────────────────────────────
  @action
  onFacilityInput(event) {
    this.facilityQuery = event.target.value;
    this.showFacilityResults = true;
    if (!this.facilityQuery.trim()) {
      this.facilityResults = [];
      return;
    }
    debounce(this, '_searchFacilities', 350);
  }

  @action
  onFacilityFocus() {
    this.showFacilityResults = true;
    if (!this.facilityResults.length) {
      this._searchFacilities();
    }
  }

  @action
  onFacilityBlur() {
    setTimeout(() => {
      this.showFacilityResults = false;
    }, 200);
  }

  async _searchFacilities() {
    const query = this.facilityQuery.trim();
    this.facilitySearching = true;
    try {
      const params = { country_code: 'bd', limit: 10 };
      if (query) params.search_text = query;
      const results = await this.store.query('facility', params);
      if (this.facilityQuery.trim() === query) {
        this.facilityResults = results.slice();
        this.showFacilityResults = true;
      }
    } catch {
      this.facilityResults = [];
    } finally {
      this.facilitySearching = false;
    }
  }

  @action
  selectFacility(facility) {
    this.selectedFacility = facility;
    this.facilityQuery = facility.fac_name;
    this.showFacilityResults = false;
    this.fieldName = facility.fac_name;
    this.locationText = facility.fac_address;
    this._locationData = {
      ...emptyLocation(),
      city: facility.fac_city || '',
      country: facility.fac_country || '',
      state: facility.fac_division || '',
    };
    if (this.errors.fieldName) this.errors = { ...this.errors, fieldName: null };
    if (this.errors.locationText) this.errors = { ...this.errors, locationText: null };
  }

  @action
  clearFacility() {
    this.selectedFacility = null;
    this.facilityQuery = '';
    this.facilityResults = [];
    this.showFacilityResults = false;
    this.fieldName = '';
    this.locationText = '';
    this._locationData = emptyLocation();
  }

  _facilityLogoUrl = (path) => {
    if (!path) return null;
    if (path.startsWith('http')) return path;
    return `https://ag-khela.s3.ap-south-1.amazonaws.com/${path}`;
  };

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
  async handleSubmit(event) {
    event.preventDefault();

    // ── Validation ───────────────────────────────────────────────────────
    const cricketRequired = ['matchDate', 'matchTime', 'gameType', 'matchName', 'matchOvers', 'ballType', 'phoneNumber', 'fieldName', 'locationText'];
    const footballRequired = [
      'matchDate',
      'matchTime',
      'matchName',
      'phoneNumber',
      'fieldName',
      'locationText',
      'homeAway',
      'matchType',
      'matchLevel',
      'ageGroup',
      'fieldType',
      'fieldSize',
      'goalBarSize',
      'footballBallType',
      'jerseyMandatory',
    ];
    const required = this.isFootball ? footballRequired : cricketRequired;
    const errs = {};
    for (const field of required) {
      const v = this[field];
      if (typeof v === 'string' ? !v.trim() : !v) errs[field] = 'Required';
    }
    if (this.isFootball && !this.footballSquadSize) errs.squadSize = 'Required';

    // ── Team player validations ───────────────────────────────────────────
    const myPlayers = this.myTeamInfo?.players ?? [];
    const opponentPlayers = this.opponentTeamInfo?.players ?? [];

    if (myPlayers.length < 5) {
      this.toast.error(`Your team must have at least 5 players (currently ${myPlayers.length})`);
      return;
    }
    if (opponentPlayers.length < 5) {
      this.toast.error(`Opponent team must have at least 5 players (currently ${opponentPlayers.length})`);
      return;
    }

    const myPlayerIds = new Set(myPlayers.map((p) => p.id));
    const duplicates = opponentPlayers.filter((p) => myPlayerIds.has(p.id));
    if (duplicates.length > 0) {
      const names = duplicates.map((p) => p.name).join(', ');
      this.toast.error(`Same player(s) in both teams: ${names}`);
      return;
    }

    this.errors = errs;
    if (Object.keys(errs).length > 0) return;

    // ── Build payload ─────────────────────────────────────────────────────
    const loc = this._locationData;
    const lat = loc.lat ?? 0;
    const lng = loc.lng ?? 0;
    const user = this.session.currentUser ?? {};

    const gameConfig = this.isFootball
      ? {
          match_price: this.matchPrize || '',
          number_of_player_in_one_side: this.footballSquadSize,
          home_away_status: this.homeAway,
          age_group: this.ageGroup,
          field_type: this.fieldType,
          field_type_environment: this.fieldTypeEnv,
          field_size: this.fieldSizeCustom || this.fieldSize,
          goal_bar_size: this.goalBarSizeCustom || this.goalBarSize,
          boot_allowed: this.bootAllowed === 'Yes',
          shoe_allowed: this.shoeAllowed === 'Yes',
          jersey_mandatory: this.jerseyMandatory === 'Yes',
          match_duration: Number(this.matchDuration),
          number_of_halves: Number(this.numberOfHalves),
          half_duration: Number(this.halfDuration),
          extra_time_half_duration: Number(this.extraTimeHalfDurationCalc),
          tie_breaker: this.tieBreaker === 'Yes',
          tie_breaker_ways: this.tieBreakerWays,
        }
      : {
          over: Number(this.matchOvers),
          match_prize: this.matchPrize || '',
          number_of_player_in_one_side: this.playersPerSide,
        };

    const payload = {
      Team1: this.selectedTeamId,
      Team2: this.selectedOpponentId,
      Type_Of_Game: this.isFootball ? this.matchType : this.gameType,
      Game_Configuration: gameConfig,
      Game_DateTime: `${this.matchDate}T${this.matchTime}:00.000`,
      Game_Name: this.matchName.trim(),
      Game_Location: {
        country: loc.country || '',
        state: loc.state || '',
        division: loc.state || '',
        city: loc.city || '',
        place: loc.city || '',
        address: this.locationText.trim(),
      },
      countrycode: loc.countryCode || 'BD',
      latitude: lat,
      longitude: lng,
      GameOwner_Phone: `${this.phoneCountry.dial}${this.phoneNumber.trim()}`,
      GameOwner_email: user.user_email || '',
      Game_LiveLink: {
        maplink: `https://www.google.com/maps/search/?api=1&query=${lat},${lng}`,
      },
      sportsballtype: this.isFootball ? this.footballBallType : this.ballType,
      gamefield_name: this.fieldName.trim(),
      sportstype: (this.args.sport || 'Cricket').toLowerCase(),
      ...(this.photoUploadUrl ? { game_logo: this.photoUploadUrl } : {}),
      ...(this.coverPhotoUrl ? { cover_photo: this.coverPhotoUrl } : {}),
      ...(this.isFootball && this.selectedFacility ? { platform_facility: this.selectedFacility.id } : {}),
      ...(this.isFootball
        ? {
            match_level: {
              match_level: this.matchLevel,
              match_sub_level: this.isMultiSelectLevel ? this.selectedSubLevels : this.matchSubLevel ? [this.matchSubLevel] : [],
            },
          }
        : {}),
      note: this.note,
    };

    // ── Submit ────────────────────────────────────────────────────────────
    const cleanPayload = omitEmpty(payload);
    console.log('[MatchCreation] payload:', JSON.stringify(cleanPayload, null, 2));
    this.isSubmitting = true;
    try {
      const response = await this.api.post('/game/MatchCreation/', cleanPayload);
      this.toast.success('Match created successfully!');
      const gameId = response?.data?.game_id || response?.game_id || response?.id;
      if (gameId) {
        this.router.transitionTo('match.match-details', { queryParams: { gameid: gameId } });
      } else {
        this.router.transitionTo('match.index');
      }
    } catch (err) {
      const msg = err?.payload?.message || err?.message || 'Failed to create match';
      this.toast.error(msg);
    } finally {
      this.isSubmitting = false;
    }
  }

  <template>
    <div class="min-h-screen bg-slate-900">

      {{! ── Top bar ── }}
      <div class="bg-slate-900/90 backdrop-blur-sm border-b border-slate-700/50 sticky top-0 z-20">
        <div class="max-w-2xl mx-auto px-4 sm:px-6 py-4 flex items-center gap-4">
          <button
            type="button"
            class="flex items-center justify-center w-9 h-9 rounded-xl bg-slate-800 hover:bg-slate-700 border border-slate-700/60 text-gray-400 hover:text-white transition-all flex-shrink-0"
            {{on "click" this.goBack}}
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
            </svg>
          </button>
          <div class="flex-1 min-w-0">
            <h1 class="text-white text-lg font-bold truncate">Create a Match</h1>
            <p class="text-gray-500 text-xs">Step {{this.currentStep}} of {{this.steps.length}}</p>
          </div>
        </div>

        {{! ── Step progress bar ── }}
        <div class="max-w-2xl mx-auto px-4 sm:px-6 pb-4">
          {{! Step labels }}
          <div class="flex items-center justify-between mb-2">
            {{#each this.steps as |step|}}
              <button type="button" class="flex items-center gap-2 group" {{on "click" (fn this.goToStep step.number)}}>
                <div
                  class="w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold transition-all
                    {{if
                      (eq this.currentStep step.number)
                      'bg-cyan-500 text-white shadow-lg shadow-cyan-500/30'
                      (if
                        (lte step.number this.currentStep)
                        'bg-cyan-500/20 text-cyan-400 border border-cyan-500/40'
                        'bg-slate-700 text-gray-500 border border-slate-600/50'
                      )
                    }}"
                >
                  {{#if (lte step.number this.currentStep)}}
                    {{#if (eq this.currentStep step.number)}}
                      {{step.number}}
                    {{else}}
                      <svg class="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 20 20">
                        <path
                          fill-rule="evenodd"
                          d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
                          clip-rule="evenodd"
                        />
                      </svg>
                    {{/if}}
                  {{else}}
                    {{step.number}}
                  {{/if}}
                </div>
                <span
                  class="text-xs font-medium hidden sm:block transition-colors
                    {{if (eq this.currentStep step.number) 'text-white' (if (lte step.number this.currentStep) 'text-cyan-400' 'text-gray-600')}}"
                >
                  {{step.label}}
                </span>
              </button>

              {{! Connector line (between steps) }}
              {{#if (lte step.number 2)}}
                <div class="flex-1 h-px mx-3 {{if (gt this.currentStep step.number) 'bg-cyan-500/50' 'bg-slate-700/60'}}">
                </div>
              {{/if}}
            {{/each}}
          </div>
        </div>
      </div>

      {{! ── Step content ── }}
      <div class="max-w-2xl mx-auto px-4 sm:px-6 py-8">

        {{! ════ STEP 1 : Select Your Team ════ }}
        {{#if (eq this.currentStep 1)}}
          <div class="space-y-5">
            <div>
              <h2 class="text-white text-xl font-bold">Select Your Team</h2>
              <p class="text-gray-500 text-sm mt-1">Choose the team you'll be playing with</p>
            </div>

            {{#if this.errors.team}}
              <div class="flex items-center gap-2 px-4 py-3 bg-red-500/10 border border-red-500/20 rounded-xl text-red-400 text-sm">
                <svg class="w-4 h-4 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                  <path
                    fill-rule="evenodd"
                    d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z"
                    clip-rule="evenodd"
                  />
                </svg>
                {{this.errors.team}}
              </div>
            {{/if}}

            {{! Search my teams }}
            {{#if this.myTeams.length}}
              <div class="relative">
                <svg
                  class="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500 pointer-events-none"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
                <input
                  type="text"
                  placeholder="Search your teams..."
                  value={{this.myTeamQuery}}
                  class="w-full bg-slate-800/60 border border-slate-700/50 rounded-xl pl-10 pr-4 py-2.5 text-sm text-white placeholder-gray-500 focus:outline-none focus:border-cyan-500/50 transition-colors"
                  {{on "input" this.onMyTeamSearch}}
                />
              </div>
            {{/if}}

            {{! Team cards }}
            {{#if this.isLoadingMyTeams}}
              <div class="space-y-3">
                {{#each (array 1 2 3) as |_|}}
                  <div class="rounded-2xl border border-slate-700/50 bg-slate-800/40 p-5 animate-pulse flex items-center gap-4">
                    <div class="w-5 h-5 rounded-full bg-slate-700 flex-shrink-0"></div>
                    <div class="w-12 h-12 rounded-xl bg-slate-700 flex-shrink-0"></div>
                    <div class="flex-1 space-y-2">
                      <div class="h-4 bg-slate-700 rounded w-32"></div>
                      <div class="h-3 bg-slate-700 rounded w-20"></div>
                    </div>
                  </div>
                {{/each}}
              </div>
            {{else if this.myTeamsError}}
              <div class="py-10 text-center bg-slate-800/40 rounded-2xl border border-slate-700/50">
                <div class="w-12 h-12 mx-auto mb-3 bg-red-500/10 rounded-full flex items-center justify-center">
                  <svg class="w-6 h-6 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                    />
                  </svg>
                </div>
                <p class="text-gray-400 text-sm font-medium">{{this.myTeamsError}}</p>
                <button
                  type="button"
                  class="mt-3 px-4 py-2 bg-slate-700 hover:bg-slate-600 text-white text-xs rounded-xl transition-colors"
                  {{on "click" this.loadMyTeams}}
                >
                  Try Again
                </button>
              </div>
            {{else if this.myTeams.length}}
              <div class="space-y-3">
                {{#each this.filteredMyTeams as |team|}}
                  <div
                    class="rounded-2xl border overflow-hidden transition-all
                      {{if
                        (eq this.selectedTeamId team.id)
                        'border-cyan-500/60 bg-slate-800/80 shadow-lg shadow-cyan-500/10'
                        'border-slate-700/50 bg-slate-800/40 hover:border-slate-600/60'
                      }}"
                  >

                    <button type="button" class="w-full flex items-center gap-4 px-5 py-4 text-left" {{on "click" (fn this.selectTeam team.id)}}>
                      <div
                        class="w-5 h-5 rounded-full border-2 flex items-center justify-center flex-shrink-0 transition-all
                          {{if (eq this.selectedTeamId team.id) 'border-cyan-500' 'border-slate-600'}}"
                      >
                        {{#if (eq this.selectedTeamId team.id)}}
                          <div class="w-2.5 h-2.5 rounded-full bg-cyan-500"></div>
                        {{/if}}
                      </div>
                      <div class="w-12 h-12 rounded-xl flex-shrink-0 shadow-md">
                        {{#if team.logo}}
                          <div class="w-full h-full rounded-xl overflow-hidden bg-white p-1.5">
                            <img src={{team.logo}} alt={{team.name}} class="w-full h-full object-contain" />
                          </div>
                        {{else}}
                          <div class="w-full h-full rounded-xl bg-gradient-to-br from-cyan-600 to-blue-700 flex items-center justify-center">
                            <span class="text-white text-xs font-bold">{{teamInitials team.name}}</span>
                          </div>
                        {{/if}}
                      </div>
                      <p class="text-white font-semibold truncate flex-1">{{team.name}}</p>
                      {{#if (eq this.selectedTeamId team.id)}}
                        {{#if this.isLoadingMyTeamInfo}}
                          <div class="w-4 h-4 border-2 border-cyan-500 border-t-transparent rounded-full animate-spin flex-shrink-0"></div>
                        {{else if this.myTeamInfo}}
                          <button
                            type="button"
                            class="flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-slate-700/60 hover:bg-slate-700 text-gray-400 hover:text-white text-xs transition-all flex-shrink-0"
                            {{on "click" this.toggleMyTeamPlayers}}
                          >
                            <span>{{this.myTeamInfo.players.length}} players</span>
                            <svg
                              class="w-3.5 h-3.5 transition-transform {{if this.myTeamPlayersExpanded 'rotate-180' ''}}"
                              fill="none"
                              stroke="currentColor"
                              viewBox="0 0 24 24"
                            >
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                            </svg>
                          </button>
                        {{/if}}
                      {{/if}}
                    </button>

                    {{#if (eq this.selectedTeamId team.id)}}
                      {{#if this.isLoadingMyTeamInfo}}
                        <div class="border-t border-slate-700/40 px-5 py-3 space-y-2.5">
                          {{#each (array 1 2 3) as |_|}}
                            <div class="flex items-center gap-3 animate-pulse">
                              <div class="w-8 h-8 rounded-full bg-slate-700 flex-shrink-0"></div>
                              <div class="flex-1 space-y-1.5">
                                <div class="h-3 bg-slate-700 rounded w-28"></div>
                                <div class="h-2.5 bg-slate-700 rounded w-16"></div>
                              </div>
                            </div>
                          {{/each}}
                        </div>
                      {{else if this.myTeamPlayersExpanded}}
                        {{#if this.myTeamInfo.players.length}}
                          <div class="border-t border-slate-700/40 px-5 py-3 space-y-2 max-h-52 overflow-y-auto">
                            {{#each this.myTeamInfo.players as |player index|}}
                              <div class="flex items-center gap-3 py-0.5">
                                <span
                                  class="w-5 h-5 rounded-full bg-slate-700 text-gray-500 text-[10px] font-bold flex items-center justify-center flex-shrink-0"
                                >
                                  {{index}}
                                </span>
                                <div class="w-8 h-8 rounded-full bg-slate-700 overflow-hidden flex-shrink-0">
                                  <img
                                    src={{player.logo}}
                                    alt={{player.name}}
                                    class="w-full h-full object-cover"
                                    onerror="this.src='/images/default-player.png'"
                                  />
                                </div>
                                <div class="min-w-0 flex-1">
                                  <p class="text-white text-xs font-medium truncate">{{player.name}}</p>
                                  <p class="text-gray-500 text-[10px]">{{player.role}}</p>
                                </div>
                                {{#if (this.isDuplicate player.id)}}
                                  <span class="text-[10px] font-semibold text-red-400 bg-red-400/10 px-1.5 py-0.5 rounded flex-shrink-0">Conflict</span>
                                {{/if}}
                              </div>
                            {{/each}}
                          </div>
                        {{/if}}
                      {{/if}}
                    {{/if}}
                  </div>
                {{/each}}
                {{#unless this.filteredMyTeams.length}}
                  <div class="py-8 text-center text-gray-500 text-sm">
                    No teams match "{{this.myTeamQuery}}"
                  </div>
                {{/unless}}
              </div>
            {{else}}
              <div class="py-12 text-center bg-slate-800/40 rounded-2xl border border-slate-700/50">
                <div class="w-14 h-14 mx-auto mb-4 bg-slate-700/50 rounded-2xl flex items-center justify-center">
                  <svg class="w-7 h-7 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="1.5"
                      d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z"
                    />
                  </svg>
                </div>
                <p class="text-gray-400 font-medium">No teams found</p>
                <p class="text-gray-600 text-sm mt-1">Create a team first to organize a match</p>
              </div>
            {{/if}}

            {{! Next button }}
            <button
              type="button"
              class="w-full flex items-center justify-center gap-2 py-3.5 rounded-2xl font-semibold text-sm transition-all
                {{if
                  this.selectedTeamId
                  'bg-cyan-500 hover:bg-cyan-400 text-white shadow-lg shadow-cyan-500/25 active:scale-[0.98]'
                  'bg-slate-800 text-gray-500 border border-slate-700/50 cursor-not-allowed'
                }}"
              {{on "click" this.goNext}}
            >
              Continue
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
              </svg>
            </button>
          </div>

          {{! ════ STEP 2 : Select Opponent ════ }}
        {{else if (eq this.currentStep 2)}}
          <div class="space-y-5">
            <div>
              <h2 class="text-white text-xl font-bold">Find Opponent</h2>
              <p class="text-gray-500 text-sm mt-1">Search and select the opposing team</p>
            </div>

            {{! Your team chip (reminder) }}
            {{#if this.selectedTeam}}
              <div class="flex items-center gap-3 px-4 py-3 bg-slate-800/60 border border-slate-700/40 rounded-xl">
                <div class="w-8 h-8 rounded-lg flex-shrink-0">
                  {{#if this.selectedTeam.logo}}
                    <div class="w-full h-full rounded-lg overflow-hidden bg-white p-1">
                      <img src={{this.selectedTeam.logo}} alt={{this.selectedTeam.name}} class="w-full h-full object-contain" />
                    </div>
                  {{else}}
                    <div class="w-full h-full rounded-lg bg-gradient-to-br from-cyan-600 to-blue-700 flex items-center justify-center">
                      <span class="text-white text-[10px] font-bold">{{teamInitials this.selectedTeam.name}}</span>
                    </div>
                  {{/if}}
                </div>
                <div class="flex-1 min-w-0">
                  <p class="text-xs text-gray-500">Your team</p>
                  <p class="text-white text-sm font-semibold truncate">{{this.selectedTeam.name}}</p>
                </div>
                <span class="text-slate-500 text-xl font-bold px-3">VS</span>
                {{#if this.selectedOpponent}}
                  <div class="flex items-center gap-2 flex-1 justify-end min-w-0">
                    <div class="min-w-0 text-right">
                      <p class="text-xs text-gray-500">Opponent</p>
                      <p class="text-white text-sm font-semibold truncate">{{this.selectedOpponent.name}}</p>
                    </div>
                    <div class="w-8 h-8 rounded-lg flex-shrink-0">
                      {{#if this.selectedOpponent.logo}}
                        <div class="w-full h-full rounded-lg overflow-hidden bg-white p-1">
                          <img src={{this.selectedOpponent.logo}} alt={{this.selectedOpponent.name}} class="w-full h-full object-contain" />
                        </div>
                      {{else}}
                        <div class="w-full h-full rounded-lg bg-gradient-to-br from-violet-600 to-purple-700 flex items-center justify-center">
                          <span class="text-white text-[10px] font-bold">{{teamInitials this.selectedOpponent.name}}</span>
                        </div>
                      {{/if}}
                    </div>
                  </div>
                {{else}}
                  <div class="flex-1 text-right">
                    <p class="text-gray-600 text-sm">Select opponent →</p>
                  </div>
                {{/if}}
              </div>
            {{/if}}

            {{#if this.errors.opponent}}
              <div class="flex items-center gap-2 px-4 py-3 bg-red-500/10 border border-red-500/20 rounded-xl text-red-400 text-sm">
                <svg class="w-4 h-4 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                  <path
                    fill-rule="evenodd"
                    d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z"
                    clip-rule="evenodd"
                  />
                </svg>
                {{this.errors.opponent}}
              </div>
            {{/if}}

            {{! Search input }}
            <div class="relative">
              <svg
                class="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500 pointer-events-none"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
              </svg>
              <input
                type="text"
                placeholder="Search team name..."
                value={{this.opponentQuery}}
                class="w-full bg-slate-800/60 border border-slate-700/50 rounded-2xl pl-11 pr-4 py-3.5 text-sm text-white placeholder-gray-600 focus:outline-none focus:border-cyan-500/60 focus:ring-1 focus:ring-cyan-500/20 transition-all"
                {{on "input" this.onOpponentInput}}
              />
            </div>

            {{! Results }}
            {{#if this.isSearchingOpponent}}
              <div class="py-10 text-center">
                <div class="w-7 h-7 border-2 border-cyan-500 border-t-transparent rounded-full animate-spin mx-auto mb-3"></div>
                <p class="text-gray-500 text-sm">Searching...</p>
              </div>
            {{else if this.opponentResults.length}}
              <div class="space-y-2">
                <p class="text-xs text-gray-500 font-medium px-1">Search Results</p>
                {{#each this.opponentResults as |team|}}
                  <div
                    class="rounded-2xl border overflow-hidden transition-all
                      {{if
                        (eq this.selectedOpponentId team.id)
                        'border-cyan-500/60 bg-slate-800/80 shadow-lg shadow-cyan-500/10'
                        'border-slate-700/50 bg-slate-800/40 hover:border-slate-600/60'
                      }}"
                  >

                    <button type="button" class="w-full flex items-center gap-4 px-5 py-3.5 text-left" {{on "click" (fn this.selectOpponent team)}}>
                      <div
                        class="w-5 h-5 rounded-full border-2 flex items-center justify-center flex-shrink-0 transition-all
                          {{if (eq this.selectedOpponentId team.id) 'border-cyan-500' 'border-slate-600'}}"
                      >
                        {{#if (eq this.selectedOpponentId team.id)}}
                          <div class="w-2.5 h-2.5 rounded-full bg-cyan-500"></div>
                        {{/if}}
                      </div>
                      <div class="w-11 h-11 rounded-xl flex-shrink-0 shadow-md">
                        {{#if team.logo}}
                          <div class="w-full h-full rounded-xl overflow-hidden bg-white p-1">
                            <img src={{team.logo}} alt={{team.name}} class="w-full h-full object-contain" />
                          </div>
                        {{else}}
                          <div class="w-full h-full rounded-xl bg-gradient-to-br from-violet-600 to-purple-700 flex items-center justify-center">
                            <span class="text-white text-xs font-bold">{{teamInitials team.name}}</span>
                          </div>
                        {{/if}}
                      </div>
                      <span class="text-white font-medium truncate flex-1">{{team.name}}</span>
                      {{#if (eq this.selectedOpponentId team.id)}}
                        {{#if this.isLoadingOpponentInfo}}
                          <div class="w-4 h-4 border-2 border-cyan-500 border-t-transparent rounded-full animate-spin flex-shrink-0"></div>
                        {{else if this.opponentTeamInfo}}
                          <button
                            type="button"
                            class="flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-slate-700/60 hover:bg-slate-700 text-gray-400 hover:text-white text-xs transition-all flex-shrink-0"
                            {{on "click" this.toggleOpponentPlayers}}
                          >
                            <span>{{this.opponentTeamInfo.players.length}} players</span>
                            <svg
                              class="w-3.5 h-3.5 transition-transform {{if this.opponentPlayersExpanded 'rotate-180' ''}}"
                              fill="none"
                              stroke="currentColor"
                              viewBox="0 0 24 24"
                            >
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                            </svg>
                          </button>
                        {{/if}}
                      {{/if}}
                    </button>

                    {{#if (eq this.selectedOpponentId team.id)}}
                      {{#if this.isLoadingOpponentInfo}}
                        <div class="border-t border-slate-700/40 px-5 py-3 space-y-2.5">
                          {{#each (array 1 2 3) as |_|}}
                            <div class="flex items-center gap-3 animate-pulse">
                              <div class="w-8 h-8 rounded-full bg-slate-700 flex-shrink-0"></div>
                              <div class="flex-1 space-y-1.5">
                                <div class="h-3 bg-slate-700 rounded w-28"></div>
                                <div class="h-2.5 bg-slate-700 rounded w-16"></div>
                              </div>
                            </div>
                          {{/each}}
                        </div>
                      {{else if this.opponentPlayersExpanded}}
                        {{#if this.opponentTeamInfo.players.length}}
                          <div class="border-t border-slate-700/40 px-5 py-3 space-y-2 max-h-52 overflow-y-auto">
                            {{#each this.opponentTeamInfo.players as |player index|}}
                              <div class="flex items-center gap-3 py-0.5">
                                <span
                                  class="w-5 h-5 rounded-full bg-slate-700 text-gray-500 text-[10px] font-bold flex items-center justify-center flex-shrink-0"
                                >
                                  {{index}}
                                </span>
                                <div class="w-8 h-8 rounded-full bg-slate-700 overflow-hidden flex-shrink-0">
                                  <img
                                    src={{player.logo}}
                                    alt={{player.name}}
                                    class="w-full h-full object-cover"
                                    onerror="this.src='/images/default-player.png'"
                                  />
                                </div>
                                <div class="min-w-0 flex-1">
                                  <p class="text-white text-xs font-medium truncate">{{player.name}}</p>
                                  <p class="text-gray-500 text-[10px]">{{player.role}}</p>
                                </div>
                                {{#if (this.isDuplicate player.id)}}
                                  <span class="text-[10px] font-semibold text-red-400 bg-red-400/10 px-1.5 py-0.5 rounded flex-shrink-0">Conflict</span>
                                {{/if}}
                              </div>
                            {{/each}}
                          </div>
                        {{/if}}
                      {{/if}}
                    {{/if}}
                  </div>
                {{/each}}
              </div>
            {{else if this.opponentQuery}}
              <div class="py-12 text-center">
                <div class="w-14 h-14 mx-auto mb-4 bg-slate-800 rounded-2xl flex items-center justify-center">
                  <svg class="w-7 h-7 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                  </svg>
                </div>
                <p class="text-gray-400 font-medium">No teams found</p>
                <p class="text-gray-600 text-sm mt-1">Try a different search term</p>
              </div>
            {{else}}
              {{! Suggested / nearby teams }}
              {{#if this.isLoadingSuggested}}
                <div class="space-y-3">
                  <p class="text-xs text-gray-500 font-medium px-1">Nearby Teams</p>
                  {{#each (array 1 2 3) as |_|}}
                    <div class="rounded-2xl border border-slate-700/50 bg-slate-800/40 p-4 animate-pulse flex items-center gap-4">
                      <div class="w-5 h-5 rounded-full bg-slate-700 flex-shrink-0"></div>
                      <div class="w-11 h-11 rounded-xl bg-slate-700 flex-shrink-0"></div>
                      <div class="flex-1 h-4 bg-slate-700 rounded w-28"></div>
                    </div>
                  {{/each}}
                </div>
              {{else if this.suggestedTeams.length}}
                <div class="space-y-2">
                  <p class="text-xs text-gray-500 font-medium px-1">Nearby Teams</p>
                  {{#each this.suggestedTeams as |team|}}
                    <div
                      class="rounded-2xl border overflow-hidden transition-all
                        {{if
                          (eq this.selectedOpponentId team.id)
                          'border-cyan-500/60 bg-slate-800/80 shadow-lg shadow-cyan-500/10'
                          'border-slate-700/50 bg-slate-800/40 hover:border-slate-600/60'
                        }}"
                    >
                      <button type="button" class="w-full flex items-center gap-4 px-5 py-3.5 text-left" {{on "click" (fn this.selectOpponent team)}}>
                        <div
                          class="w-5 h-5 rounded-full border-2 flex items-center justify-center flex-shrink-0 transition-all
                            {{if (eq this.selectedOpponentId team.id) 'border-cyan-500' 'border-slate-600'}}"
                        >
                          {{#if (eq this.selectedOpponentId team.id)}}
                            <div class="w-2.5 h-2.5 rounded-full bg-cyan-500"></div>
                          {{/if}}
                        </div>
                        <div class="w-11 h-11 rounded-xl flex-shrink-0 shadow-md">
                          {{#if team.logo}}
                            <div class="w-full h-full rounded-xl overflow-hidden bg-white p-1">
                              <img src={{team.logo}} alt={{team.name}} class="w-full h-full object-contain" />
                            </div>
                          {{else}}
                            <div class="w-full h-full rounded-xl bg-gradient-to-br from-violet-600 to-purple-700 flex items-center justify-center">
                              <span class="text-white text-xs font-bold">{{teamInitials team.name}}</span>
                            </div>
                          {{/if}}
                        </div>
                        <span class="text-white font-medium truncate flex-1">{{team.name}}</span>
                        {{#if (eq this.selectedOpponentId team.id)}}
                          {{#if this.isLoadingOpponentInfo}}
                            <div class="w-4 h-4 border-2 border-cyan-500 border-t-transparent rounded-full animate-spin flex-shrink-0"></div>
                          {{else if this.opponentTeamInfo}}
                            <button
                              type="button"
                              class="flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-slate-700/60 hover:bg-slate-700 text-gray-400 hover:text-white text-xs transition-all flex-shrink-0"
                              {{on "click" this.toggleOpponentPlayers}}
                            >
                              <span>{{this.opponentTeamInfo.players.length}} players</span>
                              <svg
                                class="w-3.5 h-3.5 transition-transform {{if this.opponentPlayersExpanded 'rotate-180' ''}}"
                                fill="none"
                                stroke="currentColor"
                                viewBox="0 0 24 24"
                              >
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                              </svg>
                            </button>
                          {{/if}}
                        {{/if}}
                      </button>
                      {{#if (eq this.selectedOpponentId team.id)}}
                        {{#if this.isLoadingOpponentInfo}}
                          <div class="border-t border-slate-700/40 px-5 py-3 space-y-2.5">
                            {{#each (array 1 2 3) as |_|}}
                              <div class="flex items-center gap-3 animate-pulse">
                                <div class="w-8 h-8 rounded-full bg-slate-700 flex-shrink-0"></div>
                                <div class="flex-1 space-y-1.5">
                                  <div class="h-3 bg-slate-700 rounded w-28"></div>
                                  <div class="h-2.5 bg-slate-700 rounded w-16"></div>
                                </div>
                              </div>
                            {{/each}}
                          </div>
                        {{else if this.opponentPlayersExpanded}}
                          {{#if this.opponentTeamInfo.players.length}}
                            <div class="border-t border-slate-700/40 px-5 py-3 space-y-2 max-h-52 overflow-y-auto">
                              {{#each this.opponentTeamInfo.players as |player index|}}
                                <div class="flex items-center gap-3 py-0.5">
                                  <span
                                    class="w-5 h-5 rounded-full bg-slate-700 text-gray-500 text-[10px] font-bold flex items-center justify-center flex-shrink-0"
                                  >
                                    {{index}}
                                  </span>
                                  <div class="w-8 h-8 rounded-full bg-slate-700 overflow-hidden flex-shrink-0">
                                    <img
                                      src={{player.logo}}
                                      alt={{player.name}}
                                      class="w-full h-full object-cover"
                                      onerror="this.src='/images/default-player.png'"
                                    />
                                  </div>
                                  <div class="min-w-0 flex-1">
                                    <p class="text-white text-xs font-medium truncate">{{player.name}}</p>
                                    <p class="text-gray-500 text-[10px]">{{player.role}}</p>
                                  </div>
                                  {{#if (this.isDuplicate player.id)}}
                                    <span class="text-[10px] font-semibold text-red-400 bg-red-400/10 px-1.5 py-0.5 rounded flex-shrink-0">Conflict</span>
                                  {{/if}}
                                </div>
                              {{/each}}
                            </div>
                          {{/if}}
                        {{/if}}
                      {{/if}}
                    </div>
                  {{/each}}
                </div>
              {{else}}
                <div class="py-12 text-center">
                  <div class="w-14 h-14 mx-auto mb-4 bg-slate-800 rounded-2xl flex items-center justify-center">
                    <svg class="w-7 h-7 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="1.5"
                        d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z"
                      />
                    </svg>
                  </div>
                  <p class="text-gray-500 font-medium">Search for a team</p>
                  <p class="text-gray-600 text-sm mt-1">Type a team name above to find opponents</p>
                </div>
              {{/if}}
            {{/if}}

            {{! Next button }}
            <button
              type="button"
              class="w-full flex items-center justify-center gap-2 py-3.5 rounded-2xl font-semibold text-sm transition-all
                {{if
                  this.opponentReadyForNext
                  'bg-cyan-500 hover:bg-cyan-400 text-white shadow-lg shadow-cyan-500/25 active:scale-[0.98]'
                  'bg-slate-800 text-gray-500 border border-slate-700/50 cursor-not-allowed'
                }}"
              {{on "click" this.goNext}}
            >
              Continue to Match Setup
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
              </svg>
            </button>
          </div>

          {{! ════ STEP 3 : Match Setup ════ }}
        {{else if (eq this.currentStep 3)}}
          <form {{on "submit" this.handleSubmit}} class="space-y-6">

            {{! Teams summary card }}
            {{#if (eq this.currentStep 3)}}
              <div class="bg-slate-800/50 border border-slate-700/40 rounded-2xl px-5 py-4">
                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-3 flex-1 min-w-0">
                    <div class="w-10 h-10 rounded-xl flex-shrink-0 shadow">
                      {{#if this.selectedTeam.logo}}
                        <div class="w-full h-full rounded-xl overflow-hidden bg-white p-1">
                          <img src={{this.selectedTeam.logo}} alt={{this.selectedTeam.name}} class="w-full h-full object-contain" />
                        </div>
                      {{else}}
                        <div class="w-full h-full rounded-xl bg-gradient-to-br from-cyan-600 to-blue-700 flex items-center justify-center">
                          <span class="text-white text-xs font-bold">{{teamInitials this.selectedTeam.name}}</span>
                        </div>
                      {{/if}}
                    </div>
                    <p class="text-white font-semibold text-sm truncate">{{this.selectedTeam.name}}</p>
                  </div>
                  <div class="px-4 flex-shrink-0">
                    <span class="text-gray-500 text-xs font-bold bg-slate-700/60 px-2.5 py-1 rounded-full">VS</span>
                  </div>
                  <div class="flex items-center gap-3 flex-1 min-w-0 justify-end">
                    <p class="text-white font-semibold text-sm truncate text-right">{{this.selectedOpponent.name}}</p>
                    <div class="w-10 h-10 rounded-xl flex-shrink-0 shadow">
                      {{#if this.selectedOpponent.logo}}
                        <div class="w-full h-full rounded-xl overflow-hidden bg-white p-1">
                          <img src={{this.selectedOpponent.logo}} alt={{this.selectedOpponent.name}} class="w-full h-full object-contain" />
                        </div>
                      {{else}}
                        <div class="w-full h-full rounded-xl bg-gradient-to-br from-violet-600 to-purple-700 flex items-center justify-center">
                          <span class="text-white text-xs font-bold">{{teamInitials this.selectedOpponent.name}}</span>
                        </div>
                      {{/if}}
                    </div>
                  </div>
                </div>
              </div>
            {{/if}}

            <div>
              <h2 class="text-white text-xl font-bold">Match Setup</h2>
              <p class="text-gray-500 text-sm mt-1">Configure the match details</p>
            </div>

            {{#if this.isFootball}}

              {{! ── FOOTBALL FORM ──────────────────────────────────── }}

              {{! Match Photo }}
              <div class="space-y-2">
                <label class="block text-gray-400 text-sm font-medium">
                  Match Photo
                  <span class="text-gray-600 text-xs font-normal">(optional)</span>
                </label>
                <div class="w-36">
                  <ImageUploader @type="football_game_logo" @aspectRatio="1/1" @onChange={{this.onPhotoUploaded}} />
                </div>
              </div>

              {{! Cover Photo }}
              <div class="space-y-2">
                <label class="block text-gray-400 text-sm font-medium">
                  Cover Photo
                  <span class="text-gray-600 text-xs font-normal">(optional)</span>
                </label>
                <ImageUploader @type="football_cover_photo" @aspectRatio="16/9" @onChange={{this.onCoverPhotoUploaded}} />
              </div>

              {{! Home / Away }}
              <div class="space-y-1.5">
                <label class="block text-gray-400 text-sm font-medium">
                  Home / Away
                  <span class="text-red-400">*</span>
                </label>
                <div class="relative">
                  <select
                    class="w-full appearance-none bg-slate-800/60 border
                      {{if this.errors.homeAway 'border-red-500/60' 'border-slate-700/50'}}
                      rounded-2xl px-4 py-3 text-sm text-white focus:outline-none focus:border-cyan-500/60 focus:ring-1 focus:ring-cyan-500/20 transition-all cursor-pointer [color-scheme:dark]"
                    {{on "change" (fn this.setField "homeAway")}}
                  >
                    <option value="" disabled selected={{eq this.homeAway ""}}>Select Home / Away</option>
                    {{#each FB_HOME_AWAY as |opt|}}
                      <option value={{opt}} selected={{eq this.homeAway opt}}>{{opt}}</option>
                    {{/each}}
                  </select>
                  <svg
                    class="absolute right-4 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500 pointer-events-none"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  ><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
                </div>
                {{#if this.errors.homeAway}}<p class="text-red-400 text-xs">{{this.errors.homeAway}}</p>{{/if}}
              </div>

              {{! Game Name }}
              <div class="space-y-1.5">
                <label class="block text-gray-400 text-sm font-medium">
                  Game Name
                  <span class="text-red-400">*</span>
                </label>
                <input
                  type="text"
                  placeholder="e.g. Premier League Friendly 2025"
                  value={{this.matchName}}
                  class="w-full bg-slate-800/60 border
                    {{if this.errors.matchName 'border-red-500/60' 'border-slate-700/50'}}
                    rounded-2xl px-4 py-3 text-sm text-white placeholder-gray-600 focus:outline-none focus:border-cyan-500/60 focus:ring-1 focus:ring-cyan-500/20 transition-all"
                  {{on "input" (fn this.setField "matchName")}}
                />
                {{#if this.errors.matchName}}<p class="text-red-400 text-xs">{{this.errors.matchName}}</p>{{/if}}
              </div>

              {{! Match Price }}
              <div class="space-y-1.5">
                <label class="block text-gray-400 text-sm font-medium">
                  Match Price
                  <span class="text-gray-600 text-xs font-normal">(optional)</span>
                </label>
                <input
                  type="text"
                  placeholder="e.g. 5000 BDT"
                  value={{this.matchPrize}}
                  class="w-full bg-slate-800/60 border border-slate-700/50 rounded-2xl px-4 py-3 text-sm text-white placeholder-gray-600 focus:outline-none focus:border-cyan-500/60 focus:ring-1 focus:ring-cyan-500/20 transition-all"
                  {{on "input" (fn this.setField "matchPrize")}}
                />
              </div>

              {{! Match Phone }}
              <div class="space-y-1.5">
                <label class="block text-gray-400 text-sm font-medium">
                  Match Phone
                  <span class="text-red-400">*</span>
                </label>
                <div
                  class="flex items-center bg-slate-800/60 border
                    {{if this.errors.phoneNumber 'border-red-500/60' 'border-slate-700/50'}}
                    rounded-2xl overflow-hidden"
                >
                  <button
                    type="button"
                    class="flex items-center gap-2 pl-3 pr-2 py-3 border-r border-slate-700/50 flex-shrink-0"
                    {{on "click" this.toggleCountryPicker}}
                  >
                    <img src="https://flagcdn.com/w20/{{this.phoneCountry.code}}.png" alt={{this.phoneCountry.name}} class="w-5 h-4 rounded-sm object-cover" />
                    <span class="text-white text-sm font-medium">{{this.phoneCountry.dial}}</span>
                    <svg class="w-3 h-3 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M19 9l-7 7-7-7"
                      /></svg>
                  </button>
                  <input
                    type="tel"
                    placeholder="1XXXXXXXXX"
                    value={{this.phoneNumber}}
                    class="flex-1 bg-transparent px-3 py-3 text-sm text-white placeholder-gray-600 focus:outline-none"
                    {{on "input" (fn this.setField "phoneNumber")}}
                  />
                </div>
                {{#if this.errors.phoneNumber}}<p class="text-red-400 text-xs">{{this.errors.phoneNumber}}</p>{{/if}}
              </div>

              {{! Match Type }}
              <div class="space-y-1.5">
                <label class="block text-gray-400 text-sm font-medium">
                  Match Type
                  <span class="text-red-400">*</span>
                </label>
                <div class="relative">
                  <select
                    class="w-full appearance-none bg-slate-800/60 border
                      {{if this.errors.matchType 'border-red-500/60' 'border-slate-700/50'}}
                      rounded-2xl px-4 py-3 text-sm text-white focus:outline-none focus:border-cyan-500/60 focus:ring-1 focus:ring-cyan-500/20 transition-all cursor-pointer [color-scheme:dark]"
                    {{on "change" (fn this.setField "matchType")}}
                  >
                    <option value="" disabled selected={{eq this.matchType ""}}>Select Match Type</option>
                    {{#each FB_MATCH_TYPES as |opt|}}
                      <option value={{opt}} selected={{eq this.matchType opt}}>{{opt}}</option>
                    {{/each}}
                  </select>
                  <svg
                    class="absolute right-4 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500 pointer-events-none"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  ><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
                </div>
                {{#if this.errors.matchType}}<p class="text-red-400 text-xs">{{this.errors.matchType}}</p>{{/if}}
              </div>

              {{! Match Level }}
              <div class="space-y-1.5">
                <label class="block text-gray-400 text-sm font-medium">
                  Match Level
                  <span class="text-red-400">*</span>
                </label>
                <div class="relative">
                  <select
                    class="w-full appearance-none bg-slate-800/60 border
                      {{if this.errors.matchLevel 'border-red-500/60' 'border-slate-700/50'}}
                      rounded-2xl px-4 py-3 text-sm text-white focus:outline-none focus:border-cyan-500/60 focus:ring-1 focus:ring-cyan-500/20 transition-all cursor-pointer [color-scheme:dark]"
                    {{on "change" (fn this.setField "matchLevel")}}
                  >
                    <option value="" disabled selected={{eq this.matchLevel ""}}>Select Match Level</option>
                    {{#each FB_MATCH_LEVELS as |opt|}}
                      <option value={{opt}} selected={{eq this.matchLevel opt}}>{{opt}}</option>
                    {{/each}}
                  </select>
                  <svg
                    class="absolute right-4 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500 pointer-events-none"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  ><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
                </div>
                {{#if this.errors.matchLevel}}<p class="text-red-400 text-xs">{{this.errors.matchLevel}}</p>{{/if}}
              </div>

              {{! Match Sub Level (shown only when level is selected) }}
              {{#if this.matchLevel}}
                <div class="space-y-2 pl-2 border-l-2 border-slate-700/50">
                  <label class="block text-gray-400 text-sm font-medium">Match Sub Level</label>
                  {{#if this.isMultiSelectLevel}}
                    {{#if this.selectedSubLevels.length}}
                      <div class="flex flex-wrap gap-1.5">
                        {{#each this.selectedSubLevels as |sel|}}
                          <span
                            class="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium bg-cyan-500/15 border border-cyan-500/40 text-cyan-300"
                          >
                            {{sel}}
                            <button type="button" {{on "click" (fn this.toggleSubLevel sel)}} class="ml-0.5 hover:text-white transition-colors">
                              <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5"><path
                                  stroke-linecap="round"
                                  stroke-linejoin="round"
                                  d="M6 18L18 6M6 6l12 12"
                                /></svg>
                            </button>
                          </span>
                        {{/each}}
                      </div>
                    {{/if}}
                    <div class="rounded-2xl border border-slate-700/50 bg-slate-800/40 overflow-hidden max-h-52 overflow-y-auto divide-y divide-slate-700/30">
                      {{#each this.multiSubLevelOptions as |opt|}}
                        <button
                          type="button"
                          {{on "click" (fn this.toggleSubLevel opt)}}
                          class="w-full flex items-center gap-3 px-4 py-2.5 text-sm text-left transition-colors
                            {{if (includes this.selectedSubLevels opt) 'bg-cyan-500/10 text-cyan-300' 'text-gray-300 hover:bg-slate-700/40'}}"
                        >
                          <span
                            class="flex-shrink-0 w-4 h-4 rounded border flex items-center justify-center transition-all
                              {{if (includes this.selectedSubLevels opt) 'bg-cyan-500 border-cyan-500' 'border-slate-600 bg-transparent'}}"
                          >
                            {{#if (includes this.selectedSubLevels opt)}}
                              <svg class="w-2.5 h-2.5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="3"><path
                                  stroke-linecap="round"
                                  stroke-linejoin="round"
                                  d="M5 13l4 4L19 7"
                                /></svg>
                            {{/if}}
                          </span>
                          {{opt}}
                        </button>
                      {{/each}}
                    </div>
                  {{else}}
                    <div class="relative">
                      <select
                        class="w-full appearance-none bg-slate-800/60 border border-slate-700/50 rounded-2xl px-4 py-3 text-sm text-white focus:outline-none focus:border-cyan-500/60 focus:ring-1 focus:ring-cyan-500/20 transition-all cursor-pointer [color-scheme:dark]"
                        {{on "change" (fn this.setField "matchSubLevel")}}
                      >
                        <option value="">Match Sub Level</option>
                        {{#each this.footballSubLevelOptions as |opt|}}
                          <option value={{opt}} selected={{eq this.matchSubLevel opt}}>{{opt}}</option>
                        {{/each}}
                      </select>
                      <svg
                        class="absolute right-4 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500 pointer-events-none"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      ><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
                    </div>
                  {{/if}}
                </div>
              {{/if}}

              {{! Age Group }}
              <div class="space-y-1.5">
                <label class="block text-gray-400 text-sm font-medium">
                  Age Group
                  <span class="text-red-400">*</span>
                </label>
                <div class="relative">
                  <select
                    class="w-full appearance-none bg-slate-800/60 border
                      {{if this.errors.ageGroup 'border-red-500/60' 'border-slate-700/50'}}
                      rounded-2xl px-4 py-3 text-sm text-white focus:outline-none focus:border-cyan-500/60 focus:ring-1 focus:ring-cyan-500/20 transition-all cursor-pointer [color-scheme:dark]"
                    {{on "change" (fn this.setField "ageGroup")}}
                  >
                    <option value="" disabled selected={{eq this.ageGroup ""}}>Select Age Group</option>
                    {{#each FB_AGE_GROUPS as |opt|}}
                      <option value={{opt}} selected={{eq this.ageGroup opt}}>{{opt}}</option>
                    {{/each}}
                  </select>
                  <svg
                    class="absolute right-4 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500 pointer-events-none"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  ><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
                </div>
                {{#if this.errors.ageGroup}}<p class="text-red-400 text-xs">{{this.errors.ageGroup}}</p>{{/if}}
              </div>

              {{! Squad Size }}
              {{#if this.opponentReadyForNext}}
                <div class="space-y-1.5">
                  <label class="block text-gray-400 text-sm font-medium">
                    Squad Size
                    <span class="text-red-400">*</span>
                  </label>
                  <div class="flex items-center gap-2">
                    <div class="relative flex-1">
                      <select
                        class="w-full appearance-none bg-slate-800/60 border
                          {{if this.errors.squadSize 'border-red-500/60' 'border-slate-700/50'}}
                          rounded-2xl px-4 py-3 text-sm text-white focus:outline-none focus:border-cyan-500/60 focus:ring-1 focus:ring-cyan-500/20 transition-all cursor-pointer [color-scheme:dark]"
                        {{on "change" this.onSquadSizeChange}}
                      >
                        {{#each this.footballSquadSizeOptions as |n|}}
                          <option value={{n}} selected={{eq this.footballSquadSize n}}>{{n}}</option>
                        {{/each}}
                      </select>
                      <svg
                        class="absolute right-4 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500 pointer-events-none"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      ><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
                    </div>
                    <span class="text-gray-400 text-sm flex-shrink-0">player-a-side</span>
                  </div>
                  {{#if this.errors.squadSize}}<p class="text-red-400 text-xs">{{this.errors.squadSize}}</p>{{/if}}
                </div>
              {{/if}}

              {{! Match Time (date + time) }}
              <div class="grid grid-cols-2 gap-3">
                <div class="space-y-1.5">
                  <label class="block text-gray-400 text-sm font-medium">Date <span class="text-red-400">*</span></label>
                  <div
                    class="w-full bg-slate-800/60 border {{if this.errors.matchDate 'border-red-500/60' 'border-slate-700/50'}} rounded-2xl cursor-pointer"
                    role="button"
                    {{on "click" this.openPicker}}
                  >
                    <input
                      type="date"
                      value={{this.matchDate}}
                      class="w-full bg-transparent px-4 py-3 text-sm text-white focus:outline-none [color-scheme:dark] cursor-pointer"
                      {{on "change" (fn this.setField "matchDate")}}
                    />
                  </div>
                  {{#if this.errors.matchDate}}<p class="text-red-400 text-xs">{{this.errors.matchDate}}</p>{{/if}}
                </div>
                <div class="space-y-1.5">
                  <label class="block text-gray-400 text-sm font-medium">Time <span class="text-red-400">*</span></label>
                  <div
                    class="w-full bg-slate-800/60 border {{if this.errors.matchTime 'border-red-500/60' 'border-slate-700/50'}} rounded-2xl cursor-pointer"
                    role="button"
                    {{on "click" this.openPicker}}
                  >
                    <input
                      type="time"
                      value={{this.matchTime}}
                      class="w-full bg-transparent px-4 py-3 text-sm text-white focus:outline-none [color-scheme:dark] cursor-pointer"
                      {{on "change" (fn this.setField "matchTime")}}
                    />
                  </div>
                  {{#if this.errors.matchTime}}<p class="text-red-400 text-xs">{{this.errors.matchTime}}</p>{{/if}}
                </div>
              </div>

              {{! Facility Search }}
              <div class="space-y-1.5">
                <label class="block text-gray-400 text-sm font-medium">
                  Select Facility
                  <span class="ml-1 text-xs font-normal text-gray-500">(optional)</span>
                </label>
                <div class="relative" {{on "focusout" this.onFacilityBlur}}>
                  {{#if this.selectedFacility}}
                    {{! Selected chip }}
                    <div class="flex items-center gap-3 bg-slate-800/60 border border-cyan-500/40 rounded-2xl px-4 py-3">
                      {{#if (this._facilityLogoUrl this.selectedFacility.fac_logo)}}
                        <img
                          src={{this._facilityLogoUrl this.selectedFacility.fac_logo}}
                          alt={{this.selectedFacility.fac_name}}
                          class="w-9 h-9 rounded-xl object-cover flex-shrink-0"
                        />
                      {{else}}
                        <div class="w-9 h-9 rounded-xl bg-cyan-900/40 border border-cyan-700/40 flex items-center justify-center flex-shrink-0">
                          <svg class="w-4 h-4 text-cyan-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="2"
                              d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"
                            /><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" /></svg>
                        </div>
                      {{/if}}
                      <div class="flex-1 min-w-0">
                        <p class="text-sm font-semibold text-white truncate">{{this.selectedFacility.fac_name}}</p>
                        <p class="text-xs text-gray-500 truncate">{{this.selectedFacility.fac_address}}</p>
                        {{#if this.selectedFacility.fac_sports.length}}
                          <div class="flex gap-1 mt-1.5 flex-wrap">
                            {{#each this.selectedFacility.fac_sports as |sport|}}
                              <span
                                class="text-[10px] px-2 py-0.5 rounded-full bg-cyan-900/40 border border-cyan-700/30 text-cyan-400 capitalize"
                              >{{sport}}</span>
                            {{/each}}
                          </div>
                        {{/if}}
                      </div>
                      <button
                        type="button"
                        {{on "click" this.clearFacility}}
                        class="w-7 h-7 rounded-lg flex items-center justify-center text-gray-500 hover:text-red-400 hover:bg-red-400/10 transition-all flex-shrink-0"
                      >
                        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2.5"
                            d="M6 18L18 6M6 6l12 12"
                          /></svg>
                      </button>
                    </div>
                  {{else}}
                    {{! Search input }}
                    <div
                      class="{{if this.showFacilityResults 'rounded-t-2xl rounded-b-none border-b-0' 'rounded-2xl'}}
                        bg-slate-800/60 border border-slate-700/50 focus-within:border-cyan-500/60 focus-within:ring-1 focus-within:ring-cyan-500/20 transition-all overflow-hidden"
                    >
                      <div class="flex items-center px-4 py-3 gap-3">
                        {{#if this.facilitySearching}}
                          <svg class="w-4 h-4 text-cyan-400 animate-spin flex-shrink-0" fill="none" viewBox="0 0 24 24">
                            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
                            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z" />
                          </svg>
                        {{else}}
                          <svg class="w-4 h-4 text-gray-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <circle cx="11" cy="11" r="8" /><path d="m21 21-4.35-4.35" />
                          </svg>
                        {{/if}}
                        <input
                          type="text"
                          placeholder="Search by facility name…"
                          value={{this.facilityQuery}}
                          autocomplete="off"
                          class="flex-1 bg-transparent text-sm text-white placeholder-gray-500 focus:outline-none"
                          {{on "input" this.onFacilityInput}}
                          {{on "focus" this.onFacilityFocus}}
                          {{on "blur" this.onFacilityBlur}}
                        />
                      </div>
                    </div>

                    {{! Dropdown }}
                    {{#if this.showFacilityResults}}
                      <div
                        class="absolute z-50 w-full bg-slate-900 border border-slate-700/50 border-t-transparent rounded-b-2xl shadow-2xl overflow-hidden max-h-72 overflow-y-auto divide-y divide-slate-800/60"
                      >

                        {{#if this.facilitySearching}}
                          <div class="flex items-center justify-center gap-2 py-6 text-sm text-gray-500">
                            <svg class="w-4 h-4 text-cyan-400 animate-spin" fill="none" viewBox="0 0 24 24">
                              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
                              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z" />
                            </svg>
                            Searching…
                          </div>

                        {{else if this.facilityResults.length}}
                          {{#each this.facilityResults as |fac|}}
                            <button
                              type="button"
                              {{on "click" (fn this.selectFacility fac)}}
                              class="w-full text-left px-4 py-3 flex items-center gap-3 hover:bg-slate-800 transition-colors"
                            >
                              {{#if (this._facilityLogoUrl fac.fac_logo)}}
                                <img src={{this._facilityLogoUrl fac.fac_logo}} alt={{fac.fac_name}} class="w-10 h-10 rounded-xl object-cover flex-shrink-0" />
                              {{else}}
                                <div class="w-10 h-10 rounded-xl bg-slate-700 flex items-center justify-center flex-shrink-0">
                                  <svg class="w-4 h-4 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path
                                      stroke-linecap="round"
                                      stroke-linejoin="round"
                                      stroke-width="2"
                                      d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"
                                    /></svg>
                                </div>
                              {{/if}}
                              <div class="flex-1 min-w-0">
                                <p class="text-sm font-semibold text-white truncate">{{fac.fac_name}}</p>
                                <p class="text-xs text-gray-500 truncate mt-0.5">{{fac.fac_address}}</p>
                                {{#if fac.fac_sports.length}}
                                  <div class="flex gap-1 mt-1.5 flex-wrap">
                                    {{#each fac.fac_sports as |sport|}}
                                      <span class="text-[10px] px-2 py-0.5 rounded-full bg-slate-700/80 text-gray-400 capitalize">{{sport}}</span>
                                    {{/each}}
                                  </div>
                                {{/if}}
                              </div>
                              <svg class="w-4 h-4 text-gray-600 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path
                                  stroke-linecap="round"
                                  stroke-linejoin="round"
                                  stroke-width="2"
                                  d="M9 5l7 7-7 7"
                                /></svg>
                            </button>
                          {{/each}}

                        {{else if this.facilityQuery}}
                          <div class="py-8 text-center">
                            <svg class="w-8 h-8 text-gray-600 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path
                                stroke-linecap="round"
                                stroke-linejoin="round"
                                stroke-width="1.5"
                                d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                              /></svg>
                            <p class="text-sm text-gray-500">No facilities found for "{{this.facilityQuery}}"</p>
                          </div>

                        {{else}}
                          <div class="flex items-center gap-2 px-4 py-4 text-xs text-gray-600">
                            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><circle cx="11" cy="11" r="8" /><path
                                d="m21 21-4.35-4.35"
                              /></svg>
                            Type to search for a facility
                          </div>
                        {{/if}}

                      </div>
                    {{/if}}
                  {{/if}}
                </div>
              </div>

              {{! Match Field Name }}
              <div class="space-y-1.5">
                <label class="block text-gray-400 text-sm font-medium">
                  Match Field Name
                  <span class="text-red-400">*</span>
                </label>
                <input
                  type="text"
                  placeholder="Enter Match Field Name"
                  value={{this.fieldName}}
                  class="w-full bg-slate-800/60 border
                    {{if this.errors.fieldName 'border-red-500/60' 'border-slate-700/50'}}
                    rounded-2xl px-4 py-3 text-sm text-white placeholder-gray-600 focus:outline-none focus:border-cyan-500/60 focus:ring-1 focus:ring-cyan-500/20 transition-all"
                  {{on "input" (fn this.setField "fieldName")}}
                />
                {{#if this.errors.fieldName}}<p class="text-red-400 text-xs">{{this.errors.fieldName}}</p>{{/if}}
              </div>

              {{! Location }}
              <div class="space-y-1.5">
                <label class="block text-gray-400 text-sm font-medium">
                  Location
                  <span class="text-red-400">*</span>
                </label>
                <div class="flex items-center gap-2">
                  <div class="relative flex-1">
                    <input
                      type="text"
                      placeholder="Start typing your address…"
                      value={{this.locationText}}
                      autocomplete="off"
                      class="w-full bg-slate-800/60 border
                        {{if this.errors.locationText 'border-red-500/60' 'border-slate-700/50'}}
                        rounded-2xl px-4 py-3 pr-9 text-sm text-white placeholder-gray-500 focus:outline-none focus:border-cyan-500/60 focus:ring-1 focus:ring-cyan-500/20 transition-all"
                      {{on "input" (fn this.setField "locationText")}}
                    />
                    {{#if this.placesLoading}}
                      <span class="absolute right-3 top-1/2 -translate-y-1/2">
                        <svg class="w-4 h-4 text-cyan-400 animate-spin" fill="none" viewBox="0 0 24 24">
                          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
                          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z" />
                        </svg>
                      </span>
                    {{/if}}
                    {{#if this.showPlaces}}
                      <ul
                        class="absolute z-50 top-full mt-1.5 w-full bg-slate-900 border border-slate-700 rounded-2xl shadow-2xl overflow-hidden divide-y divide-slate-700/60"
                      >
                        {{#each this.placeSuggestions as |suggestion|}}
                          <li>
                            <button
                              type="button"
                              {{on "click" (fn this.selectPlace suggestion)}}
                              class="w-full text-left px-4 py-3 text-sm text-gray-200 hover:bg-cyan-900/30 flex items-center gap-3 transition-colors"
                            >
                              <svg class="w-4 h-4 shrink-0 text-cyan-400" fill="currentColor" viewBox="0 0 20 20">
                                <path
                                  fill-rule="evenodd"
                                  d="M5.05 4.05a7 7 0 119.9 9.9L10 18.9l-4.95-4.95a7 7 0 010-9.9zM10 11a2 2 0 100-4 2 2 0 000 4z"
                                  clip-rule="evenodd"
                                />
                              </svg>
                              <span class="truncate">{{suggestion.description}}</span>
                            </button>
                          </li>
                        {{/each}}
                      </ul>
                    {{/if}}
                  </div>
                  <span class="text-gray-500 text-xs font-medium flex-shrink-0">OR</span>
                  <LocationPicker @onSelect={{this.handleLocationSelect}} />
                </div>
                {{#if this.errors.locationText}}<p class="text-red-400 text-xs">{{this.errors.locationText}}</p>{{/if}}
              </div>

              {{! Field Type }}
              <div class="space-y-1.5">
                <label class="block text-gray-400 text-sm font-medium">
                  Field Type
                  <span class="text-red-400">*</span>
                </label>
                <div class="space-y-2">
                  <div class="relative">
                    <select
                      class="w-full appearance-none bg-slate-800/60 border
                        {{if this.errors.fieldType 'border-red-500/60' 'border-slate-700/50'}}
                        rounded-2xl px-4 py-3 text-sm text-white focus:outline-none focus:border-cyan-500/60 focus:ring-1 focus:ring-cyan-500/20 transition-all cursor-pointer [color-scheme:dark]"
                      {{on "change" (fn this.setField "fieldType")}}
                    >
                      <option value="" disabled selected={{eq this.fieldType ""}}>Select Surface Type</option>
                      {{#each FB_FIELD_TYPES.surface as |opt|}}
                        <option value={{opt}} selected={{eq this.fieldType opt}}>{{opt}}</option>
                      {{/each}}
                    </select>
                    <svg
                      class="absolute right-4 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500 pointer-events-none"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    ><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
                  </div>
                  <div class="relative">
                    <select
                      class="w-full appearance-none bg-slate-800/60 border border-slate-700/50 rounded-2xl px-4 py-3 text-sm text-white focus:outline-none focus:border-cyan-500/60 focus:ring-1 focus:ring-cyan-500/20 transition-all cursor-pointer [color-scheme:dark]"
                      {{on "change" (fn this.setField "fieldTypeEnv")}}
                    >
                      <option value="" disabled selected={{eq this.fieldTypeEnv ""}}>Select Indoor / Outdoor</option>
                      {{#each FB_FIELD_TYPES.environment as |opt|}}
                        <option value={{opt}} selected={{eq this.fieldTypeEnv opt}}>{{opt}}</option>
                      {{/each}}
                    </select>
                    <svg
                      class="absolute right-4 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500 pointer-events-none"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    ><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
                  </div>
                </div>
                {{#if this.errors.fieldType}}<p class="text-red-400 text-xs">{{this.errors.fieldType}}</p>{{/if}}
              </div>

              {{! Field Size }}
              <div class="space-y-1.5">
                <label class="block text-gray-400 text-sm font-medium">
                  Field Size
                  <span class="text-red-400">*</span>
                </label>
                <div class="relative">
                  <div
                    class="border
                      {{if this.errors.fieldSize 'border-red-500/60' 'border-slate-700/50'}}
                      rounded-2xl overflow-hidden bg-slate-800/60 focus-within:border-cyan-500/60 focus-within:ring-1 focus-within:ring-cyan-500/20 transition-all"
                  >
                    <div class="flex items-center">
                      <input
                        type="text"
                        placeholder="Select or type custom field size"
                        value={{this.fieldSizeCustom}}
                        class="flex-1 bg-transparent px-4 py-3 text-sm text-white placeholder-gray-500 focus:outline-none"
                        {{on "input" (fn this.setField "fieldSizeCustom")}}
                        {{on "focus" this.toggleFieldSizeDropdown}}
                      />
                      <button type="button" class="px-3 py-3 text-gray-500 hover:text-gray-300 transition-colors" {{on "click" this.toggleFieldSizeDropdown}}>
                        <svg
                          class="w-4 h-4 transition-transform {{if this.showFieldSizeDropdown 'rotate-180'}}"
                          fill="none"
                          stroke="currentColor"
                          viewBox="0 0 24 24"
                        ><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
                      </button>
                    </div>
                    {{#if this.showFieldSizeDropdown}}
                      <div class="border-t border-slate-700/50">
                        {{#each FB_FIELD_SIZES as |size|}}
                          <button
                            type="button"
                            class="w-full text-left px-4 py-2.5 text-sm text-white hover:bg-slate-700/50 border-b border-slate-700/30 last:border-b-0 transition-colors
                              {{if (eq this.fieldSize size) 'text-cyan-400 bg-cyan-500/10'}}"
                            {{on "click" (fn this.selectFieldSize size)}}
                          >{{size}}</button>
                        {{/each}}
                      </div>
                    {{/if}}
                  </div>
                </div>
                {{#if this.errors.fieldSize}}<p class="text-red-400 text-xs">{{this.errors.fieldSize}}</p>{{/if}}
              </div>

              {{! Goal Bar Size }}
              <div class="space-y-1.5">
                <label class="block text-gray-400 text-sm font-medium">
                  Goal Bar Size
                  <span class="text-red-400">*</span>
                </label>
                <div class="relative">
                  <div
                    class="border
                      {{if this.errors.goalBarSize 'border-red-500/60' 'border-slate-700/50'}}
                      rounded-2xl overflow-hidden bg-slate-800/60 focus-within:border-cyan-500/60 focus-within:ring-1 focus-within:ring-cyan-500/20 transition-all"
                  >
                    <div class="flex items-center">
                      <input
                        type="text"
                        placeholder="Select or type custom goal bar size"
                        value={{this.goalBarSizeCustom}}
                        class="flex-1 bg-transparent px-4 py-3 text-sm text-white placeholder-gray-500 focus:outline-none"
                        {{on "input" (fn this.setField "goalBarSizeCustom")}}
                        {{on "focus" this.toggleGoalBarDropdown}}
                      />
                      <button type="button" class="px-3 py-3 text-gray-500 hover:text-gray-300 transition-colors" {{on "click" this.toggleGoalBarDropdown}}>
                        <svg
                          class="w-4 h-4 transition-transform {{if this.showGoalBarDropdown 'rotate-180'}}"
                          fill="none"
                          stroke="currentColor"
                          viewBox="0 0 24 24"
                        ><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
                      </button>
                    </div>
                    {{#if this.showGoalBarDropdown}}
                      <div class="border-t border-slate-700/50">
                        {{#each FB_GOAL_BAR_SIZES as |size|}}
                          <button
                            type="button"
                            class="w-full text-left px-4 py-2.5 text-sm text-white hover:bg-slate-700/50 border-b border-slate-700/30 last:border-b-0 transition-colors
                              {{if (eq this.goalBarSize size) 'text-cyan-400 bg-cyan-500/10'}}"
                            {{on "click" (fn this.selectGoalBarSize size)}}
                          >{{size}}</button>
                        {{/each}}
                      </div>
                    {{/if}}
                  </div>
                </div>
                {{#if this.errors.goalBarSize}}<p class="text-red-400 text-xs">{{this.errors.goalBarSize}}</p>{{/if}}
              </div>

              {{! Sports Ball Type }}
              <div class="space-y-1.5">
                <label class="block text-gray-400 text-sm font-medium">
                  Sports Ball Type
                  <span class="text-red-400">*</span>
                </label>
                <div class="relative">
                  <div
                    class="border
                      {{if this.errors.footballBallType 'border-red-500/60' 'border-slate-700/50'}}
                      rounded-2xl overflow-hidden bg-slate-800/60 focus-within:border-cyan-500/60 focus-within:ring-1 focus-within:ring-cyan-500/20 transition-all"
                  >
                    <button
                      type="button"
                      class="w-full flex items-center justify-between px-4 py-3 text-sm transition-colors hover:bg-slate-700/30"
                      {{on "click" this.toggleBallTypeDropdown}}
                    >
                      <span class="{{if this.footballBallType 'text-white' 'text-gray-500'}}">
                        {{if this.footballBallType this.footballBallType "Select Sports Ball Type"}}
                      </span>
                      <svg
                        class="w-4 h-4 text-gray-500 flex-shrink-0 transition-transform {{if this.showBallTypeDropdown 'rotate-180'}}"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                      </svg>
                    </button>
                    {{#if this.showBallTypeDropdown}}
                      <div class="border-t border-slate-700/50">
                        {{#each FB_BALL_TYPES as |type|}}
                          <button
                            type="button"
                            class="w-full text-left px-4 py-3 text-sm font-semibold text-white hover:bg-slate-700/50 border-b border-slate-700/40 last:border-b-0 transition-colors
                              {{if (eq this.footballBallType type) 'text-cyan-400 bg-cyan-500/10'}}"
                            {{on "click" (fn this.selectBallTypeOption type)}}
                          >
                            {{type}}
                          </button>
                        {{/each}}
                      </div>
                    {{/if}}
                  </div>
                </div>
                {{#if this.errors.footballBallType}}<p class="text-red-400 text-xs">{{this.errors.footballBallType}}</p>{{/if}}
              </div>

              {{! Boot Allowed }}
              <div class="space-y-1.5">
                <label class="block text-gray-400 text-sm font-medium">Boot Allowed</label>
                <div class="relative">
                  <select
                    class="w-full appearance-none bg-slate-800/60 border border-slate-700/50 rounded-2xl px-4 py-3 text-sm text-white focus:outline-none focus:border-cyan-500/60 focus:ring-1 focus:ring-cyan-500/20 transition-all cursor-pointer [color-scheme:dark]"
                    {{on "change" (fn this.setField "bootAllowed")}}
                  >
                    {{#each FB_YES_NO as |opt|}}
                      <option value={{opt}} selected={{eq this.bootAllowed opt}}>{{opt}}</option>
                    {{/each}}
                  </select>
                  <svg
                    class="absolute right-4 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500 pointer-events-none"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  ><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
                </div>
              </div>

              {{! Shoe Allowed }}
              <div class="space-y-1.5">
                <label class="block text-gray-400 text-sm font-medium">Shoe Allowed</label>
                <div class="relative">
                  <select
                    class="w-full appearance-none bg-slate-800/60 border border-slate-700/50 rounded-2xl px-4 py-3 text-sm text-white focus:outline-none focus:border-cyan-500/60 focus:ring-1 focus:ring-cyan-500/20 transition-all cursor-pointer [color-scheme:dark]"
                    {{on "change" (fn this.setField "shoeAllowed")}}
                  >
                    {{#each FB_YES_NO as |opt|}}
                      <option value={{opt}} selected={{eq this.shoeAllowed opt}}>{{opt}}</option>
                    {{/each}}
                  </select>
                  <svg
                    class="absolute right-4 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500 pointer-events-none"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  ><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
                </div>
              </div>

              {{! Jersey Mandatory }}
              <div class="space-y-1.5">
                <label class="block text-gray-400 text-sm font-medium">
                  Jersey Mandatory
                  <span class="text-red-400">*</span>
                </label>
                <div class="relative">
                  <select
                    class="w-full appearance-none bg-slate-800/60 border
                      {{if this.errors.jerseyMandatory 'border-red-500/60' 'border-slate-700/50'}}
                      rounded-2xl px-4 py-3 text-sm text-white focus:outline-none focus:border-cyan-500/60 focus:ring-1 focus:ring-cyan-500/20 transition-all cursor-pointer [color-scheme:dark]"
                    {{on "change" (fn this.setField "jerseyMandatory")}}
                  >
                    {{#each FB_YES_NO as |opt|}}
                      <option value={{opt}} selected={{eq this.jerseyMandatory opt}}>{{opt}}</option>
                    {{/each}}
                  </select>
                  <svg
                    class="absolute right-4 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500 pointer-events-none"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  ><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
                </div>
              </div>

              {{! Match Duration }}
              <div class="space-y-1.5">
                <label class="block text-gray-400 text-sm font-medium">
                  Match Duration
                  <span class="text-red-400">*</span>
                </label>
                <div class="flex items-center gap-2">
                  <input
                    type="number"
                    min="1"
                    max="300"
                    value={{this.matchDuration}}
                    class="flex-1 bg-slate-800/60 border
                      {{if this.errors.matchDuration 'border-red-500/60' 'border-slate-700/50'}}
                      rounded-2xl px-4 py-3 text-sm text-white placeholder-gray-600 focus:outline-none focus:border-cyan-500/60 focus:ring-1 focus:ring-cyan-500/20 transition-all"
                    {{on "input" (fn this.setField "matchDuration")}}
                  />
                  <span class="text-gray-400 text-sm flex-shrink-0">Minutes</span>
                </div>
              </div>

              {{! Number of halves }}
              <div class="space-y-1.5">
                <label class="block text-gray-400 text-sm font-medium">
                  Number of halves
                  <span class="text-red-400">*</span>
                </label>
                <div class="relative">
                  <select
                    class="w-full appearance-none bg-slate-800/60 border border-slate-700/50 rounded-2xl px-4 py-3 text-sm text-white focus:outline-none focus:border-cyan-500/60 focus:ring-1 focus:ring-cyan-500/20 transition-all cursor-pointer [color-scheme:dark]"
                    {{on "change" (fn this.setField "numberOfHalves")}}
                  >
                    {{#each FB_HALVES as |n|}}
                      <option value={{n}} selected={{eq this.numberOfHalves n}}>{{n}}</option>
                    {{/each}}
                  </select>
                  <svg
                    class="absolute right-4 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500 pointer-events-none"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  ><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
                </div>
              </div>

              {{! Half Duration }}
              <div class="space-y-1.5">
                <label class="block text-gray-400 text-sm font-medium">Half Duration</label>
                {{#if (eq this.numberOfHalves 1)}}
                  <div class="flex items-center gap-3 bg-slate-800/20 border border-slate-700/30 rounded-2xl px-4 py-3 opacity-50 cursor-not-allowed">
                    <svg class="w-4 h-4 text-gray-600 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636"
                      /></svg>
                    <span class="text-xs text-gray-500">Not applicable for single half selection</span>
                  </div>
                {{else}}
                  <div class="flex items-center gap-2">
                    <div class="flex-1 flex items-center gap-2 bg-slate-800/30 border border-slate-700/40 rounded-2xl px-4 py-3">
                      <span class="text-sm text-gray-300 tabular-nums">{{this.halfDuration}}</span>
                      <span class="text-xs text-gray-600">min</span>
                      <svg class="w-3.5 h-3.5 text-gray-600 ml-auto flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
                        /></svg>
                    </div>
                    <span class="text-gray-400 text-sm flex-shrink-0">Minutes</span>
                  </div>
                {{/if}}
              </div>

              {{! Tie Breaker }}
              <div class="space-y-1.5">
                <label class="block text-gray-400 text-sm font-medium">
                  Tie Breaker
                  <span class="text-red-400">*</span>
                </label>
                <div class="relative">
                  <select
                    class="w-full appearance-none bg-slate-800/60 border border-slate-700/50 rounded-2xl px-4 py-3 text-sm text-white focus:outline-none focus:border-cyan-500/60 focus:ring-1 focus:ring-cyan-500/20 transition-all cursor-pointer [color-scheme:dark]"
                    {{on "change" (fn this.setField "tieBreaker")}}
                  >
                    {{#each FB_YES_NO as |opt|}}
                      <option value={{opt}} selected={{eq this.tieBreaker opt}}>{{opt}}</option>
                    {{/each}}
                  </select>
                  <svg
                    class="absolute right-4 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500 pointer-events-none"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  ><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
                </div>
              </div>

              {{! Tie Breaker Ways }}
              {{#if (eq this.tieBreaker "Yes")}}
                <div class="space-y-1.5">
                  <label class="block text-gray-400 text-sm font-medium">
                    Tie Breaker Ways
                    <span class="ml-1.5 text-xs font-normal text-gray-500">(applicable when Tie Breaker is Yes)</span>
                  </label>
                  <div class="relative">
                    <select
                      class="w-full appearance-none bg-slate-800/60 border border-slate-700/50 rounded-2xl px-4 py-3 text-sm text-white focus:outline-none focus:border-cyan-500/60 focus:ring-1 focus:ring-cyan-500/20 transition-all cursor-pointer [color-scheme:dark]"
                      {{on "change" (fn this.setField "tieBreakerWays")}}
                    >
                      <option value="" disabled selected={{eq this.tieBreakerWays ""}}>Select Tie Breaker Way</option>
                      {{#each FB_TIE_BREAKER_WAYS as |opt|}}
                        <option value={{opt}} selected={{eq this.tieBreakerWays opt}}>{{opt}}</option>
                      {{/each}}
                    </select>
                    <svg
                      class="absolute right-4 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500 pointer-events-none"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    ><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
                  </div>
                </div>
              {{/if}}

              {{! Extra Time Duration + Halves }}
              {{#if this.showExtraTimeDuration}}
                <div class="space-y-1.5">
                  <label class="block text-gray-400 text-sm font-medium">
                    Extra Time Duration
                    <span class="ml-1.5 text-xs font-normal text-gray-500">(applicable for Extra Time & Penalty / Extra Time)</span>
                  </label>
                  <div class="flex items-center gap-2">
                    <input
                      type="number"
                      min="1"
                      max="120"
                      value={{this.extraTimeHalfDuration}}
                      class="flex-1 bg-slate-800/60 border border-slate-700/50 rounded-2xl px-4 py-3 text-sm text-white placeholder-gray-600 focus:outline-none focus:border-cyan-500/60 focus:ring-1 focus:ring-cyan-500/20 transition-all"
                      {{on "input" (fn this.setField "extraTimeHalfDuration")}}
                    />
                    <span class="text-gray-400 text-sm flex-shrink-0">Minutes</span>
                  </div>
                </div>

                <div class="space-y-1.5">
                  <label class="block text-gray-400 text-sm font-medium">Extra Time Number of Halves</label>
                  <div class="relative">
                    <select
                      class="w-full appearance-none bg-slate-800/60 border border-slate-700/50 rounded-2xl px-4 py-3 text-sm text-white focus:outline-none focus:border-cyan-500/60 focus:ring-1 focus:ring-cyan-500/20 transition-all cursor-pointer [color-scheme:dark]"
                      {{on "change" (fn this.setField "extraTimeNumberOfHalves")}}
                    >
                      {{#each FB_HALVES as |n|}}
                        <option value={{n}} selected={{eq this.extraTimeNumberOfHalves n}}>{{n}}</option>
                      {{/each}}
                    </select>
                    <svg
                      class="absolute right-4 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500 pointer-events-none"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    ><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
                  </div>
                </div>

                <div class="space-y-1.5">
                  <label class="block text-gray-400 text-sm font-medium">Extra Time Half Duration</label>
                  {{#if (eq this.extraTimeNumberOfHalves 1)}}
                    <div class="flex items-center gap-3 bg-slate-800/20 border border-slate-700/30 rounded-2xl px-4 py-3 opacity-50 cursor-not-allowed">
                      <svg class="w-4 h-4 text-gray-600 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636"
                        /></svg>
                      <span class="text-xs text-gray-500">Not applicable for single extra time half selection</span>
                    </div>
                  {{else}}
                    <div class="flex items-center gap-2">
                      <div class="flex-1 flex items-center gap-2 bg-slate-800/30 border border-slate-700/40 rounded-2xl px-4 py-3">
                        <span class="text-sm text-gray-300 tabular-nums">{{this.extraTimeHalfDurationCalc}}</span>
                        <span class="text-xs text-gray-600">min</span>
                        <svg class="w-3.5 h-3.5 text-gray-600 ml-auto flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
                          /></svg>
                      </div>
                      <span class="text-gray-400 text-sm flex-shrink-0">Minutes</span>
                    </div>
                  {{/if}}
                </div>
              {{/if}}

              {{! Note }}
              <div class="space-y-1.5">
                <label class="block text-gray-400 text-sm font-medium">
                  Note
                  <span class="text-gray-600 text-xs font-normal">(optional)</span>
                </label>
                <textarea
                  rows="3"
                  placeholder="e.g. Both teams confirmed"
                  class="w-full bg-slate-800/60 border border-slate-700/50 rounded-2xl px-4 py-3 text-sm text-white placeholder-gray-600 focus:outline-none focus:border-cyan-500/60 focus:ring-1 focus:ring-cyan-500/20 transition-all resize-none"
                  {{on "input" (fn this.setField "note")}}
                >{{this.note}}</textarea>
              </div>

            {{else}}

              {{! ── CRICKET FORM ────────────────────────────────────── }}

              {{! Photo upload }}
              <div class="space-y-2">
                <label class="block text-gray-400 text-sm font-medium">
                  Match Photo
                  <span class="text-gray-600 text-xs font-normal">(optional)</span>
                </label>
                <div class="w-36">
                  <ImageUploader @type="cricket_game_logo" @aspectRatio="1/1" @onChange={{this.onPhotoUploaded}} />
                </div>
              </div>

              {{! Date & Time }}
              <div class="grid grid-cols-2 gap-3">
                <div class="space-y-1.5">
                  <label class="block text-gray-400 text-sm font-medium">
                    Date
                    <span class="text-red-400">*</span>
                  </label>
                  <div
                    class="w-full bg-slate-800/60 border {{if this.errors.matchDate 'border-red-500/60' 'border-slate-700/50'}} rounded-2xl cursor-pointer"
                    role="button"
                    {{on "click" this.openPicker}}
                  >
                    <input
                      type="date"
                      value={{this.matchDate}}
                      class="w-full bg-transparent px-4 py-3 text-sm text-white focus:outline-none [color-scheme:dark] cursor-pointer"
                      {{on "change" (fn this.setField "matchDate")}}
                    />
                  </div>
                  {{#if this.errors.matchDate}}
                    <p class="text-red-400 text-xs">{{this.errors.matchDate}}</p>
                  {{/if}}
                </div>
                <div class="space-y-1.5">
                  <label class="block text-gray-400 text-sm font-medium">
                    Time
                    <span class="text-red-400">*</span>
                  </label>
                  <div
                    class="w-full bg-slate-800/60 border {{if this.errors.matchTime 'border-red-500/60' 'border-slate-700/50'}} rounded-2xl cursor-pointer"
                    role="button"
                    {{on "click" this.openPicker}}
                  >
                    <input
                      type="time"
                      value={{this.matchTime}}
                      class="w-full bg-transparent px-4 py-3 text-sm text-white focus:outline-none [color-scheme:dark] cursor-pointer"
                      {{on "change" (fn this.setField "matchTime")}}
                    />
                  </div>
                  {{#if this.errors.matchTime}}
                    <p class="text-red-400 text-xs">{{this.errors.matchTime}}</p>
                  {{/if}}
                </div>
              </div>

              {{! Game Type }}
              <div class="space-y-1.5">
                <label class="block text-gray-400 text-sm font-medium">
                  Type of Game
                  <span class="text-red-400">*</span>
                </label>

                {{! Trigger button }}
                <button
                  type="button"
                  class="w-full flex items-center justify-between bg-slate-800/60 border
                    {{if this.errors.gameType 'border-red-500/60' 'border-slate-700/50'}}
                    rounded-2xl px-4 py-3 text-sm transition-all hover:border-slate-600/60"
                  {{on "click" this.toggleGameTypePicker}}
                >
                  <span class="{{if this.gameType 'text-white font-medium' 'text-gray-500'}}">
                    {{if this.gameType this.gameType "Select game type"}}
                  </span>
                  <svg
                    class="w-4 h-4 text-gray-500 flex-shrink-0 transition-transform {{if this.showGameTypePicker 'rotate-180' ''}}"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                  </svg>
                </button>

                {{! Custom list }}
                {{#if this.showGameTypePicker}}
                  <div class="rounded-2xl border border-slate-700/50 overflow-hidden bg-slate-900 shadow-xl shadow-black/40">
                    {{#each GAME_TYPES as |type|}}
                      <button
                        type="button"
                        class="w-full text-left px-5 py-3.5 text-sm font-semibold transition-colors border-b border-slate-800/60 last:border-b-0
                          {{if (eq this.gameType type) 'bg-cyan-500/10 text-cyan-400' 'text-white hover:bg-slate-800/80'}}"
                        {{on "click" (fn this.selectGameType type)}}
                      >
                        <div class="flex items-center justify-between">
                          <span>{{type}}</span>
                          {{#if (eq this.gameType type)}}
                            <svg class="w-4 h-4 text-cyan-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7" />
                            </svg>
                          {{/if}}
                        </div>
                      </button>
                    {{/each}}
                  </div>
                {{/if}}

                {{#if this.errors.gameType}}
                  <p class="text-red-400 text-xs">{{this.errors.gameType}}</p>
                {{/if}}
              </div>

              {{! Match Name }}
              <div class="space-y-1.5">
                <label class="block text-gray-400 text-sm font-medium">
                  Match Name
                  <span class="text-red-400">*</span>
                </label>
                <input
                  type="text"
                  placeholder="e.g. Season Opener 2025"
                  value={{this.matchName}}
                  class="w-full bg-slate-800/60 border
                    {{if this.errors.matchName 'border-red-500/60' 'border-slate-700/50'}}
                    rounded-2xl px-4 py-3 text-sm text-white placeholder-gray-600 focus:outline-none focus:border-cyan-500/60 focus:ring-1 focus:ring-cyan-500/20 transition-all"
                  {{on "input" (fn this.setField "matchName")}}
                />
                {{#if this.errors.matchName}}
                  <p class="text-red-400 text-xs">{{this.errors.matchName}}</p>
                {{/if}}
              </div>

              {{! Match Overs }}
              <div class="space-y-1.5">
                <label class="block text-gray-400 text-sm font-medium">
                  Match Overs
                  <span class="text-red-400">*</span>
                </label>
                <input
                  type="number"
                  min="1"
                  max="100"
                  placeholder="20"
                  value={{this.matchOvers}}
                  class="w-full bg-slate-800/60 border
                    {{if this.errors.matchOvers 'border-red-500/60' 'border-slate-700/50'}}
                    rounded-2xl px-4 py-3 text-sm text-white placeholder-gray-600 focus:outline-none focus:border-cyan-500/60 focus:ring-1 focus:ring-cyan-500/20 transition-all"
                  {{on "input" (fn this.setField "matchOvers")}}
                />
                {{#if this.errors.matchOvers}}
                  <p class="text-red-400 text-xs">{{this.errors.matchOvers}}</p>
                {{/if}}
              </div>

              {{! Number Of Players A Side — only when both teams ready with no conflicts }}
              {{#if this.opponentReadyForNext}}
                <div class="space-y-1.5">
                  <label class="block text-gray-400 text-sm font-medium">
                    Number Of Players A Side
                    <span class="text-red-400">*</span>
                  </label>
                  <div class="relative">
                    <select
                      class="w-full appearance-none bg-slate-800/60 border border-slate-700/50 rounded-2xl px-4 py-3 text-sm text-white focus:outline-none focus:border-cyan-500/60 focus:ring-1 focus:ring-cyan-500/20 transition-all cursor-pointer [color-scheme:dark]"
                      {{on "change" this.onPlayersPerSideChange}}
                    >
                      {{#each this.playersPerSideOptions as |n|}}
                        <option value={{n}} selected={{eq this.playersPerSide n}}>{{n}}</option>
                      {{/each}}
                    </select>
                    <svg
                      class="absolute right-4 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500 pointer-events-none"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                    </svg>
                  </div>
                </div>
              {{/if}}

              {{! Match Prize }}
              <div class="space-y-1.5">
                <label class="block text-gray-400 text-sm font-medium">
                  Match Prize
                  <span class="text-gray-600 text-xs font-normal">(optional)</span>
                </label>
                <input
                  type="text"
                  placeholder="e.g. 5000 BDT"
                  value={{this.matchPrize}}
                  class="w-full bg-slate-800/60 border border-slate-700/50 rounded-2xl px-4 py-3 text-sm text-white placeholder-gray-600 focus:outline-none focus:border-cyan-500/60 focus:ring-1 focus:ring-cyan-500/20 transition-all"
                  {{on "input" (fn this.setField "matchPrize")}}
                />
              </div>

              {{! Ball Type }}
              <div class="space-y-1.5">
                <label class="block text-gray-400 text-sm font-medium">
                  Ball Type
                  <span class="text-red-400">*</span>
                </label>

                <button
                  type="button"
                  class="w-full flex items-center justify-between bg-slate-800/60 border
                    {{if this.errors.ballType 'border-red-500/60' 'border-slate-700/50'}}
                    rounded-2xl px-4 py-3 text-sm transition-all hover:border-slate-600/60"
                  {{on "click" this.toggleBallTypePicker}}
                >
                  <span class="{{if this.ballType 'text-white font-medium' 'text-gray-500'}}">
                    {{if this.ballType this.ballType "Select ball type"}}
                  </span>
                  <svg
                    class="w-4 h-4 text-gray-500 flex-shrink-0 transition-transform {{if this.showBallTypePicker 'rotate-180' ''}}"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                  </svg>
                </button>

                {{#if this.showBallTypePicker}}
                  <div class="rounded-2xl border border-slate-700/50 overflow-hidden bg-slate-900 shadow-xl shadow-black/40">
                    {{#each BALL_TYPES as |type|}}
                      <button
                        type="button"
                        class="w-full text-left px-5 py-3.5 text-sm font-semibold transition-colors border-b border-slate-800/60 last:border-b-0
                          {{if (eq this.ballType type) 'bg-cyan-500/10 text-cyan-400' 'text-white hover:bg-slate-800/80'}}"
                        {{on "click" (fn this.selectBallType type)}}
                      >
                        <div class="flex items-center justify-between">
                          <span>{{type}}</span>
                          {{#if (eq this.ballType type)}}
                            <svg class="w-4 h-4 text-cyan-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7" />
                            </svg>
                          {{/if}}
                        </div>
                      </button>
                    {{/each}}
                  </div>
                {{/if}}

                {{#if this.errors.ballType}}
                  <p class="text-red-400 text-xs">{{this.errors.ballType}}</p>
                {{/if}}
              </div>

              {{! Phone Number }}
              <div class="space-y-1.5">
                <label class="block text-gray-400 text-sm font-medium">
                  Phone No
                  <span class="text-red-400">*</span>
                </label>
                <div
                  class="flex items-center bg-slate-800/60 border
                    {{if this.errors.phoneNumber 'border-red-500/60' 'border-slate-700/50'}}
                    rounded-2xl overflow-hidden focus-within:border-cyan-500/60 focus-within:ring-1 focus-within:ring-cyan-500/20 transition-all"
                >
                  {{! Country code trigger }}
                  <button
                    type="button"
                    class="flex items-center gap-2 px-4 py-3 border-r border-slate-700/50 flex-shrink-0 hover:bg-slate-700/40 transition-colors"
                    {{on "click" this.toggleCountryPicker}}
                  >
                    {{#if this.phoneCountry.flag}}
                      <img src={{this.phoneCountry.flag}} alt={{this.phoneCountry.code}} class="w-5 h-3.5 object-cover rounded-sm flex-shrink-0" />
                    {{else}}
                      <span class="w-5 h-3.5 bg-slate-600 rounded-sm flex-shrink-0"></span>
                    {{/if}}
                    <span class="text-gray-300 text-sm font-medium">{{this.phoneCountry.dial}}</span>
                    <svg
                      class="w-3 h-3 text-gray-500 transition-transform {{if this.showCountryPicker 'rotate-180' ''}}"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                    </svg>
                  </button>
                  <input
                    type="tel"
                    placeholder="Phone number"
                    value={{this.phoneNumber}}
                    class="flex-1 bg-transparent px-4 py-3 text-sm text-white placeholder-gray-600 focus:outline-none"
                    {{on "input" (fn this.setField "phoneNumber")}}
                  />
                </div>

                {{! Country picker dropdown }}
                {{#if this.showCountryPicker}}
                  <div class="rounded-2xl border border-slate-700/50 bg-slate-900 shadow-xl shadow-black/40 overflow-hidden">
                    {{! Search }}
                    <div class="p-3 border-b border-slate-800">
                      <div class="flex items-center gap-2 bg-slate-800/80 rounded-xl px-3 py-2">
                        <svg class="w-4 h-4 text-gray-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                        </svg>
                        <input
                          type="text"
                          placeholder="Search country or code..."
                          value={{this.countrySearch}}
                          class="flex-1 bg-transparent text-sm text-white placeholder-gray-500 focus:outline-none"
                          {{on "input" this.onCountrySearch}}
                        />
                      </div>
                    </div>
                    {{! List }}
                    <div class="max-h-52 overflow-y-auto">
                      {{#if this.filteredCountries.length}}
                        {{#each this.filteredCountries as |country|}}
                          <button
                            type="button"
                            class="w-full flex items-center gap-3 px-4 py-2.5 text-sm transition-colors border-b border-slate-800/40 last:border-b-0
                              {{if (eq this.phoneCountry.code country.code) 'bg-cyan-500/10 text-cyan-400' 'text-white hover:bg-slate-800/80'}}"
                            {{on "click" (fn this.selectCountry country)}}
                          >
                            {{#if country.flag}}
                              <img src={{country.flag}} alt={{country.code}} class="w-6 h-4 object-cover rounded-sm flex-shrink-0" />
                            {{else}}
                              <span class="w-6 h-4 bg-slate-600 rounded-sm flex-shrink-0"></span>
                            {{/if}}
                            <span class="flex-1 text-left truncate">{{country.name}}</span>
                            <span class="text-gray-500 text-xs flex-shrink-0">{{country.dial}}</span>
                          </button>
                        {{/each}}
                      {{else}}
                        <p class="text-center text-gray-500 text-sm py-6">No results</p>
                      {{/if}}
                    </div>
                  </div>
                {{/if}}

                {{#if this.errors.phoneNumber}}
                  <p class="text-red-400 text-xs">{{this.errors.phoneNumber}}</p>
                {{/if}}
              </div>

              {{! Facility Search }}
              <div class="space-y-1.5">
                <label class="block text-gray-400 text-sm font-medium">
                  Search Facility
                  <span class="ml-1 text-xs font-normal text-gray-500">(optional)</span>
                </label>
                <div class="relative">
                  {{#if this.selectedFacility}}
                    <div class="flex items-center gap-3 bg-slate-800/60 border border-cyan-500/40 rounded-2xl px-4 py-3">
                      {{#if (this._facilityLogoUrl this.selectedFacility.fac_logo)}}
                        <img
                          src={{this._facilityLogoUrl this.selectedFacility.fac_logo}}
                          alt={{this.selectedFacility.fac_name}}
                          class="w-8 h-8 rounded-lg object-cover flex-shrink-0"
                        />
                      {{else}}
                        <div class="w-8 h-8 rounded-lg bg-slate-700 flex items-center justify-center flex-shrink-0">
                          <svg class="w-4 h-4 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="2"
                              d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"
                            /><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" /></svg>
                        </div>
                      {{/if}}
                      <div class="flex-1 min-w-0">
                        <p class="text-sm font-semibold text-white truncate">{{this.selectedFacility.fac_name}}</p>
                        <p class="text-xs text-gray-500 truncate">{{this.selectedFacility.fac_address}}</p>
                      </div>
                      <button type="button" {{on "click" this.clearFacility}} class="text-gray-500 hover:text-red-400 transition-colors flex-shrink-0">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M6 18L18 6M6 6l12 12"
                          /></svg>
                      </button>
                    </div>
                  {{else}}
                    <div class="relative">
                      <input
                        type="text"
                        placeholder="Search by facility name…"
                        value={{this.facilityQuery}}
                        autocomplete="off"
                        class="w-full bg-slate-800/60 border border-slate-700/50 rounded-2xl px-4 py-3 pr-9 text-sm text-white placeholder-gray-500 focus:outline-none focus:border-cyan-500/60 focus:ring-1 focus:ring-cyan-500/20 transition-all"
                        {{on "input" this.onFacilityInput}}
                        {{on "focus" this.onFacilityFocus}}
                        {{on "blur" this.onFacilityBlur}}
                      />
                      {{#if this.facilitySearching}}
                        <span class="absolute right-3 top-1/2 -translate-y-1/2">
                          <svg class="w-4 h-4 text-cyan-400 animate-spin" fill="none" viewBox="0 0 24 24">
                            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
                            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z" />
                          </svg>
                        </span>
                      {{/if}}
                    </div>
                    {{#if this.showFacilityResults}}
                      <ul
                        class="absolute z-50 top-full mt-1.5 w-full bg-slate-900 border border-slate-700 rounded-2xl shadow-2xl overflow-hidden divide-y divide-slate-700/60 max-h-64 overflow-y-auto"
                      >
                        {{#if this.facilityResults.length}}
                          {{#each this.facilityResults as |fac|}}
                            <li>
                              <button
                                type="button"
                                {{on "click" (fn this.selectFacility fac)}}
                                class="w-full text-left px-4 py-3 flex items-center gap-3 hover:bg-cyan-900/30 transition-colors"
                              >
                                {{#if (this._facilityLogoUrl fac.fac_logo)}}
                                  <img src={{this._facilityLogoUrl fac.fac_logo}} alt={{fac.fac_name}} class="w-9 h-9 rounded-lg object-cover flex-shrink-0" />
                                {{else}}
                                  <div class="w-9 h-9 rounded-lg bg-slate-700 flex items-center justify-center flex-shrink-0">
                                    <svg class="w-4 h-4 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path
                                        stroke-linecap="round"
                                        stroke-linejoin="round"
                                        stroke-width="2"
                                        d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"
                                      /></svg>
                                  </div>
                                {{/if}}
                                <div class="flex-1 min-w-0">
                                  <p class="text-sm font-semibold text-white truncate">{{fac.fac_name}}</p>
                                  <p class="text-xs text-gray-500 truncate">{{fac.fac_address}}</p>
                                  {{#if fac.fac_sports.length}}
                                    <div class="flex gap-1 mt-1 flex-wrap">
                                      {{#each fac.fac_sports as |sport|}}
                                        <span class="text-[10px] px-1.5 py-0.5 rounded-full bg-slate-700 text-gray-400 capitalize">{{sport}}</span>
                                      {{/each}}
                                    </div>
                                  {{/if}}
                                </div>
                              </button>
                            </li>
                          {{/each}}
                        {{else}}
                          <li class="px-4 py-4 text-sm text-gray-500 text-center">No facilities found</li>
                        {{/if}}
                      </ul>
                    {{/if}}
                  {{/if}}
                </div>
              </div>

              {{! Match Field Name }}
              <div class="space-y-1.5">
                <label class="block text-gray-400 text-sm font-medium">
                  Match Field Name
                  <span class="text-red-400">*</span>
                </label>
                <input
                  type="text"
                  placeholder="Match Field Name"
                  value={{this.fieldName}}
                  class="w-full bg-slate-800/60 border
                    {{if this.errors.fieldName 'border-red-500/60' 'border-slate-700/50'}}
                    rounded-2xl px-4 py-3 text-sm text-white placeholder-gray-600 focus:outline-none focus:border-cyan-500/60 focus:ring-1 focus:ring-cyan-500/20 transition-all"
                  {{on "input" (fn this.setField "fieldName")}}
                />
                {{#if this.errors.fieldName}}
                  <p class="text-red-400 text-xs">{{this.errors.fieldName}}</p>
                {{/if}}
              </div>

              {{! Select Location }}
              <div class="space-y-1.5">
                <label class="block text-gray-400 text-sm font-medium">
                  Select Location
                  <span class="text-red-400">*</span>
                </label>
                <div class="flex items-center gap-2">
                  <div class="relative flex-1">
                    <input
                      type="text"
                      placeholder="Start typing your address…"
                      value={{this.locationText}}
                      autocomplete="off"
                      class="w-full bg-slate-800/60 border
                        {{if this.errors.locationText 'border-red-500/60' 'border-slate-700/50'}}
                        rounded-2xl px-4 py-3 pr-9 text-sm text-white placeholder-gray-500 focus:outline-none focus:border-cyan-500/60 focus:ring-1 focus:ring-cyan-500/20 transition-all"
                      {{on "input" (fn this.setField "locationText")}}
                    />
                    {{#if this.placesLoading}}
                      <span class="absolute right-3 top-1/2 -translate-y-1/2">
                        <svg class="w-4 h-4 text-cyan-400 animate-spin" fill="none" viewBox="0 0 24 24">
                          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
                          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z" />
                        </svg>
                      </span>
                    {{/if}}
                    {{#if this.showPlaces}}
                      <ul
                        class="absolute z-50 top-full mt-1.5 w-full bg-slate-900 border border-slate-700 rounded-2xl shadow-2xl overflow-hidden divide-y divide-slate-700/60"
                      >
                        {{#each this.placeSuggestions as |suggestion|}}
                          <li>
                            <button
                              type="button"
                              {{on "click" (fn this.selectPlace suggestion)}}
                              class="w-full text-left px-4 py-3 text-sm text-gray-200 hover:bg-cyan-900/30 flex items-center gap-3 transition-colors"
                            >
                              <svg class="w-4 h-4 shrink-0 text-cyan-400" fill="currentColor" viewBox="0 0 20 20">
                                <path
                                  fill-rule="evenodd"
                                  d="M5.05 4.05a7 7 0 119.9 9.9L10 18.9l-4.95-4.95a7 7 0 010-9.9zM10 11a2 2 0 100-4 2 2 0 000 4z"
                                  clip-rule="evenodd"
                                />
                              </svg>
                              <span class="truncate">{{suggestion.description}}</span>
                            </button>
                          </li>
                        {{/each}}
                      </ul>
                    {{/if}}
                  </div>
                  <span class="text-gray-500 text-xs font-medium flex-shrink-0">OR</span>
                  <LocationPicker @onSelect={{this.handleLocationSelect}} />
                </div>
              </div>

            {{/if}}{{! end football/cricket if }}

            {{! Submit }}
            <div class="pt-2 pb-8">
              <button
                type="submit"
                disabled={{this.isSubmitting}}
                class="w-full flex items-center justify-center gap-2 py-4 rounded-2xl font-semibold text-sm transition-all
                  {{if
                    this.isSubmitting
                    'bg-slate-700 text-gray-500 cursor-not-allowed'
                    'bg-gradient-to-r from-cyan-600 to-cyan-500 hover:from-cyan-500 hover:to-cyan-400 text-white shadow-xl shadow-cyan-600/25 active:scale-[0.98]'
                  }}"
              >
                {{#if this.isSubmitting}}
                  <div class="w-4 h-4 border-2 border-gray-500 border-t-transparent rounded-full animate-spin"></div>
                  Creating Match...
                {{else}}
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                  </svg>
                  Create Match
                {{/if}}
              </button>
            </div>

          </form>
        {{/if}}
      </div>
    </div>
  </template>
}
