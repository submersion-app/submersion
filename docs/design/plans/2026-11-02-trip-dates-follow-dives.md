# Trip Dates Follow Their Dives Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A trip stretches outward to cover its dives when one lands outside it or is redated outside it, and Create new trip in the dive editor and bulk edit opens prefilled from the dives.

**Architecture:** One pure function decides the covering range. One data helper applies it across dives, stretching larger trips and staging sync. Each deliberate write path calls the helper; imports and repairs do not.

**Tech Stack:** Flutter, Riverpod, Drift, ARB localization.

**Spec:** `docs/design/specs/2026-11-02-trip-dates-follow-dives-design.md`

## Global Constraints

- Stretch outward only; never move a bound inward.
- Compare calendar days. A dive's day comes from `diveDateTime.toUtc()` components; a trip's date is local midnight of a day (`tripDay`).
- Write bounds as `DateTime(y, m, d).millisecondsSinceEpoch`, never by adding hours.
- Write `trips` through Drift `update`, so `watchTripsChanges()` ticks and every trip provider refreshes.
- Do not call the stretch from `createDive`, `updateDive` or `bulkUpdateFields`.
- Paths through `p.join`, no literal `/tmp`, no em-dashes, no emojis.

## Review Focus

1. A save that changes neither trip nor date on a dive outside its trip: no stretch, no message. Task 5 tests it.
2. A dive at 23:30 wall clock on the last day, in a zone behind UTC: it stays on that day and does not stretch. Task 1 tests it.
3. Undo after the diver edited one bound: that bound stays, the other restores. Task 2 tests it.
4. A side trip with a broken parent link (missing, or itself a side trip): the side trip stretches, nothing else. Task 2 tests it.
5. Bulk edit that clears the trip (`Value(null)`), or sets it to a trip with all dives inside: no stretch, no second message line. Task 3 tests it.

---

### Task 1: The pure range

**Files:**
- Create: `lib/features/trips/domain/services/trip_date_stretch.dart`
- Test: `test/features/trips/domain/services/trip_date_stretch_test.dart`

**Interfaces:**
- Produces:
  - `DateTime diveWallClockDay(DateTime diveDateTime)`: local midnight of the dive's wall-clock day.
  - `TripDateRange? coveringRange({required DateTime start, required DateTime end, required Iterable<DateTime> diveDateTimes})`: null when already covered. `typedef TripDateRange = ({DateTime start, DateTime end});`
  - `class TripDateStretch` (const, Equatable): `tripId`, `tripName`, `priorStart`, `priorEnd`, `start`, `end` (all `DateTime`), `isLargerTrip` (bool, default false).
  - `TripDateStretch? ownStretch(Iterable<TripDateStretch> stretches)`: the first with `!isLargerTrip`.
  - `bool diveSaveTouchesTrip({required String? tripId, required String? previousTripId, required DateTime date, required DateTime? previousDate})`: false when `tripId` is null; true when the trip differs, `previousDate` is null, or the wall-clock day differs.

- [ ] **Step 1: Write failing tests**

Names and expectations (trip 2026-03-05 to 2026-03-10 unless stated):
- `already covered returns null`: dive 2026-03-07.
- `a dive on the first and last day returns null`.
- `an earlier dive moves only the start`: `DateTime.utc(2026, 3, 1, 9)` gives start `DateTime(2026, 3, 1)`, end `DateTime(2026, 3, 10)`.
- `a later dive moves only the end`.
- `dives on both sides move both`.
- `no dives returns null`.
- `a late dive stays on its wall-clock day`: `DateTime.utc(2026, 3, 10, 23, 30)` returns null.
- `an early dive stays on its wall-clock day`: `DateTime.utc(2026, 3, 5, 0, 30)` returns null.
- `a day across daylight saving is a calendar day`: trip 2026-03-29 to 2026-03-30, dive `DateTime.utc(2026, 4, 5, 8)`, end equals `DateTime(2026, 4, 5)`.
- `an end stored at noon is not moved inward`: end `DateTime(2026, 3, 10, 12)`, dive on 2026-03-10 returns null.
- `ownStretch skips a larger trip`.
- `diveSaveTouchesTrip`: new dive true; no trip false; same trip and day false; same trip, later time same day false; new trip true; new day true.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/trips/domain/services/trip_date_stretch_test.dart`
Expected: FAIL, the file does not exist.

- [ ] **Step 3: Implement in `trip_date_stretch.dart`, reusing `tripDay` from `trip_dive_days.dart`**

- [ ] **Step 4: Run to verify it passes**

Run the same command. Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/trips/domain/services/trip_date_stretch.dart test/features/trips/domain/services/trip_date_stretch_test.dart
git commit -m "feat(trips): work out the dates that cover a trip's dives"
```

