import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/sync/hlc.dart';

import '../../../helpers/test_database.dart';

/// `logDeletions` tombstones many records of one entity type in a single
/// transaction, for deletes that remove rows in bulk (a diver's whole
/// library). Each tombstone has to look exactly like one `logDeletion`
/// writes: its own clock, so the changeset writer's `hlc >` filter publishes
/// every one, and one row per (entityType, recordId).
void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() => tearDownTestDatabase());

  test('writes one tombstone per record, each with its own clock', () async {
    final repo = SyncRepository();

    await repo.logDeletions(entityType: 'dives', recordIds: ['d1', 'd2', 'd3']);

    final all = await repo.getAllDeletions();
    expect(all.map((d) => d.recordId).toSet(), {'d1', 'd2', 'd3'});
    expect(all.every((d) => d.entityType == 'dives'), isTrue);
    final clocks = [for (final d in all) d.hlc];
    expect(clocks, everyElement(isNotNull));
    expect(
      clocks.toSet(),
      hasLength(3),
      reason: 'each delete is its own event',
    );
    for (final d in all) {
      expect(d.originHlc, d.hlc, reason: 'a local delete is its own origin');
    }
  });

  test('replaces an earlier tombstone for the same record', () async {
    final repo = SyncRepository();
    await repo.logDeletion(entityType: 'dives', recordId: 'd1', deletedAt: 1);
    final earlier = (await repo.getAllDeletions()).single;

    await repo.logDeletions(entityType: 'dives', recordIds: ['d1']);

    final all = await repo.getAllDeletions();
    expect(all, hasLength(1));
    expect(all.single.deletedAt, greaterThan(1));
    expect(
      Hlc.parse(all.single.hlc!).compareTo(Hlc.parse(earlier.hlc!)),
      greaterThan(0),
      reason: 'a re-delete must advance the clock or it is never republished',
    );
  });

  test('leaves the same id of another entity type alone', () async {
    final repo = SyncRepository();
    await repo.logDeletion(entityType: 'tags', recordId: 'x', deletedAt: 1);

    await repo.logDeletions(entityType: 'dives', recordIds: ['x']);

    final all = await repo.getAllDeletions();
    expect(all.map((d) => (d.entityType, d.recordId)).toSet(), {
      ('tags', 'x'),
      ('dives', 'x'),
    });
    expect(all.singleWhere((d) => d.entityType == 'tags').deletedAt, 1);
  });

  test('collapses a record listed twice into one tombstone', () async {
    final repo = SyncRepository();

    await repo.logDeletions(entityType: 'dives', recordIds: ['d1', 'd1']);

    expect(await repo.getAllDeletions(), hasLength(1));
  });

  test('logs more records than SQLite binds in one statement', () async {
    // The bundled SQLite binds at most 32766 variables per statement, so a
    // library this size fails any single `IN (...)` over every id.
    final repo = SyncRepository();
    final ids = [for (var i = 0; i < 33000; i++) 'd$i'];

    await repo.logDeletions(entityType: 'dives', recordIds: ids);

    expect(await repo.getAllDeletions(), hasLength(ids.length));
  });

  test('does nothing for no records', () async {
    final repo = SyncRepository();

    await repo.logDeletions(entityType: 'dives', recordIds: const []);

    expect(await repo.getAllDeletions(), isEmpty);
  });
}
