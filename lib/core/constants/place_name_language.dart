/// The language reverse-geocoded place names are stored in.
///
/// A synced per-diver setting (issue #1187). Stored as the ISO 639-1 code,
/// never as a display name. English is the default because every row
/// written before the setting existed was geocoded in English (issue #214),
/// and mixing languages within one logbook splits a country across two
/// statistics buckets. There is deliberately no "follow app language"
/// value: the app language can be `system`, which resolves per device.
/// Instead a fresh install starts in the app language and a later change of
/// app language offers to switch, both through [forAppLocale] (issue #3111).
abstract final class PlaceNameLanguage {
  static const String defaultCode = 'en';

  /// The app's own languages, in the order the language picker lists them.
  static const List<String> supportedCodes = [
    'en',
    'es',
    'fr',
    'de',
    'it',
    'nl',
    'pt',
    'hu',
    'ar',
    'he',
    'zh',
  ];

  /// A supported code, or [defaultCode] for anything else: null, blank, or a
  /// code this build does not know (a synced peer on a newer build could send
  /// one). Case and surrounding whitespace are forgiven first, so a padded or
  /// upper-cased copy of a supported code still counts as that code.
  static String normalize(String? code) {
    final cleaned = code?.trim().toLowerCase();
    return cleaned != null && supportedCodes.contains(cleaned)
        ? cleaned
        : defaultCode;
  }

  /// The place name language matching an app language setting: the setting
  /// itself when it names a language, or for `system` the first of the
  /// device's [deviceLanguageCodes] the app supports, as the app's own locale
  /// resolution picks it. English when nothing matches.
  static String forAppLocale(
    String appLocale,
    Iterable<String> deviceLanguageCodes,
  ) {
    if (appLocale != 'system') return normalize(appLocale);
    for (final code in deviceLanguageCodes) {
      final cleaned = code.trim().toLowerCase();
      if (supportedCodes.contains(cleaned)) return cleaned;
    }
    return defaultCode;
  }
}
