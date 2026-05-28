import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { service } from '@ember/service';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { array } from '@ember/helper';
import { eq } from 'ember-truth-helpers';
import tuiCalendarModifier from 'spordium/modifiers/tui-calendar';

const DARK_THEME = {
  common: {
    backgroundColor: '#0f172a',
    border: '1px solid #1e293b',
    holiday: { color: '#f87171' },
    saturday: { color: '#94a3b8' },
    dayName: { color: '#94a3b8' },
    today: { color: '#818cf8' },
    gridSelection: {
      backgroundColor: 'rgba(129, 140, 248, 0.15)',
      border: '1px solid #818cf8',
    },
  },
  month: {
    dayExceptThisMonth: { color: '#475569' },
    holidayExceptThisMonth: { color: '#475569' },
    moreView: {
      backgroundColor: '#1e293b',
      border: '1px solid #334155',
    },
    gridCell: { headerHeight: 31 },
  },
  week: {
    nowIndicatorLabel: { color: '#818cf8' },
    nowIndicatorPast: { border: '1px dashed #475569' },
    nowIndicatorBullet: { backgroundColor: '#818cf8' },
    nowIndicatorToday: { border: '1px solid #818cf8' },
    timeGridHour: { color: '#64748b' },
    timeGridHalfHour: { border: '1px solid #1e293b' },
  },
};

function formatDateLabel(date, view) {
  const formatOptions = {
    month: { year: 'numeric', month: 'long' },
    week: { year: 'numeric', month: 'short', day: 'numeric' },
    day: { year: 'numeric', month: 'long', day: 'numeric' },
  };
  return new Intl.DateTimeFormat('en-US', formatOptions[view] ?? formatOptions.month).format(date);
}

export default class TuiCalendarComponent extends Component {
  @service theme;

  @tracked calendarInstance = null;
  @tracked currentView = this.args.view ?? 'month';
  @tracked dateLabel = formatDateLabel(new Date(), this.args.view ?? 'month');

  // theme.isDark tracked — toggle হলে এই getter re-run হবে → setTheme() call হবে
  get syncTheme() {
    const isDark = this.theme.isDark;
    if (!this.calendarInstance) return;
    this.calendarInstance.setTheme(isDark ? DARK_THEME : {});
  }

  @action
  onCalendarReady(instance) {
    this.calendarInstance = instance;

    instance.on('beforeCreateEvent', (eventData) => {
      instance.createEvents([{ ...eventData, id: crypto.randomUUID() }]);
      this.args.onCreateEvent?.(eventData);
    });

    instance.on('beforeUpdateEvent', ({ event, changes }) => {
      instance.updateEvent(event.id, event.calendarId, changes);
      this.args.onUpdateEvent?.({ event, changes });
    });

    instance.on('beforeDeleteEvent', (event) => {
      instance.deleteEvent(event.id, event.calendarId);
      this.args.onDeleteEvent?.(event);
    });

    instance.on('clickEvent', ({ event }) => {
      this.args.onClickEvent?.(event);
    });

    this.#updateLabel();
  }

  @action goToday() {
    this.calendarInstance?.today();
    this.#updateLabel();
  }
  @action goPrev() {
    this.calendarInstance?.prev();
    this.#updateLabel();
  }
  @action goNext() {
    this.calendarInstance?.next();
    this.#updateLabel();
  }

  @action
  changeView(view) {
    this.calendarInstance?.changeView(view);
    this.currentView = view;
    this.#updateLabel();
  }

  #updateLabel() {
    const rawDate = this.calendarInstance?.getDate();
    const date = rawDate?.toDate?.() ?? rawDate ?? new Date();
    this.dateLabel = formatDateLabel(date, this.currentView);
  }

  <template>
    <div class="tui-wrapper">
      {{! syncTheme consume করতে হবে — theme toggle এ reactive হবে }}
      {{this.syncTheme}}

      <nav class="tui-nav" aria-label="Calendar navigation">
        <div class="tui-nav__group">
          <button type="button" class="tui-btn" aria-label="Previous period" {{on "click" this.goPrev}}>← Prev</button>
          <button type="button" class="tui-btn tui-btn--today" aria-label="Go to today" {{on "click" this.goToday}}>Today</button>
          <button type="button" class="tui-btn" aria-label="Next period" {{on "click" this.goNext}}>Next →</button>
        </div>

        <div class="tui-nav__label" role="heading" aria-live="polite">
          {{this.dateLabel}}
        </div>

        <div class="tui-nav__group" role="group" aria-label="View switcher">
          {{#each (array "month" "week" "day") as |view|}}
            <button type="button" class="tui-btn {{if (eq this.currentView view) 'tui-btn--active'}}" aria-pressed={{if (eq this.currentView view) "true" "false"}} {{on "click" (fn this.changeView view)}}>
              {{view}}
            </button>
          {{/each}}
        </div>
      </nav>

      <div class="tui-calendar-body" {{tuiCalendarModifier view=this.currentView events=@events calendars=@calendars usageStatistics=false useFormPopup=@useFormPopup useDetailPopup=@useDetailPopup theme=@theme onReady=this.onCalendarReady}}>
      </div>
    </div>
  </template>
}
