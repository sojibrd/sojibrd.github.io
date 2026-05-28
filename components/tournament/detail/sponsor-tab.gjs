// app/components/tournament/detail/sponsor-tab.gjs
import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { fn, concat } from '@ember/helper';
import { service } from '@ember/service';

const API_BASE = 'https://spordiumapi.adnanfoundation.com';
const IMAGE_BASE = 'https://ag-khela.s3.ap-south-1.amazonaws.com/';

function sponsorInitials(name = '') {
  return name
    .split(' ')
    .map((w) => w[0])
    .join('')
    .slice(0, 2)
    .toUpperCase();
}

function fileToBase64(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result.split(',')[1]);
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
}

export default class SponsorTab extends Component {
  @service session;

  @tracked showAddModal = false;
  @tracked showEditModal = false;
  @tracked isSaving = false;

  // ── Add form ───────────────────────────────────────────────
  @tracked addName = '';
  @tracked addLogoBase64 = '';
  @tracked addLogoExt = 'jpg';
  @tracked addLogoPreview = null;
  @tracked addBannerBase64 = '';
  @tracked addBannerExt = 'jpg';
  @tracked addBannerPreview = null;

  // ── Edit form ──────────────────────────────────────────────
  @tracked editSponsor = null;
  @tracked editName = '';
  @tracked editLandingPage = ''; // ✅ নতুন
  @tracked editLogoBase64 = '';
  @tracked editLogoExt = 'jpg';
  @tracked editLogoPreview = null;
  @tracked editBannerBase64 = '';
  @tracked editBannerExt = 'jpg';
  @tracked editBannerPreview = null;

  get isOwner() {
    return this.args.isOrganizer ?? false;
  }

  get sponsors() {
    return this.args.sponsors ?? [];
  }

  authHeaders() {
    return this.session.isAuthenticated
      ? { Authorization: `Bearer ${this.session.token}`, 'Content-Type': 'application/json' }
      : { 'Content-Type': 'application/json' };
  }

  // ✅ Bug fix: event propagation stop করার action
  @action
  stopProp(e) {
    e.stopPropagation();
  }

  // ── Add modal ──────────────────────────────────────────────
  @action
  openAddModal() {
    this.addName = '';
    this.addLogoBase64 = '';
    this.addLogoPreview = null;
    this.addBannerBase64 = '';
    this.addBannerPreview = null;
    this.showAddModal = true;
  }

  @action closeAddModal() {
    this.showAddModal = false;
  }

  @action onAddNameInput(e) {
    this.addName = e.target.value;
  }

  @action
  async onAddLogoChange(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    this.addLogoExt = file.name.split('.').pop() ?? 'jpg';
    this.addLogoBase64 = await fileToBase64(file);
    this.addLogoPreview = URL.createObjectURL(file);
  }

  @action
  async onAddBannerChange(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    this.addBannerExt = file.name.split('.').pop() ?? 'jpg';
    this.addBannerBase64 = await fileToBase64(file);
    this.addBannerPreview = URL.createObjectURL(file);
  }

  @action
  async initiateBkashPayment() {
    if (!this.addName.trim()) return;
    this.isSaving = true;
    try {
      const res = await fetch(`${API_BASE}/payment/bkash/initiate/?payment_for=tsa`, {
        method: 'POST',
        headers: this.authHeaders(),
        body: JSON.stringify({
          payment_medium: 'BKASH',
          tournament_id: this.args.tournamentId,
          sponsor_name: this.addName,
        }),
      });
      const json = await res.json();
      if (json.payment_url) {
        window.open(json.payment_url, '_blank');
        this.showAddModal = false;
      }
    } catch {
      /* handle */
    } finally {
      this.isSaving = false;
    }
  }

  // ── Edit modal ─────────────────────────────────────────────
  @action
  openEditModal(sponsor) {
    this.editSponsor = sponsor;
    this.editName = sponsor.sponsor_name ?? '';
    this.editLandingPage = sponsor.sponsor_landing_page ?? ''; // ✅ নতুন
    this.editLogoBase64 = '';
    this.editLogoPreview = sponsor.sponsor_logo ? `${IMAGE_BASE}${sponsor.sponsor_logo}` : null;
    this.editBannerBase64 = '';
    this.editBannerPreview = sponsor.sponsor_banner ? `${IMAGE_BASE}${sponsor.sponsor_banner}` : null;
    this.showEditModal = true;
  }

