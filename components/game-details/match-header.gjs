import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { fn, get } from '@ember/helper';
import { eq, not, or } from 'ember-truth-helpers';
import { service } from '@ember/service';
import config from 'spordium/config/environment';
import AppDownloadModal from 'spordium/components/ui/app-download-modal';
import SwitchScorerModal from 'spordium/components/ui/switch-scorer-modal';
import RescheduleModal from 'spordium/components/ui/reschedule-modal';
import SelectRoleModal from 'spordium/components/ui/select-role-modal';
import SelectStartPlayersModal from 'spordium/components/ui/select-start-players-modal';
import ShareButton from 'spordium/components/share-button';
import WatchLaterButton from 'spordium/components/watch-later-button';

const SEARCH_API_HOST = config.APP.SEARCH_API_HOST;

class MatchHeaderComponent extends Component {
  @service store;
  @service session;
  @service router;
  @service api;
  @service toast;
  @service websocket;

  _wsUnlisten = null;
  _wsDebounceTimers = {};

  constructor(owner, args) {
    super(owner, args);
    if (this.isPreMatch) {
      this.loadAllCounts();
      this.loadPlayersAssigned();
      this._wsUnlisten = this.websocket.on('*', this._onWsMessage);
    }
  }

  willDestroy() {
    super.willDestroy();
    this._wsUnlisten?.();
    Object.values(this._wsDebounceTimers).forEach(clearTimeout);
  }

  _onWsMessage = (data) => {
    const payload = data?.payload ?? data;
    const type = payload?.notification_type || payload?.type;

    if (type === 'umpire_response') this._debounceRefresh('umpire', this.loadAcceptedOfficialCount);
    if (type === 'scorer_response' || type === 'active_scorer_request_response') this._debounceRefresh('scorer', this.loadAcceptedScorerCount);
    if (type === 'streamer_response') this._debounceRefresh('streamer', this.loadAcceptedStreamerCount);
  };

  _debounceRefresh(key, fn) {
    clearTimeout(this._wsDebounceTimers[key]);
    this._wsDebounceTimers[key] = setTimeout(() => fn.call(this), 300);
  }

  @tracked isMenuOpen = false;
  @tracked showGameOfficialModal = false;
  @tracked acceptedOfficialCount = 0;
  @tracked showScorerModal = false;
  @tracked acceptedScorerCount = 0;
  @tracked showStreamerModal = false;
  @tracked acceptedStreamerCount = 0;
  @tracked playersAssigned = false;
  @tracked playerSelections = {};
  @tracked showSelectPlayersModal = false;
  @tracked isStartMatchFlow = false;
  @tracked showStartNextModal = false;
  @tracked showStartWarning = false;
  @tracked startWarningErrors = [];
  @tracked isCheckingStart = false;
  @tracked isStarting = false;
  @tracked showAppDownload = false;
  @tracked appDownloadItem = null;
  @tracked showSwitchScorer = false;
  @tracked isAskingScorer = false;
  @tracked showResetConfirm = false;
  @tracked isResetting = false;
  @tracked showAbandonOptions = false;
  @tracked showAbandonConfirm = false;
  @tracked showReschedule = false;
  @tracked abandonReason = '';
  @tracked isAbandoning = false;

  get currentUserId() {
    return this.session.currentUser?.user_id;
  }

  get isScorer() {
    const scorers = this.args.model?.gameScorer;
    if (!this.currentUserId || !Array.isArray(scorers)) return false;
    const id = String(this.currentUserId);
    return scorers.some(
      (s) =>
        String(s?.id) === id ||
        String(s?.user_id) === id ||
        (typeof s === 'string' && s === id)
    );
  }

  get isActiveScorer() {
    if (!this.currentUserId) return false;
    return String(this.args.model?.activeScorrer) === String(this.currentUserId);
  }

  get isOwner() {
    if (!this.currentUserId) return false;
    return this.args.model?.gameOwner === this.currentUserId;
  }

  get isPreMatch() {
    const model = this.args.model;
    return this.isOwner && !model?.isStarted && !model?.isFinished && !model?.isApproving;
  }

  get umpireReady() {
    return this.acceptedOfficialCount >= 2;
  }

  get scorerReady() {
    return this.acceptedScorerCount >= 2;
  }

  get streamerReady() {
    return this.acceptedStreamerCount >= 1;
  }

  get mandatoryReady() {
    return this.umpireReady && this.scorerReady;
  }

  @action
  openGameOfficialModal() {
    this.showGameOfficialModal = true;
  }

  @action
  closeGameOfficialModal() {
    this.showGameOfficialModal = false;
    this.loadAcceptedOfficialCount();
  }

  @action
  onGameOfficialSelected() {}

  async loadAllCounts() {
    const gameId = this.args.model?.id;
    if (!gameId) return;
    try {
      const [officials, scorers, streamers] = await Promise.all([
        this.store.query('accepted-role-person', { game_id: gameId, role: 'CricketUmipire' }),
        this.store.query('accepted-role-person', { game_id: gameId, role: 'CricketScorer' }),
        this.store.query('accepted-role-person', { game_id: gameId, role: 'CricketVideoStreamer' }),
      ]);
      this.acceptedOfficialCount = officials.filter((r) => r.status === 'accepted').length;
      this.acceptedScorerCount = scorers.filter((r) => r.status === 'accepted').length;
      this.acceptedStreamerCount = streamers.filter((r) => r.status === 'accepted').length;
    } catch {
      // keep existing counts
    }
  }

