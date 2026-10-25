# Underwater Track 3D Scene Implementation Plan

> Revised after a cross-examination pass (see spec for the full
> reasoning): `chromeStyle` is force-required by `SceneChromeMode.framed`
> too, but resolves to a free, already-generic `diveChromeStyle(context)`
> call; the zero-Z and 45-second-playback assumptions are both already
> the dive scene's own default/fixed behavior, not new/unverified paths;
> `decimateSeriesIndices`'s cross-feature import already has precedent
> in `dive_3d` itself; `activeRange`'s no-fix-event fallback and
> `navTrackByIdProvider`'s point hydration are both confirmed safe by
> reading the actual code; and two of the four metric-picker labels
> should reuse existing `dive3d_metric_*` strings instead of duplicating
> them under a new key.

**Goal:** A `Dive3dPage`-equivalent 3D scene for underwater tracks, scoped
to depth/temperature/speed/battery voltage, reusing the dive_3d feature's
entity-agnostic rendering layer.

**Spec:** `docs/design/specs/2026-10-25-track-3d-scene-design.md`

**Issue:** Closes #3649

---

## File Structure

### New Files

| File | Responsibility |
|------|-----------------|
| `lib/features/nav_track/domain/track_3d/track_scene_metric.dart` | `TrackSceneMetric` enum + `TrackMetricPalette.colorsFor` (continuous ramp only) |
| `lib/features/nav_track/domain/track_3d/nav_track_3d_scene_data.dart` | `NavTrack3dSceneData`: plain series from `route.points`, scoped to the active range |
| `lib/features/nav_track/domain/track_3d/nav_track_scene_geometry_service.dart` | `NavTrackSceneGeometryService.build()`: `NavTrack3dSceneData` + `TrackSceneMetric` -> `Scene3d` |
| `lib/features/nav_track/presentation/providers/nav_track_3d_providers.dart` | `navTrack3dSceneDataProvider`, `navTrack3dGeometryProvider` |
| `lib/features/nav_track/presentation/pages/nav_track_3d_page.dart` | The page: viewport, metric picker, scrub bar, readout panel |
| `lib/features/nav_track/presentation/widgets/track_readout_panel.dart` | Live metric readout at the scrub instant (mirrors `SceneReadoutPanel`/`dive_readout_rows.dart`, four rows instead of eight) |
| `test/features/nav_track/domain/track_3d/track_scene_metric_test.dart` | Palette output for each metric, null handling |
| `test/features/nav_track/domain/track_3d/nav_track_3d_scene_data_test.dart` | Series extraction, active-range scoping, `availableMetrics` |
| `test/features/nav_track/domain/track_3d/nav_track_scene_geometry_service_test.dart` | Scene bounds/layers/scrubPath shape for a known input |
| `test/features/nav_track/presentation/pages/nav_track_3d_page_test.dart` | Page renders, metric picker switches color, scrub bar updates readout |

### Modified Files

| File | Change |
|------|--------|
| `lib/features/nav_track/presentation/pages/nav_track_detail_page.dart` | Add the `view_in_ar` `IconButton` next to the existing `terrain` one |
| `lib/l10n/arb/app_en.arb` (+ `app_de.arb`) | New strings: `navTrack3d_previewTitle`, `navTrack3d_metric_depth`, `navTrack3d_metric_temperature`, `navTrack3d_metric_speed`, `navTrack3d_metric_battery` |
| `test/features/nav_track/presentation/pages/nav_track_detail_page_test.dart` | New test: the cube button pushes `NavTrack3dPage` |

**Explicitly reused, unmodified** (confirmed entity-agnostic by reading
their source -- listed so nothing looks missed): `Scene3d`, `SceneLayer`,
`ScrubPath`, `SceneBounds`, `MeshData`, `RibbonBuilder.curtain`,
`PathBuilder.build`, `buildDiveAxes`, `Dive3dInteractiveViewport`,
`TimeScrubBar`, `ProfileLookup`, `MetricPalette`'s ramp constants (read,
not imported -- `TrackMetricPalette` duplicates the four-color ramp
rather than reaching into `dive_3d`'s private `_ramp`).

---

## Task 1: `TrackSceneMetric` + `TrackMetricPalette`

