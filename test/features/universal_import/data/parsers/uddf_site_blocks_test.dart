import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/uddf_import_parser.dart';

import '../../../../helpers/test_database.dart';

/// Where UDDF sites are declared, and where a dive may point at them (#2209).
///
/// The site table used to be read from the first `<divesite>` block only, so
/// a file carrying a second block lost every site in it, and every dive that
/// linked one imported with no site. A dive's links were also read only when
/// it had an `<informationbeforedive>`, even the ones UDDF allows directly
/// under `<dive>`.
void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  Future<ImportPayload> parse(String uddf) =>
      UddfImportParser().parse(Uint8List.fromList(utf8.encode(uddf)));

  Iterable<ImportWarning> unresolved(ImportPayload payload) => payload.warnings
      .where((w) => w.code == ImportWarningCode.sitesUnresolved);

  String document({required String siteBlocks, required String dive}) =>
      '''<?xml version="1.0" encoding="UTF-8" ?>
<uddf version="3.2.0">
  $siteBlocks
  <profiledata>
    <repetitiongroup id="rg-1">
      $dive
    </repetitiongroup>
  </profiledata>
</uddf>''';

  String diveLinking(String ref) =>
      '''<dive id="d-1">
        <informationbeforedive>
          <link ref="$ref" />
          <datetime>2024-06-01T09:00:00</datetime>
        </informationbeforedive>
        <informationafterdive>
          <greatestdepth>18.0</greatestdepth>
          <diveduration>2400</diveduration>
        </informationafterdive>
      </dive>''';

  group('a file with two <divesite> blocks', () {
    const twoBlocks =
        '<divesite><site id="s1"><name>North Reef</name></site></divesite>'
        '<divesite><site id="s2"><name>South Wall</name></site></divesite>';

    test('imports the sites from both', () async {
      final payload = await parse(
        document(siteBlocks: twoBlocks, dive: diveLinking('s1')),
      );

      expect(
        payload.entitiesOf(ImportEntityType.sites).map((s) => s['name']),
        unorderedEquals(['North Reef', 'South Wall']),
      );
    });

    test('resolves a dive linking a site in the second block', () async {
      final payload = await parse(
        document(siteBlocks: twoBlocks, dive: diveLinking('s2')),
      );

      final dive = payload.entitiesOf(ImportEntityType.dives).single;
      expect((dive['site'] as Map<String, dynamic>)['name'], 'South Wall');
      expect(unresolved(payload), isEmpty);
    });
  });

  group('a <site> with no id', () {
    // UDDF requires the id, so no dive can ever link to this site. It is
    // kept anyway: a logbook's site list holds places never dived, and a
    // named place with coordinates is worth more than the malformed id.
    test('is still imported as a site', () async {
      final payload = await parse(
        document(
          siteBlocks:
              '<divesite><site><name>Blue Hole</name><geography>'
              '<latitude>17.3160</latitude><longitude>-87.5347</longitude>'
              '</geography></site></divesite>',
          dive: diveLinking('s-missing'),
        ),
      );

      final site = payload.entitiesOf(ImportEntityType.sites).single;
      expect(site['name'], 'Blue Hole');
      expect(site['latitude'], 17.3160);
      expect(site.containsKey('uddfId'), isFalse);
      // The dive's link names nothing the file declares, which is still
      // reported rather than guessed at.
      final dive = payload.entitiesOf(ImportEntityType.dives).single;
      expect(dive['site'], isNull);
      expect(unresolved(payload).single.count, 1);
    });
  });

  group('a dive with no <informationbeforedive>', () {
    String diveWithOnlyDirectLink(String ref) =>
        '''<dive id="d-1">
        <link ref="$ref" />
        <informationafterdive>
          <greatestdepth>18.0</greatestdepth>
          <diveduration>2400</diveduration>
        </informationafterdive>
      </dive>''';

    test('resolves a site linked directly under <dive>', () async {
      final payload = await parse(
        document(
          siteBlocks:
              '<divesite><site id="s1"><name>North Reef</name></site>'
              '</divesite>',
          dive: diveWithOnlyDirectLink('s1'),
        ),
      );

      final dive = payload.entitiesOf(ImportEntityType.dives).single;
      expect((dive['site'] as Map<String, dynamic>)['uddfId'], 's1');
      expect(unresolved(payload), isEmpty);
    });

    test('raises the notice when that link does not resolve', () async {
      final payload = await parse(
        document(
          siteBlocks: '<divesite></divesite>',
          dive: diveWithOnlyDirectLink('s-missing'),
        ),
      );

      expect(unresolved(payload).single.count, 1);
    });
  });
}