  async loadAcceptedOfficialCount() {
    const gameId = this.args.model?.id;
    if (!gameId) return;
    try {
      const results = await this.store.query('accepted-role-person', {
        game_id: gameId,
        role: 'CricketUmipire',
      });
      this.acceptedOfficialCount = results.filter((r) => r.status === 'accepted').length;
    } catch {
      // keep existing count
    }
  }

  @action
  openScorerModal() {
    this.showScorerModal = true;
  }

  @action
  closeScorerModal() {
    this.showScorerModal = false;
    this.loadAcceptedScorerCount();
  }

  @action
  onScorerRoleSelected() {}

  async loadAcceptedScorerCount() {
    const gameId = this.args.model?.id;
    if (!gameId) return;
    try {
      const results = await this.store.query('accepted-role-person', {
        game_id: gameId,
        role: 'CricketScorer',
      });
      this.acceptedScorerCount = results.filter((r) => r.status === 'accepted').length;
    } catch {
      // keep existing count
    }
  }

  @action
  openStreamerModal() {
    this.showStreamerModal = true;
  }

  @action
  closeStreamerModal() {
    this.showStreamerModal = false;
    this.loadAcceptedStreamerCount();
  }

  @action
  onStreamerRoleSelected() {}

  async loadAcceptedStreamerCount() {
    const gameId = this.args.model?.id;
    if (!gameId) return;
    try {
      const results = await this.store.query('accepted-role-person', {
        game_id: gameId,
        role: 'CricketVideoStreamer',
      });
      this.acceptedStreamerCount = results.filter((r) => r.status === 'accepted').length;
    } catch {
      // keep existing count
    }
  }

  async loadPlayersAssigned() {
    const gameId = this.args.model?.id;
    const team1Id = this.args.model?.team1?.id;
    const team2Id = this.args.model?.team2?.id;
    if (!gameId || (!team1Id && !team2Id)) return;

    const fetchOne = async (teamId) => {
      if (!teamId) return [teamId, null];
      try {
        const res = await this.api.get('/live_scoring/playing-player/', { game_id: gameId, team_id: teamId });
        const data = res?.data;
        if (!data?.start_players?.length) return [teamId, null];
        return [teamId, {
          count: data.start_players.length,
          hasCaptain: !!data.captain_id,
          hasViceCaptain: !!data.vice_captain_id,
          hasWicketKeeper: !!(data.wicket_keeper || data.wicket_keeper_id),
          data: { ...data, wicket_keeper_id: data.wicket_keeper || data.wicket_keeper_id || null },
        }];
      } catch {
        return [teamId, null];
      }
    };

    try {
      const [[, r1], [, r2]] = await Promise.all([fetchOne(team1Id), fetchOne(team2Id)]);
      const selections = {};
      if (r1) selections[team1Id] = r1;
      if (r2) selections[team2Id] = r2;
      this.playerSelections = selections;
      this.playersAssigned = [team1Id, team2Id].filter(Boolean).every((id) => !!selections[id]);
    } catch {
      // keep existing state
    }
  }

  get hasFixableWarning() {
    return this.startWarningErrors.some((e) => e === 'umpire' || e === 'scorer');
  }

  @action
  async startMatch() {
    if (!this.mandatoryReady) {
      const errors = [];
      if (!this.umpireReady) errors.push('umpire');
      if (!this.scorerReady) errors.push('scorer');
      this.startWarningErrors = errors;
      this.showStartWarning = true;
      return;
    }
    if (this.isCheckingStart) return;
    this.isCheckingStart = true;
    try {
      const res = await this.api.post('/role/ckeck_role_ready_to_go/', {
        game_id: this.args.model?.id,
      });
      const data = res?.data;
      if (data?.ready_to_go === false && data?.error?.length) {
        this.startWarningErrors = data.error;
        this.showStartWarning = true;
      } else {
        // Open player selection as part of the start flow
        this.isStartMatchFlow = true;
        this.showSelectPlayersModal = true;
      }
    } catch {
      this.toast.error('Could not verify match readiness. Please try again.');
    } finally {
      this.isCheckingStart = false;
    }
  }

