# Tank Pressure Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deprecate the legacy `DiveProfiles.pressure` column, fix multi-tank pressure loss on Shearwater import (#115), and standardize all pressure data through the `tank_pressure_profiles` table.

**Architecture:** Fix importers to write `allTankPressures` instead of single `pressure` (Phase 1), migrate existing data forward (Phase 2), update all consumers to read exclusively from `tank_pressure_profiles` (Phase 3), then remove the `pressure` field from `DiveProfilePoint` (Phase 4). Phases 3 and 4 are done together since removing the field forces all consumer updates via compile errors.

**Tech Stack:** Flutter/Dart, Drift ORM (SQLite), Riverpod, libdivecomputer FFI via Pigeon

**Branch:** `feature/tank-pressure-migration`

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `lib/features/universal_import/data/services/shearwater_dive_mapper.dart` | Modify | Build `allTankPressures` from FFI samples |
| `lib/core/services/export/uddf/uddf_import_service.dart` | Modify | Remove legacy `point['pressure']` write |
| `lib/core/services/export/uddf/uddf_full_import_service.dart` | Modify | Remove legacy `point['pressure']` write |
| `lib/features/dive_import/data/services/uddf_entity_importer.dart` | Modify | Remove `p['pressure']` from profile parsing, remove legacy fallback in `_storeTankPressures` |
| `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` | Modify | Stop writing legacy pressure column |
| `lib/core/database/database.dart` | Modify | Schema version 59, migration, deprecation comment |
| `lib/features/dive_log/domain/entities/dive.dart` | Modify | Remove `pressure` from `DiveProfilePoint` |
| `lib/features/dive_log/data/repositories/dive_repository_impl.dart` | Modify | Stop reading/writing legacy pressure |
| `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` | Modify | Remove legacy pressure path |
| `lib/features/dive_log/data/services/gas_analysis_service.dart` | Modify | Remove `p.pressure` fallback |
| `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart` | Modify | Remove legacy fallback |
| `lib/features/dive_log/data/services/profile_markers_service.dart` | Modify | Remove `_findPressureCrossingsFromProfile` legacy path |
| `lib/core/services/export/uddf/uddf_export_builders.dart` | Modify | Source pressure from tank pressure data |
| `lib/core/services/export/uddf/uddf_export_service.dart` | Modify | Source pressure from tank pressure data |
| `test/features/universal_import/data/services/shearwater_dive_mapper_profile_test.dart` | Modify | Update existing tests, add multi-tank test |

---

## Task 0: Create Feature Branch

**Files:** None (git operation only)

- [ ] **Step 1: Create and switch to feature branch**

```bash
git checkout -b feature/tank-pressure-migration
```

- [ ] **Step 2: Verify branch**

```bash
git branch --show-current
```

Expected: `feature/tank-pressure-migration`

---

## Task 1: Fix ShearwaterDiveMapper to Preserve Multi-Tank Pressure

**Files:**
- Modify: `test/features/universal_import/data/services/shearwater_dive_mapper_profile_test.dart`
- Modify: `lib/features/universal_import/data/services/shearwater_dive_mapper.dart`

- [ ] **Step 1: Write failing test for multi-tank pressure mapping**

Add this test to the `mergeWithParsedDive` group in `test/features/universal_import/data/services/shearwater_dive_mapper_profile_test.dart`:

