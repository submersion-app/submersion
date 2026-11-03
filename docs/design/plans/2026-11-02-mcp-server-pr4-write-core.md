# MCP server PR 4: the write core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An agent can preview, apply and revert changes to dives, buddies and sites, one operation in the change log per diver, with the diver confirming in the app.

**Architecture:** A write catalogue under `lib/features/agent_access/data/writes/` sits beside the read catalogue and shares its entity names and document keys. Preview is a pure read that diffs requested values against the record's document and stores a plan in memory. Apply re-checks version markers, waits for the diver, and runs every operation through a repository or the bulk edit service inside `SyncCoordinator.run`, `ChangeLogScope.run` and one transaction.

**Tech Stack:** Flutter, Drift, Riverpod, `mcp_dart` behind the existing adapter.

**Spec:** `docs/design/specs/2026-11-01-mcp-server-design.md`, section "Writes". PR 2 and PR 3 plans sit beside this one.

## Global Constraints

- Preview "must not open a transaction, not even one that is rolled back".
- "The server never writes a table directly."
- Writes run inside `SyncCoordinator.run`; the scope stays outside the transaction; the scope body is the writes and nothing else.
- Apply is all or nothing. Staleness refuses the whole plan.
- Plan expiry 15 minutes. Confirmation timeout 5 minutes. The confirmation is per device, default on.
- Field names and units follow the `get_records` documents.
- Everything stays behind `agentAccessAvailableProvider` (debug mode). PR 6 removes that.
- Every tool passes the gate first: demo mode, app lock, database available.
- Tool and resource text is English. Dialog and change log strings go through ARB in all 11 locales.
- No em-dashes, no attribution, `Refs #4071`, not `Closes`.

## Scope

In: `ChangeLogSource.agent`, change set parsing, `preview_changes`, `apply_changes`, `revert_operation`, plan store, confirmation dialog, coverage guard as a ratchet, and create, update and delete for `dives`, `buddies` and `sites`.

Dive relations in this PR: `buddies`, `tags`, `types`, `site`. Tanks, weights, sightings, equipment and courses come with the coverage series (PR 5).

Out: every other entity (PR 5), removing the debug gate and user docs (PR 6).

## Rulings

Spec gaps this plan settles. Each is recorded in the spec's decision record in Task 9.

- A plan with any blocked item gets no `plan_id`. The agent re-previews without those items, so a diver never confirms something that cannot run.
- Field writes use a partial companion, not `copyWith`. Most `copyWith` methods use `??`, so they cannot clear a field, and building a whole entity loses any field the mapper forgets.
- Dives write through `BulkDiveEditService.apply`, so an agent edit behaves as the diver's bulk edit does, including the site snap.
- `date_time` writes through `bulkShiftDiveTimes` with the difference, so entry and exit move with it.
- Version marker: `updated_at` plus the current ids of each relation the plan changes.
- Markers are checked again inside the sync turn, after the diver confirms. The spec checks before the wait, but the wait can last five minutes.
- A record may appear once per change set. A later reference to a record the same set deletes is blocked. Create then link takes two applies; no placeholder ids.
- `revert_operation` keeps records changed since by default; `include_changed_since: true` overrides. The app does not ask the diver first, as the spec describes no dialog there.
- Deleting a dive passes `holdRemoteMedia: true` through `bulkDeleteDives`, so a revert finds its blobs. Nothing releases a held blob today, the same as the logbook's own delete.

## Review Focus

1. The diver edits a record while the dialog is open: apply refuses as stale, nothing is written.
2. A repository refuses in the middle of a plan: nothing changed, and no empty entry appears in the feed.
3. `null` on a nullable field clears it, on a required field is blocked, and an omitted key leaves it alone.
4. A buddy or tag owned by another profile, attached to a dive: blocked, not written.
5. A library site the owner of the record may not edit: blocked, because `updateSite` would otherwise silently keep the library's values and report success.

## File map

