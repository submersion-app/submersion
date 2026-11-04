# MCP server PR 5b: small catalogs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in one session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An agent can create, edit and delete the diver's small catalogs (tags, dive types, roles, site types, species, dive centers with their gear notes, custom certification agencies with their levels, cylinder configs, weight presets and tank presets), merge tags, and link tags and expected species to sites, exactly as the app's own screens allow; and the write coverage guard tells real gaps from methods that are not diver-edited records.

**Architecture:** Each catalog is a `WritableEntry` family under `lib/features/agent_access/data/writes/families/`, registered in `WriteCatalog`, writing through the repository its settings screen uses. A merge is a delete that names `merge_into`; the change set, planner, plan item, applier, tool schema and confirm dialog learn it once, generically, and tags are the first entity to implement it. The coverage guard gains an `exempt` map, a reason per non-record write method.

**Tech Stack:** Flutter, Drift, flutter_test against a real test database (`setUpTestDatabase`), the write harness of PRs 4 and 5a (`test/features/agent_access/data/writes/child_write_harness.dart`).

**Spec:** `docs/design/specs/2026-11-01-mcp-server-design.md` ("Writes", "Coverage and release gate"). The design for this PR was approved in conversation on 2026-11-03 and is restated in the sections below.

## Global Constraints

- An agent changes exactly what a diver can change in the app, through the same repository method the app's screen calls, and nothing else.
- Document keys and entity names are those the read catalogue already uses (`catalog_records.dart`, `site_records.dart`, `training_records.dart`, `gear_records.dart`).
- Built-in dive types, roles and site types are read-only, except a dive type's `show_in_detail_header` and `show_in_list_view`. Built-in species are editable, as in the app. Built-in tank presets are app constants, not rows.
- Everything stays behind `agentAccessAvailableProvider` (debug mode) until PR 6.
- No schema change.
- Every PR links its issue: `Refs #4071`.
- No em-dashes, en-dashes or double hyphens as prose punctuation, anywhere; no mention of the tooling that wrote the code.
- Files stay under 800 lines; `write_planner.dart` is at 747, so merge planning goes in a new part file.

## Review Focus

1. **A tag create or rename that hits an existing name** (the index is per diver on the trimmed name, case-insensitive): `createTag` silently returns the incumbent, so a plan must block it as `duplicate_record` naming the existing tag, never report a create of a record that already existed. Test in Task 2.
2. **Turning off a tag scope that has links** removes the tag from every item of that scope, as the tag page warns: the plan must list those links as parts. Test in Task 2.
3. **A merge into itself, into a tag the set deletes or merges, into another diver's tag, or of an entity that cannot merge**: blocked with a reason, before any write. Test in Task 3.
4. **Deleting a custom agency or level in use**: the repository deletes nothing and returns the usage, so the plan must block it as `not_permitted` with the counts, not fail at apply. Test in Task 6.
5. **Changing a built-in dive type's name or deleting it**: blocked as `not_permitted`; changing only its visibility goes through. Test in Task 4.

---

### Task 1: Exempt the write methods that are not records

**Files:**
- Modify: `test/architecture/agent_write_coverage_test.dart`
- Modify: `test/architecture/agent_write_coverage_baseline.txt` (regenerated)

**Interfaces:**
- Produces: `const exempt = <String, String>{}` in `agent_write_coverage_test.dart`, keyed like `covered` (`path:method`) or `path:*` for a whole repository file, valued by the reason.

