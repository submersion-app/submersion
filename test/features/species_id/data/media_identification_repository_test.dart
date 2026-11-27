import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/naming_bars.dart';
import 'package:submersion/features/species_id/domain/entities/scanned_ranges.dart';

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

  test('a run keeps where it came from, its run id and its naming bars, '
      'and its rows their run id (issue #4876)', () async {
    const bars = NamingBars(
      minCropSide: 64,
      minOpenScore: 0.15,
      suggestScore: 0.5,
      suggestScoreNoLocation: 0.7,
    );
    final made = run().copyWith(
      analysedBy: () => 'laptop',
      runId: () => 'r1',
      namingBars: () => bars,
    );
    final row = identification('a').copyWith(runId: () => 'r1');
    await repo.storeRun(made, insert: [row], deleteIds: []);

    expect(await repo.runFor('m1'), made);
    expect(await repo.forMedia('m1'), [row]);
  });

  test('a run written without an origin keeps the one stored', () async {
    await repo.storeRun(
      run().copyWith(analysedBy: () => 'laptop', runId: () => 'r1'),
      insert: const [],
      deleteIds: const [],
    );
    await repo.storeRun(run(count: 0), insert: const [], deleteIds: const []);
    final stored = (await repo.runFor('m1'))!;
    expect(stored.analysedBy, 'laptop');
    expect(stored.runId, 'r1');
  });

  test(
    'a media run and its rows are read in one snapshot (issue #4721)',
    () async {
      await repo.storeRun(
        run(),
        insert: [identification('a')],
        deleteIds: const [],
      );
      final (stored, rows) = await repo.forMediaWithRun('m1');
      expect(stored?.packVersion, '2026.11.1');
      expect(rows.map((i) => i.id), ['a']);
      final (none, nothing) = await repo.forMediaWithRun('other');
      expect(none, isNull);
      expect(nothing, isEmpty);
    },
  );

  test('many media runs and rows read in one snapshot, track paths left out '
      'when not wanted (issue #4727)', () async {
    await repo.storeRun(run(), insert: [identification('a')], deleteIds: []);
    await repo.storeRun(videoRun(), insert: [track('t1')], deleteIds: []);

    final (runs, rows) = await repo.forMediaIdsWithRuns([
      'm1',
      'v1',
      'other',
    ], withPaths: false);
    expect(runs.keys.toSet(), {'m1', 'v1'});
    expect(rows['m1']!.map((i) => i.id), ['a']);
    expect(rows['v1']!.single.path, isEmpty);
    expect(rows['v1']!.single.isPending, isFalse);

    final (_, withPaths) = await repo.forMediaIdsWithRuns(['v1']);
    expect(withPaths['v1']!.single.path, isNotEmpty);
  });

  test('a fixed logbook and a way to find one are refused together, '
      'in every build', () {
    expect(
      () => MediaIdentificationRepository(
        database: db,
        currentDatabase: () => db,
      ),
      throwsArgumentError,
    );
  });

  group('a transaction stays on the logbook open when it began', () {
    late AppDatabase other;
    late MediaIdentificationRepository switching;

    setUp(() async {
      other = AppDatabase(
        NativeDatabase.memory(setup: registerAppSqlFunctions),
      );
      addTearDown(other.close);
      await repo.storeRun(run(), insert: [identification('a')], deleteIds: []);
      // The first lookup finds this logbook; every later one, another.
      var lookups = 0;
      switching = MediaIdentificationRepository(
        currentDatabase: () => lookups++ == 0 ? db : other,
      );
    });

    test('a snapshot reads both from there', () async {
      final (stored, rows) = await switching.forMediaWithRun('m1');
      expect(stored?.packVersion, '2026.11.1');
      expect(rows.map((i) => i.id), ['a']);
    });

    test('a batched read stays on one logbook across its chunks', () async {
      // 500 to a chunk: m1 is read in the second.
      final ids = [for (var i = 0; i < 500; i++) 'x$i', 'm1'];
      // The suggestions read joins the media row.
      await addMedia('m1');
      var lookups = 0;
      MediaIdentificationRepository fresh() => MediaIdentificationRepository(
        currentDatabase: () => lookups++ == 0 ? db : other,
      );

      expect((await fresh().forMediaIds(ids))['m1']!.map((i) => i.id), ['a']);
      lookups = 0;
      expect((await fresh().runsFor(ids)).keys, ['m1']);
      lookups = 0;
      expect(
        await fresh().mediaIdsWithSuggestions(anyUndecided: true, among: ids),
        ['m1'],
      );
    });

    test('a snapshot of many media reads both from there', () async {
      final (runs, rows) = await switching.forMediaIdsWithRuns([
        'm1',
      ], withPaths: false);
      expect(runs['m1']?.packVersion, '2026.11.1');
      expect(rows['m1']!.map((i) => i.id), ['a']);
    });

    test('a store after reading reads and writes there', () async {
      List<MediaIdentification>? read;
      await switching.storeRunAfterReading(
        'm1',
        read: true,
        build: (current) async {
          read = current;
          return (
            run: run(count: 2),
            insert: [identification('b')],
            deleteIds: const <String>[],
          );
        },
      );
      expect(read?.map((i) => i.id), ['a']);
      expect((await repo.forMedia('m1')).map((i) => i.id), ['a', 'b']);
      expect(await other.select(other.mediaIdentifications).get(), isEmpty);
    });

    test('renaming moves the rows and the run on there', () async {
      final renamed = run().copyWith(
        packVersion: '2026.12.1',
        locationCell: () => null,
      );
      final named = identification('a').copyWith(openScore: 0.7);
      await switching.updateNames([named], run: renamed);
      expect(await repo.runFor('m1'), renamed);
      expect((await repo.forMedia('m1')).single.openScore, 0.7);
      expect(await other.select(other.mediaIdentificationRuns).get(), isEmpty);
    });

    test('a decision is written there', () async {
      final dismissed = identification(
        'a',
        decision: IdentificationDecision.rejected,
        decidedAt: fixtureT1,
      );
      await switching.updateDecisions([dismissed]);
      expect(await repo.forMedia('m1'), [dismissed]);
    });

    test('a stored run and its rows are written there', () async {
      await switching.storeRun(
        run(count: 2),
        insert: [identification('b')],
        deleteIds: const ['a'],
      );
      expect((await repo.runFor('m1'))!.detectionCount, 2);
      expect((await repo.forMedia('m1')).map((i) => i.id), ['b']);
      expect(await other.select(other.mediaIdentificationRuns).get(), isEmpty);
      expect(await other.select(other.mediaIdentifications).get(), isEmpty);
    });

    test('a deletion removes the rows and the run there', () async {
      expect(await switching.deleteForMedia(['m1']), ['a']);
      expect(await repo.runFor('m1'), isNull);
      expect(await repo.forMedia('m1'), isEmpty);
    });

    test('a callback it left behind follows the logbook open when it runs, '
        'not the one the transaction began on', () async {
      late Zone inside;
      await switching.storeRunAfterReading(
        'm1',
        read: false,
        build: (_) async {
          inside = Zone.current;
          return null;
        },
      );
      expect(await inside.run(() => switching.forMedia('m1')), isEmpty);
    });
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
    expect(await repo.updateNames([identification('a')], run: renamed), ['a']);
    expect(await repo.runFor('m1'), renamed);
  });

  test('a rename read before another device\'s run synced in writes '
      'nothing over it (issue #4876)', () async {
    final mine = run().copyWith(runId: () => 'mine');
    await repo.storeRun(mine, insert: [identification('a')], deleteIds: []);
    final theirs = run().copyWith(
      runId: () => 'theirs',
      analysedBy: () => 'laptop',
      packVersion: '2026.11.9',
    );
    await repo.storeRun(theirs, insert: const [], deleteIds: []);

    final written = await repo.updateNames([
      identification('a').copyWith(openScore: 0.9),
    ], run: mine.copyWith(packVersion: '2026.12.1'));

    expect(written, isEmpty, reason: 'its crops are not promoted either');
    expect(await repo.runFor('m1'), theirs);
    expect((await repo.forMedia('m1')).single.openScore, 0.42);
  });

  test('a rename moves only what naming sets: the pack, the place and the '
      'bars; the scan as stored stays', () async {
    await repo.storeRun(
      videoRun().copyWith(scannedMs: () => 5000),
      insert: const [],
      deleteIds: [],
    );
    // Read when only a second had been scanned.
    final stale = videoRun().copyWith(scannedMs: () => 1000);

    await repo.updateNames(const [], run: stale.copyWith(packVersion: 'p2'));

    final stored = (await repo.runFor('v1'))!;
    expect(stored.packVersion, 'p2');
    expect(stored.scannedMs, 5000);
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

  test('orphans are media ids with rows here whose media was deleted; rows '
      'whose media has not arrived yet are not (issue #4876)', () async {
    Future<void> tombstone(String mediaId) => db.customStatement(
      'INSERT INTO deletion_log (id, entity_type, record_id, deleted_at) '
      "VALUES ('t-$mediaId', 'media', '$mediaId', 1)",
    );
    await addMedia('m-live');
    // Synced from another device: its media may still be on its way.
    await repo.storeRun(
      run(mediaId: 'm-waiting').copyWith(analysedBy: () => 'laptop'),
      insert: [identification('w', mediaId: 'm-waiting')],
      deleteIds: [],
    );
    // Made here, its media gone with no tombstone left: an orphan.
    await repo.storeRun(
      run(mediaId: 'm-mine').copyWith(analysedBy: () => 'phone'),
      insert: const [],
      deleteIds: const [],
    );
    await tombstone('m-gone');
    await tombstone('m-gone-2');
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
      await repo.orphanMediaIds(deviceId: 'phone'),
      unorderedEquals(['m-gone', 'm-gone-2', 'm-mine']),
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

    test("a run's scanned stretches round trip (issue #4709)", () async {
      final ranges = const ScannedRanges().add(0, 12000).add(30000, 40000);
      await repo.storeRun(
        videoRun().copyWith(scannedRanges: () => ranges),
        insert: const [],
        deleteIds: const [],
      );
      expect((await repo.runFor('v1'))!.scannedRanges, ranges);
    });

    test('a run stored without stretches reads its mark as one '
        'stretch', () async {
      await repo.storeRun(
        videoRun(scannedMs: 12000),
        insert: const [],
        deleteIds: const [],
      );
      final stored = (await repo.runFor('v1'))!;
      expect(stored.scannedRanges, isNull);
      expect(stored.scanned.stretches, [(startMs: 0, endMs: 12000)]);
    });

    test('corrupt stretches read as none, so the mark applies', () async {
      await repo.storeRun(
        videoRun().copyWith(
          scannedRanges: () => const ScannedRanges().add(0, 5000),
        ),
        insert: const [],
        deleteIds: const [],
      );
      await db.customStatement(
        "UPDATE media_identification_runs SET scanned_ranges = X'02'",
      );
      final stored = (await repo.runFor('v1'))!;
      expect(stored.scannedRanges, isNull);
      expect(stored.scanned.stretches, [(startMs: 0, endMs: 10000)]);
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
