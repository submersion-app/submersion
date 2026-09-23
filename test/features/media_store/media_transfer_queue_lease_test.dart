import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

/// A reclaim runs on every drain and several workers can drain one queue at
/// once (a runtime rebuild leaves the superseded worker running), so a row a
/// worker has taken must be invisible to both selection and reclaim until
/// that worker lets it go. Claims are that lease.
void main() {
  late LocalCacheDatabase db;
  late MediaTransferQueueRepository repo;

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
    repo = MediaTransferQueueRepository(database: db);
  });

  tearDown(() => db.close());

  test('reclaim returns a stranded transferring row to pending', () async {
    final id = await repo.enqueueUpload(mediaId: 'm1');
    await repo.markTransferring(id);
    // Stuck: nextPending never selects 'transferring'.
    expect(await repo.nextPending(DateTime.now()), isNull);

    expect(await repo.requeueStale(), 1);

    expect((await repo.allForTesting()).single.state, 'pending');
    expect(await repo.nextPending(DateTime.now()), isNotNull);
  });

  test('reclaim leaves a claimed row until it is released', () async {
    // A rebuilt runtime's worker reclaims on its first drain while the
    // superseded worker may still be uploading. Another repository over the
    // same database stands in for that second worker.
    await repo.enqueueUpload(mediaId: 'm1');
    final claimed = (await repo.claimNextPending(DateTime.now()))!;
    await repo.markTransferring(claimed.id);

    expect(await MediaTransferQueueRepository(database: db).requeueStale(), 0);
    expect((await repo.allForTesting()).single.state, 'transferring');

    repo.release(claimed.id);
    expect(await repo.requeueStale(), 1, reason: 'released, so stranded');
  });

  // The reclaim reads the transferring rows, then drops the claimed ones.
  // A row claimed and marked transferring while the reclaim runs must come
  // through untouched, whichever side of the read it lands on.
  test('a row claimed while a reclaim runs is left alone', () async {
    await repo.enqueueUpload(mediaId: 'm1');
    final other = MediaTransferQueueRepository(database: db);

    final reclaim = repo.requeueStale();
    final claimed = (await other.claimNextPending(DateTime.now()))!;
    await other.markTransferring(claimed.id);

    expect(await reclaim, 0);
    expect(await repo.requeueStale(), 0);
    expect((await repo.allForTesting()).single.state, 'transferring');
  });

  test('stranded and live rows together: only the stranded one is '
      'reclaimed', () async {
    final stranded = await repo.enqueueUpload(mediaId: 'dead');
    await repo.markTransferring(stranded);
    final liveId = await repo.enqueueUpload(mediaId: 'live');
    final live = (await repo.claimNextPending(DateTime.now()))!;
    expect(live.id, liveId);
    await repo.markTransferring(live.id);

    expect(await repo.requeueStale(), 1);

    final rows = {for (final r in await repo.allForTesting()) r.id: r.state};
    expect(rows[stranded], 'pending');
    expect(rows[liveId], 'transferring');
  });

  // A budget-expired transfer that never reached markTransferring leaves its
  // row pending; once its deferral passes, another drain must not select it
  // while the first transfer still runs.
  test('a claimed row is not selected until it is released', () async {
    await repo.enqueueUpload(mediaId: 'm1');
    final claimed = (await repo.claimNextPending(DateTime.now()))!;

    expect(await repo.nextPending(DateTime.now()), isNull);
    expect(await repo.claimNextPending(DateTime.now()), isNull);

    repo.release(claimed.id);
    expect((await repo.claimNextPending(DateTime.now()))?.id, claimed.id);
  });

  test('two workers claiming at once never take the same row', () async {
    await repo.enqueueUpload(mediaId: 'm1');
    final other = MediaTransferQueueRepository(database: db);

    final claims = await Future.wait([
      repo.claimNextPending(DateTime.now()),
      other.claimNextPending(DateTime.now()),
    ]);

    expect(claims.whereType<MediaTransferQueueEntry>(), hasLength(1));
  });

  test('two workers take two rows, one each', () async {
    await repo.enqueueUpload(mediaId: 'm1');
    await repo.enqueueUpload(mediaId: 'm2');
    final other = MediaTransferQueueRepository(database: db);

    final claims = await Future.wait([
      repo.claimNextPending(DateTime.now()),
      other.claimNextPending(DateTime.now()),
    ]);

    expect(claims.map((e) => e?.mediaId).toSet(), {'m1', 'm2'});
  });

  test('a claim on one database does not cover another', () async {
    final other = LocalCacheDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    final otherRepo = MediaTransferQueueRepository(database: other);
    await repo.enqueueUpload(mediaId: 'm1');
    final id = await otherRepo.enqueueUpload(mediaId: 'm1');
    expect((await repo.claimNextPending(DateTime.now()))?.id, id);
    await otherRepo.markTransferring(id);

    expect(await otherRepo.requeueStale(), 1);
  });
}
