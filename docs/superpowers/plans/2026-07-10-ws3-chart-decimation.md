# WS3: Chart Decimation + Scoped Series Cache Implementation Plan

> Executed inline (executing-plans) in worktree `.claude/worktrees/ws3-chart`,
> branch `worktree-ws3-chart`.

**Goal:** Ceiling-source toggles measured at ~0.85 s main-isolate CPU each
(profile mode, dive 1006, 4,762 samples; Skia dash-path measurement +
full series rebuild). Target < 200 ms by (a) rendering decimated series
(~2,000 points budget) everywhere the full profile is drawn today, and
(b) scoping the series cache so an analysis-curve change no longer rebuilds
the base depth/temperature/pressure series.

**Spec:** WS3 in `2026-07-10-large-db-performance-design.md`; evidence in
the findings doc (SkContourMeasure::getSegment + series-rebuild allocation).

## Design

1. **Shared decimation projection.** `decimateProfileIndices` (existing,
   tested, feature-preserving: depth envelope, max-depth spike, ascent-band
   crossings, decoType transitions) produces the kept ORIGINAL indices for
   the active profile. All parallel per-sample arrays (the 14 analysis
   curves, ascentRates) are projected through the same indices, so every
   series stays index-aligned. State fields `_dProfile`, `_dAscentRates`,
   `_dCeilingCurve`, ... hold the projections; series builders read them
   instead of `widget.*`. Tooltip/touch code keeps reading the ORIGINAL
   `widget.profile` (it already remaps touched spots by timestamp, which is
   decimation-compatible).
2. **Zoom-aware, quantized.** The projection covers the visible X window
   expanded by half a window on each side, at the full point budget. The
   viewport enters the cache signatures as a BUCKET (half-octave zoom steps,
   quarter-window pan steps): within a bucket, zoom/pan stays a pure cache
   hit exactly as today; crossing a bucket re-decimates (~ms at 2k points).
   Unzoomed charts use the whole range ('full' bucket). Deep zoom therefore
   converges to original resolution (window shrinks, budget constant).
3. **Scoped cache.** `ChartSeriesCache` gains per-key signatures
   (`series(key, signature, build)`); the single `'main'` assembly splits
   into four order-preserving groups:
   - `base`: depth (gas/velocity variants), gas-switch markers,
     temperature, tank pressures, heart rate, SAC, ascent-rate line.
   - `analysis`: ceiling, NDL, ppO2/ppN2/ppHe, MOD, density, GF, surface
     GF, mean depth, TTS, CNS, OTU (everything fed by analysis curves).
   - `markers`: profile marker lines.
   - `overlays`: comparison-source overlays (kept LAST, preserving the
     depth-bar leading-index invariant).
   A ceiling-source toggle re-emits analysis curves -> only `analysis`
   (and nothing else) rebuilds, over decimated points.
4. **Overlays decimated** per overlay source with the same helper (depth /
   temperature / ceiling / NDL series per overlay).
5. Tank-pressure series are NOT decimated (independent sparse timestamps,
   NaN-guard logic untouched; not implicated by measurement).

## Tasks

1. `ChartSeriesCache` per-key signatures + unit tests (extend existing
   test file if present, else create).
2. `DecimatedProfileView` helper (slice by visible fraction + decimate +
   project parallel arrays) + unit tests (budget respected, max-depth kept,
   slice covers expanded window, identity when under budget).
3. Chart surgery: projection state fields, four-group cache assembly with
   per-group signatures (viewport bucket included), builder bodies swapped
   to `_d*` fields.
4. Regression: chart-related test files + whole-project analyze/format.
5. Commit, push --no-verify, PR.

## Verification gates

- Existing chart/velocity/tooltip tests green.
- New cache + decimation tests green.
- Analyze/format clean.
