# Sync Base-Part Processing Off the UI Isolate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in one session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the CPU work of a base transfer off the UI isolate on every provider, with or without encryption, without changing a single byte on the wire, and stop an interrupted base fetch from being read as an empty cloud library.

**Architecture:** A long-lived per-transfer worker owns the rolling SHA-256 state (`BasePartHasher`). Everything without rolling state goes through one helper, `runOffIsolate`, which reruns inline on any failure that says nothing about the data. `assemble` separates "the cloud data is bad" (null) from "the fetch was interrupted" (a thrown `BaseFetchInterrupted`).

**Tech Stack:** Dart isolates (`Isolate.spawn`, `Isolate.run`, `TransferableTypedData`), `package:crypto`, `package:cryptography` (`DartAesGcm`), `dart:io` gzip and zlib, `package:archive` inflate.

**Spec:** `docs/design/specs/2026-10-30-sync-part-processing-off-ui-isolate-design.md`. Read it first; this plan argues from it.

## Global Constraints

- Digests, envelopes, signatures and packs stay byte-identical to today's. Old and new builds interoperate in both directions.
- Threshold: `kOffIsolateMinBytes = 256 * 1024`, one constant.
- Hasher reply timeout 60 seconds; handshake timeout 10 seconds.
- At most one part in flight. Memory never grows with base size.
- `off_isolate.dart`, `base_part_hasher.dart`, `base_part_file_source.dart`, `sync_envelope.dart`, `sigv4_signer.dart` and the `git/pack_*`, `git_object_*` files import no Flutter package, so `dart compile exe` keeps working. Use `package:meta` for `@visibleForTesting`.
- Work functions passed to `runOffIsolate` are top-level or static, called from a small function of their own, so the closure context holds nothing but their arguments. Never declare the closure inside `seal`, `open` or an instance method that also holds a key or `this`.
- Injectable test hooks are parameters, never mutable statics (`test/architecture/test_global_state_restored_test.dart`).
- Paths use `p.join`; temporary space comes from `Directory.systemTemp`.
- No commit or PR text names an AI tool. No em dashes anywhere.
- Before each commit: `dart format .`, `flutter analyze`, the task's tests. Run `test/architecture/` after adding any file under `lib/`. Stage explicit paths. Gate commits on the log, not on a pipeline's exit code.

## Review Focus

1. **A transfer that fails partway leaves no worker running.** An upload that throws on part 2 must still dispose the hasher. Pinned in Task 4.
2. **Sizes at the boundary.** A file exactly one part long, a whole multiple of the part size, and a first part of exactly `kOffIsolateMinBytes`. Pinned in Tasks 2, 3 and 4.
3. **An incompressible payload above the threshold.** Gzip output is not smaller, so the flag stays clear and the body is the raw plaintext, through the off-isolate path. Pinned in Task 7.
4. **Two hashers alive at once.** Adopt walks devices in turn, but nothing in the type forbids overlap, and rolling state must not bleed. Pinned in Task 3.
5. **A pack holding an object the store already has.** Worker and main store race on the same content-addressed file, leaving one object, no `.tmp` file, and a correct size total. Pinned in Task 10.

---

### Task 1: Capture the before numbers

Throwaway. Nothing here is committed. It runs first because the code changes next.

**Files:**
- Create (untracked, deleted in Task 11): `tool/bench_3829.dart`, `tool/bench_3829_frames.dart`

**Interfaces:**
- Produces: `<scratchpad>/bench3829/before.txt` and `<scratchpad>/bench3829/before_frames.txt`, read by Task 11.

- [ ] **Step 1: Write `tool/bench_3829.dart`.** It imports production classes from `package:submersion/...` and runs under `dart compile exe`. Use the 1 ms periodic gap tracker from the scratchpad bench. Scenarios, 32 MiB of JSON-like data on the same seed: `BasePartFileSource.uploadAll` with a no-op uploader; the same with `skipPart: (_) => true`; `SyncEnvelope.seal` then `open` on one 8 MiB part with a fixed key; `SigV4Signer.sign` on one 8 MiB part; `writePack` collected on one 8 MiB blob; `readSpooledPack` on that pack into a `FileGitObjectStore` in a temp directory. Print total, largest gap, count over 8 ms and 16 ms, three rounds each.