```
lib/features/agent_access/data/writes/
  change_set.dart            ChangeSet, ChangeOp, RelationChange, parsing
  field_codec.dart           FieldCodec and the kinds: text, number, integer, flag, enum, wall clock
  writable_entity.dart       WritableEntry and the plan item inputs
  write_catalog.dart         WriteCatalog
  write_plan.dart            WritePlan, PlanItem, BlockReason, RecordMarker
  write_planner.dart         preview
  write_plan_store.dart      in-memory plans with expiry
  write_applier.dart         apply
  families/dive_writes.dart  buddy_writes.dart  site_writes.dart
lib/features/agent_access/data/tools/
  preview_changes_tool.dart  apply_changes_tool.dart  revert_operation_tool.dart
lib/features/agent_access/domain/write_confirmer.dart
lib/features/agent_access/presentation/widgets/agent_write_confirm_dialog.dart
lib/features/agent_access/presentation/providers/agent_write_providers.dart
```

Tests mirror these paths. `test/features/agent_access/data/records/record_harness.dart` already sets up a real database.

---

### Task 1: The agent change log source

**Files:**
- Modify: `lib/core/services/change_log/change_log_scope.dart:10`, `lib/features/change_log/presentation/change_log_labels.dart:11-33,100-113`, all 11 `lib/l10n/arb/app_*.arb`
- Test: `test/features/change_log/presentation/change_log_labels_test.dart`

**Interfaces:** Produces `ChangeLogSource.agent`, ARB `changeLog_source_agent`.

- [ ] **Step 1: Write the failing test** `'the agent source has a label and an icon'`: `changeLogSourceLabel(l, ChangeLogSource.agent) == 'Agent'`; `changeLogSourceIcon(ChangeLogSource.agent) == Icons.smart_toy_outlined`; and `'an agent operation is titled by its own label'` (the `_ when label != null` arm).
- [ ] **Step 2: Run it.** Expected: compile failure on `ChangeLogSource.agent`.
- [ ] **Step 3: Implement.** Add `agent` to the enum after `system` (existing rows read by name, so order is safe). Add the two switch arms. Add `changeLog_source_agent` to every ARB, translated, then `flutter gen-l10n`. The feed's filter chips iterate `ChangeLogSource.values`, so they need no change.
- [ ] **Step 4: Run** `flutter test test/features/change_log test/l10n`. Expected: pass.
- [ ] **Step 5: Commit** `feat(agent-access): add the agent change log source`.

### Task 2: Change sets and field values

**Files:**
- Create: `data/writes/change_set.dart`, `data/writes/field_codec.dart`
- Modify: `domain/agent_tool_error.dart`
- Test: `test/features/agent_access/data/writes/change_set_test.dart`, `field_codec_test.dart`

**Interfaces:** Produces:

```dart
const kMaxChangeSetOperations = 500;

class ChangeSet {
  final String label;
  final List<ChangeOp> operations;
  static ChangeSet parse(Map<String, Object?> args); // throws invalidArgument naming operations[i]
}
sealed class ChangeOp { String get entity; int get index; }
class CreateOp extends ChangeOp { String? diverId; Map<String, Object?> fields; }
class UpdateOp extends ChangeOp { String id; Map<String, Object?> fields; Map<String, RelationChange> relations; }
class DeleteOp extends ChangeOp { String id; }
class RelationChange { List<String> add, remove; List<String>? set; }

class FieldRefusal implements Exception { final String reason; }
abstract class FieldCodec {
  bool get nullable;
  Object? parse(Object? raw); // canonical value, throws FieldRefusal
  Object? canonical(Object? documentValue); // for the old value
}
FieldCodec.text({int? maxLength, bool nullable}), .number({min, max, nullable}),
.integer({min, max, nullable}), .flag(), .enumName(Iterable<Enum>, {nullable}), .wallClock()
```

New error codes: `planNotFound` `plan_not_found`, `planExpired` `plan_expired`, `planStale` `plan_stale`, `notConfirmed` `not_confirmed`, `writeRefused` `write_refused`.

- [ ] **Step 1: Write the failing tests.** Change set: `'refuses an empty label'`, `'refuses more than 500 operations'`, `'a relation with set and add is refused'`, `'names the failing operation index'`. Codec: `'number outside its range is refused'`, `'null on a required field is refused'`, `'null on a nullable field stays null'`, `'an enum refuses a name it does not have and lists the names'`, `'a wall clock with an offset is refused'` (documents carry nominal Z), `'text keeps inner whitespace'`.
- [ ] **Step 2: Run them.** Expected: fail, `change_set.dart` missing.
- [ ] **Step 3: Implement.** Pure Dart, no database. A wall clock parses `YYYY-MM-DDTHH:MM:SSZ` to a UTC `DateTime` and compares through `wallClock()` from `document_dates.dart`.
- [ ] **Step 4: Run them.** Expected: pass.
- [ ] **Step 5: Commit** `feat(agent-access): parse change sets and field values`.