  async proceedStartMatch(data) {
    if (this.isStarting) return;
    this.isStarting = true;
    try {
      const model = this.args.model;
      const t1 = model?.team1;
      const t2 = model?.team2;
      const tosserIsBatting = data.battingChoice === 'batting';
      const battingTeam = (t1?.id === data.tossWinnerId) === tosserIsBatting ? t1 : t2;
      const bowlingTeam = battingTeam?.id === t1?.id ? t2 : t1;

      const battingPlayers = this.store.peekRecord('team-player', battingTeam?.id)?.players ?? [];
      const bowlingPlayers = this.store.peekRecord('team-player', bowlingTeam?.id)?.players ?? [];
      const findName = (players, id) => players.find((p) => p.id === id)?.name ?? '';

      const payload = {
        toss: { tossWinTeamId: data.tossWinnerId },
        battingteamid: battingTeam?.id,
        fildingteamid: bowlingTeam?.id,
        facing: { id: data.strikerId, name: findName(battingPlayers, data.strikerId) },
        runner: { id: data.nonStrikerId, name: findName(battingPlayers, data.nonStrikerId) },
        bowling: { id: data.bowlerId, name: findName(bowlingPlayers, data.bowlerId) },
        matchid: model?.id,
        game_official: data.umpireIds,
        game_livestreamer: data.streamerIds,
        game_scorer: data.scorerIds,
        bowlermaxover: String(data.maxBowlerOvers),
        active_scorrer: data.activeScorerId,
      };

      const res = await this.api.post('/live_scoring/start_match_game/', payload);
      const msg = res?.data?.message || res?.message || 'Match started successfully.';
      this.toast.success(msg);
      const cached = this.store.peekRecord('game-detail', this.args.model?.id);
      if (cached) this.store.unloadRecord(cached);
      this.router.refresh();
    } catch (e) {
      this.toast.error(e?.payload?.message || 'Failed to start match. Please try again.');
    } finally {
      this.isStarting = false;
    }
  }

  @action
  closeStartWarning() {
    const errors = [...this.startWarningErrors];
    this.showStartWarning = false;
    this.startWarningErrors = [];

    if (errors.includes('umpire')) {
      this.showGameOfficialModal = true;
    } else if (errors.includes('scorer')) {
      this.showScorerModal = true;
    }
  }

  @action
  openSelectPlayersModal() {
    this.showSelectPlayersModal = true;
  }

  @action
  closeSelectPlayersModal() {
    this.showSelectPlayersModal = false;
    this.isStartMatchFlow = false;
    this.loadPlayersAssigned();
  }

  @action
  onPlayersSelected(data = {}) {
    this.showSelectPlayersModal = false;
    this.loadPlayersAssigned();
    if (this.isStartMatchFlow) {
      this.isStartMatchFlow = false;
      this.proceedStartMatch(data);
    }
  }

  get isInningsStart() {
    const model = this.args.model;
    if (!model?.isStarted) return false;
    const balls = model.livescore?.batting?.balls ?? model.livescore?.balls;
    return (balls ?? 0) === 0;
  }

  get menuItems() {
    const isStarted = this.args.model?.isStarted;
    const isFinished = this.args.model?.isFinished;
    const hasDisposition = !!this.args.model?.gameFinishDisposition?.matchstatus;

    const isApproving = this.args.model?.isApproving;

    // Approval pending — only scoreboard
    if (isApproving) return ['Match Scoreboard'];

    // Match not started and not finished — no menu
    if (!isStarted && !isFinished && !hasDisposition) return [];

    // Match finished or abandoned — only scoreboard
    if (isFinished || hasDisposition) return ['Match Scoreboard'];

    // Case 4: Active scorer + start of innings
    if (this.isActiveScorer && this.isInningsStart) {
      return [
        'Input Score',
        'Input Players In Field',
        'Match Abandoned',
        'Match Scoreboard',
        'Reset Match',
        'Switch Active Scorer',
        'Change Batsman',
        'Change Striker',
        'Change Bowler',
      ];
    }

    // Case 3: Active scorer
    if (this.isActiveScorer) {
      return [
        'Input Score',
        'Input Players In Field',
        'Match Abandoned',
        'Match Scoreboard',
        'Reset Match',
        'Switch Active Scorer',
      ];
    }

    // Case 2: Scorer but not active scorer
    if (this.isScorer && !this.isActiveScorer) {
      const items = ['View Players In Field', 'Match Scoreboard'];
      if (this.args.model?.activeScorrer) items.push('Ask to be an Active Scorer');
      return items;
    }

    // Case 1: Guest or logged in but no relation with game
    return isStarted ? ['Match Scoreboard'] : [];
  }

  @action
  toggleMenu() {
    this.isMenuOpen = !this.isMenuOpen;
  }

  @action
  closeMenu() {
    this.isMenuOpen = false;
  }

  get appOnlyItems() {
    return [
      'View Players In Field',
      'Input Players In Field',
      'Input Score',
      'Change Bowler',
      'Change Striker',
      'Change Batsman',
    ];
  }

  @action
  onMenuItemClick(item) {
    this.isMenuOpen = false;
    if (item === 'Match Scoreboard') {
      const gameId = this.args.model?.id || this.args.model?.gameId;
      this.router.transitionTo('match.scoreboard', { queryParams: { id: gameId } });
    } else if (item === 'Switch Active Scorer') {
      this.showSwitchScorer = true;
    } else if (item === 'Ask to be an Active Scorer') {
      this.askToBeActiveScorer();
    } else if (item === 'Reset Match') {
      this.showResetConfirm = true;
    } else if (item === 'Match Abandoned') {
      this.showAbandonOptions = true;
    } else if (this.appOnlyItems.includes(item)) {
      this.appDownloadItem = item;
      this.showAppDownload = true;
    }
  }

