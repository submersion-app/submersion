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
  });
}
