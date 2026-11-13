import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/dive_sites/data/catalogue/local_site_catalogue.dart';
import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_importer.dart';
import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_parser.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

class _Bundle extends AssetBundle {
  _Bundle(this.catalogue);

  final String catalogue;

  @override
  Future<ByteData> load(String key) async {
    final text = key == kSiteCatalogueAsset ? catalogue : 'fixture';
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));
  }
}

Map<String, Object?> _site(
  String id,
  String name, {
  double? lat,
  double? lon,
  String? country,
  String? region,
  String? island,
}) => {
  'id': id,
  'name': name,
  'lat': ?lat,
  'lon': ?lon,
  'country': ?country,
  'region': ?region,
  'island': ?island,
  'source': 'osm',
  'trust': 'verified',
};

/// Bonaire's west coast, with one site per interesting distance from
/// Salt Pier (12.0800, -68.2800), plus sites elsewhere for search.
final _fixture = jsonEncode({
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
  'sites': [
    {
      'id': 'full',
      'name': 'Salt Pier',
      'lat': 12.08,
      'lon': -68.28,
      'country_code': 'BQ',
      'country': 'Caribbean Netherlands',
      'region': 'Kralendijk',
      'locality': 'Belnem',
      'island': 'Bonaire',
      'body_of_water': 'Caribbean Sea',
      'water_type': 'salt',
      'min_depth_m': 5,
      'max_depth_m': 15.5,
      'types': ['reef', 'pier'],
      'entry': ['shore', 'ladder'],
      'features': ['drift'],
      'difficulty': 'beginner',
      'hazards': 'boat traffic',
      'description': 'Pillars.',
      'website': 'https://example.org',
      'source': 'osm',
      'source_ref': 'https://www.openstreetmap.org/node/1',
      'trust': 'researched',
    },
    // About 2.2 km north.
    _site('near', 'Angel City', lat: 12.10, lon: -68.28, island: 'Bonaire'),
    // About 11 km north.
    _site('mid', 'Bari Reef', lat: 12.18, lon: -68.28, island: 'Bonaire'),
    // About 77 km east: Curaçao is west, this is open water east.
    _site('far', 'Far Reef', lat: 12.08, lon: -67.57),
    _site('nowhere', 'Salt Mine', country: 'Germany'),
    _site('egypt', 'Blue Hole', lat: 28.57, lon: 34.54, country: 'Egypt'),
    _site('palau', 'Blue Corner', lat: 7.13, lon: 134.22, country: 'Palau'),
    _site('accent', 'Cancún', lat: 21.1, lon: -86.7, country: 'México'),
    _site('percent', '100% Reef', lat: 1, lon: 1),
    _site('under', 'Reef_Wall', lat: 2, lon: 2),
    // Either side of the antimeridian, 0.1 degree of longitude apart.
    _site('fiji_east', 'Rainbow Reef East', lat: -16.8, lon: -179.95),
    _site('fiji_far', 'Rainbow Reef Far', lat: -16.8, lon: 178.0),
  ],
});

const _saltPier = GeoPoint(12.08, -68.28);

