import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/text/fuzzy_match.dart';
import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_parser.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

String _file(List<Object?> sites, {Map<String, Object?>? sources}) =>
    jsonEncode({
      'metadata': {
        'format': 2,
        'sources':
            sources ??
            {
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

Map<String, Object?> _site([Map<String, Object?> overrides = const {}]) => {
  'id': 'osm_node_1',
  'name': 'Salt Pier',
  'source': 'osm',
  'trust': 'verified',
  ...overrides,
};

void main() {
  group('parseSiteCatalogue', () {
    test('a full record parses', () {
      final parsed = parseSiteCatalogue(
        _file([
          {
            'id': 'osm_node_1',
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
            'entry': ['shore'],
            'features': ['drift'],
            'difficulty': 'beginner',
            'hazards': 'boat traffic',
            'description': 'Pillars.',
            'website': 'https://example.org',
            'source': 'osm',
            'source_ref': 'https://www.openstreetmap.org/node/1',
            'trust': 'verified',
          },
        ]),
      );

      expect(parsed.format, 2);
      expect(
        parsed.sources.single,
        const CatalogueSource(
          key: 'osm',
          name: 'OpenStreetMap',
          licence: 'ODbL-1.0',
          licenceUrl: 'https://www.openstreetmap.org/copyright',
          credit: 'OpenStreetMap contributors',
        ),
      );
      expect(
        parsed.sites.single,
        const CatalogueSite(
          id: 'osm_node_1',
          name: 'Salt Pier',
          location: GeoPoint(12.08, -68.28),
          countryCode: 'BQ',
          country: 'Caribbean Netherlands',
          region: 'Kralendijk',
          locality: 'Belnem',
          island: 'Bonaire',
          bodyOfWater: 'Caribbean Sea',
          waterType: WaterType.salt,
          minDepth: 5,
          maxDepth: 15.5,
          typeIds: ['reef', 'pier'],
          entryMethods: [EntryMethod.shore],
          features: ['drift'],
          difficulty: SiteDifficulty.beginner,
          hazards: 'boat traffic',
          description: 'Pillars.',
          website: 'https://example.org',
          source: 'osm',
          sourceRef: 'https://www.openstreetmap.org/node/1',
        ),
      );
    });

    test('a record with only the required fields parses', () {
      final parsed = parseSiteCatalogue(_file([_site()]));

      expect(
        parsed.sites.single,
        const CatalogueSite(id: 'osm_node_1', name: 'Salt Pier', source: 'osm'),
      );
    });

    test('unknown names are dropped, the record is kept', () {
      final parsed = parseSiteCatalogue(
        _file([
          _site({
            'water_type': 'acid',
            'entry': ['shore', 'teleport'],
            'types': ['reef', 'volcano'],
            'difficulty': 'heroic',
            'trust': 'rumour',
          }),
        ]),
      );

      final site = parsed.sites.single;
      expect(site.waterType, isNull);
      expect(site.entryMethods, [EntryMethod.shore]);
      expect(site.typeIds, ['reef']);
      expect(site.difficulty, isNull);
      expect(site.trust, CatalogueTrust.verified);
    });

    test('a register record says so, and anything else is a dive site', () {
      final parsed = parseSiteCatalogue(
        _file([
          _site({'id': 'ukho_1', 'kind': 'register'}),
          _site({'id': 'osm_node_2'}),
          _site({'id': 'osm_node_3', 'kind': 'site'}),
          _site({'id': 'osm_node_4', 'kind': 'something new'}),
          _site({'id': 'osm_node_5', 'kind': 7}),
        ]),
      );

      expect(parsed.sites.map((s) => s.kind), [
        CatalogueKind.register,
        CatalogueKind.site,
        CatalogueKind.site,
        CatalogueKind.site,
        CatalogueKind.site,
      ]);
    });

    test('a researched record keeps its trust level', () {
      final parsed = parseSiteCatalogue(
        _file([
          _site({'trust': 'researched'}),
        ]),
      );

      expect(parsed.sites.single.trust, CatalogueTrust.researched);
    });

    test('a record without an id or a name is skipped', () {
      final parsed = parseSiteCatalogue(
        _file([
          {'name': 'No id', 'source': 'osm'},
          {'id': 'osm_node_2', 'source': 'osm'},
          {'id': 'osm_node_3', 'name': '  ', 'source': 'osm'},
          'not a record',
          null,
          _site(),
        ]),
      );

      expect(parsed.sites.map((s) => s.id), ['osm_node_1']);
    });

    test('a record without a source is skipped', () {
      final parsed = parseSiteCatalogue(
        _file([
          {'id': 'osm_node_2', 'name': 'Sourceless'},
          _site(),
        ]),
      );

      expect(parsed.sites.map((s) => s.id), ['osm_node_1']);
    });

    test('a number given as a string does not break the file', () {
      final parsed = parseSiteCatalogue(
        _file([
          _site({'lat': '12.08', 'lon': -68.28, 'max_depth_m': 'deep'}),
          _site({'id': 'osm_node_2', 'name': 'Other', 'lat': 1, 'lon': 2}),
        ]),
      );

      expect(parsed.sites, hasLength(2));
      expect(parsed.sites.first.location, isNull);
      expect(parsed.sites.first.maxDepth, isNull);
      expect(parsed.sites.last.location, const GeoPoint(1, 2));
    });

    test('text where a list belongs is read as no list', () {
      final parsed = parseSiteCatalogue(
        _file([
          _site({'types': 'reef', 'entry': 7, 'features': null}),
        ]),
      );

      final site = parsed.sites.single;
      expect(site.typeIds, isEmpty);
      expect(site.entryMethods, isEmpty);
      expect(site.features, isEmpty);
    });

    test('a latitude without a longitude gives no location', () {
      final parsed = parseSiteCatalogue(
        _file([
          _site({'lat': 12.08}),
        ]),
      );

      expect(parsed.sites.single.location, isNull);
    });

    test('a coordinate outside the globe gives no location', () {
      final parsed = parseSiteCatalogue(
        _file([
          _site({'lat': 95.0, 'lon': 10.0}),
        ]),
      );

      expect(parsed.sites.single.location, isNull);
    });

    test('a source without a name is skipped', () {
      final parsed = parseSiteCatalogue(
        _file(
          [_site()],
          sources: {
            'osm': {'licence': 'ODbL-1.0'},
            'curated': {
              'name': 'Submersion',
              'licence': 'ODbL-1.0',
              'credit': 'Submersion contributors',
            },
          },
        ),
      );

      expect(parsed.sources.map((s) => s.key), ['curated']);
      expect(parsed.sources.single.licenceUrl, isNull);
    });

    test('text that is not JSON throws FormatException', () {
      expect(() => parseSiteCatalogue('not json'), throwsFormatException);
    });

    test('JSON without a sites list throws FormatException', () {
      expect(
        () => parseSiteCatalogue(jsonEncode({'metadata': {}})),
        throwsFormatException,
      );
      expect(
        () => parseSiteCatalogue(jsonEncode(['a', 'list'])),
        throwsFormatException,
      );
    });
  });

  group('naming the sea', () {
    test('a located record with no body of water takes the sea there', () {
      final asked = <(double, double)>[];
      final parsed = parseSiteCatalogue(
        _file([
          _site({'lat': 27.2, 'lon': 33.8}),
        ]),
        seaAt: (latitude, longitude) {
          asked.add((latitude, longitude));
          return 'Red Sea';
        },
      );

      expect(parsed.sites.single.bodyOfWater, 'Red Sea');
      expect(asked, [(27.2, 33.8)]);
    });

    test('a record keeps the body of water it came with', () {
      final parsed = parseSiteCatalogue(
        _file([
          _site({'lat': 28.5, 'lon': 34.5, 'body_of_water': 'Gulf of Aqaba'}),
        ]),
        seaAt: (_, _) => 'Red Sea',
      );

      expect(parsed.sites.single.bodyOfWater, 'Gulf of Aqaba');
    });

    test('a record with no position is not asked about', () {
      var asked = 0;
      final parsed = parseSiteCatalogue(
        _file([_site()]),
        seaAt: (_, _) {
          asked++;
          return 'Red Sea';
        },
      );

      expect(parsed.sites.single.bodyOfWater, isNull);
      expect(asked, 0);
    });

    test('fresh water near a coast is never given a sea', () {
      // The sea table reaches a few kilometres inland, to catch sites
      // recorded from a beach. A cenote or a lake that close to the coast
      // is still not in the sea.
      final parsed = parseSiteCatalogue(
        _file([
          _site({
            'id': 'cenote',
            'lat': 20.2,
            'lon': -87.4,
            'types': ['cenote'],
          }),
          _site({
            'id': 'lake',
            'lat': 54.3,
            'lon': 10.2,
            'types': ['wreck', 'lake'],
          }),
          _site({
            'id': 'fresh',
            'lat': 54.3,
            'lon': 10.2,
            'water_type': 'fresh',
          }),
          _site({
            'id': 'reef',
            'lat': 20.2,
            'lon': -87.4,
            'types': ['reef'],
          }),
        ]),
        seaAt: (_, _) => 'Caribbean Sea',
      );

      expect(
        {for (final site in parsed.sites) site.id: site.bodyOfWater},
        {'cenote': null, 'lake': null, 'fresh': null, 'reef': 'Caribbean Sea'},
      );
    });

    test('with no sea table nothing is named', () {
      final parsed = parseSiteCatalogue(
        _file([
          _site({'lat': 27.2, 'lon': 33.8}),
        ]),
      );

      expect(parsed.sites.single.bodyOfWater, isNull);
    });
  });

  group('catalogueSearchText', () {
    test('folds name, country, region, locality, island and sea', () {
      const site = CatalogueSite(
        id: 'a',
        name: 'Cancún',
        country: 'México',
        region: 'Quintana Roo',
        locality: 'Puerto Juárez',
        island: 'Isla Mujeres',
        bodyOfWater: 'Caribbean Sea',
        source: 'osm',
      );

      expect(
        catalogueSearchText(site),
        '${normalize('Cancún')}$kCatalogueNameEnd'
        '${normalize('México Quintana Roo Puerto Juárez Isla Mujeres '
        'Caribbean Sea')}',
      );
    });

    test('the name ends at a mark that sorts before any letter or space', () {
      // Ordering by this text is ordering by folded name: "Blue Hole" comes
      // before "Blue Hole Dahab" whatever places follow either name.
      const short = CatalogueSite(
        id: 'a',
        name: 'Blue Hole',
        country: 'Egypt',
        source: 'osm',
      );
      const long = CatalogueSite(
        id: 'b',
        name: 'Blue Hole Dahab',
        country: 'Belize',
        source: 'osm',
      );

      expect(
        catalogueSearchText(short).compareTo(catalogueSearchText(long)),
        isNegative,
      );
      expect(
        catalogueSearchText(short),
        startsWith('blue hole$kCatalogueNameEnd'),
      );
    });

    test('blank parts are dropped', () {
      const site = CatalogueSite(
        id: 'a',
        name: 'Blue Hole',
        country: '  ',
        region: 'Dahab',
        source: 'osm',
      );

      expect(catalogueSearchText(site), 'blue hole${kCatalogueNameEnd}dahab');
    });
  });
}
