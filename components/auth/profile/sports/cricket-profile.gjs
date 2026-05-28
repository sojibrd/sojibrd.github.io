import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { eq, or } from 'ember-truth-helpers';
import config from 'spordium/config/environment';
import lucideIcon from 'spordium/helpers/lucide-icon';
import { fmt, humanize, parseRole } from '../sport-meta';

export default class CricketProfileComponent extends Component {
  // @args: profile, sportData, host, isCurrentUser, onOpenPhotoUploader, onOpenEditForm

  @tracked cricketStatsTab = 'batting';

  get cp() { return this.args.sportData?.profile ?? {}; }
  get s()  { return this.args.sportData?.stats ?? {}; }
  get bs() { return this.args.sportData?.bowlingStats ?? {}; }
  get fds(){ return this.args.sportData?.fieldingStats ?? {}; }
  get os() { return this.args.sportData?.overallStats ?? {}; }

  get cricketPic() {
    const cp = this.cp;
    const candidates = [cp.player_primary_pic, cp.player_image];
    for (const raw of candidates) {
      if (raw && !raw.endsWith('//') && raw.trim() !== '') {
        return this.args.host + raw;
      }
    }
    return null;
  }

  get cricketSkills() {
    return (this.cp.skills ?? []).map(humanize);
  }

  get cricketRoles() {
    return (this.cp.user_roles ?? []).map(parseRole);
  }

  get hasBattingData() {
    const s = this.s;
    return s.runs_scored != null || s.games_batted != null;
  }

  get battingTableRows() {
    const s = this.s;
    const d = v => v === '—';
    const pl = (n, word) => n === '1' ? `1 ${word}` : `${n} ${word}s`;

    const makeRow = (format, inn, no, runs, hs, avg, sr, fifties, hundreds, onefifty, twohundred) => {
      const fl = format.toLowerCase();
      return {
        format, inn, no, runs, hs, avg, sr, fifties, hundreds, onefifty, twohundred,
        innTip:        d(inn)        ? `No innings data for ${fl}`                                      : `Batted in ${pl(inn, 'innings')} in ${fl} play`,
        noTip:         d(no)         ? `No not-out data for ${fl}`                                      : `Walked off unbeaten — not dismissed in ${pl(no, 'innings')}`,
        runsTip:       d(runs)       ? `No runs data for ${fl}`                                         : `Scored a total of ${runs} runs in ${fl} play`,
        hsTip:         d(hs)         ? `No score data for ${fl}`                                        : `${format} best: ${hs} runs in a single innings`,
        avgTip:        d(avg)        ? `No batting average for ${fl}`                                   : `Averages ${avg} runs per innings in ${fl} play`,
        srTip:         d(sr)         ? `No strike rate data for ${fl}`                                  : `Scores ${sr} runs per 100 balls faced in ${fl}`,
        fiftiesTip:    d(fifties)    ? `No half-century data for ${fl}`                                 : `Hit ${pl(fifties, 'half-century')} (50–99 runs) in ${fl}`,
        hundredsTip:   d(hundreds)   ? `No century data for ${fl}`                                      : `Hit ${pl(hundreds, 'century')} (100+ runs) in ${fl}`,
        onefiftyTip:   d(onefifty)   ? `150+ scores not tracked for ${fl}`                              : `Crossed 150 runs on ${pl(onefifty, 'occasion')} in ${fl}`,
        twohundredTip: d(twohundred) ? `Double centuries not tracked for ${fl}`                          : `Hit ${pl(twohundred, 'double century')} (200+ runs) in ${fl}`,
      };
    };

    return [
      makeRow('Career',
        fmt(s.games_batted),      fmt(s.not_out, '0'),
        fmt(s.runs_scored),       fmt(s.best_score),
        fmt(s.batting_average),   fmt(s.batting_strike_rate),
        fmt(s.runs50,  '0'),      fmt(s.runs100, '0'),
        fmt(s.runs150, '0'),      fmt(s.runs200, '0'),
      ),
      makeRow('Game',
        fmt(s.game_appeared_batsman),    fmt(s.game_not_out, '0'),
        fmt(s.game_runs_scored),         fmt(s.game_balls_faced),
        fmt(s.game_batting_average),     fmt(s.game_batting_strike_rate),
        fmt(s.game_runs50,  '0'),        fmt(s.game_runs100, '0'),
        '—', '—',
      ),
      makeRow('Tournament',
        fmt(s.tournament_appeared_batsman),    fmt(s.tournament_not_out, '0'),
        fmt(s.tournament_runs_scored),         fmt(s.tournament_balls_faced),
        fmt(s.tournament_batting_average),     fmt(s.tournament_batting_strike_rate),
        fmt(s.tournament_runs50,  '0'),        fmt(s.tournament_runs100, '0'),
        '—', '—',
      ),
    ];
  }

  get hasBowlingData() {
    const b = this.bs;
    return Object.keys(b).length > 0 &&
      (b.total_wickets_taken != null || b.balls_bowled != null || b.total_runs_given != null);
  }

  get bowlingTableRows() {
    const b = this.bs;
    return [
      {
        format:  'Career',
        balls:   fmt(b.balls_bowled),
        wkts:    fmt(b.total_wickets_taken),
        runs:    fmt(b.total_runs_given),
        avg:     fmt(b.bowling_average),
        sr:      fmt(b.bowling_strike_rate),
        maiden:  fmt(b.maidenover, '0'),
        bowled:  fmt(b.bowledout,       '0'),
        caught:  fmt(b.caughtout,       '0'),
        cnb:     fmt(b.caughtandbowled, '0'),
        lbw:     fmt(b.lbw,             '0'),
        stumped: fmt(b.stumped,         '0'),
      },
      {
        format:  'Game',
        balls:   fmt(b.game_balls_bowled),
        wkts:    fmt(b.game_wickets_taken),
        runs:    fmt(b.game_runs_given),
        avg:     fmt(b.game_bowling_average),
        sr:      fmt(b.game_bowling_strike_rate),
        maiden:  '—',
        bowled:  '—',
        caught:  '—',
        cnb:     '—',
        lbw:     '—',
        stumped: '—',
      },
      {
        format:  'Tournament',
        balls:   fmt(b.tournament_balls_bowled),
        wkts:    fmt(b.tournament_wickets_taken),
        runs:    fmt(b.tournament_runs_given),
        avg:     fmt(b.tournament_bowling_average),
        sr:      fmt(b.tournament_bowling_strike_rate),
        maiden:  '—',
        bowled:  '—',
        caught:  '—',
        cnb:     '—',
        lbw:     '—',
        stumped: '—',
      },
    ];
  }

