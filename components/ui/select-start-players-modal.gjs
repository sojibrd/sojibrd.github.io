import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { service } from '@ember/service';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { eq, not } from 'ember-truth-helpers';
import { modifier } from 'ember-modifier';

function initial(str) {
  return str?.charAt(0)?.toUpperCase() ?? '?';
}

const onInsert = modifier((_, [fn]) => { fn(); });

class SelectStartPlayersModalComponent extends Component {
  @service store;
  @service api;
  @service toast;

  @tracked step = 'team-select'; // 'team-select' | 'player-select' | 'toss-select'
  @tracked isLoading = false;
  @tracked isSaving = false;
  @tracked teamData = null;
  @tracked selectedTeamId = null;
  @tracked selectedPlayerIds = new Set();
  @tracked captainId = null;
  @tracked viceCaptainId = null;
  @tracked wicketKeeperId = null;
  @tracked error = null;
  @tracked teamSelectionStatus = {}; // { [teamId]: { count, hasCaptain, hasViceCaptain, hasWicketKeeper, data } }
  @tracked tossWinnerId = null;
  @tracked battingChoice = null; // 'batting' | 'bowling'
  @tracked maxBowlerOvers = null;
  @tracked strikerId = null;
  @tracked nonStrikerId = null;
  @tracked bowlerId = null;
  @tracked lineupPlayers = []; // players for batsman/bowler steps
  @tracked isLineupLoading = false;
  @tracked umpireSource = null; // 'team' | 'list'
  @tracked umpirePlayers = [];
  @tracked selectedUmpireIds = new Set();
  @tracked isUmpireLoading = false;
  @tracked scorerSource = null; // 'team' | 'list'
  @tracked scorerPlayers = [];
  @tracked selectedScorerIds = new Set();
  @tracked activeScorerId = null;
  @tracked isScorerLoading = false;
  @tracked streamerSource = null; // 'team' | 'list'
  @tracked streamerPlayers = [];
  @tracked selectedStreamerIds = new Set();
  @tracked activeStreamerId = null;
  @tracked isStreamerLoading = false;
  _loadSelectionsPromise = null;

  get players() {
    return this.teamData?.players ?? [];
  }

  get selectedCount() {
    return this.selectedPlayerIds.size;
  }

  get requiredPlayersCount() {
    return this.args.model?.gameConfiguration?.number_of_player_in_one_side ?? null;
  }

  get hasEnoughPlayers() {
    return this.selectedPlayerIds.size >= 5;
  }

  get tooManyPlayers() {
    return this.requiredPlayersCount !== null && this.selectedPlayerIds.size > this.requiredPlayersCount;
  }

  get isMaxReached() {
    return this.requiredPlayersCount !== null && this.selectedPlayerIds.size >= this.requiredPlayersCount;
  }

  isPlayerBlocked = (playerId) => this.isMaxReached && !this.selectedPlayerIds.has(playerId);

  get sameCaptainVc() {
    return this.captainId !== null && this.captainId === this.viceCaptainId;
  }

  get isValid() {
    return (
      this.hasEnoughPlayers &&
      !this.tooManyPlayers &&
      this.captainId !== null &&
      this.viceCaptainId !== null &&
      !this.sameCaptainVc &&
      this.wicketKeeperId !== null
    );
  }

  isPlayerSelected = (playerId) => this.selectedPlayerIds.has(playerId);
  isCaptain = (playerId) => this.captainId === playerId;
  isViceCaptain = (playerId) => this.viceCaptainId === playerId;
  isWicketKeeper = (playerId) => this.wicketKeeperId === playerId;

  teamStatus = (teamId) => this.teamSelectionStatus[teamId] ?? null;
  teamStatusCount = (teamId) => this.teamSelectionStatus[teamId]?.count ?? 0;

  get bothTeamsSelected() {
    const t1 = this.args.model?.team1?.id;
    const t2 = this.args.model?.team2?.id;
    return !!(this.teamSelectionStatus[t1] && this.teamSelectionStatus[t2]);
  }

  loadTeamSelections = () => {
    if (this._loadSelectionsPromise) return;

    // Use preloaded data from parent if available — skip network fetch
    const preloaded = this.args.preloadedSelections;
    if (preloaded && Object.keys(preloaded).length > 0) {
      this.teamSelectionStatus = preloaded;
      this._loadSelectionsPromise = Promise.resolve();
      return;
    }

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

    this._loadSelectionsPromise = Promise.all([fetchOne(team1Id), fetchOne(team2Id)])
      .then(([r1, r2]) => {
        const next = {};
        if (r1[1]) next[r1[0]] = r1[1];
        if (r2[1]) next[r2[0]] = r2[1];
        this.teamSelectionStatus = next;
      });
  }

  @action
  async selectTeam(teamId) {
    this.selectedTeamId = teamId;
    this.error = null;
    this.isLoading = true;

    try {
      const peeked = this.store.peekRecord('team-player', teamId);
      const teamDataPromise = peeked
        ? Promise.resolve(peeked)
        : this.store.findRecord('team-player', teamId);

      // Wait for selections to finish loading (no-op if already resolved), then read from cache
      const existingPromise = (this._loadSelectionsPromise ?? Promise.resolve())
        .then(() => this.teamSelectionStatus[teamId]?.data ?? null);

      const [teamData, existing] = await Promise.all([teamDataPromise, existingPromise]);

      this.teamData = teamData;

      if (existing?.start_players?.length) {
        const ids = new Set(existing.start_players.map((p) => p.player_id));
        if (existing.captain_id) ids.add(existing.captain_id);
        if (existing.vice_captain_id) ids.add(existing.vice_captain_id);
        if (existing.wicket_keeper_id) ids.add(existing.wicket_keeper_id);
        this.selectedPlayerIds = ids;
        this.captainId = existing.captain_id ?? null;
        this.viceCaptainId = existing.vice_captain_id ?? null;
        this.wicketKeeperId = existing.wicket_keeper_id ?? null;
      } else {
        this.selectedPlayerIds = new Set();
        this.captainId = teamData.captain ?? null;
        this.viceCaptainId = teamData.viceCaptain ?? null;
        this.wicketKeeperId = teamData.wicketKeepers?.[0] ?? null;
      }

      this.step = 'player-select';
    } catch {
      this.error = 'Could not load players. Please try again.';
    } finally {
      this.isLoading = false;
    }
  }

  @action
  proceedWithExisting() {
    this.tossWinnerId = null;
    this.step = 'toss-select';
  }

  @action
  selectTossWinner(teamId) {
    this.tossWinnerId = teamId;
  }

  get overLimitOptions() {
    const total = this.args.model?.gameConfiguration?.over ?? 10;
    return Array.from({ length: total }, (_, i) => i + 1);
  }

  get tossWinnerTeam() {
    const t1 = this.args.model?.team1;
    const t2 = this.args.model?.team2;
    if (!this.tossWinnerId) return null;
    return t1?.id === this.tossWinnerId ? t1 : t2;
  }

  get battingTeam() {
    const t1 = this.args.model?.team1;
    const t2 = this.args.model?.team2;
    const tosserIsBatting = this.battingChoice === 'batting';
    return (t1?.id === this.tossWinnerId) === tosserIsBatting ? t1 : t2;
  }

  get bowlingTeam() {
    const t1 = this.args.model?.team1;
    const t2 = this.args.model?.team2;
    const tosserIsBatting = this.battingChoice === 'batting';
    return (t1?.id === this.tossWinnerId) === tosserIsBatting ? t2 : t1;
  }

  @action
  tossNext() {
    if (!this.tossWinnerId) return;
    this.battingChoice = null;
    this.step = 'choice-select';
  }

  @action
  selectBattingChoice(choice) {
    this.battingChoice = choice;
  }

  @action
  choiceNext() {
    if (!this.battingChoice) return;
    this.maxBowlerOvers = null;
    this.step = 'over-limit-select';
  }

  @action
  selectMaxBowlerOvers(n) {
    this.maxBowlerOvers = n;
  }

  @action
  async overLimitNext() {
    if (!this.maxBowlerOvers) return;
    this.strikerId = null;
    this.nonStrikerId = null;
    await this._loadLineupPlayers(this.battingTeam?.id);
    this.step = 'batsman-select';
  }

  _loadLineupPlayers = async (teamId) => {
    if (!teamId) return;
    this.isLineupLoading = true;
    try {
      const peeked = this.store.peekRecord('team-player', teamId);
      const data = peeked ?? await this.store.findRecord('team-player', teamId);
      this.lineupPlayers = data?.players ?? [];
    } catch {
      this.lineupPlayers = [];
    } finally {
      this.isLineupLoading = false;
    }
  }

  @action
  setStriker(playerId) {
    if (this.nonStrikerId === playerId) this.nonStrikerId = null;
    this.strikerId = this.strikerId === playerId ? null : playerId;
  }

  @action
  setNonStriker(playerId) {
    if (this.strikerId === playerId) this.strikerId = null;
    this.nonStrikerId = this.nonStrikerId === playerId ? null : playerId;
  }

  get batsmanValid() {
    return this.strikerId && this.nonStrikerId && this.strikerId !== this.nonStrikerId;
  }

  @action
  async batsmanNext() {
    if (!this.batsmanValid) return;
    this.bowlerId = null;
    await this._loadLineupPlayers(this.bowlingTeam?.id);
    this.step = 'bowler-select';
  }

  @action
  selectBowler(playerId) {
    this.bowlerId = this.bowlerId === playerId ? null : playerId;
  }

  @action
  bowlerNext() {
    if (!this.bowlerId) return;
    this.umpireSource = null;
    this.umpirePlayers = [];
    this.selectedUmpireIds = new Set();
    this.step = 'umpire-source-select';
  }

