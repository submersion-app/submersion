import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/statistics/domain/trend_aggregation.dart';
import 'package:submersion/features/statistics/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

List<TrendDataPoint> series(int n) => List.generate(
  n,
  (i) => TrendDataPoint(
    date: DateTime.utc(2024, 1, 1).add(Duration(days: i * 7)),
    value: 10.0 + i,
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
  testWidgets('plots x as epoch milliseconds, not the array index', (
    tester,
  ) async {
    final points = series(6);
    await tester.pumpWidget(host(DiveTrendChart(points: points)));

    final data = readData(tester);
    final spots = data.lineBarsData.first.spots;

    expect(spots, hasLength(6));
    expect(spots.first.x, points.first.date.millisecondsSinceEpoch.toDouble());
    expect(spots.last.x, points.last.date.millisecondsSinceEpoch.toDouble());
  });

  testWidgets('the x bounds span the first and last dive', (tester) async {
    final points = series(6);
    await tester.pumpWidget(host(DiveTrendChart(points: points)));

    final data = readData(tester);

    expect(data.minX, points.first.date.millisecondsSinceEpoch.toDouble());
    expect(data.maxX, points.last.date.millisecondsSinceEpoch.toDouble());
  });

  testWidgets('draws dots with no connecting stroke in raw mode', (
    tester,
  ) async {
    await tester.pumpWidget(host(DiveTrendChart(points: series(6))));

    final bar = readData(tester).lineBarsData.first;

    expect(bar.barWidth, 0);
    expect(bar.dotData.show, isTrue);
  });

  testWidgets('a gap between dives is preserved in the x spacing', (
    tester,
  ) async {
    final points = <TrendDataPoint>[
      TrendDataPoint(date: DateTime.utc(2024, 1, 1), value: 10),
      TrendDataPoint(date: DateTime.utc(2024, 1, 2), value: 12),
      TrendDataPoint(date: DateTime.utc(2026, 1, 1), value: 40),
    ];
    await tester.pumpWidget(host(DiveTrendChart(points: points)));

    final spots = readData(tester).lineBarsData.first.spots;
    final firstGap = spots[1].x - spots[0].x;
    final secondGap = spots[2].x - spots[1].x;

    expect(secondGap, greaterThan(firstGap * 100));
  });

  testWidgets('monthly aggregation collapses to one point per month', (
    tester,
  ) async {
    final points = <TrendDataPoint>[
      TrendDataPoint(date: DateTime.utc(2024, 1, 5), value: 10),
      TrendDataPoint(date: DateTime.utc(2024, 1, 20), value: 20),
      TrendDataPoint(date: DateTime.utc(2024, 2, 5), value: 30),
    ];
    await tester.pumpWidget(
      host(
        DiveTrendChart(points: points, aggregation: TrendAggregation.monthly),
      ),
    );

    final spots = readData(tester).lineBarsData.first.spots;

    expect(spots, hasLength(2));
    expect(spots.first.y, 15); // mean of 10 and 20
  });

  testWidgets('renders the empty state rather than a chart for no dives', (
    tester,
  ) async {
    await tester.pumpWidget(host(const DiveTrendChart(points: [])));

    expect(find.byType(LineChart), findsNothing);
    expect(find.text('No trend data available'), findsOneWidget);
  });

  testWidgets('a single dive still renders a chart', (tester) async {
    await tester.pumpWidget(host(DiveTrendChart(points: series(1))));

    final data = readData(tester);

    expect(data.maxX, greaterThan(data.minX));
  });

  group('min/max band', () {
    final spread = <TrendDataPoint>[
      TrendDataPoint(date: DateTime.utc(2024, 1, 5), value: 10),
      TrendDataPoint(date: DateTime.utc(2024, 1, 20), value: 30),
      TrendDataPoint(date: DateTime.utc(2024, 2, 5), value: 40),
      TrendDataPoint(date: DateTime.utc(2024, 2, 25), value: 60),
    ];

    testWidgets('draws no band in raw mode', (tester) async {
      await tester.pumpWidget(host(DiveTrendChart(points: spread)));

      expect(readData(tester).betweenBarsData, isEmpty);
    });

    testWidgets('draws one band between the min and max series when monthly', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DiveTrendChart(points: spread, aggregation: TrendAggregation.monthly),
        ),
      );

      final data = readData(tester);

      expect(data.betweenBarsData, hasLength(1));
      expect(data.betweenBarsData.first.fromIndex, 1);
      expect(data.betweenBarsData.first.toIndex, 2);
    });

    testWidgets('the band series carry the bucket min and max', (tester) async {
      await tester.pumpWidget(
        host(
          DiveTrendChart(points: spread, aggregation: TrendAggregation.monthly),
        ),
      );

      final bars = readData(tester).lineBarsData;

      expect(bars[1].spots.map((s) => s.y), [10, 40]);
      expect(bars[2].spots.map((s) => s.y), [30, 60]);
    });

    testWidgets('the band series are not stroked or dotted', (tester) async {
      await tester.pumpWidget(
        host(
          DiveTrendChart(points: spread, aggregation: TrendAggregation.monthly),
        ),
      );

      final bars = readData(tester).lineBarsData;

      expect(bars[1].barWidth, 0);
      expect(bars[1].dotData.show, isFalse);
      expect(bars[2].barWidth, 0);
      expect(bars[2].dotData.show, isFalse);
    });

    testWidgets('a bucket holding one dive yields a zero-height band', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DiveTrendChart(
            points: [
              TrendDataPoint(date: DateTime.utc(2024, 1, 5), value: 10),
              TrendDataPoint(date: DateTime.utc(2024, 2, 5), value: 40),
            ],
            aggregation: TrendAggregation.monthly,
          ),
        ),
      );

      final bars = readData(tester).lineBarsData;

      expect(bars[1].spots.map((s) => s.y), bars[2].spots.map((s) => s.y));
    });

    testWidgets('the y bounds cover the band, not just the means', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DiveTrendChart(points: spread, aggregation: TrendAggregation.monthly),
        ),
      );

      final data = readData(tester);

      expect(data.minY, lessThanOrEqualTo(10));
      expect(data.maxY, greaterThanOrEqualTo(60));
    });
  });

  group('overlays', () {
    testWidgets('draws neither overlay by default', (tester) async {
      await tester.pumpWidget(host(DiveTrendChart(points: series(20))));

      expect(readData(tester).lineBarsData, hasLength(1));
    });

    testWidgets('draws a rolling mean series when asked', (tester) async {
      await tester.pumpWidget(
        host(DiveTrendChart(points: series(20), showRollingMean: true)),
      );

      final bars = readData(tester).lineBarsData;

      expect(bars, hasLength(2));
      expect(bars.last.spots, hasLength(20));
      expect(bars.last.barWidth, greaterThan(0));
    });

    testWidgets('draws the linear fit as exactly two endpoints', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(DiveTrendChart(points: series(20), showLinearFit: true)),
      );

      final bars = readData(tester).lineBarsData;

      expect(bars, hasLength(2));
      expect(bars.last.spots, hasLength(2));
    });

    testWidgets('draws both overlays together', (tester) async {
      await tester.pumpWidget(
        host(
          DiveTrendChart(
            points: series(20),
            showRollingMean: true,
            showLinearFit: true,
          ),
        ),
      );

      expect(readData(tester).lineBarsData, hasLength(3));
    });

    testWidgets('draws no overlay below the minimum point count', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DiveTrendChart(
            points: series(4),
            showRollingMean: true,
            showLinearFit: true,
          ),
        ),
      );

      expect(readData(tester).lineBarsData, hasLength(1));
    });

    testWidgets('the rolling mean is unchanged by the aggregation mode', (
      tester,
    ) async {
      // Both fits read the raw dives. If they read the buckets instead,
      // changing the dropdown would move the trend line and wrongly imply the
      // underlying trend had changed.
      await tester.pumpWidget(
        host(DiveTrendChart(points: series(20), showRollingMean: true)),
      );
      final raw = readData(
        tester,
      ).lineBarsData.last.spots.map((s) => s.y).toList();

      await tester.pumpWidget(
        host(
          DiveTrendChart(
            points: series(20),
            showRollingMean: true,
            aggregation: TrendAggregation.monthly,
          ),
        ),
      );
      final aggregated = readData(tester).lineBarsData
          .where((b) => b.barWidth > 0)
          .last
          .spots
          .map((s) => s.y)
          .toList();

      expect(aggregated, raw);
    });
  });

  group('x axis labels', () {
    // These assert RENDERED text. Every LineChartData assertion above passed
    // while the axis drew nothing, because fl_chart calls getTitlesWidget at
    // values IT chooses, not at values we nominate. Matching those values
    // exactly against our tick timestamps essentially never hits, so only the
    // endpoints that happened to coincide ever rendered.
    List<String> yearLabels(WidgetTester tester) => tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .where((t) => RegExp(r'^20\d\d$').hasMatch(t))
        .toList();

    List<TrendDataPoint> multiYear() => List.generate(
      24,
      (i) => TrendDataPoint(
        date: DateTime.utc(2020 + i ~/ 4, (i % 4) * 3 + 1, 1),
        value: 10.0 + i,
      ),
    );

    testWidgets('gives fl_chart an explicit bottom-axis interval', (
      tester,
    ) async {
      await tester.pumpWidget(host(DiveTrendChart(points: multiYear())));

      final interval = readData(
        tester,
      ).titlesData.bottomTitles.sideTitles.interval;

      expect(interval, isNotNull);
      expect(interval, greaterThan(0));
    });

    testWidgets('draws several year labels across a multi-year span', (
      tester,
    ) async {
      await tester.pumpWidget(host(DiveTrendChart(points: multiYear())));

      expect(yearLabels(tester).length, greaterThanOrEqualTo(3));
    });

    testWidgets('draws year labels in aggregated mode too', (tester) async {
      await tester.pumpWidget(
        host(
          DiveTrendChart(
            points: multiYear(),
            aggregation: TrendAggregation.monthly,
          ),
        ),
      );

      expect(yearLabels(tester).length, greaterThanOrEqualTo(3));
    });
  });

  group('no duplicate adjacent labels', () {
    testWidgets('a nine-month monthly span labels each month once', (
      tester,
    ) async {
      // A uniform interval drifts off real month boundaries, so two adjacent
      // slots can format to the same month abbreviation ("Sep Sep").
      final points = <TrendDataPoint>[
        for (var m = 0; m < 9; m++)
          TrendDataPoint(date: DateTime.utc(2025, 9 + m, 15), value: 10.0 + m),
      ];

      await tester.pumpWidget(
        host(
          DiveTrendChart(points: points, aggregation: TrendAggregation.monthly),
        ),
      );

      // Month labels now read "Sep '25": every one carries its year.
      final monthLabel = RegExp(r"^[A-Za-z]{3,} '\d{2}$");
      final labels = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .where(monthLabel.hasMatch)
          .toList();

      expect(labels, isNotEmpty);
      expect(
        labels.length,
        labels.toSet().length,
        reason: 'duplicate month labels: $labels',
      );
    });
  });

  group('readability', () {
    final spread = <TrendDataPoint>[
      for (var m = 0; m < 6; m++)
        TrendDataPoint(date: DateTime.utc(2025, 9 + m, 5), value: 10.0 + m),
      for (var m = 0; m < 6; m++)
        TrendDataPoint(date: DateTime.utc(2025, 9 + m, 20), value: 30.0 + m),
    ];

    testWidgets('marks each aggregated bucket with a dot', (tester) async {
      // Without dots an aggregated series is a smooth line and the only way
      // to find a data point is to hover for it.
      await tester.pumpWidget(
        host(
          DiveTrendChart(points: spread, aggregation: TrendAggregation.monthly),
        ),
      );

      expect(readData(tester).lineBarsData.first.dotData.show, isTrue);
    });

    testWidgets('keeps the band series free of dots', (tester) async {
      await tester.pumpWidget(
        host(
          DiveTrendChart(points: spread, aggregation: TrendAggregation.monthly),
        ),
      );

      final bars = readData(tester).lineBarsData;

      expect(bars[1].dotData.show, isFalse);
      expect(bars[2].dotData.show, isFalse);
    });

    testWidgets('keeps the tooltip inside the chart on a narrow surface', (
      tester,
    ) async {
      await tester.pumpWidget(host(DiveTrendChart(points: spread)));

      final tooltip = readData(tester).lineTouchData.touchTooltipData;

      expect(tooltip.fitInsideHorizontally, isTrue);
      // Drawn above the plot rather than over it, so it can never land on the
      // point it is describing. That is also why it does not fit vertically.
      expect(tooltip.showOnTopOfTheChartBoxArea, isTrue);
      expect(tooltip.tooltipMargin, 0);
    });

    testWidgets('the tooltip reports the data series only', (tester) async {
      // Aggregated mode carries three series; touching drew one unlabelled
      // line per series, so a bucket read as three mystery numbers.
      await tester.pumpWidget(
        host(
          DiveTrendChart(points: spread, aggregation: TrendAggregation.monthly),
        ),
      );

      final data = readData(tester);
      final bars = data.lineBarsData;
      final touched = [
        for (var i = 0; i < bars.length; i++)
          LineBarSpot(bars[i], i, bars[i].spots.first),
      ];

      final items = data.lineTouchData.touchTooltipData.getTooltipItems(
        touched,
      );

      expect(items.where((i) => i != null), hasLength(1));
    });
  });

  group('touch indicator', () {
    final spread = <TrendDataPoint>[
      for (var m = 0; m < 6; m++)
        TrendDataPoint(date: DateTime.utc(2025, 9 + m, 5), value: 10.0 + m),
      for (var m = 0; m < 6; m++)
        TrendDataPoint(date: DateTime.utc(2025, 9 + m, 20), value: 30.0 + m),
    ];

    testWidgets('uses the same tooltip type as the dive profile chart', (
      tester,
    ) async {
      await tester.pumpWidget(host(DiveTrendChart(points: spread)));

      final data = readData(tester);
      final bars = data.lineBarsData;
      final items = data.lineTouchData.touchTooltipData.getTooltipItems([
        LineBarSpot(bars[0], 0, bars[0].spots.first),
      ]);
      final style = items.whereType<LineTooltipItem>().single.textStyle;

      expect(style.fontSize, 14);
      expect(style.fontFamily, 'RobotoMono');
      expect(style.fontFeatures, isNotEmpty);
    });

    testWidgets('marks the touched point on the data series', (tester) async {
      await tester.pumpWidget(host(DiveTrendChart(points: spread)));

      final data = readData(tester);
      final bars = data.lineBarsData;
      final indicators = data.lineTouchData.getTouchedSpotIndicator(bars[0], [
        0,
      ]);

      expect(indicators.whereType<TouchedSpotIndicatorData>(), hasLength(1));
    });

    testWidgets('marks nothing on the band and overlay series', (tester) async {
      // One highlight per series would stack several dots and lines on a
      // single touch.
      await tester.pumpWidget(
        host(
          DiveTrendChart(
            points: spread,
            aggregation: TrendAggregation.monthly,
            showRollingMean: true,
          ),
        ),
      );

      final data = readData(tester);
      final bars = data.lineBarsData;

      for (var i = 1; i < bars.length; i++) {
        final indicators = data.lineTouchData.getTouchedSpotIndicator(bars[i], [
          0,
        ]);
        expect(
          indicators.every((d) => d == null),
          isTrue,
          reason: 'series $i drew an indicator',
        );
      }
    });
  });

  group('zoom and pan', () {
    List<TrendDataPoint> longSeries() => List.generate(
      60,
      (i) => TrendDataPoint(
        date: DateTime.utc(2022, 1, 1).add(Duration(days: i * 20)),
        value: 10.0 + (i % 7),
      ),
    );

    testWidgets('renders instantly so panning does not smear', (tester) async {
      // fl_chart's LineChart is an ImplicitlyAnimatedWidget defaulting to
      // 150ms. Any chart rebuilt from pointer events lerps old data to new,
      // smearing bars while panning (PR #879).
      await tester.pumpWidget(host(DiveTrendChart(points: longSeries())));

      final chart = tester.widget<LineChart>(find.byType(LineChart));

      expect(chart.duration, Duration.zero);
    });

    testWidgets('starts unzoomed, spanning the whole range', (tester) async {
      final points = longSeries();
      await tester.pumpWidget(host(DiveTrendChart(points: points)));

      final data = readData(tester);

      expect(data.minX, points.first.date.millisecondsSinceEpoch.toDouble());
      expect(data.maxX, points.last.date.millisecondsSinceEpoch.toDouble());
    });

    testWidgets('a scroll wheel tick narrows the visible span', (tester) async {
      await tester.pumpWidget(host(DiveTrendChart(points: longSeries())));
      final before = readData(tester);
      final beforeSpan = before.maxX - before.minX;

      final center = tester.getCenter(find.byType(LineChart));
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      tester.binding.handlePointerEvent(pointer.hover(center));
      tester.binding.handlePointerEvent(pointer.scroll(const Offset(0, -100)));
      await tester.pump();

      final after = readData(tester);
      expect(after.maxX - after.minX, lessThan(beforeSpan));
    });

    testWidgets('clips data outside the visible window', (tester) async {
      await tester.pumpWidget(host(DiveTrendChart(points: longSeries())));

      expect(readData(tester).clipData.any, isTrue);
    });

    testWidgets('a trackpad pinch zooms', (tester) async {
      await tester.pumpWidget(host(DiveTrendChart(points: longSeries())));
      final before = readData(tester);
      final beforeSpan = before.maxX - before.minX;

      final center = tester.getCenter(find.byType(LineChart));
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.trackpad,
      );
      await gesture.panZoomStart(center);
      await gesture.panZoomUpdate(center, scale: 2.5);
      await tester.pump();

      final after = readData(tester);
      expect(after.maxX - after.minX, lessThan(beforeSpan));

      await gesture.panZoomEnd();
      await tester.pump();
    });

    testWidgets('a mouse drag pans once zoomed', (tester) async {
      await tester.pumpWidget(host(DiveTrendChart(points: longSeries())));

      final center = tester.getCenter(find.byType(LineChart));
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      tester.binding.handlePointerEvent(pointer.hover(center));
      tester.binding.handlePointerEvent(pointer.scroll(const Offset(0, -100)));
      await tester.pump();
      final zoomed = readData(tester);

      tester.binding.handlePointerEvent(pointer.down(center));
      tester.binding.handlePointerEvent(
        pointer.move(center - const Offset(60, 0)),
      );
      tester.binding.handlePointerEvent(pointer.up());
      await tester.pump();

      final panned = readData(tester);
      expect(panned.minX, greaterThan(zoomed.minX));
      // The span is unchanged: panning moves the window, it does not resize it.
      expect(panned.maxX - panned.minX, closeTo(zoomed.maxX - zoomed.minX, 1));
    });

    testWidgets('the axis relabels for the zoomed window', (tester) async {
      // Zoomed into a few weeks, year ticks would say nothing.
      await tester.pumpWidget(host(DiveTrendChart(points: longSeries())));
      final wide = readData(tester);

      final center = tester.getCenter(find.byType(LineChart));
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      tester.binding.handlePointerEvent(pointer.hover(center));
      for (var i = 0; i < 12; i++) {
        tester.binding.handlePointerEvent(
          pointer.scroll(const Offset(0, -100)),
        );
      }
      await tester.pump();

      final narrow = readData(tester);
      expect(narrow.maxX - narrow.minX, lessThan(wide.maxX - wide.minX));
      expect(
        narrow.titlesData.bottomTitles.sideTitles.interval,
        lessThan(wide.titlesData.bottomTitles.sideTitles.interval!),
      );
    });
  });

  group('zoom controls', () {
    testWidgets('offers zoom in, zoom out and a level readout', (tester) async {
      await tester.pumpWidget(
        host(DiveTrendChart(points: series(20), chartId: 'depth')),
      );

      expect(find.byKey(const ValueKey('trend-depth-zoom-in')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('trend-depth-zoom-out')),
        findsOneWidget,
      );
      expect(find.text('1.0x'), findsOneWidget);
    });

    testWidgets('the reset button appears only once zoomed', (tester) async {
      // Zooming in with no way back out is the state this prevents.
      await tester.pumpWidget(
        host(DiveTrendChart(points: series(20), chartId: 'depth')),
      );

      expect(
        find.byKey(const ValueKey('trend-depth-zoom-reset')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('trend-depth-zoom-in')));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('trend-depth-zoom-reset')),
        findsOneWidget,
      );
    });

    testWidgets('zoom in narrows the window and reset restores it', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(DiveTrendChart(points: series(20), chartId: 'depth')),
      );
      final full = readData(tester);
      final fullSpan = full.maxX - full.minX;

      await tester.tap(find.byKey(const ValueKey('trend-depth-zoom-in')));
      await tester.pump();
      expect(readData(tester).maxX - readData(tester).minX, lessThan(fullSpan));

      await tester.tap(find.byKey(const ValueKey('trend-depth-zoom-reset')));
      await tester.pump();
      expect(
        readData(tester).maxX - readData(tester).minX,
        closeTo(fullSpan, 1),
      );
    });
  });

  group('tapping a dive', () {
    List<TrendDataPoint> withIds() => List.generate(
      20,
      (i) => TrendDataPoint(
        date: DateTime.utc(2024, 1, 1).add(Duration(days: i * 7)),
        value: 10.0 + i,
        diveId: 'dive-$i',
      ),
    );

    testWidgets('reports the dive behind a tapped raw point', (tester) async {
      String? tapped;
      await tester.pumpWidget(
        host(
          DiveTrendChart(
            points: withIds(),
            onDiveSelected: (id) => tapped = id,
          ),
        ),
      );

      final data = readData(tester);
      final bars = data.lineBarsData;
      data.lineTouchData.touchCallback!(
        FlTapUpEvent(TapUpDetails(kind: PointerDeviceKind.mouse)),
        LineTouchResponse(
          touchLocation: Offset.zero,
          touchChartCoordinate: Offset.zero,
          lineBarSpots: [TouchLineBarSpot(bars[0], 0, bars[0].spots[3], 0)],
        ),
      );
      await tester.pump();

      expect(tapped, 'dive-3');
    });

    testWidgets('reports nothing for an aggregated bucket', (tester) async {
      // A bucket stands for several dives, so there is no single one to open.
      String? tapped;
      await tester.pumpWidget(
        host(
          DiveTrendChart(
            points: withIds(),
            aggregation: TrendAggregation.monthly,
            onDiveSelected: (id) => tapped = id,
          ),
        ),
      );

      final data = readData(tester);
      final bars = data.lineBarsData;
      data.lineTouchData.touchCallback!(
        FlTapUpEvent(TapUpDetails(kind: PointerDeviceKind.mouse)),
        LineTouchResponse(
          touchLocation: Offset.zero,
          touchChartCoordinate: Offset.zero,
          lineBarSpots: [TouchLineBarSpot(bars[0], 0, bars[0].spots.first, 0)],
        ),
      );
      await tester.pump();

      expect(tapped, isNull);
    });
  });

  testWidgets('frames the plot area like the dive profile chart', (
    tester,
  ) async {
    // Without a border the plot floats on the card with nothing bounding it.
    await tester.pumpWidget(host(DiveTrendChart(points: series(20))));

    final border = readData(tester).borderData;

    expect(border.show, isTrue);
    expect(border.border.top.width, greaterThan(0));
    expect(border.border.bottom.width, greaterThan(0));
    expect(border.border.left.width, greaterThan(0));
    expect(border.border.right.width, greaterThan(0));
  });

  testWidgets('caps the tooltip width so a value cannot wrap mid-row', (
    tester,
  ) async {
    // Without a cap the bubble sized to its container and broke rows like
    // "Rolling avg 85 psi/min" across two lines.
    await tester.pumpWidget(host(DiveTrendChart(points: series(20))));

    final tooltip = readData(tester).lineTouchData.touchTooltipData;

    expect(tooltip.maxContentWidth, greaterThanOrEqualTo(300));
  });

  group('hover line', () {
    testWidgets('spans the full plot height, not just up to the point', (
      tester,
    ) async {
      // fl_chart's default line stops at the touched spot, so for a series
      // sitting near zero it is a few pixels tall and reads as absent.
      await tester.pumpWidget(host(DiveTrendChart(points: series(20))));

      final touch = readData(tester).lineTouchData;
      final bar = readData(tester).lineBarsData.first;

      expect(touch.getTouchLineStart(bar, 0), double.negativeInfinity);
      expect(touch.getTouchLineEnd(bar, 0), double.infinity);
    });

    testWidgets('draws the line on the data series', (tester) async {
      await tester.pumpWidget(host(DiveTrendChart(points: series(20))));

      final data = readData(tester);
      final indicator = data.lineTouchData.getTouchedSpotIndicator(
        data.lineBarsData.first,
        [0],
      ).single;

      expect(indicator, isNotNull);
      expect(indicator!.indicatorBelowLine.strokeWidth, greaterThan(0));
    });
  });
}
