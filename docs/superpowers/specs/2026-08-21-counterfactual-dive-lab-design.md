# Counterfactual Dive Lab: Design Spec

Date: 2026-08-21
Status: Approved design, pending implementation planning
Branch / worktree: `worktree-counterfactual-dive-lab` at
`.claude/worktrees/counterfactual-dive-lab`

## Goal

Start from an actual logged dive, pick any moment, and branch reality:
"What if I had switched to 50% here?", "What if the deco bottle was lost?",
"What if we had begun the ascent five minutes earlier?", "What would 40/85
have done?", "Could my remaining back gas support an out-of-gas buddy?"

The alternate timeline replays decompression, tissues, CNS/OTU, gas
reserves, buoyancy and TTS alongside what actually happened, shows a clear
delta, and can be saved or shared with an instructor.

Most of the hard infrastructure already exists; this feature composes it.
The smallest magical version is one timestamp, one changed decision and a
delta panel. The approved v1 program goes further (see Scope), but every
phase is releasable on its own.

## Decisions made during brainstorming

| Question | Decision |
| --- | --- |
| How is the alternate timeline produced? | Both modes, selectable per scenario: **Replay** (same recorded depth path, changed inputs) and **Re-plan** (engine computes the ascent and deco from the branch point) |
| Which interventions in v1? | All five pitch interventions (switch gas at T, lost deco/stage gas, begin ascent earlier/later/now, different gradient factors, out-of-gas buddy) plus three extras: bail out to OC here (CCR/SCR dives), ascent rate / stop length tweaks, buoyancy delta in the panel |
| Where does it live? | A dedicated full-screen Dive Lab page plus a teaser section card on dive detail |
| Persistence and sharing? | Save scenarios to a new synced table; share as PDF slate; share as a versioned `.sublab` scenario file that embeds a dive snapshot so an instructor without the dive can open it |
| Engine approach | Hybrid, one output shape: a new `ScenarioEngine` composes `ProfileAnalysisService` (replay, and the final like-for-like analysis of both timelines) with `PlanEngine` (re-plan). Rejected: plan-backed only (deltas at T not exactly zero, replay numbers drift from the dive detail page) and a new sample-level engine (duplicates PlanEngine's gas, issue, CCR and bailout logic) |

## Vocabulary

- **Branch point (T)**: the sample index on the actual primary profile at
  which the timelines diverge. Everything before T is identical in both
  timelines by construction.
- **Actual timeline**: the logged dive exactly as analysed today by
  `profileAnalysisProvider`.
- **Counterfactual timeline**: the alternate dive, produced by the replay
  or re-plan pipeline.
- **Intervention**: one changed decision applied from T onward.
- **Scenario**: a dive id, a branch point, a mode and a list of
  interventions. Inputs only; results are always recomputed.

## Existing infrastructure this design composes

Verified in the codebase on 2026-08-20:

| Capability | Where | Used for |
| --- | --- | --- |
| Per-sample tissue state of a logged dive | `ProfileAnalysis.decoStatuses[i].compartments` (`lib/features/dive_log/data/services/profile_analysis_service.dart`), `cnsCurve[i]`, `otuCurve[i]` | branch state at T |
| Exact mid-dive restore | `BuhlmannAlgorithm.restoreState(compartments, gfLowCeilingAnchor:)` (`lib/core/deco/buhlmann_algorithm.dart`); `BuhlmannState` in `lib/core/deco/deco_model.dart` | seeding the re-plan engine |
| Whole-profile replay from a seed with an arbitrary gas schedule | `ProfileAnalysisService.analyze(startCompartments:, gasSegments:, ascentGasPlan:, ...)`; `ProfileGasSegment` | replay pipeline and the final analysis of both timelines |
| Planner engine accepting a seed | `PlanEngine.compute(plan, startState:)` (`lib/features/planner/domain/services/plan_engine.dart`) returning `PlanOutcome` (stops, tank usages with turn/min gas, CNS/OTU, issues, tissue timeline) | re-plan pipeline |
| Lost-gas and deviation variants | `ContingencyService.lostGasFor`, `deviatePlan` | `loseTank` semantics |
| CCR bailout math | `BailoutSolver` | `bailOut` semantics |
| Best gas by depth | `OptimalOcAscentGas` / `AvailableGas` (`lib/core/deco/ascent/ascent_gas_plan.dart`) | replay substitutions after a lost tank or bailout |
| Tissue seed from a logged dive | `seededTissueState` (`lib/features/planner/domain/services/tissue_seed.dart`), `FollowDiveSheet` | end-to-end precedent for dive -> plan handoff |
| Selected sample cursor | `profileTrackingIndexProvider(diveId)` (`lib/features/dive_log/presentation/providers/profile_tracking_provider.dart`) | pre-seeding T from the detail chart |
| Ghost profile on the real chart | `ChartSourceOverlay` (`dive_profile_chart.dart`), `buildPlannedOverlay` (`lib/features/planner/presentation/providers/plan_overlay_provider.dart`) | counterfactual overlay |
| Profile from plan segments | `synthesizePlanProfile` (`lib/features/weight_planner/presentation/providers/plan_buoyancy_twin_provider.dart`) | synthesising counterfactual samples (generalised) |
| Buoyancy over a profile | `runBuoyancyTwin`, `TwinAnalyzer` (`lib/core/buoyancy/`), `buoyancyTwinProvider` | buoyancy rows |
| Real-gas consumption | `pressureAfterConsuming` (`lib/core/utils/gas_compressibility.dart`), `gasModelProvider` | consumption pass |
| Tank pressure series | `tankPressuresProvider`, `estimatedTankPressuresProvider` (`dive_providers.dart`) | pressure at T |
| Section registry | `DiveDetailSectionId` (`lib/core/constants/dive_detail_sections.dart`) | teaser card |
| Full-screen push pattern | `FullscreenProfilePage` pushed on the root navigator (issue #811) | lab page navigation |
| PDF slate | `PlanSlatePdfService` (`lib/features/planner/data/services/plan_slate_pdf_service.dart`), `sharePdfBytes` / `savePdfToFile` | PDF output |
| Versioned file codec | `plan_file_codec.dart` (`.subplan`) | `.sublab` codec |
| Synced aggregate with repository | `DivePlanRepository`, `dive_plans` tables, 18 sync registration sites with structural tests | `dive_scenarios` |

One gap: `DecoStatus` (`lib/core/deco/entities/deco_status.dart`) does not
carry the GF-low ceiling anchor, so a mid-dive restore from the logged-dive
path cannot be exact today. This design adds it (see Engine).

## Architecture

Three layers, strict dependency direction (UI -> domain -> engine), in a
new feature module `lib/features/dive_lab/`:

1. **Engine / domain** (`lib/features/dive_lab/domain/`): pure Dart, no
   Flutter imports. `DiveScenario`, `ScenarioIntervention` (sealed) and its
   codec, `BranchState`, `ScenarioEngine`, `ScenarioOutcome`, delta and
   verdict builders, the consumption pass, the re-plan compiler.
2. **Data** (`lib/features/dive_lab/data/`): `DiveScenarioRepository`
   (Drift + sync log), `DiveLabSlatePdfService`, `scenario_file_codec.dart`
   (`.sublab`), scenario file importer.
3. **Presentation** (`lib/features/dive_lab/presentation/`): `DiveLabPage`
   (phone and wide layouts), providers (branch, scenario draft, outcome,
   saved list), widgets (chart host, branch controls, intervention chips and
   sheet, delta panel, tissue strips, gas rows, runtime table, buoyancy rows,
   teaser card, saved-scenarios sheet).

Small, contained changes outside the module:

- `lib/core/deco/entities/deco_status.dart`: nullable
  `gfLowCeilingAnchorBar`, filled by `BuhlmannAlgorithm.processProfile` and
  `processProfileWithGasSegments`.
- `lib/core/constants/dive_detail_sections.dart`: `DiveDetailSectionId.diveLab`.
- `dive_detail_page.dart`: toolbar icon + overflow item in both chrome
  variants; section builder for the teaser card.
- Database: `dive_scenarios` table, migration, sync registration.
- Universal import: `.sublab` extension routed to the scenario importer.
- l10n: new keys in every locale ARB.

## Scope and the scenario model

### Eligibility

Any dive with a primary profile (`isPrimary`, the #536 filter) of at least
two samples, in OC, CCR or SCR dive mode. Gauge and apnea dives are
ineligible (no deco analysis exists for them); the entry points are hidden
and a direct open renders a friendly empty state.

### `DiveScenario`

```dart
class DiveScenario {
  final String id;
  final String diveId;
  final String name;
  final String? notes;
  final int branchSeconds;            // runtime seconds on the primary profile
  final ScenarioMode mode;            // replay | replan
  final List<ScenarioIntervention> interventions;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

Inputs only. Results are never persisted; the engine recomputes on open
(same rule as `DivePlan` / `PlanOutcome`).

### Interventions

`sealed class ScenarioIntervention` with a versioned JSON codec
(`formatVersion` inside the JSON). Adding a kind later is a codec change,
not a schema change.

| Kind | Parameters | Replay semantics | Re-plan semantics |
| --- | --- | --- | --- |
| `switchGas` | `TankRef`: existing tank id, or hypothetical `{gasMix, volumeLiters, startPressureBar}` | same depth path; inspired gas from T is the chosen mix | the remaining bottom segments breathe that tank; the tank's `decoSwitchDepth` is pinned to the depth at T so the ascent plan uses it from here (a ppO2 violation surfaces as an engine issue, which is the honest answer to "what if I switched here") |
| `loseTank` | existing tank id with role deco, stage, bailout or pony | wherever the actual schedule breathed the lost tank after T, substitute the best remaining gas for that depth (`OptimalOcAscentGas` over remaining tanks, falling back to back gas) | tank removed before the engine runs (the `ContingencyService.lostGasFor` rule) |
| `shiftAscent` | `deltaSeconds` (negative = earlier) | not available (path change) | the last remaining bottom segment is shortened or extended by the delta; a delta that consumes the whole remaining bottom behaves as `ascendNow` |
| `ascendNow` | none | not available (path change) | no remaining bottom segments; the engine schedules the ascent from T |
| `changeGf` | `gfLow`, `gfHigh` (percent) | the whole dive is analysed under the new pair (a lens: tissues unchanged, ceilings / TTS / stops change) | same, and the branch state (anchor included) is re-derived under the new pair so the engine is consistent with its own ceilings |
| `shareGas` | `buddyFactor` (default `PlanEngineConfig.buddyFactor`) | same path; consumption after T charged at stressed SAC x buddy factor; reports when each tank reaches reserve and empty | implies `ascendNow`; engine SAC (bottom and deco) = stressed SAC x buddy factor; min-gas verdict at T |
| `bailOut` | optional tank id (default: every `bailout` role tank; a hypothetical tank may be supplied) | OC on the bailout gases by depth from T, stressed SAC, same path | implies `ascendNow`; OC plan on the bailout tanks at stressed SAC (the `BailoutSolver` rule applied at a chosen instant) |
| `ascentPolicy` | any of `ascentRateMPerMin`, `lastStopDepthM`, `extraLastStopSeconds`, `gasSwitchStopSeconds` | not available (path change) | overrides the corresponding `SchedulePolicy` fields; `extraLastStopSeconds` is appended to the final stop after the engine schedules it |

Replay semantics for `loseTank`, `shareGas` and `bailOut` are meaningful
because the question they answer is "would the stops I actually did have
been enough / would the gas have lasted on the path I actually swam".

### Composition rules

- A scenario holds a list of interventions. At most one per kind.
- Path-changing kinds (`shiftAscent`, `ascendNow`, `ascentPolicy`) are
  re-plan only. Adding one while in replay flips the mode to re-plan with a
  one-line explanation in the UI; removing the last one does not flip back.
- `shareGas` and `bailOut` imply `ascendNow` in re-plan (the dive is
  aborted). Adding `shiftAscent` alongside them is rejected by validation.
- On CCR and SCR dives `switchGas` is hidden (bailout is the switch) and
  `loseTank` applies to bailout tanks, which only changes the outcome when
  combined with `bailOut`.
- `changeGf` changes only the counterfactual timeline. The actual timeline
  is always the dive as logged under its effective GF, so the delta table
  shows "actual at GF a/b" versus "what-if at GF c/d", which is what the
  diver asked.

## Engine

All engine code is pure Dart and isolate-safe. `ScenarioEngine.run` is
invoked under `compute()` from the presentation layer.

### Settings resolution

`ScenarioSettings` is built by the provider layer exactly as
`profile_analysis_provider.computeAnalysisForProfile` does: per-dive GF
override only when both values are present, else the diver settings;
CNS method; `DiveEnvironment.forConditions(altitude, waterType)` with the
"altitude <= 0 means unset" rule; gas model; ppO2 working and deco limits;
last stop depth; stop increment; ascent and descent rates; SAC defaults.
A `changeGf` intervention replaces the GF pair for the counterfactual.

### `BranchState`

Derived from the actual analysis (re-run under the counterfactual GF when
`changeGf` is present, so the anchor matches):

| Field | Source |
| --- | --- |
| `index`, `runtimeSeconds`, `depthMeters` | nearest sample to `branchSeconds` on the primary profile |
| `compartments`, `gfLowCeilingAnchorBar` | `decoStatuses[index]` (the new anchor field) |
| `cnsPercent`, `otu` | `cnsCurve[index]`, `otuCurve[index]` |
| `activeTankId`, inspired gas | the gas segment in force at T (OC), or loop setpoint / diluent (CCR, SCR) |
| `tankPressuresBar` per tank | measured series at T; else the estimated series (linear start -> end, the `estimatedTankPressuresProvider` rule); else unknown. Each tank carries a `PressureSource {measured, estimated, unknown}` |
| `sacLitersPerMin` | rolling SAC at T from the analysis; else the dive's cylinder SAC; else `loggedAverageSacProvider`; else 15 L/min. Carries `SacSource {measured, diveAverage, logAverage, default}` |

Sources are surfaced as flags on the outcome and shown as "estimated"
badges in the UI.

### `DecoStatus.gfLowCeilingAnchorBar`

Nullable `double` added to `DecoStatus`. `BuhlmannAlgorithm.processProfile`
and `processProfileWithGasSegments` set it from the algorithm's running
`gfLowCeilingAnchor` after each sample. Existing constructors and callers
are unaffected (default null). The planner's `BuhlmannGf._capture()` already
preserves the anchor; this closes the same gap on the logged-dive path.

### Replay pipeline

1. Build the whole-dive inputs for `ProfileAnalysisService.analyze`:
   depths and timestamps unchanged; gas segments identical before T and
   rewritten after T per the intervention table; CCR setpoint schedule
   unchanged unless `bailOut` (then OC from T); GF pair per settings
   resolution.
2. Run `analyze` from t = 0. Samples before T reproduce the cached actual
   analysis bit for bit (same inputs, same service), so the delta at T is
   zero by construction and no mid-dive restore is needed. With `changeGf`
   the tissue-derived curves (compartments, GF99, surface GF, CNS, OTU)
   still match before T; only the GF-dependent curves (ceiling, TTS, NDL,
   stops) differ, which is the point of that intervention.
3. Consumption pass (separate, per sample, both timelines): litres per
   sample = SAC(t) x ambient pressure(t) x dt, charged to the timeline's
   active tank; after T for `shareGas` and `bailOut` the rate is stressed
   SAC x buddy factor (bailout: stressed SAC). Pressures via
   `pressureAfterConsuming` under the configured gas model. Output per tank:
   end pressure, `reserveReachedAt`, `emptyAt`. When a tank has a measured
   series in the actual timeline, the actual side reports the measured end
   pressure and the counterfactual side reports measured-up-to-T plus the
   simulated remainder.

### Re-plan pipeline

1. `BranchState` as above.
2. **Compile** a `DivePlan` (`lib/features/planner/domain/entities/dive_plan.dart`):
   - `mode` from the dive's mode (OC -> `PlanMode.oc`, CCR -> `ccr` with the
     dive's setpoints, SCR -> `scr`); `bailOut` compiles an OC plan.
   - `altitude`, `waterType`, GF, `lastStopDepth`, `ascentRate`,
     `descentRate`, `gasSwitchStopSeconds`, air breaks from settings;
     `ascentPolicy` overrides applied.
   - `sacBottom` = branch SAC; `sacDeco` and `sacStressed` left null so the
     planner defaults (0.8x, 2.5x) apply; `shareGas` and `bailOut` set both
     bottom and deco SAC to stressed x buddy factor (buddy factor 1 for
     bailout).
   - `tanks` = the dive's tanks with `startPressure` = pressure at T
     (unknown pressure -> the tank is carried with `startPressure` null and
     the outcome flags gas metrics for it as unavailable); `loseTank`
     removes; hypothetical tanks are appended with fresh ids; `switchGas`
     pins `decoSwitchDepth`.
   - `segments` = the remaining bottom phase: actual samples from T to
     `finalAscentStart`, coarse-grained by merging consecutive samples whose
     depth stays within +/-1.5 m of the running segment mean into one
     `PlanSegment.bottom` at the mean depth, with depth changes larger than
     that emitted as descent / ascent segments at the observed rate.
     `finalAscentStart` = start of the last `DivePhase.ascent` run in
     `calculateDepthBasedSegments`; when T is at or after it, there are no
     bottom segments. `shiftAscent` trims or extends the last bottom
     segment; `ascendNow` drops them all.
   - `sourceDiveId` = the dive id; `surfaceInterval` null.
3. `PlanEngine.compute(plan, startState: BuhlmannState(compartments,
   gfLowCeilingAnchor))`, engine config from the same providers the planner
   uses (`planEngineConfigProvider`).
4. **Synthesise** the counterfactual remainder at 10 s resolution from the
   plan segments plus the outcome's ascent and stops (including gas-switch
   stops and `extraLastStopSeconds`), time-shifted to start at T. This
   generalises `synthesizePlanProfile` (which today only walks segments)
   into a shared helper that also walks `PlanOutcome.stops`.
5. **Splice**: counterfactual profile = actual samples 0..index followed by
   the synthesised remainder; gas segments = actual before T, planned
   switches after; then `analyze` on the spliced profile from t = 0.
   `PlanOutcome` rides along for tank usages, turn and min gas, CCR loop gas,
   issues and the runtime table.

### `ScenarioOutcome`

```dart
class ScenarioOutcome {
  final BranchState branch;
  final ProfileAnalysis actual;
  final ProfileAnalysis counterfactual;
  final List<DiveProfilePoint> counterfactualProfile;
  final PlanOutcome? planOutcome;           // re-plan only
  final ScenarioConsumption consumption;    // per-tank, both timelines
  final List<ScenarioDelta> deltas;
  final List<ScenarioDelta> verdictDeltas;  // the leading deltas; the UI
                                            // composes the sentence via l10n
  final List<ScenarioFlag> flags;           // estimated SAC / pressure, etc.
  final BuoyancyComparison? buoyancy;       // phase 4
}
```

`ScenarioDelta { metric, actual, counterfactual, delta, unitKind,
betterWhen }` where `betterWhen` is `lower`, `higher` or `neutral` so the UI
can colour direction without per-metric special cases.

Delta metrics (both timelines unless noted): runtime; TTS at T (each
timeline's `ttsCurve[index]`, which differs only when GF or the available
ascent gases differ); total deco
time; first stop depth and stop count; surface GF; peak GF99 after T; CNS at
surface; OTU at surface; max ppO2 after T; per-tank end pressure with
reserve status; gas-out instant (if any); min gas at T versus available
(`shareGas`); ceiling violations after T (count and worst excursion);
buoyancy: net at the last stop, peak lift demand, min ditchable lead (phase
4); the engine's severity-sorted issue list (re-plan).

Verdict: `verdictDeltas` holds the three largest normalised deltas; the UI
renders them as one localised sentence, for example "Surfacing 9 min
earlier with surface GF 71% vs 78%; the 50% bottle would have ended at
62 bar".

### Execution, caching, performance

- `ScenarioEngine.run(ScenarioRequest)` under `compute()`. The request
  carries the dive, primary profile, tanks, gas switches, pressure series,
  cached actual analysis, settings and the scenario; all already
  isolate-safe types (the existing analysis isolate carries the same).
- Debounced ~150 ms while scrubbing T or editing chips. Memoised by a hash
  of (dive id, analysis settings, scenario).
- Cost: one whole-dive analysis (same as the existing cached one, hundreds
  of milliseconds for a 90 min dive at 1 s samples) plus, for re-plan, one
  `PlanEngine.compute` and one more analysis of the spliced profile.

### Invariants (tests)

- Identity: replay with no interventions equals the cached actual analysis
  (ceiling, GF99, CNS, OTU curves) exactly.
- Continuity: in both modes, every tissue-derived counterfactual curve
  (compartments, GF99, surface GF, CNS, OTU) equals the actual one at
  `index`; the GF-dependent curves (ceiling, TTS, NDL) also match at
  `index` unless the scenario contains `changeGf` or removes / adds a tank
  (which changes the ascent gas plan and therefore TTS at T).
- Monotonicity: `loseTank` never shortens total deco; `shiftAscent`
  earlier never lengthens it; raising GF-high never raises TTS.
- Compile round-trip: the remaining-bottom segments reproduce the actual
  remainder's mean depth within 0.5 m and its duration exactly.
- Codec round-trip for every intervention kind and for `.sublab`.
- Anchor: a mid-dive `restoreState` from `DecoStatus.gfLowCeilingAnchorBar`
  continues to the same ceilings as the uninterrupted run.

No new tissue math is introduced, so no new Python golden vectors;
`PlanEngine`'s golden suite remains the validation anchor. Hand-computed
vectors for the consumption pass and deltas (computed, not recalled).

## UI

### `DiveLabPage`

Pushed on the root navigator (the `FullscreenProfilePage` pattern, issue
#811) with `diveId` and optional `scenarioId`. Entry points: a new icon in
the profile-card toolbar (next to fullscreen / 3D) and "What if…" in the
overflow menu, in both app-bar chrome variants of `dive_detail_page.dart`.
The branch point pre-seeds from `profileTrackingIndexProvider(diveId)` when
a point is selected; otherwise it defaults to `finalAscentStart`.

Layout:

```
Phone (stacked; chart fixed ~40% height, the rest scrolls)
+----------------------------------------+
| < Dive Lab   [Save] [Share] [Saved] ⋮  |
|  chart: actual solid, what-if dashed   |
|  from T, branch marker, ceiling band   |
|----------------------------------------|
| Branch 23:40 @ 31.2 m [-1m][-10s][+10s][+1m]
| Mode ( Replay | Re-plan )              |
| [Switch to 50% x] [Ascend now x] [+ Add]
|----------------------------------------|
| Verdict line                           |
| tiles | delta table | tissue strips    |
| per-tank gas | issues | runtime table  |
| buoyancy rows                          |
+----------------------------------------+

Wide (>= 1160): chart + controls in the left pane, delta panel in a
scrollable right pane. 760-1160: right pane collapsible.
```

- **Chart**: the existing `DiveProfileChart` with the actual profile, the
  counterfactual as a `ChartSourceOverlay` (`sourceId: 'lab:<scenarioId>'`,
  dashed accent colour, appended after the `sourceById` filtered loop
  exactly as `plannedOverlay` is), the branch marker via
  `highlightedTimestamp`, and the counterfactual's ceiling and deco-stop
  curves in the chart's ceiling params with a legend toggle to show the
  actual ones instead. Drag-scrub moves T (`onPointSelected`); steppers give
  precision. Range selection is disabled on this page.
- **Controls**: branch readout with steppers; Replay / Re-plan segmented
  control; intervention chips (tap edits, x removes) and "+ Add", which
  opens a bottom sheet listing the kinds valid for this dive and mode. Each
  kind has a small form reusing planner widgets: tank picker over the dive's
  tanks, gas-mix picker, minute steppers, GF pair, buddy factor, policy
  fields.
- **Delta panel**: verdict line; headline tiles (TTS, deco time, surface GF,
  CNS, gas); full delta table (actual | what-if | delta, coloured by
  `betterWhen`); end-of-dive tissue strips actual vs what-if
  (`TissueHeatMapStrip`); per-tank gas rows with reserve status and gas-out
  instant; severity-sorted issues; the counterfactual runtime table;
  buoyancy rows when the twin has inputs. Estimated inputs carry an
  "estimated" badge whose tooltip names the fallback used. Every value
  respects the active diver's unit settings.
- **Recompute**: debounced, under `compute()`, a thin progress bar while
  stale; the previous result stays visible, dimmed, until the new one lands.
- **Saved sheet**: this dive's scenarios (open, duplicate, rename, delete,
  multi-select for PDF, import scenario file). Save prompts for a name with
  a generated default such as "Re-plan at 23:40, 50% lost".

### Teaser card

`DiveDetailSectionId.diveLab` ("What if") on dive detail: the dive's saved
scenarios, each with a lazily computed one-line summary ("Re-plan at 23:40:
deco -9 min, surf GF 71%"; computed in the isolate on first visibility,
cached per session) and a "New scenario" CTA. Hidden for ineligible dives.
Tapping a row opens the lab on that scenario. Participates in the section
registry (reorder / hide in Settings).

### l10n

All strings through `AppLocalizations`, keys added to every locale ARB
(`diveLab_*`). Engine output uses keys plus arguments, never prose.

## Persistence, sync and sharing

### `dive_scenarios`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | text PK | uuid |
| `dive_id` | text FK -> `dives.id` ON DELETE CASCADE | |
| `name` | text | |
| `notes` | text nullable | |
| `branch_seconds` | int | |
| `mode` | text | `replay` / `replan` (enum by name, like `PlanMode`) |
| `interventions_json` | text | versioned JSON array |
| `created_at`, `updated_at` | datetime | |
| HLC / tombstone columns | | identical set to `dive_plans` |

Schema version: the next free number at implementation time. Main is at
v160 (`currentSchemaVersion = 160` on `origin/main` as of 2026-08-21);
re-grep the scalar and the open PR claims when the migration is written
(schema-version-ladder memory). Migration adds the table and indices;
`beforeOpen` backstop per convention.

`DiveScenarioRepository` (save / get / listByDive / delete / watch) mirrors
`DivePlanRepository` including sync-log writes and tombstones. Sync
registration follows the 18-site pattern (14 serializer, 3 sync_service, 1
`_hlcTargets`) and the structural tests are extended. The table follows the
2026-08-17 cross-version sync compatibility rules so older clients ignore
it. Deleting a dive deletes its scenarios (FK cascade plus the sync deletion
handling the deletion-FK memory describes). Backup and restore need nothing
extra.

### PDF slate

`DiveLabSlatePdfService` in the `PlanSlatePdfService` mould (PdfFonts
theme, `sharePdfBytes` / `savePdfToFile`): dive header; scenario description
(branch time and depth, mode, interventions, settings used: GF, model, gas
model); the chart captured as PNG through the chart export key (the
existing `_exportProfileChart` path) and embedded; delta table; per-tank
gas; counterfactual runtime table; issues; an "estimated inputs" footnote.
Multi-selecting scenarios in the Saved sheet yields one PDF with a section
per scenario. Chart PNG share reuses the existing export path unchanged.

### `.sublab` scenario file

Versioned JSON via the `plan_file_codec` pattern:

```json
{
  "formatVersion": 1,
  "exportedBy": {"app": "submersion", "version": "x.y.z", "platform": "..."},
  "scenario": { ... DiveScenario ... },
  "diveSnapshot": {
    "diveId": "...", "diveDateTime": "...", "siteName": "...",
    "diveMode": "oc|ccr|scr", "gfLow": 30, "gfHigh": 70,
    "altitudeMeters": 0, "waterType": "salt",
    "tanks": [ ... ], "gasSwitches": [ ... ],
    "profile": [ {"t": 0, "d": 0.0, "temp": 24.1, "setpoint": null, "ppO2": null}, ... ],
    "tankPressures": { "<tankId>": [ {"t": 0, "bar": 210.0}, ... ] },
    "computerName": "..."
  }
}
```

Export from the Saved sheet and the app-bar Share menu. Import from the
Saved sheet ("Import scenario file") and from the universal-import
extension router so opening a `.sublab` from Files lands there. Import
rules: if the dive id exists locally, attach the scenario with a fresh id
(skip when an identical scenario already exists); otherwise create the dive
from the snapshot as an ordinary imported dive (notes record "Shared via
Dive Lab scenario from <app/device>") and attach. Foreign or newer
`formatVersion` raises `FormatException` and shows the same error dialog
`.subplan` import uses.

## Phases

One plan document and one worktree per phase (phases 3, 4 and 5 stack on
this branch or on each other as the planner program did). Phases 3 and 4
are independent once 2 lands; 5 needs 3.

| Phase | Deliverable | Releasable as |
| --- | --- | --- |
| 1 | Engine + domain: `DecoStatus` anchor, `BranchState`, interventions + codec, `ScenarioEngine` (replay, re-plan compile, synthesis, splice, consumption pass, deltas, verdict), invariant tests | internal only |
| 2 | Lab page, ephemeral: chart overlay, branch controls, mode switch, chips for the five core interventions, delta panel (no buoyancy), entry points, isolate + debounce | "What if" explore-and-forget |
| 3 | Persistence + sync + Saved sheet + teaser card (schema bump) | saved scenarios |
| 4 | Extras: `bailOut` for CCR/SCR dives, `ascentPolicy`, buoyancy rows (twin over the counterfactual profile) | full intervention set |
| 5 | Outputs: PDF slate, `.sublab` export/import, multi-scenario PDF | share with an instructor |

## Error handling

- Ineligible dive: entry points hidden; a direct open shows a friendly
  empty state naming the reason.
- Analysis still computing or unavailable: loading state, never a blank
  chart; if the actual analysis fails, the lab shows the analysis error and
  no scenario runs.
- No pressure data: gas rows are labelled estimated (SAC-based); with no
  SAC source at all, gas metrics are hidden with a one-line reason.
- Undiveable re-plan (for example deco cannot be completed on carried gas):
  the engine returns its issues and the partial schedule; the panel renders
  a "not completable as branched" banner and the issue list. The engine
  never throws on an undiveable scenario.
- CCR / SCR dive with no bailout tank: the `bailOut` chip prompts for a
  hypothetical tank before it can be added.
- Validation errors on composition (duplicate kind, `shiftAscent` with
  `shareGas`): rejected at the chip sheet with an inline message.
- Isolate failure: caught, logged, "couldn't compute" with a retry action.
- Import: malformed or newer file -> `FormatException` -> error dialog;
  snapshot missing a profile -> rejected with a message.

## Testing

- Unit (pure Dart): engine identity, continuity, monotonicity, compile
  round-trip, synthesis, splice, consumption pass, deltas and verdict with
  hand-computed vectors; intervention and `.sublab` codec round-trips;
  `DecoStatus` anchor continuity.
- Provider integration through the real DB (the buoyancy-twin lesson:
  hydration sources must be tested end to end, not with hand-built
  entities): outcome provider from a seeded dive with tanks, switches and
  pressures; teaser summary provider.
- Widget: lab page phone and wide, branch controls, chip sheet forms, delta
  table colours, tissue strips, Saved sheet, teaser card, locale pinned to
  `en`, `settingsProvider` overridden as the planner tests do.
- Persistence: repository round-trip, FK-on sync round-trip, tombstones,
  structural sync registration tests, migration test asserting the exact
  new version.
- PDF: bytes non-empty and document structure asserted (embedded fonts
  defeat text extraction under `flutter test`; do not assert on extracted
  text).
- Release gate: a manual checklist running a handful of real logged dives
  (the on-disk samples) through "ascend now" and "lost deco gas" and
  comparing the re-planned schedule against MultiDeco seeded with the same
  tissue state.

## Explicitly out of scope (v1)

- VPM-B in the lab (Buhlmann only, matching `PlanEngine`).
- Changes before the branch point: a scenario is always a suffix change.
- Multi-dive or repetitive-dive chains.
- In-app side-by-side of two scenarios (the multi-scenario PDF covers it;
  a compare view is a natural v2, the `PlanComparePage` pattern applies).
- Deep links or QR for scenarios.
- Instructor comments or annotations on a scenario.
- Scenario templates or "try all interventions" sweeps.
- Editing the actual profile.
