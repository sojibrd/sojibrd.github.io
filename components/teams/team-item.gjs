import { LinkTo } from '@ember/routing';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import getTeamLogo from 'spordium/helpers/append-bucket';

<template>
  <LinkTo @route="teams.team-details" @model={{@team.id}} class="block group">
    <div
      class="bg-white dark:bg-gray-900 rounded-xl shadow-lg dark:shadow-gray-900/50 overflow-hidden transition-all duration-300 ease-in-out hover:shadow-2xl hover:-translate-y-1 flex flex-col border border-transparent dark:border-gray-800"
      data-test-team-item={{@team.id}}
    >
      {{! Card Header with Logo }}
      <div class="h-40 bg-gray-100 dark:bg-gray-800 flex items-center justify-center p-4">
        {{#if @team.team_logo}}
          <img
            src={{getTeamLogo @team.team_logo}}
            alt="Logo for {{@team.team_name}}"
            class="h-28 w-28 object-contain group-hover:scale-105 transition-transform duration-300"
            loading="lazy"
          />
        {{else}}
          <div
            class="h-28 w-28 rounded-full bg-gray-200 dark:bg-gray-700 flex items-center justify-center text-center p-2"
          >
            <span class="text-xl font-bold text-gray-500 dark:text-gray-300">{{@team.team_name}}</span>
          </div>
        {{/if}}
      </div>

      {{! Card Body with Team Info }}
      <div class="p-4 text-center">
        <h3
          class="font-bold text-xl text-gray-800 dark:text-white truncate"
          title={{@team.team_name}}
        >
          {{@team.team_name}}
        </h3>
        {{#if @team.game_name}}
          <p class="text-sm text-gray-500 dark:text-gray-400 capitalize">{{@team.game_name}}</p>
        {{/if}}
      </div>

      {{! Card Footer with Actions }}
      <div
        class="mt-auto p-4 border-t border-gray-100 dark:border-gray-700 flex justify-center space-x-3"
      >
        <LinkTo @route="teams.team" @model={{@team.id}} class="block group">
          <button
            type="button"
            class="px-4 py-2 text-sm font-medium rounded-lg transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2 dark:focus:ring-offset-gray-900 text-indigo-700 dark:text-indigo-300 bg-indigo-100 dark:bg-indigo-900/40 hover:bg-indigo-200 dark:hover:bg-indigo-900/70 focus:ring-indigo-500"
          >
            Edit
          </button>
        </LinkTo>
        <button
          type="button"
          class="px-4 py-2 text-sm font-medium rounded-lg transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2 dark:focus:ring-offset-gray-900 text-red-700 dark:text-red-400 bg-red-100 dark:bg-red-900/30 hover:bg-red-200 dark:hover:bg-red-900/60 focus:ring-red-500"
          {{on "click" (fn @onDelete @team)}}
        >
          Delete
        </button>
      </div>
    </div>
  </LinkTo>
</template>
