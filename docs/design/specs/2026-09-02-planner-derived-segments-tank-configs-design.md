# Dive Planner: Derived Segment Phases and Saved Tank Configurations

**Status:** design approved in chat 2026-09-02; spec awaiting review. Parts A, C, D, E and F implemented on `worktree-planner-redesign`; part B not started
**Branch:** TBD (one worktree per part)
**Baseline:** `origin/main` at 6ba0f5cedc0

## Problem

Two unrelated papercuts in the planner, both rooted in the planner asking the
diver to restate information it already has.

### A. The diver declares a segment type the planner could infer

`SegmentEditor` opens with a `DropdownButton<SegmentType>` over all six values
of `SegmentType` (`segment_editor.dart:121-147`), and the diver must pick
Descent / Bottom / Ascent / Deco Stop / Gas Switch / Safety Stop *before*
entering depths. The choice is then largely ignored, and where it is not
ignored it can contradict the numbers:

- A segment declared Descent with `startDepth: 30, endDepth: 12` is stored,
  charted and decompressed as an ascent, but billed at the bottom SAC rate.
- Picking a type mutates the depth fields underneath the diver:
  `_updateDefaultsForType` (`segment_editor.dart:273-314`) squashes Bottom to
  flat by copying end depth into start depth, and forces Safety Stop to 5 m /
  3 min.
- Both depth fields are always visible for every type. Descent does not hide
  start depth; Bottom does not hide end depth. The only per-type field
  visibility in the whole editor is the rate box (`segment_editor.dart:95`).

Meanwhile the chart already does the right thing: dragging a vertex re-derives
the type from the slope sign (`plan_chart_edit_controller.dart:89-103`). So the
app contains two contradictory models of what a segment type is - a declared
input in the editor and a derived label on the chart.

### B. Tank setups cannot be saved, named or reused in the planner

`PlanTankList`'s `_TankEditDialog` (`plan_tank_list.dart:168-370`) is five free
text fields, a role dropdown and a checkbox. There is no preset picker, no
saved-configuration picker, and no way to name and keep a tank setup. Every
plan starts from a hardcoded AL80 minted by
`DivePlanNotifier._createDefaultTank()`
(`dive_planner_providers.dart:144-155`), and a diver who plans the same
double-12 + AL40 deco rig every week retypes it every week.

## Findings

### The stored `SegmentType` is almost entirely redundant

The decompression model never sees it. `plan_engine.dart:234` feeds
`DecoSegment(startDepth, endDepth, durationSeconds)` straight into
`BuhlmannGf`; ppO2/CNS/OTU use `avgDepth` and `deeperEnd`
(`plan_engine.dart:243-244`, `:718-722`); the chart profile
(`plan_canvas_providers.dart:145-151`), the bailout solver
(`bailout_solver.dart:139-152`) and the buoyancy twin
(`plan_buoyancy_twin_provider.dart:36`) all interpolate from
`startDepth`/`endDepth`/`durationSeconds` alone. The buoyancy twin explicitly
tests `seg.startDepth == seg.endDepth` rather than reading the type.

Complete inventory of behaviour that depends on `segment.type`:

| Site | Behaviour | Derivable from the numbers? |
| --- | --- | --- |
| `plan_engine.dart:588-589` | SAC selection: `bottom \| descent` -> `sacBottom`, else `sacDecoEffective` | Yes. Descending or level-at-depth -> bottom SAC; ascending or level-on-the-ascent -> deco SAC |
| `contingency_service.dart:180` | `deviatePlan` adds the time delta only to `bottom` segments | Yes. The same method already matches its *depth* delta by `startDepth/endDepth ~= plan.maxDepth` (`:164-168`) |
| `range_table_service.dart:122` | `_shortestBottomMinutes` skips non-`bottom` segments | Yes. Level leg at max depth |
| `plan_engine.dart:296` | Records `ndlAtBottom` / `ttsAtBottom` | Already `type == bottom \|\| endDepth >= maxDepth - 0.1` - the type half is redundant |
| `plan_calculator_service.dart:225` | Same capture in the legacy calculator | Same |
| `plan_calculator_service.dart:237` | Gates the `ndlExceeded` warning to `bottom` segments | Yes, and arguably should not be gated at all |
| `plan_chart_edit_controller.dart:48` | `draggable: type != gasSwitch` | See gas switches below |
| `plan_chart_edit_controller.dart:89-103` | Re-derives the type after a drag | Already derived: slope sign, with flat legs coerced to `bottom` |
| `plan_segment.dart:112-144`, `segment_list.dart:222-276`, `segment_editor.dart:316-405` | Icon, colour, label, dropdown text | Presentation only |

Nothing else in `lib/` branches on the type.

### Gas-switch segments are already vestigial

