# 3D Dive Flythrough - Design

Date: 2026-07-11
Status: Approved (brainstorming session)
Feature: 3D flythrough visualization of a dive between GPS entry and exit
points, with overlay stat series rendered as 3D lanes in the viewport.

## Summary

When position data is available for a dive, Submersion renders the dive as a
3D scene: the dive path reconstructed between GPS anchors with real depth from
profile samples, stat series (temperature, ascent rate, tank pressure/SAC,
NDL, TTS) as parallel 3D lanes, and the deco ceiling as a translucent sheet
above the path. A follow-cam flies the path under the existing playback
transport; the user can break out into free orbit or jump to preset
viewpoints. The feature appears as a preview card in dive detail and a
dedicated fullscreen page.

Because GPS does not work underwater, the horizontal path is always a
reconstruction. The design is explicit about this: every rendered path
carries a fidelity tag surfaced in the UI, and depth is the only horizontal
axis-independent ground truth.

## Decisions (from brainstorming)

| Decision | Choice |
| --- | --- |
| Path reconstruction | Tiered: heading dead reckoning, surface-GPS anchors, straight-line; graceful degradation |
| Camera | Follow-cam playback + free orbit + preset viewpoints (all three) |
| Overlay rendering | Parallel lanes offset from the dive path; ceiling as 3D sheet |
| Lane series (v1) | Temperature, ascent rate, tank pressure/SAC, NDL, TTS |
| 3D engine | three_js (Dart port, ANGLE-backed) + three_js_controls |
| Renderer flags | None. three_js brings its own GL context; no Impeller required |
| Placement | Embedded preview card in dive detail + fullscreen page |
| GPS gating | Degrade gracefully: entry+exit > single anchor out-and-back > site pin; hide only with no position data |

## Section 1: Path reconstruction

New pure-Dart service `DivePathReconstructor` in
`lib/features/dive_log/domain/services/dive_path_reconstructor.dart`.

Inputs:

- Entry/exit anchors from `dives.entry_latitude/longitude` and
  `exit_latitude/longitude` (falling back to `dive_data_sources` values via
  the active-source model, then the site pin).
