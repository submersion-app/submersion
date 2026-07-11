# Dive 3D View - Design

**Date:** 2026-07-11
**Status:** Approved design, pending implementation plan
**Scope:** Phase one of a four-scene 3D visualization platform

## Vision

A 3D viewport for dive data that gives divers a different view of their dives
over time and across multiple dimensions. Four scene families were identified,
all sharing one foundation:

1. **Single-dive scene** (this spec, phase one) - one dive explored richly:
   depth-time ribbon, water-column temperature strata, deco ceiling surface,
   event/photo markers.
2. **Career terrain** (future) - many dives stacked along the Z axis by date
   or site, forming a terrain of diving history.
3. **Tissue/deco model view** (future) - 16 Buhlmann compartments x time x
   gas loading as an animated surface, computed by replaying logged profiles
   through the planner's deco engine.
4. **Spatial site view** (future) - dive anchored in real site geography via
   bathymetry and surface GPS tracks.

**Data constraint that shapes everything:** there is no underwater positioning
data (no compass heading, no acoustic nav; GPS dies at the surface). The
diver's actual swim path is not reconstructable. Every scene spends its third
axis on something we genuinely store: another metric, another dive, a tissue
compartment, or surface-only geography.

## Phase-one product decisions (approved)

- **Experience model:** explorable 3D object (orbit/zoom/pan) plus a time
  scrubber that moves a diver cursor along the ribbon and drives a metrics
  readout panel. A play button animates the scrub. The scene is static
  geometry; only the cursor moves.
