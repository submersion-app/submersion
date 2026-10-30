// Issue #3482 phase 5: once a replace and join commits, every queued
// transfer names the replaced library's media, so the whole queue goes.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

void main() {
  late LocalCacheDatabase db;
  late MediaTransferQueueRepository repo;

  setUp(() {
    db = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    repo = MediaTransferQueueRepository(database: db);
  });

  tearDown(() => db.close());

  test('clears rows in every state and direction', () async {
    await repo.enqueueUpload(mediaId: 'pending');
    final transferring = await repo.enqueueUpload(mediaId: 'moving');
    await repo.markTransferring(transferring);
    final failed = await repo.enqueueUpload(mediaId: 'failed');
    for (var i = 0; i < 5; i++) {
      await repo.markFailed(failed, 'boom');
    }
    final done = await repo.enqueueDelete(
      mediaId: 'gone',
      contentHash: 'h1',
      originalExt: 'jpg',
      renditionExt: 'jpg',
    );
    await repo.markDone(done);

    expect(await repo.clearAll(), 4);
    expect(await repo.allForTesting(), isEmpty);
  });

  test('an empty queue clears nothing', () async {
    expect(await repo.clearAll(), 0);
  });

  // Copilot review: a transfer the worker handed off keeps running after its
  // drain moved on, so a replace waits for every claim to settle first.
  test('claims are waited out, and a claim that stays reports false', () async {
    await repo.enqueueUpload(mediaId: 'moving');
    final claimed = (await repo.claimNextPending(DateTime.now()))!;

    expect(
      await repo.waitForClaimsToSettle(const Duration(milliseconds: 50)),
      isFalse,
    );

    repo.releaseSettled(claimed.id);
    expect(
      await repo.waitForClaimsToSettle(const Duration(milliseconds: 50)),
      isTrue,
    );
  });

  test('every row id is listed, for a worker-safe drop', () async {
    final a = await repo.enqueueUpload(mediaId: 'a');
    final b = await repo.enqueueUpload(mediaId: 'b');

    expect((await repo.allIds()).toSet(), {a, b});
  });
}
