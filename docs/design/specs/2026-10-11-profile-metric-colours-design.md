# Profile metric colours: design

Issue: #3012. Release: v1.8.2.

## Problem

Every metric on the dive profile chart has a fixed colour. Some are hard to
tell apart at a glance: ppO2 (Cyan 600, `#00ACC1`) reads as a second blue next
to the depth line (`#0077B6`). Divers want to choose the colour of each metric
so the ones they care about stand out.

## Outcome

A diver can give any recolourable profile metric a colour from a curated
palette. Colours stay unique: picking a colour another metric holds swaps the
two. The choice is stored per diver, syncs across devices, and applies
everywhere the metric's colour appears. Divers who never customise see exactly
today's colours.

## Behaviour

### Recolourable metrics (20)

Depth, temperature, pressure, heart rate, SAC, max-depth marker, ceiling, NDL,
TTS, GTR, CNS, OTU, ppO2, ppN2, ppHe, MOD, gas density, GF, surface GF, mean
depth.

These are modelled as a new `ProfileMetric` enum
(`lib/features/dive_log/presentation/profile_colors/profile_metric.dart`), one
value per metric above, in this order.

Not recolourable, because their colour carries its own meaning: the
ascent-rate safe/warning/danger bands, the deco-stop band, the O2 cell traces,
gas-switch markers and the gas timeline, and the pressure lines on a dive with
more than one tank (coloured per gas).

Also not recolourable, because nothing on the chart is drawn in their swatch
colour: events (each event line takes its severity colour) and the ascent-rate
line (since #2228 an `AscentRateBarOverlay` shaded red to green by rate).
Recolouring either would change only a legend swatch.

### Palette (26 swatches)

The 18 fixed default colours of the metrics above (every metric except
temperature and pressure), the two colours events and the ascent-rate line
keep for their swatches (Cyan 800 `0xFF00838F`, Lime 500 `0xFFCDDC39`), plus
six extras:

| Extra | ARGB |
| --- | --- |
| Light Green 700 | `0xFF689F38` |
| Deep Orange 400 | `0xFFFF7043` |
| Light Blue 400 | `0xFF29B6F6` |
| Purple A200 | `0xFFE040FB` |
| Pink A400 | `0xFFF50057` |
| Green A400 | `0xFF00E676` |

Order: the 18 defaults in `ProfileMetric` order, then Cyan 800 and Lime 500,
then the extras. The same
colour is used in light and dark mode.

Legibility, measured when the palette was chosen and pinned by a test:

- No two swatches are closer than CIE76 ΔE 10 (closest pair: NDL and MOD at
  10.2; each extra is at least 16.9 from every other swatch).
- Every swatch has a contrast ratio of at least 1.5:1 against white and
  against the dark chart surface `#121212`.

### Auto defaults

Two metrics have no fixed default colour:

- **Temperature** follows the theme's `colorScheme.tertiary`, as today.
- **Pressure** follows the per-gas colour (`GasColors.forGasMix`), as today.
  Its legend and dialog swatch keep showing `Colors.orange` while on Auto.

Both show an "Auto" swatch on the settings page until the diver picks a colour.
A custom pressure colour applies to the pressure line on a single-tank dive and
to that tank's pressure-threshold markers, so line and markers still match. A
dive with more than one tank keeps per-gas colours whatever the setting.

### Swap rule

When metric M takes colour C:

1. If another metric N currently shows C, N receives the colour M was showing.
2. If M was on Auto (so it was showing no palette colour), N instead receives
   the first palette colour, in palette order, that no metric shows.
3. If the colour N receives is N's own default, N's override is cleared rather
   than stored.

With 26 swatches and at most 20 metrics showing palette colours, rule 2 always
finds a free swatch. "Shows" means the effective colour (override, else fixed
default); Auto metrics show no palette colour and never take part in a swap
as N.

### Resets

- The palette sheet's leading swatch is "Default" (or "Auto" for temperature
  and pressure). Choosing Default is choosing the metric's default colour, so
  the swap rule applies. Choosing Auto clears the override; nothing swaps.
