# Card Coloring Enhancement Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the boolean "depth-colored dive cards" toggle with a flexible system that lets users color dive cards by any numeric attribute (depth, duration, temperature, OTU, max ppO2) using customizable color gradients.

**Architecture:** New `CardColorAttribute` enum and `CardColorGradient` class in a shared constants file. AppSettings gains four new fields replacing the boolean toggle. DiveListTile's coloring becomes generic -- it reads a numeric value from any attribute and Color.lerps between the configured gradient's start/end colors. DiveSummary gets two new fields (otu, maxPpO2) populated via the paginated SQL query.

**Tech Stack:** Flutter, Drift ORM (migration v35), Riverpod state management, go_router, l10n (10 ARB files).

**Design doc:** `docs/plans/2026-02-17-card-coloring-design.md`

---

## Task 1: Create CardColorAttribute enum and gradient constants

**Files:**
- Create: `lib/core/constants/card_color.dart`
- Test: `test/core/constants/card_color_test.dart`

**Step 1: Write the failing test**

Create `test/core/constants/card_color_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/card_color.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';

void main() {
  group('CardColorAttribute', () {
    test('has 6 values including none', () {
      expect(CardColorAttribute.values.length, 6);
      expect(CardColorAttribute.values.contains(CardColorAttribute.none), true);
    });
  });

  group('cardColorPresets', () {
    test('contains 5 presets', () {
      expect(cardColorPresets.length, 5);
    });

    test('all presets have non-null start and end colors', () {
      for (final preset in cardColorPresets.values) {
        expect(preset.startColor.alpha, greaterThan(0));
        expect(preset.endColor.alpha, greaterThan(0));
      }
    });

    test('ocean preset matches original depth colors', () {
      final ocean = cardColorPresets['ocean']!;
      expect(ocean.startColor, const Color(0xFF4DD0E1));
      expect(ocean.endColor, const Color(0xFF0D1B2A));
    });
  });

  group('getCardColorValue', () {
    final dive = DiveSummary(
      id: 'test-1',
      dateTime: DateTime(2024, 1, 1),
      maxDepth: 30.0,
      duration: const Duration(minutes: 45),
      waterTemp: 22.5,
      otu: 18.0,
      maxPpO2: 1.35,
      sortTimestamp: 0,
    );

    test('returns null for CardColorAttribute.none', () {
      expect(getCardColorValue(dive, CardColorAttribute.none), isNull);
    });

    test('returns maxDepth for depth', () {
      expect(getCardColorValue(dive, CardColorAttribute.depth), 30.0);
    });

    test('returns duration in minutes for duration', () {
      expect(getCardColorValue(dive, CardColorAttribute.duration), 45.0);
    });

    test('returns waterTemp for temperature', () {
      expect(getCardColorValue(dive, CardColorAttribute.temperature), 22.5);
    });

    test('returns otu for otu', () {
      expect(getCardColorValue(dive, CardColorAttribute.otu), 18.0);
    });

    test('returns maxPpO2 for maxPpO2', () {
      expect(getCardColorValue(dive, CardColorAttribute.maxPpO2), 1.35);
    });

    test('returns null when dive has no data for attribute', () {
      final emptyDive = DiveSummary(
        id: 'test-2',
        dateTime: DateTime(2024, 1, 1),
        sortTimestamp: 0,
      );
      expect(getCardColorValue(emptyDive, CardColorAttribute.depth), isNull);
      expect(
        getCardColorValue(emptyDive, CardColorAttribute.duration),
        isNull,
      );
      expect(
        getCardColorValue(emptyDive, CardColorAttribute.temperature),
        isNull,
      );
      expect(getCardColorValue(emptyDive, CardColorAttribute.otu), isNull);
      expect(getCardColorValue(emptyDive, CardColorAttribute.maxPpO2), isNull);
    });
  });

  group('normalizeAndLerp', () {
    test('returns null when value is null', () {
      expect(
        normalizeAndLerp(
          value: null,
          min: 0,
          max: 100,
          startColor: const Color(0xFF000000),
          endColor: const Color(0xFFFFFFFF),
        ),
        isNull,
      );
    });

    test('returns startColor when min == max (all same value)', () {
      final color = normalizeAndLerp(
        value: 50,
        min: 50,
        max: 50,
        startColor: const Color(0xFF4DD0E1),
        endColor: const Color(0xFF0D1B2A),
      );
      expect(color, const Color(0xFF4DD0E1));
    });

    test('returns startColor for min value', () {
      final color = normalizeAndLerp(
        value: 10,
        min: 10,
        max: 100,
        startColor: const Color(0xFF4DD0E1),
        endColor: const Color(0xFF0D1B2A),
      );
      expect(color, const Color(0xFF4DD0E1));
    });

    test('returns endColor for max value', () {
      final color = normalizeAndLerp(
        value: 100,
        min: 10,
        max: 100,
        startColor: const Color(0xFF4DD0E1),
        endColor: const Color(0xFF0D1B2A),
      );
      expect(color, const Color(0xFF0D1B2A));
    });

    test('returns midpoint color for middle value', () {
      final color = normalizeAndLerp(
        value: 55,
        min: 10,
        max: 100,
        startColor: const Color(0xFF000000),
        endColor: const Color(0xFFFFFFFF),
      );
      // 0.5 normalized => mid-gray
      expect(color, isNotNull);
      expect(color!.red, closeTo(128, 2));
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/core/constants/card_color_test.dart`
Expected: FAIL -- `card_color.dart` does not exist yet, and `DiveSummary` lacks `otu`/`maxPpO2`.

