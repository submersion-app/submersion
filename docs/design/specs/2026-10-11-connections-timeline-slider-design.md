# Connections: interactive timeline slider

Issue: #3248 (part of #2321). Builds on year play, shipped with the Connections
explorer story phase (`2026-10-05-connections-explorer-story-design.md`).

## Goal

Year play grows the map one whole year per beat, and the only way to choose
a range by hand is a whole-year slider tucked into the panel's Filter tab.
The control over the canvas is a Play button next to a static "Years 2019 to
2023" label.

This change puts an interactive timeline beside the Play button on the
canvas: a two-thumb range slider at day resolution that updates the map live
while it is dragged, and a Play button that sweeps the end of the range
smoothly instead of stepping by years. The Filter tab gets the same control.

## Decisions

| Question | Decision |
| --- | --- |
| What the slider controls | Both ends of the date range (two thumbs), the same range the Filter tab slider sets |
| Resolution | Whole calendar days, the filter's own precision |
| When the map updates while dragging | Live, latest wins: a reload whenever the previous one has settled |
| What Play does | Smooth sweep of the end thumb; the whole first-to-last span takes 20 s |
| Filter tab | Same shared control replaces the year slider there |
| Canvas layout | A card along the bottom of the canvas: label row, then Play and the slider; full width on phones, capped at 560 px and left-aligned on wide screens |
| Architecture | One timeline notifier owns the on-screen range and commits it to the filter (approach A) |

## Data

`ConnectionsRepository.diveYearSpan` becomes `diveDateSpan`, returning the
first and last calendar day (wall-clock date, time of day dropped) with a
dive in scope, or null when there are none. The SQL is unchanged; only the
conversion of `MIN`/`MAX(dive_date_time)` changes from a year to a date.

`connectionsYearSpanProvider` becomes `connectionsDateSpanProvider`. Its
existing readers change as follows:

- The empty state's "has any dives" check reads `!= null` as before.
- The share caption's "All dives {first} to {last}" reads `.year` from each end.

The control hides when the span is a single day (today it hides below two
years).

## Timeline state

`ConnectionsTimelineNotifier` replaces `YearPlayNotifier`. It is
`autoDispose` and kept alive by the page for its lifetime, as year play is
today. Its state:

- `pending`: the day range on screen while a drag or the sweep is ahead of
  the map; null when idle, in which case the sliders show the filter's range.
- `playing`: whether the sweep is running.

### Committing

Whenever `pending` differs from the filter's range and no graph load is in
flight, the notifier writes `pending` into `connectionsFilterProvider`:

- An end at the edge of the span is left open (no `startDate` at the first
  dive day, no `endDate` at the last), so dives logged later stay on the map.
  A range covering the whole span therefore clears both dates (no filter at
  all), as the year slider does today.
- Any end inside the span is written as a calendar date.

It then waits for the page's existing `loadStarted` / `loadSettled` reports
before writing again. The page also reports from each build whether the graph
is loading, because its listener never hears about an initial load (the
first one, or a new node budget), and a write during one restarts it silently. Several drag moves during one load produce one write,
of the latest value. A write that starts no load (the graph is already
cached) counts as settled at once, so commits never stall. When a settle
finds `pending` equal to the filter's range, `pending` clears to null.

The notifier remembers the last filter it wrote, to tell its own writes from
the diver's.

### Dragging

- Grabbing either thumb stops the sweep.
- Each move sets `pending` and triggers a commit attempt.
- Release sets the final `pending`; it is always committed eventually.

### Play sweep

- **Start:** if the end already sits at the last dive day, the end jumps to
  the start thumb's day and grows from there; otherwise it continues from the
  current end. The start thumb never moves.
- **Pace:** the end advances at `spanDays / 20 s`, computed from elapsed time
  on a periodic timer so dropped frames do not slow it. The thumb moves on
  every tick, snapped to whole days; the map follows at whatever rate loads
  settle.
