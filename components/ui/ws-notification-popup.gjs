import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { service } from '@ember/service';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { modifier } from 'ember-modifier';
import { eq } from 'ember-truth-helpers';
import { markNotificationActioned } from 'spordium/utils/notification-action';

// Role-based requests → Accept/Decline via /role/accept-role/
const ROLE_REQUEST_TYPES = new Set([
  'umpire_request',
  'streamer_request',
  'scorer_request', // possible scorer variant
  'cricketscorer_request', // possible scorer variant
  'team_player_add', // team invite
]);

// Scorer offer requests → Accept/Decline via /live_scoring/active-scorrer-accept/
const SCORER_OFFER_TYPES = new Set([
  'active_scorer_offer_request',
  'active_scorer_request_request',
]);

const REQUEST_TYPES = new Set([...ROLE_REQUEST_TYPES, ...SCORER_OFFER_TYPES]);

// Info-only (auto-dismiss)
const INFO_TYPES = new Set([
  'umpire_response',
  'scorer_response',
  'streamer_response',
  'active_scorer_request_response',
  'accepted',
  'club_manager_response',
  'team_player_remove',
]);

const LABELS = {
  umpire_request: 'Umpire Invitation',
  streamer_request: 'Streamer Invitation',
  scorer_request: 'Scorer Invitation',
  cricketscorer_request: 'Scorer Invitation',
  active_scorer_offer_request: 'Scorer Invitation',
  active_scorer_request_request: 'Scorer Request',
  umpire_response: 'Umpire Response',
  scorer_response: 'Scorer Response',
  streamer_response: 'Streamer Response',
  active_scorer_request_response: 'Scorer Response',
  accepted: 'Accepted',
  club_manager_response: 'Club Update',
  team_player_add: 'Team Invitation',
  team_player_remove: 'Team Update',
};

// Real WS envelope:
// { status, receiver, payload: { notification_id, notification_type, message: {...}, created_at } }
function unwrap(raw) {
  if (raw?.payload && typeof raw.payload === 'object') return raw.payload;
  if (raw?.data && typeof raw.data === 'object') return raw.data;
  return raw;
}

function resolveType(raw) {
  const d = unwrap(raw);
  return d.notification_type || d.type || null;
}

function normalise(raw) {
  const d = unwrap(raw);
  const type = resolveType(raw);

  const msgObj =
    typeof d.message === 'object' && d.message !== null ? d.message : {};
  const msgText =
    typeof d.message === 'string' ? d.message : msgObj.message || '';

  // declined_id present → declined, accepted_id present → accepted
  let isAccepted = d.accept ?? msgObj.accept ?? null;
  if (isAccepted === null) {
    if (msgObj.declined_id) isAccepted = false;
    else if (msgObj.accepted_id) isAccepted = true;
  }

  return {
    id: d.notification_id || d.id || String(Date.now()),
    type,
    label: LABELS[type] || type,
    message: msgText,
    createdAt: d.created_at || null,
    matchId: d.match_id || msgObj.match_id || null,
    gameId: d.game_id || msgObj.game_id || null,
    owner: d.owner || msgObj.owner || null,
    teamId: d.team_id || msgObj.team_id || null,
    isAccepted,
  };
}

const onInsert = modifier((_, [cb]) => {
  cb();
});

export default class WsNotificationPopupComponent extends Component {
  @service websocket;
  @service api;
  @service session;
  @service toast;

  @tracked queue = []; // list of normalised notification objects
  @tracked processingId = null;
  _dismissTimer = null;
  _unsubscribe = null;

  get current() {
    return this.queue[0] ?? null;
  }

  get isRequest() {
    return this.current ? REQUEST_TYPES.has(this.current.type) : false;
  }

  // true → use /role/accept-role/   false → use /live_scoring/active-scorrer-accept/
  get isRoleRequest() {
    return this.current ? ROLE_REQUEST_TYPES.has(this.current.type) : false;
  }

  get isInfo() {
    return this.current ? INFO_TYPES.has(this.current.type) : false;
  }

  get pendingCount() {
    return this.queue.length;
  }

  get hasMore() {
    return this.queue.length > 1;
  }

