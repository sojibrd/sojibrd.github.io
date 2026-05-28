import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { eq } from 'ember-truth-helpers';
import { termsAndConditions as tc, privacyPart1 as p1, privacyPart2 as p2 } from '../../utils/legal-content';

export default class TermsModalComponent extends Component {
  @tracked activeTab = 'terms';

  @action switchTab(tab) {
    this.activeTab = tab;
  }

  @action accept() {
    this.args.onAccept?.();
  }

  @action decline() {
    this.args.onDecline?.();
  }

  @action handleBackdropClick(event) {
    if (event.target === event.currentTarget) {
      this.args.onDecline?.();
    }
  }

  <template>
    {{! ── Backdrop ─────────────────────────────────────────────────────────── }}
    <div
      class="fixed inset-0 z-[9999] flex items-end sm:items-center justify-center p-0 sm:p-4"
      role="dialog"
      aria-modal="true"
      aria-label="Terms and Conditions"
      {{on "click" this.handleBackdropClick}}
    >
      <div class="absolute inset-0 bg-black/60 backdrop-blur-sm"></div>

      {{! ── Modal Card ───────────────────────────────────────────────────── }}
      <div class="relative z-10 w-full sm:max-w-2xl lg:max-w-3xl flex flex-col bg-white dark:bg-gray-900 sm:rounded-3xl rounded-t-3xl overflow-hidden shadow-2xl max-h-[92dvh] sm:max-h-[88vh]">

        {{! ── Header ──────────────────────────────────────────────────────── }}
        <div class="flex-shrink-0 bg-gradient-to-r from-indigo-600 via-violet-600 to-indigo-700 dark:from-indigo-800 dark:via-violet-900 dark:to-indigo-900 px-5 sm:px-8 pt-5 sm:pt-7 pb-0">

          {{! Top row: logo + close }}
          <div class="flex items-center justify-between mb-4">
            <div class="flex items-center gap-2.5">
              <div class="w-8 h-8 rounded-xl bg-white/20 flex items-center justify-center backdrop-blur-sm">
                <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z"/>
                </svg>
              </div>
              <div>
                <p class="text-white/70 text-[10px] uppercase tracking-widest font-medium leading-none mb-0.5">Spordium Platform</p>
                <p class="text-white font-bold text-sm leading-none">Legal Agreements</p>
              </div>
            </div>
            <button
              type="button"
              {{on "click" this.decline}}
              class="w-8 h-8 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center transition-colors text-white/80 hover:text-white"
              aria-label="Close"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>

          {{! Tab switcher }}
          <div class="flex gap-1 bg-white/10 rounded-t-xl p-1">
            <button
              type="button"
              {{on "click" (fn this.switchTab "terms")}}
              class="flex-1 flex items-center justify-center gap-1.5 py-2.5 rounded-lg text-xs font-bold uppercase tracking-wider transition-all
                {{if (eq this.activeTab 'terms')
                  'bg-white dark:bg-gray-900 text-indigo-700 dark:text-indigo-400 shadow-sm'
                  'text-white/70 hover:text-white hover:bg-white/10'}}"
            >
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z"/>
              </svg>
              Terms
            </button>
            <button
              type="button"
              {{on "click" (fn this.switchTab "privacy")}}
              class="flex-1 flex items-center justify-center gap-1.5 py-2.5 rounded-lg text-xs font-bold uppercase tracking-wider transition-all
                {{if (eq this.activeTab 'privacy')
                  'bg-white dark:bg-gray-900 text-indigo-700 dark:text-indigo-400 shadow-sm'
                  'text-white/70 hover:text-white hover:bg-white/10'}}"
            >
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z"/>
              </svg>
              Privacy
            </button>
          </div>
        </div>

        {{! ── Scrollable body ──────────────────────────────────────────────── }}
        <div class="flex-1 overflow-y-auto overscroll-contain" style="scroll-behavior: smooth;">

