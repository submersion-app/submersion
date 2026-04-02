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

    test('returns site ID mapping via siteIdForName', () {
      final rows = <Map<String, dynamic>>[
        {'siteName': 'Blue Hole'},
      ];

      extractor.extractFromRows(rows);

      final id = extractor.siteIdForName('Blue Hole');
      expect(id, isNotNull);
      expect(id, isA<String>());
    });

    test('siteIdForName is case-insensitive', () {
      final rows = <Map<String, dynamic>>[
        {'siteName': 'Blue Hole'},
      ];

      extractor.extractFromRows(rows);

      final id1 = extractor.siteIdForName('Blue Hole');
      final id2 = extractor.siteIdForName('blue hole');
      expect(id1, id2);
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

    test('siteIdForName returns null for unseen site name', () {
      final rows = <Map<String, dynamic>>[
        {'siteName': 'Blue Hole'},
      ];

      extractor.extractFromRows(rows);

      expect(extractor.siteIdForName('Unknown Site'), isNull);
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
  });
}
