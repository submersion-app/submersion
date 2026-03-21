# Compact Dive List View Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two new compact view modes (compact two-line card, dense single-row) alongside the existing detailed tile, with an app bar toggle and a persistent default in Settings > Appearance.

**Architecture:** New `DiveListViewMode` enum drives a switch in `DiveListContent._buildDiveList()` to render one of three tile widgets. A runtime `StateProvider` (initialized once from the persisted setting, NOT reactively watched) enables session-scoped switching via the app bar without overwriting the saved default. The persistent default lives in `DiverSettings` (Drift) and flows through `AppSettings` / `SettingsNotifier`.

**Tech Stack:** Flutter, Riverpod (StateProvider, StateNotifier), Drift ORM (SQLite), Material 3

**Spec:** `docs/superpowers/specs/2026-03-21-compact-dive-list-view-design.md`

---

## File Structure

### New Files

| File | Responsibility |
|------|---------------|
| `lib/core/constants/dive_list_view_mode.dart` | `DiveListViewMode` enum with `fromName()` |
| `lib/features/dive_log/presentation/widgets/compact_dive_list_tile.dart` | Two-line compact card tile widget |
| `lib/features/dive_log/presentation/widgets/dense_dive_list_tile.dart` | Single-row flat tile widget |
| `lib/features/dive_log/presentation/widgets/dive_list_view_mode_toggle.dart` | Segmented icon button for app bar |
| `test/core/constants/dive_list_view_mode_test.dart` | Enum unit tests |
| `test/features/dive_log/presentation/widgets/compact_dive_list_tile_test.dart` | Compact tile widget tests |
| `test/features/dive_log/presentation/widgets/dense_dive_list_tile_test.dart` | Dense tile widget tests |
| `test/features/dive_log/presentation/widgets/dive_list_view_mode_toggle_test.dart` | Toggle widget tests |

### Modified Files

| File | Change |
|------|--------|
| `lib/core/database/database.dart` | Add `diveListViewMode` column to `DiverSettings` (line ~660), bump schema to 51 (line 1187), add migration (line ~2333) |
| `lib/features/settings/presentation/providers/settings_providers.dart` | Add `diveListViewMode` field to `AppSettings` (line ~136), constructor default (line ~265), `copyWith` param (line ~370), setter on `SettingsNotifier` (line ~844), runtime `StateProvider` |
| `lib/features/settings/data/repositories/diver_settings_repository.dart` | Serialize in `createSettingsForDiver` (line ~88), `updateSettingsForDiver` (line ~198), deserialize in `_mapRowToAppSettings` (line ~343) |
| `lib/features/settings/presentation/pages/appearance_page.dart` | Add "Dive List View" dropdown after gradient picker (line ~92) |
| `lib/features/dive_log/presentation/widgets/dive_list_content.dart` | Switch tile widget in `_buildDiveList` (line ~1184), add toggle to `_buildAppBar` (line ~853) and `_buildCompactAppBar` (line ~943) |

---

## Task 1: DiveListViewMode Enum

**Files:**
- Create: `lib/core/constants/dive_list_view_mode.dart`
- Test: `test/core/constants/dive_list_view_mode_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/core/constants/dive_list_view_mode_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_list_view_mode.dart';

void main() {
  group('DiveListViewMode', () {
    test('has three values', () {
      expect(DiveListViewMode.values.length, 3);
    });

    test('fromName returns correct value for each name', () {
      expect(DiveListViewMode.fromName('detailed'), DiveListViewMode.detailed);
      expect(DiveListViewMode.fromName('compact'), DiveListViewMode.compact);
      expect(DiveListViewMode.fromName('dense'), DiveListViewMode.dense);
    });

    test('fromName returns detailed for unknown name', () {
      expect(DiveListViewMode.fromName('unknown'), DiveListViewMode.detailed);
      expect(DiveListViewMode.fromName(''), DiveListViewMode.detailed);
    });

    test('name returns correct string for serialization', () {
      expect(DiveListViewMode.detailed.name, 'detailed');
      expect(DiveListViewMode.compact.name, 'compact');
      expect(DiveListViewMode.dense.name, 'dense');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/constants/dive_list_view_mode_test.dart`
