# Planner: SCR injection rate and VO2, pSCR VO2 (issue #4660)

## Intent

The planner's semi-closed modes run on fixed figures a diver cannot see or
change. A constant mass flow (CMF) SCR plan always assumes a 12 L/min supply
injection rate and a 1.3 L/min metabolic O2 consumption (VO2). A Drager Ray
owner asked where to enter their nozzle's flow; there is nowhere. For a nozzle
delivering less than 12 L/min the planner overstates loop O2, understates inert
gas loading and overstates no-stop time: the non-conservative direction. CMF
supply gas use is the injection rate times time, so gas duration is wrong too.

The passive SCR (pSCR) mode has the same gap: its O2 consumption (720 mL/min)
is fixed, and its loop-O2 drop reads a hidden 20 L/min SAC while the same plan's
gas budget reads the diver's own bottom SAC (15 L/min by default).

## Goals

- A diver can set, per plan, the SCR injection rate, the SCR VO2 and the pSCR
  VO2, with diver-level defaults in Settings > Planner defaults.
- An empty plan field follows the diver's default live, as the CCR setpoints
  and every other overridable Setup field do (issue #3552).
- Values show and are typed in the active diver's volume unit per minute
  (L/min or cuft/min), the same lane as the dive log's SCR panel (#1935).
- Values are stored with the plan, so a recalled plan recomputes the same way.
- A diver can check the resulting loop against their unit's documentation:
  the SCR loop FO2 range, and the pSCR inspired ppO2 drop.
- An injection rate too low for the VO2 is a critical plan issue, never a
  silent fallback.

## Non-goals

- A rebreather equipment model (a gear item carrying nozzle flow). Out of
  scope; there is no such model today.
- ESCR planning, orifice size or nozzle catalogue lookups.
- Changing the pSCR ratio's storage. It stays a diver-wide setting edited from
  the planner's pSCR section.
- A depth-varying or workload-phased VO2 inside one plan. One VO2 per plan.

## Anti-goals

- With nothing entered, an SCR plan must compute exactly as it does today.
- Migrations add empty columns only; no existing plan or setting is rewritten.

## Decisions (made with the maintainer)

1. **Scope:** SCR injection rate and VO2, plus pSCR VO2.
2. **pSCR SAC:** the hidden 20 L/min (`pscrSacMlMin`) is removed. The pSCR
   loop-O2 drop reads the plan's resolved bottom SAC (`sacBottom`, plan value
   or diver default), the same SAC its gas budget already uses, as Subsurface's
   `pscr_o2` does with `bottomsac`. With the 15 L/min default this lowers the
   predicted loop O2 slightly on existing pSCR plans: the conservative
   direction. Accepted.
3. **Approach A:** mirror the CCR setpoints. Nullable per-plan columns, synced
   diver defaults, merged through `PlanEngineConfig.resolvedFor`.
4. **VO2 is separate per mode:** one SCR VO2 (default 1.3 L/min) and one pSCR
   VO2 (default 0.72 L/min), each with its own plan field and diver default,
   so neither mode's numbers move for a diver who enters nothing.
5. **Dive Lab** falls back to the diver's new defaults for a logged dive with
   no injection rate or VO2 of its own.

## Approaches considered

| Approach | Trade-off | Outcome |
| --- | --- | --- |
| A. Per-plan nullable columns + diver defaults (CCR setpoint pattern) | Three plan columns and three diver settings, synced; fits every existing Setup field | **Chosen** |
| B. Diver-wide setting only (like the pSCR ratio) | No plan columns, but a recalled plan follows today's default, and a diver with two units cannot plan both | Rejected |
| C. Read flow from a rebreather gear item | No rebreather equipment model exists; a project of its own | Rejected |

## Design

### Data

`dive_plans` (in `lib/core/database/tables/dive_plan_tables.dart`), three
nullable real columns, null meaning "use the diver's default":

- `scrInjectionRate` (surface L/min)
- `scrVo2` (surface L/min)
- `pscrVo2` (surface L/min)

`diver_settings` (in `lib/core/database/tables/diver_tables.dart`), three
non-null real columns with defaults 12.0, 1.3 and 0.72:

- `plannerScrInjectionRate`, `plannerScrVo2`, `plannerPscrVo2`

One schema rung adds all six columns (empty or defaulted; no rewrite). Both
tables already sync, so the new columns join the sync serializer and the
settings conflict catalogue the way their neighbours do. Defaults reach fresh
databases only by being column defaults; nothing is backfilled.

### Domain

- `DivePlan` gains `scrInjectionRate`, `scrVo2`, `pscrVo2` (nullable, with
  `copyWith` clear flags), and the plan repository maps them.
- `AppSettings` gains the three diver defaults with setters on the settings
  notifier.
- `PlanEngineConfig`: keep `scrInjectionRateLpm` and `scrVo2Lpm`; replace
  `pscrO2ConsumptionMlMin` by an L/min `pscrVo2Lpm` (multiply by 1000 where
  the pSCR model wants mL/min); delete `pscrSacMlMin`.
- `planEngineConfigFromSettings` sets all three from settings.
- `resolvedFor(plan)` merges the three plan fields with `?? this.x`.
- `breathingFor` passes `config.sacBottom * 1000` as the pSCR SAC. `config`
  there is already the plan-resolved config, so the plan's own bottom SAC wins.

### Engine guard

`ScrCalculator.calculateCmfSteadyStateFo2` has no valid answer (returns null)
in two cases: the injection rate is at or below VO2, or the flow carries less
O2 than the diver uses (rate x supply FO2 below VO2, for example 4 L/min of
EAN32 at VO2 1.3). In both, `Scr` falls back to the supply mix, so the inspired
ppO2 looks like the supply's and the existing hypoxic checks never fire.

