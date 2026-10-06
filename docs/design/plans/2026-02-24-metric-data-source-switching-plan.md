# Metric Data Source Switching Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add per-metric data source preference (Dive Computer vs Calculated) for NDL, ceiling, TTS, and CNS, with global defaults and per-dive session overrides.

**Architecture:** A `MetricDataSource` enum (`computer`/`calculated`) drives per-metric source selection. Global defaults persist in `AppSettings` (backed by Drift columns). Per-dive overrides live in `ProfileLegendState` (session-only). The `overlayComputerDecoData` function gains per-metric source params and returns a `MetricSourceInfo` record reporting actual sources used (handling fallback). Legend badges show "(DC)" or "(Calc\*)" indicators.

**Tech Stack:** Flutter/Dart, Drift ORM (SQLite), Riverpod state management

**Design doc:** `docs/plans/2026-02-23-metric-data-source-switching-design.md`

---

## Context for Implementer

### What already exists (uncommitted on main)

A "Computer CNS Preference" feature was just implemented. It added:

- `useDiveComputerCnsData` boolean field to `AppSettings`, `DiverSettings` table (migration v41), and the repository
- `useDiveComputerCnsDataProvider` convenience provider
- `setUseDiveComputerCnsData` setter on `SettingsNotifier`
- `includeComputerCns` bool param on `overlayComputerDecoData`
- `extractComputerCns()` and `hasComputerCns()` in `computer_cns_extractor.dart`
- A CNS toggle in `settings_page.dart` decompression section
- Integration tests in `computer_cns_provider_integration_test.dart`

**This plan replaces that single-boolean system with a unified per-metric source system.** The `useDiveComputerCnsData` bool, its provider, its setter, and its UI toggle are all removed. The `extractComputerCns` helper and `hasComputerCns` function remain unchanged.

### Key files you will touch

| File | Action |
|------|--------|
| `lib/core/constants/profile_metrics.dart` | Add `MetricDataSource` enum and `MetricSourceInfo` typedef |
| `lib/core/database/database.dart` | Add 4 columns to `DiverSettings`, migration v42, bump schema to 42 |
| `lib/features/settings/data/repositories/diver_settings_repository.dart` | Replace `useDiveComputerCnsData` with 4 source fields in read/write |
| `lib/features/settings/presentation/providers/settings_providers.dart` | Replace `useDiveComputerCnsData` field/provider/setter with 4 source fields |
| `lib/features/dive_log/presentation/providers/profile_legend_provider.dart` | Add 4 source fields + cycle methods to `ProfileLegendState` and notifier |
| `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart` | Refactor `overlayComputerDecoData` signature, update `profileAnalysisProvider`, add `metricSourceInfoProvider` |
| `lib/features/dive_log/presentation/widgets/dive_profile_legend.dart` | Badge labels with source indicator, source segmented controls in More menu |
| `lib/features/settings/presentation/pages/settings_page.dart` | Replace CNS toggle with Data Source Preferences section |
| `lib/features/settings/presentation/pages/appearance_page.dart` | Add Data Source Preferences section |
| `test/core/constants/profile_metrics_test.dart` | New: enum serialization tests |
| `test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart` | Update overlay tests for new signature |
| `test/features/dive_log/domain/services/computer_cns_provider_integration_test.dart` | Update for new signature + add per-metric source tests |
| `test/features/settings/presentation/pages/settings_page_test.dart` | Update mock for new setter methods |
| `test/features/statistics/presentation/pages/records_page_test.dart` | Update mock for new setter methods |

---

## Task 1: MetricDataSource Enum and MetricSourceInfo Type

**Files:**

- Modify: `lib/core/constants/profile_metrics.dart` (append after line 165)
- Create: `test/core/constants/profile_metrics_test.dart`

**Step 1: Write the failing test**

Create `test/core/constants/profile_metrics_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';

void main() {
  group('MetricDataSource', () {
    test('toInt returns 0 for computer, 1 for calculated', () {
      expect(MetricDataSource.computer.toInt(), 0);
      expect(MetricDataSource.calculated.toInt(), 1);
    });

    test('fromInt returns computer for 0', () {
      expect(MetricDataSource.fromInt(0), MetricDataSource.computer);
    });

    test('fromInt returns calculated for 1', () {
      expect(MetricDataSource.fromInt(1), MetricDataSource.calculated);
    });

    test('fromInt defaults to calculated for unknown values', () {
      expect(MetricDataSource.fromInt(99), MetricDataSource.calculated);
      expect(MetricDataSource.fromInt(-1), MetricDataSource.calculated);
    });

    test('roundtrip: toInt then fromInt', () {
      for (final source in MetricDataSource.values) {
        expect(MetricDataSource.fromInt(source.toInt()), source);
      }
    });
  });

  group('MetricSourceInfo', () {
    test('can be created with all fields', () {
      const info = (
        ndlActual: MetricDataSource.computer,
        ceilingActual: MetricDataSource.calculated,
        ttsActual: MetricDataSource.computer,
        cnsActual: MetricDataSource.calculated,
      );
      expect(info.ndlActual, MetricDataSource.computer);
      expect(info.ceilingActual, MetricDataSource.calculated);
      expect(info.ttsActual, MetricDataSource.computer);
      expect(info.cnsActual, MetricDataSource.calculated);
    });

    test('all-calculated convenience works', () {
      const info = (
        ndlActual: MetricDataSource.calculated,
        ceilingActual: MetricDataSource.calculated,
        ttsActual: MetricDataSource.calculated,
        cnsActual: MetricDataSource.calculated,
      );
      expect(info.ndlActual, MetricDataSource.calculated);
    });
  });
}
```text
**Step 2: Run test to verify it fails**

Run: `flutter test test/core/constants/profile_metrics_test.dart`
Expected: FAIL -- `MetricDataSource` is not defined.

**Step 3: Write minimal implementation**

Append to `lib/core/constants/profile_metrics.dart` (after the closing brace of `ProfileMetricCategoryExtension` at line 165):

```dart

/// Data source preference for metrics that can come from a dive computer or app calculation.
enum MetricDataSource {
  computer,   // Prefer dive-computer-reported data
  calculated; // Always use app-calculated data

  /// Serialize to int for database storage (0 = computer, 1 = calculated).
  int toInt() => index;

  /// Deserialize from int. Returns [calculated] for unknown values.
  static MetricDataSource fromInt(int value) =>
      value == 0 ? MetricDataSource.computer : MetricDataSource.calculated;
}

/// Reports which data source was actually used for each metric after fallback resolution.
///
/// When a user prefers `computer` but no computer data exists for that metric,
/// the actual source falls back to `calculated`.
typedef MetricSourceInfo = ({
  MetricDataSource ndlActual,
  MetricDataSource ceilingActual,
  MetricDataSource ttsActual,
  MetricDataSource cnsActual,
});
```text
**Step 4: Run test to verify it passes**

