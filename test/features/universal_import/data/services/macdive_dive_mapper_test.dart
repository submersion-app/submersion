import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/services/macdive_db_reader.dart';
import 'package:submersion/features/universal_import/data/services/macdive_dive_mapper.dart';

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
      final gasMix = tank['gasMix'] as Map<String, dynamic>;
      expect(gasMix['o2'], closeTo(0.32, 0.001));
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
      'profile is always empty (ZSAMPLES is proprietary, not decoded)',
      () async {
        final logbook = await MacDiveDbReader.readAll(bytes);
        final payload = MacDiveDiveMapper.toPayload(logbook);
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