```dart
test('builds allTankPressures from FFI samples with tank indices', () {
  final baseMap = <String, dynamic>{'profile': <Map<String, dynamic>>[]};
  final parsed = pigeon.ParsedDive(
    fingerprint: '',
    dateTimeYear: 2025,
    dateTimeMonth: 1,
    dateTimeDay: 1,
    dateTimeHour: 0,
    dateTimeMinute: 0,
    dateTimeSecond: 0,
    maxDepthMeters: 20,
    avgDepthMeters: 10,
    durationSeconds: 600,
    samples: [
      // Tank 0 at t=10
      pigeon.ProfileSample(
        timeSeconds: 10,
        depthMeters: 5.0,
        pressureBar: 200.0,
        tankIndex: 0,
      ),
      // Tank 1 at t=10
      pigeon.ProfileSample(
        timeSeconds: 10,
        depthMeters: 5.0,
        pressureBar: 190.0,
        tankIndex: 1,
      ),
      // Tank 0 at t=20
      pigeon.ProfileSample(
        timeSeconds: 20,
        depthMeters: 10.0,
        pressureBar: 195.0,
        tankIndex: 0,
      ),
      // Tank 1 at t=20
      pigeon.ProfileSample(
        timeSeconds: 20,
        depthMeters: 10.0,
        pressureBar: 185.0,
        tankIndex: 1,
      ),
      // Sample with no pressure (no allTankPressures expected)
      pigeon.ProfileSample(timeSeconds: 30, depthMeters: 12.0),
    ],
    tanks: [],
    gasMixes: [],
    events: [],
  );
  final result = ShearwaterDiveMapper.mergeWithParsedDive(
    baseMap,
    parsed,
  );
  final profile = result['profile'] as List;
  expect(profile, hasLength(5));

  // Sample with tank 0 pressure
  final s1 = profile[0] as Map<String, dynamic>;
  expect(s1.containsKey('pressure'), isFalse);
  final s1Pressures =
      s1['allTankPressures'] as List<Map<String, dynamic>>;
  expect(s1Pressures, hasLength(1));
  expect(s1Pressures[0]['pressure'], 200.0);
  expect(s1Pressures[0]['tankIndex'], 0);

  // Sample with tank 1 pressure
  final s2 = profile[1] as Map<String, dynamic>;
  expect(s2.containsKey('pressure'), isFalse);
  final s2Pressures =
      s2['allTankPressures'] as List<Map<String, dynamic>>;
  expect(s2Pressures, hasLength(1));
  expect(s2Pressures[0]['pressure'], 190.0);
  expect(s2Pressures[0]['tankIndex'], 1);

  // Sample with no pressure has no allTankPressures key
  final s5 = profile[4] as Map<String, dynamic>;
  expect(s5.containsKey('allTankPressures'), isFalse);
  expect(s5.containsKey('pressure'), isFalse);
});

test('defaults tankIndex to 0 when FFI sample has null tankIndex', () {
  final baseMap = <String, dynamic>{'profile': <Map<String, dynamic>>[]};
  final parsed = pigeon.ParsedDive(
    fingerprint: '',
    dateTimeYear: 2025,
    dateTimeMonth: 1,
    dateTimeDay: 1,
    dateTimeHour: 0,
    dateTimeMinute: 0,
    dateTimeSecond: 0,
    maxDepthMeters: 20,
    avgDepthMeters: 10,
    durationSeconds: 600,
    samples: [
      pigeon.ProfileSample(
        timeSeconds: 10,
        depthMeters: 5.0,
        pressureBar: 200.0,
        // tankIndex is null
      ),
    ],
    tanks: [],
    gasMixes: [],
    events: [],
  );
  final result = ShearwaterDiveMapper.mergeWithParsedDive(
    baseMap,
    parsed,
  );
  final profile = result['profile'] as List;
  final s1 = profile[0] as Map<String, dynamic>;
  final s1Pressures =
      s1['allTankPressures'] as List<Map<String, dynamic>>;
  expect(s1Pressures[0]['tankIndex'], 0);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/universal_import/data/services/shearwater_dive_mapper_profile_test.dart`

Expected: FAIL — tests expect `allTankPressures` but mapper writes `pressure`.

- [ ] **Step 3: Update ShearwaterDiveMapper to build allTankPressures**

In `lib/features/universal_import/data/services/shearwater_dive_mapper.dart`, replace the pressure mapping in `mergeWithParsedDive()` (lines 381-383):

Replace:
```dart
      if (s.pressureBar != null) {
        sampleMap['pressure'] = s.pressureBar;
      }
```

With:
```dart
      if (s.pressureBar != null) {
        sampleMap['allTankPressures'] = <Map<String, dynamic>>[
          {'pressure': s.pressureBar, 'tankIndex': s.tankIndex ?? 0},
        ];
      }
```

- [ ] **Step 4: Update existing test that expects `pressure` key**

In `test/features/universal_import/data/services/shearwater_dive_mapper_profile_test.dart`, the test `'builds profile samples with all sensor data'` (around line 288) currently asserts:

```dart
expect(s1['pressure'], 200.0);
```

and (around line 304):

```dart
expect(s2.containsKey('pressure'), isFalse);
```

Replace the `s1['pressure']` assertion with:

```dart
expect(s1.containsKey('pressure'), isFalse);
final s1Pressures =
    s1['allTankPressures'] as List<Map<String, dynamic>>;
expect(s1Pressures[0]['pressure'], 200.0);
expect(s1Pressures[0]['tankIndex'], 0);
```

The `s2` assertion for `pressure` being absent stays the same. Add:

```dart
expect(s2.containsKey('allTankPressures'), isFalse);
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/universal_import/data/services/shearwater_dive_mapper_profile_test.dart`

