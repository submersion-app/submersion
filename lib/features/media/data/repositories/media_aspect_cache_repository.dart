import 'package:drift/drift.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/media/domain/value_objects/learned_aspect.dart';

/// Read and write access to the learned shapes of library thumbnails (issue
/// #4738), kept in the local cache database.
///
/// Whether an entry still applies to its item is the caller's check
/// (`learnedAspectApplies`): this stores what it is given and returns
/// everything, since the library reads the whole map once per session.
class MediaAspectCacheRepository {
  MediaAspectCacheRepository({LocalCacheDatabase? database})
    : _database = database;

  final LocalCacheDatabase? _database;

  LocalCacheDatabase get _db =>
      _database ?? LocalCacheDatabaseService.instance.database;

  /// Every learned shape, keyed by media id.
  Future<Map<String, LearnedAspect>> loadAll() async {
    final rows = await _db.select(_db.mediaAspectCache).get();
    return {
      for (final row in rows)
        row.mediaId: (ratio: row.ratio, width: row.width, height: row.height),
    };
  }

  /// Writes every entry in one batch, replacing any row for the same item.
  Future<void> putAll(Map<String, LearnedAspect> entries) async {
    if (entries.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.batch((b) {
      for (final MapEntry(key: mediaId, value: e) in entries.entries) {
        b.insert(
          _db.mediaAspectCache,
          MediaAspectCacheCompanion.insert(
            mediaId: mediaId,
            ratio: e.ratio,
            width: Value(e.width),
            height: Value(e.height),
            learnedAt: now,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }
}
