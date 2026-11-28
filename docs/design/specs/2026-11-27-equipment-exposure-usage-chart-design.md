# Equipment exposure: totals, recency and a usage chart

Release: v1.8.7. Size: a small change to one card.

## Intent

On a gear item's page, a diver wants to see at a glance how recently the item
was dived and how often it gets used, as a picture rather than a row of chips.
Today the Exposure card (`lib/features/equipment/presentation/widgets/exposure_card.dart`)
lists one chip per unit with a non-zero total and a muted footer with the dive
count and date range. Nothing on it shows recency or the pattern of use.

## Goals

- Recency at a glance: when the item was last dived.
- Frequency as a chart: how often it is dived, over the last year and over its
  whole life.
- The headline totals (dives, hours) read as numbers, not chips.

## Non-goals

- The Insights > Equipment > Exposure ranking is unchanged.
- No new storage, schema change or sync change: everything derives from the
  exposure samples the card already reads.
- No navigation from a bar to the dives behind it.
- The service-oriented units (salt-water hours, cold dives, high-O2 hours, deep
  dives, battery cycles) are not charted.

## Anti-goals

- A chart that only reads well for a typical item. It must work for a mask with
  5 dives bought last month and for a regulator with 2,000 dives over 12 years
  that has sat idle since 2023.
- A chart that ends at the last dive. The axis ends at today, so idle time is
  visible.
- Disagreeing with the service clocks: the card keeps reading
  `equipmentExposureInputsProvider`, the same samples the clocks read.

## Approaches considered

| Approach | Trade-off |
| --- | --- |
| **A. Usage bars (chosen)** | Dives per month for the last 12 months, switchable to dives per year over the item's life. Bars end at today, so empty bars on the right show recency. Holds at both ends of the range (a few short bars; about 15 yearly bars). Matches the `fl_chart` bar charts used elsewhere. |
| B. Lifetime timeline strip | One tick per dive from first dive to today. Shows trips as clusters, but thousands of dives smear together and frequency is hard to read. |
| C. Calendar heatmap | One square per week for a year. Shows rhythm, but covers one year only, so an item idle for longer shows an empty grid. |

The diver chose A.

## Design

### Headline row (replaces the dives and hours chips)

Three stat tiles across the top of the card:

- **Last dived**: relative time from the latest sample's date to today:
  "Today", "N days ago" under a month, "N months ago" under two years, then
  "N years ago". Exact date in the tile's semantics label. *(My call on the
  wording and the cut-offs.)*
- **Dives**: the dive count.
- **Hours**: total hours, one decimal, as the chip shows today.

The remaining units keep their chips below the chart, unchanged. The dives and
hours chips go, since the tiles now carry them. *(My call.)*

### Usage chart

- A bar chart of **dive count** per bucket. The tooltip on a bar gives the
  bucket's label, dives and hours. *(My call: count, not hours, because "how
  often" is a count.)*
- A two-way switch above the chart: **12 months** (default) and **All years**.
  The choice is not saved; every page opens on 12 months. *(My call.)*
- **12 months**: twelve monthly buckets, the current month last, empty months
  drawn as zero. A caption under the chart: "N dives in the last 12 months".
- **All years**: one bucket per calendar year from the year of the first
  sample to the current year, empty years drawn as zero.
- Buckets use the dive's local calendar date, as the rest of the app shows dive
  dates.
- Axis labels thin out so they never overlap at phone width (every other
  month label at narrow widths; year labels thinned to fit for long lives).
  *(Builder settles the exact thinning.)*

### Footer and empty states

- The footer keeps the dive count and first-to-last date range.
- No dives: the card keeps today's empty message and draws no tiles or chart.
- Only dives older than 12 months: the 12-month view draws twelve empty bars
  with a caption "No dives in the last 12 months", which is the recency answer.

### Where it shows

Everywhere `ExposureCard` is used: the gear item page and the gear passport
page.

## Constraints

- All new strings localized (en plus the existing locales via the normal ARB
  flow).
- Respect the active diver's settings for date formatting; hours are unitless.
- Colours from the theme so light and dark both read.

## Left to the builder

- Where the bucketing lives (a pure function in `domain/services`, tested
  directly) and the provider shape.
- Exact axis-label thinning and bar widths.
