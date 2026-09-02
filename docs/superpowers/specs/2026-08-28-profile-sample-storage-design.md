# Profile Sample Storage: Packed Series

Design for replacing the row-per-sample `dive_profiles` and
`tank_pressure_profiles` tables with one compressed, columnar BLOB row per
series. Approved in brainstorming on 2026-08-28. Companion issues: #1375
(cache and tombstone retention) and #1376 (backup retention defaults and
raw-data discard) cover the rest of the on-device storage findings and are
independent of this design.

## 1. Why

Measured on a 40-dive development database (28.07 MB, schema v179):

| btree | size |
|---|---:|
| `dive_profiles` | 9.99 MB |
| `tank_pressure_profiles` | 5.30 MB |
| `idx_tank_pressure_dive_tank` | 3.42 MB |
| `sqlite_autoindex_dive_profiles_1` | 2.48 MB |
| `idx_dive_profiles_dive_id` | 2.19 MB |
| `sqlite_autoindex_tank_pressure_profiles_1` | 2.04 MB |
| subtotal | 25.41 MB (90.5% of the file) |
| the other 244 btrees | 2.66 MB |

Both tables hold one row per sample, and every row carries three or four
36-character UUID strings (`id`, `dive_id`, `computer_id`, `source_id`, or
`tank_id`), each mirrored again in the primary-key autoindex and the
secondary index. `tank_pressure_profiles` spends 4.32 MB of UUID text to
carry 0.48 MB of timestamps and pressures.

Per-dive cost is 332 KB (a 1,032-dive fixture measured 2026-07-10 with 6 of
the intended indexes) to 719 KB (the current schema with all 70 indexes). A
1,000-dive logbook is therefore 300 to 700 MB, and backup retention (3
pre-migration plus 10 manual copies by default) multiplies that by up to 14x
on disk.

Fragmentation is not the problem: `freelist_count` is 0 and `VACUUM INTO`
recovers 4.3%. Periodic compaction was considered and rejected; the only
`VACUUM` in this design is the one-time pass after the migration drops the
old tables.

Packing each series into a columnar, zlib-compressed BLOB was measured on the
same database (lossless, float64 for real fields):

| table | today | packed | factor |
|---|---:|---:|---:|
| `dive_profiles` and its indexes | 14.66 MB | 0.20 MB | 74x |
| `tank_pressure_profiles` and its indexes | 10.75 MB | 0.08 MB | 129x |

50,883 sample rows become 40 series rows. Sync payloads shrink by the same
factor, and a dive edit stops shipping any samples at all.

Alternatives measured and rejected: `WITHOUT ROWID` (14.66 to 14.03 MB; the
fat TEXT key bloats every secondary index) and UUID text to 16-byte BLOB
re-encoding (42 to 46%, still row-per-sample, still a sync protocol change).

## 2. Goals and non-goals

Goals:

- Order-of-magnitude reduction in the bytes the two sample tables occupy,
  on disk and on the sync wire.
- No behaviour change above the repository layer. `DiveProfilePoint`, the
  chart, the analysis pipeline, and every provider keep their contracts.
- Every source-scoped operation (manual edit, restore, primary swap,
  reparse, split, merge, consolidation) becomes a single-row operation.
- Per-series last-writer-wins in sync, replacing the clockless per-sample
  blind upsert.
- Adding a sample field never again requires an `ALTER TABLE` over a
  million rows.

Non-goals:

- Lossy downsampling or decimation at rest. The codec is lossless.
- A natural-key uniqueness constraint on series. One data source
  legitimately owns two series (its original and a manual edit), and
  convergence across devices already rests on the dive-level match gate.
- A dual-format sync bridge. The compatibility floor rises; older peers
  hold until they upgrade.
- Periodic or scheduled compaction.

## 3. Architecture

