# Sync base-part processing off the UI isolate

Issue: #3829. Release: v1.8.4.

## Intent

A cloud base transfer does its CPU work on the isolate that called sync, which
in the app is the UI isolate. Scrolling or typing during a base publish,
compaction, resume or download can stutter, even though SQLite and base parsing
already have worker isolates.

The issue reports the SHA-256 work: about 81 ms per 8 MiB part. Investigation
found further stalls on the same path, in encrypted sync and inside the S3 and
Git providers, some of them longer than the hashing. The goal of this work is
that no single step of part processing visibly blocks the UI isolate, whichever
provider is in use and with or without encryption.

Investigation also found that a failed base fetch during adopt or the retirement
fence can be read as "the cloud has no library". This work adds a new way for a
fetch to fail, so it closes that gap too.

## Measured baseline

From a throwaway AOT build on an Apple M5 Pro, with 8 MiB parts of JSON-like
data. These are host component timings, not app frame timings.

| Step | Blocks the calling isolate for |
| --- | --- |
| Whole-file plus per-part SHA-256 | about 88 ms per part |
| One SHA-256 over 8 MiB (SigV4 payload hash on a plain S3 part) | about 44 ms |
| `gzip.encode` in `SyncEnvelope.seal` | 95 to 120 ms per part |
| Pure Dart AES-GCM on the gzipped payload (Windows, Linux) | 110 to 125 ms per part |
| Pure Dart AES-GCM on an incompressible 8 MiB payload | 450 to 510 ms per part |

The S3 row is half of the measured pair, not its own measurement. Not yet
measured: `inflateBounded`, Git's SHA-1 and deflate on write, and Git's trailer
SHA-1 and pure Dart inflate on read.

Compared options for the SHA-256 work, 32 MiB total:

| Option | Total | Largest event-loop gap |
| --- | --- | --- |
| Inline | about 350 ms | about 88 ms per part |
| Worker isolate | about 350 ms | 1.4 ms |
| 64 KiB slices on the calling isolate | about 353 ms | 2.0 ms |

`Isolate.spawn` to first reply took 0.04 ms at the median.
`TransferableTypedData.fromList` on 8 MiB took 0.39 ms.

The backend for `AesGcm.with256bits()` differs by platform. On Android, iOS and
macOS `cryptography_flutter` registers and calls platform APIs. Its handlers
contain no threading code, so they run on the platform thread, which current
Flutter is likely to share with the UI thread on mobile. Hardware AES is
expected to take a few milliseconds per part, but that is unmeasured. On Windows
and Linux no plugin registers, so AES-GCM is pure Dart on the calling isolate.

## Goals

- Move both SHA-256 operations for base parts off the calling isolate, for
  upload and download.
- Move gzip, inflate and pure Dart AES-GCM for large envelopes off the calling
  isolate.
- Move the S3 SigV4 payload hash for large bodies off the calling isolate.
- Move Git's blob hash, pack writing and pack reading for large payloads off the
  calling isolate.
- Stop a local fault or a network failure during a base fetch from being read as
  "the cloud has no library" in adopt, the retirement fence and replace-join.
- Produce the same bytes as today: identical part digests, whole-file digest and
  envelope format, so old and new builds interoperate in both directions.

## Non-goals

- Any change to part size, manifest format or the SBE1 envelope format.
- Any change to what is uploaded, in what order, or to progress reporting.
- Moving file reads, file writes or HTTP I/O off the calling isolate. They are
  already asynchronous.
- Moving the row-sized hash in `exportBaseToTempFile`, which yields on every
  write.
- Moving native AES-GCM on Android, iOS and macOS off the platform thread. Pure
  Dart in a worker would be slower overall, and on those devices it would replace
  hardware AES.
- Changing how pull treats a failed fetch.
- File-backed Git writes, which already stream in small chunks. Only backups use
  them, not base parts.

## Anti-goals

These would make the work a failure even if the numbers improved.

