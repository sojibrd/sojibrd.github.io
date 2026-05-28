import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { service } from '@ember/service';
import { hash } from '@ember/helper';
import { eq } from 'ember-truth-helpers';
import { LinkTo } from '@ember/routing';
import ShareButton from '../share-button';
import WatchLaterButton from '../watch-later-button';

function fmtDateTime(dateStr) {
  if (!dateStr) return '';
  const d    = new Date(dateStr);
  const day  = d.toLocaleDateString('en-GB', { day: 'numeric', month: 'short' });
  const time = d.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: true });
  return `${day} · ${time}`;
}

function formatOvers(raw) {
  if (raw == null) return null;
  const full  = Math.floor(raw);
  const balls = Math.round((raw - full) * 10);
  return `${full}.${balls}`;
}

function calcCRR(runs, overs) {
  if (runs == null || overs == null) return null;
  const n = typeof overs === 'string' ? parseFloat(overs) : overs;
  if (!n || isNaN(n)) return null;
  const full       = Math.floor(n);
  const extra      = Math.round((n - full) * 10);
  const totalBalls = full * 6 + extra;
  if (!totalBalls) return null;
  return ((runs / totalBalls) * 6).toFixed(2);
}

export default class NearbyMatchCard extends Component {
  @service websocket;

  @tracked livePayload  = null;
  @tracked viewerCount  = null;
  @tracked _isLive      = false;
  @tracked _isFinished  = false;

  _wsUnlisten = null;

  constructor() {
    super(...arguments);
    this._isLive     = this.args.match?.isLive     ?? false;
    this._isFinished = this.args.match?.isFinished  ?? false;
    this._setupWs();
  }

  _setupWs() {
    const match = this.args.match;
    if (!match?.id || match?.isFinished) return;

    const id = String(match.id);

    this._wsUnlisten = this.websocket.on('*', (data) => {
      if (data?.status !== 'success' || !data?.payload) return;

      const receiverGameId = data.receiver?.split(':').pop();
      if (receiverGameId !== id) return;

      const payload = data.payload;
      const type    = payload.type;

      if (type === 'viewer_count') {
        this.viewerCount = { live: payload.live ?? 0, total: payload.total ?? 0 };
        return;
      }

      if (payload.is_started !== undefined) this._isLive = payload.is_started;
      if (payload.is_finished) {
        this._isFinished = true;
        this._isLive     = false;
        this._wsUnlisten?.();
        this._wsUnlisten = null;
        return;
      }

      const isScoreEvent =
        type === 'match_score' ||
        type === 'stricker_bowler_stats' ||
        payload.isScoreboardData === true;

      if (isScoreEvent) {
        this.livePayload = this._normalizePayload(payload);
      }
    });
  }

  willDestroy() {
    super.willDestroy();
    this._wsUnlisten?.();
    this._wsUnlisten = null;
  }

  _normalizePayload(raw) {
    if (!raw) return null;

    if (raw.isScoreboardData === true) {
      const b = raw.bowling ?? {};
      return {
        run:    b.runsgiven    ?? null,
        over:   b.oversbowled  ?? null,
        wicket: b.wicketstaken ?? null,
        striker: raw.facing ? {
          name:  raw.facing.matchbatsman?.name ?? null,
          runs:  raw.facing.runsscored         ?? null,
          balls: raw.facing.ballsfaced          ?? null,
        } : null,
        runner: raw.runner ? {
          name:  raw.runner.matchbatsman?.name ?? null,
          runs:  raw.runner.runsscored         ?? null,
          balls: raw.runner.ballsfaced          ?? null,
        } : null,
        bowler: raw.bowling?.matchbowler?.name ?? null,
      };
    }

    return {
      run:    raw.run    != null ? parseInt(raw.run,    10) : null,
      over:   raw.over   != null ? parseFloat(raw.over)     : null,
      wicket: raw.wicket != null ? parseInt(raw.wicket, 10) : null,
      striker: raw.facing ? {
        name:  raw.facing.name ?? null,
        runs:  null,
        balls: null,
      } : null,
      runner: raw.runner ? {
        name:  raw.runner.name      ?? null,
        runs:  raw.runnerScore      ?? null,
        balls: raw.runnerBallPlayed ?? null,
      } : null,
      bowler: raw.bowling?.name ?? null,
    };
  }

