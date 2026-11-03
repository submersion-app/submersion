# MCP server PR 5c: gear Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in one session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An agent can create, edit and delete the diver's gear (items with their attributes, tags and shares; sets with their members and geofences; storage places and the moves between them; assembly components) exactly as the app's own gear screens allow, and the plan lists everything a gear write does beyond its fields.

**Architecture:** Each gear entity is a `WritableEntry` under `lib/features/agent_access/data/writes/families/`, registered in `WriteCatalog`, writing through the repository its screen uses. The write core learns two generic reports first: rows a create adds alongside the record (`WritableEntry.alsoCreates`) and rows of other records an update rewrites (`SideEffects.touched`), each with a line in the confirm dialog. Status shortcuts and the inner steps of an item delete go in the coverage guard's `exempt` map.

**Tech Stack:** Flutter, Drift, flutter_test against a real test database (`setUpTestDatabase`), the write harness `test/features/agent_access/data/writes/child_write_harness.dart`.

**Spec:** `docs/design/specs/2026-11-01-mcp-server-design.md` ("Writes", "Coverage and release gate"). The design for this PR was approved in conversation on 2026-11-03: the equipment family splits in two, and this PR is the gear half; service kinds, records and schedules, observations, cylinder fills and transmitters are PR 5d.

## Global Constraints

- An agent changes exactly what a diver can change in the app, through the repository method the app's screen calls.
- Entity names and document keys are the read catalogue's (`gear_records.dart`, `gear_documents.dart`).
- Writes act as the record's owner, as in PRs 4 to 5b. Only the owner's agent may delete an item or manage its shares (`canDeleteEquipment`, `canShareEquipment`).
- `last_service_date` and `service_interval_days` are not writable: legacy columns with no editor, replaced by the service ledger (PR 5d).
- `is_active` is not writable; it follows `status`.
- Everything stays behind `agentAccessAvailableProvider` (debug mode) until PR 6. No schema change.
- Every commit and the PR say `Refs #4071`. No em-dashes, en-dashes or double hyphens as prose punctuation; no mention of the tooling that wrote the code.
- Files stay under 800 lines. `write_planner.dart` is at 774, so Task 1 splits it before anything is added.
- The branch is stacked on PR #4195 and targets main; rebase onto main once #4195 merges.

## Review Focus

1. **Sharing an item with its owner, with a profile that does not exist, or sharing an item that has no owner**: blocked in the preview, never a failure at apply. Test in Task 4.
2. **A component or a fitted part that would close a loop** (A in B and B in A, or a part fitted to itself through its parent chain): blocked as `invalid_value`. Tests in Tasks 3 and 7.
3. **Deleting a place any move names**: the repository throws; the plan must block it as `not_permitted` and say to archive it. Test in Task 6.
4. **Retiring an item, or taking it out of `wanted`**: the plan lists `is_active` false, or the purchase date it fills, as indirect fields. Test in Task 3.
5. **A set member the set's owner cannot see** (another profile's item with no share): blocked as `other_profile_reference`. Test in Task 5.

---

### Task 1: Make room in the planner, and exempt what is not a record

**Files:**
- Create: `lib/features/agent_access/data/writes/write_planner_relations.dart` (part of `write_planner.dart`)
- Modify: `lib/features/agent_access/data/writes/write_planner.dart`
- Modify: `test/architecture/agent_write_coverage_test.dart`, `test/architecture/agent_write_coverage_baseline.txt` (regenerated)

**Interfaces:**
- Produces: `extension _Relations on _Pass` holding `_relations`, `_delta`, `_checkRefs` and `_existing`, moved verbatim.

