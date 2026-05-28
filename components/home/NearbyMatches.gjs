import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { service } from '@ember/service';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { LinkTo } from '@ember/routing';
import config from 'spordium/config/environment';
import NearbyMatchCard from './NearbyMatchCard';

const LIMIT       = 2;
const S3          = config.APP.S3_BUCKET_URL;
const DEFAULT_LAT = 23.7805462;
const DEFAULT_LNG = 90.4266584;

function logoUrl(path) {
  if (!path) return null;
  if (path.startsWith('http')) return path;
  return `${S3}/${path}`;
}

function initial(name) {
  return (name?.[0] || '?').toUpperCase();
}

function fromHome(m) {
  const t1 = m.score?.batting?.team_name  || 'Team A';
  const t2 = m.score?.fielding?.team_name || 'Team B';
  return {
    id:         m.game_id,
    name:       `${t1} vs ${t2}`,
    datetime:   m.datetime,
    matchType:  m.match_type ?? 'tournament',
    sportType:  m.sportstype ?? m.sport_type ?? '',
    isLive:     m.is_start    === true,
    isFinished: m.is_finished === true,
    team1:   { name: t1, logo: logoUrl(m.score?.batting?.team_logo),  initial: initial(t1) },
    team2:   { name: t2, logo: logoUrl(m.score?.fielding?.team_logo), initial: initial(t2) },
    batting: {
      livescore: m.score?.batting?.livescore    ?? null,
      wickets:   m.score?.batting?.wicketstaken ?? null,
      balls:     m.score?.batting?.balls        ?? null,
    },
    fielding: {
      livescore: m.score?.fielding?.livescore ?? null,
    },
  };
}

export default class NearbyMatchesComponent extends Component {
  @service geolocation;
  @service api;

  @tracked matches          = [];
  @tracked label            = '';
  @tracked isLive           = false;
  @tracked isLoading        = true;
  @tracked hasError         = false;
  @tracked _openShareId     = null;

  @action onShareMenuChange(matchId, isOpen) {
    this._openShareId = isOpen ? matchId : null;
  }

  _pollTimer = null;

  constructor() {
    super(...arguments);
    this.load();
    this._pollTimer = setInterval(() => this.load(), 60_000);
  }

  willDestroy() {
    super.willDestroy();
    clearInterval(this._pollTimer);
  }

  async _homeGet(endpoint, params) {
    try {
      const result = await this.api.get(endpoint, params);
      return (result?.data ?? []).map(fromHome);
    } catch {
      return [];
    }
  }

  @action
  async load() {
    this.isLoading = true;
    this.hasError  = false;
    this.matches   = [];

    try {
      let latitude  = DEFAULT_LAT;
      let longitude = DEFAULT_LNG;

      try {
        const coords = await this.geolocation.getCoords();
        latitude  = coords.latitude;
        longitude = coords.longitude;
      } catch {
        // location unavailable — use Banani default
      }

      const data = await this._homeGet('/home/nearest_location_live/', {
        latitude, longitude, limit: LIMIT,
      });

      this.matches = data;
      this.isLive  = data.some((m) => m.isLive);
      this.label   = data.length ? 'Live Near By Me' : 'No Matches';

    } catch {
      this.hasError = true;
    } finally {
      this.isLoading = false;
    }
  }

  <template>
    <div class="w-full rounded-2xl flex flex-col
                bg-gradient-to-br from-white/[0.11] via-white/[0.07] to-white/[0.03]
                backdrop-blur-md
                border border-white/[0.14]
                shadow-[0_4px_24px_rgba(0,0,0,0.30),inset_0_1px_0_rgba(255,255,255,0.10)]
                {{if this._openShareId 'relative z-50' 'relative'}}">

