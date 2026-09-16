import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';

/// A table whose rows are deleted and tombstoned together with their parent,
/// linked to it by [parentColumn].
typedef _ChildTable = ({String table, String entityType, String parentColumn});

/// A diver-owned table that the diver deletion clears row by row.
///
/// [hasBuiltIns] tables keep seeded rows that are never synced: they are
/// left alone, as `dive_types` and `site_types` are.
typedef _OwnedTable = ({
  String table,
  String entityType,
  bool hasBuiltIns,
  List<_ChildTable> children,
});

/// The diver-owned tables whose `diver_id` references `divers` with no
/// ON DELETE action and which have no bespoke step in the diver deletion.
/// Children are deleted in list order, before their parent.
const List<_OwnedTable> _ownedTables = [
  (
    table: 'weight_presets',
    entityType: 'weightPresets',
    hasBuiltIns: false,
    children: [
      (
        table: 'weight_preset_entries',
        entityType: 'weightPresetEntries',
        parentColumn: 'preset_id',
      ),
    ],
  ),
  (
    table: 'cylinder_configs',
    entityType: 'cylinderConfigs',
    hasBuiltIns: false,
    children: [
      (
        table: 'cylinder_config_items',
        entityType: 'cylinderConfigItems',
        parentColumn: 'config_id',
      ),
    ],
  ),
  (
    table: 'transmitters',
    entityType: 'transmitters',
    hasBuiltIns: false,
    children: [],
  ),
  (
    table: 'dive_roles',
    entityType: 'diveRoles',
    hasBuiltIns: true,
    children: [],
  ),
  // Segments before tanks: a segment's tank_id has no ON DELETE action. The
  // plan's equipment links cascade, here and on a peer applying the plan's
  // tombstone, as DivePlanRepository.deletePlan leaves them.
  (
    table: 'dive_plans',
    entityType: 'divePlans',
    hasBuiltIns: false,
    children: [
      (
        table: 'dive_plan_segments',
        entityType: 'divePlanSegments',
        parentColumn: 'plan_id',
      ),
      (
        table: 'dive_plan_tanks',
        entityType: 'divePlanTanks',
        parentColumn: 'plan_id',
      ),
    ],
  ),
  (
    table: 'checklist_templates',
    entityType: 'checklistTemplates',
    hasBuiltIns: false,
    children: [
      (
        table: 'checklist_template_items',
        entityType: 'checklistTemplateItems',
        parentColumn: 'template_id',
      ),
    ],
  ),
  (
    table: 'pre_dive_checklist_templates',
    entityType: 'preDiveChecklistTemplates',
    hasBuiltIns: true,
    children: [
      (
        table: 'pre_dive_checklist_template_items',
        entityType: 'preDiveChecklistTemplateItems',
        parentColumn: 'template_id',
      ),
    ],
  ),
  (
    table: 'pre_dive_sessions',
    entityType: 'preDiveSessions',
    hasBuiltIns: false,
    children: [
      (
        table: 'pre_dive_session_items',
        entityType: 'preDiveSessionItems',
        parentColumn: 'session_id',
      ),
    ],
  ),
];

Future<List<String>> _idsOf(
  AppDatabase db,
  String sql,
  List<String> args,
) async {
  final rows = await db
      .customSelect(
        sql,
        variables: [for (final a in args) Variable.withString(a)],
      )
      .get();
  return [for (final r in rows) r.read<String>('id')];
}

/// Deletes the [child] rows whose parent is one of [parentIds] (a query
/// taking [diverId] as its only argument), logging a deletion for each.
Future<void> _deleteChildren(
  AppDatabase db,
  SyncRepository syncRepository,
  _ChildTable child,
  String parentIds,
  String diverId,
) async {
  final where = '${child.parentColumn} IN ($parentIds)';
  final ids = await _idsOf(db, 'SELECT id FROM ${child.table} WHERE $where', [
    diverId,
  ]);
  if (ids.isEmpty) return;
  await db.customStatement('DELETE FROM ${child.table} WHERE $where', [
    diverId,
  ]);
  for (final id in ids) {
    await syncRepository.logDeletion(
      entityType: child.entityType,
      recordId: id,
    );
  }
}

/// Deletes [diverId]'s rows of every table in [_ownedTables], with their
/// children, logging a deletion for each row. Run it inside the caller's
/// transaction.
///
/// A peer applies the diver's own tombstone as a single-row delete and then
/// sets every dangling `diver_id` to NULL, which the readers of these tables
/// take to mean "shared with every diver". Without a tombstone per row, the
/// deleted diver's templates, configs and presets would surface for everyone
/// on the other devices.
Future<void> deleteDiverOwnedRows(
  AppDatabase db,
  SyncRepository syncRepository,
  String diverId,
) async {
  for (final owned in _ownedTables) {
    final ownedWhere = owned.hasBuiltIns
        ? 'diver_id = ? AND is_built_in = 0'
        : 'diver_id = ?';
    final ownedIds = 'SELECT id FROM ${owned.table} WHERE $ownedWhere';
    for (final child in owned.children) {
      await _deleteChildren(db, syncRepository, child, ownedIds, diverId);
    }
    final ids = await _idsOf(db, ownedIds, [diverId]);
    if (ids.isEmpty) continue;
    await db.customStatement('DELETE FROM ${owned.table} WHERE $ownedWhere', [
      diverId,
    ]);
    for (final id in ids) {
      await syncRepository.logDeletion(
        entityType: owned.entityType,
        recordId: id,
      );
    }
  }
}

