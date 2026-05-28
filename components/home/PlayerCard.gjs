import Component from '@glimmer/component';

export default class PlayerCard extends Component {
  <template>
    <div class="flex items-center rounded-lg px-2 py-2 w-full min-h-[56px]">
      <img
        src={{@avatarUrl}}
        alt="Player Avatar"
        class="w-10 h-10 rounded-full object-cover border border-white/20 mr-3"
      />
      <div class="flex-1 min-w-0">
        <div class="flex items-center justify-between">
          <span class="font-medium text-[13px] text-white truncate">{{@name}}</span>
          {{#if @rank}}
            <span class="text-[10px] font-semibold text-white/60">#{{@rank}}</span>
          {{/if}}
        </div>
        <div class="flex items-center justify-between mt-0.5">
          <span class="text-[11px] text-white/50">{{@position}}</span>
          <span class="text-[13px] font-semibold text-white">{{@statValue}}<span class="text-[10px] font-normal text-white/40 ml-0.5 align-top">{{@statLabel}}</span></span>
        </div>
      </div>
    </div>
  </template>
}
