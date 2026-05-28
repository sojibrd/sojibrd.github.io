import Component from '@glimmer/component';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { eq } from 'ember-truth-helpers';

export default class Pagonation extends Component {
  // Returns an array of { n: number|null, ellipsis: boolean }
  get pages() {
    const total   = this.args.totalPages  ?? 1;
    const current = this.args.currentPage ?? 1;

    const add = (n)  => ({ n, ellipsis: false });
    const gap = ()   => ({ n: null, ellipsis: true });

    if (total <= 7) {
      return Array.from({ length: total }, (_, i) => add(i + 1));
    }

    const result = [add(1)];

    if (current > 3)           result.push(gap());

    const start = Math.max(2, current - 1);
    const end   = Math.min(total - 1, current + 1);
    for (let i = start; i <= end; i++) result.push(add(i));

    if (current < total - 2)   result.push(gap());
    result.push(add(total));

    return result;
  }

  get isFirst() { return (this.args.currentPage ?? 1) <= 1; }
  get isLast()  { return (this.args.currentPage ?? 1) >= (this.args.totalPages ?? 1); }

  <template>
    {{#if (eq @totalPages 1)}}
      {{! single page — nothing to show }}
    {{else}}
    <nav
      aria-label="Pagination"
      class="flex items-center justify-center gap-1.5 mt-10 select-none"
    >

      {{! ── Previous ── }}
      <button
        type="button"
        disabled={{this.isFirst}}
        {{on "click" @onPreviousClick}}
        class="group flex items-center gap-1.5 px-3 py-2 rounded-xl text-sm font-semibold
               border transition-all duration-200
               {{if this.isFirst
                 'border-gray-200 dark:border-gray-700 text-gray-300 dark:text-gray-600 cursor-not-allowed bg-white dark:bg-gray-900'
                 'border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-300
                  bg-white dark:bg-gray-900
                  hover:bg-indigo-50 dark:hover:bg-indigo-900/20
                  hover:border-indigo-300 dark:hover:border-indigo-600
                  hover:text-indigo-600 dark:hover:text-indigo-400
                  shadow-sm'}}"
      >
        <svg class="w-4 h-4 transition-transform duration-200 {{if this.isFirst '' 'group-hover:-translate-x-0.5'}}"
             viewBox="0 0 24 24" fill="none" stroke="currentColor"
             stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M15 18l-6-6 6-6"/>
        </svg>
        <span class="hidden sm:inline"></span>
      </button>

      {{! ── Page numbers ── }}
      {{#each this.pages as |page|}}
        {{#if page.ellipsis}}
          <span class="flex items-end justify-center w-9 h-9 pb-1
                       text-gray-400 dark:text-gray-500 text-sm tracking-widest">
            ···
          </span>
        {{else}}
          <button
            type="button"
            {{on "click" (fn @onPageIndexClick page.n)}}
            class="relative flex items-center justify-center w-9 h-9 rounded-xl text-sm font-bold
                   border transition-all duration-200
                   {{if (eq page.n @currentPage)
                     'bg-gradient-to-br from-indigo-500 to-violet-600
                      dark:from-indigo-600 dark:to-violet-700
                      border-transparent text-white shadow-md shadow-indigo-400/30
                      dark:shadow-indigo-700/40 scale-105'
                     'bg-white dark:bg-gray-900
                      border-gray-200 dark:border-gray-700
                      text-gray-600 dark:text-gray-300
                      hover:bg-indigo-50 dark:hover:bg-indigo-900/20
                      hover:border-indigo-300 dark:hover:border-indigo-600
                      hover:text-indigo-600 dark:hover:text-indigo-400
                      shadow-sm'}}"
          >
            {{page.n}}
            {{#if (eq page.n @currentPage)}}
              <span class="absolute inset-0 rounded-xl ring-2 ring-indigo-400/40 dark:ring-indigo-500/30 ring-offset-1 dark:ring-offset-gray-950"></span>
            {{/if}}
          </button>
        {{/if}}
      {{/each}}

      {{! ── Next ── }}
      <button
        type="button"
        disabled={{this.isLast}}
        {{on "click" @onNextClick}}
        class="group flex items-center gap-1.5 px-3 py-2 rounded-xl text-sm font-semibold
               border transition-all duration-200
               {{if this.isLast
                 'border-gray-200 dark:border-gray-700 text-gray-300 dark:text-gray-600 cursor-not-allowed bg-white dark:bg-gray-900'
                 'border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-300
                  bg-white dark:bg-gray-900
                  hover:bg-indigo-50 dark:hover:bg-indigo-900/20
                  hover:border-indigo-300 dark:hover:border-indigo-600
                  hover:text-indigo-600 dark:hover:text-indigo-400
                  shadow-sm'}}"
      >
        <span class="hidden sm:inline"></span>
        <svg class="w-4 h-4 transition-transform duration-200 {{if this.isLast '' 'group-hover:translate-x-0.5'}}"
             viewBox="0 0 24 24" fill="none" stroke="currentColor"
             stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M9 18l6-6-6-6"/>
        </svg>
      </button>

    </nav>
    {{/if}}
  </template>
}
