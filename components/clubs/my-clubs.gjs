import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { fn, array } from '@ember/helper';
import { eq } from 'ember-truth-helpers';
import { service } from '@ember/service';

const API_URL = 'https://spordiumapi.adnanfoundation.com/clubs/user-clubs/';

const SPORT_COLORS = [
  'bg-indigo-100 dark:bg-indigo-900/40 text-indigo-700 dark:text-indigo-300',
  'bg-violet-100 dark:bg-violet-900/40 text-violet-700 dark:text-violet-300',
  'bg-sky-100 dark:bg-sky-900/40 text-sky-700 dark:text-sky-300',
  'bg-emerald-100 dark:bg-emerald-900/40 text-emerald-700 dark:text-emerald-300',
  'bg-amber-100 dark:bg-amber-900/40 text-amber-700 dark:text-amber-300',
];

function resolveUrl(path) {
  if (!path) return null;
  if (path.startsWith('http')) return path;
  return `https://ag-khela.s3.ap-south-1.amazonaws.com/${path}`;
}

function clubTypePillClass(type) {
  if (!type) return 'bg-white/20 text-white';
  const t = type.toLowerCase();
  if (t.includes('professional') && !t.includes('semi')) return 'bg-indigo-700/80 text-white backdrop-blur-sm';
  if (t.includes('semi'))                                 return 'bg-violet-600/80 text-white backdrop-blur-sm';
  return 'bg-white/20 text-white backdrop-blur-sm';
}

// ══════════════════════════════════════════════════════════════════════════════
export default class MyClubs extends Component {
  @service session;
  @service router;

  @tracked clubs     = [];
  @tracked isLoading = true;
  @tracked error     = null;

  constructor(owner, args) {
    super(owner, args);
    this.fetchMyClubs();
  }

