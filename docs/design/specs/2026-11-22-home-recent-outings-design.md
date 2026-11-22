# Home: Recent Outings Postcards: Design

**Date:** 2026-11-22
**Status:** Awaiting approval
**Release:** v1.8.5
**Feature area:** `lib/features/dashboard/`, `lib/features/settings/`

## Why

The upper part of Home looks stark, most of all on a phone. The Activity
calendar covers a fixed window (6 months on a phone, 12 on desktop), and most
recreational divers log their dives in one to three trips a year, so for most
of the year the window is empty: a grid of grey cells reading "0 dives · 0
days", with unused space below the grid. The maintainer's own log (36 dives in
five outings, the last one 199 days ago) shows exactly that. This is the
common case, not an edge case.

Home should instead show the diver's own diving near the top, in a way that
looks good with a short or sparse history, on phone and desktop alike.

## Goals

- A "Recent outings" panel: one postcard per recent outing, with a cover
  photo from that outing, its name, dates and a few numbers.
- Never empty while the diver has at least one dive, however long ago.
- Looks intentional for outings with no photos.
- Works at phone, tablet and desktop widths.
- Fix the trend lines in the key number tiles, which are clipped at zero.
- On a phone, no key number tile sits alone on a half-empty row.

## Non-goals

- No change to the Activity calendar panel itself. It stays available and
  stays in the Trends preset.
