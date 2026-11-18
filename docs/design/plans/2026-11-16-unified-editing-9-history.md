# Unified Editing, Plan 9: Every Change in a Sitting Is in Its History Entry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every change a dive sitting saves appear in the dive's one History entry, with old and new values, and go back when that entry is reverted: a dismissed safety finding, readings moved between cylinders, and the sitting's writes to other records (a document, a plan link, a route link, the site, the trip) (issue #4527).

**Architecture:** Three changes to the change log, none to its schema. (1) A sitting's operation opts in to machine-row updates, as remove source and the agent already do, and `dive_safety_findings` joins those tables with only `dismissed_at` recorded. (2) A sitting's label names its record (`record_edit:dives:<id>:<cards>`), and the settler keeps such an operation, and a revert of it, about that record however many other records it touched; the record filter of the feed also matches an operation's own root. (3) The entry page lists the two machine columns a sitting changes, and names reference columns and three tables in the diver's language. The triggers are generated from the policy and reinstalled by hash on open, so no rung is needed. Plan 6's held writes already run inside the sitting's scope; only the last task needs its names.

**Tech Stack:** Flutter, drift (SQLite triggers), Riverpod, `flutter gen-l10n`.

**Spec:** `docs/design/specs/2026-11-14-unified-editing-pattern-design.md`, sections "History", "Saving, cancelling, leaving" and "Testing". Plan 5 (`2026-11-15-unified-editing-5-tanks-equipment-weights.md`) and plan 6 (`2026-11-15-unified-editing-6-remaining-cards.md`, on branch `ericgriffin/nifty-tereshkova-be3a99` until it merges) list the held writes this plan logs; read their "For plans ..." and "After the review" sections. The change log itself is issue #3922; read the doc comments of `lib/core/database/change_log/change_log_policy.dart` and `lib/features/change_log/data/services/change_log_settler.dart` before starting.

## What changes, write by write

| Written in a sitting | Logged today | After this plan | Task |
| --- | --- | --- | --- |
| A finding dismissed or restored (`SafetyFindingsRepository.setDismissed`, `dive_safety_findings.dismissed_at`) | Nothing: the table has a delete trigger only | An update of `dismissed_at`, listed in the entry, reverted with it | 1, 5 |
| Readings moved between cylinders (`TankPressureRepository.exchangeTankSources(includePressures: false)`, `tank_pressure_series.tank_id`) | The `dive_tanks` columns only; the series update fires only under remove source, remove duplicate cylinders, update planned dives or the agent | The series update too, its `tank_id` listed, reverted with it | 1, 5 |
| A document filed under the dive (`documents.dive_id`) | An update under the document's own root, so the entry has two roots and is filed as a multi-record entry; a sitting with no dive change is not in the dive's History at all | Same events, the entry stays about the dive: titled by it, found in its History, a child row with per-field Revert | 2, 3, 4 |
| A plan linked or unlinked (`DivePlanRepository.linkPlanToDive`, `unlinkPlan`, `dive_plans.linked_dive_id`) | As above, under the plan | As above | 2, 3, 4 |
| A route linked, unlinked or made primary (`applyDiveRouteLinkDraft`, `NavTrackRepository.setPrimary`, `nav_tracks.dive_id`, `is_primary`) | As above, under the route | As above | 2, 3, 4 |
| An altitude copied to the site, a location added to it (plans 2 and 4), the trip stretched (plan 3) | As above, under the site or trip | As above | 2, 3, 4 |

The tide record and the weather fetch for a new dive run after `DiveEditSaveService.save` returns, so after `ChangeLogScope.run` has closed: they stay out of the entry, as the spec says. Task 6 pins it.

## Eric's choices (2026-11-16)

1. **A sitting that also changes another record is one entry about the dive**: titled with the dive, the other record's changes listed as child rows with old and new values and per-field Revert. It still shows in that record's own History, and in the feed's kind filter it counts as a dive entry.
2. **A dive's History shows sittings on that dive only.** A plan taken from dive B by a link to dive A is not in B's History; a link changed on another page shows under that record only.
3. **Readings moved between cylinders are listed** in the entry, as a "Pressure readings" row showing the cylinder they moved from and to.

## Calls made in this plan, for Eric to check

