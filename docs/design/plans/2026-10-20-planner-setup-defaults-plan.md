# Planner setup defaults: implementation plan

**Issue:** #3552
**Spec:** `docs/design/specs/2026-10-20-planner-setup-defaults-design.md`

**Goal:** Every Setup-accordion field that has no global source today gets one
on `DiverSettings`, resolved live (not snapshotted) the same way
`ppO2Bottom`/`ppO2Deco`/`o2Narcotic`/`setpointLow`/`setpointHigh` already are.
A plan field overridden by the diver is visibly distinct from one still
following Settings, using the hint-text pattern `PlanNumberField` already has
(no new shared widget). The new global defaults are edited on the existing
Decompression sub-page under Settings > Safety.

**Tech stack:** Flutter, Riverpod, Drift (DB migration ladder), Equatable
entities.

**Revision note (2026-10-20, after cross-examination):** this replaces the
first draft, which (a) invented a new shared override widget that duplicates
`PlanNumberField`'s existing hint-text pattern, (b) deferred CCR/PSCR/DPV
Team to a follow-up PR, and (c) coupled `sacDeco` to `sacBottom` implicitly.
All three were corrected per explicit decisions below. Everything in the
spec's scope ships in this one PR, in small, separately committable tasks.

## Scope: all of it, in small commits

Every section gets its global default in this PR:

| Field | New `DiverSettings` column | Default | Current UI shape |
| --- | --- | --- | --- |
| `descentRate` | `plannerDescentRate` | 18.0 | `PlanNumberField`, `allowEmpty: false` -> becomes `true` |
| `ascentRate` | `plannerAscentRate` | 9.0 | same |
| `intermediateAscentRate` | `plannerIntermediateAscentRate` | 6.0 | same |
| `shallowAscentRate` | `plannerShallowAscentRate` | 3.0 | same |
| `finalAscentRate` | `plannerFinalAscentRate` | 1.0 | same |
| `lastStopDepth` | reuse existing `DiverSettings.lastStopDepth` | 3.0 | `PlanLastStopSelector` (segmented control, not a text field) - gains a "Default" segment |
| `gasSwitchStopSeconds` | `plannerGasSwitchStopSeconds` | 0 | already `PlanNumberField`, `allowEmpty: false` -> `true` |
| `sacBottom` | `plannerSacBottom` | 15.0 | `allowEmpty: false` -> `true` |
| `sacDeco` | `plannerSacDeco` (own column, decided: no implicit coupling to `sacBottom`) | 15.0 | already override-shaped, just needs the new `hintValue` source |
| `sacStressed` -> new `sacStressedFactor` | `plannerSacStressedFactor` | 2.5 | **no UI today** - new field added to `PlanGasOptionsSection` |
| `sacFactor` | `plannerBuddyFactor` | 2.0 | `allowEmpty: false` -> `true` |
| `problemSolvingMinutes` | `plannerProblemSolvingMinutes` | 2 | `allowEmpty: false` -> `true` |
| `bestMixEndMeters` | `plannerBestMixEndMeters` | 30.0 | `allowEmpty: false` -> `true` |
| `deviationDepthDelta` | `plannerDeviationDepthDelta` | 5.0 | `contingency_settings_section.dart`, check current shape |
| `deviationTimeMinutes` | `plannerDeviationTimeMinutes` | 5 | same |
| `setpointLow`/`setpointHigh` | *(already live-resolved)* `ccrSetpointLow`/`ccrSetpointHigh` | - | **UI retrofit only**: hand-rolled controller in `ccr_settings_section.dart` -> `PlanNumberField` hint-text pattern |
| `DpvMission.batteryReserveFraction` | `plannerBatteryReserveFraction` | 1/3 | `allowEmpty: false` -> `true` |
| `DpvMission.walkSpeedMps` | `plannerWalkSpeedMps` | 0.8 | `allowEmpty: false` -> `true` |

Explicitly **not** touched (per spec non-goals/anti-goals):

