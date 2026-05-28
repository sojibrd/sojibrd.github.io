import Component from '@glimmer/component';

// ══════════════════════════════════════════════════════════════════════════════
// CardSkeleton — animated placeholder shown while tournament list loads
// ══════════════════════════════════════════════════════════════════════════════
export default class TournamentCardSkeleton extends Component {
  get items() { return [1, 2, 3, 4, 5, 6, 7, 8]; }

  <template>
    {{#each this.items as |i|}}
      <div
        key={{i}}
        class="bg-white dark:bg-gray-800 rounded-2xl overflow-hidden border
               border-gray-100 dark:border-gray-700 animate-pulse"
      >
        {{! Cover image placeholder }}
        <div class="h-36 bg-gray-200 dark:bg-gray-700"></div>

        <div class="p-4 space-y-3">
          {{! Sport badge + status }}
          <div class="flex items-center justify-between">
            <div class="h-5 w-16 bg-gray-200 dark:bg-gray-700 rounded-full"></div>
            <div class="h-5 w-20 bg-gray-200 dark:bg-gray-700 rounded-full"></div>
          </div>

          {{! Title }}
          <div class="h-4 bg-gray-200 dark:bg-gray-700 rounded w-3/4"></div>
          <div class="h-4 bg-gray-200 dark:bg-gray-700 rounded w-1/2"></div>

          {{! Meta row }}
          <div class="flex gap-3 pt-1">
            <div class="h-3 bg-gray-200 dark:bg-gray-700 rounded w-20"></div>
            <div class="h-3 bg-gray-200 dark:bg-gray-700 rounded w-16"></div>
          </div>

          {{! Teams / prize row }}
          <div class="flex items-center justify-between pt-1">
            <div class="h-3 bg-gray-200 dark:bg-gray-700 rounded w-24"></div>
            <div class="h-6 bg-gray-200 dark:bg-gray-700 rounded-lg w-20"></div>
          </div>
        </div>
      </div>
    {{/each}}
  </template>
}
