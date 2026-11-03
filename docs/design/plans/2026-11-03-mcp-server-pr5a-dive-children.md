# MCP server PR 5a: dive children Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An agent can add, change and remove a dive's tanks, weights and sightings one record at a time, and link equipment and courses to a dive, through the same preview, confirm and apply flow PR 4 built.

**Architecture:** Tanks, weights and sightings become write entities of their own, under the read catalogue's names (`dive_tanks`, `dive_weights`, `sightings`). They are child entries: each names its dive in `dive_id`, takes that dive's profile as its owner, and stays on that dive. Equipment and courses become relations on `dives`, written through the bulk edit service's `EquipmentOp` and `DiveCoursesOp`, as tags are.

**Tech Stack:** Flutter, Drift, Riverpod, `mcp_dart` behind the existing adapter.

**Spec:** `docs/design/specs/2026-11-01-mcp-server-design.md`, section "Writes". PR 4 plan: `docs/design/plans/2026-11-02-mcp-server-pr4-write-core.md`.

## Global Constraints

All of PR 4's constraints hold: preview opens no transaction, the server never writes a table directly, writes run inside `SyncCoordinator.run` and `ChangeLogScope.run`, apply is all or nothing, everything stays behind `agentAccessAvailableProvider`, no em-dashes, no attribution, `Refs #4071`.

## Scope

In: write entities `dive_tanks`, `dive_weights` and `sightings` (create, update, delete); dive relations `gear` and `courses`; the planner support child entries need; per-row tank and weight writes on a new repository; the coverage guard entries for every method these reach.

Out, for later PRs in the series: custom fields, diver roles, gas switches, profile events and scenarios on a dive (they need repository work of their own); writes to `species`, `equipment` and `courses` themselves (5b, 5d, 5e); a tank's gear links (`equipment_id`, `regulator_equipment_id`), which come with equipment in 5b.

## Rulings

Eric approved one-record-at-a-time writes for tanks, weights and sightings, by the ids `get_records` returns (2026-11-03, "proceed"). The rest are my calls, recorded as design rows in the spec's decision record in Task 7.

- A child's owner is its dive's owner. A create names the dive in `dive_id`; `diver_id`, if given, must be that dive's owner. `dive_id` cannot change after a create: moving a tank is a delete and a create.
- A sighting keeps its species. The app's own sighting update writes only count and notes, so `species_id` is create-only too.
- A child has no `updated_at`. Its version marker is its dive's `updated_at`, which every child write path bumps (`_bumpDives`, `updateDive`, the sighting methods), plus a footprint of the child's own document, which catches a change that reached the child row alone, such as a sync merge.
- An operation on a child whose dive the same set deletes is blocked. The dive's delete takes its children with it, and running the child operation first or second would either be redundant or fail.
- Tank and weight writes go through a new `DiveChildRowRepository` with one method per row write, so an edit touches one row: `bulkReplaceTanks` would re-insert every tank under fresh ids and destroy pressure series and gas switches, and `updateDive` rewrites the whole dive from an entity. The tank delete removes the tank's pressure series through `TankPressureSeriesRepository.deleteForTank` (tombstoned) and logs its gas switches' tombstones, as `updateDive` does.
- Sightings write through `SpeciesRepository.addSighting`, `updateSighting` and `deleteSighting`, unchanged.
- Gas: `o2_fraction` from 0.05 to 1, `he_fraction` from 0 to 0.95, and their sum at most 1, judged on the tank as it would be after the change. The app's tank editor accepts any number; an agent is held to mixes a diver could breathe.
- A weight label is stored trimmed and capped by `normalizeWeightLabel`. A label with surrounding spaces is blocked rather than written differently from what the plan shows.
- Adding an assembly to a dive's `gear` adds its active parts, and removing an item removes everything attached through it, as the bulk editor does. The plan lists those parts as indirect, both the ones gained and the ones lost, so `SideEffects` gains a `lost` map.
- Planning-only tank fields (`deco_switch_depth_m`, `is_travel_gas`) and import-owned ones (`computer_id`, `transmitter_serial`, `usage_duration_s`, `trip_cylinder_id`) stay read-only.

## Review Focus

