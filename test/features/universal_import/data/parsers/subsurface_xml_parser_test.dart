import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/subsurface_xml_parser.dart';

void main() {
  final parser = SubsurfaceXmlParser();

  Uint8List xmlBytes(String xml) => Uint8List.fromList(utf8.encode(xml));

  group('supportedFormats', () {
    test('supports subsurfaceXml', () {
      expect(parser.supportedFormats, [ImportFormat.subsurfaceXml]);
    });
  });

  group('value parsing - via minimal dives', () {
    test('parses duration in M:SS min format', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='68:12 min'>
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );
      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives.length, 1);
      expect(dives[0]['duration'], const Duration(minutes: 68, seconds: 12));
      expect(dives[0]['runtime'], const Duration(minutes: 68, seconds: 12));
    });

    test('parses depth values with unit suffix', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <divecomputer model='Test'>
  <depth max='25.5 m' mean='18.3 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );
      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives[0]['maxDepth'], 25.5);
      expect(dives[0]['avgDepth'], 18.3);
    });

    test('parses dateTime from date and time attributes', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='5' date='2025-11-13' time='07:23:58' duration='10:00 min'>
  <divecomputer model='Test'>
  <depth max='8.0 m' mean='4.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );
      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives[0]['dateTime'], DateTime(2025, 11, 13, 7, 23, 58));
      expect(dives[0]['diveNumber'], 5);
    });
  });

  group('dive metadata', () {
    test('parses buddy with leading comma cleanup', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <buddy>, John Doe</buddy>
  <divemaster>Jane Smith</divemaster>
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );
      final dive = result.entitiesOf(ImportEntityType.dives).first;
      expect(dive['buddy'], 'John Doe');
      expect(dive['diveMaster'], 'Jane Smith');
    });

    test('parses notes and appends suit and SAC', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' sac='16.262 l/min' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <notes>Great dive!</notes>
  <suit>3mm Bare wetsuit</suit>
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );
      final dive = result.entitiesOf(ImportEntityType.dives).first;
      expect(dive['notes'], contains('Great dive!'));
      expect(dive['notes'], contains('Suit: 3mm Bare wetsuit'));
      expect(dive['notes'], contains('SAC: 16.262 l/min'));
    });

    test('parses air temperature from divetemperature element', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <divetemperature air='21.111 C'/>
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  <temperature water='28.0 C' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );
      final dive = result.entitiesOf(ImportEntityType.dives).first;
      expect(dive['airTemp'], closeTo(21.111, 0.001));
      expect(dive['waterTemp'], 28.0);
    });

    test('maps visibility and current enums', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' visibility='5' current='4' rating='3' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );
      final dive = result.entitiesOf(ImportEntityType.dives).first;
      expect(dive['visibility'], Visibility.excellent);
      expect(dive['currentStrength'], CurrentStrength.strong);
      expect(dive['rating'], 3);
    });

    test('maps watersalinity to WaterType', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' watersalinity='1030 g/l' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );
      final dive = result.entitiesOf(ImportEntityType.dives).first;
      expect(dive['waterType'], WaterType.salt);
    });
  });
}
