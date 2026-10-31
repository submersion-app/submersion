import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/presentation/utils/sac_rate_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_segment_table.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_segments_view.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_time_columns.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

SacSegment _segment(
  int startMin,
  int endMin, {
  double sacRate = 1.0,
  double avgDepth = 20.0,
  DivePhase? phase,
  String? tankId,
  String? tankName,
}) => SacSegment(
  startTimestamp: startMin * 60,
  endTimestamp: endMin * 60,
  avgDepth: avgDepth,
  minDepth: 0.0,
  maxDepth: 30.0,
  sacRate: sacRate,
  gasConsumed: 1.0,
  phase: phase,
  tankId: tankId,
  tankName: tankName,
);

final _time = [
  _segment(0, 5, sacRate: 1.0, avgDepth: 10),
  _segment(5, 10, sacRate: 2.0, avgDepth: 20),
  _segment(10, 15, sacRate: 0.5, avgDepth: 30),
  _segment(15, 20, sacRate: 0.5, avgDepth: 5),
];

final _phases = [
  _segment(0, 2, sacRate: 2.0, avgDepth: 12, phase: DivePhase.descent),
  _segment(2, 14, sacRate: 1.0, avgDepth: 21, phase: DivePhase.bottom),
  _segment(14, 16, sacRate: 0.8, avgDepth: 11, phase: DivePhase.ascent),
  _segment(16, 19, sacRate: 0.5, avgDepth: 5, phase: DivePhase.safetyStop),
  _segment(19, 20, sacRate: 0.8, avgDepth: 2, phase: DivePhase.ascent),
];

final _gases = [
  _segment(0, 15, sacRate: 1.0, tankId: 'back', tankName: 'Back gas'),
  _segment(15, 20, sacRate: 0.5, tankId: 'stage', tankName: 'EAN50'),
];

SacRateDisplay _rates({
  GasConsumptionLane lane = GasConsumptionLane.rmv,
  double? Function(String?)? volumeFor,
}) => SacRateDisplay(
  units: const UnitFormatter(AppSettings()),
  lane: lane,
  normalizationFactor: 1.0,
  volumeFor: volumeFor ?? (_) => 10.0,
);

