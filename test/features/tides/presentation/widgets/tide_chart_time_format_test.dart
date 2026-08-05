import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/core/tide/entities/tide_prediction.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// Tide instants are stored wall-clock-as-UTC: the digits the diver saw,
// flagged UTC. Every label the chart paints must print those digits verbatim.
// `.toLocal()` shifts them by the MACHINE's UTC offset, so on any non-UTC
// host the pre-fix code renders shifted digits and these tests fail. (#222)
final _reference = DateTime.utc(2026, 1, 15, 22);
final _highTide = DateTime.utc(2026, 1, 16, 1);
final _lowTide = DateTime.utc(2026, 1, 16, 7);

final _extremes = [
  TideExtreme(type: TideExtremeType.high, time: _highTide, heightMeters: 2.4),
  TideExtreme(type: TideExtremeType.low, time: _lowTide, heightMeters: 0.4),
];

/// Half-hourly predictions spanning the whole chart window.
///
/// The chart's visible window is derived as `reference - 6h` (no past
/// extremes) through `secondFutureExtreme + 30min`, i.e. 16:00 Jan 15 through
/// 07:30 Jan 16. The first visible prediction therefore lands exactly on
/// 16:00, which anchors the tooltip assertion below.
List<TidePrediction> _buildPredictions() {
  final start = DateTime.utc(2026, 1, 15, 12);
  return [
    for (var i = 0; i <= 48; i++)
      TidePrediction(
        time: start.add(Duration(minutes: 30 * i)),
        heightMeters: 1.4 + math.sin(i * math.pi / 12),
      ),
  ];
}

Future<void> _pumpChart(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 800,
            child: TideChart(
              predictions: _buildPredictions(),
              extremes: _extremes,
              now: _reference,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// All semantics labels currently in the tree.
Iterable<String> _semanticsLabels(WidgetTester tester) => tester
    .widgetList<Semantics>(find.byType(Semantics))
    .map((s) => s.properties.label)
    .whereType<String>();

void main() {
  // The chart formats via DateFormat(pattern) with no explicit locale, so it
  // resolves against intl's process-global default. Pin it so the expected
  // digits do not depend on the locale the test host happens to run under.
  String? previousDefaultLocale;

  setUp(() {
    previousDefaultLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });

  tearDown(() {
    Intl.defaultLocale = previousDefaultLocale;
  });

  group('TideChart wall-clock time formatting (#222)', () {
    testWidgets('the "Now" label prints the reference wall clock verbatim', (
      tester,
    ) async {
      await _pumpChart(tester);

      expect(find.textContaining('22:00'), findsOneWidget);
    });

    testWidgets('bottom axis labels print window wall-clock times verbatim', (
      tester,
    ) async {
      await _pumpChart(tester);

      // Window starts at 16:00 with a 4-hour tick interval.
      expect(find.text('16:00'), findsOneWidget);
      expect(find.text('20:00'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('04:00'), findsOneWidget);
    });

    testWidgets('the top axis day label marks the wall-clock midnight', (
      tester,
    ) async {
      await _pumpChart(tester);

      // Midnight inside the window is 00:00 on Fri Jan 16. A device-local
      // shift would move the crossing off the tick and drop the label.
      expect(find.text('Fri'), findsOneWidget);
    });

    testWidgets('the screen-reader summary lists unshifted extreme times', (
      tester,
    ) async {
      await _pumpChart(tester);

      final summary = _semanticsLabels(
        tester,
      ).firstWhere((l) => l.contains('Tide chart.'));
      expect(summary, contains('at 01:00'));
      expect(summary, contains('at 07:00'));
    });

    testWidgets('extreme marker labels print unshifted times', (tester) async {
      await _pumpChart(tester);

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      final labels = chart.data.extraLinesData.verticalLines
          .map((line) => line.label.labelResolver(line))
          .toList();

      expect(labels, contains(' H 01:00 2.4m '));
      expect(labels, contains(' L 07:00 0.4m '));
    });

    testWidgets('the touch tooltip prints the unshifted point time and date', (
      tester,
    ) async {
      await _pumpChart(tester);

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      final data = chart.data;
      final curve = data.lineBarsData.first;
      final items = data.lineTouchData.touchTooltipData.getTooltipItems([
        LineBarSpot(curve, 0, curve.spots.first),
      ]);

      final tooltip = items.first!;
      // First visible prediction is 16:00 on Thu Jan 15.
      expect(tooltip.text, '16:00\n');
      expect(
        tooltip.children!.map((span) => span.toPlainText()).join(),
        contains('Thu, Jan 15'),
      );
    });
  });
}
