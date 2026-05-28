import Component from '@glimmer/component';

// ── null/undefined → display value ───────────────────────────────────────────
function v(val) {
  if (val === null || val === undefined) return 0;
  if (typeof val === 'number') return isNaN(val) ? 0 : val;
  return val;
}

// ── Row definitions — API key mapping ────────────────────────────────────────
const ROWS = [
  {
    gameLabel:        'Game Won',
    tournamentLabel:  'Tournament Won',
    gameKey:          'won_games',
    tournamentKey:    'won_tournaments',
  },
  {
    gameLabel:        'Lost Game',
    tournamentLabel:  'Lost Tournament',
    gameKey:          'lost_games',
    tournamentKey:    'lost_tournaments',
  },
  {
    gameLabel:        'Draw Game',
    tournamentLabel:  'Draw Tournament',
    gameKey:          'drawn_games',
    tournamentKey:    'drawn_tournaments',
  },
  {
    gameLabel:        'Game Played',
    tournamentLabel:  'Tournament Played',
    gameKey:          'played_games',
    tournamentKey:    'played_tournaments',
  },
  {
    gameLabel:        'Abondned Game',
    tournamentLabel:  'Abondned Tournament',
    gameKey:          'abandoned_games',
    tournamentKey:    'abandoned_tournaments',
  },
  {
    gameLabel:        'Runs Taken in Game',
    tournamentLabel:  'Runs Taken in Tournament',
    gameKey:          'runs_taken_game',
    tournamentKey:    'runs_taken_tournaments',
  },
  {
    gameLabel:        'Team Average in Game',
    tournamentLabel:  'Team Average in Tournament',
    gameKey:          'teams_avg_games',
    tournamentKey:    'teams_avg_tournaments',
  },
  {
    gameLabel:        'Runs Given in Game',
    tournamentLabel:  'Runs Given in Tournament',
    gameKey:          'runs_given_games',
    tournamentKey:    'runs_given_tournaments',
  },
  {
    gameLabel:        'Ball Faced in Game',
    tournamentLabel:  'Ball Faced in Tournament',
    gameKey:          'balls_faced_games',
    tournamentKey:    'balls_faced_tournaments',
  },
  {
    gameLabel:        'Team Weight in Game',
    tournamentLabel:  'Team Weight in Tournament',
    gameKey:          'team_weight_games',
    tournamentKey:    'team_weight_tournaments',
  },
  {
    gameLabel:        'Balls Bowled in Game',
    tournamentLabel:  'Balls Bowled in Tournament',
    gameKey:          'balls_bowled_games',
    tournamentKey:    'balls_bowled_tournaments',
  },
  {
    gameLabel:        'Teams Rating in Game',
    tournamentLabel:  'Teams Rating in Tournament',
    gameKey:          'teams_rating_games',
    tournamentKey:    'teams_rating_tournaments',
  },
  {
    gameLabel:        'Wicket Lost in Game',
    tournamentLabel:  'Wicket Lost in Tournament',
    gameKey:          'wickets_lost_games',
    tournamentKey:    'wickets_lost_tournaments',
  },
  {
    gameLabel:        'Wickets Taken in Game',
    tournamentLabel:  'Wickets Taken in Tournament',
    gameKey:          'wickets_taken_games',
    tournamentKey:    'wickets_taken_tournaments',
  },
  {
    gameLabel:        'Batting Average in Game',
    tournamentLabel:  'Batting Average in Tournament',
    gameKey:          'batting_average_games',
    tournamentKey:    'batting_average_tournaments',
  },
  {
    gameLabel:        'Bowling Average in Game',
    tournamentLabel:  'Bowling Average in Tournament',
    gameKey:          'bawling_average_games',
    tournamentKey:    'bawling_average_tournaments',
  },
  {
    gameLabel:        'Team Strike Rates in Game',
    tournamentLabel:  'Team Strike Rates in Tournament',
    gameKey:          'teams_strike_rate_games',
    tournamentKey:    'teams_strike_rate_tournaments',
  },
  {
    gameLabel:        'Batting Strike Rates in Game',
    tournamentLabel:  'Batting Strike Rates in Tournament',
    gameKey:          'batting_strike_rate_games',
    tournamentKey:    'batting_strike_rate_tournaments',
  },
  {
    gameLabel:        'Bowling Strike Rates in Games',
    tournamentLabel:  'Bowling Strike Rates in Tournament',
    gameKey:          'bawling_strike_rate_games',
    tournamentKey:    'bawling_strike_rate_tournaments',
  },
];

