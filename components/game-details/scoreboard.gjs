import { eq, or } from 'ember-truth-helpers';

function initial(str) {
  return str?.charAt(0)?.toUpperCase() ?? '?';
}

function ballBg(ball) {
  if (ball === 'W') return 'bg-red-500 text-white';
  if (ball === 'wd') return 'bg-yellow-400 text-yellow-900';
  if (ball === 'nb') return 'bg-orange-500 text-white';
  if (ball === 'lb') return 'bg-purple-400 text-white';
  if (ball === '0' || ball === '.') return 'bg-gray-200 dark:bg-slate-700 text-gray-400 dark:text-slate-500';
  if (parseInt(ball, 10) >= 4) return 'bg-emerald-500 text-white';
  return 'bg-slate-200 dark:bg-slate-600 text-slate-700 dark:text-slate-200';
}

function ballDisplay(ball) {
  return ball === '0' ? '·' : ball;
}

function recentBalls(arr) {
  if (!arr?.length) return [];
  return arr.length > 8 ? arr.slice(-8) : arr;
}

<template>
  <div class="rounded-2xl overflow-hidden shadow-lg border border-gray-200 dark:border-white/5 bg-white dark:bg-slate-900">

    {{! ── Status Bar ── }}
    <div class="flex items-center justify-between px-4 py-2.5 bg-gray-50 dark:bg-slate-950 border-b border-gray-100 dark:border-white/5">
      <div class="flex items-center gap-2">
        {{#if @model.isFinished}}
          <span class="text-xs font-bold uppercase tracking-widest text-gray-400 dark:text-slate-500">
            {{#if (eq @model.typeOfGame "Test")}}Stumps{{else}}Match Over{{/if}}
          </span>
        {{else if @model.isApproving}}
          <span class="flex items-center gap-1.5 text-xs font-bold uppercase tracking-widest text-amber-500 dark:text-amber-400">
            <span class="relative flex h-2 w-2">
              <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-amber-400 opacity-75"></span>
              <span class="relative inline-flex rounded-full h-2 w-2 bg-amber-500"></span>
            </span>
            Approval Pending
          </span>
        {{else if @model.isStarted}}
          <span class="flex items-center gap-1.5 text-xs font-bold uppercase tracking-widest text-red-500 dark:text-red-400">
            <span class="relative flex h-2 w-2">
              <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-red-400 opacity-75"></span>
              <span class="relative inline-flex rounded-full h-2 w-2 bg-red-500"></span>
            </span>
            Live
          </span>
        {{else}}
          <span class="text-xs font-bold uppercase tracking-widest text-sky-500 dark:text-sky-400">Upcoming</span>
        {{/if}}

        {{#if @model.typeOfGame}}
          <span class="h-3 w-px bg-gray-200 dark:bg-white/10"></span>
          <span class="text-xs text-gray-400 dark:text-slate-500 uppercase">{{@model.typeOfGame}}</span>
        {{/if}}
      </div>

      <div class="flex items-center gap-2">
        {{#if @viewerCount}}
          <div class="flex items-center gap-1.5">
            <svg class="w-3 h-3 text-red-400" fill="currentColor" viewBox="0 0 24 24">
              <path d="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5zM12 17c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3z"/>
            </svg>
            <span class="text-red-400 text-xs font-bold">{{@viewerCount.live}}</span>
            <span class="text-gray-300 dark:text-white/20 text-xs">·</span>
            <span class="text-gray-400 dark:text-slate-500 text-xs">{{@viewerCount.total}}</span>
          </div>
        {{/if}}
        {{#if @model.isStarted}}
          {{#unless @model.isFinished}}
            <span class="text-xs text-gray-400 dark:text-slate-500 uppercase tracking-wider">Inn {{@model.currentInnings}}</span>
          {{/unless}}
        {{/if}}
      </div>
    </div>

    {{! ── Main Score + Live Info ── }}
    <div class="px-4 pt-5 pb-4">

      {{! ════════════════════════════════════════
          CASE A: team1 is batting
          Left = team1 (bat), Right = team2 (bowl)
      ════════════════════════════════════════ }}
      {{#if @model.team1.isBatting}}

        {{! Score header row }}
        <div class="flex items-start gap-3">

          {{! Left — Batting (team1) }}
          <div class="flex-1 min-w-0">
            <div class="flex items-start gap-2.5">
              <div class="relative flex-shrink-0">
                <div class="rounded-xl overflow-hidden border border-gray-200 dark:border-white/10 bg-gray-100 dark:bg-slate-800 flex items-center justify-center w-11 h-11">
                  {{#if @model.team1.logo}}
                    <img src={{@model.team1.logo}} alt={{@model.team1.name}} class="w-full h-full object-cover" />
                  {{else}}
                    <span class="text-gray-400 dark:text-slate-500 font-bold text-base">{{initial @model.team1.name}}</span>
                  {{/if}}
                </div>
                <div class="absolute -bottom-1 -right-1 w-4 h-4 bg-emerald-500 rounded-full border-2 border-white dark:border-slate-900 flex items-center justify-center">
                  <svg viewBox="0 0 256 256" fill="white" class="w-2.5 h-2.5">
                    <path d="M243.31,81.37,190.63,28.69a16,16,0,0,0-22.63,0L60.69,136a16,16,0,0,0,0,22.63l20.68,20.68-47,47a8,8,0,0,0,11.32,11.32l47-47,20.68,20.68a16,16,0,0,0,22.63,0L243.31,104a16,16,0,0,0,0-22.63ZM124.69,200,104,179.31l29.66-29.65a8,8,0,0,0-11.32-11.32L92.69,168,72,147.31,107.31,112H160v52.69ZM232,92.69l-56,56V104a8,8,0,0,0-8-8H123.31l56-56L232,92.68ZM60,88A28,28,0,1,0,32,60,28,28,0,0,0,60,88Zm0-40A12,12,0,1,1,48,60,12,12,0,0,1,60,48Z"/>
                  </svg>
                </div>
              </div>
              <div class="min-w-0 flex-1">
                <p class="text-gray-500 dark:text-slate-400 text-xs truncate mb-1">{{@model.team1.name}}</p>
                <div class="flex items-baseline gap-0.5">
                  <span class="text-gray-900 dark:text-white font-extrabold tracking-tight" class="text-[clamp(1.5rem,4vw,2.2rem)] leading-none">{{@model.team1.score}}</span>
                  <span class="text-gray-500 dark:text-slate-600 text-lg font-light">/{{@model.team1.wickets}}</span>
                </div>
                {{#if @model.isStarted}}
                  {{#if @model.team1.runRate}}
                    <div class="inline-flex items-center gap-1 mt-1">
                      <span class="text-emerald-500 dark:text-emerald-400 text-[10px] sm:text-[11px] font-bold uppercase tracking-wide">CRR</span>
                      <span class="text-emerald-500 dark:text-emerald-400 text-xs font-extrabold">{{@model.team1.runRate}}</span>
                    </div>
                  {{/if}}
                {{/if}}
              </div>
            </div>
          </div>

          {{! Center }}
          <div class="flex-shrink-0 flex flex-col items-center justify-start pt-3 px-1 gap-1">
            {{#if (or @model.isFinished @model.isApproving)}}
              <p class="text-gray-400 dark:text-slate-600 text-[10px] sm:text-xs uppercase tracking-widest">Result</p>
              <p class="text-emerald-600 dark:text-emerald-400 text-xs sm:text-sm font-semibold text-center max-w-[100px]">{{@model.matchSummary}}</p>
              {{#if @manOfTheMatchName}}
                <p class="text-amber-500 text-[11px] font-semibold text-center mt-1">🏅 {{@manOfTheMatchName}}</p>
              {{/if}}
            {{else if @model.matchSummary}}
              <p class="text-gray-400 dark:text-slate-600 text-[10px] sm:text-xs uppercase tracking-widest">Need</p>
              <p class="text-amber-500 dark:text-amber-400 text-lg font-extrabold leading-none">{{@model.runsNeeded}}</p>
              <p class="text-gray-400 dark:text-slate-600 text-[10px]">{{@model.ballsRemaining}}b</p>
              <div class="w-6 h-px bg-gray-200 dark:bg-white/5 my-0.5"></div>
              <p class="text-gray-400 dark:text-slate-600 text-[10px] uppercase">RRR</p>
              <p class="text-rose-500 dark:text-rose-400 text-sm font-extrabold leading-none">{{@model.requiredRunRate}}</p>
            {{else}}
              <span class="text-gray-400 dark:text-slate-600 text-xs sm:text-sm font-bold uppercase">vs</span>
            {{/if}}
          </div>

          {{! Right — Bowling (team2) }}
          <div class="flex-1 min-w-0">
            <div class="flex items-start gap-2.5">
              <div class="min-w-0 flex-1 text-right">
                <p class="text-gray-500 dark:text-slate-400 text-xs truncate mb-1">{{@model.team2.name}}</p>
                {{#if (or @model.isFinished @model.isApproving)}}
                  <div class="flex items-baseline gap-0.5 justify-end">
                    <span class="text-gray-900 dark:text-white font-extrabold tracking-tight" class="text-[clamp(1.5rem,4vw,2.2rem)] leading-none">{{@model.team2.score}}</span>
                    <span class="text-gray-500 dark:text-slate-600 text-lg font-light">/{{@model.team2.wickets}}</span>
                  </div>
                {{else if @model.isStarted}}
                  <div class="flex items-baseline gap-0.5 justify-end">
                    <span class="text-gray-900 dark:text-white font-extrabold tracking-tight" class="text-[clamp(1.5rem,4vw,2.2rem)] leading-none">{{@model.team2.bowlingSummary.oversBowled}}</span>
                    <span class="text-gray-500 dark:text-slate-500 text-sm font-medium ml-1">ov</span>
                  </div>
                {{else}}
                  <div class="flex items-baseline gap-0.5 justify-end">
                    <span class="text-gray-400 dark:text-slate-600 text-3xl font-extrabold leading-none">00</span>
                  </div>
                {{/if}}
              </div>
              <div class="flex-shrink-0 relative">
                <div class="rounded-xl overflow-hidden border border-gray-200 dark:border-white/10 bg-gray-100 dark:bg-slate-800 flex items-center justify-center w-11 h-11">
                  {{#if @model.team2.logo}}
                    <img src={{@model.team2.logo}} alt={{@model.team2.name}} class="w-full h-full object-cover" />
                  {{else}}
                    <span class="text-gray-400 dark:text-slate-500 font-bold text-base">{{initial @model.team2.name}}</span>
                  {{/if}}
                </div>
                {{#if @model.isStarted}}
                  <div class="absolute -bottom-1 -left-1 w-4 h-4 bg-rose-500 rounded-full border-2 border-white dark:border-slate-900 flex items-center justify-center">
                    <svg viewBox="0 0 256 256" fill="white" class="w-2.5 h-2.5">
                      <path d="M128,24A104,104,0,1,0,232,128,104.11,104.11,0,0,0,128,24ZM72.09,195.91c.82-1,1.64-1.93,2.42-2.91A8,8,0,1,0,62,183l-1.34,1.62a87.82,87.82,0,0,1,0-113.24L62,73A8,8,0,1,0,74.51,63c-.78-1-1.6-2-2.42-2.91a87.84,87.84,0,0,1,111.82,0c-.82,1-1.64,1.92-2.42,2.91A8,8,0,1,0,194,73l1.34-1.62a87.82,87.82,0,0,1,0,113.24L194,183a8,8,0,1,0-12.48,10c.78,1,1.6,1.95,2.42,2.91a87.84,87.84,0,0,1-111.82,0Zm23.8-50.59a104.5,104.5,0,0,1-4.48,17.35,8,8,0,0,1-15.09-5.34,87.1,87.1,0,0,0,3.79-14.65,8,8,0,1,1,15.78,2.64Zm0-34.64a8,8,0,0,1-6.57,9.21A8.52,8.52,0,0,1,88,120a8,8,0,0,1-7.88-6.68,87.1,87.1,0,0,0-3.79-14.65,8,8,0,0,1,15.09-5.34A104.5,104.5,0,0,1,95.89,110.68Zm78.91,56.86a8,8,0,0,1-10.21-4.87,104.5,104.5,0,0,1-4.48-17.35,8,8,0,1,1,15.78-2.64,87.1,87.1,0,0,0,3.79,14.65A8,8,0,0,1,174.8,167.54Zm-14.69-56.86a104.5,104.5,0,0,1,4.48-17.35,8,8,0,0,1,15.09,5.34,87.1,87.1,0,0,0-3.79,14.65A8,8,0,0,1,168,120a8.52,8.52,0,0,1-1.33-.11A8,8,0,0,1,160.11,110.68Z"/>
                    </svg>
                  </div>
                {{/if}}
              </div>
            </div>
          </div>

        </div>

        {{! Details row — batsmen & bowler side by side }}
        {{#if @model.isStarted}}{{#unless @model.isFinished}}
          <div class="mt-3 pt-2.5 border-t border-gray-100 dark:border-white/5 flex gap-3">

            {{! Batsmen (left) }}
            <div class="flex-1 min-w-0">
              {{#if @model.currentBatsmen.length}}
                <p class="text-[10px] sm:text-xs font-bold uppercase tracking-widest text-emerald-500 dark:text-emerald-400 mb-2">Batting</p>
                <div class="space-y-1.5">
                  {{#each @model.currentBatsmen as |b|}}
                    <div class="flex items-center justify-between gap-2">
                      <div class="flex items-center gap-1.5 min-w-0">
                        {{#if b.isStriker}}
                          <svg class="w-3.5 h-3.5 flex-shrink-0 text-emerald-500" viewBox="0 0 256 256" fill="currentColor">
                            <path d="M243.31,81.37,190.63,28.69a16,16,0,0,0-22.63,0L60.69,136a16,16,0,0,0,0,22.63l20.68,20.68-47,47a8,8,0,0,0,11.32,11.32l47-47,20.68,20.68a16,16,0,0,0,22.63,0L243.31,104a16,16,0,0,0,0-22.63ZM124.69,200,104,179.31l29.66-29.65a8,8,0,0,0-11.32-11.32L92.69,168,72,147.31,107.31,112H160v52.69ZM232,92.69l-56,56V104a8,8,0,0,0-8-8H123.31l56-56L232,92.68ZM60,88A28,28,0,1,0,32,60,28,28,0,0,0,60,88Zm0-40A12,12,0,1,1,48,60,12,12,0,0,1,60,48Z"/>
                          </svg>
                        {{else}}
                          <span class="w-3.5 h-3.5 flex-shrink-0"></span>
                        {{/if}}
                        <span class="text-gray-700 dark:text-slate-300 text-xs sm:text-[13px] font-medium truncate">{{b.fullName}}</span>
                      </div>
                      <div class="flex items-center gap-2 flex-shrink-0">
                        <span class="text-emerald-500 dark:text-emerald-400 text-xs font-bold">{{b.runs}}<span class="text-gray-400 dark:text-slate-500 font-normal">({{b.balls}})</span></span>
                        {{#if b.strikeRate}}<span class="text-gray-400 dark:text-slate-500 text-[11px]">SR <span class="text-gray-600 dark:text-slate-400">{{b.strikeRate}}</span></span>{{/if}}
                        {{#if b.fours}}<span class="text-gray-400 dark:text-slate-500 text-[11px]">4s <span class="text-amber-500 dark:text-amber-400">{{b.fours}}</span></span>{{/if}}
                        {{#if b.sixes}}<span class="text-gray-400 dark:text-slate-500 text-[11px]">6s <span class="text-purple-500 dark:text-purple-400">{{b.sixes}}</span></span>{{/if}}
                      </div>
                    </div>
                  {{/each}}
                </div>
              {{/if}}
            </div>

            {{! Bowler (right) }}
            <div class="flex-1 min-w-0">
              {{#if @model.currentBowler}}
                <p class="text-[10px] sm:text-xs font-bold uppercase tracking-widest text-blue-500 dark:text-blue-400 mb-2 text-right">Bowling</p>
                <div class="flex items-center justify-between gap-2">
                  <div class="flex items-center gap-1.5 min-w-0">
                    <svg class="w-3.5 h-3.5 flex-shrink-0 text-rose-500" viewBox="0 0 256 256" fill="currentColor">
                      <path d="M128,24A104,104,0,1,0,232,128,104.11,104.11,0,0,0,128,24ZM72.09,195.91c.82-1,1.64-1.93,2.42-2.91A8,8,0,1,0,62,183l-1.34,1.62a87.82,87.82,0,0,1,0-113.24L62,73A8,8,0,1,0,74.51,63c-.78-1-1.6-2-2.42-2.91a87.84,87.84,0,0,1,111.82,0c-.82,1-1.64,1.92-2.42,2.91A8,8,0,1,0,194,73l1.34-1.62a87.82,87.82,0,0,1,0,113.24L194,183a8,8,0,1,0-12.48,10c.78,1,1.6,1.95,2.42,2.91a87.84,87.84,0,0,1-111.82,0Zm23.8-50.59a104.5,104.5,0,0,1-4.48,17.35,8,8,0,0,1-15.09-5.34,87.1,87.1,0,0,0,3.79-14.65,8,8,0,1,1,15.78,2.64Zm0-34.64a8,8,0,0,1-6.57,9.21A8.52,8.52,0,0,1,88,120a8,8,0,0,1-7.88-6.68,87.1,87.1,0,0,0-3.79-14.65,8,8,0,0,1,15.09-5.34A104.5,104.5,0,0,1,95.89,110.68Zm78.91,56.86a8,8,0,0,1-10.21-4.87,104.5,104.5,0,0,1-4.48-17.35,8,8,0,1,1,15.78-2.64,87.1,87.1,0,0,0,3.79,14.65A8,8,0,0,1,174.8,167.54Zm-14.69-56.86a104.5,104.5,0,0,1,4.48-17.35,8,8,0,0,1,15.09,5.34,87.1,87.1,0,0,0-3.79,14.65A8,8,0,0,1,168,120a8.52,8.52,0,0,1-1.33-.11A8,8,0,0,1,160.11,110.68Z"/>
                    </svg>
                    <span class="text-gray-700 dark:text-slate-300 text-xs sm:text-[13px] font-medium truncate">{{@model.currentBowler.fullName}}</span>
                  </div>
                  <div class="flex items-center gap-2 flex-shrink-0">
                    <span class="text-blue-500 dark:text-blue-400 text-xs font-bold">{{@model.currentBowler.wickets}}/{{@model.currentBowler.runs}}<span class="text-gray-400 dark:text-slate-500 font-normal">({{@model.currentBowler.overs}})</span></span>
                    {{#if @model.currentBowler.economy}}<span class="text-gray-400 dark:text-slate-500 text-[11px]">Econ <span class="text-gray-600 dark:text-slate-400">{{@model.currentBowler.economy}}</span></span>{{/if}}
                    {{#if @model.currentBowler.maidens}}<span class="text-gray-400 dark:text-slate-500 text-[11px]">M <span class="text-cyan-500 dark:text-cyan-400">{{@model.currentBowler.maidens}}</span></span>{{/if}}
                    {{#if @model.currentBowler.wides}}<span class="text-gray-400 dark:text-slate-500 text-[11px]">Wd <span class="text-yellow-500 dark:text-yellow-400">{{@model.currentBowler.wides}}</span></span>{{/if}}
                    {{#if @model.currentBowler.noBalls}}<span class="text-gray-400 dark:text-slate-500 text-[11px]">Nb <span class="text-orange-500 dark:text-orange-400">{{@model.currentBowler.noBalls}}</span></span>{{/if}}
                  </div>
                </div>
              {{/if}}
            </div>

          </div>
        {{/unless}}{{/if}}

      {{! ════════════════════════════════════════
          CASE B: team2 is batting (live) OR upcoming/finished
          Live:     Left = team2 (bat), Right = team1 (bowl)
          Upcoming: Left = team1,       Right = team2
      ════════════════════════════════════════ }}
      {{else}}

        {{! Score header row }}
        <div class="flex items-start gap-3">

          {{! Left — team2 if live-batting, otherwise team1 }}
          <div class="flex-1 min-w-0">
            <div class="flex items-start gap-2.5">
              <div class="relative flex-shrink-0">
                <div class="rounded-xl overflow-hidden border border-gray-200 dark:border-white/10 bg-gray-100 dark:bg-slate-800 flex items-center justify-center w-11 h-11">
                  {{#if @model.isStarted}}
                    {{#if @model.team2.logo}}
                      <img src={{@model.team2.logo}} alt={{@model.team2.name}} class="w-full h-full object-cover" />
                    {{else}}
                      <span class="text-gray-400 dark:text-slate-500 font-bold text-base">{{initial @model.team2.name}}</span>
                    {{/if}}
                  {{else}}
                    {{#if @model.team1.logo}}
                      <img src={{@model.team1.logo}} alt={{@model.team1.name}} class="w-full h-full object-cover" />
                    {{else}}
                      <span class="text-gray-400 dark:text-slate-500 font-bold text-base">{{initial @model.team1.name}}</span>
                    {{/if}}
                  {{/if}}
                </div>
                {{#if @model.team2.isBatting}}
                  <div class="absolute -bottom-1 -right-1 w-4 h-4 bg-emerald-500 rounded-full border-2 border-white dark:border-slate-900 flex items-center justify-center">
                    <svg viewBox="0 0 10 10" fill="white" class="w-2 h-2">
                      <path d="M1 9.5 L7.5 0.5 L9.5 2.5 L3 11.5 Z" transform="translate(0,-1)"/>
                      <path d="M7 0 L10 3 L8.5 4.5 L5.5 1.5 Z"/>
                    </svg>
                  </div>
                {{/if}}
              </div>
              <div class="min-w-0 flex-1">
                <p class="text-gray-500 dark:text-slate-400 text-xs truncate mb-1">{{if @model.isStarted @model.team2.name @model.team1.name}}</p>
                {{#if (or @model.isStarted @model.isApproving)}}
                  <div class="flex items-baseline gap-0.5">
                    <span class="text-gray-900 dark:text-white font-extrabold tracking-tight text-[clamp(1.5rem,4vw,2.2rem)] leading-none">{{@model.team2.score}}</span>
                    <span class="text-gray-500 dark:text-slate-600 text-lg font-light">/{{@model.team2.wickets}}</span>
                  </div>
                {{else}}
                  <span class="text-gray-400 dark:text-slate-600 text-3xl font-extrabold leading-none">00</span>
                {{/if}}
                {{#if @model.isStarted}}
                  {{#if @model.team2.runRate}}
                    <div class="inline-flex items-center gap-1 mt-1">
                      <span class="text-emerald-500 dark:text-emerald-400 text-[10px] sm:text-[11px] font-bold uppercase tracking-wide">CRR</span>
                      <span class="text-emerald-500 dark:text-emerald-400 text-xs font-extrabold">{{@model.team2.runRate}}</span>
                    </div>
                  {{/if}}
                {{/if}}
              </div>
            </div>
          </div>

          {{! Center }}
          <div class="flex-shrink-0 flex flex-col items-center justify-start pt-3 px-1 gap-1">
            {{#if (or @model.isFinished @model.isApproving)}}
              <p class="text-gray-400 dark:text-slate-600 text-[10px] sm:text-xs uppercase tracking-widest">Result</p>
              <p class="text-emerald-600 dark:text-emerald-400 text-xs sm:text-sm font-semibold text-center max-w-[100px]">{{@model.matchSummary}}</p>
              {{#if @manOfTheMatchName}}
                <p class="text-amber-500 text-[11px] font-semibold text-center mt-1">🏅 {{@manOfTheMatchName}}</p>
              {{/if}}
            {{else if @model.matchSummary}}
              <p class="text-gray-400 dark:text-slate-600 text-[10px] sm:text-xs uppercase tracking-widest">Need</p>
              <p class="text-amber-500 dark:text-amber-400 text-lg font-extrabold leading-none">{{@model.runsNeeded}}</p>
              <p class="text-gray-400 dark:text-slate-600 text-[10px]">{{@model.ballsRemaining}}b</p>
              <div class="w-6 h-px bg-gray-200 dark:bg-white/5 my-0.5"></div>
              <p class="text-gray-400 dark:text-slate-600 text-[10px] uppercase">RRR</p>
              <p class="text-rose-500 dark:text-rose-400 text-sm font-extrabold leading-none">{{@model.requiredRunRate}}</p>
            {{else}}
              <span class="text-gray-400 dark:text-slate-600 text-xs sm:text-sm font-bold uppercase">vs</span>
            {{/if}}
          </div>

          {{! Right — team1 if live-bowling, otherwise team2 }}
          <div class="flex-1 min-w-0">
            <div class="flex items-start gap-2.5">
              <div class="min-w-0 flex-1 text-right">
                <p class="text-gray-500 dark:text-slate-400 text-xs truncate mb-1">{{if @model.isStarted @model.team1.name @model.team2.name}}</p>
                {{#if (or @model.isFinished @model.isApproving)}}
                  <div class="flex items-baseline gap-0.5 justify-end">
                    <span class="text-gray-900 dark:text-white font-extrabold tracking-tight text-[clamp(1.5rem,4vw,2.2rem)] leading-none">{{@model.team1.score}}</span>
                    <span class="text-gray-500 dark:text-slate-600 text-lg font-light">/{{@model.team1.wickets}}</span>
                  </div>
                {{else if @model.isStarted}}
                  <div class="flex items-baseline gap-0.5 justify-end">
                    <span class="text-gray-900 dark:text-white font-extrabold tracking-tight text-[clamp(1.5rem,4vw,2.2rem)] leading-none">{{@model.team1.bowlingSummary.oversBowled}}</span>
                    <span class="text-gray-500 dark:text-slate-500 text-sm font-medium ml-1">ov</span>
                  </div>
                {{else}}
                  <div class="flex items-baseline gap-0.5 justify-end">
                    <span class="text-gray-400 dark:text-slate-600 text-3xl font-extrabold leading-none">00</span>
                  </div>
                {{/if}}
              </div>
              <div class="flex-shrink-0 relative">
                <div class="rounded-xl overflow-hidden border border-gray-200 dark:border-white/10 bg-gray-100 dark:bg-slate-800 flex items-center justify-center w-11 h-11">
                  {{#if @model.isStarted}}
                    {{#if @model.team1.logo}}
                      <img src={{@model.team1.logo}} alt={{@model.team1.name}} class="w-full h-full object-cover" />
                    {{else}}
                      <span class="text-gray-400 dark:text-slate-500 font-bold text-base">{{initial @model.team1.name}}</span>
                    {{/if}}
                  {{else}}
                    {{#if @model.team2.logo}}
                      <img src={{@model.team2.logo}} alt={{@model.team2.name}} class="w-full h-full object-cover" />
                    {{else}}
                      <span class="text-gray-400 dark:text-slate-500 font-bold text-base">{{initial @model.team2.name}}</span>
                    {{/if}}
                  {{/if}}
                </div>
                {{#if @model.isStarted}}
                  <div class="absolute -bottom-1 -left-1 w-4 h-4 bg-rose-500 rounded-full border-2 border-white dark:border-slate-900 flex items-center justify-center">
                    <svg viewBox="0 0 256 256" fill="white" class="w-2.5 h-2.5">
                      <path d="M128,24A104,104,0,1,0,232,128,104.11,104.11,0,0,0,128,24ZM72.09,195.91c.82-1,1.64-1.93,2.42-2.91A8,8,0,1,0,62,183l-1.34,1.62a87.82,87.82,0,0,1,0-113.24L62,73A8,8,0,1,0,74.51,63c-.78-1-1.6-2-2.42-2.91a87.84,87.84,0,0,1,111.82,0c-.82,1-1.64,1.92-2.42,2.91A8,8,0,1,0,194,73l1.34-1.62a87.82,87.82,0,0,1,0,113.24L194,183a8,8,0,1,0-12.48,10c.78,1,1.6,1.95,2.42,2.91a87.84,87.84,0,0,1-111.82,0Zm23.8-50.59a104.5,104.5,0,0,1-4.48,17.35,8,8,0,0,1-15.09-5.34,87.1,87.1,0,0,0,3.79-14.65,8,8,0,1,1,15.78,2.64Zm0-34.64a8,8,0,0,1-6.57,9.21A8.52,8.52,0,0,1,88,120a8,8,0,0,1-7.88-6.68,87.1,87.1,0,0,0-3.79-14.65,8,8,0,0,1,15.09-5.34A104.5,104.5,0,0,1,95.89,110.68Zm78.91,56.86a8,8,0,0,1-10.21-4.87,104.5,104.5,0,0,1-4.48-17.35,8,8,0,1,1,15.78-2.64,87.1,87.1,0,0,0,3.79,14.65A8,8,0,0,1,174.8,167.54Zm-14.69-56.86a104.5,104.5,0,0,1,4.48-17.35,8,8,0,0,1,15.09,5.34,87.1,87.1,0,0,0-3.79,14.65A8,8,0,0,1,168,120a8.52,8.52,0,0,1-1.33-.11A8,8,0,0,1,160.11,110.68Z"/>
                    </svg>
                  </div>
                {{/if}}
              </div>
            </div>
          </div>

        </div>

        {{! Details row — batsmen & bowler side by side }}
        {{#if @model.isStarted}}{{#unless @model.isFinished}}
          <div class="mt-3 pt-2.5 border-t border-gray-100 dark:border-white/5 flex gap-3">

            {{! Batsmen (left) }}
            <div class="flex-1 min-w-0">
              {{#if @model.currentBatsmen.length}}
                <p class="text-[10px] sm:text-xs font-bold uppercase tracking-widest text-emerald-500 dark:text-emerald-400 mb-2">Batting</p>
                <div class="space-y-1.5">
                  {{#each @model.currentBatsmen as |b|}}
                    <div class="flex items-center justify-between gap-2">
                      <div class="flex items-center gap-1.5 min-w-0">
                        {{#if b.isStriker}}
                          <svg class="w-3.5 h-3.5 flex-shrink-0 text-emerald-500" viewBox="0 0 256 256" fill="currentColor">
                            <path d="M243.31,81.37,190.63,28.69a16,16,0,0,0-22.63,0L60.69,136a16,16,0,0,0,0,22.63l20.68,20.68-47,47a8,8,0,0,0,11.32,11.32l47-47,20.68,20.68a16,16,0,0,0,22.63,0L243.31,104a16,16,0,0,0,0-22.63ZM124.69,200,104,179.31l29.66-29.65a8,8,0,0,0-11.32-11.32L92.69,168,72,147.31,107.31,112H160v52.69ZM232,92.69l-56,56V104a8,8,0,0,0-8-8H123.31l56-56L232,92.68ZM60,88A28,28,0,1,0,32,60,28,28,0,0,0,60,88Zm0-40A12,12,0,1,1,48,60,12,12,0,0,1,60,48Z"/>
                          </svg>
                        {{else}}
                          <span class="w-3.5 h-3.5 flex-shrink-0"></span>
                        {{/if}}
                        <span class="text-gray-700 dark:text-slate-300 text-xs sm:text-[13px] font-medium truncate">{{b.fullName}}</span>
                      </div>
                      <div class="flex items-center gap-2 flex-shrink-0">
                        <span class="text-emerald-500 dark:text-emerald-400 text-xs font-bold">{{b.runs}}<span class="text-gray-400 dark:text-slate-500 font-normal">({{b.balls}})</span></span>
                        {{#if b.strikeRate}}<span class="text-gray-400 dark:text-slate-500 text-[11px]">SR <span class="text-gray-600 dark:text-slate-400">{{b.strikeRate}}</span></span>{{/if}}
                        {{#if b.fours}}<span class="text-gray-400 dark:text-slate-500 text-[11px]">4s <span class="text-amber-500 dark:text-amber-400">{{b.fours}}</span></span>{{/if}}
                        {{#if b.sixes}}<span class="text-gray-400 dark:text-slate-500 text-[11px]">6s <span class="text-purple-500 dark:text-purple-400">{{b.sixes}}</span></span>{{/if}}
                      </div>
                    </div>
                  {{/each}}
                </div>
              {{/if}}
            </div>

            {{! Bowler (right) }}
            <div class="flex-1 min-w-0">
              {{#if @model.currentBowler}}
                <p class="text-[10px] sm:text-xs font-bold uppercase tracking-widest text-blue-500 dark:text-blue-400 mb-2 text-right">Bowling</p>
                <div class="flex items-center justify-between gap-2">
                  <div class="flex items-center gap-1.5 min-w-0">
                    <svg class="w-3.5 h-3.5 flex-shrink-0 text-rose-500" viewBox="0 0 256 256" fill="currentColor">
                      <path d="M128,24A104,104,0,1,0,232,128,104.11,104.11,0,0,0,128,24ZM72.09,195.91c.82-1,1.64-1.93,2.42-2.91A8,8,0,1,0,62,183l-1.34,1.62a87.82,87.82,0,0,1,0-113.24L62,73A8,8,0,1,0,74.51,63c-.78-1-1.6-2-2.42-2.91a87.84,87.84,0,0,1,111.82,0c-.82,1-1.64,1.92-2.42,2.91A8,8,0,1,0,194,73l1.34-1.62a87.82,87.82,0,0,1,0,113.24L194,183a8,8,0,1,0-12.48,10c.78,1,1.6,1.95,2.42,2.91a87.84,87.84,0,0,1-111.82,0Zm23.8-50.59a104.5,104.5,0,0,1-4.48,17.35,8,8,0,0,1-15.09-5.34,87.1,87.1,0,0,0,3.79-14.65,8,8,0,1,1,15.78,2.64Zm0-34.64a8,8,0,0,1-6.57,9.21A8.52,8.52,0,0,1,88,120a8,8,0,0,1-7.88-6.68,87.1,87.1,0,0,0-3.79-14.65,8,8,0,0,1,15.09-5.34A104.5,104.5,0,0,1,95.89,110.68Zm78.91,56.86a8,8,0,0,1-10.21-4.87,104.5,104.5,0,0,1-4.48-17.35,8,8,0,1,1,15.78-2.64,87.1,87.1,0,0,0,3.79,14.65A8,8,0,0,1,174.8,167.54Zm-14.69-56.86a104.5,104.5,0,0,1,4.48-17.35,8,8,0,0,1,15.09,5.34,87.1,87.1,0,0,0-3.79,14.65A8,8,0,0,1,168,120a8.52,8.52,0,0,1-1.33-.11A8,8,0,0,1,160.11,110.68Z"/>
                    </svg>
                    <span class="text-gray-700 dark:text-slate-300 text-xs sm:text-[13px] font-medium truncate">{{@model.currentBowler.fullName}}</span>
                  </div>
                  <div class="flex items-center gap-2 flex-shrink-0">
                    <span class="text-blue-500 dark:text-blue-400 text-xs font-bold">{{@model.currentBowler.wickets}}/{{@model.currentBowler.runs}}<span class="text-gray-400 dark:text-slate-500 font-normal">({{@model.currentBowler.overs}})</span></span>
                    {{#if @model.currentBowler.economy}}<span class="text-gray-400 dark:text-slate-500 text-[11px]">Econ <span class="text-gray-600 dark:text-slate-400">{{@model.currentBowler.economy}}</span></span>{{/if}}
                    {{#if @model.currentBowler.maidens}}<span class="text-gray-400 dark:text-slate-500 text-[11px]">M <span class="text-cyan-500 dark:text-cyan-400">{{@model.currentBowler.maidens}}</span></span>{{/if}}
                    {{#if @model.currentBowler.wides}}<span class="text-gray-400 dark:text-slate-500 text-[11px]">Wd <span class="text-yellow-500 dark:text-yellow-400">{{@model.currentBowler.wides}}</span></span>{{/if}}
                    {{#if @model.currentBowler.noBalls}}<span class="text-gray-400 dark:text-slate-500 text-[11px]">Nb <span class="text-orange-500 dark:text-orange-400">{{@model.currentBowler.noBalls}}</span></span>{{/if}}
                  </div>
                </div>
              {{/if}}
            </div>

          </div>
        {{/unless}}{{/if}}

      {{/if}}
      {{! end team1/team2 batting switch }}

      {{! ── Ball-by-ball current over ── }}
      {{#if @model.currentOverBalls.length}}
        <div class="mt-3 pt-2.5 border-t border-gray-100 dark:border-white/5 flex items-center gap-1.5">
          <span class="text-[11px] font-bold uppercase tracking-widest text-gray-400 dark:text-slate-500 flex-shrink-0">This Over</span>
          {{#each (recentBalls @model.currentOverBalls) as |ball|}}
            <span class="inline-flex items-center justify-center w-5 h-5 rounded-full text-[9px] font-bold flex-shrink-0 {{ballBg ball}}">
              {{ballDisplay ball}}
            </span>
          {{/each}}
        </div>
      {{/if}}

    </div>
  </div>
</template>
