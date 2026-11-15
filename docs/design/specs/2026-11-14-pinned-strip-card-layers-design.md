# Pinned profile strip: layers from the cards in view

Date: 2026-11-14. Release: v1.8.5.

## Intent

Dive details pins a thin, scrubbable profile strip at the top of the page once
the full profile card scrolls away (#4423, #4509, #4524, #4554). Today the
strip always draws the same thing: the depth line and shading, the NDL line,
the ceiling and deco stop bands, and the max-depth dot.

The diver uses the strip to enrich their understanding of the card they are
reading, over time. So the strip should show, on the dive's timeline, the data
of the cards currently on screen: reading the environment card puts the
temperature line on the strip; reading the cylinders card puts the tank
pressures and GTR there. Scrubbing the strip then reads those values back at
the cursor.

## Goals

- Each card that has time-series data behind it adds that data to the strip
  as a layer while it is in view.
- Several cards in view: all their layers show at once.
- Every change to the strip (a layer coming or going, the strip's height
  changing) fades or eases smoothly, never pops.
- The floating tooltip reads the value of every active layer at the cursor.
- The strip grows taller while any layer is on, so stacked lines stay
  readable, and returns to its current height when none is.

## Non-goals

- No per-layer settings or toggles. The existing "pin profile on scroll"
  setting (`diver_settings.pin_profile_on_scroll`) still turns the whole strip
  on or off, and nothing else is added. No schema change.
- No change to the full profile chart, or to the condense and hand-over from
  the full card to the strip.
- No axes or scale labels on the strip.

## Anti-goals (failure even if it works)

- Layers flickering on and off as a card's edge crosses the threshold during a
  slow scroll.
- Fades that trail the scroll noticeably (the reason approach 2 was rejected).
- The depth line's hand-over from the full chart breaking or showing two depth
  lines (#4423's guarantee).
- Scroll performance dropping: the strip repaints on every scroll frame while
  it shows.

## Card to layer mapping

| Card (`DiveDetailSectionId`) | Layer(s) | Data source |
| --- | --- | --- |
| `environment` | Temperature line | `DiveProfilePoint.temperature` |
| `tissueLoading` | CNS line, plus surface GF line | `ProfileAnalysis.cnsCurve`; `ProfileAnalysis.surfaceGfCurve` |
| `tanks` (cylinders) | One pressure line per tank, GTR line, plus a gas switch tick at each switch | `watchChartTankSeries` (as the cylinders card and full chart use); `ProfileAnalysis.gtrCurve`; `gasSwitchesProvider` |
| `sacSegments` (consumption) | SAC line, plus phase bands | `ProfileAnalysis.sacCurve`; `phaseSegmentsProvider` |
| `media` | A dot at each capture moment | `photoMarkersFromMedia` over `mediaForDiveProvider` (as the full chart) |
| `decoStatus` | TTS line | `ProfileAnalysis.ttsCurve` |
| `health` | Heart rate line | `DiveProfilePoint.heartRate` |
| `notes` | A tick at each annotation, and at each computer bookmark | `diveAnnotationsProvider`; `ProfileEventType.bookmark` events (`diveComputerEventsProvider`) |
| `safetyReview` | A window per finding, start to end | `safetyReviewProvider` findings with `startTimestamp` (and `endTimestamp`); dismissed findings excluded |
| `diveLab` | The linked plan's depth line, ghosted | `plannedProfileOverlayProvider` (the full chart's plan-vs-actual line, read without the chart's own plan switch) |
| `dataSources` | The dive's other computers' depth lines, ghosted | `sourceProfilesProvider`, every source but the active one |

The first five rows are the diver's. The diver later approved every other
row, after asking for more ideas of what each card could add. Every other
card adds nothing: altitude, tide, nav track (its map already follows the
shared cursor), sightings, weights, buoyancy, buddies, equipment, tags,
documents, custom fields, signatures, surface GPS, details. A running
mean-depth line for details was considered and dropped as low value.

**The full chart's own switches:** a card in view adds its layers even
where the diver has hidden that metric on the full chart (its legend or
options): the card being on screen is the stronger signal. Proposed in
design and not objected to. So the plan shows with Dive Lab in view even
with the chart's plan switch off.

A layer whose data the dive does not have (no temperature samples, no tank
pressure series, no media) draws nothing and adds no tooltip row, even with
its card in view.

**Estimated tank pressures (decided by the diver):** the strip matches the
full chart. Where `watchChartTankSeries` gives estimated pressure lines (the
diver's "show estimated tank pressure" setting on, no transmitter data), the
strip draws them, styled as the full chart styles estimates, and their tooltip
rows carry the same "(est.)" marking the full chart uses.

**Heart rate (decided by the diver):** the line rides with the Health card
only. The Health card shows only with an Apple Health record
(`diveHealthHasContent`), so a dive with computer or strap heart rate and no
Health record never shows the line on the strip. Accepted.

All data follows the active source (`activeDiveSourceProvider`), as the strip's
existing lines do.

## How each layer looks

- **Lines** (temperature, CNS, surface GF, each tank's pressure, GTR, SAC,
  TTS, heart rate): drawn over the depth shading, in the diver's chart colours
  (`ProfileMetricPalette.colorOf`), tanks in the full chart's per-tank colours.
  Each line has its own vertical range across the strip's curve area. Where
  `ProfileMetricBands` gives the metric a fixed band, the strip uses it, so a
  line sits where the full chart's right-axis metric does; otherwise the
  dive's own min and max for that series. All tanks share one pressure range
  so they compare at a glance.
- **Phase bands** (consumption): full-height translucent tints behind the
  depth shading, one per phase segment, in `SacSegmentColors.forPhase`, so
  the strip and the consumption card's timeline read as the same thing.
- **Media dots**: on the depth line at each capture moment, ringed in the
  strip's surface colour like the max-depth dot. Markers too close to tell
  apart cluster as the full chart clusters them (`clusterPhotoMarkers`).
- **Annotation and bookmark ticks**: a short tick at the top edge at each
  annotation's or bookmark's time, bookmarks in a distinct style from
  annotations so the two read apart.
- **Gas switch ticks**: a short tick at the bottom edge at each switch, in
  the new gas's colour (`GasColors`, as the full chart colours gases).
- **Safety finding windows**: a translucent full-height tint from a finding's
  start to its end in its severity's colour (as the safety review card
  colours severities), with a solid edge line at the start; a finding with no
  end shows as a tick at its start. Findings without a start time draw
  nothing.
- **Ghost depth lines** (plan, other computers): thin, low-alpha depth lines on
  the strip's own depth scale, styled as the full chart styles its plan and
  source overlays. They use the same mapping as the strip's depth line, so the
  deepest of all the drawn lines sets the depth range while one shows.

## When a card counts as in view

A card is in view only once all of it, or most of it, shows in the window
(decided by the diver after the first build, which used a lower bar of
96 px): at least 75% of the card lies between a fixed edge 72 px below the
page's top (the grown strip's bottom) and the bottom of the page's viewport.
A card taller than that room, which can never show 75% of itself, counts
once it fills 75% of the room. The edge is fixed, not the strip's current
bottom, so the strip growing cannot push a card back out of view. A card
already in view stays in until it falls 16 px below the threshold, so one
resting on it does not flicker with scroll jitter.

A card folded to its header row (the phone list layout) is not in
view, and is never measured, because its content is not built.

In the wide paired layout, both cards of a pair are measured independently.

## Motion

- Each layer has its own strength from 0 to 1, eased (about 250 ms,
  ease-in-out) toward 1 while its card is in view and toward 0 when not. A
  card scrolling out mid-fade reverses the fade from where it is.
- The strip's height eases from 44 px (`kPinnedStripHeight`) to 72 px while any
  **line** layer with data has its card in view, and back when none does, on
  the same curve. Media dots, ticks, phase bands, finding windows and ghost
  depth lines do not grow the strip: they stack no extra scales and read fine
  at 44 px (builder call).
- Layers and the extra height appear only once the strip is settled (condense
  at 1). As the strip starts to un-condense (scrolling back up toward the
  profile card), layers fade out and the height eases back, so the hand-over
  to the full chart's depth line runs as it does today.
- With the platform's reduce-motion setting on
  (`MediaQuery.disableAnimations`), changes apply without animating.

## Tooltip

While the cursor is set, the floating tooltip adds one row per active layer
with data, after its existing rows, in the mapping table's order: the value
at the cursor, formatted in the active diver's units (temperature, pressure,
SAC through the unit formatter). Phase shows the phase name (the consumption
card's own strings). A safety finding window under the cursor adds a row
with the finding's name (the safety review card's own strings). The plan adds
a "planned depth" row and each other computer a depth row named as the full
chart names that source. Media, annotations, bookmarks and gas switch ticks
add no rows. A layer still fading
in counts as active once its target is in view. The strip's semantics value
reads the same rows, as today.

