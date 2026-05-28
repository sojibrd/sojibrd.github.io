import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { eq, add } from 'ember-truth-helpers';
import { service } from '@ember/service';
import lucideIcon from 'spordium/helpers/lucide-icon';
import HeroBanner from 'spordium/components/tournament/detail/hero-cover';
import InfoBar from 'spordium/components/tournament/detail/info-bar';
import OverviewTab from 'spordium/components/tournament/detail/overview-tab';
import TeamsTab from 'spordium/components/tournament/detail/teams-tab';
import OrganizerTab from 'spordium/components/tournament/detail/organizer-tab';
import PreviousMatchesTab from 'spordium/components/tournament/detail/previous-match-tab';
import LiveMatchesTab from 'spordium/components/tournament/detail/live-match-tab';
import SponsorTab from 'spordium/components/tournament/detail/sponsor-tab';

const API_BASE = 'https://spordiumapi.adnanfoundation.com';
const IMAGE_BASE = 'https://ag-khela.s3.ap-south-1.amazonaws.com/';

const TABS = [
  { id: 'overview', label: 'Overview', icon: 'info' },
  { id: 'organizer', label: 'Organizer', icon: 'building-2' },
  { id: 'teams', label: 'Teams', icon: 'users' },
  { id: 'fixtures', label: 'Fixtures', icon: 'calendar' },
  { id: 'previousMatch', label: 'Previous Matches', icon: 'history' },
  { id: 'liveMatch', label: 'Live Matches', icon: 'radio' },
  // { id: 'pointTable', label: 'Point Table', icon: 'table-2' },
  { id: 'stats', label: 'Stats', icon: 'bar-chart-2' },
  { id: 'sponsor', label: 'Sponsor', icon: 'handshake' },
];

// ══════════════════════════════════════════════════════════════════════════════
// TournamentDetail — detail page with 10 tabs
//
// @arg {string} tournamentId — from query param
// @arg {string} activeTab    — from query param
// ══════════════════════════════════════════════════════════════════════════════
export default class TournamentDetail extends Component {
  constructor(owner, args) {
    super(owner, args);
    if (this.args.tournamentId) {
      this.fetchTournamentOne(this.args.tournamentId);

      // ✅ Fix: direct URL load এ active tab এর data fetch করো
      const initialTab = this.args.activeTab ?? 'overview';
      if (initialTab !== 'overview') {
        this.fetchTabData(initialTab);
      }
    }
  }
  @service router;
  @service session;

  @tracked tournamentOverview = null;
  @tracked isLoading = true;
  @tracked error = null;
  @tracked activeTab = this.args.activeTab ?? 'overview';
  @tracked tabBarStart = true;
  @tracked tabBarEnd = false;

  // ── Tab-specific data (lazy loaded) ───────────────────────────────────────
  @tracked teams = [];
  teamsLoaded = false;
  @tracked organizer = [];
  organizerLoaded = false;
  @tracked fixtures = [];
  fixturesLoaded = false;
  @tracked previousMatch = [];
  previousMatchLoaded = false;
  @tracked posts = [];
  postsLoaded = false;
  @tracked liveMatch = [];
  liveMatchLoaded = false;
  @tracked sponsor = [];
  sponsorLoaded = false;

  get tabs() {
    return TABS;
  }
  get tOne() {
    return this.tournamentOverview ?? {};
  }

  get coverUrl() {
    return this.tOne.tournament_logo ? `${IMAGE_BASE}${this.tOne.tournament_logo}` : '/placeholder.png';
  }

  get startDate() {
    const date = this.tOne.tournament_start_date;
    if (!date) return 'TBA';
    return new Date(date).toLocaleDateString('en-GB', {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
    });
  }

  get endDate() {
    const date = this.tOne.tournament_team_registration_end_date;
    if (!date) return 'TBA';
    return new Date(date).toLocaleDateString('en-GB', {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
    });
  }

  get city() {
    return this.tOne.tournament_location?.city ?? 'TBA';
  }

  get country() {
    return this.tOne.tournament_location?.country ?? '';
  }
  get tournamentType() {
    return this.tOne.tournament_type ?? 'Unknown';
  }
  get totalTeams() {
    return this.tOne.registered_teams ?? 0;
  }

  get maxTeams() {
    return this.tOne.tournament_paid_number_of_teams ?? '?';
  }

  get prizePool() {
    const prizes = this.tOne.tournament_prize;
    if (!prizes?.length) return null;
    // prize array তে total amount থাকলে সেটা দেখাও
    return `৳${Number(prizes[0].prize_name === 'tournamentWinnerPrize' ? prizes[0].prize : (prizes ?? 0)).toLocaleString()}`;
  }

