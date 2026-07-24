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

  test('markFailed honours an explicit retryAfter instead of the default '
      'minute-scale backoff', () async {
    final id = await repo.enqueueUpload(mediaId: 'm1');
    final t0 = DateTime.now();
    await repo.markFailed(
      id,
      'source unavailable on this device',
      retryAfter: const Duration(hours: 25),
    );

    // The default ladder would have made this due within minutes, which would
    // burn an attempt against a resolution lockout that is still in force.
    expect(await repo.nextPending(t0.add(const Duration(hours: 2))), isNull);

    final due = await repo.nextPending(t0.add(const Duration(hours: 26)));
    expect(due, isNotNull);
    expect(due!.attempts, 1);
  });

  test('retryAfter still counts toward the terminal attempt cap', () async {
    final id = await repo.enqueueUpload(mediaId: 'm1');
    for (var i = 0; i < 5; i++) {
      await repo.markFailed(
        id,
        'source unavailable on this device',
        retryAfter: const Duration(hours: 25),
      );
    }
    final row = (await repo.allForTesting()).single;
    expect(row.state, 'failed');
    expect(row.attempts, 5);
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

  test('requeueStale returns an orphaned transferring row to pending so the '
      'drainer can see it again', () async {
    // An interrupted drain (app killed/backgrounded after markTransferring
    // but before markDone/markFailed) strands a row in 'transferring'. Here
    // it had already failed once (attempt consumed, error + backoff set) and
    // was mid-retry when it stranded, so it carries a stale error message.
    final id = await repo.enqueueUpload(mediaId: 'm1');
    await repo.updateResumeState(id, '{"uploadId":"u1"}');
    await repo.markFailed(id, 'network blip');
    await repo.updateProgress(id, transferredBytes: 60, totalBytes: 64);
    await repo.markTransferring(id);
    // Proof of the bug: nextPending never selects 'transferring'.
    expect(await repo.nextPending(DateTime.now()), isNull);

    final reclaimed = await repo.requeueStale();
    expect(reclaimed, 1);

    final row = (await repo.allForTesting()).single;
    expect(row.state, 'pending');
    expect(row.attempts, 1, reason: 'reclaim preserves the attempt budget');
    expect(
      row.errorMessage,
      isNull,
      reason: 'a reclaimed row was interrupted, not failed - no stale error',
    );
    expect(row.nextAttemptAt, isNull, reason: 'reclaimed rows are due now');
    expect(row.progressBytes, isNull, reason: 'stale progress is cleared');
    expect(row.totalBytes, isNull);
    expect(
      row.resumeStateJson,
      '{"uploadId":"u1"}',
      reason: 'a resumable adapter must keep its resume point',
    );
    expect(await repo.nextPending(DateTime.now()), isNotNull);
  });

  test(
    'requeueStale leaves pending, done, and failed rows untouched',
    () async {
      final pending = await repo.enqueueUpload(mediaId: 'p');
      final done = await repo.enqueueUpload(mediaId: 'd');
      await repo.markDone(done);
      final failed = await repo.enqueueUpload(mediaId: 'f');
      for (var i = 0; i < 5; i++) {
        await repo.markFailed(failed, 'boom');
      }

      expect(await repo.requeueStale(), 0);

      final byId = {for (final r in await repo.allForTesting()) r.id: r};
      expect(byId[pending]!.state, 'pending');
      expect(byId[done]!.state, 'done');
      expect(byId[failed]!.state, 'failed');
      expect(byId[failed]!.attempts, 5);
    },
  );

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

  test('markFailed reports terminality', () async {
    final id = await repo.enqueueUpload(mediaId: 'm1');
    for (var i = 0; i < 4; i++) {
      expect(await repo.markFailed(id, 'e'), isFalse);
    }
    expect(await repo.markFailed(id, 'e'), isTrue);
    expect((await repo.allForTesting()).single.state, 'failed');
  });

  test('enqueueRepairUpload re-arms a terminally failed row', () async {
    final id = await repo.enqueueUpload(mediaId: 'm1');
    for (var i = 0; i < 5; i++) {
      await repo.markFailed(id, 'boom');
    }
    expect((await repo.allForTesting()).single.state, 'failed');

    final again = await repo.enqueueRepairUpload(mediaId: 'm1');
    expect(again, id);
    final row = (await repo.allForTesting()).single;
    expect(row.state, 'pending');
    expect(row.attempts, 0);
    expect(await repo.nextPending(DateTime.now()), isNotNull);

    // Live rows are reused untouched, and absent rows insert fresh.
    expect(await repo.enqueueRepairUpload(mediaId: 'm1'), id);
    final fresh = await repo.enqueueRepairUpload(mediaId: 'm2');
    expect(fresh, isNot(id));
  });

  group('enqueueDelete', () {
    test('inserts a delete row with hash and payload', () async {
      final id = await repo.enqueueDelete(
        mediaId: 'm1',
        contentHash: 'aabb',
        originalExt: 'jpg',
        renditionExt: 'jpg',
      );
      final row = (await repo.allForTesting()).single;
      expect(row.id, id);
      expect(row.direction, 'delete');
      expect(row.contentHash, 'aabb');
      expect(row.state, 'pending');
      expect(row.payloadJson, '{"originalExt":"jpg","renditionExt":"jpg"}');
    });

    test('is idempotent per content hash for live and failed rows', () async {
      final first = await repo.enqueueDelete(
        mediaId: 'm1',
        contentHash: 'aabb',
        originalExt: 'jpg',
        renditionExt: 'jpg',
      );
      final again = await repo.enqueueDelete(
        mediaId: 'm2', // different row, same blob
        contentHash: 'aabb',
        originalExt: 'jpg',
        renditionExt: 'jpg',
      );
      expect(again, first);
      expect((await repo.allForTesting()).length, 1);
    });

    test('a done delete row allows a fresh enqueue', () async {
      final first = await repo.enqueueDelete(
        mediaId: 'm1',
        contentHash: 'aabb',
        originalExt: 'jpg',
        renditionExt: 'jpg',
      );
      await repo.markDone(first);
      final second = await repo.enqueueDelete(
        mediaId: 'm1',
        contentHash: 'aabb',
        originalExt: 'jpg',
        renditionExt: 'jpg',
      );
      expect(second, isNot(first));
    });

    test('upload dedup ignores delete rows for the same mediaId', () async {
      await repo.enqueueDelete(
        mediaId: 'm1',
        contentHash: 'aabb',
        originalExt: 'jpg',
        renditionExt: 'jpg',
      );
      final uploadId = await repo.enqueueUpload(mediaId: 'm1');
      final rows = await repo.allForTesting();
      expect(rows.length, 2);
      expect(rows.firstWhere((r) => r.id == uploadId).direction, 'upload');
    });

    test('watchLatestForMedia ignores delete rows', () async {
      await repo.enqueueDelete(
        mediaId: 'm1',
        contentHash: 'aabb',
        originalExt: 'jpg',
        renditionExt: 'jpg',
      );
      expect(await repo.watchLatestForMedia('m1').first, isNull);
    });
  });

  test('v6 migration adds payload_json to an existing v5 database', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 5');
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
            progress_bytes INTEGER,
            total_bytes INTEGER,
            override_level TEXT,
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
            source_version INTEGER,
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
    expect(names, contains('payload_json'));
    final kept = await upgraded
        .customSelect("SELECT media_id, payload_json FROM media_transfer_queue")
        .getSingle();
    expect(kept.data['media_id'], 'm1');
    expect(kept.data['payload_json'], isNull);
  });
}