1. A tank edit leaves every other tank of the dive, its pressure series and its gas switches as they were.
2. A child of another profile's dive is changed under that profile, and a create naming another `diver_id` is blocked.
3. Deleting a tank lists its gas switches and pressure series in the plan, and a revert brings all three back.
4. Adding an assembly to `gear` lists its parts as indirect, and a template change between preview and apply refuses the plan as stale.

## File map

```
lib/features/dive_log/data/repositories/dive_child_row_repository.dart   per-row tank and weight writes
lib/features/agent_access/data/writes/
  writable_entity.dart        ChildOf, createOnly, SideEffects.lost
  field_codec.dart            FieldCodec.reference
  write_planner.dart          child rows, owners, markers, references
  write_planner_children.dart the child rules, as a part file (the planner is at the size limit)
  families/tank_writes.dart   families/weight_writes.dart   families/sighting_writes.dart
  families/dive_writes.dart   gear and courses relations
  write_catalog.dart          the three entries
lib/features/agent_access/data/tools/preview_changes_tool.dart   the child rule in the description
test/architecture/agent_write_coverage_test.dart, agent_write_coverage_baseline.txt
```

Tests mirror these paths. Child planner tests go in a new `write_planner_children_test.dart`, as `write_planner_test.dart` is near the 800-line limit.

---

### Task 1: Per-row tank and weight writes

**Files:** create `lib/features/dive_log/data/repositories/dive_child_row_repository.dart`, test `test/features/dive_log/data/repositories/dive_child_row_repository_test.dart`.

`DiveChildRowRepository({AppDatabase? database})`, built like `TankRoleRepairRepository`, with `SyncRepository` and `TankPressureSeriesRepository`. No method opens a transaction or notifies; the applier owns both.

