# Tissue Saturation 3D Scene Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox (`- [ ]`) tracking.

**Goal:** A 3D "tissue landscape" scene showing 16-compartment inert-gas loading across a repetitive-dive chain (with surface intervals), rendered through the existing CustomPainter viewport.

**Architecture:** First generalize the dive_3d renderable to a scene-agnostic `Scene3d` (layers + markers + bounds + scrub path) so tissue/career/spatial scenes all fit the same painter/viewport. Then add a pure `TissueReplayService` (Buhlmann replay over the chain), a `TissueSurfaceBuilder` (height-field grid mesh), providers, and a scene switcher on `Dive3dPage`.

**Tech Stack:** Flutter stable, Riverpod, existing `BuhlmannAlgorithm` (`lib/core/deco/buhlmann_algorithm.dart`), `Canvas.drawVertices` renderer. No external 3D library.

**Spec:** `docs/superpowers/specs/2026-07-11-tissue-saturation-3d-design.md`

## Global Constraints

- `dart format .` clean + `flutter analyze` clean before every commit.
- New user-facing strings into all 11 `lib/l10n/arb/app_*.arb` + regenerate.
- Buhlmann GF passed as fractions 0..1; app stores ints 0..100 (divide by 100).
- Compartment loadings are bar absolute (`currentPN2`, `currentPHe`); ambient via `DiveEnvironment.pressureAtDepth`.
- Pure services are the tested unit; the isolate hop is not (repo convention).
- Commit per task; no co-author line; no session URL. Hooks bypassed in worktree (`git -c core.hooksPath=/dev/null`), format/analyze/test run manually.

---

## Phase A - Generalize the renderable (foundation for all new scenes)

### Task A1: Scene3d / SceneLayer / ScrubPath types

**Files:** Create `lib/features/dive_3d/domain/scene_3d.dart`; Test `test/features/dive_3d/domain/scene_3d_test.dart`.

- `class SceneLayer { final MeshData mesh; final SceneOverlay? overlay; const SceneLayer(this.mesh, {this.overlay}); }` (null overlay = always visible).
- `class ScrubPath { final List<double> xs; final List<double?> ys; const ScrubPath({required this.xs, required this.ys}); Offset? positionAt(double normalized, SceneBounds bounds) ... }` returning the interpolated scene (x,y) for the cursor, or null.
- `class Scene3d { final List<SceneLayer> layers; final List<SceneMarker> markers; final SceneBounds bounds; final ScrubPath? scrubPath; }`.
- Tests: ScrubPath interpolates monotonic xs; null when out of data.

### Task A2: Painter + cursor consume Scene3d

**Files:** Modify `preview_painter.dart`, `dive_3d_interactive_viewport.dart`.

- `Dive3dPreviewPainter` takes `Scene3d scene` (drop `Dive3dGeometry`). Iterate `scene.layers`; skip a layer whose `overlay != null && !visibleOverlays.contains(overlay)`. Markers gated by `SceneOverlay.markers`. Grid/ribbon-type layers have `overlay == null`.
- `_ScrubCursorPainter` uses `scene.scrubPath` to place the cursor (null scrubPath -> no cursor).
- `Dive3dInteractiveViewport` takes `Scene3d`.

### Task A3: Preview card + SceneGeometryService produce Scene3d

**Files:** Modify `scene_geometry_service.dart`, `dive_3d_preview_card.dart`, `application/providers.dart`, and dive-scene tests.

- `SceneGeometryService.build(...)` returns `Scene3d` with layers `[grid(null), strata(strata), curtain(curtain), ceiling(ceiling), ribbon(null)]` (skipping null meshes), markers, bounds, and `scrubPath` = ribbon leading-vertex xs/ys.
- `dive3dGeometryProvider` return type -> `Scene3d?`.
- `Dive3dPreviewCard` and `Dive3dPage` consume `Scene3d`.
- Update `scene_geometry_service_test.dart`, `dive_3d_interactive_viewport_test.dart`, card/page tests to assert on `scene.layers` / `scene.scrubPath`.

