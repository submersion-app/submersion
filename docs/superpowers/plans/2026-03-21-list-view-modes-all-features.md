# List View Density Modes — All Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add compact and/or dense view modes to sites, trips, equipment, buddies, and dive centers lists, reusing and generalizing the dive list's existing view mode infrastructure.

**Architecture:** Rename `DiveListViewMode` to `ListViewMode` and move the toggle widget to `shared/widgets/` since it is now used by all features. Add 5 per-feature database columns, AppSettings fields, runtime providers, and settings UI sections. Create 8 new tile widgets (3 compact + 5 dense) following the patterns established by `CompactDiveListTile` and `DenseDiveListTile`.

**Tech Stack:** Flutter, Riverpod (StateProvider, StateNotifier), Drift ORM (SQLite), Material 3

**Spec:** `docs/superpowers/specs/2026-03-21-list-view-modes-all-features-design.md`

---

## File Structure

### New Files

| File | Responsibility |
|------|---------------|
| `lib/core/constants/list_view_mode.dart` | Renamed `ListViewMode` enum (replaces `dive_list_view_mode.dart`) |
| `lib/shared/widgets/list_view_mode_toggle.dart` | Renamed `ListViewModeToggle` with `availableModes` param (replaces dive_log version) |
| `lib/features/dive_sites/presentation/widgets/compact_site_list_tile.dart` | Two-line compact card for sites |
| `lib/features/dive_sites/presentation/widgets/dense_site_list_tile.dart` | Single-row flat tile for sites |
| `lib/features/trips/presentation/widgets/compact_trip_list_tile.dart` | Two-line compact card for trips |
| `lib/features/trips/presentation/widgets/dense_trip_list_tile.dart` | Single-row flat tile for trips |
| `lib/features/dive_centers/presentation/widgets/compact_dive_center_list_tile.dart` | Two-line compact card for dive centers |
| `lib/features/dive_centers/presentation/widgets/dense_dive_center_list_tile.dart` | Single-row flat tile for dive centers |
| `lib/features/equipment/presentation/widgets/dense_equipment_list_tile.dart` | Single-row flat tile for equipment |
| `lib/features/buddies/presentation/widgets/dense_buddy_list_tile.dart` | Single-row flat tile for buddies |
| `test/core/constants/list_view_mode_test.dart` | Renamed enum tests |
| `test/shared/widgets/list_view_mode_toggle_test.dart` | Renamed toggle tests with availableModes |
| `test/features/dive_sites/presentation/widgets/compact_site_list_tile_test.dart` | Compact site tile tests |
| `test/features/dive_sites/presentation/widgets/dense_site_list_tile_test.dart` | Dense site tile tests |
| `test/features/trips/presentation/widgets/compact_trip_list_tile_test.dart` | Compact trip tile tests |
| `test/features/trips/presentation/widgets/dense_trip_list_tile_test.dart` | Dense trip tile tests |
| `test/features/dive_centers/presentation/widgets/compact_dive_center_list_tile_test.dart` | Compact dive center tile tests |
| `test/features/dive_centers/presentation/widgets/dense_dive_center_list_tile_test.dart` | Dense dive center tile tests |
| `test/features/equipment/presentation/widgets/dense_equipment_list_tile_test.dart` | Dense equipment tile tests |
| `test/features/buddies/presentation/widgets/dense_buddy_list_tile_test.dart` | Dense buddy tile tests |

### Deleted Files

| File | Reason |
|------|--------|
| `lib/core/constants/dive_list_view_mode.dart` | Replaced by `list_view_mode.dart` |
| `lib/features/dive_log/presentation/widgets/dive_list_view_mode_toggle.dart` | Replaced by `shared/widgets/list_view_mode_toggle.dart` |
| `test/core/constants/dive_list_view_mode_test.dart` | Replaced by `list_view_mode_test.dart` |
| `test/features/dive_log/presentation/widgets/dive_list_view_mode_toggle_test.dart` | Replaced by `shared/widgets/list_view_mode_toggle_test.dart` |

### Modified Files

