# Buoyancy Digital Twin — Design

Date: 2026-07-17
Status: Approved design, pre-implementation
Related: Weight prediction engine (`lib/core/buoyancy/`, PR #564), deco engine
(`lib/core/deco/`), Weight Planner (`lib/features/weight_planner/`), Dive
Planner (`lib/features/planner/`)

## Problem

Divers currently answer "why was this exact configuration difficult to hold at
the final stop?" with notes and intuition. The data to answer it precisely is
already logged: profile samples, per-tank pressures, gear links, carried lead,
water type. The weight-prediction engine (PR #564) predicts static pre-dive
lead anchored at the neutral-at-safety-stop convention, and its spec explicitly
deferred depth- and time-dependent modeling.

The Buoyancy Digital Twin is that deferred second act: model net buoyancy of
the diver and rig through the dive — cylinder buoyancy swing as gas is
consumed, exposure-suit compression and rebound, wing/drysuit gas demand — and
present begin-versus-end buoyancy, a final-stop diagnosis, predicted minimum
ditchable weight, and a comparison against logged weighting history.

## Goals

- Compute a net-buoyancy-versus-time series for a logged dive from its real
  profile, real tank pressures, and the diver's calibrated gear terms.
- Answer the motivating question with an opinionated plain-language diagnosis
  at the final stop, backed by a term-by-term breakdown and a chart.
- Derive from the same series: begin/end net buoyancy, peak wing-lift demand
  (compared to rated lift when known), minimum ditchable weight (compared to
  what was actually droppable), and a drysuit gas estimate on drysuit dives.
- Compare model-implied ideal lead against carried lead across recent dives
  with the same exposure suit, tying into existing weighting feedback.
- What-if re-simulation on a logged dive: adjust lead, tank, suit, or water
  type and watch the curve and verdict recompute; strictly ephemeral.
- Serve both surfaces from one engine: retrospective analysis on the dive
  detail page, and forward simulation in the Dive Planner and Weight Planner.
- Degrade gracefully at every missing input; never show a broken section.

## Non-goals (v1)

- Persisting computed twin results (computed on demand, like deco analysis).
- Modeling stages or weights dropped or handed off mid-dive.
- Undergarment-specific drysuit modeling (implicit in the learned suit term).
- Compression modeling for neoprene accessories (hood/gloves/boots stay
  static; their terms are small).
- Apnea dives (section hidden; no tank swing to model).
- Community-sourced suit or wing data.

## Engine (calibrated twin)

Location: `lib/core/buoyancy/` — pure Dart, no Flutter imports, composing the
existing modules. Sign convention unchanged: positive = buoyant = needs lead.

For each profile sample t:

```
net(t) = suit(depth(t)) + sum(tank_i(t)) + staticGear + personal + water - lead
```

### Cylinder term (physics)

`tank_i(t) = emptyBuoyancyKg_i - gasMassKg_i(P_i(t))`, with
`gasMassKg = volumeL * pressureBar * mixDensityKgPerLBar`.

- Pressure source: measured `tank_pressure_profiles` series for that tank when
  present; otherwise linear interpolation between `startPressure` and
  `endPressure` across the dive, labeled as estimated in the UI.
- Mix density is computed from the tank's O2/He fractions using per-component
  densities (O2, N2, He) derived from molar masses at the same reference
  temperature as the existing `airDensityKgPerLBar` constant, so air mixes
  agree exactly with the static engine. Trimix fills weigh visibly less than
  air; technical divers will check this.
- Empty buoyancy and volume resolve exactly as `BuoyancyPhysics.tankTermKg`
  does today: catalog by preset, spec match, per-material fallback.

### Exposure-suit term (physics anchored to calibration)

Wetsuit buoyancy is an incompressible residual plus a gas fraction following
Boyle's law:

```
suit(d) = B_res + B_gas / P_rel(d)      where B_surface = B_res + B_gas,
B_res = kNeopreneResidualFraction * B_surface
```

`P_rel` comes from `DiveEnvironment.pressureAtDepth`, so salinity, altitude,
and surface pressure are respected. `kNeopreneResidualFraction` is a new
engine constant (initial default 0.3, validated against published neoprene
data during implementation).

Anchoring: the diver's fitted suit term from `FittedWeightModel` represents
the suit near the safety stop (~5 m). The twin inverts the compression curve
through that anchor to recover `B_surface`, so the sweep is personalized
without new user input. The inversion clamps to type-plausible bounds
(`B_surface` in `[anchor, 3 * anchor]`, non-negative); a non-positive fitted
term falls back to the type-default prior. Dives with no linked suit omit the
term and the UI hints to link gear.

Drysuits hold constant loft (the diver adds gas to maintain it): the suit term
stays constant and the twin instead reports a gas budget — surface-equivalent
liters added across descents, `V_loft * sum(positive pressure deltas)`, with
`V_loft` estimated from the suit's buoyancy term divided by water density.

### Static terms (reused verbatim)

Non-suit gear terms, the personal term, and the water term come from
`FittedWeightModel` (learned where history exists, priors otherwise) and are
constant through the dive. Lead = sum of `dive_weights` rows, falling back to
`dives.weightAmount`. Body mass uses the `diver_weight_entries` entry nearest
the dive date.

Unit reconciliation: `BuoyancyPhysics` densities are kg/L, `DiveEnvironment`
uses kg/m3. The twin converts at a single documented point; neither engine is
refactored.

### Derived outputs

All from the one series (`BuoyancyTwinResult`):

- Per-sample net buoyancy plus per-sample term breakdown.
- Begin-of-dive and end-of-dive net buoyancy.
- Final-stop verdict: net and breakdown at the anchor point. Anchor = last
  sustained shallow segment before surfacing (depth <= 9 m, low variance,
  >= 60 s; constants tunable); fallback to the shallowest 60 s window of the
  final ascent; for dives without a usable profile, the static safety-stop
  convention (5 m, reserve pressure).
- Peak wing-lift demand: `max over t of max(0, -net(t))`, flagged against the
  wing's rated `liftCapacityKg` when set.
- Minimum ditchable weight: at the worst point of the dive with the wing
  assumed dead, the lead that must be droppable to restore a swimmable margin:
  `max(0, kDitchableMarginKg - worstNet)` with `kDitchableMarginKg` default
  2.0. Compared against actually-droppable carried lead via a placement map:
  integrated/belt/pockets droppable; backplate/trim/ankle fixed.
- Ideal lead: `carried + net(anchor)`. Positive net at the anchor means the
  diver needed that much more lead; negative means less.
- Drysuit gas estimate (drysuit dives only).

### Model boundaries

Each piece is independently testable pure Dart: gas density, suit compression
curve (and its inversion), the per-sample simulator, anchor detection, and the
derived-output calculators are separate units consumed by one
`BuoyancyTwin.simulate(...)` entry point. The planner passes a synthetic
profile through the same entry point; there is no planner-specific engine
path.

## Data model

No per-dive storage: twin results are computed on demand and cached in
providers, exactly like deco/tissue analysis. No sync surface for results.

One new capture: wing/BCD lift capacity.

- Contract: nullable `liftCapacityKg` on `EquipmentItem`, offered for
  `bcd`-type items in the gear edit form's Advanced group, displayed via
  `UnitFormatter` (lbs when imperial).
- Storage mechanism is decided at plan time based on PR #608 (equipment
  attributes KV): a plain `equipment` column if #608 has not merged (claiming
  the next free schema version per the ladder — verify the ladder topic file
  first; several open PRs hold claims), or an attribute-catalog entry if it
  has. The engine only ever reads the domain getter, so it is insulated from
  the outcome. This is the feature's only possible migration; if the column
  path is taken it follows the established migration-test pattern and
  exporter/backup updates.

