# Tombstone GC and Device Retirement (Fleet-Acked Horizon)

Date: 2026-07-16
Status: Implemented (schema v114 -- renumbered twice while the PR was open: planned as v112, moved to v113 after main claimed v112 for equipment.thickness, then to v114 after main claimed v113 for the CNS calculation method; see docs/superpowers/plans/2026-07-16-tombstone-gc-device-retirement.md)

## Problem

The incremental sync transport (PR #330) already solves changeset growth: each
device publishes a compacted base plus append-only changesets, compaction
rewrites a fresh base and inline-prunes superseded files, and readers are
gap-tolerant (a peer whose cursor points below a pruned changeset cold-starts
from the new base). Two growth/correctness gaps remain:

1. **Tombstone GC vs. long-offline devices.** `clearOldDeletions(olderThanDays: 90)`
   runs after every successful sync (`sync_service.dart`), so the deletion log
   and every published base carry at most ~90 days of tombstones. A device
   offline longer than 90 days that still holds a row deleted elsewhere finds
   no tombstone anywhere when it returns; it keeps the row and republishes it
   on its next base rewrite, resurrecting the record fleet-wide. Nothing
   detects "this peer was away longer than the tombstone window" (the
   stale-restore detector only compares a device against its own cloud
   manifest).

2. **Dead-device log GC.** A retired phone's manifest, base, and changesets sit
   in the bucket forever; every peer lists and considers them on every sync.
   `deleteDeviceSyncFile` documents the failure mode: "if the provider is
   offline the log lingers indefinitely as a stale peer."

A related pathology feeds gap 1: routine dive edits generate tombstones, not
just user deletes. `updateDive` delete-and-reinserts weights, equipment
junctions, and custom fields, calling `logDeletion` (not `logDeletionIfMissing`)
per removed row, so editing one dive 50 times writes ~150 duplicate tombstones
for the same three junction keys.

## Decisions (settled with the user)

- **Retention policy: fleet-acked horizon.** A tombstone is GC'd only after
  every live device has provably applied it. Time-based `clearOldDeletions`
  is replaced. Chosen over a fixed window because divers commonly own a
  seasonal secondary device (the iPad that syncs once a year on the annual
  trip); a fixed window fences that device on every trip.
- **Fence behavior: silent cloud-wins.** A device returning after retirement
  is rebuilt from the cloud library automatically. Its previously-synced
  records that were deleted elsewhere are removed locally with no prompt and
  no quarantine export. Its unpublished (pending) records are re-merged, so
  offline-logged dives are never lost.
- **Retirement period: 12 months. Heartbeat: 7 days. Safety floor: 30 days.**
  Constants, adjustable at implementation time.
- **Tombstone dedupe is folded in** regardless of horizon mechanics:
  `logDeletion` becomes an upsert per `(entityType, recordId)`.

## Architecture

Both mechanisms share one liveness primitive: the per-device manifest, which
is already the atomic commit point of every publish and therefore doubles as
a presence record. No new registry, no coordinator.

### 1. Manifest changes (additive fields, no format break)

- `appliedPeerHlc: {peerDeviceId: hlcHigh}` — the highest HLC this device has
  applied from each peer's log. Updated whenever a pull applies data; written
  with the next manifest rewrite.
- **Heartbeat:** a sync that neither applies nor publishes anything still
  rewrites the manifest when `updatedAt` is older than 7 days. Today an empty
  publish is a no-op, so a read-mostly device's manifest goes stale even while
  it syncs daily; the heartbeat makes `manifest.updatedAt` a reliable
  liveness signal.

Old-format manifests (no `appliedPeerHlc`) are treated as acknowledging
nothing. In a mixed-version fleet this stalls GC entirely — strictly safer
than today's unconditional 90-day purge — until all devices upgrade.

### 2. Tombstone GC: fleet-acked horizon

At compaction/publish time, device A may drop a tombstone with HLC `H` when
both hold:

- For every peer manifest that is **not durably fenced** (no retirement
  marker confirmed present in the bucket), `appliedPeerHlc[A] >= H`. A
  manifest with no `appliedPeerHlc` entry for A (a device that has not yet
  pulled A's log, or an old-format manifest) acknowledges nothing and blocks
  GC. Manifest age deliberately does NOT exempt a peer: a stale peer whose
  retirement-marker upload failed is unfenced, and GC'ing past it would let
  it later rejoin without the fence and resurrect deleted rows. The
  retirement sweep reports exactly which markers are durably present, and GC
  exempts only that set (a stale peer therefore blocks GC for at most the one
  sync in which its marker is written).
- `deletedAt` is older than the 30-day safety floor (covers in-flight device
  joins and twin splits).

Consequences:

- A single-device library GCs down to the floor.
- A fleet's deletion log is bounded by its slowest live device, which
  retirement caps at 12 months.
- HLC comparison uses the fixed-width zero-padded canonical string form, the
  same convention as the existing changeset filters (see the v86 deletion-HLC
  work); legacy sentinel HLCs (`...:legacy`) sort below any real HLC and are
  GC-eligible once past the floor.

Why new devices are safe: they cold-start from bases whose data already
excludes deleted rows. Resurrection requires a device that still *holds* the
row, and the horizon guarantees every live holder has applied the deletion.
The base continues to carry the (now bounded) full deletion log, preserving
the existing no-resurrection guarantee for cold-starting peers.

### 3. Tombstone dedupe at the source

`logDeletion` becomes an upsert keyed on `(entityType, recordId)`, keeping the
newest `deletedAt` and `hlc`. A schema migration dedupes existing rows
(keeping the newest per key) and adds a unique index. `logDeletionIfMissing`
remains for the merge path (its insert-if-absent semantics are unchanged by
the unique index). Re-deleting a record refreshes its tombstone's timestamp
and HLC, which is the desired semantics.

### 4. Device retirement

During sync, any device that observes a peer manifest with `updatedAt` older
than 12 months:

1. Writes a retirement marker `ssv1.<deviceId>.retired.json` with fields
   `{formatVersion, deviceId, retiredAt}`. Concurrent retirers write the same
   file name with semantically equivalent content (retiredAt may differ by
   the race window); last write wins and either copy fences identically, so
   the operation is idempotent in effect.
2. Deletes the retiree's manifest, base parts, and changesets.

Order matters: marker first, then file deletion, so a partially-completed
retirement still fences the returning device. Leftover files after a partial
retirement are inert (peers skip retired device ids) and are swept by the next
peer's retry. Markers are tiny and persist until the device rejoins.

Retirement applies regardless of manifest format version. An actively-syncing
old-version client that gets wrongly retired self-heals: the writer already
treats the cloud manifest as authority, and a missing manifest cold-starts a
fresh base (PR #330 device-verification fix 2). Its data is current, so the
republish resurrects nothing.

### 5. The fence: retired device returns

Trigger: on sync, a device finds its own retirement marker; or its manifest is
missing while local publish state records a prior base *and* the marker check
confirms retirement (distinguishing retirement from a transient list
inconsistency on eventually-consistent backends — when in doubt, treat as
transient and retry).

Flow, fully automatic, no user interaction:

1. Snapshot the device's pending records (the existing `markRecordPending`
   bookkeeping identifies unpublished local changes).
2. Adopt the current cloud library as authoritative, reusing the existing
   adopt/rebuild path. Local records absent from the cloud with no tombstone
   are removed (silent cloud-wins).
3. Re-apply the pending snapshot and let the normal merge rules run:
   offline-created records merge in; a pending edit to a remotely-deleted
   record follows the existing newer-edit-revives-deletion rule.
4. Publish a fresh base under the same device identity, then delete the
   device's own retirement marker. The device is live again from this point.

User experience: open the app after two years, sync runs, the library
converges to the fleet's current state plus any dives logged on this device
while offline. No error state, no manual re-pairing.

## Invariants

1. **No resurrection at any offline duration.** A tombstone exists somewhere
   reachable (peer deletion logs and bases) until every device that could
   hold the row has either applied it or been retired; retired devices are
   fenced through cloud-wins rebuild before they may publish.
2. **Offline-created dives always survive.** Pending records are snapshotted
   before the fence rebuild and re-merged after.
3. **Bases always carry the full retained deletion log** (the existing
   base-always-full invariant, now over a bounded log).
4. **GC and retirement only delete what is provably safe.** Acked-by-all-live
   tombstones; logs of devices already fenced by a durable marker. A stale
   listing delays GC by one cycle but never makes it wrong.
5. **Marker before deletion.** A returning device can always detect its own
   retirement.

## Failure handling

- **Clock skew:** liveness compares wall-clock `updatedAt` against a 12-month
  threshold; realistic skew is orders of magnitude smaller.
- **Concurrent retirement by two peers:** identical marker content; file
  deletions are idempotent.
- **Retirement of a device mid-return:** the returning device either sees the
  marker (fences) or completes a publish that refreshes `updatedAt` before the
  retirer lists (stays live). The 30-day safety floor plus the 12-month
  threshold make the race window practically unreachable; the fence is the
  backstop either way.
- **Transient missing manifest:** never treated as retirement without the
  marker; the existing cold-start-fresh-base behavior remains the fallback.

## Testing

Property-style tests on the existing `FakeCloudStorageProvider` multi-device
harness (`changeset_sync_convergence_test.dart` pattern):

- Multi-device convergence with GC interleaved at every compaction; assert no
  tombstone needed by any live device is ever dropped.
- Seasonal device: offline 11 months, deletions happen fleet-wide, device
  returns; tombstones were retained for it; clean resume, no fence, full
  convergence.
- Fence: device offline 13 months, retired by a peer, returns holding both
  pending offline dives and stale previously-synced rows; converges with the
  dives kept and published, stale rows removed, no resurrection on any peer.
- Mixed-version fleet (one manifest without `appliedPeerHlc`): GC fully
  stalls; nothing is dropped.
- Single-device library: GC down to the 30-day floor.
- Partial retirement (marker written, deletions interrupted): returning
  device still fences; next peer sweeps leftovers.
- Heartbeat: pull-only device stays live past 12 months of never publishing.
- Migration: dedupe of a deletion log containing duplicate
  `(entityType, recordId)` rows keeps the newest and adds the unique index;
  `logDeletion` upsert semantics.

## Out of scope

- Media/blob GC (media sync is a separate program).
- A device-management UI (listing/retiring devices manually). Reset Sync
  State already deletes the local device's own log; retirement here is
  automatic only.
- Changing merge semantics (row-level HLC LWW is unchanged).
- Backup/restore interactions beyond what the existing stale-restore detector
  and epoch machinery already cover.

## Constants

| Constant | Value | Rationale |
| --- | --- | --- |
| Retirement period | 12 months | Longer than any realistic seasonal-device cycle |
| Heartbeat interval | 7 days | Cheap (one small manifest PUT); keeps liveness fresh |
| GC safety floor | 30 days | Covers in-flight joins, twins, and backend list lag |
