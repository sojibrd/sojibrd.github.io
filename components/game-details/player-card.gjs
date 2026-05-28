import Component from '@glimmer/component';
import { action } from '@ember/object';
import { service } from '@ember/service';
import { tracked } from '@glimmer/tracking';
import { on } from '@ember/modifier';

export default class PlayerCard extends Component {
  @service api;
  @service router;

  @tracked isNavigating = false;

  @action
  async goToPlayer() {
    if (this.isNavigating) return;
    this.isNavigating = true;
    try {
      const res = await this.api.get(`/auth_user/get_profile_info/`, { user_id: this.args.player.id });
      const username = res?.data?.user_username;
      if (username) {
        this.router.transitionTo('player', username);
      } else {
        this.router.transitionTo('player', this.args.player.id);
      }
    } catch {
      this.router.transitionTo('player', this.args.player.id);
    } finally {
      this.isNavigating = false;
    }
  }

  <template>
    <button
      type="button"
      {{on "click" this.goToPlayer}}
      class="w-full flex items-center gap-3 bg-gray-50 dark:bg-slate-700/60 hover:bg-gray-100 dark:hover:bg-slate-700 rounded-xl p-3 transition-all border border-gray-200 dark:border-slate-600/30 shadow-sm hover:shadow-md hover:-translate-y-0.5 cursor-pointer text-left"
    >
      <span class="text-gray-500 dark:text-gray-500 text-xs w-5 font-semibold">{{@index}}</span>
      <div class="w-11 h-11 sm:w-12 sm:h-12 lg:w-14 lg:h-14 rounded-xl overflow-hidden bg-gray-200 dark:bg-slate-600 flex-shrink-0 shadow-inner">
        <img
          src={{@player.avatar}}
          alt={{@player.name}}
          class="w-full h-full object-cover"
          onerror="this.src='/assets/avatar/boy (1).webp'"
        />
      </div>
      <div class="flex-1 min-w-0">
        <div class="flex items-center gap-2">
          <h4 class="text-gray-900 dark:text-white font-semibold text-sm lg:text-base truncate">{{@player.name}}</h4>
          {{#if @player.is12thMan}}
            <span class="text-[10px] bg-amber-500/20 text-amber-600 dark:text-amber-400 px-1.5 py-0.5 rounded font-medium">12th</span>
          {{/if}}
          {{#if @player.isLeftHanded}}
            <span class="text-[10px] bg-cyan-500/20 text-cyan-600 dark:text-cyan-400 px-1.5 py-0.5 rounded font-medium">LH</span>
          {{/if}}
        </div>
        {{#if @player.role}}
          <p class="text-cyan-600 dark:text-cyan-400/80 text-xs lg:text-sm font-medium">{{@player.role}}</p>
        {{/if}}
        {{#if @player.style}}
          <p class="text-gray-500 dark:text-gray-500 text-xs lg:text-sm truncate">{{@player.style}}</p>
        {{/if}}
      </div>
      {{#if this.isNavigating}}
        <div class="w-4 h-4 border-2 border-indigo-500 border-t-transparent rounded-full animate-spin flex-shrink-0"></div>
      {{/if}}
    </button>
  </template>
}
