# Dive Planner Redesign — Design Spec

Date: 2026-07-05
Status: Approved design, pending implementation planning

## Goal

Replace the current dive planner with a technical dive planner that matches the
feature depth of MultiDeco and V-Planner, the usability of Divekit, and adds a
capability no competitor has: deep integration with the dive log. All deco
calculations use the same shared engine as the dive details page.

## Problem

The current planner (`lib/features/planning/` + `lib/features/dive_planner/`,
~5,100 lines) is clunky, incomplete, and inaccurate:

- No persistence: save and convert-to-dive are TODO stubs; plans cannot be
  reloaded.
- Altitude input exists but is cosmetic — the engine hardcodes surface pressure
  at 1.0 bar. Salinity is not modeled (fixed 10 m/bar).
- Repetitive-dive tissue seeding is a stub.
- CCR affects only ppO2/CNS display, not inert-gas loading. No bailout
  planning.
- Gas consumption ignores compressibility. No contingency planning of any
  kind (deviation plans, lost gas, turn pressure).
- UI is a static 3-tab form with no live feedback loop.

## Decisions made during brainstorming

| Question | Decision |
| --- | --- |
| Deco models | Buhlmann ZH-L16C + GF only for now; define a `DecoModel` interface so VPM-B can be added later without rework |
| CCR | Full support: constant-ppO2 loading, setpoints, OC bailout with worst-case bailout point |
| Recreational NDL mode | No — one tech-focused planner |
| Log integration | All four: tissue seeding, SAC auto-fill, plan-vs-actual, convert-to-dive |
| Contingencies | All four: one-tap deviation plans, lost-gas plans, turn pressure, reserve validation |
| Outputs | All four: runtime table + slate PDF, share as file, multi-plan compare, range tables |
| Form factor | Adaptive, phone-first |
| UI model | Live Profile Canvas (chart is the centerpiece, live recalc, no Calculate button) |
| Hub | Redesign the `/planning` hub and restyle the standalone calculators to match |
| Strategy | Engine-first with validation suite, clean UI rebuild alongside the old planner, parallel worktree tracks for post-engine phases |

## Architecture

Three layers, strict dependency direction (UI -> domain -> engine):

1. **Engine** (`lib/core/deco/`) — pure Dart, no Flutter imports, metric-only.
2. **Plan domain** (`lib/features/planner/domain/` + Drift tables) — the
   persisted `DivePlan` aggregate and the `PlanEngine` orchestrator.
3. **Planner UI** (`lib/features/planner/presentation/`) — the Live Profile
   Canvas. Built as a fresh feature module; the old `dive_planner` feature
   stays routed until cutover, then is deleted.

### Phases

Phases 1-3 are strictly sequential. Phases 4-7 are independent once the engine
API freezes at the end of Phase 1, and can run as parallel worktree tracks.
The app is releasable after every phase.

| Phase | Deliverable |
| --- | --- |
| 1 | Engine: `DecoModel` interface, altitude/salinity, CCR constant-ppO2 loading, gas compressibility, golden-vector validation suite |
| 2 | Plan domain: entities, persistence (schema v98+), sync, `PlanEngine` |
| 3 | Planner UI: Live Profile Canvas, OC planning end-to-end, cutover from old planner |
| 4 | CCR planning + bailout solver + scrub-to-bailout UI |
| 5 | Contingencies: deviation plans, lost-gas, turn pressure, reserve validation |
| 6 | Log integration: tissue seeding, SAC auto-fill, plan-vs-actual, convert-to-dive |
| 7 | Outputs (slate/PDF, share file, compare, range tables) + hub restyle |

## Engine design (Phase 1)

### DecoModel interface

```dart
abstract class DecoModel {
  TissueState initial(DiveEnvironment env);
  TissueState applySegment(TissueState s, Segment seg, InspiredGas gas);
  double ceiling(TissueState s);          // meters; GF-interpolated for Buhlmann
  Duration ndl(TissueState s, InspiredGas gas, DiveEnvironment env);
  DecoSchedule schedule(TissueState s, SchedulePolicy policy, AscentGasPlan gases);
}
```

- `TissueState` is model-opaque (Buhlmann: 16x2 tensions; VPM later: bubble
  parameters). Existing `BuhlmannAlgorithm` internals are reused — this is a
  re-facing plus fixes, not a rewrite.
- `BuhlmannGf` is the only implementation shipped now.

### DiveEnvironment

- `surfacePressure` derived from altitude via the existing
  `AltitudeCalculator`.
- `waterDensity`: fresh 1000 / EN13319 1020 / salt 1025 kg/m3.
- Both feed all depth<->pressure conversions, replacing the hardcoded 1.0 bar
  and 10 m/bar. Dive details (`ProfileAnalysisService`) inherits these fixes;
  existing displayed values will shift slightly — that is the accuracy fix
  working, not a regression.

