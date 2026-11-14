import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/dive_writes.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

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

  test('a rating of 0 clears the rating, never storing 0 (#4415)', () async {
    await writes.update(
      'd1',
      kDiverA,
      const RecordUpdate(values: {'rating': 4}),
    );
    // The planner parses what an agent sends before the write, and the plan
    // shows that parsed value.
    final parsed = writes.fields['rating']!.parse(0);
    expect(parsed, isNull);
    await writes.update(
      'd1',
      kDiverA,
      RecordUpdate(values: {'rating': parsed}),
    );

    expect((await h.one('dives', 'd1'))!['rating'], isNull);
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
      'media_time_offset_s': -47,
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
      'dive_number': 20,
      'runtime_s': 3000,
      'bottom_time_s': 2400,
      'surface_interval_s': 5400,
    };
    expect(
      samples.keys.toSet(),
      // The clocks are parsed values, buddy_roles writes the buddy links,
      // and a measured visibility clears the band this sample sets.
      writes.fields.keys.toSet().difference({
        'date_time',
        'exit_time',
        'buddy_roles',
        'visibility_m',
        'visibility_min_m',
        'visibility_max_m',
      }),
    );

    await writes.update('d1', kDiverA, const RecordUpdate(values: samples));

    final doc = (await h.one('dives', 'd1'))!;
    for (final MapEntry(:key, :value) in samples.entries) {
      expect(doc[key], value, reason: key);
    }
  });

  // Issue #4539: the shift moves the dive's media at once, so a read after
  // the write shows the depth the shift gives.
  test('media_time_offset_s places the dive\'s media again', () async {
    await ProfileSeriesRepository().insertSeries(
      diveId: 'd1',
      samples: const [
        ProfileSample(timestamp: 0, depth: 0),
        ProfileSample(timestamp: 600, depth: 20),
        ProfileSample(timestamp: 660, depth: 22),
        ProfileSample(timestamp: 1200, depth: 0),
      ],
    );
    await db
        .into(db.media)
        .insert(
          MediaCompanion.insert(
            id: 'm1',
            filePath: 'm1.jpg',
            // Stamped 11 minutes in by a camera running a minute ahead.
            takenAt: const Value(seededClock + 660000),
            createdAt: t,
            updatedAt: t,
            diveId: const Value('d1'),
          ),
        );

    await writes.update(
      'd1',
      kDiverA,
      const RecordUpdate(values: {'media_time_offset_s': -60}),
    );

    final placed = await db
        .customSelect(
          "SELECT elapsed_seconds, depth_meters FROM media_enrichment "
          "WHERE media_id = 'm1'",
        )
        .getSingle();
    expect(placed.read<int>('elapsed_seconds'), 600);
    expect(placed.read<double>('depth_meters'), 20);
  });

  group('surface_interval_s (#4333)', () {
    const hour = 3600000;

    /// An earlier dive that ended two hours before d1 starts.
    Future<void> earlierDive() =>
        dive('d0', entry: seededClock - 3 * hour, exit: seededClock - 2 * hour);

    test('a plan compares with the column, not the gap a read shows', () async {
      await earlierDive();
      final doc = (await h.one('dives', 'd1'))!;
      expect(doc['surface_interval_s'], 7200);

      final stored = await writes.stored('d1', doc);

      expect(stored['surface_interval_s'], isNull);
    });

    test('a stored interval is what a plan compares with', () async {
      await writes.update(
        'd1',
        kDiverA,
        const RecordUpdate(values: {'surface_interval_s': 600}),
      );
      final doc = (await h.one('dives', 'd1'))!;

      expect((await writes.stored('d1', doc))['surface_interval_s'], 600);
    });

    test('null clears a stored interval back to the gap', () async {
      await earlierDive();
      await writes.update(
        'd1',
        kDiverA,
        const RecordUpdate(values: {'surface_interval_s': 600}),
      );
      expect((await h.one('dives', 'd1'))!['surface_interval_s'], 600);

      await writes.update(
        'd1',
        kDiverA,
        const RecordUpdate(values: {'surface_interval_s': null}),
      );

      expect((await h.one('dives', 'd1'))!['surface_interval_s'], 7200);
    });
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
      'surface_interval_s': 4200,
    });

    final doc = (await h.one('dives', id))!;
    expect(doc['surface_interval_s'], 4200);
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