- `airBreaks`, `stopMinimums`, `turnPressureRule`, `turnPressureFraction` -
  no sensible global default.
- `altitude`, `startDateTime`, `waterType`/`salinityPpt` - per-dive, or
  already on the separate snapshot mechanism.
- `DpvMission.defaultCurrent`/`setsTowardDeg`/`surfaceSwimLimitM` - describe
  this dive, not a diver policy.
- `pscrRatio` - already purely global, no plan-level field exists.
- `ppO2Bottom`/`ppO2Deco`/`o2Narcotic` - already correctly live-resolved AND
  already show the override state (`PlanNumberField` today); no change.

## Architecture

- `PlanEngineConfig` (`lib/features/planner/domain/services/plan_engine.dart`)
  gains the new fields (mirrors `ppO2Working` etc.), built from
  `DiverSettings` in `planEngineConfigProvider`
  (`lib/features/planner/presentation/providers/plan_canvas_providers.dart`).
- `PlanEngineConfig.resolvedFor(plan)` gains `copyWith(field: plan.field)`
  lines for every new nullable field, matching the existing `ppO2Working`/
  `ppO2Deco`/`o2Narcotic` lines - a plan value always wins, `null` leaves the
  Settings-sourced config value in place. `sacFactor`/`bestMixEndMeters`
  reuse the existing `buddyFactor`/`bestMixEndMeters` config fields exactly
  as `ppO2Bottom` reuses `ppO2Working`.
- New resolver getters on `PlanEngineConfig`, matching `setpointLowFor`/
  `setpointHighFor`: one `<field>For(plan)` per new field that the engine
  itself consults mid-computation. `DpvMission`-level fields
  (`batteryReserveFraction`, `walkSpeedMps`) resolve through the mission
  engine/validator's own config instead, wherever that already reads
  `DpvMission` defaults - inventory the exact call sites in Task 7.
- Every engine call site currently reading a field now-nullable field
  directly switches to the resolved getter (grep-driven, mechanical,
  per-task below - the 65-file grep hit list from cross-examination includes
  many false positives from generic names like `ascentRate`/`sacFactor`
  reused by unrelated classes; each task filters its own subset).
