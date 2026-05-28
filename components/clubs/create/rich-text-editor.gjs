/**
 * RichTextEditor
 * ──────────────────────────────────────────────────────────────────────────────
 * A `contenteditable` rich-text description editor backed by `document.execCommand`.
 * Includes a toolbar with: font family, font size, bold, italic, underline,
 * strikethrough, text colour, align left/centre/right, ordered & unordered lists.
 *
 * The editor content is NOT tracked by this component — the parent must handle
 * the `onInput` callback and persist the HTML string itself.
 *
 * NOTE: The parent's validation reads `document.getElementById(editorId)` directly,
 * so @editorId must match what the parent looks up.
 *
 * @arg {string}   [editorId]      - id attribute on the contenteditable div.
 *                                   Defaults to "rich-editor".
 * @arg {string}   [placeholder]   - Placeholder text when the editor is empty.
 * @arg {string}   [initialHtml]   - HTML to pre-populate the editor (edit scenarios).
 *                                   Pass a NON-TRACKED field so this only fires once.
 * @arg {string[]} fontFamilies    - List of font-family option strings.
 * @arg {Array<{label: string, value: string}>} fontSizes
 *                                 - Font size options (value is the execCommand size 1–7).
 * @arg {string}   [error]         - Validation error message.
 * @arg {boolean}  [required]      - Shows asterisk next to the label.
 * @arg {Function} onInput         - Called with the native `input` event.
 * @arg {Function} onFmt           - Called with a `document.execCommand` command string.
 * @arg {Function} onFmtVal        - Called with (command, event) for value-based commands.
 * @arg {Function} onSetTextColor  - Called with the `input[type=color]` change event.
 *
 * Usage:
 *   <RichTextEditor
 *     @editorId="rich-editor"
 *     @placeholder="Describe your club…"
 *     @initialHtml={{this._initialDescription}}
 *     @fontFamilies={{this.fontFamilies}}
 *     @fontSizes={{this.fontSizes}}
 *     @error={{this.errors.description}}
 *     @required={{true}}
 *     @onInput={{this.onDescriptionInput}}
 *     @onFmt={{this.fmt}}
 *     @onFmtVal={{this.fmtVal}}
 *     @onSetTextColor={{this.setTextColor}}
 *   />
 */
import Component from '@glimmer/component';
import { scheduleOnce } from '@ember/runloop';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import FormFieldError from './form-field-error';

export default class RichTextEditorComponent extends Component {
  constructor(owner, args) {
    super(owner, args);
    // Pre-populate contenteditable once after first render if initialHtml is provided.
    // scheduleOnce('afterRender') ensures the DOM element exists before we write to it.
    if (args.initialHtml) {
      scheduleOnce('afterRender', this, this._setInitialHtml);
    }
  }

  _setInitialHtml() {
    const editorId = this.args.editorId ?? 'rich-editor';
    const el = document.getElementById(editorId);
    if (el && !el.dataset.rteInitialized) {
      el.innerHTML = this.args.initialHtml;
      el.dataset.rteInitialized = '1';
    }
  }

