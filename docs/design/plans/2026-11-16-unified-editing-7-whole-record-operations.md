# Unified Editing, Plan 7: Whole-Record Operations, the Menus, the List Pane and Shortcuts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every control on the dive page that acts on the dive as a whole (delete, re-parse, resync, the data source operations, set primary source, mark logged, mark complete, surfaced, add heart rate, the pre-dive checklist link, Edit profile, assign transmitter, the gear link and the check-in chip) needs the page unlocked with no unsaved changes. Each acts at once and is its own History entry, and afterwards the sitting starts again from the stored dive. The locked bar gains History beside the lock. The dive list's pane gets the same lock, and leaving a sitting by any route (another row, another tab, quitting) asks first. Unlock, Save and Cancel get keys (issue #4527).

**Architecture:** One shared idea, the *operation gate*, says whether a whole-record operation may run now: not offered, locked, unsaved changes, or free. Menus list a blocked operation disabled under one caption line. Buttons are drawn disabled with the reason as their tooltip, so nothing moves when the page unlocks. `RecordEditController.runOperation` runs an operation: it freezes the clean sitting, awaits the operation, reads the stored record again and starts a fresh sitting on it (`retake`). The list pane builds the same scope, leave guard, strip and bar as the full page, inside its own header. Leaving is checked through the existing `AppExitGuard`: the open sitting holds an `AppExitBlocker`, the dive routes ask it in `GoRoute.onExit`, and `MasterDetailScaffold` asks it before it changes selection. Shortcuts are `Intent`s handled at the shell, for the record page that registered last and is current. Still behind `kUnlockEditing`.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), go_router 17 (`GoRoute.onExit`), drift (SQLite), `flutter gen-l10n`.

**Spec:** `docs/design/specs/2026-11-14-unified-editing-pattern-design.md`. Read "States and the top bar", "Saving, cancelling, leaving", "Whole-record operations", "History" (its last bullet), "Wide screens and keyboard", and "What a locked dive page no longer shows". The names used here are the ones the earlier plans built: read "For plans ..." and "After the review" in plans 1 to 6, 9 and 10 (`docs/design/plans/2026-11-14-unified-editing-1-skeleton.md` to `2026-11-16-unified-editing-10-photo-viewer.md`). Plan 6's execution notes (session notes file `plan-6-execution-handover.md`) list where plan 6's built code differs from its text.

## The operations, and where each lives

"Op" means a whole-record operation: needs the unlock, needs no unsaved changes, acts at once, keeps its own confirmation, is its own History entry, and leaves the page unlocked and clean.

| Operation | Control today | Write | Confirmation today | With the switch on |
| --- | --- | --- | --- | --- |
| Delete | menu `delete` | `paginatedDiveListProvider.notifier.deleteDive` | yes | Op, menu. Locks before the page leaves |
| Re-parse raw data | menu `reparse` | `reparseServiceProvider.reparseDive` | no | Op, menu |
| Resync from original file | menu `resync` | `diveResyncOrchestratorProvider.resync` | no | Op, menu |
| Mark as logged | menu `markLogged`, planned banner | `convertPlanToActualDive` | no | Op, menu and banner |
| Mark as complete | menu `markComplete`, draft banner | `markDraftComplete` | no | Op, menu and banner |
| Surfaced | draft banner | `diveDraftRepositoryProvider.closeDraft` | no | Op, banner |
| Add heart rate | menu `addHeartRate` | `diveHealthMetricsServiceProvider.refresh` | no | Op, menu |
| Link, unlink pre-dive checklist | menu `linkPreDive` / `unlinkPreDive` | `preDiveSessionRepositoryProvider.linkToDive` / `unlinkFromDive` | picker / no | Op, menu |
| Draw a profile (no profile yet) | the form's profile row | route `editProfile`, `mode: draw` | own page | Op, menu (new item, call 6) |
| Edit profile | the form's profile row only | route `editProfile` | own page | Op, a button on the Profile card (new) |
| Set primary source | Data sources card menu; profile source bar chips (card, pinned copy, open Profile editor) | `diveRepositoryProvider.setPrimaryDataSource` | no | Op, each place |
| Split into separate dive | Data sources card menu | `diveSplitServiceProvider.split` | yes | Op |
| Remove source | Data sources card menu | `removeSourceWithUndo` | yes | Op, no Undo (call 4) |
| Separate combined dives | Data sources section menu | `diveUncombineServiceProvider.separate` | yes | Op |
| Assign transmitter | Cylinders read card | `registerTransmittersForDives` (through `/transmitters/new`) | no | Op, shown disabled while blocked (call 3) |
| Tank gear menu (add to my gear, link, unlink cylinder) | Cylinders read card | `cylinderFromTankServiceProvider.linkTank` / `unlinkTank` | no | Op, shown disabled while blocked (call 3) |
| Gear check-in chip | Cylinders and Equipment rows | the check-in sheet | sheet | Op (call 2) |

Not ops, and usable while locked and during a sitting, as the spec lists them: History, Open full page (pane), Display options, Export, Log near-miss, Log for a buddy's profile, Compare (what-if), View in planner, Plan repetitive dive, the banners' Download now and Open in planner, Compare in 3D on the Data sources card, the 3D and fullscreen buttons on the Profile card.

## Leaving a sitting

| Way out | Today | With this plan |
| --- | --- | --- |
| Back, the close of a pushed page | `RecordEditLeaveGuard` (PopScope) | Unchanged |
| Sidebar, bottom bar, Cmd/Ctrl+1 to 5, Cmd/Ctrl+, and every other `go` out of the dive routes | Nothing asks; the sitting is dropped | `GoRoute.onExit` on `dives` and `diveDetail` asks `appExitGuard.mayLeave()` |
| Quitting the app, closing its window | Nothing asks | The open sitting is an `AppExitBlocker`: asked as the table editor is |
| Another row in the list pane, by tap or arrow key | Nothing asks | `MasterDetailScaffold` asks before it changes selection; the dive list asks before it moves its highlight |
| The pane's other in-place moves (map toggle, new dive, the map's details tap, the hero's site link) | Nothing asks | `goInPlaceGuarded` |
| Previous, next | Off during a sitting (plan 1) | Unchanged |

With no unsaved changes each way out locks and goes without asking, as the spec says.

## Calls made in this plan, for Eric to check

Eric's standing choices apply: a locked record allows no change at all; one Save per unlock; day-to-day logging needs the unlock; nothing moves when the page unlocks. Made in writing this plan, not confirmed:

