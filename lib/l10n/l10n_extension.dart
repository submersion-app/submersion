import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Localizations for text produced outside the widget tree -- background
/// syncs and other notifiers that have no [BuildContext] to read.
///
/// [localeTag] is the persisted locale setting: a language code such as
/// `en`, or `system` to follow the platform. Anything unsupported falls
/// back to English, mirroring MaterialApp's own resolution.
AppLocalizations l10nForLocaleTag(String localeTag) {
  final tag = localeTag == 'system'
      ? PlatformDispatcher.instance.locale.languageCode
      : localeTag;
  final code = tag.split(RegExp('[-_]')).first.toLowerCase();
  final isSupported = AppLocalizations.supportedLocales.any(
    (locale) => locale.languageCode == code,
  );
  return lookupAppLocalizations(Locale(isSupported ? code : 'en'));
}
