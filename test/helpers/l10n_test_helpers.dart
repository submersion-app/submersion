import 'package:flutter/material.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Creates a [MaterialApp] with localization delegates configured.
///
/// Use this in widget tests instead of bare `MaterialApp(home: ...)` to ensure
/// `context.l10n` calls resolve correctly. Pass [locale] to pin the resolved
/// language when a test asserts on specific localized strings, so the result
/// does not depend on the host environment's locale.
MaterialApp localizedMaterialApp({required Widget home, Locale? locale}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}
