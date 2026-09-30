<script setup>
import { toRef } from 'vue';
import { useRouter } from 'vue-router';
import FluentIcon from 'shared/components/FluentIcon/Index.vue';
import HeaderActions from './HeaderActions.vue';
import AvailabilityContainer from 'widget/components/Availability/AvailabilityContainer.vue';
import { useAvailability } from 'widget/composables/useAvailability';
import brandLogo from 'widget/assets/images/vibecraft-icon.svg';

const props = defineProps({
  avatarUrl: { type: String, default: '' },
  title: { type: String, default: '' },
  showPopoutButton: { type: Boolean, default: false },
  showBackButton: { type: Boolean, default: false },
  availableAgents: { type: Array, default: () => [] },
});

const availableAgents = toRef(props, 'availableAgents');

const router = useRouter();
const { isOnline } = useAvailability(availableAgents);

const onBackButtonClick = () => {
  router.replace({ name: 'home' });
};
</script>

<template>
  <header class="flex min-w-0 justify-between w-full p-5 bg-n-background gap-2">
    <div class="flex min-w-0 flex-1 items-center">
      <button
        v-if="showBackButton"
        class="px-2 ltr:-ml-3 rtl:-mr-3"
        @click="onBackButtonClick"
      >
        <FluentIcon
          icon="chevron-left"
          size="24"
          class="text-n-slate-12 rtl:rotate-180"
        />
      </button>
      <img
        class="widget-header__brand-mark ltr:mr-3 rtl:ml-3"
        :src="brandLogo"
        :alt="$t('BUBBLE.BRAND_NAME')"
      />
      <div class="widget-header__details flex min-w-0 flex-1 flex-col gap-1">
        <div
          class="widget-header__title flex items-center text-base font-medium leading-4 text-n-slate-12"
        >
          <span
            v-dompurify-html="title || $t('BUBBLE.BRAND_NAME')"
            class="ltr:mr-1 rtl:ml-1"
          />
          <div
            :class="`h-2 w-2 rounded-full
              ${isOnline ? 'bg-n-teal-10' : 'hidden'}`"
          />
        </div>
        <div class="widget-header__availability-slot">
          <AvailabilityContainer
            :agents="availableAgents"
            :show-header="false"
            :show-avatars="false"
            text-classes="widget-header__availability"
          />
        </div>
      </div>
    </div>
    <HeaderActions class="shrink-0" :show-popout-button="showPopoutButton" />
  </header>
</template>
