import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { eq } from 'ember-truth-helpers';
import { service } from '@ember/service';
import { getUserLocation } from 'spordium/utils/utility.helper';

const TABS = [
  { id: 'about',       label: 'About Us' },
  { id: 'trophies',    label: 'Trophies' },
  { id: 'teams',       label: 'Teams' },
  { id: 'fixture',     label: 'Fixture' },
  { id: 'live',        label: 'Live Match' },
  { id: 'previous',    label: 'Previous Match' },
  { id: 'events',      label: 'Club Events' },
  { id: 'facilities',  label: 'Facilities' },
  { id: 'tournaments', label: 'Club Tournaments' },
  { id: 'recruitments',label: 'Recruitments' },
  { id: 'bookfield',   label: 'Book Field' },
  { id: 'posts',       label: 'Posts' },
  { id: 'gallery',     label: 'Gallery' },
];

const SKELETON_ROWS = [1, 2, 3];

// ══════════════════════════════════════════════════════════════════════════════
export default class ClubDetails extends Component {
  @service session;
  @tracked club               = null;
  @tracked currentUser        = null;
  @tracked isLoading          = true;
  @tracked error              = null;
  @tracked activeTab          = 'about';
  @tracked isCurrentUserClub  = false;
  @tracked tabBarAtStart      = true;
  @tracked tabBarAtEnd        = false;

  constructor(owner, args) {
    super(owner, args);
    // Fire both fetches in parallel so ownership is resolved before the UI renders
    this.fetchDetails();
    this.prefetchUserClubs();
  }

