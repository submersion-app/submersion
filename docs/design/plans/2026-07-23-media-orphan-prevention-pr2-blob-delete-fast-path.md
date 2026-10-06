# Media Orphan Prevention PR 2: Blob Delete Fast Path Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When media rows die, durably delete their remote blobs (original +
thumb + rendition) via the existing transfer queue, with a drain-time
refcount guard; and stop stranding S3 multipart sessions on failure.

**Architecture:** PR 2 of 4 from
`docs/superpowers/specs/2026-07-23-media-store-orphan-prevention-design.md`
(sections 5.1-5.6). Exploration-driven refinement of spec 5.1: the queue
table already has unused `direction` (default `'upload'`) and `contentHash`
columns from Phase 1, so delete intents ride `direction = 'delete'` and
local cache DB v6 adds only ONE nullable `payloadJson` column (holding
`{"originalExt": ..., "renditionExt": ...}`, the two facts unrecoverable
after the media row dies). New units: `MediaDeleteProcessor` (drains delete
entries), `MediaDeletionCoordinator` (enqueue-before-delete wrapper the five
UI deletion call sites use), `MediaObjectStore.abandonResume` (multipart
session abort seam; S3 implements, others no-op).

**Tech Stack:** Flutter/Dart, Drift (local cache DB), Riverpod, flutter_test,
`test/helpers/in_memory_media_object_store.dart`, `test/helpers/fake_s3_server.dart`.

## Global Constraints

- Work in a dedicated worktree (branch `worktree-media-orphan-pr2`); after
  creation run `git submodule update --init --recursive`, `flutter pub get`,
  `dart run build_runner build --delete-conflicting-outputs`.
- `dart format .` clean before every commit; `flutter analyze` clean (infos
  fatal in CI). No emojis.
- Main app DB schema is NOT touched (no v136 here — that is PR 4). Only the
  local cache DB bumps (5 -> 6).
- Single-enqueuer rule (spec 5.4): only these user-action call sites enqueue
  deletes; sync tombstone application must NOT be wired to the coordinator.
- l10n changes go to ALL 11 arb locales (`lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb`)
  followed by `flutter gen-l10n` (generated `app_localizations*.dart` are
  tracked — commit them).
- PR description: substantive summary only; no attribution or session links.

---

### Task 1: Local cache DB v6 — `payloadJson` column

**Files:**
- Modify: `lib/core/database/local_cache_database.dart` (table lines 21-40,
  `schemaVersion` line 67, `onUpgrade` lines 70-92)
- Test: `test/features/media_store/media_transfer_queue_repository_test.dart`

**Interfaces:**
- Produces: `mediaTransferQueue.payloadJson` (`TextColumn`, nullable) —
  Tasks 2 and 4 read/write it as `MediaTransferQueueEntry.payloadJson`.

- [ ] **Step 1: Write the failing migration test**

Append to `test/features/media_store/media_transfer_queue_repository_test.dart`
(mirror the file's existing stored-schema upgrade tests around lines 131 and
227 — same NativeDatabase-on-temp-file pattern; reuse its imports):

```dart
test('v6 migration adds payload_json to an existing v5 stored schema',
    () async {
  final dir = await Directory.systemTemp.createTemp('cache_v6_test');
  addTearDown(() => dir.delete(recursive: true));
  final file = File('${dir.path}/cache.sqlite');

  // Build a v5-shaped database by hand: the v5 table WITHOUT payload_json,
  // stamped user_version = 5.
  final raw = sqlite3.sqlite3.open(file.path);
  raw.execute('''
    CREATE TABLE media_transfer_queue (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      media_id TEXT NOT NULL,
      direction TEXT NOT NULL DEFAULT 'upload',
      object_kind TEXT NOT NULL DEFAULT 'original',
      content_hash TEXT NULL,
      state TEXT NOT NULL DEFAULT 'pending',
      attempts INTEGER NOT NULL DEFAULT 0,
      next_attempt_at INTEGER NULL,
      resume_state_json TEXT NULL,
      error_message TEXT NULL,
      priority INTEGER NOT NULL DEFAULT 0,
      progress_bytes INTEGER NULL,
      total_bytes INTEGER NULL,
      override_level TEXT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
  ''');
  raw.execute('''
    CREATE TABLE media_cache_entries (
      content_hash TEXT NOT NULL,
      kind TEXT NOT NULL,
      relative_path TEXT NOT NULL,
      size_bytes INTEGER NOT NULL,
      last_accessed_at INTEGER NOT NULL,
      created_at INTEGER NOT NULL,
      source_version INTEGER NULL,
      PRIMARY KEY (content_hash, kind)
    );
  ''');
  raw.execute('''
    CREATE TABLE local_asset_cache (
      media_id TEXT NOT NULL PRIMARY KEY,
      recorded_at INTEGER NOT NULL,
      failure_count INTEGER NOT NULL DEFAULT 0
    );
  ''');
  raw.execute('PRAGMA user_version = 5;');
  raw.dispose();

  final upgraded = LocalCacheDatabase(NativeDatabase(file));
  addTearDown(upgraded.close);
  final migrated = MediaTransferQueueRepository(database: upgraded);
  final id = await migrated.enqueueDeleteForTesting(upgraded);
  final rows = await migrated.allForTesting();
  expect(rows.single.id, id);
  expect(rows.single.payloadJson, '{"originalExt":"jpg"}');
});
```

