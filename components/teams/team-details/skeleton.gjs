<template>
  <div class="animate-pulse">
    <div
      class="h-56 sm:h-72 bg-gradient-to-br from-gray-200 to-gray-300 dark:from-gray-700 dark:to-gray-800"
    ></div>
    <div class="flex justify-center -mt-14 mb-6">
      <div
        class="w-28 h-28 rounded-3xl bg-gray-300 dark:bg-gray-600 border-4 border-white dark:border-gray-950 shadow-xl"
      ></div>
    </div>
    <div class="flex flex-col items-center gap-3 px-4 mb-10">
      <div class="h-7 bg-gray-300 dark:bg-gray-600 rounded-full w-56"></div>
      <div class="h-4 bg-gray-200 dark:bg-gray-700 rounded-full w-32"></div>
      <div class="flex gap-2">
        <div class="h-6 bg-gray-200 dark:bg-gray-700 rounded-full w-20"></div>
        <div class="h-6 bg-gray-200 dark:bg-gray-700 rounded-full w-24"></div>
      </div>
    </div>
    <div class="border-b border-gray-200 dark:border-gray-700 px-4 mb-8">
      <div class="flex gap-2 pb-0 max-w-6xl mx-auto">
        {{#each @skeletonRows as |_|}}
          <div
            class="h-9 bg-gray-200 dark:bg-gray-700 rounded-t w-20 shrink-0"
          ></div>
          <div
            class="h-9 bg-gray-200 dark:bg-gray-700 rounded-t w-16 shrink-0"
          ></div>
          <div
            class="h-9 bg-gray-200 dark:bg-gray-700 rounded-t w-24 shrink-0"
          ></div>
          <div
            class="h-9 bg-gray-200 dark:bg-gray-700 rounded-t w-14 shrink-0"
          ></div>
        {{/each}}
      </div>
    </div>
    <div class="max-w-6xl mx-auto px-4 grid grid-cols-1 lg:grid-cols-3 gap-6">
      <div class="lg:col-span-2 space-y-4">
        <div
          class="rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-700/50 h-40"
        ></div>
        <div
          class="rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-700/50 h-56"
        ></div>
      </div>
      <div
        class="rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-700/50 h-64"
      ></div>
    </div>
  </div>
</template>