Run: `flutter test test/core/constants/profile_metrics_test.dart`
Expected: All 7 tests PASS.

**Step 5: Commit**

```bash
git add lib/core/constants/profile_metrics.dart test/core/constants/profile_metrics_test.dart
git commit -m "feat: add MetricDataSource enum and MetricSourceInfo type

Part of metric data source switching feature. Enum serializes to int
for database storage. MetricSourceInfo record reports actual source
used per metric after fallback resolution."
```typescript
---

## Task 2: Refactor overlayComputerDecoData for Per-Metric Sources

**Files:**

- Modify: `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart:139-197` (the function)
- Modify: `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart:505` (diveProfileAnalysisProvider call)
- Modify: `test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart` (existing overlay tests)
- Modify: `test/features/dive_log/domain/services/computer_cns_provider_integration_test.dart` (existing overlay tests)

**Step 1: Update existing overlay tests for new signature**

In `test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart`, the `overlayComputerDecoData` group (starts at line 195) calls the function without named params and expects a `ProfileAnalysis` return. Update every call site:

The function now returns `(ProfileAnalysis, MetricSourceInfo)`. Every test that calls `overlayComputerDecoData(...)` must destructure the result.

For tests that currently DO overlay (they pass profiles with computer data), the new signature requires explicitly passing `MetricDataSource.computer` for each metric being tested. The old default was to overlay everything; the new default is `MetricDataSource.calculated` (overlay nothing).

Example update pattern -- old:

```dart
final result = overlayComputerDecoData(baseAnalysis, profileWithNdl);
expect(result.ndlCurve[5], equals(12));
```text
New:

```dart
final (result, sourceInfo) = overlayComputerDecoData(
  baseAnalysis, profileWithNdl,
  ndlSource: MetricDataSource.computer,
);
expect(result.ndlCurve[5], equals(12));
expect(sourceInfo.ndlActual, MetricDataSource.computer);
```dart
Update all 8 tests in the `overlayComputerDecoData` group:

1. `returns original analysis when no computer data present` -- no source params needed (all default to calculated). Destructure result:

   ```dart
   final (result, sourceInfo) = overlayComputerDecoData(baseAnalysis, baseProfile);
   expect(result, same(baseAnalysis)); // No change
   expect(sourceInfo.ndlActual, MetricDataSource.calculated);
   ```

1. `overlays computer NDL when available` -- add `ndlSource: MetricDataSource.computer`:

   ```dart
   final (result, sourceInfo) = overlayComputerDecoData(
     baseAnalysis, profileWithComputerNdl,
     ndlSource: MetricDataSource.computer,
   );
   ```

2. `overlays computer ceiling when available` -- add `ceilingSource: MetricDataSource.computer`.

3. `overlays computer TTS when available` -- add `ttsSource: MetricDataSource.computer`.

4. `overlays computer CNS when available` -- add `cnsSource: MetricDataSource.computer`.

5. `handles mixed computer data` -- add all 4 sources as `MetricDataSource.computer`.

6. `overlays multiple curves simultaneously` -- add relevant sources as `MetricDataSource.computer`.

7. `handles empty analysis curves gracefully` -- add all sources as `MetricDataSource.computer`.

Also add 2 new tests:

```dart
test('source=calculated ignores available computer NDL data', () {
  // Create profile with computer NDL data
  final profileWithNdl = baseProfile.map((p) {
    final idx = baseProfile.indexOf(p);
    return p.copyWith(ndl: idx < 5 ? 12 : null);
  }).toList();

  final (result, sourceInfo) = overlayComputerDecoData(
    baseAnalysis,
    profileWithNdl,
    ndlSource: MetricDataSource.calculated, // Explicitly calculated
  );
  // NDL curve should NOT be overlaid
  expect(result.ndlCurve, equals(baseAnalysis.ndlCurve));
  expect(sourceInfo.ndlActual, MetricDataSource.calculated);
});

test('source=computer without data falls back to calculated', () {
  // baseProfile has no computer data
  final (result, sourceInfo) = overlayComputerDecoData(
    baseAnalysis,
    baseProfile,
    ndlSource: MetricDataSource.computer, // Want computer but none exists
  );
  expect(result, same(baseAnalysis));
  expect(sourceInfo.ndlActual, MetricDataSource.calculated); // Fallback
});
```typescript
In `test/features/dive_log/domain/services/computer_cns_provider_integration_test.dart`, update the `overlayComputerDecoData - includeComputerCns parameter` group (line 48). Replace `includeComputerCns: false` with `cnsSource: MetricDataSource.calculated` and `includeComputerCns: true` with `cnsSource: MetricDataSource.computer`. Destructure all return values. Add import for `MetricDataSource`:

```dart
import 'package:submersion/core/constants/profile_metrics.dart';
```text
Update the 4 tests in that group:

1. `cnsSource: calculated excludes CNS curve...` -- change `includeComputerCns: false` to `cnsSource: MetricDataSource.calculated`, add `ndlSource: MetricDataSource.computer, ceilingSource: MetricDataSource.computer, ttsSource: MetricDataSource.computer` (these were previously always overlaid).
2. `cnsSource: computer overlays computer CNS curve` -- change `includeComputerCns: true` to `cnsSource: MetricDataSource.computer` plus other sources as `computer`.
3. `defaults to calculated (new default behavior)` -- call with no params, expect NO overlay (this is a behavior change from old default of `true`).
4. `cnsSource: calculated with only CNS computer data returns original` -- change param name.

**Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart test/features/dive_log/domain/services/computer_cns_provider_integration_test.dart`
Expected: FAIL -- `overlayComputerDecoData` signature mismatch.

**Step 3: Implement the refactored function**

Replace lines 139-197 of `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart` with:

```dart
(ProfileAnalysis, MetricSourceInfo) overlayComputerDecoData(
  ProfileAnalysis analysis,
  List<DiveProfilePoint> profile, {
  MetricDataSource ndlSource = MetricDataSource.calculated,
  MetricDataSource ceilingSource = MetricDataSource.calculated,
  MetricDataSource ttsSource = MetricDataSource.calculated,
  MetricDataSource cnsSource = MetricDataSource.calculated,
}) {
  final hasComputerNdl = profile.any((p) => p.ndl != null);
  final hasComputerCeiling = profile.any((p) => p.ceiling != null);
  final hasComputerTts = profile.any((p) => p.tts != null);
  final hasComputerCns = profile.any((p) => p.cns != null);

  // Decide per-metric: overlay only when source=computer AND data exists
  final useNdl = ndlSource == MetricDataSource.computer && hasComputerNdl;
  final useCeiling =
      ceilingSource == MetricDataSource.computer && hasComputerCeiling;
  final useTts = ttsSource == MetricDataSource.computer && hasComputerTts;
  final useCns = cnsSource == MetricDataSource.computer && hasComputerCns;

  // Report actual source used (fallback to calculated if no data)
  final sourceInfo = (
    ndlActual:
        useNdl ? MetricDataSource.computer : MetricDataSource.calculated,
    ceilingActual:
        useCeiling ? MetricDataSource.computer : MetricDataSource.calculated,
    ttsActual:
        useTts ? MetricDataSource.computer : MetricDataSource.calculated,
    cnsActual:
        useCns ? MetricDataSource.computer : MetricDataSource.calculated,
  );

  if (!useNdl && !useCeiling && !useTts && !useCns) {
    return (analysis, sourceInfo);
  }

  final overlaid = analysis.copyWith(
    ndlCurve: useNdl
        ? List<int>.generate(
            profile.length,
            (i) =>
                profile[i].ndl ??
                (i < analysis.ndlCurve.length ? analysis.ndlCurve[i] : 0),
          )
        : null,
    ceilingCurve: useCeiling
        ? List<double>.generate(
            profile.length,
            (i) =>
                profile[i].ceiling ??
                (i < analysis.ceilingCurve.length
                    ? analysis.ceilingCurve[i]
                    : 0.0),
          )
        : null,
    ttsCurve: useTts
        ? List<int>.generate(
            profile.length,
            (i) =>
                profile[i].tts ??
                (analysis.ttsCurve != null && i < analysis.ttsCurve!.length
                    ? analysis.ttsCurve![i]
                    : 0),
          )
        : null,
    cnsCurve: useCns
        ? List<double>.generate(
            profile.length,
            (i) =>
                profile[i].cns ??
                (analysis.cnsCurve != null && i < analysis.cnsCurve!.length
                    ? analysis.cnsCurve![i]
                    : 0.0),
          )
        : null,
  );

  return (overlaid, sourceInfo);
}
```typescript
Add import at top of file:

```dart
import 'package:submersion/core/constants/profile_metrics.dart';
```text
**Step 4: Fix calling sites that break**

Two callers within the same file need updating:

**a) `profileAnalysisProvider` (line 345-349):** Temporarily keep working by destructuring (the full provider refactor happens in Task 6):

```dart
      // Overlay computer-reported deco data where available
      final (overlaid, _) = overlayComputerDecoData(
        analysis,
        dive.profile,
        cnsSource: useComputerCns
            ? MetricDataSource.computer
            : MetricDataSource.calculated,
        // NDL/ceiling/TTS: keep current behavior of always overlaying
        ndlSource: MetricDataSource.computer,
        ceilingSource: MetricDataSource.computer,
        ttsSource: MetricDataSource.computer,
      );
```text
**b) `diveProfileAnalysisProvider` (line 505):** This provider always overlays all computer data:

```dart
    // Overlay computer-reported deco data where available
    final (overlaid, _) = overlayComputerDecoData(
      analysis,
      dive.profile,
      ndlSource: MetricDataSource.computer,
      ceilingSource: MetricDataSource.computer,
      ttsSource: MetricDataSource.computer,
      cnsSource: MetricDataSource.computer,
    );
    return overlaid;
```text
**Step 5: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart test/features/dive_log/domain/services/computer_cns_provider_integration_test.dart`
Expected: All tests PASS.

**Step 6: Run full test suite**

Run: `flutter test`
Expected: All tests PASS. If any fail, fix the call sites.

**Step 7: Commit**

```bash
git add lib/features/dive_log/presentation/providers/profile_analysis_provider.dart test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart test/features/dive_log/domain/services/computer_cns_provider_integration_test.dart
git commit -m "feat: refactor overlayComputerDecoData for per-metric source selection

Replace single includeComputerCns bool with per-metric MetricDataSource
params (ndl, ceiling, tts, cns). Function now returns (ProfileAnalysis,
MetricSourceInfo) tuple reporting actual source used per metric."
```text
---

## Task 3: Database Migration v42

**Files:**

- Modify: `lib/core/database/database.dart:566-567` (table definition), `:1108` (schema version), `:1979-1983` (migration)

**Step 1: Write the migration**

In `lib/core/database/database.dart`:

**a) Replace `useDiveComputerCnsData` column with 4 source columns (around line 566-567):**

Remove:

```dart
  BoolColumn get useDiveComputerCnsData =>
      boolean().withDefault(const Constant(false))();
```text
Replace with:

```dart
  IntColumn get defaultNdlSource => integer().withDefault(const Constant(1))();
  IntColumn get defaultCeilingSource =>
      integer().withDefault(const Constant(1))();
  IntColumn get defaultTtsSource => integer().withDefault(const Constant(1))();
  IntColumn get defaultCnsSource => integer().withDefault(const Constant(1))();
```text
(Values: 0 = computer, 1 = calculated. Default 1 = calculated.)

**b) Bump schema version (line 1108):**

Change `int get schemaVersion => 41;` to `int get schemaVersion => 42;`

**c) Add migration v42 (after line 1983):**

```dart
        if (from < 42) {
          // Add per-metric data source columns
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN default_ndl_source INTEGER NOT NULL DEFAULT 1',
          );
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN default_ceiling_source INTEGER NOT NULL DEFAULT 1',
          );
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN default_tts_source INTEGER NOT NULL DEFAULT 1',
          );
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN default_cns_source INTEGER NOT NULL DEFAULT 1',
          );
          // Migrate existing CNS toggle: if user had it enabled, set CNS source to computer (0)
          await customStatement(
            'UPDATE diver_settings SET default_cns_source = 0 WHERE use_dive_computer_cns_data = 1',
          );
        }
```text
**Step 2: Run build_runner to regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Drift generates updated code for the new columns.

**Step 3: Run tests**

Run: `flutter test`
Expected: Compilation errors in repository and settings code (they still reference the old column). This is expected -- Tasks 4 fixes them.

**Step 4: Commit (database layer only)**

```bash
git add lib/core/database/database.dart lib/core/database/database.g.dart
git commit -m "feat: database migration v42 - per-metric data source columns

Add default_ndl_source, default_ceiling_source, default_tts_source,
default_cns_source columns to diver_settings. Migrate existing
use_dive_computer_cns_data toggle to default_cns_source."
```text
---

## Task 4: AppSettings and Repository - New Source Fields

**Files:**

