// Instances here are deliberately non-const: const instances canonicalise to
// a single instance, so == short-circuits on identity and the Equatable props
// under test are never evaluated.
// ignore_for_file: prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';

ScooterSpec _scooter() => ScooterSpec(
  equipmentId: 'eq-1',
  name: 'Blacktip',
  ratedSpeedMps: 0.9,
  burnTimeSeconds: 5400,
  towSpeedFactor: 0.55,
  towBurnFactor: 1.7,
);

MissionMember _member() => MissionMember(
  id: 'm1',
  order: 0,
  displayName: 'Sam',
  buddyId: 'buddy-1',
  diverId: 'diver-1',
  sacBottom: 15,
  swimSpeedMps: 0.25,
  scooter: _scooter(),
);

MissionLeg _leg() => MissionLeg(
  id: 'L1',
  order: 0,
  label: 'T',
  distanceM: 300,
  depthM: 20,
  headingDeg: 90,
  current: CurrentVector(speedMps: 0.2, setsTowardDeg: 45),
);

void main() {
  group('CurrentVector', () {
    test('copyWith replaces each field and keeps the other', () {
      final current = CurrentVector(speedMps: 0.2, setsTowardDeg: 45);
      expect(
        current.copyWith(speedMps: 0.5),
        CurrentVector(speedMps: 0.5, setsTowardDeg: 45),
      );
      expect(
        current.copyWith(setsTowardDeg: 90),
        CurrentVector(speedMps: 0.2, setsTowardDeg: 90),
      );
      expect(current.copyWith(), current);
      expect(current.hashCode, current.copyWith().hashCode);
    });
  });

  group('ScooterSpec', () {
    test('copyWith replaces every field', () {
      final spec = _scooter().copyWith(
        equipmentId: 'eq-2',
        name: 'Other',
        ratedSpeedMps: 1.1,
        burnTimeSeconds: 3600,
        towSpeedFactor: 0.5,
        towBurnFactor: 2.0,
      );
      expect(spec.equipmentId, 'eq-2');
      expect(spec.name, 'Other');
      expect(spec.ratedSpeedMps, 1.1);
      expect(spec.burnTimeSeconds, 3600);
      expect(spec.towSpeedFactor, 0.5);
      expect(spec.towBurnFactor, 2.0);
    });

    test('an empty copyWith is equal, and each field breaks equality', () {
      final spec = _scooter();
      expect(spec.copyWith(), spec);
      expect(spec.copyWith().hashCode, spec.hashCode);
      expect(spec.copyWith(towBurnFactor: 1.5), isNot(spec));
      expect(spec.copyWith(burnTimeSeconds: 1), isNot(spec));
    });

    test('tow speed is the rated speed times the tow speed factor', () {
      expect(_scooter().towSpeedMps, closeTo(0.9 * 0.55, 1e-12));
    });
  });

  group('MissionMember', () {
    test('copyWith replaces every field', () {
      final other = _scooter().copyWith(name: 'Other');
      final member = _member().copyWith(
        id: 'm2',
        order: 3,
        displayName: 'Alex',
        buddyId: 'buddy-2',
        diverId: 'diver-2',
        sacBottom: 18,
        swimSpeedMps: 0.15,
        scooter: other,
      );
      expect(member.id, 'm2');
      expect(member.order, 3);
      expect(member.displayName, 'Alex');
      expect(member.buddyId, 'buddy-2');
      expect(member.diverId, 'diver-2');
      expect(member.sacBottom, 18);
      expect(member.swimSpeedMps, 0.15);
      expect(member.scooter, other);
    });

    test('the clear flags drop the buddy and diver links only', () {
      final member = _member();
      final cleared = member.copyWith(clearBuddyId: true, clearDiverId: true);
      expect(cleared.buddyId, isNull);
      expect(cleared.diverId, isNull);
      expect(cleared.displayName, member.displayName);
      expect(member.copyWith(displayName: 'x').buddyId, 'buddy-1');
    });

    test('an empty copyWith is equal, and a changed SAC is not', () {
      final member = _member();
      expect(member.copyWith(), member);
      expect(member.copyWith().hashCode, member.hashCode);
      expect(member.copyWith(sacBottom: 20), isNot(member));
    });
  });

  group('MissionLeg', () {
    test('copyWith replaces every field and can clear the current', () {
      final leg = _leg().copyWith(
        id: 'L2',
        order: 1,
        label: 'Jump 2',
        distanceM: 150,
        depthM: 30,
        headingDeg: 180,
        current: CurrentVector(speedMps: 0.1, setsTowardDeg: 0),
      );
      expect(leg.id, 'L2');
      expect(leg.order, 1);
      expect(leg.label, 'Jump 2');
      expect(leg.distanceM, 150);
      expect(leg.depthM, 30);
      expect(leg.headingDeg, 180);
      expect(leg.current, CurrentVector(speedMps: 0.1, setsTowardDeg: 0));
      expect(leg.copyWith(clearCurrent: true).current, isNull);
      expect(_leg().copyWith(), _leg());
    });

    test('the return heading is the reciprocal, wrapped to 0 to 360', () {
      expect(_leg().returnHeadingDeg, 270);
      expect(_leg().copyWith(headingDeg: 270).returnHeadingDeg, 90);
      expect(_leg().copyWith(headingDeg: 0).returnHeadingDeg, 180);
    });
  });

  group('DpvMission', () {
    test('copyWith replaces the team and can clear the default current', () {
      final mission = DpvMission(
        legs: [_leg()],
        defaultCurrent: CurrentVector(speedMps: 0.1, setsTowardDeg: 0),
      );
      final withTeam = mission.copyWith(team: [_member()]);
      expect(withTeam.team, [_member()]);
      expect(withTeam.legs, [_leg()]);
      expect(withTeam.defaultCurrent, isNotNull);
      expect(
        withTeam.copyWith(clearDefaultCurrent: true).defaultCurrent,
        isNull,
      );
      expect(
        mission
            .copyWith(
              defaultCurrent: CurrentVector(speedMps: 0.3, setsTowardDeg: 10),
            )
            .defaultCurrent,
        CurrentVector(speedMps: 0.3, setsTowardDeg: 10),
      );
    });
  });

  group('outcome value equality', () {
    // Each builder takes one varied field so the "not equal" case proves the
    // field is part of props rather than merely present on the class.
    MissionIssue issue({String? legId = 'L1'}) => MissionIssue(
      type: MissionIssueType.untraversableLeg,
      severity: MissionIssueSeverity.blocking,
      legId: legId,
      memberId: 'm1',
      outbound: false,
    );
    LegOutcome leg({int outboundSeconds = 600}) => LegOutcome(
      legId: 'L1',
      outboundSpeedMps: 0.5,
      returnSpeedMps: 0.4,
      outboundSeconds: outboundSeconds,
      returnSeconds: 750,
    );
    ExitOutcome exit({bool blocked = false}) => ExitOutcome(
      mode: MissionExitMode.swim,
      feasible: !blocked,
      exitBottomSeconds: 1500,
      ttsSeconds: 300,
      exitLitersByMember: {'m1': 1200.0},
      blockedByCurrent: blocked,
    );
    WaypointOutcome waypoint({bool survivable = true}) => WaypointOutcome(
      index: 0,
      legId: 'L1',
      cumulativeDistanceM: 300,
      arrivalRuntimeSeconds: 667,
      directDistanceHomeM: 300,
      safeSurfaceSeconds: 900,
      members: [
        MemberWaypointOutcome(
          memberId: 'm1',
          gasRemainingBar: 180,
          swim: exit(),
          survivable: survivable,
        ),
      ],
      survivable: survivable,
    );
    MemberOutcome member({double? turn = 120}) => MemberOutcome(
      memberId: 'm1',
      batteryRoundTripFraction: 0.4,
      setsCruiseSpeed: true,
      bindingFactor: MissionBindingFactor.battery,
      bindingWaypointIndex: 1,
      turnPressureBar: turn,
    );
    MissionOutcome outcome({int? abandonment = 0}) => MissionOutcome(
      segments: const [],
      cruiseSpeedMps: 0.5,
      legs: [leg()],
      waypoints: [waypoint()],
      members: [member()],
      abandonmentIndex: abandonment,
      constraint: MissionConstraint(
        memberId: 'm1',
        factor: MissionBindingFactor.battery,
        waypointIndex: 1,
      ),
      issues: [issue()],
    );

    test('equal values compare equal with equal hash codes', () {
      for (final (a, b) in [
        (issue(), issue()),
        (leg(), leg()),
        (exit(), exit()),
        (waypoint(), waypoint()),
        (member(), member()),
        (outcome(), outcome()),
      ]) {
        expect(a, b);
        expect(a.hashCode, b.hashCode);
      }
    });

    test('a changed field breaks equality', () {
      expect(issue(legId: 'L2'), isNot(issue()));
      expect(leg(outboundSeconds: 601), isNot(leg()));
      expect(exit(blocked: true), isNot(exit()));
      expect(waypoint(survivable: false), isNot(waypoint()));
      expect(member(turn: null), isNot(member()));
      expect(outcome(abandonment: null), isNot(outcome()));
    });

    test('an outcome is blocked only by a blocking issue', () {
      expect(outcome().isBlocked, isTrue);
      expect(
        MissionOutcome.empty(
          issues: [
            MissionIssue(
              type: MissionIssueType.scenarioFailed,
              severity: MissionIssueSeverity.warning,
            ),
          ],
        ).isBlocked,
        isFalse,
      );
    });
  });
}