- [ ] **Step 1: Write the failing tests** in `agent_write_coverage_test.dart`: `'every exempt entry names an existing write and a reason'` (each key's file exists, a `:*` key's file has at least one write, a `:method` key is found by the same scan the guard uses, every reason is non-empty); `'no method is both covered and exempt'`; and change `'every repository write is covered or in the baseline'` so an exempt method needs neither.
- [ ] **Step 2: Run** `flutter test test/architecture/agent_write_coverage_test.dart`. Expected: FAIL on `exempt` undefined.
- [ ] **Step 3: Add `exempt`** with these entries and reasons:
  - `lib/features/settings/data/repositories/app_settings_repository.dart:*` and `diver_settings_repository.dart:*`: preferences, not logbook records.
  - `lib/features/auto_update/data/repositories/update_preferences.dart:*`, `lib/features/backup/data/repositories/backup_preferences.dart:*`, `lib/features/change_log/data/repositories/change_log_preferences.dart:*`: app preferences.
  - `lib/features/change_log/data/repositories/change_log_repository.dart:*`: the log of changes itself, written by every write.
  - `lib/features/notifications/data/repositories/scheduled_notification_repository.dart:*`: reminders scheduled from records, rewritten when they change.
  - `lib/features/maps/data/repositories/offline_map_repository.dart:*`, `lib/features/reef/data/repositories/reef_cache_dao.dart:*`, `lib/features/tides/data/repositories/noaa_station_cache_repository.dart:*`, `lib/features/gps_log/data/repositories/track_geometry_cache_repository.dart:*`, `lib/features/insights/data/repositories/deco_classification_cache.dart:*`: caches and downloads.
  - `lib/features/insights/data/repositories/observation_dismissals_repository.dart:*`, `lib/features/data_quality/data/repositories/quality_findings_repository.dart:*`: state of derived findings, recomputed from records.
  - `lib/features/dive_computer/data/repositories/dive_computer_connection_repository.dart:*`: this device's pairing with a computer.
  - `lib/features/marine_life/data/repositories/species_repository.dart:resetBuiltInSpecies`: restores the bundled catalogue; the edits it undoes are species updates.
  - `lib/features/weight_presets/data/repositories/weight_preset_repository.dart:createFromWeights`: a shortcut for a create with entries, which `weight_presets` covers.
  Correct any path the existence test rejects by locating the file with `git ls-files | grep <name>`.
- [ ] **Step 4: Regenerate the baseline:** `UPDATE_AGENT_WRITE_BASELINE=1 flutter test test/architecture/agent_write_coverage_test.dart`, then run it again without the variable. Expected: PASS, and the baseline is about 65 lines shorter.
- [ ] **Step 5: Commit** `test(agent-access): exempt write methods that are not diver records`.

### Task 2: Tags

**Files:**
- Create: `lib/features/agent_access/data/writes/families/tag_writes.dart`
- Modify: `lib/features/agent_access/data/writes/field_codec.dart` (a set-of-names codec)
- Modify: `lib/features/agent_access/data/writes/write_catalog.dart`
- Modify: `test/architecture/agent_write_coverage_test.dart`, baseline
- Test: `test/features/agent_access/data/writes/tag_writes_test.dart`, `test/features/agent_access/data/writes/field_codec_test.dart`

**Interfaces:**
- Produces: `factory FieldCodec.enumSet(Iterable<Enum> values, {int min = 0})`, shaped like the existing `FieldCodec.enumName`, parsing a list of names to a sorted `List<String>`, refusing an unknown name, a repeat or fewer than `min`; `canonical` sorts a document list. `class TagWrites extends WritableEntry` with `TagWrites(RecordRepositories r)`.

Fields: `name` text (max 100); `color_hex` text, nullable, must match `^#[0-9A-Fa-f]{6}$` (refuse with `invalid_value` otherwise); `scopes` `FieldCodec.enumSet(TagScope.values, min: 1)`, defaulting to `['dives']` on create. `requiredOnCreate`: `name`. Writes: `createTag`, `updateTag` (current tag with the named fields), `deleteTag`.

