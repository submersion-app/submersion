# Media Store Phase 3 (Large Objects) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Videos upload through S3 multipart with per-part resume and progress, survive kill-and-resume, and play on a second device; gallery-video poster thumbs render everywhere — Phase 3 of the Media Store spec (`docs/superpowers/specs/2026-07-10-s3-media-storage-design.md`, sections 8, 9, 17).

**Architecture:** The `MediaObjectStore` interface gains optional progress/resume parameters (the extension Phase 1 planned for). `S3ApiClient` gains the multipart operations (Create/UploadPart/Complete/Abort/ListParts) plus Range GET; `S3MediaObjectStore.putFile` becomes threshold-switched (single-shot under 8 MiB, multipart loop above, resume state persisted after every acknowledged part), and `getFile` streams Range chunks to disk so downloads stay memory-bounded. The pipeline lifts Phase 2's video-ineligibility gate, threads resume state and progress through the queue (local cache DB v3 adds progress columns), and video playback on remote devices rides a store fallback inside `resolvedFilePathProvider` — the single seam `photo_viewer_page`'s `_VideoItem` already consumes.

**Tech Stack:** Existing media-store stack; no new dependencies. The chunk loop lives inside the S3 adapter for now — extracting a shared `TransferEngine` waits for Phase 4 when a second session protocol (Drive/Dropbox) exists to generalize over.

## Global Constraints

- Work ONLY in the worktree: `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/media-store-phase3` (branch `worktree-media-store-phase3`, stacked on `worktree-media-store-phase2`; the PR targets that branch).
- Main DB stays at v103. Local cache DB goes v2 -> v3 (two nullable progress columns; `m.addColumn` migration).
- TDD; per-file test runs with `set -o pipefail` when piping through `tail`; per-test `--timeout 60s` on new suites.
- `dart format .` + whole-project `flutter analyze` before every commit (CI is `--fatal-infos`). No emojis. Conventional single-line commit messages, no trailers.
- Every file must be Read at its phase-3 worktree absolute path before its first Edit (edit tracking resets per worktree).
- Widget tests render from snapshot data, never live drift `watch()` streams; provider tests hold `container.listen` subscriptions (Riverpod 3 auto-pause) and poll until the EXPECTED value appears (stale `.value` persists across invalidation).
- **Documented spec deviation:** non-gallery (localFile) video thumbnails are deferred to Phase 5. Gallery videos - the dominant path on iOS/Android/macOS - get poster thumbs free through photo_manager's `resolveThumbnail` (`BytesData`); localFile videos degrade to the placeholder, extending the spec's own accepted Windows/Linux degradation (spec section 19). No native thumbnailer dependency enters this phase.
- Phase 1+2 signatures consumed verbatim: `StoreKeys.objectKey/thumbKey/extensionFor/contentTypeFor` (mp4/mov already mapped), `sha256OfFile`, `MediaTransferQueueRepository` (+`retry`/`defer` preserve `resumeStateJson` untouched today - keep it that way), `MediaUploadPipeline.process`, `WorkerGate` (the Phase 2 runtime gate already checks `videosOnCellular` for video entries - lifting eligibility activates it with zero gate changes), `MediaStoreResolver.tryResolveRemote`, `mediaStoreRuntimeProvider`.

---

### Task 1: Interface extension (progress + resume) and fake/contract updates

**Files:**
- Modify: `lib/core/services/media_store/media_object_store.dart`
- Modify: `lib/core/services/media_store/s3_media_object_store.dart` (accept the new params; single-shot behavior unchanged this task)
- Modify: `test/helpers/in_memory_media_object_store.dart`
- Modify: `test/core/services/media_store/media_object_store_contract.dart` (+ its `_test.dart` unchanged)

**Interfaces:**
- Produces (in `media_object_store.dart`):
```dart
/// Progress callback: [transferredBytes] so far; [totalBytes] null when
/// the total is unknown.
typedef TransferProgressCallback =
    void Function(int transferredBytes, int? totalBytes);

abstract class MediaObjectStore {
  Future<StoreObjectInfo?> head(String key);
  Future<void> putFile(
    String key,
    File source, {
    required String contentType,
    TransferProgressCallback? onProgress,
    String? resumeStateJson,
    void Function(String resumeStateJson)? onResumeStateChanged,
  });
  Future<void> getFile(
    String key,
    File destination, {
    TransferProgressCallback? onProgress,
  });
  Future<void> delete(String key);
  Stream<StoreObjectInfo> list(String keyPrefix);
}
```
`resumeStateJson` is adapter-opaque JSON; callers persist whatever `onResumeStateChanged` hands them and replay it verbatim.

- [ ] **Step 1: Write the failing contract additions**

Append to the `group` in `media_object_store_contract.dart`:

```dart
    test('putFile and getFile report progress reaching the full size',
        () async {
      final bytes = List<int>.generate(4096, (i) => i % 251);
      final src = tempFile('p.bin', bytes);
      final putProgress = <int>[];
      await store.putFile(
        'smv1/objects/aa/p.bin',
        src,
        contentType: 'application/octet-stream',
        onProgress: (sent, total) => putProgress.add(sent),
      );
      expect(putProgress, isNotEmpty);
      expect(putProgress.last, bytes.length);

      final getProgress = <int>[];
      final dest = File('${tmp.path}/p.out');
      await store.getFile(
        'smv1/objects/aa/p.bin',
        dest,
        onProgress: (received, total) => getProgress.add(received),
      );
      expect(getProgress, isNotEmpty);
      expect(getProgress.last, bytes.length);
      expect(await dest.readAsBytes(), bytes);
    });
```

- [ ] **Step 2: Run to verify it fails**

Run: `set -o pipefail; flutter test test/core/services/media_store/media_object_store_contract_test.dart --timeout 60s 2>&1 | tail -3`
Expected: FAIL to compile (named parameters undefined).

