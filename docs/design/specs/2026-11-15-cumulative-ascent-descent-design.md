# Cumulative ascent and descent, against trenches and mountains

Date: 2026-11-15
Status: approved 2026-11-15
Release: v1.8.5
Issue: #4569

## Intent

A diver's logbook holds a number nobody adds up: how far they have gone
down, and come back up, across every dive. This feature adds it up and
draws it against things people know the size of. "Your descents add up to
the Titanic. Your ascents add up to Kilimanjaro."

It is a novelty number. It teaches nothing about safety or technique, so
the picture is the feature and the figures support it. It should be fun to
look at, fun to poke at, and honest about how the number was made.

## Goals

- One card on Insights > Profile showing total descent and total ascent on
  a vertical scale: sea level in the middle, descent sinking past ocean
  landmarks, ascent rising past mountains.
- Pointing at any level of either bar says when the diver's running total
  reached it, and opens the dive that got them there.
- Works for every diver: a new diver with ten dives, a diver whose whole
  logbook is hand-typed, and a diver with thousands of dives.
- Opens instantly after the first load, however large the logbook.

## Non-goals

- No new Insights page, route, landing tile or navigation shortcut.
- No per-dive figure on the dive detail page, in lists, in exports or in
  the query language. The per-dive value exists only to feed this card.
- No achievements, badges or notifications when a landmark is passed.
- No sharing or image export of the card.
- Prior-experience dives (the pre-app dive count on the diver) are not
  included. They carry no depths.

## Anti-goals

- A total inflated by sensor noise. A diver hovering at 20 m must not
  collect phantom metres.
- Two totals that differ for no reason the diver could name.
- A scale on which a beginner's bar is a sliver, or a veteran's bar runs
  off the top.
- A synced or backed-up copy of a number any device can work out again.

## What was decided

These were settled with the maintainer on 2026-11-15.

1. **Visualization: a vertical scale.** Chosen over a pair of
   next-landmark progress bars and over "multiples of one landmark" tiles.
2. **Date readout.** Hovering over part of either bar says the date the
   running total reached that level.
3. **Dives without a profile are estimated from max depth.** Such a dive
   counts once down to its max depth and once back up. That is the least
   it can have been, so the total never overstates. A line under the scale
   says how many dives were estimated.
4. **Past the top of the scale: multiples, plus bigger named landmarks.**
   The scale keeps growing. Marks become "2 x Everest", "3 x Challenger
   Deep" and so on, with larger named landmarks mixed in.
5. **Ascent and descent match exactly.** Every dive starts and ends at the
   surface, so each profile is counted from 0 m and back to 0 m, even when
   the computer started recording at depth or stopped early. Total descent
   and total ascent are the same number, drawn mirrored.
6. **Movement under 1 m is ignored.** A change of direction counts only
   once the depth has moved at least 1 m from the last turning point.
7. **Per-dive results are kept in a local cache table**, on this device
   only, keyed by a fingerprint of the dive's profile.
8. **The readout is a strip under the scale.** A hairline marks the level
   on the bar; a fixed strip below holds the level, the date and an Open
   dive action. Chosen over a tooltip that follows the pointer, from live
   mockups of both.
9. **Touch: tap, or hold then drag.** A tap on a bar selects a level.
   Press and hold on a bar, then drag, scrubs along it. An ordinary swipe
   always scrolls the page, even when it starts on a bar. Chosen over tap
   only and over the bar taking any drag that starts on it.

## Approaches

How the per-dive figure is produced. Three were considered.

- **Compute on read.** The pattern the two existing Profile cards use:
  decode every profile on a worker each time the card loads. No database
  change. Costs one more full pass over every profile each time the page
  opens.
