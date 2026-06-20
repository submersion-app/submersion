# Streaming Base Import (iCloud Sync OOM Fix)

Tracking issue: [#358 — iCloud sync on iOS leads to app crash](https://github.com/submersion-app/submersion/issues/358)

## Problem

Enabling iCloud sync on iOS crashes the app ~20 s after startup for a user with
a large library. The user enabled sync on macOS first (which published a base),
then on iOS (which crashes adopting it).

The debug log is conclusive:

```
...ssv1.<uuid>.base.000000000005.p0000 (8388608 bytes)
...p0001 (8388608 bytes)
... (64 parts total = 512 MB)
...p0063 (8388608 bytes)        @ 14:33:24
[~109 s gap, no Dart error, no stack trace]
Initializing notification service @ 14:35:13   <- app relaunched
```

All 64 parts download in ~0.6 s (they are already iCloud-cached on disk, so this
is **not** a network problem), then the app spends ~109 s in pure CPU/RAM work
and is silently relaunched. A silent relaunch with no Dart exception is the
signature of an **OS-level out-of-memory (jetsam) kill**, not a code crash.

### Root cause

Adopting a peer's **base** snapshot materializes the entire database in memory
several times over. The live path is
`performSync()` -> `ChangesetReader.pull()` -> `_fetchBase()` ->
`ChangesetCodec.decodeChangeset()` -> `SyncDataSerializer.deserializePayload()`
-> `SyncPayload.fromJson()`, all on the main isolate. For the ~512 MB base:

| Stage | Code | Resident cost |
|-------|------|--------------|
| Download all parts | `_fetchBase` accumulates `List<Uint8List>` | ~512 MB |
| Reassemble | `BaseChunker.reassemble` allocates one contiguous `Uint8List` | +512 MB (~1 GB peak) |
| UTF-8 -> String | `utf8.decode(full)` | +0.5-1 GB |
| JSON -> objects | `jsonDecode` -> whole-DB `Map`/`List` graph | +1-4 GB |
| Re-encode | `SyncPayload.fromJson` sets `rawDataJson = jsonEncode(data)` | +~512 MB |

Peak is several GB, which exceeds iOS's per-app memory limit (device-dependent,
~1.3-2.8 GB) and triggers a jetsam kill. The macOS publisher survived only
because desktops have far more headroom.

The base is the entire database serialized as one JSON document: `SyncData` holds
38 tables, each a `List<Map<String, dynamic>>`. `DiveProfiles` is **one row per
sample** (`timestamp`, `depth`, `temperature`, ...), so a large library is
*millions of tiny rows* -- which is what makes the base 512 MB and what makes a
streaming/batched apply both necessary and sufficient.

For contrast, DB *restore* of an equally large `.db` works fine because it is a
file-level byte copy (`close -> copy -> reopen`); it never builds a Dart object
graph. Base adoption does the opposite.

## Solution

Import the base with **bounded memory** by streaming it through disk and applying
it in batches, instead of materializing the whole `SyncPayload` in RAM. No
wire-format change (old bases already in users' iClouds must import with no user
action -- we never force a desktop re-publish). The delicate per-record merge
logic is reused unchanged; only how rows are *fed* to it changes.

Key enabling facts discovered during investigation:

- `_mergeEntity` is **per-record and upsert-only** -- no per-entity aggregate
  state beyond read-only precomputed maps, and it never deletes rows absent from
  its input. Therefore feeding a table in N batches produces a byte-identical
  result to one call.
- The merge's only whole-payload coupling is two precomputations
  (`contradicted`, `revivedParents`) that need only **IDs and timestamps**, plus
  the (small) deletions map. The revival scan touches only *parent* tables
  (dives, sites, ...), never the millions of `diveProfiles` rows.
- The manifest's per-part + whole-file checksums verify byte integrity, which is
  strictly stronger than the payload-level data checksum (see existing comment at
  `changeset_reader.dart:146`). So the streaming path can verify bytes during
  download and skip the payload-level `validateChecksum` / `rawDataJson`
  re-encode entirely.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Memory strategy | Stream parts to a temp file; two-pass parse + batched apply | Only option that bounds peak RAM regardless of DB size; un-bricks existing installs with no user action |
