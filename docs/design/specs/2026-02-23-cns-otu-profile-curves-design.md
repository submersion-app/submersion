# CNS% and OTU Profile Curves on Dive Profile Graph

## Summary

Add cumulative CNS% (Central Nervous System oxygen toxicity) and OTU (Oxygen
Tolerance Units) overlay curves to the dive profile chart. Both are disabled by
default and toggled via the existing "More" legend popover in the decompression
section.

## Requirements

- Show cumulative CNS% including residual from prior dives (starts at cnsStart)
- Show cumulative OTU accumulated during the dive (starts at 0)
- Both disabled by default (toggleable in "More" menu)
- Follow existing curve pattern used by ppO2, GF%, NDL, TTS, etc.

## Data Layer

### ProfileAnalysisService

Add two private methods:

**`_calculateCnsCurve()`**: Iterates over the profile using the pre-computed
`ppO2Curve`. For each segment, calls `CnsTable.cnsForSegment(ppO2, duration)`
and accumulates. Returns `List<double>` where `cnsCurve[0] = startCns` and each
subsequent value includes all prior CNS.

**`_calculateOtuCurve()`**: Same iteration pattern. For each segment, calls
`_calculateOtu(ppO2, duration)` (already exists as private method). Returns
`List<double>` where `otuCurve[0] = 0.0` and each subsequent value includes
all prior OTU.

Both methods are called in `analyze()` after the ppO2 curve is computed.

### ProfileAnalysis

Add fields:

- `List<double>? cnsCurve`
- `List<double>? otuCurve`
- `bool get hasCnsData => cnsCurve != null && cnsCurve!.isNotEmpty`
- `bool get hasOtuData => otuCurve != null && otuCurve!.isNotEmpty`

## Widget Layer

### DiveProfileChart

Add parameters:

- `List<double>? cnsCurve`
- `List<double>? otuCurve`

Add rendering methods:

- `_buildCnsLine(double chartMaxDepth)`: Maps 0-200% to depth axis. Color: `Color(0xFFE65100)` (Orange 900). Dashed line `[6, 3]`.
- `_buildOtuLine(double chartMaxDepth)`: Maps 0-300 OTU to depth axis. Color: `Color(0xFF6D4C41)` (Brown 600). Dashed line `[4, 4]`.

### ProfileLegendState

Add fields (default false):

- `bool showCns`
- `bool showOtu`

Add methods: `toggleCns()`, `toggleOtu()`

Wire through: `copyWith`, `==`, `hashCode`, `activeSecondaryCount`

Initialize from settings (both default to false initially -- no settings
entry needed until user demand warrants persistent defaults).

### ProfileLegendConfig

Add fields:

- `bool hasCnsData`
- `bool hasOtuData`

Wire into `hasSecondaryToggles`.

### DiveProfileLegend

Add CNS and OTU toggle items in the decompression section of the More
popover menu (alongside NDL, GF%, Surface GF, TTS).

### ProfileRightAxisMetric

Add enum values:

- `cns` (displayName: 'CNS%', shortName: 'CNS', color: Color(0xFFE65100), unitSuffix: '%', category: decompression)
- `otu` (displayName: 'OTU', shortName: 'OTU', color: Color(0xFF6D4C41), unitSuffix: 'OTU', category: decompression)

## Wiring

### dive_detail_page.dart

Pass `analysis?.cnsCurve` and `analysis?.otuCurve` to both DiveProfileChart
invocations (inline card and fullscreen dialog).

## Tooltip

When CNS/OTU are enabled, show their values in the touch tooltip:

- CNS: `"CNS: 12.3%"`
- OTU: `"OTU: 45"`

## Localization

Add to ARB files:

- `diveLog_legend_label_cns` = "CNS%"
- `diveLog_legend_label_otu` = "OTU"

## Color Reference

| Curve | Color | Hex |
|-------|-------|-----|
| CNS% | Orange 900 | #E65100 |
| OTU | Brown 600 | #6D4C41 |

Both are warm tones that convey "oxygen toxicity" conceptually and are distinct
from all existing curve colors (blues, greens, purples, pinks, teals).

## Scale Mapping

Dynamic scaling based on actual dive data (not fixed ceilings):

| Curve | Min | Max | Note |
|-------|-----|-----|------|
| CNS% | 0 | max(actualMax * 1.25, 10%) | 25% headroom, min floor 10% |
| OTU | 0 | max(actualMax * 1.25, 20) | 25% headroom, min floor 20 OTU |

This ensures curves fill the chart meaningfully — a recreational dive with
5% CNS sees a useful curve, not a flat line at the top of a 0-200% axis.

## Files to Modify

1. `lib/features/dive_log/data/services/profile_analysis_service.dart` - add curves + has-data getters
2. `lib/core/constants/profile_metrics.dart` - add enum values
3. `lib/features/dive_log/presentation/providers/profile_legend_provider.dart` - add toggle state
4. `lib/features/dive_log/presentation/widgets/dive_profile_legend.dart` - add config + menu items
5. `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` - add params + rendering
6. `lib/features/dive_log/presentation/pages/dive_detail_page.dart` - wire data through
7. `lib/l10n/arb/app_en.arb` (and other locale files) - add localization keys