### Task 3: The write catalogue for dives, buddies and sites

**Files:**
- Create: `data/writes/writable_entity.dart`, `write_catalog.dart`, `families/dive_writes.dart`, `families/buddy_writes.dart`, `families/site_writes.dart`
- Modify: `lib/features/buddies/data/repositories/buddy_repository.dart`, `lib/features/dive_sites/data/repositories/site_repository_impl.dart`
- Test: `test/features/agent_access/data/writes/dive_writes_test.dart`, `buddy_writes_test.dart`, `site_writes_test.dart`, `test/features/buddies/data/repositories/buddy_update_fields_test.dart`

**Interfaces:** Produces:

```dart
abstract interface class WritableEntry {
  String get name;   // the read catalogue's name
  String get table;
  Map<String, FieldCodec> get fields;
  Map<String, RelationSpec> get relations;
  Set<String> get requiredOnCreate;
  Future<Set<String>> currentRelation(String id, String relation);
  /// Null when the owner of the record may change it.
  Future<BlockReason?> refuse(String id, String? ownerId, ChangeKind kind);
  Future<String> create(String diverId, Map<String, Object?> values);
  Future<void> update(String id, RecordUpdate update);
  Future<void> delete(String id, String? ownerId);
}
class RelationSpec { String refTable; bool single; bool refOwnedByDiver; }
class RecordUpdate { Map<String, Object?> values; Map<String, RelationChange> relations; }
class WriteCatalog { WritableEntry? named(String name); List<WritableEntry> get all; }
```

Repository additions: `BuddyRepository.updateFields(String id, BuddiesCompanion partial)` stamps `updated_at`, marks pending and notifies, as `bulkUpdateFields` does, and an all-absent companion writes nothing. `SiteRepository.updateSite` gains `DiveSitesCompanion? metadataPatch`, passed to `_writeSiteUpdate`. `SiteRepository.mayEditLibrary(String id, {String? actingDiverId})` exposes the stamper's check.

Field lists:
- `dives`: `name`, `notes`, `date_time`, `max_depth_m` 0 to 350, `avg_depth_m` 0 to 350, `water_temp_c` -3 to 45, `air_temp_c` -60 to 60, `visibility`, `rating` 0 to 5, `is_favorite`, `excluded_from_stats`, `excluded_from_gas_stats`, `dive_operator`, `boat_name`, `boat_captain`, `dive_master`, `buddy`, `current_direction`, `current_strength`, `swell_height_m`, `surface_conditions`, `entry_method`, `exit_method`, `water_type`, `altitude_m`, `weather_description`.
- `buddies`: `name`, `email`, `phone`, `social_handle`, `notes`, `is_favorite`, `excluded_from_rankings`.
- `sites`: `name`, `description`, `latitude`, `longitude`, `min_depth_m`, `max_depth_m`, `difficulty`, `water_type`, `country`, `region`, `city`, `island`, `body_of_water`, `rating`, `notes`, `hazards`, `access_notes`, `mooring_number`, `parking_info`.

Dive relation values: `buddies` adds with role `DiveRole.buddyId`, and `BuddiesOp` takes `BuddyWithRole`, so load each buddy first. `tags` maps to `TagsOp`, `types` to `DiveTypesOp`, `site` to `SiteOp` and is `single`. A `set` becomes `BulkCollectionMode.replace`.

