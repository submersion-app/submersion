# List View Density Modes for All Features

## Problem

The dive list now supports three view density modes (detailed, compact, dense), but the other list screens (sites, trips, equipment, buddies, dive centers) still only have one layout. Users with many entries need the same density control across all list views.

## Solution

Add compact and/or dense view modes to all five remaining list features. As part of this work, rename the existing `ListViewMode` enum to `ListViewMode` and `ListViewModeToggle` to `ListViewModeToggle` since they are now shared across all features. Each feature gets per-feature persistent settings and session-scoped app bar toggles matching the dive list pattern.

## Features and Modes

| Feature | Modes | Compact | Dense |
|---------|-------|---------|-------|
| Sites | detailed, compact, dense | Yes | Yes |
| Trips | detailed, compact, dense | Yes | Yes |
| Dive Centers | detailed, compact, dense | Yes | Yes |
| Equipment | detailed, dense | No | Yes |
| Buddies | detailed, dense | No | Yes |

Equipment and buddies tiles are already fairly compact, so a middle tier is not needed.

## Compact Tile Layouts (Two-Line Card)

### CompactSiteListTile

- Line 1: Site name (expanded) | Dive count | Chevron
- Line 2: Location string
- Dropped from detailed: Map background, depth range, difficulty, star rating, circular avatar

### CompactTripListTile

- Line 1: Trip name (expanded) | Date range | Chevron
- Line 2: Dive count | Total bottom time
- Dropped from detailed: Trip type icon/avatar, trip subtitle

### CompactDiveCenterListTile

- Line 1: Name (expanded) | Dive count | Chevron
- Line 2: Location string
- Dropped from detailed: Affiliations, star rating, custom icon container

## Dense Tile Layouts (Single-Row Flat)

All dense tiles use no card wrapper, divider-separated rows with fixed-width columns for alignment.

### DenseSiteListTile

- Row: Site name (expanded) | Location (truncated) | Dive count | Chevron

### DenseTripListTile

- Row: Trip name (expanded) | Abbreviated date range | Dive count | Chevron

### DenseDiveCenterListTile

- Row: Name (expanded) | Location (truncated) | Dive count | Chevron

### DenseEquipmentListTile

- Row: Name (expanded) | Type label | Service status indicator | Chevron
- Service status uses error color if service is due, secondary color otherwise

### DenseBuddyListTile

- Row: Name (expanded) | Cert level | Dive count | Chevron
- No avatar, no agency

## Shared Infrastructure

### DiveListViewMode Enum

Reuse the existing `ListViewMode` enum (`detailed`, `compact`, `dense`) from `lib/core/constants/dive_list_view_mode.dart`. No changes needed.

### DiveListViewModeToggle Enhancement

Add an `availableModes` parameter to the existing `ListViewModeToggle` widget:

```dart
class DiveListViewModeToggle extends StatelessWidget {
  final DiveListViewMode currentMode;
  final ValueChanged<DiveListViewMode> onModeChanged;
  final List<DiveListViewMode> availableModes;
  final double iconSize;
  ...
}
```

- Defaults to `DiveListViewMode.values` (all three modes)
- Equipment and buddies pass `[DiveListViewMode.detailed, DiveListViewMode.dense]`
- The popup menu only renders items in `availableModes`

### Database

Add 5 new text columns to the `DiverSettings` table. Single schema bump (currentSchemaVersion + 1) with one migration adding all columns:

```dart
TextColumn get siteListViewMode => text().withDefault(const Constant('detailed'))();
TextColumn get tripListViewMode => text().withDefault(const Constant('detailed'))();
TextColumn get equipmentListViewMode => text().withDefault(const Constant('detailed'))();
TextColumn get buddyListViewMode => text().withDefault(const Constant('detailed'))();
TextColumn get diveCenterListViewMode => text().withDefault(const Constant('detailed'))();
```

Migration:

```sql
ALTER TABLE diver_settings ADD COLUMN site_list_view_mode TEXT NOT NULL DEFAULT 'detailed';
ALTER TABLE diver_settings ADD COLUMN trip_list_view_mode TEXT NOT NULL DEFAULT 'detailed';
ALTER TABLE diver_settings ADD COLUMN equipment_list_view_mode TEXT NOT NULL DEFAULT 'detailed';
ALTER TABLE diver_settings ADD COLUMN buddy_list_view_mode TEXT NOT NULL DEFAULT 'detailed';
ALTER TABLE diver_settings ADD COLUMN dive_center_list_view_mode TEXT NOT NULL DEFAULT 'detailed';
```

### AppSettings

5 new `ListViewMode` fields with defaults of `DiveListViewMode.detailed`. 5 new setters on `SettingsNotifier` following the existing `setDiveListViewMode` pattern.

### DiverSettingsRepository

Serialize/deserialize all 5 new fields in `createSettingsForDiver`, `updateSettingsForDiver`, and `_mapRowToAppSettings` using `.name` / `DiveListViewMode.fromName()`.

### Runtime Providers

5 new `StateProvider<DiveListViewMode>` providers, each using `ref.read(settingsProvider)` (not `ref.watch`) to initialize from the persisted default:

```dart
final siteListViewModeProvider = StateProvider<DiveListViewMode>((ref) {
  final settings = ref.read(settingsProvider);
  return settings.siteListViewMode;
});
// ... same pattern for trip, equipment, buddy, diveCenter
```

