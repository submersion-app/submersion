# Media Store Phase 4 (Backends) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The media store works on all four backends - Dropbox, Google Drive, and iCloud join S3, each with single-shot AND resumable large-file transfers behind the same `MediaObjectStore` contract, selectable from a provider chooser on the Media Storage page - Phase 4 of the Media Store spec (`docs/superpowers/specs/2026-07-10-s3-media-storage-design.md`, sections 8.2, 13, 14, 17).

**Architecture:** Three new adapters, each using its service's native shape. Dropbox is path-native: keys map to `/submersion-media/<key>` in the app folder, and the existing `DropboxApiClient`'s in-memory session upload is refactored into public file-drivable primitives (`start/append/finish`) plus Range downloads; resume state is `{sessionId, offset}`. Google Drive gets a raw-REST adapter over the sync provider's authenticated `AuthClient`: one `submersion-media` folder in `appDataFolder`, file NAME = full store key, ALL uploads via resumable sessions (one code path), resume via the `Content-Range: bytes */total` probe, downloads via Range. iCloud is a filesystem adapter over the ubiquity container (`<container>/submersion-media/<key>`): small writes via the native `writeFile`, large files via `moveFile` (OS-coordinated), reads via `downloadIfNeeded`, resume OS-managed - behind an injectable `ICloudMediaPlatform` so tests run against a temp directory. Attach state gains a provider type; the runtime builds the right adapter; `MediaStoreService` gains per-provider connect flows; the settings page gains the chooser.