---

## Phase B - Tissue replay + geometry (pure, TDD)

### Task B1: TissueChainInput + TissueReplayService

**Files:** Create `lib/features/dive_3d/domain/tissue/tissue_chain.dart` (input entities), `lib/features/dive_3d/domain/tissue/tissue_replay_service.dart`, `lib/features/dive_3d/domain/tissue/tissue_replay_result.dart`; Test `test/features/dive_3d/domain/tissue/tissue_replay_service_test.dart`.

- Input: `class TissueDiveInput { final List<double> times; final List<double> depths; final List<GasLeg> gasLegs; }` where `GasLeg { int startSeconds; double fN2; double fHe; }`; `class TissueChainInput { final List<TissueDiveInput> dives; final List<int> surfaceIntervalSeconds; final double gfLow, gfHigh; final DiveEnvironment environment; }`.
- Result: flat arrays - `times` (chain clock seconds), `bool isSurface` per column, `Float32List loadingsN2` and `loadingsHe` (columns x 16, bar), `Float32List gradientFactors` (columns x 16, fraction), `Uint8List controllingCompartment` (per column, 0-15), `List<int> seamBoundaries` (column indices where a surface interval starts/ends).
- Replay: one `BuhlmannAlgorithm(gfLow, gfHigh, environment)`, surface-saturated start. Per dive, step each decimated leg with `calculateSegment(depthMeters: avgDepth, durationSeconds: dt, fN2, fHe)` (gas from `gasLegs`), snapshot `algo.compartments` after each. Between dives, off-gas the surface interval in ~10 chunks with `calculateSegment(depthMeters: 0, durationSeconds: chunk, fN2: airN2Fraction)`, snapshotting each chunk (for the seam curve). Per snapshot compute ambient (`environment.pressureAtDepth(depth)`), then per compartment `gradientFactor(ambient)`; controlling = argmax.
- Tests: single air dive to 30m/20min raises fast-compartment loading; a long surface interval drains fast compartments faster than slow (assert compartment 1 gradient drops more than compartment 16 across the SI); He present only when a gasLeg carries fHe>0; controlling compartment shifts to slower compartments as the dive lengthens. Validate a leg against a hand-computed / golden-corpus value for one compartment (closeTo 5e-3).

### Task B2: ChainTimeAxis (seam-compressed time -> X)

**Files:** Create `lib/features/dive_3d/domain/tissue/chain_time_axis.dart`; Test `chain_time_axis_test.dart`.

- Maps chain clock seconds -> X in `[0, SceneBounds.xSpan]` where dive spans are proportional and each surface interval occupies a fixed narrow seam width (e.g. 4% of xSpan each), regardless of real SI duration.
- `double xOf(double clockSeconds)`, plus `List<double> seamXs` for readout labeling.
- Tests: two equal dives with a huge SI between them -> each dive occupies ~48% width, seam ~4%; monotonic.

### Task B3: TissueSurfaceBuilder

**Files:** Create `lib/features/dive_3d/domain/tissue/tissue_surface_builder.dart`; Test `tissue_surface_builder_test.dart`.

- `enum TissueGas { combined, n2, he }`; `enum TissueColorMode { mValue, absolute }`.
- `static MeshData buildSurface({required TissueReplayResult result, required ChainTimeAxis axis, required TissueGas gas, required TissueColorMode colorMode})`: grid over (column) x (16 compartments). x = axis.xOf(time), z = compartment mapped across `[-zSlabHalfWidth, +zSlabHalfWidth]`, y = loading (combined = N2+He, or the selected gas) scaled so the max loading in the result maps to a fixed visual height. Color: mValue mode -> gradientFactor ramp (green->amber->red via MetricPalette-style); absolute mode -> loading ramp. Two triangles per grid cell.
- `static MeshData? buildControllingRidge({required result, required axis})`: a thin bright strip following the controlling compartment per column.
- `static ScrubPath scrubPath(...)`: xs = column X values, ys = a fixed top-of-surface height (cursor rides as a column marker) - actually emit a vertical column indicator via a small mesh in the geometry service; the ScrubPath cursor sits at the surface top for the scrubbed column.
- Tests: vertex/index counts (columns x 16), y height reflects relative loading, colorMode switches channels, controlling ridge follows argmax.

