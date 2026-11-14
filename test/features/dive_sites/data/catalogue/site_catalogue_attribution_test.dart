import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
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

  /// The licence entry as one text, its line breaks folded.
  Future<String> licenceText() async {
    SiteCatalogueAttribution.registerLicense();
    final entries = await LicenseRegistry.licenses
        .where((entry) => entry.packages.contains('Dive site data'))
        .toList();
    return entries.last.paragraphs.map((p) => p.text).join('\n');
  }

  test('every source the shipped catalogue declares is credited with its '
      'licence', () async {
    // Read from the file, so a source added later without a credit fails
    // here.
    final doc =
        jsonDecode(
              File(
                p.join('assets', 'data', 'site_catalogue.json'),
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final sources =
        (doc['metadata'] as Map<String, dynamic>)['sources']
            as Map<String, dynamic>;
    final text = await licenceText();

    expect(sources, isNotEmpty);
    for (final MapEntry(:key, :value) in sources.entries) {
      final source = value as Map<String, dynamic>;
      expect(text, contains(source['name'] as String), reason: key);
      expect(text, contains(source['licence_url'] as String), reason: key);
    }
  });

  test('each publisher\'s own required words are there', () async {
    final text = await licenceText();

    // The UK Hydrographic Office's attribution statement.
    expect(
      text,
      contains(
        'Contains public sector information, licensed under the Open '
        'Government Licence v3.0, from the UK Hydrographic Office.',
      ),
    );
    // New Jersey's credit and disclaimer, and that its metadata travels.
    expect(
      text,
      contains(
        'This application was developed using New Jersey Department of '
        'Environmental Protection Geographic Information System digital '
        'data, but this secondary product has not been verified by NJDEP '
        'and is not state-authorized or endorsed.',
      ),
    );
    expect(text, contains('assets/data/site_catalogue_njdep_metadata.xml'));
    // Florida asks to be named as the producer of its records.
    expect(text, contains('FWC-FWRI'));
    expect(text, contains('National Monuments Service'));
    expect(text, contains('not for navigation'));
  });

  test('every entry states its licence, the project\'s own sites '
      'included', () async {
    final text = await licenceText();

    // A source's name and link are not its licence: the Florida Keys
    // entry had neither a licence nor "public domain", and the sites the
    // project adds itself were credited only by the repository's name.
    expect(
      text,
      contains(
        'Marine Sanctuary. A work of the United States Government, in the '
        'public domain.',
      ),
    );
    expect(
      text,
      contains(
        'Sites added by the Submersion project '
        '(scripts/dive_sites_curated.json), under the Open Database '
        'License 1.0.',
      ),
    );
  });

  test('the sources kept apart from the ODbL database say so', () async {
    final text = await licenceText();

    expect(text, contains('not licensed under the ODbL'));
    for (final publisher in [
      'New Jersey Department of Environmental Protection',
      'Division of Aquatic Resources',
      'Texas Parks and Wildlife Department',
      'N.C. Division of Marine Fisheries',
    ]) {
      expect(text, contains(publisher));
    }
    expect(text, contains('may not be used commercially'));
    expect(text, contains('without alteration'));
  });

  test('the credit is filed under one heading', () {
    expect(SiteCatalogueAttribution.packageName, 'Dive site data');
  });
}
