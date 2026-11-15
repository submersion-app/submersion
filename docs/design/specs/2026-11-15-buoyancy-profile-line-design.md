# Net buoyancy line on the dive profile

Issue: #4593

## Intent

Divers want to see where their buoyancy shifts happen relative to depth
changes: getting heavier as the suit compresses on descent, getting lighter
as gas is breathed, and the swing back as the suit re-expands on ascent. The
Buoyancy card on the dive page already draws net buoyancy over time, but on
its own chart, away from the depth trace. This feature puts the same
calculated line on the main dive profile chart as an optional metric, so the
two can be read against each other.

## Goals

- An optional "Buoyancy" line on the dive profile chart: the net buoyancy the
  buoyancy model computes for each profile sample.
- The line is drawn in one colour while the diver is buoyant (net above 0)
  and another while heavy (net below 0), switching where it crosses neutral.
- One legend entry and one Chart options row for it, not two.
- A synced "show by default" setting, off by default, like the other profile
  metrics.

## Non-goals

- No change to the buoyancy model's physics or to the Buoyancy card, which
  keeps modelling the primary computer.
- No component lines (suit, tanks); net only.
- Not on the profile editor, the estimated-profile chart or dive comparison.
- No overlay lines for the computers that are not being drawn. The chart
  shows one buoyancy line, for whichever computer it is drawing.

## Anti-goals

- No shading between the line and neutral. The diver chose this explicitly:
  shading covers the depth trace, which is what the line is read against.
- Colour must not be the only cue to the side of neutral (colour-blind
  divers). The tooltip names the side in words.

## Decided in conversation

- Approach A below (a profile metric like gas density and GTR).
- Two-colour line, no shading.
- One legend entry, "Buoyancy", with a two-colour swatch.
- A default-visibility setting, off by default.
- Proposals the diver accepted without change: a dashed neutral rule; the
  right-axis range always includes 0; the tooltip names the side
  ("+0.9 kg buoyant", "-2.4 kg heavy"); weights follow the diver's weight
  unit; the toggle is absent when the model cannot run for the dive.
- Multi-computer dives: the line models whichever computer the chart is
  drawing, using that computer's samples and tank pressures (not the
  primary's line laid over another computer's depth, and not hidden).
- The dashboard's recent-dive preview shows the line too when the default
  is on.

## Approaches considered

| | Approach | Trade-off | Verdict |
| --- | --- | --- | --- |
| A | New profile metric. Net buoyancy is passed into `DiveProfileChart` as a per-sample curve and drawn as runs of one sign, each run its own `LineChartBarData`, like the ascent-rate-coloured depth line (`velocityBandRuns`). | Reuses the chart's metric band, zoom, right axis, legend and tooltip machinery. More bars when the line crosses neutral often. | **Chosen.** |
| B | One bar with a hard-stop vertical gradient at neutral. | One series, but fl_chart sizes a bar gradient to the bar's own bounds, which move with zoom and clipping, so the colour switch drifts off zero. | Rejected: the switch at zero is the point of the feature. |
| C | A separate painter overlay on top of the chart, like `counterdiffusion_overlay.dart`. | Full drawing control, but zoom, pan, cursor and tooltip would all need re-implementing. | Rejected: duplicated logic. |

## Current state (what the builder starts from)

- `buoyancyTwinProvider(diveId)`
  (`lib/features/dive_log/presentation/providers/buoyancy_twin_provider.dart`)
  returns `BuoyancyTwinOutcome?`. It is null when the dive is unmodelable
  (no tanks and no suit, such as apnea). The simulation runs in an isolate.
- `runBuoyancyTwin` (`lib/core/buoyancy/buoyancy_twin.dart`) emits one
  `TwinSample` per profile sample, carrying the sample's `timestamp`, from
  the isPrimary-filtered `diveProfileProvider`. `TwinSample.netKg` is the
  value to draw (positive is buoyant).
- The dive page already watches the provider to decide whether to show the
  Buoyancy card (`dive_detail_section_gates.dart`), so on that page the
  model is usually computed anyway.