Expected: ALL PASS

- [ ] **Step 6: Commit**

```bash
git add lib/features/universal_import/data/services/shearwater_dive_mapper.dart test/features/universal_import/data/services/shearwater_dive_mapper_profile_test.dart
git commit -m "feat(import): build allTankPressures from FFI samples in ShearwaterDiveMapper

Fixes #115 — sidemount dives with two AI transmitters now preserve
both tanks' pressure curves instead of silently dropping the second."
```

---

## Task 2: Remove Legacy Pressure Writes from UDDF Import Services

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_import_service.dart`
- Modify: `lib/core/services/export/uddf/uddf_full_import_service.dart`

- [ ] **Step 1: Remove legacy backward-compat pressure write from uddf_import_service.dart**

In `lib/core/services/export/uddf/uddf_import_service.dart`, remove lines 625-629 (the legacy fallback block):

```dart
            // Store first tank's pressure in legacy fields for backward compatibility
            if (!point.containsKey('pressure')) {
              point['pressure'] = pressure;
              point['tankIndex'] = tankIdx;
            }
```

- [ ] **Step 2: Remove legacy backward-compat pressure write from uddf_full_import_service.dart**

In `lib/core/services/export/uddf/uddf_full_import_service.dart`, remove lines 1520-1524 (identical block):

```dart
            // Store first tank's pressure in legacy fields for backward compatibility
            if (!point.containsKey('pressure')) {
              point['pressure'] = pressure;
              point['tankIndex'] = tankIdx;
            }
```

- [ ] **Step 3: Run existing UDDF import tests**

Run: `flutter test test/core/services/export/uddf/`

Expected: ALL PASS (tests should not depend on the legacy `pressure` key being present)

- [ ] **Step 4: Commit**

```bash
git add lib/core/services/export/uddf/uddf_import_service.dart lib/core/services/export/uddf/uddf_full_import_service.dart
git commit -m "refactor(import): stop writing legacy pressure field in UDDF importers

allTankPressures is the sole pressure output. The legacy point['pressure']
backward-compat write is no longer needed."
```

---

## Task 3: Remove Legacy Fallback from UddfEntityImporter._storeTankPressures

**Files:**
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart`

- [ ] **Step 1: Remove the legacy single-pressure fallback in _storeTankPressures**

In `lib/features/dive_import/data/services/uddf_entity_importer.dart`, in the `_storeTankPressures` method (lines 1378-1422), remove the `else` block (lines 1405-1416) that handles legacy single `pressure` field:

Replace the entire loop body (lines 1390-1416):

```dart
      // Check for multi-tank pressure data first
      final allTankPressures =
          p['allTankPressures'] as List<Map<String, dynamic>>?;
      if (allTankPressures != null && allTankPressures.isNotEmpty) {
        for (final tp in allTankPressures) {
          final pressure = tp['pressure'] as double?;
          final tankIdx = tp['tankIndex'] as int? ?? 0;
          if (pressure != null && tankIdx >= 0 && tankIdx < tanks.length) {
            final tankId = tanks[tankIdx].id;
            pressuresByTank.putIfAbsent(tankId, () => []).add((
              timestamp: timestamp,
              pressure: pressure,
            ));
          }
        }
      } else {
        // Legacy single pressure field
        final pressure = p['pressure'] as double?;
        final tankIdx = (p['tankIndex'] as int?) ?? 0;
        if (pressure != null && tankIdx >= 0 && tankIdx < tanks.length) {
          final tankId = tanks[tankIdx].id;
          pressuresByTank.putIfAbsent(tankId, () => []).add((
            timestamp: timestamp,
            pressure: pressure,
          ));
        }
      }
```

With (remove the else branch and simplify):

```dart
      final allTankPressures =
          p['allTankPressures'] as List<Map<String, dynamic>>?;
      if (allTankPressures != null && allTankPressures.isNotEmpty) {
        for (final tp in allTankPressures) {
          final pressure = tp['pressure'] as double?;
          final tankIdx = tp['tankIndex'] as int? ?? 0;
          if (pressure != null && tankIdx >= 0 && tankIdx < tanks.length) {
            final tankId = tanks[tankIdx].id;
            pressuresByTank.putIfAbsent(tankId, () => []).add((
              timestamp: timestamp,
              pressure: pressure,
            ));
          }
        }
      }
```

- [ ] **Step 2: Remove pressure from profile parsing in import method**

