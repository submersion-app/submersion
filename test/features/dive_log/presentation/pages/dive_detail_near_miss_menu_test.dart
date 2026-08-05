import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Exercises the "Log near-miss" overflow action added by the near-miss log
/// feature: selecting it must navigate to the incident create form with the
/// dive prefilled. Covers the menu item and its onSelected handler in both the
/// full-page and embedded (master-detail) app bars.
void main() {
  Future<void> pumpDetail(WidgetTester tester, {required bool embedded}) async {
    final dive = createTestDiveWithBottomTime();
    final overrides = await getBaseOverrides();

    final router = GoRouter(
      initialLocation: '/detail',
      routes: [
        GoRoute(
          path: '/detail',
          builder: (context, state) =>
              DiveDetailPage(diveId: dive.id, embedded: embedded),
        ),
        GoRoute(
          path: '/incidents/new',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text(
                'NEW INCIDENT diveId=${state.uri.queryParameters['diveId']}',
              ),
            ),
          ),
        ),
      ],
    );

    // The detail page intentionally overflows its fixed test viewport; that is
    // not what this test asserts, so swallow only overflow errors.
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

  Future<void> tapLogNearMiss(WidgetTester tester) async {
    // The header overflow menu is the last more_vert on the page (a source bar,
    // when present, renders earlier).
    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log near-miss'));
    await tester.pumpAndSettle();
  }

  testWidgets('full-page app bar: Log near-miss opens the prefilled form', (
    tester,
  ) async {
    await pumpDetail(tester, embedded: false);
    await tapLogNearMiss(tester);
    expect(find.text('NEW INCIDENT diveId=test-dive-1'), findsOneWidget);
  });

  testWidgets('embedded app bar: Log near-miss opens the prefilled form', (
    tester,
  ) async {
    await pumpDetail(tester, embedded: true);
    await tapLogNearMiss(tester);
    expect(find.text('NEW INCIDENT diveId=test-dive-1'), findsOneWidget);
  });
}