- [ ] **Step 1: Move** `_relations`, `_delta`, `_checkRefs` and `_existing` from `write_planner.dart` into the new part file as an extension, as `write_planner_references.dart` did. No behaviour change.
- [ ] **Step 2: Run** `flutter analyze lib/features/agent_access` and `flutter test test/features/agent_access/data/writes`. Expected: no issues, all pass; `write_planner.dart` under 700 lines.
- [ ] **Step 3: Add to `exempt`**, each with its reason:
  - `equipment_repository_impl.dart:retireEquipment`, `:setStatusForMany`, `:markEquipmentPurchased`, `:reactivateEquipment`: shortcuts for a status change, which `equipment` covers through `updateEquipment`.
  - `equipment_repository_impl.dart:createEquipmentWithTags`, `:updateEquipmentWithTags`: the edit page's save, which `equipment` covers as a field write plus a `tags` relation.
  - `dive_sensor_summary_repository.dart:*`, `equipment_service_status_repository.dart:*`: derived summaries, recomputed from dives and the service ledger.
  - `equipment_findings_repository.dart:*`: the review state of derived findings.
  - `cylinder_gear_links.dart:*`, `equipment_location_buddy_links.dart:*`, `equipment_location_center_links.dart:*`, `equipment_tag_repository.dart:deleteLinksForEquipment`, `equipment_share_repository.dart:deleteForEquipment`, `equipment_location_move_repository.dart:deleteForEquipment`: inner steps of a delete of their owner.
  Paths are under `lib/features/equipment/data/repositories/`; correct any the existence test rejects.
- [ ] **Step 4: Regenerate the baseline** with `UPDATE_AGENT_WRITE_BASELINE=1`, run again without it. Expected: PASS.
- [ ] **Step 5: Commit** `refactor(agent-access): split the planner's relation checks and exempt gear helpers`.

### Task 2: Report rows a create adds and records an update rewrites

**Files:**
- Modify: `writable_entity.dart`, `write_planner.dart`, `write_plan.dart`, `presentation/widgets/agent_write_confirm_dialog.dart`, `lib/l10n/arb/app_*.arb` (11 locales) and the generated localizations
- Test: `test/features/agent_access/data/writes/write_planner_test.dart`, `test/features/agent_access/presentation/widgets/agent_write_confirm_dialog_test.dart`

**Interfaces:**
- Produces: `Future<Map<String, int>> WritableEntry.alsoCreates(String diverId, Map<String, Object?> values)`, default `const {}`: rows of other tables the create adds, by table.
- Produces: `SideEffects.touched` (`Map<String, int>`): rows of other records the update rewrites, by table; part of `isEmpty` and `footprint`.
- Produces: `PlanItem.alsoCreates` and the update's `touched`, in JSON as `also_creates` and `also_changes`.
- Produces: l10n keys `settings_agentAccess_confirm_alsoAdds` ("Also adds {kind}: {count}") and `settings_agentAccess_confirm_alsoChanges` ("Also changes {kind}: {count}").

- [ ] **Step 1: Write the failing tests:** a planner test with a fake entry whose `alsoCreates` returns `{'service_schedules': 2}` expects `plan.items.single.alsoCreates == {'service_schedules': 2}` and the JSON key `also_creates`; one whose `sideEffects` returns `touched: {'dive_computers': 1}` expects the update planned (not unchanged) with that count. A dialog test expects "Also adds" and "Also changes" lines, in the summary and in the row.
- [ ] **Step 2: Run** them. Expected: FAIL on the missing members.
- [ ] **Step 3: Implement.** The summary sums them as it sums `moved`. Translate both keys into all 11 locales and run `flutter gen-l10n`.
- [ ] **Step 4: Run** the writes and presentation tests. Expected: PASS.
- [ ] **Step 5: Commit** `feat(agent-access): list rows a create adds and records an update rewrites`.

### Task 3: Gear items

**Files:**
- Create: `lib/features/agent_access/data/writes/families/equipment_writes.dart`, `test/features/agent_access/data/writes/equipment_writes_test.dart`
- Modify: `write_catalog.dart`, the coverage test's `covered`

**Interfaces:**
- Consumes: `alsoCreates`, `SideEffects.touched` (Task 2); `ObjectListCodec`, `FieldCodec.text(trim:)`, `appendSlotBlock`-style helpers from PR 5b.
- Produces: `class EquipmentWrites extends WritableEntry` (`name` and `table` `equipment`).

