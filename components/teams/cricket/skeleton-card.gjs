<template>
  <div
    class="flex flex-col bg-white dark:bg-gray-900 rounded-2xl overflow-hidden border border-gray-100 dark:border-gray-800"
  >
    <div class="h-1 bg-gray-100 dark:bg-gray-800 shrink-0"></div>

    {{! Horizontal on mobile, vertical on sm+ }}
    <div class="flex flex-row sm:flex-col flex-1">
      {{! Logo zone }}
      <div
        class="w-24 shrink-0 sm:w-full sm:h-40 bg-gradient-to-br from-gray-100 to-gray-50 dark:from-gray-800 dark:to-gray-900 flex items-center justify-center"
      >
        <div class="w-11 h-11 sm:w-20 sm:h-20 rounded-2xl bg-gray-200 dark:bg-gray-700 animate-pulse"></div>
      </div>

      {{! Info }}
      <div class="flex flex-col flex-1 px-3 sm:px-4 py-3 space-y-2 sm:space-y-3">
        <div class="space-y-1.5">
          <div class="h-4 bg-gray-200 dark:bg-gray-700 rounded-lg animate-pulse sm:mx-4"></div>
          <div class="h-3 bg-gray-100 dark:bg-gray-800 rounded-lg animate-pulse sm:mx-8"></div>
        </div>
        <div class="hidden sm:grid grid-cols-2 gap-2">
          <div class="h-12 bg-gray-100 dark:bg-gray-800 rounded-xl animate-pulse"></div>
          <div class="h-12 bg-gray-100 dark:bg-gray-800 rounded-xl animate-pulse"></div>
        </div>
        <div class="mt-auto h-8 bg-gray-100 dark:bg-gray-800 rounded-xl animate-pulse"></div>
      </div>
    </div>
  </div>
</template>
