import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import config from 'spordium/config/environment';
import {getUserLocation} from "../../../utils/utility.helper";


const GOOGLE_MAPS_API_KEY = config.APP.GOOGLE_MAPS_API_KEY;
const MAP_ID = 'DEMO_MAP_ID'; // swap with your real Map ID in production




// ── Load Google Maps JS SDK once across the whole app ──────────────────────────
let _mapsPromise = null;
function loadGoogleMaps() {
  if (_mapsPromise) return _mapsPromise;
  _mapsPromise = new Promise((resolve) => {
    // Already loaded (e.g. hot-reload)
    if (window.google?.maps?.marker) return resolve();

    window.__googleMapsReady = resolve;
    const s = document.createElement('script');
    s.src = `https://maps.googleapis.com/maps/api/js?key=${GOOGLE_MAPS_API_KEY}&libraries=places,marker&loading=async&callback=__googleMapsReady`;
    s.async = true;
    document.head.appendChild(s);
  });
  return _mapsPromise;
}

// ── Reverse geocode ────────────────────────────────────────────────────────────
function reverseGeocode(lat, lng) {
  return new Promise((resolve) => {
    new window.google.maps.Geocoder().geocode(
      { location: { lat, lng } },
      (results, status) =>
        resolve(
          status === 'OK' && results[0]
            ? results[0].formatted_address
            : `${lat.toFixed(6)}, ${lng.toFixed(6)}`
        )
    );
  });
}

// ── Wait until the browser has actually painted the element ───────────────────
// Two nested rAFs guarantee the element is in the layout tree after Ember renders
function afterPaint(fn) {
  requestAnimationFrame(() => requestAnimationFrame(fn));
}

// ── Build the custom animated pin DOM element ─────────────────────────────────
function buildPinElement() {
  if (!document.getElementById('lp-pin-styles')) {
    const style = document.createElement('style');
    style.id = 'lp-pin-styles';
    style.textContent = `
      @keyframes lp-ripple {
        0%   { transform: scale(1);   opacity: 0.6; }
        100% { transform: scale(3);   opacity: 0;   }
      }
      @keyframes lp-drop {
        0%   { transform: translateY(-20px) scale(0.6); opacity: 0; }
        65%  { transform: translateY(4px)   scale(1.1); opacity: 1; }
        100% { transform: translateY(0)     scale(1);   opacity: 1; }
      }
      .lp-pin { position: relative; width: 28px; height: 28px; cursor: pointer; }
      .lp-pin .lp-ring {
        position: absolute; inset: 0; border-radius: 50%;
        border: 2px solid #38bdf8;
        animation: lp-ripple 1.5s ease-out infinite;
      }
      .lp-pin .lp-ring2 { animation-delay: 0.75s; }
      .lp-pin .lp-core {
        position: absolute; inset: 5px; border-radius: 50%;
        background: #38bdf8;
        box-shadow: 0 0 12px 3px rgba(56,189,248,0.5);
        animation: lp-drop 0.3s cubic-bezier(.22,.68,0,1.45) both;
      }
    `;
    document.head.appendChild(style);
  }

  const wrap = document.createElement('div');
  wrap.className = 'lp-pin';
  wrap.innerHTML = `
    <div class="lp-ring"></div>
    <div class="lp-ring lp-ring2"></div>
    <div class="lp-core"></div>
  `;
  return wrap;
}

// ══════════════════════════════════════════════════════════════════════════════
export default class LocationPicker extends Component {
  @tracked isOpen          = false;
  @tracked isLoading       = false;
  @tracked selectedLat     = null;
  @tracked selectedLng     = null;
  @tracked selectedAddress = '';
  @tracked geocoding       = false;

  _map    = null;
  _marker = null;
  _search = null;

  // ── Open ─────────────────────────────────────────────────────────────────────
  @action
  async openPicker() {
    this.isOpen    = true;
    this.isLoading = true;

    await loadGoogleMaps();

    this.isLoading = false;

    // Wait for Ember to flush rendering, then init the map
    afterPaint(() => this._initMap());
  }

  // ── Init map ──────────────────────────────────────────────────────────────────
  async _initMap() {
    const container = document.getElementById('lp-map-canvas');
    if (!container || this._map) return;

    const map_data = await getUserLocation() // New Delhi fallback
    const defaultCenter = map_data.geo && (map_data.geo.lat && map_data.geo.long)?{lat:map_data.geo.lat,lng:map_data.geo.long}:{ lat: 23.8041, lng: 90.4152 };
    // 1. Create map first — so the geolocation callback can safely call setCenter
    this._map = new window.google.maps.Map(container, {
      center:             defaultCenter,
      zoom:               14,
      mapId:              MAP_ID,
      gestureHandling:    'greedy',
      mapTypeControl:     false,
      streetViewControl:  false,
      fullscreenControl:  false,
      zoomControlOptions: {
        position: window.google.maps.ControlPosition.RIGHT_CENTER,
      },
    });

    // 2. Attach Places search
    this._initSearchBox();

    // 3. Try to get the user's real position
    navigator.geolocation?.getCurrentPosition(
      ({ coords }) => {
        const pos = { lat: coords.latitude, lng: coords.longitude };
        this._map.setCenter(pos);
        this._map.setZoom(15);
        this._placeMarker(pos);
      },
      () => {
        // Permission denied / unavailable → pin at default center
        this._placeMarker(defaultCenter);
      },
      { timeout: 6000 }
    );

    // 4. Click anywhere on the map to move the pin
    this._map.addListener('click', (e) => {
      this._placeMarker({ lat: e.latLng.lat(), lng: e.latLng.lng() });
    });
  }

