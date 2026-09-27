import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_engine.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_scenario_service.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_segment_builder.dart';

const _air = GasMix(o2: 21);

domain.DivePlan _plan() => domain.DivePlan(
  id: 'plan-1',
  name: 'Robustness',
  gfLow: 40,
  gfHigh: 80,
  tanks: const [
    DiveTank(
      id: 'back',
      volume: 40,
      startPressure: 230,
      gasMix: _air,
      role: TankRole.backGas,
    ),
  ],
  createdAt: DateTime(2026, 9, 25),
  updatedAt: DateTime(2026, 9, 25),
);

MissionMember _member(String id, int order) => MissionMember(
  id: id,
  order: order,
  displayName: id,
  sacBottom: 15,
  scooter: ScooterSpec(
    name: 'S-$id',
    ratedSpeedMps: 0.5,
    burnTimeSeconds: 7200,
  ),
);

MissionLeg _leg(String id, int order, {double distance = 200}) => MissionLeg(
  id: id,
  order: order,
  label: id,
  distanceM: distance,
  depthM: 20,
  headingDeg: 0,
);

/// Throws from the overhead time-to-safe-surface scenario only.
class _SafeSurfaceThrows extends MissionScenarioService {
  const _SafeSurfaceThrows();

  @override
  int overheadSafeSurfaceSeconds({
    required domain.DivePlan plan,
    required DpvMission mission,
    required int waypointIndex,
    MissionProfile? outbound,
  }) => throw StateError('unschedulable');
}

/// Counts how often an outbound profile is built.
class _CountingBuilder extends MissionSegmentBuilder {
  _CountingBuilder();

  int outbounds = 0;

  @override
  MissionProfile outbound({
    required domain.DivePlan plan,
    required DpvMission mission,
    required int throughLegIndex,
    required double speedMps,
  }) {
    outbounds++;
    return super.outbound(
      plan: plan,
      mission: mission,
      throughLegIndex: throughLegIndex,
      speedMps: speedMps,
    );
  }
}

void main() {
  const engine = MissionEngine();

  group('a leg too short to travel', () {
    for (final distance in [0.0, 0.3]) {
      test('a $distance m leg is a blocking issue, not a crash', () {
        final outcome = engine.compute(
          plan: _plan(),
          mission: DpvMission(
            legs: [
              _leg('L1', 0),
              _leg('L2', 1, distance: distance),
            ],
            team: [_member('a', 0)],
          ),
        );
        expect(outcome.isBlocked, isTrue);
        expect(
          outcome.issues.map((i) => (i.type, i.legId)),
          contains((MissionIssueType.legTooShort, 'L2')),
        );
      });
    }
  });

  test('a plan with no cylinder is a blocking issue, not an empty answer', () {
    final outcome = engine.compute(
      plan: _plan().copyWith(tanks: const []),
      mission: DpvMission(legs: [_leg('L1', 0)], team: [_member('a', 0)]),
    );
    expect(outcome.isBlocked, isTrue);
    expect(
      outcome.issues.map((i) => i.type),
      contains(MissionIssueType.planHasNoTank),
    );
  });

  test('a safe-surface scenario that throws is reported, not swallowed', () {
    final outcome = const MissionEngine(scenarios: _SafeSurfaceThrows())
        .compute(
          plan: _plan(),
          mission: DpvMission(
            legs: [_leg('L1', 0)],
            team: [_member('a', 0), _member('b', 1)],
          ),
        );
    expect(outcome.waypoints.single.safeSurfaceSeconds, isNull);
    expect(
      outcome.issues.map((i) => (i.type, i.legId)),
      contains((MissionIssueType.scenarioFailed, 'L1')),
    );
  });

  test('the outbound profile is built once per waypoint', () {
    // One build for the planned round trip, then one per waypoint shared by
    // every scenario there (two swims, two tows, one safe surface).
    final builder = _CountingBuilder();
    MissionEngine(
      builder: builder,
      scenarios: MissionScenarioService(builder: builder),
    ).compute(
      plan: _plan(),
      mission: DpvMission(
        legs: [_leg('L1', 0), _leg('L2', 1)],
        team: [_member('a', 0), _member('b', 1)],
      ),
    );
    expect(builder.outbounds, 1 + 2);
  });
}
