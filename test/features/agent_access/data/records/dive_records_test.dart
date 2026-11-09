import 'dart:convert';
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

    group('surface_interval_s (#4333)', () {
      const hour = 3600000;

      /// An earlier dive of diver A that ended an hour before a1 starts.
      Future<void> earlierDive() => db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'a0',
              diveDateTime: t - 2 * hour,
              entryTime: const Value(t - 2 * hour),
              exitTime: const Value(t - hour),
              createdAt: t,
              updatedAt: t,
              diverId: const Value(kDiverA),
            ),
          );

      test('a dive with none stored reads the gap the app shows', () async {
        await earlierDive();

        expect((await h.one('dives', 'a1'))!['surface_interval_s'], 3600);
        // The profile path loads each dive on its own; it fills it too.
        final withProfile = await h.one('dives', 'a1', include: ['profile']);
        expect(withProfile!['surface_interval_s'], 3600);
      });

      test('a stored interval wins over the gap', () async {
        await earlierDive();
        await (db.update(db.dives)..where((d) => d.id.equals('a1'))).write(
          const DivesCompanion(surfaceIntervalSeconds: Value(900)),
        );

        expect((await h.one('dives', 'a1'))!['surface_interval_s'], 900);
      });

      test('the first dive has none', () async {
        expect((await h.one('dives', 'a1'))!['surface_interval_s'], isNull);
      });
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

    test('populated blocks map their rows', () async {
      await db
          .into(db.tags)
          .insert(
            TagsCompanion.insert(
              id: 'tag',
              name: 'night',
              createdAt: t,
              updatedAt: t,
              diverId: const Value(kDiverA),
            ),
          );
      await db
          .into(db.diveTags)
          .insert(
            DiveTagsCompanion.insert(
              id: 'dt',
              diveId: 'a1',
              tagId: 'tag',
              createdAt: t,
            ),
          );
      await db
          .into(db.diveTypes)
          .insert(
            DiveTypesCompanion.insert(
              id: 'wreck-custom',
              name: 'Wreck',
              createdAt: t,
              updatedAt: t,
              diverId: const Value(kDiverA),
            ),
          );
      await db
          .into(db.diveDiveTypes)
          .insert(
            DiveDiveTypesCompanion.insert(
              id: 'ddt',
              diveId: 'a1',
              diveTypeId: 'wreck-custom',
              createdAt: t,
            ),
          );
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion.insert(
              id: 'src',
              diveId: 'a1',
              isPrimary: const Value(true),
              entryTime: Value(DateTime.utc(2024, 5, 1, 10)),
              exitTime: Value(DateTime.utc(2024, 5, 1, 10, 45)),
              importedAt: DateTime.utc(2024),
              createdAt: DateTime.utc(2024),
            ),
          );
      final doc = (await h.one(
        'dives',
        'a1',
        include: ['tags', 'types', 'weights', 'media', 'data_sources'],
      ))!;
      expect(doc['tags'], ['night']);
      expect(doc['types'], [
        {'id': 'wreck-custom', 'name': 'Wreck'},
      ]);
      expect((doc['weights'] as List).cast<Map>().single['amount_kg'], 4.0);
      expect((doc['media'] as List).cast<Map>().single['id'], 'm1');
      final source = (doc['data_sources'] as List).cast<Map>().single;
      expect(source['id'], 'src');
      // Drift reads this column local-flagged; the wall clock must survive.
      expect(source['entry_time'], '2024-05-01T10:00:00.000Z');
      expect(source['exit_time'], '2024-05-01T10:45:00.000Z');
    });

    test('a type another profile owns gives no name away', () async {
      await db
          .into(db.diveTypes)
          .insert(
            DiveTypesCompanion.insert(
              id: 'their-type',
              name: 'Their private type',
              createdAt: t,
              updatedAt: t,
              diverId: const Value(kDiverB),
            ),
          );
      await db
          .into(db.diveDiveTypes)
          .insert(
            DiveDiveTypesCompanion.insert(
              id: 'ddt-theirs',
              diveId: 'a1',
              diveTypeId: 'their-type',
              createdAt: t,
            ),
          );

      final doc = (await h.one('dives', 'a1', include: ['types']))!;

      final type = (doc['types'] as List).cast<Map>().singleWhere(
        (t) => t['id'] == 'their-type',
      );
      expect(type['name'], isNull);
    });

    test('gear names the equipment on the dive', () async {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: 'reg',
              name: 'Regulator',
              type: 'regulator',
              createdAt: t,
              updatedAt: t,
              diverId: const Value(kDiverA),
            ),
          );
      await db
          .into(db.diveEquipment)
          .insert(
            DiveEquipmentCompanion.insert(diveId: 'a1', equipmentId: 'reg'),
          );
      final doc = (await h.one('dives', 'a1', include: ['gear']))!;
      final gear = (doc['gear'] as List).cast<Map>().single;
      expect(gear['equipment_id'], 'reg');
      expect(gear['name'], 'Regulator');
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

    test('safety findings read with their dismissal, by profile', () async {
      for (final dive in const ['a1', 'b1']) {
        await db
            .into(db.diveSafetyReviews)
            .insert(
              DiveSafetyReviewsCompanion.insert(
                diveId: dive,
                engineVersion: 1,
                reviewedAt: t,
              ),
            );
        await db
            .into(db.diveSafetyFindings)
            .insert(
              DiveSafetyFindingsCompanion.insert(
                id: 'f-$dive',
                diveId: dive,
                ruleId: 'rapidAscent',
                severity: 'caution',
                engineVersion: 1,
                createdAt: t,
                startTimestamp: const Value(120),
                dismissedAt: Value(dive == 'a1' ? t : null),
              ),
            );
      }

      final doc = (await h.one('safety_findings', 'f-a1'))!;

      expect(doc['dive_id'], 'a1');
      expect(doc['rule_id'], 'rapidAscent');
      expect(doc['severity'], 'caution');
      expect(doc['start_s'], 120);
      expect(doc['dismissed_at'], endsWith('Z'));
      expect(await h.one('safety_findings', 'f-b1'), isNull);
      expect(await h.list('safety_findings', parentId: 'a1'), ['f-a1']);
    });

    test('sightings read by id with their species name', () async {
      final doc = (await h.one('sightings', 'si'))!;
      expect(doc['species_name'], 'Turtle');
      expect(await h.one('sightings', 'si', diverId: kDiverB), isNull);
    });
  });

  group('media', () {
    test('a row with no capture time still reads', () async {
      await db
          .into(db.media)
          .insert(
            MediaCompanion.insert(
              id: 'undated',
              filePath: 'path/undated.jpg',
              diveId: const Value('a1'),
              createdAt: t,
              updatedAt: t,
            ),
          );
      final doc = (await h.one('media', 'undated'))!;
      expect(doc['captured_time'], endsWith('Z'));
    });

    test('media scope matches the library rule', () async {
      expect((await h.list('media')).toSet(), {'m1', 'm3'});
      expect((await h.list('media', diverId: kDiverB)).toSet(), {'m2', 'm3'});
      expect(await h.one('media', 'm2'), isNull);
    });

    test('a feed item keeps its URL out of the document', () async {
      await db
          .into(db.media)
          .insert(
            MediaCompanion.insert(
              id: 'feed',
              filePath: '',
              sourceType: const Value('manifestEntry'),
              url: const Value('https://example.test/a.jpg?token=secret'),
              diveId: const Value('a1'),
              createdAt: t,
              updatedAt: t,
            ),
          );
      final doc = (await h.one('media', 'feed'))!;
      expect(doc['source_type'], 'manifestEntry');
      expect(jsonEncode(doc), isNot(contains('token=secret')));

      final dive = (await h.one('dives', 'a1', include: ['media']))!;
      expect(jsonEncode(dive), isNot(contains('token=secret')));
    });

    test('a signature row emits no image data', () async {
      final doc = (await h.one('media', 'm1'))!;
      expect(doc['dive_id'], 'a1');
      expect(doc.keys, isNot(contains('image_data')));
      expect(doc.values, isNot(contains(isA<Uint8List>())));
    });
  });
}
