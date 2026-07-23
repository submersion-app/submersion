# Color Accents Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Optional per-feature-area accent colors applied to nav icons, page-header icons, and list/settings icons, controlled by three per-diver synced toggles in Settings > Appearance.

**Architecture:** A `FeatureAccentColors` ThemeExtension (curated light/dark palette keyed by feature id) registered on all 5 theme presets; three `DiverSettings` boolean columns (schema v135) flowing through `AppSettings`/`SettingsNotifier`; a shared `resolveFeatureAccent` helper + `FeatureAccentIcon`/`FeatureAppBarTitle` widgets consumed by the three surfaces. The desktop NavigationRail is refactored to iterate `kNavDestinations` first.

**Tech Stack:** Flutter Material 3, Drift ORM, Riverpod, ARB l10n.

**Spec:** `docs/superpowers/specs/2026-07-23-color-accents-design.md` (read it first).

## Global Constraints

- Schema bump is exactly **134 → 135**; migration must be idempotent (`_assert*` helper called from both `onUpgrade` and the `beforeOpen` backstop, mirroring `_assertDecoStopSettingsColumns`).
- All three toggles default **false** at every layer (Drift `withDefault`, SQL `DEFAULT 0`, `AppSettings` constructor, sync import defaults).
- Only icons are tinted — labels/text never take accent colors. The `more` nav sentinel is never tinted.
- Every new user-visible string is added to `lib/l10n/arb/app_en.arb` **and all 10 non-English locales** (ar, de, es, fr, he, hu, it, nl, pt, zh), then `flutter gen-l10n`.
- `dart format .` must produce no changes; `flutter analyze` must be clean (info-level lints fail CI).
- No emojis anywhere. TDD per task: failing test first. Commit at the end of every task.
- Run tests with a timeout guard (`flutter test <path>`); never pipe analyze/test output through `tail`/`head` in a way that masks the exit code.

---

### Task 1: FeatureAccentColors ThemeExtension + palette

**Files:**
- Create: `lib/core/theme/feature_accent_colors.dart`
- Test: `test/core/theme/feature_accent_colors_test.dart`

**Interfaces:**
- Consumes: `kNavDestinations` from `package:submersion/shared/widgets/nav/nav_destinations.dart` (test only).
- Produces: `class FeatureAccentColors extends ThemeExtension<FeatureAccentColors>` with `Map<String, Color> colors`, `Color? of(String featureId)`, `static const FeatureAccentColors light`, `static const FeatureAccentColors dark`. Later tasks call `Theme.of(context).extension<FeatureAccentColors>()?.of(id)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/theme/feature_accent_colors_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/feature_accent_colors.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';

void main() {
  group('FeatureAccentColors', () {
    test('every routable nav destination has an entry in both palettes', () {
      final routableIds = kNavDestinations
          .where((d) => d.id != 'more')
          .map((d) => d.id);
      for (final id in routableIds) {
        expect(FeatureAccentColors.light.of(id), isNotNull,
            reason: 'light palette missing $id');
        expect(FeatureAccentColors.dark.of(id), isNotNull,
            reason: 'dark palette missing $id');
      }
    });

    test('the more sentinel is intentionally absent', () {
      expect(FeatureAccentColors.light.of('more'), isNull);
      expect(FeatureAccentColors.dark.of('more'), isNull);
    });

    test('settings root sections have settings-prefixed entries', () {
      const sectionIds = [
        'about', 'appearance', 'data', 'dataSources', 'decompression',
        'profile', 'safety', 'manage', 'notifications', 'sharedData',
        'units', 'debug',
      ];
      for (final id in sectionIds) {
        expect(FeatureAccentColors.light.of('settings-$id'), isNotNull);
        expect(FeatureAccentColors.dark.of('settings-$id'), isNotNull);
      }
    });

    test('unknown id returns null', () {
      expect(FeatureAccentColors.light.of('nonexistent'), isNull);
    });

    test('light and dark palettes have identical key sets', () {
      expect(FeatureAccentColors.light.colors.keys.toSet(),
          FeatureAccentColors.dark.colors.keys.toSet());
    });

    test('lerp interpolates per key', () {
      final mid = FeatureAccentColors.light
          .lerp(FeatureAccentColors.dark, 0.5);
      final expected = Color.lerp(FeatureAccentColors.light.of('dives'),
          FeatureAccentColors.dark.of('dives'), 0.5);
      expect(mid.of('dives'), expected);
    });

    test('copyWith replaces the map', () {
      final replaced = FeatureAccentColors.light
          .copyWith(colors: const {'x': Color(0xFF000000)});
      expect(replaced.of('x'), const Color(0xFF000000));
      expect(replaced.of('dives'), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/feature_accent_colors_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package ... feature_accent_colors.dart` (file does not exist).

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/theme/feature_accent_colors.dart
import 'package:flutter/material.dart';

/// Curated per-feature-area accent colors, exposed as a [ThemeExtension] so
/// lookups resolve against the active theme brightness and animate across
/// theme changes. Keys are the stable `NavDestination.id` strings plus
/// `settings-<sectionId>` entries for the settings root sections. A missing
/// key means "no accent" — callers fall back to the ambient icon color.
class FeatureAccentColors extends ThemeExtension<FeatureAccentColors> {
  const FeatureAccentColors({required this.colors});

  final Map<String, Color> colors;

  Color? of(String featureId) => colors[featureId];

  static const FeatureAccentColors light = FeatureAccentColors(
    colors: {
      'dashboard': Color(0xFF0077B6),
      'dives': Color(0xFF1976D2),
      'sites': Color(0xFF388E3C),
      'trips': Color(0xFF7B1FA2),
      'equipment': Color(0xFFF57C00),
      'buddies': Color(0xFFC2185B),
      'dive-centers': Color(0xFF6D4C41),
      'certifications': Color(0xFFFFA000),
      'courses': Color(0xFF303F9F),
      'statistics': Color(0xFF00796B),
      'planning': Color(0xFF512DA8),
      'transfer': Color(0xFF0097A7),
      'gps-log': Color(0xFFD32F2F),
      'settings': Color(0xFF455A64),
      // Settings root sections: identical to the colors previously hardcoded
      // on settingsSections so the root page look does not change.
      'settings-about': Color(0xFF607D8B),
      'settings-appearance': Color(0xFFE91E63),
      'settings-data': Color(0xFF4CAF50),
      'settings-dataSources': Color(0xFFF44336),
      'settings-decompression': Color(0xFF673AB7),
      'settings-profile': Color(0xFF2196F3),
      'settings-safety': Color(0xFFFF5252),
      'settings-manage': Color(0xFF3F51B5),
      'settings-notifications': Color(0xFFFF9800),
      'settings-sharedData': Color(0xFF00BCD4),
      'settings-units': Color(0xFF009688),
      'settings-debug': Color(0xFF9E9E9E),
    },
  );

