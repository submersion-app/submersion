import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_row_restore.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
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
}