  get hasBallSpeedData() {
    const b = this.bs;
    return b.lowestballspeed != null || b.averageballspeed != null || b.highestballspeed != null;
  }

  get fieldingPositionRows() {
    const fds = this.fds;
    if (!fds || typeof fds !== 'object') return [];
    return Object.keys(fds)
      .filter(k => k !== 'fielding_rating')
      .map(pos => {
        const v = fds[pos] ?? {};
        return {
          position:           pos,
          played:             v.played             ?? '—',
          runout:             v.runout             ?? '—',
          catches:            v.catches            ?? '—',
          runssaved:          v.runssaved          ?? '—',
          directthrough:      v.directthrough      ?? '—',
          spectacularcatch:   v.spectacularcatch   ?? '—',
          spectacularfilding: v.spectacularfilding ?? '—',
        };
      });
  }

  get hasFieldingData() { return this.fieldingPositionRows.length > 0; }

  get hasOverallData() {
    const o = this.os;
    return Object.keys(o).length > 0 &&
      (o.total_played != null || o.player_world_ranking != null || o.player_country_ranking != null);
  }

  get overallTableRows() {
    const o = this.os;
    return [
      {
        format:       'Career',
        played:       fmt(o.total_played, '0'),
        cityRank:     fmt(o.player_city_ranking),
        stateRank:    fmt(o.player_state_ranking),
        countryRank:  fmt(o.player_country_ranking),
        worldRank:    fmt(o.player_world_ranking),
      },
      {
        format:       'Game',
        played:       '—',
        cityRank:     fmt(o.game_player_city_ranking),
        stateRank:    fmt(o.game_player_state_ranking),
        countryRank:  fmt(o.game_player_country_ranking),
        worldRank:    fmt(o.game_player_world_ranking),
      },
      {
        format:       'Tournament',
        played:       '—',
        cityRank:     fmt(o.tournament_player_city_ranking),
        stateRank:    fmt(o.tournament_player_state_ranking),
        countryRank:  fmt(o.tournament_player_country_ranking),
        worldRank:    fmt(o.tournament_player_world_ranking),
      },
    ];
  }

  @action switchCricketStatsTab(tab) { this.cricketStatsTab = tab; }

  <template>
    {{! ── Cricket Hero Header ── }}
    <div class="relative bg-gradient-to-br from-gray-900 via-indigo-950 to-gray-900 overflow-hidden">
      <div class="absolute inset-0 opacity-5" style="background-image: radial-gradient(circle, white 1px, transparent 1px); background-size: 24px 24px;"></div>
      <div class="relative flex flex-col md:flex-row gap-6 px-4 sm:px-6 md:px-10 pt-6 md:pt-7 pb-5">