Future<void> _pump(
  WidgetTester tester, {
  List<SacSegment>? time,
  List<SacSegment>? phases,
  List<SacSegment>? gases,
  SacRateDisplay? rates,
  int? selectedTimestamp,
  Widget? laneSelector,
  double width = 342,
  Locale locale = const Locale('en'),
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: SacSegmentsView(
                timeSegments: time ?? _time,
                phaseSegments: phases ?? _phases,
                gasSegments: gases ?? _gases,
                rates: rates ?? _rates(),
                selectedTimestamp: selectedTimestamp,
                laneSelector: laneSelector,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Text _text(WidgetTester tester, String value) =>
    tester.widget<Text>(find.text(value));

bool _isHighlighted(WidgetTester tester, String label) =>
    _text(tester, label).style?.fontWeight == FontWeight.bold;

Offset _columnCenter(WidgetTester tester, int index, int count) {
  final chart = tester.getRect(find.byType(SacTimeColumns));
  return Offset(
    chart.left + chart.width * (index + 0.5) / count,
    chart.top + 30,
  );
}

void main() {
  group('a merged row across cylinders', () {
    testWidgets('converts each stretch with its own volume', (tester) async {
      await _pump(
        tester,
        phases: [
          _segment(0, 6, phase: DivePhase.ascent, tankId: 'twin'),
          _segment(6, 10, phase: DivePhase.ascent, tankId: 'stage'),
        ],
        gases: const [],
        rates: _rates(volumeFor: (id) => id == 'twin' ? 24.0 : 7.0),
      );

      expect(find.text('17.2'), findsOneWidget);
    });
  });

  group('time the segments do not cover', () {
    final gap = [_segment(0, 5, sacRate: 1.0), _segment(20, 25, sacRate: 2.0)];

    testWidgets('a sample gap keeps the axis on real time', (tester) async {
      await _pump(tester, time: gap);

      expect(find.text('20 min'), findsOneWidget);
    });

    testWidgets('a tap in the gap picks the next column', (tester) async {
      await _pump(tester, time: gap);
      final chart = tester.getRect(find.byType(SacTimeColumns));

      // 30% of 25 minutes is 7.5, past the first column's end at 5.
      await tester.tapAt(
        Offset(chart.left + chart.width * 0.3, chart.top + 30),
      );
      await tester.pump();
      expect(find.textContaining('20-25 min'), findsOneWidget);
    });

    testWidgets('a late first sample does not shift the axis', (tester) async {
      await _pump(
        tester,
        time: [_segment(10, 15), _segment(15, 20, sacRate: 2.0)],
      );
      final chart = tester.getRect(find.byType(SacTimeColumns));

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
    await _pump(tester);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    final center = _columnCenter(tester, 1, 4);
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
      await _pump(tester);

      expect(find.byType(SacTimeColumns), findsOneWidget);
      expect(find.text('Bottom'), findsOneWidget);
      expect(find.text('Back gas'), findsOneWidget);
      expect(find.byType(FilterChip), findsNothing);
      expect(find.byType(SegmentedButton<SacSegmentationType>), findsNothing);
    });

    testWidgets('hides Gas on a dive that stayed on one cylinder', (
      tester,
    ) async {
      await _pump(
        tester,
        gases: [_segment(0, 20, tankId: 'back', tankName: 'Back gas')],
      );

      expect(find.text('Gas'), findsNothing);
      expect(find.text('Back gas'), findsNothing);
    });

    testWidgets('leaves out a section with no data, keeping the others', (
      tester,
    ) async {
      await _pump(tester, phases: const []);

      expect(find.text('Bottom'), findsNothing);
      expect(find.text('Back gas'), findsOneWidget);
      expect(find.byType(SacTimeColumns), findsOneWidget);
    });

    testWidgets('shows only the chart when phase and gas have no data', (
      tester,
    ) async {
      await _pump(tester, phases: const [], gases: const []);

      expect(find.byType(SacTimeColumns), findsOneWidget);
      expect(find.byType(SacSegmentTable), findsNothing);
    });

    testWidgets('sets the lane selector beside the Time heading', (
      tester,
    ) async {
      await _pump(tester, laneSelector: const SizedBox(key: Key('lane')));

      final heading = tester.getCenter(find.text('Time').first);
      final lane = tester.getCenter(find.byKey(const Key('lane')));
      expect(lane.dy, closeTo(heading.dy, 1));
      expect(lane.dx, greaterThan(heading.dx));
    });
  });

  group('table', () {
    testWidgets('names the unit once, in the heading', (tester) async {
      await _pump(tester);

      expect(find.text('L/min'), findsOneWidget);
      expect(find.text('10.0'), findsNWidgets(2)); // Bottom and Back gas.
      expect(find.textContaining('10.0 L/min'), findsNothing);
    });

    testWidgets('gives a row that cannot convert its own unit', (tester) async {
      await _pump(
        tester,
        rates: _rates(volumeFor: (id) => id == 'stage' ? null : 10.0),
      );

      expect(find.text('L/min'), findsOneWidget);
      expect(find.text('0.5 bar/min'), findsOneWidget);
    });

    testWidgets('reports time spent in a phase, not its span', (tester) async {
      await _pump(tester);

      // Ascent: 2:00 + 1:00, not the 6:00 from its first start to last end.
      expect(find.text('3:00'), findsNWidgets(2)); // Ascent and Safety stop.
      expect(find.text('6:00'), findsNothing);
    });

    testWidgets('shows average depth in the diver\'s units', (tester) async {
      await _pump(
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
      await _pump(
        tester,
        phases: const [],
        gases: [
          _segment(0, 10, sacRate: 1.0, tankId: 'big', tankName: 'Big'),
          _segment(10, 20, sacRate: 1.0, tankId: 'small', tankName: 'Small'),
        ],
        rates: _rates(volumeFor: (id) => id == 'big' ? 8.0 : 4.0),
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
      await _pump(tester, phases: [_segment(0, 20, phase: DivePhase.deco)]);

      expect(find.text('Deco'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_bottom), findsOneWidget);
      expect(find.byIcon(Icons.warning), findsNothing);
    });

    testWidgets('translates phase names and headings', (tester) async {
      await _pump(tester, locale: const Locale('de'));

      expect(find.text('Grund'), findsOneWidget);
      expect(find.text('Sicherheitsstopp'), findsOneWidget);
      expect(find.text('Tiefe'), findsOneWidget);
    });
  });

  group('readout', () {
    testWidgets('names the peak segment until one is picked', (tester) async {
      await _pump(tester);

      expect(find.text('Peak 20.0 L/min at 5-10 min'), findsOneWidget);
    });

    testWidgets('tapping a column reads it out, tapping again clears it', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tapAt(_columnCenter(tester, 2, 4));
      await tester.pump();
      expect(find.text('10-15 min · 5.0 L/min · 30m'), findsOneWidget);

      await tester.tapAt(_columnCenter(tester, 2, 4));
      await tester.pump();
      expect(find.text('Peak 20.0 L/min at 5-10 min'), findsOneWidget);
    });

    testWidgets('dragging across the columns scrubs the readout', (
      tester,
    ) async {
      await _pump(tester);

      final gesture = await tester.startGesture(_columnCenter(tester, 0, 4));
      await gesture.moveTo(_columnCenter(tester, 1, 4));
      await tester.pump();
      await gesture.moveTo(_columnCenter(tester, 3, 4));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(find.text('15-20 min · 5.0 L/min · 5m'), findsOneWidget);
    });

    testWidgets('hovering a column reads it out until the pointer leaves', (
      tester,
    ) async {
      await _pump(tester);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(_columnCenter(tester, 0, 4));
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
      await _pump(tester, selectedTimestamp: 16 * 60 + 30);

      expect(find.text('15-20 min · 5.0 L/min · 5m'), findsOneWidget);
      expect(_isHighlighted(tester, 'Safety stop'), isTrue);
      expect(_isHighlighted(tester, 'Bottom'), isFalse);
      expect(_isHighlighted(tester, 'EAN50'), isTrue);
      expect(_isHighlighted(tester, 'Back gas'), isFalse);
    });

    testWidgets('highlights nothing with no point selected', (tester) async {
      await _pump(tester);

      expect(_isHighlighted(tester, 'Bottom'), isFalse);
      expect(_isHighlighted(tester, 'Back gas'), isFalse);
    });

    testWidgets('a tapped column also marks its phase and gas rows', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tapAt(_columnCenter(tester, 0, 4));
      await tester.pump();

      expect(_isHighlighted(tester, 'Bottom'), isTrue); // Middle of 0-5 min.
      expect(_isHighlighted(tester, 'Back gas'), isTrue);
    });

    testWidgets('moving the chart cursor replaces a tapped column', (
      tester,
    ) async {
      await _pump(tester, selectedTimestamp: 60);
      await tester.tapAt(_columnCenter(tester, 3, 4));
      await tester.pump();
      expect(find.textContaining('15-20 min'), findsOneWidget);

      await _pump(tester, selectedTimestamp: 7 * 60);
      await tester.pump();

      expect(find.textContaining('5-10 min'), findsOneWidget);
    });
  });

  group('layout', () {
    for (final width in [342.0, 300.0]) {
      testWidgets('fits at $width wide with long labels', (tester) async {
        await _pump(
          tester,
          width: width,
          gases: [
            _segment(0, 15, tankId: 'a', tankName: 'A very long cylinder name'),
            _segment(15, 20, tankId: 'b', tankName: 'Another long name here'),
          ],
        );

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('fits at large text', (tester) async {
      await _pump(
        tester,
        width: 342,
        textScaler: const TextScaler.linear(1.5),
        rates: _rates(volumeFor: (id) => id == 'stage' ? null : 10.0),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('stays the same height however long the dive', (tester) async {
      await _pump(tester);
      final short = tester.getSize(find.byType(SacTimeColumns)).height;

      await _pump(
        tester,
        time: [
          for (var i = 0; i < 60; i++)
            _segment(i * 5, (i + 1) * 5, sacRate: 1.0 + i % 3),
        ],
      );

      expect(tester.getSize(find.byType(SacTimeColumns)).height, short);
    });

    testWidgets('keeps time running left to right in a right-to-left locale', (
      tester,
    ) async {
      await _pump(tester, locale: const Locale('ar'));

      await tester.tapAt(_columnCenter(tester, 0, 4));
      await tester.pump();

      expect(find.textContaining('0-5'), findsOneWidget);
    });

    testWidgets('a screen reader can activate a column', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);

      tester.semantics.tap(find.semantics.byLabel('15-20 min, 5.0 L/min, 5m'));
      await tester.pump();

      expect(find.text('15-20 min · 5.0 L/min · 5m'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('announces each column to a screen reader', (tester) async {
      final handle = tester.ensureSemantics();

      await _pump(tester);

      expect(
        find.bySemanticsLabel('5-10 min, 20.0 L/min, 20m'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('column colors', () {
    double contrast(Color a, Color b) {
      final (lighter, darker) = a.computeLuminance() > b.computeLuminance()
          ? (a, b)
          : (b, a);
      return (lighter.computeLuminance() + 0.05) /
          (darker.computeLuminance() + 0.05);
    }

    for (final preset in AppThemeRegistry.presets) {
      for (final brightness in Brightness.values) {
        test('stand out on ${preset.id} ${brightness.name}', () {
          final theme = AppThemeRegistry.resolveTheme(preset, brightness);
          final scheme = theme.colorScheme;
          final card = theme.cardTheme.color ?? scheme.surfaceContainerLow;
          final idle = SacTimeColumns.idleColor(scheme);

          expect(contrast(idle, card), greaterThan(1.4));
          expect(contrast(scheme.primary, idle), greaterThan(1.2));
        });
      }
    }
  });

  group('sacTimeAxisTicks', () {
    test('keeps the axis to a few labels at any length', () {
      expect(sacTimeAxisTicks(20), [0, 5, 10, 15, 20]);
      expect(sacTimeAxisTicks(40), [0, 10, 20, 30, 40]);
      expect(sacTimeAxisTicks(60), [0, 15, 30, 45, 60]);
      expect(sacTimeAxisTicks(180), [0, 60, 120, 180]);
      expect(sacTimeAxisTicks(1000), [0, 240, 480, 720, 960]);
    });

    test('stops at the last whole step inside the dive', () {
      expect(sacTimeAxisTicks(47), [0, 15, 30, 45]);
    });

    test('never returns an empty axis', () {
      expect(sacTimeAxisTicks(0), [0]);
    });
  });
}
