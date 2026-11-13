import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/insights/domain/suit_type.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/presentation/pages/insights_progression_page.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_charts.dart';
import 'package:submersion/features/insights/presentation/widgets/trend_chart_section.dart';
import 'package:submersion/features/insights/presentation/widgets/trend_control_strip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/info_button.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

List<TrendDataPoint> series(int n) => List.generate(
  n,
  (i) => TrendDataPoint(
    date: DateTime.utc(2024, 1, 1).add(Duration(days: i * 7)),
    value: 10.0 + i,
  ),
);

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    Future<SuitTypeStats> Function()? suits,
  }) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          depthProgressionTrendProvider.overrideWith((ref) async => series(20)),
          runtimeTrendProvider.overrideWith((ref) async => series(20)),
          bottomTimeTrendProvider.overrideWith((ref) async => series(20)),
          if (suits != null)
            divesBySuitTypeProvider.overrideWith((ref) => suits()),
        ].cast(),
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: InsightsProgressionPage(embedded: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders a per-dive chart for depth, run time and bottom time', (
    tester,
  ) async {
    await pumpPage(tester);

    // Four charts: depth, run time, bottom time, and the cumulative count.
    // Only the first three carry controls; a mean of a running total says
    // nothing.
    expect(find.byType(DiveTrendChart), findsNWidgets(4));
    expect(find.byType(TrendControlStrip), findsNWidgets(3));
  });

  testWidgets('run time sits between depth and bottom time (issue #3059)', (
    tester,
  ) async {
    await pumpPage(tester);

    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(find.text('Runtime Trend'), findsOneWidget);
    expect(top('Maximum Depth Progression'), lessThan(top('Runtime Trend')));
    expect(top('Runtime Trend'), lessThan(top('Bottom Time Trend')));
    // Its own control strip, so its settings are independent.
    expect(
      find.byKey(const ValueKey('trend-aggregation-runtime')),
      findsOneWidget,
    );
  });

  testWidgets('a runtime point opens its dive', (tester) async {
    final pushed = <String>[];
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const InsightsProgressionPage(embedded: true),
        ),
        GoRoute(
          path: '/dives/:id',
          builder: (_, state) {
            pushed.add(state.pathParameters['id']!);
            return const Text('dive page');
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          depthProgressionTrendProvider.overrideWith((ref) async => series(20)),
          runtimeTrendProvider.overrideWith((ref) async => series(20)),
          bottomTimeTrendProvider.overrideWith((ref) async => series(20)),
        ].cast(),
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final runtime = tester.widget<TrendChartSection>(
      find.ancestor(
        of: find.text('Runtime Trend'),
        matching: find.byType(TrendChartSection),
      ),
    );
    runtime.onDiveSelected!('d7');
    await tester.pumpAndSettle();

    expect(pushed, ['d7']);
  });

  testWidgets('both charts start in per-dive mode', (tester) async {
    await pumpPage(tester);

    final charts = tester
        .widgetList<DiveTrendChart>(find.byType(DiveTrendChart))
        .toList();

    for (final chart in charts) {
      expect(chart.aggregation, TrendAggregation.none);
    }
  });

  testWidgets('the cumulative count draws no fitted overlays', (tester) async {
    await pumpPage(tester);

    final cumulative = tester
        .widgetList<DiveTrendChart>(find.byType(DiveTrendChart))
        .last;

    expect(cumulative.showRollingMean, isFalse);
    expect(cumulative.showLinearFit, isFalse);
  });

  testWidgets('the two charts hold independent aggregation settings', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(const ValueKey('trend-aggregation-depth')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monthly average').last);
    await tester.pumpAndSettle();

    final charts = tester
        .widgetList<DiveTrendChart>(find.byType(DiveTrendChart))
        .toList();

    expect(charts[0].aggregation, TrendAggregation.monthly);
    expect(charts[1].aggregation, TrendAggregation.none);
  });

  testWidgets('the cumulative and per-year charts are untouched', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('Cumulative Dive Count'), findsOneWidget);
    expect(find.text('Dives Per Year'), findsOneWidget);
  });

  group('suit type chart (issues #1824, #4490)', () {
    // The per-year chart is empty on the test database and shows its empty
    // state, so the only CategoryBarChart on the page is the suit chart.
    List<({String label, int count})> suitBars(WidgetTester tester) =>
        tester.widget<CategoryBarChart>(find.byType(CategoryBarChart)).data;

    testWidgets('draws one bar per suit type, in the order it is given', (
      tester,
    ) async {
      await pumpPage(
        tester,
        suits: () async => const [
          (type: SuitType.wetsuit(mm: 3, style: 'shorty'), count: 1),
          (type: SuitType.wetsuit(mm: 5, style: 'full'), count: 2),
          (type: SuitType.wetsuit(mm: 6.5), count: 3),
          (type: SuitType.wetsuit(style: 'semi_dry'), count: 4),
          (type: SuitType.wetsuit(), count: 5),
          (type: SuitType.drysuit(), count: 6),
        ],
      );

      expect(find.text('Dives by Suit Type'), findsOneWidget);
      expect(suitBars(tester), [
        (label: 'Wetsuit · 3 mm shorty', count: 1),
        (label: 'Wetsuit · 5 mm full', count: 2),
        (label: 'Wetsuit · 6.5 mm', count: 3),
        (label: 'Wetsuit · semi-dry', count: 4),
        (label: 'Wetsuit', count: 5),
        (label: 'Drysuit', count: 6),
      ]);
    });

    testWidgets('a drysuit-only logbook draws a chart, not the empty state', (
      tester,
    ) async {
      await pumpPage(
        tester,
        suits: () async => const [(type: SuitType.drysuit(), count: 7)],
      );

      expect(suitBars(tester), [(label: 'Drysuit', count: 7)]);
      expect(
        find.text('No dives with a wetsuit or drysuit linked'),
        findsNothing,
      );
    });

    testWidgets('no linked suit at all shows the empty state', (tester) async {
      await pumpPage(tester, suits: () async => const []);

      expect(find.byType(CategoryBarChart), findsNothing);
      expect(
        find.text('No dives with a wetsuit or drysuit linked'),
        findsOneWidget,
      );
    });

    testWidgets('a failed query shows the error state', (tester) async {
      await pumpPage(
        tester,
        suits: () async => throw StateError('query failed'),
      );

      expect(find.text('Could not load suit type data'), findsOneWidget);
    });
  });
  testWidgets('every trend chart and the cumulative count carry an info icon', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.byType(InfoButton), findsNWidgets(4));
  });
}
