# App Theme Presets — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add 9 selectable visual themes (5 palette, 4 full) with a dedicated gallery page, persisted per-diver.

**Architecture:** Theme registry pattern with two theme types: palette themes (seed color only, Material 3 generates palettes) and full visual themes (hand-crafted ThemeData). Settings stored in DiverSettings table, wired through Riverpod providers to MaterialApp.router.

**Tech Stack:** Flutter Material 3, Drift ORM, Riverpod, go_router, Google Fonts (JetBrains Mono, Nunito for full themes)

---

### Task 1: Create AppThemePreset data model

**Files:**

- Create: `lib/core/theme/app_theme_preset.dart`
- Test: `test/core/theme/app_theme_preset_test.dart`

**Step 1: Write the failing test**

```dart
// test/core/theme/app_theme_preset_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/app_theme_preset.dart';

void main() {
  group('AppThemePreset', () {
    test('palette preset has seedColor and no ThemeData', () {
      final preset = AppThemePreset.palette(
        id: 'test',
        nameKey: 'theme_test',
        seedColor: const Color(0xFF0077B6),
      );

      expect(preset.type, ThemeType.palette);
      expect(preset.seedColor, const Color(0xFF0077B6));
      expect(preset.lightTheme, isNull);
      expect(preset.darkTheme, isNull);
    });

    test('full preset has ThemeData and no seedColor', () {
      final light = ThemeData.light();
      final dark = ThemeData.dark();
      final preset = AppThemePreset.full(
        id: 'test_full',
        nameKey: 'theme_test_full',
        lightTheme: light,
        darkTheme: dark,
      );

      expect(preset.type, ThemeType.full);
      expect(preset.seedColor, isNull);
      expect(preset.lightTheme, light);
      expect(preset.darkTheme, dark);
    });

    test('equality based on id', () {
      final a = AppThemePreset.palette(
        id: 'ocean',
        nameKey: 'theme_ocean',
        seedColor: const Color(0xFF0077B6),
      );
      final b = AppThemePreset.palette(
        id: 'ocean',
        nameKey: 'theme_ocean',
        seedColor: const Color(0xFF0077B6),
      );
      expect(a, equals(b));
    });
  });
}
```text
**Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/app_theme_preset_test.dart`
Expected: FAIL — `app_theme_preset.dart` does not exist

**Step 3: Write minimal implementation**

```dart
// lib/core/theme/app_theme_preset.dart
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum ThemeType { palette, full }

class AppThemePreset extends Equatable {
  final String id;
  final String nameKey;
  final ThemeType type;
  final Color? seedColor;
  final ThemeData? lightTheme;
  final ThemeData? darkTheme;

  const AppThemePreset._({
    required this.id,
    required this.nameKey,
    required this.type,
    this.seedColor,
    this.lightTheme,
    this.darkTheme,
  });

  const AppThemePreset.palette({
    required this.id,
    required this.nameKey,
    required Color this.seedColor,
  })  : type = ThemeType.palette,
        lightTheme = null,
        darkTheme = null;

  AppThemePreset.full({
    required this.id,
    required this.nameKey,
    required ThemeData this.lightTheme,
    required ThemeData this.darkTheme,
  })  : type = ThemeType.full,
        seedColor = null;

  @override
  List<Object?> get props => [id];
}
```text
**Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/app_theme_preset_test.dart`
Expected: PASS

**Step 5: Commit**

```

feat: add AppThemePreset data model

```text
---

### Task 2: Extract buildPaletteTheme from AppTheme and create theme registry

**Files:**

- Modify: `lib/core/theme/app_theme.dart`
- Create: `lib/core/theme/app_theme_registry.dart`
- Test: `test/core/theme/app_theme_registry_test.dart`

**Step 1: Write the failing test**

