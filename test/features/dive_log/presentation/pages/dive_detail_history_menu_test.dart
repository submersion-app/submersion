import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The History entry of the overflow menu opens the change log filtered to
/// this dive, in both the full-page and embedded (master-detail) app bars.
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
          path: '/settings/change-log',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text(
                'CHANGE LOG ${state.uri.queryParameters['rootTable']} '
                '${state.uri.queryParameters['rootId']}',
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

  Future<void> tapHistory(WidgetTester tester) async {
    // The header overflow menu is the last more_vert on the page (a source bar,
    // when present, renders earlier).
    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
  }

  testWidgets('full-page app bar: History opens this dive\'s change log', (
    tester,
  ) async {
    await pumpDetail(tester, embedded: false);
    await tapHistory(tester);
    expect(find.text('CHANGE LOG dives test-dive-1'), findsOneWidget);
  });

  testWidgets('embedded app bar: History opens this dive\'s change log', (
    tester,
  ) async {
    await pumpDetail(tester, embedded: true);
    await tapHistory(tester);
    expect(find.text('CHANGE LOG dives test-dive-1'), findsOneWidget);
  });
}