In the same file, in the profile parsing block (lines 970-981), remove the `pressure` parameter:

Replace:
```dart
      final profile =
          profileData
              ?.map(
                (p) => DiveProfilePoint(
                  timestamp: p['timestamp'] as int? ?? 0,
                  depth: p['depth'] as double? ?? 0.0,
                  temperature: p['temperature'] as double?,
                  pressure: p['pressure'] as double?,
                  setpoint: p['setpoint'] as double?,
                  ppO2: p['ppO2'] as double?,
                ),
              )
              .toList() ??
          [];
```

With:
```dart
      final profile =
          profileData
              ?.map(
                (p) => DiveProfilePoint(
                  timestamp: p['timestamp'] as int? ?? 0,
                  depth: p['depth'] as double? ?? 0.0,
                  temperature: p['temperature'] as double?,
                  setpoint: p['setpoint'] as double?,
                  ppO2: p['ppO2'] as double?,
                ),
              )
              .toList() ??
          [];
```

Note: This step will cause a compile error until Task 7 removes `pressure` from `DiveProfilePoint`. If you are implementing sequentially, defer this edit to Task 7 and only do Step 1 now.

- [ ] **Step 3: Run import tests**

Run: `flutter test test/features/dive_import/`

Expected: ALL PASS

- [ ] **Step 4: Commit**

```bash
git add lib/features/dive_import/data/services/uddf_entity_importer.dart
git commit -m "refactor(import): remove legacy pressure fallback from _storeTankPressures

Only allTankPressures is consumed. The legacy single-pressure fallback
branch is no longer needed since all importers now produce allTankPressures."
```

---

## Task 4: Stop Writing Legacy Pressure in Dive Computer Repository

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart`

- [ ] **Step 1: Remove legacy pressure write from profile insert**

In `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart`, in the batch insert block (around line 968-974), replace:

```dart
              // Store primary tank pressure for legacy compatibility
              pressure: Value(
                point.tankIndex == 0 || point.tankIndex == null
                    ? point.pressure
                    : null,
              ),
```

With:

```dart
              pressure: const Value(null),
```

- [ ] **Step 2: Run dive computer tests**

Run: `flutter test test/features/dive_log/data/repositories/`

Expected: ALL PASS

- [ ] **Step 3: Commit**

```bash
git add lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart
git commit -m "refactor(import): stop writing legacy pressure column from dive computer path

Pressure data flows exclusively through tank_pressure_profiles table.
The per-tank grouping and insertion (lines 1037-1074) is already correct."
```

---

## Task 5: Database Migration — Backfill Legacy Pressure Data

**Files:**
- Modify: `lib/core/database/database.dart`

- [ ] **Step 1: Bump schema version**

In `lib/core/database/database.dart`, change line 1256:

```dart
  static const int currentSchemaVersion = 58;
```

To:

```dart
  static const int currentSchemaVersion = 59;
```

- [ ] **Step 2: Add deprecation comment to pressure column**

On line 258, change:

```dart
  RealColumn get pressure => real().nullable()(); // bar
```

To:

```dart
  // Deprecated: use tank_pressure_profiles table. Column retained for schema compat.
  RealColumn get pressure => real().nullable()();
```

- [ ] **Step 3: Add migration block**

Add the following migration block after the `if (from < 58)` block (which ends around line 2523). Find the closing `}` of the last migration and add before the closing of `onUpgrade`:

```dart
        if (from < 59) {
          // Migrate legacy dive_profiles.pressure data into tank_pressure_profiles.
          // For each dive that has pressure data in dive_profiles but NO existing
          // rows in tank_pressure_profiles, copy the pressure points into
          // tank_pressure_profiles associated with the dive's first tank.
          final divesWithLegacyPressure = await customSelect('''
            SELECT DISTINCT dp.dive_id
            FROM dive_profiles dp
            WHERE dp.pressure IS NOT NULL
              AND dp.is_primary = 1
              AND NOT EXISTS (
                SELECT 1 FROM tank_pressure_profiles tpp
                WHERE tpp.dive_id = dp.dive_id
              )
          ''').get();

          for (final row in divesWithLegacyPressure) {
            final diveId = row.read<String>('dive_id');

            // Get the first tank for this dive (lowest rowid)
            final tankRows = await customSelect('''
              SELECT id FROM dive_tanks
              WHERE dive_id = ?
              ORDER BY rowid ASC
              LIMIT 1
            ''', variables: [Variable(diveId)]).get();

            if (tankRows.isEmpty) continue;
            final tankId = tankRows.first.read<String>('id');

            // Copy pressure points into tank_pressure_profiles
            // Use hex(randomblob(16)) for UUID generation in SQLite
            await customStatement('''
              INSERT INTO tank_pressure_profiles (id, dive_id, tank_id, timestamp, pressure)
              SELECT
                lower(hex(randomblob(4)) || '-' || hex(randomblob(2)) || '-4' ||
                  substr(hex(randomblob(2)),2) || '-' ||
                  substr('89ab', abs(random()) % 4 + 1, 1) ||
                  substr(hex(randomblob(2)),2) || '-' ||
                  hex(randomblob(6))),
                ?,
                ?,
                dp.timestamp,
                dp.pressure
              FROM dive_profiles dp
              WHERE dp.dive_id = ?
                AND dp.pressure IS NOT NULL
                AND dp.is_primary = 1
            ''', variables: [Variable(diveId), Variable(tankId), Variable(diveId)]);
          }
        }
