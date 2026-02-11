import 'package:flutter/material.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Creates a [MaterialApp] with localization delegates configured.
///
/// Use this in widget tests instead of bare `MaterialApp(home: ...)` to ensure
/// `context.l10n` calls resolve correctly.
MaterialApp localizedMaterialApp({required Widget home}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}