- Modify: `lib/features/settings/presentation/providers/settings_providers.dart`
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart`
- Modify: `test/features/settings/presentation/pages/settings_page_test.dart` (mock)
- Modify: `test/features/statistics/presentation/pages/records_page_test.dart` (mock)

**Step 1: Update AppSettings class**

In `lib/features/settings/presentation/providers/settings_providers.dart`:

**a) Replace field (line 107-108):**

Remove:

```dart
  /// Whether to use dive-computer-reported CNS data when available
  final bool useDiveComputerCnsData;
```text
Replace with:

```dart
  /// Default data source for NDL metric (computer or calculated)
  final MetricDataSource defaultNdlSource;

  /// Default data source for ceiling metric (computer or calculated)
  final MetricDataSource defaultCeilingSource;

  /// Default data source for TTS metric (computer or calculated)
  final MetricDataSource defaultTtsSource;

  /// Default data source for CNS metric (computer or calculated)
  final MetricDataSource defaultCnsSource;
```typescript
Add import at top:

```dart
import 'package:submersion/core/constants/profile_metrics.dart';
```text
**b) Update constructor defaults (line 225):**

Remove:

```dart
    this.useDiveComputerCnsData = false,
```text
Replace with:

```dart
    this.defaultNdlSource = MetricDataSource.calculated,
    this.defaultCeilingSource = MetricDataSource.calculated,
    this.defaultTtsSource = MetricDataSource.calculated,
    this.defaultCnsSource = MetricDataSource.calculated,
```text
**c) Update copyWith (line 320 param, line 379-380 body):**

Remove param: `bool? useDiveComputerCnsData,`

Add params:

```dart
    MetricDataSource? defaultNdlSource,
    MetricDataSource? defaultCeilingSource,
    MetricDataSource? defaultTtsSource,
    MetricDataSource? defaultCnsSource,
```text
Remove body line:

```dart
      useDiveComputerCnsData:
          useDiveComputerCnsData ?? this.useDiveComputerCnsData,
```text
Add body lines:

```dart
      defaultNdlSource: defaultNdlSource ?? this.defaultNdlSource,
      defaultCeilingSource: defaultCeilingSource ?? this.defaultCeilingSource,
      defaultTtsSource: defaultTtsSource ?? this.defaultTtsSource,
      defaultCnsSource: defaultCnsSource ?? this.defaultCnsSource,
```text
**d) Replace setter (lines 689-692):**

Remove:

```dart
  Future<void> setUseDiveComputerCnsData(bool value) async {
    state = state.copyWith(useDiveComputerCnsData: value);
    await _saveSettings();
  }
```text
Replace with:

```dart
  Future<void> setDefaultNdlSource(MetricDataSource value) async {
    state = state.copyWith(defaultNdlSource: value);
    await _saveSettings();
  }

  Future<void> setDefaultCeilingSource(MetricDataSource value) async {
    state = state.copyWith(defaultCeilingSource: value);
    await _saveSettings();
  }

  Future<void> setDefaultTtsSource(MetricDataSource value) async {
    state = state.copyWith(defaultTtsSource: value);
    await _saveSettings();
  }

  Future<void> setDefaultCnsSource(MetricDataSource value) async {
    state = state.copyWith(defaultCnsSource: value);
    await _saveSettings();
  }
```text
**e) Replace convenience provider (lines 971-973):**

Remove:

```dart
final useDiveComputerCnsDataProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.useDiveComputerCnsData));
});
```text
(No replacement needed -- consumers will read from `ProfileLegendState` instead.)

**Step 2: Update DiverSettingsRepository**

In `lib/features/settings/data/repositories/diver_settings_repository.dart`:

**a) In `createSettingsForDiver` (line 77):**

Remove:

```dart
              useDiveComputerCnsData: Value(s.useDiveComputerCnsData),
```text
Replace with:

```dart
              defaultNdlSource: Value(s.defaultNdlSource.toInt()),
              defaultCeilingSource: Value(s.defaultCeilingSource.toInt()),
              defaultTtsSource: Value(s.defaultTtsSource.toInt()),
              defaultCnsSource: Value(s.defaultCnsSource.toInt()),
```text
**b) In `updateSettingsForDiver` (line 177):**

Remove:

```dart
          useDiveComputerCnsData: Value(settings.useDiveComputerCnsData),
```text
Replace with:

```dart
          defaultNdlSource: Value(settings.defaultNdlSource.toInt()),
          defaultCeilingSource: Value(settings.defaultCeilingSource.toInt()),
          defaultTtsSource: Value(settings.defaultTtsSource.toInt()),
          defaultCnsSource: Value(settings.defaultCnsSource.toInt()),
```text
**c) In `_mapRowToAppSettings` (line 313):**

Remove:

```dart
      useDiveComputerCnsData: row.useDiveComputerCnsData,
```text
Replace with:

```dart
      defaultNdlSource: MetricDataSource.fromInt(row.defaultNdlSource),
      defaultCeilingSource: MetricDataSource.fromInt(row.defaultCeilingSource),
      defaultTtsSource: MetricDataSource.fromInt(row.defaultTtsSource),
      defaultCnsSource: MetricDataSource.fromInt(row.defaultCnsSource),
```typescript
Add import at top:

```dart
import 'package:submersion/core/constants/profile_metrics.dart';
```text
**Step 3: Update test mocks**

In `test/features/settings/presentation/pages/settings_page_test.dart`, find the `_MockSettingsNotifier` class. Replace (around line 104-105):

Remove:

```dart
  @override
  Future<void> setUseDiveComputerCnsData(bool value) async =>
      state = state.copyWith(useDiveComputerCnsData: value);
```text
Replace with:

```dart
  @override
  Future<void> setDefaultNdlSource(MetricDataSource value) async =>
      state = state.copyWith(defaultNdlSource: value);

  @override
  Future<void> setDefaultCeilingSource(MetricDataSource value) async =>
      state = state.copyWith(defaultCeilingSource: value);

  @override
  Future<void> setDefaultTtsSource(MetricDataSource value) async =>
      state = state.copyWith(defaultTtsSource: value);

  @override
  Future<void> setDefaultCnsSource(MetricDataSource value) async =>
      state = state.copyWith(defaultCnsSource: value);
```text
Add import:

```dart
import 'package:submersion/core/constants/profile_metrics.dart';
```typescript
Do the same in `test/features/statistics/presentation/pages/records_page_test.dart` (same pattern around line 105-106).

**Step 4: Update profileAnalysisProvider to remove old provider reference**

In `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart`:

Remove the import of `useDiveComputerCnsDataProvider` usage. At line 310, change:

```dart
      final useComputerCns = ref.watch(useDiveComputerCnsDataProvider);
```text
Temporarily replace with (this will be fully refactored in Task 6):

```dart
      final settings = ref.watch(settingsProvider);
      final useComputerCns = settings.defaultCnsSource == MetricDataSource.computer;
