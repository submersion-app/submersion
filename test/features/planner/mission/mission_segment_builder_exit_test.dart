import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/exit_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_segment_builder.dart';

const _air = GasMix(o2: 21);

domain.DivePlan _plan() => domain.DivePlan(
  id: 'plan-1',
  name: 'Builder exits',
  gfLow: 40,
  gfHigh: 80,
  descentRate: 18,
  ascentRate: 9,
  tanks: const [
    DiveTank(
      id: 'back',
      volume: 24,
      startPressure: 200,
      gasMix: _air,
      role: TankRole.backGas,
    ),
  ],
  createdAt: DateTime(2026, 9, 25),
  updatedAt: DateTime(2026, 9, 25),
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
  distanceM: 400,
  depthM: 30,
  headingDeg: 0,
);

void main() {
  const builder = MissionSegmentBuilder();
  const mission = DpvMission(legs: [_l1, _l2]);

  test('outbound stops at the waypoint', () {
    final profile = builder.outbound(
      plan: _plan(),
      mission: mission,
      throughLegIndex: 1,
      speedMps: 0.5,
    );
    expect(profile.segments.map((s) => s.id), [
      'mission-out-travel-L1',
      'mission-out-L1',
      'mission-out-travel-L2',
      'mission-out-L2',
    ]);
    expect(profile.waypointArrivalSeconds, [667, 1500]);
  });

  test('a straight leg home is appended at its own speed', () {
    final out = builder.outbound(
      plan: _plan(),
      mission: mission,
      throughLegIndex: 1,
      speedMps: 0.5,
    );
    final segments = builder.appendExitLegs(
      plan: _plan(),
      segments: out.segments,
      exitLegs: const [
        ExitLeg(id: 'home', distanceM: 500, depthM: 30, headingDeg: 216.87),
      ],
      exitSpeedMps: 0.2,
    );
    expect(segments.length, out.segments.length + 1);
    expect(segments.last.id, 'mission-ret-home');
    expect(segments.last.durationSeconds, 2500);
    expect(segments.last.order, out.segments.length);
    // The input list is left alone.
    expect(out.segments.length, 4);
  });

  test('an exit leg at a new depth gets its travel first', () {
    final out = builder.outbound(
      plan: _plan(),
      mission: mission,
      throughLegIndex: 1,
      speedMps: 0.5,
    );
    final segments = builder.appendExitLegs(
      plan: _plan(),
      segments: out.segments,
      exitLegs: const [
        ExitLeg(id: 'home', distanceM: 500, depthM: 10, headingDeg: 216.87),
      ],
      exitSpeedMps: 0.2,
    );
    expect(segments.map((s) => s.id).skip(4), [
      'mission-ret-travel-home',
      'mission-ret-home',
    ]);
  });

  test('an exit leg shorter than the minimum is skipped', () {
    final out = builder.outbound(
      plan: _plan(),
      mission: mission,
      throughLegIndex: 1,
      speedMps: 0.5,
    );
    final segments = builder.appendExitLegs(
      plan: _plan(),
      segments: out.segments,
      exitLegs: const [
        ExitLeg(id: 'home', distanceM: 0.1, depthM: 30, headingDeg: 0),
      ],
      exitSpeedMps: 0.2,
    );
    expect(segments, out.segments);
  });

  test('build is outbound plus the retraced route', () {
    final built = builder.build(
      plan: _plan(),
      mission: mission,
      throughLegIndex: 1,
      outboundSpeedMps: 0.5,
      exitSpeedMps: 0.5,
    );
    expect(built.segments.map((s) => s.id).skip(4), [
      'mission-ret-L2',
      'mission-ret-travel-L1',
      'mission-ret-L1',
    ]);
  });
}
