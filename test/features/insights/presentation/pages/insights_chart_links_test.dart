import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/domain/calendar_day_matrix.dart';
import 'package:submersion/features/insights/domain/tank_configuration/tank_configuration.dart';
import 'package:submersion/features/insights/presentation/pages/insights_conditions_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_gas_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_overview_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_progression_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_social_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_time_patterns_page.dart';
import 'package:submersion/features/insights/presentation/providers/conditions_stats_providers.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_charts.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../recording_insights_repository.dart';

/// Issue #3805: each chart's rows reach the dive list with the right
/// category. What a tap does is `chart_selection_test`'s; that each filter
/// selects the dives counted is `insights_repository_chart_dives_test`'s.
void main() {
  late RecordingInsightsRepository repository;
  late ProviderContainer container;

  setUp(() => repository = RecordingInsightsRepository());

  Future<void> pumpPage(
    WidgetTester tester,
    Widget page,
    List<dynamic> overrides,
  ) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/insights',
      routes: [
        GoRoute(
          path: '/insights',
          builder: (_, _) => Scaffold(body: page),
        ),
        GoRoute(path: '/dives', builder: (_, _) => const Text('dive list')),
      ],
    );
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        locale: const Locale('en'),
        overrides: [
          ...base,
          insightsRepositoryProvider.overrideWithValue(repository),
          ...overrides.cast(),
        ],
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(tester.element(find.byWidget(page)));
  }

  Finder inCard(String title, Finder matching) => find.descendant(
    of: find.ancestor(
      of: find.text(title),
      matching: find.byType(StatSectionCard),
    ),
    matching: matching,
  );

  void expectOpened(WidgetTester tester, String label, QueryNode query) {
    expect(find.text('dive list'), findsOneWidget);
    expect(container.read(diveFilterProvider).diveIdsLabel, label);
    expect(repository.lastFilter?.query, query);
  }

  ConditionNode condition(String field, QueryOp op, QueryValue? value) =>
      ConditionNode(FieldPath([field]), op, value);

  group('Time Patterns', () {
    List<dynamic> overrides() => [
      divesByDayOfWeekProvider.overrideWith(
        (ref) async => const [(dayOfWeek: 6, count: 142)],
      ),
      divesByTimeOfDayProvider.overrideWith(
        (ref) async => TimeOfDayDistribution.empty,
      ),
      divesBySeasonProvider.overrideWith(
        (ref) async => const [(month: 6, count: 20)],
      ),
      divesByCalendarDayProvider.overrideWith(
        (ref) async => CalendarDayMatrix.fromCounts(const []),
      ),
      surfaceIntervalStatsProvider.overrideWith(
        (ref) async => throw StateError('not under test'),
      ),
    ];

    testWidgets('a day opens that weekday', (tester) async {
      await pumpPage(
        tester,
        const InsightsTimePatternsPage(embedded: true),
        overrides(),
      );

      final chart = tester.widget<CategoryBarChart>(
        inCard('Dives by Day of Week', find.byType(CategoryBarChart)),
      );
      await chart.onOpenBar!(6);
      await tester.pumpAndSettle();

      expectOpened(
        tester,
        'Dives by Day of Week: ${chart.data[6].label}',
        condition('weekday', QueryOp.eq, const EnumValue('saturday')),
      );
    });

    testWidgets('a month opens that month', (tester) async {
      await pumpPage(
        tester,
        const InsightsTimePatternsPage(embedded: true),
        overrides(),
      );

      final chart = tester.widget<CategoryBarChart>(
        inCard('Seasonal Patterns', find.byType(CategoryBarChart)),
      );
      await chart.onOpenBar!(5);
      await tester.pumpAndSettle();

      expectOpened(
        tester,
        'Seasonal Patterns: ${chart.data[5].label}',
        condition('month', QueryOp.eq, const NumberValue(6, null)),
      );
    });
  });

  testWidgets('Time Patterns: a time of day opens the dives counted', (
    tester,
  ) async {
    await pumpPage(tester, const InsightsTimePatternsPage(embedded: true), [
      divesByDayOfWeekProvider.overrideWith((ref) async => const []),
      divesBySeasonProvider.overrideWith((ref) async => const []),
      divesByCalendarDayProvider.overrideWith(
        (ref) async => CalendarDayMatrix.fromCounts(const []),
      ),
      surfaceIntervalStatsProvider.overrideWith(
        (ref) async => throw StateError('not under test'),
      ),
      divesByTimeOfDayProvider.overrideWith(
        (ref) async => TimeOfDayDistribution(
          segments: [
            DistributionSegment(label: 'Dusk', count: 2, percentage: 100),
          ],
          divesWithoutLocation: 0,
          diveIdsByBucket: const {
            'Dusk': ['a', 'b'],
          },
        ),
      ),
    ]);

    final chart = tester.widget<DistributionPieChart>(
      inCard('Dives by Time of Day', find.byType(DistributionPieChart)),
    );
    await chart.onOpenSegment!(0);
    await tester.pumpAndSettle();

    final filter = container.read(diveFilterProvider);
    expect(filter.diveIds, ['a', 'b']);
    expect(
      filter.diveIdsLabel,
      'Dives by Time of Day: ${chart.data.single.label}',
    );
  });

  testWidgets('Progression: a year opens that year', (tester) async {
    await pumpPage(tester, const InsightsProgressionPage(embedded: true), [
      depthProgressionTrendProvider.overrideWith((ref) async => const []),
      runtimeTrendProvider.overrideWith((ref) async => const []),
      bottomTimeTrendProvider.overrideWith((ref) async => const []),
      divesPerYearProvider.overrideWith(
        (ref) async => const [(year: 2024, count: 80)],
      ),
    ]);

    final chart = tester.widget<CategoryBarChart>(
      inCard('Dives Per Year', find.byType(CategoryBarChart)),
    );
    await chart.onOpenBar!(0);
    await tester.pumpAndSettle();

    expectOpened(
      tester,
      'Dives Per Year: 2024',
      condition('year', QueryOp.eq, const NumberValue(2024, null)),
    );
  });

  group('Conditions', () {
    List<dynamic> overrides() => [
      conditionsRowsProvider.overrideWith((ref) async => const []),
      visibilityDistributionProvider.overrideWith((ref) async => const []),
      siteTypeDistributionProvider.overrideWith((ref) async => const []),
      waterTypeDistributionProvider.overrideWith(
        (ref) async => [
          DistributionSegment(
            label: kNotRecordedDistributionKey,
            count: 12,
            percentage: 100,
          ),
        ],
      ),
      entryMethodDistributionProvider.overrideWith(
        (ref) async => [
          DistributionSegment(label: 'boat', count: 9, percentage: 100),
        ],
      ),
    ];

    testWidgets('Not recorded opens the dives with no water type', (
      tester,
    ) async {
      await pumpPage(
        tester,
        const InsightsConditionsPage(embedded: true),
        overrides(),
      );

      final chart = tester.widget<DistributionPieChart>(
        inCard('Water Type', find.byType(DistributionPieChart)),
      );
      await chart.onOpenSegment!(0);
      await tester.pumpAndSettle();

      expectOpened(
        tester,
        'Water Type: Not recorded',
        condition('waterType', QueryOp.isEmpty, null),
      );
    });

    testWidgets('a water temperature band opens the dives binned in it', (
      tester,
    ) async {
      repository.bandPerDive = const {'cold': 0, 'warm': 2, 'warmer': 2};
      await pumpPage(tester, const InsightsConditionsPage(embedded: true), [
        ...overrides(),
        waterTempBandDistributionProvider.overrideWith(
          (ref) async => const [
            (lower: null, upper: 10, count: 1),
            (lower: 10, upper: 20, count: 0),
            (lower: 20, upper: null, count: 2),
          ],
        ),
        waterTempBandMetricsProvider.overrideWith((ref) async => const []),
      ]);

      final chart = tester.widget<CategoryBarChart>(
        inCard('Dives by Water Temperature', find.byType(CategoryBarChart)),
      );
      await chart.onOpenBar!(2);
      await tester.pumpAndSettle();

      expect(find.text('dive list'), findsOneWidget);
      expect(container.read(diveFilterProvider).diveIds, ['warm', 'warmer']);
    });

    testWidgets('an entry method opens that method', (tester) async {
      await pumpPage(
        tester,
        const InsightsConditionsPage(embedded: true),
        overrides(),
      );

      final chart = tester.widget<CategoryBarChart>(
        inCard('Entry Method', find.byType(CategoryBarChart)),
      );
      await chart.onOpenBar!(0);
      await tester.pumpAndSettle();

      expectOpened(
        tester,
        'Entry Method: ${chart.data[0].label}',
        condition('entryMethod', QueryOp.eq, const EnumValue('boat')),
      );
    });
  });

  group('charts with their own query', () {
    List<dynamic> conditions() => [
      conditionsRowsProvider.overrideWith((ref) async => const []),
      waterTypeDistributionProvider.overrideWith((ref) async => const []),
      entryMethodDistributionProvider.overrideWith((ref) async => const []),
      visibilityDistributionProvider.overrideWith(
        (ref) async => [
          DistributionSegment(label: 'good', count: 3, percentage: 100),
        ],
      ),
      siteTypeDistributionProvider.overrideWith(
        (ref) async => [
          DistributionSegment(
            label: 'Reef',
            count: 2,
            percentage: 100,
            key: 'custom-id',
          ),
        ],
      ),
    ];

    testWidgets('a visibility segment asks for its key', (tester) async {
      await pumpPage(
        tester,
        const InsightsConditionsPage(embedded: true),
        conditions(),
      );

      final chart = tester.widget<DistributionPieChart>(
        inCard('Visibility Distribution', find.byType(DistributionPieChart)),
      );
      await chart.onOpenSegment!(0);
      await tester.pumpAndSettle();

      expect(repository.lastAsked, 'visibility:good');
    });

    testWidgets('a site type asks for its id, not its name', (tester) async {
      await pumpPage(
        tester,
        const InsightsConditionsPage(embedded: true),
        conditions(),
      );

      await tester.ensureVisible(find.text('Reef'));
      await tester.tap(find.text('Reef'));
      await tester.pumpAndSettle();

      expect(repository.lastAsked, 'siteType:custom-id');
    });

    testWidgets('a suit bar asks for its bucket', (tester) async {
      await pumpPage(tester, const InsightsProgressionPage(embedded: true), [
        depthProgressionTrendProvider.overrideWith((ref) async => const []),
        runtimeTrendProvider.overrideWith((ref) async => const []),
        bottomTimeTrendProvider.overrideWith((ref) async => const []),
        divesBySuitThicknessProvider.overrideWith(
          (ref) async => (
            byThickness: const [(mm: 5.0, count: 4)],
            unknownThicknessCount: 1,
            drysuitCount: 2,
          ),
        ),
      ]);

      final chart = tester.widget<CategoryBarChart>(
        inCard('Dives by Suit Thickness', find.byType(CategoryBarChart)),
      );
      await chart.onOpenBar!(0);
      await tester.pumpAndSettle();
      expect(repository.lastAsked, 'suit:mm:5.0');
    });

    testWidgets('Not recorded opens its own slice on Solo vs Buddy', (
      tester,
    ) async {
      await pumpPage(tester, const InsightsSocialPage(embedded: true), [
        soloVsBuddyCountProvider.overrideWith(
          (ref) async => (solo: 1, buddy: 2, notRecorded: 3),
        ),
        topBuddiesProvider.overrideWith((ref) async => const []),
        topDiveCentersProvider.overrideWith((ref) async => const []),
      ]);

      await tester.tap(find.text('Not recorded'));
      await tester.pumpAndSettle();

      final filter = container.read(diveFilterProvider);
      expect(filter.diveIds, ['unrecorded-dive']);
      expect(filter.diveIdsLabel, 'Solo vs Buddy Dives: Not recorded');
    });

    testWidgets('a gas mix row asks for its gas', (tester) async {
      await pumpPage(tester, const InsightsGasPage(embedded: true), [
        gasMixDistributionProvider.overrideWith(
          (ref) async => [
            DistributionSegment(label: 'Nitrox', count: 4, percentage: 100),
          ],
        ),
        sacTrendProvider.overrideWith((ref) async => const []),
        tankConfigurationStatsProvider.overrideWith(
          (ref) async => TankConfigurationStats.fromDives(const []),
        ),
        sacByTankRoleProvider.overrideWith((ref) async => const {}),
      ]);

      await tester.tap(find.text('Nitrox'));
      await tester.pumpAndSettle();

      expect(repository.lastAsked, 'gasMix:Nitrox');
    });
  });

  testWidgets('Overview: a dive type row opens that type', (tester) async {
    final stats = DiveStatistics(
      totalDives: 3,
      totalTimeSeconds: 3600,
      maxDepth: 30,
      avgMaxDepth: 20,
      avgTemperature: 24,
      totalSites: 1,
    );
    await pumpPage(tester, const InsightsOverviewPage(embedded: true), [
      diveStatisticsProvider.overrideWith((ref) async => stats),
      filteredDiveStatisticsProvider.overrideWith((ref) async => stats),
      filteredDiveRecordsProvider.overrideWith((ref) async => DiveRecords()),
      diveTypeDistributionProvider.overrideWith(
        (ref) async => [
          DistributionSegment(
            label: 'wreck',
            count: 3,
            percentage: 100,
            totalDurationSeconds: 3600,
          ),
        ],
      ),
    ]);

    await tester.ensureVisible(find.text('Wreck'));
    await tester.tap(find.text('Wreck'));
    await tester.pumpAndSettle();

    expectOpened(
      tester,
      'Dive Types: Wreck',
      condition('types', QueryOp.eq, const RefValue('wreck', 'wreck')),
    );
  });
}
