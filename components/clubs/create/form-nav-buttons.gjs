/**
 * FormNavButtons
 * ──────────────────────────────────────────────────────────────────────────────
 * Sticky footer navigation for multi-step forms. Renders:
 *  - "Back" button (hidden on the first step)
 *  - "Step X of Y" label in the centre
 *  - "Continue" button (intermediate steps) or a submit button (last step)
 *
 * @arg {number}   currentStep   - 1-based current step index.
 * @arg {number}   totalSteps    - Total number of steps.
 * @arg {boolean}  isFirstStep   - Hide the Back button when true.
 * @arg {boolean}  isLastStep    - Show the submit button instead of Continue.
 * @arg {boolean}  isSubmitting  - Disables & shows a spinner on the submit button.
 * @arg {string}   [submitLabel] - Label for the submit button (default: "Submit").
 * @arg {Function} onPrev        - Called when Back is clicked.
 * @arg {Function} onNext        - Called when Continue is clicked.
 * @arg {Function} onSubmit      - Called when the submit button is clicked.
 *
 * Usage:
 *   <FormNavButtons
 *     @currentStep={{this.currentStep}}
 *     @totalSteps={{this.totalSteps}}
 *     @isFirstStep={{this.isFirstStep}}
 *     @isLastStep={{this.isLastStep}}
 *     @isSubmitting={{this.isSubmitting}}
 *     @submitLabel="Create Club"
 *     @onPrev={{this.prevStep}}
 *     @onNext={{this.nextStep}}
 *     @onSubmit={{this.handleSubmit}}
 *   />
 */
import { on } from '@ember/modifier';

<template>
  <div class="flex items-center justify-between
              px-6 sm:px-8 py-5
              border-t border-gray-100 dark:border-gray-700/60
              bg-gray-50/50 dark:bg-gray-800/30">

    {{! Back button (hidden on first step) }}
    {{#if @isFirstStep}}
      <div></div>
    {{else}}
      <button
        type="button"
        {{on "click" @onPrev}}
        class="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl
               border border-gray-200 dark:border-gray-600
               bg-white dark:bg-gray-800
               text-gray-700 dark:text-gray-300 text-sm font-semibold
               hover:border-gray-300 dark:hover:border-gray-500
               hover:bg-gray-50 dark:hover:bg-gray-700
               transition-all duration-200
               focus:outline-none focus:ring-2 focus:ring-gray-300 dark:focus:ring-gray-600"
      >
        <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor"
             stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M15 18l-6-6 6-6"/>
        </svg>
        Back
      </button>
    {{/if}}

    {{! Step counter }}
    <span class="text-xs font-medium text-gray-400 dark:text-gray-500">
      Step {{@currentStep}} of {{@totalSteps}}
    </span>

    {{! Continue / Submit }}
    {{#if @isLastStep}}
      <button
        type="button"
        {{on "click" @onSubmit}}
        disabled={{@isSubmitting}}
        class="inline-flex items-center gap-2 px-6 py-2.5 rounded-xl
               bg-gradient-to-r from-indigo-600 via-violet-600 to-indigo-600
               hover:from-indigo-500 hover:via-violet-500 hover:to-indigo-500
               text-white text-sm font-bold shadow-lg shadow-indigo-500/30
               disabled:opacity-60 disabled:cursor-not-allowed
               transition-all duration-200
               focus:outline-none focus:ring-2 focus:ring-indigo-400 focus:ring-offset-2
               dark:focus:ring-offset-gray-900"
      >
        {{#if @isSubmitting}}
          <svg class="w-4 h-4 animate-spin" viewBox="0 0 24 24" fill="none">
            <circle class="opacity-25" cx="12" cy="12" r="10"
                    stroke="currentColor" stroke-width="4"/>
            <path class="opacity-75" fill="currentColor"
                  d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/>
          </svg>
          Creating…
        {{else}}
          <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor"
               stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <path d="M5 13l4 4L19 7"/>
          </svg>
          {{if @submitLabel @submitLabel "Submit"}}
        {{/if}}
      </button>
    {{else}}
      <button
        type="button"
        {{on "click" @onNext}}
        class="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl
               bg-indigo-600 hover:bg-indigo-500 active:bg-indigo-700
               text-white text-sm font-semibold shadow-sm shadow-indigo-500/25
               transition-all duration-200
               focus:outline-none focus:ring-2 focus:ring-indigo-400 focus:ring-offset-2
               dark:focus:ring-offset-gray-900"
      >
        Continue
        <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor"
             stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M9 18l6-6-6-6"/>
        </svg>
      </button>
    {{/if}}

  </div>
</template>
