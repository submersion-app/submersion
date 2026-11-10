import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_app.dart';

/// A routed, localized app around [child] for the species map widget tests,
/// on the repo's base overrides (settings, preferences).
///
/// [prefs] are written into the preferences the overrides hand out, so a
/// test can start with the public layer on. Any location other than `/`
/// renders `page:<location>` and `query:<decoded query>`, so a test can tap
/// a link and assert where it went.
Future<Widget> speciesMapHarness({
  required Widget child,
  List<Override> overrides = const [],
  Map<String, Object> prefs = const {},
}) async {
  final base = await getBaseOverrides();
  final shared = await SharedPreferences.getInstance();
  for (final entry in prefs.entries) {
    final value = entry.value;
    if (value is bool) await shared.setBool(entry.key, value);
    if (value is String) await shared.setString(entry.key, value);
  }
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(body: child),
      ),
      GoRoute(
        path: '/:a/:b',
        builder: (context, state) => Scaffold(
          body: Column(
            children: [
              Text('page:${state.uri}'),
              // Decoded, so a test can tell an id that arrived intact.
              Text('query:${state.uri.queryParameters}'),
            ],
          ),
        ),
      ),
    ],
  );
  return testAppRouter(
    router: router,
    locale: const Locale('en'),
    overrides: [...base, ...overrides],
  );
}
