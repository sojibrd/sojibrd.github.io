/**
 * FormStepIndicator
 * ──────────────────────────────────────────────────────────────────────────────
 * Renders a horizontal progress bar and clickable step bubbles for multi-step
 * forms. Completed steps show a checkmark; the active step is highlighted with
 * an indigo ring; future steps are dimmed.
 *
 * @arg {Array<{id: number, label: string, iconPath: string}>} steps
 *   Ordered list of step definitions.
 * @arg {number}   currentStep     - 1-based index of the active step.
 * @arg {SafeString} progressStyle - `htmlSafe('width:X%')` for the progress bar fill.
 * @arg {Function} onGoToStep      - Called with (stepId: number) when a
 *                                   completed step bubble is clicked (navigate back).
 *
 * Usage:
 *   <FormStepIndicator
 *     @steps={{this.steps}}
 *     @currentStep={{this.currentStep}}
 *     @progressStyle={{this.stepProgressStyle}}
 *     @onGoToStep={{this.goToStep}}
 *   />
 */
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { eq, gt } from 'ember-truth-helpers';

<template>
  {{! Progress bar track }}
  <div class="relative h-1.5 bg-gray-200 dark:bg-gray-700 rounded-full mb-6">
    <div
      class="absolute inset-y-0 left-0 rounded-full
             bg-gradient-to-r from-indigo-500 via-violet-500 to-fuchsia-500
             transition-all duration-500 ease-out"
      style={{@progressStyle}}
    ></div>
  </div>

  {{! Step bubbles }}
  <div class="grid gap-2" style="grid-template-columns: repeat({{@steps.length}}, 1fr);">
    {{#each @steps as |step|}}
      <button
        type="button"
        {{on "click" (fn @onGoToStep step.id)}}
        class="flex flex-col items-center gap-1.5 group
               {{if (eq step.id @currentStep) 'pointer-events-none' ''}}"
      >
        <div class="w-10 h-10 rounded-full flex items-center justify-center
                    border-2 transition-all duration-300
                    {{if (eq step.id @currentStep)
                      'bg-indigo-600 border-indigo-600 shadow-lg shadow-indigo-500/30 scale-110'
                      (if (gt @currentStep step.id)
                        'bg-emerald-500 border-emerald-500'
                        'bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-600
                         group-hover:border-indigo-300 dark:group-hover:border-indigo-500')}}">
          {{#if (gt @currentStep step.id)}}
            <svg class="w-4 h-4 text-white" viewBox="0 0 24 24" fill="none"
                 stroke="currentColor" stroke-width="3"
                 stroke-linecap="round" stroke-linejoin="round">
              <path d="M5 13l4 4L19 7"/>
            </svg>
          {{else}}
            <svg class="w-4 h-4 {{if (eq step.id @currentStep) 'text-white' 'text-gray-400 dark:text-gray-500'}}"
                 viewBox="0 0 24 24" fill="none" stroke="currentColor"
                 stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d={{step.iconPath}}/>
            </svg>
          {{/if}}
        </div>
        <span class="text-[11px] font-semibold transition-colors duration-200
                     {{if (eq step.id @currentStep)
                       'text-indigo-600 dark:text-indigo-400'
                       (if (gt @currentStep step.id)
                         'text-emerald-600 dark:text-emerald-400'
                         'text-gray-400 dark:text-gray-500')}}">
          {{step.label}}
        </span>
      </button>
    {{/each}}
  </div>
</template>
