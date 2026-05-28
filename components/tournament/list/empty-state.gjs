import Component from '@glimmer/component';
import { on } from '@ember/modifier';
import lucideIcon from 'spordium/helpers/lucide-icon';

// ══════════════════════════════════════════════════════════════════════════════
// EmptyState — shown when tournament list has no results
//
// @arg {string}   heading   — Main message (default: "No tournaments found")
// @arg {string}   subtext   — Supporting text
// @arg {string}   icon      — Lucide icon name (default: "trophy")
// @arg {Function} onReset   — Optional "Clear filters" callback
// ══════════════════════════════════════════════════════════════════════════════
export default class TournamentEmptyState extends Component {
  get heading() { return this.args.heading ?? 'No tournaments found'; }
  get subtext()  { return this.args.subtext  ?? 'Try adjusting your search or filters.'; }
  get icon()     { return this.args.icon     ?? 'trophy'; }

  <template>
    <div class="flex flex-col items-center justify-center py-20 px-6 text-center">
      <div class="w-16 h-16 rounded-2xl bg-gray-100 dark:bg-gray-800 flex items-center
                  justify-center mb-5">
        {{lucideIcon this.icon class="w-8 h-8 text-gray-400 dark:text-gray-500"}}
      </div>

      <h3 class="text-base font-semibold text-gray-900 dark:text-white mb-1">
        {{this.heading}}
      </h3>
      <p class="text-sm text-gray-500 dark:text-gray-400 max-w-xs">
        {{this.subtext}}
      </p>

      {{#if @onReset}}
        <button
          type="button"
          {{on "click" @onReset}}
          class="mt-5 px-4 py-2 text-sm font-medium rounded-xl
                 bg-blue-600 text-white hover:bg-blue-700 transition-colors"
        >
          Clear filters
        </button>
      {{/if}}
    </div>
  </template>
}