- [ ] **Step 1: Write the failing tests:**
  - `'an item is created, edited and deleted'`: create with name, type `regulator`, brand; update brand and notes; delete; the document reads each step.
  - `'retiring lists is_active, leaving wanted fills the purchase date'`: an update of status `retired` lists `is_active: true -> false` as indirect; a `wanted` item updated to `active` with no purchase date lists today's date as indirect, and apply stores both.
  - `'a create lists the service clocks it attaches'`: a `tank` create lists `alsoCreates` equal to the count `ServiceScheduleRepository().autoAttachForEquipment` adds for a tank (read the kinds flagged auto-attach for the type to compute it).
  - `'renaming a device item lists the device it renames'`: an item a dive computer names, renamed, lists `touched: {'dive_computers': 1}`.
  - `'attributes are replaced whole and a key must fit the type'`: a curated key from `EquipmentAttributeCatalog.attributesFor(type)` saves; a curated key of another type blocks as `invalid_value`; a custom attribute saves with `is_custom: true`; an unchanged list is no change.
  - `'a fitted part cannot be fitted to itself'`: `parent_equipment_id` naming the item, or its descendant, blocks as `invalid_value`.
  - `'legacy service fields and is_active are not writable'`: `last_service_date`, `service_interval_days` and `is_active` are refused as unknown fields.
  - `'only the owner deletes an item'` and `'a delete lists everything it takes'`: another profile's shared item delete blocks; a delete reach lists schedules, records, components, moves and shares under parts, and unlinked fills and cylinders.
- [ ] **Step 2: Run.** Expected: FAIL with `not_writable`.
- [ ] **Step 3: Implement `EquipmentWrites`:**
  - Fields: `name` text(100, trim), `type` enumName(EquipmentType), `brand`, `model`, `serial_number` nullable text, `status` enumName(EquipmentStatus), `purchase_date` calendar date nullable, `purchase_price` number(0..1e7) nullable, `purchase_currency` text(3) nullable, `notes` text(allowBlank), `custom_reminder_enabled` flag, `custom_reminder_days` a list of whole days (1..365, at most 10), `parent_equipment_id` reference('equipment', nullable), `attributes` ObjectListCodec of `key`, `is_custom` (default false), `value_text`, `value_num`, as the read document lists them.
  - Create and update go through `createEquipment` and `updateEquipment` with the whole entity rebuilt from the current item and the values; `is_active` is `status` not in {retired, sold}; leaving `wanted` with no purchase date fills today, as `markEquipmentPurchased` does. Both derived values reach the plan through `sideEffects.fields`.
  - `refuse`: a curated attribute key not in `attributesFor(type)`; a parent loop (walk `parent_equipment_id` up from the named parent; the item itself on the way blocks).
  - `alsoCreates`: the schedules `autoAttachForEquipment` would add for the type, plus one for a legacy interval (never, since the field is not writable).
  - `sideEffects.touched`: dive computers and transmitters whose name `_mirrorNameToDevices` would rewrite; service schedules an inspection-date attribute change re-anchors (`attributeServiceBaselines`).
  - Delete: `deleteOwnedEquipment(id, actingDiverId: owner)`; `deleteReach` counts by `countCascaded`/`countUnlinked` plus the device records (`records`) and the media split; `deletedDocumentOwners` is the item's documents.
- [ ] **Step 4: Run.** Expected: PASS. Add `createEquipment`, `updateEquipment`, `deleteEquipment`, `deleteOwnedEquipment`, `saveAttributes` to `covered`; regenerate the baseline.
- [ ] **Step 5: Commit** `feat(agent-access): write gear items`.

### Task 4: An item's tags and shares

**Files:**
- Modify: `equipment_writes.dart`, `equipment_writes_test.dart`

**Interfaces:**
- Produces: relations `tags` (RelationSpec refEntity `tags`) and `shared_with` (refEntity `divers`) on `equipment`.

- [ ] **Step 1: Write the failing tests:** `'an item gains and loses tags'` (through `EquipmentTagRepository.replaceTags`); `'a tag not used for equipment cannot link'` (blocks as `invalid_value`, honouring `soFar.values` as `_siteTagBlock` does); `'an item is shared and unshared'` (through `setShares`, actingDiverId the owner); `'sharing with the owner, an unknown profile or from an ownerless item is blocked'`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement** `currentRelation` (tag links, share rows), the update's relation writes (the whole new list, as the editor saves it), and the blocks.
- [ ] **Step 4: Run.** Expected: PASS. Add `equipment_share_repository.dart:setShares` to `covered`, and the tag link `replaceTags` if it is still in the baseline. Exempt `shareMany`, `unshare` and `shareAllForDiver` as bulk shortcuts for a share change, which `shared_with` covers through `setShares`. Regenerate the baseline.
- [ ] **Step 5: Commit** `feat(agent-access): write an item's tags and shares`.

