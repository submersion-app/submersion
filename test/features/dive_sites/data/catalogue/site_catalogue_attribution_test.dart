import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_attribution.dart';

/// The built-in dive sites come from OpenStreetMap, under the Open Database
/// License: shipping them means carrying the credit and saying the licence.
void main() {
  test(
    'the licence page credits OpenStreetMap and names the licence',
    () async {
      SiteCatalogueAttribution.registerLicense();

      final entries = await LicenseRegistry.licenses
          .where((entry) => entry.packages.contains('Dive site data'))
          .toList();

      expect(entries, isNotEmpty);
      final text = entries.last.paragraphs.map((p) => p.text).join('\n');
      expect(text, contains('OpenStreetMap contributors'));
      expect(text, contains('Open Database'));
      expect(text, contains('(ODbL)'));
      expect(text, contains('https://www.openstreetmap.org/copyright'));
      expect(text, contains('assets/data/site_catalogue.json'));
      // The licence itself, and where the database is offered.
      expect(text, contains('https://opendatacommons.org/licenses/odbl/1-0/'));
      expect(text, contains('https://github.com/submersion-app/submersion'));
    },
  );

  test('the credit is filed under one heading', () {
    expect(SiteCatalogueAttribution.packageName, 'Dive site data');
  });
}