  static const FeatureAccentColors dark = FeatureAccentColors(
    colors: {
      'dashboard': Color(0xFF48CAE4),
      'dives': Color(0xFF64B5F6),
      'sites': Color(0xFF81C784),
      'trips': Color(0xFFBA68C8),
      'equipment': Color(0xFFFFB74D),
      'buddies': Color(0xFFF06292),
      'dive-centers': Color(0xFFBCAAA4),
      'certifications': Color(0xFFFFD54F),
      'courses': Color(0xFF7986CB),
      'statistics': Color(0xFF4DB6AC),
      'planning': Color(0xFF9575CD),
      'transfer': Color(0xFF4DD0E1),
      'gps-log': Color(0xFFE57373),
      'settings': Color(0xFF90A4AE),
      'settings-about': Color(0xFF90A4AE),
      'settings-appearance': Color(0xFFF06292),
      'settings-data': Color(0xFF81C784),
      'settings-dataSources': Color(0xFFE57373),
      'settings-decompression': Color(0xFF9575CD),
      'settings-profile': Color(0xFF64B5F6),
      'settings-safety': Color(0xFFFF8A80),
      'settings-manage': Color(0xFF7986CB),
      'settings-notifications': Color(0xFFFFB74D),
      'settings-sharedData': Color(0xFF4DD0E1),
      'settings-units': Color(0xFF4DB6AC),
      'settings-debug': Color(0xFFBDBDBD),
    },
  );

  @override
  FeatureAccentColors copyWith({Map<String, Color>? colors}) {
    return FeatureAccentColors(colors: colors ?? this.colors);
  }

