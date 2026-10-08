# Dive Time Timezone Fix

## Problem

Dive times imported from dive computers are shifted by a number of hours equal to the user's UTC offset. User reports confirm this across multiple devices:

- Shearwater Perdix 2: shifted behind by 8 hours (PST user)
- Shearwater Tern: shifted forward by 13 hours (GMT+13 user)
- Shearwater Perdix: 7-hour shift matching PDT offset
- DeepSix Excursion: 4-hour shift matching EDT offset

The root cause is a bug chain in the import pipeline where local wall-clock time components are interpreted as UTC, then converted back to local for display, producing a double-shift.

## Design Principle

Dive times represent wall-clock time at the dive site. They must never be shifted, converted, or interpreted through any timezone. Whatever time the diver saw on their dive computer is what the app displays, permanently, regardless of the device's current timezone.

## Storage Convention: Wall-Clock-as-UTC

All dive times are stored as `DateTime.utc(y, m, d, h, min, s).millisecondsSinceEpoch`. The UTC label is a storage mechanism, not a semantic claim about timezone. This means the UTC components of the stored epoch equal the wall-clock time the diver experienced.

Display code formats these UTC DateTimes directly. `DateFormat.format(utcDateTime)` uses the UTC components, so the displayed time is always the wall-clock time regardless of device timezone.

## Bug Chain (Current Behavior)

1. libdivecomputer provides date/time components (year, month, day, hour, minute, second) plus a `timezone` field (seconds east of UTC, or `DC_TIMEZONE_NONE` if unknown). For most dive computers, these components are local wall-clock time.
2. Native code (Swift/Kotlin) forces a UTC calendar to interpret these components, treating "7:42 AM local" as "7:42 AM UTC" and producing the wrong POSIX epoch.
3. Dart mapper creates `DateTime.fromMillisecondsSinceEpoch(epoch * 1000)` (a local DateTime from the wrong epoch).
4. UI calls `.toLocal()` or `DateFormat.format()` on this local DateTime.
5. Result: every dive time is shifted by the user's UTC offset.

## Changes

### 1. Pigeon API

Replace the single `dateTimeEpoch` field in `ParsedDive` with raw components:

```dart
// In pigeons/dive_computer_api.dart - ParsedDive class
// Remove: final int dateTimeEpoch;
// Add:
final int dateTimeYear;
final int dateTimeMonth;
final int dateTimeDay;
final int dateTimeHour;
final int dateTimeMinute;
final int dateTimeSecond;
final int? dateTimeTimezoneOffset; // seconds east of UTC, null if unknown
```

The timezone offset is passed through for informational purposes and future Teric-specific handling (see Known Limitations). It is not used in the initial Dart mapper logic.

After modifying the Pigeon definition, regenerate with:

```bash
dart run pigeon --input pigeons/dive_computer_api.dart
```

### 2. Native Code (Swift and Kotlin)

**Files:**
- `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift` (lines 408-420)
- `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt` (lines 281-295)

Remove the UTC calendar epoch calculation. Pass through the raw components from the C struct (`dive.year`, `dive.month`, `dive.day`, `dive.hour`, `dive.minute`, `dive.second`) and the timezone field (`dive.timezone`). Map `DC_TIMEZONE_NONE` (which equals `INT_MIN` per `libdivecomputer/datetime.h`) to `nil`/`null` on the Pigeon side.

**iOS/macOS (Swift):** The Swift implementation lives in the shared Darwin Swift Package at `darwin/Sources/LibDCDarwin/`. The `ios/Classes/` and `macos/Classes/` directories contain only generated Pigeon glue code. The change must be made in the `darwin/` path.

**Android (Kotlin):** The Android side reads fields via JNI one at a time (e.g., `LibdcWrapper.nativeGetDiveYear(divePtr)`). There is currently no `nativeGetDiveTimezone` JNI binding. A new JNI method must be added:

- Add `nativeGetDiveTimezone(divePtr: Long): Int` to `LibdcWrapper.kt`
- Implement the corresponding C/JNI function in the native library
- Return the raw `timezone` field from the `libdc_dive_t` struct

