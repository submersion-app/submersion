import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/geocoding/sea_area_service.dart';
import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_importer.dart';
import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_row_mapper.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';

/// v22: a catalogue record says whether it is a dive site or a register
/// record (a charted wreck, a reef deployment). The picker lists the two
/// apart, so the kind is a column reads can filter on.

/// The table as v21 created it, before the kind existed.
const _v21Table = '''
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
    PRIMARY KEY (id)
  )
''';

const _v21Meta = '''
  CREATE TABLE site_catalogue_meta (
    key TEXT NOT NULL,
    value TEXT NOT NULL,
    PRIMARY KEY (key)
  )
''';

const _oldRow =
    "INSERT INTO site_catalogue (id, name, search_text, source) "
    "VALUES ('osm_node_1', 'Salt Pier', 'salt pier', 'osm')";

/// A local cache as an install on the previous build left it: stamped
/// [version], holding the v21 catalogue tables and one imported site.
LocalCacheDatabase _existing(int version) => LocalCacheDatabase(
  NativeDatabase.memory(
    setup: (raw) {
      raw.execute(_v21Table);
      raw.execute(_v21Meta);
      raw.execute(_oldRow);
      raw.execute(
        "INSERT INTO site_catalogue_meta (key, value) "
        "VALUES ('version', '3:old-hash')",
      );
      raw.execute('PRAGMA user_version = $version');
    },
  ),
);

Future<List<String>> _columnsOf(LocalCacheDatabase db) async =>
    (await db.customSelect("PRAGMA table_info('site_catalogue')").get())
        .map((c) => c.read<String>('name'))
        .toList();

Future<bool> _hasKindIndex(LocalCacheDatabase db) async =>
    (await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'index' "
              "AND name = 'idx_site_catalogue_kind_lat_lon'",
            )
            .get())
        .isNotEmpty;

class _Bundle extends AssetBundle {
  _Bundle(this.files);

  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    final text = files[key];
    if (text == null) throw StateError('Unable to load asset: "$key"');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));
  }
}

void main() {
  test('the local cache is at version 22', () {
    final db = LocalCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(db.schemaVersion, 22);
  });

  test('a fresh database has the kind, last, and its index', () async {
    final db = LocalCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect((await _columnsOf(db)).last, 'kind');
    expect(await _hasKindIndex(db), isTrue);
  });

  test('a version 21 database gains the kind and keeps its rows as dive '
      'sites', () async {
    final db = _existing(21);
    addTearDown(db.close);

    expect((await _columnsOf(db)).last, 'kind');
    expect(await _hasKindIndex(db), isTrue);
    final row = await db.select(db.siteCatalogueEntries).getSingle();
    expect(row.id, 'osm_node_1');
    expect(catalogueSiteFromRow(row).kind, CatalogueKind.site);
  });

  test('a database stamped 22 without the kind is healed', () async {
    // A colliding branch's v22 that never added the column.
    final db = _existing(22);
    addTearDown(db.close);

    expect((await _columnsOf(db)).last, 'kind');
    expect(await _hasKindIndex(db), isTrue);
    expect(await db.select(db.siteCatalogueEntries).get(), hasLength(1));
  });

  test('opening twice changes nothing the second time', () async {
    final db = _existing(21);
    addTearDown(db.close);
    await _columnsOf(db);

    // The backstop runs on every open: it must be safe to repeat.
    await db.customStatement('SELECT 1');
    expect(
      (await _columnsOf(db)).where((name) => name == 'kind'),
      hasLength(1),
    );
  });

  test('the next catalogue still imports over the migrated rows', () async {
    final db = _existing(21);
    addTearDown(db.close);
    final catalogue = jsonEncode({
      'metadata': {
        'format': 2,
        'sources': {
          'ukho': {'name': 'UKHO', 'licence': 'OGL-UK-3.0', 'credit': 'UKHO'},
        },
      },
      'sites': [
        {
          'id': 'ukho_1',
          'name': 'HMS Exeter',
          'lat': 1.0,
          'lon': 2.0,
          'kind': 'register',
          'source': 'ukho',
          'trust': 'verified',
        },
      ],
    });

    final outcome = await SiteCatalogueImporter(
      database: db,
      bundle: _Bundle({
        kSiteCatalogueAsset: catalogue,
        kSiteCatalogueVersionAsset: 'new-hash',
        SeaAreaService.assetPath: '{"areas": []}',
      }),
    ).importIfChanged();

    expect(outcome, SiteCatalogueImportOutcome.imported);
    final row = await db.select(db.siteCatalogueEntries).getSingle();
    expect(row.id, 'ukho_1');
    expect(catalogueSiteFromRow(row).kind, CatalogueKind.register);
  });
}
