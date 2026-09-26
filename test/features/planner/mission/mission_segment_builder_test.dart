import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_segment_builder.dart';

const _air = GasMix(o2: 21);

domain.DivePlan _plan({List<DiveTank>? tanks}) => domain.DivePlan(
  id: 'plan-1',
  name: 'Builder',
  gfLow: 40,
  gfHigh: 80,
  descentRate: 18,
  ascentRate: 9,
  tanks:
      tanks ??
      const [
        DiveTank(
          id: 'back',
          volume: 24,
          startPressure: 200,
          gasMix: _air,
          role: TankRole.backGas,
        ),
      ],
  createdAt: DateTime(2026, 9, 18),
  updatedAt: DateTime(2026, 9, 18),
);

const _l1 = MissionLeg(
  id: 'L1',
  order: 0,
  label: 'A',
  distanceM: 300,
  depthM: 20,
  headingDeg: 90,
);
const _l2 = MissionLeg(
  id: 'L2',
  order: 1,
  label: 'B',
  distanceM: 200,
  depthM: 30,
  headingDeg: 180,
);

void main() {
  const builder = MissionSegmentBuilder();

  test('a two-leg route becomes travel and hold segments out and back', () {
    final profile = builder.build(
      plan: _plan(),
      mission: const DpvMission(legs: [_l1, _l2]),
      throughLegIndex: 1,
      outboundSpeedMps: 0.5,
      exitSpeedMps: 0.5,
    );
    final ids = profile.segments.map((s) => s.id).toList();
    expect(ids, [
      'mission-out-travel-L1',
      'mission-out-L1',
      'mission-out-travel-L2',
      'mission-out-L2',
      'mission-ret-L2',
      'mission-ret-travel-L1',
      'mission-ret-L1',
    ]);
    expect(profile.segments.map((s) => s.targetDepth).toList(), [
      20.0,
      20.0,
      30.0,
      30.0,
      30.0,
      20.0,
      20.0,
    ]);
    expect(profile.segments.map((s) => s.durationSeconds).toList(), [
      67,
      600,
      33,
      400,
      400,
      67,
      600,
    ]);
    expect(profile.segments.map((s) => s.order).toList(), [
      0,
      1,
      2,
      3,
      4,
      5,
      6,
    ]);
    expect(profile.waypointArrivalSeconds, [667, 1100]);
  });

  test('every segment breathes the back gas tank', () {
    final profile = builder.build(
      plan: _plan(
        tanks: const [
          DiveTank(
            id: 'deco',
            volume: 11,
            startPressure: 200,
            gasMix: GasMix(o2: 50),
            role: TankRole.deco,
          ),
          DiveTank(
            id: 'back',
            volume: 24,
            startPressure: 200,
            gasMix: _air,
            role: TankRole.backGas,
          ),
        ],
      ),
      mission: const DpvMission(legs: [_l1]),
      throughLegIndex: 0,
      outboundSpeedMps: 0.5,
      exitSpeedMps: 0.5,
    );
    expect(profile.segments.map((s) => s.tankId).toSet(), {'back'});
    expect(profile.segments.first.gasMix, _air);
  });

  test(
    'a failure at the first waypoint exits only that leg, at exit speed',
    () {
      final profile = builder.build(
        plan: _plan(),
        mission: const DpvMission(legs: [_l1, _l2]),
        throughLegIndex: 0,
        outboundSpeedMps: 0.5,
        exitSpeedMps: 0.2,
      );
      expect(profile.segments.map((s) => s.id).toList(), [
        'mission-out-travel-L1',
        'mission-out-L1',
        'mission-ret-L1',
      ]);
      expect(profile.segments.last.durationSeconds, 1500);
      expect(profile.waypointArrivalSeconds, [667]);
    },
  );

  test('a per-leg current changes the outbound and return holds', () {
    // 0.1 m/s setting toward 90 on a heading of 90: 0.6 out, 0.4 back.
    final leg = _l1.copyWith(
      current: const CurrentVector(speedMps: 0.1, setsTowardDeg: 90),
    );
    final profile = builder.build(
      plan: _plan(),
      mission: DpvMission(legs: [leg]),
      throughLegIndex: 0,
      outboundSpeedMps: 0.5,
      exitSpeedMps: 0.5,
    );
    expect(profile.segments[1].durationSeconds, 500);
    expect(profile.segments[2].durationSeconds, 750);
  });

  test(
    'a leg at the same depth as the previous one needs no travel segment',
    () {
      final flat = _l2.copyWith(depthM: 20);
      final profile = builder.build(
        plan: _plan(),
        mission: DpvMission(legs: [_l1, flat]),
        throughLegIndex: 1,
        outboundSpeedMps: 0.5,
        exitSpeedMps: 0.5,
      );
      expect(profile.segments.map((s) => s.id).toList(), [
        'mission-out-travel-L1',
        'mission-out-L1',
        'mission-out-L2',
        'mission-ret-L2',
        'mission-ret-L1',
      ]);
    },
  );

  test('a speed that makes no headway is refused rather than clamped', () {
    // A one-second hold against a current the diver cannot beat would report
    // an impossible exit as feasible, so the builder must refuse it.
    final leg = _l1.copyWith(
      current: const CurrentVector(speedMps: 0.3, setsTowardDeg: 90),
    );
    expect(
      () => builder.build(
        plan: _plan(),
        mission: DpvMission(legs: [leg]),
        throughLegIndex: 0,
        outboundSpeedMps: 0.5,
        exitSpeedMps: 0.2,
      ),
      throwsArgumentError,
    );
  });

  test('a hold never rounds below the time the leg takes', () {
    // 100 m at 0.3 m/s is 333.3 s; rounding to 333 s would end the leg
    // short of the waypoint, so the hold rounds up.
    final profile = builder.build(
      plan: _plan(),
      mission: DpvMission(legs: [_l1.copyWith(distanceM: 100)]),
      throughLegIndex: 0,
      outboundSpeedMps: 0.3,
      exitSpeedMps: 0.3,
    );
    expect(profile.segments[1].durationSeconds, 334);
    expect(profile.segments[2].durationSeconds, 334);
  });

  test('without a declared back gas the first tank is breathed', () {
    final profile = builder.build(
      plan: _plan(
        tanks: const [
          DiveTank(
            id: 'stage',
            volume: 11,
            startPressure: 200,
            gasMix: _air,
            role: TankRole.stage,
          ),
          DiveTank(
            id: 'other',
            volume: 11,
            startPressure: 200,
            gasMix: _air,
            role: TankRole.stage,
          ),
        ],
      ),
      mission: const DpvMission(legs: [_l1]),
      throughLegIndex: 0,
      outboundSpeedMps: 0.5,
      exitSpeedMps: 0.5,
    );
    expect(profile.segments.map((s) => s.tankId).toSet(), {'stage'});
  });

  test('profiles built from the same inputs are equal', () {
    MissionProfile build(double exit) => builder.build(
      plan: _plan(),
      mission: const DpvMission(legs: [_l1]),
      throughLegIndex: 0,
      outboundSpeedMps: 0.5,
      exitSpeedMps: exit,
    );
    expect(build(0.5), build(0.5));
    expect(build(0.5).hashCode, build(0.5).hashCode);
    expect(build(0.25), isNot(build(0.5)));
  });

  test('a plan without tanks yields no segments', () {
    final profile = builder.build(
      plan: _plan(tanks: const []),
      mission: const DpvMission(legs: [_l1]),
      throughLegIndex: 0,
      outboundSpeedMps: 0.5,
      exitSpeedMps: 0.5,
    );
    expect(profile.segments, isEmpty);
    expect(profile.waypointArrivalSeconds, isEmpty);
  });
}