The C wrapper already copies `dt.timezone` into `dive->timezone` (`libdc_download.c:271`), so the value is available in the struct for both platforms.

### 3. Dart Mapper

**File:** `lib/features/dive_computer/data/services/parsed_dive_mapper.dart`

```dart
// Always use components as-is. For the vast majority of dive computers,
// these are the local wall-clock time the diver saw on the display.
// See "Known Limitations" for the Shearwater Teric edge case.
final startTime = DateTime.utc(
  parsed.dateTimeYear, parsed.dateTimeMonth, parsed.dateTimeDay,
  parsed.dateTimeHour, parsed.dateTimeMinute, parsed.dateTimeSecond,
);
```

**Why no timezone branch:** Analysis of libdivecomputer parsers shows that when `timezone != DC_TIMEZONE_NONE`, most devices (DiveSystem iDive, Halcyon Symbios, Divesoft Freedom, SEAC Screen, Uwatec/Scubapro, DeepSix Excursion) add the timezone offset to ticks *before* calling `dc_datetime_gmtime()`, producing **local** components. Applying the timezone offset again in the Dart mapper would double-shift these devices. Only the Shearwater Teric provides true UTC components with a timezone offset. See Known Limitations.

### 4. Manual Entry

**File:** `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (lines 3283-3301)

Change `DateTime(...)` to `DateTime.utc(...)` for both entry and exit DateTimes:

```dart
final entryDateTime = DateTime.utc(
  _entryDate.year, _entryDate.month, _entryDate.day,
  _entryTime.hour, _entryTime.minute,
);
```

Same change for `exitDateTime` construction. The `exitDateTime.difference(entryDateTime)` runtime calculation (line 3306) remains correct since both DateTimes use the same UTC convention and `Duration` is based on absolute epoch difference.

### 5. Database Read Path

**File:** `lib/features/dive_log/data/repositories/dive_repository_impl.dart`

Every place a dive DateTime is reconstructed from the database must use `isUtc: true`:

```dart
// Before:
dateTime: DateTime.fromMillisecondsSinceEpoch(row.diveDateTime),

// After:
dateTime: DateTime.fromMillisecondsSinceEpoch(row.diveDateTime, isUtc: true),
```

This applies to `_mapRowToDive`, `_mapRowToDiveWithPreloadedData`, and any other mapping methods. Same for `entryTime` and `exitTime` fields.

### 6. Date Range Queries

**File:** `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (line 1337)

`getDivesInRange(start, end)` compares `start.millisecondsSinceEpoch` against stored values. After the fix, stored epochs are wall-clock-as-UTC. Callers that construct range bounds from `DateTime.now()` or `DateTime(y, m, d)` (local) will produce local epochs that don't match the wall-clock-as-UTC convention.

**Fix:** All callers of `getDivesInRange` and `getDiveNumberForDate` must construct date bounds using `DateTime.utc(y, m, d)` instead of `DateTime(y, m, d)`. Audit callers in:

- `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart` (lines 656, 742)
- `lib/features/dive_import/presentation/providers/dive_import_providers.dart` (line 269) — constructs `rangeStart`/`rangeEnd` from HealthKit `ImportedDive.startTime` values (local DateTimes). Must convert to UTC components: `DateTime.utc(d.year, d.month, d.day, d.hour, d.minute, d.second)` before passing to `getDivesInRange`.
- Any other provider or service that queries dives by date range

Similarly, `getDiveNumberForDate` (line 1409) receives a `DateTime` parameter and uses `.millisecondsSinceEpoch`. Callers must pass UTC DateTimes.

### 7. Display Path

No changes needed to formatting code. `UnitFormatter.formatDate/formatTime/formatDateTime` in `lib/core/utils/unit_formatter.dart` call `DateFormat.format(dateTime)`, which uses the DateTime's own components. For UTC DateTimes, this formats the UTC components directly.

The `.toLocal()` calls in `dive_detail_page.dart` (lines 2771-2902) are for tide prediction times, not dive times. Tides are genuinely UTC and must continue using `.toLocal()`. Do not change those.

