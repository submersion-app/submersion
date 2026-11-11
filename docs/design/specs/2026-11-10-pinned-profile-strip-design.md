# Pinned profile strip on dive details

Release: v1.8.5

## Intent

On the dive details page a diver scrubs the profile chart to pick a moment, then
reads the cards further down (tank pressure, SAC segments, buoyancy) against
that moment. Today the profile scrolls away as soon as those cards are on
screen, so the thing being scrubbed with is gone exactly when it is needed.

When the full profile card scrolls off the top of the page, it condenses into a
thin, scrubbable strip pinned under the page header. Scrubbing the strip drives
the same shared cursor as the full chart, so every card that already follows
the cursor keeps following it. The buoyancy chart joins that cursor, in both
directions. A setting turns the strip off.

## Goals

- A pinned strip (about 56 logical px) appears once the full profile card has
  scrolled off the top, and disappears when it scrolls back.
- The transition is a "genie" condense: the profile card condenses and squashes
  up into the strip as it leaves, and reverses as it returns.
- The strip is scrubbable (drag on touch, hover on pointer devices) and writes
  the shared cursor, `profileTrackingIndexProvider(diveId)`.
- The strip shows a values row at the cursor: time, depth, ppO2, and NDL or the
  current deco stop.
- The buoyancy chart shows the shared cursor, and hovering or touching it
  writes the shared cursor (two-way sync).
- A synced setting, on by default, turns the strip off.

## Non-goals

- No change to the full profile chart's own rendering, zoom, range selection or
  playback.
- The strip does not zoom or pan; it always shows the whole dive.
- No configurable strip contents (the values are fixed, see below).
- The fullscreen profile page is unchanged.
- The dive list's profile panel (`DiveProfilePanel`) is unchanged.

## Anti-goals (would make this a failure even if it works)

- The strip and the cards disagree about the moment, or show different values
  from the full chart for the same moment.
- The strip hijacks vertical scrolling on a phone, so the page becomes hard to
  scroll.
- The page jumps or reflows when the strip appears or disappears.
- With the setting off, the page behaves in any way differently from today.

## Decided by the user

- Applies everywhere the dive details page renders: phone, tablet, and the
  desktop master-detail pane.
- Layout is "option C": the depth curve on top, a single values row beneath it.
- The curve shows depth only (shaded, like the full chart), plus a cursor line
  and a dot on the curve at the cursor.
- The values row is a fixed set, independent of the chart options: **time,
  depth, ppO2, and NDL or deco stop**. The last slot shows NDL while within
  no-deco limits and the current stop (depth and time) once in deco.
- With no cursor, the values row shows a dimmed hint instead of values: "Drag
  to scrub" on touch, "Hover to scrub" on pointer devices. No cursor line is
  drawn. (The user considered the end-of-dive state and chose the hint.)
- When the cursor is released, the strip behaves as the full chart does today
  (touch end and mouse exit clear the cursor), so the two never disagree.
- Buoyancy cursor sync is two-way: either profile moves a marker on the
  buoyancy chart, and hovering or touching the buoyancy chart moves the cursor
  on both profiles and on every card that follows it.
- The condense animation matches the looping mockup reviewed in brainstorming:
  the card loses its inset margins and rounded corners to span the full page
  width, squashes in height, and rises to sit under the header.
- Setting: "Pin profile when scrolling", in Settings > Appearance with the dive
  profile options, on by default, synced like other diver settings. Off means
  the page behaves exactly as today. Buoyancy two-way sync is not gated by the
  setting.

## Current state (facts the design builds on)

- `lib/features/dive_log/presentation/pages/dive_detail_page.dart`: the body is
  one `SingleChildScrollView` using `DetailScrollController.maybeOf(context)`
  (from `lib/shared/widgets/master_detail/detail_scroll_retainer.dart`), falling
  back to its own controller when standalone. No slivers. Standalone mode is a
  `Scaffold` with an `AppBar`; embedded (desktop master-detail) mode is a
  `Column` of `DiveDetailEmbeddedHeader` plus the body.
- Sections render through `DiveDetailSectionList` in user order. The profile
  is `DiveDetailProfileSection` (`widgets/dive_detail/dive_detail_profile_section.dart`).
  The user can reorder sections, hide the profile section, or use the
  `DiveDetailLayout.list` layout where sections fold to header rows.