- [ ] **Step 1: Write the failing tests:**
  - `'enumSet parses names into a sorted list'` and `'enumSet refuses an unknown name, a repeat or too few'` in `field_codec_test.dart`.
  - `tag_writes_test.dart`: `'a new tag applies to dives unless told'` (create with name only reads back `scopes: ['dives']`); `'a name another tag of the diver holds is a duplicate'` (seed `Wreck`; create ` wreck ` blocks with `BlockReason.duplicateRecord`, and the detail names the existing id; an update renaming another tag to `WRECK` blocks the same way); `'a colour must be #RRGGBB'` (`'red'` and `'#FFF'` block `invalidValue`, `'#FF5733'` passes); `'turning off a scope lists the links it removes'` (a tag on two dives and one site; update `scopes: ['sites']` plans `parts['dive_tags'] == 2`, and after apply the dives carry no link); `'a delete unlinks every item'` (reach `unlinked` counts `dive_tags` and `site_tags`; after apply both are empty); `'every codec key has a column'` (each field round-trips through update and reads back).
- [ ] **Step 2: Run** `flutter test test/features/agent_access/data/writes/tag_writes_test.dart test/features/agent_access/data/writes/field_codec_test.dart`. Expected: FAIL, `TagWrites` undefined.
- [ ] **Step 3: Implement** the codec, then `TagWrites`: `refuse` checks the duplicate on create and on a `name` change with the same trimmed, case-insensitive match `createTag` uses (read the incumbent with one query on `tags` for the owner), and the colour pattern; `sideEffects` counts, for each scope a change turns off, the rows of that scope's junction (`TagScope.table`) holding the tag, into `parts`; `deleteReach` uses `countUnlinked('tags', id)` from `write_reach.dart`. Register `TagWrites(repositories)` in `WriteCatalog`.
- [ ] **Step 4: Run** the same tests. Expected: PASS.
- [ ] **Step 5: Move `createTag`, `updateTag`, `deleteTag` to `covered` as `'tags'`**, regenerate the baseline, run `flutter test test/architecture`. Expected: PASS.
- [ ] **Step 6: Commit** `feat(agent-access): write tags`.

### Task 3: Merge, with tags first

**Files:**
- Create: `lib/features/agent_access/data/writes/write_planner_merge.dart` (part of `write_planner.dart`)
- Modify: `change_set.dart`, `writable_entity.dart`, `write_plan.dart`, `write_planner.dart`, `write_applier.dart`, `families/tag_writes.dart`, `data/tools/preview_changes_tool.dart`, `presentation/widgets/agent_write_confirm_dialog.dart`, `lib/l10n/arb/app_*.arb` (11 locales)
- Test: `test/features/agent_access/data/writes/change_set_test.dart`, `test/features/agent_access/data/writes/tag_merge_test.dart`, `test/features/agent_access/presentation/widgets/agent_write_confirm_dialog_test.dart`

**Interfaces:**
- Produces:
  - `DeleteOp.mergeInto` (`String?`), parsed from a delete's `merge_into` (a non-empty string, else refused like `id`); `_deleteKeys` gains `merge_into`.
  - On `WritableEntry`: `bool get mergeable => false`; `Future<DeleteReach> mergeReach(String id, String intoId) async => const DeleteReach()`; `Future<void> merge(String id, String intoId, String? ownerId) => throw UnsupportedError(name)`.
  - `DeleteReach.moved` (`Map<String, int>`, rows re-pointed to the survivor, by table), in `isEmpty` and `footprint`.
  - `PlanItem.mergeInto` and `PlanItem.mergeTitle` (`String?`).
  - l10n keys `settings_agentAccess_confirm_merge` ("Merge into {name}") and `settings_agentAccess_confirm_moves` ("Moves {kind}: {count}"), in all 11 locales.

Rules, in `_mergeBlock(...)` in the part file, run for a delete with `mergeInto` before `refuse`:
- `not_permitted` when the entity is not `mergeable`.
- `invalid_value` when `mergeInto == id`.
- `unknown_reference` when the survivor does not exist or is not visible to the item's owner under the entity's read scope.
- `other_profile_reference` when the survivor's owner differs from the merged record's.
- `reference_deleted` when the set deletes or merges the survivor.

The item carries a version marker for the survivor as well as the merged record, so a change to either between preview and apply refuses the apply. The applier calls `entry.merge(id, mergeInto, diverId)` for such an item.

