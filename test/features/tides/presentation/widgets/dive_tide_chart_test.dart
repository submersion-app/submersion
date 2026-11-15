import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/core/tide/entities/tide_prediction.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tides/domain/services/dive_tide_window.dart';
import 'package:submersion/features/tides/presentation/widgets/dive_tide_chart.dart';
import 'package:submersion/features/tides/presentation/widgets/dive_tide_chart_painter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A dive entered at 10:05 on Saturday 28 March 2026, with a 12.4 hour tide
/// that peaks at 14:20: highs at 01:56 and 14:20, lows at 08:08 and 20:32.
final _entry = DateTime.utc(2026, 3, 28, 10, 5);
final _high = DateTime.utc(2026, 3, 28, 14, 20);
const _period = Duration(hours: 12, minutes: 24);

double _heightAt(DateTime time) {
  final phase =
      time.difference(_high).inSeconds / _period.inSeconds * 2 * math.pi;
  return 1.4 + math.cos(phase);
}

DiveTideWindow _window() {
  final start = _entry.subtract(diveTideWindowHalfSpan);
  final end = _entry.add(diveTideWindowHalfSpan);
  return DiveTideWindow(
    entry: _entry,
    start: start,
    end: end,
    predictions: [
      for (
        var time = start;
        !time.isAfter(end);
        time = time.add(const Duration(minutes: 10))
      )
        TidePrediction(time: time, heightMeters: _heightAt(time)),
    ],
    extremes: [
      TideExtreme(
        type: TideExtremeType.high,
        time: _high.subtract(_period),
        heightMeters: 2.4,
      ),
      TideExtreme(
        type: TideExtremeType.low,
        time: _high.subtract(_period ~/ 2),
        heightMeters: 0.4,
      ),
      TideExtreme(type: TideExtremeType.high, time: _high, heightMeters: 2.4),
      TideExtreme(
        type: TideExtremeType.low,
        time: _high.add(_period ~/ 2),
        heightMeters: 0.4,
      ),
    ],
  );
}

DateTime _identity(DateTime instant) => instant;

Future<void> _pump(
  WidgetTester tester, {
  double width = 600,
  AppSettings settings = const AppSettings(
    timeFormat: TimeFormat.twentyFourHour,
  ),
  DateTime Function(DateTime) displayTime = _identity,
  Duration? diveDuration,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: DiveTideChart(
              window: _window(),
              units: UnitFormatter(settings),
              displayTime: displayTime,
              diveDuration: diveDuration,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Iterable<Text> _chartTexts(WidgetTester tester) => tester.widgetList<Text>(
  find.descendant(of: find.byType(DiveTideChart), matching: find.byType(Text)),
);

DiveTideChartPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find
                  .descendant(
                    of: find.byType(DiveTideChart),
                    matching: find.byType(CustomPaint),
                  )
                  .first,
            )
            .painter!
        as DiveTideChartPainter;

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

  testWidgets('labels every high and low in the day around the dive', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('H 01:56 · 2.4m'), findsOneWidget);
    expect(find.text('L 08:08 · 0.4m'), findsOneWidget);
    expect(find.text('H 14:20 · 2.4m'), findsOneWidget);
    expect(find.text('L 20:32 · 0.4m'), findsOneWidget);
  });

  testWidgets('marks the dive with its entry time', (tester) async {
    await _pump(tester);

    expect(find.text('10:05'), findsOneWidget);
    expect(find.byIcon(Icons.scuba_diving), findsOneWidget);
  });

  testWidgets('every chart label is drawn at 14 px (#4567)', (tester) async {
    await _pump(tester);

    final texts = _chartTexts(tester).toList();
    // Four extremes, the dive marker, and both axes.
    expect(texts.length, greaterThan(8));
    for (final text in texts) {
      expect(
        text.style?.fontSize,
        14,
        reason: '"${text.data}" is not at the chart label size',
      );
    }
    // The old graph drew its marks at 9 px.
    final high = tester.widget<Text>(find.text('H 14:20 · 2.4m'));
    expect(high.style?.fontSize, 14);
    final entry = tester.widget<Text>(find.text('10:05'));
    expect(entry.style?.fontSize, 14);
  });

  testWidgets('a narrow card keeps the time and drops the height', (
    tester,
  ) async {
    await _pump(tester, width: 320);

    expect(find.text('H 14:20'), findsOneWidget);
    expect(find.text('L 08:08'), findsOneWidget);
    expect(find.textContaining('· 2.4m'), findsNothing);
    expect(tester.takeException(), isNull);

    // Nothing spills past the chart's own box.
    final chart = tester.getRect(find.byType(DiveTideChart));
    for (final element
        in find
            .descendant(
              of: find.byType(DiveTideChart),
              matching: find.byType(Text),
            )
            .evaluate()) {
      final rect = tester.getRect(find.byWidget(element.widget));
      expect(rect.left, greaterThanOrEqualTo(chart.left - 0.5));
      expect(rect.right, lessThanOrEqualTo(chart.right + 0.5));
    }
  });

  testWidgets('times follow the 12-hour clock setting', (tester) async {
    await _pump(
      tester,
      width: 900,
      settings: const AppSettings(timeFormat: TimeFormat.twelveHour),
    );

    expect(find.text('H 2:20 PM · 2.4m'), findsOneWidget);
    expect(find.text('10:05 AM'), findsOneWidget);
  });

  testWidgets('heights follow the depth unit setting', (tester) async {
    await _pump(
      tester,
      settings: const AppSettings(
        depthUnit: DepthUnit.feet,
        timeFormat: TimeFormat.twentyFourHour,
      ),
    );

    // 2.4 m is 7.9 ft; 0.4 m is 1.3 ft.
    expect(find.text('H 14:20 · 7.9ft'), findsOneWidget);
    expect(find.text('L 08:08 · 1.3ft'), findsOneWidget);
  });

  testWidgets('labels are printed in the site clock', (tester) async {
    // A site four hours behind UTC.
    await _pump(
      tester,
      displayTime: (instant) => instant.subtract(const Duration(hours: 4)),
    );

    expect(find.text('H 10:20 · 2.4m'), findsOneWidget);
    expect(find.text('06:05'), findsOneWidget);
  });

  testWidgets('the time axis names the day at midnight', (tester) async {
    await _pump(tester);

    // The window runs 22:05 Friday to 22:05 Saturday, so it holds one
    // midnight: the start of Saturday.
    expect(find.text('Sat'), findsOneWidget);
    expect(find.text('00:00'), findsNothing);
    expect(find.text('12:00'), findsOneWidget);
  });

  testWidgets('the dive is shaded from entry to exit', (tester) async {
    await _pump(tester, diveDuration: const Duration(minutes: 72));

    final painter = _painter(tester);
    final plotWidth = painter.plot.width;
    expect(painter.exitX, isNotNull);
    expect(
      painter.exitX! - painter.entryX,
      closeTo(plotWidth * 72 / (24 * 60), 0.01),
    );
    // The entry sits at the middle of a window centred on it.
    expect(painter.entryX, closeTo(painter.plot.center.dx, 0.01));
  });

  testWidgets('a dive with no known duration is marked at entry only', (
    tester,
  ) async {
    await _pump(tester);

    expect(_painter(tester).exitX, isNull);
  });

  testWidgets('describes the highs and lows to a screen reader', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);

    expect(
      find.bySemanticsLabel(
        RegExp(r'Tide chart\. High tide at 01:56, 2\.4m\. Low tide at 08:08'),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });
}
