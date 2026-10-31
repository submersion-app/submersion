# Insights: open the dives behind a chart

Issue: #3805. Related: #3804 (tank filters in search, stays open), #2623
(country and region rows), #3127 (calendar days), #3806 (Not recorded filters).

Mockups: [assets/2026-10-30-insights-links-to-dives-mockup.html](assets/2026-10-30-insights-links-to-dives-mockup.html)

## Why

A diver reads a number on Insights, something looks wrong ("Not recorded: 12",
"Twin backmount: 40"), and has no way to see which dives make it up. The search
cannot answer it either: several of these categories are worked out by the app
and have no search filter. Today only countries, regions and calendar days link
to their dives.

The point of the feature is checking a number. So a link must open exactly the
dives the number counted. If "Saturday: 142" opens 145 dives, the feature has
failed even though it technically works.

## Goals

- Every Insights chart that counts dives by category opens the dives behind each
  category, including its Not recorded category when it has one.
- Dives with nothing recorded for a Conditions card can be reached from that card.
- The list opened holds exactly the dives the number counted, under the Insights
  filter in force at the moment of the tap.
- Reading a number stays possible on a phone without being taken to another
  screen.

## Non-goals

- New search or Refine filters. #3804 asks for tank filters in search; this
  feature reaches those dives by a link only, and the issue stays open.
- Changing what any chart counts, or the shape of any chart. Conditions cards do
  not gain a Not recorded row.

## Anti-goals

- A list whose count differs from the number tapped.
- A tap on a bar that a diver only wanted to read throwing them onto another
  screen.
- Search-syntax chips such as `month = 6` for a diver who only tapped a bar.

## Behaviour

### Tapping

Vertical bars and pie slices show the number first. The first tap marks the bar
or slice and shows a strip under the chart: `Saturday · 142 dives` and
`View dives`. Tapping `View dives` opens the list.

- Tapping the marked bar or slice again clears it. Tapping another moves the mark.
- The mark clears when the chart's data changes (a filter change, an edit).
- A bar with 0 dives can be marked and shows its number, with no `View dives`.
- Taps anywhere in a bar's column count, so a very short bar can be hit.
- The strip is the same on every platform. Hover tooltips on desktop stay as they
  are.

Everything that already shows its number, or has none hidden behind a touch, opens
with one tap and carries a chevron: pie legend rows,
`HorizontalCategoryBarChart` rows, the Overview's `_DistributionBarRow` rows, the
coverage line, and the deco tiles and hint. Ranking rows, calendar cells, countries
and regions already behave this way.

Back returns to Insights with its filter unchanged, as `openDiveList` already
does.

### What gets a link

| Page | What |
| --- | --- |
| Overview | Depth ranges (pie and bar rows), dive types (bar rows) |
| Time Patterns | Day of week, month, time of day, calendar days (already linked) |
| Progression | Dives per year, suit thickness |
| Profile | Deco tile, No deco tile, the "not recorded" hint |
| Conditions | Water type, entry method (each with its Not recorded row), visibility, water temperature bands, site type |
| Conditions | Air temperature, wind speed, humidity, pressure, swell and altitude bands |
| Conditions | Cloud cover, precipitation, wind direction, current strength, current direction, exit method |
| Conditions | The coverage line on every card that has one |
| Gas | Gas mix, tank configuration, extras |
| Social | With buddy, solo, not recorded |
| Geographic | Countries, regions (already linked) |

The coverage line, "Based on 42 of 310 dives", opens the 268 dives with nothing
recorded for that card. It is only a link while some dives are unrecorded.

These stay as they are:

- Time at depth (Profile) counts minutes, and SAC by tank role is an average: no
  set of dives adds up to either number. The same goes for the deco rate tile.
- Rankings that open their own page: buddies, dive centers, gear, sites, species,
  trips. Those pages list their dives.
- Gear findings and issue reports count findings, not dives.

### One kind of link: a list of dives

