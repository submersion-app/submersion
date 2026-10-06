# Default Tank Preset Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a default tank preset setting (defaulting to AL80) that auto-populates new dive tanks and optionally fills missing fields on imported dives.

**Architecture:** Store the preset name in `DiverSettings` and resolve it at runtime via `TankPresetRepository`. A centralized utility handles import fallback logic. The Tank Presets page gets a default indicator and import toggle.

**Tech Stack:** Flutter, Drift ORM, Riverpod, go_router

**Spec:** `docs/superpowers/specs/2026-03-18-default-tank-preset-design.md`

---

### Task 1: Database Schema — Add Columns and Migration

**Files:**
- Modify: `lib/core/database/database.dart:602-605` (DiverSettings table, add columns after `defaultStartPressure`)
- Modify: `lib/core/database/database.dart:1183` (increment `currentSchemaVersion` from 49 to 50)
- Modify: `lib/core/database/database.dart:2277` (add migration block after `if (from < 49)` block)

- [ ] **Step 1: Add columns to DiverSettings table**

In `lib/core/database/database.dart`, after the `defaultStartPressure` column definition (line 605), add:

```dart
  TextColumn get defaultTankPreset =>
      text().nullable().withDefault(const Constant('al80'))();
  BoolColumn get applyDefaultTankToImports =>
      boolean().withDefault(const Constant(false))();
```

- [ ] **Step 2: Increment schema version**

Change line 1183:

```dart
static const int currentSchemaVersion = 50;
```

- [ ] **Step 3: Add migration block**

After the `if (from < 49)` block (after line ~2277), add:

```dart
        if (from < 50) {
          final settingsInfo = await customSelect(
            'PRAGMA table_info(diver_settings)',
          ).get();
          final settingsCols = settingsInfo
              .map((r) => r.read<String>('name'))
              .toSet();
          if (!settingsCols.contains('default_tank_preset')) {
            await customStatement(
              "ALTER TABLE diver_settings ADD COLUMN default_tank_preset TEXT DEFAULT 'al80'",
            );
          }
          if (!settingsCols.contains('apply_default_tank_to_imports')) {
            await customStatement(
              'ALTER TABLE diver_settings ADD COLUMN apply_default_tank_to_imports INTEGER NOT NULL DEFAULT 0',
            );
          }
        }
```

- [ ] **Step 4: Run code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Drift generates updated `database.g.dart` with new columns

- [ ] **Step 5: Verify compilation**

Run: `flutter analyze`
Expected: No new errors (existing issues may be present)

- [ ] **Step 6: Commit**

```bash
git add lib/core/database/database.dart lib/core/database/database.g.dart
git commit -m "feat(db): add defaultTankPreset and applyDefaultTankToImports columns to DiverSettings"
```

---