**Step 3: Write minimal implementation**

Create `lib/core/constants/card_color.dart`:

```dart
import 'dart:ui';

import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';

/// Which dive attribute to use for card background coloring.
enum CardColorAttribute {
  none,
  depth,
  duration,
  temperature,
  otu,
  maxPpO2;

  /// Parse from stored string, defaulting to none.
  static CardColorAttribute fromName(String name) {
    return CardColorAttribute.values.firstWhere(
      (e) => e.name == name,
      orElse: () => CardColorAttribute.none,
    );
  }
}

/// A named color gradient with start (low) and end (high) colors.
class CardColorGradient {
  final String name;
  final Color startColor;
  final Color endColor;

  const CardColorGradient({
    required this.name,
    required this.startColor,
    required this.endColor,
  });
}

/// Built-in gradient presets. Keyed by preset name.
const Map<String, CardColorGradient> cardColorPresets = {
  'ocean': CardColorGradient(
    name: 'Ocean',
    startColor: Color(0xFF4DD0E1),
    endColor: Color(0xFF0D1B2A),
  ),
  'thermal': CardColorGradient(
    name: 'Thermal',
    startColor: Color(0xFF2196F3),
    endColor: Color(0xFFF44336),
  ),
  'sunset': CardColorGradient(
    name: 'Sunset',
    startColor: Color(0xFFFFC107),
    endColor: Color(0xFF7B1FA2),
  ),
  'forest': CardColorGradient(
    name: 'Forest',
    startColor: Color(0xFF81C784),
    endColor: Color(0xFF1B5E20),
  ),
  'monochrome': CardColorGradient(
    name: 'Monochrome',
    startColor: Color(0xFFB0BEC5),
    endColor: Color(0xFF263238),
  ),
};

/// Extract the numeric value from a DiveSummary for a given attribute.
double? getCardColorValue(DiveSummary dive, CardColorAttribute attribute) {
  return switch (attribute) {
    CardColorAttribute.none => null,
    CardColorAttribute.depth => dive.maxDepth,
    CardColorAttribute.duration => dive.duration?.inMinutes.toDouble(),
    CardColorAttribute.temperature => dive.waterTemp,
    CardColorAttribute.otu => dive.otu,
    CardColorAttribute.maxPpO2 => dive.maxPpO2,
  };
}

/// Normalize a value within [min, max] and lerp between two colors.
/// Returns null if value is null.
Color? normalizeAndLerp({
  required double? value,
  required double? min,
  required double? max,
  required Color startColor,
  required Color endColor,
}) {
  if (value == null || min == null || max == null) return null;

  final range = max - min;
  if (range <= 0) return startColor;

  final normalized = ((value - min) / range).clamp(0.0, 1.0);
  return Color.lerp(startColor, endColor, normalized);
}

/// Resolve the effective gradient colors from settings values.
/// If gradientStart/gradientEnd are non-null, they represent custom colors.
/// Otherwise, look up the preset by name.
({Color start, Color end}) resolveGradientColors({
  required String presetName,
  required int? customStart,
  required int? customEnd,
}) {
  if (customStart != null && customEnd != null) {
    return (start: Color(customStart), end: Color(customEnd));
  }
  final preset = cardColorPresets[presetName] ?? cardColorPresets['ocean']!;
  return (start: preset.startColor, end: preset.endColor);
}
```

