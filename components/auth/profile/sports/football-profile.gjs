import Component from '@glimmer/component';
import { on } from '@ember/modifier';
import { or, eq } from 'ember-truth-helpers';
import lucideIcon from 'spordium/helpers/lucide-icon';
import { parseRole } from '../sport-meta';

export default class FootballProfileComponent extends Component {
  // @args: profile, sportData, host, isCurrentUser, onOpenPhotoUploader

  get cp() { return this.args.sportData?.profile ?? {}; }

  get footballPic() {
    const cp = this.cp;
    const candidates = [cp.player_primary_pic, cp.player_image];
    for (const raw of candidates) {
      if (raw && !raw.endsWith('//') && raw.trim() !== '') {
        return this.args.host + raw;
      }
    }
    return null;
  }

  get footballPositions() {
    const pos = this.cp.playing_position;
    return Array.isArray(pos) ? pos : (pos ? [pos] : []);
  }

  get footballSkills() {
    return this.cp.football_skills ?? this.cp.skills ?? [];
  }

  get footballRoles() {
    return (this.cp.user_roles ?? []).map(parseRole);
  }

  <template>
    {{! ── Football Hero Header ── }}
    <div class="relative bg-gradient-to-br from-gray-900 via-green-950/60 to-gray-900 overflow-hidden">
      <div class="absolute inset-0 opacity-5" style="background-image: radial-gradient(circle, white 1px, transparent 1px); background-size: 24px 24px;"></div>
      <div class="absolute bottom-0 left-0 right-0 h-px bg-gradient-to-r from-transparent via-green-500/40 to-transparent"></div>
      <div class="relative flex flex-col md:flex-row gap-6 px-4 sm:px-6 md:px-10 pt-6 md:pt-7 pb-5">

