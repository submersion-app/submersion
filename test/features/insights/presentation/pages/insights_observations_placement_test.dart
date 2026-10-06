import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

/// Where the observations strip sits on the Insights landing (#2381): above
/// the phone category list, and at the top of the desktop Overview summary
/// only.
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
    testWidgets('the strip leads the category list', (tester) async {
      await pump(
        tester,
        const InsightsMobileContent(),
        strip([gapObservation(lastDiveId: 'a'), categoryObservation('gas')]),
      );
      final stripTop = tester.getTopLeft(find.byType(ObservationsStrip)).dy;
      final overviewTop = tester.getTopLeft(find.text('Overview')).dy;
      expect(stripTop, lessThan(overviewTop));
      expect(find.text('Observations'), findsOneWidget);
    });

    testWidgets('an empty strip takes no space', (tester) async {
      await pump(tester, const InsightsMobileContent(), strip(const []));
      // A zero-height list child reads as offstage to the default finder;
      // the list still stretches it to full width, so only height counts.
      final finder = find.byType(ObservationsStrip, skipOffstage: false);
      expect(tester.getSize(finder).height, 0);
      expect(find.text('Observations'), findsNothing);
    });
  });

  group('desktop Overview summary', () {
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

    testWidgets('the summary leads with the strip', (tester) async {
      await pump(
        tester,
        const Scaffold(
          body: InsightsOverviewPage(embedded: true, showObservations: true),
        ),
        [
          ...stats(),
          ...strip([gapObservation()]),
        ],
      );
      final stripTop = tester.getTopLeft(find.byType(ObservationsStrip)).dy;
      expect(stripTop, lessThan(tester.getTopLeft(find.text('42')).dy));
    });

    testWidgets('the Overview category detail does not repeat it', (
      tester,
    ) async {
      await pump(
        tester,
        const Scaffold(body: InsightsOverviewPage(embedded: true)),
        [
          ...stats(),
          ...strip([gapObservation()]),
        ],
      );
      expect(find.byType(ObservationsStrip), findsNothing);
    });
  });
}
