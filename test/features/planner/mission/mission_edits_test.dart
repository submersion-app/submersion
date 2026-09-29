import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_edits.dart';

/// A DPV equipment item, built as scooter_spec_resolver_test.dart does.
EquipmentItem dpvItem(String id, {double speedMps = 0.9, double hours = 1.5}) {
  EquipmentAttribute num(String key, double value) =>
      EquipmentAttribute.curated(equipmentId: id, key: key, valueNum: value);
  return EquipmentItem(
    id: id,
    name: 'Blacktip',
    type: EquipmentType.dpv,
    attributes: [num('speed_mps', speedMps), num('burn_time_h', hours)],
  );
}

void main() {
  final starter = MissionEdits.starter(
    legId: 'L1',
    memberId: 'm1',
    memberName: 'Sam',
    sacBottom: 16,
  );

  test('the starter has one empty leg and one diver with no scooter', () {
    expect(starter.legs.single.distanceM, 0);
    expect(starter.legs.single.id, 'L1');
    final member = starter.team.single;
    expect(member.displayName, 'Sam');
    expect(member.sacBottom, 16);
    expect(member.swimSpeedMps, kDefaultSwimSpeedMps);
    expect(member.scooter.ratedSpeedMps, 0);
    expect(member.scooter.burnTimeSeconds, 0);
  });

  test('a new leg carries the last depth and heading', () {
    final withDepth = MissionEdits.updateLeg(
      starter,
      starter.legs.single.copyWith(depthM: 24, headingDeg: 135),
    );
    final added = MissionEdits.addLeg(withDepth, 'L2');
    expect(added.legs.map((l) => l.id), ['L1', 'L2']);
    expect(added.legs.last.depthM, 24);
    expect(added.legs.last.headingDeg, 135);
    expect(added.legs.last.distanceM, 0);
    expect(added.legs.map((l) => l.order), [0, 1]);
  });

  test('removing and reordering renumber the order', () {
    var m = MissionEdits.addLeg(starter, 'L2');
    m = MissionEdits.addLeg(m, 'L3');
    m = MissionEdits.reorderLegs(m, 2, 0);
    expect(m.legs.map((l) => l.id), ['L3', 'L1', 'L2']);
    expect(m.legs.map((l) => l.order), [0, 1, 2]);
    m = MissionEdits.removeLeg(m, 'L1');
    expect(m.legs.map((l) => l.id), ['L3', 'L2']);
    expect(m.legs.map((l) => l.order), [0, 1]);
  });

  test('members are added, updated and removed by id', () {
    var m = MissionEdits.addMember(starter, 'm2', name: 'Alex', sacBottom: 14);
    expect(m.team.map((t) => t.displayName), ['Sam', 'Alex']);
    m = MissionEdits.updateMember(m, m.team.last.copyWith(swimSpeedMps: 0.3));
    expect(m.team.last.swimSpeedMps, 0.3);
    m = MissionEdits.removeMember(m, 'm1');
    expect(m.team.map((t) => t.id), ['m2']);
    expect(m.team.single.order, 0);
  });

  group('live scooters', () {
    DpvMission withScooter(String? equipmentId) => MissionEdits.updateMember(
      starter,
      starter.team.single.copyWith(
        scooter: ScooterSpec(
          equipmentId: equipmentId,
          name: 'Old name',
          ratedSpeedMps: 0.5,
          burnTimeSeconds: 3600,
        ),
      ),
    );

    test('a picked scooter takes the live item numbers', () {
      final m = MissionEdits.withLiveScooters(withScooter('eq-1'), [
        dpvItem('eq-1'),
      ]);
      final scooter = m.team.single.scooter;
      expect(scooter.name, 'Blacktip');
      expect(scooter.ratedSpeedMps, 0.9);
      expect(scooter.burnTimeSeconds, 5400);
    });

    test('a deleted item keeps the stored snapshot', () {
      final stored = withScooter('eq-gone');
      expect(MissionEdits.withLiveScooters(stored, [dpvItem('eq-1')]), stored);
    });

    test('a manual scooter is never overlaid', () {
      final stored = withScooter(null);
      expect(MissionEdits.withLiveScooters(stored, [dpvItem('eq-1')]), stored);
    });
  });

  test('the next default name is the lowest one not in use', () {
    String nameFor(int n) => 'Diver $n';
    final two = MissionEdits.addMember(
      MissionEdits.starter(
        legId: 'L1',
        memberId: 'm1',
        memberName: 'Diver 1',
        sacBottom: 15,
      ),
      'm2',
      name: 'Diver 2',
      sacBottom: 15,
    );
    expect(MissionEdits.nextDefaultName(two, nameFor), 'Diver 3');
    final onlyTwo = MissionEdits.removeMember(two, 'm1');
    expect(MissionEdits.nextDefaultName(onlyTwo, nameFor), 'Diver 1');
  });
}
