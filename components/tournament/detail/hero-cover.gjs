import lucideIcon from 'spordium/helpers/lucide-icon';
import { LinkTo } from '@ember/routing';

<template>
  {{! ── Hero cover ───────────────────────────────────────────────── }}
  <div class="relative">
    <div class="h-56 sm:h-72 overflow-hidden bg-gray-200 dark:bg-gray-700">
      <img src={{@coverUrl}} alt={{@tOne.tournament_name}} class="w-full h-full object-cover" />
      <div class="absolute inset-0 bg-gradient-to-t from-black/60 via-black/20 to-transparent"></div>
    </div>

    {{! Back button }}
    <div class="absolute top-4 left-4">
      <LinkTo
        @route="tournament.index"
        class="p-2 rounded-xl bg-black/30 backdrop-blur-sm hover:bg-black/50 transition-colors"
      >
        {{lucideIcon "arrow-left" class="w-4 h-4 text-white"}}
      </LinkTo>
    </div>

    {{! Edit button (organizer only) }}
    {{#if @isOrganizer}}
      <div class="absolute top-4 right-4">
        {{!-- <LinkTo
          @route="tournament.create"
          @model={{this.args.tournamentId}}
          class="flex items-center gap-1.5 px-3 py-2 text-xs font-semibold rounded-xl bg-black/30 backdrop-blur-sm text-white hover:bg-black/50 transition-colors"
        >
          {{lucideIcon "pencil" class="w-3.5 h-3.5"}}
          Edit
        </LinkTo> --}}
      </div>
    {{/if}}
  </div>
</template>
