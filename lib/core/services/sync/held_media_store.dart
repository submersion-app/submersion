import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';

/// The media rows this device holds back from older devices (issue #5122):
/// kept with no dive, site or gear while a device in the library would
/// delete them. Device-local; see [HeldMedia].
class HeldMediaStore {
  HeldMediaStore({AppDatabase? database}) : _database = database;

  final AppDatabase? _database;

  AppDatabase get _db => _database ?? DatabaseService.instance.database;

  /// Every media id held back.
  Future<Set<String>> heldIds() async {
    final rows = await _db.select(_db.heldMedia).get();
    return {for (final row in rows) row.mediaId};
  }

  /// Whether [mediaId] is held back.
  Future<bool> isHeld(String mediaId) async {
    final row = await (_db.select(
      _db.heldMedia,
    )..where((t) => t.mediaId.equals(mediaId))).getSingleOrNull();
    return row != null;
  }

  /// Records [mediaIds] as held back. An id already held keeps the time it
  /// was first held.
  Future<void> hold(Iterable<String> mediaIds, {required DateTime at}) async {
    final ids = mediaIds.toSet();
    if (ids.isEmpty) return;
    await _db.batch((batch) {
      batch.insertAll(_db.heldMedia, [
        for (final id in ids)
          HeldMediaCompanion.insert(
            mediaId: id,
            heldAt: at.millisecondsSinceEpoch,
          ),
      ], mode: InsertMode.insertOrIgnore);
    });
  }

  /// Forgets [mediaIds]: released, or gone.
  Future<void> release(Iterable<String> mediaIds) async {
    final ids = mediaIds.toSet();
    if (ids.isEmpty) return;
    await (_db.delete(_db.heldMedia)..where((t) => t.mediaId.isIn(ids))).go();
  }
}