- [ ] **Step 2: Compile and run it.**

Run: `dart compile exe tool/bench_3829.dart -o <scratchpad>/bench3829/before.exe`, then run the exe and tee to `before.txt`.
Expected: one line per scenario per round, and digests that match between rounds.

- [ ] **Step 3: Write `tool/bench_3829_frames.dart`.** `BasePartFileSink` reaches `path_provider`, so downloads are measured here. A minimal app: a `ListView` scrolled by an `AnimationController`, `SchedulerBinding.instance.addTimingsCallback` recording build and raster durations, and three runs on a loop (upload, download through `BasePartFileSink.assemble`, skipped-part resume), each plain and through `EncryptingCloudStorageProvider` over a no-op inner provider. It writes p50, p90, p99, worst and missed frames to a file, then exits.

- [ ] **Step 4: Run it in a macOS profile build.**

Run: `flutter run --profile -d macos -t tool/bench_3829_frames.dart` from a Terminal panel tab, not the Bash tool: a macOS app launched from this session's shell can abort on first frame.
Expected: `before_frames.txt` has a line per flow and mode.

If the profile build cannot run here, record why and carry on. Report the gap in the PR rather than blocking on it.

---

### Task 2: One-shot off-isolate helper

**Files:**
- Create: `lib/core/utils/off_isolate.dart`
- Test: `test/core/utils/off_isolate_test.dart`

**Interfaces:**
- Produces:

```dart
const int kOffIsolateMinBytes = 256 * 1024;
typedef OffIsolateRunner = Future<R> Function<R>(FutureOr<R> Function() work);

Future<T> runOffIsolate<T>(
  FutureOr<T> Function() work, {
  required int bytes,
  int minBytes = kOffIsolateMinBytes,
  bool Function(Object error)? isExpected,
  @visibleForTesting OffIsolateRunner? runner,
});
```

- [ ] **Step 1: Write the failing tests.**

```dart
String? isolateName() => Isolate.current.debugName;

test('below the threshold it runs on this isolate', () async {
  expect(await runOffIsolate(isolateName, bytes: 1), Isolate.current.debugName);
});
test('at the threshold it runs on another isolate', () async {
  final name = await runOffIsolate(isolateName, bytes: kOffIsolateMinBytes);
  expect(name, isNot(Isolate.current.debugName));
});
test('one byte under the threshold stays inline', () async {
  final name = await runOffIsolate(isolateName, bytes: kOffIsolateMinBytes - 1);
  expect(name, Isolate.current.debugName);
});
test('an expected error is rethrown without running inline', () async {
  var inline = 0;
  await expectLater(
    runOffIsolate<int>(
      () { inline++; throw const FormatException('bad'); },
      bytes: 1 << 20,
      isExpected: (e) => e is FormatException,
      runner: <R>(work) async => throw const FormatException('bad'),
    ),
    throwsFormatException,
  );
  expect(inline, 0);
});
test('a spawn failure reruns inline', () async {
  final value = await runOffIsolate(
    () => 7,
    bytes: 1 << 20,
    runner: <R>(work) async => throw IsolateSpawnException('no isolate'),
  );
  expect(value, 7);
});
test('a RemoteError reruns inline', ...);        // runner throws RemoteError('died', '')
test('an unsendable closure reruns inline', ...); // work captures a ReceivePort; no runner
test('a real failure surfaces from the inline rerun', () async {
  await expectLater(
    runOffIsolate<int>(() => throw StateError('real'), bytes: 1 << 20),
    throwsStateError,
  );
});
```

- [ ] **Step 2: Run the tests to verify they fail.**

Run: `flutter test test/core/utils/off_isolate_test.dart`
Expected: FAIL, `off_isolate.dart` does not exist.

- [ ] **Step 3: Implement `runOffIsolate` in `lib/core/utils/off_isolate.dart`.** Default runner is `Isolate.run`. `catch (e)`: rethrow when `isExpected?.call(e) == true`, otherwise `return work()`.

- [ ] **Step 4: Run the tests to verify they pass.**

