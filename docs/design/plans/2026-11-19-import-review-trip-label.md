# Import Review Trip Label Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The import review shows, on each dive that will be saved as new, the trip it will join, and the import summary counts the saved dives per trip.

**Architecture:** The file importer's "place by date" condition moves into one pure function under `trips/domain/services/`, which the importer and a new pure review service both call. File adapters stamp each dive and trip row with the trip reference and dates the rule needs; a wizard provider runs the review service against the target diver's trips and the live review state. The summary reads the saved dives' trips.

**Tech Stack:** Flutter, Riverpod, Drift (read only), ARB l10n.

**Spec:** `docs/design/specs/2026-11-19-import-review-trip-label-design.md`

## Global Constraints

- Which trip a dive is saved in does not change; `uddf_entity_importer_existing_trip_test.dart` stays green unchanged.
- Read-only label: no picker, no override passed to any save route.
- Only rows saved as new dives get a label: selected, and either not a duplicate with no action, or marked import as new.
- Every new string goes to all 11 ARBs (ar, de, en, es, fr, he, hu, it, nl, pt, zh), inserted beside a key of the same group; plurals use `{count}`, never a literal digit.
- Trip icon: `Icons.flight_outlined` (the Trips nav icon).
- No em-dashes anywhere; `dart format .` before each commit; run only the test files named here.

## Review Focus

- A file trip the diver unticks: its dives show the trip they get by date, not the unticked one (Task 3 test `untickedFileTripFallsBackToDate`).
- A duplicate row that is pending, skipped or merged shows no trip (Task 3 test `onlyNewDivesGetANameForEachAction`).
- A multi-diver import into a profile it creates shows no trip for those rows (Task 4 test `newProfileRowsShowNoTrip`).
- An undated dive shows no trip, as it is never placed (Task 1 test `undatedDiveIsNeverPlaced`).
- A download filed under another diver reads that diver's trips, not the active diver's (Task 4 test `downloadForOtherDiverReadsTheirTrips`).

---

### Task 1: Shared placement rule

**Files:**
- Create: `lib/features/trips/domain/services/imported_dive_trip.dart`
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart:3051-3058`
- Test: `test/features/trips/domain/services/imported_dive_trip_test.dart`

**Interfaces:**
- Produces:
  - `bool placesImportedDiveByDate({required bool hasOwnTrip, required bool hasTripRef, required bool sourceHasTrips, required bool isDated})`: `!hasOwnTrip && isDated && (hasTripRef || !sourceHasTrips)`.
  - `Trip? tripForImportedDive({Trip? ownTrip, bool hasTripRef = false, bool sourceHasTrips = false, required DateTime? diveDateTime, required Iterable<Trip> trips})`: `ownTrip`, else `tripForDiveDate` when the predicate holds, else null.

- [ ] **Step 1: Write the failing tests**: `ownTripWins` (own trip returned even when another covers the day), `noFileTripsPlacesByDate`, `fileWithTripsLeavesUnreferencedDiveOut` (sourceHasTrips true, hasTripRef false: null), `unimportedOwnTripPlacesByDate` (hasTripRef true, ownTrip null: the covering trip), `undatedDiveIsNeverPlaced`, and one predicate truth-table test over the four flags.
- [ ] **Step 2: Run** `flutter test test/features/trips/domain/services/imported_dive_trip_test.dart`; expected FAIL (file missing).
- [ ] **Step 3: Implement** both functions with doc comments citing #2618 and #3022.
- [ ] **Step 4: Replace the importer's inline condition** with `placesImportedDiveByDate(hasOwnTrip: linkedTripId != null, hasTripRef: tripRef != null, sourceHasTrips: fileHasTrips, isDated: sourceDateTime != null)`; keep the lazy `diverTrips ??=` load and the existing comment's reasoning.
- [ ] **Step 5: Run** the new test plus `test/features/dive_import/data/services/uddf_entity_importer_existing_trip_test.dart`; expected PASS.
- [ ] **Step 6: Commit** `refactor(trips): share the rule that places an imported dive in a trip`.

### Task 2: Rows carry trip references

**Files:**
- Modify: `lib/features/import_wizard/domain/models/import_bundle.dart` (`EntityItem`)
- Modify: `lib/features/import_wizard/data/adapters/universal_adapter.dart` (`_diveToEntityItem`, `_tripToEntityItem`, the group building near line 505)
- Test: `test/features/import_wizard/data/adapters/universal_adapter_trip_ref_test.dart`, plus a `copyWith` case in the existing `import_bundle` model test if one exists (else in the new file)

**Interfaces:**
- Produces on `EntityItem`:
  - `final String? tripRef;` On a dive, its source `tripRef`; on a trip, its own `uddfId`.
  - `final bool sourceHasTrips;` (default false) On a dive, whether its own file had trips: `data[PayloadMerger.sourceHasTripsKey] as bool?`, else whether the payload has any trips.
  - `final ({DateTime start, DateTime end})? tripDates;` On a trip, its `startDate`/`endDate`; null when either is missing.
  - `copyWith({ImportTarget? target})` keeps all three.

- [ ] **Step 1: Write the failing tests**: a payload with two trips and three dives (one per trip, one with none) gives dive rows `tripRef` equal to the trip rows' `tripRef`, `sourceHasTrips` true, and trip rows `tripDates`; a merged payload whose dive carries `_sourceHasTrips: false` gives false; `copyWith(target:)` keeps the fields.
- [ ] **Step 2: Run** the test file; expected FAIL (no such field).
- [ ] **Step 3: Implement** the fields and stamp them in the two builders; pass `payloadHasTrips` into `_diveToEntityItem` from the caller.
- [ ] **Step 4: Run** the test file; expected PASS.
- [ ] **Step 5: Commit** `feat(import-wizard): carry each row's trip reference into the review`.