```

- [ ] **Step 4: Run codegen to update generated schema**

Run: `dart run build_runner build --delete-conflicting-outputs`

Expected: Build completes successfully.

- [ ] **Step 5: Run full test suite**

Run: `flutter test`

Expected: ALL PASS (or pre-existing failures only, not related to this change)

- [ ] **Step 6: Commit**

```bash
git add lib/core/database/database.dart lib/core/database/database.g.dart
git commit -m "feat(db): migrate legacy pressure data to tank_pressure_profiles (schema v59)

Backfills existing dive_profiles.pressure data into tank_pressure_profiles,
associated with each dive's first tank. Skips dives that already have
tank pressure data or have no tanks."
```

---

## Task 6: Stop Reading/Writing Legacy Pressure in Dive Repository

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart`

- [ ] **Step 1: Remove pressure mapping when reading profiles**

In `lib/features/dive_log/data/repositories/dive_repository_impl.dart`, find all three places where `DiveProfilePoint` is constructed from DB rows and remove the `pressure` parameter:

**Location 1** (~line 233): In `getProfile()`:
```dart
              (p) => domain.DiveProfilePoint(
                timestamp: p.timestamp,
                depth: p.depth,
                pressure: p.pressure,  // REMOVE THIS LINE
```

**Location 2** (~line 381): In `getProfilesBySource()`:
```dart
              domain.DiveProfilePoint(
                timestamp: row.timestamp,
                depth: row.depth,
                pressure: row.pressure,  // REMOVE THIS LINE
```

**Location 3** (~line 2477): In the dive loading method:
```dart
            (p) => domain.DiveProfilePoint(
              timestamp: p.timestamp,
              depth: p.depth,
              pressure: p.pressure,  // REMOVE THIS LINE
```

- [ ] **Step 2: Stop writing pressure when inserting profiles**

**Location 1** (~line 287): In `saveEditedProfile()`:

Remove:
```dart
                pressure: Value(point.pressure),
```

Replace with:
```dart
                pressure: const Value(null),
```

**Location 2** (~line 704): In `createDive()`:

Remove:
```dart
              pressure: Value(point.pressure),
```

Replace with:
```dart
              pressure: const Value(null),
```

Note: These edits will cause compile errors until Task 7 removes `pressure` from `DiveProfilePoint`. If implementing sequentially, do Task 7 first or do these together.

- [ ] **Step 3: Run repository tests**

Run: `flutter test test/features/dive_log/data/repositories/`

Expected: ALL PASS

- [ ] **Step 4: Commit**

```bash
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart
git commit -m "refactor(repo): stop reading/writing legacy pressure in dive repository

Pressure data is now exclusively sourced from tank_pressure_profiles."
```

---

## Task 7: Remove pressure from DiveProfilePoint Entity

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive.dart`

This is the "break the world" step that forces all remaining consumers to update via compile errors.

- [ ] **Step 1: Remove pressure field from DiveProfilePoint**

In `lib/features/dive_log/domain/entities/dive.dart`, make these changes to `DiveProfilePoint`:

Remove field (line 720):
```dart
  final double? pressure; // bar
```

Remove from constructor (line 740):
```dart
    this.pressure,
```

Remove from `copyWith` parameter list (line 758):
```dart
    double? pressure,
```

Remove from `copyWith` body (line 775):
```dart
      pressure: pressure ?? this.pressure,
```

Remove from `props` list (line 795):
```dart
    pressure,
