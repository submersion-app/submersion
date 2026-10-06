# Computer CNS Preference Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a per-diver setting to prefer dive-computer-reported CNS data for the O2 toxicity card, with seamless chaining across dives that mix computer and calculated CNS.

**Architecture:** New boolean setting flows through the existing per-diver settings pipeline (Drift table -> repository -> Riverpod provider). The `profileAnalysisProvider` checks this setting and either derives CNS from computer samples or calculates from NOAA tables. The recursive `_computeResidualCns` short-circuits at dives with computer CNS.

**Tech Stack:** Flutter, Drift ORM, Riverpod, SQLite

---

### Task 1: Database Migration (v41) - Add Setting Column

**Files:**

- Modify: `lib/core/database/database.dart:565` (DiverSettings table)
- Modify: `lib/core/database/database.dart:1106` (schemaVersion)
- Modify: `lib/core/database/database.dart` (migration block, after `if (from < 40)`)

**Step 1: Add column to DiverSettings table**

In `lib/core/database/database.dart`, after line 565 (`decoStopIncrement`), add:

```dart
  BoolColumn get useDiveComputerCnsData =>
      boolean().withDefault(const Constant(false))();
```text
**Step 2: Bump schema version**

Change line 1106 from `int get schemaVersion => 40;` to `int get schemaVersion => 41;`

**Step 3: Add migration step**

After the `if (from < 40)` block, add:

```dart
        if (from < 41) {
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN use_dive_computer_cns_data INTEGER NOT NULL DEFAULT 0',
          );
        }
```text
**Step 4: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Build completes, `database.g.dart` regenerated with new column.

**Step 5: Commit**

```

feat: add useDiveComputerCnsData setting column (migration v41)

```text
---

### Task 2: Settings Data Model - AppSettings + Repository

**Files:**

- Modify: `lib/features/settings/presentation/providers/settings_providers.dart:105` (AppSettings field)
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart:221` (constructor default)
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart:315` (copyWith param)
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart:372` (copyWith body)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart:76` (create)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart:175` (update)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart:310` (read)

**Step 1: Add field to AppSettings class**

In `settings_providers.dart`, after `decoStopIncrement` (line 105), add:

```dart
  /// Whether to use dive-computer-reported CNS data when available
  final bool useDiveComputerCnsData;
```text
**Step 2: Add constructor default**

After `this.decoStopIncrement = 3.0,` (around line 221), add:

```dart
    this.useDiveComputerCnsData = false,
```text
**Step 3: Add copyWith parameter and body line**

Add to copyWith params (after `decoStopIncrement`):

```dart
    bool? useDiveComputerCnsData,
```text
Add to copyWith body (after `decoStopIncrement` line):

```dart
      useDiveComputerCnsData: useDiveComputerCnsData ?? this.useDiveComputerCnsData,
```text
**Step 4: Add to repository create method**

In `diver_settings_repository.dart` `createSettingsForDiver`, after `decoStopIncrement` line (~76), add:

```dart
              useDiveComputerCnsData: Value(s.useDiveComputerCnsData),
```text
**Step 5: Add to repository update method**

In `updateSettingsForDiver`, after `decoStopIncrement` line (~175), add:

```dart
          useDiveComputerCnsData: Value(settings.useDiveComputerCnsData),
```text
**Step 6: Add to repository read mapping**

In `_mapRowToAppSettings`, after `decoStopIncrement` line (~310), add:

```dart
      useDiveComputerCnsData: row.useDiveComputerCnsData,
```text
**Step 7: Commit**

```

feat: add useDiveComputerCnsData to AppSettings and repository

```dart
---

### Task 3: Settings Provider + Convenience Provider

**Files:**

- Modify: `lib/features/settings/presentation/providers/settings_providers.dart:680` (SettingsNotifier setter)
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart:957` (convenience provider)

**Step 1: Add setter to SettingsNotifier**

After `setDecoStopIncrement` (~line 680), add:

```dart
  Future<void> setUseDiveComputerCnsData(bool value) async {
    state = state.copyWith(useDiveComputerCnsData: value);
    await _saveSettings();
  }
```text
**Step 2: Add convenience provider**

After `showNdlOnProfileProvider` (~line 957), add:

```dart
final useDiveComputerCnsDataProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.useDiveComputerCnsData));
});
```text
**Step 3: Commit**

```

feat: add useDiveComputerCnsData setter and convenience provider

```text
---

### Task 4: Settings UI - Toggle in Decompression Section

**Files:**

- Modify: `lib/features/settings/presentation/pages/settings_page.dart:771-778` (_DecompressionSectionContent)

**Step 1: Add SwitchListTile to decompression section**

In `_DecompressionSectionContent.build()`, before the closing `],` of the Column children (line 778), add after the info card:

```dart
          const SizedBox(height: 24),
          _buildSectionHeader(
            context,
            'Dive Computer Data',
          ),
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
Note: Localization strings should be added later when all l10n keys are batched. Use string literals for now.

