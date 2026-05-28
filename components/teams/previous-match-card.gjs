import Component from '@glimmer/component';
import config from 'spordium/config/environment';

export default class MatchCard extends Component {
  get result() {
    return getResult(this.args.match, this.args.teamId);
  }

  get resultMeta() {
    const map = {
      won: {
        label: 'Won',
        classes: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400',
      },
      lost: {
        label: 'Lost',
        classes: 'bg-red-100 text-red-600 dark:bg-red-900/30 dark:text-red-400',
      },
      draw: {
        label: 'Draw',
        classes: 'bg-gray-100 text-gray-600 dark:bg-gray-700 dark:text-gray-400',
      },
    };
    return map[this.result] ?? map.draw;
  }
  get team1() {
    return this.args.match.team1_details ?? {};
  }

  get team2() {
    return this.args.match.team2_details ?? {};
  }

  <template>
    <div class="flex items-center gap-3 p-4 rounded-xl border border-gray-100 dark:border-gray-700/50 bg-gray-50 dark:bg-gray-800/50 hover:border-indigo-200 dark:hover:border-indigo-700/50 transition-all">
      <span class="shrink-0 px-2.5 py-1 rounded-full text-[11px] font-bold uppercase tracking-wide {{this.resultMeta.classes}}">{{this.resultMeta.label}}</span>

      <div class="flex items-center gap-2 flex-1 min-w-0">
        <img src={{logoUrl this.team1.team1_logo}} alt={{this.team1.team_name}} class="w-8 h-8 rounded-lg object-contain bg-white dark:bg-gray-700 border border-gray-100 dark:border-gray-600 shrink-0" />
        <span class="text-sm font-medium text-gray-800 dark:text-gray-200 truncate">
          {{this.team1.team1_name}}
        </span>
      </div>

      <span class="text-xs font-bold text-gray-400 dark:text-gray-600 shrink-0">VS</span>

      <div class="flex items-center gap-2 flex-1 min-w-0 justify-end">
        <span class="text-sm font-medium text-gray-800 dark:text-gray-200 truncate text-right">
          {{this.team2.team2_name}}
        </span>
        <img src={{logoUrl this.team2.team2_logo}} alt={{this.team2.team_name}} class="w-8 h-8 rounded-lg object-contain bg-white dark:bg-gray-700 border border-gray-100 dark:border-gray-600 shrink-0" />
      </div>

      <span class="shrink-0 text-xs text-gray-400 dark:text-gray-500 hidden sm:block">
        {{formatDate @match.game_datetime}}
      </span>
    </div>
  </template>
}

// ─── Pure helpers ─────────────────────────────────────────────────────────────
function getResult(match, teamId) {
  if (!match.winner_team) return 'draw';
  return String(match.winner_team) === String(teamId) ? 'won' : 'lost';
}

function formatDate(dateStr) {
  if (!dateStr) return '—';
  return new Date(dateStr).toLocaleDateString('en-US', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
}

function logoUrl(path) {
  if (!path) return '/placeholder.png';
  if (path.startsWith('http')) return path;
  return `${config.APP.S3_BUCKET_URL}/${path.replace(/^\//, '')}`;
}
