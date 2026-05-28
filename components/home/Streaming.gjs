import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { service } from '@ember/service';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { LinkTo } from '@ember/routing';
import { modifier } from 'ember-modifier';
import { onInit } from '../../utils/utility.helper';
import config from 'spordium/config/environment';

const S3          = config.APP.S3_BUCKET_URL;
const SEARCH_HOST = config.APP.SEARCH_API_HOST || '';

function imgUrl(path) {
  if (!path) return null;
  if (path.startsWith('http')) return path;
  const clean = path.startsWith('/') ? path.slice(1) : path;
  return `${S3}/${clean}`;
}

// Re-triggers CSS animation on every flashKey change
const animPop = modifier((el, [_key]) => {
  el.classList.remove('ls-ball-pop');
  void el.offsetWidth;
  el.classList.add('ls-ball-pop');
});

const BALL_STYLES = {
  six:    { ring: '#34d399', bg: 'rgba(52,211,153,0.15)', text: '#34d399', label: 'SIX!' },
  four:   { ring: '#38bdf8', bg: 'rgba(56,189,248,0.15)', text: '#38bdf8', label: 'FOUR!' },
  wicket: { ring: '#f87171', bg: 'rgba(248,113,113,0.15)', text: '#f87171', label: 'WICKET!' },
  wide:   { ring: '#fbbf24', bg: 'rgba(251,191,36,0.15)',  text: '#fbbf24', label: 'WIDE' },
  noball: { ring: '#fb923c', bg: 'rgba(251,146,60,0.15)',  text: '#fb923c', label: 'NO BALL' },
  dot:    { ring: '#64748b', bg: 'rgba(100,116,139,0.12)', text: '#94a3b8', label: 'DOT' },
  runs:   { ring: '#a78bfa', bg: 'rgba(167,139,250,0.15)', text: '#a78bfa', label: 'RUN' },
};

function detectBallType(curr, prev) {
  if (!prev) return null;
  const cf = curr.facing, pf = prev.facing;
  const cb = curr.bowling, pb = prev.bowling;
  if ((cb?.wideball  ?? 0) > (pb?.wideball  ?? 0)) return 'wide';
  if ((cb?.noball    ?? 0) > (pb?.noball    ?? 0)) return 'noball';
  if (cf?.outtype && !pf?.outtype)                  return 'wicket';
  if ((cf?.runs_6    ?? 0) > (pf?.runs_6    ?? 0)) return 'six';
  if ((cf?.runs_4    ?? 0) > (pf?.runs_4    ?? 0)) return 'four';
  const runsDelta = (cf?.runsscored ?? 0) - (pf?.runsscored ?? 0);
  return runsDelta === 0 ? 'dot' : 'runs';
}

function n(val, fallback = '—') {
  return val != null ? val : fallback;
}

function formatMatchDate(id) {
  if (!id) return '';
  const raw = (id.split('__')[1] ?? id).slice(0, 8);
  if (raw.length < 8) return '';
  try {
    return new Date(`${raw.slice(0,4)}-${raw.slice(4,6)}-${raw.slice(6,8)}`).toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  } catch { return ''; }
}

export default class LiveScoreCard extends Component {
  @service router;
  @service websocket;

  @tracked liveData              = null;
  @tracked lastBallType          = null;
  @tracked lastBallValue         = '—';
  @tracked flashKey              = 0;
  @tracked _nearestMatch         = null;
  @tracked enrichedNearbyMatches = [];

  #prevPayload        = null;
  #destroyed          = false;
  #unlisten           = null;
  #lastFetchedMatchId = null;
  #initialFetchDone   = false;
  #fetchDone          = false;

  // ── Initial match data (from nearest_location_live API or @match arg) ───

  get match()        { return this._nearestMatch ?? this.args.match; }
  get gameId()       { return this._nearestMatch?.game_id ?? this.args.match?.game_id ?? null; }
  get matchScore()   { return this.match?.score; }
  get matchName()    { return this.matchScore?.name || '—'; }
  get battingTeam()  { return this.matchScore?.batting; }
  get fieldingTeam() { return this.matchScore?.fielding; }
  get isStarted()    { return this.match?.is_start === true; }
  get matchPrize()   { const p = this.matchScore?.match_prize; return Number(p) > 0 ? p : null; }
  get innings()      { return this.matchScore?.innings ?? null; }

  get battingInitial()  { return (this.battingTeam?.team_name  || '?')[0].toUpperCase(); }
  get fieldingInitial() { return (this.fieldingTeam?.team_name || '?')[0].toUpperCase(); }

  get matchDateStr() {
    const dt = this.match?.datetime;
    if (!dt) return null;
    try {
      return new Date(dt).toLocaleString('en-US', {
        month: 'short', day: 'numeric', year: 'numeric',
        hour: '2-digit', minute: '2-digit',
      });
    } catch { return null; }
  }