  @override
  FeatureAccentColors lerp(
    ThemeExtension<FeatureAccentColors>? other,
    double t,
  ) {
    if (other is! FeatureAccentColors) return this;
    final keys = {...colors.keys, ...other.colors.keys};
    return FeatureAccentColors(
      colors: {
        for (final key in keys)
          key: Color.lerp(colors[key], other.colors[key], t) ??
              (other.colors[key] ?? colors[key]!),
      },
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/feature_accent_colors_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Format and commit**

```bash
dart format lib/core/theme/feature_accent_colors.dart test/core/theme/feature_accent_colors_test.dart
git add lib/core/theme/feature_accent_colors.dart test/core/theme/feature_accent_colors_test.dart
git commit -m "feat(theme): FeatureAccentColors ThemeExtension with curated palette"
```

---

### Task 2: Register the extension on all 5 theme presets

**Files:**
- Modify: `lib/core/theme/full_themes/submersion_theme.dart`
- Modify: `lib/core/theme/full_themes/console_theme.dart`
- Modify: `lib/core/theme/full_themes/tropical_theme.dart`
- Modify: `lib/core/theme/full_themes/minimalist_theme.dart`
- Modify: `lib/core/theme/full_themes/deep_theme.dart`
- Test: `test/core/theme/theme_preset_accents_test.dart`

**Interfaces:**
- Consumes: `FeatureAccentColors.light` / `.dark` (Task 1); `AppThemeRegistry.presets`.
- Produces: `themeData.extension<FeatureAccentColors>()` non-null on every preset's light and dark themes.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/theme/theme_preset_accents_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/core/theme/feature_accent_colors.dart';

void main() {
  test('every theme preset registers FeatureAccentColors in both modes', () {
    for (final preset in AppThemeRegistry.presets) {
      expect(preset.lightTheme.extension<FeatureAccentColors>(),
          same(FeatureAccentColors.light),
          reason: '${preset.id} light theme missing accents');
      expect(preset.darkTheme.extension<FeatureAccentColors>(),
          same(FeatureAccentColors.dark),
          reason: '${preset.id} dark theme missing accents');
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/theme_preset_accents_test.dart`
Expected: FAIL — extension lookups return null.

- [ ] **Step 3: Register the extension in each preset file**

In each of the 5 files, add the import and an `extensions:` entry to BOTH `ThemeData` definitions. Worked example for `submersion_theme.dart` (apply the identical pattern to console, tropical, minimalist, deep — light theme gets `.light`, dark theme gets `.dark`):

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/theme/feature_accent_colors.dart';
```

```dart
final ThemeData submersionLight = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  extensions: const <ThemeExtension<dynamic>>[FeatureAccentColors.light],
  colorScheme: ColorScheme.fromSeed(
```

```dart
final ThemeData submersionDark = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  extensions: const <ThemeExtension<dynamic>>[FeatureAccentColors.dark],
  colorScheme: ColorScheme.fromSeed(
```

Note: if a preset file's `ThemeData` already has an `extensions:` list (none do today), append to it instead of adding a second one.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/theme_preset_accents_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/core/theme/
git add lib/core/theme/ test/core/theme/theme_preset_accents_test.dart
git commit -m "feat(theme): register FeatureAccentColors on all theme presets"
```

---

### Task 3: DiverSettings columns + schema v135 migration

**Files:**
- Modify: `lib/core/database/database.dart` (table def ~line 1466; `currentSchemaVersion` line 2846; versions list ending line 3008; new `_assert` helper near `_assertDecoStopSettingsColumns` line 3526; `onUpgrade` after line 7037; `beforeOpen` backstop near line 7135)
- Test: `test/core/database/migration_v135_accent_columns_test.dart`
- Generated: rerun build_runner.

**Interfaces:**
- Consumes: existing migration ladder patterns.
- Produces: Drift columns `accentNavIcons`, `accentSectionHeaders`, `accentListIcons` (SQL: `accent_nav_icons`, `accent_section_headers`, `accent_list_icons`) on `DiverSettings`; generated `DiverSetting` data class and companion fields of the same names (Task 4 and 5 depend on these).

- [ ] **Step 1: Write the failing migration test** (pattern copied from `test/core/database/migration_v126_emergency_card_test.dart`)

```dart
// test/core/database/migration_v135_accent_columns_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Minimal pre-v135 shape: a diver_settings table without the accent columns,
/// stamped at v134 so the 134->135 upgrade runs the accent-columns block.
NativeDatabase _dbAt134() {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 134');
      rawDb.execute('''
        CREATE TABLE diver_settings (
          id TEXT NOT NULL PRIMARY KEY
        )
      ''');
      rawDb.execute("INSERT INTO diver_settings (id) VALUES ('settings')");
    },
  );
}

void main() {
  test('v135 adds accent toggle columns defaulting to 0', () async {
    final db = AppDatabase(_dbAt134());
    addTearDown(() => db.close());

    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, containsAll(<String>{
      'accent_nav_icons',
      'accent_section_headers',
      'accent_list_icons',
    }));

    // The pre-existing row hydrates with the disabled default.
    final row = await db
        .customSelect(
          'SELECT accent_nav_icons, accent_section_headers, '
          'accent_list_icons FROM diver_settings',
        )
        .getSingle();
    expect(row.read<int>('accent_nav_icons'), 0);
    expect(row.read<int>('accent_section_headers'), 0);
    expect(row.read<int>('accent_list_icons'), 0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/database/migration_v135_accent_columns_test.dart`
Expected: FAIL — columns absent (schema still 134, no migration block).

- [ ] **Step 3: Make the schema changes in `lib/core/database/database.dart`**

3a. Table definition — after the `themePreset` column (line ~1466) add:

```dart
  // Color accents (optional per-surface icon tinting; all default off)
  BoolColumn get accentNavIcons =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get accentSectionHeaders =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get accentListIcons =>
      boolean().withDefault(const Constant(false))();
```

3b. Version constant (line 2846):

```dart
  static const int currentSchemaVersion = 135;
```

3c. Versions list — after the `134,` entry (line 3008) add:

```dart
    // v135: color accent toggle columns on diver_settings.
    135,
  ];
```

3d. Idempotent helper — place next to `_assertDecoStopSettingsColumns` (after line 3544):

```dart
  /// v135: color accent toggle columns on diver_settings. Idempotent; safe
  /// to call from both onUpgrade and the beforeOpen backstop.
  Future<void> _assertAccentColorSettingsColumns() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    for (final column in const [
      'accent_nav_icons',
      'accent_section_headers',
      'accent_list_icons',
    ]) {
      if (!names.contains(column)) {
        await customStatement(
          'ALTER TABLE diver_settings ADD COLUMN $column '
          'INTEGER NOT NULL DEFAULT 0 CHECK ($column IN (0, 1))',
        );
      }
    }
  }
```

3e. `onUpgrade` — after the `if (from < 134) await reportProgress();` line (7037):

```dart
        // v135: color accent toggle columns on diver_settings.
        if (from < 135) {
          await _assertAccentColorSettingsColumns();
        }
        if (from < 135) await reportProgress();
```

3f. `beforeOpen` backstop — next to the v133 backstop call to `_assertDecoStopSettingsColumns()` (line ~7135):

```dart
        // v135 backstop: re-assert color accent toggle columns.
        await _assertAccentColorSettingsColumns();
```

- [ ] **Step 4: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: completes with no errors; `database.g.dart` gains the three fields.

- [ ] **Step 5: Run tests**

Run: `flutter test test/core/database/migration_v135_accent_columns_test.dart`
Expected: PASS.
Also run: `flutter test test/core/database/` — the other migration tests must still pass.

- [ ] **Step 6: Format and commit**

```bash
dart format lib/core/database/ test/core/database/migration_v135_accent_columns_test.dart
git add -A lib/core/database/ test/core/database/migration_v135_accent_columns_test.dart
git commit -m "feat(db): v135 accent toggle columns on diver_settings"
```

---

### Task 4: AppSettings fields, repository mapping, notifier setters, gate providers

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (AppSettings fields ~line 104; constructor defaults ~line 382; copyWith ~lines 517/640; setters after `setThemePreset` ~line 1030; gate providers after `themePresetProvider` ~line 1619)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart` (insert companion ~line 74; update companion ~line 222; row-to-AppSettings read ~line 412)
- Test: `test/features/settings/presentation/providers/settings_notifier_real_test.dart` (extend existing file — it already provides `_InMemorySettingsRepository`)

**Interfaces:**
- Consumes: generated `DiverSettingsCompanion.accentNavIcons/...` fields (Task 3).
- Produces: `AppSettings.accentNavIcons`, `.accentSectionHeaders`, `.accentListIcons` (bool); `SettingsNotifier.setAccentNavIcons(bool)`, `.setAccentSectionHeaders(bool)`, `.setAccentListIcons(bool)`; providers `accentNavIconsProvider`, `accentSectionHeadersProvider`, `accentListIconsProvider` (`Provider<bool>`). Tasks 6-12 depend on these names.

- [ ] **Step 1: Write the failing test** — add this group to `settings_notifier_real_test.dart`, inside `main()`, using the file's existing setup helpers (mirror how an adjacent group constructs the notifier with `_InMemorySettingsRepository`; reuse its container/notifier fixtures exactly):

```dart
  group('accent color toggles', () {
    test('default to false', () {
      expect(const AppSettings().accentNavIcons, isFalse);
      expect(const AppSettings().accentSectionHeaders, isFalse);
      expect(const AppSettings().accentListIcons, isFalse);
    });

    test('setters update state and persist through the repository', () async {
      // Use the same notifier/repository fixture pattern as the groups above.
      await notifier.setAccentNavIcons(true);
      expect(notifier.state.accentNavIcons, isTrue);

      await notifier.setAccentSectionHeaders(true);
      expect(notifier.state.accentSectionHeaders, isTrue);

      await notifier.setAccentListIcons(true);
      expect(notifier.state.accentListIcons, isTrue);

      // Round-trip: the in-memory repository stored the values.
      final stored = await repository.getSettingsForDiver(diverId);
      expect(stored?.accentNavIcons, isTrue);
      expect(stored?.accentSectionHeaders, isTrue);
      expect(stored?.accentListIcons, isTrue);
    });
  });
```

(Adapt local variable names — `notifier`, `repository`, `diverId` — to whatever the surrounding groups in that file actually use; the file already has setUp blocks at lines 71/272/471/543 to copy from.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/settings/presentation/providers/settings_notifier_real_test.dart`
Expected: FAIL — `accentNavIcons` getter undefined on AppSettings.

- [ ] **Step 3: Implement in `settings_providers.dart`**

3a. Fields, after `final String themePresetId;` (line 104):

```dart
  final bool accentNavIcons;
  final bool accentSectionHeaders;
  final bool accentListIcons;
```

3b. Constructor defaults, next to `this.themePresetId = 'submersion',` (line ~382):

```dart
    this.accentNavIcons = false,
    this.accentSectionHeaders = false,
    this.accentListIcons = false,
```

3c. `copyWith` parameters, next to `String? themePresetId,` (line ~528):

```dart
    bool? accentNavIcons,
    bool? accentSectionHeaders,
    bool? accentListIcons,
```

and assignments, next to `themePresetId: themePresetId ?? this.themePresetId,` (line ~640):

```dart
      accentNavIcons: accentNavIcons ?? this.accentNavIcons,
      accentSectionHeaders: accentSectionHeaders ?? this.accentSectionHeaders,
      accentListIcons: accentListIcons ?? this.accentListIcons,
```

3d. Setters on `SettingsNotifier`, after `setThemePreset` (line ~1031):

```dart
  Future<void> setAccentNavIcons(bool value) async {
    state = state.copyWith(accentNavIcons: value);
    await _saveSettings();
  }

  Future<void> setAccentSectionHeaders(bool value) async {
    state = state.copyWith(accentSectionHeaders: value);
    await _saveSettings();
  }

  Future<void> setAccentListIcons(bool value) async {
    state = state.copyWith(accentListIcons: value);
    await _saveSettings();
  }
```

3e. Gate providers, after `themePresetProvider` (line ~1619):

```dart
/// Color accent toggles (narrow selects so surfaces rebuild only on their
/// own toggle, not on every settings mutation).
final accentNavIconsProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.accentNavIcons));
});

final accentSectionHeadersProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.accentSectionHeaders));
});

final accentListIconsProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.accentListIcons));
});
```

- [ ] **Step 4: Implement mapping in `diver_settings_repository.dart`**

4a. Insert companion — after `themePreset: Value(s.themePresetId),` (line 74):

```dart
              accentNavIcons: Value(s.accentNavIcons),
              accentSectionHeaders: Value(s.accentSectionHeaders),
              accentListIcons: Value(s.accentListIcons),
```

4b. Update companion — after `themePreset: Value(settings.themePresetId),` (line 222):

```dart
          accentNavIcons: Value(settings.accentNavIcons),
          accentSectionHeaders: Value(settings.accentSectionHeaders),
          accentListIcons: Value(settings.accentListIcons),
