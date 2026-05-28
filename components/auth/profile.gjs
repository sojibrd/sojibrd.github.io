import Component from '@glimmer/component';
import { service } from '@ember/service';
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import ViewProfile from './profile/view-profile';
import EditProfile from './profile/edit-profile';

export default class ProfileRouteComponent extends Component {
  @service store;
  @service session;
  @service toast;
  @service router;

  @tracked profile   = null;
  @tracked isLoading = true;
  @tracked isSaving  = false;
  @tracked error     = null;
  @tracked isEditing = false;

  constructor() {
    super(...arguments);
    this.loadProfile(this.args.model);
  }

  @action async loadProfile(username) {
    this.isLoading = true;
    this.error     = null;
    try {
      this.profile = await this.store.queryRecord('user-profile', { user_name: username });
    } catch (e) {
      this.error = e?.message ?? 'Failed to load profile. Please try again.';
    } finally {
      this.isLoading = false;
    }
  }

  get isCurrentUser() {
    return (
      this.session.isAuthenticated &&
      this.session.currentUser?.user_username === this.profile?.user_username
    );
  }

  @action beginEditing()  { this.isEditing = true;  }
  @action cancelEditing() {
    if (this.profile?.hasDirtyAttributes) {
      this.profile.rollbackAttributes();
    }
    this.isEditing = false;
  }

  @action
  async saveProfile(event) {
    event.preventDefault();
    if (this.isSaving) return;
    this.isSaving = true;
    const oldUsername = this.args.model;
    try {
      await this.profile.save();
      const newUsername = this.profile.user_username;
      const usernameChanged = newUsername && newUsername !== oldUsername;
      if (usernameChanged) {
        await this.session.updateUser({ ...this.session.currentUser, user_username: newUsername });
        this.isEditing = false;
        this.toast.success('Profile updated successfully');
        this.router.transitionTo('profile', newUsername);
      } else {
        this.profile = await this.store.queryRecord('user-profile', { user_name: oldUsername });
        this.isEditing = false;
        this.toast.success('Profile updated successfully');
      }
    } catch (err) {
      this.toast.error(err?.message ?? 'Failed to save profile. Please try again.');
      if (this.profile?.hasDirtyAttributes) {
        this.profile.rollbackAttributes();
      }
    } finally {
      this.isSaving = false;
    }
  }

  <template>
    <div class="min-h-screen bg-gray-50 dark:bg-gray-950 py-10 px-4 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-5xl">

        {{#if this.isLoading}}
          <div class="flex flex-col items-center justify-center py-24 gap-4">
            <div class="h-12 w-12 animate-spin rounded-full border-4 border-indigo-500 border-t-transparent"></div>
            <p class="text-sm text-gray-400 dark:text-gray-500">Loading profile…</p>
          </div>

        {{else if this.error}}
          <div class="flex flex-col items-center justify-center py-24 gap-4 text-center">
            <span class="text-5xl">⚠️</span>
            <p class="text-base font-semibold text-red-500 dark:text-red-400">{{this.error}}</p>
            <button
              type="button"
              {{on "click" (fn this.loadProfile this.args.model)}}
              class="mt-2 px-6 py-2.5 text-sm font-bold text-white bg-indigo-600 hover:bg-indigo-500 rounded-xl transition-colors"
            >
              Try again
            </button>
          </div>

        {{else if this.profile}}
          {{#if this.isEditing}}
            <EditProfile
              @profile={{this.profile}}
              @isSaving={{this.isSaving}}
              @onCancel={{this.cancelEditing}}
              @onSave={{this.saveProfile}}
            />
          {{else}}
            <ViewProfile
              @profile={{this.profile}}
              @isCurrentUser={{this.isCurrentUser}}
              @onEdit={{this.beginEditing}}
              @onProfileRefresh={{fn this.loadProfile this.args.model}}
            />
          {{/if}}
        {{/if}}

      </div>
    </div>
  </template>
}
