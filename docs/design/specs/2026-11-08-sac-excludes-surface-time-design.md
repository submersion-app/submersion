# SAC and RMV leave out surface time at the ends of a dive

Issue: #2930 (from discussion #2250). Release v1.8.5.

## Why

Some computers keep logging while the transmitter is pressurised, so a dive
can end with minutes of samples at the surface, and some start logging before
the descent. Whole-dive SAC and RMV divide the gas used by the runtime and by
the ambient pressure at the average depth, so those surface minutes count as
time the diver breathed at depth. The rate comes out too low, and the longer
the diver stays on the surface with the computer awake, the lower it gets.

Range SAC and RMV on the profile (the issue's suggested alternative) already
exist and are not changed here.

## Goals

- Whole-dive SAC (bar/min) and RMV (L/min) divide by the time the diver was
  underwater and by the average depth over that time, not by the whole
  recording.
- The same number everywhere a whole-dive rate appears: the dive page, its SAC
  by cylinder rows, dive cards and the table, PDF and exports, statistics and
  insights charts and records, and the query language.
- Dives with no surface time at either end keep exactly the SAC they have now.

## Non-goals

- Runtime, bottom time, the profile, average depth as displayed, and every
  other duration stay as recorded. Nothing stored on the dive changes.
- No setting and no per-dive override (the second idea in the issue comment).
  A setting only makes sense if some diver wants surface time in their SAC.
- Surface intervals in the middle of a dive (a surface swim between two
  descents) are not trimmed: only the leading and trailing runs.
- Range SAC on the profile, SAC segments and the SAC curve already work from
  the pressure samples in the chosen time and are left alone.
- Rebreather gas rates (CCR O2 and diluent use) are not changed.

## Anti-goals

- A dive's SAC must not differ between its card, its detail page and the
  statistics, even for a moment after the sweep has run.
- Trimming must never make a dive's rate unavailable where it was available.

## The rule (pure, one implementation)

A `GasUseWindow` is computed from the depth samples alone:

1. A sample deeper than **1.0 m** (`kSurfaceDepthM`, matching the buoyancy
   twin analyzer) is underwater.
2. The window starts at the sample just before the first underwater sample
   (the descent starts there) and ends at the sample just after the last one
   (the end of the ascent). With no sample before or after, it starts or ends
   at the underwater sample itself.
3. When the window covers the whole recording (nothing to trim), or no sample
   is underwater, or there are fewer than two samples, there is no window and
   the rates use what they use today.
4. Otherwise the window carries its length in seconds and the time-weighted
   mean depth of the samples inside it (the same `timeWeightedMean` the dive's
   average depth uses).

The SAC and RMV divide by `min(window length, measured runtime)`: a runtime
that a diver already shortened by hand is not shortened twice. They use the
window's average depth for the ambient pressure. With no window, they keep the
measured runtime and the stored average depth, so a dive without a surface
tail does not move.

Depth only, so it works with or without a transmitter. Known limitation (my
call): a diver who breathes a logged cylinder at the surface (0 m oxygen, a
surface swim on the regulator) has that gas counted against the underwater
time, so their rate reads a little high. The entity has no pressure series to
detect that, and the trailing surface tail the issue describes is far more
common.

## Where the window lives

- **Dart, with samples** (the detail page): `Dive.gasUseWindow` computes it from
  `profile`.
- **Dart, without samples** (list reads, exports): the dive repository fills a
  new read-only `Dive.storedGasUseWindow` from the derived metrics cache,
  the way `profileSpan` is filled today.
- **SQL** (statistics, insights, query fields): `gasUseSecondsSql` and
  `gasUseAvgDepthSql` read the same cache row.
- **Cache:** `dive_derived_metrics` gains `gas_use_s` and `gas_use_avg_depth_m`
  (nullable, device-local, schema rung). `DerivedMetricsService` computes them
  with the same pure function, for every dive with samples, including gauge,
  rebreather and pressure-less dives. Its version is bumped so the sweep fills
  every existing row once.

A stale cache row (built before the dive's latest edit) is used until the
scheduler rebuilds it, which every write already schedules.

## Builder's calls

- The 1.0 m surface threshold and the neighbouring-sample rule.
- No minimum trim: any surface run at either end is trimmed.
- Per-cylinder SAC (`GasAnalysisService.calculateCylinderSac`) uses the window
  as the dive's start and end, so a single-cylinder dive's row agrees with the
  dive's SAC.
- The statistics and insights ticks follow `dive_derived_metrics`, so a rate
  refreshes once the sweep fills a row.