```dart
// test/core/theme/app_theme_registry_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/app_theme.dart';
import 'package:submersion/core/theme/app_theme_preset.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';

void main() {
  group('AppThemeRegistry', () {
    test('contains all 9 presets', () {
      expect(AppThemeRegistry.presets.length, 9);
    });

    test('first preset is submersion', () {
      expect(AppThemeRegistry.presets.first.id, 'submersion');
    });

    test('findById returns correct preset', () {
      final preset = AppThemeRegistry.findById('coral_reef');
      expect(preset.id, 'coral_reef');
      expect(preset.type, ThemeType.palette);
    });

    test('findById returns submersion for unknown id', () {
      final preset = AppThemeRegistry.findById('nonexistent');
      expect(preset.id, 'submersion');
    });

    test('palette presets list contains 5 entries', () {
      final palettes = AppThemeRegistry.presets
          .where((p) => p.type == ThemeType.palette)
          .toList();
      expect(palettes.length, 5);
    });

    test('full presets list contains 4 entries', () {
      final full = AppThemeRegistry.presets
          .where((p) => p.type == ThemeType.full)
          .toList();
      expect(full.length, 4);
    });
  });

  group('resolveTheme', () {
    test('returns light ThemeData for palette preset', () {
      final preset = AppThemeRegistry.findById('submersion');
      final theme = AppThemeRegistry.resolveTheme(preset, Brightness.light);
      expect(theme.brightness, Brightness.light);
      expect(theme.useMaterial3, true);
    });

    test('returns dark ThemeData for palette preset', () {
      final preset = AppThemeRegistry.findById('coral_reef');
      final theme = AppThemeRegistry.resolveTheme(preset, Brightness.dark);
      expect(theme.brightness, Brightness.dark);
      expect(theme.useMaterial3, true);
    });

    test('returns hand-crafted ThemeData for full preset', () {
      final preset = AppThemeRegistry.findById('console');
      final theme = AppThemeRegistry.resolveTheme(preset, Brightness.dark);
      expect(theme, isNotNull);
      expect(theme.brightness, Brightness.dark);
    });
  });

  group('buildPaletteTheme', () {
    test('generates light theme with given seed', () {
      final theme = AppTheme.buildPalette(
        seedColor: const Color(0xFFE07A5F),
        brightness: Brightness.light,
      );
      expect(theme.brightness, Brightness.light);
      expect(theme.useMaterial3, true);
      // Card theme should have 12px radius (shared override)
      final cardShape = theme.cardTheme.shape as RoundedRectangleBorder;
      expect(cardShape.borderRadius, BorderRadius.circular(12));
    });

    test('generates dark theme with given seed', () {
      final theme = AppTheme.buildPalette(
        seedColor: const Color(0xFF2D6A4F),
        brightness: Brightness.dark,
      );
      expect(theme.brightness, Brightness.dark);
    });
  });
}
```text
**Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/app_theme_registry_test.dart`
Expected: FAIL — `AppTheme.buildPalette` and `AppThemeRegistry` don't exist

**Step 3: Modify `app_theme.dart` to extract `buildPalette`**

Replace the existing `AppTheme` class in `lib/core/theme/app_theme.dart` with:

```dart
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  /// Build a palette theme from a seed color for the given brightness.
  /// Applies shared component overrides (card, input, FAB).
  static ThemeData buildPalette({
    required Color seedColor,
    required Brightness brightness,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
      ),
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // Keep static getters for backward compatibility during migration
  static ThemeData get light => buildPalette(
    seedColor: const Color(0xFF0077B6),
    brightness: Brightness.light,
  );

  static ThemeData get dark => buildPalette(
    seedColor: const Color(0xFF0077B6),
    brightness: Brightness.dark,
  );
}
```text
**Step 4: Create full theme files (stubs first, refined later)**

Create each of these files. The full theme details for each theme are described below the registry.

- `lib/core/theme/full_themes/console_theme.dart`
- `lib/core/theme/full_themes/tropical_theme.dart`
- `lib/core/theme/full_themes/minimalist_theme.dart`
- `lib/core/theme/full_themes/deep_theme.dart`

Each file exports two `ThemeData` objects: `<name>Light` and `<name>Dark`. See the "Full Theme Specifications" appendix at the bottom of this plan for exact color values, typography, and component overrides for each theme.

**Step 5: Create the registry**

```dart
// lib/core/theme/app_theme_registry.dart
import 'package:flutter/material.dart';
import 'package:submersion/core/theme/app_theme.dart';
import 'package:submersion/core/theme/app_theme_preset.dart';
import 'package:submersion/core/theme/full_themes/console_theme.dart';
import 'package:submersion/core/theme/full_themes/tropical_theme.dart';
import 'package:submersion/core/theme/full_themes/minimalist_theme.dart';
import 'package:submersion/core/theme/full_themes/deep_theme.dart';