- **Placement:** an embedded preview card on the dive detail page that expands
  to a fullscreen route (`/dives/:id/3d`, same pattern as fullscreen
  profile #469). The embedded card is a static software-rendered snapshot,
  not a live GL viewport (see Architecture).
- **Overlays in first version:** metric-colored ribbon, temperature strata,
  deco ceiling surface, event + photo markers. All derived from data already
  stored per profile sample.

## Section 1 - Engine and risk posture

**Engine: `three_js`** (Knightro63's Dart port of three.js) plus
`three_js_controls` (orbit) and `three_js_geometry` as needed. It runs on the
stable Flutter channel via ANGLE textures on desktop and mobile - no Impeller
dependency. Actively maintained (release May 2026), modular sub-packages.

**Why not flutter_scene:** it requires the Flutter master channel (depends on
non-stable Flutter GPU features), and Impeller is not yet shipped on Windows
and Linux, which are Submersion targets. It stays on the roadmap as a
migration watch-item once Flutter GPU/Impeller reach stable on desktop.

**Phase 0 spike (hard gate before feature work):** a throwaway screen
rendering a spinning mesh via three_js, verified on macOS, iOS simulator,
Android, and the Windows CI build (which catches `/WX` plugin-build
strictness). If the spike fails on a required platform, fall back to
Approach A (custom `Canvas.drawVertices` projection pipeline) reusing the
same geometry layer.

**Isolation boundary:** all dive-domain geometry building is engine-agnostic
plain Dart emitting flat typed-data arrays (positions, indices, colors). No
three_js imports outside a thin adapter. This is simultaneously the
fallback path, the future-migration path, and the unit-test seam.

## Section 2 - Architecture

```
lib/features/dive_3d/
  domain/
    entities/
      dive_3d_scene_data.dart     // plain-Dart scene input: samples, strata,
                                  // ceiling series, markers, tank curves
      mesh_data.dart              // engine-agnostic mesh: positions, indices,
                                  // per-vertex colors, opacity group
    geometry/
      ribbon_builder.dart         // depth-time ribbon mesh + metric coloring
      strata_builder.dart         // temperature strata quads
      ceiling_builder.dart        // deco ceiling surface
      marker_layout.dart          // 3D anchor points for events/photos
      scene_bounds.dart           // axis scaling, aspect normalization
    metric_palette.dart           // metric -> color ramps (theme + unit aware)
  application/
    providers.dart                // dive3dSceneDataProvider (family by diveId)
  presentation/
    pages/dive_3d_page.dart       // fullscreen route /dives/:id/3d
    widgets/
      dive_3d_preview_card.dart   // embedded card on dive detail
      scene_viewport.dart         // three_js viewport widget (fullscreen only)
      time_scrub_bar.dart         // scrubber + play button
      scene_readout_panel.dart    // per-instant metrics readout
      metric_selector.dart        // ribbon coloring metric chips
    renderer/
      three_adapter.dart          // MeshData -> three_js objects; owns engine imports
```

Structural decisions:

1. **Engine behind one file.** Only `three_adapter.dart` (and
   `scene_viewport.dart`, which hosts its texture widget) import three_js.
2. **Preview card uses no GL.** It software-projects the same `MeshData`
   through a fixed isometric camera onto a `CustomPaint`, repainting only when
   dive data changes. The GL engine spins up only on the fullscreen page.
   No live GL in scroll views, no gesture conflicts, no idle GPU cost.
3. **Scene data assembly reuses existing repositories/providers** from
   `dive_log` (dive, profiles, tank pressure profiles, events, photos). No
   new queries. Profile selection filters to `isPrimary` (known trap:
   `getDiveById` loads profiles unfiltered). Multi-computer dives render the
   primary profile in phase one.
4. **Geometry building runs in `compute()`** for large profiles, returning
   transferable typed-data lists.

## Section 3 - Scene composition

**Coordinate system (shared by all future scenes):** X = run time,
Y = depth (surface at top, increasing downward), Z = the extra axis (lateral
ribbon thickness here; dive-index or tissue-compartment in later scenes).
`scene_bounds.dart` normalizes axis scaling so any dive fills the viewport
with sane proportions.

Scene elements:

1. **Metric-colored ribbon** - per sample, two vertices at
   `(t, -depth, +/- w/2)` forming a triangle strip; per-vertex color from the
   selected metric (temperature, ascent rate, ppO2, CNS, heart rate, tank
   pressure) via `metric_palette.dart`. A translucent **depth curtain** falls
   from the ribbon to the max-depth plane (3D analogue of the 2D area fill;
   primary depth-reading cue from any camera angle).
2. **Temperature strata** - samples binned by depth band, averaged into a
   temp-vs-depth profile, rendered as translucent horizontal slabs spanning
   the time range (warm-to-cool ramp, surface-to-deep). Thermoclines appear
   as color boundaries. Hidden when the dive has no temperature data.
3. **Deco ceiling surface** - translucent amber quad strip at `y = -ceiling`
   for samples with nonzero ceiling. The vertical gap between ribbon and
   ceiling is the deco margin; segments where depth is shallower than the
   ceiling render red (violation made physical).
4. **Event + photo markers** - billboarded sprites anchored to the ribbon at
   their timestamp with a thin connector line: gas-switch chips showing the
   mix, bookmark pins, photo thumbnails. Tap opens the existing photo viewer
   or event detail.
5. **Axes and grid** - faint horizontal depth planes at round intervals in
   the diver's depth unit, time ticks along the base, billboarded labels.
   All values use the active diver's unit settings via existing formatters.
6. **Scrub cursor** - marker sliding along the ribbon with the timeline; the
   readout panel shows that instant's depth, temp, ascent rate,
   ppO2/setpoint, CNS, TTS, and tank pressures.
7. **Camera and lighting** - perspective camera, orbit controls (drag
   rotate, pinch/scroll zoom, two-finger pan), initial three-quarter view,
   double-tap reset. Vertex-colored, mostly unlit materials with subtle
   ambient + directional shading; analytical readability over atmosphere.

## Section 4 - Interaction and data flow

- **Timeline:** the scrub bar owns a normalized time position. Play maps the
  full dive to ~45 s wall-clock (speed toggle available). Scrubbing never
  moves the camera.
- **Scrub state stays out of Riverpod.** It changes at frame rate during
  play, so it lives in a local `ValueNotifier` that only the cursor transform
  and readout panel listen to. Riverpod owns data; animation state is
  widget-local (avoids provider rebuild storms).
- **Metric switching is a color-buffer-only update** - re-run the palette
  pass, re-upload vertex colors; positions/indices untouched. Chips render
  only for metrics present in the dive's data.
- **Overlay toggles** (strata, ceiling, curtain, markers) show/hide scene
  objects without rebuilds.
- **Marker taps** use the engine raycaster to hit-test sprites.
- **Gestures:** orbit/zoom/pan as above; desktop trackpad behavior must align
  with the shared `TrackpadZoomGestureRecognizer` conventions used by maps
  and the profile chart (exact zoom-vs-rotate mapping specified during
  implementation).
- **Data flow:** `dive3dSceneDataProvider(diveId)` composes existing
  providers, watches `watchDiveDetailChanges` for post-sync reactivity, and a
  geometry provider runs builders in `compute()`. Profiles beyond ~5k samples
  are decimated for geometry (reusing the chart's downsampling approach);
  the readout panel keeps full-resolution lookup.
- **Degraded states:**
  - No profile samples (manual logs): preview card and 3D entry point do not
    render.
  - Missing temp/ceiling/events: those elements silently absent.
  - Engine init failure (ANGLE quirk): viewport catches it and falls back to
    the static software-projected rendering used by the preview card, with an
    "interactive 3D unavailable on this device" notice. Degrades to a
    picture, never a crash.

## Section 5 - Testing

- **Unit tests (bulk of coverage, no GL):** geometry builders (vertex/index
  counts, metric coloring, ceiling-violation segmentation, strata binning),
  bounds normalization, decimation, palette unit-awareness.
- **Golden tests:** the preview card's software-projected painter with
  fixture dives (deep deco dive, shallow reef dive, sparse-data dive) -
  deterministic 3D renders in CI with zero GL.
- **Widget tests:** metric chips reflect available data, readout values at
  known scrub positions, degraded-state fallbacks, card-to-fullscreen
  navigation. Standard provider-mock setup.
- **Not CI-testable:** the three_js viewport itself. Kept thin; gated by the
  Phase 0 spike plus a manual device matrix (macOS, iOS, Android, Windows).
  Windows CI still compiles it, catching plugin-build failures early.

## Phasing

- **Phase 0:** three_js platform spike (gate; fallback = Approach A canvas
  pipeline on the same geometry layer).
- **Phase 1:** this spec - single-dive scene, preview card + fullscreen page.
- **Phase 2+ (separate specs):** career terrain, tissue/deco model view,
  spatial site view (bathymetry sourcing is its own investigation).

## Risks

- **three_js maturity:** 0.x package; API churn possible. Mitigated by the
  adapter boundary and spike gate.
- **ANGLE on Linux:** desktop support is ANGLE-based; Linux is the least
  exercised path. Spike covers it; software fallback exists.
- **Large-profile performance:** mitigated by decimation + compute() +
  render-on-demand (render frames only on camera/scrub/animation changes,
  not a continuous loop).
- **flutter_scene migration:** when Flutter GPU reaches stable on all
  targets, only `three_adapter.dart` and `scene_viewport.dart` should need
  rewriting.
