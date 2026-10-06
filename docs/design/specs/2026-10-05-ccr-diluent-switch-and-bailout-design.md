# CCR deco: mid-dive diluent switches and OC bailout (issue #577)

## Problem

Since #455 / PR #571 a logged CCR dive is analysed with the constant-ppO2 loop
model: `buildCcrProfileGasSegments` builds setpoint-bearing segments from the
resolved loop ppO2 over ONE diluent (`resolveCcrDiluentMix`). Recorded gas
switches on a CCR dive are never read, so:

1. **Diluent switches** are ignored. A diver who changes diluent mid-dive is
   computed on the first diluent for the whole dive and the He:N2 split is wrong
   for the rest.
2. **Open-circuit bailout** is ignored. After a switch to a bailout cylinder the
   tissues still load from the loop, and ppO2, CNS and OTU keep reading the O2
   cells, which measure a loop the diver is no longer breathing.

## Goals

- Gas switches on a CCR dive change the analysed breathing gas, classified by
  the target cylinder's `TankRole`.
- During a bailout stretch the tissues, ppO2, CNS/OTU, gas fraction overlays and
  MOD line all describe the open-circuit gas being breathed.
- The simulated ascent (TTS, deco stops) from a bailout sample uses the dive's
  carried open-circuit gases.
- A CCR dive with no recorded switches analyses exactly as it does today.

## Non-goals

- SCR (separate follow-up; its switches stay ignored).
- A stored per-sample loop/OC flag (no schema or importer changes).
- `diveProfileAnalysisProvider` (the synchronous Dive-object provider loads no
  switches for OC dives either).
- The dive planner.

## Design

### 1. Switch classification

New pure-Dart file `lib/features/dive_log/domain/services/ccr_gas_schedule.dart`.

`classifyCcrGasChanges(switches, tanks)` returns a time-ordered
`List<CcrGasChange>`; each change carries `timestamp`, `kind`
(`diluent` | `openCircuit`), `fN2` and `fHe`. It walks the switches (sorted by
timestamp, ties broken by id as `buildProfileGasSegments` does) with a two-state
machine, starting on the loop:

| Target tank role | While on the loop | While on open circuit |
| --- | --- | --- |
| `diluent` | diluent change | back on the loop with that diluent |
| `bailout`, `deco`, `stage`, `pony`, `sidemountLeft`, `sidemountRight` | open circuit on that gas | open-circuit gas switch |
| `oxygenSupply` | dropped (it feeds the loop) | open circuit on that O2 |
| `backGas` (untagged) | read as `oxygenSupply` when 99% O2 or more, else as `diluent` | same |

`backGas` is the role a file import (UDDF, Shearwater Cloud, Subsurface
without a `use` tag) gives a cylinder it knows nothing about. On a CCR dive it
is therefore loop gas, never a bailout, which matches the tank
`resolveCcrDiluentMix` already falls back to. Only a cylinder explicitly
marked bailout, deco, stage, pony or sidemount starts a bailout. (Revised
after the final review found that untagged imported diluents turned a return
to the loop into open circuit on the diluent.)

A switch whose `tankId` is not in `tanks` (the computer-scoped tank list) is
dropped. Fractions come from the switch's joined tank mix (`o2Fraction`,
`heFraction`); an air mix uses `airN2Fraction` as elsewhere.

### 2. Segment building

`buildCcrProfileGasSegments` gains an optional `gasChanges` parameter (default
empty, so existing callers and fixtures are unchanged) and an optional seed
timestamp. Walking the samples in order, applying each change at its timestamp:

- **On the loop:** today's behaviour. The setpoint follows the loop ppO2 curve,
  starting a new segment when it moves more than `setpointTolerance`, using the
  CURRENT diluent's fractions. A diluent change starts a new segment at the
  change timestamp carrying the curve value at that sample (or the fallback
  setpoint when there is no curve).
