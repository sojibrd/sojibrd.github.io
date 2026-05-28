import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { service } from '@ember/service';
import { LinkTo } from '@ember/routing';
import Card from './card';
import CardSkeleton from './card-skeleton';
import EmptyState from './empty-state';
import lucideIcon from 'spordium/helpers/lucide-icon';

const API_BASE = 'https://spordiumapi.adnanfoundation.com';

// ══════════════════════════════════════════════════════════════════════════════
// Drafts — authenticated user's draft (unpublished) tournaments
// ══════════════════════════════════════════════════════════════════════════════
export default class TournamentDraftsList extends Component {
  @service session;
  @service router;

  @tracked tournaments = [];
  @tracked isLoading = true;
  @tracked error = null;

  constructor(owner, args) {
    super(owner, args);
    this.fetchDrafts();
  }

  get isEmpty() {
    return !this.isLoading && !this.error && this.tournaments.length === 0;
  }
  get hasResults() {
    return !this.isLoading && !this.error && this.tournaments.length > 0;
  }

  async fetchDrafts() {
    this.isLoading = true;
    this.error = null;

    try {
      const res = await fetch(
        `${API_BASE}/tournament_v2/get-tournaments-by-owner/?tournament_owner=${this.session.currentUser?.user_id}&country_code=BD&limit=100&offset=0&tournament_status=draft`,
        {
          headers: {
            Authorization: `Bearer ${this.session.token}`,
            Accept: 'application/json',
          },
        },
      );
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json = await res.json();
      this.tournaments = json.data?.results ?? json.data ?? json.results ?? [];
    } catch {
      this.error = 'Failed to load drafts. Please try again.';
    } finally {
      this.isLoading = false;
    }
  }

  @action retry() {
    this.fetchDrafts();
  }

  @action openTournament(tournament) {
    // Draft → go to wizard to continue editing
    const id = tournament.tournament_id ?? tournament.id;
    this.router.transitionTo('tournament.create', id);
  }

  <template>
    <div class="min-h-screen bg-gray-50 dark:bg-gray-950">

      {{! Page header }}
      <div
        class="bg-white dark:bg-gray-900 border-b border-gray-200 dark:border-gray-700"
      >
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-3">
              <LinkTo
                @route="tournament.index"
                class="p-2 rounded-xl hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
              >
                {{lucideIcon "arrow-left" class="w-4 h-4 text-gray-500"}}
              </LinkTo>
              <div>
                <h1
                  class="text-xl font-extrabold text-gray-900 dark:text-white flex items-center gap-2"
                >
                  {{lucideIcon "file-edit" class="w-5 h-5 text-yellow-500"}}
                  My Drafts
                </h1>
                <p class="text-xs text-gray-500 dark:text-gray-400 mt-0.5">
                  Continue editing unpublished tournaments
                </p>
              </div>
            </div>

            {{! Tab switcher }}
            <div
              class="flex items-center gap-2 bg-gray-100 dark:bg-gray-800 rounded-xl p-1"
            >
              <LinkTo
                @route="tournament.drafts"
                class="px-4 py-1.5 text-sm font-semibold rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white shadow-sm"
              >
                Drafts
                {{#if this.hasResults}}
                  <span
                    class="ml-1.5 px-1.5 py-0.5 text-[10px] font-bold rounded-full bg-yellow-100 dark:bg-yellow-900/40 text-yellow-700 dark:text-yellow-400"
                  >
                    {{this.tournaments.length}}
                  </span>
                {{/if}}
              </LinkTo>
              <LinkTo
                @route="tournament.published"
                class="px-4 py-1.5 text-sm font-medium rounded-lg text-gray-500 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white transition-colors"
              >
                Published
              </LinkTo>
            </div>
          </div>
        </div>
      </div>

      {{! Content }}
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
        {{#if this.isLoading}}
          <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">
            <CardSkeleton />
          </div>

        {{else if this.error}}
          <div class="flex flex-col items-center justify-center py-20 gap-3">
            <p class="text-sm text-red-500">{{this.error}}</p>
            <button
              type="button"
              {{on "click" this.retry}}
              class="px-4 py-2 text-sm font-medium rounded-xl bg-blue-600 text-white hover:bg-blue-700"
            >
              Retry
            </button>
          </div>

        {{else if this.isEmpty}}
          <EmptyState
            @icon="file-edit"
            @heading="No drafts yet"
            @subtext="Create a tournament and save it as a draft to continue later."
          />

        {{else}}
          <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">
            {{#each this.tournaments as |t|}}
              <Card @tournament={{t}} @onClick={{this.openTournament}} />
            {{/each}}
          </div>
        {{/if}}
      </div>

    </div>
  </template>
}
