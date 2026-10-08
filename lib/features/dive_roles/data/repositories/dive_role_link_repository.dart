import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_roles/domain/services/dive_role_set.dart';

/// Reads and writes the role junctions (issue #1221): `dive_diver_roles` and
/// `dive_buddy_roles`, kept in step with the scalar primary-role columns
/// `dives.diver_role` and `dive_buddies.role` that older app versions read.
///
/// Every read goes through [DiveRoleSet.resolve], so a scalar an older
/// version changed after the junction was written wins. Writes are minimal
/// diffs: unchanged rows keep their ids and clocks, removed rows are
/// tombstoned, new rows are marked pending. No method notifies or opens a
/// transaction; the caller owns both, as the bulk repository methods do.
class DiveRoleLinkRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();

  Future<List<DiveDiverRole>> diverRoleRowsForDives(
    List<String> diveIds,
  ) async {
    if (diveIds.isEmpty) return const [];
    return (_db.select(
      _db.diveDiverRoles,
    )..where((t) => t.diveId.isIn(diveIds))).get();
  }

  Future<List<DiveBuddyRole>> buddyRoleRowsForDives(
    List<String> diveIds,
  ) async {
    if (diveIds.isEmpty) return const [];
    return (_db.select(
      _db.diveBuddyRoles,
    )..where((t) => t.diveId.isIn(diveIds))).get();
  }

  /// Each of [diveIds]' resolved diver role set; a dive with no role maps
  /// to an empty list.
  Future<Map<String, List<String>>> diverRoleIdsForDives(
    List<String> diveIds,
  ) async {
    if (diveIds.isEmpty) return const {};
    final dives =
        await (_db.selectOnly(_db.dives)
              ..addColumns([_db.dives.id, _db.dives.diverRole])
              ..where(_db.dives.id.isIn(diveIds)))
            .get();
    return resolveDiverRoleIds({
      for (final d in dives) d.read(_db.dives.id)!: d.read(_db.dives.diverRole),
    });
  }

  /// [diverRoleIdsForDives] for callers that already hold each dive's
  /// `diver_role` scalar ([scalarByDive]), so only the junction is read.
  Future<Map<String, List<String>>> resolveDiverRoleIds(
    Map<String, String?> scalarByDive,
  ) async {
    if (scalarByDive.isEmpty) return const {};
    final junction = <String, List<String>>{};
    for (final row in await diverRoleRowsForDives(scalarByDive.keys.toList())) {
      junction.putIfAbsent(row.diveId, () => []).add(row.roleId);
    }
    return {
      for (final entry in scalarByDive.entries)
        entry.key: DiveRoleSet.resolve(
          scalar: entry.value,
          junction: junction[entry.key] ?? const [],
        ),
    };
  }

  /// `diveId -> buddyId -> resolved role set` for every `dive_buddies` row
  /// of [diveIds].
  Future<Map<String, Map<String, List<String>>>> buddyRoleIdsForDives(
    List<String> diveIds,
  ) async {
    if (diveIds.isEmpty) return const {};
    final links = await (_db.select(
      _db.diveBuddies,
    )..where((t) => t.diveId.isIn(diveIds))).get();
    return _resolveBuddyLinks(links, await buddyRoleRowsForDives(diveIds));
  }

  /// [buddyRoleIdsForDives] over the whole library, for whole-table
  /// aggregates such as a buddy's usual role.
  Future<Map<String, Map<String, List<String>>>> allBuddyRoleIds() async {
    return _resolveBuddyLinks(
      await _db.select(_db.diveBuddies).get(),
      await _db.select(_db.diveBuddyRoles).get(),
    );
  }

  Map<String, Map<String, List<String>>> _resolveBuddyLinks(
    List<DiveBuddy> links,
    List<DiveBuddyRole> rows,
  ) {
    final junction = <(String, String), List<String>>{};
    for (final row in rows) {
      junction.putIfAbsent((row.diveId, row.buddyId), () => []).add(row.roleId);
    }
    final result = <String, Map<String, List<String>>>{};
    for (final link in links) {
      result.putIfAbsent(
        link.diveId,
        () => {},
      )[link.buddyId] = DiveRoleSet.resolveBuddy(
        scalar: link.role,
        junction: junction[(link.diveId, link.buddyId)] ?? const [],
      );
    }
    return result;
  }

  /// Makes [diveId]'s diver roles [roleIds] (normalized), setting
  /// `dives.diver_role` to the primary role. The dive is marked pending only
  /// when that scalar changes.
  Future<void> writeDiverRoles(
    String diveId,
    Iterable<String> roleIds, {
    int? now,
  }) async {
    final at = now ?? DateTime.now().millisecondsSinceEpoch;
    final wanted = DiveRoleSet.normalize(roleIds);
    final primary = wanted.isEmpty ? null : wanted.first;
    final dive =
        await (_db.selectOnly(_db.dives)
              ..addColumns([_db.dives.diverRole])
              ..where(_db.dives.id.equals(diveId)))
            .getSingleOrNull();
    if (dive == null) return;
    if (dive.read(_db.dives.diverRole) != primary) {
      await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
        DivesCompanion(diverRole: Value(primary), updatedAt: Value(at)),
      );
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: at,
      );
    }
    final existing = await (_db.select(
      _db.diveDiverRoles,
    )..where((t) => t.diveId.equals(diveId))).get();
    for (final row in existing) {
      if (wanted.contains(row.roleId)) continue;
      await (_db.delete(
        _db.diveDiverRoles,
      )..where((t) => t.id.equals(row.id))).go();
      await _syncRepository.logDeletion(
        entityType: 'diveDiverRoles',
        recordId: row.id,
      );
    }
    final have = {for (final r in existing) r.roleId};
    for (final roleId in wanted) {
      if (have.contains(roleId)) continue;
      final id = _uuid.v4();
      await _db
          .into(_db.diveDiverRoles)
          .insert(
            DiveDiverRolesCompanion(
              id: Value(id),
              diveId: Value(diveId),
              roleId: Value(roleId),
              createdAt: Value(at),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'diveDiverRoles',
        recordId: id,
        localUpdatedAt: at,
      );
    }
  }

  /// Makes [buddyId]'s roles on [diveId] [roleIds] (normalized; empty means
  /// Buddy), setting the pair's `dive_buddies.role` to the primary role. A
  /// link row is marked pending only when that scalar changes.
  Future<void> writeBuddyRoles(
    String diveId,
    String buddyId,
    Iterable<String> roleIds, {
    int? now,
  }) async {
    final at = now ?? DateTime.now().millisecondsSinceEpoch;
    final wanted = DiveRoleSet.normalizeBuddy(roleIds);
    final links = await (_db.select(
      _db.diveBuddies,
    )..where((t) => t.diveId.equals(diveId) & t.buddyId.equals(buddyId))).get();
    for (final link in links) {
      if (link.role == wanted.first) continue;
      await (_db.update(_db.diveBuddies)..where((t) => t.id.equals(link.id)))
          .write(DiveBuddiesCompanion(role: Value(wanted.first)));
      await _syncRepository.markRecordPending(
        entityType: 'diveBuddies',
        recordId: link.id,
        localUpdatedAt: at,
      );
    }
    final existing = await (_db.select(
      _db.diveBuddyRoles,
    )..where((t) => t.diveId.equals(diveId) & t.buddyId.equals(buddyId))).get();
    for (final row in existing) {
      if (wanted.contains(row.roleId)) continue;
      await (_db.delete(
        _db.diveBuddyRoles,
      )..where((t) => t.id.equals(row.id))).go();
      await _syncRepository.logDeletion(
        entityType: 'diveBuddyRoles',
        recordId: row.id,
      );
    }
    final have = {for (final r in existing) r.roleId};
    for (final roleId in wanted) {
      if (have.contains(roleId)) continue;
      final id = _uuid.v4();
      await _db
          .into(_db.diveBuddyRoles)
          .insert(
            DiveBuddyRolesCompanion(
              id: Value(id),
              diveId: Value(diveId),
              buddyId: Value(buddyId),
              roleId: Value(roleId),
              createdAt: Value(at),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'diveBuddyRoles',
        recordId: id,
        localUpdatedAt: at,
      );
    }
  }

  /// Deletes and tombstones every role row of [buddyIds] on [diveId], for a
  /// buddy leaving the dive.
  Future<void> deleteBuddyRoles(String diveId, Iterable<String> buddyIds) =>
      deleteBuddyRolesOnDives([diveId], buddyIds);

  /// [deleteBuddyRoles] across [diveIds] in one pass, for bulk removals.
  Future<void> deleteBuddyRolesOnDives(
    List<String> diveIds,
    Iterable<String> buddyIds,
  ) async {
    final ids = buddyIds.toList();
    if (ids.isEmpty || diveIds.isEmpty) return;
    final rows = await (_db.select(
      _db.diveBuddyRoles,
    )..where((t) => t.diveId.isIn(diveIds) & t.buddyId.isIn(ids))).get();
    if (rows.isEmpty) return;
    await (_db.delete(
      _db.diveBuddyRoles,
    )..where((t) => t.diveId.isIn(diveIds) & t.buddyId.isIn(ids))).go();
    await _syncRepository.logDeletions(
      entityType: 'diveBuddyRoles',
      recordIds: rows.map((r) => r.id),
    );
  }

  /// Makes the junction rows of [diveIds] exactly the captured rows, for
  /// undo paths. Rows not captured are tombstoned and deleted; captured rows
  /// are re-inserted under their own ids and marked pending.
  ///
  /// A null [diverRows] or [buddyRows] leaves that table alone.
  /// [onlyBuddyIds] limits the buddy table to those buddies, for an undo
  /// that only touched some people on the dives.
  Future<void> restoreRows({
    required List<String> diveIds,
    List<DiveDiverRole>? diverRows,
    List<DiveBuddyRole>? buddyRows,
    Set<String>? onlyBuddyIds,
  }) async {
    if (diveIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (diverRows != null) {
      final keep = {for (final r in diverRows) r.id};
      final current = await diverRoleRowsForDives(diveIds);
      await _syncRepository.logDeletions(
        entityType: 'diveDiverRoles',
        recordIds: [
          for (final r in current)
            if (!keep.contains(r.id)) r.id,
        ],
      );
      await (_db.delete(
        _db.diveDiverRoles,
      )..where((t) => t.diveId.isIn(diveIds))).go();
      for (final r in diverRows) {
        await _db
            .into(_db.diveDiverRoles)
            .insert(r.toCompanion(false), mode: InsertMode.insertOrReplace);
        await _syncRepository.markRecordPending(
          entityType: 'diveDiverRoles',
          recordId: r.id,
          localUpdatedAt: now,
        );
      }
    }
    if (buddyRows != null) {
      bool inScope(String buddyId) =>
          onlyBuddyIds == null || onlyBuddyIds.contains(buddyId);
      final keep = {for (final r in buddyRows) r.id};
      final current = [
        for (final r in await buddyRoleRowsForDives(diveIds))
          if (inScope(r.buddyId)) r,
      ];
      await _syncRepository.logDeletions(
        entityType: 'diveBuddyRoles',
        recordIds: [
          for (final r in current)
            if (!keep.contains(r.id)) r.id,
        ],
      );
      for (final r in current) {
        await (_db.delete(
          _db.diveBuddyRoles,
        )..where((t) => t.id.equals(r.id))).go();
      }
      for (final r in buddyRows) {
        await _db
            .into(_db.diveBuddyRoles)
            .insert(r.toCompanion(false), mode: InsertMode.insertOrReplace);
        await _syncRepository.markRecordPending(
          entityType: 'diveBuddyRoles',
          recordId: r.id,
          localUpdatedAt: now,
        );
      }
    }
  }
}
