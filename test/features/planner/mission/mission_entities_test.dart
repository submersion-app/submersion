import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';

const _scooter = ScooterSpec(
  name: 'Blacktip',
  ratedSpeedMps: 0.9,
  burnTimeSeconds: 5400,
);

MissionLeg _leg({String id = 'l1', CurrentVector? current}) => MissionLeg(
  id: id,
  order: 0,
  label: 'T',
  distanceM: 300,
  depthM: 20,
  headingDeg: 90,
  current: current,
);

void main() {
  group('CurrentVector.alongRouteComponent', () {
    test('a current setting along the heading helps by its full speed', () {
      const current = CurrentVector(speedMps: 0.5, setsTowardDeg: 90);
      expect(current.alongRouteComponent(90), closeTo(0.5, 1e-9));
    });

    test('a current setting against the heading hurts by its full speed', () {
      const current = CurrentVector(speedMps: 0.5, setsTowardDeg: 270);
      expect(current.alongRouteComponent(90), closeTo(-0.5, 1e-9));
    });

    test('a cross current contributes nothing along the route', () {
      const current = CurrentVector(speedMps: 0.5, setsTowardDeg: 0);
      expect(current.alongRouteComponent(90), closeTo(0, 1e-9));
    });

    test('a quartering current contributes cos(45 degrees) of its speed', () {
      const current = CurrentVector(speedMps: 0.5, setsTowardDeg: 45);
      expect(
        current.alongRouteComponent(90),
        closeTo(0.5 * math.cos(math.pi / 4), 1e-9),
      );
    });

    test('the reversed heading flips the sign', () {
      const current = CurrentVector(speedMps: 0.5, setsTowardDeg: 45);
      expect(
        current.alongRouteComponent(270),
        closeTo(-current.alongRouteComponent(90), 1e-9),
      );
    });
  });

  group('ScooterSpec defaults', () {
    test('tow factors default to 0.6 speed and 1.5 burn', () {
      expect(_scooter.towSpeedFactor, 0.6);
      expect(_scooter.towBurnFactor, 1.5);
      expect(_scooter.equipmentId, isNull);
    });

    test('copyWith can clear the equipment id', () {
      const linked = ScooterSpec(
        equipmentId: 'eq-1',
        name: 'Blacktip',
        ratedSpeedMps: 0.9,
        burnTimeSeconds: 5400,
      );
      expect(linked.copyWith(clearEquipmentId: true).equipmentId, isNull);
      expect(linked.copyWith(name: 'Other').equipmentId, 'eq-1');
    });
  });

  group('MissionMember defaults', () {
    test('swim speed defaults to 0.2 m/s', () {
      const member = MissionMember(
        id: 'm1',
        order: 0,
        displayName: 'Sam',
        sacBottom: 15,
        scooter: _scooter,
      );
      expect(member.swimSpeedMps, 0.2);
      expect(member.buddyId, isNull);
      expect(member.diverId, isNull);
    });
  });

  group('DpvMission', () {
    test('battery reserve defaults to one third', () {
      const mission = DpvMission();
      expect(mission.batteryReserveFraction, closeTo(1 / 3, 1e-12));
      expect(mission.legs, isEmpty);
      expect(mission.team, isEmpty);
    });

    test('currentFor prefers the leg current over the mission default', () {
      const legCurrent = CurrentVector(speedMps: 0.3, setsTowardDeg: 10);
      const defaultCurrent = CurrentVector(speedMps: 0.1, setsTowardDeg: 200);
      final mission = DpvMission(
        legs: [
          _leg(current: legCurrent),
          _leg(id: 'l2'),
        ],
        defaultCurrent: defaultCurrent,
      );
      expect(mission.currentFor(mission.legs[0]), legCurrent);
      expect(mission.currentFor(mission.legs[1]), defaultCurrent);
    });

    test('currentFor is null when neither the leg nor the mission has one', () {
      final mission = DpvMission(legs: [_leg()]);
      expect(mission.currentFor(mission.legs[0]), isNull);
    });

    test('value equality holds across copies', () {
      final a = DpvMission(legs: [_leg()], batteryReserveFraction: 0.25);
      final b = DpvMission(legs: [_leg()], batteryReserveFraction: 0.25);
      expect(a, b);
      expect(a.copyWith(batteryReserveFraction: 0.5), isNot(b));
    });
  });
}
