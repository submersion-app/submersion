# Chart Options Dialog Redesign

## Problem

The "More chart options" dialog in the dive profile graph has usability issues:

1. Data source selectors (DC/Calc) appear as separate rows below their associated metrics, making it unclear which source belongs to which metric.
2. The flat list of 20+ toggles with only divider separators is hard to scan and takes up excessive vertical space.
3. The Ceiling metric occupies a primary legend slot despite being a niche decompression feature, while the more commonly-used Events toggle is buried in the dialog.

## Design Decisions

### Primary Legend Changes

- **Remove** Ceiling from primary inline legend toggles.
- **Add** Events as a primary inline legend toggle (replacing Ceiling's slot).
- Primary legend remains: Depth (non-toggle), Temperature, Pressure (single-tank only), Events, "More" button.
- Events primary toggle renders conditionally on `config.hasEvents` (same pattern as the existing Ceiling conditional). If a dive has no events, the slot simply doesn't render — no fallback to another metric.
- Events uses `Colors.amber` (matching its current color in the dialog).

### Inline Segmented Source Selectors

Replace the disconnected "Source: DC/Calc" rows with a Material 3 `SegmentedButton<MetricDataSource>` integrated directly into the metric's toggle row. This applies to the 4 source-capable metrics:

- Ceiling
- NDL
- TTS
- CNS%

The segmented button sits on the trailing (right) side of the row. Both options are always visible so users don't need to guess what tapping will cycle to. When the metric's visibility toggle is off, the segmented button is visually dimmed but remains tappable (users can pre-select their preferred source before enabling the metric).

The `SegmentedButton` calls explicit set methods (e.g., `setCeilingSource(MetricDataSource.computer)`) rather than the existing cycle methods. Add `setCeilingSource`, `setNdlSource`, `setTtsSource`, `setCnsSource` to the provider. Remove the existing `cycle*Source` methods since they are no longer used.

Fallback behavior is unchanged: when the user selects "DC" but dive computer data is unavailable, the app falls back to calculated data and the legend label shows an asterisk indicator (e.g., "DC*" or "Calc*" in the inline legend for metrics promoted there).

### Collapsible Sections

Replace the flat list with collapsible section headers. Each section is an `ExpansionTile`-style row with a title and expand/collapse chevron. Sections remember their expanded/collapsed state for the session (stored in `ProfileLegendState`, read by the dialog on each open).

**Initial expanded defaults:** Overlays and Decompression start expanded; Markers, Gas Analysis, and Other start collapsed. Tank Pressures (when present) starts expanded.

| Section | Metrics |
|---------|---------|
| Overlays | Heart Rate, SAC, Ascent Rate Colors |
| Markers | Max Depth, Pressure Thresholds, Gas Switches |
| Decompression | Ceiling (+DC/Calc), NDL (+DC/Calc), TTS (+DC/Calc), CNS% (+DC/Calc), OTU |
| Gas Analysis | ppO2, ppN2, ppHe, MOD, Gas Density |
| Other | GF%, Surface GF%, Mean Depth |

Multi-tank pressure toggles (when present) appear as their own section titled "Tank Pressures" between Markers and Decompression.

### Section Grouping Rationale

- **Overlays**: Data curves drawn on the chart background.
- **Markers**: Point annotations (dots, lines, icons) overlaid on the depth curve.
- **Decompression**: Metrics related to decompression status and oxygen exposure.
- **Gas Analysis**: Partial pressure and gas property curves.
- **Other**: Gradient factors and statistical metrics.

## Affected Files

### Must Change

| File | Change |
|------|--------|
| `lib/features/dive_log/presentation/widgets/dive_profile_legend.dart` | Swap Ceiling/Events in primary toggles; remove Events from `_ChartOptionsDialog` (it is no longer a secondary toggle); rewrite `_ChartOptionsDialog` with collapsible sections and inline `SegmentedButton`s; remove `_buildSourceSelector`; add a new Ceiling visibility toggle row in the Decompression section (currently Ceiling has no visibility toggle in the dialog -- only a source selector); update `_MoreOptionsButton._activeSecondaryCount` to include `showCeiling` and remove `showEvents`; remove `hasEvents` from `ProfileLegendConfig.hasSecondaryToggles` (Events is now primary) |
| `lib/features/dive_log/presentation/providers/profile_legend_provider.dart` | Add section expanded/collapsed state as a `Map<String, bool>` field in `ProfileLegendState` (requires updating `copyWith`, `==`, `hashCode` -- same pattern as `showTankPressure`); add explicit `setCeilingSource`, `setNdlSource`, `setTtsSource`, `setCnsSource` methods; remove `cycle*Source` methods; add `showCeiling` to `activeSecondaryCount` and remove `showEvents` from it (note: Ceiling defaults to on, so the badge count will increase by 1 for dives with ceiling data -- this is the correct behavior since Ceiling is now a secondary toggle) |

### May Need Minor Updates

| File | Change |
|------|--------|
| `lib/core/constants/profile_metrics.dart` | No changes needed (categories already exist) |
| `lib/features/settings/presentation/providers/settings_providers.dart` | No changes needed (per-metric defaults already stored) |
| `lib/features/dive_log/presentation/pages/dive_detail_page.dart` | No changes needed (`ProfileLegendConfig.hasEvents` is already wired up) |

## Scope Boundaries

- Section expanded/collapsed state is session-only (not persisted to database or preferences).
- No changes to which metrics exist or how they're computed.
- No changes to the chart rendering itself (only the legend/options UI).
- No changes to the Settings page profile defaults section.
- The `_sourceLabel` function remains available for any future use but is no longer called from the primary legend after this change (no source-capable metrics remain in the primary legend).

## Testing

- Unit tests for section grouping logic (which metrics go in which section).
- Widget tests for collapsible section expand/collapse behavior.
- Widget tests for segmented button source selection (tap DC, tap Calc, verify state).
- Widget tests for primary legend showing Events instead of Ceiling.
- Verify badge count on "More" button correctly counts active secondary toggles (Ceiling is now counted as secondary; expect badge count to increase by 1 for dives with ceiling data since Ceiling defaults on).
- Widget tests for Ceiling visibility toggle in the Decompression section (new toggle -- did not exist before).
