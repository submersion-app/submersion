# Weight Prediction (Weight Planner) — Design

Date: 2026-07-11
Status: Approved design, pre-implementation
Related: Planning hub (`lib/features/planning/`), Dive Planner (`lib/features/planner/`), existing rule-of-thumb calculator (`lib/core/utils/weight_calculator.dart`)

## Problem

The Planning section's Weight Calculator is a static rule-of-thumb lookup (base
weight by suit type, flat tank/water adjustments). It ignores the diver's own
dive history, their actual gear, and their body — even though the database
already records typed weight entries per dive (`dive_weights`), gear used per
dive (`dive_equipment`), tank details (`dive_tanks`), and water type.

Divers want to compose the rig they plan to dive, get an accurate prediction of
how much lead to carry and where to put it, and see how the requirement changes
as they swap gear.

## Goals

- Predict total required weight for a planned rig as accurately as the diver's
  data allows, personalized from their logged dives.
- Predict weight placement (integrated / belt / trim / ankle / backplate)
  from the diver's habitual distribution.
- Live what-if: swapping a gear item, tank, or water type updates the
  prediction immediately and shows the delta.
- Two consumer surfaces from day one: an upgraded standalone Weight Planner
  tool, and a Gear & Weights section in the Dive Planner.
- Capture the new data that raises the accuracy ceiling: per-dive weighting
  feedback, optional per-item gear buoyancy metadata, dated diver body
  weight/height.
- Degrade gracefully: with zero history the tool behaves like an improved
  rule-of-thumb calculator and never feels broken.

## Non-goals (v1)

- Exposure suit as an explicit per-dive column (stays inferred from linked
  equipment; declined during scoping).
- Suit compression / depth-dependent buoyancy modeling (weighting convention
  is neutral-at-safety-stop; compression at depth is out of scope).
- Prompting the user to backfill feedback on historical dives.
- Cross-diver or community-sourced gear buoyancy data.

## Prediction engine (Approach C: hybrid physics + learned calibration)

Location: `lib/core/buoyancy/` — pure Dart, no Flutter imports, mirroring the
`lib/core/deco/` engine pattern. Exposed to features via Riverpod providers.

### Model

All terms in kg-equivalent buoyancy; positive means lead is needed to offset it.

```
predictedWeight = personalTerm          (learned; body + swim-gear baseline)
                + sum(gearTerm(item))   (learned with priors, per equipment item)
                + sum(tankTerm(tank))   (physics)
                + waterTerm             (physics)
```

### Physics terms (computed, never learned)

- `tankTerm`: buoyancy of each tank near-empty (neutral at safety stop with
  reserve pressure — the standard weighting convention), derived from
  material + volume + working pressure via a built-in constants catalog in
  the engine, keyed consistently with the existing tank-presets feature.
  Replaces the old flat +/-2 kg by material.
- `waterTerm`: water-density shift scaled by total displaced mass
  (body weight + rig dry weight), not a constant. Reference density is salt
  water (EN13319); fresh and brackish subtract proportionally to total mass.

### Learned terms (ridge regression over the active diver's history)

Each logged dive with recorded weights becomes one observation:

```
correctedCarriedWeight - physicsTerms(dive) =
    personalTerm + sum(gearTerm(items linked to that dive))
```

- `correctedCarriedWeight`: carried weight (sum of `dive_weights` rows;
  fallback `dives.weightAmount`) adjusted by feedback — overweighted
  subtracts the stated magnitude, underweighted adds it; default magnitude
  1.0 kg when the user gave direction but no amount.
- Observation weights: dives rated "correct" count double; unrated dives
  count normal; recency decay halves an observation's weight roughly every
  two years so old body composition and habits fade.
  Outliers beyond 3 sigma of the diver's own corrected-weight distribution
  are down-weighted, not dropped.
- Ridge priors: a user-entered `equipment.buoyancyKg` is a strong prior for
  that item's term; otherwise a type-based default table (the existing
  rule-of-thumb values, generalized) is a weak prior. The personal-term
  prior derives from body weight (percent-of-body-weight heuristic), falling
  back to the suit-type heuristic when no body weight entry exists.
- Solver: normal equations + Gaussian elimination. Feature count is the
  number of distinct equipment items in history (tens), so this is
  deterministic and fast; no new dependencies.
- Correlated gear (always the same BCD + suit) is safe: individual terms
  shrink toward priors but their sum — the only thing predictions use — is
  well-determined.
- Dives without gear links (e.g., imports) still contribute to the personal
  and water terms; they simply carry no per-item features.

### Placement prediction

Split the predicted total using the diver's average placement fractions from
the most recent 10 dives that (a) used the same exposure-suit-type equipment
item as the planned rig (any dive qualifies when the rig has no exposure
suit) and (b) have `dive_weights` rows. Round to 0.5 kg (or 1 lb)
increments with largest-remainder allocation so parts sum exactly to the
total. No qualifying history: show a single unplaced "Weight" line.

### Confidence

High / Medium / Low derived from: number of supporting corrected dives, share
of the prediction coming from learned terms vs. priors, and residual spread.
Rendered as "based on N dives". Capped at Medium when no body-weight entry
exists. Predictions clamp to >= 0 kg.

