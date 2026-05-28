import Component from '@glimmer/component';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { eq } from 'ember-truth-helpers';
import { inject as service } from '@ember/service';

export default class TeamTabsComponent extends Component {
  @service session;

  get displayedTeams() {
    if (this.session.isAuthenticated) {
      return this.args.tabs;
    }
    return this.args.tabs.filter((t) => t !== 'My Teams');
  }

  <template>
    <div class="border-b border-gray-200 dark:border-gray-700">
      <nav class="-mb-px flex space-x-8 items-center" aria-label="Tabs">
        {{#each this.displayedTeams as |tab|}}
          <button
            type="button"
            class={{if
              (eq @activeTab tab)
              "border-indigo-500 dark:border-indigo-400 text-indigo-600 dark:text-indigo-400 whitespace-nowrap py-2.5 px-4 border-b-2 font-semibold text-sm focus:outline-none"
              "border-transparent text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200 hover:border-gray-300 dark:hover:border-gray-600 whitespace-nowrap py-2.5 px-4 border-b-2 font-semibold text-sm transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-indigo-500 rounded-sm"
            }}
            aria-current={{if (eq @activeTab tab) "page" "false"}}
            {{on "click" (fn @onSelectTab tab)}}
          >
            {{tab}}
          </button>
        {{/each}}
        <div class="ml-auto flex items-center">
          {{yield}}
        </div>
      </nav>
    </div>
  </template>
}