  get userId() {
    return this.session.currentUser?.user_id;
  }

  // ── Lifecycle ──────────────────────────────────────────

  @action
  setup() {
    this._unsubscribe = this.websocket.on('*', this._onMessage);
  }

  willDestroy() {
    super.willDestroy();
    this._unsubscribe?.();
    clearTimeout(this._dismissTimer);
  }

  // ── WebSocket handler ──────────────────────────────────

  _onMessage = (data) => {
    const type = resolveType(data);
    if (!type || (!REQUEST_TYPES.has(type) && !INFO_TYPES.has(type))) return;

    const notif = normalise(data);

    // Avoid duplicates by id
    if (this.queue.some((n) => n.id === notif.id)) return;

    // Request types go to the front so latest invitation shows immediately.
    // Info/response types go to the back (lower priority).
    if (REQUEST_TYPES.has(notif.type)) {
      this.queue = [notif, ...this.queue];
    } else {
      this.queue = [...this.queue, notif];
    }

    // If this is the first item and it's info-only, start auto-dismiss
    if (this.queue.length === 1 && INFO_TYPES.has(notif.type)) {
      this._startAutoDismiss();
    }
  };

  // ── Dismiss helpers ────────────────────────────────────

  _shift() {
    clearTimeout(this._dismissTimer);
    this._dismissTimer = null;
    this.queue = this.queue.slice(1);

    // Auto-dismiss the next item if it's info-only
    if (this.current && INFO_TYPES.has(this.current.type)) {
      this._startAutoDismiss();
    }
  }

  _startAutoDismiss() {
    clearTimeout(this._dismissTimer);
    this._dismissTimer = setTimeout(() => this._shift(), 5000);
  }

  @action
  dismiss() {
    this._shift();
  }

  @action
  stopPropagation(e) {
    e.stopPropagation();
  }

  // ── Action handlers ────────────────────────────────────

  @action
  async respondToRoleRequest(accept) {
    const notif = this.current;
    if (!notif || this.processingId) return;
    this.processingId = notif.id;
    try {
      // Field name depends on which role is being accepted
      const ACCEPT_ID_KEY = {
        umpire_request: 'umpire_id',
        streamer_request: 'streamer_id',
        scorer_request: 'scorer_id',
        team_player_add: 'player_id',
      };
      const idKey = ACCEPT_ID_KEY[notif.type] ?? 'umpire_id';
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
      this._shift();
    } catch (e) {
      this.toast.error(e?.payload?.message || 'Something went wrong.');
    } finally {
      this.processingId = null;
    }
  }