/// Trip children whose `trip_id` has no ON DELETE action. The diver deletion
/// removes liveaboard details and itinerary days itself; these two are
/// deleted and tombstoned the way `TripRepository.deleteTrip` does.
const List<_ChildTable> _tripChildren = [
  (
    table: 'trip_checklist_items',
    entityType: 'tripChecklistItems',
    parentColumn: 'trip_id',
  ),
  (
    table: 'trip_day_weather',
    entityType: 'tripDayWeather',
    parentColumn: 'trip_id',
  ),
];

/// Deletes the checklist items and weather days of [diverId]'s trips,
/// logging a deletion for each. Run it inside the caller's transaction,
/// after shared trips have moved to a surviving diver (theirs stay with
/// them) and before the diver's trips are deleted, which these rows would
/// otherwise block.
Future<void> deleteDiverTripChildren(
  AppDatabase db,
  SyncRepository syncRepository,
  String diverId,
) async {
  for (final child in _tripChildren) {
    await _deleteChildren(
      db,
      syncRepository,
      child,
      'SELECT id FROM trips WHERE diver_id = ?',
      diverId,
    );
  }
}

/// Clears the dive center of other divers' dives logged at one of
/// [diverId]'s centers, stamping and marking each dive so the change reaches
/// peers. Run it inside the caller's transaction, after the diver's own
/// dives are deleted (so every dive still pointing at a center survives) and
/// before the centers are deleted.
///
/// `dives.dive_center_id` has no ON DELETE action, so such a dive would
/// otherwise fail the deletion of the center and roll the whole diver
/// deletion back.
Future<void> clearDiveLinksToDiverCenters(
  AppDatabase db,
  SyncRepository syncRepository,
  String diverId, {
  required int now,
}) async {
  const where =
      'dive_center_id IN (SELECT id FROM dive_centers WHERE diver_id = ?)';
  // stats-scope-exempt: deletion cascade cleanup.
  final ids = await _idsOf(db, 'SELECT id FROM dives WHERE $where', [diverId]);
  if (ids.isEmpty) return;
  await db.customStatement(
    'UPDATE dives SET dive_center_id = NULL, updated_at = ? WHERE $where',
    [now, diverId],
  );
  for (final id in ids) {
    await syncRepository.markRecordPending(
      entityType: 'dives',
      recordId: id,
      localUpdatedAt: now,
    );
  }
}

/// Deletes [diverId]'s custom service kinds, except a kind a surviving
/// service schedule still uses: that one moves to [survivorId] (or is
/// shared, when no diver survives), stamped and marked for sync. Run it
/// inside the caller's transaction, after the diver's own equipment is
/// deleted, so every schedule still standing belongs to gear that outlives
/// the diver.
///
/// `service_schedules.service_kind_id` cascades, so deleting a kind another
/// diver's gear is scheduled against would silently delete that schedule.
Future<void> retireDiverServiceKinds(
  AppDatabase db,
  SyncRepository syncRepository,
  String diverId, {
  required String? survivorId,
  required int now,
}) async {
  const owned = 'diver_id = ? AND is_built_in = 0';
  const inUse =
      '$owned AND id IN (SELECT service_kind_id FROM service_schedules)';
  final keptIds = await _idsOf(
    db,
    'SELECT id FROM service_kinds WHERE $inUse',
    [diverId],
  );
  if (keptIds.isNotEmpty) {
    await db.customStatement(
      'UPDATE service_kinds SET diver_id = ?, updated_at = ? WHERE $inUse',
      [survivorId, now, diverId],
    );
    for (final id in keptIds) {
      await syncRepository.markRecordPending(
        entityType: 'serviceKinds',
        recordId: id,
        localUpdatedAt: now,
      );
    }
  }
  // No schedule references what is left, so the cascade takes nothing.
  final deletedIds = await _idsOf(
    db,
    'SELECT id FROM service_kinds WHERE $owned',
    [diverId],
  );
  if (deletedIds.isEmpty) return;
  await db.customStatement('DELETE FROM service_kinds WHERE $owned', [diverId]);
  for (final id in deletedIds) {
    await syncRepository.logDeletion(entityType: 'serviceKinds', recordId: id);
  }
}
