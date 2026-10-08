# Table Mode: Full-Width Default, Details Toggle, and Entity Settings

## Problem

In table mode, all sections except Dives render the table inside the
`MasterDetailScaffold` master pane (440px), with the detail pane always visible
on the right. This wastes horizontal space that the table needs. Dives already
handles this correctly by bypassing `MasterDetailScaffold` and using a
full-width layout.

Additional gaps:
- No way to toggle a details pane on/off in table mode for any section.
- Non-Dives sections lack a "Column Settings" button in the desktop app bar.
- Settings > Appearance has no field configuration for non-Dives sections
  (no table column presets, no card view field customization).

## Design

### 1. `TableModeLayout` Shared Widget

A new widget at `lib/shared/widgets/table_mode_layout/table_mode_layout.dart`
that encapsulates the table mode layout state machine for all sections.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `sectionKey` | `String` | Yes | Identifier for this section (e.g., `'dives'`, `'sites'`). Used to key persisted toggle state. |
| `appBarTitle` | `String` | Yes | Section title for the app bar. |
| `tableContent` | `Widget` | Yes | The table view widget (EntityTableView or DiveTableView). |
| `detailBuilder` | `Widget Function(String id)` | Yes | Builds the detail pane for a selected entity. Same builder currently passed to MasterDetailScaffold. |
| `editBuilder` | `Widget Function(String id)` | No | Builds the edit form for an entity. |
| `createBuilder` | `Widget Function()` | No | Builds the create form. |
| `summaryBuilder` | `Widget Function(String id)` | No | Builds the summary widget for an entity. |
| `mapBuilder` | `Widget Function({String? selectedId, ...})` | No | Builds the map pane. Signature matches existing mapBuilder used in MasterDetailScaffold. Only provided by Dives, Sites, and Dive Centers. |
| `profilePanelBuilder` | `Widget Function()` | No | Builds the profile panel above the table. Only provided by Dives. |
| `appBarActions` | `List<Widget>` | No | Additional app bar actions (e.g., column settings button). |
| `selectedId` | `String?` | Yes | Currently highlighted/selected entity ID. |
| `onEntitySelected` | `void Function(String)` | Yes | Callback when a table row is tapped (highlights row, updates detail pane). |
| `onEntityDoubleTap` | `void Function(String)?` | No | Callback for double-tap navigation (navigates to detail page). |
| `isSelectionMode` | `bool` | No | Whether multi-selection mode is active. |
| `selectedIds` | `Set<String>` | No | Set of selected entity IDs in selection mode. |
| `onSelectionChanged` | `void Function(String)?` | No | Toggle selection for an entity. |
| `selectionAppBar` | `PreferredSizeWidget?` | No | App bar to show when selection mode is active (with count, actions). |
| `floatingActionButton` | `Widget?` | No | FAB for the scaffold. |

#### Layout State Machine (Desktop >= 1100px)

| Details | Map | Profile | Result |
|---------|-----|---------|--------|
| OFF | OFF | OFF | Full-width Scaffold with table only |
| ON | OFF | n/a | MasterDetailScaffold: table as master, detail pane right |
| OFF | ON | OFF | Row: table left (Expanded), map right (Expanded) |
| ON | ON | n/a | MasterDetailScaffold: Column(map, table) as master, detail pane right |
| OFF | OFF | ON | Full-width Scaffold with Column(profilePanel, table) -- Dives only |
| OFF | ON | ON | Row: Column(profilePanel, table) left, map right -- Dives only |

Profile and Details are mutually exclusive. Toggling one disables the other.

#### App Bar Toggle Buttons (Desktop Only)

The widget renders these toggle buttons in the app bar, right-aligned:

1. **Profile** (Dives only) -- `Icons.area_chart`, toggles profile panel
2. **Details** -- `Icons.vertical_split` or similar, toggles detail pane
3. **Map** (sections with mapBuilder only) -- `Icons.map`, toggles map view
4. **Columns** -- `Icons.view_column_outlined`, opens column picker

Active toggles use the primary color tint (same as the existing Dives profile
panel toggle). Inactive toggles use the default icon color.

#### Mobile (< 1100px)

- Details button is not shown.
- Map toggle navigates to full-screen map (existing behavior, unchanged).
- Profile panel toggle remains available for Dives.
- Column settings button is shown.

### 2. Toggle State Management

#### Details Pane Toggle Provider

A `StateNotifier`-based provider family, keyed by section name, that loads its
initial value from the diver settings repository and writes back on change.
Follows the same pattern as the existing `showProfilePanelProvider` and
`tableViewConfigProvider`:

```dart
// One provider per section, reading/writing to the diver settings JSON.
// Key: "showTableDetailsPane_<sectionKey>" in the settings map.
final tableDetailsPaneProvider = StateNotifierProvider.family<
    TableDetailsPaneNotifier, bool, String>(
  (ref, sectionKey) => TableDetailsPaneNotifier(ref, sectionKey),
);
```

Default value is `false` (details pane hidden) for all sections.

The existing `showProfilePanelProvider` for Dives is unchanged. Mutual
exclusion is enforced by `TableModeLayout`: when Details toggles ON, it sets
profile panel to OFF, and vice versa.

#### Map Toggle

Unchanged. Continues to use URL query parameter `?view=map` managed by each
section's list page.

### 3. Section List Page/Content Migration

#### List Page Changes (`*_list_page.dart`)

Each section's list page currently always wraps content in
`MasterDetailScaffold`. The change:

```
if (viewMode == ListViewMode.table) {
  // Bypass MasterDetailScaffold, use TableModeLayout instead
  return TableModeLayout(
    sectionKey: '<section>',
    tableContent: <SectionListContent>(showAppBar: false),
    detailBuilder: (id) => <existing detail builder>,
    editBuilder: (id) => <existing edit builder>,
    // ... other existing builders
    mapBuilder: <if applicable>,
  );
}
// Non-table modes use MasterDetailScaffold as before
return MasterDetailScaffold(...);
```

#### List Content Changes (`*_list_content.dart`)

The `_buildTableModeScaffold()` method simplifies. It no longer needs to handle
the `showAppBar` true/false split or render its own Scaffold. It returns just
the table content (filter bars + EntityTableView). The layout chrome (app bar,
toggle buttons, split panes) is handled by `TableModeLayout`.

The column settings action is passed as an `appBarActions` parameter to
`TableModeLayout`.

### 4. Settings > Appearance Expansion

#### Entity-Aware Column Config Page

The existing `ColumnConfigPage` is expanded with a section selector at the top:

- **Dropdown or segmented control:** Dives | Sites | Buddies | Trips | Equipment | Dive Centers | Certifications | Courses
- Selecting a section shows its available view modes:
  - **Table tab:** Column order, visibility, pinning, presets (save/load/delete)
  - **Detailed tab:** Extra fields configuration
  - **Compact tab:** Slot field assignments (where applicable)

For Dives, this is the existing behavior unchanged. For other sections, the
table column config uses the existing `EntityTableViewConfig` providers. The
card view configs use the new `EntityCardViewConfig` model (see below).

#### Details Pane Toggle in Appearance

A new "Table View" group in the Appearance page, below the existing column
config entry:

```
Table View
  [Column & Field Configuration]  >   (existing, now entity-aware)
  [Show details pane by default]
    Dives         [toggle]
    Sites         [toggle]
    Buddies       [toggle]
    Trips         [toggle]
    Equipment     [toggle]
    Dive Centers  [toggle]
    Certifications [toggle]
    Courses       [toggle]
```

### 5. Generic Entity Card View Configuration

#### New Model: `EntityCardViewConfig<F>`

A generic version of the existing Dives-only `CardViewConfig`, at
`lib/shared/models/entity_card_view_config.dart`:

```dart
class EntityCardSlotConfig<F extends EntityField> extends Equatable {
  final String slotId;
  final F field;
  // copyWith, toJson, fromJson
}

class EntityCardViewConfig<F extends EntityField> extends Equatable {
  final List<EntityCardSlotConfig<F>> slots;
  final List<F> extraFields; // detailed mode only
  // copyWith, toJson, fromJson with fieldFromName resolver
}
```

Each entity type defines:
- Default slot assignments for its card views (detailed, compact where
  applicable)
- The set of available fields for configuration
- Stored per-diver in the settings repository, same pattern as existing Dive
  card config

#### Per-Section Card Config Providers

Each section gets providers following the existing Dives pattern:

```dart
final siteDetailedCardConfigProvider =
    StateNotifierProvider<EntityCardConfigNotifier<SiteField>,
        EntityCardViewConfig<SiteField>>(...);

final siteCompactCardConfigProvider =
    StateNotifierProvider<EntityCardConfigNotifier<SiteField>,
        EntityCardViewConfig<SiteField>>(...);
```

#### Sections and Their Card Modes

| Section | Detailed config | Compact config |
|---------|----------------|----------------|
| Sites | Yes (4 slots + extra fields) | Yes (4 slots) |
| Dive Centers | Yes (4 slots + extra fields) | Yes (4 slots) |
| Buddies | Yes (4 slots + extra fields) | Yes (4 slots) |
| Trips | Yes (4 slots + extra fields) | Yes (4 slots) |
| Equipment | Yes (4 slots + extra fields) | Yes (4 slots) |
| Certifications | Yes (4 slots + extra fields) | No (no compact mode) |
| Courses | Yes (4 slots + extra fields) | No (no compact mode) |

## Out of Scope / Unchanged

- **Mobile behavior:** No Details button on phones. Map toggle navigates to
  full-screen map as currently implemented.
- **Map toggle mechanism:** URL query params (`?view=map`), unchanged.
- **Existing Dives profile panel:** Behavior unchanged; just becomes mutually
  exclusive with the new Details toggle.
- **Existing Dives table mode full-width behavior:** Unchanged; `TableModeLayout`
  replaces the inline logic with the shared widget.
- **Card view rendering changes:** The list tile widgets themselves are not
  modified. Only their field configuration becomes user-customizable.

## Affected Files

### New Files
- `lib/shared/widgets/table_mode_layout/table_mode_layout.dart`
- `lib/shared/models/entity_card_view_config.dart`
- Per-section card config providers (in each section's providers file)

### Modified Files
- `lib/features/*/presentation/pages/*_list_page.dart` (all 8 sections)
- `lib/features/*/presentation/widgets/*_list_content.dart` (all 8 sections)
- `lib/features/settings/presentation/pages/column_config_page.dart`
- `lib/features/settings/presentation/pages/appearance_page.dart`
- `lib/features/settings/data/repositories/diver_settings_repository.dart`
- `lib/features/dive_log/presentation/widgets/dive_list_content.dart` (Details toggle + mutual exclusion with Profile)
- `lib/features/dive_log/presentation/pages/dive_list_page.dart` (route through TableModeLayout)
