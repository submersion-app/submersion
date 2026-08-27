import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';
import 'package:submersion/features/statistics/presentation/widgets/stat_charts.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// Issue #219: the SAC rate trend plot drew its horizontal grid lines on
// gridData.horizontalInterval while leaving SideTitles.interval null, so
// fl_chart labelled the left axis on its own getEfficientInterval sequence.
// The lines and the numbers were computed from different steps and visibly
// did not line up. Both sides must now share one interval, and the axis
// bounds must sit on that interval so every line carries a label.

final _sacTrend = [
  for (final (index, value) in const [12.4, 15.1, 13.8, 18.2, 16.0].indexed)
    TrendDataPoint(
      date: DateTime(2024, index + 1),
      value: value,
      label: 'M${index + 1}',
    ),
];

/// Values are anchored to zero, the baseline fl_chart iterates both grid lines
/// and side titles from.
bool _isOnTick(double value, double interval) {
  final steps = value / interval;
  return (steps - steps.roundToDouble()).abs() < 1e-9;
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(child: SizedBox(width: 400, height: 300, child: child)),
      ),
    ),
  );
}

void main() {
  group('TrendLineChart axis', () {
    testWidgets('grid lines and left labels share one interval', (
      tester,
    ) async {
      await _pump(tester, TrendLineChart(data: _sacTrend));

      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      final gridInterval = data.gridData.horizontalInterval;
      final labelInterval = data.titlesData.leftTitles.sideTitles.interval;

      expect(gridInterval, isNotNull);
      expect(labelInterval, isNotNull);
      expect(labelInterval, gridInterval);
    });

    testWidgets('axis bounds sit on the shared interval', (tester) async {
      await _pump(tester, TrendLineChart(data: _sacTrend));

      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      final interval = data.gridData.horizontalInterval!;

      expect(_isOnTick(data.minY, interval), isTrue);
      expect(_isOnTick(data.maxY, interval), isTrue);
    });

    testWidgets('every rendered left label lands on a grid line', (
      tester,
    ) async {
      final labelledValues = <double>[];
      await _pump(
        tester,
        TrendLineChart(
          data: _sacTrend,
          yAxisFormatter: (value) {
            labelledValues.add(value);
            return value.toStringAsFixed(1);
          },
        ),
      );

      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      final interval = data.gridData.horizontalInterval!;

      expect(labelledValues, isNotEmpty);
      for (final value in labelledValues) {
        expect(
          _isOnTick(value, interval),
          isTrue,
          reason: '$value is not a multiple of the $interval grid interval',
        );
      }
    });

    testWidgets('keeps the whole series inside the axis', (tester) async {
      await _pump(tester, TrendLineChart(data: _sacTrend));

      final data = tester.widget<LineChart>(find.byType(LineChart)).data;

      expect(data.minY, lessThanOrEqualTo(12.4));
      expect(data.maxY, greaterThanOrEqualTo(18.2));
    });

    testWidgets('survives a flat series', (tester) async {
      await _pump(
        tester,
        TrendLineChart(
          data: [
            TrendDataPoint(date: DateTime(2024), value: 15.0, label: 'Jan'),
            TrendDataPoint(date: DateTime(2024, 2), value: 15.0, label: 'Feb'),
          ],
        ),
      );

      final data = tester.widget<LineChart>(find.byType(LineChart)).data;

      expect(data.maxY, greaterThan(data.minY));
      expect(data.gridData.horizontalInterval, greaterThan(0));
    });
  });

  group('CategoryBarChart axis', () {
    const counts = <({String label, int count})>[
      (label: 'Reef', count: 10),
      (label: 'Wreck', count: 6),
      (label: 'Cave', count: 3),
    ];

    testWidgets('grid lines and left labels share one interval', (
      tester,
    ) async {
      await _pump(tester, const CategoryBarChart(data: counts));

      final data = tester.widget<BarChart>(find.byType(BarChart)).data;
      final gridInterval = data.gridData.horizontalInterval;
      final labelInterval = data.titlesData.leftTitles.sideTitles.interval;

      expect(gridInterval, isNotNull);
      expect(labelInterval, gridInterval);
    });

    testWidgets('steps in whole counts so every line is labelled', (
      tester,
    ) async {
      await _pump(tester, const CategoryBarChart(data: counts));

      final data = tester.widget<BarChart>(find.byType(BarChart)).data;
      final interval = data.gridData.horizontalInterval!;

      // The left titles render nothing for fractional values, so a fractional
      // interval would leave unlabelled lines.
      expect(interval, interval.roundToDouble());
      expect(data.maxY, greaterThanOrEqualTo(10));
      expect(_isOnTick(data.maxY, interval), isTrue);
    });
  });
}
