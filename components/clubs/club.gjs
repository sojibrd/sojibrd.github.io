import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { service } from '@ember/service';
import { LinkTo } from '@ember/routing';
// LinkTo is used in the template for route-based navigation
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { eq } from 'ember-truth-helpers';
import { getUserLocation } from '../../utils/utility.helper';
import Pagonation from '../pagonation';

const DEFAULT_LAT    = 23.79431617060116;
const DEFAULT_LONG   = 90.40723691635932;
const DEFAULT_COUNTRY = 'BD';
const PAGE_SIZE       = 10;

// ══════════════════════════════════════════════════════════════════════════════
export default class Club extends Component {
  @service session;
  @service router;

  @tracked clubs       = [];
  @tracked isLoading   = true;
  @tracked error       = null;
  @tracked activeTab   = 'all';
  @tracked searchQuery = '';
  @tracked currentPage = 1;

  constructor(owner, args) {
    super(owner, args);
    this.fetchClubs();
  }

  get filteredClubs() {
    const q = this.searchQuery.trim().toLowerCase();
    if (!q) return this.clubs;
    return this.clubs.filter(
      (c) => c.name?.toLowerCase().includes(q) || c.city?.toLowerCase().includes(q)
    );
  }

  get totalPages() {
    return Math.max(1, Math.ceil(this.filteredClubs.length / PAGE_SIZE));
  }

  get paginatedClubs() {
    const start = (this.currentPage - 1) * PAGE_SIZE;
    return this.filteredClubs.slice(start, start + PAGE_SIZE);
  }

  get isEmpty() {
    return !this.isLoading && !this.error && this.filteredClubs.length === 0;
  }

  get hasClubs() {
    return !this.isLoading && !this.error && this.filteredClubs.length > 0;
  }

  get skeletons() {
    return [1, 2, 3, 4, 5];
  }

  async fetchClubs() {
    this.isLoading = true;
    this.error     = null;

    let lat          = DEFAULT_LAT;
    let long         = DEFAULT_LONG;
    let country_code = DEFAULT_COUNTRY;

    try {
      const location = await getUserLocation();
      if (location.status && location.geo?.lat && location.geo?.long) {
        lat  = location.geo.lat;
        long = location.geo.long;
      }
    } catch {
      // fall through to defaults
    }

    try {
      const url = `https://spordiumapi.adnanfoundation.com/clubs/public-clubs/?country_code=${country_code}&lat=${lat}&long=${long}`;
      const res  = await fetch(url);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json = await res.json();
      this.clubs = json.data ?? [];
    } catch {
      this.error = 'Failed to load clubs. Please try again.';
    } finally {
      this.isLoading = false;
    }
  }

  @action
  retry() {
    this.fetchClubs();
  }

  @action
  setTab(tab) {
    this.activeTab   = tab;
    this.currentPage = 1;
  }

  @action
  updateSearch(event) {
    this.searchQuery = event.target.value;
    this.currentPage = 1;
  }

  @action
  goNext() {
    if (this.currentPage < this.totalPages) this.currentPage++;
  }

  @action
  goPrev() {
    if (this.currentPage > 1) this.currentPage--;
  }

  @action
  goToPage(page) {
    this.currentPage = page;
  }

  @action
  navigateToCreateClub() {
    if (this.session.isAuthenticated) {
      this.router.transitionTo('clubs.subscription');
    } else {
      this.router.transitionTo('login');
    }
  }

  @action
  openClub(clubId) {
    this.router.transitionTo('clubs.details', clubId);
  }

  <template>
    <section class="w-full px-4 py-8 sm:px-6 lg:px-8">
      {{! ── Sport tabs + search ── }}
      <div class="relative mb-6">
        {{! track underline }}
        <div class="absolute bottom-0 left-0 right-0 h-px bg-gray-200 dark:bg-gray-700"></div>

