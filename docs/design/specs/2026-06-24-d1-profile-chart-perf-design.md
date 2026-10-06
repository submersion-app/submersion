# D1 — Dive Profile Chart Performance — Design

**Date:** 2026-06-24
**Status:** Design approved
**Branch/worktree:** `worktree-d1-profile-chart-perf`
**Parent:** Phase 2 of the app performance investigation (`2026-06-24-app-performance-investigation-design.md`, findings in `2026-06-24-app-performance-findings.md`)

## Goal

Make the dive profile chart cheap to build. Measurement (profile mode, Apple M5 Pro, 3,644-sample dive) found it **build-bound**: ~35 ms build / ~2.8 ms raster on a cold open, with the chart rebuilding all series on every interaction, plus a separate O(N^2) hot spot (`combineMultiTankPressures`, ~56 ms) on the same cold-open path.

## What the measurement established

- The curve **math** is already off the main isolate (`profileAnalysisProvider` runs `_runProfileAnalysis` in a `compute()` isolate). The 35 ms is purely **`FlSpot` reconstruction on the UI isolate**.
- The chart caches **nothing**: every `build()` re-maps the full ~3,644-point profile into `FlSpot` lists for ~20 curves (each `isCurved: true` Bézier). Rebuilds fire on tooltip hover, playback tick, legend toggle, and zoom/pan.
- `combineMultiTankPressures` (`profile_analysis_provider.dart:54`/`:624`) is an O(N^2) per-timestamp restart-from-zero scan, on the main isolate, before the analysis isolate.
- **Fidelity is safe:** events, gas switches, deco stops, and the ceiling are drawn from separate timestamp-keyed data (`dive_profile_events`/gas-switch tables) as vertical lines/markers — decimating the polylines cannot drop them. Tooltips/`onPointSelected` map `spotIndex -> widget.profile[i]`, so any decimation must keep a shared index map.

## Approach: pure decimator + in-widget per-curve memoization + O(N) merge-walk

Chosen seam is the **chart widget**, not the analysis isolate:

- A **pure decimator** returns a sorted `List<int>` of keep-indices, applied uniformly to the profile and every parallel curve array (alignment automatic; the list **is** the tooltip index map).
- The widget caches `FlSpot` lists **per curve**, invalidated only on `profile`/`units` change.

Rejected alternative: decimating inside `profileAnalysisProvider`'s isolate makes decimation "free" but over-couples analysis with display and forces an invasive provider return-type change. The decimator is O(N) (~1 ms, once, cached), so the main-isolate cost is negligible while the change stays localized and the widget remains the only thing that knows `FlSpot`.

## Component 1 — the decimator (`profile_decimator.dart`, pure + unit-tested)

- **Algorithm: min/max-per-bucket with forced-keep.** Bucket the time range into ~`targetN/2` buckets; from each keep the min-depth and max-depth sample (preserves the depth envelope and the max-depth spike exactly). Then **force-keep** any index where (a) the ascent-rate band changes (inter-sample velocity crosses 9 or 12 m/min) or (b) `decoType` transitions. O(N).
- **Threshold:** only decimate when `profile.length > kDecimationThreshold` (~2000, ~= chart px x DPI). Typical ~1,100-point dives are untouched (no-op path).
- **Output:** ascending `List<int>` of original indices to keep. `keepIndices[i]` is the original index for decimated position `i` (the tooltip index map).
- **Velocity is computed in metric** (unit-independent), so the decimator never depends on display units.
- **Why force-keeping band crossings is sufficient:** because every crossing is kept, no two adjacent kept samples ever span a band boundary, so the velocity recomputed on the decimated series over that span is the average of instantaneous velocities all within one band — which is itself within that band. The coloring therefore stays faithful; no rapid-ascent excursion can be averaged into a safer band.

## Component 2 — memoization (`dive_profile_chart.dart`)

