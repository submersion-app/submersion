import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/subsurface_xml_parser.dart';

/// A dive worn with two computers keeps both (issue #2672).
///
/// Subsurface writes one `<divecomputer>` per computer inside the `<dive>`;
/// the first is the one it displays. The parser used to read only that one.
void main() {
  final parser = SubsurfaceXmlParser();

  Future<List<Map<String, dynamic>>> parseDives(String dives) async {
    final xml =
        '''
<divelog program='subsurface' version='3'>
<dives>
$dives
</dives>
</divelog>
''';
    final payload = await parser.parse(Uint8List.fromList(utf8.encode(xml)));
    return payload.entitiesOf(ImportEntityType.dives);
  }

  const perdix = '''
  <divecomputer model='Shearwater Perdix' deviceid='aaaa1111' diveid='11111111'>
  <depth max='30.0 m' mean='18.0 m' />
  <temperature water='22.0 C' />
  <extradata key='Serial' value='SN-A' />
  <extradata key='FW Version' value='90' />
  <event time='20:00 min' type='8' name='bookmark' />
  <sample time='0:00 min' depth='0.0 m' pressure0='200.0 bar' />
  <sample time='10:00 min' depth='30.0 m' />
  <sample time='40:00 min' depth='0.0 m' pressure0='60.0 bar' />
  </divecomputer>''';

  String teric({String attributes = ''}) =>
      '''
  <divecomputer model='Shearwater Teric' deviceid='bbbb2222' diveid='22222222'$attributes>
  <depth max='30.4 m' mean='18.2 m' />
  <temperature water='21.5 C' />
  <extradata key='Serial' value='SN-B' />
  <extradata key='FW Version' value='15' />
  <extradata key='Deco model' value='GF 30/70' />
  <event time='21:00 min' type='8' name='bookmark' />
  <sample time='0:00 min' depth='0.0 m' pressure0='201.0 bar' />
  <sample time='10:00 min' depth='30.4 m' />
  <sample time='40:00 min' depth='0.0 m' pressure0='61.0 bar' />
  </divecomputer>''';

  String dive(String computers) =>
      '''
<dive number='1' date='2025-03-10' time='09:00:00' duration='40:00 min'>
  <cylinder size='11.1 l' workpressure='207.0 bar' description='AL80' o2='32.0%' />
$computers
</dive>''';

  group('a dive with two computers', () {
    test('keeps the dive itself on the first computer', () async {
      final dives = await parseDives(dive('$perdix\n${teric()}'));

      final d = dives.single;
      expect(d['diveComputerModel'], 'Shearwater Perdix');
      expect(d['diveComputerSerial'], 'SN-A');
      expect(d['maxDepth'], 30.0);
      expect(d['waterTemp'], 22.0);
      final profile = d['profile'] as List<Map<String, dynamic>>;
      expect(profile.map((p) => p['depth']), [0.0, 30.0, 0.0]);
    });

    test('carries the second computer as an additional computer', () async {
      final dives = await parseDives(dive('$perdix\n${teric()}'));

      final extra = dives.single['additionalComputers'] as List;
      expect(extra, hasLength(1));
      final tericReading = extra.single as Map<String, dynamic>;
      expect(tericReading['diveComputerModel'], 'Shearwater Teric');
      expect(tericReading['diveComputerSerial'], 'SN-B');
      expect(tericReading['diveComputerFirmware'], '15');
      expect(tericReading['decoAlgorithm'], 'buhlmann');
      expect(tericReading['gradientFactorLow'], 30);
      expect(tericReading['gradientFactorHigh'], 70);
      expect(tericReading['maxDepth'], 30.4);
      expect(tericReading['avgDepth'], 18.2);
      expect(tericReading['waterTemp'], 21.5);
      // Subsurface omits a computer's duration when it matches the dive's.
      expect(tericReading['duration'], const Duration(minutes: 40));
      expect(tericReading['timeOffsetSeconds'], 0);
    });

    test('reads the second computer its own profile and events', () async {
      final dives = await parseDives(dive('$perdix\n${teric()}'));

      final tericReading =
          (dives.single['additionalComputers'] as List).single
              as Map<String, dynamic>;
      final profile = tericReading['profile'] as List<Map<String, dynamic>>;
      expect(profile.map((p) => p['timestamp']), [0, 600, 2400]);
      expect(profile.map((p) => p['depth']), [0.0, 30.4, 0.0]);
      final pressures = [
        for (final p in profile)
          (p['allTankPressures'] as List).single['pressure'],
      ];
      expect(pressures.first, 201.0);
      expect(pressures.last, 61.0);

      final events = tericReading['events'] as List<Map<String, dynamic>>;
      expect(events.single['eventType'], 'bookmark');
      expect(events.single['timestamp'], 1260);
    });

    test('the second computer does not leak into the dive fields', () async {
      final dives = await parseDives(dive('$perdix\n${teric()}'));

      final events = dives.single['events'] as List<Map<String, dynamic>>;
      expect(events.single['timestamp'], 1200);
    });

    test('offsets a computer whose clock started elsewhere', () async {
      // Subsurface writes a computer's own date and time only when they
      // differ from the dive's, and its duration only when it differs from
      // the first computer's.
      final dives = await parseDives(
        dive(
          '$perdix\n'
          '${teric(attributes: " date='2025-03-10' time='09:01:30' duration='38:30 min'")}',
        ),
      );

      final tericReading =
          (dives.single['additionalComputers'] as List).single
              as Map<String, dynamic>;
      expect(tericReading['timeOffsetSeconds'], 90);
      expect(
        tericReading['duration'],
        const Duration(minutes: 38, seconds: 30),
      );
    });

    test('keeps every further computer, in file order', () async {
      final third = teric().replaceAll('Shearwater Teric', 'Suunto D5');
      final dives = await parseDives(dive('$perdix\n${teric()}\n$third'));

      final extra = dives.single['additionalComputers'] as List;
      expect(extra.map((e) => (e as Map)['diveComputerModel']), [
        'Shearwater Teric',
        'Suunto D5',
      ]);
    });
  });

  test('a computer dated with no time starts at midnight', () async {
    // The date reader is shared by the dive and each further computer; a
    // missing time reads as midnight rather than dropping the date.
    final dives = await parseDives('''
<dive number='1' date='2025-03-10' duration='40:00 min'>
$perdix
${teric(attributes: " date='2025-03-10' time='00:01:00'")}
</dive>''');

    expect(dives.single['dateTime'], DateTime.utc(2025, 3, 10));
    final tericReading =
        (dives.single['additionalComputers'] as List).single
            as Map<String, dynamic>;
    expect(tericReading['timeOffsetSeconds'], 60);
  });

  test('a dive with one computer carries no additional computers', () async {
    final dives = await parseDives(dive(perdix));

    expect(dives.single.containsKey('additionalComputers'), isFalse);
  });
}