`TagWrites`: `mergeable` true; `mergeReach` counts, per junction, the source's links whose item does not already carry the survivor (`moved`) and those that do (`parts`, removed); `merge` calls `mergeTags(sourceTagIds: [id], survivingTagId: intoId, name: <survivor's name now>, colorHex: <survivor's colour now>)`, read at apply time so an update of the survivor earlier in the same set is kept.

- [ ] **Step 1: Write the failing tests:**
  - `change_set_test.dart`: `'a delete may name merge_into'` and `'merge_into must be a non-empty string'`.
  - `tag_merge_test.dart`:
    - `'a merge moves every link to the survivor and deletes the source'`: dives d1 and d2 carry `wreck`, d2 also carries `Wreck`, site s1 carries `wreck`. The plan's reach has `moved: {dive_tags: 1, site_tags: 1}` and `parts: {dive_tags: 1}`. After apply, `wreck` is gone and d1, d2 and s1 each carry `Wreck` once.
    - `'a merge keeps a rename of the survivor in the same set'`.
    - `'a merge into itself, a deleted survivor or another diver's tag is blocked'` with the reasons above.
    - `'an entity that cannot merge refuses merge_into'`, using `buddies`.
    - `'a revert restores the source and its links'`, through `revert_operation` as the existing revert tests drive it.
    - `'a change to the survivor after the preview refuses the apply'`.
  - Dialog test: `'a merge reads as merge into the survivor and lists what moves'`.
- [ ] **Step 2: Run** the three test files. Expected: FAIL to compile on `mergeInto`.
- [ ] **Step 3: Implement** in the order of the Interfaces block. Document `merge_into` in `preview_changes_tool.dart`'s operation schema ("for a delete of an entity that can merge: the id of the record that takes over its links") and in `TagWrites.note`.
- [ ] **Step 4: Run** the three files, then `flutter test test/features/agent_access`. Expected: PASS.
- [ ] **Step 5: Move `mergeTags` to `covered` as `'tags'`**, regenerate the baseline, run `flutter test test/architecture`, `flutter analyze`. Expected: PASS, no issues.
- [ ] **Step 6: Commit** `feat(agent-access): merge tags through a delete with merge_into`.

### Task 4: Dive types, roles and site types

**Files:**
- Create: `families/dive_type_writes.dart`, `families/dive_role_writes.dart`, `families/site_type_writes.dart`
- Modify: `write_catalog.dart`, coverage map, baseline
- Test: `test/features/agent_access/data/writes/type_catalog_writes_test.dart`

**Interfaces:**
- Produces: `DiveTypeWrites(RecordRepositories)`, `DiveRoleWrites(RecordRepositories)`, `SiteTypeWrites(RecordRepositories)`.

Fields:

| Entity | Fields |
| --- | --- |
| `dive_types` | `name` text (max 60), `short_name` text (max 12, nullable), `sort_order` integer (0 to 999), `show_in_detail_header` flag, `show_in_list_view` flag |
| `dive_roles` | `name` text (max 60) |
| `site_types` | `name` text (max 60), `sort_order` integer (0 to 999) |

Built-ins (`is_built_in` true in the document):
- An update naming anything but the two `show_in_*` keys blocks `not_permitted`, and a delete blocks too.
- A dive type update naming only those keys calls `setDiveTypeVisibility`; one naming others calls `updateDiveType` with the current type copied.
- A role update calls `renameDiveRole`; site types call `updateSiteType`.
- Deletes call `deleteDiveType`, `deleteDiveRole`, `deleteSiteType`, the methods the settings pages call.
- `deleteReach` uses `countUnlinked` for the type's or role's link tables.

