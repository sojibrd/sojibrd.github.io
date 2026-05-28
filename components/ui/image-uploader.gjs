import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { service } from '@ember/service';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { onInit } from 'spordium/utils/utility.helper';
import lucideIcon from 'spordium/helpers/lucide-icon';
import { eq } from 'ember-truth-helpers';

const AVATARS = [
  '/assets/avatar/boy (1).webp',
  '/assets/avatar/boy (2).webp',
  '/assets/avatar/boy (3).webp',
  '/assets/avatar/girl (1).webp',
  '/assets/avatar/girl (2).webp',
  '/assets/avatar/cricket_player.png',
  '/assets/avatar/cricket_catch.png',
  '/assets/avatar/cricket_helmet.png',
  '/assets/avatar/football_player.webp',
  '/assets/avatar/badminton.webp',
  '/assets/avatar/baseball.webp',
  '/assets/avatar/female_tennis.webp',
];

/*
  <Ui::ImageUploader
    @type="game_logo"
    @multiple={{false}}
    @initialToken={{this.match.gameLogo}}
    @onChange={{this.onImageUploaded}}
  />

  @type           — upload type sent to initiate-upload API (e.g. "game_logo", "cricket_game")
  @multiple       — allow multiple file selection (default false)
  @initialToken   — existing objectToken to show on load (edit mode); component builds the URL
  @initialPreview — existing full image URL (use instead of @initialToken if you have the URL)
  @aspectRatio    — CSS aspect-ratio value for the preview/upload area (e.g. "1/1" for square,
                    "16/9" for cover, "4/3"). Defaults to a fixed h-36 when omitted.
  @onChange       — called when image changes:
                    single:   ({ objectToken, previewUrl }) on new upload, null on remove
                    multiple: ([{ objectToken, previewUrl }, ...])
*/

export default class ImageUploaderComponent extends Component {
  @service upload;
  @service api;
  @service session;

  @tracked items = []; // [{ previewUrl, objectToken, uploading, error, existing? }]
  @tracked hasCamera = false;
  @tracked showCamera = false;
  @tracked lightboxUrl = null;
  @tracked showAvatarPicker = false;
  @tracked selectedAvatar = null;

  // non-tracked refs, mutated imperatively
  videoElement = null;
  cameraStream = null;

  constructor(owner, args) {
    super(owner, args);
    const token = args.initialToken;
    const preview = args.initialPreview;
    if (token || preview) {
      this.items = [
        {
          previewUrl: token
            ? `${this.api.bucket_Images_Host}/${token}`
            : preview,
          objectToken: null,
          uploading: false,
          error: null,
          existing: true,
        },
      ];
    }
  }

  willDestroy() {
    super.willDestroy();
    this._stopStream();
  }

  get multiple() {
    return this.args.multiple ?? false;
  }

  get uploadType() {
    return this.args.type ?? 'game_logo';
  }

  get aspectRatio() {
    return this.args.aspectRatio ?? null;
  }

  // CSS style strings derived from aspectRatio — avoids need for `and`/`not` helpers in template
  get previewAreaStyle() {
    return this.aspectRatio && !this.multiple
      ? `aspect-ratio:${this.aspectRatio}`
      : null;
  }

  get previewImgStyle() {
    return this.aspectRatio && !this.multiple ? 'height:100%' : null;
  }

  get uploadAreaStyle() {
    return this.aspectRatio ? `aspect-ratio:${this.aspectRatio}` : null;
  }

  // In small/square contexts (aspectRatio set) suppress the 2-col camera split
  get showCameraOption() {
    return this.hasCamera && !this.aspectRatio;
  }

  get showUploadArea() {
    return this.multiple || this.items.length === 0;
  }

  get avatarList() {
    return AVATARS;
  }

  get avatarConfirmDisabled() {
    return !this.selectedAvatar;
  }