**Step 4: Add otu and maxPpO2 to DiveSummary**

Modify `lib/features/dive_log/domain/entities/dive_summary.dart`:
- Add fields: `final double? otu;` and `final double? maxPpO2;`
- Add to constructor parameters
- Add to `copyWith` method
- Add to `props` list
- Add to `DiveSummary.fromDive` factory (otu from `dive.otu` if it exists, maxPpO2 as null since it requires profile aggregation)

Note: `Dive` entity does not currently have `otu`. The field exists in the database (`dives.otu`) but was never mapped to the domain entity. For DiveSummary, we read it directly from the SQL query result, so we don't need to add it to `Dive` entity.

**Step 5: Run test to verify it passes**

Run: `flutter test test/core/constants/card_color_test.dart`
Expected: PASS

**Step 6: Commit**

```bash
git add lib/core/constants/card_color.dart test/core/constants/card_color_test.dart lib/features/dive_log/domain/entities/dive_summary.dart
git commit -m "feat: add CardColorAttribute enum, gradient presets, and DiveSummary fields"
```

---

## Task 2: Update AppSettings with new card color fields

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart`
  - `AppSettings` class (fields, constructor, copyWith)
  - `SettingsNotifier` (new setters)
  - New convenience providers
- Test: `test/core/constants/card_color_test.dart` (add backward compat test)

**Step 1: Write the failing test**

Add to `test/core/constants/card_color_test.dart`:

```dart
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

// ... inside main()

group('AppSettings backward compatibility', () {
  test('showDepthColoredDiveCards returns true when attribute is not none', () {
    const settings = AppSettings(cardColorAttribute: CardColorAttribute.depth);
    expect(settings.showDepthColoredDiveCards, true);
  });

  test('showDepthColoredDiveCards returns false when attribute is none', () {
    const settings = AppSettings(cardColorAttribute: CardColorAttribute.none);
    expect(settings.showDepthColoredDiveCards, false);
  });

  test('default AppSettings has cardColorAttribute none', () {
    const settings = AppSettings();
    expect(settings.cardColorAttribute, CardColorAttribute.none);
    expect(settings.cardColorGradientPreset, 'ocean');
    expect(settings.cardColorGradientStart, isNull);
    expect(settings.cardColorGradientEnd, isNull);
  });
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/core/constants/card_color_test.dart`
Expected: FAIL -- `cardColorAttribute` field does not exist on AppSettings.

**Step 3: Modify AppSettings**

In `lib/features/settings/presentation/providers/settings_providers.dart`:

1. Add import: `import 'package:submersion/core/constants/card_color.dart';`

2. Replace the `showDepthColoredDiveCards` field (line ~108) with:
```dart
  /// Which attribute to use for card background coloring
  final CardColorAttribute cardColorAttribute;

  /// Name of the selected gradient preset ('ocean', 'thermal', etc.)
  final String cardColorGradientPreset;

  /// Custom gradient start color (ARGB int), null when using preset
  final int? cardColorGradientStart;

  /// Custom gradient end color (ARGB int), null when using preset
  final int? cardColorGradientEnd;

  /// Backward-compatible getter: true when any card coloring is active
  bool get showDepthColoredDiveCards =>
      cardColorAttribute != CardColorAttribute.none;
```

3. Update constructor defaults (replace `this.showDepthColoredDiveCards = false` around line ~203):
```dart
    this.cardColorAttribute = CardColorAttribute.none,
    this.cardColorGradientPreset = 'ocean',
    this.cardColorGradientStart,
    this.cardColorGradientEnd,
```

4. Update `copyWith` -- replace the `showDepthColoredDiveCards` parameter (~line 291) with:
```dart
    CardColorAttribute? cardColorAttribute,
    String? cardColorGradientPreset,
    int? cardColorGradientStart,
    int? cardColorGradientEnd,
    bool clearCardColorGradientStart = false,
    bool clearCardColorGradientEnd = false,
```
And in the return body replace the `showDepthColoredDiveCards` line (~342):
```dart
      cardColorAttribute: cardColorAttribute ?? this.cardColorAttribute,
      cardColorGradientPreset:
          cardColorGradientPreset ?? this.cardColorGradientPreset,
      cardColorGradientStart: clearCardColorGradientStart
          ? null
          : (cardColorGradientStart ?? this.cardColorGradientStart),
      cardColorGradientEnd: clearCardColorGradientEnd
          ? null
          : (cardColorGradientEnd ?? this.cardColorGradientEnd),
```

5. Replace `setShowDepthColoredDiveCards` setter (~line 643) in SettingsNotifier with:
```dart
  Future<void> setCardColorAttribute(CardColorAttribute attribute) async {
    state = state.copyWith(cardColorAttribute: attribute);
    await _saveSettings();
  }

  Future<void> setCardColorGradientPreset(String preset) async {
    state = state.copyWith(
      cardColorGradientPreset: preset,
      clearCardColorGradientStart: true,
      clearCardColorGradientEnd: true,
    );
    await _saveSettings();
  }

  Future<void> setCardColorGradientCustom(int start, int end) async {
    state = state.copyWith(
      cardColorGradientPreset: 'custom',
      cardColorGradientStart: start,
      cardColorGradientEnd: end,
    );
    await _saveSettings();
  }
```

6. Replace `showDepthColoredDiveCardsProvider` (~line 899) with:
```dart
final showDepthColoredDiveCardsProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.showDepthColoredDiveCards));
});

