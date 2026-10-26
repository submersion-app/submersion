import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/services/segment_chain.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_edit_controller.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_geometry.dart';
import 'package:submersion/features/planner/presentation/chart/plan_profile_chart.dart';
import 'package:submersion/features/planner/presentation/chart/plan_waypoint_menu.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/test_app.dart';

/// Issue #3564: on a phone there is no right mouse button and no Delete key,
/// so a waypoint added by double-tap could not be removed from the chart.
/// A long-press opens the same waypoint menu right-click does.

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _removeItem = Key('planWaypointMenu_remove');

void main() {
  Widget harness() => testApp(
    // The tests assert the English menu label.
    locale: const Locale('en'),
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    ],
    child: const SizedBox(width: 500, height: 400, child: PlanProfileChart()),
  );

  late ProviderContainer container;

  List<PlanSegment> ordered() =>
      List<PlanSegment>.from(container.read(divePlanNotifierProvider).segments)
        ..sort((a, b) => a.order.compareTo(b.order));

  Future<void> pumpPlan(WidgetTester tester, {bool decoTank = false}) async {
    await tester.pumpWidget(harness());
    container = ProviderScope.containerOf(
      tester.element(find.byType(PlanProfileChart)),
    );
    final notifier = container.read(divePlanNotifierProvider.notifier);
    notifier.addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
    if (decoTank) {
      notifier.addTank(
        const DiveTank(
          id: 'o2',
          volume: 11.1,
          startPressure: 207,
          gasMix: GasMix(o2: 100),
          role: TankRole.deco,
        ),
      );
    }
    await tester.pumpAndSettle();
  }

  PlanSegment bottomSegment() {
    const chain = SegmentChain();
    final legs = chain.resolve(
      container.read(divePlanNotifierProvider).segments,
    );
    return legs[chain.bottomLegIndex(legs)!].segment;
  }

  /// Global position of the handle at the end of [segmentId].
  Offset handleOf(WidgetTester tester, String segmentId) {
    final vertex = planVertices(
      container.read(divePlanNotifierProvider).segments,
    ).firstWhere((v) => v.segmentId == segmentId);
    final rect = tester.getRect(find.byKey(const Key('planChartOverlay')));
    final series = container.read(planCanvasSeriesProvider);
    final geometry = PlanChartGeometry(
      size: rect.size,
      maxTimeSeconds: series.maxTimeSeconds,
      maxDepthMeters: series.maxDepth,
      depthUnitScale: 1,
    );
    return rect.topLeft + geometry.toPixel(vertex.timeSeconds, vertex.depth);
  }

  Future<TestGesture> longPress(WidgetTester tester, Offset at) async {
    final gesture = await tester.startGesture(at);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pumpAndSettle();
    return gesture;
  }

  int totalSeconds() => ordered().fold(0, (sum, s) => sum + s.durationSeconds);

  testWidgets('long-press on a waypoint offers Remove and the gases', (
    tester,
  ) async {
    await pumpPlan(tester, decoTank: true);
    await longPress(tester, handleOf(tester, bottomSegment().id));

    expect(find.byKey(_removeItem), findsOneWidget);
    expect(find.text('Remove waypoint'), findsOneWidget);
    expect(
      find.byType(PopupMenuItem<WaypointMenuAction>),
      findsNWidgets(container.read(divePlanNotifierProvider).tanks.length + 1),
    );
  });

  testWidgets('picking a gas switches the leg after the waypoint', (
    tester,
  ) async {
    await pumpPlan(tester, decoTank: true);
    final before = ordered();
    await longPress(tester, handleOf(tester, before.first.id));
    await tester.tap(find.text('O2').last);
    await tester.pumpAndSettle();

    final after = ordered();
    expect(after[1].tankId, 'o2');
    expect(after[1].gasMix, const GasMix(o2: 100));
    expect(after.first, before.first);
  });

  testWidgets('a gas picked at the last waypoint goes on its own leg', (
    tester,
  ) async {
    await pumpPlan(tester, decoTank: true);
    final last = ordered().last;
    await longPress(tester, handleOf(tester, last.id));
    await tester.tap(find.text('O2').last);
    await tester.pumpAndSettle();

    expect(ordered().last.tankId, 'o2');
  });

  testWidgets('Remove drops the waypoint without moving the others', (
    tester,
  ) async {
    await pumpPlan(tester);
    // The descent's end is a middle waypoint (the quick plan's last one is
    // the bottom leg's end, which has no next leg to absorb its time).
    final before = ordered();
    final descent = before.first;
    final next = before[1];
    final runtime = totalSeconds();
    container.read(selectedSegmentIdProvider.notifier).state = descent.id;

    await longPress(tester, handleOf(tester, descent.id));
    await tester.tap(find.byKey(_removeItem));
    await tester.pumpAndSettle();

    final after = ordered();
    expect(after.any((s) => s.id == descent.id), isFalse);
    final merged = after.firstWhere((s) => s.id == next.id);
    expect(
      merged.durationSeconds,
      next.durationSeconds + descent.durationSeconds,
    );
    expect(totalSeconds(), runtime);
    expect(container.read(selectedSegmentIdProvider), isNull);
  });

  testWidgets('removing a double-tapped waypoint restores the plan', (
    tester,
  ) async {
    await pumpPlan(tester);
    final before = ordered();
    final bottom = bottomSegment();

    // Double-tap halfway along the bottom leg, below the profile line.
    final start = handleOf(tester, before[before.indexOf(bottom) - 1].id);
    final end = handleOf(tester, bottom.id);
    final at = Offset((start.dx + end.dx) / 2, end.dy - 30);
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(at);
    await tester.pumpAndSettle();
    expect(ordered(), hasLength(before.length + 1));

    // The split keeps the bottom leg's id on its first half, whose end is
    // the new waypoint.
    await longPress(tester, handleOf(tester, bottom.id));
    await tester.tap(find.byKey(_removeItem));
    await tester.pumpAndSettle();

    final after = ordered();
    expect(after, hasLength(before.length));
    expect(
      [for (final s in after) (s.targetDepth, s.durationSeconds)],
      [for (final s in before) (s.targetDepth, s.durationSeconds)],
    );
  });

  testWidgets('dragging a waypoint by touch does not open the menu', (
    tester,
  ) async {
    await pumpPlan(tester);
    final bottom = bottomSegment();
    final gesture = await tester.startGesture(handleOf(tester, bottom.id));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump(kLongPressTimeout);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byKey(_removeItem), findsNothing);
    expect(
      ordered().firstWhere((s) => s.id == bottom.id).targetDepth,
      greaterThan(bottom.targetDepth),
    );
  });

  testWidgets('finger jitter during the hold does not edit the waypoint', (
    tester,
  ) async {
    await pumpPlan(tester);
    final descent = ordered().first;
    final gesture = await tester.startGesture(handleOf(tester, descent.id));
    // Jitter inside the slop, across the hold.
    await gesture.moveBy(const Offset(5, 0));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(ordered().first, descent);
    expect(find.byKey(_removeItem), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a mouse held on a waypoint does not open the menu', (
    tester,
  ) async {
    await pumpPlan(tester);
    final gesture = await tester.startGesture(
      handleOf(tester, bottomSegment().id),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(kLongPressTimeout * 2);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byKey(_removeItem), findsNothing);
  });

  testWidgets('a finger gets a larger target than the mouse', (tester) async {
    await pumpPlan(tester);
    // 20 px off the handle: outside the mouse's 16 px, inside touch's 24 px.
    final near = handleOf(tester, ordered().first.id) + const Offset(0, 20);
    await longPress(tester, near);
    expect(find.byKey(_removeItem), findsOneWidget);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      near,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(_removeItem), findsNothing);
  });

  testWidgets('long-press away from a waypoint opens nothing', (tester) async {
    await pumpPlan(tester);
    final rect = tester.getRect(find.byKey(const Key('planChartOverlay')));
    await longPress(tester, rect.center + const Offset(0, 120));

    expect(find.byKey(_removeItem), findsNothing);
  });

  testWidgets('right-click offers Remove too', (tester) async {
    await pumpPlan(tester);
    final descent = ordered().first;
    final runtime = totalSeconds();
    final gesture = await tester.startGesture(
      handleOf(tester, descent.id),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_removeItem));
    await tester.pumpAndSettle();
    expect(ordered().any((s) => s.id == descent.id), isFalse);
    expect(totalSeconds(), runtime);
  });

  testWidgets('right-clicks off a waypoint are not taps', (tester) async {
    await pumpPlan(tester);
    final before = ordered();
    final rect = tester.getRect(find.byKey(const Key('planChartOverlay')));
    // Well below the profile, so no handle is hit and no menu opens.
    final at = rect.center + const Offset(0, 120);
    for (var i = 0; i < 2; i++) {
      final gesture = await tester.startGesture(
        at,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    // Two quick taps there would select a leg and split it.
    expect(ordered(), before);
    expect(container.read(selectedSegmentIdProvider), isNull);
  });

  testWidgets('the Delete key removes the same way', (tester) async {
    await pumpPlan(tester);
    final descent = ordered().first;
    final runtime = totalSeconds();
    container.read(selectedSegmentIdProvider.notifier).state = descent.id;
    tester
        .widget<Focus>(
          find
              .descendant(
                of: find.byType(PlanProfileChart),
                matching: find.byType(Focus),
              )
              .first,
        )
        .focusNode!
        .requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(ordered().any((s) => s.id == descent.id), isFalse);
    expect(totalSeconds(), runtime);
  });
}
