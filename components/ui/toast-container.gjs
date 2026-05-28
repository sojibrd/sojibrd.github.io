import Component from '@glimmer/component';
import { service } from '@ember/service';
import { fn } from '@ember/helper';
import ToastItem from './toast-item';

export default class ToastContainer extends Component {
  @service toast;

  dismiss = (id) => {
    this.toast.dismiss(id);
  };

  <template>
    <div
      class="fixed top-5 right-5 z-50 flex flex-col gap-3"
      aria-live="polite"
    >
      {{#each this.toast.toasts as |t|}}
        <ToastItem
          @toast={{t}}
          @onDismiss={{fn this.dismiss t.id}}
        />
      {{/each}}
    </div>
  </template>
}