  get battingScoreStr() {
    const b = this.battingTeam;
    if (!b || b.livescore == null) return null;
    return `${b.livescore}/${b.wicketstaken ?? 0}`;
  }

  get fieldingScoreStr() {
    const f = this.fieldingTeam;
    if (!f || f.livescore == null) return null;
    return `${f.livescore}/${f.wicketstaken ?? 0}`;
  }

  get battingRuns()    { return this.battingTeam?.livescore  ?? 0; }
  get battingWickets() { return this.battingTeam?.wicketstaken ?? 0; }
  get fieldingRuns()   { return this.fieldingTeam?.livescore  ?? '—'; }
  get fieldingWickets(){ return this.fieldingTeam?.wicketstaken ?? 0; }

  // ── WS live data getters ──────────────────────────────────────────────────

  get striker() { return this.liveData?.payload?.facing; }
  get runner()  { return this.liveData?.payload?.runner; }
  get bowler()  { return this.liveData?.payload?.bowling; }

  get strikerName() { return this.striker?.matchbatsman?.name || '—'; }
  get runnerName()  { return this.runner?.matchbatsman?.name  || '—'; }
  get bowlerName()  { return this.bowler?.matchbowler?.name   || '—'; }

  get strikerStats()  { return `${n(this.striker?.runsscored, 0)}(${n(this.striker?.ballsfaced, 0)})  SR ${n(this.striker?.strikerate)}`; }
  get runnerStats()   { return `${n(this.runner?.runsscored,  0)}(${n(this.runner?.ballsfaced,  0)})`; }
  get bowlerStats()   {
    const b = this.bowler;
    if (!b) return '';
    return `${n(b.oversbowled, 0)} ov · ${n(b.runsgiven, 0)} r · ${n(b.wicketstaken, 0)} w · ER ${n(b.economyrate)}`;
  }

  get ballStyle() { return BALL_STYLES[this.lastBallType] ?? null; }

  // ── Connection flags ──────────────────────────────────────────────────────

  get isConnected()  { return this.websocket.isConnected; }
  get isConnecting() { return !this.websocket.isConnected; }
  get hasError()     { return false; }
  get isClosed()     { return false; }
  get hasData()       { return !!this.liveData; }
  get nearbyMatches() { return this.websocket.nearbyMatches; }
  get showHeader()    { return this.hasData || this.nearbyMatches.length === 0; }

  get nearbyHeaderLabel() {
    return 'Most Viewed';
  }

  // ── WebSocket ─────────────────────────────────────────────────────────────

  @action
  goToGame() {
    if (!this.gameId) return;
    this.router.transitionTo('match.match-details', { queryParams: { gameid: this.gameId } });
  }

  @action
  goToMatch(matchId, event) {
    event.stopPropagation();
    this.router.transitionTo('match.match-details', { queryParams: { gameid: matchId } });
  }

  @action
  stopPropagation(event) {
    event.stopPropagation();
  }

  _transformSearchItem(item) {
    return {
      game_id:  item.game_id,
      is_start: item.is_started,
      datetime: item.game_datetime,
      score: {
        name:        item.game_name,
        batting:     item.game_result?.batting  ?? null,
        fielding:    item.game_result?.fielding ?? null,
        innings:     item.game_result?.innings  ?? null,
        match_prize: item.game_result?.match_prize ?? item.game_configuration?.match_prize ?? null,
      },
    };
  }

  async _fetchNearbyMatchDetails(matches) {
    if (!matches?.length || this.#fetchDone) return;
    this.#fetchDone = true;
    try {
      // Single API call — search by primary match ID with high limit to capture all nearby matches
      const primaryId = matches[0].match_id;
      const url  = `${SEARCH_HOST}/search/upcomming-game-search/?country_code=BD&limit=${matches.length + 5}&offset=0&search_data=${encodeURIComponent(primaryId)}`;
      const res  = await fetch(url, { headers: { Accept: 'application/json' } });
      const json = await res.json();
      if (this.#destroyed) return;

      const items  = json.data?.results ?? json.results ?? json.data ?? [];
      const lookup = new Map(items.map((g) => [String(g.game_id), g]));

      const enriched = matches.map((m) => {
        const g = lookup.get(String(m.match_id));
        if (!g) return { ...m, _raw: null };
        const d = new Date(g.game_datetime);
        return {
          match_id:      m.match_id,
          sport:         m.sport,
          live_count:    m.live_count,
          total_count:   m.total_count,
          name:          g.game_name,
          isStarted:     g.is_started,
          isFinished:    g.is_finished,
          overs:         g.game_configuration?.over ?? null,
          prize:         (() => { const p = g.game_configuration?.match_prize; return Number(p) > 0 ? p : null; })(),
          formattedDate: d.toLocaleDateString('en-US', { day: 'numeric', month: 'short' }),
          formattedTime: d.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: true }),
          team1:         { name: g.team1_details?.team_name || 'Team 1', logo: imgUrl(g.team1_details?.team_logo) },
          team2:         { name: g.team2_details?.team_name || 'Team 2', logo: imgUrl(g.team2_details?.team_logo) },
          _raw:          g,
        };
      });

      this.enrichedNearbyMatches = enriched;

      const first = enriched[0];
      if (first?._raw) {
        this._nearestMatch       = this._transformSearchItem(first._raw);
        this.#lastFetchedMatchId = String(first.match_id);
        this.websocket.syncMatchScoreIds(
          enriched.filter((e) => e._raw).map((e) => String(e.match_id))
        );
      }
    } catch {
      // silent
    }
  }

