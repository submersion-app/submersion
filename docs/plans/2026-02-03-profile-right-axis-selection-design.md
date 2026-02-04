# Dive Profile Right Y-Axis Selection

## Overview

Add the ability to dynamically select which metric is displayed on the right Y-axis of the dive profile chart, with configurable defaults in Settings.

## Requirements

1. Users can tap the right Y-axis label to select a different metric
2. Settings provides default visibility controls for all chart metrics
3. Smart fallback chain when selected metric has no data

## Data Model

### New Enum: ProfileRightAxisMetric

```dart
enum ProfileRightAxisMetric {
  temperature('Temperature'),
  pressure('Pressure'),
  heartRate('Heart Rate'),
  sac('SAC Rate'),
  ndl('NDL'),
  ppO2('ppO2'),
  ppN2('ppN2'),
  ppHe('ppHe'),
  gasDensity('Gas Density'),
  gf('GF%'),
  surfaceGf('Surface GF'),
  tts('TTS');

  final String displayName;
  const ProfileRightAxisMetric(this.displayName);
}
```

### Settings Fields

#### Right Y-Axis Default
- `defaultRightAxisMetric: ProfileRightAxisMetric` (default: `temperature`)

#### Primary Metrics Defaults
- `defaultShowTemperature: bool` (default: `true`)
- `defaultShowPressure: bool` (default: `false`)
- `defaultShowHeartRate: bool` (default: `false`)
- `defaultShowSac: bool` (default: `false`)

#### Decompression Defaults
- `defaultShowCeiling: bool` (default: `true`)
- `defaultShowAscentRateColors: bool` (default: `true`)
- `defaultShowNdl: bool` (default: `false`)
- `defaultShowEvents: bool` (default: `true`)

#### Gas Analysis Defaults
- `defaultShowPpO2: bool` (default: `false`)
- `defaultShowPpN2: bool` (default: `false`)
- `defaultShowPpHe: bool` (default: `false`)
- `defaultShowGasDensity: bool` (default: `false`)

#### Gradient Factor Defaults
- `defaultShowGf: bool` (default: `false`)
- `defaultShowSurfaceGf: bool` (default: `false`)

#### Other Metrics Defaults
- `defaultShowMeanDepth: bool` (default: `false`)
- `defaultShowTts: bool` (default: `false`)

#### Marker Defaults
- `defaultShowMaxDepthMarker: bool` (default: `true`) - already exists as `showMaxDepthMarker`
- `defaultShowPressureMarkers: bool` (default: `false`) - already exists as `showPressureThresholdMarkers`
- `defaultShowGasSwitchMarkers: bool` (default: `true`)

## Fallback Priority Chain

When the selected metric has no data, fall back in this order:

```
User's selection -> Temperature -> Pressure -> Heart Rate -> SAC -> NDL -> ppO2 -> Hide
```

## Chart Interaction

### Tap Axis Label Behavior

Tapping the right Y-axis area opens a popup menu:

- Shows all metrics grouped by category
- Current selection is highlighted
- Metrics without data are disabled/grayed
- "None" option to hide the axis entirely
- Selection is session-only (doesn't change global default)

### Touch Target

The right axis label area plus padding becomes tappable. Subtle visual hint (dropdown indicator or link styling) aids discoverability.

## Settings UI

Located in: **Appearance > Dive Profile**

```
Dive Profile Defaults
+-- Right Y-Axis Metric: [Temperature v]
+-- Primary Metrics
|   +-- Temperature [x]
|   +-- Pressure [ ]
|   +-- Heart Rate [ ]
|   +-- SAC Rate [ ]
+-- Decompression
|   +-- Ceiling [x]
|   +-- Ascent Rate Colors [x]
|   +-- NDL [ ]
|   +-- Events [x]
+-- Gas Analysis
|   +-- ppO2 [ ]
|   +-- ppN2 [ ]
|   +-- ppHe [ ]
|   +-- Gas Density [ ]
+-- Gradient Factors
|   +-- GF% [ ]
|   +-- Surface GF [ ]
+-- Other
|   +-- Mean Depth [ ]
|   +-- TTS [ ]
+-- Markers
    +-- Max Depth [x]
    +-- Pressure Thresholds [ ]
    +-- Gas Switches [x]
```

## Files to Modify

### New Files
| File | Purpose |
|------|---------|
| `lib/core/constants/profile_metrics.dart` | `ProfileRightAxisMetric` enum |

### Modified Files
| File | Changes |
|------|---------|
| `lib/features/settings/presentation/providers/settings_providers.dart` | Add default metric fields, setters, providers |
| `lib/features/settings/data/repositories/diver_settings_repository.dart` | Persist new settings |
| `lib/features/dive_log/presentation/providers/profile_legend_provider.dart` | Add `rightAxisMetric`, initialize from settings |
| `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` | Dynamic right axis, tap handler |
| `lib/features/dive_log/presentation/widgets/dive_profile_legend.dart` | Initialize from settings defaults |
| `lib/features/settings/presentation/pages/settings_page.dart` | Dive Profile defaults section |
| Database schema | New columns for settings |

## Implementation Order

1. Create `ProfileRightAxisMetric` enum with metadata
2. Add settings fields to `AppSettings` and `SettingsNotifier`
3. Update diver settings repository for persistence
4. Update `ProfileLegendProvider` to initialize from settings
5. Implement dynamic right Y-axis in chart widget
6. Add tap-to-select popup on axis
7. Build Settings UI for Dive Profile defaults

## Design Decisions

- **Session-only chart changes**: Changing the right axis on a chart doesn't persist - it's for quick exploration. The default comes from Settings.
- **Smart fallback**: Ensures users always see useful data rather than an empty axis.
- **Grouped settings UI**: Categories match the chart's "More options" menu for consistency.
- **Existing marker settings**: `showMaxDepthMarker` and `showPressureThresholdMarkers` already exist - we'll reuse them rather than duplicate.
