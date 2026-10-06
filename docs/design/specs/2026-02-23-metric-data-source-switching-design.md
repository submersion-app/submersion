# Metric Data Source Switching

## Problem

When a dive computer provides per-sample data for NDL, ceiling, TTS, and CNS, the app silently overlays it onto calculated curves via `overlayComputerDecoData`. The user has no way to know which source they're viewing, no way to switch between sources per metric, and no way to compare the dive computer's algorithms against the app's Buhlmann calculations.

## Solution

Add a per-metric data source preference system. Each of the four computer-capable metrics (NDL, ceiling, TTS, CNS) gets an independent source selector: "Dive Computer" or "Calculated". Global defaults persist in settings; per-dive overrides live in the profile legend (session-only). The legend badge shows the active source, with a fallback indicator when computer data is preferred but unavailable.

## MetricDataSource Enum

```dart
enum MetricDataSource {
  computer,   // Prefer dive-computer-reported data
  calculated, // Always use app-calculated data
}
```text
Placed in `lib/core/constants/profile_metrics.dart` alongside existing metric enums.

## Data Model

### ProfileLegendState

New fields for the four computer-capable metrics:

```dart
final MetricDataSource ndlSource;
final MetricDataSource ceilingSource;
final MetricDataSource ttsSource;
final MetricDataSource cnsSource;
```text
Default: `MetricDataSource.calculated` (preserves current behavior).

### AppSettings

Matching persistent fields:

```dart
final MetricDataSource defaultNdlSource;
final MetricDataSource defaultCeilingSource;
final MetricDataSource defaultTtsSource;
final MetricDataSource defaultCnsSource;
```text
### Database Migration (v42)

Four new integer columns on `DiverSettings`:

```sql
ALTER TABLE diver_settings ADD COLUMN default_ndl_source INTEGER NOT NULL DEFAULT 1;
ALTER TABLE diver_settings ADD COLUMN default_ceiling_source INTEGER NOT NULL DEFAULT 1;
ALTER TABLE diver_settings ADD COLUMN default_tts_source INTEGER NOT NULL DEFAULT 1;
ALTER TABLE diver_settings ADD COLUMN default_cns_source INTEGER NOT NULL DEFAULT 1;
```text
Values: 0 = computer, 1 = calculated.

Migrate existing CNS toggle:

```sql
UPDATE diver_settings SET default_cns_source = 0 WHERE use_dive_computer_cns_data = 1;
```text
The `use_dive_computer_cns_data` column is left in place (SQLite compat) but no longer read.

### Replaces useDiveComputerCnsData

The `useDiveComputerCnsData` boolean, `useDiveComputerCnsDataProvider`, `setUseDiveComputerCnsData` setter, and the UI toggle are all removed. CNS source selection becomes part of this unified system. Consumers switch from `useDiveComputerCnsDataProvider` to checking `cnsSource == MetricDataSource.computer`.

## Overlay Mechanism

### overlayComputerDecoData Signature Change

```dart
(ProfileAnalysis, MetricSourceInfo) overlayComputerDecoData(
  ProfileAnalysis analysis,
  List<DiveProfilePoint> profile, {
  MetricDataSource ndlSource = MetricDataSource.calculated,
  MetricDataSource ceilingSource = MetricDataSource.calculated,
  MetricDataSource ttsSource = MetricDataSource.calculated,
  MetricDataSource cnsSource = MetricDataSource.calculated,
})
```text
Per-metric logic: Only overlay computer data when `source == MetricDataSource.computer` AND the profile has that computer data. Falls back to calculated curve otherwise.

### MetricSourceInfo

Returned alongside the analysis to communicate which source was actually used:

```dart
typedef MetricSourceInfo = ({
  MetricDataSource ndlActual,
  MetricDataSource ceilingActual,
  MetricDataSource ttsActual,
  MetricDataSource cnsActual,
});
```text
If `ndlSource == computer` but no computer NDL data exists, `ndlActual == calculated` (fallback).

### CNS Special Case

When `cnsSource == MetricDataSource.computer`:

1. `extractComputerCns` derives cnsStart/cnsEnd from first/last profile samples
2. `_computeResidualCns` short-circuits at dives with computer CNS
3. `o2Exposure` gets overridden with computer values

Logic is identical to the current `useDiveComputerCnsData` flow, just driven by enum comparison.