```

4c. Read mapping — after `themePresetId: row.themePreset,` (line 412):

```dart
      accentNavIcons: row.accentNavIcons,
      accentSectionHeaders: row.accentSectionHeaders,
      accentListIcons: row.accentListIcons,
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/settings/presentation/providers/settings_notifier_real_test.dart`
Expected: PASS (new group + all pre-existing groups).

- [ ] **Step 6: Format and commit**

```bash
dart format lib/features/settings/ test/features/settings/
git add lib/features/settings/ test/features/settings/presentation/providers/settings_notifier_real_test.dart
git commit -m "feat(settings): accent toggle state, persistence, and gate providers"
```

---

### Task 5: Sync import defaults

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (`_applyDiverSettingDefaults`, map beginning line 5094)
- Test: extend the existing sync serializer diver-settings test if one covers `_applyDiverSettingDefaults` seeding (search: `grep -rn "applyDiverSettingDefaults\|seed it so payloads" test/core/services/sync/`); otherwise add `test/core/services/sync/diver_settings_accent_defaults_test.dart` following the import-path pattern of the nearest existing serializer test.

Note: NO export change is needed — `_exportDiverSettings` serializes whole rows via the generated `toJson()` (line 4133), which automatically includes the new columns.

**Interfaces:**
- Consumes: generated `DiverSetting.fromJson` (Task 3).
- Produces: legacy payloads (missing the accent keys) import without throwing, hydrating to `false`.

- [ ] **Step 1: Write the failing test.** If an existing defaults test enumerates seeded keys, extend it with the three new keys. Otherwise create a focused test that exercises the code path the defaults protect — `DiverSetting.fromJson` on a payload predating v135. Follow the setup idiom of the nearest test in `test/core/services/sync/` (they construct the serializer against an in-memory `AppDatabase`); the essential assertion:

```dart
    // A payload from a pre-v135 device has no accent keys. After defaults
    // are applied on import, the row must hydrate with the toggles off
    // rather than throwing in DiverSetting.fromJson.
    final imported = await importDiverSettingsPayload(legacyPayloadWithoutAccentKeys);
    expect(imported.accentNavIcons, isFalse);
    expect(imported.accentSectionHeaders, isFalse);
    expect(imported.accentListIcons, isFalse);
```

(Use the actual import entry point the existing serializer tests call; do not invent a new public API for the test.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test <the test file>`
Expected: FAIL — `fromJson` throws on the missing non-nullable bool keys (or the keys are absent from the defaults map).

- [ ] **Step 3: Add the defaults** in `_applyDiverSettingDefaults`, after the `'themePreset': 'submersion',` entry (line 5108):

```dart
      // Color accents (non-nullable bools added in v135; seed payloads
      // predating the columns so fromJson hydrates instead of throwing).
      'accentNavIcons': false,
      'accentSectionHeaders': false,
      'accentListIcons': false,
```

- [ ] **Step 4: Run tests**

Run: `flutter test <the test file>` — PASS.
Also run the existing sync serializer diver-settings tests to confirm no regressions.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/core/services/sync/ test/core/services/sync/
git add lib/core/services/sync/ test/core/services/sync/
git commit -m "feat(sync): seed accent toggle defaults for pre-v135 payloads"
```

---

### Task 6: l10n strings + Appearance page toggles

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` + all 10 non-English arb files (`app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`)
- Modify: `lib/features/settings/presentation/pages/appearance_page.dart` (insert after the nav-customization Consumer block + its Divider, line ~120)
- Test: `test/features/settings/presentation/pages/appearance_page_accents_test.dart` (if `test/features/settings/presentation/pages/` already contains an appearance page test, extend it instead)

**Interfaces:**
- Consumes: `settingsProvider` / `SettingsNotifier.setAccent*` (Task 4).
- Produces: l10n getters `settings_appearance_colorAccents`, `settings_appearance_accentNavIcons`, `settings_appearance_accentNavIcons_subtitle`, `settings_appearance_accentSectionHeaders`, `settings_appearance_accentSectionHeaders_subtitle`, `settings_appearance_accentListIcons`, `settings_appearance_accentListIcons_subtitle`.

- [ ] **Step 1: Add English strings** to `app_en.arb` (alongside the other `settings_appearance_*` keys):

```json
  "settings_appearance_colorAccents": "Color accents",
  "settings_appearance_accentNavIcons": "Colored navigation icons",
  "settings_appearance_accentNavIcons_subtitle": "Tint main menu icons with each feature's color",
  "settings_appearance_accentSectionHeaders": "Colored section headers",
  "settings_appearance_accentSectionHeaders_subtitle": "Show a colored feature icon next to page titles",
  "settings_appearance_accentListIcons": "Colored list icons",
  "settings_appearance_accentListIcons_subtitle": "Tint icons in lists and settings pages",
```

- [ ] **Step 2: Translate into all 10 non-English locales.** Add the same 7 keys with translated values to each arb file. Worked example for `app_de.arb`:

```json
  "settings_appearance_colorAccents": "Farbakzente",
  "settings_appearance_accentNavIcons": "Farbige Navigationssymbole",
  "settings_appearance_accentNavIcons_subtitle": "Hauptmenü-Symbole in Themenfarben einfärben",
  "settings_appearance_accentSectionHeaders": "Farbige Bereichsüberschriften",
  "settings_appearance_accentSectionHeaders_subtitle": "Farbiges Symbol neben Seitentiteln anzeigen",
  "settings_appearance_accentListIcons": "Farbige Listensymbole",
  "settings_appearance_accentListIcons_subtitle": "Symbole in Listen und Einstellungen einfärben",
```

Translate idiomatically for ar, es, fr, he, hu, it, nl, pt, zh as well — every file gets all 7 keys.

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: completes; getters available on `AppLocalizations`.

- [ ] **Step 4: Write the failing widget test**

```dart
// test/features/settings/presentation/pages/appearance_page_accents_test.dart
// Follow the harness pattern of the existing page tests in this directory
// (e.g. safety_settings_page_test.dart): ProviderScope with the same
// overrides they use for settingsProvider, MaterialApp with
// AppLocalizations delegates, pump AppearancePage.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('appearance page shows three accent toggles, all off', (tester) async {
    // ...pump AppearancePage via the directory's standard harness...
    expect(find.text('Color accents'), findsOneWidget);
    expect(find.text('Colored navigation icons'), findsOneWidget);
    expect(find.text('Colored section headers'), findsOneWidget);
    expect(find.text('Colored list icons'), findsOneWidget);
    final switches = tester
        .widgetList<SwitchListTile>(find.byType(SwitchListTile));
    expect(switches.where((s) => s.value == false).length,
        greaterThanOrEqualTo(3));
  });

  testWidgets('toggling calls the notifier', (tester) async {
    // ...same harness...
    await tester.tap(find.text('Colored navigation icons'));
    await tester.pump();
    // Assert against the overridden notifier/repository per the harness's
    // established verification idiom.
  });
}
```

- [ ] **Step 5: Run test to verify it fails** (`flutter test test/features/settings/presentation/pages/appearance_page_accents_test.dart` — FAIL, UI absent), **then add the UI** in `appearance_page.dart` after the nav-customization `Consumer` block's trailing `const Divider(),` (line ~120):

