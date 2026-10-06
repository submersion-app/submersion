# Computer CNS Data Preference

## Problem

When a dive computer provides per-sample CNS data, the app ignores it for the O2 toxicity card summary (cnsStart, cnsEnd, cnsDelta). Instead, it always recalculates CNS from scratch using NOAA tables. The per-sample CNS curve is overlaid on the chart, but the dive-level summary values on the O2 toxicity card remain app-calculated — creating a disconnect between what the chart shows and what the card reports.

## Solution

Add a per-diver setting to prefer dive-computer-reported CNS data when available. When enabled:

1. Dives with computer CNS samples use first/last sample values for cnsStart/cnsEnd
2. Dives without computer CNS continue using app-calculated values
3. The recursive residual CNS walk short-circuits at dives with computer CNS data
4. Cross-source chaining works seamlessly (decay from computer cnsEnd into a subsequent calculated dive)

## Setting

- **Name:** `useDiveComputerCnsData`
- **Type:** bool
- **Default:** false (opt-in, preserves existing behavior)
- **Location:** Decompression section of Settings page
- **Label:** "Use Dive Computer CNS Data"
- **Subtitle:** "Prefer CNS values reported by the dive computer over app-calculated values"

## Data Flow

### Setting OFF (default / current behavior)

```text
_computeResidualCns(diveId)
  -> getPreviousDive()
  -> recursively get previous dive's profileAnalysis
  -> apply exponential decay over surface interval
  -> return residual as startCns

service.analyze(startCns: residual)
  -> NOAA table CNS calculation from scratch
  -> returns o2Exposure with calculated cnsStart/cnsEnd
```

### Setting ON, dive HAS computer CNS

```text
profileAnalysisProvider:
  -> skip _computeResidualCns() entirely
  -> service.analyze(startCns: 0.0)  // still need other analysis
  -> overlayComputerDecoData() overlays cnsCurve (existing)
  -> NEW: derive o2Exposure.cnsStart from first non-null CNS sample
  -> NEW: derive o2Exposure.cnsEnd from last non-null CNS sample
```

### Setting ON, dive does NOT have computer CNS

```text
Same as "Setting OFF" — full app calculation with recursive residual.
```

### Recursive walk with mixed data sources

```text
Dive C (no computer CNS, setting ON)
  -> _computeResidualCns(C)
    -> getPreviousDive() = Dive B
    -> Dive B HAS computer CNS
    -> SHORT-CIRCUIT: cnsEnd = last CNS sample from B's profile
    -> apply decay over surface interval
    -> return residual for C

Dive C then calculates CNS normally using that residual as startCns.
```

## Changes by Component

### Database (migration v41)

New column on `DiverSettings`:

```sql
ALTER TABLE diver_settings
  ADD COLUMN use_dive_computer_cns_data INTEGER NOT NULL DEFAULT 0;
```dart
### Settings Layer

| File | Change |
|------|--------|
| `database.dart` (DiverSettings table) | Add `useDiveComputerCnsData` BoolColumn |
| `settings_providers.dart` (AppSettings) | Add field, copyWith, constructor default |
| `settings_providers.dart` (SettingsNotifier) | Add `setUseDiveComputerCnsData()` setter |
| `settings_providers.dart` (convenience) | Add `useDiveComputerCnsDataProvider` |
| `diver_settings_repository.dart` | Map field in create/update/read |
| `settings_page.dart` | SwitchListTile in Decompression section |

### Provider Layer

| File | Change |
|------|--------|
| `profile_analysis_provider.dart` | `profileAnalysisProvider`: check setting + profile, conditionally skip residual calc, derive o2Exposure from samples |
| `profile_analysis_provider.dart` | `_computeResidualCns`: short-circuit when previous dive has computer CNS and setting is on |
| `profile_analysis_provider.dart` | `overlayComputerDecoData`: extend to also overlay o2Exposure cnsStart/cnsEnd |

### Unchanged Components

- `ProfileAnalysisService.analyze()` - stays pure, always NOAA-calculated
- `O2Exposure` entity - no schema change
- `O2ToxicityCard` / `CompactO2ToxicityPanel` - consume O2Exposure identically
- OTU calculation - always app-calculated (not reported by dive computers)
- Per-sample CNS curve overlay - already works

## Helper: Extract Computer CNS Start/End

Pure function to derive dive-level CNS from per-sample data:

```dart
/// Extracts cnsStart and cnsEnd from computer-reported per-sample CNS data.
/// Returns null if no computer CNS samples exist.
({double cnsStart, double cnsEnd})? extractComputerCns(
  List<DiveProfilePoint> profile,
) {
  double? first;
  double? last;
  for (final point in profile) {
    if (point.cns != null) {
      first ??= point.cns!;
      last = point.cns!;
    }
  }
  if (first == null || last == null) return null;
  return (cnsStart: first, cnsEnd: last);
}
```

## Edge Cases

- **Sparse CNS samples:** First non-null may not be sample index 0. Still valid.
- **All-null CNS:** `extractComputerCns` returns null, falls back to calculation.
- **Single CNS sample:** cnsStart == cnsEnd. Unusual but handled.
- **CNS decreasing mid-dive:** Possible on very long shallow dives where recovery > accumulation. Accepted as-is from computer.

## Testing

- Unit: `extractComputerCns` with various sample patterns
- Unit: `_computeResidualCns` short-circuit with computer CNS
- Provider: setting ON + computer CNS -> uses computer values
- Provider: setting ON + no computer CNS -> falls back to calculation
- Provider: setting OFF + computer CNS -> ignores computer values
- Provider: recursive chain with mixed computer/calculated dives
- Provider: boundary decay from computer cnsEnd to subsequent calculated dive
