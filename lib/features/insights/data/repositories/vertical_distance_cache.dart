import 'package:drift/drift.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';

/// One dive's cached figure and the fingerprint it was worked out under.
typedef VerticalDistanceCacheEntry = ({double meters, String inputsHash});

/// Read and write access to each dive's cached vertical distance (issue
/// #4569), modelled on `DecoClassificationCacheRepository`.
///
/// An entry is valid only for the `inputsHash` it was written under, so a
/// changed profile or a bumped algorithm invalidates it with no purge. The
/// staleness check is the caller's: this returns the stored hash rather than
/// filtering on it, so a whole library is one round trip per chunk.
class VerticalDistanceCacheRepository {
  VerticalDistanceCacheRepository({LocalCacheDatabase? database})
    : _database = database;

  final LocalCacheDatabase? _database;

  LocalCacheDatabase get _db =>
      _database ?? LocalCacheDatabaseService.instance.database;

  /// Every stored entry for [diveIds], keyed by dive id. Ids are queried in
  /// chunks so the bound-variable count stays under SQLite's limit.
  Future<Map<String, VerticalDistanceCacheEntry>> getEntries(
    Set<String> diveIds,
  ) async {
    if (diveIds.isEmpty) return const {};
    final entries = <String, VerticalDistanceCacheEntry>{};
    for (final chunk in seriesIdChunks(diveIds.toList(growable: false))) {
      final rows = await (_db.select(
        _db.diveVerticalDistanceCache,
      )..where((t) => t.diveId.isIn(chunk))).get();
      for (final row in rows) {
        entries[row.diveId] = (meters: row.meters, inputsHash: row.inputsHash);
      }
    }
    return entries;
  }

  /// Writes every entry in one batch, replacing any row for the same dive.
  Future<void> putAll(Map<String, VerticalDistanceCacheEntry> entries) async {
    if (entries.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.batch((b) {
      for (final MapEntry(key: diveId, value: e) in entries.entries) {
        b.insert(
          _db.diveVerticalDistanceCache,
          DiveVerticalDistanceCacheCompanion.insert(
            diveId: diveId,
            meters: e.meters,
            inputsHash: e.inputsHash,
            computedAt: now,
          ),
          onConflict: DoUpdate(
            (_) => DiveVerticalDistanceCacheCompanion(
              meters: Value(e.meters),
              inputsHash: Value(e.inputsHash),
              computedAt: Value(now),
            ),
          ),
        );
      }
    });
  }

  Future<void> clear() async {
    await _db.delete(_db.diveVerticalDistanceCache).go();
  }
}
