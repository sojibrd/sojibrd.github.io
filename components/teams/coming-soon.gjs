<template>
  <div class="flex flex-col items-center justify-center py-14 sm:py-24 text-center px-4">
    <div
      class="w-20 h-20 mb-6 rounded-3xl bg-gradient-to-br from-gray-100 to-gray-50 dark:from-gray-800 dark:to-gray-900 flex items-center justify-center text-4xl"
    >
      {{@emoji}}
    </div>
    <h3 class="text-lg font-bold text-gray-900 dark:text-white mb-2">Coming Soon</h3>
    <p class="text-sm text-gray-500 dark:text-gray-400">{{@label}}
      teams are on their way!</p>
  </div>
</template>
