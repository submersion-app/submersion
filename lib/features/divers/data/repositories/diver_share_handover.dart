import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/data/repositories/item_shares_repository.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';

/// A profile delete's handover of the trips and sites [fromDiverId] shared
/// with chosen profiles (issue #2151): each goes to the profile it was
/// shared with first (oldest share row, then lowest id), which loses that
/// share row and its own hide of the item; every other share row stays, so
/// each remaining profile keeps access and every dive stays linked.
/// Everything else [fromDiverId] owns is left to the caller: items shared
/// with everyone go to the default heir, private ones are deleted.
///
/// Runs inside the caller's transaction. Returns the ids handed over.
Future<({List<String> tripIds, List<String> siteIds})> handOverSharedItems(
  SyncRepository sync, {
  required String fromDiverId,
  required int now,
}) async {
  final db = DatabaseService.instance.database;
  final trips = await _handOver(
    db,
    sync,
    SharedItemKind.trip,
    fromDiverId: fromDiverId,
    now: now,
  );
  final sites = await _handOver(
    db,
    sync,
    SharedItemKind.site,
    fromDiverId: fromDiverId,
    now: now,
  );
  return (tripIds: trips, siteIds: sites);
}

Future<List<String>> _handOver(
  AppDatabase db,
  SyncRepository sync,
  SharedItemKind kind, {
  required String fromDiverId,
  required int now,
}) async {
  final (table, shares, column, entity) = switch (kind) {
    SharedItemKind.trip => ('trips', 'trip_shares', 'trip_id', 'trips'),
    SharedItemKind.site => (
      'dive_sites',
      'site_shares',
      'site_id',
      'diveSites',
    ),
  };
  // Items shared with everyone are the caller's, as are library sites,
  // which a profile delete never hands over.
  final rows = await db
      .customSelect(
        'SELECT s.$column AS item_id, s.diver_id '
        'FROM $shares s JOIN $table i ON i.id = s.$column '
        'WHERE i.diver_id = ? AND i.is_shared = 0 AND s.diver_id != ? '
        '${kind == SharedItemKind.site ? 'AND i.shared_library_id IS NULL ' : ''}'
        'ORDER BY s.created_at, s.id',
        variables: [
          Variable.withString(fromDiverId),
          Variable.withString(fromDiverId),
        ],
      )
      .get();
  // The first row per item is its oldest share.
  final heirs = <String, String>{};
  for (final r in rows) {
    heirs.putIfAbsent(
      r.read<String>('item_id'),
      () => r.read<String>('diver_id'),
    );
  }
  final shareRepo = ItemSharesRepository();
  final hides = ProfileHidesRepository();
  for (final MapEntry(key: itemId, value: heir) in heirs.entries) {
    await shareRepo.deleteShares(kind, [itemId], diverId: heir);
    await db.customUpdate(
      'UPDATE $table SET diver_id = ?, updated_at = ? WHERE id = ?',
      variables: [
        Variable.withString(heir),
        Variable.withInt(now),
        Variable.withString(itemId),
      ],
      updates: {kind == SharedItemKind.trip ? db.trips : db.diveSites},
      updateKind: UpdateKind.update,
    );
    await sync.markRecordPending(
      entityType: entity,
      recordId: itemId,
      localUpdatedAt: now,
    );
    await hides.deleteHides(kind, [itemId], diverId: heir);
  }
  return heirs.keys.toList();
}
