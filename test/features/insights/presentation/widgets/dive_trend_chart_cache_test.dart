import 'dart:collection';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/domain/trend_gap_threshold.dart';
import 'package:submersion/features/insights/domain/trend_range.dart';
import 'package:submersion/features/insights/presentation/widgets/chart_overview_strip.dart';
import 'package:submersion/features/insights/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/features/insights/presentation/widgets/trend_reference_line.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Pan and zoom rebuild the chart on every pointer move, and nothing a move
/// changes follows from the data (issue #3858). A list that counts its reads
/// proves that for every path through the chart at once, with no hook in
/// production code: a viewport-only move reads no element at all.
class CountingPoints extends ListBase<TrendDataPoint> {
  CountingPoints(this._inner);

  final List<TrendDataPoint> _inner;
  int reads = 0;

  @override
  int get length => _inner.length;

  @override
  set length(int value) => throw UnsupportedError('read only');

  @override
  TrendDataPoint operator [](int index) {
    reads++;
    return _inner[index];
  }

  @override
  void operator []=(int index, TrendDataPoint value) =>
      throw UnsupportedError('read only');
}

/// Two runs of dives two years apart, so a gap threshold collapses a break.
List<TrendDataPoint> dives({String prefix = 'd', double base = 10}) => [
  for (var i = 0; i < 30; i++)
    TrendDataPoint(
      date: DateTime.utc(2019, 1, 7).add(Duration(days: i * 3)),
      value: base + i % 7,
      diveId: '$prefix$i',
    ),
  for (var i = 0; i < 30; i++)
    TrendDataPoint(
      date: DateTime.utc(2022, 1, 3).add(Duration(days: i * 3)),
      value: base + 2 + i % 5,
      diveId: '$prefix${i + 30}',
    ),
];

Widget host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

LineChartData readData(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart)).data;

dynamic chartState(WidgetTester tester) =>
    tester.state(find.byType(DiveTrendChart));

Future<void> zoomIn(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('trend-c-zoom-in')));
  await tester.pump();
}

Future<void> wheelPan(WidgetTester tester) async {
  final pointer = TestPointer(1, PointerDeviceKind.mouse);
  final centre = tester.getCenter(find.byType(LineChart));
  await tester.sendEventToBinding(pointer.hover(centre));
  await tester.sendEventToBinding(pointer.scroll(const Offset(120, 0)));
  await tester.pump();
}

