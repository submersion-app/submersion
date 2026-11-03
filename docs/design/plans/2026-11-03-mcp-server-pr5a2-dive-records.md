# MCP server PR 5a, part 2: the rest of a dive's records Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An agent can change the rest of what a diver can change on a dive: custom fields, their own roles, gas switches as the dive editor shows them, annotations, and Dive Lab scenarios. With PR 5a, a dive is then fully writable.

**Architecture:** Custom fields, gas switches, annotations and scenarios are child entries of `dives`, using PR 5a's child machinery. Diver roles become a relation on `dives`, written through the bulk edit service as tags are. Each writes through the same path the app's own screen uses.

**Spec:** `docs/design/specs/2026-11-01-mcp-server-design.md`, "Writes". PR 5a plan: `docs/design/plans/2026-11-03-mcp-server-pr5a-dive-children.md`.

## Global Constraints

PR 4's and PR 5a's: preview opens no transaction, writes go through repositories or services, everything stays behind debug mode, no em-dashes, no attribution, `Refs #4071`.

## The line (Eric, 2026-11-03)

An agent can change exactly what a diver can change in the app, and nothing a computer recorded that the app itself protects.

- **Gas switches:** the ones the dive editor shows, the dive's primary computer's and untagged ones, through `DiverGasSwitchWriter`, the editor's own writer. Another computer's switches are blocked.
- **Profile events:** annotations only, through `AnnotationRepository`. An event a computer recorded is blocked.
- **Custom fields, diver roles, scenarios:** in full.

## Rulings (my calls, recorded as design rows in the spec)

- `dive_events` is writable for annotations only: a create is always an annotation; an update or delete of any other type is blocked with `not_permitted`. An annotation's words live in the dive's Notes, so a create appends a linked paragraph there and a delete turns the link back into plain words, as the app does. `description` is create-only: rewording an annotation is a Notes edit. A move without `depth_m` keeps the stored depth (`moveAnnotation` would clear it).
- An annotation create or delete in a set that also updates its dive is blocked: both write the dive's Notes, and whichever ran second would undo the other. The entry says so with `WritableEntry.writesParent`.
- A gas switch change goes through `DiverGasSwitchWriter.save` with the editor's view of the list, so it also marks the dive's switches as diver-owned (a re-parse leaves them) and drops the stored safety review, as an editor save does. `tank_id` must be a tank of the same dive. A new time with no `depth_m` takes the profile's depth at that time, as the editor fills it, and the plan lists it as indirect.
- Custom fields write one row at a time on `DiveChildRowRepository`, with sync marks and a dive stamp, as `updateDive`'s diff does (the repository's own `replaceFieldsForDive` marks nothing for sync). A key must not be blank, as the editor drops blank keys.
- Scenarios write through `DiveScenarioRepository.saveScenario` and `deleteScenario`. `interventions` takes the list documents return; it is decoded with the Dive Lab codec and checked with `validateInterventions`. Defaults: `mode` `replay`, `branch_s` 0.
- Diver roles are a `roles` relation on `dives`, written with `DiverRolesOp`. The primary role stays first unless removed; added roles follow in the order given.
- **Follow-up, Notes and annotations:** an agent's update of a dive's `notes` now runs `AnnotationRepository.reconcile`, as the editor's save does, so an annotation whose link the new Notes drop is deleted rather than left on the profile, and the cached words follow. The plan lists the annotations it deletes as parts (`SideEffects.parts`).

## File map

```
lib/features/dive_log/data/repositories/dive_child_row_repository.dart   + custom field rows
lib/features/agent_access/data/writes/
  writable_entity.dart                 writesParent, SideEffects.parts
  write_planner.dart / _children.dart  writesParent block, effect parts into reach
  families/custom_field_writes.dart    families/gas_switch_writes.dart
  families/annotation_writes.dart      families/scenario_writes.dart
  families/dive_writes.dart            roles relation, notes reconcile
  write_catalog.dart
lib/features/agent_access/data/tools/preview_changes_tool.dart
test/architecture/agent_write_coverage_test.dart, baseline
```

---

### Task 1: Custom field rows

- [ ] `addCustomField`, `updateCustomField`, `deleteCustomField` on `DiveChildRowRepository`, each marking its row pending in the same block and stamping the dive. Tests first.
- [ ] `CustomFieldWrites` (`dive_custom_fields`): `dive_id`, `key` (text, 100), `value` (text, blank allowed), `sort_order` (0 to 999, default one past the highest). Tests: every field reaches its column, a blank key is blocked, revert restores a deleted field.
- [ ] Commit `feat(agent-access): write a dive's custom fields`.

### Task 2: Diver roles

- [ ] `roles` relation on `DiveWrites` (`dive_roles`), current from `DiveRoleLinkRepository.diverRoleIdsForDives`, written as one `DiverRolesOp` with the new ordered list. Tests: add keeps the primary first, remove of the primary promotes the next, another profile's custom role is blocked.
- [ ] Commit `feat(agent-access): write a dive's diver roles`.

### Task 3: Gas switches

- [ ] `GasSwitchWrites` (`gas_switches`): `dive_id`, `t_s` (0 to 172800), `tank_id` (reference to `dive_tanks`), `depth_m` (0 to 350, nullable). `refuse` blocks another computer's switch and a tank of another dive. `sideEffects` fills depth from the profile for a moved switch. Writes rebuild the editor's list and call `DiverGasSwitchWriter.save`.
- [ ] Tests: create, move with the depth filled, delete, another computer's switch blocked, `gas_switches_edited` set, revert.
- [ ] Commit `feat(agent-access): write a dive's gas switches`.

### Task 4: Annotations

- [ ] `writesParent` on `WritableEntry` and the planner block. `AnnotationWrites` (`dive_events`): `dive_id`, `t_s`, `depth_m`, `description` (required, create-only, 500).
- [ ] Tests: a create links its words in Notes, a move keeps the depth, a delete unlinks the words, a computer event is blocked, a create beside an update of its dive is blocked.
- [ ] Commit `feat(agent-access): write a dive's annotations`.

### Task 5: Scenarios

- [ ] `ScenarioWrites` (`dive_scenarios`) with an interventions codec. Tests: create, update keeps what it does not name, invalid interventions blocked, delete and revert.
- [ ] Commit `feat(agent-access): write a dive's Dive Lab scenarios`.

### Task 6: Notes reconcile (follow-up)

- [ ] `SideEffects.parts`, carried into the item's reach. `DiveWrites`: a `notes` change lists the annotations whose links it drops, and `update` runs `reconcile` after the bulk edit. Tests: dropping a link deletes its annotation and the plan said so; rewording a link refreshes the cached words.
- [ ] Commit `fix(agent-access): keep annotations in step with an agent's Notes edit`.

### Task 7: Coverage, description, docs

- [ ] Move every reached method to `covered`, regenerate the baseline.
- [ ] `preview_changes` description: annotations only, words in Notes; gas switches as the editor shows them.
- [ ] Spec decision rows; developer guide; run format, whole-repo analyze, `test/features/agent_access`, `test/features/dive_log/data`, `test/architecture`, `test/shared`, and agent access under `TZ=Australia/Sydney`.
- [ ] Commit `docs(agent-access): document the rest of a dive's writes`.
