import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
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
      final payload = MacDiveDiveMapper.toPayload(logbook);
      expect(payload.entitiesOf(ImportEntityType.dives).length, 3);
      expect(payload.entitiesOf(ImportEntityType.sites).length, 2);
      expect(payload.entitiesOf(ImportEntityType.buddies).length, 2);
      expect(payload.entitiesOf(ImportEntityType.tags).length, 2);
      expect(payload.entitiesOf(ImportEntityType.equipment).length, 1);
    });

    test('dive sourceUuid preserved', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = MacDiveDiveMapper.toPayload(logbook);
      final dives = payload.entitiesOf(ImportEntityType.dives);
      final uuids = dives.map((d) => d['sourceUuid']).toSet();
      expect(uuids, {'dive-uuid-1', 'dive-uuid-2', 'dive-uuid-3'});
    });

    test(
      'dive 1 has tagRefs [Reef, Photography] and buddies [Alice, Bob]',
      () async {
        final logbook = await MacDiveDbReader.readAll(bytes);
        final payload = MacDiveDiveMapper.toPayload(logbook);
        final dive1 = payload
            .entitiesOf(ImportEntityType.dives)
            .firstWhere((d) => d['sourceUuid'] == 'dive-uuid-1');
        expect(dive1['tagRefs'], containsAll(['Reef', 'Photography']));
        expect(dive1['unmatchedBuddyNames'], containsAll(['Alice', 'Bob']));
      },
    );

    test('dive 3 has no buddies or tags', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = MacDiveDiveMapper.toPayload(logbook);
      final dive3 = payload
          .entitiesOf(ImportEntityType.dives)
          .firstWhere((d) => d['sourceUuid'] == 'dive-uuid-3');
      expect(dive3['tagRefs'], anyOf(isNull, isEmpty));
      expect(dive3['unmatchedBuddyNames'], anyOf(isNull, isEmpty));
    });

    test('dive 1 tanks include gas mix and pressures', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = MacDiveDiveMapper.toPayload(logbook);
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
      // gasMix must be a `GasMix` object, not a Map — UddfEntityImporter does
      // `t['gasMix'] as GasMix?` and a Map cast would throw at runtime.
      // MacDive stores oxygen as a fraction (0.32); GasMix.o2 is a percent.
      expect(tank['gasMix'], isA<GasMix>());
      final gasMix = tank['gasMix'] as GasMix;
      expect(gasMix.o2, closeTo(32.0, 0.01));
      expect(gasMix.he, closeTo(0.0, 0.01));
    });

    test('sites: saltwater/freshwater mapped to enum names', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = MacDiveDiveMapper.toPayload(logbook);
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
      final payload = MacDiveDiveMapper.toPayload(logbook);
      final fresh = payload
          .entitiesOf(ImportEntityType.sites)
          .firstWhere((s) => s['name'] == 'Freshwater Springs');
      expect(fresh.containsKey('latitude'), isFalse);
      expect(fresh.containsKey('longitude'), isFalse);
    });

    test(
      'no profile key emitted (MacDive SQLite profiles unsupported)',
      () async {
        final logbook = await MacDiveDbReader.readAll(bytes);
        final payload = MacDiveDiveMapper.toPayload(logbook);
        // ZSAMPLES is AES-encrypted and ZRAWDATA is a MacDive-specific
        // wrapper libdivecomputer can't parse, so the mapper does not emit
        // profile samples. Matches macdive_xml_parser.dart's convention of
        // omitting the key entirely when no samples are available.
        for (final dive in payload.entitiesOf(ImportEntityType.dives)) {
          expect(dive.containsKey('profile'), isFalse);
        }
      },
    );

    test(
      'ZRAWDATA present → single aggregated warning pointing at XML export',
      () {
        final rawData = Uint8List.fromList(List.filled(32, 0x41));
        final logbook = MacDiveRawLogbook(
          dives: [
            MacDiveRawDive(
              pk: 1,
              uuid: 'dive-1',
              computer: 'Shearwater Teric',
              rawDataBlob: rawData,
            ),
            MacDiveRawDive(
              pk: 2,
              uuid: 'dive-2',
              computer: 'Shearwater Teric',
              rawDataBlob: rawData,
            ),
            const MacDiveRawDive(
              pk: 3,
              uuid: 'dive-3',
              computer: 'Manual',
              rawDataBlob: null,
            ),
          ],
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

        final payload = MacDiveDiveMapper.toPayload(logbook);
        expect(payload.warnings, hasLength(1));
        final w = payload.warnings.single;
        expect(w.severity, ImportWarningSeverity.info);
        expect(w.entityType, ImportEntityType.dives);
        // Counts only the dives with non-empty ZRAWDATA (2 of 3).
        expect(w.message, contains('2 dive'));
        expect(w.message.toLowerCase(), contains('xml'));
      },
    );

    test('no warning when logbook has no ZRAWDATA', () {
      const logbook = MacDiveRawLogbook(
        dives: [
          MacDiveRawDive(
            pk: 1,
            uuid: 'dive-1',
            computer: 'Manual',
            rawDataBlob: null,
          ),
        ],
        sitesByPk: {},
        buddiesByPk: {},
        tagsByPk: {},
        gearByPk: {},
        tanksByPk: {},
        gasesByPk: {},
        tankAndGases: [],
        crittersByPk: {},
        certifications: [],
        serviceRecords: [],
        events: [],
        diveToBuddyPks: {},
        diveToTagPks: {},
        diveToGearPks: {},
        diveToCritterPks: {},
        unitsPreference: 'Metric',
      );
      final payload = MacDiveDiveMapper.toPayload(logbook);
      expect(payload.warnings, isEmpty);
    });

    test('metadata includes source identifier and dive count', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = MacDiveDiveMapper.toPayload(logbook);
      expect(payload.metadata['source'], 'macdive_sqlite');
      expect(payload.metadata['diveCount'], 3);
    });

    test('site entity carries sourceUuid from ZDIVESITE.ZUUID', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = MacDiveDiveMapper.toPayload(logbook);
      final salt = payload
          .entitiesOf(ImportEntityType.sites)
          .firstWhere((s) => s['name'] == 'Test Reef');
      expect(salt['sourceUuid'], 'site-uuid-1');
    });
  });
}