Two new tables, `dive_profile_series` and `tank_pressure_series`, replace
`dive_profiles` and `tank_pressure_profiles`. A series row carries the
identity columns exactly as they exist per row today, a small set of summary
scalars, a codec version, and one BLOB holding every sample of the series.

Three new units:

- `ProfileSeriesCodec` (pure Dart, no Drift or Flutter imports, the same
  layering as `lib/features/gps_log/domain/track_point_codec.dart`). Encodes
  a sample list to bytes and back, and computes the summary scalars from the
  samples it packs, so a scalar can never disagree with its blob.
- `ProfileSeriesRepository`. Owns every read and write of series rows. The
  only place that encodes or decodes in production code outside the
  migration packer and the sync tolerance shim.
- `ProfileSeries` and `TankPressureSeries` domain entities: identity,
  summary, and the decoded sample list.

`DiveRepository` and `TankPressureRepository` keep their public signatures
(`getDiveProfile`, `getMergedProfile`, `getProfilesByDataSource`,
`getDiveForAnalysis`, `getBatchProfileSummaries`, `getTankPressures`,
`getPressuresForTank`) and delegate to the series repository.

The existing per-row `computer_id`, `source_id`, `is_primary` triple is
already a series identity: every operation that touches those columns
filters a whole group and never a single sample. Lifting the triple onto the
series row is the whole conceptual change.

## 4. Schema

### `dive_profile_series`

| column | type | notes |
|---|---|---|
| `id` | TEXT PK | uuid v4 for new writes; deterministic for migrated rows (section 8) |
| `dive_id` | TEXT NOT NULL | FK `dives(id)` ON DELETE CASCADE |
| `computer_id` | TEXT | FK `dive_computers(id)` ON DELETE SET NULL |
| `source_id` | TEXT | FK `dive_data_sources(id)` ON DELETE SET NULL |
| `is_primary` | INTEGER NOT NULL DEFAULT 1 | CHECK 0 or 1 |
| `sample_count` | INTEGER NOT NULL | |
| `start_timestamp` | INTEGER NOT NULL | seconds from dive start, first sample |
| `end_timestamp` | INTEGER NOT NULL | seconds from dive start, last sample |
| `max_depth` | REAL NOT NULL | metres |
| `first_depth` | REAL NOT NULL | metres |
| `last_depth` | REAL NOT NULL | metres |
| `has_deco_type` | INTEGER NOT NULL | any sample with `deco_type` not null |
| `has_deco_stop` | INTEGER NOT NULL | any sample with `deco_type = 2` |
| `has_positive_ceiling` | INTEGER NOT NULL | any sample with `ceiling > 0` |
| `codec_version` | INTEGER NOT NULL | |
| `samples` | BLOB NOT NULL | codec output |
| `created_at` | INTEGER NOT NULL | |
| `updated_at` | INTEGER NOT NULL | |
| `hlc` | TEXT | sync clock, same shape as `dives.hlc` |

Index: `idx_dive_profile_series_dive_primary` on `(dive_id, is_primary)`.

### `tank_pressure_series`

| column | type | notes |
|---|---|---|
| `id` | TEXT PK | as above |
| `dive_id` | TEXT NOT NULL | FK `dives(id)` ON DELETE CASCADE |
| `tank_id` | TEXT NOT NULL | FK `dive_tanks(id)` ON DELETE CASCADE |
| `computer_id` | TEXT | FK `dive_computers(id)` ON DELETE SET NULL |
| `sample_count` | INTEGER NOT NULL | |
| `start_timestamp` | INTEGER NOT NULL | |
| `end_timestamp` | INTEGER NOT NULL | |
| `codec_version` | INTEGER NOT NULL | |
| `samples` | BLOB NOT NULL | |
| `created_at` | INTEGER NOT NULL | |
| `updated_at` | INTEGER NOT NULL | |
| `hlc` | TEXT | |

Index: `idx_tank_pressure_series_dive_tank` on `(dive_id, tank_id)`.

The summary scalars are exactly the set the nine SQL consumers in section 9
need. Nothing speculative is stored; anything else decodes.

