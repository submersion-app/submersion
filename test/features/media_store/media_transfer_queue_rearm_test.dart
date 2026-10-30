import 'package:drift/drift.dart' show Value;
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

  Future<MediaTransferQueueEntry> rowOf(int id) async =>
      (await repo.allForTesting()).singleWhere((r) => r.id == id);

  Future<void> failTimes(int id, int times) async {
    for (var i = 0; i < times; i++) {
      await repo.markFailed(id, 'boom');
    }
  }

  test('a terminally failed upload goes back to pending with a fresh '
      'budget and is claimable', () async {
    final id = await repo.enqueueUpload(mediaId: 'm1');
    await failTimes(id, 5);
    expect((await rowOf(id)).state, 'failed');

    expect(await repo.rearmUploads(['m1']), 1);

    final row = await rowOf(id);
    expect(row.state, 'pending');
    expect(row.attempts, 0);
    expect(row.nextAttemptAt, isNull);
    expect(row.errorMessage, isNull);
    final claimed = await repo.claimNextPending(DateTime.now());
    expect(claimed?.id, id);
    repo.release(id);
  });

  test('a pending upload with spent attempts gets its budget back', () async {
    final id = await repo.enqueueUpload(mediaId: 'm1');
    await failTimes(id, 4);
    expect((await rowOf(id)).attempts, 4);

    expect(await repo.rearmUploads(['m1']), 1);

    final row = await rowOf(id);
    expect(row.state, 'pending');
    expect(row.attempts, 0);
    expect(row.nextAttemptAt, isNull);
    expect(row.errorMessage, isNull);
    // One more failure no longer makes it terminal.
    expect(await repo.markFailed(id, 'boom'), isFalse);
  });

  test('a fresh pending row is left as it is', () async {
    final id = await repo.enqueueUpload(mediaId: 'm1');
    final until = DateTime.now().add(const Duration(hours: 1));
    await repo.defer(id, until, reason: 'policy');
    final before = await rowOf(id);

    expect(await repo.rearmUploads(['m1']), 0);

    final after = await rowOf(id);
    expect(after.nextAttemptAt, before.nextAttemptAt);
    expect(after.errorMessage, 'policy');
    expect(after.updatedAt, before.updatedAt);
  });

  test('leaves transferring, done, delete and claimed rows, and other '
      'media, alone', () async {
    final transferring = await repo.enqueueUpload(mediaId: 'm1');
    await failTimes(transferring, 2);
    await repo.markTransferring(transferring);

    final done = await repo.enqueueUpload(mediaId: 'm2');
    await failTimes(done, 2);
    await repo.markDone(done);

    final delete = await repo.enqueueDelete(
      mediaId: 'm3',
      contentHash: 'h3',
      originalExt: 'jpg',
      renditionExt: 'jpg',
    );
    await failTimes(delete, 5);

    final other = await repo.enqueueUpload(mediaId: 'other');
    await failTimes(other, 5);

    final claimed = await repo.enqueueUpload(mediaId: 'm4');
    await failTimes(claimed, 2);
    // Make it due so the claim takes it.
    await (db.update(db.mediaTransferQueue)..where((t) => t.id.equals(claimed)))
        .write(const MediaTransferQueueCompanion(nextAttemptAt: Value(null)));
    expect((await repo.claimNextPending(DateTime.now()))?.id, claimed);

    expect(await repo.rearmUploads(['m1', 'm2', 'm3', 'm4']), 0);

    expect((await rowOf(transferring)).attempts, 2);
    expect((await rowOf(transferring)).state, 'transferring');
    expect((await rowOf(done)).state, 'done');
    expect((await rowOf(delete)).state, 'failed');
    expect((await rowOf(other)).state, 'failed');
    expect((await rowOf(claimed)).attempts, 2);
    repo.release(claimed);
  });

  test('covers every id across chunks', () async {
    final ids = <int>[];
    for (var i = 0; i < 5; i++) {
      final id = await repo.enqueueUpload(mediaId: 'm$i');
      await failTimes(id, 5);
      ids.add(id);
    }

    expect(
      await repo.rearmUploads(['m0', 'm1', 'm2', 'm3', 'm4'], chunkSize: 2),
      5,
    );

    for (final id in ids) {
      expect((await rowOf(id)).state, 'pending');
    }
  });

  test('an empty list touches nothing', () async {
    expect(await repo.rearmUploads(const []), 0);
  });
}
