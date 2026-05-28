import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { hash } from '@ember/helper';
import { LinkTo } from '@ember/routing';
import { service } from '@ember/service';
import Team from './TrendingCard/Team';
import Score from './TrendingCard/Score';
import config from 'spordium/config/environment';
import { onInit } from '../../utils/utility.helper';
import ShareButton from '../share-button';
import WatchLaterButton from '../watch-later-button';

function formatOvers(balls) {
  const fullOvers = Math.floor(balls);
  const remainingBalls = Math.round((balls - fullOvers) * 10);
  return `${fullOvers}.${remainingBalls}`;
}

function calcCRR(runs, overs) {
  if (runs == null || overs == null) return null;
  const n = typeof overs === 'string' ? parseFloat(overs) : overs;
  if (!n || isNaN(n)) return null;
  const full = Math.floor(n);
  const extra = Math.round((n - full) * 10);
  const totalBalls = full * 6 + extra;
  if (!totalBalls) return null;
  return ((runs / totalBalls) * 6).toFixed(2);
}

function formatDate(dateStr) {
  const d = new Date(dateStr);
  return d.toLocaleDateString('en-US', { day: 'numeric', month: 'short' });
}

export default class TrendingCard extends Component {
  @service websocket;

  bucket = config.APP.S3_BUCKET_URL;

  @tracked livePayload = null;
  @tracked viewerCount = null;
  @tracked _isLive = false;
  @tracked _isFinished = false;
  @tracked _shareMenuOpen = false;

  _wsUnlisten = null;

  constructor() {
    super(...arguments);
    this._isLive     = this.args.match?.is_start    ?? false;
    this._isFinished = this.args.match?.is_finished ?? false;
    this._setupLiveStream();
  }

  // ── WebSocket ──────────────────────────────────────────────────────────────

