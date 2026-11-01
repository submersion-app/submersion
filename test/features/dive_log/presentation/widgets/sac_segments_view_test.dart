import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/core/theme/contrast_ratio.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/utils/sac_rate_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_segment_colors.dart';
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
  GasMix? gasMix,
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
  gasMix: gasMix,
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
  final chart = tester.getRect(find.byKey(SacTimeColumns.plotKey));
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
      final chart = tester.getRect(find.byKey(SacTimeColumns.plotKey));

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
      // The page scrolls; this checks the card, not the 600 point test window.
      tester.view.physicalSize = const Size(2400, 3000);
      addTearDown(tester.view.resetPhysicalSize);

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

  group('colors', () {
    final hues = {
      for (final phase in DivePhase.values) ...{
        '${phase.name} light': (
          SacSegmentColors.forPhase(phase, Brightness.light),
          Brightness.light,
        ),
        '${phase.name} dark': (
          SacSegmentColors.forPhase(phase, Brightness.dark),
          Brightness.dark,
        ),
      },
      for (final brightness in Brightness.values)
        for (final gas in [
          GasColors.air,
          GasColors.nitrox,
          GasColors.oxygen,
          GasColors.trimix,
        ])
          'gas ${gas.toARGB32()} ${brightness.name}': (gas, brightness),
    };

    for (final preset in AppThemeRegistry.presets) {
      for (final brightness in Brightness.values) {
        final theme = AppThemeRegistry.resolveTheme(preset, brightness);
        final scheme = theme.colorScheme;
        final card = Color.alphaBlend(
          theme.cardTheme.color ?? scheme.surfaceContainerLow,
          scheme.surface,
        );

        test('stand out with no hue on ${preset.id} ${brightness.name}', () {
          final idle = SacSegmentColors.idle(scheme.primary, theme);

          expect(contrastRatio(idle, card), greaterThan(1.4));
          expect(contrastRatio(scheme.primary, idle), greaterThan(1.2));
        });

        for (final MapEntry(key: name, value: (hue, mode)) in hues.entries) {
          if (mode != brightness) continue;

          test('$name stands out on ${preset.id} ${brightness.name}', () {
            final idle = SacSegmentColors.idle(hue, theme);

            expect(contrastRatio(idle, card), greaterThan(1.4));
            expect(contrastRatio(hue, idle), greaterThan(1.2));
          });

          test('$name keeps a row label readable on ${preset.id} '
              '${brightness.name}', () {
            final bar = SacSegmentColors.barFill(hue, theme);

            expect(contrastRatio(scheme.onSurface, bar), greaterThan(4.5));
            expect(contrastRatio(bar, card), greaterThan(1.1));
          });
        }
      }
    }

    for (final preset in AppThemeRegistry.presets) {
      for (final brightness in Brightness.values) {
        test('resolve to opaque on ${preset.id} ${brightness.name}', () {
          final theme = AppThemeRegistry.resolveTheme(preset, brightness);

          expect(SacSegmentColors.idle(Colors.blue, theme).a, 1.0);
          expect(SacSegmentColors.barFill(Colors.blue, theme).a, 1.0);
        });
      }
    }

    test('give every phase its own hue', () {
      for (final brightness in Brightness.values) {
        final colors = {
          for (final phase in DivePhase.values)
            SacSegmentColors.forPhase(phase, brightness),
        };
        expect(colors, hasLength(DivePhase.values.length));
      }
    });

    Color columnColor(WidgetTester tester, int index) {
      final boxes = tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byKey(SacTimeColumns.plotKey),
          matching: find.byType(DecoratedBox),
        ),
      );
      return (boxes.elementAt(index).decoration as BoxDecoration).color!;
    }

    testWidgets('a column takes the color of the phase it mostly falls in', (
      tester,
    ) async {
      await _pump(tester);
      final theme = Theme.of(tester.element(find.byType(SacTimeColumns)));
      Color idle(DivePhase phase) => SacSegmentColors.idle(
        SacSegmentColors.forPhase(phase, theme.brightness),
        theme,
      );

      expect(columnColor(tester, 0), idle(DivePhase.bottom));
      expect(columnColor(tester, 1), idle(DivePhase.bottom));
      expect(columnColor(tester, 3), idle(DivePhase.safetyStop));
    });

    testWidgets('the selected column draws at full strength', (tester) async {
      await _pump(tester, selectedTimestamp: 7 * 60);
      final scheme = Theme.of(
        tester.element(find.byType(SacTimeColumns)),
      ).colorScheme;

      expect(
        columnColor(tester, 1),
        SacSegmentColors.forPhase(DivePhase.bottom, scheme.brightness),
      );
    });

    testWidgets('columns stay on the primary color with no phase data', (
      tester,
    ) async {
      await _pump(tester, phases: const []);
      final theme = Theme.of(tester.element(find.byType(SacTimeColumns)));

      expect(
        columnColor(tester, 0),
        SacSegmentColors.idle(theme.colorScheme.primary, theme),
      );
    });

    testWidgets('a phase row uses the color of its columns', (tester) async {
      await _pump(tester, gases: const []);
      final scheme = Theme.of(
        tester.element(find.byType(SacTimeColumns)),
      ).colorScheme;

      final rows = tester
          .widget<SacSegmentTable>(find.byType(SacSegmentTable))
          .sections
          .single
          .rows;
      expect(rows.map((r) => r.color), [
        for (final phase in [
          DivePhase.descent,
          DivePhase.bottom,
          DivePhase.ascent,
          DivePhase.safetyStop,
        ])
          SacSegmentColors.forPhase(phase, scheme.brightness),
      ]);
    });

    testWidgets('a gas row uses the color of its gas everywhere else', (
      tester,
    ) async {
      await _pump(
        tester,
        phases: const [],
        gases: [
          _segment(0, 15, tankId: 'back', gasMix: const GasMix(o2: 18, he: 45)),
          _segment(15, 20, tankId: 'deco', gasMix: const GasMix(o2: 50)),
        ],
      );

      final rows = tester
          .widget<SacSegmentTable>(find.byType(SacSegmentTable))
          .sections
          .single
          .rows;
      expect(rows.map((r) => r.color), [GasColors.trimix, GasColors.nitrox]);
    });

    testWidgets('a gas row with no known mix has no color of its own', (
      tester,
    ) async {
      await _pump(tester, phases: const []);

      final rows = tester
          .widget<SacSegmentTable>(find.byType(SacSegmentTable))
          .sections
          .single
          .rows;
      expect(rows.map((r) => r.color), everyElement(isNull));
    });
  });

  group('rate axis', () {
    double columnFactor(WidgetTester tester, int index) => tester
        .widgetList<FractionallySizedBox>(
          find.descendant(
            of: find.byKey(SacTimeColumns.plotKey),
            matching: find.byType(FractionallySizedBox),
          ),
        )
        .elementAt(index)
        .heightFactor!;

    testWidgets('labels the scale, with the unit on the top line', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('20 L/min'), findsOneWidget);
      expect(find.text('10'), findsAtLeastNWidgets(1));
      // Zero is also the first mark on the time axis.
      expect(find.text('0'), findsNWidgets(2));
    });

    testWidgets('follows the lane in view', (tester) async {
      await _pump(tester, rates: _rates(lane: GasConsumptionLane.sac));

      expect(find.text('2 bar/min'), findsOneWidget);
    });

    testWidgets('follows the diver\'s units', (tester) async {
      await _pump(
        tester,
        rates: SacRateDisplay(
          units: const UnitFormatter(
            AppSettings(pressureUnit: PressureUnit.psi),
          ),
          lane: GasConsumptionLane.sac,
          normalizationFactor: 1.0,
          volumeFor: (_) => null,
        ),
      );

      expect(find.text('30 psi/min'), findsOneWidget);
    });

    testWidgets('falls back to pressure when a column cannot convert', (
      tester,
    ) async {
      await _pump(
        tester,
        time: [
          _segment(0, 5, tankId: 'back', sacRate: 2.0),
          _segment(5, 10, tankId: 'stage'),
        ],
        rates: _rates(volumeFor: (id) => id == 'back' ? 10.0 : null),
      );

      expect(find.text('2 bar/min'), findsOneWidget);
    });

    testWidgets('a column reaches the value it reads on the axis', (
      tester,
    ) async {
      await _pump(
        tester,
        time: [_segment(0, 5, sacRate: 2.2), _segment(5, 10, sacRate: 1.1)],
      );

      // 22 L/min on an axis that tops out at 30.
      expect(find.text('30 L/min'), findsOneWidget);
      expect(columnFactor(tester, 0), closeTo(22 / 30, 1e-9));
      expect(columnFactor(tester, 1), closeTo(11 / 30, 1e-9));
    });

    testWidgets('the average line uses the same scale', (tester) async {
      await _pump(
        tester,
        time: [_segment(0, 5, sacRate: 2.2), _segment(5, 10, sacRate: 1.1)],
      );

      final chart = tester.widget<SacTimeColumns>(find.byType(SacTimeColumns));
      expect(chart.averageFactor, closeTo(16.5 / 30, 1e-9));
    });

    testWidgets('leaves the axis off a dive with no consumption', (
      tester,
    ) async {
      await _pump(tester, time: [_segment(0, 5, sacRate: 0)]);

      expect(
        tester.widget<SacTimeColumns>(find.byType(SacTimeColumns)).rateTicks,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('sits left of the plot in a right-to-left locale', (
      tester,
    ) async {
      await _pump(tester, locale: const Locale('ar'));
      final plot = tester.getRect(find.byKey(SacTimeColumns.plotKey));
      final chart = tester.getRect(find.byType(SacTimeColumns));

      expect(plot.right, chart.right);
      expect(plot.left, greaterThan(chart.left));
    });

    testWidgets('leaves the screen reader on the columns', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);

      expect(find.bySemanticsLabel('20 L/min'), findsNothing);
      handle.dispose();
    });

    testWidgets('picks the right column across the plot, not the card', (
      tester,
    ) async {
      await _pump(tester);
      final plot = tester.getRect(find.byKey(SacTimeColumns.plotKey));

      Future<void> tapAcross(double share) async {
        await tester.tapAt(
          Offset(plot.left + plot.width * share, plot.top + 30),
        );
        await tester.pump();
      }

      await tapAcross(0.55);
      expect(find.textContaining('10-15 min ·'), findsOneWidget);

      await tapAcross(0.8);
      expect(find.textContaining('15-20 min ·'), findsOneWidget);
    });
  });

  group('time axis', () {
    List<Text> axisLabels(WidgetTester tester) {
      final columns = find.byType(SacTimeColumns);
      final plot = tester.getRect(find.byKey(SacTimeColumns.plotKey));
      return tester
          .widgetList<Text>(
            find.descendant(of: columns, matching: find.byType(Text)),
          )
          .where((t) => t.data != null && t.data!.isNotEmpty)
          .where((t) {
            final rect = tester.getRect(find.byWidget(t));
            return rect.top >= plot.bottom;
          })
          .toList();
    }

    final fiftyMinutes = [
      for (var i = 0; i < 10; i++) _segment(i * 5, (i + 1) * 5),
    ];

    void widenWindow(WidgetTester tester) {
      tester.view.physicalSize = const Size(4800, 1800);
      addTearDown(tester.view.resetPhysicalSize);
    }

    testWidgets('adds marks as the card widens', (tester) async {
      widenWindow(tester);
      await _pump(tester, time: fiftyMinutes, width: 342);
      final narrow = axisLabels(tester).length;

      await _pump(tester, time: fiftyMinutes, width: 1200);

      expect(axisLabels(tester).length, greaterThan(narrow));
    });

    testWidgets('marks every column once there is room', (tester) async {
      widenWindow(tester);
      await _pump(tester, time: fiftyMinutes, width: 1200);

      expect(axisLabels(tester).map((t) => t.data), [
        for (var minutes = 0; minutes < 50; minutes += 5) '$minutes',
        '50 min',
      ]);
    });

    for (final (width, scale) in [
      (300.0, 1.0),
      (342.0, 1.0),
      (760.0, 1.0),
      (342.0, 1.5),
      (760.0, 2.0),
    ]) {
      testWidgets('no labels touch at $width wide, text x$scale', (
        tester,
      ) async {
        await _pump(
          tester,
          time: [for (var i = 0; i < 24; i++) _segment(i * 5, (i + 1) * 5)],
          width: width,
          textScaler: TextScaler.linear(scale),
        );

        final rects = [
          for (final label in axisLabels(tester))
            tester.getRect(find.byWidget(label)),
        ];
        expect(rects.length, greaterThan(1));
        for (var i = 1; i < rects.length; i++) {
          expect(rects[i].left, greaterThan(rects[i - 1].right));
        }
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('sacTimeAxisMarks', () {
    // Close to the card's real label font, at 6 points a character.
    double measured(int tick, {required bool isLast}) =>
        ('$tick'.length + (isLast ? 4 : 0)) * 6.0;

    List<int> marks(int minutes, double width) => sacTimeAxisMarks(
      totalSeconds: minutes * 60,
      width: width,
      labelWidth: measured,
    );

    test('labels every ten minutes on a phone', () {
      expect(marks(52, 280), [0, 10, 20, 30, 40, 50]);
    });

    test('labels every column on a wide card', () {
      expect(marks(52, 700), [for (var m = 0; m <= 50; m += 5) m]);
    });

    test('backs off as labels widen', () {
      double wide(int tick, {required bool isLast}) => 60;

      expect(
        sacTimeAxisMarks(totalSeconds: 3120, width: 280, labelWidth: wide),
        [0, 20, 40],
      );
    });

    test('holds a short dive to its only mark', () {
      expect(marks(0, 280), [0]);
      expect(marks(3, 280), [0]);
    });

    test('stops at the last whole step inside the dive', () {
      expect(marks(47, 280), [0, 10, 20, 30, 40]);
    });

    test('thins out a very long dive', () {
      expect(marks(1000, 280), [0, 240, 480, 720, 960]);
    });

    test('still returns marks when nothing fits', () {
      double huge(int tick, {required bool isLast}) => 500;

      expect(
        sacTimeAxisMarks(totalSeconds: 3000, width: 100, labelWidth: huge),
        isNotEmpty,
      );
    });
  });
}