### Task 2: The data helper and its undo

**Files:**
- Create: `lib/features/trips/data/repositories/trip_date_stretch.dart`
- Test: `test/features/trips/data/repositories/trip_date_stretch_test.dart`

**Interfaces:**
- Consumes: Task 1, `tripFromRow`, `effectiveParentId`.
- Produces:
  - `Future<List<TripDateStretch>> stretchTripsToCoverDives(AppDatabase db, SyncRepository sync, Iterable<String> diveIds, {required int now})`
  - `Future<void> restoreStretchedTripDates(AppDatabase db, SyncRepository sync, Iterable<TripDateStretch> stretches, {required int now})`

Neither opens a transaction nor notifies, like `clearForeignTripCylinderLinks`.

- [ ] **Step 1: Write failing tests** against `AppDatabase` from `helpers/test_database.dart`, inserting dives as `trip_cylinder_side_trip_test.dart` does

- `a dive with no trip changes nothing`
- `a covered dive writes nothing and stages nothing`: `updated_at` unchanged, no pending row for the trip.
- `a dive outside stretches the trip, bumps updated_at and stages it`: `getPendingChanges` holds entity `trips` for the id.
- `dives on two trips stretch both, each to its own dives`.
- `more dives than one chunk`: 501 ids, one outside, stretch still happens.
- `a side trip stretch stretches its larger trip`: result holds both, the parent with `isLargerTrip: true`.
- `a dive inside a side trip leaves the larger trip alone`.
- `a side trip inside its larger trip's dates leaves the larger trip alone` after a stretch that stays inside it.
- `a broken parent link is ignored`: parent missing (foreign keys off is not needed: use a parent that is itself a side trip).
- `a larger trip takes both its own dives and its side trip's stretch`: one call with both, a single result for the parent.
- `restore puts both bounds back and stages the trip`.
- `restore leaves a bound the diver edited since`: edit the end, restore, the start returns and the end stays.
- `restore leaves a later stretch`: stretch the end further, restore, the end stays.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/trips/data/repositories/trip_date_stretch_test.dart`
Expected: FAIL, the file does not exist.

- [ ] **Step 3: Implement**

Read dive id, trip id and date with `db.select(db.dives)` in chunks of 500, where `tripId` is not null. Group wall-clock dates by trip. Load those trips, then any parents they name. Add a stretched trip's dates to its valid parent's list, then compute the parent once, so one trip yields one result. Write with `db.update(db.trips)` and `TripsCompanion`. `isLargerTrip` is true when the parent had no dives of its own in this call. Undo compares each stored bound's milliseconds to `start`/`end` and writes only those that match.

- [ ] **Step 4: Run to verify it passes**

Run the same command. Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/trips/data/repositories/trip_date_stretch.dart test/features/trips/data/repositories/trip_date_stretch_test.dart
git commit -m "feat(trips): stretch trips to cover their dives"
```

### Task 3: Bulk edit, rules and the assign paths

**Files:**
- Modify: `lib/features/dive_log/domain/entities/bulk_edit_snapshot.dart`, `lib/features/dive_log/data/services/bulk_dive_edit_service.dart`, `lib/features/rules/data/services/dive_rule_applier.dart`, `lib/features/trips/data/repositories/trip_repository.dart`, `lib/features/dive_log/data/repositories/dive_repository_impl.dart`
- Test: `test/features/dive_log/data/services/bulk_dive_edit_trip_stretch_test.dart`, `test/features/trips/data/repositories/trip_repository_stretch_test.dart`, a test next to the existing rule applier tests

