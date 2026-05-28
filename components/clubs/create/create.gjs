import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { LinkTo } from '@ember/routing';

export default class CreateClub extends Component {
  @tracked agreedToTerms = false;

  get stats() {
    return [
      { value: '500+',    label: 'Active Clubs'  },
      { value: '50,000+', label: 'Players'       },
      { value: '100+',    label: 'Tournaments'   },
      { value: '12+',     label: 'Sports'        },
    ];
  }

  get features() {
    return [
      { label: 'Multiple Club Management',   path: 'M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2zM9 22V12h6v10' },
      { label: 'Multiple Team Management',   path: 'M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2M23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75' },
      { label: 'Official Player Profile',    path: 'M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8z' },
      { label: 'Accurate Sports Statistics', path: 'M18 20V10M12 20V4M6 20v-6' },
      { label: 'In-depth Sports Analytics',  path: 'M21 21H3V3M7 14l4-4 4 4 4-4' },
      { label: 'Talent Scouting',            path: 'M21 21l-4.35-4.35M11 19a8 8 0 1 0 0-16 8 8 0 0 0 0 16z' },
      { label: 'Scheduling & Calendar',      path: 'M8 7V3m8 4V3M3 11h18M5 5h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2z' },
    ];
  }

  get freeFeatures() {
    return [
      '1 Club Management',
      'Up to 25 Players',
      'Basic Match Statistics',
      'Official Player Profiles',
      'Community Support',
      'Mobile App Access',
      'Basic Scheduling',
    ];
  }

  get proFeatures() {
    return [
      'Multiple Club Management',
      'Unlimited Players',
      'Advanced Statistics',
      'Priority Support',
      'In-depth Sports Analytics',
      'Talent Scouting Tools',
      'Advanced Scheduling & Calendar',
      'Team Communication Tools',
      'Performance Tracking',
    ];
  }

  get customFeatures() {
    return [
      'Advance Team Suite',
      'Custom Branding & Domain',
      'Dedicated Account Manager',
      'API & Custom Integrations',
      'SLA Guarantee',
      'On-site Training & Onboarding',
      'Advanced Role Management',
      'Custom Reporting Dashboard',
      'White-label Solution',
    ];
  }

  @action
  toggleTerms() {
    this.agreedToTerms = !this.agreedToTerms;
  }

  <template>
    <div style="user-select: none" class="min-h-screen bg-gray-50 dark:bg-gray-950">

      {{! ══ HERO ══ }}
      <div class="relative overflow-hidden
                  bg-gradient-to-br from-slate-900 via-indigo-950 to-violet-950
                  py-24 px-4 sm:px-6 lg:px-8">

        {{! Glow orbs }}
        <div class="absolute -top-24 -left-24 w-[480px] h-[480px]
                    bg-indigo-600/20 rounded-full blur-3xl pointer-events-none"></div>
        <div class="absolute -bottom-24 -right-24 w-[480px] h-[480px]
                    bg-violet-600/20 rounded-full blur-3xl pointer-events-none"></div>
        <div class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2
                    w-[600px] h-[600px]
                    bg-fuchsia-600/10 rounded-full blur-3xl pointer-events-none"></div>

        {{! Grid overlay }}
        <div class="absolute inset-0 opacity-[0.04] pointer-events-none"
             style="background-image:linear-gradient(rgba(255,255,255,.5) 1px,transparent 1px),linear-gradient(90deg,rgba(255,255,255,.5) 1px,transparent 1px);background-size:40px 40px;"></div>

        <div class="relative max-w-3xl mx-auto text-center">

          {{! Badge }}
          <div class="inline-flex items-center gap-2 px-4 py-1.5 rounded-full
                      bg-white/10 border border-white/20
                      text-white/80 text-sm font-medium mb-8">
            <svg class="w-4 h-4 text-amber-400" viewBox="0 0 24 24" fill="currentColor">
              <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>
            </svg>
            Powered by Spordium Ecosystem
          </div>

          {{! Heading }}
          <h1 class="text-4xl sm:text-5xl lg:text-6xl font-extrabold leading-tight text-white mb-5">
            Welcome To
            <span class="block text-transparent bg-clip-text
                         bg-gradient-to-r from-indigo-300 via-violet-300 to-fuchsia-300">
              Spordium Club
            </span>
          </h1>

          <p class="text-lg text-white/60 leading-relaxed max-w-2xl mx-auto mb-10">
            We're here to support the daily operations and long-term growth of your sports clubs.
            Manage your club in a structured and efficient way — performance focused, digitally aligned,
            and built for the future of sports management.
          </p>