class AppThemeRegistry {
  AppThemeRegistry._();

  static final List<AppThemePreset> presets = [
    // Palette themes
    const AppThemePreset.palette(
      id: 'submersion',
      nameKey: 'theme_submersion',
      seedColor: Color(0xFF0077B6),
    ),
    const AppThemePreset.palette(
      id: 'coral_reef',
      nameKey: 'theme_coral_reef',
      seedColor: Color(0xFFE07A5F),
    ),
    const AppThemePreset.palette(
      id: 'tropical_lagoon',
      nameKey: 'theme_tropical_lagoon',
      seedColor: Color(0xFF00B4A0),
    ),
    const AppThemePreset.palette(
      id: 'kelp_forest',
      nameKey: 'theme_kelp_forest',
      seedColor: Color(0xFF2D6A4F),
    ),
    const AppThemePreset.palette(
      id: 'night_dive',
      nameKey: 'theme_night_dive',
      seedColor: Color(0xFF7B2D8B),
    ),
    // Full visual themes
    AppThemePreset.full(
      id: 'console',
      nameKey: 'theme_console',
      lightTheme: consoleLight,
      darkTheme: consoleDark,
    ),
    AppThemePreset.full(
      id: 'tropical',
      nameKey: 'theme_tropical',
      lightTheme: tropicalLight,
      darkTheme: tropicalDark,
    ),
    AppThemePreset.full(
      id: 'minimalist',
      nameKey: 'theme_minimalist',
      lightTheme: minimalistLight,
      darkTheme: minimalistDark,
    ),
    AppThemePreset.full(
      id: 'deep',
      nameKey: 'theme_deep',
      lightTheme: deepLight,
      darkTheme: deepDark,
    ),
  ];

  /// Find a preset by ID, falling back to Submersion if not found.
  static AppThemePreset findById(String id) {
    return presets.firstWhere(
      (p) => p.id == id,
      orElse: () => presets.first,
    );
  }

  /// Resolve the concrete ThemeData for a preset at a given brightness.
  static ThemeData resolveTheme(AppThemePreset preset, Brightness brightness) {
    if (preset.type == ThemeType.full) {
      return brightness == Brightness.light
          ? preset.lightTheme!
          : preset.darkTheme!;
    }
    return AppTheme.buildPalette(
      seedColor: preset.seedColor!,
      brightness: brightness,
    );
  }
}
```text
**Step 6: Run test to verify it passes**

Run: `flutter test test/core/theme/app_theme_registry_test.dart`
Expected: PASS

**Step 7: Run full test suite to verify no regressions**

Run: `flutter test`
Expected: All existing tests still pass (AppTheme.light/dark still work)

**Step 8: Commit**

```

feat: add theme registry with palette and full theme support

```dart
---

### Task 3: Create full theme definitions

**Files:**

- Create: `lib/core/theme/full_themes/console_theme.dart`
- Create: `lib/core/theme/full_themes/tropical_theme.dart`
- Create: `lib/core/theme/full_themes/minimalist_theme.dart`
- Create: `lib/core/theme/full_themes/deep_theme.dart`

Each file defines `final ThemeData <name>Light` and `final ThemeData <name>Dark`. Use the exact colors, typography, and component overrides from the HTML mockups (docs/plans/2026-02-25-app-theme-presets-design.md).

**Console theme key properties:**

- Font: JetBrains Mono (via `google_fonts` package) for headers; Inter for body
- Card: 4px radius, 1px border `#2a3a4a`, no elevation
- FAB: 4px radius, background `#4ae0c0`
- Seed-like palette: dark slate `#1a2230` surfaces, teal `#4ae0c0` accent
- AppBar: flat, `#1a2230` background

**Tropical theme key properties:**

- Font: Nunito (via `google_fonts`) for all text
- Card: 20px radius, elevation 4 with soft shadows
- FAB: 22px radius, coral `#E07A5F`
- Seed-like palette: teal `#00B4A0` primary, coral accent
- AppBar: teal `#00B4A0`

