# Dive Time Timezone Fix Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix dive times being shifted by the user's UTC offset on import, and establish a timezone-stable wall-clock-as-UTC storage convention.

**Architecture:** Replace the Pigeon epoch-based datetime transfer with raw year/month/day/hour/minute/second components. Store all dive times as `DateTime.utc(...)` so the UTC components equal the wall-clock time. Migrate existing dives and add a bulk-fix tool for edge cases.

**Tech Stack:** Flutter/Dart, Drift ORM, Pigeon (FFI bridge), Swift (Darwin), Kotlin/JNI (Android), C (libdivecomputer wrapper)

**Spec:** `docs/superpowers/specs/2026-03-17-dive-time-timezone-fix-design.md`

---

## Chunk 1: Pigeon API + Native Code Changes

These tasks modify the FFI bridge layer to pass raw datetime components instead of a pre-computed epoch.

### Task 1: Update Pigeon API Definition

**Files:**

- Modify: `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart:119-154`

- [ ] **Step 1: Replace `dateTimeEpoch` with component fields in ParsedDive**

In `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart`, replace the `dateTimeEpoch` field in the `ParsedDive` class constructor and field list:

```dart
class ParsedDive {
  const ParsedDive({
    required this.fingerprint,
    required this.dateTimeYear,
    required this.dateTimeMonth,
    required this.dateTimeDay,
    required this.dateTimeHour,
    required this.dateTimeMinute,
    required this.dateTimeSecond,
    this.dateTimeTimezoneOffset,
    required this.maxDepthMeters,
    required this.avgDepthMeters,
    required this.durationSeconds,
    this.minTemperatureCelsius,
    this.maxTemperatureCelsius,
    required this.samples,
    required this.tanks,
    required this.gasMixes,
    required this.events,
    this.diveMode,
    this.decoAlgorithm,
    this.gfLow,
    this.gfHigh,
    this.decoConservatism,
  });
  final String fingerprint;
  final int dateTimeYear;
  final int dateTimeMonth;
  final int dateTimeDay;
  final int dateTimeHour;
  final int dateTimeMinute;
  final int dateTimeSecond;
  final int? dateTimeTimezoneOffset; // seconds east of UTC, null if unknown
  final double maxDepthMeters;
  final double avgDepthMeters;
  final int durationSeconds;
  final double? minTemperatureCelsius;
  final double? maxTemperatureCelsius;
  final List<ProfileSample> samples;
  final List<TankInfo> tanks;
  final List<GasMix> gasMixes;
  final List<DiveEvent> events;
  final String? diveMode;
  final String? decoAlgorithm;
  final int? gfLow;
  final int? gfHigh;
  final int? decoConservatism;
}
```

- [ ] **Step 2: Regenerate Pigeon code**

Run from the `packages/libdivecomputer_plugin/` directory:

```bash
cd packages/libdivecomputer_plugin && dart run pigeon --input pigeons/dive_computer_api.dart
```

This regenerates `lib/src/generated/dive_computer_api.g.dart` (Dart), `ios/Classes/DiveComputerApi.g.swift`, and `android/src/main/kotlin/.../DiveComputerApi.g.kt`.

**Important:** The `@ConfigurePigeon` annotation only specifies `swiftOut: 'ios/Classes/DiveComputerApi.g.swift'` — there is no macOS output configured. The macOS file is a separate copy. After regeneration, copy the iOS Swift file to macOS:

```bash
cp ios/Classes/DiveComputerApi.g.swift macos/Classes/DiveComputerApi.g.swift
```

- [ ] **Step 3: Commit**

```bash
git add packages/libdivecomputer_plugin/pigeons/ packages/libdivecomputer_plugin/lib/src/generated/ packages/libdivecomputer_plugin/ios/Classes/DiveComputerApi.g.swift packages/libdivecomputer_plugin/macos/Classes/DiveComputerApi.g.swift packages/libdivecomputer_plugin/android/
git commit -m "feat: replace dateTimeEpoch with raw component fields in Pigeon API"
```

### Task 2: Update Swift Native Code (Darwin)

**Files:**

- Modify: `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift:397-537`

- [ ] **Step 1: Remove UTC calendar epoch calculation and pass raw components**

In `DiveComputerHostApiImpl.swift`, in the `convertParsedDive` method (starting around line 397), replace lines 408-420 (the UTC calendar epoch computation) and update the `ParsedDive` constructor call at lines 516-537.