### Task B4: TissueGeometryService

**Files:** Create `lib/features/dive_3d/domain/tissue/tissue_geometry_service.dart`; Test `tissue_geometry_service_test.dart`.

- `Scene3d build(TissueReplayResult result, {required TissueGas gas, required TissueColorMode colorMode, bool splitHelium})`: bounds sized to the chain; layers = surface(null overlay) + controlling ridge(null); markers = []; scrubPath from the axis. When `splitHelium` and the chain has helium, build two offset surfaces (N2 and He) instead of the combined one.
- Tests: combined vs split layer counts; helium split only when He present.

---

## Phase C - Providers + page integration

### Task C1: Tissue providers

**Files:** Create `lib/features/dive_3d/application/tissue_providers.dart`; Test `test/features/dive_3d/application/tissue_providers_test.dart`.

- `tissueChainProvider(diveId)` - derives the day-chain: walk the diver's dives ordered by time, include neighbors while surface interval < 24h from the entry dive. Returns ordered dives + SIs.
- `tissueReplayProvider(diveId)` - `FutureProvider.family<TissueReplayResult?, String>`: assembles `TissueChainInput` (per-dive decimated times/depths, gas legs from tanks/switches via existing `buildProfileGasSegments` or a local builder, environment from dive altitude/water type, GF from dive or diver defaults), runs `TissueReplayService` (sync under threshold, else `compute()`), null when the entry dive has no profile.
- `typedef TissueGeometryKey = ({String diveId, TissueGas gas, TissueColorMode colorMode, bool splitHelium});` and `tissueGeometryProvider` -> `Scene3d?`.
- Tests: chain window (23h in, 25h out), replay assembles from mocked source profiles, geometry non-null for a profiled dive.

### Task C2: Scene switcher + tissue readout + toggles + l10n

**Files:** Modify `dive_3d_page.dart`; create `lib/features/dive_3d/presentation/widgets/tissue_readout_panel.dart`; modify l10n arbs; Test page test additions.

- `enum SceneKind { dive, tissue }` on the page (segmented control in the app bar). Tissue mode watches `tissueGeometryProvider` + `tissueReplayProvider` and renders the same `Dive3dInteractiveViewport`.
- Controls in tissue mode: gas toggle (Combined default; N2/He split shown only when the chain has helium), color-mode toggle (M-value / Absolute).
- `TissueReadoutPanel`: at the scrub instant, controlling compartment number, its %M (gradientFactor x100), ceiling implied, and per-gas loading when split. Interpolates the replay result over chain time; listens to the scrub `ValueListenable` directly.
- l10n keys: `dive3d_scene_dive`, `dive3d_scene_tissue`, `dive3d_tissue_gasCombined`, `dive3d_tissue_gasN2`, `dive3d_tissue_gasHe`, `dive3d_tissue_colorMValue`, `dive3d_tissue_colorAbsolute`, `dive3d_tissue_controlling`, `dive3d_tissue_modelLabel` (e.g. "Buhlmann ZHL-16C GF {low}/{high}").
- Tests: scene switcher toggles kind; tissue controls render; readout shows controlling compartment at a known scrub position.

### Task C3: Verification sweep + push

- `dart format . && flutter analyze` clean; `flutter test test/features/dive_3d/ test/core/deco/` green; l10n completeness grep; push; watch CI.