- [ ] **Step 1: Write the failing repository test** `'updateFields clears a nullable column and stamps the row pending'` and `'an empty companion writes nothing'`.
- [ ] **Step 2: Run it.** Expected: fail, no `updateFields`.
- [ ] **Step 3: Add the repository methods.**
- [ ] **Step 4: Write the failing family tests**, one group per entity against a real database: `'update writes only the named columns'` (a column not named keeps its value), `'null clears a nullable column'`, `'create returns an id the record reads back under'`, `'delete removes the row'`. Dives also: `'date_time moves entry and exit by the same difference'`, `'adding a buddy keeps the others'`, `'set replaces tags'`, `'site snaps the water type as bulk edit does'`. Sites also: `'a library site the owner may not edit is refused'`, `'clearing a description on a library site records the edit'`. Assert every written document passes `expectCleanDocument` after a read back.
- [ ] **Step 5: Run them.** Expected: fail, `dive_writes.dart` missing.
- [ ] **Step 6: Implement.** Each family maps document keys to one companion through a private switch, so a key the codec lists and the mapper lacks fails a test: `'every codec key has a column'` runs each key through `update`. `date_time` is split off and sent to `bulkShiftDiveTimes`. `delete` throws `AgentToolException(writeRefused)` when `deleteSite` returns false.
- [ ] **Step 7: Run them.** Expected: pass.
- [ ] **Step 8: Commit** `feat(agent-access): write dives, buddies and sites through their repositories`.

### Task 4: `preview_changes`

**Files:**
- Create: `data/writes/write_plan.dart`, `write_planner.dart`, `write_plan_store.dart`, `data/tools/preview_changes_tool.dart`
- Test: `test/features/agent_access/data/writes/write_planner_test.dart`, `write_plan_store_test.dart`, `test/features/agent_access/data/tools/preview_changes_tool_test.dart`

**Interfaces:**
- Consumes: `ChangeSet`, `WriteCatalog`, `RecordCatalog`.
- Produces:

```dart
enum BlockReason { recordNotFound, notWritable, unknownField, invalidValue, missingField,
  unknownReference, otherProfileReference, duplicateRecord, referenceDeleted, notPermitted }
class PlanItem { ChangeKind kind; String entity; String? id; String? diverId;
  Map<String, FieldChange> fields; Map<String, RelationDelta> relations;
  BlockReason? blocked; String? blockDetail; int operationIndex; }
class RecordMarker { String table; String id; int? updatedAt; Map<String, Set<String>> relations; }
class WritePlan { String id; String label; String? clientName; DateTime expiresAt;
  List<PlanItem> items; List<RecordMarker> markers;
  Map<String, Object?> toJson(); bool get applicable; }
class WritePlanner { Future<WritePlan> preview(ChangeSet set, {required String defaultDiverId, String? clientName}); }
class WritePlanStore { WritePlanStore({DateTime Function()? clock}); void put(WritePlan p); WritePlan take(String id); }
```

`take` removes the plan and throws `planNotFound` or `planExpired`. An unchanged value is dropped from the item, and an item with nothing left is reported under `unchanged`.

- [ ] **Step 1: Write the failing tests.** `'a preview opens no transaction and ticks no table'` (spec test: wrap the executor, count `beginTransaction` and table updates, both zero, for a change set holding a create, an update and a delete). `'each changed field shows old and new'`, `'an unchanged value is not listed'`, `'null is listed as a clear and an omitted key is not'`, `'null on a required field is blocked'`, `'a missing record is blocked'`, `'an unknown field is blocked and lists the names'`, `'a buddy of another profile is blocked'`, `'a record twice is blocked'`, `'a reference to a record the set deletes is blocked'`, `'a library site the owner may not edit is blocked'`, `'counts are per entity and per diver across two profiles'`, `'a blocked plan is not stored and has no plan_id'`, `'store refuses an expired plan'`, `'take is single use'`.
- [ ] **Step 2: Run them.** Expected: fail.
- [ ] **Step 3: Implement.** Read `diver_id` and `updated_at` with one `customSelect` per chunk of ids, read documents through the read catalogue's `read` as the record's owner, and compare through the codec's `canonical`. `sites` is the one table whose owner can be null: the marker keeps null and `refuse` decides.
- [ ] **Step 4: Run them.** Expected: pass.
- [ ] **Step 5: Commit** `feat(agent-access): preview a change set without touching the database`.

### Task 5: `apply_changes`

**Files:**
- Create: `data/writes/write_applier.dart`, `data/tools/apply_changes_tool.dart`, `domain/write_confirmer.dart`
- Test: `test/features/agent_access/data/writes/write_applier_test.dart`, `test/features/agent_access/data/tools/apply_changes_tool_test.dart`

