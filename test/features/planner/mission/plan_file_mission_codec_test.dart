import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/data/services/plan_file_codec.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/entities/mission/shore_exit.dart';

const _mission = DpvMission(
  legs: [
    MissionLeg(
      id: 'L1',
      order: 0,
      label: 'T',
      distanceM: 300,
      depthM: 20,
      headingDeg: 90,
      current: CurrentVector(speedMps: 0.2, setsTowardDeg: 45),
    ),
    MissionLeg(
      id: 'L2',
      order: 1,
      label: 'Jump 2',
      distanceM: 150,
      depthM: 25,
      headingDeg: 180,
      shoreExit: ShoreExit(surfaceSwimM: 120, walkM: 400),
    ),
  ],
  team: [
    MissionMember(
      id: 'm1',
      order: 0,
      displayName: 'Sam',
      buddyId: 'buddy-1',
      sacBottom: 16,
      swimSpeedMps: 0.25,
      scooter: ScooterSpec(
        equipmentId: 'eq-1',
        name: 'Blacktip',
        ratedSpeedMps: 0.9,
        burnTimeSeconds: 5400,
        towSpeedFactor: 0.55,
        towBurnFactor: 1.7,
      ),
    ),
  ],
  batteryReserveFraction: 0.4,
  defaultCurrent: CurrentVector(speedMps: 0.05, setsTowardDeg: 10),
  environment: MissionEnvironment.openWater,
  walkSpeedMps: 1.1,
  surfaceSwimLimitM: 250,
);

domain.DivePlan _plan({DpvMission? mission}) => domain.DivePlan(
  id: 'plan-1',
  name: 'File mission',
  gfLow: 40,
  gfHigh: 80,
  tanks: const [DiveTank(id: 'tank-1', volume: 12, gasMix: GasMix(o2: 21))],
  mission: mission,
  createdAt: DateTime(2026, 9, 19),
  updatedAt: DateTime(2026, 9, 19),
);

/// The mission as a file carries it: ids blanked, so a comparison ignores
/// the fresh ids an import mints, and the buddy, diver and scooter links
/// cleared, since export drops them.
DpvMission _portable(DpvMission m) => m.copyWith(
  legs: [for (final l in m.legs) l.copyWith(id: '')],
  team: [
    for (final t in m.team)
      t.copyWith(
        id: '',
        clearBuddyId: true,
        clearDiverId: true,
        scooter: t.scooter.copyWith(clearEquipmentId: true),
      ),
  ],
);

void main() {
  test('the format is at version 3', () {
    expect(subplanVersion, 3);
  });

  test('a mission survives export and import under fresh ids', () {
    final imported = subplanFromJson(
      planToSubplanJson(_plan(mission: _mission)),
    );
    final mission = imported.mission!;
    expect(_portable(mission), _portable(_mission));
    expect(mission.legs.map((l) => l.id), isNot(contains('L1')));
    expect(mission.team.single.id, isNot('m1'));
  });

  test('the buddy, diver and scooter links are not exported', () {
    // They name rows in the exporting install; on another install they
    // would dangle or, worse, match an unrelated row.
    final json = jsonDecode(planToSubplanJson(_plan(mission: _mission)));
    final member = json['plan']['mission']['team'][0] as Map<String, dynamic>;
    expect(member.containsKey('buddyId'), isFalse);
    expect(member.containsKey('diverId'), isFalse);
    expect(member.containsKey('scooterEquipmentId'), isFalse);
    final imported = subplanFromJson(jsonEncode(json));
    expect(imported.mission!.team.single.buddyId, isNull);
    expect(imported.mission!.team.single.scooter.equipmentId, isNull);
    expect(imported.mission!.team.single.scooter.name, 'Blacktip');
  });

  test('a file is stamped with the lowest version that can carry it', () {
    // A plan with nothing new stays readable on a version 2 install; only a
    // mission needs version 3.
    expect(jsonDecode(planToSubplanJson(_plan()))['version'], 2);
    expect(
      jsonDecode(planToSubplanJson(_plan(mission: _mission)))['version'],
      3,
    );
  });

  test('a plan without a mission writes no mission block', () {
    final json = jsonDecode(planToSubplanJson(_plan()));
    expect((json['plan'] as Map).containsKey('mission'), isFalse);
    expect(subplanFromJson(jsonEncode(json)).mission, isNull);
  });

  test('a version 2 file still imports, without a mission', () {
    final json = jsonDecode(planToSubplanJson(_plan()));
    json['version'] = 2;
    expect(subplanFromJson(jsonEncode(json)).mission, isNull);
  });

  test('a mission block missing a required field is rejected', () {
    final json = jsonDecode(planToSubplanJson(_plan(mission: _mission)));
    (json['plan']['mission']['legs'][0] as Map).remove('distanceM');
    expect(() => subplanFromJson(jsonEncode(json)), throwsFormatException);
  });

  group('a malformed mission is rejected, not half-imported', () {
    Map<String, dynamic> exported() =>
        jsonDecode(planToSubplanJson(_plan(mission: _mission)))
            as Map<String, dynamic>;

    test('a mission value that is not a map', () {
      final json = exported();
      json['plan']['mission'] = 'broken';
      expect(() => subplanFromJson(jsonEncode(json)), throwsFormatException);
    });

    test('a shore exit missing one of its distances', () {
      final json = exported();
      json['plan']['mission']['legs'][1]['shoreExit'] = {'surfaceSwimM': 120};
      expect(() => subplanFromJson(jsonEncode(json)), throwsFormatException);
    });

    test('a leg current with a non-number field', () {
      final json = exported();
      json['plan']['mission']['legs'][0]['current'] = {
        'speedMps': 'fast',
        'setsTowardDeg': 45,
      };
      expect(() => subplanFromJson(jsonEncode(json)), throwsFormatException);
    });

    test('a default current that is not a map', () {
      final json = exported();
      json['plan']['mission']['defaultCurrent'] = 'north';
      expect(() => subplanFromJson(jsonEncode(json)), throwsFormatException);
    });
  });
}
