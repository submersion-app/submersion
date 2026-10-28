import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
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
