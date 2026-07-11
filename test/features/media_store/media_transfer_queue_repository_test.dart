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

  test('re-enqueue after terminal failure returns the existing row and '
      'preserves its attempt count', () async {
    final id = await repo.enqueueUpload(mediaId: 'm1');
    for (var i = 0; i < 5; i++) {
      await repo.markFailed(id, 'boom');
    }
    expect((await repo.allForTesting()).single.state, 'failed');

    // Backfill or a re-import must not resurrect a terminally failed row
    // with a fresh attempt budget; that is what explicit retry() is for.
    final again = await repo.enqueueUpload(mediaId: 'm1');
    expect(again, id);
    final rows = await repo.allForTesting();
    expect(rows, hasLength(1));
    expect(rows.single.attempts, 5);
    expect(rows.single.state, 'failed');
  });

  test('markDone clears a stale error message from an earlier '
      'failure', () async {
    final id = await repo.enqueueUpload(mediaId: 'm1');
    await repo.markFailed(id, 'boom');
    await repo.markDone(id);
    final row = (await repo.allForTesting()).single;
    expect(row.state, 'done');
    expect(row.errorMessage, isNull);
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

  test('watchEntries orders transferring, pending, failed, done', () async {
    final a = await repo.enqueueUpload(mediaId: 'a');
    final b = await repo.enqueueUpload(mediaId: 'b');
    final c = await repo.enqueueUpload(mediaId: 'c');
    final d = await repo.enqueueUpload(mediaId: 'd');
    await repo.markTransferring(b);
    await repo.markDone(c);
    for (var i = 0; i < 5; i++) {
      await repo.markFailed(d, 'x');
    }

    final entries = await repo.watchEntries().first;
    expect(entries.map((e) => e.id).toList(), [b, a, d, c]);
  });

  test('watchLatestForMedia emits the newest row and null when '
      'absent', () async {
    expect(await repo.watchLatestForMedia('m9').first, isNull);
    final id = await repo.enqueueUpload(mediaId: 'm9');
    final row = await repo.watchLatestForMedia('m9').first;
    expect(row!.id, id);
  });

  test('retry resets a terminally failed entry', () async {
    final id = await repo.enqueueUpload(mediaId: 'm1');
    for (var i = 0; i < 5; i++) {
      await repo.markFailed(id, 'boom');
    }
    expect((await repo.allForTesting()).single.state, 'failed');

    await repo.retry(id);
    final row = (await repo.allForTesting()).single;
    expect(row.state, 'pending');
    expect(row.attempts, 0);
    expect(row.nextAttemptAt, isNull);
    expect(row.errorMessage, isNull);
    expect(await repo.nextPending(DateTime.now()), isNotNull);
  });

  test('defer postpones without consuming an attempt', () async {
    final id = await repo.enqueueUpload(mediaId: 'm1');
    final until = DateTime.now().add(const Duration(minutes: 10));
    await repo.defer(id, until);
    expect(await repo.nextPending(DateTime.now()), isNull);
    final row = (await repo.allForTesting()).single;
    expect(row.attempts, 0);
    expect(row.state, 'pending');
    expect(
      await repo.nextPending(until.add(const Duration(seconds: 1))),
      isNotNull,
    );
  });

  test('deleteDone removes only completed rows and watchActiveCount tracks '
      'pending plus transferring', () async {
    final a = await repo.enqueueUpload(mediaId: 'a');
    final b = await repo.enqueueUpload(mediaId: 'b');
    await repo.markDone(a);
    await repo.markTransferring(b);
    expect(await repo.watchActiveCount().first, 1);
    expect(await repo.deleteDone(), 1);
    expect((await repo.allForTesting()).length, 1);
  });

  test('v3 migration adds progress columns to an existing v2 '
      'database', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 2');
        rawDb.execute('''
          CREATE TABLE local_asset_cache (
            media_id TEXT NOT NULL PRIMARY KEY,
            local_asset_id TEXT,
            resolved_at INTEGER NOT NULL,
            resolution_method TEXT NOT NULL,
            attempt_count INTEGER NOT NULL DEFAULT 0
          )
        ''');
        rawDb.execute('''
          CREATE TABLE media_transfer_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            media_id TEXT NOT NULL,
            direction TEXT NOT NULL DEFAULT 'upload',
            object_kind TEXT NOT NULL DEFAULT 'original',
            content_hash TEXT,
            state TEXT NOT NULL DEFAULT 'pending',
            attempts INTEGER NOT NULL DEFAULT 0,
            next_attempt_at INTEGER,
            resume_state_json TEXT,
            error_message TEXT,
            priority INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        rawDb.execute('''
          CREATE TABLE media_cache_entries (
            content_hash TEXT NOT NULL,
            kind TEXT NOT NULL,
            relative_path TEXT NOT NULL,
            size_bytes INTEGER NOT NULL,
            last_accessed_at INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            PRIMARY KEY (content_hash, kind)
          )
        ''');
        rawDb.execute(
          "INSERT INTO media_transfer_queue "
          "(media_id, created_at, updated_at) VALUES ('m1', 1, 1)",
        );
      },
    );
    final upgraded = LocalCacheDatabase(nativeDb);
    addTearDown(upgraded.close);

    final cols = await upgraded
        .customSelect("PRAGMA table_info('media_transfer_queue')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, containsAll(['progress_bytes', 'total_bytes']));
    final kept = await upgraded
        .customSelect("SELECT media_id FROM media_transfer_queue")
        .getSingle();
    expect(kept.data['media_id'], 'm1');
  });

  test('resume state persists through markFailed and retry, and clears on '
      'markDone', () async {
    final id = await repo.enqueueUpload(mediaId: 'm1');
    await repo.updateResumeState(id, '{"uploadId":"u1"}');
    await repo.updateProgress(id, transferredBytes: 16, totalBytes: 64);

    await repo.markFailed(id, 'network blip');
    var row = (await repo.allForTesting()).single;
    expect(row.resumeStateJson, '{"uploadId":"u1"}');
    expect(row.progressBytes, 16);

    for (var i = 0; i < 4; i++) {
      await repo.markFailed(id, 'boom');
    }
    await repo.retry(id);
    row = (await repo.allForTesting()).single;
    expect(
      row.resumeStateJson,
      '{"uploadId":"u1"}',
      reason: 'retry must keep the resume point',
    );

    await repo.markDone(id);
    row = (await repo.allForTesting()).single;
    expect(row.resumeStateJson, isNull);
    expect(row.progressBytes, isNull);
    expect(row.totalBytes, isNull);
  });
}
