import Component from '@glimmer/component';
import TournamentListIndex from './list/index';

// ══════════════════════════════════════════════════════════════════════════════
// TournamentIndex — main page wrapper rendered at /tournament
// ══════════════════════════════════════════════════════════════════════════════
export default class TournamentIndex extends Component {
  <template><TournamentListIndex /></template>
}
