import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/domain/calendar_day_matrix.dart';
import 'package:submersion/features/insights/presentation/pages/insights_conditions_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_overview_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_progression_page.dart';
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
