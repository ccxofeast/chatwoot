<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { getWidgetLocaleStorageKey } from 'widget/helpers/urlParamsHelper';

const LANGUAGE_OPTIONS = [
  { code: 'zh_CN', baseCode: 'zh', shortLabel: '中文', label: '简体中文' },
  { code: 'en', baseCode: 'en', shortLabel: 'EN', label: 'English' },
  { code: 'fr', baseCode: 'fr', shortLabel: 'FR', label: 'Français' },
  { code: 'ru', baseCode: 'ru', shortLabel: 'RU', label: 'Русский' },
  { code: 'es', baseCode: 'es', shortLabel: 'ES', label: 'Español' },
];

const { locale, t } = useI18n({ useScope: 'global' });
const store = useStore();

const enabledLanguageCodes = computed(() => {
  const enabledLanguages = window.chatwootWebChannel?.enabledLanguages || [];
  return new Set(
    enabledLanguages.flatMap(language =>
      [language.iso_639_1_code, language.code].filter(Boolean)
    )
  );
});

const languageOptions = computed(() => {
  const enabledCodes = enabledLanguageCodes.value;
  const configuredOptions = LANGUAGE_OPTIONS.filter(
    language =>
      enabledCodes.has(language.code) || enabledCodes.has(language.baseCode)
  );

  return configuredOptions.length ? configuredOptions : LANGUAGE_OPTIONS;
});

const selectedLanguageCode = computed(() => {
  const currentLocale = locale.value || 'en';
  const currentLanguage = languageOptions.value.find(
    language =>
      language.code === currentLocale || language.baseCode === currentLocale
  );
  return currentLanguage?.code || languageOptions.value[0]?.code || 'en';
});

const selectedLanguage = computed(
  () =>
    languageOptions.value.find(
      language => language.code === selectedLanguageCode.value
    ) || languageOptions.value[0]
);

const persistLocale = code => {
  try {
    window.localStorage.setItem(getWidgetLocaleStorageKey(), code);
  } catch (error) {
    // Private browsing and embedded webviews can make localStorage unavailable.
  }
};

const setLanguage = code => {
  const selectedOption = languageOptions.value.find(
    language => language.code === code
  );
  if (!selectedOption) return;

  locale.value = selectedOption.code;
  document.documentElement.lang = selectedOption.code.replace('_', '-');
  persistLocale(selectedOption.code);

  store.dispatch('conversation/setCustomAttributes', {
    preferred_language: selectedOption.code,
  });
};
</script>

<template>
  <label
    v-if="languageOptions.length > 1"
    class="language-selector"
    :aria-label="t('LANGUAGE_SELECTOR.ARIA_LABEL')"
  >
    <i class="i-lucide-languages language-selector__icon" aria-hidden="true" />
    <span class="sr-only">{{ t('LANGUAGE_SELECTOR.LABEL') }}</span>
    <select
      class="reset-base language-selector__select"
      :value="selectedLanguageCode"
      :aria-label="t('LANGUAGE_SELECTOR.ARIA_LABEL')"
      @change="setLanguage($event.target.value)"
    >
      <option
        v-for="language in languageOptions"
        :key="language.code"
        :value="language.code"
      >
        {{ language.label }}
      </option>
    </select>
    <span class="language-selector__value" aria-hidden="true">
      {{ selectedLanguage.shortLabel }}
    </span>
    <i
      class="i-lucide-chevron-down language-selector__chevron"
      aria-hidden="true"
    />
  </label>
</template>
