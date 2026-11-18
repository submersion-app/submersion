import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';

import 'identification_fixtures.dart';

void main() {
  late AppDatabase db;
  late MediaIdentificationRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
    repo = MediaIdentificationRepository(database: db);
  });
  tearDown(() => db.close());

  Future<void> addMedia(String id) => db
      .into(db.media)
      .insert(
        MediaCompanion.insert(id: id, filePath: '', createdAt: 0, updatedAt: 0),
      );

  test('a stored run and its identifications read back unchanged', () async {
    await repo.storeRun(run(), insert: [identification('a')], deleteIds: []);

    expect(await repo.runFor('m1'), run());
    expect(await repo.forMedia('m1'), [identification('a')]);
    expect(await repo.runFor('other'), isNull);
    expect(await repo.forMedia('other'), isEmpty);
  });

  test('a run with nothing found is stored', () async {
    await repo.storeRun(run(count: 0), insert: const [], deleteIds: const []);
    expect((await repo.runFor('m1'))!.detectionCount, 0);
  });

  test(
    'storing again replaces the run and removes what it is told to',
    () async {
      await repo.storeRun(
        run(),
        insert: [identification('a'), identification('b')],
        deleteIds: [],
      );
      final newer = run(count: 2).copyWith(packVersion: '2026.12.1');
      await repo.storeRun(
        newer,
        insert: [identification('c')],
        deleteIds: ['a'],
      );

      expect((await repo.runFor('m1'))!.packVersion, '2026.12.1');
      expect(
        (await repo.forMedia('m1')).map((i) => i.id),
        unorderedEquals(['b', 'c']),
      );
    },
  );

  test('decisions are updated in place', () async {
    await repo.storeRun(run(), insert: [identification('a')], deleteIds: []);
    final accepted = identification(
      'a',
      decision: IdentificationDecision.accepted,
      decidedSpeciesId: 'sp_queen_parrotfish',
      decidedAt: fixtureT1,
    );
    await repo.updateDecisions([accepted]);
    expect(await repo.forMedia('m1'), [accepted]);
  });

  test('updating can also move the run on', () async {
    await repo.storeRun(run(), insert: [identification('a')], deleteIds: []);
    final renamed = run().copyWith(
      packVersion: '2026.12.1',
      locationCell: () => null,
    );
    await repo.updateNames([identification('a')], run: renamed);
    expect(await repo.runFor('m1'), renamed);
  });

  test('an update that lands after the rows were cleared brings nothing '
      'back', () async {
    await repo.storeRun(run(), insert: [identification('a')], deleteIds: []);
    final dismissed = identification(
      'a',
      decision: IdentificationDecision.rejected,
      decidedAt: fixtureT1,
    );
    await repo.deleteForMedia(['m1']);
    await repo.updateDecisions([dismissed]);
    await repo.updateNames([dismissed], run: run());
    expect(await repo.forMedia('m1'), isEmpty);
    expect(await repo.runFor('m1'), isNull);
  });

  test('deleting for media removes runs and identifications and returns '
      'the ids', () async {
    await repo.storeRun(run(), insert: [identification('a')], deleteIds: []);
    await repo.storeRun(
      run(mediaId: 'm2'),
      insert: [identification('b', mediaId: 'm2')],
      deleteIds: [],
    );

    expect(await repo.deleteForMedia(['m1']), ['a']);
    expect(await repo.runFor('m1'), isNull);
    expect(await repo.forMedia('m2'), hasLength(1));
  });

  test('orphans are media ids with rows here but no media row', () async {
    await addMedia('m-live');
    await repo.storeRun(
      run(mediaId: 'm-live'),
      insert: [identification('a', mediaId: 'm-live')],
      deleteIds: [],
    );
    await repo.storeRun(
      run(mediaId: 'm-gone'),
      insert: const [],
      deleteIds: const [],
    );
    await repo.storeRun(
      run(mediaId: 'm-gone-2'),
      insert: [identification('b', mediaId: 'm-gone-2')],
      deleteIds: [],
    );

    expect(
      await repo.orphanMediaIds(),
      unorderedEquals(['m-gone', 'm-gone-2']),
    );
  });

  test('count and media ids cover every identification and run', () async {
    await repo.storeRun(
      run(),
      insert: [identification('a'), identification('b')],
      deleteIds: [],
    );
    await repo.storeRun(
      run(mediaId: 'm2', count: 0),
      insert: const [],
      deleteIds: const [],
    );
    expect(await repo.count(), 2);
    expect(await repo.mediaIds(), unorderedEquals(['m1', 'm2']));
  });

  test('tagged species come with their scientific names', () async {
    await addMedia('m1');
    await db
        .into(db.species)
        .insert(
          SpeciesCompanion.insert(
            id: 'own-1',
            commonName: 'Brown Chromis',
            scientificName: const Value('Chromis multilineata'),
            category: 'fish',
          ),
        );
    await db
        .into(db.mediaSpecies)
        .insert(
          MediaSpeciesCompanion.insert(
            id: 't1',
            mediaId: 'm1',
            speciesId: 'own-1',
            createdAt: 0,
          ),
        );
    expect(await repo.taggedSpecies('m1'), [
      const TaggedSpecies(
        speciesId: 'own-1',
        scientificName: 'Chromis multilineata',
      ),
    ]);
    expect(await repo.taggedSpecies('m2'), isEmpty);
  });

  group('videos (issue #4675)', () {
    test('a track round-trips with its time range, path, claim and '
        'flags', () async {
      final fish = track('t1', claimedSpeciesId: 'sp_x', confident: true);
      await repo.storeRun(videoRun(), insert: [fish], deleteIds: []);
      final stored = (await repo.forMedia('v1')).single;
      expect(stored.startMs, 1000);
      expect(stored.endMs, 2000);
      expect(stored.bestMs, fish.bestMs);
      expect(stored.claimedSpeciesId, 'sp_x');
      expect(stored.confident, isTrue);
      expect(stored.specific, isTrue);
      expect(stored.path, hasLength(fish.path.length));
      for (var k = 0; k < fish.path.length; k++) {
        expect(stored.path[k].ms, fish.path[k].ms);
        expect(stored.path[k].box.x, closeTo(fish.path[k].box.x, 1e-4));
      }
    });

    test('a run keeps how far the scan got and the video length', () async {
      await repo.storeRun(videoRun(), insert: const [], deleteIds: const []);
      final stored = (await repo.runFor('v1'))!;
      expect(stored.scannedMs, 10000);
      expect(stored.videoDurationMs, 25000);
    });

    test('a photo row keeps null video fields', () async {
      await repo.storeRun(run(), insert: [identification('a')], deleteIds: []);
      final stored = (await repo.forMedia('m1')).single;
      expect(stored.isTrack, isFalse);
      expect(stored.path, isEmpty);
      expect(stored.claimedSpeciesId, isNull);
      expect((await repo.runFor('m1'))!.scannedMs, isNull);
      final raw = await db
          .customSelect('SELECT track_path FROM media_identifications')
          .getSingle();
      expect(raw.data['track_path'], isNull);
    });

    test('a corrupt path reads as no path', () async {
      await repo.storeRun(videoRun(), insert: [track('t1')], deleteIds: []);
      await db.customStatement(
        "UPDATE media_identifications SET track_path = X'02'",
      );
      final stored = (await repo.forMedia('v1')).single;
      expect(stored.isTrack, isTrue);
      expect(stored.path, isEmpty);
    });

    test('a claim is written to its row', () async {
      await repo.storeRun(videoRun(), insert: [track('t1')], deleteIds: []);
      await repo.claim('t1', 'sp_y');
      expect((await repo.forMedia('v1')).single.claimedSpeciesId, 'sp_y');
    });

    test(
      'a decision written from an older read keeps a claim made since',
      () async {
        final read = track('t1');
        await repo.storeRun(videoRun(), insert: [read], deleteIds: []);
        await repo.claim('t1', 'sp_y');
        await repo.updateDecisions([
          read.copyWith(decision: IdentificationDecision.rejected),
        ]);
        final stored = (await repo.forMedia('v1')).single;
        expect(stored.decision, IdentificationDecision.rejected);
        expect(stored.claimedSpeciesId, 'sp_y');
      },
    );

    test('a decision written from an older read keeps the path and names '
        'a scan stored since', () async {
      final read = track('t1', endMs: 2000);
      await repo.storeRun(videoRun(), insert: [read], deleteIds: []);
      final grown = track('t1', endMs: 4000).copyWith(openScore: 0.42);
      await repo.storeRun(videoRun(), insert: [grown], deleteIds: []);
      await repo.updateDecisions([
        read.copyWith(decision: IdentificationDecision.rejected),
      ]);
      final stored = (await repo.forMedia('v1')).single;
      expect(stored.decision, IdentificationDecision.rejected);
      expect(stored.endMs, 4000);
      // The codec rounds each box; the samples are what tell.
      expect(stored.path, hasLength(grown.path.length));
      expect(stored.path.last.ms, 4000);
      expect(stored.openScore, 0.42);
    });

    test(
      'names written from an older read keep a decision made since',
      () async {
        final read = track('t1');
        await repo.storeRun(videoRun(), insert: [read], deleteIds: []);
        final decided = read.copyWith(
          decision: IdentificationDecision.accepted,
          decidedSpeciesId: 'sp_x',
          decidedAt: fixtureT1,
        );
        await repo.updateDecisions([decided]);
        await repo.updateNames([
          read.copyWith(openScore: 0.33, confident: false),
        ], run: videoRun());
        final stored = (await repo.forMedia('v1')).single;
        expect(stored.decision, IdentificationDecision.accepted);
        expect(stored.decidedSpeciesId, 'sp_x');
        expect(stored.openScore, 0.33);
        expect(stored.confident, isFalse);
      },
    );

    test('a claim on a missing row writes nothing', () async {
      await repo.claim('gone', 'sp_y');
      expect(await repo.count(), 0);
    });
  });

  test('a write ticks the change stream', () async {
    final ticks = <void>[];
    final sub = repo.watchChanges().listen(ticks.add);
    addTearDown(sub.cancel);
    await repo.storeRun(run(), insert: [identification('a')], deleteIds: []);
    await pumpEventQueue();
    expect(ticks, isNotEmpty);
  });
}