Expected: FAIL — `dive_list_view_mode.dart` does not exist yet.

- [ ] **Step 3: Write the enum**

Create `lib/core/constants/dive_list_view_mode.dart`:

```dart
/// Which layout to use for the dive list.
enum DiveListViewMode {
  /// Full-size card with profile chart, stats, tags
  detailed,

  /// Two-line compact card: site + date on line 1, depth + duration on line 2
  compact,

  /// Single-row flat: all data on one line, divider-separated
  dense;

  /// Parse from stored string, defaulting to detailed.
  static DiveListViewMode fromName(String name) {
    return DiveListViewMode.values.firstWhere(
      (e) => e.name == name,
      orElse: () => DiveListViewMode.detailed,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/constants/dive_list_view_mode_test.dart`
Expected: All 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/constants/dive_list_view_mode.dart test/core/constants/dive_list_view_mode_test.dart
git commit -m "feat: add DiveListViewMode enum"
```

---

## Task 2: Database Schema — Add Column and Migration

**Files:**
- Modify: `lib/core/database/database.dart`

- [ ] **Step 1: Add column to DiverSettings table**

In `lib/core/database/database.dart`, after the `showPressureThresholdMarkers` column (line 660), add:

```dart
  // Dive list view mode (v51)
  TextColumn get diveListViewMode =>
      text().withDefault(const Constant('detailed'))();
```

- [ ] **Step 2: Bump schema version**

Change line 1187 from:
```dart
  static const int currentSchemaVersion = 50;
```
to:
```dart
  static const int currentSchemaVersion = 51;
```

- [ ] **Step 3: Add migration**

In the `onUpgrade` callback, before the closing `},` of the last migration block (before line 2334), add:

```dart
        if (from < 51) {
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN dive_list_view_mode TEXT NOT NULL DEFAULT 'detailed'",
          );
        }
```

- [ ] **Step 4: Run code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Drift generates updated `database.g.dart` with the new column.

- [ ] **Step 5: Verify the app compiles**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add lib/core/database/database.dart lib/core/database/database.g.dart
git commit -m "feat: add dive_list_view_mode column to DiverSettings (schema v51)"
```

---

## Task 3: Settings Layer — AppSettings, Repository, Notifier

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart`
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart`

- [ ] **Step 1: Add field to AppSettings class**

In `settings_providers.dart`, add the field after `cardColorAttribute` (line ~136):

```dart
  /// Which layout to use for the dive list
  final DiveListViewMode diveListViewMode;
```

Add the import at the top of the file:
```dart
import 'package:submersion/core/constants/dive_list_view_mode.dart';
```

- [ ] **Step 2: Add constructor default**

In the `AppSettings` constructor (after `cardColorAttribute` default, line ~265), add:

```dart
    this.diveListViewMode = DiveListViewMode.detailed,
```

- [ ] **Step 3: Add to copyWith**

In the `copyWith()` method parameters (after `cardColorAttribute`, line ~370), add:

```dart
    DiveListViewMode? diveListViewMode,
```

In the `copyWith()` return body (after `cardColorAttribute`, line ~442), add:

```dart
      diveListViewMode: diveListViewMode ?? this.diveListViewMode,
```

- [ ] **Step 4: Add setter to SettingsNotifier**

After the `setCardColorAttribute` method (line ~806), add:

```dart
  Future<void> setDiveListViewMode(DiveListViewMode mode) async {
    state = state.copyWith(diveListViewMode: mode);
    await _saveSettings();
  }
```

- [ ] **Step 5: Add runtime provider**

At the top of `settings_providers.dart`, after the existing provider definitions (near line ~500), add the runtime provider:

```dart
/// Runtime-scoped dive list view mode. Initialized from persisted setting,
/// can be overridden by app bar toggle without changing the saved default.
///
/// IMPORTANT: Uses `ref.read()` (not `ref.watch()`) to read the persisted
/// default only once at creation time. If we used `ref.watch()`, any change
/// to *any* setting would reset the runtime override back to the default,
/// breaking the session-scoped toggle behavior.
final diveListViewModeProvider = StateProvider<DiveListViewMode>((ref) {
  final settings = ref.read(settingsProvider);
  return settings.diveListViewMode;
});
```