Run: `flutter test test/core/utils/off_isolate_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit.** `feat(sync): add a one-shot off-isolate helper`

---

### Task 3: BasePartHasher

**Files:**
- Create: `lib/core/services/sync/changeset_log/base_part_hasher.dart`
- Create: `lib/core/services/sync/changeset_log/base_part_hasher_logged.dart`
- Test: `test/core/services/sync/changeset_log/base_part_hasher_test.dart`

**Interfaces:**
- Consumes: `kOffIsolateMinBytes` (Task 2).
- Produces:

```dart
abstract interface class BasePartHasher {
  Future<String> addPart(Uint8List part);
  Future<String> finish();
  Future<void> dispose();
}

class BasePartHasherException implements Exception {
  BasePartHasherException(this.message);
  final String message;
}

typedef BasePartHasherOpener = Future<BasePartHasher> Function(int firstPartBytes);

Future<BasePartHasher> openBasePartHasher(
  int firstPartBytes, {
  void Function(Object error)? onWorkerUnavailable,
  @visibleForTesting void Function(SendPort) entryPoint = basePartHasherWorkerMain,
  @visibleForTesting Duration handshakeTimeout = const Duration(seconds: 10),
  @visibleForTesting Duration replyTimeout = const Duration(seconds: 60),
});

class WorkerBasePartHasher implements BasePartHasher {
  @visibleForTesting Isolate get debugIsolate;
}

// base_part_hasher_logged.dart, which may import LoggerService
Future<BasePartHasher> openLoggedBasePartHasher(int firstPartBytes);
```

- [ ] **Step 1: Write the failing tests,** run against both implementations by parameterizing on `firstPartBytes` (`0` and `kOffIsolateMinBytes`), feeding real parts of those sizes where the size matters.

```dart
test('part and whole digests match BaseChunker across parts', ...);
//   three parts, short last part: expect(await h.addPart(p), BaseChunker.checksum(p));
//   expect(await h.finish(), BaseChunker.checksum(all));
test('an empty part hashes to the empty digest', ...);
test('the caller keeps its bytes', ...);  // copy before, addPart, expect equal after

test('a first part below the threshold uses no worker', () async {
  final h = await openBasePartHasher(kOffIsolateMinBytes - 1);
  expect(h, isNot(isA<WorkerBasePartHasher>()));
});
test('a first part at the threshold uses a worker', ...);
test('two hashers keep their rolling state apart', ...); // interleave addPart on two

test('a failed spawn falls back to inline and reports it', ...);
//   entryPoint throws before its handshake; onWorkerUnavailable is called once;
//   digests still match.
test('a silent worker falls back after the handshake timeout', ...);
//   entryPoint does nothing; handshakeTimeout: 50 ms.

