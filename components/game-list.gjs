import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { service } from '@ember/service';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { debounce } from '@ember/runloop';
import { eq, or } from 'ember-truth-helpers';
import { modifier } from 'ember-modifier';

const infiniteScroll = modifier((element, [onIntersect]) => {
  const observer = new IntersectionObserver(
    (entries) => { if (entries[0]?.isIntersecting) onIntersect(); },
    { rootMargin: '200px' }
  );
  observer.observe(element);
  return () => observer.disconnect();
});
import config from 'spordium/config/environment';
import ShareButton from './share-button';
import WatchLaterButton from './watch-later-button';

const LIMIT = 10;

function formatOvers(overs) {
  if (overs == null || isNaN(overs)) return null;
  const full = Math.floor(overs);
  const balls = Math.round((overs - full) * 10);
  return balls > 0 ? `${full}.${balls}` : `${full}`;
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

export default class GameListComponent extends Component {
  @service router;
  @service session;
  @service store;
  @service toast;
  @service authModal;
  @service websocket;

  _wsSubscribedIds = new Set();
  _wsListener = null;

  @tracked games = [];
  @tracked isLoading = true;
  @tracked isLoadingMore = false;
  @tracked hasMore = true;
  @tracked lastGameId = null;
  @tracked error = null;
  @tracked searchQuery = '';
  @tracked activeTab = 'all';
  @tracked selectedSport = 'all';

  _syncUrlToState() {
    const sport = this.args.sport ?? 'all';
    const tab   = this.args.tab   ?? 'all';
    const tabIsValid = tab === 'my' || tab === 'all';
    this.activeTab    = tabIsValid ? tab : 'all';
    this.selectedSport = sport;
  }

  sportTabs = [
    { key: 'all',        label: 'All',        icon: '🎮' },
    { key: 'Cricket',    label: 'Cricket',    icon: '🏏' },
    // { key: 'Football',   label: 'Football',   icon: '⚽' },
    // { key: 'Basketball', label: 'Basketball', icon: '🏀' },
  ];

  @tracked myGames = [];
  @tracked isLoadingMyGames = false;
  @tracked myGamesError = null;

  @tracked searchResults = null;
  @tracked isSearching = false;
  @tracked showSportPicker = false;

  sportTypes = ['Cricket']; // 'Football', 'Basketball'
  @tracked selectedDates = [];
  @tracked dateFrom = '';
  @tracked dateTo = '';
  @tracked showDatePicker = false;

  get dateLabel() {
    if (!this.dateFrom) return null;
    if (this.dateTo && this.dateTo !== this.dateFrom) {
      return `${this.selectedDates.length} dates`;
    }
    return this.dateFrom;
  }

  constructor() {
    super(...arguments);
    this._syncUrlToState();
    this.loadGames();
  }

  get s3BucketUrl() {
    return config.APP.S3_BUCKET_URL || 'https://spordium.s3.ap-southeast-1.amazonaws.com';
  }

  getImageUrl(path) {
    if (!path) return '/images/default-team.png';
    if (path.startsWith('http')) return path;
    const cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return `${this.s3BucketUrl}/${cleanPath}`;
  }

  @action
  async loadGames() {
    this.isLoading = true;
    this.error = null;
    this.lastGameId = null;
    this.hasMore = true;

    try {
      const body = { limit: LIMIT, countrycode: 'BD' };
      if (this.selectedSport !== 'all') body.sportstype = this.selectedSport.toLowerCase();

      const response = await fetch(`${config.APP.API_HOST}/game/game_list/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify(body),
      });

      if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);

      const data = await response.json();
      const results = this.transformGames(data.data || []);
      this.games = results;
      this.lastGameId = results.at(-1)?.id ?? null;
      this.hasMore = results.length === LIMIT;
      this._syncWsSubscriptions();
    } catch (err) {
      console.error('Error loading games:', err);
      this.error = err.message;
    } finally {
      this.isLoading = false;
    }
  }

  @action
  async loadMore() {
    if (this.isLoadingMore || !this.hasMore || this.searchResults) return;
    this.isLoadingMore = true;

    try {
      const body = { limit: LIMIT, countrycode: 'BD' };
      if (this.selectedSport !== 'all') body.sportstype = this.selectedSport.toLowerCase();
      if (this.lastGameId) body.last_game_id = this.lastGameId;

      const response = await fetch(`${config.APP.API_HOST}/game/game_list/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify(body),
      });

      if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);

      const data = await response.json();
      const newResults = this.transformGames(data.data || []);
      this.games = [...this.games, ...newResults];
      this.lastGameId = newResults.at(-1)?.id ?? this.lastGameId;
      this.hasMore = newResults.length === LIMIT;
      this._syncWsSubscriptions();
    } catch (err) {
      console.error('Load more error:', err);
    } finally {
      this.isLoadingMore = false;
    }
  }

  transformGames(results) {
    return results.map((game) => {
      const gameDate = new Date(game.game_datetime);

      const isFinished = game.is_finished ?? (!game.is_started && game.game_result != null);

      let status = 'Upcoming';
      let statusClass = 'bg-blue-500';
      if (isFinished) {
        status = 'Finished';
        statusClass = 'bg-slate-500';
      } else if (game.is_started) {
        status = 'LIVE';
        statusClass = 'bg-red-500';
      }

      return {
        id: game.game_id,
        name: game.game_name,
        datetime: game.game_datetime,
        formattedDate: gameDate.toLocaleDateString('en-US', {
          day: 'numeric',
          month: 'short',
          year: 'numeric',
        }),
        formattedTime: gameDate.toLocaleTimeString('en-US', {
          hour: '2-digit',
          minute: '2-digit',
          hour12: true,
        }),
        get formattedDateTime() { return `${this.formattedDate} · ${this.formattedTime}`; },
        isStarted: game.is_started,
        isFinished,
        status,
        statusClass,
        overs: game.game_configuration?.over || 0,
        playersPerSide: game.game_configuration?.number_of_player_in_one_side || 11,
        matchPrize: (() => { const p = game.game_result?.match_prize ?? game.game_configuration?.match_prize; return Number(p) > 0 ? p : null; })(),
        team1: {
          id: game.team1_id,
          name: game.team1_name || game.game_result?.batting?.team_name || 'Team 1',
          logo: this.getImageUrl(game.team1_logo || game.game_result?.batting?.team_logo),
        },
        team2: {
          id: game.team2_id,
          name: game.team2_name || game.game_result?.fielding?.team_name || 'Team 2',
          logo: this.getImageUrl(game.team2_logo || game.game_result?.fielding?.team_logo),
        },
        sportType: game.sportstype || game.sport_type || null,
        isWatchLater: false,
        watchLaterLoading: false,
        liveScore: (() => {
          const batting = game.game_result?.batting ?? null;
          if (!batting || !game.is_started) return null;
          const runs    = batting.livescore ?? null;
          const wickets = batting.wicketstaken ?? null;
          const balls   = batting.balls;
          const scoreStr = runs != null
            ? `${runs}${wickets != null ? '/' + wickets : ''}`
            : null;
          const battingTeamName = batting.team_name || null;
          const crr = (batting.CR != null && batting.CR > 0)
            ? Number(batting.CR).toFixed(2)
            : calcCRR(runs, balls);
          const isSecondInnings = game.game_result?.innings === 2;
          const rr = (isSecondInnings && batting.RR != null && batting.RR > 0)
            ? Number(batting.RR).toFixed(2)
            : null;
          return { scoreStr, overs: balls != null ? formatOvers(balls) : null, battingTeamName, crr, rr };
        })(),
        disposition: isFinished ? (game.game_finish_disposition?.disposition ?? null) : null,
      };
    });
  }

  _updateGame(id, updates) {
    const patch = (list) => list.map((g) => (g.id === id ? { ...g, ...updates } : g));
    this.games = patch(this.games);
    this.myGames = patch(this.myGames);
    if (this.searchResults) this.searchResults = patch(this.searchResults);
  }

  _isEligibleForWs(game, today) {
    if (game.isFinished) return false;
    if (game.isStarted) return true;
    return new Date(game.datetime).toISOString().slice(0, 10) === today;
  }

  _syncWsSubscriptions() {
    const today = new Date().toISOString().slice(0, 10);
    const allGames = [...this.games, ...this.myGames];
    const wantedIds = new Set(
      allGames.filter((g) => this._isEligibleForWs(g, today)).map((g) => String(g.id))
    );

    if (!this._wsListener && wantedIds.size > 0) {
      this._wsListener = this.websocket.on('*', (data) => this._handleWsMessage(data));
    }

    this.websocket.syncMatchScoreIds([...wantedIds]);
    this._wsSubscribedIds = wantedIds;
  }

  _handleWsMessage(data) {
    if (data?.status !== 'success' || !data?.payload) return;

    // receiver format: "match:score:{game_id}" or "match:details:{game_id}"
    const gameId = String(data.receiver?.split(':').pop() ?? '');
    if (!gameId || !this._wsSubscribedIds.has(gameId)) return;

    const payload = data.payload;
    const type = payload.type;

    // Viewer count update
    if (type === 'viewer_count') {
      this._updateGame(gameId, { viewerCount: { live: payload.live ?? 0, total: payload.total ?? 0 } });
      return;
    }

    // Score update events: extract runs/wickets/overs and patch liveScore
    if (type === 'match_score' || type === 'stricker_bowler_stats' || payload.isScoreboardData) {
      let runs, wickets, overs;
      let rawOvers;
      if (payload.isScoreboardData) {
        // Shape A — stricker_bowler_stats
        runs     = payload.bowling?.runsgiven    ?? null;
        wickets  = payload.bowling?.wicketstaken ?? null;
        rawOvers = payload.bowling?.oversbowled;
        overs    = formatOvers(rawOvers);
      } else {
        // Shape B — match_score (ball-by-ball)
        runs     = payload.run    != null ? parseInt(payload.run,    10) : null;
        wickets  = payload.wicket != null ? parseInt(payload.wicket, 10) : null;
        rawOvers = payload.over   != null ? parseFloat(payload.over)     : null;
        overs    = rawOvers != null ? formatOvers(rawOvers) : null;
      }
      const scoreStr = runs != null
        ? `${runs}${wickets != null ? '/' + wickets : ''}`
        : null;

      const battingTeamId = payload.battingteamid
        ? String(payload.battingteamid)
        : payload.team_id ? String(payload.team_id) : null;
      const game =
        this.games.find((g) => String(g.id) === gameId) ||
        this.myGames.find((g) => String(g.id) === gameId);
      let battingTeamName = null;
      if (game && battingTeamId) {
        if (String(game.team1.id) === battingTeamId) battingTeamName = game.team1.name;
        else if (String(game.team2.id) === battingTeamId) battingTeamName = game.team2.name;
      }

      if (battingTeamId && !game?.isFinished) {
        const liveScore = (scoreStr != null || overs != null)
          ? { scoreStr, overs, battingTeamName, crr: calcCRR(runs, rawOvers), rr: null }
          : (game?.liveScore ?? null);
        this._updateGame(gameId, {
          isStarted: true,
          isFinished: false,
          status: 'LIVE',
          statusClass: 'bg-red-500',
          liveScore,
        });
      } else if (scoreStr != null || overs != null) {
        const scoreUpdate = { liveScore: { scoreStr, overs, battingTeamName, crr: calcCRR(runs, rawOvers), rr: null } };
        if (!game?.isFinished) {
          scoreUpdate.isStarted = true;
          scoreUpdate.isFinished = false;
          scoreUpdate.status = 'LIVE';
          scoreUpdate.statusClass = 'bg-red-500';
        }
        this._updateGame(gameId, scoreUpdate);
      }
      return;
    }

    const updates = {};
    if (payload.is_started !== undefined) updates.isStarted = payload.is_started;
    if (payload.is_finished !== undefined) updates.isFinished = payload.is_finished;

    if (payload.is_finished) {
      updates.status = 'Finished';
      updates.statusClass = 'bg-slate-500';
    } else if (payload.is_started) {
      updates.status = 'LIVE';
      updates.statusClass = 'bg-red-500';
    }

    if (Object.keys(updates).length > 0) {
      this._updateGame(gameId, updates);
    }
  }

  willDestroy() {
    super.willDestroy();
    if (this._wsListener) {
      this._wsListener();
      this._wsListener = null;
    }
    if (this._wsSubscribedIds.size > 0) {
      this.websocket.unsubscribe({ matchScoreIds: [...this._wsSubscribedIds] });
      this._wsSubscribedIds.clear();
    }
  }

  @action
  goToGameDetails(gameId) {
    //this.router.transitionTo('match.match-details', { queryParams: { gameid: gameId } });
    const url = this.router.urlFor('match.match-details', { queryParams: { gameid: gameId } });
    window.open(url, '_self');
  }

  @action
  retry() {
    this.games = [];
    this.lastGameId = null;
    this.hasMore = true;
    this.loadGames();
  }

  get skeletonArray() {
    return [1, 2, 3, 4, 5, 6];
  }

  get displayGames() {
    if (this.activeTab === 'my') {
      if (this.selectedSport === 'all') return this.myGames;
      return this.myGames.filter((g) => g.sportType?.toLowerCase() === this.selectedSport.toLowerCase());
    }
    return this.searchResults ?? this.games;
  }

  @action
  onSearchInput(event) {
    this.searchQuery = event.target.value;

    if (this.activeTab === 'my') return;

    if (!this.searchQuery.trim() && !this.selectedDates.length) {
      this.searchResults = null;
      this.isSearching = false;
      return;
    }

    debounce(this, this.performSearch, 400);
  }

  async performSearch() {
    const queryAtStart = this.searchQuery;
    const datesAtStart = [...this.selectedDates];
    this.isSearching = true;
    try {
      const body = { limit: LIMIT, countrycode: 'BD' };
      if (this.selectedSport !== 'all') body.sportstype = this.selectedSport.toLowerCase();
      if (queryAtStart.trim()) body.search_data = queryAtStart;
      if (datesAtStart.length) body.dates = datesAtStart;

      const response = await fetch(`${config.APP.API_HOST}/game/game_list/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify(body),
      });
      if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
      const data = await response.json();
      if (this.searchQuery === queryAtStart) {
        this.searchResults = this.transformGames(data.data || []);
      }
    } catch (err) {
      console.error('Search error:', err);
      if (this.searchQuery === queryAtStart) {
        this.searchResults = [];
      }
    } finally {
      this.isSearching = false;
    }
  }

  @action
  toggleDatePicker() {
    this.showDatePicker = !this.showDatePicker;
  }

  @action
  closeDatePicker() {
    this.showDatePicker = false;
  }

  @action
  onFromChange(event) {
    this.dateFrom = event.target.value;
    if (this.dateTo && this.dateTo < this.dateFrom) {
      this.dateTo = '';
    }
    this._expandRange();
    this._triggerSearch();
  }

  @action
  onToChange(event) {
    this.dateTo = event.target.value;
    this._expandRange();
    this._triggerSearch();
  }

  @action
  clearDates() {
    this.dateFrom = '';
    this.dateTo = '';
    this.selectedDates = [];
    this.showDatePicker = false;
    this._triggerSearch();
  }

  _expandRange() {
    if (!this.dateFrom) {
      this.selectedDates = [];
      return;
    }
    const from = new Date(this.dateFrom);
    const to = this.dateTo ? new Date(this.dateTo) : from;
    const dates = [];
    const cur = new Date(from);
    while (cur <= to) {
      dates.push(cur.toISOString().slice(0, 10));
      cur.setDate(cur.getDate() + 1);
    }
    this.selectedDates = dates;
  }

  _triggerSearch() {
    if (!this.searchQuery.trim() && !this.selectedDates.length) {
      this.searchResults = null;
      return;
    }
    debounce(this, this.performSearch, 300);
  }

  async fetchMyGames() {
    this.isLoadingMyGames = true;
    this.myGamesError = null;
    try {
      const url = `${config.APP.API_HOST}/game/owner-game-list/`;
      const response = await fetch(url, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
          Authorization: `Bearer ${this.session.token}`,
        },
      });
      if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
      const data = await response.json();
      this.myGames = this.transformGames(data.data || []);
      this._syncWsSubscriptions();
    } catch (err) {
      console.error('Error loading my games:', err);
      this.myGamesError = err.message;
    } finally {
      this.isLoadingMyGames = false;
    }
  }

  @action
  async toggleMyGames() {
    if (this.activeTab === 'my') {
      this.activeTab = 'all';
      this.router.replaceWith('match', { queryParams: { sport: this.selectedSport, tab: 'all' } });
      return;
    }
    this.activeTab = 'my';
    this.router.replaceWith('match', { queryParams: { sport: this.selectedSport, tab: 'my' } });
    if (this.myGames.length) return;
    await this.fetchMyGames();
  }

  @action
  async retryMyGames() {
    this.myGames = [];
    await this.fetchMyGames();
  }

  @action
  setSport(sport) {
    if (this.selectedSport === sport) return;
    this.selectedSport = sport;
    this.router.replaceWith('match', { queryParams: { sport, tab: this.activeTab } });
    if (this.activeTab === 'my') return;
    this.games = [];
    this.lastGameId = null;
    this.hasMore = true;
    this.searchResults = null;
    this.loadGames();
  }

  @action
  onCreateGameClick() {
    if (!this.session.isAuthenticated) {
      this.authModal.open('login');
    } else {
      this.showSportPicker = true;
    }
  }

  @action
  closeSportPicker() {
    this.showSportPicker = false;
  }

  @action
  selectSport(sport) {
    this.showSportPicker = false;
    this.router.transitionTo('match.create', { queryParams: { sport } });
  }

  <template>
    <div class="w-full py-8">

        {{! Top bar: tabs + search + create }}
        <div class="relative mb-8">
          <div class="absolute bottom-0 left-0 right-0 h-px bg-gray-200 dark:bg-gray-700"></div>
          <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-y-3 sm:gap-4">

            {{! Left: tab bar }}
            <div class="flex items-center overflow-x-auto scrollbar-hide" role="tablist">
              {{#if this.session.isAuthenticated}}
                <button
                  type="button"
                  class="relative flex shrink-0 items-center gap-1.5 px-4 py-2.5 text-sm font-semibold transition-colors duration-200 focus:outline-none
                    {{if (eq this.activeTab 'my') 'text-cyan-600 dark:text-cyan-400' 'text-gray-500 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200'}}"
                  {{on "click" this.toggleMyGames}}
                >
                  <span>👤</span>
                  <span>My Games</span>
                  {{#if (eq this.activeTab 'my')}}<span class="absolute bottom-0 left-0 right-0 h-0.5 rounded-full bg-cyan-600 dark:bg-cyan-400"></span>{{/if}}
                </button>
              {{/if}}
              {{#each this.sportTabs as |tab|}}
                <button
                  type="button"
                  class="relative flex shrink-0 items-center gap-1.5 px-4 py-2.5 text-sm font-semibold transition-colors duration-200 focus:outline-none
                    {{if (eq this.selectedSport tab.key) 'text-cyan-600 dark:text-cyan-400' 'text-gray-500 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200'}}"
                  {{on "click" (fn this.setSport tab.key)}}
                >
                  <span>{{tab.icon}}</span>
                  <span>{{tab.label}}</span>
                  {{#if (eq this.selectedSport tab.key)}}<span class="absolute bottom-0 left-0 right-0 h-0.5 rounded-full bg-cyan-600 dark:bg-cyan-400"></span>{{/if}}
                </button>
              {{/each}}
            </div>

            {{! Right: Create Game + search + date range }}
            <div class="flex items-center gap-2 pb-2 sm:pb-1 w-full sm:w-auto sm:shrink-0">
            {{#if this.session.isAuthenticated}}
              <button
                type="button"
                class="inline-flex items-center gap-1.5 px-4 py-2.5 rounded-xl text-sm font-semibold bg-cyan-600 hover:bg-cyan-500 text-white shadow-sm shadow-cyan-600/20 transition-all flex-shrink-0"
                {{on "click" this.onCreateGameClick}}
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                </svg>
                Create Match
              </button>
            {{/if}}

            {{! Combined pill bar }}
            <div class="flex items-center bg-white dark:bg-slate-800 border rounded-xl overflow-visible transition-all flex-1 sm:w-96
              {{if this.selectedDates.length 'border-cyan-500/40' 'border-gray-200 dark:border-slate-700/60'}}">

              {{! Search input }}
              <div class="relative flex-1 min-w-0">
                <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500 pointer-events-none" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
                <input
                  type="text"
                  placeholder="Search games..."
                  class="w-full bg-transparent pl-9 pr-3 py-2.5 text-sm text-gray-900 dark:text-white placeholder-gray-400 dark:placeholder-gray-500 focus:outline-none"
                  value={{this.searchQuery}}
                  {{on "input" this.onSearchInput}}
                />
              </div>

              {{! Divider }}
              <div class="w-px h-5 bg-gray-200 dark:bg-slate-700/60 flex-shrink-0"></div>

              {{! Date range trigger button }}
              <div class="relative flex-shrink-0">
                <button
                  type="button"
                  class="flex items-center gap-1.5 px-3 py-2.5 text-sm font-medium transition-colors
                    {{if this.selectedDates.length 'text-cyan-400' 'text-gray-500 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white'}}"
                  {{on "click" this.toggleDatePicker}}
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                  </svg>
                  {{#if this.dateLabel}}
                    {{this.dateLabel}}
                  {{else}}
                    Dates
                  {{/if}}
                </button>

                {{! Date dropdown }}
                {{#if this.showDatePicker}}
                  <div class="fixed inset-0 z-10" role="presentation" {{on "click" this.closeDatePicker}}></div>

                  <div class="absolute right-0 top-full mt-2 z-20 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-700/50 rounded-2xl shadow-2xl p-4 w-72">

                    {{! Step indicators }}
                    <div class="flex items-center gap-2 mb-4">
                      {{! Step 1 }}
                      <div class="flex items-center gap-1.5 flex-1">
                        <div class="w-5 h-5 rounded-full flex items-center justify-center text-[10px] font-bold flex-shrink-0
                          {{if this.dateFrom 'bg-cyan-500 text-white' 'bg-gray-100 dark:bg-slate-700 text-gray-400 dark:text-gray-500'}}">1</div>
                        <div class="flex-1">
                          <p class="text-[10px] text-gray-500 leading-none mb-0.5">Start</p>
                          <p class="text-xs font-semibold {{if this.dateFrom 'text-gray-900 dark:text-white' 'text-gray-400 dark:text-gray-600'}}">
                            {{if this.dateFrom this.dateFrom '—'}}
                          </p>
                        </div>
                      </div>

                      {{! Arrow }}
                      <svg class="w-3.5 h-3.5 {{if this.dateFrom 'text-cyan-500' 'text-gray-300 dark:text-slate-700'}} flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M9 5l7 7-7 7" />
                      </svg>

                      {{! Step 2 }}
                      <div class="flex items-center gap-1.5 flex-1">
                        <div class="w-5 h-5 rounded-full flex items-center justify-center text-[10px] font-bold flex-shrink-0
                          {{if this.dateTo 'bg-cyan-500 text-white' 'bg-gray-100 dark:bg-slate-700 text-gray-400 dark:text-gray-500'}}">2</div>
                        <div class="flex-1">
                          <p class="text-[10px] text-gray-500 leading-none mb-0.5">End</p>
                          <p class="text-xs font-semibold {{if this.dateTo 'text-gray-900 dark:text-white' 'text-gray-400 dark:text-gray-600'}}">
                            {{if this.dateTo this.dateTo '—'}}
                          </p>
                        </div>
                      </div>
                    </div>

                    {{! From input }}
                    <div class="mb-2">
                      <label class="text-gray-500 text-[11px] mb-1 block">Start date</label>
                      <input
                        type="date"
                        style="color-scheme: dark;"
                        class="w-full bg-gray-50 dark:bg-slate-700/50 border border-gray-200 dark:border-slate-600/50 rounded-xl px-3 py-2 text-sm text-gray-900 dark:text-white focus:outline-none focus:border-cyan-500/60 cursor-pointer transition-colors"
                        value={{this.dateFrom}}
                        {{on "change" this.onFromChange}}
                      />
                    </div>

                    {{! To input }}
                    <div>
                      <label class="text-gray-500 text-[11px] mb-1 block">End date <span class="text-gray-600">(optional)</span></label>
                      <input
                        type="date"
                        style="color-scheme: dark;"
                        class="w-full bg-gray-50 dark:bg-slate-700/50 border border-gray-200 dark:border-slate-600/50 rounded-xl px-3 py-2 text-sm text-gray-900 dark:text-white focus:outline-none focus:border-cyan-500/60 cursor-pointer transition-colors
                          {{unless this.dateFrom 'opacity-40 pointer-events-none'}}"
                        value={{this.dateTo}}
                        {{on "change" this.onToChange}}
                      />
                    </div>

                    {{#if this.selectedDates.length}}
                      <p class="text-cyan-400 text-[11px] mt-2.5 text-center">
                        {{this.selectedDates.length}} date{{if (eq this.selectedDates.length 1) '' 's'}} selected
                      </p>
                    {{/if}}

                    {{#if this.selectedDates.length}}
                      <button
                        type="button"
                        class="mt-3 w-full py-1.5 text-xs text-gray-400 dark:text-gray-500 hover:text-red-400 border border-gray-200 dark:border-slate-700/50 hover:border-red-500/30 rounded-lg transition-colors"
                        {{on "click" this.clearDates}}
                      >
                        Clear dates
                      </button>
                    {{/if}}
                  </div>
                {{/if}}
              </div>

              {{! Clear dates X }}
              {{#if this.selectedDates.length}}
                <button
                  type="button"
                  class="px-2 text-gray-400 dark:text-gray-600 hover:text-gray-900 dark:hover:text-white transition-colors flex-shrink-0"
                  {{on "click" this.clearDates}}
                >
                  <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              {{/if}}

            </div>

          </div>
        </div>
        </div>

        {{#if (eq this.activeTab 'my')}}
          {{! ── My Games tab ── }}
          {{#if this.isLoadingMyGames}}
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
              {{#each this.skeletonArray}}
                <div class="bg-white dark:bg-slate-800 rounded-2xl p-5 animate-pulse border border-gray-200 dark:border-slate-700/50">
                  <div class="flex justify-between items-start mb-4">
                    <div class="h-5 bg-gray-200 dark:bg-slate-700 rounded w-24"></div>
                    <div class="h-6 bg-gray-200 dark:bg-slate-700 rounded w-16"></div>
                  </div>
                  <div class="flex items-center justify-between mb-4">
                    <div class="flex items-center gap-3">
                      <div class="w-12 h-12 bg-gray-200 dark:bg-slate-700 rounded-xl"></div>
                      <div class="h-4 bg-gray-200 dark:bg-slate-700 rounded w-20"></div>
                    </div>
                    <div class="text-gray-300 dark:text-slate-600 text-lg font-bold">VS</div>
                    <div class="flex items-center gap-3">
                      <div class="h-4 bg-gray-200 dark:bg-slate-700 rounded w-20"></div>
                      <div class="w-12 h-12 bg-gray-200 dark:bg-slate-700 rounded-xl"></div>
                    </div>
                  </div>
                  <div class="h-4 bg-gray-200 dark:bg-slate-700 rounded w-32 mx-auto"></div>
                </div>
              {{/each}}
            </div>
          {{else if this.myGamesError}}
            <div class="bg-white dark:bg-slate-800 rounded-2xl p-8 text-center border border-gray-200 dark:border-slate-700/50">
              <div class="w-16 h-16 mx-auto mb-4 bg-red-500/10 rounded-full flex items-center justify-center">
                <svg class="w-8 h-8 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"></path>
                </svg>
              </div>
              <h3 class="text-gray-900 dark:text-white text-lg font-bold mb-2">Failed to Load My Games</h3>
              <p class="text-gray-600 dark:text-gray-400 text-sm mb-4">{{this.myGamesError}}</p>
              <button type="button" class="px-5 py-2.5 bg-cyan-600 hover:bg-cyan-700 text-white text-sm font-medium rounded-lg transition-colors" {{on "click" this.retryMyGames}}>
                Try Again
              </button>
            </div>
          {{else if this.displayGames.length}}
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
              {{#each this.displayGames as |game|}}
                <div
                  role="button"
                  tabindex="0"
                  class="group relative bg-white dark:bg-slate-800 rounded-2xl border border-gray-200 dark:border-slate-700/50 hover:border-cyan-500/40 hover:shadow-xl hover:shadow-cyan-500/10 transition-all duration-200 cursor-pointer {{if (eq this.activeShareMenuId game.id) 'z-50' 'z-0'}}"
                  {{on "click" (fn this.goToGameDetails game.id)}}
                >
                  {{! Header: game name + status badge }}
                  <div class="flex items-start justify-between px-4 pt-4 pb-2 gap-2">
                    <div class="min-w-0 flex-1">
                      <p class="text-gray-900 dark:text-white text-sm font-bold truncate group-hover:text-cyan-500 transition-colors">{{game.name}}</p>
                      <p class="text-[11px] text-gray-400 dark:text-gray-500 mt-0.5">{{game.formattedDate}} · {{game.formattedTime}}</p>
                    </div>
                    {{#if game.isFinished}}
                      <span class="px-2.5 py-1 bg-slate-100 dark:bg-slate-700/80 text-slate-500 dark:text-slate-400 text-xs font-semibold rounded-full flex-shrink-0">Finished</span>
                    {{else if game.isStarted}}
                      <div class="flex items-center gap-1.5 flex-shrink-0">
                        <span class="flex items-center gap-1.5 px-2.5 py-1 bg-red-500/10 text-red-500 text-xs font-bold rounded-full ring-1 ring-red-500/20">
                          <span class="w-1.5 h-1.5 rounded-full bg-red-500 animate-pulse"></span>
                          LIVE
                        </span>
                        {{#if game.viewerCount}}
                          <span class="flex items-center gap-1.5 px-2 py-1 bg-black/5 dark:bg-white/5 text-gray-500 dark:text-gray-400 text-[10px] font-medium rounded-full">
                            <svg class="w-3 h-3 text-red-500" fill="currentColor" viewBox="0 0 24 24">
                              <path d="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5zM12 17c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3z"/>
                            </svg>
                            <span class="text-red-500">{{game.viewerCount.live}}</span>
                            <span class="text-gray-300 dark:text-slate-600">·</span>
                            {{game.viewerCount.total}}
                          </span>
                        {{/if}}
                      </div>
                    {{else}}
                      <span class="px-2.5 py-1 bg-blue-500/10 text-blue-500 dark:text-blue-400 text-xs font-semibold rounded-full flex-shrink-0">Upcoming</span>
                    {{/if}}
                  </div>

                  <div class="mx-4 h-px bg-gray-100 dark:bg-slate-700/50"></div>

                  {{! Teams }}
                  <div class="flex items-center gap-3 px-4 py-4">
                    <div class="flex-1 flex flex-col items-center gap-2 min-w-0">
                      <div class="w-14 h-14 rounded-2xl overflow-hidden bg-gray-50 dark:bg-slate-700/60 p-1.5 ring-1 ring-gray-100 dark:ring-slate-600/40">
                        <img src={{game.team1.logo}} alt={{game.team1.name}} class="w-full h-full object-contain" />
                      </div>
                      <p class="text-gray-900 dark:text-white text-xs font-semibold text-center truncate w-full px-1">{{game.team1.name}}</p>
                    </div>
                    <div class="flex-shrink-0">
                      <span class="text-[11px] font-bold tracking-widest text-gray-300 dark:text-slate-600">VS</span>
                    </div>
                    <div class="flex-1 flex flex-col items-center gap-2 min-w-0">
                      <div class="w-14 h-14 rounded-2xl overflow-hidden bg-gray-50 dark:bg-slate-700/60 p-1.5 ring-1 ring-gray-100 dark:ring-slate-600/40">
                        <img src={{game.team2.logo}} alt={{game.team2.name}} class="w-full h-full object-contain" />
                      </div>
                      <p class="text-gray-900 dark:text-white text-xs font-semibold text-center truncate w-full px-1">{{game.team2.name}}</p>
                    </div>
                  </div>

                  {{#if game.isStarted}}
                    {{#if game.liveScore.scoreStr}}
                      <div class="flex items-center justify-center gap-2 py-2 px-4 flex-wrap">
                        {{#if game.liveScore.battingTeamName}}
                          <span class="text-[11px] text-gray-500 dark:text-gray-400 font-medium truncate max-w-[80px]">{{game.liveScore.battingTeamName}}</span>
                          <span class="text-gray-200 dark:text-slate-600">·</span>
                        {{/if}}
                        <span class="text-sm font-bold text-red-500">{{game.liveScore.scoreStr}}</span>
                        {{#if game.liveScore.overs}}
                          <span class="text-[11px] text-gray-400 dark:text-gray-500">({{game.liveScore.overs}} ov)</span>
                        {{/if}}
                        {{#if game.liveScore.crr}}
                          <span class="text-gray-200 dark:text-slate-600">·</span>
                          <span class="text-[11px] text-emerald-500 dark:text-emerald-400 font-medium">CRR {{game.liveScore.crr}}</span>
                        {{/if}}
                        {{#if game.liveScore.rr}}
                          <span class="text-gray-200 dark:text-slate-600">·</span>
                          <span class="text-[11px] text-orange-500 dark:text-orange-400 font-medium">RRR {{game.liveScore.rr}}</span>
                        {{/if}}
                      </div>
                    {{/if}}
                  {{else if game.isFinished}}
                    {{#if game.disposition}}
                      <div class="py-2 px-4 text-center">
                        <span class="text-[11px] text-gray-500 dark:text-gray-400 font-medium">{{game.disposition}}</span>
                      </div>
                    {{/if}}
                  {{/if}}

                  <div class="mx-4 h-px bg-gray-100 dark:bg-slate-700/50"></div>

                  {{! Footer: stats + actions }}
                  <div class="px-4 py-3 flex items-center justify-between gap-2">
                    <div class="flex items-center gap-1.5 text-[11px] text-gray-500 dark:text-gray-400 min-w-0">
                      {{#if game.overs}}
                        <span><span class="text-cyan-500 font-semibold">{{game.overs}}</span> Ovr</span>
                      {{/if}}
                      {{#if game.matchPrize}}
                        <span class="text-gray-200 dark:text-slate-700">•</span>
                        <span class="text-amber-400 font-medium truncate max-w-[60px]">🏆 {{game.matchPrize}}</span>
                      {{/if}}
                    </div>
                    <div class="flex items-center gap-1 flex-shrink-0">
                      <ShareButton @matchId={{game.id}} @matchName={{game.name}} @matchDate={{game.formattedDateTime}} @isLive={{game.isStarted}} @sportType={{game.sportType}} @dropUp={{true}} />
                      {{#unless (or game.isFinished game.isStarted)}}
                        <WatchLaterButton @matchId={{game.id}} @matchType={{game.sportType}} />
                      {{/unless}}
                    </div>
                  </div>

                </div>
              {{/each}}
            </div>
          {{else}}
            <div class="bg-white dark:bg-slate-800 rounded-2xl p-8 text-center border border-gray-200 dark:border-slate-700/50">
              <div class="w-16 h-16 mx-auto mb-4 bg-gray-100 dark:bg-slate-700/50 rounded-full flex items-center justify-center">
                <svg class="w-8 h-8 text-gray-400 dark:text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"></path>
                </svg>
              </div>
              <h3 class="text-gray-900 dark:text-white text-lg font-bold mb-2">No Games Found</h3>
              <p class="text-gray-600 dark:text-gray-400 text-sm">
                {{#if this.searchQuery}}No games matched "{{this.searchQuery}}".{{else}}You haven't created any games yet.{{/if}}
              </p>
            </div>
          {{/if}}

        {{else}}
          {{! ── All Games tab ── }}
          {{#if this.isSearching}}
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
              {{#each this.skeletonArray}}
                <div class="bg-white dark:bg-slate-800 rounded-2xl p-5 animate-pulse border border-gray-200 dark:border-slate-700/50">
                  <div class="flex justify-between items-start mb-4">
                    <div class="h-5 bg-gray-200 dark:bg-slate-700 rounded w-24"></div>
                    <div class="h-6 bg-gray-200 dark:bg-slate-700 rounded w-16"></div>
                  </div>
                  <div class="flex items-center justify-between mb-4">
                    <div class="flex items-center gap-3">
                      <div class="w-12 h-12 bg-gray-200 dark:bg-slate-700 rounded-xl"></div>
                      <div class="h-4 bg-gray-200 dark:bg-slate-700 rounded w-20"></div>
                    </div>
                    <div class="text-gray-300 dark:text-slate-600 text-lg font-bold">VS</div>
                    <div class="flex items-center gap-3">
                      <div class="h-4 bg-gray-200 dark:bg-slate-700 rounded w-20"></div>
                      <div class="w-12 h-12 bg-gray-200 dark:bg-slate-700 rounded-xl"></div>
                    </div>
                  </div>
                  <div class="h-4 bg-gray-200 dark:bg-slate-700 rounded w-32 mx-auto"></div>
                </div>
              {{/each}}
            </div>
          {{else if this.isLoading}}
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
              {{#each this.skeletonArray}}
                <div class="bg-white dark:bg-slate-800 rounded-2xl p-5 animate-pulse border border-gray-200 dark:border-slate-700/50">
                  <div class="flex justify-between items-start mb-4">
                    <div class="h-5 bg-gray-200 dark:bg-slate-700 rounded w-24"></div>
                    <div class="h-6 bg-gray-200 dark:bg-slate-700 rounded w-16"></div>
                  </div>
                  <div class="flex items-center justify-between mb-4">
                    <div class="flex items-center gap-3">
                      <div class="w-12 h-12 bg-gray-200 dark:bg-slate-700 rounded-xl"></div>
                      <div class="h-4 bg-gray-200 dark:bg-slate-700 rounded w-20"></div>
                    </div>
                    <div class="text-gray-300 dark:text-slate-600 text-lg font-bold">VS</div>
                    <div class="flex items-center gap-3">
                      <div class="h-4 bg-gray-200 dark:bg-slate-700 rounded w-20"></div>
                      <div class="w-12 h-12 bg-gray-200 dark:bg-slate-700 rounded-xl"></div>
                    </div>
                  </div>
                  <div class="h-4 bg-gray-200 dark:bg-slate-700 rounded w-32 mx-auto"></div>
                </div>
              {{/each}}
            </div>
          {{else if this.error}}
            <div class="bg-white dark:bg-slate-800 rounded-2xl p-8 text-center border border-gray-200 dark:border-slate-700/50">
              <div class="w-16 h-16 mx-auto mb-4 bg-red-500/10 rounded-full flex items-center justify-center">
                <svg class="w-8 h-8 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"></path>
                </svg>
              </div>
              <h3 class="text-gray-900 dark:text-white text-lg font-bold mb-2">Failed to Load Matches</h3>
              <p class="text-gray-600 dark:text-gray-400 text-sm mb-4">{{this.error}}</p>
              <button type="button" class="px-5 py-2.5 bg-cyan-600 hover:bg-cyan-700 text-white text-sm font-medium rounded-lg transition-colors" {{on "click" this.retry}}>
                Try Again
              </button>
            </div>
          {{else if this.displayGames.length}}
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
              {{#each this.displayGames as |game|}}
                <div
                  role="button"
                  tabindex="0"
                  class="group relative bg-white dark:bg-slate-800 rounded-2xl border border-gray-200 dark:border-slate-700/50 hover:border-cyan-500/40 hover:shadow-xl hover:shadow-cyan-500/10 transition-all duration-200 cursor-pointer {{if (eq this.activeShareMenuId game.id) 'z-50' 'z-0'}}"
                  {{on "click" (fn this.goToGameDetails game.id)}}
                >
                  {{! Header: game name + status badge }}
                  <div class="flex items-start justify-between px-4 pt-4 pb-2 gap-2">
                    <div class="min-w-0 flex-1">
                      <p class="text-gray-900 dark:text-white text-sm font-bold truncate group-hover:text-cyan-500 transition-colors">{{game.name}}</p>
                      <p class="text-[11px] text-gray-400 dark:text-gray-500 mt-0.5">{{game.formattedDate}} · {{game.formattedTime}}</p>
                    </div>
                    {{#if game.isFinished}}
                      <span class="px-2.5 py-1 bg-slate-100 dark:bg-slate-700/80 text-slate-500 dark:text-slate-400 text-xs font-semibold rounded-full flex-shrink-0">Finished</span>
                    {{else if game.isStarted}}
                      <div class="flex items-center gap-1.5 flex-shrink-0">
                        <span class="flex items-center gap-1.5 px-2.5 py-1 bg-red-500/10 text-red-500 text-xs font-bold rounded-full ring-1 ring-red-500/20">
                          <span class="w-1.5 h-1.5 rounded-full bg-red-500 animate-pulse"></span>
                          LIVE
                        </span>
                        {{#if game.viewerCount}}
                          <span class="flex items-center gap-1.5 px-2 py-1 bg-black/5 dark:bg-white/5 text-gray-500 dark:text-gray-400 text-[10px] font-medium rounded-full">
                            <svg class="w-3 h-3 text-red-500" fill="currentColor" viewBox="0 0 24 24">
                              <path d="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5zM12 17c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3z"/>
                            </svg>
                            <span class="text-red-500">{{game.viewerCount.live}}</span>
                            <span class="text-gray-300 dark:text-slate-600">·</span>
                            {{game.viewerCount.total}}
                          </span>
                        {{/if}}
                      </div>
                    {{else}}
                      <span class="px-2.5 py-1 bg-blue-500/10 text-blue-500 dark:text-blue-400 text-xs font-semibold rounded-full flex-shrink-0">Upcoming</span>
                    {{/if}}
                  </div>

                  <div class="mx-4 h-px bg-gray-100 dark:bg-slate-700/50"></div>

                  {{! Teams }}
                  <div class="flex items-center gap-3 px-4 py-4">
                    <div class="flex-1 flex flex-col items-center gap-2 min-w-0">
                      <div class="w-14 h-14 rounded-2xl overflow-hidden bg-gray-50 dark:bg-slate-700/60 p-1.5 ring-1 ring-gray-100 dark:ring-slate-600/40">
                        <img src={{game.team1.logo}} alt={{game.team1.name}} class="w-full h-full object-contain" />
                      </div>
                      <p class="text-gray-900 dark:text-white text-xs font-semibold text-center truncate w-full px-1">{{game.team1.name}}</p>
                    </div>
                    <div class="flex-shrink-0">
                      <span class="text-[11px] font-bold tracking-widest text-gray-300 dark:text-slate-600">VS</span>
                    </div>
                    <div class="flex-1 flex flex-col items-center gap-2 min-w-0">
                      <div class="w-14 h-14 rounded-2xl overflow-hidden bg-gray-50 dark:bg-slate-700/60 p-1.5 ring-1 ring-gray-100 dark:ring-slate-600/40">
                        <img src={{game.team2.logo}} alt={{game.team2.name}} class="w-full h-full object-contain" />
                      </div>
                      <p class="text-gray-900 dark:text-white text-xs font-semibold text-center truncate w-full px-1">{{game.team2.name}}</p>
                    </div>
                  </div>

                  {{#if game.isStarted}}
                    {{#if game.liveScore.scoreStr}}
                      <div class="flex items-center justify-center gap-2 py-2 px-4 flex-wrap">
                        {{#if game.liveScore.battingTeamName}}
                          <span class="text-[11px] text-gray-500 dark:text-gray-400 font-medium truncate max-w-[80px]">{{game.liveScore.battingTeamName}}</span>
                          <span class="text-gray-200 dark:text-slate-600">·</span>
                        {{/if}}
                        <span class="text-sm font-bold text-red-500">{{game.liveScore.scoreStr}}</span>
                        {{#if game.liveScore.overs}}
                          <span class="text-[11px] text-gray-400 dark:text-gray-500">({{game.liveScore.overs}} ov)</span>
                        {{/if}}
                        {{#if game.liveScore.crr}}
                          <span class="text-gray-200 dark:text-slate-600">·</span>
                          <span class="text-[11px] text-emerald-500 dark:text-emerald-400 font-medium">CRR {{game.liveScore.crr}}</span>
                        {{/if}}
                        {{#if game.liveScore.rr}}
                          <span class="text-gray-200 dark:text-slate-600">·</span>
                          <span class="text-[11px] text-orange-500 dark:text-orange-400 font-medium">RRR {{game.liveScore.rr}}</span>
                        {{/if}}
                      </div>
                    {{/if}}
                  {{else if game.isFinished}}
                    {{#if game.disposition}}
                      <div class="py-2 px-4 text-center">
                        <span class="text-[11px] text-gray-500 dark:text-gray-400 font-medium">{{game.disposition}}</span>
                      </div>
                    {{/if}}
                  {{/if}}

                  <div class="mx-4 h-px bg-gray-100 dark:bg-slate-700/50"></div>

                  {{! Footer: stats + actions }}
                  <div class="px-4 py-3 flex items-center justify-between gap-2">
                    <div class="flex items-center gap-1.5 text-[11px] text-gray-500 dark:text-gray-400 min-w-0">
                      {{#if game.overs}}
                        <span><span class="text-cyan-500 font-semibold">{{game.overs}}</span> Ovr</span>
                      {{/if}}
                      {{#if game.matchPrize}}
                        <span class="text-gray-200 dark:text-slate-700">•</span>
                        <span class="text-amber-400 font-medium truncate max-w-[60px]">🏆 {{game.matchPrize}}</span>
                      {{/if}}
                    </div>
                    <div class="flex items-center gap-1 flex-shrink-0">
                      <ShareButton @matchId={{game.id}} @matchName={{game.name}} @matchDate={{game.formattedDateTime}} @isLive={{game.isStarted}} @sportType={{game.sportType}} @dropUp={{true}} />
                      {{#unless (or game.isFinished game.isStarted)}}
                        <WatchLaterButton @matchId={{game.id}} @matchType={{game.sportType}} />
                      {{/unless}}
                    </div>
                  </div>

                </div>
              {{/each}}
            </div>

            {{! Infinite scroll sentinel — only when not searching }}
            {{#unless this.searchResults}}
              <div {{infiniteScroll this.loadMore}}></div>
              {{#if this.isLoadingMore}}
                <div class="flex flex-col items-center gap-3 py-8">
                  <svg class="w-6 h-6 text-cyan-500 animate-spin" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8z"></path>
                  </svg>
                  <span class="text-gray-500 dark:text-gray-600 text-xs">Loading more matches…</span>
                </div>
              {{else if this.hasMore}}
                <div class="py-6 text-center">
                  <span class="text-gray-500 dark:text-gray-700 text-xs">{{this.games.length}} matches loaded</span>
                </div>
              {{/if}}
            {{/unless}}

          {{else}}
            <div class="bg-white dark:bg-slate-800 rounded-2xl p-8 text-center border border-gray-200 dark:border-slate-700/50">
              <div class="w-16 h-16 mx-auto mb-4 bg-gray-100 dark:bg-slate-700/50 rounded-full flex items-center justify-center">
                <svg class="w-8 h-8 text-gray-400 dark:text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"></path>
                </svg>
              </div>
              <h3 class="text-gray-900 dark:text-white text-lg font-bold mb-2">No Matches Found</h3>
              <p class="text-gray-600 dark:text-gray-400 text-sm">
                {{#if this.searchQuery}}No results for "{{this.searchQuery}}".{{else}}There are no upcoming matches in your area right now.{{/if}}
              </p>
            </div>
          {{/if}}
        {{/if}}
      </div>

    {{! Sport type picker modal }}
    {{#if this.showSportPicker}}
      <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm" role="dialog">
        <div class="absolute inset-0" {{on "click" this.closeSportPicker}}></div>
        <div class="relative z-10 bg-slate-800 border border-white/10 rounded-2xl shadow-2xl w-72 py-6 px-4">
          <h2 class="text-white font-bold text-center text-lg mb-5">Select Sport</h2>
          <div class="flex flex-col gap-2">
            {{#each this.sportTypes as |sport|}}
              <button
                type="button"
                class="w-full py-3 text-white font-semibold text-base rounded-xl hover:bg-white/10 transition-colors"
                {{on "click" (fn this.selectSport sport)}}
              >
                {{sport}}
              </button>
            {{/each}}
          </div>
        </div>
      </div>
    {{/if}}
  </template>
}
