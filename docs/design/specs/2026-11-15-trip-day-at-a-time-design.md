# Trip page: one day at a time, picked from a strip of dive profiles

Date: 2026-11-15
Release: v1.8.5

## Intent

The trip page's Overview is "very busy", has poor visual separation between
its elements, and "feels like a wall of data" (the maintainer's words). From
the trip's first day onward it is one long scroll: a title block, a tinted
stat strip, and then for every day a tinted header band, a card, a map, a
tinted inner box of stats with a 24 hour bar and a conditions line, and dive
cards nested inside the day card. On a phone one day fills the screen, the
trip name and dates show twice, and the same four stats repeat for the trip
and for every day. Nothing is ranked, and there is no view where the whole
trip can be taken in.

An earlier answer to the same complaint (issue #4106, PR #4111) kept the long
scroll and merged surfaces. It was closed unmerged. This design changes the
structure instead: the page shows **one day at a time**, and the way to move
between days is a strip that draws the whole trip as its dives.

## Goals

- A diver opening a trip sees its shape at a glance: how many days, which
  days were dived, how deep and how long each dive was.
- A day's detail has the page to itself, with no other day competing.
- Trip-wide content (totals, notes, documents, vessel) has one obvious home.
- Less on screen at once, and nothing shown twice.

## Non-goals

- The Prepare page shown before a trip's first day
  (`TripPrepareOverview`) is unchanged.
- The other five tabs (Itinerary, Gear, Checklist, Dives, Photos) are
  unchanged.
- The trip list, its tiles and the Trips overview summary are unchanged.
- No new data is recorded, no schema change, no sync change.
- The dive card (`DiveListItem`) is not restyled.

## Anti-goals

- Restyling the same long scroll. That was #4111.
- A second look for a dive that exists nowhere else in the app.
- Any change that makes the trip story read dive samples again. The story
  read must stay sample-free (see Constraints).

## Today's page, for reference

`TripOverviewTab` shows `TripPrepareOverview` before the first day and
`TripStoryView` from then on. `TripStoryView`
(`lib/features/trips/presentation/widgets/story/trip_story_view.dart`) is one
`TodayAnchoredScrollView` of slivers: `TripStoryHero`, `TripStatStrip`, the
under-way cards (`TripCylindersSummaryCard`, `TripFlightCountdownCard`),
`TripVesselSection` for a liveaboard, one chapter per day
(`TripStoryDayHeader` over `TripStoryDayCard`), then notes and
`DocumentsSection`. A trip under way opens scrolled to today's chapter.

## Approaches considered

Each was mocked up on the same six-day trip at phone width and reviewed.

**How the page is structured**

| Approach | What it is | Trade-off |
| --- | --- | --- |
| Same page, calmer | Keep everything in one scroll; one surface per day, stats folded into the day's subtitle | Still about two days per screen. This is the kind of fix #4111 was |
| Outline | Each day folds to one line; tap to open it in place | Whole trip on one screen, but a day's detail still shares the scroll with the other days |
| **One day at a time (chosen)** | A day picker, then only the chosen day | A day's detail has the page to itself. Two days' detail are never visible together |

**How the day is picked**, within "one day at a time"

| Approach | Trade-off |
| --- | --- |
| Day strip with a dot per dive | Clear, but says nothing about the dives |
| Stepper (arrows on the day title) | Least chrome, no sense of the trip, five taps from day 1 to day 6 |
| Side rail down the left edge | Good on a wide pane, costs a fifth of a phone's width |
| **Depth drawn per day (chosen)** | The picker is a picture of the trip |

**How depth is drawn**, within the depth picker

| Approach | Trade-off |
| --- | --- |
| One bar per dive | Shows depth only |
| Bars placed by time of day, night shaded | Shows when, but bars are a few points wide on a phone |
| **A shape per dive, as deep as it went and as wide as it was long (chosen)** | Shows depth and length; not time of day |
| Shapes shaded by depth | Decoration, no new information |
| Selected day widens | Tiles move every time a day is picked |

Within dive shapes, a stand-in trapezoid from max depth and runtime was
weighed against **the dive's recorded profile (chosen)**. The recorded
profile turned out to be cheap: see Data.

**Where trip-wide content lives:** a leading tile in the strip that opens a
whole-trip page (chosen), over leaving a totals line pinned above every day.

**How a day's dives are listed:** the diver's configured dive card (chosen)
over plain fixed rows. Plain rows are quieter, but ignore the card
configuration and are a second look for a dive.

**The wide pane:** map beside the dives (chosen) over the phone layout
stretched.

## The design

### Structure

From the trip's first day onward the Overview tab is two parts:

1. **The picker**, fixed directly under the tab row. It does not scroll with
   the page. (Nothing on this page has been pinned since #2845; this
   reverses that on purpose, because a picker that scrolls away turns
   changing day into scroll, then tap.)
2. **The page** under it, which scrolls: either the Trip page or one day's
   page, according to the picker.

The trip's name is not repeated under the tabs. It is already in the app bar
on a phone and in the pane header in master-detail.

```
+--------------------------------------------+
| <  Red Sea Liveaboard            map edit  |   app bar (unchanged)
| Overview  Itinerary  Gear  Checklist  ...  |   tabs (unchanged)
+------+------+------+------+------+----+----+
| Trip | Wed  |[Thu ]| Fri  | Sat  |Sun |Mon |   picker, fixed
| All  | 28   |[29  ]| 30   | 31   | 1  | 2  |
|  =   |--v---|[vvv ]|-VVv--|-Vv---|-v--|----|   surface line, dives hang
+------+------+------+------+------+----+----+
| Thu, Oct 29                          31 C  |   the page (scrolls)
| Day 2 of 6, Big Brother                    |
| 3 dives, 2h 31m, 30.2 m max                |
| [ map of the day                         ] |
| [ 24 hour bar ]   Water 27 C, Vis 30 m     |
| [ dive card #142 ]                         |
| [ dive card #143 ]                         |
| [ dive card #144 ]                         |
| PHOTOS  [] [] [] +9                        |
| SPECIES SEEN  (chips)                      |
+--------------------------------------------+
```

### The picker

- **Tiles.** First a "Trip" tile for the whole-trip page, then one tile per
  entry of `story.days`, in order. A thin rule separates the Trip tile from
  the days.
- **Day tile.** Short weekday and day of month on top. Under them a surface
  line, with the day's dives hanging down from it, in start-time order, left
  to right, with a small gap between them.
- **A dive's shape** is its depth profile drawn as a filled silhouette:
  time runs left to right, depth runs down.
  - Depth uses **one scale for the whole trip**: the trip's deepest dive
    reaches the full height. That is what makes days comparable.
  - Width is proportional to the dive's runtime, on **one scale for the whole
    trip**, chosen so the busiest day fits its tile. A very short dive keeps
    a minimum width so it stays visible.
- **Selected tile.** Its column is tinted and its shapes take the strong
  primary colour. The other days' shapes are a muted tone of the same hue.
- **A dive that has not happened** (a draft, or a plan nobody has dived) is
  drawn as a dashed outline with no fill, on any day, whatever profile is
  stored for it. A planner-made plan is saved with its planned profile, so
  without this rule it would look like a logged dive. The dashed outline is
  the mark the app already uses for a profile that was not recorded.
  "Has not happened" is the app's existing undived rule (`diveUndivedSql`,
  `DiveTimes.isUndivedPlan`, issue #3924), not `isPlanned` alone: a dive
  mirrored from a buddy's logged dive is flagged planned but did happen, and
  draws as a real dive.
- **A day with no dives at all** (a surface day, or a day ahead with nothing
  planned) shows only the surface line: empty water.
- **Today**, while the trip is under way, is marked on its tile label in the
  same language the page already uses for today (`TodayChip`, primary
  emphasis).
- **Choosing.** A tap selects a tile. Selecting scrolls the page back to its
  top. Days are not changed by swiping: the tab view already owns horizontal
  swipes.
- **Long trips.** Day tiles keep a readable minimum width (about 38 points).
  When they do not all fit, the day tiles scroll sideways while the Trip tile
  stays fixed at the left. The selected day is brought into view when it is
  chosen and when the page opens.
- **Size.** On a phone the drawing is about 60 points tall under the labels.
  On the wide pane the picker spans the pane and the drawing is taller (about
  76 points), so the profiles are roughly twice the phone's size.

Reference values from the mockups, a starting point and not a contract.
Colours come from the theme's colour scheme in both light and dark mode;
nothing is hardcoded.

| Part | Mockup (light) | Likely token |
| --- | --- | --- |
| Surface line | `#3A5F8A` | `primary` |
| Selected column tint | `#DDE8F5` | `primaryContainer` |
| Selected shapes | `#244A73` at 55% fill, solid outline | `onPrimaryContainer` or `primary` |
| Other shapes | `#7F9CBD` at 45% fill, solid outline | a muted `primary` |

### A day's page

In order. Anything a day lacks is simply absent.

On **today's page while the trip is under way**, the cylinders summary and
the return flight countdown come first, above the head, under the same
conditions as today. The page that opens during a trip must show the no-fly
countdown without a tap. No other day's page shows them.

1. **Head.** Weekday and date as the title. Under it "Day N of M", the day
   type, port and site names as today's header shows them, and the day's
   totals as words: dive count, runtime, max depth. The weather badge sits
   at the right as today. Today keeps its chip; a day ahead keeps its
   Planned chip. The four-tile stat grid and its tinted box are gone.
2. **The day's map**, when the day has map points, with the expand button to
   the fullscreen day map as today. Tapping a pin still highlights that
   dive's card.
3. **The plan** (`TripStoryDayPlan`), when the day has one.
4. **The 24 hour bar and the conditions line**, untinted. The bar stays
   because the picker's shapes show depth and length, not time of day.
5. **The dives**, as `DiveListItem` cards exactly as today, directly on the
   page. They are no longer inside a day card. Planned dives and drafts are
   listed here as they are today.
6. **Photos**, then **species seen**, each under its small caption, as today.

There is no card around the day, no tinted header band and no tinted inner
box. The day is the page.

- **A surface day** shows its head and one quiet line saying there were no
  dives that day.
- **A day ahead** shows its head, its plan, and the cards of any dives
  already planned for it.

### The Trip page

In order:

1. A line with the date range, the length in days and the trip's country
   flags. While the trip is under way, the "Day N of M" line follows it.
2. The four trip totals (dives, runtime, max depth, sites visited), larger
   than body text, with no band behind them.
3. While the trip is under way only: the cylinders summary and the return
   flight countdown, under the same conditions as today. They also head
   today's page (see A day's page), so during a trip they appear in both
   places.
4. **One line per day**: day number, weekday and date, the day type, port and
   sites, and at the right the dive count and max depth. A surface day's line
   is muted. Today's line is marked. Tapping a line selects that day in the
   picker.
5. The vessel section, for a liveaboard.
6. Notes, when the trip has any.
7. Documents.

A trip with nothing in it yet (`story.isEmpty`) shows the existing empty
state and its "find dives" action on this page, in place of items 2 to 4.

```
+------+------+------+------+------+----+----+
|[Trip]| Wed  | Thu  | Fri  | Sat  |Sun |Mon |
|[All ]| 28   | 29   | 30   | 31   | 1  | 2  |
|[ =  ]|--v---|-vvv--|-VVv--|-Vv---|-v--|----|
+------+------+------+------+------+----+----+
| Oct 28 to Nov 2, 2026, 6 days, (flag)      |
|    10        8h 22m     40.0 m       6     |
|   Dives     Runtime    Max depth   Sites   |
| (1) Wed, Oct 28   Embark, Abu Dabbab  1 >  |
| (2) Thu, Oct 29   Big Brother         3 >  |
| (3) Fri, Oct 30   Daedalus Reef       3 >  |
| ...                                        |
| VESSEL     MY Blue Horizon ...             |
| NOTES      ...                             |
| DOCUMENTS  ...                             |
+--------------------------------------------+
```

### Where the page opens

- **A trip under way** opens on today. "Under way" is the rule
  `TripStoryView._opensAtToday` uses now: the story reaches today and
  `trip.isInProgress`.
- **Every other trip** opens on the Trip page.
- The selection is kept while that trip's page is alive, so leaving for
  another tab and coming back returns to the same day. A different trip in
  the master-detail pane starts fresh, the same way `TripDetailTabs` is keyed
  by trip id. It is not kept across app restarts.

### The wide pane

When the Overview is wide enough, a day's page puts two columns under its
head:

- **Left:** the map, the plan, the 24 hour bar, the conditions line, photos
  and species.
- **Right:** the day's dive cards.

So a tapped pin lights up a card that is already in view. The two columns
are one scroll: they move together under the fixed picker, and a pin tap
keeps today's behaviour of bringing its card into view only when it is off
screen. The map can be taller here than in the single column (about 230
points in the mockup). Below that width, and for a day with no map points,
the page is the single column described above. The switch is by measured width, not by platform, so a narrow desktop
window gets the single column too.

The Trip page stays one column at every width.

## Constraints

- **The story read stays sample-free.** `divesForTripProvider` reads through
  `getDivesByIdsWithoutSamples` (issue #3831, PR #3844), which is what made
  long trips open quickly. Statement-count tests pin it in
  `test/features/dive_log/data/repositories/dive_repository_without_samples_test.dart`.
  This design must not change that read or route more dives through the
  sampled path.
- **Units.** Every depth and temperature shown as a number goes through the
  active diver's `UnitFormatter`. The picker's shapes carry no numbers.
- **Theme.** Light and dark, from the colour scheme.
- **Text scale.** Tile labels and the day head grow with accessibility text
  sizes; nothing clips.
- **Project rules** that apply as always: tests first, files of 200 to 400
  lines (800 at most), new strings in every locale's ARB file,
  `test/architecture/` passing, and before/after screenshots in the PR in
  light and dark at phone and desktop widths.

## Data

- Everything on the Trip page and a day's page comes from the `TripStory`
  and `TripWithStats` the page already loads. No new query.
- **The picker's profiles** come from the app's existing mini-profile path:
  `DiveRepository.getBatchProfileSummaries`, through `DiveProfileBatcher`
  into `batchProfileCacheProvider`. That reader fetches downsampled profiles
  for a batch of dives in one query and decodes them on a background isolate.
  The dive list, the dashboard and the dive cards already use it.
  - The page asks for the whole trip's dive ids once, when it opens. The page
    appears from the story read alone; the shapes arrive after.
  - The cache is keyed by dive id only, so the picker must request at the
    reader's default resolution, the same one the dive list uses. A different
    sample count would leave the wrong resolution in a shared cache.
  - The reader gives three answers per dive, and the picker honours them the
    way the dive list does: a point list is drawn; an empty list means the
    dive has no samples, and it is drawn from `EstimatedProfile` with the
    dashed outline that marks an estimate (#4112); no entry means not known
    yet or unreadable.
- A shape is as wide as the profile it draws: a recorded profile's own time
  span, or an estimate's own span. The picker shows no duration as a number,
  so this never presents a bottom time as a runtime; the dashed outline
  already says the shape is an estimate. Runtime shown as a number (the day
  head, the day lines) keeps today's rules.

## Accessibility

- Each tile is a button. Its label says what the drawing shows: the day
  number, the date, the dive count and the deepest depth in the diver's unit;
  the Trip tile says it opens the whole trip. The selected state is put on
  the tappable node itself, not on a wrapper above it.
- On desktop, with the picker focused, the left and right arrow keys move the
  selection.
- A day line on the Trip page is a button named for its day.

## What the maintainer decided

- One day at a time.
- The picker is depth drawn per day, as a shape per dive.
- The shapes are the dives' recorded profiles.
- A leading "All" tile opens a whole-trip page.
- A dive that has not happened is drawn as a dashed outline in the picker.
- During a trip, the cylinders summary and the no-fly countdown sit at the
  top of today's page and on the Trip page.
- A day's dives are the configured dive cards.
- On the wide pane, the map sits beside the dives.
- The Trip page's content and order, where the page opens, the fixed picker,
  the surface day and the kept 24 hour bar were proposed and accepted as
  drawn.

## Calls made in writing this up

These were not discussed in detail. Each is the writer's call and can be
overruled.

- Depth and width each use one scale across the whole trip.
- The page scrolls to its top when the day changes.
- Selection is kept per trip while the page is alive, and not across
  restarts.
- A day with no map points uses the single column even on the wide pane.
- On the wide pane the two columns are one scroll, not two.
- A shape is as wide as the profile it draws, so a dive logged by hand is as
  wide as its estimate.
- The Trip page is one column at every width.
- The day's totals are words in the head, and the per-day site count is
  dropped, since the site names are listed beside it.
- The day's dive count, runtime and max depth, in the head, on the day lines
  and in the tile's spoken label, are computed as they are today, over all
  of the day's dives. The trip totals keep their own rule, which leaves out
  planned, draft and excluded dives, so the two can differ by a planned
  dive, as they can on today's page. Changing either count is out of scope.
- Both of the picker's scales cover every shape it draws, dashed ones
  included, so nothing overflows its tile.
- Upcoming trips, the other tabs and the trip list are out of scope.
- Tracking: issue #4106 states this same problem and is still open, with a
  different "approved design" (hero cards) whose PR #4111 was closed
  unmerged. This work reuses #4106: rewrite its approved-design section to
  this design, set its Release to v1.8.5, and have the PR close it.

## Left to the builder

- The widget breakdown and file names. `TripStoryView` will be largely
  replaced; `TripStoryDayCard` and `TripStoryDayHeader` are the source of the
  day page's parts.
- What is no longer used after the change and can be deleted. Two things
  stay: `TodayAnchoredScrollView`, which the Itinerary tab uses, and
  `TripStoryHero`, which the Prepare page uses. The empty state the Trip page
  needs is the private `_EmptyState` inside `TripStoryHero`, so it has to be
  lifted out to be shared.
- How the selection is held. `TripDetailTabs`' `TabBarView` does not keep an
  off-screen tab alive, so state inside the Overview widget would be lost on
  a tab change; it has to live above the tab view or in a provider keyed by
  trip id.
- How the picker is painted (a `CustomPainter` is the obvious fit), the
  exact tile sizes, the minimum dive width, and the transition between pages.
- What a tile draws while its profiles are still loading.
- How the page learns, per dive, whether a planned dive is undived, without
  adding a query per dive.
- The width at which the two columns switch on. Start near 600 points of
  Overview width and check it at real pane widths: at half the pane each
  column is about phone width.
- Whether a very long trip's profile request needs chunking.
- The wording of the new strings (the surface day line, the tile labels).

## Testing

Tests are written first. At least:

- The opening rule: under way opens on today, anything else on the Trip
  page.
- Selecting a tile shows that day and only that day; selecting the Trip tile
  shows the Trip page; a day line selects its day.
- Today's page during a trip leads with the cylinders summary and the flight
  countdown; no other day's page has them.
- A plan nobody has dived and a draft draw dashed; a mirrored dive that
  happened draws as a real dive.
- The Trip page's contents and order, including the under-way cards only
  while under way, and the empty state.
- A day's page contents and order; a surface day; a day ahead.
- The picker: one shape per dive in start order, shared depth scale, an
  estimated outline for a dive with no samples, nothing drawn for a day with
  no dives.
- A long trip scrolls the strip and keeps the selected day in view; the Trip
  tile stays fixed.
- The two-column layout at a wide width and the single column at a narrow
  one.
- Semantics: tile labels and the selected state.
- The existing statement-count guard on the trip dive read still passes
  unchanged.

The existing tests under `test/features/trips/presentation/widgets/story/`
(`trip_story_view_test.dart`, `trip_story_day_card_test.dart`,
`trip_story_day_header_test.dart`, `trip_stat_strip_test.dart`) describe the
page being replaced and are rewritten with it.
