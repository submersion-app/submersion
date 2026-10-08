# Streaming base *publish* — write-side OOM fix (#358)

Date: 2026-06-30
Branch: `worktree-issue-358-publish-base-oom-streaming`
Status: Design approved (scope: memory-safe publish only)

## Problem

Enabling cloud sync on iOS still crashes the app on a large library, even after
the two read-side streaming fixes shipped (PR #365 pull-base, PR #398
Replace-adopt, both in v1.5.8). The reporter's iPhone gets *past* the download
now, then dies during the **upload/publish** phase.

### Root cause

`ChangesetWriter.publish()` publishes this device's own per-device base whenever
it has never published to the current backend (`hasBase == false`). That is
exactly the state of a **fresh device that just cold-pulled a large library**:
after the streamed pull, its local DB holds the whole library, and on the next
`performSync` it takes the `!hasBase` branch and re-materializes the entire
library in RAM to publish its base:

1. `_serializer.exportChangeset(hlcWatermark: null)` → `_buildSyncData(null)`
   builds the full 39-table object graph in memory, then `jsonEncode` produces
   the full `dataJson` string.
2. `_codec.encodeChangeset(payload)` re-encodes the whole thing to one
   `Uint8List fullBytes`.
3. `BaseChunker.slice(fullBytes)` copies it again into 8 MB parts.
4. `parts.map(BaseChunker.checksum)` hashes each.

All held simultaneously → object graph + full JSON string + `fullBytes` + parts
≈ 3–4× the base size. `_compact()` has the identical shape.

