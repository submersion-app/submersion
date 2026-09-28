import 'package:drift/drift.dart';

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
}

/// What [DivePlanMissionStore.write] stored and touched: the mission as
/// written (null when it was removed), the rows written and the rows removed.
typedef MissionWrite = ({
  DpvMission? mission,
  MissionRowIds written,
  MissionRowIds removed,
});

/// Persistence for a plan's DPV mission (v244, issue #2086), kept apart
/// from `DivePlanRepository` so that file does not grow further.
///
/// [write] and [deleteAll] run inside the caller's transaction; the
/// `record*` methods run after it commits, so a rollback leaves no stray
/// pending marker or tombstone.
class DivePlanMissionStore {
  const DivePlanMissionStore();

  /// Upserts [mission] for [planId] and deletes the legs and members it no
  /// longer lists; a null [mission] deletes every mission row of the plan.
  ///
  /// Row ids are global, so a leg or member id a row of another plan already
  /// holds (a copy that skipped [remint]) gets a fresh id from [newId]
  /// instead of taking that plan's row over. Returns the mission as stored,
  /// carrying any such new ids, and the rows written and removed.
  Future<MissionWrite> write(
    db.AppDatabase d,
    String planId,
    DpvMission? mission,
    int now,
    String Function() newId,
  ) async {
    final existingMission = await _missionRow(d, planId);
    final existing = await _childrenFor(d, planId);

    if (mission == null) {
      await deleteAll(d, planId);
      return (
        mission: null,
        written: MissionRowIds.none,
        removed: MissionRowIds(
          mission: existingMission != null,
          legIds: [for (final r in existing.legs) r.id],
          memberIds: [for (final r in existing.members) r.id],
        ),
      );
    }

    final stored = await _withOwnIds(d, planId, mission, newId);
    final legCreatedAt = {for (final r in existing.legs) r.id: r.createdAt};
    final memberCreatedAt = {
      for (final r in existing.members) r.id: r.createdAt,
    };
    final keptLegs = {for (final l in stored.legs) l.id};
    final keptMembers = {for (final m in stored.team) m.id};
    final removedLegs = [
      for (final r in existing.legs)
        if (!keptLegs.contains(r.id)) r.id,
    ];
    final removedMembers = [
      for (final r in existing.members)
        if (!keptMembers.contains(r.id)) r.id,
    ];

    await d.batch((b) {
      b.insertAllOnConflictUpdate(d.divePlanMissions, [
        DivePlanMissionRows.mission(
          planId,
          stored,
          now,
          createdAt: existingMission?.createdAt,
        ),
      ]);
      if (stored.legs.isNotEmpty) {
        b.insertAllOnConflictUpdate(d.divePlanMissionLegs, [
          for (final (i, leg) in stored.legs.indexed)
            DivePlanMissionRows.leg(
              planId,
              leg,
              i,
              now,
              createdAt: legCreatedAt[leg.id],
            ),
        ]);
      }
      if (stored.team.isNotEmpty) {
        b.insertAllOnConflictUpdate(d.divePlanMissionMembers, [
          for (final (i, member) in stored.team.indexed)
            DivePlanMissionRows.member(
              planId,
              member,
              i,
              now,
              createdAt: memberCreatedAt[member.id],
            ),
        ]);
      }
      if (removedLegs.isNotEmpty) {
        b.deleteWhere(d.divePlanMissionLegs, (t) => t.id.isIn(removedLegs));
      }
      if (removedMembers.isNotEmpty) {
        b.deleteWhere(
          d.divePlanMissionMembers,
          (t) => t.id.isIn(removedMembers),
        );
      }
    });

    return (
      mission: stored,
      written: MissionRowIds(
        mission: true,
        legIds: [...keptLegs],
        memberIds: [...keptMembers],
      ),
      removed: MissionRowIds(
        mission: false,
        legIds: removedLegs,
        memberIds: removedMembers,
      ),
    );
  }

  /// The mission stored for [planId], or null when the plan has none.
  Future<DpvMission?> read(db.AppDatabase d, String planId) async {
    final row = await _missionRow(d, planId);
    if (row == null) return null;
    final children = await _childrenFor(d, planId);
    return DivePlanMissionRows.toMission(row, children.legs, children.members);
  }

  /// Every mission row [planId] owns, for tombstoning a plan delete.
  Future<MissionRowIds> idsFor(db.AppDatabase d, String planId) async {
    final mission = await _missionRow(d, planId);
    final children = await _childrenFor(d, planId);
    return MissionRowIds(
      mission: mission != null,
      legIds: [for (final r in children.legs) r.id],
      memberIds: [for (final r in children.members) r.id],
    );
  }

  Future<db.DivePlanMission?> _missionRow(db.AppDatabase d, String planId) {
    return (d.select(
      d.divePlanMissions,
    )..where((t) => t.planId.equals(planId))).getSingleOrNull();
  }

  Future<
    ({List<db.DivePlanMissionLeg> legs, List<db.DivePlanMissionMember> members})
  >
  _childrenFor(db.AppDatabase d, String planId) async {
    return (
      legs: await (d.select(
        d.divePlanMissionLegs,
      )..where((t) => t.planId.equals(planId))).get(),
      members: await (d.select(
        d.divePlanMissionMembers,
      )..where((t) => t.planId.equals(planId))).get(),
    );
  }

  /// [mission] with a fresh id on every leg and member whose id a row of
  /// another plan already holds.
  Future<DpvMission> _withOwnIds(
    db.AppDatabase d,
    String planId,
    DpvMission mission,
    String Function() newId,
  ) async {
    final legIds = [for (final l in mission.legs) l.id];
    final memberIds = [for (final m in mission.team) m.id];
    final takenLegs = legIds.isEmpty
        ? const <String>{}
        : {
            for (final r
                in await (d.select(d.divePlanMissionLegs)..where(
                      (t) => t.id.isIn(legIds) & t.planId.isNotValue(planId),
                    ))
                    .get())
              r.id,
          };
    final takenMembers = memberIds.isEmpty
        ? const <String>{}
        : {
            for (final r
                in await (d.select(d.divePlanMissionMembers)..where(
                      (t) => t.id.isIn(memberIds) & t.planId.isNotValue(planId),
                    ))
                    .get())
              r.id,
          };
    if (takenLegs.isEmpty && takenMembers.isEmpty) return mission;
    return mission.copyWith(
      legs: [
        for (final l in mission.legs)
          takenLegs.contains(l.id) ? l.copyWith(id: newId()) : l,
      ],
      team: [
        for (final m in mission.team)
          takenMembers.contains(m.id) ? m.copyWith(id: newId()) : m,
      ],
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
