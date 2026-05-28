import Component from '@glimmer/component';
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import { modifier } from 'ember-modifier';
import config from 'spordium/config/environment';
import PlayerCard from './PlayerCard';
import { LinkTo } from '@ember/routing';
import { getUserLocation, onInit } from '../../utils/utility.helper';

const BASE      = config.APP.SEARCH_API_HOST;
const S3        = config.APP.S3_BUCKET_URL;
const LIMIT     = 10;
const SKELETONS = [1, 2, 3];

// Per-endpoint cache so each PlayerList instance maintains separate data
const playerCaches = new Map();

function getOrCreateCache(endpoint) {
  if (!playerCaches.has(endpoint)) {
    playerCaches.set(endpoint, { players: null, nextCursor: null, rankOffset: 0, hasMore: true });
  }
  return playerCaches.get(endpoint);
}

// Country code resolved once and cached for 10 minutes
let _countryCode     = null;
let _countryCodeTs   = 0;
const COUNTRY_TTL    = 10 * 60 * 1000;

async function getCountryCode(lat, long) {
  if (_countryCode && Date.now() - _countryCodeTs < COUNTRY_TTL) {
    return _countryCode;
  }
  try {
    const key = config.APP.GOOGLE_MAPS_API_KEY;
    const url = `https://maps.googleapis.com/maps/api/geocode/json?latlng=${lat},${long}&result_type=country&key=${key}`;
    const res = await fetch(url);
    if (res.ok) {
      const data = await res.json();
      const comp = data.results?.[0]?.address_components?.find(c => c.types.includes('country'));
      _countryCode   = comp?.short_name ?? 'BD';
      _countryCodeTs = Date.now();
      return _countryCode;
    }
  } catch {
    // fall through to default
  }
  return 'BD';
}

function transformPlayer(player, index) {
  const first = player.player_fullname?.first_name?.trim() ?? '';
  const last  = player.player_fullname?.last_name?.trim()  ?? '';
  return {
    avatarUrl:  `${S3}/${player.player_primary_pic}`,
    name:       [first, last].filter(Boolean).join(' ') || player.user_username || '—',
    username:   player.user_username,
    position:   player.skills?.[0] ?? 'N/A',
    statLabel:  '',
    statValue:  player.bowling_strike_rate != null ? String(player.bowling_strike_rate) : '—',
    rank:       index + 1,
  };
}

export default class PlayerList extends Component {
  @tracked players       = [];
  @tracked isLoading     = true;
  @tracked isLoadingMore = false;
  @tracked error         = null;
  @tracked hasMore       = true;

  nextCursor  = null;
  rankOffset  = 0;

  get endpoint() {
    const title = this.args.title ?? '';
    if (title.includes('District')) return '/search/top-players-district/';
    if (title.includes('Country'))  return '/search/top-players-in-country/';
    return '/search/top-players-nearby/';
  }

  async doFetch(cursor) {
    const location = await getUserLocation();
    const { lat, long } = location.geo;
    const countryCode = await getCountryCode(lat, long);

    const params = new URLSearchParams({
      latitude:     lat,
      longitude:    long,
      limit:        LIMIT,
      country_code: countryCode,
    });
    if (cursor) params.set('last_player_id', cursor);

    const url = `${BASE}${this.endpoint}?${params}`;
    const res = await fetch(url, { headers: { Accept: 'application/json' } });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return res.json();
  }

  @action async loadPlayers() {
    const cache = getOrCreateCache(this.endpoint);
    if (cache.players) {
      this.players    = cache.players;
      this.nextCursor = cache.nextCursor;
      this.rankOffset = cache.rankOffset;
      this.hasMore    = cache.hasMore;
      this.isLoading  = false;
      return;
    }
    this.isLoading  = true;
    this.error      = null;
    this.nextCursor = null;
    this.rankOffset = 0;
    try {
      const data    = await this.doFetch(null);
      const results = data.results ?? [];
      this.players    = results.map((p, i) => transformPlayer(p, i));
      this.nextCursor = data.next_cursor ?? null;
      this.hasMore    = !!data.next_cursor;
      this.rankOffset = results.length;
      cache.players    = this.players;
      cache.nextCursor = this.nextCursor;
      cache.rankOffset = this.rankOffset;
      cache.hasMore    = this.hasMore;
    } catch {
      this.error = 'Failed to load players';
    } finally {
      this.isLoading = false;
    }
  }

