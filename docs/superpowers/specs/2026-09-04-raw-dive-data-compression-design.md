# Compressing Raw Dive Computer Data at Rest

**Issue:** [#227](https://github.com/submersion-app/submersion/issues/227)
**Date:** 2026-09-04

## Problem

`dive_data_sources.raw_data` holds the raw per-dive bytes libdivecomputer
handed back at download time. Those bytes are what makes re-parse possible
after a libdivecomputer fix (#224, #226, #478), so they are kept forever and
are the sole recoverable copy of a download. They are stored uncompressed.

The 2026-04-15 raw-data spec ruled compression out of scope with the
rationale "dive blobs are 1-50 KB; compression adds complexity for negligible
savings". Two things have changed since:

1. That verdict was calibrated on small blobs. Measured against the repository's
   own libdivecomputer fixtures, real dives compress well (see below).
2. The profile-series work (#1387, #1406) cut the row-per-sample tables from
   751 MB to 35 MB at 1,000 dives. `raw_data` was a rounding error next to
   those tables. It is now a large share of what is left.

## Measurement

zlib level 6 over the raw fixtures already committed to this repository:

| fixture | raw | zlib-6 | with 8-byte header | ratio |
|---|---:|---:|---:|---:|
| `packages/libdivecomputer_plugin/test/native/fixtures/dive1_raw.bin` | 400 B | 321 B | 329 B | 1.22x |
| `packages/libdivecomputer_plugin/test/native/fixtures/petrel3_ccr_o2_cells.bin` | 22,400 B | 8,903 B | 9,184 B | 2.44x |
| `packages/libdivecomputer_plugin/android/src/androidTest/assets/shearwater_teric_dive.bin` | 22,144 B | 4,655 B | 4,663 B | 4.75x |

Level 9 was measured too and gains under 1.2% over level 6 on all three, so
level 6 is used.

The "zlib-6" column is Python's zlib, used for the survey. The "with header"
column is what the shipped Dart encoder actually produces, measured after
implementation. They agree on two fixtures and differ by 3% on the Petrel 3
one: the two zlib builds make slightly different choices at the same level.
The shipped numbers are the ones in the rightmost columns.

The 400-byte fixture is a synthetic minimal dive. Ordinary recreational dives
from a Shearwater or Petrel are the 22 KB cases, at 2.4x to 4.7x. The old
"negligible" verdict came from calibrating on the small case.

At 5,000 downloaded dives the design doc's own estimate of about 150 MB of raw
bytes becomes roughly 40 MB. #1376 documents that default backup retention
keeps up to 13 full database copies plus the live one, so bytes removed from
the live database are removed up to 14 times from disk.

## Goal

Store `raw_data` compressed on disk, with no change to what any caller sees,
no change to the sync wire format, and no possibility of losing a byte of an
irreplaceable download.

## Scope

- `dive_data_sources.raw_data` only.
- A migration rung that recompresses existing rows, so libraries that already
  hold raw data benefit rather than only new downloads.

## Out of Scope

| Item | Rationale |
|---|---|
| `raw_fingerprint` | A handful of bytes per row, and it is hex-matched for download de-duplication. Nothing to gain, a live matching path to risk. |
| The "discard raw data" action and backup retention | #1376 owns both, and its body says the two issues coexist. |
| A Storage usage page row for raw bytes | #1375 owns the storage registry. Compression does not need it. |
| Compressing any other BLOB column | Media bytes are already compressed formats; profile series are already zlib. |
| Changing the sync wire format | Explicitly preserved. See "The sync invariant". |

## Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Where compression happens | A Drift `TypeConverter` on the column | Cannot be missed by a new write site, and it keeps sync transparent for free. |
| How a compressed blob is recognised | A magic header inside the blob | Self-describing. No sidecar column for `DiveMergeService` to carry, no state to consult on a partially migrated table. |
| What a non-matching blob means | Legacy uncompressed bytes, returned verbatim | One rule covers pre-migration rows, rows inbound from an older peer, and incompressible blobs. |
| Compression codec | `zlib`, level 6 | Already a dependency of the profile-series codecs. Level 9 measured under 1.2% better. |
| When to compress | Only when the encoded form is strictly smaller | A blob that does not compress is stored exactly as it arrived. |
| Sync wire format | Unchanged: peers keep exchanging uncompressed bytes | No `minimumCompatibleSchemaVersion` raise, so no older peer is refused. |
| Existing rows | Recompressed by a migration rung, then one VACUUM | Rewriting in place only moves pages to the freelist. VACUUM is what returns them. |
| Decode failure | Fall back to "legacy raw", never throw | A converter throwing would break ordinary row mapping for the whole table. |

## Blob Format

```
offset  size  meaning
0       4     magic, ASCII "SRD1"
4       4     uint32 little-endian, length of the original bytes
8       n     zlib stream (level 6) of the original bytes
```

A stored blob is decoded as compressed if and only if **all** of:

1. It is at least 8 bytes long and begins with the magic.
2. The zlib stream inflates without error, bounded by the declared length.
3. The inflated length equals the declared length.

Otherwise the stored bytes are returned unchanged.

The residual risk is a legacy raw blob that satisfies all three conditions by
accident, which would read back as its own inflation instead of itself. For
that, arbitrary dive computer bytes would have to begin with the specific
four-byte magic (about 2^-32), and the bytes after offset 8 would have to form
a zlib stream whose adler32 trailer validates (about another 2^-32), inflating
to exactly the length the preceding four bytes happen to spell. Conditions 2
and 3 are what push it there; the magic alone would not be enough. The
combination is not reachable in practice, and after the migration below every
stored blob was written by this encoder anyway, leaving only rows inbound from
an older peer in the legacy state.

Encoding writes the compressed form only when both hold:

- `8 + zlibLength < originalLength`. The 400-byte fixture above clears that
  bar; a 20-byte blob would not, and is stored raw.
- `originalLength <= kMaxRawDiveBlobBytes` (see below). The encoder must never
  produce a blob its own decoder's bound would refuse, so anything over the cap
  is stored raw and stays readable.

The version digit in the magic is the extension point. A future codec change
mints "SRD2" and the decoder keeps understanding "SRD1" forever, because the
blobs are the only copy of the download.

## Where It Lives

New file `lib/core/database/raw_dive_data_codec.dart`, holding the encode and
decode functions and the format constants, with no Flutter imports. The
existing `database_import_graph_test` walks `database.dart`'s import graph and
requires it to stay Flutter-free, so this file must stay so too.

The converter is applied in `database.dart`:

```dart
BlobColumn get rawData =>
    blob().map(const RawDiveDataConverter()).nullable()();
```

Drift wraps a non-nullable converter on a nullable column with
`NullAwareTypeConverter`, so `null` maps to `null` in both directions and the
generated data-class field stays `Uint8List?`. No caller's type changes and
no call site needs editing.

Decoding uses `inflateBounded` from `lib/core/utils/bounded_inflate.dart` with
`zlib.decoder`. That guard is chunked, so a crafted blob is abandoned at the
first oversized chunk rather than after the whole body is in memory.

Both of its caps are derived from one constant,
`kMaxRawDiveBlobBytes = 8 MiB`, comfortably above any dive a computer records
and far below anything that threatens memory:

- `maxBlobBytes` is `kMaxRawDiveBlobBytes`.
- `maxBytes` is `min(declaredLength, kMaxRawDiveBlobBytes)`. The declared
  length is attacker-controlled up to 4 GiB, so it bounds the inflate only
  when it is the smaller of the two. Clamping it is also what lets condition 3
  reject a blob that inflates past what it promised.

### Why a converter rather than encoding at the call sites

Only two sites write `raw_data` content today
(`dive_computer_repository_impl.dart:1348` and `reparse_service.dart:479`) and
only two read it (`ReparseService.reparseAllForComputer` and
`ReparseService.reparseDive`, both passing `source.rawData!` to the native
parser). Four sites is few enough to edit by hand.

The converter is chosen anyway for two reasons that outlive the current site
count:

1. A future write site that forgets to encode stores a raw blob, which still
   reads back correctly, so the mistake is invisible. A future *read* site that
   forgets to decode hands compressed bytes to libdivecomputer. The converter
   removes both classes of mistake.
2. It is what makes the sync invariant below hold without touching sync at all.

The cost is that every read of a `dive_data_sources` row inflates its blob,
including reads that never look at `rawData`. Reading the row already pulls the
blob off disk, and it now pulls a smaller one, so the net change on the read
path is a few tens of microseconds of inflate against less I/O.

This would be the codebase's first `TypeConverter`. That is the one respect in
which the design cuts against the existing grain, and it is called out here so
a reviewer weighs it deliberately rather than discovering it.

## The Sync Invariant

Sync payloads are gzipped whole before encryption (`SyncEnvelope`, flag bit0),
so compressing this column buys nothing on the wire. The entire benefit is at
rest, and the wire is left alone.

Every sync path that touches this table goes through
`table.map(row).toJson(serializer: _syncBlobSerializer)` or the matching
`fromJson`, both of which operate on the converted Dart value. With the
converter in place they therefore continue to emit and accept **uncompressed**
bytes, base64-encoded exactly as today. Consequences:

- `minimumCompatibleSchemaVersion` is **not** raised. No peer on an older build
  is refused.
- A row inbound from an older peer arrives uncompressed and is compressed on
  write by the converter.
- The recompression migration is invisible to sync. It changes bytes on disk,
  not the logical value, and touches no HLC, so no peer sees a change.
- Two devices compressing the same download to different bytes cannot cause a
  flip-flop, because the compressed bytes never travel.

Raw SQL that mentions this column was audited: `reparse_service.dart` lines
248, 255 and 271 and `database.dart:5790` use only `raw_data IS NULL` /
`IS NOT NULL` predicates, and `database.dart:8314` copies the column verbatim
during a table rebuild. None reads blob content, so the converter's absence on
those paths is correct.

## Migration

A new rung, **v190**. This was written against `origin/main` at schema version
187 and planned as v188, but by implementation time main had taken 188 (insurer
phone numbers, #1522) and 189 (media equipment link, #1517), so the branch
merged main and the rung moved up. The number is re-verified against
`origin/main` immediately before it is claimed, per the schema ladder
convention; that check is what caught this.

The rung has no DDL. The column's SQL type is unchanged; only the stored bytes
move. It walks `dive_data_sources` rows where `raw_data IS NOT NULL` in
batches, encodes each blob, and writes back only the rows that got smaller.
Rows already carrying the magic are skipped, so the rung is idempotent and a
run interrupted part way costs nothing but the work already done.

Encode cost is roughly 1 ms per 22 KB blob, so a 5,000-dive library is a few
seconds, comparable to the profile-series migration's measured 9.1 s. The rung
reports progress through the existing per-step callback.

**The rung is guarded per row and cannot fail the ladder.** An unguarded pack
step in the v182 profile-series rung could leave a database that would not
open, which is the worst outcome available to any migration and the one this
rung is closest to repeating. A row whose encode throws is left exactly as it
is, counted, and logged; the rung moves on. Leaving a blob uncompressed costs
space, and the self-describing format means that row keeps reading correctly
forever. Nothing about a failed row justifies refusing to open the database
that holds the diver's log.

### Reclaiming the pages

Rewriting rows in place moves the old pages to the freelist; VACUUM returns
them to the filesystem. `DatabaseService._runUpgradeLadder` already owns
exactly one VACUUM per open, currently gated on `storedBefore < 183`, with a
second trigger for an unplanned reclaim discovered mid-ladder
(`AppDatabase.droppedLegacySampleTables`).

The rung sets a parallel flag, `AppDatabase.recompressedRawBlobs`, set only
when at least one row actually shrank. `_runUpgradeLadder` treats it like the
existing unplanned-reclaim signal, so:

- A file with no raw data takes no VACUUM.
- A file that recompressed rows takes the one VACUUM that already exists,
  under the existing ticket, on the same exclusive main-isolate connection,
  outside any migration transaction.
- The VACUUM stays non-fatal. A busy lock leaves a correct database that is
  merely larger than it needs to be.

The planned-versus-unplanned distinction in the progress reporting is kept as
it stands: reporting an unplanned reclaim as a step would push the bar past
its own total.

## Error Handling

| Situation | Behaviour |
|---|---|
| Blob without the magic | Returned verbatim as legacy raw bytes. |
| Magic present, stream corrupt or truncated | `BoundedInflateException` is caught and the stored bytes are returned verbatim. |
| Magic present, inflated length disagrees | Stored bytes returned verbatim. |
| Blob inflates past its declared length | Abandoned mid-stream by `inflateBounded`; stored bytes returned verbatim. |
| Encode throws on a normal write | Not caught. A failure to deflate in memory is a defect, not malformed input, and silently storing raw bytes would hide it. |
| Encode throws inside the migration | Caught per row. That row is left raw and counted; the rung continues. See below. |

The fallback never throws out of row mapping, so a damaged blob degrades into
a re-parse failure. Re-parse already counts and surfaces failures
(`reparseAllForComputer` returns `succeeded`/`failed`; `reparseDive` returns
`errors`), so the degradation is reported rather than silent.

## Testing

**Codec unit tests**

- Round trip over each of the three committed fixtures, asserting byte equality
  and that the encoded form is smaller.
- A blob that does not compress is stored unchanged and reads back unchanged.
- Legacy raw bytes with no magic pass through both directions untouched.
- A crafted legacy blob beginning with the four magic bytes reads back as
  itself.
- A truncated zlib stream behind a valid magic reads back as the stored bytes.
- A zlib bomb behind a valid magic is refused by the bound, not inflated.
- A blob larger than `kMaxRawDiveBlobBytes` is stored raw by the encoder and
  reads back byte-identical, proving the encoder never mints something its own
  decoder would refuse.
- Empty and single-byte blobs.

**Migration test**

A v187 raw-DDL fixture with several `dive_data_sources` rows carrying raw
blobs, stamped with `PRAGMA user_version`, run up the ladder. Assertions: the
on-disk blobs carry the magic, every decoded value equals the original bytes,
`recompressedRawBlobs` is set, and a second run is a no-op. A companion
fixture with no raw data asserts the flag stays clear. A third asserts the
ladder completes and the database opens when one row's encode throws, with
that row left raw and still readable.

**Integration**

`ReparseService` round trip: write a download through the repository, read it
back through `getSourcesForDiveReparse`, and assert the bytes handed to the
parse function are byte-identical to what was downloaded.

**The load-bearing test**

A sync round trip asserting the exported `diveDataSources` JSON carries the
base64 of the **uncompressed** bytes. This is what pins the wire contract. A
later refactor that moves encoding out of the converter and into the call
sites would leak compressed blobs to peers, and this test is the only thing
that would catch it.

## Rejected Alternatives

**A sidecar `raw_data_encoding` column.** Unambiguous, but every path that
copies a row has to carry it. `DiveMergeService` copies `dive_data_sources`
rows wholesale as provenance, deliberately, because each carried row is the
sole surviving copy of one download's raw bytes. A self-describing blob
survives that copy with nothing to remember.

**Compressed bytes on the wire, with the sync floor raised to the new rung.** This is
the precedent the profile-series program set, and it is one line. It was
rejected because the failure it protects against is mild and self-healing (an
older peer's re-parse of a synced dive fails until that peer updates; no data
is lost or corrupted), while the protection is severe: raising the floor stops
older peers syncing at all. Disproportionate.

**Decoding at the sync boundary while storing compressed.** Would also keep the
wire unchanged, but `sync_data_serializer.dart` has about ten
`case 'diveDataSources'` branches across export, paging, upsert and apply.
Getting nine of ten right leaks compressed blobs to peers silently, with no
floor raised to catch it. The converter makes the boundary singular.

**Lazy recompression by a startup sweep** instead of a rung. The live
precedent for background maintenance is `MediaOrphanBacklogSweep`, and this
work would fit it. Rejected because a sweep with no VACUUM rewrites rows
without shrinking the file, and the one-VACUUM-per-open seam is tied to the
upgrade ladder. The rung reaches the reclaim; a sweep would not.

**No migration at all**, letting only new downloads compress. Rejected because
the users with the most raw bytes are the ones who have been downloading
longest.

## Files Touched

| File | Change |
|---|---|
| `lib/core/database/raw_dive_data_codec.dart` | New. Format constants, encode, decode, converter. |
| `lib/core/database/database.dart` | `.map(...)` on `rawData`; the v190 rung; the `recompressedRawBlobs` and `hasUnreclaimedPages` flags. |
| `lib/core/database/database.g.dart` | Regenerated. Not committed: `.gitignore` excludes `*.g.dart`. |
| `lib/core/services/database_service.dart` | The VACUUM gate learns the new reclaim signal. |
| `test/core/database/raw_dive_data_codec_test.dart` | New. Codec unit tests. |
| `test/core/database/migration_v190_raw_data_compression_test.dart` | New. Migration fixtures. |
| `test/features/dive_computer/data/services/reparse_service_test.dart` | Round-trip assertion. |
| `test/core/services/sync/sync_serializer_round_trip_test.dart` | The wire-contract assertion. |

No user-facing string changes, so no ARB work.
