import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';

void main() {
  test('fresh database exposes bathymetry_cache', () async {
    final db = LocalCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // v7 introduced bathymetry_cache; later branches may bump further.
    expect(db.schemaVersion, greaterThanOrEqualTo(7));
    await db
        .into(db.bathymetryCache)
        .insert(
          BathymetryCacheCompanion.insert(
            cacheKey: '12.16,-68.30',
            centerLat: 12.17,
            centerLon: -68.29,
            status: 'ok',
            sourceId: const Value('gmrt'),
            resolutionMeters: const Value(61.0),
            gridJson: const Value('{}'),
            fetchedAt: 1753600000000,
          ),
        );
    final rows = await db.select(db.bathymetryCache).get();
    expect(rows.single.status, 'ok');
    expect(rows.single.sourceId, 'gmrt');
  });

  test('upgrade from a stored v6 schema creates bathymetry_cache', () async {
    final db = LocalCacheDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          // Minimal v6 shape: the migration only creates the new table, so
          // the pre-existing tables need to exist, not be column-perfect.
          raw
            ..execute(
              'CREATE TABLE local_asset_cache '
              '(media_id TEXT PRIMARY KEY, local_asset_id TEXT, '
              'resolved_at INTEGER, resolution_method TEXT, '
              'attempt_count INTEGER)',
            )
            ..execute(
              'CREATE TABLE media_transfer_queue '
              '(id INTEGER PRIMARY KEY AUTOINCREMENT, media_id TEXT)',
            )
            ..execute(
              'CREATE TABLE media_cache_entries '
              '(content_hash TEXT, kind TEXT, '
              'PRIMARY KEY (content_hash, kind))',
            )
            ..execute('PRAGMA user_version = 6');
        },
      ),
    );
    addTearDown(db.close);
    // Any query forces open + migration.
    final rows = await db.select(db.bathymetryCache).get();
    expect(rows, isEmpty);
  });

  test(
    'self-heals a v7 database stamped by a parallel branch (reef shape)',
    () async {
      // Reproduces the runtime ladder collision: another branch already
      // bumped user_version to 7 with ITS table, so onUpgrade never runs
      // here and bathymetry_cache would not exist without the beforeOpen
      // re-assert.
      final db = LocalCacheDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw
              ..execute(
                'CREATE TABLE local_asset_cache '
                '(media_id TEXT PRIMARY KEY, local_asset_id TEXT, '
                'resolved_at INTEGER, resolution_method TEXT, '
                'attempt_count INTEGER)',
              )
              ..execute(
                'CREATE TABLE media_transfer_queue '
                '(id INTEGER PRIMARY KEY AUTOINCREMENT, media_id TEXT)',
              )
              ..execute(
                'CREATE TABLE media_cache_entries '
                '(content_hash TEXT, kind TEXT, '
                'PRIMARY KEY (content_hash, kind))',
              )
              ..execute(
                'CREATE TABLE reef_data_cache '
                '(cache_key TEXT PRIMARY KEY, payload TEXT)',
              )
              ..execute('PRAGMA user_version = 7');
          },
        ),
      );
      addTearDown(db.close);
      await db
          .into(db.bathymetryCache)
          .insert(
            BathymetryCacheCompanion.insert(
              cacheKey: '12.16,-68.30',
              centerLat: 12.17,
              centerLon: -68.29,
              status: 'empty',
              fetchedAt: 1753600000000,
            ),
          );
      final rows = await db.select(db.bathymetryCache).get();
      expect(rows.single.status, 'empty');
    },
  );

  test('self-heals a v8-stamped database missing reef_data_cache', () async {
    // Mirror of the bathymetry self-heal: a parallel branch that also
    // claims v8 stamps user_version first, so the from<8 reef block never
    // runs and reef_data_cache would be missing without the beforeOpen
    // re-assert.
    final db = LocalCacheDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw
            ..execute(
              'CREATE TABLE local_asset_cache '
              '(media_id TEXT PRIMARY KEY, local_asset_id TEXT, '
              'resolved_at INTEGER, resolution_method TEXT, '
              'attempt_count INTEGER)',
            )
            ..execute(
              'CREATE TABLE media_transfer_queue '
              '(id INTEGER PRIMARY KEY AUTOINCREMENT, media_id TEXT)',
            )
            ..execute(
              'CREATE TABLE media_cache_entries '
              '(content_hash TEXT, kind TEXT, '
              'PRIMARY KEY (content_hash, kind))',
            )
            ..execute('PRAGMA user_version = 8');
        },
      ),
    );
    addTearDown(db.close);
    await db
        .into(db.reefDataCache)
        .insert(
          ReefDataCacheCompanion.insert(
            provider: 'noaaCoralReefWatch',
            coordKey: '12.160,-68.280',
            payloadJson: '{}',
            status: 'ok',
            fetchedAt: 1753600000000,
          ),
        );
    final rows = await db.select(db.reefDataCache).get();
    expect(rows.single.status, 'ok');
  });

  test('upgrade from a stored v8 schema creates the watcher tables', () async {
    final db = LocalCacheDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw
            ..execute(
              'CREATE TABLE local_asset_cache '
              '(media_id TEXT PRIMARY KEY, local_asset_id TEXT, '
              'resolved_at INTEGER, resolution_method TEXT, '
              'attempt_count INTEGER)',
            )
            ..execute(
              'CREATE TABLE media_transfer_queue '
              '(id INTEGER PRIMARY KEY AUTOINCREMENT, media_id TEXT)',
            )
            ..execute(
              'CREATE TABLE media_cache_entries '
              '(content_hash TEXT, kind TEXT, '
              'PRIMARY KEY (content_hash, kind))',
            )
            ..execute('PRAGMA user_version = 8');
        },
      ),
    );
    addTearDown(db.close);

    expect(db.schemaVersion, greaterThanOrEqualTo(9));
    await db
        .into(db.watchedRoots)
        .insert(WatchedRootsCompanion.insert(path: '/nas/Dives', addedAt: 1));
    await db
        .into(db.watchedFolderIndex)
        .insert(
          WatchedFolderIndexCompanion.insert(
            rootPath: '/nas/Dives',
            relativePath: '2026/a.jpg',
            sizeBytes: 4,
            mtimeMillis: 2,
            contentHash: const Value('H'),
          ),
        );
    expect((await db.select(db.watchedRoots).get()).single.path, '/nas/Dives');
  });

  test('self-heals a v9-stamped database missing the watcher tables', () async {
    // Same ladder collision as the v7/v8 cases: a parallel branch claiming
    // v9 stamps user_version first, so the from<9 block never runs here.
    final db = LocalCacheDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw
            ..execute(
              'CREATE TABLE local_asset_cache '
              '(media_id TEXT PRIMARY KEY, local_asset_id TEXT, '
              'resolved_at INTEGER, resolution_method TEXT, '
              'attempt_count INTEGER)',
            )
            ..execute(
              'CREATE TABLE media_transfer_queue '
              '(id INTEGER PRIMARY KEY AUTOINCREMENT, media_id TEXT)',
            )
            ..execute(
              'CREATE TABLE media_cache_entries '
              '(content_hash TEXT, kind TEXT, '
              'PRIMARY KEY (content_hash, kind))',
            )
            ..execute('PRAGMA user_version = 9');
        },
      ),
    );
    addTearDown(db.close);

    await db
        .into(db.watchedFolderIndex)
        .insert(
          WatchedFolderIndexCompanion.insert(
            rootPath: '/nas/Dives',
            relativePath: '2026/a.jpg',
            sizeBytes: 4,
            mtimeMillis: 2,
          ),
        );
    final rows = await db.select(db.watchedFolderIndex).get();
    expect(rows.single.relativePath, '2026/a.jpg');
    // Not yet hashed: the scanner fills this in on its first pass.
    expect(rows.single.contentHash, null);
  });
}
