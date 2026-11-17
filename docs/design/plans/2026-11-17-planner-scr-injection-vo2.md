# Planner SCR injection rate and VO2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (native, in one session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver set the SCR injection rate, SCR VO2 and pSCR VO2 per plan, with diver defaults, and stop a CMF loop with no valid steady state from planning silently on the supply mix.

**Architecture:** Three nullable `dive_plans` columns plus three defaulted `diver_settings` columns, merged by `PlanEngineConfig.resolvedFor` exactly as the CCR setpoints and SAC are. A pure `scrFlowIssues` check raises a critical issue. UI mirrors `CcrSettingsSection` (plan) and `PlannerGasDefaultsSection.rmvTile` (Settings).

**Tech Stack:** Flutter, Riverpod, Drift (schema v374), ARB l10n (11 locales).

**Spec:** `docs/design/specs/2026-11-17-planner-scr-injection-vo2-design.md`

## Global Constraints

- All three values are stored in surface L/min. Defaults: SCR injection 12.0, SCR VO2 1.3, pSCR VO2 0.72.
- An SCR plan with nothing entered computes exactly as today.
- Display in the diver's volume unit per minute: suffix `units.rmvSymbol`, convert with `units.convertRmv` / `units.volumeToLiters`. Injection rate decimals `units.rmvDecimals`; VO2 decimals `units.rmvDecimals + 1`.
- Migrations add columns only; no backfill. `minimumCompatibleSchemaVersion` does not move.
- No em-dashes anywhere; new l10n keys are translated in every locale ARB (ar, de, en, es, fr, he, hu, it, nl, pt, zh), inserted beside a neighbouring key of the same group, then `flutter gen-l10n`.
- Local test runs: only the test files a task names, by path, at most 15; never a folder.

## Review Focus

1. A lean supply where rate > VO2 but rate x FO2 < VO2 (4 L/min EAN32, VO2 1.3) must raise `scrFlowTooLow`, not plan on the supply mix. Test in Task 5.
2. An imperial diver retyping the VO2 hint must get back 1.3 L/min within 0.01, not 1.42. Test in Task 6.
3. Clearing a plan field must fall back to the diver default (null stored), not save 0. Test in Task 6.
4. A pSCR plan's loop drop follows the plan's own `sacBottom` override, not only the diver default. Test in Task 4.
5. An OC bailout segment inside an SCR plan must not raise `scrFlowTooLow` for the bailout gas. Test in Task 5.

---

### Task 1: Schema v374

**Files:**
- Modify: `lib/core/database/tables/dive_plan_tables.dart` (beside `setpointSwitchDepth`)
- Modify: `lib/core/database/tables/diver_tables.dart` (beside `plannerWalkSpeedMps`)
- Create: `lib/core/database/migrations/helpers/scr_flow_migrations.dart`
- Modify: `lib/core/database/migrations/app_database_migrations.dart` (part directive)
- Modify: `lib/core/database/migrations/ladder/rungs_v340_onward.dart` (rung 374)
- Modify: `lib/core/database/database.dart` (`currentSchemaVersion = 374`, append 374 to `migrationVersions` with a comment)
- Modify: `lib/core/database/migrations/before_open_settings_columns.dart` (backstop call)
- Test: `test/core/database/migration_v374_scr_flow_test.dart`

**Interfaces:**
- Produces: Drift columns `DivePlans.scrInjectionRate`, `DivePlans.scrVo2`, `DivePlans.pscrVo2` (nullable real, doc comment "Null = use the diver's Settings default (issue #4660)."); `DiverSettings.plannerScrInjectionRate` (default 12.0), `plannerScrVo2` (1.3), `plannerPscrVo2` (0.72), non-null real.
- Produces: `extension ScrFlowMigrations on AppDatabase { Future<void> _assertScrFlowColumns(); }` using `_addColumnIfMissing` for `dive_plans.scr_injection_rate REAL`, `dive_plans.scr_vo2 REAL`, `dive_plans.pscr_vo2 REAL`, `diver_settings.planner_scr_injection_rate REAL NOT NULL DEFAULT 12.0`, `planner_scr_vo2 REAL NOT NULL DEFAULT 1.3`, `planner_pscr_vo2 REAL NOT NULL DEFAULT 0.72`.

