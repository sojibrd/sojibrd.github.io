import Component from '@glimmer/component';
import { LinkTo } from '@ember/routing';
import config from 'spordium/config/environment';

function logoUrl(path) {
  if (!path) return 'https://placehold.co/128x128/6366f1/ffffff?text=T';
  if (path.startsWith('http')) return path;
  return `${config.APP.S3_BUCKET_URL}/${path.replace(/^\//, '')}`;
}

function initials(name) {
  if (!name) return '?';
  return name
    .split(' ')
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase() ?? '')
    .join('');
}

export default class CricketTeamCard extends Component {
  get logo() {
    return logoUrl(this.args.team.team_logo);
  }
  get abbr() {
    return initials(this.args.team.team_name);
  }
  get locationInfo() {
    const loc = this.args.team.country_of_gameplaying;
    return loc ? loc : 'Unknown location';
  }
  <template>
    <LinkTo @route="teams.cricket-details" @model={{@team.id}} class="group block focus:outline-none rounded-2xl">
      <article class="relative flex flex-col bg-white dark:bg-gray-900 rounded-2xl overflow-hidden border border-gray-100 dark:border-gray-800 shadow-sm transition-all duration-300 hover:shadow-xl hover:-translate-y-1">
        {{! Top accent bar }}
        <div class="h-1 w-full bg-gradient-to-r from-emerald-400 via-cyan-500 to-indigo-500 shrink-0"></div>

        {{! Content: horizontal on mobile, vertical on sm+ }}
        <div class="flex flex-row sm:flex-col flex-1">

          {{! Logo zone: fixed width column on mobile, full-width top zone on sm+ }}
          <div class="relative flex items-center justify-center w-24 shrink-0 sm:w-full sm:h-40 bg-gradient-to-br from-slate-50 via-white to-indigo-50/60 dark:from-gray-800 dark:via-gray-900 dark:to-indigo-950/40 overflow-hidden">
            <div class="absolute inset-0 opacity-30" style="background: radial-gradient(circle at 50% 120%, #6366f120 0%, transparent 70%);"></div>

            {{#if this.logo}}
              <img src={{this.logo}} alt={{@team.team_name}} loading="lazy" class="relative z-10 h-14 w-14 sm:h-24 sm:w-24 object-contain drop-shadow-lg group-hover:scale-110 transition-transform duration-300" />
            {{else}}
              <div class="relative z-10 h-11 w-11 sm:h-20 sm:w-20 rounded-2xl bg-gradient-to-br from-emerald-500 to-cyan-600 flex items-center justify-center shadow-xl group-hover:scale-110 transition-transform duration-300">
                <span class="text-sm sm:text-2xl font-black text-white tracking-tight">
                  {{this.abbr}}
                </span>
              </div>
            {{/if}}
          </div>

          {{! Info panel }}
          <div class="flex flex-col flex-1 min-w-0 px-3 sm:px-4 py-3 sm:pt-3 sm:pb-4 gap-2 sm:gap-3">
            {{! Name + location }}
            <div class="text-left sm:text-center">
              <h3 class="font-bold text-gray-900 dark:text-white text-sm sm:text-[15px] leading-snug truncate" title={{@team.team_name}}>
                {{@team.team_name}}
              </h3>
              <p class="mt-0.5 text-[11px] text-gray-400 dark:text-gray-500 flex items-center sm:justify-center gap-1">
                <svg class="w-3 h-3 shrink-0 text-emerald-400" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M5.05 4.05a7 7 0 119.9 9.9L10 18.9l-4.95-4.95a7 7 0 010-9.9zM10 11a2 2 0 100-4 2 2 0 000 4z" clip-rule="evenodd" />
                </svg>
                <span class="truncate">{{this.locationInfo}}</span>
              </p>
            </div>

            {{! CTA }}
            <div
              class="mt-auto rounded-xl py-1.5 sm:py-2 text-center text-xs font-bold tracking-wide text-indigo-600 dark:text-indigo-400 bg-indigo-50 dark:bg-indigo-950/40 border border-indigo-100 dark:border-indigo-900/40 group-hover:bg-indigo-600 group-hover:text-white group-hover:border-indigo-600 dark:group-hover:bg-indigo-600 dark:group-hover:text-white transition-all duration-200"
            >
              View Team →
            </div>
          </div>
        </div>
      </article>
    </LinkTo>
  </template>
}