test('killing the worker fails the call in flight promptly', () async {
  final h = await openBasePartHasher(
    kOffIsolateMinBytes,
    entryPoint: _neverReplies,
  ) as WorkerBasePartHasher;
  final pending = h.addPart(Uint8List(16));
  h.debugIsolate.kill(priority: Isolate.immediate);
  await expectLater(
    pending.timeout(const Duration(seconds: 5)),
    throwsA(isA<BasePartHasherException>()),
  );
  await expectLater(h.addPart(Uint8List(16)), throwsA(isA<BasePartHasherException>()));
});
test('a silent worker fails the call at the reply timeout', ...); // replyTimeout: 50 ms
test('dispose is safe after a failure and when repeated', ...);
```

`_neverReplies` is a top-level test function that sends its port and ignores every message.

- [ ] **Step 2: Run the tests to verify they fail.**

Run: `flutter test test/core/services/sync/changeset_log/base_part_hasher_test.dart`
Expected: FAIL, the file does not exist.

- [ ] **Step 3: Implement `base_part_hasher.dart`.** Mirror `BaseParseClient.spawn` for the handshake, teardown on failure, and `errorsAreFatal: false`. Add `onExit: port` so a killed isolate fails the waiter at once. A request sends `TransferableTypedData.fromList([part])`. Replies are strings. A failed hasher latches: every later call throws. `dispose` kills the isolate and closes the port, once. Keep the `_DigestSink` here so the two copies in source and sink can go.

- [ ] **Step 4: Implement `base_part_hasher_logged.dart`.** `openLoggedBasePartHasher` calls `openBasePartHasher` with `onWorkerUnavailable` logging a warning through `LoggerService`.

- [ ] **Step 5: Run the tests to verify they pass.**

Run: `flutter test test/core/services/sync/changeset_log/base_part_hasher_test.dart`
Expected: all pass, in under 30 seconds.

- [ ] **Step 6: Commit.** `feat(sync): hash base parts on a per-transfer worker isolate`

---

### Task 4: Upload through the hasher

**Files:**
- Modify: `lib/core/services/sync/changeset_log/base_part_file_source.dart`
- Modify: `lib/core/services/sync/changeset_log/changeset_writer.dart:224,516`
- Test: `test/core/services/sync/changeset_log/base_part_file_source_test.dart`

**Interfaces:**
- Consumes: `BasePartHasher`, `BasePartHasherOpener`, `openBasePartHasher`, `openLoggedBasePartHasher` (Task 3).
- Produces: `BasePartFileSource(String path, {int partSize, BasePartHasherOpener openHasher = openBasePartHasher})`.

- [ ] **Step 1: Write the failing tests.**

```dart
test('a worker failure propagates and stops later uploads', () async {
  // 3 parts; openHasher returns a fake whose second addPart throws
  // BasePartHasherException.
  // expect uploadAll throwsA(isA<BasePartHasherException>());
  // expect uploaded indices == [0]; expect the file can be deleted.
});
test('a failed upload disposes the hasher', () async {
  // upload throws on index 1; a recording fake hasher sees dispose called once.
});
test('digests are unchanged at part-size multiples', ...);
//   file of exactly 2 * partSize, and of exactly partSize: partCount, digests.
test('an empty file opens a hasher for zero bytes and yields one part', ...);
```

- [ ] **Step 2: Run the tests to verify they fail.**

Run: `flutter test test/core/services/sync/changeset_log/base_part_file_source_test.dart`
Expected: the new tests FAIL on the missing `openHasher` parameter.

- [ ] **Step 3: Implement.** Open the hasher with `min(length, partSize)` after reading the length, inside the existing `try`. Replace `whole.add` and `BaseChunker.checksum` with `await hasher.addPart(buf)` and the closing digest with `await hasher.finish()`. Dispose in `finally` before `raf.close()`. Update the class comment to say where hashing runs. In `changeset_writer.dart`, pass `openHasher: openLoggedBasePartHasher` at both call sites.

- [ ] **Step 4: Run the tests to verify they pass.**

Run: `flutter test test/core/services/sync/changeset_log/base_part_file_source_test.dart test/core/services/sync/changeset_log/resumable_base_publish_test.dart`
Expected: all pass, existing tests unchanged.

- [ ] **Step 5: Commit.** `feat(sync): hash uploaded base parts off the UI isolate`

---

### Task 5: Download through the hasher, and split null from interrupted

**Files:**
- Modify: `lib/core/services/sync/changeset_log/base_part_file_sink.dart`
- Test: `test/core/services/sync/changeset_log/base_part_file_sink_test.dart`

**Interfaces:**
- Consumes: `BasePartHasher`, `BasePartHasherOpener`, `openLoggedBasePartHasher`, `BasePartHasherException` (Task 3).
- Produces:

```dart
class BaseFetchInterrupted implements Exception {
  BaseFetchInterrupted(this.cause);
  final Object cause;
}

