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

@DriftDatabase(tables: [LocalAssetCache, MediaTransferQueue, MediaCacheEntries])
class LocalCacheDatabase extends _$LocalCacheDatabase {
  LocalCacheDatabase(super.e);

  @override
  int get schemaVersion => 5;

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
    },
  );
}
