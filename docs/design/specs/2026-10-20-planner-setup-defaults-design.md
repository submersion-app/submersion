# Planner setup defaults: resolve Setup accordion fields from the diver's Settings

Issue: #3552. Release: TBD.

## Intent

The planner's Setup accordion (Deco, Rates, Gas, Environment, Contingency,
CCR/PSCR, DPV Team) holds fields that today only exist on the plan itself:
every new plan starts from hardcoded constructor defaults on `DivePlan`, with
no connection to anything the diver has configured globally. A few fields
(gradient factors, reserve pressure, water type, ppO2 limits, O2-narcotic,
CCR setpoints) already have some form of global counterpart; most do not.

The goal: every Setup field a new plan starts with comes from the diver's
Settings, and changing it inside one plan never touches the global default -
exactly the relationship gradient factors already have, but applied
consistently and with the mechanism below rather than the older one.

## Goals

- Every `DivePlan` field exposed in the Setup accordion that has no global
  source today gets one, stored as a new `DiverSettings` column (no new
  table).
- A new plan's Setup fields resolve from the diver's current Settings at the
  moment the plan is computed, not copied once at creation.
- Editing a field inside a plan overrides only that plan; the global default
  is unaffected.
- The Setup accordion visibly marks a field that has been overridden inside
  the plan, distinct from one still following the diver's Settings - the
  diver must be able to tell the two states apart at a glance, not just
  infer it from the number happening to differ. Clearing an override is a
  visible, explicit action (not something that happens by typing the same
  value back in).
- If the diver changes a global default later, every plan that has not
  locally overridden that field - including an already-saved, long-untouched
  one - picks up the new value the next time it is computed. (Decided
  explicitly: this is the opposite of how gradient factors behave today; see
  "Two existing patterns" below.)
- No new Settings UI location: the existing Settings > Safety > Decompression
  sub-page (`docs/design/plans/2026-10-16-safety-settings-hub.md`) is extended
  with the missing field groups, rather than adding a new entry under
  "Einstellungen verwalten" / Settings > Manage.
- All Setup sections get this treatment: Deco, Rates, Gas, Environment,
  Contingency, CCR, PSCR, DPV Team - not just the ones that already have a
  partial global source.

## Non-goals

- Gradient factors, reserve pressure, and water type keep their existing
  snapshot-on-create + pristine-sync mechanism
  (`adoptGradientFactorsIfPristine`, `adoptPlannerWaterIfPristine` in
  `lib/features/dive_planner/presentation/providers/dive_planner_providers.dart`).
  Retrofitting them onto the mechanism below is separate work, out of scope
  here; see "Two existing patterns" for why this leaves a visible
  inconsistency.
- No change to any field's default *value* (15 L/min SAC, 18 m/min descent,
  etc.) - only to where that value is sourced from for a new, unedited plan.
- No change to `PlanEngineConfig` fields that have no corresponding
  `DivePlan` field and are not surfaced in the Setup accordion at all
  (`otuLimit`, `o2MetabolicRateLpm`, `loopVolumeLiters`, `scrInjectionRateLpm`,
  `pscrO2ConsumptionMlMin`, `pscrSacMlMin`). These stay app-wide constants.
- No new top-level Settings section or route.
- `PscrSettingsSection`'s `pscrRatio` is already purely global with no
  per-plan override field; untouched by this work.
- Mission-specific DPV Team fields (`defaultCurrent`, `setsTowardDeg`,
  `surfaceSwimLimitM`) get no global default - they describe this dive, not
  a diver policy, the same reasoning that excludes `altitude`/`startDateTime`.

## Anti-goals

- A field the diver has explicitly overridden inside a plan must never be
  silently reset to the (possibly since-changed) global default. "Live
  resolve" means an *unset* field tracks Settings; a *set* field never does,
  persisted or not.
