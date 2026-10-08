# Dedupe dive_data_sources rows that share a computer

Date: 2026-08-11

## Problem

A sequential dive merge (`DiveMergeService.apply`, used for "split pair"
combines where a computer logged one dive as two separate downloads) carries
over every original dive's `dive_data_sources` row as provenance
(`dive_merge_service.dart:390-408`). When both original dives were logged by
the *same* physical computer -- the common case for a split-pair merge --
this produces two `dive_data_sources` rows on the merged dive sharing one
`computer_id`.

`getProfilesByDataSource()` (`dive_repository_impl.dart:706`) builds a
`computerId -> sourceId` lookup to attribute each `dive_profiles` row to its
owning source. Two rows sharing a `computerId` collide in that map -- the
non-primary row's id silently overwrites the primary's, so every profile
point for that computer gets attributed to the non-primary row. The result,
confirmed against dive #955 (a real merged dive):

- The primary source shows "No dive profile data" even though it has the
  correct depth/duration/temperature (30.1m / 99min / 15C, matching the
  dive's own row).
- The non-primary source shows the full 642-point chart, but under its own
  stale, pre-merge stats (3.3m / 5min / 23C) -- whichever original segment
  it came from.
- The "Sources" chip row shows two identical "Petrel 3" chips, and nothing
  distinguishes which one is real.

`getDataSources()` (`dive_repository_impl.dart:5432`), which feeds the chip
row via `diveDataSourcesProvider`, returns both rows unfiltered -- so even
fixing the profile attribution alone would leave a second, empty, selectable
"ghost" chip.

Checked the current database: only dive #955 is affected today (1 of
~1,000+ dives), but the trigger -- merging two dives from the same computer
-- is the exact scenario the `split_pair` quality detector actively surfaces
and offers as a one-tap repair, so this is plausibly latent in other
merged-dive histories too, not unique to this one dive.

## Decision

Display-only fix, scoped to reading existing data correctly. No schema
change, no data migration, no change to `DiveMergeService`. Existing
affected dives self-heal the next time they're opened; nothing needs to be
rewritten in the database.

## Design

Add one private helper to `DiveRepository`
(`lib/features/dive_log/data/repositories/dive_repository_impl.dart`),
operating on the raw Drift table row (`DiveDataSourcesData`, the type
`_db.select(_db.diveDataSources).get()` returns in both call sites below,
and the same type `_mapRowToDataSource` already takes -- so one helper
serves both without a mapping-order change):

```dart
List<DiveDataSourcesData> _canonicalDataSourceRows(
  List<DiveDataSourcesData> rows,
) {
  final seenComputers = <String>{};
  final result = <DiveDataSourcesData>[];
  for (final row in rows) {
    final computerId = row.computerId;
    if (computerId == null) {
      result.add(row);
      continue;
    }
    if (!seenComputers.add(computerId)) continue; // already have the canonical row
    result.add(row);
  }
  return result;
}
```

Both queries already sort `desc(isPrimary), asc(createdAt)` before this
would run, so for any group of rows sharing a `computerId`, the first one
encountered is the primary if one exists, else the earliest-created --
exactly the row that should survive. Rows with no `computerId` (manual
entries, edited profiles) are never deduped; there is nothing to collide on.

Call sites:
- `getDataSources()` (`:5432`): run `rows` (the raw query result, before
  `_friendlyNamesFor`/`_mapRowToDataSource`) through
  `_canonicalDataSourceRows`. The chip row (`SourceBar` in
  `dive_detail_page.dart`, fed by `diveDataSourcesProvider`) iterates the
  mapped list directly, so the duplicate chip disappears -- not hidden, not
  disabled, simply not returned.
- `getProfilesByDataSource()` (`:706`): run `sourceRows` through
  `_canonicalDataSourceRows` immediately after the initial query, before
  `primary`, `sourceIdByComputer`, and the final returned map are built.
  Every other line in the function is unchanged -- `sourceIdByComputer` can
  now only ever hold one id per `computerId` because its input no longer
  has duplicates, so every profile point on that computer routes to the one
  surviving (primary-preferred) source.

Net effect on #955: the primary source becomes the sole entry, carries all
642 profile points, and its own `dive_data_sources` row already has the
correct depth/duration/temperature (verified directly) -- no fallback to
the dive's own scalar columns needed for this case, though the header UI
already has that fallback for genuinely metadata-only sources.

**Not in scope**: `getSourceKeysByDiveId()` (`:5473`), used by the import
duplicate-checker to fingerprint-match against *every* source including
non-canonical ones, must keep seeing all rows -- deduping there would let a
re-download from the "losing" duplicate source fail to register as an
exact match. Also not touched: `DiveMergeService` itself (a separate,
explicitly out-of-scope prevention fix for a future merge), and any other
direct `_db.select(_db.diveDataSources)` call site not enumerated above.

## Testing

`test/features/dive_log/data/repositories/profiles_by_data_source_test.dart`
already exercises `getProfilesByDataSource()` against a real (in-memory)
database. Add a case seeding two `dive_data_sources` rows for one dive that
share a `computerId` -- one primary with real stats, one non-primary with
different stale stats -- plus `dive_profiles` rows tagged with that shared
`computerId`, and assert the returned map has exactly one entry (the
primary's id) containing every profile point. A parallel case in whatever
test file covers `getDataSources()` (`dive_repository_test.dart` per the
existing grep) asserts the returned list has one row, not two, for the
same fixture.