When any leg breathes a CMF loop (plan mode SCR, or an SCR segment) on a supply
gas for which the steady state is invalid at the resolved injection rate and
SCR VO2, the engine raises a new critical `PlanIssueType.scrFlowTooLow`, one
issue per distinct supply gas, naming the gas, the rate and the VO2 (builder's
call: the condition depends on each leg's supply gas, not only the two
scalars). The tissue loading may keep today's fallback; the critical issue is
what stops the plan reading as diveable. The existing hypoxic-loop checks remain
for valid steady states that are still hypoxic at depth.

### Planner Setup UI

- **New SCR section** in `plan_setup_accordion.dart`, shown when the plan mode
  is SCR (placed where the CCR and pSCR sections sit). Two `PlanNumberField`s,
  injection rate and VO2, value = plan field converted to the volume unit,
  hint = diver default converted, suffix = `units.rmvSymbol`, decimals from the
  RMV lane. Clearing a field clears the plan override.
- Under them, a one-line loop check: the loop FO2 at the resolved VO2, at
  resting VO2 (`ScrCalculator.restingVo2`) and at hard-work VO2
  (`ScrCalculator.hardWorkVo2`), on the plan's supply gas (the first diluent /
  supply cylinder's mix). Where the steady state is invalid for a VO2 (either
  case in Engine guard), that slot says "flow too low" instead of a percentage.
- Decimals (builder's call): the injection rate uses the RMV lane's decimals;
  VO2 uses one more, as the dive log's SCR panel does (`_vo2Decimals` in
  `scr_settings_panel.dart`), because 1.3 L/min is 0.046 cuft/min and two
  decimals would round a retyped hint to about 1.42 L/min. The same rule
  applies to the hints and to the Settings tiles.
- **pSCR section:** gains a VO2 `PlanNumberField` beside the existing ratio, and
  a one-line inspired ppO2 drop (bar) at the resolved VO2, bottom SAC and ratio.
- The Setup info sheet (`plan_setup_info.dart`) and info terms gain entries
  for injection rate and VO2.

### Settings

`Settings > Planner defaults` gains a **Rebreather** card with three
`PlannerDefaultTile`s built like the existing `rmvTile`: SCR injection rate,
SCR VO2, pSCR VO2, all in the diver's volume unit per minute.

### Logging a plan

`planned_log_entry.dart` writes, gated by plan mode as setpoints are gated by
`_onLoop`: for an SCR plan, `scrType = cmf`, `scrInjectionRate` and
`assumedVo2` (the resolved values); for a pSCR plan, `scrType = pascr` and
`assumedVo2` (the resolved pSCR VO2). Other modes write null. The
"unchanged" comparison (`matches`) compares the same resolved values (builder's
call). Planned entries logged before this change carry no loop values, so each
SCR or pSCR planned entry reads as behind once and "Update planned dives"
offers to fill them in. After that, a changed diver default adds no churn of
its own: it changes the loop FO2 and so the deco profile, which `matches`
already compares.

### Dive Lab

`ScenarioSettings.engineConfigFor` falls back to the diver's new defaults
(SCR injection rate, SCR VO2, pSCR VO2) instead of the engine constants when a
logged dive has no injection rate or VO2 of its own (maintainer's choice), so
the Lab and the planner agree. The new `scrFlowTooLow` critical issue applies
in the Lab too; it already treats any critical issue as "replan not
completable" (`isReplanCompletable`), which is correct for a loop the diver
could not have breathed.

### Agent access

Mirror the setpoint fields:

- `plan_documents.dart`: expose the three plan fields (null = follows diver).
- `dive_plan_fields.dart`: accept them as writable plan inputs
  (`scr_injection_rate_l_min`, `scr_vo2_l_min`, `pscr_vo2_l_min`), validated
  positive.
- `plan_result_document.dart`: report the resolved values with the existing
  `own(...)` / `fromSettings(...)` labels; drop any mention of the removed
  pSCR SAC.
- Regenerate `sql_column_notes.generated.dart` from the new column docs.

### Validation

All inputs must be positive. Field minimums: injection rate 0.1 L/min, VO2
0.1 L/min (converted for display). No upper bound beyond what the number field
already allows. The cross-field check (flow at or below VO2) is the engine
issue above, not a field error, because the two values can come from
different sources (plan vs diver default).

## Acceptance

- An SCR plan computed with a diver-entered injection rate and VO2 breathes
  the loop FO2 `ScrCalculator.calculateCmfSteadyStateFo2` gives for those values,
  and charges supply gas at the entered injection rate.
- With no values entered, an SCR plan's outcome is identical to today's.
- A pSCR plan's loop-O2 drop uses the entered pSCR VO2 and the plan's resolved
  bottom SAC.
- An injection rate at or below VO2, or one whose O2 delivery (rate x supply
  FO2) is below VO2, yields a critical `scrFlowTooLow` issue.
- A Dive Lab replay of a logged SCR dive with no rate or VO2 uses the diver's
  defaults.
- Inputs, hints and the Settings tiles display in the diver's volume unit, and
  typed values convert back to L/min.
- A saved plan reloads with its values; a changed diver default changes only
  plans whose fields are empty.
- A logged SCR plan's dive carries injection rate and VO2.

## Left to the builder

- Exact l10n keys and wording (English source; other locales via the usual
  ARB flow).
- Whether the loop-check line is a widget of its own file.
- Test layout, provided engine, mapper, migration, sync, UI and agent paths
  are each covered.
