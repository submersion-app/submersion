import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/diver_delete_steps.dart';

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
        ? 'diver_id = ?1 AND is_built_in = 0'
        : 'diver_id = ?1';
    final ownedIds = 'SELECT id FROM ${owned.table} WHERE $ownedWhere';
    await deleteDiverRows(db, syncRepository, diverId, [
      for (final child in owned.children)
        (
          table: child.table,
          entityType: child.entityType,
          where: '${child.parentColumn} IN ($ownedIds)',
        ),
      (table: owned.table, entityType: owned.entityType, where: ownedWhere),
    ]);
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
  final keptIds = await diverRowIds(
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
  final deletedIds = await diverRowIds(
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
