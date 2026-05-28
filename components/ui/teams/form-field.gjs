import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';

export default class FormFieldComponent extends Component {
  @tracked isFocused = false;
  @tracked hasValue = false;

  constructor() {
    super(...arguments);
    this.hasValue = Boolean(this.args.value);
  }

  get isFloating() {
    return this.isFocused || this.hasValue;
  }

  get labelClass() {
    const base =
      'absolute left-3 transition-all duration-200 pointer-events-none font-medium';
    return this.isFloating
      ? `${base} -top-2.5 text-xs bg-white dark:bg-gray-900 px-1 text-indigo-600 dark:text-indigo-400`
      : `${base} top-2.5 text-sm text-gray-400 dark:text-gray-500`;
  }

  get inputClass() {
    const base =
      'block w-full rounded-lg px-3 pt-4 pb-2 text-sm text-gray-900 dark:text-gray-100 bg-white dark:bg-gray-900 transition-all duration-200 outline-none';
    const border = this.isFocused
      ? 'border-2 border-indigo-500 shadow-sm shadow-indigo-100 dark:shadow-indigo-900/30'
      : 'border border-gray-300 dark:border-gray-600 hover:border-gray-400 dark:hover:border-gray-500';
    return `${base} ${border}`;
  }

  @action
  handleFocus() {
    this.isFocused = true;
  }

  @action
  handleBlur(event) {
    this.isFocused = false;
    this.hasValue = Boolean(event.target.value);
  }

  <template>
    <div class="relative w-full">
      {{! Floating Label }}
      <label for={{@id}} class={{this.labelClass}}>
        {{@label}}
        {{#if @required}}
          <span class="text-red-500 ml-0.5">*</span>
        {{/if}}
      </label>

      {{! Input }}
      <input
        id={{@id}}
        name={{@id}}
        type={{if @type @type "text"}}
        value={{@value}}
        autocomplete={{if @autocomplete @autocomplete "off"}}
        class={{this.inputClass}}
        {{on "focus" this.handleFocus}}
        {{on "blur" this.handleBlur}}
        {{on "input" @onInput}}
        ...attributes
      />

      {{! Helper text }}
      {{#if @hint}}
        <p class="mt-1 text-xs text-gray-400 dark:text-gray-500 pl-1">
          {{@hint}}
        </p>
      {{/if}}

      {{! Error state }}
      {{#if @error}}
        <p class="mt-1 text-xs text-red-500 pl-1 flex items-center gap-1">
          <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
            <path
              fill-rule="evenodd"
              d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z"
              clip-rule="evenodd"
            />
          </svg>
          {{@error}}
        </p>
      {{/if}}

      {{yield}}
    </div>
  </template>
}