  @action
  async selectUmpireSource(source) {
    this.umpireSource = source;
    this.selectedUmpireIds = new Set();
    this.isUmpireLoading = true;
    try {
      if (source === 'team') {
        const [battingData, bowlingData] = await Promise.all([
          this._fetchTeamPlayers(this.battingTeam?.id),
          this._fetchTeamPlayers(this.bowlingTeam?.id),
        ]);
        // Tag each player with their team side for side-by-side rendering
        this.umpirePlayers = [
          ...battingData.map((p) => ({ ...p, teamSide: 'batting' })),
          ...bowlingData.map((p) => ({ ...p, teamSide: 'bowling' })),
        ];
      } else {
        // Load accepted match officials from the existing Ember model
        const results = await this.store.query('accepted-role-person', {
          game_id: this.args.model?.id,
          role: 'CricketUmipire',
        });
        const bucketHost = this.api.bucket_Images_Host;
        this.umpirePlayers = results
          .filter((r) => r.status === 'accepted')
          .map((r) => ({
            id: r.userid,
            name: r.fullName || r.userid,
            avatar: r.primaryPic ? `${bucketHost}/${r.primaryPic}` : null,
          }));
      }
      this.step = 'umpire-pick';
    } catch {
      this.toast.error('Could not load umpires. Please try again.');
    } finally {
      this.isUmpireLoading = false;
    }
  }

  _fetchTeamPlayers = async (teamId) => {
    if (!teamId) return [];
    try {
      const peeked = this.store.peekRecord('team-player', teamId);
      const data = peeked ?? await this.store.findRecord('team-player', teamId);
      return data?.players ?? [];
    } catch {
      return [];
    }
  }

  @action
  toggleUmpire(playerId) {
    const next = new Set(this.selectedUmpireIds);
    next.has(playerId) ? next.delete(playerId) : next.add(playerId);
    this.selectedUmpireIds = next;
  }

  isUmpireSelected = (playerId) => this.selectedUmpireIds.has(playerId);

  get umpireValid() {
    return this.selectedUmpireIds.size >= 2;
  }

  @action
  umpireNext() {
    if (!this.umpireValid) return;
    this.scorerSource = null;
    this.scorerPlayers = [];
    this.selectedScorerIds = new Set();
    this.activeScorerId = null;
    this.step = 'scorer-source-select';
  }

  @action
  async selectScorerSource(source) {
    this.scorerSource = source;
    this.selectedScorerIds = new Set();
    this.activeScorerId = null;
    this.isScorerLoading = true;
    try {
      if (source === 'team') {
        const [battingData, bowlingData] = await Promise.all([
          this._fetchTeamPlayers(this.battingTeam?.id),
          this._fetchTeamPlayers(this.bowlingTeam?.id),
        ]);
        this.scorerPlayers = [
          ...battingData.map((p) => ({ ...p, teamSide: 'batting' })),
          ...bowlingData.map((p) => ({ ...p, teamSide: 'bowling' })),
        ];
      } else {
        const results = await this.store.query('accepted-role-person', {
          game_id: this.args.model?.id,
          role: 'CricketScorer',
        });
        const bucketHost = this.api.bucket_Images_Host;
        this.scorerPlayers = results
          .filter((r) => r.status === 'accepted')
          .map((r) => ({
            id: r.userid,
            name: r.fullName || r.userid,
            avatar: r.primaryPic ? `${bucketHost}/${r.primaryPic}` : null,
          }));
      }
      this.step = 'scorer-pick';
    } catch {
      this.toast.error('Could not load scorers. Please try again.');
    } finally {
      this.isScorerLoading = false;
    }
  }

  @action
  toggleScorer(playerId) {
    const next = new Set(this.selectedScorerIds);
    if (next.has(playerId)) {
      next.delete(playerId);
      if (this.activeScorerId === playerId) this.activeScorerId = null;
    } else {
      next.add(playerId);
    }
    this.selectedScorerIds = next;
  }

  @action
  setActiveScorer(playerId, e) {
    e?.stopPropagation();
    if (!this.selectedScorerIds.has(playerId)) return;
    this.activeScorerId = this.activeScorerId === playerId ? null : playerId;
  }

  isScorerSelected = (playerId) => this.selectedScorerIds.has(playerId);
  isActiveScorer = (playerId) => this.activeScorerId === playerId;

  get scorerValid() {
    return this.selectedScorerIds.size >= 1 && this.activeScorerId !== null;
  }

  @action
  scorerNext() {
    if (!this.scorerValid) return;
    this.streamerSource = null;
    this.streamerPlayers = [];
    this.selectedStreamerIds = new Set();
    this.activeStreamerId = null;
    this.step = 'streamer-source-select';
  }

  @action
  async selectStreamerSource(source) {
    this.streamerSource = source;
    this.selectedStreamerIds = new Set();
    this.activeStreamerId = null;
    this.isStreamerLoading = true;
    try {
      if (source === 'team') {
        const [battingData, bowlingData] = await Promise.all([
          this._fetchTeamPlayers(this.battingTeam?.id),
          this._fetchTeamPlayers(this.bowlingTeam?.id),
        ]);
        this.streamerPlayers = [
          ...battingData.map((p) => ({ ...p, teamSide: 'batting' })),
          ...bowlingData.map((p) => ({ ...p, teamSide: 'bowling' })),
        ];
      } else {
        const results = await this.store.query('accepted-role-person', {
          game_id: this.args.model?.id,
          role: 'CricketVideoStreamer',
        });
        const bucketHost = this.api.bucket_Images_Host;
        this.streamerPlayers = results
          .filter((r) => r.status === 'accepted')
          .map((r) => ({
            id: r.userid,
            name: r.fullName || r.userid,
            avatar: r.primaryPic ? `${bucketHost}/${r.primaryPic}` : null,
          }));
      }
      this.step = 'streamer-pick';
    } catch {
      this.toast.error('Could not load streamers. Please try again.');
    } finally {
      this.isStreamerLoading = false;
    }
  }

  @action
  toggleStreamer(playerId) {
    const next = new Set(this.selectedStreamerIds);
    if (next.has(playerId)) {
      next.delete(playerId);
      if (this.activeStreamerId === playerId) this.activeStreamerId = null;
    } else {
      next.add(playerId);
    }
    this.selectedStreamerIds = next;
  }

  @action
  setActiveStreamer(playerId, e) {
    e?.stopPropagation();
    if (!this.selectedStreamerIds.has(playerId)) return;
    this.activeStreamerId = this.activeStreamerId === playerId ? null : playerId;
  }

  isStreamerSelected = (playerId) => this.selectedStreamerIds.has(playerId);
  isActiveStreamer = (playerId) => this.activeStreamerId === playerId;

  get streamerValid() {
    return this.selectedStreamerIds.size >= 1 && this.activeStreamerId !== null;
  }

  @action
  streamerNext() {
    this.args.onDone?.({
      tossWinnerId: this.tossWinnerId,
      battingChoice: this.battingChoice,
      maxBowlerOvers: this.maxBowlerOvers,
      strikerId: this.strikerId,
      nonStrikerId: this.nonStrikerId,
      bowlerId: this.bowlerId,
      umpireIds: [...this.selectedUmpireIds],
      scorerIds: [...this.selectedScorerIds],
      activeScorerId: this.activeScorerId,
      streamerIds: [...this.selectedStreamerIds],
      activeStreamerId: this.activeStreamerId,
    });
    this.handleClose();
  }

  @action
  async back() {
    if (this.step === 'streamer-pick') {
      this.step = 'streamer-source-select';
      this.selectedStreamerIds = new Set();
      this.activeStreamerId = null;
      this.streamerPlayers = [];
      this.streamerSource = null;
      return;
    }
    if (this.step === 'streamer-source-select') {
      this.step = 'scorer-pick';
      return;
    }
    if (this.step === 'scorer-pick') {
      this.step = 'scorer-source-select';
      this.selectedScorerIds = new Set();
      this.activeScorerId = null;
      this.scorerPlayers = [];
      this.scorerSource = null;
      return;
    }
    if (this.step === 'scorer-source-select') {
      this.step = 'umpire-pick';
      return;
    }
    if (this.step === 'umpire-pick') {
      this.step = 'umpire-source-select';
      this.selectedUmpireIds = new Set();
      this.umpirePlayers = [];
      this.umpireSource = null;
      return;
    }
    if (this.step === 'umpire-source-select') {
      this.step = 'bowler-select';
      await this._loadLineupPlayers(this.bowlingTeam?.id);
      return;
    }
    if (this.step === 'bowler-select') {
      this.step = 'batsman-select';
      this.bowlerId = null;
      await this._loadLineupPlayers(this.battingTeam?.id);
      return;
    }
    if (this.step === 'batsman-select') {
      this.step = 'over-limit-select';
      this.strikerId = null;
      this.nonStrikerId = null;
      this.lineupPlayers = [];
      return;
    }
    if (this.step === 'over-limit-select') {
      this.step = 'choice-select';
      this.maxBowlerOvers = null;
      return;
    }
    if (this.step === 'choice-select') {
      this.step = 'toss-select';
      this.battingChoice = null;
      return;
    }
    if (this.step === 'toss-select') {
      this.step = 'team-select';
      this.tossWinnerId = null;
      return;
    }
    this.step = 'team-select';
    this.teamData = null;
    this.selectedPlayerIds = new Set();
    this.captainId = null;
    this.viceCaptainId = null;
    this.error = null;
  }

  @action
  togglePlayer(player, e) {
    if (e) e.stopPropagation();
    if (player.pending) return;
    const playerId = player.id;
    const next = new Set(this.selectedPlayerIds);
    if (next.has(playerId)) {
      next.delete(playerId);
      if (this.captainId === playerId) this.captainId = null;
      if (this.viceCaptainId === playerId) this.viceCaptainId = null;
      if (this.wicketKeeperId === playerId) this.wicketKeeperId = null;
    } else {
      if (this.requiredPlayersCount !== null && next.size >= this.requiredPlayersCount) return;
      next.add(playerId);
    }
    this.selectedPlayerIds = next;
  }

  @action
  setCaptain(player, e) {
    e.stopPropagation();
    if (player.pending) return;
    if (this.captainId === player.id) {
      this.captainId = null;
    } else {
      this.captainId = player.id;
      if (this.viceCaptainId === player.id) this.viceCaptainId = null;
    }
  }

  @action
  setViceCaptain(player, e) {
    e.stopPropagation();
    if (player.pending) return;
    if (this.viceCaptainId === player.id) {
      this.viceCaptainId = null;
    } else {
      this.viceCaptainId = player.id;
      if (this.captainId === player.id) this.captainId = null;
    }
  }

