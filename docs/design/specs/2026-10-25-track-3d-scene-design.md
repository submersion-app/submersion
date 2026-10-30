# Underwater Track 3D Scene

Issue: #3649

## Problem

The dive detail page offers two distinct 3D views side by side
(`dive_detail_page.dart:1960-1979`): `Icons.terrain` -> `SpatialSitePage`
(3D site terrain) and `Icons.view_in_ar` (a cube) -> `Dive3dPage` (an
animated, scrubbable 3D scene of the dive's own profile, colorable by
metric, with a time scrubber and play/pause).

An underwater track's detail page already has the `terrain`-equivalent
(`NavTrackSeascapePage`, the `nav-track-open-3d` button) but nothing
equivalent to `Dive3dPage`. A track has no gas model (no tank pressure,
ppO2, CNS, TTS, ascent-rate ceiling) so `Dive3dPage` cannot be reused
as-is, but it can for everything a track *does* record: depth over time,
temperature, DPV speed, and battery voltage, all already parsed per
sample onto `NavTrackPoint` (confirmed against a real Seacraft ENC log,
018.DAT.csv).

## Solution

### What's reused unchanged

The dive_3d feature's rendering layer turns out to be entity-agnostic --
it consumes a renderer-neutral `Scene3d` (layers + markers + bounds +
scrub path), never a `Dive` directly:

- `Scene3d`, `SceneLayer`, `ScrubPath`, `SceneBounds`, `MeshData` (domain
  types)
- `RibbonBuilder.curtain` / `PathBuilder.build` (pure geometry: take
  `times`/`depths`/`zs`/bounds, return meshes -- no `Dive` reference)
- `buildDiveAxes` (pure geometry: ticks + titles in, `AxisFrame` +
  `AxisLabelSet` out)
