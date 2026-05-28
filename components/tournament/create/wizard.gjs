import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { eq, gt, lt } from 'ember-truth-helpers';
import { service } from '@ember/service';
import Step1 from './step-1-info/index';
import Step2 from './step-2-format/index';
import Step3 from './step-3-team';
import Step4 from './step-4-organizer';
import Step5 from './step-5-other';
import lucideIcon from 'spordium/helpers/lucide-icon';

const API_BASE = 'https://spordiumapi.adnanfoundation.com';
const TOTAL_STEPS = 5;
const S3_BASE = 'https://ag-khela.s3.ap-south-1.amazonaws.com';

const STEP_META = [
  { label: 'Info', icon: 'file-text' },
  { label: 'Format', icon: 'layout-list' },
  { label: 'Teams', icon: 'users' },
  { label: 'Organizer', icon: 'building-2' },
  { label: 'Publish', icon: 'send' },
];

function add(a, b) {
  return a + b;
}

function validateStep(step, data) {
  if (step === 1) {
    if (!data.tournament_name?.trim()) return 'Tournament name is required.';
    if (!data.tournament_sport) return 'Please select a sport.';
  }
  return null;
}

const DEFAULT_DATA = {
  tournament_id: null,
  tournament_name: '',
  tournament_sport: '',
  tornament_season: '',
  tournament_type: '',
  tournament_start_date: '',
  tournament_match_days: [],
  tournament_match_number_per_day: 0,
  tournament_match_time_slots: [],
  tournament_prize: [],
  tournament_team_registration_type: 'publicRegistration',
  tournament_team_registration_fee: 0,
  tournament_team_registration_end_date: '',
  tournament_team_registration_fee_currency: null,
  payment_receiving_details: [],
  payment_receiving_medium_type: [],
  tournament_logo: null,
  tournament_location: null,
  tournament_latitude: null,
  tournament_longtitude: null,
  _coverPhotoPreview: null,
  delete_prizes: [],
  tournament_paid_number_of_teams: 0, //
};

export default class TournamentWizard extends Component {
  @service session;
  @service router;
  @service upload;

  @tracked currentStep = 1;
  @tracked stepError = null;
  @tracked submitError = null;
  @tracked isSubmitting = false;
  @tracked paidTeams = 0;
  @tracked data = { ...DEFAULT_DATA };

  #step1Snapshot = null;
  #step2Snapshot = null;

  tournamentId = this.args.tournamentId ?? null;

  constructor(owner, args) {
    super(owner, args);
    if (this.tournamentId) {
      this.loadStep1(this.tournamentId);
    }
  }

  async loadStep1(id) {
    try {
      const res = await fetch(`${API_BASE}/tournament_v2/create-tournament-1/?tournament_id=${id}`);
      if (!res.ok) return;
      const json = await res.json();
      const t = json.data ?? json;
      this.paidTeams = t.tournament_paid_number_of_teams ?? 0;
      const toDate = (iso) => iso?.substring(0, 10) ?? '';

      this.data = {
        ...DEFAULT_DATA,
        tournament_id: t.tournament_id ?? id,
        tournament_name: t.tournament_name ?? '',
        tournament_sport: t.tournament_sport ?? '',
        tornament_season: t.tornament_season ?? '',
        tournament_type: t.tournament_type ?? '',
        tournament_start_date: toDate(t.tournament_start_date),
        tournament_match_days: t.tournament_match_days ?? [],
        tournament_match_number_per_day: t.tournament_match_number_per_day ?? 0,
        tournament_match_time_slots: t.tournament_match_time_slots ?? [],
        tournament_prize: t.tournament_prize ?? [],
        tournament_team_registration_type: t.tournament_team_registration_type ?? 'publicRegistration',
        tournament_team_registration_fee: t.tournament_team_registration_fee ?? 0,
        tournament_team_registration_end_date: toDate(t.tournament_team_registration_end_date),
        tournament_team_registration_fee_currency: t.tournament_team_registration_fee_currency ?? null,
        payment_receiving_details: t.payment_receiving_details ?? [],
        payment_receiving_medium_type: t.payment_receiving_medium_type ?? [],
        tournament_logo: t.tournament_logo ?? null,
        tournament_location: t.tournament_location ?? null,
        tournament_latitude: t.tournament_latitude ?? null,
        tournament_longtitude: t.tournament_longtitude ?? null,
        _coverPhotoPreview: t.tournament_logo ? `${S3_BASE}/${t.tournament_logo}` : null,
        delete_prizes: t.delete_prizes ?? [],
      };

      this.#step1Snapshot = this.#getStep1Snapshot();
    } catch (error) {
      console.error('Error loading existing tournament:', error);
    }
  }