Both tables replace the two entries `idx_dive_profiles_dive_id` and
`idx_tank_pressure_dive_tank` in `kPerformanceIndexes`
(`lib/core/database/performance_indexes.dart`) with their own indexes. The
old entries must be removed, or the `beforeOpen` heal would try to index a
dropped table.

## 5. Codec v1

Columnar, versioned, lossless.

Layout:

1. Header: one version byte (`1`), then `sample_count` as an unsigned
   varint.
2. One block per field, in the fixed field-table order below (28 fields
   for a dive profile: every `dive_profiles` column except `id`,
   `dive_id`, `computer_id`, `source_id`, and `is_primary`). Each block
   begins with a presence mode byte: `0` absent (every value null; no
   payload), `1` all present, `2` bitmap (a presence bitmap of
   `ceil(n / 8)` bytes precedes the payload; only present values are
   written).
3. The concatenation of header and blocks is zlib-compressed with
   `dart:io`'s `ZLibCodec` at level 6. No web build exists in CI, and
   `dart:io` compression is already used by `track_point_codec.dart` and
   `sync_envelope.dart`.

Varints are canonical: every value has exactly one encoding, the shortest
one. LEB128 otherwise allows padding a value with continuation bytes that
carry no payload, which would give one series several valid byte forms and
make byte comparison of two blobs meaningless. The reader refuses any
varint whose terminating byte carries a zero payload, unless that byte is
the whole varint (the encoding of zero).

Field table (dive profile), with encoding:

| field | encoding |
|---|---|
| `timestamp` | delta from previous value, zigzag varint; the first delta is from 0 |
| `depth` | float64 little-endian |
| `pressure` (legacy per-sample column, still populated on older rows) | float64 |
| `temperature` | float64 |
| `heart_rate` | delta zigzag varint |
| `ascent_rate` | float64 |
| `ceiling` | float64 |
| `ndl` | delta zigzag varint |
| `setpoint` | float64 |
| `pp_o2` | float64 |
| `o2_sensor1` to `o2_sensor6` | float64 each |
| `cns` | float64 |
| `tts` | delta zigzag varint |
| `rbt` | delta zigzag varint |
| `deco_type` | delta zigzag varint |
| `heart_rate_source` | run-length over the present values: a run count varint, then per run a length varint, a UTF-8 byte-length varint, and the bytes |
| `heading` | float64 |
| `o2_sensor_mv1` to `o2_sensor_mv6` | delta zigzag varint each |

Field table (tank pressure): `timestamp` (delta zigzag varint), `pressure`
(float64).

Delta encoding of integer fields resets its "previous value" to 0 at the
start of each field block and skips null entries (the delta is from the last
present value). A zero timestamp delta is legal, so samples that share a
timestamp are representable in insertion order.

Real fields are float64 rather than fixed point because the measured 74x
already exceeds the target and fixed point would be lossy for depths that
libdivecomputer reports as doubles. float32 was measured (101x) and rejected
for the same reason.

Versioning: a later codec appends fields to the table under a new version
byte. A decoder for version N reads a version M < N blob with the missing
fields null. Decoders never guess: an unknown version byte, a truncated
payload, or a block count that disagrees with the field table throws
`ProfileSeriesCodecException` rather than returning a partial list.

Summary scalars are computed by the encoder from the sample list it packs
and returned alongside the bytes, so the repository writes both from one
call.

## 6. Read and write paths

### Writes

The thirteen sites that mint sample rows today reduce to this repository
API:

- `insertSeries(ProfileSeriesDraft)`: encode, compute summaries, mint a v4
  id, insert one row.
- `replaceSeriesOwnedBy(diveId, {computerId, sourceId}, samples)`: delete
  the matching series rows, insert the replacement. Used by reparse,
  re-download, and consolidation.
- `demoteAll(diveId)` and `promote(diveId, {computerId, sourceId})`: the
  `is_primary` flips, each a single-row `UPDATE`.
