import Component from '@glimmer/component';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { eq } from 'ember-truth-helpers';
import lucideIcon from 'spordium/helpers/lucide-icon';

// @args:
//   selectedSport, isEditMode, isSaving, saveError, saveDisabled
//   nickName, jerseyNumber, matchFee, tournamentFee
//   selectedSkills, selectedPositions, skillSearch, positionSearch
//   showSkillDropdown, showPositionDropdown
//   filteredSkillOptions, filteredPositionOptions
//   sportMeta, roleRows, careerHighlights
//   onClose, onSubmit
//   onUpdateField, onUpdateSkillSearch, onOpenSkillDropdown, onCloseSkillDropdown, onToggleSkillDropdown
//   onSelectSkill, onRemoveSkillTag
//   onUpdatePositionSearch, onOpenPositionDropdown, onClosePositionDropdown, onTogglePositionDropdown
//   onSelectPosition, onRemovePositionTag
//   onAddHighlight, onRemoveHighlight, onUpdateHighlight
//   onUpdateRoleField, onAddRoleRow, onRemoveRoleRow

export default class SportProfileFormComponent extends Component {
  <template>
    <div
      class="fixed inset-0 z-50 flex items-center justify-center p-4"
      role="dialog"
      aria-modal="true"
      aria-label="Add sports profile form"
    >
      <div class="absolute inset-0 bg-black/70 backdrop-blur-sm" {{on "click" @onClose}}></div>
      <div class="relative z-10 w-full max-w-2xl bg-gray-900 rounded-2xl shadow-2xl ring-1 ring-white/10 max-h-[90vh] overflow-y-auto">

        <div class="sticky top-0 z-10 flex items-center justify-between px-6 py-5 border-b border-white/10 bg-gray-900/95 backdrop-blur-sm">
          <div class="flex items-center gap-3">
            <span class="text-2xl">{{@selectedSport.emoji}}</span>
            <div>
              <h2 class="text-lg font-extrabold bg-gradient-to-r from-indigo-400 to-violet-400 bg-clip-text text-transparent tracking-tight">
                {{if @isEditMode "Edit" "Add"}} Sports Profile
              </h2>
              <p class="text-xs text-gray-400 mt-0.5 capitalize">{{@selectedSport.label}} · {{if @isEditMode "Update your details" "Fill in your details"}}</p>
            </div>
          </div>
          <button type="button" aria-label="Close profile form" {{on "click" @onClose}}
            class="flex items-center justify-center w-8 h-8 rounded-full bg-white/5 hover:bg-white/10 text-gray-400 hover:text-white transition-colors">
            {{lucideIcon "x" size=16}}
          </button>
        </div>

        <form {{on "submit" @onSubmit}} class="px-6 py-6 space-y-5">

          {{! Nick Name }}
          <div class="flex flex-col gap-1.5 sm:flex-row sm:items-center sm:gap-4">
            <label class="text-sm font-semibold text-gray-300 sm:w-40 sm:shrink-0">
              Nick Name <span class="text-red-400 ml-0.5">*</span>
            </label>
            <input type="text" placeholder="Enter Nick Name" value={{@nickName}}
              {{on "input" (fn @onUpdateField "nickName")}}
              class="flex-1 bg-gray-800 border border-gray-700 text-white placeholder-gray-500 rounded-lg px-4 py-2.5 text-sm focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 focus:outline-none transition-colors"
            />
          </div>