- **End:** on reaching the last day the sweep commits the final range and
  stops; the button returns to Play.
- **Stops** (as year play does today):
  - any filter change the notifier did not make (filter sheet, chip
    removal, Clear);
  - any view change other than the highlight mode (including loading a
    saved map);
  - a failed load (the page shows the reload error).

## Widgets

### `TimelineRangeSlider`

A `RangeSlider` over whole days from the first to the last dive day.

- **No `divisions`:** thousands of tick marks would smear into a bar, so
  values are rounded to whole days in code.
- **Values:** it shows the notifier's `pending` range when set, else the
  filter's range clamped to the span.
- **Accessibility:** screen readers get each thumb as a formatted date
  through `semanticFormatterCallback`.

### `TimelineControl`

A label row with the range in the diver's date format, built from
`UnitFormatter.formatDate` so it follows the date-format setting (for
example "3 Mar 2019 to 14 Aug 2021"). Below it, a row of the Play/Pause button
and the slider. The label updates live while dragging or sweeping.

### On the canvas

`ConnectionsTimelineBar` replaces `YearPlayPill`: the control inside a Card at
the bottom of the canvas with 12 px margins.

- **Phones:** it spans the canvas width above the bottom sheet, following
  the sheet's extent through the existing `bottomInset`.
- **Wide screens:** it is capped at 560 px and left-aligned.
- **Where it shows:** like the pill today, over the graph, the table views
  and an empty played range.

### In the Filter tab

`YearRangeSlider` is replaced by `TimelineControl` without the card, so both
places show identical, synchronised thumbs.

### Strings

| Key | English | Notes |
| --- | --- | --- |
| `connections_timeline_range` | `{start} to {end}` | new, String placeholders |
| `connections_timeline_play` | `Play timeline` | new |
| `connections_yearPlay_pause` | `Pause` | kept |
| `connections_yearRange_label`, `connections_yearPlay_play` | | removed |

All 11 locales get translations.

### Removed

`YearPlayPill`, `YearPlayButton`, `YearRangeSlider` and
`year_play_provider.dart`. Its `filteredYears` helper becomes a day-based
`filteredDays`.

## Edge cases

- **Day arithmetic:** calendar construction (`DateTime(y, m, d + n)`), never
  `add(Duration(days: n))`, so a DST change cannot shift a thumb by a day.
- **Filter dates outside the span** (set in the full filter sheet before
  the first dive or after the last) are clamped for display only. The filter
  is not rewritten until the diver drags.
- **Collapsed thumbs:** start equal to end is allowed and shows a single day.
- **Span changes mid-drag** (a dive synced in, a diver switch): the slider
  re-clamps to the new span and `pending` is clamped with it.
- **Leaving the page** cancels the sweep timer through the notifier's
  autoDispose.
- **Reduced motion:** the sweep still runs because the diver asked for it.
  Node movement already follows `MediaQuery.disableAnimations`.

## Testing

TDD throughout.

- **Repository:** `diveDateSpan` returns wall-clock calendar days, null with
  no dives, and respects the diver scope.
- **Notifier** (ProviderContainer plus fakeAsync):
  - Several `pending` updates during one load give exactly one write, of the
    latest value, after the settle.
  - A whole-span range clears the dates.
  - A write that starts no load does not stall later commits.
  - Sweep pace: after 10 s of fake time the end is at half the span.
  - Sweep start rules: from the start thumb when already at the end,
    otherwise from the current end.
  - The sweep stops on an outside filter change, on a view change other than
    highlight, and on a failed load.
  - The sweep ends with a commit at the last day.
- **Widgets:**
  - The slider shows the filter's range.
  - Dragging updates the label live and commits the release value.
  - Play/Pause toggles.
  - The control is hidden for a single-day span.
  - The label follows the date-format setting.
  - The bar is full width on a phone and capped at 560 px on a wide screen.
- **Rewritten tests:** the existing year-play and year-slider tests become
  timeline tests, and the page test checks for the bar instead of the pill.
