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

## Scope

One symmetric switch depth, as today, with a diver-wide default. Out of scope
(dive computers such as the Shearwater Petrel 3 or Divesoft Liberty offer
these, but they change the plan model): separate descent and ascent switch
depths, a time-based switch, descent or deco setpoints.

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
- `SettingsNotifier.setCcrPpO2Limits` gains `setpointSwitchDepth`, clamped to
  `ccrSwitchDepthMin`..`ccrSwitchDepthMax` (3..30 m) and snapped to a 1 m
  grid, written in the same single update as the setpoints.
- `ccrSetpointSwitchDepthProvider`, a `select` on `settingsProvider`.

### Resolution

- `DivePlan.effectiveSetpointSwitchDepth` is removed and replaced by
  `DivePlan.specSetpointSwitchDepth = 10.0`, the last-resort constant, with the
  same reasoning as `specSetpointLow/High`: no getter on the plan may skip the
  Settings.
- `PlanEngineConfig.ccrSetpointSwitchDepth` (default the spec constant), in
  the constructor, `props`, `copyWith` (so `resolvedFor` carries it), filled
  from Settings in `plan_engine_settings.dart`.
- `PlanEngineConfig.setpointSwitchDepthFor(plan)` =
  `plan.setpointSwitchDepth ?? ccrSetpointSwitchDepth`.
- Every reader moves to it: `setpointAt` and the ascent loop in
  `plan_engine.dart`, `scenario_engine.dart`, and the assert in
  `counterfactual_profile_synthesizer.dart` (which must compare against the
  same value the loop got).
- `splitAtSetpointSwitch(plan, segment, stretch, {required double
  switchDepth})`: callers pass the resolved depth (`plan_engine.dart`,
  `bailout_solver.dart`, `counterfactual_profile_synthesizer.dart`).
- The agent plan-result document reports the resolved switch depth next to
  `setpoint_low_bar` / `setpoint_high_bar`.

### Planner

- Entering CCR mode seeds `setpointSwitchDepth` from Settings when unset, the
  same way `updateMode` already seeds setpoint low/high
  (`getDefaultCcrSetpoints` gains the depth). Plans built elsewhere (agent,
  file import, Dive Lab) and saved plans with no value resolve through the
  config.
- The CCR section's switch depth hint shows the Settings value in the diver's
  depth unit instead of 10 m.

### Settings UI

- `CcrPpO2LimitDialog` gains a depth slider below the setpoints: 3..30 m in
  1 m steps, the grid kept in meters and the text in the diver's depth unit,
  as in `PpO2DecoBandsDialog`. Label "Setpoint switch depth", hint "High
  setpoint below, low setpoint above".
- The tile subtitle adds the depth in the diver's unit.
- New strings in every ARB locale.

## Behaviour change

A saved plan with no switch depth of its own follows the diver's Settings
after the update, as unset setpoints already do. With the default left at
10 m nothing changes.

## Tests

- Migration v384: added at 10.0 from v383, existing value kept.
- Sync fallback: a payload without the field hydrates to 10.0.
- Notifier: clamp, grid, single write; repository round trip.
- `PlanEngineConfig`: equality includes the field, `resolvedFor` keeps it,
  plan value wins over Settings.
- Engine: with Settings at 6 m and no plan value, the setpoint changes and the
  leg is cut at 6 m; planner and Dive Lab agree.
- Planner notifier: entering CCR seeds the depth; a set depth is kept.
- Widgets: dialog slider saves meters, shows the diver's unit; CCR section
  hint follows Settings.
