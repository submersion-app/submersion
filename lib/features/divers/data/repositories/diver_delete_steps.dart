/// The rows the diver deletion removes, table by table, and the entity type
/// each one's tombstone carries.
///
/// A peer learns of these rows' fate only from the deletion log. Their
/// `diver_id` references `divers` with no ON DELETE action, so the diver's
/// own tombstone cascades to nothing there: the peer's FK repair sets the
/// dangling `diver_id` to NULL instead, and readers such as
/// `BuddyRepository`'s exact-name lookup take an ownerless row to mean
/// "shared with every diver". Without a tombstone per row, the deleted
/// diver's dives, gear, buddies and tags would surface for every diver on
/// the other devices, and a base snapshot published there would spread them
/// further.
///
/// Each list carries the children that table's own repository delete
/// tombstones. Children the repository leaves to an ON DELETE CASCADE (a
/// dive's tanks, a site's links) get none: the peer's own cascade takes them
/// when the parent's tombstone lands.
library;

import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';

/// One step of the diver deletion: the rows of [table] matching [where], in
/// which `?1` stands for the diver id, deleted and tombstoned as
/// [entityType].
typedef DiverDeleteStep = ({String table, String entityType, String where});

/// The ids [sql] selects, binding [args] as its arguments.
Future<List<String>> diverRowIds(
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

/// Runs [steps] in order for [diverId], logging a deletion for every row
/// each one deletes. Run it inside the caller's transaction.
///
/// The tombstones go in one batch per step, so a diver with thousands of
/// dives costs one pass over the deletion log instead of a transaction per
/// dive.
Future<void> deleteDiverRows(
  AppDatabase db,
  SyncRepository syncRepository,
  String diverId,
  List<DiverDeleteStep> steps,
) async {
  for (final step in steps) {
    final ids = await diverRowIds(
      db,
      'SELECT id FROM ${step.table} WHERE ${step.where}',
      [diverId],
    );
    if (ids.isEmpty) continue;
    await db.customStatement('DELETE FROM ${step.table} WHERE ${step.where}', [
      diverId,
    ]);
    await syncRepository.logDeletions(
      entityType: step.entityType,
      recordIds: ids,
    );
  }
}

/// The diver's dives. Their children (tanks, profile series, tag links...)
/// cascade here and, from each dive's tombstone, on a peer: the tombstones
/// `DiveRepository.bulkDeleteDives` writes, one per dive.
// stats-scope-exempt: deletion cascade. Deletes the diver's dives, excluded
// ones included.
const List<DiverDeleteStep> diverDiveSteps = [
  (table: 'dives', entityType: 'dives', where: 'diver_id = ?1'),
];

const _ofDiverTrips = 'trip_id IN (SELECT id FROM trips WHERE diver_id = ?1)';

/// The trips and sites the diver still owns: the private ones, and the
/// shared ones too when no diver survived to take them. A trip's children
/// reference `trips` with no ON DELETE action, so they go first, tombstoned
/// as `TripRepository.deleteTrip` tombstones them. A site's own links
/// cascade, as they do from `SiteRepository.deleteSite`.
const List<DiverDeleteStep> diverTripAndSiteSteps = [
  (
    table: 'liveaboard_detail_records',
    entityType: 'liveaboardDetails',
    where: _ofDiverTrips,
  ),
  (
    table: 'trip_itinerary_days',
    entityType: 'itineraryDays',
    where: _ofDiverTrips,
  ),
  (
    table: 'trip_checklist_items',
    entityType: 'tripChecklistItems',
    where: _ofDiverTrips,
  ),
  (
    table: 'trip_day_weather',
    entityType: 'tripDayWeather',
    where: _ofDiverTrips,
  ),
  (table: 'trips', entityType: 'trips', where: 'diver_id = ?1'),
  (table: 'dive_sites', entityType: 'diveSites', where: 'diver_id = ?1'),
];

const _diverGear = 'SELECT id FROM equipment WHERE diver_id = ?1';

/// The diver's gear, with the children `EquipmentRepository.deleteEquipment`
/// tombstones. They would cascade with the gear; deleting them first is the
/// same outcome with their ids in hand.
const List<DiverDeleteStep> diverGearSteps = [
  (
    table: 'service_schedules',
    entityType: 'serviceSchedules',
    where: 'equipment_id IN ($_diverGear)',
  ),
  (
    table: 'service_records',
    entityType: 'serviceRecords',
    where: 'equipment_id IN ($_diverGear)',
  ),
  (
    table: 'equipment_components',
    entityType: 'equipmentComponents',
    where:
        'parent_equipment_id IN ($_diverGear) '
        'OR component_equipment_id IN ($_diverGear)',
  ),
  (
    table: 'equipment_observations',
    entityType: 'equipmentObservations',
    where: 'equipment_id IN ($_diverGear)',
  ),
  (
    table: 'equipment_findings',
    entityType: 'equipmentFindings',
    where: 'equipment_id IN ($_diverGear)',
  ),
  (
    table: 'equipment_tags',
    entityType: 'equipmentTags',
    where: 'equipment_id IN ($_diverGear)',
  ),
  (table: 'equipment', entityType: 'equipment', where: 'diver_id = ?1'),
];

/// The rest of the diver's library. A buddy's certifications cascade with
/// the buddy, so they go first, tombstoned as `BuddyRepository.deleteBuddy`
/// tombstones them; so do a set's geofences and a center's rental gear
/// notes, as `EquipmentSetRepository.deleteSet` and
/// `DiveCenterRepository.deleteDiveCenter` tombstone theirs. Built-in dive
/// types are never synced and stay.
const List<DiverDeleteStep> diverLibrarySteps = [
  (
    table: 'equipment_set_geofences',
    entityType: 'equipmentSetGeofences',
    where: 'set_id IN (SELECT id FROM equipment_sets WHERE diver_id = ?1)',
  ),
  (
    table: 'equipment_sets',
    entityType: 'equipmentSets',
    where: 'diver_id = ?1',
  ),
  (
    table: 'certifications',
    entityType: 'certifications',
    where: 'buddy_id IN (SELECT id FROM buddies WHERE diver_id = ?1)',
  ),
  (table: 'buddies', entityType: 'buddies', where: 'diver_id = ?1'),
  (
    table: 'certifications',
    entityType: 'certifications',
    where: 'diver_id = ?1',
  ),
  (
    table: 'dive_center_gear_notes',
    entityType: 'diveCenterGearNotes',
    where:
        'dive_center_id IN (SELECT id FROM dive_centers WHERE diver_id = ?1)',
  ),
  (table: 'dive_centers', entityType: 'diveCenters', where: 'diver_id = ?1'),
  (table: 'tags', entityType: 'tags', where: 'diver_id = ?1'),
  (
    table: 'dive_types',
    entityType: 'diveTypes',
    where: 'diver_id = ?1 AND is_built_in = 0',
  ),
  (table: 'tank_presets', entityType: 'tankPresets', where: 'diver_id = ?1'),
  (
    table: 'dive_computers',
    entityType: 'diveComputers',
    where: 'diver_id = ?1',
  ),
  (
    table: 'diver_weight_entries',
    entityType: 'diverWeightEntries',
    where: 'diver_id = ?1',
  ),
];

/// A link a surviving dive holds to a row the diver deletion removes.
typedef _DiveLink = ({String column, String parentTable});

/// The dive columns naming a row the deletion removes. None of them has an
/// ON DELETE action, so a link left in place fails that row's DELETE with
/// SqliteException(787) and rolls the whole diver deletion back.
const List<_DiveLink> _diveLinksToDiverRows = [
  (column: 'site_id', parentTable: 'dive_sites'),
  (column: 'trip_id', parentTable: 'trips'),
  (column: 'dive_center_id', parentTable: 'dive_centers'),
];

/// Clears the links surviving dives hold to [diverId]'s sites, trips and
/// dive centers, stamping and marking each dive so the change reaches peers.
/// Run it inside the caller's transaction, after the diver's own dives are
/// deleted (so every dive still holding such a link outlives the diver) and
/// before those rows are.
///
/// Another diver typically holds one because the site or trip was shared at
/// one point and has since been made private again.
Future<void> clearDiveLinksToDiverRows(
  AppDatabase db,
  SyncRepository syncRepository,
  String diverId, {
  required int now,
}) async {
  final staged = <String>{};
  for (final link in _diveLinksToDiverRows) {
    final where =
        '${link.column} IN '
        '(SELECT id FROM ${link.parentTable} WHERE diver_id = ?1)';
    // stats-scope-exempt: deletion cascade cleanup.
    final ids = await diverRowIds(db, 'SELECT id FROM dives WHERE $where', [
      diverId,
    ]);
    if (ids.isEmpty) continue;
    await db.customStatement(
      'UPDATE dives SET ${link.column} = NULL, updated_at = ?2 WHERE $where',
      [diverId, now],
    );
    staged.addAll(ids);
  }
  // Marked once, after the clears: a dive can lose a site and a trip to the
  // same deletion.
  for (final id in staged) {
    await syncRepository.markRecordPending(
      entityType: 'dives',
      recordId: id,
      localUpdatedAt: now,
    );
  }
}
