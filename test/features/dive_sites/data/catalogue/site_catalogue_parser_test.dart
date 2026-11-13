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

  group('catalogueSearchText', () {
    test('folds name, country, region, locality and island', () {
      const site = CatalogueSite(
        id: 'a',
        name: 'Cancún',
        country: 'México',
        region: 'Quintana Roo',
        locality: 'Puerto Juárez',
        island: 'Isla Mujeres',
        source: 'osm',
      );

      expect(
        catalogueSearchText(site),
        normalize('Cancún México Quintana Roo Puerto Juárez Isla Mujeres'),
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

      expect(catalogueSearchText(site), normalize('Blue Hole Dahab'));
    });
  });
}
