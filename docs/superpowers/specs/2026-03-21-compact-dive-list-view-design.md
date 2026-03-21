# Compact Dive List View

## Problem

The current dive list tiles are large, showing dive number, site name, location, date/time, profile mini-chart, depth/duration/temperature stats, and tags. This limits the number of dives visible on screen at once. Users with many logged dives need a denser view for faster scanning and navigation.

## Solution

Add two new compact view modes alongside the existing detailed tile, with a toggle in the app bar for quick switching and a persistent default in Settings > Appearance.

## View Modes

### Detailed (current, default)

No changes. The existing `DiveListTile` with all current features: CircleAvatar dive number, site name with favorite/rating, location, date/time, profile mini-chart, depth/duration/temperature stats, tags, map-tile background support.

### Compact (Two-Line Card)

A new `CompactDiveListTile` widget. Roughly 2x the density of the detailed view.

**Line 1:** Dive number (text, not CircleAvatar) | Site name (expanded, ellipsis overflow) | Date/time | Chevron

**Line 2:** (indented under site name) Depth icon + value | Duration icon + value

- Card-based layout preserved (Material `Card` widget)
- Card vertical margin reduced from 4 to 2
- Internal padding reduced from 12 to 10
- Selection mode: checkbox replaces dive number (same as current)
- Attribute gradient coloring supported on card background
- Map-tile background NOT supported (too visually noisy at this density)

**Dropped from detailed:** Location (region/country), star rating, favorite icon, profile mini-chart, water temperature, tags.

### Dense (Single-Row Flat)

A new `DenseDiveListTile` widget. Roughly 3x the density of the detailed view.

**Single row:** Dive number | Site name (expanded) | Abbreviated date | Depth | Duration | Chevron

- No card wrapper -- flat rows with thin dividers between them
- Uses `InkWell` directly inside the `ListView`
- Date abbreviated: "Mar 15" (no time, no year unless different from current year)
- Fixed-width columns for depth and duration so values align across rows
- Selection mode: checkbox replaces dive number
- Attribute gradient coloring supported on row background
- Map-tile background NOT supported

**Dropped from compact:** Full date/time reduced to short date, no card elevation/margins, stats inline on single row instead of second line.

## View Mode Enum

New file: `lib/core/constants/dive_list_view_mode.dart`

```dart
enum DiveListViewMode {
  detailed,
  compact,
  dense;

  static DiveListViewMode fromName(String name) {
    return DiveListViewMode.values.firstWhere(
      (e) => e.name == name,
      orElse: () => DiveListViewMode.detailed,
    );
  }
}
```

Follows the existing `CardColorAttribute` enum pattern.

## Data Model Changes

### Database

Add a text column to the `DiverSettings` table:

```dart
TextColumn get diveListViewMode =>
    text().withDefault(const Constant('detailed'))();
```

### AppSettings

Add field:

```dart
final DiveListViewMode diveListViewMode;
```

With `copyWith` support and default of `DiveListViewMode.detailed`.

### SettingsNotifier

Add setter:

```dart
Future<void> setDiveListViewMode(DiveListViewMode mode) async {
  state = state.copyWith(diveListViewMode: mode);
  await _saveSettings();
}
```

### DiverSettingsRepository

Map to/from database using `.name` / `DiveListViewMode.fromName()`, following the existing pattern used by `CardColorAttribute`.

## Toggle Control

### App Bar (Quick Switch)

A segmented icon button group in the dive list app bar, next to the existing map toggle:

- `Icons.view_agenda` for Detailed
- `Icons.view_list` for Compact
- `Icons.list` for Dense

Reads/writes to a **runtime-scoped provider** (not the persisted default). This allows quick switching without overwriting the user's saved preference.

### Settings > Appearance (Persistent Default)

A new "Dive List View" dropdown in the Appearance page, alongside the existing card coloring controls. Options: Detailed / Compact / Dense. Sets the persisted default via `SettingsNotifier.setDiveListViewMode()`.

### Runtime vs. Default Behavior

- On page load, the runtime view mode initializes from the persisted default.
- App bar toggle changes the runtime value only (session-scoped).
- Settings page changes both the persistent default AND the current runtime value.
- Result: switching via app bar is temporary; changing the setting is permanent.

## Widget Architecture

### New Widgets

| Widget | File | Purpose |
|--------|------|---------|
| `CompactDiveListTile` | `lib/features/dive_log/presentation/widgets/compact_dive_list_tile.dart` | Two-line compact card tile |
| `DenseDiveListTile` | `lib/features/dive_log/presentation/widgets/dense_dive_list_tile.dart` | Single-row flat tile |
| `DiveListViewModeToggle` | `lib/features/dive_log/presentation/widgets/dive_list_view_mode_toggle.dart` | Segmented icon button for app bar |

### Modified Files

| File | Change |
|------|--------|
| `lib/core/database/database.dart` | Add `diveListViewMode` column to `DiverSettings` |
| `lib/features/settings/presentation/providers/settings_providers.dart` | Add field to `AppSettings`, setter to `SettingsNotifier` |
| `lib/features/settings/data/repositories/diver_settings_repository.dart` | Map new column to/from `AppSettings` |
| `lib/features/settings/presentation/pages/appearance_page.dart` | Add "Dive List View" dropdown |
| `lib/features/dive_log/presentation/widgets/dive_list_content.dart` | Switch tile widget based on runtime view mode |
| `lib/features/dive_log/presentation/pages/dive_list_page.dart` | Add view mode toggle to app bar |

### Runtime Provider

A new `StateProvider<DiveListViewMode>` that initializes from the persisted setting and can be overridden by the app bar toggle. The `DiveListContent` widget watches this provider to decide which tile widget to render.

## Attribute Coloring

All three view modes support attribute-based gradient coloring (depth, duration, temperature). The same `colorValue`, `minValueInList`, `maxValueInList`, `gradientStartColor`, `gradientEndColor` parameters are passed to all tile variants. The `normalizeAndLerp` utility and luminance-based text color logic are reused.

Map-tile backgrounds are only supported in the Detailed view mode. The compact and dense views disable map backgrounds regardless of the setting.

## Testing

- Unit tests for `DiveListViewMode` enum (fromName, default fallback)
- Widget tests for `CompactDiveListTile` and `DenseDiveListTile` (renders correct data, selection mode, attribute coloring)
- Widget test for `DiveListViewModeToggle` (tapping changes mode)
- Integration test: switching view modes in `DiveListContent` renders correct tile type
- Settings persistence: verify round-trip through database