- A digest or envelope that differs from today's for the same input.
- Weakened corrupt-part rejection, or a path that certifies bytes it did not
  hash. Skipped parts on resume are still read and hashed.
- Memory that grows with base size. At most one part is in flight.
- A failed isolate that fails or corrupts a sync that would have worked before.
- A hang. The long-lived worker has a timer on every wait. One-shot isolates run
  CPU-bound work on data they already hold, so they cannot wait on anything, and
  `Isolate.run` reports an isolate that exits.
- Slower pure Dart cryptography on devices that have hardware AES today.

## Decisions

Made by the maintainer in the design conversation:

1. **Scope is the whole path:** checksums, gzip, inflate, and AES-GCM on Windows
   and Linux, plus the S3 and Git provider stalls.
2. **Checksums use a worker isolate,** not time slices on the UI isolate.
3. **A worker that dies mid-transfer fails the transfer,** and the next sync
   retries. There is no inline catch-up.
4. **A failed base fetch aborts adopt, the fence and replace-join.** Both a dead
   worker and a download error abort with a sync error, and the next sync
   retries. Missing or corrupt cloud data still skips that device as today. Pull
   keeps its current behaviour.
5. **Profiling evidence** is AOT before and after numbers using the production
   classes with a no-op transport, plus frame times from a macOS profile build
   while a list scrolls. The harness is throwaway. Results go in the PR.
6. **The 8 ms target does not block the PR.** The numbers must be in the PR, and
   a miss is explained there for the maintainer to judge.

## Design

### One-shot off-isolate helper

Gzip, inflate, pure Dart AES-GCM, the S3 payload hash, the Git blob hash, pack
writing and pack reading share one helper, in `lib/core/utils/`:

```dart
const int kOffIsolateMinBytes = 256 * 1024;

/// Runs [work] in a one-shot isolate when [bytes] reaches the threshold, and
/// inline otherwise. Any failure [isExpected] does not recognize reruns [work]
/// inline.
Future<T> runOffIsolate<T>(
  FutureOr<T> Function() work, {
  required int bytes,
  bool Function(Object error) isExpected,
});
```

Rules:

- **Expected errors are rethrown.** They are real answers about the data:
  `BoundedInflateException` and `SecretBoxAuthenticationError` for the envelope,
  `GitException` for pack reading.
- **Anything else reruns inline.** That covers `IsolateSpawnException`,
  `RemoteError`, and a message that cannot be sent. None of this work holds
  rolling state, so nothing is lost by repeating it.
- **Work functions are top-level or static,** taking only what they need. A
  closure declared inside `seal` or `open` can capture the surrounding context,
  including the key, and fail to send or copy far more than intended.
- **The helper and the classes it serves stay free of Flutter imports,** so the
  profiling harness can use `dart compile exe`.

Inflate and pack reading are judged on compressed bytes, though they cost what
the output costs, so they use the threshold divided by `kCompressedCostFactor`,
8. The threshold is one named constant. Below it the work takes roughly 3 ms or less
on the measured host, and the isolate spawn buys nothing. It also keeps small
manifests, changesets and markers on the calling isolate and in the calling zone.
The value is the designer's call and may change if profiling argues otherwise.
Pure Dart AES-GCM costs about eight times as much per byte, some 60 ms per MiB, so
the envelope gives it one eighth of the threshold.

### Part hasher

A new abstraction, `BasePartHasher`, owns the rolling whole-file SHA-256 and the
per-part SHA-256 for one transfer:

```dart
abstract interface class BasePartHasher {
  /// Adds [part] to the whole-file hash and returns its `sha256:<hex>` digest.
  Future<String> addPart(Uint8List part);

  /// Completes the whole-file hash and returns its `sha256:<hex>` digest.
  Future<String> finish();

  /// Releases the worker, if any. Safe after a failure, and safe to repeat.
  Future<void> dispose();
}
```

There are two implementations:

