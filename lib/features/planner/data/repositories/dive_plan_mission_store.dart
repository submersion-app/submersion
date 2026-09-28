import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/features/planner/data/repositories/dive_plan_mission_rows.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';

/// The mission rows a write or delete touched, for sync bookkeeping.
class MissionRowIds {
  /// Whether the mission row itself (id = plan id) is included.
  final bool mission;
  final List<String> legIds;
  final List<String> memberIds;

  const MissionRowIds({
    required this.mission,
    required this.legIds,
    required this.memberIds,
  });

  static const none = MissionRowIds(mission: false, legIds: [], memberIds: []);

  bool get isEmpty => !mission && legIds.isEmpty && memberIds.isEmpty;
}

/// Persistence for a plan's DPV mission (v241, issue #2086), kept apart
/// from `DivePlanRepository` so that file does not grow further.
///
/// [write] and [deleteAll] run inside the caller's transaction; the
/// `record*` methods run after it commits, so a rollback leaves no stray
/// pending marker or tombstone.
class DivePlanMissionStore {
  const DivePlanMissionStore();

  /// Upserts [mission] for [planId] and deletes the legs and members it no
  /// longer lists; a null [mission] deletes every mission row of the plan.
  /// Returns the rows written and the rows removed.
  Future<(MissionRowIds, MissionRowIds)> write(
    db.AppDatabase d,
    String planId,
    DpvMission? mission,
    int now,
  ) async {
    final existingMission = await (d.select(
      d.divePlanMissions,
    )..where((t) => t.planId.equals(planId))).getSingleOrNull();
    final existingLegs = await (d.select(
      d.divePlanMissionLegs,
    )..where((t) => t.planId.equals(planId))).get();
    final existingMembers = await (d.select(
      d.divePlanMissionMembers,
    )..where((t) => t.planId.equals(planId))).get();

    if (mission == null) {
      await deleteAll(d, planId);
      return (
        MissionRowIds.none,
        MissionRowIds(
          mission: existingMission != null,
          legIds: [for (final r in existingLegs) r.id],
          memberIds: [for (final r in existingMembers) r.id],
        ),
      );
    }

    final legCreatedAt = {for (final r in existingLegs) r.id: r.createdAt};
    final memberCreatedAt = {
      for (final r in existingMembers) r.id: r.createdAt,
    };
    await d
        .into(d.divePlanMissions)
        .insertOnConflictUpdate(
          DivePlanMissionRows.mission(
            planId,
            mission,
            now,
            createdAt: existingMission?.createdAt,
          ),
        );
    for (final (i, leg) in mission.legs.indexed) {
      await d
          .into(d.divePlanMissionLegs)
          .insertOnConflictUpdate(
            DivePlanMissionRows.leg(
              planId,
              leg,
              i,
              now,
              createdAt: legCreatedAt[leg.id],
            ),
          );
    }
    for (final (i, member) in mission.team.indexed) {
      await d
          .into(d.divePlanMissionMembers)
          .insertOnConflictUpdate(
            DivePlanMissionRows.member(
              planId,
              member,
              i,
              now,
              createdAt: memberCreatedAt[member.id],
            ),
          );
    }

    final keptLegs = {for (final l in mission.legs) l.id};
    final keptMembers = {for (final m in mission.team) m.id};
    final removedLegs = [
      for (final r in existingLegs)
        if (!keptLegs.contains(r.id)) r.id,
    ];
    final removedMembers = [
      for (final r in existingMembers)
        if (!keptMembers.contains(r.id)) r.id,
    ];
    if (removedLegs.isNotEmpty) {
      await (d.delete(
        d.divePlanMissionLegs,
      )..where((t) => t.id.isIn(removedLegs))).go();
    }
    if (removedMembers.isNotEmpty) {
      await (d.delete(
        d.divePlanMissionMembers,
      )..where((t) => t.id.isIn(removedMembers))).go();
    }

    return (
      MissionRowIds(
        mission: true,
        legIds: [for (final l in mission.legs) l.id],
        memberIds: [for (final m in mission.team) m.id],
      ),
      MissionRowIds(
        mission: false,
        legIds: removedLegs,
        memberIds: removedMembers,
      ),
    );
  }

