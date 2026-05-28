import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { eq } from 'ember-truth-helpers';
import config from 'spordium/config/environment';

class ScoreboardPageComponent extends Component {
  @tracked selectedInnings = 0;

  get model() {
    return this.args.model;
  }

  get inningsData() {
    return this.args.inningsData || [];
  }

  get currentBattingInnings() {
    return this.inningsData[this.selectedInnings] || null;
  }

  get battingRows() {
    return this.currentBattingInnings?.batsmen || [];
  }

  get battingTotals() {
    const inn = this.currentBattingInnings;
    if (!inn) return null;
    return { teamName: inn.teamName, runs: inn.score ?? '0', overs: inn.overs ?? '—' };
  }

  get bowlingData() {
    return this.args.bowlingData || [];
  }

  get currentBowlingTeam() {
    const battingTeamId = this.currentBattingInnings?.teamId;
    if (!battingTeamId) return null;
    return this.bowlingData.find((t) => t.teamId !== battingTeamId) || null;
  }

  get bowlingRows() {
    return this.currentBowlingTeam?.bowlers || [];
  }

  get tossText() {
    const toss = this.model?.toss;
    if (!toss) return null;
    const winner = toss.toss_winner_name || toss.winner_name || toss.winner || '';
    const decision = toss.toss_decision || toss.decision || '';
    if (!winner) return null;
    return `${winner} won the toss and elected to ${decision}`;
  }

  get matchDateFormatted() {
    const dt = this.model?.gameDatetime;
    if (!dt) return null;
    try {
      return new Date(dt).toLocaleString('en-GB', {
        day: '2-digit', month: 'short', year: 'numeric',
        hour: '2-digit', minute: '2-digit', hour12: true,
      });
    } catch {
      return null;
    }
  }

  get staffGroups() {
    const toRoleMembers = (list) =>
      (list || []).map((m) => {
        const first = m?.user_fullname?.first_name || '';
        const last  = m?.user_fullname?.last_name  || '';
        const name  = `${first} ${last}`.trim() || m?.user_username || m?.user_email || '—';
        const picPath = m?.user_primary_pic;
        const avatar  = picPath ? `${config.APP.S3_BUCKET_URL}/${picPath}` : null;
        return { name, avatar, initial: name.charAt(0).toUpperCase() };
      });

    return [
      { label: 'Streamer', icon: '📹', members: toRoleMembers(this.args.streamers) },
      { label: 'Umpire',   icon: '⚖️', members: toRoleMembers(this.args.umpires) },
      { label: 'Scorer',   icon: '📊', members: toRoleMembers(this.args.scorers) },
    ];
  }

  get inningsTabs() {
    return this.inningsData.map((inn, idx) => ({
      label: `Innings ${inn.inningsNumber}`,
      sublabel: inn.teamName,
      index: idx,
    }));
  }

  @action
  selectInnings(index) {
    this.selectedInnings = index;
  }

  @action
  goBack() {
    history.back();
  }

  <template>
    <div class="min-h-screen bg-gray-50 dark:bg-slate-950 -mx-4 sm:-mx-6 lg:-mx-8">

      {{! ── Hero Header ── }}
      <div class="bg-gradient-to-b from-gray-100 to-gray-50 dark:from-slate-800 dark:to-slate-950 border-b border-gray-200 dark:border-slate-700/40 px-4 sm:px-6 lg:px-8 pt-5 pb-6">
        <div class="max-w-6xl mx-auto">

        {{! Back }}
        <button
          type="button"
          class="flex items-center gap-1.5 text-gray-500 hover:text-gray-800 dark:hover:text-gray-200 text-xs mb-5 transition-colors"
          {{on "click" this.goBack}}
        >
          <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
          </svg>
          Back
        </button>