  @action
  async respondToScorerRequest(accept) {
    const notif = this.current;
    if (!notif || this.processingId) return;
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
      this._shift();
    } catch (e) {
      this.toast.error(e?.payload?.message || 'Something went wrong.');
    } finally {
      this.processingId = null;
    }
  }

  @action
  async respondToTeamRequest(accept) {
    const notif = this.current;

    if (!notif || this.processingId) return;
    this.processingId = notif.id;
    try {
      await this.api.post('/team/update_Player_in_team_accept_decline/', {
        team_id: notif.teamId,
        action: accept ? 'accept' : 'decline',
      });
      this.toast.success(
        accept ? 'Team invitation accepted.' : 'Team invitation declined.',
      );
      markNotificationActioned(this.api, notif.id);
      this._shift();
    } catch (e) {
      this.toast.error(e?.payload?.message || 'Something went wrong.');
    } finally {
      this.processingId = null;
    }
  }

  <template>
    {{! Mount hook — registers WS listener once }}
    <div {{onInsert this.setup}} class="hidden"></div>

    {{#if this.current}}
      {{#let this.current as |notif|}}

        {{! Backdrop }}
        <div
          class="fixed inset-0 z-50 flex items-center justify-center px-4 bg-black/40"
          role="presentation"
          {{on "click" this.dismiss}}
        >

          {{! Modal — matches screenshot style }}
          <div
            class="bg-white dark:bg-gray-900 rounded-2xl shadow-2xl w-full max-w-sm animate-slide-up"
            {{on "click" this.stopPropagation}}
          >
            <div class="px-6 pt-6 pb-5">

              {{! Title }}
              <h3 class="text-lg font-bold text-gray-900 dark:text-white mb-4">
                {{notif.label}}
              </h3>

              {{! Message }}
              <p
                class="text-sm text-gray-700 dark:text-gray-300 leading-relaxed mb-1"
              >
                {{notif.message}}
              </p>

              {{! Timestamp }}
              {{#if notif.createdAt}}
                <p
                  class="text-xs text-gray-400 dark:text-gray-500 mt-1 mb-4"
                >{{notif.createdAt}}</p>
              {{else}}
                <div class="mb-4"></div>
              {{/if}}

              {{! Pending indicator }}
              {{#if this.hasMore}}
                <p class="text-xs text-gray-400 mb-3">+{{this.pendingCount}}
                  more waiting</p>
              {{/if}}

              {{! Info badge }}
              {{#if this.isInfo}}
                {{#if notif.isAccepted}}
                  <span
                    class="inline-flex px-3 py-1 text-xs font-semibold rounded-full bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400 mb-4"
                  >Accepted</span>
                {{else if (eq notif.isAccepted false)}}
                  <span
                    class="inline-flex px-3 py-1 text-xs font-semibold rounded-full bg-red-100 dark:bg-red-900/30 text-red-600 dark:text-red-400 mb-4"
                  >Declined</span>
                {{/if}}
              {{/if}}

              {{! Buttons }}
              <div class="flex justify-end gap-2">
                {{#if this.isRequest}}

                  {{! 1. team invitation }}
                  {{#if (eq notif.type "team_player_add")}}
                    <button
                      type="button"
                      class="px-5 py-2 text-sm font-semibold text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-xl transition-colors disabled:opacity-40"
                      disabled={{this.processingId}}
                      {{on "click" (fn this.respondToTeamRequest false)}}
                    >Decline</button>
                    <button
                      type="button"
                      class="px-5 py-2 text-sm font-semibold bg-cyan-600 hover:bg-cyan-500 text-white rounded-xl transition-colors disabled:opacity-40 min-w-[72px]"
                      disabled={{this.processingId}}
                      {{on "click" (fn this.respondToTeamRequest true)}}
                    >{{if this.processingId "..." "Accept"}}</button>

                    {{! 2. old role request handler (umpire/streaming) }}
                  {{else if this.isRoleRequest}}
                    <button
                      type="button"
                      class="px-5 py-2 text-sm font-semibold text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-xl transition-colors disabled:opacity-40"
                      disabled={{this.processingId}}
                      {{on "click" (fn this.respondToRoleRequest false)}}
                    >Decline</button>
                    <button
                      type="button"
                      class="px-5 py-2 text-sm font-semibold bg-cyan-600 hover:bg-cyan-500 text-white rounded-xl transition-colors disabled:opacity-40 min-w-[72px]"
                      disabled={{this.processingId}}
                      {{on "click" (fn this.respondToRoleRequest true)}}
                    >{{if this.processingId "..." "Accept"}}</button>

                    {{! 3. scorer offer requests }}
                  {{else}}
                    <button
                      type="button"
                      class="px-5 py-2 text-sm font-semibold text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-xl transition-colors disabled:opacity-40"
                      disabled={{this.processingId}}
                      {{on "click" (fn this.respondToScorerRequest false)}}
                    >Decline</button>
                    <button
                      type="button"
                      class="px-5 py-2 text-sm font-semibold bg-cyan-600 hover:bg-cyan-500 text-white rounded-xl transition-colors disabled:opacity-40 min-w-[72px]"
                      disabled={{this.processingId}}
                      {{on "click" (fn this.respondToScorerRequest true)}}
                    >{{if this.processingId "..." "Accept"}}</button>
                  {{/if}}

                {{else}}
                  <button
                    type="button"
                    class="px-5 py-2 text-sm font-semibold text-cyan-600 dark:text-cyan-400 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-xl transition-colors"
                    {{on "click" this.dismiss}}
                  >OK</button>
                {{/if}}
              </div>

            </div>
          </div>
        </div>

      {{/let}}
    {{/if}}
  </template>
}