**Interfaces:**
- Consumes: `WritePlanStore`, `WriteCatalog`, `ChangeLogRepository.settleAll`.
- Produces:

```dart
class WriteConfirmation { String? clientName; String label; Map<String, int> countsByEntity;
  Map<String, int> countsByDiver; List<PlanItem> items; }
abstract interface class WriteConfirmer { Future<bool> confirm(WriteConfirmation request); }
class WriteResult { List<({String operationId, String? diverId})> operations;
  Map<String, int> counts; List<String> createdIds; }
class WriteApplier {
  WriteApplier({required WriteCatalog catalog, required ChangeLogRepository changeLog,
    required WriteConfirmer confirmer, required bool Function() confirmEnabled,
    void Function(Iterable<String>) afterDiveWrites = refreshAfterRuleWrites});
  Future<WriteResult> apply(AppDatabase db, WritePlan plan);
}
```

Order inside `apply`: markers, confirmation, then `SyncCoordinator.run` holding markers again, `ChangeLogScope.run(db, source: ChangeLogSource.agent, label: plan.label, body: () => db.transaction(...))`, each item through `WritableEntry`. After the commit: `SyncEventBus.notifyLocalChange()`, `afterDiveWrites` for dives changed or created, then `settleAll()` and read `id = ? OR id LIKE ?` with `'$op:%'` from `change_log_operations`, since the settler files other owners as `op:diver`.

- [ ] **Step 1: Write the failing tests.** `'one operation per diver with source agent'` (two profiles, ids from the result match the feed), `'a stale record refuses the whole plan and names it'`, `'a change to a relation is stale too'`, `'a record edited while the dialog is open refuses after the confirmation'` (the fake confirmer edits the row before answering), `'denied returns not_confirmed and changes nothing'`, `'no confirmation is asked when the setting is off'`, `'a repository refusal rolls back every operation'`, `'a refused apply leaves no entry in the feed'`, `'records are stamped pending'`, `'the refresh runs for the changed dives'`, `'an expired plan is refused'`, `'a plan is single use'`, `'a diver save during the wait is not filed under the agent'`.
- [ ] **Step 2: Run them.** Expected: fail.
- [ ] **Step 3: Implement.** A `FakeWriteConfirmer` in the test file. If `'leaves no entry'` fails, the empty operation comes from `ChangeLogScope._close`; delete it there only when the operation holds no event.
- [ ] **Step 4: Run them.** Expected: pass. Also `TZ=Australia/Sydney` for this folder.
- [ ] **Step 5: Commit** `feat(agent-access): apply a previewed plan as one operation per diver`.

### Task 6: The confirmation dialog

**Files:**
- Create: `presentation/widgets/agent_write_confirm_dialog.dart`, `presentation/providers/agent_write_providers.dart`
- Modify: all 11 ARB files
- Test: `test/features/agent_access/presentation/widgets/agent_write_confirm_dialog_test.dart`, `test/features/agent_access/presentation/providers/agent_write_providers_test.dart`

**Interfaces:**
- Consumes: `WriteConfirmer`, `rootNavigatorKey`, `hasDesktopWindow()`.
- Produces: `class AppWriteConfirmer implements WriteConfirmer` with `AppWriteConfirmer({BuildContext? Function()? context, Duration timeout = const Duration(minutes: 5), Future<void> Function()? raiseWindow})`, and `agentWriteConfirmerProvider`, `agentWritePlanStoreProvider`.

Requests queue, one dialog at a time. The dialog shows the client (or "An agent"), the label, the counts per entity and per diver, an expandable list of every change, then Deny and Allow. The diver name comes from the profile, and units in the list respect that diver's settings through `UnitFormatter`, so a depth shows in feet for a diver using feet.

- [ ] **Step 1: Write the failing tests.** `'shows the client, label and counts'`, `'names an unknown client generically'`, `'Allow answers true'`, `'Deny answers false'`, `'barrier dismiss is off'`, `'timeout closes the dialog and answers false'`, `'two requests show one at a time'`, `'no navigator answers false'`, `'depth respects the diver units'`, `'long values wrap at 2x text'`.
- [ ] **Step 2: Run them.** Expected: fail.
- [ ] **Step 3: Implement.** `raiseWindow` calls `windowManager.show()` then `focus()` when `hasDesktopWindow()`.
- [ ] **Step 4: Run them.** Expected: pass.
- [ ] **Step 5: Commit** `feat(agent-access): ask the diver before applying a plan`.