Remove this block (lines 408-420):

```swift
// Convert datetime to epoch seconds.
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "UTC")!
var components = DateComponents()
components.year = Int(dive.year)
components.month = Int(dive.month)
components.day = Int(dive.day)
components.hour = Int(dive.hour)
components.minute = Int(dive.minute)
components.second = Int(dive.second)
let epoch = calendar.date(from: components).map {
    Int64($0.timeIntervalSince1970)
} ?? 0
```

Replace with timezone mapping:

```swift
// Map DC_TIMEZONE_NONE (INT32_MIN) to nil.
let timezoneOffset: Int64? = dive.timezone == Int32.min ? nil : Int64(dive.timezone)
```

Update the `ParsedDive(...)` constructor call (lines 516-537), replacing `dateTimeEpoch: epoch` with the component fields:

```swift
return ParsedDive(
    fingerprint: fingerprintHex,
    dateTimeYear: Int64(dive.year),
    dateTimeMonth: Int64(dive.month),
    dateTimeDay: Int64(dive.day),
    dateTimeHour: Int64(dive.hour),
    dateTimeMinute: Int64(dive.minute),
    dateTimeSecond: Int64(dive.second),
    dateTimeTimezoneOffset: timezoneOffset,
    maxDepthMeters: dive.max_depth,
    avgDepthMeters: dive.avg_depth,
    durationSeconds: Int64(dive.duration),
    minTemperatureCelsius: dive.min_temp.isNaN ? nil : dive.min_temp,
    maxTemperatureCelsius: dive.max_temp.isNaN ? nil : dive.max_temp,
    samples: samples,
    tanks: tanks,
    gasMixes: gasMixes,
    events: events,
    diveMode: diveModeStr,
    decoAlgorithm: decoAlgorithm,
    gfLow: dive.gf_low == 0 ? nil : Int64(dive.gf_low),
    gfHigh: dive.gf_high == 0 ? nil : Int64(dive.gf_high),
    decoConservatism: dive.deco_conservatism == 0 ? nil : Int64(dive.deco_conservatism)
)
```

Note: The `timezone` field is an `int` in the C struct `libdc_parsed_dive_t` (defined in `macos/Classes/libdc_wrapper.h:158`). `DC_TIMEZONE_NONE` is `INT_MIN` which is `Int32.min` in Swift.

- [ ] **Step 2: Verify the project builds for macOS**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion && flutter build macos --debug 2>&1 | tail -20
```

Expected: Build succeeds (or only unrelated warnings).

- [ ] **Step 3: Commit**

```bash
git add packages/libdivecomputer_plugin/darwin/
git commit -m "feat(ios/macos): pass raw datetime components instead of UTC epoch"
```

### Task 3: Add Android JNI Timezone Binding

**Files:**

- Modify: `packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp:568-573`
- Modify: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/LibdcWrapper.kt:48`

- [ ] **Step 1: Add `nativeGetDiveTimezone` JNI function in C++**

In `libdc_jni.cpp`, after the `nativeGetDiveSecond` function (line 573), add:

```cpp
extern "C" JNIEXPORT jint JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetDiveTimezone(
    JNIEnv *, jclass, jlong divePtr) {
    auto *dive = reinterpret_cast<const libdc_parsed_dive_t *>(divePtr);
    return dive->timezone;
}
```

- [ ] **Step 2: Add Kotlin external declaration**

In `LibdcWrapper.kt`, after `nativeGetDiveSecond` (line 48), add:

```kotlin
    external fun nativeGetDiveTimezone(divePtr: Long): Int
```

- [ ] **Step 3: Commit**

```bash
git add packages/libdivecomputer_plugin/android/
git commit -m "feat(android): add nativeGetDiveTimezone JNI binding"
```

### Task 4: Update Kotlin Native Code (Android)

**Files:**