- No new data collection and no database schema change.
- No change to how trips are created or how dives are linked to trips.
- No temperature colouring (the mockup's colour came from water temperature;
  most divers' outings sit in a narrow temperature band, so it carried little).

## Anti-goals

- Home getting slower to open: no profile sample decoding for this panel, and
  a dives summary query, two small media queries, and a whole-trips query
  only for a log longer than the read (see Data).
- Copying photos into app storage. Covers are the existing media links, shown
  through the existing thumbnail path.
- Rewriting a layout the diver arranged themselves.
- A cover arriving late moving the rows below the panel.

## Approaches

Two rounds of choices, both decided with the maintainer.

**What to change at the top of phone Home.** (A) make the activity panel find
the diver's dives instead of a fixed window; (B) a "last dive" hero card; (C)
both. **A was chosen**: the activity panel is the part that looks worst and
the smallest change that fixes it.

**What the outings panel looks like.** After a first sketch (month bars with
outing labels) was judged still bland, three richer forms were mocked up with
the maintainer's real log, at phone and desktop width:

1. **Outing postcards (chosen).** A card per outing with a cover photo; an
   outing without photos shows its own depth skyline as the cover. The only
   form where the top of Home shows the diver's own diving rather than a
   chart, and it degrades well without photos.
2. Depth skyline. Every dive as a bar hanging from a surface line, grouped
   by outing. No photos needed, but still a chart, and month bars of a
   similar kind already exist in the Dives per month panel.
3. Map and journey. Outing pins joined in date order. Striking, but sparse at
   the zoom needed to show several trips, and the Recent sites panel already
   puts a map on Balanced.

## Outings

An **outing** is a group of the active diver's dives, counting the same dives
as every other Home number: planned dives and dives excluded from statistics
are left out (through `DiveStatsScope`), so a card's counts and depths agree
with the key number tiles above it (decided with the maintainer).

- Every dive linked to a trip belongs to that trip's outing.
- Dives with no trip are grouped among themselves, in date order: a dive joins
  the previous trip-less dive's outing when its local calendar day is no more
  than 2 days after that dive's day. Otherwise it starts a new outing.
- An outing's dates are the first and last local days of its dives (not the
  trip's planned dates).
- Outings are ordered newest first by their last dive.

Each outing carries:

| Field | Value |
| --- | --- |
| Name | The trip's name. For a trip-less outing, the name of the site with the most dives in it (ties: the site dived first). With no site on any of its dives, a localised "Dives" heading |
| Dates | First and last dive day, formatted as one localised range |
| Dives | Count of its dives |
| Max depth | Deepest maximum depth among its dives, shown in the diver's depth unit |
| Species | Distinct species sighted on its dives; omitted from the card when zero |
| Depths | Each dive's maximum depth in date order, for the skyline cover |
| Cover | One media item, or none (below) |
| Target | The trip, or the date range for a trip-less outing |

The grouping is a pure Dart function over a list of dive summaries, so it can
be unit tested without a database.

### Cover

Chosen from the photos and videos linked to the outing's dives through
`Media.diveId`, excluding orphaned rows, signatures and media linked only to a
site, in this order:

1. A favourite, photos before videos, earliest first.
2. One with a species tag in `MediaSpecies` (synced, so every device picks the
   same cover; the unsynced `MediaIdentifications` detections are not used),
   photos before videos, earliest first.
3. The earliest photo, then the earliest video.

With no media, or when the chosen item cannot be loaded, the cover is a map
of the outing's dive sites (added after review, chosen by the maintainer from
mockups): the app's tile layer with a diver pin per site that has a position,
fitted to all of them (a single site at the dive details header's zoom, 12),
not interactive, fading into the card's text strip only at its bottom edge.
Only when no site has a position is the cover the outing's depth skyline: a
thin surface line with one bar per dive hanging
below it, each as long as that dive's maximum depth. Every card's skyline uses
the same depth scale (the deepest dive among the outings shown), so a pool
session reads shallow beside a reef trip. Bars use the theme's primary colour
on its container tint; no colour is hard coded.

## The panel

A new panel, `HomePanelType.recentOutings`, titled "Recent outings".

- **Spec:** width class L, height class tall. Not conditional: like the
  Activity calendar, it is always present when switched on, and holds its own
  loading, empty and error states. (A conditional panel always forms a row of
  its own, which would stop it pairing with Gear service on desktop.)
- **Enum position:** declared directly after `activityCalendar`, so the
  existing reconciliation slots it in next to the calendar for stored layouts.
  Its stored name `recentOutings` is never renamed.
- **Trailing summary:** "5 outings · 36 dives" across the outings shown.
- **Content:** up to the last 8 outings.
  - Phone: one card at a time in a horizontal pager, the next card peeking at
    the right edge, page dots below.
  - Tablet and desktop: cards side by side at a minimum width of about 170
    logical pixels, as many as fit (4 in a desktop L panel); the rest scroll
    sideways.
- **Card:** cover on top, then name (one line, elided), dates, and a line of
  dives · max depth · species. Each card is its own tap target:
  - A trip outing opens `/trips/<id>`.
  - A trip-less outing opens the dive list showing exactly its dives, through
    the existing `openDiveList` helper with `DiveFilterState(diveIds: ...)`
    (the same "replace the filter" behaviour as the tag link). A date range
    would also catch trip dives on the same days.
- **Panel tap** (title area): opens the Trips list.
- **Loading:** the shared panel loading bar. The panel's height is fixed,
  so nothing below it moves when the cards arrive.
- **Empty (no dives):** a short line inside the panel ("Your outings will
  show here once you log a dive"); the existing First dive panel carries the
  call to action.
- **Error:** the shared panel error state.
- **Accessibility:** each card's semantic label states name, dates, dive
  count, max depth with its unit, and species count when present. The panel's
  label states its title and summary.

## Data

Reads, all scoped to the current diver and none watching any Insights-page
filter:

1. **Dive summaries:** id, dive date and time (the stored wall clock), trip
   id and trip name, site name, maximum depth and the species seen, for the
   diver's 301 most recent dives, newest first. Summary columns only; no
   profile samples. Only the newest 300 are grouped; the 301st says whether
   the log goes further back.
2. **Whole trips, only when the log goes further back:** every in-scope dive
   of each trip among those 300, however old, so a trip the read cut through
   still counts all its dives. A trip-less outing beginning within the 2-day
   join gap of the cut may still be missing dives, so it is left out unless
   it is the only outing.
3. **Cover candidates:** the photos and videos linked to the kept outings'
   dives, with favourite flag, type, taken time and whether a confirmed
   species tag exists.
4. **Cover items:** the chosen covers themselves, at most one per outing.

A failed cover read leaves every outing without a cover rather than failing
the panel. The provider invalidates itself when a dive, trip, site, sighting
or media item changes and when the local day changes, following the pattern
of the existing Home providers, and is not watched while the panel is hidden
(issue #4251).

## Presets

| Preset | Change |
| --- | --- |
| Balanced | `recentOutings` takes `activityCalendar`'s place (calendar becomes hidden) |
| Logbook | `recentOutings` added after the waiting-on-you run, followed by `latestVsAverage`, then `latestProfile`, `recentDives` and the rest as today. On desktop the first row is then outings (L) beside latest vs average (S) |
| Trends | Unchanged; keeps the calendar |
| Ready | Unchanged |

### No upgrade step

The panel-based Home (#4826) merged on 2026-11-22 and is in no release yet, so
no released install has a stored panel layout. A layout is stored only once
the diver changes it in Settings, and every install with nothing stored
already resolves to the current Balanced preset. The presets therefore simply
change, with no migration, no new preference and no frozen copy of the old
lists (decided with the maintainer). A beta tester with a stored layout keeps
it, with the new panel slotted in hidden by the existing reconciliation.

## Key number tiles

### Odd tile count on a phone

On a phone the tiles sit two across, so an odd number of tiles leaves the last
one alone on a full-width row with its right half empty. Decided with the
maintainer (option B of the lone-tile mockup): with an odd number of tiles on
a phone, the **first** tile becomes a full-width headline (its value larger,
its trend line widened to fill the space beside the value, with the series'
start and "now" marked under it) and the remaining tiles pair up below. An
even count, tablet and desktop are unchanged. The panel's height calculation
(`KeyNumbersPanel.heightFor`) accounts for the headline row so the grid row
still matches its content. A first tile with no trend line (for example when
the diver has hidden Dives) still takes the headline row, without a line.

### Trend line clipping

A tile's content is taller than the short row allows: on a phone the trend
line's 16-pixel box ends 3 pixels below the bottom of the tile's clipped
content area (measured: line box bottom 194, content bottom 191), and the line
draws its lowest values, zero included, in exactly those pixels. So a series
with empty months draws as broken dashes. The trend line instead takes only
the height left under the tile's text, at most 16 pixels, so it is never
clipped; the point mapping in `homeSparklinePoints` is unchanged.

## Settings

Settings > Appearance > Home lists the new panel with its switch and drag
handle like every other panel. The preset tiles draw their thumbnails from the
preset lists, so they pick up the change without further work.

## Translations

New strings (panel title, summary, card dates range and stats line, empty
line, the "Dives" fallback name, semantic labels) go in all 11 ARB files.

## Testing

- **Grouping (unit):** trip dives grouped by trip; trip-less dives split at
  gaps over 2 days and joined at 2; a trip-less dive between two trip dives;
  naming by most-dived site with the tie rule; no site; ordering by last dive;
  the 8-outing cap; local-day boundaries under a non-UTC time zone (CI runs
  under `Australia/Sydney`).
- **Cover choice (unit):** favourite beats identified beats earliest; photos
  before videos at each tier; orphaned rows ignored; none gives the skyline.
- **Stored layouts (unit):** a stored layout without the new panel gains it
  hidden, next to the calendar; nothing stored resolves to the new Balanced.
- **Key numbers (widget):** five tiles on a phone give a headline row plus two
  pairs, and the panel height matches; four and six tiles are unchanged;
  tablet and desktop are unchanged.
- **Presets:** lists hold only known panels, no duplicates; in Balanced and
  Logbook the row holding the outings panel fills its width at every tier
  (other presets keep today's rows, some of which are not full).
- **Panel (widget):** loading, empty, error and data states at phone and
  desktop width without overflow, in metric and imperial; card taps reach the
  trip route and the dive list filtered to the outing's dive ids; hidden panel's provider not read.
- **Trend line:** in a key number tile at phone and desktop width, at text
  scale 1 and 1.6, the trend line's box lies inside the tile's content area.

## Calls made by the author, for the maintainer to check

| Call | Reason |
| --- | --- |
| Trip-less dives join at a gap of 2 days or less | A weekend of shore dives stays one outing; separate weekends stay apart |
| Outing name is the trip name as written, elided | Shortening "Bonaire May 2026" to "Bonaire" would guess at the diver's naming; the dates line already shows the month |
| Up to 8 outings | Enough to swipe through a couple of years for most divers without loading a long history |
| Cover order: favourite, identified species, earliest | A favourite is the diver's own pick; an identified photo is likely a subject rather than a surface shot |
| Skyline in the theme's primary colour | Panels never hard-code colours; temperature varied too little to read |
| Panel is not conditional and shows an empty line with no dives | Keeps it pairing with Gear service on desktop; matches the other chart panels |
| Logbook gets the panel too, reordered for full desktop rows | Logbook is about the diver's own history, which this panel is |
| Ready and Trends unchanged | Ready looks ahead; Trends is the calendar's natural home |
| Panel tap opens the Trips list | Cards cover the individual outings; the panel title needs a destination |
| Planned dives are never part of an outing | They have not happened |
| A trip-less card opens exactly its dives | A date range would also list trip dives from the same days |
| Cover tier 2 reads `MediaSpecies` | Synced, so covers match across devices; a rejected detection cannot promote a photo |

## Left to the builder

- Exact sizes, paddings and type roles within the mockups.
- Query shape (one query or two) and where the grouping function lives under
  `lib/features/dashboard/`.
- The pager widget and how the page dots are drawn.
- How a cover's load failure is detected, as long as the card then shows the
  skyline rather than an empty box.

## Mockups

The mockups are kept, untracked, under `.superpowers/brainstorm/` in the
working tree used for this design (`outings-real.html` is the chosen set; it
uses the maintainer's own log and photos and is not to be committed).
Screenshots of the built panel go in the pull request.