- The Decompression sub-page must not grow a second, divergent resolution
  order from the one `PlanEngineConfig`/`setpointAt` already use (segment
  override > plan override > diver's Settings > spec constant last resort).
  New fields follow the same order.
- `stopMinimums` (the per-depth stop-time map) gets no global default - it is
  diver-authored content for one plan, not a policy setting, and stays
  plan-only.
- After this work, CCR setpoints must not remain the one field group that is
  live-resolved but shows no visible override state - see "CCR / PSCR / DPV
  Team" below.

## Two existing patterns (why this matters)

The codebase already has two different mechanisms for "a plan falls back to
something global," and they behave differently once a plan is saved:

- **Snapshot-on-create** (`gfLow`/`gfHigh`, `reservePressure`, `waterType`/
  `salinityPpt`): non-nullable `DivePlan` fields. `_createInitialState()` (
  `dive_planner_providers.dart`) copies the diver's current Settings value in
  at creation. `adoptGradientFactorsIfPristine()` /
  `adoptPlannerWaterIfPristine()` keep an *unsaved, untouched* draft synced if
  Settings change while the planner is open, but once the plan is persisted
  (or the diver has touched the field), the copied value is frozen forever -
  a later Settings change never reaches that plan again.
- **Live-resolve** (`ppO2Bottom`, `ppO2Deco`, `o2Narcotic`, `setpointLow`,
  `setpointHigh`): nullable `DivePlan` fields. `null` means "use the diver's
  Settings"; a set value always wins. `PlanEngineConfig.resolvedFor(plan)`
  (`lib/features/planner/domain/services/plan_engine.dart`) merges the
  plan's overrides onto the app-wide config built fresh from Settings on
  every computation (`planEngineConfigProvider`,
  `plan_canvas_providers.dart`). This was a deliberate choice (issue #2801):
  the code comment on `DivePlan.specSetpointLow`/`specSetpointHigh` explains
  that a getter falling back directly to a spec constant was rejected
  specifically because it would skip the diver's Settings.

This spec follows the live-resolve pattern for every field it adds, because
it is the one the codebase has already chosen deliberately (not just the
older, incidental one), and because the "Live-Resolve" answer was chosen
explicitly for this feature over snapshot semantics. The resulting
inconsistency - GF/reserve pressure/water type still snapshot, everything
else live-resolves - is a known, accepted gap; not addressed here.

## The visible-override mechanism already exists - reuse it, don't reinvent it

`PlanNumberField` (`lib/features/dive_planner/presentation/widgets/setup/plan_number_field.dart`)
already supports exactly the required UX, used today for `ppO2Bottom`,
`ppO2Deco`, and `sacDeco`:

- `value: null` + `allowEmpty: true` shows the Settings value as a greyed
  `hintText` (the `hintValue` parameter) - visibly distinct from a typed
  value.
- Emptying the box calls `onChanged(null)`, an explicit act distinct from
  typing the same number back in (which would set a real override equal to
  the default, not clear it).

Every field in scope that is rendered through `PlanNumberField` today in
`allowEmpty: false` mode (all of Rates, and `batteryReserveFraction`/
`walkSpeedMps` in DPV Team) needs that same conversion: `value`/`onChanged`
become nullable, `allowEmpty: true`, `hintValue` sourced from the new
Settings provider instead of the plan's own current value. This is the bulk
of the UI work - not a new shared widget.

Two fields do **not** go through `PlanNumberField` and need their own
treatment:

- `lastStopDepth` is a `PlanLastStopSelector` (a fixed-choice segmented
  control, `plan_deco_section.dart`), not a text field. It gets an
  additional "Default" segment showing the current Settings value in
  parentheses (e.g. "Default (3 m)"); picking a concrete depth is an
  override, picking "Default" clears it.
- CCR setpoints (`ccr_settings_section.dart`) use a hand-rolled
  `TextEditingController` synced via `ref.listen`, with no visible
  override/following distinction at all despite already being live-resolved.
  This section is retrofitted onto the `PlanNumberField` hint-text pattern
  for consistency - otherwise it is the one field group left inconsistent by
  this work.

## Fields in scope and their new global source

All new columns go on `DiverSettings`
(`lib/core/database/tables/diver_tables.dart`), following that table's
existing pattern: one typed column per setting, `withDefault(const
Constant(...))`, covered by the table's `hlc` sync column.

### Already live-resolved today (UI retrofit only, see above)

| `DivePlan` field | Resolves via | `DiverSettings` column |
| --- | --- | --- |
| `ppO2Bottom` | `PlanEngineConfig.ppO2Working` | `ppO2MaxWorking` |
| `ppO2Deco` | `PlanEngineConfig.ppO2Deco` | `ppO2MaxDeco` |
| `o2Narcotic` | `PlanEngineConfig.o2Narcotic` | `o2Narcotic` |
| `setpointLow` | `PlanEngineConfig.setpointLowFor(plan)` | `ccrSetpointLow` |
| `setpointHigh` | `PlanEngineConfig.setpointHighFor(plan)` | `ccrSetpointHigh` |

`ppO2Bottom`/`ppO2Deco`/`sacDeco` already show the override state correctly
(they use `PlanNumberField` today). Only the CCR setpoint fields need UI
work; their resolution logic is unchanged.

### Deco

| `DivePlan` field | Current default | New `DiverSettings` column |
| --- | --- | --- |
| `descentRate` | `18.0` (hardcoded) | `plannerDescentRate` |
| `ascentRate` | `9.0` | `plannerAscentRate` |
| `intermediateAscentRate` | `6.0` | `plannerIntermediateAscentRate` |
| `shallowAscentRate` | `3.0` | `plannerShallowAscentRate` |
| `finalAscentRate` | `1.0` | `plannerFinalAscentRate` |
| `lastStopDepth` | `3.0` | reuse existing `DiverSettings.lastStopDepth` (already present, currently unused by plan creation) |
| `gasSwitchStopSeconds` | `0` | `plannerGasSwitchStopSeconds` |
| `airBreaks` | `null` (no policy) | `plannerAirBreakPolicy` (nullable; `null` = no air breaks, matching today's default) |

`lastStopDepth` is a pre-existing gap worth calling out on its own: the diver
Settings table has carried this column since the Safety work, but no plan
has ever read it. This spec is what finally wires it up.

### Rates / Gas

| `DivePlan` field | Current default | New `DiverSettings` column |
| --- | --- | --- |
| `sacBottom` | `15.0` | `plannerSacBottom` |
| `sacDeco` | `null`, falls back to `15.0` via `sacDecoEffective` getter | `plannerSacDeco`, its own column (decided: no implicit coupling to `plannerSacBottom`) |
| `sacStressed` | `null`, falls back to `sacBottom * 2.5` via `sacStressedEffective` | `plannerSacStressedFactor` (the *factor*, 2.5, not an absolute value). Decided: included even though `sacStressed` has no Setup-accordion UI today - `PlanGasOptionsSection` gains a new field for it as part of this work. |
| `sacFactor` | `2.0` | reuse `PlanEngineConfig.buddyFactor`'s source - today a hardcoded `2.0` constant with no Settings column at all; add `plannerBuddyFactor` |
| `problemSolvingMinutes` | `2` | `plannerProblemSolvingMinutes` |
| `bestMixEndMeters` | `30.0` | `plannerBestMixEndMeters` |

Note: `sacFactor` and `bestMixEndMeters` are currently non-nullable on
`DivePlan`, so `PlanEngineConfig.resolvedFor()` always overwrites
`buddyFactor`/`bestMixEndMeters` with the plan's value - the config's own
defaults for those two fields are effectively dead for any call that goes
through `resolvedFor`. Making them nullable (so a plan can genuinely say "use
the diver's default") changes this: `resolvedFor` must skip the override
when the plan field is `null`, the same way it already does for
`ppO2Bottom`/`ppO2Deco`/`o2Narcotic`.

### Environment

`altitude`, `waterType`/`salinityPpt`, and `startDateTime` are either
genuinely per-dive (altitude, start time - no sensible global default) or
already covered by the existing water-type snapshot mechanism (explicitly
out of scope above). No new columns here.

### Contingency

| `DivePlan` field | Current default | New `DiverSettings` column |
| --- | --- | --- |
| `deviationDepthDelta` | `5.0` | `plannerDeviationDepthDelta` |
| `deviationTimeMinutes` | `5` | `plannerDeviationTimeMinutes` |
| `turnPressureRule` | `null` (no rule) | `plannerTurnPressureRule` (nullable; `null` stays "no rule", matching today) |
| `turnPressureFraction` | `null` | `plannerTurnPressureFraction` |

### CCR / PSCR / DPV Team

Inventoried (cross-examination pass, 2026-10-20):

- **CCR** (`ccr_settings_section.dart`): setpoints are already live-resolved
  (table above), but the field shows a plain number with no visible
  distinction between "following Settings" and "overridden" - a hand-rolled
  `TextEditingController` kept in sync via `ref.listen`, not the
  `PlanNumberField` hint-text pattern. This is retrofitted onto the same
  hint-text pattern as everything else in this spec, so CCR is not the one
  remaining exception to the visibility goal.
- **PSCR** (`pscr_settings_section.dart`): `pscrRatio` is already *purely*
  global (`pscrRatioProvider`/`setPscrRatio`) with no per-plan override field
  on `DivePlan` at all. Nothing to change here.
- **DPV Team** (`mission_team_section.dart`, fields live on `DpvMission`, not
  `DivePlan`): most fields describe this specific mission (`defaultCurrent`,
  `setsTowardDeg`, `surfaceSwimLimitM` - the current and swim distance of
  this dive, not a diver policy) and get no global default, the same
  reasoning that already excludes `altitude`/`startDateTime`. Only
  `batteryReserveFraction` and `walkSpeedMps` are genuine diver-policy
  values; both are non-nullable fields with hardcoded constants
  (`kDefaultBatteryReserveFraction`, `kDefaultWalkSpeedMps` in
  `dpv_mission.dart`) and go through the same nullable + `DiverSettings`
  column + resolver treatment as Rates.

## Settings UI: Decompression sub-page

The existing `DecompressionSettingsContent`
(`lib/features/settings/presentation/pages/decompression_settings_page.dart`,
reached at Settings > Safety > Decompression) gains new field groups for
Rates, Gas/SAC, Contingency, and the two DPV Team policy fields, laid out
the same way the Setup accordion already groups them, so a diver who has
used the planner recognizes the sections immediately.

No navigation changes beyond this page's own content growing: no new route,
no new hub row, no change to the Safety hub's structure from
`2026-10-16-safety-settings-hub.md`.

## Resolution order, end to end

For every field in scope, exactly the order `setpointAt` already uses for
CCR setpoints:

1. A per-segment override, if the field has one (none of the new fields do
   today).
2. The plan's own value, if set (non-null).
3. The diver's Settings value.
4. A spec/pure constant, only as the absolute last resort for a caller with
   no Settings available at all (mirrors `DivePlan.specSetpointLow` /
   `specSetpointHigh`) - in practice, since Settings always has a row with
   defaults, step 4 should never actually trigger outside tests.

## Testing

- A newly created, unsaved plan's resolved values (via `PlanEngineConfig`/
  whatever resolver Rates and Gas end up using) match the diver's current
  Settings for every new field, including after Settings change while the
  planner is open and the plan is still untouched.
- Overriding a field inside a plan, saving it, then changing the
  corresponding global Settings value: the saved plan keeps its own value on
  reload; an *other*, never-touched saved plan picks up the new global value.
- Clearing an override back to "use Settings" makes the field live-resolve
  again.
- The Setup accordion shows the overridden-vs-following-Settings state
  correctly: following on a fresh plan, overridden immediately after editing
  a field (even before saving), still overridden after save/reload, and back
  to following after an explicit reset. Covers all three UI shapes: the
  `PlanNumberField` hint-text fields, the `lastStopDepth` segmented control's
  "Default" option, and the retrofitted CCR setpoint fields.
- Migration: existing plans are unaffected by the new `DiverSettings`
  columns; their already-stored concrete values are untouched.
- Decompression sub-page: new field groups render current Settings values,
  write back to the right columns, and sit alongside the existing
  gradient-factor/ppO2/CNS rows without duplicating them.

## Left to the builder

- Exact new column names (suggested above, not final).
- Where the new rate/SAC/contingency resolvers live: directly on
  `PlanEngineConfig` (if the engine needs them mid-computation) versus a
  separate planner-defaults resolver used only at plan-creation/UI time.
- Exact wording/icon for the `lastStopDepth` "Default" segment.
- Exact grouping/ordering of the new field groups within the Decompression
  sub-page.
