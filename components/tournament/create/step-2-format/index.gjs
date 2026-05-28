import Component from '@glimmer/component';
import MatchInfo from './match-info';
import GroupsConfig from './groups-config';
import PlayerRules from './player-rules';

export default class Step2Format extends Component {
  <template>
    <div class="space-y-8">

      {{! Section: Match Info }}
      <div>
        <h3 class="text-sm font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider mb-4">
          Match Configuration
        </h3>
        <MatchInfo @data={{@data}} @onUpdate={{@onUpdate}} />
      </div>

      <div class="border-t border-gray-100 dark:border-gray-800" />

      {{! Section: Groups }}
      <div>
        <h3 class="text-sm font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider mb-4">
          Groups
        </h3>
        <GroupsConfig @data={{@data}} @onUpdate={{@onUpdate}} @paidTeams={{@paidTeams}} />
      </div>

      <div class="border-t border-gray-100 dark:border-gray-800" />

      {{! Section: Player Rules }}
      <div>
        <h3 class="text-sm font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider mb-4">
          Player &amp; Scoring Rules
        </h3>
        <PlayerRules @data={{@data}} @onUpdate={{@onUpdate}} />
      </div>

    </div>
  </template>
}
