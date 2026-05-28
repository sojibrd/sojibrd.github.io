import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { fn, array } from '@ember/helper';
import { modifier } from 'ember-modifier';
import { eq } from 'ember-truth-helpers';
import config from 'spordium/config/environment';

const SEARCH_API_HOST = config.APP.SEARCH_API_HOST;
const S3_BUCKET_URL = config.APP.S3_BUCKET_URL;

const _initialized = new WeakSet();

const onInsert = modifier((el, [fn]) => {
  if (!_initialized.has(el)) {
    _initialized.add(el);
    fn();
  }
});

class SwitchScorerModalComponent extends Component {
  @tracked scorers = [];
  @tracked selectedId = null;
  @tracked isLoading = false;
  @tracked error = null;

  get isSendDisabled() {
    return !this.selectedId;
  }

  @action
  async fetchScorers() {
    const gameScorer = this.args.gameScorer;
    const activeScorerId = this.args.activeScorerId;

    if (!gameScorer?.length) return;

    // Extract IDs and exclude active scorer
    const ids = gameScorer
      .map((s) => s?.id || s?.user_id || (typeof s === 'string' ? s : null))
      .filter(Boolean)
      .filter((id) => String(id) !== String(activeScorerId));

    if (!ids.length) {
      this.scorers = [];
      return;
    }

    this.isLoading = true;
    this.error = null;

    try {
      const idsParam = encodeURIComponent(JSON.stringify(ids));
      const url = `${SEARCH_API_HOST}/search/cricket-role-details-by-id/?ids=${idsParam}&role=cricketscorer`;
      const response = await fetch(url);
      if (!response.ok) throw new Error('Failed to fetch');
      const data = await response.json();
      const list = Array.isArray(data) ? data : (data?.results || data?.data || []);

      this.scorers = ids.map((id, i) => {
        const m = list[i] || {};
        const first = m?.user_fullname?.first_name || '';
        const last = m?.user_fullname?.last_name || '';
        const name = `${first} ${last}`.trim() || m?.user_username || m?.user_email || '—';
        const picPath = m?.user_primary_pic;
        const avatar = picPath ? `${S3_BUCKET_URL}/${picPath}` : null;
        return { id, name, avatar, initial: name.charAt(0).toUpperCase() };
      });
    } catch {
      this.error = 'Could not load scorers. Please try again.';
    } finally {
      this.isLoading = false;
    }
  }

  @action
  selectScorer(id) {
    this.selectedId = this.selectedId === id ? null : id;
  }

  @action
  handleClose() {
    this.selectedId = null;
    this.scorers = [];
    this.error = null;
    this.args.onClose?.();
  }

  @action
  handleSend() {
    if (!this.selectedId) return;
    const scorer = this.scorers.find((s) => s.id === this.selectedId);
    if (scorer) this.args.onSend?.(scorer);
    this.handleClose();
  }

  <template>
    {{#if @isOpen}}
      <div
        class="fixed inset-0 z-50 flex items-end sm:items-center justify-center"
        {{onInsert this.fetchScorers}}
        role="dialog"
        aria-modal="true"
      >
        {{! Backdrop }}
        <div
          class="absolute inset-0 bg-black/60 backdrop-blur-sm"
          role="presentation"
          {{on "click" this.handleClose}}
        ></div>

        {{! Sheet }}
        <div class="relative w-full sm:max-w-sm bg-slate-800 rounded-t-2xl sm:rounded-2xl shadow-2xl border border-slate-700/60 z-10 flex flex-col max-h-[80vh]">

          {{! Header }}
          <div class="px-6 pt-6 pb-4 border-b border-slate-700/50 flex-shrink-0">
            <h3 class="text-white font-bold text-lg">Other Scorers</h3>
            <p class="text-gray-400 text-sm mt-0.5">Select a player to assign the active scorer role.</p>
          </div>

          {{! Body }}
          <div class="px-6 py-4 overflow-y-auto flex-1">
            {{#if this.isLoading}}
              {{#each (array 1 2 3) as |_|}}
                <div class="flex items-center gap-3 p-3 rounded-xl animate-pulse mb-2">
                  <div class="w-10 h-10 rounded-full bg-slate-700 flex-shrink-0"></div>
                  <div class="flex-1 h-4 bg-slate-700 rounded"></div>
                  <div class="w-5 h-5 rounded-full bg-slate-700"></div>
                </div>
              {{/each}}

            {{else if this.error}}
              <p class="text-red-400 text-sm text-center py-4">{{this.error}}</p>

            {{else if this.scorers.length}}
              {{#each this.scorers as |scorer|}}
                <button
                  type="button"
                  class="w-full flex items-center gap-3 p-3 rounded-xl transition-colors mb-1 text-left
                    {{if (eq this.selectedId scorer.id) 'bg-slate-700' 'hover:bg-slate-700/50'}}"
                  {{on "click" (fn this.selectScorer scorer.id)}}
                >
                  {{! Avatar }}
                  <div class="w-10 h-10 rounded-full flex-shrink-0 flex items-center justify-center overflow-hidden bg-blue-900 text-white text-sm font-bold">
                    {{#if scorer.avatar}}
                      <img src={{scorer.avatar}} alt={{scorer.name}} class="w-full h-full object-cover" />
                    {{else}}
                      {{scorer.initial}}
                    {{/if}}
                  </div>

                  {{! Name }}
                  <span class="flex-1 text-gray-200 text-sm font-medium truncate">{{scorer.name}}</span>

                  {{! Radio }}
                  <div class="w-5 h-5 rounded-full border-2 flex-shrink-0 flex items-center justify-center
                    {{if (eq this.selectedId scorer.id) 'border-cyan-400' 'border-gray-500'}}">
                    {{#if (eq this.selectedId scorer.id)}}
                      <div class="w-2.5 h-2.5 rounded-full bg-cyan-400"></div>
                    {{/if}}
                  </div>
                </button>
              {{/each}}

            {{else}}
              <p class="text-gray-500 text-sm text-center py-6">No other scorers available.</p>
            {{/if}}
          </div>

          {{! Footer }}
          <div class="px-6 py-4 border-t border-slate-700/50 flex justify-end gap-3 flex-shrink-0">
            <button
              type="button"
              class="px-5 py-2 text-sm font-semibold text-gray-300 hover:text-white transition-colors"
              {{on "click" this.handleClose}}
            >
              Back
            </button>
            <button
              type="button"
              class="flex items-center gap-2 px-5 py-2 rounded-xl text-sm font-semibold transition-colors
                {{if this.isSendDisabled
                  'bg-slate-700 text-gray-500 cursor-not-allowed'
                  'bg-cyan-600 hover:bg-cyan-500 text-white'}}"
              {{on "click" this.handleSend}}
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
              </svg>
              Send
            </button>
          </div>

        </div>
      </div>
    {{/if}}
  </template>
}

export default SwitchScorerModalComponent;
