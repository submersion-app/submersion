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

  String _relativePath(
    String contentHash,
    MediaCacheKind kind, {
    String? extension,
  }) => p.join(
    switch (kind) {
      MediaCacheKind.original => 'originals',
      MediaCacheKind.thumb => 'thumbs',
      MediaCacheKind.rendition => 'renditions',
    },
    contentHash.substring(0, 2),
    extension == null || extension.isEmpty
        ? contentHash
        : '$contentHash.$extension',
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
        (row.sourceVersion == null ||
            row.sourceVersion! < freshAfter.millisecondsSinceEpoch)) {
      // Stale: the store object carries a newer version than the one we
      // cached (or we cached it before the version token was tracked).
      // Both sides are the uploading device's remoteCompressedUploadedAt
      // stamp, so this comparison is immune to local clock skew -- unlike a
      // local createdAt wall-clock, which could strand or thrash the cache.
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
  ///
  /// [sourceVersion] records the authoritative store-object version these
  /// bytes were fetched for (a rendition's synced remoteCompressedUploadedAt,
  /// epoch millis) so [get]'s freshAfter check can detect an overwrite
  /// without relying on this device's wall clock.
  ///
  /// [extension] (no leading dot) is appended to the content-addressed
  /// filename. Content addressing has no use for it, but AVFoundation does:
  /// `VideoPlayerController.file` reaches a bare `AVURLAsset`, which infers
  /// the container format from the path extension alone and fails with
  /// "Cannot Open" (-11828) on an extensionless file. Photos are unaffected
  /// because `Image.file` sniffs the bytes. Callers pass the same extension
  /// the store object was keyed with, so the cached name mirrors the remote
  /// one. Omitting it keeps the historical extensionless layout.
  Future<File> put(
    String contentHash,
    MediaCacheKind kind,
    File source, {
    int? sourceVersion,
    String? extension,
  }) async {
    final relative = _relativePath(contentHash, kind, extension: extension);
    // The index is keyed {contentHash, kind}, and relativePath used to be a
    // pure function of that key, so an overwrite always rewrote the same
    // path. Now that the caller supplies the extension, two rows over
    // identical bytes can ask for different names (extensionFor is not
    // injective over content, and a video's name can fall back to its local
    // path). Note the superseded path before insertOnConflictUpdate forgets
    // it: nothing would reference that file afterwards, and eviction only
    // walks the index, so it would occupy disk forever without counting
    // against any cap.
    final superseded = await _relativePathOf(contentHash, kind);
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
            sourceVersion: Value(sourceVersion),
          ),
        );
    if (superseded != null && superseded != relative) {
      await _bestEffortDelete(File(p.join(_root.path, superseded)));
    }
    await evictIfNeeded();
    return dest;
  }

  /// The path currently indexed for [contentHash]/[kind], or null when there
  /// is no entry.
  Future<String?> _relativePathOf(
    String contentHash,
    MediaCacheKind kind,
  ) async {
    final row =
        await (_db.select(_db.mediaCacheEntries)..where(
              (t) =>
                  t.contentHash.equals(contentHash) &
                  t.kind.equals(_kindName(kind)),
            ))
            .getSingleOrNull();
    return row?.relativePath;
  }

  /// Removing a superseded file is housekeeping: the new copy is already in
  /// place and indexed, so a failure here must not turn a good put into an
  /// error.
  Future<void> _bestEffortDelete(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Leaves one stale file behind; the next put for this key retries.
    }
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

  /// Deterministic transcode output path (spec section 8):
  /// `<root>/transcode/<hash>_<level>.mp4`. Engines write `<path>.tmp` and
  /// rename, so an existing file here is always a COMPLETE rendition; it
  /// survives upload retries and app restarts and is removed only via
  /// [deleteTranscodeArtifacts] on markDone.
  Future<File> transcodeFile(String contentHash, String levelName) async {
    final dir = Directory(p.join(_root.path, 'transcode'));
    await dir.create(recursive: true);
    return File(p.join(dir.path, '${contentHash}_$levelName.mp4'));
  }

  /// Removes every transcode artifact for [contentHash]: all levels'
  /// renditions plus any .tmp debris. Best-effort.
  Future<void> deleteTranscodeArtifacts(String contentHash) async {
    final dir = Directory(p.join(_root.path, 'transcode'));
    try {
      if (!await dir.exists()) return;
      await for (final entity in dir.list()) {
        if (entity is File &&
            p.basename(entity.path).startsWith('${contentHash}_')) {
          try {
            await entity.delete();
          } on FileSystemException {
            // A single locked/vanished file must not abort the sweep.
          }
        }
      }
    } on FileSystemException {
      // exists()/list() can race with other writers or hit a permission
      // error; this cleanup is best-effort and must never surface (it now
      // runs after markDone, where throwing would flip a committed upload).
    }
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