| Wire format | Unchanged | Old monolithic-JSON bases already exist in iCloud; "never force a re-publish" is a hard constraint |
| JSON parsing | Hand-rolled boundary scanner that delegates per-row decode to stdlib `jsonDecode` | No third-party dependency in the security-sensitive sync data path; test surface limited to boundary detection |
| Merge logic | Reused unmodified (`_mergeEntity`, `_applyRemoteDeletions`, FK repair) | Per-record + upsert-only, so batching is provably equivalent; avoids touching data-integrity code that accreted many fixes |
| Base integrity check | Manifest per-part + whole-file SHA-256 only; drop payload-level checksum for bases | Byte-level check is stronger; also removes the `rawDataJson` amplifier |
| Apply atomicity | Single existing deferred-FK transaction around the whole base apply | A mid-import kill rolls back cleanly; cursor advances only on success -> safe retry |
| Temp file | `getTemporaryDirectory()`, unique per `deviceId+baseSeq`, deleted in `finally` | Not iCloud, not backed up; survives a killed prior run via overwrite |
| Responsiveness | `Future.delayed(Duration.zero)` yield + progress between batches | Removes the secondary watchdog-kill risk during a long import |
| Which paths stream | Primary: `ChangesetReader._fetchBase` (the reported crash). Fast-follow: `SyncService._collectEpochPayloads` (Replace-adopt) | The merge-base path fixes #358. Replace-adopt shares the reader/sink but needs its own orchestration (replace, not merge), so it is a separable follow-up to keep this PR focused |
| Write side | Out of scope (tracked follow-up) | Publisher also holds the whole serialized DB, but has desktop headroom and is not the reported crash |

## Architecture

Only the **base** adoption path streams. Changesets are per-device deltas (small)
and stay on the existing in-memory path, untouched.

### 1. `BasePartFileSink` (new)

`lib/core/services/sync/changeset_log/base_part_file_sink.dart`

Downloads base parts one at a time and appends each to a temp file, verifying
each part's checksum as it lands and feeding a chunked SHA-256 so the whole-file
`baseChecksum` is verified without ever holding the file in RAM. Holds at most
one ~8 MB part at a time.

```dart
/// Returns the temp file path on success, or null when a part is missing or a
/// checksum fails (transient -> caller retries next sync).
Future<String?> assemble({
  required int partCount,
  required String? wholeChecksum,
  required List<String> partChecksums,
  required Future<Uint8List?> Function(int index) downloadPart,
  required String tempFilePath,
});
```

- Per-part checksum mismatch or missing part -> delete temp file, return null.
- Whole-file checksum mismatch -> delete temp file, return null.
- Pure except for the injected `downloadPart` and the file sink, so tests drive
  it with in-memory parts and a temp path.

### 2. `BaseJsonStreamReader` (new)

`lib/core/services/sync/changeset_log/base_json_stream_reader.dart`

The hand-rolled boundary scanner. Consumes a `Stream<List<int>>` (prod:
`File(path).openRead()`; tests: in-memory bytes). It does **not** parse JSON
values itself; it tracks string/escape state and brace/bracket depth to find the
byte boundaries of each row object inside `data.<table>:[...]`, then hands each
isolated row's bytes to stdlib `jsonDecode`.

Two scan modes:

```dart
/// Header scalars (epochId, version, ...) and the full deletions map, by
/// depth-skipping the giant `data` value. Small.
Future<BaseEnvelope> readEnvelope(Stream<List<int>> bytes);

/// Emits decoded rows one at a time. `wantedTables` lets a pass skip tables it
/// does not need (e.g. Pass A skips diveProfiles).
Future<void> streamRows(
  Stream<List<int>> bytes, {
  Set<String>? wantedTables,
  required Future<void> Function(String entityType, Map<String, dynamic> row) onRow,
});
```

The scanner must correctly handle: string values containing `{ } [ ] , "`,
escaped quotes and backslashes, `\uXXXX` escapes, nested objects/arrays within a
row, rows split across read-chunk boundaries, a single row larger than the read
buffer, empty `data`, missing tables, and extra unknown top-level keys.

### 3. `ChangesetReader` (changed: orchestration only)

`_fetchBase` becomes `_fetchBaseToFile`, returning a temp-file path instead of a
decoded `SyncPayload`. The base branch in `pull()` calls a new injected
`applyBaseFile(path, manifest)` callback instead of `apply(payload)`. The
changeset branch is unchanged. Per-peer `try/catch` and cursor-advance semantics
are unchanged (one bad peer never blocks others; cursor advances only after a
successful apply).

### 4. `SyncService.applyBaseFile` (new orchestration; reuses existing primitives)

Drives the passes and calls the **existing, unmodified** `_applyRemoteDeletions`,
`_mergeEntity`, `repairDanglingForeignKeys`, `_pendingRecordMap`, `_deletionMap`
inside the **existing** `applyInDeferredFkTransaction`:

1. **Envelope/tail scan** (`readEnvelope`): header + full `deletions` (depth-skip
   `data`).
