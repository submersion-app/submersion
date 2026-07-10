import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

void main() {
  late LocalCacheDatabase db;
  late MediaTransferQueueRepository repo;

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
    repo = MediaTransferQueueRepository(database: db);
  });

  tearDown(() => db.close());

  test('enqueue then nextPending returns the entry once', () async {
    final id = await repo.enqueueUpload(mediaId: 'm1');
    final entry = await repo.nextPending(DateTime.now());
    expect(entry, isNotNull);
    expect(entry!.id, id);
    expect(entry.mediaId, 'm1');
    expect(entry.state, 'pending');

    await repo.markTransferring(id);
    expect(await repo.nextPending(DateTime.now()), isNull);
  });

  test('enqueue is idempotent per mediaId while not done', () async {
    final a = await repo.enqueueUpload(mediaId: 'm1');
    final b = await repo.enqueueUpload(mediaId: 'm1');
    expect(a, b);
    await repo.markDone(a);
    final c = await repo.enqueueUpload(mediaId: 'm1');
    expect(c, isNot(a));
  });

  test('markFailed applies backoff and terminal state after 5 '
      'attempts', () async {
    final id = await repo.enqueueUpload(mediaId: 'm1');
    final t0 = DateTime.now();
    await repo.markFailed(id, 'boom');
    // Not yet due.
    expect(await repo.nextPending(t0), isNull);
    // Due after the first backoff window (1 minute).
    final due = await repo.nextPending(t0.add(const Duration(minutes: 2)));
    expect(due, isNotNull);
    expect(due!.attempts, 1);
    expect(due.errorMessage, 'boom');

    for (var i = 0; i < 4; i++) {
      await repo.markFailed(id, 'boom $i');
    }
    final rows = await repo.allForTesting();
    expect(rows.single.state, 'failed');
    expect(await repo.nextPending(t0.add(const Duration(days: 1))), isNull);
  });

  test('v2 migration creates both tables', () async {
    final cols = await db
        .customSelect("PRAGMA table_info('media_transfer_queue')")
        .get();
    expect(cols, isNotEmpty);
    final cacheCols = await db
        .customSelect("PRAGMA table_info('media_cache_entries')")
        .get();
    expect(cacheCols, isNotEmpty);
  });

  test('real v1 to v2 upgrade preserves local_asset_cache rows', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 1');
        rawDb.execute('''
          CREATE TABLE local_asset_cache (
            media_id TEXT NOT NULL PRIMARY KEY,
            local_asset_id TEXT,
            resolved_at INTEGER NOT NULL,
            resolution_method TEXT NOT NULL,
            attempt_count INTEGER NOT NULL DEFAULT 0
          )
        ''');
        rawDb.execute(
          "INSERT INTO local_asset_cache "
          "(media_id, resolved_at, resolution_method) VALUES ('m1', 1, 'x')",
        );
      },
    );
    final upgraded = LocalCacheDatabase(nativeDb);
    addTearDown(upgraded.close);

    final queueCols = await upgraded
        .customSelect("PRAGMA table_info('media_transfer_queue')")
        .get();
    expect(queueCols, isNotEmpty);
    final kept = await upgraded
        .customSelect("SELECT media_id FROM local_asset_cache")
        .getSingle();
    expect(kept.data['media_id'], 'm1');
  });
}
