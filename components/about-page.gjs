import { LinkTo } from '@ember/routing';
import lucideIcon from 'spordium/helpers/lucide-icon';

<template>
  <div class="min-h-screen bg-slate-900 text-white">

    <section class="relative min-h-screen flex items-center justify-center overflow-hidden">
      <div class="absolute inset-0 bg-gradient-to-br from-slate-900 via-slate-800 to-indigo-950"></div>
      <div class="absolute top-1/4 left-1/4 w-96 h-96 bg-indigo-500/20 blur-3xl rounded-full -translate-x-1/2 -translate-y-1/2"></div>
      <div class="absolute bottom-1/4 right-1/4 w-80 h-80 bg-violet-500/20 blur-3xl rounded-full translate-x-1/2 translate-y-1/2"></div>
      <div class="absolute top-1/2 left-1/2 w-64 h-64 bg-cyan-500/10 blur-3xl rounded-full -translate-x-1/2 -translate-y-1/2"></div>
      <div class="relative z-10 max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <p class="text-primary text-lg sm:text-xl font-bold italic tracking-widest uppercase mb-4">Spordium</p>
        <h1 class="text-4xl sm:text-5xl lg:text-6xl font-bold italic text-white leading-tight mb-6">
          The Ultimate Platform for Amateur &amp; Semi-Professional Athletes
        </h1>
        <p class="text-slate-300 text-lg sm:text-xl font-light tracking-wide">
          Score Live, Broadcast Wide.
        </p>
      </div>
      <div class="absolute bottom-0 left-0 right-0 h-32 bg-gradient-to-t from-slate-900 to-transparent"></div>
    </section>

    <section class="py-20 bg-slate-900">
      <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="bg-slate-800/50 backdrop-blur rounded-2xl border border-slate-700/50 p-8 sm:p-12 flex flex-col lg:flex-row gap-10 items-start">
          <div class="flex-shrink-0">
            <div class="w-16 h-16 rounded-2xl bg-indigo-500/20 border border-indigo-500/30 flex items-center justify-center">
              {{lucideIcon "globe" size=32 class="text-indigo-400"}}
            </div>
          </div>
          <div class="space-y-5">
            <p class="text-slate-300 text-base sm:text-lg leading-relaxed">
              Spordium is more than just a sports platform, it's a digital revolution built to empower the heart of global sports: amateur and semi-professional athletes. In a world where grassroots talent often goes unnoticed, our platform brings visibility, structure and opportunity to the players, organizers and fans that make the game happen.
            </p>
            <p class="text-slate-300 text-base sm:text-lg leading-relaxed">
              We're building a next generation sports ecosystem, one that breaks barriers of geography, technology and visibility. From real time sports scoring and AI-powered performance analysis to global broadcasting and monetization tools, Spordium ensures that every moment on the field counts.
            </p>
            <p class="text-slate-300 text-base sm:text-lg leading-relaxed">
              Whether you're organizing a local tournament, chasing your dream as a player or cheering from halfway across the world, Spordium gives you the tools, exposure and community to make it all possible.
            </p>
          </div>
        </div>
      </div>
    </section>

    <section class="py-20 bg-gradient-to-r from-indigo-900 to-violet-900">
      <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex flex-col lg:flex-row gap-12 items-center">
          <div class="flex-1">
            <p class="text-indigo-300 text-sm font-bold uppercase tracking-widest mb-3">Vision</p>
            <h2 class="text-3xl sm:text-4xl font-bold italic text-white mb-6">Our Vision</h2>
            <p class="text-indigo-100 text-base sm:text-lg leading-relaxed">
              To empower the next generation of athletes by giving them a platform to compete, be seen and succeed, no matter where they play. We believe that talent shouldn't be defined by access and success shouldn't depend on location. Spordium democratizes opportunity in sports, enabling athletes from every background to rise, thrive and be recognized on a global stage.
            </p>
          </div>
          <div class="flex-shrink-0 w-full lg:w-72 space-y-4">
          </div>
        </div>
      </div>
    </section>

    <section class="py-20 bg-slate-900">
      <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="text-center mb-14">
          <p class="text-indigo-400 text-sm font-bold uppercase tracking-widest mb-3">Platform</p>
          <h2 class="text-3xl sm:text-4xl font-bold italic text-white">Redefining the Future of Sports</h2>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <div class="bg-slate-800 border border-slate-700 rounded-2xl p-6 hover:border-indigo-500 transition-all hover:-translate-y-1 flex flex-col gap-4">
            <div class="w-12 h-12 rounded-xl bg-indigo-500/20 flex items-center justify-center">
              {{lucideIcon "calendar" size=24 class="text-indigo-400"}}
            </div>
            <h3 class="text-white font-bold text-lg">Game Setup, Simplified</h3>
            <p class="text-slate-400 text-sm leading-relaxed">Easily organize and manage matches and sports tournaments with our intuitive tools.</p>
          </div>
          <div class="bg-slate-800 border border-slate-700 rounded-2xl p-6 hover:border-cyan-500 transition-all hover:-translate-y-1 flex flex-col gap-4">
            <div class="w-12 h-12 rounded-xl bg-cyan-500/20 flex items-center justify-center">
              {{lucideIcon "play" size=24 class="text-cyan-400"}}
            </div>
            <h3 class="text-white font-bold text-lg">Real-Time Scoring</h3>
            <p class="text-slate-400 text-sm leading-relaxed">Capture every move, live and with precision, using our live sports scoring app.</p>
          </div>
          <div class="bg-slate-800 border border-slate-700 rounded-2xl p-6 hover:border-violet-500 transition-all hover:-translate-y-1 flex flex-col gap-4">
            <div class="w-12 h-12 rounded-xl bg-violet-500/20 flex items-center justify-center">
              {{lucideIcon "video" size=24 class="text-violet-400"}}
            </div>
            <h3 class="text-white font-bold text-lg">Broadcast Without Limits</h3>
            <p class="text-slate-400 text-sm leading-relaxed">Stream your games to a global audience with minimal setup.</p>
          </div>
          <div class="bg-slate-800 border border-slate-700 rounded-2xl p-6 hover:border-emerald-500 transition-all hover:-translate-y-1 flex flex-col gap-4 md:col-span-1">
            <div class="w-12 h-12 rounded-xl bg-emerald-500/20 flex items-center justify-center">
              {{lucideIcon "sliders" size=24 class="text-emerald-400"}}
            </div>
            <h3 class="text-white font-bold text-lg">AI-Powered Insights</h3>
            <p class="text-slate-400 text-sm leading-relaxed">Access powerful sports analytics to guide performance and decision-making.</p>
          </div>
          <div class="bg-slate-800 border border-slate-700 rounded-2xl p-6 hover:border-amber-500 transition-all hover:-translate-y-1 flex flex-col gap-4 md:col-span-1 lg:col-start-2">
            <div class="w-12 h-12 rounded-xl bg-amber-500/20 flex items-center justify-center">
              {{lucideIcon "star" size=24 class="text-amber-400"}}
            </div>
            <h3 class="text-white font-bold text-lg">Monetization for All</h3>
            <p class="text-slate-400 text-sm leading-relaxed">Empower players, organizers and facilitators to earn from their passion using our flexible monetization tools.</p>
          </div>
        </div>
      </div>
    </section>

    <section class="py-20 bg-slate-800/40">
      <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="text-center mb-14">
          <p class="text-cyan-400 text-sm font-bold uppercase tracking-widest mb-3">Community</p>
          <h2 class="text-3xl sm:text-4xl font-bold italic text-white">Empowering the Game Changers</h2>
        </div>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-6">
          <div class="bg-slate-800/60 border-l-4 border-indigo-500 rounded-xl p-6 flex gap-5 items-start">
            <div class="w-11 h-11 rounded-lg bg-indigo-500/20 flex items-center justify-center flex-shrink-0">
              {{lucideIcon "user" size=22 class="text-indigo-400"}}
            </div>
            <div>
              <h3 class="text-white font-bold text-lg mb-2">Athletes</h3>
              <p class="text-slate-400 text-sm leading-relaxed">Showcase your skills, gain exposure and take control of your career path with our semi-pro athlete platform.</p>
            </div>
          </div>
          <div class="bg-slate-800/60 border-l-4 border-cyan-500 rounded-xl p-6 flex gap-5 items-start">
            <div class="w-11 h-11 rounded-lg bg-cyan-500/20 flex items-center justify-center flex-shrink-0">
              {{lucideIcon "users" size=22 class="text-cyan-400"}}
            </div>
            <div>
              <h3 class="text-white font-bold text-lg mb-2">Viewers &amp; Fans</h3>
              <p class="text-slate-400 text-sm leading-relaxed">Watch, support and engage with the games that matter to you.</p>
            </div>
          </div>
          <div class="bg-slate-800/60 border-l-4 border-green-500 rounded-xl p-6 flex gap-5 items-start">
            <div class="w-11 h-11 rounded-lg bg-green-500/20 flex items-center justify-center flex-shrink-0">
              {{lucideIcon "search" size=22 class="text-green-400"}}
            </div>
            <div>
              <h3 class="text-white font-bold text-lg mb-2">Scouts &amp; Recruiters</h3>
              <p class="text-slate-400 text-sm leading-relaxed">Discover hidden talent and track performance with real-time tools.</p>
            </div>
          </div>
          <div class="bg-slate-800/60 border-l-4 border-orange-500 rounded-xl p-6 flex gap-5 items-start">
            <div class="w-11 h-11 rounded-lg bg-orange-500/20 flex items-center justify-center flex-shrink-0">
              {{lucideIcon "building" size=22 class="text-orange-400"}}
            </div>
            <div>
              <h3 class="text-white font-bold text-lg mb-2">Organizers &amp; Facilitators</h3>
              <p class="text-slate-400 text-sm leading-relaxed">Plan, execute and monetize sports events with professional grade features.</p>
            </div>
          </div>
        </div>
      </div>
    </section>

    <section class="py-24 bg-slate-900">
      <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <p class="text-slate-500 text-sm font-bold uppercase tracking-widest mb-16">We Believe</p>
        <div class="space-y-12">
          <div class="flex flex-col items-center gap-4">
            <div class="w-1 h-8 bg-gradient-to-b from-transparent to-indigo-500 rounded-full"></div>
            <p class="text-2xl sm:text-3xl lg:text-4xl font-bold italic">
              Every athlete deserves <span class="text-transparent bg-clip-text bg-gradient-to-r from-indigo-400 to-violet-400">a stage.</span>
            </p>
          </div>
          <div class="flex flex-col items-center gap-4">
            <div class="w-1 h-8 bg-gradient-to-b from-indigo-500 to-cyan-500 rounded-full"></div>
            <p class="text-2xl sm:text-3xl lg:text-4xl font-bold italic">
              Every game deserves <span class="text-transparent bg-clip-text bg-gradient-to-r from-cyan-400 to-teal-400">an audience.</span>
            </p>
          </div>
          <div class="flex flex-col items-center gap-4">
            <div class="w-1 h-8 bg-gradient-to-b from-cyan-500 to-green-500 rounded-full"></div>
            <p class="text-2xl sm:text-3xl lg:text-4xl font-bold italic">
              Every talent deserves <span class="text-transparent bg-clip-text bg-gradient-to-r from-green-400 to-emerald-400">a chance.</span>
            </p>
          </div>
          <div class="w-1 h-8 bg-gradient-to-b from-green-500 to-transparent rounded-full mx-auto"></div>
        </div>
      </div>
    </section>

    <section class="py-24 bg-gradient-to-r from-indigo-600 to-violet-600">
      <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <h2 class="text-3xl sm:text-4xl font-bold italic text-white mb-4">Join the Future of Sports</h2>
        <p class="text-indigo-100 text-lg mb-10">Be part of the movement that's democratizing sports worldwide.</p>
        <LinkTo
          @route="signup"
          class="inline-block py-3.5 px-14 bg-green-500 hover:bg-green-600 active:bg-green-700 text-white font-bold rounded-full uppercase tracking-widest text-sm transition-colors"
        >
          Get Started
        </LinkTo>
      </div>
    </section>

  </div>
</template>