  @action
  openAvatarPicker() {
    this.selectedAvatar = null;
    this.showAvatarPicker = true;
  }

  @action
  closeAvatarPicker() {
    this.showAvatarPicker = false;
    this.selectedAvatar = null;
  }

  @action
  selectAvatar(url) {
    this.selectedAvatar = url;
  }

  @action
  async confirmAvatar() {
    if (!this.selectedAvatar) return;
    const url = this.selectedAvatar;
    this.closeAvatarPicker();

    try {
      const response = await fetch(url);
      const blob = await response.blob();
      const ext = url.split('.').pop().split('?')[0];
      const file = new File([blob], `avatar.${ext}`, { type: blob.type || 'image/webp' });

      const item = {
        file,
        previewUrl: url,
        objectToken: null,
        uploading: true,
        error: null,
      };

      this.items = this.multiple ? [...this.items, item] : [item];
      await this._uploadItem(item, file);
    } catch (err) {
      console.error('ImageUploader avatar fetch error:', err);
    }
  }

  @action
  openLightbox(item) {
    if (item.uploading) return;
    this.lightboxUrl = item.previewUrl;
  }

  @action
  closeLightbox() {
    this.lightboxUrl = null;
  }

  @action
  async checkCamera() {
    try {
      const devices = await navigator.mediaDevices.enumerateDevices();
      this.hasCamera = devices.some((d) => d.kind === 'videoinput');
    } catch {
      this.hasCamera = false;
    }
  }

