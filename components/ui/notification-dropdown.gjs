import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { service } from '@ember/service';
import { on } from '@ember/modifier';
import { fn, array } from '@ember/helper';
import { eq, or } from 'ember-truth-helpers';
import { markNotificationActioned } from 'spordium/utils/notification-action';

const NOTIFICATION_LABELS = {
  active_scorer_offer_request: 'Scorer Request',
  active_scorer_request_request: 'Scorer Request',
  active_scorer_request_response: 'Scorer Response',
  club_manager_response: 'Club',
  overend_data_confirmation: 'Overend Data Confirmation',
  umpire_request: 'Umpire Request',
  umpire_response: 'Umpire Response',
  streamer_request: 'Streamer Request',
  team_player_add: 'Team Player Add',
  accepted: 'Accepted',
};

function notifLabel(type) {
  return NOTIFICATION_LABELS[type] || type;
}

function timeAgo(dateStr) {
  if (!dateStr) return '';
  const diffMs = new Date() - new Date(dateStr);
  const diffMins = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMs / 3600000);
  const diffDays = Math.floor(diffMs / 86400000);
  if (diffMins < 1) return 'just now';
  if (diffMins < 60) return `${diffMins}m ago`;
  if (diffHours < 24) return `${diffHours}h ago`;
  return `${diffDays}d ago`;
}

class NotificationDropdownComponent extends Component {
  @service store;
  @service session;
  @service api;
  @service toast;
  @service router;

  @tracked isOpen = false;
  @tracked notifications = [];
  @tracked isLoading = false;
  @tracked error = null;
  @tracked processingId = null;
  @tracked activeOverNotif = null;
  @tracked isSendingUmpireRequest = false;
  @tracked dropdownStyle = '';

  get userId() {
    return this.session.currentUser?.user_id;
  }

  get hasUnread() {
    return this.notifications.length > 0;
  }

  get documentBody() {
    return document.body;
  }

  @action
  async toggleDropdown(e) {
    if (!this.isOpen) {
      const rect = e.currentTarget.getBoundingClientRect();
      const top = rect.bottom + 8;
      const DROPDOWN_WIDTH = 320;
      if (rect.right >= DROPDOWN_WIDTH) {
        this.dropdownStyle = `top:${top}px;right:${window.innerWidth - rect.right}px;`;
      } else {
        this.dropdownStyle = `top:${top}px;left:${Math.max(8, rect.left)}px;`;
      }
    }
    this.isOpen = !this.isOpen;
    if (this.isOpen && !this.notifications.length) {
      await this.fetchNotifications();
    }
  }

  @action
  closeDropdown() {
    this.isOpen = false;
  }

  @action
  async respond(notif, accept) {
    if (this.processingId) return;
    this.processingId = notif.id;
    try {
      const res = await this.api.post('/live_scoring/active-scorrer-accept/', {
        match_id: notif.matchId,
        accept: String(accept),
      });
      const msg = res?.message;
      if (accept) {
        this.toast.success(msg || 'Request accepted.');
      } else {
        this.toast.info(msg || 'Request declined.');
      }
      markNotificationActioned(this.api, notif.id);
      this.notifications = this.notifications.filter((n) => n.id !== notif.id);
    } catch (e) {
      this.toast.error(e?.payload?.message || 'Something went wrong.');
    } finally {
      this.processingId = null;
    }
  }
  @action
  async respondToTeamPlayerAdd(notif, accept) {
    if (this.processingId) return;
    this.processingId = notif.id;
    try {
      const payload = {
        team_id: notif.teamId,
        action: String(accept),
      };
      console.log('payload', payload);

      const res = await this.api.post(
        '/team/update_Player_in_team_accept_decline/',
        payload,
      );
      const msg = res?.message;
      if (accept) {
        this.toast.success(msg || 'Request accepted.');
      } else {
        this.toast.info(msg || 'Request declined.');
      }
      markNotificationActioned(this.api, notif.id);
      this.notifications = this.notifications.filter((n) => n.id !== notif.id);
    } catch (e) {
      this.toast.error(e?.payload?.message || 'Something went wrong.');
    } finally {
      this.processingId = null;
    }
  }

