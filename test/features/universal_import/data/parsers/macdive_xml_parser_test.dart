import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/macdive_xml_parser.dart';

void main() {
  group('MacDiveXmlParser', () {
    late Uint8List bytes;

    setUpAll(() async {
      final content = await File(
        'test/fixtures/macdive_xml/metric_small.xml',
      ).readAsString();
      bytes = Uint8List.fromList(utf8.encode(content));
    });

    test('supportedFormats exposes macdiveXml', () {
      expect(const MacDiveXmlParser().supportedFormats, [
        ImportFormat.macdiveXml,
      ]);
    });

    test('produces one dive entity', () async {
      final payload = await const MacDiveXmlParser().parse(bytes);
      expect(payload.entitiesOf(ImportEntityType.dives).length, 1);
    });

    test('produces one site, one buddy, one equipment, two tags', () async {
      final payload = await const MacDiveXmlParser().parse(bytes);
      expect(payload.entitiesOf(ImportEntityType.sites).length, 1);
      expect(payload.entitiesOf(ImportEntityType.buddies).length, 1);
      expect(payload.entitiesOf(ImportEntityType.equipment).length, 1);
      expect(payload.entitiesOf(ImportEntityType.tags).length, 2);
    });

    test('dive carries sourceUuid from <identifier>', () async {
      final payload = await const MacDiveXmlParser().parse(bytes);
      final dive = payload.entitiesOf(ImportEntityType.dives).first;
      expect(dive['sourceUuid'], '20240601090000-ABC123');
    });

    test('dive carries tagRefs matching tag entity names', () async {
      final payload = await const MacDiveXmlParser().parse(bytes);
      final dive = payload.entitiesOf(ImportEntityType.dives).first;
      expect(dive['tagRefs'], containsAll(['Reef', 'Photography']));
      final tagNames = payload
          .entitiesOf(ImportEntityType.tags)
          .map((t) => t['name'] as String)
          .toSet();
      expect(tagNames, containsAll(['Reef', 'Photography']));
    });

    test('dive carries site data (siteName + dive map refs)', () async {
      final payload = await const MacDiveXmlParser().parse(bytes);
      final dive = payload.entitiesOf(ImportEntityType.dives).first;
      final site = payload.entitiesOf(ImportEntityType.sites).first;
      expect(dive['siteName'], 'Test Reef');
      expect(site['name'], 'Test Reef');
      expect(site['country'], 'Mexico');
      expect(site['waterType'], 'salt');
      expect(site['latitude'], closeTo(24.12345, 0.00001));
      expect(site['longitude'], closeTo(-110.54321, 0.00001));
    });

    test('dive has tank data derived from gases', () async {
      final payload = await const MacDiveXmlParser().parse(bytes);
      final dive = payload.entitiesOf(ImportEntityType.dives).first;
      final tanks = dive['tanks'] as List?;
      expect(tanks, isNotNull);
      expect(tanks!.length, 1);
      final tank = tanks.first as Map<String, dynamic>;
      expect(tank['startPressure'], 200);
      expect(tank['endPressure'], 60);
      // Keys match the UDDF/Subsurface tank-map convention so
      // UddfEntityImporter._buildTanks can consume them directly.
      expect(tank['volume'], 12);
      expect(tank['workingPressure'], 232);
      // gasMix must be a `GasMix` object, not a Map — the importer does
      // `t['gasMix'] as GasMix?` and a Map cast would throw.
      expect(tank['gasMix'], isA<GasMix>());
      final gasMix = tank['gasMix'] as GasMix;
      // GasMix stores o2/he as percentages 0-100 (not 0-1 fractions).
      expect(gasMix.o2, closeTo(32.0, 0.01));
      expect(gasMix.he, closeTo(0.0, 0.01));
    });

    test('dive has profile samples with timestamp+depth', () async {
      final payload = await const MacDiveXmlParser().parse(bytes);
      final dive = payload.entitiesOf(ImportEntityType.dives).first;
      final profile = dive['profile'] as List?;
      expect(profile, isNotNull);
      expect(profile!.length, 3);
      expect((profile[0] as Map)['timestamp'], 0);
      expect((profile[1] as Map)['timestamp'], 60);
    });

    test(
      'dive maps boat/diveOperator/weather into existing UDDF key names',
      () async {
        final payload = await const MacDiveXmlParser().parse(bytes);
        final dive = payload.entitiesOf(ImportEntityType.dives).first;
        expect(dive['boatName'], 'MV Test');
        expect(dive['diveOperator'], 'Test Operator');
        expect(dive['weather'], 'Sunny');
      },
    );

    test('returns error payload on invalid XML', () async {
      final bad = Uint8List.fromList(utf8.encode('not xml at all'));
      final payload = await const MacDiveXmlParser().parse(bad);
      expect(payload.entitiesOf(ImportEntityType.dives), isEmpty);
      expect(payload.warnings, isNotEmpty);
      expect(payload.warnings.first.severity, ImportWarningSeverity.error);
    });

    test('maps MacDive waterType "saltwater" to WaterType.salt.name', () async {
      final payload = await const MacDiveXmlParser().parse(bytes);
      final site = payload.entitiesOf(ImportEntityType.sites).first;
      // Downstream UddfEntityImporter calls _parseEnum(raw, WaterType.values)
      // which matches by `.name`. So "saltwater" (MacDive raw) should become
      // "salt" (WaterType.salt.name).
      expect(site['waterType'], 'salt');
    });

    test('maps MacDive entryType "Boat" to EntryMethod.boat.name', () async {
      const xml = '''<?xml version="1.0"?>
<dives><units>Metric</units><schema>2.2.0</schema>
  <dive>
    <date>2024-01-01 09:00:00</date><identifier>d1</identifier>
    <maxDepth>20</maxDepth><duration>1800</duration>
    <entryType>Boat</entryType>
    <samples/>
  </dive>
</dives>''';
      final bytes = Uint8List.fromList(utf8.encode(xml));
      final payload = await const MacDiveXmlParser().parse(bytes);
      final dive = payload.entitiesOf(ImportEntityType.dives).first;
      expect(dive['entryMethod'], 'boat');
    });

    test('unknown entryType strings pass through as null', () async {
      const xml = '''<?xml version="1.0"?>
<dives><units>Metric</units><schema>2.2.0</schema>
  <dive>
    <date>2024-01-01 09:00:00</date><identifier>d1</identifier>
    <maxDepth>20</maxDepth><duration>1800</duration>
    <entryType>WormholeDive</entryType>
    <samples/>
  </dive>
</dives>''';
      final bytes = Uint8List.fromList(utf8.encode(xml));
      final payload = await const MacDiveXmlParser().parse(bytes);
      final dive = payload.entitiesOf(ImportEntityType.dives).first;
      // Unknown value: omit the key entirely so the importer leaves the
      // dive's entryMethod at its default, rather than writing a garbage
      // value.
      expect(dive.containsKey('entryMethod'), isFalse);
    });
  });

  group('MacDiveXmlParser dedup behavior', () {
    test('two dives with same site name produce one site entity', () async {
      const xml = '''<?xml version="1.0"?>
<dives><units>Metric</units><schema>2.2.0</schema>
  <dive>
    <date>2024-01-01 09:00:00</date><identifier>d1</identifier>
    <maxDepth>20</maxDepth><duration>1800</duration>
    <site><name>Reef</name><country>US</country></site>
    <samples/>
  </dive>
  <dive>
    <date>2024-01-01 13:00:00</date><identifier>d2</identifier>
    <maxDepth>22</maxDepth><duration>1800</duration>
    <site><name>Reef</name><country>US</country></site>
    <samples/>
  </dive>
</dives>''';
      final bytes = Uint8List.fromList(utf8.encode(xml));
      final payload = await const MacDiveXmlParser().parse(bytes);
      expect(payload.entitiesOf(ImportEntityType.dives).length, 2);
      expect(
        payload.entitiesOf(ImportEntityType.sites).length,
        1,
        reason: 'sites dedup by name',
      );
    });

    test(
      'empty <item/> gear elements are skipped (no phantom entity)',
      () async {
        const xml = '''<?xml version="1.0"?>
<dives><units>Metric</units><schema>2.2.0</schema>
  <dive>
    <date>2024-01-01 09:00:00</date><identifier>d1</identifier>
    <maxDepth>20</maxDepth><duration>1800</duration>
    <gear>
      <item/>
      <item><manufacturer> </manufacturer><name></name><serial/></item>
      <item><manufacturer>Test</manufacturer><name>BCD1</name></item>
    </gear>
    <samples/>
  </dive>
</dives>''';
        final bytes = Uint8List.fromList(utf8.encode(xml));
        final payload = await const MacDiveXmlParser().parse(bytes);
        final equipment = payload.entitiesOf(ImportEntityType.equipment);
        expect(equipment.length, 1, reason: 'only the populated item survives');
        expect(equipment.first['name'], 'BCD1');
      },
    );

    test('multiple dives with overlapping buddies dedup', () async {
      const xml = '''<?xml version="1.0"?>
<dives><units>Metric</units><schema>2.2.0</schema>
  <dive>
    <date>2024-01-01 09:00:00</date><identifier>d1</identifier>
    <maxDepth>20</maxDepth><duration>1800</duration>
    <buddies><buddy>Alice</buddy><buddy>Bob</buddy></buddies>
    <samples/>
  </dive>
  <dive>
    <date>2024-01-01 13:00:00</date><identifier>d2</identifier>
    <maxDepth>22</maxDepth><duration>1800</duration>
    <buddies><buddy>Alice</buddy></buddies>
    <samples/>
  </dive>
</dives>''';
      final bytes = Uint8List.fromList(utf8.encode(xml));
      final payload = await const MacDiveXmlParser().parse(bytes);
      expect(
        payload.entitiesOf(ImportEntityType.buddies).length,
        2,
        reason: 'Alice+Bob unique',
      );
    });
  });
}
