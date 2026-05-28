/**
 * ManagerSearch
 * ──────────────────────────────────────────────────────────────────────────────
 * An email-based user-search field that lets the user add multiple club managers.
 * Displays selected managers as avatar + email tag chips (removable).
 * Searches after a 350 ms debounce once a valid email format is detected.
 * The parent owns all state; this component is purely presentational.
 *
 * @arg {Object[]} selectedManagers
 *   Array of already-selected user objects. Each object must have:
 *     - userid           {string}  — unique key used for add/remove
 *     - user_email       {string}  — displayed in the chip
 *     - user_primary_pic {string?} — avatar URL (falls back to SVG placeholder)
 *     - user_fullname    {{first_name: string, last_name: string}?}
 *
 * @arg {string}   searchQuery     - Controlled value of the search input.
 * @arg {Object[]} searchResults   - Filtered list of users returned by the API.
 *   Each object has the same shape as selectedManagers entries.
 * @arg {boolean}  searchOpen      - Whether the results dropdown is visible.
 * @arg {boolean}  searchLoading   - Shows a spinner in the search icon slot.
 * @arg {string}   [error]         - Validation error for the managers field.
 * @arg {Function} onInput         - Called with the native `input` event on the search field.
 * @arg {Function} onSelect        - Called with (user: Object) when a result row is clicked.
 * @arg {Function} onRemove        - Called with (userid: string) when a chip × is clicked.
 * @arg {Function} onCloseDropdown - Called (no args) when the backdrop is clicked.
 *
 * Usage:
 *   <ManagerSearch
 *     @selectedManagers={{this.selectedManagers}}
 *     @searchQuery={{this.managerSearchQuery}}
 *     @searchResults={{this.managerSearchResults}}
 *     @searchOpen={{this.managerSearchOpen}}
 *     @searchLoading={{this.managerSearchLoading}}
 *     @error={{this.errors.managers}}
 *     @onInput={{this.onManagerInput}}
 *     @onSelect={{this.selectManager}}
 *     @onRemove={{this.removeManager}}
 *     @onCloseDropdown={{this.closeManagerDropdown}}
 *   />
 */
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import FormFieldError from './form-field-error';

