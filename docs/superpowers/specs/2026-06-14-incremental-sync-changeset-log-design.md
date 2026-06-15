# Incremental Sync via Per-Device Changeset Log — Design

- Date: 2026-06-14
- Status: Approved (design); implementation not started
- Owner: Eric
- Related: supersedes the full-snapshot transport described in the 2026-06-01
  iCloud sync spec and the 2026-06-09 S3 backend spec. The
  `CloudStorageProvider` abstraction and the HLC/LWW merge core are reused
  unchanged; only the on-storage layout and the local sync-position bookkeeping
  change.

## 1. Background

Submersion's cloud sync is storage-backend-agnostic: `SyncService`
(`lib/core/services/sync/sync_service.dart`) talks only to the abstract
`CloudStorageProvider`
(`lib/core/services/cloud_storage/cloud_storage_provider.dart`), with three
implementations today — iCloud, Google Drive, and S3-compatible.

Today each device writes **one full-snapshot file** per device,
`submersion_sync_<deviceId>.json`, containing a complete export of all ~51
tables plus a deletion log. Every sync re-serializes the entire database
(`exportData(since: null)`, `sync_service.dart:516` — commented "Full export for
now") and overwrites that file; each peer lists the folder and downloads every
other device's full file, merging row-by-row via HLC last-writer-wins with
tombstoned deletions.

**The problem.** For a heavy user (≈3,000 dives) the database is ~180–250 MB;
`dive_profiles` (~810K rows) and `tank_pressure_profiles` (~1M rows) are ~90% of
it, and that bulk is **write-once** (a dive's profile never changes after
import, barring re-parse). The full-snapshot transport re-uploads, and forces
every peer to re-download, the entire dataset on **every** sync — even when only
a few new dives were added. On slow or metered links this manifests as syncs
that time out or require the app to stay open for a long time.

**What already exists and is reused.** The hard, debugged parts of incremental
sync are already in place:

- Per-row `updatedAt` on every syncable table, plus **HLC stamps** (`hlc.dart`)
  on the 23 mutable tables (`database.dart:1666`).
- A **tombstone deletion log** with resurrection guards and deferred-FK repair
  (`database.dart:1359`; merge at `sync_service.dart:1265`).
- A **per-provider sync cursor** (v81, `sync_repository.dart:198`) and
  idempotent HLC last-writer-wins merge (`sync_service.dart:1304`).
- `exportData(since:)` already filters every table by `updatedAt` — the delta
  query exists; it is simply always called with `null`. This design reuses that
  machinery, widening the filter predicate to an HLC watermark for clock-skew
  safety (see §5.2).

The blocker is therefore **not** missing change-tracking — it is the file
layout. A single full-snapshot file cannot be truncated to a delta, because a
new or long-absent peer downloads that one file and would silently miss all
history. This design changes the storage layout to a per-device changeset log on
top of the existing merge core.

## 2. Decision record

Decisions made with the owner during design:

| # | Decision | Choice |
|---|----------|--------|
| 1 | Primary goal | Incremental steady-state deltas (primary); resumable cold-start for the unavoidable large first sync (secondary) |
| 2 | Media scope | Database content only. Layout kept media-ready (content-addressed blobs are a clean future drop-in) but no media transport is built now |
| 3 | Merge model | Keep the existing **row-level** HLC last-writer-wins CRDT unchanged. Field-level (column) merge and `cr-sqlite` adoption explicitly deferred/rejected for this effort |
| 4 | Storage layout | **Approach A**: per-device append-only changeset log + periodic compacted base. Rejected: (B) content-addressed blob + metadata-log hybrid — deferred as the future media path; (C) content-defined chunking of the raw SQLite file — loses row-level merge, dedups poorly |
| 5 | Format version | **v1**. The current full-snapshot format was never released to users, so there is **no migration** — the new format is the first released format |
| 6 | Base transfer | Full snapshot byte-sliced into ~8 MB parts (default, tunable) for resumable transfer. Rejected: slicing by entity/dive range (more complex, marginal gain) |
| 7 | Wire format | Reuse the existing `SyncPayload` v2 structure and `exportData` machinery (its `since` filter widened from `updatedAt` to an HLC watermark for skew-safety); do not invent a new serialization |
| 8 | Compaction trigger | `changesetBytesSinceBase ≥ 30% of base bytes` **OR** `(headSeq − baseSeq) ≥ 200` changesets, whichever trips first (the count cap backstops the many-tiny-changesets pathology a pure byte trigger misses) |
| 9 | Compaction gating | **Not** Wi-Fi-gated; runs on any connection. Resumability makes interruptions safe. **No** user toggle (owner decision) |
| 10 | Restore correctness | Authoritative rebuild from the current published library on stale-restore detection. **No** dependence on the 90-day tombstone window |

## 3. Goals and non-goals

### Goals

- Routine syncs transmit only what changed since the device last published
  (target: a diver adding a few dives uploads ~hundreds of KB, not ~250 MB).
- Cold-start (new/replacement device) and any large transfer are **chunked and
  resumable**, surviving interruption and slow links without restarting.
- No change to the merge/conflict/tombstone/FK-repair core, or to the
  `CloudStorageProvider` interface. New behavior must work on the **lowest
  common denominator** of the backends: whole-file put/get/list/delete, no
  conditional writes / compare-and-swap, no range reads, eventually-consistent
  listing (S3).
- Preserve every existing invariant: library-epoch / "replace everywhere" mode,
  per-provider backend switching, twin/clone detection, and — most importantly —
  database restore.

### Non-goals

- Syncing media files (photos/videos). They remain on disk, path-referenced;
  only their metadata rows sync, as today. The layout is kept media-ready (see
  §15) but no media transport is built.
- Field-level conflict merge. Row-level LWW is retained.
- Reducing the *total* bytes of a genuine cold-start — a new device must still
  obtain the full dataset once; this design makes that transfer resumable, not
  smaller.

## 4. On-storage layout

> **Implemented layout (supersedes the subfolder illustration below).** Discovery
> via subfolders differs across backends (S3 prefix vs iCloud/Drive directory),
> so the implementation uses a **flat, filename-encoded layout** in the single
> existing sync folder, reusing the portable `listFiles({folderId, namePattern})`
> path. Names are `ssv1.` + deviceId + a kind suffix, with zero-padded seqs so
> lexical order matches numeric order. `lib/.../changeset_log/changeset_log_layout.dart`
> (`ChangesetLogLayout`) is the source of truth:
>
> ```
> <sync-folder>/
>   submersion_library_epoch.json            # UNCHANGED epoch / "replace everywhere" marker
>   ssv1.<deviceId>.manifest.json            # commit point; the only file ever rewritten
>   ssv1.<deviceId>.base.<baseSeq>.p0000     # full snapshot, byte-sliced into resumable parts
>   ssv1.<deviceId>.cs.<seq>.json            # immutable changesets, seq strictly increasing
> ```
>
> The single-writer, monotonic-seq, base-plus-changeset semantics in the rest of
> this section (and §§5-11) are exactly as designed; only the path spelling
> changed from `submersion-sync/v1/<deviceId>/<file>` to `ssv1.<deviceId>.<file>`.

Each device is the **sole writer** of a private subtree, which removes any need
for the conditional-write / compare-and-swap primitives the backends lack.

```
<sync-folder>/
  library_epoch.json                      # UNCHANGED: existing epoch / "replace everywhere" marker
  submersion-sync/v1/                      # new format, version-namespaced for a future v2
    <deviceId>/                            # this device's private namespace (single-writer)
      manifest.json                        # small; the ONLY file ever rewritten; the commit point
      base-<baseSeq>.part000               # full snapshot, byte-sliced into resumable parts
      base-<baseSeq>.part001
      ...
      cs-<seq>.json                        # immutable changesets, seq strictly increasing
      cs-<seq>.json
```

- `<baseSeq>` and `<seq>` draw from one monotonic counter per device; values are
  never reused. The base represents the device's full state **as of** `baseSeq`;
  every `cs-<seq>` with `seq > baseSeq` is a delta layered on top of it.
- Discovery: list `submersion-sync/v1/` to find peer device folders. S3 =
  `ListObjects` on that prefix; iCloud/Drive = directory listing. All within the
  existing `listFiles({folderId, namePattern})` capability.
- The legacy `submersion_sync_<deviceId>.json` path and its upload/download code
  are **removed**, not coexisted with (Decision 5).

## 5. File formats

### 5.1 `manifest.json`

Small; rewritten on every publish; the authoritative description of this
device's published state. It is the only mutable file, and only its owner writes
it.

```json
{
  "formatVersion": 1,
  "deviceId": "<uuid>",
  "provider": "s3|icloud|googledrive",
  "baseSeq": 412,
  "basePartCount": 9,
  "baseBytes": 419430400,
  "baseChecksum": "sha256:…",            // over the reassembled base payload
  "basePartChecksums": ["sha256:…", …],  // one per part, for resumable integrity
  "headSeq": 460,                          // highest changeset seq present
  "publishedHlcHigh": "…",                 // HLC high-water of all published data (restore detection)
  "epochId": "<library-epoch>",            // ties into existing epoch machinery
  "uploadNonce": "<uuid>",                 // twin/clone detection (as today's payload nonce)
  "updatedAt": 1718323200000
}
```

Readers derive the changeset range to pull as `[baseSeq+1 … headSeq]`. The
manifest deliberately omits a per-changeset checksum list: each `cs` file
self-validates via the `checksum` field already in `SyncPayload`, keeping the
manifest small and bounded.

### 5.2 `cs-<seq>.json` (changeset)

A `SyncPayload` (the existing v2 structure) populated as a **delta**:

- `data`: rows changed since the previous changeset's watermark — HLC-stamped
  rows with `hlc > sinceHlc`, plus their **write-once children gathered
  dive-centrically** (a dive's profile / tank-pressure / events ride along when
  that dive's row is in the delta), produced by `exportData` with its `since`
  predicate widened from `updatedAt` to the HLC watermark (`hlc > sinceHlc` on
  the 23 HLC tables) for clock-skew safety.
- `deletions`: tombstones from `deletion_log` created since the watermark.
- Header additions to the existing payload: `seq`, `sinceHlc` (watermark start),
  `toHlc` (watermark end = this device's `publishedHlcHigh` after this
  changeset). Existing fields reused: `deviceId`, `checksum`, `uploadNonce`,
  `epochId`, `exportedAt`.

### 5.3 `base-<baseSeq>.partNNN` (base snapshot)

A full export (`exportData(since: null)` — the snapshot produced today),
serialized once into a single `SyncPayload`, then sliced into ~8 MB byte parts.
Parts are raw byte slices (not individually parseable): a consumer downloads all
parts, concatenates, verifies `baseChecksum`, then parses once. Byte-slicing
keeps the format backend-agnostic (plain whole-file put/get) and gives
fine-grained resume.

## 6. Local state and schema additions (Drift v83 → v84)

The conceptual change to the local model: today's single conflated cursor
(`lastSyncTimestamp`) must split in two — what I have not yet *published*, and
how far I have *consumed* each peer — because incremental sync from multiple
peers cannot be expressed by one number.

**New table — `sync_peer_cursors`** (download progress; one row per peer ×
provider):

```
peerDeviceId   TEXT      ┐ composite
provider       TEXT      ┘ primary key   -- per-provider, mirroring the v81 cursor scoping
baseSeqApplied INT?                      -- peer baseSeq we have consumed (null until first base)
lastSeqApplied INT                       -- highest cs-<seq> from this peer we have applied
updatedAt      INT
```

**New table — `local_publish_state`** (this device's own publish position; one
row per provider, so a backend switch starts clean):

```
provider                TEXT  PRIMARY KEY
baseSeq                 INT?
basePartCount           INT?
baseBytes               INT?    -- denominator for the 30% compaction trigger
headSeq                 INT     -- highest cs seq written (the device's counter)
publishedHlcHigh        TEXT?   -- HLC high-water of published data; the next delta's watermark AND the restore detector
changesetBytesSinceBase INT     -- numerator for the 30% trigger (re-derivable from listing)
updatedAt               INT
```

> This refines the verbal Section 3 sketch ("extend `sync_metadata`"): publish
> state is **per-provider** in its own table for backend-switch correctness,
> rather than crammed into the singleton `sync_metadata` row. `sync_metadata`
> retains global device identity (`deviceId`, `instanceToken`, HLC seed).

Reused unchanged: `deletion_log` (tombstones) and the conflict rows in
`sync_records`. The *pending-record* role of `sync_records` is superseded by the
watermark (the export is now purely query-driven — "rows with `hlc >
watermark`" — so nothing is missed by a dropped pending mark); that table is
retained for conflict storage and its pending role cleaned up separately.

Migration v84 = create the two tables; no data backfill (no released prior
format). A pre-v84 backup restored later simply migrates to an empty cursor
table → clean cold-start.

## 7. Write path (publishing local changes)

During the upload phase of `performSync()`, scoped to the active provider:

1. **Recover authority if needed.** If a restore is detected (§12) or local
   publish state is missing/behind, re-read this device's own `manifest.json`
   from the cloud and set `headSeq`/`baseSeq`/`publishedHlcHigh` from it before
   doing anything else. The cloud manifest is the authority for the device's own
   published position (Invariant I4).
2. **Ensure namespace** — `createFolder` for `v1/<deviceId>/` if absent.
3. **Build the delta** — `exportData` filtered by `hlc > publishedHlcHigh`: HLC
   rows past the watermark, their write-once children gathered dive-centrically,
   plus tombstones since the watermark.
4. **Empty delta → stop.** No file is written; a routine no-op sync costs one
   manifest read per peer plus one own-manifest check.
5. **First publish with data → write a base** (`base-<seq>`), not a changeset.
   Bootstrapping is "compaction at seq 1."
6. **Otherwise write `cs-<seq>.json`** — `seq = headSeq + 1`, immutable. Large
   first changesets may be byte-sliced like a base (same resumable mechanism).
7. **Advance local state** — `headSeq = seq`; `publishedHlcHigh = max HLC
   included`; `changesetBytesSinceBase += bytes`.
8. **Rewrite `manifest.json` LAST** — the commit point. The data file is
   confirmed uploaded before the manifest references it.
9. **Evaluate the compaction trigger** (§10).

**Integration point (existing reparse path):** re-parse must bump the parent
dive's HLC so step 3's dive-centric gather re-emits the regenerated
profile/tank-pressure children. Without the bump, the watermark query never
notices the changed child rows. (Aligns with the known requirement that the
reparse path mirror the download persistence path.)

## 8. Read path (consuming peers' changes)

During the download phase of `performSync()`:

1. **Discover peers** — list `v1/`, read each peer's `manifest.json`, skip own
   `<deviceId>`.
2. **Decide what to fetch** per peer by comparing the manifest to
   `sync_peer_cursors[peerId, provider]`:

   | Cursor vs. peer manifest | Meaning | Fetch |
   |---|---|---|
   | `lastSeqApplied == headSeq` | up to date | nothing |
   | `baseSeq ≤ lastSeqApplied < headSeq` | steady-state, behind | `cs-(lastSeqApplied+1 … headSeq]` |
   | `lastSeqApplied < baseSeq` (incl. no cursor) | cold-start, or lapped by the peer's compaction | `base-<baseSeq>.*` then `cs-(baseSeq+1 … headSeq]` |

3. **Download** the needed files (resumable — §9), validating each against the
   manifest/payload checksums.
4. **Apply in seq order** — base first if fetched, then changesets ascending —
   through the existing `_applyRemotePayload` (HLC LWW + tombstone guard +
   deferred-FK repair + dependency-ordered table application). The merge core is
   unchanged.
5. **Advance the cursor only after the apply transaction commits.** An
   interrupted apply re-fetches and re-applies next time rather than skipping a
   seq.

Peers are independent logs; processing order across peers does not affect the
converged result (Invariant I5), which permits parallel peer fetch later.

**Lapped-by-compaction correctness:** a device behind a peer's current base
re-adopts that base. Because a base is a full snapshot containing everything the
deleted changesets did, and re-applying known state is an LWW no-op, deletion of
old changesets never loses data for a slow device (Invariant I8).

## 9. Resumability (both directions)

Unit of resumability = **the file**; safety net = **idempotent application**.

- **Download resume.** A `cs` file is atomic (fully fetched+validated, or
  re-fetched). A base is N parts staged in the app temp dir, each validated
  against `basePartChecksums`; on interruption only missing parts are
  re-fetched, then the whole is checksum-verified and applied. A 400 MB base
  interrupted at part 6/9 resumes at part 7.
- **Upload resume.** Base parts are uploaded one whole-file PUT at a time.
  Because the manifest is written last, a half-uploaded base is never referenced
  and is invisible to readers; the next sync re-PUTs missing parts (re-PUTting
  identical bytes is harmless) and then publishes the manifest.
- **The cursor is an optimization, not a correctness requirement.**
  Re-downloading and re-applying an already-applied file is a no-op (LWW), so
  the worst case of any interruption — dropped download, crashed apply, partial
  upload — is redundant work next sync, never corruption. Losing the entire
  local cursor table costs one expensive re-sync that converges identically.

Defaults: ~8 MB part size (tunable); partial downloads staged in the app temp
dir with per-part validation; cursor advanced post-commit only.

## 10. Compaction

Evaluated at the end of each write (§7 step 9). Trigger (Decision 8):

```
changesetBytesSinceBase ≥ 0.30 × baseBytes   OR   (headSeq − baseSeq) ≥ 200
```

The byte trigger bounds wasted bytes; the count cap backstops the
many-tiny-changesets pathology (frequent small edits whose total never reaches
30%, which would otherwise leave a cold-starting device fetching hundreds of
files). Process:

1. Export a fresh full snapshot in a **consistent read transaction**
   (`exportData(since: null)`); concurrent writes during the upload become
   post-base changesets.
2. `newBaseSeq = headSeq`; slice into ~8 MB parts; PUT each (immutable,
   resumable, runs on any connection per Decision 9).
3. Compute `baseChecksum` + `basePartChecksums`; **rewrite the manifest** (commit
   point) → `baseSeq = newBaseSeq`.
4. Reset `baseBytes`, `changesetBytesSinceBase = 0`.
5. **Reconcile-delete** superseded files (old `base-*`; `cs-(oldBaseSeq+1 …
   newBaseSeq]`) after a **grace window** (default 14 days). They are redundant
   the instant the new base lands (the base is their superset); the grace is
   only so an in-flight reader that already began fetching old changesets can
   finish.

Crash safety follows from manifest-last + reconcile-delete: interrupted part
uploads are unreferenced and invisible; cleanup is an idempotent sweep ("delete
my own `base`<`baseSeq` and `cs`≤`baseSeq` older than the grace window") that any
later sync re-runs.

Expected frequency for the target heavy user: roughly once or twice a year
(active daily-syncing diver) down to rarely (casual user). Each compaction is a
background, resumable, full-base re-upload.

## 11. Coexistence with existing subsystems

**Library epoch / "replace everywhere."** `library_epoch.json` stays at the root,
unchanged. Each manifest carries `epochId`. A "replace everywhere" bumps the
epoch and publishes a fresh base at the new epoch. Peers seeing a newer epoch
than `lastAcceptedEpochId` reset that peer's cursor and adopt the new base —
i.e., the epoch change deterministically routes them through the cold-start path
against the replacement library. The existing adopt-vs-merge / moved-marker
decision logic sits above the layout and is unchanged.

**Backend switching.** Both `sync_peer_cursors` and `local_publish_state` are
keyed by `provider`. On a new backend there are no rows → every peer is
cold-start and this device republishes its base as if new — exactly the v81
per-provider lesson. The existing "clean up old backend" step becomes
"optionally delete my `v1/<deviceId>/` subtree on the old provider."

**Twin / clone detection.** Two installs sharing a `deviceId` would both write to
`v1/<deviceId>/` and collide on seq with divergent content. The manifest's
`uploadNonce` (as today's payload nonce) detects this: a device finding its own
manifest advanced by a nonce it did not write adopts a fresh identity
(`adoptFreshIdentity()` → new `<deviceId>` namespace, republish base) — the
existing resolution on the existing signal.

## 12. Database restore (no tombstone-window dependence)

Restoring an older `.db` backup silently rewinds the data rows, `headSeq`, the
upload watermark, and the per-peer cursors at once. Correctness must not depend
on re-applying tombstones (which fails once they are pruned), so recovery
**rebuilds the device from the current authoritative library and discards the
restored data rather than merging it.**

**Detection — an impossible-unless-restored condition.** `publishedHlcHigh` (the
HLC high-water this device last published) is a required manifest field. On
launch, re-read this device's own **cloud** manifest (which a local restore
cannot rewind) and compare its `publishedHlcHigh` against the restored DB's
local HLC high-water:

```
localHlcHigh < manifest.publishedHlcHigh   ⟹   stale restore
```

This can never occur legitimately — a device cannot have published data it does
not possess. A current device sits at `==`; a device with unsynced edits at `>`;
only a rewind lands below. Comparing against the *cloud* value is essential,
since a restore rewinds the local copy too. Two detectors compose. (1) The existing `reconcileDeviceIdentity`
(`sync_initializer.dart:101`) compares the DB's `instanceToken` against a
SharedPreferences mirror that a DB restore cannot rewind — a fast, offline,
launch-time signal that already calls `rebaselineAfterRestore`. (2) This
HLC-vs-cloud-manifest comparison runs at sync time and needs no local anchors,
so it **closes the documented blind spot** in (1): a restore *predating* those
anchors — today's "needs a one-time manual Reset Sync State" case
(`sync_initializer.dart:90-93`) — is caught here automatically. The HLC check is
sufficient on its own and fires regardless of backup age; `instanceToken` is the
cheap early signal.

**Recovery:**

1. **Quarantine genuine post-restore edits** — local rows with `hlc >
   publishedHlcHigh` (e.g. a dive added after restoring, before this sync).
2. **Rebuild syncable state clean from the current published library** — re-read
   own manifest → fetch own base + changesets; cold-start-pull every peer's base
   + changesets; merge. Deleted rows are absent (as absence-in-base or
   tombstones-in-changesets). Restored stale rows are not carried forward.
3. **Graft the quarantined edits** back on top; they publish forward with fresh
   HLCs.
4. Recover the seq counter from the manifest (no reuse); reset the new
   `sync_peer_cursors` / `local_publish_state` (extending the existing
   `rebaselineAfterRestore`); resume.

**Why the 90-day window stops mattering.** A published deletion is durable for as
long as any base could still reintroduce the row, because it lives in the
changeset log until compaction folds it into the base (after which the base
simply lacks the row — a more durable "deleted"). The local 90-day
`deletion_log` prune only governs how changesets are *built*, never whether the
authoritative library reflects a deletion. Rebuilding from that library
therefore excludes deleted rows with no expiry, for any backup age.

**Residual limits (both decoupled from restore):**

- A peer deletion this device never synced *and* that is past retention — the
  irreducible floor of any sync system with finite tombstones (a device offline
  longer than the window misses the delete). Restore no longer worsens it.
- Restore-then-edit a since-deleted row revives that one row via the grafted
  edit's fresh HLC — deliberate user action, identical to retained LWW
  semantics.

**Cost.** The clean rebuild is heavy but fires only on a detected stale restore
(rare) and reuses the cold-start fetch path plus the existing Replace-mode
reconciliation. `publishedHlcHigh` is one manifest field; the detector is one
comparison.

## 13. Error handling

Governing rule: **never advance a cursor, watermark, or seq on partial success;
everything retries idempotently.**

- Interrupted up/download → resumable parts + manifest-last (§9); no full
  restart.
- Checksum mismatch on a fetched file → discard, re-fetch; if persistent, skip
  that peer this cycle (do not advance its cursor), log a warning. One bad peer
  never blocks others.
- Referenced file missing (S3 list lag, or a compaction-deletion race) → treat
  as transient, skip the peer this cycle, retry next sync.
- Unparseable manifest → skip that peer, log; other peers proceed.
- Apply failure (a row fails FK even after repair) → reuse the existing
  `recordsFailed != 0` path: do not advance, retry.
- Storage full / quota (mainly at compaction's big base) → surface error, do not
  advance; resumable so it continues when space frees.
- Insufficient temp space to stage a cold-start base → pre-check and surface a
  clear error rather than failing mid-assembly.

## 14. Testing strategy (TDD per CLAUDE.md)

Keystone: a **fake `CloudStorageProvider`** test double (in-memory key→bytes
map) that runs the whole engine deterministically and can simulate eventual
consistency (delayed LIST) to exercise transient-missing-file paths.

- **Unit:** changeset construction (since-watermark + dive-centric children +
  tombstones); compaction triggers (30% byte **and** 200-count cap); seq
  monotonicity; base slicing/reassembly + checksums.
- **Property tests** (guard the CRDT assumptions the design leans on): apply-twice
  ≡ apply-once (idempotency); apply-in-any-peer-order ⇒ identical state
  (order-independence).
- **Multi-device integration** over the fake provider: cold-start, steady-state,
  compaction-while-a-peer-lags (Case-C re-adopt), backend switch, epoch/replace,
  and an explicit **restore scenario** — rewind a device's local state and assert
  no seq reuse, convergence, and no resurrected deletes (including a backup
  *older* than the tombstone window).
- **Reuse existing patterns:** the settings-notifier mocks (adding a notifier
  method requires updating the 4 mocks — `flutter analyze` catches it),
  Apple-only `skip:` guards for any iCloud-tile tests (Linux CI), and the lcov
  null-aware / Drift-column-getter coverage gotchas (use non-null rows and
  column-referencing queries).

## 15. Invariants (load-bearing)

- **I1 — Single-writer namespace.** Only device D writes under `v1/<D>/`. No
  compare-and-swap needed.
- **I2 — Immutability once referenced.** A `cs`/`base` file is immutable once a
  published manifest references it; unreferenced orphans may be overwritten.
- **I3 — Manifest is the commit point.** Data files are uploaded before the
  manifest that references them; readers only ever see referenced-and-present
  files.
- **I4 — Monotonic, non-reused seq; cloud manifest is authority.** Seq strictly
  increases per device, never reused. The device reconciles its own counter from
  its cloud manifest before publishing.
- **I5 — Idempotent application.** Applying any base/changeset any number of
  times, in any cross-peer order, converges (LWW + tombstone). Cursors are an
  optimization, not a correctness requirement.
- **I6 — No advance on partial success.** Cursor/watermark/seq advance only after
  the relevant transaction commits.
- **I7 — `publishedHlcHigh` monotonic; cloud is authority.** A device's
  `localHlcHigh` below its *cloud manifest's* `publishedHlcHigh` ⟹ stale restore.
- **I8 — Base supersedes its changesets.** A base is a full superset of the
  changesets it replaces, so compaction never strands a lagging peer.

## 16. Media-ready seam (future, not built)

The chosen layout extends to media without rework (Decision 2): a future
`submersion-sync/v1/blobs/<sha256>` content-addressed store, with per-dive media
referenced by hash from the metadata rows, slots beside the changeset log
(Approach B becomes Approach A + a blob store). Nothing in this design precludes
it; nothing here builds it.

## 17. Open questions

- Restore detection composes the existing `reconcileDeviceIdentity` anchors with
  the new HLC-vs-cloud-manifest check (§12); the latter is designed to cover the
  former's documented "restore predating anchors → manual Reset Sync State" blind
  spot. Implementation must confirm the two compose and add a test that restores
  a pre-anchor backup and asserts automatic recovery (no manual reset).
- Default grace window (14 days) and part size (~8 MB): approved as starting
  defaults; tune against real backend latency/rate limits if needed.