  <template>
    <div>
      <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
        Description / BIO
        {{#if @required}}<span class="text-rose-500"> *</span>{{/if}}
      </label>

      <div class="rounded-xl border transition-all duration-200
                  {{if @error
                    'border-rose-400 dark:border-rose-500'
                    'border-gray-200 dark:border-gray-600
                     focus-within:border-indigo-400 dark:focus-within:border-indigo-500
                     focus-within:ring-2 focus-within:ring-indigo-400/20 dark:focus-within:ring-indigo-500/20'}}
                  overflow-hidden bg-white dark:bg-gray-800">

        {{! Toolbar }}
        <div class="flex flex-wrap items-center gap-0.5 px-2 py-2
                    bg-gray-50 dark:bg-gray-700/50
                    border-b border-gray-200 dark:border-gray-600">

          {{! Font family }}
          <select
            {{on "change" (fn @onFmtVal "fontName")}}
            class="h-7 text-xs rounded-lg border border-gray-200 dark:border-gray-600
                   bg-white dark:bg-gray-700 text-gray-700 dark:text-gray-300
                   px-1.5 mr-1 focus:outline-none focus:ring-1 focus:ring-indigo-400/50
                   transition-all duration-150"
            title="Font family"
          >
            {{#each @fontFamilies as |font|}}
              <option value={{font}}>{{font}}</option>
            {{/each}}
          </select>

          {{! Font size }}
          <select
            {{on "change" (fn @onFmtVal "fontSize")}}
            class="h-7 text-xs rounded-lg border border-gray-200 dark:border-gray-600
                   bg-white dark:bg-gray-700 text-gray-700 dark:text-gray-300
                   px-1.5 mr-1 focus:outline-none focus:ring-1 focus:ring-indigo-400/50
                   transition-all duration-150"
            title="Font size"
          >
            {{#each @fontSizes as |size|}}
              <option value={{size.value}}>{{size.label}}</option>
            {{/each}}
          </select>

          <div class="w-px h-5 bg-gray-200 dark:bg-gray-600 mx-0.5"></div>

          {{! Bold }}
          <button type="button" {{on "click" (fn @onFmt "bold")}} title="Bold"
                  class="w-7 h-7 flex items-center justify-center rounded-lg
                         text-gray-600 dark:text-gray-400 font-bold text-sm
                         hover:bg-gray-200 dark:hover:bg-gray-600 transition-all duration-150">B</button>

          {{! Italic }}
          <button type="button" {{on "click" (fn @onFmt "italic")}} title="Italic"
                  class="w-7 h-7 flex items-center justify-center rounded-lg
                         text-gray-600 dark:text-gray-400 italic text-sm
                         hover:bg-gray-200 dark:hover:bg-gray-600 transition-all duration-150">I</button>

          {{! Underline }}
          <button type="button" {{on "click" (fn @onFmt "underline")}} title="Underline"
                  class="w-7 h-7 flex items-center justify-center rounded-lg
                         text-gray-600 dark:text-gray-400 underline text-sm
                         hover:bg-gray-200 dark:hover:bg-gray-600 transition-all duration-150">U</button>

          {{! Strikethrough }}
          <button type="button" {{on "click" (fn @onFmt "strikeThrough")}} title="Strikethrough"
                  class="w-7 h-7 flex items-center justify-center rounded-lg
                         text-gray-600 dark:text-gray-400 line-through text-sm
                         hover:bg-gray-200 dark:hover:bg-gray-600 transition-all duration-150">S</button>

          <div class="w-px h-5 bg-gray-200 dark:bg-gray-600 mx-0.5"></div>

          {{! Text colour }}
          <label class="relative w-7 h-7 flex items-center justify-center rounded-lg
                        hover:bg-gray-200 dark:hover:bg-gray-600 cursor-pointer
                        transition-all duration-150" title="Text color">
            <svg class="w-4 h-4 text-gray-600 dark:text-gray-400" viewBox="0 0 24 24"
                 fill="none" stroke="currentColor" stroke-width="2"
                 stroke-linecap="round" stroke-linejoin="round">
              <path d="M9 7l-5 13h2l1.5-4h7l1.5 4h2L13 7z"/>
              <path d="M7.5 14l2-5.5 2 5.5"/>
            </svg>
            <input type="color" class="absolute inset-0 opacity-0 w-full h-full cursor-pointer"
                   {{on "input" @onSetTextColor}} />
          </label>

          <div class="w-px h-5 bg-gray-200 dark:bg-gray-600 mx-0.5"></div>

          {{! Align left }}
          <button type="button" {{on "click" (fn @onFmt "justifyLeft")}} title="Align left"
                  class="w-7 h-7 flex items-center justify-center rounded-lg
                         text-gray-600 dark:text-gray-400
                         hover:bg-gray-200 dark:hover:bg-gray-600 transition-all duration-150">
            <svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                 stroke-width="2.5" stroke-linecap="round">
              <line x1="3" y1="6" x2="21" y2="6"/>
              <line x1="3" y1="12" x2="15" y2="12"/>
              <line x1="3" y1="18" x2="18" y2="18"/>
            </svg>
          </button>

          {{! Align centre }}
          <button type="button" {{on "click" (fn @onFmt "justifyCenter")}} title="Align center"
                  class="w-7 h-7 flex items-center justify-center rounded-lg
                         text-gray-600 dark:text-gray-400
                         hover:bg-gray-200 dark:hover:bg-gray-600 transition-all duration-150">
            <svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                 stroke-width="2.5" stroke-linecap="round">
              <line x1="3" y1="6" x2="21" y2="6"/>
              <line x1="6" y1="12" x2="18" y2="12"/>
              <line x1="4" y1="18" x2="20" y2="18"/>
            </svg>
          </button>

          {{! Align right }}
          <button type="button" {{on "click" (fn @onFmt "justifyRight")}} title="Align right"
                  class="w-7 h-7 flex items-center justify-center rounded-lg
                         text-gray-600 dark:text-gray-400
                         hover:bg-gray-200 dark:hover:bg-gray-600 transition-all duration-150">
            <svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                 stroke-width="2.5" stroke-linecap="round">
              <line x1="3" y1="6" x2="21" y2="6"/>
              <line x1="9" y1="12" x2="21" y2="12"/>
              <line x1="6" y1="18" x2="21" y2="18"/>
            </svg>
          </button>

          <div class="w-px h-5 bg-gray-200 dark:bg-gray-600 mx-0.5"></div>

          {{! Ordered list }}
          <button type="button" {{on "click" (fn @onFmt "insertOrderedList")}} title="Ordered list"
                  class="w-7 h-7 flex items-center justify-center rounded-lg
                         text-gray-600 dark:text-gray-400
                         hover:bg-gray-200 dark:hover:bg-gray-600 transition-all duration-150">
            <svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                 stroke-width="2" stroke-linecap="round">
              <line x1="10" y1="6" x2="21" y2="6"/>
              <line x1="10" y1="12" x2="21" y2="12"/>
              <line x1="10" y1="18" x2="21" y2="18"/>
              <path d="M4 6h1v4M4 10h2M6 18H4c0-1 2-2 2-3s-1-1.5-2-1"/>
            </svg>
          </button>

          {{! Bullet list }}
          <button type="button" {{on "click" (fn @onFmt "insertUnorderedList")}} title="Bullet list"
                  class="w-7 h-7 flex items-center justify-center rounded-lg
                         text-gray-600 dark:text-gray-400
                         hover:bg-gray-200 dark:hover:bg-gray-600 transition-all duration-150">
            <svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                 stroke-width="2" stroke-linecap="round">
              <line x1="9" y1="6" x2="21" y2="6"/>
              <line x1="9" y1="12" x2="21" y2="12"/>
              <line x1="9" y1="18" x2="21" y2="18"/>
              <circle cx="4" cy="6" r="1" fill="currentColor" stroke="none"/>
              <circle cx="4" cy="12" r="1" fill="currentColor" stroke="none"/>
              <circle cx="4" cy="18" r="1" fill="currentColor" stroke="none"/>
            </svg>
          </button>

        </div>

        {{! Editable content area }}
        <div
          id={{if @editorId @editorId "rich-editor"}}
          contenteditable="true"
          {{on "input" @onInput}}
          class="min-h-[160px] max-h-72 overflow-y-auto
                 px-4 py-3 text-sm text-gray-900 dark:text-gray-100
                 focus:outline-none"
          data-placeholder={{if @placeholder @placeholder "Write something…"}}
        ></div>
      </div>

      {{! CSS placeholder trick }}
      <style>
        #{{if @editorId @editorId "rich-editor"}}:empty:before {
          content: attr(data-placeholder);
          color: #9ca3af;
          pointer-events: none;
        }
      </style>

      <FormFieldError @error={{@error}} />
    </div>
  </template>
}