- `deleteSeriesOwnedBy(diveId, {computerId, sourceId})` and
  `deleteSeriesForDive(diveId)`.
- The tank-pressure equivalents keyed by `(diveId, tankId, computerId)`.

Semantics preserved exactly:

- Manual edit (`saveEditedProfile`): demote every series for the dive, then
  insert a new primary series with `computer_id` null and the primary
  source's `source_id`.
- Restore (`restoreOriginalProfile`): delete series where `is_primary` and
  `computer_id IS NULL`, then re-promote the primary computer's series (or
  every remaining series for a single-computer dive).
- Split and merge: encode their rebased sample lists into new series rows;
  originals are deleted as today.
- Consolidation undo: `DiveMergeSnapshot` captures series rows instead of
  sample rows and re-inserts them by series id with `insertOrReplace`.
- Primary-source swap: `markRecordPending` once per series instead of once
  per sample.

Exact-duplicate dedupe (`_dropDuplicateSamples`, whole-row equality) moves
from read time to encode time in the repository and into the migration
packer. Samples that share a timestamp but differ are kept in insertion
order.

### Reads

Every existing read method selects series rows for the dive and decodes.
Merge order across sources and the promote tiebreaker are reproduced in Dart
over decoded lists. `getBatchProfileSummaries` decodes one series per dive
and downsamples, replacing the load-every-row path.

Decoding one series (at most a few thousand samples) is on the order of a
millisecond and runs on the isolate that receives the row. Whole-library
aggregations (section 9) decode on a worker isolate via `compute`.

### Domain

`DiveProfilePoint` is unchanged. `TankPressurePoint.id` is removed: it
appears only in Equatable `props`, no widget or exporter reads it, and
`estimated_tank_pressure_synthesizer.dart` already fabricates non-uuid
values for it.

## 7. Sync

`diveProfileSeries` and `tankPressureSeries` register in
`SyncDataSerializer._baseTables` with `blob: true`, export by their own
`hlc > since` (the `_exportGpsTracks` pattern, `samples` riding as base64
through `_syncBlobSerializer`), and register as HLC-bearing with
`updated_at` in `SyncService`. Apply is `insertOnConflictUpdate` by series
id with last-writer-wins by HLC. `parentRefs` lists `dives`,
`dive_computers`, `dive_data_sources`, and (for tank series) `dive_tanks`, so
`sync_parent_refs_completeness_test` stays green.

`diveProfiles` and `tankPressureProfiles` leave `_baseTables`, `SyncData`,
`hlcBearing`, `parentRefs`, and the `fetchRecord`, `upsertRecord`,
`upsertRecords`, `deleteRecord`, and `recordIdsFor` switches.

Deleting a series logs one `deletion_log` row for the series id. The three
per-sample tombstone amplifiers named in #1375 (tank-pressure delete, split,
safety-review recompute over samples) disappear as a consequence.

`minimumCompatibleSchemaVersion` rises to the new rung: the migration
removes two synced entities and replaces them, which the floor's own rules
classify as breaking. The floor is one-directional, so receiving-side
tolerance for older peers' payloads is added in the serializer's established
pattern: legacy `diveProfiles` and `tankPressureProfiles` arrays that still
arrive are grouped by identity tuple and packed into series on apply, using
the same packer the migration uses. This is a read-side shim, not a
dual-write; older peers hold until they upgrade and then migrate their own
rows.

The `cross_version_roundtrip_test` projection is extended to cover the new
boundary, as the floor's doc comment requires.

## 8. Migration and one-time compaction

### The rung

One new ladder rung at the next free schema version. At the time of
writing `origin/main` is at 179 and 180 is the next free rung, but at least
one sibling worktree also needs to move onto it; the number is claimed at
implementation time and re-checked against `origin/main` immediately before
the PR opens.

Steps, in order:

