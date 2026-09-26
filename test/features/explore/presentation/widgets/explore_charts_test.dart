import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/explore/domain/chart_selection.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/presentation/providers/explore_providers.dart';
import 'package:submersion/features/explore/presentation/widgets/explore_charts.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/features/insights/presentation/widgets/horizontal_category_bar_chart.dart';
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
  }) async {
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
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
}
