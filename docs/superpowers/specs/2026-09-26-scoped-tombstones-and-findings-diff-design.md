# Scoped tombstones and the safety findings diff (issue #1926)

Issue #1926 is item 6b of the storage reclamation audit (#1375): several delete
paths write one `deletion_log` tombstone per child row, and the safety review
rewrites every finding on every recompute. Since #1463 tombstones are
garbage-collected everywhere, so the remaining cost is write amplification and
sync payload size.

## Decisions (made with the maintainer, 2026-09-26)

| Question | Decision |
| --- | --- |
| What makes a recomputed finding "the same" | Natural key match on (rule, span), keeping the stored id; brand-new findings get a deterministic id |
| Profile edit / re-import (`clearReviewForDive`) | Keep the findings, drop only the review marker |
| Dismissals across a recompute | A kept finding keeps its dismissal |
| Wire change | In scope: a scoped tombstone, gated by the compat floor |
| Where the scoped tombstone is emitted | The split, plus every "replace all events on a dive" path |
| Representation | A synthetic entity type (approach A below) |

## Part 1: safety findings diff

### Identity

A finding's natural key is `(ruleId, startTimestamp, endTimestamp, ordinal)`,
where `ordinal` is its position among findings of the same review that share
the first three fields (0 for the first). The engine emits at most one finding
per rule per span today, so the ordinal is almost always 0; it exists so that
two identical keys can never collapse into one row.

New findings get a deterministic id:
`Uuid().v5(kSafetyFindingNamespace, '$diveId|$ruleId|$start|$end|$ordinal')`,
with nulls spelled as the empty string. This follows the existing precedents
(`quality_finding.dart`, `equipment_findings_repository.dart`). Two devices that
recompute the same dive independently therefore mint the same id for the same
new finding and converge instead of duplicating.

`SafetyReviewService.review` keeps its `idGenerator` parameter for tests, but
its default becomes the deterministic id above.

### `saveReview`

Inside one transaction:

1. Load the dive's stored findings and index them by natural key (ordinal
   computed the same way, over rows in `startTimestamp` then `id` order).
2. For each computed finding:
   - **Match found.** Keep the stored `id`, `dismissedAt` and `createdAt`. If
     `severity`, `value` and `engineVersion` are all equal, write nothing. If any
     differ, update those columns only and mark the row pending.
   - **No match.** Insert with the computed (deterministic) id, then
     `removeDeletion` for that id (a finding that stopped firing and was
     tombstoned can fire again under the same id; left in place, the tombstone
     would ride the next changeset beside the row and delete it on every peer),
     then mark pending.
3. Stored rows that matched nothing are deleted and tombstoned with one
   `logDeletions` call.
4. The marker is upserted and marked pending as today.
5. The parent dive is **no longer** marked pending. The bump predates #1769:
   both safety tables are in `parentGatedChildEntities`, so a pending marker or
   finding now exports on its own, and #1769 established that re-stamping a
   parent for a child-only change lets this device's stale dive row beat a
   peer's newer edit. The other parent bumps in this repository (`setDismissed`,
   `setDismissedForDives`) are left alone; converting them is #1769's open
   follow-up, not this issue.

`saveReview` returns the persisted `SafetyReview` (stored ids, dismissals and
creation times), and `safetyReviewProvider` returns that instead of the engine's
raw output. Without this the UI would hold ids that are not in the table and a
dismiss would silently match nothing.

`SyncEventBus.notifyLocalChange()` fires only when something was written.

### `clearReviewForDive`

Deletes and tombstones only the `diveSafetyReviews` marker (one tombstone, keyed
on `diveId`, exactly as today). The findings rows stay, so the next recompute
diffs against them and a re-import that reaches the same findings mints nothing.

### Readers of findings without a marker

`getReview` already returns null when no marker exists, so the detail page is
unchanged. The dive list's finding badge counts `dive_safety_findings` directly
(two queries in `dive_repository_impl.dart`); both gain
`AND EXISTS (SELECT 1 FROM dive_safety_reviews r WHERE r.dive_id = d.id)` so a
dive whose review was invalidated shows no badge until it is recomputed, which is
what users see today.

## Part 2: batched per-row tombstones

`DiveSplitService` tombstones its moved tanks with one `logDeletions` call
instead of a loop. Tanks stay per-row because the moved set is filtered by
references (1 to 4 rows).

## Part 3: the scoped tombstone

### Representation (approach A)

A new synthetic entity type, `diveProfileEventsScope`, in the existing
`deletion_log` (no column change). Its `recordId` encodes the scope:

| recordId | Meaning |
| --- | --- |
| `<diveId>` | every `dive_profile_events` row on that dive |
| `<diveId>\|<computerId>` | every row on that dive whose `computer_id` is that computer |

A value type, `EventScopeTombstone`, owns `encode()` / `tryDecode()` so no call
site builds the string by hand. Dive and computer ids are uuids and never
contain `|`.

The row carries the delete's clock in `origin_hlc` like any other local
tombstone, and uses the same watermark export, relay and GC. The unique index on
`(entity_type, record_id)` means a later scoped delete of the same scope replaces
the earlier one, which is correct: its clock is newer, so it covers a superset.

Rejected alternatives:

- **B, a `scope` column plus a new top-level wire key.** Rebuilds the unique
  index and touches every `deletion_log` reader; an older reader drops the key
  silently, so it is never relayed.
