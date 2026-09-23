import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

/// A reclaim runs on every drain, so it must never flip a row a live
/// transfer in this process still owns. Leases name those rows.
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

  test('reclaim leaves a row a worker still holds', () async {
    // A rebuilt runtime's worker reclaims on its first drain while the
    // superseded worker may still be uploading. Another repository over the
    // same database stands in for that second worker.
    final id = await repo.enqueueUpload(mediaId: 'm1');
    final release = Completer<void>();
    final held = repo.holdWhile(id, () async {
      await repo.markTransferring(id);
      await release.future;
    });
    await pumpEventQueue();

    expect(await MediaTransferQueueRepository(database: db).requeueStale(), 0);
    expect((await repo.allForTesting()).single.state, 'transferring');

    release.complete();
    await held;
    expect(await repo.requeueStale(), 1, reason: 'released once it settles');
  });

  test('a lease on one database does not cover another', () async {
    final other = LocalCacheDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    final otherRepo = MediaTransferQueueRepository(database: other);
    final id = await otherRepo.enqueueUpload(mediaId: 'm1');
    await otherRepo.markTransferring(id);
    final release = Completer<void>();
    final held = repo.holdWhile(id, () => release.future);

    expect(await otherRepo.requeueStale(), 1);

    release.complete();
    await held;
  });

  test('two holders of one id keep it held until both settle', () async {
    final id = await repo.enqueueUpload(mediaId: 'm1');
    await repo.markTransferring(id);
    final first = Completer<void>();
    final second = Completer<void>();
    final a = repo.holdWhile(id, () => first.future);
    final b = repo.holdWhile(id, () => second.future);

    first.complete();
    await a;
    expect(await repo.requeueStale(), 0);

    second.complete();
    await b;
    expect(await repo.requeueStale(), 1);
  });

  test('a lease is released when the work throws', () async {
    final id = await repo.enqueueUpload(mediaId: 'm1');
    await repo.markTransferring(id);

    await expectLater(
      repo.holdWhile(id, () async => throw StateError('upload failed')),
      throwsStateError,
    );

    expect(await repo.requeueStale(), 1);
  });
}