  @action closeEditModal() {
    this.showEditModal = false;
    this.editSponsor = null;
  }

  @action onEditNameInput(e) {
    this.editName = e.target.value;
  }
  @action onEditLandingPageInput(e) {
    this.editLandingPage = e.target.value;
  } // ✅ নতুন

  @action
  async onEditLogoChange(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    this.editLogoExt = file.name.split('.').pop() ?? 'jpg';
    this.editLogoBase64 = await fileToBase64(file);
    this.editLogoPreview = URL.createObjectURL(file);
  }

  @action
  async onEditBannerChange(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    this.editBannerExt = file.name.split('.').pop() ?? 'jpg';
    this.editBannerBase64 = await fileToBase64(file);
    this.editBannerPreview = URL.createObjectURL(file);
  }

  @action
  async saveEdit() {
    if (!this.editSponsor) return;
    this.isSaving = true;
    try {
      // ✅ শুধু changed fields পাঠাবো
      const payload = {
        sponsor_id: this.editSponsor.sponsor_id,
        sponsor_name: this.editName,
        tournament_id: this.args.tournamentId,
        sponsor_landing_page: this.editLandingPage,
      };

      // ✅ নতুন logo select করলেই পাঠাবো
      if (this.editLogoBase64) {
        payload.sponsor_logo = {
          base64: this.editLogoBase64,
          extension: this.editLogoExt,
        };
      }

      // ✅ নতুন banner select করলেই পাঠাবো
      if (this.editBannerBase64) {
        payload.sponsor_banner = {
          base64: this.editBannerBase64,
          extension: this.editBannerExt,
        };
      }

      const res = await fetch(`${API_BASE}/tournament_v2/update-tournament-sponsor/?sponsor_id=${this.editSponsor.sponsor_id}`, {
        method: 'POST',
        headers: this.authHeaders(),
        body: JSON.stringify(payload),
      });

      if (res.ok) {
        this.closeEditModal();
        // ✅ parent কে refresh করাবো
        this.args.onSponsorUpdated?.();
      }
    } catch {
      /* handle */
    } finally {
      this.isSaving = false;
    }
  }

  <template>
    <div>

