# Dive focus redesign

## Problem

Dive focus (Insights, `/insights/focus`, from issue #1611) lets a diver pick a
group of dives by one metric and see what the group has in common. The idea
is sound, but the page is hard to use:

- Nothing on the page says what it is for. The only hint is the category
  subtitle "Best, worst and threshold groups".
- The controls are an unlabelled row: a metric dropdown, a Best / Worst /
  Above / Below button, 5 / 10 / 20 chips and a "Dives" box that duplicates
  them. Picking Above or Below shows an empty "Value" box with no unit and an
  empty page.
- The chart draws the group's dives at the same tiny size as every other
  dive, a shade darker, with no legend.
- The payoff, the common factors table, sits at the bottom under a ten-row
  dive list. Its rows read "24.2 m vs 21.6 m" with no column headers, the
  "Stands out" chips are scattered down the left column, and rows such as
  "Not recorded" or "50 min vs 50 min" crowd out the ones that matter.
- Only six metrics are available: RMV, SAC, max depth, bottom time, weight
  and water temp.

## Brief

A diver opens Dive focus and, without instruction, can answer "what do my
best (or worst, deepest, coldest...) dives have in common?". The finding leads
the page; the dives are evidence. The page keeps its name. Fourteen metrics
are available. Values display in the active diver's units; the Insights filter
and the exclude-from-stats scopes apply; the selection lasts for the session,
as today.

## Section 1: Page layout and the sentence builder

One column at every width, top to bottom:

1. **Intro line** under the title: "See what a group of your dives has in
   common." The Insights category subtitle becomes "What your best and worst
   dives have in common".
2. **Sentence builder** in a card (below).
3. **Summary line:** "10 of 64 dives. Average 11.9 L/min, against 16.8 L/min
   across all your dives." The "all shown" and "no match" variants keep their
   current meaning with the same tone.
4. **What stands out** card (Section 2).
5. **Chart** (Section 3).
6. **Full comparison** table (Section 2).
7. **The dives** list, titled "The dives", showing the first 5 rows with a
   "Show all 10 dives" button beneath. The button expands the list until the
   selection changes. Rows are unchanged: rank (ranked modes only), site, date,
   depth and duration, the metric value; tapping opens the dive.

### Sentence builder

The controls read as a sentence whose words are menus.

- Ranked form: "Show the [10] dives with the [best] [RMV]".
- Threshold form: "Show the dives with [RMV] [above] [15.0 L/min]".
- The **mode** menu lists best and worst for metrics where lower is better
  (RMV, SAC, gas used), lowest and highest for the others, then above and
  below. Choosing above or below switches the sentence to the threshold form
  and back.
- The **count** menu offers 5, 10, 20, 50 and "Custom...". Custom opens a
  small dialog with one number field, 1 to 999, with the existing validation
  message. The chips and the second text box are removed.
- The **metric** menu is grouped with headings: Gas (RMV, SAC, gas used);
  Depth and time (max depth, average depth, bottom time, surface interval);
  Conditions (water temp, air temp, visibility, altitude); Exposure (CNS at
  end, OTU); Kit (weight).
- The **threshold** field shows the unit beside the number at all times.
  Switching to above or below, or changing the metric while in a threshold
  mode, pre-fills the field with the population mean for that metric
  (rounded for input as the field does today), so the page never shows an
  empty box over an empty page. The diver's own edits are kept across
  settings changes, as today, and re-rendered on a unit change (#3017).
- Each sentence form is one localised template string containing marker
  tokens for its slots. The widget splits the translated string around the
  markers and lays the fragments and controls out in a `Wrap`, so a translator
  can reorder the words. A unit test checks that every locale's template
  contains each marker exactly once.

## Section 2: What stands out, and the full comparison

### Strength

The factor model gains a `strength` on every standout: for a numeric factor
the absolute difference in baseline standard deviations; for a categorical
value its share gap in points divided by 100. The standout rule is unchanged
(half a standard deviation; 20 points with at least 2 group dives). The report
exposes `standouts` ordered by strength, strongest first.

### What stands out card

Directly under the summary line, titled "What stands out".

- One line per standout, strongest first, at most five:
  - Categorical, whole group: "All 10 were boat entries (64% of all your
    dives)".
  - Categorical, part of the group: "8 of 10 were boat entries, against 64% of
    all your dives".
  - Numeric: "Average depth 2.1 m shallower (11.3 m vs 13.4 m)". Direction
    words per numeric factor: deeper / shallower (depths), longer / shorter
    (duration), warmer / colder (water temp), larger / smaller (tank size),
    more lead / less lead (weight).
- More than five: a final line "and 2 more in the full comparison".
- No standouts: "Nothing stands out about these dives."
- Fewer than 3 dives in the group: "Pick at least 3 dives to see what they
  share", and the full comparison is not shown.

### Full comparison table

Below the chart, titled "Full comparison", subtitle "All dives means every
dive in the current filter that has RMV" (the current metric's name).

- Column headers: the factor, "These dives", "All dives", and "Difference"
  (numeric rows). Below a 600 px width the difference moves under the "These
  dives" value as muted text and the header has three columns.
- Within each group (Dive shape, Conditions, When and where, Kit and gas),
  standouts sort first, then the remaining rows in their current order. A
  standout carries a small accent marker beside its name; the chip under the
  name is removed. Coverage ("9 of 12 dives") stays as muted text under the
  name.
- **Folded rows.** A row is quiet when it is not a standout and either has no
  data ("Not recorded"), or its numeric difference rounds to zero in the
  diver's display units, or its categorical top value's share gap is under 5
  points. Quiet rows are hidden behind a "Show 6 more factors" button at the
  bottom of the table; pressing it shows them until the selection changes. A
  group with only quiet rows hides its heading too. When no row is quiet the
  button is absent.
- The self-factor omission rule gains two entries: average depth omits the
  average depth row; visibility omits the visibility row. Max depth, bottom
  time, weight and water temp keep theirs.

## Section 3: The chart

- Title "RMV over time", naming the current metric.
- Group points draw at twice the radius of the others in the accent colour;
  other dives keep the small muted dot. `TrendSeries` gains an optional
  `pointRadius`, null for every other caller.
- A legend row above the plot, drawn by the Focus page (the chart's own
  legend is part of the control strip the Focus page does not show): an
  accent swatch "In the group" and a muted swatch "Other dives".
- In above or below mode, a dashed horizontal line at the threshold with the
  formatted value as its label. `DiveTrendChart` gains an optional
  `referenceLine` (value and label); the line is built in a new file beside
  the chart so `dive_trend_chart.dart` stays under 800 lines.
- Tapping a dot opens the dive, as today.

## Section 4: Metrics

| Metric | Source | Storage unit | Display | Better end |
| --- | --- | --- | --- | --- |
| RMV | existing | L/min | diver's volume rate | lower |
| SAC | existing | bar/min | diver's pressure rate | lower |
| Gas used | sum over tanks of the consumption volume `getSacVolumePerDive` already computes, not divided by time or depth | L | L or cuft | lower |
| Max depth | existing | m | depth | none |
| Average depth | `dives.avg_depth` | m | depth | none |
| Bottom time | existing | min | min | none |
| Surface interval | `dives.surface_interval_seconds` | min | hours and minutes via the existing surface interval formatter; threshold entered in minutes | none |
| Water temp | existing | C | temperature | none |
| Air temp | `dives.air_temp` | C | temperature | none |
| Visibility | `dives.visibility_meters` | m | distance in the diver's depth unit | none |
| Altitude | `dives.altitude` | m | altitude in the diver's depth unit | none |
| CNS at end | `dives.cns_end` | % | % | none |
| OTU | `dives.otu` | OTU | plain number | none |
| Weight | existing | kg | weight | none |

Each new metric is one per-dive series in the focus repository file, scoped
through `_diveFilter` like the existing ones, excluding planned dives and
dives excluded from stats, and one arm in the metric series provider. A dive
without the value is absent from the series. Air temp and water temp allow a
negative threshold; the rest do not. Dives logged with only a visibility band
and no distance are absent from the visibility series.

The gas page's "See top 10" link still opens RMV or SAC, best 10.

## Section 5: Structure, errors and testing

### Units

| Unit | Change |
| --- | --- |
| `insights/domain/focus/focus_metric.dart` | Eight new values, `group`, `lowerIsBetter`. |
| `insights/domain/focus/focus_factor.dart`, `focus_factor_analyzer.dart` | `strength`, ordered standouts, the two new self-factor omissions. |
| `insights/domain/focus/focus_quiet_rows.dart` (new) | Pure rule deciding which rows fold, given display rounding. |
| `insights/data/repositories/insights_repository_focus.dart` | Eight series methods; split into a part file if it nears 800 lines. |
| `insights/presentation/providers/insights_focus_providers.dart` | New arms; population mean for the threshold default. |
| `insights/presentation/formatters/focus_metric_units.dart`, `focus_labels.dart`, `focus_factor_labels.dart` | Units, labels, direction words, grouped menu names. |
| `insights/presentation/widgets/focus/focus_sentence.dart` (new) | The sentence builder; replaces `focus_selector.dart`. |
| `insights/presentation/widgets/focus/focus_count_dialog.dart` (new) | The custom count dialog. |
| `insights/presentation/widgets/focus/focus_standouts_card.dart` (new) | The headline card. |
| `insights/presentation/widgets/focus/focus_factors_table.dart` | Headers, sorting, markers, folding, subtitle. |
| `insights/presentation/widgets/focus/focus_results.dart`, `focus_dive_list.dart` | New order, legend row, chart title, Show all. |
| `insights/presentation/pages/insights_focus_page.dart` | Intro line. |
| `insights/presentation/widgets/dive_trend_chart.dart`, `trend_reference_line.dart` (new) | `pointRadius` on `TrendSeries`; `referenceLine`. |
| `insights/presentation/widgets/insights_list_content.dart` | Category subtitle. |
| ARB files, every locale | New and changed strings. |
| `docs/user/statistics.md` | Dive focus section rewritten. |

### Errors

Unchanged. Repository methods log and rethrow like their neighbours; every
async surface keeps its loading, empty and error states; the threshold field
keeps its inline validation.

### Testing (written first)

- Unit: each new series (a dive with and without the value, a planned dive,
  an excluded dive, the gas sum across two tanks); strength and ordering;
  the quiet-row rule in metric and imperial; the template splitter and the
  every-locale marker check; direction words; the two new self-factor
  omissions.
- Widget: the sentence in both forms and the switch between them; the count
  menu and custom dialog; the pre-filled threshold on mode and metric change;
  the standouts card with standouts, with none, with more than five, and with
  too few dives; the table headers, sorting, fold and expand, and the fold
  reset on a new selection; the legend row, the point radius and the
  threshold line; the dive list Show all; the gas page link.
- The existing focus page, selector and factors table tests are updated to
  the new widgets rather than deleted.
- `test/architecture/` and `test/shared/` after adding files under `lib/`.

## Out of scope

- Persisting the selection across launches.
- Pushing the group into the dive list's filter.
- Ascent rate or any metric that needs profile samples.
- Rating as a metric.