// ── Component ─────────────────────────────────────────────────────────────────
export default class TournamentTable extends Component {
  get d() {
    return this.args.stats ?? {};
  }

  get strikeRate() {
    return v(this.d.teams_strike_rate);
  }

  get average() {
    return v(this.d.teams_avg);
  }

  get rows() {
    return ROWS.map((row, i) => ({
      ...row,
      gameValue:       v(this.d[row.gameKey]),
      tournamentValue: v(this.d[row.tournamentKey]),
      isEven:          i % 2 === 0,
    }));
  }

  get totalTeamsRating() {
    return v(this.d.total_teams_rating);
  }

  get teamsRatingTournaments() {
    return v(this.d.teams_rating_tournaments);
  }

  <template>
    <div class="rounded-xl overflow-hidden border border-gray-200 dark:border-slate-700 bg-white dark:bg-gray-900">

      {{! ── Header: Strike Rate & Average ── }}
      <div class="flex items-center justify-center gap-1 py-3 border-b border-gray-200 dark:border-slate-700">
        <span class="text-sm font-semibold text-gray-800 dark:text-slate-200">
          Strike Rate:
          <span class="text-gray-900 dark:text-white font-bold">{{this.strikeRate}}</span>
          ,&nbsp;Average:
          <span class="text-gray-900 dark:text-white font-bold">{{this.average}}</span>
        </span>
        {{!-- <svg class="w-4 h-4 text-gray-400 dark:text-slate-500 ml-1 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
            d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
        </svg> --}}
      </div>

      {{! ── Sub-header: Game Rating | Tournament ── }}
      <div class="grid grid-cols-2 border-b border-gray-200 dark:border-slate-700">
        <div class="px-4 py-2 border-r border-gray-200 dark:border-slate-700">
          <span class="text-xs text-gray-500 dark:text-slate-400 font-medium">Game Rating: </span>
          <span class="text-xs font-bold text-gray-800 dark:text-slate-200">{{this.totalTeamsRating}}</span>
        </div>
        <div class="px-4 py-2">
          <span class="text-xs text-gray-500 dark:text-slate-400 font-medium">Tournament: </span>
          <span class="text-xs font-bold text-gray-800 dark:text-slate-200">{{this.teamsRatingTournaments}}</span>
        </div>
      </div>

      {{! ── Stat Rows ── }}
      {{#each this.rows as |row|}}
        <div class="grid grid-cols-2 border-b border-gray-100 dark:border-slate-800
          {{if row.isEven 'bg-white dark:bg-gray-900' 'bg-gray-50 dark:bg-slate-800/40'}}">

          <div class="flex items-center justify-between px-4 py-2.5 border-r border-gray-100 dark:border-slate-800">
            <span class="text-xs text-gray-600 dark:text-slate-400">{{row.gameLabel}}</span>
            <span class="text-xs font-semibold text-gray-900 dark:text-slate-100 ml-2 shrink-0">{{row.gameValue}}</span>
          </div>

          <div class="flex items-center justify-between px-4 py-2.5">
            <span class="text-xs text-gray-600 dark:text-slate-400">{{row.tournamentLabel}}</span>
            <span class="text-xs font-semibold text-gray-900 dark:text-slate-100 ml-2 shrink-0">{{row.tournamentValue}}</span>
          </div>

        </div>
      {{/each}}

    </div>
  </template>
}