BasePartFileSink({
  Future<Directory> Function()? tempDirProvider,
  BasePartHasherOpener openHasher = openLoggedBasePartHasher,
});
```

`assemble` keeps its signature and returns null, or throws `BaseFetchInterrupted`.

- [ ] **Step 1: Write the failing tests.**

```dart
test('a part the cloud lacks returns null', ...);        // downloadPart -> null
test('a digest mismatch returns null', ...);
test('a whole-file mismatch returns null', ...);
test('a corrupt envelope returns null', ...);            // throws EnvelopeCorruptException
test('a key this device lacks returns null', ...);       // throws SyncEncryptionRequired
test('a download error throws BaseFetchInterrupted', () async {
  await expectLater(
    sink.assemble(
      name: 'ssv1_x', partCount: 2, wholeChecksum: null, partChecksums: const [],
      downloadPart: (i) async => throw const CloudStorageException('dropped'),
    ),
    throwsA(isA<BaseFetchInterrupted>()),
  );
  expect(dir.listSync(), isEmpty);
});
test('a hasher failure throws BaseFetchInterrupted and leaves no file', ...);
test('the hasher is sized from the first part and disposed on every exit', ...);
//   recording opener: firstPartBytes == first part length; dispose once on
//   success, on null, and on interruption.
test('no hasher opens when the first part is missing', ...);
test('partCount 0 with a whole checksum still returns null', ...);
```

- [ ] **Step 2: Run the tests to verify they fail.**

Run: `flutter test test/core/services/sync/changeset_log/base_part_file_sink_test.dart`
Expected: the download-error and hasher tests FAIL.

- [ ] **Step 3: Implement.** Catch order in the loop: `on EnvelopeCorruptException` and `on SyncEncryptionRequired` set `ok = false`; `catch (e, st)` records the interruption. Hash before writing, as today. A `finish()` failure also counts as an interruption. Close the file, delete the temp on any failure, dispose in `finally`, then `Error.throwWithStackTrace(BaseFetchInterrupted(e), st)` if interrupted. Update the `assemble` doc comment with the split, and say that adopt and pull read a null differently.

- [ ] **Step 4: Run the tests to verify they pass.**

Run: `flutter test test/core/services/sync/changeset_log/base_part_file_sink_test.dart`
Expected: all pass, existing tests unchanged.

- [ ] **Step 5: Commit.** `fix(sync): tell an interrupted base fetch from a bad cloud base`

---

### Task 6: Callers of a failed fetch

**Files:**
- Modify: `lib/core/services/sync/changeset_log/changeset_reader.dart:304`
- Modify: `lib/core/services/sync/sync_service.dart:5691-5800`
- Test: `test/core/services/sync/changeset_log/changeset_reader_test.dart`
- Test: `test/core/services/sync/sync_retirement_fence_test.dart`
- Test: `test/core/services/sync/sync_service_epoch_test.dart`
- Test: `test/core/services/sync/sync_service_replace_join_test.dart`

**Interfaces:**
- Consumes: `BaseFetchInterrupted` (Task 5).

Each test uses a local `FakeCloudStorageProvider` subclass whose `downloadFile` throws `CloudStorageException('connection lost')` for a file id containing `ChangesetLogLayout.basePartName(peer, seq, 0)`.

- [ ] **Step 1: Write the failing tests.**

```dart
// sync_retirement_fence_test.dart, beside the existing 'fence with no readable
// cloud library re-establishes from local' test, whose setup it copies.
test('an interrupted fetch leaves the fence up and the marker in place', () async {
  // One device in the library; the fake drops its base part.
  // expect the sync result status == SyncResultStatus.error;
  // expect the epoch marker file still in the cloud;
  // expect publish state and peer cursors unchanged;
  // expect no local row deleted.
});
test('the existing no-readable-library re-establish still runs when the part is missing', ...);

// sync_service_epoch_test.dart
test('adopt reports an interrupted fetch and does not recover', () async {
  // result status == SyncResultStatus.error; the marker is untouched.
});
test('adopt with two devices aborts rather than refill without the second', () async {
  // The fake drops only the second device's base; local rows are untouched;
  // no ssv1_adopt_* temp file remains in the sync temp dir.
});
test('adopt still skips a device whose base is missing in the cloud', ...);

// changeset_reader_test.dart
test('pull treats an interrupted fetch as an incomplete peer', () async {
  // result.incompletePeerDeviceIds contains the peer; it is not in
  // readFailedPeerDeviceIds; the cursor does not move.
});