### Task 3: Review trip names (pure)

**Files:**
- Create: `lib/features/import_wizard/domain/services/review_trip_names.dart`
- Test: `test/features/import_wizard/domain/services/review_trip_names_test.dart`

**Interfaces:**
- Consumes: `tripForImportedDive` (Task 1), `EntityItem.tripRef/sourceHasTrips/tripDates` (Task 2).
- Produces: `Map<int, String> reviewTripNames({required EntityGroup dives, EntityGroup? trips, required Set<int> diveSelections, required Map<int, DuplicateAction> diveActions, Set<int> tripSelections = const {}, Map<int, DuplicateAction> tripActions = const {}, required List<Trip> Function(EntityItem dive) existingTripsFor, required DateTime now})`, keyed by dive row index.

Rules the body follows (mirroring `UniversalAdapter._resolveSelections` and `preResolvedIdsFor(..., linkOnSkip: false)`):
- A file trip row is imported when selected and its action is not skip, consolidate or replaceSource; it becomes a `Trip` named by the row title, dated by `tripDates` (or `now` for both, as the importer does).
- A file trip row marked consolidate links to `trips.entityMatches[j].existingId`, looked up in `existingTripsFor(dive)`.
- A dive's `ownTrip` is the imported or linked trip whose row `tripRef` equals the dive's; date candidates are `existingTripsFor(dive)` plus every imported file trip.