1. **The label carries the record id**, `record_edit:dives:<diveId>:notes,tags`, rather than a new column on `change_log_operations`: the settler must know in every later pass which operations are pinned, and the label is already the sitting's mark. A label written before this plan (`record_edit:dives:notes,tags`, only on development builds, since sittings are behind `kUnlockEditing`) still reads, unpinned.
2. **A revert of a pinned entry is pinned to the same record**, so reverting a sitting that only filed a document is in the dive's History too.
3. **An operation split off for another diver's record is not pinned** (`_forOwner`, id `<operation>:<owner>`): a sitting that copies an altitude to a site shared by its owner files that part under the owner, who could not open the dive. Withdrawn after the second review: Eric chose to keep such a write in the dive's entry (see "Second review").
4. **Finding updates are logged for `dismissed_at` only, and only inside an opted-in operation** (a sitting, remove source, remove duplicate cylinders, update planned dives, the agent). A review recomputed while a sitting's scope is open rewrites other columns of the same rows, and those must not land in the entry. Dismissals made outside a sitting (today's immediate path with the switch off, `setDismissedForDives` across dives) stay unlogged, as today.
5. **A sitting opts in to every opt-in table**, not only the two the spec names (`dive_profile_series` and `media_enrichment` as well): a sitting's revert must bring back every machine row it changed.
6. **The entry lists only `dive_safety_findings.dismissed_at` and `tank_pressure_series.tank_id`** among machine columns, for any operation. A remove duplicate cylinders entry therefore now also lists the readings it moved; samples, offsets and primary flags stay hidden as today.
7. **A reference column is named as the conflict dialog names it** (`conflictReferenceLabel`) in every History entry: "Dive", "Linked dive", "Tank", "Site", where today an uncatalogued column falls back to "Dive Id", "Site Id".
8. **Three new strings**: `changeLog_table_safetyFinding` "Safety finding", `changeLog_table_pressureSeries` "Pressure readings", `changeLog_table_navTrack` "Underwater track". Without them these child rows read "Dive Safety Findings", "Tank Pressure Series" and "Nav Tracks" in English in every language.
9. **A finding's row is not named by its rule**, as a tank's row is not named by its cylinder today: "Safety finding · Edited", then "Dismissed".
10. **A revert's own entry still records no machine rows.** Reverting the revert of a sitting puts the dive's values back but leaves the dismissal and the readings where the first revert left them, as for remove source today.

## Not in this plan

- The History icon beside the lock on a locked page (the spec's last History bullet): plan 7, with the menus.
- The weather fetch for a new dive: plan 8 keeps it after the write.
- Plan 6's own held writes. They already run inside the sitting's transaction and scope; this plan changes what the log records of them, not how they are written.
- A dive's History showing link changes made elsewhere (Eric's choice 2).

## Global Constraints

- No table, column, schema version bump or migration rung. The triggers are rebuilt from the policy when their hash differs (`_assertChangeLogTriggers`, `lib/core/database/migrations/before_open_change_log.dart`). No stored value is rewritten, so `changeLogRewrittenColumns` is unchanged.
- A trigger must never fail a save: it names only columns the file has (`ChangeLogTableSpec.narrowedTo`) and reads only `change_log_context` and `change_log_operations`.
- `ChangeLogScope.run` stays outside the transaction it covers (`DiveEditSaveService.save` already does this).
- With `kUnlockEditing` false no sitting is made, so pinning never applies. What changes for everyone: reference column names and the three table names in History, and the readings a remove duplicate cylinders entry moved now listed (calls 6 to 8).
- The policy is the only place a table or column joins the log (its library doc says so). Settler and trigger SQL read one shared predicate from it, never a copy.
- `lib/core/database/change_log/change_log_policy.dart` may import `lib/core/services/change_log/record_edit_label.dart` (it has no imports of its own); it must not import `change_log_scope.dart`.
- No file over 800 lines. The settler is at 653 and the repository at 545: check `wc -l` after each task.
- Every new string goes in all 11 ARB files under `lib/l10n/arb/` with a real translation, then `flutter gen-l10n`.
- No em-dash characters anywhere; no emojis; no mention of any AI tool in code, commits or pull requests. Do not join two parts of a label with a spaced hyphen.
- Tests restore global state: `tearDownTestDatabase()`, `SyncClock.instance.reset()`, `SyncCoordinator.reset` through `addTearDown`. Build repositories in `setUp`.
- Before each commit: `dart format .`, `flutter analyze`, the affected test files, plus `flutter test test/core/database/change_log/ test/architecture/`. Never the whole suite. Do not pipe `flutter test` into `grep` or `tail` to judge the result.
- Do not push or open a pull request; that waits for Eric.

## Review Focus

1. **Readings moved onto a cylinder the sitting then removes.** Revert brings back the cylinder and each cylinder's readings where they were before the sitting. Pinned in Task 6.
2. **A sitting whose only change is another record** (a document filed, nothing on the dive). It is in the dive's History, titled with the dive, and so is its revert. Pinned in Tasks 3, 4 and 6.
3. **A safety review recomputed inside a sitting's scope**, rewriting `value`, `severity` or `engine_version` on its findings. Nothing about them is logged; a dismissal in the same sitting still is. Pinned in Task 1.
4. **The finding is gone by the time the entry is reverted** (the review stopped firing it and deleted the row). The revert puts the rest back and reports that item as blocked; nothing throws. Pinned in Task 6.
5. **A reverted dismissal or readings move reaches other devices.** After the revert the finding and the series rows are marked pending. Pinned in Task 6.

## Preparation

- [ ] Work on a branch cut from current `origin/main` (plans 1 to 5 merged). Task 7 waits for plan 6 on `main`.
- [ ] In a fresh worktree: `git submodule update --init --recursive`, `flutter pub get`, then `dart run build_runner build --delete-conflicting-outputs` with no build filter.
- [ ] `flutter analyze` on the whole repository is clean before any change.
- [ ] Take the pull request's "before" pictures now: the History entry of a sitting that changed notes and copied an altitude to the site (today a multi-record "Changes" entry), and a remove duplicate cylinders entry, light and dark, phone and desktop width.

## File Structure

