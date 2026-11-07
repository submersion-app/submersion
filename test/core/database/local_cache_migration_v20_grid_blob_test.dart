import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database;
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_grid_codec.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';

final _legacyGrid = BathymetryGrid(
  originLat: 12.14,
  originLon: -68.31,
  cellSizeLatDeg: 0.004,
  cellSizeLonDeg: 0.004,
  rows: 2,
  cols: 2,
  depthsMeters: const [10, 20, null, 40],
  sourceId: 'gmrt-zürich',
  resolutionMeters: 61,
  fetchedAt: DateTime.utc(2026, 7, 28),
);

/// The v19 shapes of the two grid tables, holding one legacy JSON row each.
void _v19Tables(Database raw, {required int userVersion}) {
  final json = jsonEncode(_legacyGrid.toJson()).replaceAll("'", "''");
  raw
    ..execute(
      'CREATE TABLE bathymetry_cache (cache_key TEXT NOT NULL, '
      'center_lat REAL NOT NULL, center_lon REAL NOT NULL, '
      'status TEXT NOT NULL, source_id TEXT NULL, '
      'resolution_meters REAL NULL, grid_json TEXT NULL, '
      'fetched_at INTEGER NOT NULL, PRIMARY KEY (cache_key))',
    )
    ..execute(
      "INSERT INTO bathymetry_cache VALUES ('12.16,-68.30@8000v6', 12.17, "
      "-68.29, 'ok', 'gmrt', 61, '$json', 1753600000000)",
    )
    ..execute(
      "INSERT INTO bathymetry_cache VALUES ('0.00,0.00@8000v6', 0, 0, "
      "'empty', NULL, NULL, NULL, 1753600000000)",
    )
    ..execute(
      'CREATE TABLE swiss_bathy_tile_cache (tile_key TEXT NOT NULL, '
      'status TEXT NOT NULL, grid_json TEXT NULL, '
      'fetched_at INTEGER NOT NULL, source_datetime TEXT NULL, '
      'checked_at INTEGER NULL, source_href TEXT NULL, '
      'reference_level_meters REAL NULL, PRIMARY KEY (tile_key))',
    )
    ..execute(
      "INSERT INTO swiss_bathy_tile_cache VALUES ('2726_1221', 'ok', "
      "'$json', 1753600000000, NULL, NULL, NULL, 405.92)",
    )
    ..execute('PRAGMA user_version = $userVersion');
}

Future<Set<String>> _indexes(LocalCacheDatabase db, String table) async => {
  for (final row in await db.customSelect("PRAGMA index_list('$table')").get())
    row.read<String>('name'),
};

void main() {
  for (final (label, userVersion) in [
    ('upgrade from a stored v19 schema', 19),
    // A colliding branch's v20 that never added these columns: no rung runs,
    // so the open must add them.
    ('a v20-stamped database without the columns, healed on open', 20),
  ]) {
    test('$label keeps legacy grids readable and sizes them', () async {
      final db = LocalCacheDatabase(
        NativeDatabase.memory(
          setup: (raw) => _v19Tables(raw, userVersion: userVersion),
        ),
      );
      addTearDown(db.close);

      final rows = {
        for (final row in await db.select(db.bathymetryCache).get())
          row.cacheKey: row,
      };
      final ok = rows['12.16,-68.30@8000v6']!;
      expect(ok.gridBlob, isNull);
      expect(ok.gridBytes, utf8.encode(ok.gridJson!).length);
      expect(ok.lastUsedAt, isNull);
      expect(
        BathymetryGridCodec.decodeStored(
          blob: ok.gridBlob,
          json: ok.gridJson,
        )!.depthsMeters,
        _legacyGrid.depthsMeters,
      );
      expect(rows['0.00,0.00@8000v6']!.gridBytes, isNull);

      final tile = await db.select(db.swissBathyTileCache).getSingle();
      expect(tile.gridBlob, isNull);
      expect(tile.gridJson, isNotNull);

      expect(
        await _indexes(db, 'bathymetry_cache'),
        contains('bathymetry_cache_budget_idx'),
      );
    });
  }

  test('a fresh database has the v20 columns', () async {
    final db = LocalCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, greaterThanOrEqualTo(20));
    Future<Set<String>> columns(String table) async => {
      for (final row
          in await db.customSelect("PRAGMA table_info('$table')").get())
        row.read<String>('name'),
    };
    expect(
      await columns('bathymetry_cache'),
      containsAll(['grid_blob', 'grid_bytes', 'last_used_at']),
    );
    expect(await columns('swiss_bathy_tile_cache'), contains('grid_blob'));
    expect(
      await _indexes(db, 'bathymetry_cache'),
      contains('bathymetry_cache_budget_idx'),
    );
  });
}