```dart
          // -- Color accents --
          _buildSectionHeader(
            context,
            context.l10n.settings_appearance_colorAccents,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.format_paint_outlined),
            title: Text(context.l10n.settings_appearance_accentNavIcons),
            subtitle: Text(
              context.l10n.settings_appearance_accentNavIcons_subtitle,
            ),
            value: settings.accentNavIcons,
            onChanged: (value) =>
                ref.read(settingsProvider.notifier).setAccentNavIcons(value),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.title_outlined),
            title: Text(
              context.l10n.settings_appearance_accentSectionHeaders,
            ),
            subtitle: Text(
              context.l10n.settings_appearance_accentSectionHeaders_subtitle,
            ),
            value: settings.accentSectionHeaders,
            onChanged: (value) => ref
                .read(settingsProvider.notifier)
                .setAccentSectionHeaders(value),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.list_alt_outlined),
            title: Text(context.l10n.settings_appearance_accentListIcons),
            subtitle: Text(
              context.l10n.settings_appearance_accentListIcons_subtitle,
            ),
            value: settings.accentListIcons,
            onChanged: (value) =>
                ref.read(settingsProvider.notifier).setAccentListIcons(value),
          ),
          const Divider(),
```

- [ ] **Step 6: Run tests, format, commit**

Run: `flutter test test/features/settings/presentation/pages/` — PASS.

```bash
dart format .
git add lib/l10n/ lib/features/settings/presentation/pages/appearance_page.dart test/features/settings/
git commit -m "feat(settings): color accents toggles in appearance settings"
```

---

### Task 7: Shared accent helpers and widgets

**Files:**
- Create: `lib/shared/widgets/feature_accent.dart`
- Test: `test/shared/widgets/feature_accent_test.dart`

**Interfaces:**
- Consumes: `FeatureAccentColors` (Task 1); gate providers (Task 4); `kNavDestinations`.
- Produces:
  - `enum AccentSurface { nav, header, list }`
  - `Color? resolveFeatureAccent(BuildContext context, WidgetRef ref, {required AccentSurface surface, required String featureId})`
  - `class FeatureAccentIcon extends ConsumerWidget` — `FeatureAccentIcon(IconData icon, {required String featureId, required AccentSurface surface, double? size})`
  - `class FeatureAppBarTitle extends ConsumerWidget` — `FeatureAppBarTitle({required String featureId, required String title})`

- [ ] **Step 1: Write the failing test**

```dart
// test/shared/widgets/feature_accent_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/feature_accent_colors.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/feature_accent.dart';

Widget _harness(Widget child, {bool listOn = false, bool headerOn = false}) {
  return ProviderScope(
    overrides: [
      accentListIconsProvider.overrideWithValue(listOn),
      accentSectionHeadersProvider.overrideWithValue(headerOn),
      accentNavIconsProvider.overrideWithValue(false),
    ],
    child: MaterialApp(
      theme: ThemeData(
        extensions: const <ThemeExtension<dynamic>>[
          FeatureAccentColors.light,
        ],
      ),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('FeatureAccentIcon uses accent when toggle on', (tester) async {
    await tester.pumpWidget(_harness(
      const FeatureAccentIcon(Icons.backpack,
          featureId: 'equipment', surface: AccentSurface.list),
      listOn: true,
    ));
    final icon = tester.widget<Icon>(find.byIcon(Icons.backpack));
    expect(icon.color, FeatureAccentColors.light.of('equipment'));
  });

  testWidgets('FeatureAccentIcon falls back when toggle off', (tester) async {
    await tester.pumpWidget(_harness(
      const FeatureAccentIcon(Icons.backpack,
          featureId: 'equipment', surface: AccentSurface.list),
    ));
    expect(tester.widget<Icon>(find.byIcon(Icons.backpack)).color, isNull);
  });

  testWidgets('FeatureAccentIcon falls back for unknown id', (tester) async {
    await tester.pumpWidget(_harness(
      const FeatureAccentIcon(Icons.backpack,
          featureId: 'nonexistent', surface: AccentSurface.list),
      listOn: true,
    ));
    expect(tester.widget<Icon>(find.byIcon(Icons.backpack)).color, isNull);
  });

  testWidgets('FeatureAppBarTitle is text-only when toggle off', (tester) async {
    await tester.pumpWidget(_harness(
      const FeatureAppBarTitle(featureId: 'dives', title: 'Dives'),
    ));
    expect(find.text('Dives'), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('FeatureAppBarTitle shows tinted icon when toggle on',
      (tester) async {
    await tester.pumpWidget(_harness(
      const FeatureAppBarTitle(featureId: 'dives', title: 'Dives'),
      headerOn: true,
    ));
    expect(find.text('Dives'), findsOneWidget);
    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, Icons.scuba_diving);
    expect(icon.color, FeatureAccentColors.light.of('dives'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/widgets/feature_accent_test.dart`
Expected: FAIL — `feature_accent.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/shared/widgets/feature_accent.dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/feature_accent_colors.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';

/// The three user-toggleable surfaces that can show feature accent colors.
enum AccentSurface { nav, header, list }

/// Resolves the accent color for [featureId] on [surface], or null when the
/// surface's toggle is off or the palette has no entry. Callers treat null
/// as "use the ambient/default color", so every failure mode degrades to
/// today's appearance.
Color? resolveFeatureAccent(
  BuildContext context,
  WidgetRef ref, {
  required AccentSurface surface,
  required String featureId,
}) {
  final enabled = switch (surface) {
    AccentSurface.nav => ref.watch(accentNavIconsProvider),
    AccentSurface.header => ref.watch(accentSectionHeadersProvider),
    AccentSurface.list => ref.watch(accentListIconsProvider),
  };
  if (!enabled) return null;
  return Theme.of(context).extension<FeatureAccentColors>()?.of(featureId);
}

/// An [Icon] tinted with its feature's accent color when the surface's
/// toggle is enabled; otherwise identical to a plain [Icon].
class FeatureAccentIcon extends ConsumerWidget {
  const FeatureAccentIcon(
    this.icon, {
    super.key,
    required this.featureId,
    required this.surface,
    this.size,
  });

  final IconData icon;
  final String featureId;
  final AccentSurface surface;
  final double? size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolveFeatureAccent(
      context,
      ref,
      surface: surface,
      featureId: featureId,
    );
    return Icon(icon, color: color, size: size);
  }
}

/// An AppBar title that prefixes the feature's filled nav icon, accent
/// tinted, when the section-headers toggle is on; plain [Text] otherwise.
/// Takes a pre-localized [title] so this shared widget never touches l10n.
class FeatureAppBarTitle extends ConsumerWidget {
  const FeatureAppBarTitle({
    super.key,
    required this.featureId,
    required this.title,
  });

  final String featureId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolveFeatureAccent(
      context,
      ref,
      surface: AccentSurface.header,
      featureId: featureId,
    );
    if (color == null) return Text(title);
    NavDestination? destination;
    for (final d in kNavDestinations) {
      if (d.id == featureId) {
        destination = d;
        break;
      }
    }
    if (destination == null) return Text(title);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(destination.selectedIcon, color: color),
        const SizedBox(width: 8),
        Flexible(child: Text(title)),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/widgets/feature_accent_test.dart`