          {{! Stats }}
          <div class="grid grid-cols-2 sm:grid-cols-4 gap-4 max-w-2xl mx-auto">
            {{#each this.stats as |stat|}}
              <div class="flex flex-col items-center px-4 py-3 rounded-2xl
                          bg-white/5 border border-white/10 backdrop-blur-sm">
                <span class="text-2xl font-extrabold text-white leading-none mb-0.5">
                  {{stat.value}}
                </span>
                <span class="text-xs text-white/50 font-medium">{{stat.label}}</span>
              </div>
            {{/each}}
          </div>

        </div>
      </div>

      {{! ══ FEATURES STRIP ══ }}
      <div class="bg-gradient-to-r from-indigo-600 via-violet-600 to-indigo-600
                  dark:from-indigo-800 dark:via-violet-800 dark:to-indigo-800
                  py-6 px-4 sm:px-6 lg:px-8">
        <div class="max-w-6xl mx-auto">
          <div class="grid grid-cols-4 sm:grid-cols-7 gap-3 sm:gap-4">
            {{#each this.features as |feat|}}
              <div class="group flex flex-col items-center gap-2">
                <div class="w-11 h-11 rounded-2xl
                            bg-white/15 border border-white/20
                            flex items-center justify-center
                            group-hover:bg-white/25 group-hover:scale-110
                            transition-all duration-200">
                  <svg class="w-5 h-5 text-white" viewBox="0 0 24 24" fill="none"
                       stroke="currentColor" stroke-width="2"
                       stroke-linecap="round" stroke-linejoin="round">
                    <path d={{feat.path}} />
                  </svg>
                </div>
                <span class="hidden sm:block text-white/85 text-[10px] font-medium text-center leading-tight">
                  {{feat.label}}
                </span>
              </div>
            {{/each}}
          </div>
        </div>
      </div>

      {{! ══ PRICING ══ }}
      <div class="py-20 px-4 sm:px-6 lg:px-8">

        {{! Section header }}
        <div class="text-center mb-14">
          <p class="text-sm font-semibold tracking-widest uppercase
                    text-indigo-600 dark:text-indigo-400 mb-2">
            Pricing Plans
          </p>
          <h2 class="text-3xl sm:text-4xl font-extrabold
                     text-gray-900 dark:text-white mb-3">
            Manage Your Clubs With Us
          </h2>
          <p class="text-gray-500 dark:text-gray-400 max-w-lg mx-auto">
            Let Spordium do all the work for you. Pick the plan that fits your club's ambition.
          </p>
        </div>

        {{! Cards }}
        <div class="max-w-5xl mx-auto grid grid-cols-1 md:grid-cols-3 gap-6 items-start">

          {{! ── Free ── }}
          <div class="rounded-2xl p-7 flex flex-col
                      bg-white dark:bg-gray-900
                      border border-gray-200 dark:border-gray-700/60
                      shadow-md hover:shadow-xl transition-all duration-300">
            <p class="text-xs font-bold tracking-widest uppercase
                      text-gray-400 dark:text-gray-500 mb-1">
              Spordium Go
            </p>
            <p class="text-4xl font-extrabold text-gray-900 dark:text-white mb-1">Free</p>
            <p class="text-sm text-gray-400 dark:text-gray-500 mb-6">
              Forever, no credit card needed
            </p>
            <LinkTo
              @route="clubs.createclub"
              class="w-full py-2.5 rounded-xl text-sm font-bold mb-7
                     border-2 border-indigo-500 dark:border-indigo-400
                     text-indigo-600 dark:text-indigo-400
                     hover:bg-indigo-50 dark:hover:bg-indigo-900/20
                     transition-all duration-150 text-center block
                     focus:outline-none focus:ring-2 focus:ring-indigo-400 focus:ring-offset-1">
              Get Started Free
            </LinkTo>
            <p class="text-[11px] font-bold tracking-widest uppercase
                      text-gray-400 dark:text-gray-500 mb-3">Features</p>
            <ul class="space-y-2.5">
              {{#each this.freeFeatures as |feat|}}
                <li class="flex items-start gap-2.5">
                  <span class="mt-0.5 shrink-0 w-4 h-4 rounded-full
                               bg-emerald-100 dark:bg-emerald-900/30
                               flex items-center justify-center">
                    <svg class="w-2.5 h-2.5 text-emerald-600 dark:text-emerald-400"
                         viewBox="0 0 24 24" fill="none" stroke="currentColor"
                         stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round">
                      <path d="M5 13l4 4L19 7"/>
                    </svg>
                  </span>
                  <span class="text-sm text-gray-600 dark:text-gray-300">{{feat}}</span>
                </li>
              {{/each}}
            </ul>
          </div>

          {{! ── Pro (featured) ── }}
          <div class="relative rounded-2xl p-7 flex flex-col
                      bg-gradient-to-b from-indigo-600 to-violet-700
                      dark:from-indigo-700 dark:to-violet-800
                      shadow-2xl shadow-indigo-500/30
                      ring-2 ring-indigo-400/60
                      md:-mt-4 md:-mb-4
                      transition-all duration-300">

            <span class="absolute -top-3.5 left-1/2 -translate-x-1/2
                         inline-flex items-center gap-1.5 px-3 py-1 rounded-full
                         text-[11px] font-extrabold tracking-wider uppercase
                         bg-amber-400 text-amber-900 shadow-lg shadow-amber-400/40">
              <svg class="w-3 h-3" viewBox="0 0 24 24" fill="currentColor">
                <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>
              </svg>
              Most Popular
            </span>

            <p class="text-xs font-bold tracking-widest uppercase text-indigo-200 mb-1 mt-2">
              Spordium Pro
            </p>
            <div class="flex items-end gap-1 mb-1">
              <span class="text-lg font-bold text-indigo-200 self-start mt-1.5">৳</span>
              <span class="text-4xl font-extrabold text-white leading-none">700</span>
              <span class="text-indigo-200 text-sm mb-1">/ month</span>
            </div>
            <p class="text-sm text-indigo-200/70 mb-6">Billed monthly, cancel anytime</p>

            <button type="button" disabled
              class="w-full py-2.5 rounded-xl text-sm font-bold mb-7
                     bg-white/50 text-indigo-400
                     shadow-lg shadow-black/10
                     cursor-not-allowed opacity-60">
              Coming Soon
            </button>

            <p class="text-[11px] font-bold tracking-widest uppercase text-indigo-200 mb-3">
              Everything in Free, plus
            </p>
            <ul class="space-y-2.5">
              {{#each this.proFeatures as |feat|}}
                <li class="flex items-start gap-2.5">
                  <span class="mt-0.5 shrink-0 w-4 h-4 rounded-full
                               bg-white/20 flex items-center justify-center">
                    <svg class="w-2.5 h-2.5 text-white" viewBox="0 0 24 24" fill="none"
                         stroke="currentColor" stroke-width="3.5"
                         stroke-linecap="round" stroke-linejoin="round">
                      <path d="M5 13l4 4L19 7"/>
                    </svg>
                  </span>
                  <span class="text-sm text-indigo-100">{{feat}}</span>
                </li>
              {{/each}}
            </ul>
          </div>

          {{! ── Custom ── }}
          <div class="rounded-2xl p-7 flex flex-col
                      bg-slate-900 dark:bg-slate-800
                      border border-slate-700 dark:border-slate-600/60
                      shadow-md hover:shadow-xl transition-all duration-300">
            <p class="text-xs font-bold tracking-widest uppercase text-slate-400 mb-1">
              Spordium Custom Club
            </p>
            <p class="text-3xl font-extrabold text-white mb-1 leading-tight">
              For Institutions
            </p>
            <p class="text-sm text-slate-400 mb-6">
              Custom pricing for large organisations
            </p>
            <button type="button" disabled
              class="w-full py-2.5 rounded-xl text-sm font-bold mb-7
                     bg-slate-600/50 text-slate-400
                     border border-slate-600/50
                     cursor-not-allowed opacity-60">
              Coming Soon
            </button>
            <p class="text-[11px] font-bold tracking-widest uppercase text-slate-400 mb-3">
              Everything in Pro, plus
            </p>
            <ul class="space-y-2.5">
              {{#each this.customFeatures as |feat|}}
                <li class="flex items-start gap-2.5">
                  <span class="mt-0.5 shrink-0 w-4 h-4 rounded-full
                               bg-violet-500/20 flex items-center justify-center">
                    <svg class="w-2.5 h-2.5 text-violet-400" viewBox="0 0 24 24" fill="none"
                         stroke="currentColor" stroke-width="3.5"
                         stroke-linecap="round" stroke-linejoin="round">
                      <path d="M5 13l4 4L19 7"/>
                    </svg>
                  </span>
                  <span class="text-sm text-slate-300">{{feat}}</span>
                </li>
              {{/each}}
            </ul>
          </div>

        </div>

        {{! T&C }}
        <div class="flex justify-center mt-10">
          <label class="flex items-center gap-3 cursor-pointer group select-none">
            <span
              role="checkbox"
              {{on "click" this.toggleTerms}}
              class="relative flex-shrink-0 w-5 h-5 rounded-md border-2 transition-all duration-150
                     {{if this.agreedToTerms
                       'bg-indigo-600 border-indigo-600 dark:bg-indigo-500 dark:border-indigo-500'
                       'bg-white dark:bg-gray-900 border-gray-300 dark:border-gray-600
                        group-hover:border-indigo-400 dark:group-hover:border-indigo-500'}}"
            >
              {{#if this.agreedToTerms}}
                <svg class="absolute inset-0 m-auto w-3 h-3 text-white"
                     viewBox="0 0 24 24" fill="none" stroke="currentColor"
                     stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M5 13l4 4L19 7"/>
                </svg>
              {{/if}}
            </span>
            <span class="text-sm text-gray-600 dark:text-gray-400">
              I agree to all the
              <a href="#"
                 class="font-semibold text-indigo-600 dark:text-indigo-400
                        hover:text-indigo-500 dark:hover:text-indigo-300
                        underline underline-offset-2 transition-colors duration-150">
                Terms and Conditions
              </a>
            </span>
          </label>
        </div>

      </div>
    </div>
  </template>
}