  @action
  async respondToRoleRequest(notif, accept) {
    if (this.processingId) return;
    this.processingId = notif.id;
    try {
      const ACCEPT_ID_KEY = {
        umpire_request: 'umpire_id',
        streamer_request: 'streamer_id',
        scorer_request: 'scorer_id',
      };
      const idKey = ACCEPT_ID_KEY[notif.notificationType] ?? 'umpire_id';
      const res = await this.api.post('/role/accept-role/', {
        game_id: notif.gameId,
        [idKey]: this.userId,
        notification_id: notif.id,
        action: accept ? 'accepted' : 'declined',
        owner: notif.owner,
      });
      const msg = res?.message;
      if (accept) {
        this.toast.success(msg || 'Request accepted.');
      } else {
        this.toast.info(msg || 'Request declined.');
      }
      markNotificationActioned(this.api, notif.id);
      this.notifications = this.notifications.filter((n) => n.id !== notif.id);
    } catch (e) {
      this.toast.error(e?.payload?.message || 'Something went wrong.');
    } finally {
      this.processingId = null;
    }
  }

  @action
  openOverModal(notif) {
    this.isOpen = false;
    this.activeOverNotif = notif;
  }

  @action
  closeOverModal() {
    this.activeOverNotif = null;
  }

  @action
  stopPropagation(e) {
    e.stopPropagation();
  }

  @action
  async sendUmpireRequest() {
    const notif = this.activeOverNotif;
    if (!notif || this.isSendingUmpireRequest) return;
    this.isSendingUmpireRequest = true;
    try {
      const uniqueId = (notif.uniqueId || '').replace(/_s$/, '_u');
      await this.api.post('/live_scoring/over-end-roles-request/', {
        type: 'umpire',
        match_id: notif.matchId,
        match_name: notif.matchName,
        over: notif.over,
        notification_type: 'overend_data_confirmation',
        unique_id: uniqueId,
      });
      this.toast.success('Request sent to umpire.');
      this.activeOverNotif = null;
    } catch (e) {
      this.toast.error(e?.payload?.message || 'Failed to send request.');
    } finally {
      this.isSendingUmpireRequest = false;
    }
  }

  async fetchNotifications() {
    if (!this.userId) return;

    this.isLoading = true;
    this.error = null;

    try {
      const results = await this.store.query('notification', {
        userId: this.userId,
        limit: 10,
        offset: 0,
      });
      this.notifications = results.slice();
    } catch {
      this.error = 'Could not load notifications.';
    } finally {
      this.isLoading = false;
    }
  }