- [ ] `enum TrackSceneMetric { depth, temperature, speed, batteryVoltage }`.
- [ ] `TrackMetricPalette.colorsFor(metric, values) -> Float32List`, same
      shape as `MetricPalette.colorsFor` but only the continuous-ramp
      branch (no `ascentRate`/`tts` special cases): normalize to the
      series' own min/max, lerp across a 4-stop ramp, grey for null/
      non-finite.
- [ ] Test: known values map to expected ramp positions; a null entry
      gets the grey fallback; a constant series (max - min < 1e-9) maps
      every value to the ramp midpoint (mirrors `MetricPalette`'s own
      guard).

## Task 2: `NavTrack3dSceneData`

- [ ] `factory NavTrack3dSceneData.fromRoute(NavTrack route)`:
      - active range via `NavTrackCorrector.activeRange(route.points)`
        (same boundary `NavTrackStats.of` and the 2D polyline layer use).
      - `times`: `point.timestamp - active.first.timestamp` (elapsed
        seconds, matching `SceneBounds(durationSeconds:)`'s convention).
      - `depths`, `temperatures`, `speeds`, `batteryVolts`: straight
        copies from the active-range points.
      - `durationSeconds`: `times.last` (0 when fewer than 2 points).
      - `maxDepthMeters`: max of `depths`.
- [ ] `bool get hasProfile => times.length >= 2`.
- [ ] `Set<TrackSceneMetric> get availableMetrics`: depth always; the
      other three only when at least one sample is finite (mirrors
      `Dive3dSceneData.availableMetrics`'s `_any` check).
- [ ] Tests: active-range scoping actually drops a post-fix tail (reuse
      a `NavTrack` fixture with a `gpsFixed`/`outOfWater` tail, same shape
      the corrector's own tests build); `availableMetrics` omits a metric
      whose series is all-null; `hasProfile` false for 0-1 points.

## Task 3: `NavTrackSceneGeometryService`

- [ ] `Scene3d build(NavTrack3dSceneData data, TrackSceneMetric colorMetric)`:
      - `SceneBounds(durationSeconds: data.durationSeconds, maxDepthMeters:
        data.maxDepthMeters, sceneMinZ: -SceneBounds.zPathHalfSpan,
        sceneMaxZ: SceneBounds.zPathHalfSpan)` (zs stays `0` everywhere --
        no Z-axis metric).
      - Reuse `decimateSeriesIndices` (same `targetPoints = 2000` the dive
        service uses) so a long recording (6600+ samples, per the sample
        file) doesn't build an oversized mesh.
      - `colorValues` from the chosen metric's series (plain switch, no
        tank-pressure-style resampling needed -- every series already
        shares the same sample cadence).
      - Layers: `SceneLayer(RibbonBuilder.curtain(...))` +
        `SceneLayer(PathBuilder.build(...))`, no `overlay:` (nothing to
        gate -- there are no optional overlays in this scene).
      - `markers: const []` (see spec, Out of scope).
      - `scrubPath`: same shape as the dive service's, `zs` all zero.
- [ ] Test: bounds reflect the input's duration/max depth; the ribbon
      layer's mesh is non-empty for a 2+ point input; an empty/1-point
      input returns a scene with empty layers rather than throwing
      (mirrors how the dive service is never called for `!hasProfile`
      data -- the page gates on that the same way `Dive3dPage` does).

## Task 4: Providers

- [ ] `navTrack3dSceneDataProvider = FutureProvider.family<NavTrack3dSceneData?, String>`:
      watches `navTrackByIdProvider(trackId)`, returns null when the
      route is null or `!hasProfile`.
- [ ] `navTrack3dGeometryProvider = FutureProvider.family<Scene3d?, (String, TrackSceneMetric)>`:
      same `_computeThreshold`/`compute()` isolate-hop pattern as
      `dive3dGeometryProvider` (2000 samples), for the same reason (a
      6600-sample file is exactly the case this guards).

## Task 5: `TrackReadoutPanel`

- [ ] `trackReadoutRows({required NavTrack3dSceneData data, required double
      timestampSeconds, required UnitFormatter units, required AppLocalizations
      l10n, TrackSceneMetric? emphasize})`: four rows (depth, temperature,
      speed, battery), each `ProfileLookup(data.times).interpolate(series,
      timestampSeconds)`, formatted via `units.formatDepth` /
      `units.formatTemperature` / `units.formatTrackSpeed` / a plain
      `'${v.toStringAsFixed(2)} V'`; a row is omitted when its metric
      isn't in `data.availableMetrics`.
- [ ] `TrackReadoutPanel` widget: same `ValueListenableBuilder<double>` +
      `Wrap` shape as `SceneReadoutPanel`, built from `trackReadoutRows`
      instead of `diveReadoutRows`.
- [ ] Test: interpolates correctly between two known samples; omits a
      row for a metric with no data; emphasizes the active color metric.

## Task 6: `NavTrack3dPage`

- [ ] `ConsumerStatefulWidget` taking `trackId`, mirroring
      `_Dive3dPageState`'s shape but with only the single scene kind:
      `ValueNotifier<double> _position`, `AnimationController _player`,
      `TrackSceneMetric _colorMetric = TrackSceneMetric.depth`.
- [ ] `Scaffold(appBar: AppBar(title: Text(l10n.navTrack3d_previewTitle)))`,
      body: loading/error/empty states (route not found, or
      `!hasProfile`) then the scene scaffold:
      - `Expanded(child: Dive3dInteractiveViewport(scene: ..., chromeMode:
        SceneChromeMode.framed, scrubCursor: ScrubCursorStyle.dot,
        visibleOverlays: const {}, axisFrame: ..., axisLabels: ...,
        chromeStyle: diveChromeStyle(context)))` -- `framed` mode
        force-unwraps `chromeStyle` too, not just `axisFrame`
        (`dive_3d_interactive_viewport.dart:461-462`), but
        `diveChromeStyle` (`dive_3d/presentation/dive_chrome.dart`) is
        pure theme lookup, reused verbatim with no new code. Axes built
        via the reused `buildDiveAxes`, same tick-building helpers
        `depthAxisTicks`/`timeAxisTicks`.
      - metric picker: `SegmentedButton<TrackSceneMetric>`, options from
        `data.availableMetrics`.
      - `TrackReadoutPanel` + `TimeScrubBar` + play/pause, same wiring
        as `Dive3dPage`'s own player (`AnimationController` driving
        `_position`, pausing on `onScrubStart`).
- [ ] Tests: renders the viewport for a track with a profile; shows the
      empty state for a track with `pointCount < 2`; switching the metric
      picker changes which provider key is watched (assert via a spy
      override or by checking the emphasized readout row); dragging the
      scrub bar updates the readout panel's values.

## Task 7: Wire into `NavTrackDetailPage`

- [ ] Add the `Icons.view_in_ar` `IconButton` (tooltip
      `navTrack3d_previewTitle`) next to the existing `nav-track-open-3d`
      `terrain` button, `key: ValueKey('nav-track-open-3d-preview')`,
      pushing `MaterialPageRoute(builder: (_) => NavTrack3dPage(trackId:
      route.id))` -- same `Navigator.of(context).push` shape the dive
      page's own `view_in_ar` button uses (not a named/go_router route,
      matching precedent).