  _setupLiveStream() {
    const match = this.args.match;
    if (!match?.game_id || match?.is_finished) return;

    const id = String(match.game_id);

    this._wsUnlisten = this.websocket.on('*', (data) => {
      if (data?.status !== 'success' || !data?.payload) return;

      const receiverGameId = data.receiver?.split(':').pop();
      if (receiverGameId !== id) return;

      const payload = data.payload;
      const type = payload.type;

      if (type === 'viewer_count') {
        this.viewerCount = { live: payload.live ?? 0, total: payload.total ?? 0 };
        return;
      }

      // Status transitions
      if (payload.is_started !== undefined) this._isLive = payload.is_started;
      if (payload.is_finished) {
        this._isFinished = true;
        this._isLive = false;
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
    if (this._wsUnlisten) {
      this._wsUnlisten();
      this._wsUnlisten = null;
    }
  }

  // ── Getters ────────────────────────────────────────────────────────────────

  @action onStart(){
  }

  @action onShareMenuChange(isOpen) {
    this._shareMenuOpen = isOpen;
  }

  get isLive() {
    return this._isLive;
  }

  get isFinished() {
    return this._isFinished;
  }

  get showWatchLater() {
    return !this.isLive && !this.isFinished;
  }

  get matchName() {
    return this.args.match?.score?.name ?? 'Unknown Match';
  }

  get matchPrize() {
    const p = this.args.match?.score?.match_prize;
    return Number(p) > 0 ? p : null;
  }

  get teamA() {
    return this.args.match?.score?.batting?.team_name ?? 'Team A';
  }

  get teamB() {
    return this.args.match?.score?.fielding?.team_name ?? 'Team B';
  }

  get teamALogo() {
    return this.args.match?.score?.batting?.team_logo;
  }

  get teamBLogo() {
    return this.args.match?.score?.fielding?.team_logo;
  }

  get batting() {
    return this.args.match?.score?.batting;
  }

  get fielding() {
    return this.args.match?.score?.fielding;
  }

  get innings() {
    return this.args.match?.score?.innings;
  }

  get dateFormatted() {
    return formatDate(this.args.match?.datetime);
  }

  get battingOvers() {
    return formatOvers(this.batting?.balls ?? 0);
  }

  get fieldingOvers() {
    return formatOvers(this.fielding?.balls ?? 0);
  }

  get battingScoreClass() {
    return this.isBattingLeading ? 'text-white' : 'text-white/40';
  }

  get fieldingScoreClass() {
    return !this.isBattingLeading ? 'text-white' : 'text-white/40';
  }

  get crr() {
    const runs = this.displayBattingScore;
    const overs = this.livePayload?.over ?? this.batting?.balls ?? null;
    return calcCRR(runs, overs);
  }

  get battingSubtext() {
    const overs = (this.isLive && this.livePayload) ? this.displayBattingOvers : this.battingOvers;
    const crr = this.crr;
    if (this.isLive && crr) return `${overs} ov · CRR ${crr}`;
    if (this.isLive && this.innings === 1) return 'Batting';
    return `${overs} ov`;
  }

  get fieldingSubtext() {
    if (this.isLive && this.innings === 1) return 'Bowling';
    return `${this.fieldingOvers} ov`;
  }

  get matchId() {
    const m = this.args.match;
    return m?.game_id ?? m?.id ?? m?.score?.game_id ?? m?.score?.id;
  }

  // ── Payload normalizer ────────────────────────────────────────────────────
  //
  // Two distinct payload shapes arrive on match:details events.
  // This method collapses both into a single internal format so every
  // display getter stays simple and shape-agnostic.
  //
  // Shape A — "stricker_bowler_stats" (isScoreboardData: true)
  //   payload.bowling.runsgiven    → team runs
  //   payload.bowling.oversbowled  → team overs (number, e.g. 0.4)
  //   payload.bowling.wicketstaken → team wickets
  //   payload.facing / runner have matchbatsman / runsscored / ballsfaced
  //
  // Shape B — ball-by-ball update (all scalars at top level)
  //   payload.run     → team runs    (string)
  //   payload.over    → team overs   (string, e.g. "0.4")
  //   payload.wicket  → team wickets (string)
  //   payload.facing / runner are plain {id, name}
  //   payload.runnerScore / runnerBallPlayed carry runner stats
  //   payload.bowling is plain {id, name}

  _normalizePayload(raw) {
    if (!raw) return null;

    // ── Shape A ──────────────────────────────────────────────────────────────
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

    // ── Shape B ──────────────────────────────────────────────────────────────
    return {
      run:    raw.run    != null ? parseInt(raw.run,    10) : null,
      over:   raw.over   != null ? parseFloat(raw.over)     : null,
      wicket: raw.wicket != null ? parseInt(raw.wicket, 10) : null,
      striker: raw.facing ? {
        name:  raw.facing.name ?? null,
        runs:  null,   // not provided in Shape B
        balls: null,
      } : null,
      runner: raw.runner ? {
        name:  raw.runner.name           ?? null,
        runs:  raw.runnerScore           ?? null,
        balls: raw.runnerBallPlayed      ?? null,
      } : null,
      bowler: raw.bowling?.name ?? null,
    };
  }

  // ── Display getters (read from normalised livePayload) ────────────────────

  get hasLiveDetails() {
    return this.isLive && this.livePayload !== null;
  }

  get displayBattingScore() {
    return this.livePayload?.run ?? this.batting?.livescore;
  }

  get displayBattingWickets() {
    return this.livePayload?.wicket ?? this.batting?.wicketstaken;
  }

  get displayBattingOvers() {
    const raw = this.livePayload?.over ?? this.batting?.balls ?? 0;
    return formatOvers(raw);
  }

  // Colour classes react to live score
  get isBattingLeading() {
    return (this.displayBattingScore ?? 0) >= (this.fielding?.livescore ?? 0);
  }

  // ── Now-playing strip ──────────────────────────────────────────────────────

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
      @query={{hash gameid=this.matchId}}
      class="block relative rounded-2xl mb-3 no-underline
             {{if this._shareMenuOpen 'z-50' 'z-0'}}
             bg-gradient-to-br from-white/[0.11] via-white/[0.07] to-white/[0.03]
             backdrop-blur-md
             border border-white/[0.14]
             shadow-[0_4px_24px_rgba(0,0,0,0.30),inset_0_1px_0_rgba(255,255,255,0.10)]
             hover:shadow-[0_8px_36px_rgba(0,0,0,0.40),inset_0_1px_0_rgba(255,255,255,0.14)]
             hover:border-white/[0.22]
             hover:-translate-y-0.5
             transition-all duration-200 cursor-pointer"
      ...attributes
    >
      {{! ── Live accent stripe on the left edge ── }}
      {{#if this.isLive}}
        <div
          class="absolute left-0 top-4 bottom-4 w-[3px] rounded-full
                 bg-gradient-to-b from-emerald-400/80 via-emerald-400 to-emerald-400/80
                 shadow-[0_0_8px_rgba(52,211,153,0.7)]"
        ></div>
      {{/if}}

      <div class="px-3 py-3 sm:px-5 sm:py-4" {{onInit this.onStart}}>

        {{! ── Top Meta ── }}
        <div class="flex items-center justify-between gap-2 mb-2.5 sm:mb-4">

          {{! Left: status badge + match name + viewer count }}
          <div class="flex items-center gap-1.5 sm:gap-2 min-w-0 flex-1">
            {{#if this.isLive}}
              <span
                class="inline-flex items-center gap-1
                       bg-emerald-500/20 text-emerald-300
                       border border-emerald-400/40
                       shadow-[0_0_10px_rgba(52,211,153,0.25)]
                       font-semibold text-[9px] tracking-widest uppercase
                       px-2 py-0.5 sm:px-2.5 sm:py-1 rounded-full shrink-0"
              >
                <span class="w-[5px] h-[5px] bg-emerald-400 rounded-full animate-pulse
                             shadow-[0_0_4px_rgba(52,211,153,0.9)]">
                </span>
                Live
              </span>
            {{else}}
              <span
                class="inline-flex items-center
                       bg-white/[0.08] text-white/40
                       border border-white/[0.12]
                       text-[9px] tracking-widest uppercase
                       px-2 py-0.5 sm:px-2.5 sm:py-1 rounded-full shrink-0"
              >
                Ended
              </span>
            {{/if}}

            <span class="text-white/60 text-[10px] sm:text-[11px] font-medium truncate">
              {{this.matchName}}
            </span>
            {{#if this.viewerCount}}
              <span class="hidden xs:inline-flex items-center gap-1 sm:gap-1.5 px-1.5 sm:px-2 py-0.5 bg-white/[0.07] border border-white/[0.10] rounded-full text-[9px] font-medium text-white/50 shrink-0">
                <svg class="w-2 h-2 sm:w-2.5 sm:h-2.5 text-red-400" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5zM12 17c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3z"/>
                </svg>
                <span class="text-red-400">{{this.viewerCount.live}}</span>
                <span class="text-white/20">·</span>
                {{this.viewerCount.total}}
              </span>
            {{/if}}
          </div>

          {{! Right: date + prize + actions }}
          <div class="flex items-center gap-1 sm:gap-1.5 shrink-0 text-[9px] sm:text-[10px] font-medium">
            <span class="text-white/45 hidden sm:inline">{{this.dateFormatted}}</span>
            {{#if this.matchPrize}}
              <span
                class="text-amber-300 font-bold
                       bg-amber-400/10 border border-amber-400/20
                       px-1.5 py-0.5 rounded-md"
              >৳{{this.matchPrize}}</span>
            {{/if}}
            <ShareButton @matchId={{this.matchId}} @matchName={{this.matchName}} @matchDate={{this.dateFormatted}} @isLive={{this.isLive}} @sportType={{@match.sportstype}} @onMenuChange={{this.onShareMenuChange}} />
            {{#unless this.isLive}}
              <WatchLaterButton
                @matchId={{this.matchId}}
                @matchType={{@match.match_type}}
              />
            {{/unless}}
          </div>
        </div>

        {{! Date row on xs (shown only when date is hidden in top row) }}
        <div class="flex items-center gap-1.5 mb-2 sm:hidden">
          <span class="text-white/35 text-[9px]">{{this.dateFormatted}}</span>
          {{#if this.viewerCount}}
            <span class="inline-flex items-center gap-1 px-1.5 py-0.5 bg-white/[0.07] border border-white/[0.10] rounded-full text-[9px] font-medium text-white/50">
              <svg class="w-2 h-2 text-red-400" fill="currentColor" viewBox="0 0 24 24">
                <path d="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5zM12 17c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3z"/>
              </svg>
              <span class="text-red-400">{{this.viewerCount.live}}</span>
              <span class="text-white/20">·</span>
              {{this.viewerCount.total}}
            </span>
          {{/if}}
        </div>

        {{! ── Teams + Scores Row ── }}
        <div class="flex items-center justify-between gap-1.5 sm:gap-3">

          {{! Left Team (Batting) }}
          <Team
            @name={{this.teamA}}
            @logo={{this.teamALogo}}
            @subtext={{this.battingSubtext}}
            @bucket={{this.bucket}}
          />

          {{! Score pill ── hero element }}
          <div
            class="flex items-center gap-1.5 sm:gap-3 px-2 sm:px-4 py-1.5 sm:py-2 shrink-0
                   bg-black/30 rounded-xl
                   border border-white/[0.09]
                   shadow-[inset_0_1px_0_rgba(255,255,255,0.06),0_2px_12px_rgba(0,0,0,0.3)]"
          >
            <Score
              @score={{this.displayBattingScore}}
              @wickets={{this.displayBattingWickets}}
              @colorClass={{this.battingScoreClass}}
              @alignClass="text-right"
            />

            <div class="flex flex-col items-center gap-[3px]">
              <div class="w-px h-3 bg-gradient-to-b from-transparent via-white/25 to-transparent"></div>
              <span class="text-[7px] font-black tracking-[0.12em] text-white/25 uppercase">vs</span>
              <div class="w-px h-3 bg-gradient-to-b from-transparent via-white/25 to-transparent"></div>
            </div>

            <Score
              @score={{this.fielding.livescore}}
              @wickets={{this.fielding.wicketstaken}}
              @colorClass={{this.fieldingScoreClass}}
              @alignClass="text-left"
            />
          </div>

          {{! Right Team (Fielding) }}
          <Team
            @name={{this.teamB}}
            @logo={{this.teamBLogo}}
            @subtext={{this.fieldingSubtext}}
            @bucket={{this.bucket}}
            @reverse={{true}}
          />

        </div>

        {{! ── Live Now-Playing Strip ── }}
        {{#if this.hasLiveDetails}}
          <div
            class="mt-2.5 sm:mt-3 -mx-3 -mb-3 px-3 py-2 sm:-mx-5 sm:-mb-4 sm:px-5
                   bg-black/20
                   border-t border-white/[0.07]
                   flex items-center justify-between gap-2 sm:gap-3
                   text-[9px] sm:text-[10px] font-medium"
          >
            {{! Batsmen }}
            <div class="flex items-center gap-1.5 sm:gap-2 min-w-0 text-white/60">
              <span
                class="shrink-0 text-[8px] font-bold tracking-widest uppercase
                       text-emerald-400/70 bg-emerald-500/10
                       border border-emerald-400/20 px-1.5 py-0.5 rounded"
              >Bat</span>
              <span class="truncate text-white/65">
                {{this.liveStrikerText}}
                {{#if this.liveRunnerText}}
                  <span class="text-white/25 mx-1">·</span>
                  <span class="text-white/45">{{this.liveRunnerText}}</span>
                {{/if}}
              </span>
            </div>

            {{! Bowler }}
            <div class="flex items-center gap-1 sm:gap-1.5 shrink-0 text-white/60">
              <span
                class="text-[8px] font-bold tracking-widest uppercase
                       text-sky-400/70 bg-sky-500/10
                       border border-sky-400/20 px-1.5 py-0.5 rounded"
              >Bowl</span>
              <span class="text-white/65 truncate max-w-[80px] sm:max-w-none">{{this.liveBowlerText}}</span>
            </div>
          </div>
        {{/if}}

      </div>
    </LinkTo>
  </template>
}
