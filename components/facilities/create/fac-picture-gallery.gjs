/**
 * FacPictureGallery
 * ──────────────────────────────────────────────────────────────────────────────
 * Displays a grid of facility picture previews with individual remove buttons
 * and an "Add More" upload trigger when the max has not been reached.
 *
 * @arg {string[]} previews  - Array of data-URL preview strings.
 * @arg {number}   count     - Current number of selected files.
 * @arg {number}   maxCount  - Maximum number of pictures allowed.
 * @arg {string}   [error]   - Upload error message.
 * @arg {Function} onTrigger - Called when the upload trigger button is clicked.
 * @arg {Function} onRemove  - Called with (index) when a picture's × is clicked.
 *
 * Usage:
 *   <FacPictureGallery
 *     @previews={{this.picturePreviews}}
 *     @count={{this.pictureFiles.length}}
 *     @maxCount={{this.MAX_PICTURES}}
 *     @error={{this.pictureError}}
 *     @onTrigger={{this.triggerPicturesUpload}}
 *     @onRemove={{this.removePicture}}
 *   />
 */
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { lt } from 'ember-truth-helpers';
import lucideIcon from 'spordium/helpers/lucide-icon';

<template>
  <div>
    {{! Preview grid }}
    {{#if @previews.length}}
      <div class="grid grid-cols-3 gap-2 mb-2">
        {{#each @previews key="@index" as |src i|}}
          <div class="relative rounded-lg overflow-hidden aspect-square">
            <img src={{src}} alt="Facility picture" class="w-full h-full object-cover" />
            <button
              type="button"
              aria-label="Remove picture"
              {{on "click" (fn @onRemove i)}}
              class="absolute top-1 right-1 w-5 h-5 rounded-full
                     bg-black/60 hover:bg-black/80 text-white
                     flex items-center justify-center transition-all"
            >
              {{lucideIcon "x" size=12}}
            </button>
          </div>
        {{/each}}
      </div>
    {{/if}}

    {{! Upload trigger (hidden when max reached) }}
    {{#if (lt @count @maxCount)}}
      <button
        type="button"
        {{on "click" @onTrigger}}
        class="w-full h-24 rounded-xl border-2 border-dashed
               border-gray-700 hover:border-indigo-500/50
               bg-gray-800/50 hover:bg-gray-800
               flex flex-col items-center justify-center gap-2
               text-gray-500 hover:text-indigo-400
               transition-all duration-200 group"
      >
        {{lucideIcon "upload" size=20}}
        <span class="text-xs font-semibold">
          {{if @previews.length "Add More Pictures" "Upload Facility Pictures"}}
        </span>
      </button>
    {{/if}}

    {{#if @error}}
      <p class="mt-1 text-xs text-rose-400">{{@error}}</p>
    {{/if}}
  </div>
</template>