- **Inline:** today's code, on the calling isolate.
- **Worker:** one isolate per transfer, shaped like `BaseParseClient`: handshake
  on spawn, sequential request and reply. The main isolate sends each part as
  `TransferableTypedData`, so the caller keeps its own `Uint8List` for upload or
  writing. The worker holds the rolling hash state. Its reply is the part digest.
  A final message returns the whole-file digest.

A factory picks one from the size of the first part:

```dart
Future<BasePartHasher> openBasePartHasher({required int firstPartBytes});
```

The first part is always the largest, so its size is a safe proxy for the
transfer. Below `kOffIsolateMinBytes` the inline hasher is used and no isolate
spawns. At or above it, a worker spawns. A spawn or handshake failure falls back
to the inline hasher, which is the same behaviour as today. The fallback logs a
warning, as the base-parse fallback does.

Injectable test hooks are constructor or function parameters, not mutable
statics, so tests have no process-wide state to restore.

**Liveness.** An isolate exit listener and error port fail an in-flight request
immediately. A timeout on each request is the backstop, 60 seconds to match
`BaseParseClient.messageTimeout`. One part is small enough that no heartbeat is
needed.

**Failure.** After a successful spawn, a failed request throws
`BasePartHasherException`, and every later call on that hasher throws too. It
never falls back, because the rolling state is gone.

### BasePartFileSource

`uploadAll` opens the hasher once the file length is known, then replaces
`whole.add(buf)` and `BaseChunker.checksum(buf)` with `await hasher.addPart(buf)`.
The order is unchanged: hash, then upload, then the progress tick. Skipped parts
are still read and hashed. An empty file still yields one empty part. The hasher
is disposed in the existing `finally` alongside the file handle.

A worker failure propagates like an upload failure. In the first-base and forced
paths the writer keeps the export and its record, and the next attempt resumes
by skipping parts already in the cloud. Compaction has no resume, so it starts
again on the next run. That is accepted.

### BasePartFileSink

`assemble` opens the hasher after the first part lands, because that is when the
size is known. Each part goes through `await hasher.addPart(part)`, and the
returned digest is compared with the manifest's. The whole-file comparison uses
`finish()`. The hasher is disposed on every exit path, including when
`downloadPart` returns null before a hasher exists.

A part past the end of `partChecksums` is still added to the whole-file hash and
its digest is ignored, as today.

### What a failed fetch means

`assemble` currently turns every failure into null. Its callers read null
differently. Pull is additive, so it skips the peer and retries. Adopt, the fence
and replace-join are delete-all-refill, so `_collectEpochBaseSources` skips the
device, and if no device is left the fence drops this device's retirement marker
and republishes from local, as if the cloud held no library. A dropped connection
can reach that today.

`assemble` splits the outcomes:

- **Returns null,** after deleting the temp file, for a statement about the cloud
  data: `downloadPart` returned null, a digest mismatch, `EnvelopeCorruptException`
  or `SyncEncryptionRequired`.
- **Throws `BaseFetchInterrupted`,** after deleting the temp file, for everything
  else: `BasePartHasherException`, and any other error from `downloadPart`. It
  carries the cause.

Epoch recovery reads manifests the same way. `_epochHasReadableLibrary` answers
whether a library exists, and a "no" past the grace window ends in
`_reestablishEpochFromLocalLibrary`, which deletes every sync file. So it shares
one rule with `_collectEpochBaseSources`: a manifest that could not be fetched
propagates, and one the cloud holds but this device cannot use is skipped.

The callers then behave like this:

- **`ChangesetReader`:** catches `BaseFetchInterrupted` around `_fetchBaseToFile`
  and handles it exactly as it handles null today, so pull's behaviour and its
  reported `incompletePeerDeviceIds` do not change.
- **`_collectEpochBaseSources`:** treats a manifest it could not fetch the same
  way, while one the cloud holds but this device cannot use still skips the
  device. On any failure it deletes the temp files it has already assembled, then
  lets the exception propagate. Adopt and the fence end as a sync
  error, the markers and local state are untouched, and the next sync retries.
