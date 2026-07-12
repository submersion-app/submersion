# Tissue Saturation 3D Scene - Design (dive 3D view, phase 2)

**Date:** 2026-07-11
**Status:** Approved design, pending implementation plan
**Depends on:** the dive 3D view foundation (PR #565) - geometry layer,
`SceneProjector`/`Dive3dPreviewPainter` CustomPainter renderer,
`Dive3dInteractiveViewport`, scrub timeline. **No external 3D library**:
this scene renders through the same `Canvas.drawVertices` pipeline.

## What it shows

A "tissue landscape": inert-gas loading across the 16 Buhlmann
compartments over a repetitive-dive chain, including the surface intervals
between dives. The saturation wave visibly travels from fast compartments
(spiking early, draining fast) toward slow ones; off-gassing during
surface intervals and residual loading carried into the next dive are the
core teaching payload.

## Approved product decisions

- **Scope:** full repetitive-dive chains, not single dives. The time axis
  spans from the first dive's descent to the last dive's surfacing.
- **Chain selection:** automatic day-chain. Entered from any dive's 3D
  page (scene switcher "Dive" / "Tissues"); the chain is every dive linked
  to it by surface intervals under 24 h. No picker UI.
- **N2 vs He:** default surface shows combined inert-gas loading. A He
  toggle (shown only when the chain includes helium) splits into separate
  N2 and He surfaces - the fast-draining He landscape vs the slow N2 one
  is the isobaric counter-diffusion story in one picture.

## Scene geometry

Coordinate convention from the phase-1 spec: **X = chain time**,
**Z = compartment index** (1-16, fast to slow), **Y = loading (bar)**.
One surface mesh over the X x Z grid with Y heights, emitted as the same
`MeshData` the phase-1 builders produce, rendered by the unchanged
painter/viewport.

- **Surface-interval compression:** each SI renders at a fixed narrow
  width (a "seam" band) with its real duration labeled via the readout;
  at real scale a 2 h interval would flatten two 50 min dives into
  slivers. Dive segments render at full proportional width.
- **Color modes:** default is **% of M-value** (supersaturation toward
  the GF-adjusted Buhlmann limit): green -> amber -> red, making the
  controlling compartment the reddest ridge. Toggle to absolute loading
  (bar). Both map through `MetricPalette`-style ramps.
- **Controlling-compartment ridge:** the compartment with max %M at each
  time step is highlighted (brighter ridge line strip on the surface).
- **Scrub cursor:** the phase-1 timeline scrubs the chain; the cursor
  becomes a highlighted time-column (a translucent plane at X = t) drawn
  by the foregroundPainter, same repaint-isolation pattern as phase 1.
- **Readout:** at the scrub instant - controlling compartment number, its
  %M, the ceiling it implies, and (when split) per-gas loading. Formatted
  via UnitFormatter where units apply.

## Data: TissueReplayService

Pure Dart, isolate-friendly (`compute()` above the same threshold pattern
as phase 1), mirroring the repo convention that the pure worker is the
tested unit.

- **Chain derivation:** repository query for the diver's dives ordered by
  time; walk neighbors while surface interval < 24 h in both directions
  from the entry dive.
- **Replay:** for each dive, feed its full-resolution profile through the
  existing `BuhlmannAlgorithm` (golden-vector tested) with that dive's
  recorded gas mixes and switches and its recorded GF settings (diver
  defaults when absent). Between dives, off-gas at local surface pressure
  for the interval duration. Residual state carries forward.
- **Input decimation:** replay input decimated to >= 1 sample / 10 s -
  tissue kinetics are far slower than profile sampling; this bounds chain
  replay cost. Readout values interpolate the replay output, not the raw
  profile.
- **Output:** flat typed arrays (isolate-transferable): times, seam
  boundaries, per-time 16-compartment N2 and He loadings (combined
  derived), per-time controlling compartment and %M.

## New components

```
lib/features/dive_3d/
  domain/
    tissue_replay_service.dart      // chain replay -> TissueReplayResult
    geometry/tissue_surface_builder.dart  // grid surface -> MeshData
  application/tissue_providers.dart // chain + replay + geometry providers
  presentation/
    (Dive3dPage gains a scene switcher; readout panel gains a tissue mode)
```

Everything else - viewport, painter, projector, scrub bar, page chrome -
is reused unchanged. The preview card stays the dive scene.

## Testing

- Replay service vs the deco golden-vector corpus for single dives; He/N2
  half-time off-gassing assertions across synthetic surface intervals;
  chain-derivation window tests (23 h in, 25 h out).
- Surface builder: grid vertex/index counts, seam compression widths,
  %M color mapping, controlling-ridge selection.
- Widget tests: scene switcher, color-mode and He toggles, readout values
  at known scrub instants. The viewport needs no new tests.

## Risks

- Long-chain replay cost: bounded by input decimation + compute();
  measure with a 4-dive liveaboard day before tuning further.
- GF/algorithm fidelity: dives downloaded from computers may record
  different algorithms than Buhlmann GF; the scene labels the model it
  replays with ("Buhlmann ZHL-16C GF lo/hi") so it never presents itself
  as the computer's own math.

## Explicitly deferred

- Manual chain picker and trip-based entry.
- VPM-B replay.
- Predictive mode (extending the surface off-gassing curve into "time to
  fly / next-dive readiness") - natural phase 3 of this scene.
