import Component from '@glimmer/component';
import { service } from '@ember/service';
import { on } from '@ember/modifier';
import { LinkTo } from '@ember/routing';
import AllList from './all-list';
import lucideIcon from 'spordium/helpers/lucide-icon';

// ══════════════════════════════════════════════════════════════════════════════
// TournamentListIndex — page wrapper for the public tournament grid
// Renders the hero header + AllList grid
// ══════════════════════════════════════════════════════════════════════════════
export default class TournamentListIndex extends Component {
  @service session;

  <template>
    <div class="min-h-screen bg-gray-50 dark:bg-gray-950">

      {{! Hero header }}
      <div class="bg-white dark:bg-gray-900 border-b border-gray-200 dark:border-gray-700">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
            <div>
              <h1 class="text-2xl font-extrabold text-gray-900 dark:text-white flex items-center gap-2">
                {{lucideIcon "trophy" class="w-6 h-6 text-yellow-500"}}
                Tournaments
              </h1>
              <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
                Browse and join tournaments near you
              </p>
            </div>

            <div class="flex items-center gap-3">
              {{#if this.session.isAuthenticated}}
                {{! My drafts / published links }}
                <LinkTo @route="tournament.drafts" class="px-4 py-2 text-sm font-medium rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:border-blue-400 transition-colors">
                  My Drafts
                </LinkTo>
                <LinkTo @route="tournament.published" class="px-4 py-2 text-sm font-medium rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:border-blue-400 transition-colors">
                  Published
                </LinkTo>

                {{!-- <LinkTo
                  @route="tournament.create"
                  class="inline-flex items-center gap-1.5 px-4 py-2 text-sm font-medium rounded-xl border border-gray-200 bg-cyan-600 hover:bg-cyan-500 text-white shadow-sm shadow-cyan-600/20 transition-all flex-shrink-0"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                  </svg>
                  Create Tournament
                </LinkTo> --}}

              {{/if}}
            </div>
          </div>
        </div>
      </div>

      {{! Content }}
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
        <AllList />
      </div>

    </div>
  </template>
}
