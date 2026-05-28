// app/components/tournament/detail/live-match-tab.gjs
import Component from '@glimmer/component';
import { on } from '@ember/modifier';

const IMAGE_BASE = 'https://ag-khela.s3.ap-south-1.amazonaws.com/';

function formatDate(dateStr) {
  if (!dateStr) return 'TBA';
  return new Date(dateStr).toLocaleDateString('en-GB', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
}

function formatTime(dateStr) {
  if (!dateStr) return '';
  return new Date(dateStr).toLocaleTimeString('en-GB', {
    hour: '2-digit',
    minute: '2-digit',
  });
}

function teamInitials(name = '') {
  return name
    .split(' ')
    .map((w) => w[0])
    .join('')
    .slice(0, 2)
    .toUpperCase();
}

// ──────────────────────────────────────────────────────────────
// Single match card
// ──────────────────────────────────────────────────────────────
class MatchCard extends Component {
  get isLive() {
    return this.args.match?.is_started === true;
  }

  get match() {
    return this.args.match ?? {};
  }

  get team1Logo() {
    return this.match.team1_logo ? `${IMAGE_BASE}${this.match.team1_logo}` : null;
  }

  get team2Logo() {
    return this.match.team2_logo ? `${IMAGE_BASE}${this.match.team2_logo}` : null;
  }

  get locationText() {
    const loc = this.match.tmatch_location;
    if (!loc) return 'TBA';
    return [loc.place, loc.city, loc.country].filter(Boolean).join(', ');
  }

  get group1() {
    return this.match.flutter_data?.group_and_position_label_team1 ?? '';
  }

  get group2() {
    return this.match.flutter_data?.group_and_position_label_team2 ?? '';
  }

  <template>
    <div class="bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 rounded-xl overflow-hidden mb-3">

      {{! ── Top bar ── }}
      <div class="flex items-center justify-between px-4 py-2.5 border-b border-gray-100 dark:border-gray-800">
        <div class="flex items-center gap-2">
          <span class="text-xs text-gray-400">Match #{{this.match.tmatch_no}}</span>

          {{#if this.isLive}}
            <span
              class="flex items-center gap-1.5 text-xs font-medium px-2 py-0.5 rounded-full bg-red-50 dark:bg-red-900/20 text-red-600 dark:text-red-400"
            >
              <span class="w-1.5 h-1.5 rounded-full bg-red-500 animate-pulse"></span>
              Live
            </span>
          {{else}}
            <span class="text-xs font-medium px-2 py-0.5 rounded-full bg-gray-100 dark:bg-gray-800 text-gray-500 capitalize">
              {{this.match.tmatch_status}}
            </span>
          {{/if}}
        </div>

        <span class="text-xs text-gray-400">
          {{formatDate this.match.tmatch_date}},
          {{formatTime this.match.tmatch_date}}
        </span>
      </div>

      {{! ── Teams ── }}
      <div class="flex items-center justify-between px-4 py-5 gap-3">

        {{! Team 1 }}
        <div class="flex flex-col items-center gap-2 flex-1">
          <div
            class="w-12 h-12 rounded-full bg-gray-100 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 overflow-hidden flex items-center justify-center"
          >
            {{#if this.team1Logo}}
              <img src={{this.team1Logo}} alt={{this.match.team1_name}} class="w-full h-full object-cover" />
            {{else}}
              <span class="text-xs font-medium text-gray-500">{{teamInitials this.match.team1_name}}</span>
            {{/if}}
          </div>
          <p class="text-xs font-semibold text-gray-900 dark:text-white text-center leading-tight max-w-[88px]">
            {{this.match.team1_name}}
          </p>
          {{#if this.group1}}
            <p class="text-[10px] text-gray-400">{{this.group1}}</p>
          {{/if}}
        </div>

        {{! VS }}
        <div class="flex flex-col items-center gap-1 shrink-0">
          <span class="text-sm font-medium text-gray-400">vs</span>
          {{#if this.match.destination}}
            <span class="text-[10px] text-gray-400">Target: {{this.match.destination}}</span>
          {{/if}}
        </div>

        {{! Team 2 }}
        <div class="flex flex-col items-center gap-2 flex-1">
          <div
            class="w-12 h-12 rounded-full bg-gray-100 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 overflow-hidden flex items-center justify-center"
          >
            {{#if this.team2Logo}}
              <img src={{this.team2Logo}} alt={{this.match.team2_name}} class="w-full h-full object-cover" />
            {{else}}
              <span class="text-xs font-medium text-gray-500">{{teamInitials this.match.team2_name}}</span>
            {{/if}}
          </div>
          <p class="text-xs font-semibold text-gray-900 dark:text-white text-center leading-tight max-w-[88px]">
            {{this.match.team2_name}}
          </p>
          {{#if this.group2}}
            <p class="text-[10px] text-gray-400">{{this.group2}}</p>
          {{/if}}
        </div>
      </div>

      {{! ── Reporting time ── }}
      {{#if this.match.tmatch_reportingtime}}
        <div class="flex items-center gap-2 px-4 py-1.5 border-t border-gray-100 dark:border-gray-800">
          <span class="text-[10px] text-gray-400">Reporting:</span>
          <span class="text-[10px] font-medium text-gray-600 dark:text-gray-300">{{this.match.tmatch_reportingtime}}</span>
          {{#if this.match.tmatchfield_name}}
            <span class="ml-auto text-[10px] text-gray-400 truncate max-w-[140px]">{{this.match.tmatchfield_name}}</span>
          {{/if}}
        </div>
      {{/if}}

      {{! ── Location bar ── }}
      <div class="flex items-center gap-2 px-4 py-2 border-t border-gray-100 dark:border-gray-800 bg-gray-50 dark:bg-gray-800/50">
        <svg class="w-3 h-3 shrink-0 text-gray-400" viewBox="0 0 16 16" fill="currentColor">
          <path d="M8 1C5.24 1 3 3.24 3 6c0 4.25 5 9 5 9s5-4.75 5-9c0-2.76-2.24-5-5-5zm0 6.5A1.5 1.5 0 1 1 8 4a1.5 1.5 0 0 1 0 3z" />
        </svg>
        <span class="text-xs text-gray-500 truncate flex-1">{{this.locationText}}</span>
        {{!-- {{#if this.match.tmatchfield_gmap}}
          <a
            href={{this.match.tmatchfield_gmap}}
            target="_blank"
            rel="noopener noreferrer"
            class="text-xs text-blue-500 hover:text-blue-600 shrink-0 font-medium"
          >
            Map
          </a>
        {{/if}} --}}
      </div>
    </div>
  </template>
}

// ──────────────────────────────────────────────────────────────
// LiveMatchesTab — parent
// @arg {Array} matches — array of live match objects from API
// ──────────────────────────────────────────────────────────────
export default class LiveMatchesTab extends Component {
  <template>
    <div class="space-y-1">
      {{#if @matches.length}}
        {{#each @matches as |match|}}
          <MatchCard @match={{match}} />
        {{/each}}
      {{else}}
        <div class="py-16 text-center text-sm text-gray-400">
          No live matches at the moment.
        </div>
      {{/if}}
    </div>
  </template>
}
