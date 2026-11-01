import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_issue_grouping.dart';
import 'package:submersion/features/planner/domain/services/plan_issue_markers.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_edit_controller.dart';
import 'package:submersion/features/planner/presentation/chart/plan_issue_marker_layer.dart';
import 'package:submersion/features/planner/presentation/chart/plan_profile_chart.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_issue_marker_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/test_app.dart';

/// A warning marker that sits on a waypoint (#3738): hover and click reach
/// the marker, a drag moves the waypoint, and right-click or a long-press
/// opens the waypoint's menu.

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _popup = Key('planChartIssuePopup');
const _removeItem = Key('planWaypointMenu_remove');

void main() {
  late ProviderContainer container;

  /// The waypoint at the foot of the descent.
  PlanVertex waypoint() => planVertices(
    container.read(divePlanNotifierProvider).segments,
  ).firstWhere((v) => v.draggable && v.depth > 0);

  Future<void> seed(WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          planIssueMarkersProvider.overrideWith((ref) {
            final vertex = planVertices(
              ref.watch(divePlanNotifierProvider).segments,
            ).where((v) => v.draggable && v.depth > 0).firstOrNull;
            if (vertex == null) return const [];
            return [
              PlanIssueMarker(
                runtimeSeconds: vertex.timeSeconds.round(),
                groups: const [
                  GroupedPlanIssue(
                    issue: PlanIssue(
                      type: PlanIssueType.endExceeded,
                      severity: PlanIssueSeverity.warning,
                      message: 'END',
                      value: 45,
                      threshold: 30,
                    ),
                    count: 1,
                  ),
                ],
              ),
            ];
          }),
        ],
        child: const SizedBox(
          width: 500,
          height: 400,
          child: PlanProfileChart(),
        ),
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(PlanProfileChart)),
    );
    container
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 45, bottomTimeMinutes: 25);
    await tester.pumpAndSettle();
  }

  PlanIssueMarkerPainter painter(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.byKey(const Key('planChartIssueMarkers')),
              )
              .painter
          as PlanIssueMarkerPainter;

  /// The marker's sign, in global coordinates: in reach of the waypoint
  /// it stands on as well.
  Offset sign(WidgetTester tester) =>
      tester.getTopLeft(find.byType(PlanProfileChart)) +
      painter(tester).placed.single.glyph.center;

  List<PlanSegment> segments() =>
      List.of(container.read(divePlanNotifierProvider).segments);

  Set<PlanIssueKey> picked() => container.read(highlightedPlanIssuesProvider);

  Future<TestGesture> mouse(WidgetTester tester) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    return gesture;
  }

  testWidgets('hovering shows the warnings, locked onto the waypoint', (
    tester,
  ) async {
    await seed(tester);
    final gesture = await mouse(tester);
    await gesture.moveTo(sign(tester));
    await tester.pump();

    expect(find.byKey(_popup), findsOneWidget);
    expect(container.read(scrubTimeProvider), waypoint().timeSeconds);
  });

  testWidgets('a click picks the marker: the ring shows, the sign goes', (
    tester,
  ) async {
    await seed(tester);
    final before = segments();
    final gesture = await mouse(tester);
    await gesture.moveTo(sign(tester));
    await tester.pump();
    final hovered = tester.getRect(find.byKey(_popup));

    await gesture.down(sign(tester));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(picked(), isNotEmpty);
    expect(painter(tester).highlighted.single, isTrue);
    expect(
      tester.renderObject(find.byKey(const Key('planChartIssueMarkers'))),
      paintsExactlyCountTimes(#drawPath, 0),
    );
    expect(tester.getRect(find.byKey(_popup)), hovered);
    expect(segments(), before);
  });

  testWidgets('a mouse drag moves the waypoint, hiding the warnings first', (
    tester,
  ) async {
    await seed(tester);
    final before = segments();
    final gesture = await mouse(tester);
    await gesture.moveTo(sign(tester));
    await tester.pump();
    expect(find.byKey(_popup), findsOneWidget);

    await gesture.down(sign(tester));
    await tester.pump();
    await gesture.moveBy(const Offset(10, 0));
    await tester.pump();
    expect(find.byKey(_popup), findsNothing);
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    expect(find.byKey(_popup), findsNothing);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(segments(), isNot(before));
    expect(picked(), isEmpty);
  });

  testWidgets('a picked marker hides its warnings when its waypoint is '
      'dragged', (tester) async {
    await seed(tester);
    final gesture = await mouse(tester);
    await gesture.down(sign(tester));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(_popup), findsOneWidget);

    await gesture.down(sign(tester));
    await tester.pump();
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(find.byKey(_popup), findsNothing);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a touch drag moves the waypoint without the warnings '
      'flashing up', (tester) async {
    await seed(tester);
    final before = segments();
    final gesture = await tester.startGesture(sign(tester));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.byKey(_popup), findsNothing);
    }
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byKey(_popup), findsNothing);
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byKey(_popup), findsNothing);
    expect(segments(), isNot(before));
    expect(picked(), isEmpty);
  });

  testWidgets('a touch tap picks the marker', (tester) async {
    await seed(tester);
    await tester.tapAt(sign(tester));
    await tester.pumpAndSettle();

    expect(picked(), isNotEmpty);
    expect(find.byKey(_popup), findsOneWidget);
  });

  testWidgets('a long-press opens the waypoint menu, not the marker', (
    tester,
  ) async {
    await seed(tester);
    final gesture = await tester.startGesture(sign(tester));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byKey(_removeItem), findsOneWidget);
    expect(picked(), isEmpty);
  });

  testWidgets('a right-click opens the waypoint menu, not the marker', (
    tester,
  ) async {
    await seed(tester);
    final gesture = await tester.startGesture(
      sign(tester),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byKey(_removeItem), findsOneWidget);
    expect(picked(), isEmpty);
  });
}
