import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Display options live in the page's overflow menu rather than behind their
/// own header button, in both the standalone app bar and the embedded
/// master-detail header.
void main() {
  Future<void> pumpDetail(WidgetTester tester, {bool embedded = false}) async {
    final dive = createTestDiveWithBottomTime();
    final overrides = await getBaseOverrides();

    final router = GoRouter(
      initialLocation: '/detail',
      routes: [
        GoRoute(
          path: '/detail',
          builder: (context, state) => embedded
              ? Scaffold(body: DiveDetailPage(diveId: dive.id, embedded: true))
              : DiveDetailPage(diveId: dive.id),
        ),
      ],
    );

    // The detail page overflows its fixed test viewport; that is not what
    // this test asserts, so swallow only overflow errors.
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) return;
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          diveProvider(dive.id).overrideWith((ref) async => dive),
          diveDataSourcesProvider(
            dive.id,
          ).overrideWith((ref) async => <DiveDataSource>[]),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> chooseDisplayOptions(WidgetTester tester) async {
    // The header overflow menu is the last more_vert on the page (a source
    // bar, when present, renders earlier).
    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Display options'));
    await tester.pumpAndSettle();
  }

  testWidgets('phone overflow lists display options before favorite', (
    tester,
  ) async {
    // Below the compact app-bar width the favorite toggle joins the
    // overflow; display options still lead the list.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);
    await pumpDetail(tester);

    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Display options')).dy,
      lessThan(tester.getTopLeft(find.text('Add to favorites')).dy),
    );
  });

  for (final embedded in [false, true]) {
    final mode = embedded ? 'embedded' : 'standalone';

    testWidgets('$mode header has no display-options button', (tester) async {
      await pumpDetail(tester, embedded: embedded);

      expect(find.byTooltip('Display options'), findsNothing);
    });

    testWidgets('$mode overflow opens the display-options panel', (
      tester,
    ) async {
      await pumpDetail(tester, embedded: embedded);

      expect(find.text('LAYOUT'), findsNothing);

      await chooseDisplayOptions(tester);

      expect(find.text('Display options'), findsNothing);
      expect(find.text('LAYOUT'), findsOneWidget);
      expect(find.byType(ReorderableListView), findsOneWidget);
    });
  }
}
