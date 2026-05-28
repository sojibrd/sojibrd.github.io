/**
 * LinkListField
 * ──────────────────────────────────────────────────────────────────────────────
 * A dynamic list of URL inputs where the user can add or remove entries.
 * The "remove" button is hidden when only one entry remains.
 * Used for both video links and social media links in the club create form.
 *
 * @arg {string}   label       - Field section label (e.g. "Club Video Links").
 * @arg {string[]} links       - Current list of link strings (can be empty strings).
 * @arg {string}   [error]     - Validation error message shown below the list.
 * @arg {string}   [placeholder] - Placeholder for each URL input.
 * @arg {Function} onAdd       - Called (no args) to append an empty entry.
 * @arg {Function} onRemove    - Called with (index: number) to remove an entry.
 * @arg {Function} onUpdate    - Called with (index: number, event: InputEvent).
 *
 * Usage:
 *   <LinkListField
 *     @label="Club Video Links"
 *     @links={{this.videoLinks}}
 *     @error={{this.errors.videoLinks}}
 *     @placeholder="YouTube / Vimeo link"
 *     @onAdd={{this.addVideoLink}}
 *     @onRemove={{this.removeVideoLink}}
 *     @onUpdate={{this.updateVideoLink}}
 *   />
 *
 *   <LinkListField
 *     @label="Social Media Links"
 *     @links={{this.socialLinks}}
 *     @error={{this.errors.socialLinks}}
 *     @placeholder="Facebook / Instagram / Twitter link"
 *     @onAdd={{this.addSocialLink}}
 *     @onRemove={{this.removeSocialLink}}
 *     @onUpdate={{this.updateSocialLink}}
 *   />
 */
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { gt } from 'ember-truth-helpers';
import FormFieldError from './form-field-error';

<template>
  <div>
    <div class="flex items-center justify-between mb-2">
      <label class="text-sm font-semibold text-gray-700 dark:text-gray-300">
        {{@label}}
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
        Add Link
      </button>
    </div>

    <div class="space-y-2">
      {{#each @links key="@index" as |link i|}}
        <div class="flex gap-2">
          <input
            type="url"
            placeholder={{if @placeholder @placeholder "https://…"}}
            value={{link}}
            {{on "input" (fn @onUpdate i)}}
            class="flex-1 px-4 py-3 rounded-xl border border-gray-200 dark:border-gray-600
                   bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-gray-100
                   placeholder:text-gray-400 dark:placeholder:text-gray-500
                   focus:outline-none focus:ring-2 focus:ring-indigo-400/30 dark:focus:ring-indigo-500/30
                   focus:border-indigo-400 dark:focus:border-indigo-500
                   transition-all duration-200"
          />
          {{#if (gt @links.length 1)}}
            <button
              type="button"
              {{on "click" (fn @onRemove i)}}
              class="w-11 h-11 rounded-xl border border-rose-200 dark:border-rose-700/50
                     bg-rose-50 dark:bg-rose-900/20 text-rose-500
                     flex items-center justify-center
                     hover:bg-rose-100 dark:hover:bg-rose-900/40
                     transition-all duration-150"
            >
              <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                   stroke-width="2.5" stroke-linecap="round">
                <path d="M18 6L6 18M6 6l12 12"/>
              </svg>
            </button>
          {{/if}}
        </div>
      {{/each}}
    </div>

    <FormFieldError @error={{@error}} />
  </div>
</template>
