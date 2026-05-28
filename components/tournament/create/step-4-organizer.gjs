import Component from '@glimmer/component';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import lucideIcon from 'spordium/helpers/lucide-icon';
import { eq, gt } from 'ember-truth-helpers';

// ─────────────────────────────────────────────────────────────────────────────
const ORGANIZER_ROLES = ['Tournament Director', 'Club President', 'Event Manager', 'Association Secretary', 'Sponsor Representative', 'Individual Organizer'];

const HOST_ROLES = ['Venue Owner', 'Title Sponsor', 'Co-Sponsor', 'Ground Manager', 'Broadcast Partner', 'Media Partner'];

const CO_ORGANIZER_ROLES = ['Co-Organizer', 'Co-Host', 'Supporting Sponsor', 'Media Partner', 'Logistics Partner', 'Volunteer Coordinator'];

// ══════════════════════════════════════════════════════════════════════════════
// Step 4 — Organizer + Host info + logo upload
//
// @arg {Object}   data           — wizard shared data object
// @arg {Function} onUpdate       — (key, value) update handler
// @arg {Function} onLogoUpload   — (file) => { previewUrl, objectToken }
// ══════════════════════════════════════════════════════════════════════════════
export default class TournamentStep4 extends Component {
  @tracked logoUploading = false;
  @tracked logoError = null;

  // ── getters ───────────────────────────────────────────────────────────────
  get d() {
    return this.args.data ?? {};
  }

  get organizerRoles() {
    return ORGANIZER_ROLES;
  }
  get hostRoles() {
    return HOST_ROLES;
  }
  get coOrganizerRoles() {
    return CO_ORGANIZER_ROLES;
  }

  get coOrganizers() {
    return this.d.coOrganizers ?? [];
  }

  // ── actions — general ─────────────────────────────────────────────────────
  @action
  onInput(key, e) {
    this.args.onUpdate(key, e.target.value);
  }

  @action
  onSelect(key, e) {
    this.args.onUpdate(key, e.target.value);
  }

  // ── actions — logo ────────────────────────────────────────────────────────
  @action
  async onLogoChange(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    this.logoUploading = true;
    this.logoError = null;
    try {
      await this.args.onLogoUpload(file);
    } catch {
      this.logoError = 'Upload failed. Please try again.';
    } finally {
      this.logoUploading = false;
    }
  }

  // ── actions — co-organizers ───────────────────────────────────────────────
  @action
  addCoOrganizer() {
    const updated = [...this.coOrganizers, { id: crypto.randomUUID(), name: '', phone: '', role: '' }];
    this.args.onUpdate('coOrganizers', updated);
  }

  @action
  removeCoOrganizer(id) {
    this.args.onUpdate(
      'coOrganizers',
      this.coOrganizers.filter((c) => c.id !== id)
    );
  }

  @action
  updateCoOrganizer(id, field, e) {
    const updated = this.coOrganizers.map((c) => (c.id === id ? { ...c, [field]: e.target.value } : c));
    this.args.onUpdate('coOrganizers', updated);
  }

  <template>
    <div class="space-y-8">

      {{! ── Section header ──────────────────────────────────────────────── }}
      <div>
        <h2 class="text-lg font-bold text-gray-900 dark:text-white">
          Organizer &amp; Host
        </h2>
        <p class="text-sm text-gray-500 dark:text-gray-400 mt-0.5">
          Who is organizing and hosting this tournament
        </p>
      </div>

      {{! ══════════════════════════════════════════════════════════════════ }}
      {{! PRIMARY ORGANIZER                                                  }}
      {{! ══════════════════════════════════════════════════════════════════ }}
      <div class="space-y-5">
        <h3 class="text-sm font-bold text-gray-700 dark:text-gray-300 flex items-center gap-1.5">
          {{lucideIcon "user-circle" class="w-4 h-4 text-blue-500"}}
          Primary Organizer
        </h3>

