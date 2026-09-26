import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/entities/mission/shore_exit.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_engine.dart';

const _air = GasMix(o2: 21);

domain.DivePlan _plan({double tankLiters = 40}) => domain.DivePlan(
  id: 'plan-1',
  name: 'Lake',
  gfLow: 40,
  gfHigh: 80,
  descentRate: 18,
  ascentRate: 9,
  sacBottom: 15,
  reservePressure: 50,
  salinityPpt: DiveEnvironment.salinityPptFromDensity(
    DiveEnvironment.en13319Density,
  ),
  tanks: [
    DiveTank(
      id: 'back',
      volume: tankLiters,
      startPressure: 230,
      gasMix: _air,
      role: TankRole.backGas,
    ),
  ],
  createdAt: DateTime(2026, 9, 25),
  updatedAt: DateTime(2026, 9, 25),
);

MissionMember _member(String id, int order, {double swim = 0.2}) =>
    MissionMember(
      id: id,
      order: order,
      displayName: id,
      sacBottom: 15,
      swimSpeedMps: swim,
      scooter: ScooterSpec(
        name: 'S-$id',
        ratedSpeedMps: 0.5,
        burnTimeSeconds: 7200,
      ),
    );

/// Three 200 m legs due north at 20 m: waypoints 200, 400 and 600 m out.
List<MissionLeg> _legs({ShoreExit? shoreAtSecond}) => [
  for (var i = 0; i < 3; i++)
    MissionLeg(
      id: 'L$i',
      order: i,
      label: 'W$i',
      distanceM: 200,
      depthM: 20,
      headingDeg: 0,
      shoreExit: i == 1 ? shoreAtSecond : null,
    ),
];

/// Sets toward the north: the scooters make 0.8 m/s out and 0.2 m/s home,
/// and a 0.2 m/s swimmer makes no headway home at all.
const _northerly = CurrentVector(speedMps: 0.3, setsTowardDeg: 0);