// sync_service_replace_join_test.dart
test('an interrupted fetch fails prepare and changes nothing', () async {
  // await expectLater(service.prepareReplaceJoin(),
  //   throwsA(isA<BaseFetchInterrupted>()));
  // this device's dive and roster are untouched.
});
```

- [ ] **Step 2: Run the tests to verify they fail.**

Run: `flutter test test/core/services/sync/sync_retirement_fence_test.dart test/core/services/sync/sync_service_epoch_test.dart test/core/services/sync/sync_service_replace_join_test.dart test/core/services/sync/changeset_log/changeset_reader_test.dart`
Expected: pull fails on `readFailedPeerDeviceIds`, the two-device adopt test fails on a leftover temp file. The fence, adopt and replace-join tests pass since Task 5 made these throw; that is the coverage this task pins.

- [ ] **Step 3: Implement.** In `ChangesetReader`, catch `BaseFetchInterrupted` around `_fetchBaseToFile`, log it with its cause, and fall through to the existing null handling. In `_collectEpochBaseSources`, wrap the device loop: `on BaseFetchInterrupted` deletes every path in `baseFilePaths`, then rethrows. Read the caller of `prepare()` in `replace_and_join_providers.dart` and confirm a throw reaches its existing failure handling, as a `listFiles` network error does today; no new `ReplaceJoinOutcome`. If it does not, add the handling there.

- [ ] **Step 4: Run the tests to verify they pass.**

Run: the Step 2 command.
Expected: all pass.

- [ ] **Step 5: Commit.** `fix(sync): abort adopt and the fence on an interrupted base fetch`

---

### Task 7: Envelope seal and open

**Files:**
- Modify: `lib/core/services/sync/crypto/sync_envelope.dart`
- Test: `test/core/services/sync/crypto/sync_envelope_test.dart`

**Interfaces:**
- Consumes: `runOffIsolate`, `kOffIsolateMinBytes` (Task 2).
- Produces: `seal` and `open` each gain `@visibleForTesting int offIsolateMinBytes = kOffIsolateMinBytes`. Passing `1 << 40` forces the inline path.

- [ ] **Step 1: Write the failing tests.**

```dart
// nonceForTest and a fixed key throughout; payload 1 MiB of JSON-like bytes.
test('sealing off-isolate gives the same bytes as inline', () async {
  final off = await seal(payload);
  final inline = await seal(payload, offIsolateMinBytes: 1 << 40);
  expect(off, inline);
});
test('envelopes from either path open through the other', ...);
test('an incompressible payload stays unflagged through the worker', () async {
  // 1 MiB of Random(1) bytes: sealed[20] & 0x01 == 0, and it round-trips.
});
test('a wrong name still raises EnvelopeCorruptException off-isolate', ...);
test('a tampered body still raises EnvelopeCorruptException off-isolate', ...);
test('the inflate cap still rejects off-isolate', ...);
//   compressZeros from test/support/compression_bombs.dart, maxPlaintextBytes below its size.
test('a payload below the threshold stays inline', ...); // existing KATs cover bytes
```

- [ ] **Step 2: Run the tests to verify they fail.**

Run: `flutter test test/core/services/sync/crypto/sync_envelope_test.dart`
Expected: FAIL on the missing `offIsolateMinBytes` parameter.

- [ ] **Step 3: Implement.** Add static private `_gzip`, `_inflate`, `_dartEncrypt` and `_dartDecrypt` with small wrappers, per the closure rule in Global Constraints. `_inflate` is passed `maxPlaintextBytes` and builds `gzip.decoder` inside. `isExpected` is `BoundedInflateException` for inflate and `SecretBoxAuthenticationError` for decrypt. Choose the AES route with `_aesGcm is DartAesGcm` (import `package:cryptography/dart.dart`); extract the key with `extractBytes()` only on that route, and rebuild `SecretKeyData` and `DartAesGcm.with256bits()` in the worker. Leave every other backend exactly as it is.

- [ ] **Step 4: Run the tests to verify they pass.**

Run: `flutter test test/core/services/sync/crypto/ test/core/services/cloud_storage/encrypting_cloud_storage_provider_test.dart test/core/services/sync/encrypted_sync_integration_test.dart`
Expected: all pass, including the python-built KATs.

- [ ] **Step 5: Commit.** `feat(sync): seal and open large envelopes off the UI isolate`

---

### Task 8: S3 payload hash

**Files:**
- Modify: `lib/core/services/cloud_storage/s3/sigv4_signer.dart:137-152`
- Modify: `lib/core/services/cloud_storage/s3/s3_api_client.dart:685-715`
- Test: `test/core/services/cloud_storage/s3/sigv4_signer_test.dart`
- Test: `test/core/services/cloud_storage/s3/s3_api_client_test.dart`

**Interfaces:**
- Consumes: `runOffIsolate` (Task 2).
- Produces: `SigV4Signer.sign({..., String? payloadHash})`. When non-null it replaces `hexSha256(payload)`.

- [ ] **Step 1: Write the failing tests.**

```dart
test('a precomputed payload hash signs identically', () {
  final direct = SigV4Signer.sign(/* the AWS vector's fields */);
  final given = SigV4Signer.sign(
    /* the same fields */,
    payloadHash: SigV4Signer.hexSha256(payload),
  );
  expect(given, direct);
});
test('a large PUT carries the same content hash header', ...);
//   s3_api_client_test: capture the request of a 512 KiB upload; expect
//   x-amz-content-sha256 == SigV4Signer.hexSha256(body).
```

- [ ] **Step 2: Run the tests to verify they fail.**

Run: `flutter test test/core/services/cloud_storage/s3/sigv4_signer_test.dart`
Expected: FAIL on the missing `payloadHash` parameter.

- [ ] **Step 3: Implement.** Add a top-level `_payloadHash(Uint8List)` in `s3_api_client.dart` that calls `runOffIsolate` with `bytes: payload.length`, and call it from `_send`.

- [ ] **Step 4: Run the tests to verify they pass.**

Run: `flutter test test/core/services/cloud_storage/s3/`
Expected: all pass.

- [ ] **Step 5: Commit.** `feat(sync): hash large S3 bodies off the UI isolate`

---

### Task 9: Git write

**Files:**
- Modify: `lib/core/services/cloud_storage/git/git_object_id.dart`
- Modify: `lib/core/services/cloud_storage/git/pack_writer.dart`
- Modify: `lib/core/services/cloud_storage/git/git_branch_session.dart:495,523`
- Test: `test/core/services/cloud_storage/git/pack_writer_test.dart`

**Interfaces:**
- Consumes: `runOffIsolate`, `kOffIsolateMinBytes` (Task 2).
- Produces:

```dart
Future<GitObjectId> hashGitObjectOffIsolate(GitObjectType type, Uint8List body);
Future<Stream<List<int>>> preparePack(
  List<PackEntrySource> entries, {
  @visibleForTesting int minBytes = kOffIsolateMinBytes,
});
```

- [ ] **Step 1: Write the failing tests.**

```dart
test('a pack built off-isolate is byte-identical to writePack', () async {
  // 1 MiB JSON-like blob plus a commit, as PackEntrySource.bytes.
  final direct = await _collect(writePack(entries));
  final prepared = await _collect(await preparePack(entries));
  expect(prepared, direct);
});
test('a small pack streams as it does today', ...);
//   preparePack(small) yields more than one event, the shape writePack gives.
test('a file-backed entry streams and reads back', ...);
test('a pack over the threshold reads back through readPack', ...);
test('hashGitObjectOffIsolate matches hashGitObject at and under the threshold', ...);
```

- [ ] **Step 2: Run the tests to verify they fail.**

Run: `flutter test test/core/services/cloud_storage/git/pack_writer_test.dart`
Expected: FAIL on the missing functions.

- [ ] **Step 3: Implement.** `preparePack` returns `writePack(entries)` when any entry is file-backed or the total of `entry.size` is under `minBytes`. Otherwise `Stream.value(await runOffIsolate(() => _collectPack(entries), bytes: total))`, with `_collectPack` a top-level function. `writePack` is not touched. In `git_branch_session.dart`, `_bytesPut` calls `hashGitObjectOffIsolate`, and `_pushCommit` awaits `preparePack` for `pack:`. Commit hashing stays inline, since a commit is tiny.

- [ ] **Step 4: Run the tests to verify they pass.**

Run: `flutter test test/core/services/cloud_storage/git/`
Expected: all pass, including the `git` CLI interop tests where the tool is present.

- [ ] **Step 5: Commit.** `feat(sync): hash and pack large Git writes off the UI isolate`

---

### Task 10: Git read

**Files:**
- Modify: `lib/core/services/cloud_storage/git/git_object_store.dart:173`
- Modify: `lib/core/services/cloud_storage/git/git_pack_spool.dart:60`
- Test: `test/core/services/cloud_storage/git/git_object_store_test.dart`
- Test: `test/core/services/cloud_storage/git/git_pack_spool_test.dart`

**Interfaces:**
- Consumes: `runOffIsolate` (Task 2).
- Produces: `FileGitObjectStore.unindexed(Directory root)`, which starts from an empty index and never scans. `readSpooledPack` gains `@visibleForTesting int offIsolateMinBytes = kOffIsolateMinBytes`.

- [ ] **Step 1: Write the failing tests.**

```dart
// git_object_store_test.dart
test('an unindexed store reads objects already on disk', ...);
test('an unindexed store does not scan its directory', ...);
//   a stale .tmp file older than an hour survives a put; a normal store's
//   scan would have swept it.
test('a main store adopts what an unindexed store wrote', ...);
test('adopted objects count toward the main store size', ...);
//   a main store with a low maxBytes trims after an unindexed store's puts.

