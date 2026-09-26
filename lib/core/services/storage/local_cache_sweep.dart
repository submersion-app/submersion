import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
import 'package:submersion/features/reef/data/repositories/reef_cache_dao.dart';

/// SharedPreferences key holding the last local cache sweep's epoch millis.
///
/// Per-device by nature, like the scratch sweep's stamp: the local cache
/// database is never synced, so what this device pruned is not news to a peer.
const String kLocalCacheSweepStampKey = 'local_cache_sweep_last_run_ms';

/// How often the sweep runs. Dead rows accumulate slowly (a bathymetry
/// generation bump ships with a release, and deletions are rare), and each
/// pass checks cached ids against the library.
const Duration kLocalCacheSweepInterval = Duration(days: 7);

/// Whether a local cache sweep is due.
///
/// A stamp more than a day in the future can only come from a broken clock,
/// and must not suppress sweeping until real time catches up: the same
/// defence as `shouldSweepScratch`. Less than that is ordinary skew.
bool shouldSweepLocalCache({
  required DateTime? lastSweptAt,
  required DateTime now,
}) {
  if (lastSweptAt == null) return true;
  if (lastSweptAt.isAfter(now.add(const Duration(days: 1)))) return true;
  return now.difference(lastSweptAt) >= kLocalCacheSweepInterval;
}

/// What one sweep pass deleted, per table.
class LocalCacheSweepReport {
  const LocalCacheSweepReport({
    required this.bathymetryRows,
    required this.trackGeometryRows,
    required this.decoRows,
    required this.assetRows,
    required this.reefRows,
    required this.vacuumed,
  });

  final int bathymetryRows;
  final int trackGeometryRows;
  final int decoRows;
  final int assetRows;
  final int reefRows;

  /// Whether the pass ran VACUUM to give freed pages back to the filesystem.
  final bool vacuumed;

  int get rowsDeleted =>
      bathymetryRows + trackGeometryRows + decoRows + assetRows + reefRows;

  @override
  String toString() =>
      'LocalCacheSweepReport(bathymetry: $bathymetryRows, '
      'trackGeometry: $trackGeometryRows, deco: $decoRows, '
      'asset: $assetRows, reef: $reefRows, vacuumed: $vacuumed)';
}

/// Deletes rows in `submersion_local.db` that nothing will read again
/// (issue #1929), then shrinks the file when that freed enough to matter.
///
/// - Bathymetry grids whose key [BathymetryRepository.keyFor] can no longer
///   build: every earlier generation, and Swiss lake rows keyed under a level
///   the lake no longer documents. These are most of the file.
/// - Track geometry, deco classifications and resolved asset ids whose track,
///   dive or media item is gone from the library. A delete made on this device
///   evicts some of them directly; a delete applied by sync, or one from a
///   path that never learned about these caches, does not.
/// - Reef rows past their lifetime, which reads ignore but never remove.
///
/// Everything here is derived data that is rebuilt on demand, so the cost of
/// a row deleted early is one recompute or refetch.
///
/// The orphan checks span two databases, so they cannot be one `DELETE ...
/// WHERE NOT IN (SELECT ...)`. Cached ids are read first and then looked up
/// in the library: a row cached after that read is never a candidate, so a
/// record created mid-sweep cannot lose its fresh cache row.
class LocalCacheSweep {
  LocalCacheSweep({
    required LocalCacheDatabase localCache,
    required AppDatabase library,
  }) : _local = localCache,
       _library = library;

  final LocalCacheDatabase _local;
  final AppDatabase _library;
  final _log = LoggerService.forClass(LocalCacheSweep);

  /// Free space worth a VACUUM. `auto_vacuum` is off, so deleted rows only
  /// move pages to the freelist and the file keeps its size. Below this a
  /// launch pays nothing; the superseded bathymetry on a typical install is
  /// well above it.
  static const int vacuumThresholdBytes = 1024 * 1024;

