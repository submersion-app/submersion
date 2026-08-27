import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';
import 'package:submersion/features/statistics/presentation/widgets/stat_charts.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// Issue #864: fl_chart's default touch tooltip stringifies the raw double,
// so a monthly average like 528/61 = 8.655737704918034 was displayed with
// 15 decimal places on the water temperature chart. The tooltip must run
// every value through the chart's valueFormatter (unit-aware) instead.

final _minSeries = [
  TrendDataPoint(date: DateTime(2024, 9), value: 5.0, label: 'Sep'),
];
final _avgSeries = [
  TrendDataPoint(date: DateTime(2024, 9), value: 528 / 61, label: 'Sep'),
];
final _maxSeries = [
  TrendDataPoint(date: DateTime(2024, 9), value: 21.0, label: 'Sep'),
];

Future<void> _pumpChart(
  WidgetTester tester, {
  String Function(double)? valueFormatter,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            height: 300,
            child: MultiTrendLineChart(
              dataSeries: [_minSeries, _avgSeries, _maxSeries],
              seriesLabels: const ['Min', 'Avg', 'Max'],
              seriesColors: const [Colors.blue, Colors.green, Colors.red],
              valueFormatter: valueFormatter,
            ),
          ),
        ),
      ),
    ),
  );
}

List<LineTooltipItem?> _tooltipItemsForAllSeries(WidgetTester tester) {
  final chart = tester.widget<LineChart>(find.byType(LineChart));
  final data = chart.data;
  final touchedSpots = [
    for (var i = 0; i < data.lineBarsData.length; i++)
      LineBarSpot(data.lineBarsData[i], i, data.lineBarsData[i].spots.first),
  ];
  return data.lineTouchData.touchTooltipData.getTooltipItems(touchedSpots);
}

void main() {
  group('MultiTrendLineChart tooltip', () {
    testWidgets('formats values with the valueFormatter', (tester) async {
      await _pumpChart(
        tester,
        valueFormatter: (value) => '${value.toStringAsFixed(1)} °C',
      );

      final items = _tooltipItemsForAllSeries(tester);
      final texts = items.map((item) => item!.text).toList();

      expect(texts, hasLength(3));
      expect(texts.any((t) => t.contains('8.7 °C')), isTrue);
      expect(texts.any((t) => t.contains('8.655737704918')), isFalse);
      expect(texts.any((t) => t.contains('5.0 °C')), isTrue);
      expect(texts.any((t) => t.contains('21.0 °C')), isTrue);
    });

    testWidgets('includes the point label once', (tester) async {
      await _pumpChart(
        tester,
        valueFormatter: (value) => '${value.toStringAsFixed(1)} °C',
      );

      final items = _tooltipItemsForAllSeries(tester);
      final texts = items.map((item) => item!.text).toList();

      expect(texts.where((t) => t.contains('Sep')), hasLength(1));
    });

    testWidgets('falls back to one decimal place without a formatter', (
      tester,
    ) async {
      await _pumpChart(tester);

      final items = _tooltipItemsForAllSeries(tester);
      final texts = items.map((item) => item!.text).toList();

      expect(texts.any((t) => t.contains('8.7')), isTrue);
      expect(texts.any((t) => t.contains('8.655737704918')), isFalse);
    });

    testWidgets('colors each tooltip line with its series color', (
      tester,
    ) async {
      await _pumpChart(
        tester,
        valueFormatter: (value) => '${value.toStringAsFixed(1)} °C',
      );

      final items = _tooltipItemsForAllSeries(tester);
      final colors = items.map((item) => item!.textStyle.color).toList();

      expect(colors, [Colors.blue, Colors.green, Colors.red]);
    });
  });
}
