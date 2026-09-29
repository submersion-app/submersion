import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_edits.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/presentation/providers/mission_outcome_provider.dart';

/// A two-diver mission the engine can compute: 300 m at 20 m on 0.9 m/s
/// scooters.
void _buildMission(ProviderContainer container) {
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
  var m = MissionEdits.starter(
    legId: 'L1',
    memberId: 'a',
    memberName: 'Sam',
    sacBottom: 15,
  );
  m = MissionEdits.addMember(m, 'b', name: 'Alex', sacBottom: 14);
  m = MissionEdits.updateLeg(
    m,
    m.legs.single.copyWith(label: 'T', distanceM: 300, depthM: 20),
  );
  const scooter = ScooterSpec(
    name: 'Blacktip',
    ratedSpeedMps: 0.9,
    burnTimeSeconds: 5400,
  );
  m = m.copyWith(team: [for (final t in m.team) t.copyWith(scooter: scooter)]);
  notifier.enableMission(m);
}

/// Runs the engine on the calling isolate; widget tests cannot wait on a
/// real isolate inside testWidgets.
Future<MissionOutcome> _syncRunner(
  domain.DivePlan plan,
  DpvMission mission,
  PlanEngineConfig config,
) async => const MissionEngine().compute(plan: plan, mission: mission);

void main() {
  test('no mission, no outcome', () async {
    final container = ProviderContainer(
      overrides: [missionEngineRunnerProvider.overrideWithValue(_syncRunner)],
    );
    addTearDown(container.dispose);
    expect(await container.read(missionOutcomeProvider.future), isNull);
  });

  test('a mission is computed with the diver engine config', () async {
    PlanEngineConfig? seen;
    final container = ProviderContainer(
      overrides: [
        missionEngineRunnerProvider.overrideWithValue((plan, mission, config) {
          seen = config;
          return _syncRunner(plan, mission, config);
        }),
      ],
    );
    addTearDown(container.dispose);
    _buildMission(container);
    final outcome = await container.read(missionOutcomeProvider.future);
    expect(outcome!.waypoints, hasLength(1));
    expect(seen, isNotNull);
  });

  test('the outcome follows the latest edit, not an earlier one', () async {
    final container = ProviderContainer(
      overrides: [missionEngineRunnerProvider.overrideWithValue(_syncRunner)],
    );
    addTearDown(container.dispose);
    _buildMission(container);
    final notifier = container.read(divePlanNotifierProvider.notifier);
    final mission = container.read(divePlanNotifierProvider).mission!;
    // Two edits in a row; only the second may be reported.
    notifier.updateMission(MissionEdits.addLeg(mission, 'L2'));
    notifier.updateMission(
      MissionEdits.updateLeg(
        MissionEdits.addLeg(mission, 'L2'),
        MissionEdits.addLeg(mission, 'L2').legs.last.copyWith(distanceM: 100),
      ),
    );
    final outcome = await container.read(missionOutcomeProvider.future);
    expect(outcome!.waypoints, hasLength(2));
  });

  test('an engine error is an error, not an endless computation', () async {
    final container = ProviderContainer(
      overrides: [
        missionEngineRunnerProvider.overrideWithValue(
          (plan, mission, config) async => throw StateError('isolate'),
        ),
      ],
    );
    addTearDown(container.dispose);
    _buildMission(container);
    await expectLater(
      container.read(missionOutcomeProvider.future),
      throwsA(isA<StateError>()),
    );
  });

  test('the isolate runner computes the same outcome', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    _buildMission(container);
    final state = container.read(divePlanNotifierProvider);
    final plan = divePlanFromState(state);
    const config = PlanEngineConfig();
    final inIsolate = await runMissionEngineInIsolate(
      plan,
      state.mission!,
      config,
    );
    expect(
      inIsolate,
      const MissionEngine().compute(plan: plan, mission: state.mission!),
    );
  });
}
