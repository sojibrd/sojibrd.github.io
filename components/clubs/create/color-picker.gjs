/**
 * ColorPicker
 * ──────────────────────────────────────────────────────────────────────────────
 * Renders a list of color swatches with native `<input type="color">` pickers.
 * Supports adding new colors and removing existing ones (the last remaining
 * color cannot be removed).
 *
 * The parent is responsible for all state; this component is purely presentational.
 *
 * @arg {Array<{color: string, index: number, style: SafeString}>} colorsForDisplay
 *   Pre-processed list produced by the parent's `colorsForDisplay` getter.
 *   Each item carries:
 *     - color  {string}     — hex string (e.g. "#4f46e5")
 *     - index  {number}     — 0-based position in the parent array
 *     - style  {SafeString} — `htmlSafe("background-color:#4f46e5")`
 * @arg {number}   colorCount  - Length of the raw colors array (used to hide
 *                               the remove button when only one color remains).
 * @arg {Function} onAdd       - Called (no args) when "+ Add Color" is clicked.
 * @arg {Function} onUpdate    - Called with (index: number, event: InputEvent).
 * @arg {Function} onRemove    - Called with (index: number) to remove a swatch.
 *
 * Usage:
 *   <ColorPicker
 *     @colorsForDisplay={{this.colorsForDisplay}}
 *     @colorCount={{this.clubColors.length}}
 *     @onAdd={{this.addColor}}
 *     @onUpdate={{this.updateColor}}
 *     @onRemove={{this.removeColor}}
 *   />
 */
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { gt } from 'ember-truth-helpers';

<template>
  <div>
    <div class="flex items-center justify-between mb-2">
      <label class="text-sm font-semibold text-gray-700 dark:text-gray-300">
        Club Colors
      </label>
      <button
        type="button"
        {{on "click" @onAdd}}
        class="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg
               bg-indigo-50 dark:bg-indigo-900/30
               text-indigo-600 dark:text-indigo-400 text-xs font-semibold
               hover:bg-indigo-100 dark:hover:bg-indigo-900/50
               transition-all duration-150"
      >
        <svg class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor"
             stroke-width="3" stroke-linecap="round">
          <path d="M12 5v14M5 12h14"/>
        </svg>
        Add Color
      </button>
    </div>

    <div class="flex flex-wrap gap-3">
      {{#each @colorsForDisplay as |item|}}
        <div class="flex items-center gap-2 p-2 rounded-xl
                    border border-gray-200 dark:border-gray-600
                    bg-gray-50 dark:bg-gray-800 group">

          {{! Color preview swatch }}
          <div class="w-8 h-8 rounded-lg shadow-sm border border-white/50 dark:border-gray-600/50 shrink-0"
               style={{item.style}}></div>

          {{! Native color picker (hidden behind the swatch) }}
          <input
            type="color"
            value={{item.color}}
            {{on "input" (fn @onUpdate item.index)}}
            class="w-6 h-6 rounded cursor-pointer border-0 bg-transparent p-0
                   focus:outline-none focus:ring-2 focus:ring-indigo-400/50"
            title="Pick color"
          />

          {{! Hex label }}
          <span class="text-xs font-mono text-gray-500 dark:text-gray-400 min-w-[4.5rem]">
            {{item.color}}
          </span>

          {{! Remove button (hidden when only one color) }}
          {{#if (gt @colorCount 1)}}
            <button
              type="button"
              {{on "click" (fn @onRemove item.index)}}
              class="opacity-0 group-hover:opacity-100 w-5 h-5 rounded-full
                     bg-rose-100 dark:bg-rose-900/30 text-rose-500
                     flex items-center justify-center
                     transition-all duration-150"
            >
              <svg class="w-2.5 h-2.5" viewBox="0 0 24 24" fill="none"
                   stroke="currentColor" stroke-width="3" stroke-linecap="round">
                <path d="M18 6L6 18M6 6l12 12"/>
              </svg>
            </button>
          {{/if}}

        </div>
      {{/each}}
    </div>
  </div>
</template>