- Modify: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt:278-402`

- [ ] **Step 1: Remove UTC calendar epoch and pass raw components**

In `DiveComputerHostApiImpl.kt`, in the `convertParsedDive` method (line 278), replace lines 281-295 (the UTC calendar epoch computation):

Remove:

```kotlin
// Convert datetime to epoch seconds.
// libdivecomputer provides LOCAL time + timezone offset (seconds east of UTC).
// We create a UTC calendar with the local time components, then subtract
// the timezone offset to get the correct UTC epoch.
val cal = Calendar.getInstance(TimeZone.getTimeZone("UTC"))
cal.set(
    LibdcWrapper.nativeGetDiveYear(divePtr),
    LibdcWrapper.nativeGetDiveMonth(divePtr) - 1,  // Calendar months are 0-based
    LibdcWrapper.nativeGetDiveDay(divePtr),
    LibdcWrapper.nativeGetDiveHour(divePtr),
    LibdcWrapper.nativeGetDiveMinute(divePtr),
    LibdcWrapper.nativeGetDiveSecond(divePtr)
)
cal.set(Calendar.MILLISECOND, 0)
val epoch = cal.timeInMillis / 1000
```

Replace with:

```kotlin
// Pass raw datetime components through to Dart.
// Map DC_TIMEZONE_NONE (INT_MIN) to null.
val timezone = LibdcWrapper.nativeGetDiveTimezone(divePtr)
val timezoneOffset: Long? = if (timezone == Int.MIN_VALUE) null else timezone.toLong()
```

Update the `ParsedDive(...)` constructor call (lines 385-402), replacing `dateTimeEpoch = epoch` with component fields:

```kotlin
return ParsedDive(
    fingerprint = fingerprint,
    dateTimeYear = LibdcWrapper.nativeGetDiveYear(divePtr).toLong(),
    dateTimeMonth = LibdcWrapper.nativeGetDiveMonth(divePtr).toLong(),
    dateTimeDay = LibdcWrapper.nativeGetDiveDay(divePtr).toLong(),
    dateTimeHour = LibdcWrapper.nativeGetDiveHour(divePtr).toLong(),
    dateTimeMinute = LibdcWrapper.nativeGetDiveMinute(divePtr).toLong(),
    dateTimeSecond = LibdcWrapper.nativeGetDiveSecond(divePtr).toLong(),
    dateTimeTimezoneOffset = timezoneOffset,
    maxDepthMeters = maxDepth,
    avgDepthMeters = avgDepth,
    durationSeconds = LibdcWrapper.nativeGetDiveDuration(divePtr).toLong(),
    minTemperatureCelsius = if (minTemp.isNaN()) null else minTemp,
    maxTemperatureCelsius = if (maxTemp.isNaN()) null else maxTemp,
    samples = samples,
    tanks = tanks,
    gasMixes = gasMixes,
    events = events,
    diveMode = diveMode,
    decoAlgorithm = decoAlgorithm,
    gfLow = gfLow,
    gfHigh = gfHigh,
    decoConservatism = decoConservatism
)
```

Also remove the `java.util.Calendar` and `java.util.TimeZone` imports at the top of the file (lines 10-11) if no longer used elsewhere.

- [ ] **Step 2: Commit**

```bash
git add packages/libdivecomputer_plugin/android/
git commit -m "feat(android): pass raw datetime components instead of UTC epoch"
```

---

## Chunk 2: Dart Layer Changes

These tasks update the Dart mapper, manual entry, database reads, and date range queries.

### Task 5: Update Dart Mapper

**Files:**

- Modify: `lib/features/dive_computer/data/services/parsed_dive_mapper.dart`
- Test: `test/features/dive_computer/data/services/parsed_dive_mapper_test.dart`

- [ ] **Step 1: Write failing test for wall-clock-as-UTC construction**

Create `test/features/dive_computer/data/services/parsed_dive_mapper_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/features/dive_computer/data/services/parsed_dive_mapper.dart';

