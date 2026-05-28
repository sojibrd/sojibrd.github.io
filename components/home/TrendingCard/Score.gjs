<template>
  <div class={{@alignClass}}>
    <p class="font-black leading-none tracking-tight text-xl sm:text-2xl md:text-[2rem] {{@colorClass}}">
      {{#if @score}}{{@score}}{{else}}0{{/if}}<span
        class="text-xs sm:text-sm md:text-base font-bold text-white/30 ml-0.5"
      >/{{#if @wickets}}{{@wickets}}{{else}}0{{/if}}</span>
    </p>
  </div>
</template>
