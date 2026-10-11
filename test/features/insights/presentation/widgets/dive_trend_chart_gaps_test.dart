import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/domain/trend_gap_threshold.dart';
import 'package:submersion/features/insights/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Center(child: SizedBox(width: 600, child: child)),
  ),
);

LineChartData readData(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart)).data;

dynamic chartState(WidgetTester tester) =>
    tester.state(find.byType(DiveTrendChart));

List<TrendDataPoint> run(DateTime from, int n, String prefix) => [
  for (var i = 0; i < n; i++)
    TrendDataPoint(
      date: from.add(Duration(days: i * 9)),
      value: 10.0 + i % 5,
      diveId: '$prefix$i',
    ),
];

double ms(DateTime d) => d.millisecondsSinceEpoch.toDouble();

void main() {
  final before = run(DateTime.utc(2013, 1, 1), 40, 'a');
  final after = run(DateTime.utc(2020, 1, 1), 20, 'b');
  final points = [...before, ...after];

  testWidgets('Off plots epoch milliseconds exactly as before', (tester) async {
    await tester.pumpWidget(host(DiveTrendChart(points: points)));
    final spots = readData(tester).lineBarsData.first.spots;
    expect(spots, hasLength(points.length));
    expect(spots.last.x, ms(after.last.date));
    expect(find.byKey(const ValueKey('trend-break-bands')), findsNothing);
  });

  testWidgets('the band painter is present only when a gap collapses', (
    tester,
  ) async {
    await tester.pumpWidget(host(DiveTrendChart(points: points)));
    expect(find.byKey(const ValueKey('trend-break-bands')), findsNothing);
    await tester.pumpWidget(
      host(
        DiveTrendChart(points: points, gapThreshold: TrendGapThreshold.year1),
      ),
    );
    expect(find.byKey(const ValueKey('trend-break-bands')), findsOneWidget);
  });

  testWidgets('a year threshold pulls the later dives left', (tester) async {
    await tester.pumpWidget(
      host(
        DiveTrendChart(points: points, gapThreshold: TrendGapThreshold.year1),
      ),
    );
    final data = readData(tester);
    expect(data.maxX, lessThan(ms(after.last.date)));
    final firstAfter = data.lineBarsData.first.spots.firstWhere(
      (s) => !s.isNull() && s.x > ms(before.last.date),
    );
    expect(
      firstAfter.x - ms(before.last.date),
      // The band and its margins: 7% of the 522 days with dives.
      lessThan(Duration.millisecondsPerDay * 60),
    );
  });

  testWidgets('the rolling average breaks at the gap', (tester) async {
    await tester.pumpWidget(
      host(
        DiveTrendChart(
          points: points,
          showRollingMean: true,
          gapThreshold: TrendGapThreshold.year1,
        ),
      ),
    );
    final rolling = readData(tester).lineBarsData[1].spots;
    expect(rolling.where((s) => s.isNull()), hasLength(1));
  });

  testWidgets('the fit is drawn in one piece per period', (tester) async {
    await tester.pumpWidget(
      host(
        DiveTrendChart(
          points: points,
          showLinearFit: true,
          gapThreshold: TrendGapThreshold.year1,
        ),
      ),
    );
    final fit = readData(tester).lineBarsData[1].spots;
    expect(fit, hasLength(5));
    expect(fit[2].isNull(), isTrue);
  });

  testWidgets('aggregated lines lift the pen at the break', (tester) async {
    final monthly = [
      for (var m = 0; m < 6; m++)
        TrendDataPoint(date: DateTime.utc(2013, 1 + m, 15), value: 10),
      for (var m = 0; m < 6; m++)
        TrendDataPoint(date: DateTime.utc(2020, 1 + m, 15), value: 20),
    ];
    await tester.pumpWidget(
      host(
        DiveTrendChart(
          points: monthly,
          aggregation: TrendAggregation.monthly,
          gapThreshold: TrendGapThreshold.year1,
        ),
      ),
    );
    final bars = readData(tester).lineBarsData;
    // The mean line and the min and max bounds the spread band fills.
    for (final bar in bars.take(3)) {
      expect(bar.spots.indexWhere((s) => s.isNull()), 6);
    }
  });

  testWidgets('a dive after a break opens itself, not its neighbour', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        DiveTrendChart(
          points: points,
          gapThreshold: TrendGapThreshold.year1,
          onDiveSelected: (_) {},
        ),
      ),
    );
    final bar = readData(tester).lineBarsData.first;
    final gapAt = bar.spots.indexWhere((s) => s.isNull());
    expect(gapAt, before.length);
    final state = chartState(tester);
    expect(state.debugDiveIdForSpot(0, gapAt - 1), before.last.diveId);
    expect(state.debugDiveIdForSpot(0, gapAt), isNull);
    expect(state.debugDiveIdForSpot(0, gapAt + 1), after.first.diveId);
    expect(
      state.debugDiveIdForSpot(0, bar.spots.length - 1),
      after.last.diveId,
    );
  });

  testWidgets('two dives years apart still draw', (tester) async {
    await tester.pumpWidget(
      host(
        DiveTrendChart(
          points: [
            TrendDataPoint(date: DateTime.utc(2015, 5, 1), value: 10),
            TrendDataPoint(date: DateTime.utc(2019, 5, 1), value: 20),
          ],
          gapThreshold: TrendGapThreshold.year1,
        ),
      ),
    );
    final data = readData(tester);
    final band = chartState(tester).debugScale.breaks.single;
    expect(
      (band.axisEnd - band.axisStart) / (data.maxX - data.minX),
      lessThan(0.2),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a chart drawn only from secondary series collapses their gap', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        DiveTrendChart(
          points: const [],
          secondarySeries: [
            TrendSeries(label: 'A', points: before, color: Colors.red),
            TrendSeries(label: 'B', points: after, color: Colors.blue),
          ],
          gapThreshold: TrendGapThreshold.year1,
        ),
      ),
    );
    expect(readData(tester).maxX, lessThan(ms(after.last.date)));
  });

  testWidgets('the readout over a band says No dives with both dates', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        DiveTrendChart(points: points, gapThreshold: TrendGapThreshold.year1),
      ),
    );
    final state = chartState(tester);
    final b = state.debugScale.breaks.single;
    state.debugPointerAxisX = (b.axisStart + b.axisEnd) / 2;
    final data = readData(tester);
    final bar = data.lineBarsData.first;
    final items = data.lineTouchData.touchTooltipData.getTooltipItems([
      LineBarSpot(bar, 0, bar.spots.first),
    ]);
    expect(items.first!.text, 'No dives: Dec 18, 2013 to Jan 1, 2020');
  });

  testWidgets('a real hover over the band reads No dives', (tester) async {
    // End to end through fl_chart's touch response, no debug setter: the
    // pointer position it reports must be in axis units for breakAt.
    await tester.pumpWidget(
      host(
        DiveTrendChart(points: points, gapThreshold: TrendGapThreshold.year1),
      ),
    );
    final state = chartState(tester);
    final b = state.debugScale.breaks.single;
    final data = readData(tester);
    final chart = tester.getRect(find.byType(LineChart));
    // The plot spans the chart minus the 50px left titles.
    final plotLeft = chart.left + 50;
    final plotWidth = chart.width - 50;
    final fx =
        ((b.axisStart + b.axisEnd) / 2 - data.minX) / (data.maxX - data.minX);
    final x = plotLeft + fx * plotWidth;
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer(location: Offset(x, chart.top + 40));
    await gesture.moveTo(Offset(x, chart.top + 41));
    await tester.pump();

    final bar = readData(tester).lineBarsData.first;
    final items = readData(tester).lineTouchData.touchTooltipData
        .getTooltipItems([LineBarSpot(bar, 0, bar.spots.first)]);
    expect(items.first!.text, startsWith('No dives:'));
  });

  testWidgets('the readout over the data shows the real date', (tester) async {
    await tester.pumpWidget(
      host(
        DiveTrendChart(points: points, gapThreshold: TrendGapThreshold.year1),
      ),
    );
    final state = chartState(tester);
    final data = readData(tester);
    final bar = data.lineBarsData.first;
    final spot = bar.spots.lastWhere((s) => !s.isNull());
    state.debugPointerAxisX = spot.x;
    final items = data.lineTouchData.touchTooltipData.getTooltipItems([
      LineBarSpot(bar, 0, spot),
    ]);
    expect(items.first!.text, startsWith('Jun 20, 2020'));
  });
}
