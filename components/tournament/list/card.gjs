import Component from '@glimmer/component';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { service } from '@ember/service';
import lucideIcon from 'spordium/helpers/lucide-icon';

const IMAGE_BASE = 'https://ag-khela.s3.ap-south-1.amazonaws.com/';

const STATUS_STYLES = {
  upcoming:
    'bg-blue-100  dark:bg-blue-900/40  text-blue-700  dark:text-blue-300',
  live: 'bg-green-100 dark:bg-green-900/40 text-green-700 dark:text-green-300',
  completed:
    'bg-gray-100  dark:bg-gray-700     text-gray-600  dark:text-gray-300',
  cancelled:
    'bg-red-100   dark:bg-red-900/40   text-red-700   dark:text-red-300',
  draft:
    'bg-yellow-100 dark:bg-yellow-900/40 text-yellow-700 dark:text-yellow-300',
};

const STATUS_LABELS = {
  upcoming: 'Upcoming',
  live: 'Live',
  completed: 'Completed',
  cancelled: 'Cancelled',
  draft: 'Draft',
};

// ══════════════════════════════════════════════════════════════════════════════
// Card — single tournament card in the grid
//
// @arg {Object}   tournament  — tournament data object
// @arg {Function} onClick     — called with tournament object on click
// ══════════════════════════════════════════════════════════════════════════════
export default class TournamentCard extends Component {
  @service router;

  get t() {
    return this.args.tournament ?? {};
  }
  get coverUrl() {
    return this.t.tournament_logo
      ? `${IMAGE_BASE}${this.t.tournament_logo}`
      : '/placeholder.png';
  }
  get logoUrl() {
    return this.t.tournament_logo
      ? `${IMAGE_BASE}${this.t.tournament_logo}`
      : null;
  }
  get status() {
    return this.t.status ?? 'upcoming';
  }
  get statusStyle() {
    return STATUS_STYLES[this.status] ?? STATUS_STYLES.upcoming;
  }
  get statusLabel() {
    return STATUS_LABELS[this.status] ?? this.status;
  }
  get sport() {
    return this.t.sport ?? '';
  }
  get title() {
    return this.t.tournament_name ?? 'Untitled Tournament';
  }
  get location() {
    return [this.t.city, this.t.country].filter(Boolean).join(', ') || 'TBA';
  }
  get startDate() {
    if (!this.t.start_date) return 'TBA';
    return new Date(this.t.start_date).toLocaleDateString('en-GB', {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
    });
  }
  get teams() {
    return this.t.tournament_paid_number_of_teams ?? 0;
  }
  get maxTeams() {
    return this.t.max_teams ?? 0;
  }
  get prize() {
    if (!this.t.prize_pool) return null;
    return `৳${Number(this.t.prize_pool).toLocaleString()}`;
  }
  get format() {
    return this.t.match_format ?? '';
  }
  get isFull() {
    return this.maxTeams > 0 && this.teams >= this.maxTeams;
  }

  <template>
    <button
      type="button"
      {{on "click" (fn @onClick this.t)}}
      class="group w-full text-left bg-white dark:bg-gray-800 rounded-2xl overflow-hidden border border-gray-100 dark:border-gray-700 hover:border-blue-300 dark:hover:border-blue-600 hover:shadow-lg hover:shadow-blue-500/10 transition-all duration-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-500"
    >
      {{! Cover image }}
      <div class="relative h-36 overflow-hidden bg-gray-100 dark:bg-gray-700">
        <img
          src={{this.coverUrl}}
          alt={{this.title}}
          class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
          loading="lazy"
        />

        {{! Organizer logo }}
        {{!-- {{#if this.logoUrl}}
          <div
            class="absolute bottom-2 left-2 w-8 h-8 rounded-lg overflow-hidden border-2 border-white dark:border-gray-800 shadow-sm bg-white"
          >
            <img
              src={{this.logoUrl}}
              alt="organizer"
              class="w-full h-full object-cover"
            />
          </div>
        {{/if}} --}}

        {{! Status badge }}
        <div class="absolute top-2 right-2">
          <span
            class="px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider rounded-full
              {{this.statusStyle}}"
          >
            {{this.statusLabel}}
          </span>
        </div>
      </div>

      {{! Card body }}
      <div class="p-4 space-y-2.5">
        {{! Sport + format }}
        <div class="flex items-center gap-2 flex-wrap">
          {{#if this.sport}}
            <span
              class="px-2 py-0.5 text-[10px] font-semibold rounded-full bg-blue-50 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400"
            >
              {{this.sport}}
            </span>
          {{/if}}
          {{#if this.format}}
            <span
              class="px-2 py-0.5 text-[10px] font-semibold rounded-full bg-gray-100 dark:bg-gray-700 text-gray-500 dark:text-gray-400"
            >
              {{this.format}}
            </span>
          {{/if}}
        </div>

        {{! Title }}
        <h3
          class="text-sm font-bold text-gray-900 dark:text-white leading-snug line-clamp-2 group-hover:text-blue-600 dark:group-hover:text-blue-400 transition-colors"
        >
          {{this.title}}
        </h3>

        {{! Location + date }}
        <div
          class="flex items-center gap-3 text-xs text-gray-500 dark:text-gray-400"
        >
          <span class="flex items-center gap-1 min-w-0 truncate">
            {{lucideIcon "map-pin" class="w-3 h-3 shrink-0"}}
            {{this.location}}
          </span>
          <span class="flex items-center gap-1 shrink-0">
            {{lucideIcon "calendar" class="w-3 h-3 shrink-0"}}
            {{this.startDate}}
          </span>
        </div>

        {{! Teams + prize }}
        <div class="flex items-center justify-between pt-0.5">
          <span
            class="text-xs text-gray-500 dark:text-gray-400 flex items-center gap-1"
          >
            {{lucideIcon "users" class="w-3 h-3"}}
            {{this.teams}}{{#if this.maxTeams}}/{{this.maxTeams}}{{/if}}
            teams
            {{#if this.isFull}}
              <span
                class="ml-1 text-[10px] font-semibold text-red-500"
              >Full</span>
            {{/if}}
          </span>

          {{#if this.prize}}
            <span
              class="px-2 py-1 text-xs font-bold rounded-lg bg-yellow-50 dark:bg-yellow-900/30 text-yellow-700 dark:text-yellow-400"
            >
              {{lucideIcon
                "trophy"
                class="w-3 h-3 inline mr-0.5"
              }}{{this.prize}}
            </span>
          {{/if}}
        </div>
      </div>
    </button>
  </template>
}
