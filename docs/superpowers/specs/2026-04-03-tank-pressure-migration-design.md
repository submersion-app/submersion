# Tank Pressure Migration: Deprecate Legacy `p.pressure` in Favor of `tank_pressure_profiles`

**Date:** 2026-04-03
**Issue:** [#115](https://github.com/submersion-app/submersion/issues/115)
**Approach:** Import-first, then consolidate

## Problem

The codebase has two parallel systems for storing dive pressure data:

1. **Legacy:** `DiveProfiles.pressure` -- a nullable column storing a single pressure value per profile sample. No tank association.
2. **Modern:** `TankPressureProfiles` table -- stores pressure keyed by `(diveId, tankId, timestamp)`, enabling multi-tank support.

This dual storage causes two problems:

- **Data loss on import (issue #115):** `ShearwaterDiveMapper.mergeWithParsedDive` writes `sampleMap['pressure'] = s.pressureBar` with no `tankIndex`, so for multi-transmitter dives (e.g., sidemount with two AI pods), the second tank's pressure curve is silently dropped. The FFI layer already provides per-sample `tankIndex` -- the mapper just discards it.
- **Unnecessary consumer complexity:** Every pressure consumer (chart, SAC calculation, markers) has dual-path code: check `tank_pressure_profiles` first, fall back to legacy `p.pressure`.

## Decisions

| Decision | Choice |
|----------|--------|
| Migration strategy | Migrate existing legacy data forward into `tank_pressure_profiles` |
| Entity field | Remove `pressure` from `DiveProfilePoint` entirely (clean break) |
| Approach ordering | Fix importers first (addresses #115), then backfill, then clean up consumers |

## Import Path Analysis

Three distinct import paths exist:

| Path | Current behavior | Change needed |
|------|-----------------|---------------|
| UDDF import | Builds `allTankPressures` array, inserts into `tank_pressure_profiles`. Also writes legacy `point['pressure']` for backward compat. | Stop writing legacy `point['pressure']` |
| Shearwater Cloud import | Mapper writes single `sampleMap['pressure']`, drops `tankIndex`. Flows through `UddfEntityImporter._storeTankPressures()`. | Build `allTankPressures` from FFI samples using `s.pressureBar` + `s.tankIndex` |
| Dive computer BLE | `DiveComputerRepositoryImpl` groups by `tankIndex`, inserts into `tank_pressure_profiles` directly. | Stop writing to legacy `DiveProfiles.pressure` column |

## Design

### Phase 1: Fix Importers

#### ShearwaterDiveMapper

In `mergeWithParsedDive()`, replace single pressure write with `allTankPressures`:

```dart
// Before:
if (s.pressureBar != null) {
  sampleMap['pressure'] = s.pressureBar;
}

// After:
if (s.pressureBar != null) {
  final tankIdx = s.tankIndex ?? 0;
  sampleMap['allTankPressures'] = [
    {'pressure': s.pressureBar, 'tankIndex': tankIdx},
  ];
}
```

Each FFI `ProfileSample` carries one tank's pressure per timestamp. The downstream `UddfEntityImporter._storeTankPressures()` already aggregates `allTankPressures` entries across samples and inserts into `tank_pressure_profiles`.

Stop writing `sampleMap['pressure']` entirely.

#### UDDF Import Services

In `uddf_import_service.dart` (~line 627) and `uddf_full_import_service.dart` (~line 1522), stop writing `point['pressure']` for backward compatibility. Only `allTankPressures` is written.

#### UddfEntityImporter Profile Parsing

In the profile parsing block (~line 970), stop reading `p['pressure']` into `DiveProfilePoint.pressure`.

#### Dive Computer BLE Path

In `dive_computer_repository_impl.dart`, stop writing to the `DiveProfiles.pressure` column. The existing tank pressure insertion (grouping by `tankIndex` into `tank_pressure_profiles`) is already correct.

### Phase 2: Database Migration

New Drift schema version. Migration runs in Dart (not raw SQL) for UUID generation.

**Steps:**

1. Query for `diveId`s that have at least one non-null `pressure` in `dive_profiles` AND no existing rows in `tank_pressure_profiles`.
2. For each candidate dive, look up the first `dive_tank` by lowest `rowid` (SQLite insertion order). Associate all legacy pressure points with that tank -- matches existing implicit "tank 0" behavior.
3. Batch insert one `tank_pressure_profiles` row per non-null pressure point: `(uuid, diveId, tankId, timestamp, pressure)`.

**Edge cases:**

| Case | Handling |
|------|----------|
| Dive already has `tank_pressure_profiles` rows | Skip -- already migrated or correctly imported |
| Dive has pressure data but no `dive_tanks` | Skip -- no valid tank to associate with |
| Dive has multiple tanks but legacy pressure | Associate with first tank (matches existing implicit behavior) |
| Dive has null pressure for all profile points | No-op |

**Column retention:** The `DiveProfiles.pressure` column stays in the DB schema (Drift does not support `DROP COLUMN`). After migration, it is never read or written.

### Phase 3: Consumer Updates

Every consumer that reads `p.pressure` from `DiveProfilePoint` switches to `TankPressurePoint` data from `tank_pressure_profiles`.

#### Profile Chart (`dive_profile_chart.dart`)

- Remove legacy single-pressure line drawing (~line 2050)
- Remove `p.pressure != null` checks (~lines 457, 797)
- Remove `_tankPressuresPending` suppression logic
- Keep only the multi-tank pressure visualization path (~lines 2073-2100)
- Min/max bounds from tank pressure data only

#### Gas Analysis Service (`gas_analysis_service.dart`)

- Accept `Map<String, List<TankPressurePoint>>` instead of relying on profile pressure
- Pressure interpolation sourced from `TankPressurePoint` data
- Single-tank: use sole tank's curve. Multi-tank: each tank's curve is already separate.

#### Profile Analysis Provider (`profile_analysis_provider.dart`)

- Remove fallback at ~line 424 that extracts `p.pressure` when no multi-tank data exists
- `_combineMultiTankPressures()` becomes the sole path

#### Pressure Markers Service (`profile_markers_service.dart`)

- Accept tank pressure data as input
- Use active tank's pressure curve for threshold detection

#### UDDF Export (`uddf_export_builders.dart`, `uddf_export_service.dart`)

Both UDDF export paths write `<tankpressure>` elements from `point.pressure` on `DiveProfilePoint`. After field removal, export must source per-waypoint pressure from `tank_pressure_profiles` data. The export function needs to accept tank pressure data (keyed by tank ID) alongside the profile, then look up the pressure for the active tank at each waypoint's timestamp.

#### Dive Repository (`dive_repository_impl.dart`)

- Stop mapping `pressure` when reading profiles (~lines 233, 381, 2477)
- Stop writing `pressure` when inserting profiles (~lines 287, 704)

#### Dive Computer Repository (`dive_computer_repository_impl.dart`)

- Stop writing to `DiveProfiles.pressure` column
- Tank pressure insertion (grouping by `tankIndex` into `tank_pressure_profiles`) unchanged

### Phase 4: Entity Cleanup

#### `DiveProfilePoint` (`dive.dart`)

Remove from the entity:
- `final double? pressure;` field
- Constructor parameter
- `copyWith()` parameter
- `Equatable` props entry

`TankPressurePoint` (already defined) becomes the sole pressure representation.

#### `DiveProfiles` Drift table (`database.dart`)

The `pressure` column stays in the schema. Add deprecation comment.

#### `ProfileSample` import entity (`downloaded_dive.dart`)

Keeps `pressure` and `tankIndex` fields. These are transient objects used during import to carry FFI data into `_storeTankPressures()`. Not stored directly.

#### Import map structure

- Remove: `sampleMap['pressure']` (legacy single pressure)
- Keep: `sampleMap['allTankPressures']` (list of `{pressure, tankIndex}` maps)

## Testing

- Unit tests for `ShearwaterDiveMapper.mergeWithParsedDive()` with multi-transmitter FFI data (two tanks, interleaved samples)
- Unit tests for database migration: verify legacy pressure data appears in `tank_pressure_profiles` after migration
- Unit tests for migration edge cases: dives with no tanks, dives already migrated, dives with all-null pressure
- Integration tests for SAC calculation using only `TankPressurePoint` data
- Integration tests for pressure marker detection from tank pressure data
- Verify profile chart renders correctly with only multi-tank pressure source
- Verify re-importing a Shearwater dive with two AI transmitters shows both pressure curves

## Files Changed

| File | Change |
|------|--------|
| `lib/features/universal_import/data/services/shearwater_dive_mapper.dart` | Build `allTankPressures` from FFI samples |
| `lib/core/services/export/uddf/uddf_import_service.dart` | Stop writing legacy `point['pressure']` |
| `lib/core/services/export/uddf/uddf_full_import_service.dart` | Stop writing legacy `point['pressure']` |
| `lib/features/dive_import/data/services/uddf_entity_importer.dart` | Stop reading `p['pressure']` into entity |
| `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` | Stop writing legacy pressure column |
| `lib/core/database/database.dart` | Schema version bump, migration, deprecation comment |
| `lib/features/dive_log/domain/entities/dive.dart` | Remove `pressure` from `DiveProfilePoint` |
| `lib/features/dive_log/data/repositories/dive_repository_impl.dart` | Stop reading/writing legacy pressure |
| `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` | Remove legacy pressure path |
| `lib/features/dive_log/data/services/gas_analysis_service.dart` | Source pressure from tank pressure data |
| `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart` | Remove legacy fallback |
| `lib/features/dive_log/data/services/profile_markers_service.dart` | Source pressure from tank pressure data |
| `lib/core/services/export/uddf/uddf_export_builders.dart` | Source `<tankpressure>` from tank pressure data |
| `lib/core/services/export/uddf/uddf_export_service.dart` | Source `<tankpressure>` from tank pressure data |
