import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/services/macdive_db_reader.dart';
import 'package:submersion/features/universal_import/data/services/macdive_dive_mapper.dart';
import 'package:submersion/features/universal_import/data/services/macdive_raw_types.dart';

import '../../../../fixtures/macdive_sqlite/build_synthetic_db.dart';

void main() {
  late Uint8List bytes;

  setUpAll(() async {
    final path =
        '${Directory.systemTemp.path}/mdm_${DateTime.now().microsecondsSinceEpoch}.sqlite';
    final file = buildSyntheticMacDiveDb(path);
    bytes = Uint8List.fromList(await file.readAsBytes());
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });
  });

  group('MacDiveDiveMapper', () {
    test('produces 3 dives, 2 sites, 2 buddies, 2 tags, 1 gear', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      expect(payload.entitiesOf(ImportEntityType.dives).length, 3);
      expect(payload.entitiesOf(ImportEntityType.sites).length, 2);
      expect(payload.entitiesOf(ImportEntityType.buddies).length, 2);
      expect(payload.entitiesOf(ImportEntityType.tags).length, 2);
      expect(payload.entitiesOf(ImportEntityType.equipment).length, 1);
    });

    test('dive sourceUuid preserved', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      final dives = payload.entitiesOf(ImportEntityType.dives);
      final uuids = dives.map((d) => d['sourceUuid']).toSet();
      expect(uuids, {'dive-uuid-1', 'dive-uuid-2', 'dive-uuid-3'});
    });

    test(
      'dive 1 has tagRefs [Reef, Photography] and buddies [Alice, Bob]',
      () async {
        final logbook = await MacDiveDbReader.readAll(bytes);
        final payload = await MacDiveDiveMapper.toPayload(logbook);
        final dive1 = payload
            .entitiesOf(ImportEntityType.dives)
            .firstWhere((d) => d['sourceUuid'] == 'dive-uuid-1');
        expect(dive1['tagRefs'], containsAll(['Reef', 'Photography']));
        expect(dive1['unmatchedBuddyNames'], containsAll(['Alice', 'Bob']));
      },
    );

    test('dive 3 has no buddies or tags', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      final dive3 = payload
          .entitiesOf(ImportEntityType.dives)
          .firstWhere((d) => d['sourceUuid'] == 'dive-uuid-3');
      expect(dive3['tagRefs'], anyOf(isNull, isEmpty));
      expect(dive3['unmatchedBuddyNames'], anyOf(isNull, isEmpty));
    });

    test('dive 1 tanks include gas mix and pressures', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      final dive1 = payload
          .entitiesOf(ImportEntityType.dives)
          .firstWhere((d) => d['sourceUuid'] == 'dive-uuid-1');
      final tanks = dive1['tanks'] as List?;
      expect(tanks, isNotNull);
      expect(tanks!.length, 1);
      final tank = tanks.first as Map<String, dynamic>;
      // Synthetic: AL80 + EAN32 + 3000 psi start / 1000 psi end.
      // Units preference is Metric in the fixture, so raw values
      // pass through as-is (3000 "bar", 1000 "bar") because the
      // Metric branch is a passthrough. This is intentional -
      // the synthetic fixture isn't testing unit conversion, the
      // unit-converter tests in M2 did that.
      expect(tank['startPressure'], 3000);
      expect(tank['endPressure'], 1000);
      final gasMix = tank['gasMix'] as Map<String, dynamic>;
      expect(gasMix['o2'], closeTo(0.32, 0.001));
    });

    test('sites: saltwater/freshwater mapped to enum names', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      final sites = payload.entitiesOf(ImportEntityType.sites);
      final salt = sites.firstWhere((s) => s['name'] == 'Test Reef');
      final fresh = sites.firstWhere((s) => s['name'] == 'Freshwater Springs');
      expect(
        salt['waterType'],
        'salt',
        reason: 'MacDive "saltwater" -> WaterType.salt.name',
      );
      expect(fresh['waterType'], 'fresh');
    });

    test('sites: lat=0 lon=0 filtered to null', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      final fresh = payload
          .entitiesOf(ImportEntityType.sites)
          .firstWhere((s) => s['name'] == 'Freshwater Springs');
      expect(fresh.containsKey('latitude'), isFalse);
      expect(fresh.containsKey('longitude'), isFalse);
    });

    test(
      'profile is always empty (ZSAMPLES is proprietary, not decoded)',
      () async {
        final logbook = await MacDiveDbReader.readAll(bytes);
        final payload = await MacDiveDiveMapper.toPayload(logbook);
        for (final dive in payload.entitiesOf(ImportEntityType.dives)) {
          final profile = dive['profile'] as List?;
          // We either don't emit the key at all, or emit an empty list.
          expect(
            profile ?? const [],
            isEmpty,
            reason: 'M3 does not decode ZSAMPLES - profile stays empty',
          );
        }
      },
    );

    test('metadata includes source identifier and dive count', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      expect(payload.metadata['source'], 'macdive_sqlite');
      expect(payload.metadata['diveCount'], 3);
    });

    test('site entity carries sourceUuid from ZDIVESITE.ZUUID', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      final salt = payload
          .entitiesOf(ImportEntityType.sites)
          .firstWhere((s) => s['name'] == 'Test Reef');
      expect(salt['sourceUuid'], 'site-uuid-1');
    });
  });

  group('MacDiveDiveMapper.profile from ZRAWDATA', () {
    // The synthetic DB builder creates dives WITHOUT rawDataBlob by default.
    // These tests build logbooks manually with specific raw data for testing.

    test(
      'decoded profile emitted when ZRAWDATA present and decode succeeds',
      () async {
        final rawData = Uint8List.fromList(List.filled(32, 0x41));
        final parsed = pigeon.ParsedDive(
          fingerprint: 'test',
          dateTimeYear: 2026,
          dateTimeMonth: 3,
          dateTimeDay: 11,
          dateTimeHour: 10,
          dateTimeMinute: 0,
          dateTimeSecond: 0,
          maxDepthMeters: 10.0,
          avgDepthMeters: 6.0,
          durationSeconds: 600,
          samples: [
            pigeon.ProfileSample(
              timeSeconds: 0,
              depthMeters: 0.0,
              temperatureCelsius: 25.0,
            ),
            pigeon.ProfileSample(
              timeSeconds: 10,
              depthMeters: 5.0,
              temperatureCelsius: 24.5,
            ),
            pigeon.ProfileSample(
              timeSeconds: 20,
              depthMeters: 10.0,
              temperatureCelsius: 24.0,
            ),
          ],
          tanks: const [],
          gasMixes: const [],
          events: const [],
        );
        final dive = MacDiveRawDive(
          pk: 1,
          uuid: 'dive-decode-ok',
          computer: 'Shearwater Teric',
          rawDataBlob: rawData,
        );
        final logbook = MacDiveRawLogbook(
          dives: [dive],
          sitesByPk: const {},
          buddiesByPk: const {},
          tagsByPk: const {},
          gearByPk: const {},
          tanksByPk: const {},
          gasesByPk: const {},
          tankAndGases: const [],
          crittersByPk: const {},
          certifications: const [],
          serviceRecords: const [],
          events: const [],
          diveToBuddyPks: const {},
          diveToTagPks: const {},
          diveToGearPks: const {},
          diveToCritterPks: const {},
          unitsPreference: 'Metric',
        );

        final payload = await MacDiveDiveMapper.toPayload(
          logbook,
          parseRawDiveData: (vendor, product, model, data) async => parsed,
        );
        final returnedDives = payload.entitiesOf(ImportEntityType.dives);
        final profile = returnedDives.first['profile'] as List;
        expect(profile, hasLength(3));
        expect((profile[0] as Map)['timestamp'], 0);
        expect((profile[0] as Map)['depth'], 0.0);
        expect((profile[0] as Map)['temperature'], 25.0);
        expect((profile[2] as Map)['depth'], 10.0);
        expect(payload.warnings, isEmpty);
      },
    );

    test('decode failure produces warning and empty profile', () async {
      final dive = MacDiveRawDive(
        pk: 1,
        uuid: 'dive-decode-fail',
        computer: 'Shearwater Teric',
        rawDataBlob: Uint8List.fromList(List.filled(32, 0x42)),
      );
      final logbook = MacDiveRawLogbook(
        dives: [dive],
        sitesByPk: const {},
        buddiesByPk: const {},
        tagsByPk: const {},
        gearByPk: const {},
        tanksByPk: const {},
        gasesByPk: const {},
        tankAndGases: const [],
        crittersByPk: const {},
        certifications: const [],
        serviceRecords: const [],
        events: const [],
        diveToBuddyPks: const {},
        diveToTagPks: const {},
        diveToGearPks: const {},
        diveToCritterPks: const {},
        unitsPreference: 'Metric',
      );

      final payload = await MacDiveDiveMapper.toPayload(
        logbook,
        parseRawDiveData: (v, p, m, d) async => throw Exception('corrupt'),
      );
      final returnedDives = payload.entitiesOf(ImportEntityType.dives);
      expect(returnedDives.first['profile'], isEmpty);
      expect(payload.warnings, hasLength(1));
      expect(payload.warnings.first.message, contains('dive-decode-fail'));
      expect(payload.warnings.first.severity, ImportWarningSeverity.warning);
    });

    test('null ZRAWDATA produces empty profile with no warning', () async {
      final dive = MacDiveRawDive(
        pk: 1,
        uuid: 'dive-no-raw',
        computer: 'Manual',
        rawDataBlob: null,
      );
      final logbook = MacDiveRawLogbook(
        dives: [dive],
        sitesByPk: const {},
        buddiesByPk: const {},
        tagsByPk: const {},
        gearByPk: const {},
        tanksByPk: const {},
        gasesByPk: const {},
        tankAndGases: const [],
        crittersByPk: const {},
        certifications: const [],
        serviceRecords: const [],
        events: const [],
        diveToBuddyPks: const {},
        diveToTagPks: const {},
        diveToGearPks: const {},
        diveToCritterPks: const {},
        unitsPreference: 'Metric',
      );

      final payload = await MacDiveDiveMapper.toPayload(
        logbook,
        parseRawDiveData: (v, p, m, d) async =>
            throw StateError('should not be called'),
      );
      final returnedDives = payload.entitiesOf(ImportEntityType.dives);
      expect(returnedDives.first['profile'], isEmpty);
      expect(payload.warnings, isEmpty);
    });
  });
}
