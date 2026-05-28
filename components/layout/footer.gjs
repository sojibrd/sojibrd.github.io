import Component from '@glimmer/component';
import { LinkTo } from '@ember/routing';

export default class FooterComponent extends Component {
  get currentYear() {
    return new Date().getFullYear();
  }

  <template>
    <footer class="relative z-10 bg-gray-100 dark:bg-slate-800/80 border-t border-gray-200 dark:border-slate-700/50 mt-auto transition-colors duration-200">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">

        {{! Main Footer Content }}
        <div class="py-8 sm:py-10">
          <div class="flex flex-col sm:flex-row sm:justify-between gap-8">

            {{! Brand Column }}
            <div>
              <div class="mb-3">
                <img src="/spordium_text.svg" alt="Spordium" class="h-8" />
              </div>
              <p class="text-gray-500 dark:text-gray-400 text-sm leading-relaxed">
                Score Live, Broadcast Wide.
              </p>
            </div>

            {{! Quick Links }}
            <div>
              <h4 class="text-gray-900 dark:text-white font-semibold text-sm mb-3">Quick Links</h4>
              <ul class="space-y-2">
                <li>
                  <LinkTo @route="index" class="text-gray-500 dark:text-gray-400 hover:text-cyan-500 dark:hover:text-cyan-400 text-sm transition-colors">
                    Home
                  </LinkTo>
                </li>
                <li>
                  <LinkTo @route="about" class="text-gray-500 dark:text-gray-400 hover:text-cyan-500 dark:hover:text-cyan-400 text-sm transition-colors">
                    About Us
                  </LinkTo>
                </li>
                <li>
                  <LinkTo @route="contact-us" class="text-gray-500 dark:text-gray-400 hover:text-cyan-500 dark:hover:text-cyan-400 text-sm transition-colors">
                    Contact Us
                  </LinkTo>
                </li>
                <li>
                  <LinkTo
                    @route="privacy-policy"
                    class="text-gray-500 dark:text-gray-400 hover:text-cyan-500 dark:hover:text-cyan-400 text-sm transition-colors"
                  >
                    Privacy Policy
                  </LinkTo>
                </li>
                <li>
                  <LinkTo
                    @route="terms-and-conditions"
                    class="text-gray-500 dark:text-gray-400 hover:text-cyan-500 dark:hover:text-cyan-400 text-sm transition-colors"
                  >
                    Terms &amp; Conditions
                  </LinkTo>
                </li>
              </ul>
            </div>

            {{! Contact + Follow Us }}
            <div>
              <h4 class="text-gray-900 dark:text-white font-semibold text-sm mb-3">Contact</h4>
              <ul class="space-y-2 mb-6">
                <li>
                  <a href="tel:+8801329660799" class="text-gray-500 dark:text-gray-400 hover:text-cyan-500 dark:hover:text-cyan-400 text-sm transition-colors">
                    +880 1329660799
                  </a>
                </li>
                <li>
                  <a href="#" class="text-gray-500 dark:text-gray-400 hover:text-cyan-500 dark:hover:text-cyan-400 text-sm transition-colors">
                    spordium.com
                  </a>
                </li>
                <li>
                  <a
                    href="mailto:support@spordium.com"
                    class="text-gray-500 dark:text-gray-400 hover:text-cyan-500 dark:hover:text-cyan-400 text-sm transition-colors"
                  >
                    support@spordium.com
                  </a>
                </li>
                <li>
                  <p class="text-gray-500 dark:text-gray-400 text-sm leading-relaxed">
                    Spordium, Flat A4, House 25, Road 4, Block F, Banani, Dhaka - 1213, Bangladesh
                  </p>
                </li>
              </ul>

              <h4 class="text-gray-900 dark:text-white font-semibold text-sm mb-3">Follow Us</h4>
              <div class="flex items-center gap-3">
                <a
                  href="https://www.facebook.com/spordium.official"
                  aria-label="Facebook"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="w-9 h-9 rounded-full bg-gray-200 dark:bg-slate-700 flex items-center justify-center text-gray-500 dark:text-gray-400 hover:text-cyan-500 dark:hover:text-cyan-400 hover:bg-gray-300 dark:hover:bg-slate-600 transition-colors"
                >
                  <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                    <path
                      d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"
                    ></path>
                  </svg>
                </a>
                <a
                  href="https://www.youtube.com/@SpordiumTV"
                  aria-label="YouTube"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="w-9 h-9 rounded-full bg-gray-200 dark:bg-slate-700 flex items-center justify-center text-gray-500 dark:text-gray-400 hover:text-cyan-500 dark:hover:text-cyan-400 hover:bg-gray-300 dark:hover:bg-slate-600 transition-colors"
                >
                  <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                    <path
                      d="M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z"
                    ></path>
                  </svg>
                </a>
                <a
                  href="https://x.com/spordium"
                  aria-label="X"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="w-9 h-9 rounded-full bg-gray-200 dark:bg-slate-700 flex items-center justify-center text-gray-500 dark:text-gray-400 hover:text-cyan-500 dark:hover:text-cyan-400 hover:bg-gray-300 dark:hover:bg-slate-600 transition-colors"
                >
                  <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                    <path
                      d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-4.714-6.231-5.401 6.231H2.746l7.73-8.835L1.254 2.25H8.08l4.259 5.631 5.905-5.631zm-1.161 17.52h1.833L7.084 4.126H5.117z"
                    ></path>
                  </svg>
                </a>
                <a
                  href="https://www.linkedin.com/company/spordium"
                  aria-label="LinkedIn"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="w-9 h-9 rounded-full bg-gray-200 dark:bg-slate-700 flex items-center justify-center text-gray-500 dark:text-gray-400 hover:text-cyan-500 dark:hover:text-cyan-400 hover:bg-gray-300 dark:hover:bg-slate-600 transition-colors"
                >
                  <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                    <path
                      d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433a2.062 2.062 0 0 1-2.063-2.065 2.064 2.064 0 1 1 2.063 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"
                    ></path>
                  </svg>
                </a>
              </div>
            </div>

          </div>
        </div>

        {{! Bottom Bar }}
        <div class="py-5 border-t border-gray-200 dark:border-slate-700/50">
          <p class="text-center text-gray-400 dark:text-gray-500 text-xs mb-2">
            &copy;Spordium
            {{this.currentYear}}. All rights reserved.
          </p>
          <p class="text-center text-gray-400 dark:text-gray-500 text-xs max-w-2xl mx-auto">
            Spordium and its logo are trademarks of Spordium. All content, designs and software on this platform are protected by applicable copyright
            intellectual property laws. Unauthorized use or reproduction is strictly prohibited.
          </p>
        </div>

      </div>
    </footer>
  </template>
}
