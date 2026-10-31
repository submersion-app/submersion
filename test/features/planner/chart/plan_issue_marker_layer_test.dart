import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_issue_grouping.dart';
import 'package:submersion/features/planner/domain/services/plan_issue_markers.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_geometry.dart';
import 'package:submersion/features/planner/presentation/chart/plan_issue_marker_layer.dart';
import 'package:submersion/features/planner/presentation/chart/plan_profile_chart.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_issue_marker_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_results_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PlanIssueMarker _marker(int at, PlanIssueType type, PlanIssueSeverity sev) =>
    PlanIssueMarker(
      runtimeSeconds: at,
      groups: [
        GroupedPlanIssue(
          issue: PlanIssue(type: type, severity: sev, message: '$type'),
          count: 1,
        ),
      ],
    );

const _geometry = PlanChartGeometry(
  size: Size(500, 400),
  maxTimeSeconds: 1800,
  maxDepthMeters: 40,
  depthUnitScale: 1,
);

double _profile(double t) => t < 120 ? t / 3 : 40;

void main() {
  group('placeIssueMarkers', () {
    test('the sign sits just above the line, clear of it', () {
      final placed = placeIssueMarkers(
        markers: [
          _marker(600, PlanIssueType.endExceeded, PlanIssueSeverity.warning),
        ],
        geometry: _geometry,
        depthAt: _profile,
      ).single;
      expect(placed.anchor, _geometry.toPixel(600, 40));
      expect(placed.depthMeters, 40);
      expect(placed.glyph.bottom, lessThan(placed.anchor.dy));
      expect(placed.glyph.center.dx, closeTo(placed.anchor.dx, 0.01));
    });

    test('at the surface the sign flips below the line', () {
      final placed = placeIssueMarkers(
        markers: [
          _marker(0, PlanIssueType.cnsWarning, PlanIssueSeverity.warning),
        ],
        geometry: _geometry,
        depthAt: _profile,
      ).single;
      expect(placed.glyph.top, greaterThan(placed.anchor.dy));
      expect(placed.glyph.left, greaterThanOrEqualTo(_geometry.plotRect.left));
    });

    test('a picked marker stays exactly where it sits unpicked', () {
      final marker = _marker(
        600,
        PlanIssueType.endExceeded,
        PlanIssueSeverity.warning,
      );
      PlacedIssueMarker place({required bool picked}) => placeIssueMarkers(
        markers: [marker],
        geometry: _geometry,
        depthAt: _profile,
        highlighted: picked ? marker.keys : const {},
      ).single;

      final picked = place(picked: true);
      final unpicked = place(picked: false);
      expect(picked.highlighted, isTrue);
      expect(unpicked.highlighted, isFalse);
      expect(picked.glyph, unpicked.glyph);
    });

    test('markers a few pixels apart share one, worst first', () {
      final placed = placeIssueMarkers(
        markers: [
          _marker(600, PlanIssueType.endExceeded, PlanIssueSeverity.warning),
          _marker(610, PlanIssueType.gasOut, PlanIssueSeverity.critical),
          _marker(1500, PlanIssueType.otuHigh, PlanIssueSeverity.warning),
        ],
        geometry: _geometry,
        depthAt: _profile,
      );
      expect(placed, hasLength(2));
      expect(placed.first.marker.severity, PlanIssueSeverity.critical);
      expect(placed.first.marker.runtimeSeconds, 600);
      expect(placed.first.marker.groups, hasLength(2));
    });

    test('hit-testing finds the nearest sign within reach', () {
      final placed = placeIssueMarkers(
        markers: [
          _marker(600, PlanIssueType.endExceeded, PlanIssueSeverity.warning),
          _marker(1500, PlanIssueType.otuHigh, PlanIssueSeverity.warning),
        ],
        geometry: _geometry,
        depthAt: _profile,
      );
      final second = placed[1].glyph.center;
      expect(hitTestIssueMarker(placed, second + const Offset(5, 5)), 1);
      expect(hitTestIssueMarker(placed, second + const Offset(30, 0)), isNull);
      expect(
        hitTestIssueMarker(placed, second + const Offset(20, 0), radius: 24),
        1,
      );
    });
  });

  group('issueMarkerTarget', () {
    const chart = Size(500, 400);

    test('is a 48 px square centred on the sign', () {
      const glyph = Rect.fromLTWH(200, 200, 14, 12);
      final target = issueMarkerTarget(glyph, chart);
      expect(target.size, const Size(48, 48));
      expect(target.center, glyph.center);
    });

    test('stays whole beside the edge of the chart', () {
      // A marker at the surface sits right under the top of the plot, where
      // the box would otherwise reach past the chart and be clipped.
      const surface = Rect.fromLTWH(200, 17, 14, 12);
      final target = issueMarkerTarget(surface, chart);
      expect(target.size, const Size(48, 48));
      expect(target.top, 0);

      const atTheEnd = Rect.fromLTWH(474, 390, 14, 12);
      final corner = issueMarkerTarget(atTheEnd, chart);
      expect(corner.size, const Size(48, 48));
      expect(corner.right, chart.width);
      expect(corner.bottom, chart.height);
    });
  });

  group('on the chart', () {
    Widget harness({List<Override> overrides = const []}) => testApp(
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ...overrides,
      ],
      child: const SizedBox(width: 500, height: 400, child: PlanProfileChart()),
    );

    PlanIssueMarkerPainter markerPainter(WidgetTester tester) =>
        tester
                .widget<CustomPaint>(
                  find.byKey(const Key('planChartIssueMarkers')),
                )
                .painter
            as PlanIssueMarkerPainter;

    Future<ProviderContainer> seed(
      WidgetTester tester, {
      double depth = 45,
      List<Override> overrides = const [],
    }) async {
      await tester.pumpWidget(harness(overrides: overrides));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanProfileChart)),
      );
      container
          .read(divePlanNotifierProvider.notifier)
          .addSimplePlan(maxDepth: depth, bottomTimeMinutes: 25);
      await tester.pumpAndSettle();
      return container;
    }

    Offset markerAt(WidgetTester tester, int index) {
      final origin = tester.getTopLeft(find.byType(PlanProfileChart));
      return origin + markerPainter(tester).placed[index].glyph.center;
    }

    testWidgets('a screen reader gets the same 48 px target as a fingertip', (
      tester,
    ) async {
      await seed(tester);
      final targets = find.descendant(
        of: find.byType(PlanIssueMarkerLayer),
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.onTap != null,
        ),
      );
      expect(targets, findsWidgets);
      for (final target in targets.evaluate()) {
        expect(target.size!.width, moreOrLessEquals(48));
        expect(target.size!.height, moreOrLessEquals(48));
      }
    });

    testWidgets('a plan with warnings shows them on the profile', (
      tester,
    ) async {
      final container = await seed(tester);
      final markers = container.read(planIssueMarkersProvider);
      expect(markers, isNotEmpty);
      expect(markerPainter(tester).placed, isNotEmpty);
      expect(find.byKey(const Key('planChartIssuePopup')), findsNothing);
    });

    testWidgets('tapping a marker shows its warnings and picks them out', (
      tester,
    ) async {
      final container = await seed(tester);
      final selectedBefore = container.read(selectedSegmentIdProvider);
      final placed = markerPainter(tester).placed.first;

      await tester.tapAt(markerAt(tester, 0));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('planChartIssuePopup')), findsOneWidget);
      expect(container.read(highlightedPlanIssuesProvider), placed.marker.keys);
      expect(markerPainter(tester).highlighted.first, isTrue);
      // The ring is centred on the point the warnings start at.
      final anchor = markerPainter(tester).placed.first.anchor;
      expect(
        tester.renderObject(find.byKey(const Key('planChartIssueMarkers'))),
        paints..something((method, arguments) {
          if (method != #drawCircle) return false;
          final paint = arguments[2] as Paint;
          return arguments[0] == anchor &&
              arguments[1] == issueMarkerRingRadius &&
              paint.style == PaintingStyle.stroke &&
              paint.strokeWidth == 2;
        }),
      );
      // Its sign gives way to the ring: only the other markers draw one,
      // each a fill and an outline.
      expect(
        tester.renderObject(find.byKey(const Key('planChartIssueMarkers'))),
        paintsExactlyCountTimes(
          #drawPath,
          2 * (markerPainter(tester).placed.length - 1),
        ),
      );
      // A marker tap is not a segment tap.
      expect(container.read(selectedSegmentIdProvider), selectedBefore);

      // Tapping it again lets go.
      await tester.tapAt(markerAt(tester, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('planChartIssuePopup')), findsNothing);
      expect(container.read(highlightedPlanIssuesProvider), isEmpty);
    });

    testWidgets('tapping elsewhere on the chart lets go of a marker', (
      tester,
    ) async {
      final container = await seed(tester);
      await tester.tapAt(markerAt(tester, 0));
      await tester.pumpAndSettle();
      expect(container.read(highlightedPlanIssuesProvider), isNotEmpty);

      final rect = tester.getRect(find.byType(PlanProfileChart));
      await tester.tapAt(rect.bottomRight - const Offset(30, 40));
      await tester.pumpAndSettle();
      expect(container.read(highlightedPlanIssuesProvider), isEmpty);
    });

    testWidgets('hovering a marker shows its warnings instead of scrubbing', (
      tester,
    ) async {
      final container = await seed(tester);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(markerAt(tester, 0));
      await tester.pump();

      expect(find.byKey(const Key('planChartIssuePopup')), findsOneWidget);
      expect(container.read(scrubTimeProvider), isNull);

      await gesture.moveTo(const Offset(700, 500));
      await tester.pump();
      expect(find.byKey(const Key('planChartIssuePopup')), findsNothing);
    });

    testWidgets('the popup stays put from hover to click', (tester) async {
      await seed(tester);
      final popup = find.byKey(const Key('planChartIssuePopup'));
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(markerAt(tester, 0));
      await tester.pump();
      final hovered = tester.getRect(popup);

      await gesture.down(markerAt(tester, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(markerPainter(tester).highlighted.first, isTrue);
      expect(tester.getRect(popup), hovered);
    });

    testWidgets('the popup leaves room for the ring', (tester) async {
      // A marker mid-chart with a wide popup, too wide to fit on either side
      // of it on a 500 px chart.
      await seed(
        tester,
        overrides: [
          planIssueMarkersProvider.overrideWith(
            (ref) => [
              PlanIssueMarker(
                runtimeSeconds:
                    ref.watch(activePlanOutcomeProvider).runtimeSeconds ~/ 2,
                groups: const [
                  GroupedPlanIssue(
                    issue: PlanIssue(
                      type: PlanIssueType.ndlExceededNoDecoGas,
                      severity: PlanIssueSeverity.alert,
                      message: 'no deco gas',
                    ),
                    count: 1,
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      final placed = markerPainter(tester).placed.single;
      final origin = tester.getTopLeft(find.byType(PlanProfileChart));
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(origin + placed.glyph.center);
      await tester.pump();

      final popup = tester.getRect(
        find.byKey(const Key('planChartIssuePopup')),
      );
      final ring = Rect.fromCircle(
        center: origin + placed.anchor,
        radius: issueMarkerRingRadius + 1,
      );
      expect(popup.overlaps(ring), isFalse);
      expect(popup.overlaps(placed.glyph.shift(origin)), isFalse);
    });

    testWidgets('a marker on a deco stop shows its warnings, locked onto '
        'the stop', (tester) async {
      // A marker where the ascent reaches the first deco stop, a corner of
      // the profile with no waypoint of its own.
      int firstStop(Ref ref) => ref
          .watch(activePlanOutcomeProvider)
          .stops
          .first
          .arrivalRuntimeSeconds;
      final container = await seed(
        tester,
        overrides: [
          planIssueMarkersProvider.overrideWith(
            (ref) => [
              _marker(
                firstStop(ref),
                PlanIssueType.endExceeded,
                PlanIssueSeverity.warning,
              ),
            ],
          ),
        ],
      );
      final arrival = container
          .read(activePlanOutcomeProvider)
          .stops
          .first
          .arrivalRuntimeSeconds;
      final glyph = markerPainter(tester).placed.single.glyph;
      final origin = tester.getTopLeft(find.byType(PlanProfileChart));
      // Halfway between the sign and the stop it stands on, in reach of both.
      final stop = Offset(glyph.center.dx, glyph.bottom + 5);
      final between = origin + Offset.lerp(glyph.center, stop, 0.5)!;

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(between);
      await tester.pump();

      expect(container.read(scrubTimeProvider), arrival);
      expect(find.byKey(const Key('planChartIssuePopup')), findsOneWidget);
    });

    testWidgets('a row picked in the list shows on its marker', (tester) async {
      final container = await seed(tester);
      final marker = container.read(planIssueMarkersProvider).first;
      container.read(highlightedPlanIssuesProvider.notifier).state = {
        marker.keys.first,
      };
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('planChartIssuePopup')), findsOneWidget);
      expect(markerPainter(tester).highlighted, contains(true));
    });

    testWidgets('a warning edited away takes its marker with it', (
      tester,
    ) async {
      final container = await seed(tester);
      expect(container.read(planIssueMarkersProvider), isNotEmpty);

      final notifier = container.read(divePlanNotifierProvider.notifier);
      notifier.addSimplePlan(maxDepth: 12, bottomTimeMinutes: 20);
      await tester.pumpAndSettle();
      expect(container.read(planIssueMarkersProvider), isEmpty);
      expect(markerPainter(tester).placed, isEmpty);
    });
  });

  group('in the warnings list', () {
    const issue = PlanIssue(
      type: PlanIssueType.endExceeded,
      severity: PlanIssueSeverity.warning,
      message: 'END',
      atRuntime: 90,
      value: 36,
      threshold: 30,
    );
    const listOnly = PlanIssue(
      type: PlanIssueType.ndlExceededNoDecoGas,
      severity: PlanIssueSeverity.alert,
      message: 'no deco gas',
    );
    const outcome = PlanOutcome(
      runtimeSeconds: 1620,
      maxDepth: 36,
      ndlAtBottom: 600,
      ttsAtBottom: 120,
      stops: [],
      segmentOutcomes: [],
      tankUsages: [],
      cnsEnd: 5,
      otuTotal: 10,
      issues: [listOnly, issue],
      endTissue: BuhlmannState(compartments: []),
      surfacedTissue: BuhlmannState(compartments: []),
      tissueTimeline: [],
      ceilingTrace: [],
    );

    Widget harness() => testApp(
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        activePlanOutcomeProvider.overrideWithValue(outcome),
      ],
      child: SizedBox(
        width: 500,
        height: 900,
        child: PlanResultsSheet(controller: ScrollController()),
      ),
    );

    testWidgets('tapping a row with a marker picks it out', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanResultsSheet)),
      );
      final row = find.byKey(
        const ValueKey('planIssueRow-endExceeded-warning'),
      );
      await tester.scrollUntilVisible(
        row,
        200,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(container.read(highlightedPlanIssuesProvider), {
        (PlanIssueType.endExceeded, PlanIssueSeverity.warning),
      });

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(container.read(highlightedPlanIssuesProvider), isEmpty);
    });

    testWidgets('a row with no moment is not tappable', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('planIssueRow-ndlExceededNoDecoGas-alert')),
        findsNothing,
      );
    });
  });
}