```text
At line 394, change:

```dart
    final useComputerCns = ref.watch(useDiveComputerCnsDataProvider);
```text
To:

```dart
    final settings = ref.watch(settingsProvider);
    final useComputerCns = settings.defaultCnsSource == MetricDataSource.computer;
```text
**Step 5: Run build_runner**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Drift regenerates with new column types.

**Step 6: Run tests**

Run: `flutter test`
Expected: All tests PASS.

**Step 7: Commit**

```bash
git add lib/features/settings/presentation/providers/settings_providers.dart lib/features/settings/data/repositories/diver_settings_repository.dart lib/features/dive_log/presentation/providers/profile_analysis_provider.dart test/features/settings/presentation/pages/settings_page_test.dart test/features/statistics/presentation/pages/records_page_test.dart
git commit -m "feat: replace useDiveComputerCnsData with per-metric source fields

AppSettings now has defaultNdlSource, defaultCeilingSource,
defaultTtsSource, defaultCnsSource (MetricDataSource enum). Old boolean
field, provider, and setter removed. Repository updated for int
serialization."
```text
---

## Task 5: ProfileLegendState - Source Fields and Cycle Methods

**Files:**

- Modify: `lib/features/dive_log/presentation/providers/profile_legend_provider.dart`

**Step 1: Add source fields to ProfileLegendState**

In `lib/features/dive_log/presentation/providers/profile_legend_provider.dart`:

Add import:

```dart
import 'package:submersion/core/constants/profile_metrics.dart';
```text
**a) Add 4 fields after `showOtu` (around line 43-44):**

```dart
  final MetricDataSource ndlSource;
  final MetricDataSource ceilingSource;
  final MetricDataSource ttsSource;
  final MetricDataSource cnsSource;
```text
**b) Add constructor defaults (after `this.showOtu = false`):**

```dart
    this.ndlSource = MetricDataSource.calculated,
    this.ceilingSource = MetricDataSource.calculated,
    this.ttsSource = MetricDataSource.calculated,
    this.cnsSource = MetricDataSource.calculated,
```text
**c) Add to `copyWith` -- parameter list:**

```dart
    MetricDataSource? ndlSource,
    MetricDataSource? ceilingSource,
    MetricDataSource? ttsSource,
    MetricDataSource? cnsSource,
```text
And body:

```dart
      ndlSource: ndlSource ?? this.ndlSource,
      ceilingSource: ceilingSource ?? this.ceilingSource,
      ttsSource: ttsSource ?? this.ttsSource,
      cnsSource: cnsSource ?? this.cnsSource,
```text
**d) Add to `==` operator:**

```dart
        ndlSource == other.ndlSource &&
        ceilingSource == other.ceilingSource &&
        ttsSource == other.ttsSource &&
        cnsSource == other.cnsSource &&
```text
**e) Add to `hashCode`:**

Add `ndlSource`, `ceilingSource`, `ttsSource`, `cnsSource` to the `Object.hashAll` list.

**Step 2: Add cycle methods to ProfileLegend notifier**

After the existing toggle methods (around line 366), add:

```dart
  void cycleNdlSource() {
    state = state.copyWith(
      ndlSource: state.ndlSource == MetricDataSource.computer
          ? MetricDataSource.calculated
          : MetricDataSource.computer,
    );
  }

  void cycleCeilingSource() {
    state = state.copyWith(
      ceilingSource: state.ceilingSource == MetricDataSource.computer
          ? MetricDataSource.calculated
          : MetricDataSource.computer,
    );
  }

  void cycleTtsSource() {
    state = state.copyWith(
      ttsSource: state.ttsSource == MetricDataSource.computer
          ? MetricDataSource.calculated
          : MetricDataSource.computer,
    );
  }

  void cycleCnsSource() {
    state = state.copyWith(
      cnsSource: state.cnsSource == MetricDataSource.computer
          ? MetricDataSource.calculated
          : MetricDataSource.computer,
    );
  }
```text
**Step 3: Initialize from settings defaults**

In the `build()` method (around line 232-260), add to the `ProfileLegendState` constructor call:

```dart
      ndlSource: settings.defaultNdlSource,
      ceilingSource: settings.defaultCeilingSource,
      ttsSource: settings.defaultTtsSource,
      cnsSource: settings.defaultCnsSource,
```text
**Step 4: Run tests**

Run: `flutter test`
Expected: All tests PASS.

**Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/providers/profile_legend_provider.dart
git commit -m "feat: add per-metric data source fields to ProfileLegendState

Four new MetricDataSource fields (ndl, ceiling, tts, cns) with cycle
methods. Initialized from AppSettings defaults. Supports per-dive
session overrides via the cycle methods."
```text
---

## Task 6: profileAnalysisProvider Refactor and metricSourceInfoProvider

**Files:**

- Modify: `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart`
- Modify: `test/features/dive_log/domain/services/computer_cns_provider_integration_test.dart`

**Step 1: Add metricSourceInfoProvider**

In `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart`, add near the other provider declarations (after imports):

```dart
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';

/// Reports which data source was actually used for each metric in the current profile.
/// Updated as a side-effect of profileAnalysisProvider.
final metricSourceInfoProvider = StateProvider<MetricSourceInfo?>((ref) => null);
```text
**Step 2: Refactor profileAnalysisProvider to read from ProfileLegendState**

In `profileAnalysisProvider` (around lines 309-349), replace the temporary code from Task 4:

Remove:

```dart
      final settings = ref.watch(settingsProvider);
      final useComputerCns = settings.defaultCnsSource == MetricDataSource.computer;
      final computerCns = useComputerCns
          ? extractComputerCns(dive.profile)
          : null;
```text
Replace with:

```dart
      // Read per-metric source preferences from legend state
      final legendState = ref.watch(profileLegendProvider);
      final ndlSource = legendState.ndlSource;
      final ceilingSource = legendState.ceilingSource;
      final ttsSource = legendState.ttsSource;
      final cnsSource = legendState.cnsSource;

      final useComputerCns = cnsSource == MetricDataSource.computer;
      final computerCns = useComputerCns
          ? extractComputerCns(dive.profile)
          : null;
```text
Update the overlay call (around line 345):

Remove:

```dart
      final (overlaid, _) = overlayComputerDecoData(
        analysis,
        dive.profile,
        cnsSource: useComputerCns
            ? MetricDataSource.computer
            : MetricDataSource.calculated,
        ndlSource: MetricDataSource.computer,
        ceilingSource: MetricDataSource.computer,
        ttsSource: MetricDataSource.computer,
      );
```text
Replace with:

```dart
      final (overlaid, sourceInfo) = overlayComputerDecoData(
        analysis,
        dive.profile,
        ndlSource: ndlSource,
        ceilingSource: ceilingSource,
        ttsSource: ttsSource,
        cnsSource: cnsSource,
      );

      // Publish actual source info for legend badge display
      ref.read(metricSourceInfoProvider.notifier).state = sourceInfo;
```text
**Step 3: Update `_computeResidualCns` to read from legend state**

Replace (around line 394):

Remove:

```dart
    final settings = ref.watch(settingsProvider);
    final useComputerCns = settings.defaultCnsSource == MetricDataSource.computer;
```text
Replace with:

```dart
    final legendState = ref.watch(profileLegendProvider);
    final useComputerCns = legendState.cnsSource == MetricDataSource.computer;
```dart
**Step 4: Update integration tests**

In `test/features/dive_log/domain/services/computer_cns_provider_integration_test.dart`, the "Provider decision logic integration" group (line 456+) currently references `includeComputerCns: true/false`. These tests call `overlayComputerDecoData` directly with the boolean. Update them to use the new enum-based params.

In each test, replace:

- `includeComputerCns: true` with `cnsSource: MetricDataSource.computer`
- `includeComputerCns: false` with `cnsSource: MetricDataSource.calculated`
- Destructure return values: `final (overlaid, sourceInfo) = overlayComputerDecoData(...)`

For tests that always overlay NDL/ceiling/TTS (which was the old implicit behavior), explicitly pass:

```dart
ndlSource: MetricDataSource.computer,
ceilingSource: MetricDataSource.computer,
ttsSource: MetricDataSource.computer,
```text
**Step 5: Run tests**

Run: `flutter test`
Expected: All tests PASS.

**Step 6: Commit**

```bash
git add lib/features/dive_log/presentation/providers/profile_analysis_provider.dart test/features/dive_log/domain/services/computer_cns_provider_integration_test.dart
git commit -m "feat: profileAnalysisProvider reads metric sources from ProfileLegendState

Provider now watches ProfileLegendState for per-metric source
preferences instead of the old useDiveComputerCnsData boolean.
Publishes MetricSourceInfo via metricSourceInfoProvider for legend
badge display."
```text
---

## Task 7: Legend UI - Badge Labels and Source Controls

**Files:**

- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_legend.dart`

**Step 1: Add import**

```dart
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
```text
**Step 2: Update badge labels for source-capable metrics**

In the `build()` method, read the source info:

```dart
    final sourceInfo = ref.watch(metricSourceInfoProvider);
```text
Create a helper method in `_MoreOptionsButtonState` or as a top-level function:

```dart
  String _sourceLabel(String baseName, MetricDataSource preferred, MetricDataSource actual) {
    if (preferred == MetricDataSource.computer) {
      if (actual == MetricDataSource.computer) {
        return '$baseName (DC)';
      }
      // Wanted computer but fell back to calculated
      return '$baseName (Calc*)';
    }
    // User chose calculated -- no indicator needed
    return baseName;
  }
```text
**Step 3: Update the NDL, ceiling, TTS, and CNS toggle menu items**

For each of the 4 source-capable metrics in `_buildMenuItems()`, update the `label` parameter to use `_sourceLabel`. For example, the CNS entry (around line 645):

Before:

```dart
          label: context.l10n.diveLog_legend_label_cns,
```text
After:

```dart
          label: _sourceLabel(
            context.l10n.diveLog_legend_label_cns,
            legendState.cnsSource,
            sourceInfo?.cnsActual ?? MetricDataSource.calculated,
          ),