| File | Change | Tasks |
| --- | --- | --- |
| `lib/core/services/change_log/record_edit_label.dart` | Label names its record; public `prefix` | 2 |
| `lib/core/database/change_log/change_log_policy.dart` | Findings join the opt-in tables; `changeLogOptInUpdateColumns`; `changeLogOptsInMachineRows`; `changeLogShownMachineColumns` | 1, 5 |
| `lib/core/database/change_log/change_log_trigger_sql.dart` | Opt-in clause matches a sitting; column-limited opt-in update | 1 |
| `lib/features/change_log/data/services/change_log_settler.dart` | Shared opt-in predicate; pinned roots | 1, 3 |
| `lib/features/change_log/data/repositories/change_log_repository.dart` | Record filter matches the operation's root; shown machine columns | 4, 5 |
| `lib/features/change_log/presentation/change_log_labels.dart` | New label shape; three table names | 2, 5 |
| `lib/features/change_log/presentation/change_log_value_format.dart` | Reference columns named | 5 |
| `lib/features/dive_log/data/services/dive_edit_save_service.dart` | Passes the dive id to the label | 2 |
| `lib/l10n/arb/app_*.arb` | Three strings | 5 |
| `test/features/change_log/data/services/change_log_sitting_machine_rows_test.dart` | New | 1 |
| `test/features/change_log/data/services/change_log_settler_pinned_root_test.dart` | New (the settler test is at 635 lines) | 3 |
| `test/features/dive_log/data/services/dive_edit_save_service_history_test.dart` | New (the save service test is at 725 lines) | 4, 6 |
| `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_sitting_history_test.dart` | New | 7 |

---

### Task 1: A sitting records the machine rows it changes; a finding records its dismissal only

**Files:**
- Modify: `lib/core/database/change_log/change_log_policy.dart` (around `changeLogOptInUpdateTables`, `:529`)
- Modify: `lib/core/database/change_log/change_log_trigger_sql.dart` (`_optInOperation`, `:125`; `_updateTrigger`, `:173`)
- Modify: `lib/features/change_log/data/services/change_log_settler.dart` (`_optedInMachineRows`, `:543`)
- Modify: `lib/core/services/change_log/record_edit_label.dart` (`_prefix` becomes public `prefix`; nothing else here, Task 2 changes the shape)
- Test: `test/core/database/change_log/change_log_trigger_sql_test.dart`, `test/core/database/change_log/change_log_policy_test.dart`, `test/features/change_log/data/services/change_log_sitting_machine_rows_test.dart` (new)

**Interfaces:**
- Produces:

```dart
// record_edit_label.dart
static const prefix = 'record_edit';

// change_log_policy.dart
// changeLogOptInUpdateTables gains 'dive_safety_findings'; its doc says a
// sitting opts in too, and why a finding is here (a dismissal is the
// diver's change, made on a machine row).

/// Opt-in tables whose update records only these columns. A finding is
/// written once by the review, except dismissed_at, which the diver toggles;
/// a review recomputed inside a sitting must not log its other columns.
const Map<String, Set<String>> changeLogOptInUpdateColumns = {
  'dive_safety_findings': {'dismissed_at'},
};

/// Whether an operation with [label] from [source] records updates to the
/// opt-in tables: one of changeLogSeriesUpdateLabels, one of
/// changeLogSeriesUpdateSources, or an editing sitting (a label that starts
/// with '${RecordEditLabel.prefix}:').
bool changeLogOptsInMachineRows({required String? label, required String source});
```

  `_optInOperation()` adds `OR substr(o.label, 1, 12) = 'record_edit:'` (length computed from `RecordEditLabel.prefix`, not typed; `LIKE` would read the underscore as a wildcard). `_updateTrigger` limits `columns` to `changeLogOptInUpdateColumns[spec.table]` when present. `_optedInMachineRows` keeps its table check and calls `changeLogOptsInMachineRows` for the rest.

- [ ] **Step 1: Write the failing tests**

```dart
// change_log_trigger_sql_test.dart
test('a finding gets an opt-in update trigger that compares only dismissed_at', () {
  final update = buildChangeLogTriggers(
    _specFor(db, 'dive_safety_findings'),
    ChangeLogClass.deleteCopyOnly,
    schemaVersion: 1,
  ).singleWhere((s) => s.contains('AFTER UPDATE'));
  expect(update, contains('OLD."dismissed_at" IS NOT NEW."dismissed_at"'));
  expect(update, isNot(contains('"severity"')));
  expect(update, isNot(contains('"value"')));
});
test('the opt-in clause matches a sitting by its label prefix', () {
  final update = buildChangeLogTriggers(
    _specFor(db, 'dive_profile_series'),
    ChangeLogClass.deleteCopyOnly,
    schemaVersion: 1,
  ).singleWhere((s) => s.contains('AFTER UPDATE'));
  expect(update, contains("substr(o.label, 1, 12) = 'record_edit:'"));
});

// change_log_policy_test.dart
test('every opt-in column exists on its table and the table is opt-in', ...);
test('a sitting opts in; a free manual label does not', () {
  expect(changeLogOptsInMachineRows(label: 'record_edit:dives:d:tanks', source: 'manual'), isTrue);
  expect(changeLogOptsInMachineRows(label: 'record_editor', source: 'manual'), isFalse);
  expect(changeLogOptsInMachineRows(label: null, source: 'manual'), isFalse);
  expect(changeLogOptsInMachineRows(label: 'x', source: 'agent'), isTrue);
});

// change_log_sitting_machine_rows_test.dart: a diver, a dive, two tanks,
// one series on tank A, one finding; setUp clears the log as
// change_log_series_update_test.dart does. Each test runs its writes in
// ChangeLogScope.run(source: manual, label: 'record_edit:dives:dive:tanks').
test('a series moved in a sitting records tank_id old and new', ...);
test('a finding dismissed in a sitting records dismissed_at only', ...);
test('a finding dismissed outside any operation records nothing', ...);
test('a review rewriting a finding\'s value and severity in a sitting records nothing', ...);
test('both survive settling while the dive lives', ...);   // action U kept
test('reverting the sitting puts the series and the dismissal back', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/core/database/change_log/change_log_trigger_sql_test.dart test/core/database/change_log/change_log_policy_test.dart test/features/change_log/data/services/change_log_sitting_machine_rows_test.dart`
Expected: FAIL (no update trigger on `dive_safety_findings`, no `changeLogOptsInMachineRows`).