The download preview displays in `download_step_widget.dart` (line 417) and `device_download_page.dart` (line 830) access `date.month/day/year` directly without `.toLocal()`, which is correct for the new convention since the DateTime will be UTC with wall-clock components. The import preview in `imported_dive_card.dart` (line 87) uses `DateFormat.format(dive.startTime)` which also works correctly with UTC DateTimes. No changes needed in these files.

### 8. Profile and Tank Timestamps

Profile points (`dive_profiles` table) and tank pressure points store timestamps as seconds-from-dive-start (relative offsets), not absolute DateTimes. These are not affected by this change.

## Schema Migration

### New Column

Add `importVersion` (nullable integer) to the `dives` table:

```dart
IntColumn get importVersion => integer().nullable()();
```

- `null` = pre-fix dive (legacy)
- `1` = post-fix dive (wall-clock-as-UTC convention)

All new dives (imported or manual) are created with `importVersion: Value(1)`.

### Automatic Migration

Run once on app upgrade as a Drift schema migration step.

**Dive-computer-imported dives** (identified by `diveComputerModel IS NOT NULL` OR `computerId IS NOT NULL`):

- Already accidentally stored in wall-clock-as-UTC format (the import bug treated local components as UTC, which happens to be the target format).
- Action: Set `importVersion = 1`. No timestamp change.

**Wearable-imported dives** (identified by `wearableSource IS NOT NULL` AND NOT already classified above):

- HealthKit-sourced dives are stored as true local epoch (HealthKit provides proper local DateTimes).
- FIT-imported dives (Garmin): `DateTime.fromMillisecondsSinceEpoch(startTimeMs)` where `startTimeMs` is a UTC epoch from the FIT SDK. Creates a local DateTime, stored as true local epoch.
- Action for all wearable/file imports: Shift timestamps by the device's current UTC offset: `newEpoch = oldEpoch - localOffsetMs`. Set `importVersion = 1`.

**Note on UDDF full-import path:** The full UDDF import (`uddf_entity_importer.dart`) constructs `Dive(...)` objects directly without setting `wearableSource`. These dives will have `wearableSource IS NULL` and no `diveComputerModel`/`computerId`, causing them to be classified as manual dives. This is acceptable for the migration since `DateTime.tryParse()` on UDDF strings without timezone designators produces local DateTimes (same as manual), and the migration shifts them identically. For UDDF strings WITH timezone designators (e.g., `Z` suffix), the migration will over-correct — the bulk-fix tool handles these cases. As an implementation improvement, `uddf_entity_importer.dart` should be updated to set `wearableSource = 'uddf'` on created dives for future classification reliability.

**Manual dives** (all remaining: `diveComputerModel IS NULL` AND `computerId IS NULL` AND `wearableSource IS NULL`):

- Stored as true local epoch.
- Action: Shift timestamps by the device's current UTC offset: `newEpoch = oldEpoch - localOffsetMs`. Set `importVersion = 1`.

The auto-migration uses the device's current UTC offset, which is imperfect if the user changed timezones since entering a dive or if DST was different at the time of entry. The bulk-fix tool handles these edge cases.

The migration must shift `diveDateTime`, `entryTime`, and `exitTime` columns for affected rows.

## Bulk-Fix Tool

A screen accessible from Settings that lets users manually correct dive times.

### User Flow

1. User navigates to Settings > Fix Dive Times
2. User selects dives to fix (filter by date range, select individual dives, or select all)
3. User enters an hour offset to apply (e.g., +7, -5)
4. Preview shows before/after times for selected dives
5. User confirms
6. Tool applies the offset to `diveDateTime`, `entryTime`, and `exitTime` for selected dives

### Scope

This tool is for correcting any dives whose times are wrong after the automatic migration. It applies a uniform hour offset to all selected dives. Note that dives spanning a DST transition within a single timezone may need separate corrections (different offset for summer vs winter dives). Users can run the tool multiple times with different selections and offsets.

## Known Limitations

### Shearwater Teric UTC Components