  @action async loadMore() {
    if (this.isLoadingMore || !this.hasMore || !this.nextCursor) return;
    this.isLoadingMore = true;
    try {
      const data    = await this.doFetch(this.nextCursor);
      const results = data.results ?? [];
      const offset  = this.rankOffset;
      this.players  = [...this.players, ...results.map((p, i) => transformPlayer(p, offset + i))];
      this.nextCursor = data.next_cursor ?? null;
      this.hasMore    = !!data.next_cursor;
      this.rankOffset += results.length;
      const cache = getOrCreateCache(this.endpoint);
      cache.players    = this.players;
      cache.nextCursor = this.nextCursor;
      cache.rankOffset = this.rankOffset;
      cache.hasMore    = this.hasMore;
    } catch {
      this.hasMore = false;
    } finally {
      this.isLoadingMore = false;
    }
  }

  sentinel = modifier((el) => {
    const observer = new IntersectionObserver(
      ([entry]) => { if (entry.isIntersecting) this.loadMore(); },
      { threshold: 0.1 }
    );
    observer.observe(el);
    return () => observer.disconnect();
  });

  <template>
    <div class="bg-white/10 backdrop-blur-md border border-white/20 rounded-xl shadow-lg px-4 pt-3 pb-2 w-full" {{onInit this.loadPlayers}}>

      {{! Header }}
      <div class="flex items-center justify-between mb-2">
        <h2 class="text-sm font-bold text-white">{{if @title @title "Top Players"}}</h2>
      </div>

      {{! Scrollable list }}
      <div class="flex flex-col gap-2 overflow-y-auto max-h-72 scrollbar-hide">

        {{#if this.isLoading}}
          <div class="flex flex-col gap-2 animate-pulse">
            {{#each SKELETONS as |_|}}
              <div class="flex items-center rounded-lg px-2 py-2 min-h-[56px] bg-white/10">
                <div class="w-10 h-10 rounded-full bg-white/20 mr-3 shrink-0"></div>
                <div class="flex-1 min-w-0">
                  <div class="flex items-center justify-between">
                    <div class="h-3.5 w-24 bg-white/20 rounded"></div>
                    <div class="h-3 w-6 bg-white/20 rounded"></div>
                  </div>
                  <div class="flex items-center justify-between mt-1.5">
                    <div class="h-2.5 w-16 bg-white/15 rounded"></div>
                    <div class="h-3.5 w-10 bg-white/15 rounded"></div>
                  </div>
                </div>
              </div>
            {{/each}}
          </div>

        {{else if this.error}}
          <p class="text-red-300 text-[11px] text-center py-4">{{this.error}}</p>

        {{else if this.players.length}}
          {{#each this.players as |player|}}
            <LinkTo @route="player" @model={{player.username}}
              class="block rounded-lg bg-white/5 border border-white/10 transition-all duration-200 hover:bg-white/15 hover:-translate-y-0.5">
              <PlayerCard
                @avatarUrl={{player.avatarUrl}}
                @name={{player.name}}
                @position={{player.position}}
                @statLabel={{player.statLabel}}
                @statValue={{player.statValue}}
                @rank={{player.rank}}
              />
            </LinkTo>
          {{/each}}

          {{! Sentinel — triggers loadMore when scrolled into view }}
          <div {{this.sentinel}} class="flex items-center justify-center py-2 min-h-[24px]">
            {{#if this.isLoadingMore}}
              <div class="flex items-center gap-1.5">
                <div class="w-4 h-4 rounded-full border-2 border-white/30 border-t-white animate-spin"></div>
                <span class="text-white/50 text-[10px]">Loading…</span>
              </div>
            {{/if}}
          </div>

        {{else}}
          <p class="text-white/50 text-[11px] text-center py-4">No players found</p>
        {{/if}}

      </div>

      <LinkTo @route="players" class="w-full mt-2 text-cyan-300 text-[11px] font-medium py-2 hover:underline flex items-center justify-center gap-1 transition-colors">
        View Leaderboard <span aria-hidden="true">&rarr;</span>
      </LinkTo>
    </div>
  </template>
}