  get sportLabel() {
    return this.tOne.tournament_sport ?? '';
  }

  get statusLabel() {
    // API তে status field নেই, start_date দেখে calculate করো
    const start = this.tOne.tournament_start_date;
    if (!start) return 'Upcoming';
    return new Date(start) <= new Date() ? 'Ongoing' : 'Upcoming';
  }
  get isOrganizer() {
    return this.session.isAuthenticated && this.tOne.tournament_owner === this.session.currentUser?.user_id;
  }

  get season() {
    return this.tOne.tornament_season ?? '';
  }

  // ── Fetch ─────────────────────────────────────────────────────────────────
  async fetchTournamentOne(id) {
    this.isLoading = true;
    this.error = null;
    try {
      const headers = {};
      if (this.session.isAuthenticated) {
        headers.Authorization = `Bearer ${this.session.token}`;
      }
      const resOne = await fetch(`${API_BASE}/tournament_v2/create-tournament-1/?tournament_id=${id}`, {
        headers,
      });

      if (!resOne.ok) throw new Error(`HTTP ${resOne.status}`);
      const jsonOne = await resOne.json();

      this.tournamentOverview = jsonOne.data ?? jsonOne;
      return;
    } catch {
      this.error = 'Failed to load tournament. Please try again.';
    } finally {
      this.isLoading = false;
    }
  }

