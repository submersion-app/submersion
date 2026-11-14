import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/geocoding/sea_area_service.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_importer.dart';
import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_parser.dart';
import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_row_mapper.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';

/// Serves the catalogue assets, and the sea table when a test gives one,
/// from memory, and counts each read.
class _Bundle extends AssetBundle {
  _Bundle({this.catalogue, this.version, this.seaAreas});

  String? catalogue;
  String? version;
  String? seaAreas;
  final Map<String, int> reads = {};

  @override
  Future<ByteData> load(String key) async {
    reads[key] = (reads[key] ?? 0) + 1;
    final text = switch (key) {
      kSiteCatalogueAsset => catalogue,
      kSiteCatalogueVersionAsset => version,
      SeaAreaService.assetPath => seaAreas,
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

/// A sea table with one sea: the square from the equator and the prime
/// meridian to 10 degrees north and east.
final _testSea = jsonEncode({
  'areas': [
    {
      'name': 'Test Sea',
      'bbox': [0, 0, 10, 10],
      'area': 100.0,
      'polygons': [
        {
          'outer': [0, 0, 10, 0, 10, 10, 0, 10, 0, 0],
        },
      ],
    },
  ],
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
    expect(await meta('version'), '$kSiteCatalogueImportRevision:v1');
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
    // The folded name, the mark that ends it, then the folded places.
    expect(row.read<String>('search_text'), 'cancun${kCatalogueNameEnd}mexico');
    expect(jsonDecode(row.read<String>('type_ids')), ['reef']);
    expect(jsonDecode(row.read<String>('entry_methods')), ['boat']);
    expect(row.read<double>('latitude'), 21.1);
  });

  test('a register record is stored and read back as one', () async {
    final db = LocalCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final bundle = _Bundle(
      catalogue: _catalogue([
        _site('ukho_1', 'HMS Exeter', {
          'kind': 'register',
          'lat': 1.0,
          'lon': 2.0,
        }),
        _site('osm_node_1', 'Salt Pier'),
      ]),
      version: 'v1',
    );

    await SiteCatalogueImporter(database: db, bundle: bundle).importIfChanged();

    final rows = await db.select(db.siteCatalogueEntries).get();
    final byId = {for (final row in rows) row.id: catalogueSiteFromRow(row)};
    expect(byId['ukho_1']!.kind, CatalogueKind.register);
    expect(byId['osm_node_1']!.kind, CatalogueKind.site);
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
    expect(await meta('version'), '$kSiteCatalogueImportRevision:v2');
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
    expect(await meta('version'), '$kSiteCatalogueImportRevision:v1');

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

  test('a file with no usable record leaves the old rows', () async {
    final bundle = _Bundle(catalogue: _three, version: 'v1');
    final importer = SiteCatalogueImporter(database: db, bundle: bundle);
    await importer.importIfChanged();

    // Parses, but nothing in it is a site: emptying the catalogue until
    // the next app update would be worse than keeping the old one.
    bundle
      ..catalogue = _catalogue([
        {'id': 'osm_node_9', 'source': 'osm'},
        'not a record',
      ])
      ..version = 'v2';
    final outcome = await importer.importIfChanged();

    expect(outcome, SiteCatalogueImportOutcome.failed);
    expect(await ids(), ['osm_node_1', 'osm_node_2', 'osm_node_3']);
    expect(await meta('version'), '$kSiteCatalogueImportRevision:v1');
  });

  test('a build that reads the file differently imports it again', () async {
    final bundle = _Bundle(catalogue: _three, version: 'v1');
    await SiteCatalogueImporter(database: db, bundle: bundle).importIfChanged();

    // The same file, a newer importer (a fix to how search text is folded,
    // say): the stored rows are from the old reading.
    final outcome = await SiteCatalogueImporter(
      database: db,
      bundle: bundle,
      importRevision: kSiteCatalogueImportRevision + 1,
    ).importIfChanged();

    expect(outcome, SiteCatalogueImportOutcome.imported);
    expect(await meta('version'), '${kSiteCatalogueImportRevision + 1}:v1');
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

  test('names each site\'s sea from the bundled sea table', () async {
    final bundle = _Bundle(
      catalogue: _catalogue([
        _site('osm_node_1', 'Shark Reef', {'lat': 5, 'lon': 5}),
        _site('osm_node_2', 'Inland Quarry', {'lat': 50, 'lon': 50}),
      ]),
      version: 'v1',
      seaAreas: _testSea,
    );

    final outcome = await SiteCatalogueImporter(
      database: db,
      bundle: bundle,
    ).importIfChanged();

    expect(outcome, SiteCatalogueImportOutcome.imported);
    final rows = await db
        .customSelect(
          'SELECT id, body_of_water, search_text FROM site_catalogue '
          'ORDER BY id',
        )
        .get();
    expect(rows[0].read<String?>('body_of_water'), 'Test Sea');
    // A search for the sea finds the site.
    expect(rows[0].read<String>('search_text'), contains('test sea'));
    expect(rows[1].read<String?>('body_of_water'), isNull);
  });

  test('an unreadable sea table does not stop the import', () async {
    final bundle = _Bundle(
      catalogue: _catalogue([
        _site('osm_node_1', 'Shark Reef', {'lat': 5, 'lon': 5}),
      ]),
      version: 'v1',
      seaAreas: 'not a sea table',
    );

    final outcome = await SiteCatalogueImporter(
      database: db,
      bundle: bundle,
    ).importIfChanged();

    expect(outcome, SiteCatalogueImportOutcome.imported);
    expect(await ids(), ['osm_node_1']);
  });

  group('buildSiteCatalogueRows', () {
    final catalogue = _catalogue([
      _site('osm_node_1', 'Shark Reef', {'lat': 5, 'lon': 5}),
    ]);

    test('says the sea table was read', () {
      final built = buildSiteCatalogueRows((
        catalogue: catalogue,
        seaAreas: _testSea,
      ));

      expect(built.seaTableRead, isTrue);
      expect(built.rows.single.bodyOfWater.value, 'Test Sea');
    });

    test('says so when the sea table cannot be parsed', () {
      // The importer logs this: a catalogue with no sea names must not
      // look like a normal import.
      final built = buildSiteCatalogueRows((
        catalogue: catalogue,
        seaAreas: 'not a sea table',
      ));

      expect(built.seaTableRead, isFalse);
      expect(built.rows.single.bodyOfWater.value, isNull);
    });

    test('a sea table that was never read is not a parse failure', () {
      final built = buildSiteCatalogueRows((
        catalogue: catalogue,
        seaAreas: null,
      ));

      expect(built.seaTableRead, isFalse);
      expect(built.rows, hasLength(1));
    });
  });
}
