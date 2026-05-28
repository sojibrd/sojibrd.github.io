import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import {onInit} from "../../utils/utility.helper";
import config from 'spordium/config/environment';

const API_HOST = config.APP.API_HOST;


export default class GameLiveComponent extends Component {
    @tracked isPlaying = false;
    @tracked isHovering = false;
    @tracked videoId = false;
    @tracked validVideoURLs = []

    _toEmbedUrl(url) {
      if (!url || url.includes('null')) return null;
      const watchMatch = url.match(/[?&]v=([^&]+)/);
      if (watchMatch) return `https://www.youtube.com/embed/${watchMatch[1]}?autoplay=1&mute=0`;
      const shortMatch = url.match(/youtu\.be\/([^?]+)/);
      if (shortMatch) return `https://www.youtube.com/embed/${shortMatch[1]}?autoplay=1&mute=0`;
      if (url.includes('/embed/')) return url;
      return null;
    }

    @action async gameLiveStreamURL() {
      const gameID = this.args.id || 'BD__20251202045748139212';
      const request = await fetch(`${API_HOST}/live_scoring/get-match-live-link/`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ game_id: gameID }),
      });
      const response = await request.json();
      if (response.data?.youtube_link?.length) {
        this.validVideoURLs = response.data.youtube_link
          .map((entry) => this._toEmbedUrl(Object.values(entry)[0]))
          .filter(Boolean);
      }
    }


    get embedUrl() {
      if (!this.videoId) return '';
      return `https://www.youtube.com/embed/${this.videoId}?autoplay=${this.isPlaying ? 1 : 0}&mute=${this.isPlaying ? 0 : 1}`;
    }

    @action
    togglePlay() {
      this.isPlaying = !this.isPlaying;
    }

    @action
    setHovering(state) {
      this.isHovering = state;
    }

  <template>
      <div class="flex flex-wrap gap-6 {{unless this.validVideoURLs.length 'hidden'}}" {{onInit this.gameLiveStreamURL}}>
        {{#each this.validVideoURLs as |url|}}
          {{log url}}
          <div class="w-full h-full flex items-center justify-center p-6 px-0 transition-all duration-500 ease-in-out select-none" >
            <div class="relative w-full max-w-7xl transition-all duration-500 ease-in-out">
              {{!-- Video Container --}}
              <div
                class="relative w-full aspect-video bg-gradient-to-br from-gray-900 via-gray-800 to-black rounded-lg sm:rounded-xl md:rounded-2xl lg:rounded-3xl overflow-hidden shadow-2xl transition-all duration-500 ease-in-out hover:shadow-red-500/20"
                {{on "mouseenter" (fn this.setHovering true)}}
                {{on "mouseleave" (fn this.setHovering false)}}
              >
                {{#if url}}
                {{!-- YouTube iframe --}}
                  <iframe
                    src={{url}}
                    class="absolute inset-0 w-full h-full transition-all duration-500 ease-in-out"
                    frameborder="0"
                    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                    allowfullscreen
                  ></iframe>

                  {{!-- Control Overlay --}}
                  <div
                    class="absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-transparent opacity-0 hover:opacity-100 transition-all duration-300 ease-in-out flex items-end justify-between p-4 sm:p-6 md:p-8 pointer-events-none"
                    style={{if this.isHovering "opacity: 1;" "opacity: 0;"}}
                  >
                    {{!-- Live Badge --}}
                    <button class="flex items-center gap-3 bg-gray-900 text-white px-4 py-2 rounded-lg select-none" type="button">
                      <span class="relative flex size-3">
                        {{!-- The radiating circle (fades out) --}}
                        <span class="absolute inline-flex h-full w-full animate-ping rounded-full bg-red-400 opacity-75"></span>
                        {{!-- The solid center dot --}}
                        <span class="relative inline-flex size-3 rounded-full bg-red-500"></span>
                      </span>
                      LIVE
                    </button>

                    {{!-- Play/Pause Button --}}
                    <button
                      type="button"
                      {{on "click" this.togglePlay}}
                      class="pointer-events-auto group relative w-12 h-12 sm:w-14 sm:h-14 md:w-16 md:h-16 lg:w-20 lg:h-20 rounded-full bg-white/10 backdrop-blur-md border-2 border-white/30 flex items-center justify-center transition-all duration-300 ease-in-out hover:bg-white/20 hover:scale-110 hover:border-white/50 active:scale-95 shadow-xl"
                    >
                      {{!-- Play Icon --}}
                      {{#unless this.isPlaying}}
                        <svg
                          class="w-5 h-5 sm:w-6 sm:h-6 md:w-7 md:h-7 lg:w-9 lg:h-9 text-white ml-1 transition-all duration-300 ease-in-out group-hover:scale-110"
                          fill="currentColor"
                          viewBox="0 0 24 24"
                        >
                          <path d="M8 5v14l11-7z" />
                        </svg>
                      {{/unless}}

                      {{!-- Pause Icon --}}
                      {{#if this.isPlaying}}
                        <svg
                          class="w-5 h-5 sm:w-6 sm:h-6 md:w-7 md:h-7 lg:w-9 lg:h-9 text-white transition-all duration-300 ease-in-out group-hover:scale-110"
                          fill="currentColor"
                          viewBox="0 0 24 24"
                        >
                          <path d="M6 4h4v16H6V4zm8 0h4v16h-4V4z" />
                        </svg>
                      {{/if}}

                      {{!-- Ripple Effect --}}
                      <div class="absolute inset-0 rounded-full bg-white/20 scale-0 group-hover:scale-100 group-hover:opacity-0 transition-all duration-500 ease-out"></div>
                    </button>
                  </div>

                  {{!-- Status Indicator Top Right --}}
                  <div class="absolute top-4 right-4 sm:top-6 sm:right-6 flex flex-col gap-2 transition-all duration-500 ease-in-out">
                    {{!-- Viewer Count --}}
                    {{#if @viewerCount}}
                      <div class="bg-black/50 backdrop-blur-md px-3 py-1.5 sm:px-4 sm:py-2 rounded-full flex items-center gap-2 transition-all duration-300 ease-in-out hover:bg-black/70">
                        <svg class="w-3 h-3 sm:w-4 sm:h-4 text-red-400" fill="currentColor" viewBox="0 0 24 24">
                          <path d="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5zM12 17c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3z"/>
                        </svg>
                        <span class="text-red-400 text-xs sm:text-sm font-semibold">{{@viewerCount.live}}</span>
                        <span class="text-white/30 text-xs">·</span>
                        <span class="text-white/60 text-xs sm:text-sm font-medium">{{@viewerCount.total}}</span>
                      </div>
                    {{/if}}
                  </div>

                {{else}}
                {{!-- No Video Placeholder --}}
                  <div class="absolute inset-0 flex flex-col items-center justify-center p-6 text-center">
                    <svg class="w-16 h-16 sm:w-20 sm:h-20 md:w-24 md:h-24 lg:w-32 lg:h-32 text-gray-600 mb-4 transition-all duration-500 ease-in-out" fill="currentColor" viewBox="0 0 24 24">
                      <path d="M10 16.5l6-4.5-6-4.5v9zM12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z"/>
                    </svg>
                    <h3 class="text-white text-lg sm:text-xl md:text-2xl lg:text-3xl font-bold mb-2 transition-all duration-500 ease-in-out">
                      No Video URL Provided
                    </h3>
                    <p class="text-gray-400 text-sm sm:text-base md:text-lg max-w-md transition-all duration-500 ease-in-out">
                      Please provide a valid YouTube URL to display the live video
                    </p>
                  </div>
                {{/if}}
              </div>


            </div>
          </div>
        {{/each}}
      </div>

  </template>
}