The Shearwater Teric (with logversion >= 9) is the only device whose libdivecomputer parser returns **UTC** components with a non-`DC_TIMEZONE_NONE` timezone offset. All other timezone-aware parsers (DiveSystem iDive, Halcyon Symbios, Divesoft Freedom, SEAC Screen, Uwatec/Scubapro, DeepSix Excursion) adjust ticks by the timezone offset before calling `dc_datetime_gmtime()`, producing local components.

Because the Dart mapper treats all components as local wall-clock time, Teric users will see UTC time instead of local time. This is an improvement over the current behavior (where times are double-shifted and wildly wrong), but still not ideal for Teric users in non-UTC timezones.

**Planned enhancement:** Add Teric-specific handling in the native layer (Swift/Kotlin), where the device model is known. When the device is identified as a Shearwater Teric AND `timezone != DC_TIMEZONE_NONE`, apply the timezone offset to the components before passing them through Pigeon. This converts the UTC components to local wall-clock components, making them consistent with all other devices. The `dateTimeTimezoneOffset` field in the Pigeon API is already included to support this enhancement.

### UDDF Import Timezone Ambiguity

UDDF XML datetime strings may or may not include timezone designators. When they do (e.g., `2024-06-15T14:42:00Z`), `DateTime.tryParse` returns a UTC DateTime. When they don't (e.g., `2024-06-15T14:42:00`), it returns a local DateTime. The auto-migration treats all UDDF imports as local epoch, which may slightly over-correct or under-correct for UDDF files with timezone designators. The bulk-fix tool handles these cases.

## Testing Strategy

### Unit Tests

- Dart mapper: verify wall-clock-as-UTC construction from raw components (timezone offset ignored)
- Migration logic: verify computer-imported dives are left unchanged, manual/wearable dives are shifted correctly
- Bulk-fix: verify offset application and preview calculation
- Date range queries: verify callers use UTC bounds

### Integration Tests

- Full import pipeline: mock Pigeon ParsedDive with raw components, verify stored epoch has correct wall-clock-as-UTC value
- Manual entry: verify DateTime.utc construction and correct storage
- Database round-trip: verify that stored and retrieved times display identically
- Range query round-trip: verify getDivesInRange with UTC bounds returns correct dives

### Edge Cases

- Timezone offset that crosses a date boundary (e.g., UTC+13 at 11 PM local)
- Negative timezone offsets
- `dateTimeTimezoneOffset` of zero (UTC, not unknown)
- Devices that provide `DC_TIMEZONE_NONE`
- Leap seconds (should be a no-op since we pass through components)
- Dives spanning a DST transition (bulk-fix with different offsets per selection)
- UDDF files with and without timezone designators in datetime strings

## Files Changed

| File | Change |
|------|--------|
| `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart` | Replace `dateTimeEpoch` with component fields + timezone |
| `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift` | Pass through raw components instead of UTC epoch |
| `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt` | Pass through raw components instead of UTC epoch |
| `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/LibdcWrapper.kt` | Add `nativeGetDiveTimezone` JNI binding |
| Android JNI C/C++ file | Implement `nativeGetDiveTimezone` native method |
| `packages/libdivecomputer_plugin/lib/src/generated/dive_computer_api.g.dart` | Regenerated by Pigeon |
| `lib/features/dive_computer/data/services/parsed_dive_mapper.dart` | Wall-clock-as-UTC DateTime construction from components |
| `lib/features/dive_log/presentation/pages/dive_edit_page.dart` | `DateTime(...)` to `DateTime.utc(...)` |
| `lib/features/dive_log/data/repositories/dive_repository_impl.dart` | Add `isUtc: true` to all DateTime reconstructions |
| `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart` | Use UTC bounds for date range queries |
| `lib/features/dive_import/presentation/providers/dive_import_providers.dart` | Convert `getDivesInRange` bounds and `getDiveNumberForDate` arg to UTC |
| `lib/core/database/database.dart` | Add `importVersion` column, migration step |
| New: `lib/features/settings/presentation/pages/fix_dive_times_page.dart` | Bulk-fix tool UI |
| New: `lib/features/settings/data/services/dive_time_migration_service.dart` | Migration and bulk-fix logic |