          {{! Football: Playing Positions }}
          {{#if (eq @selectedSport.key "football")}}
            <div class="flex flex-col gap-1.5 sm:flex-row sm:items-start sm:gap-4">
              <label class="text-sm font-semibold text-gray-300 sm:w-40 sm:shrink-0 sm:pt-2">
                Playing positions <span class="text-red-400 ml-0.5">*</span>
              </label>
              <div class="flex-1 relative">
                <div class="min-h-[42px] flex flex-wrap gap-1.5 items-center bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 cursor-text focus-within:border-indigo-500 focus-within:ring-1 focus-within:ring-indigo-500 transition-colors">
                  {{#each @selectedPositions as |pos|}}
                    <span class="inline-flex items-center gap-1 bg-indigo-600/30 border border-indigo-500/50 text-indigo-300 text-xs font-semibold px-2 py-0.5 rounded-md">
                      {{pos}}
                      <button type="button" aria-label="Remove {{pos}}" {{on "click" (fn @onRemovePositionTag pos)}}
                        class="text-indigo-400 hover:text-white ml-0.5 leading-none">
                        {{lucideIcon "x" size=10}}
                      </button>
                    </span>
                  {{/each}}
                  <input type="text" placeholder={{if @selectedPositions.length "" "Select positions"}}
                    value={{@positionSearch}}
                    {{on "input" @onUpdatePositionSearch}}
                    {{on "focus" @onOpenPositionDropdown}}
                    {{on "blur" @onClosePositionDropdown}}
                    class="flex-1 bg-transparent text-sm text-white placeholder-gray-500 focus:outline-none min-w-[120px] py-0.5"
                  />
                  <button type="button" aria-label="Toggle positions dropdown" {{on "mousedown" @onTogglePositionDropdown}}
                    class="text-gray-500 hover:text-gray-300 shrink-0 ml-1">
                    {{lucideIcon "chevron-down" size=16}}
                  </button>
                </div>
                {{#if @showPositionDropdown}}
                  <div class="absolute z-20 mt-1 w-full bg-gray-800 border border-gray-700 rounded-lg shadow-xl max-h-52 overflow-y-auto">
                    {{#if @filteredPositionOptions.length}}
                      {{#each @filteredPositionOptions as |pos|}}
                        <button type="button" {{on "mousedown" (fn @onSelectPosition pos)}}
                          class="w-full text-left px-4 py-2.5 text-sm text-gray-200 hover:bg-indigo-600/30 hover:text-white transition-colors">
                          {{pos}}
                        </button>
                      {{/each}}
                    {{else}}
                      <p class="px-4 py-3 text-sm text-gray-500 italic">No matching positions found.</p>
                    {{/if}}
                  </div>
                {{/if}}
              </div>
            </div>

            {{! Jersey Number }}
            <div class="flex flex-col gap-1.5 sm:flex-row sm:items-center sm:gap-4">
              <label class="text-sm font-semibold text-gray-300 sm:w-40 sm:shrink-0">
                Jersey Number <span class="text-red-400 ml-0.5">*</span>
              </label>
              <input type="text" placeholder="Enter Jersey Number" value={{@jerseyNumber}}
                {{on "input" (fn @onUpdateField "jerseyNumber")}}
                class="flex-1 bg-gray-800 border border-gray-700 text-white placeholder-gray-500 rounded-lg px-4 py-2.5 text-sm focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 focus:outline-none transition-colors"
              />
            </div>
          {{/if}}

          {{! Skills }}
          <div class="flex flex-col gap-1.5 sm:flex-row sm:items-start sm:gap-4">
            <label class="text-sm font-semibold text-gray-300 sm:w-40 sm:shrink-0 sm:pt-2">
              {{if (eq @selectedSport.key "cricket") "Skills or Roles" "Skills"}}
              <span class="text-red-400 ml-0.5">*</span>
            </label>
            <div class="flex-1 relative">
              <div class="min-h-[42px] flex flex-wrap gap-1.5 items-center bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 cursor-text focus-within:border-indigo-500 focus-within:ring-1 focus-within:ring-indigo-500 transition-colors">
                {{#each @selectedSkills as |skill|}}
                  <span class="inline-flex items-center gap-1 bg-indigo-600/30 border border-indigo-500/50 text-indigo-300 text-xs font-semibold px-2 py-0.5 rounded-md">
                    {{skill}}
                    <button type="button" aria-label="Remove {{skill}}" {{on "click" (fn @onRemoveSkillTag skill)}}
                      class="text-indigo-400 hover:text-white ml-0.5 leading-none">
                      {{lucideIcon "x" size=10}}
                    </button>
                  </span>
                {{/each}}
                <input type="text" placeholder={{if @selectedSkills.length "" "Select skills"}}
                  value={{@skillSearch}}
                  {{on "input" @onUpdateSkillSearch}}
                  {{on "focus" @onOpenSkillDropdown}}
                  {{on "blur" @onCloseSkillDropdown}}
                  class="flex-1 bg-transparent text-sm text-white placeholder-gray-500 focus:outline-none min-w-[120px] py-0.5"
                />
                <button type="button" aria-label="Toggle skills dropdown" {{on "mousedown" @onToggleSkillDropdown}}
                  class="text-gray-500 hover:text-gray-300 shrink-0 ml-1">
                  {{lucideIcon "chevron-down" size=16}}
                </button>
              </div>
              {{#if @showSkillDropdown}}
                <div class="absolute z-20 mt-1 w-full bg-gray-800 border border-gray-700 rounded-lg shadow-xl max-h-52 overflow-y-auto">
                  {{#if @filteredSkillOptions.length}}
                    {{#each @filteredSkillOptions as |skill|}}
                      <button type="button" {{on "mousedown" (fn @onSelectSkill skill)}}
                        class="w-full text-left px-4 py-2.5 text-sm text-gray-200 hover:bg-indigo-600/30 hover:text-white transition-colors">
                        {{skill}}
                      </button>
                    {{/each}}
                  {{else}}
                    <p class="px-4 py-3 text-sm text-gray-500 italic">No matching skills found.</p>
                  {{/if}}
                </div>
              {{/if}}
            </div>
          </div>

          {{! Match Fee }}
          <div class="flex flex-col gap-1.5 sm:flex-row sm:items-center sm:gap-4">
            <label class="text-sm font-semibold text-gray-300 sm:w-40 sm:shrink-0">Match Fee</label>
            <div class="flex-1 flex rounded-lg overflow-hidden border border-gray-700 focus-within:border-indigo-500 focus-within:ring-1 focus-within:ring-indigo-500 transition-colors">
              <span class="bg-gray-700 text-gray-300 px-3 flex items-center text-sm font-bold border-r border-gray-600 shrink-0">BDT</span>
              <input type="text" placeholder="Enter Match Fee" value={{@matchFee}}
                {{on "input" (fn @onUpdateField "matchFee")}}
                class="flex-1 bg-gray-800 text-white placeholder-gray-500 px-4 py-2.5 text-sm focus:outline-none"
              />
            </div>
          </div>

          {{! Tournament Fee }}
          <div class="flex flex-col gap-1.5 sm:flex-row sm:items-center sm:gap-4">
            <label class="text-sm font-semibold text-gray-300 sm:w-40 sm:shrink-0">Tournament Fee</label>
            <div class="flex-1 flex rounded-lg overflow-hidden border border-gray-700 focus-within:border-indigo-500 focus-within:ring-1 focus-within:ring-indigo-500 transition-colors">
              <span class="bg-gray-700 text-gray-300 px-3 flex items-center text-sm font-bold border-r border-gray-600 shrink-0">BDT</span>
              <input type="text" placeholder="Enter Tournament Fee" value={{@tournamentFee}}
                {{on "input" (fn @onUpdateField "tournamentFee")}}
                class="flex-1 bg-gray-800 text-white placeholder-gray-500 px-4 py-2.5 text-sm focus:outline-none"
              />
            </div>
          </div>

          {{! Cricket only: Highlights of Career }}
          {{#if (eq @selectedSport.key "cricket")}}
            <div class="flex flex-col gap-1.5 sm:flex-row sm:items-start sm:gap-4">
              <label class="text-sm font-semibold text-gray-300 sm:w-40 sm:shrink-0 sm:pt-2.5">Highlights of Career</label>
              <div class="flex-1 space-y-2">
                {{#each @careerHighlights as |highlight hlIndex|}}
                  <div class="flex items-center gap-2">
                    <input type="text" placeholder="Enter Highlights of Career link" value={{highlight}}
                      {{on "input" (fn @onUpdateHighlight hlIndex)}}
                      class="flex-1 bg-gray-800 border border-gray-700 text-white placeholder-gray-500 rounded-lg px-4 py-2.5 text-sm focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 focus:outline-none transition-colors"
                    />
                    {{#if (eq hlIndex 0)}}
                      <button type="button" aria-label="Add highlight" {{on "click" @onAddHighlight}}
                        class="flex items-center justify-center w-8 h-8 rounded-lg bg-indigo-600/20 hover:bg-indigo-600/40 text-indigo-400 hover:text-indigo-300 border border-indigo-500/30 transition-colors shrink-0">
                        {{lucideIcon "plus" size=14}}
                      </button>
                    {{else}}
                      <button type="button" aria-label="Remove highlight" {{on "click" (fn @onRemoveHighlight hlIndex)}}
                        class="flex items-center justify-center w-8 h-8 rounded-lg bg-red-500/10 hover:bg-red-500/20 text-red-400 hover:text-red-300 border border-red-500/20 transition-colors shrink-0">
                        {{lucideIcon "minus" size=14}}
                      </button>
                    {{/if}}
                  </div>
                {{/each}}
              </div>
            </div>
          {{/if}}

          {{! I Can Be (role rows) }}
          <div class="flex flex-col gap-1.5 sm:flex-row sm:items-start sm:gap-4">
            <label class="text-sm font-semibold text-gray-300 sm:w-40 sm:shrink-0 sm:pt-2.5">I Can Be</label>
            <div class="flex-1 space-y-2.5">
              {{#each @roleRows as |row i|}}
                <div class="flex items-center gap-2">
                  <div class="flex-1 relative">
                    <select {{on "change" (fn @onUpdateRoleField i "role")}}
                      class="w-full bg-gray-800 border border-gray-700 text-white rounded-lg px-4 py-2.5 text-sm appearance-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 focus:outline-none transition-colors">
                      <option value="" disabled class="text-gray-500 bg-gray-800">Select Role</option>
                      {{#each @sportMeta.roles as |role|}}
                        <option value={{role}} selected={{eq row.role role}} class="bg-gray-800 text-white">{{role}}</option>
                      {{/each}}
                    </select>
                    <span class="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-gray-500">
                      {{lucideIcon "chevron-down" size=16}}
                    </span>
                  </div>
                  <div class="flex rounded-lg overflow-hidden border border-gray-700 focus-within:border-indigo-500 focus-within:ring-1 focus-within:ring-indigo-500 transition-colors w-28 sm:w-36 shrink-0">
                    <span class="bg-gray-700 text-gray-300 px-2.5 flex items-center text-xs font-bold border-r border-gray-600 shrink-0">BDT</span>
                    <input type="number" min="0" value={{row.fee}}
                      {{on "input" (fn @onUpdateRoleField i "fee")}}
                      class="flex-1 bg-gray-800 text-white px-2.5 py-2.5 text-sm focus:outline-none w-0 min-w-0"
                    />
                  </div>
                  <button type="button" aria-label="Remove role" {{on "click" (fn @onRemoveRoleRow i)}}
                    class="flex items-center justify-center w-8 h-8 rounded-lg bg-red-500/10 hover:bg-red-500/20 text-red-400 hover:text-red-300 border border-red-500/20 hover:border-red-500/40 transition-colors shrink-0">
                    {{lucideIcon "x" size=14}}
                  </button>
                </div>
              {{/each}}
              <button type="button" {{on "click" @onAddRoleRow}}
                class="inline-flex items-center gap-1.5 text-xs font-bold text-indigo-400 hover:text-indigo-300 border border-dashed border-indigo-500/40 hover:border-indigo-400/60 px-4 py-2 rounded-lg transition-colors">
                {{lucideIcon "plus" size=13 class="shrink-0"}}
                Add More
              </button>
            </div>
          </div>

          {{! Error }}
          {{#if @saveError}}
            <div class="flex items-start gap-2 px-4 py-3 rounded-lg bg-red-500/10 border border-red-500/30 text-red-400 text-xs">
              <svg class="w-4 h-4 shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126z"/>
              </svg>
              {{@saveError}}
            </div>
          {{/if}}

          {{! Save button }}
          <div class="border-t border-white/10 pt-4 flex justify-center">
            <button type="submit" disabled={{@saveDisabled}}
              class="inline-flex items-center gap-2 bg-indigo-600 hover:bg-indigo-500 active:bg-indigo-700 disabled:opacity-60 disabled:cursor-not-allowed text-white font-bold px-16 py-2.5 rounded-lg transition-colors shadow-lg shadow-indigo-500/20 text-sm uppercase tracking-widest">
              {{#if @isSaving}}
                <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8z"/>
                </svg>
                Saving…
              {{else}}
                Save
              {{/if}}
            </button>
          </div>

        </form>
      </div>
    </div>
  </template>
}
