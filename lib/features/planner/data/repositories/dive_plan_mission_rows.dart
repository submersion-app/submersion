import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/entities/mission/shore_exit.dart';

/// Row and entity mapping for a plan's DPV mission (v244, issue #2086).
///
/// The mission row's id is its plan's id. Legs and members store their list
/// position as `sort_order` and read it back as their `order`.
abstract final class DivePlanMissionRows {
  static db.DivePlanMissionsCompanion mission(
    String planId,
    DpvMission mission,
    int now, {
    int? createdAt,
  }) {
    return db.DivePlanMissionsCompanion(
      id: Value(planId),
      planId: Value(planId),
      batteryReserveFraction: Value(mission.batteryReserveFraction),
      defaultCurrentSpeedMps: Value(mission.defaultCurrent?.speedMps),
      defaultCurrentSetsTowardDeg: Value(mission.defaultCurrent?.setsTowardDeg),
      environment: Value(mission.environment.name),
      walkSpeedMps: Value(mission.walkSpeedMps),
      surfaceSwimLimitM: Value(mission.surfaceSwimLimitM),
      createdAt: Value(createdAt ?? now),
      updatedAt: Value(now),
    );
  }

  static db.DivePlanMissionLegsCompanion leg(
    String planId,
    MissionLeg leg,
    int sortOrder,
    int now, {
    int? createdAt,
  }) {
    return db.DivePlanMissionLegsCompanion(
      id: Value(leg.id),
      planId: Value(planId),
      sortOrder: Value(sortOrder),
      label: Value(leg.label),
      distanceM: Value(leg.distanceM),
      depthM: Value(leg.depthM),
      headingDeg: Value(leg.headingDeg),
      currentSpeedMps: Value(leg.current?.speedMps),
      currentSetsTowardDeg: Value(leg.current?.setsTowardDeg),
      shoreSwimM: Value(leg.shoreExit?.surfaceSwimM),
      shoreWalkM: Value(leg.shoreExit?.walkM),
      createdAt: Value(createdAt ?? now),
      updatedAt: Value(now),
    );
  }

  static db.DivePlanMissionMembersCompanion member(
    String planId,
    MissionMember member,
    int sortOrder,
    int now, {
    int? createdAt,
  }) {
    final scooter = member.scooter;
    return db.DivePlanMissionMembersCompanion(
      id: Value(member.id),
      planId: Value(planId),
      sortOrder: Value(sortOrder),
      displayName: Value(member.displayName),
      buddyId: Value(member.buddyId),
      diverId: Value(member.diverId),
      sacBottom: Value(member.sacBottom),
      swimSpeedMps: Value(member.swimSpeedMps),
      scooterEquipmentId: Value(scooter.equipmentId),
      scooterName: Value(scooter.name),
      scooterSpeedMps: Value(scooter.ratedSpeedMps),
      scooterBurnSeconds: Value(scooter.burnTimeSeconds),
      towSpeedFactor: Value(scooter.towSpeedFactor),
      towBurnFactor: Value(scooter.towBurnFactor),
      createdAt: Value(createdAt ?? now),
      updatedAt: Value(now),
    );
  }

  static DpvMission toMission(
    db.DivePlanMission row,
    List<db.DivePlanMissionLeg> legRows,
    List<db.DivePlanMissionMember> memberRows,
  ) {
    final legs = [...legRows]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final members = [...memberRows]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return DpvMission(
      legs: [
        for (final (i, r) in legs.indexed)
          MissionLeg(
            id: r.id,
            order: i,
            label: r.label,
            distanceM: r.distanceM,
            depthM: r.depthM,
            headingDeg: r.headingDeg,
            current: _current(r.currentSpeedMps, r.currentSetsTowardDeg),
            shoreExit: _shore(r.shoreSwimM, r.shoreWalkM),
          ),
      ],
      team: [
        for (final (i, r) in members.indexed)
          MissionMember(
            id: r.id,
            order: i,
            displayName: r.displayName,
            buddyId: r.buddyId,
            diverId: r.diverId,
            sacBottom: r.sacBottom,
            swimSpeedMps: r.swimSpeedMps,
            scooter: ScooterSpec(
              equipmentId: r.scooterEquipmentId,
              name: r.scooterName,
              ratedSpeedMps: r.scooterSpeedMps,
              burnTimeSeconds: r.scooterBurnSeconds,
              towSpeedFactor: r.towSpeedFactor,
              towBurnFactor: r.towBurnFactor,
            ),
          ),
      ],
      batteryReserveFraction: row.batteryReserveFraction,
      defaultCurrent: _current(
        row.defaultCurrentSpeedMps,
        row.defaultCurrentSetsTowardDeg,
      ),
      // An unknown name (a newer peer's environment) reads as overhead, the
      // conservative choice: it never offers a surface exit that may not be.
      environment:
          MissionEnvironment.values.asNameMap()[row.environment] ??
          MissionEnvironment.overhead,
      walkSpeedMps: row.walkSpeedMps,
      surfaceSwimLimitM: row.surfaceSwimLimitM,
    );
  }

  /// A shore exit needs both halves; a row with one reads as none.
  static ShoreExit? _shore(double? swimM, double? walkM) {
    if (swimM == null || walkM == null) return null;
    return ShoreExit(surfaceSwimM: swimM, walkM: walkM);
  }

  /// A current needs both halves; a row with one of them (a partial sync or
  /// a hand-edited database) reads as no current rather than a guess.
  static CurrentVector? _current(double? speedMps, double? setsTowardDeg) {
    if (speedMps == null || setsTowardDeg == null) return null;
    return CurrentVector(speedMps: speedMps, setsTowardDeg: setsTowardDeg);
  }
}