**Interfaces:**
- Consumes: Task 2.
- Produces:
  - `BulkEditSnapshot.tripDateStretches`: `List<TripDateStretch>`, default `const []`.
  - `TripRepository.stretchToCoverDives(List<String> diveIds)`: `Future<List<TripDateStretch>>`, in a transaction, notifying sync when anything changed. Task 5 uses it.

- [ ] **Step 1: Write failing tests**

- `apply with a trip stretches it and reports it in the snapshot`
- `apply clearing the trip stretches nothing`
- `apply to a trip that covers the dives reports nothing`
- `apply with no trip field reports nothing`
- `undo restores the trip's dates`
- `undo leaves a bound edited since`
- rule: `a rule setting a trip stretches it`; `a rule clearing a trip stretches nothing`
- repository: `assignDivesToTrip stretches`, `assignDiveToTrip stretches`, `bulkUpdateTrip stretches`, `bulkUpdateTrip to null stretches nothing`, `stretchToCoverDives returns what it changed`

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/dive_log/data/services/bulk_dive_edit_trip_stretch_test.dart test/features/trips/data/repositories/trip_repository_stretch_test.dart`
Expected: FAIL on the missing field and method.

- [ ] **Step 3: Implement**

In `_applyInner`, after `bulkUpdateFields` inside the transaction, when `req.scalars.tripId.present && req.scalars.tripId.value != null`. In `_undoInner`, after the dive rows, inside its transaction. In `DiveRuleApplier._setField`, after the chunks, over `changed`, when the companion sets a non-null trip; it needs a `SyncRepository` field. In the assign methods and `_bulkUpdateTripInner`, inside their transactions, after the dive writes.

- [ ] **Step 4: Run to verify they pass, along with the existing suites**

Run: `flutter test test/features/dive_log/data/services test/features/trips/data/repositories test/features/rules`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features test/features
git commit -m "feat(trips): stretch trips from bulk edit, rules and assignment"
```

### Task 4: The message in bulk edit

**Files:**
- Modify: all 11 `lib/l10n/arb/app_*.arb` and regenerated `app_localizations*.dart`, `lib/features/dive_log/presentation/pages/dive_edit_page.dart`
- Create: `lib/features/trips/presentation/helpers/trip_date_stretch_message.dart`
- Test: `test/features/dive_log/presentation/pages/bulk_edit_snackbar_test.dart`

**Interfaces:**
- Produces: `String? tripDateStretchMessage(AppLocalizations l10n, UnitFormatter units, Iterable<TripDateStretch> stretches)`: null when `ownStretch` is null. New keys `trips_dateStretch_message` (`{trip} now runs {dates}`, both String) and `trips_dateStretch_failed` (`Dive saved, but the trip's dates couldn't be updated`).

- [ ] **Step 1: Write failing tests** in `bulk_edit_snackbar_test.dart`

- `a stretched trip adds a line to the applied message and keeps Undo`
- `no stretch keeps the single line`

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/dive_log/presentation/pages/bulk_edit_snackbar_test.dart`
Expected: FAIL on the missing line.

- [ ] **Step 3: Add the keys to every ARB with real translations, run `flutter gen-l10n`, add the helper and use it in `_saveBulk`**

Join with a newline in the SnackBar's `Text`.

- [ ] **Step 4: Run to verify they pass, with the localization guards**

Run: `flutter test test/features/dive_log/presentation/pages/bulk_edit_snackbar_test.dart test/l10n`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n lib/features/trips/presentation/helpers/trip_date_stretch_message.dart lib/features/dive_log/presentation/pages/dive_edit_page.dart test/features/dive_log/presentation/pages/bulk_edit_snackbar_test.dart
git commit -m "feat(dive-log): say when a bulk edit stretches a trip"
```