## Toggle Control

### App Bar (Quick Switch)

Each feature's list content widget gets a `ListViewModeToggle` in its app bar actions (both mobile `_buildAppBar` and desktop `_buildCompactAppBar`). Same placement pattern as the dive list.

- Sites, trips, dive centers: default `availableModes` (all three)
- Equipment, buddies: `availableModes: [DiveListViewMode.detailed, DiveListViewMode.dense]`

### Settings > Appearance (Persistent Default)

New sections in the Appearance page for each feature, placed after the existing "Dive Log" section:

- **Dive Sites** section -- site list view mode dropdown
- **Trips** section -- trip list view mode dropdown
- **Equipment** section -- equipment list view mode dropdown (Detailed/Dense only)
- **Buddies** section -- buddy list view mode dropdown (Detailed/Dense only)
- **Dive Centers** section -- dive center list view mode dropdown

Both `appearance_page.dart` (mobile) and `settings_page.dart` (desktop inline) get the new sections.

### Runtime vs. Default Behavior

Matches the dive list pattern:
- On page load, the runtime view mode initializes from the persisted default.
- App bar toggle changes the runtime value only (session-scoped).
- Settings page changes both the persistent default AND the current runtime value.

## Rename Existing Files

As part of this work, rename the enum and toggle widget to remove the "Dive" prefix:

| Old Name | New Name | Old File | New File |
|----------|----------|----------|----------|
| `DiveListViewMode` | `ListViewMode` | `lib/core/constants/dive_list_view_mode.dart` | `lib/core/constants/list_view_mode.dart` |
| `DiveListViewModeToggle` | `ListViewModeToggle` | `lib/features/dive_log/presentation/widgets/dive_list_view_mode_toggle.dart` | `lib/shared/widgets/list_view_mode_toggle.dart` |

Update all existing references in the dive list feature, settings providers, settings pages, and tests. The toggle moves from the dive_log feature to shared/widgets since it is now used by all features.

Also rename the existing runtime provider from `diveListViewModeProvider` to stay consistent. The dive list's runtime provider keeps its name since it is feature-specific.

## Selection Mode

All new compact and dense tile widgets support `isSelectionMode` and `isSelected` parameters, following the same pattern as the existing dive list tiles. In selection mode, a checkbox replaces the leading element (dive number, icon, or avatar). Features that currently support selection mode (sites with multi-select) carry that behavior into all view modes.

## Card Color Gradients

Card color gradient support (attribute-based coloring) is **dive list only**. The new tiles for other features do not include `colorValue`, `minValueInList`, or gradient color parameters. If gradient coloring is added to other features in the future, it can be added to their tile widgets at that time.

## New Widget Files

| Widget | File |
|--------|------|
| `CompactSiteListTile` | `lib/features/dive_sites/presentation/widgets/compact_site_list_tile.dart` |
| `DenseSiteListTile` | `lib/features/dive_sites/presentation/widgets/dense_site_list_tile.dart` |
| `CompactTripListTile` | `lib/features/trips/presentation/widgets/compact_trip_list_tile.dart` |
| `DenseTripListTile` | `lib/features/trips/presentation/widgets/dense_trip_list_tile.dart` |
| `CompactDiveCenterListTile` | `lib/features/dive_centers/presentation/widgets/compact_dive_center_list_tile.dart` |
| `DenseDiveCenterListTile` | `lib/features/dive_centers/presentation/widgets/dense_dive_center_list_tile.dart` |
| `DenseEquipmentListTile` | `lib/features/equipment/presentation/widgets/dense_equipment_list_tile.dart` |
| `DenseBuddyListTile` | `lib/features/buddies/presentation/widgets/dense_buddy_list_tile.dart` |

## Modified Files

| File | Change |
|------|--------|
| `lib/core/database/database.dart` | Add 5 columns to DiverSettings, bump to v52, migration |
| `lib/features/settings/presentation/providers/settings_providers.dart` | 5 fields on AppSettings, 5 setters, 5 runtime providers |
| `lib/features/settings/data/repositories/diver_settings_repository.dart` | Serialize/deserialize 5 new fields |
| `lib/features/settings/presentation/pages/appearance_page.dart` | 5 new sections with dropdowns |
| `lib/features/settings/presentation/pages/settings_page.dart` | 5 new sections (desktop inline) |
| `lib/features/dive_log/presentation/widgets/dive_list_view_mode_toggle.dart` | Add `availableModes` parameter |
| `lib/features/dive_sites/presentation/widgets/site_list_content.dart` | Toggle in app bar, tile switch |
| `lib/features/trips/presentation/widgets/trip_list_content.dart` | Toggle in app bar, tile switch |
| `lib/features/equipment/presentation/widgets/equipment_list_content.dart` | Toggle in app bar, tile switch |
| `lib/features/buddies/presentation/widgets/buddy_list_content.dart` | Toggle in app bar, tile switch |
| `lib/features/dive_centers/presentation/widgets/dive_center_list_content.dart` | Toggle in app bar, tile switch |

## Testing

- Widget tests for each new tile widget (8 tiles x ~3 tests each) -- renders correct data, selection mode, null fallbacks
- Widget test for `ListViewModeToggle` with `availableModes` -- only filtered modes appear
- Existing settings tests should pass with defaults (new fields have defaults)
- Mock notifier updates for any test files with explicit `SettingsNotifier` implementations