- `Dive3dInteractiveViewport` (takes a `Scene3d` + chrome config;
  `SceneChromeMode.framed` is its own documented mode for "the dive path
  scene"). Verified past the surface read: `framed` force-unwraps both
  `axisFrame` *and* `chromeStyle` (`dive_3d_interactive_viewport.dart:461-462`),
  not just `axisFrame`/`axisLabels` as first assumed. `chromeStyle` turns
  out to be free, too -- `diveChromeStyle(context)` (`dive_chrome.dart`)
  builds it from `Theme.of(context).colorScheme` alone, no dive data
  anywhere in it. Reused verbatim, zero new code for this piece.
- `TimeScrubBar` (a bare `ValueNotifier<double>`, zero domain coupling)
- `ProfileLookup` (generic time-interpolation over `List<double>`)
- The dive scene's own **zero-Z default path**: `scene_geometry_service.dart`
  already fills `zs` with `List<double>.filled(times.length, 0)` whenever
  no Z-axis metric is picked, which is `Dive3dPage`'s own starting state
  (`_zMetric` is null until the diver picks one). A z-less track scene
  isn't a new, unverified code path -- it's the same one the dive scene
  takes by default every time it first opens.
- The player's **fixed 45-second playback** (`Duration(seconds: 45)` in
  `Dive3dPage`'s `_player` `AnimationController`, `dive_3d_page.dart:118-121`)
  is not derived from `data.durationSeconds` -- animates the normalized
  0..1 position over a constant real-world duration regardless of how
  long the dive (or track) actually was. Copied as-is, no track-duration
  dependency to get wrong.

### What's new (track-specific, much smaller than the dive equivalents)

1. **`TrackSceneMetric`** -- its own enum (`depth`, `temperature`,
   `speed`, `batteryVoltage`), not an extension of `dive_3d`'s
   `SceneMetric`: that enum's exhaustive switches live across several
   dive-only files (`scene_geometry_service.dart`, `dive_3d_page.dart`,
   `Dive3dSceneData.availableMetrics`), and a track has neither
   `ascentRate`/`ppO2`/`cns`/`tankPressure`/`tts` nor a use for them.
   Reusing that enum would mean four new dead cases in every one of those
   switches. A small parallel `TrackMetricPalette` (continuous ramp only
   -- no `ascentRate`/`tts` special-casing) reuses `MetricPalette`'s own
   ramp colors for visual consistency with the dive scene.
2. **`NavTrack3dSceneData`** -- plain series (`times` elapsed-seconds
   from the route's own `NavTrackCorrector.activeRange` start, `depths`,
   `temperatures`, `speeds`, `batteryVolts`), built from `route.points`.
   Scoped to the active range for the same reason `NavTrackStats.of`
   already is: the post-dive GPS-fix sample and the out-of-water tail
   are calibration, not the dive. Verified `_activeRange`'s fallback for
   a track with no GPS fix event at all (a cave dive, no surface contact
   anywhere in the recording, the case the user's own worry about a
   surface-driven artifact raised a few turns ago): no `preDiveFixEvent`
   leaves `start = 0`, and with no `gpsFixed`/`outOfWater` run anywhere
   to end the walk early, `end` reaches `length - 1` -- the whole
   recording, same as `NavTrackStats.of` already does for exactly that
   case today. No special-casing needed.
   `route.points` is confirmed fully hydrated on the detail page this
   button lives on: `navTrackByIdProvider`'s own doc comment says so
   directly ("One route, hydrated with its points, for the detail and
   alignment pages") and its body calls `getById(id, includePoints:
   true)` (`nav_track_providers.dart:60-71`).
3. **`NavTrackSceneGeometryService`** -- the track's own `build()`,
   modeled on `SceneGeometryService.build` but with the dive-only parts
   dropped: no strata, shadows, ceiling, or Z-axis metric (a track has
   nothing worth putting on a third axis). No markers in this first pass
   (see Out of scope) -- `RibbonBuilder.curtain` + `PathBuilder.build`
   are the only two mesh layers. Decimation reuses
   `decimateSeriesIndices` (`dive_log/presentation/widgets/profile_decimator.dart`)
   the same way the dive service does. That import crosses both a
   feature boundary (`nav_track` -> `dive_log`) and a layer boundary
   (domain -> presentation) at face value, but it is already exactly how
   `dive_3d`'s own `scene_geometry_service.dart` imports it -- an
   existing precedent, not a new violation. Functionally it is also
   already generic: `decimateSeriesIndices` is documented as
   "`decimateProfileIndices` without the safety force-keeps" and calls
   it with `bands`/`decoTypes` filled with neutral, never-crossing values
   (all-zero bands, all `-1` decoTypes) -- the dive-specific force-keep
   logic inside never actually triggers through this entry point, for a
   dive or a track alike.
4. **Providers** (`nav_track_3d_providers.dart`) -- `navTrack3dSceneDataProvider`
   and `navTrack3dGeometryProvider`, mirroring `dive_3d/application/providers.dart`'s
   shape but watching only `navTrackByIdProvider` (no tank/gas/event/photo
   providers to watch).
5. **`NavTrack3dPage`** -- modeled on `Dive3dPage`'s single-scene path
   (the `dive` `SceneKind` only -- no tissue/computers equivalent for a
   track), with:
   - the viewport (`Dive3dInteractiveViewport`, `chromeMode: framed`,
     `scrubCursor: dot`, no overlays)
   - a metric picker (4 options instead of 8)
   - `TimeScrubBar` + play/pause, reused verbatim
   - a readout panel showing all four metrics at the scrub instant
     (depth/temperature/speed via the respective `UnitFormatter` methods
     -- `formatDepth`, `formatTemperature`, the already-fixed
     `formatTrackSpeed` -- battery as a plain `"x.xx V"`, no unit to
     convert)
6. **Wiring**: a new `Icons.view_in_ar` `IconButton` on
   `NavTrackDetailPage`, next to the existing `terrain` button, pushing
   `NavTrack3dPage(trackId: route.id)` the same way the dive page pushes
   `Dive3dPage(diveId: dive.id)`.
7. **l10n reuse, not duplication**: `dive3d_metric_depth` ("Depth"/"Tiefe")
   and `dive3d_metric_temperature` ("Temp") already exist and say exactly
   what the track picker needs for those two metrics -- reused directly,
   not re-declared under a new key. Only `speed` and `batteryVoltage`
   need genuinely new strings; `dive3d_previewTitle` ("3D View"/"3D-Ansicht")
   is the pattern to match for the new `navTrack3d_previewTitle`.

## Out of scope

- **Markers** (gas switches, bookmarks, photos on the dive scene have no
  track equivalent; a simple start/end marker pair was considered but
  `SceneMarkerKind` has no generic "start"/"end" case and adding one
  touches the shared renderer's marker-drawing switch -- deferred rather
  than widen the blast radius for a first pass).
- **Z-axis metric** (a third axis showing, say, speed while color shows
  temperature) -- the dive scene's Z-axis picker is a real feature but
  adds real UI/geometry surface; a track's four metrics are better served
  by the color picker alone for now.
- **Computers/tissue-equivalent scene kinds** -- a track has one data
  source and no gas model, so there is nothing for either to compare.
- **Course/pitch/roll/cumulative distance** as metrics -- discussed and
  ruled out with the user: not meaningful as a color ramp or scene data
  for this feature.
