<template>
  <div
    class="flex-1 flex items-center gap-1.5 sm:gap-2.5 min-w-0
      {{if @reverse 'flex-row-reverse text-right'}}"
  >
    {{! Logo }}
    <div
      class="w-8 h-8 sm:w-10 sm:h-10 md:w-12 md:h-12 rounded-xl shrink-0 overflow-hidden
             ring-2 ring-white/20 ring-offset-1 ring-offset-transparent
             bg-white/10 flex items-center justify-center
             shadow-[0_2px_12px_rgba(0,0,0,0.4)]"
    >
      {{#if @logo}}
        <img
          src="{{@bucket}}/{{@logo}}"
          class="w-full h-full object-cover"
          alt={{@name}}
          loading="lazy"
        />
      {{else}}
        <svg class="w-5 h-5 text-white/25" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" d="M15 19.128a9.38 9.38 0 0 0 2.625.372 9.337 9.337 0 0 0 4.121-.952 4.125 4.125 0 0 0-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 0 1 8.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0 1 11.964-3.07M12 6.375a3.375 3.375 0 1 1-6.75 0 3.375 3.375 0 0 1 6.75 0Z" />
        </svg>
      {{/if}}
    </div>

    {{! Name + subtext }}
    <div class="min-w-0">
      <p class="text-white text-[11px] sm:text-[13px] font-bold truncate leading-tight">
        {{@name}}
      </p>
      <p class="text-white/45 text-[9px] sm:text-[10px] mt-0.5 font-medium tabular-nums">
        {{@subtext}}
      </p>
    </div>
  </div>
</template>