- [ ] Test: tapping the new button pushes `NavTrack3dPage` with the right
      `trackId` (same shape as the existing align/3d-seascape button
      tests in `nav_track_detail_page_test.dart`).

## Task 8: l10n

- [ ] `navTrack3d_previewTitle`: confirmed pattern to match --
      `dive3d_previewTitle` is "3D View" / "3D-Ansicht" (not "3D preview"
      as first guessed); use the same wording for consistency between
      the two cube buttons rather than inventing new phrasing.
- [ ] **Reuse, don't duplicate**: `dive3d_metric_depth` ("Depth"/"Tiefe")
      and `dive3d_metric_temperature` ("Temp"/...) already exist --
      confirmed present in `app_en.arb`. Reference them directly from
      the track metric picker.
- [ ] New keys, no existing equivalent: `navTrack3d_metric_speed`,
      `navTrack3d_metric_batteryVoltage`.

## Task 9: Verification

- [ ] `flutter gen-l10n`
- [ ] `dart format .`
- [ ] `flutter analyze`
- [ ] `/code-review` on the full diff before pushing.
- [ ] Manual check on the Hot Build with the real sample file
      (018.DAT.csv, already linked via a dive through this session's
      other fixes): scrub through, switch metrics, confirm the four
      readouts track the earlier-verified max/avg figures.

## Decided without asking

- Metric picker default: `depth`, matching the existing 2D polyline
  layer's own depth-color default (`BathymetryTerrainBuilder.depthColor`)
  -- keeps the 2D map and the new 3D view reading the same way at first
  glance. Speed is one tap away in the same picker.