**Minimalist theme key properties:**

- Font: Inter with lighter weights (300 body, 500 headers)
- Card: 8px radius, 1px border `#e8e8e8`, no elevation
- FAB: 8px radius, dark `#333`
- Near-monochrome: `#475569` primary, minimal color
- AppBar: transparent, no elevation

**Deep theme key properties:**

- Font: Inter with bold headers (700)
- Card: 16px radius, semi-transparent backgrounds, subtle border
- FAB: 16px radius, gradient-like blue `#2070c0` → `#40a0e8`
- Deep navy: `#0A1628` surfaces, blue `#40a0e8` accent
- AppBar: semi-transparent `#0A1628`

**Step 1: Add `google_fonts` dependency** (if not already present)

Run: `flutter pub add google_fonts`

**Step 2: Create all four theme files**

Implement each file with light and dark variants. Each file should be ~100-150 lines.

**Step 3: Run tests**

Run: `flutter test test/core/theme/app_theme_registry_test.dart`
Expected: PASS (registry tests already validate full themes exist)

**Step 4: Commit**

```

feat: add Console, Tropical, Minimalist, and Deep full theme definitions

```text
---

### Task 4: Add database column and migration

**Files:**

- Modify: `lib/core/database/database.dart` (DiverSettings table + migration)

**Step 1: Add column to DiverSettings table**

In `lib/core/database/database.dart`, inside the `DiverSettings` class (after line 538 `themeMode`), add:

```dart
  // Theme preset
  TextColumn get themePreset => text().withDefault(const Constant('submersion'))();
```text
**Step 2: Bump schema version**

Change `schemaVersion` from `42` to `43` (line 1113).

**Step 3: Add migration**

After the `if (from < 42)` block (line 2007), add:

```dart
        if (from < 43) {
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN theme_preset TEXT NOT NULL DEFAULT 'submersion'",
          );
        }
```text
**Step 4: Run code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`

**Step 5: Run tests**

Run: `flutter test`
Expected: All tests pass

**Step 6: Commit**

```

feat: add themePreset column to DiverSettings (schema v43)

```dart
---

### Task 5: Wire themePreset through repository and settings providers

**Files:**

- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart`
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart`

**Step 1: Update `AppSettings` class** (`settings_providers.dart`)

Add `themePresetId` field (store as String, resolve to preset in provider):

- Add field: `final String themePresetId;` (after `themeMode`, around line 64)
- Add to constructor with default: `this.themePresetId = 'submersion',` (after `themeMode` default, around line 216)
- Add to `copyWith`: parameter `String? themePresetId,` and corresponding line in return

**Step 2: Add setter to SettingsNotifier** (after `setThemeMode`, around line 605)

```dart
  Future<void> setThemePresetId(String presetId) async {
    state = state.copyWith(themePresetId: presetId);
    await _saveSettings();
  }
```text
**Step 3: Add convenience provider** (after `themeModeProvider`, around line 948)

```dart
final themePresetProvider = Provider<AppThemePreset>((ref) {
  final presetId = ref.watch(settingsProvider.select((s) => s.themePresetId));
  return AppThemeRegistry.findById(presetId);
});
```text
Add the necessary imports for `AppThemePreset` and `AppThemeRegistry`.

**Step 4: Update repository** (`diver_settings_repository.dart`)

In `_mapRowToAppSettings` (line 291), add:

```dart
      themePresetId: row.themePreset,
```text
In `createSettingsForDiver` (line 46), add to the `DiverSettingsCompanion`:

```dart
              themePreset: Value(s.themePresetId),
```text
In `updateSettingsForDiver` (line 150), add to the `DiverSettingsCompanion`:

```dart
          themePreset: Value(settings.themePresetId),
```text
**Step 5: Run tests**

Run: `flutter test`
Expected: All tests pass

**Step 6: Commit**

```

feat: wire themePreset through settings providers and repository

