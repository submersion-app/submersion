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

1. A sample deeper than **1.0 m** (`kGasUseSurfaceDepthM`, matching the buoyancy
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

Depth alone decides the window. Breathing at the surface is the next section.

## Breathing at the surface

A diver can breathe a logged cylinder at the surface: oxygen on the boat after
a deco dive, or a surface swim on the regulator. That gas is in the cylinder's
drop, so leaving its minutes out makes the rate read high. A surface minute
counts at 1 bar, which is what SAC's pressure-minutes denominator already
expects, so the fix is to put those minutes back whenever something says they
were breathed. Three signals, decided by the user on 2026-11-08:

1. **A gas switch logged on the surface.** A switch to a breathing cylinder
   after the window closes (the diver switched to oxygen on the boat while the
   computer still logged) extends the window to the end of the recording.
2. **A cylinder's pressure still falling on the surface.** In the trailing
   surface run, a breathing cylinder whose pressure drops at least
   **5 bar** (`kSurfaceBreathingMinDropBar`) below its value where the window
   closes extends the window to the time it reaches its lowest. In the leading
   run, one that was at least 5 bar higher before the descent extends the
   window back to the last time it was at its highest. 5 bar sits above
   transmitter resolution and the temperature swing of a cylinder leaving the
   water, and below about four minutes of breathing on a 12 L cylinder.
3. **Minutes the diver enters.** Each cylinder gains "Breathed at the surface"
   (`dive_tanks.surface_breathing_s`, synced, nullable), for time after the
   computer stopped logging, which no recording shows. Those seconds count at
   0 m.

With 1 or 2 the window is still one span: it stretches to cover the surface
breathing, and its mean depth (surface samples near 0 m) brings the ambient
pressure toward 1 bar on its own. A window stretched to the whole recording is
no window, as before. With 3 the entered seconds are added to the time a rate
divides by, and the depth is blended as `window seconds x window depth /
(window seconds + entered seconds)`, the same as samples at 0 m.

Where each piece lives:

- **Pure:** `surfaceBreathingOf` (new) finds the bounds from the underwater
  window, the switch times and the pressure series; `gasUseWindowOf` takes the
  bounds and stretches to them.
- **SAC by cylinder and the role trend:** `cylinderUsage` takes the dive's
  pressure series and computes the bounds itself, since it has the switches
  and pressures in hand. A cylinder's entered seconds join its breathing time
  and depth, and the role trend adds a group's entered seconds the same way.
- **Cache:** the sweep reads the gas switches and the displayed pressure
  series, stores the stretched window in `gas_use_s` / `gas_use_avg_depth_m`,
  and stores the bounds in `surface_breathed_from_s` /
  `surface_breathed_until_s` (same v347 step, device-local). Its stamp gains
  the dive's gas switches, which never re-stamp the dive. Engine version 4 to 5.
- **Dive entity:** reads fill `Dive.surfaceBreathing` from the cache, and
  `Dive.gasUse` passes it to `gasUseWindowOf` on the profile. `_consumptionBasis`
  adds the breathing cylinders' entered seconds.
- **SQL:** `gasUseSecondsSql` adds the dive's entered seconds and
  `gasUseAvgDepthSql` blends the depth, so every whole-dive SQL rate follows.
- **Editor:** a minutes field under the cylinder's end pressure, with a line
  saying it is for time after the computer stopped logging.

Builder's calls for this section: the 5 bar threshold; a switch logged on the
surface stretches to the end of the recording, so any surface minutes before
the switch count on the cylinder breathed before it; entered seconds sit at
0 m with no position in time, so they never move a cylinder's windows; the
leading run uses pressure alone, since the starting gas switch is always
logged there.

## Where the window lives

- **Dart, with samples** (the detail page): `Dive.gasUse` computes it from
  `profile`.
- **Dart, without samples** (list reads, exports): the dive repository fills a
  new read-only `Dive.storedGasUse` from the derived metrics cache,
  the way `profileSpan` is filled today.
- **SQL** (statistics, insights, query fields): `gasUseSecondsSql` and
  `gasUseAvgDepthSql` read the same cache row.
- **Cache:** `dive_derived_metrics` gains `gas_use_s` and `gas_use_avg_depth_m`
  (nullable, device-local, schema rung). `DerivedMetricsRepository` computes
  them with the same pure function from the merged profile the dive page
  reads (every recording, not only the primary series the engine decodes), so
  a dive logged by two computers reports one number. Every mode is covered,
  gauge, rebreather and pressure-less dives included. The engine version is
  bumped so the sweep fills every existing row once.

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