And a helper at the bottom of the file (exercises the new column without
depending on Task 2's API yet):

```dart
extension EnqueueDeleteForTesting on MediaTransferQueueRepository {
  Future<int> enqueueDeleteForTesting(LocalCacheDatabase db) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return db
        .into(db.mediaTransferQueue)
        .insert(
          MediaTransferQueueCompanion.insert(
            mediaId: 'm-payload',
            createdAt: now,
            updatedAt: now,
            payloadJson: const Value('{"originalExt":"jpg"}'),
          ),
        );
  }
}
```

NOTE: if the file's existing v1-schema fixture test creates
`local_asset_cache` with different columns, copy that test's exact
`local_asset_cache` DDL instead of the block above — only
`media_transfer_queue`/`media_cache_entries` matter here. Imports needed:
`import 'package:sqlite3/sqlite3.dart' as sqlite3;` (then
`sqlite3.sqlite3.open(...)`), `dart:io`, and drift's `Value` — check which
the file already has.

- [ ] **Step 2: Run it — expect compile failure (`payloadJson` undefined)**

Run: `flutter test test/features/media_store/media_transfer_queue_repository_test.dart`
Expected: FAIL to compile (no `payloadJson` on companion/row).

- [ ] **Step 3: Implement v6**

In `lib/core/database/local_cache_database.dart`:

Add to `MediaTransferQueue` after `overrideLevel` (line 37):

```dart
  /// Operation payload for non-upload directions (v6). For 'delete'
  /// entries: {"originalExt": ..., "renditionExt": ...} — the two facts
  /// that cannot be recovered once the media row is gone.
  TextColumn get payloadJson => text().nullable()();
```

Bump `schemaVersion` 5 -> 6 and add to `onUpgrade` (after the `from < 5`
block, same guard idiom — `from < 2` full-create already includes it):

```dart
        if (from >= 2 && from < 6) {
          await m.addColumn(mediaTransferQueue, mediaTransferQueue.payloadJson);
        }
```

Then run codegen: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 4: Run the test — expect PASS**

Run: `flutter test test/features/media_store/media_transfer_queue_repository_test.dart`
Expected: PASS (whole file — existing migration tests prove no double-add).

- [ ] **Step 5: Commit**

```bash
git add lib/core/database/local_cache_database.dart test/features/media_store/media_transfer_queue_repository_test.dart
git commit -m "feat(media-store): local cache DB v6 adds transfer queue payload column"
```

---

### Task 2: Queue repository — `enqueueDelete` + direction-scoped upload queries

**Files:**
- Modify: `lib/features/media_store/data/media_transfer_queue_repository.dart`
- Test: `test/features/media_store/media_transfer_queue_repository_test.dart`

**Interfaces:**
- Produces: `Future<int> enqueueDelete({required String mediaId, required String contentHash, required String originalExt, required String renditionExt})`
  — used by Task 6's coordinator. Delete rows have `direction == 'delete'`,
  `payloadJson == '{"originalExt":...,"renditionExt":...}'`.
- Changes: `enqueueUpload`, `enqueueReupload`, `watchLatestForMedia` now
  filter `direction.equals('upload')` so delete rows for the same mediaId
  cannot be confused with upload rows. `nextPending`, `markDone`,
  `markFailed`, `retry`, `requeueStale`, `defer`, `deleteDone`,
  `watchEntries` stay direction-agnostic (deletes share the lifecycle).

- [ ] **Step 1: Write the failing tests**

Append to the queue repository test file:

```dart
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
    expect(
      row.payloadJson,
      '{"originalExt":"jpg","renditionExt":"jpg"}',
    );
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
    expect(
      rows.firstWhere((r) => r.id == uploadId).direction,
      'upload',
    );
  });
});
```

- [ ] **Step 2: Run — expect FAIL (`enqueueDelete` undefined)**

Run: `flutter test test/features/media_store/media_transfer_queue_repository_test.dart`

- [ ] **Step 3: Implement**

In `media_transfer_queue_repository.dart` add (after `enqueueReupload`):

```dart
  /// Enqueues a remote-blob delete intent (orphan-prevention spec 5.1).
  /// One entry covers all tiers (original + thumb + rendition) of one
  /// content hash. Idempotent per hash for every live state, mirroring
  /// enqueueUpload's semantics: pending/transferring/failed delete rows
  /// are reused (the sweep is the backstop for terminal failures); only
  /// 'done' allows a fresh insert. [originalExt]/[renditionExt] are
  /// captured here because the media row is gone by drain time.
  Future<int> enqueueDelete({
    required String mediaId,
    required String contentHash,
    required String originalExt,
    required String renditionExt,
  }) async {
    return _db.transaction(() async {
      final existing =
          await (_db.select(_db.mediaTransferQueue)..where(
                (t) =>
                    t.direction.equals('delete') &
                    t.contentHash.equals(contentHash) &
                    t.state.isNotValue('done'),
              ))
              .get();
      if (existing.isNotEmpty) return existing.first.id;
      final now = DateTime.now().millisecondsSinceEpoch;
      return _db
          .into(_db.mediaTransferQueue)
          .insert(
            MediaTransferQueueCompanion.insert(
              mediaId: mediaId,
              direction: const Value('delete'),
              contentHash: Value(contentHash),
              payloadJson: Value(
                jsonEncode({
                  'originalExt': originalExt,
                  'renditionExt': renditionExt,
                }),
              ),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
  }
```

Add `import 'dart:convert';` at the top.

Then scope the three mediaId-keyed upload queries: in `enqueueUpload`'s
existing-row select, `enqueueReupload`'s delete-existing statement, and
`watchLatestForMedia`'s where clause, add `& t.direction.equals('upload')`
to the existing `t.mediaId.equals(mediaId)` condition (three one-line
edits; read each method and extend its `where`).

- [ ] **Step 4: Run the queue test file — expect PASS. Also run worker + pipeline suites (direction filter regression):**

Run: `flutter test test/features/media_store/`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/media_store/data/media_transfer_queue_repository.dart test/features/media_store/media_transfer_queue_repository_test.dart
git commit -m "feat(media-store): delete-intent queue entries with per-hash idempotency"
```

---

### Task 3: `MediaRepository.countRowsWithHash`

**Files:**
- Modify: `lib/features/media/data/repositories/media_repository.dart`
  (beside `countRowsWithOriginal`, ~line 1020)
- Test: `test/features/media/data/media_repository_compressed_test.dart`

**Interfaces:**
- Produces: `Future<int> countRowsWithHash(String contentHash)` — counts
  ALL media rows with the hash, uploaded or not (deliberately broader than
  `countRowsWithOriginal`; spec 5.3). Used by Task 4's processor.

- [ ] **Step 1: Failing test** (append to the compressed test file):

```dart
  test('countRowsWithHash counts every row with the hash, uploaded or not',
      () async {
    await repo.createMedia(
      photo('u1', hash: 'hh').copyWith(remoteUploadedAt: DateTime(2026)),
    );
    await repo.createMedia(photo('u2', hash: 'hh')); // never uploaded
    await repo.createMedia(photo('u3', hash: 'other'));
    expect(await repo.countRowsWithHash('hh'), 2);
    expect(await repo.countRowsWithHash('nope'), 0);
  });
```

- [ ] **Step 2: Run — expect FAIL (method undefined)**

Run: `flutter test test/features/media/data/media_repository_compressed_test.dart`

- [ ] **Step 3: Implement** (mirror `countRowsWithOriginal`'s query shape,
  minus the stamp filter):

```dart
  /// Rows referencing [contentHash] at all — uploaded or not. The delete
  /// fast path's drain-time refcount (orphan-prevention spec 5.3):
  /// deliberately broader than [countRowsWithOriginal] because skipping a
  /// blob delete is free while a wrong delete costs a re-upload.
  Future<int> countRowsWithHash(String contentHash) async {
    final count = countAll();
    final query = _db.selectOnly(_db.media)
      ..addColumns([count])
      ..where(_db.media.contentHash.equals(contentHash));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }
```

- [ ] **Step 4: Run — expect PASS.** Then commit:

```bash
git add lib/features/media/data/repositories/media_repository.dart test/features/media/data/media_repository_compressed_test.dart
git commit -m "feat(media): countRowsWithHash refcount for blob deletion"
```

---

### Task 4: `MediaDeleteProcessor`

**Files:**
- Create: `lib/features/media_store/data/media_delete_processor.dart`
- Test: `test/features/media_store/media_delete_processor_test.dart`

**Interfaces:**
- Consumes: `MediaTransferQueueRepository` (markTransferring/markDone/markFailed),
  `MediaRepository.countRowsWithHash`, `MediaObjectStore.delete`,
  `StoreKeys.objectKey/thumbKey/renditionKey`.
- Produces: `class MediaDeleteProcessor { Future<void> process(MediaTransferQueueEntry entry) }`
  — Task 5's worker dispatches `direction == 'delete'` entries here.

- [ ] **Step 1: Failing tests**

Create `test/features/media_store/media_delete_processor_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/data/media_delete_processor.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

import '../../helpers/in_memory_media_object_store.dart';
import '../../helpers/test_database.dart';

void main() {
  late LocalCacheDatabase cacheDb;
  late MediaTransferQueueRepository queue;
  late MediaRepository mediaRepository;
  late InMemoryMediaObjectStore store;
  late MediaDeleteProcessor processor;

  setUp(() async {
    await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    queue = MediaTransferQueueRepository(database: cacheDb);
    mediaRepository = MediaRepository();
    store = InMemoryMediaObjectStore();
    processor = MediaDeleteProcessor(
      queue: queue,
      store: store,
      mediaRepository: mediaRepository,
    );
  });

  tearDown(() async {
    await cacheDb.close();
    await tearDownTestDatabase();
  });

  const hash = 'aabbccdd';
  final originalKey = StoreKeys.objectKey(hash, extension: 'jpg');
  final thumbKey = StoreKeys.thumbKey(hash);
  final renditionKey = StoreKeys.renditionKey(hash, ext: 'jpg');

  Future<MediaTransferQueueEntry> deleteEntry() async {
    final id = await queue.enqueueDelete(
      mediaId: 'gone',
      contentHash: hash,
      originalExt: 'jpg',
      renditionExt: 'jpg',
    );
    return (await queue.allForTesting()).firstWhere((r) => r.id == id);
  }

  test('deletes all three tiers and marks done when hash unreferenced',
      () async {
    store.objects[originalKey] = [1, 2, 3];
    store.objects[thumbKey] = [4];
    store.objects[renditionKey] = [5];
    await processor.process(await deleteEntry());
    expect(store.objects, isEmpty);
    expect((await queue.allForTesting()).single.state, 'done');
  });

  test('skips deletion when any row still references the hash', () async {
    await mediaRepository.createMedia(
      MediaItem(
        id: 'still-here',
        mediaType: MediaType.photo,
        takenAt: DateTime(2026),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        contentHash: hash,
      ),
    );
    store.objects[originalKey] = [1];
    await processor.process(await deleteEntry());
    expect(store.objects, containsPair(originalKey, [1]));
    expect((await queue.allForTesting()).single.state, 'done');
  });

  test('store failure marks the entry failed for retry', () async {
    store.objects[originalKey] = [1];
    store.failDeleteWith = Exception('boom');
    await processor.process(await deleteEntry());
    final row = (await queue.allForTesting()).single;
    expect(row.state, 'pending'); // attempt 1 of 5, backoff scheduled
    expect(row.attempts, 1);
    expect(row.errorMessage, contains('boom'));
  });

  test('malformed payload still deletes thumb and falls back on defaults',
      () async {
    final id = await queue.enqueueDelete(
      mediaId: 'gone',
      contentHash: hash,
      originalExt: 'jpg',
      renditionExt: 'jpg',
    );
    // Corrupt the payload behind the repository's back.
    await (cacheDb.update(cacheDb.mediaTransferQueue)
          ..where((t) => t.id.equals(id)))
        .write(
          const MediaTransferQueueCompanion(
            payloadJson: Value('not json'),
          ),
        );
    store.objects[thumbKey] = [4];
    final entry = (await queue.allForTesting()).single;
    await processor.process(entry);
    expect(store.objects, isEmpty);
    expect((await queue.allForTesting()).single.state, 'done');
  });
}
```

If `InMemoryMediaObjectStore`'s byte map is not named `objects`, read
`test/helpers/in_memory_media_object_store.dart` and use its actual public
map/putBytes seam; if none is public, add a test-only
`Map<String, List<int>> get objects` view to the helper.

Add `import 'package:drift/drift.dart' show Value;` if the corrupt-payload
write needs it.

- [ ] **Step 2: Run — expect FAIL (processor file missing)**

Run: `flutter test test/features/media_store/media_delete_processor_test.dart`

- [ ] **Step 3: Implement**

Create `lib/features/media_store/data/media_delete_processor.dart`:

```dart
import 'dart:convert';

import 'package:submersion/core/services/logging/app_logger.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

/// Drains 'delete' transfer-queue entries: removes a dead media row's
/// remote original, thumb, and rendition objects (orphan-prevention spec
/// section 5). The refcount re-check happens here at drain time — never at
/// enqueue time — so references that appear between the two (late sync
/// pulls, re-imports) win and the delete becomes a no-op.
class MediaDeleteProcessor {
  MediaDeleteProcessor({
    required MediaTransferQueueRepository queue,
    required MediaObjectStore store,
    required MediaRepository mediaRepository,
  }) : _queue = queue,
       _store = store,
       _mediaRepository = mediaRepository;

  final MediaTransferQueueRepository _queue;
  final MediaObjectStore _store;
  final MediaRepository _mediaRepository;
  final _log = AppLogger('MediaDeleteProcessor');

  Future<void> process(MediaTransferQueueEntry entry) async {
    await _queue.markTransferring(entry.id);
    try {
      final hash = entry.contentHash;
      if (hash == null || hash.isEmpty) {
        // Unusable intent; nothing safe to delete. The sweep is the backstop.
        await _queue.markDone(entry.id);
        return;
      }
      if (await _mediaRepository.countRowsWithHash(hash) > 0) {
        await _queue.markDone(entry.id);
        return;
      }
      final payload = _parsePayload(entry.payloadJson);
      await _store.delete(
        StoreKeys.objectKey(hash, extension: payload.originalExt),
      );
      await _store.delete(StoreKeys.thumbKey(hash));
      await _store.delete(
        StoreKeys.renditionKey(hash, ext: payload.renditionExt),
      );
      await _queue.markDone(entry.id);
    } on Exception catch (e, stackTrace) {
      _log.warning(
        'Remote delete failed for ${entry.contentHash}',
        error: e,
        stackTrace: stackTrace,
      );
      await _queue.markFailed(entry.id, e.toString());
    }
  }

  /// Defensive parse: a corrupt payload degrades to plausible extensions
  /// rather than failing the entry — deleting a key that never existed is
  /// an idempotent no-op, and anything missed falls to the sweep.
  ({String originalExt, String renditionExt}) _parsePayload(String? json) {
    if (json != null) {
      try {
        final decoded = jsonDecode(json);
        if (decoded is Map<String, dynamic>) {
          final original = decoded['originalExt'];
          final rendition = decoded['renditionExt'];
          if (original is String && rendition is String) {
            return (originalExt: original, renditionExt: rendition);
          }
        }
      } on FormatException {
        // fall through to defaults
      }
    }
    return (originalExt: 'bin', renditionExt: 'jpg');
  }
}
```

If the project's logger class/API differs (check how
`media_upload_pipeline.dart` constructs and calls its `_log`), mirror that
exactly.

- [ ] **Step 4: Run — expect PASS.** Then commit:

```bash
git add lib/features/media_store/data/media_delete_processor.dart test/features/media_store/media_delete_processor_test.dart
git commit -m "feat(media-store): delete processor with drain-time refcount guard"
```

---

### Task 5: Worker routing + cellular-gate bypass

**Files:**
- Modify: `lib/features/media_store/data/media_store_worker.dart`
  (constructor lines 15-23, drain loop lines 48-77)
- Modify: `lib/features/media_store/presentation/providers/media_store_providers.dart`
  (worker construction ~line 211, gate closure lines 223-237)
- Test: `test/features/media_store/media_store_worker_delete_test.dart` (new)

**Interfaces:**
- Consumes: Task 4's `MediaDeleteProcessor`.
- Produces: `MediaStoreWorker` gains optional `MediaDeleteProcessor? deleteProcessor`
  ctor param; drain dispatches `entry.direction == 'delete'` to it (defers
  the entry when the processor is absent). Gate: delete entries proceed on
  any non-offline network.

- [ ] **Step 1: Failing test**

Create `test/features/media_store/media_store_worker_delete_test.dart`.
Mirror the setup style of `media_store_worker_reclaim_test.dart` (read it
first for the pipeline test-double idiom), with this core:

```dart
test('drain routes delete entries to the delete processor', () async {
  // queue: one delete entry + one upload entry
  await queue.enqueueDelete(
    mediaId: 'dead',
    contentHash: 'aa',
    originalExt: 'jpg',
    renditionExt: 'jpg',
  );
  await queue.enqueueUpload(mediaId: 'alive');
  final processedUploads = <String>[];
  final processedDeletes = <int>[];
  // pipeline double records mediaIds; delete-processor double records ids
  // and marks done (so drain terminates).
  final worker = MediaStoreWorker(
    queue: queue,
    pipeline: pipelineDouble, // records entry.mediaId, marks entry done
    deleteProcessor: deleteProcessorDouble,
  );
  await worker.drain();
  expect(processedDeletes, hasLength(1));
  expect(processedUploads, ['alive']);
});

test('delete entries are deferred when no delete processor is wired',
    () async {
  await queue.enqueueDelete(
    mediaId: 'dead',
    contentHash: 'aa',
    originalExt: 'jpg',
    renditionExt: 'jpg',
  );
  final worker = MediaStoreWorker(queue: queue, pipeline: pipelineDouble);
  await worker.drain(); // must terminate, not spin
  final row = (await queue.allForTesting()).single;
  expect(row.state, 'pending');
  expect(row.nextAttemptAt, isNotNull); // parked in the defer window
});
```

For the doubles: `MediaDeleteProcessor` is a concrete class — subclass it
in the test overriding `process` (constructor args can be the real queue +
`InMemoryMediaObjectStore()` + `MediaRepository()`), or wrap via a small
`implements MediaDeleteProcessor` fake if the ctor pulls too much. The
pipeline double follows whatever `media_store_worker_reclaim_test.dart`
already does for `MediaUploadPipeline`.

- [ ] **Step 2: Run — expect FAIL (no `deleteProcessor` param)**

- [ ] **Step 3: Implement worker routing**

In `media_store_worker.dart`: add ctor param + field
`final MediaDeleteProcessor? _deleteProcessor;` (import the processor), and
in the drain loop replace the single dispatch line (line 72,
`await _pipeline.process(entry);`) with:

```dart
      if (entry.direction == 'delete') {
        final deleteProcessor = _deleteProcessor;
        if (deleteProcessor == null) {
          // No processor wired (unattached runtime shapes in tests):
          // park the entry so drain terminates; a properly wired worker
          // picks it up later.
          await _queue.defer(entry.id, DateTime.now().add(deferWindow));
          continue;
        }
        await deleteProcessor.process(entry);
        continue;
      }
      await _pipeline.process(entry);
```

- [ ] **Step 4: Wire runtime + gate**

In `media_store_providers.dart` runtime provider: construct the processor
and pass it (beside the existing `MediaUploadPipeline` construction,
~line 202):

```dart
      final deleteProcessor = MediaDeleteProcessor(
        queue: MediaTransferQueueRepository(),
        store: store,
        mediaRepository: mediaRepository,
      );
```

and add `deleteProcessor: deleteProcessor,` to the `MediaStoreWorker(...)`
construction. In the gate closure, immediately after the offline check
(`if (kind == NetworkKind.offline) return WorkerGate.stopDraining;`):

```dart
          // Deletes are tiny API calls with no payload: exempt from the
          // cellular media policies, gated only by being online
          // (orphan-prevention spec 5.6).
          if (entry.direction == 'delete') return WorkerGate.proceed;
```

Import `media_delete_processor.dart` there.

- [ ] **Step 5: Run — expect PASS**

Run: `flutter test test/features/media_store/`

- [ ] **Step 6: Commit**

```bash
git add lib/features/media_store/data/media_store_worker.dart lib/features/media_store/presentation/providers/media_store_providers.dart test/features/media_store/media_store_worker_delete_test.dart
git commit -m "feat(media-store): worker routes delete entries, cellular gate exempts them"
```

---

### Task 6: Multipart session abort (`abandonResume`)

**Files:**
- Modify: `lib/core/services/media_store/media_object_store.dart` (interface)
- Modify: `lib/core/services/media_store/s3_media_object_store.dart`
  (`_putMultipart` lines 102-160, new `abandonResume`)
- Modify: `lib/core/services/media_store/dropbox_media_object_store.dart`,
  `google_drive_media_object_store.dart`, `icloud_media_object_store.dart`
  (no-op impls), `test/helpers/in_memory_media_object_store.dart`
  (recording impl) — plus run
  `grep -rn "implements MediaObjectStore" lib test` and give EVERY
  implementor the member.
- Modify: `lib/features/media_store/data/media_transfer_queue_repository.dart`
  (`markFailed` returns `Future<bool>`)
- Modify: `lib/features/media_store/data/media_upload_pipeline.dart`
  (terminal-failure abort hook)
- Test: `test/features/media_store/s3_multipart_abort_test.dart` (new);
  extend `test/helpers/fake_s3_server.dart` with
  `int get activeMultipartUploadCount => _sessions.length;`

**Interfaces:**
- Produces: `Future<void> abandonResume(String key, String? resumeStateJson)`
  on `MediaObjectStore` (abstract member; every implementor defines it —
  no-op everywhere except S3). `markFailed` now returns whether the entry
  went terminal.

- [ ] **Step 1: Failing tests**

Create `test/features/media_store/s3_multipart_abort_test.dart` (mirror the
existing multipart test file's FakeS3Server + S3MediaObjectStore setup —
find it with `grep -rln "FakeS3Server" test/features/media_store/` and copy
its store construction):

```dart
test('putFile without resume persistence aborts the multipart session on '
    'failure', () async {
  // Arrange a > partSizeBytes source and a persistent part-upload fault
  // (fault must persist until cleared — one-shot 500s get absorbed by the
  // client's retry).
  server.failPartUploads = true; // use the fake's existing fault seam name
  await expectLater(
    store.putFile(key, bigFile, contentType: 'image/jpeg'),
    throwsA(isA<MediaStoreException>()),
  );
  server.failPartUploads = false;
  expect(server.activeMultipartUploadCount, 0); // aborted, not stranded
});

test('putFile WITH resume persistence keeps the session for resume',
    () async {
  server.failPartUploads = true;
  String? resume;
  await expectLater(
    store.putFile(
      key,
      bigFile,
      contentType: 'image/jpeg',
      onResumeStateChanged: (json) => resume = json,
    ),
    throwsA(isA<MediaStoreException>()),
  );
  server.failPartUploads = false;
  expect(server.activeMultipartUploadCount, 1); // kept for resume
});

test('abandonResume aborts the recorded session and tolerates junk',
    () async {
  // ... produce a stranded session as in the previous test ...
  await store.abandonResume(key, resume);
  expect(server.activeMultipartUploadCount, 0);
  await store.abandonResume(key, 'not json'); // must not throw
  await store.abandonResume(key, null); // must not throw
});
```

Adjust the fault-seam name to whatever `fake_s3_server.dart` actually
exposes (read it; per its docs the injected fault persists until cleared).

Also extend the queue test file:

```dart
test('markFailed reports terminality', () async {
  final id = await repo.enqueueUpload(mediaId: 'm1');
  for (var i = 0; i < 4; i++) {
    expect(await repo.markFailed(id, 'e'), isFalse);
    await repo.retryAfterBackoffForTesting(id); // or clear nextAttemptAt as existing tests do
  }
  expect(await repo.markFailed(id, 'e'), isTrue);
});
```

(Use whatever mechanism the existing markFailed tests use to walk attempts
— read those tests and mirror; drop the helper if they simply call
markFailed repeatedly.)

- [ ] **Step 2: Run — expect FAIL (no `abandonResume`, `markFailed` returns void)**

- [ ] **Step 3: Implement**

Interface (`media_object_store.dart`, after `delete`):

```dart
  /// Best-effort abandonment of any provider-side resumable upload
  /// session recorded in [resumeStateJson] for [key] (orphan-prevention
  /// spec 5.5). Called when an upload is terminally failed. Providers
  /// whose sessions self-expire (Dropbox, Drive, iCloud) no-op; must
  /// never throw on malformed or null state.
  Future<void> abandonResume(String key, String? resumeStateJson);
```

S3 implementation (in `s3_media_object_store.dart`):

```dart
  @override
  Future<void> abandonResume(String key, String? resumeStateJson) async {
    if (resumeStateJson == null) return;
    String? uploadId;
    try {
      final decoded = jsonDecode(resumeStateJson);
      if (decoded is Map<String, dynamic>) {
        final id = decoded['uploadId'];
        if (id is String) uploadId = id;
      }
    } on FormatException {
      return;
    }
    await _abortQuietly(_wire(key), uploadId);
  }
```

No-op impls in Dropbox/Drive/iCloud adapters (and every other
`implements MediaObjectStore` hit from the grep, including the in-memory
helper — there give it a `abandonResumeCalls` recording list):

```dart
  @override
  Future<void> abandonResume(String key, String? resumeStateJson) async {}
```

`_putMultipart` no-persistence abort: hoist the session variable so the
catch can see it, and abort when the caller gave no persistence callback
(nothing will ever replay this session):

At the top of `_putMultipart`, change the local session binding so it is
declared before the `try` (`({String uploadId, List<S3PartInfo> parts})?
session;` assigned inside), then replace the catch block (lines 151-159):

```dart
    } on CloudStorageException catch (e) {
      if (onResumeStateChanged == null) {
        await _abortQuietly(wireKey, session?.uploadId);
      }
      throw _map('put', key, e);
    } on FileSystemException catch (e) {
      if (onResumeStateChanged == null) {
        await _abortQuietly(wireKey, session?.uploadId);
      }
      throw MediaStoreException(
        'cannot read source for $key',
        kind: MediaStoreErrorKind.fatal,
        cause: e,
      );
    }