  @action
  async askToBeActiveScorer() {
    if (this.isAskingScorer) return;
    const model = this.args.model;
    const activeScorerId = model?.activeScorrer;
    if (!activeScorerId) return;

    this.isAskingScorer = true;
    try {
      // Fetch active scorer info to get their name
      const idsParam = encodeURIComponent(JSON.stringify([activeScorerId]));
      const url = `${SEARCH_API_HOST}/search/cricket-role-details-by-id/?ids=${idsParam}&role=cricketscorer`;
      const response = await fetch(url);
      let scorerName = '';
      if (response.ok) {
        const data = await response.json();
        const list = Array.isArray(data) ? data : (data?.results || data?.data || []);
        const m = list[0] || {};
        const first = m?.user_fullname?.first_name || '';
        const last = m?.user_fullname?.last_name || '';
        scorerName = `${first} ${last}`.trim() || m?.user_username || m?.user_email || '';
      }

      const result = await this.api.post('/live_scoring/active-scorrer-request/', {
        target_user: activeScorerId,
        user_type: 'secondary_scorer',
        match_id: model?.id,
        match_name: model?.gameName,
        target_user_name: scorerName,
      });
      const msg = result?.message || result?.msg || 'Request sent successfully.';
      this.toast.success(msg);
    } catch (e) {
      const msg = e?.payload?.message || e?.payload?.msg || 'Failed to send request.';
      this.toast.error(msg);
    } finally {
      this.isAskingScorer = false;
    }
  }

  @action
  closeSwitchScorer() {
    this.showSwitchScorer = false;
  }

  @action
  closeResetConfirm() {
    this.showResetConfirm = false;
  }

  @action
  openReschedule() {
    this.showAbandonOptions = false;
    this.showReschedule = true;
  }

  @action
  closeReschedule() {
    this.showReschedule = false;
  }

  @action
  openSimpleAbandon() {
    this.showAbandonOptions = false;
    this.abandonReason = '';
    this.showAbandonConfirm = true;
  }

  @action
  closeAbandon() {
    this.showAbandonOptions = false;
    this.showAbandonConfirm = false;
    this.abandonReason = '';
  }


  @action
  updateAbandonReason(e) {
    this.abandonReason = e.target.value;
  }

  @action
  async confirmAbandon() {
    if (this.isAbandoning) return;
    this.isAbandoning = true;
    try {
      const model = this.args.model;
      const reason = this.abandonReason.trim();
      const disposition = reason ? `abandoned!(${reason})` : 'abandoned!()';
      const res = await this.api.post('/live_scoring/singlematch-finish-disposition/', {
        matchid: model?.id,
        finish_disposition: {
          matchstatus: 'abandoned',
          disposition,
        },
      });
      const msg = res?.data?.message || res?.message || 'Match abandoned.';
      this.toast.success(msg);
      this.showAbandonConfirm = false;
      this.router.refresh();
    } catch (e) {
      this.toast.error(e?.payload?.message || 'Failed to abandon match.');
    } finally {
      this.isAbandoning = false;
    }
  }

  @action
  async resetMatch() {
    if (this.isResetting) return;
    this.isResetting = true;
    try {
      const res = await this.api.post('/live_scoring/restart-single-match/', {
        matchid: this.args.model?.id,
      });
      const msg = res?.message || res?.data?.status || 'Match reset successfully.';
      this.toast.success(msg);
      this.showResetConfirm = false;
      this.router.refresh();
    } catch (e) {
      this.toast.error(e?.payload?.message || 'Failed to reset match.');
    } finally {
      this.isResetting = false;
    }
  }

  @action
  async onScorerSelected(scorer) {
    const model = this.args.model;
    try {
      await this.api.post('/live_scoring/active-scorrer-request/', {
        target_user: scorer.id,
        user_type: 'main_scorer',
        match_id: model?.id,
        match_name: model?.gameName,
        target_user_name: scorer.name,
      });
    } catch (e) {
      console.error('Failed to switch active scorer:', e);
    }
  }

  @action
  closeAppDownload() {
    this.showAppDownload = false;
    this.appDownloadItem = null;
  }

  <template>
    <div class="relative rounded-2xl border border-gray-200 dark:border-white/5 bg-white dark:bg-slate-900 px-4 pt-4 pb-3">

