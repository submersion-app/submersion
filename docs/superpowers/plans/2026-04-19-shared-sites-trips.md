# Shared Sites and Trips Across Dive Profiles — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users mark individual trips and dive sites as visible to all local dive profiles, with a global Settings default and a bulk-share action, solving the "re-entering the same data for every family member" pain.

**Architecture:** Add a per-record `is_shared` boolean column to `trips` and `dive_sites`. Route all diver-scoped list/search queries through a new centralized `VisibilityFilter` helper that encodes the predicate `diver_id = ? OR is_shared = 1`. A new `AppSettingsRepository` stores the household-level "share new records by default" toggle in the global `settings` key-value table. Edit pages, list tiles, and a new Settings section consume the flag.

**Tech Stack:** Flutter 3.x, Drift ORM, Riverpod, Material 3, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-04-19-shared-sites-trips-design.md`

---

## File Structure

### Files to create

| Path | Responsibility |
|---|---|
| `lib/core/data/visibility/visibility_filter.dart` | Encodes the owner-or-shared visibility predicate. Two entry points: Drift query builder and raw SQL fragment. |
| `lib/features/settings/data/repositories/app_settings_repository.dart` | CRUD for global app settings stored in the `settings` key-value table (currently unused except for `active_diver_id`). First consumer: `share_new_records_by_default`. |
| `test/core/data/visibility/visibility_filter_test.dart` | Unit tests for the helper. |
| `test/features/settings/data/repositories/app_settings_repository_test.dart` | Unit tests for the new repo. |

### Files to modify

| Path | Change |
|---|---|
| `lib/core/database/database.dart` | Add `isShared` columns to `Trips` and `DiveSites`, bump `currentSchemaVersion` 68 → 69, add `if (from < 69)` migration step. |
| `lib/features/trips/domain/entities/trip.dart` | Add `final bool isShared` to `Trip`, thread through constructor, `copyWith`, `props`. |
| `lib/features/dive_sites/domain/entities/dive_site.dart` | Same for `DiveSite`. |
| `lib/features/trips/data/repositories/trip_repository.dart` | (a) Read/write `isShared` in `_mapRowToTrip`, `createTrip`, `updateTrip`. (b) Visibility filter on `getAllTrips`, `searchTrips`, `findTripForDate`, `getAllTripsWithStats`. (c) New methods `setShared(String id, bool isShared)`, `shareAllForDiver(String diverId)`. |
| `lib/features/dive_sites/data/repositories/site_repository_impl.dart` | Mirror of trip repo changes (mappers, visibility filter on list/search, new `setShared`/`shareAllForDiver`). |
| `lib/l10n/arb/app_en.arb` | New English strings for the share toggle label, settings section, bulk-share buttons and confirmation. |
| `lib/features/trips/presentation/pages/trip_edit_page.dart` | Add `SwitchListTile` for sharing, default from `AppSettingsRepository`, hidden when only one diver. |
| `lib/features/dive_sites/presentation/pages/site_edit_page.dart` | Mirror of trip edit page change. |
| `lib/features/trips/presentation/widgets/trip_list_content.dart` | Render shared icon next to title when `trip.isShared && divers.length > 1`. |
| `lib/features/dive_sites/presentation/widgets/site_list_content.dart` | Mirror. |
| `lib/features/settings/presentation/pages/settings_page.dart` | New "Shared data" section with default toggle + two bulk-share tiles. Suppressed when only one diver. |
| `test/features/trips/data/repositories/trip_repository_test.dart` | Tests for persistence round-trip, visibility filtering, bulk share, single-row share. |
| `test/features/dive_sites/data/repositories/site_repository_test.dart` | Same shape of tests for sites. |
| `test/features/trips/presentation/pages/trip_edit_page_test.dart` | Widget test for the switch's default-from-settings behavior and persistence. |

---

## Task 1: Schema migration — add `isShared` columns

**Files:**
- Modify: `lib/core/database/database.dart`
- Modify: `lib/core/database/database.g.dart` (regenerated)

**Context:** `currentSchemaVersion` is 68 (verified at `lib/core/database/database.dart:1327`). Migration pattern is `if (from < N) { customStatement(ALTER TABLE ...) }` followed by `if (from < N) await reportProgress();` — visible around `lib/core/database/database.dart:3196-3212`.

- [ ] **Step 1: Write a migration test**

Create file `test/core/database/shared_column_migration_test.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  test('schemaVersion is 69 and both is_shared columns exist', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(db.schemaVersion, equals(69));

    final tripCols = await db
        .customSelect("PRAGMA table_info('trips')")
        .get();
    final tripNames = tripCols.map((r) => r.read<String>('name')).toSet();
    expect(tripNames, contains('is_shared'));

    final siteCols = await db
        .customSelect("PRAGMA table_info('dive_sites')")
        .get();
    final siteNames = siteCols.map((r) => r.read<String>('name')).toSet();
    expect(siteNames, contains('is_shared'));
  });

  test('is_shared defaults to false on insert without explicit value', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    const now = 1_700_000_000_000;
    await db.into(db.trips).insert(
      TripsCompanion.insert(
        id: 't1',
        name: 'Test Trip',
        startDate: now,
        endDate: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final row = await (db.select(db.trips)..where((t) => t.id.equals('t1')))
        .getSingle();
    expect(row.isShared, isFalse);

    await db.into(db.diveSites).insert(
      DiveSitesCompanion.insert(
        id: 's1',
        name: 'Test Site',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final siteRow = await (db.select(db.diveSites)
          ..where((t) => t.id.equals('s1')))
        .getSingle();
    expect(siteRow.isShared, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/database/shared_column_migration_test.dart`
Expected: FAIL — schemaVersion is 68, `is_shared` columns don't exist.

- [ ] **Step 3: Add `isShared` column to both tables**

Edit `lib/core/database/database.dart`. Inside `class Trips extends Table`, add after the existing `notes` column and before `createdAt`:

```dart
  BoolColumn get isShared => boolean().withDefault(const Constant(false))();
```

Inside `class DiveSites extends Table`, add after `altitude` (the last existing column) and before the `@override` closing:

```dart
  BoolColumn get isShared => boolean().withDefault(const Constant(false))();
```

- [ ] **Step 4: Bump `currentSchemaVersion`**

At `lib/core/database/database.dart:1327`, change:

```dart
static const int currentSchemaVersion = 68;
```

to:

```dart
static const int currentSchemaVersion = 69;
```

- [ ] **Step 5: Add the migration step**

At the end of the migration strategy block, after the `if (from < 68) await reportProgress();` line (around `database.dart:3212`) and before the closing of the `onUpgrade` callback, add:

```dart
        if (from < 69) {
          await customStatement(
            'ALTER TABLE trips ADD COLUMN is_shared INTEGER NOT NULL DEFAULT 0',
          );
          await customStatement(
            'ALTER TABLE dive_sites ADD COLUMN is_shared INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (from < 69) await reportProgress();
```

- [ ] **Step 6: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Success, `database.g.dart` updated with new columns.

- [ ] **Step 7: Run test to verify it passes**

Run: `flutter test test/core/database/shared_column_migration_test.dart`
Expected: PASS.

- [ ] **Step 8: Run full analyze + test to catch unintended breakage**

Run: `flutter analyze`
Expected: No new errors.

Run: `flutter test test/core/database/`
Expected: All database tests pass (the two new ones plus existing migration tests).

- [ ] **Step 9: Commit**

```bash
git add lib/core/database/database.dart \
  lib/core/database/database.g.dart \
  test/core/database/shared_column_migration_test.dart
git commit -m "feat(db): add is_shared column to trips and dive_sites (v69)"
```

---

## Task 2: Extend `Trip` domain entity with `isShared`

**Files:**
- Modify: `lib/features/trips/domain/entities/trip.dart`
- Modify: `test/features/trips/domain/entities/trip_test.dart`

**Context:** `Trip` is an `Equatable` value object with a `copyWith` constructor (`lib/features/trips/domain/entities/trip.dart:5-107`). The existing pattern uses sentinel values for nullable fields and standard `??` fallbacks for required fields.

- [ ] **Step 1: Write the failing test**

Append to `test/features/trips/domain/entities/trip_test.dart` inside its existing `main()` `group('Trip', () { ... })`:

```dart
  group('isShared', () {
    test('defaults to false', () {
      final trip = Trip(
        id: 't1',
        name: 'Test',
        startDate: DateTime(2024),
        endDate: DateTime(2024),
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      expect(trip.isShared, isFalse);
    });

    test('copyWith sets isShared', () {
      final trip = Trip(
        id: 't1',
        name: 'Test',
        startDate: DateTime(2024),
        endDate: DateTime(2024),
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      final shared = trip.copyWith(isShared: true);
      expect(shared.isShared, isTrue);
      expect(trip.isShared, isFalse);
    });

    test('props include isShared so equality distinguishes shared state', () {
      final base = Trip(
        id: 't1',
        name: 'Test',
        startDate: DateTime(2024),
        endDate: DateTime(2024),
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      expect(base == base.copyWith(isShared: true), isFalse);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/trips/domain/entities/trip_test.dart`
Expected: FAIL — `isShared` not defined on `Trip`.

- [ ] **Step 3: Add `isShared` to `Trip`**

Edit `lib/features/trips/domain/entities/trip.dart`. Inside the `Trip` class, add the field after `notes`:

```dart
  final bool isShared;
```

Update the constructor (`const Trip({...})`) to include:

```dart
    this.isShared = false,
```

(Insert this after `this.notes = ''` and before `required this.createdAt`.)

Update `copyWith` — add parameter `bool? isShared,` near the end of the parameter list (after `String? notes`) and the assignment `isShared: isShared ?? this.isShared,` inside the returned `Trip(...)`.

Update `props` — add `isShared,` to the list (after `notes`).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/trips/domain/entities/trip_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/trips/`
Expected: No errors. If `TripsCompanion`-using call sites complain about a missing `isShared` argument, that's expected — Task 4 will fix them. Note the failures in a comment but do not fix in this task.

- [ ] **Step 6: Commit**

```bash
git add lib/features/trips/domain/entities/trip.dart \
  test/features/trips/domain/entities/trip_test.dart
git commit -m "feat(trips): add isShared to Trip domain entity"
```

---

## Task 3: Extend `DiveSite` domain entity with `isShared`

**Files:**
- Modify: `lib/features/dive_sites/domain/entities/dive_site.dart`
- Modify: `test/features/dive_sites/domain/entities/dive_site_test.dart` (create if absent)

**Context:** `DiveSite` is an `Equatable` (`lib/features/dive_sites/domain/entities/dive_site.dart:33-163`). Unlike `Trip`, `DiveSite` does not carry `createdAt`/`updatedAt` in the domain entity (the repo manages those itself).

- [ ] **Step 1: Write the failing test**

Create (or append, if file exists) `test/features/dive_sites/domain/entities/dive_site_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  group('DiveSite.isShared', () {
    test('defaults to false', () {
      const site = DiveSite(id: 's1', name: 'Reef');
      expect(site.isShared, isFalse);
    });

    test('copyWith sets isShared', () {
      const site = DiveSite(id: 's1', name: 'Reef');
      final shared = site.copyWith(isShared: true);
      expect(shared.isShared, isTrue);
      expect(site.isShared, isFalse);
    });

    test('props include isShared', () {
      const site = DiveSite(id: 's1', name: 'Reef');
      expect(site == site.copyWith(isShared: true), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_sites/domain/entities/dive_site_test.dart`
Expected: FAIL — `isShared` not defined.

- [ ] **Step 3: Add `isShared` to `DiveSite`**

Edit `lib/features/dive_sites/domain/entities/dive_site.dart`:

Add field (after `conditions`):

```dart
  final bool isShared;
```

Add to constructor (after `this.conditions`):

```dart
    this.isShared = false,
```

Update `copyWith` — add parameter `bool? isShared,` near the end and `isShared: isShared ?? this.isShared,` in the returned `DiveSite(...)`.

Update `props` — add `isShared,` to the list.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_sites/domain/entities/dive_site_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/dive_sites/`
Expected: No errors from this change. (`DiveSitesCompanion` call sites in the repo will be fixed in Task 5.)

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_sites/domain/entities/dive_site.dart \
  test/features/dive_sites/domain/entities/dive_site_test.dart
git commit -m "feat(sites): add isShared to DiveSite domain entity"
```

---

## Task 4: TripRepository — persist `isShared` on create/update/read

**Files:**
- Modify: `lib/features/trips/data/repositories/trip_repository.dart`
- Modify: `test/features/trips/data/repositories/trip_repository_test.dart`

**Context:** The repository has five places that map rows to `Trip` or write `TripsCompanion` values. Every one of them needs to include `isShared`. They are at `trip_repository.dart:79-105` (searchTrips mapping), `108-150` (createTrip), `152-186` (updateTrip), `508-540` (getAllTripsWithStats mapping), `459-483` (findTripForDate mapping), and `543-558` (`_mapRowToTrip`).

- [ ] **Step 1: Write the failing test**

Append to `test/features/trips/data/repositories/trip_repository_test.dart` inside the `group('TripRepository', () { ... })`:

```dart
    group('isShared persistence', () {
      test('createTrip persists isShared when set on entity', () async {
        final trip = createTestTrip(name: 'Shared Trip').copyWith(
          isShared: true,
        );
        final created = await repository.createTrip(trip);

        final readBack = await repository.getTripById(created.id);
        expect(readBack, isNotNull);
        expect(readBack!.isShared, isTrue);
      });

      test('createTrip defaults isShared to false when not set', () async {
        final trip = createTestTrip(name: 'Default Trip');
        final created = await repository.createTrip(trip);

        final readBack = await repository.getTripById(created.id);
        expect(readBack!.isShared, isFalse);
      });

      test('updateTrip persists isShared changes', () async {
        final trip = createTestTrip(name: 'Toggle');
        final created = await repository.createTrip(trip);

        await repository.updateTrip(
          created.copyWith(isShared: true),
        );

        final readBack = await repository.getTripById(created.id);
        expect(readBack!.isShared, isTrue);
      });
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/trips/data/repositories/trip_repository_test.dart --name "isShared persistence"`
Expected: FAIL — `isShared` is not persisted; read-back returns `false` or compile error.

- [ ] **Step 3: Thread `isShared` through the repository**

Edit `lib/features/trips/data/repositories/trip_repository.dart`:

**In `createTrip` (around line 108-150)**, inside the `TripsCompanion(...)` insert, add before `createdAt: Value(now.millisecondsSinceEpoch),`:

```dart
              isShared: Value(trip.isShared),
```

**In `updateTrip` (around line 152-186)**, inside the `TripsCompanion(...)` write, add before `updatedAt: Value(now),`:

```dart
          isShared: Value(trip.isShared),
```

**In `_mapRowToTrip` (around line 543-558)**, in the `domain.Trip(...)` returned, add before `createdAt:`:

```dart
      isShared: row.isShared,
```

**In `searchTrips` mapping (around line 79-105)**, in the `domain.Trip(...)` inside `.map(...)`, add before `createdAt:`:

```dart
        isShared: (row.data['is_shared'] as int? ?? 0) != 0,
```

**In `findTripForDate` mapping (around line 459-483)**, same addition before `createdAt:`:

```dart
      isShared: (result.data['is_shared'] as int? ?? 0) != 0,
```

**In `getAllTripsWithStats` mapping (around line 508-540)**, same addition:

```dart
        isShared: (row.data['is_shared'] as int? ?? 0) != 0,
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/trips/data/repositories/trip_repository_test.dart --name "isShared persistence"`
Expected: PASS.

- [ ] **Step 5: Regression-check existing tests**

Run: `flutter test test/features/trips/data/repositories/trip_repository_test.dart`
Expected: All existing tests still pass.

- [ ] **Step 6: Analyze**

Run: `flutter analyze lib/features/trips/data/`
Expected: No errors.

- [ ] **Step 7: Commit**

```bash
git add lib/features/trips/data/repositories/trip_repository.dart \
  test/features/trips/data/repositories/trip_repository_test.dart
git commit -m "feat(trips): persist isShared in TripRepository"
```

---

## Task 5: SiteRepository — persist `isShared` on create/update/read

**Files:**
- Modify: `lib/features/dive_sites/data/repositories/site_repository_impl.dart`
- Modify: `test/features/dive_sites/data/repositories/site_repository_test.dart`

**Context:** `SiteRepository` (class `SiteRepository`, file `site_repository_impl.dart`) has mapping and write sites at `site_repository_impl.dart:580-602` (`_mapRowToSite`), `57-107` (`createSite`), `109-153` (`updateSite`), and `604-626` (`_updateSiteRow`, used by merge/undo). Every one needs to pass through `isShared`.

- [ ] **Step 1: Write the failing test**

Open `test/features/dive_sites/data/repositories/site_repository_test.dart`. Inside its main `group`, append a new group (use the existing `createTestSite` helper if present, otherwise adapt):

```dart
    group('isShared persistence', () {
      test('createSite persists isShared=true', () async {
        const site = DiveSite(
          id: '',
          name: 'Shared Reef',
          isShared: true,
        );
        final created = await repository.createSite(site);

        final readBack = await repository.getSiteById(created.id);
        expect(readBack, isNotNull);
        expect(readBack!.isShared, isTrue);
      });

      test('createSite defaults isShared to false', () async {
        const site = DiveSite(id: '', name: 'Default Reef');
        final created = await repository.createSite(site);

        final readBack = await repository.getSiteById(created.id);
        expect(readBack!.isShared, isFalse);
      });

      test('updateSite persists isShared changes', () async {
        const site = DiveSite(id: '', name: 'Toggle');
        final created = await repository.createSite(site);

        await repository.updateSite(created.copyWith(isShared: true));

        final readBack = await repository.getSiteById(created.id);
        expect(readBack!.isShared, isTrue);
      });
    });
```

If `site_repository_test.dart` does not import the `DiveSite` entity, add:

```dart
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_sites/data/repositories/site_repository_test.dart --name "isShared persistence"`
Expected: FAIL.

- [ ] **Step 3: Thread `isShared` through the site repository**

Edit `lib/features/dive_sites/data/repositories/site_repository_impl.dart`:

**In `createSite` (around line 57-107)**, inside the `DiveSitesCompanion(...)` insert, add before `createdAt: Value(now),`:

```dart
              isShared: Value(site.isShared),
```

**In `updateSite` (around line 109-153)**, inside the `DiveSitesCompanion(...)` write, add before `updatedAt: Value(now),`:

```dart
          isShared: Value(site.isShared),
```

**In `_updateSiteRow` (around line 604-626, used by merge/undo flows)**, add before `updatedAt: Value(now),`:

```dart
        isShared: Value(site.isShared),
```

**In `_mapRowToSite` (around line 580-602)**, in the returned `domain.DiveSite(...)`, add as the last argument before the closing `);`:

```dart
      isShared: row.isShared,
```

**In `undoMerge` (around line 385-412)** — the inline `DiveSitesCompanion(...)` for re-creating deleted sites. Add before `createdAt: Value(ts?.createdAt ?? now),`:

```dart
                  isShared: Value(site.isShared),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_sites/data/repositories/site_repository_test.dart --name "isShared persistence"`
Expected: PASS.

- [ ] **Step 5: Regression-check**

Run: `flutter test test/features/dive_sites/data/repositories/site_repository_test.dart`
Expected: All existing tests pass (including the merge/undo tests, which now round-trip `isShared` transparently).

- [ ] **Step 6: Analyze**

Run: `flutter analyze lib/features/dive_sites/data/`
Expected: No errors.

- [ ] **Step 7: Commit**

```bash
git add lib/features/dive_sites/data/repositories/site_repository_impl.dart \
  test/features/dive_sites/data/repositories/site_repository_test.dart
git commit -m "feat(sites): persist isShared in SiteRepository"
```

---

## Task 6: Create `VisibilityFilter` helper

**Files:**
- Create: `lib/core/data/visibility/visibility_filter.dart`
- Create: `test/core/data/visibility/visibility_filter_test.dart`

**Context:** The helper must serve two query idioms: Drift builder (`SimpleSelectStatement`) and raw SQL strings via `customSelect`. The predicate is `(diver_id = ? OR is_shared = 1)`. When `diverId == null`, the helper must be a no-op so existing "no filter" call sites stay unchanged.

- [ ] **Step 1: Write the failing test**

Create `test/core/data/visibility/visibility_filter_test.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/visibility_filter.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  group('VisibilityFilter.sqlFragment', () {
    test('returns empty fragment when diverId is null', () {
      final frag = VisibilityFilter.sqlFragment(
        tableAlias: 't',
        diverId: null,
        conjunction: 'AND',
      );
      expect(frag.whereClause, isEmpty);
      expect(frag.variables, isEmpty);
      expect(frag.isEmpty, isTrue);
    });

    test('builds predicate with AND conjunction and qualified columns', () {
      final frag = VisibilityFilter.sqlFragment(
        tableAlias: 't',
        diverId: 'diver-1',
        conjunction: 'AND',
      );
      expect(
        frag.whereClause,
        equals(' AND (t.diver_id = ? OR t.is_shared = 1)'),
      );
      expect(frag.variables.length, equals(1));
      expect(frag.isEmpty, isFalse);
    });

    test('builds predicate with WHERE conjunction', () {
      final frag = VisibilityFilter.sqlFragment(
        tableAlias: 'trips',
        diverId: 'd-1',
        conjunction: 'WHERE',
      );
      expect(
        frag.whereClause,
        equals(' WHERE (trips.diver_id = ? OR trips.is_shared = 1)'),
      );
    });
  });

  group('VisibilityFilter.applyToTrips', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() => db.close());

    Future<void> insertTrip(String id, String diverId, bool shared) async {
      const t = 1_700_000_000_000;
      await db.into(db.trips).insert(
        TripsCompanion.insert(
          id: id,
          name: id,
          startDate: t,
          endDate: t,
          createdAt: t,
          updatedAt: t,
          diverId: Value(diverId),
          isShared: Value(shared),
        ),
      );
    }

    test('no-op when diverId is null', () async {
      await insertTrip('t1', 'A', false);
      await insertTrip('t2', 'B', false);

      final query = db.select(db.trips);
      VisibilityFilter.applyToTrips(query, null);
      final rows = await query.get();

      expect(rows.length, equals(2));
    });

    test('returns owned rows for the given diver', () async {
      await insertTrip('t1', 'A', false);
      await insertTrip('t2', 'B', false);

      final query = db.select(db.trips);
      VisibilityFilter.applyToTrips(query, 'A');
      final rows = await query.get();

      expect(rows.map((r) => r.id), equals(['t1']));
    });

    test('returns shared rows regardless of owner', () async {
      await insertTrip('t1', 'A', false);
      await insertTrip('t2', 'B', true);
      await insertTrip('t3', 'C', false);

      final query = db.select(db.trips);
      VisibilityFilter.applyToTrips(query, 'A');
      final rows = await query.get();

      expect(
        rows.map((r) => r.id).toSet(),
        equals({'t1', 't2'}),
      );
    });
  });

  group('VisibilityFilter.applyToDiveSites', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() => db.close());

    Future<void> insertSite(String id, String diverId, bool shared) async {
      const t = 1_700_000_000_000;
      await db.into(db.diveSites).insert(
        DiveSitesCompanion.insert(
          id: id,
          name: id,
          createdAt: t,
          updatedAt: t,
          diverId: Value(diverId),
          isShared: Value(shared),
        ),
      );
    }

    test('returns owner + shared rows', () async {
      await insertSite('s1', 'A', false);
      await insertSite('s2', 'B', true);
      await insertSite('s3', 'C', false);

      final query = db.select(db.diveSites);
      VisibilityFilter.applyToDiveSites(query, 'A');
      final rows = await query.get();

      expect(
        rows.map((r) => r.id).toSet(),
        equals({'s1', 's2'}),
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/data/visibility/visibility_filter_test.dart`
Expected: FAIL — `visibility_filter.dart` does not exist.

- [ ] **Step 3: Implement `VisibilityFilter`**

Create `lib/core/data/visibility/visibility_filter.dart`:

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';

/// Applies the owner-or-shared visibility predicate to queries on tables
/// that have a nullable `diver_id` and an `is_shared` column (trips,
/// dive_sites). When `diverId` is `null`, every entry point is a no-op so
/// existing "all divers / unfiltered" call sites keep working unchanged.
class VisibilityFilter {
  const VisibilityFilter._();

  /// Applies `(diver_id = diverId OR is_shared = true)` to a Drift select
  /// on the `trips` table.
  static void applyToTrips(
    SimpleSelectStatement<$TripsTable, Trip> query,
    String? diverId,
  ) {
    if (diverId == null) return;
    query.where((t) => t.diverId.equals(diverId) | t.isShared.equals(true));
  }

  /// Applies `(diver_id = diverId OR is_shared = true)` to a Drift select
  /// on the `dive_sites` table.
  static void applyToDiveSites(
    SimpleSelectStatement<$DiveSitesTable, DiveSite> query,
    String? diverId,
  ) {
    if (diverId == null) return;
    query.where((t) => t.diverId.equals(diverId) | t.isShared.equals(true));
  }

  /// Returns a SQL fragment and its variables for raw-SQL composition.
  ///
  /// * `tableAlias` qualifies the column names (e.g. `"t"` in
  ///   `FROM trips t`, or `"trips"` when the table is unaliased).
  /// * `conjunction` is `"AND"` when other WHERE clauses precede this
  ///   fragment, or `"WHERE"` when this is the first predicate.
  ///
  /// When `diverId` is `null`, the fragment is empty (no text, no vars),
  /// so callers can concatenate unconditionally.
  static SqlFragment sqlFragment({
    required String tableAlias,
    required String? diverId,
    required String conjunction,
  }) {
    if (diverId == null) {
      return const SqlFragment(whereClause: '', variables: []);
    }
    final clause =
        ' $conjunction ($tableAlias.diver_id = ? OR $tableAlias.is_shared = 1)';
    return SqlFragment(
      whereClause: clause,
      variables: [Variable.withString(diverId)],
    );
  }
}

/// A WHERE-fragment plus its variables, returned by
/// [VisibilityFilter.sqlFragment].
class SqlFragment {
  final String whereClause;
  final List<Variable<Object>> variables;

  const SqlFragment({required this.whereClause, required this.variables});

  bool get isEmpty => whereClause.isEmpty;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/data/visibility/visibility_filter_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/core/data/visibility/`
Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add lib/core/data/visibility/visibility_filter.dart \
  test/core/data/visibility/visibility_filter_test.dart
git commit -m "feat(core): add VisibilityFilter helper for owner-or-shared predicate"
```

---

## Task 7: TripRepository — apply visibility filter to diver-scoped queries

**Files:**
- Modify: `lib/features/trips/data/repositories/trip_repository.dart`
- Modify: `test/features/trips/data/repositories/trip_repository_test.dart`

**Context:** Current behavior at `trip_repository.dart:23-38` filters strictly by `diverId`. After this task, diver-scoped trip queries must return owned trips **or** shared trips. The call sites are: `getAllTrips` (Drift builder), `searchTrips` (raw SQL), `findTripForDate` (raw SQL), `getAllTripsWithStats` (raw SQL).

- [ ] **Step 1: Write the failing test**

Append to `test/features/trips/data/repositories/trip_repository_test.dart` inside the outer `group('TripRepository', () { ... })`:

```dart
    group('visibility filter', () {
      test('getAllTrips returns owner + shared for a given diver', () async {
        await repository.createTrip(
          createTestTrip(name: 'Owned by A')
              .copyWith(diverId: 'A'),
        );
        await repository.createTrip(
          createTestTrip(name: 'Owned by B')
              .copyWith(diverId: 'B'),
        );
        await repository.createTrip(
          createTestTrip(name: 'Shared from B')
              .copyWith(diverId: 'B', isShared: true),
        );

        final names = (await repository.getAllTrips(diverId: 'A'))
            .map((t) => t.name)
            .toSet();
        expect(names, equals({'Owned by A', 'Shared from B'}));
      });

      test('getAllTrips with null diverId returns everything', () async {
        await repository.createTrip(createTestTrip(name: 'One')
            .copyWith(diverId: 'A'));
        await repository.createTrip(createTestTrip(name: 'Two')
            .copyWith(diverId: 'B'));

        final trips = await repository.getAllTrips();
        expect(trips.length, equals(2));
      });

      test('searchTrips honors visibility filter', () async {
        await repository.createTrip(
          createTestTrip(name: 'Bonaire A').copyWith(diverId: 'A'),
        );
        await repository.createTrip(
          createTestTrip(name: 'Bonaire B')
              .copyWith(diverId: 'B', isShared: true),
        );
        await repository.createTrip(
          createTestTrip(name: 'Bonaire C').copyWith(diverId: 'C'),
        );

        final results = await repository.searchTrips(
          'Bonaire',
          diverId: 'A',
        );
        final names = results.map((t) => t.name).toSet();
        expect(names, equals({'Bonaire A', 'Bonaire B'}));
      });

      test('findTripForDate honors visibility filter', () async {
        final day = DateTime(2024, 6, 15);
        await repository.createTrip(
          createTestTrip(
            name: 'A trip',
            startDate: day,
            endDate: day,
          ).copyWith(diverId: 'B', isShared: true),
        );
        final trip = await repository.findTripForDate(day, diverId: 'A');
        expect(trip, isNotNull);
        expect(trip!.name, equals('A trip'));
      });

      test('getAllTripsWithStats honors visibility filter', () async {
        await repository.createTrip(
          createTestTrip(name: 'Shared X')
              .copyWith(diverId: 'B', isShared: true),
        );
        await repository.createTrip(
          createTestTrip(name: 'Private Y').copyWith(diverId: 'B'),
        );

        final all = await repository.getAllTripsWithStats(diverId: 'A');
        final names = all.map((t) => t.trip.name).toSet();
        expect(names, equals({'Shared X'}));
      });
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/trips/data/repositories/trip_repository_test.dart --name "visibility filter"`
Expected: FAIL — private-to-B trips are not returned for diver A.

- [ ] **Step 3: Apply `VisibilityFilter` in `TripRepository`**

Edit `lib/features/trips/data/repositories/trip_repository.dart`:

Add at the top of the imports:

```dart
import 'package:submersion/core/data/visibility/visibility_filter.dart';
```

**Replace `getAllTrips` body (`trip_repository.dart:23-38`)** — change the `if (diverId != null) { query.where(...) }` block to:

```dart
      VisibilityFilter.applyToTrips(query, diverId);
```

So the method body becomes:

```dart
    try {
      final query = _db.select(_db.trips)
        ..orderBy([(t) => OrderingTerm.desc(t.startDate)]);
      VisibilityFilter.applyToTrips(query, diverId);

      final rows = await query.get();
      return rows.map(_mapRowToTrip).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get all trips', error: e, stackTrace: stackTrace);
      rethrow;
    }
```

**Replace `searchTrips` (`trip_repository.dart:58-105`)** — swap the inline `diverFilter` logic for a `VisibilityFilter.sqlFragment` call. The new body:

```dart
  Future<List<domain.Trip>> searchTrips(String query, {String? diverId}) async {
    final searchTerm = '%${query.toLowerCase()}%';
    final vis = VisibilityFilter.sqlFragment(
      tableAlias: 'trips',
      diverId: diverId,
      conjunction: 'AND',
    );
    final variables = [
      Variable.withString(searchTerm),
      Variable.withString(searchTerm),
      Variable.withString(searchTerm),
      Variable.withString(searchTerm),
      ...vis.variables,
    ];

    final results = await _db.customSelect('''
      SELECT * FROM trips
      WHERE (LOWER(name) LIKE ?
         OR LOWER(location) LIKE ?
         OR LOWER(resort_name) LIKE ?
         OR LOWER(liveaboard_name) LIKE ?)
      ${vis.whereClause}
      ORDER BY start_date DESC
    ''', variables: variables).get();

    return results.map((row) {
      return domain.Trip(
        id: row.data['id'] as String,
        diverId: row.data['diver_id'] as String?,
        name: row.data['name'] as String,
        startDate: DateTime.fromMillisecondsSinceEpoch(
          row.data['start_date'] as int,
        ),
        endDate: DateTime.fromMillisecondsSinceEpoch(
          row.data['end_date'] as int,
        ),
        location: row.data['location'] as String?,
        resortName: row.data['resort_name'] as String?,
        liveaboardName: row.data['liveaboard_name'] as String?,
        notes: (row.data['notes'] as String?) ?? '',
        tripType: TripType.fromName(
          (row.data['trip_type'] as String?) ?? 'shore',
        ),
        isShared: (row.data['is_shared'] as int? ?? 0) != 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row.data['created_at'] as int,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row.data['updated_at'] as int,
        ),
      );
    }).toList();
  }
```

**Replace `findTripForDate` (`trip_repository.dart:440-483`)** — swap the inline `diverFilter` / variables build-up for the helper:

```dart
  Future<domain.Trip?> findTripForDate(DateTime date, {String? diverId}) async {
    final dateMs = date.millisecondsSinceEpoch;
    final vis = VisibilityFilter.sqlFragment(
      tableAlias: 'trips',
      diverId: diverId,
      conjunction: 'AND',
    );
    final variables = [
      Variable.withInt(dateMs),
      Variable.withInt(dateMs),
      ...vis.variables,
    ];

    final result = await _db.customSelect('''
      SELECT * FROM trips
      WHERE start_date <= ? AND end_date >= ?
      ${vis.whereClause}
      ORDER BY start_date DESC
      LIMIT 1
    ''', variables: variables).getSingleOrNull();

    if (result == null) return null;

    return domain.Trip(
      id: result.data['id'] as String,
      diverId: result.data['diver_id'] as String?,
      name: result.data['name'] as String,
      startDate: DateTime.fromMillisecondsSinceEpoch(
        result.data['start_date'] as int,
      ),
      endDate: DateTime.fromMillisecondsSinceEpoch(
        result.data['end_date'] as int,
      ),
      location: result.data['location'] as String?,
      resortName: result.data['resort_name'] as String?,
      liveaboardName: result.data['liveaboard_name'] as String?,
      notes: (result.data['notes'] as String?) ?? '',
      tripType: TripType.fromName(
        (result.data['trip_type'] as String?) ?? 'shore',
      ),
      isShared: (result.data['is_shared'] as int? ?? 0) != 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        result.data['created_at'] as int,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        result.data['updated_at'] as int,
      ),
    );
  }
```

**Replace `getAllTripsWithStats` (`trip_repository.dart:486-541`)** — swap the `diverFilter` literal. The `LEFT JOIN dives` stays intact; the visibility predicate applies to `t` (the trips alias). Use `WHERE` as the conjunction because there is no other predicate on trips prior to the fragment:

```dart
  Future<List<domain.TripWithStats>> getAllTripsWithStats({
    String? diverId,
  }) async {
    final vis = VisibilityFilter.sqlFragment(
      tableAlias: 't',
      diverId: diverId,
      conjunction: 'WHERE',
    );

    final rows = await _db.customSelect('''
      SELECT
        t.*,
        COUNT(DISTINCT d.id) AS dive_count,
        COALESCE(SUM(d.bottom_time), 0) AS total_bottom_time,
        MAX(d.max_depth) AS max_depth,
        AVG(d.avg_depth) AS avg_depth
      FROM trips t
      LEFT JOIN dives d ON d.trip_id = t.id
      ${vis.whereClause}
      GROUP BY t.id
      ORDER BY t.start_date DESC
    ''', variables: vis.variables).get();

    return rows.map((row) {
      final trip = domain.Trip(
        id: row.data['id'] as String,
        diverId: row.data['diver_id'] as String?,
        name: row.data['name'] as String,
        startDate: DateTime.fromMillisecondsSinceEpoch(
          row.data['start_date'] as int,
        ),
        endDate: DateTime.fromMillisecondsSinceEpoch(
          row.data['end_date'] as int,
        ),
        location: row.data['location'] as String?,
        resortName: row.data['resort_name'] as String?,
        liveaboardName: row.data['liveaboard_name'] as String?,
        notes: (row.data['notes'] as String?) ?? '',
        tripType: TripType.fromName(
          (row.data['trip_type'] as String?) ?? 'shore',
        ),
        isShared: (row.data['is_shared'] as int? ?? 0) != 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row.data['created_at'] as int,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row.data['updated_at'] as int,
        ),
      );
      return domain.TripWithStats(
        trip: trip,
        diveCount: row.data['dive_count'] as int,
        totalBottomTime: row.data['total_bottom_time'] as int,
        maxDepth: row.data['max_depth'] as double?,
        avgDepth: row.data['avg_depth'] as double?,
      );
    }).toList();
  }
```

- [ ] **Step 4: Run new test group to verify it passes**

Run: `flutter test test/features/trips/data/repositories/trip_repository_test.dart --name "visibility filter"`
Expected: PASS.

- [ ] **Step 5: Regression-check**

Run: `flutter test test/features/trips/data/repositories/trip_repository_test.dart`
Expected: all existing tests still pass.

Run: `flutter analyze lib/features/trips/`
Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add lib/features/trips/data/repositories/trip_repository.dart \
  test/features/trips/data/repositories/trip_repository_test.dart
git commit -m "feat(trips): filter list/search queries via VisibilityFilter"
```

---

## Task 8: SiteRepository — apply visibility filter to diver-scoped queries

**Files:**
- Modify: `lib/features/dive_sites/data/repositories/site_repository_impl.dart`
- Modify: `test/features/dive_sites/data/repositories/site_repository_test.dart`

**Context:** Diver-scoped site queries are `getAllSites` (`site_repository_impl.dart:20-37`), `searchSites` (`495-525`), and `getSitesWithDiveCounts` which delegates to `getAllSites` (`552-578`). All three take `String? diverId`.

- [ ] **Step 1: Write the failing test**

Append to `test/features/dive_sites/data/repositories/site_repository_test.dart` inside the main group:

```dart
    group('visibility filter', () {
      test('getAllSites returns owner + shared for a given diver', () async {
        await repository.createSite(
          const DiveSite(id: '', name: 'Salt A', diverId: 'A'),
        );
        await repository.createSite(
          const DiveSite(id: '', name: 'Pier B', diverId: 'B'),
        );
        await repository.createSite(
          const DiveSite(
            id: '',
            name: 'Shared Reef',
            diverId: 'B',
            isShared: true,
          ),
        );

        final names = (await repository.getAllSites(diverId: 'A'))
            .map((s) => s.name)
            .toSet();
        expect(names, equals({'Salt A', 'Shared Reef'}));
      });

      test('getAllSites with null diverId returns everything', () async {
        await repository.createSite(
          const DiveSite(id: '', name: 'One', diverId: 'A'),
        );
        await repository.createSite(
          const DiveSite(id: '', name: 'Two', diverId: 'B'),
        );

        final sites = await repository.getAllSites();
        expect(sites.length, equals(2));
      });

      test('searchSites honors visibility filter', () async {
        await repository.createSite(
          const DiveSite(id: '', name: 'Bonaire Reef', diverId: 'A'),
        );
        await repository.createSite(
          const DiveSite(
            id: '',
            name: 'Bonaire Pier',
            diverId: 'B',
            isShared: true,
          ),
        );
        await repository.createSite(
          const DiveSite(id: '', name: 'Bonaire Private', diverId: 'C'),
        );

        final results = await repository.searchSites('Bonaire', diverId: 'A');
        final names = results.map((s) => s.name).toSet();
        expect(names, equals({'Bonaire Reef', 'Bonaire Pier'}));
      });
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_sites/data/repositories/site_repository_test.dart --name "visibility filter"`
Expected: FAIL.

- [ ] **Step 3: Apply `VisibilityFilter` in `SiteRepository`**

Edit `lib/features/dive_sites/data/repositories/site_repository_impl.dart`:

Add import:

```dart
import 'package:submersion/core/data/visibility/visibility_filter.dart';
```

**In `getAllSites` (`site_repository_impl.dart:20-37`)**, replace the inner `if (diverId != null) { query.where(...) }` with:

```dart
        VisibilityFilter.applyToDiveSites(query, diverId);
```

**In `searchSites` (`site_repository_impl.dart:495-525`)**, same replacement inside `PerfTimer.measure(...)`:

```dart
        VisibilityFilter.applyToDiveSites(searchQuery, diverId);
```

(Delete the old `if (diverId != null) { searchQuery.where(...) }` block.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_sites/data/repositories/site_repository_test.dart --name "visibility filter"`
Expected: PASS.

- [ ] **Step 5: Regression-check**

Run: `flutter test test/features/dive_sites/data/repositories/site_repository_test.dart`
Expected: all tests pass.

Run: `flutter analyze lib/features/dive_sites/`
Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_sites/data/repositories/site_repository_impl.dart \
  test/features/dive_sites/data/repositories/site_repository_test.dart
git commit -m "feat(sites): filter list/search queries via VisibilityFilter"
```

---

## Task 9: TripRepository — `setShared` and `shareAllForDiver`

**Files:**
- Modify: `lib/features/trips/data/repositories/trip_repository.dart`
- Modify: `test/features/trips/data/repositories/trip_repository_test.dart`

- [ ] **Step 1: Write the failing tests**

Append to the outer trip repository test `group`:

```dart
    group('sharing actions', () {
      test('setShared toggles the field on a single trip', () async {
        final created = await repository.createTrip(
          createTestTrip(name: 'Flip me').copyWith(diverId: 'A'),
        );

        await repository.setShared(created.id, true);
        final readShared = await repository.getTripById(created.id);
        expect(readShared!.isShared, isTrue);

        await repository.setShared(created.id, false);
        final readBack = await repository.getTripById(created.id);
        expect(readBack!.isShared, isFalse);
      });

      test('shareAllForDiver marks only that diver\'s private trips shared',
          () async {
        await repository.createTrip(
          createTestTrip(name: 'A1').copyWith(diverId: 'A'),
        );
        await repository.createTrip(
          createTestTrip(name: 'A2').copyWith(diverId: 'A'),
        );
        await repository.createTrip(
          createTestTrip(name: 'B1').copyWith(diverId: 'B'),
        );
        await repository.createTrip(
          createTestTrip(name: 'A3-already')
              .copyWith(diverId: 'A', isShared: true),
        );

        final updatedCount = await repository.shareAllForDiver('A');
        expect(updatedCount, equals(2));

        final aTrips = await repository.getAllTrips(diverId: 'A');
        final aShared = {
          for (final t in aTrips) t.name: t.isShared,
        };
        expect(aShared['A1'], isTrue);
        expect(aShared['A2'], isTrue);
        expect(aShared['A3-already'], isTrue);

        // B's trip remains private.
        final bTrips = await repository.getAllTrips(diverId: 'B');
        expect(
          bTrips.singleWhere((t) => t.name == 'B1').isShared,
          isFalse,
        );
      });

      test('shareAllForDiver returns 0 when nothing to share', () async {
        await repository.createTrip(
          createTestTrip(name: 'Already')
              .copyWith(diverId: 'A', isShared: true),
        );
        expect(await repository.shareAllForDiver('A'), equals(0));
      });
    });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/trips/data/repositories/trip_repository_test.dart --name "sharing actions"`
Expected: FAIL — `setShared` and `shareAllForDiver` undefined.

- [ ] **Step 3: Add `setShared` and `shareAllForDiver` to `TripRepository`**

Edit `lib/features/trips/data/repositories/trip_repository.dart`. Add these two methods (place them after `updateTrip`, before `deleteTrip`):

```dart
  /// Flip the shared state of a single trip. Marks it pending for sync.
  Future<void> setShared(String id, bool isShared) async {
    try {
      _log.info('Setting trip $id isShared=$isShared');
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.trips)..where((t) => t.id.equals(id))).write(
        TripsCompanion(
          isShared: Value(isShared),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'trips',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set shared flag on trip $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Mark every private trip owned by [diverId] as shared. Returns the
  /// count of rows updated. All updated rows are marked pending for sync.
  Future<int> shareAllForDiver(String diverId) async {
    try {
      _log.info('Bulk sharing all private trips for diver $diverId');
      final now = DateTime.now().millisecondsSinceEpoch;

      return await _db.transaction(() async {
        final toShare = await (_db.select(_db.trips)
              ..where((t) => t.diverId.equals(diverId) & t.isShared.equals(false)))
            .get();

        if (toShare.isEmpty) return 0;

        await _db.customUpdate(
          'UPDATE trips SET is_shared = 1, updated_at = ? '
          'WHERE diver_id = ? AND is_shared = 0',
          variables: [
            Variable.withInt(now),
            Variable.withString(diverId),
          ],
          updates: {_db.trips},
        );

        for (final row in toShare) {
          await _syncRepository.markRecordPending(
            entityType: 'trips',
            recordId: row.id,
            localUpdatedAt: now,
          );
        }
        SyncEventBus.notifyLocalChange();
        return toShare.length;
      });
    } catch (e, stackTrace) {
      _log.error(
        'Failed to bulk-share trips for diver $diverId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/trips/data/repositories/trip_repository_test.dart --name "sharing actions"`
Expected: PASS.

- [ ] **Step 5: Regression-check**

Run: `flutter test test/features/trips/data/repositories/trip_repository_test.dart`
Expected: all tests pass.

Run: `flutter analyze lib/features/trips/`
Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add lib/features/trips/data/repositories/trip_repository.dart \
  test/features/trips/data/repositories/trip_repository_test.dart
git commit -m "feat(trips): add setShared and shareAllForDiver"
```

---

## Task 10: SiteRepository — `setShared` and `shareAllForDiver`

**Files:**
- Modify: `lib/features/dive_sites/data/repositories/site_repository_impl.dart`
- Modify: `test/features/dive_sites/data/repositories/site_repository_test.dart`

- [ ] **Step 1: Write the failing tests**

Append to the outer site repository test `group`:

```dart
    group('sharing actions', () {
      test('setShared toggles the field on a single site', () async {
        final created = await repository.createSite(
          const DiveSite(id: '', name: 'Flip', diverId: 'A'),
        );

        await repository.setShared(created.id, true);
        final readShared = await repository.getSiteById(created.id);
        expect(readShared!.isShared, isTrue);

        await repository.setShared(created.id, false);
        final readBack = await repository.getSiteById(created.id);
        expect(readBack!.isShared, isFalse);
      });

      test('shareAllForDiver shares only that diver\'s private sites',
          () async {
        await repository.createSite(
          const DiveSite(id: '', name: 'A1', diverId: 'A'),
        );
        await repository.createSite(
          const DiveSite(id: '', name: 'A2', diverId: 'A'),
        );
        await repository.createSite(
          const DiveSite(id: '', name: 'B1', diverId: 'B'),
        );
        await repository.createSite(
          const DiveSite(
            id: '',
            name: 'A3-already',
            diverId: 'A',
            isShared: true,
          ),
        );

        final count = await repository.shareAllForDiver('A');
        expect(count, equals(2));

        final aSites = await repository.getAllSites(diverId: 'A');
        final aMap = {for (final s in aSites) s.name: s.isShared};
        expect(aMap['A1'], isTrue);
        expect(aMap['A2'], isTrue);
        expect(aMap['A3-already'], isTrue);

        final bSites = await repository.getAllSites(diverId: 'B');
        expect(
          bSites.singleWhere((s) => s.name == 'B1').isShared,
          isFalse,
        );
      });

      test('shareAllForDiver returns 0 when nothing to share', () async {
        await repository.createSite(
          const DiveSite(
            id: '',
            name: 'Already',
            diverId: 'A',
            isShared: true,
          ),
        );
        expect(await repository.shareAllForDiver('A'), equals(0));
      });
    });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_sites/data/repositories/site_repository_test.dart --name "sharing actions"`
Expected: FAIL.

- [ ] **Step 3: Add `setShared` and `shareAllForDiver` to `SiteRepository`**

Edit `lib/features/dive_sites/data/repositories/site_repository_impl.dart`. Add these two methods after `updateSite` and before `deleteSite`:

```dart
  /// Flip the shared state of a single site. Marks it pending for sync.
  Future<void> setShared(String id, bool isShared) async {
    try {
      _log.info('Setting site $id isShared=$isShared');
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.diveSites)..where((t) => t.id.equals(id))).write(
        DiveSitesCompanion(
          isShared: Value(isShared),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'diveSites',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set shared flag on site $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Mark every private site owned by [diverId] as shared. Returns the
  /// count of rows updated. All updated rows are marked pending for sync.
  Future<int> shareAllForDiver(String diverId) async {
    try {
      _log.info('Bulk sharing all private sites for diver $diverId');
      final now = DateTime.now().millisecondsSinceEpoch;

      return await _db.transaction(() async {
        final toShare = await (_db.select(_db.diveSites)
              ..where((t) =>
                  t.diverId.equals(diverId) & t.isShared.equals(false)))
            .get();

        if (toShare.isEmpty) return 0;

        await _db.customUpdate(
          'UPDATE dive_sites SET is_shared = 1, updated_at = ? '
          'WHERE diver_id = ? AND is_shared = 0',
          variables: [
            Variable.withInt(now),
            Variable.withString(diverId),
          ],
          updates: {_db.diveSites},
        );

        for (final row in toShare) {
          await _syncRepository.markRecordPending(
            entityType: 'diveSites',
            recordId: row.id,
            localUpdatedAt: now,
          );
        }
        SyncEventBus.notifyLocalChange();
        return toShare.length;
      });
    } catch (e, stackTrace) {
      _log.error(
        'Failed to bulk-share sites for diver $diverId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_sites/data/repositories/site_repository_test.dart --name "sharing actions"`
Expected: PASS.

- [ ] **Step 5: Regression-check**

Run: `flutter test test/features/dive_sites/data/repositories/site_repository_test.dart`
Expected: all tests pass.

Run: `flutter analyze lib/features/dive_sites/`
Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_sites/data/repositories/site_repository_impl.dart \
  test/features/dive_sites/data/repositories/site_repository_test.dart
git commit -m "feat(sites): add setShared and shareAllForDiver"
```

---

## Task 11: AppSettingsRepository — global `share_new_records_by_default` key

**Files:**
- Create: `lib/features/settings/data/repositories/app_settings_repository.dart`
- Create: `test/features/settings/data/repositories/app_settings_repository_test.dart`

**Context:** The existing `settings` table is a `(key TEXT PRIMARY KEY, value TEXT, updatedAt INT)` key-value store. Its current consumer is `DiverRepository` (`diver_repository.dart:389-432`) for `active_diver_id`. Follow the same `insertOnConflictUpdate` pattern. The repository is keyed by string key, not by diver.

- [ ] **Step 1: Write the failing test**

Create `test/features/settings/data/repositories/app_settings_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppSettingsRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = AppSettingsRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('AppSettingsRepository.getShareByDefault', () {
    test('returns false when key is absent', () async {
      expect(await repository.getShareByDefault(), isFalse);
    });

    test('round-trips true', () async {
      await repository.setShareByDefault(true);
      expect(await repository.getShareByDefault(), isTrue);
    });

    test('round-trips false after being set to true', () async {
      await repository.setShareByDefault(true);
      await repository.setShareByDefault(false);
      expect(await repository.getShareByDefault(), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/settings/data/repositories/app_settings_repository_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement `AppSettingsRepository`**

Create `lib/features/settings/data/repositories/app_settings_repository.dart`:

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';

/// Read/write global (not per-diver) app settings stored in the
/// key-value `settings` table.
class AppSettingsRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  static final _log = LoggerService.forClass(AppSettingsRepository);

  static const _shareByDefaultKey = 'share_new_records_by_default';

  /// Whether newly created sites and trips default to shared.
  /// Returns `false` when the key has never been set.
  Future<bool> getShareByDefault() async {
    try {
      final row = await (_db.select(_db.settings)
            ..where((t) => t.key.equals(_shareByDefaultKey)))
          .getSingleOrNull();
      return row?.value == 'true';
    } catch (e, stackTrace) {
      _log.error(
        'Failed to read $_shareByDefaultKey',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<void> setShareByDefault(bool value) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.into(_db.settings).insertOnConflictUpdate(
        SettingsCompanion(
          key: const Value(_shareByDefaultKey),
          value: Value(value ? 'true' : 'false'),
          updatedAt: Value(now),
        ),
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to write $_shareByDefaultKey',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/settings/data/repositories/app_settings_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/settings/data/`
Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add lib/features/settings/data/repositories/app_settings_repository.dart \
  test/features/settings/data/repositories/app_settings_repository_test.dart
git commit -m "feat(settings): add AppSettingsRepository for global share-by-default key"
```

---

## Task 12: Add localized UI strings (English)

**Files:**
- Modify: `lib/l10n/arb/app_en.arb`
- Generated: `lib/l10n/gen/` (via `flutter gen-l10n`)

**Context:** The app localizes every UI string via ARB files (`lib/l10n/arb/app_en.arb` is the source of truth; other locales are translated in a separate pass, consistent with the recent i18n commits). Access pattern is `context.l10n.<keyName>`. Add only the English strings here — other locales can be populated in a later i18n pass.

- [ ] **Step 1: Add new strings to `app_en.arb`**

Edit `lib/l10n/arb/app_en.arb`. Inside the top-level JSON object, add these key/value pairs (place them alphabetically or in a logical cluster — match the existing file's convention by grouping near other settings strings):

```json
  "share_toggle_label": "Share with all dive profiles",
  "@share_toggle_label": {
    "description": "Switch on trip/site edit pages that makes the record visible to all local dive profiles."
  },
  "settings_shareByDefault_title": "Share new sites and trips by default",
  "@settings_shareByDefault_title": {
    "description": "Global setting: when ON, newly created trips and sites are shared with all dive profiles by default."
  },
  "settings_shareAllSites_title": "Share all my sites",
  "@settings_shareAllSites_title": {},
  "settings_shareAllTrips_title": "Share all my trips",
  "@settings_shareAllTrips_title": {},
  "settings_shareAllSites_confirm": "Make all {count} of your sites visible to every dive profile in this app? You can unshare individual sites later.",
  "@settings_shareAllSites_confirm": {
    "placeholders": {
      "count": {"type": "int"}
    }
  },
  "settings_shareAllTrips_confirm": "Make all {count} of your trips visible to every dive profile in this app? You can unshare individual trips later.",
  "@settings_shareAllTrips_confirm": {
    "placeholders": {
      "count": {"type": "int"}
    }
  },
  "settings_shareAllSites_snackbar": "Shared {count} sites with all dive profiles.",
  "@settings_shareAllSites_snackbar": {
    "placeholders": {
      "count": {"type": "int"}
    }
  },
  "settings_shareAllTrips_snackbar": "Shared {count} trips with all dive profiles.",
  "@settings_shareAllTrips_snackbar": {
    "placeholders": {
      "count": {"type": "int"}
    }
  },
  "settings_shareAll_noneToShare": "Nothing to share.",
  "@settings_shareAll_noneToShare": {},
  "settings_sharedData_sectionTitle": "Shared data",
  "@settings_sharedData_sectionTitle": {},
```

- [ ] **Step 2: Regenerate the localization delegates**

Run: `flutter gen-l10n`
Expected: Success. The `AppLocalizations` Dart class now exposes the new getters.

- [ ] **Step 3: Verify compilation**

Run: `flutter analyze lib/l10n/`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/arb/app_en.arb lib/l10n/gen/
git commit -m "i18n(en): add strings for shared sites/trips across dive profiles"
```

---

## Task 13: Trip edit page — "Share with all dive profiles" switch

**Files:**
- Modify: `lib/features/trips/presentation/pages/trip_edit_page.dart`
- Modify: `test/features/trips/presentation/pages/trip_edit_page_test.dart`

**Context:** `TripEditPage` is a `ConsumerStatefulWidget` (`trip_edit_page.dart:17-33`). It loads an existing trip via `_loadTrip()` in edit mode. On save, it builds a `Trip` and calls the trip provider. The switch must be suppressed when `allDiversProvider` reports fewer than 2 divers.

- [ ] **Step 1: Write the failing widget test**

Append to `test/features/trips/presentation/pages/trip_edit_page_test.dart`:

```dart
  group('share toggle', () {
    testWidgets('hides the toggle when only one diver exists',
        (tester) async {
      await tester.pumpWidget(
        // Uses the existing helper that wraps TripEditPage with a
        // MaterialApp + ProviderScope. Provide a single-diver override.
        wrapWithProviders(
          child: const TripEditPage(),
          diverCount: 1,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Share with all dive profiles'), findsNothing);
    });

    testWidgets(
      'shows the toggle when 2+ divers and defaults from AppSettings',
      (tester) async {
        await tester.pumpWidget(
          wrapWithProviders(
            child: const TripEditPage(),
            diverCount: 2,
            shareByDefault: true,
          ),
        );
        await tester.pumpAndSettle();

        final toggleFinder = find.byWidgetPredicate((w) =>
            w is SwitchListTile &&
            (w.title is Text) &&
            ((w.title as Text).data == 'Share with all dive profiles'));
        expect(toggleFinder, findsOneWidget);
        final toggle = tester.widget<SwitchListTile>(toggleFinder);
        expect(toggle.value, isTrue);
      },
    );
  });
```

If `wrapWithProviders` does not exist with the needed parameters, extend its implementation in the test file (or inline the overrides) to:
  1. Override `allDiversProvider` with a fake list of `diverCount` `Diver` stubs.
  2. Override a new `appSettingsRepositoryProvider` / `shareByDefaultProvider` so the page can read the default synchronously.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/trips/presentation/pages/trip_edit_page_test.dart --name "share toggle"`
Expected: FAIL.

- [ ] **Step 3: Add a provider for share-by-default**

Edit `lib/features/settings/presentation/providers/settings_providers.dart` (this file already exists per `settings_page.dart:21`). Add:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  return AppSettingsRepository();
});

final shareByDefaultProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(appSettingsRepositoryProvider);
  return repo.getShareByDefault();
});
```

(If the import block already contains the Riverpod/providers imports, do not duplicate them — only add the two provider declarations.)

- [ ] **Step 4: Wire the switch into `TripEditPage`**

Edit `lib/features/trips/presentation/pages/trip_edit_page.dart`:

Add imports:

```dart
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
```

Add state field to `_TripEditPageState`:

```dart
  bool _isShared = false;
```

In `_loadTrip()` (where `_originalTrip` is populated), set the initial value from the existing trip:

```dart
    setState(() {
      // ...existing state setters...
      _isShared = loadedTrip.isShared;
    });
```

For new trips (no `tripId`), set the default inside `initState` or the first `build`. Use `ref.read(shareByDefaultProvider.future)` in an async post-frame callback:

```dart
  @override
  void initState() {
    super.initState();
    // ...existing init...
    if (!isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final shareByDefault = await ref.read(shareByDefaultProvider.future);
        if (!mounted) return;
        setState(() => _isShared = shareByDefault);
      });
    }
  }
```

In `build`, add the switch to the form. Find the existing `Column` (or section) that renders the trip's notes field, and append (gated by diver count):

```dart
            ref.watch(allDiversProvider).maybeWhen(
              data: (divers) => divers.length >= 2
                  ? SwitchListTile(
                      title: Text(context.l10n.share_toggle_label),
                      value: _isShared,
                      onChanged: (v) => setState(() {
                        _isShared = v;
                        _hasChanges = true;
                      }),
                    )
                  : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            ),
```

In the save path (where the `Trip` is constructed before calling `createTrip` / `updateTrip`), include:

```dart
      isShared: _isShared,
```

- [ ] **Step 5: Run the widget test to verify it passes**

Run: `flutter test test/features/trips/presentation/pages/trip_edit_page_test.dart --name "share toggle"`
Expected: PASS.

- [ ] **Step 6: Run the full trip edit page suite**

Run: `flutter test test/features/trips/presentation/pages/trip_edit_page_test.dart`
Expected: All existing tests pass.

- [ ] **Step 7: Analyze**

Run: `flutter analyze lib/features/trips/ lib/features/settings/presentation/providers/`
Expected: No errors.

- [ ] **Step 8: Commit**

```bash
git add lib/features/trips/presentation/pages/trip_edit_page.dart \
  lib/features/settings/presentation/providers/settings_providers.dart \
  test/features/trips/presentation/pages/trip_edit_page_test.dart
git commit -m "feat(trips): add share-with-all-dive-profiles toggle to trip edit page"
```

---

## Task 14: Site edit page — "Share with all dive profiles" switch

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_edit_page.dart`
- Modify: `test/features/dive_sites/presentation/pages/site_edit_page_test.dart` (create if absent)

**Context:** Mirrors Task 13. The site edit page follows the same `ConsumerStatefulWidget` shape as the trip edit page. The l10n key, diver-count suppression, and default-from-settings logic are identical.

- [ ] **Step 1: Write the failing widget test**

Create or append `test/features/dive_sites/presentation/pages/site_edit_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ... add the same set of imports the existing site edit page tests use,
// including the helper that yields a MaterialApp + ProviderScope with
// the necessary repository/provider overrides.

void main() {
  group('SiteEditPage share toggle', () {
    testWidgets('hides the toggle when only one diver exists',
        (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          child: const SiteEditPage(),
          diverCount: 1,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Share with all dive profiles'), findsNothing);
    });

    testWidgets('shows toggle and reflects AppSettings default for new site',
        (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          child: const SiteEditPage(),
          diverCount: 2,
          shareByDefault: true,
        ),
      );
      await tester.pumpAndSettle();

      final toggleFinder = find.byWidgetPredicate((w) =>
          w is SwitchListTile &&
          (w.title is Text) &&
          ((w.title as Text).data == 'Share with all dive profiles'));
      expect(toggleFinder, findsOneWidget);
      final toggle = tester.widget<SwitchListTile>(toggleFinder);
      expect(toggle.value, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_sites/presentation/pages/site_edit_page_test.dart --name "share toggle"`
Expected: FAIL.

- [ ] **Step 3: Wire the switch into `SiteEditPage`**

Edit `lib/features/dive_sites/presentation/pages/site_edit_page.dart`:

Add imports:

```dart
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
```

(Only add imports that are not already present.)

Add state field:

```dart
  bool _isShared = false;
```

In the existing load path (mirrors `_loadTrip`), set `_isShared` from `loadedSite.isShared`. For a new site, inside `initState`:

```dart
  @override
  void initState() {
    super.initState();
    if (!isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final shareByDefault = await ref.read(shareByDefaultProvider.future);
        if (!mounted) return;
        setState(() => _isShared = shareByDefault);
      });
    }
    // ...existing init...
  }
```

In the form's build method, append near the notes/description section:

```dart
            ref.watch(allDiversProvider).maybeWhen(
              data: (divers) => divers.length >= 2
                  ? SwitchListTile(
                      title: Text(context.l10n.share_toggle_label),
                      value: _isShared,
                      onChanged: (v) => setState(() {
                        _isShared = v;
                        _hasChanges = true;
                      }),
                    )
                  : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            ),
```

On save, include:

```dart
      isShared: _isShared,
```

in the `DiveSite(...)` constructor call or `copyWith` used before `createSite`/`updateSite`.

- [ ] **Step 4: Run the widget test to verify it passes**

Run: `flutter test test/features/dive_sites/presentation/pages/site_edit_page_test.dart --name "share toggle"`
Expected: PASS.

- [ ] **Step 5: Regression-check**

Run: `flutter test test/features/dive_sites/`
Expected: All tests pass.

Run: `flutter analyze lib/features/dive_sites/`
Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_sites/presentation/pages/site_edit_page.dart \
  test/features/dive_sites/presentation/pages/site_edit_page_test.dart
git commit -m "feat(sites): add share-with-all-dive-profiles toggle to site edit page"
```

---

## Task 15: Trip list tile — shared icon

**Files:**
- Modify: `lib/features/trips/presentation/widgets/trip_list_content.dart`
- Modify: `test/features/trips/presentation/widgets/trip_list_content_test.dart`

**Context:** The trip list renders tiles in a `ListView.builder`. Add a small `Icon(Icons.people_outline)` next to (or inside) the tile title when `trip.isShared && diverCount > 1`. For single-diver installs, render nothing.

- [ ] **Step 1: Write the failing test**

Append to `test/features/trips/presentation/widgets/trip_list_content_test.dart`:

```dart
  group('shared icon', () {
    testWidgets('renders people_outline icon for shared trips with 2+ divers',
        (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          child: const TripListContent(),
          diverCount: 2,
          trips: [
            tripWithStats(name: 'Shared trip', isShared: true),
            tripWithStats(name: 'Private trip', isShared: false),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Exactly one icon on the shared tile.
      final sharedIcon = find.descendant(
        of: find.widgetWithText(ListTile, 'Shared trip'),
        matching: find.byIcon(Icons.people_outline),
      );
      expect(sharedIcon, findsOneWidget);

      final privateIcon = find.descendant(
        of: find.widgetWithText(ListTile, 'Private trip'),
        matching: find.byIcon(Icons.people_outline),
      );
      expect(privateIcon, findsNothing);
    });

    testWidgets('does not render icon when only one diver', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          child: const TripListContent(),
          diverCount: 1,
          trips: [tripWithStats(name: 'Shared trip', isShared: true)],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.people_outline), findsNothing);
    });
  });
```

`tripWithStats(...)` and `wrapWithProviders(...)` are test helpers; extend them (if needed) to accept an `isShared` parameter and a `diverCount`.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/trips/presentation/widgets/trip_list_content_test.dart --name "shared icon"`
Expected: FAIL.

- [ ] **Step 3: Render the icon in the trip tile**

Edit `lib/features/trips/presentation/widgets/trip_list_content.dart`. In the tile widget that renders the trip row (typically inside `ListView.builder` or a dedicated tile widget like `TripListTile`), locate the title subtree. Wrap the title Text in a Row:

```dart
Row(
  children: [
    Expanded(child: Text(trip.name /* existing style */)),
    if (trip.isShared && divers.length >= 2) ...[
      const SizedBox(width: 6),
      Icon(
        Icons.people_outline,
        size: 16,
        color: Theme.of(context).colorScheme.primary,
      ),
    ],
  ],
),
```

Obtain `divers.length` from `ref.watch(allDiversProvider)` (use `.valueOrNull?.length ?? 0` for a safe synchronous read). Thread it into the tile constructor if the tile widget is separate from the list content.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/trips/presentation/widgets/trip_list_content_test.dart --name "shared icon"`
Expected: PASS.

- [ ] **Step 5: Regression-check**

Run: `flutter test test/features/trips/presentation/widgets/trip_list_content_test.dart`
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/trips/presentation/widgets/trip_list_content.dart \
  test/features/trips/presentation/widgets/trip_list_content_test.dart
git commit -m "feat(trips): show shared icon on trip list tiles"
```

---

## Task 16: Site list tile — shared icon

**Files:**
- Modify: `lib/features/dive_sites/presentation/widgets/site_list_content.dart`
- Modify: `test/features/dive_sites/presentation/widgets/site_list_content_test.dart`

**Context:** Mirrors Task 15.

- [ ] **Step 1: Write the failing test**

Append to `test/features/dive_sites/presentation/widgets/site_list_content_test.dart`:

```dart
  group('shared icon', () {
    testWidgets('renders people_outline icon on shared sites with 2+ divers',
        (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          child: const SiteListContent(),
          diverCount: 2,
          sites: const [
            DiveSite(id: 's1', name: 'Shared Reef', isShared: true),
            DiveSite(id: 's2', name: 'Private Reef'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Shared Reef'),
          matching: find.byIcon(Icons.people_outline),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Private Reef'),
          matching: find.byIcon(Icons.people_outline),
        ),
        findsNothing,
      );
    });

    testWidgets('does not render icon when only one diver', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          child: const SiteListContent(),
          diverCount: 1,
          sites: const [
            DiveSite(id: 's1', name: 'Shared Reef', isShared: true),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.people_outline), findsNothing);
    });
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_sites/presentation/widgets/site_list_content_test.dart --name "shared icon"`
Expected: FAIL.

- [ ] **Step 3: Render the icon in the site tile**

Edit `lib/features/dive_sites/presentation/widgets/site_list_content.dart`. Locate the tile subtree and wrap the title in the same `Row`:

```dart
Row(
  children: [
    Expanded(child: Text(site.name /* existing style */)),
    if (site.isShared && divers.length >= 2) ...[
      const SizedBox(width: 6),
      Icon(
        Icons.people_outline,
        size: 16,
        color: Theme.of(context).colorScheme.primary,
      ),
    ],
  ],
),
```

Source `divers.length` from `ref.watch(allDiversProvider).valueOrNull?.length ?? 0`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dive_sites/presentation/widgets/site_list_content_test.dart --name "shared icon"`
Expected: PASS.

- [ ] **Step 5: Regression-check**

Run: `flutter test test/features/dive_sites/presentation/widgets/site_list_content_test.dart`
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_sites/presentation/widgets/site_list_content.dart \
  test/features/dive_sites/presentation/widgets/site_list_content_test.dart
git commit -m "feat(sites): show shared icon on site list tiles"
```

---

## Task 17: Settings page — default toggle + bulk-share actions

**Files:**
- Modify: `lib/features/settings/presentation/pages/settings_page.dart`
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (for an update action)
- Create/Modify: `test/features/settings/presentation/pages/settings_page_shared_data_test.dart`

**Context:** `settings_page.dart` composes the settings UI. The new section needs:
1. A `SwitchListTile` bound to `shareByDefaultProvider` with an async update.
2. Two `ListTile`s that trigger confirmation dialogs and call `TripRepository.shareAllForDiver` / `SiteRepository.shareAllForDiver` for the current diver.
3. Suppression when fewer than 2 divers exist.

- [ ] **Step 1: Write the failing widget test**

Create `test/features/settings/presentation/pages/settings_page_shared_data_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The `wrapSettingsPage(...)` helper must provide:
//   - allDiversProvider override with diverCount stubs
//   - shareByDefaultProvider override with an initial value
//   - currentDiverIdProvider override with 'diver-A'
//   - tripRepositoryProvider override yielding an in-memory repository
//   - siteRepositoryProvider override yielding an in-memory repository
// Extend the existing settings-page test helper with these parameters.

void main() {
  group('Settings page - Shared data section', () {
    testWidgets('hidden when only one diver', (tester) async {
      await tester.pumpWidget(wrapSettingsPage(diverCount: 1));
      await tester.pumpAndSettle();
      expect(find.text('Shared data'), findsNothing);
    });

    testWidgets('shows section when 2+ divers', (tester) async {
      await tester.pumpWidget(wrapSettingsPage(diverCount: 2));
      await tester.pumpAndSettle();
      expect(find.text('Shared data'), findsOneWidget);
      expect(
        find.text('Share new sites and trips by default'),
        findsOneWidget,
      );
      expect(find.text('Share all my sites'), findsOneWidget);
      expect(find.text('Share all my trips'), findsOneWidget);
    });

    testWidgets('toggling the default switch persists via AppSettings',
        (tester) async {
      await tester.pumpWidget(
        wrapSettingsPage(diverCount: 2, shareByDefault: false),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(SwitchListTile,
            'Share new sites and trips by default'),
      );
      await tester.pumpAndSettle();

      // Assert the fake AppSettingsRepository recorded the write.
      expect(fakeAppSettings.lastWritten, isTrue);
    });

    testWidgets('share-all-sites action calls repo and shows snackbar',
        (tester) async {
      fakeSiteRepo.seedPrivateSitesForDiver('diver-A', count: 3);
      await tester.pumpWidget(wrapSettingsPage(diverCount: 2));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Share all my sites'));
      await tester.pumpAndSettle();

      // Confirm dialog
      expect(find.textContaining('Make all 3 of your sites'), findsOneWidget);
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      expect(fakeSiteRepo.shareAllCalledFor, equals('diver-A'));
      expect(
        find.textContaining('Shared 3 sites with all dive profiles'),
        findsOneWidget,
      );
    });
  });
}
```

The test file references `fakeAppSettings`, `fakeSiteRepo`, `wrapSettingsPage` helpers. These need to be implemented inside the file as small classes/functions that the test owns — do not put them in production code.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/settings/presentation/pages/settings_page_shared_data_test.dart`
Expected: FAIL.

- [ ] **Step 3: Extend `settings_providers.dart` with an update notifier for the toggle**

Edit `lib/features/settings/presentation/providers/settings_providers.dart`. Add:

```dart
final setShareByDefaultProvider =
    Provider.family<Future<void> Function(), bool>((ref, value) {
  return () async {
    final repo = ref.read(appSettingsRepositoryProvider);
    await repo.setShareByDefault(value);
    ref.invalidate(shareByDefaultProvider);
  };
});
```

(Or inline the write directly in the settings page widget — either works. The family-provider pattern keeps the write out of the widget.)

- [ ] **Step 4: Add the "Shared data" section to `settings_page.dart`**

Edit `lib/features/settings/presentation/pages/settings_page.dart`. Locate the main settings list body (a `ListView` or `Column` of sections). Insert a new section (use the existing section-building pattern in the file — likely a `Card` or grouped `ListTile`s with a header):

```dart
    Consumer(
      builder: (context, ref, _) {
        final divers = ref.watch(allDiversProvider).valueOrNull ?? const [];
        if (divers.length < 2) return const SizedBox.shrink();

        final shareByDefault =
            ref.watch(shareByDefaultProvider).valueOrNull ?? false;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                context.l10n.settings_sharedData_sectionTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            SwitchListTile(
              title: Text(context.l10n.settings_shareByDefault_title),
              value: shareByDefault,
              onChanged: (v) async {
                final repo = ref.read(appSettingsRepositoryProvider);
                await repo.setShareByDefault(v);
                ref.invalidate(shareByDefaultProvider);
              },
            ),
            ListTile(
              title: Text(context.l10n.settings_shareAllSites_title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _confirmAndBulkShareSites(context, ref),
            ),
            ListTile(
              title: Text(context.l10n.settings_shareAllTrips_title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _confirmAndBulkShareTrips(context, ref),
            ),
          ],
        );
      },
    ),
```

Add the two confirmation helpers at the end of the file (outside the widget class, or as static methods — follow the file's existing convention):

```dart
Future<void> _confirmAndBulkShareSites(
  BuildContext context,
  WidgetRef ref,
) async {
  final diverId = ref.read(currentDiverIdProvider);
  if (diverId == null) return;
  final siteRepo = ref.read(siteRepositoryProvider);

  final privateCount = (await siteRepo.getAllSites(diverId: diverId))
      .where((s) => !s.isShared)
      .length;

  if (privateCount == 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.settings_shareAll_noneToShare)),
    );
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(
        context.l10n.settings_shareAllSites_confirm(privateCount),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Share'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  final count = await siteRepo.shareAllForDiver(diverId);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(context.l10n.settings_shareAllSites_snackbar(count))),
  );
}

Future<void> _confirmAndBulkShareTrips(
  BuildContext context,
  WidgetRef ref,
) async {
  final diverId = ref.read(currentDiverIdProvider);
  if (diverId == null) return;
  final tripRepo = ref.read(tripRepositoryProvider);

  final privateCount = (await tripRepo.getAllTrips(diverId: diverId))
      .where((t) => !t.isShared)
      .length;

  if (privateCount == 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.settings_shareAll_noneToShare)),
    );
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(
        context.l10n.settings_shareAllTrips_confirm(privateCount),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Share'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  final count = await tripRepo.shareAllForDiver(diverId);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(context.l10n.settings_shareAllTrips_snackbar(count))),
  );
}
```

Add any missing imports at the top of `settings_page.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
```

If `siteRepositoryProvider` or `tripRepositoryProvider` is named differently in the existing providers file, use the actual exported name (grep to confirm).

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/settings/presentation/pages/settings_page_shared_data_test.dart`
Expected: PASS.

- [ ] **Step 6: Regression-check the full settings test suite**

Run: `flutter test test/features/settings/`
Expected: All tests pass.

- [ ] **Step 7: Analyze**

Run: `flutter analyze lib/features/settings/`
Expected: No errors.

- [ ] **Step 8: Manual smoke test**

Run the app on macOS with 2+ divers seeded:

```bash
flutter run -d macos
```

Checklist:
- Open Settings → scroll to "Shared data". Section visible.
- Flip the "Share new sites and trips by default" switch. Close and re-open Settings; switch state persisted.
- Tap "Share all my sites" → confirmation dialog shows correct count → confirm → snackbar appears → switch active diver → sites previously owned by the first diver now appear in the second diver's list.
- Verify the same for trips.
- Delete one of the two divers (leaving a single diver). Open Settings — "Shared data" section is hidden.

- [ ] **Step 9: Format + commit**

Run: `dart format lib/ test/`
Expected: No changes if code was already formatted; otherwise commit the formatting.

```bash
git add lib/features/settings/presentation/pages/settings_page.dart \
  lib/features/settings/presentation/providers/settings_providers.dart \
  test/features/settings/presentation/pages/settings_page_shared_data_test.dart
git commit -m "feat(settings): add shared data section with default toggle and bulk-share actions"
```

---

## Post-implementation verification

Before declaring the feature complete, run the full project suite and smoke-test the flow end-to-end:

- [ ] Run the entire test suite: `flutter test`
      Expected: All tests pass.
- [ ] Run `dart format --set-exit-if-changed lib/ test/`
      Expected: No changes required.
- [ ] Run `flutter analyze`
      Expected: No errors or warnings introduced by this branch.
- [ ] Manual end-to-end check on macOS with two seeded dive profiles:
      - Create a trip + a site on diver A with "Share with all dive profiles" enabled. Switch to diver B — both visible.
      - Create a second trip + site on diver A with share disabled. Switch to diver B — not visible.
      - With share-by-default turned ON in Settings, open the trip create form — switch pre-checked.
      - Use "Share all my trips" with mixed private/already-shared records — snackbar reports the number newly shared (not the total).
      - Delete one of the two divers — sharing UI disappears from edit pages, list tiles, and the Settings section.

---

## Self-Review

The spec's decisions were cross-checked against the plan:

- **Schema v68→v69 migration with `is_shared` column on `trips` and `dive_sites`:** Task 1.
- **Domain entities carry `isShared`:** Tasks 2, 3.
- **Repositories persist `isShared`:** Tasks 4, 5.
- **`VisibilityFilter` helper with Drift + SQL entry points:** Task 6.
- **Visibility filter applied at all diver-scoped query sites:** Tasks 7 (trips: `getAllTrips`, `searchTrips`, `findTripForDate`, `getAllTripsWithStats`), 8 (sites: `getAllSites`, `searchSites`; `getSitesWithDiveCounts` delegates to `getAllSites` and inherits filtering).
- **`getById` methods remain unfiltered:** Honored — no changes to `getTripById` or `getSiteById`.
- **`setShared` + `shareAllForDiver` on both repositories, with sync-pending marks + transaction:** Tasks 9, 10.
- **`AppSettingsRepository` with `share_new_records_by_default` key, default `false`:** Task 11.
- **L10n strings for the toggle, settings section, and bulk-share confirm/snackbar:** Task 12 (English only; other locales follow in a separate i18n pass consistent with recent commits).
- **Trip edit page switch, default-from-settings, diver-count suppression:** Task 13.
- **Site edit page switch mirror:** Task 14.
- **Trip list shared icon with `Icons.people_outline`, hidden for single-diver:** Task 15.
- **Site list shared icon mirror:** Task 16.
- **Settings page "Shared data" section (default toggle + two bulk-share actions with confirm + snackbar, suppressed for single-diver):** Task 17.
- **Sync considerations (`is_shared` flows via Drift's generated `toJson`/`fromJson`, no serializer changes required):** Confirmed via grep of `sync_data_serializer.dart`, which uses `Trip.fromJson(data)` and `DiveSitesCompanion.insert` (both generated). No task needed.
- **Trip children (`itinerary`, `liveaboard`) inherit parent visibility:** No task needed — repos access children strictly via `tripId`, as validated in the spec's Architecture section.
- **Dives remain per-diver:** No change to any dive query; confirmed.

No placeholders remain. All type/method names are consistent between tasks (e.g., `shareAllForDiver` appears with the same signature across Tasks 9, 10, and 17; `VisibilityFilter.applyToTrips` / `applyToDiveSites` match between Task 6 and Tasks 7, 8). All commits end their respective task, matching the "frequent commits" rule.
