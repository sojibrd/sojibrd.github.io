import Component from '@glimmer/component';
import { on } from '@ember/modifier';
import config from 'spordium/config/environment';

const PLAY_STORE_URL = config.APP.PLAY_STORE_URL;
const APP_STORE_URL = config.APP.APP_STORE_URL;

const ITEM_DESCRIPTIONS = {
  'View Players In Field': 'See live player positions on the field in real time.',
  'Input Players In Field': 'Set and update player positions on the field.',
  'Input Score': 'Enter ball-by-ball scores and manage live scoring.',
  'Change Bowler': 'Switch the current bowler for the next over.',
  'Change Striker': 'Swap the striker and non-striker batsman.',
  'Change Batsman': 'Bring in a new batsman after a wicket.',
};

const DEFAULT_DESCRIPTION = 'This feature is available on the Spordium app. Download to get started.';

class AppDownloadModalComponent extends Component {
  get playStoreUrl() {
    return PLAY_STORE_URL;
  }

  get appStoreUrl() {
    return APP_STORE_URL;
  }

  get description() {
    if (this.args.description) return this.args.description;
    return ITEM_DESCRIPTIONS[this.args.title] ?? DEFAULT_DESCRIPTION;
  }

  <template>
    {{#if @isOpen}}
      <div
        class="fixed inset-0 z-50 flex items-end sm:items-center justify-center"
        role="dialog"
        aria-modal="true"
      >
        {{! Backdrop }}
        <div
          class="absolute inset-0 bg-black/60 backdrop-blur-sm"
          role="presentation"
          {{on "click" @onClose}}
        ></div>

        {{! Sheet }}
        <div class="relative w-full sm:max-w-sm bg-slate-800 rounded-t-2xl sm:rounded-2xl shadow-2xl border border-slate-700/60 p-6 z-10">

          {{! Close }}
          <button
            type="button"
            class="absolute top-4 right-4 w-8 h-8 flex items-center justify-center text-gray-400 hover:text-white transition-colors"
            {{on "click" @onClose}}
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>

          {{! Icon }}
          <div class="w-14 h-14 mx-auto mb-4 bg-gradient-to-br from-cyan-500 to-blue-600 rounded-2xl flex items-center justify-center shadow-lg">
            <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z" />
            </svg>
          </div>

          <h3 class="text-white font-bold text-lg text-center mb-1">
            {{if @title @title "Get the Spordium App"}}
          </h3>
          <p class="text-gray-400 text-sm text-center mb-6">
            {{this.description}}
          </p>

          {{! Store Buttons }}
          <div class="flex flex-col gap-3">

            {{! Google Play }}
            <a
              href={{this.playStoreUrl}}
              target="_blank"
              rel="noopener noreferrer"
              class="flex items-center gap-3 bg-black hover:bg-gray-900 text-white px-4 py-3 rounded-xl transition-colors border border-gray-700"
            >
              <svg class="w-7 h-7 flex-shrink-0" viewBox="0 0 24 24" fill="currentColor">
                <path d="M3.18 23.76a2 2 0 001.81-.19l10.89-6.28-2.37-2.37-10.33 8.84zM20.51 9.1L17.07 7.1l-2.68 2.68 2.68 2.68 3.46-2.02a1.5 1.5 0 000-2.34zM3.18.24L13.51 9.1l-2.37 2.37L.99.43A2 2 0 013.18.24zM1 1.42v21.16l10.14-10.58L1 1.42z"/>
              </svg>
              <div>
                <p class="text-[10px] text-gray-400 leading-none">Get it on</p>
                <p class="text-sm font-semibold leading-tight">Google Play</p>
              </div>
            </a>

            {{! App Store — coming soon }}
            <div class="flex items-center gap-3 bg-black/50 text-white px-4 py-3 rounded-xl border border-gray-700/50 opacity-50 cursor-not-allowed select-none">
              <svg class="w-7 h-7 flex-shrink-0" viewBox="0 0 24 24" fill="currentColor">
                <path d="M17.05 20.28c-.98.95-2.05.8-3.08.35-1.09-.46-2.09-.48-3.24 0-1.44.62-2.2.44-3.06-.35C2.79 15.25 3.51 7.7 9.05 7.42c1.42.07 2.4.83 3.23.83.84 0 2.42-1.03 4.07-.88 1.73.14 2.99.82 3.81 2.07-3.49 2.04-2.93 6.51.59 7.83-.65 1.73-1.5 3.45-3.7 4.01zM12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z"/>
              </svg>
              <div>
                <p class="text-[10px] text-gray-400 leading-none">Download on the</p>
                <p class="text-sm font-semibold leading-tight">App Store <span class="text-[10px] font-normal text-gray-500">— Coming Soon</span></p>
              </div>
            </div>

          </div>
        </div>
      </div>
    {{/if}}
  </template>
}

export default AppDownloadModalComponent;