final cardColorAttributeProvider = Provider<CardColorAttribute>((ref) {
  return ref.watch(settingsProvider.select((s) => s.cardColorAttribute));
});
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/core/constants/card_color_test.dart`
Expected: PASS

**Step 5: Run full test suite to check for breakage**

Run: `flutter test`
Expected: Some tests may reference `showDepthColoredDiveCards` as a constructor param. Fix any compilation errors by removing the named param from test constructors (the computed getter still works for reading).

**Step 6: Commit**

```bash
git add lib/features/settings/presentation/providers/settings_providers.dart test/core/constants/card_color_test.dart
git commit -m "feat: replace showDepthColoredDiveCards with cardColorAttribute settings"
```

---

## Task 3: Database migration (schema v35)

**Files:**
- Modify: `lib/core/database/database.dart`
  - Add 4 new columns to `DiverSettings` table definition (~line 552-554)
  - Bump `schemaVersion` from 34 to 35 (line 1080)
  - Add migration block `if (from < 35)` after the `from < 34` block

**Step 1: Add columns to DiverSettings table class**

After line 554 (`showDepthColoredDiveCards`), add:

```dart
  // Card coloring settings (v35)
  TextColumn get cardColorAttribute =>
      text().withDefault(const Constant('none'))();
  TextColumn get cardColorGradientPreset =>
      text().withDefault(const Constant('ocean'))();
  IntColumn get cardColorGradientStart => integer().nullable()();
  IntColumn get cardColorGradientEnd => integer().nullable()();
```

**Step 2: Bump schema version**

Change line 1080 from `int get schemaVersion => 34;` to `int get schemaVersion => 35;`

**Step 3: Add migration block**

After the `if (from < 34)` block (after the closing `}` around line 1818+), add:

```dart
        if (from < 35) {
          // Card coloring: attribute selector + gradient settings
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN card_color_attribute TEXT NOT NULL DEFAULT 'none'",
          );
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN card_color_gradient_preset TEXT NOT NULL DEFAULT 'ocean'",
          );
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN card_color_gradient_start INTEGER',
          );
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN card_color_gradient_end INTEGER',
          );
          // Migrate existing depth coloring users
          await customStatement(
            "UPDATE diver_settings SET card_color_attribute = 'depth' WHERE show_depth_colored_dive_cards = 1",
          );
        }
