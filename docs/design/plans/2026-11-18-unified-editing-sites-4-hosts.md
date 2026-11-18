# Unified editing, sites, plan 4: hosts, routes and whole-record operations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the site's lock to all three places a site is shown (the full page, the site list's pane, the site inside the dive list's pane), make the old edit addresses open the page unlocked, and turn the site's delete, remove, unhide and library actions into whole-record operations (issue #4527, phase 2). Still behind `kUnlockSiteEditing`.

**Architecture:** Plans 1 to 3 (PRs #4686, #4688, #4694) built the site page on `RecordEditHost<_SiteDetailContent, DiveSite>`, but only the full page hosts editing (`hostsEditing => widget.unlockEditing && !widget.embedded`). This plan first lifts two pieces the dive page keeps to itself into `lib/shared/widgets/record_editing/`: opening a page unlocked (`_DiveDetailPageUnlockOpen`), and the pane header's unlocked row laid over the locked one. The dive page moves onto both unchanged. The site page then hosts editing in its panes too, opens unlocked from `?mode=edit`, and runs its record actions through `RecordEditController.runOperation`, as the dive's menu does.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), go_router, `flutter gen-l10n` (no new strings).

**Spec:** [docs/design/specs/2026-11-17-unified-editing-phase-2-sites-design.md](../specs/2026-11-17-unified-editing-phase-2-sites-design.md), sections "Hosts and routes", "What is held, and what is not" (the whole-record rows) and "Delivery" item 4.

## Global Constraints

- Built on the names plans 1 to 3 shipped: `RecordEditHost` (`hostsEditing`, `offersEditing`, `editScaffold`, `editPane`, `editingPaneRow`, `lockButton`, `sittingEndedByLeave`, `onEditChanged`), `_SiteDetailPageEditing` (`_editingInBuild`, `_offersEditingNow`, `_canEditSite`, `_tellDrop`), `_SiteDetailFullscreen`, `recordOperationBlockOf`, `recordOperationRunnerOf`, `recordOperationReason`, `recordOperationCaption` (`record_operation_gate.dart`), `cancelSitting`.
- With `kUnlockSiteEditing` false the site page, its panes and its routes look and behave exactly as today: no existing test changes its expectations. Every switch-dependent change takes the switch as a parameter that defaults to `kUnlockSiteEditing`, so tests can turn it on.
- Where a shared piece is lifted out of the dive page, the dive's tests pass unchanged. That is the proof nothing moved. Shared pieces are named for what they are, not for a record type, because phase 3's detail pages will use them.
- A locked page writes nothing on any tap, in all three hosts.
- The attachment work in Delivery item 4 (the PDF viewer's lock and the details page for a document with no viewer) is its own plan, 4b, written after this one. Nothing here changes attachments.
- The Edit buttons and the reader's "Suggest changes" stay until the switch-over plan; with the switch on, Edit leads to the unlocked page through the routes below, and `?suggest=1` still opens the form (plan 5 replaces it).
- No new strings. Never use em-dashes or en-dashes as punctuation. Commits, the PR and files follow the repository guide's Attribution section.
- Test runs: only the test files a task writes or changes, by literal path, at most 15 per run. Never a folder, never the whole suite, never guards by hand: the pre-push hook runs them.
- Never `--build-filter` build_runner.

## Review Focus

1. **The back arrow of a site shown in the dive list's pane, with unsaved changes.** It asks first; Keep editing stays on the site with the sitting intact; Discard goes back to the dive. Pinned in Task 6.
2. **Delete chosen from the menu while the site is unlocked with unsaved changes.** It does not run: the menu shows "Save or cancel first" over a disabled Delete, and nothing is deleted. Pinned in Task 4.
3. **`/sites/<id>?mode=edit` opened on desktop**, where the full page moves into the list pane. The pane opens the site unlocked once; it does not open twice or lose the unlock in the move. Pinned in Task 3.
4. **A library reader's site** (no lock until plan 5). Remove from profile and Unhide still work as today, because an operation is gated only where the page offers editing. Pinned in Task 4.
5. **Save or Cancel in a pane opened by `&mode=edit`.** The pane returns to the site in view mode (the address drops `mode=edit`), and Back does not reopen it unlocked. Pinned in Task 5.

## Preparation

- [ ] On branch `ericgriffin/unified-editing-sites-4-hosts`, cut from `origin/main` after #4694 merged. Generate code unfiltered in the background if the worktree is fresh: `dart run build_runner build --delete-conflicting-outputs`.
- [ ] `flutter analyze` on the whole repository is clean.
- [ ] Commit this plan: `git add docs/design/plans/2026-11-18-unified-editing-sites-4-hosts.md && git commit -m "docs(sites): unified editing phase 2 plan 4"`.

## File Structure

New:

| File | Responsibility |
| --- | --- |
| `lib/shared/widgets/record_editing/record_open_unlocked.dart` | `RecordOpenUnlocked`: a record page asked to open unlocked does so once, and tells its owner when that sitting ends |
| `lib/shared/widgets/record_editing/record_pane_row.dart` | `RecordPaneRow`: a pane header's locked row, with the unlocked row laid over it; `kRecordCompactBarWidth` |
| `lib/features/dive_sites/presentation/pages/site_detail_page_operations.dart` | The site's whole-record operations (a `part` of `site_detail_page.dart`) |
| `lib/features/dive_sites/presentation/pages/site_detail_page_bars.dart` | The full page's locked bar and the pane's header (a `part`, moved out of `site_detail_page.dart`, which is at 2,412 lines) |
| `lib/features/dive_sites/presentation/pages/site_edit_routes.dart` | `siteEditRedirect`, `unlockedSitePane` |

Modified, by task: see each task's Files block.

---

### Task 1: `RecordOpenUnlocked`, lifted out of the dive page

**Files:**
- Create: `lib/shared/widgets/record_editing/record_open_unlocked.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page_unlock_open.dart` (becomes a thin mixin over the shared one), `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (mixin list; `_openedUnlocked` reads become `hasOpenedUnlocked`)
- Test: `test/shared/widgets/record_editing/record_edit_host_test.dart` (existing; add a group), and unchanged: `test/features/dive_log/presentation/pages/dive_detail_page_unlock_open_test.dart`, `dive_detail_page_unlock_pane_test.dart`, `dive_detail_page_unlock_pane_site_test.dart`

**Interfaces:**
- Produces:

```dart
mixin RecordOpenUnlocked<W extends ConsumerStatefulWidget, T>
    on RecordEditHost<W, T> {
  /// Whether [widget] asks for the page opened unlocked.
  bool openUnlockedOf(W widget);

  /// Told once when the sitting this page opened unlocked has ended, not
  /// when a leave the app asked about ended it.
  VoidCallback? get onOpenedSittingEnded;

  /// The page is handing its unlock to another (a pane it is moving into).
  bool get handsUnlockElsewhere => false;

  /// The page has gone for good (its record deleted): no end is told.
  bool get hasLeftForGood => false;

  /// Whether it has opened unlocked, or tried to.
  bool get hasOpenedUnlocked;

  /// Unlocks on [stored] after this frame, once, when asked to. Call where
  /// the page first has the stored record.
  void openUnlockedOnce(T stored);

  /// Call from [onEditChanged]: tells [onOpenedSittingEnded] once.
  void noteOpenedSittingEnded();
}
```

  It overrides `didUpdateWidget` with the dive's rules as they stand: turned on again, it opens again; turned off with the sitting it opened clean and not busy, it locks.
- Consumes: `RecordEditHost.isCreating`, `shownRecord`, `editController`, `maybeEditController`, `sittingEndedByLeave`.

- [ ] **Step 1: Write the failing tests** in `record_edit_host_test.dart`, on the file's `_NotePage` harness given `openUnlocked` and `onSittingEnded`:
  - `opened unlocked, the page unlocks once`: pumps `_NotePage(openUnlocked: true)`; expects `RecordEditBar`; Cancel; expects no bar; a rebuild with the same widget stays locked.
  - `the end of the sitting it opened is told once`: `onSittingEnded` counter is 1 after Cancel, still 1 after a later unlock and Cancel.
  - `turned off with nothing changed, it locks`: pump `openUnlocked: true`, then `false`; expects no bar.
  - `a leave the app asked about is not told`: unlock opened, `appExitGuard.mayLeave()` with Discard; counter stays 0.
- [ ] **Step 2: Run them; they fail** (`openUnlocked` is not a parameter of the harness's page yet).
  Run: `flutter test test/shared/widgets/record_editing/record_edit_host_test.dart`
- [ ] **Step 3: Implement `RecordOpenUnlocked`** by moving `_DiveDetailPageUnlockOpen`'s bodies into it, renamed to the interface above. The dive mixin keeps only its overrides: `openUnlockedOf => w.openUnlocked`, `onOpenedSittingEnded => widget.onSittingEnded`, `handsUnlockElsewhere => _redirectingToPane`, `hasLeftForGood => _leftDeletedDive`, and `_noteSittingEnded` calling `noteOpenedSittingEnded()`. Give the harness page the mixin.
- [ ] **Step 4: Run the new tests and the three dive files; all pass, the dive files unchanged.**
- [ ] **Step 5: Commit** `refactor(record-editing): opening a page unlocked is shared`.

### Task 2: `RecordPaneRow` and the compact bar width, lifted out of the dive page

**Files:**
- Create: `lib/shared/widgets/record_editing/record_pane_row.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_embedded_header.dart` (its `Stack` of the locked row under `unlockedRow` becomes a `RecordPaneRow`), `lib/features/dive_log/presentation/pages/dive_detail_page_bars.dart` (`_kCompactAppBarWidth` becomes `kRecordCompactBarWidth`)
- Test: `test/shared/widgets/record_editing/record_pane_row_test.dart` (new); unchanged: `test/features/dive_log/presentation/pages/dive_detail_page_unlock_pane_test.dart`

**Interfaces:**
- Produces: `class RecordPaneRow extends StatelessWidget { const RecordPaneRow({super.key, required this.locked, this.unlocked}); }`. With `unlocked` null it is `locked`; otherwise `locked` keeps its size, invisible, with `unlocked` filling it. `const double kRecordCompactBarWidth = 600;`: below it a locked bar moves History into its menu.

- [ ] **Step 1: Write the failing tests**: `locked alone shows the locked row`; `unlocked lays its row over the locked one at the same height` (the `RecordPaneRow`'s size equals the locked row's, and the locked row's text is not hit-testable).
- [ ] **Step 2: Run them; they fail.** `flutter test test/shared/widgets/record_editing/record_pane_row_test.dart`
- [ ] **Step 3: Implement**, then move the dive's header and bar onto it.
- [ ] **Step 4: Run the new file and `dive_detail_page_unlock_pane_test.dart`; all pass.**
- [ ] **Step 5: Commit** `refactor(record-editing): the pane header's unlocked row is shared`.

### Task 3: The full page opens unlocked; History beside the lock; the edit route

**Files:**
- Create: `lib/features/dive_sites/presentation/pages/site_edit_routes.dart`, `lib/features/dive_sites/presentation/pages/site_detail_page_bars.dart` (part)
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page.dart` (`SiteDetailPage` and `_SiteDetailContent` gain `openUnlocked` and `onSittingEnded`; the state mixes in `RecordOpenUnlocked`; the desktop redirect keeps `&mode=edit`; the locked `AppBar` moves to the bars part), `lib/features/dive_sites/presentation/pages/site_detail_page_editing.dart` (`onEditChanged` calls `noteOpenedSittingEnded()`; `openUnlockedOnce(widget.site)` from `_editingInBuild`), `lib/core/router/app_router.dart` (`siteDetail`: `openUnlocked: state.uri.queryParameters['mode'] == 'edit'`; `editSite`: `redirect: siteEditRedirect`)
- Test: `test/features/dive_sites/presentation/pages/site_detail_page_unlock_test.dart` (existing; add cases), `test/core/router/app_router_test.dart` (existing; add a case)

**Interfaces:**
- Produces:
  - `SiteDetailPage({..., bool openUnlocked = false, VoidCallback? onSittingEnded})`.
  - `String? siteEditRedirect(BuildContext context, GoRouterState state, {bool unlockEditing = kUnlockSiteEditing})`: `/sites/<id>?mode=edit` when `unlockEditing` and `suggest` is not `'1'`; otherwise null, which keeps the form.
  - The full page's locked bar: History (`openChangeLogHistory(rootTable: 'dive_sites')`) as an icon beside the lock when the window is at least `kRecordCompactBarWidth` wide, else the menu's first item, as the dive's bar does. With the switch off the bar is as today.
- Consumes: Task 1's `RecordOpenUnlocked`, Task 2's `kRecordCompactBarWidth`.

- [ ] **Step 1: Write the failing tests**:
  - `opened with mode=edit, the page is unlocked`: `pumpSitePage(openUnlocked: true)` (add the parameter to the harness); `RecordEditBar` shows; Cancel; locked; the harness's `onSittingEnded` counter is 1.
  - `History sits beside the lock on a wide window and in the menu on a narrow one`: at 900 wide `find.byTooltip(l.changeLog_history)` finds one in the `AppBar`; at 400 wide none there, one in the opened menu.
  - In `app_router_test.dart`, `the site edit address opens the page unlocked with the switch on`: `siteEditRedirect` for `/sites/s1/edit` is `/sites/s1?mode=edit` with `unlockEditing: true`, null with it false, and null for `?suggest=1`.
  - `on desktop, mode=edit moves into the pane still asking to unlock` (Review Focus 3): with the master-detail redirect on, the address the page goes to is `/sites?selected=s1&mode=edit`, once.
- [ ] **Step 2: Run them; they fail.**
  `flutter test test/features/dive_sites/presentation/pages/site_detail_page_unlock_test.dart test/core/router/app_router_test.dart`
- [ ] **Step 3: Implement.** The desktop redirect follows the dive page's (`dive_detail_page.dart`, the `_redirectingToPane` block): set `handsUnlockElsewhere`, add `&mode=edit` when `openUnlocked && !hasOpenedUnlocked`.
- [ ] **Step 4: Run them; they pass.** Also run `test/features/dive_sites/presentation/pages/site_detail_page_test.dart` unchanged.
- [ ] **Step 5: Commit** `feat(sites): the site page opens unlocked from its edit address`.

### Task 4: Whole-record operations

**Files:**
- Create: `lib/features/dive_sites/presentation/pages/site_detail_page_operations.dart` (part)
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page.dart` (`_handleMenuAction` routes the operation actions through the new part; the owner and library items are built once for both headers), `site_detail_page_bars.dart`
- Test: `test/features/dive_sites/presentation/pages/site_detail_page_operations_test.dart` (new)

**Interfaces:**
- Produces, in `mixin _SiteDetailPageOperations on ConsumerState<_SiteDetailContent>, RecordEditHost<_SiteDetailContent, DiveSite>, _SiteDetailPageEditing`:
  - `RecordOperationBlock? get siteOperationBlock => recordOperationBlockOf(_offersEditingNow() ? editController : null)`: null, so every action acts as today, where the page offers no editing (the switch off, a library reader).
  - `Future<void> _runSiteOperation(Future<bool> Function() operation)`: through `recordOperationRunnerOf(editController, record: 'site $siteId')` while the page offers editing, else the operation directly.
  - `List<PopupMenuEntry<String>> _siteRecordMenuItems(BuildContext context, WidgetRef ref, DiveSite site)`: the caption (`recordOperationCaption(context, recordOperationReason(l10n, siteOperationBlock, plural: true))`), then Add to library and Delete from library (`_libraryMenuItems`, kept), then Delete, Unhide or Remove from profile, the rules of today's embedded menu (`canDestroySharedItemOnceKnown`, `watchHiddenHere`, `watchReachesHere`). Each item `enabled: siteOperationBlock == null || siteOperationBlock == RecordOperationBlock.none`. Both the full page's menu and the pane's use it: the full page gains Delete, Remove and Unhide.
  - Each of `delete`, `remove`, `unhide`, `addToLibrary`, `libraryDelete` runs through `_runSiteOperation`, its body answering whether it wrote (the confirmation dialogs stay). After a delete, a remove or a library delete, the page leaves as today (`context.go('/sites')` or `onDeleted`/`onClose`).
- Consumes: `runOperation` reads the site again after a write (`rereadStored`) and starts a fresh sitting on it, or locks when it is gone.

- [ ] **Step 1: Write the failing tests** (switch on, `pumpSitePage`):
  - `locked, the menu's record actions are disabled under "Unlock to use these"`: open the menu; `find.text(l.recordEdit_unlockToUseThese)` finds one; tapping Delete opens no dialog.
  - `unlocked with unsaved changes, they wait for Save or Cancel` (Review Focus 2): type in Notes, open the menu; `l.recordEdit_saveOrCancelFirst` shows; Delete is disabled; nothing deleted.
  - `unlocked with nothing to save, Delete asks, deletes and leaves`: confirm; the harness's fake delete is called once; the page has gone to `/sites`.
  - `the full page's menu offers Delete`: as owner, `find.text(l.diveSites_detail_deleteMenu_label)` in the full page's menu.
  - `Unhide while unlocked starts a fresh sitting on the site as stored`: the bar stays; the session is a new one.
  - `a library reader still removes the site from the profile` (Review Focus 4): reader role; the menu's Remove is enabled with the page locked, and runs.
  - `with the switch off the menu is as today`: no caption; Delete enabled.
- [ ] **Step 2: Run them; they fail.** `flutter test test/features/dive_sites/presentation/pages/site_detail_page_operations_test.dart`
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them, and `site_detail_page_test.dart` and `site_detail_page_unlock_test.dart`; all pass.**
- [ ] **Step 5: Commit** `feat(sites): delete, remove, unhide and the library actions are whole-record operations`.

### Task 5: The site list's pane hosts the sitting

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page_editing.dart` (`hostsEditing => widget.unlockEditing`, panes included), `site_detail_page.dart` (the embedded branch builds `editPane(header:, shown:, content:)` when hosting), `site_detail_page_bars.dart` (the pane header: `lockButton(site, compact: true)` when offered; its row is a `RecordPaneRow` whose `unlocked` is `editingPaneRow(widget.site, menu: <the pane's menu>)` while a sitting is open), `site_edit_routes.dart`, `lib/features/dive_sites/presentation/pages/site_list_page.dart` (both `editBuilder`s: `unlockedSitePane` when the switch is on)
- Test: `test/features/dive_sites/presentation/pages/site_detail_page_unlock_pane_test.dart` (new), `test/features/dive_sites/presentation/pages/site_detail_page_unlock_test.dart` (existing: `the pane offers no lock yet` becomes `the pane offers the lock`), `test/features/dive_sites/presentation/pages/site_list_page_test.dart` (existing; add a case)

**Interfaces:**
- Produces: `Widget unlockedSitePane(BuildContext context, String id, VoidCallback onCancel, {VoidCallback? onDeleted})` returning `SiteDetailPage(siteId: id, embedded: true, openUnlocked: true, onSittingEnded: onCancel, onDeleted: onDeleted)`, as `unlockedDivePane` does for dives.
- Consumes: Task 1, Task 2, Task 4's menu items.

- [ ] **Step 1: Write the failing tests**:
  - `the pane offers the lock and unlocks under the shared pane header`: `pumpSitePage(embedded: true)`; tap the lock; `RecordEditPaneHeader` shows with the site's editing title; the locked row is laid under it (`RecordPaneRow`).
  - `the pane's Save writes one sitting and locks`: Notes typed, Save; one save call; no pane header.
  - `the pane opened by mode=edit returns to view mode on Save or Cancel` (Review Focus 5): `unlockedSitePane` with an `onCancel` counter; Cancel; the counter is 1; the page is locked.
  - In `site_list_page_test.dart`, `with the switch on, mode=edit shows the site page unlocked, not the form`: `find.byType(SiteEditPage)` finds nothing; `RecordEditPaneHeader` shows.
  - `a locked pane offers no way to change the site`: no `RecordPencilIcon`, no `AddStrip`, no Media add button (`find.byTooltip(l.media_diveMediaSection_addTooltip)`), and the menu's record actions disabled under `l.recordEdit_unlockToUseThese`; the harness's save fake has no calls.
- [ ] **Step 2: Run them; they fail.**
  `flutter test test/features/dive_sites/presentation/pages/site_detail_page_unlock_pane_test.dart test/features/dive_sites/presentation/pages/site_detail_page_unlock_test.dart test/features/dive_sites/presentation/pages/site_list_page_test.dart`
- [ ] **Step 3: Implement.** The drop slot (`_tellDrop`) now registers from a pane too: a pane is a page that edits in place.
- [ ] **Step 4: Run them; they pass.**
- [ ] **Step 5: Commit** `feat(sites): the site list's pane holds the sitting`.

### Task 6: The site inside the dive list's pane

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page_bars.dart` (the pane's back arrow leaves through `_leaveThroughClose`), `site_detail_page_editing.dart`, `lib/features/dive_log/presentation/pages/dive_list_page.dart` (the `editBuilder`'s `site` branch: with the switch on, `SiteDetailPage(siteId:, embedded: true, openUnlocked: true, onClose:, onSittingEnded:, onDeleted:)` with today's three address rewrites, the form otherwise)
- Test: `test/features/dive_log/presentation/pages/dive_detail_page_unlock_pane_site_test.dart` (existing; add cases)

**Interfaces:**
- Produces: `Future<void> _leaveThroughClose()` in `_SiteDetailPageEditing`: with a sitting open, `sittingEndedByLeave = true`, then `cancelSitting(context, editController)`; on false, `sittingEndedByLeave = false` and stay; then `widget.onClose?.call()`. The pane's back arrow calls it in place of `widget.onClose`.

- [ ] **Step 1: Write the failing tests**:
  - `the site in the dive's pane offers the lock`: the dive list pane with `&site=s1`; the lock shows.
  - `its back arrow with unsaved changes asks first` (Review Focus 1): unlock, type Notes, tap back; the discard dialog shows; Keep editing leaves the site unlocked with "Choppy"; back again, Discard; the dive shows, nothing saved.
  - `its back arrow with nothing changed goes straight back`: unlock, back; the dive shows; no dialog.
  - `mode=edit there opens the site unlocked, and Cancel keeps the site in view`: the address keeps `site=s1` and drops `mode`.
  - `locked there, it offers no way to change the site`: as Task 5's locked-pane test, in the dive list's pane.
- [ ] **Step 2: Run them; they fail.**
  `flutter test test/features/dive_log/presentation/pages/dive_detail_page_unlock_pane_site_test.dart`
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them, and `embedded_site_navigation_test.dart` and `dive_list_page_test.dart` unchanged; all pass.**
- [ ] **Step 5: Commit** `feat(sites): the site in the dive list's pane holds the sitting`.

### Task 7: Finish

- [ ] `dart format` on every changed file; whole-repo `flutter analyze` is clean.
- [ ] Code review of the branch (`/code-review xhigh --fix --max-findings all`), every valid finding fixed test first.
- [ ] Screenshots, switch on, from headless widget-test goldens: the full page's bar with History beside the lock (wide) and in the menu (narrow); the site list's pane locked and unlocked; the site in the dive list's pane unlocked; the menu's operations under "Unlock to use these". Light and dark for the pane header.
- [ ] PR to `main` with `Refs #4527`, Auto-fix on.
