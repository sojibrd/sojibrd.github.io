import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { service } from '@ember/service';
import { action } from '@ember/object';
import { LinkTo } from '@ember/routing';
import Search from './home/Search';
import Streaming from './home/Streaming';
// import YourCompetetions from './home/YourCompetetions';
import NearbyMatches from './home/NearbyMatches';
import PlayerList from './home/PlayerList';
import TrendingCard from './home/TrendingCard';
import TrendingCardSkeleton from './home/TrendingCardSkeleton';
import {onInit} from "../utils/utility.helper";

export default class HomePageComponent extends Component {
  @service geolocation;
  @service api;
  @service websocket;

  @tracked trendingMatches = [];
  @tracked exactTrendingMatches = [];

  @tracked isLoadingTrending = true;
  @tracked trendingError = null;

  @tracked isLoadingExact = true;
  @tracked exactError = null;

  _subscribedIds = [];

  get streamingMatch() {
    return this.trendingMatches[0] ?? null;
  }

  constructor() {
    super(...arguments);
    this.loadMatches();
  }

  willDestroy() {
    super.willDestroy();
    if (this._subscribedIds.length) {
      this.websocket.unsubscribe({ matchScoreIds: this._subscribedIds });
    }
  }

  async loadMatches() {
    try {
      const { latitude, longitude } = await this.geolocation.getCoords();
      const baseParams = { longitude, latitude, limit: 3 };

      const nearbyReady = new Promise((resolve) => {
        const unsub = this.websocket.on('*', (msg) => {
          if (msg?.status === 'success' && msg?.payload?.type === 'nearby_matches') {
            unsub();
            resolve();
          }
        });
        setTimeout(() => { unsub(); resolve(); }, 3000);
      });

      await Promise.allSettled([
        this.loadTrending(baseParams),
        this.loadExact(baseParams),
        nearbyReady,
      ]);

      this._subscribeAll();
    } catch (error) {
      const errorMessage =
        'Could not retrieve location to find matches. Please enable location services and try again.';
      this.trendingError = errorMessage;
      this.exactError = errorMessage;
      this.isLoadingTrending = false;
      this.isLoadingExact = false;
      console.error('Error getting coordinates:', error);
    }
  }

  _subscribeAll() {
    const allMatches = [...this.trendingMatches, ...this.exactTrendingMatches];
    const restIds = allMatches
      .filter(m => !m.is_finished && m.game_id)
      .map(m => String(m.game_id));
    const nearbyIds = this.websocket.nearbyMatches.map(m => String(m.match_id));
    const ids = [...new Set([...restIds, ...nearbyIds])];
    this._subscribedIds = ids;
    this.websocket.syncMatchScoreIds(ids);
  }

  async _fetchWithRetry(fn, retries = 2, delayMs = 1000) {
    for (let attempt = 0; attempt <= retries; attempt++) {
      try {
        return await fn();
      } catch (error) {
        const isServerError = error?.status >= 500 || error?.status === 0;
        if (isServerError && attempt < retries) {
          await new Promise((r) => setTimeout(r, delayMs * (attempt + 1)));
          continue;
        }
        throw error;
      }
    }
  }

  async loadTrending(params) {
    this.isLoadingTrending = true;
    this.trendingError = null;
    try {
      const result = await this._fetchWithRetry(() =>
        this.api.get('/home/nearest_location_live/', params)
      );
      this.trendingMatches = result.data || [];
    } catch (error) {
      this.trendingError = 'Failed to load trending matches.';
      console.error('Error fetching trending matches:', error);
    } finally {
      this.isLoadingTrending = false;
    }
  }

  async loadExact(params) {
    this.isLoadingExact = true;
    this.exactError = null;
    try {
      const result = await this._fetchWithRetry(() =>
        this.api.get('/home/upcoming-owner-priority-games/', { ...params, limit: 10 })
      );
      this.exactTrendingMatches = result.data || [];
    } catch (error) {
      this.exactError = 'Failed to load matches near you.';
      console.error('Error fetching exact trending matches:', error);
    } finally {
      this.isLoadingExact = false;
    }
  }

  @action onVideoInit(element) {
    if (!element) return;
    element.muted = true;
    const play = () => {
      element.play().catch(() => {
        console.warn('Autoplay blocked by browser.');
        setTimeout(_=>element.play(), 500);
      });
    };

    // Video already has enough data (served from cache) — play immediately
    if (element.readyState >= 2) {
      play();
      return;
    }

    // Otherwise wait until the browser has buffered enough to start playback
    element.addEventListener('canplay', play, { once: true });
  }


  <template>

  <div class="relative min-h-screen dark:text-white">

    {{! ── Background Video ────────────────────────────────────────────────
         CRITICAL: This wrapper must be `fixed` with NO transforms on itself
         or any ancestor. `overflow-hidden` is safe here because it is ON the
         fixed element itself (clips children), not on an ancestor of it.
    ────────────────────────────────────────────────────────────────────── }}
    <div class="fixed inset-0 z-0 overflow-hidden">
      <video
        class="absolute inset-0 w-full h-full object-cover scale-110"
        autoplay
        muted
        loop
        playsinline
        preload="auto"
        {{onInit this.onVideoInit}}
      >
        <source src="/Stadium Premium Footage 720P.mp4" type="video/mp4" />
      </video>