### Task 5: The dive editor stretches on save

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart`
- Test: `test/features/dive_log/presentation/pages/dive_edit_trip_stretch_test.dart`

**Interfaces:**
- Consumes: `diveSaveTouchesTrip`, `TripRepository.stretchToCoverDives`, `tripDateStretchMessage`.

- [ ] **Step 1: Write failing tests**

- `saving a new dive outside its trip stretches the trip and says so`
- `moving a dive onto a trip stretches it`
- `redating a dive on a trip stretches it`
- `saving an out-of-range dive unchanged leaves the trip and shows no message`

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_trip_stretch_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement in `_saveDive`**

Capture `ScaffoldMessenger.of(context)` before the awaits. After the quality-scan block and `rulesAfterCreate`, when `diveSaveTouchesTrip` holds for `_selectedTrip?.id`, `_existingDive?.tripId ?? _existingDive?.trip?.id`, `entryDateTime` and `_existingDive?.dateTime`, call `stretchToCoverDives([savedDiveId])` in a try/catch that logs and shows `trips_dateStretch_failed`, as the route links block does. Show the message before navigating.

- [ ] **Step 4: Run to verify they pass**

Run the same command, then `flutter test test/features/dive_log/presentation/pages/dive_edit_page_test.dart`. Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/pages/dive_edit_page.dart test/features/dive_log/presentation/pages/dive_edit_trip_stretch_test.dart
git commit -m "feat(dive-log): stretch a trip when saving a dive outside it"
```

### Task 6: Prefilled Create new trip

**Files:**
- Modify: `lib/features/trips/presentation/helpers/new_trip_from_selection.dart`, `lib/features/dive_log/presentation/pages/dive_edit_page.dart`
- Test: `test/features/dive_log/presentation/pages/dive_edit_new_trip_prefill_test.dart`

**Interfaces:**
- Produces: `Future<String?> newTripForDiveEdit(BuildContext context, WidgetRef ref, List<SelectionDiveFacts> facts)`: pushes `/trips/new` with the draft's `diveIds` empty and returns the new id, opening no trip page. `newTripFromSelection` keeps its signature and shares the draft building.

- [ ] **Step 1: Write failing tests**

- `the dive editor's Create new trip opens at the dive's date`: the form shows the dive's day as start and end, not today.
- `it carries the site's location and the dive center's name`.
- `the bulk form's Create new trip spans the selected dives`.
- `backing out of the form moves no dive and leaves the trip unset`.
- `saving the form selects the new trip without moving the dive until the edit saves`.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_new_trip_prefill_test.dart`
Expected: FAIL, the form opens at today.

- [ ] **Step 3: Implement**

In `_showTripPicker`, build facts from `loadSelectionTripFacts(widget.bulkDiveIds!)` in bulk, else one `SelectionDiveFacts` from the form: `diveId: ''`, `diveDateTime` as `DateTime.utc` of `_entryDate`, `tripId: _selectedTrip?.id`, the site's region and country, the center's name. Replace `context.push<String>('/trips/new')` with `newTripForDiveEdit`.

- [ ] **Step 4: Run to verify they pass, with the selection tests**

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_new_trip_prefill_test.dart test/features/dive_log/presentation/widgets/dive_list_new_trip_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/trips/presentation/helpers/new_trip_from_selection.dart lib/features/dive_log/presentation/pages/dive_edit_page.dart test/features/dive_log/presentation/pages/dive_edit_new_trip_prefill_test.dart
git commit -m "feat(dive-log): prefill Create new trip from the dives being edited"
```

### Task 7: Final checks

- [ ] **Step 1: Format and analyze the whole repo**

Run: `dart format . && flutter analyze`
Expected: no issues.

- [ ] **Step 2: Run the guards and feature suites**

Run: `flutter test test/architecture test/shared test/l10n test/features/trips test/features/rules test/features/dive_log/data`
Expected: all pass. `dive_edit_page.dart` stays under its size guard, or the new block moves to a part file.

- [ ] **Step 3: Commit anything format changed**

```bash
git add -u
git commit -m "style: format"
```
