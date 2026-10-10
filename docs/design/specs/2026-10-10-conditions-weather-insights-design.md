# Weather and Conditions Statistics in Insights

Issue: #3118

## Problem

The Conditions tab in Insights charts water temperature, visibility, water
type, site type and entry method, but none of the surface weather a diver
faces (air temperature, sun, cloud, rain, wind) and only some of the other
fields in the dive form's Conditions group. Every one of those fields is
already stored on the dive, entered by hand or fetched from Open-Meteo, so
the gap is aggregation and charts, not data.

## Goal

Every chartable field of the dive form's Conditions group gets a statistic on
the Conditions tab, scoped by the Insights filter and the active diver, and
shown in the diver's units.

| Field | Status before | After |
| --- | --- | --- |
| Water temp, visibility, water type, entry method | charted | unchanged |
| Air temp, cloud cover, precipitation, wind speed, wind direction, humidity, surface pressure | not charted | new |
| Current strength, current direction, swell height | not charted (current is a Focus factor only) | new |
| Altitude, exit method | not charted | new |
| Weather description | free text | not charted |

## Page layout

The Conditions tab becomes four headed groups. Existing cards move into a
group but keep their behaviour, including their current empty states.

**Water** (existing cards): visibility pie, water type pie, water temperature
trend, water temperature by month, water temperature bands.

**Surface & weather** (new):

| Card | Chart | Bands or categories |
| --- | --- | --- |
| Air temperature trend | `TrendChartSection`, a point opens its dive | per dive |
| Air temperature bands | bar | °C: <10, 10-20, 20-25, 25-30, ≥30. °F: <50, 50-70, 70-80, 80-90, ≥90 |
| Cloud cover | pie | Clear, Partly cloudy, Mostly cloudy, Overcast |
| Precipitation | bar | None, Drizzle, Light rain, Rain, Heavy rain, Snow, Sleet, Hail |
| Wind speed | bar | km/h: <10, 10-20, 20-30, 30-40, ≥40. kts: <5, 5-10, 10-15, 15-20, ≥20 |
| Wind direction | bar | N, NE, E, SE, S, SW, W, NW, Variable, None |
| Humidity | bar | <40, 40-60, 60-80, ≥80 % |
| Surface pressure | bar | mbar: <900, 900-1000, 1000-1020, ≥1020. inHg: <27, 27-29.5, 29.5-30.1, ≥30.1 |

**Water movement** (new): current strength pie (None, Light, Moderate,
Strong); current direction bar (the same compass categories as wind); swell
height bar (m: <0.5, 0.5-1, 1-2, ≥2. ft: <2, 2-3, 3-6, ≥6).

**Site & access**: site type (existing), altitude bar by the deco altitude
groups (Sea level, Group 1, Group 2, Group 3, Extreme), entry method
(existing), exit method bar (new).

### Rules for the new cards

- **Bands per unit.** Each band set is defined in round numbers per display
  unit, as `waterTempBandEdges` already does, not converted from one set.
  Wind follows the app's wind unit (km/h when the depth unit is metres,
  knots otherwise), surface pressure follows `formatSurfacePressure` (mbar
  or inHg), swell follows the depth unit.
- **Display rounding before binning.** A stored reading is converted to the
  display unit and rounded to the precision the app shows it at before it is
  compared with an edge, so a value shown as "20°C" lands in the band that
  starts at 20. Precisions: air temperature 1 decimal, wind 0, humidity 0,
  surface pressure 0 (mbar) or 2 (inHg), swell 1.
- **Lower edge inclusive, upper exclusive.** The first band is open below and
  the last open above.
- **Every band is shown**, empty ones included, so a band chart keeps its
  shape. **Categorical bars show only categories with dives**, in natural
  order (calm to severe, clockwise compass, enum order), not by count.
- **Coverage line.** Under each new chart: "Based on 42 of 310 dives", where
  the second number is the dives in the current filter and the first is the
  dives with that field recorded. The text is plural-aware.
- **Unrecorded dives are excluded** from a chart and counted only in the
  coverage line. A blank or unrecognized stored enum string counts as not
  recorded.
- **Hidden when empty.** A new card with no recorded dive is not shown. The
  Surface & weather and Water movement headers hide when all their cards are
  hidden. Water and Site & access always contain existing cards, so their
  headers always show.
- **Altitude is the dive's stored value.** `Dive` has no effective altitude
  (the detail page shows a separate note when only the site has one), and
  decompression reads the dive's own value, so the chart does too.
- **Exit method is the stored value.** Exit method has no site fallback.

## Architecture

### Data: one query

