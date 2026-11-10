# Remove a data source, and remove duplicate cylinders in bulk: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver remove an unwanted data source from a dive, remove a duplicate cylinder from one dive or from every dive with a serial-proven twin in one undoable action, and dismiss every finding the inbox shows.

**Architecture:** The change log gains an opt-in update trigger for the two series tables, so both removals revert completely. Remove source reuses the ownership and promotion rules extracted from `DiveSplitService`, and deletes where Split moves. Duplicate cylinders merge into a survivor chosen by pure rules, through a repository modelled on `TankRoleRepairRepository.useAsBailout`. A service then runs that merge for one finding or for many under one change log operation. The inbox gains the per-card repair, a Tanks-chip bulk action and "Dismiss all shown".

**Tech Stack:** Flutter, Riverpod, Drift (SQLite triggers), flutter_test with an in-memory `AppDatabase`.

**Spec:** `docs/design/specs/2026-11-09-remove-source-and-duplicate-cylinders-design.md` (issue #4393)

## Global Constraints

- **No em-dashes** in code, comments, ARB strings, commits or the PR.
- **ARB strings in every locale.** Every user-visible string is an ARB key in `lib/l10n/arb/app_en.arb` and in every other `app_*.arb` the project keeps. Run `flutter gen-l10n` after editing.
- **Units.** Any displayed quantity follows the active diver's unit settings, through the existing `buildQualityUnitFormatters`.
- **Do not grow the large files.**
  - At most 800 lines per file.
  - `quality_repair_executor.dart` (798 lines) and `data_quality_inbox_page.dart` (970 lines) must not grow by more than a few dispatch lines. New logic goes in new files.
- **Removals open their own operation.** The removal services open their own change log operation through `ChangeLogScope.bulk`. Callers never wrap them in another scope, or the opt-in label would be lost to the outer operation.
- **Sync.** Every deleted row is logged with `SyncRepository.logDeletion`/`logDeletions`, or deleted through a repository method that tombstones. Every rewritten row is marked pending under a fresh `hlc` where the table has one.
- **Before each commit:** `dart format .`, `flutter analyze` (zero issues), the touched test files, and `test/architecture/` plus `test/shared/` when a `lib/` file was added.
- **Tests restore global state.** `QualityScanScheduler.enabled`, `DatabaseService` test database and harness defaults are restored in `tearDown` (`applyGlobalTestDefaults()`).

## Review Focus

1. **Blob equality on revert.** Reverting a `samples` blob edit compares the live and target values. If it uses `==` on `Uint8List` it sees "changed since" every time. Owner: Task 1, test `revert restores an opted-in samples edit without a changed-since block`.
2. **A removed source's tank is shared** with another computer, through `sharedComputerIds` or another computer's series, events or switches. The tank must stay, with an heir, not be deleted. Owner: Task 3.
3. **Stale findings in a bulk run.** The twin's tanks were already merged or deleted after the scan. The dive is skipped quietly, not counted as failed. Owner: Task 7.
4. **Three cylinders on one serial** raise A-B, A-C and B-C findings. A single run merges all three into one survivor and resolves all three findings. Owner: Task 7.
5. **Serial spelling differences.** Serials that differ only by surrounding whitespace are one group; letter case counts, as the detector compares it (changed in review, so a stale finding cannot widen a merge). Owner: Task 5.

---

### Task 1: Change log records opted-in updates to series rows

**Files:**
- Modify: `lib/core/services/change_log/change_log_scope.dart` (`ChangeLogLabels`: add `removeSource = 'remove_source'`, `removeDuplicateCylinders = 'remove_duplicate_cylinders'`)
- Modify: `lib/core/database/change_log/change_log_policy.dart` (add `const Set<String> changeLogSeriesUpdateLabels = {ChangeLogLabels.removeSource, ChangeLogLabels.removeDuplicateCylinders};` with a doc comment saying why updates to these machine tables are opt-in)
- Modify: `lib/core/database/change_log/change_log_trigger_sql.dart` (`buildChangeLogTriggers`: a `deleteCopyOnly` table also gets `_machineUpdateTrigger`)
- Modify: `lib/features/change_log/data/services/change_log_settler.dart:186-193` (keep `deleteCopyOnly` events whose action is `'U'`)
- Modify: `lib/features/change_log/presentation/change_log_labels.dart` and the ARB files (`changeLog_label_removeSource` "Removed a data source", `changeLog_label_removeDuplicateCylinders` "Removed duplicate cylinders")
- Test: `test/core/database/change_log/change_log_trigger_sql_test.dart`, `change_log_capture_test.dart`, `change_log_lifecycle_test.dart` (trigger count expectations), `test/features/change_log/data/services/change_log_settler_test.dart`, `change_log_restore_test.dart`

**Interfaces:**
- Produces: `ChangeLogLabels.removeSource`, `ChangeLogLabels.removeDuplicateCylinders`, `changeLogSeriesUpdateLabels`. Later tasks open their operations with these labels.

**Trigger shape:**
- Same name pattern as tracked update triggers: `change_log_trg_<table>_u`.
- Same changed-column test and ignored columns as `_updateTrigger`.
- Its `WHEN` adds:
  `EXISTS (SELECT 1 FROM change_log_context c JOIN change_log_operations o ON o.id = c.operation_id WHERE c.id = 1 AND c.scope_expires_at > <now expr used by _eventInsert> AND o.label IN (<quoted labels>))`.
- No schema change: the trigger hash in `before_open_change_log.dart` reinstalls the triggers on next open.

- [ ] **Step 1: Write failing tests.**
  - trigger_sql: `a delete copy only table gets a delete and an opt-in update trigger` asserts two statements for `dive_profile_series`, and that the update one contains `o.label IN ('remove_source', 'remove_duplicate_cylinders')`.
  - capture:
    - `series update outside any operation records nothing`.
    - `series update in a quality_repair operation records nothing`.
    - `series update in a remove_source operation records a U event with old and new samples`, using `logEvents`/`logFields` from `change_log_support.dart`.
  - settler: `a machine row update event survives settling while its dive lives`.
  - restore (template `change_log_restore_test.dart:89-102`):
    - `revert restores an opted-in samples edit without a changed-since block`. Update `samples` and `is_primary` inside a `ChangeLogScope.run(label: removeSource)`, plan the operation, execute it, then assert the original blob bytes and `is_primary`, and assert `plan.hasChangedSince` is false.
- [ ] **Step 2: Run them.** `flutter test test/core/database/change_log test/features/change_log`. Expected: the new tests FAIL.
- [ ] **Step 3: Implement** the labels, policy set, trigger, settler rule and label strings.
  - If the restore test shows a changed-since block, fix the comparison in `_planEdits` (`change_log_revert_service.dart:144`) to compare blobs by content (`listEquals` on `Uint8List`).
- [ ] **Step 4: Run** the same command. Expected: all PASS, including the existing lifecycle and policy tests.
- [ ] **Step 5: Commit.** `feat(change-log): record opted-in edits to series rows so removals revert fully`

### Task 2: Extract Split's ownership and promotion rules

A refactor with no change in behaviour. `DiveSplitService`'s four test files are the guard.

**Files:**
- Create: `lib/features/dive_log/data/services/source_ownership.dart`
- Create: `lib/features/dive_log/data/services/primary_source_promotion.dart`
- Modify: `lib/features/dive_log/data/services/dive_split_service.dart` (call the extracted code; `_snapshotTiming` and `_later` move with the promotion)

**Interfaces:**
- Produces, in `source_ownership.dart`:
  - `class SourceOwnedRows`, holding the rows the source owns as Split selects them (`:117-169`, `:297-299`, `:534-538`):
    - `profileSeries`, `pressureSeries`, `events`, `gasSwitches`;
    - `movedTanks` (no remaining references);
    - `inheritedTanks` (`hasRemainingRefs`, `:304-319`), each with its heir computer id and heir source id;
    - `sharingTanks` (tanks that list the source's computer in `sharedComputerIds`, `:420-445`).
  - `Future<SourceOwnedRows> readSourceOwnedRows(AppDatabase db, {required DiveDataSourcesData source, required List<DiveDataSourcesData> sources, required String diveId})`. It must run inside the caller's transaction, before any delete (`source_id` is ON DELETE SET NULL).
- Produces, in `primary_source_promotion.dart`:
  - `Future<DiveDataSourcesData> promoteAfterPrimaryLeaves(AppDatabase db, SyncRepository sync, {required String diveId, required DiveDataSourcesData leaving, required List<DiveDataSourcesData> sources, required Dive diveRow, required Set<String> liveEditIds, required int now})`.
  - It covers Split's step 9 (`:613-720`): promote the earliest remaining source, `promoteOwnedBy` when there is no primary series, `rezeroDiveTimeline`, `clearReviewForDive`, the headline rebuild, and the dive write marked pending.
  - It returns the promoted source.
  - The caller owns the transaction.

- [ ] **Step 1: Run Split's tests on main as a baseline.**
  `flutter test test/features/dive_log/data/services/dive_split_service_test.dart test/features/dive_log/data/services/dive_split_service_series_test.dart test/features/dive_log/data/services/dive_split_tank_source_id_test.dart test/features/dive_log/data/services/dive_split_timeline_test.dart`. Expected: PASS.
- [ ] **Step 2: Extract** both files and make `_splitInner` call them. Keep every query and write in the same order.
- [ ] **Step 3: Run** the same four files plus `test/features/dive_log/integration/multi_computer_integration_test.dart`. Expected: PASS, unchanged.
- [ ] **Step 4: Commit.** `refactor(dive-log): share split's source ownership and primary promotion rules`

### Task 3: Remove-source service

**Files:**
- Create: `lib/features/dive_log/data/services/dive_source_removal_service.dart`
- Create: `lib/features/change_log/data/services/change_log_operation_undo.dart`
- Modify: `lib/features/dive_log/presentation/providers/dive_providers.dart` (add `diveSourceRemovalServiceProvider` next to `diveSplitServiceProvider`, `:240`)
- Test: `test/features/dive_log/data/services/dive_source_removal_service_test.dart`. Copy the row helpers from `dive_split_service_test.dart:29-167`.

**Interfaces:**
- Consumes: `readSourceOwnedRows`, `promoteAfterPrimaryLeaves` (Task 2), `ChangeLogLabels.removeSource` (Task 1).
- Produces:
  - `class SourceRemoval { final String? operationId; }`
  - `class DiveSourceRemovalService { Future<SourceRemoval> remove({required String diveId, required String sourceId}); }`
    - Throws `ArgumentError` when the source is not on the dive or is its only source.
    - Throws `UnreadableSeriesException` like Split.
  - `Future<bool> undoChangeLogOperation(String? operationId)`.
    - It is the body of `DiveBulkDeleteService._revertDelete` (`dive_bulk_delete_service.dart:111-130`) made shareable: settle, plan the operation, execute.
    - It returns `result.kept == 0`.
    - `DiveBulkDeleteService` switches to it.

**The removal, in one `_db.transaction` inside `ChangeLogScope.bulk(label: ChangeLogLabels.removeSource)`:**
1. Read the sources and the owned rows.
2. Give inherited tanks their heir, and strip the computer from sharing tanks (Split's writes, without the clone).
3. Delete in Split's order, with Split's tombstones: switches, pressure series, profile series, events (scoped tombstone plus user-source events), moved tanks.
4. Delete the source row with `logDeletion(entityType: 'diveDataSources')`.
5. When it was the primary, call `promoteAfterPrimaryLeaves`.
6. After commit, call `SyncEventBus.notifyLocalChange()`.

The operation id is captured with `ChangeLogScope.currentOperationId` inside the body.

- [ ] **Step 1: Write failing tests.**
  - `removing a secondary source deletes it and only what it owns`: the primary's series, tanks and events remain.
  - `logs a deletion for the source, its tanks, switches and series`: assert on `db.deletionLog`.
  - `removing the primary promotes the earliest remaining source and re-zeroes its timeline`: assert `isPrimary` and the dive's `diveDateTime`.
  - `refuses the only source`, expecting `ArgumentError`.
  - `leaves the logbook entry untouched`: notes, site, buddies and tags are unchanged.
  - `a tank another computer still uses stays, with an heir` (Review Focus 2).
  - `reverting the operation brings the dive back as it was`: the source, its series samples, tanks, switches, primary flag and headline all return, and `fkViolations()` is empty.
- [ ] **Step 2: Run** `flutter test test/features/dive_log/data/services/dive_source_removal_service_test.dart`. Expected: FAIL (service missing).
- [ ] **Step 3: Implement** the service, the undo helper and the provider. Switch `DiveBulkDeleteService` to the helper.
- [ ] **Step 4: Run** the new test file, `test/features/dive_log/data/services/dive_bulk_delete_service_test.dart` and the Split tests. Expected: PASS.
- [ ] **Step 5: Commit.** `feat(dive-log): remove a data source from a dive`

### Task 4: Remove source in the dive's Data Sources menu and on Conflicting sources findings

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/remove_source_dialog.dart`. It provides `Future<bool> confirmRemoveSource(BuildContext context, {required String? source})`. Title "Remove this source?". The body says the readings from `{source}` will be removed from this dive and the logbook entry stays. Confirm button "Remove".
- Modify: `lib/features/dive_log/presentation/widgets/data_sources_section.dart`
  - `_SourceMenuAction.remove`
  - an `onRemove` callback, passed only when `isMultiSource`, like `onSplit` (`:186-188`)
  - menu key `diveLog_sources_menu_remove` "Remove source"
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_data_sources_section.dart`, `dive_detail_actions.dart` (add `removeSource`), `dive_detail_page.dart:266` and `dive_detail_page_actions.dart`
  - Add `_confirmAndRemoveSource(Dive dive, String sourceId)`, modelled on `_confirmAndSplit` (`:311-356`).
  - It shows a snackbar with Undo that calls `undoChangeLogOperation`.
  - Keys: `diveLog_sources_removeDone` "Source removed", `diveLog_sources_removeFailed` "Could not remove the source".
- Modify: `lib/features/data_quality/domain/repairs/quality_repair_action.dart`
  - Add `RemoveSourceRepair({required diveId, required sourceId})`.
  - The `source_conflict` case (`:521-529`) offers it after `SplitSourceRepair`.
- Modify: `lib/features/data_quality/presentation/widgets/quality_finding_card.dart`. Add labels `dataQuality_repairLabel_removeSource` "Remove source" and `dataQuality_repairLabel_removeSourceNamed` "Remove {source}".
- Modify: `lib/features/data_quality/presentation/pages/data_quality_inbox_page.dart` (`_runAction`)
  - The new case confirms, calls the service directly (like Split at `:350-367`, never inside the executor's scope), sets the finding resolved and schedules a scan.
  - Its snackbar Undo calls `undoChangeLogOperation`.
- Test:
  - `test/features/dive_log/presentation/widgets/data_sources_section_test.dart`: `Remove source is offered for each source when there are two or more` and `not offered for a single source`.
  - `test/features/data_quality/repairs/repair_mapping_test.dart`: `source_conflict offers remove source`.
  - `test/features/data_quality/presentation/data_quality_inbox_page_test.dart`: `remove source repair asks before removing`.

- [ ] **Step 1: Capture the before screenshots**, before touching UI code: a multi-source dive's Data Sources menu, and the inbox with a source conflict card.
- [ ] **Step 2: Write the failing widget and mapping tests.**
- [ ] **Step 3: Run them.** Expected: FAIL.
- [ ] **Step 4: Implement**, add the ARB keys in every locale, then run `flutter gen-l10n`.
- [ ] **Step 5: Run** the three test files. Expected: PASS.
- [ ] **Step 6: Commit.** `feat(dive-log): offer Remove source on the dive and on conflicting-source findings`

### Task 5: Duplicate-cylinder rules

**Files:**
- Create: `lib/features/data_quality/domain/repairs/duplicate_cylinder_rules.dart`
- Test: `test/features/data_quality/domain/repairs/duplicate_cylinder_rules_test.dart`

**Interfaces:**
- Produces pure functions over the Drift `DiveTank` rows:
  - `List<List<String>> serialGroups(List<DiveTank> tanks)`:
    - groups tanks by `transmitterSerial` through the detector's own `normalizeTransmitterSerial` (trimmed, case kept, all-zero as none);
    - ignores null or empty serials;
    - keeps groups of two or more;
    - sorts ids within a group and groups by their first id.
  - `List<String> duplicateGroupFor({required String tankIdA, required String tankIdB, required bool sameTransmitter, required List<DiveTank> tanks})`:
    - when `sameTransmitter`, returns the serial group containing `tankIdA`;
    - otherwise returns `[tankIdA, tankIdB]`;
    - returns only ids still present (empty when fewer than two remain).
  - `String pickSurvivor(List<DiveTank> group, {required String? primarySourceId})`:
    - the tanks whose `sourceId == primarySourceId` are the candidates, or all tanks when none or all of them are;
    - then the most detail, counting non-null `volume`, `workingPressure`, `tankName` or `presetName` (one point), `equipmentId`, `regulatorEquipmentId`;
    - then the lowest id.
  - `bool mixesDiffer(List<DiveTank> group)`: true when any two differ in `o2Percent` or `hePercent` by more than 0.05.

- [ ] **Step 1: Write failing tests:**
  - `serial groups trim whitespace but keep case, as the detector does` (Review Focus 5)
  - `serial groups skip tanks without a serial`
  - `three tanks on one serial form one group`
  - `curve-only twins form a pair`
  - `stale ids are dropped`
  - `survivor is the primary source's tank`
  - `without a primary tank the most detailed tank survives`
  - `ties go to the lowest id`
  - `gas mix does not count as detail`: 32/0 vs 21/0, with everything else equal, picks the lower id
  - `mixes differ on O2`
  - `mixes differ on He`
  - `equal mixes do not differ`
- [ ] **Step 2: Run** `flutter test test/features/data_quality/domain/repairs/duplicate_cylinder_rules_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit.** `feat(data-quality): rules for choosing which duplicate cylinder stays`

### Task 6: Merge duplicate cylinders into the survivor

**Files:**
- Create: `lib/features/dive_log/data/repositories/duplicate_cylinder_repository.dart`
- Modify: `lib/features/dive_log/data/repositories/tank_pressure_repository.dart`. Add a public `Future<int> moveTankPressureSeries(String diveId, String fromTankId, String toTankId)` that wraps `TankPressureSeriesRepository.reassignTank` (`tank_pressure_series_repository.dart:235`).
- Test: `test/features/dive_log/data/repositories/duplicate_cylinder_repository_test.dart`

**Interfaces:**
- Produces: `class DuplicateCylinderRepository { DuplicateCylinderRepository({AppDatabase? database}); Future<bool> mergeInto({required String diveId, required String survivorId, required List<String> duplicateIds, ({double o2, double he})? mix, required int now}); }`.
  - The caller owns the transaction and the notify.
  - Returns false when the survivor or every duplicate has gone.

**The merge, in order** (pattern: `TankRoleRepairRepository.useAsBailout`, `tank_role_repair_repository.dart:41-98`):
1. Update the survivor (fresh `hlc`, pending `diveTanks`):
   - fill each null `volume`, `workingPressure`, `tankName`, `presetName`, `equipmentId`, `regulatorEquipmentId` from the first duplicate that has it;
   - apply `mix` when given;
   - `sharedComputerIds` becomes the union of its own and every duplicate's `computerId` and `sharedComputerIds`, minus the survivor's own `computerId`, encoded with the existing `encodeSharedComputerIds`.
2. If the survivor has no pressure series (`hasTankSeries`) and a duplicate does:
   - move that duplicate's series with `moveTankPressureSeries`;
   - copy its `startPressure`, `endPressure`, `sourceTankIndex`.
3. Re-point `gasSwitches` and `diveProfileEvents` from each duplicate to the survivor (fresh `hlc` on switches, pending marks).
4. Delete each duplicate with `DiveChildRowRepository.deleteTank` (`dive_child_row_repository.dart:82`). It deletes the duplicate's remaining series with tombstones and logs the tank deletion.

- [ ] **Step 1: Write failing tests:**
  - `fills only the survivor's empty details`
  - `applies the chosen mix`
  - `unions shared computers and adds the duplicate's computer`
  - `moves the series when the survivor has none`
  - `deletes the duplicate's series when the survivor has its own`
  - `re-points gas switches and profile events`
  - `logs the duplicate tank deletion`
  - `returns false when the duplicates are already gone`
- [ ] **Step 2: Run** the new test file. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit.** `feat(dive-log): merge duplicate cylinders into one`

### Task 7: Duplicate-cylinder service, single and bulk

**Files:**
- Create: `lib/features/data_quality/data/services/duplicate_cylinder_service.dart`
- Test: `test/features/data_quality/data/services/duplicate_cylinder_service_test.dart`

**Interfaces:**
- Consumes: Tasks 1, 5 and 6, plus `QualityFindingsRepository.setStatus`, `scheduleQualityScan`, `scheduleSensorSummaryRefresh(force: true)` and `scheduleDerivedMetricsRefresh(force: true)`, as `QualityRepairExecutor._rescan` calls them.
- Produces:
  - `class CylinderMergePreview { final String diveId; final String survivorId; final List<String> duplicateIds; final bool mixesDiffer; final List<({String tankId, double o2, double he})> mixes; }`
  - `class DuplicateRemovalResult { final int merged; final int skippedMixes; final int failed; final String? operationId; }`
  - `class DuplicateCylinderService`:
    - `Future<CylinderMergePreview?> previewFor(QualityFinding twin)`. Returns null when the group has fewer than two live tanks.
    - `Future<DuplicateRemovalResult> removeOne(CylinderMergePreview preview, {({double o2, double he})? mix, required List<String> findingIds})`.
    - `List<QualityFinding> bulkCandidates(Iterable<QualityFinding> open)`: `detectorId == 'tank_assignment'`, `tankIdA`/`tankIdB` present, `sameTransmitter == true`.
    - `Future<List<CylinderMergePreview>> previewAll(List<QualityFinding> candidates)`: one preview per dive and serial group.
    - `Future<DuplicateRemovalResult> removeAll(List<CylinderMergePreview> previews, {required List<QualityFinding> candidates, void Function(int done, int total)? onProgress})`.

**Behaviour:**
- Both writes run in `ChangeLogScope.bulk(label: ChangeLogLabels.removeDuplicateCylinders)`, with one transaction per dive, then `SyncEventBus.notifyLocalChange()` once.
- `removeAll`:
  - skips previews with `mixesDiffer`, counted in `skippedMixes`, leaving their findings open;
  - skips a stale preview whose merge returns false without counting it;
  - counts a thrown merge in `failed` and keeps going;
  - marks resolved every candidate finding whose dive merged.
- The operation id comes from `ChangeLogScope.currentOperationId`.

- [ ] **Step 1: Write failing tests:**
  - `bulk candidates are serial-proven twins only`
  - `three tanks on one serial merge in one run and resolve all three findings` (Review Focus 4)
  - `dives whose mixes differ are skipped and their findings stay open`
  - `a stale finding is skipped without counting a failure` (Review Focus 3)
  - `one failing dive does not stop the batch`
  - `the whole batch reverts with one undo`: `undoChangeLogOperation(result.operationId)` brings back every tank and its series samples
- [ ] **Step 2: Run** the new test file. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit.** `feat(data-quality): remove duplicate cylinders on one dive or many`

### Task 8: Inbox actions: per-card removal, bulk removal, Dismiss all shown

**Files:**
- Create: `lib/features/data_quality/presentation/widgets/duplicate_cylinder_dialogs.dart`:
  - `Future<bool> confirmRemoveDuplicate(...)`
  - `Future<({double o2, double he})?> chooseDuplicateMix(...)`, listing each cylinder's mix as `O2/He`, defaulting to the survivor's
- Create: `lib/features/data_quality/presentation/widgets/duplicate_cylinders_sheet.dart`. The bulk confirmation sheet:
  - one row per dive using `DiveIdentityLabel`, with "Remove {n} cylinders, keep {name}";
  - a skipped line when `skippedMixes > 0`;
  - progress while it runs.
- Create: `lib/features/data_quality/presentation/pages/data_quality_inbox_actions.dart`. Holds the handlers the page calls, so the page grows by dispatch lines only:
  - `runRemoveDuplicate`
  - `runBulkRemoveDuplicates`
  - `runDismissAllShown`
- Modify: `lib/features/data_quality/domain/repairs/quality_repair_action.dart`.
  - Add `RemoveDuplicateCylinderRepair({required diveId, required tankIdA, required tankIdB, required sameTransmitter})`.
  - It comes first in the twin branch of `tank_assignment` (`:504-520`).
- Modify: `quality_finding_card.dart`, label `dataQuality_repairLabel_removeDuplicate` "Remove duplicate cylinder".
- Modify: `lib/features/data_quality/data/repositories/quality_findings_repository.dart`.
  - Add `Future<void> reopenAll(Iterable<String> ids)`, mirroring `dismissAll` (`:267`) with `QualityStatus.open`.
- Modify: `data_quality_inbox_page.dart`:
  - A `_runAction` case for the new repair.
  - An AppBar `IconButton` for bulk removal, shown when `_chip == QualityChip.tanks` and `bulkCandidates(open)` is non-empty. Tooltip and label `dataQuality_bulk_removeDuplicates` "Remove duplicate cylinders ({count} dives)".
  - An AppBar `PopupMenuButton` holding `dataQuality_action_dismissAllShown` "Dismiss all shown ({count})", acting on `open`.
- ARB keys in every locale:
  - `dataQuality_bulk_removeDuplicates_done` "Removed on {count} dives"
  - `dataQuality_bulk_skippedMixes` "{count} skipped: gas mixes differ"
  - `dataQuality_bulk_failed` "{count} failed"
  - `dataQuality_dismissAll_title`, `dataQuality_dismissAll_body`, `dataQuality_dismissAll_confirm`, `dataQuality_dismissAll_done` "Dismissed {count} findings"
  - the dialog and sheet titles
- Test:
  - `test/features/data_quality/repairs/repair_mapping_test.dart`: `twin findings offer remove duplicate first`.
  - `test/features/data_quality/presentation/data_quality_inbox_page_test.dart`:
    - `bulk removal shows only on the Tanks chip with serial-proven twins`
    - `bulk removal is hidden for curve-only twins`
    - `dismiss all shown dismisses exactly the shown findings and undo reopens them`
    - `a twin whose mixes differ asks which mix to keep`
  - `test/features/data_quality/data/repositories/quality_findings_repository_test.dart`: `reopenAll reopens and marks pending`.

- [ ] **Step 1: Capture the before screenshots**, before touching UI code: the inbox on the Tanks chip with a twin card, and the inbox AppBar.
- [ ] **Step 2: Write the failing tests.**
- [ ] **Step 3: Run them.** Expected: FAIL.
- [ ] **Step 4: Implement**, add the ARB keys in every locale, then run `flutter gen-l10n`.
- [ ] **Step 5: Run** the touched test files, `test/architecture/` and `test/shared/`. Expected: PASS.
- [ ] **Step 6: Commit.** `feat(data-quality): remove duplicate cylinders in bulk and dismiss all shown findings`

### Task 9: Whole-branch check and after screenshots

- [ ] **Step 1: Run the checks.** `dart format .`, `flutter analyze`, then `flutter test test/features/data_quality test/features/dive_log test/features/change_log test/core/database test/architecture test/shared` in the background with a log in the scratchpad. Expected: all PASS.
- [ ] **Step 2: Capture the after screenshots** of the same screens as Tasks 4 and 8, in light and dark (the sheet and dialogs are new surfaces), at phone and desktop widths.
- [ ] **Step 3: Commit** any formatting fixes: `chore: format`.
