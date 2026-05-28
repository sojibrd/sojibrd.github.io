import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { service } from '@ember/service';

const EMPTY_CRICKET = {
  profileName: '',
  nickName: '',
  skills: '',
  matchFee: '',
  tournamentFee: '',
  highlights: '',
  goal: '',
  batting: {
    overall: {},
    game: {},
    tournament: {},
  },
  bowling: {
    overall: {},
    game: {},
    tournament: {},
  },
  fielding: {
    overall: {},
    game: {},
    tournament: {},
  },
  overallStat: {},
  gallery: [],
};

export default class PlayerDetails extends Component {
  @service store;
  @service api;
  @service router;
  @service toast;

  @tracked player;
  @tracked cricket;
  @tracked batting_history;
  @tracked bowling_history;
  @tracked fielding_history;
  @tracked overall_history;
  @tracked gallery_images;
  @tracked isLoading;
  // @tracked activeStatsLoadingTab = null;
  @tracked showEmailModal = false;
  @tracked emailTo = '';
  @tracked emailName = '';
  @tracked emailMessage = '';
  @tracked showMessageToast = false;

  constructor() {
    super(...arguments);
    this.cricket = null;
    this.bowling_history = this.normalizeBowling();
    this.fielding_history = this.normalizeFielding();
    this.overall_history = this.normalizeOverallStat();
    this.gallery_images = [];
    this.batting_history = this.normalizeBattingHistory();
    this.loadProfile(this.args.username);
  }

  // https://spordiumapi.adnanfoundation.com/auth_user/get_playing_sports/cricket/BD__0204095528554914/
  // https://spordiumapi.adnanfoundation.com/auth_user/get_player_batting_history/BD__0204095528554914/


  async loadProfile(userId) {
    this.isLoading = true;
    try {
      const data = await this.store.queryRecord('user-profile', { user_name: userId });
      this.player = data;
      console.log(">>PLAYER:::>>",this.player);
      if (data?.user_username && data.user_username !== userId) {
        this.router.replaceWith('player', data.user_username);
      }
    } catch (e) {
      this.error = e;
    } finally {
      this.isLoading = false;
    }
  }

  // Main tabs: General / Cricket
  @tracked activeMainTab = 'general';

  // Cricket inner tabs
  @tracked activeStatsTab = 'batting';

  // Main tab switch
  @action
  async switchMainTab(tab) {
    this.activeMainTab = tab;
    if (tab === 'cricket') {
      this.isLoading = true;
      try {
        const cricket = await this.api.get(`/auth_user/get_playing_sports/cricket/${this.player.userid}`);
        const batting_history = await this.api.get(`/auth_user/get_player_batting_history/${this.player.userid}`);

        this.cricket = cricket.data || {};
        this.batting_history = this.normalizeBattingHistory(batting_history?.data ?? batting_history);
        console.log('cricket', this.cricket);
        console.log('batting_history', this.batting_history);
        this.isLoading = false;
      } catch (error) {
        console.error('Error fetching trending matches:', error);
        this.isLoading = false;
      } finally {
        this.isLoading = false;
      }
    }
  }

  // /auth_user/get_player_bowling_history/BD__0204095528554914/
  // /auth_user/get_player_filding_history/BD__0204095528554914/
  // /auth_user/get_player_overall_history/BD__0204095528554914/
  // /auth_user/get_image/cricket/BD__0204095528554914/


  // Stats tab switch (Cricket inner)
  @action
  async switchStatsTab(tab) {
    this.activeStatsTab = tab;
    if (!this.player?.userid) return;

    // if (tab === 'bowling' || tab === 'fielding' || tab === 'overall' || tab === 'gallery') {
    //   this.activeStatsLoadingTab = tab;
    // }

    try {
      if (tab === 'bowling') {
        const result = await this.api.get(`/auth_user/get_player_bowling_history/${this.player.userid}/`);
        this.bowling_history = this.normalizeBowling(result?.data ?? result);
      } else if (tab === 'fielding') {
        const result = await this.api.get(`/auth_user/get_player_filding_history/${this.player.userid}/`);
        this.fielding_history = this.normalizeFielding(result?.data ?? result);
      } else if (tab === 'overall') {
        const result = await this.api.get(`/auth_user/get_player_overall_history/${this.player.userid}/`);
        this.overall_history = this.normalizeOverallStat(result?.data ?? result);
      } else if (tab === 'gallery') {
        const result = await this.api.get(`/auth_user/get_image/cricket/${this.player.userid}/`);
        this.gallery_images = this.normalizeGallery(result?.data ?? result);
      }
    } catch (error) {
      console.error(`Error fetching ${tab} stats:`, error);
    } finally {
      // if (tab === 'bowling' || tab === 'fielding' || tab === 'overall' || tab === 'gallery') {
      //   this.activeStatsLoadingTab = null;
      // }
    }
  }

