import Component from '@glimmer/component';
import { on } from '@ember/modifier';
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import lucideIcon from 'spordium/helpers/lucide-icon';

// @arg {String}   coverPhotoPreview   — current preview URL (nullable)
// @arg {Function} onPhotoUpload       — (file) => Promise<{ previewUrl, objectToken }>
export default class CoverPhoto extends Component {
  @tracked uploading = false;
  @tracked error = null;

  @action
  async onChange(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    this.uploading = true;
    this.error = null;
    try {
      const base64 = await this.#toBase64(file);
      await this.args.onPhotoUpload(base64);
    } catch {
      this.error = 'Upload failed. Please try again.';
    } finally {
      this.uploading = false;
    }
  }

  #toBase64(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result); // "data:image/png;base64,..."
      reader.onerror = reject;
      reader.readAsDataURL(file);
    });
  }

  <template>
    <div>
      <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-1.5">
        Cover Photo
      </label>
      <p class="text-xs text-gray-400 mb-2">
        Recommended 1920×1080 px · Max 200 KB · PNG or JPG
      </p>

      {{#if @coverPhotoPreview}}
        <div class="relative rounded-2xl overflow-hidden h-48 bg-gray-100 dark:bg-gray-700 group">
          <img src={{@coverPhotoPreview}} alt="Cover preview" class="w-full h-full object-cover" />
          <div class="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
            <label class="cursor-pointer px-4 py-2 text-sm font-semibold text-white bg-white/20 backdrop-blur-sm rounded-xl hover:bg-white/30 transition-colors">
              {{lucideIcon "camera" class="w-4 h-4 inline mr-1"}}
              Change Photo
              <input type="file" accept="image/*" class="hidden" {{on "change" this.onChange}} />
            </label>
          </div>
        </div>
      {{else}}
        <label class="block cursor-pointer">
          <div class="flex flex-col items-center justify-center h-40 rounded-2xl border-2 border-dashed border-gray-300 dark:border-gray-600 hover:border-blue-400 dark:hover:border-blue-500 bg-gray-50 dark:bg-gray-800/50 transition-colors">
            {{#if this.uploading}}
              <div class="w-6 h-6 border-2 border-blue-500 border-t-transparent rounded-full animate-spin"></div>
              <p class="mt-2 text-sm text-gray-500">Uploading…</p>
            {{else}}
              {{lucideIcon "image-plus" class="w-8 h-8 text-gray-400 mb-2"}}
              <p class="text-sm font-medium text-gray-600 dark:text-gray-400">
                Click to upload cover photo
              </p>
              <p class="text-xs text-gray-400 mt-0.5">PNG or JPG · max 200 KB</p>
            {{/if}}
          </div>
          <input type="file" accept="image/*" class="hidden" {{on "change" this.onChange}} />
        </label>
      {{/if}}

      {{#if this.error}}
        <p class="text-xs text-red-500 mt-1">{{this.error}}</p>
      {{/if}}
    </div>
  </template>
}