  async fetchTabData(tab) {
    console.log('tab', tab);

    const id = this.args.tournamentId;
    const h = this.session.isAuthenticated ? { Authorization: `Bearer ${this.session.token}` } : {};
    try {
      switch (tab) {
        case 'teams':
          if (this.teamsLoaded) return;
          {
            const r = await fetch(`${API_BASE}/tournament_v2/create-tournament-3/?tournament_id=${id}`, {
              headers: h,
            });
            const j = await r.json();
            this.teams = j.data ?? j;
            this.teamsLoaded = true;
          }
          break;
        case 'previousMatch':
          if (this.previousMatchLoaded) return;
          {
            const r = await fetch(`${API_BASE}/tournament/get_tournament_schedule/${id}/?action_type=previous`, {
              headers: h,
            });
            const j = await r.json();
            this.previousMatch = j.data ?? j.results ?? [];
            this.previousMatchLoaded = true;
          }
          break;
        case 'liveMatch':
          if (this.liveMatchLoaded) return;
          {
            const r = await fetch(`${API_BASE}/tournament/get_tournament_schedule/${id}/?action_type=live`, {
              headers: h,
            });
            const j = await r.json();
            this.liveMatch = j.data ?? j.results ?? [];
            this.liveMatchLoaded = true;
          }
          break;
        case 'organizer':
          if (this.organizerLoaded) return;
          {
            const r = await fetch(`${API_BASE}/tournament_v2/create-tournament-4/?tournament_id=${id}`, {
              headers: h,
            });
            const j = await r.json();
            this.organizer = j.data ?? j.results ?? [];
            this.organizerLoaded = true;
          }
          break;
        case 'sponsor':
          if (this.sponsorLoaded) return;
          {
            const r = await fetch(`${API_BASE}/tournament_v2/get-tournament-all-sponsors/?tournament_id=${id}`, { headers: h });
            const j = await r.json();
            this.sponsor = j.data ?? [];
            this.sponsorLoaded = true;
          }
          break;
      }
    } catch {
      /* non-fatal */
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  @action
  switchTab(tabId) {
    this.activeTab = tabId;
    this.fetchTabData(tabId);
    this.router.replaceWith('tournament.tournament-details', {
      queryParams: { id: this.args.tournamentId, tab: tabId },
    });
  }

  @action
  retry() {
    this.fetchTournamentOne(this.args.tournamentId);
  }

  @action
  onTabBarScroll(e) {
    const el = e.target;
    this.tabBarStart = el.scrollLeft <= 8;
    this.tabBarEnd = el.scrollLeft + el.clientWidth >= el.scrollWidth - 8;
  }

  @action
  refreshSponsors() {
    // ✅ flag reset করো যাতে নতুন করে fetch হয়
    this.sponsorLoaded = false;
    this.sponsor = []; // ✅ এটা না করলে পুরনো data দেখায়
    this.fetchTabData('sponsor');
  }

  <template>
    <div class="min-h-screen bg-gray-50 dark:bg-gray-950">

      {{#if this.isLoading}}
        {{! Skeleton header }}
        <div class="bg-white dark:bg-gray-900">
          <div class="h-52 bg-gray-200 dark:bg-gray-700 animate-pulse"></div>
          <div class="max-w-5xl mx-auto px-4 py-5 space-y-3 animate-pulse">
            <div class="h-7 bg-gray-200 dark:bg-gray-700 rounded w-1/2"></div>
            <div class="h-4 bg-gray-200 dark:bg-gray-700 rounded w-1/3"></div>
          </div>
        </div>

      {{else if this.error}}
        <div class="flex flex-col items-center justify-center py-32 gap-4">
          <p class="text-sm text-red-500">{{this.error}}</p>
          <button type="button" {{on "click" this.retry}} class="px-4 py-2 text-sm font-medium rounded-xl bg-blue-600 text-white hover:bg-blue-700">
            Retry
          </button>
        </div>

      {{else}}
        <HeroBanner @coverUrl={{this.coverUrl}} @tOne={{this.tOne}} @isOrganizer={{this.isOrganizer}} @tournamentId={{@tournamentId}} />
        <div class="bg-white dark:bg-gray-900 border-b border-gray-200 dark:border-gray-700">

          <InfoBar
            @tOne={{this.tOne}}
            @sportLabel={{this.sportLabel}}
            @statusLabel={{this.statusLabel}}
            @startDate={{this.startDate}}
            @endDate={{this.endDate}}
            @city={{this.city}}
            @country={{this.country}}
            @totalTeams={{this.totalTeams}}
            @maxTeams={{this.maxTeams}}
            @prizePool={{this.prizePool}}
          />

          {{! ── Tab bar ──────────────────────────────────────────────────── }}
          <div class="relative max-w-5xl mx-auto">
            {{#unless this.tabBarStart}}
              <div
                class="absolute left-0 top-0 bottom-0 w-8 bg-gradient-to-r from-white dark:from-gray-900 to-transparent z-10 pointer-events-none"
              ></div>
            {{/unless}}
            {{#unless this.tabBarEnd}}
              <div
                class="absolute right-0 top-0 bottom-0 w-8 bg-gradient-to-l from-white dark:from-gray-900 to-transparent z-10 pointer-events-none"
              ></div>
            {{/unless}}

            <div class="flex overflow-x-auto scrollbar-hide px-4 sm:px-6 gap-1" {{on "scroll" this.onTabBarScroll}}>
              {{#each this.tabs as |tab|}}
                <button
                  type="button"
                  {{on "click" (fn this.switchTab tab.id)}}
                  class="flex items-center gap-1.5 px-3 py-3 text-xs font-semibold whitespace-nowrap border-b-2 transition-all
                    {{if
                      (eq this.activeTab tab.id)
                      'border-blue-600 text-blue-600 dark:text-blue-400'
                      'border-transparent text-gray-500 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white'
                    }}"
                >
                  {{lucideIcon tab.icon class="w-3.5 h-3.5"}}
                  {{tab.label}}
                </button>
              {{/each}}
            </div>
          </div>
        </div>
        {{! ── Tab content ──────────────────────────────────────────────── }}
        <div class="max-w-5xl mx-auto px-4 sm:px-6 py-6">

          {{! Overview }}
          {{#if (eq this.activeTab "overview")}}
            <OverviewTab
              @tOne={{this.tOne}}
              @season={{this.season}}
              @maxTeams={{this.maxTeams}}
              @tournamentType={{this.tournamentType}}
              @prizePool={{this.prizePool}}
            />
            {{! Teams }}
          {{else if (eq this.activeTab "teams")}}
            <TeamsTab @teamsData={{this.teams.teams_data}} @groupsData={{this.teams.groups_data}} />
            {{! Fixtures }}
          {{else if (eq this.activeTab "previousMatch")}}
            {{#if this.previousMatch.length}}
              <PreviousMatchesTab @matches={{this.previousMatch}} />
            {{else}}
              <div class="py-12 text-center text-sm text-gray-400">Previous Match not yet available.</div>
            {{/if}}

            {{! liveMatch }}
          {{else if (eq this.activeTab "liveMatch")}}
            {{#if this.liveMatch.length}}
              <LiveMatchesTab @matches={{this.liveMatch}} />
            {{else}}
              <div class="py-12 text-center text-sm text-gray-400">No matches yet.</div>
            {{/if}}

            {{! Posts }}
          {{else if (eq this.activeTab "organizer")}}
            <OrganizerTab @data={{this.organizer}} />
          {{else if (eq this.activeTab "stats")}}
            <div class="py-12 text-center text-sm text-gray-400">Comming Soon.</div>
          {{else if (eq this.activeTab "sponsor")}}
            <SponsorTab
              @sponsors={{this.sponsor}}
              @tournamentId={{@tournamentId}}
              @isOrganizer={{this.isOrganizer}}
              @onSponsorUpdated={{this.refreshSponsors}}
            />
          {{/if}}

        </div>
      {{/if}}

    </div>
  </template>
}
