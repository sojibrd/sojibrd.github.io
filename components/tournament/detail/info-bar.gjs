import lucideIcon from 'spordium/helpers/lucide-icon';
import { array, concat } from '@ember/helper';

<template>
  {{! ── Info bar ─────────────────────────────────────────────────── }}
  <div class="max-w-5xl mx-auto px-4 sm:px-6 py-5">
    <div class="flex items-start gap-4">
      <div class="flex-1 min-w-0">
        <div class="flex flex-wrap items-center gap-2 mb-1">
          {{#if @tOne.tournament_sport}}
            <span
              class="px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide rounded-full bg-blue-100 dark:bg-blue-900/40 text-blue-600 dark:text-blue-400"
            >
              {{@sportLabel}}
            </span>
          {{/if}}
          {{#if @statusLabel}}
            <span
              class="px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide rounded-full bg-green-100 dark:bg-green-900/40 text-green-600 dark:text-green-400"
            >
              {{@statusLabel}}
            </span>
          {{/if}}
        </div>

        <h1 class="text-xl font-extrabold text-gray-900 dark:text-white leading-tight">
          {{@tOne.tournament_name}}
        </h1>

        <div class="flex flex-wrap items-center gap-4 mt-2 text-xs text-gray-500 dark:text-gray-400">
          <span class="flex items-center gap-1">
            {{lucideIcon "calendar" class="w-3.5 h-3.5"}}
            {{@startDate}}
            –
            {{@endDate}}
          </span>
          <span class="flex items-center gap-1">
            {{lucideIcon "map-pin" class="w-3.5 h-3.5"}}
            {{@city}}
            {{if @country (concat ", " @country) ""}}
          </span>
          <span class="flex items-center gap-1">
            {{lucideIcon "users" class="w-3.5 h-3.5"}}
            {{@totalTeams}}/{{@maxTeams}}
            teams
          </span>
          {{#if @prizePool}}
            <span class="flex items-center gap-1 font-semibold text-yellow-600 dark:text-yellow-400">
              {{lucideIcon "trophy" class="w-3.5 h-3.5"}}
              {{@prizePool}}
            </span>
          {{/if}}
        </div>
      </div>
    </div>
  </div>
</template>
