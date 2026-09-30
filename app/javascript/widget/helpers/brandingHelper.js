const CJK_CHARACTERS = /[\u3400-\u9fff]/;
const LEGACY_STORE_NAMES = /vibe\s*craft\s*global|global\s*store|storefront/i;

export const hasCjkCharacters = value => CJK_CHARACTERS.test(value || '');

export const isLegacyStoreName = value =>
  !value || LEGACY_STORE_NAMES.test(value) || hasCjkCharacters(value);