1. **Blocked operations are listed, not hidden, everywhere.** In a menu they are disabled under one caption line ("Unlock to use these", or "Save or cancel your changes first"). A button (a banner's, the Profile card's Edit profile, Assign transmitter) is drawn disabled with the reason as its tooltip and no caption, so the page does not grow or shrink when it unlocks.
2. **The gear check-in chip becomes an operation**: it needs the unlock and no unsaved changes, then opens the check-in sheet, which writes at once as today. This is stricter than plan 5's call 3 (writes at once in any sitting) and much cheaper than holding check-ins until Save (a 621-line sheet), and Cancel still means nothing in the sitting happened. Holding them is still possible later.
3. **Assign transmitter and the tank gear menu are shown disabled while locked** (plan 5 hid them while locked, keeping their room). Same rule as call 1.
4. **Remove source offers no Undo on a page that offers editing.** The Undo snackbar would write at once at any moment, locked or mid-sitting. The removal is its own History entry and reverts from there. With the switch off the Undo stays.
5. **Unlink pre-dive checklist gets no confirmation**, as today: an operation keeps the confirmation it has and gains none.
6. **"Draw a profile" joins the page menu** as an operation, for a dive with no profile. Today it is reachable only from the old form, which plan 11 deletes, and a dive with no profile has no Profile card to carry it.
7. **Edit profile is a button on the Profile card's toolbar**, beside fullscreen, not on the pinned copy (which has no room).
8. **After an operation the sitting starts again from the stored dive** (`retake`): open editors close, the strip is offered afresh, the page keeps its scroll. The spec says "the working copy is taken again"; a fresh sitting is how every held collection (buddies, media, annotations) reads the rows the operation changed.
9. **An operation that leaves no dive behind locks the page** (delete; a separate or a split that removed this dive), then the page goes or shows "not found" as today.
10. **Display options stay usable during a sitting.** They are display settings; a diver who reorders sections mid-sitting moves the page themself.
11. **History sits beside the lock where the window is 600 px or wider** (`_kCompactAppBarWidth`, the width at which the bar had a favourite toggle before plan 4) and in the pane's header always (the pane only exists at 1100 px and wider). Below 600 it stays the menu's first item. During a sitting it is the menu's first item.
12. **The unlocked pane header keeps the locked header's height**: the locked row stays laid out, invisible, under the editing row. The pane's banners and site suggestion stay in its header, inside the scope.
13. **A pane showing a site (`site=`) ends the dive's sitting**: the hero's site link asks first; a clean sitting locks.
14. **Leaving is asked through `AppExitGuard`**, so quitting with unsaved changes asks too (the spec's "killed" case is unchanged). Every page holding a blocker is asked, the table editor included.
15. **Keys:** Unlock is Cmd/Ctrl+L, not while typing. Cmd+E would be the obvious choice, but the macOS menu's "Use Selection for Find" (`MainMenu.xib:149`) takes it before Flutter sees it. Save is Cmd/Ctrl+S. Escape is Cancel, also while typing. All three act only for the record page that registered last and is the current route, and a key with nothing to do passes on (an open dialog still closes on Escape). Unlock and Save are listed in the shortcuts help under Editing, with the switch on.
16. **Download now (draft banner) stays usable while locked**: downloading is one of the spec's deliberate modes.
17. **New strings** (Tasks 2, 7 and 11): `recordEdit_unlockToUseThese` "Unlock to use these", `diveLog_profile_editProfile` "Edit profile", `accessibility_shortcut_unlockRecord` "Unlock to edit", `accessibility_shortcut_saveChanges` "Save changes". Changed: `diveLog_media_dropUnlockHint` goes back to "Unlock this dive to add photos." in all locales, now that the pane can unlock. Reused: `recordEdit_unlockToUseThis` (a button's tooltip), `recordEdit_saveOrCancelFirst`, `changeLog_history`, `diveLog_edit_profile_draw`.

## Not in this plan

- A new dive (plan 8). `?mode=new` in the pane, and `/dives/new`, still open the old form.
- The switch-over (plan 11): the Edit buttons in both bars, `&mode=edit` and the old form stay as they are until then.
- Plan 9's Task 7 and plan 10's Task 13 (their own sessions).
- Rental gear notes on the "Last time at" card (plan 5 call 4): they show only in an open Details editor and keep writing at once.
- Switching diver during a sitting (issue #2564).
- The profile editor's outlier entry (`initialMode: 'outlier'`, the form's chip): plan 11 decides where it goes.

## Global Constraints

- With `kUnlockEditing` false the dive page, the pane, the menus, the banners, the Data sources card, the source bar, the Cylinders and Equipment cards, the master-detail scaffold and the shortcuts build and behave exactly as today.
- A locked page shows no control that writes. A blocked operation is listed disabled with its reason (call 1). Nothing on the page moves when it unlocks or locks, in the full page or the pane.
- An operation runs only through `RecordEditController.runOperation`, which refuses while locked, dirty, saving or already running one. Nothing it runs is held in the sitting or written by Save.
- Leaving with unsaved changes asks (`showDiscardDialog`); leaving without locks and goes. A page pushed on top that returns (History, the profile editor, a picker, the photo viewer) does not end the sitting.
- Anything that acts after an `await` checks `mounted`, reads `ref` and `context` before its first `await`, and a session it holds checks `isDisposed` and `isFrozen`.
- Settings are read with `settingsProvider.select(...)`.
- No file over 800 lines. `dive_detail_page.dart` is at 791: Task 1 makes room and nothing else may push it past 780. `data_sources_section.dart` is at 732, `cylinders_card.dart` at 643, `master_detail_scaffold.dart` at 716: check `wc -l` before adding and move code to a part file first when an addition would pass 800. `dive_list_content.dart` (2,740), `dive_list_page.dart` (1,258) and `dive_edit_page.dart` (6,845) must not grow.
- Every new string goes in all 11 ARB files with a real translation, then `flutter gen-l10n`.
- No em-dash characters anywhere; no emojis; no mention of any AI tool in code, commits or pull requests. Do not join two parts of a label with a spaced hyphen.
- Tests restore global state: `tester.view` via `addTearDown`, the test database via `tearDownTestDatabase()`, any provider override or singleton they install, and any `ShortcutCatalog` entry they register.
- Before each commit: `dart format .`, `flutter analyze`, the affected test files, plus `flutter test test/architecture/ test/shared/` when files under `lib/` were added. Never the whole suite. Do not pipe `flutter test` into `grep` or `tail` to judge the result.
- Do not push or open a pull request; that waits for Eric.

## Review Focus

1. **An operation that rewrites the dive under a clean sitting** (re-parse replaces the profile, tanks and times). Afterwards every card shows the new stored values, no card has a dot, Save is disabled, and Cancel writes nothing. Pinned in Tasks 2 and 12.
2. **An editor open when an operation starts.** The operation is offered (nothing changed); afterwards the editor is closed, the page has not jumped, and the strip offers what is now absent. Pinned in Tasks 2 and 12.
3. **"Keep editing" on another row in the pane**, by tap and by the arrow keys. The URL, the list highlight and the pane stay on the dive being edited; "Discard" then moves all three. Pinned in Task 10.
4. **Escape with something over the page**: a dialog, a sheet, a popup menu, an autocomplete's options. That closes; the sitting stays. Escape on the page itself cancels. Pinned in Task 11.
5. **Leaving by the sidebar or Cmd/Ctrl+2 with unsaved changes** asks and, on "Keep editing", stays on the dive with the sitting intact; with none it goes and the sitting is gone. Pinned in Task 10.

## Preparation

- [ ] Work on a branch cut from current `origin/main` (plans 1 to 6, 9 and 10 merged; head at or after `6092175233d`).
- [ ] In a fresh worktree: `git submodule update --init --recursive`, `flutter pub get`, then `dart run build_runner build --delete-conflicting-outputs` with no build filter.
- [ ] `flutter analyze` on the whole repository is clean before any change.
- [ ] Take the pull request's "before" pictures now, before any code changes, by the macOS window route (a dev build with `--dart-define=UNLOCK_EDITING=true` and its own `SUBMERSION_DB_PATH`): the locked bar at phone and desktop width with its menu open, the unlocked bar, the pane locked, a planned dive's and an open draft's banners, the Data sources card's menus, the source bar's chip menu, the Cylinders card with an unknown transmitter serial. Light only: no colour changes.

## File Structure

New, shared (`lib/shared/widgets/record_editing/`):

| File | Responsibility |
| --- | --- |
| `record_operation_gate.dart` | `RecordOperationBlock`, `recordOperationBlockOf`, `recordOperationReason`, `recordOperationCaption` (the menu's caption item), `RecordOperationButton` (a button drawn disabled with its reason) |
| `record_edit_shortcuts.dart` | The three intents, `RecordEditShortcutTarget`, `recordEditShortcutTargetsProvider`, `RecordEditShortcuts` (mounted at the shell) |
| `record_sitting_exit_blocker.dart` | `RecordSittingExitBlocker`: holds an `AppExitBlocker` while its controller is unlocked; `confirmLeaveRecordSitting` for `GoRoute.onExit` |

New, elsewhere:

| File | Responsibility |
| --- | --- |
| `lib/features/dive_log/presentation/pages/dive_detail_page_bars.dart` | Part file: the standalone bar, the overflow menu glue, `_onMenuSelected`, `_DiveShortcuts`, `_kCompactAppBarWidth`, moved |
| `lib/features/dive_log/presentation/pages/dive_detail_page_operations.dart` | Part file: `_runOperation` and the operations' own handlers returning whether they changed the dive |
| `lib/features/dive_log/presentation/helpers/open_profile_editor.dart` | `openProfileEditor`, moved out of the form so the Profile card can call it |
| `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_embedded_editing_header.dart` | The pane header's unlocked row, laid over the locked row |
| `lib/core/router/section_navigation.dart` (modify) | `goInPlaceGuarded` beside `goInPlace` |

Modified, by task: see each task's Files.

---

### Task 1: Room in the dive page

`dive_detail_page.dart` is at 791 lines. Move code to part files before anything is added.

**Files:**
- Create: `lib/features/dive_log/presentation/pages/dive_detail_page_bars.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart`

**Interfaces:**
- Produces: in `dive_detail_page_bars.dart`, a mixin `_DiveDetailPageBars on ConsumerState<DiveDetailPage>` holding `_standaloneBar(Dive dive, Dive shown)` (the `AppBar` built today at `dive_detail_page.dart:614-662`), `_overflowMenu`, `_onMenuSelected`; and the class `_DiveShortcuts` and the constant `_kCompactAppBarWidth`, unchanged. The state class gains the mixin.

- [ ] **Step 1: Move the code.** Cut, do not rewrite. Members the moved code reads (`_appBarMenuKey`, `_displayOptionsMenu`, `_navigateToDive`, `lockButton`, `editingOffered`) stay where they are; a mixin `on ConsumerState<DiveDetailPage>` reaches them through abstract getters declared in it, as `_DiveDetailPageEditing` does for its own.
- [ ] **Step 2: Run the dive page's tests**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_page_test.dart test/features/dive_log/presentation/pages/dive_detail_page_unlock_test.dart`
Expected: PASS, unchanged. `wc -l lib/features/dive_log/presentation/pages/dive_detail_page.dart` reads at most 690.

- [ ] **Step 3: Commit**

```bash
git add lib/features/dive_log/presentation/pages/dive_detail_page.dart lib/features/dive_log/presentation/pages/dive_detail_page_bars.dart
git commit -m "refactor(dive-log): move the dive page's bar and menu glue to a part file"
```

---

### Task 2: The operation gate, and running an operation

**Files:**
- Create: `lib/shared/widgets/record_editing/record_operation_gate.dart`
- Modify: `lib/shared/widgets/record_editing/record_edit_controller.dart`, `record_edit_leave_guard.dart`, `record_edit_bar.dart`
- Modify: `lib/l10n/arb/app_*.arb` (one string)
- Test: `test/shared/widgets/record_editing/record_edit_controller_operation_test.dart`, `record_operation_gate_test.dart`

**Interfaces:**
- Produces:
  - `enum RecordOperationBlock { none, locked, unsaved }`.
  - `RecordOperationBlock? recordOperationBlockOf(RecordEditController<Object?>? controller)`: null when `controller` is null (the page offers no editing: everything as today); `locked` when not unlocked; `unsaved` when dirty, saving or running an operation; else `none`.
  - `String? recordOperationReason(AppLocalizations l10n, RecordOperationBlock? block, {bool plural = false})`: null for null and `none`; `locked` gives `recordEdit_unlockToUseThese` when `plural`, else `recordEdit_unlockToUseThis`; `unsaved` gives `recordEdit_saveOrCancelFirst`.
  - `PopupMenuItem<T> recordOperationCaption<T>(BuildContext context, String reason)`: `PopupMenuItem<T>(enabled: false, key: const ValueKey('recordOperationCaption'))` holding `Text(reason, style: textTheme.bodySmall)`. A menu adds it only when its reason is non-null.
  - `class RecordOperationButton extends StatelessWidget { const RecordOperationButton({required String? reason, required Widget Function(VoidCallback? onPressed) builder, required VoidCallback onPressed}); }`: builds `builder(reason == null ? onPressed : null)`, wrapped in `Tooltip(message: reason)` when blocked.
  - On `RecordEditController<T>`: constructor parameter `Future<T?> Function(T stored)? reread`; getters `bool isOperating`, `bool isBusy` (`isSaving || isOperating`); `Future<bool> runOperation(Future<bool> Function() operation)`; `void retake(T stored)`.
  - `RecordEditLeaveGuard` absorbs input and refuses Back while `isBusy` (was `isSaving`). `RecordEditBar` gains `bool isBusy = false`: Cancel and Save are disabled, with no progress mark, while it is true.

`runOperation` refuses (returns false, runs nothing) unless the controller is unlocked, clean, not saving and not running one. Otherwise it sets `isOperating`, freezes the session and notifies; awaits `operation()`; thaws. If the operation returned true it awaits `reread(session.stored)`: a record gives `retake(record)`, null gives `lock()`. If it returned false the sitting carries on as it was. If it threw, the sitting carries on as it was and the error is rethrown. `isOperating` is cleared in a `finally`, before `retake`. `retake(stored)` is refused unless unlocked and clean; it disposes the session, clears open and added cards, the layout record and invalid cards, starts a new session from `stored`, calls `onStart` and notifies once; `isUnlocked` never reads false in between.

- [ ] **Step 1: Write the failing tests**

```dart
// record_operation_gate_test.dart
test('no controller: not offered, no reason', () {
  expect(recordOperationBlockOf(null), isNull);
  expect(recordOperationReason(l10n, null), isNull);
});
test('locked, then unlocked and clean, then dirty', () {
  final c = RecordEditController<Note>(onSave: (_) async {});
  expect(recordOperationBlockOf(c), RecordOperationBlock.locked);
  expect(recordOperationReason(l10n, RecordOperationBlock.locked, plural: true), 'Unlock to use these');
  expect(recordOperationReason(l10n, RecordOperationBlock.locked), 'Unlock to use this');
  c.unlock(const Note('a'));
  expect(recordOperationBlockOf(c), RecordOperationBlock.none);
  c.session!.set(noteText, 'b');
  expect(recordOperationBlockOf(c), RecordOperationBlock.unsaved);
  expect(recordOperationReason(l10n, RecordOperationBlock.unsaved), 'Save or cancel your changes first');
});
testWidgets('a blocked button is disabled with its reason as tooltip', ...);
testWidgets('the caption item cannot be chosen', ...);

// record_edit_controller_operation_test.dart
test('refused while locked, dirty, saving or running one', () async { /* each returns false, operation never called */ });
test('a completed operation starts a fresh sitting on the record read again', () async {
  // reread returns Note('fresh'); afterwards isUnlocked, !isDirty,
  // session.stored == Note('fresh'), a different EditSession instance,
  // onStart called twice, openCardIds and addedCardIds empty.
});
test('the sitting is frozen while the operation runs', () async {
  // inside operation(): session.isFrozen, isBusy, set() changes nothing.
});
test('an operation that changed nothing keeps the sitting', () async { /* returns false: same session, no reread */ });
test('a record that no longer exists locks the page', () async { /* reread null: isUnlocked false */ });
test('an operation that throws keeps the sitting and rethrows', () async { /* same session, isOperating false */ });
test('retake is refused with unsaved changes', () { /* session unchanged */ });
testWidgets('the leave guard refuses Back while an operation runs', ...);
testWidgets('the bar disables Cancel and Save while busy', ...);
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/shared/widgets/record_editing/record_operation_gate_test.dart test/shared/widgets/record_editing/record_edit_controller_operation_test.dart`
Expected: FAIL, the names are not defined.

- [ ] **Step 3: Add `recordEdit_unlockToUseThese` "Unlock to use these" to all 11 ARB files** (its description: the caption over a menu's whole-record operations on a locked record page), then `flutter gen-l10n`.
- [ ] **Step 4: Implement the gate, `runOperation`, `retake`, and the guard and bar changes** as specified above.
- [ ] **Step 5: Run the new tests and the folder**

Run: `flutter test test/shared/widgets/record_editing/ test/l10n/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/shared/widgets/record_editing lib/l10n test/shared/widgets/record_editing
git commit -m "feat(shared): a record's whole-record operations wait for an unlocked, clean sitting"
```

---

### Task 3: The dive page runs its operations through the gate

**Files:**
- Create: `lib/features/dive_log/presentation/pages/dive_detail_page_operations.dart` (part)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (one `part` line), `dive_detail_page_editing.dart`, `dive_detail_page_actions.dart`
- Test: `test/features/dive_log/presentation/pages/dive_detail_page_unlock_operations_test.dart`

**Interfaces:**
- Consumes: Task 2's `runOperation`, `reread`, `recordOperationBlockOf`.
- Produces, in the part's mixin `_DiveDetailPageOperations`:
  - `RecordOperationBlock? get operationBlock`: `editingOffered ? recordOperationBlockOf(editController) : null`.
  - `Future<void> _runOperation(Future<bool> Function() operation)`: with editing not offered, awaits `operation()` (today's path); otherwise `editController.runOperation(operation)`, a refusal ignored.
  - Each operation's handler returns `Future<bool>` (whether it wrote): `_markAsLogged`, `_surfaceDraft`, `_addHeartRate`, `_linkPreDiveChecklist`, `_unlinkPreDiveChecklist`, `_reparseDive`, `_resyncDive`, `_setPrimarySource`, `_confirmAndSplit`, `_confirmAndRemoveSource`, `_confirmAndSeparate`, and `_confirmAndDelete` (the dialog and the delete of today's `_showDeleteConfirmation`, without the navigation). A refused confirmation, a cancelled picker or a failed write returns false.
  - `_deleteDive()`: `_runOperation(_confirmAndDelete)`, then the navigation `_showDeleteConfirmation` does today (onDeleted, pop, or go to the list) when it returned true and the page is mounted.
- The page's `RecordEditController` is built with `reread: (stored) => read(diveRepositoryProvider).getDiveById(stored.id)` (the container's read, as `onStart`), then invalidates `diveProvider(stored.id)` so the page reads it too.

`_confirmAndRemoveSource` passes `removeSourceWithUndo` no Undo when editing is offered (call 4); add the parameter to `removeSourceWithUndo` (`bool offerUndo = true`) rather than a second flow.

- [ ] **Step 1: Write the failing tests** (through the unlock harness, `pumpPage`, with fakes for the services each operation calls). The unlocked bar has no menu until Task 4, so these reach the operations through the controls already drawn while unlocked (the banners, the Data sources card); the menu's cases are Task 4's.

```dart
testWidgets('a planned dive marked as logged from its banner reads the dive again', (tester) async {
  // Unlock, tap Mark as logged on the planned banner: the fake repository's
  // convertPlanToActualDive is called once; afterwards the bar still reads
  // "Editing ...", Save is disabled, and the controller's session is a new
  // one on the dive read again.
});
testWidgets('a refused confirmation leaves the sitting as it was', (tester) async {
  // Split from the Data sources card, cancel the dialog: same session.
});
testWidgets('remove source on a page that offers editing offers no Undo', ...);
testWidgets('with the switch off the operations act as today', (tester) async {
  // unlockEditing: false: Mark as logged runs with no unlock; the remove
  // snackbar has its Undo.
});
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_page_unlock_operations_test.dart`
Expected: FAIL: the banner's write runs, but the sitting is not started again and remove source still offers Undo.

- [ ] **Step 3: Move `_markAsLogged` … `_confirmAndSeparate` into the part file**, each returning `Future<bool>`; route `_onMenuSelected`, `DiveDetailActions` and the banner callbacks through `_runOperation`. `dive_detail_page_actions.dart` keeps the rest.
- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_page_unlock_operations_test.dart test/features/dive_log/presentation/pages/dive_detail_page_test.dart test/features/dive_log/presentation/widgets/remove_source_flow_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/pages lib/features/dive_log/presentation/widgets/remove_source_flow.dart test/features/dive_log/presentation
git commit -m "feat(dive-log): the dive page's whole-record operations run from a clean sitting and start it again"
```

Order note: build Task 4 immediately after this task; the two share the menu.

---

### Task 4: The menu lists the operations, and History sits beside the lock

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_overflow_menu.dart`, `dive_detail_page_bars.dart`, `dive_detail_page_editing.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_detail/dive_detail_overflow_menu_test.dart` (new or extended), `test/features/dive_log/presentation/pages/dive_detail_page_unlock_menu_test.dart`

**Interfaces:**
- Consumes: `operationBlock` (Task 3), `recordOperationCaption` (Task 2).
- Produces: `DiveDetailOverflowMenu` gains `RecordOperationBlock? operations` (null: today's menu, order and items unchanged) and `bool historyInBar = false`.

With `operations` non-null the menu reads, in order: History (unless `historyInBar`), Open full page (pane), Display options, Export, Log near-miss, Log for a buddy's profile, Compare, View in planner, Plan repetitive dive; a `PopupMenuDivider`; the caption when blocked (`recordOperationReason(..., plural: true)`); then the operations, each `enabled: operations == RecordOperationBlock.none`: Mark as logged, Mark as complete, Add heart rate, the pre-dive link, Draw a profile (when `dive.profile.isEmpty`, as the form offers it; value `drawProfile`: Task 7 handles it), Re-parse raw data, Resync from original file, Delete. Each keeps today's condition for being listed. Favourite is never in it (plan 4).

The bar: locked, at 600 px and wider, an `IconButton(Icons.history, tooltip: changeLog_history)` calling `openChangeLogHistory` sits between the favourite state and the lock, and the menu gets `historyInBar: true`. Unlocked, `RecordEditBar(actions: [menu])` with the menu built the same way (History first, `historyInBar: false`).

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('locked: reading items enabled, operations disabled under the caption', (tester) async {
  // Open the menu on a planned dive with raw data. "Unlock to use these"
  // shows once; Export and Compare are enabled; Mark as logged, Re-parse
  // raw data and Delete are disabled (PopupMenuItem.enabled false).
});
testWidgets('unlocked and clean: no caption, operations enabled', ...);
testWidgets('unlocked with a change: "Save or cancel your changes first"', ...);
testWidgets('History beside the lock at 700 px, first in the menu at 500 px', (tester) async {
  // 700: an icon with tooltip History in the bar, no History in the menu;
  // 500: no icon; the menu's first item reads History.
});
testWidgets('the unlocked bar carries the menu between the title and Save', ...);
testWidgets('the bar does not change height on unlock', ...);
testWidgets('re-parse from the unlocked bar menu runs, and the sitting starts again', ...);
testWidgets('deleting from a sitting locks, deletes and leaves without asking', (tester) async {
  // No discard dialog; the location moved; the fake list's deleteDive called once.
});
testWidgets('with the switch off the menu is as today', (tester) async {
  // Same items in today's order, none disabled, no caption, no history icon.
});
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/dive_detail_overflow_menu_test.dart test/features/dive_log/presentation/pages/dive_detail_page_unlock_menu_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the menu groups, the History icon and the unlocked bar's menu.**
- [ ] **Step 4: Run them, and Task 3's tests, which now reach the menu in a sitting**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/ test/features/dive_log/presentation/pages/dive_detail_page_unlock_menu_test.dart test/features/dive_log/presentation/pages/dive_detail_page_unlock_operations_test.dart test/features/change_log/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation test/features/dive_log/presentation
git commit -m "feat(dive-log): the dive menu lists its whole-record operations, disabled until unlocked, with History beside the lock"
```

---

### Task 5: The banners' operations

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/planned_dive_banner.dart`, `draft_dive_banner.dart`, `widgets/dive_detail/dive_detail_header_block.dart`
- Test: `test/features/dive_log/presentation/widgets/planned_dive_banner_test.dart`, `draft_dive_banner_test.dart` (extend), `test/features/dive_log/presentation/pages/dive_detail_page_unlock_header_block_test.dart` (extend)

**Interfaces:**
- Consumes: `RecordOperationButton`, `recordOperationBlockOf`, `recordOperationReason`.
- Produces: `PlannedDiveBanner` and `DraftDiveBanner` gain `String? operationReason` (null: enabled, as today). Mark as logged, Surfaced and Mark as complete are `RecordOperationButton`s; Download now and Open in planner are untouched. `DiveDetailHeaderBlock` passes `recordOperationReason(l10n, recordOperationBlockOf(RecordEditScope.maybeOf<Dive>(context)))`.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('a banner operation with a reason is disabled and says why', (tester) async {
  // PlannedDiveBanner(operationReason: 'Unlock to use this'): Mark as logged's
  // onPressed is null; long-press shows the tooltip; Open in planner enabled.
});
testWidgets('Download now stays enabled whatever the reason', ...);
testWidgets('the banner is the same height with and without a reason', ...);
testWidgets('on the page: locked, the planned banner cannot mark as logged; unlocked it can', ...);
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/dive_log/presentation/widgets/planned_dive_banner_test.dart test/features/dive_log/presentation/widgets/draft_dive_banner_test.dart test/features/dive_log/presentation/pages/dive_detail_page_unlock_header_block_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them**

Same command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets test/features/dive_log/presentation
git commit -m "feat(dive-log): the planned and draft banners' operations wait for the unlock"
```

---

### Task 6: The Data sources card and the profile's source bar

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/data_sources_section.dart`, `source_bar.dart`, `widgets/dive_detail/dive_detail_data_sources_section.dart`, `widgets/dive_detail/dive_detail_profile_section.dart`
- Test: `test/features/dive_log/presentation/widgets/data_sources_section_test.dart`, `source_bar_test.dart` (extend), `test/features/dive_log/presentation/pages/dive_detail_page_unlock_profile_test.dart` (extend)

**Interfaces:**
- Produces: `DataSourcesSection` and `SourceBar` gain `String? operationReason`. In the per-source menu, Set as primary, Split into separate dive and Remove source are `enabled: operationReason == null` under a `recordOperationCaption` when blocked (`plural: true`); the section menu's Separate combined dives the same; Compare in 3D untouched. The source bar's chip menu: Set as primary the same, with the singular reason. `DiveDetailDataSourcesSection` and the profile section (card, pinned copy and the open Profile editor) pass the reason from the scope. Every one of these is already routed through `_runOperation` by Task 3.

Check `wc -l data_sources_section.dart` before adding: at 732, move the per-source menu (`_SourceMenuAction` and its builder) to a part file first if the change passes 800.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('with a reason the source menu lists its operations disabled under it', ...);
testWidgets('Compare in 3D stays enabled with a reason', ...);
testWidgets('the source bar chip menu: Set as primary disabled with the reason', ...);
testWidgets('on the page, locked: no tap on the card or the source bar writes', (tester) async {
  // A dive with two sources: open each menu, tap each disabled item;
  // the fake repository's setPrimaryDataSource, split, remove and separate
  // are never called.
});
testWidgets('unlocked and clean: Set as primary from the pinned copy runs and the sitting starts again', ...);
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/dive_log/presentation/widgets/data_sources_section_test.dart test/features/dive_log/presentation/widgets/source_bar_test.dart test/features/dive_log/presentation/pages/dive_detail_page_unlock_profile_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them**

Same command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets test/features/dive_log/presentation
git commit -m "feat(dive-log): data source operations and set primary wait for the unlock"
```

---

### Task 7: Edit profile on the Profile card, and Draw a profile in the menu

**Files:**
- Create: `lib/features/dive_log/presentation/helpers/open_profile_editor.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (calls the helper; must not grow), `widgets/dive_detail/dive_detail_profile_section.dart`, `dive_detail_page_operations.dart`, `dive_detail_page_bars.dart`
- Modify: `lib/l10n/arb/app_*.arb` (one string)
- Test: `test/features/dive_log/presentation/helpers/open_profile_editor_test.dart`, `test/features/dive_log/presentation/pages/dive_detail_page_unlock_profile_test.dart` (extend)

**Interfaces:**
- Produces: `Future<bool> openProfileEditor(BuildContext context, WidgetRef ref, String diveId, {String? initialMode})`: today's `_openProfileEditor` (`dive_edit_page.dart:3801-3851`) up to the route's answer: asks which source to start from when several have samples, pushes `editProfile`, returns whether it saved. The form keeps its `_refreshAfterProfileSave` after it. `initialMode: 'draw'` skips the source question.
- Produces: the Profile card's toolbar gains, on a page that offers editing and outside the pinned copy (`fillHeight == false`), an `IconButton(Icons.edit_note, tooltip: diveLog_profile_editProfile)` wrapped in `RecordOperationButton` with the singular reason; it calls a new `onEditProfile` callback the page supplies (`_runOperation(() => openProfileEditor(context, ref, dive.id))`). The menu's `drawProfile` value runs `_runOperation(() => openProfileEditor(context, ref, dive.id, initialMode: 'draw'))`.

The profile editor is pushed above the page, so the sitting is not ended; it is frozen until the editor returns (Task 2).

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('openProfileEditor asks for a source on a multi-source dive and returns the editor answer', ...);
testWidgets('the Profile card offers Edit profile, disabled while locked', ...);
testWidgets('unlocked and clean, Edit profile pushes the editor; its save starts the sitting again', ...);
testWidgets('a cancelled editor leaves the sitting as it was', ...);
testWidgets('the pinned copy has no Edit profile', ...);
testWidgets('Draw a profile is listed for a dive with no profile and pushes draw mode', ...);
testWidgets('the Profile card toolbar is the same width locked and unlocked', ...);
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/dive_log/presentation/helpers/open_profile_editor_test.dart test/features/dive_log/presentation/pages/dive_detail_page_unlock_profile_test.dart`
Expected: FAIL.

- [ ] **Step 3: Add `diveLog_profile_editProfile` "Edit profile" to all 11 ARB files, `flutter gen-l10n`; implement.**
- [ ] **Step 4: Run them, and the form's profile tests**

Run: `flutter test test/features/dive_log/presentation/helpers/open_profile_editor_test.dart test/features/dive_log/presentation/pages/dive_detail_page_unlock_profile_test.dart test/features/dive_log/presentation/pages/dive_edit_profile_source_test.dart test/l10n/`
Expected: PASS. `dive_edit_profile_source_test.dart` is the form's test of the source question, which now runs through the helper.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation lib/l10n test/features/dive_log/presentation
git commit -m "feat(dive-log): Edit profile on the Profile card and Draw a profile in the menu, as whole-record operations"
```

---

### Task 8: Assign transmitter, the tank gear menu and the check-in chip

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/cylinders_card.dart`, `widgets/dive_detail/dive_detail_equipment_section.dart`, `lib/features/equipment/presentation/widgets/observation_status_chip.dart`
- Test: `test/features/dive_log/presentation/pages/dive_detail_page_unlock_gear_cards_test.dart` (extend), `test/features/equipment/presentation/widgets/observation_status_chip_test.dart` (extend)

**Interfaces:**
- Consumes: `RecordEditScope.maybeOf<Dive>(context)`, its `runOperation`, `recordOperationBlockOf`, `RecordOperationButton`.
- Produces:
  - `cylinders_card.dart`: `canAssign` (`:144-145`) is replaced by `reason = recordOperationReason(l10n, recordOperationBlockOf(edit))`. Assign transmitter is a `RecordOperationButton`, always visible where it shows today (the `Opacity`, `IgnorePointer` and `ExcludeSemantics` go). Its press runs `edit.runOperation(() async { await context.push(...); return true; })` on a page that offers editing, the push as today otherwise. The tank gear menu button is the same: disabled with the reason as tooltip; its items run inside `edit.runOperation`.
  - `ObservationStatusChip` gains `String? operationReason` and `Future<void> Function(Future<bool> Function())? runAsOperation`. With a reason it is the disabled chip plan 5 draws for read-only (its colour kept) with the reason as tooltip; with none it opens the check-in sheet through `runAsOperation` (the sheet's own write, then true). `checkInReadOnly` (`cylinders_card.dart:148-152`, `dive_detail_equipment_section.dart:41-49`) keeps meaning "not gear this dive is stored with".

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('locked: Assign transmitter shows, disabled, with "Unlock to use this"', ...);
testWidgets('unlocked with a change: disabled with "Save or cancel your changes first"', ...);
testWidgets('unlocked and clean: Assign transmitter pushes the setup and the sitting starts again', ...);
testWidgets('the Cylinders card is the same height locked and unlocked', ...);
testWidgets('the check-in chip, locked: no sheet opens', ...);
testWidgets('the check-in chip, unlocked with a change: no sheet, the reason as tooltip', ...);
testWidgets('the check-in chip, unlocked and clean: the sheet opens and writes as today', ...);
testWidgets('with the switch off Assign, the gear menu and the chip act as today', ...);
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_page_unlock_gear_cards_test.dart test/features/equipment/presentation/widgets/observation_status_chip_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement.** Check `wc -l cylinders_card.dart` first (643).
- [ ] **Step 4: Run them, and plan 5's gear tests**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_page_unlock_gear_cards_test.dart test/features/dive_log/presentation/pages/dive_detail_page_unlock_gear_test.dart test/features/equipment/presentation/widgets/ test/features/dive_log/presentation/widgets/cylinders_card_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features test/features
git commit -m "feat(dive-log): assign transmitter, the tank gear menu and gear check-ins wait for an unlocked, clean dive"
```

---

### Task 9: The list pane gets the lock

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_embedded_editing_header.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page_editing.dart`, `dive_detail_page.dart` (the embedded branch, `:595-608`), `widgets/dive_detail/dive_detail_embedded_header.dart`, `lib/features/dive_log/presentation/widgets/site_suggestion_card.dart` (where `SiteSuggestionEditing` is declared, `:43`), `lib/l10n/arb/app_*.arb` (one value)
- Test: `test/features/dive_log/presentation/pages/dive_detail_page_unlock_pane_test.dart` (new), `dive_detail_page_unlock_test.dart` (the test "in the list pane the page has no lock yet" is replaced), `test/features/media/presentation/helpers/media_drop_import_test.dart` (hint text)

**Interfaces:**
- Produces:
  - `editingOffered => widget.unlockEditing` (the pane included).
  - `SiteSuggestionEditing siteSuggestionEditingOf(BuildContext context)`: the choice `DiveDetailHeaderBlock` makes today (`:45-50`), moved into `site_suggestion_card.dart` beside `SiteSuggestionEditing` and used by the header block and the pane header.
  - `editPane({required Dive dive, required Dive shown, required Widget content})` in `_DiveDetailPageEditing`: `RecordEditLeaveGuard` (for its input absorbing while busy) around `RecordEditScope<Dive>` around a `Column` of the header, `AddStripLayout(strip: ..., body: content)`.
  - `DiveDetailEmbeddedHeader` gains `Widget? lock` (the lock button), `Widget? history` (the History icon), `RecordEditController<Dive>? editing`. With `editing` non-null: favourite is state only (as the standalone bar, plan 4); the banners get their `operationReason`; the suggestion card gets `siteSuggestionEditingOf(context)`; while unlocked the row's children are laid out unchanged in `Visibility(visible: false, maintainSize: true, maintainAnimation: true, maintainState: true)` and `DiveDetailEmbeddedEditingHeader` is laid over them in a `Stack`: Cancel, "Editing <title>", the menu, Save (the `AppBarTextAction`s `RecordEditBar` uses), filling the row's height.
  - `diveLog_media_dropUnlockHint` reads "Unlock this dive to add photos." in English and its translation in each locale (the plan 6 wording).

The pane then publishes its sitting to `openDiveSittingProvider` through the code that already does it for the full page, so a drop on an unlocked pane is held (plan 6 Task 21) and a locked pane refuses with the hint.

- [ ] **Step 1: Write the failing tests** (`pumpPage(tester, embedded: true, size: const Size(1200, 900))`)

```dart
testWidgets('the pane shows the lock and History, and favourite as state only', ...);
testWidgets('unlocking the pane: Cancel and Save in its header, the same height', (tester) async {
  // Measure the header's RenderBox height locked and unlocked: equal. The
  // first card's top does not move by more than the strip's height.
});
testWidgets('editing Notes in the pane and saving writes one sitting', ...);
testWidgets('the pane menu lists the operations as the full page does', ...);
testWidgets('a drop on an unlocked pane is held; on a locked one the hint reads "Unlock this dive to add photos."', ...);
testWidgets('the pane\'s banners and site suggestion follow the lock', ...);
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_page_unlock_pane_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**, and update the one translated value in all 11 ARB files, then `flutter gen-l10n`.
- [ ] **Step 4: Run them, and the pane's existing tests**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_page_unlock_pane_test.dart test/features/dive_log/presentation/pages/dive_detail_page_unlock_test.dart test/features/dive_log/presentation/pages/dive_detail_page_unlock_drop_test.dart test/features/dive_log/presentation/pages/dive_list_detail_callbacks_test.dart test/features/dive_log/presentation/pages/dive_list_page_test.dart test/features/media/presentation/helpers/ test/l10n/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features lib/l10n test/features
git commit -m "feat(dive-log): the dive list's pane unlocks to edit in place, behind the switch"
```

---

### Task 10: Leaving a sitting asks, by every way out

**Files:**
- Create: `lib/shared/widgets/record_editing/record_sitting_exit_blocker.dart`
- Modify: `lib/core/router/app_router.dart` (`onExit` on `dives` and `diveDetail`), `lib/core/router/section_navigation.dart` (`goInPlaceGuarded`), `lib/shared/widgets/master_detail/master_detail_scaffold.dart` (`_onItemSelected`, `_onCreate`), `lib/features/dive_log/presentation/widgets/dive_list_content.dart` (`_openDive`, no net growth), `lib/features/dive_log/presentation/pages/dive_list_page.dart` (the map toggle `:154-163`, the add sheet `:124`, the map's details tap `:431`; no net growth), `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_hero_section.dart` (the site link `:101`), `dive_detail_page_editing.dart`
- Test: `test/shared/widgets/record_editing/record_sitting_exit_blocker_test.dart`, `test/shared/widgets/master_detail/master_detail_scaffold_leave_test.dart`, `test/features/dive_log/presentation/pages/dive_detail_page_unlock_leave_test.dart`

**Interfaces:**
- Consumes: `appExitGuardProvider` (`lib/core/app/app_exit_guard.dart`): `hold(AppExitBlocker)`, `release`, `mayLeave()`.
- Produces:
  - `class RecordSittingExitBlocker<T>` with `RecordSittingExitBlocker({required RecordEditController<T> controller, required AppExitGuard guard, required Future<bool> Function() confirm})`: listens to the controller; holds one `AppExitBlocker(hasUnsavedWork: () => controller.isDirty, confirmLeaving: confirm)` while it is unlocked, releases it when it locks and in `dispose`.
  - `Future<bool> confirmLeaveRecordSitting(BuildContext context, GoRouterState state)`: `appExitGuardProvider.mayLeave()` read from the container, as `confirmLeaveTableEditor` does.
  - `Future<void> goInPlaceGuarded(BuildContext context, String location)`: reads the guard before its `await`; `mayLeave()`; then `goInPlace` if the context is still mounted.
  - `MasterDetailScaffold._onItemSelected` and `_onCreate` await `mayLeave()` first and do nothing on false.
  - The dive page holds a `RecordSittingExitBlocker` (created with the controller) whose `confirm` is `cancelSitting(context, editController)`. It locks when it is handed a site to show (`embeddedSiteId` becoming non-empty, in `didUpdateWidget`).
  - `dive_list_content.dart` `_openDive` asks `mayLeave()` before it sets `highlightedDiveIdProvider`, and returns on false.

- [ ] **Step 1: Write the failing tests**

```dart
// record_sitting_exit_blocker_test.dart
test('holds while unlocked, releases on lock and dispose', ...);
test('a clean sitting is no unsaved work', ...);

// master_detail_scaffold_leave_test.dart
testWidgets('a held blocker that says no keeps the selection', (tester) async {
  // Hold a blocker whose confirm returns false; tap another row: location
  // unchanged. Confirm true: location moves.
});
testWidgets('with nothing held selection changes at once', ...);

// dive_detail_page_unlock_leave_test.dart
testWidgets('another row with unsaved changes asks; Keep editing stays, highlight included', ...);
testWidgets('Discard moves to the row and locks', ...);
testWidgets('the arrow keys in the list ask the same', ...);
testWidgets('the sidebar with unsaved changes asks; Keep editing stays on the dive', ...);
testWidgets('the sidebar with no changes leaves at once', ...);
testWidgets('Back on the full page asks once, not twice', (tester) async {
  // PopScope asks, Discard locks, onExit finds nothing to ask about: one dialog.
});
testWidgets('the hero\'s site link in the pane asks; with no changes it locks and shows the site', ...);
testWidgets('History pushed during a sitting comes back to the same sitting', ...);
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/shared/widgets/record_editing/record_sitting_exit_blocker_test.dart test/shared/widgets/master_detail/master_detail_scaffold_leave_test.dart test/features/dive_log/presentation/pages/dive_detail_page_unlock_leave_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement.** `master_detail_scaffold.dart` is at 716: keep the change to the two methods.
- [ ] **Step 4: Run them, and the scaffold's and the exit guard's tests**

Run: `flutter test test/shared/widgets/master_detail/ test/shared/widgets/record_editing/ test/core/app/ test/features/dive_log/presentation/pages/dive_detail_page_unlock_leave_test.dart test/features/dive_log/presentation/pages/dive_list_page_test.dart test/features/table_editor/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(shared): leaving a record's sitting by another row, another tab or a quit asks first"
```

---

### Task 11: Unlock, Save and Cancel from the keyboard

**Files:**
- Create: `lib/shared/widgets/record_editing/record_edit_shortcuts.dart`
- Modify: `lib/core/router/app_router.dart` (the shell's builder, `:341-344`), `lib/core/accessibility/app_shortcuts.dart` (catalog entries), `lib/core/accessibility/shortcut_display.dart` (`_shortcutEntryLabels`), `dive_detail_page_editing.dart`, `lib/l10n/arb/app_*.arb` (two strings)
- Test: `test/shared/widgets/record_editing/record_edit_shortcuts_test.dart`, `test/features/dive_log/presentation/pages/dive_detail_page_unlock_shortcuts_test.dart`, `test/accessibility/shortcut_display_test.dart` (runs as is)

**Interfaces:**
- Produces:
  - `class UnlockRecordIntent extends Intent`, `class SaveSittingIntent extends Intent`, `class CancelSittingIntent extends Intent` (const constructors).
  - `class RecordEditShortcutTarget { RecordEditShortcutTarget({required RecordEditController<Object?> controller, required VoidCallback unlock, required VoidCallback save, required VoidCallback cancel, required bool Function() isCurrent}); }`
  - `final recordEditShortcutTargetsProvider = Provider<RecordEditShortcutTargets>(...)`; `RecordEditShortcutTargets` has `void add(RecordEditShortcutTarget)`, `void remove(RecordEditShortcutTarget)`, `RecordEditShortcutTarget? get current` (the last added whose `isCurrent()` is true).
  - `class RecordEditShortcuts extends ConsumerWidget { const RecordEditShortcuts({required Widget child}); }`: `Shortcuts` with `NotWhileTypingActivator(platformShortcut(LogicalKeyboardKey.keyL))` to unlock, `platformShortcut(LogicalKeyboardKey.keyS)` to save, `SingleActivator(LogicalKeyboardKey.escape)` to cancel, and `Actions` whose `isEnabled` reads `current`: unlock while it is locked, save while unlocked, dirty and not busy, cancel while unlocked and not busy. A disabled action leaves the key unhandled.
  - The shell builder wraps `MainScaffold` in `RecordEditShortcuts` inside the global `CallbackShortcuts`.
  - The dive page adds its target in `initState` when editing is offered (`unlock: () => editController.unlock(shownDive(stored))`, `save: _saveAndReport`, `cancel: () => cancelSitting(context, editController)`, `isCurrent: () => mounted && (ModalRoute.of(context)?.isCurrent ?? true)`) and removes it in `dispose`.
  - With `kUnlockEditing`, `AppShortcuts`' catalog lists `Unlock to edit` (Cmd/Ctrl+L) and `Save changes` (Cmd/Ctrl+S) under `Editing`; `_shortcutEntryLabels` maps them to `accessibility_shortcut_unlockRecord` and `accessibility_shortcut_saveChanges`. Escape is already listed as "Close / Cancel".

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('Cmd/Ctrl+L unlocks, Cmd/Ctrl+S saves, Escape cancels', ...);
testWidgets('Save and Escape work while a text field in an open card has focus', ...);
testWidgets('Cmd/Ctrl+L does nothing while typing in the list search', ...);
testWidgets('Escape with a dialog open closes the dialog and keeps the sitting', ...);
testWidgets('Escape in an open popup menu closes the menu only', ...);
testWidgets('a pushed page on top: the keys act on neither page underneath', ...);
testWidgets('Escape with no sitting reaches whatever else listens (no key swallowed)', (tester) async {
  // A child Focus.onKeyEvent sees Escape when the page is locked.
});
testWidgets('in the pane the keys act with focus in the list', ...);
testWidgets('the help dialog lists Unlock to edit and Save changes under Editing', ...);
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/shared/widgets/record_editing/record_edit_shortcuts_test.dart test/features/dive_log/presentation/pages/dive_detail_page_unlock_shortcuts_test.dart`
Expected: FAIL.

- [ ] **Step 3: Add the two strings to all 11 ARB files, `flutter gen-l10n`; implement.**
- [ ] **Step 4: Run them, and the shortcut suites**

Run: `flutter test test/shared/widgets/record_editing/ test/features/dive_log/presentation/pages/dive_detail_page_unlock_shortcuts_test.dart test/accessibility/ test/core/accessibility/ test/features/media/presentation/pages/media_viewer_unlock_test.dart test/l10n/`
Expected: PASS. The photo viewer's own Escape keeps working: its focus handler is deeper than the shell's.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(shared): unlock, save and cancel a record's sitting from the keyboard"
```

---

### Task 12: The page, end to end

**Files:**
- Test: `test/features/dive_log/presentation/pages/dive_detail_page_unlock_operations_test.dart` (extend)

- [ ] **Step 1: Write the end-to-end cases**

```dart
testWidgets('locked: no tap on any operation writes', (tester) async {
  // A planned dive with raw data, an imported file, two sources, a linked
  // pre-dive checklist, an unknown transmitter serial and gear with a
  // check-in chip. Tap every menu item, banner button, source menu item,
  // source bar item, Edit profile, Assign, the gear menu and the chip. No
  // repository or service fake records a call.
});
testWidgets('re-parse under an open, unchanged Notes editor: the editor closes, nothing jumps', (tester) async {
  // Unlock, open Notes, note the Notes card's top. Re-parse: afterwards no
  // card is open, Save is disabled, the card's top is where it was.
});
testWidgets('after an operation the cards show the dive as stored now', (tester) async {
  // The fake reparse changes the max depth: the header card reads the new
  // depth while still unlocked; Cancel locks with no write.
});
testWidgets('the full page and the pane agree: the same menu, the same reasons', ...);
```

- [ ] **Step 2: Run them**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_page_unlock_operations_test.dart`
Expected: PASS. Make each case fail once by breaking the code it covers (remove the gate's `unsaved` branch; skip `retake`) and restore it.

- [ ] **Step 3: The wider run**

Run: `flutter test test/architecture/ test/shared/ test/l10n/ test/accessibility/ test/core/accessibility/ test/core/app/ test/features/dive_log/presentation/ test/features/equipment/presentation/widgets/ test/features/media/presentation/ test/features/table_editor/`
Expected: PASS. Then `flutter analyze` on the whole repository: no issues.

- [ ] **Step 4: Commit**

```bash
git add test/features/dive_log/presentation/pages
git commit -m "test(dive-log): whole-record operations, the pane and leaving, end to end"
```

---

## Pull request

One, `Refs #4527`. It touches `lib/**/presentation/` and `lib/shared/widgets/`, so it carries the "before" pictures from Preparation and the same views after, taken by the macOS window route with the switch on: the locked bar at phone and desktop width with the menu open, the unlocked bar with its menu, History beside the lock, the pane locked and unlocked (same header height), the banners disabled, the Data sources and source bar menus with their caption, Edit profile on the Profile card, Assign transmitter disabled. A line says the lock is unreachable without the build switch; with the switch off nothing looks different. Pushing and opening it waits for Eric.

## For plans 8 and 11

- **Plan 8 (new dive).** A new dive has no operations: `recordOperationBlockOf` reads `unsaved` for a sitting with changes, and the menu of a page that is creating offers none of them. Leaving a new dive with anything entered goes through the same `RecordSittingExitBlocker`, and the pane's `?mode=new` through `MasterDetailScaffold._onCreate`'s check.
- **Plan 11 (switch-over).** Remove the Edit buttons from both bars; `&mode=edit` and `/dives/:id/edit` open the page unlocked (`editController.unlock` on first build). `removeSourceWithUndo(offerUndo:)`, the `operations == null` menu and every `operationReason == null` default are the switch-off paths and go with the switch. The form's outlier entry to the profile editor needs a home.

---

## After the review

The plan was built as written in one session (Eric chose "Native"), then reviewed as a whole branch by a fresh reviewer. This is what differs from the task text above, for whoever writes plans 8 and 11.

### Names that changed, or were added

| Above | Now |
| --- | --- |
| `bool isOperating` kept as a flag | The operation names the sitting it froze: ending that sitting (a lock) ends the operating state, and an operation that finishes after it touches nothing it no longer owns |
| `openProfileEditor(...)` returns `bool` | `Future<ProfileEditorResult>`, `({bool saved, bool promoted})`: the form still reseeds its source fields when the primary source changed |
| The operations' handlers move to the operations part | They stay in `dive_detail_page_actions.dart`, each returning `Future<bool>` (true whenever a write was attempted, a failed one included); the part holds `operationBlock`, `_runOperation`, `_deleteDive`, `_editProfile`, `_drawProfile` |
| Escape mapped at the shell, acting when the page is current | Still at the shell, and it stands aside whenever an enabled `DismissIntent` action is nearer the focus (an autocomplete's suggestions, a menu, a sheet), searched from above a focused text field, whose own dismiss action is always enabled |
| Catalog entries in `AppShortcuts` | Registered by `RecordEditShortcuts` itself while mounted (`listInHelp`, default `kUnlockEditing`), so `lib/core` does not import the switch |
| `goInPlaceGuarded` only | Also `goGuarded`, for a tab's own destination (the rail, the more sheet, Cmd/Ctrl+1 to 5): a tab's own entry keeps its route, so no `onExit` sees it |
| `KeyboardListNavigator` | Gains `resync`: told when the list refused a keyboard move, the cursor goes back to the current row |

### Fixed after the review

- Escape with an autocomplete's suggestions showing cancelled the sitting; it now closes the suggestions (and a sheet or a menu) first.
- Back with changes on the list pane, its tab's first page, popped that page after Discard; it now locks in place.
- The current tab's own destination dropped a pane sitting without asking; it asks.
- Tapping or arrowing back onto the dive being edited asked to discard; the row already shown asks nothing.
- "Keep editing" after an arrow key left the list's cursor on the refused row; the cursor goes back.
- A lock during an operation left the next sitting busy.

### Left open (minor, from the review)

- The check-in sheet and the tank gear menu answer "wrote" even when dismissed, so opening and dismissing one starts the sitting again and closes open, unchanged editors.
- "Open full page" stays enabled in the unlocked pane's menu: the full page can be unlocked too, two sittings on one dive (each saves only its own changes).
- Escape does not reach the pane's sitting while the list has focus: the list's own Escape (leave selection mode) answers first.
- With the switch off, the dive routes' `onExit` and the lists' selection run one microtask later (the guard is asynchronous); nothing visible.
- An error reading the dive again after an operation is not caught; after a delete it would skip leaving the page.
- No test that the strip offers again what an operation emptied.
- `dive_edit_page.dart` lost the doc comment on `_refreshAfterProfileSave` in the move.

### Tests the plan listed that were written differently

- The menu operation shown running from the unlocked bar is Unlink pre-dive checklist (Re-parse needs the native parser faked).
- No page test for the hero's site link in the pane (it exists only with a map tile, which fetches from the network), for a clean sitting locking when the pane shows a site, for the pinned profile copy, or for History pushed during a sitting.
- No `open_profile_editor_test.dart`: the form's `dive_edit_profile_source_test.dart` pins the source question through the helper.
- "Edit profile keeps its place in the toolbar" replaced "the toolbar is the same width": the Profile card's own pencil arrives on unlock (plan 6) and moves the whole toolbar.

### Cleared later (PR #4670)

- The check-in sheet and the tank gear menu already answered "nothing written" when dismissed (pinned in #4661); so does every handler on the page.
- "Open Full Page" is disabled while the pane is unlocked, under "Save or cancel your changes first" (Eric's choice): one sitting per dive.
- Escape with nothing selected in the list goes on to the pane's sitting; a held Escape's repeats stay with the list.
- A failed read after an operation never escapes: the page and the cards' controls share `recordOperationRunnerOf`, which logs it. A delete whose read fails still leaves the page (tested).
- The strip offering again what an operation emptied is tested; the doc comment on `_refreshAfterProfileSave` was already back, and the dive page's imports are grouped.
- The four page tests listed above are written (`dive_detail_page_unlock_pane_site_test.dart`, `dive_detail_page_unlock_pinned_profile_test.dart`, `dive_detail_page_unlock_history_test.dart`). Writing them found the pinned copy tripping `node.built` after Set as primary; the pinned box is now a semantics container of its own.
- "One microtask later with the switch off" stays as noted: nothing visible.

### For plans 8 and 11

- **Plan 8.** A new dive's sitting is clean until something is entered, so `RecordSittingExitBlocker` asks only once there is work; the pane's `?mode=new` goes through `MasterDetailScaffold._onCreate`'s ask.
- **Plan 11.** Remove the Edit buttons in both bars; `removeSourceWithUndo(offerUndo:)`, the `operations == null` menu and every `operationReason == null` default are the switch-off paths. The form's outlier entry to the profile editor still needs a home.