### BreathingConfig

- `OpenCircuit(gasMix)`, `ClosedCircuit(setpoint, diluent)`, `Scr(supplyGas)`.
- CCR inspired inert pressure = (P_amb - setpoint - P_water_vapor),
  partitioned by the diluent N2:He ratio, clamped when setpoint >= P_amb
  (shallow: loop is effectively pure O2). This makes Buhlmann loading correct
  for CCR; currently it wrongly uses OC fractions.

### SchedulePolicy

Stop increment (3 m), minimum stop granularity (1 min), configurable last stop
(3/6 m), descent/ascent rates, gas-switch stop time, optional O2 air breaks
(e.g. 20 min O2 / 5 min back-gas, MultiDeco-style).

### Consumption

Z-factor gas compressibility (wire in the existing
`lib/core/utils/gas_compressibility.dart`) for tank capacity and consumption.

### Validation (the accuracy claim)

- Golden vectors in `test/core/deco/golden/`: canonical OC trimix, CCR,
  altitude, and repetitive-dive plans cross-checked against MultiDeco,
  Subsurface, and DecoTengu published outputs. Tolerance: +/-1 min per stop.
  Vectors are computed externally, never from model recall.
- Property tests: deeper/longer never shortens deco; raising GF-high never
  increases TTS.

## Plan domain and persistence (Phase 2)

### DivePlan aggregate (inputs only; results always recomputed)

- Identity: id, name, notes, optional dive site link, timestamps.
- Mode: OC or CCR (plan-level; bailout legs are OC inside a CCR plan).
- Environment: altitude, water type.
- Settings: GF low/high, descent/ascent rates, last stop depth, air-break
  policy, three SAC rates (bottom, deco, stressed).
- Segments: ordered user waypoints (depth, duration, tank) for the bottom
  portion only; ascent/deco is always computed.
- Tanks: volume, working/start pressure, gas, role
  (`bottom | deco | bailout | diluent | o2`).
- Contingency config: deviation deltas (+5 m / +5 min defaults), lost-gas
  toggles, turn-pressure rule (all-usable / halves / thirds / custom).
- Repetitive context: surface interval + linked source dive (tissue seeding)
  or explicit start state; plans can chain (plan B follows plan A).

### Persistence

- New Drift tables `dive_plans`, `dive_plan_segments`, `dive_plan_tanks` at
  schema v98+, all with HLC columns so plans ride the existing sync/changeset
  infrastructure.
- Denormalized summary columns (max depth, runtime, TTS) on `dive_plans` so
  the saved-plans list renders without running the engine.

### PlanEngine (replaces PlanCalculatorService)

`DivePlan -> PlanOutcome`: schedule, per-segment tissue timeline, per-tank
consumption with reserve status, CNS/OTU, and a severity-sorted `PlanIssue`
list: ppO2 violations, END over limit, gas density over 5.2/6.2 g/L
(warn/critical), CNS/OTU thresholds, reserve/turn-pressure violations,
NDL-exceeded-without-deco-gas, hypoxic gas at depth, bailout insufficient.

## Planner UI — Live Profile Canvas (Phase 3)

Phone-first; desktop spreads the same regions into three panels (editor left,
chart + runtime table center, issues/gas/contingencies right).

- **Edit only the bottom of the dive.** Segments are user waypoints; the
  ascent/deco tail is computed and drawn live. Change bottom time, watch the
  deco tail grow.
- **Chart is display + selection + scrubbing, not drag-editing.** Tap a
  segment (chart or card) to edit with steppers. Drag along the chart to scrub
  a cursor showing runtime, depth, ceiling, TTS at that instant. Reuses
  dive-details chart interaction patterns and existing zoom infrastructure.
  Direct waypoint dragging is deferred.
- **Overlays**: ceiling envelope (dashed), gas-switch markers, stop labels,
  contingency ghost profile (dashed, toggled by chip).
- **Live status chips** always visible: runtime, TTS, deco time, CNS, issue
  count. Tapping a chip opens the results sheet to that section.
- **Persistent swipe-up results sheet**: runtime table, per-tank gas plan,
  severity-sorted issues, tissue bars at the scrub point.
- Live recalculation, no Calculate button, debounced ~150 ms.
- Mockups: `.superpowers/brainstorm/5337-1783228181/content/planner-canvas.html`
  (session artifact; composition approved 2026-07-05).

## CCR and bailout (Phase 4)

- Plan-level OC/CCR toggle. Low/high setpoint with configurable switch depth
  (defaults 0.7 bar shallow, 1.3 bar below 10 m); per-segment setpoint
  override for deco.