- **Local cache table (chosen).** Store each dive's figure in the
  device-only cache database, keyed by a fingerprint of its profile, as
  the deco classification cache does (`DecoClassificationCache`, #623).
  Only new or changed dives are decoded. Adds a table, a fingerprint and a
  sweep entry; nothing is synced.
- **Column on the dive.** Compute at import and edit, store on the dive
  row. Fastest reads, but needs a schema rung, a backfill of every
  existing dive and sync handling for a value every device can derive.

The maintainer chose the cache table: later loads are instant and the
library database and sync are untouched.

## Design

### The per-dive figure

Each dive contributes one number, its **vertical distance**: metres
travelled downward, which equals metres travelled upward. Stored and
computed in metres.

**A dive with a primary profile.** Work on the dive's primary series only,
as the other Profile cards do, so a dive logged by two computers counts
once. Where one stream spans several series rows, interleave them by
timestamp first (`_forEachStream` already does this).

1. Take the depth samples in time order. Put a 0 m point before the first
   sample and after the last.
2. Walk the depths with a 1 m deadband to find the turning points: a
   reversal is confirmed only once depth has moved at least 1 m back from
   the running extreme. The surface points at both ends are always turning
   points.
3. The vertical distance is the sum of the descending legs between
   consecutive turning points. Because the path starts and ends at 0 m,
   the ascending legs sum to the same value.

A simple dive to 20 m gives 20 m. A dive to 30 m that rises to 12 m and
drops back to 18 m before surfacing gives 30 + 6 = 36 m.

4. If the result is less than the dive's stored max depth, use the max
   depth. A sparse or truncated profile must not count for less than a
   hand-logged dive would. (Builder's call, not discussed.)

**A dive with no primary profile.** Vertical distance is the dive's stored
max depth, and the dive is counted as estimated.

**A dive with neither.** It contributes 0, is not counted as estimated,
and is never the dive a readout points at.

Only depth is read. Samples with a non-finite or negative depth are
skipped. A corrupt blob is skipped, as elsewhere, and that dive falls back
to its max depth and counts as estimated.

### Which dives

The dives Insights already counts: the current diver, the active Insights
filter, and `DiveStatsScope` (planned dives and dives excluded from
statistics are out). With a filter on, the bars and the dates describe the
running total of the filtered dives only.

Dives are ordered by dive start time, ties broken by dive id, using the
ordering the Insights trend series already use.

### The cache

A new table in the local cache database (`LocalCacheDatabase`, next schema
version):

| Column | Meaning |
| --- | --- |
| `dive_id` (primary key) | The dive |
| `meters` | Vertical distance from the profile, before the max depth floor |
| `inputs_hash` | Fingerprint of everything that can change `meters` |
| `computed_at` | Epoch millis |

Local-only by construction: no HLC, never synced, never backed up.

`inputs_hash` is `v<algorithm version>|<series fingerprint>`. The series
fingerprint is built from the dive's primary series rows without reading
their blobs: each row's id, `updated_at` and `sample_count`, in stored
order. Changing the deadband or the algorithm bumps the algorithm version,
which invalidates every row with no purge.

The max depth floor is applied at read time from the dive row, not stored,
so editing a dive's max depth needs no invalidation.

Reading:

1. One query gets the scoped dives: id, start time, max depth, and the
   series fingerprint (null when there is no primary series).
2. One chunked query gets the cache rows for dives with a fingerprint.
3. Misses (no row, or a different hash) are decoded in chunks on a worker
   isolate, as `getAscentDescentRatesForDives` does, and written back.
4. A cache read or write failure is logged and the affected dives are
   computed without the cache. The card never fails because the cache did.

`LocalCacheSweep` gains an orphan sweep for the table, beside the deco
cache's.

`local_cache_database.dart` is at 784 lines against the 800-line limit, so
the table goes in its own file, as the site catalogue cache tables do.

### The running total

From the ordered per-dive figures, build a prefix sum: after dive *i*, the
running total is *T(i)*. The card's total is the last value.

"When did the running total reach *v*?" is the first dive whose *T* is at
least *v*, found by binary search. This is a pure function over the list;
it runs on every pointer move.

### Landmarks

Two ordered lists, in metres, each entry an id, a height or depth and a
localized name. The proposed lists are below. The figures are from memory:
during the build each one is checked against a cited source, and the
source is recorded in a comment beside the constant.

**Up (mountains and tall things).** Statue of Liberty 93, Great Pyramid of
Giza 139, Eiffel Tower 330, Empire State Building 443, Burj Khalifa 828,
Ben Nevis 1,345, Mount Kosciuszko 2,228, Mount Fuji 3,776, Matterhorn
4,478, Mont Blanc 4,806, Kilimanjaro 5,895, Denali 6,190, Aconcagua 6,961,
K2 8,611, Everest 8,849, Olympus Mons (Mars) 21,900, the edge of space
(Karman line) 100,000, the International Space Station 408,000.

**Down (ocean and deep places).** Recreational depth limit 40, Great Blue
Hole (Belize) 124, Dean's Blue Hole 202, Dragon Hole 301, deepest scuba
dive 332, Crater Lake 594, Lake Tanganyika 1,470, Lake Baikal 1,642,
deepest recorded whale dive (Cuvier's beaked whale) 2,992, average ocean
depth 3,682, Titanic 3,800, Bismarck 4,790, Molloy Deep (Arctic Ocean)
5,550, deepest shipwreck (USS Samuel B. Roberts) 6,895, Java Trench
(Indian Ocean) 7,192, South Sandwich Trench (Southern Ocean) 7,434, Puerto
Rico Trench (Atlantic Ocean) 8,376, Tonga Trench 10,820, Challenger Deep
(Mariana Trench) 10,935, Kola Superdeep Borehole 12,262.

**Multiples.** Above 8,849 m on the way up, every whole multiple of
Everest from 2 x onward is a landmark. Below 10,935 m on the way down,
every whole multiple of Challenger Deep from 2 x onward is a landmark.
These continue without limit and are merged in order with the named
landmarks above them (Olympus Mons falls between 2 x and 3 x Everest).

A landmark is **passed** when the total is at least its value. Its
**passed date** is the date of the dive that took the running total to it.

The lists are the maintainer's to edit at review; adding or dropping a
landmark is a constants change.

### The scale

One linear scale, shared by both halves, so the mirrored bars are the same
length.

- **Extent.** The scale runs from 0 to the larger of the two next unpassed
  landmarks (one up, one down), plus a little headroom for its label. The
  bars therefore always fill a good part of the card: a diver is never
  more than one landmark from the top.
- **Marks.** Every passed landmark is a candidate, plus the next unpassed
  one on each side, drawn dashed. Labels that would collide are thinned:
  the next unpassed landmark and the most recently passed one always stay,
  then others are kept from the top down while they fit. Thinned landmarks
  keep a tick without a label.
- **Bars.** Plain bars, ticks and labels: no illustration, silhouettes or
  background fill. Ascent rises in the green and descent sinks in the blue
  that the rates card on the same page uses for ascent and descent, so the
  two cards read as a pair. Both must read in light and dark. (Builder's
  call, not discussed.)
- **Headline.** Beside each bar, the total in the diver's depth unit and a
  line placing it: the next landmark and how far away it is ("1,956 m to
  the Puerto Rico Trench").
- **Layout.** One arrangement at every width, as in the mockup the
  maintainer chose: the bar in the middle, landmark labels to its left,
  headlines to its right. On a wide screen the scale is capped at a
  comfortable width and centred in the card; it does not stretch.
  (Builder's call for the wide case.)
- **Size.** A fixed-height card, about 480 logical pixels of scale.

The chosen mockup, in text. The bar is one column: green above sea level,
blue below. A tick marks a passed landmark; a dashed line marks the next
one on each side.

```
              Everest 8,849 m  - - - -
                                         6,380 m
       v Kilimanjaro 5,895 m  --|##|     total ascent
        v Mont Blanc 4,806 m  --|##|     2,469 m to Everest
        v Mount Fuji 3,776 m  --|##|
        v Burj Khalifa 828 m  --|##|
  ============================|##|==================  sea level
 v Deepest scuba dive 332 m  --|##|
           v Titanic 3,800 m  --|##|
                                |##|     6,380 m
                                         total descent
  Puerto Rico Trench 8,376 m  - - - -    1,996 m to the
                                         Puerto Rico Trench
     Challenger Deep 10,935 m (off the scale until passed 8,376 m)
```

Only the next unpassed landmark on each side is drawn; later ones appear
as the diver passes the one before.

### The readout

- **The strip.** A fixed strip under the scale, always present so the
  card's height never changes. With nothing selected it invites the diver
  to point at a bar. With a level selected it shows the level in the
  diver's unit and the date the running total reached it ("3,000 m of
  descent, reached 14 Mar 2023"), and an Open dive action.
- **The hairline.** A line across the bar at the selected level. Within a
  few pixels of a passed landmark it snaps to the landmark, and the strip
  names it: "Passed the Titanic on 2 Jun 2022".
- **Desktop:** moving the pointer over either bar selects the level under
  it, live. A click pins that level, so the pointer can leave the bar and
  reach the Open dive action; the strip shows it is pinned. A click on the
  card away from the bars unpins. While pinned, hovering changes nothing.
- **Touch:** a tap on a bar selects and pins that level. Press and hold on
  a bar, then drag, scrubs the level along it and leaves it pinned on
  release. A swipe is never claimed by the bars: the page scrolls. A tap
  on the card away from the bars unpins.
- **Opening the dive:** Open dive goes to the dive which took the running
  total to that level (`context.push('/dives/<id>')`, as single dives are
  opened elsewhere).
- Because the totals match, the same height on either bar gives the same
  date.
- Levels above the total (the dashed next landmark) have no date; the
  readout there says how far away it is.
- Dates use the diver's date format preference.

### Around the scale

- **Title and info.** The card uses `StatSectionCard` with an info sheet
  that says, in two sentences, what is counted and how: each dive from the
  surface and back, wobble under 1 m ignored, dives without a profile
  counted from max depth.
- **Estimated note.** When any dive was estimated: "*N* of *M* dives
  counted from max depth". Absent when none were.
- **Empty state.** No dives in scope with a depth: the card shows
  `StatEmptyState`, as the rates card does.
- **Loading and error.** As the rates card: a spinner at the card's
  height, and the standard error state.
- **Placement.** Directly under the "Ascent & Descent" rates card on
  Insights > Profile.

### A second card: max depths added up

Added during review at the user's request. A second card, "Max Depths
Added Up", sits beside the first and draws the same scale, strip,
landmarks and interactions from a different figure: each dive counts once
straight down to its stored max depth and straight back up, ignoring every
change of depth along the way. It sets the profile figure beside a plainer
one, so the diver can see how much the in-water up and down adds.

- **Data.** Read from the dives' `max_depth` alone, through the same dive
  query, scope and filter as the first card. No profile is decoded, so it
  needs no cache and loads at once even while the first card is still
  working out new profiles.
- **Dives counted.** A dive with no max depth is left out. No figure is
  ever estimated, so the card has no estimated note; it keeps an empty
  line for one only beside the first card (see Layout).
- **Info.** Its info sheet says that only each dive's deepest point
  counts and that dives with no max depth are left out.
- **Layout.** From 800 px of room for the cards (the page's content
  width, inside its padding and beside any navigation rail) the two cards
  sit side by side, ending level (the second keeps an empty note row);
  below that they stack. Chosen over a single card with two pairs of bars, which would have
  meant reworking the scale.
- **One scale.** Both cards are sized to the larger of their two scales,
  so the bars compare at a glance; the smaller card shows headroom above
  its bar. Until both have loaded, each card uses its own scale.

### Units and language

Every figure, including each landmark's height or depth, follows the
active diver's depth unit. All strings are localized in every supported
locale, landmark names included. Multiples are built from a localized
pattern ("{count} x {landmark}").

### Accessibility

The scale has a semantic summary: the total, the next landmark on each
side and the distance to it. Passed landmarks are exposed to assistive
technology as a list with their dates, each with an action that opens its
dive, so the date readout is not reachable by pointer alone. The list is
in the semantics tree only; it is not drawn, since dozens of rows would
not fit the fixed-height card. (Builder's call, not discussed.)

## Constraints

- Follows the diver's unit settings everywhere.
- No change to the library database schema, sync, backup or export.
- New files stay under the repository's size limits; the Profile page is
  at 495 lines, so the card is its own widget file, and the painter and
  the readout logic are separate from it.
- Pure logic (turning points, prefix sums, crossing lookup, landmark
  merge, label thinning) is free of Flutter and tested directly.

## Left to the builder

- Exact wording of every string, within the two-sentence cap on info text.
- The headroom fraction, tick lengths, label thinning thresholds and the
  card's exact height.
- Whether the series fingerprint and scoped dives come from one query or
  two.
- The chunk size for cache writes.
- File and class names.

## Testing

- Unit tests for the per-dive figure: a simple dive, a multi-level dive, a
  sawtooth under and over the deadband, a profile that starts and ends at
  depth, a single-sample profile, an empty one, and the max depth floor.
  Expected values are computed by hand in the test, not copied from the
  implementation.
- Unit tests for the running total and the crossing lookup, including a
  level exactly on a dive's total and dives contributing 0.
- Unit tests for the landmark merge with multiples, and for scale extent
  and label thinning at small, middling and very large totals.
- Repository tests over a real in-memory database: cache hit, miss, stale
  hash, a dive with no profile, the Insights filter, excluded and planned
  dives, and a failing cache.
- Widget tests for the card: headline and estimated note in metric and
  imperial, the readout on hover and on tap, the empty state, and the
  semantic summary.