  @action
  setWicketKeeper(player, e) {
    e.stopPropagation();
    if (player.pending) return;
    this.wicketKeeperId = this.wicketKeeperId === player.id ? null : player.id;
  }

  @action
  async handleDone() {
    if (!this.isValid || this.isSaving) return;

    const selectedPlayers = this.players.filter((p) => this.selectedPlayerIds.has(p.id));
    const payload = {
      game_id: this.args.model?.id,
      [this.selectedTeamId]: {
        captain_id: this.captainId,
        vice_captain_id: this.viceCaptainId,
        wicket_keeper: this.wicketKeeperId,
        start_players: selectedPlayers.map((p) => ({
          player_id: p.id,
          PlayerName: { first_name: p.firstName, last_name: p.lastName },
          player_image: p.playerImage ?? '',
          has_skill_left_handed_batsman: p.isLeftHanded ?? false,
          is12thMan: p.is12thMan || null,
          pending: p.pending || null,
        })),
        players_on_field: [],
      },
    };

    this.isSaving = true;
    try {
      const res = await this.api.post('/live_scoring/playing-player/', payload);
      const msg = res?.data?.message || res?.message || 'Players saved successfully.';
      this.toast.success(msg);

      if (this.args.isStartFlow) {
        // Update local status for the saved team
        const next = { ...this.teamSelectionStatus };
        next[this.selectedTeamId] = {
          count: selectedPlayers.length,
          hasCaptain: !!this.captainId,
          hasViceCaptain: !!this.viceCaptainId,
          hasWicketKeeper: !!this.wicketKeeperId,
          data: {
            start_players: selectedPlayers.map((p) => ({ player_id: p.id })),
            captain_id: this.captainId,
            vice_captain_id: this.viceCaptainId,
            wicket_keeper_id: this.wicketKeeperId,
          },
        };
        this.teamSelectionStatus = next;

        const t1Id = this.args.model?.team1?.id;
        const t2Id = this.args.model?.team2?.id;
        const bothDone = !!(next[t1Id] && next[t2Id]);

        if (bothDone) {
          this.tossWinnerId = null;
          this.step = 'toss-select';
        } else {
          // Go back to team-select to pick the other team
          this.teamData = null;
          this.selectedPlayerIds = new Set();
          this.captainId = null;
          this.viceCaptainId = null;
          this.wicketKeeperId = null;
          this.selectedTeamId = null;
          this.step = 'team-select';
        }
      } else {
        this.args.onDone?.();
        this.handleClose();
      }
    } catch (e) {
      this.toast.error(e?.payload?.message || 'Failed to save players.');
    } finally {
      this.isSaving = false;
    }
  }

  @action
  handleClose() {
    this.step = 'team-select';
    this.teamData = null;
    this.selectedPlayerIds = new Set();
    this.captainId = null;
    this.viceCaptainId = null;
    this.wicketKeeperId = null;
    this.error = null;
    this.selectedTeamId = null;
    this.tossWinnerId = null;
    this.battingChoice = null;
    this.maxBowlerOvers = null;
    this.strikerId = null;
    this.nonStrikerId = null;
    this.bowlerId = null;
    this.lineupPlayers = [];
    this.isLineupLoading = false;
    this.umpireSource = null;
    this.umpirePlayers = [];
    this.selectedUmpireIds = new Set();
    this.isUmpireLoading = false;
    this.scorerSource = null;
    this.scorerPlayers = [];
    this.selectedScorerIds = new Set();
    this.activeScorerId = null;
    this.isScorerLoading = false;
    this.streamerSource = null;
    this.streamerPlayers = [];
    this.selectedStreamerIds = new Set();
    this.activeStreamerId = null;
    this.isStreamerLoading = false;
    this.isLoading = false;
    this.isSaving = false;
    this.teamSelectionStatus = {};
    this._loadSelectionsPromise = null;
    this.args.onClose?.();
  }