- [ ] **Step 3: Implement** the policy entries, the trigger clause and column limit, and the settler predicate as above.

- [ ] **Step 4: Run and confirm they pass**

Run: the Step 2 files, then `flutter test test/core/database/change_log/ test/features/change_log/data/services/change_log_series_update_test.dart test/features/change_log/data/services/change_log_settler_test.dart`
Expected: PASS. `change_log_series_update_test.dart`'s "the opt-in labels" and "the opt-in sources" tests stay as they are.

- [ ] **Step 5: Commit**

```bash
git add lib/core test
git commit -m "feat(change-log): a sitting records the machine rows it changes, and a finding its dismissal"
```

---

### Task 2: A sitting's label names its record

**Files:**
- Modify: `lib/core/services/change_log/record_edit_label.dart`
- Modify: `lib/features/dive_log/data/services/dive_edit_save_service.dart` (`:67`)
- Modify: `lib/features/change_log/presentation/change_log_labels.dart` (`_recordEditLabel`, `:78`, if the new record shape needs it)
- Test: `test/core/services/change_log/record_edit_label_test.dart`, `test/features/dive_log/data/services/dive_edit_save_service_test.dart` ("one sitting is one operation, labelled with its cards", `:156`), `test/features/change_log/presentation/change_log_labels_test.dart`

**Interfaces:**
- Produces:

```dart
/// `record_edit:dives:<id>:notes,tags`. Throws ArgumentError for an empty
/// [id] or one containing ':'.
static String encode({required String table, required String id, required Iterable<String> cardIds});

/// Also reads the earlier `record_edit:<table>:<cards>`, with a null id.
static ({String table, String? id, List<String> cardIds})? decode(String label);
```

  `DiveEditSaveService.save` passes `id: diveId`.

- [ ] **Step 1: Write the failing tests**

```dart
test('encode names the table, the record and the cards, sorted', () {
  expect(RecordEditLabel.encode(table: 'dives', id: 'd1', cardIds: ['tags', 'notes']),
      'record_edit:dives:d1:notes,tags');
});
test('decode reverses encode, id included', ...);
test('decode reads a label written before the id, with a null id', () {
  final decoded = RecordEditLabel.decode('record_edit:dives:notes,tags')!;
  expect(decoded.id, isNull);
  expect(decoded.cardIds, ['notes', 'tags']);
});
test('decode returns null for an empty id or empty cards', () {
  expect(RecordEditLabel.decode('record_edit:dives::notes'), isNull);
  expect(RecordEditLabel.decode('record_edit:dives:d1:'), isNull);
});
test('encode refuses an id with a colon', ...);
// dive_edit_save_service_test.dart: the existing label test expects
// RecordEditLabel.encode(table: 'dives', id: 'dive', cardIds: [...]).
// change_log_labels_test.dart: the subtitle names the cards for both shapes.
```

- [ ] **Step 2: Run and confirm they fail**

Run: the three test files.
Expected: FAIL (no `id` parameter).

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the three test files, then `flutter test test/features/change_log/presentation/ test/features/change_log/data/services/change_log_sitting_machine_rows_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(change-log): a sitting's label names the record it was opened on"
```

---

### Task 3: The settler keeps a sitting's entry about its record

**Files:**
- Modify: `lib/features/change_log/data/services/change_log_settler.dart` (`_Operation`, `:72`; `_note`, `:221`; `_forgetRootIfEmpty`, `:250`; `_loadOperation`, `:321`)
- Test: `test/features/change_log/data/services/change_log_settler_pinned_root_test.dart` (new)