  // ── Places Autocomplete search box ───────────────────────────────────────────
  _initSearchBox() {
    const input = document.getElementById('lp-search-input');
    if (!input) return;

    this._search = new window.google.maps.places.Autocomplete(input, {
      fields: ['geometry', 'formatted_address'],
    });

    this._search.addListener('place_changed', () => {
      const place = this._search.getPlace();
      if (!place.geometry?.location) return;

      const pos = {
        lat: place.geometry.location.lat(),
        lng: place.geometry.location.lng(),
      };
      this._map.setCenter(pos);
      this._map.setZoom(16);
      this._placeMarker(pos, place.formatted_address);
    });
  }

  // ── Drop / move the animated pin ─────────────────────────────────────────────
  _placeMarker(position, knownAddress = null) {
    const { AdvancedMarkerElement } = window.google.maps.marker;

    if (this._marker) {
      // Rebuild content to re-trigger the drop animation on every click
      this._marker.content  = buildPinElement();
      this._marker.position = position;
    } else {
      this._marker = new AdvancedMarkerElement({
        map:     this._map,
        position,
        content: buildPinElement(),
        title:   'Selected location',
      });
    }

    this.selectedLat = position.lat;
    this.selectedLng = position.lng;

    if (knownAddress) {
      this.selectedAddress = knownAddress;
      this.geocoding = false;
    } else {
      this.geocoding = true;
      reverseGeocode(position.lat, position.lng).then((addr) => {
        this.selectedAddress = addr;
        this.geocoding = false;
      });
    }
  }

  // ── Confirm ──────────────────────────────────────────────────────────────────
  @action
  handleSelect() {
    if (this.selectedLat === null) return;
    this.args.onSelect?.({
      lat:     this.selectedLat,
      lng:     this.selectedLng,
      address: this.selectedAddress,
    });
    this._close();
  }

  // ── Cancel ───────────────────────────────────────────────────────────────────
  @action
  handleCancel() {
    this._close();
  }

  _close() {
    if (this._marker) this._marker.map = null;
    this._map    = null;
    this._marker = null;
    this._search = null;

    this.isOpen          = false;
    this.selectedLat     = null;
    this.selectedLng     = null;
    this.selectedAddress = '';
    this.geocoding       = false;
  }

  // ── Template ──────────────────────────────────────────────────────────────────
  <template>
    {{! ── Trigger button ── }}
    <button
      type="button"
      {{on "click" this.openPicker}}
      class="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl
             bg-sky-500 hover:bg-sky-400 active:scale-95
             text-white font-semibold text-sm
             shadow-lg shadow-sky-900/40
             transition-all duration-150
             focus:outline-none focus:ring-2 focus:ring-sky-400 focus:ring-offset-2 focus:ring-offset-zinc-900"
    >
      <svg class="w-4 h-4 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7z"/>
        <circle cx="12" cy="9" r="2.5"/>
      </svg>
    </button>