- **Replace-join:** `prepareReplaceJoin` must turn it into a failed attempt that
  changes nothing, not an uncaught error. Its existing handling of a failed
  attempt is the model.

### Envelope seal and open

`SyncEnvelope` keeps its signature and output.

- **Gzip** in `seal` and **inflate** in `open` go through `runOffIsolate`.
  `BoundedInflateException` is expected, so it still reaches the existing catch
  in `open` and becomes `EnvelopeCorruptException`.
- **AES-GCM** keeps `AesGcm.with256bits()`. When that resolves to `DartAesGcm`,
  which is the Windows and Linux case, encrypt and decrypt go through
  `runOffIsolate` with raw key bytes and a `DartAesGcm` built in the worker. When
  it resolves to anything else, it is called as today, so Android, iOS and macOS
  do not change. `SecretBoxAuthenticationError` is expected, so a failed
  authentication is never retried or masked.

Raw key bytes reach a short-lived isolate in the same process. That adds no new
trust boundary, because isolates share an address space.

### S3

`SigV4Signer.sign` gains an optional precomputed `payloadHash`. `_send` in
`s3_api_client.dart` computes it through `runOffIsolate` for a large body and
passes it in. The hash value is identical, so the signature is identical. Small
requests take the existing path. The signing key derivation stays inline, since
it is a handful of short HMACs.

### Git write

Two steps change, both in `git_branch_session.dart`:

- `_bytesPut` hashes a large body through `runOffIsolate` instead of calling
  `hashGitObject` directly.
- `_pushCommit` runs `writePack` inside `runOffIsolate` when every entry is held
  in memory and their total size reaches the threshold, collects the output, and
  passes it to `transport.push` as a one-event stream. `writePack` itself does not
  change, so the pack format, the Adler and SHA-1 trailers and the push protocol
  cannot drift. A pack with a file-backed entry streams as it does today.

Memory stays bounded: a pack holds one part plus its small tree, index and commit
objects. Each push retry rebuilds the pack, as it does today.

### Git read

`readSpooledPack` already writes the pack to disk before parsing it, so the whole
of `readPackFile` runs through `runOffIsolate` when the file reaches the threshold
and the store is a `FileGitObjectStore`. A `MemoryGitObjectStore` cannot cross an
isolate boundary and stays inline. `GitException` is expected. Any other failure
reruns inline on the same spool file, which is safe because objects are addressed
by content.

The worker needs a store on the same directory. `FileGitObjectStore` documents
that stores on one directory share files and adopt each other's objects on first
use, but a new store scans its whole directory, which takes seconds on a full
cache and would run once per pack. A new constructor, for example
`FileGitObjectStore.unindexed(root)`, starts with an empty index and never trims.
`_entryFor` already adopts files by `stat`, so reads and writes behave the same
without the scan.

Eviction stays with the main store, and only it runs `trim`. It is asked about
every object in the pack as soon as the read returns, which adopts them, so its
size accounting stays correct even when a session reads only one of them.

### Comments to update

`sync_service.dart` says twice that the whole-file SHA-256 still runs on the main
isolate and that folding it in is a deferred follow-up. Both become false. The
class comments on the source and sink should say where the hashing runs. The
`assemble` doc comment should state the null and throw split.

## Testing

Timing tests would be flaky on CI, so automated tests assert structure and bytes.
The timing evidence is the one-off profiling below.

**Helper:** below the threshold it runs inline, at or above it runs on another
isolate, an expected error is rethrown, and a spawn failure or `RemoteError`
reruns inline.

**Hasher, against both implementations:**

- Part and whole digests equal `BaseChunker.checksum` for multi-part input, a
  short final part, and an empty part.
- Input bytes are unchanged and still usable after `addPart`.
- The worker path really ran on another isolate.
- A first part below the threshold does not spawn.
- Spawn failure and handshake timeout fall back to inline with correct digests.
- A worker killed mid-transfer fails the in-flight call promptly, and later calls
  fail too.
