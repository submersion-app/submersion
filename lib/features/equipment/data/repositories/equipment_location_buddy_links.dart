import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';

const _linkChunkSize = 500;

/// Clears the link on every place standing for one of [buddyIds] and stages
/// each place (issue #3790). The place keeps its name, kind and history. The
/// schema's SET NULL would clear the link too, but it reaches no peer. Run
/// it inside the deleting transaction, before the buddies go.
Future<void> clearEquipmentLocationBuddyLinks(
  AppDatabase db,
  SyncRepository syncRepository,
  Iterable<String> buddyIds, {
  required int now,
}) async {
  final placeIds = (await _linkedPlaces(db, buddyIds)).map((r) => r.id);
  await _writeLink(db, syncRepository, placeIds.toList(), null, now: now);
}

/// Moves every place linked to one of [fromBuddyIds] onto [toBuddyId] and
/// stages it, for a buddy merge. Returns each moved place's previous buddy,
/// which [restoreEquipmentLocationBuddyLinks] puts back on an undo. Run it
/// inside the merge's transaction, before the duplicates go.
Future<Map<String, String>> repointEquipmentLocationBuddyLinks(
  AppDatabase db,
  SyncRepository syncRepository, {
  required List<String> fromBuddyIds,
  required String toBuddyId,
  required int now,
}) async {
  final previous = {
    for (final row in await _linkedPlaces(db, fromBuddyIds))
      row.id: row.buddyId!,
  };
  await _writeLink(
    db,
    syncRepository,
    previous.keys.toList(),
    toBuddyId,
    now: now,
  );
  return previous;
}

/// Puts each place in [previousBuddyIds] back on its buddy, for a merge's
/// undo. Run it after the merged buddies exist again.
Future<void> restoreEquipmentLocationBuddyLinks(
  AppDatabase db,
  SyncRepository syncRepository,
  Map<String, String> previousBuddyIds, {
  required int now,
}) async {
  for (final entry in previousBuddyIds.entries) {
    await _writeLink(db, syncRepository, [entry.key], entry.value, now: now);
  }
}

Future<List<EquipmentLocationRow>> _linkedPlaces(
  AppDatabase db,
  Iterable<String> buddyIds,
) async {
  final rows = <EquipmentLocationRow>[];
  for (final chunk in buddyIds.toSet().slices(_linkChunkSize)) {
    rows.addAll(
      await (db.select(
        db.equipmentLocations,
      )..where((t) => t.buddyId.isIn(chunk))).get(),
    );
  }
  return rows;
}

Future<void> _writeLink(
  AppDatabase db,
  SyncRepository syncRepository,
  List<String> placeIds,
  String? buddyId, {
  required int now,
}) async {
  for (final chunk in placeIds.slices(_linkChunkSize)) {
    await (db.update(
      db.equipmentLocations,
    )..where((t) => t.id.isIn(chunk))).write(
      EquipmentLocationsCompanion(
        buddyId: Value(buddyId),
        updatedAt: Value(now),
      ),
    );
  }
  for (final id in placeIds) {
    await syncRepository.markRecordPending(
      entityType: 'equipmentLocations',
      recordId: id,
      localUpdatedAt: now,
    );
  }
}
