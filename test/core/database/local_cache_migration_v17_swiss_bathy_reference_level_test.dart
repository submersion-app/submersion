import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';

void main() {
  test(
    'fresh database exposes reference_level_meters on swiss_bathy_tile_cache',
    () async {
      final db = LocalCacheDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      expect(db.schemaVersion, greaterThanOrEqualTo(17));
      await db
          .into(db.swissBathyTileCache)
          .insert(
            SwissBathyTileCacheCompanion.insert(
              tileKey: '2665_1212',
              status: 'ok',
              gridJson: const Value('{}'),
              fetchedAt: 1753600000000,
              sourceDatetime: const Value('2023-01-01T00:00:00Z'),
              checkedAt: const Value(1753600000000),
              sourceHref: const Value('https://example.org/real.zip'),
              referenceLevelMeters: const Value(419.00),
            ),
          );
      final row = await db.select(db.swissBathyTileCache).getSingle();
      expect(row.referenceLevelMeters, 419.00);
    },
  );

  test('upgrade from a stored v16 schema adds reference_level_meters, '
      'nullable so existing rows survive', () async {
    final db = LocalCacheDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          // Minimal v16 shape: swiss_bathy_tile_cache exists WITHOUT the
          // v17 column, plus one pre-existing row to prove the upgrade
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
              'source_href TEXT NULL, '
              'PRIMARY KEY (tile_key))',
            )
            ..execute(
              "INSERT INTO swiss_bathy_tile_cache "
              "(tile_key, status, grid_json, fetched_at, source_datetime, "
              "checked_at, source_href) "
              "VALUES ('2665_1212', 'ok', '{}', 1753600000000, "
              "'2023-01-01T00:00:00Z', 1753600000000, "
              "'https://example.org/real.zip')",
            )
            ..execute('PRAGMA user_version = 16');
        },
      ),
    );
    addTearDown(db.close);
    final row = await db.select(db.swissBathyTileCache).getSingle();
    expect(row.tileKey, '2665_1212');
    expect(row.sourceHref, 'https://example.org/real.zip');
    // Pre-v17 rows have no known reference level -- SwissBathyTileCacheRepository.read
    // treats null the same as a mismatch when a caller checks it, forcing
    // one re-resolution rather than trusting a level that might no longer
    // be correct.
    expect(row.referenceLevelMeters, isNull);
  });

  test('a database already stamped at v17 but still v16-shaped (a ladder '
      'collision: another branch claimed user_version 17 first without '
      'actually running this migration) is healed by the beforeOpen '
      'backstop, not just onUpgrade -- onUpgrade never runs here since '
      'Drift sees no version change to apply (Copilot review)', () async {
    final db = LocalCacheDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw
            ..execute(
              'CREATE TABLE swiss_bathy_tile_cache '
              '(tile_key TEXT NOT NULL, status TEXT NOT NULL, '
              'grid_json TEXT NULL, fetched_at INTEGER NOT NULL, '
              'source_datetime TEXT NULL, checked_at INTEGER NULL, '
              'source_href TEXT NULL, '
              'PRIMARY KEY (tile_key))',
            )
            ..execute(
              "INSERT INTO swiss_bathy_tile_cache "
              "(tile_key, status, grid_json, fetched_at, source_datetime, "
              "checked_at, source_href) "
              "VALUES ('2665_1212', 'ok', '{}', 1753600000000, "
              "'2023-01-01T00:00:00Z', 1753600000000, "
              "'https://example.org/real.zip')",
            )
            // Stamped at the CURRENT schema version despite the table
            // still missing reference_level_meters -- the exact
            // collision this backstop exists to heal.
            ..execute('PRAGMA user_version = 17');
        },
      ),
    );
    addTearDown(db.close);
    final row = await db.select(db.swissBathyTileCache).getSingle();
    expect(row.tileKey, '2665_1212');
    expect(row.sourceHref, 'https://example.org/real.zip');
    expect(row.referenceLevelMeters, isNull);
  });
}
