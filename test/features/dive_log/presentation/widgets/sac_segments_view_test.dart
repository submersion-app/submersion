import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/presentation/utils/sac_rate_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_segment_table.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_time_columns.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import 'sac_segments_test_harness.dart';

void main() {
  group('a merged row across cylinders', () {
    testWidgets('converts each stretch with its own volume', (tester) async {
      await pumpSacSegmentsView(
        tester,
        phases: [
          sacSegment(0, 6, phase: DivePhase.ascent, tankId: 'twin'),
          sacSegment(6, 10, phase: DivePhase.ascent, tankId: 'stage'),
        ],
        gases: const [],
        rates: sacRates(volumeFor: (id) => id == 'twin' ? 24.0 : 7.0),
      );

      expect(find.text('17.2'), findsOneWidget);
    });
  });

  group('time the segments do not cover', () {
    final gap = [
      sacSegment(0, 5, sacRate: 1.0),
      sacSegment(20, 25, sacRate: 2.0),
    ];

    testWidgets('a sample gap keeps the axis on real time', (tester) async {
      await pumpSacSegmentsView(tester, time: gap);

      expect(find.text('20 min'), findsOneWidget);
    });

    testWidgets('a tap in the gap picks the next column', (tester) async {
      await pumpSacSegmentsView(tester, time: gap);
      final chart = tester.getRect(find.byKey(SacTimeColumns.plotKey));

      // 30% of 25 minutes is 7.5, past the first column's end at 5.
      await tester.tapAt(
        Offset(chart.left + chart.width * 0.3, chart.top + 30),
      );
      await tester.pump();
      expect(find.textContaining('20-25 min'), findsOneWidget);
    });

    testWidgets('a late first sample does not shift the axis', (tester) async {
      await pumpSacSegmentsView(
        tester,
        time: [sacSegment(10, 15), sacSegment(15, 20, sacRate: 2.0)],
      );
      final chart = tester.getRect(find.byKey(SacTimeColumns.plotKey));

      expect(find.text('20 min'), findsOneWidget);
      await tester.tapAt(
        Offset(chart.left + chart.width * 0.6, chart.top + 30),
      );
      await tester.pump();
      expect(find.textContaining('10-15 min'), findsOneWidget);
    });
  });

  testWidgets('hovering inside one column does not rebuild the card', (
    tester,
  ) async {
    await pumpSacSegmentsView(tester);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    final center = sacColumnCenter(tester, 1, 4);
    await gesture.addPointer(location: center);
    await gesture.moveTo(center);
    await tester.pump();

    await gesture.moveTo(center + const Offset(2, 0));

    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  group('all three breakdowns at once', () {
    testWidgets('shows time, phase and gas together with no mode control', (
      tester,
    ) async {
      await pumpSacSegmentsView(tester);

      expect(find.byType(SacTimeColumns), findsOneWidget);
      expect(find.text('Bottom'), findsOneWidget);
      expect(find.text('Back gas'), findsOneWidget);
      expect(find.byType(FilterChip), findsNothing);
      expect(find.byType(SegmentedButton<SacSegmentationType>), findsNothing);
    });

    testWidgets('hides Gas on a dive that stayed on one cylinder', (
      tester,
    ) async {
      await pumpSacSegmentsView(
        tester,
        gases: [sacSegment(0, 20, tankId: 'back', tankName: 'Back gas')],
      );

      expect(find.text('Gas'), findsNothing);
      expect(find.text('Back gas'), findsNothing);
    });

    testWidgets('leaves out a section with no data, keeping the others', (
      tester,
    ) async {
      await pumpSacSegmentsView(tester, phases: const []);

      expect(find.text('Bottom'), findsNothing);
      expect(find.text('Back gas'), findsOneWidget);
      expect(find.byType(SacTimeColumns), findsOneWidget);
    });

    testWidgets('shows only the chart when phase and gas have no data', (
      tester,
    ) async {
      await pumpSacSegmentsView(tester, phases: const [], gases: const []);

      expect(find.byType(SacTimeColumns), findsOneWidget);
      expect(find.byType(SacSegmentTable), findsNothing);
    });

    testWidgets('sets the lane selector beside the Time heading', (
      tester,
    ) async {
      await pumpSacSegmentsView(
        tester,
        laneSelector: const SizedBox(key: Key('lane')),
      );

      final heading = tester.getCenter(find.text('Time').first);
      final lane = tester.getCenter(find.byKey(const Key('lane')));
      expect(lane.dy, closeTo(heading.dy, 1));
      expect(lane.dx, greaterThan(heading.dx));
    });
  });

  group('table', () {
    testWidgets('names the unit once, in the heading', (tester) async {
      await pumpSacSegmentsView(tester);

      expect(find.text('L/min'), findsOneWidget);
      expect(find.text('10.0'), findsNWidgets(2)); // Bottom and Back gas.
      expect(find.textContaining('10.0 L/min'), findsNothing);
    });

    testWidgets('gives a row that cannot convert its own unit', (tester) async {
      await pumpSacSegmentsView(
        tester,
        rates: sacRates(volumeFor: (id) => id == 'stage' ? null : 10.0),
      );

      expect(find.text('L/min'), findsOneWidget);
      expect(find.text('0.5 bar/min'), findsOneWidget);
    });

    testWidgets('reports time spent in a phase, not its span', (tester) async {
      await pumpSacSegmentsView(tester);

      // Ascent: 2:00 + 1:00, not the 6:00 from its first start to last end.
      expect(find.text('3:00'), findsNWidgets(2)); // Ascent and Safety stop.
      expect(find.text('6:00'), findsNothing);
    });

    testWidgets('shows average depth in the diver\'s units', (tester) async {
      await pumpSacSegmentsView(
        tester,
        rates: SacRateDisplay(
          units: const UnitFormatter(AppSettings()),
          lane: GasConsumptionLane.sac,
          normalizationFactor: 1.0,
          volumeFor: (_) => null,
        ),
      );

      expect(find.text('21m'), findsOneWidget);
    });

    testWidgets('sizes gas bars by the displayed rate, not bar/min', (
      tester,
    ) async {
      // The same bar/min from different cylinders: 8 L/min against 4 L/min.
      await pumpSacSegmentsView(
        tester,
        phases: const [],
        gases: [
          sacSegment(0, 10, sacRate: 1.0, tankId: 'big', tankName: 'Big'),
          sacSegment(10, 20, sacRate: 1.0, tankId: 'small', tankName: 'Small'),
        ],
        rates: sacRates(volumeFor: (id) => id == 'big' ? 8.0 : 4.0),
      );

      final bars = tester
          .widgetList<FractionallySizedBox>(
            find.descendant(
              of: find.byType(SacSegmentTable),
              matching: find.byType(FractionallySizedBox),
            ),
          )
          .map((b) => b.widthFactor);
      expect(bars, [1.0, 0.5]);
    });

    testWidgets('names a deco stop without a warning sign', (tester) async {
      await pumpSacSegmentsView(
        tester,
        phases: [sacSegment(0, 20, phase: DivePhase.deco)],
      );

      expect(find.text('Deco'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_bottom), findsOneWidget);
      expect(find.byIcon(Icons.warning), findsNothing);
    });

    testWidgets('translates phase names and headings', (tester) async {
      await pumpSacSegmentsView(tester, locale: const Locale('de'));

      expect(find.text('Grund'), findsOneWidget);
      expect(find.text('Sicherheitsstopp'), findsOneWidget);
      expect(find.text('Tiefe'), findsOneWidget);
    });
  });

  group('readout', () {
    testWidgets('names the peak segment until one is picked', (tester) async {
      await pumpSacSegmentsView(tester);

      expect(find.text('Peak 20.0 L/min at 5-10 min'), findsOneWidget);
    });

    testWidgets('tapping a column reads it out, tapping again clears it', (
      tester,
    ) async {
      await pumpSacSegmentsView(tester);

      await tester.tapAt(sacColumnCenter(tester, 2, 4));
      await tester.pump();
      expect(find.text('10-15 min · 5.0 L/min · 30m'), findsOneWidget);

      await tester.tapAt(sacColumnCenter(tester, 2, 4));
      await tester.pump();
      expect(find.text('Peak 20.0 L/min at 5-10 min'), findsOneWidget);
    });

    testWidgets('dragging across the columns scrubs the readout', (
      tester,
    ) async {
      await pumpSacSegmentsView(tester);

      final gesture = await tester.startGesture(sacColumnCenter(tester, 0, 4));
      await gesture.moveTo(sacColumnCenter(tester, 1, 4));
      await tester.pump();
      await gesture.moveTo(sacColumnCenter(tester, 3, 4));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(find.text('15-20 min · 5.0 L/min · 5m'), findsOneWidget);
    });

    testWidgets('hovering a column reads it out until the pointer leaves', (
      tester,
    ) async {
      await pumpSacSegmentsView(tester);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(sacColumnCenter(tester, 0, 4));
      await tester.pump();
      expect(find.text('0-5 min · 10.0 L/min · 10m'), findsOneWidget);

      await mouse.moveTo(Offset.zero);
      await tester.pump();
      expect(find.text('Peak 20.0 L/min at 5-10 min'), findsOneWidget);
    });
  });

  group('selected point', () {
    testWidgets('marks its column, phase row and gas row at once', (
      tester,
    ) async {
      await pumpSacSegmentsView(tester, selectedTimestamp: 16 * 60 + 30);

      expect(find.text('15-20 min · 5.0 L/min · 5m'), findsOneWidget);
      expect(sacIsHighlighted(tester, 'Safety stop'), isTrue);
      expect(sacIsHighlighted(tester, 'Bottom'), isFalse);
      expect(sacIsHighlighted(tester, 'EAN50'), isTrue);
      expect(sacIsHighlighted(tester, 'Back gas'), isFalse);
    });

    testWidgets('highlights nothing with no point selected', (tester) async {
      await pumpSacSegmentsView(tester);

      expect(sacIsHighlighted(tester, 'Bottom'), isFalse);
      expect(sacIsHighlighted(tester, 'Back gas'), isFalse);
    });

    testWidgets('a tapped column also marks its phase and gas rows', (
      tester,
    ) async {
      await pumpSacSegmentsView(tester);

      await tester.tapAt(sacColumnCenter(tester, 0, 4));
      await tester.pump();

      expect(sacIsHighlighted(tester, 'Bottom'), isTrue); // Middle of 0-5 min.
      expect(sacIsHighlighted(tester, 'Back gas'), isTrue);
    });

    testWidgets('moving the chart cursor replaces a tapped column', (
      tester,
    ) async {
      await pumpSacSegmentsView(tester, selectedTimestamp: 60);
      await tester.tapAt(sacColumnCenter(tester, 3, 4));
      await tester.pump();
      expect(find.textContaining('15-20 min'), findsOneWidget);

      await pumpSacSegmentsView(tester, selectedTimestamp: 7 * 60);
      await tester.pump();

      expect(find.textContaining('5-10 min'), findsOneWidget);
    });
  });

  group('layout', () {
    for (final width in [342.0, 300.0]) {
      testWidgets('fits at $width wide with long labels', (tester) async {
        await pumpSacSegmentsView(
          tester,
          width: width,
          gases: [
            sacSegment(
              0,
              15,
              tankId: 'a',
              tankName: 'A very long cylinder name',
            ),
            sacSegment(15, 20, tankId: 'b', tankName: 'Another long name here'),
          ],
        );

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('fits at large text', (tester) async {
      // The page scrolls; this checks the card, not the 600 point test window.
      tester.view.physicalSize = const Size(2400, 3000);
      addTearDown(tester.view.resetPhysicalSize);

      await pumpSacSegmentsView(
        tester,
        width: 342,
        textScaler: const TextScaler.linear(1.5),
        rates: sacRates(volumeFor: (id) => id == 'stage' ? null : 10.0),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('stays the same height however long the dive', (tester) async {
      await pumpSacSegmentsView(tester);
      final short = tester.getSize(find.byType(SacTimeColumns)).height;

      await pumpSacSegmentsView(
        tester,
        time: [
          for (var i = 0; i < 60; i++)
            sacSegment(i * 5, (i + 1) * 5, sacRate: 1.0 + i % 3),
        ],
      );

      expect(tester.getSize(find.byType(SacTimeColumns)).height, short);
    });

    testWidgets('keeps time running left to right in a right-to-left locale', (
      tester,
    ) async {
      await pumpSacSegmentsView(tester, locale: const Locale('ar'));

      await tester.tapAt(sacColumnCenter(tester, 0, 4));
      await tester.pump();

      expect(find.textContaining('0-5'), findsOneWidget);
    });

    testWidgets('a screen reader can activate a column', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSacSegmentsView(tester);

      tester.semantics.tap(find.semantics.byLabel('15-20 min, 5.0 L/min, 5m'));
      await tester.pump();

      expect(find.text('15-20 min · 5.0 L/min · 5m'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('announces each column to a screen reader', (tester) async {
      final handle = tester.ensureSemantics();

      await pumpSacSegmentsView(tester);

      expect(
        find.bySemanticsLabel('5-10 min, 20.0 L/min, 20m'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