        <div class="flex flex-col items-center md:items-start gap-2 shrink-0">
          <div class="relative">
            {{#if this.footballPic}}
              <img
                src={{this.footballPic}}
                class="h-32 w-32 md:h-36 md:w-36 rounded-2xl object-cover border-2 border-green-400/40 shadow-2xl shadow-green-900/40"
                alt="Football profile"
              />
            {{else}}
              <img
                src="/assets/avatar/football_player.webp"
                class="h-32 w-32 md:h-36 md:w-36 rounded-2xl object-cover border-2 border-green-500/20 shadow-2xl shadow-green-900/40"
                alt="Default football profile"
              />
            {{/if}}
            {{#if this.cp.jersey_number}}
              <div class="absolute -top-3 -right-3 w-9 h-9 rounded-full bg-green-500 text-white text-xs font-black flex items-center justify-center shadow-lg shadow-green-500/40 border-2 border-gray-900">
                {{this.cp.jersey_number}}
              </div>
            {{/if}}
            <div class="absolute -bottom-2.5 left-1/2 -translate-x-1/2 bg-green-600 text-white text-[10px] font-black px-3 py-0.5 rounded-full uppercase tracking-widest whitespace-nowrap shadow-lg">
              ⚽ Footballer
            </div>
            {{#if @isCurrentUser}}
              <button
                type="button"
                {{on "click" @onOpenPhotoUploader}}
                class="absolute top-2 right-2 flex items-center justify-center w-7 h-7 rounded-full bg-black/50 hover:bg-black/70 active:scale-95 text-white shadow-md transition-all duration-200"
                aria-label="Change football profile photo"
              >
                {{lucideIcon "upload" size=13}}
              </button>
            {{/if}}
          </div>
          {{#if this.cp.player_nickname}}
            <div class="text-center md:text-left mt-4">
              <p class="text-[10px] text-green-300/70 uppercase tracking-widest font-semibold">Nickname</p>
              <p class="text-2xl font-black text-white tracking-tight">"{{this.cp.player_nickname}}"</p>
            </div>
          {{/if}}
        </div>

        <div class="flex-1 space-y-4 min-w-0">
          <div>
            <h1 class="text-2xl md:text-3xl font-extrabold text-white leading-tight capitalize">
              {{or @profile.user_fullname.first_name "Guest"}}
              {{@profile.user_fullname.last_name}}
            </h1>
            <p class="text-green-300 font-semibold text-base mt-0.5">@{{@profile.user_username}}</p>
            {{#if @profile.verify_img_status}}
              <span class="inline-flex items-center gap-1 mt-1.5 bg-green-500/20 border border-green-500/40 text-green-400 text-[10px] font-bold px-2 py-0.5 rounded-full uppercase tracking-wide">
                ✓ Verified
              </span>
            {{/if}}
          </div>
          {{#if this.footballPositions.length}}
            <div>
              <p class="text-[10px] font-bold uppercase tracking-widest text-green-300 mb-2">Playing Position</p>
              <div class="flex flex-wrap gap-2">
                {{#each this.footballPositions as |pos|}}
                  <span class="px-3 py-1 rounded-full bg-green-500/20 border border-green-400/30 text-green-200 text-xs font-semibold">{{pos}}</span>
                {{/each}}
              </div>
            </div>
          {{/if}}
          <div class="grid grid-cols-2 gap-3">
            <div class="rounded-xl bg-white/5 border border-white/10 p-3 md:p-4">
              <p class="text-[10px] font-bold uppercase tracking-widest text-gray-400 mb-1">Match Fee</p>
              <p class="text-lg font-extrabold text-emerald-400">
                {{#if this.cp.match_fee}}৳{{this.cp.match_fee}}{{else}}—{{/if}}
              </p>
            </div>
            <div class="rounded-xl bg-white/5 border border-white/10 p-3 md:p-4">
              <p class="text-[10px] font-bold uppercase tracking-widest text-gray-400 mb-1">Tournament Fee</p>
              <p class="text-lg font-extrabold text-amber-400">
                {{#if this.cp.tournament_fee}}৳{{this.cp.tournament_fee}}{{else}}—{{/if}}
              </p>
            </div>
          </div>
          {{#if this.footballRoles.length}}
            <div>
              <p class="text-[10px] font-bold uppercase tracking-widest text-green-300 mb-2">Football Roles & Rates</p>
              <div class="flex flex-wrap gap-2">
                {{#each this.footballRoles as |role|}}
                  <div class="flex items-center gap-2 px-3 py-1.5 rounded-xl bg-white/5 border border-white/10">
                    <span class="text-xs font-bold text-white">{{role.name}}</span>
                    <span class="text-xs font-black text-emerald-400">৳{{role.fee}}</span>
                  </div>
                {{/each}}
              </div>
            </div>
          {{/if}}
          {{#if this.cp.player_id}}
            <p class="text-[10px] text-gray-600 font-mono">ID: {{this.cp.player_id}}</p>
          {{/if}}
        </div>
      </div>
    </div>

    {{! ── Football Content ── }}
    <div class="px-4 sm:px-6 md:px-10 py-6 sm:py-8">
      <div class="space-y-6">

        <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <div class="relative overflow-hidden rounded-2xl bg-gradient-to-br from-green-500/15 to-emerald-600/5 border border-green-500/20 p-5 flex flex-col items-center justify-center gap-2 text-center">
            <div class="w-14 h-14 rounded-xl bg-green-500/10 border border-green-500/20 flex items-center justify-center">
              <span class="text-2xl font-black text-green-300">{{if this.cp.jersey_number this.cp.jersey_number "—"}}</span>
            </div>
            <p class="text-[10px] font-bold uppercase tracking-widest text-gray-500">Jersey Number</p>
          </div>
          <div class="relative overflow-hidden rounded-2xl bg-gradient-to-br from-emerald-500/15 to-teal-600/5 border border-emerald-500/20 p-5 flex flex-col items-center justify-center gap-2 text-center">
            <p class="text-2xl font-black text-emerald-300">
              {{#if this.cp.match_fee}}৳{{this.cp.match_fee}}{{else}}—{{/if}}
            </p>
            <p class="text-[10px] font-bold uppercase tracking-widest text-gray-500">Match Fee</p>
          </div>
          <div class="relative overflow-hidden rounded-2xl bg-gradient-to-br from-amber-500/15 to-orange-600/5 border border-amber-500/20 p-5 flex flex-col items-center justify-center gap-2 text-center">
            <p class="text-2xl font-black text-amber-300">
              {{#if this.cp.tournament_fee}}৳{{this.cp.tournament_fee}}{{else}}—{{/if}}
            </p>
            <p class="text-[10px] font-bold uppercase tracking-widest text-gray-500">Tournament Fee</p>
          </div>
        </div>

        {{#if this.footballPositions.length}}
          <div class="rounded-2xl overflow-hidden border border-green-500/15 bg-gradient-to-b from-green-500/8 to-transparent">
            <div class="flex items-center gap-2.5 px-5 py-3.5 border-b border-green-500/15 bg-green-500/10">
              <span class="text-base">🎯</span>
              <span class="text-xs font-black text-green-300 uppercase tracking-widest">Playing Positions</span>
              <span class="ml-auto text-[10px] font-bold text-green-400/60 bg-green-500/10 border border-green-500/20 px-2 py-0.5 rounded-full">
                {{this.footballPositions.length}} position{{if (eq this.footballPositions.length 1) "" "s"}}
              </span>
            </div>
            <div class="p-5 flex flex-wrap gap-2.5">
              {{#each this.footballPositions as |pos|}}
                <div class="flex items-center gap-2 px-4 py-2 rounded-xl bg-green-500/10 border border-green-500/20 hover:bg-green-500/20 transition-colors">
                  <div class="w-2 h-2 rounded-full bg-green-400 shrink-0"></div>
                  <span class="text-sm font-semibold text-green-100">{{pos}}</span>
                </div>
              {{/each}}
            </div>
          </div>
        {{else}}
          <div class="rounded-2xl border border-green-500/10 bg-green-600/5 flex flex-col items-center justify-center py-10 gap-2 text-center">
            <span class="text-3xl opacity-30">🎯</span>
            <p class="text-sm text-gray-500 font-medium">No playing positions set yet.</p>
          </div>
        {{/if}}

        {{#if this.footballSkills.length}}
          <div class="rounded-2xl overflow-hidden border border-sky-500/15 bg-gradient-to-b from-sky-500/8 to-transparent">
            <div class="flex items-center gap-2.5 px-5 py-3.5 border-b border-sky-500/15 bg-sky-500/10">
              <span class="text-base">⚡</span>
              <span class="text-xs font-black text-sky-300 uppercase tracking-widest">Skills</span>
              <span class="ml-auto text-[10px] font-bold text-sky-400/60 bg-sky-500/10 border border-sky-500/20 px-2 py-0.5 rounded-full">
                {{this.footballSkills.length}} skill{{if (eq this.footballSkills.length 1) "" "s"}}
              </span>
            </div>
            <div class="p-5 flex flex-wrap gap-2">
              {{#each this.footballSkills as |skill|}}
                <span class="px-3 py-1.5 rounded-lg bg-sky-500/15 border border-sky-500/20 text-sky-200 text-xs font-semibold hover:bg-sky-500/25 transition-colors">{{skill}}</span>
              {{/each}}
            </div>
          </div>
        {{/if}}

        {{#if this.footballRoles.length}}
          <div class="rounded-2xl overflow-hidden border border-violet-500/15 bg-gradient-to-b from-violet-500/8 to-transparent">
            <div class="flex items-center gap-2.5 px-5 py-3.5 border-b border-violet-500/15 bg-violet-500/10">
              <span class="text-base">🎖️</span>
              <span class="text-xs font-black text-violet-300 uppercase tracking-widest">Roles & Rates</span>
            </div>
            <div class="p-4 grid grid-cols-1 sm:grid-cols-2 gap-3">
              {{#each this.footballRoles as |role|}}
                <div class="flex items-center justify-between gap-3 px-4 py-3 rounded-xl bg-white/5 border border-white/8 hover:bg-white/8 transition-colors">
                  <div class="flex items-center gap-2.5">
                    <div class="w-2 h-2 rounded-full bg-violet-400 shrink-0"></div>
                    <span class="text-sm font-semibold text-white">{{role.name}}</span>
                  </div>
                  <span class="text-sm font-black text-emerald-400 shrink-0">৳{{role.fee}}</span>
                </div>
              {{/each}}
            </div>
          </div>
        {{/if}}

      </div>
    </div>
  </template>
}
