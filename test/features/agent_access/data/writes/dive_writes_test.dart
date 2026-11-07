import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/dive_writes.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';

void main() {
  late AppDatabase db;
  late RecordHarness h;
  late DiveWrites writes;
  const t = kSeedTime;
  const seededClock = 1710408600000; // 2024-03-14T09:30:00Z

  Future<void> dive(String id, {int? entry, int? exit}) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diverId: const Value(kDiverA),
          diveDateTime: seededClock,
          createdAt: t,
          updatedAt: t,
          notes: const Value('seeded notes'),
          boatName: const Value('Sea Star'),
          waterTemp: const Value(12.0),
          entryTime: Value(entry),
          exitTime: Value(exit),
        ),
      );

  Future<void> buddy(String id) => db
      .into(db.buddies)
      .insert(
        BuddiesCompanion.insert(
          id: id,
          name: id,
          createdAt: t,
          updatedAt: t,
          diverId: const Value(kDiverA),
        ),
      );

  Future<void> tag(String id) => db
      .into(db.tags)
      .insert(
        TagsCompanion.insert(
          id: id,
          name: id,
          createdAt: t,
          updatedAt: t,
          diverId: const Value(kDiverA),
        ),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    h = RecordHarness(db);
    await seedTwoDivers(db);
    writes = DiveWrites(RecordRepositories());
    await dive('d1', entry: seededClock, exit: seededClock + 2700000);
  });

  tearDown(() => tearDownTestDatabase());

  test('update writes only the named columns', () async {
    await writes.update(
      'd1',
      kDiverA,
      const RecordUpdate(values: {'water_temp_c': 24.5}),
    );

    final doc = await h.one('dives', 'd1');
    expect(doc!['water_temp_c'], 24.5);
    expect(doc['boat_name'], 'Sea Star');
    expect(doc['notes'], 'seeded notes');
  });

  test('null clears a nullable column', () async {
    await writes.update(
      'd1',
      kDiverA,
      const RecordUpdate(values: {'boat_name': null}),
    );

    expect((await h.one('dives', 'd1'))!['boat_name'], isNull);
  });

  test('every codec key has a column', () async {
    const samples = <String, Object?>{
      'name': 'Morning dive',
      'notes': 'edited',
      'max_depth_m': 31.0,
      'avg_depth_m': 18.0,
      'water_temp_c': 21.0,
      'air_temp_c': 28.0,
      'visibility': 'good',
      'rating': 4,
      'is_favorite': true,
      'excluded_from_stats': true,
      'excluded_from_gas_stats': true,
      'dive_operator': 'Blue Ops',
      'boat_name': 'Marlin',
      'boat_captain': 'Rui',
      'dive_master': 'Noa',
      'buddy': 'Ana',
      'current_direction': 'north',
      'current_strength': 'light',
      'swell_height_m': 1.5,
      'surface_conditions': 'Glassy',
      'entry_method': 'boat',
      'exit_method': 'shore',
      'water_type': 'salt',
      'altitude_m': 300.0,
      'weather_description': 'Sunny',
    };
    expect(
      samples.keys.toSet(),
      // The clock moves as a shift, and buddy_roles writes the buddy links.
      writes.fields.keys.toSet().difference({'date_time', 'buddy_roles'}),
    );

    await writes.update('d1', kDiverA, const RecordUpdate(values: samples));

    final doc = (await h.one('dives', 'd1'))!;
    for (final MapEntry(:key, :value) in samples.entries) {
      expect(doc[key], value, reason: key);
    }
  });

  test('date_time moves entry and exit by the same difference', () async {
    final moved = DateTime.utc(2024, 3, 14, 11, 30);

    await writes.update(
      'd1',
      kDiverA,
      RecordUpdate(values: {'date_time': moved}),
    );

    final doc = (await h.one('dives', 'd1'))!;
    expect(doc['date_time'], '2024-03-14T11:30:00.000Z');
    expect(doc['entry_time'], '2024-03-14T11:30:00.000Z');
    expect(doc['exit_time'], '2024-03-14T12:15:00.000Z');
  });

  test('adding a buddy keeps the others', () async {
    await buddy('b1');
    await buddy('b2');
    await writes.update(
      'd1',
      kDiverA,
      const RecordUpdate(
        relations: {
          'buddies': RelationDelta(add: {'b1'}),
        },
      ),
    );

    await writes.update(
      'd1',
      kDiverA,
      const RecordUpdate(
        relations: {
          'buddies': RelationDelta(add: {'b2'}),
        },
      ),
    );

    expect(await writes.currentRelation('d1', 'buddies'), {'b1', 'b2'});
    final links = await BuddyRepository().getBuddiesForDive('d1');
    expect(links.map((l) => l.primaryRole.id), everyElement('buddy'));
  });

  test('a removed buddy leaves and a kept one stays', () async {
    await buddy('b1');
    await buddy('b2');
    await writes.update(
      'd1',
      kDiverA,
      const RecordUpdate(
        relations: {
          'buddies': RelationDelta(add: {'b1', 'b2'}),
        },
      ),
    );

    await writes.update(
      'd1',
      kDiverA,
      const RecordUpdate(
        relations: {
          'buddies': RelationDelta(remove: {'b1'}),
        },
      ),
    );

    expect(await writes.currentRelation('d1', 'buddies'), {'b2'});
  });

  test('tags are added and removed', () async {
    await tag('t1');
    await tag('t2');
    await writes.update(
      'd1',
      kDiverA,
      const RecordUpdate(
        relations: {
          'tags': RelationDelta(add: {'t1', 't2'}),
        },
      ),
    );
    await writes.update(
      'd1',
      kDiverA,
      const RecordUpdate(
        relations: {
          'tags': RelationDelta(remove: {'t1'}),
        },
      ),
    );

    expect(await writes.currentRelation('d1', 'tags'), {'t2'});
  });

  test('site snaps the water type as bulk edit does', () async {
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 's1',
            name: 'Blue Hole',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverA),
            waterType: const Value('salt'),
          ),
        );

    await writes.update(
      'd1',
      kDiverA,
      const RecordUpdate(
        relations: {
          'site': RelationDelta(add: {'s1'}),
        },
      ),
    );

    final doc = (await h.one('dives', 'd1'))!;
    expect((doc['site'] as Map)['id'], 's1');
    expect(doc['water_type'], 'salt');
    expect(await writes.currentRelation('d1', 'site'), {'s1'});
  });

  group('currentRelation reads what a full dive read gives', () {
    Future<Set<String>> fromDive(String relation) async {
      final dive = await RecordRepositories().dives.getDiveById('d1');
      return switch (relation) {
        'tags' => {for (final t in dive!.tags) t.id},
        'types' => dive!.diveTypeIds.toSet(),
        _ => {?dive!.site?.id},
      };
    }

    test('for tags', () async {
      await tag('t1');
      await db
          .into(db.diveTags)
          .insert(
            DiveTagsCompanion.insert(
              id: 'dt1',
              diveId: 'd1',
              tagId: 't1',
              createdAt: t,
            ),
          );

      expect(await writes.currentRelation('d1', 'tags'), {'t1'});
      expect(
        await writes.currentRelation('d1', 'tags'),
        await fromDive('tags'),
      );
    });

    test('for types, falling back to the legacy column', () async {
      expect(
        await writes.currentRelation('d1', 'types'),
        await fromDive('types'),
      );
      expect(await writes.currentRelation('d1', 'types'), isNotEmpty);
    });

    test('for types held as links', () async {
      for (final (id, type) in [('l1', 'wreck'), ('l2', 'night')]) {
        await db
            .into(db.diveDiveTypes)
            .insert(
              DiveDiveTypesCompanion.insert(
                id: id,
                diveId: 'd1',
                diveTypeId: type,
                createdAt: t,
              ),
            );
      }

      expect(await writes.currentRelation('d1', 'types'), {'wreck', 'night'});
      expect(
        await writes.currentRelation('d1', 'types'),
        await fromDive('types'),
      );
    });

    test('for the site, and nothing for a dive that has gone', () async {
      await db
          .into(db.diveSites)
          .insert(
            DiveSitesCompanion.insert(
              id: 's1',
              name: 'Blue Hole',
              createdAt: t,
              updatedAt: t,
              diverId: const Value(kDiverA),
            ),
          );
      await (db.update(db.dives)..where((d) => d.id.equals('d1'))).write(
        const DivesCompanion(siteId: Value('s1')),
      );

      expect(await writes.currentRelation('d1', 'site'), {'s1'});
      expect(
        await writes.currentRelation('d1', 'site'),
        await fromDive('site'),
      );
      for (final relation in ['tags', 'types', 'site']) {
        expect(await writes.currentRelation('gone', relation), isEmpty);
      }
    });
  });

  test('create returns an id the record reads back under', () async {
    final id = await writes.create(kDiverA, {
      'date_time': DateTime.utc(2025, 1, 2, 8),
      'max_depth_m': 18.0,
      'water_type': 'fresh',
    });

    final doc = (await h.one('dives', id))!;
    expect(doc['diver_id'], kDiverA);
    expect(doc['date_time'], '2025-01-02T08:00:00.000Z');
    expect(doc['max_depth_m'], 18.0);
    expect(doc['water_type'], 'fresh');
    expect(doc['dive_number'], isNotNull);
  });

  test('delete removes the row', () async {
    await writes.delete('d1', kDiverA);

    expect(await h.one('dives', 'd1'), isNull);
  });
}
