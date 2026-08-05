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

@DriftDatabase(
  tables: [
    LocalAssetCache,
    MediaTransferQueue,
    MediaCacheEntries,
    BathymetryCache,
  ],
)
class LocalCacheDatabase extends _$LocalCacheDatabase {
  LocalCacheDatabase(super.e);

  @override
  int get schemaVersion => 7;

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
      // v7: bathymetry grid cache. NOTE: the reef-data branch (PR #728)
      // also claims v7 on its own branch — whichever merges second
      // renumbers. from < 7 covers both the v1 path and v2..v6 upgrades.
      if (from < 7) {
        await m.createTable(bathymetryCache);
      }
    },
    beforeOpen: (details) async {
      // Ladder-collision self-heal: a parallel branch that also claims v7
      // (e.g. reef data) may have stamped user_version first on a shared
      // dev machine, so onUpgrade never runs here and this table would be
      // missing. Idempotent re-assert, mirroring the main DB's pattern.
      // Keep the column shape in sync with the BathymetryCache table.
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
    },
  );
}
