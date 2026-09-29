import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_number_field.dart';
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/entities/mission/shore_exit.dart';
import 'package:submersion/features/planner/presentation/panes/plan_editor_pane.dart';
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

Widget _harness({Locale locale = const Locale('en')}) => testApp(
  overrides: [settingsProvider.overrideWith((ref) => _TestSettingsNotifier())],
  locale: locale,
  child: const PlanEditorPane(),
);

/// Adds a leg through the editor the Add button opens.
Future<void> _addLeg(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Add leg'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

/// A route the team can travel: [legs] with one 0.9 m/s scooter.
DpvMission _travelable(DpvMission mission, List<MissionLeg> legs) =>
    mission.copyWith(
      legs: legs,
      team: [
        mission.team.single.copyWith(
          scooter: const ScooterSpec(
            name: 'S',
            ratedSpeedMps: 0.9,
            burnTimeSeconds: 5400,
          ),
        ),
      ],
    );

Future<ProviderContainer> _openRoute(
  WidgetTester tester,
  List<MissionLeg> legs, {
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_harness(locale: locale));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(SwitchListTile));
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(PlanEditorPane)),
  );
  final notifier = container.read(divePlanNotifierProvider.notifier);
  notifier.updateMission(
    _travelable(container.read(divePlanNotifierProvider).mission!, legs),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('turning the mission on swaps the segments for the route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('Route'), findsNothing);
    await tester.tap(find.text('Plan as DPV mission'));
    await tester.pumpAndSettle();

    expect(find.text('Route'), findsOneWidget);
    expect(find.text('Leg 1'), findsOneWidget);
    // The starter is incomplete: the strip names why there is no profile.
    expect(find.textContaining('No profile yet'), findsOneWidget);
  });

  testWidgets('turning it off asks first and keeps the segments', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan as DPV mission'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Plan as DPV mission'));
    await tester.pumpAndSettle();
    expect(find.text('Turn off the DPV mission?'), findsOneWidget);
    await tester.tap(find.text('Turn off'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanEditorPane)),
    );
    expect(container.read(divePlanNotifierProvider).mission, isNull);
    expect(find.text('Route'), findsNothing);
  });

  testWidgets('adding a leg adds a row', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan as DPV mission'));
    await tester.pumpAndSettle();
    // Adding opens the editor first; cancelling adds nothing.
    await tester.tap(find.byTooltip('Add leg'));
    await tester.pumpAndSettle();
    expect(find.text('Edit leg'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Leg 2'), findsNothing);
    await tester.tap(find.byTooltip('Add leg'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(PlanNumberField, 'Distance'),
        matching: find.byType(TextField),
      ),
      '200',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Leg 2'), findsOneWidget);
  });

  testWidgets('the route card fits a 320 pt phone', (tester) async {
    tester.view.physicalSize = const Size(320, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan as DPV mission'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a leg row reads distance, depth, current and exit in order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan as DPV mission'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanEditorPane)),
    );
    final notifier = container.read(divePlanNotifierProvider.notifier);
    final mission = container.read(divePlanNotifierProvider).mission!;
    notifier.updateMission(
      mission.copyWith(
        legs: const [
          MissionLeg(
            id: 'L1',
            order: 0,
            label: 'Wall',
            distanceM: 600,
            depthM: 18,
            headingDeg: 90,
            current: CurrentVector(speedMps: 0.15, setsTowardDeg: 225),
            shoreExit: ShoreExit(surfaceSwimM: 120, walkM: 40),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('600m at 18m, heading 90°'), findsOneWidget);
    expect(find.textContaining('Current 9 m/min toward 225°'), findsOneWidget);
    expect(
      find.textContaining('Shore exit: swim 120m, walk 40m'),
      findsOneWidget,
    );
  });

  testWidgets('a first leg the current blocks says why there is no profile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan as DPV mission'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanEditorPane)),
    );
    final mission = container.read(divePlanNotifierProvider).mission!;
    container
        .read(divePlanNotifierProvider.notifier)
        .updateMission(
          mission.copyWith(
            legs: const [
              MissionLeg(
                id: 'L1',
                order: 0,
                label: 'Wall',
                distanceM: 300,
                depthM: 20,
                headingDeg: 0,
                // 0.6 m/s setting south against 0.5 m/s scooters heading north.
                current: CurrentVector(speedMps: 0.6, setsTowardDeg: 180),
              ),
            ],
            team: [
              mission.team.single.copyWith(
                scooter: const ScooterSpec(
                  name: 'S',
                  ratedSpeedMps: 0.5,
                  burnTimeSeconds: 7200,
                ),
              ),
            ],
          ),
        );
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).segments, isEmpty);
    expect(
      find.textContaining('No profile yet: The current blocks Wall'),
      findsOneWidget,
    );
  });

  testWidgets('on desktop the delete button is not under a drag handle', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan as DPV mission'));
    await tester.pumpAndSettle();
    await _addLeg(tester);
    expect(find.text('Leg 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete leg').last);
    await tester.pumpAndSettle();
    expect(find.text('Leg 2'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('dragging a leg by its handle reorders the route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan as DPV mission'));
    await tester.pumpAndSettle();
    await _addLeg(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanEditorPane)),
    );
    final first = container.read(divePlanNotifierProvider).mission!.legs.first;

    final handle = find.byIcon(Icons.drag_handle).first;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(kLongPressTimeout);
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();

    final legs = container.read(divePlanNotifierProvider).mission!.legs;
    expect(legs.last.id, first.id);
    expect([for (final l in legs) l.order], [0, 1]);
  });

  testWidgets('turning it on over hand-built segments asks first', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanEditorPane)),
    );
    container
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
    await tester.pumpAndSettle();
    final handBuilt = container.read(divePlanNotifierProvider).segments;

    await tester.tap(find.text('Plan as DPV mission'));
    await tester.pumpAndSettle();
    expect(
      find.text('Replace the segments with a DPV mission?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).mission, isNull);
    expect(container.read(divePlanNotifierProvider).segments, handBuilt);

    await tester.tap(find.text('Plan as DPV mission'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).mission, isNotNull);
  });

  testWidgets('tapping a leg edits it, and the profile lists its segments', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan as DPV mission'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanEditorPane)),
    );
    final mission = container.read(divePlanNotifierProvider).mission!;
    container
        .read(divePlanNotifierProvider.notifier)
        .updateMission(
          mission.copyWith(
            legs: [
              mission.legs.single.copyWith(
                label: 'Wall',
                distanceM: 300,
                depthM: 20,
              ),
            ],
            team: [
              mission.team.single.copyWith(
                scooter: const ScooterSpec(
                  name: 'S',
                  ratedSpeedMps: 0.9,
                  burnTimeSeconds: 5400,
                ),
              ),
            ],
          ),
        );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Wall'));
    await tester.pumpAndSettle();
    expect(find.text('Edit leg'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(PlanNumberField, 'Distance'),
        matching: find.byType(TextField),
      ),
      '450',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      container.read(divePlanNotifierProvider).mission!.legs.single.distanceM,
      450,
    );

    await tester.tap(find.text('Generated profile'));
    await tester.pumpAndSettle();
    final segments = container.read(divePlanNotifierProvider).segments;
    expect(find.textContaining(' min'), findsNWidgets(segments.length));
  });

  const wall = MissionLeg(
    id: 'L1',
    order: 0,
    label: 'Wall',
    distanceM: 300,
    depthM: 20,
    headingDeg: 0,
  );

  testWidgets('a plan-level issue is a note under a working profile', (
    tester,
  ) async {
    final container = await _openRoute(tester, const [wall]);
    container
        .read(divePlanNotifierProvider.notifier)
        .updateMode(domain.PlanMode.ccr);
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).segments, isNotEmpty);
    expect(find.textContaining('No profile yet'), findsNothing);
    expect(
      find.text('DPV missions plan open circuit dives only'),
      findsOneWidget,
    );
    expect(find.text('Generated profile'), findsOneWidget);
  });

  testWidgets('a later leg the current blocks is named under the profile', (
    tester,
  ) async {
    await _openRoute(tester, const [
      wall,
      MissionLeg(
        id: 'L2',
        order: 1,
        label: 'Channel',
        distanceM: 200,
        depthM: 20,
        headingDeg: 0,
        // 1.2 m/s setting south against 0.9 m/s scooters heading north.
        current: CurrentVector(speedMps: 1.2, setsTowardDeg: 180),
      ),
    ]);
    expect(find.text('The current blocks Channel'), findsOneWidget);
    expect(find.text('Generated profile'), findsOneWidget);
  });

  testWidgets('generated profile rows are worded per language', (tester) async {
    await _openRoute(tester, const [wall], locale: const Locale('de'));
    // The route card's profile comes before the Plan Setup sections.
    await tester.tap(find.byType(ExpansionTile).first);
    await tester.pumpAndSettle();
    expect(find.textContaining(' Min.'), findsWidgets);
    expect(find.textContaining(' min'), findsNothing);
  });
}
