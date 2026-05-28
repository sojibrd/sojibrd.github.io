import TeamItem from './team-item';

<template>
  <div
    class="grid grid-cols-1 gap-6 p-4 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 sm:p-6"
  >
    {{#each @items as |item|}}
      <TeamItem @team={{item}} @onEdit={{@onEdit}} @onDelete={{@onDelete}} />
    {{else}}
      <p class="col-span-full py-16 text-center text-lg text-gray-500 dark:text-gray-400">No teams
        to display.</p>
    {{/each}}
  </div>
</template>