- [ ] **Step 1: Write the failing migration test**, modelled on `migration_v370_buoyancy_default_test.dart`: a v373 database with minimal `dive_plans (id)` and `diver_settings (id, diver_id)` tables and one row each. Tests: `'v374 is in the ladder'` (`migrationVersions` contains 374); `'the floor does not move'` (`minimumCompatibleSchemaVersion < 374`); `'upgrading adds empty plan columns'` (the three plan columns read null); `'upgrading defaults the diver columns'` (12.0, 1.3, 0.72); `'an existing value is kept'` (a v373 db already carrying `planner_scr_vo2 = 2.0` keeps 2.0).
- [ ] **Step 2: Run** `flutter test test/core/database/migration_v374_scr_flow_test.dart`. Expected: FAIL (374 not in ladder).
- [ ] **Step 3: Implement** the columns, helper, part directive, rung (`if (from < 374) await _assertScrFlowColumns(); if (from < 374) await reportProgress();` with a comment naming #4660, "Column only, no backfill, so the floor does not move; re-asserted in beforeOpen"), version bump and backstop. Run `dart run build_runner build --delete-conflicting-outputs` (unfiltered, in the background).
- [ ] **Step 4: Run** the migration test plus `test/core/database/fresh_schema_declared_columns_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(planner): store SCR injection rate and VO2 columns (schema v374)`.

### Task 2: Diver defaults in settings

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (`AppSettings` field, constructor default, `copyWith`, setters, providers)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart` (the three places `plannerWalkSpeedMps` is mapped)
- Modify: `lib/features/settings/presentation/conflicts/catalogue/diver_settings_fields.dart`
- Test: `test/features/settings/data/repositories/diver_settings_repository_planner_defaults_test.dart`, `test/features/settings/presentation/providers/planner_defaults_settings_test.dart`

**Interfaces:**
- Consumes: Task 1 columns.
- Produces: `AppSettings.plannerScrInjectionRate` (12.0), `plannerScrVo2` (1.3), `plannerPscrVo2` (0.72), all `double`; `SettingsNotifier.setPlannerScrInjectionRate(double)`, `setPlannerScrVo2(double)`, `setPlannerPscrVo2(double)`; providers `plannerScrInjectionRateProvider`, `plannerScrVo2Provider`, `plannerPscrVo2Provider` (`Provider<double>`, `settingsProvider.select`).
- Conflict fields: `'plannerScrInjectionRate'`, `'plannerScrVo2'`, `'plannerPscrVo2'`, `FieldKind.rmv`, labels from Task 6's l10n keys `plannerCanvas_scr_injectionRate`, `plannerCanvas_scr_vo2`, `plannerCanvas_pscr_vo2` (add those three keys here if Task 6 has not yet).

- [ ] **Step 1: Write failing tests**: repository round trip (save 7.5 / 2.0 / 0.9, reload, equal); a fresh row reads the defaults; notifier setter test per field (set, then `settingsProvider` reflects it) following the walk-speed test's shape.
- [ ] **Step 2: Run** both test files. Expected: FAIL (no such field).
- [ ] **Step 3: Implement** following `plannerWalkSpeedMps` at every site.
- [ ] **Step 4: Run** both test files plus `test/features/settings/presentation/providers/every_setter_waits_for_load_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(settings): diver defaults for SCR injection rate and VO2`.

### Task 3: Plan fields, persistence and editor state

**Files:**
- Modify: `lib/features/planner/domain/entities/dive_plan.dart` (fields, `copyWith` with `clearScrInjectionRate`/`clearScrVo2`/`clearPscrVo2`, `props`)
- Modify: `lib/features/planner/data/repositories/dive_plan_repository.dart` (write and read mapping)
- Modify: `lib/features/planner/data/services/plan_file_codec.dart` (keys `scrInjectionRate`, `scrVo2`, `pscrVo2`)
- Modify: `lib/features/dive_planner/domain/entities/plan_result.dart` (`DivePlanState` fields, `copyWith` clears, `props`)
- Modify: `lib/features/planner/domain/services/dive_plan_state_mapper.dart` (both directions, clear flag when null)
- Modify: `lib/features/dive_planner/presentation/providers/dive_planner_providers.dart` (notifier method)
- Modify: `lib/features/settings/presentation/conflicts/catalogue/people_planning_fields.dart` (three `FieldKind.rmv` entries)
- Test: the existing tests for the repository, codec and mapper (find with `grep -rl setpointSwitchDepth test/features/planner test/features/dive_planner`), plus one notifier test.

**Interfaces:**
- Produces: `DivePlan.scrInjectionRate`, `DivePlan.scrVo2`, `DivePlan.pscrVo2` (`double?`, L/min); the same three on `DivePlanState`.
- Produces: `DivePlanNotifier.updateLoopFlow({double? scrInjectionRate, double? scrVo2, double? pscrVo2, bool clearScrInjectionRate = false, bool clearScrVo2 = false, bool clearPscrVo2 = false})`.

- [ ] **Step 1: Write failing tests**: repository save/load keeps 7.5 / 2.0 / 0.9 and keeps null as null; codec encode/decode round trip with and without values; mapper state to plan to state round trip; notifier `updateLoopFlow(scrVo2: 2.0)` then `updateLoopFlow(clearScrVo2: true)` leaves null.
- [ ] **Step 2: Run** those test files. Expected: FAIL.
- [ ] **Step 3: Implement** following `setpointSwitchDepth` at every site.
- [ ] **Step 4: Run** the same files. Expected: PASS.
- [ ] **Step 5: Commit** `feat(planner): keep SCR injection rate and VO2 on the plan`.

### Task 4: Engine config resolution and pSCR SAC

**Files:**
- Modify: `lib/features/planner/domain/services/plan_engine.dart` (config fields, `copyWith`, `props`, `resolvedFor`, `breathingFor`)
- Modify: `lib/features/planner/data/services/plan_engine_settings.dart`
- Test: `test/features/planner/domain/services/plan_engine_config_value_semantics_test.dart`, `test/features/planner/data/services/plan_engine_settings_test.dart`, create `test/features/planner/plan_engine_loop_flow_test.dart`; re-run `test/features/planner/plan_engine_semi_closed_gas_test.dart`, `plan_engine_scr_test.dart`, `plan_engine_scr_ascent_test.dart`, `test/core/deco/passive_scr_test.dart`.

**Interfaces:**
- Consumes: Task 2 settings, Task 3 plan fields.
- Produces: `PlanEngineConfig.pscrVo2Lpm` (double, default 0.72), replacing `pscrO2ConsumptionMlMin`; `pscrSacMlMin` deleted. `scrInjectionRateLpm` and `scrVo2Lpm` keep their names and defaults.
- `breathingFor` pSCR branch: `o2ConsumptionMlMin: config.pscrVo2Lpm * 1000`, `sacMlMin: config.sacBottom * 1000`.

- [ ] **Step 1: Write failing tests** in `plan_engine_loop_flow_test.dart`:
  - `'an SCR plan breathes the CMF loop for the entered rate and VO2'`: plan mode SCR, EAN50 supply, `scrInjectionRate: 7.5`, `scrVo2: 2.0`; `breathingFor(...)` on the resolved config yields an `Scr` whose inspired fO2 equals `ScrCalculator.calculateCmfSteadyStateFo2(injectionRateLpm: 7.5, supplyO2Percent: 50, vo2: 2.0)` (about 0.318).
  - `'supply gas is charged at the entered rate'`: `resolved.cylinderLiters(PlanMode.scr, sac: 15, minutes: 10, ambientBar: 4)` is 75.0.
  - `'an SCR plan with nothing entered computes as today'`: `PlanEngine(config: const PlanEngineConfig()).compute(plan)` and the same with `planEngineConfigFromSettings(const AppSettings())` give equal runtime and stops.
  - `'pSCR drop uses the entered VO2 and the plan bottom SAC'`: pSCR plan on EAN32, `pscrVo2: 1.0`, plan `sacBottom: 25` (diver default 15); the `PassiveScr` from `breathingFor` has `o2DropBar` equal to that of `PassiveScr(supplyFO2: 0.32, o2ConsumptionMlMin: 1000, sacMlMin: 25000, pscrRatio: config.pscrRatio)`.
  - Settings mapping: `planEngineConfigFromSettings` copies the three settings; `resolvedFor` prefers plan values, falls back when null.
  - Update `plan_engine_config_value_semantics_test.dart`: replace the two pSCR entries with `'pscrVo2Lpm'`.
- [ ] **Step 2: Run** the new file and the two config tests. Expected: FAIL.
- [ ] **Step 3: Implement**.
- [ ] **Step 4: Run** all files listed under Test. Any pSCR test pinned to the old 20 L/min SAC gets its expectation updated with a comment citing #4660 and the spec's decision 2; SCR tests must pass unchanged. Expected: PASS.
- [ ] **Step 5: Commit** `feat(planner): resolve SCR flow and pSCR VO2 from the plan and Settings`.

### Task 5: Flow-too-low guard

**Files:**
- Create: `lib/features/planner/domain/services/scr_flow_check.dart`
- Modify: `lib/features/planner/domain/entities/plan_outcome.dart` (enum value with doc)
- Modify: `lib/features/planner/domain/services/plan_engine.dart` (add `issues.addAll(scrFlowIssues(plan, config))` beside `_modOverrideIssues`, where `config` is the resolved one)
- Modify: `lib/features/planner/presentation/widgets/plan_issue_text.dart`; ARB key `plannerCanvas_issue_scrFlowTooLow`
- Test: create `test/features/planner/domain/services/scr_flow_check_test.dart`

**Interfaces:**
- Produces: `PlanIssueType.scrFlowTooLow` (doc: `[PlanIssue.value]` is the injection rate and `[PlanIssue.threshold]` the least flow that sustains the loop on that supply, both surface L/min; `[PlanIssue.tankId]` the supply).
- Produces: `Iterable<PlanIssue> scrFlowIssues(domain.DivePlan plan, PlanEngineConfig config)`: for each segment with `modeFor(plan, segment) == PlanMode.scr`, distinct by `tankId`, when `ScrCalculator.calculateCmfSteadyStateFo2(injectionRateLpm: config.scrInjectionRateLpm, supplyO2Percent: segment.gasMix.o2, vo2: config.scrVo2Lpm)` is null, one `PlanIssue(type: scrFlowTooLow, severity: critical, tankId, value: rate, threshold: max(vo2, vo2 / fO2))`.
- Message `plannerCanvas_issue_scrFlowTooLow(rate, gas, needed)`: "{rate} is too little flow for {gas}: the loop needs more than {needed} at this VO2." Rate and needed formatted with `units.formatRmv`; gas name from the tank's mix as other issue texts name it.

- [ ] **Step 1: Write failing tests**: `'flow at or below VO2 raises the issue'` (rate 1.3, VO2 1.3, EAN50); `'flow too lean for the supply raises it'` (rate 4.0, VO2 1.3, EAN32; threshold about 4.06); `'a sustainable flow raises nothing'` (12.0, 1.3, EAN50); `'one issue per supply tank'` (two segments on one tank); `'an OC bailout segment is not checked'` (SCR plan, one segment with `diveModeOverride: PlanMode.oc` on EAN21 at rate 4.0, VO2 1.3: no issue); `'a non-SCR plan raises nothing'`; and one `PlanEngine.compute` test that the issue appears in `outcome.issues` as critical.
- [ ] **Step 2: Run** the test file. Expected: FAIL.
- [ ] **Step 3: Implement**, add the ARB key in all locales, `flutter gen-l10n`.
- [ ] **Step 4: Run** the test file and `test/features/planner/plan_engine_scr_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(planner): flag an SCR flow too low to sustain the loop`.

### Task 6: Planner Setup sections

**Files:**
- Create: `lib/features/planner/presentation/widgets/scr_settings_section.dart`
- Create: `lib/features/planner/presentation/widgets/loop_flow_summary.dart`
- Modify: `lib/features/planner/presentation/widgets/pscr_settings_section.dart` (VO2 field plus drop line)
- Modify: `lib/features/planner/presentation/panes/plan_setup_accordion.dart` (`if (mode == domain.PlanMode.scr) ('scr', 'SCR', const ScrSettingsSection())` before the pSCR entry)
- Modify: `lib/features/planner/presentation/info/plan_setup_info.dart`, `lib/shared/widgets/info_sheet/dive_terms.dart` (injection rate and VO2 entries; respect the info-sheet two-sentence cap)
- ARB keys: `plannerCanvas_scr_injectionRate`, `plannerCanvas_scr_vo2`, `plannerCanvas_pscr_vo2`, `plannerCanvas_scr_loopSummary(atVo2, resting, hardWork, gas)`, `plannerCanvas_scr_flowTooLow`, `plannerCanvas_pscr_dropSummary(drop)`
- Test: create `test/features/planner/presentation/widgets/scr_settings_section_test.dart`, `loop_flow_summary_test.dart`; extend the existing pSCR section test.

**Interfaces:**
- Consumes: Task 2 providers, Task 3 `updateLoopFlow`, Task 4 `PlanEngineConfig` (read `planEngineConfigProvider` then `.resolvedFor(plan)` for the summary).
- Produces: `class ScrSettingsSection extends ConsumerWidget`; `class LoopFlowSummary extends StatelessWidget { const LoopFlowSummary({required double injectionRateLpm, required double vo2Lpm, required GasMix supply}); }`.
- `ScrSettingsSection` lays out like `CcrSettingsSection` (two `PlanNumberField`s, stack under 360 px): value `units.convertRmv(state.scrInjectionRate)`, hint `units.convertRmv(diverDefault)`, `suffixText: units.rmvSymbol`, `min: units.convertRmv(0.1)`, `onChanged: (v) => notifier.updateLoopFlow(scrInjectionRate: v == null ? null : units.volumeToLiters(v), clearScrInjectionRate: v == null)`; same for VO2 with `decimals: units.rmvDecimals + 1`. Under them a `LoopFlowSummary` on the plan's supply (first `TankRole.diluent` tank's mix, else the first segment's).
- `LoopFlowSummary` shows loop O2 percent at the given VO2, at `ScrCalculator.restingVo2` and at `ScrCalculator.hardWorkVo2`; a null result shows `plannerCanvas_scr_flowTooLow` in that slot.
- pSCR section: VO2 `PlanNumberField` beside the ratio; under it `plannerCanvas_pscr_dropSummary` with `PassiveScr(...).o2DropBar` built from the resolved config (formatted 2 decimals, bar).

- [ ] **Step 1: Write failing widget tests**: SCR section shows only in SCR mode; empty fields show the diver defaults as hints in L/min, and in cuft/min for an imperial diver; typing 7.5 stores 7.5; clearing stores null; an imperial diver typing the VO2 hint's text back stores 1.3 within 0.01; `LoopFlowSummary` on EAN50 at 12 / 1.3 shows 44%, resting 46%, hard work 39% (compute expected values from `ScrCalculator` in the test, rounded as displayed); at rate 2.0 the hard-work slot shows the flow-too-low text; pSCR VO2 field stores and clears.
- [ ] **Step 2: Run** the test files. Expected: FAIL.
- [ ] **Step 3: Implement**, translate keys in every locale, `flutter gen-l10n`.
- [ ] **Step 4: Run** the test files. Expected: PASS.
- [ ] **Step 5: Commit** `feat(planner): enter SCR injection rate and VO2 in plan Setup`.

### Task 7: Settings Rebreather card

**Files:**
- Create: `lib/features/settings/presentation/widgets/planner_rebreather_defaults_section.dart`
- Modify: `lib/features/settings/presentation/pages/planner_defaults_settings_page.dart` (card after the gas card, with a section header key `settings_plannerDefaults_rebreather`)
- Test: create `test/features/settings/presentation/widgets/planner_rebreather_defaults_section_test.dart`

**Interfaces:**
- Consumes: Task 2 setters; `PlannerDefaultTile`.
- Produces: `class PlannerRebreatherDefaultsSection extends ConsumerWidget`, three tiles built like `PlannerGasDefaultsSection.rmvTile` (valueText `units.formatRmv`, VO2 tiles use `rmvDecimals + 1` for value text and initial value), saving `units.volumeToLiters(entered)`.

- [ ] **Step 1: Write failing tests**: tiles show 12.0 / 1.30 / 0.72 L/min; an imperial diver sees cuft/min; saving 7.5 calls `setPlannerScrInjectionRate(7.5)`.
- [ ] **Step 2: Run**. Expected: FAIL.
- [ ] **Step 3: Implement**; ARB key in all locales; `flutter gen-l10n`.
- [ ] **Step 4: Run** the new test and `test/features/settings/presentation/pages/settings_page_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(settings): SCR and pSCR defaults on the planner defaults page`.

### Task 8: Logging a plan carries the loop values

**Files:**
- Modify: `lib/features/planner/presentation/providers/planned_log_entry.dart`
- Test: its existing test file (find with `grep -rl planned_log_entry test`)

**Interfaces:**
- Consumes: Task 4 resolved config (the entry is built where the outcome is computed; pass the resolved `PlanEngineConfig` in, or the three resolved values).
- Produces: logged `Dive.scrType` (`ScrType.cmf` for SCR, `ScrType.pascr` for pSCR, null otherwise), `scrInjectionRate` (SCR only), `assumedVo2` (SCR VO2 or pSCR VO2); `matches` compares the same three.

- [ ] **Step 1: Write failing tests**: an SCR plan with rate 7.5 logs scrType cmf, 7.5 and its VO2; an SCR plan with nothing entered logs 12.0 and 1.3; a pSCR plan logs pascr, null rate, 0.72; an OC plan logs nulls; `matches` is false after the plan's VO2 changes.
- [ ] **Step 2: Run**. Expected: FAIL.
- [ ] **Step 3: Implement**.
- [ ] **Step 4: Run**. Expected: PASS.
- [ ] **Step 5: Commit** `feat(planner): a logged SCR plan keeps its injection rate and VO2`.

### Task 9: Dive Lab falls back to the diver defaults

**Files:**
- Modify: `lib/features/dive_lab/domain/entities/scenario_settings.dart` (fields `defaultScrInjectionRateLpm` 12.0, `defaultScrVo2Lpm` 1.3, in constructor, `copyWith`, `props`; `engineConfigFor` falls back to them)
- Modify: `lib/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart` (fill from `engineConfig.scrInjectionRateLpm` / `scrVo2Lpm`)
- Test: the existing `scenario_settings` test and the lab inputs provider test (find with `grep -rl engineConfigFor test`)

- [ ] **Step 1: Write failing tests**: `ScenarioSettings(defaultScrInjectionRateLpm: 7.5).engineConfigFor()` has rate 7.5; a dive value still wins; the provider passes the diver's settings through.
- [ ] **Step 2: Run**. Expected: FAIL.
- [ ] **Step 3: Implement**.
- [ ] **Step 4: Run**. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-lab): replay an SCR dive with the diver's SCR defaults`.

### Task 10: Agent access

**Files:**
- Modify: `lib/features/agent_access/data/documents/plan_documents.dart` (`scr_injection_rate_l_min`, `scr_vo2_l_min`, `pscr_vo2_l_min`)
- Modify: `lib/features/agent_access/data/writes/families/dive_plan_fields.dart` (`number(...)` / `clears(...)` for the three, positive)
- Modify: `lib/features/agent_access/data/planning/plan_result_document.dart` (in the SCR branch `own(plan.scrInjectionRate, config.scrInjectionRateLpm)` and `own(plan.scrVo2, config.scrVo2Lpm)`; in the pSCR branch `own(plan.pscrVo2, config.pscrVo2Lpm)`)
- Regenerate: `lib/features/agent_access/data/resources/sql_column_notes.generated.dart` (find its generator with `grep -rl sql_column_notes scripts tool`)
- Test: the existing tests for each file (find with `grep -rl "setpoint_low_bar\|sac_bottom_l_min" test/features/agent_access`)

- [ ] **Step 1: Write failing tests**: a plan document carries the three keys; a write of `scr_vo2_l_min: 2.0` stores 2.0 and `null` clears it; a negative value is refused; the result document for an SCR plan reports the rate with source plan or settings.
- [ ] **Step 2: Run**. Expected: FAIL.
- [ ] **Step 3: Implement** and regenerate the column notes.
- [ ] **Step 4: Run**. Expected: PASS.
- [ ] **Step 5: Commit** `feat(agent-access): read and write a plan's SCR flow and VO2`.

### Task 11: Finish

- [ ] **Step 1:** `dart format .` and `flutter analyze` (whole repo). Expected: no issues.
- [ ] **Step 2:** After screenshots of the SCR Setup section, the pSCR section and the Settings Rebreather card (light, plus an imperial diver), per the build-feature Screenshots section.