      {{! ONE gradient overlay only ── never add a second one outside this div }}
      <div class="absolute inset-0 bg-gradient-to-b from-orange-950/60 via-slate-900/70 to-slate-900/85"></div>
    </div>

    {{! ── Page Content ── }}
    <div class="relative z-10 max-w-7xl mx-auto px-3 sm:px-6 lg:px-8 pb-8">

      {{! ── Search Bar ── }}
      <div class="pt-4 sm:pt-6 pb-4 sm:pb-6">
        <Search />
      </div>

      {{! ── Main Grid ──
           mobile/tablet: single column — left content stacks above PlayerLists
           lg+:           two columns  — left content | right PlayerList sidebar
           PlayerLists render ONCE; CSS grid repositions them between breakpoints.
      ── }}
      <div class="grid grid-cols-1 lg:grid-cols-[1fr_300px] xl:grid-cols-[1fr_320px] gap-5 lg:gap-6 items-start">

        {{! ── Left Column (main content) ── }}
        <div class="min-w-0">

          {{! ── Hero Row ──
               mobile:  stacked (Streaming full-width, then Competitions full-width)
               sm+:     side-by-side (Streaming fixed, Competitions flex-grow)
          ── }}
          <div class="flex flex-col sm:flex-row gap-3 sm:gap-4 mb-6 sm:mb-8 items-stretch">

            {{! Streaming card — full-width on mobile, fixed narrow on sm+ }}
            <div class="w-full sm:w-44 md:w-52 lg:w-56 sm:flex-shrink-0 flex [&>*]:flex-1 [&>*]:w-full [&>*]:h-full">
              <Streaming
                @match={{this.streamingMatch}}
              />
            </div>

            {{! Your Competitions — full-width on mobile, flex-grow on sm+ }}
            <div class="w-full sm:flex-1 sm:min-w-0 flex [&>*]:flex-1 [&>*]:w-full [&>*]:h-full">
              <NearbyMatches />
            </div>

          </div>

          {{! ── Trending Matches ── }}
          <div class="mb-6 sm:mb-8">
            <div class="flex items-center justify-between mb-3">
              <h2 class="text-sm font-bold text-white">Trending Matches Near Me</h2>
              <LinkTo @route="match.index"
                class="text-orange-300 text-[11px] font-medium hover:underline flex items-center gap-1 no-underline"
              >View All <span aria-hidden="true">&rarr;</span></LinkTo>
            </div>
            <div class="rounded-xl">
              {{#if this.isLoadingTrending}}
                <div>
                  <TrendingCardSkeleton />
                  <TrendingCardSkeleton />
                  <TrendingCardSkeleton />
                </div>
              {{else if this.trendingError}}
                <p class="text-red-400 text-center py-8 border border-white/20 rounded-xl bg-black/30 backdrop-blur-sm">
                  {{this.trendingError}}
                </p>
              {{else}}
                {{#each this.trendingMatches as |match|}}
                  <TrendingCard @match={{match}} />
                {{else}}
                  <p class="text-white/60 text-center py-8 border border-white/20 rounded-xl bg-black/30 backdrop-blur-sm">
                    No trending matches available.
                  </p>
                {{/each}}
              {{/if}}
            </div>
          </div>

          {{! ── Matches Near You ── }}
          <div class="mb-6 sm:mb-8">
            <div class="flex items-center justify-between mb-3">
              <h2 class="text-sm font-bold text-white">Matches Near You</h2>
              <LinkTo @route="match.index"
                class="text-orange-300 text-[11px] font-medium hover:underline flex items-center gap-1 no-underline"
              >View All <span aria-hidden="true">&rarr;</span></LinkTo>
            </div>
            <div class="rounded-xl">
              {{#if this.isLoadingExact}}
                <div>
                  <TrendingCardSkeleton />
                  <TrendingCardSkeleton />
                  <TrendingCardSkeleton />
                </div>
              {{else if this.exactError}}
                <p class="text-red-400 text-center py-8 border border-white/20 rounded-xl bg-black/30 backdrop-blur-sm">
                  {{this.exactError}}
                </p>
              {{else}}
                {{#each this.exactTrendingMatches as |match|}}
                  <TrendingCard @match={{match}} />
                {{else}}
                  <p class="text-white/60 text-center py-8 border border-white/20 rounded-xl bg-black/30 backdrop-blur-sm">
                    No matches available near you.
                  </p>
                {{/each}}
              {{/if}}
            </div>
          </div>

        </div>

        {{! ── PlayerLists ──
             Rendered ONCE. CSS grid places them:
               mobile/tablet → below main content (2nd grid row, 1 col)
               lg+           → right sidebar (col 2, sticky top)
             Inner grid shifts from 1→3→1 columns across breakpoints.
        ── }}
        <div class="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-1 gap-4 lg:gap-5 lg:sticky lg:top-4">
          <PlayerList @title="Top Players - Near By Me" />
          <PlayerList @title="Top Players - District" />
          <PlayerList @title="Top Players - Country" />
        </div>

      </div>
    </div>
  </div>
  </template>
}