```

- [ ] **Step 2: Run analyzer to find all broken references**

Run: `flutter analyze 2>&1 | grep "pressure"`

Expected: List of compile errors in consumer files — this is the roadmap for remaining fixes.

- [ ] **Step 3: Commit**

```bash
git add lib/features/dive_log/domain/entities/dive.dart
git commit -m "refactor(entity): remove pressure field from DiveProfilePoint

TankPressurePoint is now the sole representation of pressure data.
Consumers will be updated in subsequent commits."
```

---

## Task 8: Update Gas Analysis Service

**Files:**
- Modify: `lib/features/dive_log/data/services/gas_analysis_service.dart`

- [ ] **Step 1: Remove legacy pressure fallback in _calculateSegmentSac**

In `lib/features/dive_log/data/services/gas_analysis_service.dart`, in `_calculateSegmentSac()` (around lines 549-557), remove the fallback block:

```dart
    // Fallback to profile pressure data
    if (pressureUsed == null) {
      final pressurePoints = profile.where((p) => p.pressure != null).toList();
      if (pressurePoints.length >= 2) {
        final startPressure = pressurePoints.first.pressure!;
        final endPressure = pressurePoints.last.pressure!;
        pressureUsed = startPressure - endPressure;
      }
    }
```

Delete those lines entirely. The method already tries time-series pressure data first (lines 539-547) and falls back to tank start/end pressure (lines 561-570).

- [ ] **Step 2: Run gas analysis tests**

Run: `flutter test test/features/dive_log/data/services/gas_analysis_service_test.dart`

Expected: ALL PASS

- [ ] **Step 3: Commit**

```bash
git add lib/features/dive_log/data/services/gas_analysis_service.dart
git commit -m "refactor(analysis): remove legacy p.pressure fallback from SAC calculation

SAC calculation now uses tank_pressure_profiles time-series data or
tank start/end pressure estimation. The legacy profile pressure
fallback is no longer needed."
```

---

## Task 9: Update Profile Analysis Provider

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart`

- [ ] **Step 1: Remove legacy pressure fallback**

In `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart`, remove the fallback block (lines 422-431):

```dart
    // Fall back to single pressure from profile if no multi-tank data
    if (pressures == null || pressures.length != depths.length) {
      final singlePressures = dive.profile
          .where((p) => p.pressure != null)
          .map((p) => p.pressure!)
          .toList();
      if (singlePressures.length == depths.length) {
        pressures = singlePressures;
      }
    }
```

Delete those lines entirely. After the migration, all pressure data lives in `tank_pressure_profiles` and is loaded via `_combineMultiTankPressures()`.

- [ ] **Step 2: Run provider tests**

Run: `flutter test test/features/dive_log/presentation/providers/`

Expected: ALL PASS

- [ ] **Step 3: Commit**

```bash
git add lib/features/dive_log/presentation/providers/profile_analysis_provider.dart
git commit -m "refactor(analysis): remove legacy pressure fallback in profile analysis provider

_combineMultiTankPressures() is now the sole path for loading
pressure data into SAC curve calculation."
```

---

## Task 10: Update Profile Markers Service

**Files:**
- Modify: `lib/features/dive_log/data/services/profile_markers_service.dart`

- [ ] **Step 1: Remove legacy pressure detection and fallback path**

In `lib/features/dive_log/data/services/profile_markers_service.dart`, in `getPressureThresholdMarkers()`:

Replace the logic block (lines 155-213) with a simplified version that only uses tank pressure data:

```dart
    if (tanksWithPressure.isEmpty || profile.isEmpty) {
      return markers;
    }

    final hasMultiTankData = tankPressures != null && tankPressures.isNotEmpty;

    if (!hasMultiTankData) {
      // No time-series pressure data - estimate based on linear consumption
      return _estimatePressureMarkersLinear(profile, tanksWithPressure);
    }

    for (var tankIndex = 0; tankIndex < tanksWithPressure.length; tankIndex++) {
      final tank = tanksWithPressure[tankIndex];
      final startPressure = tank.startPressure!;

      // Calculate threshold values
      final thresholds = {
        ProfileMarkerType.pressureTwoThirds: startPressure * (2 / 3),
        ProfileMarkerType.pressureHalf: startPressure * 0.5,
        ProfileMarkerType.pressureOneThird: startPressure * (1 / 3),
      };

      if (tankPressures.containsKey(tank.id)) {
        final tankPressurePoints = tankPressures[tank.id]!;
        markers.addAll(
          _findPressureCrossingsFromTankData(
            profile: profile,
            tankPressurePoints: tankPressurePoints,
            thresholds: thresholds,
            tank: tank,
            tankIndex: tankIndex,
          ),
        );
      } else {
        // Estimate for tanks without time-series data
        markers.addAll(
          _estimatePressureCrossings(
            profile: profile,
            tank: tank,
            tankIndex: tankIndex,
            thresholds: thresholds,
          ),
        );
      }
    }

    return markers;
```

