# Table View & Customizable Columns Design

**Issue:** [submersion-app/submersion#56](https://github.com/submersion-app/submersion/issues/56)
**Date:** 2026-04-04
**Status:** Approved

## Summary

Add a table view mode to the dive log with user-selectable, sortable, reorderable, and resizable columns. Extend the existing card-based views (detailed, compact, dense) with customizable field content. Each view mode has its own independent field configuration, with support for user-defined presets.

## Motivation

Users coming from Subsurface expect a spreadsheet-style table showing planning-critical data (SAC rate, weights, gas config, water type) at a glance. The current card-based list shows fixed fields that don't match every diver's priorities. A table view with selectable columns gives power users the data density they need, while customizable card fields improve the existing views for everyone.

## Design Decisions

| Decision | Choice |
|----------|--------|
| Scope | Table view + customizable card fields |
| Field set | Every Dive entity field exposed as a selectable column |
| Config independence | Each view mode has its own independent config |
| Desktop table layout | Full-width, no detail pane |
| Mobile table layout | Horizontal scroll with pinned columns |
| Table interactions | Sort, reorder, resize, custom presets |
| Config UI access | Inline gear icon in table + Settings page |
| Settings location | Settings > Appearance > Dive List > Column Configuration |
| Detailed card | Fixed top area + configurable extra fields grid |
| Compact/Dense cards | Fixed layout with selectable slot content |
| Field identification | Icon where available, short label fallback |
| Table implementation | Custom Flutter widget from primitives |
| Data loading | No new DB queries; computed fields from existing batch data |
| Built-in presets | Standard, Technical, Planning |

## 1. Field Definition System

### DiveFieldCategory

Groups fields in the column picker UI for discoverability.

```dart
enum DiveFieldCategory {
  core,        // #, date, site, depth, duration
  environment, // water temp, air temp, visibility, current, water type
  gas,         // O2%, He%, gas name, MOD, END
  tank,        // volume, start/end pressure, SAC, gas consumed
  weight,      // total weight, weight breakdown
  equipment,   // suit, computer, gear items
  deco,        // GF low/high, algorithm, NDL, ceiling
  physiology,  // CNS, OTU, heart rate
  rebreather,  // dive mode, setpoints, diluent, loop O2
  people,      // buddy, dive master
  location,    // site name, GPS, altitude, dive center
  trip,        // trip name
  rating,      // stars, favorite
  metadata,    // notes, tags, custom fields, import source
}
```

### DiveField Enum

Every possible column/field. Each value carries metadata via extension getters:

| Property | Type | Purpose |
|----------|------|---------|
| `label` | `String Function(AppLocalizations)` | Full localized display name (table headers, settings UI, detailed card labels) |
| `shortLabel` | `String` | Abbreviated text for compact/dense fallback (e.g. "SAC", "GFL", "CNS") |
| `icon` | `IconData?` | Material icon for compact/dense primary display; null triggers shortLabel fallback |
| `category` | `DiveFieldCategory` | Grouping in column picker |
| `defaultWidth` | `double` | Default column width in pixels for the table |
| `minWidth` | `double` | Minimum resize width |
| `sortable` | `bool` | Whether the table can sort by this field |
| `valueExtractor` | `dynamic Function(Dive)` | Pulls the raw value from a Dive |
| `formatter` | `String Function(dynamic, UnitFormatter)` | Formats for display with unit awareness |

Fields include all direct Dive entity properties plus computed fields:

**Computed fields (derived from already-loaded data):**

| Field | Computation | Data Source |
|-------|-------------|-------------|
| SAC rate | `(startP - endP) * tankVol / runtime / (avgDepth/10 + 1)` | Tanks + avgDepth + runtime |
| Gas consumed | `(startP - endP) * tankVol` | Tanks |
| Total weight | Sum of all DiveWeight entries | `dive.totalWeight` getter |
| Primary gas | Formatted name of first tank's gas mix | `dive.tanks.first.gasMix` |
| Surface interval | Time delta from previous dive's exit | Sorted dive list (see note below) |

**Special case -- Surface interval:** This field requires the sorted dive list, not just the current dive. The `valueExtractor` signature `Dive -> dynamic` doesn't cover this. Implementation should pre-compute surface intervals when the dive list is loaded/sorted and attach them as a `Map<String, Duration?>` (dive ID to interval) passed alongside the dive list to the table widget. The `valueExtractor` for this field would look up the pre-computed map rather than deriving from the Dive object alone.

Adding a new field in the future requires only adding an enum value and its metadata -- no widget changes.

**Field identification in compact/dense card slots:**
- If the field has a recognized Material icon: show `icon + value`
- If no icon exists: show `shortLabel: value` as text prefix

Examples with icons: depth (`arrow_downward`), duration (`timer`), temperature (`thermostat`), weight (`fitness_center`), visibility (`visibility`), buddy (`person`), rating (`star`).

Examples with short labels: SAC rate ("SAC"), GF Low ("GFL"), CNS% ("CNS"), O2% ("O2"), water type ("Water").

## 2. Configuration Model

### Table View Config

```dart
class TableColumnConfig {
  final DiveField field;
  final double width;       // User-resized or default
  final bool isPinned;      // Frozen on left during horizontal scroll
  // Column position is defined by index in the parent list (no separate sortIndex)
}

class TableViewConfig {
  final List<TableColumnConfig> columns;  // Visible columns in order
  final DiveField? sortField;             // Current sort column
  final bool sortAscending;               // Sort direction
}
```

### Card View Configs

```dart
// Compact & Dense: fixed layout slots with selectable content
class CardSlotConfig {
  final String slotId;      // e.g. "subtitle", "stat1", "stat2"
  final DiveField field;    // What data fills this slot
}

class CardViewConfig {
  final ListViewMode mode;           // detailed, compact, or dense
  final List<CardSlotConfig> slots;  // For compact/dense: slot assignments
  final List<DiveField> extraFields; // For detailed only: flexible area fields
}
```

### Presets

```dart
class FieldPreset {
  final String id;
  final String name;            // User-defined, e.g. "Tech Diving", "Travel Log"
  final ListViewMode viewMode;  // Which view mode this preset is for
  final Map<String, dynamic> config;  // Serialized config
  final bool isBuiltIn;         // System defaults can't be deleted
}
```

### Storage

New Drift tables:

| Table | Columns | Purpose |
|-------|---------|---------|
| `view_configs` | `id`, `diver_id`, `view_mode`, `config_json`, `updated_at` | One row per (diver, view_mode) -- the active configuration |
| `field_presets` | `id`, `diver_id`, `view_mode`, `name`, `config_json`, `is_built_in`, `created_at` | Named presets per (diver, view_mode) |

Configs are per-diver so switching divers loads their personalized layouts.

**Persistence flow:**
1. User changes columns/presets -> updates `ViewFieldConfig` in memory via `StateNotifier`
2. Notifier writes to Drift DB (debounced for resize drag events)
3. On app start, active config loaded from DB per diver
4. Switching divers reloads that diver's config

### Built-in Presets

Shipped with the app (cannot be deleted, can be duplicated):

| Preset | View Mode | Columns/Fields |
|--------|-----------|----------------|
| Standard | table | #, date, site, max depth, duration, water temp |
| Technical | table | #, date, site, max depth, duration, GF, deco algorithm, CNS, gas mix, SAC |
| Planning | table | #, date, site, max depth, SAC, total weight, water type, tanks, gas config |

Card view modes ship with sensible defaults matching today's layout (no visible change on upgrade).

## 3. Table View Widget Architecture

### Widget Tree

```
DiveTableView
+-- TableHeader (sticky at top)
|   +-- PinnedHeaderCells (fixed left, not horizontally scrollable)
|   |   e.g. [#] [Site Name]
|   +-- ScrollableHeaderCells (linked to horizontal scroll controller)
|       e.g. [Date] [Depth] [Duration] [SAC] [Weight] ...
|       +-- GestureDetector per cell (tap -> sort, long-press -> column menu)
|       +-- ResizeHandle per cell (drag -> adjust width)
|
+-- TableBody (vertical ListView.builder)
|   +-- TableRow (per dive)
|       +-- PinnedCells (fixed left, same widths as pinned headers)
|       +-- ScrollableCells (linked to SAME horizontal scroll controller)
|
+-- TableToolbar (top-right overlay)
    +-- GearIcon -> opens quick column picker
```

### Scroll Synchronization

One `ScrollController` shared between the header's scrollable section and every row's scrollable section via a `LinkedScrollControllerGroup`. All columns stay aligned during horizontal scroll.

### Pinned Columns

Default: dive number + site name. User can pin/unpin via column header context menu. Pinned section uses a fixed-width `Row` outside the horizontal scroll area.

### Sorting

Tap a header to cycle: unsorted -> ascending -> descending. One sort column active at a time. Sorting happens on the already-loaded `List<Dive>` in a provider, not at the DB level. Table header sort and the existing sort provider stay in sync.

### Column Resize

`GestureDetector` on the right edge of each header cell. Horizontal drag updates the column's `width` in config. Minimum width enforced per `DiveField.minWidth`.

### Column Reorder

Long-press + drag a header cell to reposition. Updates column order in config. Reorder only within scrollable columns; pinned columns stay put.

### Row Interaction

- **Tap** -> navigates to `DiveDetailPage` via `context.push('/dives/$id')`
- **Long-press** -> enters multi-select mode with checkboxes (same as current card behavior)
- **Row height** -> fixed, compact (~36-40px) for maximum density

### Mobile Considerations

Same widget, same code path. No `ResponsiveBreakpoints` check to switch implementations.
- Pinned columns take ~100px; rest scrolls horizontally
- Touch-friendly resize handles: 24px hit target on mobile (vs 8px on desktop)
- Column reorder via long-press + drag works naturally with touch

## 4. Card View Customization

### Detailed View (DiveListTile) -- Hybrid

Fixed top area (unchanged):
- Dive number badge, site name, location, date, mini profile chart, rating, favorite

Configurable extra fields area (new):
- Renders below the fixed area as a 2-column grid of `label: value` pairs
- 0 extra fields selected = card looks exactly like today (no breaking change)
- Order matches user's configured order
- On narrow screens, grid collapses to 1 column

### Compact View (CompactDiveListTile) -- Slot-based

Fixed structure, selectable content per slot:

| Slot | Default | User Can Change To |
|------|---------|-------------------|
| `title` | Site name | Any text field |
| `date` | Date/time | Any field |
| `stat1` | Max depth (with icon) | Any field (icon or shortLabel) |
| `stat2` | Duration (with icon) | Any field (icon or shortLabel) |

Dive number remains fixed (not a configurable slot).

### Dense View (DenseDiveListTile) -- Slot-based

Single row, same approach:

| Slot | Default |
|------|---------|
| `slot1` | Site name |
| `slot2` | Date |
| `slot3` | Max depth |
| `slot4` | Duration |

Dive number remains fixed.

## 5. Configuration UI

### Inline Table Gear Icon

Small gear icon in the top-right corner of the table header row. Opens:
- **Bottom sheet** (mobile) or **popover menu** (desktop)
- Checklist of all fields grouped by `DiveFieldCategory`, toggling visibility
- Dropdown to switch between saved presets
- "Manage Presets" link to jump to full settings page

### Settings Page

Located at `Settings > Appearance > Dive List > Column Configuration`.

**View mode selector** at top (dropdown or tabs): Table, Detailed, Compact, Dense.

**Table mode configuration:**
- **Preset bar:** dropdown to switch presets, [Save], [Save As], [Delete]. Built-in presets can be duplicated but not deleted.
- **Visible columns list:** drag-to-reorder with grip handles. Each row shows field name + pin toggle (table only). Swipe-to-remove or tap minus to hide.
- **Available fields:** grouped by `DiveFieldCategory`. Tap [+] to add to visible list.
- **[Reset to Default]** button.

**Compact/Dense mode configuration:**
- Slot assignments: list of slots with dropdowns to pick which `DiveField` fills each slot.
- **[Reset to Default]** button.

**Detailed mode configuration:**
- Same slot assignments for the fixed area.
- Drag-to-reorder list of extra fields for the flexible area (same UI pattern as table's visible columns).
- **[Reset to Default]** button.

## 6. Integration with Existing Systems

### ListViewMode Extension

```dart
enum ListViewMode {
  detailed,
  compact,
  dense,
  table,  // new
}
```

`ListViewModeToggle` widget gets a 4th icon (`Icons.table_chart` or `Icons.grid_on`).

### DiveListContent Changes

- When `viewMode == table`, renders `DiveTableView` instead of `ListView.builder` with tile widgets
- On desktop in table mode, `DiveListPage` skips `MasterDetailScaffold` and renders `DiveTableView` full-width (no detail pane). Other 3 modes continue using master-detail on desktop.
- Row tap navigates via `context.push('/dives/$id')` on all platforms

### Existing Features (Unchanged)

| Feature | Behavior in Table Mode |
|---------|----------------------|
| Search | Filters dive list; table renders filtered results |
| Filters | `DiveFilterState` applies; table shows filtered dives |
| Sort | Existing sort bottom sheet syncs with table header sort |
| Multi-select | Long-press row enters selection mode with checkboxes |
| Map view | Mutually exclusive with table; toggling switches between them |
| Export | Selection-based export operates on `Dive` objects, view-agnostic |
| Card coloring | Not applied to table rows initially (plain rows); possible follow-up |

### Navigation

- New settings page at `Settings > Appearance > Dive List > Column Configuration`
- No new routes for the table (view mode within existing `/dives` route)

## 7. Data Loading

No changes to the data loading strategy. All fields used in the table and card customization are available from data already batch-loaded by `DiveRepository.getAllDives()`:

- Direct Dive entity properties
- Nested relations: site, dive center, trip (batch-loaded via joins)
- Tanks, equipment, tags, custom fields (batch-loaded)
- Computed values: SAC rate, gas consumed, total weight (calculated from loaded data)

Profile data remains lazy-loaded (detail page only). No new DB queries for list rendering.

Performance: `valueExtractor` and `formatter` functions run per-cell, per-visible-row. `ListView.builder` only builds visible rows, so this stays fast with hundreds of dives and many columns.

## Out of Scope

- Column drag-resize on card views (cards use fixed layouts)
- Card color attribute applied to table rows (follow-up)
- Resizable master-detail split pane (separate feature request)
- Custom field types beyond key-value strings