  @action
  async openCamera() {
    try {
      // Acquire the stream before showing the overlay so the video element
      // always has a ready stream the moment it enters the DOM.
      this.cameraStream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'user' },
        audio: false,
      });
      this.showCamera = true;
    } catch (err) {
      console.error('Camera access error:', err);
    }
  }

  @action
  attachStream(videoEl) {
    this.videoElement = videoEl;
    videoEl.srcObject = this.cameraStream;
    videoEl.play().catch(() => {});
  }

  @action
  capturePhoto() {
    const video = this.videoElement;
    if (!video) return;

    const canvas = document.createElement('canvas');
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    const ctx = canvas.getContext('2d');
    // Mirror the captured image to match the mirrored preview
    ctx.translate(canvas.width, 0);
    ctx.scale(-1, 1);
    ctx.drawImage(video, 0, 0);

    canvas.toBlob(
      async (blob) => {
        this._stopStream();
        this.showCamera = false;

        const file = new File([blob], 'camera-capture.jpg', {
          type: 'image/jpeg',
        });
        const item = {
          file,
          previewUrl: URL.createObjectURL(blob),
          objectToken: null,
          uploading: true,
          error: null,
        };

        this.items = this.multiple ? [...this.items, item] : [item];
        await this._uploadItem(item, file);
      },
      'image/jpeg',
      0.92,
    );
  }

  @action
  closeCamera() {
    this._stopStream();
    this.showCamera = false;
  }

  _stopStream() {
    if (this.cameraStream) {
      this.cameraStream.getTracks().forEach((t) => t.stop());
      this.cameraStream = null;
    }
    this.videoElement = null;
  }

  @action
  async onFileChange(event) {
    const files = Array.from(event.target.files ?? []);
    if (!files.length) return;

    const newItems = files.map((file) => ({
      file,
      previewUrl: URL.createObjectURL(file),
      objectToken: null,
      uploading: true,
      error: null,
    }));

    const toUpload = this.multiple ? newItems : [newItems[0]];
    this.items = this.multiple ? [...this.items, ...toUpload] : toUpload;
    await Promise.all(toUpload.map((item) => this._uploadItem(item, item.file)));

    event.target.value = '';
  }

  async _uploadItem(item, file) {
    try {
      const { objectToken, previewUrl } = await this.upload.uploadImage(file, {
        type: this.uploadType,
      });

      if (item.previewUrl?.startsWith('blob:')) URL.revokeObjectURL(item.previewUrl);

      this.items = this.items.map((i) =>
        i === item ? { ...i, previewUrl, objectToken, uploading: false, error: null } : i,
      );
      this._notifyChange();
    } catch (err) {
      console.error('ImageUploader upload error:', err);
      this.items = this.items.map((i) =>
        i === item ? { ...i, uploading: false, error: 'Upload failed' } : i,
      );
    }
  }

  @action
  removeItem(item) {
    if (item.previewUrl?.startsWith('blob:')) URL.revokeObjectURL(item.previewUrl);
    this.items = this.items.filter((i) => i !== item);
    this._notifyChange();
  }

  _notifyChange() {
    const uploaded = this.items.filter((i) => i.objectToken);
    if (this.multiple) {
      this.args.onChange?.(
        uploaded.map(({ objectToken, previewUrl }) => ({ objectToken, previewUrl })),
      );
    } else {
      const first = uploaded[0];
      this.args.onChange?.(
        first ? { objectToken: first.objectToken, previewUrl: first.previewUrl } : null,
      );
      if (first && this.args.updateSession) {
        this.session.updateProfilePic(first.objectToken);
      }
    }
  }

  <template>
    <div class="space-y-3" {{onInit this.checkCamera}}>

      {{! Camera overlay }}
      {{#if this.showCamera}}
        <div
          class="fixed inset-0 z-50 flex items-center justify-center bg-black/85 p-4"
          role="dialog"
          aria-modal="true"
          aria-label="Camera capture"
        >
          <div class="relative w-full max-w-sm bg-black rounded-2xl overflow-hidden shadow-2xl">
            {{! Live video feed — mirrored so it looks natural }}
            <video
              autoplay
              playsinline
              muted
              class="w-full block -scale-x-100"
              {{onInit this.attachStream}}
            ></video>

            {{! Controls }}
            <div
              class="absolute bottom-5 inset-x-0 flex items-center justify-center gap-6 px-4"
            >
              <button
                type="button"
                class="px-5 py-2.5 bg-slate-700/80 hover:bg-slate-600 text-white text-sm font-semibold rounded-full transition-colors"
                {{on "click" this.closeCamera}}
              >
                Cancel
              </button>

              {{! Shutter button }}
              <button
                type="button"
                aria-label="Capture photo"
                class="w-16 h-16 bg-white hover:bg-gray-100 active:scale-95 rounded-full flex items-center justify-center shadow-lg transition-all border-4 border-gray-300"
                {{on "click" this.capturePhoto}}
              >
                {{lucideIcon "camera" size=26 class="text-gray-800"}}
              </button>
            </div>
          </div>
        </div>
      {{/if}}

      {{! Avatar picker overlay }}
      {{#if this.showAvatarPicker}}
        <div
          class="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/85 p-4"
          role="dialog"
          aria-modal="true"
          aria-label="Choose avatar"
        >
          <div class="relative w-full max-w-sm bg-slate-900 rounded-2xl overflow-hidden shadow-2xl">
            <div class="flex items-center justify-between px-4 pt-4 pb-3 border-b border-slate-700/60">
              <span class="text-white text-sm font-semibold">Choose an Avatar</span>
              <button
                type="button"
                aria-label="Close avatar picker"
                class="w-7 h-7 bg-slate-700/80 hover:bg-slate-600 rounded-lg flex items-center justify-center transition-colors"
                {{on "click" this.closeAvatarPicker}}
              >
                {{lucideIcon "x" size=14 class="text-white"}}
              </button>
            </div>

            <div class="grid grid-cols-4 gap-2 p-4 max-h-60 overflow-y-auto">
              {{#each this.avatarList as |avatarUrl|}}
                <button
                  type="button"
                  class="relative aspect-square rounded-xl overflow-hidden border-2 transition-all
                    {{if (eq this.selectedAvatar avatarUrl) 'border-indigo-500 ring-2 ring-indigo-400/50' 'border-transparent hover:border-slate-500'}}"
                  {{on "click" (fn this.selectAvatar avatarUrl)}}
                >
                  <img src={{avatarUrl}} alt="Avatar option" class="w-full h-full object-cover" />
                  {{#if (eq this.selectedAvatar avatarUrl)}}
                    <div class="absolute inset-0 bg-indigo-500/30 flex items-center justify-center">
                      {{lucideIcon "check" size=18 class="text-white drop-shadow"}}
                    </div>
                  {{/if}}
                </button>
              {{/each}}
            </div>

            <div class="flex items-center gap-2 px-4 pb-4 pt-1">
              <button
                type="button"
                class="flex-1 py-2 rounded-xl bg-slate-700/80 hover:bg-slate-600 text-white text-sm font-semibold transition-colors"
                {{on "click" this.closeAvatarPicker}}
              >
                Cancel
              </button>
              <button
                type="button"
                disabled={{this.avatarConfirmDisabled}}
                class="flex-1 py-2 rounded-xl text-white text-sm font-semibold transition-colors
                  {{if this.selectedAvatar 'bg-indigo-600 hover:bg-indigo-500' 'bg-slate-700 opacity-50 cursor-not-allowed'}}"
                {{on "click" this.confirmAvatar}}
              >
                Use This Avatar
              </button>
            </div>
          </div>
        </div>
      {{/if}}

      {{! Lightbox }}
      {{#if this.lightboxUrl}}
        <div
          class="fixed inset-0 z-50 flex items-center justify-center bg-black/90 p-4"
          role="dialog"
          aria-modal="true"
          {{on "click" this.closeLightbox}}
        >
          <img
            src={{this.lightboxUrl}}
            alt="Preview"
            class="max-w-full max-h-full rounded-2xl object-contain shadow-2xl"
          />
          <button
            type="button"
            aria-label="Close preview"
            class="absolute top-4 right-4 w-9 h-9 bg-slate-800/90 hover:bg-slate-700 rounded-xl flex items-center justify-center transition-colors"
            {{on "click" this.closeLightbox}}
          >
            {{lucideIcon "x" size=18 class="text-white"}}
          </button>
        </div>
      {{/if}}

      {{! Previews }}
      {{#if this.items.length}}
        <div class="{{if this.multiple 'grid grid-cols-3 gap-2'}}">
          {{#each this.items as |item|}}
            <div
              class="relative rounded-2xl overflow-hidden
                {{unless this.multiple (unless this.aspectRatio 'h-36')}}"
              style={{this.previewAreaStyle}}
            >
              <img
                src={{item.previewUrl}}
                alt="Preview"
                class="w-full {{if this.multiple 'h-24' (unless this.aspectRatio 'h-36')}} object-cover {{unless item.uploading 'cursor-zoom-in'}}"
                style={{this.previewImgStyle}}
                {{on "click" (fn this.openLightbox item)}}
              />
              <div
                class="absolute inset-0 bg-gradient-to-t from-slate-900/60 to-transparent pointer-events-none"
              ></div>

              {{! Status badge }}
              {{#if item.uploading}}
                <div
                  class="absolute inset-0 bg-slate-900/50 flex items-center justify-center gap-2 pointer-events-none"
                >
                  <div
                    class="w-4 h-4 border-2 border-cyan-400 border-t-transparent rounded-full animate-spin"
                  ></div>
                  <span class="text-white text-xs font-medium">Uploading...</span>
                </div>
              {{else if item.objectToken}}
                <div
                  class="absolute bottom-2 left-2 flex items-center gap-1 bg-green-500/90 px-2 py-0.5 rounded-lg pointer-events-none"
                >
                  {{lucideIcon "check" size=12 class="text-white"}}
                  <span class="text-white text-[10px] font-semibold">Uploaded</span>
                </div>
              {{else if item.error}}
                <div
                  class="absolute bottom-2 left-2 flex items-center gap-1 bg-red-500/90 px-2 py-0.5 rounded-lg pointer-events-none"
                >
                  {{lucideIcon "alert-circle" size=12 class="text-white"}}
                  <span class="text-white text-[10px] font-semibold">Failed</span>
                </div>
              {{else if item.existing}}
                <div
                  class="absolute bottom-2 left-2 flex items-center gap-1 bg-slate-700/90 px-2 py-0.5 rounded-lg pointer-events-none"
                >
                  <span class="text-slate-300 text-[10px] font-semibold">Current</span>
                </div>
              {{/if}}

              {{! Remove button }}
              <button
                type="button"
                aria-label="Remove image"
                class="absolute top-2 right-2 w-7 h-7 bg-red-500/90 hover:bg-red-500 rounded-xl flex items-center justify-center text-white transition-colors shadow-lg"
                {{on "click" (fn this.removeItem item)}}
              >
                {{lucideIcon "x" size=14 class="text-white"}}
              </button>

              {{! Change buttons — single mode only, not while uploading }}
              {{#unless this.multiple}}
                {{#unless item.uploading}}
                  <div class="absolute top-2 left-2 flex items-center gap-1">
                    <label
                      class="w-7 h-7 bg-slate-700/90 hover:bg-slate-600 rounded-lg flex items-center justify-center cursor-pointer transition-colors shadow-lg"
                      aria-label="Upload from device"
                      title="Upload from device"
                    >
                      {{lucideIcon "upload" size=13 class="text-white"}}
                      <input
                        type="file"
                        accept="image/png,image/jpeg"
                        class="hidden"
                        {{on "change" this.onFileChange}}
                      />
                    </label>
                    {{#if this.hasCamera}}
                      <button
                        type="button"
                        class="w-7 h-7 bg-slate-700/90 hover:bg-slate-600 rounded-lg flex items-center justify-center transition-colors shadow-lg"
                        aria-label="Take photo"
                        title="Take photo"
                        {{on "click" this.openCamera}}
                      >
                        {{lucideIcon "camera" size=13 class="text-white"}}
                      </button>
                    {{/if}}
                    <button
                      type="button"
                      class="w-7 h-7 bg-slate-700/90 hover:bg-slate-600 rounded-lg flex items-center justify-center transition-colors shadow-lg"
                      aria-label="Choose avatar"
                      title="Choose avatar"
                      {{on "click" this.openAvatarPicker}}
                    >
                      {{lucideIcon "smile" size=13 class="text-white"}}
                    </button>
                  </div>
                {{/unless}}
              {{/unless}}
            </div>
          {{/each}}
        </div>
      {{/if}}

      {{! Upload / camera area — hidden for single mode when an item already exists }}
      {{#if this.showUploadArea}}
        {{! When aspectRatio is set the area is small/square — skip the 2-col camera split }}
        {{#if this.aspectRatio}}
          {{! Compact square context: single upload area + corner icons }}
          <div class="relative">
            <label
              class="flex flex-col items-center justify-center w-full rounded-2xl border-2 border-dashed border-slate-700/70 bg-slate-800/30 hover:bg-slate-800/60 hover:border-slate-600/70 cursor-pointer transition-all group"
              style={{this.uploadAreaStyle}}
            >
              {{lucideIcon "upload-cloud" size=28 class="text-gray-600 group-hover:text-gray-500 mb-1.5 transition-colors"}}
              <span class="text-gray-500 text-xs group-hover:text-gray-400 transition-colors">
                {{if this.multiple "Add Photos" "Upload Photo"}}
              </span>
              <span class="text-gray-600 text-[10px] mt-0.5">PNG or JPG</span>
              <input
                type="file"
                accept="image/png,image/jpeg"
                multiple={{this.multiple}}
                class="hidden"
                {{on "change" this.onFileChange}}
              />
            </label>
            <div class="absolute bottom-2 right-2 flex items-center gap-1">
              <label
                class="w-7 h-7 bg-slate-700/90 hover:bg-slate-600 rounded-lg flex items-center justify-center cursor-pointer transition-colors shadow-lg"
                aria-label="Upload from device"
                title="Upload from device"
              >
                {{lucideIcon "upload" size=13 class="text-white"}}
                <input
                  type="file"
                  accept="image/png,image/jpeg"
                  multiple={{this.multiple}}
                  class="hidden"
                  {{on "change" this.onFileChange}}
                />
              </label>
              {{#if this.hasCamera}}
                <button
                  type="button"
                  aria-label="Take photo"
                  title="Take photo"
                  class="w-7 h-7 bg-slate-700/90 hover:bg-slate-600 rounded-lg flex items-center justify-center transition-colors shadow-lg"
                  {{on "click" this.openCamera}}
                >
                  {{lucideIcon "camera" size=13 class="text-white"}}
                </button>
              {{/if}}
              <button
                type="button"
                aria-label="Choose avatar"
                title="Choose avatar"
                class="w-7 h-7 bg-slate-700/90 hover:bg-slate-600 rounded-lg flex items-center justify-center transition-colors shadow-lg"
                {{on "click" this.openAvatarPicker}}
              >
                {{lucideIcon "smile" size=13 class="text-white"}}
              </button>
            </div>
          </div>
        {{else}}
          {{! Full-size context: upload + camera + avatar }}
          <div class="{{if this.hasCamera 'grid grid-cols-3 gap-2' 'grid grid-cols-2 gap-2'}}">
            <label
              class="flex flex-col items-center justify-center w-full h-32 rounded-2xl border-2 border-dashed border-slate-700/70 bg-slate-800/30 hover:bg-slate-800/60 hover:border-slate-600/70 cursor-pointer transition-all group"
            >
              {{lucideIcon "upload-cloud" size=32 class="text-gray-600 group-hover:text-gray-500 mb-2 transition-colors"}}
              <span class="text-gray-500 text-sm group-hover:text-gray-400 transition-colors">
                {{if this.multiple "Add Photos" "Upload Photo"}}
              </span>
              <span class="text-gray-600 text-xs mt-0.5">PNG or JPG</span>
              <input
                type="file"
                accept="image/png,image/jpeg"
                multiple={{this.multiple}}
                class="hidden"
                {{on "change" this.onFileChange}}
              />
            </label>
            {{#if this.hasCamera}}
              <button
                type="button"
                class="flex flex-col items-center justify-center w-full h-32 rounded-2xl border-2 border-dashed border-slate-700/70 bg-slate-800/30 hover:bg-slate-800/60 hover:border-slate-600/70 cursor-pointer transition-all group"
                {{on "click" this.openCamera}}
              >
                {{lucideIcon "camera" size=32 class="text-gray-600 group-hover:text-gray-500 mb-2 transition-colors"}}
                <span class="text-gray-500 text-sm group-hover:text-gray-400 transition-colors">
                  Take Photo
                </span>
                <span class="text-gray-600 text-xs mt-0.5">Use Camera</span>
              </button>
            {{/if}}
            <button
              type="button"
              class="flex flex-col items-center justify-center w-full h-32 rounded-2xl border-2 border-dashed border-slate-700/70 bg-slate-800/30 hover:bg-slate-800/60 hover:border-slate-600/70 cursor-pointer transition-all group"
              {{on "click" this.openAvatarPicker}}
            >
              {{lucideIcon "smile" size=32 class="text-gray-600 group-hover:text-gray-500 mb-2 transition-colors"}}
              <span class="text-gray-500 text-sm group-hover:text-gray-400 transition-colors">
                Choose Avatar
              </span>
              <span class="text-gray-600 text-xs mt-0.5">Pick from list</span>
            </button>
          </div>
        {{/if}}
      {{/if}}

    </div>
  </template>
}
