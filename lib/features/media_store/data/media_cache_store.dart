import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/database/local_cache_database.dart';

enum MediaCacheKind { original, thumb, rendition }

/// Content-addressed local cache for store-fetched media (spec section 10).
/// Files live under [root]; bookkeeping lives in media_cache_entries.
/// Two pools with independent caps so bulk original downloads can never
/// evict the thumbnails that keep grids rendering.
class MediaCacheStore {
  MediaCacheStore({
    required LocalCacheDatabase database,
    required Directory root,
    this.originalsCapBytes = 2 * 1024 * 1024 * 1024,
    this.thumbsCapBytes = 256 * 1024 * 1024,
    this.renditionsCapBytes = 1 * 1024 * 1024 * 1024,
  }) : _db = database,
       _root = root;

  final LocalCacheDatabase _db;
  final Directory _root;
  final int originalsCapBytes;
  final int thumbsCapBytes;
  final int renditionsCapBytes;

  int _stagingCounter = 0;

  String _kindName(MediaCacheKind kind) => switch (kind) {
    MediaCacheKind.original => 'original',
    MediaCacheKind.thumb => 'thumb',
    MediaCacheKind.rendition => 'rendition',
  };

  String _relativePath(String contentHash, MediaCacheKind kind) => p.join(
    switch (kind) {
      MediaCacheKind.original => 'originals',
      MediaCacheKind.thumb => 'thumbs',
      MediaCacheKind.rendition => 'renditions',
    },
    contentHash.substring(0, 2),
    contentHash,
  );

  /// Cached file for [contentHash], or null on a miss. A hit refreshes the
  /// LRU timestamp; a dangling index row (file deleted externally) is
  /// removed and reported as a miss.
  Future<File?> get(
    String contentHash,
    MediaCacheKind kind, {
    DateTime? freshAfter,
  }) async {
    final row =
        await (_db.select(_db.mediaCacheEntries)..where(
              (t) =>
                  t.contentHash.equals(contentHash) &
                  t.kind.equals(_kindName(kind)),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    if (freshAfter != null &&
        row.createdAt < freshAfter.millisecondsSinceEpoch) {
      // Stale: the store object was overwritten after we cached it.
      final stale = File(p.join(_root.path, row.relativePath));
      if (await stale.exists()) await stale.delete();
      await _deleteEntry(contentHash, kind);
      return null;
    }
    final file = File(p.join(_root.path, row.relativePath));
    if (!await file.exists()) {
      await _deleteEntry(contentHash, kind);
      return null;
    }
    await (_db.update(_db.mediaCacheEntries)..where(
          (t) =>
              t.contentHash.equals(contentHash) &
              t.kind.equals(_kindName(kind)),
        ))
        .write(
          MediaCacheEntriesCompanion(
            lastAccessedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
    return file;
  }

  /// Moves [source] into the cache under [contentHash] and indexes it.
  Future<File> put(String contentHash, MediaCacheKind kind, File source) async {
    final relative = _relativePath(contentHash, kind);
    final dest = File(p.join(_root.path, relative));
    await dest.parent.create(recursive: true);
    try {
      await source.rename(dest.path);
    } on FileSystemException {
      // Cross-device rename fallback.
      await source.copy(dest.path);
      await source.delete();
    }
    final size = await dest.length();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.mediaCacheEntries)
        .insertOnConflictUpdate(
          MediaCacheEntriesCompanion.insert(
            contentHash: contentHash,
            kind: _kindName(kind),
            relativePath: relative,
            sizeBytes: size,
            lastAccessedAt: now,
            createdAt: now,
          ),
        );
    await evictIfNeeded();
    return dest;
  }

  /// A unique temp file under the cache root, for downloads and pipeline
  /// staging. Same volume as the cache, so put() can use a cheap rename.
  Future<File> stagingFile() async {
    final dir = Directory(p.join(_root.path, 'staging'));
    await dir.create(recursive: true);
    _stagingCounter += 1;
    return File(
      p.join(
        dir.path,
        'stage_${DateTime.now().microsecondsSinceEpoch}_$_stagingCounter',
      ),
    );
  }

  Future<int> totalBytes(MediaCacheKind kind) async {
    final sum = _db.mediaCacheEntries.sizeBytes.sum();
    final query = _db.selectOnly(_db.mediaCacheEntries)
      ..addColumns([sum])
      ..where(_db.mediaCacheEntries.kind.equals(_kindName(kind)));
    final row = await query.getSingle();
    return row.read(sum) ?? 0;
  }

  Future<void> evictIfNeeded() async {
    await _evictPool(MediaCacheKind.original, originalsCapBytes);
    await _evictPool(MediaCacheKind.thumb, thumbsCapBytes);
    await _evictPool(MediaCacheKind.rendition, renditionsCapBytes);
  }

  Future<void> _evictPool(MediaCacheKind kind, int capBytes) async {
    var total = await totalBytes(kind);
    if (total <= capBytes) return;
    final rows =
        await (_db.select(_db.mediaCacheEntries)
              ..where((t) => t.kind.equals(_kindName(kind)))
              ..orderBy([(t) => OrderingTerm.asc(t.lastAccessedAt)]))
            .get();
    for (final row in rows) {
      if (total <= capBytes) break;
      final file = File(p.join(_root.path, row.relativePath));
      if (await file.exists()) await file.delete();
      await _deleteEntry(row.contentHash, kind);
      total -= row.sizeBytes;
    }
  }

  Future<void> _deleteEntry(String contentHash, MediaCacheKind kind) async {
    await (_db.delete(_db.mediaCacheEntries)..where(
          (t) =>
              t.contentHash.equals(contentHash) &
              t.kind.equals(_kindName(kind)),
        ))
        .go();
  }
}
