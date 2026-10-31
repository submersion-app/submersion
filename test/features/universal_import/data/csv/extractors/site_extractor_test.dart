import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/extractors/site_extractor.dart';

void main() {
  late SiteExtractor extractor;

  setUp(() {
    extractor = SiteExtractor();
  });

  group('SiteExtractor', () {
    test('extracts unique sites by name', () {
      final rows = <Map<String, dynamic>>[
        {'siteName': 'Blue Hole'},
        {'siteName': 'Blue Hole'},
        {'siteName': 'The Wall'},
      ];

      final sites = extractor.extractFromRows(rows);

      expect(sites, hasLength(2));
      final names = sites.map((s) => s['name']).toList();
      expect(names, containsAll(['Blue Hole', 'The Wall']));
    });

    test('deduplicates case-insensitively', () {
      final rows = <Map<String, dynamic>>[
        {'siteName': 'Blue Hole'},
        {'siteName': 'blue hole'},
        {'siteName': 'BLUE HOLE'},
      ];

      final sites = extractor.extractFromRows(rows);

      expect(sites, hasLength(1));
    });

    test('extracts GPS coordinates in Subsurface lat lon format', () {
      final rows = <Map<String, dynamic>>[
        {'siteName': 'Blue Hole', 'gps': '24.0786 -76.1234'},
      ];

      final sites = extractor.extractFromRows(rows);

      expect(sites, hasLength(1));
      expect(sites[0]['latitude'], closeTo(24.0786, 0.0001));
      expect(sites[0]['longitude'], closeTo(-76.1234, 0.0001));
    });

    test('handles missing site name gracefully', () {
      final rows = <Map<String, dynamic>>[
        {'maxDepth': 25.0},
        {'siteName': null},
        {'siteName': ''},
      ];

      final sites = extractor.extractFromRows(rows);

      expect(sites, isEmpty);
    });

    test('returns the site ID of a row via siteIdForRow', () {
      final rows = <Map<String, dynamic>>[
        {'siteName': 'Blue Hole'},
      ];

      final sites = extractor.extractFromRows(rows);

      expect(extractor.siteIdForRow(rows.single), sites.single['id']);
    });

    test('siteIdForRow is case-insensitive', () {
      final rows = <Map<String, dynamic>>[
        {'siteName': 'Blue Hole'},
      ];

      final sites = extractor.extractFromRows(rows);

      expect(
        extractor.siteIdForRow({'siteName': 'blue hole'}),
        sites.single['id'],
      );
    });

    test('each site gets a unique UUID', () {
      final rows = <Map<String, dynamic>>[
        {'siteName': 'Blue Hole'},
        {'siteName': 'The Wall'},
      ];

      final sites = extractor.extractFromRows(rows);

      final id1 = sites[0]['id'] as String;
      final id2 = sites[1]['id'] as String;
      expect(id1, isNot(equals(id2)));
    });

    test('site has null GPS when gps field absent', () {
      final rows = <Map<String, dynamic>>[
        {'siteName': 'Blue Hole'},
      ];

      final sites = extractor.extractFromRows(rows);

      expect(sites[0]['latitude'], isNull);
      expect(sites[0]['longitude'], isNull);
    });

    test('each site has a uddfId matching its id', () {
      final rows = <Map<String, dynamic>>[
        {'siteName': 'Blue Hole'},
        {'siteName': 'The Wall'},
      ];

      final sites = extractor.extractFromRows(rows);

      expect(sites, hasLength(2));
      for (final site in sites) {
        expect(site['uddfId'], isNotNull);
        expect(site['uddfId'], equals(site['id']));
      }
    });

    test('handles GPS with extra whitespace', () {
      final rows = <Map<String, dynamic>>[
        {'siteName': 'Blue Hole', 'gps': '  24.0786   -76.1234  '},
      ];

      final sites = extractor.extractFromRows(rows);

      expect(sites, hasLength(1));
      expect(sites[0]['latitude'], closeTo(24.0786, 0.0001));
      expect(sites[0]['longitude'], closeTo(-76.1234, 0.0001));
    });

    test('returns null GPS for empty gps field', () {
      final rows = <Map<String, dynamic>>[
        {'siteName': 'Blue Hole', 'gps': ''},
      ];

      final sites = extractor.extractFromRows(rows);

      expect(sites, hasLength(1));
      expect(sites[0]['latitude'], isNull);
      expect(sites[0]['longitude'], isNull);
    });

    test('returns null GPS for whitespace-only gps field', () {
      final rows = <Map<String, dynamic>>[
        {'siteName': 'Blue Hole', 'gps': '   '},
      ];

      final sites = extractor.extractFromRows(rows);

      expect(sites, hasLength(1));
      expect(sites[0]['latitude'], isNull);
      expect(sites[0]['longitude'], isNull);
    });

    test('returns null GPS for single value (missing longitude)', () {
      final rows = <Map<String, dynamic>>[
        {'siteName': 'Blue Hole', 'gps': '24.0786'},
      ];

      final sites = extractor.extractFromRows(rows);

      expect(sites, hasLength(1));
      expect(sites[0]['latitude'], isNull);
      expect(sites[0]['longitude'], isNull);
    });

    test('returns null GPS for non-numeric values', () {
      final rows = <Map<String, dynamic>>[
        {'siteName': 'Blue Hole', 'gps': 'invalid location'},
      ];

      final sites = extractor.extractFromRows(rows);

      expect(sites, hasLength(1));
      expect(sites[0]['latitude'], isNull);
      expect(sites[0]['longitude'], isNull);
    });

    test('parses negative GPS coordinates', () {
      final rows = <Map<String, dynamic>>[
        {'siteName': 'South Reef', 'gps': '-33.8688 151.2093'},
      ];

      final sites = extractor.extractFromRows(rows);

      expect(sites, hasLength(1));
      expect(sites[0]['latitude'], closeTo(-33.8688, 0.0001));
      expect(sites[0]['longitude'], closeTo(151.2093, 0.0001));
    });

    test('siteIdForRow returns null for unseen site name', () {
      final rows = <Map<String, dynamic>>[
        {'siteName': 'Blue Hole'},
      ];

      extractor.extractFromRows(rows);

      expect(extractor.siteIdForRow({'siteName': 'Unknown Site'}), isNull);
    });

    test('GPS from first occurrence wins for deduped sites', () {
      final rows = <Map<String, dynamic>>[
        {'siteName': 'Blue Hole', 'gps': '24.0786 -76.1234'},
        {'siteName': 'Blue Hole', 'gps': '99.0 -99.0'},
      ];

      final sites = extractor.extractFromRows(rows);

      expect(sites, hasLength(1));
      expect(sites[0]['latitude'], closeTo(24.0786, 0.0001));
      expect(sites[0]['longitude'], closeTo(-76.1234, 0.0001));
    });

    test('carries city, region and country from the first occurrence', () {
      final rows = <Map<String, dynamic>>[
        {
          'siteName': 'Blue Hole',
          'siteCity': 'Victoria',
          'siteIsland': 'Comino',
          'siteRegion': 'Gozo',
          'siteCountry': 'Malta',
        },
        {'siteName': 'Blue Hole', 'siteCountry': 'MALTA'},
      ];

      final site = extractor.extractFromRows(rows).single;

      expect(site['city'], 'Victoria');
      expect(site['island'], 'Comino');
      expect(site['region'], 'Gozo');
      expect(site['country'], 'Malta');
    });

    group('same-name sites (#4015)', () {
      final dahab = <String, dynamic>{
        'siteName': 'Blue Hole',
        'siteCity': 'Dahab',
        'siteCountry': 'Egypt',
      };
      final belize = <String, dynamic>{
        'siteName': 'Blue Hole',
        'siteCity': 'Lighthouse Reef',
        'siteCountry': 'Belize',
      };

      test('rows that place a name differently are two sites', () {
        final sites = extractor.extractFromRows([dahab, belize]);

        expect(sites.map((s) => s['country']), ['Egypt', 'Belize']);
        expect(extractor.siteIdForRow(dahab), sites.first['id']);
        expect(extractor.siteIdForRow(belize), sites.last['id']);
        expect(sites.first['id'], isNot(sites.last['id']));
      });

      test('a row that leaves the place blank cannot tell them apart', () {
        final blank = <String, dynamic>{'siteName': 'Blue Hole'};

        final sites = extractor.extractFromRows([dahab, blank, belize]);

        expect(sites, hasLength(2));
        expect(extractor.siteIdForRow(blank), sites.first['id']);
      });

      test('a later row fills what the first left blank, and then decides '
          'the next one', () {
        final blank = <String, dynamic>{'siteName': 'Blue Hole'};

        final sites = extractor.extractFromRows([blank, dahab, belize]);

        expect(sites.map((s) => s['country']), ['Egypt', 'Belize']);
        expect(sites.first['city'], 'Dahab');
        expect(extractor.siteIdForRow(blank), sites.first['id']);
        expect(extractor.siteIdForRow(dahab), sites.first['id']);
        expect(extractor.siteIdForRow(belize), sites.last['id']);
      });
    });

    test('leaves out blank place fields', () {
      final rows = <Map<String, dynamic>>[
        {'siteName': 'Blue Hole', 'siteCity': '  ', 'siteCountry': 'Malta'},
      ];

      final site = extractor.extractFromRows(rows).single;

      expect(site.containsKey('city'), isFalse);
      expect(site.containsKey('region'), isFalse);
      expect(site['country'], 'Malta');
    });
  });
}