  /// The mission stored for [planId], or null when the plan has none.
  Future<DpvMission?> read(db.AppDatabase d, String planId) async {
    final row = await (d.select(
      d.divePlanMissions,
    )..where((t) => t.planId.equals(planId))).getSingleOrNull();
    if (row == null) return null;
    final legs = await (d.select(
      d.divePlanMissionLegs,
    )..where((t) => t.planId.equals(planId))).get();
    final members = await (d.select(
      d.divePlanMissionMembers,
    )..where((t) => t.planId.equals(planId))).get();
    return DivePlanMissionRows.toMission(row, legs, members);
  }

  /// Every mission row [planId] owns, for tombstoning a plan delete.
  Future<MissionRowIds> idsFor(db.AppDatabase d, String planId) async {
    final mission = await (d.select(
      d.divePlanMissions,
    )..where((t) => t.planId.equals(planId))).getSingleOrNull();
    final legs = await (d.select(
      d.divePlanMissionLegs,
    )..where((t) => t.planId.equals(planId))).get();
    final members = await (d.select(
      d.divePlanMissionMembers,
    )..where((t) => t.planId.equals(planId))).get();
    return MissionRowIds(
      mission: mission != null,
      legIds: [for (final r in legs) r.id],
      memberIds: [for (final r in members) r.id],
    );
  }

  /// Deletes every mission row of [planId]. The rows reference the plan with
  /// no delete action, so this runs before the plan row is deleted.
  Future<void> deleteAll(db.AppDatabase d, String planId) async {
    await (d.delete(
      d.divePlanMissionLegs,
    )..where((t) => t.planId.equals(planId))).go();
    await (d.delete(
      d.divePlanMissionMembers,
    )..where((t) => t.planId.equals(planId))).go();
    await (d.delete(
      d.divePlanMissions,
    )..where((t) => t.planId.equals(planId))).go();
  }

  /// [mission] with a fresh id on every leg and member, for a duplicated
  /// plan: row ids are global, so the copy cannot reuse the source's.
  DpvMission remint(DpvMission mission, String Function() newId) {
    return mission.copyWith(
      legs: [for (final l in mission.legs) l.copyWith(id: newId())],
      team: [for (final m in mission.team) m.copyWith(id: newId())],
    );
  }

  /// Marks [written] pending and tombstones [removed], after the commit.
  Future<void> recordWrite(
    SyncRepository sync,
    String planId,
    MissionRowIds written,
    MissionRowIds removed,
    int now,
  ) async {
    if (written.mission) {
      await sync.markRecordPending(
        entityType: 'divePlanMissions',
        recordId: planId,
        localUpdatedAt: now,
      );
    }
    for (final id in written.legIds) {
      await sync.markRecordPending(
        entityType: 'divePlanMissionLegs',
        recordId: id,
        localUpdatedAt: now,
      );
    }
    for (final id in written.memberIds) {
      await sync.markRecordPending(
        entityType: 'divePlanMissionMembers',
        recordId: id,
        localUpdatedAt: now,
      );
    }
    await recordDeletion(sync, planId, removed);
  }

  /// Tombstones [removed]: children first, then the mission row.
  Future<void> recordDeletion(
    SyncRepository sync,
    String planId,
    MissionRowIds removed,
  ) async {
    for (final id in removed.legIds) {
      await sync.logDeletion(entityType: 'divePlanMissionLegs', recordId: id);
    }
    for (final id in removed.memberIds) {
      await sync.logDeletion(
        entityType: 'divePlanMissionMembers',
        recordId: id,
      );
    }
    if (removed.mission) {
      await sync.logDeletion(entityType: 'divePlanMissions', recordId: planId);
    }
  }
}