        <div class="flex items-center justify-between gap-4">
          <div class="flex items-center gap-1" role="tablist">

          {{! All }}
          <button
            type="button"
            role="tab"
            {{on "click" (fn this.setTab "all")}}
            class="relative flex items-center gap-2 px-4 py-2.5 text-sm font-semibold
                   transition-colors duration-200 focus:outline-none
                   {{if (eq this.activeTab 'all')
                     'text-indigo-600 dark:text-indigo-400'
                     'text-gray-500 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200'}}"
          >
            <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none"
                 stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <circle cx="12" cy="12" r="10"/>
              <path d="M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"/>
              <path d="M2 12h20"/>
            </svg>
            All
            {{#if (eq this.activeTab "all")}}
              <span class="absolute bottom-0 left-0 right-0 h-0.5 rounded-full bg-indigo-600 dark:bg-indigo-400"></span>
            {{/if}}
          </button>

          {{! Cricket }}
          <button
            type="button"
            role="tab"
            {{on "click" (fn this.setTab "cricket")}}
            class="relative flex items-center gap-2 px-4 py-2.5 text-sm font-semibold
                   transition-colors duration-200 focus:outline-none
                   {{if (eq this.activeTab 'cricket')
                     'text-indigo-600 dark:text-indigo-400'
                     'text-gray-500 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200'}}"
          >
            <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none"
                 stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <ellipse cx="12" cy="12" rx="10" ry="10"/>
              <path d="M5 5l14 14"/>
              <path d="M19 5L5 19"/>
            </svg>
            Cricket
            {{#if (eq this.activeTab "cricket")}}
              <span class="absolute bottom-0 left-0 right-0 h-0.5 rounded-full bg-indigo-600 dark:bg-indigo-400"></span>
            {{/if}}
          </button>

          {{! Football }}
          <button
            type="button"
            role="tab"
            {{on "click" (fn this.setTab "football")}}
            class="relative flex items-center gap-2 px-4 py-2.5 text-sm font-semibold
                   transition-colors duration-200 focus:outline-none
                   {{if (eq this.activeTab 'football')
                     'text-indigo-600 dark:text-indigo-400'
                     'text-gray-500 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200'}}"
          >
            <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none"
                 stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <circle cx="12" cy="12" r="10"/>
              <path d="M12 2c0 0-3 4-3 10s3 10 3 10"/>
              <path d="M2 12h20"/>
              <path d="M4.93 4.93l4.24 4.24"/>
              <path d="M14.83 14.83l4.24 4.24"/>
              <path d="M4.93 19.07l4.24-4.24"/>
              <path d="M14.83 9.17l4.24-4.24"/>
            </svg>
            Football
            {{#if (eq this.activeTab "football")}}
              <span class="absolute bottom-0 left-0 right-0 h-0.5 rounded-full bg-indigo-600 dark:bg-indigo-400"></span>
            {{/if}}
          </button>

          </div>

          {{! ── Right side: search + auth buttons ── }}
          <div class="flex items-center gap-2 pb-1 shrink-0">

            {{! Search input }}
            <div class="relative">
              <div class="pointer-events-none absolute inset-y-0 left-3 flex items-center">
                <svg class="w-3.5 h-3.5 text-gray-400" viewBox="0 0 24 24" fill="none"
                     stroke="currentColor" stroke-width="2.5"
                     stroke-linecap="round" stroke-linejoin="round">
                  <circle cx="11" cy="11" r="8"/>
                  <path d="M21 21l-4.35-4.35"/>
                </svg>
              </div>
              <input
                type="search"
                placeholder="Search clubs…"
                value={{this.searchQuery}}
                {{on "input" this.updateSearch}}
                class="w-40 sm:w-48 pl-8 pr-3 py-1.5 text-sm
                       rounded-lg border border-gray-200 dark:border-gray-700
                       bg-gray-50 dark:bg-gray-800
                       text-gray-900 dark:text-gray-100
                       placeholder:text-gray-400 dark:placeholder:text-gray-500
                       focus:outline-none focus:ring-2 focus:ring-indigo-400/60 focus:border-indigo-400
                       dark:focus:ring-indigo-500/40 dark:focus:border-indigo-500
                       transition-all duration-200"
              />
            </div>




              {{! Create Club → /clubs/subscription (auth-gated) }}
              <button
                type="button"
                {{on "click" this.navigateToCreateClub}}
                class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-semibold
                       bg-indigo-600 hover:bg-indigo-500 active:bg-indigo-700
                       text-white shadow-sm shadow-indigo-500/25
                       transition-all duration-150
                       focus:outline-none focus:ring-2 focus:ring-indigo-400 focus:ring-offset-1
                       dark:focus:ring-offset-gray-900"
              >
                <svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none"
                     stroke="currentColor" stroke-width="2.5"
                     stroke-linecap="round" stroke-linejoin="round">
                  <path d="M12 5v14M5 12h14"/>
                </svg>
                <span class="hidden sm:inline">Create Club</span>
                <span class="sm:hidden">Create</span>
              </button>
            {{! Auth-only actions }}
            {{#if this.session.isAuthenticated}}
              {{! My Club → /clubs/myclubs }}
              <LinkTo
                @route="clubs.myclubs"
                class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-semibold
                       bg-white dark:bg-gray-800
                       border border-indigo-200 dark:border-indigo-700/60
                       text-indigo-600 dark:text-indigo-400
                       hover:bg-indigo-50 dark:hover:bg-indigo-900/20
                       hover:border-indigo-300 dark:hover:border-indigo-500
                       shadow-sm
                       transition-all duration-150
                       focus:outline-none focus:ring-2 focus:ring-indigo-400 focus:ring-offset-1
                       dark:focus:ring-offset-gray-900"
              >
                <svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none"
                     stroke="currentColor" stroke-width="2.5"
                     stroke-linecap="round" stroke-linejoin="round">
                  <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
                  <polyline points="9 22 9 12 15 12 15 22"/>
                </svg>
                <span class="hidden sm:inline">My Club</span>
                <span class="sm:hidden">Mine</span>
              </LinkTo>

            {{/if}}
          </div>

        </div>
      </div>

      {{! ── Loading skeleton grid ── }}
      {{#if this.isLoading}}
        <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-4 sm:gap-6">
          {{#each this.skeletons as |_|}}
            <div
              class="rounded-2xl
                     bg-white dark:bg-gray-900
                     border border-gray-100 dark:border-gray-700/50
                     shadow-md animate-pulse"
            >
              {{! banner }}
              <div class="h-28 rounded-t-2xl bg-gradient-to-br from-gray-200 to-gray-300 dark:from-gray-700 dark:to-gray-600"></div>
              {{! body }}
              <div class="px-4 pb-5">
                <div class="flex justify-center -mt-9 mb-3">
                  <div class="w-[68px] h-[68px] rounded-2xl bg-gray-300 dark:bg-gray-600 border-[3px] border-white dark:border-gray-900"></div>
                </div>
                <div class="h-4 bg-gray-300 dark:bg-gray-600 rounded-full w-3/4 mx-auto mb-2"></div>
                <div class="h-3 bg-gray-200 dark:bg-gray-700 rounded-full w-1/2 mx-auto mb-4"></div>
                <div class="h-px bg-gray-200 dark:bg-gray-700 mb-4"></div>
                <div class="grid grid-cols-3 gap-2">
                  <div class="h-10 rounded-xl bg-gray-200 dark:bg-gray-700"></div>
                  <div class="h-10 rounded-xl bg-gray-200 dark:bg-gray-700"></div>
                  <div class="h-10 rounded-xl bg-gray-200 dark:bg-gray-700"></div>
                </div>
              </div>
            </div>
          {{/each}}
        </div>

      {{! ── Error state ── }}
      {{else if this.error}}
        <div class="flex flex-col items-center justify-center py-20 text-center">
          <div class="w-16 h-16 mb-4 rounded-2xl
                      bg-rose-100 dark:bg-rose-900/30
                      flex items-center justify-center">
            <svg class="w-8 h-8 text-rose-500" viewBox="0 0 24 24" fill="none"
                 stroke="currentColor" stroke-width="2"
                 stroke-linecap="round" stroke-linejoin="round">
              <path d="M12 2a10 10 0 1 0 0 20A10 10 0 0 0 12 2z"/>
              <path d="M12 8v4"/>
              <path d="M12 16h.01"/>
            </svg>
          </div>
          <p class="text-base font-semibold text-gray-900 dark:text-white mb-1">Something went wrong</p>
          <p class="text-sm text-gray-500 dark:text-gray-400">{{this.error}}</p>
        </div>

      {{! ── Empty state ── }}
      {{else if this.isEmpty}}
        <div class="flex flex-col items-center justify-center py-20 text-center">
          <div class="w-16 h-16 mb-4 rounded-2xl
                      bg-indigo-100 dark:bg-indigo-900/30
                      flex items-center justify-center">
            <svg class="w-8 h-8 text-indigo-400" viewBox="0 0 24 24" fill="none"
                 stroke="currentColor" stroke-width="1.5"
                 stroke-linecap="round" stroke-linejoin="round">
              <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
              <circle cx="9" cy="7" r="4"/>
              <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
              <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
            </svg>
          </div>
          <p class="text-base font-semibold text-gray-900 dark:text-white mb-1">No clubs found</p>
          <p class="text-sm text-gray-500 dark:text-gray-400">Try expanding your search area.</p>
        </div>

      {{! ── Club grid ── }}
      {{else if this.hasClubs}}
        <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-4 sm:gap-6">
          {{#each this.paginatedClubs as |club|}}

            {{! card — no overflow-hidden so the logo can bleed above the banner }}
            <div
              role="button"
              tabindex="0"
              {{on "click" (fn this.openClub club.club_id)}}
              class="group relative rounded-2xl
                     bg-white dark:bg-gray-900
                     border border-gray-100 dark:border-gray-700/50
                     shadow-md hover:shadow-2xl hover:shadow-indigo-500/10
                     transition-all duration-300 ease-out
                     hover:-translate-y-2 cursor-pointer"
            >
              {{! ── Banner — overflow-hidden only here ── }}
              <div
                class="relative h-28 rounded-t-2xl overflow-hidden
                       bg-gradient-to-br
                       from-indigo-500 via-violet-500 to-fuchsia-500
                       dark:from-indigo-700 dark:via-violet-700 dark:to-fuchsia-700"
              >
                {{! dot-grid texture }}
                <div
                  class="absolute inset-0 opacity-[0.18]"
                  style="background-image: radial-gradient(circle, white 1px, transparent 1px); background-size: 16px 16px;"
                ></div>

                {{! shine sweep on hover }}
                <div
                  class="absolute inset-0 -translate-x-full group-hover:translate-x-full
                         bg-gradient-to-r from-transparent via-white/25 to-transparent
                         transition-transform duration-700 ease-in-out"
                ></div>

                {{! Rank badge }}
                {{#if club.rank_in_country}}
                  <span
                    class="absolute top-2.5 right-3
                           inline-flex items-center gap-0.5
                           px-2 py-0.5 rounded-full
                           text-[10px] font-bold tracking-widest
                           bg-black/20 backdrop-blur-sm
                           text-white border border-white/20"
                  >
                    #{{club.rank_in_country}}
                  </span>
                {{/if}}
              </div>

              {{! ── Card body ── }}
              <div class="px-4 pb-5">

                {{! Logo — floats above the banner; z-10 keeps it above the banner }}
                <div class="relative z-10 flex justify-center -mt-9 mb-3">
                  <div
                    class="w-[68px] h-[68px] rounded-2xl
                           border-[3px] border-white dark:border-gray-900
                           shadow-lg overflow-hidden
                           bg-white dark:bg-gray-700
                           ring-2 ring-indigo-300/50 dark:ring-indigo-500/40
                           group-hover:ring-4 group-hover:ring-indigo-400/70 dark:group-hover:ring-indigo-400/50
                           group-hover:scale-105
                           transition-all duration-300"
                  >
                    <img
                      src={{club.logo}}
                      alt={{club.name}}
                      class="w-full h-full object-cover"
                    />
                  </div>
                </div>

                {{! Club name }}
                <h3
                  class="text-center font-extrabold text-[15px] leading-snug
                         text-gray-900 dark:text-white
                         group-hover:text-indigo-600 dark:group-hover:text-indigo-400
                         transition-colors duration-200
                         truncate"
                  title={{club.name}}
                >
                  {{club.name}}
                </h3>

                {{! City }}
                <div class="flex items-center justify-center gap-1 mt-1 mb-4">
                  <svg class="w-3 h-3 text-violet-400 shrink-0"
                       viewBox="0 0 24 24" fill="none" stroke="currentColor"
                       stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7z"/>
                    <circle cx="12" cy="9" r="2.5"/>
                  </svg>
                  <span class="text-[11px] font-medium text-gray-400 dark:text-gray-500 truncate">
                    {{club.city}}
                  </span>
                </div>

                {{! Divider }}
                <div class="h-px bg-gradient-to-r from-transparent via-gray-200 dark:via-gray-700 to-transparent mb-4"></div>

                {{! Stats row: Wins / Losses / Points }}
                <div class="grid grid-cols-3 gap-2">

                  <div class="flex flex-col items-center py-2 rounded-xl
                              bg-emerald-50 dark:bg-emerald-900/20
                              border border-emerald-100 dark:border-emerald-800/40">
                    <span class="text-[9px] font-bold tracking-widest uppercase
                                 text-emerald-500 dark:text-emerald-400 mb-0.5">
                      WIN
                    </span>
                    <span class="text-sm font-extrabold text-emerald-700 dark:text-emerald-300 leading-none">
                      {{#if club.wins}}{{club.wins}}{{else}}—{{/if}}
                    </span>
                  </div>

                  <div class="flex flex-col items-center py-2 rounded-xl
                              bg-rose-50 dark:bg-rose-900/20
                              border border-rose-100 dark:border-rose-800/40">
                    <span class="text-[9px] font-bold tracking-widest uppercase
                                 text-rose-500 dark:text-rose-400 mb-0.5">
                      LOSS
                    </span>
                    <span class="text-sm font-extrabold text-rose-600 dark:text-rose-300 leading-none">
                      {{#if club.loss}}{{club.loss}}{{else}}—{{/if}}
                    </span>
                  </div>

                  <div class="flex flex-col items-center py-2 rounded-xl
                              bg-amber-50 dark:bg-amber-900/20
                              border border-amber-100 dark:border-amber-800/40">
                    <span class="text-[9px] font-bold tracking-widest uppercase
                                 text-amber-500 dark:text-amber-400 mb-0.5">
                      PTS
                    </span>
                    <span class="text-sm font-extrabold text-amber-700 dark:text-amber-300 leading-none">
                      {{#if club.points}}{{club.points}}{{else}}—{{/if}}
                    </span>
                  </div>

                </div>
              </div>
            </div>
          {{/each}}
        </div>

        <Pagonation
          @currentPage={{this.currentPage}}
          @totalPages={{this.totalPages}}
          @onNextClick={{this.goNext}}
          @onPreviousClick={{this.goPrev}}
          @onPageIndexClick={{this.goToPage}}
        />
      {{/if}}

    </section>
  </template>
}
