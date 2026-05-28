/**
 * ImageUploader
 * ──────────────────────────────────────────────────────────────────────────────
 * Reusable file-upload zone with preview, remove, and validation-error display.
 * Does NOT manage its own file state — the parent component handles file reading
 * and passes the preview URL down.
 *
 * Two visual variants:
 *  - "banner"  (default) — wide landscape preview (h-36) with file-name overlay
 *  - "logo"              — side-by-side square preview + upload button
 *
 * Multi-file mode: pass @previews (array of data-URLs) instead of @preview.
 * Each thumbnail gets a remove button that fires @onRemoveAt with its index.
 * The hidden file input must have the `multiple` attribute set in the parent.
 *
 * A hidden `<input type="file">` must be placed in the parent's template with
 * the id matching @inputId, and wired to the parent's upload handler. This
 * component only calls @onTrigger to imperatively click that input.
 *
 * @arg {string}   label          - Field label text.
 * @arg {string}   [hint]         - Optional hint after the label (e.g. "900×300 px · max 200 KB").
 * @arg {string}   [preview]      - Data-URL or src of the current preview image (single-file mode).
 * @arg {Array}    [previews]     - Array of data-URLs (multi-file mode). Activates thumbnail grid.
 * @arg {string}   [fileName]     - File name shown in the banner overlay.
 * @arg {string}   [uploadError]  - File-size / type error from the upload handler.
 * @arg {string}   [error]        - Validation error from the parent form validator.
 * @arg {string}   inputId        - id of the hidden file input element.
 * @arg {string}   [variant]      - "banner" (default) | "logo"
 * @arg {boolean}  [required]     - Appends a red asterisk to the label.
 * @arg {Function} onTrigger      - Called to programmatically click the hidden file input.
 * @arg {Function} [onRemove]     - Called to clear the current single-file preview.
 * @arg {Function} [onRemoveAt]   - Called with index to remove one item from @previews.
 */
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { eq } from 'ember-truth-helpers';
import FormFieldError from './form-field-error';

