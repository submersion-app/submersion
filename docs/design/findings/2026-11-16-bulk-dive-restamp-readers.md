# What relies on the bulk writers restamping their dives (issue #4651)

Issue #4651 plans to stop the dive bulk writers calling `_bumpDives`, which
sets `dives.updated_at = now` and marks the dive pending for sync. This note
records what reads that restamp today, so the change does not swap a sync bug
for stale screens.

## The writers already stage their own children

Every bulk writer already marks the child rows it changed pending (for
example `setTankRoles` stages each `diveTanks` row, `bulkReplaceTags` stages
each `diveTags` row and logs each deletion) and only then calls `_bumpDives`.
The children travel on their own clocks since #1769, so the restamp adds
nothing to sync. It only adds the risk the issue describes.

`_mergeComputersInner` is different: `_repointDiveOwnedTables`
(`dive_computer_merge_repository.dart`) writes `dives.updated_at` itself when
a dive's `computer_id` changes. Dropping its `_bumpDives` call removes only
the restamp for dives touched through tanks, series or gear links.

Correction to the issue: the bulk course writers change `dive_courses`
(through `DiveCourseLinks`), not `course_requirement_dives`.

## Persisted caches: all covered

Every device-local cache whose result reads a child table these writers touch
already has a key that moves without a dive restamp:

| Cache | Why it is covered |
| --- | --- |
| Derived metrics, deco classification, residual and safety-review history, role consumption, sensor summaries, exposure samples | Keyed on `diveSourceStampSql`, which sums each tank's `hlc`; staging a tank (with `markRecordPending`, not `markFactsPending`) or deleting one moves it |
| Equipment condition fingerprint | Digests the set of linked dives and each sample's contact O2 |
| Change log / History | `updated_at` is a bookkeeping column; a bump-only write records nothing |

Nothing user-facing reads `dives.updated_at`: there is no "recently
modified" sort and the `Dive` entity carries no `updatedAt`.

## In-memory providers: NOT covered

The gap is Drift table ticks. Many providers refresh only when the `dives`
table is written, and today they see bulk child edits only because
`_bumpDives` writes `dives`:

- The hydrated dive list (`DiveListNotifier`, `_listBaseTables` in
  `dive_providers.dart`) ticks on `dives` plus the weight tables. It renders
  tanks, tags, dive types and courses, so a bulk edit of those would leave it
  stale until some unrelated dive write.
- `diveTypeStatisticsProvider` ticks on `dive_types` plus `dives`; the
  `dives.dive_type` mirror moves only when a dive's first type changes.
- `tableEditorNewWeightTypeProvider` ticks on `dives` only (minor).
- `courseProgressProvider` and `creditableDivesProvider` do not watch
  `dive_courses` (not confirmed whether their queries read it).
- 44 files use `watchDivesChanges()` alone; each one that reads a child table
  without watching it has the same gap. Not audited one by one.

The same gap reaches peers: once the dives row stops travelling with a bulk
child edit, a peer applying only the child rows ticks only the child tables.

## Options

1. **Keep the tick, drop the write.** Replace `_bumpDives` with
   `_db.notifyUpdates({TableUpdate.onTable(_db.dives)})` (the pattern
   `sync_service.dart` already uses after raw SQL repairs), and have the sync
   apply emit one `dives` tick when a batch carries parent-gated children.
   Every screen refreshes exactly as it does today, with no audit of the 44
   files, and no dive row is written or staged.
2. **Widen each provider's ticks.** Add the child tables each provider reads
   to its tick set, as #4442 did for weights in `_listBaseTables`. More
   precise, but every provider needs checking, and a provider missed stays
   stale.

## Decision

Option 1, chosen 2026-11-16.

- The child-only bulk writers call `_tickDives()` (a `dives` table
  notification, no write) instead of `_bumpDives`. So do `bulkAddTags` and
  `bulkRemoveTags`, which restamped every selected dive directly rather than
  through `_bumpDives`, even a dive whose tags did not change, and the
  equipment set writers `bulkAddEquipmentSets` and `bulkRemoveEquipmentSets`,
  whose shared `_rewriteGear` lives in the part file
  `dive_repository_gear_sets.dart`.
- Two bulk families also change a column of the dive itself, which only a
  dive restamp carries to peers: the representative `dives.dive_type` and
  `dives.course_id`. Those dives are still restamped, but only when the
  column actually changed. `_replaceDiveTypeRows` reports it, and the bulk
  course writers pass `markPending` to `DiveCourseLinks.refreshRepresentative`.
- `SyncDataSerializer.upsertRecord`, `upsertRecords` and `deleteRecord` tick
  `dives` after applying a row of one of the six dive child types
  (`diveChildEntitiesThatTickDives`), so a peer's screens refresh too.
- `_mergeComputersInner` keeps its restamp: it changes `dives.computer_id`,
  and its own comment says it restamps so clockless children replicate.

## Other writers that still restamp for a child-only change

Found while checking, not converted here:

- `updateTankRecordPressures` (tank pressures)
- the tag merge in `TagRepository`, which restamps every dive whose tag link
  it relinks (`TagScopeTable.restampedParentTable`)
- gas switch and profile event writers (`createGasSwitch`,
  `deleteGasSwitch`, `deleteGasSwitchesForDive`, `insertProfileEvents` and
  the event tombstone path)