**Tech Stack:** Existing stack; no new dependencies. New MockClient protocol fakes: `FakeDropboxServer`, `FakeDriveServer` (siblings of Phase 3's `FakeS3Server`).

## Global Constraints

- Work ONLY in the worktree: `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/media-store-phase4` (branch `worktree-media-store-phase4`, stacked on `worktree-media-store-phase3`; the PR targets that branch).
- No schema changes (main v103, local cache v3). Attach state grows one SharedPreferences key.
- TDD; `set -o pipefail` on piped test runs; `--timeout 60s`+ on new suites; Read every file at this worktree's absolute path before its first Edit; format + whole-project analyze (`--fatal-infos` in CI) before every commit; no emojis; conventional single-line commits without trailers; new strings into all 11 arb files.
- Fault-injection fakes must out-stubborn retry policies: `DropboxApiClient` retries 401 once and 429 once; a generic 500 is NOT retried by it (unlike `S3ApiClient`), so one-shot 500 injection works for Dropbox; the Drive adapter's raw REST has NO retry layer (the adapter surfaces errors to the queue's backoff), so one-shot injection works there too.
- The shared behavioral contract (`test/core/services/media_store/media_object_store_contract.dart`) runs against every new adapter's fake-backed instance - that IS the "Phase 1 criteria on all four backends" proof; the per-adapter kill-resume tests are the Phase 3 criteria proof.
- iCloud honesty (spec sections 8.2, 19): resume/progress are OS-managed; the adapter reports a single completion progress tick, and kill-resume is N/A at the adapter level (documented in the PR). iCloud is gated to iOS/macOS via the existing `ICloudNativeService.getAvailability()`.
- Phase 1-3 pieces consumed verbatim: `MediaObjectStore` (with Phase 3's progress/resume parameters), `StoreKeys`, `StoreMarkerStore.ensure/read`, `MediaStoreAttachState`, `MediaStoreService` + providers in `media_store_providers.dart`, `MediaStoresRepository.upsertActive`, contract runner `runMediaObjectStoreContract(name, build)`, `CloudProviderType` enum (`lib/core/data/repositories/sync_repository.dart:14`: icloud/googledrive/s3/dropbox), Dropbox singletons (`DropboxAuthManager`, `DropboxApiClient` callback wiring per `dropbox_storage_provider.dart:31-37`), `GoogleDriveStorageProvider` internals (`_authClient`/`_allowSilentAuth`, google_drive_storage_provider.dart:23-30), `ICloudNativeService` statics, `isApplePlatformProvider` (sync_providers.dart).

---

### Task 1: Dropbox client - public session primitives, Range download, recursive list

**Files:**
- Modify: `lib/core/services/cloud_storage/dropbox/dropbox_api_client.dart`
- Create: `test/helpers/fake_dropbox_server.dart`
- Test: `test/core/services/cloud_storage/dropbox/dropbox_api_client_sessions_test.dart`

**Interfaces:**
- Produces (on `DropboxApiClient`):
```dart
Future<String> uploadSessionStart(Uint8List firstChunk); // returns session_id
Future<void> uploadSessionAppend({required String sessionId, required int offset, required Uint8List chunk});
Future<DropboxFileMetadata> uploadSessionFinish({required String sessionId, required int offset, required String path, required Uint8List lastChunk});
Future<({Uint8List bytes, int? totalLength})> downloadRange(String path, {required int start, required int endInclusive});
// listFolder gains: Future<List<DropboxFileMetadata>> listFolder({String path = '', bool recursive = false});
```
`_uploadChunked` is refactored to call the three public primitives (behavior identical; its existing threshold test keeps passing). `downloadRange` sends the `Range` HTTP header on `/2/files/download` and parses `Content-Range` for the total (null when the server answers 200 with the full body).
- Produces (test helper `FakeDropboxServer`):
```dart
class FakeDropboxServer {
  final Map<String, Uint8List> files = {};   // path -> bytes ('/x/y.jpg')
  final List<http.Request> captured = [];
  int sessionAppendCount = 0;                 // successful appends+finishes with bodies
  int? failAfterAppends;                      // one-shot 500 when reached (no client retry on 500)
  MockClient get client;
  String bearerToken = 'test-token';          // _handle verifies the Authorization header
}
```
Handler branches on the request URL path: `/2/files/upload` (store body at `Dropbox-API-Arg`.path), `/2/files/download` (serve bytes; honor `Range` -> 206 + `Content-Range`), `/2/files/get_metadata` (JSON metadata or `{"error_summary": "path/not_found/.."}` with 409), `/2/files/list_folder` (+ `/continue`; respect `recursive` by prefix-matching stored paths; one page, `has_more: false`), `/2/files/delete_v2` (idempotent), `/2/users/get_current_account`, `/2/files/upload_session/start` (mint `session-N`, store chunks), `append_v2` (verify `cursor.offset` equals accumulated length, else 409 `{"error_summary": "incorrect_offset/.."}`), `finish` (concatenate into `files[commit.path]`). Dropbox not-found/errors are HTTP 409 with an `error_summary` JSON body - the client keys off the summary text, not the status.

- [ ] **Step 1: Write the failing test**

Create `test/core/services/cloud_storage/dropbox/dropbox_api_client_sessions_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_api_client.dart';

import '../../../../helpers/fake_dropbox_server.dart';

void main() {
  late FakeDropboxServer server;
  late DropboxApiClient client;

  setUp(() {
    server = FakeDropboxServer();
    client = DropboxApiClient(
      getAccessToken: () async => server.bearerToken,
      onAccessTokenRejected: () {},
      httpClient: server.client,
    );
  });

  test('session start, append, finish assembles the file in order', () async {
    final sessionId = await client.uploadSessionStart(
      Uint8List.fromList(List.filled(8, 1)),
    );
    await client.uploadSessionAppend(
      sessionId: sessionId,
      offset: 8,
      chunk: Uint8List.fromList(List.filled(8, 2)),
    );
    final meta = await client.uploadSessionFinish(
      sessionId: sessionId,
      offset: 16,
      path: '/m/big.bin',
      lastChunk: Uint8List.fromList(List.filled(4, 3)),
    );
    expect(meta.pathLower, '/m/big.bin');
    expect(server.files['/m/big.bin'], [
      ...List.filled(8, 1),
      ...List.filled(8, 2),
      ...List.filled(4, 3),
    ]);
  });

  test('append with a wrong offset surfaces incorrect_offset', () async {
    final sessionId = await client.uploadSessionStart(
      Uint8List.fromList([1, 2]),
    );
    await expectLater(
      client.uploadSessionAppend(
        sessionId: sessionId,
        offset: 99,
        chunk: Uint8List.fromList([3]),
      ),
      throwsA(
        predicate(
          (e) => e.toString().contains('incorrect_offset'),
        ),
      ),
    );
  });

  test('downloadRange returns the slice and total', () async {
    server.files['/m/r.bin'] = Uint8List.fromList(
      List.generate(100, (i) => i),
    );
    final range = await client.downloadRange(
      '/m/r.bin',
      start: 10,
      endInclusive: 19,
    );
    expect(range.bytes, List.generate(10, (i) => i + 10));
    expect(range.totalLength, 100);
  });

  test('recursive listFolder returns nested paths', () async {
    server.files['/m/smv1/objects/aa/x.bin'] = Uint8List.fromList([1]);
    server.files['/m/smv1/thumbs/aa/x.jpg'] = Uint8List.fromList([2]);
    server.files['/other.bin'] = Uint8List.fromList([3]);
    final entries = await client.listFolder(path: '/m/smv1', recursive: true);
    expect(entries.map((e) => e.pathLower).toSet(), {
      '/m/smv1/objects/aa/x.bin',
      '/m/smv1/thumbs/aa/x.jpg',
    });
  });
}
```

- [ ] **Step 2: Build the fake, run to verify failure, implement**

Write `test/helpers/fake_dropbox_server.dart` per the Interfaces block (branch on `request.url.path`; content endpoints read `Dropbox-API-Arg` header JSON; RPC endpoints read the JSON body; every branch checks `Authorization == 'Bearer ${bearerToken}'` and returns 401 otherwise). Run the test -> FAIL to compile. Then in `dropbox_api_client.dart`:

(a) Extract the three public session methods from `_uploadChunked`'s inline calls - each wraps one `_send(_contentRequest(...))` exactly as `_uploadChunked` does today, e.g.:

```dart
  /// Starts an upload session with the first chunk; returns the session id.
  Future<String> uploadSessionStart(Uint8List firstChunk) async {
    final response = await _send(
      () => _contentRequest(
        '/2/files/upload_session/start',
        arg: {'close': false},
        body: firstChunk,
      ),
    );
    return _decodeMap(response!)['session_id'] as String;
  }
```
(`uploadSessionAppend` mirrors the append_v2 call; `uploadSessionFinish` mirrors finish and returns `DropboxFileMetadata.fromJson`.) Rewrite `_uploadChunked`'s body to call them (same offsets, same behavior).

(b) `downloadRange`: `_contentRequest('/2/files/download', arg: {'path': path})` with the Range header added after build:

```dart
  Future<({Uint8List bytes, int? totalLength})> downloadRange(
    String path, {
    required int start,
    required int endInclusive,
  }) async {
    final response = await _send(
      () => _contentRequest('/2/files/download', arg: {'path': path})
        ..headers['Range'] = 'bytes=$start-$endInclusive',
      notFoundMessage: 'File not found in Dropbox: $path',
    );
    final contentRange = response!.headers['content-range'];
    return (
      bytes: response.bodyBytes,
      totalLength: contentRange == null
          ? null
          : int.parse(contentRange.split('/').last),
    );
  }
```
NOTE: `_send` treats 2xx as success; a 206 passes. Verify `_send`'s success check is `>= 200 && < 300` (it is, line 286) before assuming.

(c) `listFolder` gains `bool recursive = false`, passed into the `list_folder` RPC body.

- [ ] **Step 3: Run all Dropbox tests**

```bash
set -o pipefail
flutter test test/core/services/cloud_storage/dropbox/ --timeout 60s 2>&1 | tail -2
```
Expected: PASS (existing dropbox client tests plus the new ones - the `_uploadChunked` refactor is covered by whatever session test exists; if none exists, the Task 2 adapter tests cover it end-to-end).

- [ ] **Step 4: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add -A
git commit -m "feat(media-store): dropbox session primitives and range download"
```

---

### Task 2: DropboxMediaObjectStore

**Files:**
- Create: `lib/core/services/media_store/dropbox_media_object_store.dart`
- Test: `test/core/services/media_store/dropbox_media_object_store_test.dart`

**Interfaces:**
- Produces:
```dart
class DropboxMediaObjectStore implements MediaObjectStore {
  DropboxMediaObjectStore({
    required DropboxApiClient client,
    this.rootPath = '/submersion-media',
    this.chunkSizeBytes = 8 * 1024 * 1024, // session threshold AND chunk size
  });
  // key 'smv1/objects/aa/h.jpg' <-> path '/submersion-media/smv1/objects/aa/h.jpg'
  // Dropbox path_lower is LOWERCASE - keys are already lowercase (hex hashes,
  // fixed literals), so the round trip is safe; assert/document this.
}
```
- Behavior: `putFile` <= chunk -> single `client.upload`; larger -> session loop over `RandomAccessFile` slices with resume JSON `{"sessionId": "...", "offset": N, "chunkSizeBytes": M}` fired after every acknowledged append, `onProgress` alongside; resume validation is optimistic (append at the recorded offset; an `incorrect_offset` error or any session error aborts to a fresh session - Dropbox has no ListParts equivalent). `getFile`: metadata size via `getMetadata` (null -> notFound `MediaStoreException`); small -> whole `download`; large -> `downloadRange` loop to a `RandomAccessFile`. `head` -> `getMetadata` mapped to `StoreObjectInfo` (key = path minus root prefix). `delete` -> `client.delete` (already idempotent). `list(keyPrefix)` -> `listFolder(path: rootPath + '/' + dirOf(prefix), recursive: true)` filtered by full prefix client-side. Error mapping `_map`: message contains 'not found' -> notFound; 'authorization expired' -> auth; 'Could not reach' or 'rate limit' -> transient; 'out of storage' -> fatal; else fatal.

- [ ] **Step 1: Write the failing tests**

Create `test/core/services/media_store/dropbox_media_object_store_test.dart` - structurally a sibling of `s3_media_object_store_test.dart`: a `build({int? chunkSizeBytes})` helper over `FakeDropboxServer`, plus:

```dart
  // 1. Contract: the shared behavioral suite.
  runMediaObjectStoreContract(
    'DropboxMediaObjectStore',
    () async {
      server = FakeDropboxServer();
      return build();
    },
  );
```
(the contract's `setUp` calls `build()` fresh each test; recreate the server inside the builder so state never leaks), and these specific tests:

- `putFile maps the key under /submersion-media` - put `smv1/objects/ab/abc.jpg`, expect `server.files['/submersion-media/smv1/objects/ab/abc.jpg']`.
- `large putFile goes through a session with progress and resume state` - `build(chunkSizeBytes: 16 * 1024)`, 50 KiB payload -> expect assembled bytes, `resumeJson` contains `"sessionId"`, progress last == length.
- `kill-and-resume appends only the remaining chunks` - `server.failAfterAppends = 1` (start succeeds = chunk 1 stored; the first append dies), expect `MediaStoreException`; capture resume JSON (offset == 16 KiB); clear the injection; fresh `build(...)` + `putFile(resumeStateJson: ...)` -> assembled bytes correct AND `server.sessionAppendCount` shows chunk 1 was not re-sent (count the content-endpoint bodies: start=1, failed append, then appends for chunks 2..N + finish only).
- `a stale resume state (unknown session) restarts fresh` - resume JSON with `"sessionId": "session-nope"` -> file still assembles correctly.
- `chunked getFile round-trips with progress` (large object via `downloadRange` loop).

Write every test fully with exact byte-array assertions in the style of the S3 adapter test file (that file is the template; only the server fake and path mapping differ).

- [ ] **Step 2: Run to verify failure, implement the adapter**

The adapter mirrors `S3MediaObjectStore`'s structure exactly (threshold switch, `_putSession` <-> `_putMultipart`, `_validateResume` simplified to JSON-parse-only, `RandomAccessFile` loops, `_map`); the only structural differences: paths instead of wire keys (`String _path(String key) => '$rootPath/$key';`), resume JSON `{sessionId, offset, chunkSizeBytes}` (mismatch of chunkSizeBytes -> fresh session), Dropbox finish carries the LAST chunk (loop uploads chunks 1..N-1 via append, then finish with chunk N), and getFile sizes come from `getMetadata`.

- [ ] **Step 3: Run, format, analyze, commit**

```bash
set -o pipefail
flutter test test/core/services/media_store/dropbox_media_object_store_test.dart --timeout 90s 2>&1 | tail -2
dart format . && flutter analyze
git add -A
git commit -m "feat(media-store): dropbox media adapter with session resume"
```

---

### Task 3: GoogleDriveMediaObjectStore (raw REST, always-resumable)

**Files:**
- Modify: `lib/core/services/cloud_storage/google_drive_storage_provider.dart` (client accessor, ~line 26)
- Create: `lib/core/services/media_store/google_drive_media_object_store.dart`
- Create: `test/helpers/fake_drive_server.dart`
- Test: `test/core/services/media_store/google_drive_media_object_store_test.dart`

**Interfaces:**
- `GoogleDriveStorageProvider` gains (after `_initDriveApi`):
```dart
  /// Authenticated HTTP client for the media store's raw REST calls.
  /// Enables silent auth (the media attach itself is the opt-in) and
  /// returns null when no Google session can be established.
  Future<http.Client?> mediaHttpClient() async {
    _allowSilentAuth = true;
    if (await isAuthenticated()) return _authClient;
    return null;
  }
```
(add `import 'package:http/http.dart' as http;`).
- Produces:
```dart
class GoogleDriveMediaObjectStore implements MediaObjectStore {
  GoogleDriveMediaObjectStore({
    required http.Client client,           // authenticated
    this.folderName = 'submersion-media',
    this.chunkSizeBytes = 8 * 1024 * 1024, // MUST be a multiple of 256 KiB (Drive requirement)
    String apiBase = 'https://www.googleapis.com',
  });
  // One folder in appDataFolder; file NAME = the full store key (Drive
  // names allow '/'). All uploads are resumable sessions - one code path.
}
```
- REST surface used (all relative to `apiBase`): `GET /drive/v3/files?spaces=appDataFolder&q=<query>&fields=files(id,name,modifiedTime,size)` (folder ensure by name+mimeType, key lookup by name+parent, list by parent), `POST /drive/v3/files` (folder create), `POST /upload/drive/v3/files?uploadType=resumable` with JSON `{name, parents}` -> `Location` header session URI (updates of an existing key first DELETE the old file - content-addressed keys never change content, so overwrite only matters for interrupted garbage), `PUT <sessionUri>` with `Content-Range: bytes a-b/total` per chunk -> 308 until the final chunk's 200/201, resume probe `PUT <sessionUri>` with `Content-Range: bytes */total` + empty body -> 308 with `Range: bytes=0-N` (resume at N+1) or 200 (already complete) or 404 (stale -> fresh session), `GET /drive/v3/files/<id>?alt=media` (+ `Range` header for chunked downloads), `DELETE /drive/v3/files/<id>`.
- Resume JSON: `{"sessionUri": "...", "totalBytes": N, "chunkSizeBytes": M}`. `head`/`getFile`/`delete`/`list` resolve key -> fileId by name query each call.
- Error mapping: HTTP 401/403 -> auth; 404 on a resolved id -> notFound (head returns null when the name query is empty); 429/5xx/transport -> transient; else fatal.

- [ ] **Step 1: Write the failing tests**

Create `test/helpers/fake_drive_server.dart`:

```dart
class FakeDriveServer {
  final Map<String, ({String name, Uint8List bytes})> filesById = {};
  final Map<String, String> foldersByName = {};   // name -> id
  final List<http.Request> captured = [];
  int chunkPutCount = 0;                          // session PUTs with bodies
  int? failAfterChunkPuts;                        // one-shot 500 when reached
  MockClient get client;
}
```
Handler: `GET /drive/v3/files` parses `q` with two regexes (`name = '<x>'`, `'<id>' in parents`, `mimeType = '...folder'`) and answers `{files: [...]}`; `POST /drive/v3/files` creates a folder id `folder-N`; `POST /upload/drive/v3/files` (uploadType=resumable) reads the JSON `{name, parents}`, mints `session-N` bound to that name, responds 200 with `Location: <apiBase>/fake-session/session-N`; `PUT /fake-session/<id>`: `Content-Range: bytes */total` -> 308 + `Range: bytes=0-<stored-1>` (or 200 with the file JSON if complete, 404 if unknown session); ranged body PUT appends (verify the start offset equals stored length, else 500), 308 until `end+1 == total`, then materialize `filesById['file-N']` and respond 200 `{"id": "file-N", "name": ...}`; `GET /drive/v3/files/<id>?alt=media` serves bytes honoring `Range` (206 + `Content-Range`); `DELETE /drive/v3/files/<id>` -> 204.

Create `test/core/services/media_store/google_drive_media_object_store_test.dart`: the contract suite (`runMediaObjectStoreContract('GoogleDriveMediaObjectStore', ...)` with a fresh server per build) plus, mirroring the S3/Dropbox adapter test files exactly in structure:
- `putFile stores the key as the file name in the media folder` (assert `filesById.values.single.name == 'smv1/objects/ab/abc.jpg'` and folder ensure ran once).
- `large putFile chunks through one session with progress and resume state` (chunkSizeBytes: 256 KiB test override NOTE - the 256 KiB multiple rule means test chunks are 256 KiB and payloads ~700 KiB).
- `kill-and-resume probes the session and uploads only the tail` (`failAfterChunkPuts = 2`; resume -> probe request observed (`bytes */`), `chunkPutCount` delta covers only the remaining chunks + probe).
- `stale session (404 probe) restarts fresh`.
- `chunked getFile round-trips with progress`.

- [ ] **Step 2: Run to verify failure, implement**

Implement the provider accessor and the adapter. The adapter follows the same skeleton as the other two (`_ensureFolderId` cached per instance; `_fileIdForKey(key)` name query; threshold-free: every put opens a session; the chunk loop mirrors S3's `RandomAccessFile` pattern with `Content-Range` headers; `_probeSession(sessionUri, total)` implements the `*/total` resume probe). All requests set `'Content-Type': 'application/json; charset=utf-8'` for metadata calls. Key names in queries must escape single quotes (`key.replaceAll("'", r"\'")`) - keys are hex/fixed so this is belt-and-braces.

- [ ] **Step 3: Run, format, analyze, commit**

```bash
set -o pipefail
flutter test test/core/services/media_store/google_drive_media_object_store_test.dart --timeout 90s 2>&1 | tail -2
dart format . && flutter analyze
git add -A
git commit -m "feat(media-store): google drive media adapter with resumable sessions"
```

---

### Task 4: ICloudMediaObjectStore over an injectable platform

**Files:**
- Create: `lib/core/services/media_store/icloud_media_platform.dart`
- Create: `lib/core/services/media_store/icloud_media_object_store.dart`
- Test: `test/core/services/media_store/icloud_media_object_store_test.dart`

**Interfaces:**
- Produces:
```dart
/// Thin seam over the iCloud container so the adapter is testable against
/// a temp directory. The default implementation delegates to
/// ICloudNativeService statics + dart:io.
abstract class ICloudMediaPlatform {
  Future<String?> containerPath();
  Future<void> writeSmallFile(String path, Uint8List data); // native writeFile
  Future<bool> moveIntoContainer(String sourcePath, String destinationPath);
  Future<bool> ensureDownloaded(String path);               // downloadIfNeeded
  Future<void> refreshFolder(String path);                  // best-effort
}

class NativeICloudMediaPlatform implements ICloudMediaPlatform { ... }

/// Temp-directory fake for tests (lives in the SAME file, exported for
/// reuse by later tasks' tests):
class DirectoryICloudMediaPlatform implements ICloudMediaPlatform {
  DirectoryICloudMediaPlatform(this.root);
  final Directory root;
  // containerPath -> root.path; writeSmallFile -> File.writeAsBytes;
  // moveIntoContainer -> rename-with-copy-fallback; ensureDownloaded ->
  // File.exists; refreshFolder -> no-op.
}

class ICloudMediaObjectStore implements MediaObjectStore {
  ICloudMediaObjectStore({
    required ICloudMediaPlatform platform,
    this.rootFolder = 'submersion-media',
    this.smallFileThresholdBytes = 8 * 1024 * 1024,
  });
  // key -> <container>/submersion-media/<key>
}
```
- Behavior: `putFile` ensures parent directories (`Directory(dirname).create(recursive: true)`), then small -> `writeSmallFile(bytes)`, large -> copy source to a sibling temp path inside the container's folder then `moveIntoContainer` (native coordination; the OS uploads in the background - single progress tick, resume params accepted and unused). `getFile`: `ensureDownloaded(path)` -> false or missing file -> notFound; else copy to destination with one progress tick. `head`: `ensureDownloaded` false -> null; else `File.stat` size/modified. `list(keyPrefix)`: `refreshFolder(root)` best-effort, then recursive `Directory.list` filtered to files under the prefix, keys = path minus root. `containerPath() == null` anywhere -> `MediaStoreException(kind: fatal, 'iCloud is not available on this device')`.

- [ ] **Step 1: Write the failing tests**

Create `test/core/services/media_store/icloud_media_object_store_test.dart`: the shared contract against `DirectoryICloudMediaPlatform(tempDir)` plus two specifics - `large putFile lands via moveIntoContainer` (use `smallFileThresholdBytes: 1024`, a 4 KiB payload, assert the file exists at the mapped path with correct bytes and the SOURCE staging file is gone (moved)); `null container path maps to a fatal MediaStoreException` (a fake returning null). Full code mirrors the other adapter test files; the contract runner plus ~2 targeted tests suffice because there is no protocol layer here.

- [ ] **Step 2: Run to verify failure, implement, re-run**

Both classes are small (~60 lines platform, ~130 adapter). `NativeICloudMediaPlatform` methods are one-liners onto `ICloudNativeService`; `writeSmallFile` wraps `writeFile` and rethrows as `MediaStoreException(fatal)` on failure; the adapter never calls `refreshFolder` on hot paths (only `list`).

- [ ] **Step 3: Run, format, analyze, commit**

```bash
set -o pipefail
flutter test test/core/services/media_store/icloud_media_object_store_test.dart --timeout 60s 2>&1 | tail -2
dart format . && flutter analyze
git add -A
git commit -m "feat(media-store): icloud media adapter over the ubiquity container"
```

---

### Task 5: Provider-typed attach state and runtime

**Files:**
- Modify: `lib/core/services/media_store/media_store_attach_state.dart`
- Modify: `lib/features/media_store/presentation/providers/media_store_providers.dart` (runtime builder)
- Test: modify `test/core/services/media_store/media_store_credentials_test.dart` (attach-state cases)

**Interfaces:**
- `MediaStoreAttachState` becomes provider-typed:
```dart
static const String providerTypeKey = 'media_store_provider_type';
Future<void> setAttached(String storeId, {required CloudProviderType providerType});
Future<CloudProviderType?> attachedProviderType(); // null when unset; rows
// persisted before Phase 4 have no provider type: attachedProviderType()
// falls back to CloudProviderType.s3 when a storeId exists (migration-free
// backward compatibility - S3 was the only option).
```
- `mediaStoreRuntimeProvider` builds the store by type:
```dart
  final attachedId = await attachState.attachedStoreId();
  if (attachedId == null) return null;
  final providerType =
      await attachState.attachedProviderType() ?? CloudProviderType.s3;
  final store = await _buildStore(ref, providerType);
  if (store == null) return null;   // e.g. Drive silent auth unavailable
```
backed by a shared REF-LESS helper defined in `media_store_service.dart` (Task 6's default factories reuse it verbatim - define it here once):
```dart
/// Builds the store adapter for [type], or null when the provider is not
/// usable right now (missing config, no silent Google session, iCloud
/// unavailable). Used by the runtime provider and the connect flows.
Future<MediaObjectStore?> buildMediaObjectStore(
  CloudProviderType type, {
  S3Config? s3Config,
}) async { ... }
```
s3 -> `s3Config == null ? null : S3MediaObjectStore(client: S3ApiClient(s3Config), keyPrefix: s3Config.prefix)` (the runtime loads the keychain config and passes it in); dropbox -> `DropboxMediaObjectStore(client: DropboxApiClient(getAccessToken: authManager.getAccessToken, onAccessTokenRejected: authManager.invalidateAccessToken))` over a fresh `DropboxAuthManager()`; googledrive -> `cloudProviderInstanceFor(CloudProviderType.googledrive) as GoogleDriveStorageProvider`, then `mediaHttpClient()` (null -> null, else the adapter); icloud -> gated on `ICloudNativeService.getAvailability() == available` (else null), `ICloudMediaObjectStore(platform: NativeICloudMediaPlatform())`. `cloudProviderInstanceFor` is a top-level function in sync_providers.dart; import it.

- [ ] **Step 1: Write the failing attach-state tests**

Append to `media_store_credentials_test.dart`:

```dart
  test('attach state records and returns the provider type', () async {
    SharedPreferences.setMockInitialValues({});
    final state = MediaStoreAttachState(
      prefs: await SharedPreferences.getInstance(),
    );
    await state.setAttached('store-1', providerType: CloudProviderType.dropbox);
    expect(await state.attachedStoreId(), 'store-1');
    expect(await state.attachedProviderType(), CloudProviderType.dropbox);
    await state.clear();
    expect(await state.attachedProviderType(), isNull);
  });

  test('a pre-phase-4 attachment without a provider type reads as S3',
      () async {
    SharedPreferences.setMockInitialValues({
      MediaStoreAttachState.storeIdKey: 'store-legacy',
    });
    final state = MediaStoreAttachState(
      prefs: await SharedPreferences.getInstance(),
    );
    expect(await state.attachedProviderType(), CloudProviderType.s3);
  });
```
(import `sync_repository.dart` for the enum.)

- [ ] **Step 2: Implement attach state, then the runtime switch**

Attach state: `setAttached` writes both keys; `attachedProviderType()` returns null when NO storeId, `CloudProviderType.s3` when a storeId exists without a stored type, else `CloudProviderType.values.byName(stored)`; `clear()` removes both. Compile-fix the two existing `setAttached('...')` call sites (`MediaStoreService.connectS3` -> `providerType: CloudProviderType.s3`; the service test) - the compiler enumerates them.

Runtime: extract the current S3 construction into `_buildStore` and add the switch per the Interfaces block. The preflight/gate/worker wiring is store-agnostic and stays untouched. NOTE: `_buildStore` returning null must NOT clear the attachment (a Drive token hiccup is transient); the runtime simply stays null until the next invalidation.

- [ ] **Step 3: Run, format, analyze, commit**

```bash
set -o pipefail
flutter test test/core/services/media_store/media_store_credentials_test.dart test/features/media_store/ --timeout 90s 2>&1 | tail -2
dart format . && flutter analyze
git add -A
git commit -m "feat(media-store): provider-typed attach state and runtime"
```

---

### Task 6: Per-provider connect flows in MediaStoreService

**Files:**
- Modify: `lib/features/media_store/data/media_store_service.dart`
- Test: modify `test/features/media_store/media_store_service_test.dart`

**Interfaces:**
- Produces:
```dart
class MediaStoreService {
  MediaStoreService({
    required MediaStoreCredentialsStore credentials,
    required MediaStoreAttachState attachState,
    required MediaStoresRepository storesRepository,
    MediaObjectStore Function(S3Config config)? storeFactory,
    // Phase 4 seams: builders for the managed providers, injectable fakes
    // in tests, defaulting to the real adapters.
    Future<MediaObjectStore?> Function()? dropboxStoreFactory,
    Future<MediaObjectStore?> Function()? googleDriveStoreFactory,
    Future<MediaObjectStore?> Function()? icloudStoreFactory,
  });
  Future<MediaStoreConnectResult> connectS3(S3Config config);   // unchanged + providerType on setAttached
  Future<MediaStoreConnectResult> connectDropbox();  // hint 'Dropbox'
  Future<MediaStoreConnectResult> connectGoogleDrive(); // hint 'Google Drive'
  Future<MediaStoreConnectResult> connectICloud();   // hint 'iCloud'
  Future<void> disconnect(); // also clears the provider type (attachState.clear does)
}
```
- Shared private flow `_connectManaged(CloudProviderType type, String displayHint, Future<MediaObjectStore?> Function() factory)`: factory null -> `MediaStoreException(auth, '<provider> is not connected or unavailable')`; marker ensure via `StoreMarkerStore(store)`; `attachState.setAttached(storeId, providerType: type)`; descriptor upsert with the provider's `providerType.name` and hint; NO credentials-store write (managed providers keep credentials in their own auth stores). `connectS3` keeps the credentials write.
- Default factories delegate to Task 5's `buildMediaObjectStore(type)` (already in this file), e.g. `_dropboxStoreFactory = dropboxStoreFactory ?? (() => buildMediaObjectStore(CloudProviderType.dropbox));`.

- [ ] **Step 1: Write the failing tests**

Append to `media_store_service_test.dart`:

```dart
  test('connectDropbox ensures the marker and records provider type',
      () async {
    final dropboxFake = InMemoryMediaObjectStore();
    final svc = MediaStoreService(
      credentials: credentials,
      attachState: attachState,
      storesRepository: storesRepository,
      dropboxStoreFactory: () async => dropboxFake,
    );
    final result = await svc.connectDropbox();
    expect(result.createdNewStore, isTrue);
    expect(dropboxFake.objects.containsKey('smv1/store.json'), isTrue);
    expect(await attachState.attachedProviderType(), CloudProviderType.dropbox);
    final active = await storesRepository.getActive();
    expect(active!.providerType, 'dropbox');
    expect(await credentials.load(), isNull,
        reason: 'managed providers never touch the S3 keychain entry');
  });

  test('connect on an unavailable managed provider throws auth', () async {
    final svc = MediaStoreService(
      credentials: credentials,
      attachState: attachState,
      storesRepository: storesRepository,
      googleDriveStoreFactory: () async => null,
    );
    await expectLater(
      svc.connectGoogleDrive(),
      throwsA(
        isA<MediaStoreException>().having(
          (e) => e.kind,
          'kind',
          MediaStoreErrorKind.auth,
        ),
      ),
    );
    expect(await attachState.attachedStoreId(), isNull);
  });
```
plus a `connectICloud` happy-path clone of the Dropbox test (provider type icloud, hint 'iCloud').

- [ ] **Step 2: Implement, run, commit**

Implement per the Interfaces block (the three public methods are one-liners onto `_connectManaged`). Fix `connectS3`'s `setAttached` call for the new signature. Run:

```bash
set -o pipefail
flutter test test/features/media_store/media_store_service_test.dart --timeout 60s 2>&1 | tail -2
dart format . && flutter analyze
git add -A
git commit -m "feat(media-store): per-provider connect flows"
```

---

### Task 7: Provider chooser on the Media Storage page + l10n

**Files:**
- Modify: `lib/features/media_store/presentation/pages/media_storage_page.dart`
- Modify: all 11 `lib/l10n/arb/app_*.arb` (script below)
- Test: modify `test/features/media_store/media_storage_page_test.dart`

**Interfaces:**
- Page behavior: when DISCONNECTED, a "Provider" `SegmentedButton<CloudProviderType>` (S3 / Dropbox / Google Drive / iCloud; iCloud segment only when `isApplePlatformProvider` is true) selects which connect panel shows below. S3 panel = the existing form (unchanged). Managed panels = a short explainer `Text` + a `FilledButton` (`Key('media-dropbox-connect')` / `'media-gdrive-connect'` / `'media-icloud-connect'`) calling the matching `MediaStoreService.connect*()`, then `ref.invalidate(mediaStoreRuntimeProvider)` + saved-snack + `Navigator.maybePop` (same post-connect sequence as `_connect`). Errors surface via `_showSnack(e.message, isError: true)`. When CONNECTED, the chooser hides (the status card + policies/backfill/transfers/disconnect sections are provider-agnostic and stay).
- New l10n keys (script adds all 11 locales; translations included):
  - `settings_mediaStorage_provider_label`: "Provider" / de "Anbieter" / es "Proveedor" / fr "Fournisseur" / it "Provider" / nl "Provider" / pt "Provedor" / hu "Szolgaltato" (restore: Szolgáltató) / zh "服务商" / ar "المزود" / he "ספק"
  - `settings_mediaStorage_connect_dropbox_hint`: "Uses your Dropbox connection from Cloud Sync. Media is stored in your Dropbox app folder." (translate per locale in the script, same register as existing strings)
  - `settings_mediaStorage_connect_gdrive_hint`: "Signs in with Google. Media is stored in this app's private Drive space."
  - `settings_mediaStorage_connect_icloud_hint`: "Media is stored in this app's iCloud container and syncs through your Apple ID."
  - `settings_mediaStorage_connect_action`: "Connect {provider}" (String placeholder)
  Follow the Phase 2 l10n script pattern (`add_media_storage_phase2_l10n.py` in the session scratchpad is the template): proper diacritics, `@settings_mediaStorage_connect_action` metadata with the placeholder, run + `flutter gen-l10n`, verify the diff is additions-only.
- Provider display names come from the existing enum-adjacent strings if present (check `settings_cloudSync_provider_*` keys in app_en.arb and reuse); otherwise plain literals 'S3', 'Dropbox', 'Google Drive', 'iCloud' are acceptable for segment labels (proper nouns are not translated).

- [ ] **Step 1: Write the failing widget tests**

Append to `media_storage_page_test.dart` (the `_RecordingService` gains `int dropboxCalls = 0;` etc. with overrides of the three connect methods returning canned results):

```dart
  testWidgets('provider chooser shows managed connect panel and calls the '
      'service', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(app());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    await tester.tap(find.text('Dropbox'));
    await tester.pump();
    expect(find.byKey(const Key('media-dropbox-connect')), findsOneWidget);
    expect(find.byKey(const Key('media-s3-endpoint')), findsNothing);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('media-dropbox-connect')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
    expect(service.dropboxCalls, 1);
  });
