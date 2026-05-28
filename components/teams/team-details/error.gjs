import { on } from '@ember/modifier';

<template>
  <div
    class="flex flex-col items-center justify-center min-h-[60vh] px-4 text-center"
  >
    <div
      class="w-20 h-20 mb-6 rounded-3xl bg-rose-100 dark:bg-rose-900/30 flex items-center justify-center"
    >
      <svg
        class="w-10 h-10 text-rose-500"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <circle cx="12" cy="12" r="10" /><path d="M12 8v4" /><path
          d="M12 16h.01"
        />
      </svg>
    </div>
    <h2 class="text-xl font-bold text-gray-900 dark:text-white mb-2">
      Something went wrong
    </h2>
    <p class="text-gray-500 dark:text-gray-400 mb-6">{{@error}}</p>
    <button
      type="button"
      {{on "click" @retry}}
      class="px-6 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 active:bg-indigo-700 text-white font-semibold text-sm shadow-sm transition-colors"
    >
      Try Again
    </button>
  </div>
</template>