  async prefetchUserClubs() {
    try {
      const token = this.session.token;
      if (!token) return;
      const res  = await fetch('https://spordiumapi.adnanfoundation.com/clubs/user-clubs/', {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Accept':        'application/json',
        },
      });
      if (!res.ok) return;
      const json  = await res.json();
      const clubs = Array.isArray(json) ? json : (json.data ?? json.results ?? []);
      const currentId = this.args.clubId;
      this.isCurrentUserClub = clubs.some(
        (c) => c.club_id === currentId || c.id === currentId,
      );
    } catch {
      // silently ignore — ownership check is non-critical
    }
  }

  async fetchDetails() {
    this.isLoading = true;
    this.error     = null;
    try {
      const url = `https://spordiumapi.adnanfoundation.com/clubs/details/?club_id=${encodeURIComponent(this.args.clubId)}&country_code=BD`;
      const res  = await fetch(url);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json = await res.json();
      this.club  = json.data;
    } catch {
      this.error = 'Failed to load club details. Please try again.';
    } finally {
      this.isLoading = false;
    }
    this.currentUser = await this.session.getCurrentUser();
  }

  // ── Teams ─────────────────────────────────────────────────────────────────
  @tracked teams        = [];
  @tracked teamsLoading = false;
  @tracked teamsError   = null;
  _teamsFetched         = false;

  async fetchTeams() {
    if (this.teamsLoading) return;
    this.teamsLoading = true;
    this.teamsError   = null;
    try {
      const clubId = this.club?.club_id ?? this.args.clubId;
      const url = `https://khelasearch.adnanfoundation.com/search/cricket-team-details-by-id/?club_id=${encodeURIComponent(clubId)}&limit=100&offset=0&page=1`;
      const res  = await fetch(url);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json = await res.json();
      this.teams = json.results ?? [];
    } catch {
      this.teamsError = 'Failed to load teams. Please try again.';
    } finally {
      this.teamsLoading = false;
      this._teamsFetched = true;
    }

  }

  @action retry()     { this.fetchDetails(); }
  @action retryTeams(){ this.fetchTeams(); }

  @action setTab(tab, event) {
    this.activeTab = tab;
    if (tab === 'teams' && !this._teamsFetched) {
      this.fetchTeams();
    }
    // Scroll the clicked button into the visible portion of the tab strip
    event?.currentTarget?.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'nearest' });
  }

  @action onTabBarScroll(event) {
    const el = event.target;
    this.tabBarAtStart = el.scrollLeft <= 2;
    this.tabBarAtEnd   = el.scrollLeft + el.clientWidth >= el.scrollWidth - 2;
  }

  @action scrollTabsLeft() {
    document.getElementById('club-tab-bar')?.scrollBy({ left: -200, behavior: 'smooth' });
  }

  @action scrollTabsRight() {
    document.getElementById('club-tab-bar')?.scrollBy({ left: 200, behavior: 'smooth' });
  }

  get tabs()            { return TABS; }
  get skeletonRows()    { return SKELETON_ROWS; }

  get established() {
    if (!this.club?.established_date) return null;
    return new Date(this.club.established_date).getFullYear();
  }

  get clubTypeBadge() {
    const t = this.club?.club_type;
    if (!t) return null;
    return t.charAt(0).toUpperCase() + t.slice(1);
  }

  get mapUrl()          { return this.club?.location ?? null; }
  get hasManagers()     { return (this.club?.managers?.length ?? 0) > 0; }

  /**
   * Returns true when the currently logged-in user is one of this club's managers.
   * Use this getter anywhere in the template to show/hide manager-only controls.
   */
  get isClubManager() {
    const userId = this.currentUser?.user_id;
    //console.log('current user_id: ',userId,'\tManager List: ',JSON.stringify(this.club.managers))
    if (!userId || !this.club?.managers?.length) return false;
    return this.club.managers.some((m) => m.id === userId);
  }


  get clubDescription() {
    const d = this.club?.description;
    if (!d || !d.length) return null;
    return d.trim();
  }

  get managersForDisplay() {
    return (this.club?.managers ?? []).map((m, i) => {
      const first = m?.name?.first_name?.trim() ?? '';
      const last  = m?.name?.last_name?.trim()  ?? '';
      const fullName = [first, last].filter(Boolean).join(' ') || 'Unknown';
      const initials = [first[0], last[0]].filter(Boolean).join('').toUpperCase() || '?';
      const GRAD_COLORS = [
        'from-indigo-500 to-violet-600',
        'from-rose-500 to-pink-600',
        'from-amber-500 to-orange-500',
        'from-teal-500 to-cyan-500',
        'from-fuchsia-500 to-purple-600',
      ];
      return { id: m?.id ?? '', fullName, initials, gradColor: GRAD_COLORS[i % GRAD_COLORS.length] };
    });
  }
  get hasTrophies()     { return (this.club?.trophies?.length ?? 0) > 0; }
  get hasRecentMatches(){ return (this.club?.recent_matches?.length ?? 0) > 0; }
  get hasSports()       { return (this.club?.sports?.length ?? 0) > 0; }

  teamLogoUrl(path) {
    if (!path) return null;
    if (path.startsWith('http')) return path;
    return `https://ag-khela.s3.ap-south-1.amazonaws.com/${path}`;
  }

  get teamsWithRank() {
    return this.teams.map((t, i) => ({ ...t, rank: i + 1 }));
  }

  get trophyCount() {
    return this.club?.trophies?.length ?? 0;
  }

  // ── Add Team modal ───────────────────────────────────────────────────────
  @tracked showAddTeamModal    = false;
  @tracked myTeamSearch        = '';
  @tracked otherTeamSearch     = '';
  @tracked selectedTeamType    = 'my';
  @tracked isAddingTeam        = false;
  @tracked teamSearchResults   = [];
  @tracked teamSearchLoading   = false;
  @tracked teamSearchError     = null;
  @tracked selectedTeam        = null;
  @tracked addTeamSuccess      = null;
  @tracked addTeamError        = null;

  @action openAddTeamModal() {
    this.showAddTeamModal = true;
    this.fetchTeamSuggestions();
  }

  @action closeAddTeamModal() {
    this.showAddTeamModal    = false;
    this.myTeamSearch        = '';
    this.otherTeamSearch     = '';
    this.selectedTeamType    = 'my';
    this.teamSearchResults   = [];
    this.teamSearchError     = null;
    this.selectedTeam        = null;
    this.addTeamSuccess      = null;
    this.addTeamError        = null;
  }

  async fetchTeamSuggestions() {
    this.teamSearchLoading = true;
    this.teamSearchError   = null;
    try {
      const user   = await this.session.getCurrentUser();
      const userId = user?.user_id ?? '';
      const loc    = await getUserLocation();
      const lat    = loc?.geo?.lat  ?? 23.7943;
      const lng    = loc?.geo?.long ?? 90.4072;
      const url    = `https://khelasearch.adnanfoundation.com/search/cricket-team-search/?search_data=owner@${userId}&latitude=${lat}&longitude=${lng}&limit=100&offset=10&page=1&country_code=BD&suggations=true`;
      const res    = await fetch(url);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json   = await res.json();
      this.teamSearchResults = json.suggestions?.results ?? [];
    } catch {
      this.teamSearchError = 'Could not load teams. Please try again.';
    } finally {
      this.teamSearchLoading = false;
    }
  }

  @action updateAddTeamField(field, event) {
    this[field] = event.target.value;
  }

  @action selectTeamType(type) {
    this.selectedTeamType = type;
    this.selectedTeam     = null;
  }

  @action toggleSelectTeam(team) {
    this.selectedTeam =
      this.selectedTeam?.team_id === team.team_id ? null : team;
  }

  @action async addTeam() {
    if (!this.selectedTeam || this.isAddingTeam) return;
    this.isAddingTeam   = true;
    this.addTeamError   = null;
    this.addTeamSuccess = null;
    try {
      const payload = {
        club_id:           this.club.club_id,
        teams:             [{ team_id: this.selectedTeam.team_id, owner_id: this.selectedTeam.team_owner }],
        team_country_code: 'BD',
      };
      const res = await fetch('https://spordiumapi.adnanfoundation.com/clubs/teams/', {
        method:  'POST',
        headers: {
          'Authorization': `Bearer ${this.session.token}`,
          'Content-Type':  'application/json',
          'Accept':        'application/json',
        },
        body: JSON.stringify(payload),
      });
      const json = await res.json();
      if (!res.ok) throw new Error(json?.message ?? `HTTP ${res.status}`);
      this.addTeamSuccess = json.message ?? 'Team request sent successfully.';
    } catch (err) {
      this.addTeamError = err?.message ?? 'Failed to add team. Please try again.';
    } finally {
      this.isAddingTeam = false;
    }
  }

  get myTeams() {
    const userId = this.currentUser?.user_id;
    const q      = this.myTeamSearch.trim().toLowerCase();
    return this.teamSearchResults
      .filter((t) => t.team_owner === userId)
      .filter((t) => !q || t.team_name.toLowerCase().includes(q));
  }

  get otherTeams() {
    const userId = this.currentUser?.user_id;
    const q      = this.otherTeamSearch.trim().toLowerCase();
    return this.teamSearchResults
      .filter((t) => t.team_owner !== userId)
      .filter((t) => !q || t.team_name.toLowerCase().includes(q));
  }

  teamLogoSrc(path) {
    if (!path) return null;
    if (path.startsWith('http')) return path;
    return `https://ag-khela.s3.ap-south-1.amazonaws.com/${path}`;
  }

  // ── Add Trophy modal ─────────────────────────────────────────────────────
  @tracked showTrophyModal    = false;
  @tracked trophyName             = '';
  @tracked trophyMatchName        = '';
  @tracked trophyTournament       = '';
  @tracked trophyWinningPosition  = '';
  @tracked trophyDate             = '';
  @tracked trophyPictureFile      = null;
  @tracked trophyPicturePreview = null;
  @tracked trophyPictureError = '';
  @tracked isSavingTrophy     = false;
  @tracked trophyError        = '';
  @tracked trophySuccess      = '';

  @action openTrophyModal()  { this.showTrophyModal = true; }
  @action closeTrophyModal() {
    this.showTrophyModal       = false;
    this.trophyName            = '';
    this.trophyMatchName       = '';
    this.trophyTournament      = '';
    this.trophyWinningPosition = '';
    this.trophyDate            = '';
    this.trophyPictureFile     = null;
    this.trophyPicturePreview  = null;
    this.trophyPictureError    = '';
    this.trophyError           = '';
    this.trophySuccess         = '';
  }

  @action async saveTrophy() {
    if (this.isSavingTrophy) return;
    const missing = [];
    if (!this.trophyPictureFile)     missing.push('Trophy Picture');
    if (!this.trophyName.trim())     missing.push('Trophy Name');
    if (!this.trophyMatchName.trim()) missing.push('Match Name');
    if (!this.trophyTournament.trim()) missing.push('Tournament Name');
    if (!this.trophyWinningPosition.trim()) missing.push('Winning Position');
    if (!this.trophyDate)            missing.push('Date of Achievement');
    if (missing.length) {
      this.trophyError = `Required: ${missing.join(', ')}`;
      return;
    }
    this.isSavingTrophy = true;
    this.trophyError    = '';
    this.trophySuccess  = '';
    try {
      const date            = this.trophyDate;
      const year            = parseInt(date.split('-')[0], 10);
      const winningDateTime = `${date}T00:00:00.000`;

      const payload = JSON.stringify({
        club_id:                   this.club.club_id,
        trophie_winning_date_time: winningDateTime,
        trophie_year:              year,
        trophie_name:              this.trophyName.trim(),
        trophie_match_name:        this.trophyMatchName.trim(),
        trophie_tournament_name:   this.trophyTournament.trim(),
        trophie_winning_position:  this.trophyWinningPosition.trim(),
      });

      const blob     = new Blob([this.trophyPictureFile], { type: 'application/octet-stream' });
      const formData = new FormData();
      formData.append('payload', payload);
      formData.append('picture', blob, 'trophy.jpg');

      const res  = await fetch('https://spordiumapi.adnanfoundation.com/clubs/trophies/', {
        method:  'POST',
        headers: { 'Authorization': `Bearer ${this.session.token}` },
        body:    formData,
      });
      const json = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(json?.message ?? `HTTP ${res.status}`);
      this.trophySuccess         = json.message ?? 'Trophy added successfully.';
      this.trophyName            = '';
      this.trophyMatchName       = '';
      this.trophyTournament      = '';
      this.trophyWinningPosition = '';
      this.trophyDate            = '';
      this.trophyPictureFile     = null;
      this.trophyPicturePreview  = null;
      this.trophyPictureError    = '';
      await this.fetchDetails();
    } catch (err) {
      this.trophyError = err?.message ?? 'Failed to add trophy. Please try again.';
    } finally {
      this.isSavingTrophy = false;
    }
  }

  @action handleTrophyPicture(event) {
    const file = event.target.files?.[0];
    if (!file) return;
    if (file.size > 100 * 1024) {
      this.trophyPictureError = 'Image must be under 100 KB.';
      return;
    }
    this.trophyPictureError = '';
    this.trophyPictureFile  = file;
    const reader = new FileReader();
    reader.onload = (e) => { this.trophyPicturePreview = e.target.result; };
    reader.readAsDataURL(file);
  }

  @action updateTrophyField(field, event) {
    this[field] = event.target.value;
  }

  get today() {
    return new Date().toISOString().slice(0, 10);
  }

  get trophiesByYear() {
    const trophies = this.club?.trophies ?? [];
    const groups = {};
    trophies.forEach(t => {
      const year  = t?.trophie_year ?? 'Unknown';
      const name  = t?.trophie_name ?? '';
      const image = t?.trophie_picture ?? null;
      const tournament = t?.trophie_tournament_name ?? null;
      if (!groups[year]) groups[year] = [];
      groups[year].push({ name, image, tournament });
    });
    return Object.entries(groups)
      .sort(([a], [b]) => Number(b) - Number(a))
      .map(([year, items]) => ({ year, items }));
  }

  <template>
    {{! ── Add Trophy Modal ──────────────────────────────────────────────── }}
    {{#if this.showTrophyModal}}
      {{! Backdrop }}
      <div
        role="dialog"
        aria-modal="true"
        class="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4"
      >
        {{! Dimmed overlay }}
        <div
          class="absolute inset-0 bg-black/50 dark:bg-black/70 backdrop-blur-sm"
          {{on "click" this.closeTrophyModal}}
        ></div>

        {{! Panel }}
        <div class="relative w-full sm:max-w-md bg-white dark:bg-gray-900
                    rounded-t-3xl sm:rounded-3xl shadow-2xl shadow-black/20 dark:shadow-black/50
                    border border-gray-100 dark:border-gray-700/60
                    overflow-y-auto max-h-[90dvh] sm:max-h-[85vh] animate-fade-in">

          {{! Decorative top gradient strip }}
          <div class="h-1 w-full bg-gradient-to-r from-amber-400 via-yellow-400 to-amber-500"></div>

          <div class="px-6 pt-6 pb-8">

            {{! Header }}
            <div class="flex items-center justify-between mb-6">
              <div class="flex items-center gap-3">
                <div class="w-9 h-9 rounded-xl bg-gradient-to-br from-amber-400 to-yellow-500
                            flex items-center justify-center shadow-md shadow-amber-400/30 shrink-0">
                  <svg class="w-4.5 h-4.5 text-white" viewBox="0 0 24 24" fill="none"
                       stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M6 9H4.5a2.5 2.5 0 0 1 0-5H6"/>
                    <path d="M18 9h1.5a2.5 2.5 0 0 0 0-5H18"/>
                    <path d="M4 22h16"/>
                    <path d="M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22"/>
                    <path d="M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22"/>
                    <path d="M18 2H6v7a6 6 0 0 0 12 0V2z"/>
                  </svg>
                </div>
                <h2 class="text-lg font-bold text-gray-900 dark:text-white tracking-tight">Add Trophy</h2>
              </div>
              {{! Close button }}
              <button
                type="button"
                {{on "click" this.closeTrophyModal}}
                class="w-8 h-8 rounded-xl flex items-center justify-center
                       text-gray-400 hover:text-gray-600 dark:hover:text-gray-200
                       hover:bg-gray-100 dark:hover:bg-gray-800
                       transition-all duration-150 cursor-pointer">
                <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                     stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M18 6 6 18"/><path d="m6 6 12 12"/>
                </svg>
              </button>
            </div>

            {{! ── Trophy Picture ── }}
            <div class="mb-5">
              <label class="block text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-2">
                Trophy Picture
              </label>

              <input
                id="trophy-pic-input"
                type="file"
                accept="image/*"
                class="hidden"
                {{on "change" this.handleTrophyPicture}}
              />

              {{#if this.trophyPicturePreview}}
                {{! Preview + change button }}
                <div class="flex items-center gap-4">
                  <div class="w-20 h-20 rounded-2xl overflow-hidden ring-2 ring-amber-300 dark:ring-amber-600/50 shrink-0">
                    <img src={{this.trophyPicturePreview}} alt="Trophy preview"
                         class="w-full h-full object-cover" />
                  </div>
                  <div class="flex-1 min-w-0">
                    <button
                      type="button"
                      {{on "click" (fn (mut this.trophyPicturePreview) null)}}
                      class="text-xs text-red-500 hover:text-red-600 dark:text-red-400 font-medium underline cursor-pointer">
                      Remove photo
                    </button>
                    <p class="text-[11px] text-gray-400 dark:text-gray-500 mt-1">Max 100 KB · 720×550 px recommended</p>
                  </div>
                </div>
              {{else}}
                <label
                  for="trophy-pic-input"
                  class="flex items-center justify-center gap-2.5 w-full py-3.5 px-4 rounded-2xl
                         border-2 border-dashed border-amber-300 dark:border-amber-700/50
                         bg-amber-50/50 dark:bg-amber-900/10
                         text-amber-600 dark:text-amber-400 text-sm font-semibold
                         hover:bg-amber-100/60 dark:hover:bg-amber-900/20
                         hover:border-amber-400 dark:hover:border-amber-600
                         transition-all duration-200 cursor-pointer group">
                  <svg class="w-5 h-5 group-hover:scale-110 transition-transform duration-200"
                       viewBox="0 0 24 24" fill="none" stroke="currentColor"
                       stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
                    <polyline points="17 8 12 3 7 8"/>
                    <line x1="12" y1="3" x2="12" y2="15"/>
                  </svg>
                  Upload Trophy Picture
                </label>
                <p class="text-[11px] text-gray-400 dark:text-gray-500 text-center mt-1.5">
                  720×550 px recommended · Max 100 KB
                </p>
              {{/if}}

              {{#if this.trophyPictureError}}
                <p class="mt-1.5 text-xs text-red-500 dark:text-red-400 font-medium">
                  {{this.trophyPictureError}}
                </p>
              {{/if}}
            </div>

            {{! ── Trophy Name ── }}
            <div class="mb-4">
              <label class="block text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-1.5">
                Trophy Name <span class="text-red-400">*</span>
              </label>
              <input
                type="text"
                value={{this.trophyName}}
                placeholder="e.g. UEFA Champions League"
                {{on "input" (fn this.updateTrophyField "trophyName")}}
                class="w-full px-4 py-2.5 rounded-xl text-sm
                       bg-gray-50 dark:bg-gray-800
                       border border-gray-200 dark:border-gray-700
                       text-gray-900 dark:text-white placeholder-gray-400 dark:placeholder-gray-500
                       focus:outline-none focus:ring-2 focus:ring-amber-400/60 focus:border-amber-400
                       dark:focus:ring-amber-500/40 dark:focus:border-amber-500
                       transition-all duration-200"
              />
            </div>

            {{! ── Match Name ── }}
            <div class="mb-4">
              <label class="block text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-1.5">
                Match Name <span class="text-red-400">*</span>
              </label>
              <input
                type="text"
                value={{this.trophyMatchName}}
                placeholder="e.g. Champions League Final 2025"
                {{on "input" (fn this.updateTrophyField "trophyMatchName")}}
                class="w-full px-4 py-2.5 rounded-xl text-sm
                       bg-gray-50 dark:bg-gray-800
                       border border-gray-200 dark:border-gray-700
                       text-gray-900 dark:text-white placeholder-gray-400 dark:placeholder-gray-500
                       focus:outline-none focus:ring-2 focus:ring-amber-400/60 focus:border-amber-400
                       dark:focus:ring-amber-500/40 dark:focus:border-amber-500
                       transition-all duration-200"
              />
            </div>

            {{! ── Tournament Name ── }}
            <div class="mb-4">
              <label class="block text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-1.5">
                Tournament Name <span class="text-red-400">*</span>
              </label>
              <input
                type="text"
                value={{this.trophyTournament}}
                placeholder="e.g. Premier League Season 2025"
                {{on "input" (fn this.updateTrophyField "trophyTournament")}}
                class="w-full px-4 py-2.5 rounded-xl text-sm
                       bg-gray-50 dark:bg-gray-800
                       border border-gray-200 dark:border-gray-700
                       text-gray-900 dark:text-white placeholder-gray-400 dark:placeholder-gray-500
                       focus:outline-none focus:ring-2 focus:ring-amber-400/60 focus:border-amber-400
                       dark:focus:ring-amber-500/40 dark:focus:border-amber-500
                       transition-all duration-200"
              />
            </div>

            {{! ── Winning Position ── }}
            <div class="mb-4">
              <label class="block text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-1.5">
                Winning Position <span class="text-red-400">*</span>
              </label>
              <input
                type="text"
                value={{this.trophyWinningPosition}}
                placeholder="e.g. 1st, Runner-up, 3rd Place"
                {{on "input" (fn this.updateTrophyField "trophyWinningPosition")}}
                class="w-full px-4 py-2.5 rounded-xl text-sm
                       bg-gray-50 dark:bg-gray-800
                       border border-gray-200 dark:border-gray-700
                       text-gray-900 dark:text-white placeholder-gray-400 dark:placeholder-gray-500
                       focus:outline-none focus:ring-2 focus:ring-amber-400/60 focus:border-amber-400
                       dark:focus:ring-amber-500/40 dark:focus:border-amber-500
                       transition-all duration-200"
              />
            </div>

            {{! ── Date of Achievement ── }}
            <div class="mb-6">
              <label class="block text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-1.5">
                Date of Achievement
              </label>
              <div class="relative">
                <input
                  type="date"
                  value={{this.trophyDate}}
                  max={{this.today}}
                  {{on "change" (fn this.updateTrophyField "trophyDate")}}
                  class="w-full px-4 py-2.5 rounded-xl text-sm
                         bg-gray-50 dark:bg-gray-800
                         border border-gray-200 dark:border-gray-700
                         text-gray-900 dark:text-white
                         focus:outline-none focus:ring-2 focus:ring-amber-400/60 focus:border-amber-400
                         dark:focus:ring-amber-500/40 dark:focus:border-amber-500
                         transition-all duration-200 cursor-pointer"
                />
              </div>
            </div>

            {{! ── Error / Success ── }}
            {{#if this.trophyError}}
              <p class="text-sm text-red-500 text-center -mt-2">{{this.trophyError}}</p>
            {{/if}}
            {{#if this.trophySuccess}}
              <p class="text-sm text-green-500 text-center -mt-2">{{this.trophySuccess}}</p>
            {{/if}}

            {{! ── Submit ── }}
            <button
              type="button"
              {{on "click" this.saveTrophy}}
              class="w-full py-3 rounded-2xl text-sm font-bold
                     bg-gradient-to-r from-amber-400 via-yellow-400 to-amber-500
                     text-white shadow-lg shadow-amber-400/30
                     hover:shadow-xl hover:shadow-amber-400/40 hover:scale-[1.02]
                     active:scale-[0.98] transition-all duration-200 cursor-pointer
                     disabled:opacity-60 disabled:pointer-events-none">
              {{#if this.isSavingTrophy}}
                <span class="inline-flex items-center gap-2 justify-center">
                  <svg class="w-4 h-4 animate-spin" viewBox="0 0 24 24" fill="none"
                       stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M21 12a9 9 0 1 1-6.219-8.56"/>
                  </svg>
                  Saving…
                </span>
              {{else}}
                <span class="inline-flex items-center gap-2 justify-center">
                  <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                       stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M6 9H4.5a2.5 2.5 0 0 1 0-5H6"/>
                    <path d="M18 9h1.5a2.5 2.5 0 0 0 0-5H18"/>
                    <path d="M4 22h16"/>
                    <path d="M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22"/>
                    <path d="M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22"/>
                    <path d="M18 2H6v7a6 6 0 0 0 12 0V2z"/>
                  </svg>
                  Add Trophy
                </span>
              {{/if}}
            </button>

          </div>
        </div>
      </div>
    {{/if}}

    {{! ── Add Team Modal ───────────────────────────────────────────────────── }}
    {{#if this.showAddTeamModal}}
      <div
        role="dialog"
        aria-modal="true"
        class="fixed inset-0 z-50 flex items-center justify-center p-4"
      >
        {{! Backdrop }}
        <div
          class="absolute inset-0 bg-black/60 dark:bg-black/80 backdrop-blur-sm"
          {{on "click" this.closeAddTeamModal}}
        ></div>

        {{! Panel }}
        <div class="relative w-full max-w-lg
                    bg-white dark:bg-gray-900
                    rounded-3xl shadow-2xl shadow-black/25 dark:shadow-black/60
                    border border-gray-100 dark:border-gray-700/50
                    overflow-hidden flex flex-col"
             style="max-height: 90dvh;">

          {{! Accent bar }}
          <div class="h-1 w-full shrink-0
                      bg-gradient-to-r from-indigo-500 via-violet-500 to-fuchsia-500"></div>

          {{! ── Header ── }}
          <div class="flex items-center justify-between px-6 pt-5 pb-4 shrink-0
                      border-b border-gray-100 dark:border-gray-800">
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 rounded-2xl shrink-0
                          bg-gradient-to-br from-indigo-500 to-violet-600
                          flex items-center justify-center
                          shadow-lg shadow-indigo-500/30">
                <svg class="w-5 h-5 text-white" viewBox="0 0 24 24" fill="none"
                     stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                  <circle cx="9" cy="7" r="4"/>
                  <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
                  <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
                </svg>
              </div>
              <div>
                <h2 class="text-base font-bold text-gray-900 dark:text-white tracking-tight">
                  Add Team
                </h2>
                <p class="text-xs text-gray-400 dark:text-gray-500 mt-0.5">
                  Link a team to {{this.club.name}}
                </p>
              </div>
            </div>
            <button
              type="button"
              {{on "click" this.closeAddTeamModal}}
              class="w-8 h-8 rounded-xl flex items-center justify-center shrink-0
                     text-gray-400 hover:text-gray-700 dark:hover:text-gray-200
                     hover:bg-gray-100 dark:hover:bg-gray-800
                     transition-all duration-150">
              <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                   stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                <path d="M18 6 6 18"/><path d="m6 6 12 12"/>
              </svg>
            </button>
          </div>

          {{! ── Controls (country + toggle + search) ── }}
          <div class="px-6 pt-4 pb-3 shrink-0 space-y-4">

            {{! Country row }}
            <div class="flex items-center gap-3 px-4 py-2.5 rounded-2xl
                        bg-gray-50 dark:bg-gray-800/70
                        border border-gray-200 dark:border-gray-700/60">
              <span class="text-xl leading-none shrink-0">🇧🇩</span>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-semibold text-gray-900 dark:text-white leading-tight">Bangladesh</p>
                <p class="text-[11px] text-gray-400 dark:text-gray-500">Country code: BD</p>
              </div>
              <span class="shrink-0 px-2 py-0.5 rounded-full text-[11px] font-bold
                           bg-indigo-100 dark:bg-indigo-900/50
                           text-indigo-600 dark:text-indigo-400">BD</span>
            </div>

            {{! Tab toggle }}
            <div class="grid grid-cols-2 gap-1.5 p-1
                        bg-gray-100 dark:bg-gray-800 rounded-2xl">
              <button
                type="button"
                {{on "click" (fn this.selectTeamType "my")}}
                class="flex items-center justify-center gap-1.5 py-2.5 rounded-xl
                       text-xs font-bold transition-all duration-200
                       {{if (eq this.selectedTeamType 'my')
                         'bg-white dark:bg-gray-700 text-indigo-600 dark:text-indigo-400 shadow-md shadow-black/10'
                         'text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200'}}">
                <svg class="w-3.5 h-3.5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                     stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
                  <circle cx="12" cy="7" r="4"/>
                </svg>
                My Teams
                {{#if this.myTeams.length}}
                  <span class="ml-0.5 px-1.5 py-0 rounded-full text-[10px] font-extrabold
                               bg-indigo-100 dark:bg-indigo-900/60
                               text-indigo-600 dark:text-indigo-400">
                    {{this.myTeams.length}}
                  </span>
                {{/if}}
              </button>
              <button
                type="button"
                {{on "click" (fn this.selectTeamType "other")}}
                class="flex items-center justify-center gap-1.5 py-2.5 rounded-xl
                       text-xs font-bold transition-all duration-200
                       {{if (eq this.selectedTeamType 'other')
                         'bg-white dark:bg-gray-700 text-indigo-600 dark:text-indigo-400 shadow-md shadow-black/10'
                         'text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200'}}">
                <svg class="w-3.5 h-3.5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                     stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                  <circle cx="9" cy="7" r="4"/>
                  <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
                  <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
                </svg>
                Other's Teams
                {{#if this.otherTeams.length}}
                  <span class="ml-0.5 px-1.5 py-0 rounded-full text-[10px] font-extrabold
                               bg-indigo-100 dark:bg-indigo-900/60
                               text-indigo-600 dark:text-indigo-400">
                    {{this.otherTeams.length}}
                  </span>
                {{/if}}
              </button>
            </div>

            {{! Search box }}
            <div class="relative">
              <svg class="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4
                           text-gray-400 pointer-events-none"
                   viewBox="0 0 24 24" fill="none" stroke="currentColor"
                   stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/>
              </svg>
              {{#if (eq this.selectedTeamType "my")}}
                <input
                  type="text"
                  placeholder="Search my teams…"
                  value={{this.myTeamSearch}}
                  {{on "input" (fn this.updateAddTeamField "myTeamSearch")}}
                  class="w-full pl-10 pr-4 py-2.5 rounded-2xl text-sm
                         bg-gray-50 dark:bg-gray-800
                         border border-gray-200 dark:border-gray-700
                         text-gray-900 dark:text-gray-100
                         placeholder:text-gray-400 dark:placeholder:text-gray-500
                         focus:outline-none focus:ring-2 focus:ring-indigo-400/40
                         focus:border-indigo-400 dark:focus:border-indigo-500
                         transition-all duration-200"
                />
              {{else}}
                <input
                  type="text"
                  placeholder="Search other teams…"
                  value={{this.otherTeamSearch}}
                  {{on "input" (fn this.updateAddTeamField "otherTeamSearch")}}
                  class="w-full pl-10 pr-4 py-2.5 rounded-2xl text-sm
                         bg-gray-50 dark:bg-gray-800
                         border border-gray-200 dark:border-gray-700
                         text-gray-900 dark:text-gray-100
                         placeholder:text-gray-400 dark:placeholder:text-gray-500
                         focus:outline-none focus:ring-2 focus:ring-indigo-400/40
                         focus:border-indigo-400 dark:focus:border-indigo-500
                         transition-all duration-200"
                />
              {{/if}}
            </div>
          </div>

          {{! ── Team list (scrollable) ── }}
          <div class="flex-1 overflow-y-auto px-6 pb-2"
               style="scrollbar-width: thin;">

            {{! Loading spinner }}
            {{#if this.teamSearchLoading}}
              <div class="flex flex-col items-center justify-center py-12 gap-4">
                {{! Multi-ring spinner }}
                <div class="relative w-14 h-14">
                  <div class="absolute inset-0 rounded-full border-4
                               border-indigo-100 dark:border-indigo-900/40"></div>
                  <div class="absolute inset-0 rounded-full border-4 border-transparent
                               border-t-indigo-500 animate-spin"></div>
                  <div class="absolute inset-2 rounded-full border-4 border-transparent
                               border-t-violet-400 animate-spin"
                       style="animation-direction: reverse; animation-duration: 0.7s;"></div>
                  <div class="absolute inset-4 rounded-full
                               bg-gradient-to-br from-indigo-500 to-violet-600
                               shadow-lg shadow-indigo-500/40"></div>
                </div>
                <div class="text-center">
                  <p class="text-sm font-semibold text-gray-700 dark:text-gray-300">Loading teams…</p>
                  <p class="text-xs text-gray-400 dark:text-gray-500 mt-0.5">Fetching nearby teams</p>
                </div>
              </div>

            {{! Error }}
            {{else if this.teamSearchError}}
              <div class="flex flex-col items-center justify-center py-10 text-center gap-3">
                <div class="w-12 h-12 rounded-2xl bg-rose-100 dark:bg-rose-900/30
                            flex items-center justify-center">
                  <svg class="w-6 h-6 text-rose-500" viewBox="0 0 24 24" fill="none"
                       stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <circle cx="12" cy="12" r="10"/>
                    <line x1="12" y1="8" x2="12" y2="12"/>
                    <line x1="12" y1="16" x2="12.01" y2="16"/>
                  </svg>
                </div>
                <p class="text-sm text-gray-600 dark:text-gray-400">{{this.teamSearchError}}</p>
              </div>

            {{! Team rows }}
            {{else}}
              {{#let (if (eq this.selectedTeamType "my") this.myTeams this.otherTeams) as |list|}}
                {{#if list.length}}
                  <div class="space-y-2 py-2">
                    {{#each list as |team|}}
                      <button
                        type="button"
                        {{on "click" (fn this.toggleSelectTeam team)}}
                        class="w-full flex items-center gap-3 px-3.5 py-3 rounded-2xl
                               border transition-all duration-200 text-left
                               {{if (eq this.selectedTeam.team_id team.team_id)
                                 'border-indigo-400 dark:border-indigo-500 bg-indigo-50 dark:bg-indigo-900/20 shadow-sm shadow-indigo-500/15'
                                 'border-gray-100 dark:border-gray-800 bg-white dark:bg-gray-800/50 hover:border-indigo-200 dark:hover:border-indigo-700 hover:bg-indigo-50/50 dark:hover:bg-indigo-900/10'}}">

                        {{! Logo }}
                        <div class="w-10 h-10 rounded-xl shrink-0 overflow-hidden
                                    bg-gradient-to-br from-indigo-100 to-violet-100
                                    dark:from-indigo-900/40 dark:to-violet-900/40
                                    flex items-center justify-center
                                    ring-2 ring-white dark:ring-gray-800">
                          {{#if (this.teamLogoSrc team.team_logo)}}
                            <img src={{this.teamLogoSrc team.team_logo}}
                                 alt={{team.team_name}}
                                 class="w-full h-full object-cover" />
                          {{else}}
                            <svg class="w-5 h-5 text-indigo-400" viewBox="0 0 24 24" fill="none"
                                 stroke="currentColor" stroke-width="1.5"
                                 stroke-linecap="round" stroke-linejoin="round">
                              <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                              <circle cx="9" cy="7" r="4"/>
                              <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
                              <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
                            </svg>
                          {{/if}}
                        </div>

                        {{! Info }}
                        <div class="flex-1 min-w-0">
                          <p class="text-sm font-semibold text-gray-900 dark:text-white truncate
                                     {{if (eq this.selectedTeam.team_id team.team_id) 'text-indigo-700 dark:text-indigo-300' ''}}">
                            {{team.team_name}}
                          </p>
                          {{#if team.country_of_gameplaying}}
                            <p class="text-[11px] text-gray-400 dark:text-gray-500 truncate mt-0.5">
                              {{team.country_of_gameplaying}}
                            </p>
                          {{/if}}
                        </div>

                        {{! Selection indicator }}
                        <div class="shrink-0 w-5 h-5 rounded-full border-2 transition-all duration-200 flex items-center justify-center
                                    {{if (eq this.selectedTeam.team_id team.team_id)
                                      'border-indigo-500 bg-indigo-500'
                                      'border-gray-300 dark:border-gray-600'}}">
                          {{#if (eq this.selectedTeam.team_id team.team_id)}}
                            <svg class="w-3 h-3 text-white" viewBox="0 0 24 24" fill="none"
                                 stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
                              <path d="M20 6 9 17l-5-5"/>
                            </svg>
                          {{/if}}
                        </div>
                      </button>
                    {{/each}}
                  </div>
                {{else}}
                  <div class="flex flex-col items-center justify-center py-10 text-center">
                    <div class="w-12 h-12 rounded-2xl bg-gray-100 dark:bg-gray-800
                                flex items-center justify-center mb-3">
                      <svg class="w-6 h-6 text-gray-400" viewBox="0 0 24 24" fill="none"
                           stroke="currentColor" stroke-width="1.5"
                           stroke-linecap="round" stroke-linejoin="round">
                        <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                        <circle cx="9" cy="7" r="4"/>
                        <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
                        <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
                      </svg>
                    </div>
                    <p class="text-sm font-semibold text-gray-600 dark:text-gray-400">No teams found</p>
                    <p class="text-xs text-gray-400 dark:text-gray-500 mt-0.5">Try adjusting your search</p>
                  </div>
                {{/if}}
              {{/let}}
            {{/if}}
          </div>

          {{! ── Footer ── }}
          <div class="px-6 py-4 shrink-0
                      border-t border-gray-100 dark:border-gray-800
                      bg-gray-50/80 dark:bg-gray-900/80 backdrop-blur-sm
                      space-y-3">

            {{! Success banner }}
            {{#if this.addTeamSuccess}}
              <div class="flex items-start gap-3 px-4 py-3.5 rounded-2xl
                          bg-gradient-to-r from-emerald-50 to-teal-50
                          dark:from-emerald-900/25 dark:to-teal-900/20
                          border border-emerald-200 dark:border-emerald-700/50">
                <div class="w-8 h-8 rounded-xl shrink-0
                            bg-gradient-to-br from-emerald-400 to-teal-500
                            flex items-center justify-center shadow-md shadow-emerald-500/30">
                  <svg class="w-4 h-4 text-white" viewBox="0 0 24 24" fill="none"
                       stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M20 6 9 17l-5-5"/>
                  </svg>
                </div>
                <div class="flex-1 min-w-0">
                  <p class="text-sm font-bold text-emerald-800 dark:text-emerald-300 leading-tight">
                    Request Sent!
                  </p>
                  <p class="text-xs text-emerald-700 dark:text-emerald-400 mt-0.5 leading-relaxed">
                    The team has been notified and must approve this request before joining the club.
                    Status is currently <span class="font-bold">Pending</span>.
                  </p>
                </div>
              </div>
            {{/if}}

            {{! Error banner }}
            {{#if this.addTeamError}}
              <div class="flex items-start gap-3 px-4 py-3 rounded-2xl
                          bg-rose-50 dark:bg-rose-900/20
                          border border-rose-200 dark:border-rose-700/50">
                <svg class="w-4 h-4 text-rose-500 shrink-0 mt-0.5" viewBox="0 0 24 24" fill="none"
                     stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <circle cx="12" cy="12" r="10"/>
                  <line x1="12" y1="8" x2="12" y2="12"/>
                  <line x1="12" y1="16" x2="12.01" y2="16"/>
                </svg>
                <p class="text-xs text-rose-700 dark:text-rose-400 leading-relaxed">{{this.addTeamError}}</p>
              </div>
            {{/if}}

            {{! Buttons }}
            <div class="flex items-center gap-3">
              <button
                type="button"
                {{on "click" this.closeAddTeamModal}}
                class="flex-1 py-2.5 rounded-2xl text-sm font-semibold
                       text-gray-600 dark:text-gray-400
                       bg-white dark:bg-gray-800
                       border border-gray-200 dark:border-gray-700
                       hover:bg-gray-100 dark:hover:bg-gray-700
                       transition-all duration-200">
                {{if this.addTeamSuccess "Done" "Cancel"}}
              </button>
              {{#unless this.addTeamSuccess}}
                <button
                  type="button"
                  {{on "click" this.addTeam}}
                  disabled={{if this.selectedTeam false true}}
                  class="flex-1 py-2.5 rounded-2xl text-sm font-bold text-white
                         bg-gradient-to-r from-indigo-600 to-violet-600
                         hover:from-indigo-500 hover:to-violet-500
                         shadow-md shadow-indigo-500/25
                         hover:shadow-lg hover:shadow-indigo-500/35
                         hover:scale-[1.02] active:scale-[0.98]
                         disabled:opacity-40 disabled:pointer-events-none
                         transition-all duration-200">
                  {{#if this.isAddingTeam}}
                    <span class="inline-flex items-center justify-center gap-2">
                      <svg class="w-4 h-4 animate-spin" viewBox="0 0 24 24" fill="none"
                           stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M21 12a9 9 0 1 1-6.219-8.56"/>
                      </svg>
                      Sending Request…
                    </span>
                  {{else}}
                    <span class="inline-flex items-center justify-center gap-2">
                      <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none"
                           stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M12 5v14"/><path d="M5 12h14"/>
                      </svg>
                      Add Team
                    </span>
                  {{/if}}
                </button>
              {{/unless}}
            </div>

          </div>

        </div>
      </div>
    {{/if}}

    <section class="min-h-screen bg-gray-50 dark:bg-gray-950">

      {{! ── Loading skeleton ── }}
      {{#if this.isLoading}}
        <div class="animate-pulse">
          <div class="h-56 sm:h-72 bg-gradient-to-br from-gray-200 to-gray-300 dark:from-gray-700 dark:to-gray-800"></div>
          <div class="flex justify-center -mt-14 mb-6">
            <div class="w-28 h-28 rounded-3xl bg-gray-300 dark:bg-gray-600 border-4 border-white dark:border-gray-950 shadow-xl"></div>
          </div>
          <div class="flex flex-col items-center gap-3 px-4 mb-10">
            <div class="h-7 bg-gray-300 dark:bg-gray-600 rounded-full w-56"></div>
            <div class="h-4 bg-gray-200 dark:bg-gray-700 rounded-full w-32"></div>
            <div class="flex gap-2">
              <div class="h-6 bg-gray-200 dark:bg-gray-700 rounded-full w-20"></div>
              <div class="h-6 bg-gray-200 dark:bg-gray-700 rounded-full w-24"></div>
            </div>
          </div>
          <div class="border-b border-gray-200 dark:border-gray-700 px-4 mb-8">
            <div class="flex gap-2 pb-0 w-full">
              {{#each this.skeletonRows as |_|}}
                <div class="h-9 bg-gray-200 dark:bg-gray-700 rounded-t w-20 shrink-0"></div>
                <div class="h-9 bg-gray-200 dark:bg-gray-700 rounded-t w-16 shrink-0"></div>
                <div class="h-9 bg-gray-200 dark:bg-gray-700 rounded-t w-24 shrink-0"></div>
                <div class="h-9 bg-gray-200 dark:bg-gray-700 rounded-t w-14 shrink-0"></div>
              {{/each}}
            </div>
          </div>
          <div class="w-full px-4 grid grid-cols-1 lg:grid-cols-3 gap-6">
            <div class="lg:col-span-2 space-y-4">
              <div class="rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-700/50 h-40"></div>
              <div class="rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-700/50 h-56"></div>
            </div>
            <div class="rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-700/50 h-64"></div>
          </div>
        </div>

      {{! ── Error state ── }}
      {{else if this.error}}
        <div class="flex flex-col items-center justify-center min-h-[60vh] px-4 text-center">
          <div class="w-20 h-20 mb-6 rounded-3xl bg-rose-100 dark:bg-rose-900/30 flex items-center justify-center">
            <svg class="w-10 h-10 text-rose-500" viewBox="0 0 24 24" fill="none"
                 stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <circle cx="12" cy="12" r="10"/><path d="M12 8v4"/><path d="M12 16h.01"/>
            </svg>
          </div>
          <h2 class="text-xl font-bold text-gray-900 dark:text-white mb-2">Something went wrong</h2>
          <p class="text-gray-500 dark:text-gray-400 mb-6">{{this.error}}</p>
          <button
            type="button"
            {{on "click" this.retry}}
            class="px-6 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 active:bg-indigo-700
                   text-white font-semibold text-sm shadow-sm transition-colors"
          >
            Try Again
          </button>
        </div>

      {{! ── Club Detail ── }}
      {{else if this.club}}

        {{! ─── HERO BANNER ─── }}
        <div class="relative">
          <div class="relative h-52 sm:h-72 overflow-hidden
                      bg-gradient-to-br from-indigo-600 via-violet-600 to-fuchsia-600
                      dark:from-indigo-800 dark:via-violet-800 dark:to-fuchsia-800">
            {{! Dot-grid texture }}
            <div
              class="absolute inset-0 opacity-[0.15]"
              style="background-image: radial-gradient(circle, white 1px, transparent 1px); background-size: 20px 20px;"
            ></div>
            {{! Soft top-right glow }}
            <div class="absolute -top-20 -right-20 w-80 h-80 rounded-full bg-white/10 blur-3xl pointer-events-none"></div>
            {{#if this.club.cover_photo}}
              <img src={{this.club.cover_photo}} alt="Cover photo"
                   class="absolute inset-0 w-full h-full object-cover" />
              <div class="absolute inset-0 bg-gradient-to-t from-black/70 via-black/10 to-transparent"></div>
            {{/if}}
          </div>

          {{! Floating logo }}
          <div class="absolute left-1/2 -translate-x-1/2 bottom-0 translate-y-1/2 z-10">
            <div class="w-28 h-28 sm:w-32 sm:h-32 rounded-3xl
                        border-4 border-white dark:border-gray-950
                        shadow-2xl overflow-hidden
                        bg-white dark:bg-gray-800
                        ring-4 ring-indigo-300/40 dark:ring-indigo-500/30
                        transition-transform duration-300 hover:scale-105">
              <img src={{this.club.logo}} alt={{this.club.name}}
                   class="w-full h-full object-cover" />
            </div>
          </div>
        </div>

        {{! ─── CLUB IDENTITY ─── }}
        <div class="pt-20 sm:pt-24 pb-5 sm:pb-6 text-center px-4 w-full">

          <h1 class="text-xl sm:text-3xl font-black text-gray-900 dark:text-white mb-1.5 sm:mb-2 leading-tight tracking-tight">
            {{this.club.name}}
          </h1>

          {{! Location row }}
          <div class="flex items-center justify-center gap-1.5 text-gray-500 dark:text-gray-400 text-sm mb-4">
            <svg class="w-4 h-4 text-violet-500 shrink-0" viewBox="0 0 24 24" fill="none"
                 stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
              <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7z"/>
              <circle cx="12" cy="9" r="2.5"/>
            </svg>
            <span>{{this.club.city}}, {{this.club.country}}</span>
          </div>

          {{! Badges row }}
          <div class="flex flex-wrap items-center justify-center gap-2 mb-5">
            {{#if this.clubTypeBadge}}
              <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider
                           bg-indigo-100 dark:bg-indigo-900/40 text-indigo-700 dark:text-indigo-300
                           border border-indigo-200 dark:border-indigo-700/50">
                <svg class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                     stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>
                </svg>
                {{this.clubTypeBadge}}
              </span>
            {{/if}}

            {{#if this.hasSports}}
              {{#each this.club.sports as |sport|}}
                <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold
                             bg-violet-100 dark:bg-violet-900/30 text-violet-700 dark:text-violet-300
                             border border-violet-200 dark:border-violet-700/40">
                  <svg class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                       stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                    <circle cx="12" cy="12" r="10"/>
                    <path d="M2 12h20"/><path d="M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"/>
                  </svg>
                  {{sport}}
                </span>
              {{/each}}
            {{/if}}

            {{#if this.established}}
              <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold
                           bg-amber-100 dark:bg-amber-900/30 text-amber-700 dark:text-amber-300
                           border border-amber-200 dark:border-amber-700/40">
                <svg class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                     stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                  <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
                  <line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/>
                  <line x1="3" y1="10" x2="21" y2="10"/>
                </svg>
                Est. {{this.established}}
              </span>
            {{/if}}
          </div>

          {{! Quick contact links }}
          <div class="flex flex-wrap items-center justify-center gap-x-5 gap-y-3">
            {{#if this.club.phone}}
              <a href="tel:{{this.club.phone}}"
                 class="inline-flex items-center gap-1.5 text-xs text-gray-500 dark:text-gray-400
                        hover:text-emerald-600 dark:hover:text-emerald-400 transition-colors">
                <svg class="w-3.5 h-3.5 text-emerald-500" viewBox="0 0 24 24" fill="none"
                     stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07A19.5 19.5 0 0 1 4.69 12a19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 3.6 1.27h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"/>
                </svg>
                {{this.club.phone}}
              </a>
            {{/if}}

            {{#if this.club.mail}}
              <a href="mailto:{{this.club.mail}}"
                 class="inline-flex items-center gap-1.5 text-xs text-gray-500 dark:text-gray-400
                        hover:text-indigo-600 dark:hover:text-indigo-400 transition-colors">
                <svg class="w-3.5 h-3.5 text-indigo-500" viewBox="0 0 24 24" fill="none"
                     stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/>
                  <polyline points="22,6 12,13 2,6"/>
                </svg>
                {{this.club.mail}}
              </a>
            {{/if}}

            {{#if this.club.website}}
              <a href={{this.club.website}} target="_blank" rel="noopener noreferrer"
                 class="inline-flex items-center gap-1.5 text-xs text-gray-500 dark:text-gray-400
                        hover:text-cyan-600 dark:hover:text-cyan-400 transition-colors">
                <svg class="w-3.5 h-3.5 text-cyan-500" viewBox="0 0 24 24" fill="none"
                     stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                  <circle cx="12" cy="12" r="10"/>
                  <line x1="2" y1="12" x2="22" y2="12"/>
                  <path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/>
                </svg>
                Website
              </a>
            {{/if}}

            {{#if this.mapUrl}}
              <a href={{this.mapUrl}} target="_blank" rel="noopener noreferrer"
                 class="inline-flex items-center gap-1.5 text-xs text-gray-500 dark:text-gray-400
                        hover:text-rose-600 dark:hover:text-rose-400 transition-colors">
                <svg class="w-3.5 h-3.5 text-rose-500" viewBox="0 0 24 24" fill="none"
                     stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                  <polygon points="3 11 22 2 13 21 11 13 3 11"/>
                </svg>
                View on Map
              </a>
            {{/if}}
          </div>
        </div>

        {{! ─── GOOGLE ADS — Leaderboard 728×90 ─── }}
        <div class="w-full px-3 sm:px-4 mb-4 sm:mb-6">
          <div class="rounded-2xl border-2 border-dashed border-gray-200 dark:border-gray-700/60
                      bg-gradient-to-br from-gray-100/60 to-white/40
                      dark:from-gray-800/40 dark:to-gray-900/30
                      flex flex-col items-center justify-center min-h-[60px] sm:min-h-[90px] overflow-hidden relative">
            <p class="text-[9px] font-bold tracking-[0.25em] uppercase text-gray-300 dark:text-gray-600 mb-1">Advertisement</p>
            {{! ↓ Replace with your AdSense <ins> tag }}
            <div id="club-details-leaderboard-ad"
                 class="flex items-center gap-2 text-gray-300 dark:text-gray-700">
              <svg class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                <rect x="2" y="3" width="20" height="14" rx="2"/>
                <line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/>
              </svg>
              <span class="text-xs font-medium">728 × 90 — Google Ad Slot</span>
            </div>
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
              <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                   stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                <path d="M15 18l-6-6 6-6"/>
              </svg>
            </button>

            {{! Scrollable tab strip }}
            <div
              id="club-tab-bar"
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
              <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                   stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                <path d="M9 18l6-6-6-6"/>
              </svg>
            </button>

          </div>
        </div>

        {{! ─── TAB CONTENT ─── }}
        <div class="w-full px-3 sm:px-4 py-5 sm:py-8 animate-fade-in">

          {{! ── ABOUT US ── }}
          {{#if (eq this.activeTab "about")}}
            <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">

              {{! Left: description + details }}
              <div class="lg:col-span-2 space-y-6">

                {{! Description card }}
                <div class="rounded-2xl bg-white dark:bg-gray-900
                            border border-gray-100 dark:border-gray-700/50 shadow-sm overflow-hidden">

                  {{! Card header }}
                  <div class="flex items-center gap-2.5 px-6 pt-5 pb-4">
                    <div class="w-8 h-8 rounded-xl bg-gradient-to-br from-indigo-500 to-violet-600
                                flex items-center justify-center shrink-0 shadow-sm shadow-indigo-500/25">
                      <svg class="w-4 h-4 text-white" viewBox="0 0 24 24" fill="none"
                           stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
                        <polyline points="14 2 14 8 20 8"/>
                        <line x1="16" y1="13" x2="8" y2="13"/>
                        <line x1="16" y1="17" x2="8" y2="17"/>
                      </svg>
                    </div>
                    <h3 class="text-sm font-bold text-gray-900 dark:text-white">About the Club</h3>
                  </div>

                  {{#if this.clubDescription}}
                    <div class="h-px bg-gradient-to-r from-indigo-500/30 via-violet-400/20 to-transparent mx-6 mb-4"></div>
                    <div class="px-6 pb-6">
                      <p class="text-sm text-gray-600 dark:text-gray-400 leading-relaxed whitespace-pre-line">
                        {{this.clubDescription}}
                      </p>
                    </div>
                  {{else}}
                    <div class="flex flex-col items-center justify-center py-10 px-6 text-center">
                      <div class="w-12 h-12 rounded-2xl bg-gray-100 dark:bg-gray-800
                                  flex items-center justify-center mb-3">
                        <svg class="w-6 h-6 text-gray-300 dark:text-gray-600" viewBox="0 0 24 24" fill="none"
                             stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                          <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
                          <polyline points="14 2 14 8 20 8"/>
                          <line x1="16" y1="13" x2="8" y2="13"/>
                          <line x1="16" y1="17" x2="8" y2="17"/>
                        </svg>
                      </div>
                      <p class="text-sm font-semibold text-gray-400 dark:text-gray-500">No Description</p>
                      <p class="text-xs text-gray-300 dark:text-gray-600 mt-1">
                        This club hasn't added a description yet.
                      </p>
                    </div>
                  {{/if}}
                </div>

                {{! Club details grid }}
                <div class="rounded-2xl bg-white dark:bg-gray-900
                            border border-gray-100 dark:border-gray-700/50 shadow-sm p-6">
                  <h3 class="flex items-center gap-2 text-base font-bold text-gray-900 dark:text-white mb-5">
                    <span class="w-8 h-8 rounded-xl bg-violet-100 dark:bg-violet-900/40
                                 flex items-center justify-center shrink-0">
                      <svg class="w-4 h-4 text-violet-600 dark:text-violet-400" viewBox="0 0 24 24"
                           fill="none" stroke="currentColor" stroke-width="2"
                           stroke-linecap="round" stroke-linejoin="round">
                        <circle cx="12" cy="12" r="10"/>
                        <line x1="12" y1="8" x2="12" y2="12"/>
                        <line x1="12" y1="16" x2="12.01" y2="16"/>
                      </svg>
                    </span>
                    Club Information
                  </h3>

                  <dl class="grid grid-cols-1 sm:grid-cols-2 gap-3">

                    {{! Address }}
                    <div class="flex items-start gap-3 p-3 rounded-xl bg-gray-50 dark:bg-gray-800/60">
                      <div class="w-8 h-8 rounded-lg bg-rose-100 dark:bg-rose-900/30
                                  flex items-center justify-center shrink-0">
                        <svg class="w-4 h-4 text-rose-500" viewBox="0 0 24 24" fill="none"
                             stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                          <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7z"/>
                          <circle cx="12" cy="9" r="2.5"/>
                        </svg>
                      </div>
                      <div class="min-w-0">
                        <dt class="text-[10px] font-bold uppercase tracking-wider
                                   text-gray-400 dark:text-gray-500 mb-0.5">Address</dt>
                        <dd class="text-sm font-medium text-gray-700 dark:text-gray-300 truncate">
                          {{#if this.club.address}}{{this.club.address}}, {{/if}}{{this.club.city}}{{#if this.club.district}}, {{this.club.district}}{{/if}}
                        </dd>
                      </div>
                    </div>

                    {{! Established }}
                    {{#if this.established}}
                      <div class="flex items-start gap-3 p-3 rounded-xl bg-gray-50 dark:bg-gray-800/60">
                        <div class="w-8 h-8 rounded-lg bg-amber-100 dark:bg-amber-900/30
                                    flex items-center justify-center shrink-0">
                          <svg class="w-4 h-4 text-amber-500" viewBox="0 0 24 24" fill="none"
                               stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
                            <line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/>
                            <line x1="3" y1="10" x2="21" y2="10"/>
                          </svg>
                        </div>
                        <div>
                          <dt class="text-[10px] font-bold uppercase tracking-wider
                                     text-gray-400 dark:text-gray-500 mb-0.5">Established</dt>
                          <dd class="text-sm font-medium text-gray-700 dark:text-gray-300">
                            {{this.established}}
                          </dd>
                        </div>
                      </div>
                    {{/if}}

                    {{! Division }}
                    {{#if this.club.division}}
                      <div class="flex items-start gap-3 p-3 rounded-xl bg-gray-50 dark:bg-gray-800/60">
                        <div class="w-8 h-8 rounded-lg bg-blue-100 dark:bg-blue-900/30
                                    flex items-center justify-center shrink-0">
                          <svg class="w-4 h-4 text-blue-500" viewBox="0 0 24 24" fill="none"
                               stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
                            <polyline points="9 22 9 12 15 12 15 22"/>
                          </svg>
                        </div>
                        <div>
                          <dt class="text-[10px] font-bold uppercase tracking-wider
                                     text-gray-400 dark:text-gray-500 mb-0.5">Division</dt>
                          <dd class="text-sm font-medium text-gray-700 dark:text-gray-300">
                            {{this.club.division}}
                          </dd>
                        </div>
                      </div>
                    {{/if}}

                    {{! Postcode }}
                    {{#if this.club.postcode}}
                      <div class="flex items-start gap-3 p-3 rounded-xl bg-gray-50 dark:bg-gray-800/60">
                        <div class="w-8 h-8 rounded-lg bg-teal-100 dark:bg-teal-900/30
                                    flex items-center justify-center shrink-0">
                          <svg class="w-4 h-4 text-teal-500" viewBox="0 0 24 24" fill="none"
                               stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/>
                            <polyline points="22,6 12,13 2,6"/>
                          </svg>
                        </div>
                        <div>
                          <dt class="text-[10px] font-bold uppercase tracking-wider
                                     text-gray-400 dark:text-gray-500 mb-0.5">Postcode</dt>
                          <dd class="text-sm font-medium text-gray-700 dark:text-gray-300">
                            {{this.club.postcode}}
                          </dd>
                        </div>
                      </div>
                    {{/if}}

                    {{! Sports Scope }}
                    {{#if this.club.sports_scope}}
                      <div class="flex items-start gap-3 p-3 rounded-xl bg-gray-50 dark:bg-gray-800/60">
                        <div class="w-8 h-8 rounded-lg bg-fuchsia-100 dark:bg-fuchsia-900/30
                                    flex items-center justify-center shrink-0">
                          <svg class="w-4 h-4 text-fuchsia-500" viewBox="0 0 24 24" fill="none"
                               stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <circle cx="12" cy="12" r="10"/>
                            <path d="M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"/>
                            <path d="M2 12h20"/>
                          </svg>
                        </div>
                        <div>
                          <dt class="text-[10px] font-bold uppercase tracking-wider
                                     text-gray-400 dark:text-gray-500 mb-0.5">Sports Scope</dt>
                          <dd class="text-sm font-medium text-gray-700 dark:text-gray-300 capitalize">
                            {{this.club.sports_scope}}
                          </dd>
                        </div>
                      </div>
                    {{/if}}

                    {{! Map link }}
                    {{#if this.mapUrl}}
                      <div class="flex items-start gap-3 p-3 rounded-xl bg-gray-50 dark:bg-gray-800/60">
                        <div class="w-8 h-8 rounded-lg bg-green-100 dark:bg-green-900/30
                                    flex items-center justify-center shrink-0">
                          <svg class="w-4 h-4 text-green-500" viewBox="0 0 24 24" fill="none"
                               stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <polygon points="3 11 22 2 13 21 11 13 3 11"/>
                          </svg>
                        </div>
                        <div>
                          <dt class="text-[10px] font-bold uppercase tracking-wider
                                     text-gray-400 dark:text-gray-500 mb-0.5">Location</dt>
                          <dd>
                            <a href={{this.mapUrl}} target="_blank" rel="noopener noreferrer"
                               class="text-sm font-semibold text-indigo-600 dark:text-indigo-400 hover:underline">
                              View on Google Maps →
                            </a>
                          </dd>
                        </div>
                      </div>
                    {{/if}}

                  </dl>
                </div>
              </div>

              {{! Right sidebar }}
              <div class="space-y-6">

                {{! Management card }}
                <div class="rounded-2xl bg-white dark:bg-gray-900
                            border border-gray-100 dark:border-gray-700/50 shadow-sm overflow-hidden">

                  {{! Card header }}
                  <div class="flex items-center justify-between px-5 pt-5 pb-4">
                    <div class="flex items-center gap-2.5">
                      <div class="w-8 h-8 rounded-xl bg-gradient-to-br from-emerald-400 to-teal-500
                                  flex items-center justify-center shrink-0 shadow-sm shadow-emerald-400/30">
                        <svg class="w-4 h-4 text-white" viewBox="0 0 24 24" fill="none"
                             stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                          <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                          <circle cx="9" cy="7" r="4"/>
                          <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
                          <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
                        </svg>
                      </div>
                      <h3 class="text-sm font-bold text-gray-900 dark:text-white">Management</h3>
                    </div>
                    {{#if this.hasManagers}}
                      <span class="px-2 py-0.5 rounded-full text-[10px] font-bold
                                   bg-emerald-100 dark:bg-emerald-900/30
                                   text-emerald-700 dark:text-emerald-400
                                   ring-1 ring-emerald-200 dark:ring-emerald-700/40">
                        {{this.managersForDisplay.length}}
                        {{#if (eq this.managersForDisplay.length 1)}}member{{else}}members{{/if}}
                      </span>
                    {{/if}}
                  </div>

                  {{#if this.hasManagers}}
                    <ul class="divide-y divide-gray-50 dark:divide-gray-800/60 px-3 pb-3">
                      {{#each this.managersForDisplay as |m|}}
                        <li class="flex items-center gap-3 px-2 py-3 rounded-xl
                                   hover:bg-gray-50 dark:hover:bg-gray-800/50
                                   transition-colors duration-150 group">

                          {{! Avatar with initials }}
                          <div class="w-10 h-10 rounded-xl shrink-0
                                      bg-gradient-to-br {{m.gradColor}}
                                      flex items-center justify-center
                                      shadow-md text-white text-sm font-bold
                                      group-hover:scale-105 transition-transform duration-200">
                            {{m.initials}}
                          </div>

                          {{! Info }}
                          <div class="flex-1 min-w-0">
                            <p class="text-sm font-semibold text-gray-900 dark:text-white truncate leading-tight">
                              {{m.fullName}}
                            </p>
                            <p class="text-[10px] font-medium text-emerald-600 dark:text-emerald-400 mt-0.5">
                              Club Manager
                            </p>
                          </div>

                          {{! Subtle ID badge }}
                          <span class="hidden sm:inline-flex items-center px-2 py-0.5 rounded-lg text-[9px]
                                       font-mono font-medium bg-gray-100 dark:bg-gray-800
                                       text-gray-400 dark:text-gray-500 truncate max-w-[80px]"
                                title={{m.id}}>
                            {{m.id}}
                          </span>
                        </li>
                      {{/each}}
                    </ul>
                  {{else}}
                    <div class="flex flex-col items-center justify-center py-8 px-4 text-center">
                      <div class="w-10 h-10 rounded-xl bg-gray-100 dark:bg-gray-800
                                  flex items-center justify-center mb-2">
                        <svg class="w-5 h-5 text-gray-300 dark:text-gray-600" viewBox="0 0 24 24" fill="none"
                             stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                          <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                          <circle cx="9" cy="7" r="4"/>
                        </svg>
                      </div>
                      <p class="text-xs font-medium text-gray-400 dark:text-gray-500">No managers listed</p>
                    </div>
                  {{/if}}
                </div>

                {{! Sidebar ad slot 300×250 }}
                <div class="hidden sm:flex rounded-2xl border-2 border-dashed border-gray-200 dark:border-gray-700/60
                            bg-gray-100/50 dark:bg-gray-800/30
                            flex-col items-center justify-center min-h-[250px]">
                  <p class="text-[9px] font-bold tracking-[0.25em] uppercase
                             text-gray-300 dark:text-gray-600 mb-1">Advertisement</p>
                  {{! ↓ Replace with your AdSense <ins> tag }}
                  <div id="club-details-sidebar-ad"
                       class="text-gray-300 dark:text-gray-700 text-xs font-medium">
                    300 × 250 — Ad Slot
                  </div>
                </div>

              </div>
            </div>

          {{! ── TROPHIES ── }}
          {{else if (eq this.activeTab "trophies")}}
            <div class="space-y-6">

              {{! Header bar }}
              <div class="flex flex-wrap items-center justify-between gap-3
                          rounded-2xl bg-white dark:bg-gray-900
                          border border-gray-100 dark:border-gray-700/50
                          shadow-sm px-4 sm:px-5 py-4">
                <div class="flex items-center gap-3">
                  {{! Glowing trophy icon }}
                  <div class="relative w-10 h-10 rounded-xl shrink-0
                              bg-gradient-to-br from-amber-400 to-yellow-500
                              flex items-center justify-center shadow-lg shadow-amber-400/30">
                    <svg class="w-5 h-5 text-white" viewBox="0 0 24 24" fill="none"
                         stroke="currentColor" stroke-width="2"
                         stroke-linecap="round" stroke-linejoin="round">
                      <path d="M6 9H4.5a2.5 2.5 0 0 1 0-5H6"/>
                      <path d="M18 9h1.5a2.5 2.5 0 0 0 0-5H18"/>
                      <path d="M4 22h16"/><path d="M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22"/>
                      <path d="M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22"/>
                      <path d="M18 2H6v7a6 6 0 0 0 12 0V2z"/>
                    </svg>
                  </div>
                  <div>
                    <h3 class="text-base font-bold text-gray-900 dark:text-white leading-tight">
                      Trophies & Honours
                    </h3>
                    <p class="text-xs text-gray-400 dark:text-gray-500 mt-0.5">
                      {{#if this.hasTrophies}}
                        {{this.trophyCount}} honour{{#if (eq this.trophyCount 1)}}{{else}}s{{/if}} earned
                      {{else}}
                        No honours yet
                      {{/if}}
                    </p>
                  </div>
                </div>

                {{#if this.isCurrentUserClub}}
                  <button
                    type="button"
                    {{on "click" this.openTrophyModal}}
                    class="inline-flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-semibold
                           bg-gradient-to-r from-amber-400 to-yellow-500
                           text-white shadow-md shadow-amber-400/30
                           hover:shadow-lg hover:shadow-amber-400/40 hover:scale-105
                           active:scale-95 transition-all duration-200 cursor-pointer">
                    <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                         stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                      <path d="M12 5v14"/><path d="M5 12h14"/>
                    </svg>
                    Add Trophy
                  </button>
                {{/if}}
              </div>

              {{! ── Populated state ── }}
              {{#if this.hasTrophies}}
                {{#each this.trophiesByYear as |group|}}
                  <div class="flex gap-3 sm:gap-6">

                    {{! Year spine }}
                    <div class="flex flex-col items-center gap-1 shrink-0 pt-1">
                      <div class="w-10 h-10 sm:w-12 sm:h-12 rounded-xl sm:rounded-2xl
                                  bg-gradient-to-br from-amber-400 to-yellow-500
                                  flex items-center justify-center shadow-md shadow-amber-400/25 shrink-0">
                        <span class="text-[10px] sm:text-xs font-extrabold text-white leading-none tracking-tight">
                          {{group.year}}
                        </span>
                      </div>
                      <div class="w-0.5 flex-1 bg-gradient-to-b from-amber-400/40 to-transparent rounded-full"></div>
                    </div>

                    {{! Trophy cards for this year }}
                    <div class="flex-1 pb-4">
                      <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
                        {{#each group.items as |trophy|}}
                          <div class="group relative rounded-2xl overflow-hidden
                                      bg-white dark:bg-gray-900
                                      border border-amber-100 dark:border-amber-800/30
                                      shadow-sm hover:shadow-xl hover:shadow-amber-400/10
                                      hover:-translate-y-1 transition-all duration-300 cursor-default">

                            {{! Subtle ambient gradient }}
                            <div class="absolute inset-0 bg-gradient-to-br from-amber-50/60 via-transparent to-yellow-50/40
                                        dark:from-amber-900/10 dark:via-transparent dark:to-yellow-900/5
                                        pointer-events-none"></div>

                            <div class="relative p-4 flex flex-col items-center text-center gap-3">
                              {{! Trophy visual }}
                              {{#if trophy.image}}
                                <div class="w-14 h-14 rounded-xl overflow-hidden shrink-0
                                            ring-2 ring-amber-200 dark:ring-amber-700/40">
                                  <img src={{trophy.image}} alt={{trophy.name}}
                                       class="w-full h-full object-cover" />
                                </div>
                              {{else}}
                                <div class="w-14 h-14 rounded-xl shrink-0
                                            bg-gradient-to-br from-amber-100 to-yellow-100
                                            dark:from-amber-900/40 dark:to-yellow-900/30
                                            flex items-center justify-center
                                            ring-2 ring-amber-200/60 dark:ring-amber-700/30
                                            group-hover:ring-amber-400/60 transition-all duration-300">
                                  <svg class="w-7 h-7 text-amber-500 dark:text-amber-400" viewBox="0 0 24 24"
                                       fill="none" stroke="currentColor" stroke-width="1.5"
                                       stroke-linecap="round" stroke-linejoin="round">
                                    <path d="M6 9H4.5a2.5 2.5 0 0 1 0-5H6"/>
                                    <path d="M18 9h1.5a2.5 2.5 0 0 0 0-5H18"/>
                                    <path d="M4 22h16"/>
                                    <path d="M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22"/>
                                    <path d="M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22"/>
                                    <path d="M18 2H6v7a6 6 0 0 0 12 0V2z"/>
                                  </svg>
                                </div>
                              {{/if}}

                              {{! Trophy name }}
                              <p class="text-xs font-bold text-gray-800 dark:text-gray-100 leading-snug line-clamp-2">
                                {{trophy.name}}
                              </p>

                              {{! Tournament name }}
                              {{#if trophy.tournament}}
                                <p class="text-[10px] text-gray-400 dark:text-gray-500 leading-snug line-clamp-1 -mt-1">
                                  {{trophy.tournament}}
                                </p>
                              {{/if}}

                              {{! Year pill }}
                              <span class="inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-bold
                                           bg-amber-100 dark:bg-amber-900/40
                                           text-amber-700 dark:text-amber-400
                                           ring-1 ring-amber-200 dark:ring-amber-700/40">
                                {{group.year}}
                              </span>
                            </div>
                          </div>
                        {{/each}}
                      </div>
                    </div>

                  </div>
                {{/each}}

              {{! ── Empty state ── }}
              {{else}}
                <div class="rounded-2xl bg-white dark:bg-gray-900
                            border border-dashed border-amber-200 dark:border-amber-800/40
                            flex flex-col items-center justify-center py-20 text-center px-6">

                  {{! Layered glow rings }}
                  <div class="relative mb-6">
                    <div class="absolute inset-0 rounded-full bg-amber-300/20 dark:bg-amber-500/10 scale-150 animate-pulse"></div>
                    <div class="relative w-20 h-20 rounded-2xl
                                bg-gradient-to-br from-amber-100 to-yellow-100
                                dark:from-amber-900/40 dark:to-yellow-900/30
                                flex items-center justify-center shadow-lg shadow-amber-200/50 dark:shadow-amber-900/30">
                      <svg class="w-10 h-10 text-amber-400 dark:text-amber-500" viewBox="0 0 24 24"
                           fill="none" stroke="currentColor" stroke-width="1.5"
                           stroke-linecap="round" stroke-linejoin="round">
                        <path d="M6 9H4.5a2.5 2.5 0 0 1 0-5H6"/>
                        <path d="M18 9h1.5a2.5 2.5 0 0 0 0-5H18"/>
                        <path d="M4 22h16"/>
                        <path d="M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22"/>
                        <path d="M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22"/>
                        <path d="M18 2H6v7a6 6 0 0 0 12 0V2z"/>
                      </svg>
                    </div>
                  </div>

                  <p class="text-2xl font-extrabold text-gray-900 dark:text-white mb-2 tracking-tight">
                    No Trophies
                  </p>
                  <p class="text-sm text-gray-400 dark:text-gray-500 max-w-xs mb-6">
                    Every champion started with zero. Add your first trophy and start building your legacy.
                  </p>

                  {{#if this.isCurrentUserClub}}
                    <button
                      type="button"
                      {{on "click" this.openTrophyModal}}
                      class="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl text-sm font-semibold
                             bg-gradient-to-r from-amber-400 to-yellow-500
                             text-white shadow-md shadow-amber-400/30
                             hover:shadow-lg hover:shadow-amber-400/40 hover:scale-105
                             active:scale-95 transition-all duration-200 cursor-pointer">
                      <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                           stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M12 5v14"/><path d="M5 12h14"/>
                      </svg>
                      Add First Trophy
                    </button>
                  {{/if}}

                </div>
              {{/if}}

            </div>

          {{! ── TEAMS ── }}
          {{else if (eq this.activeTab "teams")}}
            <div class="space-y-4">

              {{! Header bar }}
              <div class="flex flex-wrap items-center justify-between gap-3
                          rounded-2xl bg-white dark:bg-gray-900
                          border border-gray-100 dark:border-gray-700/50
                          shadow-sm px-4 sm:px-5 py-4">
                <div class="flex items-center gap-3">
                  <div class="w-10 h-10 rounded-xl bg-gradient-to-br from-indigo-500 to-violet-600
                              flex items-center justify-center shadow-md shadow-indigo-500/30 shrink-0">
                    <svg class="w-5 h-5 text-white" viewBox="0 0 24 24" fill="none"
                         stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                      <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                      <circle cx="9" cy="7" r="4"/>
                      <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
                      <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
                    </svg>
                  </div>
                  <div>
                    <h3 class="text-base font-bold text-gray-900 dark:text-white leading-tight">Teams</h3>
                    <p class="text-xs text-gray-400 dark:text-gray-500 mt-0.5">
                      {{#if this.teamsLoading}}
                        Loading…
                      {{else}}
                        {{this.teams.length}} team{{#if (eq this.teams.length 1)}}{{else}}s{{/if}} registered
                      {{/if}}
                    </p>
                  </div>
                </div>
                {{#if this.isCurrentUserClub}}
                  <button
                    type="button"
                    {{on "click" this.openAddTeamModal}}
                    class="inline-flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-semibold
                           bg-gradient-to-r from-indigo-500 to-violet-600
                           text-white shadow-md shadow-indigo-500/25
                           hover:shadow-lg hover:shadow-indigo-500/35 hover:scale-105
                           active:scale-95 transition-all duration-200 cursor-pointer">
                    <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                         stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                      <path d="M12 5v14"/><path d="M5 12h14"/>
                    </svg>
                    Add Team
                  </button>
                {{/if}}
              </div>

              {{! ── Loading skeleton ── }}
              {{#if this.teamsLoading}}
                {{#each this.skeletonRows as |_|}}
                  <div class="rounded-2xl bg-white dark:bg-gray-900
                              border border-gray-100 dark:border-gray-700/50
                              shadow-sm p-5 animate-pulse">
                    <div class="flex items-center gap-4">
                      <div class="w-9 h-9 rounded-xl bg-gray-200 dark:bg-gray-700 shrink-0"></div>
                      <div class="w-16 h-16 rounded-2xl bg-gray-200 dark:bg-gray-700 shrink-0"></div>
                      <div class="flex-1 space-y-2">
                        <div class="h-4 w-40 bg-gray-200 dark:bg-gray-700 rounded-lg"></div>
                        <div class="h-3 w-24 bg-gray-200 dark:bg-gray-700 rounded-lg"></div>
                      </div>
                      <div class="hidden sm:flex gap-6">
                        {{#each this.skeletonRows as |_|}}
                          <div class="space-y-1">
                            <div class="h-3 w-10 bg-gray-200 dark:bg-gray-700 rounded"></div>
                            <div class="h-5 w-12 bg-gray-200 dark:bg-gray-700 rounded"></div>
                          </div>
                        {{/each}}
                      </div>
                    </div>
                  </div>
                {{/each}}

              {{! ── Error ── }}
              {{else if this.teamsError}}
                <div class="rounded-2xl bg-white dark:bg-gray-900
                            border border-red-100 dark:border-red-900/30
                            shadow-sm p-10 flex flex-col items-center text-center gap-3">
                  <div class="w-12 h-12 rounded-2xl bg-red-100 dark:bg-red-900/30
                              flex items-center justify-center">
                    <svg class="w-6 h-6 text-red-500" viewBox="0 0 24 24" fill="none"
                         stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                      <circle cx="12" cy="12" r="10"/>
                      <line x1="12" y1="8" x2="12" y2="12"/>
                      <line x1="12" y1="16" x2="12.01" y2="16"/>
                    </svg>
                  </div>
                  <p class="text-sm font-semibold text-gray-900 dark:text-white">{{this.teamsError}}</p>
                  <button
                    type="button"
                    {{on "click" this.retryTeams}}
                    class="text-xs text-indigo-500 hover:text-indigo-600 font-semibold underline cursor-pointer">
                    Try again
                  </button>
                </div>

              {{! ── Populated ── }}
              {{else if this.teams.length}}
                {{#each this.teamsWithRank as |team|}}
                  <div class="group relative rounded-2xl bg-white dark:bg-gray-900
                              border border-gray-100 dark:border-gray-700/50
                              shadow-sm hover:shadow-lg hover:shadow-indigo-500/8
                              hover:border-indigo-200 dark:hover:border-indigo-700/50
                              transition-all duration-300 overflow-hidden">

                    {{! Subtle left accent bar }}
                    <div class="absolute left-0 inset-y-0 w-1 rounded-l-2xl
                                bg-gradient-to-b from-indigo-500 to-violet-600
                                opacity-0 group-hover:opacity-100 transition-opacity duration-300"></div>

                    {{! Pending overlay }}
                    {{#if (eq team.team_status "pending")}}
                      <div class="absolute inset-0 z-10 flex items-center justify-center
                                  bg-white/40 dark:bg-gray-900/40 backdrop-blur-[2px] rounded-2xl">
                        <span class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-bold
                                     bg-amber-100 dark:bg-amber-900/50
                                     text-amber-700 dark:text-amber-400
                                     ring-1 ring-amber-300 dark:ring-amber-700/60 shadow-sm">
                          <svg class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                               stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                            <circle cx="12" cy="12" r="10"/>
                            <polyline points="12 6 12 12 16 14"/>
                          </svg>
                          Pending Approval
                        </span>
                      </div>
                    {{/if}}

                    <div class="px-4 sm:px-5 py-4 flex flex-col sm:flex-row sm:items-center gap-3 sm:gap-4
                                {{if (eq team.team_status "pending") "blur-[2px] select-none"}}">

                      {{! Rank badge }}
                      <div class="w-9 h-9 rounded-xl shrink-0
                                  bg-gradient-to-br from-indigo-500 to-violet-600
                                  flex items-center justify-center shadow-md shadow-indigo-500/25">
                        <span class="text-xs font-extrabold text-white">#{{team.rank}}</span>
                      </div>

                      {{! Logo }}
                      <div class="w-16 h-16 rounded-2xl overflow-hidden shrink-0
                                  ring-2 ring-gray-100 dark:ring-gray-700/60
                                  group-hover:ring-indigo-200 dark:group-hover:ring-indigo-700/50
                                  transition-all duration-300 bg-gray-100 dark:bg-gray-800
                                  flex items-center justify-center">
                        {{#if team.team_logo}}
                          <img src={{this.teamLogoUrl team.team_logo}}
                               alt={{team.team_name}}
                               class="w-full h-full object-cover" />
                        {{else}}
                          <svg class="w-7 h-7 text-gray-300 dark:text-gray-600" viewBox="0 0 24 24"
                               fill="none" stroke="currentColor" stroke-width="1.5"
                               stroke-linecap="round" stroke-linejoin="round">
                            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                            <circle cx="9" cy="7" r="4"/>
                          </svg>
                        {{/if}}
                      </div>

                      {{! Name + status }}
                      <div class="flex-1 min-w-0">
                        <div class="flex items-center gap-2 flex-wrap mb-1">
                          <h4 class="text-sm font-bold text-gray-900 dark:text-white truncate">
                            {{team.team_name}}
                          </h4>
                          {{#if (eq team.team_status "active")}}
                            <span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold
                                         bg-emerald-100 dark:bg-emerald-900/30
                                         text-emerald-700 dark:text-emerald-400
                                         ring-1 ring-emerald-200 dark:ring-emerald-700/40">
                              <span class="w-1.5 h-1.5 rounded-full bg-emerald-500 inline-block"></span>
                              Active
                            </span>
                          {{else}}
                            <span class="inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-bold
                                         bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400
                                         ring-1 ring-gray-200 dark:ring-gray-700">
                              {{team.team_status}}
                            </span>
                          {{/if}}
                        </div>
                        {{#if team.team_email}}
                          <p class="text-xs text-gray-400 dark:text-gray-500 truncate">{{team.team_email}}</p>
                        {{/if}}
                      </div>

                      {{! Stats grid }}
                      <div class="flex sm:grid sm:grid-cols-5 gap-x-4 gap-y-2 shrink-0
                                  overflow-x-auto sm:overflow-visible w-full sm:w-auto"
                           style="scrollbar-width: none; -ms-overflow-style: none;">

                        <div class="flex flex-col items-center text-center min-w-[48px]">
                          <span class="text-[10px] font-semibold text-gray-400 dark:text-gray-500 uppercase tracking-wide mb-0.5">
                            Matches
                          </span>
                          <span class="text-sm font-extrabold text-gray-900 dark:text-white tabular-nums">
                            {{#if team.played}}{{team.played}}{{else}}<span class="text-gray-300 dark:text-gray-600">—</span>{{/if}}
                          </span>
                        </div>

                        <div class="flex flex-col items-center text-center min-w-[48px]">
                          <span class="text-[10px] font-semibold text-gray-400 dark:text-gray-500 uppercase tracking-wide mb-0.5">
                            Runs
                          </span>
                          <span class="text-sm font-extrabold text-indigo-600 dark:text-indigo-400 tabular-nums">
                            {{#if team.total_runs_taken}}{{team.total_runs_taken}}{{else}}<span class="text-gray-300 dark:text-gray-600">—</span>{{/if}}
                          </span>
                        </div>

                        <div class="flex flex-col items-center text-center min-w-[48px]">
                          <span class="text-[10px] font-semibold text-gray-400 dark:text-gray-500 uppercase tracking-wide mb-0.5">
                            Wickets
                          </span>
                          <span class="text-sm font-extrabold text-rose-600 dark:text-rose-400 tabular-nums">
                            {{#if team.total_wickets_taken}}{{team.total_wickets_taken}}{{else}}<span class="text-gray-300 dark:text-gray-600">—</span>{{/if}}
                          </span>
                        </div>

                      </div>
                    </div>
                  </div>
                {{/each}}

              {{! ── Empty ── }}
              {{else}}
                <div class="rounded-2xl bg-white dark:bg-gray-900
                            border border-dashed border-indigo-200 dark:border-indigo-800/40
                            flex flex-col items-center justify-center py-20 text-center px-6">
                  <div class="relative mb-5">
                    <div class="absolute inset-0 rounded-full bg-indigo-300/20 dark:bg-indigo-500/10 scale-150 animate-pulse"></div>
                    <div class="relative w-20 h-20 rounded-2xl
                                bg-gradient-to-br from-indigo-100 to-violet-100
                                dark:from-indigo-900/40 dark:to-violet-900/30
                                flex items-center justify-center shadow-lg shadow-indigo-200/50 dark:shadow-indigo-900/30">
                      <svg class="w-10 h-10 text-indigo-400 dark:text-indigo-500" viewBox="0 0 24 24"
                           fill="none" stroke="currentColor" stroke-width="1.5"
                           stroke-linecap="round" stroke-linejoin="round">
                        <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                        <circle cx="9" cy="7" r="4"/>
                        <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
                        <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
                      </svg>
                    </div>
                  </div>
                  <p class="text-xl font-bold text-gray-900 dark:text-white mb-2 tracking-tight">No Teams Yet</p>
                  <p class="text-sm text-gray-400 dark:text-gray-500 max-w-xs mb-6">
                    This club hasn't added any teams. Be the first to register one.
                  </p>
                  <button
                    type="button"
                    class="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl text-sm font-semibold
                           bg-gradient-to-r from-indigo-500 to-violet-600
                           text-white shadow-md shadow-indigo-500/25
                           hover:shadow-lg hover:shadow-indigo-500/35 hover:scale-105
                           active:scale-95 transition-all duration-200 cursor-pointer">
                    <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                         stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                      <path d="M12 5v14"/><path d="M5 12h14"/>
                    </svg>
                    Add First Team
                  </button>
                </div>
              {{/if}}

            </div>

          {{! ── FIXTURE ── }}
          {{else if (eq this.activeTab "fixture")}}
            <div class="rounded-2xl bg-white dark:bg-gray-900
                        border border-gray-100 dark:border-gray-700/50 shadow-sm p-6 sm:p-8">
              <div class="flex flex-col items-center justify-center py-16 text-center">
                <div class="w-16 h-16 mb-4 rounded-2xl bg-violet-100 dark:bg-violet-900/30
                            flex items-center justify-center">
                  <svg class="w-8 h-8 text-violet-400" viewBox="0 0 24 24" fill="none"
                       stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                    <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
                    <line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/>
                    <line x1="3" y1="10" x2="21" y2="10"/>
                  </svg>
                </div>
                <p class="text-base font-semibold text-gray-900 dark:text-white mb-1">No fixtures scheduled</p>
                <p class="text-sm text-gray-400 dark:text-gray-600">Upcoming fixtures will be listed here.</p>
              </div>
            </div>

          {{! ── LIVE MATCH ── }}
          {{else if (eq this.activeTab "live")}}
            <div class="rounded-2xl bg-white dark:bg-gray-900
                        border border-gray-100 dark:border-gray-700/50 shadow-sm p-6 sm:p-8">
              <div class="flex flex-col items-center justify-center py-16 text-center">
                <div class="w-16 h-16 mb-4 rounded-2xl bg-rose-100 dark:bg-rose-900/30
                            flex items-center justify-center relative">
                  <span class="absolute top-2 right-2 flex">
                    <span class="animate-ping absolute inline-flex h-2.5 w-2.5 rounded-full bg-rose-500 opacity-75"></span>
                    <span class="relative inline-flex rounded-full h-2.5 w-2.5 bg-rose-500"></span>
                  </span>
                  <svg class="w-8 h-8 text-rose-400" viewBox="0 0 24 24" fill="none"
                       stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                    <circle cx="12" cy="12" r="10"/>
                    <polygon points="10 8 16 12 10 16 10 8"/>
                  </svg>
                </div>
                <p class="text-base font-semibold text-gray-900 dark:text-white mb-1">No live matches</p>
                <p class="text-sm text-gray-400 dark:text-gray-600">Live matches will appear here in real time.</p>
              </div>
            </div>

          {{! ── PREVIOUS MATCH ── }}
          {{else if (eq this.activeTab "previous")}}
            <div class="rounded-2xl bg-white dark:bg-gray-900
                        border border-gray-100 dark:border-gray-700/50 shadow-sm p-6 sm:p-8">
              {{#if this.hasRecentMatches}}
                <div class="space-y-3">
                  {{#each this.club.recent_matches as |match|}}
                    <div class="p-4 rounded-xl border border-gray-100 dark:border-gray-700/50
                                bg-gray-50 dark:bg-gray-800/50">
                      <p class="text-sm font-medium text-gray-700 dark:text-gray-300">{{match}}</p>
                    </div>
                  {{/each}}
                </div>
              {{else}}
                <div class="flex flex-col items-center justify-center py-16 text-center">
                  <div class="w-16 h-16 mb-4 rounded-2xl bg-gray-100 dark:bg-gray-800
                              flex items-center justify-center">
                    <svg class="w-8 h-8 text-gray-400" viewBox="0 0 24 24" fill="none"
                         stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                      <circle cx="12" cy="12" r="10"/>
                      <path d="M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"/>
                      <path d="M2 12h20"/>
                    </svg>
                  </div>
                  <p class="text-base font-semibold text-gray-900 dark:text-white mb-1">No recent matches</p>
                  <p class="text-sm text-gray-400 dark:text-gray-600">Match history will be displayed here.</p>
                </div>
              {{/if}}
            </div>

          {{! ── ALL OTHER TABS (generic coming soon) ── }}
          {{else}}
            <div class="rounded-2xl bg-white dark:bg-gray-900
                        border border-gray-100 dark:border-gray-700/50 shadow-sm p-6 sm:p-8">
              <div class="flex flex-col items-center justify-center py-16 text-center">
                <div class="w-16 h-16 mb-4 rounded-2xl
                            bg-gradient-to-br from-indigo-100 to-violet-100
                            dark:from-indigo-900/30 dark:to-violet-900/30
                            flex items-center justify-center">
                  <svg class="w-8 h-8 text-indigo-400" viewBox="0 0 24 24" fill="none"
                       stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                    <circle cx="12" cy="12" r="10"/>
                    <path d="M12 8v4m0 4h.01"/>
                  </svg>
                </div>
                <p class="text-base font-semibold text-gray-900 dark:text-white mb-1">Coming Soon</p>
                <p class="text-sm text-gray-400 dark:text-gray-600">This section is not yet available.</p>
              </div>
            </div>
          {{/if}}

        </div>
      {{/if}}
    </section>
  </template>
}
