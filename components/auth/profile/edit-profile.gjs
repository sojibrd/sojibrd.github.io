import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { on } from '@ember/modifier';
import { or, eq, not } from 'ember-truth-helpers';
import { service } from '@ember/service';
import { Input, Textarea } from '@ember/component';
import { action } from '@ember/object';
import { fn } from '@ember/helper';
import LocationPicker from 'spordium/components/auth/signup/LocationPicker';
import lucideIcon from 'spordium/helpers/lucide-icon';

const BODY_TYPES = [
  { value: 'Slim', label: 'Slim' },
  { value: 'Athletic', label: 'Athletic' },
  { value: 'Average', label: 'Average' },
  { value: 'Heavy', label: 'Heavy' },
];

export default class EditProfileComponent extends Component {
  @service('platform-settings') platformSettings;
  @service api;
  @service session;

  @tracked usernameStatus = 'idle'; // idle | checking | available | taken | error

  _usernameTimer = null;
  _originalUsername = null;

  constructor() {
    super(...arguments);
    this._originalUsername = this.args.profile?.user_username ?? null;
  }

  willDestroy() {
    super.willDestroy(...arguments);
    clearTimeout(this._usernameTimer);
  }

  get interestedSportsString() {
    return (
      this.args.profile.user_interested_sports?.all_sports?.join(', ') ?? ''
    );
  }

  set interestedSportsString(value) {
    const sports = value
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
    this.args.profile.set('user_interested_sports', { all_sports: sports });
  }

  get educationInfo() {
    return this.args.profile.user_life_history;
  }

  get bodyTypes() {
    return BODY_TYPES;
  }

  get canSubmit() {
    return this.usernameStatus === 'idle' || this.usernameStatus === 'available';
  }

  @action
  updateUsername(event) {
    const sanitized = event.target.value.toLowerCase().replace(/[^a-z0-9]/g, '');
    event.target.value = sanitized;
    this.args.profile.set('user_username', sanitized);
    clearTimeout(this._usernameTimer);
    if (!sanitized || sanitized === this._originalUsername) {
      this.usernameStatus = 'idle';
      return;
    }
    this.usernameStatus = 'checking';
    this._usernameTimer = setTimeout(() => {
      this.checkUsernameAvailability(sanitized);
    }, 300);
  }

  async checkUsernameAvailability(username) {
    try {
      const data = await this.api.get(`/auth_user/check_username/${username}/`);
      if (this.args.profile.user_username !== username) return;
      this.usernameStatus = data?.data?.exist === false ? 'available' : 'taken';
    } catch {
      if (this.args.profile.user_username === username) {
        this.usernameStatus = 'error';
      }
    }
  }

  @action
  handleSubmit(event) {
    event.preventDefault();
    if (!this.canSubmit) return;
    this.args.onSave(event);
  }

  @action
  updateBodyType(event) {
    const config = this.args.profile.user_configuration || {};
    this.args.profile.set('user_configuration', { ...config, body_type: event.target.value });
  }

  get settings() {
    return this.platformSettings.settings;
  }

  @action
  updateFullName(key, event) {
    const fullname = this.args.profile.user_fullname || {};
    const newFullname = { ...fullname, [key]: event.target.value };
    this.args.profile.set('user_fullname', newFullname);
  }

  @action
  updateConfig(key, event) {
    const config = this.args.profile.user_configuration || {};
    const newConfig = { ...config, [key]: event.target.value };
    this.args.profile.set('user_configuration', newConfig);
  }

  @action
  updateLifeHistory(key, event) {
    const lifeHistory = this.args.profile.user_life_history || {};
    const newLifeHistory = { ...lifeHistory, [key]: event.target.value };
    this.args.profile.set('user_life_history', newLifeHistory);
  }

  @action
  updateGender(event) {
    this.args.profile.set('user_sex', event.target.value);
  }