```
plus one asserting the S3 segment is selected by default with the form visible, and one asserting the iCloud segment is absent when `isApplePlatformProvider` is overridden to false (override that provider in the ProviderScope; check its exact name/exported location in sync_providers.dart first).

- [ ] **Step 2: Run the l10n script, implement the page changes, run tests**

State additions to `_MediaStoragePageState`: `CloudProviderType _selectedProvider = CloudProviderType.s3;` and a `_connectManaged(Future<MediaStoreConnectResult> Function() call)` helper mirroring `_connect`'s busy/snack/invalidate/pop sequence. The build method wraps the existing S3 form widgets in `if (!connected && _selectedProvider == CloudProviderType.s3) ...[...]` and adds the chooser + managed panels. Keep the file under 800 lines - if it crosses, extract the S3 form section into `lib/features/media_store/presentation/widgets/s3_connect_form.dart` as part of this task.

- [ ] **Step 3: Run, format, analyze, commit**

```bash
set -o pipefail
flutter test test/features/media_store/media_storage_page_test.dart --timeout 60s 2>&1 | tail -2
flutter test test/features/settings/ 2>&1 | tail -1
dart format . && flutter analyze
git add -A
git commit -m "feat(media-store): provider chooser with dropbox, drive, icloud connect"
```

---

### Task 8: Phase 4 exit verification + stacked PR

**Files:**
- Test: modify `test/features/media_store/media_store_end_to_end_test.dart`

- [ ] **Step 1: Protocol-independence e2e**

Append one test: `the cross-device video flow works over the Dropbox adapter` - clone the Phase 3 video e2e but build device A's pipeline/worker and device B's resolver over `DropboxMediaObjectStore(client: DropboxApiClient(... FakeDropboxServer ...), chunkSizeBytes: 16 * 1024)` with a 64 KiB video (forcing the session path), asserting byte-identical playback and the poster thumb on B. This proves the whole pipeline is adapter-agnostic, not just the adapters contract-compliant.

- [ ] **Step 2: Full gates**

```bash
set -o pipefail
flutter test test/features/media_store/ test/core/services/media_store/ test/core/services/cloud_storage/ --timeout 90s 2>&1 | tail -1
flutter test test/features/media/ 2>&1 | tail -1
flutter test test/core/services/sync/ 2>&1 | tail -1
flutter test test/features/settings/ 2>&1 | tail -1
dart format . && flutter analyze
```
Expected: all PASS, no issues.

- [ ] **Step 3: Commit, push, stacked PR**

```bash
git add -A && git commit -m "feat(media-store): phase 4 exit coverage"
git push -u origin worktree-media-store-phase4 --no-verify
env -u GITHUB_TOKEN gh pr create \
  --title "feat(media-store): backends, phase 4 (dropbox, google drive, icloud)" \
  --base worktree-media-store-phase3 --head worktree-media-store-phase4 \
  --body-file <scratchpad>/pr_body_phase4.md
```
PR body: repo template; STACKED on #557 (-> #556 -> #550, merge bottom-up); notes iCloud's OS-managed resume and the real-account/manual items (Dropbox + Drive live smoke, iCloud two-device smoke on real hardware per the icloud-needs-devices constraint).

## Phase 4 exit criteria (spec section 17)

- [ ] The shared MediaObjectStore contract passes on all four adapters (fake-backed)
- [ ] Kill-and-resume proven for Dropbox sessions and Drive resumable sessions (request counting); iCloud documented as OS-managed
- [ ] Chunked, progress-reporting downloads on Dropbox and Drive; iCloud via ensureDownloaded
- [ ] Provider chooser connects each backend; attach state and runtime are provider-typed; legacy S3 attachments keep working without migration
- [ ] Cross-device video e2e passes over a non-S3 adapter