    {{! ── Modal ── }}
    {{#if this.isOpen}}
      <div
        class="fixed inset-0 z-[9999] flex items-center justify-center p-3 sm:p-6"
        role="dialog"
        aria-modal="true"
        aria-label="Location Picker"
      >
        {{! Backdrop }}
        <div
          class="absolute inset-0 bg-black/75 backdrop-blur-sm"
          {{on "click" this.handleCancel}}
        ></div>

        {{! Panel }}
        <div
          class="relative z-10 flex flex-col w-full max-w-2xl rounded-2xl overflow-hidden
                 bg-zinc-900 border border-zinc-700/50
                 shadow-[0_32px_80px_rgba(0,0,0,0.85)]"
          style="max-height: 92dvh;"
        >

          {{! ── Header ── }}
          <div class="flex items-center justify-between gap-3 px-5 py-3.5 shrink-0
                      border-b border-zinc-700/50 bg-zinc-900">
            <div class="flex items-center gap-3">
              <div class="w-9 h-9 rounded-xl bg-sky-500/15 flex items-center justify-center shrink-0">
                <svg class="w-4.5 h-4.5 text-sky-400" style="width:18px;height:18px" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7z"/>
                  <circle cx="12" cy="9" r="2.5"/>
                </svg>
              </div>
              <div>
                <h2 class="text-zinc-100 font-semibold text-sm leading-tight">Select your location</h2>
                <p class="text-zinc-500 text-xs mt-0.5">Search an address or tap anywhere on the map</p>
              </div>
            </div>
            <button
              type="button"
              {{on "click" this.handleCancel}}
              aria-label="Close"
              class="w-8 h-8 rounded-lg flex items-center justify-center
                     text-zinc-500 hover:text-zinc-200 hover:bg-zinc-700/60
                     transition-colors shrink-0"
            >
              <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round">
                <path d="M18 6L6 18M6 6l12 12"/>
              </svg>
            </button>
          </div>

          {{! ── Search box ── }}
          <div class="px-4 pt-3 pb-2 shrink-0 bg-zinc-900">
            <div class="relative">
              <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-500 pointer-events-none"
                   viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
                <circle cx="11" cy="11" r="8"/>
                <path d="m21 21-4.35-4.35"/>
              </svg>
              <input
                id="lp-search-input"
                type="text"
                placeholder="Search address, place or landmark…"
                autocomplete="off"
                class="w-full bg-zinc-800 border border-zinc-700
                       hover:border-zinc-600 focus:border-sky-500
                       text-zinc-200 placeholder-zinc-500 text-sm rounded-xl
                       pl-9 pr-4 py-2.5
                       outline-none focus:ring-2 focus:ring-sky-500/25
                       transition-colors duration-150"
              />
            </div>
          </div>

          {{! ── Map canvas ── }}
          {{! The div#lp-map-canvas MUST have explicit pixel height for the Maps API to render }}
          <div class="relative shrink-0 bg-zinc-800" style="height:380px;">

            {{! Loading skeleton }}
            {{#if this.isLoading}}
              <div class="absolute inset-0 z-10 flex flex-col items-center justify-center gap-3 bg-zinc-900">
                <div class="w-9 h-9 rounded-full border-2 border-zinc-700 border-t-sky-400 animate-spin"></div>
                <span class="text-zinc-500 text-sm">Loading map…</span>
              </div>
            {{/if}}

            <div id="lp-map-canvas" style="width:100%;height:100%;"></div>

            {{! "Tap to pin" hint — disappears once a location is chosen }}
            {{#unless this.selectedLat}}
              <div class="absolute bottom-3 left-1/2 -translate-x-1/2 pointer-events-none
                          flex items-center gap-1.5
                          px-3 py-1.5 rounded-full
                          bg-zinc-900/85 backdrop-blur-sm border border-zinc-700/60
                          text-zinc-400 text-xs whitespace-nowrap">
                <svg class="w-3 h-3 text-sky-400 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round">
                  <path d="M15 10.5a3 3 0 1 1-6 0 3 3 0 0 1 6 0z"/>
                  <path d="M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1 1 15 0z"/>
                </svg>
                Tap the map to drop a pin
              </div>
            {{/unless}}
          </div>

          {{! ── Address strip ── }}
          <div class="flex items-start gap-2.5 px-4 py-3
                      bg-zinc-800/50 border-t border-zinc-700/40 shrink-0"
               style="min-height:52px;">
            {{#if this.selectedAddress}}
              <svg class="w-3.5 h-3.5 text-sky-400 mt-0.5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
                <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7z"/>
                <circle cx="12" cy="9" r="2.5"/>
              </svg>
              <div class="flex-1 min-w-0">
                <p class="text-zinc-200 text-xs leading-relaxed">
                  {{this.selectedAddress}}
                  {{#if this.geocoding}}
                    <span class="inline-block w-3 h-3 ml-1 rounded-full border border-zinc-600
                                 border-t-sky-400 animate-spin align-middle"></span>
                  {{/if}}
                </p>
                {{#if this.selectedLat}}
                  <p class="text-zinc-600 text-[10px] font-mono mt-0.5">
                    {{this.selectedLat}}, {{this.selectedLng}}
                  </p>
                {{/if}}
              </div>
            {{else}}
              <span class="text-zinc-600 text-xs italic self-center">No location pinned yet</span>
            {{/if}}
          </div>

          {{! ── Footer ── }}
          <div class="flex items-center justify-end gap-2.5 px-4 py-3.5
                      bg-zinc-900 border-t border-zinc-700/50 shrink-0">
            <button
              type="button"
              {{on "click" this.handleCancel}}
              class="px-5 py-2 rounded-xl text-sm font-medium
                     text-zinc-400 hover:text-zinc-100
                     bg-zinc-800 hover:bg-zinc-700
                     border border-zinc-700 hover:border-zinc-600
                     transition-all duration-150
                     focus:outline-none focus:ring-2 focus:ring-zinc-600"
            >
              Cancel
            </button>
            <button
              type="button"
              {{on "click" this.handleSelect}}
              disabled={{if this.selectedLat false true}}
              class="px-5 py-2 rounded-xl text-sm font-semibold text-white
                     bg-sky-500 hover:bg-sky-400 active:bg-sky-600
                     disabled:bg-zinc-700 disabled:text-zinc-500 disabled:cursor-not-allowed
                     shadow-md shadow-sky-900/40
                     transition-all duration-150
                     focus:outline-none focus:ring-2 focus:ring-sky-400
                     focus:ring-offset-2 focus:ring-offset-zinc-900"
            >
              ✓&#xFE0E; Select Location
            </button>
          </div>

        </div>{{! /panel }}
      </div>{{! /overlay }}
    {{/if}}
  </template>
}