- [ ] **Step 1: Write the failing tests**: `dateOnlySourceUsesExistingTrips`, `importedFileTripNamesItsDives`, `consolidatedFileTripNamesTheExistingTrip`, `untickedFileTripFallsBackToDate`, `fileWithTripsLeavesUnreferencedDiveOut`, `onlyNewDivesGetANameForEachAction` (non-duplicate unselected, duplicate pending, skip, consolidate, replaceSource, fillPlanned: no entry; importAsNew: entry), `datedByUtcComponents` (a dive at 23:30 UTC on a trip's last day keeps it).
- [ ] **Step 2: Run** the test file; expected FAIL.
- [ ] **Step 3: Implement** `reviewTripNames`.
- [ ] **Step 4: Run** the test file; expected PASS.
- [ ] **Step 5: Commit** `feat(import-wizard): work out each reviewed dive's trip`.

### Task 4: Review provider and row line

**Files:**
- Create: `lib/features/import_wizard/presentation/providers/import_trip_providers.dart`
- Modify: `lib/features/import_wizard/presentation/widgets/entity_review_list.dart` (`EntityReviewList`, `_NonDuplicateRow`, `_EntityDuplicateCard`)
- Modify: `lib/features/import_wizard/presentation/widgets/review_step.dart` (`_EntityTab`)
- Modify: all 11 `lib/l10n/arb/app_*.arb`, then `flutter gen-l10n`
- Test: `test/features/import_wizard/presentation/providers/import_trip_providers_test.dart`, `test/features/import_wizard/presentation/widgets/entity_review_list_trip_test.dart`

**Interfaces:**
- Consumes: `reviewTripNames` (Task 3).
- Produces:
  - `importOwnerTripsProvider`: `FutureProvider.autoDispose.family<List<Trip>, String?>`; null resolves to `validatedCurrentDiverIdProvider`, then `tripRepositoryProvider.getAllTrips(diverId:)`.
  - `importReviewTripNamesProvider`: `Provider.autoDispose<Map<int, String>>` watching `importWizardNotifierProvider`; owner per dive row is `item.target` (`isNew`: empty list; else the id after `diver:`), else `bundle.targetChoice?.chosenDiverId ?? notifier.diverId`. A still-loading owner gives no names for its rows.
  - `EntityReviewList.tripNameForIndex`: `String? Function(int index)?`.
  - l10n `universalImport_review_tripLabel` ("Trip: {trip}", String placeholder), the row's semantics label.

- [ ] **Step 1: Write the failing provider tests** (override `importOwnerTripsProvider`): `activeDiverTripsName`, `downloadForOtherDiverReadsTheirTrips` (targetChoice chosenDiverId), `newProfileRowsShowNoTrip`, `namesFollowSelectionChanges` (toggle a file trip via the notifier, the name changes).
- [ ] **Step 2: Write the failing widget tests**: a non-duplicate row with a name shows the icon and name and the semantics label; a duplicate card marked import as new shows it; a row without a name shows nothing extra.
- [ ] **Step 3: Run** both files; expected FAIL.
- [ ] **Step 4: Implement** the providers, the row line (one `Row` of `Icon(Icons.flight_outlined, size: 14)` and the name in the subtitle style, under the subtitle), the `_EntityTab` wiring for the dives tab only, and the l10n key in every ARB.
- [ ] **Step 5: Run** both files; expected PASS. Grep that Suunto, Garmin and divelogs saves reach `DiveImportService._importNewDive` or the universal importer, so every labelled source places by date; if one does not, ask before labelling it.
- [ ] **Step 6: Commit** `feat(import-wizard): show each new dive's trip on its review row`.

### Task 5: Summary trip counts

**Files:**
- Create: `lib/features/import_wizard/presentation/widgets/import_trips_tile.dart`
- Modify: `lib/features/import_wizard/presentation/providers/import_trip_providers.dart`
- Modify: `lib/features/import_wizard/presentation/widgets/import_summary_step.dart` (after the cylinders tile near line 328)
- Modify: all 11 ARBs, `docs/guide/import-export.md` (the trip placement paragraph from #2743)
- Test: `test/features/import_wizard/presentation/widgets/import_trips_tile_test.dart`

**Interfaces:**
- Produces:
  - `importedDiveTripCountsProvider`: `FutureProvider.autoDispose.family<List<({String name, int count})>, ImportedDiveIds>`; reads `getDivesByIdsWithoutSamples`, groups by `tripId`, names via `tripRepositoryProvider.getTripById`, sorted by count descending then name.
  - `ImportTripsTile({required List<String> importedDiveIds})`, key `import_summary_trips`.
  - l10n `universalImport_summary_tripsTitle` ("Trips"), `universalImport_summary_tripCount` (`{count, plural, one{{trip}: {count} dive} other{{trip}: {count} dives}}`, placeholders `trip` String, `count` int).

- [ ] **Step 1: Write the failing tests**: two trips with 12 and 3 dives list in that order with the plural text; no dive in a trip shows nothing; a dive with no trip is not counted.
- [ ] **Step 2: Run** the file; expected FAIL.
- [ ] **Step 3: Implement** the provider, the tile (shown for every source), the strings and one guide sentence saying the review shows each dive's trip and the summary counts them.
- [ ] **Step 4: Run** the file; expected PASS. Then `flutter analyze` (whole repo) and `dart format .`.
- [ ] **Step 5: Commit** `feat(import-wizard): count the imported dives in each trip on the summary`.
