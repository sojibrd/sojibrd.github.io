import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { service } from '@ember/service';
import { on } from '@ember/modifier';
import { fn, array } from '@ember/helper';
import { eq } from 'ember-truth-helpers';
import { modifier } from 'ember-modifier';
import config from 'spordium/config/environment';
import lucideIcon from 'spordium/helpers/lucide-icon';
import ImageUploader from 'spordium/components/clubs/create/image-uploader';

const whenVisible = modifier((el, [callback]) => {
  let fired = false;
  const obs = new IntersectionObserver(
    (entries) => {
      if (entries[0].isIntersecting && !fired) {
        fired = true;
        obs.disconnect();
        callback();
      }
    },
    { threshold: 0.05, rootMargin: '0px 0px 80px 0px' }
  );
  obs.observe(el);
  return () => obs.disconnect();
});

const fadeIn = modifier((el) => {
  el.style.opacity = '0';
  el.style.transition = 'opacity 0.55s ease';
  if (el.complete && el.naturalWidth > 0) {
    el.style.opacity = '1';
    return;
  }
  el.addEventListener('load', () => { el.style.opacity = '1'; }, { once: true });
});

export default class SportGalleryComponent extends Component {
  // @args: sport, userId, host

  @service session;
  @service toast;

  @tracked images        = [];
  @tracked isLoading     = false;
  @tracked isLoaded      = false;
  @tracked error         = null;
  @tracked lightboxIndex = null;

  @tracked showUploadModal = false;
  @tracked uploadPreviews  = [];
  @tracked uploadFiles     = [];
  @tracked uploadError     = null;
  @tracked isUploading     = false;

  get currentLightboxSrc() {
    return this.lightboxIndex === null ? null : this.images[this.lightboxIndex];
  }
  get lightboxHasPrev() { return this.lightboxIndex > 0; }
  get lightboxHasNext() { return this.lightboxIndex < this.images.length - 1; }
  get lightboxCounter() {
    return this.lightboxIndex === null ? '' : `${this.lightboxIndex + 1} / ${this.images.length}`;
  }
  get uploadDisabled() { return this.uploadPreviews.length === 0 || this.isUploading; }
  get uploadType()     { return `${this.args.sport}_images`; }

  @action
  async fetchGallery() {
    if (this.isLoading || this.isLoaded) return;
    const { sport, userId } = this.args;
    if (!sport || !userId) return;

    this.isLoading = true;
    this.error     = null;

    try {
      const res = await fetch(
        `${config.APP.API_HOST}/auth_user/get_image/${sport}/${userId}/`,
        { headers: { 'Authorization': `Bearer ${this.session.token}` } }
      );
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json  = await res.json();
      const paths = Array.isArray(json.data) ? json.data : [];
      const host  = (this.args.host ?? '').replace(/\/$/, '');
      this.images  = paths.map(p => `${host}/${p}`);
    } catch (err) {
      this.error = err.message || 'Failed to load gallery';
    } finally {
      this.isLoading = false;
      this.isLoaded  = true;
    }
  }

  @action openLightbox(index) {
    this.lightboxIndex = index;
    document.addEventListener('keydown', this._onKey);
  }

  @action closeLightbox() {
    this.lightboxIndex = null;
    document.removeEventListener('keydown', this._onKey);
  }

  @action prevImage() { if (this.lightboxHasPrev) this.lightboxIndex = this.lightboxIndex - 1; }
  @action nextImage() { if (this.lightboxHasNext) this.lightboxIndex = this.lightboxIndex + 1; }

  @action openUploadModal() {
    this.showUploadModal = true;
  }

  @action closeUploadModal() {
    this.showUploadModal = false;
    this.uploadPreviews  = [];
    this.uploadFiles     = [];
    this.uploadError     = null;
    const input = document.getElementById('gallery-photo-input');
    if (input) input.value = '';
  }

  @action triggerFileInput() {
    document.getElementById('gallery-photo-input').click();
  }

  @action handleFileChange(event) {
    const files = Array.from(event.target.files);
    if (!files.length) return;
    this.uploadError = null;

    const valid = [];
    for (const file of files) {
      if (file.size > 5 * 1024 * 1024) {
        this.uploadError = 'Some files exceed the 5 MB limit and were skipped';
        continue;
      }
      valid.push(file);
    }

    // Replace selection — each file dialog open is a fresh pick
    this.uploadFiles    = valid;
    this.uploadPreviews = [];

    for (const file of valid) {
      const reader = new FileReader();
      reader.onload = (e) => {
        this.uploadPreviews = [...this.uploadPreviews, e.target.result];
      };
      reader.readAsDataURL(file);
    }

    event.target.value = '';
  }