| File | Change |
|------|--------|
| `lib/core/database/database.dart` | Add 5 columns, bump schema, migration |
| `lib/features/settings/presentation/providers/settings_providers.dart` | Rename imports, add 5 fields/setters/providers |
| `lib/features/settings/data/repositories/diver_settings_repository.dart` | Rename import, add 5 serialize/deserialize |
| `lib/features/settings/presentation/pages/appearance_page.dart` | Rename import, add 5 new sections |
| `lib/features/settings/presentation/pages/settings_page.dart` | Rename import, add 5 new sections |
| `lib/features/dive_log/presentation/widgets/dive_list_content.dart` | Update imports for renamed files |
| `lib/features/dive_log/presentation/widgets/compact_dive_list_tile.dart` | Update import path |
| `lib/features/dive_log/presentation/widgets/dense_dive_list_tile.dart` | Update import path |
| `lib/features/dive_sites/presentation/widgets/site_list_content.dart` | Add toggle + tile switch |
| `lib/features/trips/presentation/widgets/trip_list_content.dart` | Add toggle + tile switch |
| `lib/features/equipment/presentation/widgets/equipment_list_content.dart` | Add toggle + tile switch |
| `lib/features/buddies/presentation/widgets/buddy_list_content.dart` | Add toggle + tile switch |
| `lib/features/dive_centers/presentation/widgets/dive_center_list_content.dart` | Add toggle + tile switch |
| Various test files | Update imports, add mock methods |

---

## Task 1: Rename Enum — DiveListViewMode to ListViewMode

**Files:**
- Create: `lib/core/constants/list_view_mode.dart`
- Create: `test/core/constants/list_view_mode_test.dart`
- Delete: `lib/core/constants/dive_list_view_mode.dart`
- Delete: `test/core/constants/dive_list_view_mode_test.dart`
- Modify: All 11 files that import `dive_list_view_mode.dart`

- [ ] **Step 1: Create new enum file**

Create `lib/core/constants/list_view_mode.dart` with identical content to `dive_list_view_mode.dart` but with the class renamed:

```dart
/// Which layout to use for list views.
enum ListViewMode {
  /// Full-size card with all details
  detailed,

  /// Two-line compact card
  compact,

  /// Single-row flat, divider-separated
  dense;

  /// Parse from stored string, defaulting to detailed.
  static ListViewMode fromName(String name) {
    return ListViewMode.values.firstWhere(
      (e) => e.name == name,
      orElse: () => ListViewMode.detailed,
    );
  }
}
```

- [ ] **Step 2: Create new test file**

Create `test/core/constants/list_view_mode_test.dart` — copy from `dive_list_view_mode_test.dart`, replace `DiveListViewMode` with `ListViewMode` and update the import to `list_view_mode.dart`.

- [ ] **Step 3: Run new test**

Run: `flutter test test/core/constants/list_view_mode_test.dart`
Expected: All tests PASS.

- [ ] **Step 4: Update all imports and references**

In ALL files that import `dive_list_view_mode.dart` (11 files listed below), replace:
- Import path: `dive_list_view_mode.dart` → `list_view_mode.dart`
- Class name: `DiveListViewMode` → `ListViewMode` (all occurrences)

Files to update:
1. `lib/features/dive_log/presentation/widgets/dive_list_view_mode_toggle.dart`
2. `lib/features/settings/presentation/pages/settings_page.dart`
3. `lib/features/settings/presentation/pages/appearance_page.dart`
4. `lib/features/dive_log/presentation/widgets/dive_list_content.dart`
5. `lib/features/settings/data/repositories/diver_settings_repository.dart`
6. `lib/features/settings/presentation/providers/settings_providers.dart`
7. `lib/core/database/database.dart`
8. `test/features/dive_log/presentation/widgets/dive_list_view_mode_toggle_test.dart`
9. `test/features/statistics/presentation/pages/records_page_test.dart`
10. `test/features/settings/presentation/pages/settings_page_test.dart`

Also update the `AppSettings` field type, `copyWith` parameter type, setter parameter type, `StateProvider` type, and all `ListViewMode.fromName()` / `ListViewMode.detailed` references.

- [ ] **Step 5: Delete old files**

Delete `lib/core/constants/dive_list_view_mode.dart` and `test/core/constants/dive_list_view_mode_test.dart`.

- [ ] **Step 6: Verify**

Run: `flutter analyze && flutter test`
Expected: No errors, all tests pass.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "refactor: rename DiveListViewMode to ListViewMode"
```

---

## Task 2: Rename and Move Toggle — DiveListViewModeToggle to ListViewModeToggle

**Files:**
- Create: `lib/shared/widgets/list_view_mode_toggle.dart`
- Create: `test/shared/widgets/list_view_mode_toggle_test.dart`
- Delete: `lib/features/dive_log/presentation/widgets/dive_list_view_mode_toggle.dart`
- Delete: `test/features/dive_log/presentation/widgets/dive_list_view_mode_toggle_test.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart` (update import)

- [ ] **Step 1: Create new toggle widget with availableModes**

Create `lib/shared/widgets/list_view_mode_toggle.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/constants/list_view_mode.dart';

/// Popup menu button for switching between list view modes.
///
/// Shows the icon of the current mode; tapping reveals available options.
class ListViewModeToggle extends StatelessWidget {
  final ListViewMode currentMode;
  final ValueChanged<ListViewMode> onModeChanged;