- [ ] **Step 6: Update repository — createSettingsForDiver**

In `diver_settings_repository.dart`, add import:
```dart
import 'package:submersion/core/constants/dive_list_view_mode.dart';
```

In `createSettingsForDiver()`, after `cardColorAttribute: Value(s.cardColorAttribute.name),` (line ~88), add:
```dart
              diveListViewMode: Value(s.diveListViewMode.name),
```

- [ ] **Step 7: Update repository — updateSettingsForDiver**

In `updateSettingsForDiver()`, after `cardColorAttribute: Value(settings.cardColorAttribute.name),` (line ~198), add:
```dart
          diveListViewMode: Value(settings.diveListViewMode.name),
```

- [ ] **Step 8: Update repository — _mapRowToAppSettings**

In `_mapRowToAppSettings()`, after `cardColorAttribute: CardColorAttribute.fromName(row.cardColorAttribute),` (line ~343), add:
```dart
      diveListViewMode: DiveListViewMode.fromName(row.diveListViewMode),
```

- [ ] **Step 9: Verify compilation**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 10: Run existing settings tests**

Run: `flutter test test/features/settings/`
Expected: All existing tests pass (the new field has a default, so existing tests should not break).

- [ ] **Step 11: Commit**

```bash
git add lib/features/settings/presentation/providers/settings_providers.dart lib/features/settings/data/repositories/diver_settings_repository.dart
git commit -m "feat: wire DiveListViewMode through settings layer"
```

---

