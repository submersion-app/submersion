# Fullscreen Dive Profile Redesign — Design

**Date:** 2026-07-02
**Issues:** [#443](https://github.com/submersion-app/submersion/issues/443) (chart does not use full window height), [#169](https://github.com/submersion-app/submersion/issues/169) (real-time dive computer panel on fullscreen profile)
**Status:** Approved design, pending implementation plan

## Problem

The fullscreen profile view (`_FullscreenProfilePage`, a private widget in
`dive_detail_page.dart`) is not meaningfully better than the inline chart. The
chart expands to full width but its height is pinned twice: an outer
`SizedBox(height: 280/350)` in the fullscreen page and an inner
`SizedBox(height: 200)` around the plot inside `DiveProfileChart`
(`dive_profile_chart.dart:1264`). Most of the screen is empty. The view also
lacks any playback capability, even though a complete playback engine
(`profile_playback_provider.dart`) already exists and is wired only to the
inline chart.

## Goal

Make the fullscreen view a genuine dive-review experience:

- The chart fills all available height and width (#443).
- A dive-computer-style instrument bar shows live readouts that track the
  cursor, whether the user scrubs manually or plays the dive back (#169).
- Navigation (scrub, zoom, playback) and detail drill-in work with one unified
  position concept.

## Decisions (validated with mockups)

1. **Core concept:** one unified view — analysis and replay are the same
   interaction at different pacing. Not a separate "replay mode".
2. **Layout:** bottom instrument bar (chart full width; transport + readout
   tiles in a strip along the bottom). Same structure on all platforms.
3. **Chrome:** slim persistent header row (close, title, series toggles, zoom).
   No auto-hide, no floating overlays.
4. **Tiles:** adaptive by available data, with user-tunable visibility and
   order, persisted in settings.
5. **Implementation:** extract-and-compose (Approach 1). New page in its own
   files; `DiveProfileChart` gains height flexibility; existing family
   providers are watched by dive id instead of passing snapshot data.

## Layout

```
Scaffold (no AppBar)
└─ SafeArea
   └─ Column
      ├─ Header row (~40px): [close] [Dive #N — site] [spacer] [series pills + More] [zoom - +]
      ├─ Expanded: DiveProfileChart (fills remaining height)
      └─ Instrument bar
         ├─ Transport row: skip-back | play/pause | skip-fwd | scrub slider (minimap) | mm:ss / mm:ss | speed chip
         └─ Tile row: Depth, Runtime, Temp, NDL (or Ceiling+TTS), Tank, ppO2, GF ... 
```

- The header composes the existing `DiveProfileLegend` (toggle pills, "More"
  popover, zoom buttons) next to a close button and title. The chart gets a
  `showLegend` parameter (default `true`) so the fullscreen page can pass
  `false` and the chart does not render a second legend internally.
- The scrub slider track renders a small depth-outline minimap so the user can
  see where in the dive they are jumping.
- Portrait phones: tile row wraps to two rows; landscape and desktop: one row,
  horizontal scroll if space runs out.
- Orientation behavior is unchanged: all orientations enabled on entry,
  portrait-only restored on dispose.

## Components

New files under `lib/features/dive_log/presentation/`:

| File | Responsibility |
|------|----------------|
| `pages/fullscreen_profile_page.dart` | Page shell: header row, chart, orientation + lifecycle handling. Takes only `diveId`. |
| `widgets/profile_instrument_bar.dart` | Transport row + tile row; tile adaptivity and layout (wrap vs scroll). |
| `widgets/readout_tile.dart` | Single label + value tile; unit-aware; renders em dash for null-at-position. |
| `widgets/profile_transport_controls.dart` | Play/pause/step buttons, minimap slider, time display, speed chip. Supersedes `PlaybackControls` in this view. The inline view keeps `PlaybackControls`, but its speed menu is updated to the new engine presets (below). |

Modified:

- `dive_profile_chart.dart` — plot height becomes "fill parent when parent
  provides a bounded height, else 200 as today". All existing call sites are
  unaffected. Add the hide-legend parameter.
- `profile_playback_provider.dart` — engine rework (below). Public notifier
  API (`play`, `pause`, `seekTo`, ...) preserved where practical.
- `dive_detail_page.dart` — `_showFullscreenProfile` becomes a plain
  `Navigator.push` of the new page with a `diveId`; the private
  `_FullscreenProfilePage` and its metrics-table helpers (~500 lines) are
  deleted.
- Settings: one new persisted field for tile preferences (order + hidden set)
  via `SettingsNotifier`. Known cost: four test-mock sites must be updated.

## State and data flow

**Unified review position.** A `profileReviewProvider(diveId)` holds the
current position as a timestamp in dive-seconds. Consumers: chart cursor line,
instrument tiles, slider position. Writers: chart hover/drag scrub, slider,
transport buttons, playback ticker. The sample index is derived from the
timestamp by binary search over profile timestamps. This replaces the current
split between `profileTrackingIndexProvider` (hover) and
`playbackProvider.currentTimestamp` (playback) in the fullscreen view.

**Playback engine rework:**

- Replace the per-dive-second `Timer.periodic` with a ~30 fps tick that
  advances `elapsed x speed` dive-seconds per frame.
- Replace 0.5x-4x real-time speeds with presets 1x, 5x, 15x, 30x, 60x, 120x.
  Default 30x. Speed chip opens a small menu (or cycles).
- Seeking while playing is allowed; playback continues from the new position.
- Ticker cancels on dispose and pauses on app background
  (`AppLifecycleState`).

**Tile system.** A fixed priority list defines candidates: depth, runtime,
temperature, NDL, ceiling + TTS, tank pressure(s), ppO2, GF%, CNS, SAC, heart
rate, ascent rate. A candidate exists only if the dive has that series. The
deco-aware pair swaps like a real dive computer: NDL shows while
`decoType` = no-deco; ceiling + TTS replace it during deco samples. User
preference (order + hidden set) applies on top of adaptivity, so hiding never
creates empty tiles and a rec dive never shows tech tiles.

**Tile values at position t:** profile-point fields read from the sample at
the derived index; `ProfileAnalysis` parallel curves (`gfCurve`, `ttsCurve`,
`sacCurve`, ...) indexed by the same index; tank pressure interpolated from
`TankPressurePoint` series (nearest sample <= t per tank). All display values
formatted through `UnitFormatter` from `settingsProvider`.

**Data loading.** The page watches the existing family providers
(`profileAnalysisProvider`, `gasSwitchesProvider`, `tankPressuresProvider`,
dive-by-id) rather than receiving snapshot objects, so the view stays live
after sync (see issue #217 lesson) and is testable via provider overrides.
Tiles and chart render from `AsyncValue.value` to avoid reload flicker
(issue #429 lesson).

## Edge cases and error handling

- **Empty profile:** page still opens (guarded); chart shows its existing
  empty state; transport disabled; bar shows static tiles only (max depth,
  duration).
- **Null value at position** (e.g. temperature gaps): tile shows an em dash;
  the bar never reflows during playback.
- **Provider loading/error:** progress indicator / standard error widget in
  the chart area; close button always available.
- **Zoom during playback:** playback continues; cursor may leave a zoomed
  viewport. No auto-follow in v1 (documented follow-up candidate).
- **Desktop keyboard:** Space = play/pause, Left/Right = step, Esc = close.

## Testing

TDD throughout.

- **Unit:** timestamp-to-index derivation (edges, gaps); ticker advancement
  with `fakeAsync` (speed math, end clamp, pause-at-end); tile candidate
  selection across rec / tech / CCR fixtures including the NDL <-> ceiling+TTS
  swap; tank-pressure interpolation.
- **Widget:** page composition with overridden providers; tiles update as the
  review position changes; transport drives the provider; customize sheet
  hides/reorders and persists; layout test asserting the plot fills a bounded
  parent (regression guard for #443).
- **Existing suites:** update four `SettingsNotifier` mock sites; update
  `playback_controls` tests for the reworked engine.

## Out of scope

- Auto-follow of the cursor in a zoomed viewport during playback.
- Changes to the inline (dive-detail) chart layout. (`PlaybackControls` gets
  only the speed-preset update required by the shared engine rework.)
- New go_router routes / deep links to the fullscreen view.
- Skeuomorphic dive-computer rendering (bezel, segment displays).