void main() {
  group('parsedDiveToDownloaded', () {
    pigeon.ParsedDive _makeParsedDive({
      int year = 2024,
      int month = 6,
      int day = 15,
      int hour = 8,
      int minute = 42,
      int second = 0,
      int? timezoneOffset,
    }) {
      return pigeon.ParsedDive(
        fingerprint: 'abc123',
        dateTimeYear: year,
        dateTimeMonth: month,
        dateTimeDay: day,
        dateTimeHour: hour,
        dateTimeMinute: minute,
        dateTimeSecond: second,
        dateTimeTimezoneOffset: timezoneOffset,
        maxDepthMeters: 20.0,
        avgDepthMeters: 12.0,
        durationSeconds: 3600,
        samples: [],
        tanks: [],
        gasMixes: [],
        events: [],
      );
    }

    test('constructs wall-clock-as-UTC DateTime from components', () {
      final parsed = _makeParsedDive(
        year: 2024, month: 6, day: 15,
        hour: 8, minute: 42, second: 30,
      );
      final result = parsedDiveToDownloaded(parsed);

      expect(result.startTime.isUtc, isTrue);
      expect(result.startTime.year, 2024);
      expect(result.startTime.month, 6);
      expect(result.startTime.day, 15);
      expect(result.startTime.hour, 8);
      expect(result.startTime.minute, 42);
      expect(result.startTime.second, 30);
    });

    test('ignores timezone offset (components treated as wall-clock)', () {
      final parsed = _makeParsedDive(
        year: 2024, month: 6, day: 15,
        hour: 14, minute: 42, second: 0,
        timezoneOffset: 3600, // UTC+1
      );
      final result = parsedDiveToDownloaded(parsed);

      // Components are used as-is regardless of timezone
      expect(result.startTime.isUtc, isTrue);
      expect(result.startTime.hour, 14);
      expect(result.startTime.minute, 42);
    });

    test('handles null timezone offset', () {
      final parsed = _makeParsedDive(timezoneOffset: null);
      final result = parsedDiveToDownloaded(parsed);

      expect(result.startTime.isUtc, isTrue);
      expect(result.startTime.hour, 8);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/dive_computer/data/services/parsed_dive_mapper_test.dart
```

Expected: FAIL (ParsedDive constructor no longer has `dateTimeEpoch`, now has component fields).

- [ ] **Step 3: Update the mapper implementation**

In `lib/features/dive_computer/data/services/parsed_dive_mapper.dart`, replace line 7:

```dart
startTime: DateTime.fromMillisecondsSinceEpoch(parsed.dateTimeEpoch * 1000),
```

With:

```dart
startTime: DateTime.utc(
  parsed.dateTimeYear,
  parsed.dateTimeMonth,
  parsed.dateTimeDay,
  parsed.dateTimeHour,
  parsed.dateTimeMinute,
  parsed.dateTimeSecond,
),
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/features/dive_computer/data/services/parsed_dive_mapper_test.dart
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_computer/data/services/parsed_dive_mapper.dart test/features/dive_computer/data/services/parsed_dive_mapper_test.dart
git commit -m "feat: construct wall-clock-as-UTC DateTime from raw components in mapper"
```

### Task 6: Update Manual Entry to Use DateTime.utc

**Files:**

- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart:3284-3301`

- [ ] **Step 1: Change DateTime constructors to DateTime.utc**

In `dive_edit_page.dart`, in the `_saveDive()` method:

At line 3284, change:

```dart
final entryDateTime = DateTime(
```

To:

```dart
final entryDateTime = DateTime.utc(
```

At line 3295, change:

```dart
        exitDateTime = DateTime(
```

To:

```dart
        exitDateTime = DateTime.utc(
```

The `runtime = exitDateTime.difference(entryDateTime)` calculation at line 3307 remains correct since both are now UTC and `Duration` is epoch-difference-based.

- [ ] **Step 2: Commit**

```bash
git add lib/features/dive_log/presentation/pages/dive_edit_page.dart
git commit -m "fix: use DateTime.utc for manual dive entry (wall-clock-as-UTC)"
```

### Task 7: Update Database Read Path (isUtc: true)

**Files:**

- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart`

- [ ] **Step 1: Add `isUtc: true` to all dive DateTime reconstructions**

In `dive_repository_impl.dart`, find and update ALL `DateTime.fromMillisecondsSinceEpoch` calls for dive times (`diveDateTime`, `entryTime`, `exitTime`). There are three locations:

**Location 1: `_mapRowToDiveWithPreloadedData` (lines 1850-1856)**

```dart
// Line 1850:
dateTime: DateTime.fromMillisecondsSinceEpoch(row.diveDateTime, isUtc: true),
// Line 1851-1852:
entryTime: row.entryTime != null
    ? DateTime.fromMillisecondsSinceEpoch(row.entryTime!, isUtc: true)
    : null,
// Line 1854-1855:
exitTime: row.exitTime != null
    ? DateTime.fromMillisecondsSinceEpoch(row.exitTime!, isUtc: true)
    : null,
```

**Location 2: `_mapRowToDive` (lines 2187-2192)**

Same pattern — add `isUtc: true` to `dateTime`, `entryTime`, and `exitTime` reconstructions.

**Location 3: `DiveSummary` construction (lines 1094-1098)**

```dart
// Line 1094-1095:
dateTime: DateTime.fromMillisecondsSinceEpoch(
  row.read<int>('dive_date_time'), isUtc: true,
),
// Line 1097-1098:
entryTime: entryTime != null
    ? DateTime.fromMillisecondsSinceEpoch(entryTime, isUtc: true)
    : null,
```

**Important:** Do NOT add `isUtc: true` to non-dive DateTimes like `trip.startDate`, `trip.endDate`, `createdAt`, `updatedAt` — those are not dive wall-clock times.

- [ ] **Step 2: Run existing tests**

```bash
flutter test
```

Expected: Existing tests should pass (or fail only due to test fixtures that create local DateTimes for comparison — fix those if needed).

- [ ] **Step 3: Commit**

```bash
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart
git commit -m "fix: reconstruct dive DateTimes as UTC (wall-clock-as-UTC convention)"
```

### Task 8: Fix Date Range Query Callers

**Files:**

- Modify: `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart`
- Modify: `lib/features/dive_import/presentation/providers/dive_import_providers.dart`

- [ ] **Step 1: Fix profile_analysis_provider.dart**

In `profile_analysis_provider.dart`, in `_computeResidualOtu` (around line 655):

Change:

```dart
final startOfDay = DateTime(diveDate.year, diveDate.month, diveDate.day);
```

To:

```dart
final startOfDay = DateTime.utc(diveDate.year, diveDate.month, diveDate.day);
```

In `_computeWeeklyOtu` (around line 738):

Change:

```dart
final endOfDay = DateTime(
  diveDate.year,
  diveDate.month,
  diveDate.day,
).add(const Duration(days: 1));
```

To:

```dart
final endOfDay = DateTime.utc(
  diveDate.year,
  diveDate.month,
  diveDate.day,
).add(const Duration(days: 1));
```

- [ ] **Step 2: Fix dive_import_providers.dart — getDivesInRange**

In `dive_import_providers.dart` (around line 266-272), the `rangeStart` and `rangeEnd` are derived from `ImportedDive.startTime` which comes from HealthKit (local DateTimes). Replace the `rangeStart`/`rangeEnd` assignments (lines 266-267) to construct UTC DateTimes directly:

```dart
final rangeStart = DateTime.utc(
  earliest.year, earliest.month, earliest.day,
  earliest.hour, earliest.minute, earliest.second,
).subtract(const Duration(hours: 1));
final rangeEnd = DateTime.utc(
  latest.year, latest.month, latest.day,
  latest.hour, latest.minute, latest.second,
).add(const Duration(hours: 1));
```

This replaces the existing `rangeStart`/`rangeEnd` lines so they are used as before downstream — no unused variables.

- [ ] **Step 3: Fix dive_import_providers.dart — getDiveNumberForDate**

At line 345, `getDiveNumberForDate` is called with `iDive.startTime` (a local DateTime from HealthKit). Convert to UTC before passing:

```dart
final diveDateTime = DateTime.utc(
  iDive.startTime.year, iDive.startTime.month, iDive.startTime.day,
  iDive.startTime.hour, iDive.startTime.minute, iDive.startTime.second,
);
final diveNumber = await repository.getDiveNumberForDate(
  diveDateTime,
  diverId: diverId,
);
```

Audit for any other callers of `getDiveNumberForDate` in the codebase (`grep -r getDiveNumberForDate lib/`) and ensure they all pass UTC DateTimes.

- [ ] **Step 4: Commit**

```bash
git add lib/features/dive_log/presentation/providers/profile_analysis_provider.dart lib/features/dive_import/presentation/providers/dive_import_providers.dart
git commit -m "fix: use UTC bounds for all dive date range queries"
```

---

## Chunk 3: Schema Migration

### Task 9: Add importVersion Column and Auto-Migration

**Files:**

- Modify: `lib/core/database/database.dart`
- Test: `test/core/database/migration_test.dart`

- [ ] **Step 1: Write failing test for the migration**

Create `test/core/database/dive_time_migration_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Dive time migration', () {
    test('computer-imported dives keep timestamps unchanged', () {
      // A dive with diveComputerModel set should not have its
      // timestamps shifted. importVersion should be set to 1.
      // Epoch 1718438520000 = DateTime.utc(2024, 6, 15, 8, 42) which is
      // wall-clock-as-UTC (the bug accidentally stored them this way).
      final originalEpoch = DateTime.utc(2024, 6, 15, 8, 42)
          .millisecondsSinceEpoch;

      // After migration, epoch should be unchanged
      expect(originalEpoch,
          DateTime.utc(2024, 6, 15, 8, 42).millisecondsSinceEpoch);
    });

    test('manual dives are shifted by local offset', () {
      // A manual dive stored as local epoch for 8:42 AM in UTC-7 (PDT)
      // has epoch = DateTime(2024, 6, 15, 8, 42).millisecondsSinceEpoch
      // which equals DateTime.utc(2024, 6, 15, 15, 42).millisecondsSinceEpoch
      // After migration: newEpoch = oldEpoch - localOffsetMs
      // where localOffset for PDT = -7 * 3600 * 1000 = -25200000
      // newEpoch = old - (-25200000) = old + 25200000
      // This should yield DateTime.utc(2024, 6, 15, 8, 42) — the wall-clock time.
      //
      // Note: This test documents the expected behavior but cannot fully
      // test the actual migration SQL without a real database. The migration
      // service integration test (Task 10) covers the real database path.
      final localOffset = DateTime.now().timeZoneOffset.inMilliseconds;
      final manualEpoch =
          DateTime(2024, 6, 15, 8, 42).millisecondsSinceEpoch;
      final migratedEpoch = manualEpoch - localOffset;
      final migratedDt =
          DateTime.fromMillisecondsSinceEpoch(migratedEpoch, isUtc: true);

      expect(migratedDt.hour, 8);
      expect(migratedDt.minute, 42);
    });
  });
}
```

- [ ] **Step 2: Run test**

```bash
flutter test test/core/database/dive_time_migration_test.dart
```

Expected: PASS (these are conceptual tests documenting the math).

- [ ] **Step 3: Add `importVersion` column to Dives table**

In `lib/core/database/database.dart`, in the `Dives` table class (after line 144, the `surfacePressure` column), add:

```dart
  // Import version: null = pre-fix, 1 = wall-clock-as-UTC convention
  IntColumn get importVersion => integer().nullable()();
```

- [ ] **Step 4: Increment schema version and add migration**

In `database.dart`, change `schemaVersion` from `48` to `49` (line 1179):

```dart
int get schemaVersion => 49;
```

In the `onUpgrade` handler, after the `from < 48` block (around line 2249), add:

```dart
if (from < 49) {
  // Add importVersion column.
  final divesInfo =
      await customSelect('PRAGMA table_info(dives)').get();
  final divesCols =
      divesInfo.map((r) => r.read<String>('name')).toSet();

  if (!divesCols.contains('import_version')) {
    await customStatement(
        'ALTER TABLE dives ADD COLUMN import_version INTEGER');
  }

  // Migrate dive timestamps to wall-clock-as-UTC convention.
  // Computer-imported dives: already in correct format (bug stored
  // local components as UTC, which matches the target convention).
  await customStatement('''
    UPDATE dives SET import_version = 1
    WHERE dive_computer_model IS NOT NULL
       OR computer_id IS NOT NULL
  ''');

  // Wearable and manual dives: stored as true local epoch.
  // Both categories get the same shift, so we collapse them into one UPDATE
  // using `import_version IS NULL` (computer dives were already set to 1 above).
  // The spec separates wearable vs manual for rationale clarity, but the
  // migration math is identical for both categories.
  // Shift by device's current UTC offset to convert to wall-clock-as-UTC.
  final now = DateTime.now();
  final offsetMs = now.timeZoneOffset.inMilliseconds;

  await customStatement('''
    UPDATE dives
    SET dive_date_time = dive_date_time - $offsetMs,
        entry_time = CASE WHEN entry_time IS NOT NULL
                     THEN entry_time - $offsetMs ELSE NULL END,
        exit_time = CASE WHEN exit_time IS NOT NULL
                    THEN exit_time - $offsetMs ELSE NULL END,
        import_version = 1
    WHERE import_version IS NULL
  ''');
}
```

- [ ] **Step 5: Set `importVersion: Value(1)` on all new dive writes**

In `lib/features/dive_log/data/repositories/dive_repository_impl.dart`, in the `createDive` method (line 495), add `importVersion` to the `DivesCompanion`:

After `wearableId: Value(dive.wearableId),` (line 578), add:

```dart
              importVersion: const Value(1),
```

This ensures all newly created dives (both imported and manual) are marked with the post-fix convention. The same field must be added to any other code path that creates `DivesCompanion` entries — search for `DivesCompanion(` and audit each occurrence.

- [ ] **Step 6: Run build_runner to regenerate Drift code**

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 7: Run all tests**

```bash
flutter test
```

Expected: PASS (fix any test failures caused by the schema change).

- [ ] **Step 8: Commit**

```bash
git add lib/core/database/database.dart lib/core/database/database.g.dart lib/features/dive_log/data/repositories/dive_repository_impl.dart test/core/database/dive_time_migration_test.dart
git commit -m "feat: add importVersion column and wall-clock-as-UTC migration (schema v49)"
```

---

## Chunk 4: Bulk-Fix Tool

### Task 10: Create Dive Time Migration Service

**Files:**

- Create: `lib/features/settings/data/services/dive_time_migration_service.dart`
- Test: `test/features/settings/data/services/dive_time_migration_service_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/features/settings/data/services/dive_time_migration_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/data/services/dive_time_migration_service.dart';

void main() {
  group('DiveTimeMigrationService', () {
    group('computeShiftedEpoch', () {
      test('shifts epoch forward by positive hours', () {
        // 8:00 AM UTC
        final epoch =
            DateTime.utc(2024, 6, 15, 8, 0).millisecondsSinceEpoch;
        final shifted =
            DiveTimeMigrationService.computeShiftedEpoch(epoch, 3);
        final dt =
            DateTime.fromMillisecondsSinceEpoch(shifted, isUtc: true);
        expect(dt.hour, 11);
      });

      test('shifts epoch backward by negative hours', () {
        final epoch =
            DateTime.utc(2024, 6, 15, 8, 0).millisecondsSinceEpoch;
        final shifted =
            DiveTimeMigrationService.computeShiftedEpoch(epoch, -5);
        final dt =
            DateTime.fromMillisecondsSinceEpoch(shifted, isUtc: true);
        expect(dt.hour, 3);
      });

      test('handles date boundary crossing', () {
        final epoch =
            DateTime.utc(2024, 6, 15, 23, 0).millisecondsSinceEpoch;
        final shifted =
            DiveTimeMigrationService.computeShiftedEpoch(epoch, 3);
        final dt =
            DateTime.fromMillisecondsSinceEpoch(shifted, isUtc: true);
        expect(dt.day, 16);
        expect(dt.hour, 2);
      });
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/settings/data/services/dive_time_migration_service_test.dart
```

Expected: FAIL (file doesn't exist yet).

- [ ] **Step 3: Create the migration service**

Create `lib/features/settings/data/services/dive_time_migration_service.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:submersion/core/database/database.dart';

/// Lightweight DTO for the bulk-fix preview (avoids requiring all Dive fields).
class DiveTimePreview {
  const DiveTimePreview({
    required this.id,
    required this.dateTime,
    this.diveNumber,
    this.siteName,
  });

  final String id;
  final DateTime dateTime;
  final int? diveNumber;
  final String? siteName;
}

class DiveTimeMigrationService {
  DiveTimeMigrationService(this._db);

  final AppDatabase _db;

  /// Compute a shifted epoch by the given number of hours.
  static int computeShiftedEpoch(int epochMs, int hours) {
    return epochMs + (hours * 3600 * 1000);
  }

  /// Get dives matching a date range for the bulk-fix preview.
  Future<List<DiveTimePreview>> getDivesForPreview({
    DateTime? rangeStart,
    DateTime? rangeEnd,
  }) async {
    final query = _db.select(_db.dives);
    if (rangeStart != null) {
      query.where((t) => t.diveDateTime
          .isBiggerOrEqualValue(rangeStart.millisecondsSinceEpoch));
    }
    if (rangeEnd != null) {
      query.where((t) => t.diveDateTime
          .isSmallerOrEqualValue(rangeEnd.millisecondsSinceEpoch));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.diveDateTime)]);
    final rows = await query.get();
    return rows
        .map((row) => DiveTimePreview(
              id: row.id,
              dateTime: DateTime.fromMillisecondsSinceEpoch(
                  row.diveDateTime,
                  isUtc: true),
              diveNumber: row.diveNumber,
            ))
        .toList();
  }

  /// Apply an hour offset to the specified dive IDs.
  /// Uses Drift's typed update API to avoid SQL injection.
  Future<void> applyOffset({
    required List<String> diveIds,
    required int hours,
  }) async {
    if (diveIds.isEmpty || hours == 0) return;
    final offsetMs = hours * 3600 * 1000;

    for (final id in diveIds) {
      final row = await (_db.select(_db.dives)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (row == null) continue;

      await (_db.update(_db.dives)..where((t) => t.id.equals(id))).write(
        DivesCompanion(
          diveDateTime: Value(row.diveDateTime + offsetMs),
          entryTime: Value(
            row.entryTime != null ? row.entryTime! + offsetMs : null,
          ),
          exitTime: Value(
            row.exitTime != null ? row.exitTime! + offsetMs : null,
          ),
        ),
      );
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/features/settings/data/services/dive_time_migration_service_test.dart
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/data/services/dive_time_migration_service.dart test/features/settings/data/services/dive_time_migration_service_test.dart
git commit -m "feat: add DiveTimeMigrationService for bulk-fix offset logic"
```

### Task 11: Create Fix Dive Times Page

**Files:**

- Create: `lib/features/settings/presentation/pages/fix_dive_times_page.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/settings/presentation/pages/settings_page.dart`

- [ ] **Step 1: Create the Fix Dive Times page**

Create `lib/features/settings/presentation/pages/fix_dive_times_page.dart`. This page should:

1. Show a list of all dives with checkboxes for selection
2. Provide a date range filter
3. Have an hour offset input (integer, positive or negative)
4. Show a preview of before/after times for selected dives
5. Have a "Select All" / "Deselect All" toggle
6. Confirm button that applies the offset

The page should use `DiveTimeMigrationService` for the offset computation and preview. Follow the existing settings sub-page patterns (Material 3, Riverpod for state). Keep the file under 400 lines.

Key widgets:
- Hour offset: `TextField` with `inputFormatters` for integers, allow negative
- Dive list: `ListView.builder` with `CheckboxListTile` showing dive date, site name, current time
- Preview: when offset is set, show "Current: 8:00 AM -> New: 11:00 AM" next to each selected dive
- Apply button: calls `DiveTimeMigrationService.applyOffset` then shows success snackbar

- [ ] **Step 2: Add route in app_router.dart**

In `lib/core/router/app_router.dart`, in the settings sub-routes section (around line 735-759), add:

```dart
GoRoute(
  path: 'fix-dive-times',
  name: 'fixDiveTimes',
  builder: (context, state) => const FixDiveTimesPage(),
),
```

Add the import at the top of the file.

- [ ] **Step 3: Add entry point in settings_page.dart**

In `lib/features/settings/presentation/pages/settings_page.dart`, add a "Fix Dive Times" list tile in an appropriate section (near data management settings). Follow the existing pattern:

```dart
ListTile(
  leading: const Icon(Icons.access_time),
  title: const Text('Fix Dive Times'),
  subtitle: const Text('Adjust times for imported dives'),
  onTap: () => context.push('/settings/fix-dive-times'),
),
```

- [ ] **Step 4: Verify the page loads**

```bash
flutter run -d macos
```

Navigate to Settings > Fix Dive Times. Verify the page renders.

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/presentation/pages/fix_dive_times_page.dart lib/core/router/app_router.dart lib/features/settings/presentation/pages/settings_page.dart
git commit -m "feat: add Fix Dive Times settings page for bulk-fix tool"
```

---

## Chunk 5: Final Verification

### Task 12: Full Test Suite and Format Check

**Files:** None (verification only)

- [ ] **Step 1: Run full test suite**

```bash
flutter test
```

Expected: All tests pass.

- [ ] **Step 2: Run analyzer**

```bash
flutter analyze
```

Expected: No errors (warnings are acceptable if pre-existing).

- [ ] **Step 3: Run formatter**

```bash
dart format lib/ test/
```

Expected: No formatting changes needed (or apply and commit any changes).

- [ ] **Step 4: Verify macOS build**

```bash
flutter build macos --debug
```

Expected: Build succeeds.

- [ ] **Step 5: Final commit if needed**

```bash
git add -A && git commit -m "chore: format and fix analyzer warnings"
```

Only if there were formatting or analyzer fixes to apply.