void main() {
  group('a viewport-only move reads no data', () {
    for (final aggregation in TrendAggregation.values) {
      for (final gaps in [TrendGapThreshold.off, TrendGapThreshold.year1]) {
        testWidgets('${aggregation.name}, gaps ${gaps.name}', (tester) async {
          final primary = CountingPoints(dives());
          final other = CountingPoints(dives(prefix: 's', base: 30));
          await tester.pumpWidget(
            host(
              DiveTrendChart(
                chartId: 'c',
                points: primary,
                secondarySeries: [
                  TrendSeries(label: 'S', points: other, color: Colors.red),
                ],
                aggregation: aggregation,
                gapThreshold: gaps,
                showRollingMean: true,
                showLinearFit: true,
              ),
            ),
          );
          expect(primary.reads, greaterThan(0));
          primary.reads = 0;
          other.reads = 0;

          // The buttons, a second zoom past the strip appearing, the wheel.
          await zoomIn(tester);
          await zoomIn(tester);
          final zoomed = readData(tester).minX;
          await wheelPan(tester);

          expect(readData(tester).minX, isNot(zoomed));
          expect(primary.reads, 0);
          expect(other.reads, 0);
        });
      }
    }

    testWidgets('nor does dragging the overview strip', (tester) async {
      final primary = CountingPoints(dives());
      await tester.pumpWidget(
        host(
          DiveTrendChart(
            chartId: 'c',
            points: primary,
            showRollingMean: true,
            showLinearFit: true,
          ),
        ),
      );
      await zoomIn(tester);
      await zoomIn(tester);
      primary.reads = 0;

      final before = readData(tester).minX;
      final strip = tester.getRect(find.byType(ChartOverviewStrip));
      await tester.dragFrom(strip.center, const Offset(-40, 0));
      await tester.pump();

      expect(readData(tester).minX, isNot(before));
      expect(primary.reads, 0);
    });

    testWidgets('nor does a parent keeping the settled window', (tester) async {
      // The section stores the window when a gesture ends, which rebuilds it
      // and hands the chart the same list again.
      final primary = CountingPoints(dives());
      var range = TrendRange.all;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => host(
            DiveTrendChart(
              chartId: 'c',
              points: primary,
              range: range,
              onRangeChanged: (r) => setState(() => range = r),
              showLinearFit: true,
            ),
          ),
        ),
      );
      primary.reads = 0;

      await zoomIn(tester);
      await tester.pump();

      expect(range, isNot(TrendRange.all));
      expect(primary.reads, 0);
    });
  });

  group('what the chart reuses', () {
    testWidgets('new colours with the same data read nothing and still draw', (
      tester,
    ) async {
      // Spots are reused, bars are not: the colours live on the bars.
      final primary = CountingPoints(dives());
      Widget chart(Color color) => host(
        DiveTrendChart(chartId: 'c', points: primary, pointColor: color),
      );
      await tester.pumpWidget(chart(Colors.red));
      primary.reads = 0;

      await tester.pumpWidget(chart(Colors.green));

      expect(readData(tester).lineBarsData.first.color, Colors.green);
      expect(primary.reads, 0);
    });

    testWidgets('a pan hands back the same spots and strip points', (
      tester,
    ) async {
      // Spots and strip points are built from buckets, so a read count on the
      // dives cannot see them: only their identity shows they were reused.
      await tester.pumpWidget(
        host(
          DiveTrendChart(
            chartId: 'c',
            points: dives(),
            secondarySeries: [
              TrendSeries(
                label: 'S',
                points: dives(prefix: 's', base: 30),
                color: Colors.red,
              ),
            ],
            aggregation: TrendAggregation.weekly,
            gapThreshold: TrendGapThreshold.year1,
            showRollingMean: true,
            showLinearFit: true,
          ),
        ),
      );
      await zoomIn(tester);
      await zoomIn(tester);

      List<Object> derivedLists() => [
        for (final bar in readData(tester).lineBarsData) bar.spots,
        tester
            .widget<ChartOverviewStrip>(find.byType(ChartOverviewStrip))
            .points,
      ];
      final before = derivedLists();
      final start = readData(tester).minX;

      await wheelPan(tester);

      expect(readData(tester).minX, isNot(start));
      final after = derivedLists();
      expect(after, hasLength(before.length));
      for (var i = 0; i < after.length; i++) {
        expect(identical(after[i], before[i]), isTrue, reason: 'list $i');
      }
    });

    testWidgets('a pan leaves every tap on its own dive', (tester) async {
      // Newest first: the spot order is the sorted one, not the input's.
      final primary = dives().reversed.toList();
      final other = dives(prefix: 's', base: 30);
      await tester.pumpWidget(
        host(
          DiveTrendChart(
            chartId: 'c',
            points: primary,
            secondarySeries: [
              TrendSeries(label: 'S', points: other, color: Colors.red),
            ],
            gapThreshold: TrendGapThreshold.year1,
          ),
        ),
      );
      await zoomIn(tester);
      await wheelPan(tester);

      final state = chartState(tester);
      final bars = readData(tester).lineBarsData;
      expect(state.debugDiveIdForSpot(0, 0), 'd0');
      expect(state.debugDiveIdForSpot(0, 29), 'd29');
      // Spot 30 is the pen lift at the break.
      expect(bars.first.spots[30], FlSpot.nullSpot);
      expect(state.debugDiveIdForSpot(0, 30), isNull);
      expect(state.debugDiveIdForSpot(0, 31), 'd30');
      expect(state.debugDiveIdForSpot(1, 31), 's30');
    });
  });

  group('what invalidates the reuse', () {
    testWidgets('a new list of points', (tester) async {
      await tester.pumpWidget(
        host(DiveTrendChart(chartId: 'c', points: dives())),
      );
      final before = readData(tester).lineBarsData.first.spots.first;

      await tester.pumpWidget(
        host(DiveTrendChart(chartId: 'c', points: dives(base: 50))),
      );

      final after = readData(tester).lineBarsData.first.spots.first;
      expect(after.y, before.y + 40);
    });

    testWidgets('a new secondary list', (tester) async {
      final primary = dives();
      Widget chart(double base) => host(
        DiveTrendChart(
          chartId: 'c',
          points: primary,
          secondarySeries: [
            TrendSeries(
              label: 'S',
              points: dives(prefix: 's', base: base),
              color: Colors.red,
            ),
          ],
        ),
      );
      await tester.pumpWidget(chart(30));
      final before = readData(tester).lineBarsData.last.spots.first;

      await tester.pumpWidget(chart(60));

      final after = readData(tester).lineBarsData.last.spots.first;
      expect(after.y, before.y + 30);
    });

    testWidgets('the aggregation', (tester) async {
      final primary = dives();
      Widget chart(TrendAggregation mode) => host(
        DiveTrendChart(chartId: 'c', points: primary, aggregation: mode),
      );
      await tester.pumpWidget(chart(TrendAggregation.none));
      expect(readData(tester).lineBarsData, hasLength(1));
      expect(chartState(tester).debugDiveIdForSpot(0, 0), 'd0');

      await tester.pumpWidget(chart(TrendAggregation.monthly));

      // The mean plus the two invisible band bounds, and no single dive.
      expect(readData(tester).lineBarsData, hasLength(3));
      expect(chartState(tester).debugDiveIdForSpot(0, 0), isNull);
    });

    testWidgets('the gap threshold', (tester) async {
      final primary = dives();
      Widget chart(TrendGapThreshold threshold) => host(
        DiveTrendChart(
          chartId: 'c',
          points: primary,
          gapThreshold: threshold,
          showRollingMean: true,
        ),
      );
      await tester.pumpWidget(chart(TrendGapThreshold.off));
      expect(chartState(tester).debugScale.isIdentity, isTrue);
      expect(readData(tester).lineBarsData[1].spots, hasLength(60));

      await tester.pumpWidget(chart(TrendGapThreshold.year1));

      expect(chartState(tester).debugScale.isIdentity, isFalse);
      // The rolling mean now stops at the break instead of crossing it.
      expect(readData(tester).lineBarsData[1].spots, contains(FlSpot.nullSpot));
    });

    testWidgets('the rolling mean and fit toggles', (tester) async {
      final primary = dives();
      Widget chart({bool rolling = false, bool fit = false}) => host(
        DiveTrendChart(
          chartId: 'c',
          points: primary,
          showRollingMean: rolling,
          showLinearFit: fit,
        ),
      );
      await tester.pumpWidget(chart());
      expect(readData(tester).lineBarsData, hasLength(1));

      await tester.pumpWidget(chart(rolling: true));
      expect(readData(tester).lineBarsData, hasLength(2));

      await tester.pumpWidget(chart(rolling: true, fit: true));
      expect(readData(tester).lineBarsData, hasLength(3));

      await tester.pumpWidget(chart(fit: true));
      expect(readData(tester).lineBarsData, hasLength(2));
    });

    testWidgets('the reference line value', (tester) async {
      final primary = dives();
      Widget chart(double? value) => host(
        DiveTrendChart(
          chartId: 'c',
          points: primary,
          referenceLine: value == null
              ? null
              : TrendReferenceLine(value: value, label: 'x'),
        ),
      );
      await tester.pumpWidget(chart(null));
      final plain = readData(tester).maxY;

      await tester.pumpWidget(chart(100));
      final raised = readData(tester).maxY;
      expect(raised, greaterThan(plain));
      expect(raised, greaterThanOrEqualTo(100));

      await tester.pumpWidget(chart(200));
      expect(readData(tester).maxY, greaterThan(raised));
    });
  });
}
