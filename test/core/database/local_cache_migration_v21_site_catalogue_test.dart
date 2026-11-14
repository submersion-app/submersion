import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';

/// v21: the built-in site catalogue, loaded from its bundled file into two
/// local tables. Derivable data, so nothing is carried over: the rung only
/// creates the tables and the importer fills them.
const _columns = [
  'id',
  'name',
  'search_text',
  'latitude',
  'longitude',
  'country_code',
  'country',
  'region',
  'locality',
  'island',
  'body_of_water',
  'water_type',
  'min_depth',
  'max_depth',
  'type_ids',
  'entry_methods',
  'features',
  'difficulty',
  'hazards',
  'description',
  'website',
  'source',
  'source_ref',
  'trust',
  // Added by v22; a fresh database is created with it.
  'kind',
];

Future<List<String>> _columnsOf(LocalCacheDatabase db, String table) async =>
    (await db.customSelect("PRAGMA table_info('$table')").get())
        .map((c) => c.read<String>('name'))
        .toList();

Future<void> _insertOneOfEach(LocalCacheDatabase db) async {
  await db.customStatement(
    "INSERT INTO site_catalogue (id, name, search_text, source) "
    "VALUES ('osm_node_1', 'Salt Pier', 'salt pier', 'osm')",
  );
  await db.customStatement(
    "INSERT INTO site_catalogue_meta (key, value) VALUES ('version', 'abc')",
  );
}

void main() {
  test('a fresh database has both tables and the index', () async {
    final db = LocalCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(db.schemaVersion, greaterThanOrEqualTo(21));
    expect(await _columnsOf(db, 'site_catalogue'), _columns);
    expect(await _columnsOf(db, 'site_catalogue_meta'), ['key', 'value']);
    final index = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name = 'idx_site_catalogue_lat_lon'",
        )
        .get();
    expect(index, hasLength(1));
  });

  test('a fresh row takes the defaults for its lists and trust', () async {
    final db = LocalCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await _insertOneOfEach(db);

    final row = await db
        .customSelect(
          'SELECT type_ids, entry_methods, features, trust '
          'FROM site_catalogue',
        )
        .getSingle();
    expect(row.read<String>('type_ids'), '[]');
    expect(row.read<String>('entry_methods'), '[]');
    expect(row.read<String>('features'), '[]');
    expect(row.read<String>('trust'), 'verified');
  });

  test('a version 20 database gains them', () async {
    final db = LocalCacheDatabase(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA user_version = 20'),
      ),
    );
    addTearDown(db.close);

    await _insertOneOfEach(db);

    expect(await _columnsOf(db, 'site_catalogue'), _columns);
    final index = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name = 'idx_site_catalogue_lat_lon'",
        )
        .get();
    expect(index, hasLength(1));
  });

  test('a database stamped 21 without the tables is healed', () async {
    // A colliding branch's v21 that never created these tables.
    final db = LocalCacheDatabase(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA user_version = 21'),
      ),
    );
    addTearDown(db.close);

    await _insertOneOfEach(db);

    expect(await _columnsOf(db, 'site_catalogue'), _columns);
    expect(await _columnsOf(db, 'site_catalogue_meta'), ['key', 'value']);
  });
}
