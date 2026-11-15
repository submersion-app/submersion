import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/insights/domain/observations/observation.dart';
import 'package:submersion/features/insights/presentation/pages/insights_overview_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_page.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/providers/observations_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/observations_strip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import '../widgets/observation_test_harness.dart';

/// Where the observations strip sits in Insights: the Overview page leads
/// with it on every layout (#4559), and the phone landing list shows none, so
/// its categories start at the top of the screen.
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  List<Override> strip(List<Observation> list) => [
    observationStripProvider.overrideWith((ref) => AsyncData(list)),
  ];

  Future<void> pump(
    WidgetTester tester,
    Widget child,
    List<Override> extra,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...base, ...extra],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('phone landing', () {
    testWidgets('shows no observations strip', (tester) async {
      await pump(
        tester,
        const InsightsMobileContent(),
        strip([gapObservation(lastDiveId: 'a'), categoryObservation('gas')]),
      );
      expect(find.byType(ObservationsStrip, skipOffstage: false), findsNothing);
      expect(find.text('Observations'), findsNothing);
      expect(find.text('Overview'), findsOneWidget);
    });
  });

  group('Overview page', () {
    final fixture = DiveStatistics(
      totalDives: 42,
      totalTimeSeconds: 108000,
      maxDepth: 38.5,
      avgMaxDepth: 18.2,
      totalSites: 7,
      firstDiveDate: DateTime.now().subtract(const Duration(days: 730)),
    );
    List<Override> stats() => [
      diveStatisticsProvider.overrideWith((ref) async => fixture),
      filteredDiveStatisticsProvider.overrideWith((ref) async => fixture),
      filteredDiveRecordsProvider.overrideWith((ref) async => DiveRecords()),
      diveTypeDistributionProvider.overrideWith((ref) async => []),
    ];

    testWidgets('leads with the strip', (tester) async {
      await pump(
        tester,
        const Scaffold(body: InsightsOverviewPage(embedded: true)),
        [
          ...stats(),
          ...strip([gapObservation()]),
        ],
      );
      final stripTop = tester.getTopLeft(find.byType(ObservationsStrip)).dy;
      expect(stripTop, lessThan(tester.getTopLeft(find.text('42')).dy));
      expect(find.text('Observations'), findsOneWidget);
    });

    testWidgets('an empty strip takes no space on the Overview', (
      tester,
    ) async {
      await pump(
        tester,
        const Scaffold(body: InsightsOverviewPage(embedded: true)),
        [...stats(), ...strip(const [])],
      );
      expect(find.text('Observations'), findsNothing);
      final finder = find.byType(ObservationsStrip, skipOffstage: false);
      expect(tester.getSize(finder).height, 0);
    });

    testWidgets('the desktop Insights home still leads with the strip', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: '/insights',
        routes: [
          GoRoute(
            path: '/insights',
            builder: (context, state) => const InsightsPage(),
          ),
        ],
      );
      addTearDown(router.dispose);
      final base = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...base,
            ...stats(),
            ...strip([gapObservation()]),
          ],
          child: MaterialApp.router(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final stripTop = tester.getTopLeft(find.byType(ObservationsStrip)).dy;
      expect(stripTop, lessThan(tester.getTopLeft(find.text('42')).dy));
    });
  });
}
