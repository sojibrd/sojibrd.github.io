/**
 * SportsMultiSelect
 * ──────────────────────────────────────────────────────────────────────────────
 * A scope-aware sports multi-select dropdown with chip display.
 *
 * Behaviour driven by `@sportsScope`:
 *   - "Single Sports" — only one sport can be selected at a time.
 *   - "Multi Sports"  — multiple selections are allowed (minimum 2 required by
 *                       the parent's validator).
 *   - unset           — the trigger button is disabled with a warning hint.
 *
 * The dropdown is controlled externally: the parent toggles `@isOpen` via
 * `@onToggle` and closes it via `@onClose` (called when the backdrop is clicked).
 * The parent also handles the selection logic (e.g. enforcing single-sport cap)
 * via `@onToggleSport`.
 *
 * The parent is responsible for all state; this component is purely presentational.
 *
 * @arg {string}   sportsScope
 *   Current scope value — "" | "Single Sports" | "Multi Sports".
 *   Controls whether the trigger is enabled and the footer hint text.
 * @arg {string[]} selectedSports
 *   Array of currently-selected sport name strings (used for chip display +
 *   the label summary).
 * @arg {Array<{name: string, selected: boolean}>} sportsWithSelection
 *   Full sports list pre-annotated with `selected` flags.
 * @arg {boolean}  isOpen         - Whether the dropdown panel is visible.
 * @arg {string}   [error]        - Validation error for the sports field.
 * @arg {boolean}  [required]     - Shows asterisk in the label.
 * @arg {Function} onToggle       - Called (no args) to open/close the dropdown.
 * @arg {Function} onClose        - Called (no args) to close the dropdown (backdrop click).
 * @arg {Function} onToggleSport  - Called with (sportName: string) to select/deselect.
 *
 * Usage:
 *   <SportsMultiSelect
 *     @sportsScope={{this.sportsScope}}
 *     @selectedSports={{this.selectedSports}}
 *     @sportsWithSelection={{this.sportsWithSelection}}
 *     @isOpen={{this.sportsDropdownOpen}}
 *     @error={{this.errors.sports}}
 *     @required={{true}}
 *     @onToggle={{this.toggleSportsDropdown}}
 *     @onClose={{this.closeSportsDropdown}}
 *     @onToggleSport={{this.toggleSport}}
 *   />
 */
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { eq } from 'ember-truth-helpers';
import FormFieldError from './form-field-error';

