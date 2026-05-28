<template>
  <div class="min-h-screen bg-gray-50 dark:bg-slate-900 flex items-center justify-center p-4 -mx-4 sm:-mx-6 lg:-mx-8">
    <div class="text-center">
      <div class="relative w-20 h-20 mx-auto mb-6">
        <div class="absolute inset-0 border-4 border-gray-200 dark:border-slate-700 rounded-full"></div>
        <div class="absolute inset-0 border-4 border-transparent border-t-cyan-500 rounded-full animate-spin"></div>
        <div class="absolute inset-2 border-4 border-transparent border-t-red-500 rounded-full animate-spin" style="animation-direction: reverse; animation-duration: 0.8s;"></div>
      </div>
      <h2 class="text-gray-900 dark:text-white text-lg font-semibold mb-2">Loading Match Details</h2>
      <p class="text-gray-500 dark:text-gray-400 text-sm">Please wait...</p>
      <div class="flex items-center justify-center gap-1.5 mt-4">
        <span class="w-2 h-2 bg-cyan-500 rounded-full animate-bounce" style="animation-delay: 0ms;"></span>
        <span class="w-2 h-2 bg-cyan-500 rounded-full animate-bounce" style="animation-delay: 150ms;"></span>
        <span class="w-2 h-2 bg-cyan-500 rounded-full animate-bounce" style="animation-delay: 300ms;"></span>
      </div>
    </div>
  </div>
</template>
