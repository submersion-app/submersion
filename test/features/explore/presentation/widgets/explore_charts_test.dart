import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/explore/domain/chart_selection.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/presentation/providers/explore_providers.dart';
import 'package:submersion/features/explore/presentation/widgets/explore_charts.dart';
import 'package:submersion/features/explore/presentation/widgets/explore_results_list.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/features/insights/presentation/widgets/horizontal_category_bar_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

void main() {
  final en = AppLocalizationsEn();

  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  Future<void> pump(
    WidgetTester tester,
    List<ChartRequest> requests, {
    ExploreChartData data = const ExploreChartData(),
    Locale locale = const Locale('en'),
  }) async {
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: locale,
        overrides: [
          ...base,
          exploreChartDataProvider.overrideWith((ref, req) async => data),
        ],
        child: SingleChildScrollView(child: ExploreCharts(requests: requests)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a trend request renders a titled date-axis chart', (
    tester,
  ) async {
    await pump(
      tester,
      [const ChartRequest(ChartKind.depthTrend)],
      data: ExploreChartData(
        points: [TrendDataPoint(date: DateTime(2025, 6, 1), value: 30)],
      ),
    );
    expect(find.text(en.explore_chart_depthTrend), findsOneWidget);
    expect(find.byType(DiveTrendChart), findsOneWidget);
  });

  testWidgets('an entity-count request renders bars titled by kind', (
    tester,
  ) async {
    await pump(tester, [
      const ChartRequest(
        ChartKind.entityCounts,
        entityKind: MentionKind.species,
      ),
    ], data: const ExploreChartData(bars: [(label: 'Green Turtle', count: 4)]));
    expect(
      find.text(en.explore_chart_entityCounts(en.explore_kind_species)),
      findsOneWidget,
    );
    expect(find.byType(HorizontalCategoryBarChart), findsOneWidget);
    expect(find.byType(DiveTrendChart), findsNothing);
  });

  testWidgets('every chart kind and entity kind has a title', (tester) async {
    await pump(tester, [
      const ChartRequest(ChartKind.divesOverTime),
      const ChartRequest(ChartKind.waterTempTrend),
      const ChartRequest(ChartKind.bottomTimeTrend),
    ]);
    for (final title in [
      en.explore_chart_divesOverTime,
      en.explore_chart_waterTempTrend,
      en.explore_chart_bottomTimeTrend,
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }

    for (final kind in MentionKind.values) {
      await pump(tester, [
        ChartRequest(ChartKind.entityCounts, entityKind: kind),
      ]);
      expect(find.byType(Card), findsOneWidget, reason: kind.name);
    }
  });

  testWidgets('no requests renders nothing', (tester) async {
    await pump(tester, const []);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('the bottom-time chart labels minutes in the diver language', (
    tester,
  ) async {
    await pump(tester, [
      const ChartRequest(ChartKind.bottomTimeTrend),
    ], locale: const Locale('de'));
    final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));
    expect(chart.valueFormatter!(45), '45 Min.');
  });

  testWidgets('a failed query shows a sentence, not the exception', (
    tester,
  ) async {
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...base,
          exploreChartDataProvider.overrideWith(
            (ref, req) async => throw StateError('database is locked'),
          ),
          exploreResultsProvider.overrideWith(
            (ref) async => throw StateError('database is locked'),
          ),
          exploreCountProvider.overrideWith((ref) async => 0),
        ],
        child: const SingleChildScrollView(
          child: Column(
            children: [
              ExploreCharts(requests: [ChartRequest(ChartKind.depthTrend)]),
              ExploreResultsList(),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(en.common_error_tryAgain), findsNWidgets(2));
    expect(find.textContaining('database is locked'), findsNothing);
  });

  testWidgets('the SAC chart is titled SAC and reads per minute', (
    tester,
  ) async {
    await pump(
      tester,
      [const ChartRequest(ChartKind.sacTrend)],
      data: ExploreChartData(
        points: [TrendDataPoint(date: DateTime(2025, 6, 1), value: 1.2)],
      ),
    );
    expect(find.text(en.query_dives_sac), findsOneWidget);
    expect(find.byType(DiveTrendChart), findsOneWidget);
  });

  test('the SAC axis reads to the diver unit precision', () {
    expect(sacAxisLabel(const UnitFormatter(AppSettings()), 1.5), '1.5');
    expect(
      sacAxisLabel(
        const UnitFormatter(AppSettings(pressureUnit: PressureUnit.psi)),
        1.5,
      ),
      '22',
    );
  });
}