New engine constants (code, not schema): per-component gas densities,
`kNeopreneResidualFraction`, drysuit loft derivation, `kDitchableMarginKg`,
the placement ditchability map, and anchor-detection thresholds.

Everything else is reuse: `dive_profiles` (primary computer only),
`tank_pressure_profiles`, `dive_tanks`, `dive_weights`, `dive_equipment`,
`dives.waterType` + altitude via `DiveEnvironment`, `diver_weight_entries`,
`weightingFeedback`/`weightingFeedbackKg`.

## UI surfaces

### Dive detail — Buoyancy section

Follows the computed-analysis card pattern (deco/tissue): a
`FutureProvider.family<BuoyancyTwinResult?, String>` watching
`analysisDiveProvider` and the weight-calibration provider, self-invalidating
on relevant DB changes, heavy math in a `compute` isolate. Content, top to
bottom:

- Diagnosis line: "At your final stop (~5 m, 52 bar) you were ~1.8 kg
  buoyant", with the term breakdown beneath, each term tagged
  measured / from-your-dives / default, matching the Weight Planner's
  breakdown rows.
- Net-buoyancy-versus-time chart, time-aligned with the depth profile;
  tapping a point shows that moment's breakdown.
- Summary rows: begin vs end net buoyancy; peak wing-lift demand (vs rated
  lift when known); minimum ditchable vs actually droppable; drysuit gas
  estimate on drysuit dives.
