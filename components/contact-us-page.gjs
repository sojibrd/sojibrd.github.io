import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { service } from '@ember/service';
import { htmlSafe } from '@ember/template';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import lucideIcon from 'spordium/helpers/lucide-icon';

export default class ContactUsPage extends Component {
  @service toast;

  @tracked firstName = '';
  @tracked lastName = '';
  @tracked email = '';
  @tracked message = '';
  @tracked isSubmitting = false;
  @tracked submitted = false;
  @tracked errors = {};

  get isEmailValid() {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(this.email);
  }

  get messageCharCount() {
    return this.message.length;
  }

  @action
  updateField(field, event) {
    this[field] = event.target.value;
    if (this.errors[field]) {
      const updated = { ...this.errors };
      delete updated[field];
      this.errors = updated;
    }
  }

  @action
  async handleSubmit(event) {
    event.preventDefault();

    const newErrors = {};
    if (!this.firstName.trim()) newErrors.firstName = 'First name is required';
    if (!this.lastName.trim()) newErrors.lastName = 'Last name is required';
    if (!this.email.trim()) {
      newErrors.email = 'Email is required';
    } else if (!this.isEmailValid) {
      newErrors.email = 'Please enter a valid email address';
    }
    if (!this.message.trim()) {
      newErrors.message = 'Message is required';
    } else if (this.message.trim().length < 10) {
      newErrors.message = 'Message must be at least 10 characters';
    }

    this.errors = newErrors;
    if (Object.keys(newErrors).length > 0) return;

    this.isSubmitting = true;
    try {
      const payload = {
        email_subject: 'Wrote to us',
        email_title: 'USER_FEEDBACK',
        template_filename: 'spordium_dynamic_mail_template',
        email_sender: this.email,
        email_body: this.message,
        to_email: 'support@spordium.com',
        instant: true,
      };

      const response = await fetch(
        'https://kamla.adnanfoundation.com/api/v1/send_email_instantly_or_afterwards_multipart/',
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload),
        }
      );

