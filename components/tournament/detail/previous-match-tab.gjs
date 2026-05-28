// app/components/tournament/detail/previous-match-tab.gjs
import Component from '@glimmer/component';

const IMAGE_BASE = 'https://ag-khela.s3.ap-south-1.amazonaws.com/';

function formatDateTime(dateStr) {
  if (!dateStr) return 'TBA';
  const d = new Date(dateStr);
  const date = d.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
  const time = d.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' });
  return `${date} · ${time}`;
}

function teamInitials(name = '') {
  return name
    .split(' ')
    .map((w) => w[0])
    .join('')
    .slice(0, 2)
    .toUpperCase();
}

function locationText(loc) {
  if (!loc) return 'TBA';
  // address সবচেয়ে complete, না থাকলে city + country
  return loc.address ?? [loc.city, loc.country].filter(Boolean).join(', ');
}

// ──────────────────────────────────────────────────────────────
// Single previous match card
// ──────────────────────────────────────────────────────────────
class PreviousMatchCard extends Component {
  get m() {
    return this.args.match ?? {};
  }

  get team1Logo() {
    return this.m.team1_logo ? `${IMAGE_BASE}${this.m.team1_logo}` : null;
  }

  get team2Logo() {
    return this.m.team2_logo ? `${IMAGE_BASE}${this.m.team2_logo}` : null;
  }

  get group1() {
    return this.m.flutter_data?.group_and_position_label_team1 ?? '';
  }

  get group2() {
    return this.m.flutter_data?.group_and_position_label_team2 ?? '';
  }

  get location() {
    return locationText(this.m.tmatch_location);
  }

  get hasFieldName() {
    return !!this.m.tmatchfield_name;
  }

  <template>
    <div class="bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 rounded-xl overflow-hidden mb-3">

      {{! ── Top bar ── }}
      <div class="flex items-center justify-between px-4 py-2.5 border-b border-gray-100 dark:border-gray-800">
        <div class="flex items-center gap-2">
          <span class="text-xs text-gray-400">Match #{{this.m.tmatch_no}}</span>
          <span
            class="text-[10px] font-medium px-2 py-0.5 rounded-full bg-gray-100 dark:bg-gray-800 text-gray-500 capitalize border border-gray-200 dark:border-gray-700"
          >
            {{this.m.tmatch_status}}
          </span>
        </div>
        <span class="text-xs text-gray-400">{{formatDateTime this.m.tmatch_date}}</span>
      </div>

      {{! ── Teams row (horizontal) ── }}
      <div class="flex items-center px-4 py-4 gap-3">

        {{! Left team: logo → name }}
        <div class="flex items-center gap-2.5 flex-1">
          <div
            class="w-9 h-9 rounded-full bg-gray-100 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 overflow-hidden flex items-center justify-center shrink-0"
          >
            {{#if this.team1Logo}}
              <img src={{this.team1Logo}} alt={{this.m.team1_name}} class="w-full h-full object-cover" />
            {{else}}
              <span class="text-[10px] font-medium text-gray-500">{{teamInitials this.m.team1_name}}</span>
            {{/if}}
          </div>
          <div>
            <p class="text-xs font-semibold text-gray-900 dark:text-white leading-tight">{{this.m.team1_name}}</p>
            {{#if this.group1}}
              <p class="text-[10px] text-gray-400 mt-0.5">{{this.group1}}</p>
            {{/if}}
          </div>
        </div>

        {{! VS + target }}
        <div class="flex flex-col items-center gap-1 shrink-0 px-1">
          <span class="text-xs font-medium text-gray-400">vs</span>
          {{#if this.m.destination}}
            <span class="text-[9px] text-gray-400 whitespace-nowrap">Target {{this.m.destination}}</span>
          {{/if}}
        </div>

        {{! Right team: name ← logo }}
        <div class="flex items-center gap-2.5 flex-1 flex-row-reverse">
          <div
            class="w-9 h-9 rounded-full bg-gray-100 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 overflow-hidden flex items-center justify-center shrink-0"
          >
            {{#if this.team2Logo}}
              <img src={{this.team2Logo}} alt={{this.m.team2_name}} class="w-full h-full object-cover" />
            {{else}}
              <span class="text-[10px] font-medium text-gray-500">{{teamInitials this.m.team2_name}}</span>
            {{/if}}
          </div>
          <div class="text-right">
            <p class="text-xs font-semibold text-gray-900 dark:text-white leading-tight">{{this.m.team2_name}}</p>
            {{#if this.group2}}
              <p class="text-[10px] text-gray-400 mt-0.5">{{this.group2}}</p>
            {{/if}}
          </div>
        </div>

      </div>

      {{! ── Reporting + field ── }}
      <div class="flex items-center justify-between px-4 py-1.5 border-t border-gray-100 dark:border-gray-800">
        <span class="text-[10px] text-gray-400">
          Reporting:
          <span class="font-medium text-gray-600 dark:text-gray-300">{{this.m.tmatch_reportingtime}}</span>
        </span>
        {{#if this.hasFieldName}}
          <span class="text-[10px] text-gray-400 truncate max-w-[140px]">{{this.m.tmatchfield_name}}</span>
        {{else}}
          <span class="text-[10px] text-gray-300 dark:text-gray-600 italic">No field info</span>
        {{/if}}
      </div>

      {{! ── Location footer ── }}
      <div class="flex items-center gap-2 px-4 py-2 border-t border-gray-100 dark:border-gray-800 bg-gray-50 dark:bg-gray-800/50">
        <svg class="w-3 h-3 shrink-0 text-gray-400" viewBox="0 0 16 16" fill="currentColor">
          <path d="M8 1C5.24 1 3 3.24 3 6c0 4.25 5 9 5 9s5-4.75 5-9c0-2.76-2.24-5-5-5zm0 6.5A1.5 1.5 0 1 1 8 4a1.5 1.5 0 0 1 0 3z" />
        </svg>
        <span class="text-xs text-gray-500 truncate flex-1">{{this.location}}</span>
        {{!-- {{#if this.m.tmatchfield_gmap}}
          <a
            href={{this.m.tmatchfield_gmap}}
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
// PreviousMatchesTab — parent
// @arg {Array} matches — from API response .data
// ──────────────────────────────────────────────────────────────
export default class PreviousMatchesTab extends Component {
  get matchCount() {
    return this.args.matches?.length ?? 0;
  }

  <template>
    <div>
      {{! Header with count }}
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-sm font-semibold text-gray-700 dark:text-gray-300">Previous Matches</h3>
        <span class="text-xs text-gray-400 bg-gray-100 dark:bg-gray-800 px-2 py-0.5 rounded-full border border-gray-200 dark:border-gray-700">
          {{this.matchCount}}
          matches
        </span>
      </div>

      {{#if this.args.matches.length}}
        {{#each this.args.matches as |match|}}
          <PreviousMatchCard @match={{match}} />
        {{/each}}
      {{else}}
        <div class="py-16 text-center text-sm text-gray-400">
          No previous matches found.
        </div>
      {{/if}}
    </div>
  </template>
}
