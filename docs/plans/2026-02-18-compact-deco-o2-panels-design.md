# Compact Deco & O2 Toxicity Panels

## Problem

The Decompression Status and Oxygen Toxicity sections on the dive detail page consume too much vertical space when expanded (~300-350px each). Users cannot see them simultaneously with the dive profile chart without scrolling.

## Goal

All three elements (profile chart, deco status, O2 toxicity) visible on screen at the same time, on all platforms (phone, tablet, desktop), with all data still accessible.

## Approach: Responsive Side-by-Side / Stacked-Compact

### Desktop/Tablet (>=800px)

Deco and O2 panels render **side-by-side** in a Row below the chart:

```
[ Profile Chart Card              ]
[ CompactDeco  |  CompactO2Tox   ]   ~180-200px tall
```

### Phone (<800px)

Deco and O2 panels stack vertically in **compact form**:

```
[ Profile Chart Card    ]
[ CompactDeco           ]   ~150px tall
[ CompactO2Tox          ]   ~150px tall
```

## Compact Deco Panel

Condensed version of `DecoInfoPanel` (~150-180px tall):

- Header row: icon + title + DECO/NO DECO badge
- 3 metric chips in a Row (NDL/Ceiling, TTS, Leading TC) with reduced padding (8px vs 12px) and smaller text styles
- Tissue bar chart at 40px height (down from 60px)
- GF values on a single line
- Deco stop chips (only when in deco)
- Overall card padding: 12px (down from 16px)
- "At time" subtitle when a profile point is selected

## Compact O2 Toxicity Panel

Condensed version of `O2ToxicityCard` (~150-180px tall):

- Header row: icon + title + warning/critical badge (conditional)
- CNS progress bar at 6px height (down from 8px) with start/delta row
- OTU value + daily limit chip in a Row
- Max ppO2 and depth merged onto one line
- Time-above-threshold chips inline (only when >0)
- Overall card padding: 12px (down from 16px)
- Selected-point ppO2 accent row when a profile point is tapped

## Expand/Collapse Interaction

**Default state:** Compact panels always visible. No collapse-to-header-only mode.

**Expand:** Tapping a compact panel expands it to the full detailed view inline. Uses existing Riverpod providers:
- `decoSectionExpandedProvider` (false = compact, true = full)
- `o2ToxicitySectionExpandedProvider` (false = compact, true = full)

**Expanded layout:** When one panel expands, it takes full width. The other panel moves below it. The Row temporarily becomes a Column.

```
Compact (default):
+----------------+ +----------------+
| CompactDeco  > | | CompactO2    > |
+----------------+ +----------------+

Deco expanded:
+----------------------------------+
| Full DecoInfoPanel             < |
+----------------------------------+
+----------------------------------+
| CompactO2Tox                   > |
+----------------------------------+
```

**Visual affordance:** Expand chevron icon in top-right corner of each compact card.

## File Changes

| File | Change |
|------|--------|
| `lib/features/dive_log/presentation/widgets/deco_info_panel.dart` | Add `CompactDecoPanel` widget |
| `lib/features/dive_log/presentation/widgets/o2_toxicity_card.dart` | Add `CompactO2ToxicityPanel` widget |
| `lib/features/dive_log/presentation/pages/dive_detail_page.dart` | Replace `_buildDecoSection` + `_buildO2ToxicitySection` with `_buildDecoO2Panel` using `ResponsiveBreakpoints.isDesktop` |

## What Stays the Same

- `DecoInfoPanel` and `O2ToxicityCard` widgets (used as expanded view)
- `CollapsibleCardSection` widget (just no longer used for these two sections)
- All existing Riverpod providers (reused with same semantics)
- Profile chart (untouched)
- Selected point interaction (passed through to compact and full views)

## Estimated Vertical Space Savings

- Desktop: ~400px saved (two full cards -> one ~200px row)
- Phone: ~250px saved (two ~300px cards -> two ~150px compact cards)

Chart (200px) + compact panels (200px desktop / 320px phone) fits comfortably within a typical viewport.