A new part file `lib/features/insights/data/repositories/insights_repository_conditions.dart`
adds an extension `InsightsRepositoryConditions` on `InsightsRepository`
(the same split `insights_repository_focus.dart` uses, so the shared
`_diveFilter` stays private and the 3000-line main file does not grow).

`getConditionsRows({String? diverId, DiveFilterState filter})` runs one
`SELECT` over `dives` and returns one row for **every** in-scope dive, ordered
by `dive_date_time`: id, dive date time, air temp, cloud cover,
precipitation, wind speed, wind direction, humidity, surface pressure,
current strength, current direction, swell height, altitude, exit method.
Because every in-scope dive is returned, the row count is the coverage
denominator.

### Domain: pure Dart

Under `lib/features/insights/domain/conditions/`:

- `conditions_row.dart`: the per-dive value object. Enum columns are parsed
  from their stored names; blank or unknown strings become null.
- `condition_bands.dart`: a generic `BandCount` (`lower`, `upper`, `count`),
  per-unit edge functions for air temperature, wind speed, humidity, surface
  pressure and swell height, and a `countIntoBands` helper that converts,
  rounds to display precision, then bins.
- `conditions_stats.dart`: `ConditionsStats.fromRows(rows, units)` builds, in
  one pass, `totalDives`, the air temperature trend points (date, value, dive
  id) and one slice per card: a `CategoryStat<T>` (ordered non-zero counts
  and `recorded`) or a `BandStat` (all bands and `recorded`).

### Providers

- `conditionsRowsProvider`: watches the repository, current diver and
  Insights filter, with the same keep-alive expiry as the sibling providers.
- `conditionsStatsProvider`: watches `conditionsRowsProvider` and the unit
  settings only, so a unit change re-bins without re-querying.
- Each new group watches `conditionsStatsProvider`. Per-card `select`s
  would save nothing: the stats only change when the rows or the units do,
  and then every slice changes with them.
- `TrendChartIds.airTemp` is added for the air temperature trend's settings.

### Presentation

`insights_conditions_page.dart` is 449 lines, so new UI goes in
`lib/features/insights/presentation/widgets/conditions/`:

- `conditions_group_header.dart`: the group heading.
- `conditions_band_card.dart` and `conditions_category_card.dart`: reusable
  cards taking a slice, a label function, colours and a chart kind (pie or
  bar). Each renders nothing when `recorded` is 0 and shows the coverage line
  under the chart.
- One file per new group (surface and weather, water movement) plus the new
  site-and-access cards (altitude, exit method).

Labels reuse the existing localized enum names (cloud cover, precipitation,
current direction, current strength, entry and exit method, altitude group).
New l10n keys cover the group headers, card titles and subtitles, the
coverage line and the semantic labels.

### Errors and loading

The new cards share one query. While it loads, Surface & weather and Water
movement each show one spinner; if it fails, each shows one error card rather
than one per chart. The new altitude and exit method cards sit in Site &
access, whose header always shows for the existing cards, so they render
nothing while loading or on failure: the two groups above already report the
shared query's state. Existing cards keep their own providers, loading and
error states.

## Follow-up: water temperature rate in Fahrenheit

The existing water temperature trend formats its fitted per-year rate with
`formatTemperature`, which adds the 32-degree offset in Fahrenheit (0.1 °C a
year reads as about 32.2 °F). A rate is a difference, so it switches to
`formatTemperatureDelta`, which the new air temperature trend uses too.

## Testing

Written first, per the repo's TDD rule.

- `condition_bands_test.dart`: edges per unit; display rounding at each
  boundary; every band returned including empty ones.
- `conditions_stats_test.dart`: each slice's counts and `recorded`; blank and
  unknown enum strings counted as not recorded; categorical order and
  dropping of zero categories; total versus recorded; trend points sorted
  with dive ids; re-binning under °F, knots, inHg and feet.
- Repository test against an in-memory database: every in-scope dive
  returned, diver and filter scope honoured, every column mapped.
- Widget tests: a card with nothing recorded is hidden; a group header hides
  when all its cards are hidden; the coverage line renders; one error card
  per new group on failure; existing cards render under their new headers.
- `test/architecture/` and `test/shared/` guards, since `lib/` files are
  added.

## Localization

New keys are added to `app_en.arb` and translated into all ten locales (ar,
de, es, fr, he, hu, it, nl, pt, zh), inserted by anchor line. `flutter
gen-l10n` runs last.

## Out of scope

- Charting the free-text weather description.
- Changing the existing cards' empty states or adding coverage lines to them.
- Weather-driven Focus factors or observations.
- Any schema change.