  // Copy profile link
  @action
  copyProfileLink(link) {
    navigator.clipboard.writeText(`https://spordium.com/${link}`);
    this.toast.success('Copied to clipboard!');
  }

  @action
  openEmailModal() {
    this.showEmailModal = true;
  }

  @action
  closeEmailModal() {
    this.showEmailModal = false;
  }

  @action
  sendEmail() {
    // TODO: wire to API
    this.showEmailModal = false;
  }

  @action
  showComingSoon() {
    this.showMessageToast = true;
    setTimeout(() => {
      this.showMessageToast = false;
    }, 2000);
  }

  get aboutInfo() {
    const raw = this.player?.user_life_history;
    if (!raw) return null;
    if (typeof raw === 'string') return { bio: raw, jobs: [], school: null, schoolStart: null };

    const jobs = (Array.isArray(raw.job) ? raw.job : raw.job ? [raw.job] : [])
      .map((j) => ({
        title: j.title ?? j.job_title ?? j.position ?? j.role ?? '',
        company: j.company ?? j.company_name ?? j.organization ?? '',
        startAt: j.start_at ?? j['start-at'] ?? j.started_at ?? j.from ?? '',
        endAt: j.end_at ?? j['end-at'] ?? j.ended_at ?? j.to ?? '',
      }))
      .filter((j) => j.title || j.company);

    return {
      bio: raw.bio ?? raw.description ?? raw.about ?? null,
      school: raw.school_name ?? raw.school ?? null,
      schoolStart: raw['school-start-at'] ?? raw.school_start_at ?? null,
      jobs,
    };
  }

  get hasAbout() {
    const info = this.aboutInfo;
    if (!info) return false;
    return !!(info.bio || info.school || info.jobs.length);
  }

  get fullName() {
    const fn = this.player?.user_fullname;
    if (!fn) return this.player?.user_username || 'N/A';
    const parts = [fn.first_name, fn.last_name].filter(Boolean);
    return parts.length ? parts.join(' ') : (this.player?.user_username || 'N/A');
  }

  get playerAge() {
    const dob = this.player?.user_dob;
    if (!dob) return 'N/A';
    // API returns "MM-YYYY" format
    const parts = dob.split('-');
    const birthMonth = parseInt(parts[0], 10);
    const birthYear = parseInt(parts[parts.length - 1], 10);
    if (isNaN(birthYear)) return 'N/A';
    const now = new Date();
    let age = now.getFullYear() - birthYear;
    if (!isNaN(birthMonth) && now.getMonth() + 1 < birthMonth) age -= 1;
    return String(age);
  }

  get countryFlag() {
    const code = this.player?.country_code;
    if (!code || code.length !== 2) return '';
    return [...code.toUpperCase()].map(c => String.fromCodePoint(0x1F1E6 + c.charCodeAt(0) - 65)).join('');
  }

  get playerHeight() {
    const cfg = this.player?.user_configuration;
    if (!cfg?.height) return 'N/A';
    return `${cfg.height} ${cfg.height_unit || ''}`.trim();
  }

  get playerWeight() {
    const cfg = this.player?.user_configuration;
    if (!cfg?.weight) return 'N/A';
    return `${cfg.weight} ${cfg.weight_unit || ''}`.trim();
  }

  get playerInitials() {
    const fn = this.player?.user_fullname;
    if (fn?.first_name) {
      return ((fn.first_name[0] || '') + (fn.last_name?.[0] || '')).toUpperCase();
    }
    return (this.player?.user_username?.[0] || '?').toUpperCase();
  }

