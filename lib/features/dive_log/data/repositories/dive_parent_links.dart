import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';

/// `dives.site_id` and `dives.dive_center_id` reference `dive_sites` and
/// `dive_centers` with no ON DELETE action. Under `PRAGMA foreign_keys = ON`
/// a dive logged at a site or with a center fails that site's or center's
/// delete with SqliteException(787), so the deletes clear the links first
/// and the dives survive without them.

/// Clears the site of the dives logged at [siteIds], stamping and marking
/// each dive so the change reaches peers. Run it inside the caller's
/// transaction, before the sites are deleted.
Future<void> clearDiveSiteLinks(
  AppDatabase db,
  SyncRepository syncRepository,
  List<String> siteIds, {
  required int now,
}) => _clearDiveLinks(db, syncRepository, 'site_id', siteIds, now: now);

/// Clears the dive center of the dives logged with [centerIds], stamping and
/// marking each dive so the change reaches peers. Run it inside the caller's
/// transaction, before the centers are deleted.
Future<void> clearDiveCenterLinks(
  AppDatabase db,
  SyncRepository syncRepository,
  List<String> centerIds, {
  required int now,
}) =>
    _clearDiveLinks(db, syncRepository, 'dive_center_id', centerIds, now: now);

/// Sets [column] to NULL on the dives whose [column] is in [ids]. [column]
/// is one of the constants above, never caller input.
Future<void> _clearDiveLinks(
  AppDatabase db,
  SyncRepository syncRepository,
  String column,
  List<String> ids, {
  required int now,
}) async {
  if (ids.isEmpty) return;
  final where = '$column IN (${List.filled(ids.length, '?').join(', ')})';
  final rows = await db
      .customSelect(
        // stats-scope-exempt: deletion cleanup, excluded dives included.
        'SELECT id FROM dives WHERE $where',
        variables: [for (final id in ids) Variable.withString(id)],
      )
      .get();
  if (rows.isEmpty) return;
  // customUpdate, not customStatement: naming the table is what tells the
  // dive lists (which watch `dives`) to refresh.
  await db.customUpdate(
    'UPDATE dives SET $column = NULL, updated_at = ? WHERE $where',
    variables: [
      Variable.withInt(now),
      for (final id in ids) Variable.withString(id),
    ],
    updates: {db.dives},
  );
  for (final row in rows) {
    await syncRepository.markRecordPending(
      entityType: 'dives',
      recordId: row.read<String>('id'),
      localUpdatedAt: now,
    );
  }
}
