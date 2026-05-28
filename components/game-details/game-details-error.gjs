import { LinkTo } from '@ember/routing';

<template>
  <div class="min-h-screen bg-gray-50 dark:bg-slate-900 flex items-center justify-center p-4">
    <div class="bg-white dark:bg-slate-800 rounded-2xl p-8 text-center max-w-md shadow-xl border border-gray-200 dark:border-slate-700/50">
      <div class="w-20 h-20 mx-auto mb-6 bg-red-50 dark:bg-red-500/10 rounded-full flex items-center justify-center">
        <svg class="w-10 h-10 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"></path>
        </svg>
      </div>
      <h1 class="text-gray-900 dark:text-white text-xl font-bold mb-2">Oops! Something went wrong</h1>
      <p class="text-gray-500 dark:text-gray-400 mb-6">
        {{#if @model.message}}
          {{@model.message}}
        {{else}}
          Could not load match details. Please check your connection and try again.
        {{/if}}
      </p>
      <div class="flex flex-col sm:flex-row items-center justify-center gap-3">
        <button
          type="button"
          class="w-full sm:w-auto bg-cyan-500 hover:bg-cyan-600 text-white px-6 py-2.5 rounded-lg font-semibold transition shadow-lg"
          onclick={{@model.retry}}
        >
          Try Again
        </button>
        <LinkTo
          @route="index"
          class="w-full sm:w-auto bg-gray-100 dark:bg-slate-700 hover:bg-gray-200 dark:hover:bg-slate-600 text-gray-700 dark:text-white px-6 py-2.5 rounded-lg font-semibold transition"
        >
          Go Home
        </LinkTo>
      </div>
    </div>
  </div>
</template>