        <div class="flex flex-col items-center md:items-start gap-2 shrink-0">
          <div class="relative">
            {{#if this.cricketPic}}
              <img
                src={{this.cricketPic}}
                class="h-32 w-32 md:h-36 md:w-36 rounded-2xl object-cover border-2 border-indigo-400/40 shadow-2xl"
                alt="Cricket profile"
              />
            {{else}}
              <img
                src="/assets/avatar/cricket_player.png"
                class="h-32 w-32 md:h-36 md:w-36 rounded-2xl object-cover border-2 border-indigo-400/20 shadow-2xl"
                alt="Default cricket profile"
              />
            {{/if}}
            <div class="absolute -bottom-2.5 left-1/2 -translate-x-1/2 bg-indigo-500 text-white text-[10px] font-black px-3 py-0.5 rounded-full uppercase tracking-widest whitespace-nowrap shadow-lg">
              🏏 Cricketer
            </div>
            {{#if @isCurrentUser}}
              <button
                type="button"
                {{on "click" @onOpenPhotoUploader}}
                class="absolute top-2 right-2 flex items-center justify-center w-7 h-7 rounded-full bg-black/50 hover:bg-black/70 active:scale-95 text-white shadow-md transition-all duration-200"
                aria-label="Change sport profile photo"
              >
                {{lucideIcon "upload" size=13}}
              </button>
            {{/if}}
          </div>
          {{#if this.cp.player_nickname}}
            <div class="text-center md:text-left mt-4">
              <p class="text-[10px] text-indigo-300/70 uppercase tracking-widest font-semibold">Nickname</p>
              <p class="text-2xl font-black text-white tracking-tight">"{{this.cp.player_nickname}}"</p>
            </div>
          {{/if}}
        </div>

        <div class="flex-1 space-y-4 min-w-0">
          <div>
            <h1 class="text-2xl md:text-3xl font-extrabold text-white leading-tight capitalize">
              {{or @profile.user_fullname.first_name "Guest"}}
              {{@profile.user_fullname.last_name}}
            </h1>
            <p class="text-indigo-300 font-semibold text-base mt-0.5">@{{@profile.user_username}}</p>
            {{#if @profile.verify_img_status}}
              <span class="inline-flex items-center gap-1 mt-1.5 bg-green-500/20 border border-green-500/40 text-green-400 text-[10px] font-bold px-2 py-0.5 rounded-full uppercase tracking-wide">
                ✓ Verified
              </span>
            {{/if}}
          </div>
          {{#if this.cricketSkills.length}}
            <div>
              <p class="text-[10px] font-bold uppercase tracking-widest text-indigo-300 mb-2">Playing Style</p>
              <div class="flex flex-wrap gap-2">
                {{#each this.cricketSkills as |skill|}}
                  <span class="px-3 py-1 rounded-full bg-indigo-500/20 border border-indigo-400/30 text-indigo-200 text-xs font-semibold">{{skill}}</span>
                {{/each}}
              </div>
            </div>
          {{/if}}
          <div class="grid grid-cols-2 gap-3">
            <div class="rounded-xl bg-white/5 border border-white/10 p-3 md:p-4">
              <p class="text-[10px] font-bold uppercase tracking-widest text-gray-400 mb-1">Match Fee</p>
              <p class="text-lg font-extrabold text-emerald-400">
                {{#if this.cp.match_fee}}৳{{this.cp.match_fee}}{{else}}—{{/if}}
              </p>
            </div>
            <div class="rounded-xl bg-white/5 border border-white/10 p-3 md:p-4">
              <p class="text-[10px] font-bold uppercase tracking-widest text-gray-400 mb-1">Tournament Fee</p>
              <p class="text-lg font-extrabold text-amber-400">
                {{#if this.cp.tournament_fee}}৳{{this.cp.tournament_fee}}{{else}}—{{/if}}
              </p>
            </div>
          </div>
          {{#if this.cricketRoles.length}}
            <div>
              <p class="text-[10px] font-bold uppercase tracking-widest text-indigo-300 mb-2">Cricket Roles & Rates</p>
              <div class="flex flex-wrap gap-2">
                {{#each this.cricketRoles as |role|}}
                  <div class="flex items-center gap-2 px-3 py-1.5 rounded-xl bg-white/5 border border-white/10">
                    <span class="text-xs font-bold text-white">{{role.name}}</span>
                    <span class="text-xs font-black text-emerald-400">৳{{role.fee}}</span>
                  </div>
                {{/each}}
              </div>
            </div>
          {{/if}}
          {{#if this.cp.player_id}}
            <p class="text-[10px] text-gray-600 font-mono">ID: {{this.cp.player_id}}</p>
          {{/if}}
        </div>
      </div>
    </div>

    {{! ── Cricket Stats Content ── }}
    <div class="px-4 sm:px-6 md:px-10 py-6 sm:py-8">

      {{! Stats tab row }}
      <div class="mb-6 overflow-x-auto no-scrollbar -mx-6 px-6 md:-mx-10 md:px-10 pb-1">
        <div class="flex items-center gap-1 p-1.5 rounded-full bg-gray-900 w-max">
          <button type="button" {{on "click" (fn this.switchCricketStatsTab "batting")}}
            class="flex items-center gap-1.5 px-4 py-1.5 rounded-full text-xs font-black uppercase tracking-wider transition-all duration-200
              {{if (eq this.cricketStatsTab 'batting') 'bg-indigo-600 text-white shadow-md' 'text-gray-500 hover:text-gray-300'}}">
            <span>🏏</span><span>Batting</span>
          </button>
          <button type="button" {{on "click" (fn this.switchCricketStatsTab "bowling")}}
            class="flex items-center gap-1.5 px-4 py-1.5 rounded-full text-xs font-black uppercase tracking-wider transition-all duration-200
              {{if (eq this.cricketStatsTab 'bowling') 'bg-indigo-600 text-white shadow-md' 'text-gray-500 hover:text-gray-300'}}">
            <span>🎳</span><span>Bowling</span>
          </button>
          <button type="button" {{on "click" (fn this.switchCricketStatsTab "fielding")}}
            class="flex items-center gap-1.5 px-4 py-1.5 rounded-full text-xs font-black uppercase tracking-wider transition-all duration-200
              {{if (eq this.cricketStatsTab 'fielding') 'bg-indigo-600 text-white shadow-md' 'text-gray-500 hover:text-gray-300'}}">
            <span>🧤</span><span>Fielding</span>
          </button>
          <button type="button" {{on "click" (fn this.switchCricketStatsTab "overall")}}
            class="flex items-center gap-1.5 px-4 py-1.5 rounded-full text-xs font-black uppercase tracking-wider transition-all duration-200
              {{if (eq this.cricketStatsTab 'overall') 'bg-indigo-600 text-white shadow-md' 'text-gray-500 hover:text-gray-300'}}">
            <span>🏆</span><span>Overall</span>
          </button>
        </div>
      </div>

      {{! ── Batting Panel ── }}
      {{#if (eq this.cricketStatsTab "batting")}}
        <div class="relative panel-enter space-y-4">
          {{#if this.s.batting_rating}}
            <div class="flex items-center gap-2">
              <div class="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-amber-500/10 border border-amber-500/30">
                <span class="text-amber-400 text-xs">★</span>
                <span class="text-xs font-bold text-amber-400">{{this.s.batting_rating}} Batting Rating</span>
              </div>
            </div>
          {{/if}}
          {{#if this.hasBattingData}}
            <div class="overflow-x-auto rounded-2xl border border-indigo-500/25 shadow-2xl shadow-indigo-900/30">
              <div class="flex items-center gap-3 px-5 py-4 border-b border-indigo-500/20 bg-gradient-to-r from-indigo-600/25 via-indigo-600/10 to-transparent">
                <span class="text-base">🏏</span>
                <span class="text-sm font-black text-indigo-100 uppercase tracking-widest">Batting Statistics</span>
                <span class="ml-auto text-[10px] text-indigo-400/60 font-mono">Career · Game · Tournament</span>
              </div>
              <table class="w-full text-sm min-w-[760px] bg-gray-900/70 backdrop-blur-sm">
                <thead>
                  <tr class="border-b-2 border-indigo-500/30 bg-indigo-950/50">
                    <th class="text-left px-5 py-3.5 text-[10px] font-black text-indigo-400 uppercase tracking-widest sticky left-0 bg-indigo-950/90 z-10 min-w-[96px] border-r border-indigo-500/15">Format</th>
                    <th class="px-4 py-3.5 text-[10px] font-black text-gray-500 uppercase tracking-widest text-center">Inn</th>
                    <th class="px-4 py-3.5 text-[10px] font-black text-gray-500 uppercase tracking-widest text-center">NO</th>
                    <th class="px-4 py-3.5 text-[10px] font-black text-indigo-300 uppercase tracking-widest text-center">Runs</th>
                    <th class="px-4 py-3.5 text-[10px] font-black text-amber-400 uppercase tracking-widest text-center">HS</th>
                    <th class="px-4 py-3.5 text-[10px] font-black text-sky-300 uppercase tracking-widest text-center">Avg</th>
                    <th class="px-4 py-3.5 text-[10px] font-black text-emerald-400 uppercase tracking-widest text-center">SR</th>
                    <th class="px-4 py-3.5 text-[10px] font-black text-yellow-400 uppercase tracking-widest text-center">50s</th>
                    <th class="px-4 py-3.5 text-[10px] font-black text-yellow-300 uppercase tracking-widest text-center">100s</th>
                    <th class="px-4 py-3.5 text-[10px] font-black text-yellow-200/60 uppercase tracking-widest text-center">150s</th>
                    <th class="px-4 py-3.5 text-[10px] font-black text-yellow-200/60 uppercase tracking-widest text-center">200s</th>
                  </tr>
                </thead>
                <tbody>
                  {{#each this.battingTableRows as |row|}}
                    <tr class="border-b border-indigo-500/10 hover:bg-indigo-500/8 transition-colors duration-150 last:border-0
                      {{if (eq row.format 'Career') 'bg-indigo-900/15' 'bg-gray-900/20'}}">
                      <td class="sticky left-0 px-5 py-4 border-r border-indigo-500/10 z-10
                        {{if (eq row.format 'Career') 'bg-indigo-900/70' ''}}
                        {{if (eq row.format 'Game') 'bg-sky-950/70' ''}}
                        {{if (eq row.format 'Tournament') 'bg-violet-950/70' ''}}">
                        <span class="flex items-center gap-2">
                          {{#if (eq row.format 'Career')}}
                            <span class="w-1.5 h-5 rounded-full bg-indigo-400 shrink-0"></span>
                            <span class="font-black text-indigo-200 text-xs uppercase tracking-wide">Career</span>
                          {{/if}}
                          {{#if (eq row.format 'Game')}}
                            <span class="w-1.5 h-5 rounded-full bg-sky-400 shrink-0"></span>
                            <span class="font-black text-sky-300 text-xs uppercase tracking-wide">Game</span>
                          {{/if}}
                          {{#if (eq row.format 'Tournament')}}
                            <span class="w-1.5 h-5 rounded-full bg-violet-400 shrink-0"></span>
                            <span class="font-black text-violet-300 text-xs uppercase tracking-wide">Tourn.</span>
                          {{/if}}
                        </span>
                      </td>
                      {{! INN }}
                      <td class="px-4 py-4 text-center">
                        <div class="relative group inline-flex items-center justify-center">
                          <span class="text-sm font-bold text-gray-300 cursor-default">{{row.inn}}</span>
                          <div class="absolute bottom-full left-1/2 -translate-x-1/2 mb-3 z-50 pointer-events-none opacity-0 invisible translate-y-2 group-hover:opacity-100 group-hover:visible group-hover:translate-y-0 transition-all duration-200 ease-out">
                            <div class="relative px-3.5 py-2.5 bg-gray-950 border border-indigo-500/60 rounded-xl shadow-xl shadow-indigo-900/40 whitespace-nowrap">
                              <div class="absolute inset-0 rounded-xl bg-gradient-to-br from-indigo-600/20 to-transparent pointer-events-none"></div>
                              <p class="relative text-[11px] font-semibold text-indigo-100 leading-tight">{{row.innTip}}</p>
                              <div class="absolute -bottom-[5px] left-1/2 -translate-x-1/2 w-2.5 h-2.5 bg-gray-950 border-r border-b border-indigo-500/60 rotate-45"></div>
                            </div>
                          </div>
                        </div>
                      </td>
                      {{! NO }}
                      <td class="px-4 py-4 text-center">
                        <div class="relative group inline-flex items-center justify-center">
                          <span class="text-sm font-bold text-gray-500 cursor-default">{{row.no}}</span>
                          <div class="absolute bottom-full left-1/2 -translate-x-1/2 mb-3 z-50 pointer-events-none opacity-0 invisible translate-y-2 group-hover:opacity-100 group-hover:visible group-hover:translate-y-0 transition-all duration-200 ease-out">
                            <div class="relative px-3.5 py-2.5 bg-gray-950 border border-gray-500/50 rounded-xl shadow-xl shadow-gray-900/40 whitespace-nowrap">
                              <div class="absolute inset-0 rounded-xl bg-gradient-to-br from-gray-600/20 to-transparent pointer-events-none"></div>
                              <p class="relative text-[11px] font-semibold text-gray-200 leading-tight">{{row.noTip}}</p>
                              <div class="absolute -bottom-[5px] left-1/2 -translate-x-1/2 w-2.5 h-2.5 bg-gray-950 border-r border-b border-gray-500/50 rotate-45"></div>
                            </div>
                          </div>
                        </div>
                      </td>
                      {{! RUNS }}
                      <td class="px-4 py-4 text-center">
                        <div class="relative group inline-flex items-center justify-center">
                          <span class="text-xl font-black text-indigo-200 cursor-default">{{row.runs}}</span>
                          <div class="absolute bottom-full left-1/2 -translate-x-1/2 mb-3 z-50 pointer-events-none opacity-0 invisible translate-y-2 group-hover:opacity-100 group-hover:visible group-hover:translate-y-0 transition-all duration-200 ease-out">
                            <div class="relative px-3.5 py-2.5 bg-gray-950 border border-indigo-400/70 rounded-xl shadow-xl shadow-indigo-900/50 whitespace-nowrap">
                              <div class="absolute inset-0 rounded-xl bg-gradient-to-br from-indigo-500/25 to-transparent pointer-events-none"></div>
                              <p class="relative text-[11px] font-semibold text-indigo-100 leading-tight">{{row.runsTip}}</p>
                              <div class="absolute -bottom-[5px] left-1/2 -translate-x-1/2 w-2.5 h-2.5 bg-gray-950 border-r border-b border-indigo-400/70 rotate-45"></div>
                            </div>
                          </div>
                        </div>
                      </td>
                      {{! HS }}
                      <td class="px-4 py-4 text-center">
                        <div class="relative group inline-flex items-center justify-center">
                          <span class="text-base font-black text-amber-300 cursor-default">{{row.hs}}</span>
                          <div class="absolute bottom-full left-1/2 -translate-x-1/2 mb-3 z-50 pointer-events-none opacity-0 invisible translate-y-2 group-hover:opacity-100 group-hover:visible group-hover:translate-y-0 transition-all duration-200 ease-out">
                            <div class="relative px-3.5 py-2.5 bg-gray-950 border border-amber-500/60 rounded-xl shadow-xl shadow-amber-900/40 whitespace-nowrap">
                              <div class="absolute inset-0 rounded-xl bg-gradient-to-br from-amber-600/20 to-transparent pointer-events-none"></div>
                              <p class="relative text-[11px] font-semibold text-amber-100 leading-tight">{{row.hsTip}}</p>
                              <div class="absolute -bottom-[5px] left-1/2 -translate-x-1/2 w-2.5 h-2.5 bg-gray-950 border-r border-b border-amber-500/60 rotate-45"></div>
                            </div>
                          </div>
                        </div>
                      </td>
                      {{! AVG }}
                      <td class="px-4 py-4 text-center">
                        <div class="relative group inline-flex items-center justify-center">
                          <span class="text-base font-black text-sky-300 cursor-default">{{row.avg}}</span>
                          <div class="absolute bottom-full left-1/2 -translate-x-1/2 mb-3 z-50 pointer-events-none opacity-0 invisible translate-y-2 group-hover:opacity-100 group-hover:visible group-hover:translate-y-0 transition-all duration-200 ease-out">
                            <div class="relative px-3.5 py-2.5 bg-gray-950 border border-sky-500/60 rounded-xl shadow-xl shadow-sky-900/40 whitespace-nowrap">
                              <div class="absolute inset-0 rounded-xl bg-gradient-to-br from-sky-600/20 to-transparent pointer-events-none"></div>
                              <p class="relative text-[11px] font-semibold text-sky-100 leading-tight">{{row.avgTip}}</p>
                              <div class="absolute -bottom-[5px] left-1/2 -translate-x-1/2 w-2.5 h-2.5 bg-gray-950 border-r border-b border-sky-500/60 rotate-45"></div>
                            </div>
                          </div>
                        </div>
                      </td>
                      {{! SR }}
                      <td class="px-4 py-4 text-center">
                        <div class="relative group inline-flex items-center justify-center">
                          <span class="text-base font-black text-emerald-300 cursor-default">{{row.sr}}</span>
                          <div class="absolute bottom-full left-1/2 -translate-x-1/2 mb-3 z-50 pointer-events-none opacity-0 invisible translate-y-2 group-hover:opacity-100 group-hover:visible group-hover:translate-y-0 transition-all duration-200 ease-out">
                            <div class="relative px-3.5 py-2.5 bg-gray-950 border border-emerald-500/60 rounded-xl shadow-xl shadow-emerald-900/40 whitespace-nowrap">
                              <div class="absolute inset-0 rounded-xl bg-gradient-to-br from-emerald-600/20 to-transparent pointer-events-none"></div>
                              <p class="relative text-[11px] font-semibold text-emerald-100 leading-tight">{{row.srTip}}</p>
                              <div class="absolute -bottom-[5px] left-1/2 -translate-x-1/2 w-2.5 h-2.5 bg-gray-950 border-r border-b border-emerald-500/60 rotate-45"></div>
                            </div>
                          </div>
                        </div>
                      </td>
                      {{! 50s }}
                      <td class="px-4 py-4 text-center">
                        <div class="relative group inline-flex items-center justify-center">
                          <span class="text-base font-bold text-yellow-300 cursor-default">{{row.fifties}}</span>
                          <div class="absolute bottom-full left-1/2 -translate-x-1/2 mb-3 z-50 pointer-events-none opacity-0 invisible translate-y-2 group-hover:opacity-100 group-hover:visible group-hover:translate-y-0 transition-all duration-200 ease-out">
                            <div class="relative px-3.5 py-2.5 bg-gray-950 border border-yellow-500/60 rounded-xl shadow-xl shadow-yellow-900/40 whitespace-nowrap">
                              <div class="absolute inset-0 rounded-xl bg-gradient-to-br from-yellow-600/20 to-transparent pointer-events-none"></div>
                              <p class="relative text-[11px] font-semibold text-yellow-100 leading-tight">{{row.fiftiesTip}}</p>
                              <div class="absolute -bottom-[5px] left-1/2 -translate-x-1/2 w-2.5 h-2.5 bg-gray-950 border-r border-b border-yellow-500/60 rotate-45"></div>
                            </div>
                          </div>
                        </div>
                      </td>
                      {{! 100s }}
                      <td class="px-4 py-4 text-center">
                        <div class="relative group inline-flex items-center justify-center">
                          <span class="text-base font-bold text-yellow-200 cursor-default">{{row.hundreds}}</span>
                          <div class="absolute bottom-full left-1/2 -translate-x-1/2 mb-3 z-50 pointer-events-none opacity-0 invisible translate-y-2 group-hover:opacity-100 group-hover:visible group-hover:translate-y-0 transition-all duration-200 ease-out">
                            <div class="relative px-3.5 py-2.5 bg-gray-950 border border-yellow-400/60 rounded-xl shadow-xl shadow-yellow-900/40 whitespace-nowrap">
                              <div class="absolute inset-0 rounded-xl bg-gradient-to-br from-yellow-500/20 to-transparent pointer-events-none"></div>
                              <p class="relative text-[11px] font-semibold text-yellow-50 leading-tight">{{row.hundredsTip}}</p>
                              <div class="absolute -bottom-[5px] left-1/2 -translate-x-1/2 w-2.5 h-2.5 bg-gray-950 border-r border-b border-yellow-400/60 rotate-45"></div>
                            </div>
                          </div>
                        </div>
                      </td>
                      {{! 150s }}
                      <td class="px-4 py-4 text-center">
                        <div class="relative group inline-flex items-center justify-center">
                          <span class="text-sm font-bold text-gray-500 cursor-default">{{row.onefifty}}</span>
                          <div class="absolute bottom-full left-1/2 -translate-x-1/2 mb-3 z-50 pointer-events-none opacity-0 invisible translate-y-2 group-hover:opacity-100 group-hover:visible group-hover:translate-y-0 transition-all duration-200 ease-out">
                            <div class="relative px-3.5 py-2.5 bg-gray-950 border border-gray-500/50 rounded-xl shadow-xl shadow-gray-900/40 whitespace-nowrap">
                              <div class="absolute inset-0 rounded-xl bg-gradient-to-br from-gray-600/15 to-transparent pointer-events-none"></div>
                              <p class="relative text-[11px] font-semibold text-gray-300 leading-tight">{{row.onefiftyTip}}</p>
                              <div class="absolute -bottom-[5px] left-1/2 -translate-x-1/2 w-2.5 h-2.5 bg-gray-950 border-r border-b border-gray-500/50 rotate-45"></div>
                            </div>
                          </div>
                        </div>
                      </td>
                      {{! 200s }}
                      <td class="px-4 py-4 text-center">
                        <div class="relative group inline-flex items-center justify-center">
                          <span class="text-sm font-bold text-gray-500 cursor-default">{{row.twohundred}}</span>
                          <div class="absolute bottom-full left-1/2 -translate-x-1/2 mb-3 z-50 pointer-events-none opacity-0 invisible translate-y-2 group-hover:opacity-100 group-hover:visible group-hover:translate-y-0 transition-all duration-200 ease-out">
                            <div class="relative px-3.5 py-2.5 bg-gray-950 border border-gray-500/50 rounded-xl shadow-xl shadow-gray-900/40 whitespace-nowrap">
                              <div class="absolute inset-0 rounded-xl bg-gradient-to-br from-gray-600/15 to-transparent pointer-events-none"></div>
                              <p class="relative text-[11px] font-semibold text-gray-300 leading-tight">{{row.twohundredTip}}</p>
                              <div class="absolute -bottom-[5px] left-1/2 -translate-x-1/2 w-2.5 h-2.5 bg-gray-950 border-r border-b border-gray-500/50 rotate-45"></div>
                            </div>
                          </div>
                        </div>
                      </td>
                    </tr>
                  {{/each}}
                </tbody>
              </table>
              <div class="px-5 py-2.5 bg-gray-900/40 border-t border-indigo-500/10 flex gap-4">
                <span class="text-[10px] text-gray-600 font-mono">Inn = Innings · NO = Not Out · HS = Highest Score · Avg = Average · SR = Strike Rate</span>
              </div>
            </div>
          {{else}}
            <div class="flex flex-col items-center justify-center py-16 gap-3 rounded-2xl border border-indigo-500/10 bg-indigo-600/5">
              <span class="text-5xl opacity-30">🏏</span>
              <p class="text-gray-500 text-sm font-medium">No batting history recorded yet.</p>
            </div>
          {{/if}}
        </div>
      {{/if}}

      {{! ── Bowling Panel ── }}
      {{#if (eq this.cricketStatsTab "bowling")}}
        <div class="relative panel-enter space-y-4">
          {{#if this.hasBowlingData}}
            <div class="overflow-x-auto rounded-2xl border border-emerald-500/25 shadow-2xl shadow-emerald-900/30">
              <div class="flex items-center gap-3 px-5 py-4 border-b border-emerald-500/20 bg-gradient-to-r from-emerald-600/25 via-emerald-600/10 to-transparent">
                <span class="text-base">🎳</span>
                <span class="text-sm font-black text-emerald-100 uppercase tracking-widest">Bowling Statistics</span>
                <span class="ml-auto text-[10px] text-emerald-400/60 font-mono">Career · Game · Tournament</span>
              </div>
              <table class="w-full text-sm min-w-[860px] bg-gray-900/70 backdrop-blur-sm">
                <thead>
                  <tr class="border-b-2 border-emerald-500/30 bg-emerald-950/50">
                    <th class="text-left px-5 py-3.5 text-[10px] font-black text-emerald-400 uppercase tracking-widest sticky left-0 bg-emerald-950/90 z-10 min-w-[96px] border-r border-emerald-500/15">Format</th>
                    <th class="px-4 py-3.5 text-[10px] font-black text-gray-500 uppercase tracking-widest text-center">Balls</th>
                    <th class="px-4 py-3.5 text-[10px] font-black text-emerald-300 uppercase tracking-widest text-center">Wkts</th>
                    <th class="px-4 py-3.5 text-[10px] font-black text-rose-400 uppercase tracking-widest text-center">Runs</th>
                    <th class="px-4 py-3.5 text-[10px] font-black text-sky-300 uppercase tracking-widest text-center">Avg</th>
                    <th class="px-4 py-3.5 text-[10px] font-black text-amber-400 uppercase tracking-widest text-center">SR</th>
                    <th class="px-4 py-3.5 text-[10px] font-black text-violet-300 uppercase tracking-widest text-center">Maiden</th>
                    <th class="px-4 py-3.5 text-[10px] font-black text-gray-400 uppercase tracking-widest text-center">Bowled</th>
                    <th class="px-4 py-3.5 text-[10px] font-black text-gray-400 uppercase tracking-widest text-center">Caught</th>
                    <th class="px-4 py-3.5 text-[10px] font-black text-gray-400 uppercase tracking-widest text-center">C&B</th>
                    <th class="px-4 py-3.5 text-[10px] font-black text-gray-400 uppercase tracking-widest text-center">LBW</th>
                    <th class="px-4 py-3.5 text-[10px] font-black text-gray-400 uppercase tracking-widest text-center">St</th>
                  </tr>
                </thead>
                <tbody>
                  {{#each this.bowlingTableRows as |row|}}
                    <tr class="border-b border-emerald-500/10 hover:bg-emerald-500/8 transition-colors duration-150 last:border-0
                      {{if (eq row.format 'Career') 'bg-emerald-900/15' 'bg-gray-900/20'}}">
                      <td class="sticky left-0 px-5 py-4 border-r border-emerald-500/10 z-10
                        {{if (eq row.format 'Career') 'bg-emerald-900/70' ''}}
                        {{if (eq row.format 'Game') 'bg-sky-950/70' ''}}
                        {{if (eq row.format 'Tournament') 'bg-violet-950/70' ''}}">
                        <span class="flex items-center gap-2">
                          {{#if (eq row.format 'Career')}}
                            <span class="w-1.5 h-5 rounded-full bg-emerald-400 shrink-0"></span>
                            <span class="font-black text-emerald-200 text-xs uppercase tracking-wide">Career</span>
                          {{/if}}
                          {{#if (eq row.format 'Game')}}
                            <span class="w-1.5 h-5 rounded-full bg-sky-400 shrink-0"></span>
                            <span class="font-black text-sky-300 text-xs uppercase tracking-wide">Game</span>
                          {{/if}}
                          {{#if (eq row.format 'Tournament')}}
                            <span class="w-1.5 h-5 rounded-full bg-violet-400 shrink-0"></span>
                            <span class="font-black text-violet-300 text-xs uppercase tracking-wide">Tourn.</span>
                          {{/if}}
                        </span>
                      </td>
                      <td class="px-4 py-4 text-center"><span class="text-sm font-bold text-gray-300">{{row.balls}}</span></td>
                      <td class="px-4 py-4 text-center"><span class="text-xl font-black text-emerald-200">{{row.wkts}}</span></td>
                      <td class="px-4 py-4 text-center"><span class="text-base font-black text-rose-300">{{row.runs}}</span></td>
                      <td class="px-4 py-4 text-center"><span class="text-base font-black text-sky-300">{{row.avg}}</span></td>
                      <td class="px-4 py-4 text-center"><span class="text-base font-black text-amber-300">{{row.sr}}</span></td>
                      <td class="px-4 py-4 text-center"><span class="text-base font-bold text-violet-300">{{row.maiden}}</span></td>
                      <td class="px-4 py-4 text-center"><span class="text-sm font-bold text-gray-400">{{row.bowled}}</span></td>
                      <td class="px-4 py-4 text-center"><span class="text-sm font-bold text-gray-400">{{row.caught}}</span></td>
                      <td class="px-4 py-4 text-center"><span class="text-sm font-bold text-gray-400">{{row.cnb}}</span></td>
                      <td class="px-4 py-4 text-center"><span class="text-sm font-bold text-gray-400">{{row.lbw}}</span></td>
                      <td class="px-4 py-4 text-center"><span class="text-sm font-bold text-gray-400">{{row.stumped}}</span></td>
                    </tr>
                  {{/each}}
                </tbody>
              </table>
              <div class="px-5 py-2.5 bg-gray-900/40 border-t border-emerald-500/10 flex gap-4">
                <span class="text-[10px] text-gray-600 font-mono">Wkts = Wickets · Avg = Average · SR = Strike Rate · C&B = Caught & Bowled · St = Stumped</span>
              </div>
            </div>
            {{#if this.hasBallSpeedData}}
              <div class="overflow-hidden rounded-2xl border border-sky-500/20 bg-gray-900/70">
                <div class="flex items-center gap-3 px-5 py-3.5 border-b border-sky-500/15 bg-gradient-to-r from-sky-600/15 to-transparent">
                  <span class="text-base">💨</span>
                  <span class="text-sm font-black text-sky-200 uppercase tracking-widest">Ball Speed</span>
                  <span class="text-[10px] text-sky-400/60 font-mono ml-1">km/h</span>
                </div>
                <div class="grid grid-cols-3 divide-x divide-sky-500/15">
                  <div class="px-6 py-6 text-center">
                    <span class="block text-3xl font-black text-sky-300 leading-none mb-2">{{fmt this.bs.lowestballspeed}}</span>
                    <span class="block text-[10px] font-bold text-sky-500/80 uppercase tracking-widest">Slowest</span>
                  </div>
                  <div class="px-6 py-6 text-center bg-indigo-500/5">
                    <span class="block text-3xl font-black text-indigo-300 leading-none mb-2">{{fmt this.bs.averageballspeed}}</span>
                    <span class="block text-[10px] font-bold text-indigo-500/80 uppercase tracking-widest">Average</span>
                  </div>
                  <div class="px-6 py-6 text-center">
                    <span class="block text-3xl font-black text-rose-300 leading-none mb-2">{{fmt this.bs.highestballspeed}}</span>
                    <span class="block text-[10px] font-bold text-rose-500/80 uppercase tracking-widest">Fastest</span>
                  </div>
                </div>
              </div>
            {{/if}}
          {{else}}
            <div class="flex flex-col items-center justify-center py-16 gap-3 rounded-2xl border border-emerald-500/10 bg-emerald-600/5">
              <span class="text-5xl opacity-30">🎳</span>
              <p class="text-gray-500 text-sm font-medium">No bowling history recorded yet.</p>
            </div>
          {{/if}}
        </div>
      {{/if}}

      {{! ── Fielding Panel ── }}
      {{#if (eq this.cricketStatsTab "fielding")}}
        <div class="relative panel-enter space-y-4">
          {{#if this.fds.fielding_rating}}
            <div class="flex items-center gap-2">
              <div class="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-amber-500/10 border border-amber-500/30">
                <span class="text-amber-400 text-xs">★</span>
                <span class="text-xs font-bold text-amber-400">{{this.fds.fielding_rating}} Fielding Rating</span>
              </div>
            </div>
          {{/if}}
          {{#if this.hasFieldingData}}
            <div class="overflow-x-auto rounded-2xl border border-teal-500/25 shadow-2xl shadow-teal-900/30">
              <div class="flex items-center gap-3 px-5 py-4 border-b border-teal-500/20 bg-gradient-to-r from-teal-600/25 via-teal-600/10 to-transparent">
                <span class="text-base">🧤</span>
                <span class="text-sm font-black text-teal-100 uppercase tracking-widest">Fielding Statistics</span>
                <span class="ml-auto text-[10px] text-teal-400/60 font-mono">By Position</span>
              </div>
              <table class="w-full text-sm min-w-[640px] bg-gray-900/70 backdrop-blur-sm">
                <thead>
                  <tr class="border-b-2 border-teal-500/30 bg-teal-950/50">
                    <th class="text-left px-5 py-3.5 text-[10px] font-black text-teal-400 uppercase tracking-widest sticky left-0 bg-teal-950/90 z-10 min-w-[120px] border-r border-teal-500/15">Position</th>
                    <th class="px-4 py-3.5 text-[10px] font-black text-gray-400 uppercase tracking-widest text-center">Played</th>
                    <th class="px-4 py-3.5 text-[10px] font-black text-emerald-400 uppercase tracking-widest text-center">Run Outs</th>
                    <th class="px-4 py-3.5 text-[10px] font-black text-sky-400 uppercase tracking-widest text-center">Catches</th>
                    <th class="px-4 py-3.5 text-[10px] font-black text-amber-400 uppercase tracking-widest text-center">Runs Saved</th>
                    <th class="px-4 py-3.5 text-[10px] font-black text-violet-400 uppercase tracking-widest text-center">Direct Hit</th>
                    <th class="px-4 py-3.5 text-[10px] font-black text-rose-400 uppercase tracking-widest text-center">Spec. Catch</th>
                    <th class="px-4 py-3.5 text-[10px] font-black text-orange-400 uppercase tracking-widest text-center">Spec. Field</th>
                  </tr>
                </thead>
                <tbody>
                  {{#each this.fieldingPositionRows as |row|}}
                    <tr class="border-b border-teal-500/10 hover:bg-teal-500/8 transition-colors duration-150 last:border-0 bg-gray-900/20">
                      <td class="sticky left-0 px-5 py-4 bg-teal-950/70 border-r border-teal-500/10 z-10">
                        <span class="flex items-center gap-2">
                          <span class="w-1.5 h-5 rounded-full bg-teal-400 shrink-0"></span>
                          <span class="font-bold text-teal-200 capitalize text-sm">{{row.position}}</span>
                        </span>
                      </td>
                      <td class="px-4 py-4 text-center"><span class="text-base font-black text-white">{{row.played}}</span></td>
                      <td class="px-4 py-4 text-center"><span class="text-base font-black text-emerald-300">{{row.runout}}</span></td>
                      <td class="px-4 py-4 text-center"><span class="text-base font-black text-sky-300">{{row.catches}}</span></td>
                      <td class="px-4 py-4 text-center"><span class="text-base font-black text-amber-300">{{row.runssaved}}</span></td>
                      <td class="px-4 py-4 text-center"><span class="text-base font-black text-violet-300">{{row.directthrough}}</span></td>
                      <td class="px-4 py-4 text-center"><span class="text-base font-black text-rose-300">{{row.spectacularcatch}}</span></td>
                      <td class="px-4 py-4 text-center"><span class="text-base font-black text-orange-300">{{row.spectacularfilding}}</span></td>
                    </tr>
                  {{/each}}
                </tbody>
              </table>
            </div>
          {{else}}
            <div class="flex flex-col items-center justify-center py-16 gap-3 rounded-2xl border border-teal-500/10 bg-teal-600/5">
              <span class="text-5xl opacity-30">🧤</span>
              <p class="text-gray-500 text-sm font-medium">No fielding history recorded yet.</p>
            </div>
          {{/if}}
        </div>
      {{/if}}

      {{! ── Overall Panel ── }}
      {{#if (eq this.cricketStatsTab "overall")}}
        <div class="relative panel-enter space-y-4">
          {{#if this.hasOverallData}}
            <div class="overflow-x-auto rounded-2xl border border-amber-500/25 shadow-2xl shadow-amber-900/30">
              <div class="flex items-center gap-3 px-5 py-4 border-b border-amber-500/20 bg-gradient-to-r from-amber-600/25 via-amber-600/10 to-transparent">
                <span class="text-base">🏆</span>
                <span class="text-sm font-black text-amber-100 uppercase tracking-widest">Player Rankings</span>
                <span class="ml-auto text-[10px] text-amber-400/60 font-mono">Career · Game · Tournament</span>
              </div>
              <table class="w-full text-sm min-w-[520px] bg-gray-900/70 backdrop-blur-sm">
                <thead>
                  <tr class="border-b-2 border-amber-500/30 bg-amber-950/50">
                    <th class="text-left px-5 py-3.5 text-[10px] font-black text-amber-400 uppercase tracking-widest sticky left-0 bg-amber-950/90 z-10 min-w-[96px] border-r border-amber-500/15">Format</th>
                    <th class="px-5 py-3.5 text-[10px] font-black text-gray-400 uppercase tracking-widest text-center">Matches</th>
                    <th class="px-5 py-3.5 text-[10px] font-black text-sky-300 uppercase tracking-widest text-center">City</th>
                    <th class="px-5 py-3.5 text-[10px] font-black text-emerald-300 uppercase tracking-widest text-center">State</th>
                    <th class="px-5 py-3.5 text-[10px] font-black text-violet-300 uppercase tracking-widest text-center">Country</th>
                    <th class="px-5 py-3.5 text-[10px] font-black text-amber-300 uppercase tracking-widest text-center">World</th>
                  </tr>
                </thead>
                <tbody>
                  {{#each this.overallTableRows as |row|}}
                    <tr class="border-b border-amber-500/10 hover:bg-amber-500/8 transition-colors duration-150 last:border-0
                      {{if (eq row.format 'Career') 'bg-amber-900/15' 'bg-gray-900/20'}}">
                      <td class="sticky left-0 px-5 py-5 border-r border-amber-500/10 z-10
                        {{if (eq row.format 'Career') 'bg-amber-900/70' ''}}
                        {{if (eq row.format 'Game') 'bg-sky-950/70' ''}}
                        {{if (eq row.format 'Tournament') 'bg-violet-950/70' ''}}">
                        <span class="flex items-center gap-2">
                          {{#if (eq row.format 'Career')}}
                            <span class="w-1.5 h-5 rounded-full bg-amber-400 shrink-0"></span>
                            <span class="font-black text-amber-200 text-xs uppercase tracking-wide">Career</span>
                          {{/if}}
                          {{#if (eq row.format 'Game')}}
                            <span class="w-1.5 h-5 rounded-full bg-sky-400 shrink-0"></span>
                            <span class="font-black text-sky-300 text-xs uppercase tracking-wide">Game</span>
                          {{/if}}
                          {{#if (eq row.format 'Tournament')}}
                            <span class="w-1.5 h-5 rounded-full bg-violet-400 shrink-0"></span>
                            <span class="font-black text-violet-300 text-xs uppercase tracking-wide">Tourn.</span>
                          {{/if}}
                        </span>
                      </td>
                      <td class="px-5 py-5 text-center"><span class="text-xl font-black text-white">{{row.played}}</span></td>
                      <td class="px-5 py-5 text-center"><span class="text-lg font-black text-sky-300">{{row.cityRank}}</span></td>
                      <td class="px-5 py-5 text-center"><span class="text-lg font-black text-emerald-300">{{row.stateRank}}</span></td>
                      <td class="px-5 py-5 text-center"><span class="text-lg font-black text-violet-300">{{row.countryRank}}</span></td>
                      <td class="px-5 py-5 text-center"><span class="text-lg font-black text-amber-300">{{row.worldRank}}</span></td>
                    </tr>
                  {{/each}}
                </tbody>
              </table>
              <div class="px-5 py-2.5 bg-gray-900/40 border-t border-amber-500/10">
                <span class="text-[10px] text-gray-600 font-mono">Rankings show player position within each geographic scope</span>
              </div>
            </div>
          {{else}}
            <div class="flex flex-col items-center justify-center py-16 gap-3 rounded-2xl border border-amber-500/10 bg-amber-600/5">
              <span class="text-5xl opacity-30">🏆</span>
              <p class="text-gray-500 text-sm font-medium">No overall statistics recorded yet.</p>
            </div>
          {{/if}}
        </div>
      {{/if}}

    </div>
  </template>
}
