<script setup>
import HeaderActions from './HeaderActions.vue';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import brandLogo from 'widget/assets/images/vibecraft-icon.svg';

defineProps({
  avatarUrl: {
    type: String,
    default: '',
  },
  introHeading: {
    type: String,
    default: '',
  },
  introBody: {
    type: String,
    default: '',
  },
  showPopoutButton: {
    type: Boolean,
    default: false,
  },
});

const { formatMessage } = useMessageFormatter();
</script>

<template>
  <header
    class="header-expanded pt-6 pb-4 px-5 relative box-border w-full bg-transparent"
  >
    <div class="flex items-center justify-between">
      <div class="widget-header__brand-lockup flex items-center gap-2">
        <img
          class="widget-header__brand-mark widget-header__brand-mark--large"
          :src="brandLogo"
          :alt="$t('BUBBLE.BRAND_NAME')"
        />
        <span class="widget-header__brand-name">{{ $t('BUBBLE.BRAND_NAME') }}</span>
      </div>
      <HeaderActions
        :show-popout-button="showPopoutButton"
        :show-end-conversation-button="false"
      />
    </div>
    <h2
      v-dompurify-html="introHeading"
      class="widget-intro__title mt-4 text-2xl mb-1.5 font-medium text-n-slate-12 line-clamp-4"
    />
    <p
      v-dompurify-html="formatMessage(introBody)"
      class="widget-intro__body text-lg leading-normal text-n-slate-11 [&_a]:underline line-clamp-6"
    />
  </header>
</template>
