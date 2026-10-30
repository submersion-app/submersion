# Calendar day matrix (366-day dive matrix)

Issue: #3127. Release: v1.8.4.

## Intent

A diver wants to see two things about their diving across the calendar year,
regardless of which year a dive happened in:

1. **Patterns:** which parts of the year they dive in, and which they never do.
2. **Coverage:** how many of the 366 possible calendar dates they have dived on
   at least once ("265 of 366 calendar days, 72.4%").

The requester (issue author) built this in Excel from another logbook, after the
geocaching statistic of the same shape. The grid is 12 months by 31 days, one
dive count per cell, heat-coloured, with month and day-of-month totals and the
busiest month and busiest day of the month pointed out.

## Goals

- A new "Calendar days" card on **Insights > Time Patterns**, placed after the
  Seasonal card and before Surface Intervals.
- Headline: `<covered> of 366 calendar days (<pct>%)`, plus the busiest month
  and the busiest day of the month by name.
- Grid: months as rows (localized short names), days 1 to 31 as columns, one
  count per cell. Row totals on the right, column totals along the bottom, the
  grand total in the corner.
- Tapping a cell opens the Dives list filtered to that calendar date in every
  year, scoped by the current Insights filter.
- Works on phone and desktop with the same orientation.

## Non-goals

- No per-year view, year picker or comparison between years. The Insights filter
  (date range) already narrows the dives counted.
- No change to the existing Seasonal or Day of Week cards.
- No export of the matrix.

## Anti-goals

- Coverage must not be hard to read: a cell with zero dives has to look clearly
  different from a cell with one dive, even when the busiest cell holds 15.
- The phone layout must not shrink cells until numbers disappear (that option
  was considered and rejected).

## Decided with the maintainer

- **Placement:** Insights > Time Patterns card.
- **Purpose:** patterns across the year and coverage of the year.
- **Cell tap:** opens the filtered Dives list (same mechanism as the country and
  region rows on the Geographic page, `openInsightsDives`). Back returns to
  Insights.
- **Phone layout:** the same grid as desktop (months as rows), scrolling
  sideways, with the month-name column pinned on the left while the days
  scroll. The headline stays above the scrolling area.
- **Busiest month / day of month:** highlighted, as the issue asks.

The approved mockup is
[assets/2026-10-28-calendar-day-matrix-mockup.html](assets/2026-10-28-calendar-day-matrix-mockup.html)
(sample data; the phone option chosen is A).

## Behaviour

### What counts

- Dives in scope are exactly those the other Time Patterns cards count: the
  current diver, the Insights filter, and `DiveStatsScope` (dives marked
  "exclude from statistics" are not counted). Use the repository's
  `_diveFilter(filter, alias: ...)` with no `gas` or `consumptionRate` flags.
- The calendar date of a dive is its logged wall-clock date:
  `strftime('%m', dive_date_time / 1000, 'unixepoch')` and `'%d'`, the same way
  `getDivesByDayOfWeek` derives the weekday. `dive_date_time` stores the wall
  clock flagged as UTC, so no timezone conversion applies. A dive at 23:30 on
  6 May counts on 6 May wherever the device is.
- `dives.dive_date_time` is NOT NULL, so every dive in scope has a date.
- One query returns `(month, day, count)` rows grouped by month and day. The
  domain object derives everything else (totals, coverage, busiest).

### Domain object

A pure, immutable value (for example `CalendarDayMatrix`) built from the rows:

- `count(month, day)`: 0 for a valid date with no dives; null (or a distinct
  "not a date") for 30 and 31 February and 31 April, June, September and
  November. 29 February is a valid date.
- `monthTotals` (12), `dayTotals` (31), `total`.
- `coveredDays`: number of valid dates with count > 0. Denominator is always
  366. Percentage to one decimal place, formatted with the locale's number
  format.
- `busiestMonths` and `busiestDays`: every month (or day of month) tied for the
  highest total. Empty when total is 0.
- `maxCount`: the largest single cell, for the colour scale.

### Card content

- Title "Calendar days", subtitle along the lines of "Dives on each date of the
  year, across all years". Uses `StatSectionCard` like its neighbours.
- Headline row: the coverage figure large, then "Busiest month: May" and
  "Busiest day of month: 16". Ties list every tied value ("May, August").
- Grid cell: the count, centred, tabular figures. Invalid dates show a muted
  `×` and are not tappable. Zero cells show `0` in muted text.
- Totals cells: bold, uncoloured. The busiest month's row-total cell and the
  busiest day's column-total cell get a highlight outline (ties: all of them).
  The highlight is not the only signal; the headline names them.
- Column headers 1 to 31; row headers are the localized short month names
  from `insightsMonthLabels(l10n)` (`presentation/formatters/distribution_labels.dart`),
  the same helper the Seasonal card uses, so both cards name months
  identically and no new ARB strings are needed for them.

### Colour

- One hue: the theme's primary colour. Cell background opacity rises with
  `count / maxCount` from a visible floor for count 1 up to full at `maxCount`.
  Zero cells use a faint neutral surface (not the primary hue). Text colour
  switches to the on-primary colour when the background is dark enough to need
  it. Must read correctly in light and dark themes.