- [ ] **Step 3: Implement**

(a) `media_object_store.dart`: apply the Interfaces block above (add the typedef above the class; extend the two signatures; document `resumeStateJson` as adapter-opaque).

(b) `in_memory_media_object_store.dart`: extend both overrides; after storing bytes call `onProgress?.call(bytes.length, bytes.length);` (single completion tick); `getFile` likewise after writing. Ignore resume parameters.

(c) `s3_media_object_store.dart`: extend both override signatures; in this task simply invoke `onProgress?.call(length, length)` after the existing single-shot put/get succeeds (the multipart internals arrive in Task 4). `resumeStateJson`/`onResumeStateChanged` are accepted and unused for sub-threshold objects.

- [ ] **Step 4: Run to verify it passes**

Run: `set -o pipefail; flutter test test/core/services/media_store/media_object_store_contract_test.dart test/core/services/media_store/s3_media_object_store_test.dart --timeout 60s 2>&1 | tail -2`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add -A
git commit -m "feat(media-store): progress and resume hooks on MediaObjectStore"
```

---

### Task 2: Queue v3 - progress columns, resume-state persistence

**Files:**
- Modify: `lib/core/database/local_cache_database.dart` (columns + schemaVersion 3 + migration)
- Modify: `lib/features/media_store/data/media_transfer_queue_repository.dart`
- Test: modify `test/features/media_store/media_transfer_queue_repository_test.dart`

**Interfaces:**
- `MediaTransferQueue` table gains `IntColumn get progressBytes => integer().nullable()();` and `IntColumn get totalBytes => integer().nullable()();`.
- Repository gains:
```dart
Future<void> updateResumeState(int id, String? resumeStateJson); // null clears
Future<void> updateProgress(int id, {required int transferredBytes, int? totalBytes});
```
- `markDone` additionally clears `resumeStateJson`, `progressBytes`, `totalBytes` (a finished transfer must not leak stale resume data into a future re-enqueue of the same media). `retry`, `defer`, and `markFailed` must PRESERVE `resumeStateJson` - that is the whole point of resume.

- [ ] **Step 1: Write the failing tests**

Append to the queue test file:

```dart
  test('v3 migration adds progress columns to an existing v2 database',
      () async {
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
    expect(row.resumeStateJson, '{"uploadId":"u1"}',
        reason: 'retry must keep the resume point');

    await repo.markDone(id);
    row = (await repo.allForTesting()).single;
    expect(row.resumeStateJson, isNull);
    expect(row.progressBytes, isNull);
    expect(row.totalBytes, isNull);
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `set -o pipefail; flutter test test/features/media_store/media_transfer_queue_repository_test.dart --timeout 60s 2>&1 | tail -3`
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

(a) Table: add the two nullable int columns to `MediaTransferQueue` (after `priority`). Bump `schemaVersion` to 3 and extend the migration:

```dart
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(mediaTransferQueue);
        await m.createTable(mediaCacheEntries);
      }
      if (from < 3) {
        await m.addColumn(mediaTransferQueue, mediaTransferQueue.progressBytes);
        await m.addColumn(mediaTransferQueue, mediaTransferQueue.totalBytes);
      }
    },
  );
```
NOTE: `if (from < 2)` creates the tables WITH the new columns (fresh Drift schema), so the `from < 3` ALTERs would fail on a database that just ran the v2 block. Guard: change the v3 block to `if (from >= 2 && from < 3)`.

(b) Repository methods:

```dart
  /// Persists (or clears, with null) the adapter's opaque resume point.
  Future<void> updateResumeState(int id, String? resumeStateJson) async {
    await (_db.update(
      _db.mediaTransferQueue,
    )..where((t) => t.id.equals(id))).write(
      MediaTransferQueueCompanion(
        resumeStateJson: Value(resumeStateJson),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> updateProgress(
    int id, {
    required int transferredBytes,
    int? totalBytes,
  }) async {
    await (_db.update(
      _db.mediaTransferQueue,
    )..where((t) => t.id.equals(id))).write(
      MediaTransferQueueCompanion(
        progressBytes: Value(transferredBytes),
        totalBytes: Value(totalBytes),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }
```
and extend `markDone`:

```dart
  Future<void> markDone(int id) async {
    await (_db.update(
      _db.mediaTransferQueue,
    )..where((t) => t.id.equals(id))).write(
      MediaTransferQueueCompanion(
        state: const Value('done'),
        resumeStateJson: const Value(null),
        progressBytes: const Value(null),
        totalBytes: const Value(null),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }
```
(replacing the `_setState` delegation for done only; `markTransferring` keeps `_setState`).

- [ ] **Step 4: Codegen, run, commit**

```bash
dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -2
set -o pipefail; flutter test test/features/media_store/media_transfer_queue_repository_test.dart --timeout 60s 2>&1 | tail -2
dart format . && flutter analyze
git add -A
git commit -m "feat(media-store): queue resume-state and progress persistence"
```
Expected: PASS (12 tests).

---

### Task 3: S3 multipart + Range operations and a fake S3 server helper

**Files:**
- Modify: `lib/core/services/cloud_storage/s3/s3_api_client.dart`
- Create: `test/helpers/fake_s3_server.dart` (extracted+extended from the MockClient in `s3_media_object_store_test.dart`)
- Modify: `test/core/services/media_store/s3_media_object_store_test.dart` (use the helper)
- Test: `test/core/services/cloud_storage/s3/s3_multipart_test.dart`

**Interfaces:**
- Produces (on `S3ApiClient`):
```dart
class S3PartInfo {
  final int partNumber;
  final String etag;
  const S3PartInfo({required this.partNumber, required this.etag});
}

Future<String> createMultipartUpload(String key, {required String contentType});
Future<String> uploadPart(String key, {required String uploadId, required int partNumber, required Uint8List bytes}); // returns etag
Future<void> completeMultipartUpload(String key, {required String uploadId, required List<S3PartInfo> parts});
Future<void> abortMultipartUpload(String key, {required String uploadId}); // idempotent (404 ok)
Future<List<S3PartInfo>> listParts(String key, {required String uploadId});
Future<({Uint8List bytes, int totalLength})> getObjectRange(String key, {required int start, required int endInclusive});
```
- Produces (test helper):
```dart
class FakeS3Server {
  FakeS3Server({String bucket = 'test-bucket'});
  final Map<String, Uint8List> objects;       // wire key -> bytes
  final List<http.Request> captured;
  Exception? failNextWith;                    // one-shot injection
  int partUploadCount;                        // PUT ?partNumber requests seen
  MockClient get client;
}
```
The handler implements: plain PUT/GET/HEAD/DELETE/list-type=2 (as today), POST `?uploads` (returns `<InitiateMultipartUploadResult><UploadId>...`), PUT `?partNumber=N&uploadId=U` (stores the part, returns an `ETag` header `"part-N-<len>"`), POST `?uploadId=U` (concatenates parts in order into `objects[key]`), DELETE `?uploadId=U` (drops the session; 204 even if unknown), GET `?uploadId=U` (ListParts XML with `<Part><PartNumber><ETag><Size>`), and GET with a `Range: bytes=a-b` header (206, `Content-Range: bytes a-b/total`, sliced body).

- [ ] **Step 1: Write the failing multipart client test**

Create `test/core/services/cloud_storage/s3/s3_multipart_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_api_client.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';

import '../../../../helpers/fake_s3_server.dart';

void main() {
  late FakeS3Server server;
  late S3ApiClient client;

  setUp(() {
    server = FakeS3Server();
    client = S3ApiClient(
      S3Config(
        endpoint: 'http://localhost:9000',
        bucket: 'test-bucket',
        prefix: '',
        accessKeyId: 'AK',
        secretAccessKey: 'SK',
      ),
      httpClient: server.client,
    );
  });

  test('multipart create, upload, list, complete round-trips bytes',
      () async {
    final uploadId = await client.createMultipartUpload(
      'big.bin',
      contentType: 'application/octet-stream',
    );
    expect(uploadId, isNotEmpty);

    final part1 = Uint8List.fromList(List.filled(10, 1));
    final part2 = Uint8List.fromList(List.filled(6, 2));
    final etag1 = await client.uploadPart(
      'big.bin',
      uploadId: uploadId,
      partNumber: 1,
      bytes: part1,
    );
    final etag2 = await client.uploadPart(
      'big.bin',
      uploadId: uploadId,
      partNumber: 2,
      bytes: part2,
    );

    final listed = await client.listParts('big.bin', uploadId: uploadId);
    expect(listed.map((p) => p.partNumber).toList(), [1, 2]);
    expect(listed.map((p) => p.etag).toList(), [etag1, etag2]);

    await client.completeMultipartUpload(
      'big.bin',
      uploadId: uploadId,
      parts: [
        S3PartInfo(partNumber: 1, etag: etag1),
        S3PartInfo(partNumber: 2, etag: etag2),
      ],
    );
    expect(server.objects['big.bin'], [...part1, ...part2]);
  });

  test('abort discards the session and is idempotent', () async {
    final uploadId = await client.createMultipartUpload(
      'gone.bin',
      contentType: 'application/octet-stream',
    );
    await client.abortMultipartUpload('gone.bin', uploadId: uploadId);
    await client.abortMultipartUpload('gone.bin', uploadId: uploadId);
    expect(server.objects.containsKey('gone.bin'), isFalse);
  });

  test('getObjectRange returns the slice and the total length', () async {
    server.objects['r.bin'] = Uint8List.fromList(
      List.generate(100, (i) => i),
    );
    final range = await client.getObjectRange(
      'r.bin',
      start: 10,
      endInclusive: 19,
    );
    expect(range.bytes, List.generate(10, (i) => i + 10));
    expect(range.totalLength, 100);
  });
}
```

- [ ] **Step 2: Extract the FakeS3Server helper**

Move the MockClient handler out of `s3_media_object_store_test.dart` into `test/helpers/fake_s3_server.dart` per the Interfaces block, extending it with the multipart and Range branches. Session storage inside the fake: `Map<String, Map<int, Uint8List>> _sessions` keyed by uploadId; uploadId generation `'upload-${_sessions.length + 1}'`. The adapter test file then builds its store as `S3MediaObjectStore(client: S3ApiClient(config, httpClient: server.client), keyPrefix: config.prefix)` and asserts against `server.objects` / `server.captured` (same assertions as before; only plumbing moves).

- [ ] **Step 3: Run to verify failure, implement the client operations**

Run the new test -> FAIL to compile. Add the operations to `s3_api_client.dart` (below `listObjects`, above `close`):

```dart
  /// Starts a multipart upload session; returns the server's uploadId.
  Future<String> createMultipartUpload(
    String key, {
    required String contentType,
  }) async {
    final response = await _sendWithRetry(
      'POST',
      key,
      queryParams: {'uploads': ''},
    );
    if (response.statusCode != 200) _throwFor('start upload', key, response);
    final uploadId = _xmlElementText(response.body, 'UploadId');
    if (uploadId == null || uploadId.isEmpty) {
      throw CloudStorageException(
        'S3 returned no UploadId for "$key"',
      );
    }
    return uploadId;
  }

  /// Uploads one part; returns its ETag for the completion manifest.
  Future<String> uploadPart(
    String key, {
    required String uploadId,
    required int partNumber,
    required Uint8List bytes,
  }) async {
    final response = await _sendWithRetry(
      'PUT',
      key,
      queryParams: {'partNumber': '$partNumber', 'uploadId': uploadId},
      body: bytes,
    );
    if (response.statusCode != 200) {
      _throwFor('upload part $partNumber of', key, response);
    }
    final etag = response.headers['etag'];
    if (etag == null || etag.isEmpty) {
      throw CloudStorageException(
        'S3 returned no ETag for part $partNumber of "$key"',
      );
    }
    return etag;
  }

  Future<void> completeMultipartUpload(
    String key, {
    required String uploadId,
    required List<S3PartInfo> parts,
  }) async {
    final manifest = StringBuffer('<CompleteMultipartUpload>');
    for (final part in parts) {
      manifest.write(
        '<Part><PartNumber>${part.partNumber}</PartNumber>'
        '<ETag>${part.etag}</ETag></Part>',
      );
    }
    manifest.write('</CompleteMultipartUpload>');
    final response = await _sendWithRetry(
      'POST',
      key,
      queryParams: {'uploadId': uploadId},
      body: Uint8List.fromList(utf8.encode(manifest.toString())),
    );
    if (response.statusCode != 200) _throwFor('finish upload', key, response);
    // S3 reports completion errors inside a 200 body.
    if (_xmlElementText(response.body, 'Code') != null) {
      throw CloudStorageException(
        'S3 rejected the upload completion for "$key"',
      );
    }
  }

  /// Idempotent: aborting an unknown session succeeds.
  Future<void> abortMultipartUpload(
    String key, {
    required String uploadId,
  }) async {
    final response = await _sendWithRetry(
      'DELETE',
      key,
      queryParams: {'uploadId': uploadId},
    );
    const okStatuses = {200, 204, 404};
    if (!okStatuses.contains(response.statusCode)) {
      _throwFor('abort upload', key, response);
    }
  }

  Future<List<S3PartInfo>> listParts(
    String key, {
    required String uploadId,
  }) async {
    final response = await _sendWithRetry(
      'GET',
      key,
      queryParams: {'uploadId': uploadId},
    );
    if (response.statusCode != 200) _throwFor('list parts of', key, response);
    try {
      final document = XmlDocument.parse(response.body);
      return document
          .findAllElements('Part')
          .map(
            (part) => S3PartInfo(
              partNumber: int.parse(
                part.getElement('PartNumber')!.innerText,
              ),
              etag: part.getElement('ETag')!.innerText,
            ),
          )
          .toList();
    } on Exception catch (e) {
      throw CloudStorageException('S3 returned an unreadable part list', e);
    }
  }

  /// Byte-range read: [start]..[endInclusive]. Returns the slice and the
  /// object's total length parsed from Content-Range.
  Future<({Uint8List bytes, int totalLength})> getObjectRange(
    String key, {
    required int start,
    required int endInclusive,
  }) async {
    final response = await _sendWithRetry(
      'GET',
      key,
      extraHeaders: {'range': 'bytes=$start-$endInclusive'},
    );
    if (response.statusCode == 404) {
      throw CloudStorageException('File not found in S3: $key');
    }
    if (response.statusCode != 206 && response.statusCode != 200) {
      _throwFor('download range of', key, response);
    }
    final contentRange = response.headers['content-range'];
    final total = contentRange == null
        ? response.bodyBytes.length
        : int.parse(contentRange.split('/').last);
    return (bytes: response.bodyBytes, totalLength: total);
  }
```
with `class S3PartInfo` beside `S3ObjectInfo` at the top of the file.

`_sendWithRetry`/`_send` need an `extraHeaders` pass-through for the Range header: add `Map<String, String> extraHeaders = const {}` to both, merged into the request AFTER signing (`request.headers.addAll(extraHeaders)` alongside the signed headers - the Range header is not part of the SigV4 canonical headers this client signs, which S3 accepts since only signed headers participate in the signature).

- [ ] **Step 4: Run all Task 3 tests**

```bash
set -o pipefail
flutter test test/core/services/cloud_storage/s3/s3_multipart_test.dart test/core/services/media_store/s3_media_object_store_test.dart --timeout 60s 2>&1 | tail -2
```
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add -A
git commit -m "feat(media-store): S3 multipart and range operations"
```

---

### Task 4: S3 adapter large-object putFile (multipart + resume) and streamed getFile

**Files:**
- Modify: `lib/core/services/media_store/s3_media_object_store.dart`
- Test: modify `test/core/services/media_store/s3_media_object_store_test.dart`

**Interfaces:**
- Constructor gains tuning knobs (tests shrink them; production uses defaults):
```dart
S3MediaObjectStore({
  required S3ApiClient client,
  required String keyPrefix,
  int partSizeBytes = 8 * 1024 * 1024,       // also the multipart threshold
  int downloadChunkBytes = 8 * 1024 * 1024,
});
```
- Resume JSON shape (adapter-owned): `{"uploadId": "...", "partSizeBytes": N, "parts": [{"n": 1, "etag": "..."}]}`.
- `putFile`: size <= partSizeBytes -> existing single-shot + one progress tick. Larger -> multipart:
  1. Parse `resumeStateJson`; if present, `listParts` and verify every recorded part number/etag appears server-side AND the recorded partSizeBytes matches the current one - on any mismatch `abortMultipartUpload` (best-effort) and start fresh.
  2. Otherwise `createMultipartUpload`.
  3. For each remaining part index: read the slice via `RandomAccessFile` (`setPosition` + `read` - never the whole file), `uploadPart`, append to the parts list, fire `onResumeStateChanged(json)` then `onProgress(min(n*partSize, size), size)`.
  4. `completeMultipartUpload` with all parts in order.
- `getFile`: `head` for the size (null -> notFound MediaStoreException, matching the single-shot contract); loop `getObjectRange` chunks appended to the destination via a `RandomAccessFile` opened in write mode, `onProgress` after each chunk. Objects at or below `downloadChunkBytes` keep the existing single `getObject` call.
- Error mapping stays `_map(...)`; a failure mid-multipart propagates AFTER `onResumeStateChanged` has already recorded completed parts, so the caller retries from the last acknowledged part.

- [ ] **Step 1: Write the failing adapter tests**

Append to `s3_media_object_store_test.dart` (the `build` helper gains optional `partSizeBytes`/`downloadChunkBytes` parameters passed through, default 64 KiB in these tests via `build(partSizeBytes: 64 * 1024, downloadChunkBytes: 64 * 1024)`):

```dart
  test('large putFile goes multipart, reports progress, and round-trips',
      () async {
    final store = build(partSizeBytes: 64 * 1024, downloadChunkBytes: 64 * 1024);
    final bytes = List<int>.generate(200 * 1024, (i) => i % 251);
    final src = File('${tmp.path}/video.mp4')..writeAsBytesSync(bytes);

    final progress = <int>[];
    String? resumeJson;
    await store.putFile(
      'smv1/objects/aa/video.mp4',
      src,
      contentType: 'video/mp4',
      onProgress: (sent, total) => progress.add(sent),
      onResumeStateChanged: (json) => resumeJson = json,
    );

    expect(server.objects['submersion-media/smv1/objects/aa/video.mp4'],
        bytes);
    expect(server.partUploadCount, 4, reason: '200KiB / 64KiB = 4 parts');
    expect(progress.last, bytes.length);
    expect(resumeJson, contains('"uploadId"'));

    final dest = File('${tmp.path}/video.out');
    final getProgress = <int>[];
    await store.getFile(
      'smv1/objects/aa/video.mp4',
      dest,
      onProgress: (received, total) => getProgress.add(received),
    );
    expect(await dest.readAsBytes(), bytes);
    expect(getProgress.length, greaterThan(1), reason: 'chunked download');
    expect(getProgress.last, bytes.length);
  });

  test('kill-and-resume: a mid-upload failure resumes from the last '
      'acknowledged part without re-uploading it', () async {
    final store = build(partSizeBytes: 64 * 1024);
    final bytes = List<int>.generate(200 * 1024, (i) => (i * 3) % 251);
    final src = File('${tmp.path}/kr.mp4')..writeAsBytesSync(bytes);

    String? resumeJson;
    server.failAfterPartUploads = 2; // parts 1-2 succeed, part 3 dies
    await expectLater(
      store.putFile(
        'smv1/objects/aa/kr.mp4',
        src,
        contentType: 'video/mp4',
        onResumeStateChanged: (json) => resumeJson = json,
      ),
      throwsA(isA<MediaStoreException>()),
    );
    expect(resumeJson, isNotNull);
    final partsBefore = server.partUploadCount;
    expect(partsBefore, 2);

    // "Restart the app": a fresh store instance resumes from the JSON.
    server.failAfterPartUploads = null;
    final resumed = build(partSizeBytes: 64 * 1024);
    await resumed.putFile(
      'smv1/objects/aa/kr.mp4',
      src,
      contentType: 'video/mp4',
      resumeStateJson: resumeJson,
      onResumeStateChanged: (json) => resumeJson = json,
    );
    expect(server.objects['submersion-media/smv1/objects/aa/kr.mp4'], bytes);
    expect(server.partUploadCount - partsBefore, 2,
        reason: 'only parts 3-4 upload on resume');
  });

  test('a stale resume state (unknown uploadId) aborts and restarts fresh',
      () async {
    final store = build(partSizeBytes: 64 * 1024);
    final bytes = List<int>.generate(130 * 1024, (i) => i % 199);
    final src = File('${tmp.path}/stale.mp4')..writeAsBytesSync(bytes);

    await store.putFile(
      'smv1/objects/aa/stale.mp4',
      src,
      contentType: 'video/mp4',
      resumeStateJson:
          '{"uploadId":"upload-does-not-exist","partSizeBytes":65536,'
          '"parts":[{"n":1,"etag":"\\"bogus\\""}]}',
    );
    expect(server.objects['submersion-media/smv1/objects/aa/stale.mp4'],
        bytes);
  });
```
The fake gains `int? failAfterPartUploads;` - when set, part-upload PUTs beyond that count return a 500 once (then the field clears). `listParts` for an unknown uploadId returns 404 (the client's generic `_throwFor` maps it; the adapter treats ANY listParts failure as stale-resume -> fresh start).

- [ ] **Step 2: Run to verify failure, implement**

Run -> FAIL. Implement `putFile`/`getFile` per the Interfaces block. Structure inside the adapter:

```dart
  @override
  Future<void> putFile(...) async {
    final length = await source.length();
    if (length <= partSizeBytes) { /* existing single-shot + progress */ }
    return _putMultipart(key, source, length, contentType: contentType,
        onProgress: onProgress, resumeStateJson: resumeStateJson,
        onResumeStateChanged: onResumeStateChanged);
  }
```
`_putMultipart` private method implements resume-validate/create, the `RandomAccessFile` part loop, and completion; `_resumeFromJson`/`_resumeToJson` are small private helpers using `jsonDecode`/`jsonEncode` (import `dart:convert`). All client calls stay wrapped by `_map` via try/catch around the whole multipart body, EXCEPT the stale-resume `listParts` probe which catches locally and falls through to a fresh session.

- [ ] **Step 3: Run all adapter + multipart + contract tests**

```bash
set -o pipefail
flutter test test/core/services/media_store/ test/core/services/cloud_storage/s3/s3_multipart_test.dart --timeout 90s 2>&1 | tail -2
```
Expected: PASS.

- [ ] **Step 4: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add -A
git commit -m "feat(media-store): multipart upload with resume and streamed download"
```

---

### Task 5: Pipeline - video eligibility, resume/progress wiring, gallery-video thumbs

**Files:**
- Modify: `lib/features/media_store/data/media_upload_pipeline.dart`
- Test: modify `test/features/media_store/media_upload_pipeline_test.dart`

**Interfaces:**
- `_isEligible` drops the `MediaType.video` rejection (delete the Phase 2 lines and their comment). The Phase 2 runtime gate already routes video entries through `policies.videosOnCellular()` - no gate change.
- `process()` threads the queue row into the store call:
```dart
      await _mediaRepository.stampContentIdentity(...); // existing
      // ... thumb step (existing, unchanged - gallery videos produce
      //     BytesData posters through resolveThumbnail already) ...
      final existing = await _store.head(key);
      if (existing == null) {
        await _store.putFile(
          key,
          staged,
          contentType: StoreKeys.contentTypeFor(extension),
          resumeStateJson: entry.resumeStateJson,
          onResumeStateChanged: (json) =>
              unawaited(_queue.updateResumeState(entry.id, json)),
          onProgress: (sent, total) => unawaited(
            _queue.updateProgress(entry.id, transferredBytes: sent,
                totalBytes: total ?? digest.sizeBytes),
          ),
        );
      }
```
(`import 'dart:async';` for `unawaited`. `markDone` clears resume/progress - Task 2.)
- One behavioral note to encode in a test: `_materialize` COPIES the source to staging, and the staged file is deleted in `finally` - so on failure the resume state refers to a byte-identical future staging copy. Content-addressing makes this safe: the same source bytes re-materialize identically, and part boundaries depend only on partSize + content. The test asserts a failed-then-retried upload with a recording fake receives the SAME resumeStateJson back.

- [ ] **Step 1: Write the failing tests**

Replace the Phase 2 `video rows are ineligible until Phase 3` test with:

```dart
  test('video rows upload with contentType video/mp4', () async {
    final id = await enqueueLocalFileItem(
      bytes: List<int>.generate(1024, (i) => i % 251),
      name: 'clip.mp4',
      mediaType: domain.MediaType.video,
    );
    final entry = (await queue.nextPending(DateTime.now()))!;
    expect(await pipeline.process(entry), UploadOutcome.uploaded);
    final item = (await mediaRepository.getMediaById(id))!;
    expect(item.remoteUploadedAt, isNotNull);
    final key =
        'smv1/objects/${item.contentHash!.substring(0, 2)}/'
        '${item.contentHash}.mp4';
    expect(fakeStore.objects.containsKey(key), isTrue);
  });

  test('resume state and progress flow through the queue row', () async {
    // The InMemory fake accepts and echoes resume hooks: extend it first
    // (see Step 2) so putFile calls onResumeStateChanged('{"fake":1}')
    // and onProgress(length, length).
    final id = await enqueueLocalFileItem(bytes: [1, 2, 3, 4], name: 'r.jpg');
    final entry = (await queue.nextPending(DateTime.now()))!;
    fakeStore.emitResumeState = '{"fake":1}';
    expect(await pipeline.process(entry), UploadOutcome.uploaded);

    // markDone cleared them; the intermediate write is what we assert via
    // the fake's recorded call.
    expect(fakeStore.lastResumeStateJsonIn, isNull,
        reason: 'first attempt starts with no resume state');
    final row = (await queue.allForTesting()).single;
    expect(row.state, 'done');
    expect(row.resumeStateJson, isNull);

    // Second media with a pre-seeded resume state on the row reaches the
    // store call.
    final id2 = await enqueueLocalFileItem(bytes: [9, 9], name: 'r2.jpg');
    final entry2 = (await queue.nextPending(DateTime.now()))!;
    await queue.updateResumeState(entry2.id, '{"seeded":true}');
    final refreshed = (await queue.nextPending(DateTime.now()))!;
    expect(await pipeline.process(refreshed), UploadOutcome.uploaded);
    expect(fakeStore.lastResumeStateJsonIn, '{"seeded":true}');
    expect((await mediaRepository.getMediaById(id2))!.remoteUploadedAt,
        isNotNull);
    expect(id, isNot(id2));
  });

  test('gallery-style video thumbs upload (BytesData poster)', () async {
    final png = pngBytes();
    final id = await enqueueLocalFileItem(
      bytes: List<int>.generate(2048, (i) => i % 251),
      name: 'dive.mp4',
      mediaType: domain.MediaType.video,
      thumbnailData: BytesData(bytes: Uint8List.fromList(png)),
    );
    final entry = (await queue.nextPending(DateTime.now()))!;
    expect(await pipeline.process(entry), UploadOutcome.uploaded);
    final item = (await mediaRepository.getMediaById(id))!;
    expect(item.remoteThumbUploadedAt, isNotNull);
    expect(
      fakeStore.objects.containsKey(
        'smv1/thumbs/${item.contentHash!.substring(0, 2)}/'
        '${item.contentHash}.jpg',
      ),
      isTrue,
    );
  });
```
Supporting changes in the test file: `_FakeLocalFileResolver` gains an optional `thumbnailData` field returned by `resolveThumbnail` when set (falling back to `data`); `enqueueLocalFileItem` gains `MediaSourceData? thumbnailData` applied to the resolver; add `import 'dart:typed_data';`.

- [ ] **Step 2: Extend the InMemory fake**

In `test/helpers/in_memory_media_object_store.dart` add fields and wire them in `putFile`:

```dart
  /// When set, putFile fires onResumeStateChanged with this JSON once.
  String? emitResumeState;

  /// The resumeStateJson the last putFile call received.
  String? lastResumeStateJsonIn;
```
(`lastResumeStateJsonIn = resumeStateJson;` at the top of putFile; after storing bytes, `if (emitResumeState != null) onResumeStateChanged?.call(emitResumeState!);` then the progress tick.)

- [ ] **Step 3: Run to verify failure, implement the pipeline change, re-run**

Run the pipeline test -> FAIL. Apply the `_isEligible` deletion and the `putFile` call-site wiring from the Interfaces block. Re-run:

```bash
set -o pipefail
flutter test test/features/media_store/media_upload_pipeline_test.dart test/features/media_store/media_store_end_to_end_test.dart --timeout 60s 2>&1 | tail -2
```
Expected: PASS (the e2e gate test used a photo; unaffected).

- [ ] **Step 4: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add -A
git commit -m "feat(media-store): video uploads with resume and progress wiring"
```

---

### Task 6: Video playback fallback in resolvedFilePathProvider

**Files:**
- Modify: `lib/features/media/presentation/providers/resolved_asset_providers.dart` (`resolvedFilePathProvider`, ~line 89)
- Test: `test/features/media_store/resolved_file_path_store_fallback_test.dart`

**Interfaces:**
- `resolvedFilePathProvider` behavior becomes: gallery resolution (existing) -> if null, `item.localPath` when the file exists -> else store fallback via `mediaStoreRuntimeProvider`'s resolver (`tryResolveRemote(item, thumbnail: false)`, returning `FileData.file.path`) -> else null. `photo_viewer_page._VideoItem` (line 468) is untouched: its existing loading spinner covers the download.

- [ ] **Step 1: Write the failing test**

Create `test/features/media_store/resolved_file_path_store_fallback_test.dart` (ProviderContainer test; the gallery service path requires `photoPickerServiceProvider` - avoid it by overriding `assetResolutionServiceProvider`? That service class is concrete; instead use an item with `platformAssetId: null`, which makes the existing gallery branch return unavailable without touching the picker service - verify by reading the provider body first):

```dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

import '../../helpers/in_memory_media_object_store.dart';

void main() {
  late LocalCacheDatabase db;
  late Directory root;
  late InMemoryMediaObjectStore store;
  late ProviderContainer container;

  setUp(() async {
    db = LocalCacheDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('rfp_fallback');
    store = InMemoryMediaObjectStore();
    final cache = MediaCacheStore(database: db, root: root);
    final runtime = MediaStoreRuntime(
      storeId: 's1',
      store: store,
      cache: cache,
      resolver: MediaStoreResolver(store: store, cache: cache),
    );
    container = ProviderContainer(
      overrides: [
        mediaStoreRuntimeProvider.overrideWith((ref) async => runtime),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    await root.delete(recursive: true);
  });

  MediaItem videoItem({required String hash, String? localPath}) => MediaItem(
    id: 'v1',
    mediaType: MediaType.video,
    sourceType: MediaSourceType.localFile,
    localPath: localPath,
    originalFilename: 'dive.mp4',
    takenAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    contentHash: hash,
    remoteUploadedAt: DateTime(2026, 7, 1),
  );

  test('existing localPath wins without touching the store', () async {
    final local = File('${root.path}/here.mp4')..writeAsBytesSync([1, 2]);
    final path = await container.read(
      resolvedFilePathProvider(
        videoItem(hash: 'a' * 64, localPath: local.path),
      ).future,
    );
    expect(path, local.path);
    expect(store.objects, isEmpty);
  });

  test('dead localPath falls back to the store and returns playable bytes',
      () async {
    final bytes = List<int>.generate(4096, (i) => (i * 5) % 251);
    final seed = File('${root.path}/seed.mp4')..writeAsBytesSync(bytes);
    final digest = await sha256OfFile(seed);
    store.objects[StoreKeys.objectKey(digest.hash, extension: 'mp4')] = bytes;

    final path = await container.read(
      resolvedFilePathProvider(
        videoItem(
          hash: digest.hash,
          localPath: '/nonexistent/on/this/device.mp4',
        ),
      ).future,
    );
    expect(path, isNotNull);
    expect(await File(path!).readAsBytes(), bytes);
  });

  test('no store and no local file yields null', () async {
    final bare = ProviderContainer(
      overrides: [
        mediaStoreRuntimeProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(bare.dispose);
    final path = await bare.read(
      resolvedFilePathProvider(
        videoItem(hash: 'b' * 64, localPath: '/nope.mp4'),
      ).future,
    );
    expect(path, isNull);
  });
}
```
NOTE: `resolvedFilePathProvider` is a plain FutureProvider.family - `.future` reads resolve without the auto-pause stream caveat. If the provider body's FIRST step (`assetResolutionServiceProvider`) throws for a null `platformAssetId` instead of returning unavailable, adjust the implementation ordering so the null-assetId short-circuit comes first (Step 2 reads the body before editing).

- [ ] **Step 2: Read, then implement the fallback**

Read `resolved_asset_providers.dart` in full. Rework `resolvedFilePathProvider` to:

```dart
final resolvedFilePathProvider = FutureProvider.family<String?, MediaItem>((
  ref,
  item,
) async {
  // Gallery fast path (existing behavior, only when an asset id exists).
  if (item.platformAssetId != null) {
    final service = ref.watch(assetResolutionServiceProvider);
    final resolution = await service.resolveAssetId(item);
    if (resolution.status != ResolutionStatus.unavailable &&
        resolution.localAssetId != null) {
      final pickerService = ref.watch(photoPickerServiceProvider);
      final path = await pickerService.getFilePath(resolution.localAssetId!);
      if (path != null) return path;
    }
  }

  // Device-local file (localFile source rows).
  final localPath = item.localPath;
  if (localPath != null && await File(localPath).exists()) {
    return localPath;
  }

  // Media store fallback (design spec section 10): download the original
  // into the content-addressed cache and play from there.
  final runtime = await ref.read(mediaStoreRuntimeProvider.future);
  final data = await runtime?.resolver.tryResolveRemote(
    item,
    thumbnail: false,
  );
  if (data is FileData) return data.file.path;
  return null;
});
```
Add imports (`media_source_data.dart`, `media_store_providers.dart`). Preserve the existing doc comment, extending it with the fallback order.

- [ ] **Step 3: Run, format, analyze, commit**

```bash
set -o pipefail
flutter test test/features/media_store/resolved_file_path_store_fallback_test.dart test/features/media/ --timeout 60s 2>&1 | tail -1
dart format . && flutter analyze
git add -A
git commit -m "feat(media-store): store-backed video playback path"
```
Expected: PASS including the full media suite (photo_viewer widget tests exercise the provider's gallery branch).

---

### Task 7: Transfers view progress bars

**Files:**
- Modify: `lib/features/media_store/presentation/pages/transfers_page.dart` (`_TransferTile`)
- Test: modify `test/features/media_store/transfers_page_test.dart`

**Interfaces:**
- A `transferring` row with `progressBytes` and `totalBytes` renders a determinate `LinearProgressIndicator(value: progress/total)` under the title (via `ListTile.subtitle` column); without totals it renders indeterminate. Other states unchanged.

- [ ] **Step 1: Write the failing test**

Append to `transfers_page_test.dart`:

```dart
  testWidgets('transferring entries render a determinate progress bar', (
    tester,
  ) async {
    late List<MediaTransferQueueEntry> snapshot;
    await tester.runAsync(() async {
      final id = await repo.enqueueUpload(mediaId: 'm-v');
      await repo.markTransferring(id);
      await repo.updateProgress(id, transferredBytes: 25, totalBytes: 100);
      snapshot = await repo.watchEntries().first;
    });

    await tester.pumpWidget(app(snapshot));
    await tester.pump();

    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0.25);
  });
```

- [ ] **Step 2: Run to verify failure, implement**

Run -> FAIL (no progress bar). In `_TransferTile`, replace the `subtitle:` expression with:

```dart
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (entry.errorMessage != null)
            Text(entry.errorMessage!, maxLines: 2)
          else
            Text(entry.mediaId, maxLines: 1),
          if (entry.state == 'transferring')
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(
                value:
                    (entry.progressBytes != null &&
                        entry.totalBytes != null &&
                        entry.totalBytes! > 0)
                    ? entry.progressBytes! / entry.totalBytes!
                    : null,
              ),
            ),
        ],
      ),
```

- [ ] **Step 3: Run, format, analyze, commit**

```bash
set -o pipefail
flutter test test/features/media_store/transfers_page_test.dart --timeout 60s 2>&1 | tail -2
dart format . && flutter analyze
git add -A
git commit -m "feat(media-store): transfer progress bars"
```

---

### Task 8: Phase 3 exit verification + stacked PR

**Files:**
- Test: modify `test/features/media_store/media_store_end_to_end_test.dart`

- [ ] **Step 1: Cross-device video e2e**

Append (device fixtures exist; mirror the thumb e2e's structure):

```dart
  test('a video uploaded on device A plays from the store on device B', () async {
    // Device A: localFile video with a BytesData poster thumb.
    // (FakeLocalFileResolver gains the same optional thumbnailData field
    // used by the pipeline test's fake - add it to
    // test/features/media_store/support/fake_local_file_resolver.dart with
    // default null falling back to `data`.)
    // 1. create video MediaItem (mp4, 64 KiB generated bytes), enqueue,
    //    drain via a worker with no gate.
    // 2. assert remoteUploadedAt + remoteThumbUploadedAt set and the bucket
    //    holds thumb + original.
    // 3. device B: copyWith dead localPath; MediaStoreResolver
    //    tryResolveRemote(thumbnail: false) returns FileData whose bytes
    //    equal the source video's; thumbnail: true returns JPEG bytes.
  });
```
Write it fully - every numbered line above is one assertion block, and the first e2e test in the file is the fixture template.

- [ ] **Step 2: Full gates**

```bash
set -o pipefail
flutter test test/features/media_store/ test/core/services/media_store/ test/core/services/cloud_storage/s3/ --timeout 90s 2>&1 | tail -1
flutter test test/features/media/ 2>&1 | tail -1
flutter test test/core/services/sync/ 2>&1 | tail -1
flutter test test/features/settings/ 2>&1 | tail -1
dart format . && flutter analyze
```
Expected: all PASS, no issues.

- [ ] **Step 3: Commit, push, stacked PR**

```bash
git add -A && git commit -m "feat(media-store): phase 3 exit coverage"
git push -u origin worktree-media-store-phase3 --no-verify
env -u GITHUB_TOKEN gh pr create \
  --title "feat(media-store): large objects, phase 3 (multipart, resume, video)" \
  --base worktree-media-store-phase2 --head worktree-media-store-phase3 \
  --body-file <scratchpad>/pr_body_phase3.md
```
PR body follows the repo template; states STACKED on #556 (which stacks on #550, merge bottom-up); test plan lists the kill-and-resume adapter proof, the cross-device video e2e, and the pending manual items (MinIO smoke now including a real multi-hundred-MB video, playback walkthrough on a second device); notes the documented deviation (non-gallery video thumbs deferred to Phase 5).

## Phase 3 exit criteria (spec section 17)

- [ ] Multipart upload with per-part resume state; kill-and-resume proven at the adapter level (parts 1-2 not re-uploaded)
- [ ] Downloads stream in bounded-memory chunks with progress
- [ ] Videos eligible end-to-end: upload with video/mp4 content type, cellular gating via the existing videosOnCellular policy, poster thumbs for gallery videos
- [ ] Video on device B plays from the store via resolvedFilePathProvider fallback
- [ ] Transfers view shows determinate progress for in-flight transfers