- [ ] **Step 2: Remove the `_findPressureCrossingsFromProfile` method**

Delete the entire `_findPressureCrossingsFromProfile` static method (lines 287-330 approximately). It references `point.pressure` which no longer exists.

- [ ] **Step 3: Run profile markers tests**

Run: `flutter test test/features/dive_log/data/services/profile_markers_service_test.dart`

Expected: ALL PASS

- [ ] **Step 4: Commit**

```bash
git add lib/features/dive_log/data/services/profile_markers_service.dart
git commit -m "refactor(markers): remove legacy pressure fallback from pressure threshold markers

Pressure markers now use exclusively tank_pressure_profiles data
or linear estimation from tank start/end pressures."
```

---

## Task 11: Update Profile Chart

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`

- [ ] **Step 1: Remove legacy pressure detection and the `_buildPressureLine` method**

In `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`:

**a)** Remove the `hasPressureData` variable (lines 456-457):

```dart
    final hasPressureData =
        widget.profile.any((p) => p.pressure != null) && !_tankPressuresPending;
```

**b)** Remove `_tankPressuresPending` usage — search for all references and remove them. The getter itself (lines 258-261) can be deleted.

**c)** Remove the legacy pressure bounds calculation (lines 795-802):

```dart
    if (_showPressure && hasPressureData) {
      final pressures = widget.profile
          .where((p) => p.pressure != null)
          .map((p) => p.pressure!);
      if (pressures.isNotEmpty) {
        minPressure = pressures.reduce(math.min) - 10;
        maxPressure = pressures.reduce(math.max) + 10;
      }
    }
```

**d)** In the line chart data builder (around line 1016-1027), remove the `else` branch that calls `_buildPressureLine`:

Replace:
```dart
              if (_hasMultiTankPressure)
                ..._buildMultiTankPressureLines(totalMaxDepth)
              else if (_showPressure &&
                  hasPressureData &&
                  minPressure != null &&
                  maxPressure != null)
                _buildPressureLine(
                  pressureColor,
                  totalMaxDepth,
                  minPressure,
                  maxPressure,
                ),
```

With:
```dart
              if (_hasMultiTankPressure)
                ..._buildMultiTankPressureLines(totalMaxDepth),
