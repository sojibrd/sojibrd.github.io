<template>
  <div class="space-y-4">
    <div class="bg-white dark:bg-gray-900 rounded-2xl border border-gray-200 dark:border-gray-700 p-5">
      <h3 class="text-sm font-bold text-gray-900 dark:text-white mb-2">About Tournament</h3>
      <p class="text-sm text-gray-600 dark:text-gray-300 leading-relaxed">ID: {{@tOne.tournament_id}}</p>

      <p class="text-sm text-gray-600 dark:text-gray-300 leading-relaxed">Season: {{@season}}</p>
    </div>

    <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
      <div class="bg-white dark:bg-gray-900 rounded-2xl border border-gray-200 dark:border-gray-700 p-4 text-center">
        <p class="text-2xl font-black text-gray-900 dark:text-white">{{@maxTeams}}</p>
        <p class="text-xs text-gray-500 mt-0.5">Teams</p>
      </div>

      {{#if @tournamentType}}
        <div class="bg-white dark:bg-gray-900 rounded-2xl border border-gray-200 dark:border-gray-700 p-4 text-center">
          <p class="text-sm font-bold text-gray-900 dark:text-white capitalize">{{@tournamentType}}</p>
          <p class="text-xs text-gray-500 mt-0.5">Type</p>
        </div>
      {{/if}}

      {{#if @prizePool}}
        <div
          class="bg-yellow-50 dark:bg-yellow-900/20 rounded-2xl border border-yellow-200 dark:border-yellow-800 p-4 text-center"
        >
          <p class="text-sm font-black text-yellow-700 dark:text-yellow-400">{{@prizePool}}</p>
          <p class="text-xs text-yellow-600 dark:text-yellow-500 mt-0.5">Prize Pool</p>
        </div>
      {{/if}}

    </div>
  </div>
</template>
