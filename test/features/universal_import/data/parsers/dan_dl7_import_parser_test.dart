import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/dan_dl7_import_parser.dart';

const _fixtureDir = 'test/features/universal_import/data/parsers/fixtures/dl7';

Future<List<int>> _fixture(String name) =>
    File('$_fixtureDir/$name').readAsBytes();

void main() {
  const parser = DanDl7Parser();

  group('DanDl7Parser — DiverLog+ synthetic (metric, AQUALUNG ZAR)', () {
    late Map<String, dynamic> dive;
    late List<Map<String, dynamic>> sites;

    setUpAll(() async {
      final bytes = await _fixture('diverlog_plus_synthetic.zxu');
      final payload = await parser.parse(Uint8List.fromList(bytes));
      final dives = payload.entitiesOf(ImportEntityType.dives);
      sites = payload.entitiesOf(ImportEntityType.sites);
      expect(dives, hasLength(1));
      dive = dives.first;
    });

    test('core dive fields from ZDH/ZAR', () {
      expect(dive['dateTime'], DateTime.utc(2024, 6, 12, 9, 30));
      expect(dive['runtime'], const Duration(minutes: 6));
      expect(dive['maxDepth'], closeTo(18.288, 0.001));
      expect(dive['airTemp'], closeTo(28.0, 0.001));
      expect(dive['surfaceInterval'], const Duration(hours: 1));
      expect(dive['diveNumber'], 42);
      expect(dive['rating'], 4);
      expect(dive['name'], 'Morning Reef Drift');
      expect(dive['diveMode'], 'oc');
    });

    test('DUID becomes sourceUuid; PDC identity mapped', () {
      expect(dive['sourceUuid'], '4321_98765_20240612093000_42');
      expect(dive['diveComputerModel'], 'I330R');
      expect(dive['diveComputerSerial'], '98765');
      expect(dive['diveComputerFirmware'], '1.003.000');
    });

    test('min temp comes from ZAR, never the bogus ZDT field', () {
      expect(dive['waterTemp'], closeTo(26.5, 0.001));
    });

    test('profile: interval derived from decimal-minute time column', () {
      final profile = dive['profile'] as List<Map<String, dynamic>>;
      expect(profile, hasLength(12));
      expect(profile[0]['timestamp'], 0);
      expect(profile[1]['timestamp'], 30);
      expect(profile[11]['timestamp'], 330);
      expect(profile[1]['depth'], closeTo(5.2, 0.001));
      expect(profile[2]['temperature'], closeTo(27.0, 0.001));
      expect(profile[3]['temperature'], isNull);
      expect(profile[4]['decoType'], 2);
    });

    test('ascent violation column becomes an event', () {
      final events = dive['events'] as List<Map<String, dynamic>>;
      expect(
        events,
        contains(
          predicate<Map<String, dynamic>>(
            (e) =>
                e['eventType'] == 'ascentRateWarning' && e['timestamp'] == 270,
          ),
        ),
      );
    });

    test('ZAR tank with PSI pressures converts to bar', () {
      final tanks = dive['tanks'] as List<Map<String, dynamic>>;
      expect(tanks, hasLength(1));
      final tank = tanks.first;
      expect((tank['gasMix'] as GasMix).o2, 32.0);
      expect(tank['startPressure'], closeTo(206.84, 0.01));
      expect(tank['endPressure'], closeTo(124.11, 0.01));
      expect(tank['workingPressure'], closeTo(206.84, 0.01));
      expect(tank['volume'], closeTo(10.95, 0.01));
      expect(tank['name'], 'AL80');
    });

    test('site entity carries GPS and geography; dive links to it', () {
      expect(sites, hasLength(1));
      final site = sites.first;
      expect(site['name'], 'Molokini Crater');
      expect(site['latitude'], closeTo(20.877432, 1e-6));
      expect(site['longitude'], closeTo(-156.679867, 1e-6));
      expect(site['country'], 'United States');
      expect(site['region'], 'Hawaii');
      expect((dive['site'] as Map<String, dynamic>)['uddfId'], site['uddfId']);
      expect(dive['latitude'], closeTo(20.877432, 1e-6));
      expect(dive['longitude'], closeTo(-156.679867, 1e-6));
    });
  });

  group('DanDl7Parser — multi-dive seconds fixture', () {
    test('parses three dives; integer time column read as seconds', () async {
      final bytes = await _fixture('dl7_multi_dive_seconds.zxu');
      final payload = await parser.parse(Uint8List.fromList(bytes));
      final dives = payload.entitiesOf(ImportEntityType.dives);
      expect(dives, hasLength(3));

      final manual = dives[0];
      expect(manual['dateTime'], DateTime.utc(2024, 3, 1, 10));
      expect(manual['profile'], isNull);
      // Runtime falls back to the ZDT surface timestamp delta.
      expect(manual['runtime'], const Duration(minutes: 25));
      expect(manual['duration'], const Duration(minutes: 25));
      expect(manual['maxDepth'], closeTo(12.0, 0.001));
      // With no ZAR and no profile, a positive ZDT min temp is used.
      expect(manual['waterTemp'], closeTo(21.0, 0.001));

      final profiled = dives[1];
      final profile = profiled['profile'] as List<Map<String, dynamic>>;
      expect(profile, hasLength(4));
      expect(profile[1]['timestamp'], 60);
      expect(profile[2]['timestamp'], 1500);
      expect(profile[1]['depth'], closeTo(15.0, 0.001));
      // Dives with a profile leave 'duration' unset so bottom time is
      // derived from the profile by the entity importer.
      expect(profiled['duration'], isNull);
      expect(profiled['runtime'], const Duration(minutes: 30));
    });
  });

  group('DanDl7Parser — imperial fixture', () {
    test('converts feet, fahrenheit, and PSIA to SI', () async {
      final bytes = await _fixture('dl7_imperial.zxu');
      final payload = await parser.parse(Uint8List.fromList(bytes));
      final dive = payload.entitiesOf(ImportEntityType.dives).single;

      expect(dive['maxDepth'], closeTo(18.288, 0.001));
      expect(dive['airTemp'], closeTo(29.444, 0.001));

      final profile = dive['profile'] as List<Map<String, dynamic>>;
      expect(profile[1]['timestamp'], 60);
      expect(profile[2]['depth'], closeTo(18.288, 0.001));
      expect(profile[2]['temperature'], closeTo(26.667, 0.001));
      // Water temp = profile minimum when ZAR is absent.
      expect(dive['waterTemp'], closeTo(26.667, 0.001));

      final pressures =
          profile[1]['allTankPressures'] as List<Map<String, dynamic>>;
      expect(pressures.single['pressure'], closeTo(193.05, 0.01));
      expect(pressures.single['tankIndex'], 0);

      // No ZAR: one tank synthesized from the profile's gas column (air).
      final tanks = dive['tanks'] as List<Map<String, dynamic>>;
      expect(tanks, hasLength(1));
      expect((tanks.first['gasMix'] as GasMix).o2, 21.0);
      expect(tanks.first.containsKey('startPressure'), isFalse);
    });
  });

  group('DanDl7Parser — non-Aqualung ZAR', () {
    test('imports standard segments and ignores the foreign ZAR', () async {
      final bytes = await _fixture('divelogdt_zar.zxu');
      final payload = await parser.parse(Uint8List.fromList(bytes));
      final dive = payload.entitiesOf(ImportEntityType.dives).single;
      expect(dive['sourceUuid'], isNull);
      expect(dive.containsKey('site'), isFalse);
      expect(dive['maxDepth'], closeTo(10.0, 0.001));
      expect((dive['profile'] as List), hasLength(3));
    });
  });

  group('DanDl7Parser — error handling', () {
    test('empty file produces an error warning, no entities', () async {
      final payload = await parser.parse(Uint8List(0));
      expect(payload.isEmpty, isTrue);
      expect(payload.warnings, isNotEmpty);
    });

    test('file with no dives produces an error warning', () async {
      final payload = await parser.parse(
        Uint8List.fromList('FSH|^~<>{}|X^^|ZXU|20240501120000|\n'.codeUnits),
      );
      expect(payload.isEmpty, isTrue);
      expect(payload.warnings, isNotEmpty);
    });
  });
}