- `DivePlan`/`DpvMission` fields in scope become nullable, hardcoded
  constructor defaults removed, doc comments updated ("null = use the
  app-wide setting", matching the existing `ppO2Bottom` comment style).
- UI: no new shared widget. Every `PlanNumberField` usage currently in
  `allowEmpty: false` mode switches to `allowEmpty: true` with `hintValue`
  sourced from the new Settings provider instead of the plan's own value -
  the exact change already present for `ppO2Bottom`/`ppO2Deco`/`sacDeco`
  today. `PlanLastStopSelector` gets a new "Default" segment. CCR's
  `ccr_settings_section.dart` is rewritten to use `PlanNumberField` instead
  of its hand-rolled `TextEditingController`/`ref.listen` pair, dropping
  `_followSettings` entirely.
- Decompression sub-page (`decompression_settings_page.dart`) gains new
  field groups for Rates, Gas/SAC, Contingency, and DPV Team policy values,
  editing the new `DiverSettings` columns directly (no override concept
  there - it IS the global default).

## Database migration

`DiverSettings` gains the new columns via the existing migration ladder
(`lib/core/database/migrations/ladder/rungs_v231_onward.dart` and the
`diver_migrations.dart` helper under
`lib/core/database/migrations/helpers/`), not a new standalone file - check
the most recent rung there for the exact `addColumn`/schema-version-bump
pattern and copy it.

## Review focus

1. A plan value of exactly `0` (`gasSwitchStopSeconds`, a `0` current -
   though that one is out of scope - etc.) must never be mistaken for
   "unset." Only Dart `null` means "follow Settings." Grep for `?? 0` or
   truthiness shortcuts that would break this.
2. `resolvedFor`'s doc comment explicitly says every field must go through
   `copyWith` "so a field added later cannot silently fall back to its
   default here (issue #2640)" - every new field must actually be wired
   into `resolvedFor`/the new `*For(plan)` getters, not left reachable only
   via the config's own constructor default.
3. After this PR, every live-resolved field (old and new) shows the same
   visible override state through the same `PlanNumberField` hint-text
   mechanism - no stray, differently-built indicator anywhere, and no field
   left showing no indicator at all (this was true of CCR before the
   retrofit; must not be true of anything after).
4. Existing plans/missions in the DB have concrete (non-null) values for
   every field in scope (they were never nullable before), so the migration
   changes no existing plan's behavior - only newly created plans/missions
   start `null`. Cover with a test loading a pre-migration-style fixture and
   asserting its resolved values are unchanged.
5. `sacDeco` and `sacBottom` are independent globals after this PR (decided
   explicitly) - a test should confirm changing one does not affect the
   other's resolved value.

## File structure

| File | Responsibility |
| --- | --- |
| Modify `lib/core/database/tables/diver_tables.dart` | ~14 new columns |
| Modify `lib/core/database/migrations/ladder/rungs_v231_onward.dart` + `helpers/diver_migrations.dart` | migration rung |
| Modify `lib/features/planner/domain/entities/dive_plan.dart` | fields nullable, defaults removed |
| Modify `lib/features/planner/domain/entities/mission/dpv_mission.dart` | `batteryReserveFraction`/`walkSpeedMps` nullable |
| Modify `lib/features/planner/domain/services/plan_engine.dart` | new `PlanEngineConfig` fields, `resolvedFor` lines, `*For(plan)` getters |
| Modify `lib/features/planner/presentation/providers/plan_canvas_providers.dart` | wire new config fields from Settings providers |
| Modify `lib/features/settings/presentation/providers/settings_providers.dart` | new providers |
| Modify `lib/features/settings/data/repositories/diver_settings_repository.dart` | read/write new columns |
| Modify `plan_rates_section.dart` | `_RateField` -> nullable/override-capable |
| Modify `plan_deco_section.dart` | `PlanLastStopSelector` "Default" segment |
| Modify `plan_gas_options_section.dart` | existing fields' `hintValue` source switched to Settings; new `sacStressedFactor` field added |
| Modify `contingency_settings_section.dart` | deviation fields -> override-capable |
| Rewrite `ccr_settings_section.dart` | drop hand-rolled controllers, use `PlanNumberField` |
| Modify `mission_team_section.dart` | `batteryReserveFraction`/`walkSpeedMps` -> override-capable |
| Modify `decompression_settings_page.dart` | new field groups |
| Modify every engine/UI call site reading the now-nullable fields directly (grep pass per task, not fully enumerable up front) |

---

### Task 1: `DiverSettings` columns and migration rung

- [ ] Write a migration test asserting the new columns exist with the right
      defaults after migrating a fixture DB from the previous schema
      version.
- [ ] Run; FAIL.
- [ ] Add the columns to `DiverSettings` and the migration rung.
- [ ] Run; pass. Commit `feat(db): add planner default-setting columns to DiverSettings`.

### Task 2: Settings providers and repository

- [ ] Write provider tests (default value, round-trip write/read) per new
      Settings value, following the existing `lastStopDepthProvider`
      pattern.
- [ ] Run; FAIL.
- [ ] Add providers and repository read/write.
- [ ] Run; pass. Commit `feat(settings): expose planner default values`.

### Task 3: Deco + Rates - nullable fields and engine resolution (done)

Shipped as two commits, `9bcae527e4` (DB rebuild) and `725414410f`
(everything else). Turned out bigger than planned - worth recording why,
since Tasks 4-6 hit the same shape:

- The `dive_plans` columns for these fields were NOT NULL from the initial
  schema, not added later via `ALTER TABLE ADD COLUMN` - making them
  nullable needed a real table rebuild (no `ALTER COLUMN` in SQLite), not
  just a Drift-side type change. Done once, for **all** fields in scope
  across Deco/Rates/Gas/Contingency (13 columns), in the v303 migration -
  see `_assertDivePlanSetupFieldsNullable` in `dive_plan_migrations.dart`.
  **This means Tasks 4-6 need no further DB rebuild** - only their own
  Drift `.nullable()` column declaration, domain entity nullability, and
  wiring.
- `DivePlanState` (the UI draft model, `plan_result.dart`) needed the same
  nullable + `clearX`-flag treatment as `DivePlan` itself - the UI reads
  this, not the domain entity directly. Budget this into every remaining
  field-group task, not a separate later "UI" task.
- `expandRateSplitSegments` and `withDiluentSwitchTime` (pure functions, no
  `PlanEngineConfig` access) needed resolved values threaded in as explicit
  parameters from every call site (`PlanEngine`, `BailoutSolver`,
  `buildCanvasSeries`, `SegmentList`) - not a config field change, a
  call-site change.
- `MissionSegmentBuilder`/`addSimplePlan` (notifier) have no Settings access
  at all; an unset rate there falls back to the spec constant (the
  documented step-4 last resort), not a thread-through of config.
- The "shared override widget" from the original draft never existed -
  `PlanNumberField`'s existing `hintValue`/`allowEmpty` already does it;
  every `_RateField`-style wrapper just needed its `allowEmpty` flipped and
  `hintValue` repointed at the new Settings provider.
- `lastStopDepth`'s `PlanLastStopSelector` got a "Default (X m)" segment
  (new ARB key `divePlanner_label_defaultWithValue`, translated into all
  locales) instead of an empty-box pattern, per the segmented-control shape
  decided during cross-examination.

### Task 4: Gas - nullable fields and engine resolution

DB-level NOT NULL already dropped in Task 3's v303 rebuild for `sacBottom`,
`sacFactor`, `problemSolvingMinutes`, `bestMixEndMeters` - only the Drift
Table's own `.nullable()` declaration is still needed here (mechanical,
like the Task 3 dive_plan_tables.dart edit). `sacDeco`/`sacStressed` were
already nullable at every layer before this issue.

- [ ] Write tests for `sacBottom`, `sacDeco`, `sacStressed`/
      `sacStressedFactor`, `sacFactor`, `problemSolvingMinutes`,
      `bestMixEndMeters` (unset resolves to Settings, including the
      `sacFactor`/`bestMixEndMeters` cases that already route through
      `buddyFactor`/`bestMixEndMeters` in `resolvedFor`; set value wins).
      Include the independence test from Review focus item 5.
- [ ] Run; FAIL.
- [ ] Make `DivePlan`/`DivePlanState` fields nullable (with matching `clearX`
      flags on both `copyWith`s, per the Task 3 lesson); mark the Drift
      columns `.nullable()`; replace the hardcoded `* 2.5` in
      `sacStressedEffective` with the resolved factor; wire `PlanEngineConfig`.
- [ ] Grep and fix call sites for this field set (expect `plan_gas_options_section.dart`'s
      remaining non-override fields, any pure function reading these off
      `plan` directly); `flutter analyze` on both `lib` and `test`.
- [ ] Run; pass. Commit `refactor(planner): resolve Gas fields from Settings when unset`.

### Task 5: Contingency - nullable fields and resolution

- [ ] Write tests for `deviationDepthDelta`/`deviationTimeMinutes`.
- [ ] Run; FAIL.
- [ ] Make fields nullable; wire resolver.
- [ ] Grep and fix call sites; `flutter analyze`.
- [ ] Run; pass. Commit `refactor(planner): resolve Contingency fields from Settings when unset`.

### Task 6: DPV Team - nullable `DpvMission` fields and resolution

- [ ] Write tests for `batteryReserveFraction`/`walkSpeedMps`: unset
      resolves to Settings; set wins; `defaultCurrent`/`setsTowardDeg`/
      `surfaceSwimLimitM` are unaffected (stay plan-only).
- [ ] Run; FAIL.
- [ ] Make the two fields nullable on `DpvMission`; find and wire whatever
      resolves `DpvMission` defaults today (mission engine/validator -
      inventory the exact call sites here, not assumed up front).
- [ ] Run; pass. Commit `refactor(planner): resolve DPV team policy fields from Settings when unset`.

### Task 7: Database repository / mapper for now-nullable columns

- [ ] Write repository round-trip tests covering every field touched in
      Tasks 3-6: saving an unset field persists `NULL`; loading gives
      `null`.
- [ ] Run; FAIL.
- [ ] Update `dive_plan_tables.dart` / mission row tables to nullable
      columns and the corresponding mappers/repositories.
- [ ] Run; pass. Commit `feat(planner): persist unset Setup fields as null`.

### Task 8: Setup accordion - Deco/Rates UI

- [ ] Write/update widget tests for `plan_rates_section.dart` (all five
      rates become override-capable) and `plan_deco_section.dart`
      (`PlanLastStopSelector` "Default" segment, per the UI decision above).
- [ ] Run; FAIL.
- [ ] Implement.
- [ ] Run; pass. Commit `feat(planner): Deco/Rates Setup fields show and reset Settings overrides`.

### Task 9: Setup accordion - Gas UI (including new `sacStressed` field)

- [ ] Write/update widget tests for `plan_gas_options_section.dart`: existing
      override fields' hint sourced from Settings; new `sacStressed` field
      added with the same pattern.
- [ ] Run; FAIL.
- [ ] Implement.
- [ ] Run; pass. Commit `feat(planner): Gas Setup fields show and reset Settings overrides`.

### Task 10: Setup accordion - Contingency UI

- [ ] Write/update widget tests for `contingency_settings_section.dart`.
- [ ] Run; FAIL.
- [ ] Implement.
- [ ] Run; pass. Commit `feat(planner): Contingency Setup fields show and reset Settings overrides`.

### Task 11: CCR setpoint UI retrofit

- [ ] Write/update widget tests for `ccr_settings_section.dart` on the
      `PlanNumberField` pattern: unset shows the Settings hint; set shows
      the override; clearing resets. Replace the old `_followSettings`-based
      tests.
- [ ] Run; FAIL.
- [ ] Rewrite the section; delete the hand-rolled controllers/`ref.listen`
      sync code.
- [ ] Run; pass. Commit `refactor(planner): CCR setpoints show and reset Settings overrides`.

### Task 12: DPV Team UI

- [ ] Write/update widget tests for `mission_team_section.dart`'s battery
      reserve and walk speed fields.
- [ ] Run; FAIL.
- [ ] Implement.
- [ ] Run; pass. Commit `feat(planner): DPV team policy fields show and reset Settings overrides`.

### Task 13: Decompression sub-page field groups

- [ ] Write widget tests for the new Rates/Gas/Contingency/DPV-Team-policy
      groups on `decompression_settings_page.dart`: render current Settings
      values; editing writes back through the Task 2 providers.
- [ ] Run; FAIL.
- [ ] Add the groups (new ARB keys in `en`, translate into all 10 other
      locales, `flutter gen-l10n` last - same flow as the Safety hub work).
- [ ] Run; pass. Commit `feat(settings): planner defaults in Decompression settings`.

### Task 14: Full-suite pass

- [ ] `flutter analyze`.
- [ ] `dart format .`.
- [ ] Full sharded test suite (per the repo's coverage workflow, not a
      single unsharded run).
- [ ] Patch coverage check against `codecov.yml`'s 80% target before
      pushing.
- [ ] Commit any formatting-only fallout separately if `dart format .`
      touches files beyond this PR's own changes.

## Left to the builder

- Exact new column names (suggested above, not final).
- Exact wording/icon for the `lastStopDepth` "Default" segment.
- Exact mission-engine call sites that need `batteryReserveFraction`/
  `walkSpeedMps` resolution (Task 6).
- Exact grouping/ordering of the new field groups within the Decompression
  sub-page.
- Whether any Task's diff is still too large for one commit once the real
  call-site count is known; split further rather than force a single large
  commit, per the instruction to keep commits small.