- Shared cursor: `profileTrackingIndexProvider`
  (`providers/profile_tracking_provider.dart`), a `StateProvider.family<int?, String>`
  keyed by dive id. Its value is an index into the chart's rendered profile
  (`watchChartProfile(ref, dive)`, the active source's series), never into the
  merged `dive.profile` (#543).
- Cursor readers today: chart host, deco status and tissue cards, SAC segments,
  tanks card. Buoyancy does not read it.
- No-cursor fallback in the deco card is the last sample. The full chart shows
  no tooltip with no cursor.
- The full chart clears the cursor on touch end and on mouse exit
  (`dive_profile_chart.dart` `_reportSelection(null)`; chart host `MouseRegion.onExit`).
- `resolveSample` (`widgets/instrument_sample.dart`) gathers depth, NDL,
  ceiling, TTS, ppO2 and more at one timestamp, preferring analysis curves and
  falling back to computer-recorded values. The fullscreen readout uses it.
- Analysis curves come from `sourceProfileAnalysisProvider((diveId, sourceId))`;
  `ProfileAnalysis` has `ndlCurve`, `decoStopCurve`, `ceilingCurve`,
  `ppO2Curve`, `decoStatuses`, `decoStopWindows`.
- `MiniProfilePicker` (`widgets/mini_profile_picker.dart`) paints a filled
  depth curve with `MiniProfilePainter` and reports tap/drag as seconds.
- Buoyancy: `BuoyancyChart` (`widgets/buoyancy_chart.dart`) is an fl_chart
  `LineChart` with x in minutes from `TwinSample.timestamp`, with its own
  tooltip. Rendered by `BuoyancySection`.
- Boolean setting precedent: `showMaxDepthMarker` (diver settings table column,
  `AppSettings` field, `SettingsNotifier` setter, repository read/write, sync
  serializer, conflict catalogue entry and l10n key, and a `SwitchListTile` in
  `section_appearance_page.dart` `_buildDiveProfileSettings`). Schema version
  is 357, so the new column needs a migration (359: open PR #4417 holds 358).

## The design

### When the strip shows

- Active when all of these hold: the setting is on; the profile section is
  rendered in the detailed layout (not hidden, not folded in list layout); and
  the dive has a chart profile of at least two points.
- The transition is driven by scroll position, not by a timer, so scrolling
  slowly plays it slowly and scrolling back reverses it. It starts the moment
  the card's top passes the top of the page and runs in three steps. This
  replaces the condense-only design after review in the running app (the
  user chose "squash the real chart"):
  1. **Squash.** A live copy of the whole card pins to the top, laid out to
     exactly the height of the card still on screen. Header and footer keep
     their size; the chart takes the shrink, with its axes, grid and every
     line intact, until its plot is 48 px. The range is measured from the
     copy's plot, since the axes and legend around it vary.
  2. **Slide.** The squashed card then scrolls up as the card itself would,
     header first, until its plot reaches the top.
  3. **Hand-over.** The strip fades in over the copy with its depth line
     exactly on the copy's (the copy's chart reports its plot rect and
     visible ranges), its line and shading cross-fading with its surface so
     shading never doubles; then it condenses into the 56 px strip.
  The squash and slide share the scroll in one motion. The fade starts a
  fifth of the way into it and ends exactly as the copy's plot reaches the
  top, because past that point the copy slides its plot out of view: no
  data on the chart is ever seen leaving the view. From there the strip's
  line is held at the top while it condenses.
- Whatever is drawn always covers all of the card still on screen, so the
  real card never shows around it. It is an overlay on the scroll view and
  takes no space in the scroll content, so the content never jumps.
- The strip's shading sits below the depth line in the full chart's depth
  gradient, on the card's colour; it casts no shadow while see-through and a
  shadow that grows with the condense after, so nothing flashes grey.

### Strip contents

- Curve: whole-dive depth curve from the chart profile, shaded like the full
  chart, using theme colours so light and dark both work.
- Cursor: vertical line plus a dot on the curve at the cursor sample.
- Values row at the cursor:
  - time as mm:ss runtime;
  - depth in the diver's depth unit;
  - ppO2 in bar to two decimals;
  - NDL or deco stop, **matching the deco status card** (user's decision after
    the builder check): read `analysis.decoStatuses[cursorIndex]`, the same
    `DecoStatus` the card reads (`dive_detail_deco_sections.dart`). When
    `status.inDeco` is false, show NDL in minutes from `ndlSeconds`. When it
    is true, show the current stop as depth (in the diver's unit) and time,
    taken from `status.decoStops` the same way the card presents its current
    stop. Depth and time both come from that one calculation; computer-recorded
    stops are not mixed in. Accepted trade-off: on a dive where the computer's
    recorded stops differ from the calculation, the strip can show a different
    stop from the full chart's tooltip, but it always agrees with the deco
    status card.
  - Time, depth and ppO2 come from `resolveSample` against the chart profile
    and the active source's analysis, so they match the fullscreen readout.
  - A value that is unavailable (for example no analysis, or no gas data for
    ppO2) shows a dash in its slot; the slot is not dropped.
- No cursor: the values row shows the dimmed hint ("Drag to scrub" / "Hover to
  scrub"). Choose by input type (touch vs pointer) rather than platform.

### Strip input

- Touch: horizontal drag scrubs; a tap selects. Vertical drags must still
  scroll the page (use a horizontal-drag recognizer, not a pan). Lifting the
  finger clears the cursor, as the full chart does.
- Pointer: hover scrubs; leaving the strip clears the cursor.
- Writes go to `profileTrackingIndexProvider(diveId)` as indices into the chart
  profile.

### Buoyancy two-way sync

- Reading: the buoyancy chart draws a vertical marker at the cursor's
  timestamp (index resolved against the chart profile), in a neutral colour
  (the buoyant line itself is the primary colour). With no cursor, no marker.
- Writing: hovering or touching the buoyancy chart maps the touched sample's
  timestamp to the nearest chart-profile index and writes the shared cursor;
  exit and touch end clear it, matching the profile chart.
- Its existing tooltip keeps working.

### Every hoverable card moves the cursor

Added at the user's request during the build: any card with a dive-time
chart writes the shared cursor too, so the profile and the strip follow it.
The tissue heat map and area chart already did; buoyancy does (above); the
SAC segments time chart now reports the time under the pointer on hover and
drag, clearing it on exit or lift. The tide graph (tide cycle, not dive time)
and the health card (no chart) are out of scope.

### Setting

- New boolean `pinProfileOnScroll`, default true, following the
  `showMaxDepthMarker` precedent end to end, including sync and the conflict
  catalogue, with migration 359.
- `SwitchListTile` titled "Pin profile when scrolling" with a one-line
  subtitle, in `_buildDiveProfileSettings`.
- New strings go in `app_en.arb`; other locales follow the project's usual
  practice for new keys.

## Calls made by the designer (not discussed with the user)

- **Animation source:** superseded. The first build morphed a lightweight
  copy of the depth curve over the card; in the running app it hid the
  chart's axes and lines too early and left a mostly empty box, so the user
  chose to squash the live card instead (see "When the strip shows").
- **Dive list profile panel:** on desktop it already shares
  `profileTrackingIndexProvider(diveId)` with the detail chart, so it will
  follow strip and buoyancy scrubbing too. No separate cursor key.
- **Occlusion:** the strip covers the top of the scrolled content, like any
  pinned header. Any programmatic scroll-to-section offsets its target by the
  strip's height while the strip is showing.

## Left to the builder

- Widget structure, file split and names (keep files within the repo's size
  guidance), and whether the strip reuses `MiniProfilePainter` or a new
  painter.
- How the profile card's position is measured (for example a `GlobalKey` on the
  profile section read on scroll notifications).
- Exact animation curve and the progress window.
- Accessibility labels for the strip and the hint.

## Testing expectations

- Unit tests for the value resolution: NDL vs deco-stop slot, dashes for
  missing data, unit conversion.
- Widget tests: strip hidden while the profile card is visible, shown after
  scrolling past it, hidden with the setting off, hidden when the profile
  section is hidden or folded; strip drag writes the cursor; buoyancy reads and
  writes the cursor.
- Settings: persistence round trip and migration test following existing
  setting tests.