```

**e)** Remove the tooltip legacy pressure row (around lines 1265-1272):

```dart
                    if (_showPressure &&
                        !_hasMultiTankPressure &&
                        !_tankPressuresPending) {
                      final pressValue = point.pressure != null
                          ? units.formatPressure(point.pressure)
                          : '—';
```

Remove this entire block (it accesses `point.pressure`).

**f)** Delete the `_buildPressureLine` method entirely (lines 2042-2071).

- [ ] **Step 2: Run the analyzer to confirm no remaining `p.pressure` references**

Run: `flutter analyze lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`

Expected: No errors related to `pressure` on `DiveProfilePoint`.

- [ ] **Step 3: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_profile_chart.dart
git commit -m "refactor(chart): remove legacy single-pressure line from dive profile chart

Pressure visualization now exclusively uses the multi-tank pressure path
from tank_pressure_profiles. Legacy _buildPressureLine and
_tankPressuresPending are removed."
```

---

## Task 12: Update UDDF Export to Source Pressure from Tank Pressure Data

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart`
- Modify: `lib/core/services/export/uddf/uddf_export_service.dart`

- [ ] **Step 1: Update UddfExportBuilders.buildDiveElement**

In `lib/core/services/export/uddf/uddf_export_builders.dart`, add a `Map<String, List<TankPressurePoint>>?` parameter to `buildDiveElement`:

Change the method signature (line 93):

```dart
  static void buildDiveElement(
    XmlBuilder builder,
    Dive dive,
    List<Buddy>? buddies,
    List<BuddyWithRole> diveBuddyList,
    List<Tag> diveTags,
    List<ProfileEvent> profileEvents,
    List<DiveWeight> diveWeights,
    List<Trip>? trips,
    List<GasSwitchWithTank> gasSwitches,
    Map<String, List<TankPressurePoint>>? tankPressures,
  ) {
```

Add the import at the top of the file if not already present:
```dart
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
```

Then replace the `point.pressure` block (lines 325-330):

```dart
                    if (point.pressure != null) {
                      builder.element(
                        'tankpressure',
                        nest: (point.pressure! * 100000).toString(),
                      );
                    }
```

With:

```dart
                    if (tankPressures != null) {
                      for (final entry in tankPressures.entries) {
                        final pressure = _findPressureAtTimestamp(
                          entry.value,
                          point.timestamp,
                        );
                        if (pressure != null) {
                          builder.element(
                            'tankpressure',
                            nest: (pressure * 100000).toString(),
                          );
                        }
                      }
                    }
```

Add this helper method to `UddfExportBuilders`:

```dart
  static double? _findPressureAtTimestamp(
    List<TankPressurePoint> points,
    int timestamp,
  ) {
    if (points.isEmpty) return null;
    // Find the closest point within 2 seconds
    TankPressurePoint? closest;
    int minDiff = 3; // max 2 second tolerance
    for (final p in points) {
      final diff = (p.timestamp - timestamp).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = p;
      }
    }
    return closest?.pressure;
  }
```

- [ ] **Step 2: Update UddfExportService**

In `lib/core/services/export/uddf/uddf_export_service.dart`, replace the `point.pressure` block (lines 287-293):

```dart
                                    if (point.pressure != null) {
                                      builder.element(
                                        'tankpressure',
                                        nest: (point.pressure! * 100000)
                                            .toString(),
                                      ); // Pascal
                                    }
```

With the same tank pressure lookup pattern. However, since this simple export service doesn't have access to tank pressure data, add a `Map<String, Map<String, List<TankPressurePoint>>>?` parameter to `exportDivesToUddf` (keyed by dive ID, then by tank ID), or simply remove the pressure export from this simplified service since it operates without a database connection.

The simplest approach: remove the `point.pressure` block entirely from `UddfExportService` since this is the simple/quick export path that doesn't have tank pressure data available:

```dart
                                    // Tank pressure exported via UddfExportBuilders
                                    // which has access to tank_pressure_profiles data
```

- [ ] **Step 3: Update all callers of buildDiveElement to pass tankPressures**

Search for callers:

Run: `grep -rn "buildDiveElement" lib/`

Update each call site to pass the tank pressure data (or `null` if not available).

- [ ] **Step 4: Run export tests**

Run: `flutter test test/core/services/export/`

Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/export/uddf/uddf_export_builders.dart lib/core/services/export/uddf/uddf_export_service.dart
git commit -m "refactor(export): source UDDF tankpressure from tank_pressure_profiles

Export no longer reads point.pressure from DiveProfilePoint. Instead,
UddfExportBuilders accepts tank pressure data and looks up pressure
at each waypoint's timestamp."
```

---

## Task 13: Fix Remaining Compile Errors and Run Full Analysis

**Files:**
- Potentially any file still referencing `DiveProfilePoint.pressure`

- [ ] **Step 1: Run analyzer to find any remaining references**

Run: `flutter analyze 2>&1 | head -50`

Expected: Check for any remaining references to `.pressure` on `DiveProfilePoint`.

- [ ] **Step 2: Fix any remaining references**

For each remaining compile error referencing `point.pressure` or `p.pressure` on a `DiveProfilePoint`, remove or replace with tank pressure data access.

- [ ] **Step 3: Format all code**

Run: `dart format lib/ test/`

- [ ] **Step 4: Run full test suite**

Run: `flutter test`

Expected: ALL PASS

- [ ] **Step 5: Run analyzer**

Run: `flutter analyze`

Expected: No errors

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: fix remaining compile errors from pressure field removal

All consumers now exclusively use tank_pressure_profiles data."
```

---

## Task 14: Final Verification

- [ ] **Step 1: Run full test suite one more time**

Run: `flutter test`

Expected: ALL PASS

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze`

Expected: No errors

- [ ] **Step 3: Verify no remaining references to legacy pressure on profile points**

Run: `grep -rn "p\.pressure\|point\.pressure" lib/ --include="*.dart" | grep -v "tank_pressure\|TankPressure\|startPressure\|endPressure\|workingPressure\|surfacePressure\|atmosphericpressure\|tankpressure\|pressure =\|\.pressure =" | grep -v "database\.dart\|database\.g\.dart\|downloaded_dive\.dart"`

Expected: No matches (or only false positives from unrelated `pressure` fields like `surfacePressure`).

- [ ] **Step 4: Format check**

Run: `dart format --set-exit-if-changed lib/ test/`

Expected: Exit code 0 (no formatting needed)
