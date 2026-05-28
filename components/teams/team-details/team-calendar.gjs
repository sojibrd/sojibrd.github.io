import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import TuiCalendar from 'spordium/components/tui-calendar';

export default class MySchedulePage extends Component {
  @tracked events = [];

  calendars = [{ id: 'cal1', name: 'Matches', backgroundColor: '#6366f1' }];

  get getEvents() {
    return (this.args.games ?? []).map((game) => ({
      id: game.game_id,
      calendarId: 'cal1',
      title: `${game.team1_name} vs ${game.team2_name}`,
      start: new Date(game.match_date),
      end: new Date(new Date(game.match_date).getTime() + 2 * 60 * 60 * 1000),
      isReadOnly: true,
    }));
  }

  @action
  handleCreateEvent(eventData) {
    const newEvent = {
      id: crypto.randomUUID(),
      calendarId: eventData.calendarId,
      title: eventData.title,
      start: eventData.start,
      end: eventData.end,
    };
    this.events = [...this.events, newEvent];
  }

  <template>
    <div class="schedule-page">
      <TuiCalendar @view="month" @events={{this.getEvents}} @calendars={{this.calendars}} @useFormPopup={{true}} @useDetailPopup={{true}} @onCreateEvent={{this.handleCreateEvent}} />
    </div>
  </template>
}