void main() {
  const engine = MissionEngine();

  test(
    'a solo lake diver: straight-line distances, a surface way out, no tow',
    () {
      final outcome = engine.compute(
        plan: _plan(),
        mission: DpvMission(
          legs: _legs(),
          team: [_member('a', 0)],
          environment: MissionEnvironment.openWater,
        ),
      );
      expect(outcome.waypoints.map((w) => w.directDistanceHomeM), [
        closeTo(200, 1e-6),
        closeTo(400, 1e-6),
        closeTo(600, 1e-6),
      ]);
      for (final waypoint in outcome.waypoints) {
        final a = waypoint.members.single;
        expect(a.tow, isNull, reason: 'a solo diver has no buddy to tow them');
        expect(a.surface, isNotNull);
        expect(a.survivable, isTrue);
        expect(waypoint.safeSurfaceSeconds, a.surface!.ttsSeconds);
      }
      expect(outcome.abandonmentIndex, 2);
      expect(outcome.constraint, isNull);
    },
  );

  test('each failed member breathes their own stress on the surface exit', () {
    // The ascent is the same for every failure, but the diver whose scooter
    // died is stressed up to the first stop, so a's gas on a's own surface
    // exit exceeds a's gas on b's.
    final outcome = engine.compute(
      plan: _plan(),
      mission: DpvMission(
        legs: _legs(),
        team: [_member('a', 0), _member('b', 1)],
        environment: MissionEnvironment.openWater,
      ),
    );
    final members = outcome.waypoints.last.members;
    final aFails = members.firstWhere((m) => m.memberId == 'a').surface!;
    final bFails = members.firstWhere((m) => m.memberId == 'b').surface!;
    expect(
      aFails.exitLitersByMember['a']!,
      greaterThan(bFails.exitLitersByMember['a']!),
    );
  });

  test('a buddy can tow in a lake, straight home at tow speed', () {
    final outcome = engine.compute(
      plan: _plan(),
      mission: DpvMission(
        legs: _legs(),
        team: [_member('a', 0), _member('b', 1)],
        environment: MissionEnvironment.openWater,
      ),
    );
    final b = outcome.waypoints.last.members.firstWhere(
      (m) => m.memberId == 'b',
    );
    expect(b.tow!.towerId, 'a');
    expect(b.tow!.exitBottomSeconds, 2000); // 600 m at 0.3 m/s
    expect(b.tow!.feasible, isTrue);
  });

  test('a surface swim limit binds once the underwater swim runs short', () {
    // A 12 L cylinder: from 400 m out the underwater swim home cannot be
    // covered on gas, and the 400 m surface swim is over the 300 m limit.
    final outcome = engine.compute(
      plan: _plan(tankLiters: 12),
      mission: DpvMission(
        legs: _legs(),
        team: [_member('a', 0)],
        environment: MissionEnvironment.openWater,
        surfaceSwimLimitM: 300,
      ),
    );
    expect(outcome.waypoints.map((w) => w.survivable), [true, false, false]);
    expect(outcome.waypoints[1].members.single.swim.feasible, isFalse);
    expect(outcome.abandonmentIndex, 0);
    expect(
      outcome.constraint,
      const MissionConstraint(
        memberId: 'a',
        factor: MissionBindingFactor.surfaceSwimLimit,
        waypointIndex: 1,
      ),
    );
  });

  test('a shore exit and a walk rescue a waypoint the limit would lose', () {
    final outcome = engine.compute(
      plan: _plan(tankLiters: 12),
      mission: DpvMission(
        legs: _legs(
          shoreAtSecond: const ShoreExit(surfaceSwimM: 100, walkM: 300),
        ),
        team: [_member('a', 0)],
        environment: MissionEnvironment.openWater,
        surfaceSwimLimitM: 300,
      ),
    );
    final second = outcome.waypoints[1].members.single.surface!;
    expect(second.viaShore, isTrue);
    expect(second.surfaceSeconds, 875);
    expect(outcome.abandonmentIndex, 1);
    expect(outcome.constraint!.waypointIndex, 2);
    expect(outcome.constraint!.factor, MissionBindingFactor.surfaceSwimLimit);
  });

  test('a current that closes the way home closes the surface swim too', () {
    final outcome = engine.compute(
      plan: _plan(),
      mission: DpvMission(
        legs: _legs(),
        team: [_member('a', 0)],
        environment: MissionEnvironment.openWater,
        defaultCurrent: _northerly,
      ),
    );
    final first = outcome.waypoints.first.members.single;
    expect(first.surface!.blockedByCurrent, isTrue);
    expect(first.survivable, isFalse);
    expect(outcome.abandonmentIndex, isNull);
    expect(
      outcome.constraint,
      const MissionConstraint(
        memberId: 'a',
        factor: MissionBindingFactor.blockedByCurrent,
        waypointIndex: 0,
      ),
    );
  });

  group('open-water inputs are validated', () {
    DpvMission mission({
      ShoreExit? shore,
      double? limit,
      double walkSpeed = 0.8,
    }) => DpvMission(
      legs: _legs(shoreAtSecond: shore),
      team: [_member('a', 0)],
      environment: MissionEnvironment.openWater,
      surfaceSwimLimitM: limit,
      walkSpeedMps: walkSpeed,
    );

    List<(MissionIssueType, String?)> invalid(DpvMission mission) => [
      for (final issue
          in engine.compute(plan: _plan(), mission: mission).issues)
        if (issue.type == MissionIssueType.openWaterInputInvalid)
          (issue.type, issue.legId),
    ];

    test('a negative shore distance is refused, naming the leg', () {
      expect(
        invalid(mission(shore: const ShoreExit(surfaceSwimM: -50, walkM: 0))),
        [(MissionIssueType.openWaterInputInvalid, 'L1')],
      );
      expect(
        invalid(mission(shore: const ShoreExit(surfaceSwimM: 50, walkM: -1))),
        [(MissionIssueType.openWaterInputInvalid, 'L1')],
      );
    });

    test('a negative surface swim limit or walk speed is refused', () {
      expect(invalid(mission(limit: -1)), [
        (MissionIssueType.openWaterInputInvalid, null),
      ]);
      expect(invalid(mission(walkSpeed: -0.5)), [
        (MissionIssueType.openWaterInputInvalid, null),
      ]);
    });

    test('valid inputs raise no issue, and the issue blocks the mission', () {
      expect(
        invalid(mission(shore: const ShoreExit(surfaceSwimM: 0, walkM: 0))),
        isEmpty,
      );
      expect(
        engine.compute(plan: _plan(), mission: mission(limit: -1)).isBlocked,
        isTrue,
      );
    });
  });

  test(
    'a solo diver in an overhead the current closes is blocked by current',
    () {
      final outcome = engine.compute(
        plan: _plan(),
        mission: DpvMission(
          legs: _legs(),
          team: [_member('a', 0)],
          defaultCurrent: _northerly,
        ),
      );
      expect(outcome.waypoints.first.members.single.surface, isNull);
      expect(outcome.abandonmentIndex, isNull);
      expect(
        outcome.constraint,
        const MissionConstraint(
          memberId: 'a',
          factor: MissionBindingFactor.blockedByCurrent,
          waypointIndex: 0,
        ),
      );
    },
  );

  test('an overhead reports a growing time to the next safe surface', () {
    final outcome = engine.compute(
      plan: _plan(),
      mission: DpvMission(
        legs: _legs(),
        team: [_member('a', 0), _member('b', 1)],
      ),
    );
    final times = outcome.waypoints.map((w) => w.safeSurfaceSeconds!).toList();
    expect(times[0], greaterThan(0));
    expect(times[1], greaterThan(times[0]));
    expect(times[2], greaterThan(times[1]));
  });

  test('a member who cannot swim is a blocking issue, not a crash', () {
    final outcome = engine.compute(
      plan: _plan(),
      mission: DpvMission(
        legs: _legs(),
        team: [_member('a', 0, swim: 0)],
        environment: MissionEnvironment.openWater,
      ),
    );
    expect(outcome.isBlocked, isTrue);
    expect(
      outcome.issues.map((i) => (i.type, i.memberId)),
      contains((MissionIssueType.memberSwimSpeedUnset, 'a')),
    );
  });
}