- Matched surface GPS track points (existing `gps_track_matcher.dart`,
  feature #497) that overlap the dive window.
- Profile samples (time, depth) from the primary profile.
- Optional per-sample heading (new column, see Schema below).

Output: `ReconstructedPath` - ordered `(t, x, y, z)` points in a local
east/north meters frame centered on the entry anchor (equirectangular
projection; exact enough at dive scale), plus a `PathFidelity` tag.

Tiers (best available data wins; tiers compose per segment):

1. `headingTrack` - integrate a unit step along each heading sample, then
   apply an affine closure correction (rotate + scale + translate) so the
   track starts and ends exactly on the anchors. Shape from compass, scale
   and placement from GPS.
2. `anchored` - split the dive into segments between known fixes (entry,
   any mid-dive surface GPS points, exit); within a segment, horizontal
   position advances proportionally with elapsed time along the straight
   line between fixes.
3. `outAndBack` - single anchor only: swim out along a default bearing
   (first available heading sample if any, else due north) at an assumed
   12 m/min horizontal speed, capped at 250 m out, turn at half-time,
   return to the anchor.

Rules:

- Reconstruction is total: it never throws. Degenerate inputs (no samples,
  zero duration, anchors implausibly far apart) clamp to safe output with a
  low-confidence fidelity note.
- Depth always comes from real profile samples; only horizontal shape is
  estimated.
- The UI shows a "reconstructed path" badge with the fidelity tier and a
  tooltip explaining what is real vs estimated.

### Schema: heading column (lands first, own PR)

- `dive_profiles.heading` REAL nullable (degrees), next free slot on the
  schema version ladder (v105+; v104 is claimed by the in-flight weight
  planner branch - re-check claims at implementation time).
- Extract `DC_SAMPLE_BEARING` in the download pipeline and mirror the same
  persistence in `reparse_service` (established rule: reparse mirrors
  download), so existing dives gain heading via re-parse of stored raw data.

## Section 2: Scene and interaction

three_js scene in a local-meters frame, Y-up, water surface at y = 0.

Scene contents:

- Water surface: large translucent plane at y = 0 with subtle grid.
- Dive path: `TubeGeometry` along the reconstructed path. Optional
  ascent-rate coloring reuses the #242 green/yellow/red scheme; otherwise
  theme primary color.
- Stat lanes: ribbon meshes offset perpendicular to the path's horizontal
  direction, one per enabled series (temperature, ascent rate, one per tank
  for pressure or a SAC lane, NDL, TTS). Lane height = series value
  min-max normalized over the dive (exact values live in the HUD, not the
  geometry). Lane colors match the 2D chart palette so both views read as one
  system.
- Deco ceiling: translucent red-tinted sheet at ceiling depth above the path
  wherever a ceiling exists. Path crossing above the sheet makes ceiling
  violations directly visible.
- Markers: entry/exit flags, gas-switch markers (same event semantics as the
  2D chart), and a diver marker that travels the path during playback.
- Depth reference: faint horizontal grid planes every 10 m / 30 ft honoring
  the active diver's unit settings.
- No 3D text. All numeric readouts, labels, and legends are Flutter widgets
  overlaid on the GL texture (theming, localization, and units for free).

Camera:

1. Follow-cam: trails behind/above the diver marker with a short spring lag
   on position and look-at target. Driven by the existing
   `profile_playback_provider`, so the 2D chart scrub, transport controls,
   and 3D view stay in sync.
2. Free orbit: any drag breaks out of follow-cam into orbit around the path
   bounding-box center; `TrackpadZoomGestureRecognizer` drives dolly (matches
   the app's other zoomable surfaces; also sidesteps the known three_js Linux
   trackpad quirk). A "resume follow" chip returns to the flythrough.
3. Presets: top-down (map-like), side profile (matches the 2D chart
   orientation), isometric overview. Animated transitions.

Surfaces:

- Preview card in dive detail (new entry in `dive_detail_sections.dart`):
  lightweight viewport, isometric preset, no lanes, slow auto-orbit, renders
  only when visible; tap opens fullscreen.
- Fullscreen page at `/dives/:id/flythrough` (same pattern as #469
  fullscreen profile): full scene, transport bar (reuse
  `profile_transport_controls`), lane toggle chips (persisted like 2D chart
  overlay prefs), camera preset buttons, fidelity badge, playback stats HUD
  (reuse `playback_stats_panel`).

## Section 3: Architecture

```
lib/features/dive_log/
  domain/services/
    dive_path_reconstructor.dart      # tiers, closure correction, PathFidelity
    tts_series_calculator.dart        # per-sample TTS via core/deco Buhlmann replay
  presentation/flythrough/
    providers/flythrough_providers.dart  # divePathProvider.family, gating, lane prefs
    scene/scene_builder.dart          # ReconstructedPath + series -> scene graph
    scene/lane_geometry.dart          # ribbon/tube/sheet mesh generation (pure)
    scene/flythrough_camera.dart      # follow-cam spring, orbit handoff, presets
    widgets/flythrough_viewport.dart  # three_js texture widget + gestures + HUD
    widgets/flythrough_preview_card.dart
    pages/dive_flythrough_page.dart
```

Data flow: `divePathProvider(diveId)` composes dive anchors, matched GPS
track, and the primary profile (filtered by `isPrimary`; see WS2 lesson on
unfiltered profile loads) into `DivePathReconstructor`. The scene builder
rebuilds meshes only when path data or lane toggles change; playback and
camera updates touch only transforms, never geometry. Profiles are decimated
via the existing `profile_decimator` (target 1-2k points).

Series sources: depth, temperature, ascent rate, ceiling, NDL, and TTS all
have per-sample columns in `dive_profiles` (TTS is populated when the dive
computer reports it). For dives whose computer did not report TTS,
`tts_series_calculator` replays tissues through
`core/deco/buhlmann_algorithm.dart` (same machinery as the tissue-loading
card) to synthesize the series as a fallback.

Gating and fallbacks:

- Preview card and route appear only when position data exists at any tier
  (entry+exit, single anchor, or site pin).
- If the ANGLE/GL context fails to initialize (most plausible on
  Windows/Linux), both surfaces degrade to a friendly "3D view unavailable on
  this device" card. Never a crash, never a black rectangle.
- GL contexts, controllers, and textures are disposed rigorously on route pop
  (texture leaks are the classic flutter_angle failure mode).

Engine notes and risks:

- three_js v0.3.0 declares all six platforms; Linux is tested (Linux Mint)
  with known quirks: tonemapping and postprocessing broken, trackpad zoom
  flaky. None are needed by this scene (flat-shaded lines, no post-fx, our
  own zoom recognizer).
- README carries a possibly stale "works for flutter < 3.27" note; the PR 1
  spike exists to verify compatibility with our stable channel before deeper
  investment.

## Testing

TDD throughout; unit coverage targets the pure layers:

- `DivePathReconstructor`: closure correction lands exactly on both anchors,
  tier selection, per-segment composition, out-and-back symmetry, degenerate
  inputs (no samples, zero duration, absurd anchor spacing), site-pin
  fallback.
- `tts_series_calculator`: against known deco profiles with expected TTS.
- `lane_geometry`: vertex counts, value normalization, unit conversion at
  the geometry boundary.
- Widget tests: gating states (no GPS, single anchor, full anchors),
  preview-to-fullscreen navigation, lane toggle persistence.
- The GL viewport gets a thin smoke test only; real rendering verification is
  the platform spike plus a manual pass per platform.

## PR-2 addendum (2026-07-11, after PR 1 and PR #565)

Findings from PR 1 (#563) and the parallel dive-3d-view feature (#565) revise
this design as follows; where they conflict with sections above, this
addendum wins:

- Engine: three_js subpackages only (`three_js_core`, `three_js_math`,
  `three_js_angle_renderer`); the umbrella package and `three_js_controls`
  are unresolvable against existing dependency pins. flutter_angle rides the
  `submersion-app/flutter_angle` fork branch `flutter-3.44-linux-embedder`
  via dependency_overrides (wired by #565). Camera control is hand-rolled.
- The flythrough builds INSIDE `lib/features/dive_3d/` on #565's
  engine-agnostic layer (`MeshData`, `Dive3dGeometry`, `ThreeAdapter`,
  `SceneViewport`, software `SceneProjector` fallback) instead of a parallel
  `dive_log/presentation/flythrough/` stack. #565's analytical scene
  (time-extruded axes) stays untouched; spatial geometry is new files.
- TTS: `tts_series_calculator` is dropped. The existing
  `profileAnalysisProvider` already replays the profile through Buhlmann and
  exposes per-sample `decoStatuses[i].ttsSeconds`; the flythrough consumes
  that (stored `dive_profiles.tts` remains the display-priority source when
  the computer reported it).
- Playback: the flythrough page follows `Dive3dPage`'s local
  `ValueNotifier<double>` scrub pattern (frame-rate updates without Riverpod
  rebuilds) rather than `profile_playback_provider`; 2D/3D transport sync is
  dropped as a requirement.
- Placement: the flythrough opens from the dive_3d page (which is reached
  from #565's existing dive-detail preview card); a dedicated preview-card
  surface decision moves to PR 3.
- Lane scope: all five lane series (temperature, ascent rate, tank
  pressure, NDL, TTS) plus lane-preference persistence land in PR 2 - the
  generic lane builder makes the extra series near-free. PR 3 shrinks to
  the preview-card surface and polish.

## Delivery plan

Three independently shippable PRs:

1. Heading column + engine spike: schema migration (v105+, see above),
   `DC_SAMPLE_BEARING`
   extraction in download and reparse, plus a throwaway three_js spike
   behind a debug flag validated on macOS/Windows/Linux CI.
2. Core feature: reconstruction service, fullscreen flythrough with all
   three camera modes, temperature + ascent-rate lanes, ceiling sheet.
3. Full lane set + preview card: pressure/SAC, NDL, TTS lanes, dive-detail
   preview card, lane preference persistence.

The reconstruction layer has zero three_js imports by design: if the engine
changes again, the math survives untouched.
