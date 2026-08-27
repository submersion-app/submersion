import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';

/// How many values may ride in one `IN (...)`. SQLite's bound-variable
/// ceiling is ~999 on the most restrictive builds; the sync serializer uses
/// the same margin.
const int _sqlVariableChunk = 900;

/// One indexed file under a watched root.
class IndexedFile {
  const IndexedFile({
    required this.rootPath,
    required this.relativePath,
    required this.sizeBytes,
    required this.mtimeMillis,
    this.contentHash,
  });

  final String rootPath;
  final String relativePath;
  final int sizeBytes;
  final int mtimeMillis;
  final String? contentHash;
}

/// Per-device watcher state (Media section Phase 5): which folders to scan
/// and what was found in them last time.
///
/// Lives in the local cache database because every value here is derivable
/// from the filesystem in front of this device -- syncing a path from
/// another machine would only produce warnings about roots that do not
/// exist here.
class WatchedFolderRepository {
  WatchedFolderRepository({LocalCacheDatabase? database})
    : _database = database;

  final LocalCacheDatabase? _database;

  LocalCacheDatabase get _db =>
      _database ?? LocalCacheDatabaseService.instance.database;

  Future<List<String>> getRoots() async {
    final rows = await (_db.select(
      _db.watchedRoots,
    )..orderBy([(t) => OrderingTerm.asc(t.path)])).get();
    return [for (final row in rows) row.path];
  }

  Future<void> addRoot(String path) async {
    await _db
        .into(_db.watchedRoots)
        .insertOnConflictUpdate(
          WatchedRootsCompanion(
            path: Value(path),
            addedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
  }

  /// Drops the root and everything indexed beneath it -- a root the user
  /// removed must not keep feeding the auto-repair pass.
  Future<void> removeRoot(String path) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.watchedRoots,
      )..where((t) => t.path.equals(path))).go();
      await (_db.delete(
        _db.watchedFolderIndex,
      )..where((t) => t.rootPath.equals(path))).go();
    });
  }

  Future<DateTime?> lastScanAt(String rootPath) async {
    final row = await (_db.select(
      _db.watchedRoots,
    )..where((t) => t.path.equals(rootPath))).getSingleOrNull();
    final stamp = row?.lastScanAt;
    return stamp == null ? null : DateTime.fromMillisecondsSinceEpoch(stamp);
  }

  Future<void> stampScanned(String rootPath, DateTime at) async {
    await (_db.update(
      _db.watchedRoots,
    )..where((t) => t.path.equals(rootPath))).write(
      WatchedRootsCompanion(lastScanAt: Value(at.millisecondsSinceEpoch)),
    );
  }

  /// Everything indexed under [rootPath], keyed by relative path.
  Future<Map<String, IndexedFile>> indexForRoot(String rootPath) async {
    final rows = await (_db.select(
      _db.watchedFolderIndex,
    )..where((t) => t.rootPath.equals(rootPath))).get();
    return {
      for (final row in rows)
        row.relativePath: IndexedFile(
          rootPath: row.rootPath,
          relativePath: row.relativePath,
          sizeBytes: row.sizeBytes,
          mtimeMillis: row.mtimeMillis,
          contentHash: row.contentHash,
        ),
    };
  }

  Future<void> upsertIndexed(IndexedFile file) async {
    await _db
        .into(_db.watchedFolderIndex)
        .insertOnConflictUpdate(
          WatchedFolderIndexCompanion(
            rootPath: Value(file.rootPath),
            relativePath: Value(file.relativePath),
            sizeBytes: Value(file.sizeBytes),
            mtimeMillis: Value(file.mtimeMillis),
            contentHash: Value(file.contentHash),
          ),
        );
  }

  /// Drops the named index rows under [rootPath] -- the files the scanner
  /// did not see this pass.
  ///
  /// Chunked because every value becomes a bound SQL variable and a watched
  /// photo archive routinely holds more paths than SQLite will accept in one
  /// statement.
  Future<void> deleteIndexed(
    String rootPath,
    Iterable<String> relativePaths,
  ) async {
    final all = relativePaths.toList();
    for (var start = 0; start < all.length; start += _sqlVariableChunk) {
      final end = start + _sqlVariableChunk;
      final chunk = all.sublist(start, end > all.length ? all.length : end);
      await (_db.delete(_db.watchedFolderIndex)..where(
            (t) => t.rootPath.equals(rootPath) & t.relativePath.isIn(chunk),
          ))
          .go();
    }
  }

  /// Absolute path for each of [hashes] found under any watched root -- the
  /// lookup the auto-repair pass runs against missing rows.
  ///
  /// Takes the hashes it wants rather than returning the whole index, so the
  /// result is bounded by the number of missing rows rather than by the size
  /// of the watched archive.
  Future<Map<String, String>> pathsForHashes(Iterable<String> hashes) async {
    final all = hashes.toList();
    final result = <String, String>{};
    for (var start = 0; start < all.length; start += _sqlVariableChunk) {
      final end = start + _sqlVariableChunk;
      final chunk = all.sublist(start, end > all.length ? all.length : end);
      final rows = await (_db.select(
        _db.watchedFolderIndex,
      )..where((t) => t.contentHash.isIn(chunk))).get();
      for (final row in rows) {
        result[row.contentHash!] = p.join(row.rootPath, row.relativePath);
      }
    }
    return result;
  }
}