This write side was **explicitly deferred** in the 2026-06-20 read-side design
("Write side | Out of scope (tracked follow-up) | Publisher also holds the whole
serialized DB, but has desktop headroom and is not the reported crash"). The
missed case: the publisher is not always a roomy desktop — a phone that ingests
a big library becomes a publisher too.

### Evidence

The macOS publisher's `local_publish_states` row for the reporter's library:

```
provider=s3  base_seq=1  base_part_count=78  base_bytes=648190516  head_seq=1
```

`base_bytes = 648,190,516` is literal proof `exportChangeset(null)` yields one
~648 MB base (78 × 8 MB parts). Library is ~1.86 M time-series rows
(1,077,216 `dive_profiles` + 784,752 `tank_pressure_profiles`) across 1,032
dives. A 648 MB base materialized 3–4× exceeds iOS's per-process jetsam limit;
the macOS publisher survived only on desktop RAM headroom.

## Goal / non-goals

- **Goal:** publish (and compact) a base of any size with peak memory bounded to
  one page of rows + one 8 MB part buffer, independent of library size.
- **Non-goal (this PR):** avoiding the redundant self-base upload (a freshly
  cold-pulled device still uploads its own full base — just without crashing).
- **Non-goal:** binary/`VACUUM INTO` base format; apply-path CPU work already in
  flight on the `s2`/`s3` worktrees.

## Approach — mirror the read side, in reverse

The read side streams cloud → file → DB via two components. This adds their
write-side mirrors so the pipeline is symmetric:

| Read side (exists) | Write side (new) | Boundary |
| --- | --- | --- |
| `BasePartFileSink` — download parts → temp file, verify per-part + whole checksums | **`BasePartFileSource`** — read temp file in 8 MB slices → yield each part + its `sha256:` checksum + the whole-file checksum, for upload | transport ↔ file |
| `BaseJsonStreamReader` — stream file → rows | **`SyncDataSerializer.exportBaseToTempFile(...)`** — stream DB rows → payload-JSON temp file | file ↔ DB |

`ChangesetWriter` stops calling `exportChangeset` → `encodeChangeset` →
`BaseChunker.slice` at its two base sites and instead calls
`exportBaseToTempFile` then streams parts from `BasePartFileSource`.

### Decisions

| Decision | Choice | Why |
| --- | --- | --- |
| Wire format | Unchanged JSON | Hard constraint carried from the read-side fix: old bases must import without a forced re-publish, and existing readers must not change. Same `SyncPayload.toJson` structure, keys, and per-row encoding. |
| Correctness anchor | **Semantic / round-trip parity** (not byte-identity) | Rows are streamed in `id` order (keyset), which reorders each table's array vs. today's rowid-order `.get()`. That is safe: each base is verified only against **its own** manifest checksums — no reader compares one device's base bytes to another's — so reordering rows within a base has zero fleet impact, and `baseBytes` is even numerically identical (same rows, same separators). Parity is proven by (a) parse-and-compare per table as id-keyed sets, and (b) publish→pull→compare-DBs round trip. |
| DB passes | **One** | The payload's internal `checksum` field precedes `data` but is a fixed-width 64-char hex digest, so its byte span is reserved as a placeholder, `data` is streamed+hashed once, then the placeholder is patched via `RandomAccessFile.setPosition`. The base read path does not verify this field (`validateChecksum` covers changesets only), but keeping it valid over the actual `data` bytes is cheap and well-formed for any consumer. |
| Row streaming | **Keyset pagination by `id`** for the 36 `id`-PK tables (page ~1–2k rows); full-load via existing `_exportX(null)` for the 3 composite/keyed tables | Keyset is O(n) (offset would be O(n²) on million-row tables). A base exports *all* rows (`hlcSince == null`), so no per-table HLC-filter logic is needed. The 3 non-`id` tables (`diveEquipment` `{diveId,equipmentId}`, `equipmentSetItems` `{setId,equipmentId}`, `settings` `{key}`) are junction/settings tables that are inherently small, so full-loading them keeps peak memory bounded. |
| BLOB tables | `media`, `certifications`, `diveDataSources` use `_syncBlobSerializer` (base64) as today; all three have `id` PKs so they are keyset-paged (BLOBs can be large) | These are the only `_exportX` methods that pass the blob serializer; the streaming path must pass it for exactly these three so per-row bytes are unchanged. |
| Snapshot consistency | Match existing semantics (no long-held read txn) | Today's `_buildSyncData` runs each table's `.get()` as an independent query, so cross-table consistency is already best-effort; keyset paging preserves the same characteristics without holding a multi-minute WAL read open on a phone. |
| Temp file | `Directory.systemTemp`, unique per `deviceId+seq`, deleted in `finally` | Same policy as the read-side sink: not backed up, survives a killed prior run via overwrite. |
| Internal `checksum` field | Kept valid (byte-identical) though the base read path does not verify it | Base reads verify integrity via the manifest `BaseChunker` checksums, not `SyncPayload.checksum` (`validateChecksum` at `changeset_reader.dart:117` covers changesets only). Keeping it valid is belt-and-suspenders for any legacy monolithic reader. |

## `exportBaseToTempFile` mechanics

Produces exactly `jsonEncode(SyncPayload.toJson())` for the base payload, in one
bounded pass:

1. Open a `RandomAccessFile` at a unique temp path.
2. Write the header prefix in `SyncPayload.toJson` key order:
   `{"version":1,"exportedAt":<ts>,"deviceId":"<id>","lastSyncTimestamp":<n|null>,`
   then `"checksum":"<64 placeholder chars>"` (record the byte offset).
3. Write `,"data":{`. For each of the 39 tables **in `SyncData.toJson` order**:
   emit `"<jsonKey>":[`, then stream the table's rows, emitting comma-joined
   `jsonEncode(row)`; emit `]`. Row sourcing:
   - 36 `id`-PK tables: keyset page by `id` —
     `SELECT * FROM "<actualTableName>" WHERE id > ? ORDER BY id LIMIT ?`
     via `customSelect`, mapping each `QueryRow` back through the table's own
     `map(row.data).toJson(serializer: …)` (blob serializer for `media`,
     `certifications`, `diveDataSources`; plain otherwise). Cursor = last row's
     `id`; stop when a page returns < the limit.
   - 3 composite/keyed tables (`diveEquipment`, `equipmentSetItems`,
     `settings`): reuse the existing `_exportX(null)` once (small tables).
   A running SHA-256 hashes the `data` object's bytes as written; a running max
   tracks `toHlc` from any row's `hlc` string.
4. Write `},"deletions":<jsonEncode(groupedDeletions)>,"uploadNonce":<…>,`
   `"epochId":<…>,"seq":<…>,"baseSeq":null,"sinceHlc":null,"toHlc":<…>}`.
5. `setPosition(checksumOffset)` and overwrite the placeholder with the real
   64-char digest of the `data` bytes. Close.

Returns the temp path plus the metadata `ChangesetWriter` needs for the manifest
(`exportedAt`, `toHlc`, `byteLength`). `exportedAt` stays in the leading bytes so
the adopt path's 64 KB-prefix `_readBaseExportedAt` still finds it.

Peak memory: one page of rows + JSON for that page. Independent of library size.

## `BasePartFileSource` + `ChangesetWriter` wiring

`BasePartFileSource` opens the temp file and yields successive 8 MB slices; for
each it computes the `sha256:` part checksum, and it maintains the whole-file
`sha256:` checksum across all slices — the same values `BaseChunker.checksum`
would produce for the equivalent in-memory parts. `ChangesetWriter.publish()`
(`!hasBase` branch) and `_compact()`:

1. `path, meta = await _serializer.exportBaseToTempFile(...)` (in `finally`,
   delete the temp file).
2. For each part from `BasePartFileSource(path)`: `provider.uploadFile(partBytes,
   basePartName(deviceId, seq, i))`, collecting per-part checksums.
3. Build `SyncManifest` with `basePartCount`, `baseBytes = meta.byteLength`,
   `baseChecksum = source.wholeChecksum`, `basePartChecksums`,
   `publishedHlcHigh = meta.toHlc` — identical fields to today.
4. Upsert `local_publish_states` and (compact only) prune superseded files.

The empty-payload `noop` short-circuit is preserved: if the export would be
empty, publish nothing (checked before writing the temp file).

## Testing

Mirrors the parity-test culture of the two read-side fixes.

- **Semantic parity unit test:** parse `exportBaseToTempFile`'s output and the
  old `exportChangeset(deviceId, hlcWatermark: null, …)` payload, and assert
  equality **per table as id-keyed sets** (order-independent) plus equal header
  fields (with `exportedAt` fixed via an injected `now`), for a library
  exercising: parent/child/junction rows, all three BLOB tables, empty tables,
  and **more than one page** (> the page size, e.g. 2.5k rows in a time-series
  table) to cross a keyset boundary. Also assert the internal `checksum` equals
  `_computeChecksum` over the streamed `data` bytes.
- **Checksum/manifest self-consistency:** `BasePartFileSource` over the temp
  file yields a whole-file `sha256:` checksum equal to `BaseChunker.checksum` of
  the reassembled parts, per-part checksums matching each 8 MB slice, and
  `baseBytes` == the temp file length — the exact fields the manifest carries.
- **Round-trip test:** publish a library through the streaming path into a fake
  provider, then read it back through the existing `pull` / `_applyRemoteBaseFile`
  into a second DB and assert the two DBs are identical.
- **Bounded-memory / structural proof:** assert the streaming path never calls
  `_buildSyncData` (no full-graph build) and that a large synthetic library
  pages (multiple keyset windows) rather than one `.get()`.
- **Compaction:** a base rewritten by `_compact()` via the streaming path equals
  the in-memory-equivalent base.
- **Device verification:** on the booted simulator (B3558678-…) against the S3
  library — pull completes, then publish completes without crash/hang; the
  published `base_bytes` / `base_part_count` match the macOS publisher's.

## Out of scope / follow-ups

- **Skip redundant self-base publish:** a device that just cold-pulled with no
  local-only changes still uploads its own full (now memory-safe) base. Avoiding
  that upload is a separate sync-semantics change (deferred by scope choice).
- **Binary base format** (`VACUUM INTO`): smaller and fixes read+write, but
  breaks the "old JSON bases stay importable" constraint. Rejected here.
- **Apply-path CPU/throughput** (batched merge writes, isolate parse): already
  in flight on the `s2`/`s3` worktrees; untouched by this PR.

## Affected files

- New: `lib/core/services/sync/changeset_log/base_part_file_source.dart`
- New: streaming export on `SyncDataSerializer` (method + keyset row source;
  possibly a small `base_source_file_writer.dart` helper to keep the serializer
  focused).
- Edit: `lib/core/services/sync/changeset_log/changeset_writer.dart` (both base
  sites).
- Tests: parity + round-trip + compaction, alongside the existing
  `sync_*_parity_test.dart` suite.
