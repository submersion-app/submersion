import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/services/segment_chain.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_edit_controller.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_geometry.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_series_painter.dart';
import 'package:submersion/features/planner/presentation/chart/plan_profile_chart.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
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

/// Issue #3113: dragging a waypoint used to remap the pointer through an axis
/// that rescaled under it, so a small move ran the dive time away. The axes
/// now hold still for the whole drag and refit on release.
void main() {
  Widget harness() => testApp(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    ],
    child: const SizedBox(width: 500, height: 400, child: PlanProfileChart()),
  );

  PlanChartGeometry paintedGeometry(WidgetTester tester) =>
      (tester
                  .widget<CustomPaint>(find.byKey(const Key('planChartSeries')))
                  .painter
              as PlanChartSeriesPainter)
          .geometry;

  Future<
    ({
      ProviderContainer container,
      PlanSegment bottom,
      int bottomIndex,
      Rect rect,
      PlanChartGeometry geometry,
      Offset handle,
    })
  >
  setUpPlan(WidgetTester tester) async {
    await tester.pumpWidget(harness());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanProfileChart)),
    );
    container
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 10);
    await tester.pumpAndSettle();

    final segments = container.read(divePlanNotifierProvider).segments;
    const chain = SegmentChain();
    final legs = chain.resolve(segments);
    final bottom = legs[chain.bottomLegIndex(legs)!].segment;
    final vertices = planVertices(segments);
    final bottomIndex = vertices.indexWhere((v) => v.segmentId == bottom.id);
    final vertex = vertices[bottomIndex];
    final rect = tester.getRect(find.byKey(const Key('planChartOverlay')));
    final geometry = paintedGeometry(tester);
    final handle = geometry.toPixel(vertex.timeSeconds, vertex.depth);
    return (
      container: container,
      bottom: bottom,
      bottomIndex: bottomIndex,
      rect: rect,
      geometry: geometry,
      handle: handle,
    );
  }

  testWidgets('dragging right extends time at a steady scale, then refits', (
    tester,
  ) async {
    final s = await setUpPlan(tester);
    final startMaxTime = s.geometry.maxTimeSeconds;

    final gesture = await tester.startGesture(s.rect.topLeft + s.handle);
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(6, 0));
      await tester.pump();
      expect(paintedGeometry(tester).maxTimeSeconds, startMaxTime);
    }

    final ordered = List<PlanSegment>.from(
      s.container.read(divePlanNotifierProvider).segments,
    )..sort((a, b) => a.order.compareTo(b.order));
    final expected = dragVertex(
      ordered: ordered,
      vertexIndex: s.bottomIndex,
      newDepthMeters: s.geometry.dragDepthAtDy(s.handle.dy),
      newTimeSeconds: s.geometry.dragTimeAtDx(s.handle.dx + 120),
      depthUnitScale: 1,
    ).updates.single.$2;
    final dragged = ordered.firstWhere((x) => x.id == s.bottom.id);
    expect(dragged.durationSeconds, expected.durationSeconds);
    expect(dragged.durationSeconds, greaterThan(s.bottom.durationSeconds));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      paintedGeometry(tester).maxTimeSeconds,
      s.container.read(planCanvasSeriesProvider).maxTimeSeconds,
    );
    expect(paintedGeometry(tester).maxTimeSeconds, greaterThan(startMaxTime));
  });

  testWidgets('dragging down deepens at a steady scale', (tester) async {
    final s = await setUpPlan(tester);
    final startMaxDepth = s.geometry.maxDepthMeters;

    final gesture = await tester.startGesture(s.rect.topLeft + s.handle);
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 6));
      await tester.pump();
      expect(paintedGeometry(tester).maxDepthMeters, startMaxDepth);
    }

    final dragged = s.container
        .read(divePlanNotifierProvider)
        .segments
        .firstWhere((x) => x.id == s.bottom.id);
    final expectedDepth = s.geometry
        .dragDepthAtDy(s.handle.dy + 60)
        .roundToDouble();
    expect(dragged.targetDepth, expectedDepth);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('pointer moves that do not change the snapped waypoint leave '
      'the plan untouched', (tester) async {
    final s = await setUpPlan(tester);
    final gesture = await tester.startGesture(s.rect.topLeft + s.handle);
    await gesture.moveBy(const Offset(1, 0));
    await tester.pump();
    final before = s.container.read(divePlanNotifierProvider);
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(Offset(i.isEven ? -1 : 1, 0));
      await tester.pump();
    }
    expect(
      identical(s.container.read(divePlanNotifierProvider), before),
      isTrue,
    );
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a plan cleared mid-drag does not freeze the next plan', (
    tester,
  ) async {
    final s = await setUpPlan(tester);
    final gesture = await tester.startGesture(s.rect.topLeft + s.handle);
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();

    final notifier = s.container.read(divePlanNotifierProvider.notifier);
    notifier.newPlan();
    await tester.pump();
    notifier.addSimplePlan(maxDepth: 45, bottomTimeMinutes: 30);
    await tester.pump();
    expect(
      paintedGeometry(tester).maxTimeSeconds,
      s.container.read(planCanvasSeriesProvider).maxTimeSeconds,
    );
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('removing a hovered waypoint does not leave a stale index', (
    tester,
  ) async {
    final s = await setUpPlan(tester);
    final segments = List<PlanSegment>.from(
      s.container.read(divePlanNotifierProvider).segments,
    )..sort((a, b) => a.order.compareTo(b.order));
    final last = planVertices(segments).last;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: s.rect.topLeft + const Offset(80, 40));
    await mouse.moveTo(
      s.rect.topLeft + s.geometry.toPixel(last.timeSeconds, last.depth),
    );
    await tester.pump();

    s.container
        .read(divePlanNotifierProvider.notifier)
        .removeSegment(last.segmentId);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await mouse.removePointer();
  });

  testWidgets('a cancelled sequence does not pair with the next tap', (
    tester,
  ) async {
    final s = await setUpPlan(tester);
    final before = s.container.read(divePlanNotifierProvider).segments.length;
    // Empty chart space past the plan, where a double-tap appends.
    final spot = s.rect.topLeft + Offset(s.rect.width - 30, 60);
    await tester.tapAt(spot);
    final cancelled = await tester.startGesture(spot);
    await cancelled.cancel();
    await tester.tapAt(spot);
    await tester.pumpAndSettle();
    expect(s.container.read(divePlanNotifierProvider).segments.length, before);
  });

  testWidgets('a cancelled drag releases the frozen axes', (tester) async {
    final s = await setUpPlan(tester);
    final gesture = await tester.startGesture(s.rect.topLeft + s.handle);
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(
      paintedGeometry(tester).maxTimeSeconds,
      s.container.read(planCanvasSeriesProvider).maxTimeSeconds,
    );
  });
}