  @action
  handleLocationSelect(location) {
    this.args.profile.set('address', location.address);
  }

  @action
  addJob() {
    const lifeHistory = this.args.profile.user_life_history || {};
    const jobs = lifeHistory.job ? [...lifeHistory.job] : [];
    jobs.push({
      id: crypto.randomUUID(),
      job_name: '',
      'job-start-at': '',
      'job-end-at': '',
    });
    const newLifeHistory = { ...lifeHistory, job: jobs };
    this.args.profile.set('user_life_history', newLifeHistory);
  }

  @action
  updateJob(index, key, event) {
    const lifeHistory = this.args.profile.user_life_history || {};
    const jobs = lifeHistory.job || [];
    const newJobs = jobs.map((job, i) => (i === index ? { ...job, [key]: event.target.value } : job));
    this.args.profile.set('user_life_history', { ...lifeHistory, job: newJobs });
  }

  @action
  removeJob(jobToRemove) {
    const lifeHistory = this.args.profile.user_life_history || {};
    const jobs = lifeHistory.job || [];
    this.args.profile.set('user_life_history', { ...lifeHistory, job: jobs.filter(job => job !== jobToRemove) });
  }

  <template>
    <div class="overflow-hidden rounded-3xl bg-gray-950 shadow-2xl ring-1 ring-white/10">

      {{! ── Header ── }}
      <div class="relative overflow-hidden px-4 py-5 sm:px-8 sm:py-7 border-b border-white/10">
        <div class="absolute inset-0 bg-gradient-to-r from-indigo-600/20 via-violet-600/10 to-transparent pointer-events-none"></div>
        <div class="absolute inset-0 opacity-5" style="background-image: radial-gradient(circle, white 1px, transparent 1px); background-size: 28px 28px;"></div>
        <div class="relative flex items-center gap-4">
          <div class="flex items-center justify-center w-11 h-11 rounded-2xl bg-indigo-600/20 border border-indigo-500/30 shrink-0">
            <svg class="w-5 h-5 text-indigo-400" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931z"/>
            </svg>
          </div>
          <div>
            <h2 class="text-xl font-extrabold tracking-tight text-white">Edit Profile</h2>
            <p class="text-xs text-gray-400 mt-0.5">Update your personal details and preferences</p>
          </div>
        </div>
      </div>
  
      <form {{on "submit" this.handleSubmit}} class="divide-y divide-white/5">

        {{! ════ PERSONAL INFORMATION ════ }}
        <div class="grid grid-cols-1 gap-y-5 px-4 py-6 sm:px-6 sm:gap-y-6 md:px-8 md:py-8 md:grid-cols-3 md:gap-x-10">
          <div class="space-y-1.5">
            <div class="flex items-center gap-2">
              <span class="flex items-center justify-center w-7 h-7 rounded-lg bg-blue-500/15 border border-blue-500/25 text-sm">👤</span>
              <h3 class="text-sm font-bold text-white uppercase tracking-widest">Personal Info</h3>
            </div>
            <p class="text-xs text-gray-500 pl-9">Basic details about you.</p>
          </div>

          <div class="grid grid-cols-1 gap-4 md:col-span-2 sm:grid-cols-6">

            <div class="sm:col-span-3 space-y-1.5">
              <label for="firstName" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider">First Name</label>
              <input
                type="text" name="firstName" id="firstName"
                value={{@profile.user_fullname.first_name}}
                class="w-full bg-gray-800/60 border border-gray-700 hover:border-gray-600 rounded-xl px-4 py-2.5 text-sm text-white placeholder-gray-500 focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 focus:outline-none transition-colors"
                {{on "input" (fn this.updateFullName "first_name")}}
              />
            </div>