        {{! Match meta }}
        <div class="text-center mb-6">
          <h1 class="text-gray-900 dark:text-white text-xl sm:text-2xl font-black tracking-tight mb-2">
            {{#if @model.gameName}}{{@model.gameName}}{{else}}Match Scorecard{{/if}}
          </h1>
          <div class="flex flex-wrap items-center justify-center gap-2 text-[11px] text-gray-500">
            {{#if this.matchDateFormatted}}
              <span class="flex items-center gap-1">
                <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                </svg>
                {{this.matchDateFormatted}}
              </span>
              <span class="text-gray-400 dark:text-slate-700">·</span>
            {{/if}}
            {{#if @model.gamefieldName}}
              <span class="flex items-center gap-1">
                <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                </svg>
                {{@model.gamefieldName}}
              </span>
            {{/if}}
            {{#if @model.typeOfGame}}
              <span class="text-gray-400 dark:text-slate-700">·</span>
              <span class="bg-gray-200 dark:bg-slate-700/60 text-gray-600 dark:text-gray-300 px-2 py-0.5 rounded-full">{{@model.typeOfGame}}</span>
            {{/if}}
          </div>
        </div>

        {{! Teams vs block }}
        <div class="flex items-center justify-center gap-6 sm:gap-12">

          <div class="flex flex-col items-center gap-2.5 flex-1 min-w-0 max-w-[160px]">
            <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-2xl overflow-hidden bg-gray-200 dark:bg-slate-700/60 ring-2 ring-gray-300 dark:ring-slate-600/40 shadow-xl">
              <img src={{@model.team1Logo}} alt={{@model.team1Name}} class="w-full h-full object-contain p-1" />
            </div>
            <span class="text-gray-900 dark:text-white text-sm sm:text-base font-bold text-center leading-tight">{{@model.team1Name}}</span>
          </div>

          <div class="flex flex-col items-center gap-2 flex-shrink-0">
            <div class="w-11 h-11 rounded-full bg-gray-200 dark:bg-slate-700/40 ring-1 ring-gray-300 dark:ring-slate-600/40 flex items-center justify-center">
              <span class="text-gray-500 dark:text-gray-400 text-xs font-black tracking-widest">VS</span>
            </div>
            {{#if this.tossText}}
              <p class="text-gray-500 dark:text-gray-600 text-[10px] text-center max-w-[130px] leading-snug">{{this.tossText}}</p>
            {{/if}}
          </div>

          <div class="flex flex-col items-center gap-2.5 flex-1 min-w-0 max-w-[160px]">
            <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-2xl overflow-hidden bg-gray-200 dark:bg-slate-700/60 ring-2 ring-gray-300 dark:ring-slate-600/40 shadow-xl">
              <img src={{@model.team2Logo}} alt={{@model.team2Name}} class="w-full h-full object-contain p-1" />
            </div>
            <span class="text-gray-900 dark:text-white text-sm sm:text-base font-bold text-center leading-tight">{{@model.team2Name}}</span>
          </div>

        </div>
        </div>
      </div>

      <div class="px-4 sm:px-6 lg:px-8 py-5 space-y-4 max-w-6xl mx-auto">

        {{! ── Staff ── }}
        <div class="grid grid-cols-3 gap-px bg-gray-200 dark:bg-slate-700/30 rounded-2xl overflow-hidden border border-gray-200 dark:border-slate-700/40">
          {{#each this.staffGroups as |group|}}
            <div class="bg-white dark:bg-slate-900 px-4 py-3.5">
              <p class="text-gray-500 dark:text-gray-600 text-[10px] uppercase tracking-widest mb-2.5 flex items-center gap-1.5">
                <span>{{group.icon}}</span>{{group.label}}
              </p>
              {{#if group.members.length}}
                <div class="space-y-2">
                  {{#each group.members as |member|}}
                    <div class="flex items-center gap-2">
                      <div class="w-7 h-7 rounded-full overflow-hidden bg-gray-200 dark:bg-slate-700 flex-shrink-0 flex items-center justify-center ring-1 ring-gray-300 dark:ring-slate-600/40">
                        {{#if member.avatar}}
                          <img src={{member.avatar}} alt="" class="w-full h-full object-cover" />
                        {{else}}
                          <span class="text-gray-600 dark:text-gray-300 text-[11px] font-bold">{{member.initial}}</span>
                        {{/if}}
                      </div>
                      <p class="text-gray-700 dark:text-gray-200 text-xs font-medium truncate">{{member.name}}</p>
                    </div>
                  {{/each}}
                </div>
              {{else}}
                <p class="text-gray-400 dark:text-slate-600 text-xs">—</p>
              {{/if}}
            </div>
          {{/each}}
        </div>

        {{! ── Scorecard ── }}
        <div class="bg-white dark:bg-slate-900 rounded-2xl border border-gray-200 dark:border-slate-700/40 overflow-hidden">

          {{! Innings tabs }}
          <div class="flex border-b border-gray-200 dark:border-slate-700/40 bg-gray-50 dark:bg-slate-800/40">
            <div class="px-4 py-3 flex items-center border-r border-gray-200 dark:border-slate-700/40 flex-shrink-0">
              <span class="text-gray-500 text-[10px] uppercase tracking-widest font-semibold">Score Card</span>
            </div>
            {{#each this.inningsTabs as |tab|}}
              <button
                type="button"
                class="px-5 py-3 text-xs font-semibold border-b-2 transition-colors flex-shrink-0
                  {{if (eq this.selectedInnings tab.index)
                    'border-cyan-500 dark:border-cyan-400 text-gray-900 dark:text-white bg-gray-100 dark:bg-slate-800/60'
                    'border-transparent text-gray-500 hover:text-gray-700 dark:hover:text-gray-300 hover:bg-gray-100 dark:hover:bg-slate-800/30'}}"
                {{on "click" (fn this.selectInnings tab.index)}}
              >
                {{tab.label}}
                <span class="block text-[10px] font-normal opacity-60 mt-0.5 truncate max-w-[100px]">{{tab.sublabel}}</span>
              </button>
            {{/each}}
          </div>

          {{#if this.currentBattingInnings}}
            <div class="flex flex-col lg:flex-row divide-y lg:divide-y-0 lg:divide-x divide-gray-100 dark:divide-slate-700/30">

              {{! ─ Batting table ─ }}
              <div class="flex-1 min-w-0">
                <div class="flex items-center justify-between px-5 py-3 bg-gray-50 dark:bg-slate-800/30">
                  <div class="flex items-center gap-2">
                    <span class="w-1.5 h-4 bg-emerald-500 rounded-full"></span>
                    <span class="text-emerald-600 dark:text-emerald-400 text-xs font-bold uppercase tracking-wider">Batting</span>
                    <span class="text-gray-500 text-xs">· {{this.currentBattingInnings.teamName}}</span>
                  </div>
                  {{#if this.battingTotals}}
                    <div class="flex items-baseline gap-1.5">
                      <span class="text-gray-900 dark:text-white text-base font-black">{{this.battingTotals.runs}}</span>
                      <span class="text-gray-500 text-xs">({{this.battingTotals.overs}} ov)</span>
                    </div>
                  {{/if}}
                </div>

                <div class="overflow-x-auto">
                  <table class="w-full min-w-[460px]">
                    <thead>
                      <tr class="bg-gray-50 dark:bg-slate-800/20">
                        <th class="text-left text-gray-500 dark:text-gray-600 text-[10px] font-semibold uppercase tracking-wider px-5 py-2 w-[45%]">Batter</th>
                        <th class="text-right text-gray-500 dark:text-gray-600 text-[10px] font-semibold uppercase px-3 py-2">R</th>
                        <th class="text-right text-gray-500 dark:text-gray-600 text-[10px] font-semibold uppercase px-3 py-2">B</th>
                        <th class="text-right text-gray-500 dark:text-gray-600 text-[10px] font-semibold uppercase px-3 py-2">4s</th>
                        <th class="text-right text-gray-500 dark:text-gray-600 text-[10px] font-semibold uppercase px-3 py-2">6s</th>
                        <th class="text-right text-gray-500 dark:text-gray-600 text-[10px] font-semibold uppercase px-5 py-2">SR</th>
                      </tr>
                    </thead>
                    <tbody>
                      {{#each this.battingRows as |row|}}
                        <tr class="border-t border-gray-100 dark:border-slate-800 hover:bg-gray-50 dark:hover:bg-slate-800/30 transition-colors">
                          <td class="px-5 py-3">
                            <p class="text-gray-900 dark:text-white text-xs font-semibold">{{row.name}}</p>
                            {{#if row.outType}}
                              <p class="text-gray-500 dark:text-gray-600 text-[10px] mt-0.5 line-clamp-1">{{row.outType}}</p>
                            {{else if row.isOut}}
                              <p class="text-gray-500 dark:text-gray-600 text-[10px] mt-0.5">out</p>
                            {{else}}
                              <p class="text-emerald-600 dark:text-emerald-500 text-[10px] mt-0.5">not out ★</p>
                            {{/if}}
                          </td>
                          <td class="text-right px-3 py-3">
                            <span class="text-gray-900 dark:text-white text-sm font-black">{{row.runs}}</span>
                          </td>
                          <td class="text-right text-gray-500 text-xs px-3 py-3">{{row.balls}}</td>
                          <td class="text-right text-gray-500 dark:text-gray-400 text-xs px-3 py-3">{{row.fours}}</td>
                          <td class="text-right text-gray-500 dark:text-gray-400 text-xs px-3 py-3">{{row.sixes}}</td>
                          <td class="text-right text-gray-500 text-xs px-5 py-3">{{row.strikeRate}}</td>
                        </tr>
                      {{else}}
                        <tr>
                          <td colspan="6" class="px-5 py-10 text-center text-gray-400 dark:text-gray-600 text-xs">No batting data yet</td>
                        </tr>
                      {{/each}}
                    </tbody>
                    {{#if this.battingTotals}}
                      <tfoot>
                        <tr class="bg-gray-50 dark:bg-slate-800/40 border-t border-gray-200 dark:border-slate-700/50">
                          <td class="px-5 py-2.5 text-gray-500 dark:text-gray-400 text-xs font-bold">Total</td>
                          <td colspan="5" class="px-5 py-2.5 text-right">
                            <span class="text-gray-900 dark:text-white text-xs font-bold">{{this.battingTotals.runs}}</span>
                            <span class="text-gray-500 dark:text-gray-600 text-xs ml-2">({{this.battingTotals.overs}} overs)</span>
                          </td>
                        </tr>
                      </tfoot>
                    {{/if}}
                  </table>
                </div>
              </div>

              {{! ─ Bowling table ─ }}
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2 px-5 py-3 bg-gray-50 dark:bg-slate-800/30">
                  <span class="w-1.5 h-4 bg-blue-500 rounded-full"></span>
                  <span class="text-blue-600 dark:text-blue-400 text-xs font-bold uppercase tracking-wider">Bowling</span>
                  {{#if this.currentBowlingTeam}}
                    <span class="text-gray-500 text-xs">· {{this.currentBowlingTeam.teamName}}</span>
                  {{/if}}
                </div>

                <div class="overflow-x-auto">
                  <table class="w-full min-w-[660px]">
                    <thead>
                      <tr class="bg-gray-50 dark:bg-slate-800/20">
                        <th class="text-left text-gray-500 dark:text-gray-600 text-[10px] font-semibold uppercase tracking-wider px-5 py-2">Bowler</th>
                        <th class="text-right text-gray-500 dark:text-gray-600 text-[10px] font-semibold uppercase px-3 py-2">O</th>
                        <th class="text-right text-gray-500 dark:text-gray-600 text-[10px] font-semibold uppercase px-3 py-2">M</th>
                        <th class="text-right text-gray-500 dark:text-gray-600 text-[10px] font-semibold uppercase px-3 py-2">R</th>
                        <th class="text-right text-gray-500 dark:text-gray-600 text-[10px] font-semibold uppercase px-3 py-2">W</th>
                        <th class="text-right text-gray-500 dark:text-gray-600 text-[10px] font-semibold uppercase px-3 py-2">ECON</th>
                        <th class="text-right text-gray-500 dark:text-gray-600 text-[10px] font-semibold uppercase px-3 py-2">0s</th>
                        <th class="text-right text-gray-500 dark:text-gray-600 text-[10px] font-semibold uppercase px-3 py-2">4s</th>
                        <th class="text-right text-gray-500 dark:text-gray-600 text-[10px] font-semibold uppercase px-3 py-2">6s</th>
                        <th class="text-right text-gray-500 dark:text-gray-600 text-[10px] font-semibold uppercase px-3 py-2">WD</th>
                        <th class="text-right text-gray-500 dark:text-gray-600 text-[10px] font-semibold uppercase px-5 py-2">NB</th>
                      </tr>
                    </thead>
                    <tbody>
                      {{#each this.bowlingRows as |row|}}
                        <tr class="border-t border-gray-100 dark:border-slate-800 hover:bg-gray-50 dark:hover:bg-slate-800/30 transition-colors">
                          <td class="px-5 py-3 text-gray-900 dark:text-white text-xs font-semibold">{{row.name}}</td>
                          <td class="text-right text-gray-500 dark:text-gray-400 text-xs px-3 py-3">{{row.overs}}</td>
                          <td class="text-right text-gray-500 text-xs px-3 py-3">{{row.maidens}}</td>
                          <td class="text-right text-gray-500 dark:text-gray-400 text-xs px-3 py-3">{{row.runs}}</td>
                          <td class="text-right px-3 py-3">
                            <span class="text-gray-900 dark:text-white text-sm font-black">{{row.wickets}}</span>
                          </td>
                          <td class="text-right text-cyan-600 dark:text-cyan-400 text-xs font-semibold px-3 py-3">{{row.economy}}</td>
                          <td class="text-right text-gray-500 text-xs px-3 py-3">{{row.dotBalls}}</td>
                          <td class="text-right text-gray-500 text-xs px-3 py-3">{{row.fours}}</td>
                          <td class="text-right text-gray-500 text-xs px-3 py-3">{{row.sixes}}</td>
                          <td class="text-right text-gray-500 text-xs px-3 py-3">{{row.wides}}</td>
                          <td class="text-right text-gray-500 text-xs px-5 py-3">{{row.noBalls}}</td>
                        </tr>
                      {{else}}
                        <tr>
                          <td colspan="11" class="px-5 py-10 text-center text-gray-400 dark:text-gray-600 text-xs">No bowling data yet</td>
                        </tr>
                      {{/each}}
                    </tbody>
                  </table>
                </div>
              </div>

            </div>

          {{else}}
            <div class="py-16 text-center">
              <div class="w-16 h-16 mx-auto mb-4 bg-gray-100 dark:bg-slate-800 rounded-full flex items-center justify-center">
                <span class="text-3xl">🏏</span>
              </div>
              <p class="text-gray-500 dark:text-gray-400 text-sm font-semibold">Scorecard not available</p>
              <p class="text-gray-400 dark:text-gray-600 text-xs mt-1">Data will appear once the match begins</p>
            </div>
          {{/if}}

        </div>

      </div>
    </div>
  </template>
}

export default ScoreboardPageComponent;
