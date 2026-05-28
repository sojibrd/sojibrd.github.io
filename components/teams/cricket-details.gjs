import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { eq, gt } from 'ember-truth-helpers';
import config from 'spordium/config/environment';
import { inject as service } from '@ember/service';
import TeamDetailsSkeleton from './team-details/skeleton';
import TeamCalendar from './team-details/team-calendar';
import TournamentTable from './team-details/tournament-table';
import PreviousMatch from './team-details/previous-match';
import ErrorScreen from './team-details/error';
import getTeamLogo from 'spordium/helpers/append-bucket';

const TABS = [
  { id: 'about', label: 'About Us' },
  { id: 'trophies', label: 'Trophies' },
  { id: 'teams', label: 'Teams Members' },
  { id: 'schedule', label: 'Schedule' },
  { id: 'stats', label: 'Stats' },
  // { id: 'matches', label: 'Matches' },
  { id: 'previous', label: 'Previous Match' },
  { id: 'posts', label: 'Posts' },
  { id: 'gallery', label: 'Gallery' },
];

const SKELETON_ROWS = [1, 2, 3];

export default class TeamDetails extends Component {
  config = config;

  get teamDetails() {
    return this.args.model;
  }

  @tracked teamDetails = null;
  @tracked teamMembers = null;

  @tracked previousMatchData = null;
  @tracked isPreviousLoading = false;
  @tracked previousMatchError = null;

  @tracked isLoading = true;
  @tracked error = null;
  @tracked isNavigating = false;

  @tracked isLoadingMember = true;
  @tracked errorMember = null;
  @tracked activeTab = 'about';

  @tracked calendarData = null;
  @tracked isCalendarLoading = false;
  @tracked calendarError = null;

  @service session;
  @service store;
  @service api;
  @service router;

  constructor(owner, args) {
    super(owner, args);
    this.fetchDetails();
    this.fetchTeamMember();
  }

  async fetchTeamMember() {
    this.isLoadingMember = true;
    this.errorMember = null;

    try {
      this.teamMembers = await this.store.findRecord('team-member', this.args.model.team_id);
      // console.log('members', this.teamMembers);
    } catch {
      this.errorMember = 'Failed to load team members. Please try again.';
    } finally {
      this.isLoadingMember = false;
    }
  }

  async fetchDetails() {
    this.isLoading = true;
    this.error = null;
    try {
      const result = await this.api.post('/team/get_team_basic_data/', {
        team_id: this.args.model.team_id,
      });
      // return result?.data ?? result;
      // this.teamDetails = this.store.peekRecord('team', this.args.model.team_id);
      this.teamDetails = result?.data ?? result;
      // console.log('details', this.teamDetails);
    } catch {
      this.error = 'Failed to load team details. Please try again.';
    } finally {
      this.isLoading = false;
    }
  }

  @action retry() {
    window.location.reload();
  }

  @action async goToPlayer(playerId) {
    if (!playerId || this.isNavigating) return;
    this.isNavigating = true;
    try {
      const result = await this.api.get('/auth_user/get_profile_info/', { user_id: playerId });
      const username = result?.data?.user_username;
      if (username) {
        this.router.transitionTo('player', username);
      }
    } catch (e) {
      console.error('Failed to fetch player profile:', e);
    } finally {
      this.isNavigating = false;
    }
  }

  @action async setTab(tab) {
    this.activeTab = tab;

    if (tab === 'schedule' && !this.calendarData) {
      await this.fetchSchedule();
    }

    if (tab === 'previous' && !this.previousMatchData) {
      await this.fetchPreviousMatches();
    }
  }

  async fetchPreviousMatches() {
    this.isPreviousLoading = true;
    this.previousMatchError = null;

    try {
      const result = await this.api.get(`/team/team-upcomming-game-tournament-datetime/${this.args.model.team_id}/`);
      // API response shape অনুযায়ী adjust করো
      this.previousMatchData = result?.results ?? result?.data ?? result ?? [];
    } catch (err) {
      console.error(err);
      this.previousMatchError = 'Could not load previous matches.';
    } finally {
      if (!this.isDestroying && !this.isDestroyed) {
        this.isPreviousLoading = false;
      }
    }
  }

