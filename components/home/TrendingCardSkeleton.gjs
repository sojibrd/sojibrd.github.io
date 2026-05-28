<template>
  <div
    class="bg-white/10 backdrop-blur-md border border-white/20 rounded-2xl px-5 py-4 shadow-lg mb-3 animate-pulse"
    ...attributes
  >
    {{! ---- Top Meta ---- }}
    <div class="flex items-center justify-between mb-4">
      <div class="flex items-center gap-2">
        <div class="h-5 w-16 bg-white/20 rounded-full"></div>
        <div class="h-3 w-24 bg-white/20 rounded"></div>
      </div>
      <div class="flex items-center gap-1">
        <div class="h-3 w-12 bg-white/20 rounded"></div>
        <div class="h-3 w-10 bg-white/20 rounded"></div>
      </div>
    </div>

    {{! ---- Teams Row ---- }}
    <div class="flex items-center">
      {{! Left Team (Batting) }}
      <div class="flex-1 flex items-center gap-3">
        <div class="w-10 h-10 bg-white/20 rounded-full"></div>
        <div class="flex-1 space-y-2">
          <div class="h-4 w-3/4 bg-white/20 rounded"></div>
          <div class="h-3 w-1/2 bg-white/15 rounded"></div>
        </div>
      </div>

      {{! Scores }}
      <div class="flex items-center gap-3 px-2 shrink-0">
        <div class="h-5 w-12 bg-white/20 rounded"></div>
        <div class="h-5 w-3 bg-white/15 rounded"></div>
        <div class="h-5 w-12 bg-white/20 rounded"></div>
      </div>

      {{! Right Team (Fielding) }}
      <div class="flex-1 flex items-center justify-end gap-3">
        <div class="flex-1 space-y-2 text-right">
          <div class="h-4 w-3/4 bg-white/20 rounded ml-auto"></div>
          <div class="h-3 w-1/2 bg-white/15 rounded ml-auto"></div>
        </div>
      </div>
    </div>
  </div>
</template>
