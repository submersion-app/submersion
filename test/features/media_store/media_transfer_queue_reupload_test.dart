import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

void main() {
  late LocalCacheDatabase db;
  late MediaTransferQueueRepository queue;

  setUp(() {
    db = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    queue = MediaTransferQueueRepository(database: db);
  });
  tearDown(() => db.close());

  test(
    'enqueueReupload replaces prior rows and carries overrideLevel',
    () async {
      await queue.enqueueUpload(mediaId: 'm1');
      final id = await queue.enqueueReupload(
        mediaId: 'm1',
        overrideLevel: 'small',
      );
      final rows = await queue.allForTesting();
      expect(rows.where((r) => r.mediaId == 'm1').length, 1);
      expect(rows.single.id, id);
      expect(rows.single.overrideLevel, 'small');
      expect(rows.single.state, 'pending');
    },
  );

  test('a re-upload never abandons a session a drain has claimed', () async {
    // A claim is held in memory while the row still reads pending; the
    // drain is about to resume that session, so abandoning it would abort
    // the upload under way.
    final id = await queue.enqueueUpload(mediaId: 'm1');
    await queue.updateResumeState(id, '{"session":"s1"}');
    expect((await queue.claimNextPending(DateTime.now()))!.id, id);

    final dropped = await queue.reenqueueForReupload(
      mediaId: 'm1',
      overrideLevel: 'small',
    );

    expect(dropped, isEmpty);
  });

  test('a re-upload abandons the session of a row nobody holds', () async {
    final id = await queue.enqueueUpload(mediaId: 'm1');
    await queue.updateResumeState(id, '{"session":"s1"}');

    final dropped = await queue.reenqueueForReupload(
      mediaId: 'm1',
      overrideLevel: 'small',
    );

    expect(dropped.map((d) => d.resumeStateJson), ['{"session":"s1"}']);
  });

  test('a Transfers delete never abandons a claimed session', () async {
    final id = await queue.enqueueUpload(mediaId: 'm1');
    await queue.updateResumeState(id, '{"session":"s1"}');
    await queue.claimNextPending(DateTime.now());

    expect(await queue.deleteDroppingSession(id), isNull);
  });

  test('a plain enqueueUpload carries no overrideLevel', () async {
    await queue.enqueueUpload(mediaId: 'm2');
    final rows = await queue.allForTesting();
    expect(rows.single.overrideLevel, isNull);
  });

  test('hasTransferringUploads sees only an upload in flight', () async {
    expect(await queue.hasTransferringUploads(), isFalse);
    final id = await queue.enqueueUpload(mediaId: 'm1');
    expect(await queue.hasTransferringUploads(), isFalse, reason: 'pending');
    await queue.markTransferring(id);
    expect(await queue.hasTransferringUploads(), isTrue);
  });
}
