import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_importer.dart';
import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_parser.dart';

/// Serves the two catalogue assets from memory and counts each read.
class _Bundle extends AssetBundle {
  _Bundle({this.catalogue, this.version});

  String? catalogue;
  String? version;
  final Map<String, int> reads = {};

  @override
  Future<ByteData> load(String key) async {
    reads[key] = (reads[key] ?? 0) + 1;
    final text = switch (key) {
      kSiteCatalogueAsset => catalogue,
      kSiteCatalogueVersionAsset => version,
      _ => null,
    };
    if (text == null) throw StateError('Unable to load asset: "$key"');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));
  }
}

Map<String, Object?> _site(
  String id,
  String name, [
  Map<String, Object?>? more,
]) => {'id': id, 'name': name, 'source': 'osm', 'trust': 'verified', ...?more};

String _catalogue(List<Object?> sites) => jsonEncode({
  'metadata': {
    'format': 2,
    'sources': {
      'osm': {
        'name': 'OpenStreetMap',
        'licence': 'ODbL-1.0',
        'licence_url': 'https://www.openstreetmap.org/copyright',
        'credit': 'OpenStreetMap contributors',
      },
    },
  },
  'sites': sites,
});

final _three = _catalogue([
  _site('osm_node_1', 'Cancún', {
    'lat': 21.1,
    'lon': -86.7,
    'country': 'México',
    'types': ['reef'],
    'entry': ['boat'],
  }),
  _site('osm_node_2', 'Blue Hole', {'country': 'Egypt', 'region': 'Dahab'}),
  _site('osm_node_3', 'Salt Pier'),
]);