```

`markFailed` (queue repo): change signature to `Future<bool>` and end with
`return terminal;` (body otherwise unchanged).

Pipeline terminal hook (`media_upload_pipeline.dart`): locate `process`'s
failure path that calls `_queue.markFailed(entry.id, ...)`. Maintain two
locals across the original-upload attempt — set `uploadKey` just before the
original `putFile` call (line ~237) and shadow the resume callback:

```dart
    String? latestResumeJson = entry.resumeStateJson;
    String? uploadKey;
```

where the pipeline currently passes
`onResumeStateChanged: (json) => _queue.updateResumeState(entry.id, json)`
(line ~249), wrap it:

```dart
          onResumeStateChanged: (json) {
            latestResumeJson = json;
            _queue.updateResumeState(entry.id, json);
          },
```

and in the failure path:

```dart
      final terminal = await _queue.markFailed(entry.id, message);
      if (terminal && uploadKey != null && latestResumeJson != null) {
        try {
          await _store.abandonResume(uploadKey, latestResumeJson);
        } on Exception catch (e) {
          _log.warning('abandonResume failed for $uploadKey', error: e);
        }
      }
```

(Adapt variable names to the actual catch block — read it first; `message`
stands for whatever error string it already builds.)

Known accepted gap (document in the PR body, do not fix here):
`enqueueReupload` deletes an existing queue row of any state, which can
discard a `resumeStateJson` whose S3 session then strands until it expires
or PR 4's `ListMultipartUploads` reap catches it. The queue repository has
no store access, and threading one in for this edge is not worth the
coupling — spec 6.1 step 4 is the designed backstop.

- [ ] **Step 4: Run — expect PASS**

Run: `flutter test test/features/media_store/ test/core/services/`
Expected: all pass (adapter contract tests now cover the new member).

- [ ] **Step 5: Commit**

```bash
git add -A lib/core/services/media_store test/helpers lib/features/media_store/data test/features/media_store
git commit -m "feat(media-store): abort stranded S3 multipart sessions on terminal failure"
```

---

### Task 7: `MediaDeletionCoordinator` + provider

**Files:**
- Create: `lib/features/media_store/data/media_deletion_coordinator.dart`
- Modify: `lib/features/media_store/presentation/providers/media_store_providers.dart`
  (new provider)
- Test: `test/features/media_store/media_deletion_coordinator_test.dart`

**Interfaces:**
- Consumes: `MediaRepository.getMediaById/deleteMedia/deleteMultipleMedia`,
  Task 2's `enqueueDelete`, `StoreKeys.extensionFor`.
- Produces: `class MediaDeletionCoordinator { Future<void> deleteMedia(String id); Future<void> deleteMultipleMedia(List<String> ids); }`
  and `final mediaDeletionCoordinatorProvider = Provider<MediaDeletionCoordinator>`.
  Task 8's call sites use exactly these.

- [ ] **Step 1: Failing tests**

Create `test/features/media_store/media_deletion_coordinator_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/data/media_deletion_coordinator.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

