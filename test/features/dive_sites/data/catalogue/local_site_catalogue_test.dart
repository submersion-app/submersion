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
import 'package:submersion/features/dive_sites/domain/entities/catalogue_bounds.dart';
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

  /// A catalogue of just [sites], for a test that needs its own.
  Future<LocalSiteCatalogue> catalogueOf(List<Object?> sites) async {
    final db = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);
    await SiteCatalogueImporter(
      database: db,
      bundle: _Bundle(
        jsonEncode({
          'metadata': {'format': 2, 'sources': <String, Object?>{}},
          'sites': sites,
        }),
      ),
    ).importIfChanged();
    return LocalSiteCatalogue(database: db);
  }

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

    test('lists matches by name, ignoring case and accents', () async {
      // SQLite compares text byte by byte: left to the raw name, every
      // lowercase and accented name would come after "Zenobia".
      final named = LocalCacheDatabase(
        NativeDatabase.memory(setup: registerAppSqlFunctions),
      );
      addTearDown(named.close);
      await SiteCatalogueImporter(
        database: named,
        bundle: _Bundle(
          jsonEncode({
            'metadata': {'format': 2, 'sources': <String, Object?>{}},
            'sites': [
              _site('z', 'Zenobia', country: 'Testland'),
              _site('l', 'little shark', country: 'Testland'),
              _site('e', 'Épave du Donator', country: 'Testland'),
              _site('bd', 'Blue Hole Dahab', country: 'Testland'),
              _site('b', 'Blue Hole', country: 'Testland'),
            ],
          }),
        ),
      ).importIfChanged();

      final found = await LocalSiteCatalogue(
        database: named,
      ).search('testland');

      expect(found.map((s) => s.name), [
        'Blue Hole',
        'Blue Hole Dahab',
        'Épave du Donator',
        'little shark',
        'Zenobia',
      ]);
    });

    group('order', () {
      // A sea holds hundreds of sites, and its name is made of common
      // words: "sea", "north", "red". A site matched by its own name must
      // not be buried under every site of such a sea.
      Map<String, Object?> at(
        String id,
        String name, {
        required double lat,
        required double lon,
        String? sea,
        String? country,
      }) => {
        ..._site(id, name, lat: lat, lon: lon, country: country),
        'body_of_water': ?sea,
      };

      test(
        'a site matched by name comes before one matched by place',
        () async {
          final seas = await catalogueOf([
            at('abu', 'Abu Dabab', lat: 25.3, lon: 34.7, sea: 'Red Sea'),
            at('elph', 'Elphinstone', lat: 25.3, lon: 34.9, sea: 'Red Sea'),
            at('tiger', 'Sea Tiger', lat: 21.3, lon: -157.9),
            at('zulu', 'Zulu Sea Mount', lat: 1, lon: 1),
          ]);

          expect(idsOf(await seas.search('sea')), [
            'tiger',
            'zulu',
            'abu',
            'elph',
          ]);
        },
      );

      test(
        'every word has to be in the name to count as a name match',
        () async {
          final seas = await catalogueOf([
            at('hole', 'Blue Hole', lat: 28.5, lon: 34.5, country: 'Egypt'),
            at('reef', 'Blue Egypt Reef', lat: 1, lon: 1),
            at('azure', 'Azure Blue', lat: 2, lon: 2, country: 'Egypt'),
          ]);

          expect(idsOf(await seas.search('blue egypt')), [
            'reef',
            'azure',
            'hole',
          ]);
        },
      );

      test(
        'the limit keeps the name match, not the first by alphabet',
        () async {
          final seas = await catalogueOf([
            for (var i = 0; i < 60; i++)
              at(
                'in_$i',
                'Alpha ${i.toString().padLeft(2, '0')}',
                lat: 25.0 + i / 1000,
                lon: 34.7,
                sea: 'Red Sea',
              ),
            at('tiger', 'Sea Tiger', lat: 21.3, lon: -157.9),
          ]);

          final found = await seas.search('sea', limit: 50);

          expect(found, hasLength(50));
          expect(found.first.id, 'tiger');
        },
      );

      test('names first, the area leading within each', () async {
        // The dive is in the Red Sea, off Marsa Alam.
        const marsaAlam = GeoPoint(25.3, 34.7);
        final seas = await catalogueOf([
          at('abu', 'Abu Dabab', lat: 25.3, lon: 34.7, sea: 'Red Sea'),
          at('local', 'Sea Horse Bay', lat: 25.31, lon: 34.71, sea: 'Red Sea'),
          at('tiger', 'Sea Tiger', lat: 21.3, lon: -157.9),
          at('yanbu', 'Yanbu Wall', lat: 24.0, lon: 38.0, sea: 'Red Sea'),
        ]);

        expect(idsOf(await seas.search('sea', areaFirst: marsaAlam)), [
          // Named "Sea ...": the one in the dive's area, then elsewhere.
          'local',
          'tiger',
          // In a sea of that name only: the dive's area, then elsewhere.
          'abu',
          'yanbu',
        ]);
      });
    });

    group('a country named in another language', () {
      // The catalogue names countries in English. A diver types the name
      // their own language gives the country, so a query that names a
      // country finds the sites carrying that country's code (#4520).
      Map<String, Object?> inCountry(
        String id,
        String name,
        String code,
        String country, {
        double? lat,
        double? lon,
      }) => {
        ..._site(id, name, lat: lat, lon: lon, country: country),
        'country_code': code,
      };

      late LocalSiteCatalogue countries;
      setUp(() async {
        countries = await catalogueOf([
          inCountry('th', 'Sail Rock', 'TH', 'Thailand'),
          inCountry('eg', 'Ras Mohammed', 'EG', 'Egypt', lat: 27.7, lon: 34.2),
          inCountry('dahab', 'The Canyon', 'EG', 'Egypt', lat: 28.5, lon: 34.5),
          inCountry('ch', 'Lac Leman', 'CH', 'Switzerland'),
          inCountry('fr', 'Egypte Express', 'FR', 'France'),
          // No code: only its own words can find it.
          _site('uncoded', 'Thai Wall'),
        ]);
      });

      test('finds the sites of a country by its name in the diver\'s '
          'language', () async {
        expect(idsOf(await countries.search('Thaïlande')), ['th']);
        expect(idsOf(await countries.search('ประเทศไทย')), ['th']);
        expect(idsOf(await countries.search('Schweiz')), ['ch']);
      });

      test('finds them while the name is still being typed', () async {
        // Not "Thaïl": folded, that is already part of "thailand".
        expect(idsOf(await countries.search('Ägypt')), ['eg', 'dahab']);
      });

      test('still finds a country by the name the catalogue holds', () async {
        expect(idsOf(await countries.search('Switzerland')), ['ch']);
      });

      test('a site named for the word comes before the country\'s '
          'sites', () async {
        expect(idsOf(await countries.search('Égypte')), ['fr', 'eg', 'dahab']);
      });

      test('the dive\'s area leads among the country\'s sites', () async {
        const dahab = GeoPoint(28.5, 34.5);

        expect(idsOf(await countries.search('Ägypten', areaFirst: dahab)), [
          'dahab',
          'eg',
        ]);
      });

      test('a site with no country code is found by its own words '
          'only', () async {
        expect(idsOf(await countries.search('thai')), ['uncoded', 'th']);
        expect(
          idsOf(await countries.search('Thaïlande')),
          isNot(contains('uncoded')),
        );
      });

      test('a query that names no country finds no country\'s sites', () async {
        expect(await countries.search('Atlantis'), isEmpty);
      });
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

  group('by kind', () {
    // Around Scapa Flow: two dive sites and three charted wrecks, each a
    // known distance north of the point, plus one wreck far away.
    const scapa = GeoPoint(58.9, -3.1);
    Map<String, Object?> at(
      String id,
      String name,
      double northMeters, {
      bool register = false,
      double lon = -3.1,
    }) => {
      'id': id,
      'name': name,
      'lat': 58.9 + northMeters / 111194.93,
      'lon': lon,
      if (register) 'kind': 'register',
      'source': 'osm',
      'trust': 'verified',
    };

    Future<LocalSiteCatalogue> scapaCatalogue() => catalogueOf([
      at('site_far', 'Inganess Bay', 9000),
      at('site_near', 'Churchill Barrier', 2000),
      at('wreck_near', 'SMS Karlsruhe', 100, register: true),
      at('wreck_mid', 'SMS Brummer', 1400, register: true),
      at('wreck_far', 'SMS Dresden', 4000, register: true),
      at('wreck_away', 'SMS Elsewhere', 400000, register: true),
    ]);

    test('near returns one kind when asked for it, both when not', () async {
      final catalogue = await scapaCatalogue();

      expect(
        idsOf(
          await catalogue.near(
            scapa,
            radiusMeters: 50000,
            kind: CatalogueKind.site,
          ),
        ),
        ['site_near', 'site_far'],
      );
      expect(
        idsOf(
          await catalogue.near(
            scapa,
            radiusMeters: 50000,
            kind: CatalogueKind.register,
          ),
        ),
        ['wreck_near', 'wreck_mid', 'wreck_far'],
      );
      expect(idsOf(await catalogue.near(scapa, radiusMeters: 50000)), [
        'wreck_near',
        'wreck_mid',
        'site_near',
        'wreck_far',
        'site_far',
      ]);
    });

    test('the limit applies within the kind asked for', () async {
      final catalogue = await scapaCatalogue();

      expect(
        idsOf(
          await catalogue.near(
            scapa,
            radiusMeters: 50000,
            limit: 1,
            kind: CatalogueKind.site,
          ),
        ),
        ['site_near'],
      );
    });

    test('countNear counts one kind by real distance', () async {
      final catalogue = await scapaCatalogue();

      expect(
        await catalogue.countNear(
          scapa,
          radiusMeters: 50000,
          kind: CatalogueKind.register,
        ),
        3,
      );
      expect(
        await catalogue.countNear(
          scapa,
          radiusMeters: 500,
          kind: CatalogueKind.register,
        ),
        1,
      );
      expect(
        await catalogue.countNear(
          scapa,
          radiusMeters: 50000,
          kind: CatalogueKind.site,
        ),
        2,
      );
    });

    test('countNear leaves out the corners of the box', () async {
      // 1,300 m north and 1,300 m east: inside the box of a 1,500 m
      // circle, 1,838 m from its centre.
      final catalogue = await catalogueOf([
        at('corner', 'Corner Wreck', 1300, register: true, lon: -3.0774),
      ]);

      expect(
        await catalogue.countNear(
          scapa,
          radiusMeters: 1500,
          kind: CatalogueKind.register,
        ),
        0,
      );
      expect(
        await catalogue.countNear(
          scapa,
          radiusMeters: 2000,
          kind: CatalogueKind.register,
        ),
        1,
      );
    });

    test('search puts dive sites before register records that match '
        'as well', () async {
      final catalogue = await catalogueOf([
        at('wreck_a', 'Alpha Reef', 400000, register: true),
        at('site_b', 'Beta Reef', 400000),
        at('wreck_c', 'Gamma Reef', 400000, register: true),
        at('site_d', 'Delta Reef', 400000),
      ]);

      expect(idsOf(await catalogue.search('reef')), [
        'site_b',
        'site_d',
        'wreck_a',
        'wreck_c',
      ]);
    });

    test('a register record named for the word still comes before a dive '
        'site that is only in a place of that name', () async {
      final catalogue = await catalogueOf([
        {...at('site', 'Somewhere', 400000), 'region': 'Orkney'},
        at('wreck', 'Orkney Trader', 400000, register: true),
      ]);

      expect(idsOf(await catalogue.search('orkney')), ['wreck', 'site']);
    });

    test('in a search the area still leads within each kind', () async {
      final catalogue = await catalogueOf([
        at('site_away', 'Away Reef', 400000),
        at('wreck_here', 'Here Reef', 100, register: true),
        at('site_here', 'Local Reef', 200),
      ]);

      expect(idsOf(await catalogue.search('reef', areaFirst: scapa)), [
        'site_here',
        'wreck_here',
        'site_away',
      ]);
    });
  });

  group('inBounds', () {
    const box = CatalogueBounds(south: 58, west: -4, north: 60, east: -2);
    Map<String, Object?> at(
      String id,
      double lat,
      double lon, {
      bool register = false,
    }) => {
      'id': id,
      'name': id,
      'lat': lat,
      'lon': lon,
      if (register) 'kind': 'register',
      'source': 'osm',
      'trust': 'verified',
    };

    test('returns the sites in the box and no others', () async {
      final catalogue = await catalogueOf([
        at('inside', 59, -3),
        at('wreck_inside', 59.5, -2.5, register: true),
        at('north', 61, -3),
        at('west', 59, -5),
        {'id': 'nowhere', 'name': 'x', 'source': 'osm', 'trust': 'verified'},
      ]);

      final result = await catalogue.inBounds(box);

      expect(idsOf(result.sites).toSet(), {'inside', 'wreck_inside'});
      expect(result.truncated, isFalse);
    });

    test('over the limit, dive sites come first, then the register '
        'records nearest the centre', () async {
      final catalogue = await catalogueOf([
        at('wreck_edge', 59.9, -2.1, register: true),
        at('wreck_centre', 59.01, -3.01, register: true),
        at('site_a', 58.2, -3.8),
        at('site_b', 59.8, -2.2),
        at('wreck_mid', 59.4, -3.4, register: true),
      ]);

      final result = await catalogue.inBounds(box, limit: 3);

      expect(idsOf(result.sites).toSet(), {'site_a', 'site_b', 'wreck_centre'});
      expect(result.truncated, isTrue);

      final all = await catalogue.inBounds(box, limit: 5);
      expect(all.sites, hasLength(5));
      expect(all.truncated, isFalse);
    });

    test('more dive sites than the limit is cut short too', () async {
      final catalogue = await catalogueOf([
        at('site_a', 58.2, -3.8),
        at('site_b', 59.8, -2.2),
        at('site_c', 59, -3),
      ]);

      final result = await catalogue.inBounds(box, limit: 2);

      expect(result.sites, hasLength(2));
      expect(result.truncated, isTrue);
    });

    test('a box across the antimeridian holds both sides', () async {
      const seam = CatalogueBounds(
        south: -18,
        west: 179,
        north: -16,
        east: -179,
      );
      final catalogue = await catalogueOf([
        at('fiji_west', -16.8, 179.95),
        at('fiji_east', -16.8, -179.95),
        at('fiji_far', -16.8, 178.0),
        at('wreck_east', -17, -179.5, register: true),
      ]);

      final result = await catalogue.inBounds(seam);

      expect(idsOf(result.sites).toSet(), {
        'fiji_west',
        'fiji_east',
        'wreck_east',
      });
      expect(seam.center.longitude.abs(), closeTo(180, 0.001));
    });

    test('the whole world is one box', () async {
      const world = CatalogueBounds(
        south: -90,
        west: -180,
        north: 90,
        east: 180,
      );

      final result = await catalogue.inBounds(world, limit: 1000);

      expect(result.sites, hasLength(11));
      expect(idsOf(result.sites), isNot(contains('nowhere')));
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
    expect(
      await unopened.countNear(
        _saltPier,
        radiusMeters: 50000,
        kind: CatalogueKind.register,
      ),
      0,
    );
    final bounds = await unopened.inBounds(
      const CatalogueBounds(south: 0, west: 0, north: 1, east: 1),
    );
    expect(bounds.sites, isEmpty);
    expect(bounds.truncated, isFalse);
  });
}