<template>
  <div>
    <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
      Sports
      {{#if @required}}<span class="text-rose-500"> *</span>{{/if}}
      {{#unless @sportsScope}}
        <span class="ml-1.5 text-xs font-normal text-amber-500 dark:text-amber-400">
          — select Sports Scope first
        </span>
      {{/unless}}
    </label>

    <div class="relative">

      {{! Trigger button }}
      <button
        type="button"
        disabled={{unless @sportsScope true}}
        {{on "click" @onToggle}}
        class="w-full flex items-center justify-between pl-4 pr-3 py-3 rounded-xl
               border transition-all duration-200 text-left
               {{if @sportsScope
                 (if @error
                   'border-rose-400 dark:border-rose-500 bg-rose-50 dark:bg-rose-900/10'
                   'border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-800
                    hover:border-indigo-300 dark:hover:border-indigo-500
                    focus:outline-none focus:ring-2 focus:ring-indigo-400/30
                    dark:focus:ring-indigo-500/30 focus:border-indigo-400 dark:focus:border-indigo-500')
                 'border-gray-200 dark:border-gray-700 bg-gray-100 dark:bg-gray-800/50
                  opacity-50 cursor-not-allowed'}}"
      >
        <span class="text-sm {{if @selectedSports.length 'text-gray-900 dark:text-gray-100' 'text-gray-400 dark:text-gray-500'}}">
          {{#if @selectedSports.length}}
            {{#if (eq @selectedSports.length 1)}}
              {{@selectedSports}}
            {{else}}
              {{@selectedSports.length}} sports selected
            {{/if}}
          {{else}}
            Select sports
          {{/if}}
        </span>
        <svg class="w-4 h-4 text-gray-400 transition-transform duration-200
                   {{if @isOpen 'rotate-180' ''}}"
             viewBox="0 0 24 24" fill="none" stroke="currentColor"
             stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M6 9l6 6 6-6"/>
        </svg>
      </button>

      {{! Backdrop (closes dropdown on outside click) }}
      {{#if @isOpen}}
        <button type="button" class="fixed inset-0 z-10" {{on "click" @onClose}}></button>

        {{! Dropdown panel }}
        <div class="absolute top-full left-0 right-0 z-20 mt-2
                    bg-white dark:bg-gray-800 rounded-xl
                    border border-gray-100 dark:border-gray-700
                    shadow-xl shadow-black/10 overflow-hidden
                    animate-fade-in">

          {{! Sport option rows }}
          <div class="p-2 grid grid-cols-2 gap-1">
            {{#each @sportsWithSelection as |sport|}}
              <button
                type="button"
                {{on "click" (fn @onToggleSport sport.name)}}
                class="flex items-center gap-2.5 px-3 py-2.5 rounded-lg
                       text-sm font-medium text-left transition-all duration-150
                       {{if sport.selected
                         'bg-indigo-50 dark:bg-indigo-900/30 text-indigo-700 dark:text-indigo-300'
                         'text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700/50'}}"
              >
                {{! Custom checkbox }}
                <span class="w-4 h-4 rounded border-2 flex items-center justify-center shrink-0
                             transition-colors duration-150
                             {{if sport.selected 'bg-indigo-600 border-indigo-600' 'border-gray-300 dark:border-gray-500'}}">
                  {{#if sport.selected}}
                    <svg class="w-2.5 h-2.5 text-white" viewBox="0 0 24 24" fill="none"
                         stroke="currentColor" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round">
                      <path d="M5 13l4 4L19 7"/>
                    </svg>
                  {{/if}}
                </span>
                {{sport.name}}
              </button>
            {{/each}}
          </div>

          {{! Footer: count + scope hint }}
          <div class="px-3 py-2 border-t border-gray-100 dark:border-gray-700
                      bg-gray-50 dark:bg-gray-700/30
                      flex items-center justify-between gap-2">
            <p class="text-xs text-indigo-600 dark:text-indigo-400 font-medium">
              {{#if @selectedSports.length}}
                {{@selectedSports.length}} sport(s) selected
              {{else}}
                No sports selected yet
              {{/if}}
            </p>
            {{#if @sportsScope}}
              <span class="text-xs px-2 py-0.5 rounded-full font-semibold
                           {{if (eq @sportsScope 'Single Sports')
                             'bg-amber-100 dark:bg-amber-900/30 text-amber-700 dark:text-amber-400'
                             'bg-indigo-100 dark:bg-indigo-900/30 text-indigo-700 dark:text-indigo-400'}}">
                {{#if (eq @sportsScope 'Single Sports')}}
                  Pick 1 only
                {{else}}
                  Pick 2+
                {{/if}}
              </span>
            {{/if}}
          </div>
        </div>
      {{/if}}

    </div>

    {{! Validation error }}
    <FormFieldError @error={{@error}} />

    {{! Selected sports chips }}
    {{#if @selectedSports.length}}
      <div class="mt-2 flex flex-wrap gap-1.5">
        {{#each @selectedSports as |sport|}}
          <span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-full
                       bg-indigo-100 dark:bg-indigo-900/40
                       text-indigo-700 dark:text-indigo-300 text-xs font-medium">
            {{sport}}
            <button type="button" {{on "click" (fn @onToggleSport sport)}}
                    class="hover:text-indigo-500 transition-colors">
              <svg class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                   stroke-width="3" stroke-linecap="round">
                <path d="M18 6L6 18M6 6l12 12"/>
              </svg>
            </button>
          </span>
        {{/each}}
      </div>
    {{/if}}
  </div>
</template>
