import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/trip_cylinder_links.dart';
import 'package:submersion/features/trips/data/side_trip_sql.dart';

/// Prepares the side-trip links for deleting [tripIds] (issue #3658). Run it
/// inside the deleting transaction, before the trips' dives lose their trip.
///
/// * A side trip being deleted hands every profile's dives to its larger
///   trip, when that trip survives: the dives were on the larger trip all
///   along, so they must not end up on none.
/// * A side trip that survives the delete of its larger trip becomes a trip
///   of its own.
///
/// Each changed row is stamped and marked pending so the change reaches
/// peers.
Future<void> detachSideTripsForDelete(
  AppDatabase db,
  SyncRepository syncRepository,
  List<String> tripIds, {
  required int now,
}) async {
  final deleting = tripIds.toSet();
  for (final tripId in deleting) {
    final parentRows = await db
        .customSelect(
          validParentIdSql('?1'),
          variables: [Variable.withString(tripId)],
        )
        .get();
    if (parentRows.isEmpty) continue;
    final parentId = parentRows.single.read<String>('id');
    if (deleting.contains(parentId)) continue;
    final dives = await db
        .customSelect(
          // stats-scope-exempt: deletion cleanup, excluded dives included.
          'SELECT id FROM dives WHERE trip_id = ?',
          variables: [Variable.withString(tripId)],
        )
        .get();
    if (dives.isEmpty) continue;
    await db.customUpdate(
      'UPDATE dives SET trip_id = ?, updated_at = ? WHERE trip_id = ?',
      variables: [
        Variable.withString(parentId),
        Variable.withInt(now),
        Variable.withString(tripId),
      ],
      updates: {db.dives},
    );
    for (final row in dives) {
      await syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: row.read<String>('id'),
        localUpdatedAt: now,
      );
    }
  }

  final ids = deleting.toList();
  final marks = List.filled(ids.length, '?').join(', ');
  final orphans = await db
      .customSelect(
        'SELECT id FROM trips WHERE parent_trip_id IN ($marks) '
        'AND id NOT IN ($marks)',
        variables: [
          for (final id in [...ids, ...ids]) Variable.withString(id),
        ],
      )
      .get();
  for (final row in orphans) {
    final id = row.read<String>('id');
    await (db.update(db.trips)..where((t) => t.id.equals(id))).write(
      TripsCompanion(
        parentTripId: const Value(null),
        updatedAt: Value(now),
        hlc: Value(await syncRepository.issueRowClock()),
      ),
    );
    await syncRepository.markRecordPending(
      entityType: 'trips',
      recordId: id,
      localUpdatedAt: now,
    );
  }
}

/// [parentId] when trip [tripId] may be its side trip, else null (issue
/// #3658): never itself, never a trip that is missing or is a side trip,
/// and never for a trip that has side trips of its own. The trip form only
/// offers valid parents; this keeps a stale choice or a sync race from
/// writing a link every reader would then ignore.
///
/// Only a parent being set or changed is checked: [parentId] equal to
/// [storedParentId], the trip's parent as stored, is kept as it is (issue
/// #4941). `parent_trip_id` has no foreign key because a sync can deliver a
/// side trip before its larger trip, so an edit that leaves the parent
/// alone must not unlink it while the larger trip is missing here, or while
/// a sync race leaves either trip briefly in a shape the check refuses.
Future<String?> writableParentId(
  AppDatabase db, {
  required String tripId,
  required String? parentId,
  String? storedParentId,
}) async {
  if (parentId == null || parentId == tripId) return null;
  if (parentId == storedParentId) return parentId;
  final row = await db
      .customSelect(
        'SELECT '
        '(SELECT COUNT(*) FROM trips WHERE id = ?1 '
        'AND parent_trip_id IS NULL) AS parent_ok, '
        '(SELECT COUNT(*) FROM trips WHERE parent_trip_id = ?2) AS children',
        variables: [Variable.withString(parentId), Variable.withString(tripId)],
        readsFrom: {db.trips},
      )
      .getSingle();
  final ok = row.read<int>('parent_ok') == 1 && row.read<int>('children') == 0;
  return ok ? parentId : null;
}

/// Drops the links every dive on [tripId] (every profile's) has to cylinders
/// of a trip it no longer shares cylinders with: for a side trip moved to
/// another larger trip, or made a trip of its own (issue #3658). Run it
/// after the trip's new parent is written, so the rule reads it.
Future<void> clearForeignLinksOnTripDives(
  AppDatabase db,
  SyncRepository syncRepository,
  String tripId, {
  required int now,
}) async {
  final rows = await db
      .customSelect(
        // stats-scope-exempt: tank link cleanup, excluded dives included.
        'SELECT id FROM dives WHERE trip_id = ?',
        variables: [Variable.withString(tripId)],
      )
      .get();
  for (final row in rows) {
    await clearForeignTripCylinderLinks(
      db,
      syncRepository,
      row.read<String>('id'),
      tripId: tripId,
      now: now,
    );
  }
}