  async fetchMyClubs() {
    this.isLoading = true;
    this.error     = null;
    try {
      const res = await fetch(API_URL, {
        headers: {
          'Authorization': `Bearer ${this.session.token}`,
          'Accept':        'application/json',
        },
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json = await res.json();
      this.clubs  = Array.isArray(json) ? json : (json.data ?? json.results ?? []);
    } catch {
      this.error = 'Failed to load your clubs. Please try again.';
    } finally {
      this.isLoading = false;
    }
  }

  @action retry()    { this.fetchMyClubs(); }
  @action goCreate() { this.router.transitionTo('clubs.createclub'); }

  @action goToClub(clubId) {
    this.router.transitionTo('clubs.details', clubId);
  }

  get hasClubs() { return this.clubs.length > 0; }

  get processedClubs() {
    return this.clubs.map((club) => ({
      ...club,
      logoUrl:         resolveUrl(club.logo),
      coverUrl:        resolveUrl(club.cover_photo),
      establishedYear: club.established_date
        ? new Date(club.established_date).getFullYear()
        : null,
      typePillClass: clubTypePillClass(club.club_type),
      sportsWithColor: (club.sports ?? []).map((s, i) => ({
        name:  s,
        color: SPORT_COLORS[i % SPORT_COLORS.length],
      })),
    }));
  }

  get clubCount() { return this.clubs.length; }

  <template>
    <section class="min-h-screen bg-gray-50 dark:bg-gray-950">

      {{! ── Hero ── }}
      <div class="relative overflow-hidden
                  bg-gradient-to-br from-indigo-600 via-violet-600 to-fuchsia-600">
        {{! Decorative blobs }}
        <div class="absolute inset-0 pointer-events-none overflow-hidden" aria-hidden="true">
          <div class="absolute -top-20 -right-20 w-80 h-80 rounded-full bg-white/5 blur-3xl"></div>
          <div class="absolute bottom-0 -left-10 w-64 h-64 rounded-full bg-white/5 blur-2xl"></div>
          <div class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2
                      w-full h-32 bg-white/3 blur-3xl"></div>
        </div>

        <div class="relative px-4 sm:px-6 lg:px-8 pt-14 pb-36">
          <div class="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-6">

            <div>
              {{! Eyebrow chip }}
              <div class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full
                          bg-white/15 border border-white/25 backdrop-blur-sm
                          text-white text-xs font-semibold tracking-wide mb-4">
                <svg class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                     stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
                  <polyline points="9 22 9 12 15 12 15 22"/>
                </svg>
                Dashboard
              </div>
              <h1 class="text-4xl sm:text-5xl font-extrabold text-white
                         tracking-tight leading-none drop-shadow-sm">
                My Clubs
              </h1>
              <p class="mt-3 text-indigo-200 text-sm sm:text-base max-w-sm leading-relaxed">
                All the clubs you manage or belong to, in one place.
              </p>
            </div>

            {{! Create club CTA }}
            <button
              type="button"
              {{on "click" this.goCreate}}
              class="shrink-0 self-start sm:self-auto
                     inline-flex items-center gap-2.5
                     px-6 py-3 rounded-2xl
                     bg-white text-indigo-700 font-bold text-sm
                     shadow-2xl shadow-indigo-900/40
                     hover:bg-indigo-50 active:scale-95
                     transition-all duration-200">
              <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                   stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                <path d="M12 5v14"/><path d="M5 12h14"/>
              </svg>
              Create Club
            </button>
          </div>
        </div>
      </div>

      {{! ── Main content pulled over hero ── }}
      <div class="relative -mt-24 px-4 sm:px-6 lg:px-8 pb-16">

        {{! Loading skeleton }}
        {{#if this.isLoading}}
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-5">
            {{#each (array 1 2 3 4 5 6 7 8) as |_|}}
              <div class="rounded-3xl bg-white dark:bg-gray-900
                          border border-gray-100 dark:border-gray-800
                          shadow-lg overflow-hidden animate-pulse">
                <div class="h-32 bg-gradient-to-br from-gray-200 to-gray-300
                             dark:from-gray-700 dark:to-gray-800"></div>
                <div class="px-5 pt-10 pb-5 space-y-3">
                  <div class="h-5 w-3/4 bg-gray-200 dark:bg-gray-700 rounded-lg"></div>
                  <div class="h-3 w-1/2 bg-gray-100 dark:bg-gray-800 rounded-lg"></div>
                  <div class="flex gap-2 pt-2">
                    <div class="h-5 w-16 bg-gray-100 dark:bg-gray-800 rounded-full"></div>
                    <div class="h-5 w-14 bg-gray-100 dark:bg-gray-800 rounded-full"></div>
                  </div>
                </div>
              </div>
            {{/each}}
          </div>

        {{! Error state }}
        {{else if this.error}}
          <div class="flex flex-col items-center justify-center py-28 text-center">
            <div class="w-20 h-20 mb-5 rounded-3xl
                        bg-rose-100 dark:bg-rose-900/30
                        flex items-center justify-center shadow-inner">
              <svg class="w-9 h-9 text-rose-500" viewBox="0 0 24 24" fill="none"
                   stroke="currentColor" stroke-width="2"
                   stroke-linecap="round" stroke-linejoin="round">
                <circle cx="12" cy="12" r="10"/>
                <line x1="12" y1="8" x2="12" y2="12"/>
                <line x1="12" y1="16" x2="12.01" y2="16"/>
              </svg>
            </div>
            <p class="text-xl font-bold text-gray-900 dark:text-white mb-1">Something went wrong</p>
            <p class="text-sm text-gray-400 dark:text-gray-500 max-w-xs mb-6">{{this.error}}</p>
            <button
              type="button"
              {{on "click" this.retry}}
              class="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl
                     bg-indigo-600 hover:bg-indigo-500 active:bg-indigo-700
                     text-white text-sm font-semibold
                     shadow-md shadow-indigo-500/25
                     transition-all duration-200">
              <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                   stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                <path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/>
                <path d="M3 3v5h5"/>
              </svg>
              Try Again
            </button>
          </div>

        {{! Empty state }}
        {{else if (eq this.clubCount 0)}}
          <div class="flex flex-col items-center justify-center py-28 text-center">
            <div class="relative mb-7">
              <div class="w-28 h-28 rounded-3xl
                          bg-gradient-to-br from-indigo-100 to-violet-100
                          dark:from-indigo-900/40 dark:to-violet-900/40
                          flex items-center justify-center shadow-inner">
                <svg class="w-12 h-12 text-indigo-400 dark:text-indigo-500" viewBox="0 0 24 24"
                     fill="none" stroke="currentColor" stroke-width="1.5"
                     stroke-linecap="round" stroke-linejoin="round">
                  <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
                  <polyline points="9 22 9 12 15 12 15 22"/>
                </svg>
              </div>
              <div class="absolute -bottom-2 -right-2
                          w-9 h-9 rounded-xl
                          bg-gradient-to-br from-amber-400 to-orange-500
                          flex items-center justify-center shadow-lg">
                <svg class="w-4 h-4 text-white" viewBox="0 0 24 24" fill="none"
                     stroke="currentColor" stroke-width="2.5"
                     stroke-linecap="round" stroke-linejoin="round">
                  <path d="M12 5v14"/><path d="M5 12h14"/>
                </svg>
              </div>
            </div>

            <p class="text-2xl font-extrabold text-gray-900 dark:text-white tracking-tight mb-2">
              No clubs yet
            </p>
            <p class="text-sm text-gray-400 dark:text-gray-500 max-w-xs mb-8 leading-relaxed">
              You haven't created or joined any clubs. Start building your first one today!
            </p>

            <button
              type="button"
              {{on "click" this.goCreate}}
              class="inline-flex items-center gap-2.5 px-7 py-3.5 rounded-2xl font-bold text-sm
                     bg-gradient-to-r from-indigo-600 to-violet-600
                     hover:from-indigo-500 hover:to-violet-500
                     text-white
                     shadow-xl shadow-indigo-500/30
                     hover:shadow-2xl hover:shadow-indigo-500/40
                     active:scale-95 transition-all duration-200">
              <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                   stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                <path d="M12 5v14"/><path d="M5 12h14"/>
              </svg>
              Create Your First Club
            </button>
          </div>

        {{! Club cards }}
        {{else}}
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-5">
            {{#each this.processedClubs as |club|}}
              <button
                type="button"
                {{on "click" (fn this.goToClub club.club_id)}}
                class="group text-left rounded-3xl
                       bg-white dark:bg-gray-900
                       border border-gray-100 dark:border-gray-800
                       shadow-md
                       hover:shadow-2xl hover:shadow-indigo-500/10 dark:hover:shadow-indigo-900/30
                       hover:-translate-y-1.5
                       transition-all duration-300 overflow-hidden
                       focus:outline-none focus:ring-2 focus:ring-indigo-500
                       focus:ring-offset-2 dark:focus:ring-offset-gray-950">

                {{! Cover banner }}
                <div class="relative h-32 overflow-hidden
                             bg-gradient-to-br from-indigo-500 via-violet-600 to-fuchsia-600">
                  {{#if club.coverUrl}}
                    <img
                      src={{club.coverUrl}}
                      alt=""
                      class="w-full h-full object-cover
                             group-hover:scale-110 transition-transform duration-700 ease-out"
                    />
                    <div class="absolute inset-0 bg-gradient-to-t from-black/30 via-transparent to-transparent"></div>
                  {{else}}
                    {{! Pattern fallback }}
                    <div class="absolute inset-0 opacity-20" aria-hidden="true">
                      <div class="absolute -top-4 -left-4 w-28 h-28 rounded-full bg-white blur-2xl"></div>
                      <div class="absolute -bottom-4 -right-4 w-32 h-32 rounded-full bg-white blur-2xl"></div>
                    </div>
                  {{/if}}

                  {{! Club type badge }}
                  {{#if club.club_type}}
                    <span class="absolute top-2.5 right-2.5
                                 px-2.5 py-0.5 rounded-full
                                 text-[10px] font-bold tracking-wide
                                 {{club.typePillClass}}">
                      {{club.club_type}}
                    </span>
                  {{/if}}
                </div>

                {{! Body }}
                <div class="relative px-4 pb-4">

                  {{! Logo bubble }}
                  <div class="absolute -top-6 left-4
                              w-12 h-12 rounded-2xl shrink-0
                              ring-[3px] ring-white dark:ring-gray-900
                              shadow-lg overflow-hidden
                              bg-white dark:bg-gray-800
                              flex items-center justify-center">
                    {{#if club.logoUrl}}
                      <img src={{club.logoUrl}} alt={{club.name}} class="w-full h-full object-cover" />
                    {{else}}
                      <svg class="w-6 h-6 text-indigo-400" viewBox="0 0 24 24" fill="none"
                           stroke="currentColor" stroke-width="1.5"
                           stroke-linecap="round" stroke-linejoin="round">
                        <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
                        <polyline points="9 22 9 12 15 12 15 22"/>
                      </svg>
                    {{/if}}
                  </div>

                  {{! Text block }}
                  <div class="pt-8">
                    <h2 class="text-sm font-extrabold tracking-tight leading-snug
                               text-gray-900 dark:text-white truncate
                               group-hover:text-indigo-600 dark:group-hover:text-indigo-400
                               transition-colors duration-200">
                      {{club.name}}
                    </h2>

                    {{#if club.city}}
                      <p class="mt-0.5 flex items-center gap-1
                                 text-[11px] text-gray-400 dark:text-gray-500 truncate">
                        <svg class="w-3 h-3 shrink-0" viewBox="0 0 24 24" fill="none"
                             stroke="currentColor" stroke-width="2"
                             stroke-linecap="round" stroke-linejoin="round">
                          <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7z"/>
                          <circle cx="12" cy="9" r="2.5"/>
                        </svg>
                        {{club.city}}{{#if club.country}}, {{club.country}}{{/if}}
                      </p>
                    {{/if}}

                    {{! Sport badges }}
                    {{#if club.sportsWithColor.length}}
                      <div class="flex flex-wrap gap-1 mt-2.5">
                        {{#each club.sportsWithColor as |s|}}
                          <span class="px-2 py-0.5 rounded-full text-[10px] font-semibold {{s.color}}">
                            {{s.name}}
                          </span>
                        {{/each}}
                      </div>
                    {{/if}}

                    {{! Footer row }}
                    <div class="flex items-center justify-between mt-3.5 pt-3.5
                                border-t border-gray-100 dark:border-gray-800">
                      {{#if club.establishedYear}}
                        <span class="text-[10px] font-medium text-gray-400 dark:text-gray-600">
                          Est. {{club.establishedYear}}
                        </span>
                      {{else}}
                        <span></span>
                      {{/if}}

                      <span class="inline-flex items-center gap-1
                                   text-[11px] font-bold
                                   text-indigo-600 dark:text-indigo-400
                                   group-hover:gap-2 transition-all duration-200">
                        View
                        <svg class="w-3 h-3" viewBox="0 0 24 24" fill="none"
                             stroke="currentColor" stroke-width="2.5"
                             stroke-linecap="round" stroke-linejoin="round">
                          <path d="M5 12h14"/><path d="m12 5 7 7-7 7"/>
                        </svg>
                      </span>
                    </div>
                  </div>
                </div>
              </button>
            {{/each}}
          </div>

          {{! Count footer }}
          <p class="mt-8 text-center text-xs text-gray-400 dark:text-gray-600 font-medium tracking-wide">
            {{this.clubCount}} club{{#if (eq this.clubCount 1)}}{{else}}s{{/if}} found
          </p>
        {{/if}}

      </div>
    </section>
  </template>
}
