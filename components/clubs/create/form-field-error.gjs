/**
 * FormFieldError
 * ──────────────────────────────────────────────────────────────────────────────
 * Renders a single inline validation error below a form field.
 * Renders nothing when @error is falsy.
 *
 * @arg {string} error - The error message to display.
 *
 * Usage:
 *   <FormFieldError @error={{this.errors.myField}} />
 */
<template>
  {{#if @error}}
    <p class="mt-1 text-xs text-rose-500 flex items-center gap-1">
      <svg class="w-3 h-3 shrink-0" viewBox="0 0 24 24" fill="currentColor">
        <path d="M12 2a10 10 0 1 0 0 20A10 10 0 0 0 12 2zm1 13H11v-2h2v2zm0-4H11V7h2v4z"/>
      </svg>
      {{@error}}
    </p>
  {{/if}}
</template>