```text
---

### Task 6: Wire theme into MaterialApp.router

**Files:**

- Modify: `lib/app.dart`

**Step 1: Update app.dart build method**

In `lib/app.dart`, modify the `build` method (line 60):

```dart
  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final themePreset = ref.watch(themePresetProvider);
    final localeSetting = ref.watch(localeProvider);

    // Restore the last used cloud sync provider on app startup
    ref.watch(restoreLastProviderProvider);

    return MaterialApp.router(
      title: 'Submersion',
      debugShowCheckedModeBanner: false,
      theme: AppThemeRegistry.resolveTheme(themePreset, Brightness.light),
      darkTheme: AppThemeRegistry.resolveTheme(themePreset, Brightness.dark),
      themeMode: themeMode,
      locale: _resolveLocale(localeSetting),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) {
        Intl.defaultLocale = Localizations.localeOf(context).toLanguageTag();
        return child!;
      },
    );
  }
```text
Add imports:

```dart
import 'package:submersion/core/theme/app_theme_preset.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
```dart
Remove the now-unused `import 'package:submersion/core/theme/app_theme.dart';` if no longer referenced.

**Step 2: Run the app to verify**

Run: `flutter run -d macos`
Expected: App launches with default Submersion theme, same as before

**Step 3: Run tests**

Run: `flutter test`
Expected: All tests pass

**Step 4: Commit**

```

feat: wire theme preset into MaterialApp.router

```text
---

### Task 7: Update sync serializer

**Files:**

- Modify: `lib/core/services/sync/sync_data_serializer.dart`

**Step 1: Add themePreset to defaults map** (around line 1282, after `'themeMode': 'system',`)

```dart
      'themePreset': 'submersion',
```text
**Step 2: Add themePreset to `_diverSettingToJson`** (around line 1362, after `'themeMode': r.themeMode,`)

```dart
    'themePreset': r.themePreset,
```text
**Step 3: Run tests**

Run: `flutter test`
Expected: All tests pass

**Step 4: Commit**

```

feat: add themePreset to sync serializer

```diff
---

### Task 8: Add localization keys

**Files:**

- Modify: `lib/l10n/arb/app_en.arb`

**Step 1: Add theme name keys and gallery keys**

Add these entries to `app_en.arb` (near the existing `settings_appearance_*` keys):

```json
  "settings_themes_title": "Choose Theme",
  "settings_themes_color_palettes": "Color Palettes",
  "settings_themes_visual_themes": "Visual Themes",
  "settings_themes_current": "Theme",
  "theme_submersion": "Submersion",
  "theme_coral_reef": "Coral Reef",
  "theme_tropical_lagoon": "Tropical Lagoon",
  "theme_kelp_forest": "Kelp Forest",
  "theme_night_dive": "Night Dive",
  "theme_console": "Console",
  "theme_tropical": "Tropical",
  "theme_minimalist": "Minimalist",
  "theme_deep": "Deep",
```text
**Step 2: Run code generation for l10n**

Run: `flutter gen-l10n` (or `flutter pub get` if gen-l10n runs automatically)

**Step 3: Commit**

```

feat: add theme gallery and theme name localization keys

```text
---

### Task 9: Create ThemePreviewCard widget

**Files:**

- Create: `lib/features/settings/presentation/widgets/theme_preview_card.dart`
- Test: `test/features/settings/presentation/widgets/theme_preview_card_test.dart`

**Step 1: Write the failing widget test**

```dart
// test/features/settings/presentation/widgets/theme_preview_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/app_theme_preset.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/features/settings/presentation/widgets/theme_preview_card.dart';

