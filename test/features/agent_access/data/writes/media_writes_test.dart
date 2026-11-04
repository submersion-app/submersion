import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/families/media_writes.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/data/writes/write_catalog.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// A photo's edits, as the media viewer makes them: its moment on the dive,
/// the dive it is on, who and what is in it, its colour, and its delete.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;

  Future<void> photo(String id, {String? dive = 'd1'}) => db
      .into(db.media)
      .insert(
        MediaCompanion.insert(
          id: id,
          filePath: '$id.jpg',
          takenAt: const Value(kSeedTime),
          createdAt: kSeedTime,
          updatedAt: kSeedTime,
          diveId: Value(dive),
        ),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(
      db,
      catalog: (repos) => WriteCatalog.of([
        MediaWrites(repos, profileLength: (_) async => 3000),
      ]),
    );
    await h.seed();
    await photo('m1');
  });
  tearDown(() => tearDownTestDatabase());

  test(
    'a photo is pinned to a moment, moved to another dive and deleted',
    () async {
      await h.run([
        updateOp('media', 'm1', {'manual_elapsed_s': 600}),
      ]);
      expect((await h.one('media', 'm1'))!['manual_elapsed_s'], 600);

      await h.dive('d3');
      await h.run([
        updateOp('media', 'm1', {'dive_id': 'd3'}),
      ]);
      expect((await h.one('media', 'm1'))!['dive_id'], 'd3');

      await h.run([deleteOp('media', 'm1')]);
      expect(await h.one('media', 'm1'), isNull);
    },
  );

  test('a pin past the dive\'s end is refused', () async {
    await photo('loose', dive: null);

    final plan = await h.preview([
      updateOp('media', 'm1', {'manual_elapsed_s': 3001}),
    ]);
    expect(plan.items.single.block!.reason, BlockReason.invalidValue);
    final loose = await h.preview([
      updateOp('media', 'loose', {'manual_elapsed_s': 10}),
    ]);
    expect(loose.items.single.block!.reason, BlockReason.invalidValue);
  });

  test('a person is tagged once per photo', () async {
    final rui = await ChildWriteHarness(db)
        .run([
          createOp('buddies', {'name': 'Rui'}),
        ])
        .then((r) => r.created.single.id);

    await h.run([
      updateOp('media', 'm1', {
        'people': [
          {
            'buddy_id': rui,
            'box': {'x': 0.1, 'y': 0.2, 'width': 0.3, 'height': 0.3},
          },
          {'diver_id': kDiverA},
        ],
      }),
    ]);
    final tags = await db.select(db.mediaPeople).get();
    expect({for (final t in tags) t.buddyId ?? t.diverId}, {rui, kDiverA});

    final twice = await h.preview([
      updateOp('media', 'm1', {
        'people': [
          {'buddy_id': rui},
          {'buddy_id': rui},
        ],
      }),
    ]);
    expect(twice.items.single.block!.reason, BlockReason.invalidValue);

    await h.run([
      updateOp('media', 'm1', {
        'people': [
          {'diver_id': kDiverA},
        ],
      }),
    ]);
    expect(await db.select(db.mediaPeople).get(), hasLength(1));
  });

  // The people picker lists the photo's own profile's buddies.
  test('a photo cannot tag another profile\'s buddy', () async {
    final theirs = await ChildWriteHarness(db)
        .run([
          createOp('buddies', {'name': 'Ana'}, diver: kDiverB),
        ])
        .then((r) => r.created.single.id);

    final plan = await h.preview([
      updateOp('media', 'm1', {
        'people': [
          {'buddy_id': theirs},
        ],
      }),
    ]);

    expect(plan.items.single.block!.reason, BlockReason.otherProfileReference);
  });

  // A photo on no dive belongs to the profile in use, whose buddies the
  // people picker lists.
  test('a photo on no dive tags the profile\'s own buddy', () async {
    await photo('loose', dive: null);
    final rui = await ChildWriteHarness(db)
        .run([
          createOp('buddies', {'name': 'Rui'}),
        ])
        .then((r) => r.created.single.id);

    final plan = await h.preview([
      updateOp('media', 'loose', {
        'people': [
          {'buddy_id': rui},
        ],
      }),
    ]);

    expect(plan.items.single.block, isNull);
  });

  test('a species tag on a dive photo lists the sighting it adds', () async {
    final fish = await ChildWriteHarness(db)
        .run([
          createOp('species', {'common_name': 'Clownfish', 'category': 'fish'}),
        ])
        .then((r) => r.created.single.id);

    final plan = await h.preview([
      {
        ...updateOp('media', 'm1', {}),
        'relations': {
          'species_ids': {
            'add': [fish],
          },
        },
      },
    ]);
    expect(plan.items.single.alsoCreates, {'sightings': 1});
    await h.apply(plan);

    expect(await db.select(db.mediaSpecies).get(), hasLength(1));
    expect(await db.select(db.sightings).get(), hasLength(1));
  });

  test('a colour slider of 2 is refused', () async {
    final plan = await h.preview([
      updateOp('media', 'm1', {
        'color_adjustment': {'warmth': 2},
      }),
    ]);
    expect(plan.items.single.block!.reason, BlockReason.invalidValue);

    await h.run([
      updateOp('media', 'm1', {
        'color_adjustment': {'warmth': 0.4, 'strength': 0.8},
      }),
    ]);
    final adjusted = (await h.one('media', 'm1'))!['color_adjustment']! as Map;
    expect([adjusted['warmth'], adjusted['strength']], [0.4, 0.8]);
  });

  test(
    'a delete holds the cloud delete and lists the links it drops',
    () async {
      await db
          .into(db.mediaPeople)
          .insert(
            MediaPeopleCompanion.insert(
              id: 'p1',
              mediaId: 'm1',
              diverId: const Value(kDiverA),
              createdAt: kSeedTime,
              updatedAt: kSeedTime,
            ),
          );

      final plan = await h.preview([deleteOp('media', 'm1')]);
      expect(plan.items.single.reach.parts, {'media_people': 1});
      await h.apply(plan);

      expect(await db.select(db.mediaPeople).get(), isEmpty);
    },
  );

  // The delete waits with the cloud copy's delete, as the viewer's does, so
  // a revert can still find the copy.
  test('a delete lists the cloud copy and never starts the worker', () async {
    var kicks = 0;
    final cache = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(cache.close);
    final queue = MediaTransferQueueRepository(database: cache);
    h = ChildWriteHarness(
      db,
      catalog: (repos) => WriteCatalog.of([
        MediaWrites(
          repos,
          profileLength: (_) async => 3000,
          kickWorker: () async => kicks++,
          transferQueue: () => queue,
        ),
      ]),
    );
    await (db.update(db.media)..where((m) => m.id.equals('m1'))).write(
      const MediaCompanion(
        contentHash: Value('hash-1'),
        remoteUploadedAt: Value(kSeedTime),
      ),
    );

    final plan = await h.preview([deleteOp('media', 'm1')]);
    expect(plan.items.single.reach.records, {'cloud_copies': 1});
    await h.apply(plan);

    expect(await h.one('media', 'm1'), isNull);
    expect(await queue.hasHeldDelete('hash-1'), isTrue);
    expect(kicks, 0);
  });
}