```text
Apply the same pattern for NDL (find the NDL toggle in _buildMenuItems), ceiling, and TTS.

**Step 4: Add source segmented controls below each applicable toggle**

After each source-capable metric toggle in `_buildMenuItems()`, add a source selector row. Create a helper:

```dart
  PopupMenuItem<void> _buildSourceSelector(
    BuildContext context, {
    required MetricDataSource currentSource,
    required VoidCallback onCycle,
    required bool hasComputerData,
  }) {
    return PopupMenuItem<void>(
      enabled: hasComputerData,
      height: 36,
      onTap: hasComputerData ? onCycle : null,
      child: Padding(
        padding: const EdgeInsets.only(left: 28),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Source: ',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: hasComputerData
                    ? null
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                currentSource == MetricDataSource.computer ? 'DC' : 'Calc',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: hasComputerData
                      ? null
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
```text
After the NDL toggle item, add:

```dart
    // NDL source selector
    if (config.hasNdlData) {
      final hasComputerNdl = /* determined from profile data - see note below */;
      items.add(_buildSourceSelector(
        context,
        currentSource: legendState.ndlSource,
        onCycle: legendNotifier.cycleNdlSource,
        hasComputerData: hasComputerNdl,
      ));
    }
```text
**Note on `hasComputerData` for source selectors:** The `ProfileLegendConfig` already tracks `hasNdlData`, `hasCeilingCurve`, `hasTtsData`, `hasCnsData`. These indicate whether the *analysis* has data (either calculated or computer). To know if *computer* data specifically exists, we need to check the raw profile points. The simplest approach: add boolean fields to `ProfileLegendConfig`:

```dart
  final bool hasComputerNdl;
  final bool hasComputerCeiling;
  final bool hasComputerTts;
  final bool hasComputerCns;
```text
These should be set by the parent widget that creates the config (typically `DiveProfileChartContainer` or similar). Set them by checking `profile.any((p) => p.ndl != null)` etc. If the parent doesn't easily have access, use the `sourceInfo`: if `sourceInfo.ndlActual == MetricDataSource.computer` when `ndlSource == computer`, then computer data exists.

A simpler alternative: only show the source selector when the corresponding `sourceInfo` indicates computer data was available (i.e., when `preferred == computer` and `actual == computer`, computer data exists; when `preferred == computer` and `actual == calculated`, it doesn't). This avoids needing to pass new config fields. Use the `metricSourceInfoProvider` to determine availability.

Choose the approach that fits best during implementation. The key requirement is: disable the source selector when no computer data exists for that metric.

Repeat for ceiling, TTS, and CNS source selectors.

**Step 5: Run tests**

Run: `flutter test`
Expected: All tests PASS (widget tests may not specifically test these new UI elements yet).

**Step 6: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_profile_legend.dart
git commit -m "feat: legend badges show data source indicator (DC/Calc*)

Metrics with computer source preference show '(DC)' in badge.
Fallback to calculated shows '(Calc*)'. Source selector controls
added to More menu for NDL, ceiling, TTS, CNS."
```text
---

## Task 8: Settings UI - Data Source Preferences

**Files:**

- Modify: `lib/features/settings/presentation/pages/settings_page.dart:779-795`
- Modify: `lib/features/settings/presentation/pages/appearance_page.dart`

**Step 1: Update settings_page.dart**

In `lib/features/settings/presentation/pages/settings_page.dart`, replace the "Dive Computer Data" section (lines 779-795):

Remove:

```dart
          _buildSectionHeader(context, 'Dive Computer Data'),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              title: const Text('Use Dive Computer CNS Data'),
              subtitle: const Text(
                'Prefer CNS values reported by the dive computer over app-calculated values',
              ),
              secondary: const Icon(Icons.memory),
              value: settings.useDiveComputerCnsData,
              onChanged: (value) {
                ref
                    .read(settingsProvider.notifier)
                    .setUseDiveComputerCnsData(value);
              },
            ),
          ),
```text
Replace with:

```dart
          _buildSectionHeader(context, 'Data Source Preferences'),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'When set to Dive Computer, the app uses data reported by the dive computer when available. Falls back to calculated values when computer data is not present.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _buildSourceDropdownTile(
                  context,
                  ref,
                  title: 'NDL Source',
                  value: settings.defaultNdlSource,
                  onChanged: (source) => ref
                      .read(settingsProvider.notifier)
                      .setDefaultNdlSource(source),
                ),
                const Divider(height: 1),
                _buildSourceDropdownTile(
                  context,
                  ref,
                  title: 'Ceiling Source',
                  value: settings.defaultCeilingSource,
                  onChanged: (source) => ref
                      .read(settingsProvider.notifier)
                      .setDefaultCeilingSource(source),
                ),
                const Divider(height: 1),
                _buildSourceDropdownTile(
                  context,
                  ref,
                  title: 'TTS Source',
                  value: settings.defaultTtsSource,
                  onChanged: (source) => ref
                      .read(settingsProvider.notifier)
                      .setDefaultTtsSource(source),
                ),
                const Divider(height: 1),
                _buildSourceDropdownTile(
                  context,
                  ref,
                  title: 'CNS Source',
                  value: settings.defaultCnsSource,
                  onChanged: (source) => ref
                      .read(settingsProvider.notifier)
                      .setDefaultCnsSource(source),
                ),
              ],
            ),
          ),
```text
Add this helper method to `_DecompressionSectionContent`:

```dart
  Widget _buildSourceDropdownTile(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required MetricDataSource value,
    required ValueChanged<MetricDataSource> onChanged,
  }) {
    return ListTile(
      title: Text(title),
      dense: true,
      trailing: DropdownButton<MetricDataSource>(
        value: value,
        underline: const SizedBox.shrink(),
        items: const [
          DropdownMenuItem(
            value: MetricDataSource.calculated,
            child: Text('Calculated'),
          ),
          DropdownMenuItem(
            value: MetricDataSource.computer,
            child: Text('Dive Computer'),
          ),
        ],
        onChanged: (newValue) {
          if (newValue != null) onChanged(newValue);
        },
      ),
    );
  }
```text
Add import:

```dart
import 'package:submersion/core/constants/profile_metrics.dart';
```text
**Step 2: Update appearance_page.dart**

In `lib/features/settings/presentation/pages/appearance_page.dart`, add a "Data Source Preferences" subsection after the decompression metrics toggles (after the OTU toggle at line 311). Use the same dropdown pattern:

```dart
            const SizedBox(height: 16),
            _buildSubsectionHeader(
              context,
              'Data Source Preferences',
            ),
            Card(
              child: Column(
                children: [
                  _buildSourceDropdownTile(
                    context,
                    ref,
                    title: 'NDL',
                    value: settings.defaultNdlSource,
                    onChanged: (source) => ref
                        .read(settingsProvider.notifier)
                        .setDefaultNdlSource(source),
                  ),
                  const Divider(height: 1),
                  _buildSourceDropdownTile(
                    context,
                    ref,
                    title: 'Ceiling',
                    value: settings.defaultCeilingSource,
                    onChanged: (source) => ref
                        .read(settingsProvider.notifier)
                        .setDefaultCeilingSource(source),
                  ),
                  const Divider(height: 1),
                  _buildSourceDropdownTile(
                    context,
                    ref,
                    title: 'TTS',
                    value: settings.defaultTtsSource,
                    onChanged: (source) => ref
                        .read(settingsProvider.notifier)
                        .setDefaultTtsSource(source),
                  ),
                  const Divider(height: 1),
                  _buildSourceDropdownTile(
                    context,
                    ref,
                    title: 'CNS',
                    value: settings.defaultCnsSource,
                    onChanged: (source) => ref
                        .read(settingsProvider.notifier)
                        .setDefaultCnsSource(source),
                  ),
                ],
              ),
            ),
```text
Add the same `_buildSourceDropdownTile` helper method to the appearance page widget, and the `MetricDataSource` import.

**Step 3: Run tests**

Run: `flutter test`
Expected: All tests PASS.

**Step 4: Run analyze and format**

Run: `flutter analyze && dart format lib/ test/`
Expected: No issues.

**Step 5: Commit**

```bash
git add lib/features/settings/presentation/pages/settings_page.dart lib/features/settings/presentation/pages/appearance_page.dart
git commit -m "feat: Data Source Preferences UI in settings and appearance pages

Replace single CNS toggle with per-metric dropdown selectors for NDL,
ceiling, TTS, and CNS data source. Each can be set to Calculated or
Dive Computer. Present in both decompression settings and appearance."
```text
---

## Task 9: Integration Test Updates

**Files:**

- Modify: `test/features/dive_log/domain/services/computer_cns_provider_integration_test.dart`

**Step 1: Verify all existing tests still pass**

The integration test file was partially updated in Tasks 2 and 6. Verify the full file compiles and runs:

Run: `flutter test test/features/dive_log/domain/services/computer_cns_provider_integration_test.dart`
Expected: All 20 tests PASS.

**Step 2: Add per-metric source selection integration tests**

Add a new test group after the existing groups:

```dart
  group('Per-metric source selection', () {
    late ProfileAnalysisService service;
    late List<DiveProfilePoint> profile;
    late ProfileAnalysis baseAnalysis;

    setUp(() {
      service = ProfileAnalysisService(gfLow: 0.30, gfHigh: 0.70);
      // Profile with ALL computer data types
      profile = List.generate(20, (i) {
        final depth = i < 10 ? (i * 3.0) : ((20 - i) * 3.0);
        final timestamp = i * 30;
        return DiveProfilePoint(
          depth: depth,
          timestamp: timestamp,
          temperature: 20.0,
          ndl: depth > 5 ? (99 - i) : null,
          ceiling: depth > 15 ? (depth * 0.1) : null,
          tts: depth > 15 ? (i * 2) : null,
          cns: depth > 0 ? (i * 1.5) : null,
        );
      });

      final depths = profile.map((p) => p.depth).toList();
      final timestamps = profile.map((p) => p.timestamp).toList();
      baseAnalysis = service.analyze(
        diveId: 'test-per-metric',
        depths: depths,
        timestamps: timestamps,
      );
    });

    test('all sources=computer overlays everything', () {
      final (result, sourceInfo) = overlayComputerDecoData(
        baseAnalysis,
        profile,
        ndlSource: MetricDataSource.computer,
        ceilingSource: MetricDataSource.computer,
        ttsSource: MetricDataSource.computer,
        cnsSource: MetricDataSource.computer,
      );

      expect(sourceInfo.ndlActual, MetricDataSource.computer);
      expect(sourceInfo.ceilingActual, MetricDataSource.computer);
      expect(sourceInfo.ttsActual, MetricDataSource.computer);
      expect(sourceInfo.cnsActual, MetricDataSource.computer);

      // Verify NDL curve uses computer values where available
      final ndlPoint = profile.indexWhere((p) => p.ndl != null);
      expect(result.ndlCurve[ndlPoint], profile[ndlPoint].ndl);
    });

    test('mixed sources: NDL=computer, ceiling=calculated, TTS=computer, CNS=calculated', () {
      final (result, sourceInfo) = overlayComputerDecoData(
        baseAnalysis,
        profile,
        ndlSource: MetricDataSource.computer,
        ceilingSource: MetricDataSource.calculated,
        ttsSource: MetricDataSource.computer,
        cnsSource: MetricDataSource.calculated,
      );

      expect(sourceInfo.ndlActual, MetricDataSource.computer);
      expect(sourceInfo.ceilingActual, MetricDataSource.calculated);
      expect(sourceInfo.ttsActual, MetricDataSource.computer);
      expect(sourceInfo.cnsActual, MetricDataSource.calculated);

      // Ceiling should be unchanged from base analysis
      expect(result.ceilingCurve, equals(baseAnalysis.ceilingCurve));
    });

    test('source=computer with missing data falls back', () {
      // Profile with ONLY NDL data, no ceiling/TTS/CNS
      final ndlOnlyProfile = List.generate(10, (i) {
        return DiveProfilePoint(
          depth: i * 3.0,
          timestamp: i * 30,
          temperature: 20.0,
          ndl: 99 - i,
        );
      });

      final depths = ndlOnlyProfile.map((p) => p.depth).toList();
      final timestamps = ndlOnlyProfile.map((p) => p.timestamp).toList();
      final analysis = service.analyze(
        diveId: 'test-fallback',
        depths: depths,
        timestamps: timestamps,
      );

      final (_, sourceInfo) = overlayComputerDecoData(
        analysis,
        ndlOnlyProfile,
        ndlSource: MetricDataSource.computer,
        ceilingSource: MetricDataSource.computer,
        ttsSource: MetricDataSource.computer,
        cnsSource: MetricDataSource.computer,
      );

      expect(sourceInfo.ndlActual, MetricDataSource.computer);
      expect(sourceInfo.ceilingActual, MetricDataSource.calculated); // Fallback
      expect(sourceInfo.ttsActual, MetricDataSource.calculated); // Fallback
      expect(sourceInfo.cnsActual, MetricDataSource.calculated); // Fallback
    });

    test('all sources=calculated ignores all computer data', () {
      final (result, sourceInfo) = overlayComputerDecoData(
        baseAnalysis,
        profile,
        // All defaults to calculated
      );

      expect(sourceInfo.ndlActual, MetricDataSource.calculated);
      expect(sourceInfo.ceilingActual, MetricDataSource.calculated);
      expect(sourceInfo.ttsActual, MetricDataSource.calculated);
      expect(sourceInfo.cnsActual, MetricDataSource.calculated);

      // Analysis should be unchanged
      expect(result.ndlCurve, equals(baseAnalysis.ndlCurve));
      expect(result.ceilingCurve, equals(baseAnalysis.ceilingCurve));
    });
  });
```text
**Step 3: Run tests**

Run: `flutter test test/features/dive_log/domain/services/computer_cns_provider_integration_test.dart`
Expected: All tests PASS (existing 20 + new 4 = 24 total).

**Step 4: Commit**

```bash
git add test/features/dive_log/domain/services/computer_cns_provider_integration_test.dart
git commit -m "test: add per-metric source selection integration tests

Tests cover: all-computer, mixed sources, fallback on missing data,
and all-calculated scenarios for overlayComputerDecoData."
```diff
---

## Task 10: Full Verification

**Step 1: Run full test suite**

Run: `flutter test`
Expected: All tests PASS (should be ~1470+ tests).

**Step 2: Run analyzer**

Run: `flutter analyze`
Expected: No issues found.

**Step 3: Run formatter**

Run: `dart format lib/ test/`
Expected: 0 files changed (already formatted).

**Step 4: Manual smoke test (optional)**

Run: `flutter run -d macos`

Verify:

1. Open a dive with computer data (NDL/ceiling/TTS/CNS)
2. Open the profile legend More menu -- see source selectors for applicable metrics
3. Toggle NDL source to DC -- badge should show "NDL (DC)"
4. Toggle back to Calc -- badge should show "NDL"
5. Go to Settings > Decompression > Data Source Preferences
6. Change CNS source to Dive Computer
7. Go back to dive profile -- CNS should now show computer data with "(DC)" badge
8. Open a dive WITHOUT computer data -- source selectors should be disabled, no "(DC)" badges

**Step 5: Final commit (if any formatting/analysis fixes needed)**

```bash
git add -A
git commit -m "chore: final cleanup for metric data source switching"
```

---

## Summary of Changes

| Component | What Changed |
|-----------|-------------|
| `MetricDataSource` enum | NEW -- `{computer, calculated}` with int serialization |
| `MetricSourceInfo` typedef | NEW -- reports actual source per metric |
| Database migration v42 | 4 new int columns, migrates old CNS toggle |
| `AppSettings` | 4 new `MetricDataSource` fields replace `useDiveComputerCnsData` |
| `DiverSettingsRepository` | Reads/writes `MetricDataSource` as int |
| `ProfileLegendState` | 4 new source fields with cycle methods |
| `overlayComputerDecoData` | Per-metric source params, returns `(ProfileAnalysis, MetricSourceInfo)` |
| `profileAnalysisProvider` | Reads legend state for sources, publishes `MetricSourceInfo` |
| `metricSourceInfoProvider` | NEW -- communicates actual sources to UI |
| Legend widget | Badge labels show "(DC)"/"(Calc*)", source selectors in More menu |
| Settings pages | "Data Source Preferences" section replaces single CNS toggle |

### Removed

- `useDiveComputerCnsData` field, provider, setter
- `useDiveComputerCnsDataProvider` convenience provider
- `setUseDiveComputerCnsData` method
- "Dive Computer Data" UI section with single toggle