- **On open circuit:** a single segment with `setpoint: null` and the gas's
  fractions. Curve movement is ignored until the diver returns to the loop,
  which starts a setpoint segment seeded from the curve at that sample (or the
  fallback setpoint).
- Changes timestamped before the first sample are dropped; a change at the first
  sample replaces the seed, as in the open-circuit builder.
- Consecutive identical segments are not emitted.
- With no curve and no fallback setpoint the function still returns null, so the
  withheld-tissue path of #2593 is unchanged.

**Seed timestamp (follow-up).** The first segment is seeded at the first
profile timestamp instead of a hardcoded 0. A secondary computer's bucket on a
multi-source dive can start before zero, and a seed at 0 makes
`BuhlmannAlgorithm` reject the schedule and blank the analysis. This is the fix
`buildProfileGasSegments` already received for open circuit.

### 3. Provider wiring

In `profileAnalysisProvider`'s CCR arm, load `getGasSwitchesForDive` with the
same per-computer scoping as the open-circuit arm (switch to a tank this
computer breathed, and `appliesTo(computerId)`), classify against the scoped
tanks, and pass the changes to the builder. SCR passes none.

When the resulting schedule contains an open-circuit segment, the provider
passes ascent gases: `buildAvailableGases` (honouring the diver's ascent-gas
setting) minus the `diluent` cylinders, with the `oxygenSupply` cylinder kept
under either setting (a bailed-out diver can breathe it open circuit shallow,
and the tissues already load on it when a switch to it is logged); null if
that leaves nothing.

### 4. Engine ascent precedence

`BuhlmannAlgorithm.processProfileWithGasSegments` picks each sample's ascent
plan as: the loop plan when the sample's segment carries a setpoint, otherwise
the supplied `ascentGasPlan` (today: `ascentGasPlan ?? loopPlan`). Every current
caller is unaffected: open-circuit schedules carry no setpoints and CCR passes
no plan today.

### 5. Analysis service

In `ProfileAnalysisService.analyze`'s CCR branch, for every sample whose active
segment is open circuit:

- **ppO2:** ambient x the segment's FO2, on the same basis as the open-circuit
  path. CNS, OTU, max ppO2 and ppO2 warning events derive from this curve.
- **Breathed fractions** (`_calculateCcrLoopFractions`): the segment's own
  O2/N2/He, which drive the ppN2, ppHe, density and END overlays.
- **MOD line:** the open-circuit gas's O2 fraction.

Loop samples are unchanged.

### 6. Display overlay

`overlayComputerDecoData` replaces the analysed ppO2 curve with the resolved
loop curve for rebreather dives. For samples in an open-circuit segment it keeps
the analysed (breathed) value instead, so the chart line agrees with CNS and the
deco. The individual O2 cell curves are untouched.

## Testing

- `ccr_gas_schedule_test.dart`: every row of the role table in both states,
  unknown tank dropped, same-timestamp tie-break, return-to-loop seeding from
  the curve and from the fallback setpoint.
- Builder: no changes gives output identical to today; a diluent switch changes
  fN2/fHe from its timestamp; bailout yields a setpoint-null segment that ignores
  curve noise; negative first timestamp seeds there; no loop information still
  returns null.
- Engine: mixed loop/OC schedule with a plan uses the loop ascent on loop
  samples and the plan on OC samples; an OC-only schedule is unchanged.
- Service: ppO2, CNS/OTU, fractions and MOD follow the bailout gas inside the
  stretch and the loop outside it; a dive without switches is unchanged.
- Provider: integration through `profileAnalysisProvider` with switches,
  including per-computer scoping and the overlay keeping breathed ppO2.
- Existing CCR fixture suites (`ccr_loop_deco_fixture_test`,
  `tts_fixture_shape_test`, CNS cross-validation) stay green unchanged.

## Screenshots

Dive detail profile chart (ppO2 overlay plus ceiling/TTS) of a CCR dive with a
diluent switch and a bailout, before and after, desktop width, light mode.