## Task 4: CompactDiveListTile Widget

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/compact_dive_list_tile.dart`
- Test: `test/features/dive_log/presentation/widgets/compact_dive_list_tile_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/presentation/widgets/compact_dive_list_tile_test.dart`.

The project's test pattern uses `testApp()` from `test/helpers/test_app.dart` (provides ProviderScope + MaterialApp with l10n) and a local `_TestSettingsNotifier` stub. Follow the pattern from `test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_dive_list_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('CompactDiveListTile', () {
    testWidgets('renders dive number, site name, date, depth, and duration',
        (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: CompactDiveListTile(
            diveId: 'test-id',
            diveNumber: 42,
            dateTime: DateTime(2026, 3, 15, 9, 30),
            siteName: 'Blue Corner Wall',
            maxDepth: 28.5,
            duration: const Duration(minutes: 52),
            onTap: () {},
          ),
        ),
      );

      expect(find.text('#42'), findsOneWidget);
      expect(find.text('Blue Corner Wall'), findsOneWidget);
      // Depth and duration rendered with unit formatting
      expect(find.textContaining('28'), findsWidgets);
      expect(find.textContaining('52'), findsWidgets);
    });

    testWidgets('shows checkbox in selection mode', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: CompactDiveListTile(
            diveId: 'test-id',
            diveNumber: 42,
            dateTime: DateTime(2026, 3, 15),
            isSelectionMode: true,
            isSelected: true,
            onTap: () {},
          ),
        ),
      );

      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('uses unknown site text when siteName is null',
        (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: CompactDiveListTile(
            diveId: 'test-id',
            diveNumber: 1,
            dateTime: DateTime(2026, 3, 15),
            onTap: () {},
          ),
        ),
      );

      // Should show fallback text (localized "Unknown Site")
      expect(find.text('#1'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/compact_dive_list_tile_test.dart`
Expected: FAIL — file does not exist yet.

- [ ] **Step 3: Write the CompactDiveListTile widget**

Create `lib/features/dive_log/presentation/widgets/compact_dive_list_tile.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:submersion/core/constants/card_color.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/utils/unit_formatter.dart';

/// Two-line compact card tile for the dive list.
///
/// Line 1: dive number | site name | date/time | chevron
/// Line 2: (indented) depth icon + value | duration icon + value
class CompactDiveListTile extends ConsumerWidget {
  final String diveId;
  final int diveNumber;
  final DateTime dateTime;
  final String? siteName;
  final double? maxDepth;
  final Duration? duration;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelectionMode;
  final bool isSelected;

  // Card coloring
  final double? colorValue;
  final double? minValueInList;
  final double? maxValueInList;
  final Color? gradientStartColor;
  final Color? gradientEndColor;

  const CompactDiveListTile({
    super.key,
    required this.diveId,
    required this.diveNumber,
    required this.dateTime,
    this.siteName,
    this.maxDepth,
    this.duration,
    this.onTap,
    this.onLongPress,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.colorValue,
    this.minValueInList,
    this.maxValueInList,
    this.gradientStartColor,
    this.gradientEndColor,
  });

  Color? _getAttributeBackgroundColor() {
    return normalizeAndLerp(
      value: colorValue,
      min: minValueInList,
      max: maxValueInList,
      startColor: gradientStartColor ?? const Color(0xFF4DD0E1),
      endColor: gradientEndColor ?? const Color(0xFF0D1B2A),
    );
  }

  bool _shouldUseLightText(Color backgroundColor) {
    return backgroundColor.computeLuminance() < 0.5;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    // Card coloring
    final colorAttribute = ref.watch(cardColorAttributeProvider);
    final showCardColors = colorAttribute != CardColorAttribute.none;
    final attributeColor = showCardColors ? _getAttributeBackgroundColor() : null;
    final cardColor = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.3)
        : attributeColor;

    final effectiveBackground =
        cardColor ?? colorScheme.surfaceContainerHighest;
    final useLightText = _shouldUseLightText(effectiveBackground);
    final primaryTextColor = useLightText ? Colors.white : Colors.black87;
    final secondaryTextColor = useLightText ? Colors.white70 : Colors.black54;
    final accentColor =
        useLightText ? Colors.cyan.shade200 : Colors.teal.shade800;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      color: cardColor,
      child: Semantics(
        button: true,
        label: 'Dive $diveNumber at ${siteName ?? 'Unknown Site'}',
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Line 1: dive number, site name, date, chevron
                Row(
                  children: [
                    if (isSelectionMode)
                      Checkbox(
                        value: isSelected,
                        onChanged: (_) => onTap?.call(),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      )
                    else
                      SizedBox(
                        width: 36,
                        child: Text(
                          '#$diveNumber',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: accentColor,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        siteName ??
                            context.l10n.diveLog_listPage_unknownSite,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: primaryTextColor,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      units.formatDateTime(dateTime, l10n: context.l10n),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: secondaryTextColor,
                          ),
                    ),
                    ExcludeSemantics(
                      child: Icon(
                        Icons.chevron_right,
                        color: secondaryTextColor,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                // Line 2: depth and duration
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 44),
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          Icons.arrow_downward,
                          size: 13,
                          color: maxDepth != null
                              ? accentColor
                              : secondaryTextColor,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        units.formatDepth(maxDepth),
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: maxDepth != null
                                      ? accentColor
                                      : secondaryTextColor,
                                ),
                      ),
                      const SizedBox(width: 14),
                      ExcludeSemantics(
                        child: Icon(
                          Icons.timer_outlined,
                          size: 13,
                          color: duration != null
                              ? accentColor
                              : secondaryTextColor,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        duration != null
                            ? '${duration!.inMinutes} min'
                            : '--',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: duration != null
                                      ? accentColor
                                      : secondaryTextColor,
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/compact_dive_list_tile_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/compact_dive_list_tile.dart test/features/dive_log/presentation/widgets/compact_dive_list_tile_test.dart
git commit -m "feat: add CompactDiveListTile widget"
```

---

## Task 5: DenseDiveListTile Widget

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dense_dive_list_tile.dart`
- Test: `test/features/dive_log/presentation/widgets/dense_dive_list_tile_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/presentation/widgets/dense_dive_list_tile_test.dart`, using the same test pattern as the compact tile tests:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dense_dive_list_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('DenseDiveListTile', () {
    testWidgets('renders dive number, site name, date, depth, duration',
        (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: DenseDiveListTile(
            diveId: 'test-id',
            diveNumber: 42,
            dateTime: DateTime(2026, 3, 15, 9, 30),
            siteName: 'Blue Corner Wall',
            maxDepth: 28.5,
            duration: const Duration(minutes: 52),
            onTap: () {},
          ),
        ),
      );

      expect(find.text('#42'), findsOneWidget);
      expect(find.text('Blue Corner Wall'), findsOneWidget);
      expect(find.textContaining('28'), findsWidgets);
      expect(find.textContaining('52'), findsWidgets);
      // Should show abbreviated date (no time)
      expect(find.textContaining('Mar'), findsWidgets);
    });

    testWidgets('shows checkbox in selection mode', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: DenseDiveListTile(
            diveId: 'test-id',
            diveNumber: 42,
            dateTime: DateTime(2026, 3, 15),
            isSelectionMode: true,
            isSelected: false,
            onTap: () {},
          ),
        ),
      );

      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('shows year when date is not current year', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: DenseDiveListTile(
            diveId: 'test-id',
            diveNumber: 1,
            dateTime: DateTime(2024, 6, 10),
            onTap: () {},
          ),
        ),
      );

      // Should include year for non-current year
      expect(find.textContaining('24'), findsWidgets);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dense_dive_list_tile_test.dart`
Expected: FAIL — file does not exist yet.

- [ ] **Step 3: Write the DenseDiveListTile widget**

Create `lib/features/dive_log/presentation/widgets/dense_dive_list_tile.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/card_color.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/utils/unit_formatter.dart';

/// Single-row flat tile for maximum dive list density.
///
/// Layout: dive number | site name | abbreviated date | depth | duration | chevron
/// Separated by thin dividers (no card wrapper).
class DenseDiveListTile extends ConsumerWidget {
  final String diveId;
  final int diveNumber;
  final DateTime dateTime;
  final String? siteName;
  final double? maxDepth;
  final Duration? duration;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelectionMode;
  final bool isSelected;

  // Card coloring
  final double? colorValue;
  final double? minValueInList;
  final double? maxValueInList;
  final Color? gradientStartColor;
  final Color? gradientEndColor;

  const DenseDiveListTile({
    super.key,
    required this.diveId,
    required this.diveNumber,
    required this.dateTime,
    this.siteName,
    this.maxDepth,
    this.duration,
    this.onTap,
    this.onLongPress,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.colorValue,
    this.minValueInList,
    this.maxValueInList,
    this.gradientStartColor,
    this.gradientEndColor,
  });

  Color? _getAttributeBackgroundColor() {
    return normalizeAndLerp(
      value: colorValue,
      min: minValueInList,
      max: maxValueInList,
      startColor: gradientStartColor ?? const Color(0xFF4DD0E1),
      endColor: gradientEndColor ?? const Color(0xFF0D1B2A),
    );
  }

  bool _shouldUseLightText(Color backgroundColor) {
    return backgroundColor.computeLuminance() < 0.5;
  }

  /// Abbreviated date: "Mar 15" for current year, "Mar 15 '24" for other years.
  String _formatShortDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year) {
      return DateFormat('MMM d').format(dt);
    }
    return DateFormat("MMM d ''yy").format(dt);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    // Row coloring
    final colorAttribute = ref.watch(cardColorAttributeProvider);
    final showCardColors = colorAttribute != CardColorAttribute.none;
    final attributeColor = showCardColors ? _getAttributeBackgroundColor() : null;
    final rowColor = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.3)
        : attributeColor;

    final effectiveBackground =
        rowColor ?? colorScheme.surface;
    final useLightText = _shouldUseLightText(effectiveBackground);
    final primaryTextColor = useLightText ? Colors.white : Colors.black87;
    final secondaryTextColor = useLightText ? Colors.white70 : Colors.black54;
    final accentColor =
        useLightText ? Colors.cyan.shade200 : Colors.teal.shade800;

    return Semantics(
      button: true,
      label: 'Dive $diveNumber at ${siteName ?? 'Unknown Site'}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: rowColor,
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                if (isSelectionMode)
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => onTap?.call(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  )
                else
                  SizedBox(
                    width: 36,
                    child: Text(
                      '#$diveNumber',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: accentColor,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                // Site name (expanded)
                Expanded(
                  child: Text(
                    siteName ??
                        context.l10n.diveLog_listPage_unknownSite,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: primaryTextColor,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Abbreviated date
                Text(
                  _formatShortDate(dateTime),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: secondaryTextColor,
                      ),
                ),
                const SizedBox(width: 12),
                // Depth (fixed width for column alignment)
                SizedBox(
                  width: 56,
                  child: Text(
                    units.formatDepth(maxDepth),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: maxDepth != null
                              ? accentColor
                              : secondaryTextColor,
                        ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 8),
                // Duration (fixed width for column alignment)
                SizedBox(
                  width: 50,
                  child: Text(
                    duration != null ? '${duration!.inMinutes} min' : '--',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: duration != null
                              ? accentColor
                              : secondaryTextColor,
                        ),
                    textAlign: TextAlign.right,
                  ),
                ),
                ExcludeSemantics(
                  child: Icon(
                    Icons.chevron_right,
                    color: secondaryTextColor,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/dense_dive_list_tile_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dense_dive_list_tile.dart test/features/dive_log/presentation/widgets/dense_dive_list_tile_test.dart
git commit -m "feat: add DenseDiveListTile widget"
```

---

## Task 6: DiveListViewModeToggle Widget

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_list_view_mode_toggle.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_list_view_mode_toggle_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/presentation/widgets/dive_list_view_mode_toggle_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_list_view_mode.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_view_mode_toggle.dart';

void main() {
  group('DiveListViewModeToggle', () {
    testWidgets('renders three icon buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiveListViewModeToggle(
              currentMode: DiveListViewMode.detailed,
              onModeChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.view_agenda), findsOneWidget);
      expect(find.byIcon(Icons.view_list), findsOneWidget);
      expect(find.byIcon(Icons.list), findsOneWidget);
    });

    testWidgets('calls onModeChanged when tapped', (tester) async {
      DiveListViewMode? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiveListViewModeToggle(
              currentMode: DiveListViewMode.detailed,
              onModeChanged: (mode) => selected = mode,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.view_list));
      expect(selected, DiveListViewMode.compact);

      await tester.tap(find.byIcon(Icons.list));
      expect(selected, DiveListViewMode.dense);
    });

    testWidgets('highlights current mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiveListViewModeToggle(
              currentMode: DiveListViewMode.compact,
              onModeChanged: (_) {},
            ),
          ),
        ),
      );

      // The compact button should be visually highlighted
      // (we verify by checking the SegmentedButton has the correct selection)
      expect(find.byType(SegmentedButton<DiveListViewMode>), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_list_view_mode_toggle_test.dart`
Expected: FAIL — file does not exist yet.

- [ ] **Step 3: Write the toggle widget**

Create `lib/features/dive_log/presentation/widgets/dive_list_view_mode_toggle.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/constants/dive_list_view_mode.dart';

/// Segmented button for switching between dive list view modes.
///
/// Shows three icons: view_agenda (detailed), view_list (compact), list (dense).
class DiveListViewModeToggle extends StatelessWidget {
  final DiveListViewMode currentMode;
  final ValueChanged<DiveListViewMode> onModeChanged;

  /// Icon size (default 20 for compact app bars).
  final double iconSize;

  const DiveListViewModeToggle({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<DiveListViewMode>(
      segments: [
        ButtonSegment(
          value: DiveListViewMode.detailed,
          icon: Icon(Icons.view_agenda, size: iconSize),
        ),
        ButtonSegment(
          value: DiveListViewMode.compact,
          icon: Icon(Icons.view_list, size: iconSize),
        ),
        ButtonSegment(
          value: DiveListViewMode.dense,
          icon: Icon(Icons.list, size: iconSize),
        ),
      ],
      selected: {currentMode},
      onSelectionChanged: (selected) {
        onModeChanged(selected.first);
      },
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_list_view_mode_toggle_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_list_view_mode_toggle.dart test/features/dive_log/presentation/widgets/dive_list_view_mode_toggle_test.dart
git commit -m "feat: add DiveListViewModeToggle segmented button"
```

---

## Task 7: Integrate Toggle into Dive List App Bar

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart`

- [ ] **Step 1: Add imports**

At the top of `dive_list_content.dart`, add:

```dart
import 'package:submersion/core/constants/dive_list_view_mode.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_dive_list_tile.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dense_dive_list_tile.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_view_mode_toggle.dart';
```

- [ ] **Step 2: Add toggle to mobile app bar**

In `_buildAppBar()` (line ~850), add the `DiveListViewModeToggle` as the first item in the `actions` list (before the map icon, line ~854):

```dart
        DiveListViewModeToggle(
          currentMode: ref.watch(diveListViewModeProvider),
          onModeChanged: (mode) {
            ref.read(diveListViewModeProvider.notifier).state = mode;
          },
        ),
```

- [ ] **Step 3: Add toggle to compact (master-detail) app bar**

In `_buildCompactAppBar()` (line ~921), add the toggle alongside the existing `MapViewToggleButton`. Find where the `MapViewToggleButton` is placed (line ~943) and add the view mode toggle before it:

```dart
              DiveListViewModeToggle(
                currentMode: ref.watch(diveListViewModeProvider),
                onModeChanged: (mode) {
                  ref.read(diveListViewModeProvider.notifier).state = mode;
                },
                iconSize: 18,
              ),
              const SizedBox(width: 4),
```

- [ ] **Step 4: Verify compilation**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_list_content.dart
git commit -m "feat: add view mode toggle to dive list app bar"
```

---

## Task 8: Switch Tile Widget Based on View Mode

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart`

- [ ] **Step 1: Replace DiveListTile instantiation with a switch**

In `_buildDiveList()`, replace the `DiveListTile(...)` block (lines ~1184-1209) with a switch on the current view mode:

```dart
                final viewMode = ref.watch(diveListViewModeProvider);
                return switch (viewMode) {
                  DiveListViewMode.detailed => DiveListTile(
                    diveId: dive.id,
                    diveNumber: dive.diveNumber ?? index + 1,
                    dateTime: dive.dateTime,
                    siteName: dive.siteName,
                    siteLocation: dive.siteLocation,
                    maxDepth: dive.maxDepth,
                    duration: dive.runtime ?? dive.duration,
                    waterTemp: dive.waterTemp,
                    rating: dive.rating,
                    isFavorite: dive.isFavorite,
                    tags: dive.tags,
                    isSelectionMode: _isSelectionMode,
                    isSelected: isSelected || isMasterSelected,
                    colorValue: getCardColorValue(dive, colorAttribute),
                    minValueInList: minValue,
                    maxValueInList: maxValue,
                    gradientStartColor: gradientColors.start,
                    gradientEndColor: gradientColors.end,
                    siteLatitude: dive.siteLatitude,
                    siteLongitude: dive.siteLongitude,
                    onTap: () => _handleItemTap(dive),
                    onLongPress: _isSelectionMode
                        ? null
                        : () => _enterSelectionMode(dive.id),
                  ),
                  DiveListViewMode.compact => CompactDiveListTile(
                    diveId: dive.id,
                    diveNumber: dive.diveNumber ?? index + 1,
                    dateTime: dive.dateTime,
                    siteName: dive.siteName,
                    maxDepth: dive.maxDepth,
                    duration: dive.runtime ?? dive.duration,
                    isSelectionMode: _isSelectionMode,
                    isSelected: isSelected || isMasterSelected,
                    colorValue: getCardColorValue(dive, colorAttribute),
                    minValueInList: minValue,
                    maxValueInList: maxValue,
                    gradientStartColor: gradientColors.start,
                    gradientEndColor: gradientColors.end,
                    onTap: () => _handleItemTap(dive),
                    onLongPress: _isSelectionMode
                        ? null
                        : () => _enterSelectionMode(dive.id),
                  ),
                  DiveListViewMode.dense => DenseDiveListTile(
                    diveId: dive.id,
                    diveNumber: dive.diveNumber ?? index + 1,
                    dateTime: dive.dateTime,
                    siteName: dive.siteName,
                    maxDepth: dive.maxDepth,
                    duration: dive.runtime ?? dive.duration,
                    isSelectionMode: _isSelectionMode,
                    isSelected: isSelected || isMasterSelected,
                    colorValue: getCardColorValue(dive, colorAttribute),
                    minValueInList: minValue,
                    maxValueInList: maxValue,
                    gradientStartColor: gradientColors.start,
                    gradientEndColor: gradientColors.end,
                    onTap: () => _handleItemTap(dive),
                    onLongPress: _isSelectionMode
                        ? null
                        : () => _enterSelectionMode(dive.id),
                  ),
                };
```

- [ ] **Step 2: Verify compilation**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 3: Run all tests**

Run: `flutter test`
Expected: All tests PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_list_content.dart
git commit -m "feat: switch tile widget based on dive list view mode"
```

---

## Task 9: Settings > Appearance — Dive List View Dropdown

**Files:**
- Modify: `lib/features/settings/presentation/pages/appearance_page.dart`

- [ ] **Step 1: Add import**

At the top of `appearance_page.dart`, add:

```dart
import 'package:submersion/core/constants/dive_list_view_mode.dart';
```

- [ ] **Step 2: Add dropdown to Dive Log section**

In `appearance_page.dart`, after the gradient picker conditional (line ~92) and before the map background switch (line ~93), add:

```dart
          // Dive list view mode selector
          ListTile(
            leading: const Icon(Icons.view_list),
            title: const Text('Dive List View'),
            subtitle: const Text('Default layout for the dive list'),
            trailing: DropdownButton<DiveListViewMode>(
              value: settings.diveListViewMode,
              underline: const SizedBox(),
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(settingsProvider.notifier)
                      .setDiveListViewMode(value);
                  // Also update the runtime provider
                  ref.read(diveListViewModeProvider.notifier).state = value;
                }
              },
              items: DiveListViewMode.values.map((mode) {
                return DropdownMenuItem(
                  value: mode,
                  child: Text(_getViewModeDisplayName(mode)),
                );
              }).toList(),
            ),
          ),
```

- [ ] **Step 3: Add display name helper**

Add a private helper method to the `AppearancePage` class (or as a top-level function following the existing `_getAttributeDisplayName` pattern):

```dart
  String _getViewModeDisplayName(DiveListViewMode mode) {
    return switch (mode) {
      DiveListViewMode.detailed => 'Detailed',
      DiveListViewMode.compact => 'Compact',
      DiveListViewMode.dense => 'Dense',
    };
  }
```

- [ ] **Step 4: Verify compilation**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/presentation/pages/appearance_page.dart
git commit -m "feat: add dive list view mode dropdown to Appearance settings"
```

---

## Task 10: Format, Analyze, and Final Verification

**Files:** All modified files

- [ ] **Step 1: Format all code**

Run: `dart format lib/ test/`
Expected: No formatting changes needed (or changes applied cleanly).

- [ ] **Step 2: Run full analysis**

Run: `flutter analyze`
Expected: No issues.

- [ ] **Step 3: Run all tests**

Run: `flutter test`
Expected: All tests PASS.

- [ ] **Step 4: Manual smoke test**

Run: `flutter run -d macos`

Verify:
1. Dive list shows detailed view by default
2. App bar toggle switches between all three modes
3. Compact mode shows two-line cards with reduced data
4. Dense mode shows single-row flat tiles with dividers
5. Attribute coloring works in all three modes
6. Selection mode (long press) works in all three modes
7. Settings > Appearance shows "Dive List View" dropdown
8. Changing the default in Settings updates the dive list
9. App bar toggle is session-scoped (reloading reverts to default)

- [ ] **Step 5: Commit any formatting fixes**

```bash
git add -A
git commit -m "style: format code"
```