- `Future<String> addTank(String diveId, DiveTanksCompanion values)`: fresh id, `tankOrder` the count of the dive's tanks when absent, marks the tank pending, bumps the dive. Returns the id.
- `Future<bool> updateTank(String tankId, DiveTanksCompanion values)`: writes only the present columns. A present `tankRole` clears `roleSource`, as `_tankSpecsCompanion` does (#2595). Marks pending, bumps the dive. False when the tank is gone.
- `Future<bool> deleteTank(String tankId)`: deletes the tank's pressure series with `deleteForTank`, reads its gas switches, deletes the tank, logs the tank's tombstone and the switches', bumps the dive.
- `Future<String> addWeight(String diveId, DiveWeightsCompanion values)`, `updateWeight`, `deleteWeight`: the same shape. The label goes through `normalizeWeightLabel`.

- [ ] **Step 1:** Tests: an add appends after existing tanks and leaves them alone; an update writes only named columns and keeps start and end pressure; a role change clears the role source; a delete removes the tank's series and switches and tombstones all three; the dive's `updated_at` moves for each; a missing row returns false. The same for weights.
- [ ] **Step 2:** Run them red, implement, run them green.
- [ ] **Step 3:** Commit `feat(dive-log): add per-row tank and weight writes`.

### Task 2: Child entries in the write core

**Files:** `writable_entity.dart`, `field_codec.dart`, `write_planner.dart`, tests in `field_codec_test.dart` and the new `write_planner_children_test.dart`.

- `class ChildOf { const ChildOf({required this.entity, required this.field}); }`: the parent's write and read entity name, and the field that names it, which is also the column. `WritableEntry.parent` defaults to null.
- `WritableEntry.createOnly` (default empty): fields a create may set and an update may not change. Naming one with a different value blocks the update with `not_permitted`; naming it with the same value is unchanged.
- `FieldCodec.reference(String refEntity)`: a non-blank id string. After parsing, the planner checks every reference field it is given with the same visibility rule relations use (`_checkRefs`, reworked to take the entity name and a label).
- `loadRows` for a child entry reads `c.id, p.diver_id, p.updated_at, c.<field>` from the child joined to its parent. The row keeps the parent id.
- A child update or delete marks the parent row (`table` the parent's, its `updated_at`) and footprints the child's document. A create marks the parent row it names, so a dive deleted before apply refuses the plan.
- A create of a child resolves its owner from the parent: unknown dive blocks with `unknown_reference`, a `diver_id` other than the dive's owner blocks with `invalid_value`, a dive the set deletes blocks with `reference_deleted`.
- An update or delete of a child whose dive the set deletes blocks with `reference_deleted`.

- [ ] **Step 1:** Codec tests for `reference`. Planner tests with the real tank entity from Task 3 written first as a stub: owner from the dive across profiles, create without `diver_id`, create naming another profile, unknown dive, `dive_id` changed on update, a child of a deleted dive, the marker naming the dive, a stale plan when the tank alone changed.
- [ ] **Step 2:** Implement, green.
- [ ] **Step 3:** Commit `feat(agent-access): plan writes to records that belong to a dive`.

### Task 3: Tanks

**Files:** create `families/tank_writes.dart` (`TankWrites`), test `tank_writes_test.dart`, with a shared `child_write_harness.dart`.

Fields: `dive_id` (reference, required, create-only), `name` (text, 100, nullable), `volume_l` (0 to 60), `working_pressure_bar`, `start_pressure_bar`, `end_pressure_bar` (0 to 450, nullable), `o2_fraction` (0.05 to 1), `he_fraction` (0 to 0.95), `role` (`TankRole`), `material` (`TankMaterial`, nullable), `order` (0 to 99), `preset_name` (text, 60, nullable). Fractions are stored as percentages. `refuse` checks the mix on the tank after the change. `deleteReach` counts the tank's gas switches and pressure series as parts. `titleOf` is the name, else the preset, else the mix.

- [ ] **Step 1:** Tests: every codec key reaches a column; a create carries defaults (air, `backGas`); an o2 and he summing over 1 is blocked, including when only one is named; delete reach.
- [ ] **Step 2:** Implement, green. Register in `WriteCatalog`.
- [ ] **Step 3:** Commit `feat(agent-access): write a dive's tanks`.

### Task 4: Weights

`DiveWeightWrites`: `dive_id`, `type` (`WeightType`, default `belt`), `amount_kg` (0 to 60, required on create), `label` (text up to `weightLabelMaxLength`, blank allowed, blocked when not trimmed), `notes` (blank allowed).

- [ ] Tests, implement, register, commit `feat(agent-access): write a dive's weights`.

### Task 5: Sightings

`SightingWrites`: `dive_id`, `species_id` (reference to `species`, required, create-only), `count` (1 to 100000, default 1), `notes`. Writes through `SpeciesRepository`. `titleOf` is the species name.

- [ ] Tests (a species another profile owns is blocked; a built-in species is fine), implement, register, commit `feat(agent-access): write a dive's sightings`.

### Task 6: Gear and courses on a dive

`DiveWrites.relations` gains `gear` (`equipment`) and `courses` (`courses`). `currentRelation` reads `dive_equipment` and `dive_courses`. `_ops` maps them to `EquipmentOp` and `DiveCoursesOp` add and remove. `sideEffects` works out the gear expansion read-only with `GearExpander` over the components index and the active ids, and lists parts gained in `relations` and parts lost in the new `SideEffects.lost`; the plan item shows both under `indirect_relations`.

- [ ] Tests: add and remove courses; add an assembly lists its active parts as indirect and writes them; remove an item lists its attached parts as lost; equipment of another profile is blocked; a template change after preview refuses the plan. Implement, commit `feat(agent-access): link equipment and courses to a dive`.

### Task 7: Coverage, description and docs

- [ ] Move every method these entities reach from the baseline to `covered` (`addTank`, `updateTank`, `deleteTank`, `addWeight`, `updateWeight`, `deleteWeight`, `addSighting`, `updateSighting`, `deleteSighting`, `bulkAddEquipment`, `bulkRemoveEquipment`, `bulkAddCourses`, `bulkRemoveCourses`) and regenerate the baseline.
- [ ] `preview_changes` description: a record that belongs to a dive names it in `dive_id` when created, takes that dive's profile, and stays on it.
- [ ] Spec decision record: the rulings above as design rows, and Eric's row for one record at a time. `docs/developer/agent-access.md`: child entries and how to add one.
- [ ] Run `dart format .`, `flutter analyze`, `test/features/agent_access`, `test/features/dive_log/data`, `test/architecture`, `test/shared`, and `test/features/agent_access` under `TZ=Australia/Sydney`.
- [ ] Commit `docs(agent-access): document dive children writes`.
