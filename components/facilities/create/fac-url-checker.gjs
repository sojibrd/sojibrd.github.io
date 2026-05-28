/**
 * FacUrlChecker
 * ──────────────────────────────────────────────────────────────────────────────
 * Facility URL name input with an availability check button. Shows green / red
 * feedback after the check and supports a validation error message.
 *
 * @arg {string}       value      - Current URL name value.
 * @arg {boolean|null} available  - null = unchecked, true = available, false = taken.
 * @arg {boolean}      isChecking - Disables button and shows loading state.
 * @arg {string}       [checkError] - Network / API error from the check call.
 * @arg {string}       [error]    - Validation error for the field itself.
 * @arg {Function}     onInput    - Called with the native `input` event.
 * @arg {Function}     onCheck    - Called (no args) when "Check URL" is clicked.
 *
 * Usage:
 *   <FacUrlChecker
 *     @value={{this.facilityUrlName}}
 *     @available={{this.urlAvailable}}
 *     @isChecking={{this.urlChecking}}
 *     @checkError={{this.urlCheckError}}
 *     @error={{this.errors.facilityUrlName}}
 *     @onInput={{this.onUrlNameInput}}
 *     @onCheck={{this.checkUrlName}}
 *   />
 */
import { on } from '@ember/modifier';
import { eq } from 'ember-truth-helpers';
import FormFieldError from '../../clubs/create/form-field-error';
import lucideIcon from 'spordium/helpers/lucide-icon';

<template>
  <div>
    <label class="block text-sm font-semibold text-gray-300 mb-1.5">
      Facility's URL Name <span class="text-rose-500">*</span>
    </label>

    <div class="flex gap-2">
      <div class="relative flex-1">
        <input
          type="text"
          placeholder="Enter Facility's URL Name"
          value={{@value}}
          {{on "input" @onInput}}
          class="w-full px-4 py-3 rounded-xl border transition-all duration-200
                 bg-gray-800 text-gray-100 placeholder:text-gray-500
                 focus:outline-none focus:ring-2 focus:ring-indigo-500/30
                 {{if @error
                   'border-rose-500'
                   (if (eq @available true)
                     'border-emerald-500'
                     (if (eq @available false)
                       'border-rose-500'
                       'border-gray-700 focus:border-indigo-500'))}}"
        />
        {{#if (eq @available true)}}
          <div class="absolute inset-y-0 right-3 flex items-center pointer-events-none">
            {{lucideIcon "check-circle" size=16 class="text-emerald-400"}}
          </div>
        {{/if}}
      </div>

      <button
        type="button"
        {{on "click" @onCheck}}
        disabled={{@isChecking}}
        class="shrink-0 inline-flex items-center gap-1.5 px-4 py-3 rounded-xl
               bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-semibold
               disabled:opacity-60 disabled:cursor-not-allowed
               transition-all duration-200 shadow-lg shadow-indigo-500/20"
      >
        {{#if @isChecking}}
          {{lucideIcon "loader" size=14 class="animate-spin"}}
          Checking…
        {{else}}
          Check URL
        {{/if}}
      </button>
    </div>

    {{#if (eq @available true)}}
      <p class="mt-1 text-xs text-emerald-400 flex items-center gap-1">
        {{lucideIcon "check" size=12}}
        URL name is available!
      </p>
    {{else if (eq @available false)}}
      <p class="mt-1 text-xs text-rose-400 flex items-center gap-1">
        {{lucideIcon "alert-circle" size=12}}
        URL name is already taken.
      </p>
    {{/if}}

    {{#if @checkError}}
      <p class="mt-1 text-xs text-rose-400">{{@checkError}}</p>
    {{/if}}

    <FormFieldError @error={{@error}} />
  </div>
</template>
