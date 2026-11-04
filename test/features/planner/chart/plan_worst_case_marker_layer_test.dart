import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/services/plan_issue_markers.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_geometry.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_palette.dart';
import 'package:submersion/features/planner/presentation/chart/plan_issue_marker_layer.dart';
import 'package:submersion/features/planner/presentation/chart/plan_worst_case_marker_layer.dart';
import 'package:submersion/features/planner/presentation/providers/plan_worst_case_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/test_app.dart';

const _geometry = PlanChartGeometry(
  size: Size(500, 400),
  maxTimeSeconds: 1800,
  maxDepthMeters: 40,
  depthUnitScale: 1,
);

const _pillSize = Size(70, 17);

double _profile(double t) => t < 120 ? t / 3 : 40;

PlanChartWorstCase _worstCase({
  int runtimeSeconds = 600,
  double depthMeters = 40,
  bool sufficient = true,
  bool stale = false,
}) => PlanChartWorstCase(
  runtimeSeconds: runtimeSeconds,
  depthMeters: depthMeters,
  ttsSeconds: 840,
  litersRequired: 1500,
  availableLiters: 2000,
  sufficient: sufficient,
  stale: stale,
);

PlacedWorstCaseMarker _place(
  PlanChartWorstCase worstCase, {
  double Function(double)? depthAt,
}) => placeWorstCaseMarker(
  worstCase: worstCase,
  geometry: _geometry,
  depthAt: depthAt ?? _profile,
  pillSize: _pillSize,
)!;