## Approaches considered

1. **The overlay measures the cards (chosen).** `PinnedProfileOverlay` already
   records where the profile card sits in scroll-content coordinates after
   each layout and tracks the scroll offset on every frame. Each card in the
   mapping table gets a small marker at the single place
   `DiveDetailSectionList` wraps every section (its `KeyedSubtree`). The
   overlay measures the marked cards the same way and works out, per scroll
   frame and with arithmetic only, which are in view, then hands that set to
   the strip. Fades follow the scroll exactly and the measuring is already
   proven. Cost: more code beside a 517-line overlay, so the measuring lives
   in its own file. The section list wraps a section in three places (its
   `KeyedSubtree`, `_foldSection` for the phone list layout, and
   `ResponsiveSectionPair` for side-by-side pairs, which hold five of the
   mapped cards); the marker goes on the card in all three.
2. **`visibility_detector` package.** Rejected: a new dependency, callbacks
   batched (about 500 ms by default) so fades trail the scroll, and it does
   not know the strip covers the top of the page.
3. **Each card reports itself.** Rejected: the same scroll logic copied into
   every mapped card, and a new card that should add a layer is easy to miss.

## Decided how

- Approach 1, above.
- Each layer is painted by its own painter in its own fading layer, beside
  the existing `PinnedStripPainter` (already 453 lines), so layers fade
  independently and existing painting is untouched.
- The strip grows (72 px) rather than staying 44 px or stacking lanes; the
  diver picked this.

## Constraints

- Files stay within the repo's 800-line limit, 200 to 400 typical.
- Units follow the active diver's settings.
- New strings go through l10n (ARB files, every locale).
- No emojis; immutable data; `dart format`.
- Platform-agnostic; no new dependencies.
- `ensureVisibleBelowPinnedStrip` (scrolling to notes or the safety review
  lands below the strip) leaves room for the grown strip (72 px) whenever the
  strip will be pinned at the destination, since the strip may grow after
  landing. At worst that leaves a 28 px gap, never a card under the strip
  (builder call).

## Left to the builder

- The names and shape of the in-view set and how it reaches the strip (a
  value passed down from the overlay, or a provider keyed by dive).
- Exact easing curve and duration within "about 250 ms, ease-in-out".
- Line widths, dot and tick sizes, phase tint alpha: matching the strip's
  existing marks.
- Decimating each new series to `kPinnedStripPointBudget`, caching per
  series list as the existing layers do (`Expando`).
- How the overlay's geometry follows the strip's animated height (its box,
  the shadow clip, the tooltip's drop).
- Tooltip room: it is sized for five rows today and must fit the extra ones.