- Secondary metrics are normalized into a `MetricBand` of the depth axis
  (`profile_metric_band.dart`) with the right axis labelling them.
  `ProfileRightAxisMetric` (`lib/core/constants/profile_metrics.dart`)
  lists the metrics the right axis can show. An unknown stored name parses
  back to temperature, so an older peer reading "buoyancy" is safe.
- Closest precedent for the setting: `default_show_counterdiffusion`
  (#4530, schema v366, commit `0962e3bf9a3`), which touched the table,
  rung, beforeOpen backstop, sync serializer, conflicts catalogue,
  repository, settings provider, default visible metrics page, legend
  provider, chart options and their tests.
- Closest precedent for drawing: gas density (`densityCurve`, `_showDensity`
  in `dive_profile_chart.dart`) for a per-sample metric curve, and
  `velocityBandRuns` for splitting one line into coloured runs.

## Design

### Data: which computer is modelled

- A new provider, `chartBuoyancyTwinProvider(diveId)` (name is the
  builder's), returns the model for the series the chart draws:
  - `activeSourceProfileProvider(diveId)` is null (a single-source dive, or
    the sequential halves of a Combine): return `buoyancyTwinProvider`'s
    outcome unchanged, so the dive page shares one computation with the
    Buoyancy card.
  - The active source is the primary source: the same, for the same reason.
    (The builder confirms the primary `SourceProfile.points` equal what
    `diveProfileProvider` feeds the card, edited rows included; if they can
    differ, model the active points instead.)
  - Otherwise: assemble the model from the fully hydrated dive with
    `profile` replaced by the active source's `points`, and with
    `activeSourceTankPressuresProvider(diveId)` for the pressures, then run
    `runBuoyancyTwin` in an isolate exactly as `buoyancyTwinProvider` does.
    Calibration and body weight are the same inputs the card uses. A
    computer with no pressure series for a tank gets the assembler's
    existing estimated-pressure behaviour, as the primary does today.
- Because the twin emits one sample per input point with that point's
  timestamp, the curve aligns with the drawn series by index. The builder
  still matches by timestamp and leaves a gap (null) for any sample
  without a twin sample, so a mismatch shows as a gap, never a shifted line.

### Data: wiring

- `DiveProfileChart` gets a new optional input, `buoyancyCurve`
  (`List<double?>?`), aligned to `widget.profile` by index. Values are net
  buoyancy in kilograms.
- Every surface that draws a logged dive's profile with the legend state
  passes it: `DiveProfileChartHost` (the dive page, its pinned strip's
  live copy, the dashboard's recent-dive preview and the planner's
  logged-dive chart), `dive_profile_panel.dart` (the dive list's
  master-detail pane) and `fullscreen_profile_page.dart`. While the
  provider is loading or returns null, the curve is null.

### Cost constraint (dashboard)

- The dashboard preview renders on the dashboard's first frame, a path the
  code keeps lean. A surface must not run the simulation while the
  buoyancy line is off there, except where the model is already being
  computed for another reason (the dive page's Buoyancy card).
- How availability is known without the simulation is the builder's call.
  Acceptable answers: a cheap pre-check (the assembler returns null without
  running the isolate) for offering the toggle, with the simulation
  started only once the line is on; or offering the Chart options row
  whenever the dive has a tank or an exposure suit, and dropping the legend
  entry if the model then returns null.

### Availability

- The legend candidate and the Chart options row appear only when the curve
  has at least two non-null values (a `hasBuoyancyData` flag in
  `ProfileLegendConfig`, like `hasO2CellData`).
- When the setting says "on" but the dive has no buoyancy data, nothing is
  drawn and no entry appears, matching how other data-gated metrics behave.

### Drawing

- The line lives in the metric band like the other secondary metrics, and
  follows the viewport the same way (`metricsFollowViewport`).
- Value range for the band: from `min(minValue, 0)` to `max(maxValue, 0)`,
  padded by 10% of the span, with a minimum span of 1 kg equivalent so a
  dive that sits near neutral is not stretched into noise. Zero is always
  inside the range.
- The line is split into runs of one sign. A value of exactly 0 does not
  start a new run. At a sign change between two samples the builder either
  inserts an interpolated point at exactly 0, shared by both runs, or ends
  one run and starts the next on the shared sample. Prefer the interpolated
  point if metric bars do not feed the tooltip's spot-index mapping (they
  are tagged with `_tagAll`; verify); otherwise share the sample.
- Buoyant runs and heavy runs each use one fixed colour, added to
  `ProfileMetricColors` as `buoyancyBuoyant` and `buoyancyHeavy`.
- A dashed neutral rule spans the plot at the 0 value while the line is
  shown, in a neutral colour from the theme (outline or onSurfaceVariant at
  reduced alpha), thinner than the metric lines.
- No fill under or around the line.

### Right axis

- `ProfileRightAxisMetric.buoyancy` is added, so the diver can pick buoyancy
  for the right axis in Chart options and as the default right-axis metric
  in Settings. Its axis labels show signed values in the diver's weight unit
  ("+2 kg", "0 kg", "-3 kg"), with the same mapping as the line.
- Category: `ProfileMetricCategory.other`, unless the builder finds a
  better existing fit.

### Legend and Chart options

- One legend entry, "Buoyancy". Its swatch shows both colours side by
  side (half buoyant, half heavy).
- One Chart options row with the same label and swatch, toggling
  `ProfileLegendState.showBuoyancy`.

### Tooltip

- One row while the line is on, with the bullet in the colour of the side
  the value is on:
  - buoyant: "+0.9 kg buoyant"
  - heavy: "-2.4 kg heavy"
  - a value that rounds to zero at the displayed precision: "0.0 kg neutral"
- One decimal place, in the diver's weight unit, using the existing unit
  formatter.

### Default setting (synced)

- New `diver_settings.default_show_buoyancy` column, BOOLEAN, default
  false. Schema rung v370 at the time of writing (main is at 369); rescan
  open PRs and worktrees for claims right before pushing and renumber if
  taken.
- Re-asserted in `before_open_settings_columns.dart`. No backfill.
- Carried by the sync serializer and listed in the conflicts catalogue.
  An incoming null is treated as omitted (keep the local value).
- Repository, `settingsProvider` setter, default visible metrics page row,
  and the legend provider seeding `showBuoyancy` from it, all mirroring
  `defaultShowCounterdiffusion`.

### Explanations and docs

- An entry in the dive profile info sheet (`dive_profile_info.dart`):
  what the line is, that it comes from the buoyancy model on the Buoyancy
  card, and what the two colours mean.
- One line in `docs/user/dive-profiles.md`.
- New strings in every ARB file, with translations.

## Testing

- Provider: a single-source dive and a primary-active dive reuse the
  card's outcome; a secondary-active dive models that computer's points
  and pressures; switching the active computer changes the line.
- Cost: with the line off, the dashboard preview does not run the
  simulation.
- Unit: the curve builder (timestamp matching, gaps), the run splitter
  (sign changes, a value of exactly 0, a dive that never crosses), the
  value range (always includes 0, minimum span).
- Widget: the chart draws buoyant and heavy runs in their colours and the
  neutral rule only when on; the legend and Chart options show one entry
  only when data exists; the tooltip row wording for buoyant, heavy and
  neutral; the right axis labels when buoyancy is the right-axis metric.
- Settings: migration test for the new column, repository round trip,
  sync fallback for a null incoming value, default visible metrics page
  toggle, and the shared test fixtures (`mock_providers.dart`, settings
  page tests) the counterdiffusion change had to update.

## Left to the builder

- The exact two colours, provided that each is distinct from depth blue
  (`AppColors.chartDepth`), they are clearly distinct from each other
  including for common colour-vision deficiencies, and both reach at least
  3:1 contrast against the chart surface in light and dark themes
  (`contrast_ratio.dart`). PR screenshots show them in both themes.
- Interpolated crossing point versus shared sample (see Drawing).
- The metric category for the right-axis picker.
- Where the curve-from-outcome helper lives (a small pure function in
  `lib/features/dive_log/presentation/utils/` or next to the provider).
