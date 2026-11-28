import 'dart:math' as math;

import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';

/// Sighting times through a consolidation (issue #5092), kept apart from
/// [DiveConsolidationService] so that service does not grow further.
///
/// Consolidation re-bases a secondary computer's samples by its [offset]
/// from the target, so a sighting time moves with them, never before the
/// start.
int? shiftedSightingTime(int? seconds, int offset) =>
    seconds == null ? null : math.max(0, seconds + offset);

/// Gives the target's sighting of [speciesId] the secondary's time
/// [seconds] when it has none. Undo restores the target's sighting rows
/// from the consolidation snapshot.
Future<void> fillSightingTime(
  AppDatabase db,
  SyncRepository sync, {
  required String targetDiveId,
  required String speciesId,
  required int seconds,
  required int now,
}) async {
  final untimed =
      await (db.select(db.sightings)..where(
            (t) =>
                t.diveId.equals(targetDiveId) &
                t.speciesId.equals(speciesId) &
                t.seenAtSeconds.isNull(),
          ))
          .get();
  for (final row in untimed) {
    await (db.update(db.sightings)..where((t) => t.id.equals(row.id))).write(
      SightingsCompanion(seenAtSeconds: Value(seconds)),
    );
    await sync.markRecordPending(
      entityType: 'sightings',
      recordId: row.id,
      localUpdatedAt: now,
    );
  }
}