        {{! Logo }}
        <div>
          <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
            Organizer Logo
          </label>
          <p class="text-xs text-gray-400 mb-2">
            Recommended 200×200 px · Max 1200 KB · PNG or JPG
          </p>
          <div class="flex items-center gap-4">
            <div
              class="w-20 h-20 rounded-2xl border-2 border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-800 overflow-hidden flex items-center justify-center shrink-0"
            >
              {{#if this.d.logoPreview}}
                <img src={{this.d.logoPreview}} alt="Logo" class="w-full h-full object-cover" />
              {{else}}
                {{lucideIcon "image" class="w-8 h-8 text-gray-300 dark:text-gray-600"}}
              {{/if}}
            </div>
            <div class="flex-1">
              <label
                class="cursor-pointer inline-flex items-center gap-2 px-4 py-2 text-sm font-medium rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:border-blue-400 transition-colors"
              >
                {{#if this.logoUploading}}
                  <div class="w-4 h-4 border-2 border-blue-500 border-t-transparent rounded-full animate-spin"></div>
                  Uploading…
                {{else}}
                  {{lucideIcon "upload" class="w-4 h-4"}}
                  Upload Logo
                {{/if}}
                <input type="file" accept="image/*" class="hidden" {{on "change" this.onLogoChange}} />
              </label>
              {{#if this.logoError}}
                <p class="text-xs text-red-500 mt-1.5">{{this.logoError}}</p>
              {{/if}}
            </div>
          </div>
        </div>

        {{! Name + Role }}
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
              Organizer Name
              <span class="text-red-500">*</span>
            </label>
            <input
              type="text"
              value={{this.d.organizerName}}
              placeholder="Club, association, or individual"
              {{on "input" (fn this.onInput "organizerName")}}
              class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <div>
            <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
              Organizer Role
              <span class="text-red-500">*</span>
            </label>
            <select
              {{on "change" (fn this.onSelect "organizerRole")}}
              class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="">Select role…</option>
              {{#each this.organizerRoles as |role|}}
                <option value={{role}} selected={{eq this.d.organizerRole role}}>
                  {{role}}
                </option>
              {{/each}}
            </select>
          </div>
        </div>

        {{! Email + Phone }}
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
              Contact Email
            </label>
            <input
              type="email"
              value={{this.d.organizerEmail}}
              placeholder="organizer@example.com"
              {{on "input" (fn this.onInput "organizerEmail")}}
              class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <div>
            <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
              Contact Phone
            </label>
            <input
              type="tel"
              value={{this.d.organizerPhone}}
              placeholder="+880 1XXX-XXXXXX"
              {{on "input" (fn this.onInput "organizerPhone")}}
              class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
        </div>
      </div>

      {{! ══════════════════════════════════════════════════════════════════ }}
      {{! EVENT HOST                                                         }}
      {{! ══════════════════════════════════════════════════════════════════ }}
      <div class="space-y-4 pt-6 border-t border-gray-100 dark:border-gray-700">
        <h3 class="text-sm font-bold text-gray-700 dark:text-gray-300 flex items-center gap-1.5">
          {{lucideIcon "building-2" class="w-4 h-4 text-gray-400"}}
          Event Host
          <span class="text-xs font-normal text-gray-400 ml-1">(optional)</span>
        </h3>

        {{! Host Name + Role }}
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label class="block text-xs font-semibold text-gray-600 dark:text-gray-400 mb-1">
              Host Name
            </label>
            <input
              type="text"
              value={{this.d.hostName}}
              placeholder="Venue or sponsor name"
              {{on "input" (fn this.onInput "hostName")}}
              class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-600 dark:text-gray-400 mb-1">
              Host Role
            </label>
            <select
              {{on "change" (fn this.onSelect "hostRole")}}
              class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="">Select role…</option>
              {{#each this.hostRoles as |role|}}
                <option value={{role}} selected={{eq this.d.hostRole role}}>
                  {{role}}
                </option>
              {{/each}}
            </select>
          </div>
        </div>

        {{! Host Phone + Website }}
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label class="block text-xs font-semibold text-gray-600 dark:text-gray-400 mb-1">
              Host Phone
            </label>
            <input
              type="tel"
              value={{this.d.hostPhone}}
              placeholder="+880 1XXX-XXXXXX"
              {{on "input" (fn this.onInput "hostPhone")}}
              class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-600 dark:text-gray-400 mb-1">
              Host Website
            </label>
            <input
              type="url"
              value={{this.d.hostWebsite}}
              placeholder="https://example.com"
              {{on "input" (fn this.onInput "hostWebsite")}}
              class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
        </div>
      </div>

      {{! ══════════════════════════════════════════════════════════════════ }}
      {{! CO-ORGANIZERS / CO-HOSTS                                           }}
      {{! ══════════════════════════════════════════════════════════════════ }}
      <div class="space-y-4 pt-6 border-t border-gray-100 dark:border-gray-700">
        <div class="flex items-center justify-between">
          <h3 class="text-sm font-bold text-gray-700 dark:text-gray-300 flex items-center gap-1.5">
            {{lucideIcon "users" class="w-4 h-4 text-gray-400"}}
            Co-Organizers / Co-Hosts
            <span class="text-xs font-normal text-gray-400 ml-1">(optional)</span>
          </h3>
          <button
            type="button"
            {{on "click" this.addCoOrganizer}}
            class="flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold rounded-xl border border-blue-200 dark:border-blue-800 bg-blue-50 dark:bg-blue-900/20 text-blue-600 dark:text-blue-400 hover:bg-blue-100 dark:hover:bg-blue-900/30 transition-colors"
          >
            {{lucideIcon "plus" class="w-3.5 h-3.5"}}
            Add
          </button>
        </div>

        {{#if (gt this.coOrganizers.length 0)}}
          <div class="space-y-3">
            {{#each this.coOrganizers as |co|}}
              <div class="relative p-4 rounded-2xl border border-gray-200 dark:border-gray-700 bg-gray-50/50 dark:bg-gray-800/30 space-y-3">
                {{! Remove button }}
                <button
                  type="button"
                  {{on "click" (fn this.removeCoOrganizer co.id)}}
                  class="absolute top-3 right-3 p-1.5 rounded-lg hover:bg-red-50 dark:hover:bg-red-900/20 text-gray-400 hover:text-red-500 transition-colors"
                >
                  {{lucideIcon "x" class="w-3.5 h-3.5"}}
                </button>

                {{! Name + Role }}
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 pr-8">
                  <div>
                    <label class="block text-xs font-semibold text-gray-600 dark:text-gray-400 mb-1">
                      Name
                    </label>
                    <input
                      type="text"
                      value={{co.name}}
                      placeholder="Name or organization"
                      {{on "input" (fn this.updateCoOrganizer co.id "name")}}
                      class="w-full px-3 py-2 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                  </div>
                  <div>
                    <label class="block text-xs font-semibold text-gray-600 dark:text-gray-400 mb-1">
                      Role
                    </label>
                    <select
                      {{on "change" (fn this.updateCoOrganizer co.id "role")}}
                      class="w-full px-3 py-2 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500"
                    >
                      <option value="">Select role…</option>
                      {{#each this.coOrganizerRoles as |role|}}
                        <option value={{role}} selected={{eq co.role role}}>
                          {{role}}
                        </option>
                      {{/each}}
                    </select>
                  </div>
                </div>

                {{! Phone }}
                <div class="sm:w-1/2">
                  <label class="block text-xs font-semibold text-gray-600 dark:text-gray-400 mb-1">
                    Phone
                  </label>
                  <input
                    type="tel"
                    value={{co.phone}}
                    placeholder="+880 1XXX-XXXXXX"
                    {{on "input" (fn this.updateCoOrganizer co.id "phone")}}
                    class="w-full px-3 py-2 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                </div>
              </div>
            {{/each}}
          </div>
        {{else}}
          <div class="flex items-center gap-2 px-4 py-3 rounded-xl bg-gray-50 dark:bg-gray-800/50 border border-dashed border-gray-200 dark:border-gray-700">
            {{lucideIcon "user-plus" class="w-4 h-4 text-gray-300 dark:text-gray-600 shrink-0"}}
            <p class="text-sm text-gray-400">
              No co-organizers added yet
            </p>
          </div>
        {{/if}}
      </div>

    </div>
  </template>
}