- [ ] **Step 1: Write the failing tests:** `'a built-in dive type shows or hides but keeps its name'`; `'a built-in role or site type cannot change or go'`; `'a custom type, role and site type are created for the diver, renamed and deleted'`; `'deleting a custom dive type unlinks its dives'`, checking reach and the rows after apply.
- [ ] **Step 2: Run** the file. Expected: FAIL.
- [ ] **Step 3: Implement and register.**
- [ ] **Step 4: Run** the file. Expected: PASS.
- [ ] **Step 5: Move** `createDiveType`, `updateDiveType`, `setDiveTypeVisibility`, `deleteDiveType`, `createDiveRole`, `renameDiveRole`, `deleteDiveRole`, `createSiteType`, `updateSiteType`, `deleteSiteType` to `covered`, regenerate the baseline, run `flutter test test/architecture`. Expected: PASS.
- [ ] **Step 6: Commit** `feat(agent-access): write dive types, roles and site types`.

### Task 5: Species, and tags and expected species on sites

**Files:**
- Create: `families/species_writes.dart`
- Modify: `families/site_writes.dart` (two relations), `write_catalog.dart`, coverage map, baseline
- Test: `test/features/agent_access/data/writes/species_writes_test.dart`, `test/features/agent_access/data/writes/site_writes_test.dart`

**Interfaces:**
- Produces: `SpeciesWrites(RecordRepositories)`; `SiteWrites.relations` gains `'tags': RelationSpec(refEntity: 'tags')` and `'expected_species': RelationSpec(refEntity: 'species')`.

`species` fields:
- `common_name` text (max 200)
- `scientific_name` text (max 200, nullable)
- `category` `FieldCodec.enumName(SpeciesCategory.values)`
- `taxonomy_class` text (max 100, nullable)
- `description` text (nullable, `allowBlank`)

`photo_path` stays read-only: dive photos are links only. Required on create: `common_name` and `category`. Writes go through `createSpecies`, `updateSpecies` (current species copied) and `deleteSpecies`. `deleteReach` counts sightings and expected-species rows as `parts`, through `countCascaded('species', id)`.

Site relations:
- `tags` adds through `TagLinkRepository.addTags` and removes through `removeTags`, for the site scope. A tag whose scopes lack `sites` blocks `invalid_value`, as the site editor offers only site tags.
- `expected_species` goes through `addExpectedSpecies` and `removeExpectedSpecies`, with `actingDiverId` and library stamping as `SiteWrites` already does for a library site. A new link carries no notes, as the app adds it.
- `currentRelation` reads `site_tags` and the expected species table.

- [ ] **Step 1: Write the failing tests:** `'a built-in species can be edited'`; `'a species delete takes its sightings with it'`, checking reach and the rows; `'a site gains and loses tags'`; `'a tag not used for sites cannot link to one'`; `'a site gains and loses expected species'`.
- [ ] **Step 2: Run** both files. Expected: FAIL.
- [ ] **Step 3: Implement and register.**
- [ ] **Step 4: Run** both files. Expected: PASS.
- [ ] **Step 5: Move** `createSpecies`, `updateSpecies`, `deleteSpecies`, `addExpectedSpecies`, `removeExpectedSpecies` and the tag link methods the relation calls to `covered`, regenerate the baseline, run `flutter test test/architecture`. Expected: PASS.
- [ ] **Step 6: Commit** `feat(agent-access): write species, and tags and expected species on sites`.

### Task 6: Dive centers and their gear notes; custom agencies and their levels

**Files:**
- Create: `families/center_writes.dart`, `families/center_gear_note_writes.dart`, `families/custom_certification_writes.dart` (holds `CustomAgencyWrites` and `CustomLevelWrites`)
- Modify: `write_catalog.dart`, coverage map, baseline
- Test: `test/features/agent_access/data/writes/center_writes_test.dart`, `test/features/agent_access/data/writes/custom_certification_writes_test.dart`

**Interfaces:**
- Produces: `CenterWrites(RecordRepositories)`, `CenterGearNoteWrites(RecordRepositories)` with `parent => ChildOf(entity: 'centers', field: 'center_id')`, `CustomAgencyWrites(RecordRepositories)`, `CustomLevelWrites(RecordRepositories)` with `parent => ChildOf(entity: 'custom_agencies', field: 'agency_id')`.