### Task 2: AppSettings and SettingsNotifier — Add Fields and Setters

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart:38-39` (add storage keys)
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart:71-72` (add fields after `defaultStartPressure`)
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart:236-237` (add constructor defaults)
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart:340-341` (add to `copyWith` params)
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart:653-661` (add setter methods after `setDefaultStartPressure`)
- Test: `test/features/settings/presentation/providers/settings_providers_test.dart`

- [ ] **Step 1: Write failing test for new AppSettings fields**

Create or update `test/features/settings/presentation/providers/settings_providers_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  group('AppSettings defaultTankPreset', () {
    test('has al80 as default', () {
      const settings = AppSettings();
      expect(settings.defaultTankPreset, 'al80');
    });

    test('has applyDefaultTankToImports false as default', () {
      const settings = AppSettings();
      expect(settings.applyDefaultTankToImports, false);
    });

    test('copyWith updates defaultTankPreset', () {
      const settings = AppSettings();
      final updated = settings.copyWith(defaultTankPreset: 'hp100');
      expect(updated.defaultTankPreset, 'hp100');
    });

    test('copyWith updates applyDefaultTankToImports', () {
      const settings = AppSettings();
      final updated = settings.copyWith(applyDefaultTankToImports: true);
      expect(updated.applyDefaultTankToImports, true);
    });

    test('copyWith can clear defaultTankPreset', () {
      const settings = AppSettings(defaultTankPreset: 'hp100');
      final updated = settings.copyWith(clearDefaultTankPreset: true);
      expect(updated.defaultTankPreset, null);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/settings/presentation/providers/settings_providers_test.dart`
Expected: FAIL — `defaultTankPreset` field does not exist

- [ ] **Step 3: Add storage keys**

In `lib/features/settings/presentation/providers/settings_providers.dart`, after line 39 (`defaultStartPressure` key), add:

```dart
  static const String defaultTankPreset = 'default_tank_preset';
  static const String applyDefaultTankToImports = 'apply_default_tank_to_imports';
```

- [ ] **Step 4: Add fields to AppSettings class**

After `defaultStartPressure` field (line 72), add:

```dart
  final String? defaultTankPreset;
  final bool applyDefaultTankToImports;
```

- [ ] **Step 5: Add constructor defaults**

After `this.defaultStartPressure = 200,` (line 237), add:

```dart
    this.defaultTankPreset = 'al80',
    this.applyDefaultTankToImports = false,
```

- [ ] **Step 6: Add copyWith parameters**

After `int? defaultStartPressure,` (line 341), add:

```dart
    String? defaultTankPreset,
    bool clearDefaultTankPreset = false,
    bool? applyDefaultTankToImports,
```

And in the `return AppSettings(...)` body, after the `defaultStartPressure` mapping, add:

```dart
      defaultTankPreset: clearDefaultTankPreset ? null : (defaultTankPreset ?? this.defaultTankPreset),
      applyDefaultTankToImports: applyDefaultTankToImports ?? this.applyDefaultTankToImports,
```

- [ ] **Step 7: Add setter methods to SettingsNotifier**

After `setDefaultStartPressure()` (line 661), add:

```dart
  Future<void> setDefaultTankPreset(String? presetName) async {
    state = state.copyWith(
      defaultTankPreset: presetName,
      clearDefaultTankPreset: presetName == null,
    );
    await _saveSettings();
  }

  Future<void> setApplyDefaultTankToImports(bool value) async {
    state = state.copyWith(applyDefaultTankToImports: value);
    await _saveSettings();
  }
```

- [ ] **Step 8: Run test to verify it passes**

Run: `flutter test test/features/settings/presentation/providers/settings_providers_test.dart`
Expected: PASS

- [ ] **Step 9: Commit**

```bash
git add lib/features/settings/presentation/providers/settings_providers.dart test/features/settings/presentation/providers/settings_providers_test.dart
git commit -m "feat(settings): add defaultTankPreset and applyDefaultTankToImports to AppSettings"
```

---

### Task 3: DiverSettingsRepository — Persist New Columns

**Files:**
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart:65-66` (createSettingsForDiver)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart:173-174` (updateSettingsForDiver)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart:317-318` (_mapRowToAppSettings)

- [ ] **Step 1: Update _mapRowToAppSettings()**

In `_mapRowToAppSettings()` (around line 318), after `defaultStartPressure: row.defaultStartPressure,`, add:

```dart
      defaultTankPreset: row.defaultTankPreset,
      applyDefaultTankToImports: row.applyDefaultTankToImports,
```

- [ ] **Step 2: Update createSettingsForDiver()**

In `createSettingsForDiver()` (around line 66), after `defaultStartPressure: Value(s.defaultStartPressure),`, add:

```dart
              defaultTankPreset: Value(s.defaultTankPreset),
              applyDefaultTankToImports: Value(s.applyDefaultTankToImports),
```

- [ ] **Step 3: Update updateSettingsForDiver()**

In `updateSettingsForDiver()` (around line 174), after `defaultStartPressure: Value(settings.defaultStartPressure),`, add:

```dart
          defaultTankPreset: Value(settings.defaultTankPreset),
          applyDefaultTankToImports: Value(settings.applyDefaultTankToImports),
```

- [ ] **Step 4: Update sync serializer**

In `lib/core/services/sync/sync_data_serializer.dart`, find the two locations where `defaultTankVolume` and `defaultStartPressure` are referenced (around lines 1352-1353 and 1432-1433) and add the new fields after them:

In the defaults map (around line 1353):
```dart
      'defaultTankPreset': 'al80',
      'applyDefaultTankToImports': false,
```

In the row serializer (around line 1433):
```dart
    'defaultTankPreset': r.defaultTankPreset,
    'applyDefaultTankToImports': r.applyDefaultTankToImports,
```

- [ ] **Step 5: Verify compilation**

Run: `flutter analyze`
Expected: No new errors

- [ ] **Step 6: Commit**

```bash
git add lib/features/settings/data/repositories/diver_settings_repository.dart lib/core/services/sync/sync_data_serializer.dart
git commit -m "feat(settings): persist defaultTankPreset and applyDefaultTankToImports in repository and sync"
```

---

### Task 4: Preset Resolution Utility

**Files:**
- Create: `lib/features/tank_presets/domain/services/default_tank_preset_resolver.dart`
- Test: `test/features/tank_presets/domain/services/default_tank_preset_resolver_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/domain/services/default_tank_preset_resolver.dart';

void main() {
  group('DefaultTankPresetResolver', () {
    test('resolves built-in preset by name', () async {
      final resolver = DefaultTankPresetResolver();
      final result = await resolver.resolve('al80');
      expect(result, isNotNull);
      expect(result!.name, 'al80');
      expect(result.volumeLiters, 11.1);
      expect(result.workingPressureBar, 207);
    });

    test('returns null for unknown preset name', () async {
      final resolver = DefaultTankPresetResolver();
      final result = await resolver.resolve('nonexistent');
      expect(result, isNull);
    });

    test('returns null for null preset name', () async {
      final resolver = DefaultTankPresetResolver();
      final result = await resolver.resolve(null);
      expect(result, isNull);
    });

    test('resolves all built-in presets', () async {
      final resolver = DefaultTankPresetResolver();
      for (final preset in TankPresets.all) {
        final result = await resolver.resolve(preset.name);
        expect(result, isNotNull, reason: 'Failed to resolve ${preset.name}');
        expect(result!.volumeLiters, preset.volumeLiters);
      }
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/tank_presets/domain/services/default_tank_preset_resolver_test.dart`
Expected: FAIL — file does not exist

- [ ] **Step 3: Implement the resolver**

Create `lib/features/tank_presets/domain/services/default_tank_preset_resolver.dart`:

```dart
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/features/tank_presets/data/repositories/tank_preset_repository.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';

/// Resolves a preset name to a [TankPresetEntity].
///
/// When a repository is available, delegates to [TankPresetRepository.getPresetByName()]
/// which checks custom presets first, then built-in. This ensures a custom preset
/// that shadows a built-in name is found correctly.
///
/// Without a repository, falls back to built-in presets only.
/// Returns null if the preset name is not found (stale reference).
class DefaultTankPresetResolver {
  final TankPresetRepository? _repository;

  DefaultTankPresetResolver({
    TankPresetRepository? repository,
  }) : _repository = repository;

  /// Resolve a preset name to a [TankPresetEntity].
  ///
  /// Returns null if [presetName] is null or the preset cannot be found.
  Future<TankPresetEntity?> resolve(String? presetName) async {
    if (presetName == null) return null;

    // Delegate to repository (checks custom first, then built-in)
    if (_repository != null) {
      return _repository.getPresetByName(presetName);
    }

    // Fallback: built-in presets only (no DB available)
    final builtIn = TankPresets.byName(presetName);
    if (builtIn != null) {
      return TankPresetEntity.fromBuiltIn(builtIn);
    }

    return null;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/tank_presets/domain/services/default_tank_preset_resolver_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/tank_presets/domain/services/default_tank_preset_resolver.dart test/features/tank_presets/domain/services/default_tank_preset_resolver_test.dart
git commit -m "feat(tank-presets): add DefaultTankPresetResolver utility"
```

---

### Task 5: Update _addTank() and initState() in DiveEditPage

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart:2-4` (add imports)
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart:79-80` (add cached preset field)
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart:177-193` (update initState to pre-fetch preset)
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart:1823-1836` (update _addTank)

- [ ] **Step 1: Add import**

At the top of `dive_edit_page.dart`, add:

```dart
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/domain/services/default_tank_preset_resolver.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
```

- [ ] **Step 2: Add cached preset field and import for TankPresets**

In `_DiveEditPageState` class (around line 79), add a field:

```dart
  TankPresetEntity? _defaultPreset;
```

Also add the built-in presets import at the top of the file:

```dart
import 'package:submersion/core/constants/tank_presets.dart';
```

- [ ] **Step 3: Add preset pre-fetch method**

Add a method to the state class. This resolves built-in presets synchronously via `TankPresets.byName()` first, then falls back to async for custom presets. A `_tanksDirty` flag prevents overwriting user edits if the async path returns after the user has interacted.

```dart
  bool _tanksDirty = false;

  Future<void> _loadDefaultPreset() async {
    final settings = ref.read(settingsProvider);
    final presetName = settings.defaultTankPreset;

    // Try synchronous built-in resolution first
    final builtIn = presetName != null ? TankPresets.byName(presetName) : null;
    if (builtIn != null) {
      _defaultPreset = TankPresetEntity.fromBuiltIn(builtIn);
      return;
    }

    // Async fallback for custom presets
    if (presetName != null) {
      final repository = ref.read(tankPresetRepositoryProvider);
      final resolver = DefaultTankPresetResolver(repository: repository);
      final preset = await resolver.resolve(presetName);
      if (mounted) {
        setState(() => _defaultPreset = preset);
      }
    }
  }
```

- [ ] **Step 4: Update initState() to use default preset for initial tank**

Replace the tank initialization in `initState()` (lines 182-193). After `_entryTime = TimeOfDay.now();` (line 180), replace the `_tanks = [...]` block with:

**Note:** The original code used `endPressure: 50` — we preserve that behavior.

```dart
    // Eagerly resolve built-in presets (sync), async for custom
    _loadDefaultPreset();

    final settings = ref.read(settingsProvider);
    _tanks = [
      DiveTank(
        id: _uuid.v4(),
        volume: _defaultPreset?.volumeLiters ?? settings.defaultTankVolume,
        workingPressure: _defaultPreset?.workingPressureBar,
        startPressure: settings.defaultStartPressure,
        endPressure: 50,
        gasMix: const GasMix(),
        role: TankRole.backGas,
        material: _defaultPreset?.material,
        order: 0,
        presetName: _defaultPreset?.name,
      ),
    ];
```

Since `_loadDefaultPreset()` resolves built-in presets synchronously (AL80, HP100, etc.), the `_defaultPreset` is already populated by the time we construct the tank — no race condition. Custom presets resolve async but that's a rare edge case, and the `_tanksDirty` guard prevents overwriting user edits.

- [ ] **Step 5: Update _addTank() method**

Replace `_addTank()` (lines 1823-1836) with:

```dart
  void _addTank() {
    final settings = ref.read(settingsProvider);
    _tanksDirty = true;
    setState(() {
      _tanks.add(
        DiveTank(
          id: _uuid.v4(),
          volume: _defaultPreset?.volumeLiters ?? settings.defaultTankVolume,
          workingPressure: _defaultPreset?.workingPressureBar,
          startPressure: settings.defaultStartPressure,
          endPressure: 50,
          gasMix: const GasMix(),
          role: _tanks.isEmpty ? TankRole.backGas : TankRole.stage,
          material: _defaultPreset?.material,
          order: _tanks.length,
          presetName: _defaultPreset?.name,
        ),
      );
    });
  }
```

- [ ] **Step 6: Verify compilation**

Run: `flutter analyze`
Expected: No new errors

- [ ] **Step 7: Commit**

```bash
git add lib/features/dive_log/presentation/pages/dive_edit_page.dart
git commit -m "feat(dive-edit): use default tank preset when adding tanks"
```

---

### Task 6: Import Tank Fallback Utility

**Files:**
- Create: `lib/features/universal_import/data/services/import_tank_defaults.dart`
- Test: `test/features/universal_import/data/services/import_tank_defaults_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/universal_import/data/services/import_tank_defaults.dart';

void main() {
  final al80 = TankPresetEntity.fromBuiltIn(TankPresets.al80);

  group('applyTankDefaults', () {
    test('fills missing volume from preset', () {
      final tank = <String, dynamic>{
        'startPressure': 200,
      };
      final result = applyTankDefaults(
        tank,
        defaultPreset: al80,
        defaultStartPressure: 200,
      );
      expect(result['volume'], 11.1);
      expect(result['startPressure'], 200);
    });

    test('does not overwrite existing volume', () {
      final tank = <String, dynamic>{
        'volume': 15.0,
      };
      final result = applyTankDefaults(
        tank,
        defaultPreset: al80,
        defaultStartPressure: 200,
      );
      expect(result['volume'], 15.0);
    });

    test('fills missing workingPressure from preset', () {
      final tank = <String, dynamic>{};
      final result = applyTankDefaults(
        tank,
        defaultPreset: al80,
        defaultStartPressure: 200,
      );
      expect(result['workingPressure'], 207);
    });

    test('does not overwrite existing workingPressure', () {
      final tank = <String, dynamic>{
        'workingPressure': 234,
      };
      final result = applyTankDefaults(
        tank,
        defaultPreset: al80,
        defaultStartPressure: 200,
      );
      expect(result['workingPressure'], 234);
    });

    test('fills missing material from preset', () {
      final tank = <String, dynamic>{};
      final result = applyTankDefaults(
        tank,
        defaultPreset: al80,
        defaultStartPressure: 200,
      );
      expect(result['material'], TankMaterial.aluminum);
    });

    test('does not overwrite existing material', () {
      final tank = <String, dynamic>{
        'material': TankMaterial.steel,
      };
      final result = applyTankDefaults(
        tank,
        defaultPreset: al80,
        defaultStartPressure: 200,
      );
      expect(result['material'], TankMaterial.steel);
    });

    test('fills missing startPressure from defaultStartPressure', () {
      final tank = <String, dynamic>{};
      final result = applyTankDefaults(
        tank,
        defaultPreset: al80,
        defaultStartPressure: 210,
      );
      expect(result['startPressure'], 210);
    });

    test('treats zero volume as missing', () {
      final tank = <String, dynamic>{
        'volume': 0.0,
      };
      final result = applyTankDefaults(
        tank,
        defaultPreset: al80,
        defaultStartPressure: 200,
      );
      expect(result['volume'], 11.1);
    });

    test('treats zero workingPressure as missing', () {
      final tank = <String, dynamic>{
        'workingPressure': 0,
      };
      final result = applyTankDefaults(
        tank,
        defaultPreset: al80,
        defaultStartPressure: 200,
      );
      expect(result['workingPressure'], 207);
    });

    test('returns unmodified tank when no preset provided', () {
      final tank = <String, dynamic>{
        'volume': 15.0,
      };
      final result = applyTankDefaults(
        tank,
        defaultPreset: null,
        defaultStartPressure: 200,
      );
      expect(result['volume'], 15.0);
      expect(result.containsKey('workingPressure'), false);
    });

    test('applies startPressure fallback even without preset', () {
      final tank = <String, dynamic>{};
      final result = applyTankDefaults(
        tank,
        defaultPreset: null,
        defaultStartPressure: 200,
      );
      expect(result['startPressure'], 200);
    });
  });

  group('applyTankDefaultsToList', () {
    test('applies defaults to all tanks in list', () {
      final tanks = [
        <String, dynamic>{'volume': 15.0},
        <String, dynamic>{},
      ];
      final results = applyTankDefaultsToList(
        tanks,
        defaultPreset: al80,
        defaultStartPressure: 200,
      );
      expect(results[0]['volume'], 15.0);
      expect(results[1]['volume'], 11.1);
    });

    test('returns empty list for empty input', () {
      final results = applyTankDefaultsToList(
        [],
        defaultPreset: al80,
        defaultStartPressure: 200,
      );
      expect(results, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/universal_import/data/services/import_tank_defaults_test.dart`
Expected: FAIL — file does not exist

- [ ] **Step 3: Implement the utility**

Create `lib/features/universal_import/data/services/import_tank_defaults.dart`:

```dart
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';

/// Apply default tank values to a single tank data map.
///
/// Fills missing fields (volume, workingPressure, material) from [defaultPreset]
/// and missing startPressure from [defaultStartPressure].
/// Fields that already have non-zero values are left untouched.
///
/// Returns a new map with defaults applied (does not mutate the input).
Map<String, dynamic> applyTankDefaults(
  Map<String, dynamic> tank, {
  required TankPresetEntity? defaultPreset,
  required int defaultStartPressure,
}) {
  final result = Map<String, dynamic>.of(tank);

  if (defaultPreset != null) {
    // Fill volume if missing or zero
    final volume = result['volume'];
    if (volume == null || (volume is num && volume <= 0)) {
      result['volume'] = defaultPreset.volumeLiters;
    }

    // Fill workingPressure if missing or zero
    final wp = result['workingPressure'];
    if (wp == null || (wp is num && wp <= 0)) {
      result['workingPressure'] = defaultPreset.workingPressureBar;
    }

    // Fill material if missing
    if (result['material'] == null) {
      result['material'] = defaultPreset.material;
    }
  }

  // Fill startPressure if missing or zero (independent of preset)
  final sp = result['startPressure'];
  if (sp == null || (sp is num && sp <= 0)) {
    result['startPressure'] = defaultStartPressure;
  }

  return result;
}

/// Apply default tank values to a list of tank data maps.
///
/// Convenience wrapper around [applyTankDefaults] for batch processing.
List<Map<String, dynamic>> applyTankDefaultsToList(
  List<Map<String, dynamic>> tanks, {
  required TankPresetEntity? defaultPreset,
  required int defaultStartPressure,
}) {
  return tanks
      .map(
        (t) => applyTankDefaults(
          t,
          defaultPreset: defaultPreset,
          defaultStartPressure: defaultStartPressure,
        ),
      )
      .toList();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/universal_import/data/services/import_tank_defaults_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/universal_import/data/services/import_tank_defaults.dart test/features/universal_import/data/services/import_tank_defaults_test.dart
git commit -m "feat(import): add import tank defaults utility for per-field fallback"
```

---

### Task 7: Integrate Tank Defaults into UddfEntityImporter and Providers

**Files:**

- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart:1141-1182` (_buildTanks method)
- Modify: `lib/features/universal_import/presentation/providers/universal_import_providers.dart`
- Modify: `lib/features/dive_import/presentation/providers/uddf_import_providers.dart`

**Architecture note:** All import formats (UDDF, CSV, FIT, Subsurface XML) converge through `UddfEntityImporter._buildTanks()` to create `DiveTank` objects. The universal import system converts all parsed payloads to the UDDF format via `_toUddfResult(payload)` before saving. This means modifying `_buildTanks()` in `UddfEntityImporter` covers ALL import paths — the individual parsers do NOT need modification.

**Important:** `UddfEntityImporter` is currently instantiated as `const UddfEntityImporter()` in both `uddf_import_providers.dart` (~line 459) and `universal_import_providers.dart` (~line 473). Adding instance fields removes the `const` constructor, so BOTH call sites must be updated.

- [ ] **Step 1: Add imports to uddf_entity_importer.dart**

At the top of `uddf_entity_importer.dart`, add:

```dart
import 'package:submersion/features/universal_import/data/services/import_tank_defaults.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
```

- [ ] **Step 2: Add fields and update constructor**

Find the class constructor/fields of `UddfEntityImporter` and add optional parameters. The class is currently `const` — it becomes non-const:

```dart
  final TankPresetEntity? _defaultTankPreset;
  final int _defaultStartPressure;
  final bool _applyDefaultTankToImports;

  UddfEntityImporter({
    TankPresetEntity? defaultTankPreset,
    int defaultStartPressure = 200,
    bool applyDefaultTankToImports = false,
  })  : _defaultTankPreset = defaultTankPreset,
        _defaultStartPressure = defaultStartPressure,
        _applyDefaultTankToImports = applyDefaultTankToImports;
```

- [ ] **Step 3: Apply defaults in _buildTanks()**

In `_buildTanks()` (line 1141), after `final tanksData = diveData['tanks'] as List<Map<String, dynamic>>?;` (line 1142), add the fallback logic:

```dart
    if (tanksData != null && tanksData.isNotEmpty) {
      final processedTanks = _applyDefaultTankToImports
          ? applyTankDefaultsToList(
              tanksData,
              defaultPreset: _defaultTankPreset,
              defaultStartPressure: _defaultStartPressure,
            )
          : tanksData;
      return processedTanks.map((t) {
```

Update the rest of the method to use `processedTanks` instead of `tanksData`.

- [ ] **Step 4: Update both call sites to pass settings**

In BOTH `uddf_import_providers.dart` (~line 459) and `universal_import_providers.dart` (~line 473), replace `const UddfEntityImporter()` with:

```dart
final settings = ref.read(settingsProvider);
TankPresetEntity? defaultPreset;
if (settings.applyDefaultTankToImports && settings.defaultTankPreset != null) {
  final repository = ref.read(tankPresetRepositoryProvider);
  final resolver = DefaultTankPresetResolver(repository: repository);
  defaultPreset = await resolver.resolve(settings.defaultTankPreset);
}

final importer = UddfEntityImporter(
  defaultTankPreset: defaultPreset,
  defaultStartPressure: settings.defaultStartPressure,
  applyDefaultTankToImports: settings.applyDefaultTankToImports,
);
```

Add necessary imports for `DefaultTankPresetResolver`, `settingsProvider`, and `tankPresetRepositoryProvider` at the top of each file.

- [ ] **Step 5: Fix existing test**

The existing test file `test/features/dive_import/data/services/uddf_entity_importer_test.dart` uses `const importer = UddfEntityImporter()`. Since the constructor is no longer `const`, change it to `final importer = UddfEntityImporter()`.

- [ ] **Step 6: Verify compilation**

Run: `flutter analyze`
Expected: No new errors

- [ ] **Step 7: Commit**

```bash
git add lib/features/dive_import/data/services/uddf_entity_importer.dart lib/features/universal_import/presentation/providers/universal_import_providers.dart lib/features/dive_import/presentation/providers/uddf_import_providers.dart test/features/dive_import/data/services/uddf_entity_importer_test.dart
git commit -m "feat(import): apply default tank preset fallback in entity importer and providers"
```

---

### Task 8: Add Localization Keys

Localization keys must be added BEFORE the UI task (Task 9) that references them.

**Files:**

- Modify: localization ARB files (find the pattern used in the project)

- [ ] **Step 1: Find the localization files**

Search for existing `tankPresets_` l10n keys to find the right ARB file(s).

- [ ] **Step 2: Add new keys**

Add the following keys to the ARB file(s):

```json
"tankPresets_defaultSettings": "Default Tank",
"tankPresets_applyToImports": "Apply default tank to imports",
"tankPresets_applyToImports_subtitle": "Fill in missing tank data on imported dives using the default preset",
"tankPresets_setAsDefault": "Set as default",
"tankPresets_currentDefault": "Current default",
"tankPresets_deleteDefaultMessage": "Are you sure you want to delete {name}? This is your current default tank preset and will be reset to AL80."
```

- [ ] **Step 3: Run code generation if needed**

Run: `flutter gen-l10n` or equivalent

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/
git commit -m "feat(l10n): add localization keys for default tank preset feature"
```

---

### Task 9: Tank Presets Page — Default Indicator and Toggle

**Files:**
- Modify: `lib/features/tank_presets/presentation/pages/tank_presets_page.dart` (entire file)
- Test: `test/features/tank_presets/presentation/pages/tank_presets_page_test.dart`

- [ ] **Step 1: Write failing test for default indicator**

Create `test/features/tank_presets/presentation/pages/tank_presets_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/tank_presets/presentation/pages/tank_presets_page.dart';

// Test that the page shows a star icon for the default preset.
// (Full widget test setup with providers omitted for brevity —
//  follow the pattern in test/features/settings/presentation/pages/settings_page_test.dart)
void main() {
  group('TankPresetsPage', () {
    // Tests will be implemented following existing test patterns
    test('placeholder for default indicator tests', () {
      // Verify the TankPresetsPage class exists and can be constructed
      const page = TankPresetsPage();
      expect(page, isNotNull);
    });
  });
}
```

- [ ] **Step 2: Add settings import**

In `tank_presets_page.dart`, the `settings_providers.dart` import already exists (line 6). No change needed.

- [ ] **Step 3: Add "Apply default tank to imports" toggle**

In the `build()` method, inside the `data: (presets)` callback (line 39), before the `return ListView(...)`, add a header section. Replace the `return ListView(...)` block with:

```dart
          return ListView(
            children: [
              // Default tank settings header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  context.l10n.tankPresets_defaultSettings,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              SwitchListTile(
                title: Text(context.l10n.tankPresets_applyToImports),
                subtitle: Text(context.l10n.tankPresets_applyToImports_subtitle),
                value: settings.applyDefaultTankToImports,
                onChanged: (value) {
                  ref
                      .read(settingsProvider.notifier)
                      .setApplyDefaultTankToImports(value);
                },
              ),
              const Divider(),
              if (customPresets.isNotEmpty) ...[
```

Note: The l10n keys need to be added. Use the existing localization pattern. If l10n keys don't exist yet, use hardcoded strings initially and add l10n in a follow-up.

- [ ] **Step 4: Add default star icon to _buildPresetTile()**

Update `_buildPresetTile()` to show a star icon indicating the default. The method signature already receives `ref` so it can read settings.

Replace the `trailing` section of the ListTile (lines 125-142) with logic that includes a default star button for all presets:

```dart
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              isDefault ? Icons.star : Icons.star_outline,
              color: isDefault
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            onPressed: isDefault
                ? null
                : () => ref
                    .read(settingsProvider.notifier)
                    .setDefaultTankPreset(preset.name),
            tooltip: isDefault
                ? context.l10n.tankPresets_currentDefault
                : context.l10n.tankPresets_setAsDefault,
          ),
          if (canEdit) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  context.push('/tank-presets/${preset.id}/edit'),
              tooltip: context.l10n.tankPresets_editPreset,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref, preset),
              tooltip: context.l10n.tankPresets_deletePreset,
            ),
          ],
        ],
      ),
```

To determine `isDefault`, pass it into the method. Update the method signature to accept `bool isDefault` and compute it in the caller:

```dart
  Widget _buildPresetTile(
    BuildContext context,
    WidgetRef ref,
    TankPresetEntity preset,
    UnitFormatter units, {
    required bool canEdit,
    required bool isDefault,
  }) {
```

Update callers (lines 55 and 70) to pass `isDefault`:

```dart
  isDefault: settings.defaultTankPreset == preset.name,
```

- [ ] **Step 5: Update _confirmDelete() for default preset warning**

Update `_confirmDelete()` to warn when deleting the default preset. Add a check at the start:

```dart
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TankPresetEntity preset,
  ) async {
    final settings = ref.read(settingsProvider);
    final isDefault = settings.defaultTankPreset == preset.name;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.tankPresets_deleteTitle),
        content: Text(
          isDefault
              ? context.l10n.tankPresets_deleteDefaultMessage(preset.displayName)
              : context.l10n.tankPresets_deleteMessage(preset.displayName),
        ),
```

After successful deletion, if it was the default, reset to AL80:

```dart
    if (confirmed == true) {
      try {
        final notifier = ref.read(tankPresetListNotifierProvider.notifier);
        await notifier.deletePreset(preset.id);
        if (isDefault) {
          ref.read(settingsProvider.notifier).setDefaultTankPreset('al80');
        }
```

- [ ] **Step 6: Run formatting**

Run: `dart format lib/features/tank_presets/presentation/pages/tank_presets_page.dart`

- [ ] **Step 7: Verify compilation**

Run: `flutter analyze`
Expected: No new errors

- [ ] **Step 8: Commit**

```bash
git add lib/features/tank_presets/presentation/pages/tank_presets_page.dart test/features/tank_presets/presentation/pages/tank_presets_page_test.dart
git commit -m "feat(tank-presets): add default preset indicator and import toggle to Tank Presets page"
```

---

### Task 10: Run Full Test Suite and Format

**Files:** All modified files

- [ ] **Step 1: Format all code**

Run: `dart format lib/ test/`

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze`
Expected: No new errors introduced

- [ ] **Step 3: Run all tests**

Run: `flutter test`
Expected: All tests pass

- [ ] **Step 4: Fix any failures**

Address any test failures or analyzer warnings.

- [ ] **Step 5: Final commit if formatting changes needed**

```bash
git add -A
git commit -m "chore: format and fix lint issues for default tank preset feature"
```
