<script>
const WIDGET_BRAND_NAME = 'VibeCraft Care';

const {
  LOGO_THUMBNAIL: logoThumbnail,
  BRAND_NAME: brandName,
  WIDGET_BRAND_URL: widgetBrandURL,
} = window.globalConfig || {};

export default {
  props: {
    disableBranding: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      globalConfig: {
        brandName,
        logoThumbnail,
        widgetBrandURL,
      },
    };
  },
  computed: {
    displayBrandName() {
      return this.$te('BUBBLE.BRAND_NAME')
        ? this.$t('BUBBLE.BRAND_NAME')
        : WIDGET_BRAND_NAME;
    },
    brandRedirectURL() {
      try {
        const referrerHost = this.$store.getters['appConfig/getReferrerHost'];
        const url = new URL(this.globalConfig.widgetBrandURL);
        if (referrerHost) {
          url.searchParams.set('utm_source', referrerHost);
          url.searchParams.set('utm_medium', 'widget');
        } else {
          url.searchParams.set('utm_medium', 'survey');
        }
        url.searchParams.set('utm_campaign', 'branding');
        return url.toString();
      } catch (e) {
        // Suppressing the error as getter is not defined in some cases
      }
      return '';
    },
  },
};
</script>

<template>
  <div
    v-if="globalConfig.brandName && !disableBranding"
    class="px-0 py-0.5 flex justify-center"
  >
    <a
      :href="brandRedirectURL"
      rel="noreferrer noopener nofollow"
      target="_blank"
      class="branding--link text-n-slate-11 hover:text-n-slate-12 cursor-pointer text-xs inline-flex hover:opacity-100 opacity-90 no-underline justify-center items-center leading-3"
    >
      <span class="branding--mark ltr:mr-1 rtl:ml-1" aria-hidden="true">
        <i class="i-lucide-message-circle" />
      </span>
      <span>
        {{ displayBrandName }}
      </span>
    </a>
  </div>
  <div v-else class="p-3" />
</template>