### Task 7: `revert_operation`

**Files:**
- Create: `data/tools/revert_operation_tool.dart`
- Test: `test/features/agent_access/data/tools/revert_operation_tool_test.dart`

**Interfaces:** Consumes `ChangeLogRevertService.planOperation`, `.execute`, `ChangeLogRepository.settleAll`. Input `operation_id`, `include_changed_since` (default false). Output `reverted`, `kept`, `kept_items`, `operation_id`.

- [ ] **Step 1: Write the failing tests.** `'an applied update reverts to the old values'`, `'an applied delete brings the dive back with its tanks'`, `'an applied create is removed'`, `'a record changed since is kept by default'`, `'include_changed_since reverts it too'`, `'an unknown operation is not_found'`, `'a split operation id reverts one diver'`, `'an operation of another source can be reverted'`.
- [ ] **Step 2: Run them.** Expected: fail.
- [ ] **Step 3: Implement.** Do not wrap in `SyncCoordinator.run`: `execute` takes its own turn.
- [ ] **Step 4: Run them.** Expected: pass.
- [ ] **Step 5: Commit** `feat(agent-access): revert an operation from a tool`.

### Task 8: Registry wiring and end to end

**Files:**
- Modify: `data/tools/agent_tool_registry.dart`, `presentation/providers/agent_access_providers.dart:246-250`
- Test: `test/features/agent_access/data/tools/agent_tool_registry_test.dart`, `test/features/agent_access/data/server/agent_write_e2e_test.dart`

**Interfaces:** `AgentToolRegistry.standard` gains `required WriteCatalog writes`, `required WritePlanStore plans`, `required WriteApplier applier`, `required ChangeLogRevertService revert`, `required ChangeLogRepository changeLog`. The store comes from a provider, because mcp_dart builds a server per request and a plan must outlive it.

- [ ] **Step 1: Write the failing tests.** Registry: the eight tool names. End to end over loopback with the MCP client: initialize, read a dive, preview a change, apply, read the new value, revert, read the old value. Demo gate: `'every write tool refuses in demo mode'`, restoring the gate in `addTearDown`.
- [ ] **Step 2: Run them.** Expected: fail.
- [ ] **Step 3: Implement.** Each tool description states the two-step flow and that a blocked plan has no id.
- [ ] **Step 4: Run them.** Expected: pass.
- [ ] **Step 5: Commit** `feat(agent-access): expose the write tools`.

### Task 9: Coverage guard and documents

**Files:**
- Create: `test/architecture/agent_write_coverage_test.dart`, `test/architecture/agent_write_coverage_baseline.txt`
- Modify: `docs/developer/agent-access.md`, `docs/design/specs/2026-11-01-mcp-server-design.md`

The guard lists public methods named `create*`, `add*`, `insert*`, `update*`, `set*`, `save*`, `delete*`, `remove*`, `upsert*`, `bulk*`, `merge*` on repositories under `lib/features/*/data/repositories`. Each must be named in `covered` (a map in the test, method to the write entity that reaches it) or in the baseline file as `file:method`.

- [ ] **Step 1: Write the test and generate the baseline** from its own output.
- [ ] **Step 2: Prove it can fail:** add a throwaway `deleteEverything` to a repository, run, see the failure name it, remove it. A baseline entry whose method is gone must fail too.
- [ ] **Step 3: Update the docs:** tool surface, how to add a writable entity, the flow, and the rulings above in the spec's decision record as `design` rows.
- [ ] **Step 4: Run** `flutter test test/architecture test/shared test/features/agent_access test/features/change_log test/l10n`, then `flutter analyze` on the whole repository.
- [ ] **Step 5: Commit** `test(agent-access): guard write coverage and document the write flow`.

## After the tasks

`dart format .`, a screenshot of the dialog in light and dark, phone and desktop, by the throwaway golden route, then the PR with `Refs #4071`, then review rounds and the Copilot request as `build-feature` describes.
