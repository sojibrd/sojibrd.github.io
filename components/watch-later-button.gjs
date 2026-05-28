import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { service } from '@ember/service';
import { on } from '@ember/modifier';

export default class WatchLaterButton extends Component {
  // @matchId   — required
  // @matchType — string (default: 'tournament')

  @service store;
  @service session;
  @service toast;

  @tracked isAdded   = false;
  @tracked isLoading = false;

  @action
  async add(event) {
    event.preventDefault();
    event.stopPropagation();
    if (this.isAdded || this.isLoading) return;
    if (!this.session.isAuthenticated) {
      this.toast.warning('Please log in to use Watch Later');
      return;
    }
    this.isLoading = true;
    const record = this.store.createRecord('watch-later', {
      userId:    this.session.currentUser?.user_id,
      matchType: this.args.matchType ?? 'tournament',
      matchId:   this.args.matchId,
    });
    try {
      await record.save();
      this.isAdded = true;
      this.toast.success('Added to Watch Later');
    } catch {
      record.unloadRecord();
      this.toast.error('Failed to add to Watch Later');
    } finally {
      this.isLoading = false;
    }
  }

  <template>
    <button
      type="button"
      title="Watch Later"
      {{on "click" this.add}}
      class="p-1 rounded-full transition-colors duration-150
             {{if this.isAdded
               'text-emerald-400 bg-emerald-500/15'
               'text-gray-400 dark:text-white/40
                hover:text-gray-700 dark:hover:text-white/80
                hover:bg-gray-100 dark:hover:bg-white/10'}}"
    >
      {{#if this.isLoading}}
        <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5 animate-spin" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M21 12a9 9 0 1 1-6.219-8.56"/>
        </svg>
      {{else}}
        <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>
        </svg>
      {{/if}}
    </button>
  </template>
}
