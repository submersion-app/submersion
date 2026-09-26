import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/csv/extractors/dive_extractor.dart';
import 'package:submersion/features/universal_import/data/csv/extractors/site_extractor.dart';
import 'package:submersion/features/universal_import/data/csv/models/import_configuration.dart';
import 'package:submersion/features/universal_import/data/csv/models/transformed_rows.dart';
import 'package:submersion/features/universal_import/data/csv/pipeline/csv_correlator.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';

/// The CSV importer's half of the shared location contract (#2212, #2232).
///
/// `SiteExtractor` required a non-empty `siteName` before it read `gps`, and
/// `gps` was not among the fields `DiveExtractor` copies, so a row that
/// recorded where the dive happened but not what the place is called lost the
/// coordinates twice over.
void main() {
  Map<String, dynamic> row({String? siteName, String? gps}) =>
      <String, dynamic>{
        'dateTime': DateTime.utc(2025, 3, 15, 9, 5),
        'maxDepth': 20.0,
        'siteName': ?siteName,
        'gps': ?gps,
      };

  group('SiteExtractor', () {
    test('keeps a row with coordinates and no site name', () {
      final sites = SiteExtractor().extractFromRows([
        row(gps: '20.2114 -87.4654'),
      ]);

      expect(sites, hasLength(1));
      expect(sites.single['name'], '20.211400, -87.465400');
      expect(sites.single['latitude'], 20.2114);
      expect(sites.single['longitude'], -87.4654);
    });

    test('keeps a row whose site name is blank rather than absent', () {
      final sites = SiteExtractor().extractFromRows([
        row(siteName: '   ', gps: '20.2114 -87.4654'),
      ]);

      expect(sites.single['name'], '20.211400, -87.465400');
    });

    test('deduplicates two nameless rows at the same place', () {
      final sites = SiteExtractor().extractFromRows([
        row(gps: '20.2114 -87.4654'),
        row(gps: '20.2114 -87.4654'),
      ]);

      expect(sites, hasLength(1));
    });

    test('drops a row with neither a name nor readable coordinates', () {
      expect(SiteExtractor().extractFromRows([row()]), isEmpty);
      expect(SiteExtractor().extractFromRows([row(gps: 'not a fix')]), isEmpty);
    });

    test('a named row still wins its own name', () {
      final sites = SiteExtractor().extractFromRows([
        row(siteName: 'Dos Ojos', gps: '20.2114 -87.4654'),
      ]);

      expect(sites.single['name'], 'Dos Ojos');
    });

    test('siteIdForRow finds the site a nameless row created', () {
      final extractor = SiteExtractor();
      final nameless = row(gps: '20.2114 -87.4654');
      final sites = extractor.extractFromRows([nameless]);

      expect(extractor.siteIdForRow(nameless), sites.single['id']);
    });

    test('siteIdForRow still resolves a named row', () {
      final extractor = SiteExtractor();
      final named = row(siteName: 'Dos Ojos');
      final sites = extractor.extractFromRows([named]);

      expect(extractor.siteIdForRow(named), sites.single['id']);
    });
  });

  group('DiveExtractor', () {
    test('carries the row\'s coordinates onto the dive', () {
      final dive = const DiveExtractor().extract(row(gps: '20.2114 -87.4654'));

      expect(dive['latitude'], 20.2114);
      expect(dive['longitude'], -87.4654);
    });

    test('does not persist a pair the contract rejects', () {
      // `SiteExtractor` already drops these, so a dive that kept them would
      // contradict the site built from the same cell.
      for (final gps in const ['0 0', '91.5 -87.4654', '20.2114 181.0']) {
        final dive = const DiveExtractor().extract(row(gps: gps));
        expect(dive.containsKey('latitude'), isFalse, reason: gps);
        expect(dive.containsKey('longitude'), isFalse, reason: gps);
      }
    });

    test('leaves the dive without coordinates when gps is unreadable', () {
      final dive = const DiveExtractor().extract(row(gps: 'not a fix'));

      expect(dive.containsKey('latitude'), isFalse);
      expect(dive.containsKey('longitude'), isFalse);
    });
  });

  group('CsvCorrelator', () {
    test('links a nameless row\'s dive to its coordinate-named site', () {
      final nameless = row(gps: '20.2114 -87.4654');
      final payload = const CsvCorrelator().correlate(
        diveListRows: TransformedRows(rows: [nameless]),
        config: const ImportConfiguration(
          mappings: {},
          entityTypesToImport: {ImportEntityType.dives, ImportEntityType.sites},
        ),
      );

      final site = payload.entities[ImportEntityType.sites]!.single;
      final dive = payload.entities[ImportEntityType.dives]!.single;
      expect(dive['siteId'], site['id']);
    });

    test('a dive keeps its own coordinates when sites are not imported', () {
      final payload = const CsvCorrelator().correlate(
        diveListRows: TransformedRows(rows: [row(gps: '20.2114 -87.4654')]),
        config: const ImportConfiguration(
          mappings: {},
          entityTypesToImport: {ImportEntityType.dives},
        ),
      );

      expect(payload.entities[ImportEntityType.sites], isNull);
      final dive = payload.entities[ImportEntityType.dives]!.single;
      expect(dive['latitude'], 20.2114);
      expect(dive['longitude'], -87.4654);
    });
  });
}
