# Chinese (Simplified) Localization

**Date:** 2026-03-29
**Issue:** https://github.com/submersion-app/submersion/issues/104

## Summary

Add Simplified Chinese (`zh`) as the 11th supported language in Submersion. This follows the same pattern used for all existing translations: a complete ARB file with all keys translated, plus a locale option in the language settings page.

## Scope

### Files to create

| File | Description |
|------|-------------|
| `lib/l10n/arb/app_zh.arb` | Simplified Chinese translations for all 4,378 keys |

### Files to modify

| File | Change |
|------|--------|
| `lib/features/settings/presentation/pages/language_settings_page.dart` | Add `_LocaleOption(code: 'zh', nativeName: '中文', englishName: 'Chinese')` to `supportedLocales` list |

### Files regenerated

| File | Trigger |
|------|---------|
| `lib/l10n/arb/app_localizations.dart` | `flutter gen-l10n` |
| `lib/l10n/arb/app_localizations_zh.dart` | `flutter gen-l10n` |

## No architectural changes

The existing localization infrastructure handles this automatically:

- `l10n.yaml` picks up new ARB files from `lib/l10n/arb/`
- `AppLocalizations` regenerates with the new locale
- `resolveAppLocale()` in `app.dart` matches `zh` system locales
- The locale provider and settings persistence work for any locale code
- Flutter's text rendering handles CJK characters natively
- The `intl` package provides Chinese date/number formatting via the `zh` locale

## Translation conventions

- **Full Chinese character translations** -- no English loanwords for dive terminology
- All ICU message syntax preserved (plurals, selects, placeholders)
- Metadata `@`-entries included only where the English ARB defines placeholders

### Dive terminology reference

| English | Chinese |
|---------|---------|
| BCD (Buoyancy Control Device) | 浮力控制装置 |
| Nitrox | 高氧空气 |
| Trimix | 三混气 |
| Dive buddy | 潜伴 |
| Regulator | 调节器 |
| Wetsuit | 湿衣 |
| Drysuit | 干衣 |
| Logbook | 潜水日志 |

## ARB file format

```json
{
  "@@locale": "zh",
  "@@last_modified": "2026-03-29",
  "key_name": "中文翻译",
  ...
}
```

Keys are alphabetically ordered, matching the convention of other translation files.

## Verification

1. `flutter gen-l10n` -- confirms ARB parses without errors
2. `flutter analyze` -- catches codegen issues
3. `flutter test` -- ensures no regressions
