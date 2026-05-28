import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { service } from '@ember/service';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { eq, not } from 'ember-truth-helpers';
import config from 'spordium/config/environment';

const SEARCH_API = config.APP.SEARCH_API_HOST;
const API_HOST = config.APP.API_HOST;
const IMAGE_BASE = config.APP.S3_BUCKET_URL;

function tournamentLogo(path) {
  if (!path) return null;
  return `${IMAGE_BASE}/${path}`;
}

function formatLocation(loc) {
  if (!loc) return null;
  if (typeof loc === 'string') return loc;
  return [loc.city, loc.district, loc.country].filter(Boolean).join(', ') || null;
}

function formatDate(dateStr) {
  if (!dateStr) return 'TBA';
  return new Date(dateStr).toLocaleDateString('en-GB', {
    day: 'numeric',
    month: 'short',
  });
}

export default class YourTournamentsWidget extends Component {
  @service session;
  @service router;

  @tracked tournaments = [];
  @tracked isLoading = false;
  @tracked error = null;

  constructor(owner, args) {
    super(owner, args);
    this.loadTournaments();
  }

  get isAuthenticated() {
    return !!this.session.currentUser;
  }

  get userId() {
    return this.session.currentUser?.user_id;
  }

  async loadTournaments() {
    this.isLoading = true;
    this.error = null;
    try {
      let res;
      if (this.isAuthenticated) {
        res = await fetch(
          `${API_HOST}/tournament_v2/get-tournaments-by-owner/?tournament_owner=${this.userId}&country_code=BD&limit=10&offset=0`,
          {
            headers: {
              Authorization: `Bearer ${this.session.token}`,
              Accept: 'application/json',
            },
          },
        );
      } else {
        res = await fetch(
          `${SEARCH_API}/search/upcomming-tournament-search_v2/?longitude=90.4048701&latitude=23.7768744&offset=0&limit=10&country_code=BD`,
        );
      }
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json = await res.json();
      this.tournaments = (json.data?.results ?? json.results ?? json.data ?? []).slice(0, 2);
    } catch {
      this.error = true;
    } finally {
      this.isLoading = false;
    }
  }

  @action
  openTournament(_tournament) {
    // tournament route is currently disabled
  }

  <template>
    <div class="relative w-72 rounded-2xl overflow-hidden shadow-2xl select-none bg-white/10 backdrop-blur-md border border-white/20">

      {{! Header }}
      <div class="flex items-center justify-between px-4 pt-4 pb-3">
        <span class="text-[15px] font-bold text-white tracking-tight">
          {{#if this.isAuthenticated}}Your&nbsp;&nbsp;Matches{{else}}Matches{{/if}}
        </span>
        <div class="p-1 rounded-full text-white/20">
          <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7"/>
          </svg>
        </div>
      </div>

      {{! Body }}
      <div class="px-4 pb-4 space-y-2.5 min-h-[120px]">

        {{! Loading }}
        {{#if this.isLoading}}
          <div class="space-y-2.5">
            <div class="h-16 rounded-xl bg-white/10 animate-pulse"></div>
            <div class="h-16 rounded-xl bg-white/10 animate-pulse"></div>
          </div>

        {{! Error }}
        {{else if this.error}}
          <div class="flex flex-col items-center justify-center py-6 gap-2">
            <p class="text-xs text-red-300">Failed to load tournaments</p>
            <button type="button" {{on "click" this.loadTournaments}} class="text-xs text-white/60 hover:text-white underline transition-colors">
              Retry
            </button>
          </div>

        {{! Empty }}
        {{else if (not this.tournaments.length)}}
          <div class="flex flex-col items-center justify-center py-6 gap-2 text-center">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-7 h-7 text-white/30" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
            </svg>
            <p class="text-xs text-white/50">No tournaments yet</p>
            <span class="mt-1 px-3 py-1.5 rounded-lg bg-blue-600/40 text-white/40 text-xs font-semibold cursor-not-allowed">
              Create Match
            </span>
          </div>

        {{! Tournament cards }}
        {{else}}
          {{#each this.tournaments as |t|}}
            <button
              type="button"
              {{on "click" (fn this.openTournament t)}}
              class="group w-full text-left rounded-2xl overflow-hidden border border-white/10 hover:border-white/20 transition-all duration-200"
            >
              {{! Banner }}
              <div class="relative h-16 overflow-hidden bg-white/8">
                {{#if (tournamentLogo t.tournament_logo)}}
                  <img src={{tournamentLogo t.tournament_logo}} alt="" class="w-full h-full object-cover" />
                {{else}}
                  {{! Placeholder pattern }}
                  <div class="w-full h-full flex items-center justify-center">
                    <svg xmlns="http://www.w3.org/2000/svg" class="w-8 h-8 text-white/15" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M5 3v4M3 5h4M6 17v4m-2-2h4m5-16l2.286 6.857L21 12l-5.714 2.143L13 21l-2.286-6.857L5 12l5.714-2.143L13 3z"/>
                    </svg>
                  </div>
                {{/if}}
                {{! Bottom gradient for text readability }}
                <div class="absolute inset-x-0 bottom-0 h-12 bg-gradient-to-t from-black/60 to-transparent"></div>
                {{! Name overlay }}
                <div class="absolute inset-x-0 bottom-0 px-3 pb-2">
                  <p class="text-sm font-semibold text-white truncate leading-tight drop-shadow">{{t.tournament_name}}</p>
                </div>
                {{! Status badge }}
                {{#if t.tournament_status}}
                  <div class="absolute top-2 right-2">
                    <span class="text-[9px] font-bold uppercase tracking-wider px-1.5 py-0.5 rounded-full
                      {{if (eq t.tournament_status 'live') 'bg-green-500/40 text-green-200'
                        (if (eq t.tournament_status 'upcoming') 'bg-black/40 text-white/80'
                          'bg-black/30 text-white/50')}}">
                      {{t.tournament_status}}
                    </span>
                  </div>
                {{/if}}
              </div>

              {{! Card body }}
              <div class="px-3 py-2">
                <div class="flex items-center justify-between text-[10px] text-white/50">
                  <div class="flex items-center gap-0.5">
                    <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/></svg>
                    &nbsp;{{formatDate t.tournament_start_date}}
                  </div>
                  <div class="flex items-center gap-0.5">
                    <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0"/></svg>
                    &nbsp;{{t.tournament_paid_number_of_teams}} teams
                  </div>
                  {{#if (formatLocation t.tournament_location)}}
                    <div class="flex items-center gap-0.5 truncate max-w-[90px]">
                      <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/><path stroke-linecap="round" stroke-linejoin="round" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/></svg>
                      &nbsp;<span class="truncate">{{formatLocation t.tournament_location}}</span>
                    </div>
                  {{/if}}
                </div>
              </div>
            </button>
          {{/each}}

        {{/if}}

      </div>
    </div>
  </template>
}