Expected: PASS (5 tests). If `overrideWithValue` is unavailable on plain `Provider` in the project's Riverpod version, use `accentListIconsProvider.overrideWith((ref) => listOn)` instead — check how other tests in `test/` override plain providers and match that idiom.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/shared/widgets/feature_accent.dart test/shared/widgets/feature_accent_test.dart
git add lib/shared/widgets/feature_accent.dart test/shared/widgets/feature_accent_test.dart
git commit -m "feat(shared): feature accent resolution helper and widgets"
```

---

### Task 8: NavigationRail refactor (behavior-preserving)

**Files:**
- Modify: `lib/shared/widgets/main_scaffold.dart` (`_calculateSelectedIndex` lines 32-48; `_onDestinationSelected` lines 73-117; `destinations:` lines 237-310; add import)
- Test: `test/shared/widgets/nav/rail_destination_order_test.dart`

**Interfaces:**
- Consumes: `kNavDestinations`.
- Produces: private getter `_railDestinations` on `_MainScaffoldState` (14 entries, `more` excluded) used by Task 9.

- [ ] **Step 1: Write the failing-if-broken order-lock test.** This test encodes the exact pre-refactor rail order so the refactor cannot silently change navigation:

```dart
// test/shared/widgets/nav/rail_destination_order_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';

void main() {
  test('kNavDestinations order matches the wide-screen rail contract', () {
    final rail = kNavDestinations.where((d) => d.id != 'more').toList();
    final expected = <(String, String)>[
      ('dashboard', '/dashboard'),
      ('dives', '/dives'),
      ('sites', '/sites'),
      ('trips', '/trips'),
      ('equipment', '/equipment'),
      ('buddies', '/buddies'),
      ('dive-centers', '/dive-centers'),
      ('certifications', '/certifications'),
      ('courses', '/courses'),
      ('statistics', '/statistics'),
      ('planning', '/planning'),
      ('transfer', '/transfer'),
      ('gps-log', '/gps-log'),
      ('settings', '/settings'),
    ];
    expect(rail.length, expected.length);
    for (var i = 0; i < expected.length; i++) {
      expect((rail[i].id, rail[i].route), expected[i],
          reason: 'rail index $i must map to ${expected[i]}');
    }
  });
}
```

- [ ] **Step 2: Run it — it should already PASS** (it locks current behavior): `flutter test test/shared/widgets/nav/rail_destination_order_test.dart`. This is the regression net for the refactor.

- [ ] **Step 3: Refactor `main_scaffold.dart`**

3a. Add import:

```dart
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';
```

3b. Add to `_MainScaffoldState` (above `_calculateSelectedIndex`):

```dart
  /// Rail destinations: every routable destination in canonical order.
  List<NavDestination> get _railDestinations =>
      kNavDestinations.where((d) => d.id != 'more').toList(growable: false);
```

3c. Replace the wide-screen branch of `_calculateSelectedIndex` (the 14 `if (location.startsWith(...))` lines, 34-48) with:

```dart
    if (isWideScreen) {
      final rail = _railDestinations;
      for (var i = 0; i < rail.length; i++) {
        if (location.startsWith(rail[i].route)) return i;
      }
      return 0;
    }
```

3d. Replace the wide-screen `switch` in `_onDestinationSelected` (lines 74-117) with:

```dart
    if (isWideScreen) {
      context.go(_railDestinations[index].route);
    } else {
```

(keeping the existing mobile branch unchanged).

3e. Replace the 14 hardcoded `NavigationRailDestination(...)` entries (lines 237-310) with:

```dart
                            destinations: [
                              for (final destination in _railDestinations)
                                NavigationRailDestination(
                                  icon: Icon(destination.icon),
                                  selectedIcon: Icon(destination.selectedIcon),
                                  label: Text(destination.label(context.l10n)),
                                ),
                            ],
```

- [ ] **Step 4: Verify**

Run: `flutter test test/shared/widgets/nav/rail_destination_order_test.dart` — PASS.
Run: `flutter test test/shared/` — any existing scaffold/nav tests must still pass.
Run: `flutter analyze` — clean (the refactor removes code; watch for now-unused imports).

- [ ] **Step 5: Format and commit**

```bash
dart format lib/shared/widgets/main_scaffold.dart test/shared/widgets/nav/rail_destination_order_test.dart
git add lib/shared/widgets/main_scaffold.dart test/shared/widgets/nav/rail_destination_order_test.dart
git commit -m "refactor(nav): drive NavigationRail from shared kNavDestinations"
```

---

### Task 9: Apply nav accents (rail, bottom bar, More sheet)

**Files:**
- Modify: `lib/shared/widgets/main_scaffold.dart` (rail destinations from Task 8; `_buildMobileNavBar` lines ~349-364; `_showMoreMenu` ListTile leading line ~161)
- Test: `test/shared/widgets/nav/nav_accent_icons_test.dart`

**Interfaces:**
- Consumes: `accentNavIconsProvider`, `FeatureAccentColors`, `_railDestinations` (Task 8).
- Produces: user-visible nav accent behavior; no new API.

- [ ] **Step 1: Write the failing widget test**

```dart
// test/shared/widgets/nav/nav_accent_icons_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/feature_accent_colors.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/main_scaffold.dart';
import 'package:submersion/shared/widgets/nav/nav_primary_provider.dart';

// Minimal router hosting MainScaffold as a shell. If existing tests already
// pump MainScaffold (search test/ for 'MainScaffold'), reuse their harness
// instead of this one.
GoRouter _router() {
  return GoRouter(
    initialLocation: '/dives',
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          for (final path in ['/dashboard', '/dives', '/sites', '/trips'])
            GoRoute(
              path: path,
              builder: (context, state) => const SizedBox.shrink(),
            ),
        ],
      ),
    ],
  );
}

Widget _app({required bool accentsOn}) {
  return ProviderScope(
    overrides: [
      accentNavIconsProvider.overrideWithValue(accentsOn),
      // Keep the mobile bar deterministic: default primary slots.
      // Override navPrimaryDestinationsProvider if the notifier hits
      // persistence in tests (see nav_primary_provider.dart).
    ],
    child: MaterialApp.router(
      // Include the app's localization delegates (copy from an existing
      // widget test that pumps a page using context.l10n).
      theme: ThemeData(
        extensions: const <ThemeExtension<dynamic>>[
          FeatureAccentColors.light,
        ],
      ),
      routerConfig: _router(),
    ),
  );
}

void main() {
  testWidgets('mobile nav icons tinted when toggle on', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(accentsOn: true));
    await tester.pumpAndSettle();

    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.scuba_diving),
      ),
    );
    expect(icon.color, FeatureAccentColors.light.of('dives'));
  });

  testWidgets('mobile nav icons untinted when toggle off', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(accentsOn: false));
    await tester.pumpAndSettle();

    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.scuba_diving),
      ),
    );
    expect(icon.color, isNull);
  });

  testWidgets('rail icons tinted when toggle on (wide layout)', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(accentsOn: true));
    await tester.pumpAndSettle();

    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.byIcon(Icons.location_on_outlined),
      ),
    );
    expect(icon.color, FeatureAccentColors.light.of('sites'));
  });
}
```

Note for the implementer: the wide harness only registers 4 routes but the rail renders all 14 destinations — that is fine, the test never taps unregistered ones. If `MainScaffold` pulls providers that need overriding in tests (`downloadNotifierProvider`, `navPrimaryDestinationsProvider`), copy the overrides from any existing test that pumps it; if none exists, override `navPrimaryDestinationsProvider` with the first 5 entries of `kNavDestinations` filtered per `kDefaultPrimaryIds`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/widgets/nav/nav_accent_icons_test.dart`
Expected: FAIL — icon colors are null with accents on.