`centers` fields:
- Text: `name` (max 200), and `street`, `city`, `state_province`, `postal_code`, `country`, `phone`, `email`, `website`, `affiliations`, all nullable.
- `latitude` number (-90 to 90, nullable) and `longitude` number (-180 to 180, nullable). A create or update that ends with exactly one of them set blocks `invalid_value`.
- `rating` number (0 to 5, nullable).
- `notes` text (`allowBlank`).
- `fill_opens_at_min` and `fill_closes_at_min`, integers (0 to 1439, nullable).
- `is_permanently_closed` flag.

Writes go through `createDiveCenter`, `updateDiveCenter` (current copied) and `deleteDiveCenter`. `deleteReach` counts linked dives (`countDivesByOwner` on the dives' center column) and gear notes as `parts`.

`center_gear_notes` fields:
- `center_id` reference, create only.
- `gear_type` and `verdict`, enum names of their domain enums.
- `label` and `size`, text, nullable.
- `lead_adjustment_kg` number (-30 to 30, nullable) and `volume_l` number (0 to 30, nullable).
- `note` text (`allowBlank`).
- `dive_id`, a nullable reference to a dive of the same diver.

`noted_at` is set to now on create and kept on update. Writes go through the gear note repository's `create`, `update` and `delete`.

`custom_agencies` fields: `name` text (max 100), `color_argb` integer (0 to 4294967295), `is_shared` flag.

`custom_levels` fields: `agency_id` reference (create only), `name` text (max 100), `is_progression` flag, `sort_order` integer (0 to 999).

Certification rules:
- Every repository call passes `actingDiverId: ownerId`, as `SiteWrites` does.
- A delete blocks `not_permitted` when `usage(id)` (for a level) or `agencyUsage(id)` (for an agency) reports any use, naming the counts. That's the case where the repository would delete nothing.
- A level update that changes `sort_order` on a progression level calls `reorderProgression` with the agency's progression ids, reordered to put this level at its new place. Any other change calls `updateLevel`.

- [ ] **Step 1: Write the failing tests:**
  - `'a center is created, edited and deleted, and its dives only lose the link'`
  - `'a center needs both coordinates or neither'`
  - `'a gear note belongs to its center and keeps when it was noted'`
  - `'an agency or level in use cannot be deleted'`, with the usage in the detail
  - `'an unused agency goes with its levels'`
  - `'moving a progression level reorders the progression'`
- [ ] **Step 2: Run** both files. Expected: FAIL.
- [ ] **Step 3: Implement and register.**
- [ ] **Step 4: Run** both files. Expected: PASS.
- [ ] **Step 5: Move** the twelve methods reached (`createDiveCenter`, `updateDiveCenter`, `deleteDiveCenter`, the gear note `create`, `update`, `delete`, `createAgency`, `updateAgency`, `deleteAgency`, `createLevel`, `updateLevel`, `deleteLevel`, `reorderProgression`) to `covered`, regenerate the baseline, run `flutter test test/architecture`. Expected: PASS.
- [ ] **Step 6: Commit** `feat(agent-access): write dive centers, gear notes and custom certifications`.

### Task 7: Tank presets, weight presets and cylinder configs

**Files:**
- Create: `families/preset_writes.dart` (`TankPresetWrites`, `WeightPresetWrites`), `families/cylinder_config_writes.dart`
- Modify: `write_catalog.dart`, coverage map, baseline
- Test: `test/features/agent_access/data/writes/preset_writes_test.dart`, `test/features/agent_access/data/writes/cylinder_config_writes_test.dart`

**Interfaces:**
- Produces: `TankPresetWrites(RecordRepositories)`, `WeightPresetWrites(RecordRepositories)`, `CylinderConfigWrites(RecordRepositories)`; two list codecs, `WeightPresetEntriesCodec` and `CylinderConfigItemsCodec`. Each list codec parses a list of item documents (each object's keys being those of `weightPresetEntryDocument` and `cylinderConfigItemDocument`, without `id` and the parent key) to its canonical JSON. The codec's `canonical` drops `id` and the parent key from a stored list, so an unchanged list compares equal, as `InterventionsCodec` does for scenarios.

`tank_presets` fields:
- `name` text (max 60)
- `display_name` text (max 100)
- `volume_l` number (0.1 to 30)
- `working_pressure_bar` number (1 to 450)
- `material` enum name
- `description` text (`allowBlank`)
- `sort_order` integer (0 to 999)

`rated_capacity_cuft` is derived and read-only. Writes go through `createPreset`, `updatePreset` (current copied) and `deletePreset`.

`weight_presets` fields: `display_name` text (max 100), `notes` text (`allowBlank`), `sort_order` integer, and `entries` (the codec). Each entry has:
- `type` enum name
- `amount_kg` number (0 to 30)
- `label` text, nullable
- `notes` text
- `sort_order` integer

Weight preset writes:
- A create calls `createPreset`.
- An update naming only `display_name` or `notes` calls `renamePreset`; one naming `entries` calls `updatePreset` with the whole list.
- A delete calls `deletePreset`.
- `stored()` adds the current entries under `entries`, so a plan compares lists.

`cylinder_configs` fields: `name` text (max 100), `description` text (`allowBlank`), `sort_order` integer, `equipment_id` (a nullable reference to `equipment` of the same diver), and `items` (the codec). Each item has:
- `label` text, nullable
- `role` enum name
- `volume_l` number (0.1 to 30, nullable)
- `working_pressure_bar` number (1 to 450, nullable)
- `material` enum name, nullable
- `o2_fraction` number (0.05 to 1) and `he_fraction` number (0 to 0.95); stored as percent, ×100, and their sum may not pass 1
- `default_start_pressure_bar` number (nullable)
- `deco_switch_depth_m` number (0 to 120, nullable)
- `sort_order` integer

Cylinder config writes:
- A create calls `createConfig`, then `saveItems` when items are named.
- An update calls `updateConfig` (current copied) for scalars and `saveItems` for `items`.
- A delete calls `deleteConfig`.
- `stored()` adds the current items.

- [ ] **Step 1: Write the failing tests:**
  - `'a tank preset is created, edited and deleted'`
  - `'renaming a weight preset keeps its entries'`
  - `'a weight preset's entries are replaced whole'`
  - `'an unchanged entry list is not listed as a change'`
  - `'cylinder config items take fractions and store percent'`
  - `'gas fractions that pass 1 are refused'`
  - `'a config can point at the diver's own equipment only'`
- [ ] **Step 2: Run** both files. Expected: FAIL.
- [ ] **Step 3: Implement and register.**
- [ ] **Step 4: Run** both files. Expected: PASS.
- [ ] **Step 5: Move** the methods reached (`createPreset`, `updatePreset`, `deletePreset` in both preset repositories, `renamePreset`, `createConfig`, `updateConfig`, `deleteConfig`, `saveItems`) to `covered`, regenerate the baseline, run `flutter test test/architecture`. Expected: PASS.
- [ ] **Step 6: Commit** `feat(agent-access): write tank presets, weight presets and cylinder configs`.

### Task 8: Docs, full checks and screenshots

**Files:**
- Modify: `docs/developer/agent-access.md` (the writable entities list, merge_into, the exempt map)
- Screenshots: the scratchpad, then the project's screenshot gist

- [ ] **Step 1: Update** `docs/developer/agent-access.md`: list the twelve new entities and the two site relations, describe `merge_into` (tags only so far), and say where the exempt map lives and what qualifies.
- [ ] **Step 2: Run** `dart format .`, `flutter analyze`, `flutter test test/features/agent_access test/architecture test/features/settings`, and `python3.14 scripts/check_docs_links.py`. Expected: all pass, no issues.
- [ ] **Step 3: Capture screenshots** of the confirm dialog in English on macOS, light and dark: a plain tag delete (before, from main's build) and a tag merge (after). The dialog is the only visible change.
- [ ] **Step 4: Commit** `docs(agent-access): catalog writes and merges`.
