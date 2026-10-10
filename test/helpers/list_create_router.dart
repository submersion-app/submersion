import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Text shown by the stand-in full-page create route.
const kFullPageCreateForm = 'full-page create form';

/// Pumps a list section's [content] as the page at [listPath] inside a router,
/// with a `new` child route standing in for the full-page create form, on a
/// [width]-wide window. Returns the router so a test can read where a create
/// button sent it: `<listPath>/new` on narrow widths, `<listPath>?mode=new`
/// beside a detail pane.
Future<GoRouter> pumpListInCreateRouter(
  WidgetTester tester, {
  required List<dynamic> overrides,
  required Widget content,
  required String listPath,
  required double width,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final router = GoRouter(
    initialLocation: listPath,
    routes: [
      GoRoute(
        path: listPath,
        builder: (context, state) => Scaffold(body: content),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) =>
                const Scaffold(body: Text(kFullPageCreateForm)),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}