      {{! Tournament pill }}
      {{#if @model.tournamentName}}
        <div class="flex items-center gap-1.5 mb-2.5">
          {{#if @model.tournamentLogo}}
            <img src={{@model.tournamentLogo}} alt="" class="w-4 h-4 rounded object-cover opacity-80" />
          {{/if}}
          <span class="text-xs font-semibold text-cyan-600 dark:text-cyan-400/80 uppercase tracking-wider">{{@model.tournamentName}}</span>
        </div>
      {{/if}}

      {{! Menu: top-right absolute — single label or kebab }}
      {{#if (not (or this.isResetting this.isAbandoning))}}
        {{#if (eq this.menuItems.length 1)}}
          <div class="absolute top-3 right-3">
            <button type="button"
              class="px-2.5 py-1 bg-gray-100 dark:bg-slate-700/80 hover:bg-gray-200 dark:hover:bg-slate-600 border border-gray-200 dark:border-white/5 text-gray-700 dark:text-slate-300 hover:text-gray-900 dark:hover:text-white text-xs font-semibold rounded-lg transition-colors"
              {{on "click" (fn this.onMenuItemClick (get this.menuItems "0"))}}>
              {{get this.menuItems "0"}}
            </button>
          </div>
        {{else if this.menuItems.length}}
          <div class="absolute top-3 right-3">
            <button type="button"
              class="w-7 h-7 flex items-center justify-center bg-gray-100 dark:bg-slate-700/80 hover:bg-gray-200 dark:hover:bg-slate-600 border border-gray-200 dark:border-white/5 rounded-lg transition-colors"
              {{on "click" this.toggleMenu}}>
              <svg class="w-4 h-4 text-gray-500 dark:text-slate-300" fill="currentColor" viewBox="0 0 20 20">
                <circle cx="10" cy="4" r="1.5"/><circle cx="10" cy="10" r="1.5"/><circle cx="10" cy="16" r="1.5"/>
              </svg>
            </button>
            {{#if this.isMenuOpen}}
              <div class="fixed inset-0 z-10" role="presentation" {{on "click" this.closeMenu}}></div>
              <div class="absolute right-0 mt-2 w-52 rounded-xl shadow-2xl z-20 overflow-hidden py-1 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-700">
                {{#each this.menuItems as |item|}}
                  <button type="button"
                    class="w-full text-left px-4 py-2.5 text-xs text-gray-700 dark:text-slate-200 hover:bg-gray-100 dark:hover:bg-slate-700 hover:text-gray-900 dark:hover:text-white transition-colors"
                    {{on "click" (fn this.onMenuItemClick item)}}>
                    {{item}}
                  </button>
                {{/each}}
              </div>
            {{/if}}
          </div>
        {{/if}}
      {{/if}}

      {{! Game name }}
      <h1 class="text-gray-900 dark:text-white font-bold leading-snug line-clamp-2 mb-2.5 pr-10 text-base sm:text-lg lg:text-xl">
        {{#if @model.gameName}}{{@model.gameName}}{{else}}Match{{/if}}
      </h1>

      {{! Row 1: type · date · venue }}
      <div class="flex items-center gap-2 flex-wrap mb-2">

        {{#if @model.typeOfGame}}
          <span class="inline-flex items-center gap-1 text-xs font-semibold text-gray-700 dark:text-white bg-gray-100 dark:bg-slate-600 px-2 py-0.5 rounded-full">
            🏏 {{@model.typeOfGame}}
          </span>
        {{/if}}

        {{#if @model.formattedDate}}
          <span class="inline-flex items-center gap-1 text-xs text-gray-500 dark:text-slate-400 bg-gray-100 dark:bg-white/5 px-2 py-0.5 rounded-full">
            <svg class="w-3 h-3 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
              <rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/>
            </svg>
            {{@model.formattedDate}}
            {{#if @model.formattedTime}}· {{@model.formattedTime}}{{/if}}
          </span>
        {{/if}}

        {{#if @model.fullVenue}}
          <span class="inline-flex items-center gap-1 text-xs text-gray-500 dark:text-slate-400 bg-gray-100 dark:bg-white/5 px-2 py-0.5 rounded-full">
            <svg class="w-3 h-3 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
              <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7z"/><circle cx="12" cy="9" r="2.5"/>
            </svg>
            {{#if @model.gameLivelink.maplink}}
              <a href={{@model.gameLivelink.maplink}} target="_blank" rel="noopener noreferrer" class="hover:text-amber-500 dark:hover:text-amber-400 transition-colors">{{@model.fullVenue}}</a>
            {{else}}
              <span>{{@model.fullVenue}}</span>
            {{/if}}
          </span>
        {{/if}}

      </div>

      {{! Row 2: match config chips }}
      <div class="flex items-center gap-2 flex-wrap mb-2">

        {{#if @model.totalOvers}}
          <span class="inline-flex items-center gap-1 text-xs text-gray-500 dark:text-slate-400 bg-gray-100 dark:bg-white/5 px-2 py-0.5 rounded-full">
            ⏱ {{@model.totalOvers}} Overs
          </span>
        {{/if}}

        {{#if @model.ballLabel}}
          <span class="inline-flex items-center gap-1 text-xs text-gray-500 dark:text-slate-400 bg-gray-100 dark:bg-white/5 px-2 py-0.5 rounded-full capitalize">
            🟤 {{@model.ballLabel}}
          </span>
        {{/if}}

        {{#if @model.playersPerSide}}
          <span class="inline-flex items-center gap-1 text-xs text-gray-500 dark:text-slate-400 bg-gray-100 dark:bg-white/5 px-2 py-0.5 rounded-full">
            👥 {{@model.playersPerSide}}-a-side
          </span>
        {{/if}}

        {{#if @model.bowlermaxover}}
          <span class="inline-flex items-center gap-1 text-xs text-gray-500 dark:text-slate-400 bg-gray-100 dark:bg-white/5 px-2 py-0.5 rounded-full">
            🎳 Max {{@model.bowlermaxover}} ov/bowler
          </span>
        {{/if}}

        {{#if @model.matchPrize}}
          <span class="inline-flex items-center gap-1 text-xs font-semibold text-amber-600 dark:text-amber-400 bg-amber-50 dark:bg-amber-400/10 px-2 py-0.5 rounded-full">
            🏆 {{@model.matchPrize}}
          </span>
        {{/if}}

      </div>

      {{! Row 3: toss }}
      {{#if @model.tossDescription}}
        <div class="flex items-center gap-2 flex-wrap mb-2">
          <span class="inline-flex items-center gap-1 text-xs text-gray-500 dark:text-slate-400 bg-gray-100 dark:bg-white/5 px-2 py-0.5 rounded-full">
            🪙 {{@model.tossDescription}}
          </span>
        </div>
      {{/if}}

      {{! Divider }}
      <div class="h-px bg-gray-200 dark:bg-white/5 mb-3"></div>

      {{! Actions row }}
      <div class="flex items-center gap-2 flex-wrap">

        {{! Share + Watch Later — always visible }}
        <div class="flex items-center gap-1.5 ml-auto">
          <ShareButton
            @matchId={{@model.id}}
            @matchName={{@model.gameName}}
            @matchDate={{@model.formattedDate}}
            @isLive={{@model.isStarted}}
            @sportType={{@model.sportType}}
            @dropUp={{true}}
          />
          {{#unless @model.isStarted}}
            {{#unless @model.isFinished}}
              <WatchLaterButton
                @matchId={{@model.id}}
                @matchType={{@model.sportType}}
              />
            {{/unless}}
          {{/unless}}
        </div>

        {{#if this.isPreMatch}}

          {{! Start button — primary CTA }}
          <button type="button"
            class="flex items-center gap-1.5 px-3.5 py-1.5 bg-emerald-600 hover:bg-emerald-500 active:bg-emerald-700 text-white text-xs font-bold rounded-lg transition-colors disabled:opacity-50 shadow-lg shadow-emerald-900/40"
            disabled={{or this.isCheckingStart this.isStarting}}
            {{on "click" this.startMatch}}>
            {{#if (or this.isCheckingStart this.isStarting)}}
              <span class="w-3 h-3 border-2 border-white/30 border-t-white rounded-full animate-spin"></span>
            {{/if}}
            {{if this.isStarting "Starting…" "Start Match"}}
          </button>

          {{! Secondary pre-match buttons }}
          <button type="button"
            class="px-2.5 py-1.5 text-xs font-medium rounded-lg transition-colors border
              {{if this.playersAssigned
                'bg-emerald-100 dark:bg-emerald-700/30 hover:bg-emerald-200 dark:hover:bg-emerald-700/50 text-emerald-700 dark:text-emerald-300 border-emerald-300 dark:border-emerald-600/50'
                'bg-gray-100 dark:bg-slate-700/80 hover:bg-gray-200 dark:hover:bg-slate-600 text-gray-700 dark:text-slate-300 border-gray-200 dark:border-white/5'}}"
            {{on "click" this.openSelectPlayersModal}}>
            Players
          </button>

          <button type="button"
            class="flex items-center gap-1.5 px-2.5 py-1.5 text-xs font-medium rounded-lg transition-colors border
              {{if this.umpireReady
                'bg-emerald-100 dark:bg-emerald-700/30 hover:bg-emerald-200 dark:hover:bg-emerald-700/50 text-emerald-700 dark:text-emerald-300 border-emerald-300 dark:border-emerald-600/50'
                'bg-gray-100 dark:bg-slate-700/80 hover:bg-gray-200 dark:hover:bg-slate-600 text-gray-700 dark:text-slate-300 border-gray-200 dark:border-white/5'}}"
            {{on "click" this.openGameOfficialModal}}>
            Umpire
            {{#if this.acceptedOfficialCount}}
              <span class="text-[9px] font-bold w-4 h-4 rounded-full flex items-center justify-center
                {{if this.umpireReady 'bg-emerald-600 text-white' 'bg-gray-800 dark:bg-slate-900 text-white'}}">{{this.acceptedOfficialCount}}</span>
            {{/if}}
          </button>

          <button type="button"
            class="flex items-center gap-1.5 px-2.5 py-1.5 text-xs font-medium rounded-lg transition-colors border
              {{if this.scorerReady
                'bg-emerald-100 dark:bg-emerald-700/30 hover:bg-emerald-200 dark:hover:bg-emerald-700/50 text-emerald-700 dark:text-emerald-300 border-emerald-300 dark:border-emerald-600/50'
                'bg-gray-100 dark:bg-slate-700/80 hover:bg-gray-200 dark:hover:bg-slate-600 text-gray-700 dark:text-slate-300 border-gray-200 dark:border-white/5'}}"
            {{on "click" this.openScorerModal}}>
            Scorer
            {{#if this.acceptedScorerCount}}
              <span class="text-[9px] font-bold w-4 h-4 rounded-full flex items-center justify-center
                {{if this.scorerReady 'bg-emerald-600 text-white' 'bg-gray-800 dark:bg-slate-900 text-white'}}">{{this.acceptedScorerCount}}</span>
            {{/if}}
          </button>

          <button type="button"
            class="flex items-center gap-1.5 px-2.5 py-1.5 text-xs font-medium rounded-lg transition-colors border
              {{if this.streamerReady
                'bg-emerald-100 dark:bg-emerald-700/30 hover:bg-emerald-200 dark:hover:bg-emerald-700/50 text-emerald-700 dark:text-emerald-300 border-emerald-300 dark:border-emerald-600/50'
                'bg-gray-100 dark:bg-slate-700/80 hover:bg-gray-200 dark:hover:bg-slate-600 text-gray-700 dark:text-slate-300 border-gray-200 dark:border-white/5'}}"
            {{on "click" this.openStreamerModal}}>
            Streamer
            {{#if this.acceptedStreamerCount}}
              <span class="text-[9px] font-bold w-4 h-4 rounded-full flex items-center justify-center
                {{if this.streamerReady 'bg-emerald-600 text-white' 'bg-gray-800 dark:bg-slate-900 text-white'}}">{{this.acceptedStreamerCount}}</span>
            {{/if}}
          </button>

        {{/if}}

      </div>
    </div>

    {{! Reset Match Confirmation Modal }}
    {{#if this.showResetConfirm}}
      <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm px-4">
        <div class="bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-700 rounded-2xl shadow-2xl w-full max-w-sm p-6">
          <h3 class="text-base font-semibold text-gray-900 dark:text-white mb-2">Reset Match?</h3>
          <p class="text-sm text-gray-500 dark:text-gray-400 mb-6">This will reset all match data. This action cannot be undone.</p>
          <div class="flex gap-3 justify-end">
            <button
              type="button"
              class="px-4 py-2 text-sm font-semibold rounded-lg bg-gray-100 dark:bg-slate-700 hover:bg-gray-200 dark:hover:bg-slate-600 text-gray-700 dark:text-gray-200 transition-colors"
              {{on "click" this.closeResetConfirm}}
            >
              Cancel
            </button>
            <button
              type="button"
              class="px-4 py-2 text-sm font-semibold rounded-lg bg-red-600 hover:bg-red-500 text-white transition-colors disabled:opacity-50"
              disabled={{this.isResetting}}
              {{on "click" this.resetMatch}}
            >
              {{if this.isResetting "Resetting..." "Reset"}}
            </button>
          </div>
        </div>
      </div>
    {{/if}}

    {{! Abandon Options Modal }}
    {{#if this.showAbandonOptions}}
      <div class="fixed inset-0 z-50 flex items-center justify-center px-4" role="dialog">
        <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" {{on "click" this.closeAbandon}}></div>
        <div class="relative z-10 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-700 rounded-2xl shadow-2xl w-full max-w-sm p-5">
          <div class="flex flex-col gap-3 mb-4">
            <button
              type="button"
              class="w-full py-3 text-sm font-semibold rounded-xl bg-gray-100 dark:bg-slate-700 hover:bg-gray-200 dark:hover:bg-slate-600 text-gray-800 dark:text-white transition-colors"
              {{on "click" this.openReschedule}}
            >
              Re Schedule Match (M)
            </button>
            <button
              type="button"
              class="w-full py-3 text-sm font-semibold rounded-xl bg-gray-100 dark:bg-slate-700 hover:bg-gray-200 dark:hover:bg-slate-600 text-gray-800 dark:text-white transition-colors"
              {{on "click" this.openSimpleAbandon}}
            >
              Simple Abandoned Match
            </button>
          </div>
          <div class="flex justify-end">
            <button
              type="button"
              class="px-4 py-1.5 text-sm font-semibold text-cyan-600 dark:text-cyan-400 hover:underline"
              {{on "click" this.closeAbandon}}
            >
              OK
            </button>
          </div>
        </div>
      </div>
    {{/if}}

    {{! Abandon Confirm Modal }}
    {{#if this.showAbandonConfirm}}
      <div class="fixed inset-0 z-50 flex items-center justify-center px-4" role="dialog">
        <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" {{on "click" this.closeAbandon}}></div>
        <div class="relative z-10 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-2xl shadow-2xl w-full max-w-sm p-6">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-base font-semibold text-gray-900 dark:text-white">
              Abandon '{{@model.gameName}}'?
            </h3>
            <button type="button" class="text-gray-400 hover:text-gray-600 dark:hover:text-gray-200" {{on "click" this.closeAbandon}}>
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
          <textarea
            class="w-full px-3 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-slate-600 bg-gray-50 dark:bg-slate-700 text-gray-800 dark:text-gray-200 placeholder-gray-400 resize-none focus:outline-none focus:ring-2 focus:ring-cyan-500"
            rows="3"
            placeholder="Reason (optional)"
            value={{this.abandonReason}}
            {{on "input" this.updateAbandonReason}}
          ></textarea>
          <div class="flex gap-3 justify-end mt-4">
            <button
              type="button"
              class="px-4 py-2 text-sm font-semibold rounded-lg bg-slate-100 hover:bg-slate-200 dark:bg-slate-700 dark:hover:bg-slate-600 text-gray-700 dark:text-gray-200 transition-colors"
              {{on "click" this.closeAbandon}}
            >
              Cancel
            </button>
            <button
              type="button"
              class="px-4 py-2 text-sm font-semibold rounded-lg bg-red-600 hover:bg-red-500 text-white transition-colors disabled:opacity-50"
              disabled={{this.isAbandoning}}
              {{on "click" this.confirmAbandon}}
            >
              {{if this.isAbandoning "Confirming..." "Confirm"}}
            </button>
          </div>
        </div>
      </div>
    {{/if}}

    <AppDownloadModal
      @isOpen={{this.showAppDownload}}
      @onClose={{this.closeAppDownload}}
      @title={{this.appDownloadItem}}
    />

    <SwitchScorerModal
      @isOpen={{this.showSwitchScorer}}
      @onClose={{this.closeSwitchScorer}}
      @onSend={{this.onScorerSelected}}
      @gameScorer={{@model.gameScorer}}
      @activeScorerId={{@model.activeScorrer}}
    />

    <RescheduleModal
      @isOpen={{this.showReschedule}}
      @onClose={{this.closeReschedule}}
      @model={{@model}}
    />

    <SelectRoleModal
      @isOpen={{this.showGameOfficialModal}}
      @role="cricketumipire"
      @title="Select Umpire"
      @gameId={{@model.id}}
      @onSelect={{this.onGameOfficialSelected}}
      @onClose={{this.closeGameOfficialModal}}
    />

    <SelectRoleModal
      @isOpen={{this.showScorerModal}}
      @role="cricketscorer"
      @title="Select Scorer"
      @gameId={{@model.id}}
      @onSelect={{this.onScorerRoleSelected}}
      @onClose={{this.closeScorerModal}}
    />

    <SelectRoleModal
      @isOpen={{this.showStreamerModal}}
      @role="cricketstreamer"
      @title="Select Streamer"
      @gameId={{@model.id}}
      @onSelect={{this.onStreamerRoleSelected}}
      @onClose={{this.closeStreamerModal}}
    />

    <SelectStartPlayersModal
      @isOpen={{this.showSelectPlayersModal}}
      @model={{@model}}
      @isStartFlow={{this.isStartMatchFlow}}
      @preloadedSelections={{this.playerSelections}}
      @onDone={{this.onPlayersSelected}}
      @onClose={{this.closeSelectPlayersModal}}
    />

    {{! Start Match — role readiness warning }}
    {{#if this.showStartWarning}}
      <div class="fixed inset-0 z-50 flex items-center justify-center px-4" role="dialog">
        <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" {{on "click" this.closeStartWarning}}></div>
        <div class="relative z-10 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-700 rounded-2xl shadow-2xl w-full max-w-sm p-6">

          <div class="flex items-start gap-3 mb-4">
            <div class="w-9 h-9 rounded-full bg-yellow-50 dark:bg-yellow-500/15 flex items-center justify-center flex-shrink-0 mt-0.5">
              <svg class="w-5 h-5 text-yellow-500 dark:text-yellow-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z" />
              </svg>
            </div>
            <div>
              <h3 class="text-gray-900 dark:text-white font-semibold text-base mb-1">Not ready to start</h3>
              <p class="text-gray-500 dark:text-gray-400 text-sm">The following roles need at least 2 accepted members:</p>
            </div>
          </div>

          <ul class="mb-5 space-y-2">
            {{#each this.startWarningErrors as |err|}}
              <li class="flex items-center gap-2 text-sm">
                <span class="w-1.5 h-1.5 rounded-full bg-yellow-400 flex-shrink-0"></span>
                {{#if (eq err "umpire")}}
                  <span class="text-gray-700 dark:text-gray-200">At least 2 <span class="text-yellow-600 dark:text-yellow-400 font-medium">Umpires</span> must be accepted before starting</span>
                {{else if (eq err "scorer")}}
                  <span class="text-gray-700 dark:text-gray-200">At least 2 <span class="text-yellow-600 dark:text-yellow-400 font-medium">Scorers</span> must be accepted before starting</span>
                {{else}}
                  <span class="text-gray-700 dark:text-gray-200 capitalize">{{err}} — not enough members accepted</span>
                {{/if}}
              </li>
            {{/each}}
          </ul>

          <div class="flex justify-end">
            <button
              type="button"
              class="px-4 py-2 text-sm font-semibold rounded-lg transition-colors flex items-center gap-1.5
                {{if this.hasFixableWarning
                  'bg-yellow-500 hover:bg-yellow-400 text-white'
                  'bg-gray-100 dark:bg-slate-700 hover:bg-gray-200 dark:hover:bg-slate-600 text-gray-700 dark:text-gray-200'}}"
              {{on "click" this.closeStartWarning}}
            >
              {{if this.hasFixableWarning "Fix Now" "OK"}}
              {{#if this.hasFixableWarning}}
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M9 5l7 7-7 7" />
                </svg>
              {{/if}}
            </button>
          </div>

        </div>
      </div>
    {{/if}}
  </template>
}

export default MatchHeaderComponent;
