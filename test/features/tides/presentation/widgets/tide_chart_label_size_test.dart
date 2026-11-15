import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/core/tide/entities/tide_prediction.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_chart.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_cycle_graph.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import 'tide_record_fixture.dart';

// The tide charts drew the text on their marks at 9 px, which is too small
// to read (#4567). These pin the sizes the charts now use.

final _reference = DateTime.utc(2026, 1, 15, 22);

final _extremes = [
  TideExtreme(
    type: TideExtremeType.high,
    time: DateTime.utc(2026, 1, 16, 1),
    heightMeters: 2.4,
  ),
  TideExtreme(
    type: TideExtremeType.low,
    time: DateTime.utc(2026, 1, 16, 7),
    heightMeters: -0.4,
  ),
];

/// Half-hourly predictions across the chart's window, crossing the datum so
/// the mean-sea-level line is drawn.
List<TidePrediction> _predictions() {
  final start = DateTime.utc(2026, 1, 15, 12);
  return [
    for (var i = 0; i <= 48; i++)
      TidePrediction(
        time: start.add(Duration(minutes: 30 * i)),
        heightMeters: 1.0 + 1.5 * math.sin(i * math.pi / 12),
      ),
  ];
}

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Center(child: SizedBox(width: 800, child: child)),
  ),
);

