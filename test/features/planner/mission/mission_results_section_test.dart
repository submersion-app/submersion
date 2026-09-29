import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_edits.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_engine.dart';
import 'package:submersion/features/planner/presentation/mission/mission_result_text.dart';
import 'package:submersion/features/planner/presentation/mission/mission_results_section.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/presentation/providers/mission_outcome_provider.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_kit.dart';
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

Future<MissionOutcome> _syncRunner(
  domain.DivePlan plan,
  DpvMission mission,
  PlanEngineConfig config,
) async => const MissionEngine().compute(plan: plan, mission: mission);

DpvMission _mission({int divers = 2}) {
  var m = MissionEdits.starter(
    legId: 'L1',
    memberId: 'a',
    memberName: 'Samantha Richardson',
    sacBottom: 15,
  );
  for (var i = 1; i < divers; i++) {
    m = MissionEdits.addMember(m, 'm$i', name: 'Alexandra $i', sacBottom: 14);
  }
  m = MissionEdits.updateLeg(
    m,
    m.legs.single.copyWith(label: 'Erster Abzweig', distanceM: 300, depthM: 20),
  );
  const scooter = ScooterSpec(
    name: 'Blacktip',
    ratedSpeedMps: 0.9,
    burnTimeSeconds: 5400,
  );
  return m.copyWith(
    team: [for (final t in m.team) t.copyWith(scooter: scooter)],
  );
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required double width,
  DpvMission? mission,
  MissionEngineRunner runner = _syncRunner,
}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        missionEngineRunnerProvider.overrideWithValue(runner),
      ],
      child: const SingleChildScrollView(child: MissionResultsSection()),
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MissionResultsSection)),
  );
  final notifier = container.read(divePlanNotifierProvider.notifier);
  notifier.addTank(
    const DiveTank(
      id: 'back',
      volume: 24,
      startPressure: 230,
      gasMix: GasMix(o2: 21),
      role: TankRole.backGas,
    ),
  );
  notifier.enableMission(mission ?? _mission());
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('a computed mission shows the sentence, cards and waypoints', (
    tester,
  ) async {
    final container = await _pump(tester, width: 400);
    // The battery line in full for one diver, from the outcome itself: the
    // percent and the minutes differ, so a swapped pair changes the text.
    final a = container
        .read(missionOutcomeProvider)
        .value!
        .members
        .firstWhere((m) => m.memberId == 'a');
    expect(
      find.text(
        'Battery ${ceilPercent(a.batteryRoundTripFraction)}% of burn time '
        '(${ceilMinutes((a.batteryRoundTripFraction * 5400).round())}′), '
        'reserve 34%',
      ),
      // Both divers ride the same scooter, so the line can appear twice.
      findsWidgets,
    );
    // Exactly one constraint sentence, whichever the engine concludes.
    expect(
      find.textContaining(
        RegExp(r'^(Limited by|Every waypoint is survivable)'),
      ),
      findsOneWidget,
    );
    // The default reserve is one third, shown rounded up, and every
    // multi-placeholder line reads in sentence order.
    expect(
      find.textContaining(
        RegExp(r'^Battery \d+% of burn time \(\d+′\), reserve 34%$'),
      ),
      findsNWidgets(2),
    );
    expect(find.textContaining(RegExp(r'^300m, arrive \d+′$')), findsOneWidget);
    expect(
      find.textContaining(
        RegExp(r'^Erster Abzweig: out \d+ m/min \d+′, back \d+ m/min \d+′$'),
      ),
      findsOneWidget,
    );
    // Section headers render their label in capitals, so match the widget.
    Finder header(String label) => find.byWidgetPredicate(
      (w) => w is PlanSectionHeader && w.label == label,
    );
    expect(header('Waypoints'), findsOneWidget);
    expect(header('Legs'), findsOneWidget);
  });

  testWidgets('removing a diver before the new outcome lands does not throw', (
    tester,
  ) async {
    final container = await _pump(tester, width: 400);
    final notifier = container.read(divePlanNotifierProvider.notifier);
    final mission = container.read(divePlanNotifierProvider).mission!;
    notifier.updateMission(MissionEdits.removeMember(mission, 'm1'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a solo diver reads no buddy for the tow', (tester) async {
    await _pump(tester, width: 400, mission: _mission(divers: 1));
    expect(find.textContaining('no buddy'), findsWidgets);
  });

  testWidgets('a blocked mission lists why', (tester) async {
    await _pump(
      tester,
      width: 400,
      mission: MissionEdits.starter(
        legId: 'L1',
        memberId: 'a',
        memberName: 'Sam',
        sacBottom: 15,
      ),
    );
    expect(find.textContaining('cannot be computed yet'), findsOneWidget);
    expect(find.textContaining("Sam's scooter needs"), findsOneWidget);
  });

  testWidgets('three divers fit a 320 pt phone', (tester) async {
    await _pump(tester, width: 320, mission: _mission(divers: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an engine error says so instead of computing forever', (
    tester,
  ) async {
    await _pump(
      tester,
      width: 400,
      runner: (plan, mission, config) async => throw StateError('isolate'),
    );
    expect(find.text('The mission could not be computed'), findsOneWidget);
    expect(find.text('Working out the failure scenarios'), findsNothing);
  });

  testWidgets('a scenario that could not be computed is not "cannot get out"', (
    tester,
  ) async {
    await _pump(
      tester,
      width: 400,
      runner: (plan, mission, config) async {
        final real = const MissionEngine().compute(
          plan: plan,
          mission: mission,
        );
        return real.copyWith(
          waypoints: [
            for (final w in real.waypoints)
              w.copyWith(
                survivable: false,
                members: [
                  for (final m in w.members)
                    MemberWaypointOutcome(
                      memberId: m.memberId,
                      gasRemainingBar: m.gasRemainingBar,
                      swim: const ExitOutcome.failed(
                        mode: MissionExitMode.swim,
                      ),
                      survivable: false,
                    ),
                ],
              ),
          ],
        );
      },
    );
    expect(find.textContaining('could not be computed'), findsWidgets);
    expect(find.textContaining('cannot get out'), findsNothing);
  });
}
