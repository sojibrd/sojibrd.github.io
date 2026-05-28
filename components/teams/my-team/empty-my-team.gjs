import { on } from '@ember/modifier';

<template>
  <div class="flex flex-col items-center justify-center py-14 sm:py-24 text-center px-4">
    <div class="relative mb-6">
      <div
        class="w-24 h-24 rounded-3xl bg-gradient-to-br from-indigo-100 to-violet-100 dark:from-indigo-900/30 dark:to-violet-900/30 flex items-center justify-center"
      >
        <svg
          class="w-12 h-12 text-indigo-400"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="1.5"
            d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z"
          />
        </svg>
      </div>
      <span class="absolute -bottom-1 -right-1 text-2xl">🏏</span>
    </div>
    <h3 class="text-lg font-bold text-gray-900 dark:text-white mb-2">No teams
      yet</h3>
    <p class="text-sm text-gray-500 dark:text-gray-400 max-w-xs mb-6">
      Create your first team and start playing with friends!
    </p>
    <button
      type="button"
      class="inline-flex items-center gap-2 px-6 py-3 rounded-2xl text-sm font-bold text-white bg-gradient-to-r from-indigo-600 to-violet-600 shadow-lg shadow-indigo-500/30 hover:shadow-indigo-500/50 hover:-translate-y-0.5 transition-all duration-200"
      {{on "click" @onCreate}}
    >
      <svg
        class="w-4 h-4"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2.5"
          d="M12 4v16m8-8H4"
        />
      </svg>
      Create Team
    </button>
  </div>
</template>