```

**Step 4: Run build_runner to regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Generates updated `database.g.dart` with new columns.

**Step 5: Verify build compiles**

Run: `flutter analyze`
Expected: No errors (warnings OK).

**Step 6: Commit**

```bash
git add lib/core/database/database.dart lib/core/database/database.g.dart
git commit -m "feat: add card color settings columns (schema v35)"
```

---

## Task 4: Update DiverSettingsRepository to map new columns

**Files:**
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart`
  - `createSettingsForDiver` (~lines 47-109)
  - `updateSettingsForDiver` (~lines 142-204)
  - `_mapRowToAppSettings` (~lines 270-322)

**Step 1: Update _mapRowToAppSettings**

At line 298, replace:
```dart
      showDepthColoredDiveCards: row.showDepthColoredDiveCards,
```
With:
```dart
      cardColorAttribute: CardColorAttribute.fromName(row.cardColorAttribute),
      cardColorGradientPreset: row.cardColorGradientPreset,
      cardColorGradientStart: row.cardColorGradientStart,
      cardColorGradientEnd: row.cardColorGradientEnd,
```

Add import at top: `import 'package:submersion/core/constants/card_color.dart';`

**Step 2: Update createSettingsForDiver**

At line 76, replace:
```dart
              showDepthColoredDiveCards: Value(s.showDepthColoredDiveCards),
```
With:
```dart
              cardColorAttribute: Value(s.cardColorAttribute.name),
              cardColorGradientPreset: Value(s.cardColorGradientPreset),
              cardColorGradientStart: Value(s.cardColorGradientStart),
              cardColorGradientEnd: Value(s.cardColorGradientEnd),
```

**Step 3: Update updateSettingsForDiver**

At line 169, replace:
```dart
          showDepthColoredDiveCards: Value(settings.showDepthColoredDiveCards),
```
With:
```dart
          cardColorAttribute: Value(settings.cardColorAttribute.name),
          cardColorGradientPreset: Value(settings.cardColorGradientPreset),
          cardColorGradientStart: Value(settings.cardColorGradientStart),
          cardColorGradientEnd: Value(settings.cardColorGradientEnd),
```

**Step 4: Run tests**

Run: `flutter test`
Expected: PASS (existing settings tests still work).

**Step 5: Commit**

```bash
git add lib/features/settings/data/repositories/diver_settings_repository.dart
git commit -m "feat: map card color settings columns in DiverSettingsRepository"
```

---

## Task 5: Add OTU and maxPpO2 to paginated dive query

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (~lines 994-1053)

**Step 1: Update SQL SELECT**

In `getDiveSummaries`, modify the SQL string (~lines 994-1002). Add after `d.dive_type,`:

```dart
            'd.otu, '
            '(SELECT MAX(pp_o2) FROM dive_profiles dp WHERE dp.dive_id = d.id) AS max_pp_o2, '
```

**Step 2: Update DiveSummary construction**

In the `rows.map` block (~lines 1030-1052), add before `sortTimestamp`:

```dart
            otu: row.readNullable<double>('otu'),
            maxPpO2: row.readNullable<double>('max_pp_o2'),
```

Also add `_db.diveProfiles` to the `readsFrom` set (line 1015) so Drift watches the profiles table:

```dart
            readsFrom: {_db.dives, _db.diveSites, _db.diveProfiles},
```

**Step 3: Run tests**

Run: `flutter test`
Expected: PASS.

**Step 4: Commit**

```bash
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart
git commit -m "feat: add OTU and max ppO2 to paginated dive summary query"
```

---

## Task 6: Generalize DiveListTile coloring

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_list_page.dart`
  - `DiveListTile` class (~lines 330-650)

**Step 1: Update DiveListTile parameters**

Replace the depth-specific fields with generic ones. Change:
```dart
  final double? minDepthInList;
  final double? maxDepthInList;
```
To:
```dart
  /// The dive's value for the active color attribute
  final double? colorValue;
  /// Min value in the current list for normalization
  final double? minValueInList;
  /// Max value in the current list for normalization
  final double? maxValueInList;
  /// Gradient start color (low value)
  final Color? gradientStartColor;
  /// Gradient end color (high value)
  final Color? gradientEndColor;
```

Update the constructor to match.

**Step 2: Replace _getDepthBackgroundColor**

Replace `_getDepthBackgroundColor` (~lines 387-408) with:

```dart
  Color? _getAttributeBackgroundColor() {
    return normalizeAndLerp(
      value: colorValue,
      min: minValueInList,
      max: maxValueInList,
      startColor: gradientStartColor ?? const Color(0xFF4DD0E1),
      endColor: gradientEndColor ?? const Color(0xFF0D1B2A),
    );
  }