  get isLive()     { return this._isLive || this.livePayload !== null || this.viewerCount !== null; }
  get isFinished() { return this._isFinished; }

  get displayBattingScore() {
    return this.livePayload?.run ?? this.args.match?.batting?.livescore ?? null;
  }

  get displayBattingWickets() {
    return this.livePayload?.wicket ?? this.args.match?.batting?.wickets ?? null;
  }

  get displayBattingOvers() {
    return formatOvers(this.livePayload?.over ?? this.args.match?.batting?.balls ?? null);
  }

  get displayFieldingScore() {
    return this.args.match?.fielding?.livescore ?? null;
  }

  get crr() {
    return calcCRR(this.displayBattingScore, this.livePayload?.over ?? this.args.match?.batting?.balls ?? null);
  }

  get scoreStr() {
    const r = this.displayBattingScore;
    const w = this.displayBattingWickets;
    if (r == null) return null;
    return w != null ? `${r}/${w}` : `${r}`;
  }

  get hasScore() {
    return this.scoreStr != null;
  }

  get hasLiveDetails() {
    return this._isLive && this.livePayload !== null;
  }

  get liveStrikerText() {
    const s = this.livePayload?.striker;
    if (!s?.name) return '';
    if (s.runs != null) return `${s.name}  ${s.runs}(${s.balls ?? 0})`;
    return s.name;
  }

  get liveRunnerText() {
    const r = this.livePayload?.runner;
    if (!r?.name) return '';
    if (r.runs != null) return `${r.name}  ${r.runs}(${r.balls ?? 0})`;
    return r.name;
  }

  get liveBowlerText() {
    const name = this.livePayload?.bowler;
    if (!name) return '';
    return `${name}  ${this.displayBattingOvers}-${this.displayBattingScore ?? 0}`;
  }

  <template>
    <LinkTo
      @route="match.match-details"
      @query={{hash gameid=@match.id}}
      class="block relative rounded-xl border border-white/[0.07]
             bg-white/[0.04] hover:bg-white/[0.08]
             hover:border-white/[0.14]
             transition-all duration-150 no-underline
             {{if (eq @openShareId @match.id) 'z-50' 'z-0'}}">