## Data model (migration v104)

| Change | Details |
| --- | --- |
| `dives` + 2 columns | `weightingFeedback` TEXT nullable (`correct` / `overweighted` / `underweighted`); `weightingFeedbackKg` REAL nullable (magnitude; direction implied by the enum) |
| `equipment` + 2 columns | `buoyancyKg` REAL nullable (net in-water buoyancy: positive floats, negative sinks); `weightKg` REAL nullable (dry weight; feeds displacement scaling) |
| new `diver_weight_entries` | `id` TEXT PK, `diverId` -> divers, `measuredAt` INT, `weightKg` REAL, `heightCm` REAL nullable, `createdAt`/`updatedAt` INT, `hlc` TEXT nullable. Dated history; engine uses the entry nearest each dive date; UI shows latest |
| new `dive_plan_equipment` | `planId` -> dive_plans (cascade), `equipmentId` -> equipment (cascade); composite PK; mirrors `dive_equipment` |
| `dive_plans` + 2 columns | `plannedWeightKg` REAL nullable (accepted total); `plannedWeightPlacement` TEXT nullable (JSON snapshot keyed by dive_weights weight types) |

Conventions that must be followed (established repo traps):

- New user-edited rows carry HLC columns and participate in sync changesets;
  `diver_weight_entries` and `dive_plan_equipment` need deletion-log
  (tombstone) wiring so cross-device deletes do not resurrect.
- Indexes for the new child tables must be created in `onCreate` and in the
  `beforeOpen` re-assert path, not only in `onUpgrade` (fresh/restored DBs
  otherwise lack them).
- Exporters/backup/restore must include the new tables and columns.
- `plannedWeightPlacement` is a JSON snapshot on the plan row by design:
  plan weights are a snapshot of a prediction, not independently editable
  rows, so a child table would add sync surface for no benefit.

Existing data reused as-is: `dive_weights` (training targets + placement
labels), `dive_equipment` (feature vectors), `dive_tanks`
(material/volume/working pressure), `dives.waterType`, legacy
`dives.weightAmount` as fallback target when a dive has no `dive_weights`
rows.

## UI surfaces

### Weight Planner tool (route `/planning/weight-calculator`, page rewritten)

- Rig composer: equipment-set picker (one tap loads a set), item chip list
  with add/remove — buoyancy-relevant gear types (exposure suits, BCDs,
  backplates) offered first, remaining types under "more". Tank row reusing
  the existing tank-preset picker. Water type segmented control. Body weight
  prefilled from the latest `diver_weight_entries` row, editable inline;
  inline edits write a new dated entry only on explicit "save to profile".
- Result card: large total (via `UnitFormatter`, respecting active diver
  units), placement rows, confidence line, transient delta chip (~4 s) after
  any swap ("-2.5 kg vs. previous rig"), and an expandable breakdown listing
  each term tagged as measured-from-your-dives / from-gear-specs /
  default-estimate.
- Zero history: identical UI, Low confidence, all-default terms.

### Dive Planner

- New "Gear & Weights" `FormSection` in the plan editor using the same
  shared rig-composer widgets. Water type and tanks come from the plan
  itself (no duplicate inputs). Prediction chip inline; an accept action
  persists `plannedWeightKg` + `plannedWeightPlacement`.

### Dive edit form

- In the existing weights card: three-chip segmented row "How was your
  weighting?" (`Felt right` / `Overweighted` / `Underweighted`) plus an
  amount field revealed only for Over/Under.

### Gear edit form

- Optional buoyancy and dry-weight fields in an "Advanced" group with
  type-appropriate hint text.

All new user-facing strings are localized into all supported locales per repo
policy.

## Edge cases

- No diver weight entry: personal prior falls back to suit-type heuristic;
  confidence capped at Medium.
- Retired/deleted gear: history keeps informing the fit; the composer offers
  only active gear.
- Multi-tank rigs (doubles, sidemount, stages): tank terms sum; no special
  cases.
- Multi-diver: engine parameterized by `diverId`; switching the active diver
  switches the model.
- Units: storage in kg throughout (existing convention); display via
  `UnitFormatter`.

## Testing

- Engine unit tests (pure Dart): physics terms against hand-computed vectors
  (vectors computed with python3, not recalled); regression recovery of
  known synthetic gear effects within tolerance; prior dominance at n = 0-2
  dives; feedback-correction math; placement rounding sums exactly to total.
- Golden scenarios: 50 consistent salt dives then predict fresh; a gear swap
  never seen in history; a chronically overweighted diver with feedback —
  each asserting direction and magnitude bounds.
- Widget tests: tool compose/swap/delta flow; planner section persistence;
  feedback chips writing through to the dive. Follow FormSection test
  gotchas (uppercased labels, ensureVisible before tap).
- Migration test: v103 -> v104 per the existing migration-test pattern.

## Rollout

Single feature branch/worktree; schema bump to v104 coordinated with the
schema version ladder (v103 current). The old `WeightCalculator` utility is
retired once the new engine covers its route.
