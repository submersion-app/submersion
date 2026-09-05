import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';

void main() {
  test('fresh database exposes swiss_bathy_tile_cache', () async {
    final db = LocalCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, greaterThanOrEqualTo(14));
    await db
        .into(db.swissBathyTileCache)
        .insert(
          SwissBathyTileCacheCompanion.insert(
            tileKey: '2685_1240',
            status: 'ok',
            gridJson: const Value('{}'),
            fetchedAt: 1753600000000,
          ),
        );
    final rows = await db.select(db.swissBathyTileCache).get();
    expect(rows.single.status, 'ok');
    expect(rows.single.tileKey, '2685_1240');
  });

  test(
    'upgrade from a stored v13 schema creates swiss_bathy_tile_cache',
    () async {
      final db = LocalCacheDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            // Minimal v13 shape: the migration only creates the new table, so
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
              ..execute('PRAGMA user_version = 13');
          },
        ),
      );
      addTearDown(db.close);
      final rows = await db.select(db.swissBathyTileCache).get();
      expect(rows, isEmpty);
    },
  );

  test(
    'self-heals a v14-stamped database missing swiss_bathy_tile_cache',
    () async {
      // Reproduces the runtime ladder collision: another branch already
      // bumped user_version to 14 with ITS table, so onUpgrade never runs
      // here and swiss_bathy_tile_cache would not exist without the
      // beforeOpen re-assert.
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
              ..execute('PRAGMA user_version = 14');
          },
        ),
      );
      addTearDown(db.close);
      await db
          .into(db.swissBathyTileCache)
          .insert(
            SwissBathyTileCacheCompanion.insert(
              tileKey: '2685_1240',
              status: 'empty',
              fetchedAt: 1753600000000,
            ),
          );
      final rows = await db.select(db.swissBathyTileCache).get();
      expect(rows.single.status, 'empty');
    },
  );
}