- [ ] **Step 3: Implement in `main_scaffold.dart`**

3a. In `build`, before the wide-screen branch, add:

```dart
    final navAccentsOn = ref.watch(accentNavIconsProvider);
    final accents = Theme.of(context).extension<FeatureAccentColors>();
    Color? navAccent(String id) => navAccentsOn ? accents?.of(id) : null;
```

with imports:

```dart
import 'package:submersion/core/theme/feature_accent_colors.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
```

3b. Rail destinations (from Task 8) become:

```dart
                              for (final destination in _railDestinations)
                                NavigationRailDestination(
                                  icon: Icon(
                                    destination.icon,
                                    color: navAccent(destination.id),
                                  ),
                                  selectedIcon: Icon(
                                    destination.selectedIcon,
                                    color: navAccent(destination.id),
                                  ),
                                  label: Text(destination.label(context.l10n)),
                                ),
```

3c. `_buildMobileNavBar` — thread the helper through (change the signature to accept it or recompute inside; recomputing keeps the diff smaller):

```dart
  Widget _buildMobileNavBar(BuildContext context, int selectedIndex) {
    final primary = ref.watch(navPrimaryDestinationsProvider);
    final navAccentsOn = ref.watch(accentNavIconsProvider);
    final accents = Theme.of(context).extension<FeatureAccentColors>();
    Color? navAccent(String id) => navAccentsOn ? accents?.of(id) : null;
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) =>
          _onDestinationSelected(index, isWideScreen: false),
      destinations: [
        for (final destination in primary)
          NavigationDestination(
            icon: Icon(destination.icon, color: navAccent(destination.id)),
            selectedIcon: Icon(
              destination.selectedIcon,
              color: navAccent(destination.id),
            ),
            label: destination.label(context.l10n),
          ),
      ],
    );
  }
```

The `more` sentinel stays untinted automatically: `navAccent('more')` returns null because the palette has no `more` entry.

3d. `_showMoreMenu` overflow ListTile leading (line ~161):

```dart
                    ListTile(
                      leading: Icon(
                        destination.icon,
                        color: navAccent(destination.id),
                      ),
```

(compute `navAccentsOn`/`accents`/`navAccent` at the top of `_showMoreMenu` the same way, reading `ref.read(accentNavIconsProvider)` since the sheet is transient).

- [ ] **Step 4: Run tests**

