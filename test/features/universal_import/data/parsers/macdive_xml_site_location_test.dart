import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/macdive_xml_parser.dart';

/// MacDive XML's half of the shared location contract (#2213, #2232).
///
/// The XML export carries a site inline on each dive, so there is no
/// dangling reference to resolve; only the nameless-site shape applies.
void main() {
  Uint8List xml(String siteBody) => Uint8List.fromList(
    utf8.encode('''<?xml version="1.0" encoding="UTF-8"?>
<dives>
    <units>Metric</units>
    <dive>
        <date>2024-06-01 09:00:00</date>
        <identifier>20240601090000-ABC123</identifier>
        <maxDepth>25.40</maxDepth>
        <duration>2400</duration>
        <site>$siteBody</site>
    </dive>
</dives>'''),
  );

  test(
    'a site with coordinates and no name survives under a coordinate name',
    () async {
      final payload = await const MacDiveXmlParser().parse(
        xml('<lat>20.2114</lat><lon>-87.4654</lon>'),
      );

      final site = payload.entitiesOf(ImportEntityType.sites).single;
      expect(site['name'], '20.211400, -87.465400');
      expect(site['latitude'], 20.2114);
      expect(site['longitude'], -87.4654);
    },
  );

  test('the dive links to the coordinate-named site', () async {
    final payload = await const MacDiveXmlParser().parse(
      xml('<lat>20.2114</lat><lon>-87.4654</lon>'),
    );

    final dive = payload.entitiesOf(ImportEntityType.dives).single;
    final ref = (dive['site'] as Map<String, dynamic>)['uddfId'];
    expect(ref, payload.entitiesOf(ImportEntityType.sites).single['uddfId']);
  });

  test('a named site still wins its own name', () async {
    final payload = await const MacDiveXmlParser().parse(
      xml('<name>Test Reef</name><lat>20.2114</lat><lon>-87.4654</lon>'),
    );

    expect(
      payload.entitiesOf(ImportEntityType.sites).single['name'],
      'Test Reef',
    );
  });

  test('a site with neither a name nor coordinates is dropped', () async {
    final payload = await const MacDiveXmlParser().parse(
      xml('<country>Mexico</country>'),
    );

    expect(payload.entitiesOf(ImportEntityType.sites), isEmpty);
    expect(payload.entitiesOf(ImportEntityType.dives).single['site'], isNull);
  });
}