- "Reset all" on the settings page, behind a confirmation dialog, clears every
  override. It is disabled when nothing is customised.

### Where the colour applies

The chosen colour drives, for that metric: the primary trace, the overlaid
computers' traces (through the existing `overlayTint`), the cursor tooltip
bullet, the active legend, the chart options dialog swatch, and the right
Y-axis label and ticks when the metric is on the right axis.

`ProfileRightAxisMetric` (`lib/core/constants/profile_metrics.dart`) keeps its
own copy of the colours today, and it has drifted: its NDL is Light Green 700
while the chart draws NDL in Yellow 700. The right axis resolves through the
palette instead, which removes the copy and the mismatch.

`DiveProfileMiniChart` (list thumbnails) keeps the default depth colour, so
list rendering does not depend on diver settings.

## Storage and sync

### Schema v284

Shipped as v284: designed as v282, renumbered because PR #3133 holds 282
and #3296 shipped 283 first.


20 nullable `IntColumn`s on `diver_settings`, one per `ProfileMetric`, named
`profile_color_<metric>` (Dart getters `profileColorDepth`,
`profileColorTemperature`, ... `profileColorMeanDepth`; Drift names
`profileColorPpO2` `profile_color_pp_o2`). Each holds an ARGB int; null means
the metric's default (or Auto).

- The rung lives in `lib/core/database/migrations/ladder/rungs_v231_onward.dart`
  and calls `_assertProfileMetricColorColumns()` in
  `lib/core/database/migrations/helpers/diver_migrations.dart`.
- `beforeOpen` re-asserts the columns with a one-line call into that helper
  (`before_open.dart` is at the 800-line guard).
- No backfill: existing rows get null in every column and render today's
  colours.

### Domain

`AppSettings` gains one field, `profileMetricColors`, of an immutable value
type `ProfileMetricColorOverrides` (an unmodifiable map from `ProfileMetric` to
ARGB int, compared by value). It owns the swap rule, Default/Auto, reset, and
dedupe. A small mapping file beside the repository
(`lib/features/settings/data/repositories/profile_metric_color_columns.dart`)
maps the 20 columns to and from it; nothing above the repository sees
individual columns.

A stored colour outside the palette is honoured (a newer build may add
swatches). A fully transparent stored value is ignored.

### Dedupe on load

Sync conflicts resolve per field, so two devices can end up with the same
colour on two metrics. When overrides are read, a dedupe pass keeps the
first metric (in `ProfileMetric` order) that shows a colour and moves every
later holder to the first unused palette colour. The fix is written back on
the next settings save; reads never write.

### Sync

The columns travel in the `diverSettings` row like every other column. An
older peer that does not know them sends no key at all, and
`_withLocalForOmitted` (#2553) already keeps this device's value for an
omitted key, so an older peer never clears a newer peer's colours.

A null colour is a choice (Default, Auto or Reset all), so it syncs as a
value. The columns are deliberately not listed in `_nullMeansUnsetKeys`:
that would stop a reset on one device from reaching the others.

Each column has an entry in
`lib/features/settings/presentation/conflicts/catalogue/diver_settings_fields.dart`.
All 20 use one parameterised label, "Profile color: {metric}", filled from the
existing legend labels, and `FieldKind.enumValue` with a labeler that names
the stored colour as "{name} (#RRGGBB)". A null value shows the dialog's usual
"Not set". (The conflict dialog renders text only, so a swatch would need a
dialog change this feature does not otherwise need.)

### Notifier

- `setProfileMetricColor(ProfileMetric metric, Color? color)`: `null` means
  Default/Auto. Waits for the diver's settings to load (as
  `setTrendGapThreshold` does), applies the swap rule, and saves once (at
  most two columns change, plus any dedupe fix).
- `resetProfileMetricColors()`: clears all 20.

## UI

### Settings entry