```

Add import: `import 'package:submersion/core/constants/card_color.dart';`

**Step 3: Update build method references**

In the `build` method (~line 429-443), replace:
```dart
    final showDepthColors = ref.watch(showDepthColoredDiveCardsProvider);
```
With:
```dart
    final colorAttribute = ref.watch(cardColorAttributeProvider);
    final showCardColors = colorAttribute != CardColorAttribute.none;
```

Replace:
```dart
    final depthColor = (showDepthColors && !shouldShowMap)
        ? _getDepthBackgroundColor(context)
        : null;
```
With:
```dart
    final attributeColor = (showCardColors && !shouldShowMap)
        ? _getAttributeBackgroundColor()
        : null;
```

And update `cardColor` assignment to use `attributeColor`.

**Step 4: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors.

**Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/pages/dive_list_page.dart
git commit -m "refactor: generalize DiveListTile coloring to support any attribute"
```

---

## Task 7: Update DiveListContent and RecentDivesCard range computation

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart` (~lines 1129-1196)
- Modify: `lib/features/dashboard/presentation/widgets/recent_dives_card.dart` (~lines 52-85)

**Step 1: Update DiveListContent._buildDiveList**

Replace the depth-specific range calculation (lines 1136-1145):
```dart
    // Calculate depth range for relative depth coloring
    final depthsWithValues = dives
        .where((d) => d.maxDepth != null)
        .map((d) => d.maxDepth!);
    final minDepth = depthsWithValues.isNotEmpty
        ? depthsWithValues.reduce((a, b) => a < b ? a : b)
        : null;
    final maxDepth = depthsWithValues.isNotEmpty
        ? depthsWithValues.reduce((a, b) => a > b ? a : b)
        : null;
```

With:
```dart
    // Calculate value range for card coloring based on active attribute
    final settings = ref.read(settingsProvider);
    final colorAttribute = settings.cardColorAttribute;
    final colorValues = dives
        .map((d) => getCardColorValue(d, colorAttribute))
        .whereType<double>();
    final minValue = colorValues.isNotEmpty
        ? colorValues.reduce((a, b) => a < b ? a : b)
        : null;
    final maxValue = colorValues.isNotEmpty
        ? colorValues.reduce((a, b) => a > b ? a : b)
        : null;
    final gradientColors = resolveGradientColors(
      presetName: settings.cardColorGradientPreset,
      customStart: settings.cardColorGradientStart,
      customEnd: settings.cardColorGradientEnd,
    );
```

Add import: `import 'package:submersion/core/constants/card_color.dart';`

**Step 2: Update DiveListTile construction**

Replace the `minDepthInList`/`maxDepthInList` params in the DiveListTile constructor call (lines 1188-1189):

```dart
                  colorValue: getCardColorValue(dive, colorAttribute),
                  minValueInList: minValue,
                  maxValueInList: maxValue,
                  gradientStartColor: gradientColors.start,
                  gradientEndColor: gradientColors.end,
```

**Step 3: Apply same changes to RecentDivesCard**

Apply the identical range calculation pattern to `recent_dives_card.dart` (lines 52-61 and the DiveListTile constructor call).

**Step 4: Run flutter analyze and tests**

Run: `flutter analyze && flutter test`
Expected: PASS.

**Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_list_content.dart lib/features/dashboard/presentation/widgets/recent_dives_card.dart
git commit -m "feat: use generic attribute-based card coloring in list builders"
```

---

## Task 8: Update Appearance page UI

**Files:**
- Modify: `lib/features/settings/presentation/pages/appearance_page.dart` (~lines 47-58)
- Create: `lib/features/settings/presentation/widgets/gradient_preset_picker.dart`
- Create: `lib/features/settings/presentation/widgets/custom_gradient_dialog.dart`

**Step 1: Create GradientPresetPicker widget**

Create `lib/features/settings/presentation/widgets/gradient_preset_picker.dart`:

A horizontal scrollable row of gradient swatch cards. Each card is ~60x40 showing a linear gradient. The selected preset has a checkmark overlay. The last card labeled "Custom" opens the custom gradient dialog.

Props:
- `String selectedPreset`
- `int? customStart` / `int? customEnd`
- `ValueChanged<String> onPresetSelected`
- `void Function(int start, int end) onCustomSelected`

**Step 2: Create CustomGradientDialog widget**

Create `lib/features/settings/presentation/widgets/custom_gradient_dialog.dart`:

A dialog with:
- Two color wells (start + end) using Flutter's built-in color picker or a simple HSV picker
- A live preview gradient bar
- Cancel/Apply buttons
- Returns `(int, int)?` tuple of ARGB values

Note: For the color picker, use a simple approach with sliders for H/S/V rather than adding a pub dependency. Keep it minimal.

**Step 3: Replace SwitchListTile in AppearancePage**

In `appearance_page.dart`, replace lines 47-58 (the depth coloring SwitchListTile) with:

```dart
          // Card coloring attribute selector
          ListTile(
            leading: const Icon(Icons.palette),
            title: Text(context.l10n.settings_appearance_cardColorAttribute),
            subtitle: Text(
              context.l10n.settings_appearance_cardColorAttribute_subtitle,
            ),
            trailing: DropdownButton<CardColorAttribute>(
              value: settings.cardColorAttribute,
              underline: const SizedBox(),
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(settingsProvider.notifier)
                      .setCardColorAttribute(value);
                }
              },
              items: CardColorAttribute.values.map((attr) {
                return DropdownMenuItem(
                  value: attr,
                  child: Text(_getAttributeDisplayName(context, attr)),
                );
              }).toList(),
            ),
          ),
          // Gradient picker (visible when coloring is active)
          if (settings.cardColorAttribute != CardColorAttribute.none)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: GradientPresetPicker(
                selectedPreset: settings.cardColorGradientPreset,
                customStart: settings.cardColorGradientStart,
                customEnd: settings.cardColorGradientEnd,
                onPresetSelected: (preset) {
                  ref
                      .read(settingsProvider.notifier)
                      .setCardColorGradientPreset(preset);
                },
                onCustomSelected: (start, end) {
                  ref
                      .read(settingsProvider.notifier)
                      .setCardColorGradientCustom(start, end);
                },
              ),
            ),
```

Add a helper method to the class:

```dart
  String _getAttributeDisplayName(
    BuildContext context,
    CardColorAttribute attr,
  ) {
    return switch (attr) {
      CardColorAttribute.none =>
        context.l10n.settings_appearance_cardColorAttribute_none,
      CardColorAttribute.depth =>
        context.l10n.settings_appearance_cardColorAttribute_depth,
      CardColorAttribute.duration =>
        context.l10n.settings_appearance_cardColorAttribute_duration,
      CardColorAttribute.temperature =>
        context.l10n.settings_appearance_cardColorAttribute_temperature,
      CardColorAttribute.otu =>
        context.l10n.settings_appearance_cardColorAttribute_otu,
      CardColorAttribute.maxPpO2 =>
        context.l10n.settings_appearance_cardColorAttribute_maxPpO2,
    };
  }
```

**Step 4: Run flutter analyze**

Run: `flutter analyze`
Expected: l10n keys will be missing. That's OK -- we add them in Task 9.

**Step 5: Commit**

```bash
git add lib/features/settings/presentation/pages/appearance_page.dart lib/features/settings/presentation/widgets/gradient_preset_picker.dart lib/features/settings/presentation/widgets/custom_gradient_dialog.dart
git commit -m "feat: add card color attribute dropdown and gradient preset picker UI"
```

---

