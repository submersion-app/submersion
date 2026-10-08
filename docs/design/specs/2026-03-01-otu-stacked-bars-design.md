# OTU Stacked Bars in O2 Toxicity Panel

**Date:** 2026-03-01
**Status:** Approved

## Problem

The CompactO2ToxicityPanel shows OTU data as plain text metrics in a 3-column
row (This Dive / Daily / Weekly). The CNS Oxygen Clock above it uses a
visually rich stacked bar with segmented layers showing residual, this-dive
contribution, and cursor tracking. OTU deserves the same treatment to provide
at-a-glance understanding of daily and weekly pulmonary oxygen budget usage.

## Decision

Replace the text-only `_buildOtuBreakdown` method with a new `_buildOtuProgress`
that renders two full-width stacked bars (Daily and Weekly), each mirroring the
CNS `_buildStackedCnsBar` pattern with 4 layers.

## Design

### Visual Layout

```text
Oxygen Tolerance Units

Daily                                85 / 300 OTU
+----------+-----------+---------------------------+
| Prior    | This Dive |        Remaining          |
|(blueGrey)| (green)   |       (background)        |
+----------+-----------+---------------------------+
Start: 42 OTU                    +43 this dive

Weekly                              320 / 850 OTU
+--------------+-----------+-----------------------+
|    Prior     | This Dive |       Remaining       |
|  (blueGrey)  | (green)   |     (background)      |
+--------------+-----------+-----------------------+
Prior: 277 OTU                   +43 this dive
```

### Bar Layers (4, identical to CNS bar)

1. **Background track** - full width represents the limit (300 daily / 850 weekly)
2. **Colored bar** - total OTU as fraction of limit, color based on percentage
3. **Cursor overlay** - OTU at cursor point during profile scrubbing (primary color)
4. **Prior segment** - residual from prior dives (blueGrey, rendered on top)

### Data Flow

**Daily bar** (all data already available in O2Exposure):

- `prior` = `exposure.otuStart` (earlier same-day dives)
- `thisDive` = `exposure.otu`
- `total` = `exposure.otuDaily` (= otuStart + otu)
- `limit` = `O2Exposure.dailyOtuLimit` (300)
- `cursorDelta` = `selectedOtu` when non-null (OTU at cursor point within this dive)

**Weekly bar** (derived from existing `weeklyOtu` parameter):

- `prior` = `weeklyOtu - exposure.otu` (weekly total minus this dive)
- `thisDive` = `exposure.otu`
- `total` = `weeklyOtu`
- `limit` = `O2Exposure.weeklyOtuLimit` (850)
- `cursorDelta` = `selectedOtu` when non-null (same cursor value)

No new providers or data sources needed. All values derive from existing
`O2Exposure` fields and the `weeklyOtu` parameter.

### Color Thresholds

Same as existing `_getOtuLimitColor`:

| % of Limit | Color       |
|------------|-------------|
| < 50%      | green       |
| 50-79%     | amber       |
| 80-99%     | orange      |
| >= 100%    | error (red) |

### Label Rows

Each bar section has:

- **Header row**: label left ("Daily" / "Weekly") + value right ("85 / 300 OTU", colored)
- **Footer row**: prior amount left ("Start: 42 OTU" / "Prior: 277 OTU") + delta right ("+43 this dive")
- **Cursor mode**: header value shows "cursor / total" format (e.g., "21 / 85 / 300 OTU")

### Bar Dimensions

- Height: 20px (matches CNS bar)
- Border radius: 6px (matches CNS bar)
- Vertical spacing between daily and weekly bars: 8px

## Files to Modify

| File | Change |
|------|--------|
| `lib/features/dive_log/presentation/widgets/o2_toxicity_card.dart` | Replace `_buildOtuBreakdown` with `_buildOtuProgress`; add `_buildStackedOtuBar` helper |

### Method Changes in CompactO2ToxicityPanel

**Remove:**

- `_buildOtuBreakdown` (3-column text metrics)
- `_buildOtuMetric` (individual text metric helper)

**Add:**

- `_buildOtuProgress` - renders "Oxygen Tolerance Units" header + daily bar + weekly bar
- `_buildStackedOtuBar` - renders one stacked bar with 4 layers (parameterized by prior/total/limit/cursor/label)
- `_buildOtuLabelRow` - header row with label + value
- `_buildOtuFooterRow` - footer row with start/prior amount + delta

### No Changes to O2ToxicityCard (Full Version)

The full-size `O2ToxicityCard` (used in settings previews) already has
`_buildOtuProgressRow` with `LinearProgressIndicator`. It can be updated
in a follow-up if desired, but is not in scope for this change.

## Edge Cases

- **No prior dives**: `otuStart` = 0, blueGrey segment not rendered (same as CNS when `startFraction` = 0)
- **weeklyOtu null**: falls back to `exposure.otu` (this dive only), prior = 0
- **Over limit**: bar fills to 100% width, color becomes error red. Values still show actual numbers.
- **No cursor**: cursor overlay layer is skipped (same as CNS)

## Testing

- Verify daily bar shows correct segments for a dive with otuStart > 0
- Verify weekly bar shows correct prior = weeklyOtu - otu
- Verify cursor overlay appears when selectedOtu is provided
- Verify color thresholds at 50%, 80%, 100% boundaries
- Verify bars render correctly when otuStart = 0 (no prior segment)
- Verify bars render correctly when weeklyOtu is null
