# Card Coloring Enhancement Design

## Overview

Replace the current boolean "Depth-colored dive cards" toggle with a flexible system that allows users to color dive cards by any numeric attribute (depth, duration, temperature, OTU, max ppO2) using customizable color gradients (curated presets + custom two-color picker).

## Requirements

- Color dive cards by: Depth, Duration, Temperature, OTU, Max ppO2
- Provide 5 curated gradient presets + custom two-color option
- Migrate existing users (depth coloring ON -> attribute=depth, gradient=ocean)
- Add OTU and Max ppO2 to DiveSummary for efficient list rendering
- Maintain backward compatibility with existing settings and sync format

## Data Model

### New enum: CardColorAttribute

```dart
enum CardColorAttribute {
  none,        // No coloring (plain cards)
  depth,       // Max depth
  duration,    // Bottom time
  temperature, // Water temperature
  otu,         // Oxygen Toxicity Units
  maxPpO2,     // Maximum ppO2 from profile data
}
```

### New class: CardColorGradient

```dart
class CardColorGradient {
  final String name;
  final Color startColor; // Low value color
  final Color endColor;   // High value color
}
```

### Gradient presets

| Preset | Start (low) | End (high) | Description |
|--------|------------|-----------|-------------|
| Ocean | #4DD0E1 turquoise | #0D1B2A deep navy | Current default |
| Thermal | #2196F3 cool blue | #F44336 hot red | Cold-to-hot |
| Sunset | #FFC107 gold | #7B1FA2 deep purple | Warm-to-dramatic |
| Forest | #81C784 light green | #1B5E20 dark green | Natural range |
| Monochrome | #B0BEC5 light grey | #263238 charcoal | Subtle, works in any theme |

### AppSettings changes

Replace `showDepthColoredDiveCards: bool` with:

- `cardColorAttribute: CardColorAttribute` (default: `none`)
- `cardColorGradientPreset: String` (default: `'ocean'`)
- `cardColorGradientStart: int?` (ARGB int, null when using preset)
- `cardColorGradientEnd: int?` (ARGB int, null when using preset)

Add computed getter for backward compat:

```dart
bool get showDepthColoredDiveCards => cardColorAttribute != CardColorAttribute.none;
```

### DiveSummary additions

- `otu: double?` -- from `dives.otu` column (already in database)
- `maxPpO2: double?` -- subquery: `SELECT MAX(pp_o2) FROM dive_profiles WHERE dive_id = ?`

## Settings UI

### Appearance page changes

Replace the single SwitchListTile with two controls under the "Dive Log" section:

1. **"Color cards by"** -- ListTile with trailing DropdownButton
   - Options: None, Depth, Duration, Temperature, OTU, Max ppO2
   - When None is selected, the gradient selector is hidden

2. **"Color gradient"** -- Horizontal scrollable row of gradient swatch cards
   - Each swatch is ~60x40 showing a mini gradient preview
   - Selected swatch has a checkmark overlay
   - Final item is "Custom" which opens a two-color picker dialog

### Custom gradient dialog

- Two color wells (start + end) with standard color picker
- Live preview gradient bar between them
- Cancel / Apply buttons

## Card Rendering

### Value extraction

```dart
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
```

### Range computation (in list builders)

```dart
final attribute = settings.cardColorAttribute;
final values = dives
    .map((d) => getCardColorValue(d, attribute))
    .whereType<double>();
final minValue = values.isEmpty ? null : values.reduce(min);
final maxValue = values.isEmpty ? null : values.reduce(max);
```

### Color calculation (in DiveListTile)

```dart
Color? _getAttributeBackgroundColor() {
  // get value, normalize to 0.0-1.0, Color.lerp(start, end, normalized)
}
```

### Data flow

```
Settings (attribute + gradient)
        |
        v
DiveListContent / RecentDivesCard
  - reads cardColorAttribute from settingsProvider
  - computes min/max VALUE range across visible dives
  - passes (minValue, maxValue, gradientStart, gradientEnd) to each tile
        |
        v
DiveListTile._getAttributeBackgroundColor()
  - extracts this dive's value for the active attribute
  - normalizes to 0.0-1.0
  - Color.lerp(gradientStart, gradientEnd, normalized)
```

## Database Migration

### New columns on diver_settings

```sql
ALTER TABLE diver_settings ADD COLUMN card_color_attribute TEXT NOT NULL DEFAULT 'none';
ALTER TABLE diver_settings ADD COLUMN card_color_gradient_preset TEXT NOT NULL DEFAULT 'ocean';
ALTER TABLE diver_settings ADD COLUMN card_color_gradient_start INTEGER NULL;
ALTER TABLE diver_settings ADD COLUMN card_color_gradient_end INTEGER NULL;
```

### Data migration

```sql
UPDATE diver_settings
SET card_color_attribute = 'depth'
WHERE show_depth_colored_dive_cards = 1;
```

The old `show_depth_colored_dive_cards` column is left in place (SQLite limitations) but code stops reading it.

## Backward Compatibility

- `showDepthColoredDiveCards` becomes a computed getter on AppSettings
- `showDepthColoredDiveCardsProvider` continues to work via the getter
- Sync serializer reads old `showDepthColoredDiveCards` key during import for older export files
- New fields are serialized alongside old field for forward/backward compat

## Files to Create/Modify

| File | Action |
|------|--------|
| `lib/core/constants/card_color.dart` | NEW - enum, gradient class, presets, value extractor |
| `lib/features/settings/presentation/providers/settings_providers.dart` | MODIFY - new fields, copyWith, setters |
| `lib/features/settings/data/repositories/diver_settings_repository.dart` | MODIFY - map new columns |
| `lib/core/database/database.dart` | MODIFY - add columns, migration |
| `lib/features/settings/presentation/pages/appearance_page.dart` | MODIFY - replace toggle with dropdown + gradient picker |
| `lib/features/settings/presentation/widgets/gradient_preset_picker.dart` | NEW - horizontal gradient swatch widget |
| `lib/features/settings/presentation/widgets/custom_gradient_dialog.dart` | NEW - two-color picker dialog |
| `lib/features/dive_log/domain/entities/dive_summary.dart` | MODIFY - add otu, maxPpO2 |
| `lib/features/dive_log/data/repositories/dive_repository.dart` | MODIFY - add OTU + ppO2 subquery |
| `lib/features/dive_log/presentation/pages/dive_list_page.dart` | MODIFY - generalize DiveListTile coloring |
| `lib/features/dive_log/presentation/widgets/dive_list_content.dart` | MODIFY - generalize range computation |
| `lib/features/dashboard/presentation/widgets/recent_dives_card.dart` | MODIFY - same generalization |
| `lib/core/services/sync/sync_data_serializer.dart` | MODIFY - serialize new fields |
| 10 ARB files | MODIFY - add new l10n keys |

## Testing Plan

1. Unit tests for CardColorAttribute value extraction (all 5 attributes + none)
2. Unit tests for gradient presets (verify all 5 return valid Color pairs)
3. Unit tests for normalization + Color.lerp with edge cases (all same value, single dive, null values)
4. Unit tests for migration logic (existing users with depth coloring ON/OFF)
5. Widget tests for the new appearance page controls (attribute dropdown, gradient selector)
6. Integration test for settings round-trip: set attribute+gradient, verify card renders correctly
7. Existing settings tests should still pass (backward compat getter)
