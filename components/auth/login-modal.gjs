import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { service } from '@ember/service';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { eq } from 'ember-truth-helpers';
import LoginForm from './login-form';
import SignupForm from './signup-form';
import ForgotPassword from './forgot-password';

export default class LoginModalComponent extends Component {
  @service authModal;

  @tracked forgotPasswordEmail = '';

  @action
  handleForgotPassword(email) {
    this.forgotPasswordEmail = email;
    this.authModal.switchTo('forgot-password');
  }

  get isLoginTab() {
    return this.authModal.activeTab === 'login';
  }

  get isForgotPassword() {
    return this.authModal.activeTab === 'forgot-password';
  }

  get modalTitle() {
    if (this.isForgotPassword) return 'Reset your password';
    if (this.isLoginTab) return 'Welcome back';
    return 'Create your account';
  }

  get modalSubtitle() {
    if (this.isForgotPassword) return 'Enter your email and a new password.';
    if (this.isLoginTab) return 'Enter your credentials to continue.';
    return 'Join Spordium to track live matches and more.';
  }

  <template>
    {{#if this.authModal.isOpen}}
      <div class="fixed inset-0 z-50 flex items-center justify-center p-2 sm:p-4" role="dialog" aria-modal="true">

        {{! Backdrop }}
        <div class="absolute inset-0 bg-black/50 backdrop-blur-sm" {{on "click" this.authModal.close}}></div>

        {{! Modal Card }}
        <div class="relative z-10 w-full max-w-md bg-transparent
                    rounded-2xl shadow-2xl
                    overflow-y-auto max-h-[calc(100dvh-1rem)] no-scrollbar">

          {{!--! Header: title + close button }}
          <div class="flex items-start justify-between px-6 pt-6 pb-4">
            <div>
              <h2 class="text-xl font-bold text-gray-900 dark:text-white">
                {{this.modalTitle}}
              </h2>
              <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
                {{this.modalSubtitle}}
              </p>
            </div>
            <button
              type="button"
              {{on "click" this.authModal.close}}
              aria-label="Close"
              class="ml-4 mt-0.5 p-1.5 rounded-lg text-gray-400 hover:text-gray-600
                     dark:hover:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors shrink-0"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>--}}

          {{! Form }}
          <div>
            {{#if this.isForgotPassword}}
              <ForgotPassword
                @email={{this.forgotPasswordEmail}}
                @onBackToLogin={{fn this.authModal.switchTo "login"}}
                @onSuccess={{fn this.authModal.switchTo "login"}}
              />
            {{else if this.isLoginTab}}
              <LoginForm
                @isModal={{true}}
                @onClose={{this.authModal.close}}
                @onSwitchToSignup={{fn this.authModal.switchTo "signup"}}
                @onForgotPassword={{this.handleForgotPassword}}
              />
            {{else}}
              <SignupForm
                @isModal={{true}}
                @onClose={{this.authModal.close}}
                @onSwitchToLogin={{fn this.authModal.switchTo "login"}}
              />
            {{/if}}
          </div>

        </div>
      </div>
    {{/if}}
  </template>
}