- Tank roles diluent + O2; consumption = metabolic O2 rate (default 1.0
  L/min, configurable) plus diluent for descent volume and flushes. END and
  density warnings evaluate the diluent.
- **Bailout solver**: for every minute of the CCR plan, compute the full OC
  bailout outcome (bailout gases, stressed SAC, OC deco). Mark the worst-case
  point (max gas required) on the chart; validate bailout tanks against it.
- **Scrub-to-bailout**: scrub anywhere, tap "Bailout from here" — chart ghosts
  the bailout profile from that instant with its own runtime table.
- Bailout scan computes lazily after the main outcome renders (performance).

## Contingencies (Phase 5)

- **Deviation plans**: +5 m / +5 min / both (configurable deltas) as full
  outcomes — ghost overlay, tables in results sheet, on the slate export.
- **Lost-gas plans**: recompute schedule without each deco gas. CCR loop loss
  is the bailout plan.
- **Turn pressure**: per-plan rule -> turn pressure on each bottom tank chip.
- **Reserve validation**: rock-bottom at worst point (stressed SAC,
  configurable buddy factor), per-tank issues.

## Log integration (Phase 6)

- **Tissue seeding**: "Following" row — pick a logged dive (default most
  recent) + surface interval; engine starts from that dive's end tissue state
  (from `ProfileAnalysis`) with surface off-gassing applied.
- **SAC auto-fill**: bottom SAC defaults to rolling average from logged dives,
  tagged "from your log", per-plan override. Deco/stressed default to 0.8x /
  2.5x until edited.
- **Plan-vs-actual**: plans link to dives; dive-detail chart gains a "show
  plan" toggle overlaying planned profile and stops on the actual.
- **Convert-to-dive**: creates a dive skeleton (date, site, tanks, gases,
  planned runtime) linked to the plan; computer download fills the profile.

## Outputs (Phase 7)

- **Dive slate**: high-contrast printable page — main runtime table, deviation
  tables, lost-gas tables, gas plan. PDF via `pdf`/`printing` packages (new
  dependencies).
- **Share as file**: versioned JSON (`.subplan`) via share sheet; importable
  by any Submersion install. QR/web viewer explicitly out of scope.
- **Multi-plan compare**: 2-3 saved plans -> overlaid profiles + diff table
  (runtime, TTS, deco time, per-tank gas, CNS).
- **Range tables**: matrix around the base plan (depth +/-3/6 m x time +/-5/10
  min, configurable) showing runtime/TTS; included in slate PDF.

## Hub redesign (Phase 7)

`/planning` reorganized around the planner: saved plans list + "New plan"
front and center; calculators (deco calculator, MOD/END/best mix, consumption,
rock bottom, weight, surface interval) as a tools grid, restyled to the new
visual language (chips, live-recalc cards, no Calculate buttons). The deco
calculator picks up altitude/salinity via the shared engine.

## Error handling

- The engine never throws on an undiveable plan: best-effort schedule +
  critical `PlanIssue`s. The canvas renders a "not diveable as planned" state
  with the issues list — never a crash or blank chart.
- Input guards: max depth 200 m, max runtime 24 h.
- Recalc debounced ~150 ms; moves to an isolate if profiling shows jank.

## Testing

- Golden-vector suite (Phase 1 foundation) — runs on every engine change.
- Property tests for model invariants.
- Unit tests: PlanEngine consumption / turn pressure / issue generation;
  contingency and bailout solvers.
- Persistence round-trip + FK-ON sync tests for new tables.
- Widget tests: canvas panels, results sheet, issue rendering.
- Release gate: manual checklist comparing a standard plan set against
  MultiDeco before each planner release.

## Explicitly out of scope

- VPM-B implementation (interface designed for it; no implementation now).
- Recreational/NDL-first mode.
- Direct drag-editing of waypoints on the chart.
- QR-code / web-viewer plan sharing.
- Cave "same-way-back" planning (turn-pressure covers penetration basics).
- Gas blending calculator (exists separately; not part of this redesign).

## Competitive context (research summary)

Table stakes across MultiDeco/V-Planner/Divekit/Dive Tools/Subsurface:
ZH-L16 + GF, multi-level multi-gas OC, CCR with setpoints + bailout, CNS/OTU,
runtime tables, altitude/salinity, configurable rates/last stop, offline,
print/share. Differentiators this design captures: log-integrated planning
(unique to Submersion), scrub-to-bailout (beyond Divekit's worst-case point),
one-tap contingency ghosts, live tissue/GF visualization, multi-plan compare,
range tables, published validation vectors (trust, per Divekit's playbook).