- History strip: ideal vs carried lead over the most recent 10 computable
  dives sharing the same exposure-suit item, annotated with weighting
  feedback where present.
- What-if: an adjust affordance opens a sheet to tweak lead total, tank,
  suit, or water type; curve and verdict recompute live; ephemeral with
  reset; nothing persists.

### Dive Planner

The Gear & Weights section gains the twin outputs computed from the planned
profile segments and planned tanks through the same engine entry point.

### Weight Planner tool

Gains a "through the dive" panel with two inputs (max depth, bottom time)
that synthesize a square profile for the simulation; outputs mirror the
planner's.

Graceful degradation: no profile — summary only, no chart, static anchor; no
tank pressures — swing omitted with an "add tank pressures" hint; estimated
inputs labeled as such. All new strings localized into all ten non-English
locales; all values through `UnitFormatter`.

## Edge cases

- Profile source: primary computer samples only (`isPrimary`), avoiding the
  unfiltered-profile double-count trap (#536).
- CCR/gauge dives: measured pressure series are used as-is; no OC assumptions
  are injected when pressure data is absent (swing omitted rather than
  fabricated from SAC).
- Apnea dives: section hidden.
- Multi-tank rigs: per-tank series or per-tank interpolation, summed; no
  special cases for doubles/sidemount/stages beyond the non-goal above.
- Missing volume or material: engine defaults, labeled as estimates.
- Suit accessories (hood/gloves/boots): static terms only.
- Degenerate calibration (non-positive suit term): type-default fallback.
- Multi-diver: parameterized by the active diver's calibration, as the weight
  planner already is.
- Water type null: `DiveEnvironment` EN13319 default, matching deco behavior.

## Testing

- Engine unit tests (pure Dart) with hand-computed vectors, computed with
  python3 at authoring time, never recalled: gas-mass linearity and
  trimix-versus-air density; compression curve endpoints (surface value,
  residual-only at depth) and anchor inversion round-trip; agreement with the
  static engine when the twin is evaluated at the safety-stop convention;
  minimum-ditchable and peak-lift scenarios; measured-versus-interpolated
  pressure parity on synthetic series; anchor detection on shaped profiles
  (square, multi-level, no-stop, profile-less).
- Provider tests against in-memory Drift following the profile-analysis
  provider test pattern (invalidation on dive/weights/gear changes).
- Widget tests: detail section render states (full, degraded, hidden),
  what-if sheet recompute and reset, planner and tool panels. Respect the
  FormSection test gotchas (uppercased labels, ensureVisible before tap).
- Migration + exporter tests only if the lift-capacity column path is taken.

## Rollout

All work in the dedicated worktree
(`.claude/worktrees/buoyancy-digital-twin`, branch
`worktree-buoyancy-digital-twin`), spec included; single PR. Schema ladder
coordination only if the column path is taken. No feature flag: the section
simply appears where inputs exist.