- **C, a generic scope expression.** Turns a remote tombstone into a
  caller-supplied `WHERE` clause for two concrete uses.
- **Extra fields on a `diveProfileEvents` entry.** Unsafe: an older
  `SyncDeletion.fromJson` ignores unknown fields and would apply the entry as a
  plain per-id delete of `id`.

### What it deletes

A row `r` is covered by scope tombstone `t` when `r.dive_id` matches, the
computer matches (if the scope names one), and `r` predates the delete:

- `r.hlc` and `t.originHlc` both present: `r.hlc <= t.originHlc`.
- Otherwise: `r.created_at <= t.deletedAt`.

This is the per-row rule from #1769 applied to a set: a row written after the
delete (a re-import's fresh events, a peer's concurrent insert) survives. The
fallback lets pre-v210 rows, which have no clock, be removed; without it a split
or re-import of an older dive would leave its events on every peer for good.

### Emitters

| Path | Scope |
| --- | --- |
| `DiveSplitService` (moved events) | `<diveId>\|<computerId>` of the split source |
| `DiveComputerRepositoryImpl.clearEventsForDive` | `<diveId>` |
| `DiveRepositoryImpl.deleteProfileEventsForDive` | `<diveId>` |
| `DiveReimportService._replaceProfileEvents` | `<diveId>` |
| `ReparseService` (events branch of `_deleteAndTombstone`) | `<diveId>` |

Each emits one scoped tombstone instead of one per event, via a new
`SyncRepository.logScopedDeletion(EventScopeTombstone)`. The tombstone is logged
before the replacement events are inserted and staged, so their clocks are newer
than the delete. The split's split-source events are exactly the set
`dive_id = P AND computer_id = C` (`ownedByComputer`), so the scope matches what
the split removes.

`ReparseService` still tombstones `gasSwitches` per row (via `logDeletions`);
switches have no computer column and are few.

### Apply

`_applyRemoteDeletions` routes entries of type `diveProfileEventsScope` to a new
`EventScopeTombstoneApplier` (its own file under `lib/core/services/sync/`), which:

1. Decodes the scope; an undecodable recordId is logged and skipped.
2. Selects the covered rows (rule above), skipping rows pending locally and rows
   the same payload presents live (the existing `contradicted` set).
3. Deletes them in chunks.
4. Relays: stores the tombstone if absent, or replaces it when the incoming
   `originHlc` is newer than the stored one. (`logDeletionIfMissing` keeps the
   first copy it sees, which for a scope would pin an older, narrower clock.)
5. Feeds the clock to `SyncClock.receive`, as the per-row path does.

Failures are caught per entry and counted, like the per-row path, so one bad
entry never aborts the batch or the cursor.

### Merge guard

Deletions apply before the merge, and the merge blocks revival only by exact id.
A lagging third peer's base can still hold the old events, so the merge gains a
check for `diveProfileEvents` records: if a stored scope tombstone covers the
incoming row by the rule above, the row is skipped. A row strictly newer than
the delete is applied. Scope tombstones are loaded once per payload into a map
keyed by dive id.

### Compat floor and schema

- New rung **v231**: `CREATE INDEX IF NOT EXISTS idx_dive_profile_events_dive_id
  ON dive_profile_events (dive_id)`, with a `beforeOpen` backstop. The scoped
  delete and merge lookups select events by dive; the table has no index on it
  today.
- `minimumCompatibleSchemaVersion` rises **224 to 231**, with a history entry:
  this build publishes scope tombstones that an older reader stores as an inert
  unknown type, leaving the covered events on that device for good.
- An older reader that somehow receives one anyway does no harm: an unknown
  entity type deletes nothing (pinned by
  `unknown_entity_type_forward_compat_test.dart`).
- `cross_version_roundtrip_test.dart` is extended as its header requires.

## Measurement

A test, `tombstone_amplification_measurement_test.dart`, seeds a realistic
logbook and counts `deletion_log` rows:

- **Engine bump:** 200 dives with 0 to 6 findings each, reviewed, then
  recomputed at a higher engine version with unchanged findings. Before: one
  tombstone per stored finding. After: zero.
- **Re-import of a long dive:** 300 events replaced. Before: 300. After: 1.
- **Split of a long dive:** 300 events on the split source plus 2 moved tanks.
  Before: 302 plus the series and source tombstones. After: 1 scope, 2 tanks,
  plus the unchanged series and source tombstones.

The before numbers are measured on this branch's parent commit with the same
harness and quoted in the PR description.

## Testing

- Findings diff: unchanged recompute writes and tombstones nothing; a changed
  severity updates in place and keeps the dismissal; a finding that disappears is
  tombstoned; a re-fired deterministic id clears its old tombstone; two
  independent recomputes produce the same ids; the provider returns stored ids.
- `clearReviewForDive`: only the marker is tombstoned; findings remain; the
  badge hides until recompute.
- Scoped tombstone: encode/decode; apply deletes covered rows and keeps newer,
  pending, contradicted and other-computer rows; null-clock fallback; relay keeps
  the newest clock; merge guard blocks a stale row and admits a newer one;
  two-device round trip through `performSync`; the floor holds a v230 reader.
- Each emitter: one scope tombstone and no per-event tombstones.

## Out of scope

- Converting other per-row loops (gas switches, uncombine segments,
  consolidation undo): subsets or few rows.
- Scopes for tables other than `dive_profile_events`.
