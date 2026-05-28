import Component from '@glimmer/component';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { action } from '@ember/object';
import lucideIcon from 'spordium/helpers/lucide-icon';

const WEEKDAYS = [
  { key: 'sunday', label: 'Sun' },
  { key: 'monday', label: 'Mon' },
  { key: 'tuesday', label: 'Tue' },
  { key: 'wednesday', label: 'Wed' },
  { key: 'thursday', label: 'Thu' },
  { key: 'friday', label: 'Fri' },
  { key: 'saturday', label: 'Sat' },
];

// @arg {Array}    weekdays        — ["saturday", "sunday", ...]
// @arg {Number}   matchesPerDay
// @arg {Array}    matchTimeSlots  — [{ id, start_time, game_count }]
// @arg {Function} onUpdate        — (key, value) => void  (API keys)
export default class ScheduleSection extends Component {
  get weekdays() {
    return WEEKDAYS;
  }

  get selectedWeekdays() {
    return this.args.weekdays ?? [];
  }

  get matchTimeSlots() {
    return this.args.matchTimeSlots ?? [];
  }

  get matchesPerDay() {
    return this.args.matchesPerDay ?? 0;
  }

  get totalSlotsGameCount() {
    return this.matchTimeSlots.reduce((sum, s) => sum + (s.game_count ?? 0), 0);
  }

  get canAddSlot() {
    return this.matchesPerDay > 0 && this.totalSlotsGameCount < this.matchesPerDay;
  }

  isWeekdaySelected = (dayKey) => this.selectedWeekdays.includes(dayKey);

  getSlotStartTime = (slot) => (slot.start_time ? slot.start_time.substring(11, 16) : '');
  getSlotGameCount = (slot) => slot.game_count ?? 1;

  @action toggleWeekday(dayKey) {
    const current = [...this.selectedWeekdays];
    const idx = current.indexOf(dayKey);
    if (idx === -1) current.push(dayKey);
    else current.splice(idx, 1);
    this.args.onUpdate('tournament_match_days', current);
  }

  @action onMatchesPerDayInput(e) {
    const val = parseInt(e.target.value, 10);
    this.args.onUpdate('tournament_match_number_per_day', isNaN(val) ? null : val);
  }

  @action addTimeSlot() {
    if (!this.canAddSlot) return;
    const remaining = this.matchesPerDay - this.totalSlotsGameCount;
    this.args.onUpdate('tournament_match_time_slots', [...this.matchTimeSlots, { id: crypto.randomUUID(), start_time: '', game_count: Math.min(1, remaining) }]);
  }

  @action removeTimeSlot(slotId) {
    this.args.onUpdate(
      'tournament_match_time_slots',
      this.matchTimeSlots.filter((s) => s.id !== slotId)
    );
  }

  @action onSlotTimeInput(slotId, e) {
    const isoTime = e.target.value ? `2000-01-01T${e.target.value}:00.000` : '';
    this.args.onUpdate(
      'tournament_match_time_slots',
      this.matchTimeSlots.map((s) => (s.id === slotId ? { ...s, start_time: isoTime } : s))
    );
  }

  @action onSlotGameCountInput(slotId, e) {
    const raw = parseInt(e.target.value, 10);
    if (isNaN(raw) || raw < 1) return;
    const otherTotal = this.matchTimeSlots.filter((s) => s.id !== slotId).reduce((sum, s) => sum + (s.game_count ?? 0), 0);
    const clamped = Math.min(raw, Math.max(1, this.matchesPerDay - otherTotal));
    this.args.onUpdate(
      'tournament_match_time_slots',
      this.matchTimeSlots.map((s) => (s.id === slotId ? { ...s, game_count: clamped } : s))
    );
  }

  <template>
    <div class="space-y-8">

      <div>
        <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
          Match Days
        </label>
        <p class="text-xs text-gray-400 mb-2">Select days when matches will be scheduled</p>
        <div class="flex gap-2 flex-wrap">
          {{#each this.weekdays as |day|}}
            <button
              type="button"
              {{on "click" (fn this.toggleWeekday day.key)}}
              class="w-12 h-12 rounded-xl text-sm font-medium border-2 transition-all
                {{if (this.isWeekdaySelected day.key) 'border-blue-500 bg-blue-50 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300' 'border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300 hover:border-blue-300'}}"
            >
              {{day.label}}
            </button>
          {{/each}}
        </div>
      </div>

      <div>
        <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
          Matches per Day
        </label>
        <div class="flex items-center gap-3 max-w-xs">
          <input
            type="number"
            value={{this.matchesPerDay}}
            min="1"
            max="10"
            placeholder="e.g. 4"
            {{on "input" this.onMatchesPerDayInput}}
            class="w-full px-4 py-2.5 text-sm rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <span class="text-sm text-gray-500 dark:text-gray-400 whitespace-nowrap">matches / day</span>
        </div>
      </div>

      <div>
        <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
          Match Time Slots
        </label>
        <p class="text-xs text-gray-400 mb-3">
          Total games across all slots cannot exceed matches per day
          {{#if this.matchesPerDay}}
            ({{this.totalSlotsGameCount}}/{{this.matchesPerDay}}
            scheduled).
          {{/if}}
        </p>

        <div class="space-y-3">
          {{#each this.matchTimeSlots as |slot|}}
            <div class="flex items-center gap-3 p-3 rounded-xl bg-gray-50 dark:bg-gray-800/50 border border-gray-200 dark:border-gray-700">
              <div class="flex-1">
                <label class="block text-xs text-gray-500 dark:text-gray-400 mb-1">Start Time</label>
                <input
                  type="time"
                  value={{this.getSlotStartTime slot}}
                  {{on "input" (fn this.onSlotTimeInput slot.id)}}
                  class="w-full px-3 py-2 text-sm rounded-lg border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>
              <div class="w-28 shrink-0">
                <label class="block text-xs text-gray-500 dark:text-gray-400 mb-1">Games</label>
                <input
                  type="number"
                  value={{this.getSlotGameCount slot}}
                  min="1"
                  max={{this.matchesPerDay}}
                  {{on "input" (fn this.onSlotGameCountInput slot.id)}}
                  class="w-full px-3 py-2 text-sm rounded-lg border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>
              <button type="button" {{on "click" (fn this.removeTimeSlot slot.id)}} class="mt-5 p-2 rounded-lg text-red-400 hover:text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors shrink-0">
                {{lucideIcon "x" class="w-4 h-4"}}
              </button>
            </div>
          {{/each}}

          {{#if this.canAddSlot}}
            <button
              type="button"
              {{on "click" this.addTimeSlot}}
              class="w-full py-2.5 flex items-center justify-center gap-2 text-sm font-medium text-blue-600 dark:text-blue-400 border-2 border-dashed border-blue-300 dark:border-blue-700 rounded-xl hover:bg-blue-50 dark:hover:bg-blue-900/20 transition-colors"
            >
              {{lucideIcon "plus" class="w-4 h-4"}}
              Add Time Slot
            </button>
          {{else if this.matchesPerDay}}
            <p class="text-xs text-gray-400 text-center py-2">
              All
              {{this.matchesPerDay}}
              matches scheduled across slots.
            </p>
          {{else}}
            <p class="text-xs text-gray-400 text-center py-2">
              Set "Matches per Day" above to add time slots.
            </p>
          {{/if}}
        </div>
      </div>

    </div>
  </template>
}
