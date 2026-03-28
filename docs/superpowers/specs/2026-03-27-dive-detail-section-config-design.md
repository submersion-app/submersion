# Dive Detail Section Configuration

Customizable visibility and ordering of sections on the Dive Details page, managed through a drag-and-drop interface in Settings > Appearance.

## Context

The Dive Details page displays ~20 sections of information (deco status, SAC rates, environment, tanks, buddies, etc.) in a fixed hardcoded order. Users have no control over which sections appear or their display order. Different divers care about different data — a recreational diver may not need tissue loading or altitude, while a tech diver wants deco status front and center.

## Requirements

### Configurable Sections

Two sections are **fixed** (always visible, always at the top):
1. Header (dive number, date/time, type, duration, depth, favorite)
2. Dive Profile Chart (interactive depth/temp chart, playback controls)

The remaining 17 sections are **configurable** (visibility toggle + reorderable):

| ID | Display Name | Description |
|----|-------------|-------------|
| `decoO2` | Deco Status / Tissue Loading | NDL, ceiling, tissue heat map, O2 toxicity |
| `sacSegments` | SAC Rate by Segment | Phase/time segmentation, cylinder breakdown |
| `details` | Details | Type, location, trip, dive center, interval |
| `environment` | Environment | Air/water temp, visibility, current |
| `altitude` | Altitude | Altitude value, category, deco requirement |
| `tide` | Tide | Tide cycle graph and timing |
| `weights` | Weights | Weight breakdown, total weight |
| `tanks` | Tanks | Tank list, gas mixes, pressures, per-tank SAC |
| `buddies` | Buddies | Buddy list with roles |
| `signatures` | Signatures | Buddy/instructor signature display and capture |
| `equipment` | Equipment | Equipment used in dive |
| `sightings` | Marine Life Sightings | Species spotted, sighting details |
| `media` | Media | Photos/videos gallery |
| `tags` | Tags | Dive tags |
| `notes` | Notes | Dive notes/description |
| `customFields` | Custom Fields | User-defined custom fields |
| `dataSources` | Data Sources | Connected dive computers, source management |

### Visibility Behavior

- User preferences control the **maximum** visible set
- Existing data-driven auto-hide logic is preserved: even if a section is enabled, it still hides when the dive has no data for it (e.g., Tanks hides when `dive.tanks.isEmpty`)
- This means: user config is a filter on top of data availability, not an override

### Defaults

- All 17 configurable sections are **visible** by default
- Default order matches the current hardcoded order (as listed in the table above)
- Existing users see zero change until they explicitly customize

### Per-Diver Settings

- Section configuration is **per-diver**, consistent with all other settings
- Each diver profile maintains its own section order and visibility preferences

## Data Model

### DiveDetailSectionId Enum

```dart
enum DiveDetailSectionId {
  decoO2,
  sacSegments,
  details,
  environment,
  altitude,
  tide,
  weights,
  tanks,
  buddies,
  signatures,
  equipment,
  sightings,
  media,
  tags,
  notes,
  customFields,
  dataSources,
}
```

### DiveDetailSectionConfig

```dart
class DiveDetailSectionConfig {
  final DiveDetailSectionId id;
  final bool visible;

  const DiveDetailSectionConfig({
    required this.id,
    required this.visible,
  });
}
```

Array position determines display order. No explicit `order` field needed.

### Default Configuration

A static default list used when no custom config exists:

```dart
static const List<DiveDetailSectionConfig> defaultSections = [
  DiveDetailSectionConfig(id: DiveDetailSectionId.decoO2, visible: true),
  DiveDetailSectionConfig(id: DiveDetailSectionId.sacSegments, visible: true),
  // ... all 17, visible: true, in the order above
];
```

## Storage

### Database Column

Add a nullable `TEXT` column `diveDetailSections` to the existing `diver_settings` table.

- `null` means "use defaults" — no data backfill required for existing divers
- Column is only populated once a user customizes their layout

### Migration

Single `addColumn` operation:

```dart
await m.addColumn(diverSettings, diverSettings.diveDetailSections);
```

### TypeConverter