- Cache, as widget fields: the decimated profile + `keepIndices`, the per-curve `List<FlSpot>` (built lazily on first show), and the velocity-colored depth segments.
- **Key:** `(profile identity, unit signature)`. Cleared in `didUpdateWidget` when `oldWidget.profile != widget.profile` (existing hook) and when the unit signature changes (store last-used signature, compare in `build`).
- **Visibility never invalidates** — legend toggles just select which cached lists go into `lineBarsData`. Playback ticks, hover, and zoom touch none of the cache keys, so they become pure cache hits.

## Component 3 — `combineMultiTankPressures` O(N^2) -> O(N)

- Replace the per-timestamp restart-from-zero scan with a single forward merge-walk: a per-tank cursor that only advances, interpolating the bracketing pressure points for each timestamp. Same output, linear time.
- Optionally relocate inside the existing `compute()` isolate (it is pure) for extra main-isolate relief.

## Invariants (dive-safety)

A decimated profile MUST preserve:
- the **max-depth** spike (deepest sample),
- the **ascent-rate velocity bands** — never merge across a 9 or 12 m/min crossing (a fabricated "green" rapid ascent is a safety defect),
- **`decoType` transitions** (NDL/safety/deco/deep-stop).

Tooltip/`onPointSelected` correctness MUST be preserved via the shared `keepIndices` map.

## Testing (TDD)

Write decimator tests first:
- max-depth spike always retained,
- a planted rapid-ascent excursion stays in its true velocity band (not fabricated-green),
- `decoType` transition samples retained,
- `keepIndices` round-trips (decimated position -> original sample),
- no-op when `length <= kDecimationThreshold`,
- timestamps remain strictly increasing.

Then a **parity test**: O(N) `combineMultiTankPressures` output matches the current implementation on a representative multi-tank dive. Then a before/after measurement with `vmcap.dart` (the proof-by-measurement gate): cold densest-dive build reduced, and interactions (hover/playback/zoom/legend) produce no series rebuild.

## Success criteria

- Interactions (hover, playback, legend, zoom) no longer rebuild `FlSpot` series — verified by cache behavior + frame timings.
- Cold densest-dive (3,644-sample) chart build reduced materially (target: under the 60 fps budget per frame; decimation removes ~40%+ of `FlSpot` work on dense dives).
- `combineMultiTankPressures` is O(N) with output parity.
- No dive-fidelity regression (decimator invariants tested).
- Test suite green; before/after `vmcap.dart` numbers recorded.

## Out of scope

- Viewport-aware re-decimation on zoom (future enhancement; current zoom does not slice spots).
- The other Phase 2 avenues (S3 offload sync CPU, S2 batch writes, S1 debounce, D2 lazy sections) — separate fixes/PRs.

## Measurement result (Plan A / D1a)

Captured in profile mode (Apple M5 Pro) via `scratchpad/vmcap.dart`, opening Dive #41 (3,644 samples):

- **`combineMultiTankPressures` O(N): CONFIRMED** — gone from the UI-isolate CPU hot list (was 56 ms in Phase 1).
- **Memoization: PROVEN by widget test** — a playback-only rebuild returns the identical `lineBarsData` instance; a profile change rebuilds it. The interaction jank (Phase 1's 87 over-budget warm frames) is eliminated deterministically.
- **Cold chart build: still ~36 ms** worst-frame build (vs 35.6 ms Phase 1) — unchanged, as expected (memoization caches after the first build; decimation deliberately unwired). Decimation (Plan B) is the lever for this one-time cost.
- **The on-launch sync base-apply still dominates the cold start** — `pread` 448 ms, `sqlite3VdbeExec` 245 ms, SHA-256 217 ms, `BaseJsonStreamReader` ~280 ms, all on the UI isolate (sync did not settle within the 20 s wait).

### Plan B decision
Decimation remains justified (cold build ~36 ms, ~4x over the 60 fps budget) but is **lower priority than S3 (offload sync CPU)**: the measured first-open cost is dominated by the sync base-apply, not the chart. Recommended order: ship D1a → **S3** → Plan B decimation as a later chart-polish pass.