  <template>
    {{#if @isOpen}}
      <div class="fixed inset-0 z-50 flex items-end sm:items-center justify-center" role="dialog" aria-modal="true" {{onInsert this.loadTeamSelections}}>

        {{! Backdrop }}
        <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" role="presentation" {{on "click" this.handleClose}}></div>

        {{! Sheet }}
        <div class="relative w-full sm:max-w-md bg-slate-800 rounded-t-2xl sm:rounded-2xl shadow-2xl border border-slate-700/60 z-10 flex flex-col max-h-[85vh]">

          {{! Header }}
          <div class="px-5 pt-5 pb-4 flex-shrink-0 border-b border-slate-700/50">
            <div class="flex items-center gap-3">
              {{#if (eq this.step "player-select")}}
                <button
                  type="button"
                  class="w-8 h-8 flex items-center justify-center text-gray-400 hover:text-white rounded-lg hover:bg-slate-700 transition-colors flex-shrink-0"
                  {{on "click" this.back}}
                >
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
                  </svg>
                </button>
              {{else if (eq this.step "batsman-select")}}
                <button type="button" class="w-8 h-8 flex items-center justify-center text-gray-400 hover:text-white rounded-lg hover:bg-slate-700 transition-colors flex-shrink-0" {{on "click" this.back}}>
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" /></svg>
                </button>
              {{else if (eq this.step "bowler-select")}}
                <button type="button" class="w-8 h-8 flex items-center justify-center text-gray-400 hover:text-white rounded-lg hover:bg-slate-700 transition-colors flex-shrink-0" {{on "click" this.back}}>
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" /></svg>
                </button>
              {{else if (eq this.step "umpire-source-select")}}
                <button type="button" class="w-8 h-8 flex items-center justify-center text-gray-400 hover:text-white rounded-lg hover:bg-slate-700 transition-colors flex-shrink-0" {{on "click" this.back}}>
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" /></svg>
                </button>
              {{else if (eq this.step "umpire-pick")}}
                <button type="button" class="w-8 h-8 flex items-center justify-center text-gray-400 hover:text-white rounded-lg hover:bg-slate-700 transition-colors flex-shrink-0" {{on "click" this.back}}>
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" /></svg>
                </button>
              {{else if (eq this.step "scorer-source-select")}}
                <button type="button" class="w-8 h-8 flex items-center justify-center text-gray-400 hover:text-white rounded-lg hover:bg-slate-700 transition-colors flex-shrink-0" {{on "click" this.back}}>
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" /></svg>
                </button>
              {{else if (eq this.step "scorer-pick")}}
                <button type="button" class="w-8 h-8 flex items-center justify-center text-gray-400 hover:text-white rounded-lg hover:bg-slate-700 transition-colors flex-shrink-0" {{on "click" this.back}}>
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" /></svg>
                </button>
              {{else if (eq this.step "streamer-source-select")}}
                <button type="button" class="w-8 h-8 flex items-center justify-center text-gray-400 hover:text-white rounded-lg hover:bg-slate-700 transition-colors flex-shrink-0" {{on "click" this.back}}>
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" /></svg>
                </button>
              {{else if (eq this.step "streamer-pick")}}
                <button type="button" class="w-8 h-8 flex items-center justify-center text-gray-400 hover:text-white rounded-lg hover:bg-slate-700 transition-colors flex-shrink-0" {{on "click" this.back}}>
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" /></svg>
                </button>
              {{/if}}
              <h3 class="text-white font-bold text-lg flex-1 truncate">
                {{#if (eq this.step "player-select")}}
                  {{this.teamData.teamName}}
                {{else if (eq this.step "toss-select")}}
                  Select Toss Winner Team
                {{else if (eq this.step "choice-select")}}
                  Select Batting or Bowling Team
                {{else if (eq this.step "over-limit-select")}}
                  Select Bowler Maximum Over
                {{else if (eq this.step "batsman-select")}}
                  Select Opening Batsmen
                {{else if (eq this.step "bowler-select")}}
                  Select Opening Bowler
                {{else if (eq this.step "umpire-source-select")}}
                  Select Umpire
                {{else if (eq this.step "umpire-pick")}}
                  Select Umpire
                {{else if (eq this.step "scorer-source-select")}}
                  Select Scorer
                {{else if (eq this.step "scorer-pick")}}
                  Select Scorer
                {{else if (eq this.step "streamer-source-select")}}
                  Select Streamer
                {{else if (eq this.step "streamer-pick")}}
                  Select Streamer
                {{else}}
                  Select Starting Players
                {{/if}}
              </h3>
              <button
                type="button"
                class="w-8 h-8 flex items-center justify-center text-gray-400 hover:text-white rounded-lg hover:bg-slate-700 transition-colors flex-shrink-0"
                {{on "click" this.handleClose}}
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
          </div>

          {{! Body }}
          <div class="flex-1 overflow-y-auto">

            {{! ── Team Select Step ── }}
            {{#if (eq this.step "team-select")}}
              <div class="p-5 space-y-3">
                <p class="text-sm text-gray-400 mb-4">Choose which team's starting players to set</p>

                <button
                  type="button"
                  class="w-full flex items-center gap-4 p-4 rounded-2xl transition-colors text-left disabled:opacity-50
                    {{if (this.teamStatus @model.team1.id)
                      'bg-cyan-900/30 hover:bg-cyan-900/50 border border-cyan-700/40'
                      'bg-slate-700 hover:bg-slate-600'}}"
                  disabled={{this.isLoading}}
                  {{on "click" (fn this.selectTeam @model.team1.id)}}
                >
                  {{#if @model.team1.logo}}
                    <img src={{@model.team1.logo}} alt={{@model.team1.name}} class="w-12 h-12 rounded-xl object-cover flex-shrink-0 bg-slate-600" />
                  {{else}}
                    <div class="w-12 h-12 rounded-xl bg-slate-600 flex items-center justify-center flex-shrink-0">
                      <span class="text-white font-bold text-lg">{{initial @model.team1.name}}</span>
                    </div>
                  {{/if}}
                  <div class="flex-1 min-w-0">
                    <p class="text-white font-semibold truncate">{{@model.team1.name}}</p>
                    <p class="text-gray-400 text-xs mt-0.5">Team 1</p>
                  </div>
                  {{#if (this.teamStatus @model.team1.id)}}
                    <span class="flex items-center gap-1 text-[10px] font-semibold px-2 py-0.5 rounded-full bg-cyan-500/20 text-cyan-400 flex-shrink-0">
                      <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" />
                      </svg>
                      {{this.teamStatusCount @model.team1.id}}
                    </span>
                  {{/if}}
                  <svg class="w-5 h-5 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                  </svg>
                </button>

                <button
                  type="button"
                  class="w-full flex items-center gap-4 p-4 rounded-2xl transition-colors text-left disabled:opacity-50
                    {{if (this.teamStatus @model.team2.id)
                      'bg-cyan-900/30 hover:bg-cyan-900/50 border border-cyan-700/40'
                      'bg-slate-700 hover:bg-slate-600'}}"
                  disabled={{this.isLoading}}
                  {{on "click" (fn this.selectTeam @model.team2.id)}}
                >
                  {{#if @model.team2.logo}}
                    <img src={{@model.team2.logo}} alt={{@model.team2.name}} class="w-12 h-12 rounded-xl object-cover flex-shrink-0 bg-slate-600" />
                  {{else}}
                    <div class="w-12 h-12 rounded-xl bg-slate-600 flex items-center justify-center flex-shrink-0">
                      <span class="text-white font-bold text-lg">{{initial @model.team2.name}}</span>
                    </div>
                  {{/if}}
                  <div class="flex-1 min-w-0">
                    <p class="text-white font-semibold truncate">{{@model.team2.name}}</p>
                    <p class="text-gray-400 text-xs mt-0.5">Team 2</p>
                  </div>
                  {{#if (this.teamStatus @model.team2.id)}}
                    <span class="flex items-center gap-1 text-[10px] font-semibold px-2 py-0.5 rounded-full bg-cyan-500/20 text-cyan-400 flex-shrink-0">
                      <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" />
                      </svg>
                      {{this.teamStatusCount @model.team2.id}}
                    </span>
                  {{/if}}
                  <svg class="w-5 h-5 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                  </svg>
                </button>

                {{#if this.isLoading}}
                  <div class="flex justify-center py-4">
                    <div class="w-6 h-6 border-2 border-slate-600 border-t-cyan-400 rounded-full animate-spin"></div>
                  </div>
                {{/if}}

                {{#if this.error}}
                  <p class="text-red-400 text-sm text-center py-2">{{this.error}}</p>
                {{/if}}

                {{! Next button — shown when both teams already have selections }}
                {{#if this.bothTeamsSelected}}
                  <div class="pt-2 pb-1">
                    <button
                      type="button"
                      class="w-full py-3 rounded-xl bg-cyan-600 hover:bg-cyan-500 text-white text-sm font-semibold transition-colors"
                      {{on "click" this.proceedWithExisting}}
                    >
                      Next
                    </button>
                  </div>
                {{/if}}
              </div>

            {{! ── Toss Select Step ── }}
            {{else if (eq this.step "toss-select")}}
              <div class="p-5 flex flex-col gap-4">
                <p class="text-sm text-gray-400 text-center">Select One Team to Win the Toss</p>

                <button
                  type="button"
                  class="w-full flex items-center gap-4 p-4 rounded-2xl border-2 transition-colors text-left
                    {{if (eq this.tossWinnerId @model.team1.id)
                      'border-cyan-500 bg-cyan-900/30'
                      'border-slate-700/40 bg-slate-700 hover:bg-slate-600'}}"
                  {{on "click" (fn this.selectTossWinner @model.team1.id)}}
                >
                  {{#if @model.team1.logo}}
                    <img src={{@model.team1.logo}} alt={{@model.team1.name}} class="w-12 h-12 rounded-xl object-cover flex-shrink-0 bg-slate-600" />
                  {{else}}
                    <div class="w-12 h-12 rounded-xl bg-slate-600 flex items-center justify-center flex-shrink-0">
                      <span class="text-white font-bold text-lg">{{initial @model.team1.name}}</span>
                    </div>
                  {{/if}}
                  <p class="text-white font-semibold flex-1 truncate">{{@model.team1.name}}</p>
                  {{#if (eq this.tossWinnerId @model.team1.id)}}
                    <div class="w-5 h-5 rounded-full bg-cyan-500 flex items-center justify-center flex-shrink-0">
                      <svg class="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" />
                      </svg>
                    </div>
                  {{/if}}
                </button>

                <div class="text-center text-gray-400 font-semibold text-sm">VS</div>

                <button
                  type="button"
                  class="w-full flex items-center gap-4 p-4 rounded-2xl border-2 transition-colors text-left
                    {{if (eq this.tossWinnerId @model.team2.id)
                      'border-cyan-500 bg-cyan-900/30'
                      'border-slate-700/40 bg-slate-700 hover:bg-slate-600'}}"
                  {{on "click" (fn this.selectTossWinner @model.team2.id)}}
                >
                  {{#if @model.team2.logo}}
                    <img src={{@model.team2.logo}} alt={{@model.team2.name}} class="w-12 h-12 rounded-xl object-cover flex-shrink-0 bg-slate-600" />
                  {{else}}
                    <div class="w-12 h-12 rounded-xl bg-slate-600 flex items-center justify-center flex-shrink-0">
                      <span class="text-white font-bold text-lg">{{initial @model.team2.name}}</span>
                    </div>
                  {{/if}}
                  <p class="text-white font-semibold flex-1 truncate">{{@model.team2.name}}</p>
                  {{#if (eq this.tossWinnerId @model.team2.id)}}
                    <div class="w-5 h-5 rounded-full bg-cyan-500 flex items-center justify-center flex-shrink-0">
                      <svg class="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" />
                      </svg>
                    </div>
                  {{/if}}
                </button>
              </div>

            {{! ── Choice Select Step ── }}
            {{else if (eq this.step "choice-select")}}
              <div class="p-5 flex flex-col items-center gap-6">
                <p class="text-sm text-gray-400 text-center">
                  <span class="text-white font-semibold">{{this.tossWinnerTeam.name}}</span> Won the Toss, Now Choose Batting or Bowling
                </p>

                {{! Toss winner team card }}
                <div class="w-full p-5 rounded-2xl bg-emerald-800/50 border border-emerald-600/40 flex items-center gap-4">
                  {{#if this.tossWinnerTeam.logo}}
                    <img src={{this.tossWinnerTeam.logo}} alt={{this.tossWinnerTeam.name}} class="w-14 h-14 rounded-xl object-cover flex-shrink-0 bg-slate-600" />
                  {{else}}
                    <div class="w-14 h-14 rounded-xl bg-emerald-700/60 flex items-center justify-center flex-shrink-0">
                      <span class="text-white font-bold text-xl">{{initial this.tossWinnerTeam.name}}</span>
                    </div>
                  {{/if}}
                  <p class="text-white font-bold text-base flex-1 truncate">{{this.tossWinnerTeam.name}}</p>
                </div>

                {{! Batting / Bowling toggle }}
                <div class="flex items-center gap-6">
                  {{! Batting }}
                  <button
                    type="button"
                    class="flex flex-col items-center gap-2 group"
                    {{on "click" (fn this.selectBattingChoice "batting")}}
                  >
                    <div class="w-14 h-14 rounded-full border-2 flex items-center justify-center transition-colors
                      {{if (eq this.battingChoice 'batting')
                        'border-cyan-400 bg-cyan-500/20'
                        'border-slate-600 bg-slate-700 group-hover:border-slate-500'}}">
                      {{! Cricket bat SVG }}
                      <svg class="w-7 h-7 {{if (eq this.battingChoice 'batting') 'text-cyan-400' 'text-gray-400 group-hover:text-gray-300'}}" viewBox="0 0 24 24" fill="currentColor">
                        <path d="M4.5 19.5l9-9 1.5 1.5-9 9L4.5 19.5zm10-11.5L20 2.5 21.5 4 16 9.5 14.5 8z"/>
                        <path d="M14 8l2-2 1.5 1.5-2 2L14 8z" opacity=".6"/>
                      </svg>
                    </div>
                    <span class="text-xs font-semibold {{if (eq this.battingChoice 'batting') 'text-cyan-400' 'text-gray-400 group-hover:text-gray-300'}}">Batting</span>
                  </button>

                  {{! Bowling }}
                  <button
                    type="button"
                    class="flex flex-col items-center gap-2 group"
                    {{on "click" (fn this.selectBattingChoice "bowling")}}
                  >
                    <div class="w-14 h-14 rounded-full border-2 flex items-center justify-center transition-colors
                      {{if (eq this.battingChoice 'bowling')
                        'border-red-400 bg-red-500/20'
                        'border-slate-600 bg-slate-700 group-hover:border-slate-500'}}">
                      {{! Cricket ball SVG }}
                      <svg class="w-7 h-7 {{if (eq this.battingChoice 'bowling') 'text-red-400' 'text-gray-400 group-hover:text-gray-300'}}" viewBox="0 0 24 24" fill="currentColor">
                        <circle cx="12" cy="12" r="9"/>
                        <path d="M12 3C7 3 3 7 3 12s4 9 9 9 9-4 9-9-4-9-9-9z" fill="none" stroke="currentColor" stroke-width="1" opacity=".3"/>
                        <path d="M5.5 8.5C7 10 7 14 5.5 15.5M18.5 8.5C17 10 17 14 18.5 15.5M8.5 5.5C10 7 14 7 15.5 5.5M8.5 18.5C10 17 14 17 15.5 18.5" fill="none" stroke="white" stroke-width="1.2" stroke-linecap="round" opacity=".6"/>
                      </svg>
                    </div>
                    <span class="text-xs font-semibold {{if (eq this.battingChoice 'bowling') 'text-red-400' 'text-gray-400 group-hover:text-gray-300'}}">Bowling</span>
                  </button>
                </div>
              </div>

            {{! ── Over Limit Select Step ── }}
            {{else if (eq this.step "over-limit-select")}}
              <div class="p-5">
                <div class="flex flex-wrap gap-2">
                  {{#each this.overLimitOptions as |n|}}
                    <button
                      type="button"
                      class="px-4 py-2 rounded-lg text-sm font-semibold transition-colors
                        {{if (eq this.maxBowlerOvers n)
                          'bg-cyan-600 text-white'
                          'bg-slate-700 hover:bg-slate-600 text-gray-200'}}"
                      {{on "click" (fn this.selectMaxBowlerOvers n)}}
                    >
                      {{n}} Over
                    </button>
                  {{/each}}
                </div>
              </div>

            {{! ── Batsman Select Step ── }}
            {{else if (eq this.step "batsman-select")}}
              {{#if this.isLineupLoading}}
                <div class="flex justify-center py-10">
                  <div class="w-6 h-6 border-2 border-slate-600 border-t-cyan-400 rounded-full animate-spin"></div>
                </div>
              {{else}}
                <p class="text-xs text-gray-400 text-center pt-3 pb-1">
                  {{this.battingTeam.name}} — Select Striker (S) and Non-Striker (NS)
                </p>
                <div class="divide-y divide-slate-700/50">
                  {{#each this.lineupPlayers as |player|}}
                    <div class="flex items-center gap-3 px-4 py-3">
                      <div class="w-10 h-10 rounded-xl flex-shrink-0 overflow-hidden bg-slate-700 flex items-center justify-center">
                        {{#if player.avatar}}
                          <img src={{player.avatar}} alt={{player.name}} class="w-full h-full object-cover" />
                        {{else}}
                          <span class="text-white font-bold text-sm">{{initial player.name}}</span>
                        {{/if}}
                      </div>
                      <p class="text-white text-sm font-medium flex-1 truncate">{{player.name}}</p>
                      <button
                        type="button"
                        class="w-8 h-8 rounded-full text-[10px] font-bold transition-colors flex-shrink-0
                          {{if (eq this.strikerId player.id)
                            'bg-cyan-500 text-white'
                            'bg-slate-700 text-gray-400 hover:bg-slate-600 hover:text-white'}}"
                        {{on "click" (fn this.setStriker player.id)}}
                      >S</button>
                      <button
                        type="button"
                        class="w-8 h-8 rounded-full text-[10px] font-bold transition-colors flex-shrink-0
                          {{if (eq this.nonStrikerId player.id)
                            'bg-emerald-500 text-white'
                            'bg-slate-700 text-gray-400 hover:bg-slate-600 hover:text-white'}}"
                        {{on "click" (fn this.setNonStriker player.id)}}
                      >NS</button>
                    </div>
                  {{/each}}
                </div>
              {{/if}}

            {{! ── Bowler Select Step ── }}
            {{else if (eq this.step "bowler-select")}}
              {{#if this.isLineupLoading}}
                <div class="flex justify-center py-10">
                  <div class="w-6 h-6 border-2 border-slate-600 border-t-cyan-400 rounded-full animate-spin"></div>
                </div>
              {{else}}
                <p class="text-xs text-gray-400 text-center pt-3 pb-1">
                  {{this.bowlingTeam.name}} — Select one bowler
                </p>
                <div class="divide-y divide-slate-700/50">
                  {{#each this.lineupPlayers as |player|}}
                    <div
                      role="button"
                      tabindex="0"
                      class="flex items-center gap-3 px-4 py-3 cursor-pointer hover:bg-slate-700/40 transition-colors"
                      {{on "click" (fn this.selectBowler player.id)}}
                    >
                      <div class="w-10 h-10 rounded-xl flex-shrink-0 overflow-hidden bg-slate-700 flex items-center justify-center">
                        {{#if player.avatar}}
                          <img src={{player.avatar}} alt={{player.name}} class="w-full h-full object-cover" />
                        {{else}}
                          <span class="text-white font-bold text-sm">{{initial player.name}}</span>
                        {{/if}}
                      </div>
                      <p class="text-white text-sm font-medium flex-1 truncate">{{player.name}}</p>
                      <div class="w-6 h-6 rounded-full border-2 flex-shrink-0 flex items-center justify-center transition-colors
                        {{if (eq this.bowlerId player.id)
                          'border-red-400 bg-red-400'
                          'border-gray-500'}}">
                        {{#if (eq this.bowlerId player.id)}}
                          <svg class="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" />
                          </svg>
                        {{/if}}
                      </div>
                    </div>
                  {{/each}}
                </div>
              {{/if}}

            {{! ── Umpire Source Select Step ── }}
            {{else if (eq this.step "umpire-source-select")}}
              <div class="p-5 flex flex-col gap-3">
                {{#if this.isUmpireLoading}}
                  <div class="flex justify-center py-8">
                    <div class="w-6 h-6 border-2 border-slate-600 border-t-cyan-400 rounded-full animate-spin"></div>
                  </div>
                {{else}}
                  <button
                    type="button"
                    class="w-full py-4 px-5 rounded-2xl bg-slate-700 hover:bg-slate-600 text-white font-semibold text-sm text-center transition-colors"
                    {{on "click" (fn this.selectUmpireSource "team")}}
                  >
                    Select From<br>Batting &amp; Bowling Team
                  </button>
                  <button
                    type="button"
                    class="w-full py-4 px-5 rounded-2xl bg-slate-700 hover:bg-slate-600 text-white font-semibold text-sm text-center transition-colors"
                    {{on "click" (fn this.selectUmpireSource "list")}}
                  >
                    Select From Umpire List
                  </button>
                {{/if}}
              </div>

            {{! ── Umpire Pick Step ── }}
            {{else if (eq this.step "umpire-pick")}}
              {{#if this.isUmpireLoading}}
                <div class="flex justify-center py-10">
                  <div class="w-6 h-6 border-2 border-slate-600 border-t-cyan-400 rounded-full animate-spin"></div>
                </div>
              {{else if this.umpirePlayers.length}}
                <p class="text-xs text-gray-400 text-center pt-3 pb-1">Select at least 2 umpires</p>

                {{#if (eq this.umpireSource "team")}}
                  {{! ── Side-by-side team columns ── }}
                  <div class="grid grid-cols-2 divide-x divide-slate-700/50">
                    {{! Batting team column }}
                    <div class="flex flex-col">
                      <p class="text-[10px] font-semibold text-cyan-400 text-center py-2 border-b border-slate-700/50 truncate px-2">
                        {{this.battingTeam.name}}
                      </p>
                      {{#each this.umpirePlayers as |player|}}
                        {{#if (eq player.teamSide "batting")}}
                          <button
                            type="button"
                            class="flex flex-col items-center gap-1.5 px-2 py-3 transition-colors hover:bg-slate-700/40 border-b border-slate-700/30
                              {{if (this.isUmpireSelected player.id) 'bg-cyan-900/20'}}"
                            {{on "click" (fn this.toggleUmpire player.id)}}
                          >
                            <div class="relative">
                              <div class="w-10 h-10 rounded-xl overflow-hidden bg-slate-700 flex items-center justify-center flex-shrink-0">
                                {{#if player.avatar}}
                                  <img src={{player.avatar}} alt={{player.name}} class="w-full h-full object-cover" />
                                {{else}}
                                  <span class="text-white font-bold text-sm">{{initial player.name}}</span>
                                {{/if}}
                              </div>
                              {{#if (this.isUmpireSelected player.id)}}
                                <div class="absolute -top-1 -right-1 w-4 h-4 rounded-full bg-cyan-400 flex items-center justify-center">
                                  <svg class="w-2.5 h-2.5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" />
                                  </svg>
                                </div>
                              {{/if}}
                            </div>
                            <p class="text-white text-[10px] font-medium text-center leading-tight line-clamp-2 w-full">{{player.name}}</p>
                          </button>
                        {{/if}}
                      {{/each}}
                    </div>

                    {{! Bowling team column }}
                    <div class="flex flex-col">
                      <p class="text-[10px] font-semibold text-orange-400 text-center py-2 border-b border-slate-700/50 truncate px-2">
                        {{this.bowlingTeam.name}}
                      </p>
                      {{#each this.umpirePlayers as |player|}}
                        {{#if (eq player.teamSide "bowling")}}
                          <button
                            type="button"
                            class="flex flex-col items-center gap-1.5 px-2 py-3 transition-colors hover:bg-slate-700/40 border-b border-slate-700/30
                              {{if (this.isUmpireSelected player.id) 'bg-cyan-900/20'}}"
                            {{on "click" (fn this.toggleUmpire player.id)}}
                          >
                            <div class="relative">
                              <div class="w-10 h-10 rounded-xl overflow-hidden bg-slate-700 flex items-center justify-center flex-shrink-0">
                                {{#if player.avatar}}
                                  <img src={{player.avatar}} alt={{player.name}} class="w-full h-full object-cover" />
                                {{else}}
                                  <span class="text-white font-bold text-sm">{{initial player.name}}</span>
                                {{/if}}
                              </div>
                              {{#if (this.isUmpireSelected player.id)}}
                                <div class="absolute -top-1 -right-1 w-4 h-4 rounded-full bg-cyan-400 flex items-center justify-center">
                                  <svg class="w-2.5 h-2.5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" />
                                  </svg>
                                </div>
                              {{/if}}
                            </div>
                            <p class="text-white text-[10px] font-medium text-center leading-tight line-clamp-2 w-full">{{player.name}}</p>
                          </button>
                        {{/if}}
                      {{/each}}
                    </div>
                  </div>

                {{else}}
                  {{! ── Single list (from official list) ── }}
                  <div class="divide-y divide-slate-700/50">
                    {{#each this.umpirePlayers as |player|}}
                      <div
                        role="button"
                        tabindex="0"
                        class="flex items-center gap-3 px-4 py-3 cursor-pointer hover:bg-slate-700/40 transition-colors"
                        {{on "click" (fn this.toggleUmpire player.id)}}
                      >
                        <div class="w-10 h-10 rounded-xl flex-shrink-0 overflow-hidden bg-slate-700 flex items-center justify-center">
                          {{#if player.avatar}}
                            <img src={{player.avatar}} alt={{player.name}} class="w-full h-full object-cover" />
                          {{else}}
                            <span class="text-white font-bold text-sm">{{initial player.name}}</span>
                          {{/if}}
                        </div>
                        <p class="text-white text-sm font-medium flex-1 truncate">{{player.name}}</p>
                        <div class="w-6 h-6 rounded-full border-2 flex-shrink-0 flex items-center justify-center transition-colors
                          {{if (this.isUmpireSelected player.id)
                            'border-cyan-400 bg-cyan-400'
                            'border-gray-500'}}">
                          {{#if (this.isUmpireSelected player.id)}}
                            <svg class="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" />
                            </svg>
                          {{/if}}
                        </div>
                      </div>
                    {{/each}}
                  </div>
                {{/if}}

              {{else}}
                <p class="text-gray-400 text-sm text-center py-10">No umpires found.</p>
              {{/if}}

            {{! ── Scorer Source Select Step ── }}
            {{else if (eq this.step "scorer-source-select")}}
              <div class="p-5 flex flex-col gap-3">
                {{#if this.isScorerLoading}}
                  <div class="flex justify-center py-8">
                    <div class="w-6 h-6 border-2 border-slate-600 border-t-cyan-400 rounded-full animate-spin"></div>
                  </div>
                {{else}}
                  <button type="button" class="w-full py-4 px-5 rounded-2xl bg-slate-700 hover:bg-slate-600 text-white font-semibold text-sm text-center transition-colors" {{on "click" (fn this.selectScorerSource "team")}}>
                    Select From<br>Batting &amp; Bowling Team
                  </button>
                  <button type="button" class="w-full py-4 px-5 rounded-2xl bg-slate-700 hover:bg-slate-600 text-white font-semibold text-sm text-center transition-colors" {{on "click" (fn this.selectScorerSource "list")}}>
                    Select From Scorer List
                  </button>
                {{/if}}
              </div>

            {{! ── Scorer Pick Step ── }}
            {{else if (eq this.step "scorer-pick")}}
              {{#if this.isScorerLoading}}
                <div class="flex justify-center py-10">
                  <div class="w-6 h-6 border-2 border-slate-600 border-t-cyan-400 rounded-full animate-spin"></div>
                </div>
              {{else if this.scorerPlayers.length}}
                <p class="text-xs text-gray-400 text-center pt-3 pb-1">
                  Select scorers — mark one as <span class="text-yellow-400 font-semibold">Active (A)</span>
                </p>

                {{#if (eq this.scorerSource "team")}}
                  {{! Side-by-side team columns }}
                  <div class="grid grid-cols-2 divide-x divide-slate-700/50">
                    <div class="flex flex-col">
                      <p class="text-[10px] font-semibold text-cyan-400 text-center py-2 border-b border-slate-700/50 truncate px-2">{{this.battingTeam.name}}</p>
                      {{#each this.scorerPlayers as |player|}}
                        {{#if (eq player.teamSide "batting")}}
                          <button type="button"
                            class="flex flex-col items-center gap-1 px-2 py-2 border-b border-slate-700/30 w-full transition-colors hover:bg-slate-700/40
                              {{if (this.isScorerSelected player.id) 'bg-cyan-900/20'}}"
                            {{on "click" (fn this.toggleScorer player.id)}}
                          >
                            <div class="w-10 h-10 rounded-xl overflow-hidden bg-slate-700 flex items-center justify-center flex-shrink-0">
                              {{#if player.avatar}}
                                <img src={{player.avatar}} alt={{player.name}} class="w-full h-full object-cover" />
                              {{else}}
                                <span class="text-white font-bold text-sm">{{initial player.name}}</span>
                              {{/if}}
                            </div>
                            <p class="text-white text-[10px] font-medium text-center line-clamp-1 w-full">{{player.name}}</p>
                            {{#if (this.isScorerSelected player.id)}}
                              <button type="button"
                                class="w-6 h-6 rounded-full text-[9px] font-bold transition-colors
                                  {{if (this.isActiveScorer player.id) 'bg-yellow-400 text-slate-900' 'bg-slate-700 text-gray-400 hover:bg-yellow-400 hover:text-slate-900'}}"
                                {{on "click" (fn this.setActiveScorer player.id)}}>A</button>
                            {{/if}}
                          </button>
                        {{/if}}
                      {{/each}}
                    </div>
                    <div class="flex flex-col">
                      <p class="text-[10px] font-semibold text-orange-400 text-center py-2 border-b border-slate-700/50 truncate px-2">{{this.bowlingTeam.name}}</p>
                      {{#each this.scorerPlayers as |player|}}
                        {{#if (eq player.teamSide "bowling")}}
                          <button type="button"
                            class="flex flex-col items-center gap-1 px-2 py-2 border-b border-slate-700/30 w-full transition-colors hover:bg-slate-700/40
                              {{if (this.isScorerSelected player.id) 'bg-cyan-900/20'}}"
                            {{on "click" (fn this.toggleScorer player.id)}}
                          >
                            <div class="w-10 h-10 rounded-xl overflow-hidden bg-slate-700 flex items-center justify-center flex-shrink-0">
                              {{#if player.avatar}}
                                <img src={{player.avatar}} alt={{player.name}} class="w-full h-full object-cover" />
                              {{else}}
                                <span class="text-white font-bold text-sm">{{initial player.name}}</span>
                              {{/if}}
                            </div>
                            <p class="text-white text-[10px] font-medium text-center line-clamp-1 w-full">{{player.name}}</p>
                            {{#if (this.isScorerSelected player.id)}}
                              <button type="button"
                                class="w-6 h-6 rounded-full text-[9px] font-bold transition-colors
                                  {{if (this.isActiveScorer player.id) 'bg-yellow-400 text-slate-900' 'bg-slate-700 text-gray-400 hover:bg-yellow-400 hover:text-slate-900'}}"
                                {{on "click" (fn this.setActiveScorer player.id)}}>A</button>
                            {{/if}}
                          </button>
                        {{/if}}
                      {{/each}}
                    </div>
                  </div>

                {{else}}
                  {{! Single list from scorer list }}
                  <div class="divide-y divide-slate-700/50">
                    {{#each this.scorerPlayers as |player|}}
                      <button
                        type="button"
                        class="w-full flex items-center gap-3 px-4 py-3 text-left transition-colors hover:bg-slate-700/40
                          {{if (this.isScorerSelected player.id) 'bg-cyan-900/20'}}"
                        {{on "click" (fn this.toggleScorer player.id)}}
                      >
                        <div class="w-10 h-10 rounded-xl flex-shrink-0 overflow-hidden bg-slate-700 flex items-center justify-center">
                          {{#if player.avatar}}
                            <img src={{player.avatar}} alt={{player.name}} class="w-full h-full object-cover" />
                          {{else}}
                            <span class="text-white font-bold text-sm">{{initial player.name}}</span>
                          {{/if}}
                        </div>
                        <p class="text-white text-sm font-medium flex-1 truncate">{{player.name}}</p>
                        {{! Active badge — only shown when selected }}
                        {{#if (this.isScorerSelected player.id)}}
                          <button type="button"
                            class="w-7 h-7 rounded-full text-[10px] font-bold transition-colors flex-shrink-0
                              {{if (this.isActiveScorer player.id) 'bg-yellow-400 text-slate-900' 'bg-slate-700 text-gray-400 hover:bg-yellow-400 hover:text-slate-900'}}"
                            {{on "click" (fn this.setActiveScorer player.id)}}>A</button>
                        {{/if}}
                        {{! Select indicator }}
                        <div class="w-6 h-6 rounded-full border-2 flex-shrink-0 flex items-center justify-center transition-colors
                          {{if (this.isScorerSelected player.id)
                            'border-cyan-400 bg-cyan-400'
                            'border-gray-500'}}">
                          {{#if (this.isScorerSelected player.id)}}
                            <svg class="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" />
                            </svg>
                          {{/if}}
                        </div>
                      </button>
                    {{/each}}
                  </div>
                {{/if}}

              {{else}}
                <p class="text-gray-400 text-sm text-center py-10">No scorers found.</p>
              {{/if}}

            {{! ── Streamer Source Select Step ── }}
            {{else if (eq this.step "streamer-source-select")}}
              <div class="p-5 flex flex-col gap-3">
                {{#if this.isStreamerLoading}}
                  <div class="flex justify-center py-8">
                    <div class="w-6 h-6 border-2 border-slate-600 border-t-cyan-400 rounded-full animate-spin"></div>
                  </div>
                {{else}}
                  <button type="button" class="w-full py-4 px-5 rounded-2xl bg-slate-700 hover:bg-slate-600 text-white font-semibold text-sm text-center transition-colors" {{on "click" (fn this.selectStreamerSource "team")}}>
                    Select From<br>Batting &amp; Bowling Team
                  </button>
                  <button type="button" class="w-full py-4 px-5 rounded-2xl bg-slate-700 hover:bg-slate-600 text-white font-semibold text-sm text-center transition-colors" {{on "click" (fn this.selectStreamerSource "list")}}>
                    Select From Streamer List
                  </button>
                {{/if}}
              </div>

            {{! ── Streamer Pick Step ── }}
            {{else if (eq this.step "streamer-pick")}}
              {{#if this.isStreamerLoading}}
                <div class="flex justify-center py-10">
                  <div class="w-6 h-6 border-2 border-slate-600 border-t-cyan-400 rounded-full animate-spin"></div>
                </div>
              {{else if this.streamerPlayers.length}}
                <p class="text-xs text-gray-400 text-center pt-3 pb-1">
                  Select streamers — mark one as <span class="text-yellow-400 font-semibold">Active (A)</span>
                </p>

                {{#if (eq this.streamerSource "team")}}
                  {{! Side-by-side team columns }}
                  <div class="grid grid-cols-2 divide-x divide-slate-700/50">
                    <div class="flex flex-col">
                      <p class="text-[10px] font-semibold text-cyan-400 text-center py-2 border-b border-slate-700/50 truncate px-2">{{this.battingTeam.name}}</p>
                      {{#each this.streamerPlayers as |player|}}
                        {{#if (eq player.teamSide "batting")}}
                          <button type="button"
                            class="flex flex-col items-center gap-1 px-2 py-2 border-b border-slate-700/30 w-full transition-colors hover:bg-slate-700/40
                              {{if (this.isStreamerSelected player.id) 'bg-cyan-900/20'}}"
                            {{on "click" (fn this.toggleStreamer player.id)}}
                          >
                            <div class="w-10 h-10 rounded-xl overflow-hidden bg-slate-700 flex items-center justify-center flex-shrink-0">
                              {{#if player.avatar}}
                                <img src={{player.avatar}} alt={{player.name}} class="w-full h-full object-cover" />
                              {{else}}
                                <span class="text-white font-bold text-sm">{{initial player.name}}</span>
                              {{/if}}
                            </div>
                            <p class="text-white text-[10px] font-medium text-center line-clamp-1 w-full">{{player.name}}</p>
                            {{#if (this.isStreamerSelected player.id)}}
                              <button type="button"
                                class="w-6 h-6 rounded-full text-[9px] font-bold transition-colors
                                  {{if (this.isActiveStreamer player.id) 'bg-yellow-400 text-slate-900' 'bg-slate-700 text-gray-400 hover:bg-yellow-400 hover:text-slate-900'}}"
                                {{on "click" (fn this.setActiveStreamer player.id)}}>A</button>
                            {{/if}}
                          </button>
                        {{/if}}
                      {{/each}}
                    </div>
                    <div class="flex flex-col">
                      <p class="text-[10px] font-semibold text-orange-400 text-center py-2 border-b border-slate-700/50 truncate px-2">{{this.bowlingTeam.name}}</p>
                      {{#each this.streamerPlayers as |player|}}
                        {{#if (eq player.teamSide "bowling")}}
                          <button type="button"
                            class="flex flex-col items-center gap-1 px-2 py-2 border-b border-slate-700/30 w-full transition-colors hover:bg-slate-700/40
                              {{if (this.isStreamerSelected player.id) 'bg-cyan-900/20'}}"
                            {{on "click" (fn this.toggleStreamer player.id)}}
                          >
                            <div class="w-10 h-10 rounded-xl overflow-hidden bg-slate-700 flex items-center justify-center flex-shrink-0">
                              {{#if player.avatar}}
                                <img src={{player.avatar}} alt={{player.name}} class="w-full h-full object-cover" />
                              {{else}}
                                <span class="text-white font-bold text-sm">{{initial player.name}}</span>
                              {{/if}}
                            </div>
                            <p class="text-white text-[10px] font-medium text-center line-clamp-1 w-full">{{player.name}}</p>
                            {{#if (this.isStreamerSelected player.id)}}
                              <button type="button"
                                class="w-6 h-6 rounded-full text-[9px] font-bold transition-colors
                                  {{if (this.isActiveStreamer player.id) 'bg-yellow-400 text-slate-900' 'bg-slate-700 text-gray-400 hover:bg-yellow-400 hover:text-slate-900'}}"
                                {{on "click" (fn this.setActiveStreamer player.id)}}>A</button>
                            {{/if}}
                          </button>
                        {{/if}}
                      {{/each}}
                    </div>
                  </div>

                {{else}}
                  {{! Single list from streamer list }}
                  <div class="divide-y divide-slate-700/50">
                    {{#each this.streamerPlayers as |player|}}
                      <button
                        type="button"
                        class="w-full flex items-center gap-3 px-4 py-3 text-left transition-colors hover:bg-slate-700/40
                          {{if (this.isStreamerSelected player.id) 'bg-cyan-900/20'}}"
                        {{on "click" (fn this.toggleStreamer player.id)}}
                      >
                        <div class="w-10 h-10 rounded-xl flex-shrink-0 overflow-hidden bg-slate-700 flex items-center justify-center">
                          {{#if player.avatar}}
                            <img src={{player.avatar}} alt={{player.name}} class="w-full h-full object-cover" />
                          {{else}}
                            <span class="text-white font-bold text-sm">{{initial player.name}}</span>
                          {{/if}}
                        </div>
                        <p class="text-white text-sm font-medium flex-1 truncate">{{player.name}}</p>
                        {{#if (this.isStreamerSelected player.id)}}
                          <button type="button"
                            class="w-7 h-7 rounded-full text-[10px] font-bold transition-colors flex-shrink-0
                              {{if (this.isActiveStreamer player.id) 'bg-yellow-400 text-slate-900' 'bg-slate-700 text-gray-400 hover:bg-yellow-400 hover:text-slate-900'}}"
                            {{on "click" (fn this.setActiveStreamer player.id)}}>A</button>
                        {{/if}}
                        <div class="w-6 h-6 rounded-full border-2 flex-shrink-0 flex items-center justify-center transition-colors
                          {{if (this.isStreamerSelected player.id)
                            'border-cyan-400 bg-cyan-400'
                            'border-gray-500'}}">
                          {{#if (this.isStreamerSelected player.id)}}
                            <svg class="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" />
                            </svg>
                          {{/if}}
                        </div>
                      </button>
                    {{/each}}
                  </div>
                {{/if}}

              {{else}}
                <p class="text-gray-400 text-sm text-center py-10">No streamers found.</p>
              {{/if}}

            {{! ── Player Select Step ── }}
            {{else}}
              <div class="divide-y divide-slate-700/50">
                {{#each this.players as |player|}}
                  <div
                    role="button"
                    tabindex={{if player.pending "-1" "0"}}
                    class="flex items-center gap-3 px-4 py-3 transition-colors
                      {{if player.pending
                        'opacity-50 cursor-not-allowed'
                        (if (this.isPlayerBlocked player.id)
                          'opacity-40 cursor-not-allowed'
                          'cursor-pointer hover:bg-slate-700/40 active:bg-slate-700/60')}}"
                    {{on "click" (fn this.togglePlayer player)}}
                  >

                    {{! Avatar }}
                    <div class="w-10 h-10 rounded-xl flex-shrink-0 overflow-hidden bg-slate-700 flex items-center justify-center">
                      {{#if player.avatar}}
                        <img src={{player.avatar}} alt={{player.name}} class="w-full h-full object-cover" />
                      {{else}}
                        <span class="text-white font-bold text-sm">{{initial player.name}}</span>
                      {{/if}}
                    </div>

                    {{! Name + badges }}
                    <div class="flex-1 min-w-0">
                      <p class="text-white text-sm font-medium truncate">{{player.name}}</p>
                      <div class="flex items-center gap-1 mt-0.5">
                        {{#if player.pending}}
                          <span class="text-[9px] font-semibold px-1.5 py-0.5 rounded bg-orange-500/20 text-orange-400">Pending</span>
                        {{/if}}
                        {{#if player.isLeftHanded}}
                          <span class="text-[9px] font-semibold px-1.5 py-0.5 rounded bg-blue-500/20 text-blue-400">LH</span>
                        {{/if}}
                        {{#if player.isWicketKeeper}}
                          <span class="text-[9px] font-semibold px-1.5 py-0.5 rounded bg-emerald-500/20 text-emerald-400">WK</span>
                        {{/if}}
                        {{#if player.is12thMan}}
                          <span class="text-[9px] font-semibold px-1.5 py-0.5 rounded bg-yellow-500/20 text-yellow-400">Sub</span>
                        {{/if}}
                      </div>
                    </div>

                    {{#unless player.pending}}
                      {{! Captain button }}
                      <button
                        type="button"
                        class="w-7 h-7 rounded-full text-[10px] font-bold transition-colors flex-shrink-0
                          {{if (this.isCaptain player.id)
                            'bg-yellow-400 text-slate-900'
                            'bg-slate-700 text-gray-400 hover:bg-slate-600 hover:text-white'}}"
                        {{on "click" (fn this.setCaptain player)}}
                      >C</button>

                      {{! Vice-captain button }}
                      <button
                        type="button"
                        class="w-7 h-7 rounded-full text-[10px] font-bold transition-colors flex-shrink-0
                          {{if (this.isViceCaptain player.id)
                            'bg-cyan-400 text-slate-900'
                            'bg-slate-700 text-gray-400 hover:bg-slate-600 hover:text-white'}}"
                        {{on "click" (fn this.setViceCaptain player)}}
                      >VC</button>

                      {{! Wicket-keeper button }}
                      <button
                        type="button"
                        class="w-7 h-7 rounded-full text-[10px] font-bold transition-colors flex-shrink-0
                          {{if (this.isWicketKeeper player.id)
                            'bg-emerald-400 text-slate-900'
                            'bg-slate-700 text-gray-400 hover:bg-slate-600 hover:text-white'}}"
                        {{on "click" (fn this.setWicketKeeper player)}}
                      >WK</button>

                      {{! Select indicator }}
                      <div
                        class="w-6 h-6 rounded-full border-2 flex-shrink-0 flex items-center justify-center transition-colors
                          {{if (this.isPlayerSelected player.id)
                            'border-cyan-400 bg-cyan-400'
                            'border-gray-500'}}"
                      >
                        {{#if (this.isPlayerSelected player.id)}}
                          <svg class="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" />
                          </svg>
                        {{/if}}
                      </div>
                    {{/unless}}

                  </div>
                {{/each}}
              </div>
            {{/if}}

          </div>

          {{! Footer — streamer-pick step }}
          {{#if (eq this.step "streamer-pick")}}
            <div class="px-5 py-4 border-t border-slate-700/50 flex items-center justify-between flex-shrink-0">
              <div class="flex flex-col text-xs text-gray-400 gap-0.5">
                <span><span class="text-white font-semibold">{{this.selectedStreamerIds.size}}</span> streamer selected <span class="text-gray-600">(optional)</span></span>
                {{#if this.activeStreamerId}}
                  <span class="text-yellow-400 font-semibold">Active ✓</span>
                {{/if}}
              </div>
              <button
                type="button"
                class="px-5 py-2 rounded-xl text-sm font-semibold transition-colors bg-cyan-600 hover:bg-cyan-500 text-white"
                {{on "click" this.streamerNext}}
              >Done</button>
            </div>

          {{! Footer — scorer-pick step }}
          {{else if (eq this.step "scorer-pick")}}

            <div class="px-5 py-4 border-t border-slate-700/50 flex items-center justify-between flex-shrink-0">
              <div class="flex flex-col text-xs text-gray-400 gap-0.5">
                <span><span class="text-white font-semibold">{{this.selectedScorerIds.size}}</span> scorer selected</span>
                {{#if this.activeScorerId}}
                  <span class="text-yellow-400 font-semibold">Active ✓</span>
                {{else}}
                  <span class="text-gray-500">No active scorer set</span>
                {{/if}}
              </div>
              <button
                type="button"
                disabled={{not this.scorerValid}}
                class="px-5 py-2 rounded-xl text-sm font-semibold transition-colors
                  {{if this.scorerValid
                    'bg-cyan-600 hover:bg-cyan-500 text-white'
                    'bg-slate-700 text-gray-500 cursor-not-allowed'}}"
                {{on "click" this.scorerNext}}
              >Next</button>
            </div>

          {{! Footer — umpire-pick step }}
          {{else if (eq this.step "umpire-pick")}}
            <div class="px-5 py-4 border-t border-slate-700/50 flex items-center justify-between flex-shrink-0">
              <span class="text-sm text-gray-400">
                <span class="{{if this.umpireValid 'text-cyan-400' 'text-white'}} font-semibold">
                  {{this.selectedUmpireIds.size}}
                </span> / min 2 selected
              </span>
              <button
                type="button"
                disabled={{not this.umpireValid}}
                class="px-5 py-2 rounded-xl text-sm font-semibold transition-colors
                  {{if this.umpireValid
                    'bg-cyan-600 hover:bg-cyan-500 text-white'
                    'bg-slate-700 text-gray-500 cursor-not-allowed'}}"
                {{on "click" this.umpireNext}}
              >Next</button>
            </div>

          {{! Footer — batsman-select step }}
          {{else if (eq this.step "batsman-select")}}
            <div class="px-5 py-4 border-t border-slate-700/50 flex items-center justify-between flex-shrink-0">
              <div class="flex items-center gap-2 text-sm">
                {{#if this.strikerId}}
                  <span class="text-[10px] font-semibold px-1.5 py-0.5 rounded-full bg-cyan-500/20 text-cyan-400">S ✓</span>
                {{else}}
                  <span class="text-[10px] font-semibold px-1.5 py-0.5 rounded-full bg-slate-700 text-gray-500">S –</span>
                {{/if}}
                {{#if this.nonStrikerId}}
                  <span class="text-[10px] font-semibold px-1.5 py-0.5 rounded-full bg-emerald-500/20 text-emerald-400">NS ✓</span>
                {{else}}
                  <span class="text-[10px] font-semibold px-1.5 py-0.5 rounded-full bg-slate-700 text-gray-500">NS –</span>
                {{/if}}
              </div>
              <button
                type="button"
                disabled={{not this.batsmanValid}}
                class="px-5 py-2 rounded-xl text-sm font-semibold transition-colors
                  {{if this.batsmanValid
                    'bg-cyan-600 hover:bg-cyan-500 text-white'
                    'bg-slate-700 text-gray-500 cursor-not-allowed'}}"
                {{on "click" this.batsmanNext}}
              >Next</button>
            </div>

          {{! Footer — bowler-select step }}
          {{else if (eq this.step "bowler-select")}}
            <div class="px-5 py-4 border-t border-slate-700/50 flex items-center justify-between flex-shrink-0">
              <span class="text-sm text-gray-400">
                {{#if this.bowlerId}}
                  <span class="text-emerald-400 font-semibold">1</span> bowler selected
                {{else}}
                  Select 1 bowler
                {{/if}}
              </span>
              <button
                type="button"
                disabled={{not this.bowlerId}}
                class="px-5 py-2 rounded-xl text-sm font-semibold transition-colors
                  {{if this.bowlerId
                    'bg-cyan-600 hover:bg-cyan-500 text-white'
                    'bg-slate-700 text-gray-500 cursor-not-allowed'}}"
                {{on "click" this.bowlerNext}}
              >Next</button>
            </div>

          {{! Footer — over-limit-select step }}
          {{else if (eq this.step "over-limit-select")}}
            <div class="px-5 py-4 border-t border-slate-700/50 flex items-center justify-between flex-shrink-0">
              <button
                type="button"
                class="px-5 py-2 rounded-xl text-sm font-semibold bg-slate-700 hover:bg-slate-600 text-gray-200 transition-colors"
                {{on "click" this.back}}
              >
                Back
              </button>
              <button
                type="button"
                disabled={{not this.maxBowlerOvers}}
                class="px-5 py-2 rounded-xl text-sm font-semibold transition-colors
                  {{if this.maxBowlerOvers
                    'bg-cyan-600 hover:bg-cyan-500 text-white'
                    'bg-slate-700 text-gray-500 cursor-not-allowed'}}"
                {{on "click" this.overLimitNext}}
              >
                Next
              </button>
            </div>

          {{! Footer — choice-select step }}
          {{else if (eq this.step "choice-select")}}
            <div class="px-5 py-4 border-t border-slate-700/50 flex items-center justify-between flex-shrink-0">
              <button
                type="button"
                class="px-5 py-2 rounded-xl text-sm font-semibold bg-slate-700 hover:bg-slate-600 text-gray-200 transition-colors"
                {{on "click" this.back}}
              >
                Back
              </button>
              <button
                type="button"
                disabled={{not this.battingChoice}}
                class="px-5 py-2 rounded-xl text-sm font-semibold transition-colors
                  {{if this.battingChoice
                    'bg-cyan-600 hover:bg-cyan-500 text-white'
                    'bg-slate-700 text-gray-500 cursor-not-allowed'}}"
                {{on "click" this.choiceNext}}
              >
                Next
              </button>
            </div>

          {{! Footer — toss-select step }}
          {{else if (eq this.step "toss-select")}}
            <div class="px-5 py-4 border-t border-slate-700/50 flex items-center justify-between flex-shrink-0">
              <button
                type="button"
                class="px-5 py-2 rounded-xl text-sm font-semibold bg-slate-700 hover:bg-slate-600 text-gray-200 transition-colors"
                {{on "click" this.back}}
              >
                Back
              </button>
              <button
                type="button"
                disabled={{not this.tossWinnerId}}
                class="px-5 py-2 rounded-xl text-sm font-semibold transition-colors
                  {{if this.tossWinnerId
                    'bg-cyan-600 hover:bg-cyan-500 text-white'
                    'bg-slate-700 text-gray-500 cursor-not-allowed'}}"
                {{on "click" this.tossNext}}
              >
                Next
              </button>
            </div>

          {{! Footer — only on player-select step }}
          {{else if (eq this.step "player-select")}}
            <div class="px-5 pt-3 pb-4 border-t border-slate-700/50 flex-shrink-0">

              {{! Validation hints }}
              {{#unless this.isValid}}
                <div class="flex flex-wrap gap-1.5 mb-3">
                  {{#if (not (this.hasEnoughPlayers))}}
                    <span class="text-[10px] px-2 py-1 rounded-lg bg-red-500/15 text-red-400 font-medium">
                      Min 5 players required ({{this.selectedCount}} selected)
                    </span>
                  {{/if}}
                  {{#if this.tooManyPlayers}}
                    <span class="text-[10px] px-2 py-1 rounded-lg bg-red-500/15 text-red-400 font-medium">
                      Max {{this.requiredPlayersCount}} players allowed ({{this.selectedCount}} selected)
                    </span>
                  {{/if}}
                  {{#unless this.captainId}}
                    <span class="text-[10px] px-2 py-1 rounded-lg bg-yellow-500/15 text-yellow-400 font-medium">
                      Assign a Captain (C)
                    </span>
                  {{/unless}}
                  {{#unless this.viceCaptainId}}
                    <span class="text-[10px] px-2 py-1 rounded-lg bg-cyan-500/15 text-cyan-400 font-medium">
                      Assign a Vice Captain (VC)
                    </span>
                  {{/unless}}
                  {{#unless this.wicketKeeperId}}
                    <span class="text-[10px] px-2 py-1 rounded-lg bg-emerald-500/15 text-emerald-400 font-medium">
                      Assign a Wicket Keeper (WK)
                    </span>
                  {{/unless}}
                  {{#if (this.sameCaptainVc)}}
                    <span class="text-[10px] px-2 py-1 rounded-lg bg-red-500/15 text-red-400 font-medium">
                      C and VC must be different players
                    </span>
                  {{/if}}
                </div>
              {{/unless}}

              <div class="flex items-center justify-between">
                <div class="flex items-center gap-2 text-sm">
                  <span class="text-gray-400">
                    <span class="text-white font-semibold">{{this.selectedCount}}</span>{{#if this.requiredPlayersCount}} / {{this.requiredPlayersCount}}{{/if}} selected
                  </span>
                  {{#if this.captainId}}
                    <span class="text-[10px] font-semibold px-1.5 py-0.5 rounded-full bg-yellow-400/20 text-yellow-400">C ✓</span>
                  {{else}}
                    <span class="text-[10px] font-semibold px-1.5 py-0.5 rounded-full bg-slate-700 text-gray-500">C –</span>
                  {{/if}}
                  {{#if this.viceCaptainId}}
                    <span class="text-[10px] font-semibold px-1.5 py-0.5 rounded-full bg-cyan-400/20 text-cyan-400">VC ✓</span>
                  {{else}}
                    <span class="text-[10px] font-semibold px-1.5 py-0.5 rounded-full bg-slate-700 text-gray-500">VC –</span>
                  {{/if}}
                  {{#if this.wicketKeeperId}}
                    <span class="text-[10px] font-semibold px-1.5 py-0.5 rounded-full bg-emerald-400/20 text-emerald-400">WK ✓</span>
                  {{else}}
                    <span class="text-[10px] font-semibold px-1.5 py-0.5 rounded-full bg-slate-700 text-gray-500">WK –</span>
                  {{/if}}
                </div>
                <button
                  type="button"
                  disabled={{not this.isValid}}
                  class="flex items-center gap-2 px-5 py-2 rounded-xl text-sm font-semibold transition-colors
                    {{if this.isValid
                      'bg-cyan-600 hover:bg-cyan-500 text-white'
                      'bg-slate-700 text-gray-500 cursor-not-allowed'}}"
                  {{on "click" this.handleDone}}
                >
                  {{#if this.isSaving}}
                    <div class="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                    Saving...
                  {{else}}
                    Done
                  {{/if}}
                </button>
              </div>

            </div>
          {{/if}}

        </div>
      </div>
    {{/if}}
  </template>
}

export default SelectStartPlayersModalComponent;