  /// Which modes to show in the popup. Defaults to all three.
  final List<ListViewMode> availableModes;

  /// Icon size (default 20 for compact app bars).
  final double iconSize;

  const ListViewModeToggle({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
    this.availableModes = ListViewMode.values,
    this.iconSize = 20,
  });

  IconData _iconForMode(ListViewMode mode) {
    return switch (mode) {
      ListViewMode.detailed => Icons.view_agenda,
      ListViewMode.compact => Icons.view_list,
      ListViewMode.dense => Icons.list,
    };
  }

  String _labelForMode(ListViewMode mode) {
    return switch (mode) {
      ListViewMode.detailed => 'Detailed',
      ListViewMode.compact => 'Compact',
      ListViewMode.dense => 'Dense',
    };
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ListViewMode>(
      icon: Icon(_iconForMode(currentMode), size: iconSize),
      tooltip: 'View mode',
      onSelected: onModeChanged,
      itemBuilder: (context) => availableModes.map((mode) {
        return PopupMenuItem(
          value: mode,
          child: Row(
            children: [
              Icon(
                _iconForMode(mode),
                size: 20,
                color: mode == currentMode
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              const SizedBox(width: 12),
              Text(
                _labelForMode(mode),
                style: mode == currentMode
                    ? TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      )
                    : null,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
```

- [ ] **Step 2: Create new test with availableModes tests**

Create `test/shared/widgets/list_view_mode_toggle_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/shared/widgets/list_view_mode_toggle.dart';

void main() {
  group('ListViewModeToggle', () {
    testWidgets('shows current mode icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListViewModeToggle(
              currentMode: ListViewMode.detailed,
              onModeChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.view_agenda), findsOneWidget);
      expect(find.byType(PopupMenuButton<ListViewMode>), findsOneWidget);
    });

    testWidgets('opens popup with all three options by default',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListViewModeToggle(
              currentMode: ListViewMode.detailed,
              onModeChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<ListViewMode>));
      await tester.pumpAndSettle();

      expect(find.text('Detailed'), findsOneWidget);
      expect(find.text('Compact'), findsOneWidget);
      expect(find.text('Dense'), findsOneWidget);
    });

    testWidgets('only shows availableModes when specified', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListViewModeToggle(
              currentMode: ListViewMode.detailed,
              onModeChanged: (_) {},
              availableModes: [ListViewMode.detailed, ListViewMode.dense],
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<ListViewMode>));
      await tester.pumpAndSettle();

      expect(find.text('Detailed'), findsOneWidget);
      expect(find.text('Compact'), findsNothing);
      expect(find.text('Dense'), findsOneWidget);
    });

    testWidgets('calls onModeChanged when option selected', (tester) async {
      ListViewMode? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListViewModeToggle(
              currentMode: ListViewMode.detailed,
              onModeChanged: (mode) => selected = mode,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<ListViewMode>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Compact'));
      await tester.pumpAndSettle();

      expect(selected, ListViewMode.compact);
    });
  });
}
```

- [ ] **Step 3: Update dive_list_content.dart import**

In `lib/features/dive_log/presentation/widgets/dive_list_content.dart`, replace:
```dart
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_view_mode_toggle.dart';
```
with:
```dart
import 'package:submersion/shared/widgets/list_view_mode_toggle.dart';
```

Also rename all occurrences of `DiveListViewModeToggle` to `ListViewModeToggle` in this file.

- [ ] **Step 4: Delete old files**

Delete `lib/features/dive_log/presentation/widgets/dive_list_view_mode_toggle.dart` and `test/features/dive_log/presentation/widgets/dive_list_view_mode_toggle_test.dart`.

- [ ] **Step 5: Verify**

Run: `flutter analyze && flutter test`
Expected: No errors, all tests pass.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: rename and move ListViewModeToggle to shared/widgets, add availableModes"
```

---

## Task 3: Database Schema — Add 5 Columns

**Files:**
- Modify: `lib/core/database/database.dart`

- [ ] **Step 1: Add 5 columns to DiverSettings table**

After the `diveListViewMode` column in the `DiverSettings` table, add:

```dart
  // List view modes for other features (v52)
  TextColumn get siteListViewMode =>
      text().withDefault(const Constant('detailed'))();
  TextColumn get tripListViewMode =>
      text().withDefault(const Constant('detailed'))();
  TextColumn get equipmentListViewMode =>
      text().withDefault(const Constant('detailed'))();
  TextColumn get buddyListViewMode =>
      text().withDefault(const Constant('detailed'))();
  TextColumn get diveCenterListViewMode =>
      text().withDefault(const Constant('detailed'))();
```

- [ ] **Step 2: Bump schema version**

Increment `currentSchemaVersion` by 1 (from current value).

- [ ] **Step 3: Add migration**

In the `onUpgrade` callback, after the last migration block, add:

```dart
        if (from < 52) {
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN site_list_view_mode TEXT NOT NULL DEFAULT 'detailed'",
          );
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN trip_list_view_mode TEXT NOT NULL DEFAULT 'detailed'",
          );
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN equipment_list_view_mode TEXT NOT NULL DEFAULT 'detailed'",
          );
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN buddy_list_view_mode TEXT NOT NULL DEFAULT 'detailed'",
          );
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN dive_center_list_view_mode TEXT NOT NULL DEFAULT 'detailed'",
          );
        }
```

Note: Use the actual next schema version number (currentSchemaVersion + 1), which should be 52 unless another migration landed first.

- [ ] **Step 4: Run code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 5: Verify**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add lib/core/database/database.dart
git commit -m "feat: add 5 list view mode columns to DiverSettings (schema v52)"
```

---

## Task 4: Settings Layer — AppSettings, Repository, Notifier, Runtime Providers

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart`
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart`

- [ ] **Step 1: Add 5 fields to AppSettings**

After the existing `diveListViewMode` field (and its `ListViewMode` type), add:

```dart
  /// Which layout to use for the site list
  final ListViewMode siteListViewMode;

  /// Which layout to use for the trip list
  final ListViewMode tripListViewMode;

  /// Which layout to use for the equipment list
  final ListViewMode equipmentListViewMode;

  /// Which layout to use for the buddy list
  final ListViewMode buddyListViewMode;

  /// Which layout to use for the dive center list
  final ListViewMode diveCenterListViewMode;
```

- [ ] **Step 2: Add constructor defaults**

After the existing `diveListViewMode` constructor default, add:

```dart
    this.siteListViewMode = ListViewMode.detailed,
    this.tripListViewMode = ListViewMode.detailed,
    this.equipmentListViewMode = ListViewMode.detailed,
    this.buddyListViewMode = ListViewMode.detailed,
    this.diveCenterListViewMode = ListViewMode.detailed,
```

- [ ] **Step 3: Add to copyWith parameters**

After the existing `diveListViewMode` copyWith parameter, add:

```dart
    ListViewMode? siteListViewMode,
    ListViewMode? tripListViewMode,
    ListViewMode? equipmentListViewMode,
    ListViewMode? buddyListViewMode,
    ListViewMode? diveCenterListViewMode,
```

- [ ] **Step 4: Add to copyWith return body**

After the existing `diveListViewMode` copyWith return line, add:

```dart
      siteListViewMode: siteListViewMode ?? this.siteListViewMode,
      tripListViewMode: tripListViewMode ?? this.tripListViewMode,
      equipmentListViewMode: equipmentListViewMode ?? this.equipmentListViewMode,
      buddyListViewMode: buddyListViewMode ?? this.buddyListViewMode,
      diveCenterListViewMode: diveCenterListViewMode ?? this.diveCenterListViewMode,
```

- [ ] **Step 5: Add 5 setters to SettingsNotifier**

After the existing `setDiveListViewMode` method, add:

```dart
  Future<void> setSiteListViewMode(ListViewMode mode) async {
    state = state.copyWith(siteListViewMode: mode);
    await _saveSettings();
  }

  Future<void> setTripListViewMode(ListViewMode mode) async {
    state = state.copyWith(tripListViewMode: mode);
    await _saveSettings();
  }

  Future<void> setEquipmentListViewMode(ListViewMode mode) async {
    state = state.copyWith(equipmentListViewMode: mode);
    await _saveSettings();
  }

  Future<void> setBuddyListViewMode(ListViewMode mode) async {
    state = state.copyWith(buddyListViewMode: mode);
    await _saveSettings();
  }

  Future<void> setDiveCenterListViewMode(ListViewMode mode) async {
    state = state.copyWith(diveCenterListViewMode: mode);
    await _saveSettings();
  }
```

- [ ] **Step 6: Add 5 runtime providers**

After the existing `diveListViewModeProvider`, add:

```dart
/// Runtime-scoped site list view mode.
final siteListViewModeProvider = StateProvider<ListViewMode>((ref) {
  final settings = ref.read(settingsProvider);
  return settings.siteListViewMode;
});

/// Runtime-scoped trip list view mode.
final tripListViewModeProvider = StateProvider<ListViewMode>((ref) {
  final settings = ref.read(settingsProvider);
  return settings.tripListViewMode;
});

/// Runtime-scoped equipment list view mode.
final equipmentListViewModeProvider = StateProvider<ListViewMode>((ref) {
  final settings = ref.read(settingsProvider);
  return settings.equipmentListViewMode;
});

/// Runtime-scoped buddy list view mode.
final buddyListViewModeProvider = StateProvider<ListViewMode>((ref) {
  final settings = ref.read(settingsProvider);
  return settings.buddyListViewMode;
});

/// Runtime-scoped dive center list view mode.
final diveCenterListViewModeProvider = StateProvider<ListViewMode>((ref) {
  final settings = ref.read(settingsProvider);
  return settings.diveCenterListViewMode;
});
```

- [ ] **Step 7: Update repository — createSettingsForDiver**

After the existing `diveListViewMode` line, add:

```dart
              siteListViewMode: Value(s.siteListViewMode.name),
              tripListViewMode: Value(s.tripListViewMode.name),
              equipmentListViewMode: Value(s.equipmentListViewMode.name),
              buddyListViewMode: Value(s.buddyListViewMode.name),
              diveCenterListViewMode: Value(s.diveCenterListViewMode.name),
```

- [ ] **Step 8: Update repository — updateSettingsForDiver**

After the existing `diveListViewMode` line, add:

```dart
          siteListViewMode: Value(settings.siteListViewMode.name),
          tripListViewMode: Value(settings.tripListViewMode.name),
          equipmentListViewMode: Value(settings.equipmentListViewMode.name),
          buddyListViewMode: Value(settings.buddyListViewMode.name),
          diveCenterListViewMode: Value(settings.diveCenterListViewMode.name),
```

- [ ] **Step 9: Update repository — _mapRowToAppSettings**

After the existing `diveListViewMode` line, add:

```dart
      siteListViewMode: ListViewMode.fromName(row.siteListViewMode),
      tripListViewMode: ListViewMode.fromName(row.tripListViewMode),
      equipmentListViewMode: ListViewMode.fromName(row.equipmentListViewMode),
      buddyListViewMode: ListViewMode.fromName(row.buddyListViewMode),
      diveCenterListViewMode: ListViewMode.fromName(row.diveCenterListViewMode),
```

- [ ] **Step 10: Verify**

Run: `flutter analyze && flutter test test/features/settings/`
Expected: No errors, all settings tests pass. Fix any mock notifiers that need the new setter methods (check `records_page_test.dart` and `settings_page_test.dart`).

- [ ] **Step 11: Commit**

```bash
git add lib/features/settings/ test/features/settings/ test/features/statistics/
git commit -m "feat: add 5 per-feature list view mode settings"
```

---

## Task 5: Settings UI — Appearance Page + Desktop Settings Page

**Files:**
- Modify: `lib/features/settings/presentation/pages/appearance_page.dart`
- Modify: `lib/features/settings/presentation/pages/settings_page.dart`

- [ ] **Step 1: Add 5 new sections to appearance_page.dart**

After the existing "Dive Log" section's last item (the map background switch), and before the "Dive Profile" section header, add 5 new sections. Each follows the same pattern:

```dart
          const Divider(),
          _buildSectionHeader(context, 'Dive Sites'),
          ListTile(
            leading: const Icon(Icons.view_list),
            title: const Text('Site List View'),
            subtitle: const Text('Default layout for the site list'),
            trailing: DropdownButton<ListViewMode>(
              value: settings.siteListViewMode,
              underline: const SizedBox(),
              onChanged: (value) {
                if (value != null) {
                  ref.read(settingsProvider.notifier).setSiteListViewMode(value);
                  ref.read(siteListViewModeProvider.notifier).state = value;
                }
              },
              items: ListViewMode.values.map((mode) {
                return DropdownMenuItem(
                  value: mode,
                  child: Text(_getViewModeDisplayName(mode)),
                );
              }).toList(),
            ),
          ),
```

Repeat for all 5 features with these variations:

| Feature | Section Title | Dropdown Title | Setting Method | Runtime Provider | Modes |
|---------|--------------|----------------|----------------|------------------|-------|
| Sites | `'Dive Sites'` | `'Site List View'` | `setSiteListViewMode` | `siteListViewModeProvider` | All 3 |
| Trips | `'Trips'` | `'Trip List View'` | `setTripListViewMode` | `tripListViewModeProvider` | All 3 |
| Equipment | `'Equipment'` | `'Equipment List View'` | `setEquipmentListViewMode` | `equipmentListViewModeProvider` | Detailed + Dense only |
| Buddies | `'Buddies'` | `'Buddy List View'` | `setBuddyListViewMode` | `buddyListViewModeProvider` | Detailed + Dense only |
| Dive Centers | `'Dive Centers'` | `'Dive Center List View'` | `setDiveCenterListViewMode` | `diveCenterListViewModeProvider` | All 3 |

For Equipment and Buddies, filter the dropdown items:
```dart
              items: [ListViewMode.detailed, ListViewMode.dense].map((mode) {
```

- [ ] **Step 2: Add same 5 sections to settings_page.dart (desktop inline)**

Find the Dive Log card section in `settings_page.dart` (the desktop inline appearance rendering). After it, add the same 5 sections following the desktop pattern (wrapped in `Card` widgets with `Divider(height: 1)` separators). Read the existing Dive Log card structure and match it.

- [ ] **Step 3: Verify**

Run: `flutter analyze && flutter test`
Expected: No errors, all tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/features/settings/presentation/pages/
git commit -m "feat: add per-feature list view mode dropdowns to Appearance settings"
```

---

## Task 6: Sites — Compact and Dense Tiles

**Files:**
- Create: `lib/features/dive_sites/presentation/widgets/compact_site_list_tile.dart`
- Create: `lib/features/dive_sites/presentation/widgets/dense_site_list_tile.dart`
- Test: `test/features/dive_sites/presentation/widgets/compact_site_list_tile_test.dart`
- Test: `test/features/dive_sites/presentation/widgets/dense_site_list_tile_test.dart`

**Reference:** Read the existing `SiteListTile` in `site_list_content.dart` (line ~944) for constructor parameters and the existing dive compact/dense tiles for the layout pattern.

- [ ] **Step 1: Write CompactSiteListTile test**

Follow the test pattern from `compact_dive_list_tile_test.dart`. Use `testApp()` with `_TestSettingsNotifier`. Test:
- Renders site name, location, dive count
- Shows checkbox in selection mode
- Handles null location

- [ ] **Step 2: Write CompactSiteListTile widget**

Constructor takes: `name`, `location`, `diveCount`, `onTap`, `onLongPress`, `isSelectionMode`, `isSelected`.

Layout:
- Line 1: Name (expanded) | Dive count text | Chevron
- Line 2: Location string (secondary text color)
- Card with `margin: EdgeInsets.symmetric(horizontal: 16, vertical: 2)`, padding 10

No card color gradient support. No map background.

- [ ] **Step 3: Write DenseSiteListTile test**

Test: renders name, location, dive count; checkbox in selection mode.

- [ ] **Step 4: Write DenseSiteListTile widget**

Constructor takes same params as compact. Single row with `DecoratedBox` + bottom border divider.
- Row: Name (expanded, bodySmall) | Location (truncated, fixed width ~100) | Dive count (fixed width ~40) | Chevron

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/dive_sites/presentation/widgets/`
Expected: All pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_sites/presentation/widgets/compact_site_list_tile.dart lib/features/dive_sites/presentation/widgets/dense_site_list_tile.dart test/features/dive_sites/presentation/widgets/
git commit -m "feat: add CompactSiteListTile and DenseSiteListTile widgets"
```

---

## Task 7: Sites — Integration (App Bar Toggle + Tile Switch)

**Files:**
- Modify: `lib/features/dive_sites/presentation/widgets/site_list_content.dart`

- [ ] **Step 1: Add imports**

```dart
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/compact_site_list_tile.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/dense_site_list_tile.dart';
import 'package:submersion/shared/widgets/list_view_mode_toggle.dart';
```

- [ ] **Step 2: Add toggle to mobile app bar**

In the app bar actions list (around line 326), add `ListViewModeToggle` as the first action:

```dart
        ListViewModeToggle(
          currentMode: ref.watch(siteListViewModeProvider),
          onModeChanged: (mode) {
            ref.read(siteListViewModeProvider.notifier).state = mode;
          },
        ),
```

- [ ] **Step 3: Add toggle to compact app bar**

In `_buildCompactAppBar` (around line 391), add the toggle before the `MapViewToggleButton`:

```dart
          ListViewModeToggle(
            currentMode: ref.watch(siteListViewModeProvider),
            onModeChanged: (mode) {
              ref.read(siteListViewModeProvider.notifier).state = mode;
            },
            iconSize: 18,
          ),
          const SizedBox(width: 4),
```

- [ ] **Step 4: Replace tile instantiation with switch**

Find where `SiteListTile(...)` is instantiated (around line 583). Replace with:

```dart
                final viewMode = ref.watch(siteListViewModeProvider);
                return switch (viewMode) {
                  ListViewMode.detailed => SiteListTile(
                    // ... existing params unchanged
                  ),
                  ListViewMode.compact => CompactSiteListTile(
                    name: site.name,
                    location: site.location,
                    diveCount: site.diveCount,
                    isSelectionMode: _isSelectionMode,
                    isSelected: isSelected || isMasterSelected,
                    onTap: () => _handleItemTap(site),
                    onLongPress: _isSelectionMode
                        ? null
                        : () => _enterSelectionMode(site.id),
                  ),
                  ListViewMode.dense => DenseSiteListTile(
                    name: site.name,
                    location: site.location,
                    diveCount: site.diveCount,
                    isSelectionMode: _isSelectionMode,
                    isSelected: isSelected || isMasterSelected,
                    onTap: () => _handleItemTap(site),
                    onLongPress: _isSelectionMode
                        ? null
                        : () => _enterSelectionMode(site.id),
                  ),
                };
```

Note: Read the actual `SiteListTile` instantiation to get the exact variable names and method calls. The `site` variable name may differ — match what exists.

- [ ] **Step 5: Verify**

Run: `flutter analyze && flutter test`
Expected: No errors, all tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_sites/presentation/widgets/site_list_content.dart
git commit -m "feat: integrate view mode toggle and tile switching for sites"
```

---

## Task 8: Trips — Compact and Dense Tiles

**Files:**
- Create: `lib/features/trips/presentation/widgets/compact_trip_list_tile.dart`
- Create: `lib/features/trips/presentation/widgets/dense_trip_list_tile.dart`
- Test: `test/features/trips/presentation/widgets/compact_trip_list_tile_test.dart`
- Test: `test/features/trips/presentation/widgets/dense_trip_list_tile_test.dart`

**Reference:** Read `TripListTile` in `trip_list_content.dart` (line ~389). It takes a `TripWithStats` entity.

- [ ] **Step 1: Write tests for both tiles**

CompactTripListTile test: renders trip name, date range, dive count + bottom time.
DenseTripListTile test: renders trip name, abbreviated date range, dive count.

- [ ] **Step 2: Write CompactTripListTile**

Constructor takes: `TripWithStats tripWithStats`, `isSelected`, `onTap`.

Layout:
- Line 1: Trip name (expanded) | Date range | Chevron
- Line 2: Dive count icon + count | Bottom time icon + time

Read how `TripListTile` formats date range and use the same approach.

- [ ] **Step 3: Write DenseTripListTile**

Constructor takes same. Single row: name | abbreviated date range | dive count | chevron.

For abbreviated date range: use "MMM d" format for start-end, e.g., "Mar 10 - Mar 17". Show year if not current year.

- [ ] **Step 4: Run tests and commit**

Run: `flutter test test/features/trips/presentation/widgets/`

```bash
git add lib/features/trips/presentation/widgets/compact_trip_list_tile.dart lib/features/trips/presentation/widgets/dense_trip_list_tile.dart test/features/trips/presentation/widgets/
git commit -m "feat: add CompactTripListTile and DenseTripListTile widgets"
```

---

## Task 9: Trips — Integration

**Files:**
- Modify: `lib/features/trips/presentation/widgets/trip_list_content.dart`

Follow exact same pattern as Task 7 (Sites integration):

- [ ] **Step 1: Add imports** (list_view_mode, compact tile, dense tile, toggle)
- [ ] **Step 2: Add toggle to mobile app bar** (using `tripListViewModeProvider`)
- [ ] **Step 3: Add toggle to compact app bar**
- [ ] **Step 4: Replace TripListTile instantiation with switch**

Note: `TripListTile` takes `tripWithStats` — pass the same entity to compact/dense variants.

- [ ] **Step 5: Verify and commit**

```bash
git commit -m "feat: integrate view mode toggle and tile switching for trips"
```

---

## Task 10: Dive Centers — Compact and Dense Tiles

**Files:**
- Create: `lib/features/dive_centers/presentation/widgets/compact_dive_center_list_tile.dart`
- Create: `lib/features/dive_centers/presentation/widgets/dense_dive_center_list_tile.dart`
- Test files for both

**Reference:** Read `DiveCenterListTile` in `dive_center_list_content.dart` (line ~400). It's a `ConsumerWidget` that takes a `DiveCenter` entity and watches a dive count provider.

- [ ] **Step 1: Write tests for both tiles**
- [ ] **Step 2: Write CompactDiveCenterListTile**

Constructor takes: `DiveCenter center`, `isSelected`, `onTap`. Also takes `int diveCount` (pre-resolved, to keep tile simple).

Layout:
- Line 1: Name (expanded) | Dive count | Chevron
- Line 2: Location string

- [ ] **Step 3: Write DenseDiveCenterListTile**

Single row: Name | Location (truncated) | Dive count | Chevron.

- [ ] **Step 4: Run tests and commit**

```bash
git commit -m "feat: add CompactDiveCenterListTile and DenseDiveCenterListTile widgets"
```

---

## Task 11: Dive Centers — Integration

**Files:**
- Modify: `lib/features/dive_centers/presentation/widgets/dive_center_list_content.dart`

Same pattern as Tasks 7/9. Use `diveCenterListViewModeProvider`. Dive centers already have a map toggle — add the view mode toggle before it.

- [ ] **Step 1-5:** Same pattern (imports, mobile app bar, compact app bar, tile switch, verify/commit)

```bash
git commit -m "feat: integrate view mode toggle and tile switching for dive centers"
```

---

## Task 12: Equipment — Dense Tile + Integration

**Files:**
- Create: `lib/features/equipment/presentation/widgets/dense_equipment_list_tile.dart`
- Test: `test/features/equipment/presentation/widgets/dense_equipment_list_tile_test.dart`
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_content.dart`

**Reference:** Read `EquipmentListTile` in `equipment_list_content.dart` (line ~405). Takes `EquipmentItem item`.

- [ ] **Step 1: Write test**

Test: renders name, type label, service status; checkbox in selection mode.

- [ ] **Step 2: Write DenseEquipmentListTile**

Constructor takes: `EquipmentItem item`, `isSelected`, `onTap`.

Single row: Name (expanded) | Type label (bodySmall) | Service status text (error color if due) | Chevron.

Read how `EquipmentListTile` determines service status display and reuse the same logic.

- [ ] **Step 3: Integrate into equipment_list_content.dart**

Add imports, toggle (with `availableModes: [ListViewMode.detailed, ListViewMode.dense]`), and tile switch. The `compact` branch is unreachable via the toggle but Dart requires exhaustive switches, so combine it with `detailed`:

```dart
final viewMode = ref.watch(equipmentListViewModeProvider);
return switch (viewMode) {
  ListViewMode.detailed || ListViewMode.compact => EquipmentListTile(...),
  ListViewMode.dense => DenseEquipmentListTile(...),
};
```

Use `equipmentListViewModeProvider`.

- [ ] **Step 4: Run tests and commit**

```bash
git commit -m "feat: add DenseEquipmentListTile and integrate view mode for equipment"
```

---

## Task 13: Buddies — Dense Tile + Integration

**Files:**
- Create: `lib/features/buddies/presentation/widgets/dense_buddy_list_tile.dart`
- Test: `test/features/buddies/presentation/widgets/dense_buddy_list_tile_test.dart`
- Modify: `lib/features/buddies/presentation/widgets/buddy_list_content.dart`

**Reference:** Read `BuddyListTile` in `buddy_list_content.dart` (line ~433). Takes `Buddy buddy` and `int? diveCount`.

- [ ] **Step 1: Write test**

Test: renders name, cert level, dive count; checkbox in selection mode.

- [ ] **Step 2: Write DenseBuddyListTile**

Constructor takes: `Buddy buddy`, `int? diveCount`, `isSelected`, `onTap`.

Single row: Name (expanded) | Cert level (bodySmall, truncated) | Dive count (fixed width) | Chevron.

No avatar, no agency.

- [ ] **Step 3: Integrate into buddy_list_content.dart**

Add imports, toggle (with `availableModes: [ListViewMode.detailed, ListViewMode.dense]`), and tile switch. Same compact-falls-through-to-detailed pattern as equipment:

```dart
final viewMode = ref.watch(buddyListViewModeProvider);
return switch (viewMode) {
  ListViewMode.detailed || ListViewMode.compact => BuddyListTile(...),
  ListViewMode.dense => DenseBuddyListTile(...),
};
```

Use `buddyListViewModeProvider`.

- [ ] **Step 4: Run tests and commit**

```bash
git commit -m "feat: add DenseBuddyListTile and integrate view mode for buddies"
```

---

## Task 14: Format, Analyze, and Final Verification

**Files:** All modified files

- [ ] **Step 1: Format all code**

Run: `dart format lib/ test/`

- [ ] **Step 2: Run full analysis**

Run: `flutter analyze`
Expected: No issues.

- [ ] **Step 3: Run all tests**

Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 4: Manual smoke test**

Run: `flutter run -d macos`

Verify for EACH of the 5 features:
1. Default view is detailed
2. App bar popup toggle shows correct options (3 for sites/trips/centers, 2 for equipment/buddies)
3. Switching modes renders the correct tile variant
4. Selection mode works in all view modes
5. Settings > Appearance shows the feature's dropdown in its own section
6. Changing the default in Settings updates the list
7. App bar toggle is session-scoped (reloading reverts to default)

- [ ] **Step 5: Commit any formatting fixes**

```bash
git add -A
git commit -m "style: format code"
```
