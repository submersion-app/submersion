# Seascape Player/Routing Refactor Implementation Plan

> **For agentic workers:** Execute inline with superpowers:executing-plans, in one
> session, with no subagents. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Address the follow-up cleanup from issue #2771 (itself a follow-up
to #2694) that is still worth doing: extract the shared play/pause timeline
logic. The extraction also fixes the playback bugs listed under Review
outcome; nothing else changes for divers.

**Scope decision:** The issue's third point (a shared routing helper for
`SpatialSitePage`/`NavTrackSeascapePage`) is dropped. Investigation (see
issue #2771 analysis, 2026-10-31) found the heavy duplication it originally
described has already been resolved elsewhere: both pages already share
`siteSeascapeProvider`, `SiteTerrainPane` and the playback-context types. What
remains is a thin, deliberately mirrored ~25-line routing shell with matching
code-review-driven comments in both places. Extracting that into a
6-parameter helper function would trade a small, readable duplication for a
lambda-heavy indirection, not a net readability or maintenance win.

The issue's point about `Future.wait` in `siteActivePathOverlayProvider` is
dropped as well: see Task 2.

**Scope addition:** While investigating the player-logic point, two more
byte-identical copies of the same `AnimationController` + reset-at-end toggle
were found that the issue does not mention: `Dive3dPage`
(`lib/features/dive_3d/presentation/pages/dive_3d_page.dart`) and
`NavTrack3dPage` (`lib/features/nav_track/presentation/pages/nav_track_3d_page.dart`).
Both are live, routed pages (pushed from `dive_detail_page.dart` and
`nav_track_detail_page.dart` respectively), not legacy code. Their
`_togglePlay` bodies are word-for-word identical to the two standalone
widgets already in scope, use the same `SingleTickerProviderStateMixin` +
45-second `AnimationController` + `TimeScrubBar` shape, and already have
their own play/pause widget tests (`dive_3d_page_test.dart`,
`nav_track_3d_page_test.dart`) following the same tap-pump-expect pattern
used elsewhere in this repo. They are included in the `ScenePlayer`
extraction below, bringing the total from three sites to five, and to six
with Scope addition 2.

**Architecture:** A new `ScenePlayer` `ChangeNotifier` wraps the
`AnimationController` + reset-at-end toggle logic shared by all six sites, and
a `ScenePlayerBar` wires a `TimeScrubBar` to it, so no page calls `setState`
for playback.

**Scope addition 2 (found during `/code-review` on the finished diff):** a
sixth byte-identical copy in `CompareProfile3dView`
(`lib/features/dive_3d/presentation/widgets/compare_profile_3d_view.dart`),
shared by the standalone dive-compare page and `Dive3dPage`'s Computers mode.
Migrated to `ScenePlayer` the same way, after adding the same kind of missing
play/pause test (`compare_profile_3d_view_test.dart` only checked rendering,
not play/pause, like the two sites in Scope addition 1).

**Tech Stack:** Flutter, Riverpod.

**Issue:** [#2771](https://github.com/submersion-app/submersion/issues/2771)
(Refs #2694)

## Global Constraints

- No em-dashes anywhere. No mention of any AI tool in commits, code or docs.
- `dart format .` after each task. Stage explicit paths, never a directory.
- Pure refactor: every existing playback test must keep passing unchanged.
  Any test edit that is not itself a new test for the extracted code is a
  signal the refactor changed behavior, stop and investigate. This held for
  the extraction; the fixes under Review outcome change behavior on purpose.
- No new isolated unit test for `ScenePlayer` driving a bare
  `AnimationController` outside a widget tree: there is no precedent for that
  in this repo, every existing play/pause test (in `dive_3d_page_test.dart`,
  `nav_track_3d_page_test.dart`, `nav_track_seascape_page_test.dart`,
  `site_terrain_pane_playback_test.dart`) drives it through the full widget
  tree (tap the icon, pump, assert the icon changed). Rely on those five
  existing test files as the RED/GREEN signal instead of inventing a new
  harness. Superseded in review: `TestVSync`-driven tests do exist
  (`map_camera_animator_test.dart`), and `scene_player_test.dart` now covers
  what no widget test asserts.
- Run the affected test files directly (`flutter test <path>`), not the full
  suite: trust CI for the full-suite signal, use local runs only to drive TDD
  on the files being touched.

## Review Focus

1. **Player state after extraction.** `SiteTerrainPane`'s player is nullable
   and created/disposed on `playbackContext` changes (`_syncPlayer`); the
   other five sites' players are `late final`, created once in `initState`.
   `ScenePlayer` must support both lifecycles without forcing
   `SiteTerrainPane` into always having a controller, and without forcing the
   other five into a nullable one they do not need.
2. **Durations stay different.** The six sites use 45s (five of them) and
   30s (`NavTrackSeascapePage`'s standalone widget) today. `ScenePlayer`
   takes `duration` as a constructor parameter; nothing unifies it.
3. **The end of the timeline.** Only `SiteTerrainPane` had the
   `addStatusListener` that rebuilds when playback reaches the end. Review
   showed the other five kept the pause icon up forever, so `ScenePlayer` now
   notifies on completion for every site.

## Task 1: Shared player/toggle logic (issue #2771, point 2, extended scope)

These steps record the extraction as first built. Review replaced the
`onEdgeReached` callback and the per-site `setState` wiring they name: see
Review outcome.

- [x] Read all five current implementations once more immediately before
      editing (do not rely on memory of an earlier read):
      `lib/features/site_scape/presentation/site_terrain_pane.dart`,
      `lib/features/dive_3d/presentation/pages/spatial_site_page.dart`,
      `lib/features/nav_track/presentation/pages/nav_track_seascape_page.dart`,
      `lib/features/dive_3d/presentation/pages/dive_3d_page.dart`,
      `lib/features/nav_track/presentation/pages/nav_track_3d_page.dart`.
- [x] RED (existing coverage): confirm the three existing play/pause tests
      pass on `main` first, as the pre-refactor baseline. Only three of the
      five sites actually have one today: `spatial_site_page_test.dart`
      and `nav_track_seascape_page_test.dart` check that `TimeScrubBar`
      renders but never exercise play/pause:
      `flutter test test/features/dive_3d/presentation/pages/dive_3d_page_test.dart test/features/nav_track/presentation/pages/nav_track_3d_page_test.dart test/features/site_scape/presentation/site_terrain_pane_playback_test.dart`
- [x] RED (new coverage): add a play/pause test to
      `test/features/dive_3d/presentation/pages/spatial_site_page_test.dart`
      and to
      `test/features/nav_track/presentation/pages/nav_track_seascape_page_test.dart`
      for their respective standalone (no-site) widgets, following the exact
      tap-the-icon/pump/assert-icon-changed pattern already used in
      `dive_3d_page_test.dart` (`'play toggles to pause and back'`). Unlike a
      normal RED step, these are expected to pass immediately against
      today's unrefactored widgets: the behavior already exists, only the
      test was missing. Confirm they pass BEFORE touching `scene_player.dart`
      or either page, so they serve as the true pre-refactor baseline for
      these two sites during the GREEN step below.
- [x] GREEN: add `lib/features/dive_3d/presentation/scene_player.dart` with
      a `ScenePlayer` class wrapping `AnimationController`, exposing
      `isPlaying` (replaces every current `_player.isAnimating` read, e.g.
      `TimeScrubBar(playing: ...)`), `togglePlay()`, a separate `stop()`
      (every site's `onScrubStart` calls this directly, not `togglePlay()`,
      to interrupt playback on a manual scrub without restarting it), and
      `dispose()`, taking `vsync`, `duration`, an external
      `ValueNotifier<double>` to drive, and an optional `onEdgeReached`
      callback.
- [x] Replace the five inline `AnimationController` + `_togglePlay` copies:
      - `SiteTerrainPane._SiteTerrainPaneState`: `ScenePlayer?` instead of
        `AnimationController?`, created/disposed in `_syncPlayer` exactly as
        today, `onEdgeReached: () { if (mounted) setState(() {}); }`.
      - `SpatialSitePage._DiveSeascapeStandaloneState`: `late final
        ScenePlayer`, created in `initState`, 45s, no `onEdgeReached`.
      - `NavTrackSeascapePage._NavTrackSeascapeStandaloneState`: `late final
        ScenePlayer`, created in `initState`, 30s (unchanged), no
        `onEdgeReached`.
      - `Dive3dPage`: `late final ScenePlayer`, created in `initState`, 45s,
        no `onEdgeReached`.
      - `NavTrack3dPage`: `late final ScenePlayer`, created in `initState`,
        45s, no `onEdgeReached`.
      Each site's `_togglePlay` becomes `setState(() => _player.togglePlay())`
      (or, for `SiteTerrainPane`'s nullable case, the existing null-guard
      kept around that one line). Each site's `TimeScrubBar(playing: ...)`
      switches from `_player.isAnimating` to `_player.isPlaying`, and each
      site's `onScrubStart` switches from
      `if (_player.isAnimating) setState(() => _player.stop());` to
      `if (_player.isPlaying) setState(_player.stop);` (same null-guard
      pattern for `SiteTerrainPane`).
- [x] Re-run all five play/pause test files (the three pre-existing ones
      plus the two just extended); all green with no further edits to the
      test files themselves beyond the new cases added above.
- [x] `dart format` the six touched/added source files plus the two edited
      test files.

## Task 2: `Future.wait` in `siteActivePathOverlayProvider` (issue #2771, point 3)

Dropped in review. `spatialReckonedPathProvider`, awaited just above, starts by
awaiting `primaryNavTrackForDiveProvider` and, on the dead-reckoned path,
`diveProvider` too, so at most one real lookup remains and nothing can overlap.
A record `.wait` would also have wrapped any failure in `ParallelWaitError`.
The two sequential awaits stay as they are.

## Task 3: Wrap-up

- [x] `flutter analyze` on the touched files' directories; fix any lint.
      (No issues found on `lib/features/dive_3d`, `lib/features/nav_track`,
      `lib/features/site_scape`.)
- [x] Migrate the sixth `ScenePlayer` site found by `/code-review`,
      `CompareProfile3dView`, the same way as the other four `late final`
      sites (45s, no `onEdgeReached`), with the same missing-test fix first
      (`compare_profile_3d_view_test.dart`).
- [x] PR description notes that the issue's routing-helper point was
      investigated and intentionally left out (with the reasoning above),
      and that the player-logic point was extended to three sites the issue
      did not name (`Dive3dPage`, `NavTrack3dPage`, `CompareProfile3dView`),
      with the reasoning above. `Closes #2771`.

## Review outcome

Fixed on top of the extraction, each with a test that failed first:

- Five sites kept the pause icon up after the timeline ended.
  `ScenePlayer` notifies on completion and `ScenePlayerBar` follows it, which
  replaces `onEdgeReached` and every site's `_togglePlay` and `onScrubStart`.
- A reduce-motion setting ran the timeline at 5% of its duration:
  `AnimationBehavior.preserve`.
- `SiteTerrainPane` used the single-ticker mixin with a player it can
  recreate: `TickerProviderStateMixin`.
- `Dive3dPage`'s player ran on behind the Computers scene: the scene toggle
  stops it.
- `SiteTerrainPane`'s player ran on after its active path, and so its
  timeline, went away: a listener on the overlay stops it.