      <div class="px-4 py-3">
        {{! Top row: badge + viewer count + date + actions }}
        <div class="flex items-center justify-between mb-2.5">
          {{#if this.isLive}}
            <span class="inline-flex items-center gap-1
                         text-[9px] font-bold tracking-[0.12em] uppercase
                         text-emerald-300 bg-emerald-500/20 border border-emerald-400/40
                         shadow-[0_0_8px_rgba(52,211,153,0.2)]
                         px-2 py-0.5 rounded">
              <span class="w-[5px] h-[5px] bg-emerald-400 rounded-full animate-pulse
                           shadow-[0_0_4px_rgba(52,211,153,0.9)]"></span>
              Live
            </span>
          {{else if this.isFinished}}
            <span class="text-[9px] font-bold tracking-[0.12em] uppercase
                         text-white/30 bg-white/[0.06] border border-white/[0.08]
                         px-2 py-0.5 rounded">Ended</span>
          {{else}}
            <span class="text-[9px] font-bold tracking-[0.12em] uppercase
                         text-white/35 bg-white/[0.07] border border-white/[0.08]
                         px-2 py-0.5 rounded">Match</span>
          {{/if}}

          <div class="flex items-center gap-1">
            {{#if this.viewerCount}}
              <span class="inline-flex items-center gap-1 px-1.5 py-0.5
                           bg-white/[0.07] border border-white/[0.10]
                           rounded-full text-[9px] font-medium text-white/50">
                <svg class="w-2 h-2 text-red-400" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5zM12 17c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3z"/>
                </svg>
                <span class="text-red-400">{{this.viewerCount.live}}</span>
                <span class="text-white/20">·</span>
                {{this.viewerCount.total}}
              </span>
            {{/if}}
            <span class="text-[10px] text-white/35 mr-1">
              {{fmtDateTime @match.datetime}}
            </span>
            <ShareButton
              @matchId={{@match.id}}
              @matchName={{@match.name}}
              @matchDate={{fmtDateTime @match.datetime}}
              @isLive={{this.isLive}}
              @sportType={{@match.sportType}}
              @onMenuChange={{@onShareMenuChange}}
            />
            {{#unless this.isLive}}
              <WatchLaterButton @matchId={{@match.id}} @matchType={{@match.matchType}} />
            {{/unless}}
          </div>
        </div>

        {{! Teams row }}
        <div class="flex items-center gap-2">
          {{! Team 1 }}
          <div class="flex items-center gap-2 flex-1 min-w-0">
            {{#if @match.team1.logo}}
              <img src={{@match.team1.logo}} alt={{@match.team1.name}}
                class="w-7 h-7 rounded-full object-cover flex-shrink-0 bg-white/10" />
            {{else}}
              <div class="w-7 h-7 rounded-full bg-white/10 flex-shrink-0 flex items-center justify-center">
                <span class="text-white/50 text-[10px] font-bold">{{@match.team1.initial}}</span>
              </div>
            {{/if}}
            <span class="text-white text-[13px] font-semibold truncate">{{@match.team1.name}}</span>
          </div>

          <span class="text-white/25 text-[10px] font-bold tracking-widest flex-shrink-0">VS</span>

          {{! Team 2 }}
          <div class="flex items-center gap-2 flex-1 min-w-0 justify-end">
            <span class="text-white text-[13px] font-semibold truncate text-right">{{@match.team2.name}}</span>
            {{#if @match.team2.logo}}
              <img src={{@match.team2.logo}} alt={{@match.team2.name}}
                class="w-7 h-7 rounded-full object-cover flex-shrink-0 bg-white/10" />
            {{else}}
              <div class="w-7 h-7 rounded-full bg-white/10 flex-shrink-0 flex items-center justify-center">
                <span class="text-white/50 text-[10px] font-bold">{{@match.team2.initial}}</span>
              </div>
            {{/if}}
          </div>
        </div>

        {{! Live score row (game-list style) }}
        {{#if this.hasScore}}
          <div class="flex items-center gap-1.5 mt-2 flex-wrap">
            <span class="text-white font-bold text-[13px] tabular-nums">{{this.scoreStr}}</span>
            {{#if this.displayBattingOvers}}
              <span class="text-white/40 text-[11px]">({{this.displayBattingOvers}} ov)</span>
            {{/if}}
            {{#if this.crr}}
              <span class="text-white/25 text-[10px]">·</span>
              <span class="text-emerald-400 text-[11px] font-medium">CRR {{this.crr}}</span>
            {{/if}}
          </div>
        {{/if}}
      </div>

      {{! Live now-playing strip }}
      {{#if this.hasLiveDetails}}
        <div class="px-4 py-2 bg-black/20 border-t border-white/[0.07] rounded-b-xl
                    flex items-center justify-between gap-2
                    text-[9px] font-medium">
          <div class="flex items-center gap-1.5 min-w-0 text-white/60">
            <span class="shrink-0 text-[8px] font-bold tracking-widest uppercase
                         text-emerald-400/70 bg-emerald-500/10
                         border border-emerald-400/20 px-1.5 py-0.5 rounded">Bat</span>
            <span class="truncate text-white/65">
              {{this.liveStrikerText}}
              {{#if this.liveRunnerText}}
                <span class="text-white/25 mx-1">·</span>
                <span class="text-white/45">{{this.liveRunnerText}}</span>
              {{/if}}
            </span>
          </div>
          <div class="flex items-center gap-1 shrink-0 text-white/60">
            <span class="text-[8px] font-bold tracking-widest uppercase
                         text-sky-400/70 bg-sky-500/10
                         border border-sky-400/20 px-1.5 py-0.5 rounded">Bowl</span>
            <span class="text-white/65 truncate max-w-[80px]">{{this.liveBowlerText}}</span>
          </div>
        </div>
      {{/if}}

    </LinkTo>
  </template>
}