  @action removeUploadAt(index) {
    this.uploadPreviews = this.uploadPreviews.filter((_, i) => i !== index);
    this.uploadFiles    = this.uploadFiles.filter((_, i) => i !== index);
  }

  @action async submitUpload() {
    if (this.uploadDisabled) return;
    this.isUploading = true;
    this.uploadError = null;

    try {
      const { sport } = this.args;

      // Build per-file image/checksum maps for batch initiate
      const imagesMap    = {};
      const checksumsMap = {};
      for (let i = 0; i < this.uploadFiles.length; i++) {
        const key        = `image${i + 1}`;
        const file       = this.uploadFiles[i];
        imagesMap[key]    = file.type.split('/')[1] || 'jpeg';
        checksumsMap[key] = await this._sha256Base64(file);
      }

      // Step 1: initiate batch upload
      const initRes = await fetch(`${config.APP.API_HOST}/auth_user/initiate-upload-auth/`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.session.token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          type: `${sport}_images`,
          images: imagesMap,
          checksums: checksumsMap,
        }),
      });
      if (!initRes.ok) throw new Error(`HTTP ${initRes.status}`);
      const { upload_slots } = await initRes.json();

      // Step 2: PUT each file to its S3 presigned URL
      const objectTokens = [];
      for (let i = 0; i < this.uploadFiles.length; i++) {
        const key  = `image${i + 1}`;
        const slot = upload_slots?.[key];
        if (!slot?.upload_url) throw new Error(`Upload slot missing for ${key}`);

        const s3Res = await fetch(slot.upload_url, {
          method:  'PUT',
          headers: { ...slot.headers, 'x-amz-tagging': 'status=permanent' },
          body:    this.uploadFiles[i],
        });
        if (!s3Res.ok) throw new Error(`S3 upload failed (${s3Res.status})`);
        objectTokens.push(slot.object_token);
      }

      /*/ Step 3: confirm gallery upload
      const confirmRes = await fetch(`${config.APP.API_HOST}/auth_user/upload-sports-galary/`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.session.token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          user_playing_sports: [{ sports_name: sport, player_image: objectTokens }],
        }),
      });
      if (!confirmRes.ok) throw new Error(`HTTP ${confirmRes.status}`);*/

      this.toast.success('Photos uploaded successfully!');
      this.closeUploadModal();
      // Reset so fetchGallery re-fetches fresh data
      this.isLoaded = false;
      await this.fetchGallery();
    } catch (err) {
      this.uploadError = err.message || 'Upload failed';
    } finally {
      this.isUploading = false;
    }
  }

  async _sha256Base64(file) {
    const buf  = await file.arrayBuffer();
    const hash = await crypto.subtle.digest('SHA-256', buf);
    return btoa(String.fromCharCode(...new Uint8Array(hash)));
  }

  _onKey = (e) => {
    if (e.key === 'Escape')     this.closeLightbox();
    if (e.key === 'ArrowLeft')  this.prevImage();
    if (e.key === 'ArrowRight') this.nextImage();
  };

  willDestroy() {
    super.willDestroy(...arguments);
    document.removeEventListener('keydown', this._onKey);
  }

  <template>
    <section
      class="mt-2 px-4 sm:px-6 md:px-10 pb-10"
      {{whenVisible this.fetchGallery}}
    >

      {{! ── Section Header ── }}
      <div class="relative flex items-center justify-between mb-6 pt-2">
        <div class="absolute top-0 left-0 right-0 h-px bg-gradient-to-r from-transparent via-white/10 to-transparent"></div>
        <div class="flex items-center gap-3">
          <div class="relative">
            <div class="absolute inset-0 bg-violet-500/30 rounded-xl blur-md"></div>
            <div class="relative w-11 h-11 rounded-xl bg-gradient-to-br from-violet-500 via-purple-500 to-fuchsia-600 flex items-center justify-center shadow-lg shadow-violet-500/40">
              {{lucideIcon "camera" size=20 class="text-white"}}
            </div>
          </div>
          <div>
            <h3 class="text-xl font-black bg-gradient-to-r from-violet-300 via-purple-200 to-fuchsia-300 bg-clip-text text-transparent tracking-tight">
              Gallery
            </h3>
            <p class="text-[11px] font-semibold text-gray-500 uppercase tracking-widest capitalize">
              {{@sport}} moments
            </p>
          </div>
        </div>
        {{#if this.images.length}}
          <span class="inline-flex items-center gap-1.5 text-xs font-black text-violet-300 bg-violet-500/10 border border-violet-500/25 px-3 py-1.5 rounded-full">
            {{lucideIcon "images" size=12 class="shrink-0"}}
            {{this.images.length}} photos
          </span>
        {{/if}}
      </div>

      {{! ── Loading Skeleton ── }}
      {{#if this.isLoading}}
        <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-2 sm:gap-3">
          <div class="col-span-2 aspect-video rounded-2xl bg-gray-800/80 animate-pulse overflow-hidden relative">
            <div class="absolute inset-0 -translate-x-full animate-[shimmer_1.6s_ease-in-out_infinite] bg-gradient-to-r from-transparent via-white/5 to-transparent"></div>
          </div>
          {{#each (array 1 2 3 4 5 6) as |_|}}
            <div class="aspect-square rounded-xl bg-gray-800/80 animate-pulse overflow-hidden relative">
              <div class="absolute inset-0 -translate-x-full animate-[shimmer_1.6s_ease-in-out_infinite] bg-gradient-to-r from-transparent via-white/5 to-transparent"></div>
            </div>
          {{/each}}
        </div>
      {{/if}}

      {{! ── Loaded: Image Grid ── }}
      {{#if this.isLoaded}}
        <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-2 sm:gap-3">

          {{#each this.images as |imgSrc i|}}

            {{#if (eq i 0)}}
              {{! Featured: 2-col, 16:9 }}
              <div
                class="group col-span-2 relative aspect-video rounded-2xl overflow-hidden cursor-pointer
                       ring-1 ring-white/5 hover:ring-violet-500/50
                       shadow-xl shadow-black/50 hover:shadow-violet-500/20
                       transition-all duration-300"
                role="button"
                aria-label="Open photo 1"
                {{on "click" (fn this.openLightbox 0)}}
              >
                <img src={{imgSrc}} alt="Gallery photo 1" loading="lazy"
                  class="w-full h-full object-cover scale-100 group-hover:scale-105 transition-transform duration-700"
                  {{fadeIn}}
                />
                <div class="absolute inset-0 bg-gradient-to-t from-black/65 via-black/10 to-transparent opacity-70 group-hover:opacity-90 transition-opacity duration-300"></div>
                <div class="absolute top-3 left-3 flex items-center gap-1.5 bg-black/50 backdrop-blur-sm border border-white/10 text-white text-[10px] font-black px-2.5 py-1 rounded-full uppercase tracking-widest">
                  {{lucideIcon "star" size=10 class="text-amber-400"}}
                  Featured
                </div>
                <div class="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity duration-300">
                  <div class="w-14 h-14 rounded-full bg-black/40 backdrop-blur-sm border border-white/20 flex items-center justify-center shadow-2xl">
                    {{lucideIcon "expand" size=22 class="text-white"}}
                  </div>
                </div>
                <div class="absolute bottom-0 left-0 right-0 px-4 py-3 flex items-center justify-between translate-y-full group-hover:translate-y-0 transition-transform duration-300">
                  <span class="text-white text-xs font-bold opacity-80">Photo 1 of {{this.images.length}}</span>
                  <span class="text-white/60 text-[10px] uppercase tracking-widest font-semibold capitalize">{{@sport}}</span>
                </div>
              </div>

            {{else}}
              {{! Thumbnail }}
              <div
                class="group relative aspect-square rounded-xl overflow-hidden cursor-pointer
                       ring-1 ring-white/5 hover:ring-violet-500/40
                       shadow-lg shadow-black/30 hover:shadow-violet-500/15 hover:-translate-y-0.5
                       transition-all duration-200"
                role="button"
                aria-label="Open photo {{i}}"
                {{on "click" (fn this.openLightbox i)}}
              >
                <img src={{imgSrc}} alt="Gallery photo {{i}}" loading="lazy"
                  class="w-full h-full object-cover scale-100 group-hover:scale-110 transition-transform duration-500"
                  {{fadeIn}}
                />
                <div class="absolute inset-0 bg-black/0 group-hover:bg-black/40 transition-colors duration-300"></div>
                <div class="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity duration-200">
                  <div class="w-10 h-10 rounded-full bg-black/40 backdrop-blur-sm border border-white/20 flex items-center justify-center">
                    {{lucideIcon "expand" size=16 class="text-white"}}
                  </div>
                </div>
                <div class="absolute bottom-2 right-2 text-[9px] font-black text-white/80 bg-black/50 backdrop-blur-sm px-1.5 py-0.5 rounded-full opacity-0 group-hover:opacity-100 transition-opacity duration-200">
                  {{i}}
                </div>
              </div>

            {{/if}}
          {{/each}}

          {{! ── Add Photo Tile (always visible) ── }}
          <div
            class="group relative aspect-square rounded-xl cursor-pointer
                   border-2 border-dashed border-white/10 hover:border-violet-500/50
                   bg-gray-800/20 hover:bg-violet-500/5
                   flex flex-col items-center justify-center gap-2
                   transition-all duration-200 hover:-translate-y-0.5"
            role="button"
            aria-label="Add gallery photo"
            {{on "click" this.openUploadModal}}
          >
            <div class="w-10 h-10 rounded-full bg-white/5 border border-white/10 group-hover:bg-violet-500/15 group-hover:border-violet-500/40 flex items-center justify-center transition-all duration-200">
              {{lucideIcon "plus" size=20 class="text-white/30 group-hover:text-violet-400 transition-colors duration-200"}}
            </div>
            <span class="text-[10px] font-semibold text-white/25 group-hover:text-violet-400 uppercase tracking-widest transition-colors duration-200">
              Add Photo
            </span>
          </div>

        </div>
      {{/if}}

      {{! ── Error ── }}
      {{#if this.error}}
        <div class="rounded-xl bg-red-500/5 border border-red-500/20 px-5 py-4 flex items-center gap-3">
          {{lucideIcon "alert-triangle" size=18 class="text-red-400 shrink-0"}}
          <p class="text-sm text-red-400">{{this.error}}</p>
        </div>
      {{/if}}

    </section>

    {{! ── Upload Modal ── }}
    {{#if this.showUploadModal}}
      <div
        class="fixed inset-0 z-[110] flex items-center justify-center p-4"
        role="dialog"
        aria-modal="true"
        aria-label="Upload gallery photos"
      >
        <div class="absolute inset-0 bg-black/80 backdrop-blur-sm" {{on "click" this.closeUploadModal}}></div>

        <div class="relative z-10 w-full max-w-md bg-gray-900 border border-white/10 rounded-2xl shadow-2xl overflow-hidden">

          {{! Modal Header }}
          <div class="flex items-center justify-between px-5 py-4 border-b border-white/8">
            <div class="flex items-center gap-2.5">
              <div class="w-8 h-8 rounded-lg bg-gradient-to-br from-violet-500 to-fuchsia-600 flex items-center justify-center shadow-lg shadow-violet-500/30">
                {{lucideIcon "image-plus" size=15 class="text-white"}}
              </div>
              <div>
                <p class="text-sm font-black text-white">Add Gallery Photos</p>
                <p class="text-[10px] font-semibold text-gray-500 uppercase tracking-widest capitalize">{{@sport}}</p>
              </div>
            </div>
            <button
              type="button"
              aria-label="Close"
              {{on "click" this.closeUploadModal}}
              class="w-8 h-8 rounded-full bg-white/5 hover:bg-white/10 border border-white/10 flex items-center justify-center text-gray-400 hover:text-white transition-colors"
            >
              {{lucideIcon "x" size=16}}
            </button>
          </div>

          {{! Modal Body }}
          <div class="p-5">
            <input
              type="file"
              id="gallery-photo-input"
              accept="image/png,image/jpeg,image/webp"
              multiple
              class="sr-only"
              {{on "change" this.handleFileChange}}
            />

            <ImageUploader
              @label="Gallery Photos"
              @hint="PNG, JPG, WEBP · max 5 MB each"
              @previews={{this.uploadPreviews}}
              @uploadError={{this.uploadError}}
              @inputId="gallery-photo-input"
              @type={{this.uploadType}}
              @onTrigger={{this.triggerFileInput}}
              @onRemoveAt={{this.removeUploadAt}}
            />
          </div>

          {{! Modal Footer }}
          <div class="flex items-center justify-between px-5 py-4 border-t border-white/8">
            {{#if this.uploadPreviews.length}}
              <span class="text-xs font-semibold text-gray-500">
                {{this.uploadPreviews.length}}
                {{if (eq this.uploadPreviews.length 1) "photo" "photos"}} selected
              </span>
            {{else}}
              <span></span>
            {{/if}}
            <div class="flex items-center gap-3">
              <button
                type="button"
                {{on "click" this.closeUploadModal}}
                class="px-4 py-2 rounded-lg text-sm font-semibold text-gray-400 hover:text-white hover:bg-white/5 transition-colors"
              >
                Cancel
              </button>
              <button
                type="button"
                disabled={{this.uploadDisabled}}
                {{on "click" this.submitUpload}}
                class="inline-flex items-center gap-2 px-5 py-2 rounded-lg text-sm font-black text-white
                       bg-gradient-to-r from-violet-600 to-fuchsia-600
                       hover:from-violet-500 hover:to-fuchsia-500
                       disabled:opacity-40 disabled:cursor-not-allowed
                       shadow-lg shadow-violet-500/30 transition-all duration-200"
              >
                {{#if this.isUploading}}
                  {{lucideIcon "loader-2" size=14 class="animate-spin"}}
                  Uploading…
                {{else}}
                  {{lucideIcon "upload" size=14}}
                  Upload
                {{/if}}
              </button>
            </div>
          </div>

        </div>
      </div>
    {{/if}}

    {{! ── Lightbox ── }}
    {{#if this.currentLightboxSrc}}
      <div
        class="fixed inset-0 z-[100] flex items-center justify-center"
        role="dialog"
        aria-modal="true"
        aria-label="Photo viewer"
      >
        <div class="absolute inset-0 bg-black/95 backdrop-blur-sm" {{on "click" this.closeLightbox}}></div>

        <button type="button" aria-label="Close" {{on "click" this.closeLightbox}}
          class="absolute top-4 right-4 z-10 w-10 h-10 rounded-full bg-white/10 hover:bg-white/20 border border-white/10 flex items-center justify-center text-white transition-colors">
          {{lucideIcon "x" size=20}}
        </button>

        <div class="absolute top-4 left-1/2 -translate-x-1/2 z-10 bg-black/60 backdrop-blur-sm border border-white/10 text-white text-xs font-bold px-4 py-1.5 rounded-full">
          {{this.lightboxCounter}}
        </div>

        {{#if this.lightboxHasPrev}}
          <button type="button" aria-label="Previous" {{on "click" this.prevImage}}
            class="absolute left-3 sm:left-6 z-10 w-11 h-11 rounded-full bg-white/10 hover:bg-violet-500/30 border border-white/10 hover:border-violet-500/40 flex items-center justify-center text-white transition-all duration-200 shadow-xl">
            {{lucideIcon "chevron-left" size=22}}
          </button>
        {{/if}}

        {{#if this.lightboxHasNext}}
          <button type="button" aria-label="Next" {{on "click" this.nextImage}}
            class="absolute right-3 sm:right-6 z-10 w-11 h-11 rounded-full bg-white/10 hover:bg-violet-500/30 border border-white/10 hover:border-violet-500/40 flex items-center justify-center text-white transition-all duration-200 shadow-xl">
            {{lucideIcon "chevron-right" size=22}}
          </button>
        {{/if}}

        <div class="relative z-10 w-full max-w-5xl px-16 sm:px-20 flex items-center justify-center">
          <div class="relative w-full">
            <div class="absolute inset-8 bg-violet-500/10 blur-3xl rounded-full pointer-events-none"></div>
            <img src={{this.currentLightboxSrc}} alt="Gallery photo"
              class="relative w-full max-h-[80vh] object-contain rounded-xl shadow-2xl shadow-black/70"
              {{fadeIn}}
            />
          </div>
        </div>

        <div class="absolute bottom-4 left-1/2 -translate-x-1/2 z-10 flex items-center gap-1.5 max-w-[90vw] overflow-x-auto no-scrollbar px-3 py-2 bg-black/60 backdrop-blur-sm border border-white/10 rounded-2xl">
          {{#each this.images as |imgSrc i|}}
            <button type="button" {{on "click" (fn this.openLightbox i)}}
              class="shrink-0 w-10 h-10 rounded-lg overflow-hidden border-2 transition-all duration-150
                {{if (eq this.lightboxIndex i) 'border-violet-400 scale-110 shadow-lg shadow-violet-500/40' 'border-transparent opacity-50 hover:opacity-80'}}"
              aria-label="Go to photo {{i}}">
              <img src={{imgSrc}} alt="" class="w-full h-full object-cover" />
            </button>
          {{/each}}
        </div>

      </div>
    {{/if}}
  </template>
}