void main() {
  group('placeWorstCaseMarker', () {
    test('the anchor is on the drawn line at the worst-case runtime', () {
      final placed = _place(_worstCase());
      expect(placed.anchor, _geometry.toPixel(600, 40));
    });

    test('the pill sits above and left of the line, clear of a warning '
        'sign at the same point', () {
      final placed = _place(_worstCase());
      expect(placed.pill.size, _pillSize);
      expect(
        placed.pill.right,
        closeTo(placed.anchor.dx - worstCasePillInset, 0.01),
      );
      expect(
        placed.pill.bottom,
        closeTo(placed.anchor.dy - worstCasePillGap, 0.01),
      );
      expect(placed.above, isTrue);
      // The leader runs on a slant from the diamond up to the pill.
      expect(placed.stemEnd, placed.pill.bottomRight);
      expect(placed.stemStart.dx, lessThan(placed.anchor.dx));
      expect(placed.stemStart.dy, lessThan(placed.anchor.dy));
    });

    test('next to the gas flag row the pill flips below the line', () {
      final placed = _place(_worstCase(), depthAt: (_) => 1);
      expect(placed.above, isFalse);
      expect(
        placed.pill.top,
        closeTo(placed.anchor.dy + worstCasePillGap, 0.01),
      );
      expect(placed.stemEnd, placed.pill.topRight);
      expect(placed.stemStart.dy, greaterThan(placed.anchor.dy));
    });

    test('a worst case past the end of the plot is not placed', () {
      // A stale result for a longer plan, or axes frozen for a drag.
      expect(
        placeWorstCaseMarker(
          worstCase: _worstCase(runtimeSeconds: 7200),
          geometry: _geometry,
          depthAt: _profile,
          pillSize: _pillSize,
        ),
        isNull,
      );
    });

    test('on a plot too short for the gap the pill stays inside it', () {
      const short = PlanChartGeometry(
        size: Size(500, 90),
        maxTimeSeconds: 1800,
        maxDepthMeters: 40,
        depthUnitScale: 1,
      );
      final placed = placeWorstCaseMarker(
        worstCase: _worstCase(),
        geometry: short,
        // Mid-plot: no room above for the gap, nor below for the full gap.
        depthAt: (_) => 20,
        pillSize: _pillSize,
      )!;
      expect(placed.above, isFalse);
      expect(placed.pill.bottom, lessThanOrEqualTo(short.plotRect.bottom));
      expect(placed.pill.top, greaterThanOrEqualTo(short.plotRect.top));
    });

    test('an early worst case keeps the pill inside the plot', () {
      final placed = _place(_worstCase(runtimeSeconds: 30));
      expect(placed.pill.left, _geometry.plotRect.left);
      expect(placed.pill.right, greaterThanOrEqualTo(placed.anchor.dx));
    });
  });

  group('worstCasePillDistance', () {
    final placed = _place(_worstCase());

    test('is zero on the pill', () {
      expect(worstCasePillDistance(placed, placed.pill.center), 0);
    });

    test('measures from the nearest edge within the radius', () {
      final beside = placed.pill.centerLeft - const Offset(3, 0);
      expect(worstCasePillDistance(placed, beside), closeTo(3, 0.01));
    });

    test('is null out of reach', () {
      final far = placed.pill.centerLeft - const Offset(30, 0);
      expect(worstCasePillDistance(placed, far), isNull);
      expect(worstCasePillDistance(placed, far, radius: 40), closeTo(30, 0.01));
    });
  });

  group('pointerOnWorstCase', () {
    final placed = _place(_worstCase());

    PlacedIssueMarker signAt(Offset center) => PlacedIssueMarker(
      marker: const PlanIssueMarker(runtimeSeconds: 600, groups: []),
      depthMeters: 40,
      anchor: center + const Offset(0, 11),
      glyph: Rect.fromCenter(center: center, width: 14, height: 12),
    );

    bool on(Offset position, List<PlacedIssueMarker> signs) =>
        pointerOnWorstCase(
          placed,
          signs,
          position,
          pillRadius: 16,
          signRadius: 24,
        );

    test('no marker, nothing to be on', () {
      expect(
        pointerOnWorstCase(
          null,
          const [],
          Offset.zero,
          pillRadius: 16,
          signRadius: 24,
        ),
        isFalse,
      );
    });

    test('on the pill with no sign about', () {
      expect(on(placed.pill.center, const []), isTrue);
    });

    test('a sign in reach that is closer takes the pointer', () {
      final below = placed.pill.bottomCenter + const Offset(0, 14);
      final sign = signAt(below + const Offset(0, 2));
      expect(on(below, [sign]), isFalse);
    });

    test('the pill keeps the pointer over a sign that is in reach but '
        'farther away', () {
      final sign = signAt(placed.pill.bottomCenter + const Offset(0, 16));
      expect(on(placed.pill.center, [sign]), isTrue);
    });
  });

  group('worstCaseTarget', () {
    const chart = Size(500, 400);

    test('covers the pill and is never smaller than 48 px', () {
      final placed = _place(_worstCase());
      final target = worstCaseTarget(placed.pill, chart);
      expect(target.width, greaterThanOrEqualTo(48));
      expect(target.height, 48);
      expect(target.center, placed.pill.center);
      expect(target.left, lessThanOrEqualTo(placed.pill.left));
      expect(target.top, lessThanOrEqualTo(placed.pill.top));
      expect(target.right, greaterThanOrEqualTo(placed.pill.right));
      expect(target.bottom, greaterThanOrEqualTo(placed.pill.bottom));
    });

    test('stays inside the chart', () {
      const corner = Rect.fromLTWH(0, 0, 70, 17);
      final target = worstCaseTarget(corner, chart);
      expect(target.left, 0);
      expect(target.top, 0);
    });
  });

  group('PlanWorstCaseMarkerLayer', () {
    Future<int> pumpLayer(
      WidgetTester tester, {
      required PlanChartWorstCase worstCase,
      bool active = false,
    }) async {
      var activations = 0;
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          child: Builder(
            builder: (context) => SizedBox(
              width: 500,
              height: 400,
              child: PlanWorstCaseMarkerLayer(
                placed: _place(worstCase),
                label: 'Worst case',
                active: active,
                palette: PlanChartPalette.of(Theme.of(context)),
                units: const UnitFormatter(AppSettings()),
                labelStyle: const TextStyle(fontSize: 9),
                onActivate: () => activations++,
              ),
            ),
          ),
        ),
      );
      return activations;
    }

    testWidgets('shows no card until active', (tester) async {
      await pumpLayer(tester, worstCase: _worstCase());
      expect(find.byKey(const Key('planChartWorstCaseMarker')), findsOneWidget);
      expect(find.byKey(const Key('planChartWorstCaseCard')), findsNothing);
    });

    testWidgets('an active card reads the worst case and its gas', (
      tester,
    ) async {
      await pumpLayer(tester, worstCase: _worstCase(), active: true);
      expect(find.byKey(const Key('planChartWorstCaseCard')), findsOneWidget);
      expect(find.textContaining('Worst case at 10′'), findsOneWidget);
      expect(find.text('Bailout TTS 14′'), findsOneWidget);
      expect(find.textContaining('Required'), findsOneWidget);
      expect(find.textContaining('Available'), findsOneWidget);
      expect(
        find.text('Bailout gas insufficient for the worst case'),
        findsNothing,
      );
    });

    testWidgets('a short bailout says so on the card', (tester) async {
      await pumpLayer(
        tester,
        worstCase: _worstCase(sufficient: false),
        active: true,
      );
      expect(
        find.text('Bailout gas insufficient for the worst case'),
        findsOneWidget,
      );
    });

    testWidgets('the colour follows whether the bailout gas suffices', (
      tester,
    ) async {
      PlanWorstCaseMarkerPainter painter() =>
          tester
                  .widget<CustomPaint>(
                    find.byKey(const Key('planChartWorstCaseMarker')),
                  )
                  .painter
              as PlanWorstCaseMarkerPainter;

      await pumpLayer(tester, worstCase: _worstCase());
      final scheme = Theme.of(
        tester.element(find.byType(PlanWorstCaseMarkerLayer)),
      ).colorScheme;
      expect(painter().color, scheme.secondary);

      await pumpLayer(tester, worstCase: _worstCase(sufficient: false));
      expect(painter().color, scheme.error);
    });

    testWidgets('a stale worst case is drawn dimmed', (tester) async {
      PlanWorstCaseMarkerPainter painter() =>
          tester
                  .widget<CustomPaint>(
                    find.byKey(const Key('planChartWorstCaseMarker')),
                  )
                  .painter
              as PlanWorstCaseMarkerPainter;

      await pumpLayer(tester, worstCase: _worstCase());
      expect(painter().opacity, 1);

      await pumpLayer(tester, worstCase: _worstCase(stale: true));
      expect(painter().opacity, 0.5);
    });

    testWidgets('a screen reader reads the card and can open it', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var activations = 0;
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          child: Builder(
            builder: (context) => SizedBox(
              width: 500,
              height: 400,
              child: PlanWorstCaseMarkerLayer(
                placed: _place(_worstCase()),
                label: 'Worst case',
                active: false,
                palette: PlanChartPalette.of(Theme.of(context)),
                units: const UnitFormatter(AppSettings()),
                labelStyle: const TextStyle(fontSize: 9),
                onActivate: () => activations++,
              ),
            ),
          ),
        ),
      );

      const units = UnitFormatter(AppSettings());
      final target = find.byKey(const Key('planChartWorstCaseTarget'));
      expect(
        tester.getSemantics(target),
        isSemantics(
          isButton: true,
          hasTapAction: true,
          label:
              'Worst case at 10′ · ${units.formatDepth(40, decimals: 0)}\n'
              'Bailout TTS 14′\n'
              'Required ${units.formatVolume(1500)}\n'
              'Available ${units.formatVolume(2000)}',
        ),
      );
      tester.widget<Semantics>(target).properties.onTap!();
      expect(activations, 1);
      handle.dispose();
    });
  });
}