void main() {
  // Times are formatted with DateFormat(pattern) and no explicit locale, so
  // the digits follow intl's process-wide default. Pin it, and put it back.
  String? previousDefaultLocale;

  setUp(() {
    previousDefaultLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });

  tearDown(() {
    Intl.defaultLocale = previousDefaultLocale;
  });

  group('TideChart label sizes (#4567)', () {
    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        _app(
          TideChart(
            predictions: _predictions(),
            extremes: _extremes,
            now: _reference,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('high and low labels are drawn at a readable size', (
      tester,
    ) async {
      await pump(tester);

      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      final labelled = data.extraLinesData.verticalLines
          .where((line) => line.label.show)
          .toList();
      expect(labelled, hasLength(2));
      for (final line in labelled) {
        expect(line.label.style?.fontSize, TideChart.markFontSize);
      }
      expect(TideChart.markFontSize, greaterThanOrEqualTo(14));
    });

    testWidgets('the mean sea level label is drawn at a readable size', (
      tester,
    ) async {
      await pump(tester);

      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      final labelled = data.extraLinesData.horizontalLines
          .where((line) => line.label.show)
          .toList();
      expect(labelled, hasLength(1));
      expect(
        labelled.single.label.style?.fontSize,
        greaterThanOrEqualTo(TideChart.axisFontSize),
      );
    });

    testWidgets('the Now marker and the axis labels are readable', (
      tester,
    ) async {
      await pump(tester);

      // The pill above the plot, not the legend's "Now".
      final now = tester.widget<Text>(find.textContaining(RegExp(r'^Now \S')));
      expect(now.style?.fontSize, TideChart.markFontSize);

      // Every text inside the plot (the axis ticks and the axis name); the
      // legend above it uses the theme's own body size.
      final plotTexts = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(LineChart),
              matching: find.byType(Text),
            ),
          )
          .toList();
      expect(plotTexts, isNotEmpty);
      for (final text in plotTexts) {
        expect(
          text.style?.fontSize,
          greaterThanOrEqualTo(TideChart.axisFontSize),
          reason: '"${text.data}" is too small to read',
        );
      }
      expect(TideChart.axisFontSize, greaterThanOrEqualTo(13));
    });
  });

  group('TideChart labels at a readable size still fit (#4567)', () {
    // A past high at 20:00 and two future extremes put the window at 19:30
    // to 08:30: each end holds an extreme only 30 minutes in from the edge.
    final edgeExtremes = [
      TideExtreme(
        type: TideExtremeType.high,
        time: DateTime.utc(2026, 1, 15, 20),
        heightMeters: 2.4,
      ),
      TideExtreme(
        type: TideExtremeType.low,
        time: DateTime.utc(2026, 1, 16, 2),
        heightMeters: -0.4,
      ),
      TideExtreme(
        type: TideExtremeType.high,
        time: DateTime.utc(2026, 1, 16, 8),
        heightMeters: 2.4,
      ),
    ];

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        _app(
          TideChart(
            predictions: _predictions(),
            extremes: edgeExtremes,
            now: _reference,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the Now label reads its time before its height', (
      tester,
    ) async {
      // The generated message takes its placeholders in alphabetical order
      // (height, then time), so passing them in sentence order printed
      // "Now -0.3m 22:00".
      await pump(tester);

      expect(find.text('Now 22:00 -0.3m'), findsOneWidget);
    });

    testWidgets('the Now label stays inside the chart at a large text size', (
      tester,
    ) async {
      // A past low at 21:45 opens the window at 21:15, so now (22:00) sits
      // near the left edge; doubled text makes the pill wider than the room
      // to its left.
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: _app(
            SizedBox(
              width: 360,
              child: TideChart(
                predictions: _predictions(),
                extremes: [
                  TideExtreme(
                    type: TideExtremeType.low,
                    time: DateTime.utc(2026, 1, 15, 21, 45),
                    heightMeters: -0.4,
                  ),
                  ...edgeExtremes.skip(1),
                ],
                now: _reference,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chart = tester.getRect(find.byType(TideChart));
      final pill = tester.getRect(find.textContaining(RegExp(r'^Now \S')));
      expect(pill.left, greaterThanOrEqualTo(chart.left - 0.5));
      expect(pill.right, lessThanOrEqualTo(chart.right + 0.5));

      // The band above the plot grows with the text, so the pill stays out
      // of the plot rather than covering its top.
      final topTitles = tester
          .widget<LineChart>(find.byType(LineChart))
          .data
          .titlesData
          .topTitles
          .sideTitles
          .reservedSize;
      expect(topTitles, greaterThanOrEqualTo(pill.height));
    });

    testWidgets('a label near either edge turns inward instead of clipping', (
      tester,
    ) async {
      await pump(tester);

      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      Alignment alignmentOf(String time) => data.extraLinesData.verticalLines
          .firstWhere(
            (line) =>
                line.label.show &&
                line.label.labelResolver(line).contains(' $time '),
          )
          .label
          .alignment;

      // Left edge: drawn to the right of its line.
      expect(alignmentOf('20:00').x, greaterThan(0));
      // Middle: centred on its line.
      expect(alignmentOf('02:00').x, 0);
      // Right edge: drawn to the left of its line.
      expect(alignmentOf('08:00').x, lessThan(0));
    });

    testWidgets('the axes print no off-step value at their ends', (
      tester,
    ) async {
      await pump(tester);

      final texts = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(LineChart),
              matching: find.byType(Text),
            ),
          )
          .map((text) => text.data)
          .whereType<String>()
          .toList();

      // Time ticks fall every 4 hours from the 19:30 start; the 08:30 end
      // sits an hour past the last one and crowded its label.
      expect(texts, contains('07:30'));
      expect(texts, isNot(contains('08:30')));

      // Heights run about -0.5 to 2.5 m, so the step is a whole metre; the
      // padded ends (-0.8 and 2.8) used to print over their neighbours.
      final heights = texts
          .where((t) => !t.contains(':'))
          .map(double.tryParse)
          .whereType<double>()
          .toList();
      expect(heights, isNotEmpty);
      for (final height in heights) {
        expect(height, closeTo(height.roundToDouble(), 1e-9));
      }
    });
  });

  group('TideCycleGraph label sizes (#4567)', () {
    testWidgets('paints its labels at a readable size', (tester) async {
      await tester.pumpWidget(
        _app(
          TideCycleGraph(
            record: risingTideRecord,
            referenceTime: DateTime.utc(2026, 3, 28, 10),
            height: TideCycleGraph.defaultHeight,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final painter = tester
          .widget<CustomPaint>(
            find
                .descendant(
                  of: find.byType(TideCycleGraph),
                  matching: find.byType(CustomPaint),
                )
                .first,
          )
          .painter!;
      // The painter is private to the widget's file; its label style is the
      // one every span it paints starts from.
      final style = (painter as dynamic).labelStyle as TextStyle;
      expect(style.fontSize, TideCycleGraph.labelFontSize);
      expect(TideCycleGraph.labelFontSize, greaterThanOrEqualTo(13));
      expect(tester.takeException(), isNull);
    });
  });
}