**Step 2: Verify visually**

Run: `flutter run -d macos`, navigate to Settings > Decompression.
Expected: New "Dive Computer Data" section with toggle visible below gradient factors.

**Step 3: Commit**

```

feat: add dive computer CNS data toggle to decompression settings

```text
---

### Task 5: extractComputerCns Helper - Tests First

**Files:**

- Create: `test/features/dive_log/domain/services/computer_cns_extractor_test.dart`
- Create: `lib/features/dive_log/domain/services/computer_cns_extractor.dart`

**Step 1: Write failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/computer_cns_extractor.dart';

void main() {
  group('extractComputerCns', () {
    test('returns null when profile has no CNS samples', () {
      final profile = [
        DiveProfilePoint(timestamp: 0, depth: 10.0),
        DiveProfilePoint(timestamp: 60, depth: 20.0),
        DiveProfilePoint(timestamp: 120, depth: 10.0),
      ];
      expect(extractComputerCns(profile), isNull);
    });

    test('returns start and end from computer CNS samples', () {
      final profile = [
        DiveProfilePoint(timestamp: 0, depth: 10.0, cns: 5.0),
        DiveProfilePoint(timestamp: 60, depth: 20.0, cns: 8.0),
        DiveProfilePoint(timestamp: 120, depth: 10.0, cns: 12.0),
      ];
      final result = extractComputerCns(profile);
      expect(result, isNotNull);
      expect(result!.cnsStart, 5.0);
      expect(result.cnsEnd, 12.0);
    });

    test('handles sparse CNS samples (nulls in between)', () {
      final profile = [
        DiveProfilePoint(timestamp: 0, depth: 10.0),
        DiveProfilePoint(timestamp: 60, depth: 20.0, cns: 3.0),
        DiveProfilePoint(timestamp: 120, depth: 15.0),
        DiveProfilePoint(timestamp: 180, depth: 10.0, cns: 9.0),
      ];
      final result = extractComputerCns(profile);
      expect(result, isNotNull);
      expect(result!.cnsStart, 3.0);
      expect(result.cnsEnd, 9.0);
    });

    test('handles single CNS sample', () {
      final profile = [
        DiveProfilePoint(timestamp: 0, depth: 10.0),
        DiveProfilePoint(timestamp: 60, depth: 20.0, cns: 7.0),
        DiveProfilePoint(timestamp: 120, depth: 10.0),
      ];
      final result = extractComputerCns(profile);
      expect(result, isNotNull);
      expect(result!.cnsStart, 7.0);
      expect(result.cnsEnd, 7.0);
    });

    test('returns null for empty profile', () {
      expect(extractComputerCns([]), isNull);
    });
  });

  group('hasComputerCns', () {
    test('returns true when profile has CNS samples', () {
      final profile = [
        DiveProfilePoint(timestamp: 0, depth: 10.0, cns: 5.0),
      ];
      expect(hasComputerCns(profile), isTrue);
    });

    test('returns false when profile has no CNS samples', () {
      final profile = [
        DiveProfilePoint(timestamp: 0, depth: 10.0),
      ];
      expect(hasComputerCns(profile), isFalse);
    });
  });
}
```typescript
**Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/domain/services/computer_cns_extractor_test.dart`
Expected: FAIL (file not found / function not defined)

**Step 3: Write minimal implementation**

Create `lib/features/dive_log/domain/services/computer_cns_extractor.dart`:

```dart
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Result of extracting CNS start/end from dive computer samples.
typedef ComputerCnsResult = ({double cnsStart, double cnsEnd});

/// Extracts cnsStart and cnsEnd from computer-reported per-sample CNS data.
///
/// Scans the profile for the first and last non-null CNS values.
/// Returns null if no computer CNS samples exist.
ComputerCnsResult? extractComputerCns(List<DiveProfilePoint> profile) {
  double? first;
  double? last;
  for (final point in profile) {
    if (point.cns != null) {
      first ??= point.cns!;
      last = point.cns!;
    }
  }
  if (first == null || last == null) return null;
  return (cnsStart: first, cnsEnd: last);
}

/// Whether the profile contains any computer-reported CNS samples.
bool hasComputerCns(List<DiveProfilePoint> profile) {
  return profile.any((p) => p.cns != null);
}
```text
**Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/domain/services/computer_cns_extractor_test.dart`
Expected: All 6 tests PASS

**Step 5: Commit**

```

feat: add extractComputerCns and hasComputerCns helpers with tests

