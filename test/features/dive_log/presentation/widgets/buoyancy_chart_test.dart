import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/weight_prediction_engine.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

BuoyancyTwinResult _result(List<TwinSample> samples) => BuoyancyTwinResult(
  samples: samples,
  staticKg: 5,
  suitSurfaceKg: 3.9,
  drysuitGasLiters: 0,
  pressuresEstimated: false,
  input: TwinInput(
    profile: const [],
    tanks: const [],
    suit: const TwinSuitInput(
      kind: TwinSuitKind.none,
      anchorKg: 0,
      source: TermSource.typeDefault,
    ),
    staticTerms: const [],
    leadKg: 6,
    droppableLeadKg: 4,
    environment: DiveEnvironment.forConditions(),
  ),
);

TwinSample _s(int t, double depth, double net) =>
    TwinSample(timestamp: t, depthM: depth, suitKg: 3, tanksKg: 0, netKg: net);

void main() {
  const units = UnitFormatter(AppSettings());

  group('BuoyancyChart.labelledMarkers', () {
    test('keeps required labels and drops a colliding optional one', () {
      // Start at the left edge, Deepest right beside it, Final stop far right.
      final kept = BuoyancyChart.labelledMarkers(
        xPx: [0, 20, 300],
        labelWidthPx: [30, 45, 50],
        optional: [false, true, false],
        plotWidthPx: 320,
      );
      expect(kept, {0, 2});
    });

    test('keeps an optional label that has room', () {
      final kept = BuoyancyChart.labelledMarkers(
        xPx: [0, 150, 300],
        labelWidthPx: [30, 45, 50],
        optional: [false, true, false],
        plotWidthPx: 320,
      );
      expect(kept, {0, 1, 2});
    });

    test('a required label is kept even when two collide', () {
      final kept = BuoyancyChart.labelledMarkers(
        xPx: [0, 10],
        labelWidthPx: [60, 60],
        optional: [false, false],
        plotWidthPx: 320,
      );
      expect(kept, {0, 1});
    });
  });

  group('BuoyancyChart.spotsFor', () {
    test('one spot per sample, x in minutes', () {
      final spots = BuoyancyChart.spotsFor([
        _s(0, 0, 2),
        _s(60, 10, 1),
        _s(120, 5, 1.5),
      ], units);
      expect(spots.length, 3);
      expect(spots[1].x, closeTo(1.0, 1e-9)); // 60 s -> 1 min
    });

    test('drops non-finite net values (NaN-FlSpot crash guard)', () {
      final spots = BuoyancyChart.spotsFor([
        _s(0, 0, 2),
        _s(60, 10, double.nan),
        _s(120, 5, 1.5),
      ], units);
      expect(spots.length, 2);
      expect(spots.every((s) => s.y.isFinite), isTrue);
    });

    // When a non-finite sample is dropped, the surviving samples and the
    // plotted spots must stay index-aligned so a touched spot resolves to the
    // right sample in the tooltip (previously it indexed the unfiltered list).
    test('plottableSamples stays in lockstep with spotsFor', () {
      final samples = [
        _s(0, 0, 2),
        _s(60, 10, double.nan), // dropped
        _s(120, 5, 1.5),
      ];
      final plotted = BuoyancyChart.plottableSamples(samples, units);
      final spots = BuoyancyChart.spotsFor(samples, units);
      expect(plotted.length, spots.length);
      // Spot index 1 maps to the t=120 sample, not the dropped NaN sample.
      expect(plotted[1].timestamp, 120);
      expect(spots[1].x, closeTo(2.0, 1e-9)); // 120 s -> 2 min
    });
  });

  testWidgets('renders a LineChart with labelled axes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: _ChartHost()),
      ),
    );
    expect(find.byType(LineChart), findsOneWidget);
    // Axis name labels are present (X = time, Y = net in the weight unit).
    expect(find.text('Time (min)'), findsOneWidget);
    expect(find.textContaining('Net'), findsWidgets);
  });

  group('profile cursor', () {
    final result = _result([
      _s(0, 0, 2),
      _s(60, 10, 1),
      _s(120, 12, 0.5),
      _s(180, 5, 1.5),
    ]);

    Future<void> pumpChart(
      WidgetTester tester, {
      int? cursorSeconds,
      ValueChanged<int?>? onCursorSeconds,
      List<BuoyancyChartMarker> markers = const [],
      int? restSeconds,
      UnitFormatter formatter = units,
    }) => tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: BuoyancyChart(
              result: result,
              units: formatter,
              cursorSeconds: cursorSeconds,
              onCursorSeconds: onCursorSeconds,
              markers: markers,
              restSeconds: restSeconds,
            ),
          ),
        ),
      ),
    );

    List<VerticalLine> verticalLines(WidgetTester tester) => tester
        .widget<LineChart>(find.byType(LineChart))
        .data
        .extraLinesData
        .verticalLines;

    testWidgets('draws a cursor line at cursorSeconds', (tester) async {
      await pumpChart(tester, cursorSeconds: 60);
      expect(verticalLines(tester).single.x, 1.0);
    });

    // The buoyant line and fill are the primary colour, so a primary cursor
    // vanished over them (review M5).
    testWidgets('the cursor line stands apart from the buoyancy line', (
      tester,
    ) async {
      await pumpChart(tester, cursorSeconds: 60);
      final primary = Theme.of(
        tester.element(find.byType(LineChart)),
      ).colorScheme.primary;
      expect(verticalLines(tester).single.color, isNot(primary));
    });

    testWidgets('no cursor line when there is no cursor', (tester) async {
      await pumpChart(tester);
      expect(verticalLines(tester), isEmpty);
    });

    // fl_chart resolves no touched spots in a widget test, so these drive the
    // chart's own callback with the response a real touch would carry.
    LineTouchResponse touching(LineChartBarData bar, int spotIndex) =>
        LineTouchResponse(
          touchLocation: Offset.zero,
          touchChartCoordinate: Offset.zero,
          lineBarSpots: [TouchLineBarSpot(bar, 0, bar.spots[spotIndex], 0)],
        );

    LineTouchData touchData(WidgetTester tester) =>
        tester.widget<LineChart>(find.byType(LineChart)).data.lineTouchData;

    LineChartBarData barOf(WidgetTester tester) => tester
        .widget<LineChart>(find.byType(LineChart))
        .data
        .lineBarsData
        .single;

    testWidgets('hovering a spot reports its sample time', (tester) async {
      final reported = <int?>[];
      await pumpChart(tester, onCursorSeconds: reported.add);
      touchData(tester).touchCallback!(
        const FlPointerHoverEvent(PointerHoverEvent()),
        touching(barOf(tester), 2),
      );
      expect(reported, [120]);
    });

    testWidgets('leaving the chart reports null', (tester) async {
      final reported = <int?>[];
      await pumpChart(tester, onCursorSeconds: reported.add);
      touchData(tester).touchCallback!(
        const FlPointerExitEvent(PointerExitEvent()),
        touching(barOf(tester), 2),
      );
      expect(reported, [null]);
    });

    testWidgets('a touch that hits no spot reports null', (tester) async {
      final reported = <int?>[];
      await pumpChart(tester, onCursorSeconds: reported.add);
      touchData(tester).touchCallback!(
        const FlPointerHoverEvent(PointerHoverEvent()),
        null,
      );
      expect(reported, [null]);
    });

    testWidgets('a spot maps to the plotted sample, skipping dropped ones', (
      tester,
    ) async {
      final reported = <int?>[];
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BuoyancyChart(
              result: _result([
                _s(0, 0, 2),
                _s(60, 10, double.nan),
                _s(120, 12, 0.5),
                _s(180, 5, 1.5),
              ]),
              units: units,
              onCursorSeconds: reported.add,
            ),
          ),
        ),
      );
      // Spot 1 is the 120 s sample: the NaN at 60 s is not plotted.
      touchData(tester).touchCallback!(
        const FlPointerHoverEvent(PointerHoverEvent()),
        touching(barOf(tester), 1),
      );
      expect(reported, [120]);
    });

    testWidgets('the cursor line rests on restSeconds with no cursor', (
      tester,
    ) async {
      await pumpChart(tester, restSeconds: 180);
      expect(verticalLines(tester).single.x, 3.0);
    });

    testWidgets('cursorSeconds wins over restSeconds', (tester) async {
      await pumpChart(tester, cursorSeconds: 60, restSeconds: 180);
      expect(verticalLines(tester).single.x, 1.0);
    });

    testWidgets('the touch tooltip produces no items', (tester) async {
      await pumpChart(tester, onCursorSeconds: (_) {});
      final bar = barOf(tester);
      final items = touchData(
        tester,
      ).touchTooltipData.getTooltipItems([LineBarSpot(bar, 0, bar.spots[1])]);
      expect(items, [null]);
    });

    testWidgets('the y axis title carries the weight unit', (tester) async {
      await pumpChart(
        tester,
        formatter: const UnitFormatter(
          AppSettings(weightUnit: WeightUnit.pounds),
        ),
      );
      expect(find.text('Net (lbs)'), findsOneWidget);
    });

    group('markers', () {
      const markers = [
        BuoyancyChartMarker(seconds: 0, label: 'Start'),
        BuoyancyChartMarker(seconds: 120, label: 'Deepest', optional: true),
        BuoyancyChartMarker(seconds: 180, label: 'Final stop'),
      ];

      testWidgets('each marker adds a dashed line, before the cursor', (
        tester,
      ) async {
        await pumpChart(tester, markers: markers, cursorSeconds: 60);
        final lines = verticalLines(tester);
        expect(lines.map((l) => l.x), [0.0, 2.0, 3.0, 1.0]);
        expect(lines.take(3).every((l) => l.dashArray != null), isTrue);
        expect(lines.last.dashArray, isNull);
      });

      testWidgets('marker lines carry their labels', (tester) async {
        await pumpChart(tester, markers: markers);
        final lines = verticalLines(tester);
        expect(lines[0].label.show, isTrue);
        expect(lines[0].label.labelResolver(lines[0]), 'Start');
        expect(lines[2].label.labelResolver(lines[2]), 'Final stop');
      });

      testWidgets('a dot is drawn at each marker and nowhere else', (
        tester,
      ) async {
        await pumpChart(tester, markers: markers);
        final bar = barOf(tester);
        expect(bar.dotData.show, isTrue);
        final shown = [
          for (final spot in bar.spots) bar.dotData.checkToShowDot(spot, bar),
        ];
        // Samples at 0, 60, 120 and 180 s; markers at 0, 120 and 180.
        expect(shown, [true, false, true, true]);
      });

      testWidgets('no dots without markers', (tester) async {
        await pumpChart(tester);
        expect(barOf(tester).dotData.show, isFalse);
      });

      testWidgets('markers leave headroom above the line for their labels', (
        tester,
      ) async {
        await pumpChart(tester, markers: markers);
        final data = tester.widget<LineChart>(find.byType(LineChart)).data;
        // The data peaks at 2.0 kg.
        expect(data.maxY, greaterThan(2.0));
      });
    });

    testWidgets('without a callback the chart takes no touch callback', (
      tester,
    ) async {
      await pumpChart(tester);
      expect(touchData(tester).touchCallback, isNull);
    });
  });

  testWidgets('the time axis spans every sample, whatever their order', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BuoyancyChart(
            result: _result([_s(120, 5, 1.5), _s(0, 0, 2), _s(60, 10, 1)]),
            units: units,
          ),
        ),
      ),
    );
    final data = tester.widget<LineChart>(find.byType(LineChart)).data;
    expect(data.minX, 0.0);
    expect(data.maxX, 2.0);
  });

  testWidgets('renders nothing for fewer than two samples', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BuoyancyChart(result: _result([_s(0, 0, 2)]), units: units),
        ),
      ),
    );
    expect(find.byType(LineChart), findsNothing);
  });
}

class _ChartHost extends StatelessWidget {
  const _ChartHost();
  @override
  Widget build(BuildContext context) => BuoyancyChart(
    result: _result([_s(0, 0, 2), _s(60, 10, 1), _s(120, 5, 1.5)]),
    units: const UnitFormatter(AppSettings()),
  );
}
