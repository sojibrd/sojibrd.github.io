import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { service } from '@ember/service';
import lucideIcon from 'spordium/helpers/lucide-icon';

const API_BASE = 'https://spordiumapi.adnanfoundation.com';

// ══════════════════════════════════════════════════════════════════════════════
// PaymentCallback — handles the gateway redirect back to
// /tournament/payment-callback?id=&status=
//
// @arg {string} id     — tournament ID from query param
// @arg {string} status — 'success' | 'failed' | 'cancelled' | 'pending'
// ══════════════════════════════════════════════════════════════════════════════
export default class TournamentPaymentCallback extends Component {
  @service router;
  @service session;
  @service payment;

  @tracked verifying = true;
  @tracked verified  = false;
  @tracked error     = null;

  constructor(owner, args) {
    super(owner, args);
    this.processCallback();
  }

  get status()       { return this.args.status ?? 'failed'; }
  get tournamentId() { return this.args.id ?? null; }
  get isSuccess()    { return this.status === 'success' && this.verified; }
  get isFailed()     { return this.status === 'failed'    || (this.status !== 'cancelled' && !this.verified && !this.verifying); }
  get isCancelled()  { return this.status === 'cancelled'; }

  async processCallback() {
    this.verifying = true;

    if (this.status !== 'success') {
      // No need to call backend for failed/cancelled
      this.verifying = false;
      this.verified  = false;
      return;
    }

    try {
      const res = await this.payment.verifyPaymentCallback({
        tournamentId: this.tournamentId,
        status:       this.status,
      });
      this.verified = res?.verified ?? false;
      if (!this.verified) {
        this.error = 'Payment could not be verified. Please contact support.';
      }
    } catch (err) {
      this.error   = err?.message ?? 'Verification failed. Please contact support.';
      this.verified = false;
    } finally {
      this.verifying = false;
    }
  }

  @action
  goToTournament() {
    if (this.tournamentId) {
      this.router.transitionTo('tournament.tournament-details', {
        queryParams: { id: this.tournamentId, tab: 'overview' },
      });
    } else {
      this.router.transitionTo('tournament.published');
    }
  }

  @action
  goToList() {
    this.router.transitionTo('tournament.index');
  }

  @action
  retryPayment() {
    this.router.transitionTo('tournament.team-purchase-plan', {
      queryParams: { tournament_id: this.tournamentId },
    });
  }

  <template>
    <div class="min-h-screen bg-gray-50 dark:bg-gray-950 flex items-center justify-center p-4">
      <div class="w-full max-w-md">

        {{! Verifying state }}
        {{#if this.verifying}}
          <div class="bg-white dark:bg-gray-900 rounded-3xl border border-gray-200 dark:border-gray-700
                      p-10 text-center shadow-lg">
            <div class="w-16 h-16 mx-auto mb-5 rounded-full bg-blue-50 dark:bg-blue-900/30
                        flex items-center justify-center">
              <div class="w-8 h-8 border-3 border-blue-600 border-t-transparent rounded-full animate-spin"></div>
            </div>
            <h2 class="text-lg font-extrabold text-gray-900 dark:text-white">Verifying Payment</h2>
            <p class="text-sm text-gray-500 dark:text-gray-400 mt-1">Please wait while we confirm your payment…</p>
          </div>

        {{! Success state }}
        {{else if this.isSuccess}}
          <div class="bg-white dark:bg-gray-900 rounded-3xl border border-gray-200 dark:border-gray-700
                      p-10 text-center shadow-lg">
            <div class="w-20 h-20 mx-auto mb-5 rounded-full bg-green-100 dark:bg-green-900/30
                        flex items-center justify-center">
              {{lucideIcon "check-circle" class="w-10 h-10 text-green-600 dark:text-green-400"}}
            </div>
            <h2 class="text-xl font-extrabold text-gray-900 dark:text-white">Payment Successful!</h2>
            <p class="text-sm text-gray-500 dark:text-gray-400 mt-2">
              Your tournament has been published successfully.
            </p>

            <div class="mt-6 flex flex-col gap-3">
              <button
                type="button"
                {{on "click" this.goToTournament}}
                class="w-full py-3 text-sm font-bold rounded-2xl bg-blue-600 text-white
                       hover:bg-blue-700 transition-colors"
              >
                View Tournament
              </button>
              <button
                type="button"
                {{on "click" this.goToList}}
                class="w-full py-3 text-sm font-medium rounded-2xl border border-gray-200
                       dark:border-gray-600 text-gray-600 dark:text-gray-300 hover:bg-gray-50
                       dark:hover:bg-gray-800 transition-colors"
              >
                Browse All Tournaments
              </button>
            </div>
          </div>

        {{! Cancelled state }}
        {{else if this.isCancelled}}
          <div class="bg-white dark:bg-gray-900 rounded-3xl border border-gray-200 dark:border-gray-700
                      p-10 text-center shadow-lg">
            <div class="w-20 h-20 mx-auto mb-5 rounded-full bg-yellow-100 dark:bg-yellow-900/30
                        flex items-center justify-center">
              {{lucideIcon "x-circle" class="w-10 h-10 text-yellow-600 dark:text-yellow-400"}}
            </div>
            <h2 class="text-xl font-extrabold text-gray-900 dark:text-white">Payment Cancelled</h2>
            <p class="text-sm text-gray-500 dark:text-gray-400 mt-2">
              You cancelled the payment. Your tournament has been saved as a draft.
            </p>

            <div class="mt-6 flex flex-col gap-3">
              <button
                type="button"
                {{on "click" this.retryPayment}}
                class="w-full py-3 text-sm font-bold rounded-2xl bg-blue-600 text-white
                       hover:bg-blue-700 transition-colors"
              >
                Try Again
              </button>
              <button
                type="button"
                {{on "click" this.goToList}}
                class="w-full py-3 text-sm font-medium rounded-2xl border border-gray-200
                       dark:border-gray-600 text-gray-600 dark:text-gray-300 hover:bg-gray-50
                       dark:hover:bg-gray-800 transition-colors"
              >
                Go to Drafts
              </button>
            </div>
          </div>

        {{! Failed state }}
        {{else}}
          <div class="bg-white dark:bg-gray-900 rounded-3xl border border-gray-200 dark:border-gray-700
                      p-10 text-center shadow-lg">
            <div class="w-20 h-20 mx-auto mb-5 rounded-full bg-red-100 dark:bg-red-900/30
                        flex items-center justify-center">
              {{lucideIcon "alert-circle" class="w-10 h-10 text-red-600 dark:text-red-400"}}
            </div>
            <h2 class="text-xl font-extrabold text-gray-900 dark:text-white">Payment Failed</h2>
            <p class="text-sm text-gray-500 dark:text-gray-400 mt-2">
              {{if this.error this.error "Something went wrong with your payment. Please try again."}}
            </p>

            <div class="mt-6 flex flex-col gap-3">
              <button
                type="button"
                {{on "click" this.retryPayment}}
                class="w-full py-3 text-sm font-bold rounded-2xl bg-blue-600 text-white
                       hover:bg-blue-700 transition-colors"
              >
                Try Again
              </button>
              <button
                type="button"
                {{on "click" this.goToList}}
                class="w-full py-3 text-sm font-medium rounded-2xl border border-gray-200
                       dark:border-gray-600 text-gray-600 dark:text-gray-300 hover:bg-gray-50
                       dark:hover:bg-gray-800 transition-colors"
              >
                Back to Tournaments
              </button>
            </div>
          </div>
        {{/if}}

      </div>
    </div>
  </template>
}