void main() {
  late LocalCacheDatabase db;
  late LocalSiteCatalogue catalogue;

  setUp(() async {
    db = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    await SiteCatalogueImporter(
      database: db,
      bundle: _Bundle(_fixture),
    ).importIfChanged();
    catalogue = LocalSiteCatalogue(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  List<String> idsOf(List<CatalogueSite> sites) =>
      sites.map((s) => s.id).toList();

  group('near', () {
    test('returns sites inside the radius, nearest first', () async {
      final sites = await catalogue.near(_saltPier, radiusMeters: 50000);

      expect(idsOf(sites), ['full', 'near', 'mid']);
    });

    test('a site just inside the radius is not lost to the box', () async {
      // The index answers a box and the distance check cuts its corners,
      // so the box has to hold the whole circle. Both sites are 49,990 m
      // from their centre: one due north, one due east at 60 degrees
      // north, where a degree of longitude is half as long.
      final edges = LocalCacheDatabase(
        NativeDatabase.memory(setup: registerAppSqlFunctions),
      );
      addTearDown(edges.close);
      await SiteCatalogueImporter(
        database: edges,
        bundle: _Bundle(
          jsonEncode({
            'metadata': {'format': 2, 'sources': <String, Object?>{}},
            'sites': [
              _site('north', 'North Edge', lat: 0.449571, lon: 0),
              _site('east', 'East Edge', lat: 60, lon: 10.89915),
            ],
          }),
        ),
      ).importIfChanged();
      final edgeCatalogue = LocalSiteCatalogue(database: edges);

      expect(
        idsOf(
          await edgeCatalogue.near(const GeoPoint(0, 0), radiusMeters: 50000),
        ),
        ['north'],
      );
      expect(
        idsOf(
          await edgeCatalogue.near(const GeoPoint(60, 10), radiusMeters: 50000),
        ),
        ['east'],
      );
    });

    test('a smaller radius cuts the list', () async {
      final sites = await catalogue.near(_saltPier, radiusMeters: 5000);

      expect(idsOf(sites), ['full', 'near']);
    });

    test('respects the limit, keeping the nearest', () async {
      final sites = await catalogue.near(
        _saltPier,
        radiusMeters: 50000,
        limit: 2,
      );

      expect(idsOf(sites), ['full', 'near']);
    });

    test('works across the antimeridian', () async {
      final sites = await catalogue.near(
        const GeoPoint(-16.8, 179.95),
        radiusMeters: 50000,
      );

      expect(idsOf(sites), ['fiji_east']);
    });

    test('works across the antimeridian from the other side', () async {
      final sites = await catalogue.near(
        const GeoPoint(-16.8, -179.99),
        radiusMeters: 50000,
      );

      expect(idsOf(sites), ['fiji_east']);
    });
  });

  group('search', () {
    test('needs every word', () async {
      expect(idsOf(await catalogue.search('blue egypt')), ['egypt']);
      expect(idsOf(await catalogue.search('blue')), ['palau', 'egypt']);
    });

    test('folds case and accents', () async {
      expect(idsOf(await catalogue.search('CANCUN')), ['accent']);
      expect(idsOf(await catalogue.search('méxico')), ['accent']);
    });

    test('finds a site without coordinates', () async {
      expect(idsOf(await catalogue.search('salt germany')), ['nowhere']);
    });

    test('finds a site by the sea it is in', () async {
      expect(idsOf(await catalogue.search('caribbean sea')), ['full']);
    });

    test('puts the area first, then by name', () async {
      final sites = await catalogue.search(
        'reef',
        areaFirst: _saltPier,
        limit: 4,
      );

      // Bari Reef is the only "reef" within 50 km of Salt Pier; the rest
      // follow by name.
      expect(idsOf(sites), ['mid', 'percent', 'far', 'fiji_east']);
    });

    test('treats percent and underscore literally', () async {
      expect(idsOf(await catalogue.search('%')), ['percent']);
      expect(idsOf(await catalogue.search('_')), ['under']);
      expect(idsOf(await catalogue.search('100%')), ['percent']);
    });

    test('a blank query matches nothing', () async {
      expect(await catalogue.search(''), isEmpty);
      expect(await catalogue.search('   '), isEmpty);
    });

    test('respects the limit', () async {
      expect(await catalogue.search('reef', limit: 2), hasLength(2));
    });

    test('a backslash in the query is matched literally', () async {
      expect(await catalogue.search(r'\'), isEmpty);
    });
  });

  group('byId', () {
    test('returns the site with every field', () async {
      final site = await catalogue.byId('full');

      expect(site, parseSiteCatalogue(_fixture).sites.first);
      expect(site!.entryMethods, [EntryMethod.shore, EntryMethod.ladder]);
      expect(site.trust, CatalogueTrust.researched);
      expect(site.waterType, WaterType.salt);
    });

    test('returns null for an unknown id', () async {
      expect(await catalogue.byId('missing'), isNull);
    });
  });

  test('allWithCoordinates leaves out sites without coordinates', () async {
    final sites = await catalogue.allWithCoordinates();

    expect(sites, hasLength(11));
    expect(idsOf(sites), isNot(contains('nowhere')));
  });

  test('source returns the stored source or null', () async {
    expect(
      await catalogue.source('osm'),
      const CatalogueSource(
        key: 'osm',
        name: 'OpenStreetMap',
        licence: 'ODbL-1.0',
        licenceUrl: 'https://www.openstreetmap.org/copyright',
        credit: 'OpenStreetMap contributors',
      ),
    );
    expect(await catalogue.source('rumour'), isNull);
  });

  test('every method answers empty when the database is not open', () async {
    LocalCacheDatabaseService.instance.resetForTesting();
    addTearDown(LocalCacheDatabaseService.instance.resetForTesting);
    final unopened = LocalSiteCatalogue();

    expect(await unopened.near(_saltPier, radiusMeters: 50000), isEmpty);
    expect(await unopened.search('reef'), isEmpty);
    expect(await unopened.byId('full'), isNull);
    expect(await unopened.allWithCoordinates(), isEmpty);
    expect(await unopened.source('osm'), isNull);
  });
}
