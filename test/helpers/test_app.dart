import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Creates a [ProviderScope]-wrapped [MaterialApp] with localization delegates
/// configured.
///
/// Use this in widget tests to ensure `context.l10n` calls and Riverpod
/// providers resolve correctly. Pass provider [overrides] to stub out
/// providers that would otherwise require a database or platform channel.
///
/// The [overrides] list is forwarded directly to [ProviderScope.overrides].
/// Callers should pass the return values of `.overrideWithValue(...)` or
/// `.overrideWith(...)` -- the Riverpod `Override` type is sealed and not
/// re-exported, so we accept `dynamic` here.
Widget testApp({required Widget child, List<dynamic>? overrides}) {
  return ProviderScope(
    overrides: overrides?.cast() ?? [],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}