      {{! Header }}
      <LinkTo @route="match.index"
        class="flex items-center justify-between px-4 py-3.5 rounded-t-2xl
               hover:bg-white/[0.04] transition-colors cursor-pointer flex-shrink-0 no-underline">
        <div class="flex items-center gap-2.5">
          {{#if this.isLoading}}
            <div class="w-2 h-2 rounded-full bg-white/20 animate-pulse"></div>
            <div class="h-3.5 w-24 rounded bg-white/10 animate-pulse"></div>
          {{else if this.isLive}}
            <span class="relative flex h-2 w-2">
              <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
              <span class="relative inline-flex rounded-full h-2 w-2 bg-emerald-400"></span>
            </span>
            <span class="text-sm font-bold text-white">{{this.label}}</span>
          {{else}}
            <span class="w-2 h-2 rounded-full bg-sky-400 flex-shrink-0"></span>
            <span class="text-sm font-bold text-white">{{this.label}}</span>
          {{/if}}
        </div>
        <svg class="w-4 h-4 text-white/30 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7"/>
        </svg>
      </LinkTo>

      <div class="h-px bg-white/[0.06] flex-shrink-0"></div>

      {{! Body }}
      <div class="flex flex-col flex-1 p-3 gap-2">

        {{! Loading skeletons }}
        {{#if this.isLoading}}
          <div class="rounded-xl bg-white/[0.05] border border-white/[0.06] px-4 py-3 animate-pulse">
            <div class="flex items-center justify-between mb-2.5">
              <div class="h-3 w-12 rounded bg-white/10"></div>
              <div class="h-3 w-28 rounded bg-white/10"></div>
            </div>
            <div class="flex items-center gap-2">
              <div class="flex items-center gap-2 flex-1">
                <div class="w-7 h-7 rounded-full bg-white/10 flex-shrink-0"></div>
                <div class="h-3 w-20 rounded bg-white/10"></div>
              </div>
              <div class="h-3 w-5 rounded bg-white/10 flex-shrink-0"></div>
              <div class="flex items-center gap-2 flex-1 justify-end">
                <div class="h-3 w-20 rounded bg-white/10"></div>
                <div class="w-7 h-7 rounded-full bg-white/10 flex-shrink-0"></div>
              </div>
            </div>
          </div>
          <div class="rounded-xl bg-white/[0.05] border border-white/[0.06] px-4 py-3 animate-pulse">
            <div class="flex items-center justify-between mb-2.5">
              <div class="h-3 w-12 rounded bg-white/10"></div>
              <div class="h-3 w-28 rounded bg-white/10"></div>
            </div>
            <div class="flex items-center gap-2">
              <div class="flex items-center gap-2 flex-1">
                <div class="w-7 h-7 rounded-full bg-white/10 flex-shrink-0"></div>
                <div class="h-3 w-20 rounded bg-white/10"></div>
              </div>
              <div class="h-3 w-5 rounded bg-white/10 flex-shrink-0"></div>
              <div class="flex items-center gap-2 flex-1 justify-end">
                <div class="h-3 w-20 rounded bg-white/10"></div>
                <div class="w-7 h-7 rounded-full bg-white/10 flex-shrink-0"></div>
              </div>
            </div>
          </div>

        {{! Error }}
        {{else if this.hasError}}
          <div class="flex flex-col items-center justify-center py-8 gap-2 text-center">
            <svg class="w-7 h-7 text-white/20" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9.303 3.376c.866 1.5-.217 3.374-1.948 3.374H4.645c-1.73 0-2.813-1.874-1.948-3.374L10.05 3.378c.866-1.5 3.032-1.5 3.898 0l7.355 12.748zM12 15.75h.008v.008H12v-.008z"/>
            </svg>
            <p class="text-[11px] text-white/40">Could not load matches</p>
            <button type="button" {{on "click" this.load}}
              class="text-[11px] text-white/50 hover:text-white underline transition-colors mt-1">
              Retry
            </button>
          </div>

        {{! Match cards }}
        {{else if this.matches.length}}
          {{#each this.matches as |match|}}
            <NearbyMatchCard
              @match={{match}}
              @openShareId={{this._openShareId}}
              @onShareMenuChange={{fn this.onShareMenuChange match.id}}
            />
          {{/each}}

        {{! Empty }}
        {{else}}
          <div class="flex flex-col items-center justify-center py-8 gap-2 text-center">
            <svg class="w-7 h-7 text-white/20" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z"/>
            </svg>
            <p class="text-[11px] text-white/40">No matches right now</p>
          </div>
        {{/if}}

      </div>
    </div>
  </template>
}