  async fetchSchedule() {
    this.isCalendarLoading = true;
    this.calendarError = null;

    try {
      const result = await this.api.get(`/team/team-upcomming-game-tournament-calender/${this.args.model.team_id}/`);
      this.calendarData = result?.data?.games_data ?? [];
    } catch (err) {
      console.error(err);
      this.calendarError = 'Could not load schedule at this time.';
    } finally {
      if (!this.isDestroying && !this.isDestroyed) {
        this.isCalendarLoading = false;
      }
    }
  }

  get tabs() {
    return TABS;
  }
  get skeletonRows() {
    return SKELETON_ROWS;
  }

  get established() {
    if (!this.teamDetails?.established_date) return null;
    return new Date(this.teamDetails.established_date).getFullYear();
  }

  get hasManagers() {
    return (this.teamDetails?.managers?.length ?? 0) > 0;
  }
  get hasTrophies() {
    return (this.teamDetails?.trophies?.length ?? 0) > 0;
  }
  get hasRecentMatches() {
    return (this.teamDetails?.recent_matches?.length ?? 0) > 0;
  }
  get hasSports() {
    return (this.teamDetails?.sports?.length ?? 0) > 0;
  }

  <template>
    <section class="min-h-screen bg-gray-50 dark:bg-gray-950">
      {{! ── Loading skeleton ── }}
      {{#if this.isLoading}}
        <TeamDetailsSkeleton @skeletonRows={{this.skeletonRows}} />

        {{! ── Error state ── }}
      {{else if this.error}}
        <ErrorScreen @retry={{this.retry}} @error={{this.error}} />

        {{! ── Team Detail ── }}
      {{else if this.teamDetails}}

        {{! ─── HERO BANNER ─── }}
        <div class="relative">
          <div
            class="relative h-52 sm:h-72 overflow-hidden bg-gradient-to-br from-indigo-600 via-violet-600 to-fuchsia-600 dark:from-indigo-800 dark:via-violet-800 dark:to-fuchsia-800"
          >
            {{! Dot-grid texture }}
            <div
              class="absolute inset-0 opacity-[0.15]"
              style="background-image: radial-gradient(circle, white 1px, transparent 1px); background-size: 20px 20px;"
            ></div>

            {{! Soft top-right glow }}
            <div class="absolute -top-20 -right-20 w-80 h-80 rounded-full bg-white/10 blur-3xl pointer-events-none"></div>
            {{#if this.teamDetails.cover_photo}}
              <img src={{this.teamDetails.cover_photo}} alt="Cover photo" class="absolute inset-0 w-full h-full object-cover" />
              <div class="absolute inset-0 bg-gradient-to-t from-black/70 via-black/10 to-transparent"></div>
            {{/if}}
          </div>

          {{! Floating logo }}
          <div class="absolute left-1/2 -translate-x-1/2 bottom-0 translate-y-1/2 z-10">
            <div
              class="w-28 h-28 sm:w-32 sm:h-32 rounded-3xl border-4 border-white dark:border-gray-950 shadow-2xl overflow-hidden bg-white dark:bg-gray-800 ring-4 ring-indigo-300/40 dark:ring-indigo-500/30 transition-transform duration-300 hover:scale-105"
            >
              <img src={{getTeamLogo this.teamDetails.team_logo}} alt={{this.teamDetails.team_name}} class="w-full h-full object-cover" />
            </div>
          </div>
        </div>

        {{! ─── Team IDENTITY ─── }}
        <div class="pt-20 sm:pt-24 pb-6 text-center px-4 max-w-3xl mx-auto">

          <h1 class="text-2xl sm:text-3xl font-black text-gray-900 dark:text-white mb-2 leading-tight">
            {{this.teamDetails.team_name}}
          </h1>

          {{! Location row }}
          <div class="flex items-center justify-center gap-1.5 text-gray-500 dark:text-gray-400 text-sm mb-4">
            <svg
              class="w-4 h-4 text-violet-500 shrink-0"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2.5"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7z" />
              <circle cx="12" cy="9" r="2.5" />
            </svg>
            <span>{{this.teamDetails.game_location.city}},
              {{this.teamDetails.game_location.country}}</span>
          </div>

          {{! Quick contact links }}
          <div class="flex flex-wrap items-center justify-center gap-4">
            {{#if this.teamDetails.team_mobile}}
              <a
                href="tel:{{this.teamDetails.team_mobile}}"
                class="inline-flex items-center gap-1.5 text-xs text-gray-500 dark:text-gray-400 hover:text-emerald-600 dark:hover:text-emerald-400 transition-colors"
              >
                <svg
                  class="w-3.5 h-3.5 text-emerald-500"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2.5"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <path
                    d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07A19.5 19.5 0 0 1 4.69 12a19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 3.6 1.27h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"
                  />
                </svg>
                {{this.teamDetails.team_mobile}}
              </a>
            {{/if}}

            {{#if this.teamDetails.team_email}}
              <a
                href="mailto:{{this.teamDetails.team_email}}"
                class="inline-flex items-center gap-1.5 text-xs text-gray-500 dark:text-gray-400 hover:text-indigo-600 dark:hover:text-indigo-400 transition-colors"
              >
                <svg
                  class="w-3.5 h-3.5 text-indigo-500"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2.5"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z" />
                  <polyline points="22,6 12,13 2,6" />
                </svg>
                {{this.teamDetails.team_email}}
              </a>
            {{/if}}
          </div>
        </div>

        {{! ─── GOOGLE ADS — Leaderboard 728×90 ─── }}
        <div class="max-w-4xl mx-auto px-4 mb-6">
          <div
            class="rounded-2xl border-2 border-dashed border-gray-200 dark:border-gray-700/60 bg-gradient-to-br from-gray-100/60 to-white/40 dark:from-gray-800/40 dark:to-gray-900/30 flex flex-col items-center justify-center min-h-[90px] overflow-hidden relative"
          >
            <p class="text-[9px] font-bold tracking-[0.25em] uppercase text-gray-300 dark:text-gray-600 mb-1">Advertisement</p>
            {{! ↓ Replace with your AdSense <ins> tag }}
            <div id="team-details-leaderboard-ad" class="flex items-center gap-2 text-gray-300 dark:text-gray-700">
              <svg class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                <rect x="2" y="3" width="20" height="14" rx="2" />
                <line x1="8" y1="21" x2="16" y2="21" /><line x1="12" y1="17" x2="12" y2="21" />
              </svg>
              <span class="text-xs font-medium">728 × 90 — Google Ad Slot</span>
            </div>
          </div>
        </div>

        {{! ─── STICKY TAB NAV ─── }}
        <div class="sticky top-0 z-30 bg-white/90 dark:bg-gray-900/90 backdrop-blur-md border-b border-gray-200 dark:border-gray-700/60 shadow-sm">
          <div class="max-w-6xl mx-auto">
            <div class="flex overflow-x-auto gap-0 px-2 sm:px-4" role="tablist" style="scrollbar-width: none; -ms-overflow-style: none;">
              {{#each this.tabs as |tab|}}
                <button
                  type="button"
                  role="tab"
                  {{on "click" (fn this.setTab tab.id)}}
                  class="relative shrink-0 px-4 py-2.5 text-sm font-semibold whitespace-nowrap transition-colors duration-200 focus:outline-none
                    {{if
                      (eq this.activeTab tab.id)
                      'text-indigo-600 dark:text-indigo-400'
                      'text-gray-500 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200'
                    }}"
                >
                  {{tab.label}}
                  {{#if (eq this.activeTab tab.id)}}
                    <span class="absolute bottom-0 left-0 right-0 h-0.5 rounded-full bg-indigo-600 dark:bg-indigo-400"></span>
                  {{/if}}
                </button>
              {{/each}}
            </div>
          </div>
        </div>

        {{! ─── TAB CONTENT ─── }}
        <div class="max-w-6xl mx-auto px-4 py-8">

          {{! ── ABOUT US ── }}
          {{#if (eq this.activeTab "about")}}
            <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">

              {{! Left: description + details }}
              <div class="lg:col-span-2 space-y-6">
                {{! Team details grid }}
                <div class="rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-700/50 shadow-sm p-6">
                  <h3 class="flex items-center gap-2 text-base font-bold text-gray-900 dark:text-white mb-5">
                    <span class="w-8 h-8 rounded-xl bg-violet-100 dark:bg-violet-900/40 flex items-center justify-center shrink-0">
                      {{! Icon: Info (Better for "Information") }}
                      <svg
                        class="w-4 h-4 text-violet-600 dark:text-violet-400"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="2"
                        stroke-linecap="round"
                        stroke-linejoin="round"
                      >
                        <circle cx="12" cy="12" r="10"></circle>
                        <line x1="12" y1="16" x2="12" y2="12"></line>
                        <line x1="12" y1="8" x2="12.01" y2="8"></line>
                      </svg>
                    </span>
                    Team Information
                  </h3>

                  <dl class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    {{! Game Name }}
                    {{#if this.teamDetails.game_name}}
                      <div class="flex items-start gap-3 p-3 rounded-xl bg-gray-50 dark:bg-gray-800/60">
                        <div class="w-8 h-8 rounded-lg bg-teal-100 dark:bg-teal-900/30 flex items-center justify-center shrink-0">
                          {{! Icon: Gamepad }}
                          <svg
                            class="w-4 h-4 text-teal-500"
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                            stroke-width="2"
                            stroke-linecap="round"
                            stroke-linejoin="round"
                          >
                            <line x1="6" y1="12" x2="10" y2="12"></line>
                            <line x1="8" y1="10" x2="8" y2="14"></line>
                            <line x1="15" y1="13" x2="15.01" y2="13"></line>
                            <line x1="18" y1="11" x2="18.01" y2="11"></line>
                            <rect x="2" y="6" width="20" height="12" rx="2"></rect>
                          </svg>
                        </div>
                        <div>
                          <dt class="text-[10px] font-bold uppercase tracking-wider text-gray-400 dark:text-gray-500 mb-0.5">game_name</dt>
                          <dd class="text-sm font-medium text-gray-700 dark:text-gray-300">
                            {{this.teamDetails.game_name}}
                          </dd>
                        </div>
                      </div>
                    {{/if}}

                    {{! Address }}
                    <div class="flex items-start gap-3 p-3 rounded-xl bg-gray-50 dark:bg-gray-800/60">
                      <div class="w-8 h-8 rounded-lg bg-rose-100 dark:bg-rose-900/30 flex items-center justify-center shrink-0">
                        {{! Icon: Map-Pin }}
                        <svg
                          class="w-4 h-4 text-rose-500"
                          viewBox="0 0 24 24"
                          fill="none"
                          stroke="currentColor"
                          stroke-width="2"
                          stroke-linecap="round"
                          stroke-linejoin="round"
                        >
                          <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"></path>
                          <circle cx="12" cy="10" r="3"></circle>
                        </svg>
                      </div>
                      <div class="min-w-0">
                        <dt class="text-[10px] font-bold uppercase tracking-wider text-gray-400 dark:text-gray-500 mb-0.5">Address</dt>
                        <dd class="text-sm font-medium text-gray-700 dark:text-gray-300 truncate">
                          {{#if this.teamDetails.game_location.address}}
                            {{this.teamDetails.game_location.address}},
                          {{/if}}
                          {{this.teamDetails.game_location.city}}
                          {{#if this.teamDetails.game_location.country}},
                            {{this.teamDetails.game_location.country}}
                          {{/if}}
                        </dd>
                      </div>
                    </div>

                    {{! team_email }}
                    {{#if this.teamDetails.team_email}}
                      <div class="flex items-start gap-3 p-3 rounded-xl bg-gray-50 dark:bg-gray-800/60">
                        <div class="w-8 h-8 rounded-lg bg-fuchsia-100 dark:bg-fuchsia-900/30 flex items-center justify-center shrink-0">
                          {{! Icon: Mail }}
                          <svg
                            class="w-4 h-4 text-fuchsia-500"
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                            stroke-width="2"
                            stroke-linecap="round"
                            stroke-linejoin="round"
                          >
                            <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"></path>
                            <polyline points="22,6 12,13 2,6"></polyline>
                          </svg>
                        </div>
                        <div>
                          <dt class="text-[10px] font-bold uppercase tracking-wider text-gray-400 dark:text-gray-500 mb-0.5">Email</dt>
                          <dd class="text-sm font-medium text-gray-700 dark:text-gray-300">
                            {{this.teamDetails.team_email}}
                          </dd>
                        </div>
                      </div>
                    {{/if}}

                    {{! team_mobile }}
                    {{#if this.teamDetails.team_mobile}}
                      <div class="flex items-start gap-3 p-3 rounded-xl bg-gray-50 dark:bg-gray-800/60">
                        <div class="w-8 h-8 rounded-lg bg-blue-100 dark:bg-blue-900/30 flex items-center justify-center shrink-0">
                          {{! Icon: Smartphone }}
                          <svg
                            class="w-4 h-4 text-blue-500"
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                            stroke-width="2"
                            stroke-linecap="round"
                            stroke-linejoin="round"
                          >
                            <rect x="5" y="2" width="14" height="20" rx="2" ry="2"></rect>
                            <line x1="12" y1="18" x2="12.01" y2="18"></line>
                          </svg>
                        </div>
                        <div>
                          <dt class="text-[10px] font-bold uppercase tracking-wider text-gray-400 dark:text-gray-500 mb-0.5">Team mobile</dt>
                          <dd class="text-sm font-medium text-gray-700 dark:text-gray-300">
                            {{this.teamDetails.team_mobile}}
                          </dd>
                        </div>
                      </div>
                    {{/if}}

                    {{! team_owner / Captain / Vice / Scope (Using generic User/Trophy icons) }}
                    {{#if this.teamDetails.team_owner}}
                      <div class="flex items-start gap-3 p-3 rounded-xl bg-gray-50 dark:bg-gray-800/60">
                        <div class="w-8 h-8 rounded-lg bg-orange-100 dark:bg-orange-900/30 flex items-center justify-center shrink-0">
                          {{! Icon: Shield-Check (Owner) }}
                          <svg
                            class="w-4 h-4 text-orange-500"
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                            stroke-width="2"
                            stroke-linecap="round"
                            stroke-linejoin="round"
                          >
                            <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path>
                            <path d="m9 12 2 2 4-4"></path>
                          </svg>
                        </div>
                        <div>
                          <dt class="text-[10px] font-bold uppercase tracking-wider text-gray-400 dark:text-gray-500 mb-0.5">Team owner</dt>
                          <dd class="text-sm font-medium text-gray-700 dark:text-gray-300 capitalize">
                            {{this.teamDetails.team_owner}}
                          </dd>
                        </div>
                      </div>
                    {{/if}}
                  </dl>
                </div>
              </div>

              {{! Right sidebar }}
              <div class="space-y-6">

                {{! Sidebar ad slot 300×250 }}
                <div
                  class="rounded-2xl border-2 border-dashed border-gray-200 dark:border-gray-700/60 bg-gray-100/50 dark:bg-gray-800/30 flex flex-col items-center justify-center min-h-[250px]"
                >
                  <p class="text-[9px] font-bold tracking-[0.25em] uppercase text-gray-300 dark:text-gray-600 mb-1">Advertisement</p>
                  {{! ↓ Replace with your AdSense <ins> tag }}
                  <div id="team-details-sidebar-ad" class="text-gray-300 dark:text-gray-700 text-xs font-medium">
                    300 × 250 — Ad Slot
                  </div>
                </div>

              </div>
            </div>

            {{! ── TROPHIES ── }}
          {{else if (eq this.activeTab "trophies")}}
            <div class="rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-700/50 shadow-sm p-6 sm:p-8">
              <h3 class="flex items-center gap-2 text-base font-bold text-gray-900 dark:text-white mb-6">
                <span class="w-8 h-8 rounded-xl bg-amber-100 dark:bg-amber-900/40 flex items-center justify-center shrink-0">
                  <svg
                    class="w-4 h-4 text-amber-600 dark:text-amber-400"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  >
                    <polyline points="8 6 12 2 16 6" />
                    <line x1="12" y1="2" x2="12" y2="15" />
                    <path d="M20 12v8a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2v-8" />
                    <rect x="1" y="3" width="4" height="7" /><rect x="19" y="3" width="4" height="7" />
                  </svg>
                </span>
                Trophies & Honours
              </h3>
              {{#if this.hasTrophies}}
                <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                  {{#each this.teamDetails.trophies as |trophy|}}
                    <div class="p-4 rounded-xl border border-amber-100 dark:border-amber-800/40 bg-amber-50 dark:bg-amber-900/10">
                      <p class="font-semibold text-sm text-gray-900 dark:text-white">{{trophy}}</p>
                    </div>
                  {{/each}}
                </div>
              {{else}}
                <div class="flex flex-col items-center justify-center py-16 text-center">
                  <div class="w-16 h-16 mb-4 rounded-2xl bg-amber-100 dark:bg-amber-900/30 flex items-center justify-center">
                    <svg
                      class="w-8 h-8 text-amber-400"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="1.5"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    >
                      <polyline points="8 6 12 2 16 6" />
                      <line x1="12" y1="2" x2="12" y2="15" />
                      <path d="M20 12v8a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2v-8" />
                      <rect x="1" y="3" width="4" height="7" /><rect x="19" y="3" width="4" height="7" />
                    </svg>
                  </div>
                  <p class="text-base font-semibold text-gray-900 dark:text-white mb-1">No trophies yet</p>
                  <p class="text-sm text-gray-400 dark:text-gray-600">This team's trophy cabinet is empty.</p>
                </div>
              {{/if}}
            </div>

            {{! ── TEAMS ── }}
          {{else if (eq this.activeTab "teams")}}
            <div class="rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-700/50 shadow-sm p-6 sm:p-8">
              <h3 class="flex items-center gap-2 text-base font-bold text-gray-900 dark:text-white mb-6">
                <span class="w-8 h-8 rounded-xl bg-indigo-100 dark:bg-indigo-900/40 flex items-center justify-center shrink-0">
                  <svg
                    class="w-4 h-4 text-indigo-600 dark:text-indigo-400"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  >
                    <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                    <circle cx="9" cy="7" r="4" />
                    <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
                    <path d="M16 3.13a4 4 0 0 1 0 7.75" />
                  </svg>
                </span>
                Teams
              </h3>

              {{#if this.teamMembers.team_members.length}}
                <div class="space-y-6">
                  {{! Member List Grid }}
                  <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    {{#each this.teamMembers.team_members as |member|}}
                      <div
                        role="button"
                        {{on "click" (fn this.goToPlayer member.player_id)}}
                        class="flex items-center gap-4 p-4 rounded-xl border border-gray-100 dark:border-gray-800 bg-gray-50/50 dark:bg-gray-800/30 hover:bg-gray-100 dark:hover:bg-gray-800/60 transition-colors cursor-pointer"
                      >
                        <div class="relative">
                          <img
                            src={{getTeamLogo member.player_primary_pic}}
                            alt="{{member.PlayerName.first_name}}"
                            class="w-12 h-12 rounded-full object-cover border-2 border-white dark:border-gray-700 shadow-sm"
                          />
                          {{! Badge Logic }}
                          {{#if (eq member.player_id this.teamMembers.captain)}}
                            <span class="absolute -top-1 -right-1 bg-amber-500 text-white text-[10px] font-bold px-1.5 py-0.5 rounded-full shadow-sm">C</span>
                          {{else if (eq member.player_id this.teamMembers.vice_captain)}}
                            <span class="absolute -top-1 -right-1 bg-blue-500 text-white text-[10px] font-bold px-1.5 py-0.5 rounded-full shadow-sm">VC</span>
                          {{/if}}
                        </div>

                        <div class="flex-1 min-w-0">
                          <p class="text-sm font-semibold text-gray-900 dark:text-white truncate">
                            {{member.PlayerName.first_name}}
                            {{member.PlayerName.last_name}}
                          </p>
                          <div class="flex items-center gap-2">
                            <span class="text-xs text-gray-500 dark:text-gray-400">Order: {{member.playing_order}}</span>
                            {{#if member.pending}}
                              <span
                                class="inline-flex items-center px-1.5 py-0.5 rounded-md text-[10px] font-medium bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-500"
                              >
                                Pending
                              </span>
                            {{/if}}
                          </div>
                        </div>
                      </div>
                    {{/each}}
                  </div>
                </div>

              {{else}}
                {{! Empty State }}
                <div class="flex flex-col items-center justify-center py-16 text-center">
                  <div class="w-16 h-16 mb-4 rounded-2xl bg-indigo-100 dark:bg-indigo-900/30 flex items-center justify-center">
                    <svg
                      class="w-8 h-8 text-indigo-400"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="1.5"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    >
                      <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                      <circle cx="9" cy="7" r="4" />
                    </svg>
                  </div>
                  <p class="text-base font-semibold text-gray-900 dark:text-white mb-1">No teams yet</p>
                  <p class="text-sm text-gray-400 dark:text-gray-600">Teams will appear here once added.</p>
                </div>
              {{/if}}
            </div>

            {{! ── Schedule ── }}
          {{else if (eq this.activeTab "schedule")}}
            <div class="rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-700/50 shadow-sm p-6 sm:p-8">
              <h3 class="flex items-center gap-2 text-base font-bold text-gray-900 dark:text-white mb-6">
                Schedule
              </h3>

              {{#if this.isCalendarLoading}}
                <div class="py-16 text-center text-gray-500 dark:text-gray-400">Loading schedule...</div>
              {{else if this.calendarError}}
                <div class="py-16 text-center text-red-500">{{this.calendarError}}</div>
              {{else if (gt this.calendarData.length 0)}}
                <div class="space-y-6">
                  {{! Pass the games array to the component }}
                  <TeamCalendar @games={{this.calendarData}} />
                </div>
              {{else}}
                <div class="flex flex-col items-center justify-center py-16 text-center">
                  <p class="text-sm text-gray-400 dark:text-gray-500">No scheduled games found.</p>
                </div>
              {{/if}}
            </div>
          {{else if (eq this.activeTab "stats")}}
            <div class="rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-700/50 shadow-sm p-6 sm:p-8">
              {{! <TournamentTable /> }}
              <TournamentTable @stats={{this.teamDetails}} />
            </div>

            {{! ── LIVE MATCH ── }}
          {{else if (eq this.activeTab "matches")}}
            <div class="rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-700/50 shadow-sm p-6 sm:p-8">
              <h3 class="flex items-center gap-2 text-base font-bold text-gray-900 dark:text-white mb-6">
                Matches
              </h3>

              {{#if this.isCalendarLoading}}
                <div class="py-16 text-center text-gray-500 dark:text-gray-400">Loading matches...</div>
              {{else if this.calendarError}}
                <div class="py-16 text-center text-red-500">{{this.calendarError}}</div>
              {{else if (gt this.calendarData.length 0)}}
                <div class="space-y-6">
                  <TeamCalendar @games={{this.calendarData}} />
                </div>
              {{else}}
                <div class="flex flex-col items-center justify-center py-16 text-center">
                  <p class="text-sm text-gray-400 dark:text-gray-500">No matches found.</p>
                </div>
              {{/if}}
            </div>

            {{! ── PREVIOUS MATCH ── }}
          {{else if (eq this.activeTab "previous")}}
            <div class="rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-700/50 shadow-sm p-6 sm:p-8">
              {{! added for creating new pr }}
              <PreviousMatch
                @matches={{this.previousMatchData}}
                @teamId={{@model.team_id}}
                @isLoading={{this.isPreviousLoading}}
                @error={{this.previousMatchError}}
                @onRetry={{this.fetchPreviousMatches}}
              />
            </div>
            {{! ── ALL OTHER TABS (generic coming soon) ── }}
          {{else}}
            <div class="rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-700/50 shadow-sm p-6 sm:p-8">
              <div class="flex flex-col items-center justify-center py-16 text-center">
                <div
                  class="w-16 h-16 mb-4 rounded-2xl bg-gradient-to-br from-indigo-100 to-violet-100 dark:from-indigo-900/30 dark:to-violet-900/30 flex items-center justify-center"
                >
                  <svg
                    class="w-8 h-8 text-indigo-400"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="1.5"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  >
                    <circle cx="12" cy="12" r="10" />
                    <path d="M12 8v4m0 4h.01" />
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