2. **Pass A -- metadata** (`streamRows`, decoding only parent tables and tables
   that appear in `deletions`): build `revivedParents` (parent rows locally
   tombstoned with a newer remote `updatedAt`) and `contradicted` (live ids that
   also appear in this payload's deletions). Skips the millions of profile rows.
3. Open the deferred-FK transaction, then:
   - `_applyRemoteDeletions(deletions, ...)`,
   - **Pass B -- apply** (`streamRows`, all rows): accumulate per-entity batches
     of ~500, call `_mergeEntity` per batch with the precomputed maps, discard
     the batch, yield to the event loop. Sum the `_MergeResult` counters.
   - `repairDanglingForeignKeys()`, commit.
4. `finally`: delete the temp file.

Merge *order* across entities is irrelevant: FK ordering is handled by the
deferred-FK transaction, and revival/contradiction are precomputed in Pass A, so
applying in file order is safe.

### 5. `SyncService._collectEpochPayloads` + Replace-adopt (fast-follow, not this PR)

The Replace-restore adoption path is a *separate* fix with its own orchestration.
It is even more memory-hungry than the merge path: `_collectEpochPayloads` decodes
`List<SyncPayload>` for **every** device, then the consumer (`sync_service.dart`
~1635-1674) holds the entire union of all bases (`restored`) **plus** a full
export of the local DB (`localSnapshot`) in memory simultaneously, and performs a
*replace* (delete local rows absent from the cloud union, then upsert all), not
the LWW merge. So it cannot reuse `applyBaseFile`.

Its streaming form reuses `BasePartFileSink` + `BaseJsonStreamReader` but needs a
distinct orchestration:

1. Pass 1: stream all device base files, collecting `cloudIds` per entity (ids
   only -- bounded even for millions of rows).
2. Stream local ids per entity and `deleteRecord` those absent from `cloudIds`
   (replaces the in-memory `localSnapshot` scan).
3. Pass 2: stream all device base files again in ascending `exportedAt` order and
   `upsertRecord` each row (last write wins -> "latest export wins" for ids in
   several files).

Recommended as an immediate follow-up PR so this PR stays focused on the reported
crash and a smaller review/parity surface. Folding it into this PR is possible if
preferred; flagged for confirmation in spec review.

### Memory profile (512 MB base)

- Download: <= 8 MB resident (one part at a time).
- Envelope + Pass A metadata: deletions + parent id/timestamps (small).
- Pass B apply: one ~500-row batch at a time.

Peak drops from **~4 GB -> tens of MB**, and no longer scales with DB size. Two
to three sequential reads of a local temp file are cheap (sequential I/O + page
cache).

### Explicitly untouched

`_mergeEntity`, `_applyRemoteDeletions`, FK repair, HLC/LWW, tombstone logic, the
changeset path, the wire format, and `BaseChunker`/`changeset_writer` (write side
stays as-is for now).

## Error Handling

- Missing/corrupt part -> base skipped this sync, cursor unchanged, retry next
  sync (identical to today).
- Any throw mid-import -> deferred-FK transaction rolls back the whole base
  apply; no half-imported library; cursor not advanced; clean retry.
- Structurally-malformed base (scanner cannot resolve boundaries, or whole-file
  checksum mismatch) -> abort this peer's base apply, don't advance cursor; other
  peers still process.
- Disk-full / file errors -> propagate to the per-peer `try/catch`; cursor stays
  put.
- Temp file always removed in `finally`; a stale file from a killed run is
  overwritten.

## Testing (TDD -- tests first)

1. **Boundary-scanner units** (highest-risk new code): strings containing
   `{ } [ ] , "`, escaped quotes/backslashes, `\uXXXX`, nested objects/arrays
   within a row, empty `data`, missing tables, extra unknown top-level keys,
   **rows split across read-chunk boundaries** (feed 1-byte and odd-sized
   chunks), and **a single row larger than the read buffer**.
2. **`BasePartFileSink` units**: happy path verifies file + checksum; per-part
   mismatch / missing part / whole-file mismatch each -> null; temp file cleaned
   up.
3. **Parity test (linchpin)**: build one rich `SyncPayload` exercising every
   entity type, media BLOBs, junctions, deletions, contradicted keys, revived
   parents, and a conflict. Apply it two ways into two fresh DBs: existing
   `_applyRemotePayload` (whole-graph) vs. new streaming `applyBaseFile`
   (serialized -> sliced -> reassembled-to-file -> streamed). Assert the two DBs
   are row-for-row identical and the merge counters match. Run at batch sizes
   N=1, N=3, N=infinity to prove batching never changes the outcome.
4. **Convergence**: extend `changeset_sync_convergence_test.dart` so base
   adoption routes through the streaming path and two devices still converge.

The parity test is what guarantees "bounded memory" did not change behavior by a
single row.

## Out of Scope / Follow-ups

- **Replace-adopt streaming** (`_collectEpochPayloads` + the Replace consumer):
  same OOM class on the Replace-restore path, but a distinct orchestration
  (replace, not merge). Reuses `BasePartFileSink` + `BaseJsonStreamReader`.
  Recommended as the immediate next PR (see Architecture section 5).
- **Write-side streaming** (publisher OOM on very large libraries): the macOS
  writer holds the whole serialized DB via `BaseChunker.slice(fullBytes)` in
  `changeset_writer`. Track as a separate issue; candidate fix is a
  streaming/`VACUUM INTO`-based base writer.
- **Raw-SQLite-file base format** (binary, smaller, fixes read+write): rejected
  for this fix because old JSON bases must remain importable without a re-publish,
  which requires the streaming JSON reader anyway. Possible future write-side
  optimization layered on top.