```text
---

### Task 6: Wire Setting into profileAnalysisProvider

**Files:**

- Modify: `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart`

This is the core logic change. Three modifications:

**Step 1: Add imports**

Add at top of `profile_analysis_provider.dart`:

```dart
import 'package:submersion/features/dive_log/domain/services/computer_cns_extractor.dart';
```text
**Step 2: Modify profileAnalysisProvider to check setting**

In `profileAnalysisProvider`, before the `_computeResidualCns` call (around line 307), add the setting check and conditional logic:

```dart
      // Check if dive computer CNS data should be used
      final useComputerCns = ref.watch(useDiveComputerCnsDataProvider);
      final computerCns = useComputerCns
          ? extractComputerCns(dive.profile)
          : null;

      // Compute residual CNS (skip if this dive has computer CNS data)
      final startCns = computerCns != null
          ? 0.0  // Will be overridden by computer data
          : await _computeResidualCns(ref, diveId);
```dart
Replace the existing `final startCns = await _computeResidualCns(ref, diveId);` line.

**Step 3: After overlayComputerDecoData, override o2Exposure if computer CNS available**

After the `overlayComputerDecoData` call (around line 334), and before the event merging, add:

```dart
      // Override o2Exposure with computer-reported CNS start/end
      final withCns = computerCns != null
          ? overlaid.copyWith(
              o2Exposure: overlaid.o2Exposure.copyWith(
                cnsStart: computerCns.cnsStart,
                cnsEnd: computerCns.cnsEnd,
              ),
            )
          : overlaid;
```typescript
Then use `withCns` instead of `overlaid` in the rest of the function (event merging).

**Step 4: Modify _computeResidualCns to short-circuit**

In `_computeResidualCns`, after `getPreviousDive` (line 364), add the short-circuit check:

```dart
    final previousDive = await repository.getPreviousDive(diveId);
    if (previousDive == null) return 0.0;

    // Short-circuit: if the setting is on and the previous dive has computer
    // CNS, use its last CNS sample directly instead of full analysis.
    final useComputerCns = ref.watch(useDiveComputerCnsDataProvider);
    if (useComputerCns) {
      final prevComputerCns = extractComputerCns(previousDive.profile);
      if (prevComputerCns != null) {
        return CnsTable.cnsAfterSurfaceInterval(
          prevComputerCns.cnsEnd,
          surfaceInterval!.inMinutes,
        );
      }
    }

    // Fall through to recursive calculation
```text
The existing recursive code after this point remains unchanged.

**Step 5: Verify builds**

Run: `flutter analyze`
Expected: No issues

**Step 6: Commit**

```

feat: wire useDiveComputerCnsData setting into profile analysis

```dart
---

### Task 7: Provider Integration Tests

**Files:**

- Create: `test/features/dive_log/domain/services/computer_cns_provider_integration_test.dart`

**Step 1: Write integration tests for the provider behavior**

Test scenarios:

1. Setting ON + dive with computer CNS -> o2Exposure uses computer values
2. Setting ON + dive without computer CNS -> o2Exposure uses calculated values
3. Setting OFF + dive with computer CNS -> o2Exposure uses calculated values (ignores computer)
4. Recursive chain: previous dive has computer CNS, current does not, setting ON -> residual derived from computer cnsEnd

These tests use Riverpod `ProviderContainer` overrides to mock repository responses. Follow the pattern in the existing `test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart`.

**Step 2: Run tests**

Run: `flutter test test/features/dive_log/domain/services/computer_cns_provider_integration_test.dart`
Expected: All tests PASS

**Step 3: Commit**

```text

test: add integration tests for computer CNS preference setting

```

---

### Task 8: Full Verification

**Step 1: Run full test suite**

Run: `flutter test`
Expected: All tests pass (previous count was 1440, now ~1450+)

**Step 2: Run analyzer**

Run: `flutter analyze`
Expected: No issues

**Step 3: Run formatter**

Run: `dart format lib/ test/`
Expected: No formatting changes needed

**Step 4: Commit any formatting fixes if needed**

---

### Task 9: Final Commit + Summary

**Step 1: Review all changes**

Verify the complete list of modified/created files:

- `lib/core/database/database.dart` (migration v41, new column)
- `lib/features/settings/presentation/providers/settings_providers.dart` (field, copyWith, setter, convenience provider)
- `lib/features/settings/data/repositories/diver_settings_repository.dart` (create, update, read mapping)
- `lib/features/settings/presentation/pages/settings_page.dart` (UI toggle)
- `lib/features/dive_log/domain/services/computer_cns_extractor.dart` (NEW: helper functions)
- `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart` (core logic changes)
- `test/features/dive_log/domain/services/computer_cns_extractor_test.dart` (NEW: unit tests)
- `test/features/dive_log/domain/services/computer_cns_provider_integration_test.dart` (NEW: integration tests)