import '../../helpers/test_database.dart';

void main() {
  late LocalCacheDatabase cacheDb;
  late MediaTransferQueueRepository queue;
  late MediaRepository repo;
  late int kicks;
  late MediaDeletionCoordinator coordinator;

  setUp(() async {
    await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    queue = MediaTransferQueueRepository(database: cacheDb);
    repo = MediaRepository();
    kicks = 0;
    coordinator = MediaDeletionCoordinator(
      mediaRepository: repo,
      queue: () => queue,
      kickWorker: () async => kicks++,
    );
  });

  tearDown(() async {
    await cacheDb.close();
    await tearDownTestDatabase();
  });

  MediaItem photo(
    String id, {
    String? hash,
    DateTime? uploadedAt,
    MediaType mediaType = MediaType.photo,
  }) => MediaItem(
    id: id,
    mediaType: mediaType,
    originalFilename: 'p.jpeg',
    takenAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    contentHash: hash,
    remoteUploadedAt: uploadedAt,
  );

  test('enqueues delete intent, then deletes the row, then kicks', () async {
    await repo.createMedia(
      photo('m1', hash: 'aa', uploadedAt: DateTime(2026, 2)),
    );
    await coordinator.deleteMedia('m1');
    expect(await repo.getMediaById('m1'), isNull);
    final row = (await queue.allForTesting()).single;
    expect(row.direction, 'delete');
    expect(row.contentHash, 'aa');
    expect(row.payloadJson, contains('"originalExt":"jpeg"'));
    expect(row.payloadJson, contains('"renditionExt":"jpg"'));
    expect(kicks, 1);
  });

  test('videos record an mp4 rendition extension', () async {
    await repo.createMedia(
      photo(
        'v1',
        hash: 'bb',
        uploadedAt: DateTime(2026, 2),
        mediaType: MediaType.video,
      ),
    );
    await coordinator.deleteMedia('v1');
    expect(
      (await queue.allForTesting()).single.payloadJson,
      contains('"renditionExt":"mp4"'),
    );
  });

  test('never-uploaded and hashless rows delete without enqueueing',
      () async {
    await repo.createMedia(photo('m2', hash: 'bb')); // hash, no stamp
    await repo.createMedia(photo('m3')); // no hash
    await coordinator.deleteMultipleMedia(['m2', 'm3']);
    expect(await repo.getMediaById('m2'), isNull);
    expect(await repo.getMediaById('m3'), isNull);
    expect(await queue.allForTesting(), isEmpty);
    expect(kicks, 0);
  });

  test('queue failure never blocks row deletion', () async {
    await repo.createMedia(
      photo('m4', hash: 'cc', uploadedAt: DateTime(2026, 2)),
    );
    final broken = MediaDeletionCoordinator(
      mediaRepository: repo,
      queue: () => throw StateError('cache db not initialized'),
      kickWorker: () async => kicks++,
    );
    await broken.deleteMedia('m4');
    expect(await repo.getMediaById('m4'), isNull);
  });
}
```

- [ ] **Step 2: Run — expect FAIL (file missing)**

- [ ] **Step 3: Implement**

Create `lib/features/media_store/data/media_deletion_coordinator.dart`:

```dart
import 'package:submersion/core/services/logging/app_logger.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