## Task 9: Add l10n keys to all 10 ARB files

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` (English source)
- Modify: `lib/l10n/arb/app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_it.arb`, `app_pt.arb`, `app_nl.arb`, `app_hu.arb`, `app_ar.arb`, `app_he.arb`

**Step 1: Add keys to app_en.arb**

Add near the existing `settings_appearance_depthColoredCards` keys:

```json
  "settings_appearance_cardColorAttribute": "Color cards by",
  "settings_appearance_cardColorAttribute_subtitle": "Choose which attribute determines card background color",
  "settings_appearance_cardColorAttribute_none": "None",
  "settings_appearance_cardColorAttribute_depth": "Depth",
  "settings_appearance_cardColorAttribute_duration": "Duration",
  "settings_appearance_cardColorAttribute_temperature": "Temperature",
  "settings_appearance_cardColorAttribute_otu": "OTU",
  "settings_appearance_cardColorAttribute_maxPpO2": "Max ppO2",
  "settings_appearance_colorGradient": "Color gradient",
  "settings_appearance_colorGradient_subtitle": "Choose the color range for card backgrounds",
  "settings_appearance_colorGradient_ocean": "Ocean",
  "settings_appearance_colorGradient_thermal": "Thermal",
  "settings_appearance_colorGradient_sunset": "Sunset",
  "settings_appearance_colorGradient_forest": "Forest",
  "settings_appearance_colorGradient_monochrome": "Monochrome",
  "settings_appearance_colorGradient_custom": "Custom",
```

**Step 2: Add translated keys to other 9 ARB files**

Add equivalent translations for each locale. Technical terms (OTU, ppO2) stay the same across all locales. Gradient preset names (Ocean, Thermal, etc.) can be translated.

**Step 3: Regenerate l10n**

Run: `flutter gen-l10n`
Expected: Generates updated `app_localizations.dart` and per-locale files.

**Step 4: Run flutter analyze**

Run: `flutter analyze`
Expected: PASS (all l10n references resolve).

**Step 5: Commit**

```bash
git add lib/l10n/
git commit -m "feat: add l10n keys for card color attribute and gradient settings"
```

---

## Task 10: Update sync data serializer

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart`

**Step 1: Update serialization (export)**

In the settings serialization map (~line 1365), replace:
```dart
    'showDepthColoredDiveCards': r.showDepthColoredDiveCards,
```
With:
```dart
    'showDepthColoredDiveCards': r.showDepthColoredDiveCards, // backward compat
    'cardColorAttribute': r.cardColorAttribute,
    'cardColorGradientPreset': r.cardColorGradientPreset,
    'cardColorGradientStart': r.cardColorGradientStart,
    'cardColorGradientEnd': r.cardColorGradientEnd,
```

Note: `r` here is a Drift row, so these need to reference the DB column names. Check the actual variable names used in the serializer.

**Step 2: Update deserialization defaults (import)**

In the defaults map (~line 1301), replace:
```dart
      'showDepthColoredDiveCards': false,
```
With:
```dart
      'showDepthColoredDiveCards': false, // backward compat for old exports
      'cardColorAttribute': 'none',
      'cardColorGradientPreset': 'ocean',
      'cardColorGradientStart': null,
      'cardColorGradientEnd': null,
```

Add backward-compat logic after the `...data` merge: if the new `cardColorAttribute` key is absent but old `showDepthColoredDiveCards` is true, set `cardColorAttribute` to `'depth'`.

**Step 3: Run tests**

Run: `flutter test`
Expected: PASS.

**Step 4: Commit**

```bash
git add lib/core/services/sync/sync_data_serializer.dart
git commit -m "feat: serialize card color settings in sync data"
```

---

## Task 11: Update settings_page.dart (settings summary)

**Files:**
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (~lines 1094-1104)

**Step 1: Update settings page preview**

The settings main page shows a preview of the depth coloring toggle. Update the references from `showDepthColoredDiveCards` / `setShowDepthColoredDiveCards` to use the new `cardColorAttribute` field. Show the active attribute name instead of a toggle.

**Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: PASS.

**Step 3: Commit**

```bash
git add lib/features/settings/presentation/pages/settings_page.dart
git commit -m "refactor: update settings page to show card color attribute name"
```

---

## Task 12: Final integration test and cleanup

**Files:**
- Test: Run full suite

**Step 1: Run all tests**

Run: `flutter test`
Expected: All tests PASS.

**Step 2: Run formatter**

Run: `dart format lib/ test/`
Expected: No changes needed (code was formatted as written).

**Step 3: Run analyzer**

Run: `flutter analyze`
Expected: No errors.

**Step 4: Verify the app builds**

Run: `flutter build macos --debug`
Expected: Successful build.

**Step 5: Final commit (if any formatting/cleanup changes)**

```bash
git add -A
git commit -m "chore: format and cleanup card coloring feature"
```
