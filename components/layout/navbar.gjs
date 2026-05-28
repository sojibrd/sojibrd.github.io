import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { service } from '@ember/service';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { LinkTo } from '@ember/routing';
import config from 'spordium/config/environment';
import NotificationDropdown from 'spordium/components/ui/notification-dropdown';

export default class NavbarComponent extends Component {
  @service router;
  @service session;
  @service authModal;
  @service theme;

  @tracked isMobileMenuOpen = false;
  @tracked isLogoutConfirmOpen = false;

  get currentRoute() {
    return this.router.currentRouteName || '';
  }

  get isLivePage() {
    return this.currentRoute.startsWith('match');
  }

  get isTeamsPage() {
    return this.currentRoute.startsWith('teams');
  }

  get isTournamentPage() {
    return this.currentRoute.startsWith('tournament');
  }

  get isPlayersPage() {
    return this.currentRoute.startsWith('players');
  }

  get isClubsPage() {
    return this.currentRoute.startsWith('clubs');
  }

  get isFacilitiesPage() {
    return this.currentRoute.startsWith('facilities');
  }

  get isWatchLaterPage() {
    return this.currentRoute === 'watch-later';
  }

  get userInitial() {
    const name =
      this.session.currentUser?.user_username ||
      this.session.currentUser?.user_email ||
      '?';
    return name.charAt(0).toUpperCase();
  }

  get userName() {
    return this.session.currentUser?.user_username || '';
  }

  get userEmail() {
    return this.session.currentUser?.user_email || '';
  }

  get userAvatarUrl() {
    const user = this.session.currentUser;
    if (user?.user_primary_pic) {
      return `${config.APP.S3_BUCKET_URL}/${user.user_primary_pic}`;
    }
    return null;
  }

  _boyIdx  = Math.floor(Math.random() * 3);
  _girlIdx = Math.floor(Math.random() * 2);

  get defaultAvatarUrl() {
    const user = this.session.currentUser;
    const gender = (user?.user_gender ?? user?.user_sex ?? '').toLowerCase();
    const isFemale = gender === 'female' || gender === 'f';
    if (isFemale) {
      return ['/assets/avatar/girl (1).webp', '/assets/avatar/girl (2).webp'][this._girlIdx];
    }
    return ['/assets/avatar/boy (1).webp', '/assets/avatar/boy (2).webp', '/assets/avatar/boy (3).webp'][this._boyIdx];
  }

  @action
  toggleTheme() {
    this.theme.toggle();
  }

  @action
  toggleMobileMenu() {
    this.isMobileMenuOpen = !this.isMobileMenuOpen;
    this.isProfileMenuOpen = false;
  }

  @action
  closeMobileMenu() {
    this.isMobileMenuOpen = false;
  }

  @action
  openSignIn() {
    this.isMobileMenuOpen = false;
    this.authModal.open('login');
  }

  @action
  confirmLogout() {
    this.isLogoutConfirmOpen = true;
  }

  @action
  cancelLogout() {
    this.isLogoutConfirmOpen = false;
  }

  @action
  goToOwnProfile() {
    this.isMobileMenuOpen = false;
    const ownPath = `/profile/${this.userName}`;
    if (window.location.pathname !== ownPath) {
      window.location.href = ownPath;
    }
  }

  @action
  async logout() {
    this.isLogoutConfirmOpen = false;

    // Clear all localStorage
    localStorage.clear();

    // Clear all sessionStorage
    sessionStorage.clear();

    // Clear all cookies
    document.cookie.split(';').forEach((cookie) => {
      const name = cookie.split('=')[0].trim();
      document.cookie = `${name}=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/`;
      document.cookie = `${name}=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/;domain=${window.location.hostname}`;
    });

    // Clear Cache API (service worker caches)
    if ('caches' in window) {
      const cacheNames = await caches.keys();
      await Promise.all(cacheNames.map((name) => caches.delete(name)));
    }

    await this.session.invalidate();
    this.closeMobileMenu();
  }

