# Diver-wide default for the CCR setpoint switch depth

Issue: #3793

## Problem

A CCR plan breathes the high setpoint deeper than its setpoint switch depth
and the low setpoint shallower. Setpoint low and high have diver-wide defaults
in Settings > Decompression > "ppO2 limits CCR" (issue #2342) that the planner
resolves through `PlanEngineConfig.setpointLowFor` / `setpointHighFor` (issue
#2801). The switch depth has none: an unset plan value falls back to a
hardcoded 10 m in `DivePlan.effectiveSetpointSwitchDepth`, and the planner's
CCR field shows a hardcoded 10 m hint.

Since the issue was filed, `splitAtSetpointSwitch` (#4009, PR #4045) also
reads the switch depth, to cut a leg where the loop changes setpoint. It takes
only the plan, so a default resolved anywhere else would make the cut and the
setpoint change disagree.

The planner also copies the Settings setpoints into a plan when it enters CCR
mode (`DivePlanNotifier.updateMode`), so a plan never follows a later
Settings change, the known limitation documented on that method.

## Scope

- A diver-wide switch depth default in Settings.
- The planner's CCR section gets the Setup accordion's Default/Custom
  pattern (`PlanHypercapniaControl`, `PlanPpO2BandsControl`) for each of
  setpoint low, setpoint high and switch depth, and an Off choice for the
  switch depth: no switch by depth.
- Out of scope (dive computers such as the Shearwater Petrel 3 or Divesoft
  Liberty offer these, but they change the plan model): separate descent and
  ascent switch depths, a time-based switch, descent or deco setpoints. The
  Dive Lab still takes setpoint low/high from the logged dive only.

## Design

### Setting

- New `diver_settings.ccr_setpoint_switch_depth` (REAL NOT NULL DEFAULT 10.0),
  schema v384, additive: rung in `rungs_v340_onward.dart`, re-asserted in
  `before_open_settings_columns.dart`, `migrationVersions` entry, the floor
  does not move. Seeded in `SyncDataSerializer`'s diver-settings fallback so a
  payload predating the column hydrates.
- `AppSettings.ccrSetpointSwitchDepth` (meters, default 10.0), read and written
  by `DiverSettingsRepository` like `ccrSetpointLow/High`, listed in the
  conflict catalogue (`diver_settings_fields.dart`, `FieldKind.depth`).
- `SettingsNotifier.setCcrPpO2Limits` gains `setpointSwitchDepth`, written in
  the same single update as the setpoints. Stored as entered within
  `ccrSwitchDepthInputMin`..`ccrSwitchDepthInputMax` (0..100 m), rounded to
  0.1 m. The slider covers `ccrSwitchDepthSliderMin`..`ccrSwitchDepthSliderMax`
  (3..30 m, 1 m steps); a value outside it is typed into the number field.
- `ccrSetpointSwitchDepthProvider`, a `select` on `settingsProvider`.

### Plan model

- New `dive_plans.setpoint_switch_off` (BOOLEAN NOT NULL DEFAULT 0), same
  v384 rung and backstop. `DivePlan.setpointSwitchOff`, carried through
  `copyWith`, `props`, `DivePlanState`, `dive_plan_state_mapper.dart`, the
  repository, `plan_file_codec.dart` (written only when true, read as false
  when absent), the agent plan document and write family
  (`setpoint_switch_off`), and the people/planning conflict catalogue.
- Off wins over a stored `setpointSwitchDepth`, which is kept so switching
  back to Custom restores it (as `airBreaksExplicitlyOff` does).

### Resolution

- `DivePlan.effectiveSetpointSwitchDepth` is removed and replaced by
  `DivePlan.specSetpointSwitchDepth = 10.0`, the last-resort constant, with the
  same reasoning as `specSetpointLow/High`: no getter on the plan may skip the
  Settings.
- `PlanEngineConfig.ccrSetpointSwitchDepth` (default the spec constant), in
  the constructor, `props`, `copyWith` (so `resolvedFor` carries it), filled
  from Settings in `plan_engine_settings.dart`.
- `PlanEngineConfig.setpointSwitchDepthFor(plan)`: `double.infinity` when
  `plan.setpointSwitchOff`, else `plan.setpointSwitchDepth ??
  ccrSetpointSwitchDepth`. Infinity keeps every reader correct without a
  special case: no depth is deeper, so the low setpoint applies throughout and
  no leg crosses it. Per-segment setpoints still win. Documents and the UI
  never show the infinity; they report Off.
- Every reader moves to it: `setpointAt` and the ascent loop in
  `plan_engine.dart`, `scenario_engine.dart`, and the assert in
  `counterfactual_profile_synthesizer.dart`.
- `splitAtSetpointSwitch(plan, segment, stretch, {required double
  switchDepth})`: callers pass the resolved depth (`plan_engine.dart`,
  `bailout_solver.dart`, `counterfactual_profile_synthesizer.dart`).
- Dive Lab: `ScenarioSettings` builds its own `PlanEngineConfig`, so it gains
  `ccrSetpointSwitchDepth`, filled from `planEngineConfigProvider` in
  `lab_request_inputs_provider.dart` and passed in `engineConfigFor`.
- The agent plan-result document reports the resolved switch depth (null when
  Off) next to `setpoint_low_bar` / `setpoint_high_bar`.

### Planner CCR section

- Three controls in the CCR section, each `PlanChoiceWrap` based like
  `PlanHypercapniaControl`:
  - Setpoint low: Default (Settings value as read-only text) / Custom
    (number field, prefilled with the Settings value).
  - Setpoint high: the same.
  - Switch depth: Default / Off / Custom, in the diver's depth unit; Custom
    accepts any value from 0 m.
- Default clears the plan's value, Custom writes one.
- `updateMode` no longer copies the Settings setpoints into the plan, so an
  unset plan follows Settings; its known-limitation note goes.
  Saved plans that already carry copied setpoints show Custom.
- `planned_log_entry.dart` read the copied setpoints straight from the plan
  state when it logs a plan as a planned dive. It now takes them resolved
  (`setpointLowFor` / `setpointHighFor` on `planEngineConfigProvider`), so a
  CCR plan following Settings still logs its setpoints, and its "unchanged"
  check compares the same resolved values.

### Settings UI

- `CcrPpO2LimitDialog` gains a "Setpoint switch depth" row below the
  setpoints: a 3..30 m slider in 1 m steps and a number field in the diver's
  depth unit that also takes 0..100 m. The grid stays in meters, as in
  `PpO2DecoBandsDialog`. A value outside the slider pins the thumb at that
  end. Hint: "High setpoint below, low setpoint above".
- The tile subtitle moves to a new string with the depth in the diver's unit.
- New strings in every ARB locale.

## Behaviour change

- A saved plan with no switch depth of its own follows the diver's Settings,
  as unset setpoints already do. With the default left at 10 m nothing
  changes.
- A new CCR plan no longer stores the Settings setpoints; it follows them.

## Tests

- Migration v384: both columns added at their defaults, existing values kept.
- Sync fallback: a payload without the field hydrates to 10.0.
- Notifier: input range, rounding, single write; repository round trip.
- `PlanEngineConfig`: equality includes the field, `resolvedFor` keeps it,
  plan value wins over Settings, Off resolves to no switch.
- Engine: with Settings at 6 m and no plan value, the setpoint changes and the
  leg is cut at 6 m; with Off, the low setpoint holds throughout and no leg is
  cut; planner and Dive Lab agree.
- Plan round trips: repository, file codec and state mapper keep Off.
- Planner notifier: entering CCR leaves the setpoints unset.
- Planned log entry: a CCR plan with unset setpoints logs the Settings values.
- Widgets: each control's Default/Custom (and Off) choice writes the right
  plan state; the dialog saves meters from slider and field, shows the
  diver's unit; the subtitle shows the depth.
