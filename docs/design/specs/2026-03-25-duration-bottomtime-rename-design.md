# Duration → Bottom Time Rename + SAC Calculation Fix

Rename `Dive.duration` to `Dive.bottomTime` to eliminate confusing naming, and fix SAC calculations that incorrectly use bottom time instead of runtime.

## Problem

The `Dive` entity has two time fields with confusing names:
- `duration` — actually stores **bottom time** (time at depth, excluding descent/ascent)
- `runtime` — stores **total dive time** (entry to exit)

This naming confusion has caused two categories of bugs:

1. **Semantic confusion:** Code that needs runtime accidentally uses `duration` (bottom time) because the name suggests total time. The import comparison card was comparing bottom time to runtime.

2. **SAC calculation errors (Issues #72, #87):** `Dive.sac`, `Dive.sacPressure`, and `GasAnalysisService.calculateCylinderSac` all divide gas consumed by `duration` (bottom time) instead of runtime. Since gas is consumed during descent and ascent too, the numerator covers the full dive but the denominator only covers part of it — inflating SAC by the ratio of runtime to bottom time (often 1.5-2x+).

Additionally, the `calculatedDuration` getter conflates two different concepts — it returns `exitTime - entryTime` (runtime) when entry/exit times exist, but falls back to `duration` (bottom time) when they don't. Every caller of this getter actually wants runtime.

### Evidence from Issue Reports

- **Issue #72:** User calculates SAC as 14.83 L/min using runtime (42 min). App reports 31.5 L/min — consistent with using bottom time (~20 min). Same 2x factor for bar/min: expected 1.33, got 2.8.
- **Issue #87:** User reports "impossible" 1.8 bar/min from 95 bar in 70 min. Expected ~1.3 bar/min using runtime.

## Goal

After this work:
- `Dive.bottomTime` = time at depth (currently `Dive.duration`)
- `Dive.runtime` = total dive time (unchanged)
- `Dive.effectiveRuntime` = new getter with fallback chain for best available runtime
- Any generic "duration" reference in the codebase means total time, not bottom time
- SAC calculations use runtime, producing values consistent with manual calculation and other dive software (Shearwater, Subsurface)

## Phased Approach

### Phase 1: Rename (no behavior change)

Pure mechanical rename of `duration` → `bottomTime`. All tests must pass identically with zero behavior change.

### Phase 2: SAC Fix (targeted behavior change)

Add `effectiveRuntime` getter. Fix SAC calculations to use it. Update and add tests reflecting correct SAC values.

## Phase 1 Scope: Rename

### What Gets Renamed

| Current | New | Location |
|---------|-----|----------|
| `Dive.duration` | `Dive.bottomTime` | Domain entity |
| `DiveSummary.duration` | `DiveSummary.bottomTime` | Summary entity |
| `dives.duration` (DB column) | `dives.bottom_time` | Database schema + migration |
| `DiveSortField.duration` | `DiveSortField.bottomTime` | Sort options |
| `minDurationMinutes` / `maxDurationMinutes` | `minBottomTimeMinutes` / `maxBottomTimeMinutes` | Filter state |
| Repository mappings | Updated to use `bottomTime` | dive_repository_impl.dart |
| Raw SQL `d.duration` | `d.bottom_time` | Repository queries |

### What Does NOT Get Renamed

| Field | Reason |
|-------|--------|
| `Dive.runtime` | Already correct — stays as-is |
| `DiveDataSource.duration` | Stores runtime from dive computer, not bottom time |
| `ImportedDive.duration` | Computed from endTime - startTime, this is runtime |
| `IncomingDiveData.durationSeconds` | Stores runtime |
| `ComparisonFieldType.duration` | Generic formatting enum, not tied to bottom time |
| Localization string keys | Display labels already say "Bottom Time" where appropriate |

### What Gets Replaced (not just renamed)

| Current | Replacement | Reason |
|---------|------------|--------|
| `Dive.calculatedDuration` getter | `Dive.effectiveRuntime` getter | Old getter conflated runtime and bottom time; all callers want runtime |

### Identification Rule

For each `duration` reference: "Does this refer to the Dive entity's bottom time field?"
- YES → rename to `bottomTime`
- NO (runtime, different entity, general concept) → leave as-is

## Phase 2 Scope: SAC Fix + effectiveRuntime

### New Getter: `Dive.effectiveRuntime`

Returns the best available runtime via fallback chain:

```
effectiveRuntime tries (in order):
  1. runtime              — explicitly stored from import/dive computer
  2. exitTime - entryTime — computed from entry/exit timestamps
  3. calculateRuntimeFromProfile() — first-to-last profile point
  4. bottomTime (fallback) — approximate, but better than null
```

Returns `Duration?` — `null` only if none of the above are available. In practice, most dives will have at least `bottomTime`, so SAC will almost always be calculable. When only `bottomTime` is available, SAC will be slightly overestimated (same as the current behavior), but this is acceptable — an approximate SAC is more useful than no SAC.

### Callers Switching to `effectiveRuntime`

| File | Line | Old Code | New Code |
|------|------|----------|----------|
| `photo_import_helper.dart` | 31 | `dive.calculatedDuration` | `dive.effectiveRuntime` |
| `dive_detail_page.dart` | 1133 | `dive.calculatedDuration` | `dive.effectiveRuntime` |
| `dive_detail_page.dart` | 4765 | `dive.calculatedDuration` | `dive.effectiveRuntime` |
| `dive_repository_impl.dart` | 2971 | `previousDive.calculatedDuration` | `previousDive.effectiveRuntime` |

### Local Variable Renames in `dive_edit_page.dart`

These are local variables (not calls to the getter) that should be renamed for clarity:
- Line 321, 1819: `calculatedDuration` → `calculatedBottomTime` (calls `calculateBottomTimeFromProfile()`)
- Line 804: `calculatedDuration` → `calculatedRuntime` (computes `exitDateTime - entryDateTime`)

### SAC Calculation Fixes

Three locations switch from `bottomTime` to `effectiveRuntime`:

**1. `Dive.sac` getter (dive.dart)**
```
Before: if (tanks.isEmpty || duration == null || avgDepth == null) return null;
        final minutes = duration!.inSeconds / 60;
After:  if (tanks.isEmpty || effectiveRuntime == null || avgDepth == null) return null;
        final minutes = effectiveRuntime!.inSeconds / 60;
```

**2. `Dive.sacPressure` getter (dive.dart)**
Same change — replace `duration` null check and usage with `effectiveRuntime`.

**3. `GasAnalysisService.calculateCylinderSac` (gas_analysis_service.dart:245)**
```
Before: diveEnd: dive.duration?.inSeconds ?? profile.lastOrNull?.timestamp ?? 0,
After:  diveEnd: dive.effectiveRuntime?.inSeconds ?? profile.lastOrNull?.timestamp ?? 0,
```

### What Does NOT Change

- `ProfileAnalysisService` segment methods — already use profile timestamps directly
- `GasAnalysisService` segment methods (gas-switch, phase, time-based) — already use profile timestamps
- These are correct as-is

## Impact Assessment

| Category | Files | Notes |
|----------|-------|-------|
| Domain entities | 2 (Dive, DiveSummary) | Field + constructor + copyWith + props + new getter |
| Database | 1 | Column rename migration |
| Repository | 2 | Mapping + raw SQL strings |
| Import pipeline | 3-5 | Converter, importers (only where they set bottom time) |
| UI presentation | 12+ | Detail, edit, list tiles, widgets |
| Export services | 5+ | UDDF, PDF, CSV, Excel, KML |
| Statistics/analysis | 8+ | SAC calculations, aggregations |
| Tests | ~55 files | Extensive test data references |
| **Total** | **~90-100 files** | |

## Migration

Single schema migration:

```sql
ALTER TABLE dives RENAME COLUMN duration TO bottom_time;
```

No data transformation needed — the stored values are still bottom time; the column just gets an honest name.

## Testing Strategy

### Phase 1 (Rename) Verification

- Safety grep before and after for all `duration` references that should have been renamed
- All ~2400 existing tests must pass with zero behavior change
- `dart format .` clean
- Verify sort/filter by bottom time still works
- Verify export formats output correct values

### Phase 2 (SAC Fix) Verification

- Update existing SAC tests to expect values calculated with runtime instead of bottom time
- New tests for the fix:
  - `Dive.sac` and `Dive.sacPressure` use `effectiveRuntime` when available
  - `Dive.sac` falls back to `bottomTime` when no runtime source exists
  - `GasAnalysisService.calculateCylinderSac` uses runtime for single-tank dives
  - Reproduce issue #72 numbers: 170 bar, AL80 (11.1L), 20.3m avg depth, 42 min runtime => SAC = 14.83 L/min, sacPressure = 1.33 bar/min
- Test the `effectiveRuntime` fallback chain:
  - Returns `runtime` when set
  - Falls back to `exitTime - entryTime` when `runtime` is null
  - Falls back to profile-based when entry/exit are null
  - Falls back to `bottomTime` as last resort
  - Returns `null` when nothing is available

### Issues Addressed

- **Issue #72:** SAC Rate calculations wrong by a factor of 2 or more — FIXED
- **Issue #87:** SAC Rate portion (mix rounding and deco are separate issues) — FIXED
