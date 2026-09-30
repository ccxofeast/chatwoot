<script setup>
import { nextTick, onBeforeUnmount, onMounted, ref, toRef } from 'vue';
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
const availabilitySlot = ref(null);

const AVAILABILITY_MAX_LINES = 2;
const AVAILABILITY_LINE_HEIGHT = 1.35;
const AVAILABILITY_BASE_FONT_SIZE = 10;
const AVAILABILITY_MIN_FONT_SIZE = 7;

let resizeObserver;
let mutationObserver;
let fitFrame;

const fitAvailabilityText = () => {
  if (fitFrame) cancelAnimationFrame(fitFrame);

  fitFrame = requestAnimationFrame(() => {
    const node = availabilitySlot.value?.querySelector(
      '.widget-header__availability'
    );
    if (!node || !node.clientWidth) return;

    // Measure the un-clamped text, then restore the fixed two-line presentation.
    node.style.display = 'block';
    node.style.overflow = 'visible';
    node.style.webkitLineClamp = 'unset';
    node.style.minBlockSize = '0';
    node.style.blockSize = 'auto';

    let fontSize = AVAILABILITY_BASE_FONT_SIZE;
    node.style.fontSize = `${fontSize}px`;
    node.style.lineHeight = `${fontSize * AVAILABILITY_LINE_HEIGHT}px`;

    while (
      node.scrollHeight >
        AVAILABILITY_MAX_LINES * fontSize * AVAILABILITY_LINE_HEIGHT &&
      fontSize > AVAILABILITY_MIN_FONT_SIZE
    ) {
      fontSize -= 0.25;
      node.style.fontSize = `${fontSize}px`;
      node.style.lineHeight = `${fontSize * AVAILABILITY_LINE_HEIGHT}px`;
    }

    node.style.removeProperty('display');
    node.style.removeProperty('overflow');
    node.style.removeProperty('-webkit-line-clamp');
    node.style.removeProperty('min-block-size');
    node.style.removeProperty('block-size');
  });
};

const router = useRouter();
const { isOnline } = useAvailability(availableAgents);

const onBackButtonClick = () => {
  router.replace({ name: 'home' });
};

onMounted(() => {
  nextTick(fitAvailabilityText);

  if (typeof ResizeObserver !== 'undefined') {
    resizeObserver = new ResizeObserver(fitAvailabilityText);
    if (availabilitySlot.value) resizeObserver.observe(availabilitySlot.value);
  }

  mutationObserver = new MutationObserver(fitAvailabilityText);
  if (availabilitySlot.value) {
    mutationObserver.observe(availabilitySlot.value, {
      characterData: true,
      childList: true,
      subtree: true,
    });
  }
});

onBeforeUnmount(() => {
  if (fitFrame) cancelAnimationFrame(fitFrame);
  resizeObserver?.disconnect();
  mutationObserver?.disconnect();
});
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
        <div ref="availabilitySlot" class="widget-header__availability-slot">
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