      if (response.ok) {
        this.submitted = true;
        this.firstName = '';
        this.lastName = '';
        this.email = '';
        this.message = '';
        this.errors = {};
        this.toast.success("Message sent! We'll get back to you soon.");
      } else {
        this.toast.error('Failed to send message. Please try again.');
      }
    } catch {
      this.toast.error('Failed to send message. Please try again.');
    } finally {
      this.isSubmitting = false;
    }
  }

  <template>
    <div class="min-h-screen bg-slate-900 text-white">

      {{!-- ── HERO ── --}}
      <section class="relative min-h-[60vh] flex items-center justify-center overflow-hidden">
        <div class="absolute inset-0 bg-gradient-to-br from-slate-900 via-indigo-950 to-slate-900"></div>

        <div class="absolute top-0 left-0 w-[500px] h-[500px] bg-indigo-600/20 rounded-full blur-3xl -translate-x-1/3 -translate-y-1/3"></div>
        <div class="absolute bottom-0 right-0 w-[400px] h-[400px] bg-violet-600/20 rounded-full blur-3xl translate-x-1/3 translate-y-1/3"></div>
        <div class="absolute top-1/2 left-1/2 w-[300px] h-[300px] bg-cyan-500/10 rounded-full blur-3xl -translate-x-1/2 -translate-y-1/2"></div>

        <div class="absolute inset-0 opacity-10"
          style={{htmlSafe "background-image: linear-gradient(rgba(99,102,241,0.3) 1px, transparent 1px), linear-gradient(90deg, rgba(99,102,241,0.3) 1px, transparent 1px); background-size: 60px 60px;"}}></div>

        <div class="relative z-10 max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <div class="inline-flex items-center gap-2 bg-indigo-500/10 border border-indigo-500/30 rounded-full px-5 py-2 mb-8">
            <div class="w-2 h-2 rounded-full bg-green-400 animate-pulse"></div>
            <span class="text-indigo-300 text-xs font-bold uppercase tracking-widest">Global Presence</span>
          </div>
          <h1 class="text-5xl sm:text-6xl lg:text-7xl font-bold italic text-white leading-tight mb-6">
            Get in
            <span class="text-transparent bg-clip-text bg-gradient-to-r from-indigo-400 via-violet-400 to-cyan-400">
              Touch
            </span>
          </h1>
          <p class="text-slate-400 text-lg sm:text-xl max-w-2xl mx-auto leading-relaxed">
            We're spread across three continents — reach out to our nearest office or connect with us directly.
          </p>

          <div class="flex flex-wrap items-center justify-center gap-4 mt-10">
            <a href="mailto:support@spordium.com"
              class="flex items-center gap-3 bg-slate-800/80 backdrop-blur border border-slate-700 hover:border-indigo-500 rounded-full px-6 py-3 transition-all hover:-translate-y-0.5 group">
              <div class="w-8 h-8 rounded-full bg-indigo-500/20 flex items-center justify-center group-hover:bg-indigo-500/30 transition-colors">
                {{lucideIcon "mail" size=16 class="text-indigo-400"}}
              </div>
              <span class="text-slate-300 text-sm font-medium">support@spordium.com</span>
            </a>
            <a href="tel:+8801329660799"
              class="flex items-center gap-3 bg-slate-800/80 backdrop-blur border border-slate-700 hover:border-cyan-500 rounded-full px-6 py-3 transition-all hover:-translate-y-0.5 group">
              <div class="w-8 h-8 rounded-full bg-cyan-500/20 flex items-center justify-center group-hover:bg-cyan-500/30 transition-colors">
                {{lucideIcon "phone" size=16 class="text-cyan-400"}}
              </div>
              <span class="text-slate-300 text-sm font-medium">+880 1329660799</span>
            </a>
          </div>
        </div>

        <div class="absolute bottom-0 left-0 right-0 h-24 bg-gradient-to-t from-slate-900 to-transparent"></div>
      </section>

      {{!-- ── OFFICES SECTION ── --}}
      <section class="py-24 bg-slate-900">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">

          <div class="text-center mb-16">
            <p class="text-indigo-400 text-xs font-bold uppercase tracking-widest mb-3"></p>
            <h2 class="text-3xl sm:text-4xl font-bold italic text-white mb-4">Our Offices</h2>
            <p class="text-slate-500 text-base max-w-xl mx-auto">Three offices, one mission — empowering athletes worldwide.</p>
          </div>

          <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">

            {{!-- BANGLADESH --}}
            <div class="group relative bg-slate-800/60 border border-slate-700 rounded-3xl overflow-hidden hover:border-emerald-500/50 transition-all duration-500 hover:-translate-y-2 hover:shadow-2xl hover:shadow-emerald-900/30 flex flex-col">
              <div class="h-1.5 bg-gradient-to-r from-green-500 via-emerald-400 to-teal-400"></div>
              <div class="p-7 flex-1 flex flex-col">
                <div class="flex items-center justify-between mb-6">
                  <div class="flex items-center gap-3">
                    <div class="w-12 h-12 rounded-2xl bg-emerald-500/15 border border-emerald-500/20 flex items-center justify-center text-2xl">
                      🇧🇩
                    </div>
                    <div>
                      <h3 class="text-white font-bold text-xl leading-tight">Bangladesh Office</h3>
                      <p class="text-emerald-400 text-sm font-semibold">Dhaka</p>
                    </div>
                  </div>
                  <div class="w-9 h-9 rounded-full bg-slate-700 group-hover:bg-emerald-500/20 flex items-center justify-center transition-colors">
                    {{lucideIcon "map-pin" size=16 class="text-slate-400 group-hover:text-emerald-400"}}
                  </div>
                </div>
                <div class="bg-slate-900/50 rounded-2xl p-4 mb-5 flex gap-3">
                  {{lucideIcon "building-2" size=16 class="text-emerald-400 mt-0.5 flex-shrink-0"}}
                  <div>
                    <p class="text-slate-300 text-sm leading-relaxed">Spordium, Flat A4, House 25</p>
                    <p class="text-slate-300 text-sm">Road 4, Block F, Banani</p>
                    <p class="text-slate-400 text-sm">Dhaka - 1213, Bangladesh</p>
                  </div>
                </div>
                <div class="flex-1 rounded-2xl overflow-hidden border border-slate-700 min-h-52 relative">
                  <div class="absolute inset-0 bg-slate-800 flex items-center justify-center z-0">
                    {{lucideIcon "map" size=32 class="text-slate-600"}}
                  </div>
                  <iframe
                    title="Spordium Bangladesh Office"
                    class="relative z-10 w-full h-full min-h-52 grayscale contrast-125 opacity-90 group-hover:grayscale-0 group-hover:opacity-100 transition-all duration-500"
                    src="https://maps.google.com/maps?q=Flat+A4+House+25+Road+4+Block+F+Banani+Dhaka+1213+Bangladesh&output=embed&z=15"
                    loading="lazy"
                    referrerpolicy="no-referrer-when-downgrade"
                  ></iframe>
                </div>
              </div>
            </div>

            {{!-- JAPAN --}}
            <div class="group relative bg-slate-800/60 border border-slate-700 rounded-3xl overflow-hidden hover:border-rose-500/50 transition-all duration-500 hover:-translate-y-2 hover:shadow-2xl hover:shadow-rose-900/30 flex flex-col">
              <div class="h-1.5 bg-gradient-to-r from-rose-600 via-red-500 to-pink-500"></div>
              <div class="p-7 flex-1 flex flex-col">
                <div class="flex items-center justify-between mb-6">
                  <div class="flex items-center gap-3">
                    <div class="w-12 h-12 rounded-2xl bg-rose-500/15 border border-rose-500/20 flex items-center justify-center text-2xl">
                      🇯🇵
                    </div>
                    <div>
                      <h3 class="text-white font-bold text-xl leading-tight">Japan Office</h3>
                      <p class="text-rose-400 text-sm font-semibold">Tokyo</p>
                    </div>
                  </div>
                  <div class="w-9 h-9 rounded-full bg-slate-700 group-hover:bg-rose-500/20 flex items-center justify-center transition-colors">
                    {{lucideIcon "map-pin" size=16 class="text-slate-400 group-hover:text-rose-400"}}
                  </div>
                </div>
                <div class="bg-slate-900/50 rounded-2xl p-4 mb-5 flex gap-3">
                  {{lucideIcon "building-2" size=16 class="text-rose-400 mt-0.5 flex-shrink-0"}}
                  <div>
                    <p class="text-slate-300 text-sm leading-relaxed">Room 309, 7-5-5 Nishi-Shinjuku</p>
                    <p class="text-slate-300 text-sm">Shinjuku-ku</p>
                    <p class="text-slate-400 text-sm">Tokyo, Japan</p>
                  </div>
                </div>
                <div class="flex-1 rounded-2xl overflow-hidden border border-slate-700 min-h-52 relative">
                  <div class="absolute inset-0 bg-slate-800 flex items-center justify-center z-0">
                    {{lucideIcon "map" size=32 class="text-slate-600"}}
                  </div>
                  <iframe
                    title="Spordium Japan Office"
                    class="relative z-10 w-full h-full min-h-52 grayscale contrast-125 opacity-90 group-hover:grayscale-0 group-hover:opacity-100 transition-all duration-500"
                    src="https://maps.google.com/maps?q=7-5-5+Nishi-Shinjuku+Shinjuku-ku+Tokyo+Japan&output=embed&z=15"
                    loading="lazy"
                    referrerpolicy="no-referrer-when-downgrade"
                  ></iframe>
                </div>
              </div>
            </div>

            {{!-- UAE --}}
            <div class="group relative bg-slate-800/60 border border-slate-700 rounded-3xl overflow-hidden hover:border-amber-500/50 transition-all duration-500 hover:-translate-y-2 hover:shadow-2xl hover:shadow-amber-900/30 flex flex-col">
              <div class="h-1.5 bg-gradient-to-r from-amber-500 via-yellow-400 to-orange-400"></div>
              <div class="p-7 flex-1 flex flex-col">
                <div class="flex items-center justify-between mb-6">
                  <div class="flex items-center gap-3">
                    <div class="w-12 h-12 rounded-2xl bg-amber-500/15 border border-amber-500/20 flex items-center justify-center text-2xl">
                      🇦🇪
                    </div>
                    <div>
                      <h3 class="text-white font-bold text-xl leading-tight">UAE Office</h3>
                      <p class="text-amber-400 text-sm font-semibold">Meydan</p>
                    </div>
                  </div>
                  <div class="w-9 h-9 rounded-full bg-slate-700 group-hover:bg-amber-500/20 flex items-center justify-center transition-colors">
                    {{lucideIcon "map-pin" size=16 class="text-slate-400 group-hover:text-amber-400"}}
                  </div>
                </div>
                <div class="bg-slate-900/50 rounded-2xl p-4 mb-5 flex gap-3">
                  {{lucideIcon "building-2" size=16 class="text-amber-400 mt-0.5 flex-shrink-0"}}
                  <div>
                    <p class="text-slate-300 text-sm leading-relaxed">Meydan Grandstand, 6th Floor</p>
                    <p class="text-slate-300 text-sm">Meydan Road, Nad Al Sheba</p>
                    <p class="text-slate-400 text-sm">Dubai, U.A.E.</p>
                  </div>
                </div>
                <div class="flex-1 rounded-2xl overflow-hidden border border-slate-700 min-h-52 relative">
                  <div class="absolute inset-0 bg-slate-800 flex items-center justify-center z-0">
                    {{lucideIcon "map" size=32 class="text-slate-600"}}
                  </div>
                  <iframe
                    title="Spordium UAE Office"
                    class="relative z-10 w-full h-full min-h-52 grayscale contrast-125 opacity-90 group-hover:grayscale-0 group-hover:opacity-100 transition-all duration-500"
                    src="https://maps.google.com/maps?q=Meydan+Grandstand+Meydan+Road+Nad+Al+Sheba+Dubai+UAE&output=embed&z=15"
                    loading="lazy"
                    referrerpolicy="no-referrer-when-downgrade"
                  ></iframe>
                </div>
              </div>
            </div>

          </div>
        </div>
      </section>

      {{!-- ── CONTACT DETAILS SECTION ── --}}
      <section class="py-20 bg-slate-800/40">
        <div class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="text-center mb-12">
            <p class="text-violet-400 text-xs font-bold uppercase tracking-widest mb-3">Direct Contact</p>
            <h2 class="text-3xl sm:text-4xl font-bold italic text-white">Reach Out Anytime</h2>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-6">
            <a href="mailto:support@spordium.com"
              class="group relative bg-slate-800/60 border border-slate-700 hover:border-indigo-500/60 rounded-3xl p-8 flex items-start gap-6 transition-all duration-300 hover:-translate-y-1 hover:shadow-xl hover:shadow-indigo-900/30">
              <div class="absolute inset-0 rounded-3xl bg-gradient-to-br from-indigo-600/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity"></div>
              <div class="relative w-16 h-16 rounded-2xl bg-indigo-500/15 border border-indigo-500/20 group-hover:bg-indigo-500/25 flex items-center justify-center flex-shrink-0 transition-colors">
                {{lucideIcon "mail" size=28 class="text-indigo-400"}}
              </div>
              <div class="relative">
                <p class="text-slate-500 text-xs font-bold uppercase tracking-widest mb-1">Email Us</p>
                <p class="text-white font-bold text-xl mb-1 group-hover:text-indigo-300 transition-colors">support@spordium.com</p>
                <p class="text-slate-500 text-sm">We reply within 24 hours</p>
              </div>
            </a>

            <a href="tel:+8801329660799"
              class="group relative bg-slate-800/60 border border-slate-700 hover:border-cyan-500/60 rounded-3xl p-8 flex items-start gap-6 transition-all duration-300 hover:-translate-y-1 hover:shadow-xl hover:shadow-cyan-900/30">
              <div class="absolute inset-0 rounded-3xl bg-gradient-to-br from-cyan-600/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity"></div>
              <div class="relative w-16 h-16 rounded-2xl bg-cyan-500/15 border border-cyan-500/20 group-hover:bg-cyan-500/25 flex items-center justify-center flex-shrink-0 transition-colors">
                {{lucideIcon "phone" size=28 class="text-cyan-400"}}
              </div>
              <div class="relative">
                <p class="text-slate-500 text-xs font-bold uppercase tracking-widest mb-1">Call Us</p>
                <p class="text-white font-bold text-xl mb-1 group-hover:text-cyan-300 transition-colors">+880 1329660799</p>
                <p class="text-slate-500 text-sm"></p>
              </div>
            </a>
          </div>
        </div>
      </section>

      {{!-- ── WRITE TO US ── --}}
      <section class="py-24 relative overflow-hidden bg-slate-900">
        <div class="absolute inset-0 opacity-5"
          style={{htmlSafe "background-image: radial-gradient(circle at 1px 1px, rgba(99,102,241,0.8) 1px, transparent 0); background-size: 32px 32px;"}}></div>
        <div class="absolute top-0 right-0 w-[600px] h-[600px] bg-violet-600/10 rounded-full blur-3xl translate-x-1/3 -translate-y-1/3 pointer-events-none"></div>
        <div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-indigo-600/10 rounded-full blur-3xl -translate-x-1/3 translate-y-1/3 pointer-events-none"></div>

        <div class="relative z-10 max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="max-w-2xl mx-auto w-full">

            {{!-- Form card --}}
            <div>
              <div class="relative bg-slate-800/60 backdrop-blur-sm border border-slate-700/80 rounded-3xl p-8 sm:p-10 shadow-2xl shadow-slate-950/50">
                {{! Subtle gradient border glow }}
                <div class="absolute -inset-px rounded-3xl bg-gradient-to-br from-indigo-500/10 via-transparent to-violet-500/10 pointer-events-none"></div>

                {{#if this.submitted}}
                  <div class="flex flex-col items-center justify-center py-12 text-center">
                    <div class="w-20 h-20 rounded-full bg-green-500/15 border border-green-500/30 flex items-center justify-center mb-6">
                      {{lucideIcon "check-circle" size=40 class="text-green-400"}}
                    </div>
                    <h3 class="text-white font-bold text-2xl italic mb-3">Message Sent!</h3>
                    <p class="text-slate-400 text-base max-w-sm leading-relaxed mb-8">
                      Thanks for writing to us. We've received your message and will get back to you shortly.
                    </p>
                    <button
                      type="button"
                      {{on "click" (fn (mut this.submitted) false)}}
                      class="py-3 px-10 bg-indigo-600 hover:bg-indigo-500 text-white font-bold rounded-full text-sm uppercase tracking-widest transition-colors"
                    >
                      Send Another
                    </button>
                  </div>
                {{else}}
                  <form {{on "submit" this.handleSubmit}} novalidate class="relative space-y-5">

                    {{!-- Name row --}}
                    <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                      <div>
                        <label for="cu-first-name" class="block text-slate-400 text-xs font-bold uppercase tracking-wider mb-2">First Name</label>
                        <input
                          id="cu-first-name"
                          type="text"
                          placeholder="John"
                          value={{this.firstName}}
                          {{on "input" (fn this.updateField "firstName")}}
                          class="w-full px-4 py-3.5 rounded-xl bg-slate-900/80 text-white placeholder-slate-600 text-sm border focus:outline-none focus:ring-1 transition-all
                            {{if this.errors.firstName 'border-red-500/70 focus:border-red-500 focus:ring-red-500/20' 'border-slate-700/80 focus:border-indigo-500 focus:ring-indigo-500/20'}}"
                        />
                        {{#if this.errors.firstName}}
                          <p class="mt-1.5 text-red-400 text-xs flex items-center gap-1">
                            {{lucideIcon "alert-circle" size=12 class="text-red-400"}}
                            {{this.errors.firstName}}
                          </p>
                        {{/if}}
                      </div>
                      <div>
                        <label for="cu-last-name" class="block text-slate-400 text-xs font-bold uppercase tracking-wider mb-2">Last Name</label>
                        <input
                          id="cu-last-name"
                          type="text"
                          placeholder="Doe"
                          value={{this.lastName}}
                          {{on "input" (fn this.updateField "lastName")}}
                          class="w-full px-4 py-3.5 rounded-xl bg-slate-900/80 text-white placeholder-slate-600 text-sm border focus:outline-none focus:ring-1 transition-all
                            {{if this.errors.lastName 'border-red-500/70 focus:border-red-500 focus:ring-red-500/20' 'border-slate-700/80 focus:border-indigo-500 focus:ring-indigo-500/20'}}"
                        />
                        {{#if this.errors.lastName}}
                          <p class="mt-1.5 text-red-400 text-xs flex items-center gap-1">
                            {{lucideIcon "alert-circle" size=12 class="text-red-400"}}
                            {{this.errors.lastName}}
                          </p>
                        {{/if}}
                      </div>
                    </div>

                    {{!-- Email --}}
                    <div>
                      <label for="cu-email" class="block text-slate-400 text-xs font-bold uppercase tracking-wider mb-2">Email Address</label>
                      <div class="relative">
                        <div class="absolute left-4 top-1/2 -translate-y-1/2 pointer-events-none">
                          {{lucideIcon "mail" size=16 class="text-slate-500"}}
                        </div>
                        <input
                          id="cu-email"
                          type="email"
                          placeholder="john@example.com"
                          value={{this.email}}
                          {{on "input" (fn this.updateField "email")}}
                          class="w-full pl-11 pr-4 py-3.5 rounded-xl bg-slate-900/80 text-white placeholder-slate-600 text-sm border focus:outline-none focus:ring-1 transition-all
                            {{if this.errors.email 'border-red-500/70 focus:border-red-500 focus:ring-red-500/20' 'border-slate-700/80 focus:border-indigo-500 focus:ring-indigo-500/20'}}"
                        />
                      </div>
                      {{#if this.errors.email}}
                        <p class="mt-1.5 text-red-400 text-xs flex items-center gap-1">
                          {{lucideIcon "alert-circle" size=12 class="text-red-400"}}
                          {{this.errors.email}}
                        </p>
                      {{/if}}
                    </div>

                    {{!-- Message --}}
                    <div>
                      <div class="flex items-center justify-between mb-2">
                        <label for="cu-message" class="block text-slate-400 text-xs font-bold uppercase tracking-wider">Message</label>
                        <span class="text-slate-600 text-xs tabular-nums">{{this.messageCharCount}} / min 10</span>
                      </div>
                      <div class="relative rounded-xl overflow-hidden border focus-within:ring-1 transition-all
                        {{if this.errors.message 'border-red-500/70 focus-within:border-red-500 focus-within:ring-red-500/20' 'border-slate-700/80 focus-within:border-indigo-500 focus-within:ring-indigo-500/20'}}">
                        <textarea
                          id="cu-message"
                          rows="6"
                          placeholder="Write your message here..."
                          {{on "input" (fn this.updateField "message")}}
                          class="w-full px-4 pt-4 pb-10 bg-slate-900/80 text-slate-200 placeholder-slate-600 text-sm focus:outline-none resize-none leading-relaxed"
                        >{{this.message}}</textarea>
                        <div class="absolute bottom-0 inset-x-0 px-4 py-2.5 bg-slate-900/60 border-t border-slate-800 flex items-center justify-between pointer-events-none">
                          <div class="flex items-center gap-1.5">
                            {{lucideIcon "send" size=11 class="text-slate-600"}}
                            <span class="text-slate-600 text-xs">→ support@spordium.com</span>
                          </div>
                          <span class="text-slate-700 text-xs tabular-nums">{{this.messageCharCount}}/∞</span>
                        </div>
                      </div>
                      {{#if this.errors.message}}
                        <p class="mt-1.5 text-red-400 text-xs flex items-center gap-1">
                          {{lucideIcon "alert-circle" size=12 class="text-red-400"}}
                          {{this.errors.message}}
                        </p>
                      {{/if}}
                    </div>

                    {{!-- Submit --}}
                    <button
                      type="submit"
                      disabled={{this.isSubmitting}}
                      class="w-full py-4 px-8 bg-gradient-to-r from-indigo-600 to-violet-600 hover:from-indigo-500 hover:to-violet-500 active:from-indigo-700 active:to-violet-700 disabled:opacity-60 disabled:cursor-not-allowed text-white font-bold rounded-xl uppercase tracking-widest text-sm transition-all shadow-lg shadow-indigo-900/40 flex items-center justify-center gap-3"
                    >
                      {{#if this.isSubmitting}}
                        <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
                        </svg>
                        Sending...
                      {{else}}
                        {{lucideIcon "send" size=16 class="text-white"}}
                        Send Message
                      {{/if}}
                    </button>

                  </form>
                {{/if}}
              </div>
            </div>
          </div>
        </div>
      </section>



    </div>
  </template>
}