            <div class="sm:col-span-3 space-y-1.5">
              <label for="lastName" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider">Last Name</label>
              <input
                type="text" name="lastName" id="lastName"
                value={{@profile.user_fullname.last_name}}
                class="w-full bg-gray-800/60 border border-gray-700 hover:border-gray-600 rounded-xl px-4 py-2.5 text-sm text-white placeholder-gray-500 focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 focus:outline-none transition-colors"
                {{on "input" (fn this.updateFullName "last_name")}}
              />
            </div>

            <div class="sm:col-span-3 space-y-1.5">
              <label for="username" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider">Username</label>
              <div class="relative">
                <input
                  type="text" name="username" id="username"
                  value={{@profile.user_username}}
                  class="w-full bg-gray-800/60 border {{if (eq this.usernameStatus 'taken') 'border-red-500 focus:border-red-500 focus:ring-red-500' (if (eq this.usernameStatus 'available') 'border-green-500 focus:border-green-500 focus:ring-green-500' 'border-gray-700 focus:border-indigo-500 focus:ring-indigo-500')}} hover:border-gray-600 rounded-xl px-4 py-2.5 pr-10 text-sm text-white placeholder-gray-500 focus:ring-1 focus:outline-none transition-colors"
                  {{on "input" this.updateUsername}}
                />
                {{#if (eq this.usernameStatus 'checking')}}
                  <span class="absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none">
                    <svg class="w-4 h-4 text-gray-400 animate-spin" fill="none" viewBox="0 0 24 24">
                      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
                      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8z"/>
                    </svg>
                  </span>
                {{else if (eq this.usernameStatus 'available')}}
                  <span class="absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none">
                    <svg class="w-4 h-4 text-green-400" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/>
                    </svg>
                  </span>
                {{else if (eq this.usernameStatus 'taken')}}
                  <span class="absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none">
                    <svg class="w-4 h-4 text-red-400" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
                    </svg>
                  </span>
                {{else if (eq this.usernameStatus 'error')}}
                  <span class="absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none">
                    <svg class="w-4 h-4 text-yellow-400" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z"/>
                    </svg>
                  </span>
                {{/if}}
              </div>
              {{#if (eq this.usernameStatus 'taken')}}
                <p class="text-xs text-red-400">Username already taken</p>
              {{else if (eq this.usernameStatus 'available')}}
                <p class="text-xs text-green-400">Username available</p>
              {{else if (eq this.usernameStatus 'error')}}
                <p class="text-xs text-yellow-400">Could not verify availability</p>
              {{/if}}
            </div>

            <div class="sm:col-span-3 space-y-1.5">
              <label for="email" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider">Email</label>
              <Input
                id="email" name="email" @type="email"
                @value={{@profile.user_email}}
                class="w-full bg-gray-800/60 border border-gray-700 hover:border-gray-600 rounded-xl px-4 py-2.5 text-sm text-white placeholder-gray-500 focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 focus:outline-none transition-colors"
              />
            </div>

            <div class="sm:col-span-3 space-y-1.5">
              <label for="phone" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider">Phone</label>
              <Input
                id="phone" name="phone" @type="tel"
                @value={{@profile.user_callphone}}
                class="w-full bg-gray-800/60 border border-gray-700 hover:border-gray-600 rounded-xl px-4 py-2.5 text-sm text-white placeholder-gray-500 focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 focus:outline-none transition-colors"
              />
            </div>

            <div class="sm:col-span-3 space-y-1.5">
              <label for="gender" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider">Gender</label>
              <select
                id="gender" name="gender"
                class="w-full bg-gray-800/60 border border-gray-700 hover:border-gray-600 rounded-xl px-4 py-2.5 text-sm text-white appearance-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 focus:outline-none transition-colors"
                {{on "change" this.updateGender}}
              >
                <option value="male"   selected={{eq @profile.user_sex "male"}}   class="bg-gray-800">Male</option>
                <option value="female" selected={{eq @profile.user_sex "female"}} class="bg-gray-800">Female</option>
                <option value="other"  selected={{eq @profile.user_sex "other"}}  class="bg-gray-800">Other</option>
              </select>
            </div>

            <div class="sm:col-span-3 space-y-1.5">
              <label for="dob" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider">Date of Birth</label>
              <Input
                @type="date" name="dob" id="dob"
                @value={{@profile.user_dob}}
                class="w-full bg-gray-800/60 border border-gray-700 hover:border-gray-600 rounded-xl px-4 py-2.5 text-sm text-white focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 focus:outline-none transition-colors"
              />
            </div>


          </div>
        </div>

        {{! ════ PHYSICAL ATTRIBUTES ════ }}
        <div class="grid grid-cols-1 gap-y-5 px-4 py-6 sm:px-6 sm:gap-y-6 md:px-8 md:py-8 md:grid-cols-3 md:gap-x-10">
          <div class="space-y-1.5">
            <div class="flex items-center gap-2">
              <span class="flex items-center justify-center w-7 h-7 rounded-lg bg-emerald-500/15 border border-emerald-500/25 text-sm">💪</span>
              <h3 class="text-sm font-bold text-white uppercase tracking-widest">Physical</h3>
            </div>
            <p class="text-xs text-gray-500 pl-9">Measurements and body type.</p>
          </div>

          <div class="grid grid-cols-1 gap-4 md:col-span-2 sm:grid-cols-6">

            <div class="sm:col-span-2 space-y-1.5">
              <label for="bodyType" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider">Body Type</label>
              <div class="relative group">
                <select
                  id="bodyType" name="bodyType"
                  class="w-full appearance-none bg-gray-800/60 border border-gray-700 hover:border-indigo-500/70 group-hover:border-indigo-500/70 rounded-xl px-4 py-2.5 pr-10 text-sm focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 focus:outline-none transition-all cursor-pointer
                         {{if @profile.user_configuration.body_type 'text-white' 'text-gray-500'}}"
                  {{on "change" this.updateBodyType}}
                >
                  <option value="" disabled selected={{not @profile.user_configuration.body_type}} class="bg-gray-900 text-gray-400">Select body type</option>
                  {{#each this.bodyTypes as |bt|}}
                    <option value={{bt.value}} selected={{eq @profile.user_configuration.body_type bt.value}} class="bg-gray-900 text-white">{{bt.label}}</option>
                  {{/each}}
                </select>
                <div class="pointer-events-none absolute inset-y-0 right-0 flex items-center pr-3 text-gray-500 group-hover:text-indigo-400 transition-colors">
                  {{lucideIcon "chevrons-up-down" size=14}}
                </div>
              </div>
            </div>

            <div class="sm:col-span-2 space-y-1.5">
              <label for="height" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider">Height</label>
              <div class="flex rounded-xl overflow-hidden border border-gray-700 focus-within:border-indigo-500 focus-within:ring-1 focus-within:ring-indigo-500 transition-colors">
                <input
                  type="number" name="height" id="height"
                  value={{@profile.user_configuration.height}}
                  class="flex-1 bg-gray-800/60 text-white px-4 py-2.5 text-sm focus:outline-none min-w-0"
                  {{on "input" (fn this.updateConfig "height")}}
                />
                <select
                  name="heightUnit"
                  class="bg-gray-700 text-gray-300 px-3 text-sm border-l border-gray-600 focus:outline-none shrink-0"
                  {{on "change" (fn this.updateConfig "height_unit")}}
                >
                  {{#if this.settings.height_unit}}
                    {{#each this.settings.height_unit as |unit|}}
                      <option value={{unit}} selected={{eq @profile.user_configuration.height_unit unit}} class="bg-gray-800">{{unit}}</option>
                    {{/each}}
                  {{/if}}
                </select>
              </div>
            </div>

            <div class="sm:col-span-2 space-y-1.5">
              <label for="weight" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider">Weight</label>
              <div class="flex rounded-xl overflow-hidden border border-gray-700 focus-within:border-indigo-500 focus-within:ring-1 focus-within:ring-indigo-500 transition-colors">
                <input
                  type="number" name="weight" id="weight"
                  value={{@profile.user_configuration.weight}}
                  class="flex-1 bg-gray-800/60 text-white px-4 py-2.5 text-sm focus:outline-none min-w-0"
                  {{on "input" (fn this.updateConfig "weight")}}
                />
                <select
                  name="weightUnit"
                  class="bg-gray-700 text-gray-300 px-3 text-sm border-l border-gray-600 focus:outline-none shrink-0"
                  {{on "change" (fn this.updateConfig "weight_unit")}}
                >
                  {{#if this.settings.weight_unit}}
                    {{#each this.settings.weight_unit as |unit|}}
                      <option value={{unit}} selected={{eq @profile.user_configuration.weight_unit unit}} class="bg-gray-800">{{unit}}</option>
                    {{/each}}
                  {{/if}}
                </select>
              </div>
            </div>

          </div>
        </div>

        {{! ════ LOCATION ════ }}
        <div class="grid grid-cols-1 gap-y-5 px-4 py-6 sm:px-6 sm:gap-y-6 md:px-8 md:py-8 md:grid-cols-3 md:gap-x-10">
          <div class="space-y-1.5">
            <div class="flex items-center gap-2">
              <span class="flex items-center justify-center w-7 h-7 rounded-lg bg-rose-500/15 border border-rose-500/25 text-sm">📍</span>
              <h3 class="text-sm font-bold text-white uppercase tracking-widest">Location</h3>
            </div>
            <p class="text-xs text-gray-500 pl-9">Your primary address.</p>
          </div>
          <div class="md:col-span-2 space-y-3">
            <div class="space-y-1.5">
              <label for="address" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider">Address</label>
              <Textarea
                id="address" name="address" rows="3"
                @value={{@profile.address}}
                class="w-full bg-gray-800/60 border border-gray-700 hover:border-gray-600 rounded-xl px-4 py-2.5 text-sm text-white placeholder-gray-500 focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 focus:outline-none transition-colors resize-none"
              />
            </div>
            <div class="flex items-center gap-2">
              <LocationPicker @onSelect={{this.handleLocationSelect}} />
              <span class="text-xs text-gray-500">Pick location from map to auto-fill address</span>
            </div>
          </div>
        </div>

        {{! ════ SPORTS ════ }}
        <div class="grid grid-cols-1 gap-y-5 px-4 py-6 sm:px-6 sm:gap-y-6 md:px-8 md:py-8 md:grid-cols-3 md:gap-x-10">
          <div class="space-y-1.5">
            <div class="flex items-center gap-2">
              <span class="flex items-center justify-center w-7 h-7 rounded-lg bg-amber-500/15 border border-amber-500/25 text-sm">🏅</span>
              <h3 class="text-sm font-bold text-white uppercase tracking-widest">Sports</h3>
            </div>
            <p class="text-xs text-gray-500 pl-9">Sports you are interested in.</p>
          </div>
          <div class="md:col-span-2 space-y-1.5">
            <label for="interestedSports" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider">Interested Sports <span class="normal-case text-gray-500 font-normal">(comma-separated)</span></label>
            <textarea
              id="interestedSports" name="interestedSports" rows="2"
              value={{this.interestedSportsString}}
              class="w-full bg-gray-800/60 border border-gray-700 hover:border-gray-600 rounded-xl px-4 py-2.5 text-sm text-white placeholder-gray-500 focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 focus:outline-none transition-colors resize-none"
            />
          </div>
        </div>

        {{! ════ EDUCATION ════ }}
        <div class="grid grid-cols-1 gap-y-5 px-4 py-6 sm:px-6 sm:gap-y-6 md:px-8 md:py-8 md:grid-cols-3 md:gap-x-10">
          <div class="space-y-1.5">
            <div class="flex items-center gap-2">
              <span class="flex items-center justify-center w-7 h-7 rounded-lg bg-sky-500/15 border border-sky-500/25 text-sm">🎓</span>
              <h3 class="text-sm font-bold text-white uppercase tracking-widest">Education</h3>
            </div>
            <p class="text-xs text-gray-500 pl-9">Your educational background.</p>
          </div>

          <div class="space-y-6 md:col-span-2">

            {{! School }}
            <div class="rounded-2xl bg-gray-800/40 border border-white/5 p-5 space-y-4">
              <p class="text-[10px] font-bold uppercase tracking-widest text-sky-400">🏫 School</p>
              <div class="grid grid-cols-1 gap-4 sm:grid-cols-6">
                <div class="sm:col-span-6 space-y-1.5">
                  <label for="schoolName" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider">Name</label>
                  <input type="text" name="schoolName" id="schoolName" value={{@profile.user_life_history.school_name}} placeholder="e.g. Springfield High School"
                    class="w-full bg-gray-900/60 border border-gray-700 hover:border-gray-600 rounded-xl px-4 py-2.5 text-sm text-white placeholder-gray-500 focus:border-sky-500 focus:ring-1 focus:ring-sky-500 focus:outline-none transition-colors"
                    {{on "input" (fn this.updateLifeHistory "school_name")}}/>
                </div>
                <div class="sm:col-span-3 space-y-1.5">
                  <label for="schoolStartDate" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider">Start</label>
                  <input type="date" name="schoolStartDate" id="schoolStartDate" value={{@profile.user_life_history.school_start_date}}
                    class="w-full bg-gray-900/60 border border-gray-700 hover:border-gray-600 rounded-xl px-4 py-2.5 text-sm text-white focus:border-sky-500 focus:ring-1 focus:ring-sky-500 focus:outline-none transition-colors"
                    {{on "input" (fn this.updateLifeHistory "school_start_date")}}/>
                </div>
                <div class="sm:col-span-3 space-y-1.5">
                  <label for="schoolEndDate" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider">End</label>
                  <input type="date" name="schoolEndDate" id="schoolEndDate" value={{@profile.user_life_history.school_end_date}}
                    class="w-full bg-gray-900/60 border border-gray-700 hover:border-gray-600 rounded-xl px-4 py-2.5 text-sm text-white focus:border-sky-500 focus:ring-1 focus:ring-sky-500 focus:outline-none transition-colors"
                    {{on "input" (fn this.updateLifeHistory "school_end_date")}}/>
                </div>
              </div>
            </div>

            {{! College }}
            <div class="rounded-2xl bg-gray-800/40 border border-white/5 p-5 space-y-4">
              <p class="text-[10px] font-bold uppercase tracking-widest text-indigo-400">🏛️ College</p>
              <div class="grid grid-cols-1 gap-4 sm:grid-cols-6">
                <div class="sm:col-span-6 space-y-1.5">
                  <label for="collegeName" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider">Name</label>
                  <input type="text" name="collegeName" id="collegeName" value={{@profile.user_life_history.college_name}} placeholder="e.g. Springfield Community College"
                    class="w-full bg-gray-900/60 border border-gray-700 hover:border-gray-600 rounded-xl px-4 py-2.5 text-sm text-white placeholder-gray-500 focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 focus:outline-none transition-colors"
                    {{on "input" (fn this.updateLifeHistory "college_name")}}/>
                </div>
                <div class="sm:col-span-3 space-y-1.5">
                  <label for="collegeStartDate" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider">Start</label>
                  <input type="date" name="collegeStartDate" id="collegeStartDate" value={{@profile.user_life_history.college_start_date}}
                    class="w-full bg-gray-900/60 border border-gray-700 hover:border-gray-600 rounded-xl px-4 py-2.5 text-sm text-white focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 focus:outline-none transition-colors"
                    {{on "input" (fn this.updateLifeHistory "college_start_date")}}/>
                </div>
                <div class="sm:col-span-3 space-y-1.5">
                  <label for="collegeEndDate" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider">End</label>
                  <input type="date" name="collegeEndDate" id="collegeEndDate" value={{@profile.user_life_history.college_end_date}}
                    class="w-full bg-gray-900/60 border border-gray-700 hover:border-gray-600 rounded-xl px-4 py-2.5 text-sm text-white focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 focus:outline-none transition-colors"
                    {{on "input" (fn this.updateLifeHistory "college_end_date")}}/>
                </div>
              </div>
            </div>

            {{! University }}
            <div class="rounded-2xl bg-gray-800/40 border border-white/5 p-5 space-y-4">
              <p class="text-[10px] font-bold uppercase tracking-widest text-violet-400">🎓 University</p>
              <div class="grid grid-cols-1 gap-4 sm:grid-cols-6">
                <div class="sm:col-span-6 space-y-1.5">
                  <label for="universityName" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider">Name</label>
                  <input type="text" name="universityName" id="universityName" value={{@profile.user_life_history.university_name}} placeholder="e.g. Springfield University"
                    class="w-full bg-gray-900/60 border border-gray-700 hover:border-gray-600 rounded-xl px-4 py-2.5 text-sm text-white placeholder-gray-500 focus:border-violet-500 focus:ring-1 focus:ring-violet-500 focus:outline-none transition-colors"
                    {{on "input" (fn this.updateLifeHistory "university_name")}}/>
                </div>
                <div class="sm:col-span-3 space-y-1.5">
                  <label for="universityStartDate" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider">Start</label>
                  <input type="date" name="universityStartDate" id="universityStartDate" value={{@profile.user_life_history.university_start_date}}
                    class="w-full bg-gray-900/60 border border-gray-700 hover:border-gray-600 rounded-xl px-4 py-2.5 text-sm text-white focus:border-violet-500 focus:ring-1 focus:ring-violet-500 focus:outline-none transition-colors"
                    {{on "input" (fn this.updateLifeHistory "university_start_date")}}/>
                </div>
                <div class="sm:col-span-3 space-y-1.5">
                  <label for="universityEndDate" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider">End</label>
                  <input type="date" name="universityEndDate" id="universityEndDate" value={{@profile.user_life_history.university_end_date}}
                    class="w-full bg-gray-900/60 border border-gray-700 hover:border-gray-600 rounded-xl px-4 py-2.5 text-sm text-white focus:border-violet-500 focus:ring-1 focus:ring-violet-500 focus:outline-none transition-colors"
                    {{on "input" (fn this.updateLifeHistory "university_end_date")}}/>
                </div>
              </div>
            </div>

          </div>
        </div>

        {{! ════ WORK EXPERIENCE ════ }}
        <div class="grid grid-cols-1 gap-y-5 px-4 py-6 sm:px-6 sm:gap-y-6 md:px-8 md:py-8 md:grid-cols-3 md:gap-x-10">
          <div class="space-y-1.5">
            <div class="flex items-center gap-2">
              <span class="flex items-center justify-center w-7 h-7 rounded-lg bg-orange-500/15 border border-orange-500/25 text-sm">💼</span>
              <h3 class="text-sm font-bold text-white uppercase tracking-widest">Work</h3>
            </div>
            <p class="text-xs text-gray-500 pl-9">Your professional history.</p>
          </div>

          <div class="space-y-4 md:col-span-2">
            {{#each @profile.user_life_history.job key="id" as |job index|}}
              <div class="rounded-2xl bg-gray-800/40 border border-white/5 p-5 space-y-4">
                <div class="flex items-center justify-between">
                  <p class="text-[10px] font-bold uppercase tracking-widest text-orange-400">💼 Job {{index}}</p>
                  <button
                    type="button"
                    {{on "click" (fn this.removeJob job)}}
                    class="inline-flex items-center gap-1 text-xs font-semibold text-red-400 hover:text-red-300 bg-red-500/10 hover:bg-red-500/20 border border-red-500/20 px-2.5 py-1 rounded-lg transition-colors"
                  >
                    <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
                    Remove
                  </button>
                </div>
                <div class="grid grid-cols-1 gap-4 sm:grid-cols-6">
                  <div class="sm:col-span-6 space-y-1.5">
                    <label for="jobName-{{index}}" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider">Job Title</label>
                    <input type="text" name="jobName-{{index}}" id="jobName-{{index}}" value={{job.job_name}} placeholder="e.g. Software Engineer"
                      class="w-full bg-gray-900/60 border border-gray-700 hover:border-gray-600 rounded-xl px-4 py-2.5 text-sm text-white placeholder-gray-500 focus:border-orange-500 focus:ring-1 focus:ring-orange-500 focus:outline-none transition-colors"
                      {{on "input" (fn this.updateJob index "job_name")}}/>
                  </div>
                  <div class="sm:col-span-3 space-y-1.5">
                    <label for="jobStartDate-{{index}}" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider">Start</label>
                    <input type="date" name="jobStartDate-{{index}}" id="jobStartDate-{{index}}" value={{job.job-start-at}}
                      class="w-full bg-gray-900/60 border border-gray-700 hover:border-gray-600 rounded-xl px-4 py-2.5 text-sm text-white focus:border-orange-500 focus:ring-1 focus:ring-orange-500 focus:outline-none transition-colors"
                      {{on "input" (fn this.updateJob index "job-start-at")}}/>
                  </div>
                  <div class="sm:col-span-3 space-y-1.5">
                    <label for="jobEndDate-{{index}}" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider">End</label>
                    <input type="date" name="jobEndDate-{{index}}" id="jobEndDate-{{index}}" value={{job.job-end-at}}
                      class="w-full bg-gray-900/60 border border-gray-700 hover:border-gray-600 rounded-xl px-4 py-2.5 text-sm text-white focus:border-orange-500 focus:ring-1 focus:ring-orange-500 focus:outline-none transition-colors"
                      {{on "input" (fn this.updateJob index "job-end-at")}}/>
                  </div>
                </div>
              </div>
            {{/each}}

            <button
              type="button"
              {{on "click" this.addJob}}
              class="inline-flex items-center gap-2 text-xs font-bold text-orange-400 hover:text-orange-300 border border-dashed border-orange-500/40 hover:border-orange-400/60 px-4 py-2.5 rounded-xl transition-colors w-full justify-center"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/></svg>
              Add Job
            </button>
          </div>
        </div>

        {{! ════ ACTIONS — sticky footer ════ }}
        <div class="sticky bottom-0 z-10 flex flex-wrap justify-end gap-3 px-4 py-4 sm:px-8 sm:py-5 bg-gray-900/95 backdrop-blur border-t border-white/10">
          <button
            type="button"
            {{on "click" @onCancel}}
            class="px-6 py-2.5 text-sm font-bold text-gray-300 hover:text-white border border-gray-700 hover:border-gray-500 rounded-xl bg-transparent transition-colors min-w-[90px]"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={{or @isSaving (not this.canSubmit)}}
            class="inline-flex items-center gap-2 px-8 py-2.5 text-sm font-extrabold text-white
                   bg-gradient-to-r from-indigo-600 to-violet-600 hover:from-indigo-500 hover:to-violet-500
                   disabled:opacity-60 disabled:cursor-not-allowed
                   rounded-xl shadow-lg shadow-indigo-500/25 transition-all active:scale-95 uppercase tracking-widest"
          >
            {{#if @isSaving}}
              <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8z"/>
              </svg>
              Saving…
            {{else}}
              <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/>
              </svg>
              Save Changes
            {{/if}}
          </button>
        </div>

      </form>
    </div>
  </template>
}
