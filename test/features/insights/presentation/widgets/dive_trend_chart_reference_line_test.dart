import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/features/insights/presentation/widgets/trend_reference_line.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

List<TrendDataPoint> series(int n) => List.generate(
  n,
  (i) => TrendDataPoint(
    date: DateTime.utc(2024, 1, 1).add(Duration(days: i * 7)),
    value: 10.0 + i,
    diveId: 'd$i',
  ),
);

Widget host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SizedBox(width: 600, height: 300, child: child)),
);

LineChartData readData(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart)).data;

void main() {
  testWidgets('a reference line is drawn dashed at its value with its label', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        DiveTrendChart(
          points: series(5),
          referenceLine: const TrendReferenceLine(
            value: 12.5,
            label: '12.5 L/min',
          ),
        ),
      ),
    );
    final line = readData(tester).extraLinesData.horizontalLines.single;
    expect(line.y, 12.5);
    expect(line.dashArray, isNotNull);
    expect(line.label.show, isTrue);
    expect(line.label.labelResolver(line), '12.5 L/min');
  });

  testWidgets('the y axis stretches to keep a reference line on the plot', (
    tester,
  ) async {
    // Data runs 10 to 14; a line at 40 must still be inside the axis.
    await tester.pumpWidget(
      host(
        DiveTrendChart(
          points: series(5),
          referenceLine: const TrendReferenceLine(value: 40, label: '40 m'),
        ),
      ),
    );
    expect(readData(tester).maxY, greaterThanOrEqualTo(40));
  });

  testWidgets('no reference line draws no extra lines', (tester) async {
    await tester.pumpWidget(host(DiveTrendChart(points: series(5))));
    expect(readData(tester).extraLinesData.horizontalLines, isEmpty);
  });

  testWidgets('a secondary series can draw bigger dots', (tester) async {
    await tester.pumpWidget(
      host(
        DiveTrendChart(
          points: series(5),
          secondarySeries: [
            TrendSeries(
              label: 'g',
              points: series(2),
              color: Colors.red,
              pointRadius: 4.4,
            ),
          ],
        ),
      ),
    );
    final bars = readData(tester).lineBarsData;
    final primary =
        bars.first.dotData.getDotPainter(const FlSpot(0, 0), 0, bars.first, 0)
            as FlDotCirclePainter;
    final group =
        bars.last.dotData.getDotPainter(const FlSpot(0, 0), 0, bars.last, 0)
            as FlDotCirclePainter;
    expect(primary.radius, 2.2);
    expect(group.radius, 4.4);
  });
}
