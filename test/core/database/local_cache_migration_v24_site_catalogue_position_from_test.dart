import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/database/local_cache_site_catalogue_tables.dart';
import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_row_mapper.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';

/// v24: a researched catalogue record says when its position was read off
/// a counting page's map. Matching gives such a record a wider reach and
/// no say in the automatic pick, so the flag is stored with the record.

/// The table as v23 left it, before the position's origin existed.
const _v23Table = '''
  CREATE TABLE site_catalogue (
    id TEXT NOT NULL,
    name TEXT NOT NULL,
    search_text TEXT NOT NULL,
    latitude REAL NULL,
    longitude REAL NULL,
    country_code TEXT NULL,
    country TEXT NULL,
    region TEXT NULL,
    locality TEXT NULL,
    island TEXT NULL,
    body_of_water TEXT NULL,
    water_type TEXT NULL,
    min_depth REAL NULL,
    max_depth REAL NULL,
    type_ids TEXT NOT NULL DEFAULT '[]',
    entry_methods TEXT NOT NULL DEFAULT '[]',
    features TEXT NOT NULL DEFAULT '[]',
    difficulty TEXT NULL,
    hazards TEXT NULL,
    description TEXT NULL,
    website TEXT NULL,
    source TEXT NOT NULL,
    source_ref TEXT NULL,
    trust TEXT NOT NULL DEFAULT 'verified',
    kind TEXT NOT NULL DEFAULT 'site',
    PRIMARY KEY (id)
  )
''';

const _v23Meta = '''
  CREATE TABLE site_catalogue_meta (
    key TEXT NOT NULL,
    value TEXT NOT NULL,
    PRIMARY KEY (key)
  )
''';

const _oldRow =
    "INSERT INTO site_catalogue (id, name, search_text, source, trust) "
    "VALUES ('research_id_a', 'Coral Garden', 'coral garden', 'research', "
    "'researched')";

/// A local cache as an install on the previous build left it: stamped
/// [version], holding the v23 catalogue tables and one imported site.
LocalCacheDatabase _existing(int version) => LocalCacheDatabase(
  NativeDatabase.memory(
    setup: (raw) {
      raw.execute(_v23Table);
      raw.execute(_v23Meta);
      raw.execute(_oldRow);
      raw.execute('PRAGMA user_version = $version');
    },
  ),
);

Future<List<String>> _columnsOf(LocalCacheDatabase db) async =>
    (await db.customSelect("PRAGMA table_info('site_catalogue')").get())
        .map((c) => c.read<String>('name'))
        .toList();

void main() {
  test('the local cache is at least version 24', () {
    final db = LocalCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(db.schemaVersion, greaterThanOrEqualTo(24));
  });

  test('a fresh database has the column', () async {
    final db = LocalCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await _columnsOf(db), contains('position_from'));
  });

  test('v23 to v24 adds position_from and keeps the rows', () async {
    final db = _existing(23);
    addTearDown(db.close);

    expect(await _columnsOf(db), contains('position_from'));
    final row = await db.select(db.siteCatalogueEntries).getSingle();
    expect(row.id, 'research_id_a');
    expect(catalogueSiteFromRow(row).positionFromMap, isFalse);
  });

  test('the column is added again by the open backstop when a colliding '
      'branch stamped v24 first', () async {
    final db = _existing(24);
    addTearDown(db.close);

    expect(await _columnsOf(db), contains('position_from'));
    expect(await db.select(db.siteCatalogueEntries).get(), hasLength(1));
  });

  test('running the column helper again adds nothing', () async {
    final db = _existing(23);
    addTearDown(db.close);
    await _columnsOf(db);

    // The rung and the open backstop both call it: a second run must be a
    // no-op, not a duplicate-column error.
    await addSiteCataloguePositionFrom(db);
    expect(
      (await _columnsOf(db)).where((name) => name == 'position_from'),
      hasLength(1),
    );
  });

  test('positionFromMap survives a write and a read of the cache', () async {
    final db = LocalCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    const site = CatalogueSite(
      id: 'research_id_m',
      name: 'Coral Garden',
      source: 'research',
      trust: CatalogueTrust.researched,
      positionFromMap: true,
    );

    await db.into(db.siteCatalogueEntries).insert(catalogueSiteToRow(site));
    final row = await (db.select(
      db.siteCatalogueEntries,
    )..where((t) => t.id.equals('research_id_m'))).getSingle();

    expect(row.positionFrom, 'map');
    expect(catalogueSiteFromRow(row).positionFromMap, isTrue);
  });
}