  get defaultCricketAvatar() {
    return '/assets/avatar/cricket_player.png';
  }

  get defaultAvatar() {
    const gender = (this.player?.user_sex ?? this.player?.user_gender ?? '').toLowerCase();
    const isFemale = gender === 'female' || gender === 'f';
    const seed = (this.player?.user_username ?? '').charCodeAt(0) || 0;
    if (isFemale) {
      return ['/assets/avatar/girl (1).webp', '/assets/avatar/girl (2).webp'][seed % 2];
    }
    return ['/assets/avatar/boy (1).webp', '/assets/avatar/boy (2).webp', '/assets/avatar/boy (3).webp'][seed % 3];
  }

  // Helpers: is active?
  get sportsWithIcons() {
    const sports = this.player?.user_interested_sports?.all_sports ?? [];
    const iconMap = {
      cricket: '/assets/register_modal/icon_cricketball.svg',
      football: '/assets/register_modal/icon_football.svg',
      baseball: '/assets/register_modal/icon_baseball.svg',
    };
    return sports.map((sport) => ({
      name: sport,
      icon: iconMap[sport.toLowerCase()] ?? null,
    }));
  }

  get isGeneral() { return this.activeMainTab === 'general'; }
  get isCricket() { return this.activeMainTab === 'cricket'; }

  get isBatting() { return this.activeStatsTab === 'batting'; }
  get isBowling() { return this.activeStatsTab === 'bowling'; }
  get isFielding() { return this.activeStatsTab === 'fielding'; }
  get isOverall() { return this.activeStatsTab === 'overall'; }
  get isGallery() { return this.activeStatsTab === 'gallery'; }

  // get isStatsLoading() {
  //   return this.activeStatsLoadingTab === this.activeStatsTab;
  // }

  get cricketPrimaryPic() {
    const pic = this.cricket?.player_primary_pic;
    if (!pic) return null;
    if (pic.startsWith('http://') || pic.startsWith('https://')) return pic;
    const host = this.api?.bucket_Images_Host || '';
    if (!host) return null;
    return `${host.replace(/\/$/, '')}/${pic.replace(/^\//, '')}`;
  }

  @action
  onCricketImgError(event) {
    event.target.onerror = null;
    event.target.src = this.defaultCricketAvatar;
  }

  findCricketSport(userPlayingSports) {
    if (Array.isArray(userPlayingSports)) {
      return userPlayingSports.find((sport) => {
        const name = sport?.sportsballtype
          ?? sport?.sports_name
          ?? sport?.sport_name
          ?? sport?.sport?.name
          ?? sport?.name
          ?? sport?.type
          ?? sport?.sports;

        return typeof name === 'string' && name.toLowerCase() === 'cricket';
      });
    }

    if (userPlayingSports && typeof userPlayingSports === 'object') {
      return userPlayingSports.Cricket || userPlayingSports.cricket || userPlayingSports.CRICKET;
    }

    return null;
  }

  normalizeCricket(raw) {
    if (!raw) return EMPTY_CRICKET;

    return {
      ...EMPTY_CRICKET,
      ...raw,
      profileName: raw.profileName
        ?? raw.profile_name
        ?? raw.sports_profile_name
        ?? raw.sport_profile_name
        ?? raw.player_profile_name
        ?? raw.name
        ?? '',
      nickName: raw.nickName
        ?? raw.nick_name
        ?? raw.sports_nick_name
        ?? raw.sport_nick_name
        ?? raw.player_nick_name
        ?? '',
      skills: raw.skills
        ?? raw.skill
        ?? raw.player_skills
        ?? raw.player_skill
        ?? '',
      matchFee: raw.matchFee ?? raw.match_fee ?? raw.match_fees ?? '',
      tournamentFee: raw.tournamentFee ?? raw.tournament_fee ?? raw.tournament_fees ?? '',
      highlights: raw.highlights
        ?? raw.highlight
        ?? raw.highlights_of_career
        ?? raw.career_highlights
        ?? '',
      goal: raw.goal ?? raw.i_want_to_be ?? raw.iWantToBe ?? raw.wanted_role ?? '',
      batting: this.normalizeBatting(raw.batting ?? raw.batting_stat ?? raw.batting_stats),
      bowling: this.normalizeBowling(raw.bowling ?? raw.bowling_stat ?? raw.bowling_stats),
      fielding: this.normalizeFielding(raw.fielding ?? raw.fielding_stat ?? raw.fielding_stats),
      overallStat: this.normalizeOverallStat(raw.overallStat ?? raw.overall_stat ?? raw.overall_stats),
      gallery: this.normalizeGallery(raw.gallery ?? raw.gallery_images ?? raw.images),
    };
  }