<template>
  <div>
    {{! Label }}
    <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
      {{@label}}
      {{#if @required}}<span class="text-rose-500"> *</span>{{/if}}
      {{#if @hint}}
        <span class="ml-2 text-xs font-normal text-gray-400">{{@hint}}</span>
      {{/if}}
    </label>

    {{! ── Logo variant ── }}
    {{#if (eq @variant "logo")}}

      <div class="flex items-start gap-4">
        <div class="shrink-0 w-20 h-20 rounded-2xl border-2 border-dashed
                    border-gray-200 dark:border-gray-600
                    bg-gray-50 dark:bg-gray-800
                    flex items-center justify-center overflow-hidden">
          {{#if @preview}}
            <img src={{@preview}} alt="Logo preview" class="w-full h-full object-cover" />
          {{else}}
            <svg class="w-6 h-6 text-gray-300 dark:text-gray-600" viewBox="0 0 24 24"
                 fill="none" stroke="currentColor" stroke-width="2"
                 stroke-linecap="round" stroke-linejoin="round">
              <rect x="3" y="3" width="18" height="18" rx="2"/>
              <circle cx="8.5" cy="8.5" r="1.5"/>
              <polyline points="21 15 16 10 5 21"/>
            </svg>
          {{/if}}
        </div>
        <div class="flex-1">
          <button
            type="button"
            {{on "click" @onTrigger}}
            class="w-full h-20 rounded-xl border-2 border-dashed transition-all duration-200
                   flex flex-col items-center justify-center gap-1.5 group
                   {{if @error
                     'border-rose-400 bg-rose-50 dark:bg-rose-900/10'
                     'border-gray-300 dark:border-gray-600
                      hover:border-indigo-400 dark:hover:border-indigo-500
                      hover:bg-indigo-50/50 dark:hover:bg-indigo-900/10
                      bg-gray-50 dark:bg-gray-800/50'}}"
          >
            <svg class="w-4 h-4 text-indigo-400 group-hover:text-indigo-600 transition-colors"
                 viewBox="0 0 24 24" fill="none" stroke="currentColor"
                 stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
              <polyline points="17 8 12 3 7 8"/>
              <line x1="12" y1="3" x2="12" y2="15"/>
            </svg>
            <p class="text-xs font-semibold text-gray-600 dark:text-gray-400">
              {{if @preview "Change logo" "Upload logo"}}
            </p>
            <p class="text-[10px] text-gray-400">PNG, JPG up to 100 KB</p>
          </button>
          {{#if @preview}}
            <button
              type="button"
              {{on "click" @onRemove}}
              class="mt-1.5 text-xs text-rose-500 hover:text-rose-600 transition-colors font-medium"
            >
              Remove
            </button>
          {{/if}}
        </div>
      </div>

    {{else}}

      {{! ── Banner variant (default) ── }}

      {{! Multi-file mode: @previews array provided }}
      {{#if @previews}}

        <div class="space-y-2">
          {{#if @previews.length}}
            <div class="grid grid-cols-3 sm:grid-cols-4 gap-2">
              {{#each @previews as |src i|}}
                <div class="relative aspect-square rounded-lg overflow-hidden
                            border border-gray-200 dark:border-gray-600 group">
                  <img src={{src}} alt="Preview {{i}}" class="w-full h-full object-cover" />
                  <button
                    type="button"
                    aria-label="Remove photo"
                    {{on "click" (fn @onRemoveAt i)}}
                    class="absolute top-1 right-1 w-5 h-5 rounded-full
                           bg-black/60 hover:bg-black/80 text-white
                           flex items-center justify-center
                           opacity-0 group-hover:opacity-100 transition-opacity duration-150"
                  >
                    <svg class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                         stroke-width="3" stroke-linecap="round">
                      <path d="M18 6L6 18M6 6l12 12"/>
                    </svg>
                  </button>
                </div>
              {{/each}}
            </div>
          {{/if}}

          <button
            type="button"
            {{on "click" @onTrigger}}
            class="w-full h-10 rounded-lg border-2 border-dashed transition-all duration-200
                   flex items-center justify-center gap-2 text-xs font-semibold group
                   {{if @error
                     'border-rose-400 bg-rose-50 dark:bg-rose-900/10 text-rose-500'
                     'border-gray-300 dark:border-gray-600 text-gray-500 dark:text-gray-400
                      hover:border-indigo-400 dark:hover:border-indigo-500
                      hover:text-indigo-500 bg-gray-50 dark:bg-gray-800/50'}}"
          >
            <svg class="w-4 h-4 transition-colors"
                 viewBox="0 0 24 24" fill="none" stroke="currentColor"
                 stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M12 5v14M5 12h14"/>
            </svg>
            {{if @previews.length "Change selection" "Select photos"}}
          </button>
        </div>

      {{! Single-file mode: @preview string }}
      {{else if @preview}}
        <div class="relative rounded-xl overflow-hidden border border-gray-200 dark:border-gray-600">
          <img src={{@preview}} alt="Banner preview" class="w-full h-36 object-cover" />
          <button
            type="button"
            {{on "click" @onRemove}}
            class="absolute top-2 right-2 w-7 h-7 rounded-full
                   bg-black/50 hover:bg-black/70 text-white
                   flex items-center justify-center transition-all duration-150"
          >
            <svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                 stroke-width="3" stroke-linecap="round">
              <path d="M18 6L6 18M6 6l12 12"/>
            </svg>
          </button>
          {{#if @fileName}}
            <div class="absolute bottom-2 left-2 px-2 py-0.5 rounded-full
                        bg-black/50 text-white text-[10px] font-medium">
              {{@fileName}}
            </div>
          {{/if}}
        </div>

      {{! No preview yet: full upload zone }}
      {{else}}
        <button
          type="button"
          {{on "click" @onTrigger}}
          class="w-full h-32 rounded-xl border-2 border-dashed transition-all duration-200
                 flex flex-col items-center justify-center gap-2 group
                 {{if @error
                   'border-rose-400 bg-rose-50 dark:bg-rose-900/10'
                   'border-gray-300 dark:border-gray-600
                    hover:border-indigo-400 dark:hover:border-indigo-500
                    hover:bg-indigo-50/50 dark:hover:bg-indigo-900/10
                    bg-gray-50 dark:bg-gray-800/50'}}"
        >
          <div class="w-10 h-10 rounded-xl bg-white dark:bg-gray-700 shadow-sm
                      flex items-center justify-center
                      group-hover:scale-110 transition-transform duration-200">
            <svg class="w-5 h-5 text-indigo-500" viewBox="0 0 24 24" fill="none"
                 stroke="currentColor" stroke-width="2"
                 stroke-linecap="round" stroke-linejoin="round">
              <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
              <polyline points="17 8 12 3 7 8"/>
              <line x1="12" y1="3" x2="12" y2="15"/>
            </svg>
          </div>
          <div class="text-center">
            <p class="text-sm font-semibold text-gray-700 dark:text-gray-300">
              Click to upload {{if @label @label "image"}}
            </p>
            <p class="text-xs text-gray-400 dark:text-gray-500">PNG, JPG up to 200 KB</p>
          </div>
        </button>
      {{/if}}

    {{/if}}

    {{! Upload handler error (size/type) }}
    {{#if @uploadError}}
      <p class="mt-1.5 text-xs text-rose-500 flex items-center gap-1">
        <svg class="w-3 h-3 shrink-0" viewBox="0 0 24 24" fill="currentColor">
          <path d="M12 2a10 10 0 1 0 0 20A10 10 0 0 0 12 2zm1 13H11v-2h2v2zm0-4H11V7h2v4z"/>
        </svg>
        {{@uploadError}}
      </p>
    {{/if}}

    {{! Validation error }}
    <FormFieldError @error={{@error}} />
  </div>
</template>