1. Create both series tables and their indexes.
2. Pack profiles. For each distinct `dive_id`, select that dive's rows
   ordered by `(computer_id, source_id, is_primary, timestamp, rowid)`,
   group by the identity tuple in Dart, drop exact duplicates, encode, and
   insert one series row per group. Memory is bounded by one dive's samples
   (the largest observed series is 4,631 samples), never by the table.
3. Pack tank pressures the same way, grouped by
   `(dive_id, tank_id, computer_id)`.
4. Drop `dive_profiles` and `tank_pressure_profiles`.
5. Purge `deletion_log` and `sync_records` rows whose entity type is
   `diveProfiles` or `tankPressureProfiles`.

Migrated series rows take `created_at` and `updated_at` from the migration
time and an `hlc` minted by the local clock, so the first sync after
upgrade publishes them.

### Fleet convergence

Every device runs this migration independently. A random series id per
device would let sync union two primary series per dive, the exact shape of
the duplicate dive-types bug (#1360). Migrated series ids are therefore
deterministic: uuid v5 over the identity tuple
`dive_id | computer_id | source_id | is_primary` (with the literal `null`
for absent members). Two devices holding the same synced sample rows
produce the same series id and converge on upsert. Only the migration
derives ids this way; writes after it mint v4, because a fresh download or
edit genuinely is a new series.

### Safety net

The existing pre-migration backup (`_runPreMigrationBackup` in
`startup_page.dart`, retain 3) runs before the ladder as it does today. The
rung runs under Drift's migration handling like every other rung; a failure
leaves the old tables intact for the retry.

### Compaction

Dropping the tables returns roughly 90% of the pages to the freelist, but
the file does not shrink until `VACUUM`. The seam is
`DatabaseService._runUpgradeLadder`: it reads `PRAGMA user_version` before
constructing the migrator, and if that value was below the pack rung, it
executes `VACUUM` on the same synchronous connection after the ladder
completes (the forcing `SELECT 1` has returned) and before `close()`. That
point is outside any migration transaction, on the one exclusive
main-isolate connection, before the background executor opens the file, and
works under SQLCipher.

Non-fatal by design: a `VACUUM` that fails (for example `SQLITE_BUSY` from
another connection) logs and moves on with a correct but large file. No
marker is persisted; the decision comes from the pre-ladder `user_version`.

## 9. The nine SQL consumers

| consumer | today | after |
|---|---|---|
| deco classification signals (`statistics_repository.dart`) | `MAX(deco_type IS NOT NULL)`, `MAX(deco_type = 2)`, `MAX(ceiling > 0)` over rows | `has_deco_type`, `has_deco_stop`, `has_positive_ceiling`; stays SQL |
| `decoSignalCondition` (`statistics/data/dive_filter_sql.dart`) and `getDiveIdsWithDecoSignal` | `EXISTS` over rows plus `dive_profile_events` | same flags plus events; stays SQL |
| `had_deco` in the recent-dives query (`dive_repository_impl.dart`) | `EXISTS(deco_type = 2 OR ceiling > 0)` | `has_deco_stop OR has_positive_ceiling`; stays SQL |
| profile span in `_effectiveRuntimeSql` and `_diveTimesSelect` | `MAX(ts) - MIN(ts)` over rows | `MAX(end_timestamp) - MIN(start_timestamp)` over the dive's series; stays SQL |
| quality neighbour first and last depth (`quality_context_builder.dart`) | two correlated `ORDER BY ts LIMIT 1` subqueries | `first_depth`, `last_depth`; stays SQL |
| quality prefilters (`quality_prefilters.dart`) | `EXISTS` on both sample tables | `EXISTS` on both series tables; stays SQL |
| source ownership and promote-by-predicate (`_sourceOwnsProfiles` and neighbours) | row predicates with a bound-variable-limit workaround | series-row predicates; the workaround becomes unnecessary |
| sustained ascent and descent rates (`statistics_repository.dart`) | windowed `AVG(depth)` and `LAG` over every primary row in scope | decode primary series in scope on a worker isolate; same window and threshold constants |
| time-at-depth buckets (`statistics_repository.dart`) | `LEAD` intervals with a cadence cap, tiebreak `ORDER BY at, sample_id` | same algorithm in Dart over decoded series; tiebreak is stored order |

Only the last two leave SQL, and both are whole-library aggregations that
the statistics page already awaits asynchronously. The two Dart aggregations
carry a benchmark gate (section 10).

Historical backfills in older rungs (v132, v146, v177) run before the pack
rung and are untouched. Any future backfill that needs samples decodes.

## 10. Testing and benchmark gates

Codec:

- Round-trip property tests over generated sample lists: every field null,
  every field present, mixed presence, duplicate timestamps, negative
  deltas, the largest realistic series (20,000 samples at 1 s), float64
  bit-exactness.
- A version-1 blob decoded under a hypothetical later field table yields
  the new fields null.
- An unknown version, a truncated payload, a malformed block, and a
  non-canonical (padded) varint each throw `ProfileSeriesCodecException`.

Summary scalars:

- Equivalence tests run today's SQL expressions over a row fixture, pack
  it, and assert the scalars match, proving the section 9 substitutions.

Migration (following the `test/core/database/migration_v*` precedent):

- A pre-rung fixture with exact duplicates, null `source_id`, null
  `computer_id`, a multi-source dive, and a manual-edit series.
- Asserts: decoded samples equal the originals minus exact duplicates; the
  old tables are gone; the retired tombstones and pending records are
  purged; two independently migrated copies of the same fixture produce
  identical series ids (the #1360 test).
- `query_plan_test` and `performance_indexes_test` updated for the removed
  and added indexes.

Sync:

- Export-to-JSON-to-apply round trips for both entities on a second
  database.
- The legacy-array tolerance shim applied to a v179-shaped payload.
- `sync_parent_refs_completeness_test`; the `cross_version_roundtrip_test`
  projection extended.
- One tombstone per deleted series.

Behaviour:

- Existing tests for manual edit, restore, primary swap, split, merge, and
  consolidation undo run unchanged against the new storage. Of the 53 test
  files that reference the old tables, those asserting on raw rows are
  ported.
- The two statistics aggregations that move to Dart get golden values
  captured from the SQL versions before the change.

Benchmarks, gated in the second PR, on a synthesized 1,000-dive fixture (a
`tools/` script replicates the 40-dive development database with fresh ids;
the 2026-07-10 real fixture is no longer on this machine):

- per-dive detail hydrate
- `getBatchProfileSummaries` for 50 dives
- both statistics aggregations
- migration wall time
- post-`VACUUM` file size and `VACUUM` time

Gate: nothing slower than today; numbers reported in the PR description.

## 11. Delivery

Two stacked PRs on `worktree-profile-sample-storage`:

1. Codec only: `ProfileSeriesCodec`, its exception type, the summary
   computation, and the codec tests. Pure Dart, no schema change, no
   behaviour change.
2. Schema, `ProfileSeriesRepository`, the repository ports, the migration
   rung with compaction, the sync changes and tolerance shim, the SQL
   consumer substitutions, the fixture script, and the benchmark results.

## 12. Risks and mitigations

- Migration time on a large phone database: bounded per-dive memory and a
  benchmark on the 1,000-dive fixture; the startup screen already shows
  migration progress.
- Statistics regressions from moving two aggregations to Dart: golden-value
  tests plus the benchmark gate.
- Schema rung collision with sibling worktrees: claim at implementation
  time, re-check before the PR opens.
- A sample field the field table forgot: the codec tests enumerate the
  field table against the Drift column list for `DiveProfiles` so a missing
  column fails the test, not the user.
- Deterministic migrated ids colliding with a v4 id: uuid v5 and v4 occupy
  disjoint version nibbles, so a collision is impossible by construction.