- Exact curve and floor are the builder's call; the constraint is the anti-goal
  above (0 versus 1 is unmistakable).

### Layout

- Desktop / tablet: the whole grid fits the card width when there is room;
  otherwise it scrolls sideways as on phone.
- Phone: horizontal scroll for the 31 day columns plus the totals column, with
  the month-label column pinned. The totals row scrolls with the days. The
  cells stay large enough for a two-digit number and a tap target.
- Builder's call: the cell size, and whether the pinned column is a separate
  widget beside a scrolling grid or a two-dimensional scroll view.

### Tap

- Tapping a valid cell (count 0 or more) calls `openInsightsDives` with the
  current Insights filter narrowed by `month = M AND day = D`, built the same
  way `countryDivesFilter` ANDs onto the scope's query. `_withPlace` in
  `insights_place_dives.dart` is private; add a public sibling (for example
  `calendarDayDivesFilter(scope, month:, day:)`) in the same file, sharing the
  AND-onto-scope helper.
- Tapping a zero cell still opens the list (it shows the empty state). Builder
  may disable zero cells instead; call it out in the PR if so.
- The list shows dives excluded from statistics too, as the country rows do.

### New dive query fields

The dive query registry (`lib/features/dive_log/query/dive_query_entity.dart`)
gains two number fields beside `year`, so the cell tap can be expressed as a
filter:

- `month`: 1 to 12, `CAST(strftime('%m', {r}.dive_date_time / 1000, 'unixepoch') AS INTEGER)`.
- `day` (day of month): 1 to 31, `'%d'` likewise.
- Both: defined through the `_num` helper like `year`, with `emptySql`
  `dive_date_time IS NULL` (matching `year`), `sanity: (min: 1, max: 12)` and
  `(min: 1, max: 31)` (the validator rejects out-of-range values as
  `QueryErrorCode.outOfRange`), labels `query_dives_month` /
  `query_dives_day` (translated), wired through `query_label_lookup.dart`
  beside `query_dives_year`.
- Keys are plain `month` and `day`: no existing field key or alias uses them
  (the date grammar's "last 7 day" units are values, not keys).
- These become visible in the advanced query builder and query text
  (`month:5 day:6`). That is intended. Update the tests that enumerate date
  fields: `test/core/query/fixtures/fixture_registry.dart`,
  `test/core/query/presentation/query_completions_test.dart`,
  `test/features/query/presentation/query_labels_test.dart`.
- The Explore natural-language field list (`lib/features/explore/domain/explore_fields.dart`)
  does not include `year`, so `month` and `day` stay out of it too.

### Empty and loading states

Follow the other Time Patterns cards: the same loading indicator, error text and
"no data" message when the diver has no dives in scope.

### Accessibility

- Each valid cell has a semantics label such as "6 May, 14 dives" (localized,
  with plural handling), and is a button.
- Invalid cells are excluded from semantics.
- The headline carries the coverage and the busiest month / day in text.

## Localization

New ARB keys in `app_en.arb` with descriptions, translated into all 10 other
languages (ar, de, es, fr, he, hu, it, nl, pt, zh): card title, subtitle,
coverage line (with placeholders for count and percent), busiest month label,
busiest day label, cell semantics label (plural), and the two query field
labels. Regenerate the localization files.

## Docs

`docs/user/statistics.md`: add the calendar days matrix to the Time Patterns row
(line 101) and, if the page has per-card detail, a short paragraph on reading
it and tapping a cell. No user doc lists query fields, so the new fields need
no doc entry.

## Constraints

- `insights_repository.dart` is over 3,000 lines. The new query goes in a part
  file (`insights_repository_calendar_days.dart`) as an extension, following
  `insights_repository_time_of_day.dart`.
- New provider beside `divesBySeasonProvider`, with `_keepAliveWithExpiry`,
  watching `currentDiverIdProvider` and `insightsFilterProvider`.
- The card widget goes in its own file under
  `lib/features/insights/presentation/widgets/`; the page file only adds one
  section call.
- Files stay under 800 lines; tests first (TDD); `test/architecture/` and
  `test/shared/` pass after adding files.

## Tests (minimum)

- Domain: totals, coverage over 366, invalid dates, 29 February, ties for
  busiest, all-zero input.
- Repository: counts by wall-clock date (a 23:30 dive lands on its own date),
  diver scoping, Insights filter, excluded-from-statistics dives not counted.
- Provider: covered in `insights_providers_all_test.dart` if it enumerates the
  page's providers.
- Query fields: `month` and `day` compile and match the right dives; validation
  rejects 0 and 13 / 32.
- Widget: renders counts, `×` for invalid dates, headline text, highlight on
  busiest totals; tapping a cell opens the dive list with the month and day
  filter; phone width scrolls sideways with month labels still visible.

## Left to the builder

Colour curve, cell sizes, pinned-column implementation, and exact copy
wording within the meaning above.
