/**
 * FacBannerUploader
 * ──────────────────────────────────────────────────────────────────────────────
 * Facility banner image upload area. Shows a preview with remove button when an
 * image is selected, or a styled upload CTA otherwise.
 *
 * @arg {string|null} preview    - Data URL for the selected image preview.
 * @arg {string}      [fileName] - File name shown on the preview overlay.
 * @arg {string}      [error]    - Upload error message.
 * @arg {string}      [label]    - Upload button label. Defaults to "Upload Banner".
 * @arg {string}      [hint]     - Recommended dimensions / size hint.
 * @arg {Function}    onTrigger  - Called when the upload area is clicked.
 * @arg {Function}    onRemove   - Called when the remove (×) button is clicked.
 *
 * Usage:
 *   <FacBannerUploader
 *     @preview={{this.bannerPreview}}
 *     @fileName={{this.bannerFile.name}}
 *     @error={{this.bannerError}}
 *     @label="Upload Facilities Banner"
 *     @hint="1920 × 720 px · max 500 KB"
 *     @onTrigger={{this.triggerBannerUpload}}
 *     @onRemove={{this.removeBanner}}
 *   />
 */
import { on } from '@ember/modifier';
import lucideIcon from 'spordium/helpers/lucide-icon';

<template>
  <div class="relative rounded-2xl overflow-hidden border border-gray-800
              bg-gradient-to-br from-gray-900 to-gray-800">

    {{#if @preview}}
      {{! Preview mode }}
      <div class="relative h-52">
        <img src={{@preview}} alt="Banner preview" class="w-full h-full object-cover" />
        <div class="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent"></div>
        <button type="button" {{on "click" @onRemove}}
                aria-label="Remove banner"
                class="absolute top-4 right-4 w-9 h-9 rounded-full
                       bg-black/50 hover:bg-black/70 text-white
                       flex items-center justify-center transition-all">
          {{lucideIcon "x" size=16}}
        </button>
        {{#if @fileName}}
          <div class="absolute bottom-4 left-4 text-white text-sm font-medium opacity-70">
            {{@fileName}}
          </div>
        {{/if}}
      </div>

    {{else}}
      {{! Upload CTA }}
      <button type="button" {{on "click" @onTrigger}}
              class="w-full h-44 flex flex-col items-center justify-center gap-3 group
                     hover:bg-gray-800/50 transition-all duration-200">
        <div class="w-14 h-14 rounded-2xl bg-gray-800 border border-gray-700
                    flex items-center justify-center
                    group-hover:border-indigo-500/50 group-hover:bg-gray-700
                    transition-all duration-200 shadow-lg">
          {{lucideIcon "upload" size=28 class="text-indigo-400"}}
        </div>
        <div class="text-center">
          <p class="text-base font-semibold text-white group-hover:text-indigo-300 transition-colors">
            {{if @label @label "Upload Banner"}}
          </p>
          {{#if @hint}}
            <p class="text-xs text-gray-500 mt-1">{{@hint}}</p>
          {{/if}}
        </div>
      </button>
    {{/if}}

    {{! Error }}
    {{#if @error}}
      <p class="px-4 pb-3 text-xs text-rose-400 flex items-center gap-1.5">
        {{lucideIcon "alert-circle" size=12}}
        {{@error}}
      </p>
    {{/if}}
  </div>
</template>
