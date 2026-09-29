import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/services/mission/scooter_spec_resolver.dart';

/// Every edit the canvas makes to a DPV mission (issue #2086), as pure
/// functions returning a new mission. Each keeps a leg's or member's `order`
/// equal to its list position, which is what persistence stores.
abstract final class MissionEdits {
  /// The mission a plan starts with when the diver turns it on: one empty
  /// leg and one diver whose scooter has no numbers yet. Both are blocking
  /// validation issues, which the canvas shows until they are filled in.
  static DpvMission starter({
    required String legId,
    required String memberId,
    required String memberName,
    required double sacBottom,
  }) {
    return DpvMission(
      legs: [
        MissionLeg(
          id: legId,
          order: 0,
          label: '',
          distanceM: 0,
          depthM: 0,
          headingDeg: 0,
        ),
      ],
      team: [
        MissionMember(
          id: memberId,
          order: 0,
          displayName: memberName,
          sacBottom: sacBottom,
          scooter: const ScooterSpec(
            name: '',
            ratedSpeedMps: 0,
            burnTimeSeconds: 0,
          ),
        ),
      ],
    );
  }

  /// Appends a leg that continues at the last leg's depth and heading.
  static DpvMission addLeg(DpvMission m, String id) {
    final last = m.legs.isEmpty ? null : m.legs.last;
    return _withLegs(m, [
      ...m.legs,
      MissionLeg(
        id: id,
        order: m.legs.length,
        label: '',
        distanceM: 0,
        depthM: last?.depthM ?? 0,
        headingDeg: last?.headingDeg ?? 0,
      ),
    ]);
  }

  static DpvMission updateLeg(DpvMission m, MissionLeg leg) =>
      _withLegs(m, [for (final l in m.legs) l.id == leg.id ? leg : l]);

  static DpvMission removeLeg(DpvMission m, String id) => _withLegs(m, [
    for (final l in m.legs)
      if (l.id != id) l,
  ]);

  /// Same index convention as DivePlanNotifier.reorderSegments.
  static DpvMission reorderLegs(DpvMission m, int oldIndex, int newIndex) {
    final legs = [...m.legs];
    final moved = legs.removeAt(oldIndex);
    legs.insert(newIndex.clamp(0, legs.length), moved);
    return _withLegs(m, legs);
  }

  static DpvMission addMember(
    DpvMission m,
    String id, {
    required String name,
    required double sacBottom,
  }) {
    return _withTeam(m, [
      ...m.team,
      MissionMember(
        id: id,
        order: m.team.length,
        displayName: name,
        sacBottom: sacBottom,
        scooter: const ScooterSpec(
          name: '',
          ratedSpeedMps: 0,
          burnTimeSeconds: 0,
        ),
      ),
    ]);
  }

  /// The first of `nameFor(1)`, `nameFor(2)`, ... that no diver is called,
  /// so removing "Diver 1" and adding a diver does not make two "Diver 2"s.
  static String nextDefaultName(
    DpvMission m,
    String Function(int number) nameFor,
  ) {
    final taken = {for (final t in m.team) t.displayName};
    var n = 1;
    while (taken.contains(nameFor(n))) {
      n++;
    }
    return nameFor(n);
  }

  static DpvMission updateMember(DpvMission m, MissionMember member) =>
      _withTeam(m, [for (final t in m.team) t.id == member.id ? member : t]);

  static DpvMission removeMember(DpvMission m, String id) => _withTeam(m, [
    for (final t in m.team)
      if (t.id != id) t,
  ]);

  /// Each member's scooter refreshed from the live equipment item it was
  /// picked from. A manual scooter, or one whose item is gone, keeps its
  /// stored numbers (the spec's snapshot fallback).
  static DpvMission withLiveScooters(DpvMission m, List<EquipmentItem> items) {
    const resolver = ScooterSpecResolver();
    final byId = {for (final item in items) item.id: item};
    final team = [
      for (final t in m.team)
        t.copyWith(
          scooter: resolver.overlay(
            t.scooter,
            t.scooter.equipmentId == null ? null : byId[t.scooter.equipmentId],
          ),
        ),
    ];
    final changed = [
      for (var i = 0; i < team.length; i++) team[i] != m.team[i],
    ].any((c) => c);
    return changed ? m.copyWith(team: team) : m;
  }

  static DpvMission _withLegs(DpvMission m, List<MissionLeg> legs) =>
      m.copyWith(
        legs: [for (final (i, l) in legs.indexed) l.copyWith(order: i)],
      );

  static DpvMission _withTeam(DpvMission m, List<MissionMember> team) =>
      m.copyWith(
        team: [for (final (i, t) in team.indexed) t.copyWith(order: i)],
      );
}