  normalizeBatting(rawBatting = {}) {
    const overall = rawBatting.overall ?? rawBatting.overall_stat ?? {};
    const game = rawBatting.game ?? rawBatting.game_stat ?? {};
    const tournament = rawBatting.tournament ?? rawBatting.tournament_stat ?? {};

    return {
      overall: {
        bestScore: overall.bestScore ?? overall.best_score ?? overall.best ?? '',
        totalRuns: overall.totalRuns ?? overall.total_runs ?? overall.runs ?? '',
        average: overall.average ?? overall.avg ?? overall.batting_avg ?? '',
      },
      game: {
        notOut: game.notOut ?? game.not_out ?? '',
        innings: game.innings ?? game.inning ?? '',
        average: game.average ?? game.avg ?? game.batting_avg ?? '',
      },
      tournament: {
        average: tournament.average ?? tournament.avg ?? tournament.batting_avg ?? '',
        innings: tournament.innings ?? tournament.inning ?? '',
        notOut: tournament.notOut ?? tournament.not_out ?? '',
        ballsFaced: tournament.ballsFaced ?? tournament.balls_faced ?? '',
        runsScored: tournament.runsScored ?? tournament.runs_scored ?? '',
        appearedBatsman: tournament.appearedBatsman ?? tournament.appeared_batsman ?? '',
        strikeRate: tournament.strikeRate ?? tournament.strike_rate ?? '',
        batted: tournament.batted ?? '',
        runs50: tournament.runs50 ?? tournament.runs_50 ?? '',
        runs100: tournament.runs100 ?? tournament.runs_100 ?? '',
        runs150: tournament.runs150 ?? tournament.runs_150 ?? '',
        runs200: tournament.runs200 ?? tournament.runs_200 ?? '',
      },
    };
  }

  normalizeBattingHistory(rawHistory = []) {
    const row = Array.isArray(rawHistory) ? (rawHistory[0] ?? {}) : (rawHistory ?? {});
    const v = (value) => (value === null || value === undefined || value === '' ? 0 : value);

    const stats = {
      gamesBatted: v(row.games_batted ?? row.gamesBatted),
      totalPlayed: v(row.total_played ?? row.totalPlayed),
      tournamentBatted: v(row.tournament_batted ?? row.tournamentBatted),
      runsScored: v(row.runs_scored ?? row.runsScored),
      bestScore: v(row.best_score ?? row.bestScore),
      ballsFaced: v(row.balls_faced ?? row.ballsFaced),
      battingAverage: v(row.batting_average ?? row.battingAverage),
      strikeRate: v(row.batting_strike_rate ?? row.battingStrikeRate),
      notOut: v(row.not_out ?? row.notOut),
      runs50: v(row.runs50 ?? row.runs_50),
      runs100: v(row.runs100 ?? row.runs_100),
      runs150: v(row.runs150 ?? row.runs_150),
      runs200: v(row.runs200 ?? row.runs_200),
      battingRating: v(row.batting_rating ?? row.battingRating),
    };

    return { overall: { ...stats }, game: { ...stats }, tournament: { ...stats } };
  }

