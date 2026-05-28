/**
 * FormSubmitError
 * ──────────────────────────────────────────────────────────────────────────────
 * Dismissable error banner shown after a failed form submission. Renders
 * nothing when @error is falsy.
 *
 * Supports an optional array of per-field error strings that appear as a
 * bulleted list beneath the main message.
 *
 * @arg {string}   error    - Top-level error message.
 * @arg {string[]} [errors] - Optional array of field-level error strings.
 * @arg {Function} onDismiss - Called when the × close button is clicked.
 *
 * Usage:
 *   <FormSubmitError
 *     @error={{this.submitError}}
 *     @errors={{this.submitErrors}}
 *     @onDismiss={{this.clearSubmitError}}
 *   />
 */
import { on } from '@ember/modifier';

<template>
  {{#if @error}}
    <div class="mx-6 sm:mx-8 mb-0 mt-4 rounded-xl overflow-hidden
                border border-rose-200 dark:border-rose-700/60
                bg-rose-50 dark:bg-rose-900/20">

      {{! Header row }}
      <div class="flex items-center gap-2.5 px-4 py-3
                  {{if @errors.length 'border-b border-rose-100 dark:border-rose-800/40' ''}}">
        <svg class="w-4 h-4 text-rose-500 shrink-0" viewBox="0 0 24 24" fill="currentColor">
          <path d="M12 2a10 10 0 1 0 0 20A10 10 0 0 0 12 2zm1 13H11v-2h2v2zm0-4H11V7h2v4z"/>
        </svg>
        <p class="flex-1 text-sm text-rose-700 dark:text-rose-300 font-semibold">
          {{@error}}
        </p>
        <button
          type="button"
          {{on "click" @onDismiss}}
          class="ml-2 shrink-0 w-6 h-6 rounded-full flex items-center justify-center
                 text-rose-400 hover:text-rose-600 hover:bg-rose-100
                 dark:hover:text-rose-300 dark:hover:bg-rose-800/40
                 transition-all duration-150"
          title="Dismiss"
        >
          <svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor"
               stroke-width="2.5" stroke-linecap="round">
            <path d="M18 6L6 18M6 6l12 12"/>
          </svg>
        </button>
      </div>

      {{! Per-field error list }}
      {{#if @errors.length}}
        <ul class="px-4 py-3 space-y-1.5">
          {{#each @errors as |err|}}
            <li class="flex items-start gap-2 text-xs text-rose-600 dark:text-rose-400">
              <svg class="w-3 h-3 shrink-0 mt-0.5" viewBox="0 0 24 24" fill="none"
                   stroke="currentColor" stroke-width="3"
                   stroke-linecap="round" stroke-linejoin="round">
                <path d="M18 6L6 18M6 6l12 12"/>
              </svg>
              {{err}}
            </li>
          {{/each}}
        </ul>
      {{/if}}

    </div>
  {{/if}}
</template>
