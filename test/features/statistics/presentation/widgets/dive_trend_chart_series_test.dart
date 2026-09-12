import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/statistics/domain/trend_aggregation.dart';
import 'package:submersion/features/statistics/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Secondary series (condition phase 4a): extra named series on the same
/// axes, drawn like the primary, named in the tooltip, tappable; plus a
/// shaded highlight range for a tapped finding's evidence window.
List<TrendDataPoint> series(int n, {double base = 10, String prefix = 'd'}) =>
    List.generate(
      n,
      (i) => TrendDataPoint(
        date: DateTime.utc(2024, 1, 1).add(Duration(days: i * 7)),
        value: base + i,
        diveId: '$prefix$i',
      ),
    );

Widget host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

LineChartData readData(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart)).data;

void main() {
  testWidgets('draws with an empty primary and two secondary series', (
    tester,
  ) async {
    final a = series(6, base: 50, prefix: 'a');
    final b = series(6, base: 40, prefix: 'b');
    await tester.pumpWidget(
      host(
        DiveTrendChart(
          points: const [],
          secondarySeries: [
            TrendSeries(label: 'Cell 1', points: a, color: Colors.red),
            TrendSeries(label: 'Cell 2', points: b, color: Colors.blue),
          ],
        ),
      ),
    );
    final data = readData(tester);
    // Index 0 stays the (empty) primary so tap and tooltip indices hold.
    expect(data.lineBarsData.first.spots, isEmpty);
    final secondaries = data.lineBarsData.sublist(1);
    expect(secondaries, hasLength(2));
    expect(secondaries[0].color, Colors.red);
    expect(secondaries[1].color, Colors.blue);
    expect(secondaries[0].spots, hasLength(6));
    expect(data.minX, a.first.date.millisecondsSinceEpoch.toDouble());
    expect(data.maxX, a.last.date.millisecondsSinceEpoch.toDouble());
    expect(data.maxY, greaterThanOrEqualTo(55));
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('a secondary draws like the primary in each mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        DiveTrendChart(
          points: series(6),
          secondarySeries: [
            TrendSeries(
              label: 'S',
              points: series(6, base: 20),
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
    final raw = readData(tester).lineBarsData.last;
    expect(raw.barWidth, 0);
    expect(raw.dotData.show, isTrue);

    await tester.pumpWidget(
      host(
        DiveTrendChart(
          points: series(6),
          aggregation: TrendAggregation.monthly,
          secondarySeries: [
            TrendSeries(
              label: 'S',
              points: series(6, base: 20),
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
    final aggregated = readData(tester).lineBarsData.last;
    expect(aggregated.barWidth, 2);
  });

  testWidgets('the tooltip names a secondary series', (tester) async {
    await tester.pumpWidget(
      host(
        DiveTrendChart(
          points: series(6),
          secondarySeries: [
            TrendSeries(
              label: 'Cell 2',
              points: series(6, base: 20),
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
    final data = readData(tester);
    final bars = data.lineBarsData;
    final items = data.lineTouchData.touchTooltipData.getTooltipItems([
      LineBarSpot(bars[0], 0, bars[0].spots.first),
      LineBarSpot(bars[1], 1, bars[1].spots.first),
    ]);
    final text = items.first!.children!.map((s) => s.toPlainText()).join();
    expect(text, contains('Cell 2'));
  });

  testWidgets('a tap on a secondary point opens its dive', (tester) async {
    String? opened;
    await tester.pumpWidget(
      host(
        DiveTrendChart(
          points: series(6),
          secondarySeries: [
            TrendSeries(
              label: 'S',
              points: series(6, base: 20, prefix: 's'),
              color: Colors.red,
            ),
          ],
          onDiveSelected: (id) => opened = id,
        ),
      ),
    );
    final data = readData(tester);
    final bars = data.lineBarsData;
    data.lineTouchData.touchCallback!(
      FlTapUpEvent(TapUpDetails(kind: PointerDeviceKind.touch)),
      LineTouchResponse(
        touchLocation: Offset.zero,
        touchChartCoordinate: Offset.zero,
        lineBarSpots: [TouchLineBarSpot(bars[1], 1, bars[1].spots[2], 0)],
      ),
    );
    expect(opened, 's2');
  });

  testWidgets('a highlight range becomes one vertical annotation', (
    tester,
  ) async {
    final points = series(6);
    await tester.pumpWidget(
      host(
        DiveTrendChart(
          points: points,
          highlightRange: (start: points[1].date, end: points[3].date),
        ),
      ),
    );
    final annotations = readData(
      tester,
    ).rangeAnnotations.verticalRangeAnnotations;
    expect(annotations, hasLength(1));
    expect(annotations.first.x1, points[1].date.millisecondsSinceEpoch);
    expect(annotations.first.x2, points[3].date.millisecondsSinceEpoch);
  });

  testWidgets('no highlight range means no annotation', (tester) async {
    await tester.pumpWidget(host(DiveTrendChart(points: series(6))));
    expect(readData(tester).rangeAnnotations.verticalRangeAnnotations, isEmpty);
  });

  testWidgets('a chart drawn from secondary series announces their points', (
    tester,
  ) async {
    // The condition charts leave the primary series empty and draw every
    // point as a secondary; a screen reader must not hear "0 points".
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DiveTrendChart(
            points: const [],
            secondarySeries: [
              TrendSeries(
                label: 'Cell 1',
                color: Colors.blue,
                points: [
                  for (var i = 0; i < 3; i++)
                    TrendDataPoint(
                      date: DateTime.utc(2026, 1, 1 + i),
                      value: 50.0 - i,
                    ),
                ],
              ),
              TrendSeries(
                label: 'Cell 2',
                color: Colors.green,
                points: [
                  for (var i = 0; i < 2; i++)
                    TrendDataPoint(
                      date: DateTime.utc(2026, 1, 1 + i),
                      value: 48.0 - i,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final labels = [
      for (final e in find.byType(Semantics).evaluate())
        (e.widget as Semantics).properties.label,
    ].whereType<String>();
    expect(labels, contains('Trend line chart showing 5 data points'));
  });

  test('a tap opens the data spot nearest it, across every series', () {
    // Each series reports its own nearest spot. The first one listed is
    // not the touched one: with Cell 1 missing a dive, its nearest spot
    // is another dive, and the tap meant Cell 2's.
    TouchLineBarSpot spot(int barIndex, double distance) => TouchLineBarSpot(
      LineChartBarData(spots: const [FlSpot(0, 0)]),
      barIndex,
      const FlSpot(0, 0),
      distance,
    );
    bool isData(int barIndex) => barIndex >= 1 && barIndex <= 2;
    final picked = nearestTouchedDataSpot([
      spot(0, 1),
      spot(1, 30),
      spot(2, 4),
      spot(3, 0),
    ], isData);
    expect(picked?.barIndex, 2);
    expect(nearestTouchedDataSpot([spot(3, 0)], isData), isNull);
    expect(nearestTouchedDataSpot(const [], isData), isNull);
  });
}