void main() {
  late LocalCacheDatabase db;

  setUp(() {
    db = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<List<String>> ids() async =>
      (await db.customSelect('SELECT id FROM site_catalogue ORDER BY id').get())
          .map((r) => r.read<String>('id'))
          .toList();

  Future<String?> meta(String key) async =>
      (await db
              .customSelect(
                'SELECT value FROM site_catalogue_meta WHERE key = ?',
                variables: [Variable.withString(key)],
              )
              .getSingleOrNull())
          ?.read<String>('value');

  test('first run imports every record and stores the version', () async {
    final bundle = _Bundle(catalogue: _three, version: 'v1\n');

    final outcome = await SiteCatalogueImporter(
      database: db,
      bundle: bundle,
    ).importIfChanged();

    expect(outcome, SiteCatalogueImportOutcome.imported);
    expect(await ids(), ['osm_node_1', 'osm_node_2', 'osm_node_3']);
    expect(await meta('version'), 'v1');
    final sources = jsonDecode((await meta('sources'))!) as List;
    expect((sources.single as Map)['credit'], 'OpenStreetMap contributors');

    final row = await db
        .customSelect(
          "SELECT search_text, type_ids, entry_methods, latitude "
          "FROM site_catalogue WHERE id = 'osm_node_1'",
        )
        .getSingle();
    final parsed = parseSiteCatalogue(_three).sites.first;
    expect(row.read<String>('search_text'), catalogueSearchText(parsed));
    expect(row.read<String>('search_text'), 'cancun mexico');
    expect(jsonDecode(row.read<String>('type_ids')), ['reef']);
    expect(jsonDecode(row.read<String>('entry_methods')), ['boat']);
    expect(row.read<double>('latitude'), 21.1);
  });

  test('the same version imports nothing', () async {
    final bundle = _Bundle(catalogue: _three, version: 'v1');
    final importer = SiteCatalogueImporter(database: db, bundle: bundle);
    await importer.importIfChanged();

    final outcome = await importer.importIfChanged();

    expect(outcome, SiteCatalogueImportOutcome.upToDate);
    // The large file is never read just to learn nothing changed.
    expect(bundle.reads[kSiteCatalogueAsset], 1);
    expect(bundle.reads[kSiteCatalogueVersionAsset], 2);
  });

  test('a new version replaces the rows', () async {
    final bundle = _Bundle(catalogue: _three, version: 'v1');
    final importer = SiteCatalogueImporter(database: db, bundle: bundle);
    await importer.importIfChanged();

    bundle
      ..catalogue = _catalogue([
        _site('osm_node_2', 'Blue Hole'),
        _site('osm_node_9', 'New Reef'),
      ])
      ..version = 'v2';
    final outcome = await importer.importIfChanged();

    expect(outcome, SiteCatalogueImportOutcome.imported);
    expect(await ids(), ['osm_node_2', 'osm_node_9']);
    expect(await meta('version'), 'v2');
  });

  test('a file that cannot be parsed leaves the old rows', () async {
    final bundle = _Bundle(catalogue: _three, version: 'v1');
    final importer = SiteCatalogueImporter(database: db, bundle: bundle);
    await importer.importIfChanged();

    bundle
      ..catalogue = 'not json'
      ..version = 'v2';
    final outcome = await importer.importIfChanged();

    expect(outcome, SiteCatalogueImportOutcome.failed);
    expect(await ids(), ['osm_node_1', 'osm_node_2', 'osm_node_3']);
    expect(await meta('version'), 'v1');

    // A later launch with a good file recovers.
    bundle.catalogue = _catalogue([_site('osm_node_9', 'New Reef')]);
    expect(
      await importer.importIfChanged(),
      SiteCatalogueImportOutcome.imported,
    );
    expect(await ids(), ['osm_node_9']);
  });

  test('a bad record is skipped, the rest import', () async {
    final bundle = _Bundle(
      catalogue: _catalogue([
        _site('osm_node_1', 'First'),
        {'id': 'osm_node_2', 'source': 'osm'},
        _site('osm_node_3', 'Third'),
      ]),
      version: 'v1',
    );

    final outcome = await SiteCatalogueImporter(
      database: db,
      bundle: bundle,
    ).importIfChanged();

    expect(outcome, SiteCatalogueImportOutcome.imported);
    expect(await ids(), ['osm_node_1', 'osm_node_3']);
  });

  test('an id that appears twice keeps its last record', () async {
    final bundle = _Bundle(
      catalogue: _catalogue([
        _site('osm_node_1', 'First'),
        _site('osm_node_1', 'Second'),
      ]),
      version: 'v1',
    );

    final outcome = await SiteCatalogueImporter(
      database: db,
      bundle: bundle,
    ).importIfChanged();

    expect(outcome, SiteCatalogueImportOutcome.imported);
    final row = await db
        .customSelect('SELECT name FROM site_catalogue')
        .getSingle();
    expect(row.read<String>('name'), 'Second');
  });

  test('more records than one batch all arrive', () async {
    final bundle = _Bundle(
      catalogue: _catalogue([
        for (var i = 0; i < 1203; i++) _site('osm_node_$i', 'Site $i'),
      ]),
      version: 'v1',
    );

    await SiteCatalogueImporter(database: db, bundle: bundle).importIfChanged();

    final count = await db
        .customSelect('SELECT COUNT(*) AS c FROM site_catalogue')
        .getSingle();
    expect(count.read<int>('c'), 1203);
  });

  test('two calls at once import once', () async {
    final bundle = _Bundle(catalogue: _three, version: 'v1');
    final importer = SiteCatalogueImporter(database: db, bundle: bundle);

    final outcomes = await Future.wait([
      importer.importIfChanged(),
      importer.importIfChanged(),
    ]);

    expect(outcomes, [
      SiteCatalogueImportOutcome.imported,
      SiteCatalogueImportOutcome.imported,
    ]);
    expect(bundle.reads[kSiteCatalogueAsset], 1);
  });

  test('a missing sidecar fails without throwing', () async {
    final bundle = _Bundle(catalogue: _three);

    final outcome = await SiteCatalogueImporter(
      database: db,
      bundle: bundle,
    ).importIfChanged();

    expect(outcome, SiteCatalogueImportOutcome.failed);
    expect(await ids(), isEmpty);
  });

  test('an empty sidecar fails without importing', () async {
    final bundle = _Bundle(catalogue: _three, version: '  \n');

    final outcome = await SiteCatalogueImporter(
      database: db,
      bundle: bundle,
    ).importIfChanged();

    expect(outcome, SiteCatalogueImportOutcome.failed);
    expect(bundle.reads[kSiteCatalogueAsset], isNull);
  });

  test('the database not being open fails without throwing', () async {
    LocalCacheDatabaseService.instance.resetForTesting();
    addTearDown(LocalCacheDatabaseService.instance.resetForTesting);
    final bundle = _Bundle(catalogue: _three, version: 'v1');

    final outcome = await SiteCatalogueImporter(
      bundle: bundle,
    ).importIfChanged();

    expect(outcome, SiteCatalogueImportOutcome.failed);
  });
}