  // ── Step 2 data load ──────────────────────────────────────────────────────
  async loadStep2() {
    if (!this.data.tournament_id) return;
    try {
      const res = await fetch(`${API_BASE}/tournament_v2/create-tournament-2/?tournament_id=${this.data.tournament_id}`);
      if (!res.ok) return;
      const json = await res.json();
      const t = json.data ?? json;

      this.data = {
        ...this.data,
        tournament_match_format: t.tournament_match_format ?? '',
        tournament_format: t.tournament_format ?? '',
        overs_per_match: t.overs_per_match ?? 0,
        ball_type: t.ball_type ?? '',
        pitch_type: t.pitch_type ?? '',
        tournament_number_of_groups: t.tournament_number_of_groups ?? 0,
        tournament_groups: t.tournament_groups ?? [],
        number_of_teams_per_groups: t.number_of_teams_per_groups ?? 0,
        number_of_players_playing: t.number_of_players_playing ?? 0,
        maximum_sqad_size_per_team: t.maximum_sqad_size_per_team ?? 0,
        player_age_limit: t.player_age_limit ?? { min: null, max: null },
        win_points: t.win_points ?? null,
        tie_points: t.tie_points ?? null,
        loss_points: t.loss_points ?? null,
        tie_breaker_rules: t.tie_breaker_rules ?? [],
        delete_groups: [],
      };

      // snapshot নাও যাতে unchanged data unnecessary save না হয়
      this.#step2Snapshot = this.#getStep2Snapshot();
    } catch (error) {
      console.error('Error loading step 2:', error);
    }
  }