  /// Throws on a database failure the caller should see.
  Future<LocalCacheSweepReport> run({DateTime? now}) async {
    final bathymetryRows = await _sweepBathymetry();
    final trackGeometryRows = await _sweepOrphans(
      localTable: _local.gpsTrackGeometryCache,
      localId: _local.gpsTrackGeometryCache.trackId,
      libraryTable: _library.gpsTracks,
      libraryId: _library.gpsTracks.id,
    );
    final decoRows = await _sweepOrphans(
      localTable: _local.decoClassificationCache,
      localId: _local.decoClassificationCache.diveId,
      libraryTable: _library.dives,
      libraryId: _library.dives.id,
    );
    final assetRows = await _sweepOrphans(
      localTable: _local.localAssetCache,
      localId: _local.localAssetCache.mediaId,
      libraryTable: _library.media,
      libraryId: _library.media.id,
    );
    final at = now ?? DateTime.now();
    final reefRows = await ReefCacheDao(_local, now: () => at).deleteExpired();
    final vacuumed = await _vacuumIfWorthIt();

    final report = LocalCacheSweepReport(
      bathymetryRows: bathymetryRows,
      trackGeometryRows: trackGeometryRows,
      decoRows: decoRows,
      assetRows: assetRows,
      reefRows: reefRows,
      vacuumed: vacuumed,
    );
    if (report.rowsDeleted > 0 || vacuumed) {
      _log.info('Local cache sweep: $report');
    }
    return report;
  }

  /// Reads only the keys: the grids themselves run to 143 KB a row.
  Future<int> _sweepBathymetry() async {
    final table = _local.bathymetryCache;
    final keys = await (_local.selectOnly(
      table,
    )..addColumns([table.cacheKey])).map((r) => r.read(table.cacheKey)!).get();
    final dead = keys
        .where((key) => !BathymetryRepository.isCurrentKey(key))
        .toList();
    return _deleteWhereIn(table, table.cacheKey, dead);
  }

  Future<int> _sweepOrphans({
    required TableInfo<Table, dynamic> localTable,
    required GeneratedColumn<String> localId,
    required TableInfo<Table, dynamic> libraryTable,
    required GeneratedColumn<String> libraryId,
  }) async {
    final cached = await (_local.selectOnly(
      localTable,
      distinct: true,
    )..addColumns([localId])).map((r) => r.read(localId)!).get();
    if (cached.isEmpty) return 0;

    final live = <String>{};
    for (final chunk in seriesIdChunks(cached)) {
      final rows =
          await (_library.selectOnly(libraryTable)
                ..addColumns([libraryId])
                ..where(libraryId.isIn(chunk)))
              .map((r) => r.read(libraryId)!)
              .get();
      live.addAll(rows);
    }

    final orphans = cached.where((id) => !live.contains(id)).toList();
    return _deleteWhereIn(localTable, localId, orphans);
  }

  Future<int> _deleteWhereIn(
    TableInfo<Table, dynamic> table,
    GeneratedColumn<String> column,
    List<String> values,
  ) async {
    var deleted = 0;
    for (final chunk in seriesIdChunks(values)) {
      deleted += await (_local.delete(
        table,
      )..where((_) => column.isIn(chunk))).go();
    }
    return deleted;
  }

  /// Gated on the freelist rather than on what this pass deleted, so space
  /// freed by any other path (an evicted media cache entry, a dropped track)
  /// is reclaimed too. The #1375 design kept VACUUM off the main database
  /// because two isolates contend for its lock; this one is opened only on
  /// the main isolate and is a few megabytes, so the rewrite is brief.
  Future<bool> _vacuumIfWorthIt() async {
    final freePages = await _pragmaInt('freelist_count');
    final pageSize = await _pragmaInt('page_size');
    if (freePages * pageSize < vacuumThresholdBytes) return false;
    await _local.customStatement('VACUUM');
    return true;
  }

  Future<int> _pragmaInt(String name) async {
    final row = await _local.customSelect('PRAGMA $name').getSingle();
    return row.read<int>(name);
  }
}