      {{! ── Header ── }}
      <div class="flex items-center justify-between mb-5">
        <h3 class="text-sm font-semibold text-gray-700 dark:text-gray-300"></h3>
        {{#if this.isOwner}}
          <button
            type="button"
            {{on "click" this.openAddModal}}
            class="flex items-center gap-1.5 text-xs font-medium px-3 py-2 rounded-lg border border-gray-200 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
          >
            <svg class="w-3.5 h-3.5" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round">
              <path d="M8 3v10M3 8h10" />
            </svg>
            Add sponsor
          </button>
        {{/if}}
      </div>

      {{! ── Grid ── }}
      {{#if this.sponsors.length}}
        <div class="grid grid-cols-2 sm:grid-cols-3 gap-3">
          {{#each this.sponsors as |sponsor|}}
            <div class="bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 rounded-xl overflow-hidden">
              <div class="h-20 bg-gray-100 dark:bg-gray-800 overflow-hidden">
                {{#if sponsor.sponsor_banner}}
                  <img src={{concat IMAGE_BASE sponsor.sponsor_banner}} alt="banner" class="w-full h-full object-cover" />
                {{else}}
                  <div class="w-full h-full flex items-center justify-center">
                    <span class="text-xs text-gray-400">No banner</span>
                  </div>
                {{/if}}
              </div>
              <div class="p-3">
                <div class="flex items-center gap-2 mb-2.5">
                  <div
                    class="w-8 h-8 rounded-full bg-gray-100 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 overflow-hidden flex items-center justify-center shrink-0"
                  >
                    {{#if sponsor.sponsor_logo}}
                      <img src={{concat IMAGE_BASE sponsor.sponsor_logo}} alt={{sponsor.sponsor_name}} class="w-full h-full object-cover" />
                    {{else}}
                      <span class="text-[10px] font-medium text-gray-500">{{sponsorInitials sponsor.sponsor_name}}</span>
                    {{/if}}
                  </div>
                  <span class="text-xs font-semibold text-gray-900 dark:text-white truncate">{{sponsor.sponsor_name}}</span>
                </div>
                <div class="flex gap-1.5">
                  {{#if this.isOwner}}
                    <button
                      type="button"
                      {{on "click" (fn this.openEditModal sponsor)}}
                      class="text-[11px] px-2.5 py-1 rounded-md border border-gray-200 dark:border-gray-700 text-gray-500 hover:bg-gray-50 dark:hover:bg-gray-800"
                    >
                      Edit
                    </button>
                  {{/if}}
                  {{#if sponsor.sponsor_landing_page}}
                    <a
                      href={{sponsor.sponsor_landing_page}}
                      target="_blank"
                      rel="noopener noreferrer"
                      class="text-[11px] px-2.5 py-1 rounded-md border border-blue-200 dark:border-blue-800 text-blue-500"
                    >
                      Visit
                    </a>
                  {{/if}}
                </div>
              </div>
            </div>
          {{/each}}
        </div>
      {{else}}
        <div class="py-16 text-center">
          <p class="text-sm text-gray-400">No sponsors yet.</p>
          {{#if this.isOwner}}
            <p class="text-xs text-gray-400 mt-1">Click "Add sponsor" to get started.</p>
          {{/if}}
        </div>
      {{/if}}

      {{! ══════════════════════════════════════ }}
      {{! ADD MODAL                              }}
      {{! ══════════════════════════════════════ }}
      {{#if this.showAddModal}}
        {{! ✅ Overlay: click → close }}
        <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4" {{on "click" this.closeAddModal}}>

          {{! ✅ Modal div: click → stopPropagation, overlay এ bubble করবে না }}
          <div
            class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 w-full max-w-sm overflow-hidden"
            {{on "click" this.stopProp}}
          >

            <div class="flex items-center justify-between px-4 py-3 border-b border-gray-100 dark:border-gray-800">
              <span class="text-sm font-semibold text-gray-900 dark:text-white">Add sponsor</span>
              <button type="button" {{on "click" this.closeAddModal}} class="text-gray-400 hover:text-gray-600 text-lg leading-none">✕</button>
            </div>

            <div class="p-4 flex flex-col gap-4">
              <div class="flex flex-col gap-1.5">
                <label class="text-xs font-medium text-gray-500">Sponsor name</label>
                <input
                  type="text"
                  placeholder="e.g. John Doe"
                  value={{this.addName}}
                  {{on "input" this.onAddNameInput}}
                  class="text-sm px-3 py-2 rounded-lg border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-white"
                />
              </div>
              {{!-- 
              <div class="flex flex-col gap-1.5">
                <label class="text-xs font-medium text-gray-500">Logo</label>
                <div class="flex items-center gap-3">
                  <div
                    class="w-10 h-10 rounded-full bg-gray-100 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 overflow-hidden flex items-center justify-center shrink-0"
                  >
                    {{#if this.addLogoPreview}}
                      <img src={{this.addLogoPreview}} alt="preview" class="w-full h-full object-cover" />
                    {{else}}
                      <span class="text-[10px] text-gray-400">Logo</span>
                    {{/if}}
                  </div>
                  <label
                    class="text-xs px-3 py-1.5 rounded-md border border-gray-200 dark:border-gray-700 text-gray-500 cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-800"
                  >
                    Choose image
                    <input type="file" accept="image/*" class="hidden" {{on "change" this.onAddLogoChange}} />
                  </label>
                </div>
              </div>

              <div class="flex flex-col gap-1.5">
                <label class="text-xs font-medium text-gray-500">Banner</label>
                <div class="flex items-center gap-3">
                  <div
                    class="w-20 h-10 rounded-md bg-gray-100 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 overflow-hidden flex items-center justify-center shrink-0"
                  >
                    {{#if this.addBannerPreview}}
                      <img src={{this.addBannerPreview}} alt="preview" class="w-full h-full object-cover" />
                    {{else}}
                      <span class="text-[10px] text-gray-400">Banner</span>
                    {{/if}}
                  </div>
                  <label
                    class="text-xs px-3 py-1.5 rounded-md border border-gray-200 dark:border-gray-700 text-gray-500 cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-800"
                  >
                    Choose image
                    <input type="file" accept="image/*" class="hidden" {{on "change" this.onAddBannerChange}} />
                  </label>
                </div>
              </div> --}}

              {{! bKash button }}
              <button
                type="button"
                {{on "click" this.initiateBkashPayment}}
                disabled={{this.isSaving}}
                class="w-full py-2.5 rounded-lg font-medium text-sm text-white flex items-center justify-center gap-2 disabled:opacity-50"
                style="background-color: #E2136E;"
              >
                {{#if this.isSaving}}
                  Processing...
                {{else}}
                  <span style="font-weight:700;letter-spacing:-0.5px;">bKash</span>
                  Pay & add sponsor
                {{/if}}
              </button>
            </div>
          </div>
        </div>
      {{/if}}

      {{! ══════════════════════════════════════ }}
      {{! EDIT MODAL                             }}
      {{! ══════════════════════════════════════ }}
      {{#if this.showEditModal}}
        {{! ✅ Overlay }}
        <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4" {{on "click" this.closeEditModal}}>

          {{! ✅ Modal: stopPropagation }}
          <div
            class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 w-full max-w-sm overflow-hidden"
            {{on "click" this.stopProp}}
          >

            <div class="flex items-center justify-between px-4 py-3 border-b border-gray-100 dark:border-gray-800">
              <span class="text-sm font-semibold text-gray-900 dark:text-white">Edit sponsor</span>
              <button type="button" {{on "click" this.closeEditModal}} class="text-gray-400 hover:text-gray-600 text-lg leading-none">✕</button>
            </div>

            <div class="p-4 flex flex-col gap-4">

              <div class="flex flex-col gap-1.5">
                <label class="text-xs font-medium text-gray-500">Sponsor name</label>
                <input
                  type="text"
                  value={{this.editName}}
                  {{on "input" this.onEditNameInput}}
                  class="text-sm px-3 py-2 rounded-lg border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-white"
                />
              </div>

              {{! ✅ নতুন: Landing page field }}
              <div class="flex flex-col gap-1.5">
                <label class="text-xs font-medium text-gray-500">Landing page URL</label>
                <input
                  type="url"
                  placeholder="https://example.com"
                  value={{this.editLandingPage}}
                  {{on "input" this.onEditLandingPageInput}}
                  class="text-sm px-3 py-2 rounded-lg border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-white"
                />
              </div>

              <div class="flex flex-col gap-1.5">
                <label class="text-xs font-medium text-gray-500">Logo</label>
                <div class="flex items-center gap-3">
                  <div
                    class="w-10 h-10 rounded-full bg-gray-100 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 overflow-hidden flex items-center justify-center shrink-0"
                  >
                    {{#if this.editLogoPreview}}
                      <img src={{this.editLogoPreview}} alt="logo" class="w-full h-full object-cover" />
                    {{else}}
                      <span class="text-[10px] text-gray-400">Logo</span>
                    {{/if}}
                  </div>
                  <label
                    class="text-xs px-3 py-1.5 rounded-md border border-gray-200 dark:border-gray-700 text-gray-500 cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-800"
                  >
                    Change
                    <input type="file" accept="image/*" class="hidden" {{on "change" this.onEditLogoChange}} />
                  </label>
                </div>
              </div>

              <div class="flex flex-col gap-1.5">
                <label class="text-xs font-medium text-gray-500">Banner</label>
                <div class="flex items-center gap-3">
                  <div
                    class="w-20 h-10 rounded-md bg-gray-100 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 overflow-hidden flex items-center justify-center shrink-0"
                  >
                    {{#if this.editBannerPreview}}
                      <img src={{this.editBannerPreview}} alt="banner" class="w-full h-full object-cover" />
                    {{else}}
                      <span class="text-[10px] text-gray-400">Banner</span>
                    {{/if}}
                  </div>
                  <label
                    class="text-xs px-3 py-1.5 rounded-md border border-gray-200 dark:border-gray-700 text-gray-500 cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-800"
                  >
                    Change
                    <input type="file" accept="image/*" class="hidden" {{on "change" this.onEditBannerChange}} />
                  </label>
                </div>
              </div>
            </div>

            <div class="flex justify-end gap-2 px-4 py-3 border-t border-gray-100 dark:border-gray-800">
              <button
                type="button"
                {{on "click" this.closeEditModal}}
                class="text-xs px-3 py-2 rounded-lg border border-gray-200 dark:border-gray-700 text-gray-500"
              >
                Cancel
              </button>
              <button
                type="button"
                {{on "click" this.saveEdit}}
                disabled={{this.isSaving}}
                class="text-xs px-3 py-2 rounded-lg border border-blue-200 dark:border-blue-800 bg-blue-50 dark:bg-blue-900/20 text-blue-600 dark:text-blue-400 font-medium disabled:opacity-50"
              >
                {{if this.isSaving "Saving..." "Save changes"}}
              </button>
            </div>
          </div>
        </div>
      {{/if}}

    </div>
  </template>
}
