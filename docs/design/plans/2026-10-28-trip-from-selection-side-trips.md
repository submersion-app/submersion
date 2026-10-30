# New Trip From Selection and Side Trips Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver turn selected dives into a new trip, prefilled from those dives, and let a trip be a side trip of one larger trip whose per-trip figures include the side trip's dives.

**Architecture:** One nullable column, `trips.parent_trip_id`, read through a single validity rule (parent exists, parent has no parent, not self) that lives once in SQL (`side_trip_sql.dart`) and once in Dart (`side_trips.dart`). Every per-trip dive query swaps `trip_id = ?` for an inclusive scope built from that rule; cross-trip samples keep only top-level trips. The creation flow reuses `TripEditPage` with a prefilled draft passed as a route `extra`.

**Tech Stack:** Flutter, Riverpod 3, Drift (SQLite), go_router, ARB l10n.

**Spec:** `docs/design/specs/2026-10-28-trip-from-selection-side-trips-design.md`

## Global Constraints

- Schema version **323** (main is at 320; 321 is claimed by a local worktree, 322 by PR #3726). Re-check open PRs before pushing and renumber if taken.
- No database foreign key on `parent_trip_id`: a link to a trip deleted on another device must not fail a sync apply. Readers treat a dangling link as "no parent".
- Validity rule, everywhere: a trip C has parent P only when `C.parent_trip_id = P.id`, P exists, `P.parent_trip_id IS NULL`, and `P.id <> C.id`.
- Per-trip figures are inclusive (own dives plus valid side trips' dives). Cross-trip samples and rankings use top-level trips only. Nothing counts a dive twice.
- Every SQL over `dives` either carries `DiveStatsScope` or a `stats-scope-exempt:` comment (`test/core/database/dive_stats_scope_census_test.dart`).
- Files stay under 800 lines; do not grow `trip_edit_page.dart` (1214), `trip_list_content.dart` (1340), `dive_detail_page.dart` (5691) or `dive_list_content.dart` by more than the wiring lines named below.
- Every new user-facing string is in `app_en.arb` and translated into ar, de, es, fr, he, hu, it, nl, pt, zh; run `flutter gen-l10n` last. No hard-coded digit inside an ARB `=1{}` branch: use `one{}`.
- Dates render through `UnitFormatter` (`formatMonthYear`, `formatMonthDay`), never `DateFormat` in presentation code.
- Before each commit: `dart format .`, `flutter analyze`, the task's tests. After adding any `lib/` file: `flutter test test/architecture/ test/shared/`.

## Review Focus

1. **A selection whose dives straddle midnight or a month end.** Dates come from each dive's wall-clock day (UTC components of `dive_date_time`), so a 23:30 dive on Mar 31 gives an end date of Mar 31, not Apr 1. Test in Task 10.
2. **Deleting a side trip the active profile does not own the parent of, or whose dives belong to several profiles.** Every profile's dives move to the parent. Test in Task 5.
3. **An invalid chain arriving by sync (A part of B, B part of C) or a self link.** Reads treat B's children as standalone and a self link as none; no query loops or double counts. Tests in Task 2 and Task 3.
4. **The trip list filtered so a side trip matches but its parent does not.** The side trip shows as a top-level row with "Part of <parent>". Test in Task 7.
5. **A side-trip dive tank-linked to the parent's cylinder, then the side trip is detached.** The link is cleared and staged; while attached it survives a move and shows in the parent's board. Tests in Task 4.

---

### Task 1: Column, entity, mapping and sync labelling

**Files:**
- Modify: `lib/core/database/tables/trip_tables.dart` (add `parentTripId` to `Trips`)
- Modify: `lib/core/database/migrations/helpers/trip_migrations.dart` (add `_assertTripParentColumn`)
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (rung 323)
- Modify: `lib/core/database/migrations/before_open_child_columns.dart` (backstop call)
- Modify: `lib/core/database/database.dart` (`currentSchemaVersion = 323`, append `323` with a comment to `migrationVersions`; floor unchanged)
- Modify: `lib/features/trips/domain/entities/trip.dart` (`parentTripId`, `copyWith`, `props`)
- Create: `lib/features/trips/data/repositories/trip_row_mapper.dart` (move `_mapRowToTrip` and `_mapDataToTrip` out of `trip_repository.dart`, which is at 789 lines)
- Modify: `lib/features/trips/data/repositories/trip_repository.dart` (`createTrip` and `updateTrip` write the column; use the mapper)
- Modify: `lib/core/services/sync/conflict_reference.dart` (`_defaultTargets`: `'parentTripId': 'trips'`)
- Test: `test/core/database/migration_v323_trip_parent_test.dart`, `test/features/trips/data/repositories/trip_repository_test.dart`, `test/features/trips/domain/entities/trip_test.dart` (create if absent)

**Interfaces:**
- Produces: `TextColumn get parentTripId => text().nullable()();` (no `.references`), SQL `trips.parent_trip_id`, index `idx_trips_parent_trip_id`.
- Produces: `Trip.parentTripId` (`String?`); `Trip.copyWith({Object? parentTripId = _undefined, ...})`.
- Produces: `domain.Trip tripFromRow(Trip row)` and `domain.Trip tripFromData(Map<String, Object?> data)` in `trip_row_mapper.dart`.

- [ ] **Step 1: Write the failing migration test**, modelled on `migration_v315_omit_unused_oc_gases_test.dart`: `test('v323 is in the ladder')` asserting `migrationVersions` contains 323 and `minimumCompatibleSchemaVersion` is not 323; `test('upgrading from v322 adds a null parent to every trip')` with a v322 fixture holding a minimal `trips` table and one row, asserting `PRAGMA table_info('trips')` has `parent_trip_id` and the row reads null; `test('the backstop is idempotent')` running the open twice.
- [ ] **Step 2: Run it.** `flutter test test/core/database/migration_v323_trip_parent_test.dart`; expect FAIL (no 323).
- [ ] **Step 3: Implement.** `_assertTripParentColumn()` mirrors `_assertTripReturnFlightColumn` (PRAGMA check, `ALTER TABLE trips ADD COLUMN parent_trip_id TEXT`, then `CREATE INDEX IF NOT EXISTS idx_trips_parent_trip_id ON trips(parent_trip_id)`; returns early when `trips` is absent). Rung: `if (from < 323) await _assertTripParentColumn(); if (from < 323) await reportProgress();` with a comment naming issue #3658 and the held 321/322. Call it from `before_open_child_columns.dart`. Run `dart run build_runner build --delete-conflicting-outputs`.
- [ ] **Step 4: Run the migration test**; expect PASS.
- [ ] **Step 5: Write failing entity and repository tests**: `copyWith(parentTripId: null)` clears, omitted keeps, `props` includes it; `createTrip` then `getTripById` round-trips `parentTripId: 'p1'`; `updateTrip(trip.copyWith(parentTripId: null))` clears it; `getAllTripsWithStats` maps it.
- [ ] **Step 6: Implement** the entity field, the mapper move (`tripFromRow`/`tripFromData` read `parent_trip_id`), and `parentTripId: Value(trip.parentTripId)` in both companions.
- [ ] **Step 7: Run** `flutter test test/features/trips test/features/settings/presentation/conflicts test/core/database/migration_v323_trip_parent_test.dart`; expect PASS (the conflict coverage test passes through the reference target).
- [ ] **Step 8: Commit** `feat(trips): store a side trip's parent trip`.

### Task 2: The side-trip rule, in SQL and in Dart

**Files:**
- Create: `lib/features/trips/data/side_trip_sql.dart`
- Create: `lib/features/trips/domain/services/side_trips.dart`
- Test: `test/features/trips/data/side_trip_sql_test.dart`, `test/features/trips/domain/services/side_trips_test.dart`

**Interfaces:**
- Produces (SQL fragments; `tripRef` is a bound parameter such as `?1` or a column such as `t.id`):
  - `String sideTripIdsSql(String tripRef)`: `SELECT c.id FROM trips c JOIN trips p ON p.id = c.parent_trip_id WHERE c.parent_trip_id = <tripRef> AND p.parent_trip_id IS NULL AND c.id <> p.id`
  - `String validParentIdSql(String tripRef)`: `SELECT p.id FROM trips c JOIN trips p ON p.id = c.parent_trip_id WHERE c.id = <tripRef> AND p.parent_trip_id IS NULL AND p.id <> c.id`
  - `String tripDivesScopeSql(String diveAlias, String tripRef)`: `(<a>.trip_id = <tripRef> OR <a>.trip_id IN (<sideTripIdsSql>))`
  - `const String topLevelTripSql`: predicate on alias `t`, true when `t` has no valid parent: `NOT EXISTS (SELECT 1 FROM trips p WHERE p.id = t.parent_trip_id AND p.parent_trip_id IS NULL AND p.id <> t.id)`
- Produces (Dart): `String? effectiveParentId(Trip trip, Map<String, Trip> tripsById)`; `bool canChooseAsParent(Trip candidate, {required String forTripId})` (false for itself and for a trip with a non-null `parentTripId`).

- [ ] **Step 1: Write failing tests.** SQL tests against an in-memory `AppDatabase`: trips A (top), B part of A, C part of B (invalid chain), D part of D (self), E part of "gone" (dangling). Assert `sideTripIdsSql('?1')` for A returns `{B}`, for B returns `{}`; `validParentIdSql` for B gives A, for C, D, E gives none; `topLevelTripSql` keeps A, C, D, E and drops B. Dart tests assert the same five cases for `effectiveParentId`, and `canChooseAsParent` false for self and for B.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement** the four fragments and two functions.
- [ ] **Step 4: Run**; expect PASS.
- [ ] **Step 5: Commit** `feat(trips): one rule for which trips are side trips`.

### Task 3: Inclusive per-trip dives and stats, side-trip lookups

**Files:**
- Modify: `lib/features/trips/data/repositories/trip_repository.dart` (`getDiveIdsForTrip`, `getDiveCountForTrip`, `getTripWithStats`, `getAllTripsWithStats`)
- Create: `lib/features/trips/data/repositories/side_trip_repository.dart`
- Create: `lib/features/trips/presentation/providers/side_trip_providers.dart`
- Modify: `lib/features/media/data/repositories/media_library_repository.dart:98-101` (trip filter inclusive)
- Test: `test/features/trips/data/repositories/trip_repository_side_trips_test.dart`, `test/features/trips/data/repositories/side_trip_repository_test.dart`, the media library repository test

**Interfaces:**
- Consumes: `sideTripIdsSql`, `tripDivesScopeSql`, `validParentIdSql` (Task 2).
- Produces: `class SideTripRepository { Future<List<Trip>> getSideTrips(String tripId, {String? diverId}); Future<Trip?> getParentTrip(String tripId, {String? diverId}); Stream<void> watchChanges(); }`, both reads applying `VisibilityFilter` for `SharedItemKind.trip`.
- Produces: `sideTripRepositoryProvider`, `sideTripsProvider` (`FutureProvider.family<List<Trip>, String>`), `parentTripProvider` (`FutureProvider.family<Trip?, String>`), each invalidated on `watchTripsChanges()`.

- [ ] **Step 1: Write failing tests**: parent P with 2 own dives and side trip S with 3; `getDiveIdsForTrip(P)` has 5, `getDiveIdsForTrip(S)` has 3; `getTripWithStats(P).diveCount == 5` and max depth spans S's deepest; `getAllTripsWithStats` gives P 5 and S 3; with S's parent made invalid (P given a parent) P gives 2. Media: filtering by P returns S's dive media. `SideTripRepository`: `getSideTrips(P) == [S]`, `getParentTrip(S) == P`, `getParentTrip` null when P is hidden from the profile or invalid.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement.** Replace `WHERE trip_id = ?` with `tripDivesScopeSql('dives', '?1')` (renumber binds to `?1`/`?2` as needed). In `getAllTripsWithStats` the join becomes `LEFT JOIN dives d ON <tripDivesScopeSql('d', 't.id')> ...` keeping `COUNT(DISTINCT d.id)` and the ON-clause scope. Media: `d.tripId.equals(tripId) | d.tripId.isInQuery(...)` or a `CustomExpression` of the fragment.
- [ ] **Step 4: Run** the new tests plus `test/features/trips test/features/media`; expect PASS.
- [ ] **Step 5: Commit** `feat(trips): a larger trip includes its side trips' dives`.

### Task 4: Cylinders shared with side trips

**Files:**
- Modify: `lib/features/dive_log/data/repositories/trip_cylinder_links.dart` (`clearForeignTripCylinderLinks`, `tripCylinderIdsForTrip`)
- Modify: `lib/features/trips/data/repositories/trip_cylinder_repository.dart` (`getTankUsesForTrip`, `getGasRecordTanksForTrip`, `countTripDiveRoundsOn` inclusive; `getUnlinkedTanksForTrip` own dives, own-or-parent slots; new `linkableTripIds`)
- Modify: `lib/features/trips/presentation/providers/trip_cylinder_providers.dart` (`tripCylinderStatesAtProvider`, `tripCylinderLabelsAtProvider` merge parent slots)
- Test: `test/features/trips/data/repositories/trip_cylinder_side_trip_test.dart`

**Interfaces:**
- Consumes: `validParentIdSql`, `tripDivesScopeSql` (Task 2).
- Produces: `Future<List<String>> TripCylinderRepository.linkableTripIds(String tripId)` returning `[tripId]` or `[tripId, parentId]`.
- Rule: a slot is "own" for trip T when `trip_cylinders.trip_id = T OR trip_cylinders.trip_id = (<validParentIdSql(T)>)`.

- [ ] **Step 1: Write failing tests**: P has slot X; S part of P has slot Y; dive on P linked to X moved to S with `assignDivesToTrip` keeps the X link; dive on S linked to X appears in `getTankUsesForTrip(P)` and `getGasRecordTanksForTrip(P)`; `countTripDiveRoundsOn(P, day)` counts S's dives; `getUnlinkedTanksForTrip(S)` excludes a tank linked to X; `tripCylinderIdsForTrip(db, S) == {X, Y}`; after `updateTrip(S.copyWith(parentTripId: null))` the X link is cleared and the tank is pending (Review Focus 5); `linkableTripIds(S) == [S, P]`.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement** the widened rule in both link helpers and the queries; in `updateTrip` (Task 1 file), when the stored `parent_trip_id` differs from the new one, run `clearForeignTripCylinderLinks` for each dive on the trip inside the same transaction. Providers fold each id from `linkableTripIds` and concatenate (own trip first).
- [ ] **Step 4: Run** the new test plus `test/features/trips test/features/dive_log/data`; expect PASS.
- [ ] **Step 5: Commit** `feat(trips): side trips share the larger trip's cylinders`.

### Task 5: Deleting trips and profiles keeps side-trip dives

**Files:**
- Create: `lib/features/trips/data/repositories/side_trip_links.dart`
- Modify: `lib/features/trips/data/repositories/trip_repository.dart` (`deleteTrip`: call before `clearDiveTripLinks`)
- Modify: `lib/features/divers/data/repositories/diver_repository.dart` (Step 2b: call before `clearDiveLinksToDiverRows` with the diver's trip ids)
- Test: `test/features/trips/data/repositories/side_trip_delete_test.dart`, `test/features/divers/data/repositories/` (the diver delete test file covering trips)

**Interfaces:**
- Consumes: `validParentIdSql` (Task 2).
- Produces: `Future<void> detachSideTripsForDelete(AppDatabase db, SyncRepository syncRepository, List<String> tripIds, {required int now})`: (a) each trip in `tripIds` with a valid parent not in `tripIds` hands every profile's dives to that parent (`UPDATE dives SET trip_id = ?, updated_at = ?`, each dive marked pending, `updates: {db.dives}`); (b) each trip not in `tripIds` whose `parent_trip_id` is in `tripIds` gets `parent_trip_id = NULL`, `updated_at`, a fresh `hlc` from `issueRowClock()`, and is marked pending as `trips`.

- [ ] **Step 1: Write failing tests**: deleting S moves S's dives (two profiles) to P, keeps their X links, and marks them pending (Review Focus 2); deleting P leaves S standalone, pending, with its dives; deleting both P and S in one profile delete leaves no dive pointing at either; a profile delete of S's owner moves surviving profiles' dives to P.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement** and wire both call sites inside their existing transactions.
- [ ] **Step 4: Run** the new tests plus `test/features/trips test/features/divers`; expect PASS.
- [ ] **Step 5: Commit** `feat(trips): deleting a side trip returns its dives to the larger trip`.

### Task 6: Rankings, history, query language and the dive list trip filter

**Files:**
- Modify: `lib/features/insights/data/repositories/insights_repository.dart:2133` (top trips: `topLevelTripSql`, inclusive join)
- Modify: `lib/features/trips/data/repositories/trip_history_repository.dart:43` (same)
- Modify: `lib/features/trips/query/trip_query_entity.dart` (`diveCountField('trips', <inclusive link>)`; new relation `partOf`)
- Modify: `lib/features/dive_log/query/dive_filter_query.dart:53` (inclusive trip condition)
- Test: `test/features/insights/...` (the top-trips test file), `test/features/trips/data/repositories/trip_history_repository_test.dart`, `test/features/trips/query/trip_query_entity_test.dart`, `test/features/trips/query/trip_filter_query_semantics_test.dart`, the dive filter query semantics test

**Interfaces:**
- Produces: `QueryRelation(key: 'partOf', target: QuerySubject.trips, shape: RelationShape.fk, joinSql: '{to}.id = {from}.parent_trip_id', targetFilterSql: '{to}.parent_trip_id IS NULL AND {to}.id <> {from}.id' /* if targetFilterSql cannot see {from}, keep only the first clause */, isMany: false, labelKey: 'query_trips_partOf')`.
- Produces: `DiveFilterState(tripId: T).toQuery()` emits `OrNode([trip = T, ConditionNode(FieldPath(['trip', 'partOf']), eq, T)])`.

- [ ] **Step 1: Write failing tests**: the top-trips ranking lists P with 5 dives and not S; `divesPerDiveDay` samples P with S's dives and does not sample S; the query `diveCount > 4` matches P; `partOf = P` matches S; the dive filter for P returns S's dives and for S only S's.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement**; add `query_trips_partOf` to `app_en.arb` now (translations land in Task 11).
- [ ] **Step 4: Run** the listed tests plus `test/core/query test/features/query test/features/dive_log/query`; expect PASS.
- [ ] **Step 5: Commit** `feat(trips): side trips in rankings, history and filters`.

### Task 7: Trip list nesting

**Files:**
- Create: `lib/features/trips/presentation/helpers/trip_list_rows.dart`
- Modify: `lib/features/trips/presentation/widgets/trip_list_content.dart` (`_buildTripList` builds rows through the helper; table mode stays flat)
- Modify: `lib/features/trips/presentation/widgets/compact_trip_list_tile.dart`, `dense_trip_list_tile.dart`, and the detailed `TripListTile` (new optional params)
- Test: `test/features/trips/presentation/helpers/trip_list_rows_test.dart`, `test/features/trips/presentation/widgets/trip_list_nesting_test.dart`

**Interfaces:**
- Consumes: `effectiveParentId` (Task 2), `allTripsProvider` (for parent names outside the filtered list).
- Produces: `class TripListRow { final TripWithStats item; final bool isSideTrip; final int sideTripCount; final String? partOfName; }` and `List<TripListRow> nestTripRows(List<TripWithStats> sorted, Map<String, Trip> allTripsById)`: top-level rows in the given order; each followed by its side trips present in `sorted`, by start date ascending, `isSideTrip: true`; a side trip whose parent is absent from `sorted` but present in `allTripsById` becomes a top-level row with `partOfName`; one whose parent is absent from both is plain top-level. `sideTripCount` counts the parent's valid side trips in `allTripsById`.
- Produces: tile params `bool isSideTrip = false` (16 px extra leading indent plus a subdirectory-arrow icon), `int sideTripCount = 0` (renders `trips_list_sideTripCount`), `String? partOfName` (renders `trips_partOf`).

- [ ] **Step 1: Write failing tests**: helper cases (nested order, orphan with `partOfName` for Review Focus 4, unknown parent, invalid chain stays flat); widget test pumping the list with P and S showing S indented under P and P's "1 side trip"; upcoming/past split decided by the top-level row.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement**; split upcoming and past over top-level rows only, carrying children with their parent; keyboard navigation keys follow row order.
- [ ] **Step 4: Run** `test/features/trips/presentation`; expect PASS.
- [ ] **Step 5: Commit** `feat(trips): nest side trips under the larger trip in the trip list`.

### Task 8: Trip page, form and delete dialog

**Files:**
- Modify: `lib/features/trips/presentation/widgets/trip_dives_tab.dart` (tag dives whose `tripId` is a side trip)
- Create: `lib/features/trips/presentation/widgets/part_of_trip_link.dart` (shown in `trip_detail_page.dart`'s embedded header and at the top of `TripOverviewTab`)
- Create: `lib/features/trips/presentation/widgets/part_of_trip_field.dart` (form field)
- Modify: `lib/features/trips/presentation/pages/trip_edit_page.dart` (hold `_parentTripId`, load it, save it, render the field; hidden when `sideTripsProvider(tripId)` is non-empty)
- Modify: `lib/features/trips/presentation/pages/trip_detail_page.dart` (delete dialog lines)
- Test: `test/features/trips/presentation/widgets/trip_dives_tab_side_trip_test.dart`, `part_of_trip_field_test.dart`, `part_of_trip_link_test.dart`, the trip edit page test

**Interfaces:**
- Consumes: `sideTripsProvider`, `parentTripProvider` (Task 3), `canChooseAsParent` (Task 2).
- Produces: `PartOfTripLink({required String tripId})` (renders nothing without a parent; taps open `/trips/<parentId>`); `PartOfTripField({required String? tripId, required String? value, required ValueChanged<String?> onChanged})` (a picker sheet of visible trips filtered by `canChooseAsParent`, plus "None").

- [ ] **Step 1: Write failing tests**: Dives tab for P shows S's name as a tag on S's dives only, in one date-ordered list; `PartOfTripLink(S)` reads "Part of P"; the field omits self and side trips and saves the choice; the field is hidden on P; the delete dialog for P says its side trip becomes standalone, for S says its dives return to P.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement**; new strings go in `app_en.arb`.
- [ ] **Step 4: Run** `test/features/trips/presentation`; expect PASS.
- [ ] **Step 5: Commit** `feat(trips): show and set a trip's larger trip`.

### Task 9: Dive list group header and dive detail

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/trip_group_header.dart` (second line names the parent from `parentTripProvider(section.tripId)`)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (one line after `_buildTripRow`: `PartOfTripLink(tripId: dive.trip!.id)`)
- Test: `test/features/dive_log/presentation/widgets/trip_group_header_test.dart`, the dive detail page test covering the trip row

**Interfaces:**
- Consumes: `parentTripProvider`, `PartOfTripLink` (Tasks 3, 8).

- [ ] **Step 1: Write failing tests**: a group header for S shows "Part of P"; for P shows nothing extra; the header height still fits at text scale 2.0 (extend `tripGroupHeaderExtent` only if the test fails); dive detail of a dive on S shows the trip row and "Part of P".
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `test/features/dive_log/presentation`; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-log): name a side trip's larger trip on the dive list and detail`.

### Task 10: New trip from selection

**Files:**
- Create: `lib/features/trips/data/repositories/selection_trip_facts.dart`
- Create: `lib/features/trips/domain/services/trip_draft.dart`
- Create: `lib/features/trips/presentation/helpers/new_trip_from_selection.dart`
- Modify: `lib/features/trips/presentation/pages/trip_edit_page.dart` (`TripDraft? draft` constructor param seeds fields; on save with a draft, `assignDivesToTrip(draft.diveIds, savedId, oldTripIds: ...)` and skip the candidate scan)
- Modify: `lib/core/router/app_router.dart:1082` (`TripEditPage(draft: state.extra as TripDraft?)`)
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart` (`BulkAction(id: 'new_trip', icon: Icons.card_travel, label: l10n.diveLog_selection_tooltip_newTrip, onInvoke: _newTripFromSelection)` after `bulk_edit`)
- Test: `test/features/trips/domain/services/trip_draft_test.dart`, `test/features/trips/data/repositories/selection_trip_facts_test.dart`, `test/features/dive_log/presentation/widgets/dive_list_new_trip_test.dart`

**Interfaces:**
- Produces: `class SelectionDiveFacts { final String diveId; final DateTime diveDateTime; final String? tripId; final String? siteRegion; final String? siteCountry; final String? diveCenterName; }` and `Future<List<SelectionDiveFacts>> selectionTripFacts(AppDatabase db, List<String> diveIds)` (one query, ids chunked at 500, `stats-scope-exempt`).
- Produces: `class TripDraft { final Trip trip; final List<String> diveIds; }` and `TripDraft buildTripDraft(List<SelectionDiveFacts> facts, {required Map<String, Trip> tripsById, required String Function(String? location, DateTime start) nameFor})`:
  - start/end: `DateTime(w.year, w.month, w.day)` of the earliest/latest `diveDateTime.toUtc()`.
  - location: the shared non-empty region (with the shared country appended as "Region, Country" when that is shared too), else the shared country, else null; dives without a site are ignored.
  - resortName: the shared dive center name, else null; `tripType` stays `TripType.shore`.
  - parentTripId: when every fact has the same non-null `tripId` T: `effectiveParentId(T) ?? T`; else null.
  - name: `nameFor(location, start)`.
- Produces: `Future<void> newTripFromSelection(BuildContext context, WidgetRef ref, List<String> diveIds)`: builds the draft (nameFor uses `trips_fromSelection_name` / `trips_fromSelection_nameNoLocation` with `UnitFormatter.formatMonthYear`), `context.push<String>('/trips/new', extra: draft)`, then on a returned id `context.push('/trips/<id>')`.

- [ ] **Step 1: Write failing tests**: `buildTripDraft` cases: dates from a 23:30 Mar 31 dive end on Mar 31 (Review Focus 1); shared region and country; mixed regions sharing a country; no sites gives the no-location name; shared center fills resortName; all on side trip S prefill P; all on P prefill P; mixed trips prefill null. Facts query returns region, country and center for 3 dives. Widget test: selecting 2 dives and invoking `new_trip` pushes `/trips/new` with a draft holding both ids; saving moves exactly those dives and shows no assignment sheet.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement**; the draft seeds `_nameController`, `_locationController`, `_resortController`, `_startDate`, `_endDate`, `_parentTripId` in `initState` when `draft != null`.
- [ ] **Step 4: Run** the new tests plus `test/features/trips test/features/dive_log/presentation`; expect PASS.
- [ ] **Step 5: Commit** `feat(trips): make a new trip from selected dives`.

### Task 11: Translations

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and the ten other `app_XX.arb` files (feature-grouped: insert beside a neighbouring key of the same group), then the generated `app_localizations*.dart`

New keys (English values):

| Key | English |
| --- | --- |
| `diveLog_selection_tooltip_newTrip` | New Trip from Selection |
| `trips_fromSelection_name` | {location}, {monthYear} |
| `trips_fromSelection_nameNoLocation` | Trip, {monthYear} |
| `trips_edit_field_partOf` | Part of |
| `trips_edit_partOf_none` | None (a trip of its own) |
| `trips_edit_partOf_helper` | Makes this a side trip within a larger trip |
| `trips_partOf` | Part of {name} |
| `trips_list_sideTripCount` | {count, plural, one{1 side trip} other{{count} side trips}} |
| `trips_delete_sideTripsStandalone` | {count, plural, one{Its side trip becomes a trip of its own.} other{Its {count} side trips become trips of their own.}} |
| `trips_delete_divesReturnToParent` | Its dives go back to {name}. |
| `query_trips_partOf` | Part of |

- [ ] **Step 1:** Translate every key into ar, de, es, fr, he, hu, it, nl, pt, zh.
- [ ] **Step 2:** `flutter gen-l10n`; check `grep -A1 "trips_partOf" lib/l10n/arb/app_localizations_de.dart` shows German, and `git diff --numstat lib/l10n/arb/` is even across locales.
- [ ] **Step 3:** `flutter test test/l10n` (plural and completeness guards); expect PASS.
- [ ] **Step 4: Commit** `i18n(trips): translate side trip and new trip from selection strings`.

### Task 12: Whole-branch verification

- [ ] **Step 1:** `dart format .` and `flutter analyze`; expect no issues.
- [ ] **Step 2:** `flutter test test/architecture/ test/shared/ test/core/database test/core/query test/features/trips test/features/dive_log test/features/divers test/features/insights test/features/media test/features/query test/features/settings/presentation/conflicts test/l10n`, logged to the scratchpad; expect 0 failures.
- [ ] **Step 3:** Recheck the schema claim (open PRs and sibling worktrees) and renumber 323 if taken.