A Drift `TypeConverter<List<DiveDetailSectionConfig>, String>` handles JSON serialization:

```json
[
  {"id": "decoO2", "visible": true},
  {"id": "sacSegments", "visible": true},
  {"id": "details", "visible": false}
]
```

### New Section Handling

When deserializing, if a `DiveDetailSectionId` exists in the enum but is missing from the user's saved JSON (added in a future release), the app appends it to the end of the list with `visible: true`. New sections surface automatically without a migration.

## Settings Integration

### AppSettings

New field:

```dart
final List<DiveDetailSectionConfig> diveDetailSections;
```

Defaults to `DiveDetailSectionConfig.defaultSections` when the database column is null.

### SettingsNotifier

Two new methods:

- `setDiveDetailSections(List<DiveDetailSectionConfig>)` — persists the full ordered list after any reorder or toggle
- `resetDiveDetailSections()` — sets the column back to null, restoring defaults

### DiverSettingsRepository

Handles the new column through existing `getSettingsForDiver` / `updateSettingsForDiver` flow. The TypeConverter makes this transparent.

## Settings UI

### Appearance Page Addition

A new **"Dive Details"** section in the Appearance page, placed between the existing "Dive Profile" and "Dive Sites (Map)" sections.

Contains a single navigation tile: **"Section Order & Visibility"** that routes to `/settings/dive-detail-sections`.

### DiveDetailSectionsPage

New sub-page at route `/settings/dive-detail-sections`.

**Layout:**
- A note at the top: "Fixed sections: Header, Dive Profile Chart"
- A subheading: "Configurable sections (drag to reorder)"
- A `ReorderableListView` with one row per configurable section

**Each row contains:**
- Drag handle (left) — for reordering
- Section name + short description (center)
- Visibility toggle switch (right)

**Disabled section styling:**
- Rows with visibility toggled off are dimmed (reduced opacity) but remain in the list at their current position, so users can see where they'd appear if re-enabled

**App bar:**
- Title: "Section Order & Visibility"
- Overflow menu with "Reset to Default" action

**Persistence:**
- Changes persist immediately on each reorder or toggle via `settingsNotifier.setDiveDetailSections()`
- No "Save" button needed — consistent with how all other Appearance settings work (immediate apply)

## Dive Detail Page Integration

### Section Builder Extraction

Each of the 17 configurable sections gets a dedicated builder method returning `Widget?`:

```dart
Widget? _buildDecoO2Section(DiveAggregate dive) { ... }
Widget? _buildSacSegmentsSection(DiveAggregate dive) { ... }
// etc.
```

Returns `null` when the section's data-driven auto-hide condition is met (preserving current behavior).

### Section Registry

A map from section ID to builder:

```dart
Map<DiveDetailSectionId, Widget? Function()> get _sectionBuilders => {
  DiveDetailSectionId.decoO2: () => _buildDecoO2Section(dive),
  DiveDetailSectionId.sacSegments: () => _buildSacSegmentsSection(dive),
  // ... all 17
};
```

### Render Loop

`_buildContent()` renders fixed sections first, then iterates over the user's config:

```dart
// Fixed sections
_buildHeader(dive),
_buildProfileSection(dive),
// Configurable sections in user-defined order
for (final section in settings.diveDetailSections)
  if (section.visible)
    _sectionBuilders[section.id]?.call(),
```

Null results from builders are filtered out by Flutter's standard null-aware list spreading.

### Scope of Change

This refactor extracts inline section code into named methods and replaces the hardcoded section order with a config-driven loop. It does **not**:
- Break the page into separate widget files
- Change the widget tree structure within each section
- Alter any section's internal rendering logic
- Modify the existing data-driven visibility conditions

## Testing

- **Unit tests:** TypeConverter round-trip serialization, new-section-detection logic, default config generation
- **Unit tests:** SettingsNotifier methods for set/reset of section config
- **Widget tests:** DiveDetailSectionsPage renders all 17 sections, reorder updates state, toggle updates visibility
- **Widget tests:** Dive detail page renders sections in configured order, respects visibility settings, falls back to defaults when config is null
- **Integration test:** End-to-end flow from settings page reorder through to dive detail page rendering in new order