  <template>
    {{! Over-end confirmation popup }}
    {{#if this.activeOverNotif}}
      {{#let this.activeOverNotif as |n|}}
        {{#in-element this.documentBody insertBefore=null}}
          <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40" role="presentation" {{on "click" this.closeOverModal}}>
            <div class="bg-white dark:bg-gray-900 rounded-2xl shadow-2xl w-full max-w-sm mx-4" {{on "click" this.stopPropagation}}>
            <div class="px-6 pt-6 pb-5">

              <h3 class="text-base font-bold text-gray-900 dark:text-white mb-4">
                Overend Data Confirmation
              </h3>

              <div class="space-y-2 mb-5">
                <div class="flex justify-between text-sm">
                  <span class="text-gray-500 dark:text-gray-400">Match</span>
                  <span class="font-semibold text-gray-900 dark:text-white">{{n.matchName}}</span>
                </div>
                <div class="flex justify-between text-sm">
                  <span class="text-gray-500 dark:text-gray-400">Over</span>
                  <span class="font-semibold text-gray-900 dark:text-white">{{n.over}}</span>
                </div>
                <div class="flex justify-between text-sm">
                  <span class="text-gray-500 dark:text-gray-400">Status</span>
                  {{#if n.isOverConfirmed}}
                    <span class="px-2 py-0.5 text-[11px] font-semibold rounded-full bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400">Accepted</span>
                  {{else}}
                    <span class="px-2 py-0.5 text-[11px] font-semibold rounded-full bg-yellow-100 dark:bg-yellow-900/30 text-yellow-700 dark:text-yellow-400">Pending</span>
                  {{/if}}
                </div>
              </div>

              <div class="flex justify-end gap-2">
                <button
                  type="button"
                  class="px-4 py-2 text-sm font-semibold text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-xl transition-colors"
                  {{on "click" this.closeOverModal}}
                >
                  Close
                </button>
                <button
                  type="button"
                  class="px-4 py-2 text-sm font-semibold bg-cyan-600 hover:bg-cyan-500 text-white rounded-xl transition-colors disabled:opacity-50"
                  disabled={{this.isSendingUmpireRequest}}
                  {{on "click" this.sendUmpireRequest}}
                >
                  {{if this.isSendingUmpireRequest "Sending..." "Send Request to Umpire"}}
                </button>
              </div>

            </div>
          </div>
        </div>
        {{/in-element}}
      {{/let}}
    {{/if}}

    <div>
      {{! Bell Button }}
      <button
        type="button"
        class="relative p-2 rounded-full text-gray-500 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
        title="Notifications"
        {{on "click" this.toggleDropdown}}
      >
        <svg
          class="w-5 h-5"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
          stroke-width="1.75"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M14.857 17.082a23.848 23.848 0 0 0 5.454-1.31A8.967 8.967 0 0 1 18 9.75V9A6 6 0 0 0 6 9v.75a8.967 8.967 0 0 1-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 0 1-5.714 0m5.714 0a3 3 0 1 1-5.714 0"
          />
        </svg>
        {{#if this.hasUnread}}
          <span
            class="absolute top-1 right-1 w-2 h-2 bg-red-500 rounded-full"
          ></span>
        {{/if}}
      </button>

      {{#if this.isOpen}}
        {{#in-element this.documentBody insertBefore=null}}
          {{! Backdrop }}
          <div
            class="fixed inset-0 z-[199]"
            {{on "click" this.closeDropdown}}
          ></div>

          {{! Dropdown }}
          <div
            class="fixed z-[200] w-80 bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 rounded-2xl shadow-xl overflow-hidden"
            style={{this.dropdownStyle}}
            {{on "click" this.stopPropagation}}
          >

          {{! Header }}
          <div class="px-4 py-3 border-b border-gray-100 dark:border-gray-800">
            <h3
              class="text-sm font-semibold text-gray-900 dark:text-white"
            >Notifications</h3>
          </div>

          {{! Body }}
          <div class="max-h-96 overflow-y-auto">
            {{#if this.isLoading}}
              {{#each (array 1 2 3) as |_|}}
                <div
                  class="flex gap-3 px-4 py-3 border-b border-gray-50 dark:border-gray-800/50 animate-pulse"
                >
                  <div
                    class="w-8 h-8 rounded-full bg-gray-200 dark:bg-gray-700 flex-shrink-0"
                  ></div>
                  <div class="flex-1 space-y-1.5">
                    <div
                      class="h-3 bg-gray-200 dark:bg-gray-700 rounded w-3/4"
                    ></div>
                    <div
                      class="h-3 bg-gray-200 dark:bg-gray-700 rounded w-full"
                    ></div>
                    <div
                      class="h-2.5 bg-gray-100 dark:bg-gray-800 rounded w-1/4"
                    ></div>
                  </div>
                </div>
              {{/each}}

            {{else if this.error}}
              <p
                class="text-center text-sm text-red-500 py-6 px-4"
              >{{this.error}}</p>

            {{else if this.notifications.length}}
              {{#each this.notifications as |notif|}}
                <div
                  class="px-4 py-3 border-b border-gray-50 dark:border-gray-800/50"
                >
                  <div class="flex gap-3">
                    {{! Icon }}
                    <div
                      class="w-8 h-8 rounded-full flex-shrink-0 flex items-center justify-center bg-blue-100 dark:bg-blue-900/30"
                    >
                      <svg
                        class="w-4 h-4 text-blue-600 dark:text-blue-400"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                        stroke-width="1.75"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M14.857 17.082a23.848 23.848 0 0 0 5.454-1.31A8.967 8.967 0 0 1 18 9.75V9A6 6 0 0 0 6 9v.75a8.967 8.967 0 0 1-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 0 1-5.714 0m5.714 0a3 3 0 1 1-5.714 0"
                        />
                      </svg>
                    </div>

                    {{! Content }}
                    <div class="flex-1 min-w-0">
                      <p
                        class="text-xs font-medium text-blue-600 dark:text-blue-400 mb-0.5"
                      >
                        {{notifLabel notif.notificationType}}
                      </p>
                      <p
                        class="text-xs text-gray-700 dark:text-gray-300 leading-snug line-clamp-2"
                      >
                        {{notif.messageText}}
                      </p>
                      <p
                        class="text-[10px] text-gray-400 dark:text-gray-500 mt-1"
                      >
                        {{timeAgo notif.createdAt}}
                      </p>

                      {{! Accept/Decline — scorer request }}
                      {{#if
                        (or
                          (eq
                            notif.notificationType "active_scorer_offer_request"
                          )
                          (eq
                            notif.notificationType
                            "active_scorer_request_request"
                          )
                        )
                      }}
                        <div class="flex gap-2 mt-2">
                          <button
                            type="button"
                            class="px-3 py-1 text-[11px] font-semibold rounded-lg bg-cyan-600 hover:bg-cyan-500 text-white transition-colors disabled:opacity-50"
                            disabled={{this.processingId}}
                            {{on "click" (fn this.respond notif true)}}
                          >
                            Accept
                          </button>
                          <button
                            type="button"
                            class="px-3 py-1 text-[11px] font-semibold rounded-lg bg-slate-200 hover:bg-slate-300 dark:bg-slate-700 dark:hover:bg-slate-600 text-gray-700 dark:text-gray-300 transition-colors disabled:opacity-50"
                            disabled={{this.processingId}}
                            {{on "click" (fn this.respond notif false)}}
                          >
                            Decline
                          </button>
                        </div>

                        {{! Response badge — scorer response }}
                      {{else if
                        (eq
                          notif.notificationType
                          "active_scorer_request_response"
                        )
                      }}
                        {{#if notif.isAccepted}}
                          <span
                            class="inline-block mt-1.5 px-2 py-0.5 text-[10px] font-semibold rounded-full bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400"
                          >Accepted</span>
                        {{else}}
                          <span
                            class="inline-block mt-1.5 px-2 py-0.5 text-[10px] font-semibold rounded-full bg-red-100 dark:bg-red-900/30 text-red-600 dark:text-red-400"
                          >Declined</span>
                        {{/if}}

                        {{! Accept/Decline — game official / streamer request }}
                      {{else if
                        (or
                          (eq notif.notificationType "umpire_request")
                          (eq notif.notificationType "streamer_request")
                        )
                      }}
                        <div class="flex gap-2 mt-2">
                          <button
                            type="button"
                            class="px-3 py-1 text-[11px] font-semibold rounded-lg bg-cyan-600 hover:bg-cyan-500 text-white transition-colors disabled:opacity-50"
                            disabled={{this.processingId}}
                            {{on
                              "click"
                              (fn this.respondToRoleRequest notif true)
                            }}
                          >
                            Accept
                          </button>
                          <button
                            type="button"
                            class="px-3 py-1 text-[11px] font-semibold rounded-lg bg-slate-200 hover:bg-slate-300 dark:bg-slate-700 dark:hover:bg-slate-600 text-gray-700 dark:text-gray-300 transition-colors disabled:opacity-50"
                            disabled={{this.processingId}}
                            {{on
                              "click"
                              (fn this.respondToRoleRequest notif false)
                            }}
                          >
                            Decline
                          </button>
                        </div>

                        {{! Response badge — umpire response }}
                      {{else if (eq notif.notificationType "umpire_response")}}
                        {{#if notif.isRoleAccepted}}
                          <span
                            class="inline-block mt-1.5 px-2 py-0.5 text-[10px] font-semibold rounded-full bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400"
                          >Accepted</span>
                        {{else}}
                          <span
                            class="inline-block mt-1.5 px-2 py-0.5 text-[10px] font-semibold rounded-full bg-red-100 dark:bg-red-900/30 text-red-600 dark:text-red-400"
                          >Declined</span>
                        {{/if}}

                          {{! Accept/Decline — team player add }}
                      {{else if (eq notif.notificationType "team_player_add")}}
                        <div class="flex gap-2 mt-2">
                          <button
                            type="button"
                            class="px-3 py-1 text-[11px] font-semibold rounded-lg bg-cyan-600 hover:bg-cyan-500 text-white transition-colors disabled:opacity-50"
                            disabled={{this.processingId}}
                            {{on
                              "click"
                              (fn this.respondToTeamPlayerAdd notif "accept")
                            }}
                          >
                            Accept
                          </button>
                          <button
                            type="button"
                            class="px-3 py-1 text-[11px] font-semibold rounded-lg bg-slate-200 hover:bg-slate-300 dark:bg-slate-700 dark:hover:bg-slate-600 text-gray-700 dark:text-gray-300 transition-colors disabled:opacity-50"
                            disabled={{this.processingId}}
                            {{on
                              "click"
                              (fn this.respondToTeamPlayerAdd notif "decline")
                            }}
                          >
                            Decline
                          </button>
                        </div>

                        {{! View button — overend data confirmation }}
                      {{else if (eq notif.notificationType "overend_data_confirmation")}}
                        <button
                          type="button"
                          class="mt-2 px-3 py-1 text-[11px] font-semibold rounded-lg bg-cyan-600 hover:bg-cyan-500 text-white transition-colors"
                          {{on "click" (fn this.openOverModal notif)}}
                        >
                          View
                        </button>

                        {{! Info badge — accepted }}
                      {{else if (eq notif.notificationType "accepted")}}
                        <span
                          class="inline-block mt-1.5 px-2 py-0.5 text-[10px] font-semibold rounded-full bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400"
                        >Accepted</span>
                      {{/if}}

                    </div>
                  </div>
                </div>
              {{/each}}

            {{else}}
              <div class="py-10 text-center">
                <p class="text-sm text-gray-400 dark:text-gray-500">No
                  notifications</p>
              </div>
            {{/if}}
          </div>

          </div>
        {{/in-element}}
      {{/if}}
    </div>
  </template>
}

export default NotificationDropdownComponent;