**Interfaces:**
- Consumes: `RecordEditLabel.decode` (Task 2).
- Produces (private to the settler; the observable result is the operation row's `root_table`, `root_id`, `root_label`, `root_ordinal` and `diver_id`):

```dart
// _Operation gains
final String? revertOfId;     // read from the row
final ChangeLogRoot? pinned;  // resolved by _loadOperation

/// The record an operation is about whatever else it touches: the label's
/// record for a sitting; for a revert, the pinned root of the operation it
/// reverts, followed up the revert_of_id chain. Null for an owner split
/// (an id containing ':'), a manual operation the settler created, and
/// any other operation.
Future<ChangeLogRoot?> _pinnedRootOf(Map<String, Object?> row);
```

  In `_note`, a pinned operation keeps `pinned` as its root on every event. On its first event it takes the label and ordinal from `_labelOf(pinned)` and its owner from `_ownerOf(pinned)`, falling back to the event's owner. `_forgetRootIfEmpty` leaves a pinned root in place. Nothing else in the settler changes: grouping, folding and machine-row settling read the event's own root as before.

- [ ] **Step 1: Write the failing tests**

```dart
// A diver, a dive (number 12 at site "Reef"), a document, a plan, a site.
// A sitting is ChangeLogScope.run(source: manual,
//   label: RecordEditLabel.encode(table: 'dives', id: 'dive', cardIds: [...])).
test('a sitting that changes the dive and the site is about the dive', () {
  // operation root_table 'dives', root_id 'dive', root_label 'Reef',
  // root_ordinal 12; its events keep their own roots ('dives', 'dive_sites').
});
test('a sitting that only files a document is about the dive', ...);
test('it stays about the dive across settle passes', ...);  // settle, write more under the same scope id, settle again
test('a sitting whose dive change cancelled out keeps the dive as root', ...);
test('a revert of a pinned sitting is about the same dive', ...);   // ChangeLogRevertService().execute(planOperation(id))
test('a revert of that revert is about the dive too', ...);
test('a sitting labelled the earlier way is filed as before', ...);  // two roots: root null
test('a part split off for another diver is not pinned', ...);      // a shared site owned by 'other': the 'id:other' operation keeps the site as root
test('an unscoped save is untouched', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/change_log/data/services/change_log_settler_pinned_root_test.dart`
Expected: FAIL (two-root sittings settle with a null root).

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the Step 2 file, then `flutter test test/features/change_log/ test/core/database/change_log/`
Expected: PASS. `wc -l` on the settler: at most 760; if over, move `_pinnedRootOf` and its walk into `change_log_settler_pinning.dart` as an extension on `_SettlePass` in a part file.

- [ ] **Step 5: Commit**

```bash
git add lib/features/change_log test/features/change_log
git commit -m "feat(change-log): a sitting's entry stays about its record whatever else it wrote"
```

---

### Task 4: The dive's History finds every sitting on it

**Files:**
- Modify: `lib/features/change_log/data/repositories/change_log_repository.dart` (`getFeed`, the `filter.isRecord` branch, `:97`)
- Test: `test/features/change_log/data/repositories/change_log_repository_test.dart` (add cases), `test/features/dive_log/data/services/dive_edit_save_service_history_test.dart` (new)

**Interfaces:**
- Produces: a record filter matches an operation when one of its events has that root, as today, **or** the operation's own `root_table` and `root_id` are that record.

- [ ] **Step 1: Write the failing tests**

```dart
// change_log_repository_test.dart
test('the record filter finds an operation pinned to the record with no event of its own', ...);
test('the record filter still finds the document under the document', ...);

// dive_edit_save_service_history_test.dart: setUp as in
// dive_edit_save_service_test.dart (a diver, a dive, a site, a tank), plus
// a Personal document, a plan and an unlinked route by raw SQL as the
// migration tests do. A helper reads
// ChangeLogRepository().getFeed(diverId: 'me',
//   filter: ChangeLogFilter(rootTable: 'dives', rootId: 'dive')).
test('a sitting that also copies an altitude to the site is one entry about the dive', () {
  // feed has one operation; rootTable 'dives', rootId 'dive', isBulk false
});
test('a sitting that only files a document is in the dive\'s History', ...);
  // alsoWrite: UPDATE documents SET dive_id = 'dive'; alsoWriteIsAChange: true
test('a sitting that only links a plan is in the dive\'s History', ...);
  // alsoWrite: DivePlanRepository().linkPlanToDive('plan', 'dive')
test('a sitting that only links a route is in the dive\'s History', ...);
  // alsoWrite: NavTrackRepository().link('route', 'dive', linkMode: NavTrackLinkMode.manual)
test('the document\'s own History lists the same entry', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: the two test files.
Expected: FAIL (the document-only sitting is not in the dive's feed).

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the two test files, then `flutter test test/features/change_log/ test/features/dive_log/data/services/dive_edit_save_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/change_log test/features
git commit -m "feat(change-log): a dive's History finds a sitting that changed only another record"
```

---

### Task 5: The entry lists a dismissal and moved readings, in the diver's words

**Files:**
- Modify: `lib/core/database/change_log/change_log_policy.dart`
- Modify: `lib/features/change_log/data/repositories/change_log_repository.dart` (`getEvents`, `:192`; `countEvents`, `:174`; `_fieldsByEvent`, `:232`; `_machineTables`, `:226`)
- Modify: `lib/features/change_log/presentation/change_log_labels.dart` (`changeLogTableLabel`, `:98`)
- Modify: `lib/features/change_log/presentation/change_log_value_format.dart` (`label`, `:36`)
- Modify: the 11 `lib/l10n/arb/app_*.arb` files, then `flutter gen-l10n`
- Test: `test/features/change_log/data/repositories/change_log_repository_test.dart`, `test/features/change_log/presentation/change_log_value_format_test.dart`, `test/features/change_log/presentation/change_log_labels_test.dart`, `test/features/change_log/presentation/change_log_entry_page_test.dart`

**Interfaces:**
- Produces:

```dart
// change_log_policy.dart
/// Machine columns an entry lists, for any operation: what a diver changes
/// on a machine row. Every other machine row and column stays out of the
/// entry and is kept only for a revert or a restore.
const Map<String, Set<String>> changeLogShownMachineColumns = {
  'dive_safety_findings': {'dismissed_at'},
  'tank_pressure_series': {'tank_id'},
};
```

  The repository lists a machine-table event (without `includeMachineRows`) only when it is an update that changed a column in `changeLogShownMachineColumns`, and lists only those columns of it. `countEvents` counts the same events. `getPreviewFields` reads through `getEvents` and so previews them. `includeMachineRows: true` is unchanged.

  `ChangeLogValueFormatter.label(table, column)`: a column with no catalogue entry (`conflictFieldOverrides['$entity.$key']`, `conflictFieldCatalogue[key]`) and a reference target (`ConflictReferenceResolver.targetTypeFor(entity, key)`) is named by `conflictReferenceLabel(l10n, ConflictReference(field: key, targetType: target, recordId: ''))`.

  `changeLogTableLabel`: `'dive_safety_findings' => l.changeLog_table_safetyFinding`, `'tank_pressure_series' => l.changeLog_table_pressureSeries`, `'nav_tracks' => l.changeLog_table_navTrack`. English: "Safety finding", "Pressure readings", "Underwater track".

- [ ] **Step 1: Write the failing tests**

```dart
// change_log_repository_test.dart
test('an entry lists a dismissed finding with its dismissed_at only', ...);
test('an entry lists moved readings with tank_id only', ...);
test('a series update that changed only its samples stays hidden', ...);  // remove_source scope
test('countEvents counts what getEvents lists', ...);

// change_log_value_format_test.dart
test('a reference column is named as the conflict dialog names it', () {
  expect(formatter().label('tank_pressure_series', 'tank_id'), 'Tank');
  expect(formatter().label('dive_plans', 'linked_dive_id'), 'Linked dive');
  expect(formatter().label('documents', 'dive_id'), 'Dive');
  expect(formatter().label('dives', 'max_depth'), 'Max Depth');  // catalogued: unchanged
});
test('a dismissal reads as the moment it was made', () {
  expect(formatter().value('dive_safety_findings', 'dismissed_at', ms),
      units.formatDateTime(DateTime.fromMillisecondsSinceEpoch(ms), l10n: l10n));
});

// change_log_labels_test.dart
test('the three new tables have names of their own', ...);

// change_log_entry_page_test.dart
testWidgets('a sitting entry shows the dive, a site child row and a dismissal row, each with Revert', ...);
```

  The `max_depth` expectation is the one `change_log_value_format_test.dart:42` already pins.

- [ ] **Step 2: Run and confirm they fail**

Run: the four test files.
Expected: FAIL.

- [ ] **Step 3: Implement**, adding the three strings to every ARB file with a translation, then `flutter gen-l10n`.

- [ ] **Step 4: Run and confirm they pass**

Run: the four test files, then `flutter test test/features/change_log/ test/l10n/ test/features/settings/presentation/widgets/conflict_reference_labels_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(change-log): an entry lists a dismissed finding and moved readings, with references named"
```

---

### Task 6: One sitting, every kind of change, one entry that reverts it all

**Files:**
- Test: `test/features/dive_log/data/services/dive_edit_save_service_history_test.dart` (the file from Task 4)

**Interfaces:**
- Consumes: `DiveEditSaveService.save(writeFirst:, alsoWrite:, alsoWriteIsAChange:)`, `TankPressureRepository.exchangeTankSources(includePressures: false)`, `SafetyFindingsRepository.setDismissed`, `DivePlanRepository.linkPlanToDive`, `NavTrackRepository.link` and `setPrimary`, `ChangeLogRevertService.planOperation` and `execute`, `SyncRepository` pending records.

This task adds tests only. A failure is a defect in Tasks 1 to 5: fix it there, with its own test, before going on.

- [ ] **Step 1: Write the tests**

```dart
// One sitting: notes changed; writeFirst exchanges tanks A and B; alsoWrite
// dismisses the finding, files the document, links the plan, links the
// route and makes it primary.
test('it is one operation, about the dive, in the dive\'s History', ...);
test('the entry lists the notes, the readings, the dismissal, the document, the plan and the route', ...);
test('reverting it restores every value, the readings on their own cylinders', ...);
test('readings moved onto a cylinder the sitting removes come back with it on revert', ...);
test('a finding deleted before the revert is reported blocked; the rest goes back', ...);
test('after the revert the finding and the series rows are pending for sync', ...);
test('a write made after save returns is not in the entry', ...);  // a notes update through DiveRepository after save: a separate operation
```

- [ ] **Step 2: Run them**

Run: `flutter test test/features/dive_log/data/services/dive_edit_save_service_history_test.dart`
Expected: PASS. Break each of Tasks 1, 3 and 4 in turn (remove the opt-in clause, the pin, the root filter), see a test here fail, and restore.

- [ ] **Step 3: Commit**

```bash
git add test/features/dive_log/data/services
git commit -m "test(dive-log): a sitting's every change is in its one History entry and reverts with it"
```

---

### Task 7 (after plan 6 merges): Through the sitting's own held changes

Plan 6 creates the names this task uses. Before starting, read plan 6's "After the review" section and use the names as built.

**Files:**
- Test: `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_sitting_history_test.dart` (new)

**Interfaces:**
- Consumes, from plan 6: `setFindingDismissed(EditSession<Dive>, SafetyFinding, {required bool dismissed})` (`dive_safety_sitting.dart`), `attachDocument(EditSession<Dive>, String)` (`dive_document_links_sitting.dart`), `loadDivePlanLink` and `setPlanLink` (`dive_plan_link_sitting.dart`), `loadDiveRouteLinks`, `sittingRouteDraft` and `setRouteDraft` with `DiveRouteLinkDraft.withPrimary` (`dive_route_links_sitting.dart`). From plan 5: `exchangeTankSeries(session, a, b, exchange:)` (`dive_tank_series_exchange.dart`), `diveSittingApply` (`dive_tanks_fields.dart`), `startDiveSitting` (`dive_edit_cards.dart`).
- The save is called as `_saveSitting` calls it (`dive_detail_page_editing.dart:106`): `writeFirst` when `session.hasHeldWritesBeforeRecord`, `alsoWrite: session.runHeldWrites` when `session.hasHeldWrites`, `alsoWriteIsAChange: session.hasHeldChanges`.

- [ ] **Step 1: Write the tests**

```dart
// An EditSession<Dive> over the stored dive, loaded through a
// ProviderContainer's read; the held changes made with plan 5's and
// plan 6's functions; saved through DiveEditSaveService.
test('a dismissal, an exchange, a document, a plan link and a route link: one entry about the dive', ...);
test('reverting it puts every one back', ...);
test('Cancel (dispose without save) writes nothing and logs nothing', ...);
test('the entry\'s label names every card that changed', ...);
  // RecordEditLabel.decode(label).cardIds == ['diveLab', 'documents', 'navTrack', 'notes', 'safetyReview', 'tanks']
```

- [ ] **Step 2: Run them**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/editing/dive_sitting_history_test.dart`
Expected: PASS.

- [ ] **Step 3: Format, analyse, run the guards and the affected tests**

Run: `dart format .`
Run: `flutter analyze`
Expected: no issues.
Run: `flutter test test/architecture/ test/core/database/ test/core/services/change_log/ test/features/change_log/ test/features/dive_log/data/ test/l10n/`
Run: plan 6's page test (`dive_detail_page_unlock_remaining_test.dart`): its "a change on every card: Save is one History entry naming them all" now also holds with this plan's pinning.
Expected: PASS.
Run: `wc -l` on every file this plan changed.
Expected: none over 800.

- [ ] **Step 4: Look at it**

Render the History entry of the Task 6 sitting in a throwaway widget test (real fonts from the SDK's `material_fonts` folder, deleted afterwards): the feed row and the entry page, light and dark, phone and desktop width, with English and one other language. Check by eye that the dive is the title, each other record has its child row in the diver's language, and every field has its Revert. Keep the pictures, with the "before" ones from Preparation, for the pull request.

- [ ] **Step 5: Commit**

```bash
git add test/features/dive_log
git commit -m "test(dive-log): the sitting's held changes on every card land in one History entry"
```

---

## Pull request

One, `Refs #4527`. It touches `lib/features/change_log/presentation/`, and History entries read differently with the switch off too (calls 6 to 8), so it carries the before pictures from Preparation and the after pictures from Task 7 Step 4. Pushing and opening it waits for Eric. If plan 6 has not merged when Tasks 1 to 6 are done, they can go up as their own pull request (take its after pictures then) and Task 7 follows plan 6.

## For plans 10 and 11

- **Plan 10 (photo viewer).** A sitting on a media record labels itself `RecordEditLabel.encode(table: 'media', id: mediaId, cardIds: ...)` and is then pinned to that photo by Task 3, with no change to the log. A photo's History filter is `ChangeLogFilter(rootTable: 'media', rootId: id)`.
- **Plan 11 (switch-over).** Nothing further: once the old form is gone every single-dive edit is a sitting, and so is logged as above. Today's immediate dismiss path goes with the form.
- **Any later plan that writes another record in a sitting** needs nothing here: it is inside the scope, filed under its own root, and listed in the dive's entry. A machine row a diver changes needs its column in `changeLogOptInUpdateColumns` or a tracked table, and in `changeLogShownMachineColumns`.

---

## After the review

Tasks 1 to 6 were built as written in one session (Eric chose "Native"), then reviewed as a whole branch by a fresh reviewer. Task 7 waits for plan 6. This is what differs from the task text above, for whoever builds Task 7 and writes plan 10.

### Changed from the calls above

- **Call 10 is reversed (Eric, 2026-11-16): a revert records the machine rows it puts back.** `changeLogSeriesUpdateSources` is `{'agent', 'revert'}`. A revert writes back only what was logged, so what it records is exactly the machine rows the reverted entry recorded. Without it, reverting a sitting that only dismissed a finding left a revert with no events, which the settler deletes, and the sitting read "Reverted" pointing at nothing. Reverting that revert now dismisses the finding again.
- **`RecordEditLabel.encode` never throws.** An empty id, or one holding `:`, writes the earlier unpinned label (`record_edit:dives:<cards>`), since logging must never stop a save.

### Fixed from the review

- **Superseded by the second review below: a sitting's write to another diver's shared site now stays in the dive's entry.** This first fix made a sitting whose only write was to another diver's shared site file it under that diver: `_forOwner` took a pinned scope's owner from its record before its first event, where it had compared against a null owner and kept the write.
- **A finding deleted by a review inside a sitting is not kept.** A table in `changeLogOptInUpdateColumns` opts in its updates only; its deletes follow the ordinary machine-row rule.

### Tests the plan listed that were written differently

- Task 4's route test first failed on its fixture (`source` must be a wire value, `suunto_route`), not on the feature. The document and plan tests share the path and were red for the feature.
- Task 6's mutation check: dropping the sitting's opt-in clause failed 5 tests, removing the pin 6, removing the root filter all 12.

### Left open

- `encode` accepts an empty card list, which `decode` rejects, so such a label is unpinned and shown raw. The save service never passes one: a sitting is dirty only through a pending value or a held change, and each names its card.

### Second review (2026-11-16)

A second whole-branch review found these; each fix has a test that failed first.

- **Moved readings have no per-field Revert.** Readings move between cylinders in pairs, so reverting one series alone left both on one cylinder. `changeLogRevertsWithEntryOnly` (`tank_pressure_series`) in the policy; the entry page offers no Revert on such a row, and the whole entry still reverts it. A dismissal keeps its own Revert.
- **A feed row previews only its own record's fields.** `getPreviewFields` drops fields whose event's root is not the entry's, so a site's altitude no longer reads as the dive's under its title, and a sitting that only filed a document previews nothing. The entry page lists them all.
- **Only a manual operation is pinned by its label.** An agent labels its change set with free text, which could read like a sitting's label and pin it to any record.
- **A revert's ancestors are read for their pin, not loaded.** `_pinOf` keeps them out of `_operations`, which `_writeOperations` rewrote on every pass.
- **Guards and cleanups:** a policy test pins `changeLogShownMachineColumns` to recordable columns of opt-in machine tables; `changeLogOptInKeepsDeletes` names the rule the settler had read off `changeLogOptInUpdateColumns`; `_listedEvent` no longer repeats an always-false branch; `conflictFieldNamed` is the catalogue's lookup, shared by `conflictFieldFor`, `isConflictFieldCovered` and the value formatter; one `_scopeOwnerOf` replaces two copies of the pinned owner rule.

Two findings were choices about who sees or reverts another diver's record. Eric's choices (2026-11-16), both built:

- **A sitting's write to another diver's shared site is listed in the dive's entry and reverted with it.** `_forOwner` no longer splits a pinned scope by owner, so call 3 is withdrawn: the sitting stays one operation, owned by the dive's diver, and a whole revert puts the site back and marks the entry reverted.
- **Another diver sees the rows about records they own or share, titled with one of them.** `ChangeLogSharedView` (in `data/repositories/`) restricts an entry another diver owns to the records the viewer may see (by the third review, the rules of `VisibilityFilter`): `getFeed` and `getVisibleOperation` show it to them (the site's owner, or a diver the site is shared with), titled with that record, with `ChangeLogOperation.shownRoots` set. The entry page lists, counts and reverts only those rows (`onlyRoots` on `getEvents`, `countEvents` and `planOperation`), so the dive's name and fields stay hidden; a revert of only those rows does not mark the entry reverted. `getPreviewFields` now takes the operations, so a restricted row previews the record it is titled with. The same rule now covers any entry another diver owns, so an entry about a shared site that also touched the owner's private dives shows the viewer only the site's rows, where before it showed them all.

### Third review (2026-11-16)

A third whole-branch review and the PR's first automated review found these; each fix has a test that failed first, or a coverage test checked by breaking the code it covers.

- **The shared view follows the app's visibility rules.** `ChangeLogSharedView` builds one predicate from `VisibilityFilter` for both an entry's own record and the records its rows changed, so a site or trip shared with everyone, or a site in a library the diver belongs to, counts, and one they hid does not. Trips and gear are covered as well as sites.
- **A diver who sees only part of a sitting is not told which cards of the dive it changed.** `changeLogSubtitle` leaves the label out when `shownRoots` is set.
- **The kind filter goes by the record a restricted entry is shown under.** `ChangeLogSharedView.shownTable` is the SQL of the title `asSeenBy` picks, so a sitting a partner sees titled with a shared site is found under Sites, not Dives. This closes the second review's one open item.
- **`planField` refuses a row of `changeLogRevertsWithEntryOnly`**, so the readings rule holds for any caller, not only the entry page.
- **A sitting label that names no card still decodes** and pins the entry to its dive; it reads as "Edited".
- **Cleanups:** `asSeenBy` reads a page's restricted entries in one grouped query and their names one query per table; the visibility subquery looks only at other divers' entries; `ChangeLogSql` and `changeLogMarks` live in `change_log_sql.dart`.

### Task 7 (2026-11-17)

Built after plan 6 merged, on a branch of its own. Plan 6 has no "After the review" section, so the names were checked against the code: they are as Task 7 lists them, except that `attachDocument` takes the `Document`, not its id. The test starts the sitting with `startDiveSitting` over a `ProviderContainer` on the test database, so every held change goes through its card's own function. The four tests passed as written; removing the pin failed the first, and removing the sitting's opt-in failed the first two.

Step 4's pictures came from a headless golden, deleted afterwards. A fixture cylinder needs an explicit `source_tank_index`: without one, an exchange resolves it first (0 for the one with readings, -1 for the other) and the entry reads "Not set" to -1 and 0. Two wording gaps showed, both from before this plan and left for their own change: a route link's `link_mode` reads as the raw word "manual" in every language, and a dive that gains its first dive type lists an unnamed "Dive Dive Types" row.