On the Dives appearance page (`section_appearance_page.dart`), directly below
"Default visible metrics", a `ListTile` "Metric colours" whose subtitle reads
"Default colours" or "{n} customised". It pushes `/settings/metric-colors`.

### ProfileMetricColorsPage

`lib/features/settings/presentation/pages/profile_metric_colors_page.dart`.

- Depth first, then the chart options dialog's sections: Overlays
  (temperature, pressure, heart rate, SAC), Markers (max depth),
  Decompression (ceiling, NDL, TTS, GTR, CNS, OTU), Gas analysis (ppO2, ppN2,
  ppHe, MOD, gas density), Other (GF, surface GF, mean depth).
- Each row: the existing legend label, a trailing 28 px swatch (fixed width,
  as the ListTile trailing guard of #2717 requires). Auto metrics say so in
  the subtitle ("Auto: follows the theme", "Auto: each gas has its own
  color"); a custom pressure colour's subtitle says it is used on single-tank
  dives.
- App bar action "Reset all", disabled when nothing is customised, with a
  confirmation dialog.

### Palette sheet

A modal bottom sheet opened from a row.

- Leading "Default" (or "Auto") swatch, then the 26 palette swatches in a
  `Wrap`. Swatches are 36 px inside 48 px tap targets. The current colour is
  ringed.
- A swatch another metric shows carries that metric's short label beneath it
  ("NDL"), and its semantics hint says it swaps with that metric.
- Picking applies immediately and closes the sheet.
- Swatch semantics labels name the colour by the nearest (CIE76 ΔE) of the
  app's 22 named equipment colours, through `equipmentColorName`, so a screen
  reader says "Cyan" rather than a hex code. None of the 26 swatches is
  itself an equipment colour, so an exact-match lookup would name none.

### Chart options dialog

A "Metric colours..." `TextButton` at the bottom of the dialog closes it and
pushes the settings page.

## Chart wiring

- `profileMetricPaletteProvider` resolves `AppSettings.profileMetricColors`
  plus the theme into a `ProfileMetricPalette` with `Color colorOf(ProfileMetric)`
  and `Color? pressureOverride` (non-null only when pressure is customised).
- `DiveProfileChart`, `ChartOptionsDialog` and the active legend entries watch
  it.
- The pure builders (`profile_metric_line_builders.dart`,
  `partial_pressure_line_builders.dart`, `profile_metric_bands.dart`,
  `tank_line_builders.dart`) take colours as parameters instead of reading
  `ProfileMetricColors` statically.
- `ProfileMarker.getColor` takes the resolved max-depth colour and the tank
  colours, so a custom max-depth colour and a custom single-tank pressure
  colour reach the markers.
- The cursor tooltip's bullets hold literal copies of the colours today
  (`Colors.teal`, `Color(0xFF00ACC1)` and others); they read the palette too.
- `ProfileMetricColors` stays as the single source of default colours.

## Testing

TDD throughout.

- `ProfileMetricColorOverrides`: swap with a fixed-default holder, swap from
  Auto takes the first free swatch, receiving one's own default clears the
  override, Default and Auto, reset, dedupe order.
- Palette: 26 unique swatches, every fixed default present, ΔE and contrast
  floors above.
- Migration v282: columns exist and are null on an upgraded row.
- Sync: round trip of a non-null colour; a payload without the key (an older
  peer) keeps the local value; an incoming null (a reset) clears it.
- Settings notifier: `setProfileMetricColor` writes both swapped columns in one
  save; `resetProfileMetricColors` clears all.
- Widgets: the page lists 20 rows in their groups; the sheet labels a held
  swatch and its tap swaps; Reset all confirms and clears; the dialog link
  opens the page.
- Chart: a custom ppO2 colour reaches the line, the tooltip bullet and the
  legend; a custom single-tank pressure colour reaches the line and its
  threshold markers; a multi-tank dive keeps gas colours; the right axis uses
  the palette NDL colour.

## Follow-ups in this PR

- The right Y axis resolves colours through the palette, which fixes its NDL
  colour (Light Green 700) disagreeing with the chart's (Yellow 700).