<template>
  <div>
    <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
      Club Managers <span class="text-rose-500">*</span>
    </label>

    {{! Selected manager chips }}
    {{#if @selectedManagers.length}}
      <div class="flex flex-wrap gap-2 mb-2">
        {{#each @selectedManagers as |mgr|}}
          <span class="inline-flex items-center gap-2 pl-1.5 pr-2.5 py-1 rounded-full
                       bg-gradient-to-r from-indigo-50 to-violet-50
                       dark:from-indigo-900/40 dark:to-violet-900/30
                       border border-indigo-200 dark:border-indigo-700/60
                       shadow-sm shadow-indigo-500/10">

            {{! Avatar }}
            <span class="w-6 h-6 rounded-full overflow-hidden shrink-0 ring-1 ring-indigo-300 dark:ring-indigo-600">
              {{#if mgr.user_primary_pic}}
                <img src={{mgr.user_primary_pic}} alt={{mgr.user_email}}
                     class="w-full h-full object-cover" />
              {{else}}
                <span class="w-full h-full flex items-center justify-center
                             bg-indigo-100 dark:bg-indigo-800">
                  <svg class="w-3.5 h-3.5 text-indigo-500 dark:text-indigo-300"
                       viewBox="0 0 24 24" fill="none" stroke="currentColor"
                       stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
                    <circle cx="12" cy="7" r="4"/>
                  </svg>
                </span>
              {{/if}}
            </span>

            <span class="text-xs font-semibold text-indigo-700 dark:text-indigo-300 max-w-[160px] truncate">
              {{mgr.user_email}}
            </span>

            <button type="button" {{on "click" (fn @onRemove mgr.userid)}}
                    class="ml-0.5 flex items-center justify-center w-4 h-4 rounded-full
                           text-indigo-400 hover:text-white hover:bg-indigo-500
                           dark:text-indigo-400 dark:hover:bg-indigo-500
                           transition-all duration-150">
              <svg class="w-2.5 h-2.5" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                   stroke-width="3" stroke-linecap="round">
                <path d="M18 6L6 18M6 6l12 12"/>
              </svg>
            </button>
          </span>
        {{/each}}
      </div>
    {{/if}}

    <FormFieldError @error={{@error}} />

    {{! Search input + dropdown — always visible to allow adding multiple managers }}
    <div class="relative">
      <div class="relative">
        <input
          type="text"
          placeholder={{if @selectedManagers.length "Add another manager by email…" "Search manager by email…"}}
          value={{@searchQuery}}
          {{on "input" @onInput}}
          class="w-full pl-10 pr-4 py-3 rounded-xl border border-gray-200 dark:border-gray-600
                 bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-gray-100
                 placeholder:text-gray-400 dark:placeholder:text-gray-500
                 focus:outline-none focus:ring-2 focus:ring-indigo-400/30 dark:focus:ring-indigo-500/30
                 focus:border-indigo-400 dark:focus:border-indigo-500
                 transition-all duration-200"
        />

        {{! Search / loading icon }}
        <div class="pointer-events-none absolute inset-y-0 left-3 flex items-center">
          {{#if @searchLoading}}
            <svg class="w-4 h-4 text-indigo-400 animate-spin" viewBox="0 0 24 24" fill="none"
                 stroke="currentColor" stroke-width="2.5" stroke-linecap="round">
              <path d="M21 12a9 9 0 1 1-6.219-8.56"/>
            </svg>
          {{else}}
            <svg class="w-4 h-4 text-gray-400" viewBox="0 0 24 24" fill="none"
                 stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <circle cx="11" cy="11" r="8"/><path d="M21 21l-4.35-4.35"/>
            </svg>
          {{/if}}
        </div>
      </div>

      {{! Backdrop (closes dropdown on outside click) }}
      {{#if @searchOpen}}
        <button type="button" class="fixed inset-0 z-10" {{on "click" @onCloseDropdown}}></button>

        {{! Results dropdown }}
        <div class="absolute top-full left-0 right-0 z-20 mt-2
                    bg-white dark:bg-gray-800 rounded-xl
                    border border-gray-100 dark:border-gray-700
                    shadow-2xl shadow-black/10 overflow-hidden
                    animate-fade-in">
          {{#each @searchResults as |user|}}
            <button
              type="button"
              {{on "click" (fn @onSelect user)}}
              class="w-full flex items-center gap-3 px-4 py-3
                     hover:bg-indigo-50 dark:hover:bg-indigo-900/20
                     border-b border-gray-50 dark:border-gray-700/50 last:border-0
                     transition-colors duration-150 text-left group"
            >
              {{! Avatar }}
              <span class="w-9 h-9 rounded-full overflow-hidden shrink-0
                           ring-2 ring-gray-100 dark:ring-gray-700
                           group-hover:ring-indigo-200 dark:group-hover:ring-indigo-700
                           transition-all">
                {{#if user.user_primary_pic}}
                  <img src={{user.user_primary_pic}} alt={{user.user_email}}
                       class="w-full h-full object-cover" />
                {{else}}
                  <span class="w-full h-full flex items-center justify-center
                               bg-gradient-to-br from-indigo-100 to-violet-100
                               dark:from-indigo-900/60 dark:to-violet-900/60">
                    <svg class="w-4 h-4 text-indigo-500 dark:text-indigo-300"
                         viewBox="0 0 24 24" fill="none" stroke="currentColor"
                         stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                      <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
                      <circle cx="12" cy="7" r="4"/>
                    </svg>
                  </span>
                {{/if}}
              </span>

              {{! Info }}
              <div class="flex-1 min-w-0">
                <p class="text-sm font-semibold text-gray-900 dark:text-gray-100 truncate
                          group-hover:text-indigo-700 dark:group-hover:text-indigo-300 transition-colors">
                  {{user.user_email}}
                </p>
                {{#if user.user_fullname}}
                  <p class="text-xs text-gray-400 dark:text-gray-500 truncate">
                    {{user.user_fullname.first_name}} {{user.user_fullname.last_name}}
                  </p>
                {{else}}
                  <p class="text-xs text-gray-300 dark:text-gray-600 italic">No display name</p>
                {{/if}}
              </div>

              {{! Add hint icon }}
              <svg class="w-4 h-4 shrink-0 text-gray-300 dark:text-gray-600
                          group-hover:text-indigo-500 dark:group-hover:text-indigo-400
                          transition-colors"
                   viewBox="0 0 24 24" fill="none" stroke="currentColor"
                   stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                <circle cx="12" cy="12" r="10"/><path d="M12 8v8M8 12h8"/>
              </svg>
            </button>
          {{/each}}
        </div>
      {{/if}}
    </div>
  </div>
</template>