void main() {
  group('ThemePreviewCard', () {
    testWidgets('renders theme name', (tester) async {
      final preset = AppThemeRegistry.findById('submersion');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThemePreviewCard(
              preset: preset,
              isSelected: false,
              themeName: 'Submersion',
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Submersion'), findsOneWidget);
    });

    testWidgets('shows check icon when selected', (tester) async {
      final preset = AppThemeRegistry.findById('submersion');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThemePreviewCard(
              preset: preset,
              isSelected: true,
              themeName: 'Submersion',
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      final preset = AppThemeRegistry.findById('submersion');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThemePreviewCard(
              preset: preset,
              isSelected: false,
              themeName: 'Submersion',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ThemePreviewCard));
      expect(tapped, true);
    });
  });
}
```text
**Step 2: Run test to verify it fails**

Run: `flutter test test/features/settings/presentation/widgets/theme_preview_card_test.dart`
Expected: FAIL — file doesn't exist

**Step 3: Implement ThemePreviewCard**

```dart
// lib/features/settings/presentation/widgets/theme_preview_card.dart
import 'package:flutter/material.dart';
import 'package:submersion/core/theme/app_theme_preset.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';

class ThemePreviewCard extends StatelessWidget {
  final AppThemePreset preset;
  final bool isSelected;
  final String themeName;
  final VoidCallback onTap;

  const ThemePreviewCard({
    super.key,
    required this.preset,
    required this.isSelected,
    required this.themeName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final previewTheme = AppThemeRegistry.resolveTheme(
      preset,
      Theme.of(context).brightness,
    );
    final colorScheme = previewTheme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
                width: isSelected ? 3 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 160,
                child: _buildPreview(colorScheme, previewTheme),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              if (isSelected) const SizedBox(width: 4),
              Text(
                themeName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(ColorScheme colorScheme, ThemeData themeData) {
    final cardShape = themeData.cardTheme.shape as RoundedRectangleBorder?;
    final cardRadius = cardShape?.borderRadius as BorderRadius? ??
        BorderRadius.circular(12);

    return Column(
      children: [
        // Mini app bar
        Container(
          height: 28,
          color: colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.centerLeft,
          child: Container(
            width: 48,
            height: 8,
            decoration: BoxDecoration(
              color: colorScheme.onPrimary.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        // Content area with mini cards
        Expanded(
          child: Container(
            color: colorScheme.surface,
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                _buildMiniCard(colorScheme, cardRadius),
                const SizedBox(height: 6),
                _buildMiniCard(colorScheme, cardRadius),
                const SizedBox(height: 6),
                _buildMiniCard(colorScheme, cardRadius),
              ],
            ),
          ),
        ),
        // Mini bottom nav
        Container(
          height: 24,
          color: colorScheme.surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (i) {
              return Container(
                width: 20,
                height: 6,
                decoration: BoxDecoration(
                  color: i == 0
                      ? colorScheme.primary
                      : colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniCard(ColorScheme colorScheme, BorderRadius radius) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: radius,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 6,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```text
**Step 4: Run test to verify it passes**

Run: `flutter test test/features/settings/presentation/widgets/theme_preview_card_test.dart`
Expected: PASS

**Step 5: Commit**

```

feat: add ThemePreviewCard widget with mini-mockup preview

```text
---

### Task 10: Create ThemeGalleryPage

**Files:**

- Create: `lib/features/settings/presentation/pages/theme_gallery_page.dart`
- Test: `test/features/settings/presentation/pages/theme_gallery_page_test.dart`

**Step 1: Write the failing widget test**

```dart
// test/features/settings/presentation/pages/theme_gallery_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/features/settings/presentation/pages/theme_gallery_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  group('ThemeGalleryPage', () {
    testWidgets('renders all theme presets', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ThemeGalleryPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should have 9 preview cards total
      expect(
        find.byType(/* ThemePreviewCard */ GestureDetector),
        findsAtLeast(9),
      );
    });
  });
}
```dart
Note: Exact test assertions may need to be adjusted based on how the l10n resolves in test context. Use a `ProviderScope` with overrides if needed for `settingsProvider`.

**Step 2: Implement ThemeGalleryPage**

```dart
// lib/features/settings/presentation/pages/theme_gallery_page.dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/app_theme_preset.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/theme_preview_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class ThemeGalleryPage extends ConsumerWidget {
  const ThemeGalleryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPresetId = ref.watch(
      settingsProvider.select((s) => s.themePresetId),
    );
    final l10n = AppLocalizations.of(context)!;

    final palettePresets = AppThemeRegistry.presets
        .where((p) => p.type == ThemeType.palette)
        .toList();
    final fullPresets = AppThemeRegistry.presets
        .where((p) => p.type == ThemeType.full)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings_themes_title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Color Palettes section
          Text(
            l10n.settings_themes_color_palettes,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          _buildGrid(context, ref, palettePresets, currentPresetId),
          const SizedBox(height: 32),
          // Visual Themes section
          Text(
            l10n.settings_themes_visual_themes,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          _buildGrid(context, ref, fullPresets, currentPresetId),
        ],
      ),
    );
  }

  Widget _buildGrid(
    BuildContext context,
    WidgetRef ref,
    List<AppThemePreset> presets,
    String currentPresetId,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: presets.length,
      itemBuilder: (context, index) {
        final preset = presets[index];
        return ThemePreviewCard(
          preset: preset,
          isSelected: preset.id == currentPresetId,
          themeName: _resolveThemeName(context, preset.nameKey),
          onTap: () {
            ref.read(settingsProvider.notifier).setThemePresetId(preset.id);
          },
        );
      },
    );
  }

  String _resolveThemeName(BuildContext context, String nameKey) {
    // Map nameKey to l10n string. The l10n getter names match the key pattern.
    // For now, use a simple lookup. If l10n code-gen creates getters for these
    // keys, call them directly. Otherwise, use a map.
    final l10n = AppLocalizations.of(context)!;
    switch (nameKey) {
      case 'theme_submersion': return l10n.theme_submersion;
      case 'theme_coral_reef': return l10n.theme_coral_reef;
      case 'theme_tropical_lagoon': return l10n.theme_tropical_lagoon;
      case 'theme_kelp_forest': return l10n.theme_kelp_forest;
      case 'theme_night_dive': return l10n.theme_night_dive;
      case 'theme_console': return l10n.theme_console;
      case 'theme_tropical': return l10n.theme_tropical;
      case 'theme_minimalist': return l10n.theme_minimalist;
      case 'theme_deep': return l10n.theme_deep;
      default: return nameKey;
    }
  }
}
```text
**Step 3: Run test**

Run: `flutter test test/features/settings/presentation/pages/theme_gallery_page_test.dart`
Expected: PASS (or adjust test assertions as needed)

**Step 4: Commit**

```

feat: add ThemeGalleryPage with grid layout and instant switching

```text
---

### Task 11: Add route and settings page entry point

**Files:**

- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/settings/presentation/pages/settings_page.dart`

**Step 1: Add route to app_router.dart**

In `lib/core/router/app_router.dart`, inside the `/settings` routes (after the `appearance` route, around line 718), add:

```dart
              GoRoute(
                path: 'themes',
                name: 'themes',
                builder: (context, state) => const ThemeGalleryPage(),
              ),
```text
Add the import:

```dart
import 'package:submersion/features/settings/presentation/pages/theme_gallery_page.dart';
```text
**Step 2: Add theme entry point to settings page**

In `lib/features/settings/presentation/pages/settings_page.dart`, in the Appearance section (around line 914 where the theme header is), replace or augment the theme mode radio buttons with a "Theme" row that navigates to the gallery:

Before the `ThemeMode.values.map` radio section, add a ListTile:

```dart
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: Text(context.l10n.settings_themes_current),
              subtitle: Text(_resolveCurrentThemeName(context, ref)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/themes'),
            ),
```text
Add a helper to resolve the current theme name:

```dart
  String _resolveCurrentThemeName(BuildContext context, WidgetRef ref) {
    final presetId = ref.watch(settingsProvider.select((s) => s.themePresetId));
    final preset = AppThemeRegistry.findById(presetId);
    // Same name resolution as ThemeGalleryPage
    final l10n = AppLocalizations.of(context)!;
    switch (preset.nameKey) {
      case 'theme_submersion': return l10n.theme_submersion;
      case 'theme_coral_reef': return l10n.theme_coral_reef;
      case 'theme_tropical_lagoon': return l10n.theme_tropical_lagoon;
      case 'theme_kelp_forest': return l10n.theme_kelp_forest;
      case 'theme_night_dive': return l10n.theme_night_dive;
      case 'theme_console': return l10n.theme_console;
      case 'theme_tropical': return l10n.theme_tropical;
      case 'theme_minimalist': return l10n.theme_minimalist;
      case 'theme_deep': return l10n.theme_deep;
      default: return preset.nameKey;
    }
  }
```text
**Step 3: Run the app to verify navigation works**

Run: `flutter run -d macos`
Expected: Settings > Theme row shows "Submersion", tapping opens gallery, selecting a theme applies instantly

**Step 4: Run full test suite**

Run: `flutter test`
Expected: All tests pass

**Step 5: Format code**

Run: `dart format lib/ test/`

**Step 6: Analyze code**

Run: `flutter analyze`
Expected: No issues

**Step 7: Commit**

```

feat: add /settings/themes route and theme entry point in settings page

```diff
---

### Task 12: Visual QA and polish

**Files:**

- Possibly modify theme files for color/spacing adjustments

**Step 1: Test each theme in light and dark mode**

Launch the app: `flutter run -d macos`

For each of the 9 themes, switch to it and verify:

- [ ] Light mode renders correctly
- [ ] Dark mode renders correctly
- [ ] Cards, FAB, app bar, bottom nav all use theme colors
- [ ] Dive-specific colors (depth chart, temperature, gas mix) remain unchanged
- [ ] Gallery preview cards are representative of the actual theme
- [ ] Active theme checkmark appears on correct card
- [ ] Switching themes is instant (no delay or flash)

**Step 2: Test persistence**

- Switch to Coral Reef theme
- Kill and relaunch the app
- Verify Coral Reef is still active

**Step 3: Test diver switching**

- Switch to a different diver
- Verify their independent theme setting loads

**Step 4: Adjust any visual issues found**

**Step 5: Final format + analyze**

Run: `dart format lib/ test/ && flutter analyze`

**Step 6: Commit**

```text

fix: theme visual polish and QA adjustments

```

---

## Appendix: Full Theme Color Specifications

### Console Theme

| Property | Light | Dark |
|----------|-------|------|
| Surface | `#F0F2F5` | `#141a22` |
| App bar bg | `#2a3444` | `#1a2230` |
| Primary | `#1a2230` | `#4ae0c0` |
| On primary | `#ffffff` | `#0a1018` |
| Card bg | `#ffffff` | `#1a2230` |
| Card radius | 4px | 4px |
| Card border | `#d0d8e0` | `#2a3a4a` |
| Card elevation | 0 | 0 |
| FAB bg | `#1a2230` | `#4ae0c0` |
| FAB radius | 4px | 4px |
| Text theme | JetBrains Mono headers, Inter body | Same |

### Tropical Theme

| Property | Light | Dark |
|----------|-------|------|
| Surface | `#f0faf8` | `#101a18` |
| App bar bg | `#00B4A0` | `#152824` |
| Primary | `#00B4A0` | `#40d0be` |
| Secondary | `#E07A5F` | `#e8957e` |
| Card bg | `#ffffff` | `#1a2a26` |
| Card radius | 20px | 20px |
| Card elevation | 4 | 2 |
| FAB bg | `#E07A5F` | `#E07A5F` |
| FAB radius | 22px | 22px |
| Text theme | Nunito all text | Same |

### Minimalist Theme

| Property | Light | Dark |
|----------|-------|------|
| Surface | `#fafafa` | `#121212` |
| App bar bg | transparent | transparent |
| Primary | `#475569` | `#94a3b8` |
| Card bg | `#ffffff` | `#1e1e1e` |
| Card radius | 8px | 8px |
| Card border | `#e8e8e8` | `#333333` |
| Card elevation | 0 | 0 |
| FAB bg | `#333333` | `#e0e0e0` |
| FAB radius | 8px | 8px |
| Text theme | Inter, 300 body / 500 headers | Same |

### Deep Theme

| Property | Light | Dark |
|----------|-------|------|
| Surface | `#e8f0f8` | `#080e18` |
| App bar bg | `#0a1628` | `#0a1428` |
| Primary | `#2070c0` | `#40a0e8` |
| Card bg | `#f0f4f8` | `rgba(15,30,55,0.7)` |
| Card radius | 16px | 16px |
| Card border | `rgba(60,120,180,0.15)` | `rgba(60,120,180,0.15)` |
| Card elevation | 1 | 0 |
| FAB bg | `#2070c0` | `#2070c0` |
| FAB radius | 16px | 16px |
| Text theme | Inter, 700 headers | Same |
