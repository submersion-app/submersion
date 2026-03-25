# Duration → Bottom Time Rename

Rename `Dive.duration` to `Dive.bottomTime` to eliminate the confusing naming where "duration" means bottom time in some contexts and runtime in others.

## Problem

The `Dive` entity has two time fields with confusing names:
- `duration` — actually stores **bottom time** (time at depth, excluding descent/ascent)
- `runtime` — stores **total dive time** (entry to exit)

This leads to bugs (e.g., the import comparison card was comparing bottom time to runtime) and makes the code harder to reason about.

## Goal

After this rename:
- `Dive.bottomTime` = time at depth (currently `Dive.duration`)
- `Dive.runtime` = total dive time (unchanged)
- Any generic "duration" reference in the codebase means total time, not bottom time

## Scope

### What Gets Renamed

| Current | New | Location |
|---------|-----|----------|
| `Dive.duration` | `Dive.bottomTime` | Domain entity |
| `DiveSummary.duration` | `DiveSummary.bottomTime` | Summary entity |
| `dives.duration` (DB column) | `dives.bottom_time` | Database schema + migration |
| `calculatedDuration` | `calculatedBottomTime` | Dive computed property |
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

### Identification Rule

For each `duration` reference: "Does this refer to the Dive entity's bottom time field?"
- YES → rename to `bottomTime`
- NO (runtime, different entity, general concept) → leave as-is

## Impact Assessment

| Category | Files | Notes |
|----------|-------|-------|
| Domain entities | 2 (Dive, DiveSummary) | Field + constructor + copyWith + props |
| Database | 1 | Column rename migration |
| Repository | 2 | Mapping + raw SQL strings |
| Import pipeline | 3-5 | Converter, importers (only where they set bottom time) |
| UI presentation | 12+ | Detail, edit, list tiles, widgets |
| Export services | 5+ | UDDF, PDF, CSV, Excel, KML |
| Statistics/analysis | 8+ | SAC calculations, aggregations |
| Tests | ~55 files | Extensive test data references |
| **Total** | **~90-100 files** | |

## Key Risk: SAC Calculations

SAC (Surface Air Consumption) calculations in `dive.dart` correctly use bottom time for the rate calculation. After rename, these must use `bottomTime`, not `runtime`. Verify the formula still references the correct field.

## Migration

Single schema migration:

```sql
ALTER TABLE dives RENAME COLUMN duration TO bottom_time;
```

## Testing Strategy

- Run safety grep before and after for all `duration` references
- All 2400+ existing tests must pass
- Verify SAC calculations produce identical results
- Verify sort/filter by bottom time still works
- Verify export formats output correct values