Run: `flutter test test/shared/widgets/nav/` — PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/shared/widgets/main_scaffold.dart test/shared/widgets/nav/
git add lib/shared/widgets/main_scaffold.dart test/shared/widgets/nav/
git commit -m "feat(nav): optional accent-colored navigation icons"
```

---

### Task 10: Accent icons on feature page headers

**Files (12 call sites — replace the AppBar `title: Text(...)` with `FeatureAppBarTitle`):**
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart` (AppBar title; search `appBar`) — featureId `'dives'`
- Modify: `lib/features/dive_sites/presentation/widgets/site_list_content.dart:404` — `'sites'`
- Modify: `lib/features/trips/presentation/widgets/trip_list_content.dart:167` — `'trips'`
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_content.dart:178` — `'equipment'`
- Modify: `lib/features/buddies/presentation/widgets/buddy_list_content.dart:408` — `'buddies'`
- Modify: `lib/features/dive_centers/presentation/widgets/dive_center_list_content.dart:183` — `'dive-centers'`
- Modify: `lib/features/certifications/presentation/widgets/certification_list_content.dart:148` — `'certifications'`
- Modify: `lib/features/courses/presentation/widgets/course_list_content.dart:99` — `'courses'`
- Modify: `lib/features/statistics/presentation/pages/statistics_page.dart:90` — `'statistics'`
- Modify: `lib/features/planning/presentation/pages/planning_page.dart:23` — `'planning'`
- Modify: `lib/features/transfer/presentation/pages/transfer_page.dart:90` — `'transfer'`
- Modify: `lib/features/gps_log/presentation/pages/gps_logger_page.dart:194` — `'gps-log'`

(Line numbers are as of planning; re-locate with `grep -n "AppBar(" <file>` if drifted. The equipment list page also has its own AppBar at `equipment_list_page.dart:223` — apply there too if it renders a text title.)

**Interfaces:**
- Consumes: `FeatureAppBarTitle` (Task 7).
- Produces: user-visible header behavior; no new API.

- [ ] **Step 1: Apply the mechanical change at each site.** Pattern (worked example, `site_list_content.dart`):

Before:

```dart
      appBar: AppBar(title: Text(context.l10n.siteList_appBar_title), ...
```

After:

```dart
      appBar: AppBar(
        title: FeatureAppBarTitle(
          featureId: 'sites',
          title: context.l10n.siteList_appBar_title,
        ), ...
```

with import added to each file:

```dart
import 'package:submersion/shared/widgets/feature_accent.dart';
```

Keep each file's actual l10n getter — only the wrapping changes. The l10n string stays resolved at the call site (the shared widget takes a plain string; this is deliberate, see the l10n-in-shared-widget test trap).

- [ ] **Step 2: Run the existing widget tests for every touched widget**

Run: `flutter test test/features/dive_log/ test/features/dive_sites/ test/features/trips/ test/features/equipment/ test/features/buddies/ test/features/dive_centers/ test/features/certifications/ test/features/courses/ test/features/statistics/ test/features/planning/ test/features/transfer/ test/features/gps_log/`

Expected: PASS. If a test fails because the harness lacks a provider for `accentSectionHeadersProvider`'s dependency chain (`settingsProvider`), add `accentSectionHeadersProvider.overrideWithValue(false)` to that test's ProviderScope overrides — the widget then renders plain `Text` exactly as before.

- [ ] **Step 3: Spot-check one header behavior in a test.** Add to `test/shared/widgets/feature_accent_test.dart` OR verify via the existing Task 7 `FeatureAppBarTitle` tests (already cover on/off). No new test file needed if Task 7's tests pass — the per-page change is mechanical wrapping.

- [ ] **Step 4: Format and commit**

```bash
dart format .
git add -A lib/features/ test/
git commit -m "feat(ui): optional accent icons on feature page headers"
```

---

### Task 11: Settings root palette unification + Appearance sub-page tinting

**Files:**
- Modify: `lib/features/settings/presentation/widgets/settings_list_content.dart` (remove `color` field lines 16/23 and all 11 `color:` entries lines 28-106; update its own tile rendering to resolve from the palette — find usages of `section.color` in this file)
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (`_MobileSettingsTile` color usage lines ~296-305; debug section injection lines ~180-187)
- Test: `test/features/settings/presentation/pages/settings_page_test.dart` (existing — extend)

**Interfaces:**
- Consumes: `FeatureAccentColors` (Task 1).
- Produces: `SettingsSection` WITHOUT a `color` field; all render sites resolve `Theme.of(context).extension<FeatureAccentColors>()?.of('settings-${section.id}') ?? Theme.of(context).colorScheme.primary`. The root stays always-colored (NOT gated by `accentListIcons`) with identical light-mode colors.

- [ ] **Step 1: Write the failing test** — add to `settings_page_test.dart` using its existing harness:

```dart
  testWidgets('settings rows resolve colors from the accent palette',
      (tester) async {
    // ...pump the settings page via the file's existing harness...
    // The Appearance row's leading icon container must use the palette
    // color, not a hardcoded Colors.pink.
    final appearanceIcon = tester.widget<Icon>(
      find.descendant(
        of: find.ancestor(
          of: find.text('Appearance'),
          matching: find.byType(ListTile),
        ),
        matching: find.byIcon(Icons.palette),
      ),
    );
    expect(appearanceIcon.color,
        FeatureAccentColors.light.of('settings-appearance'));
  });
```

(Adapt the finder to the page's actual tile structure — `_MobileSettingsTile` wraps the icon in a Container; assert on whichever widget carries the color. If the harness's MaterialApp theme lacks the extension, add `FeatureAccentColors.light` to its ThemeData extensions.)

- [ ] **Step 2: Run to verify it fails**, then implement:

2a. In `settings_list_content.dart`: delete `final Color? color;` and `this.color,` from `SettingsSection`, and every `color: Colors.*,` entry in `settingsSections`. Where this file renders `section.color`, replace with a local:

```dart
    final accent =
        Theme.of(context).extension<FeatureAccentColors>()?.of(
              'settings-${section.id}',
            ) ??
            Theme.of(context).colorScheme.primary;
```

and use `accent` where `section.color` was used (background `accent.withValues(alpha: 0.15)`, icon color `accent` — preserve the exact alpha/shape treatment already in place).

2b. In `settings_page.dart`: same replacement inside `_MobileSettingsTile` (lines ~296-305), and remove the `color: Colors.grey` (or equivalent) from the injected debug section (lines ~180-187) — the palette's `settings-debug` entry now supplies it.

2c. Add the import to both files:

```dart
import 'package:submersion/core/theme/feature_accent_colors.dart';
```

- [ ] **Step 3: Tint the Appearance sub-page rows** in `appearance_page.dart`: replace each plain leading icon with `FeatureAccentIcon` (surface `list`, featureId `'settings-appearance'`):

```dart
import 'package:submersion/shared/widgets/feature_accent.dart';
```

```dart
          ListTile(
            leading: const FeatureAccentIcon(
              Icons.palette_outlined,
              featureId: 'settings-appearance',
              surface: AccentSurface.list,
            ),
```

Apply the identical wrapping to the other leading icons on this page: `Icons.language` (line ~66), `Icons.map_outlined` (~76), `Icons.view_quilt_outlined` (~112), and the three `secondary:` icons of the Task 6 SwitchListTiles. Other settings sub-pages are deliberately out of scope for v1 (they adopt `FeatureAccentIcon` opportunistically later).

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/settings/`
Expected: PASS, including any pre-existing settings_page tests (they must not reference the removed `color` field — fix them to assert palette-resolved colors if they did).

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/settings/ test/features/settings/
git add lib/features/settings/ test/features/settings/
git commit -m "feat(settings): resolve section colors from accent palette; tint appearance rows"
```

---

### Task 12: Feature list-tile leading avatar accents

**Files:**
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_content.dart:592` (CircleAvatar) — `'equipment'`
- Modify: `lib/features/equipment/presentation/widgets/equipment_set_list_content.dart:171` (CircleAvatar) — `'equipment'`
- Modify: `lib/features/trips/presentation/widgets/trip_list_content.dart:616` and `:796` (CircleAvatar) — `'trips'`
- Modify: `lib/features/dive_centers/presentation/widgets/dive_center_list_content.dart:721` (Container+Icon) — `'dive-centers'`
- Test: `test/features/equipment/` (extend the nearest list-content widget test)

Dives, sites, buddies, and certifications tiles have no leading feature icon and are intentionally untouched (the toggle never adds icons to list rows).

**Interfaces:**
- Consumes: `resolveFeatureAccent` + `AccentSurface.list` (Task 7).
- Produces: user-visible list accent behavior; no new API.

- [ ] **Step 1: Write the failing test** — extend an equipment list-content widget test (use its existing harness; add `accentListIconsProvider.overrideWithValue(true)` and the theme extension):

```dart
  testWidgets('equipment tile avatar tinted when list accents on',
      (tester) async {
    // ...existing harness + accentListIconsProvider override true...
    final avatar = tester.widget<CircleAvatar>(
      find.byType(CircleAvatar).first,
    );
    final accent = FeatureAccentColors.light.of('equipment');
    expect(avatar.backgroundColor, accent!.withValues(alpha: 0.15));
  });
```

- [ ] **Step 2: Run to verify it fails**, then implement the pattern at each site. Worked example (equipment; the widget is already a Consumer — use its `ref`):

Before:

```dart
      leading: CircleAvatar(child: Icon(_getIconForType(item.type))),
```

After:

```dart
      leading: Builder(builder: (context) {
        final accent = resolveFeatureAccent(
          context,
          ref,
          surface: AccentSurface.list,
          featureId: 'equipment',
        );
        return CircleAvatar(
          backgroundColor: accent?.withValues(alpha: 0.15),
          child: Icon(_getIconForType(item.type), color: accent),
        );
      }),
```

(If the enclosing build method already has both `context` and `ref` in scope — the usual case — skip the `Builder` and inline the two statements before the `return`/tile construction instead; prefer that when possible. When `accent` is null the CircleAvatar renders exactly as today.)

For the dive-centers `Container` variant, apply `accent` to the container's decoration color (`accent?.withValues(alpha: 0.15) ?? <existing color>`) and the Icon's `color: accent` — preserve the existing fallback exactly.

Add the imports to each touched file:

```dart
import 'package:submersion/core/theme/feature_accent_colors.dart';
import 'package:submersion/shared/widgets/feature_accent.dart';
```

(drop the first import where unused).

- [ ] **Step 3: Run tests**

Run: `flutter test test/features/equipment/ test/features/trips/ test/features/dive_centers/`
Expected: PASS (new test + all existing; add `accentListIconsProvider.overrideWithValue(false)` overrides to any existing tests that now fail on the provider chain).

- [ ] **Step 4: Format and commit**

```bash
dart format .
git add -A lib/features/ test/features/
git commit -m "feat(ui): optional accent tinting on list tile leading icons"
```

---

### Task 13: Full-project quality gates

**Files:** none new.

- [ ] **Step 1: Format the whole project**

Run: `dart format .`
Expected: "0 changed" (fix and re-commit if not).

- [ ] **Step 2: Analyze the whole project**

Run: `flutter analyze`
Expected: "No issues found!" — info-level lints fail CI, so fix every hit. Do NOT pipe through `tail`/`head`.

- [ ] **Step 3: Run the touched test surfaces**

```bash
flutter test test/core/theme/ test/core/database/ test/shared/ \
  test/features/settings/ test/core/services/sync/
```

Expected: all PASS.

- [ ] **Step 4: Run the full suite once**

Run: `flutter test`
Expected: PASS. Known flaky tests (backup suite, media upload pipeline drain) may fail unrelated to this work — rerun an isolated failure once to distinguish flake from regression; only accent-related failures block.

- [ ] **Step 5: Commit any stragglers**

```bash
git status --short
```

If clean, done. If format/analyze fixes touched files:

```bash
git add -A
git commit -m "chore: format and analyze fixes for color accents"
```
