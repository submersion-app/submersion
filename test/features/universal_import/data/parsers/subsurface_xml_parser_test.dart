import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/subsurface_xml_parser.dart';

void main() {
  final parser = SubsurfaceXmlParser();
  const dualTankFixturePath =
      'test/features/universal_import/data/parsers/fixtures/dual-cylinder.ssrf';

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
      expect(dives[0]['dateTime'], DateTime.utc(2025, 11, 13, 7, 23, 58));
      expect(dives[0]['diveNumber'], 5);
    });
  });

  group('dive metadata', () {
    test('creates buddy entities and sets refs on dives', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <buddy>, John Doe, Alice</buddy>
  <divemaster>Jane Smith</divemaster>
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );
      // Buddy entities created for review step
      final buddies = result.entitiesOf(ImportEntityType.buddies);
      expect(buddies.length, 3);
      final buddyNames = buddies.map((b) => b['name']).toSet();
      expect(buddyNames, containsAll(['John Doe', 'Alice', 'Jane Smith']));

      // Dive has refs, not inline text
      final dive = result.entitiesOf(ImportEntityType.dives).first;
      expect(dive['buddyRefs'], ['John Doe', 'Alice']);
      expect(dive['diveGuideRefs'], ['Jane Smith']);
      expect(dive.containsKey('buddy'), isFalse);
      expect(dive.containsKey('diveMaster'), isFalse);
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

    test('maps divecomputer dctype to diveMode', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <divecomputer model='Test CCR' dctype='CCR'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
<dive number='2' date='2025-01-16' time='10:00:00' duration='30:00 min'>
  <divecomputer model='Test SCR' dctype='SCR'>
  <depth max='18.0 m' mean='12.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives[0]['diveMode'], DiveMode.ccr);
      expect(dives[1]['diveMode'], DiveMode.scr);
    });

    test('parses dive-level cns and preserves fractional otu', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' cns='42%' otu='17.5' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );

      final dive = result.entitiesOf(ImportEntityType.dives).first;
      expect(dive['cnsEnd'], 42.0);
      expect(dive['otu'], 17.5);
    });
  });

  group('cylinders', () {
    test('parses cylinder with gas mix as GasMix object', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <cylinder size='11.094 l' workpressure='206.843 bar' description='AL80' o2='32.0%' start='200.0 bar' end='50.0 bar' />
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );
      final dive = result.entitiesOf(ImportEntityType.dives).first;
      final tanks = dive['tanks'] as List<Map<String, dynamic>>;
      expect(tanks.length, 1);
      expect(tanks[0]['volume'], closeTo(11.094, 0.001));
      expect(tanks[0]['workingPressure'], closeTo(206.843, 0.001));
      expect(tanks[0]['startPressure'], closeTo(200.0, 0.001));
      expect(tanks[0]['endPressure'], closeTo(50.0, 0.001));
      expect(tanks[0]['gasMix'], isA<GasMix>());
      expect((tanks[0]['gasMix'] as GasMix).o2, 32.0);
      expect((tanks[0]['gasMix'] as GasMix).he, 0.0);
      expect(tanks[0]['name'], 'AL80');
    });

    test('defaults to air (21% O2, 0% He) when no gas attrs', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <cylinder size='11.094 l' workpressure='206.843 bar' description='AL80' />
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );
      final tanks =
          result.entitiesOf(ImportEntityType.dives).first['tanks']
              as List<Map<String, dynamic>>;
      expect(tanks.length, 1);
      final gasMix = tanks[0]['gasMix'] as GasMix;
      expect(gasMix.o2, 21.0);
      expect(gasMix.he, 0.0);
    });

    test('skips empty cylinder elements', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <cylinder size='11.094 l' workpressure='206.843 bar' description='AL80' />
  <cylinder />
  <cylinder />
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );
      final tanks =
          result.entitiesOf(ImportEntityType.dives).first['tanks']
              as List<Map<String, dynamic>>;
      expect(tanks.length, 1);
    });

    test('parses multiple populated cylinders as multiple tanks', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <cylinder size='11.094 l' workpressure='206.843 bar' description='Back Gas' o2='32.0%' start='200.0 bar' end='70.0 bar' />
  <cylinder size='5.550 l' workpressure='206.843 bar' description='Deco' o2='50.0%' start='180.0 bar' end='120.0 bar' />
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );
      final tanks =
          result.entitiesOf(ImportEntityType.dives).first['tanks']
              as List<Map<String, dynamic>>;

      expect(tanks.length, 2);
      expect(tanks[0]['name'], 'Back Gas');
      expect((tanks[0]['gasMix'] as GasMix).o2, 32.0);
      expect(tanks[1]['name'], 'Deco');
      expect((tanks[1]['gasMix'] as GasMix).o2, 50.0);
    });

    test('parses trimix cylinder', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <cylinder size='12.0 l' workpressure='232.0 bar' description='D12' o2='18.0%' he='45.0%' />
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );
      final tanks =
          result.entitiesOf(ImportEntityType.dives).first['tanks']
              as List<Map<String, dynamic>>;
      final gasMix = tanks[0]['gasMix'] as GasMix;
      expect(gasMix.o2, 18.0);
      expect(gasMix.he, 45.0);
      expect(gasMix.isTrimix, isTrue);
    });

    test('maps cylinder use to tank role', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <cylinder size='3.0 l' description='Diluent' use='diluent' o2='10.0%' he='50.0%' />
  <cylinder size='11.1 l' description='Stage' use='stage' o2='50.0%' />
  <cylinder size='11.1 l' description='Sidemount' use='sidemount' o2='32.0%' />
  <divecomputer model='Test CCR'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );

      final tanks =
          result.entitiesOf(ImportEntityType.dives).first['tanks']
              as List<Map<String, dynamic>>;
      expect(tanks[0]['role'], TankRole.diluent);
      expect(tanks[1]['role'], TankRole.stage);
      expect(tanks[2]['role'], isNull);
    });

    test(
      'falls back to sample pressures when cylinder lacks start/end',
      () async {
        final result = await parser.parse(
          xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='2:00 min'>
  <cylinder size='11.094 l' description='AL80' />
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  <sample time='0:00 min' depth='0.0 m' pressure0='200.5 bar' />
  <sample time='1:00 min' depth='20.0 m' pressure0='150.0 bar' />
  <sample time='2:00 min' depth='0.0 m' pressure0='100.3 bar' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
        );
        final tanks =
            result.entitiesOf(ImportEntityType.dives).first['tanks']
                as List<Map<String, dynamic>>;
        expect(tanks[0]['startPressure'], closeTo(200.5, 0.001));
        expect(tanks[0]['endPressure'], closeTo(100.3, 0.001));
      },
    );
  });

  group('profile samples', () {
    test('parses sample time/depth/temp/pressure', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='2:00 min'>
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  <sample time='0:00 min' depth='0.0 m' temp='21.0 C' pressure0='196.9 bar' />
  <sample time='0:30 min' depth='10.5 m' />
  <sample time='1:00 min' depth='20.0 m' pressure0='180.0 bar' />
  <sample time='1:30 min' depth='10.0 m' />
  <sample time='2:00 min' depth='0.0 m' pressure0='170.0 bar' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );
      final dive = result.entitiesOf(ImportEntityType.dives).first;
      final profile = dive['profile'] as List<Map<String, dynamic>>;
      expect(profile.length, 5);

      // Helper to extract tank 0 pressure from allTankPressures
      double? pressureAt(int idx) {
        final all =
            profile[idx]['allTankPressures'] as List<Map<String, dynamic>>?;
        if (all == null || all.isEmpty) return null;
        return all.firstWhere((t) => t['tankIndex'] == 0)['pressure'] as double;
      }

      // First sample: explicit pressure
      expect(profile[0]['timestamp'], 0);
      expect(profile[0]['depth'], 0.0);
      expect(profile[0]['temperature'], 21.0);
      expect(pressureAt(0), 196.9);

      // Second sample: pressure interpolated, temperature forward-filled
      expect(profile[1]['timestamp'], 30);
      expect(profile[1]['depth'], 10.5);
      expect(profile[1]['temperature'], 21.0);
      expect(pressureAt(1), closeTo(188.45, 0.01));

      // Third sample: explicit pressure
      expect(pressureAt(2), 180.0);

      // Fourth sample: interpolated between 180.0 (t=60) and 170.0 (t=120)
      expect(pressureAt(3), closeTo(175.0, 0.01));

      // Last sample: explicit pressure
      expect(profile[4]['timestamp'], 120);
      expect(profile[4]['depth'], 0.0);
      expect(pressureAt(4), 170.0);
    });

    test('parses multi-tank pressure from pressure0 and pressure1', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='2:00 min'>
  <cylinder size='11.1 l' description='AL80' o2='32%' start='200 bar' end='100 bar' />
  <cylinder size='11.1 l' description='AL80' o2='21%' start='190 bar' end='90 bar' />
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  <sample time='0:00 min' depth='0.0 m' pressure0='200.0 bar' pressure1='190.0 bar' />
  <sample time='1:00 min' depth='20.0 m' pressure0='150.0 bar' pressure1='140.0 bar' />
  <sample time='2:00 min' depth='0.0 m' pressure0='100.0 bar' pressure1='90.0 bar' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );
      final dive = result.entitiesOf(ImportEntityType.dives).first;
      final profile = dive['profile'] as List<Map<String, dynamic>>;

      // Each sample should have allTankPressures with both tanks
      final first =
          profile[0]['allTankPressures'] as List<Map<String, dynamic>>;
      expect(first, hasLength(2));
      expect(first[0], {'pressure': 200.0, 'tankIndex': 0});
      expect(first[1], {'pressure': 190.0, 'tankIndex': 1});

      final last = profile[2]['allTankPressures'] as List<Map<String, dynamic>>;
      expect(last[0], {'pressure': 100.0, 'tankIndex': 0});
      expect(last[1], {'pressure': 90.0, 'tankIndex': 1});

      // Both tanks should have start/end pressure derived from profile
      final tanks = dive['tanks'] as List<Map<String, dynamic>>;
      expect(tanks, hasLength(2));
      expect(tanks[0]['startPressure'], 200.0);
      expect(tanks[0]['endPressure'], 100.0);
      expect(tanks[1]['startPressure'], 190.0);
      expect(tanks[1]['endPressure'], 90.0);
    });

    test('parses sample ndl, tts, rbt, cns, and heart rate', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='2:00 min'>
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  <sample time='1:00 min' depth='20.0 m' ndl='14:30 min' tts='3:45 min' rbt='25:00 min' cns='12%' heartbeat='84' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );

      final dive = result.entitiesOf(ImportEntityType.dives).first;
      final profile = dive['profile'] as List<Map<String, dynamic>>;

      expect(profile.single['ndl'], 870);
      expect(profile.single['tts'], 225);
      expect(profile.single['rbt'], 1500);
      expect(profile.single['cns'], 12.0);
      expect(profile.single['heartRate'], 84);
    });

    test('maps in_deco to decoType and leaves non-deco samples null', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='3:00 min'>
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  <sample time='1:00 min' depth='20.0 m' in_deco='0' />
  <sample time='2:00 min' depth='15.0 m' in_deco='1' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );

      final dive = result.entitiesOf(ImportEntityType.dives).first;
      final profile = dive['profile'] as List<Map<String, dynamic>>;

      expect(profile[0]['decoType'], isNull);
      expect(profile[1]['decoType'], 2);
    });

    test('maps sample po2 to ppO2', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='2:00 min'>
  <divecomputer model='Test CCR'>
  <depth max='20.0 m' mean='15.0 m' />
  <sample time='1:00 min' depth='20.0 m' po2='1.21' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );

      final dive = result.entitiesOf(ImportEntityType.dives).first;
      final profile = dive['profile'] as List<Map<String, dynamic>>;

      expect(profile.single['ppO2'], 1.21);
    });
  });

  group('weights', () {
    test('parses weight amount and maps description to WeightType', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <weightsystem weight='6.35 kg' description='belt' />
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );
      final dive = result.entitiesOf(ImportEntityType.dives).first;
      final weights = dive['weights'] as List<Map<String, dynamic>>;
      expect(weights.length, 1);
      expect(weights[0]['amount'], closeTo(6.35, 0.01));
      expect(weights[0]['type'], WeightType.belt);
      expect(weights[0]['notes'], 'belt');
    });
  });

  group('sites', () {
    test('parses site name, GPS, and geo taxonomy', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<divesites>
<site uuid='abc123' name='Blue Hole' gps='18.465562 -66.084902'>
  <geo cat='2' origin='2' value='Puerto Rico'/>
  <geo cat='3' origin='0' value='Isabela'/>
</site>
</divesites>
<dives>
<dive number='1' divesiteid='abc123' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );
      final sites = result.entitiesOf(ImportEntityType.sites);
      expect(sites.length, 1);
      expect(sites[0]['name'], 'Blue Hole');
      expect(sites[0]['uddfId'], 'abc123');
      expect(sites[0]['latitude'], closeTo(18.4656, 0.001));
      expect(sites[0]['longitude'], closeTo(-66.0849, 0.001));
      expect(sites[0]['country'], 'Puerto Rico');
      expect(sites[0]['region'], 'Isabela');

      final dive = result.entitiesOf(ImportEntityType.dives).first;
      final siteRef = dive['site'] as Map<String, dynamic>;
      expect(siteRef['uddfId'], 'abc123');
    });

    test('trims leading whitespace from UUIDs', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<divesites>
<site uuid=' b95bba6' name='Escambron' gps='18.465562 -66.084902'>
</site>
</divesites>
<dives>
<dive number='1' divesiteid=' b95bba6' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );
      final sites = result.entitiesOf(ImportEntityType.sites);
      expect(sites[0]['uddfId'], 'b95bba6');

      final dive = result.entitiesOf(ImportEntityType.dives).first;
      final siteRef = dive['site'] as Map<String, dynamic>;
      expect(siteRef['uddfId'], 'b95bba6');
    });
  });

  group('trips', () {
    test('parses trip wrapper and links child dives', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<trip date='2025-11-13' time='07:00:00' location='Puerto Rico'>
  <notes>Caribbean trip</notes>
  <dive number='1' date='2025-11-13' time='07:23:58' duration='60:00 min'>
    <divecomputer model='Test'>
    <depth max='8.0 m' mean='4.0 m' />
    </divecomputer>
  </dive>
  <dive number='2' date='2025-11-13' time='10:14:49' duration='65:00 min'>
    <divecomputer model='Test'>
    <depth max='10.0 m' mean='5.0 m' />
    </divecomputer>
  </dive>
</trip>
</dives>
</divelog>
'''),
      );
      final trips = result.entitiesOf(ImportEntityType.trips);
      expect(trips.length, 1);
      expect(trips[0]['name'], 'Puerto Rico');
      expect(trips[0]['location'], 'Puerto Rico');
      expect(trips[0]['notes'], 'Caribbean trip');
      expect(trips[0]['startDate'], DateTime.utc(2025, 11, 13, 7, 0, 0));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives.length, 2);
      final tripId = trips[0]['uddfId'] as String;
      expect(dives[0]['tripRef'], tripId);
      expect(dives[1]['tripRef'], tripId);
    });
  });

  group('tags', () {
    test('extracts unique tags from comma-separated dive attrs', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' tags='shore, student' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
<dive number='2' tags='shore, boat' date='2025-01-16' time='10:00:00' duration='30:00 min'>
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );
      final tags = result.entitiesOf(ImportEntityType.tags);
      expect(tags.length, 3);
      final tagNames = tags.map((t) => t['name']).toSet();
      expect(tagNames, containsAll(['shore', 'student', 'boat']));

      final dives = result.entitiesOf(ImportEntityType.dives);
      final dive1TagRefs = dives[0]['tagRefs'] as List<String>;
      expect(dive1TagRefs, containsAll(['shore', 'student']));
    });
  });

  group('edge cases', () {
    test('returns error warning for empty input', () async {
      final result = await parser.parse(Uint8List(0));
      expect(result.isEmpty, isTrue);
      expect(result.warnings, isNotEmpty);
      expect(result.warnings.first.severity, ImportWarningSeverity.error);
    });

    test('returns error warning for malformed XML', () async {
      final result = await parser.parse(xmlBytes('<not valid xml>>>'));
      expect(result.isEmpty, isTrue);
      expect(result.warnings, isNotEmpty);
      expect(result.warnings.first.severity, ImportWarningSeverity.error);
    });

    test('returns error warning for non-divelog root', () async {
      final result = await parser.parse(xmlBytes('<uddf></uddf>'));
      expect(result.isEmpty, isTrue);
      expect(result.warnings, isNotEmpty);
      expect(result.warnings.first.message, contains('divelog'));
    });

    test('handles dive with no divecomputer element', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
</dive>
</dives>
</divelog>
'''),
      );
      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives.length, 1);
      expect(dives[0]['dateTime'], isNotNull);
      expect(dives[0].containsKey('maxDepth'), isFalse);
    });
  });

  group('integration - real Subsurface export', () {
    test('parses dual-cylinder fixture as two tanks', () async {
      final file = File(dualTankFixturePath);
      final diveXml = await file.readAsString();
      final wrapped =
          '''
<divelog program='subsurface' version='3'>
<dives>
$diveXml
</dives>
</divelog>
''';

      final result = await parser.parse(xmlBytes(wrapped));
      final dives = result.entitiesOf(ImportEntityType.dives);

      expect(dives.length, 1);
      final tanks = dives.first['tanks'] as List<Map<String, dynamic>>?;
      expect(tanks, isNotNull);
      expect(tanks!.length, 2);

      expect(tanks[0]['name'], 'D80');
      expect(tanks[0]['volume'], closeTo(22.2, 0.001));
      expect(tanks[0]['startPressure'], 210);
      expect(tanks[0]['endPressure'], 170);
      expect((tanks[0]['gasMix'] as GasMix).o2, 21.0);
      expect(tanks[0]['uddfTankId'], '0:D80');

      expect(tanks[1]['name'], 'AL80');
      expect(tanks[1]['volume'], closeTo(11.094, 0.001));
      expect(tanks[1]['startPressure'], 150);
      expect(tanks[1]['endPressure'], 100);
      expect((tanks[1]['gasMix'] as GasMix).o2, 50.0);
      expect(tanks[1]['uddfTankId'], '1:AL80');

      final gasSwitches =
          dives.first['gasSwitches'] as List<Map<String, dynamic>>?;
      expect(gasSwitches, isNotNull);
      expect(gasSwitches!.length, 5);
      expect(gasSwitches[0]['timestamp'], 10);
      expect(gasSwitches[0]['tankRef'], '0:D80');
      expect(gasSwitches[1]['timestamp'], 700);
      expect(gasSwitches[1]['tankRef'], '1:AL80');
    });

    test('parses dual-cylinder gas switch times correctly', () async {
      final file = File(dualTankFixturePath);
      final diveXml = await file.readAsString();
      final wrapped =
          '''
<divelog program='subsurface' version='3'>
<dives>
$diveXml
</dives>
</divelog>
''';

      final result = await parser.parse(xmlBytes(wrapped));
      final dive = result.entitiesOf(ImportEntityType.dives).single;
      final gasSwitches =
          dive['gasSwitches'] as List<Map<String, dynamic>>? ?? const [];

      expect(gasSwitches.map((gs) => gs['timestamp']).toList(), [
        10,
        700,
        980,
        2910,
        4050,
      ]);
      expect(gasSwitches.map((gs) => gs['tankRef']).toList(), [
        '0:D80',
        '1:AL80',
        '0:D80',
        '1:AL80',
        '0:D80',
      ]);
    });

    test('parses subsurface_export.ssrf with correct counts', () async {
      final file = File('subsurface_export.ssrf');
      if (!file.existsSync()) {
        markTestSkipped('subsurface_export.ssrf not found in project root');
        return;
      }

      final bytes = Uint8List.fromList(await file.readAsBytes());
      final result = await parser.parse(bytes);

      // Verify counts from the actual export
      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives.length, 16);

      final sites = result.entitiesOf(ImportEntityType.sites);
      expect(sites.length, 5);

      // Verify a specific dive has expected data
      final dive1 = dives.firstWhere((d) => d['diveNumber'] == 1);
      expect(dive1['dateTime'], DateTime.utc(2025, 9, 20, 7, 44, 37));
      final buddyRefs = dive1['buddyRefs'] as List<String>;
      expect(buddyRefs, isNotEmpty);
      final guideRefs = dive1['diveGuideRefs'] as List<String>;
      expect(guideRefs, isNotEmpty);

      // Buddy entities should be in the payload for the review step
      final buddies = result.entitiesOf(ImportEntityType.buddies);
      expect(buddies.length, greaterThanOrEqualTo(2));
      expect(dive1['visibility'], Visibility.poor);
      expect(dive1['currentStrength'], CurrentStrength.strong);
      expect(dive1['waterType'], WaterType.salt);

      // Verify profile data exists
      final profile = dive1['profile'] as List<Map<String, dynamic>>?;
      expect(profile, isNotNull);
      expect(profile!.length, greaterThan(10));

      // Verify tanks
      final tanks = dive1['tanks'] as List<Map<String, dynamic>>?;
      expect(tanks, isNotNull);
      expect(tanks!.length, 1);
      expect(tanks[0]['name'], 'AL80');

      // Verify weights
      final weights = dive1['weights'] as List<Map<String, dynamic>>?;
      expect(weights, isNotNull);
      expect(weights!.length, 1);
      expect(weights[0]['type'], WeightType.belt);

      // Verify tags extracted
      final tags = result.entitiesOf(ImportEntityType.tags);
      expect(tags.length, greaterThanOrEqualTo(2));

      // Verify no error warnings
      final errors = result.warnings.where(
        (w) => w.severity == ImportWarningSeverity.error,
      );
      expect(errors, isEmpty);
    });

    test('does not invent extra tanks from placeholder cylinders', () async {
      final file = File('subsurface_export.ssrf');
      if (!file.existsSync()) {
        markTestSkipped('subsurface_export.ssrf not found in project root');
        return;
      }

      final bytes = Uint8List.fromList(await file.readAsBytes());
      final result = await parser.parse(bytes);
      final dives = result.entitiesOf(ImportEntityType.dives);

      final tankCounts = dives.map((dive) {
        final tanks = dive['tanks'] as List<Map<String, dynamic>>?;
        return tanks?.length ?? 0;
      }).toList();

      expect(tankCounts, isNotEmpty);
      expect(tankCounts.reduce((a, b) => a > b ? a : b), 1);

      final dive1 = dives.firstWhere((d) => d['diveNumber'] == 1);
      final dive1Tanks = dive1['tanks'] as List<Map<String, dynamic>>?;
      expect(dive1Tanks, isNotNull);
      expect(dive1Tanks!.length, 1);

      final dive10 = dives.firstWhere((d) => d['diveNumber'] == 10);
      expect(dive10.containsKey('tanks'), isFalse);

      final dive11 = dives.firstWhere((d) => d['diveNumber'] == 11);
      expect(dive11.containsKey('tanks'), isFalse);
    });
  });
}