### Task 5: Equipment sets

**Files:**
- Create: `families/equipment_set_writes.dart`, `test/.../equipment_set_writes_test.dart`

**Interfaces:**
- Produces: `EquipmentSetWrites` (`equipment_sets`), relation `equipment_ids` (refEntity `equipment`), field `geofences` (ObjectListCodec of `label`, `latitude`, `longitude`, `radius_m`).

- [ ] **Step 1: Write the failing tests:** create, rename and delete a set (geofences tombstoned with it); `'members are added and removed'`; `'a member the owner cannot see is blocked'`; `'making a set the default clears the other'` (one default per diver after apply; the plan lists the other set's `is_default` change under `touched`); `'show_figure writes only that column'`; `'geofences are replaced whole and keep ids by position'`; `'a geofence radius outside 50 m to 50 km is refused'`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement:** `createSet`/`updateSet` for name, description, auto-apply and members; `setAsDefault`/`clearDefault` for `is_default`; `setShowFigure` for `show_figure`; geofences diffed by position into `addGeofence`/`updateGeofence`/`removeGeofence`; `stored()` adds the geofences.
- [ ] **Step 4: Run.** Expected: PASS. Cover the set repository's writes in `covered`; regenerate the baseline.
- [ ] **Step 5: Commit** `feat(agent-access): write equipment sets`.

### Task 6: Places and moves

**Files:**
- Create: `families/equipment_location_writes.dart`, `test/.../equipment_location_writes_test.dart`

**Interfaces:**
- Produces: `EquipmentLocationWrites` (`equipment_locations`) and `EquipmentLocationMoveWrites` (`equipment_location_moves`, `ChildOf(entity: 'equipment', field: 'equipment_id')`).

- [ ] **Step 1: Write the failing tests:** a place is created, renamed, archived and deleted; `'a place a move names cannot be deleted'` (`not_permitted`, detail says archive); a move is recorded, edited and deleted, and the item's current place follows; `'a move to another profile's place is blocked'`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement:** places through `createLocation`/`updateLocation`/`setArchived`/`deleteLocation` (fields `name` trim, `kind` enumName(EquipmentLocationKind), `dive_center_id` reference('centers', nullable), `notes`, `is_archived`); moves through `recordMoves` (one item), `updateMove`, `deleteMove` (fields `location_id` reference nullable, `moved_at` instant, `note`).
- [ ] **Step 4: Run.** Expected: PASS. Cover; regenerate the baseline.
- [ ] **Step 5: Commit** `feat(agent-access): write gear places and moves`.

### Task 7: Assembly components

**Files:**
- Create: `families/equipment_component_writes.dart`, `test/.../equipment_component_writes_test.dart`

**Interfaces:**
- Produces: `EquipmentComponentWrites` (`equipment_components`, `ChildOf(entity: 'equipment', field: 'parent_equipment_id')`).

- [ ] **Step 1: Write the failing tests:** a part is added, its role changed, swapped for another item (`replaceComponent`, keeping its role and place), moved (`sort_order` through `reorder`) and removed; `'a part that would close a loop is blocked'`; `'a part already in the assembly is a duplicate'`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement** with `wouldCreateCycle` in `refuse`, so the block comes before `addComponent` would throw. Fields: `component_equipment_id` reference('equipment'), `role` text(trim, allowBlank), `sort_order` integer, a slot the assembly already holds.
- [ ] **Step 4: Run.** Expected: PASS. Cover; regenerate the baseline.
- [ ] **Step 5: Commit** `feat(agent-access): write assembly components`.

### Task 8: Docs, full checks and screenshots

- [ ] **Step 1: Update** `docs/developer/agent-access.md`: the gear entities, `alsoCreates` and `touched`, and the exempt additions.
- [ ] **Step 2: Run** `dart format .`, `flutter analyze`, `flutter test test/features/agent_access test/architecture test/features/equipment test/features/settings`, `python3.14 scripts/check_docs_links.py`. Expected: all pass.
- [ ] **Step 3: Screenshots** of the confirm dialog, English, light and dark: a gear item create before (no "Also adds" line) and after.
- [ ] **Step 4: Commit** `docs(agent-access): gear writes`.