  <template>
    {{! ── Logout Confirmation Modal ── }}
    {{#if this.isLogoutConfirmOpen}}
      <div class="fixed inset-0 z-[100] flex items-center justify-center px-4">
        {{! Backdrop }}
        <div
          class="absolute inset-0 bg-black/50 backdrop-blur-sm"
          {{on "click" this.cancelLogout}}
        ></div>

        {{! Dialog }}
        <div class="relative z-10 bg-white dark:bg-gray-900 rounded-2xl shadow-2xl w-full max-w-sm p-6 border border-gray-200 dark:border-gray-700">
          {{! Icon }}
          <div class="w-12 h-12 mx-auto mb-4 rounded-full bg-red-100 dark:bg-red-900/30 flex items-center justify-center">
            <svg class="w-6 h-6 text-red-600 dark:text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.75">
              <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 9V5.25A2.25 2.25 0 0 0 13.5 3h-6a2.25 2.25 0 0 0-2.25 2.25v13.5A2.25 2.25 0 0 0 7.5 21h6a2.25 2.25 0 0 0 2.25-2.25V15m3 0 3-3m0 0-3-3m3 3H9"/>
            </svg>
          </div>

          <h3 class="text-center text-base font-semibold text-gray-900 dark:text-white mb-1">Log out?</h3>
          <p class="text-center text-sm text-gray-500 dark:text-gray-400 mb-6">Are you sure you want to log out?</p>

          <div class="flex gap-3">
            <button
              type="button"
              {{on "click" this.cancelLogout}}
              class="flex-1 px-4 py-2.5 rounded-xl text-sm font-medium border border-gray-200 dark:border-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
            >
              Cancel
            </button>
            <button
              type="button"
              {{on "click" this.logout}}
              class="flex-1 px-4 py-2.5 rounded-xl text-sm font-semibold bg-red-600 hover:bg-red-700 text-white transition-colors"
            >
              Log out
            </button>
          </div>
        </div>
      </div>
    {{/if}}

    <nav class="bg-white/95 dark:bg-gray-900/95 backdrop-blur-md border-b border-gray-200 dark:border-gray-700 sticky top-0 z-50 transition-colors duration-300">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between h-14 sm:h-16">

          {{! Left: Logo + Nav Links }}
          <div class="flex items-center gap-6 sm:gap-8">
            <LinkTo @route="index" class="flex items-center gap-1.5 group" {{on "click" this.closeMobileMenu}}>
              <div class="w-8 h-8 sm:w-9 sm:h-9 rounded-lg flex items-center justify-center group-hover:shadow-sm transition-shadow">
                <img width="24" height="24" src="/spord_ico.svg"/>
              </div>
              <span class="text-gray-900 dark:text-white font-bold text-lg sm:text-xl tracking-tight transition-colors duration-300">
                Spordium
              </span>
            </LinkTo>

            {{! Desktop Navigation Links }}
            <div class="hidden lg:flex items-center gap-0.5">
              <LinkTo @route="match"
                class="relative px-2.5 py-4 text-sm font-medium transition-colors
                  {{if this.isLivePage 'text-blue-600 dark:text-blue-400' 'text-gray-500 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white'}}">
                Match
                {{#if this.isLivePage}}<span class="absolute bottom-0 left-2.5 right-2.5 h-0.5 bg-blue-600 dark:bg-blue-400 rounded-full"></span>{{/if}}
              </LinkTo>
              <LinkTo @route="players"
                class="relative px-2.5 py-4 text-sm font-medium transition-colors
                  {{if this.isPlayersPage 'text-blue-600 dark:text-blue-400' 'text-gray-500 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white'}}">
                Players
                {{#if this.isPlayersPage}}<span class="absolute bottom-0 left-2.5 right-2.5 h-0.5 bg-blue-600 dark:bg-blue-400 rounded-full"></span>{{/if}}
              </LinkTo>
              <LinkTo @route="teams"
                class="relative px-2.5 py-4 text-sm font-medium transition-colors
                  {{if this.isTeamsPage 'text-blue-600 dark:text-blue-400' 'text-gray-500 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white'}}">
                Teams
                {{#if this.isTeamsPage}}<span class="absolute bottom-0 left-2.5 right-2.5 h-0.5 bg-blue-600 dark:bg-blue-400 rounded-full"></span>{{/if}}
              </LinkTo>
              <LinkTo @route="tournament"
                class="relative px-2.5 py-4 text-sm font-medium transition-colors
                  {{if this.isTournamentPage 'text-blue-600 dark:text-blue-400' 'text-gray-500 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white'}}">
                Tournament
                {{#if this.isTournamentPage}}<span class="absolute bottom-0 left-2.5 right-2.5 h-0.5 bg-blue-600 dark:bg-blue-400 rounded-full"></span>{{/if}}
              </LinkTo>
              <LinkTo @route="clubs"
                class="relative px-2.5 py-4 text-sm font-medium transition-colors
                  {{if this.isClubsPage 'text-blue-600 dark:text-blue-400' 'text-gray-500 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white'}}">
                Clubs
                {{#if this.isClubsPage}}<span class="absolute bottom-0 left-2.5 right-2.5 h-0.5 bg-blue-600 dark:bg-blue-400 rounded-full"></span>{{/if}}
              </LinkTo>
              <LinkTo @route="facilities"
                class="relative px-2.5 py-4 text-sm font-medium transition-colors
                  {{if this.isFacilitiesPage 'text-blue-600 dark:text-blue-400' 'text-gray-500 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white'}}">
                Facilities
                {{#if this.isFacilitiesPage}}<span class="absolute bottom-0 left-2.5 right-2.5 h-0.5 bg-blue-600 dark:bg-blue-400 rounded-full"></span>{{/if}}
              </LinkTo>
            </div>
          </div>

          {{! Right: Actions }}
          <div class="flex items-center gap-2">

          {{! Desktop actions }}
          <div class="hidden sm:flex items-center gap-2">

            {{! Community }}
            <a
              href="https://spordium.spordium.com/"
              target="_blank"
              rel="noopener noreferrer"
              class="p-2 rounded-full text-gray-500 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
              title="Community"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.75">
                <path stroke-linecap="round" stroke-linejoin="round" d="M18 18.72a9.094 9.094 0 0 0 3.741-.479 3 3 0 0 0-4.682-2.72m.94 3.198.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0 1 12 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 0 1 6 18.719m12 0a5.971 5.971 0 0 0-.941-3.197m0 0A5.995 5.995 0 0 0 12 12.75a5.995 5.995 0 0 0-5.058 2.772m0 0a3 3 0 0 0-4.681 2.72 8.986 8.986 0 0 0 3.74.477m.94-3.197a5.971 5.971 0 0 0-.94 3.197M15 6.75a3 3 0 1 1-6 0 3 3 0 0 1 6 0Zm6 3a2.25 2.25 0 1 1-4.5 0 2.25 2.25 0 0 1 4.5 0Zm-13.5 0a2.25 2.25 0 1 1-4.5 0 2.25 2.25 0 0 1 4.5 0Z"/>
              </svg>
            </a>

            {{#if this.session.isAuthenticated}}
              {{! ── Inline Icon Actions ── }}
              <div class="flex items-center gap-1">

                {{! Notification Bell }}
                <NotificationDropdown />

                {{! Watch Later }}
                {{!--
                <LinkTo @route="watch-later"
                  class="p-2 rounded-full transition-colors
                         {{if this.isWatchLaterPage 'text-emerald-500 bg-emerald-500/10' 'text-gray-500 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white hover:bg-gray-100 dark:hover:bg-gray-800'}}"
                  title="Watch Later"
                >
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.75">
                    <circle cx="12" cy="12" r="10" stroke-linecap="round" stroke-linejoin="round"/>
                    <polyline points="12 6 12 12 16 14" stroke-linecap="round" stroke-linejoin="round"/>
                  </svg>
                </LinkTo>
                  --}}
                {{! Profile Avatar }}
                {{#if this.userName}}
                  <button
                    type="button"
                    {{on "click" this.goToOwnProfile}}
                    class="p-0.5 rounded-full hover:ring-2 hover:ring-blue-500/40 transition-all duration-200"
                    title={{this.userName}}
                  >
                    <img
                      src={{if this.userAvatarUrl this.userAvatarUrl this.defaultAvatarUrl}}
                      alt={{this.userName}}
                      class="w-8 h-8 rounded-full object-cover ring-2 ring-blue-500/50"
                    />
                  </button>
                {{/if}}

                {{! Settings }}
                <LinkTo @route="settings"
                  class="p-2 rounded-full text-gray-500 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
                  title="Settings"
                >
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.75">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.325.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 0 1 1.37.49l1.296 2.247a1.125 1.125 0 0 1-.26 1.431l-1.003.827c-.293.241-.438.613-.43.992a7.723 7.723 0 0 1 0 .255c-.008.378.137.75.43.991l1.004.827c.424.35.534.955.26 1.43l-1.298 2.247a1.125 1.125 0 0 1-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.47 6.47 0 0 1-.22.128c-.331.183-.581.495-.644.869l-.213 1.281c-.09.543-.56.94-1.11.94h-2.594c-.55 0-1.019-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 0 1-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 0 1-1.369-.49l-1.297-2.247a1.125 1.125 0 0 1 .26-1.431l1.004-.827c.292-.24.437-.613.43-.991a6.932 6.932 0 0 1 0-.255c.007-.38-.138-.751-.43-.992l-1.004-.827a1.125 1.125 0 0 1-.26-1.43l1.297-2.247a1.125 1.125 0 0 1 1.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.086.22-.128.332-.183.582-.495.644-.869l.214-1.28Z"/>
                    <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z"/>
                  </svg>
                </LinkTo>

                {{! Logout }}
                <button type="button"
                  {{on "click" this.confirmLogout}}
                  class="p-2 rounded-full text-gray-500 dark:text-gray-400 hover:text-red-600 dark:hover:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors"
                  title="Logout"
                >
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.75">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 9V5.25A2.25 2.25 0 0 0 13.5 3h-6a2.25 2.25 0 0 0-2.25 2.25v13.5A2.25 2.25 0 0 0 7.5 21h6a2.25 2.25 0 0 0 2.25-2.25V15m3 0 3-3m0 0-3-3m3 3H9"/>
                  </svg>
                </button>

              </div>
            {{else}}
              <button
                type="button"
                {{on "click" this.toggleTheme}}
                title={{if this.theme.isDark "Switch to light mode" "Switch to dark mode"}}
                class="p-2 rounded-full text-gray-500 dark:text-gray-400
                       hover:text-gray-900 dark:hover:text-white
                       hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
              >
                {{#if this.theme.isDark}}
                  {{! Sun }}
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.75">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 3v2.25m6.364.386-1.591 1.591M21 12h-2.25m-.386 6.364-1.591-1.591M12 18.75V21m-4.773-4.227-1.591 1.591M5.25 12H3m4.227-4.773L5.636 5.636M15.75 12a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0Z"/>
                  </svg>
                {{else}}
                  {{! Moon }}
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.75">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M21.752 15.002A9.72 9.72 0 0 1 18 15.75c-5.385 0-9.75-4.365-9.75-9.75 0-1.33.266-2.597.748-3.752A9.753 9.753 0 0 0 3 11.25C3 16.635 7.365 21 12.75 21a9.753 9.753 0 0 0 9.002-5.998Z"/>
                  </svg>
                {{/if}}
              </button>
              <button
                type="button"
                {{on "click" (fn this.authModal.open "login")}}
                class="inline-flex items-center px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white text-sm font-medium rounded-lg transition-colors shadow-sm"
              >
                Sign In
              </button>
            {{/if}}
          </div>

            {{! Mobile Hamburger }}
            <button
              type="button"
              class="sm:hidden p-2 rounded-lg text-gray-500 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
              {{on "click" this.toggleMobileMenu}}
            >
              {{#if this.isMobileMenuOpen}}
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              {{else}}
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/>
                </svg>
              {{/if}}
            </button>

          </div>{{! end right }}
        </div>{{! end flex }}
      </div>

      {{! Mobile Menu Dropdown }}
      {{#if this.isMobileMenuOpen}}
        <div class="sm:hidden border-t border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900">

          {{! Nav Links }}
          <div class="px-3 pt-3 pb-2 space-y-0.5">
            <p class="px-3 pb-1.5 text-[10px] font-semibold uppercase tracking-widest text-gray-400 dark:text-gray-500">Navigation</p>

            <LinkTo @route="match" {{on "click" this.closeMobileMenu}}
              class="flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all
                {{if this.isLivePage 'bg-blue-50 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400' 'text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800/60 hover:text-gray-900 dark:hover:text-white'}}">
              <div class="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0
                {{if this.isLivePage 'bg-blue-100 dark:bg-blue-800/50 text-blue-600 dark:text-blue-400' 'bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400'}}">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.75">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M5.25 5.653c0-.856.917-1.398 1.667-.986l11.54 6.347a1.125 1.125 0 0 1 0 1.972l-11.54 6.347a1.125 1.125 0 0 1-1.667-.986V5.653Z"/>
                </svg>
              </div>
              Match
              <span class="ml-auto inline-flex items-center gap-1 text-[10px] font-semibold text-red-500 dark:text-red-400 bg-red-50 dark:bg-red-900/30 px-1.5 py-0.5 rounded-full">
                <span class="w-1.5 h-1.5 rounded-full bg-red-500 dark:bg-red-400 animate-pulse"></span>
                LIVE
              </span>
            </LinkTo>

            <LinkTo @route="players" {{on "click" this.closeMobileMenu}}
              class="flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all
                {{if this.isPlayersPage 'bg-blue-50 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400' 'text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800/60 hover:text-gray-900 dark:hover:text-white'}}">
              <div class="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0
                {{if this.isPlayersPage 'bg-blue-100 dark:bg-blue-800/50 text-blue-600 dark:text-blue-400' 'bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400'}}">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.75">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z"/>
                </svg>
              </div>
              Players
            </LinkTo>

            <LinkTo @route="teams" {{on "click" this.closeMobileMenu}}
              class="flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all
                {{if this.isTeamsPage 'bg-blue-50 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400' 'text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800/60 hover:text-gray-900 dark:hover:text-white'}}">
              <div class="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0
                {{if this.isTeamsPage 'bg-blue-100 dark:bg-blue-800/50 text-blue-600 dark:text-blue-400' 'bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400'}}">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.75">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M18 18.72a9.094 9.094 0 0 0 3.741-.479 3 3 0 0 0-4.682-2.72m.94 3.198.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0 1 12 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 0 1 6 18.719m12 0a5.971 5.971 0 0 0-.941-3.197m0 0A5.995 5.995 0 0 0 12 12.75a5.995 5.995 0 0 0-5.058 2.772m0 0a3 3 0 0 0-4.681 2.72 8.986 8.986 0 0 0 3.74.477m.94-3.197a5.971 5.971 0 0 0-.94 3.197M15 6.75a3 3 0 1 1-6 0 3 3 0 0 1 6 0Zm6 3a2.25 2.25 0 1 1-4.5 0 2.25 2.25 0 0 1 4.5 0Zm-13.5 0a2.25 2.25 0 1 1-4.5 0 2.25 2.25 0 0 1 4.5 0Z"/>
                </svg>
              </div>
              Teams
            </LinkTo>

            <LinkTo @route="tournament" {{on "click" this.closeMobileMenu}}
              class="flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all
                {{if this.isTournamentPage 'bg-blue-50 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400' 'text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800/60 hover:text-gray-900 dark:hover:text-white'}}">
              <div class="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0
                {{if this.isTournamentPage 'bg-blue-100 dark:bg-blue-800/50 text-blue-600 dark:text-blue-400' 'bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400'}}">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.75">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 18.75h-9m9 0a3 3 0 0 1 3 3h-15a3 3 0 0 1 3-3m9 0v-3.375c0-.621-.503-1.125-1.125-1.125h-.871M7.5 18.75v-3.375c0-.621.504-1.125 1.125-1.125h.872m5.007 0H9.497m5.007 0a7.454 7.454 0 0 1-.982-3.172M9.497 14.25a7.454 7.454 0 0 0 .981-3.172M5.25 4.236c-.982.143-1.954.317-2.916.52A6.003 6.003 0 0 0 7.73 9.728M5.25 4.236V4.5c0 2.108.966 3.99 2.48 5.228M5.25 4.236V2.721C7.456 2.41 9.71 2.25 12 2.25c2.291 0 4.545.16 6.75.47v1.516M7.73 9.728a6.726 6.726 0 0 0 2.748 1.35m8.272-6.842V4.5c0 2.108-.966 3.99-2.48 5.228m2.48-5.492a46.32 46.32 0 0 1 2.916.52 6.003 6.003 0 0 1-5.395 4.972m0 0a6.726 6.726 0 0 1-2.749 1.35m0 0a6.772 6.772 0 0 1-3.044 0"/>
                </svg>
              </div>
              Tournament
            </LinkTo>

            <LinkTo @route="clubs" {{on "click" this.closeMobileMenu}}
              class="flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all
                {{if this.isClubsPage 'bg-blue-50 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400' 'text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800/60 hover:text-gray-900 dark:hover:text-white'}}">
              <div class="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0
                {{if this.isClubsPage 'bg-blue-100 dark:bg-blue-800/50 text-blue-600 dark:text-blue-400' 'bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400'}}">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.75">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 21h16.5M4.5 3h15M5.25 3v18m13.5-18v18M9 6.75h1.5m-1.5 3h1.5m-1.5 3h1.5m3-6H15m-1.5 3H15m-1.5 3H15M9 21v-3.375c0-.621.504-1.125 1.125-1.125h3.75c.621 0 1.125.504 1.125 1.125V21"/>
                </svg>
              </div>
              Clubs
            </LinkTo>

            <LinkTo @route="facilities" {{on "click" this.closeMobileMenu}}
              class="flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all
                {{if this.isFacilitiesPage 'bg-blue-50 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400' 'text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800/60 hover:text-gray-900 dark:hover:text-white'}}">
              <div class="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0
                {{if this.isFacilitiesPage 'bg-blue-100 dark:bg-blue-800/50 text-blue-600 dark:text-blue-400' 'bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400'}}">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.75">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 21h19.5m-18-18v18m10.5-18v18m6-13.5V21M6.75 6.75h.75m-.75 3h.75m-.75 3h.75m3-6h.75m-.75 3h.75m-.75 3h.75M6.75 21v-3.375c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21M3 3h12m-.75 4.5H21m-3.75 3.75h.008v.008h-.008v-.008Zm0 3h.008v.008h-.008v-.008Zm0 3h.008v.008h-.008v-.008Z"/>
                </svg>
              </div>
              Facilities
            </LinkTo>

            <a
              href="https://spordium.spordium.com/"
              target="_blank"
              rel="noopener noreferrer"
              {{on "click" this.closeMobileMenu}}
              class="flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800/60 hover:text-gray-900 dark:hover:text-white">
              <div class="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0 bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.75">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M18 18.72a9.094 9.094 0 0 0 3.741-.479 3 3 0 0 0-4.682-2.72m.94 3.198.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0 1 12 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 0 1 6 18.719m12 0a5.971 5.971 0 0 0-.941-3.197m0 0A5.995 5.995 0 0 0 12 12.75a5.995 5.995 0 0 0-5.058 2.772m0 0a3 3 0 0 0-4.681 2.72 8.986 8.986 0 0 0 3.74.477m.94-3.197a5.971 5.971 0 0 0-.94 3.197M15 6.75a3 3 0 1 1-6 0 3 3 0 0 1 6 0Zm6 3a2.25 2.25 0 1 1-4.5 0 2.25 2.25 0 0 1 4.5 0Zm-13.5 0a2.25 2.25 0 1 1-4.5 0 2.25 2.25 0 0 1 4.5 0Z"/>
                </svg>
              </div>
              Community
            </a>
          </div>

          {{! Divider }}
          <div class="mx-4 border-t border-gray-100 dark:border-gray-800"></div>

          {{! Auth Section }}
          <div class="px-3 py-3">
            {{#if this.session.isAuthenticated}}

              {{! Profile Card — clickable → profile page }}
              {{#if this.userName}}
                <button type="button" {{on "click" this.goToOwnProfile}}
                  class="w-full block mb-3 p-3 rounded-2xl bg-gradient-to-br from-blue-50 to-indigo-50 dark:from-blue-900/20 dark:to-indigo-900/20 border border-blue-100 dark:border-blue-800/30 hover:border-blue-300 dark:hover:border-blue-600/50 transition-colors text-left">
                  <div class="flex items-center gap-3">
                    <img
                      src={{if this.userAvatarUrl this.userAvatarUrl this.defaultAvatarUrl}}
                      alt={{this.userName}}
                      class="w-12 h-12 rounded-xl object-cover ring-2 ring-blue-500/30 shadow-sm flex-shrink-0"
                    />
                    <div class="flex-1 min-w-0">
                      <p class="text-sm font-semibold text-gray-900 dark:text-white truncate">{{this.userName}}</p>
                      <p class="text-xs text-gray-500 dark:text-gray-400 truncate">{{this.userEmail}}</p>
                    </div>
                    <svg class="w-4 h-4 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5"/>
                    </svg>
                  </div>
                </button>
              {{/if}}

              {{! Quick actions 2×2 grid }}
              <div class="grid grid-cols-2 gap-2 mb-3">

                {{! Notifications }}
                <div class="flex flex-col items-center gap-0.5 pt-2 pb-1.5 rounded-xl bg-gray-50 dark:bg-gray-800 relative">
                  <NotificationDropdown />
                  <span class="text-[10px] font-medium text-gray-500 dark:text-gray-400">Alerts</span>
                </div>

                {{! Watch Later }}
                <LinkTo @route="watch-later" {{on "click" this.closeMobileMenu}}
                  class="flex flex-col items-center gap-1 py-2.5 rounded-xl bg-gray-50 dark:bg-gray-800 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors no-underline">
                  <svg class="w-5 h-5 text-gray-500 dark:text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.75">
                    <circle cx="12" cy="12" r="10" stroke-linecap="round" stroke-linejoin="round"/>
                    <polyline points="12 6 12 12 16 14" stroke-linecap="round" stroke-linejoin="round"/>
                  </svg>
                  <span class="text-[10px] font-medium text-gray-500 dark:text-gray-400">Watch Later</span>
                </LinkTo>

                {{! Settings }}
                <LinkTo @route="settings" {{on "click" this.closeMobileMenu}}
                  class="flex flex-col items-center gap-1 py-2.5 rounded-xl bg-gray-50 dark:bg-gray-800 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors no-underline">
                  <svg class="w-5 h-5 text-gray-500 dark:text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.75">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.325.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 0 1 1.37.49l1.296 2.247a1.125 1.125 0 0 1-.26 1.431l-1.003.827c-.293.241-.438.613-.43.992a7.723 7.723 0 0 1 0 .255c-.008.378.137.75.43.991l1.004.827c.424.35.534.955.26 1.43l-1.298 2.247a1.125 1.125 0 0 1-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.47 6.47 0 0 1-.22.128c-.331.183-.581.495-.644.869l-.213 1.281c-.09.543-.56.94-1.11.94h-2.594c-.55 0-1.019-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 0 1-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 0 1-1.369-.49l-1.297-2.247a1.125 1.125 0 0 1 .26-1.431l1.004-.827c.292-.24.437-.613.43-.991a6.932 6.932 0 0 1 0-.255c.007-.38-.138-.751-.43-.992l-1.004-.827a1.125 1.125 0 0 1-.26-1.43l1.297-2.247a1.125 1.125 0 0 1 1.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.086.22-.128.332-.183.582-.495.644-.869l.214-1.28Z"/>
                    <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z"/>
                  </svg>
                  <span class="text-[10px] font-medium text-gray-500 dark:text-gray-400">Settings</span>
                </LinkTo>

                {{! Theme toggle }}
                <button type="button" {{on "click" this.toggleTheme}}
                  class="flex flex-col items-center gap-1 py-2.5 rounded-xl bg-gray-50 dark:bg-gray-800 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors">
                  {{#if this.theme.isDark}}
                    <svg class="w-5 h-5 text-amber-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.75">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M12 3v2.25m6.364.386-1.591 1.591M21 12h-2.25m-.386 6.364-1.591-1.591M12 18.75V21m-4.773-4.227-1.591 1.591M5.25 12H3m4.227-4.773L5.636 5.636M15.75 12a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0Z"/>
                    </svg>
                    <span class="text-[10px] font-medium text-gray-500 dark:text-gray-400">Light Mode</span>
                  {{else}}
                    <svg class="w-5 h-5 text-indigo-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.75">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M21.752 15.002A9.72 9.72 0 0 1 18 15.75c-5.385 0-9.75-4.365-9.75-9.75 0-1.33.266-2.597.748-3.752A9.753 9.753 0 0 0 3 11.25C3 16.635 7.365 21 12.75 21a9.753 9.753 0 0 0 9.002-5.998Z"/>
                    </svg>
                    <span class="text-[10px] font-medium text-gray-500 dark:text-gray-400">Dark Mode</span>
                  {{/if}}
                </button>

              </div>

              {{! Logout }}
              <button type="button" {{on "click" this.confirmLogout}}
                class="w-full flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl text-sm font-medium text-red-600 dark:text-red-400 border border-red-200 dark:border-red-800/40 hover:bg-red-50 dark:hover:bg-red-900/20 transition-all">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.75">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 9V5.25A2.25 2.25 0 0 0 13.5 3h-6a2.25 2.25 0 0 0-2.25 2.25v13.5A2.25 2.25 0 0 0 7.5 21h6a2.25 2.25 0 0 0 2.25-2.25V15m3 0 3-3m0 0-3-3m3 3H9"/>
                </svg>
                Logout
              </button>

            {{else}}

              {{! Guest state }}
              <div class="flex flex-col gap-2">
                <button type="button" {{on "click" this.openSignIn}}
                  class="w-full flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl text-sm font-semibold bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 text-white shadow-sm transition-all">
                  Sign In
                </button>
                <button type="button" {{on "click" this.toggleTheme}}
                  class="w-full flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl text-sm font-medium
                         border border-gray-200 dark:border-gray-700
                         text-gray-700 dark:text-gray-300
                         hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                  {{#if this.theme.isDark}}
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.75">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M12 3v2.25m6.364.386-1.591 1.591M21 12h-2.25m-.386 6.364-1.591-1.591M12 18.75V21m-4.773-4.227-1.591 1.591M5.25 12H3m4.227-4.773L5.636 5.636M15.75 12a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0Z"/>
                    </svg>
                    Switch to Light Mode
                  {{else}}
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.75">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M21.752 15.002A9.72 9.72 0 0 1 18 15.75c-5.385 0-9.75-4.365-9.75-9.75 0-1.33.266-2.597.748-3.752A9.753 9.753 0 0 0 3 11.25C3 16.635 7.365 21 12.75 21a9.753 9.753 0 0 0 9.002-5.998Z"/>
                    </svg>
                    Switch to Dark Mode
                  {{/if}}
                </button>
              </div>

            {{/if}}
          </div>

          <div class="h-2"></div>
        </div>
      {{/if}}
    </nav>
  </template>
}
