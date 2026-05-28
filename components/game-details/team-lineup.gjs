import PlayerCard from './player-card';
import { helper } from '@ember/component/helper';
import { LinkTo } from '@ember/routing';

const addOne = helper(function ([index]) {
  return index + 1;
});

<template>
  <div class="bg-white dark:bg-slate-800 rounded-2xl p-4 lg:p-5 shadow-lg border border-gray-200 dark:border-slate-700/50">
    {{! Team Header }}
    <LinkTo
      @route="teams.team-details"
      @model={{@team.id}}
      class="flex items-center gap-3 lg:gap-4 mb-4 pb-4 border-b border-gray-200 dark:border-slate-700/50
             hover:opacity-80 transition-opacity cursor-pointer"
    >
      <div class="w-14 h-14 lg:w-16 lg:h-16 rounded-xl overflow-hidden bg-white p-1.5 lg:p-2 flex-shrink-0 shadow-lg border border-gray-200 dark:border-transparent">
        <img src={{@team.logo}} alt={{@team.name}} class="w-full h-full object-contain" />
      </div>
      <div class="min-w-0 flex-1">
        <h3 class="text-gray-900 dark:text-white font-bold text-base lg:text-lg truncate">{{@team.name}}</h3>
      </div>
    </LinkTo>

    {{! Players List }}
    <div class="space-y-3">
      {{#each @team.players as |player index|}}
        <PlayerCard @player={{player}} @index={{addOne index}} />
      {{/each}}
    </div>
  </div>
</template>