/// Wraps media-row deletion with the remote-blob delete fast path
/// (orphan-prevention spec 5.2): the delete INTENT is enqueued BEFORE the
/// row dies — the queue lives in a different database, so no cross-DB
/// transaction exists, and this ordering makes the only crash window
/// harmless (an intent whose row survived no-ops on the drain-time
/// refcount). Enqueue problems never block the deletion itself; missed
/// intents fall to the Verify Library sweep.
class MediaDeletionCoordinator {
  MediaDeletionCoordinator({
    required MediaRepository mediaRepository,
    required MediaTransferQueueRepository Function() queue,
    Future<void> Function()? kickWorker,
  }) : _mediaRepository = mediaRepository,
       _queue = queue,
       _kickWorker = kickWorker;

  final MediaRepository _mediaRepository;
  final MediaTransferQueueRepository Function() _queue;
  final Future<void> Function()? _kickWorker;
  final _log = AppLogger('MediaDeletionCoordinator');

  Future<void> deleteMedia(String id) => deleteMultipleMedia([id]);

  Future<void> deleteMultipleMedia(List<String> ids) async {
    var enqueued = false;
    for (final id in ids) {
      // Untyped catch on purpose: an uninitialized LocalCacheDatabaseService
      // throws StateError (an Error), and no media-store problem may ever
      // block the user's deletion.
      try {
        if (await _enqueueIntent(id)) enqueued = true;
      } catch (e, stackTrace) {
        _log.warning(
          'Could not enqueue remote delete for media $id '
          '(sweep will reconcile)',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
    if (ids.length == 1) {
      await _mediaRepository.deleteMedia(ids.single);
    } else {
      await _mediaRepository.deleteMultipleMedia(ids);
    }
    if (enqueued && _kickWorker != null) {
      try {
        await _kickWorker();
      } catch (e) {
        _log.warning('Worker kick after delete failed', error: e);
      }
    }
  }

  Future<bool> _enqueueIntent(String id) async {
    final item = await _mediaRepository.getMediaById(id);
    final hash = item?.contentHash;
    if (item == null || hash == null || hash.isEmpty) return false;
    final everUploaded =
        item.remoteUploadedAt != null ||
        item.remoteThumbUploadedAt != null ||
        item.remoteCompressedUploadedAt != null;
    if (!everUploaded) return false;
    await _queue().enqueueDelete(
      mediaId: id,
      contentHash: hash,
      originalExt: StoreKeys.extensionFor(item.originalFilename),
      renditionExt: item.mediaType == MediaType.video ? 'mp4' : 'jpg',
    );
    return true;
  }
}
```

Provider (in `media_store_providers.dart`):

```dart
/// Deletion entry point for UI flows: enqueue-before-delete per the
/// orphan-prevention spec. Reads (never watches) the runtime so consumer
/// widget tests without a media store runtime are unaffected.
final mediaDeletionCoordinatorProvider = Provider<MediaDeletionCoordinator>((
  ref,
) {
  return MediaDeletionCoordinator(
    mediaRepository: ref.watch(mediaRepositoryProvider),
    queue: () => ref.read(mediaTransferQueueRepositoryProvider),
    kickWorker: () async {
      final runtime = await ref.read(mediaStoreRuntimeProvider.future);
      await runtime?.worker?.drain();
    },
  );
});
```

(Match `runtime?.worker?.drain()` nullability to how `_retry` in
`transfers_page.dart:129` already calls it.)

- [ ] **Step 4: Run — expect PASS.** Then commit:

```bash
git add lib/features/media_store/data/media_deletion_coordinator.dart lib/features/media_store/presentation/providers/media_store_providers.dart test/features/media_store/media_deletion_coordinator_test.dart
git commit -m "feat(media-store): deletion coordinator enqueues blob deletes before rows die"
```

---

### Task 8: Route the five deletion call sites through the coordinator

**Files:**
- Modify: `lib/features/media/presentation/providers/media_providers.dart`
  (`MediaListNotifier.deleteMedia` ~line 135, `deleteMultipleMedia` ~line 141)
- Modify: `lib/features/media/presentation/providers/files_tab_providers.dart:~177`
- Modify: `lib/features/media/presentation/providers/url_tab_providers.dart:~174`
- Modify: `lib/features/media/presentation/widgets/dive_media_section.dart:~175`
- Modify: `lib/features/media/presentation/widgets/manifest_mode_panel.dart:~167`
- Test: existing consumer tests (run whole media suites)

**Interfaces:**
- Consumes: Task 7's `mediaDeletionCoordinatorProvider`.
- Produces: no signature changes — every method keeps its shape; only the
  internals now call the coordinator instead of `MediaRepository` directly.

- [ ] **Step 1: Rewire**

In `media_providers.dart` (`MediaListNotifier` has `_ref`):

```dart
  /// Delete a media item
  Future<void> deleteMedia(String id) async {
    await _ref.read(mediaDeletionCoordinatorProvider).deleteMedia(id);
    await refresh();
  }

  /// Delete multiple media items at once
  Future<void> deleteMultipleMedia(List<String> ids) async {
    await _ref.read(mediaDeletionCoordinatorProvider).deleteMultipleMedia(ids);
    await refresh();
  }
```

Add the import
`import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';`
(cross-feature import matches the existing resolver precedent).

In `files_tab_providers.dart` and `url_tab_providers.dart` and
`manifest_mode_panel.dart`: each currently loops `deleteMedia(id)` per id —
replace the loop with ONE call:

```dart
    await ref
        .read(mediaDeletionCoordinatorProvider)
        .deleteMultipleMedia(mediaIds);
```

(Read each site first; keep whatever refresh/invalidate calls follow the
loop, and use the site's actual ids variable name and ref accessor —
`_ref` in notifiers, `ref` in widgets.)

In `dive_media_section.dart` `_unlinkSelected`: replace the
`deleteMultipleMedia(selectedIds)` repository/notifier call with the same
coordinator call, preserving the surrounding selection-clearing logic.

- [ ] **Step 2: Run the consumer suites**

Run: `flutter test test/features/media test/features/media_store test/features/dive_log`
Expected: all pass. If a widget test now fails constructing the provider
graph, the failure will be a MissingStubError or StateError inside the
coordinator path — fix by confirming the coordinator catches it (Task 7's
queue-failure test covers StateError; unstubbed mock `getMediaById` returns
a default null, which skips enqueueing).

- [ ] **Step 3: Commit**

```bash
git add lib/features/media/presentation lib/features/media_store
git commit -m "feat(media): route media deletion flows through the deletion coordinator"
```

---

### Task 9: Transfers page delete tile + l10n

**Files:**
- Modify: `lib/features/media_store/presentation/pages/transfers_page.dart`
  (`_TransferTile.build`, the `switch (entry.state)` at lines 55-69)
- Modify: all 11 `lib/l10n/arb/app_*.arb` + run `flutter gen-l10n`
- Test: `test/features/media_store/transfers_page_delete_tile_test.dart` (new)

**Interfaces:**
- Consumes: `entry.direction` (existing column), new l10n key
  `settings_mediaStorage_transfers_state_deleting`.

- [ ] **Step 1: Add l10n keys**

`app_en.arb` (beside `settings_mediaStorage_transfers_state_transferring`,
line ~12827):

```json
  "settings_mediaStorage_transfers_state_deleting": "Removing from cloud",
```

Translations (insert at the same alphabetical position in each file):
- `app_de.arb`: `"Wird aus der Cloud entfernt"`
- `app_es.arb`: `"Eliminando de la nube"`
- `app_fr.arb`: `"Suppression du cloud"`
- `app_it.arb`: `"Rimozione dal cloud"`
- `app_nl.arb`: `"Verwijderen uit de cloud"`
- `app_pt.arb`: `"Removendo da nuvem"`
- `app_hu.arb`: `"Eltávolítás a felhőből"`
- `app_ar.arb`: `"جارٍ الإزالة من السحابة"`
- `app_he.arb`: `"מסיר מהענן"`
- `app_zh.arb`: `"正在从云端移除"`

Run `flutter gen-l10n` and stage the regenerated tracked
`app_localizations*.dart`.

- [ ] **Step 2: Failing widget test**

Create `test/features/media_store/transfers_page_delete_tile_test.dart`
(mirror the provider-override style of `media_storage_page_test.dart` for
pumping a localized page; override `mediaTransferEntriesProvider` — check
its exact name/type at `media_store_providers.dart:102` — with a
`Stream.value([...])` containing one delete row):

```dart
testWidgets('a transferring delete entry shows the removing label',
    (tester) async {
  final entry = MediaTransferQueueData(
    id: 1,
    mediaId: 'dead',
    direction: 'delete',
    objectKind: 'original',
    contentHash: 'aa',
    state: 'transferring',
    attempts: 0,
    priority: 0,
    createdAt: 0,
    updatedAt: 0,
  );
  // pump TransfersPage with mediaTransferEntriesProvider overridden to
  // emit [entry]
  expect(find.text('Removing from cloud'), findsOneWidget);
  expect(find.byIcon(Icons.delete_outline), findsOneWidget);
});
```

(Include any additional required constructor fields the generated
`MediaTransferQueueData` demands — the analyzer will list them.)

- [ ] **Step 3: Implement the tile**

In `_TransferTile.build`, replace the `(icon, label)` switch:

```dart
    final isDelete = entry.direction == 'delete';
    final (icon, label) = switch (entry.state) {
      'transferring' => (
        isDelete ? Icons.delete_outline : Icons.cloud_upload,
        isDelete
            ? l10n.settings_mediaStorage_transfers_state_deleting
            : l10n.settings_mediaStorage_transfers_state_transferring,
      ),
      'failed' => (
        Icons.error_outline,
        l10n.settings_mediaStorage_transfers_state_failed,
      ),
      'done' => (
        isDelete ? Icons.delete_outline : Icons.cloud_done,
        l10n.settings_mediaStorage_transfers_state_done,
      ),
      _ => (
        isDelete ? Icons.delete_outline : Icons.schedule,
        l10n.settings_mediaStorage_transfers_state_pending,
      ),
    };
```

- [ ] **Step 4: Run — expect PASS**

Run: `flutter test test/features/media_store/transfers_page_delete_tile_test.dart`

- [ ] **Step 5: Commit**

```bash
git add lib/features/media_store/presentation/pages/transfers_page.dart lib/l10n test/features/media_store/transfers_page_delete_tile_test.dart
git commit -m "feat(media-store): transfers page renders delete entries"
```

---

### Task 10: Project-wide verification + PR

- [ ] **Step 1:** `dart format .` — no changes (else fix + amend).
- [ ] **Step 2:** `flutter analyze` — `No issues found!` (never pipe through
  tail/grep).
- [ ] **Step 3:** `flutter test test/features/media test/features/media_store test/core` — all pass.
- [ ] **Step 4:** `flutter test` (full suite) — all pass; known
  backup-family order flakes pass in isolation before any `--no-verify`.
- [ ] **Step 5:** Push (`git push --no-verify -u origin worktree-media-orphan-pr2`)
  and open a PR against `main` titled
  "feat(media-store): remote blob delete fast path". Body: the leak
  (deleted rows never delete cloud blobs; stranded multipart sessions),
  the intent-log design (enqueue-before-delete + drain-time refcount +
  single-enqueuer), the multipart abort rules, and the spec/plan paths.
  No attribution or session links.

---

## Not in this PR

- Dive-deletion cascade and orphan-row backlog sweep (PR 3 — must land
  AFTER this so cascaded deletions feed this plumbing).
- Verify Library sweep, `ListMultipartUploads` reaping, schema v136 (PR 4).
- Any change to sync tombstone application (single-enqueuer rule).
