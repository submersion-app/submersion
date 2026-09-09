import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';

void main() {
  test(
    'fresh database exposes source_href on swiss_bathy_tile_cache',
    () async {
      final db = LocalCacheDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      expect(db.schemaVersion, greaterThanOrEqualTo(16));
      await db
          .into(db.swissBathyTileCache)
          .insert(
            SwissBathyTileCacheCompanion.insert(
              tileKey: '2685_1240',
              status: 'ok',
              gridJson: const Value('{}'),
              fetchedAt: 1753600000000,
              sourceDatetime: const Value('2023-01-01T00:00:00Z'),
              checkedAt: const Value(1753600000000),
              sourceHref: const Value('https://example.org/real.zip'),
            ),
          );
      final row = await db.select(db.swissBathyTileCache).getSingle();
      expect(row.sourceHref, 'https://example.org/real.zip');
    },
  );

  test('upgrade from a stored v15 schema adds source_href, nullable so '
      'existing rows survive', () async {
    final db = LocalCacheDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          // Minimal v15 shape: swiss_bathy_tile_cache exists WITHOUT the
          // v16 column, plus one pre-existing row to prove the upgrade
          // doesn't drop data.
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
              'CREATE TABLE swiss_bathy_tile_cache '
              '(tile_key TEXT NOT NULL, status TEXT NOT NULL, '
              'grid_json TEXT NULL, fetched_at INTEGER NOT NULL, '
              'source_datetime TEXT NULL, checked_at INTEGER NULL, '
              'PRIMARY KEY (tile_key))',
            )
            ..execute(
              "INSERT INTO swiss_bathy_tile_cache "
              "(tile_key, status, grid_json, fetched_at, source_datetime, "
              "checked_at) "
              "VALUES ('2685_1240', 'ok', '{}', 1753600000000, "
              "'2023-01-01T00:00:00Z', 1753600000000)",
            )
            ..execute('PRAGMA user_version = 15');
        },
      ),
    );
    addTearDown(db.close);
    final row = await db.select(db.swissBathyTileCache).getSingle();
    expect(row.tileKey, '2685_1240');
    expect(row.sourceDatetime, '2023-01-01T00:00:00Z');
    // Pre-v16 rows have no known covering href yet -- the source falls
    // back to one full re-resolution on their next freshness check, which
    // then populates this column going forward.
    expect(row.sourceHref, isNull);
  });
}
