# MCP Server PR 5d: Gear Service Ledger Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Agents can write service kinds, service clocks and service records, and replace a fitted part, each through the repository its page uses, with the page's save rules.

**Architecture:** One `WritableEntry` per entity in `lib/features/agent_access/data/writes/families/`, registered in `WriteCatalog`. The write core gains three general hooks first: `afterApply` for every kind of change, `createTouched` and `DeleteReach.touched` (so a create or delete can list the rows of other records it rewrites, as an update already does), and a reminder callback wired from the provider layer.

**Tech Stack:** Dart, Flutter, Drift, flutter_test.

**Spec:** `docs/design/specs/2026-11-01-mcp-server-design.md`. The 5d and 5e split and every "my call" below were approved in chat on 2026-11-04.

## Global Constraints

- Release v1.8.4; issue #4071 (`Refs #4071`). Branch `ericgriffin/feat-4071-gear-service`, stacked on #4199, PR to main.
- Everything stays behind debug mode; nothing user-visible beyond the confirm dialog's existing lines.
- No em-dashes or en-dash prose punctuation anywhere, including comments and commit messages. No mention of Claude or Anthropic in repo or GitHub text.
- Every write goes through the app's repository; no raw SQL writes.
- Files 200 to 400 lines, 800 max; `write_planner.dart` is at 682 lines, so new planner code goes in a part file.
- Paths built with `p.join`; tests restore any process-wide state they replace.
- Dates the app stores as days use `FieldCodec.calendarDate`; currency codes are three upper-case letters.

## Review Focus