// git_pack_spool_test.dart, on a fixture pack with offIsolateMinBytes: 0
test('a file store reads a pack through a worker', () async {
  final store = FileGitObjectStore(tempDirForTest('git_store_'));
  final ids = await readSpooledPack(_pieces(_fixture('full.pack'), 333), store,
      directory: dir, offIsolateMinBytes: 0);
  expect(ids, await readPack(_fixture('full.pack'), MemoryGitObjectStore()));
  for (final id in ids) { expect(await store.get(id), isNotNull); }
  expect(dir.listSync(), isEmpty);
});
test('a thin pack resolves against an object the main store holds', ...);
test('a corrupt pack raises GitException through the worker', ...);
test('a memory store still reads inline', ...);
test('a pack of objects already stored leaves one copy and no temp file', ...);
//   read the same pack twice, into one store, then count files; none end in .tmp.
```

- [ ] **Step 2: Run the tests to verify they fail.**

Run: `flutter test test/core/services/cloud_storage/git/git_object_store_test.dart test/core/services/cloud_storage/git/git_pack_spool_test.dart`
Expected: FAIL on the missing constructor and parameter.

- [ ] **Step 3: Implement.** `unindexed` seeds `_index = Future.value({})`, so `_entryFor` adopts by `stat`. The worker never calls `trim`. In `readSpooledPack`, when `store is FileGitObjectStore`, call `runOffIsolate` with `bytes: await file.length()` and `isExpected: (e) => e is GitException`, around a top-level `_readPackInWorker(String packPath, String storeRoot, int limit)`, which builds `FileGitObjectStore.unindexed` and calls `readPackFile`. Any other store takes today's path. Update the doc comment on the store about the worker.

- [ ] **Step 4: Run the tests to verify they pass.**

Run: `flutter test test/core/services/cloud_storage/git/`
Expected: all pass, including `git_large_download_test.dart`.

- [ ] **Step 5: Commit.** `feat(sync): read large Git packs off the UI isolate`

---

### Task 11: Finish, and capture the after numbers

**Files:**
- Modify: `lib/core/services/sync/sync_service.dart:2206-2210,2262-2266`
- Delete: `tool/bench_3829.dart`, `tool/bench_3829_frames.dart`

**Interfaces:**
- Consumes: `before.txt`, `before_frames.txt` (Task 1).
- Produces: `<scratchpad>/bench3829/after.txt`, `after_frames.txt`, and the before and after table for the PR.

- [ ] **Step 1: Update the two stale comments in `sync_service.dart`.** Both say the whole-file SHA-256 runs on the main isolate and that folding it in is a deferred follow-up.

- [ ] **Step 2: Rerun the Task 1 harnesses.** Same machine, same commands, writing `after.txt` and `after_frames.txt`. The frames harness gets the changed sink's `openHasher` default automatically.

Expected: largest gap under 8 ms on every moved path, except native AES on macOS, which stays as it is. Per spec decision 6, a miss is explained in the PR rather than blocking it.

- [ ] **Step 3: Delete the harness files.** Confirm `git status` does not list them.

- [ ] **Step 4: Run the whole affected surface.**

Run: `dart format .`, `flutter analyze`, then `flutter test test/core/services/sync test/core/services/cloud_storage test/core/utils test/architecture test/shared`
Expected: analyze clean, every test passes.

- [ ] **Step 5: Commit.** `docs(sync): say the base checksums no longer run on the UI isolate`
