import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/transfer/presentation/pages/transfer_page.dart';
import 'package:submersion/features/transfer/presentation/widgets/transfer_list_content.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Cloud is its own top-level Transfer section rather than a card nested in
/// Import, so that Garmin Connect / Shearwater Cloud / etc. can each land as
/// a sibling card without another navigation change.
void main() {
  late List<String> pushedRoutes;

  GoRouter buildRouter(String initialLocation) => GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/transfer',
        builder: (context, state) => const TransferPage(),
      ),
      GoRoute(
        path: '/transfer/import-cloud/suunto',
        builder: (context, state) {
          pushedRoutes.add(state.matchedLocation);
          return const Scaffold(body: Text('suunto wizard'));
        },
      ),
    ],
  );

  Future<void> pumpTransfer(
    WidgetTester tester, {
    String initialLocation = '/transfer?selected=cloud',
    Size surfaceSize = const Size(420, 900),
  }) async {
    pushedRoutes = [];
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          locale: const Locale('en'),
          routerConfig: buildRouter(initialLocation),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Cloud is offered as its own transfer section', (tester) async {
    await pumpTransfer(tester, initialLocation: '/transfer');

    final cloudSection = transferSections.firstWhere((s) => s.id == 'cloud');
    expect(cloudSection.icon, Icons.cloud_download);
    expect(find.text('Cloud'), findsWidgets);
    expect(find.text('Import from cloud'), findsWidgets);
  });

  testWidgets('the cloud section renders the Suunto card', (tester) async {
    await pumpTransfer(tester);

    expect(find.text('Suunto'), findsOneWidget);
    expect(
      find.text('Import dives from your Suunto app / app.suunto.com account'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.watch), findsOneWidget);
  });

  testWidgets('tapping the Suunto card opens the flattened wizard route', (
    tester,
  ) async {
    await pumpTransfer(tester);

    await tester.tap(find.text('Suunto'));
    await tester.pumpAndSettle();

    // An imperative push leaves the router's reported uri on the last go(),
    // so assert on the route that actually built instead.
    expect(pushedRoutes, ['/transfer/import-cloud/suunto']);
    expect(find.text('suunto wizard'), findsOneWidget);
  });

  testWidgets('an unknown section id still renders a message', (tester) async {
    await pumpTransfer(tester, initialLocation: '/transfer?selected=nope');

    expect(find.textContaining('nope'), findsOneWidget);
  });
}