1. A built-in service kind named by an update or delete: blocked, never a `StateError` at apply.
2. A clock create for a kind already on the item, within one set or against a stored clock: the second is a duplicate.
3. A record's effect on the item's last service date, including an older record (`createRecord` writes it as is, issue #4201): the preview says what the apply does.
4. A part replacement whose part leaves the kit or loses its parent earlier in the set: blocked by the same `inKitSoFar` reading the apply sees.
5. A reminder reschedule that fails: logged, the apply stands.

---

### Task 1: Write core hooks

**Files:**
- Modify: `lib/features/agent_access/data/writes/writable_entity.dart`, `write_applier.dart`, `write_planner.dart` (calls only), new part `write_planner_touched.dart` if the planner needs more than a few lines
- Modify: `lib/features/agent_access/data/writes/families/equipment_writes.dart` (the one existing `afterApply`)
- Test: `test/features/agent_access/data/writes/write_hooks_test.dart`

**Interfaces:**
- Produces:
  - `class AppliedChange { final ChangeKind kind; final String id; final String? parentId; final Set<String> changed; }` in `writable_entity.dart`.
  - `Future<void> WritableEntry.afterApply(AppliedChange change)`, replacing `afterApply(String id, Set<String> changed)`. The applier calls it for every applied item after the commit: an update with its id and field keys; a create with the created id (from `WriteResult.created` by operation) and its value keys; a delete with its id and no keys. `parentId` is the item's `parentId`.
  - `Future<Map<String, int>> WritableEntry.createTouched(String diverId, Map<String, Object?> values)`, default `const {}`; the planner puts it in `PlanItem.alsoChanges` for a create it keeps.
  - `DeleteReach.touched` (`Map<String, int>`, default empty, part of the reach's footprint text); the planner puts it in `PlanItem.alsoChanges` for a delete.
- `EquipmentWrites.afterApply` keeps its rule: rescan on an update whose `changed` holds `serial_number`.

- [ ] Step 1: Write the failing tests: a probe entry in the test records every `AppliedChange`; a set of a create, an update and a delete applies and the probe sees three changes with the right kinds, ids and parentIds; an entry whose `createTouched` returns `{'equipment': 1}` gives the create's item `alsoChanges: {'equipment': 1}`; a reach with `touched: {'equipment': 1}` does the same for a delete.
- [ ] Step 2: Run `flutter test test/features/agent_access/data/writes/write_hooks_test.dart`. Expected: FAIL (no `AppliedChange`).
- [ ] Step 3: Implement. A failure in `afterApply` is logged and the apply stands, as now.
- [ ] Step 4: Run the new test and `test/features/agent_access`. Expected: PASS.
- [ ] Step 5: Commit `feat(agent-access): after-apply and touched hooks for every change`.

### Task 2: Codecs for kinds and clocks

**Files:**
- Modify: `lib/features/agent_access/data/writes/field_codec.dart`
- Test: `test/features/agent_access/data/writes/field_codec_test.dart`

**Interfaces:**
- Produces:
  - `FieldCodec.numberMap({required Set<String> keys, num min, num max})`: an object whose keys are a subset of `keys`, each a number in range. Parsed value is the JSON of the map with keys sorted; `canonical` encodes a document map the same way; `wire` decodes. An empty object is allowed (no intervals).
  - `FieldCodec.enumList(Iterable<Enum> values)`: a list of distinct `.name`s. Parsed value is the JSON of the names sorted; `canonical` and `wire` as above.

- [ ] Step 1: Failing tests: `numberMap` refuses an unknown key, a non-number and an out-of-range value, and `{'b': 1, 'a': 2}` parses equal to `{'a': 2, 'b': 1}`; `enumList` refuses an unknown name and a repeat, and orders names.
- [ ] Step 2: Run the codec test. Expected: FAIL.
- [ ] Step 3: Implement.
- [ ] Step 4: Run. Expected: PASS.
- [ ] Step 5: Commit `feat(agent-access): number map and enum list codecs`.

### Task 3: Service kinds

**Files:**
- Create: `lib/features/agent_access/data/writes/families/service_kind_writes.dart`
- Modify: `write_catalog.dart`
- Test: `test/features/agent_access/data/writes/service_kind_writes_test.dart`

**Interfaces:**
- Entity `service_kinds`, table `service_kinds`, owner-scoped (create takes the owner's `diverId`).
- Fields, keyed as `serviceKindDocument` reads them: `name` (text, trim, 1 to 100), `applicable_types` (`enumList(EquipmentType.values)`, empty = every type), `default_interval_days` and `default_interval_dives` (integer 1 to 100000, nullable), `default_interval_hours` (number above 0 to 100000, nullable), `exposure_intervals` (`numberMap` over the `ExposureUnit` names other than days, dives and hours, each above 0), `default_cost` (number 0 to 10000000, nullable), `default_currency` (three letters, upper-cased, nullable = inherit), `default_category` (`ServiceCategory` name, nullable), `auto_attach` (flag). `requiredOnCreate`: `name`.
- Writes: `ServiceKindRepository.createKind`, `updateKind` (from the stored kind with the values applied), `deleteKind`.

Rules:
- `refuse`: an update or delete of a kind whose `is_built_in` is true is `BlockReason.notPermitted` ("a built-in service type is the app's own; hide it in Settings instead").
- `refuse`: a count unit in `exposure_intervals` (`coldDives`, `deepCycles`, `cycles`; only `saltHours` and `o2Hours` may be fractional) must be a whole number, as the editor requires; `invalidValue` otherwise.
- `deleteReach`: `parts` from `countCascaded('service_kinds', id)` (its clocks). Records keep the kind's id; nothing to list.

- [ ] Step 1: Failing tests: create, rename and delete a custom kind; a delete lists its clocks under parts and removes them; an update and a delete of a built-in (seeded `hydro`) are `notPermitted`; `default_interval_days: 0` and `exposure_intervals: {'coldDives': 1.5}` are `invalidValue`; `applicable_types` round-trips.
- [ ] Step 2: Run the test. Expected: FAIL.
- [ ] Step 3: Implement and register in `WriteCatalog`.
- [ ] Step 4: Run. Expected: PASS.
- [ ] Step 5: Commit `feat(agent-access): agent writes for service kinds`.

### Task 4: Service clocks

**Files:**
- Create: `lib/features/agent_access/data/writes/families/service_schedule_writes.dart`
- Modify: `write_catalog.dart`; `lib/features/equipment/data/repositories/service_schedule_repository.dart` (make `_hiddenServiceKinds` public as `hiddenServiceKindIds`, and `autoAttachKindsFor` calls it)
- Test: `test/features/agent_access/data/writes/service_schedule_writes_test.dart`

**Interfaces:**
- Entity `service_schedules`, `ChildOf(entity: 'equipment', field: 'equipment_id')`.
- Fields, keyed as `serviceScheduleDocument`: `equipment_id` (reference), `service_kind_id` (reference `service_kinds`), `interval_days`, `interval_dives`, `interval_hours`, `exposure_intervals` (as Task 3, nullable overrides), `default_cost`, `default_currency`, `anchor_date` (`calendarDate`, nullable), `enabled` (flag). `requiredOnCreate`: `service_kind_id`.
- `uniqueKey`: `UniqueClaim('$equipmentId/$kindId')` on create.
- Writes: `createSchedule(ServiceSchedule(id: '', ...))` with `withBaseline(anchor, now: DateTime.now(), picked: true)` when `anchor_date` is named; `updateSchedule(current.copyWith(...))`, with `withBaseline(..., picked: true)` when `anchor_date` is named; `deleteSchedule`.
- Consumes from 5c: `inKitSoFar` is not enough here; the wanted check reads the status an earlier change writes (`soFar.values[('equipment', id)]['status']`) before the stored one.

Rules (`refuse`, create unless noted):
- `service_kind_id` or `equipment_id` named on an update: `invalidValue` (the dialog cannot change either).
- The kind must apply to the item's type (`ServiceKind.appliesTo`), must not be another diver's custom kind, and must not be a built-in the owner hid (`hiddenServiceKindIds`): `invalidValue`.
- The item must not be wanted (the clocks card is hidden for wanted gear): `invalidValue`.
- The item already has a clock of that kind: `duplicateRecord`.
- `anchor_date` from 1950-01-01 to today: `invalidValue` otherwise.
- A clock with no interval at all, neither the kind's defaults nor an override: `invalidValue` (the dialog opens its override step for such a kind).
- `afterApply`: the reminder callback (Task 6) for `parentId`.

- [ ] Step 1: Failing tests: a clock is created, re-baselined (anchor written, picked) and deleted; a second clock of one kind, in the set and against a stored one, is a duplicate; a kind for another type, another diver's custom kind, a hidden built-in, and a clock on a wanted item are `invalidValue`; `service_kind_id` on an update is `invalidValue`; an anchor in the future is `invalidValue`.
- [ ] Step 2: Run. Expected: FAIL.
- [ ] Step 3: Implement.
- [ ] Step 4: Run, with `test/features/equipment`. Expected: PASS.
- [ ] Step 5: Commit `feat(agent-access): agent writes for service clocks`.

### Task 5: Service records

**Files:**
- Create: `lib/features/agent_access/data/writes/families/service_record_writes.dart`
- Modify: `write_catalog.dart`
- Test: `test/features/agent_access/data/writes/service_record_writes_test.dart`

**Interfaces:**
- Entity `service_records`, `ChildOf(entity: 'equipment', field: 'equipment_id')`.
- Fields, keyed as `serviceRecordDocument`: `equipment_id`, `service_kind_id` (reference `service_kinds`), `category` (`ServiceCategory` name), `service_date` (`calendarDate`), `next_service_due_date` (`calendarDate`, nullable), `provider` (text, trim, blank = null), `cost` (number 0 to 10000000, nullable), `currency` (three letters, upper-cased), `notes` (text, trim, blank allowed). `requiredOnCreate`: `service_kind_id`, `service_date`.
- Create defaults, as the dialog prefills them: `category` = `resolveDefaultServiceCategory` else `annual`; `cost` and `currency` = `resolveDefaultServiceCost` over the item's clocks and the owner's kinds; a currency still missing = the owner's `diver_settings.default_currency`, else `USD`.
- Writes: `ServiceRecordRepository.createRecord`, `updateRecord`, `deleteRecord`.

Rules:
- The kind must be one the record dialog offers: the owner's kinds minus hidden built-ins, plus any kind of one of the item's clocks; on an update, the record's current kind also stays allowed. `invalidValue` otherwise.
- `service_date` from 1950-01-01 to today; `next_service_due_date` from 1950-01-01 to ten years from today.
- `createTouched` and `sideEffects.touched` and `deleteReach.touched`: `{'equipment': 1}` when the item's `last_service_date` changes. Create: the repository writes the record's date as is (issue #4201), so it changes when that date differs from the stored one. Update and delete: the newest remaining record's date, or none, against the stored one.
- `afterApply`: the reminder callback for `parentId`.

- [ ] Step 1: Failing tests: a record is created with the defaults filled (kind default category, a clock's cost), edited and deleted; an older record lists `{'equipment': 1}` and the apply moves the date back (pinning #4201's current behaviour); deleting the only record clears the date and lists it; a hidden built-in kind is `invalidValue`; a date tomorrow is `invalidValue`.
- [ ] Step 2: Run. Expected: FAIL.
- [ ] Step 3: Implement.
- [ ] Step 4: Run. Expected: PASS.
- [ ] Step 5: Commit `feat(agent-access): agent writes for service records`.

### Task 6: Reminder callback

**Files:**
- Modify: `lib/features/agent_access/data/writes/agent_write_services.dart`, `write_catalog.dart`, `lib/features/agent_access/presentation/providers/agent_access_providers.dart`
- Test: in `service_record_writes_test.dart` and `service_schedule_writes_test.dart`

**Interfaces:**
- Produces: `typedef GearReminderRefresh = Future<void> Function(String equipmentId);`. `WriteCatalog(records, {GearReminderRefresh? refreshReminders})` passes it to the record and clock writers; `AgentWriteServices` takes and forwards it. The provider wiring builds it as the record notifier's `_rescheduleNotifications` does: read `settingsProvider`, return when notifications are off, load the item, `notificationSchedulerProvider.updateForEquipment`.

- [ ] Step 1: Failing tests: a record create and a clock update each call a recording callback once with the item id; a callback that throws leaves the apply in place.
- [ ] Step 2: Run. Expected: FAIL.
- [ ] Step 3: Implement.
- [ ] Step 4: Run. Expected: PASS.
- [ ] Step 5: Commit `feat(agent-access): reschedule gear reminders after service writes`.

### Task 7: Part replacement

**Files:**
- Modify: `lib/features/agent_access/data/writes/families/equipment_writes.dart`
- Test: `test/features/agent_access/data/writes/equipment_replace_test.dart`

**Interfaces:**
- New field `replaces_equipment_id` (reference `equipment`), create only.
- `requiredOnCreate` becomes empty; `refuse` asks for `name` and `type` (`BlockReason.missingField`, the planner's wording) unless `replaces_equipment_id` is named.
- A create naming `replaces_equipment_id` names nothing else: any other field is `invalidValue` ("a replacement copies its part; change it with an update once it exists").
- `create`: `replaceChild(old)` and return the successor's id.
- `alsoCreates`: the clocks of the old part's type (as an item create lists them). `createTouched`: `{'equipment': 1}` (the old part is retired).

Rules:
- The old part must have a parent and be in the kit as the set leaves it (`inKitSoFar`): `invalidValue` otherwise. `replaces_equipment_id` on an update: `invalidValue`.

- [ ] Step 1: Failing tests: a fitted cell is replaced, the new one holds its parent and spec attributes and the old one is retired; the plan lists the clocks and `{'equipment': 1}`; a part with no parent, one retired earlier in the set, and a create naming `name` too are `invalidValue`; a create with neither `replaces_equipment_id` nor `name` is `missingField`.
- [ ] Step 2: Run. Expected: FAIL.
- [ ] Step 3: Implement.
- [ ] Step 4: Run, with the 5c item tests. Expected: PASS.
- [ ] Step 5: Commit `feat(agent-access): replace a fitted part through the agent`.

### Task 8: Coverage, docs, screenshots

**Files:**
- Modify: `test/architecture/agent_write_coverage_test.dart`, `test/architecture/agent_write_coverage_baseline.txt` (regenerated), `docs/developer/agent-access.md`

Coverage:
- `covered`: `service_kind_repository.dart:createKind|updateKind|deleteKind` as `service_kinds`; `service_schedule_repository.dart:createSchedule|updateSchedule|deleteSchedule` as `service_schedules`; `service_record_repository.dart:createRecord|updateRecord|deleteRecord` as `service_records`; `equipment_repository_impl.dart:replaceChild` as `equipment`; `service_schedule_repository.dart:applyBaselines` as `equipment` (the item save calls it).
- `exempt`: `equipment_repository_impl.dart:markAsServiced`, "a legacy field with no caller in the app, and a write that skips sync".

- [ ] Step 1: Update the maps; run `UPDATE_AGENT_WRITE_BASELINE=1 flutter test test/architecture/agent_write_coverage_test.dart`, then the test without it. Expected: PASS, with these methods gone from the baseline.
- [ ] Step 2: Add a "Service ledger" paragraph to the Gear section of `docs/developer/agent-access.md`: the built-in refusal, the clock rules, the record defaults and the last service date note, part replacement, and the reminder callback.
- [ ] Step 3: Full checks: `dart format .`, `flutter analyze` (whole repo), and `flutter test test/features/agent_access test/architecture test/features/equipment test/features/settings test/shared`. Expected: all pass.
- [ ] Step 4: Commit `docs(agent-access): service ledger writes`. No UI change beyond the confirm dialog's existing lines, so the PR ticks "No visible UI change" and says why.