          {{! ══════════ TERMS & CONDITIONS TAB ══════════ }}
          {{#if (eq this.activeTab "terms")}}
            <div class="px-5 sm:px-8 py-5 sm:py-7">

              {{! Meta bar }}
              <div class="flex flex-wrap items-center gap-2 mb-5">
                <span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-indigo-50 dark:bg-indigo-950/60 text-indigo-600 dark:text-indigo-400 text-[10px] font-bold uppercase tracking-wider">
                  <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm.75-13a.75.75 0 00-1.5 0v5c0 .414.336.75.75.75h4a.75.75 0 000-1.5h-3.25V5z" clip-rule="evenodd"/></svg>
                  Last Update: {{tc.lastUpdate}}
                </span>
                <span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-emerald-50 dark:bg-emerald-950/60 text-emerald-600 dark:text-emerald-400 text-[10px] font-bold uppercase tracking-wider">
                  <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z" clip-rule="evenodd"/></svg>
                  {{tc.versionBadge}}
                </span>
              </div>

              <div class="mb-4">
                <h2 class="text-sm font-bold text-indigo-700 dark:text-indigo-400 uppercase tracking-wide">{{tc.title}}</h2>
              </div>

              <div class="mb-6 p-4 rounded-2xl bg-gradient-to-br from-indigo-50 to-violet-50 dark:from-indigo-950/40 dark:to-violet-950/40 border border-indigo-100 dark:border-indigo-900/50">
                {{#each tc.intro as |para|}}
                  <p class="text-xs sm:text-sm text-gray-600 dark:text-gray-300 leading-relaxed mb-3">{{para}}</p>
                {{/each}}
              </div>

              <div class="space-y-4">
                {{#each tc.sections as |section|}}
                  <div class="group">
                    <div class="flex items-start gap-3 sm:gap-4">
                      <div class="flex-shrink-0 w-8 h-8 sm:w-9 sm:h-9 rounded-xl flex items-center justify-center text-white text-xs font-black {{section.badgeClass}}">{{section.num}}</div>
                      <div class="flex-1 min-w-0 pt-0.5">
                        <h3 class="text-sm sm:text-base font-bold text-gray-900 dark:text-gray-100 mb-1.5">{{section.title}}</h3>
                        <p class="text-xs sm:text-sm text-gray-500 dark:text-gray-400 leading-relaxed">{{section.content}}</p>
                      </div>
                    </div>
                    {{#unless section.isLast}}
                      <div class="mt-3 ml-11 sm:ml-[52px] h-px bg-gray-100 dark:bg-gray-800"></div>
                    {{/unless}}
                  </div>
                {{/each}}
              </div>

              <div class="mt-5 p-3 rounded-xl bg-gray-50 dark:bg-gray-800/60 border border-gray-100 dark:border-gray-800">
                <p class="text-xs text-gray-500 dark:text-gray-400 leading-relaxed">{{tc.footerNotice}}</p>
              </div>

              <div class="mt-4 p-4 rounded-2xl bg-gradient-to-br from-indigo-50 to-violet-50 dark:from-indigo-950/40 dark:to-violet-950/40 border border-indigo-100 dark:border-indigo-900/50 flex items-center gap-3">
                <div class="w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0 {{tc.contactIconBg}}">
                  <svg class="w-4.5 h-4.5 text-white" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M21.75 6.75v10.5a2.25 2.25 0 01-2.25 2.25h-15a2.25 2.25 0 01-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25m19.5 0v.243a2.25 2.25 0 01-1.07 1.916l-7.5 4.615a2.25 2.25 0 01-2.36 0L3.32 8.91a2.25 2.25 0 01-1.07-1.916V6.75"/>
                  </svg>
                </div>
                <div>
                  <p class="text-xs font-bold text-gray-700 dark:text-gray-200 mb-0.5">{{tc.contactQuestion}}</p>
                  <p class="text-xs font-medium {{tc.contactEmailClass}}">{{tc.contactEmail}}</p>
                </div>
              </div>

            </div>
          {{/if}}

          {{! ══════════ PRIVACY TAB ══════════ }}
          {{#if (eq this.activeTab "privacy")}}
            <div class="px-5 sm:px-8 py-5 sm:py-7">

              {{! Meta bar }}
              <div class="flex flex-wrap items-center gap-2 mb-5">
                <span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-violet-50 dark:bg-violet-950/60 text-violet-600 dark:text-violet-400 text-[10px] font-bold uppercase tracking-wider">
                  <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm.75-13a.75.75 0 00-1.5 0v5c0 .414.336.75.75.75h4a.75.75 0 000-1.5h-3.25V5z" clip-rule="evenodd"/></svg>
                  Last Update: {{p1.lastUpdate}}
                </span>
                <span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-emerald-50 dark:bg-emerald-950/60 text-emerald-600 dark:text-emerald-400 text-[10px] font-bold uppercase tracking-wider">
                  <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z" clip-rule="evenodd"/></svg>
                  {{p1.gdprBadge}}
                </span>
              </div>

              {{! ── Part 1 ── }}
              <div class="mb-4">
                <h2 class="text-sm font-bold text-violet-700 dark:text-violet-400 uppercase tracking-wide">{{p1.title}}</h2>
              </div>

              <div class="mb-6 p-4 rounded-2xl bg-gradient-to-br from-violet-50 to-indigo-50 dark:from-violet-950/40 dark:to-indigo-950/40 border border-violet-100 dark:border-violet-900/50">
                {{#each p1.intro as |para|}}
                  <p class="text-xs sm:text-sm text-gray-600 dark:text-gray-300 leading-relaxed mb-3">{{para}}</p>
                {{/each}}
                <p class="text-xs sm:text-sm text-gray-600 dark:text-gray-300 leading-relaxed">
                  <span class="font-bold text-violet-700 dark:text-violet-400">Consent:</span> {{p1.consentText}}
                </p>
              </div>

              <div class="space-y-4">
                {{#each p1.sections as |section|}}
                  <div>
                    <div class="flex items-start gap-3 sm:gap-4">
                      <div class="flex-shrink-0 w-8 h-8 sm:w-9 sm:h-9 rounded-xl flex items-center justify-center text-white text-xs font-black {{section.badgeClass}}">{{section.num}}</div>
                      <div class="flex-1 min-w-0 pt-0.5">
                        <h3 class="text-sm sm:text-base font-bold text-gray-900 dark:text-gray-100 mb-1.5">{{section.title}}</h3>
                        {{#if section.subsections}}
                          <div class="space-y-2">
                            {{#each section.subsections as |sub|}}
                              <div class="p-3 rounded-xl bg-gray-50 dark:bg-gray-800/60 border border-gray-100 dark:border-gray-800">
                                <p class="text-xs font-bold text-gray-700 dark:text-gray-200 mb-1.5 uppercase tracking-wide">{{sub.title}}</p>
                                <p class="text-xs text-gray-500 dark:text-gray-400 leading-relaxed">{{sub.content}}</p>
                              </div>
                            {{/each}}
                          </div>
                        {{else if section.bullets}}
                          <p class="text-xs sm:text-sm text-gray-500 dark:text-gray-400 leading-relaxed mb-2">{{section.introContent}}</p>
                          <ul class="space-y-1.5 mb-2">
                            {{#each section.bullets as |bullet|}}
                              <li class="flex items-start gap-2 text-xs sm:text-sm text-gray-600 dark:text-gray-300">
                                <span class="flex-shrink-0 w-1.5 h-1.5 rounded-full mt-1.5 {{section.bulletDotClass}}"></span>
                                {{bullet}}
                              </li>
                            {{/each}}
                          </ul>
                          <p class="text-xs sm:text-sm text-gray-500 dark:text-gray-400 leading-relaxed">{{section.closingContent}}</p>
                        {{else}}
                          <p class="text-xs sm:text-sm text-gray-500 dark:text-gray-400 leading-relaxed">{{section.content}}</p>
                        {{/if}}
                      </div>
                    </div>
                    {{#unless section.isLast}}
                      <div class="mt-3 ml-11 sm:ml-[52px] h-px bg-gray-100 dark:bg-gray-800"></div>
                    {{/unless}}
                  </div>
                {{/each}}
              </div>

              <div class="mt-5 p-3 rounded-xl bg-gray-50 dark:bg-gray-800/60 border border-gray-100 dark:border-gray-800">
                <p class="text-xs text-gray-500 dark:text-gray-400 leading-relaxed">{{p1.footerNotice}}</p>
              </div>

              {{! Divider }}
              <div class="my-7 flex items-center gap-4">
                <div class="flex-1 h-px bg-gradient-to-r from-transparent via-gray-300 dark:via-gray-600 to-transparent"></div>
                <span class="text-[10px] font-bold uppercase tracking-widest text-gray-400 dark:text-gray-500 px-2">Also Applies</span>
                <div class="flex-1 h-px bg-gradient-to-r from-transparent via-gray-300 dark:via-gray-600 to-transparent"></div>
              </div>

              {{! ── Part 2 ── }}
              <div class="mb-4">
                <h2 class="text-sm font-bold text-violet-700 dark:text-violet-400 uppercase tracking-wide">{{p2.title}}</h2>
              </div>

              <div class="mb-6 p-4 rounded-2xl bg-gradient-to-br from-violet-50 to-indigo-50 dark:from-violet-950/40 dark:to-indigo-950/40 border border-violet-100 dark:border-violet-900/50">
                {{#each p2.intro as |para|}}
                  <p class="text-xs sm:text-sm text-gray-600 dark:text-gray-300 leading-relaxed mb-3">{{para}}</p>
                {{/each}}
              </div>

              <div class="space-y-4">
                {{#each p2.sections as |section|}}
                  <div>
                    <div class="flex items-start gap-3 sm:gap-4">
                      <div class="flex-shrink-0 w-8 h-8 sm:w-9 sm:h-9 rounded-xl flex items-center justify-center text-white text-xs font-black {{section.badgeClass}}">{{section.num}}</div>
                      <div class="flex-1 min-w-0 pt-0.5">
                        <h3 class="text-sm sm:text-base font-bold text-gray-900 dark:text-gray-100 mb-1.5">{{section.title}}</h3>
                        {{#if section.subsections}}
                          {{#if section.introContent}}
                            <p class="text-xs sm:text-sm text-gray-500 dark:text-gray-400 leading-relaxed mb-3">{{section.introContent}}</p>
                          {{/if}}
                          <div class="space-y-2">
                            {{#each section.subsections as |sub|}}
                              <div class="p-3 rounded-xl bg-gray-50 dark:bg-gray-800/60 border border-gray-100 dark:border-gray-800">
                                <p class="text-xs font-bold text-gray-700 dark:text-gray-200 mb-1.5 uppercase tracking-wide">{{sub.title}}</p>
                                <p class="text-xs text-gray-500 dark:text-gray-400 leading-relaxed">{{sub.content}}</p>
                              </div>
                            {{/each}}
                          </div>
                        {{else}}
                          <p class="text-xs sm:text-sm text-gray-500 dark:text-gray-400 leading-relaxed">{{section.content}}</p>
                        {{/if}}
                      </div>
                    </div>
                    {{#unless section.isLast}}
                      <div class="mt-3 ml-11 sm:ml-[52px] h-px bg-gray-100 dark:bg-gray-800"></div>
                    {{/unless}}
                  </div>
                {{/each}}
              </div>

              <div class="mt-5 p-3 rounded-xl bg-gray-50 dark:bg-gray-800/60 border border-gray-100 dark:border-gray-800">
                <p class="text-xs text-gray-500 dark:text-gray-400 leading-relaxed">{{p2.footerNotice}}</p>
              </div>

              <div class="mt-4 p-4 rounded-2xl bg-gradient-to-br from-violet-50 to-indigo-50 dark:from-violet-950/40 dark:to-indigo-950/40 border border-violet-100 dark:border-violet-900/50 flex items-center gap-3">
                <div class="w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0 {{p2.contactIconBg}}">
                  <svg class="w-4.5 h-4.5 text-white" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M21.75 6.75v10.5a2.25 2.25 0 01-2.25 2.25h-15a2.25 2.25 0 01-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25m19.5 0v.243a2.25 2.25 0 01-1.07 1.916l-7.5 4.615a2.25 2.25 0 01-2.36 0L3.32 8.91a2.25 2.25 0 01-1.07-1.916V6.75"/>
                  </svg>
                </div>
                <div>
                  <p class="text-xs font-bold text-gray-700 dark:text-gray-200 mb-0.5">{{p2.contactQuestion}}</p>
                  <p class="text-xs font-medium {{p2.contactEmailClass}}">{{p2.contactEmail}}</p>
                </div>
              </div>

            </div>
          {{/if}}

        </div>

        {{! ── Sticky Footer ────────────────────────────────────────────────── }}
        <div class="flex-shrink-0 border-t border-gray-100 dark:border-gray-800 bg-white dark:bg-gray-900 px-5 sm:px-8 py-4 sm:py-5">
          <div class="flex flex-col-reverse sm:flex-row items-stretch sm:items-center gap-2.5 sm:gap-3">
            <button
              type="button"
              {{on "click" this.decline}}
              class="flex-1 sm:flex-none sm:px-6 py-2.5 rounded-full border-2 border-gray-300 dark:border-gray-600 text-gray-600 dark:text-gray-300 text-xs font-bold uppercase tracking-widest hover:border-red-400 hover:text-red-500 dark:hover:border-red-500 dark:hover:text-red-400 transition-colors bg-transparent text-center"
            >
              Decline
            </button>
            <button
              type="button"
              {{on "click" this.accept}}
              class="flex-1 py-2.5 rounded-full bg-indigo-600 hover:bg-indigo-700 active:bg-indigo-800 dark:bg-indigo-700 dark:hover:bg-indigo-600 text-white text-xs font-bold uppercase tracking-widest transition-colors text-center shadow-lg shadow-indigo-200 dark:shadow-indigo-900/40"
            >
              I Agree &amp; Accept
            </button>
          </div>
          <p class="mt-2 text-center text-[10px] text-gray-400 dark:text-gray-500">By accepting, you agree to both the Terms &amp; Conditions and Privacy Policy.</p>
        </div>

      </div>
    </div>
  </template>
}