A `gasSwitch` segment's only non-derivable payload is `switchToTankId`, and
`SegmentEditor._save` (`segment_editor.dart:333-367`) **never sets it** - so
every gas-switch segment created through the UI is a 60-second flat segment
with a null switch target. `plan_file_codec.dart:70-82` does not serialise
`switchToTankId` at all, so it is lost on export/import even when set. A gas
switch is already fully expressed by consecutive segments carrying different
`tankId` values, which is what the engine's per-segment `charge(segment.tankId,
...)` actually reads (`plan_engine.dart:591`).

### `startDepth` is stored, and nothing keeps the chain intact

`startDepth` is a stored per-segment column that every consumer reads
literally. It is chained only at authoring time, as a seed: the Add dialog
passes `initialStartDepth: segments.last.endDepth`
(`segment_list.dart:92-97`), and a chart drag explicitly writes the new depth
into the *next* segment's `startDepth` (`plan_chart_edit_controller.dart:
134-137`). The Edit path passes nothing.

`reorderSegments`, `removeSegment` and `updateSegment`
(`dive_planner_providers.dart:241-291`) renumber `order` and never repair the
depth chain. So a plan where segment N ends at 30 m and segment N+1 starts at
12 m is representable, persists, syncs, and is computed as an instantaneous
teleport - `plan_canvas_providers.dart:146` even carries a
`profile.last.depth != segment.startDepth` guard to draw the discontinuity.
This is a latent correctness bug, not a cosmetic one: the Buhlmann integration
receives a leg that skips 18 m of ascent in zero time.

### Per-segment `rate` is dead

`PlanSegment.rate` is stored (`database.dart:632`), persisted
(`dive_plan_repository.dart:502`), serialised (`plan_file_codec.dart:80`) and
synced - and read by **zero** calculations. Its only consumer is seeding the
editor's rate text box (`segment_editor.dart:78`). All travel-leg maths uses
the plan-level `descentRate`/`ascentRate` (`dive_plan.dart:43-44`,
`plan_engine.dart:172-174`, `:474`, `:486`, `:603`, `:621`, `:696`, `:985`).
Its sign convention (`plan_segment.dart:56-57`: positive descent, negative
ascent) is upheld by `PlanSegment.ascent` (`:248`) and violated by the editor,
which always stores a positive value (`segment_editor.dart:361`).

### The requested tank feature already exists, unwired

`lib/features/cylinder_configs/` is a named, ordered, multi-cylinder
configuration store carrying exactly the fields the planner needs:
`CylinderConfigItem` has `label`, `tankRole`, `volumeL`,
`workingPressureBar`, `tankMaterial`, `o2Percent`, `hePercent`,
`defaultStartPressureBar`
(`cylinder_config_item.dart:10-109`). It persists to `cylinder_configs` /
`cylinder_config_items` (`database.dart:2429-2478`, added at schema v139) and
rides the sync layer (`sync_repository.dart:82-83`).

Its only consumer is the dive edit page (`dive_edit_page.dart:2824`,
`:3104-3140`). Nothing under `lib/features/dive_planner/**` or
`lib/features/planner/**` references it.

Three pieces are directly reusable:

- `ApplyConfigurationMenu` (`apply_configuration_menu.dart:14-17`) takes only
  `ValueChanged<CylinderConfig> onSelected`, reads its own providers, and
  renders `SizedBox.shrink()` when the diver has no configurations. Mountable
  in the planner as-is.
- `DiveTankConfigAdapter._fromItem`
  (`dive_tank_config_adapter.dart:32-42`) already maps a config item to a
  `DiveTank` **including `gasMix`, `material` and `workingPressure`**.
- `CylinderConfigApplier.plan()` is pure, with an injected `newId` factory.

One rule does not transfer. `FillTank` deliberately has no `o2Percent` /
`hePercent` fields (`cylinder_config_applier.dart:41-49`): for a logged dive,
`dive_tanks` defaults gas to air, so "unset" is indistinguishable from "air"
and overwriting a mix would be a safety-relevant falsehood in a logbook. That
reasoning is sound for the log and wrong for the planner, where the gas mix is
the primary thing being planned.

Finally, the reverse direction does not exist anywhere in the app: there is no
"capture the current cylinders as a named configuration" flow on any screen.
`TankEditor._saveAsPreset` (`tank_editor.dart:215-266`) saves one cylinder's
hardware spec as a `TankPresetEntity` - no gas, no role, no set.

## Decisions

| Question | Decision |
| --- | --- |
| Derive the type, or remove the concept? | Remove `SegmentType` as *input*. A derived `SegmentPhase` remains, for labels and SAC selection only |
| Keep `startDepth` stored? | No. Full waypoint model: a segment is `(targetDepth, duration, tank)`; start depth is the previous segment's target, first segment starts at the surface |
| Where does the derived geometry live? | A new pure `SegmentChain` resolver producing `ResolvedLeg`s. Consumers take resolved legs, not raw segments |
| Gas-switch segments? | The type disappears. A switch is a `tankId` change between consecutive segments, which is what the engine already reads |
| Per-segment `rate`? | Dropped. Dead field; the effective rate is `(target - start) / duration` |
| Saved tank configurations | Reuse `cylinder_configs`. No fourth tank concept |
| Planner apply semantics | Replace, not merge. New mode in the adapter; the log's merge path is untouched |
| Schema migration | None required for part A. `end_depth` already holds the target depth |
| Authoring order | Tanks first, then segments, in every layout. A diver picks the gas they are carrying before drawing the profile that breathes it |
| Cylinder roles | Derived too (part D). `bailout` stays an explicit flag, offered only on a loop plan, because a 100% cylinder there is either the O2 supply or a bailout bottle and guessing wrong understates the bailout gas |
| Tank fields | Name, size, start pressure, mix, travel flag. End pressure is an output the engine computes, not an input |
| Segment runtime | Shown per row, derived on the chain like everything else |
| Deco ceiling semantics (part E) | The ceiling is a fixed point of the GF-vs-depth interpolation, and a property of tissue state alone. `currentDepth` leaves the ceiling API |
| Trial-ascent ordering (part E) | Tested on arrival at the stop, before any minute is loaded. The old order credited off-gassing the schedule never spent |
| Ascent rates (part F) | Four configurable rates on TDI's phases, not Subsurface's mean-depth-relative bands: bottom to first stop, between intermediate stops, between shallow stops, last stop to surface. Defaults 9 / 6 / 3 / 1 m/min |
| Delivery | Six independent PRs; no part depends on another. Part C is small enough to land on its own immediately. Part E is engine-only and touches no planner UI |

### Frozen units

The engine and all entities stay metric (metres, bar, litres, m/min). Every
depth, volume and pressure field in the editor and the tank dialog reads and
writes the active diver's unit via the existing conversion helpers, per the
project rule that anything displaying units respects the diver's settings.

## Part A - Derived segment phases and the waypoint model

### New: `lib/features/planner/domain/entities/segment_phase.dart`

```dart
/// What a leg of the planned profile is doing, derived from its geometry.
enum SegmentPhase { descent, level, stop, ascent }
```

`level` and `stop` are both flat; they differ only in which SAC rate applies
and which icon is drawn.

### New: `lib/features/planner/domain/services/segment_chain.dart`

Pure, no Flutter, no `DateTime.now()`. Turns the authored waypoint list into
the resolved geometry every consumer needs.

```dart
class ResolvedLeg {
  final PlanSegment segment;
  final double startDepth;   // previous leg's target, or 0.0 for the first
  final double endDepth;     // == segment.targetDepth
  final SegmentPhase phase;
  final double? rate;        // m/min, signed; null when duration == 0
  final int runtimeSeconds;  // elapsed dive time at the END of this leg

  double get avgDepth => (startDepth + endDepth) / 2;
  double get deeperEnd => math.max(startDepth, endDepth);
  int get durationSeconds => segment.durationSeconds;
}

class SegmentChain {
  const SegmentChain();
  List<ResolvedLeg> resolve(List<PlanSegment> segments);
}
```

Phase derivation, in `resolve`:

1. `endDepth > startDepth` -> `descent`
2. `endDepth < startDepth` -> `ascent`
3. equal -> `stop` if `endDepth < maxTargetDepth` **and** no later leg has a
   target deeper than this one; otherwise `level`

Rule 3 is what makes a 6 m flat leg after the bottom read as a stop while a
20 m flat leg in a multi-level dive that later drops to 25 m reads as a level.
It reproduces today's declared types for every profile a diver would plausibly
author.

### Changed: `PlanSegment`

Removed: `type`, `startDepth`, `rate`, `switchToTankId`.
Renamed: `endDepth` -> `targetDepth` (same semantics, same column).
Kept: `id`, `targetDepth`, `durationSeconds`, `tankId`, `gasMix`,
`setpointBar`, `diveModeOverride`, `order`.

The six named factories (`plan_segment.dart:185-315`) collapse to one
`PlanSegment.waypoint({required targetDepth, required durationSeconds,
required tankId, required gasMix, ...})`. The `description` / `shortLabel`
getters (`:112-144`) are deleted rather than moved - both are already unused in
`lib/`; the UI localises through `segment_list.dart` instead.

`avgDepth`, `isDepthChange` and `calculatedRate` move to `ResolvedLeg`, since
a segment in isolation no longer knows where it starts.

### Changed: `PlanEngine`

`plan_engine.dart` resolves once at the top of `compute()` and threads
`List<ResolvedLeg>` through the private helpers that currently take
`List<PlanSegment>`.

- Line 234 (`DecoSegment`) reads `leg.startDepth` / `leg.endDepth` - identical
  values for any continuous plan, repaired values for a discontinuous one.
- Lines 588-589 become:

  ```dart
  final sac = switch (leg.phase) {
    SegmentPhase.descent || SegmentPhase.level => plan.sacBottom,
    SegmentPhase.ascent || SegmentPhase.stop => plan.sacDecoEffective,
  };
  ```

  This is behaviour-preserving: the loop at `:586` runs over authored segments
  only, and the computed ascent is charged separately at `sacDecoEffective`
  (`:600-628`).
- Line 296 drops the `type == bottom` disjunct and keeps the depth test.

### Changed: `ContingencyService` and `RangeTableService`

Both need "which leg is the bottom". Add one shared helper on `SegmentChain`:

```dart
int? bottomLegIndex(List<ResolvedLeg> legs);  // deepest level leg, last wins
```

`contingency_service.dart:180` applies its time delta to that index;
`range_table_service.dart:122` reads its duration. `contingency_service.dart:
164-168` already matches by depth and keeps doing so, except that it now
shifts only segment *targets* - the descent that feeds the bottom targets max
depth too, and every other leg follows the chain.

This changes one behaviour on a multi-level plan: the old loop added the time
delta to *every* segment typed `bottom`, so a two-level dive got it twice. It
now buys bottom time once, on the deepest level leg, which is what "+5 min" is
meant to mean.

### Changed: `SegmentEditor`

The type dropdown, both depth fields and the rate field are replaced by:

- **Depth** - the target depth, in the diver's unit. Labelled "Depth", not
  "End Depth"; `divePlanner_segmentEditor_endDepth` is retired in favour of a
  new `divePlanner_segmentEditor_depth`.
- **Duration** - minutes, unchanged.
- **Tank / gas** - unchanged.
- Setpoint and dive-mode override - unchanged, and now correctly preserved
  (see below).

A read-only line above the fields states the derived phase and the implied
rate: "Descent from 0 m at 18 m/min" / "Level at 30 m" / "Ascent to 6 m at
9 m/min". This is where the diver sees the inference, so it is not magic.

`_updateDefaultsForType` (`:273-314`) is deleted outright - there is no type to
change, and nothing may rewrite a depth the diver typed.

`_save` (`:333-367`) stops writing `rate` (gone), stops defaulting it to 10,
and **preserves `setpointBar` and `diveModeOverride`** by copying them from the
segment being edited. Today it drops both on every edit round-trip.

### Changed: `SegmentList`

Icon, colour and label switch on `leg.phase` instead of `segment.type`. Four
cases instead of six. The existing l10n strings map across:

| Phase | l10n key |
| --- | --- |
| `descent` | `divePlanner_segmentList_descent` (existing) |
| `level` | `divePlanner_segmentList_bottom` (existing) |
| `stop` | `divePlanner_segmentList_deco` (existing) |
| `ascent` | `divePlanner_segmentList_ascent` (existing) |

No new list strings; `divePlanner_segmentList_gasSwitch` and
`..._safetyStop` are retired. A leg whose `tankId` differs from the previous
leg's gets a gas-switch chip on its row, reusing the existing
`divePlanner_segmentList_gasSwitch` ("Gas switch to {gasName}") string. The
switch becomes an annotation on the leg that starts breathing the new mix,
which is also what the engine charges.

### Changed: `PlanChartEditController`

Simplifies substantially. `_retyped` (`:89-103`) is deleted - the phase is
never stored, so there is nothing to re-type. `draggable` (`:48`) becomes
unconditionally `true`. Writing the dragged depth into the next segment's
`startDepth` (`:134-137`) is deleted; the chain follows automatically.

This also fixes the bug at `:99-111`, where the sloped branch rebuilt the
segment with a raw constructor and silently dropped `rate`, `setpointBar` and
`diveModeOverride` - only the first was documented as intentional (`:85-87`).

### Changed: providers

`dive_planner_providers.dart:241-291` (`reorderSegments`, `removeSegment`,
`updateSegment`) keep renumbering `order` and no longer have a depth chain to
corrupt: removing a middle segment now closes the gap by construction.

`addSimplePlan` (`:311-326`) is rewritten in terms of waypoints and picks up
`state.descentRate` correctly - today it calls `PlanSegment.descent` without
`rate:` and silently uses the factory's hardcoded 18 m/min regardless of the
slider.

### Persistence and compatibility

**No schema migration.** `dive_plan_segments.end_depth` already holds exactly
the target depth, so `targetDepth: row.endDepth` reads every existing plan
correctly, and a continuous plan resolves to a byte-identical profile.

- `type`, `start_depth` and `rate` are no longer *read* back, but they are
  still *written*, filled from the resolved leg. Two reasons. `type` and
  `start_depth` are NOT NULL with no default, so ceasing to write them would
  need a destructive table rebuild for no gain. And filling them from the
  chain keeps them true, so an older build or a sync peer reading the row
  still sees the profile the diver authored rather than a placeholder. The
  phase maps back as `level -> bottom` and `stop -> decoStop`; `safetyStop`
  and `gasSwitch` are never written, since neither was ever distinguishable
  from the geometry. `switch_to_tank_id` is nullable and is left null.
- A consequence worth noting: re-saving a plan that had a stored
  discontinuity rewrites `start_depth` to the repaired value, so the repair is
  durable rather than re-applied on every load.
- A later cleanup migration can drop all four columns once no released
  version reads them.
- `dive_plan_repository.dart:594` currently does
  `SegmentType.values.byName(s.type)`, which **throws** on an unrecognised
  name. Deleting that line removes a live crash surface.
- Rows with `type == 'gasSwitch'` become 60-second flat legs at their stored
  depth. Depth profile and deco loading are unchanged - that is exactly what
  the engine computed before - and so is the SAC rate in the case that
  matters: a switch held on the way up classifies as a stop, which is the deco
  SAC it was already charged at. Only a switch authored at max depth would move
  to the bottom SAC, and that is not a switch any real profile performs.
- `plan_file_codec.dart` writes format version `2`: `targetDepth` replaces
  `endDepth`, and `type` / `startDepth` / `rate` are omitted. Decode accepts
  both: a v1 file's `endDepth` is read as `targetDepth` and its `type` and
  `startDepth` ignored. Version `1` files therefore keep importing, which
  matters because `.subplan` is a sharing format. The existing silent fallback
  at `:168-169` (`?? SegmentType.bottom`) disappears with the field.
- `sync_data_serializer.dart:2941` / `:3800` continue to round-trip the row;
  the retired columns simply carry their defaults on new writes.

### Out of scope for part A

Per-segment setpoint and dive-mode override semantics (only their preservation
is fixed here). The plan-level rate sliders. `plan_calculator_service.dart` is
updated only where it references the removed fields - the legacy calculator is
not rewritten.

## Part B - Saved tank configurations in the planner

Independent of part A; can ship first or in parallel.

### As built (2026-09-02)

The diver asked for saved tanks as *selectable objects*: a bar above the
plan's tanks that opens into a box of every saved cylinder, each of which
joins the plan when tapped. That is a different shape from the
`ApplyConfigurationMenu` merge designed below, so the build diverged from
the design in these ways and kept the rest:

- New `PlanSavedTanksBar`
  (`lib/features/dive_planner/presentation/widgets/plan_saved_tanks_bar.dart`),
  mounted in `PlanTankList` between the header and the tank chips. Closed by
  default, titled "Saved tanks (n)"; open, it lists every saved cylinder
  (every configuration's items, flattened) as its own chip. Tapping a chip
  calls `DivePlanNotifier.addTank` with the cylinder converted by the new
  `DiveTankConfigAdapter.tankFromItem`, gas included. Picking is a copy: the
  saved cylinder stays offered. Open state is `savedTanksExpandedProvider`,
  session-scoped like the rest of the planner's collapse state.
- Saving is one tank at a time, at the diver's request. "Save a tank" opens
  a menu of the plan's tanks; picking one prompts for a tank name (the
  `showPlanNameDialog` prompt gained a `fieldLabel` so it no longer says
  "Plan Name" here), seeded with the tank's name. The tank is captured with
  the new `TankConfigCapture.fromTanks` - the reverse adapter designed below
  - and appended to a configuration named "Saved tanks" that is created for
  the active diver on first use, so the equipment pages show everything saved
  from the planner as one list rather than one configuration per tank. The
  bar opens afterwards so the diver sees what they saved. The Manage link
  (to `/equipment/cylinder-configs`) is where saved tanks get renamed or
  removed.
- Not built: `replaceTanks`, the whole-configuration merge, the default-tank
  preset resolver, and the tank-preset picker in `_TankEditDialog`. None was
  asked for and the pick-one-cylinder shape does not need them. A tank saved
  from the planner therefore carries whatever `workingPressure` and
  `material` the plan had, which for a tank typed into the planner's dialog
  is none; the volume, gas and start pressure a plan actually uses round-trip
  exactly, and `tank_config_capture_test.dart` pins that.

### Changed: `DiveTankConfigAdapter` - a replace mode

`dive_tank_config_adapter.dart` gains one method beside `apply()`:

```dart
/// Materialises [items] as a complete tank list, discarding what was there.
///
/// The planner replaces rather than merges: a plan's cylinders are an input
/// the diver is choosing, not a record of a dive that happened, so filling
/// only null columns (as apply() does) would leave a half-applied rig. Gas
/// mix is carried here for the same reason it is refused by FillTank - in a
/// plan the mix is the thing being chosen, so silently keeping the old one
/// would be the falsehood.
List<DiveTank> replace({
  required List<CylinderConfigItem> items,
  required String Function(int index) newId,
});
```

The body is a `_fromItem` map over `items` - `_fromItem`
(`dive_tank_config_adapter.dart:32-42`) already carries `gasMix`, `material`,
`workingPressure`, `role`, `label` and `defaultStartPressureBar`. The log's
merge path and `CylinderConfigApplier` are untouched, so the safety reasoning
at `cylinder_config_applier.dart:41-49` still holds where it was written.

### New: `lib/features/cylinder_configs/domain/services/tank_config_capture.dart`

The reverse adapter, which the app currently lacks entirely.

```dart
/// Builds config items from an in-memory tank list.
///
/// Pure; [newId] mints item ids so this stays testable.
class TankConfigCapture {
  const TankConfigCapture();

  List<CylinderConfigItem> fromTanks({
    required List<DiveTank> tanks,
    required String configId,
    required String Function(int index) newId,
  });
}
```

Mapping is field-for-field: `name -> label`, `role -> tankRole`,
`volume -> volumeL`, `workingPressure -> workingPressureBar`,
`material -> tankMaterial`, `gasMix.o2 -> o2Percent`,
`gasMix.he -> hePercent`, `startPressure -> defaultStartPressureBar`,
`order -> sortOrder`. `endPressure`, `computerId`, `presetName`,
`decoSwitchDepth` and `isTravelGas` are not part of a configuration and are
dropped. Placing this in `cylinder_configs` rather than in the planner means
the dive editor can reuse it, which closes gap 3 of issue #800.

### Changed: `PlanTankList`

A "Saved tanks" row above the tank chips:

- `ApplyConfigurationMenu(onSelected: ...)` mounted unchanged, calling
  `DiveTankConfigAdapter.replace` and handing the result to a new
  `DivePlanNotifier.replaceTanks(List<DiveTank>)`. It self-hides when the
  diver has none, so the row is never a dead end.
- A "Save tanks as..." action, enabled when at least one tank is present. It
  prompts for a name (reusing the `showPlanNameDialog` pattern from
  `plan_name_dialog.dart:10`, generalised into a small
  `showNamePromptDialog`), then `TankConfigCapture.fromTanks` ->
  `CylinderConfigRepository.createConfig` + `saveItems`. Saving with an
  existing name offers to overwrite that configuration.
- A "Manage saved tanks" entry navigating to `/equipment/cylinder-configs`
  (`app_router.dart:552`).

### Changed: `DivePlanNotifier`

New `replaceTanks(List<DiveTank> tanks)`. It must do what `removeTank`
(`dive_planner_providers.dart:394`) already does for orphans: any segment whose
`tankId` is no longer present is reassigned to `tanks.first`, and its `gasMix`
is refreshed from that tank - the same invariant `updateTank` (`:372`)
maintains. Replacing with an empty list is refused, matching `removeTank`'s
refusal to remove the last tank.

`_createDefaultTank()` (`:144-155`) additionally consults
`DefaultTankPresetResolver.resolve(presetName)`
(`default_tank_preset_resolver.dart:22`) so a new plan opens with the diver's
configured default cylinder instead of a hardcoded AL80. The resolver is
async and returns nullable, so the notifier keeps the current AL80 as the
synchronous fallback and refines the tank once the resolver settles - a new
plan must never block on I/O before its first render.

### Changed: `_TankEditDialog`

The planner's dialog leaves `workingPressure`, `material` and `presetName` null
(`plan_tank_list.dart:340-370`), so a save-then-apply round trip would lose
them. It gains the tank-preset picker the dive-log tank editor already has
(`tank_editor.dart:418+`): choosing a preset seeds volume, working pressure and
material, exactly as `CylinderConfigItemEditor._applyPreset`
(`cylinder_config_item_editor.dart:63-75`) does. Round-trip fidelity through a
saved configuration follows from that.

### Out of scope for part B

Linking planner tanks to owned `EquipmentType.tank` equipment (gap 1 of
issue #800). Rebreather-owned configurations are listed by
`ApplyConfigurationMenu` and apply normally, but the planner does not filter
them by plan mode.

## Part C - Tanks before segments

Independent of A and B, and by far the smallest change.

### Rationale

Both editing layouts currently put the profile first and the cylinders second,
which inverts the authoring order. A segment's tank dropdown
(`segment_editor.dart`, the Tank / Gas field) can only offer what already
exists, so a diver drawing the profile first is picking from a single
hardcoded AL80 (`dive_planner_providers.dart:144-155`) and must go back and
re-pick tanks on every segment after defining the real rig. Gas first, then
the profile that breathes it.

This matters more after part A: with the type dropdown gone, the segment editor
is down to depth, duration and tank, so the tank choice becomes proportionally
the most significant thing in it. And it matters more after part B, because
applying a saved configuration is the natural first action when opening the
planner.

Note on naming: the widget being promoted is `PlanTankList`, which is where gas
mixes actually live. `PlanGasSection` (`plan_gas_section.dart`) holds no gas
mixes at all despite its name - only the SAC/RMV slider and reserve pressure
(`:36-70`, `:113`) - so it stays in the Setup accordion where it is.

### Changed: `PlanEditorPane` (desktop and wide)

`plan_editor_pane.dart:51-53`: `PlanTankList` moves above `SegmentList`. The
Setup accordion stays the last child, which the pane's setup-focus scroll
depends on (`:35-45` animates to `maxScrollExtent` to materialize the lazily
built accordion), so that behaviour is unaffected.

The class doc comment at `:11-12` ("segments and tanks always visible") is
reworded to match.

### Changed: phone tab deck

`plan_canvas_page.dart`:

- The `tabs` list (`:421-426`) reorders to Tanks, Plan, Setup, Results -
  `divePlanner_label_tanks` then `divePlanner_tab_plan`, both existing strings.
- `_phoneTabBody` (`:499-524`) swaps cases `0` and `1`: `0` returns
  `PlanTankList`, `1` returns `SegmentList`. Cases `2` (Setup) and `3`
  (Results) are untouched, so the two hardcoded index writes stay correct as
  they are: `_focusSetup` -> `2` (`:308`) and the issues-chip handler -> `3`
  (`:450`).
- The layout-mode doc comment at `:54` becomes
  "Chart + Tab Deck (Tanks / Plan / Setup / Results)".

`plannerPhoneTabProvider` defaults to `0`
(`planner_layout_providers.dart:19`) and is in-memory session state, so a
phone diver now lands on Tanks when opening the planner. That is the intent,
not a side effect.

### Compatibility

Nothing persisted encodes the tab order, so there is no migration and no stale
stored index to reconcile.

### Out of scope for part C

Reordering the Setup accordion's own sections
(`plan_setup_accordion.dart:81`), and the fullscreen chart page.

## Part D - Derived cylinder roles

Same argument as part A, applied to the tank editor. Independent of A, B
and C.

### Problem

The planner's tank dialog asked for a `TankRole` from a nine-value dropdown
(`plan_tank_list.dart:310-328`) - back gas, stage, deco, bailout, sidemount
left/right, pony, diluent, O2 supply. Two of those nine drive nothing at all
in a planner, and the choice can contradict the rest of the plan: a cylinder
labelled Back Gas that no segment breathes, or a Deco bottle leaner than the
bottom mix.

Unlike the segment type, role is genuinely load-bearing - it is read in 14
places and decides real numbers:

| Consumer | What role decides |
| --- | --- |
| `bailout_solver.dart:74` | Which cylinders are bailout. No bailout-role tank and `solve()` returns null, so there is no bailout plan at all |
| `plan_engine.dart:510`, `:517` | CCR metabolic O2 charged to the O2 supply; loop-fill diluent charged to the diluent |
| `plan_engine.dart:666`, `:688` | Turn pressure and rock-bottom min gas - back gas only |
| `plan_engine.dart:553` | Bailout cylinders are exempt from the reserve-violation check |
| `plan_engine.dart:920` | The "CCR in deco with no bailout gas" issue |
| `_hasDecoGas` `:934`, `_tankForGas` `:1005` | Whether a deco gas is carried, and that deco stops bill the deco bottle rather than the back gas |
| `contingency_service.dart:79`, `:121` | Which cylinders lost-gas can lose, and the back-gas fallback |

So it cannot simply be deleted. It can be *derived*, and derived more
reliably than the diver's dropdown, because the plan already records which
cylinder every segment breathes and what each mix's MOD is.

### New: `lib/features/planner/domain/services/tank_role_resolver.dart`

Pure. `apply(DivePlan) -> DivePlan` returns the plan with every cylinder's
role derived; `rolesFor(DivePlan)` exposes the map for display.

- **back gas** - the cylinder the deepest leg breathes. Straight out of the
  segment data, not a guess. With no segments yet, the first cylinder.
- **deco** - any other cylinder richer than the bottom mix, so a shallower
  MOD.
- **stage** - same or leaner than the bottom mix but not the bottom cylinder:
  a stage or pony. Travel-flagged cylinders are filed here explicitly, because
  a travel gas must never become the back gas and drag turn pressure and
  rock-bottom onto itself.
- **loop plans** (`mode != oc`) - pure O2 that no segment breathes is the
  oxygen supply; the cylinder the segments breathe is the diluent; anything
  else carried is open-circuit bailout.
- **bailout** - honoured as an explicit override and never re-derived.

`stage` and `deco` are treated identically by every consumer, and
`sidemountLeft`, `sidemountRight` and `pony` drive nothing, so those five
values simply stop being reachable from the planner. The enum itself is
untouched - the dive log still uses all nine.

### Why bailout stays a flag

On a loop plan a 100% cylinder is either the oxygen supply or a bailout/deco
bottle, and no combination of mix, size and segment references separates them:
a CCR diver carrying pure O2 as a deco bottle has two 100% cylinders. Reading
a bailout bottle as the O2 supply silently removes it from the bailout
calculation, which is a safety-relevant understatement rather than a cosmetic
slip. Cylinder size is a hint (2-3 L supply against a 7-11 L bottle) and not a
basis for a bailout plan.

So the dialog gains one checkbox, shown only when the plan mode is not `oc`.

### Where the resolver runs

At the consumer boundary, on a local copy, in four places:
`PlanEngine.compute`, `BailoutSolver.solve`,
`ContingencyService.lostGas` and `.lostGasFor`. All 14 role-reading call sites
are then correct with no change to any of them.

Deliberately **not** applied to the stored plan. The dialog persists the
diver's raw input - `bailout` when ticked, `backGas` as a neutral "derive me"
placeholder otherwise - so a *derived* role can never be read back as an
override on a later pass. `ContingencyService.isLosable` reads the derived
role and is documented as requiring a resolved plan.

No schema change: `dive_plan_tanks.role` already exists and keeps holding the
override.

### Changed: `_TankEditDialog`

Fields become **Name, Size, Start pressure, O2 %, He %**, a **Travel gas**
checkbox, and a **Bailout gas** checkbox on loop plans only. The role
dropdown is deleted. The dialog now takes the plan's `mode` so it knows
whether to offer the bailout flag.

End pressure stays out: in a plan it is an output. The engine already computes
`PlanTankUsage.remainingPressure` per cylinder from the SAC and the profile,
and the results pane shows it. An editable end pressure would either be
ignored or fight the computed value.

### Behaviour changes this causes

Three, all surfaced by existing tests and all deliberate:

1. **Every carried cylinder except the back gas is now losable.** A cylinder
   can no longer be declared `pony` to exempt it from the lost-gas
   contingency - a 32% bottle carried beside an 18/45 bottom mix is a
   deco/stage bottle by the numbers. The planner now produces a lost-gas
   variant where the declared-role version produced none.
2. **"My bottom segment breathes my deco bottle" is no longer expressible.**
   Whichever cylinder the deepest leg breathes *is* the back gas. One
   contingency test used that contrivance to exercise the segment remap; it is
   rebuilt around a travel gas lost on the descent, which covers the same code
   realistically.
3. **A plan always has a back gas**, so `lostGasFor`'s
   `orElse: remaining.first` fallback is now defensive only.

### Also in part D: segment runtime

`ResolvedLeg` carries `runtimeSeconds` - elapsed dive time at the end of the
leg - accumulated in `resolve` beside the depths and the phase, with
`startRuntimeSeconds` derived from it. Each segment row's subtitle reads
`duration - RT n' - gas`, ceiled to whole minutes with the prime suffix so it
matches the computed deco schedule's existing RT column
(`plan_results_sheet.dart:367`) rather than the stat tiles' convention. It
reuses `plannerCanvas_table_runtime` ("RT") rather than adding a twelfth
translation of the same abbreviation.

### Out of scope for part D

The dive log's own tank editor and its role dropdown, which stay as they are -
for a logged dive the role is a record of how the diver actually rigged, not
something the numbers imply. Working pressure and material are still not
collected by the planner dialog; part B needs them for a lossless round trip
through a saved configuration.

## Part E - Deco ceiling and schedule corrections

Not part of the original request. Found while investigating a plan the diver
reported: 21 m for 30 min then 10 m for an hour on air, which showed a
decompression ceiling from runtime 23 where other planners showed 37. Three
independent defects, all in the shared deco core rather than the planner.

### E1. The planner chart plotted an ungated ceiling

`PlanEngine._ceilingTrace` asked for the ceiling at every sample and drew
whatever came back. A gradient-factor ceiling becomes non-zero the moment
supersaturation crosses the GF-low line, which on this profile is runtime 17 -
long before a direct ascent stops being permitted. The curve was drawing the
GF-low deep-stop *target*, not an obligation.

`getDecoStatus` had always gated this correctly for dive details
(`buhlmann_algorithm.dart`, "only calculate ceiling/stops when actually in
deco"), so logged dives were never affected. The trace now applies the same
gate through the new `DecoModel.surfaceCeilingMeters`, and `PlanEngine`'s
per-segment `ceilingAtEnd` gates on `ndl < 0` to match
`PlanCalculatorService`, which reads it off a `DecoStatus` that was already
gated.

### E2. Long depth ramps were loaded at a single mean depth

`BuhlmannGf.applySegment` did one Schreiner step at `(start + end) / 2`
regardless of duration, so a 20-minute descent to 21 m was modelled as 20
minutes at 10.5 m. Gas loading approaches the inspired pressure exponentially,
so the mean depth of a long ramp is not equivalent to travelling it.

Depth-changing segments are now sliced at 10 s, each slice at its own mean
depth. Flat segments are untouched - their mean depth *is* their depth - and
dive-log replay feeds sample-to-sample segments a few seconds long, so that
path is unaffected either way. This is why the whole deco suite, golden
vectors included, was unmoved by E1 and E2.

### E3. The ceiling contradicted the schedule

The reported symptom, and the one that changes deco schedules. At runtime 110
the plan showed a 4.17 m ceiling whose only stop was 3 m: the schedule was
telling the diver to ascend through their own ceiling. Two coupled causes.

**The ceiling was evaluated at the diver's depth.** `calculateCeiling` took a
`currentDepth`, interpolated the GF there, and returned the tolerance at that
gradient factor. For anyone deeper than the anchor that is GF-low, so the
answer was the GF-low ceiling - a tolerance at a gradient factor that only
applies far shallower, and not a depth the diver has to respect.

Because the GF is a function of depth, the ceiling is the depth at which the
tissues are tolerated *under the gradient factor that applies at that same
depth*: a fixed point. `calculateCeiling()` now solves it by iterating from
the GF-low ceiling, which is the deepest the answer can be and descends
monotonically onto the solution (the ceiling shallows as the GF rises, and the
GF rises as the depth shallows). It takes no `currentDepth` - the ceiling is a
property of tissue state and the anchor, not of where the diver is floating.

The "may I surface?" question is genuinely different, and now has its own
name: `surfaceTargetCeiling()` on the algorithm, `surfaceCeilingMeters` on
`DecoModel`. Previously it was spelled `calculateCeiling(currentDepth: 0)`,
which worked only because `_interpolateGf(0)` returns GF-high.

**The trial ascent was tested one minute late.** `_calculateStopTime` loaded a
minute at the stop, tested the ceiling, then restored the pre-minute state and
either committed the minute or left. So a stop that cleared inside its first
minute was recorded as zero minutes and dropped, while the off-gassing that
justified leaving was never spent. Every stop was under-reported by up to a
minute, and first stops vanished outright: on this profile the diver arrived
at 9 m with a 6.63 m ceiling and was sent to 6 m.

The test now runs on arrival, before the minute is loaded - "may the diver
leave with the time spent so far?" That also removes the per-iteration
snapshot/restore, since no trial minute exists to undo.

This defect was known. `tts_cleanroom_cross_check_test.dart` had reproduced it
deliberately, commenting that production "holds ~1 min less per stop than a
check-first loop; replicate that trial-then-commit ordering to match the
numbers." It was treated as a quirk to match rather than a bug to file.

### What E3 changes

Every schedule gains a deeper first stop and one to four minutes of TTS. The
regenerated golden vectors:

| Case | Before | After |
| --- | --- | --- |
| air 30 m/25 min GF 50/80 | 6m/3 3m/8, TTS 14 | 9m/1 6m/4 3m/8, TTS 16 |
| air 40 m/20 min GF 30/70 | 15m/1 12m/2 9m/4 6m/7 3m/19, TTS 37 | 18m/1 15m/1 12m/3 9m/4 6m/8 3m/20, TTS 41 |
| EAN32 30 m/40 min GF 50/80 | 6m/4 3m/10, TTS 17 | 9m/1 6m/4 3m/11, TTS 19 |
| tx18/45 60 m/25 min GF 50/80 | 24m/2 ... 3m/16, TTS 52 | 27m/1 24m/2 ... 3m/17, TTS 55 |
| air 30 m/20 min altitude 2000 m | 6m/3 3m/6, TTS 12 | 9m/1 6m/3 3m/6, TTS 13 |
| air 30 m/25 min freshwater | 6m/3 3m/7, TTS 13 | 9m/1 6m/3 3m/7, TTS 14 |

The direction is uniformly more conservative.

**What the external references actually say.** Two fixtures in the suite carry
a hand-recorded Subsurface value, and they disagree about whether E3 is an
improvement. Measured, not recalled:

| Reference | Subsurface | Before E3 | After E3 |
| --- | --- | --- | --- |
| Ceiling, fixture 004 @ 9 m, GF 50/75 | 7.4 m | 7.45 m | 7.07 m |
| TTS, fixture 003 @ min 40, GF 45/75 | 24.0 min | 22.9 min | 24.9 min |

The ceiling moved *away* from Subsurface (0.05 m off, now 0.33 m off). The TTS
moved marginally toward it but overshot (1.1 min low, now 0.9 min high). Both
stay inside their tolerances, and the ceiling difference is a fifth of the 3 m
stop grid, so no decision a diver makes changes. But this is not the clean
corroboration it would be convenient to claim.

The two halves of E3 are separable, and they earn their keep differently:

- The **ordering** fix stands on its own without any reference. A schedule
  cannot spend a minute of off-gassing it does not record; that is a defect by
  inspection. It is also the half that moved TTS, and the only half that
  changed the golden schedules at all - reverting it alone returns every
  vector above to its old value.
- The **fixed-point ceiling** rests on coherence, not on matching Subsurface:
  it makes the ceiling an actual depth limit instead of a tolerance evaluated
  at a gradient factor that applies somewhere else. That is what the diver's
  bug report was about. It costs 0.33 m of agreement on the one ceiling
  reference we hold.

A plausible reconciliation, worth investigating but not acted on here: our
GF-low anchor is the *deepest* ceiling of the dive, while Subsurface's
`first_ceiling_pressure` appears to latch the ceiling the first time one
exists, which is shallower. A shallower anchor makes the interpolated GF more
conservative at every depth and the fixed point deeper - toward 7.4. Changing
the anchor convention is a third semantic change with its own cascade, and it
should not be made from recall. The MultiDeco comparison in the golden README
is the right instrument for settling it.

The 40 m/20 min air GF 30/70 vector is where an external planner would be most
useful, and we have no recorded value for it.

The CCR loading vector's expected ceiling is unchanged, which is the sanity
check on the fixed point: at the deepest moment of a dive the tissues are
still on-gassing, so the GF-low ceiling equals the anchor and the fixed point
pins to it. E3 moves the ceiling only once off-gassing has begun and the
anchor has frozen above it.

On the reported plan, ceiling onset now equals the deco obligation exactly:
runtime 31 at GF 30/70, 37 at GF 30/80, 40 at GF 30/85. The diver's 37 falls
out at GF-high 80.

### Out of scope for part E

`_simulateAscent` still loads a whole travel leg at its mean depth - the same
defect class as E2, but a leg between adjacent 3 m stops is 20 s and the
longest is around 100 s, so the error is far below the minute the schedule is
quantised to. Fixing it would move every schedule again for no operational
gain; it should be its own change, with its own golden regeneration.

The `lastStopDepth = 6` policy path, air breaks and CCR bailout schedules all
inherit E3 through the same `_calculateStopTime`, and their tests pass, but
none of them has an external reference vector.

## Part F - Configurable ascent rates

Also not part of the original request. It came out of comparing a plan with
Subsurface: 50 m for 30 min on air with EAN50, GF 50/80 in both apps.

| | Bottom | Travel | Stops | Runtime |
| --- | --- | --- | --- | --- |
| Subsurface | 35 | 14 | 42 | 91 |
| Submersion, before | 35 | 6 | 52 | 93 |
| Submersion, after | 35 | 13 | 48 | 96 |

The total obligation always agreed to within a couple of minutes. What did
not agree was where the time sat: Subsurface's table shows 6 m to 3 m and 3 m
to the surface each taking three minutes, so it decompresses the diver *during*
the ascent, and its stops need less. We ascended at a flat 9 m/min and crossed
the last 6 m in forty seconds, so the stops had to provide all of it. The
schedules were not really disagreeing; they were bookkeeping the same
decompression differently, and only one of the two looks like what a diver
actually does.

`SchedulePolicy` already had `ascentRateBands` and `ascentRateForDepth` for
Subsurface's four bands, defined as fractions of the dive's mean depth.
Nothing in `lib/` ever called them - the dead code was covered by tests, which
is how it survived. They are replaced rather than wired up: the model here is
TDI's, whose phases are named after where the diver is in the ascent rather
than computed from a mean depth the plan has not derived yet.

### The rate model

TDI's decompression procedures, metric column:

| Phase | Rate | Field |
| --- | --- | --- |
| Bottom to first stop | 9-10 m/min | `ascentRate` (9) |
| Between intermediate stops | 6 m/min | `intermediateAscentRate` (6) |
| Between shallow stops | 3 m/min | `shallowAscentRate` (3) |
| Final stop to surface | 1 m/min | `finalAscentRate` (1) |

These are **phases, not depth bands**, and that distinction is the whole
design. A diver leaving the bottom is doing a working ascent whether the first
stop is at 21 m or at 6 m; a diver leaving the last stop is doing the slow one
whether or not anything deeper was required. So `AscentPhase` names the three
kinds of leg a schedule contains - `toFirstStop`, `betweenStops`,
`fromLastStop` - and `ascentSeconds` takes the phase rather than inferring it
from depth.

Only `betweenStops` needs a depth, to tell an intermediate stop from a shallow
one. `shallowStopDepth` (9 m) draws that line, so the 9/6/3 stops are the
shallow ones. It is a `SchedulePolicy` constant rather than a plan field,
because the standards that name these phases do not parameterise the boundary
either.

The consequence that matters most: **a dive that owes no decompression has no
first stop to slow down for and no last stop to crawl off, so its whole ascent
is `toFirstStop` at the working rate.** Configuring the deco rates cannot
change a recreational profile at all. An earlier iteration of this banded the
ascent purely by depth, which made an 18 m no-deco dive take six minutes to
surface instead of two - correct arithmetic, wrong model. The phase enum is
what makes that error unrepresentable rather than merely fixed.

`ascentTravelSeconds` sums a whole ascent given the stop depths, assigning the
phases in the order a schedule runs them and falling back to `toFirstStop`
throughout when there are no stops. The per-leg callers walk the same
sequence, and a test asserts the total equals the sum of its legs rather than
trusting that they agree.

Both new rates **default to `ascentRate`**. That is the important safety
property of this change: only the planner configures them separately, so dive
details, profile analysis, VPM-B and every other consumer of the deco core
computes exactly what it did before. The full deco suite passed unchanged
after the wiring, which is the evidence for that.

### Where the rates had to be applied

The ascent legs of a computed schedule were being measured in seven places,
each with its own copy of `(from - to) / ascentRate * 60`:
`_ascendLeg`, `calculateTts` and the no-deco branch of `getDecoStatus` in the
algorithm; profile sampling, gas charging, stop arrival runtimes and
rock-bottom in `PlanEngine`; and `_ascentLiters` in `BailoutSolver`. Every one
of them has to agree with the legs the deco model actually loaded, or a stop's
displayed runtime drifts from the tissue state behind it. They now all route
through the policy, and `PlanEngine._policyFor` derives the policy from the
plan in one place.

Threading a `betweenStops` flag through this also surfaced a live bug in
`_mapStops`: the flag was not being advanced inside the loop, so every stop
would have been costed as travel-to-first-stop. The analyzer's
`prefer_final_locals` hint on the never-reassigned variable is what caught it.

### Persistence

Schema 187 -> 188: `dive_plans.intermediate_ascent_rate`,
`shallow_ascent_rate` and `final_ascent_rate`, all NOT NULL with the standard
defaults, following the idempotent `_assertPlanAscentRateColumns` pattern
(PRAGMA-guarded helper called from both the ladder rung and the `beforeOpen`
backstop, as `_assertTravelGasColumn` does). `.subplan` gains all three keys
and defaults them when absent.

An existing saved plan therefore picks up 6, 3 and 1 on next open and its
schedule redistributes. That is the intended behaviour, but it is a visible
change to plans a diver has already reviewed.

While adding the Rates controls it turned out `DivePlanState` never carried
`lastStopDepth` at all, so a plan opened from a `.subplan` with a 6 m last
stop silently reset to 3 m on the way back out. The final-ascent label needs
the depth, so the field is now carried and mapped both ways - a small
pre-existing data-loss bug fixed in passing.

### What is still different from Subsurface

Measured on the reference plan (50 m / 30 min, air + EAN50, GF 50/80 in both
apps):

| | Stops | Travel | Runtime |
| --- | --- | --- | --- |
| Subsurface | 42 | 14 | 91 |
| Before part F | 52 | 6 | 93 |
| After part F | 50 | 11 | 96 |

Travel is close now, and the runtimes track stop for stop down to the 9 m
level (57 against 56). The divergence is all at the last two stops - 6 m: 12
against 10; 3 m: 22 against 18 - and it is *not* the ascent rates.

It is the stop-clearance criterion. Subsurface's `trial_ascent` simulates the
ascent to the next level, loading tissue at each step and checking the ceiling
as it goes, so the travel's own off-gassing counts toward clearing the stop
the diver is leaving. Ours asks whether the ceiling is already above the next
level before any travel happens. Part F actually *widens* this gap at the
last stop, because the leg it credits is now three minutes of off-gassing at
1 m/min rather than twenty seconds at 9 m/min: 18 min at 3 m plus a 3 min
crawl is close to our 22 min at 3 m plus 3 min.

Adopting Subsurface's criterion closes most of the remaining five minutes,
and it is arguably the more faithful model - it is what the diver actually
does. It is a schedule-wide change in the *less* conservative direction, so it
was held for the diver's explicit decision rather than folded into an
ascent-rate feature. The diver gave it; part G does it.

### Out of scope for part F

The dive log's own TTS, which keeps a single ascent rate: these are planning
inputs, and a logged dive's ascent already happened at whatever rate the
samples record.

Per-band rates relative to mean depth, Subsurface's actual model. TDI's named
phases cover the diver's intent without asking them to think in fractions of a
number the plan has not computed yet.

Making `shallowStopDepth` configurable. It is 9 m by convention and the
standard treats it as fixed; a diver who wants to move it can say so and it
becomes a fifth control plus a fourth column.

## Part G - Trial ascent, whole-minute stops, and the plan as a slate

Three changes the diver asked for together after comparing the reference plan
against Subsurface's "Dive plan details" table line by line.

### G1. Stop clearance by trial ascent

`_calculateStopTime` in `lib/core/deco/buhlmann_algorithm.dart` no longer
asks whether the ceiling is already above the next level. It asks whether the
diver *could ascend there now*: `_trialAscentClears` simulates the leg to the
next level - at the rate the policy gives that phase, on the gas eligible at
each depth, in slices of at most 10 s (the same resolution `BuhlmannGf`
loads ramps at) - and requires the ceiling to stay at or below the diver after
every slice. The last slice lands exactly on the next level, so arrival is
checked too, which is what the ceiling/schedule consistency tests rely on. The
tissue state is restored before the answer is returned.

This is Subsurface's `trial_ascent` for Buhlmann. The leg's own off-gassing
counts toward clearing the stop being left, because that is what happens to
the tissues in the water. The effect is largest at the last stop, where the
credited leg is three minutes at 1 m/min: on the reference plan it was worth
about four minutes at 3 m.

The Python golden generator mirrors it (`trial_clears`, `semantics_version`
3) and the vectors were regenerated; the clean-room TTS reference does the
same in its own idiom. On the flat-rate golden cases the change is one to two
minutes of TTS, and two cases lose a first stop that cleared during the
20 s leg to the next level - the same thing Subsurface's planner does, since
it never pre-places a first stop at all.

### G2. Stops end on whole minutes

Travel between stops rarely takes a whole number of minutes (3 m at 6 m/min
is thirty seconds), so every stop used to start and end at odd seconds and a
slate could not be read against a watch. `SchedulePolicy.snapStopsToWholeMinutes`
extends each held stop so it ends on a whole minute of the ascent clock: the
stop absorbs the odd seconds of the leg that led to it, at most 59 s more per
stop, always in the conservative direction. Subsurface does the same (its
first stop chunk is `DECOTIMESTEP - clock % DECOTIMESTEP`).

The flag is off by default, so live TTS in the dive log and on the profile
keep their exact values; `PlanEngine._policyFor` turns it on. Because the
snap lives inside `calculateDecoSchedule`, `calculateTts` inherits it and
the planner's TTS, runtime and table all agree. The one place this shows is
the legacy parity test, which now allows each stop to differ from
`PlanCalculatorService` by the rounding.

### G3. The plan table is a slate

`PlanOutcome.schedule` is a list of `PlanScheduleRow`: every authored leg,
then for the computed ascent a travel leg and a stop alternating, ending with
the leg to the surface. Each row carries its kind (descent, level, ascent,
stop), the depth it ends at, its duration, the runtime at its end, its gas and
tank, and whether the gas differs from the row before. Travel durations are
read off the stops' arrival times rather than recomputed, so a line can never
disagree with the stop it leads to, and `runtimeSeconds` on the outcome is the
last row's end so the headline can never disagree with the table.

A travel leg breathes the gas eligible where it starts - the diver switches
at the stop - so the table marks the switch on the stop's line, as
Subsurface's does. Only switches print in the gas column, highlighted.

Printing is the job of `scheduleLines` in
`lib/features/planner/domain/services/schedule_lines.dart`. The runtime is
rounded to the nearest minute and each printed duration is the difference
between consecutive printed runtimes, so the column always sums to the
runtime beside it. A line that takes any time prints at least one minute and
advances the runtime by at least one, so a thirty-second leg prints as 1 min
and the stop after it gives that minute back - a first version printed the
odd seconds, and the diver read 30 s as 30 min at a glance; a slate has one
unit. The results sheet and the PDF slate both use
it; the sheet prints Subsurface's glyphs (descent, level, ascent, stop) and
the PDF prints ASCII stand-ins because the embedded font has no arrows.

The column header changed from "Stop" to "Duration" in all eleven locales
(`plannerCanvas_table_duration` replaces `plannerCanvas_table_stop`), and
`PlanSlateLabels.stop` became `duration`.

### Reading Subsurface's own table

Subsurface's stop column looked odd to the diver: 21 m for 1 min, 18 m for
1 min. Two things are going on. First, its clock snaps to a whole minute at
the first stop, so a 47 s hold prints as one minute and the leg after it
starts on the minute. Second, in the diver's Subsurface preferences the rate
between stops is 3 m/min and the "last 6 m" rate of 1 m/min applies from the
6 m stop, so every leg between 3 m stops is exactly one minute and the leg
from 6 m to 3 m is three. Neither is the TDI table this app ships as its
default (6 m/min between intermediate stops, 3 m/min between shallow ones,
1 m/min off the last stop only). To compare the two apps line for line, set
this app's rates to 9 / 3 / 3 / 1; the two-minute 6 m to 3 m difference
remains, because a "last 6 m" band is not expressible as a phase.

## Part H - A last stop between 3 and 6 m

`DivePlan.lastStopDepth` existed, persisted and flowed into the schedule
policy, but nothing in the planner set it: every plan held its last stop at
3 m. The diver asked to choose it between 6 and 4 m as well.

The Decompression section gains a "Last stop" segmented control
(`PlanLastStopSelector`) offering 3, 4, 5 and 6 m (shown in the diver's depth
unit), under the gradient-factor sliders, wired to a new
`DivePlanNotifier.updateLastStopDepth` that clamps to that range. It first
sat in the Rates section next to the final-ascent slider; the diver asked for
it under Decompression, where the rest of the deco settings live. The
final-ascent slider's label still names the chosen depth.

The engine had assumed the last stop lay on the 3 m grid. `calculateDecoSchedule`
and `_calculateStopTime` now share `_nextLevel`: from a stop the diver goes to
the next grid level, or to the last stop when the grid would step past it, or
to the surface from the last stop itself. A 4 m last stop therefore gives the
grid down to 6 m and then 4 m. Two consequences worth naming: the first stop is
never placed shallower than the last stop, so a lightly loaded dive with a 6 m
last stop owes a stop at 6 m rather than nothing because 3 m fell below the
grid (a latent gap the old code had); and the Python golden mirror follows
the same rule, which leaves the vectors byte-identical because they all use
3 m.

## Localization

New keys, English plus the existing ten locales:

- `plannerCanvas_rates_intermediateAscent` - "Intermediate stop ascent rate"
  (part F)
- `plannerCanvas_rates_shallowAscent` - "Shallow stop ascent rate" (part F)
- `plannerCanvas_rates_finalAscent` - "Final ascent rate (last {depth})",
  the placeholder naming the last-stop depth the rate applies below (part F)
- `divePlanner_segmentEditor_depth` - "Depth ({unit})"
- `divePlanner_segmentEditor_derivedLevel` - "Level at {depth}"
- `divePlanner_segmentEditor_derivedDescent` - "Descent {from} -> {to} at
  {rate}/min"
- `divePlanner_segmentEditor_derivedAscent` - "Ascent {from} -> {to} at
  {rate}/min"
- `divePlanner_segmentEditor_derivedDescentNoRate` - "Descent {from} -> {to}"
- `divePlanner_segmentEditor_derivedAscentNoRate` - "Ascent {from} -> {to}"
- `divePlanner_tanks_savedSection` - "Saved tanks"
- `divePlanner_tanks_saveAsConfig` - "Save tanks as..."
- `divePlanner_tanks_saveAsConfigHint` - "Name this tank configuration"
- `divePlanner_tanks_configApplied` - "Applied {name}"
- `divePlanner_tanks_configSaved` - "Saved {name}"
- `divePlanner_tanks_configOverwrite` - "A configuration named {name} already
  exists. Replace it?"
- `divePlanner_tanks_manageConfigs` - "Manage saved tanks"
- `divePlanner_field_bailoutGas` - "Bailout gas"
- `divePlanner_field_bailoutGasHint` - "Open-circuit gas carried in case the
  loop fails"

There is no `stop` variant of the derived-phase line: telling a deco stop
from the bottom needs the rest of the profile, which the dialog does not have,
so it says "Level" for any flat leg and the segment list makes the finer call.
The `NoRate` pair covers a zero-duration leg, where the direction is known but
a rate is not defined.

Part C adds no strings: it reuses `divePlanner_label_tanks` and
`divePlanner_tab_plan` in their new positions.

Reused unchanged: `divePlanner_segmentList_descent`, `..._bottom`, `..._deco`,
`..._ascent`, and `..._gasSwitch` ("Gas switch to {gasName}"), which becomes
the per-leg switch chip.

Retired: `divePlanner_segmentEditor_segmentType`, `..._startDepth`,
`..._endDepth`, `..._descentRate`, `..._ascentRate`, `..._gasSwitchTime`,
`divePlanner_segmentList_safetyStop`, the six `divePlanner_segmentType_*`
labels the segment dropdown needed, and `divePlanner_field_role`.

## Testing

TDD; tests land before the change they describe.

**Part A - new**

Landed as `test/features/planner/segment_chain_test.dart` (21 cases),
`plan_engine_sac_phase_test.dart` and `dive_plan_legacy_rows_test.dart`.

- `test/features/planner/segment_chain_test.dart` - phase derivation table:
  descent, ascent, level at max depth, flat leg shallower than max with
  nothing deeper after it (`stop`), flat leg in a multi-level profile that
  later goes deeper (`level`), zero-duration leg (null rate), first leg starts
  at 0, single-leg plan, empty list.
- `bottomLegIndex` for single-level, multi-level, equal deepest legs (last
  wins), a profile with no level leg at all (null), and stops ignored. Folded
  into the same file rather than a separate one.

**Part A - behaviour-preservation, the load-bearing tests**

- `test/features/planner/plan_engine_sac_phase_test.dart` - guards the
  `plan_engine.dart:588` rewrite by perturbing one SAC rate at a time and
  checking exactly which legs move: raising the bottom SAC by 1 L/min must add
  precisely the descent and level legs' bar-minutes and nothing else, and
  raising the deco SAC must move at least the authored ascent and stop legs.
  Asserting deltas rather than a single total means an unrelated engine change
  cannot make it fail spuriously.
- `test/features/planner/dive_plan_legacy_rows_test.dart` - inserts rows the
  way the segment-type era wrote them and checks: a stored `start_depth`
  discontinuity resolves to a continuous profile (an intentional behaviour
  *change*); a row whose `type` is unrecognised loads instead of throwing; and
  re-saving rewrites `type`/`start_depth`/`rate` from the chain, so the
  retired columns stay truthful and the repair is durable.
- Existing suites that must keep passing unchanged:
  `plan_engine_per_segment_test.dart`, `plan_engine_schedule_test.dart`,
  `plan_engine_rates_test.dart`, `plan_engine_issues_test.dart`,
  `plan_engine_ccr_test.dart`, `plan_compare_test.dart`,
  `dive_plan_entity_test.dart`, `dive_plan_state_mapper_test.dart`,
  `dive_plan_sync_round_trip_test.dart`, `plan_gas_consumption_test.dart`.
- `plan_file_codec` tests: v1 file decodes (type and `startDepth` ignored), v2
  round-trips, v2 preserves `setpointBar` and `diveModeOverride`.
- Widget: `segment_editor` shows one depth field and no type dropdown; editing
  a segment preserves its setpoint; a chart drag preserves setpoint and mode
  override (regression for
  `plan_chart_edit_controller.dart:99-111`).

**Part C**

Nothing currently pins the order of these two widgets - `plan_panes_test.dart:
56-57` and `plan_canvas_page_test.dart:79-93` assert only that each is
present - so the swap must arrive with tests that would have caught it:

- `plan_panes_test.dart` gains an order assertion on `PlanEditorPane`,
  comparing the vertical offsets of `PlanTankList` and `SegmentList` rather
  than their mere presence.
- `plan_canvas_page_test.dart:79` currently expects `SegmentList` on a
  default-state phone load and **will fail** after the swap; it becomes
  `PlanTankList`. This is the one existing test part C breaks.
- `plan_canvas_page_test.dart:82` ("phone tabs switch between plan, tanks,
  setup, results") taps by label text, so it keeps passing; its name and the
  order of its taps are updated to match the new deck.
- A new case asserts the deck's segment labels read Tanks, Plan, Setup,
  Results left to right.
- Regression: tapping the issues chip still lands on Results, and a Setup
  header chip deep-link still lands on Setup - the two hardcoded tab indices.

**Part D**

- `test/features/planner/tank_role_resolver_test.dart` - the derivation table:
  deepest leg's cylinder is the back gas (including when it is not the last
  leg), richer-than-bottom is deco, same-or-leaner is stage, a travel gas is
  never the back gas, no segments falls back to the first cylinder; on a loop
  plan pure O2 is the supply, the breathed cylinder the diluent, the rest
  bailout; an explicit bailout flag beats the pure-O2 derivation and is
  honoured on OC too; `apply` rewrites a copy and leaves the stored roles
  alone.
- `contingency_service_test.dart` - three tests rewritten to the new
  invariants rather than deleted: every cylinder but the back gas is losable,
  the cylinder the bottom breathes is never offered as lost, and a plan always
  has a back gas to fall back onto.
- `segment_chain_test.dart` - runtime accumulates across legs,
  `startRuntimeSeconds` is the leg's start, and a zero-duration leg does not
  advance the clock.
- `segment_list_selection_test.dart` - the rows render `RT 2'` and `RT 22'`
  for a 30 m / 20 min quick plan.

**Part B**

- `test/features/cylinder_configs/dive_tank_config_adapter_replace_test.dart` -
  `replace` carries gas mix, material and working pressure; discards prior
  tanks; empty item list.
- `test/features/cylinder_configs/tank_config_capture_test.dart` - field
  mapping, order preservation, null hardware fields, and a
  capture -> replace round trip that is lossless for every configuration
  field.
- `test/features/planner/plan_tank_list_configs_test.dart` - the saved-tanks
  row is absent with no configurations; applying replaces the tank list;
  applying reassigns orphaned segments and refreshes their gas; saving prompts
  for a name and writes a config; duplicate name offers overwrite.

**Part F - ascent rates**

- `test/core/deco/schedule_policy_test.dart` - the band selection table:
  the three banded rates defaulting to the single ascent rate (including
  *across* boundaries, so 30 m at 9 m/min stays 30 m at 9 m/min), each of the
  four phases in isolation, a leg spanning several bands being split, a
  partial band prorated, a 6 m last stop moving the crawl boundary, a whole
  ascent totalling exactly the sum of its legs, and level or descending legs
  costing nothing. Replaces the `ascentRateForDepth` group, whose subject no
  longer exists.
- `test/features/planner/plan_engine_ascent_rates_test.dart` - the engine
  behaviour a diver would notice: travel between stops slowing from 30 s to
  60 s as the stops cross 9 m, a no-deco ascent still banded despite having no
  stops to leave from, stop time falling when the ascent itself decompresses,
  and setting all four bands equal reproducing the old single-rate arithmetic
  exactly.
- `test/core/database/migration_v188_plan_ascent_rates_test.dart` - all three
  columns on a fresh database, NOT NULL with the standard defaults pinned by
  value (a wrong default silently rewrites every saved plan's schedule), the
  `beforeOpen` backstop healing a database stranded before v188, and the
  helper no-opping when the table is absent. Mirrors the v156 travel-gas
  test. Renumbered from v185 (itself renumbered from v184): main landed the
  dive_detail_layout, template-item-equipment and
  session-item-overdue-services rungs at 185-187 while this branch was open.

**Part E - the deco core**

- `test/core/deco/` in full: 424 tests, including the golden vectors and the
  VPM-B suite, all passing.
- `scripts/deco_golden/generate_vectors.py` carries the same two corrections
  and `semantics_version` goes 1 -> 2. Regenerated per the README, never by
  hand. Note what this suite does and does not prove: the generator is a
  second implementation of the *same* semantics, so agreement is a
  cross-implementation regression check, not independent validation of the new
  behaviour. It caught nothing here because it was updated in lockstep.
- `tts_cleanroom_cross_check_test.dart` is the one place a genuinely
  independent reference lives, and it had encoded the old ordering on purpose.
  Corrected to check-first and to the fixed-point ceiling; it now agrees with
  production to within its 60 s tolerance, having been 120 s out.
- The two Subsurface-referenced fixtures both still pass, but see the table
  under "What E3 changes": the ceiling reference got worse and the TTS
  reference got marginally better. Neither settles the question. The one
  unambiguous external agreement is on E1: the diver's own planner puts deco
  onset at runtime 37 for GF-high 80, which is now exactly what we report.
- `test/core/deco/ceiling_schedule_consistency_test.dart` pins the invariants
  rather than the numbers: the diver never *arrives* at a level shallower than
  the ceiling (arrival, not the ceiling standing when the schedule is
  computed - the ascent legitimately off-gasses on the way), a stop that
  clears inside its first minute is still recorded, and the surface target
  stays distinguishable from the GF ceiling. Both of its headline assertions
  fail against the old code.
- The release gate in the golden README - a hand comparison against MultiDeco -
  is the right place to settle the ceiling convention before this ships.

## Risks

- **Every deco schedule changes (part E3).** Not a planner-only change:
  `getDecoStatus` feeds dive details, so a logged deco dive reopened after
  this lands shows a deeper first stop and a slightly longer TTS than it did
  before. The direction is more conservative in every case measured, and the
  old numbers were wrong in the unsafe direction - stops were dropped that the
  tissues required. Needs a release note, and the MultiDeco comparison should
  happen before it ships rather than after.
- **The ceiling number itself moves (part E3).** A diver on the bottom of a
  deco dive previously saw the GF-low ceiling; they now see a shallower
  figure. That will read as "less deco than before" at a glance, when in fact
  the obligation grew. The stop schedule is the honest display and it is what
  the plan results and the profile chart lead with, but the standalone ceiling
  readouts in `deco_info_panel` and `compact_deco_status_card` will look
  different.
- **Silent profile change on discontinuous saved plans.** Repairing the depth
  chain alters the computed deco for any plan that had a gap. This is the
  intended fix, but a diver could reopen a saved plan and see a different TTS.
  Mitigation: the chart already draws the gap today, so the plan visibly looked
  wrong; and `plan_engine_discontinuity_repair_test.dart` pins the new
  behaviour. Worth a release note.
- **Hand-authored deco stops in the bottom portion.** A diver who today adds
  an explicit Deco Stop segment gets `sacDecoEffective`; under phase derivation
  a flat leg at max depth reads as `level` and gets `sacBottom`. Only affects a
  flat leg *at* the deepest point, which is not a deco stop in any real
  profile. Accepted.
- **`.subplan` forward compatibility.** A v2 file opened by an older build
  hits `plan_file_codec.dart`'s version check and is rejected rather than
  misread. Acceptable; the check exists for this reason.
- **Losing the explicit gas-switch row.** Divers who used gas-switch segments
  as a visual marker lose the dedicated row. Mitigated by the per-leg switch
  chip, which is strictly more accurate since it renders from the `tankId` the
  engine actually charges.
- **Configuration name collisions.** `cylinder_configs.name` is not unique.
  Handled by the overwrite prompt rather than a schema constraint.
- **Wider lost-gas output (part D).** Because every non-back-gas cylinder is
  now losable, a plan carrying several bottles produces more contingency
  variants than before, each of which runs the engine. Range tables already
  run many more variants than this, so the cost is not new, but a plan with
  five cylinders now computes four lost-gas schedules where it might have
  computed one.
- **A stored role from before part D is ignored** except when it is
  `bailout`. A plan saved with a hand-picked `oxygenSupply` or `deco` role
  gets that role re-derived, which for any coherent plan reproduces the same
  answer - but a plan whose declared roles contradicted its mixes will now
  compute differently, and more correctly.

## Out of scope

- Deleting the legacy `lib/features/dive_planner/` module. It remains the home
  of `PlanSegment`, `PlanResult` and `DivePlanNotifier`, all of which the
  current planner imports. Consolidating the two modules is a separate change.
- Auto-generated ascent profiles and repetitive dives (issue #142).
- Planner total dive time display (issue #545).
- Unifying `tank_presets` with equipment cylinders (the rest of issue #800).
- Any change to `CylinderConfigApplier`'s merge rules or to the dive edit
  page's apply flow.
