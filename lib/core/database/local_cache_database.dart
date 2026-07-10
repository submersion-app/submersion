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
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
}

/// Per-device index of content-addressed cache files (media store Phase 1).
class MediaCacheEntries extends Table {
  TextColumn get contentHash => text()();
  TextColumn get kind => text()(); // 'original' | 'thumb'
  TextColumn get relativePath => text()();
  IntColumn get sizeBytes => integer()();
  IntColumn get lastAccessedAt => integer()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {contentHash, kind};
}

@DriftDatabase(tables: [LocalAssetCache, MediaTransferQueue, MediaCacheEntries])
class LocalCacheDatabase extends _$LocalCacheDatabase {
  LocalCacheDatabase(super.e);

  @override
  int get schemaVersion => 3;

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
    },
  );
}