  // ── Step 1 snapshot ───────────────────────────────────────────────────────
  #getStep1Snapshot() {
    const d = this.data;
    return JSON.stringify({
      tournament_id: d.tournament_id,
      tournament_name: d.tournament_name,
      tournament_sport: d.tournament_sport,
      tornament_season: d.tornament_season,
      tournament_type: d.tournament_type,
      tournament_start_date: d.tournament_start_date,
      tournament_match_days: d.tournament_match_days,
      tournament_match_number_per_day: d.tournament_match_number_per_day,
      tournament_match_time_slots: d.tournament_match_time_slots,
      tournament_prize: d.tournament_prize,
      tournament_team_registration_type: d.tournament_team_registration_type,
      tournament_team_registration_fee: d.tournament_team_registration_fee,
      tournament_team_registration_end_date: d.tournament_team_registration_end_date,
      payment_receiving_details: d.payment_receiving_details,
      upload_tournament_logo: d.upload_tournament_logo,
      tournament_location: d.tournament_location,
      tournament_latitude: d.tournament_latitude,
      tournament_longtitude: d.tournament_longtitude,
      delete_prizes: d.delete_prizes,
    });
  }

  get step1HasChanges() {
    if (!this.#step1Snapshot) return true;
    return this.#getStep1Snapshot() !== this.#step1Snapshot;
  }

  #getStep1ChangedPayload() {
    const initial = JSON.parse(this.#step1Snapshot ?? '{}');
    const current = JSON.parse(this.#getStep1Snapshot());
    const changed = {};

    for (const key of Object.keys(current)) {
      if (JSON.stringify(current[key]) !== JSON.stringify(initial[key])) {
        changed[key] = current[key];
      }
    }

    return {
      tournament_id: this.data.tournament_id,
      ...changed,
    };
  }

  #getStep2ChangedPayload() {
    const initial = JSON.parse(this.#step2Snapshot ?? '{}');
    const current = JSON.parse(this.#getStep2Snapshot());
    const changed = {};

    for (const key of Object.keys(current)) {
      if (JSON.stringify(current[key]) !== JSON.stringify(initial[key])) {
        changed[key] = current[key];
      }
    }

    return {
      tournament_id: this.data.tournament_id,
      ...changed,
    };
  }

  // ── Step 2 snapshot ───────────────────────────────────────────────────────
  #getStep2Snapshot() {
    const d = this.data;
    return JSON.stringify({
      tournament_match_format: d.tournament_match_format,
      tournament_format: d.tournament_format,
      overs_per_match: d.overs_per_match,
      ball_type: d.ball_type,
      pitch_type: d.pitch_type,
      tournament_number_of_groups: d.tournament_number_of_groups,
      tournament_groups: d.tournament_groups,
      number_of_teams_per_groups: d.number_of_teams_per_groups,
      number_of_players_playing: d.number_of_players_playing,
      maximum_sqad_size_per_team: d.maximum_sqad_size_per_team,
      player_age_limit: d.player_age_limit,
      win_points: d.win_points,
      tie_points: d.tie_points,
      loss_points: d.loss_points,
      tie_breaker_rules: d.tie_breaker_rules,
      delete_groups: d.delete_groups,
    });
  }

  get step2HasChanges() {
    if (!this.#step2Snapshot) return true;
    return this.#getStep2Snapshot() !== this.#step2Snapshot;
  }

  async saveStep2IfChanged() {
    if (!this.step2HasChanges) return;
    try {
      const payload = this.#getStep2ChangedPayload();

      console.log('payload', payload);

      const res = await fetch(`${API_BASE}/tournament_v2/create-tournament-2/`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${this.session.token}`,
        },
        body: JSON.stringify(payload),
      });

      if (!res.ok) return;

      this.data = { ...this.data, delete_groups: [] };
      this.#step2Snapshot = this.#getStep2Snapshot();
    } catch (error) {
      console.error('Error saving step 2:', error);
    }
  }

  // ── Derived ───────────────────────────────────────────────────────────────
  get steps() {
    return STEP_META;
  }
  get totalSteps() {
    return TOTAL_STEPS;
  }
  get progressPct() {
    return ((this.currentStep - 1) / (TOTAL_STEPS - 1)) * 100;
  }
  get isFirstStep() {
    return this.currentStep === 1;
  }
  get isLastStep() {
    return this.currentStep === TOTAL_STEPS;
  }

  // ── Data update ───────────────────────────────────────────────────────────
  @action
  onUpdate(key, value) {
    if (key === 'tournament_start_date' || key === 'tournament_team_registration_end_date') {
      value = value ? new Date(value).toISOString() : '';
    }
    if (key === 'overs_per_match') value = Number(value);
    this.data = { ...this.data, [key]: value };
  }

  // ── Cover photo upload ────────────────────────────────────────────────────
  @action
  async onCoverPhotoUpload(base64) {
    this.data = {
      ...this.data,
      tournament_logo: base64,
      _coverPhotoPreview: base64,
    };
  }

  // ── Navigation ────────────────────────────────────────────────────────────
  @action
  async goNext() {
    const err = validateStep(this.currentStep, this.data);
    if (err) {
      this.stepError = err;
      return;
    }
    this.stepError = null;

    if (this.currentStep === 1) {
      await this.saveStep1IfChanged();
      await this.loadStep2(); // ← Step 1 save হওয়ার পরেই tournament_id নিশ্চিত, তাই এখানে
    }

    if (this.currentStep === 2) {
      await this.saveStep2IfChanged();
    }

    this.currentStep = Math.min(this.currentStep + 1, TOTAL_STEPS);
  }

  @action
  goPrev() {
    this.stepError = null;
    this.currentStep = Math.max(this.currentStep - 1, 1);
  }

  @action
  goToStep(n) {
    if (n >= this.currentStep) return;
    this.stepError = null;
    this.currentStep = n;
  }

  // ── Step 1 save ───────────────────────────────────────────────────────────
  async saveStep1IfChanged() {
    if (!this.step1HasChanges) return;
    try {
      const payload = this.#getStep1ChangedPayload();
      const res = await fetch(`${API_BASE}/tournament_v2/create-tournament-1/`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${this.session.token}`,
        },
        body: JSON.stringify(payload),
      });
      if (!res.ok) return;

      const json = await res.json();

      if (!this.data.tournament_id) {
        const newId = json.data?.tournament_id ?? json.tournament_id ?? null;
        if (newId) {
          this.data = { ...this.data, tournament_id: newId };
          this.tournamentId = newId;
          this.router.replaceWith('tournament.create', newId);
        }
      }

      this.#step1Snapshot = this.#getStep1Snapshot();
    } catch (error) {
      console.error('Error saving step 1:', error);
    }
  }

  // ── Publish / Save draft ──────────────────────────────────────────────────
  @action
  async onSaveDraft() {
    /* step 5 */
  }

  @action
  async onPublish() {
    /* step 5 */
  }

  <template>
    <div class="min-h-screen bg-gray-50 dark:bg-gray-950">

      {{! Top header }}
      <div class="bg-white dark:bg-gray-900 border-b border-gray-200 dark:border-gray-700">
        <div class="max-w-3xl mx-auto px-4 sm:px-6 py-4 flex items-center gap-4">
          <button type="button" {{on "click" this.goPrev}} class="p-2 rounded-xl hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors disabled:opacity-30 disabled:cursor-not-allowed" disabled={{this.isFirstStep}}>
            {{lucideIcon "arrow-left" class="w-4 h-4 text-gray-500"}}
          </button>
          <div class="flex-1">
            <h1 class="text-sm font-bold text-gray-900 dark:text-white">
              {{if this.tournamentId "Edit Tournament" "Create Tournament"}}
            </h1>
            <p class="text-xs text-gray-500 dark:text-gray-400">
              Step
              {{this.currentStep}}
              of
              {{this.totalSteps}}
            </p>
          </div>
          <span class="text-xs font-semibold text-blue-600 dark:text-blue-400">
            {{this.currentStep}}/{{this.totalSteps}}
          </span>
        </div>
        <div class="h-1 bg-gray-100 dark:bg-gray-800">
          <div class="h-full bg-blue-600 transition-all duration-500 ease-out rounded-r-full" style="width: {{this.progressPct}}%"></div>
        </div>
      </div>

      {{! Step indicator }}
      <div class="max-w-3xl mx-auto px-4 sm:px-6 py-4">
        <div class="flex items-center justify-between">
          {{#each this.steps as |step i|}}
            <button type="button" {{on "click" (fn this.goToStep (add i 1))}} class="flex flex-col items-center gap-1 group {{if (gt (add i 1) this.currentStep) 'cursor-default' 'cursor-pointer'}}">
              <div
                class="w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold transition-all duration-200
                  {{if
                    (eq (add i 1) this.currentStep)
                    'bg-blue-600 text-white shadow-lg shadow-blue-500/30 scale-110'
                    (if (gt (add i 1) this.currentStep) 'bg-gray-100 dark:bg-gray-800 text-gray-400' 'bg-green-100 dark:bg-green-900/40 text-green-600 dark:text-green-400')
                  }}"
              >
                {{#if (gt (add i 1) this.currentStep)}}
                  {{add i 1}}
                {{else if (eq (add i 1) this.currentStep)}}
                  {{add i 1}}
                {{else}}
                  {{lucideIcon "check" class="w-3.5 h-3.5"}}
                {{/if}}
              </div>
              <span class="text-[10px] font-medium hidden sm:block {{if (eq (add i 1) this.currentStep) 'text-blue-600 dark:text-blue-400' 'text-gray-400'}}">
                {{step.label}}
              </span>
            </button>

            {{#if (lt (add i 1) this.totalSteps)}}
              <div class="flex-1 h-px mx-1 {{if (gt (add i 1) this.currentStep) 'bg-gray-200 dark:bg-gray-700' 'bg-blue-400 dark:bg-blue-600'}}">
              </div>
            {{/if}}
          {{/each}}
        </div>
      </div>

      {{! Step content }}
      <div class="max-w-3xl mx-auto px-4 sm:px-6 pb-12">
        <div class="bg-white dark:bg-gray-900 rounded-2xl border border-gray-200 dark:border-gray-700 p-6 sm:p-8">

          {{#if (eq this.currentStep 1)}}
            <Step1 @data={{this.data}} @onUpdate={{this.onUpdate}} @onPhotoUpload={{this.onCoverPhotoUpload}} />
          {{else if (eq this.currentStep 2)}}
            <Step2 @data={{this.data}} @onUpdate={{this.onUpdate}} @paidTeams={{this.paidTeams}} />
          {{else if (eq this.currentStep 3)}}
            {{!-- <Step3 @data={{this.data}} @onUpdate={{this.onUpdate}} /> --}}
          {{else if (eq this.currentStep 4)}}
            {{!-- <Step4 @data={{this.data}} @onUpdate={{this.onUpdate}} /> --}}
          {{else if (eq this.currentStep 5)}}
            {{!-- <Step5 @data={{this.data}} @onUpdate={{this.onUpdate}} @isSubmitting={{this.isSubmitting}} @submitError={{this.submitError}} @onSaveDraft={{this.onSaveDraft}} @onPublish={{this.onPublish}} /> --}}
          {{/if}}

          {{#if this.stepError}}
            <div class="mt-4 p-3 rounded-xl bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-700">
              <p class="text-sm text-red-600 dark:text-red-400 flex items-center gap-2">
                {{lucideIcon "alert-circle" class="w-4 h-4 shrink-0"}}
                {{this.stepError}}
              </p>
            </div>
          {{/if}}

          {{#if (lt this.currentStep 5)}}
            <div class="mt-6 flex justify-end">
              <button type="button" {{on "click" this.goNext}} class="flex items-center gap-2 px-6 py-2.5 text-sm font-semibold rounded-xl bg-blue-600 text-white hover:bg-blue-700 transition-colors">
                Next
                {{lucideIcon "arrow-right" class="w-4 h-4"}}
              </button>
            </div>
          {{/if}}

        </div>
      </div>

    </div>
  </template>
}
