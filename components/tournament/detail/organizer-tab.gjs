// app/components/tournament/detail/organizer-tab.gjs

import Component from '@glimmer/component';
import { concat } from '@ember/helper';
import lucideIcon from 'spordium/helpers/lucide-icon';

const IMAGE_BASE = 'https://ag-khela.s3.ap-south-1.amazonaws.com/';

function getInitials(name = '') {
  return name.trim().charAt(0).toUpperCase() || '?';
}

function formatType(type = '') {
  return type
    .split('-')
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
    .join(' ');
}

export default class OrganizerTab extends Component {
  get hosts() {
    return this.args.data?.host_data ?? [];
  }

  get organizers() {
    return this.args.data?.organizer_data ?? [];
  }

  get hasData() {
    return this.hosts.length > 0 || this.organizers.length > 0;
  }

  <template>
    <div class="flex flex-col gap-6">

      {{#if this.hasData}}

        {{! ── Host Section ── }}
        {{#if this.hosts.length}}
          <section class="flex flex-col gap-3">
            <p class="text-xs font-semibold tracking-widest uppercase text-gray-400 dark:text-gray-500 m-0">
              Host
            </p>
            {{#each this.hosts as |host|}}
              <div class="flex items-center gap-4 bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-700 rounded-2xl px-5 py-4">

                {{#if host.host_logo}}
                  <img src={{concat IMAGE_BASE host.host_logo}} alt={{host.host_name}} class="w-12 h-12 rounded-full object-cover flex-shrink-0" />
                {{else}}
                  <div
                    class="w-12 h-12 rounded-full flex-shrink-0 flex items-center justify-center text-lg font-medium bg-blue-50 text-blue-800 dark:bg-blue-950 dark:text-blue-200"
                  >
                    {{getInitials host.host_name}}
                  </div>
                {{/if}}

                <div class="flex-1 min-w-0">
                  <p class="text-sm font-medium text-gray-900 dark:text-white m-0">
                    {{host.host_name}}
                  </p>
                  <p class="text-xs text-gray-500 dark:text-gray-400 mt-1 m-0">
                    {{if host.host_role host.host_role (formatType host.host_type)}}
                  </p>
                </div>

                <div class="flex flex-col items-end gap-2 flex-shrink-0">
                  <span class="text-xs font-medium px-2.5 py-1 rounded-full bg-blue-50 text-blue-700 dark:bg-blue-950 dark:text-blue-300">
                    Host
                  </span>
                  <div class="flex gap-2">
                    {{#if host.host_email}}
                      <a
                        href={{concat "mailto:" host.host_email}}
                        class="w-7 h-7 rounded-full bg-gray-50 dark:bg-gray-800 border border-gray-100 dark:border-gray-700 flex items-center justify-center text-gray-500 hover:text-gray-700 transition-colors"
                      >
                        {{lucideIcon "mail" class="w-3.5 h-3.5"}}
                      </a>
                    {{/if}}
                    {{#if host.host_phone}}
                      <a
                        href={{concat "tel:" host.host_phone}}
                        class="w-7 h-7 rounded-full bg-gray-50 dark:bg-gray-800 border border-gray-100 dark:border-gray-700 flex items-center justify-center text-gray-500 hover:text-gray-700 transition-colors"
                      >
                        {{lucideIcon "phone" class="w-3.5 h-3.5"}}
                      </a>
                    {{/if}}
                  </div>
                </div>

              </div>
            {{/each}}
          </section>
        {{/if}}

        {{! ── Organizer Section ── }}
        {{#if this.organizers.length}}
          <section class="flex flex-col gap-3">
            <p class="text-xs font-semibold tracking-widest uppercase text-gray-400 dark:text-gray-500 m-0">
              Organizer
            </p>
            {{#each this.organizers as |org|}}
              <div class="flex items-center gap-4 bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-700 rounded-2xl px-5 py-4">

                {{#if org.organizer_logo}}
                  <img
                    src={{concat IMAGE_BASE org.organizer_logo}}
                    alt={{org.organizer_name}}
                    class="w-12 h-12 rounded-full object-cover flex-shrink-0"
                  />
                {{else}}
                  <div
                    class="w-12 h-12 rounded-full flex-shrink-0 flex items-center justify-center text-lg font-medium bg-emerald-50 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-200"
                  >
                    {{getInitials org.organizer_name}}
                  </div>
                {{/if}}

                <div class="flex-1 min-w-0">
                  <p class="text-sm font-medium text-gray-900 dark:text-white m-0">
                    {{org.organizer_name}}
                  </p>
                  <p class="text-xs text-gray-500 dark:text-gray-400 mt-1 m-0">
                    {{if org.organizer_role org.organizer_role (formatType org.organizer_type)}}
                  </p>
                </div>

                <div class="flex flex-col items-end gap-2 flex-shrink-0">
                  <span class="text-xs font-medium px-2.5 py-1 rounded-full bg-emerald-50 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-300">
                    Organizer
                  </span>
                  <div class="flex gap-2">
                    {{#if org.organizer_email}}
                      <a
                        href={{concat "mailto:" org.organizer_email}}
                        class="w-7 h-7 rounded-full bg-gray-50 dark:bg-gray-800 border border-gray-100 dark:border-gray-700 flex items-center justify-center text-gray-500 hover:text-gray-700 transition-colors"
                      >
                        {{lucideIcon "mail" class="w-3.5 h-3.5"}}
                      </a>
                    {{/if}}
                    {{#if org.organizer_phone}}
                      <a
                        href={{concat "tel:" org.organizer_phone}}
                        class="w-7 h-7 rounded-full bg-gray-50 dark:bg-gray-800 border border-gray-100 dark:border-gray-700 flex items-center justify-center text-gray-500 hover:text-gray-700 transition-colors"
                      >
                        {{lucideIcon "phone" class="w-3.5 h-3.5"}}
                      </a>
                    {{/if}}
                  </div>
                </div>

              </div>
            {{/each}}
          </section>
        {{/if}}

      {{else}}
        <div class="py-16 text-center text-sm text-gray-400">
          No organizer information available.
        </div>
      {{/if}}

    </div>
  </template>
}