  normalizeBowling(rawBowling = {}) {
    const row = Array.isArray(rawBowling) ? (rawBowling[0] ?? {}) : rawBowling;
    const v = (value) => (value === null || value === undefined || value === '' ? 0 : value);

    const stats = {
      totalPlayed: v(row.total_played ?? row.totalPlayed),
      gameBowled: v(row.game_bowled ?? row.gameBowled),
      tournamentBowled: v(row.tournament_bowled ?? row.tournamentBowled),
      totalWicketsTaken: v(row.total_wickets_taken ?? row.totalWicketsTaken),
      ballsBowled: v(row.balls_bowled ?? row.ballsBowled),
      totalRunsGiven: v(row.total_runs_given ?? row.totalRunsGiven),
      bowlingAverage: v(row.bowling_average ?? row.bowlingAverage),
      bowlingStrikeRate: v(row.bowling_strike_rate ?? row.bowlingStrikeRate),
      bowledOut: v(row.bowledout ?? row.bowledOut),
      noBalls: v(row.noball ?? row.noBalls),
      wideBalls: v(row.wideball ?? row.wideBalls),
      lbw: v(row.lbw),
      caughtOut: v(row.caughtout ?? row.caughtOut),
      caughtAndBowled: v(row.caughtandbowled ?? row.caughtAndBowled),
      caughtBehind: v(row.caughtbehind ?? row.caughtBehind),
      hitWicket: v(row.hitwicket ?? row.hitWicket),
      maidenOvers: v(row.maidenover ?? row.maidenOvers),
      stumped: v(row.stumped),
      runOuts: v(row.runout ?? row.runOuts),
      retiredHurt: v(row.retiredhut ?? row.retiredHurt),
      totalBowled: v(row.bowled ?? row.total_bowled ?? row.totalBowled),
      lowestBallSpeed: v(row.lowestballspeed ?? row.lowestBallSpeed),
      averageBallSpeed: v(row.averageballspeed ?? row.averageBallSpeed),
      highestBallSpeed: v(row.highestballspeed ?? row.highestBallSpeed),
    };

    return { overall: { ...stats }, game: { ...stats }, tournament: { ...stats } };
  }

  normalizeFielding(rawFielding = {}) {
    const row = Array.isArray(rawFielding) ? (rawFielding[0] ?? {}) : rawFielding;
    const v = (value) => (value === null || value === undefined || value === '' ? 0 : value);

    const stats = {
      runOut: v(row.run_out ?? row.runOut),
      catchOut: v(row.catch_out ?? row.catchOut),
      catchDropped: v(row.catch_droped ?? row.catchDropped),
    };

    return { overall: { ...stats }, game: { ...stats }, tournament: { ...stats } };
  }

  normalizeOverallStat(rawOverall = {}) {
    const row = Array.isArray(rawOverall) ? (rawOverall[0] ?? {}) : rawOverall;
    const v = (value) => (value === null || value === undefined || value === '' ? 0 : value);

    const stats = {
      totalPlayed: v(row.total_played ?? row.totalPlayed),
      totalBatted: v(row.total_batted ?? row.totalBatted),
      totalBowled: v(row.total_bowled ?? row.totalBowled),
      runsScored: v(row.runs_scored ?? row.runsScored),
      totalWicketsTaken: v(row.total_wickets_taken ?? row.totalWicketsTaken),
      battingAverage: v(row.batting_average ?? row.battingAverage),
      bowlingAverage: v(row.bowling_average ?? row.bowlingAverage),
      battingStrikeRate: v(row.batting_strike_rate ?? row.battingStrikeRate),
      bowlingStrikeRate: v(row.bowling_strike_rate ?? row.bowlingStrikeRate),
      runOut: v(row.run_out ?? row.runOut),
      catchOut: v(row.catch_out ?? row.catchOut),
      manOfTheMatch: v(row.manofthematch ?? row.manOfTheMatch),
      cityRanking: v(row.player_city_ranking ?? row.cityRanking),
      worldRanking: v(row.player_world_ranking ?? row.worldRanking),
      countryRanking: v(row.player_country_ranking ?? row.countryRanking),
    };

    return { overall: { ...stats }, game: { ...stats }, tournament: { ...stats } };
  }

  normalizeGallery(rawGallery) {
    if (!rawGallery) return [];
    const list = Array.isArray(rawGallery) ? rawGallery : [rawGallery];
    const host = this.api?.bucket_Images_Host || '';

    return list.map((item) => {
      if (!item) return item;
      if (typeof item !== 'string') return item;
      if (item.startsWith('http://') || item.startsWith('https://')) return item;
      if (!host) return item;
      return `${host.replace(/\/$/, '')}/${item.replace(/^\//, '')}`;
    });
  }
}
