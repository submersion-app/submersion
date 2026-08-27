import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
/// Pass [locale] to pin the UI language deterministically (defaults to
/// MaterialApp's platform-locale resolution). Useful when a test drives the
/// device locale for other reasons but still asserts on English labels.
Widget testApp({
  required Widget child,
  List<dynamic>? overrides,
  Locale? locale,
}) {
  return ProviderScope(
    overrides: overrides?.cast() ?? [],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

/// Like [testApp] but hosts [child] inside a nested navigator holding a single
/// route, reproducing the app's master-detail (tablet) shape.
///
/// In the real app the `ShellRoute` declares no `navigatorKey`, so GoRouter
/// builds its own navigator for the shell. On a master-detail viewport a page
/// renders *embedded* in the shell's single route rather than on a pushed route
/// of its own. [testApp] instead puts the child straight under
/// `MaterialApp.home`, where `Navigator.of(context)` and the root navigator are
/// the same object -- which hides any code that pops the wrong navigator.
///
/// Use this whenever a widget shows a dialog (`showDialog` defaults to
/// `useRootNavigator: true`) and later pops it, so the test can tell the two
/// navigators apart. [navigatorKey] exposes the nested navigator for assertions.
Widget testAppInShell({
  required Widget child,
  GlobalKey<NavigatorState>? navigatorKey,
  List<dynamic>? overrides,
  Locale? locale,
}) {
  return ProviderScope(
    overrides: overrides?.cast() ?? [],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Navigator(
        key: navigatorKey,
        onGenerateRoute: (_) =>
            MaterialPageRoute<void>(builder: (_) => Scaffold(body: child)),
      ),
    ),
  );
}

/// Like [testApp] but backed by a [GoRouter], so widgets that call
/// `context.go(...)` can be exercised end to end in a test.
Widget testAppRouter({
  required GoRouter router,
  List<dynamic>? overrides,
  Locale? locale,
}) {
  return ProviderScope(
    overrides: overrides?.cast() ?? [],
    child: MaterialApp.router(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}