  @action
  fetchContinuousScore() {
    // If nearby_matches WS message arrived before this component mounted, use it immediately
    const preloadedMatches = this.websocket.nearbyMatches;
    const preloadedId      = preloadedMatches[0]?.match_id;
    if (preloadedId) {
      this.#initialFetchDone   = true;
      this.#lastFetchedMatchId = preloadedId;
      this._fetchNearbyMatchDetails(preloadedMatches);
    }

    this.#unlisten = this.websocket.on('*', (msg) => {
      if (this.#destroyed) return;

      // Once initial fetch is done, never fetch again — WS handles real-time updates
      if (!this.#initialFetchDone && msg?.status === 'success' && msg?.payload?.type === 'nearby_matches') {
        this.#initialFetchDone = true;
        const wsMatches = msg.payload.matches ?? [];
        const matchId   = wsMatches[0]?.match_id;
        if (matchId) {
          this.#lastFetchedMatchId = matchId;
          this._fetchNearbyMatchDetails(wsMatches);
        }
      }

      try {
        const gameId = this.gameId;
        if (!gameId) return;

        const payload = msg.payload;
        if (!payload?.isScoreboardData) return;

        const receiverGameId = msg.receiver?.split(':').pop();
        if (receiverGameId && receiverGameId !== String(gameId)) return;

        const ballType = detectBallType(payload, this.#prevPayload);
        if (ballType) {
          if (ballType === 'six')         this.lastBallValue = '6';
          else if (ballType === 'four')   this.lastBallValue = '4';
          else if (ballType === 'wicket') this.lastBallValue = 'W';
          else if (ballType === 'wide')   this.lastBallValue = 'WD';
          else if (ballType === 'noball') this.lastBallValue = 'NB';
          else if (ballType === 'dot')    this.lastBallValue = '0';
          else {
            const delta = (payload.facing?.runsscored ?? 0) - (this.#prevPayload?.facing?.runsscored ?? 0);
            this.lastBallValue = String(delta);
          }
          this.lastBallType = ballType;
          this.flashKey += 1;
        }

        this.#prevPayload = payload;
        this.liveData = msg;
      } catch {
        console.warn('[LiveScore WS] message error');
      }
    });
  }

  willDestroy() {
    super.willDestroy();
    this.#destroyed = true;
    if (this.#unlisten) {
      this.#unlisten();
      this.#unlisten = null;
    }
  }

  <template>
    <style>
      @keyframes ls-ball-pop {
        0%   { transform: scale(0.2) rotate(-20deg); opacity: 0; }
        55%  { transform: scale(1.2) rotate(6deg);   opacity: 1; }
        75%  { transform: scale(0.93) rotate(-2deg); }
        100% { transform: scale(1) rotate(0deg);     opacity: 1; }
      }
      @keyframes ls-shimmer {
        0%   { background-position: -200% 0; }
        100% { background-position:  200% 0; }
      }
      @keyframes ls-glow-pulse {
        0%, 100% { opacity: 0.4; transform: scale(1); }
        50%       { opacity: 0.8; transform: scale(1.15); }
      }
      .ls-ball-pop  { animation: ls-ball-pop 0.45s cubic-bezier(.34,1.56,.64,1) both; }
      .ls-shimmer   {
        background: linear-gradient(90deg, #f59e0b 0%, #fde68a 40%, #f59e0b 80%);
        background-size: 200% auto;
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        animation: ls-shimmer 2s linear infinite;
      }
      .ls-glow { animation: ls-glow-pulse 2s ease-in-out infinite; }
      @keyframes ls-spin-slow { from { transform: rotate(0deg); }  to { transform: rotate(360deg); } }
      @keyframes ls-spin-rev  { from { transform: rotate(0deg); }  to { transform: rotate(-360deg); } }
      @keyframes ls-radar     { 0%   { transform: scale(0.55); opacity: 0.7; } 100% { transform: scale(2.1); opacity: 0; } }
      @keyframes ls-dot-hop   { 0%, 80%, 100% { transform: translateY(0); opacity: 0.5; } 40% { transform: translateY(-5px); opacity: 1; } }
      .ls-spin-slow { animation: ls-spin-slow 8s linear infinite; }
      .ls-spin-rev  { animation: ls-spin-rev  5s linear infinite; }
    </style>

    <div
      class="relative flex flex-col h-full rounded-2xl overflow-hidden font-sans select-none cursor-pointer
             bg-white/10 backdrop-blur-md border border-white/20
             shadow-[0_4px_24px_rgba(0,0,0,0.30),inset_0_1px_0_rgba(255,255,255,0.10)]"
      {{onInit this.fetchContinuousScore}}
      {{on "click" this.goToGame}}
    >

      <div class="relative z-10 flex flex-col flex-1 gap-0 p-3">

        {{! ── Header — hidden when nearby matches are displayed ───────────── }}
        {{#if this.showHeader}}
        <div class="flex items-center justify-between mb-2.5">
          {{#if this.hasData}}
            <div class="flex items-center gap-1.5">
              <span class="relative flex w-2 h-2">
                <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-red-500 opacity-75"></span>
                <span class="relative inline-flex rounded-full w-2 h-2 bg-red-500"></span>
              </span>
              <span class="text-red-400 text-[11px] font-black tracking-[0.18em] uppercase">Live</span>
            </div>
          {{else if this.hasError}}
            <div class="flex items-center gap-1.5">
              <span class="w-2 h-2 rounded-full bg-red-600"></span>
              <span class="text-red-500 text-[11px] font-bold tracking-widest uppercase">Error</span>
            </div>
          {{else}}
            <div class="flex items-center gap-1.5">
              <span class="w-2 h-2 rounded-full bg-slate-600"></span>
              <span class="text-slate-500 text-[11px] font-bold tracking-widest uppercase">Offline</span>
            </div>
          {{/if}}

          <div class="flex items-center gap-1">
            <svg class="w-3 h-3 text-white/20" viewBox="0 0 24 24" fill="currentColor">
              <path d="M19.06 2.94A1.5 1.5 0 0 0 17 2.94L5.5 14.44a1.5 1.5 0 0 0 0 2.12l2 2a1.5 1.5 0 0 0 2.12 0L21.06 7.06a1.5 1.5 0 0 0 0-2.12l-2-2zM4 18l-1.5 3.5L6 20l-2-2z"/>
            </svg>
            <span class="text-white/20 text-[11px] font-semibold tracking-wide uppercase">Cricket</span>
          </div>
        </div>
        {{/if}}

        {{! ══════════════════════════════════════════════════════════════════
             STATE 1 — WS live data flowing: show ball + batting + bowling
        ══════════════════════════════════════════════════════════════════ }}
        {{#if this.hasData}}

          {{! Last ball strip }}
          {{#if this.ballStyle}}
            <div {{animPop this.flashKey}}
                 class="ls-ball-pop flex items-center gap-2 rounded-lg px-2 py-1.5 mb-2"
                 style="background:{{this.ballStyle.bg}};border:1px solid {{this.ballStyle.ring}}33;">
              <div class="w-7 h-7 rounded-full flex-shrink-0 flex items-center justify-center"
                   style="border:1.5px solid {{this.ballStyle.ring}};box-shadow:0 0 8px {{this.ballStyle.ring}}66;">
                <span class="text-[15px] font-black leading-none" style="color:{{this.ballStyle.ring}};">
                  {{this.lastBallValue}}
                </span>
              </div>
              <span class="text-[11px] font-black tracking-[0.18em] uppercase flex-1"
                    style="color:{{this.ballStyle.ring}};">{{this.ballStyle.label}}</span>
            </div>
          {{else}}
            <div class="flex items-center gap-2 rounded-lg px-2 py-1.5 mb-2"
                 style="background:rgba(255,255,255,0.03);border:1px solid rgba(255,255,255,0.06);">
              <div class="w-7 h-7 rounded-full flex-shrink-0 flex items-center justify-center"
                   style="border:1.5px solid rgba(255,255,255,0.1);">
                <span class="text-white/20 text-xs font-black">—</span>
              </div>
              <span class="text-white/20 text-[11px] font-bold tracking-widest uppercase">Next ball</span>
            </div>
          {{/if}}

          {{#if this.striker}}
            {{! BATTING label }}
            <div class="flex items-center gap-1 mb-1">
              <div class="w-1 h-2.5 rounded-full bg-orange-500"></div>
              <span class="text-[10px] font-black tracking-[0.18em] text-orange-400/70 uppercase">Batting</span>
            </div>

            {{! Striker row }}
            <div class="flex items-center gap-1.5 rounded-lg px-2 py-1.5 mb-1"
                 style="background:rgba(251,146,60,0.14);border:1px solid rgba(251,146,60,0.28);">
              <div class="w-3.5 h-3.5 rounded-full flex-shrink-0 flex items-center justify-center"
                   style="background:rgba(251,146,60,0.25);border:1px solid rgba(251,146,60,0.5);">
                <svg class="w-2 h-2" viewBox="0 0 24 24" fill="rgba(251,146,60,1)">
                  <path d="M19.06 2.94A1.5 1.5 0 0 0 17 2.94L5.5 14.44a1.5 1.5 0 0 0 0 2.12l2 2a1.5 1.5 0 0 0 2.12 0L21.06 7.06a1.5 1.5 0 0 0 0-2.12l-2-2zM4 18l-1.5 3.5L6 20l-2-2z"></path>
                </svg>
              </div>
              <div class="flex-1 min-w-0">
                <div class="flex items-baseline gap-1">
                  <span class="text-white text-[13px] font-bold truncate leading-none">{{this.strikerName}}</span>
                  <span class="text-orange-400 text-[12px] font-black flex-shrink-0">*</span>
                </div>
                <div class="flex items-center gap-1 mt-0.5 flex-wrap">
                  <span class="text-white/40 text-[11px] font-mono">{{this.strikerStats}}</span>
                  {{#if this.striker.runs_4}}
                    <span class="text-[10px] font-black text-sky-400 px-1 rounded"
                          style="background:rgba(56,189,248,0.12);border:1px solid rgba(56,189,248,0.25);">{{this.striker.runs_4}}×4</span>
                  {{/if}}
                  {{#if this.striker.runs_6}}
                    <span class="text-[10px] font-black text-emerald-400 px-1 rounded"
                          style="background:rgba(52,211,153,0.12);border:1px solid rgba(52,211,153,0.25);">{{this.striker.runs_6}}×6</span>
                  {{/if}}
                  {{#if this.striker.outtype}}
                    <span class="text-[10px] font-black text-red-400 px-1 rounded"
                          style="background:rgba(248,113,113,0.12);border:1px solid rgba(248,113,113,0.3);">OUT</span>
                  {{/if}}
                </div>
              </div>
            </div>

            {{! Runner row }}
            {{#if this.runner}}
              <div class="flex items-center gap-1.5 px-2 py-1 mb-2">
                <div class="w-3.5 h-3.5 rounded-full flex-shrink-0"
                     style="border:1px solid rgba(255,255,255,0.12);"></div>
                <span class="text-white/45 text-[12px] flex-1 min-w-0 truncate">{{this.runnerName}}</span>
                <span class="text-white/25 text-[11px] font-mono flex-shrink-0">{{this.runnerStats}}</span>
              </div>
            {{/if}}

            {{! Divider }}
            <div class="w-full h-px mb-1.5"
                 style="background:linear-gradient(to right,transparent,rgba(255,255,255,0.07),transparent);"></div>

            {{! BOWLING label }}
            {{#if this.bowler}}
              <div class="flex items-center gap-1 mb-1">
                <div class="w-1 h-2.5 rounded-full bg-indigo-500"></div>
                <span class="text-[10px] font-black tracking-[0.18em] text-indigo-400/70 uppercase">Bowling</span>
              </div>
              <div class="flex items-center gap-1.5 rounded-lg px-2 py-1.5"
                   style="background:rgba(99,102,241,0.14);border:1px solid rgba(99,102,241,0.28);">
                <div class="w-3.5 h-3.5 rounded-full flex-shrink-0 flex items-center justify-center"
                     style="background:rgba(99,102,241,0.25);border:1px solid rgba(99,102,241,0.5);">
                  <svg class="w-2 h-2 text-indigo-400" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M12 3a9 9 0 1 0 0 18A9 9 0 0 0 12 3z"></path>
                  </svg>
                </div>
                <div class="flex-1 min-w-0">
                  <div class="flex items-center justify-between gap-1">
                    <span class="text-white text-[13px] font-bold truncate leading-none">{{this.bowlerName}}</span>
                    <div class="flex gap-0.5 flex-shrink-0">
                      {{#if this.bowler.wideball}}
                        <span class="text-[9px] font-black text-amber-400 px-1 rounded"
                              style="background:rgba(251,191,36,0.12);border:1px solid rgba(251,191,36,0.3);">WD</span>
                      {{/if}}
                      {{#if this.bowler.noball}}
                        <span class="text-[9px] font-black text-orange-400 px-1 rounded"
                              style="background:rgba(251,146,60,0.12);border:1px solid rgba(251,146,60,0.3);">NB</span>
                      {{/if}}
                    </div>
                  </div>
                  <span class="text-white/40 text-[11px] font-mono mt-0.5 block">{{this.bowlerStats}}</span>
                </div>
              </div>
            {{/if}}
          {{/if}}

        {{! ══════════════════════════════════════════════════════════════════
             STATE 2 — WS nearby_matches broadcast
        ══════════════════════════════════════════════════════════════════ }}
        {{else if this.nearbyMatches.length}}

          {{! Nearby matches header }}
          <div class="flex items-center justify-between mb-1.5">
            <span class="text-sm font-bold text-white/70">{{this.nearbyHeaderLabel}}</span>
            <LinkTo @route="match.index" {{on "click" this.stopPropagation}}
              class="text-white/30 hover:text-white/60 transition-colors no-underline">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7"/>
              </svg>
            </LinkTo>
          </div>

          <div class="flex flex-col gap-2 overflow-y-auto">
            {{#each (if this.enrichedNearbyMatches.length this.enrichedNearbyMatches this.nearbyMatches) as |m|}}
              <button type="button"
                {{on "click" (fn this.goToMatch m.match_id)}}
                class="flex flex-col w-full rounded-xl text-left
                       bg-white/[0.06] border border-white/[0.10]
                       hover:bg-white/[0.10] hover:border-white/20 transition-all duration-150 overflow-hidden">

                {{! Row 1: teams }}
                <div class="flex items-center gap-2 px-3 pt-2.5 pb-2">
                  {{#if m.team1}}
                    <div class="flex-1 flex items-center gap-1.5 min-w-0">
                      {{#if m.team1.logo}}
                        <img src={{m.team1.logo}} alt={{m.team1.name}}
                             class="w-6 h-6 rounded-md object-contain shrink-0 bg-white/10 p-0.5" />
                      {{else}}
                        <div class="w-6 h-6 rounded-md shrink-0 bg-white/10 flex items-center justify-center">
                          <span class="text-[9px] font-bold text-white/40">{{m.team1.name.[0]}}</span>
                        </div>
                      {{/if}}
                      <span class="text-white/85 text-[11px] font-semibold truncate">{{m.team1.name}}</span>
                    </div>
                    <span class="text-[9px] font-black text-white/15 shrink-0">VS</span>
                    <div class="flex-1 flex items-center gap-1.5 justify-end min-w-0">
                      <span class="text-white/85 text-[11px] font-semibold truncate text-right">{{m.team2.name}}</span>
                      {{#if m.team2.logo}}
                        <img src={{m.team2.logo}} alt={{m.team2.name}}
                             class="w-6 h-6 rounded-md object-contain shrink-0 bg-white/10 p-0.5" />
                      {{else}}
                        <div class="w-6 h-6 rounded-md shrink-0 bg-white/10 flex items-center justify-center">
                          <span class="text-[9px] font-bold text-white/40">{{m.team2.name.[0]}}</span>
                        </div>
                      {{/if}}
                    </div>
                  {{else}}
                    <span class="text-white/60 text-[12px] font-bold flex-1">{{m.sport}}</span>
                    {{#if m.live_count}}
                      <div class="flex items-center gap-1 shrink-0">
                        <svg class="w-2.5 h-2.5 text-red-400/60" fill="currentColor" viewBox="0 0 24 24">
                          <path d="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5zM12 17c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3z"/>
                        </svg>
                        <span class="text-white/50 text-[11px] font-semibold">{{m.live_count}}</span>
                      </div>
                    {{/if}}
                  {{/if}}
                </div>

                {{! Row 2: status · overs · date · viewers }}
                <div class="flex items-center gap-1.5 px-3 pb-2 text-[9px]">
                  {{#if m.isFinished}}
                    <span class="font-semibold text-slate-400/70 shrink-0">Finished</span>
                  {{else if m.isStarted}}
                    <span class="flex items-center gap-1 font-black text-red-400 shrink-0">
                      <span class="w-1 h-1 rounded-full bg-red-500 animate-pulse"></span>LIVE
                    </span>
                  {{else if m.name}}
                    <span class="font-semibold text-blue-400/70 shrink-0">Upcoming</span>
                  {{else}}
                    <span class="flex items-center gap-1 font-black text-red-400 shrink-0">
                      <span class="w-1 h-1 rounded-full bg-red-500 animate-pulse"></span>LIVE
                    </span>
                  {{/if}}
                  {{#if m.overs}}
                    <span class="text-white/15">·</span>
                    <span class="text-cyan-400/70 font-semibold shrink-0">{{m.overs}} ov</span>
                  {{/if}}
                  {{#if m.formattedDate}}
                    <span class="text-white/15">·</span>
                    <span class="text-white/25 truncate">{{m.formattedDate}}</span>
                  {{/if}}
                  {{#if m.live_count}}
                    <div class="flex items-center gap-1 ml-auto shrink-0">
                      <svg class="w-2 h-2 text-red-400/50" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5zM12 17c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3z"/>
                      </svg>
                      <span class="text-white/40 font-semibold">{{m.live_count}}</span>
                    </div>
                  {{/if}}
                </div>

              </button>
            {{/each}}
          </div>

        {{! ══════════════════════════════════════════════════════════════════
             STATE 3 — No WS data yet, but API match data available
        ══════════════════════════════════════════════════════════════════ }}
        {{else if this.match}}

          {{! ── Top meta: status badge + match name ── }}
          <div class="flex items-center gap-1.5 mb-3">
            {{#if this.isStarted}}
              <span class="inline-flex items-center gap-1 shrink-0
                           bg-emerald-500/20 text-emerald-300 border border-emerald-400/40
                           text-[9px] font-bold tracking-wider uppercase px-2 py-0.5 rounded-full">
                <span class="w-1.5 h-1.5 bg-emerald-400 rounded-full animate-pulse
                             shadow-[0_0_4px_rgba(52,211,153,0.9)]"></span>
                Live
              </span>
            {{else}}
              <span class="inline-flex items-center shrink-0
                           bg-white/[0.08] text-white/40 border border-white/[0.12]
                           text-[9px] tracking-widest uppercase px-2 py-0.5 rounded-full">
                Upcoming
              </span>
            {{/if}}
            <span class="text-white/60 text-[10px] font-medium truncate">{{this.matchName}}</span>
          </div>

          {{! ── Teams + Scores ── }}
          <div class="flex items-center gap-1 flex-1">

            {{! Batting team }}
            <div class="flex flex-col items-center gap-1 flex-1 min-w-0">
              <div class="w-10 h-10 rounded-xl shrink-0 overflow-hidden
                           ring-2 ring-white/20 ring-offset-1 ring-offset-transparent
                           bg-white/10 flex items-center justify-center
                           shadow-[0_2px_12px_rgba(0,0,0,0.4)]">
                {{#if this.battingTeam.team_logo}}
                  <img src="{{S3}}/{{this.battingTeam.team_logo}}"
                       class="w-full h-full object-cover" alt={{this.battingTeam.team_name}} loading="lazy" />
                {{else}}
                  <span class="text-white/50 text-sm font-bold">{{this.battingInitial}}</span>
                {{/if}}
              </div>
              <p class="text-white text-[11px] font-bold truncate w-full text-center leading-tight">
                {{this.battingTeam.team_name}}
              </p>
              {{#if this.isStarted}}
                <p class="font-black leading-none tracking-tight text-2xl text-white">
                  {{this.battingRuns}}<span class="text-sm font-bold text-white/30 ml-0.5">/{{this.battingWickets}}</span>
                </p>
                {{#if this.battingTeam.balls}}
                  <p class="text-white/45 text-[9px] font-medium tabular-nums">{{this.battingTeam.balls}} ov</p>
                {{/if}}
              {{else}}
                <p class="text-white/40 text-[9px] font-bold tracking-wide uppercase">Batting</p>
              {{/if}}
            </div>

            {{! VS separator }}
            <div class="flex flex-col items-center gap-1 shrink-0 px-1">
              <div class="w-px h-4 bg-gradient-to-b from-transparent via-white/20 to-transparent"></div>
              <span class="text-white/25 text-[8px] font-black tracking-widest">vs</span>
              <div class="w-px h-4 bg-gradient-to-b from-transparent via-white/20 to-transparent"></div>
            </div>

            {{! Fielding team }}
            <div class="flex flex-col items-center gap-1 flex-1 min-w-0">
              <div class="w-10 h-10 rounded-xl shrink-0 overflow-hidden
                           ring-2 ring-white/20 ring-offset-1 ring-offset-transparent
                           bg-white/10 flex items-center justify-center
                           shadow-[0_2px_12px_rgba(0,0,0,0.4)]">
                {{#if this.fieldingTeam.team_logo}}
                  <img src="{{S3}}/{{this.fieldingTeam.team_logo}}"
                       class="w-full h-full object-cover" alt={{this.fieldingTeam.team_name}} loading="lazy" />
                {{else}}
                  <span class="text-white/50 text-sm font-bold">{{this.fieldingInitial}}</span>
                {{/if}}
              </div>
              <p class="text-white text-[11px] font-bold truncate w-full text-center leading-tight">
                {{this.fieldingTeam.team_name}}
              </p>
              {{#if this.isStarted}}
                <p class="font-black leading-none tracking-tight text-2xl text-white/40">
                  {{this.fieldingRuns}}<span class="text-sm font-bold text-white/30 ml-0.5">/{{this.fieldingWickets}}</span>
                </p>
              {{else}}
                <p class="text-white/40 text-[9px] font-bold tracking-wide uppercase">Fielding</p>
              {{/if}}
            </div>

          </div>

          {{! ── Footer: innings + prize + date ── }}
          <div class="flex items-center justify-between mt-auto pt-2 border-t border-white/[0.05]">
            <div class="flex items-center gap-1.5">
              {{#if this.innings}}
                <span class="text-[9px] font-bold text-white/40 bg-white/[0.07] border border-white/[0.10]
                             px-1.5 py-0.5 rounded">INN {{this.innings}}</span>
              {{/if}}
              {{#if this.matchPrize}}
                <span class="text-amber-300 text-[10px] font-bold
                             bg-amber-400/10 border border-amber-400/20 px-1.5 py-0.5 rounded-md">
                  ৳{{this.matchPrize}}
                </span>
              {{/if}}
            </div>
            {{#if this.matchDateStr}}
              <span class="text-white/30 text-[9px]">{{this.matchDateStr}}</span>
            {{/if}}
          </div>

        {{! ══════════════════════════════════════════════════════════════════
             STATE 3 — No match data yet: animated loader
        ══════════════════════════════════════════════════════════════════ }}
        {{else if this.isConnecting}}
          <div class="flex flex-col items-center justify-center flex-1 gap-5">
            <div class="relative flex items-center justify-center w-24 h-24">
              <div class="absolute inset-0 rounded-full border border-orange-500/50"
                   style="animation:ls-radar 2s ease-out infinite;"></div>
              <div class="absolute inset-0 rounded-full border border-orange-400/30"
                   style="animation:ls-radar 2s ease-out 0.65s infinite;"></div>
              <div class="absolute inset-0 rounded-full border border-orange-300/15"
                   style="animation:ls-radar 2s ease-out 1.3s infinite;"></div>
              <div class="absolute rounded-full border-2 border-dashed border-white/10 ls-spin-slow"
                   style="inset:-10px;"></div>
              <div class="absolute rounded-full border border-white/6 ls-spin-rev" style="inset:-3px;">
                <span class="absolute -top-1.5 left-1/2 -translate-x-1/2 w-2.5 h-2.5 rounded-full"
                      style="background:radial-gradient(circle,#f97316,#c2410c);box-shadow:0 0 6px #f97316aa;"></span>
              </div>
              <div class="relative w-14 h-14 rounded-full"
                   style="background:radial-gradient(circle at 38% 35%,#b91c1c,#3f0707);
                          box-shadow:0 0 24px rgba(239,68,68,0.3),inset 0 2px 5px rgba(255,255,255,0.12);">
                <svg class="absolute inset-0 w-full h-full" viewBox="0 0 56 56" fill="none">
                  <path d="M9 28 C9 15,28 9,28 9"     stroke="rgba(255,255,255,0.45)" stroke-width="1.3" stroke-linecap="round"></path>
                  <path d="M47 28 C47 41,28 47,28 47" stroke="rgba(255,255,255,0.45)" stroke-width="1.3" stroke-linecap="round"></path>
                  <path d="M12 22 L14 24" stroke="rgba(255,255,255,0.4)" stroke-width="0.9" stroke-linecap="round"></path>
                  <path d="M16 18 L18 20" stroke="rgba(255,255,255,0.4)" stroke-width="0.9" stroke-linecap="round"></path>
                  <path d="M21 14 L23 16" stroke="rgba(255,255,255,0.4)" stroke-width="0.9" stroke-linecap="round"></path>
                  <path d="M33 40 L35 42" stroke="rgba(255,255,255,0.4)" stroke-width="0.9" stroke-linecap="round"></path>
                  <path d="M38 36 L40 38" stroke="rgba(255,255,255,0.4)" stroke-width="0.9" stroke-linecap="round"></path>
                  <path d="M42 31 L44 33" stroke="rgba(255,255,255,0.4)" stroke-width="0.9" stroke-linecap="round"></path>
                </svg>
              </div>
            </div>
            <div class="flex flex-col items-center gap-2">
              <p class="text-white/25 text-[11px] font-black tracking-[0.22em] uppercase">Loading live score</p>
              <div class="flex gap-1.5">
                <span class="w-1.5 h-1.5 rounded-full bg-orange-500/60"
                      style="animation:ls-dot-hop 1.3s ease-in-out 0s infinite;"></span>
                <span class="w-1.5 h-1.5 rounded-full bg-orange-500/60"
                      style="animation:ls-dot-hop 1.3s ease-in-out 0.2s infinite;"></span>
                <span class="w-1.5 h-1.5 rounded-full bg-orange-500/60"
                      style="animation:ls-dot-hop 1.3s ease-in-out 0.4s infinite;"></span>
              </div>
            </div>
          </div>

        {{else if this.hasError}}
          <div class="flex flex-col items-center justify-center flex-1 gap-2 py-3">
            <p class="text-red-400/60 text-[12px] text-center leading-relaxed px-1">{{this.errorMessage}}</p>
          </div>

        {{else}}
          <div class="flex flex-col items-center justify-center flex-1 gap-1.5 py-3">
            <p class="text-white/15 text-[11px] text-center tracking-widest uppercase">No live data</p>
          </div>
        {{/if}}

      </div>
    </div>
  </template>
}
