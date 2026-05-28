/**
 * GeoTextInput
 * ──────────────────────────────────────────────────────────────────────────────
 * A text (or url/tel) input that shows an animated geo-location spinner inside
 * the right edge while @isGeoFilling is true. Used for address fields that are
 * auto-filled via the browser's Geolocation API + Google Geocoding.
 *
 * @arg {string}   label         - Field label text.
 * @arg {string}   placeholder   - Input placeholder.
 * @arg {string}   value         - Controlled input value.
 * @arg {string}   [error]       - Validation error message (shows FormFieldError).
 * @arg {boolean}  isGeoFilling  - When true, shows the spinner icon.
 * @arg {string}   [type]        - Input type attribute (default: "text").
 * @arg {boolean}  [required]    - Appends a red asterisk to the label when true.
 * @arg {Function} onInput       - Called with the native input event on each keystroke.
 *
 * Usage:
 *   <GeoTextInput
 *     @label="City"
 *     @placeholder="City"
 *     @value={{this.clubCity}}
 *     @error={{this.errors.clubCity}}
 *     @isGeoFilling={{this.isGeoFilling}}
 *     @required={{true}}
 *     @onInput={{fn this.updateField 'clubCity'}}
 *   />
 */
import { on } from '@ember/modifier';
import FormFieldError from './form-field-error';

<template>
  <div>
    <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
      {{@label}}
      {{#if @required}}
        <span class="text-rose-500"> *</span>
      {{/if}}
    </label>

    <div class="relative">
      <input
        type={{if @type @type "text"}}
        placeholder={{@placeholder}}
        value={{@value}}
        {{on "input" @onInput}}
        class="w-full px-4 py-3 rounded-xl border transition-all duration-200
               {{if @error
                 'border-rose-400 dark:border-rose-500 bg-rose-50 dark:bg-rose-900/10'
                 'border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-800
                  focus:border-indigo-400 dark:focus:border-indigo-500'}}
               {{if @isGeoFilling 'pr-10' ''}}
               text-gray-900 dark:text-gray-100
               placeholder:text-gray-400 dark:placeholder:text-gray-500
               focus:outline-none focus:ring-2 focus:ring-indigo-400/30 dark:focus:ring-indigo-500/30"
      />
      {{#if @isGeoFilling}}
        <div class="absolute inset-y-0 right-3 flex items-center pointer-events-none">
          <svg class="w-4 h-4 text-indigo-400 animate-spin" viewBox="0 0 24 24"
               fill="none" stroke="currentColor" stroke-width="2.5"
               stroke-linecap="round" stroke-linejoin="round">
            <path d="M21 12a9 9 0 1 1-6.219-8.56"/>
          </svg>
        </div>
      {{/if}}
    </div>

    <FormFieldError @error={{@error}} />
  </div>
</template>