- `dispose` is safe after failure and when repeated.

**Source and sink:**

- All existing tests pass unchanged. Those tests are the compatibility contract.
- Skipped-part resume still reports digests for every part.
- A worker failure in the source propagates, no later part is uploaded, and the
  file handle is closed.
- Corrupt-part and whole-file rejection work through the worker path.
- A missing part, a digest mismatch and a corrupt envelope return null.
- A worker failure and a download exception throw `BaseFetchInterrupted`, and the
  temp file is gone.

**Callers of a failed fetch:**

- Pull treats `BaseFetchInterrupted` as it treats null today.
- The fence with an interrupted fetch keeps the retirement marker, republishes
  nothing, keeps local rows, ends in an error, and rejoins on the next sync.
- Adopt with an interrupted fetch ends in an error and does not attempt recovery.
- With two devices, an interrupted fetch on the second deletes the first's temp
  file and aborts, rather than refilling with a device missing.
- A device that is missing or corrupt in the cloud is still skipped.
- Replace-join with an interrupted fetch changes nothing and reports failure.

**Envelope:**

- With `nonceForTest`, an above-threshold seal produces the same bytes as the
  inline path.
- An above-threshold envelope round-trips, and envelopes from either path open
  through the other.
- Wrong AAD and a tampered body still raise `EnvelopeCorruptException`.
- The inflate cap still rejects through the off-isolate path.

**S3:** a signature with a precomputed hash equals the signature from `sign`
computing it, and the existing SigV4 vectors still pass.

**Git:**

- A pack built off-isolate is byte-identical to one built inline.
- An above-threshold pack read through a worker store leaves every object
  readable from the main store, including a delta against an object already there.
- A corrupt pack still raises its `GitException` through the worker.
- An unindexed store adopts existing objects and does not scan.
- The main store's size accounting includes objects a worker wrote.

`flutter test` does not register the plugin, so CI exercises the `DartAesGcm`
path. Tests must run on the real event loop. No `testWidgets` test reaches these
paths today, and the one `fakeAsync` test near them
(`sync_service_epoch_test.dart`) uses a payload far below the threshold, which the
build should confirm.

## Profiling evidence

Run before and after on the same machine.

**AOT component runs** with `dart compile exe`, using the production classes:

- Flows: upload and skipped-part resume, with a no-op transport. Download is
  measured in the macOS profile build instead, because `BasePartFileSink` reaches
  `path_provider` and so cannot compile with `dart compile exe`.
- Modes: plain, encrypted. Under `dart compile exe` no plugin registers, so the
  encrypted run takes the `DartAesGcm` path, which is the Windows and Linux path.
- Providers: `SigV4Signer` on a part, `writePack` on a part, and `readSpooledPack`
  on a part-sized pack.
- Metrics: total time, largest event-loop gap, count of gaps over 8 ms and 16 ms.

**macOS profile build** with a list scrolling during a no-op transfer: frame build
and raster times at p50, p90, p99 and worst, plus missed frames. This run uses
native AES-GCM.

The target is that no part-processing step causes an event-loop gap over 8 ms on
the test machine, on the paths this work moves. The target is the designer's
proposal. Per decision 6, a miss is reported rather than blocking the PR.

The PR must state the limits of this evidence: no phone numbers, and no Windows or
Linux numbers. Encrypted Windows and Linux behaviour is inferred from running the
pure Dart cipher through the same code path. Native AES-GCM stays where it is, so
its time on the platform thread is measured on macOS only. No real provider or
network is involved.

## Left to the builder

- File layout and names, within the 200 to 400 line norm and alongside the
  existing `changeset_log`, `s3` and `git` files.
- The worker's message shapes.
- The exact shape of `FileGitObjectStore.unindexed`.
- Log wording.
- How `git_branch_session.dart`, already near the 800-line limit at 767 lines,
  makes room for its changes.
