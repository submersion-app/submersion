# Species Sighting Count Refresh Design

## Problem

`speciesSightingCountsProvider` caches the result of
`SpeciesRepository.sightingCountsBySpecies()`, but the provider does not
subscribe to any database change tick. The query reads the `sightings` table,
so a sync pull, merge, bulk edit, or other direct database write can leave the
species-management page using stale sighting counts. The architecture test now
detects this missing subscription on `main`, which also blocks PRs #1003 and
#1004 even though neither PR changes marine-life code.

## Goal

Refresh `speciesSightingCountsProvider` whenever the `sightings` table changes,
and protect that behavior with both a provider-level regression test and the
existing architecture test.

## Non-goals

- Do not change how sighting counts are calculated.
- Do not change species selection or deletion behavior.
- Do not broaden `watchSpeciesChanges()` to include unrelated tables.
- Do not use the broad, debounced dive-detail tick for this focused aggregate.
- Do not modify either PR's feature-specific files.

## Considered Approaches

### 1. Dedicated sightings-table tick (selected)

Add `SpeciesRepository.watchSightingChanges()`, backed only by Drift updates to
the `sightings` table, and subscribe the count provider with
`ref.invalidateSelfWhen`.

This follows the repository's existing table-tick pattern, matches the table the
query actually reads, reacts to direct sync writes, and avoids invalidating on
unrelated dive-detail changes.

### 2. Reuse `DiveRepository.watchDiveDetailChanges()`

This stream includes `sightings`, so it would make the provider correct, but it
also watches many other detail tables and is debounced. The count provider would
refresh for unrelated tanks, profiles, equipment, media, and safety-review
writes. That coupling and extra work are unnecessary.

### 3. Manually invalidate after known writes

Manual invalidation already happens after one page-level bulk-delete path, but
it cannot cover sync pulls, consolidation, merges, repository-level bulk edits,
or future writers. It would preserve the stale-cache defect at the database
boundary.

## Design

`SpeciesRepository` will expose:

```dart
Stream<void> watchSightingChanges() =>
    _db.tableUpdates(TableUpdateQuery.onTable(_db.sightings));
```

`speciesSightingCountsProvider` will keep a local repository reference,
subscribe with `ref.invalidateSelfWhen(repository.watchSightingChanges())`, and
then call `repository.sightingCountsBySpecies()`.

No additional debounce is needed. The provider is watched only by the species
management surface, and invalidation should track the settled table state after
each committed write. Riverpod handles subscription disposal with the provider.

## Data Flow

1. A local action or sync operation commits a write to `sightings`.
2. Drift emits a table-update event through `watchSightingChanges()`.
3. `invalidateSelfWhen` invalidates `speciesSightingCountsProvider`.
4. An active watcher causes the provider to rerun
   `sightingCountsBySpecies()`.
5. The species-management page receives the new count map and recalculates
   which species are selectable for deletion.

## Testing

Add a provider regression test that:

1. Creates a species and a dive in the test database.
2. Keeps `speciesSightingCountsProvider` alive with an active listener.
3. Confirms the initial count map is empty.
4. Writes a sighting through `SpeciesRepository` without manually invalidating
   the provider.
5. Polls the provider until the species count becomes one and asserts that
   result.

The test must fail before the production change because the cached provider
continues returning the empty map. After implementation, run the provider test,
the architecture test, formatting, analysis, and the full Flutter test suite.

## Delivery

Publish the fix as a small shared PR based on `main`. Once the commit is on the
two affected branches, rerun PR #1003 and PR #1004 checks. Keeping the fix in a
single commit makes it easy for `main` and both feature branches to converge on
the same history.