Every link, including the existing country, region and calendar links, opens the
dive list with `diveIds` holding the dives the number counted, plus a label for
the chip, and no other filter. This is what makes the list match the number: the
ids are the dives that were counted, so excluded and planned dives are out, and
the gas charts' narrower scope is honoured, without any extra condition.

The list is a snapshot. A dive edited out of the category stays in the list until
the diver goes back, when the chart shows the new number. For someone working
through strange data, a dive not vanishing the moment it is fixed is a benefit.

The Insights filter's own axes are not carried to the list. The ids were resolved
under that filter, so its chips would change nothing when removed.

### The top of the dive list

`DiveFilterState` gains a label beside `diveIds`. The chip reads
`Day of week: Saturday (142)`: the chart title, the row, and the number of ids.
For a coverage line it reads `Cloud cover: Not recorded (268)`, using the existing
Not recorded wording. Removing the chip clears both fields. Other setters of
`diveIds` pass no label and keep today's "12 dives" chip.

## Constraints

- **The number and the list must agree by construction or by test.** Every link
  has a database-backed test that the ids equal the dives the chart counted, for
  every category including Not recorded, with an excluded dive and a planned dive
  present. `insights_place_dives_test.dart` is the pattern, and its filter tests
  change with this design.
- **One rule, one place.** Ids must come from the chart's own binning, classifier
  or scope, never a second copy of the rule. For charts whose category an existing
  filter can state (country, region, calendar date, weekday, month, year, water
  type, entry method, dive type), one repository method resolves a narrowed
  `DiveFilterState` to ids through `_diveFilter`, so the statistics scope applies.
  `countryDivesFilter` and its siblings keep building that filter.
- **Scope per chart.** Gas mix counts under `_diveFilter(gas: true)`, which also
  drops gauge dives and dives excluded from gas statistics. Tank configuration uses
  the plain scope. Each link uses its own chart's scope.
- **Grouping keys.** A row must carry the stable key the count was grouped on
  (type id, enum name, bucket index), not its display label. Site type labels are
  not unique: two custom types can share a name.
- **Deco.** The tiles' counts include the computed classification, so their ids
  must come from the same classification the card uses.
- **Large rows.** A row can hold most of a logbook. `diveIds` lowers to one bind
  variable per id, so the list, its count, and the table and map views must work
  with a row of every dive in a large logbook. The builder checks SQLite's limit
  here and handles it if it can be reached.
- **`stat_charts.dart` is at 786 of 800 lines.** New chart behaviour goes in new
  files. `insights_place_dives.dart` is a place-only name; chart links get their
  own file. `insights_overview_page.dart` is already over the limit, so new code
  stays out of it where that can be avoided.
- **Screen readers.** Rows, legend rows, tiles, the coverage line and the strip are
  buttons with labels. Each non-zero bar of a vertical chart must be reachable
  without seeing it, since the chart itself is one summary label.
- **New filter field.** The label needs `copyWith`, equality (so `openDiveList`'s
  double-tap guard sees it) and clearing with `diveIds`. It filters nothing, so it
  does not count as an axis of its own.
- **Docs.** `docs/user/statistics.md` says excluded dives appear in the list a
  calendar cell opens. That stops being true, and the page gains this feature.
- **Strings** go in every ARB locale, translated, with `flutter gen-l10n` output
  committed. Dive counts use the existing plural forms.

## Left to the builder

- How ids reach the tap: kept on the stat (`ConditionsStats`,
  `TankConfigurationStats` and the time of day distribution already read every
  dive) or loaded by a repository method when `View dives` is tapped. Water
  temperature can use `getWaterTempBandPerDive`.
- The shape of the shared selection state and strip, and whether
  `DistributionPieChart` moves out of `stat_charts.dart` to make room.
- How a bar's column is hit-tested with fl_chart.
- The mark's visual treatment, within the mockup's intent. The Overview depth pie
  is its own `_DepthPieCard`, not `DistributionPieChart`, and needs the same
  behaviour.
- What `View dives` shows during a load and on a failed load.
- The wording of the new strings, close to the mockups.
