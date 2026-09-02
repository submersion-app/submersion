import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/statistics/domain/trend_aggregation.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_conditions_page.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/features/statistics/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/features/statistics/presentation/widgets/stat_charts.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          waterTempTrendProvider.overrideWith(
            (ref) async => List.generate(
              20,
              (i) => TrendDataPoint(
                date: DateTime.utc(2024, 1, 1).add(Duration(days: i * 7)),
                value: 10.0 + i,
              ),
            ),
          ),
          temperatureByMonthProvider.overrideWith(
            (ref) async => [
              (month: 1, minTemp: 8.0, avgTemp: 10.0, maxTemp: 12.0),
              (month: 7, minTemp: 24.0, avgTemp: 27.0, maxTemp: 29.0),
            ],
          ),
        ].cast(),
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StatisticsConditionsPage(embedded: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows a per-dive temperature trend', (tester) async {
    await pumpPage(tester);

    expect(find.text('Water Temperature Trend'), findsOneWidget);
    expect(find.byType(DiveTrendChart), findsOneWidget);
  });

  testWidgets('keeps the seasonal chart, retitled', (tester) async {
    await pumpPage(tester);

    expect(find.text('Seasonal Water Temperature'), findsOneWidget);
    expect(find.byType(MultiTrendLineChart), findsOneWidget);
  });

  testWidgets('the trend chart starts in per-dive mode', (tester) async {
    await pumpPage(tester);

    final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));
    expect(chart.aggregation, TrendAggregation.none);
  });

  testWidgets('the seasonal subtitle says it collapses years', (tester) async {
    await pumpPage(tester);

    expect(find.textContaining('across every year'), findsOneWidget);
  });
}