## Legend UI

### Badge Labels

| State | Badge Text |
|-------|-----------|
| NDL visible, source=computer, computer data exists | `NDL (DC)` |
| NDL visible, source=calculated | `NDL` |
| CNS visible, source=computer, NO computer data | `CNS (Calc*)` |

The `*` in `(Calc*)` indicates fallback: user preferred computer but it was unavailable.

Metrics that never have computer data (SAC, ppO2, GF, etc.) show no source indicator.

### Per-Dive Source Toggle

In the "More" popover menu, each applicable metric row gets a segmented control:

```

[x] NDL          [DC | Calc]
[x] Ceiling      [DC | Calc]
[ ] TTS          [DC | Calc]
[x] CNS          [DC | Calc]

```text
Disabled/hidden when the dive has no computer data for that metric.

### ProfileLegend Notifier

New toggle methods:

```dart
void cycleNdlSource() { ... }
void cycleCeilingSource() { ... }
void cycleTtsSource() { ... }
void cycleCnsSource() { ... }
```dart
Initialization reads `settings.defaultNdlSource`, etc.

## Provider Layer

### profileAnalysisProvider

Reads source preferences from `ProfileLegendState`:

```dart
final legendState = ref.watch(profileLegendProvider);
final ndlSource = legendState.ndlSource;
final ceilingSource = legendState.ceilingSource;
final ttsSource = legendState.ttsSource;
final cnsSource = legendState.cnsSource;
```dart
Passes them to `overlayComputerDecoData`.

### MetricSourceInfo Provider

```dart
final metricSourceInfoProvider = StateProvider<MetricSourceInfo?>((ref) => null);
```text
Written by `profileAnalysisProvider` as a side effect. Read by the legend widget for badge labels.

### Reactivity Chain

```

User toggles source in legend
  -> ProfileLegendState updates
  -> profileAnalysisProvider re-evaluates (watches profileLegendProvider)
  -> overlayComputerDecoData re-runs with new sources
  -> Chart updates with new curve data
  -> metricSourceInfoProvider updates
  -> Legend badge labels update

```text
## Settings UI

The existing "Dive Computer Data" section (single CNS toggle) is replaced with "Data Source Preferences":

```text

Data Source Preferences
  NDL Source          [Calculated v]
  Ceiling Source      [Calculated v]
  TTS Source          [Calculated v]
  CNS Source          [Calculated v]

```

Subtitle: "When set to Dive Computer, the app uses data reported by the dive computer when available. Falls back to calculated values when computer data is not present."

Both `settings_page.dart` and `appearance_page.dart` get these controls in their decompression sections.

## Unchanged Components

- `ProfileAnalysisService.analyze()` -- stays pure, always calculates
- `DiveProfilePoint` entity -- no changes
- `O2Exposure` entity -- no changes
- `O2ToxicityCard` / `CompactO2ToxicityPanel` -- consume O2Exposure identically
- `DecoInfoPanel` -- consumes DecoStatus, not source-aware
- `DiveProfileChart` rendering -- curves are curves; source is legend-only
- OTU calculation -- always app-calculated

## Testing

| Type | Coverage |
|------|----------|
| Unit | MetricDataSource enum serialization to/from int |
| Unit | overlayComputerDecoData with per-metric source params |
| Unit | MetricSourceInfo reports actual vs requested source |
| Integration | Source toggle flows through provider to chart data |
| Integration | CNS residual short-circuit with enum-based check |
| Widget | Legend badge "(DC)", "(Calc*)" display |
| Widget | Source segmented control in popover |
| Migration | v42 adds columns, migrates CNS toggle data |

### Tests to Update

- `computer_cns_provider_integration_test.dart` -- replace `includeComputerCns` bool with `cnsSource` enum
- `profile_analysis_provider_test.dart` -- update overlay call signatures
- `settings_page_test.dart` -- remove `setUseDiveComputerCnsData` mock, add source setters
- `records_page_test.dart` -- same mock update

## Edge Cases

- Dive with partial computer data (NDL present, no TTS): each metric independent
- Manual dive (no profile): source toggles have no effect
- Sparse computer samples: existing gap-fill behavior unchanged
- Future metrics: add new field to `MetricDataSource` enum, `MetricSourceInfo`, and `overlayComputerDecoData`
