import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_row_restore.dart';
import 'package:submersion/features/species_id/data/repositories/identification_crop_repository.dart';
import 'package:submersion/features/species_id/data/repositories/identification_embedding_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_cleanup.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';

import '../../../helpers/test_database.dart';
import 'identification_fixtures.dart';

/// Every write of marine life results reaches sync (issue #4876): rows are
/// marked pending with their clock stamped, the diver's decisions under
/// their own clock only, and deletions are tombstoned.
void main() {
  late AppDatabase db;
  late MediaIdentificationRepository repo;
  final sync = SyncRepository();

  setUp(() async {
    db = await setUpTestDatabase();
    // The app's own logbook: the default marks publish.
    repo = MediaIdentificationRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<Set<String>> pending(String entityType) async => {
    for (final r in await sync.getPendingRecords())
      if (r.entityType == entityType) r.recordId,
  };

  Future<Set<String>> tombstones(String entityType) async => {
    for (final d in await sync.getAllDeletions())
      if (d.entityType == entityType) d.recordId,
  };

  Future<Map<String, Object?>> clocks(String id) async =>
      (await db
              .customSelect(
                'SELECT hlc, decision_hlc FROM media_identifications WHERE id = ?',
                variables: [Variable.withString(id)],
              )
              .getSingle())
          .data;

  test('storing a run publishes the run and its rows; a row carrying a '
      'decision gets the decision clock too', () async {
    await repo.storeRun(
      run(),
      insert: [
        identification('a'),
        identification('b', decision: IdentificationDecision.accepted),
      ],
      deleteIds: const [],
    );
    expect(await pending('mediaIdentificationRuns'), {'m1'});
    expect(await pending('mediaIdentifications'), {'a', 'b'});
    expect((await clocks('a'))['hlc'], isNotNull);
    expect((await clocks('a'))['decision_hlc'], isNull);
    expect((await clocks('b'))['decision_hlc'], isNotNull);
  });

  test('a row stored again with its decision unchanged keeps its decision '
      'clock; a changed or cleared decision moves it', () async {
    final accepted = identification(
      'a',
      decision: IdentificationDecision.accepted,
    );
    final kept = identification('k', decision: IdentificationDecision.accepted);
    final cleared = identification(
      'c',
    ).copyWith(claimedSpeciesId: () => 'sp-claimed');
    await repo.storeRun(
      run(),
      insert: [accepted, kept, cleared],
      deleteIds: const [],
    );
    final before = {
      for (final id in ['a', 'k', 'c']) id: (await clocks(id))['decision_hlc'],
    };

    // A video chunk writes the tracks it continues again, decisions as
    // stored: only what the diver actually changed may win on a peer.
    await repo.storeRun(
      run(),
      insert: [
        accepted.copyWith(decision: IdentificationDecision.rejected),
        kept.copyWith(openScore: 0.5),
        cleared.copyWith(claimedSpeciesId: () => null),
      ],
      deleteIds: const [],
    );

    expect((await clocks('k'))['decision_hlc'], before['k']);
    expect((await clocks('a'))['decision_hlc'], isNot(before['a']));
    expect((await clocks('c'))['decision_hlc'], isNot(before['c']));
  });

  test('rows a re-analysis deletes are tombstoned', () async {
    await repo.storeRun(
      run(),
      insert: [identification('a')],
      deleteIds: const [],
    );
    await repo.storeRun(
      run(),
      insert: [identification('c')],
      deleteIds: const ['a'],
    );
    expect(await tombstones('mediaIdentifications'), {'a'});
  });

  test('a decision or a claim moves only the decision clock', () async {
    await repo.storeRun(
      run(),
      insert: [identification('a')],
      deleteIds: const [],
    );
    final before = await clocks('a');
    await sync.clearPendingRecords();

    await repo.updateDecisions([
      identification('a', decision: IdentificationDecision.rejected),
    ]);
    final decided = await clocks('a');
    expect(decided['hlc'], before['hlc']);
    expect(decided['decision_hlc'], isNotNull);
    expect(await pending('mediaIdentifications'), {'a'});

    await repo.claim('a', 'sp1');
    final claimed = await clocks('a');
    expect(claimed['hlc'], before['hlc']);
    expect(
      (claimed['decision_hlc']! as String).compareTo(
        decided['decision_hlc']! as String,
      ),
      greaterThan(0),
    );
  });

  test('a decision on a row since removed publishes nothing', () async {
    await repo.updateDecisions([
      identification('gone', decision: IdentificationDecision.accepted),
    ]);
    await repo.claim('gone', 'sp1');
    expect(await pending('mediaIdentifications'), isEmpty);
  });

  test(
    'a rename moves the row clock and the run, not the decision clock',
    () async {
      await repo.storeRun(
        run(),
        insert: [
          identification('a', decision: IdentificationDecision.accepted),
        ],
        deleteIds: const [],
      );
      final before = await clocks('a');
      await sync.clearPendingRecords();
      await repo.updateNames([
        identification('a').copyWith(openScore: 0.9),
      ], run: run().copyWith(packVersion: '2026.12.1'));
      final after = await clocks('a');
      expect(after['hlc'], isNot(before['hlc']));
      expect(after['decision_hlc'], before['decision_hlc']);
      expect(await pending('mediaIdentificationRuns'), {'m1'});
    },
  );

  test(
    'a leftover of a run that lost a sync race is deleted with a '
    'tombstone; one the diver has said something on meanwhile stays',
    () async {
      await repo.storeRun(
        run().copyWith(runId: () => 'mine'),
        insert: [
          identification('left').copyWith(runId: () => 'theirs'),
          identification(
            'decided',
            decision: IdentificationDecision.rejected,
          ).copyWith(runId: () => 'theirs'),
          identification('own'),
        ],
        deleteIds: const [],
      );

      expect(
        await repo.deleteLeftovers('m1', 'mine', ['left', 'decided', 'own']),
        ['left'],
      );
      expect([for (final i in await repo.forMedia('m1')) i.id]..sort(), [
        'decided',
        'own',
      ]);
      expect(await tombstones('mediaIdentifications'), {'left'});
    },
  );

  test('leftovers are judged against a run: once another run is stored, '
      'nothing goes, since its own rows are no leftovers', () async {
    // The run was read as 'mine'; a sync stored the laptop's run and rows
    // before the rows were read.
    await repo.storeRun(
      run().copyWith(runId: () => 'laptop'),
      insert: [identification('fresh')],
      deleteIds: const [],
    );

    expect(await repo.deleteLeftovers('m1', 'mine', ['fresh']), isEmpty);
    expect([for (final i in await repo.forMedia('m1')) i.id], ['fresh']);
    expect(await tombstones('mediaIdentifications'), isEmpty);
  });

  test('deleting the results of media tombstones runs and rows', () async {
    await repo.storeRun(
      run(),
      insert: [identification('a')],
      deleteIds: const [],
    );
    await repo.deleteForMedia(['m1']);
    expect(await tombstones('mediaIdentificationRuns'), {'m1'});
    expect(await tombstones('mediaIdentifications'), {'a'});
  });

  test('an undone media delete publishes its results again', () async {
    await db.customStatement(
      'INSERT INTO media (id, file_path, file_type, created_at, updated_at) '
      "VALUES ('m1', 'a', 'photo', 1, 1)",
    );
    await repo.storeRun(
      run(),
      insert: [identification('a')],
      deleteIds: const [],
    );
    final snapshot = await readMediaRows(db, ['m1']);
    await MediaRepository().deleteMultipleMedia(['m1']);
    await sync.clearPendingRecords();

    await restoreMediaRows(db, sync, snapshot, now: 10);

    expect(await pending('mediaIdentificationRuns'), {'m1'});
    expect(await pending('mediaIdentifications'), {'a'});
  });

  test(
    'the launch sweep removes the results of deleted media here only, '
    'with no tombstones: an undo elsewhere must still bring them back',
    () async {
      final support = await Directory.systemTemp.createTemp('sweep');
      addTearDown(() => support.delete(recursive: true));
      final local = LocalCacheDatabase(NativeDatabase.memory());
      addTearDown(local.close);
      final crops = IdentificationCropStore(
        supportPath: () async => support.path,
        table: IdentificationCropRepository(),
      );
      addTearDown(crops.dispose);
      await repo.storeRun(
        run().copyWith(analysedBy: () => 'laptop'),
        insert: [
          identification('a', decision: IdentificationDecision.accepted),
        ],
        deleteIds: const [],
      );
      await crops.write('m1', 'a', Uint8List.fromList([1, 2]), named: true);
      // The laptop's delete reached this phone while it could still be undone.
      await sync.logDeletions(entityType: 'media', recordIds: ['m1']);

      final swept = await IdentificationCleanup(
        identifications: repo,
        embeddings: IdentificationEmbeddingRepository(database: local),
        crops: crops,
        deviceId: () async => 'phone',
      ).sweepOrphans();

      expect(swept, 1);
      expect(await repo.runFor('m1'), isNull);
      expect(await crops.read('m1', 'a'), isNull);
      expect(await tombstones('mediaIdentificationRuns'), isEmpty);
      expect(await tombstones('mediaIdentifications'), isEmpty);
      expect(await tombstones('mediaIdentificationCrops'), isEmpty);
    },
  );

  test('the launch sweep also removes a synced crop of deleted media that '
      'has no run or rows here', () async {
    final support = await Directory.systemTemp.createTemp('sweep_crop');
    addTearDown(() => support.delete(recursive: true));
    final local = LocalCacheDatabase(NativeDatabase.memory());
    addTearDown(local.close);
    final table = IdentificationCropRepository();
    final crops = IdentificationCropStore(
      supportPath: () async => support.path,
      table: table,
    );
    addTearDown(crops.dispose);
    // Only the crop arrived, or its rows went another way.
    await table.put('a', 'm1', Uint8List.fromList([1, 2]));
    await sync.logDeletions(entityType: 'media', recordIds: ['m1']);

    final swept = await IdentificationCleanup(
      identifications: repo,
      embeddings: IdentificationEmbeddingRepository(database: local),
      crops: crops,
      deviceId: () async => 'phone',
    ).sweepOrphans();

    expect(swept, 1);
    expect(await table.bytesFor('a'), isNull);
  });

  test('clearing every identification clears them on every device: runs, '
      'rows and crops are tombstoned', () async {
    final support = await Directory.systemTemp.createTemp('clear_all');
    addTearDown(() => support.delete(recursive: true));
    final local = LocalCacheDatabase(NativeDatabase.memory());
    addTearDown(local.close);
    final crops = IdentificationCropStore(
      supportPath: () async => support.path,
      table: IdentificationCropRepository(),
    );
    addTearDown(crops.dispose);
    await repo.storeRun(
      run(),
      insert: [identification('a')],
      deleteIds: const [],
    );
    await crops.write('m1', 'a', Uint8List.fromList([1, 2]), named: true);

    await IdentificationCleanup(
      identifications: repo,
      embeddings: IdentificationEmbeddingRepository(database: local),
      crops: crops,
    ).clearAll();

    expect(await tombstones('mediaIdentificationRuns'), {'m1'});
    expect(await tombstones('mediaIdentifications'), {'a'});
    expect(await tombstones('mediaIdentificationCrops'), {'a'});
  });
}
