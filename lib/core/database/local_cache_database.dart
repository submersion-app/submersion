import 'package:drift/drift.dart';

part 'local_cache_database.g.dart';

/// Local-only table for caching resolved asset IDs per device.
/// This table is NOT synced — it lives in a separate database file.
class LocalAssetCache extends Table {
  TextColumn get mediaId => text()();
  TextColumn get localAssetId => text().nullable()();
  IntColumn get resolvedAt => integer()();
  TextColumn get resolutionMethod => text()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {mediaId};
}

/// Per-device media transfer queue (media store Phase 1). Never synced,
/// never backed up: a restored database must not carry another device's
/// in-flight transfers.
class MediaTransferQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get mediaId => text()();
  TextColumn get direction => text().withDefault(const Constant('upload'))();
  TextColumn get objectKind => text().withDefault(const Constant('original'))();
  TextColumn get contentHash => text().nullable()();
  TextColumn get state => text().withDefault(const Constant('pending'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get nextAttemptAt => integer().nullable()();
  TextColumn get resumeStateJson => text().nullable()();
  TextColumn get errorMessage => text().nullable()();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  // Transfer progress (v3), surfaced in the Transfers view.
  IntColumn get progressBytes => integer().nullable()();
  IntColumn get totalBytes => integer().nullable()();
  // Adjustable upload quality: a per-item re-upload override level (v4).
  TextColumn get overrideLevel => text().nullable()();
  // Operation payload for non-upload directions (v6). For 'delete' entries:
  // {"originalExt": ..., "renditionExt": ...} -- the two facts that cannot
  // be recovered once the media row is gone.
  TextColumn get payloadJson => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
}

/// Per-device index of content-addressed cache files (media store Phase 1).
class MediaCacheEntries extends Table {
  TextColumn get contentHash => text()();
  TextColumn get kind => text()(); // 'original' | 'thumb' | 'rendition'
  TextColumn get relativePath => text()();
  IntColumn get sizeBytes => integer()();
  IntColumn get lastAccessedAt => integer()();
  IntColumn get createdAt => integer()();
  // The authoritative store-object version this copy was fetched for, as
  // epoch millis (a rendition's synced remoteCompressedUploadedAt). Freshness
  // compares this against the item's current stamp -- both the uploading
  // device's clock -- so device clock skew cannot strand or thrash the cache.
  // Null for kinds that are not version-checked (original/thumb) and for
  // rendition entries cached before v5 (treated as stale on the next read).
  IntColumn get sourceVersion => integer().nullable()();

  @override
  Set<Column> get primaryKey => {contentHash, kind};
}

/// Cached bathymetry grids keyed by quantized coordinate (0.02 degree
/// cells). Re-derivable third-party data: never synced, never backed up.
/// status semantics: 'ok' = usable grid in gridJson; 'empty' = fetched
/// fine, definitively no water here; 'unavailable' = reserved for future
/// definitive negatives. Transient failures write NO row.
class BathymetryCache extends Table {
  TextColumn get cacheKey => text()();
  RealColumn get centerLat => real()();
  RealColumn get centerLon => real()();
  TextColumn get status => text()();
  TextColumn get sourceId => text().nullable()();
  RealColumn get resolutionMeters => real().nullable()();
  TextColumn get gridJson => text().nullable()();
  IntColumn get fetchedAt => integer()();

  @override
  Set<Column> get primaryKey => {cacheKey};
}

/// Cached third-party reef data, keyed by quantized coordinate. Never synced
/// and never backed up: any device can re-derive this from a site's
/// coordinates, so a restored database re-fetches rather than carrying
/// another device's stale results.
class ReefDataCache extends Table {
  /// A `ReefProviderId.name`.
  TextColumn get provider => text()();

  /// `ReefCoordinateKey.format` output, e.g. "12.160,-68.280".
  TextColumn get coordKey => text()();

  /// Dive date as `yyyy-MM-dd` for historical reef health; empty otherwise.
  TextColumn get variant => text().withDefault(const Constant(''))();

  /// Provider-specific JSON. Empty object when status is not `ok`.
  TextColumn get payloadJson => text()();

  /// A `ReefDataStatus.name`.
  TextColumn get status => text()();

  IntColumn get fetchedAt => integer()();

  @override
  Set<Column> get primaryKey => {provider, coordKey, variant};
}

/// Folders the repair watcher scans (Media section Phase 5). Per-device by
/// construction: a path from another machine is meaningless here, and a
/// cache wipe costs a re-add, never user data.
class WatchedRoots extends Table {
  TextColumn get path => text()();
  IntColumn get addedAt => integer()();
  IntColumn get lastScanAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {path};
}

/// The watcher's file index (Media section Phase 5). Size and mtime are the
/// change detector: a rescan re-hashes only files whose stat differs, so a
/// NAS full of unchanged photos costs one stat each instead of one full
/// read each.
class WatchedFolderIndex extends Table {
  TextColumn get rootPath => text()();
  TextColumn get relativePath => text()();
  IntColumn get sizeBytes => integer()();
  IntColumn get mtimeMillis => integer()();

  /// Null until first hashed.
  TextColumn get contentHash => text().nullable()();

  @override
  Set<Column> get primaryKey => {rootPath, relativePath};
}

@DriftDatabase(
  tables: [
    LocalAssetCache,
    MediaTransferQueue,
    MediaCacheEntries,
    BathymetryCache,
    ReefDataCache,
    WatchedRoots,
    WatchedFolderIndex,
  ],
)
class LocalCacheDatabase extends _$LocalCacheDatabase {
  LocalCacheDatabase(super.e);

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Creates the tables with the CURRENT schema, columns included.
        await m.createTable(mediaTransferQueue);
        await m.createTable(mediaCacheEntries);
      }
      if (from >= 2 && from < 3) {
        await m.addColumn(mediaTransferQueue, mediaTransferQueue.progressBytes);
        await m.addColumn(mediaTransferQueue, mediaTransferQueue.totalBytes);
      }
      // Only v2/v3 stored schemas lack this column; a v1 upgrade already
      // created the table with the full current schema above.
      if (from >= 2 && from < 4) {
        await m.addColumn(mediaTransferQueue, mediaTransferQueue.overrideLevel);
      }
      // v5: rendition cache freshness token. Only v2..v4 stored schemas lack
      // it; the v1 create path above already includes the current schema.
      if (from >= 2 && from < 5) {
        await m.addColumn(mediaCacheEntries, mediaCacheEntries.sourceVersion);
      }
      // v6: delete-intent payload. Only v2..v5 stored schemas lack it; the
      // v1 create path above already includes the current schema.
      if (from >= 2 && from < 6) {
        await m.addColumn(mediaTransferQueue, mediaTransferQueue.payloadJson);
      }
      // v7: bathymetry grid cache. from < 7 covers both the v1 path and
      // v2..v6 upgrades.
      if (from < 7) {
        await m.createTable(bathymetryCache);
      }
      // v8: reef data cache. Renumbered from v7 at merge time because the
      // bathymetry branch claimed v7 first. Every stored schema below 8
      // lacks this table, including v1, because the from<2 branch above
      // predates it. Drift's createTable is CREATE TABLE IF NOT EXISTS, so
      // a dev DB that already ran the reef branch at v7 upgrades cleanly.
      if (from < 8) {
        await m.createTable(reefDataCache);
      }
      // v9: repair watcher state (Media section Phase 5).
      if (from < 9) {
        await m.createTable(watchedRoots);
        await m.createTable(watchedFolderIndex);
      }
    },
    beforeOpen: (details) async {
      // Ladder-collision self-heal: a parallel branch that also claimed v7
      // may have stamped user_version first on a shared dev machine, so
      // onUpgrade never runs here and a table would be missing. Idempotent
      // re-assert, mirroring the main DB's pattern. Keep the column shapes
      // in sync with the BathymetryCache and ReefDataCache tables.
      await customStatement('''
        CREATE TABLE IF NOT EXISTS bathymetry_cache (
          cache_key TEXT NOT NULL,
          center_lat REAL NOT NULL,
          center_lon REAL NOT NULL,
          status TEXT NOT NULL,
          source_id TEXT NULL,
          resolution_meters REAL NULL,
          grid_json TEXT NULL,
          fetched_at INTEGER NOT NULL,
          PRIMARY KEY (cache_key)
        )
      ''');
      await customStatement('''
        CREATE TABLE IF NOT EXISTS reef_data_cache (
          provider TEXT NOT NULL,
          coord_key TEXT NOT NULL,
          variant TEXT NOT NULL DEFAULT '',
          payload_json TEXT NOT NULL,
          status TEXT NOT NULL,
          fetched_at INTEGER NOT NULL,
          PRIMARY KEY (provider, coord_key, variant)
        )
      ''');
      await customStatement('''
        CREATE TABLE IF NOT EXISTS watched_roots (
          path TEXT NOT NULL,
          added_at INTEGER NOT NULL,
          last_scan_at INTEGER,
          PRIMARY KEY (path)
        )
      ''');
      await customStatement('''
        CREATE TABLE IF NOT EXISTS watched_folder_index (
          root_path TEXT NOT NULL,
          relative_path TEXT NOT NULL,
          size_bytes INTEGER NOT NULL,
          mtime_millis INTEGER NOT NULL,
          content_hash TEXT,
          PRIMARY KEY (root_path, relative_path)
        )
      ''');
    },
  );
}
