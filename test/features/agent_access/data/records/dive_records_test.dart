import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

import '../../../../helpers/test_database.dart';
import 'record_harness.dart';

void main() {
  late AppDatabase db;
  late RecordHarness h;
  const t = kSeedTime;

  setUp(() async {
    db = await setUpTestDatabase();
    h = RecordHarness(db);
    await seedTwoDivers(db);
    for (final (id, owner) in [('a1', kDiverA), ('b1', kDiverB)]) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: id,
              diveDateTime: t,
              createdAt: t,
              updatedAt: t,
              diverId: Value(owner),
            ),
          );
      await db
          .into(db.diveTanks)
          .insert(DiveTanksCompanion.insert(id: 'tank-$id', diveId: id));
      await db
          .into(db.diveWeights)
          .insert(
            DiveWeightsCompanion.insert(
              id: 'w-$id',
              diveId: id,
              weightType: 'belt',
              amountKg: 4,
              createdAt: t,
            ),
          );
      await db
          .into(db.gasSwitches)
          .insert(
            GasSwitchesCompanion.insert(
              id: 'gs-$id',
              diveId: id,
              timestamp: 120,
              tankId: 'tank-$id',
              createdAt: t,
            ),
          );
      await db
          .into(db.diveCustomFields)
          .insert(
            DiveCustomFieldsCompanion.insert(
              id: 'cf-$id',
              diveId: id,
              fieldKey: 'Boat',
              createdAt: t,
            ),
          );
      await db
          .into(db.diveProfileEvents)
          .insert(
            DiveProfileEventsCompanion.insert(
              id: 'ev-$id',
              diveId: id,
              timestamp: 30,
              eventType: 'bookmark',
              createdAt: t,
            ),
          );
      await db
          .into(db.diveScenarios)
          .insert(
            DiveScenariosCompanion.insert(
              id: 'sc-$id',
              diveId: id,
              name: 'What if',
              branchSeconds: 60,
              mode: const Value('replan'),
              interventionsJson: '{"formatVersion":1,"interventions":[]}',
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
    await db
        .into(db.species)
        .insert(
          SpeciesCompanion.insert(
            id: 'sp',
            commonName: 'Turtle',
            category: 'reptile',
          ),
        );
    await db
        .into(db.sightings)
        .insert(
          SightingsCompanion.insert(id: 'si', diveId: 'a1', speciesId: 'sp'),
        );
    for (final (id, dive) in [('m1', 'a1'), ('m2', 'b1'), ('m3', null)]) {
      await db
          .into(db.media)
          .insert(
            MediaCompanion.insert(
              id: id,
              filePath: 'path/$id.jpg',
              diveId: Value(dive),
              takenAt: const Value(t),
              createdAt: t,
              updatedAt: t,
              imageData: Value(Uint8List.fromList([9, 8, 7])),
            ),
          );
    }
  });
  tearDown(tearDownTestDatabase);

  group('the dive document', () {
    test('the document carries every diver-entered field', () async {
      await (db.update(db.dives)..where((d) => d.id.equals('a1'))).write(
        const DivesCompanion(
          entryLatitude: Value(10.5),
          entryLongitude: Value(20.5),
          visibilityMinMeters: Value(8),
          boatName: Value('Sea Star'),
          currentDirection: Value('north'),
          swellHeight: Value(1.5),
          altitude: Value(1800),
          surfacePressure: Value(0.82),
          setpointLow: Value(0.7),
          loopVolume: Value(6),
          windSpeed: Value(4),
          humidity: Value(70),
          excludedFromGasStats: Value(true),
        ),
      );
      final doc = (await h.one('dives', 'a1'))!;
      expect(doc['entry_location'], {'latitude': 10.5, 'longitude': 20.5});
      expect(doc['exit_location'], isNull);
      expect(doc['visibility_min_m'], 8.0);
      expect(doc['boat_name'], 'Sea Star');
      expect(doc['current_direction'], 'north');
      expect(doc['swell_height_m'], 1.5);
      expect(doc['altitude_m'], 1800.0);
      expect(doc['surface_pressure_bar'], 0.82);
      expect(doc['setpoint_low_bar'], 0.7);
      expect(doc['loop_volume_l'], 6.0);
      expect(doc['wind_speed_m_s'], 4.0);
      expect(doc['humidity_percent'], 70.0);
      expect(doc['excluded_from_gas_stats'], isTrue);
    });

    test('ids of linked courses and roles are in the document', () async {
      final doc = (await h.one('dives', 'a1'))!;
      expect(doc['course_ids'], isEmpty);
      expect(doc['diver_role_ids'], isEmpty);
    });
  });

  group('dive blocks', () {
    test('custom_fields, gas_switches and events arrive as blocks', () async {
      final doc = (await h.one(
        'dives',
        'a1',
        include: ['custom_fields', 'gas_switches', 'events', 'scenarios'],
      ))!;
      expect((doc['custom_fields'] as List).cast<Map>().single['key'], 'Boat');
      expect(
        (doc['gas_switches'] as List).cast<Map>().single['tank_id'],
        'tank-a1',
      );
      expect((doc['events'] as List).cast<Map>().single['t_s'], 30);
      expect((doc['scenarios'] as List).cast<Map>().single['name'], 'What if');
    });

    test('gear and data_sources are empty lists when there are none', () async {
      final doc = (await h.one(
        'dives',
        'a1',
        include: ['gear', 'data_sources'],
      ))!;
      expect(doc['gear'], isEmpty);
      expect(doc['data_sources'], isEmpty);
    });
  });

  group('dive children', () {
    for (final (entity, own, other) in [
      ('dive_tanks', 'tank-a1', 'tank-b1'),
      ('dive_weights', 'w-a1', 'w-b1'),
      ('dive_custom_fields', 'cf-a1', 'cf-b1'),
      ('gas_switches', 'gs-a1', 'gs-b1'),
      ('dive_events', 'ev-a1', 'ev-b1'),
      ('dive_scenarios', 'sc-a1', 'sc-b1'),
    ]) {
      test('$entity reads by id and stops at the profile', () async {
        expect((await h.one(entity, own))!['dive_id'], 'a1');
        expect(await h.one(entity, other), isNull);
        expect(await h.one(entity, other, diverId: kDiverB), isNotNull);
      });

      test('$entity lists by dive', () async {
        expect(await h.list(entity), [own]);
        expect(await h.list(entity, parentId: 'a1'), [own]);
        expect(await h.list(entity, parentId: 'b1'), isEmpty);
      });
    }

    test('sightings read by id with their species name', () async {
      final doc = (await h.one('sightings', 'si'))!;
      expect(doc['species_name'], 'Turtle');
      expect(await h.one('sightings', 'si', diverId: kDiverB), isNull);
    });
  });

  group('media', () {
    test('media scope matches the library rule', () async {
      expect((await h.list('media')).toSet(), {'m1', 'm3'});
      expect((await h.list('media', diverId: kDiverB)).toSet(), {'m2', 'm3'});
      expect(await h.one('media', 'm2'), isNull);
    });

    test('a signature row emits no image data', () async {
      final doc = (await h.one('media', 'm1'))!;
      expect(doc['dive_id'], 'a1');
      expect(doc.keys, isNot(contains('image_data')));
      expect(doc.values, isNot(contains(isA<Uint8List>())));
    });
  });
}
