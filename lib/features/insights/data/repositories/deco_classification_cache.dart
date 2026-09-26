import 'package:drift/drift.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';

/// Read and write access to the memoized computed deco classifications (#623).
///
/// Entries are only valid for the `inputsHash` they were written under, so a
/// changed profile, a changed gradient factor, or a bumped analysis engine
/// invalidates them without needing an explicit purge.
class DecoClassificationCacheRepository {
  DecoClassificationCacheRepository({LocalCacheDatabase? database})
    : _database = database;

  final LocalCacheDatabase? _database;

  LocalCacheDatabase get _db =>
      _database ?? LocalCacheDatabaseService.instance.database;

  /// Every stored entry for [diveIds], keyed by dive id, in a single query.
  ///
  /// Deliberately returns the stored `inputsHash` rather than filtering on it
  /// in SQL: each dive has its own fingerprint (their `updated_at` differ), so
  /// a hash-filtered query would need one round trip per dive. The caller
  /// compares hashes in Dart, which keeps this to one round trip for the whole
  /// batch and leaves the staleness policy in one place.
  /// Ids are queried in chunks so the bound-variable count never exceeds
  /// SQLite's limit, matching `SpeciesRepository.getSightingsForDives`.
  ///
  /// Measured against the engine this app actually bundles, the ceiling is
  /// 32766 (the SQLite 3.32+ default), not the 999 that older references and
  /// the sibling repository's comment cite: an unchunked query survives 2500
  /// ids and throws "too many SQL variables" at 33000. The chunk size stays at
  /// 900 for consistency with that sibling rather than for necessity.
  ///
  /// Overrunning the limit would not surface as a visible failure here: the
  /// caller catches a cache read error and falls back to recomputing every
  /// dive, so the cache would quietly stop working for exactly the libraries
  /// that need it most.
  Future<Map<String, ({bool hadDeco, String inputsHash})>> getEntries(
    Set<String> diveIds,
  ) async {
    if (diveIds.isEmpty) return const {};

    const chunkSize = 900; // safely under SQLite's 999 bound-variable limit
    final ids = diveIds.toList(growable: false);
    final entries = <String, ({bool hadDeco, String inputsHash})>{};

    for (var start = 0; start < ids.length; start += chunkSize) {
      final end = start + chunkSize < ids.length
          ? start + chunkSize
          : ids.length;
      final rows = await (_db.select(
        _db.decoClassificationCache,
      )..where((t) => t.diveId.isIn(ids.sublist(start, end)))).get();
      for (final row in rows) {
        entries[row.diveId] = (
          hadDeco: row.hadDeco,
          inputsHash: row.inputsHash,
        );
      }
    }
    return entries;
  }

  Future<void> put(
    String diveId, {
    required bool hadDeco,
    required String inputsHash,
  }) async {
    await _db
        .into(_db.decoClassificationCache)
        .insertOnConflictUpdate(
          DecoClassificationCacheCompanion(
            diveId: Value(diveId),
            hadDeco: Value(hadDeco),
            inputsHash: Value(inputsHash),
            computedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
  }

  Future<void> clear() async {
    await _db.delete(_db.decoClassificationCache).go();
  }
}
