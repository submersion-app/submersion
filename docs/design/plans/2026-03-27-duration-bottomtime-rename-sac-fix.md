# Duration to BottomTime Rename + SAC Calculation Fix

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename `Dive.duration` to `Dive.bottomTime` for clarity, add `effectiveRuntime` getter, and fix SAC calculations to use runtime instead of bottom time (fixes issues #72, #87).

**Architecture:** Two-phase approach. Phase 1 is a pure mechanical rename across ~90 files with zero behavior change (all tests pass identically). Phase 2 adds `effectiveRuntime` and fixes SAC to use runtime, producing correct consumption rates.

**Tech Stack:** Flutter/Dart, Drift ORM (SQLite), Riverpod

**Spec:** `docs/superpowers/specs/2026-03-25-duration-bottomtime-rename-design.md`

---

## File Map

### Phase 1: Rename (files to modify)

**Domain Layer:**
- `lib/features/dive_log/domain/entities/dive.dart` — field, constructor, copyWith, props, getters
- `lib/features/dive_log/domain/entities/dive_summary.dart` — field, constructor, copyWith, props, fromDive

**Constants/Models:**
- `lib/core/constants/sort_options.dart` — `DiveSortField.duration` enum value
- `lib/features/dive_log/domain/models/dive_filter_state.dart` — filter fields and logic

**Database:**
- `lib/core/database/database.dart` — column definition + new migration

**Repository:**
- `lib/features/dive_log/data/repositories/dive_repository_impl.dart` — raw SQL + mappings

**Services:**
- `lib/features/dive_log/domain/services/field_attribution_service.dart` — attribution key
- `lib/features/statistics/data/repositories/statistics_repository.dart` — raw SQL SAC queries

**Import/Export:**
- `lib/features/dive_import/domain/services/imported_dive_converter.dart`
- `lib/features/dive_import/data/services/uddf_entity_importer.dart`
- `lib/core/services/export/csv/csv_export_service.dart`
- `lib/core/services/export/excel/excel_export_service.dart`
- `lib/core/services/export/pdf/pdf_export_service.dart`
- `lib/core/services/export/kml/kml_export_service.dart`
- `lib/core/services/export/uddf/uddf_export_service.dart`
- `lib/core/services/export/uddf/uddf_export_builders.dart`
- `lib/core/services/pdf_templates/pdf_template_naui.dart`
- `lib/core/services/pdf_templates/pdf_template_padi.dart`
- `lib/core/services/pdf_templates/pdf_template_professional.dart`
- `lib/core/services/pdf_templates/pdf_template_detailed.dart`
- `lib/core/services/pdf_templates/pdf_shared_components.dart`

**Presentation:**
- `lib/features/dive_log/presentation/providers/dive_providers.dart`
- `lib/features/dive_log/presentation/widgets/dive_list_content.dart`
- `lib/features/dive_log/presentation/widgets/merge_dive_dialog.dart`
- `lib/features/dive_log/presentation/widgets/dive_map_content.dart`
- `lib/features/dive_log/presentation/widgets/dive_summary_widget.dart`
- `lib/features/dive_log/presentation/widgets/dense_dive_list_tile.dart`
- `lib/features/dive_log/presentation/widgets/compact_dive_list_tile.dart`
- `lib/features/dive_log/presentation/pages/dive_search_page.dart`
- `lib/features/dive_log/presentation/pages/dive_list_page.dart`
- `lib/features/dive_log/presentation/pages/dive_detail_page.dart`
- `lib/features/dive_log/presentation/pages/dive_edit_page.dart`
- `lib/features/dashboard/presentation/widgets/recent_dives_card.dart`
- `lib/features/trips/presentation/widgets/trip_overview_tab.dart`

**Tests (partial list — grep for all):**
- `test/features/dive_log/data/repositories/dive_repository_test.dart`
- `test/features/dive_log/data/repositories/dive_repository_new_methods_test.dart`
- `test/features/dive_log/domain/models/dive_filter_state_test.dart`
- `test/features/dive_import/presentation/providers/dive_import_notifier_test.dart`
- `test/features/dive_log/integration/multi_computer_integration_test.dart`
- `test/features/dive_log/domain/services/field_attribution_service_test.dart`
- `test/features/dive_log/data/repositories/dive_consolidation_test.dart`
- `test/helpers/performance_data_generator.dart`
- `integration_test/helpers/uddf_screenshot_helper.dart`
- `test/integration/uddf_test_importer.dart`
- Additional test files found by grep

### Phase 2: SAC Fix (files to modify or create)

- `lib/features/dive_log/domain/entities/dive.dart` — add `effectiveRuntime`, fix `sac`/`sacPressure`
- `lib/features/dive_log/data/services/gas_analysis_service.dart` — fix `calculateCylinderSac`
- `lib/features/statistics/data/repositories/statistics_repository.dart` — fix SQL SAC queries
- `lib/features/media/presentation/helpers/photo_import_helper.dart` — use `effectiveRuntime`
- `lib/features/dive_log/presentation/pages/dive_detail_page.dart` — use `effectiveRuntime`
- `lib/features/dive_log/data/repositories/dive_repository_impl.dart` — use `effectiveRuntime`
- `lib/features/dive_log/presentation/pages/dive_edit_page.dart` — rename local variables
- `test/features/dive_log/domain/entities/dive_effective_runtime_test.dart` — NEW
- `test/features/dive_log/domain/entities/dive_sac_test.dart` — NEW or update existing

### Files NOT renamed (different concept)

- `lib/features/dive_log/domain/entities/dive_data_source.dart` — `DiveDataSource.duration` stores runtime
- `lib/features/dive_import/domain/entities/imported_dive.dart` — `ImportedDive.duration` is runtime
- `lib/core/domain/models/incoming_dive_data.dart` — `IncomingDiveData.durationSeconds` is runtime
- `lib/core/domain/models/dive_comparison_result.dart` — `ComparisonFieldType.duration` is generic
- `lib/features/dive_log/presentation/widgets/data_sources_section.dart` — displays `DiveDataSource.duration` (runtime)
- `lib/features/dive_computer/domain/entities/downloaded_dive.dart` — `DownloadedDive.duration` is runtime

---

## Task 0: Worktree Setup

**Files:** None (infrastructure)

- [ ] **Step 1: Create git worktree**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
git worktree add .claude/worktrees/sac-fix main
cd .claude/worktrees/sac-fix
```

- [ ] **Step 2: Create feature branch**

```bash
git checkout -b feature/duration-bottomtime-rename-sac-fix
```

- [ ] **Step 3: Initialize worktree**

Per CLAUDE.md, worktrees need explicit submodule init and dependency install:

```bash
git submodule update --init --recursive
flutter pub get
```

- [ ] **Step 4: Verify clean build**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
```

Expected: No errors.

---

## Task 1: Database Migration

**Files:**
- Modify: `lib/core/database/database.dart`

- [ ] **Step 1: Read current schema version**

Read `lib/core/database/database.dart` and find `currentSchemaVersion`. Currently at version 55 (line 1241).

- [ ] **Step 2: Rename column definition**

In the `Dives` table class, change:

```dart
// Before (line 115):
IntColumn get duration => integer().nullable()(); // seconds (bottom time)

// After:
IntColumn get bottomTime => integer().nullable()(); // seconds (bottom time)
```

- [ ] **Step 3: Bump schema version**

```dart
// Before:
static const int currentSchemaVersion = 55;

// After:
static const int currentSchemaVersion = 56;
```

- [ ] **Step 4: Add migration case**

In the `onUpgrade` migration handler, add a case for version 56. Find the migration switch/if chain and add:

```dart
if (from < 56) {
  await m.database.customStatement(
    'ALTER TABLE dives RENAME COLUMN duration TO bottom_time',
  );
}
```

- [ ] **Step 5: Run codegen**

```bash
dart run build_runner build --delete-conflicting-outputs
```

This regenerates Drift classes with the new column name `bottomTime`.

- [ ] **Step 6: Commit**

```bash
git add lib/core/database/database.dart lib/core/database/database.g.dart
git commit -m "db: rename dives.duration column to bottom_time (migration v56)"
```

---

## Task 2: Domain Entities Rename

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive.dart`
- Modify: `lib/features/dive_log/domain/entities/dive_summary.dart`

- [ ] **Step 1: Rename in Dive entity**

In `lib/features/dive_log/domain/entities/dive.dart`, apply these renames:

Field declaration (line 21):
```dart
// Before:
final Duration? duration; // Bottom time

// After:
final Duration? bottomTime; // Bottom time
```

Constructor parameter (line 132):
```dart
// Before:
this.duration,

// After:
this.bottomTime,
```

`calculatedDuration` getter (lines 225-231) — rename to `calculatedBottomTime` for now (Phase 2 will replace callers):
```dart
// Before:
/// Calculated duration from entry/exit times
Duration? get calculatedDuration {
  if (entryTime != null && exitTime != null) {
    return exitTime!.difference(entryTime!);
  }
  return duration;
}

// After:
/// Calculated duration from entry/exit times
Duration? get calculatedDuration {
  if (entryTime != null && exitTime != null) {
    return exitTime!.difference(entryTime!);
  }
  return bottomTime;
}
```

Note: We keep the name `calculatedDuration` in Phase 1 to avoid changing caller behavior. Phase 2 replaces it with `effectiveRuntime`.

SAC getters — rename `duration` to `bottomTime` (lines 263-303). Both `sac` and `sacPressure` getters:
```dart
// Before (in both getters):
if (tanks.isEmpty || duration == null || avgDepth == null) return null;
final minutes = duration!.inSeconds / 60;

// After (in both getters):
if (tanks.isEmpty || bottomTime == null || avgDepth == null) return null;
final minutes = bottomTime!.inSeconds / 60;
```

Note: This is Phase 1 — we rename the field reference but keep the same behavior (still using bottom time). Phase 2 switches to `effectiveRuntime`.

`calculateBottomTimeFromProfile()` method — no rename needed (already correct name).

`calculateRuntimeFromProfile()` method — no rename needed.

`copyWith` parameter (line 446):
```dart
// Before:
Duration? duration,

// After:
Duration? bottomTime,
```

`copyWith` body (line 531):
```dart
// Before:
duration: duration ?? this.duration,

// After:
bottomTime: bottomTime ?? this.bottomTime,
```

`props` list (line 619):
```dart
// Before:
duration,

// After:
bottomTime,
```

Search for any other `duration` references within this file that refer to the field (not the Duration type or other entities) and rename them.

- [ ] **Step 2: Rename in DiveSummary entity**

In `lib/features/dive_log/domain/entities/dive_summary.dart`:

Field (line 17):
```dart
// Before:
final Duration? duration;

// After:
final Duration? bottomTime;
```

Constructor (line 41):
```dart
// Before:
this.duration,

// After:
this.bottomTime,
```

`fromDive` factory (line 69):
```dart
// Before:
duration: dive.duration,

// After:
bottomTime: dive.bottomTime,
```

`copyWith` parameter (line 103) and body (line 123):
```dart
// Before:
Duration? duration,
...
duration: duration ?? this.duration,

// After:
Duration? bottomTime,
...
bottomTime: bottomTime ?? this.bottomTime,
```

`props` (line 146):
```dart
// Before:
duration,

// After:
bottomTime,
```

- [ ] **Step 3: Verify compilation**

```bash
flutter analyze lib/features/dive_log/domain/entities/dive.dart lib/features/dive_log/domain/entities/dive_summary.dart
```

Expected: Errors in downstream files referencing `.duration` on Dive/DiveSummary (expected — we fix those in subsequent tasks).

- [ ] **Step 4: Commit**

```bash
git add lib/features/dive_log/domain/entities/dive.dart lib/features/dive_log/domain/entities/dive_summary.dart
git commit -m "refactor: rename Dive.duration and DiveSummary.duration to bottomTime"
```

---

## Task 3: Constants, Models, and Providers Rename

**Files:**
- Modify: `lib/core/constants/sort_options.dart`
- Modify: `lib/features/dive_log/domain/models/dive_filter_state.dart`
- Modify: `lib/features/dive_log/presentation/providers/dive_providers.dart`

- [ ] **Step 1: Rename DiveSortField enum value**

In `lib/core/constants/sort_options.dart` (line 21):
```dart
// Before:
duration('Duration', Icons.timer),

// After:
bottomTime('Bottom Time', Icons.timer),
```

- [ ] **Step 2: Rename DiveFilterState fields**

In `lib/features/dive_log/domain/models/dive_filter_state.dart`, rename all occurrences:

- `minDurationMinutes` → `minBottomTimeMinutes` (lines 27, 51, 76, 99, 157, 243+)
- `maxDurationMinutes` → `maxBottomTimeMinutes` (lines 28, 52, 77, 100, 162, 248+)

In the `apply()` method (around line 243):
```dart
// Before:
if (minDurationMinutes != null || maxDurationMinutes != null) {
  final durationMinutes = dive.duration?.inMinutes;

// After:
if (minBottomTimeMinutes != null || maxBottomTimeMinutes != null) {
  final bottomTimeMinutes = dive.bottomTime?.inMinutes;
```

Update all filter logic referencing the renamed fields.

- [ ] **Step 3: Rename in dive_providers.dart**

In `lib/features/dive_log/presentation/providers/dive_providers.dart` (lines 73-76):
```dart
// Before:
case DiveSortField.duration:
  final aDuration = a.duration?.inMinutes ?? 0;
  final bDuration = b.duration?.inMinutes ?? 0;
  comparison = aDuration.compareTo(bDuration);

// After:
case DiveSortField.bottomTime:
  final aBottomTime = a.bottomTime?.inMinutes ?? 0;
  final bBottomTime = b.bottomTime?.inMinutes ?? 0;
  comparison = aBottomTime.compareTo(bBottomTime);
```

- [ ] **Step 4: Commit**

```bash
git add lib/core/constants/sort_options.dart lib/features/dive_log/domain/models/dive_filter_state.dart lib/features/dive_log/presentation/providers/dive_providers.dart
git commit -m "refactor: rename sort/filter duration fields to bottomTime"
```

---

## Task 4: Repository Layer Rename

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart`

This file has many references. Apply these changes:

- [ ] **Step 1: Rename SQL column references**

Change all `d.duration` to `d.bottom_time` in raw SQL strings. Key locations:

Line 1102 (SELECT):
```dart
// Before:
'd.max_depth, d.duration, d.runtime, d.water_temp, d.rating, '

// After:
'd.max_depth, d.bottom_time, d.runtime, d.water_temp, d.rating, '
```

Line 1132 (row read):
```dart
// Before:
final duration = row.readNullable<int>('duration');

// After:
final bottomTime = row.readNullable<int>('bottom_time');
```

Line 1146 (mapping):
```dart
// Before:
duration: duration != null ? Duration(seconds: duration) : null,

// After:
bottomTime: bottomTime != null ? Duration(seconds: bottomTime) : null,
```

Lines 1229-1230 (sort):
```dart
// Before:
case DiveSortField.duration:
  return 'COALESCE(d.duration, 0) $dir, $tiebreaker';

// After:
case DiveSortField.bottomTime:
  return 'COALESCE(d.bottom_time, 0) $dir, $tiebreaker';
```

Lines 1345-1351 (filter):
```dart
// Before:
if (filter.minDurationMinutes != null) {
  clauses.add('d.duration >= ?');
  args.add(Variable(filter.minDurationMinutes! * 60));
}
if (filter.maxDurationMinutes != null) {
  clauses.add('d.duration <= ?');
  args.add(Variable(filter.maxDurationMinutes! * 60));
}

// After:
if (filter.minBottomTimeMinutes != null) {
  clauses.add('d.bottom_time >= ?');
  args.add(Variable(filter.minBottomTimeMinutes! * 60));
}
if (filter.maxBottomTimeMinutes != null) {
  clauses.add('d.bottom_time <= ?');
  args.add(Variable(filter.maxBottomTimeMinutes! * 60));
}
```

Line 1586 (statistics):
```dart
// Before:
SUM(duration) as total_time,

// After:
SUM(bottom_time) as total_time,
```

Lines 1734-1735 (records):
```dart
// Before:
WHERE d.duration IS NOT NULL $diverFilter
ORDER BY d.duration DESC

// After:
WHERE d.bottom_time IS NOT NULL $diverFilter
ORDER BY d.bottom_time DESC
```

- [ ] **Step 2: Rename Drift-generated mappings**

Find all locations where the Drift-generated `row.duration` is used in domain mapping and rename to `row.bottomTime`:

Line 2265:
```dart
// Before:
duration: row.duration != null ? Duration(seconds: row.duration!) : null,

// After:
bottomTime: row.bottomTime != null ? Duration(seconds: row.bottomTime!) : null,
```

Search the file for any other `.duration` references that map to the Dive entity's bottom time field and rename them.

- [ ] **Step 3: Rename all remaining `d.duration` SQL references**

Use grep within this file to find any remaining `d.duration` or `duration` SQL references and update them. There are additional occurrences around lines 3348, 3473, 3576, 3706.

- [ ] **Step 4: Commit**

```bash
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart
git commit -m "refactor: rename duration to bottom_time in repository SQL and mappings"
```

---

## Task 5: Services Rename

**Files:**
- Modify: `lib/features/dive_log/domain/services/field_attribution_service.dart`
- Modify: `lib/features/dive_log/data/services/gas_analysis_service.dart`
- Modify: `lib/features/statistics/data/repositories/statistics_repository.dart`

- [ ] **Step 1: Rename in field_attribution_service.dart**

Line 37:
```dart
// Before:
if (activeSource.duration != null) attribution['duration'] = name;

// After:
if (activeSource.duration != null) attribution['bottomTime'] = name;
```

Note: `activeSource.duration` here is `DiveDataSource.duration` (runtime) — do NOT rename the property access. Only rename the attribution key string.

- [ ] **Step 2: Rename in gas_analysis_service.dart**

Line 245:
```dart
// Before:
diveEnd: dive.duration?.inSeconds ?? profile.lastOrNull?.timestamp ?? 0,

// After:
diveEnd: dive.bottomTime?.inSeconds ?? profile.lastOrNull?.timestamp ?? 0,
```

- [ ] **Step 3: Rename in statistics_repository.dart**

Rename all `d.duration` SQL references to `d.bottom_time`. There are 6 SQL queries (around lines 78-79, 124-125, 210-214, 259-263, 305-314):

```sql
-- Before (in all queries):
WHEN d.duration > 0 AND d.avg_depth > 0 ...
  ... / (d.duration / 60.0) / ...
WHERE d.duration > 0

-- After:
WHEN d.bottom_time > 0 AND d.avg_depth > 0 ...
  ... / (d.bottom_time / 60.0) / ...
WHERE d.bottom_time > 0
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/dive_log/domain/services/field_attribution_service.dart lib/features/dive_log/data/services/gas_analysis_service.dart lib/features/statistics/data/repositories/statistics_repository.dart
git commit -m "refactor: rename duration to bottomTime/bottom_time in services"
```

---

## Task 6: Import and Export Layer Rename

**Files:**
- Modify: `lib/features/dive_import/domain/services/imported_dive_converter.dart`
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart`
- Modify: All export service files (CSV, Excel, PDF, KML, UDDF)
- Modify: All PDF template files

- [ ] **Step 1: Rename in imported_dive_converter.dart**

Line 48:
```dart
// Before:
return dive.copyWith(duration: bottomTime);

// After:
return dive.copyWith(bottomTime: bottomTime);
```

Check for any other `duration:` named parameters in Dive constructors/copyWith calls in this file.

- [ ] **Step 2: Rename in uddf_entity_importer.dart**

Find all references to `dive.duration` or `duration:` in Dive construction and rename to `bottomTime`. Key location around line 1132:

```dart
// Before:
if (dive.duration == null && dive.profile.isNotEmpty) {
  final calculatedDuration = dive.calculateBottomTimeFromProfile();
  if (calculatedDuration != null) {
    dive = dive.copyWith(duration: calculatedDuration);

// After:
if (dive.bottomTime == null && dive.profile.isNotEmpty) {
  final calculatedBottomTime = dive.calculateBottomTimeFromProfile();
  if (calculatedBottomTime != null) {
    dive = dive.copyWith(bottomTime: calculatedBottomTime);
```

- [ ] **Step 3: Rename in export services**

For each export service, rename `dive.duration` to `dive.bottomTime`:

**CSV** (`lib/core/services/export/csv/csv_export_service.dart`):
```dart
// Before:
dive.duration?.inMinutes ?? ''
// After:
dive.bottomTime?.inMinutes ?? ''
```

**Excel** (`lib/core/services/export/excel/excel_export_service.dart`):
Replace all `dive.duration` / `d.duration` with `dive.bottomTime` / `d.bottomTime` (lines 210, 440, 461, 463-464, 499).

**PDF** (`lib/core/services/export/pdf/pdf_export_service.dart`):
Replace all `dive.duration` with `dive.bottomTime` (lines 119-120, 273-274, 417).

**KML** (`lib/core/services/export/kml/kml_export_service.dart`):
```dart
// Before:
final duration = dive.duration != null ? '${dive.duration!.inMinutes}min' : ''
// After:
final bottomTimeStr = dive.bottomTime != null ? '${dive.bottomTime!.inMinutes}min' : ''
```

**UDDF Export** (`lib/core/services/export/uddf/uddf_export_service.dart`):
```dart
// Before:
final durationSecs = dive.duration?.inSeconds ?? 0;
...
if (dive.duration != null) {

// After:
final bottomTimeSecs = dive.bottomTime?.inSeconds ?? 0;
...
if (dive.bottomTime != null) {
```

**UDDF Builders** (`lib/core/services/export/uddf/uddf_export_builders.dart`):
Same pattern — rename `dive.duration` to `dive.bottomTime`.

- [ ] **Step 4: Rename in PDF templates**

For each PDF template file, rename `d.duration` to `d.bottomTime`:
- `lib/core/services/pdf_templates/pdf_template_naui.dart`
- `lib/core/services/pdf_templates/pdf_template_padi.dart`
- `lib/core/services/pdf_templates/pdf_template_professional.dart`
- `lib/core/services/pdf_templates/pdf_template_detailed.dart`
- `lib/core/services/pdf_templates/pdf_shared_components.dart`

Pattern:
```dart
// Before:
.where((d) => d.duration != null)
.fold(Duration.zero, (sum, d) => sum + d.duration!)

// After:
.where((d) => d.bottomTime != null)
.fold(Duration.zero, (sum, d) => sum + d.bottomTime!)
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_import/ lib/core/services/export/ lib/core/services/pdf_templates/
git commit -m "refactor: rename duration to bottomTime in import/export layers"
```

---

## Task 7: Presentation Layer Rename

**Files:**
- Modify: Multiple widget and page files

- [ ] **Step 1: Rename in dive list widgets**

**dive_list_content.dart** (lines 1208, 1233, 1252):
```dart
// Before:
duration: dive.runtime ?? dive.duration,

// After:
duration: dive.runtime ?? dive.bottomTime,
```

Note: The `duration:` parameter name on the list tile widgets is a constructor parameter for "how long to display" — it is NOT the Dive.duration field. It receives runtime-or-bottomTime. After Phase 1, the field access changes but the tile parameter name stays.

**dense_dive_list_tile.dart** and **compact_dive_list_tile.dart**: If these have a `duration` constructor parameter that represents display time, leave the parameter name but update any internal references to `Dive.duration` → `Dive.bottomTime`.

**merge_dive_dialog.dart** (lines 307-308):
```dart
// Before:
final durationStr = dive.duration != null
    ? _formatDuration(dive.duration!)

// After:
final durationStr = dive.bottomTime != null
    ? _formatDuration(dive.bottomTime!)
```

**dive_map_content.dart** (lines 439-440):
```dart
// Before:
if (dive.duration != null) {
  parts.add('${dive.duration!.inMinutes} min');

// After:
if (dive.bottomTime != null) {
  parts.add('${dive.bottomTime!.inMinutes} min');
```

**dive_summary_widget.dart** (lines 271-272):
```dart
// Before:
if (records.longestDive != null && records.longestDive!.duration != null) {
  final minutes = records.longestDive!.duration!.inMinutes;

// After:
if (records.longestDive != null && records.longestDive!.bottomTime != null) {
  final minutes = records.longestDive!.bottomTime!.inMinutes;
```

- [ ] **Step 2: Rename in pages**

**dive_search_page.dart**: Rename all filter state references:
- `_minDurationMinutes` → `_minBottomTimeMinutes` (line 41)
- `_maxDurationMinutes` → `_maxBottomTimeMinutes` (line 42)
- Update all usages throughout the file (lines 93-94, 110-111, 121-122, 491, 504, 752-753, 784-785)

**dive_list_page.dart**: Same pattern for filter references:
- `minDurationMinutes` → `minBottomTimeMinutes`
- `maxDurationMinutes` → `maxBottomTimeMinutes`
- Update all usages (lines 795-796, 826-830, 1307, 1322, 1400-1401)

**dive_detail_page.dart**: Rename any `dive.duration` references to `dive.bottomTime`. Keep `dive.calculatedDuration` calls as-is (Phase 2 handles those).

**dive_edit_page.dart**: Rename `dive.duration` to `dive.bottomTime` (line 318). Keep local variable names and `calculateBottomTimeFromProfile()` calls as-is.

- [ ] **Step 3: Rename in other widgets**

**recent_dives_card.dart** and **trip_overview_tab.dart**: Search for `dive.duration` or `.duration` on Dive/DiveSummary objects and rename to `.bottomTime`.

- [ ] **Step 4: Commit**

```bash
git add lib/features/dive_log/presentation/ lib/features/dashboard/ lib/features/trips/
git commit -m "refactor: rename duration to bottomTime in presentation layer"
```

---

## Task 8: Test Files Rename

**Files:**
- Modify: All test files referencing `duration:` in Dive/DiveSummary constructors

- [ ] **Step 1: Find all test files with Dive/DiveSummary duration references**

Run from the worktree root:
```bash
grep -rn "duration:" test/ integration_test/ --include="*.dart" | grep -v "Duration\|DiveDataSource\|ImportedDive\|IncomingDiveData\|DownloadedDive\|ComparisonFieldType\|animationDuration\|timeoutDuration\|segmentDuration\|surfaceInterval\|usageDuration\|durationSeconds\|shimmerDuration\|snackBarDuration\|crossFadeDuration"
```

This filters out `duration:` usages that are NOT the Dive entity field.

- [ ] **Step 2: Rename in each test file**

For every test file that constructs `Dive(...)` or `DiveSummary(...)` with a `duration:` parameter, rename to `bottomTime:`. Key files:

```dart
// Before (in test constructors):
Dive(
  id: 'test-1',
  dateTime: DateTime.now(),
  duration: const Duration(minutes: 45),
  ...
)

// After:
Dive(
  id: 'test-1',
  dateTime: DateTime.now(),
  bottomTime: const Duration(minutes: 45),
  ...
)
```

Apply to:
- `test/features/dive_log/data/repositories/dive_repository_test.dart`
- `test/features/dive_log/data/repositories/dive_repository_new_methods_test.dart`
- `test/features/dive_log/domain/models/dive_filter_state_test.dart`
- `test/features/dive_import/presentation/providers/dive_import_notifier_test.dart`
- `test/features/dive_log/integration/multi_computer_integration_test.dart`
- `test/features/dive_log/domain/services/field_attribution_service_test.dart`
- `test/features/dive_log/data/repositories/dive_consolidation_test.dart`
- `test/helpers/performance_data_generator.dart`
- `integration_test/helpers/uddf_screenshot_helper.dart`
- `test/integration/uddf_test_importer.dart`
- Any other files found in Step 1

Also rename filter state references:
- `minDurationMinutes` → `minBottomTimeMinutes`
- `maxDurationMinutes` → `maxBottomTimeMinutes`

- [ ] **Step 3: Rename in test assertions and local variables**

Search test files for `dive.duration`, `.duration` on Dive/DiveSummary objects, and local variables named `duration` that hold Dive's bottom time. Rename to `bottomTime`.

- [ ] **Step 4: Commit**

```bash
git add test/ integration_test/
git commit -m "refactor: rename duration to bottomTime in test files"
```

---

## Task 9: Phase 1 Verification

**Files:** None (verification only)

- [ ] **Step 1: Safety grep for remaining Dive/DiveSummary duration references**

```bash
grep -rn "\.duration" lib/ test/ integration_test/ --include="*.dart" | grep -v "DiveDataSource\|ImportedDive\|IncomingDiveData\|DownloadedDive\|ComparisonFieldType\|animationDuration\|timeoutDuration\|segmentDuration\|surfaceInterval\|usageDuration\|durationSeconds\|shimmerDuration\|snackBarDuration\|crossFadeDuration\|Duration\|duration:" | head -50
```

Review output — any remaining `.duration` on Dive or DiveSummary objects indicates a missed rename.

- [ ] **Step 2: Run code generation**

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 3: Run dart format**

```bash
dart format lib/ test/
```

- [ ] **Step 4: Run flutter analyze**

```bash
flutter analyze
```

Expected: 0 issues. If there are errors, they indicate missed renames — fix them.

- [ ] **Step 5: Run full test suite**

```bash
flutter test
```

Expected: All tests pass with zero behavior change.

- [ ] **Step 6: Commit any format/fix changes**

```bash
git add -A
git commit -m "refactor: Phase 1 complete - duration renamed to bottomTime across codebase"
```

---

## Task 10: Add effectiveRuntime Getter (TDD)

**Files:**
- Create: `test/features/dive_log/domain/entities/dive_effective_runtime_test.dart`
- Modify: `lib/features/dive_log/domain/entities/dive.dart`

- [ ] **Step 1: Write failing tests for effectiveRuntime**

Create `test/features/dive_log/domain/entities/dive_effective_runtime_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  group('Dive.effectiveRuntime', () {
    test('returns runtime when set', () {
      final dive = Dive(
        id: 'test-1',
        dateTime: DateTime(2024, 1, 1),
        runtime: const Duration(minutes: 42),
        bottomTime: const Duration(minutes: 30),
        entryTime: DateTime(2024, 1, 1, 10, 0),
        exitTime: DateTime(2024, 1, 1, 10, 45),
      );

      expect(dive.effectiveRuntime, const Duration(minutes: 42));
    });

    test('falls back to exitTime - entryTime when runtime is null', () {
      final dive = Dive(
        id: 'test-2',
        dateTime: DateTime(2024, 1, 1),
        entryTime: DateTime(2024, 1, 1, 10, 0),
        exitTime: DateTime(2024, 1, 1, 10, 42),
        bottomTime: const Duration(minutes: 30),
      );

      expect(dive.effectiveRuntime, const Duration(minutes: 42));
    });

    test('falls back to profile-based runtime when entry/exit are null', () {
      final dive = Dive(
        id: 'test-3',
        dateTime: DateTime(2024, 1, 1),
        bottomTime: const Duration(minutes: 30),
        profile: [
          DiveProfilePoint(timestamp: 0, depth: 0),
          DiveProfilePoint(timestamp: 600, depth: 20.0),
          DiveProfilePoint(timestamp: 2520, depth: 0),
        ],
      );

      expect(dive.effectiveRuntime, const Duration(seconds: 2520));
    });

    test('falls back to bottomTime as last resort', () {
      final dive = Dive(
        id: 'test-4',
        dateTime: DateTime(2024, 1, 1),
        bottomTime: const Duration(minutes: 30),
      );

      expect(dive.effectiveRuntime, const Duration(minutes: 30));
    });

    test('returns null when nothing is available', () {
      final dive = Dive(
        id: 'test-5',
        dateTime: DateTime(2024, 1, 1),
      );

      expect(dive.effectiveRuntime, isNull);
    });

    test('prefers runtime over entry/exit calculation', () {
      final dive = Dive(
        id: 'test-6',
        dateTime: DateTime(2024, 1, 1),
        runtime: const Duration(minutes: 40),
        entryTime: DateTime(2024, 1, 1, 10, 0),
        exitTime: DateTime(2024, 1, 1, 10, 50),
        bottomTime: const Duration(minutes: 30),
      );

      // runtime (40 min) takes priority over exit-entry (50 min)
      expect(dive.effectiveRuntime, const Duration(minutes: 40));
    });

    test('skips entry/exit when only entryTime is set', () {
      final dive = Dive(
        id: 'test-7',
        dateTime: DateTime(2024, 1, 1),
        entryTime: DateTime(2024, 1, 1, 10, 0),
        bottomTime: const Duration(minutes: 30),
      );

      // Can't compute entry/exit, falls through to bottomTime
      expect(dive.effectiveRuntime, const Duration(minutes: 30));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/features/dive_log/domain/entities/dive_effective_runtime_test.dart
```

Expected: FAIL — `effectiveRuntime` is not defined.

- [ ] **Step 3: Implement effectiveRuntime getter**

In `lib/features/dive_log/domain/entities/dive.dart`, add after the `calculatedDuration` getter:

```dart
  /// Best available runtime for this dive.
  ///
  /// Fallback chain:
  /// 1. runtime (explicit, from dive computer/import)
  /// 2. exitTime - entryTime (computed from timestamps)
  /// 3. calculateRuntimeFromProfile() (from profile data)
  /// 4. bottomTime (approximate, but better than null)
  Duration? get effectiveRuntime {
    if (runtime != null) return runtime;

    if (entryTime != null && exitTime != null) {
      final computed = exitTime!.difference(entryTime!);
      if (!computed.isNegative && computed > Duration.zero) return computed;
    }

    final fromProfile = calculateRuntimeFromProfile();
    if (fromProfile != null) return fromProfile;

    return bottomTime;
  }
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/features/dive_log/domain/entities/dive_effective_runtime_test.dart
```

Expected: All 7 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add test/features/dive_log/domain/entities/dive_effective_runtime_test.dart lib/features/dive_log/domain/entities/dive.dart
git commit -m "feat: add Dive.effectiveRuntime getter with fallback chain"
```

---

## Task 11: Fix SAC Calculations (TDD)

**Files:**
- Create: `test/features/dive_log/domain/entities/dive_sac_fix_test.dart`
- Modify: `lib/features/dive_log/domain/entities/dive.dart`
- Modify: `lib/features/dive_log/data/services/gas_analysis_service.dart`

- [ ] **Step 1: Write failing tests for corrected SAC**

Create `test/features/dive_log/domain/entities/dive_sac_fix_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  group('Dive.sac uses effectiveRuntime', () {
    test('calculates SAC using runtime, not bottomTime (issue #72)', () {
      // Reproduce issue #72 exactly:
      // 170 bar used, AL80 (11.1L), avg depth 20.3m, runtime 42 min
      // Expected SAC: 170 * 11.1 / 42 / (20.3/10 + 1) = 14.83 L/min
      final dive = Dive(
        id: 'issue-72',
        dateTime: DateTime(2024, 1, 1),
        bottomTime: const Duration(minutes: 20),
        runtime: const Duration(minutes: 42),
        avgDepth: 20.3,
        tanks: [
          DiveTank(
            id: 't1',
            name: 'AL80',
            volume: 11.1,
            startPressure: 200,
            endPressure: 30,
            gasMix: GasMix.air(),
          ),
        ],
      );

      final sac = dive.sac!;
      // (200-30) * 11.1 / 42 / (20.3/10 + 1) = 1887 / 42 / 3.03 = 14.83
      expect(sac, closeTo(14.83, 0.1));
    });

    test('calculates sacPressure using runtime (issue #72)', () {
      final dive = Dive(
        id: 'issue-72-pressure',
        dateTime: DateTime(2024, 1, 1),
        bottomTime: const Duration(minutes: 20),
        runtime: const Duration(minutes: 42),
        avgDepth: 20.3,
        tanks: [
          DiveTank(
            id: 't1',
            name: 'AL80',
            volume: 11.1,
            startPressure: 200,
            endPressure: 30,
            gasMix: GasMix.air(),
          ),
        ],
      );

      final sacP = dive.sacPressure!;
      // (200-30) / 42 / (20.3/10 + 1) = 170 / 42 / 3.03 = 1.336
      expect(sacP, closeTo(1.34, 0.1));
    });

    test('falls back to bottomTime when runtime unavailable', () {
      final dive = Dive(
        id: 'fallback',
        dateTime: DateTime(2024, 1, 1),
        bottomTime: const Duration(minutes: 30),
        avgDepth: 20.0,
        tanks: [
          DiveTank(
            id: 't1',
            name: 'Tank',
            volume: 12.0,
            startPressure: 200,
            endPressure: 50,
            gasMix: GasMix.air(),
          ),
        ],
      );

      // (200-50) * 12 / 30 / (20/10 + 1) = 1800 / 30 / 3 = 20.0
      expect(dive.sac, closeTo(20.0, 0.1));
    });

    test('returns null when no time source available', () {
      final dive = Dive(
        id: 'no-time',
        dateTime: DateTime(2024, 1, 1),
        avgDepth: 20.0,
        tanks: [
          DiveTank(
            id: 't1',
            name: 'Tank',
            volume: 12.0,
            startPressure: 200,
            endPressure: 50,
            gasMix: GasMix.air(),
          ),
        ],
      );

      expect(dive.sac, isNull);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/features/dive_log/domain/entities/dive_sac_fix_test.dart
```

Expected: FAIL — issue #72 test expects ~14.83 but gets ~31.5 (using bottom time).

- [ ] **Step 3: Fix sac getter**

In `lib/features/dive_log/domain/entities/dive.dart`, update the `sac` getter:

```dart
  /// Air consumption rate in L/min at surface (Surface Air Consumption)
  /// Calculates total gas consumed across all tanks with valid data.
  /// Uses effectiveRuntime (total dive time) for accurate rate calculation.
  double? get sac {
    if (tanks.isEmpty || effectiveRuntime == null || avgDepth == null) {
      return null;
    }

    final minutes = effectiveRuntime!.inSeconds / 60;
    if (minutes <= 0) return null;

    final avgPressureAtm = (avgDepth! / 10) + 1; // Convert depth to ATM

    // Sum gas consumed across all tanks (in liters at surface pressure)
    double totalGasLiters = 0;
    int tanksWithData = 0;

    for (final tank in tanks) {
      if (tank.startPressure == null ||
          tank.endPressure == null ||
          tank.volume == null) {
        continue;
      }

      final pressureUsed = tank.startPressure! - tank.endPressure!;
      if (pressureUsed <= 0) continue;

      // Gas in liters at surface = tank_volume x pressure_used
      final gasLiters = tank.volume! * pressureUsed;
      totalGasLiters += gasLiters;
      tanksWithData++;
    }

    if (tanksWithData == 0 || totalGasLiters <= 0) return null;

    // SAC in liters/min at surface
    return totalGasLiters / minutes / avgPressureAtm;
  }
```

- [ ] **Step 4: Fix sacPressure getter**

```dart
  /// Air consumption rate in pressure units per minute (bar/min or psi/min)
  /// Uses effectiveRuntime (total dive time) for accurate rate calculation.
  double? get sacPressure {
    if (tanks.isEmpty || effectiveRuntime == null || avgDepth == null) {
      return null;
    }

    final minutes = effectiveRuntime!.inSeconds / 60;
    if (minutes <= 0) return null;

    final avgPressureAtm = (avgDepth! / 10) + 1; // Convert depth to ATM

    // Sum pressure consumed across all tanks with data
    double totalPressureUsed = 0;
    int tanksWithData = 0;

    for (final tank in tanks) {
      if (tank.startPressure == null || tank.endPressure == null) {
        continue;
      }

      final pressureUsed = tank.startPressure! - tank.endPressure!;
      if (pressureUsed <= 0) continue;

      totalPressureUsed += pressureUsed;
      tanksWithData++;
    }

    if (tanksWithData == 0 || totalPressureUsed <= 0) return null;

    // SAC in bar/min at surface (average across all tanks)
    return (totalPressureUsed / tanksWithData) / minutes / avgPressureAtm;
  }
```

- [ ] **Step 5: Fix GasAnalysisService.calculateCylinderSac**

In `lib/features/dive_log/data/services/gas_analysis_service.dart` (line 245):

```dart
// Before:
diveEnd: dive.bottomTime?.inSeconds ?? profile.lastOrNull?.timestamp ?? 0,

// After:
diveEnd: dive.effectiveRuntime?.inSeconds ?? profile.lastOrNull?.timestamp ?? 0,
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
flutter test test/features/dive_log/domain/entities/dive_sac_fix_test.dart
```

Expected: All 4 tests PASS.

- [ ] **Step 7: Run full test suite to check for regressions**

```bash
flutter test
```

Expected: All tests pass. Some existing SAC-related tests may need updated expected values if they were asserting the old (incorrect) behavior.

- [ ] **Step 8: Update any existing tests with incorrect expected SAC values**

If tests fail because they expected the old (bottom-time-based) SAC values, update them to use the correct runtime-based values. The test Dive fixtures need to have `runtime` set so the SAC calculation uses it.

- [ ] **Step 9: Commit**

```bash
git add lib/features/dive_log/domain/entities/dive.dart lib/features/dive_log/data/services/gas_analysis_service.dart test/
git commit -m "fix: SAC calculations use runtime instead of bottom time (fixes #72, #87)"
```

---

## Task 12: Fix Statistics Repository SQL SAC Queries

**Files:**
- Modify: `lib/features/statistics/data/repositories/statistics_repository.dart`

- [ ] **Step 1: Update SAC SQL queries to use runtime**

In `lib/features/statistics/data/repositories/statistics_repository.dart`, update all 6 SAC SQL queries to prefer `runtime` over `bottom_time`:

Replace the pattern in all queries:

```sql
-- Before:
WHEN d.bottom_time > 0 AND d.avg_depth > 0 ...
  ... / (d.bottom_time / 60.0) / ...
WHERE d.bottom_time > 0

-- After:
WHEN COALESCE(d.runtime, (d.exit_time - d.entry_time) / 1000, d.bottom_time) > 0 AND d.avg_depth > 0 ...
  ... / (COALESCE(d.runtime, (d.exit_time - d.entry_time) / 1000, d.bottom_time) / 60.0) / ...
WHERE COALESCE(d.runtime, (d.exit_time - d.entry_time) / 1000, d.bottom_time) > 0
```

Note: `entry_time` and `exit_time` are stored as Unix millisecond timestamps, so `(d.exit_time - d.entry_time) / 1000` gives seconds. Verify the timestamp format by reading the schema — if they are already in seconds, drop the `/1000`.

For readability, consider extracting the COALESCE into a SQL variable or CTE. Example for each query:

```sql
SELECT
  strftime('%Y', d.dive_date_time / 1000, 'unixepoch') AS year,
  strftime('%m', d.dive_date_time / 1000, 'unixepoch') AS month,
  AVG(
    CASE
      WHEN COALESCE(d.runtime, d.bottom_time) > 0 AND d.avg_depth > 0
        AND t.start_pressure > t.end_pressure AND t.volume > 0 THEN
        ((t.start_pressure - t.end_pressure) * t.volume)
          / (COALESCE(d.runtime, d.bottom_time) / 60.0)
          / ((d.avg_depth / 10.0) + 1)
      ELSE NULL
    END
  ) AS avg_sac
FROM dives d
```

Note: The `runtime` column stores seconds directly, same as `bottom_time`. The `entry_time`/`exit_time` timestamps are Unix milliseconds — including them in the COALESCE adds complexity for a rarely-hit case. Since most dives with SAC data will have `runtime` set (from import), using `COALESCE(d.runtime, d.bottom_time)` covers the vast majority of cases while keeping SQL readable.

Apply this pattern to all 6 query locations.

- [ ] **Step 2: Run tests**

```bash
flutter test
```

Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add lib/features/statistics/data/repositories/statistics_repository.dart
git commit -m "fix: statistics SAC queries use runtime instead of bottom time"
```

---

## Task 13: Replace calculatedDuration Callers with effectiveRuntime

**Files:**
- Modify: `lib/features/media/presentation/helpers/photo_import_helper.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart`
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart`
- Modify: `lib/features/dive_log/domain/entities/dive.dart` (remove old getter)

- [ ] **Step 1: Replace callers of calculatedDuration**

**photo_import_helper.dart** (line 31):
```dart
// Before:
final diveDuration = dive.calculatedDuration ?? const Duration(hours: 1);

// After:
final diveDuration = dive.effectiveRuntime ?? const Duration(hours: 1);
```

**dive_detail_page.dart** (lines 1133, 4765):
```dart
// Before:
diveDuration: dive.calculatedDuration,

// After:
diveDuration: dive.effectiveRuntime,
```

**dive_repository_impl.dart** (line 2971):
```dart
// Before:
previousDive.calculatedDuration ?? Duration.zero,

// After:
previousDive.effectiveRuntime ?? Duration.zero,
```

- [ ] **Step 2: Rename local variables in dive_edit_page.dart**

Lines 321, 1819 (calls to `calculateBottomTimeFromProfile()`):
```dart
// Before:
final calculatedDuration = dive.calculateBottomTimeFromProfile();
if (calculatedDuration != null) {

// After:
final calculatedBottomTime = dive.calculateBottomTimeFromProfile();
if (calculatedBottomTime != null) {
```

Update all references to the renamed local variable in the surrounding code.

Line 804 (local entry/exit time calculation):
```dart
// Before:
Duration? calculatedDuration;
...
calculatedDuration = exitDateTime.difference(entryDateTime);
if (calculatedDuration.isNegative) calculatedDuration = null;

// After:
Duration? calculatedRuntime;
...
calculatedRuntime = exitDateTime.difference(entryDateTime);
if (calculatedRuntime.isNegative) calculatedRuntime = null;
```

Update all references to `calculatedDuration` in the surrounding display logic (around lines 886-908) to use `calculatedRuntime`.

- [ ] **Step 3: Remove the old calculatedDuration getter**

In `lib/features/dive_log/domain/entities/dive.dart`, remove the `calculatedDuration` getter entirely (lines 225-231). Its functionality is fully replaced by `effectiveRuntime`.

- [ ] **Step 4: Run full test suite**

```bash
flutter test
```

Expected: All tests pass. If any tests reference `calculatedDuration`, update them to use `effectiveRuntime`.

- [ ] **Step 5: Commit**

```bash
git add lib/ test/
git commit -m "refactor: replace calculatedDuration with effectiveRuntime across codebase"
```

---

## Task 14: Phase 2 Verification

**Files:** None (verification only)

- [ ] **Step 1: Run dart format**

```bash
dart format lib/ test/
```

- [ ] **Step 2: Run flutter analyze**

```bash
flutter analyze
```

Expected: 0 issues.

- [ ] **Step 3: Run full test suite**

```bash
flutter test
```

Expected: All tests pass.

- [ ] **Step 4: Grep for any remaining calculatedDuration references**

```bash
grep -rn "calculatedDuration" lib/ test/ --include="*.dart"
```

Expected: No results (all replaced).

- [ ] **Step 5: Grep for any remaining Dive.duration references**

```bash
grep -rn "\.duration" lib/ test/ --include="*.dart" | grep -E "(dive|summary)\." | grep -iv "DiveDataSource\|ImportedDive\|IncomingDiveData\|DownloadedDive\|animationDuration"
```

Expected: No results that refer to the old Dive/DiveSummary field.

- [ ] **Step 6: Verify SAC with issue #72 math**

Run the specific SAC test:
```bash
flutter test test/features/dive_log/domain/entities/dive_sac_fix_test.dart -v
```

Verify the issue #72 test produces SAC ≈ 14.83 L/min (not 31.5).

- [ ] **Step 7: Final commit if any cleanup needed**

```bash
git add -A
git status
# Only commit if there are changes
git commit -m "chore: Phase 2 verification cleanup"
```
