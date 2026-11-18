# Unified editing, sites, plan 1: the shared host Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lift the dive page's editing wiring into shared pieces (a page host, a pane header, a fold pencil and a sitting writer), move the dive page onto them with no change in behaviour, teach History to name a site's cards, and put the site page on the host with Description and Notes editable in place, behind a build switch that is off by default (issue #4527, phase 2).

**Architecture:** `RecordEditHost<W, T>` is a mixin on `ConsumerState<W>` holding what every record page needs: its `RecordEditController<T>`, the exit blocker, the shortcut target, following the stored record, the lock button, the full-page scaffold and the pane, and save-and-report. A record type supplies its cards, its save, its strip entries and its title through abstract members. `writeRecordSitting<T>` is the one transaction and one change log operation that every sitting's save runs in; `DiveEditSaveService` keeps its public signatures and moves onto it, and the new `SiteEditSaveService` uses it. The site page's content state mixes the host in when `kUnlockSiteEditing` is on, on the full page only, for a site the profile may edit.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), drift (SQLite), go_router 17, `flutter gen-l10n` (no new strings expected).

**Spec:** [docs/design/specs/2026-11-17-unified-editing-phase-2-sites-design.md](../specs/2026-11-17-unified-editing-phase-2-sites-design.md), on top of [the pattern](../specs/2026-11-14-unified-editing-pattern-design.md).

## Global Constraints

- With `kUnlockSiteEditing` false (the default), the site page looks and behaves exactly as it does today, and no existing site test changes its expectations.
- The dive page behaves exactly as it does today after it moves onto the host and the writer. `DiveEditSaveService.save` and `.create` keep their signatures and return types, so every fake that implements the service (`FakeSave` in `dive_detail_page_unlock_harness.dart` and others) compiles unchanged.
- The switch: `const bool kUnlockSiteEditing = bool.fromEnvironment('UNLOCK_SITE_EDITING');`, read through a widget parameter defaulting to it, as phase 1's `kUnlockEditing` was.
- A site sitting's History label is `record_edit:dive_sites:<siteId>:<cardIds>` (`RecordEditLabel.encode(table: 'dive_sites', ...)`), source `ChangeLogSource.manual`.
- Only what changed is written: the sitting's changes are applied to the site as stored at Save (`EditSession.applyTo`).
- Never use em-dashes or en-dashes as punctuation in code, comments, commits or the PR. Commits, the PR and files follow the repository guide's Attribution section.
- Imports grouped dart, flutter, packages, local. Run `dart format` on changed files before each commit.
- Test runs: only the test files a task writes or changes, by path, at most 15 per run. Never a folder, never the whole suite, never `test/architecture/` or tagged `test/shared/` guards by hand: the pre-push hook runs format, whole-repo analyze, the guards and the tests affected by the change, which include the dive page's unlock tests.
- Never `--build-filter` build_runner. Never open the live database from a debug build.

## Review Focus

1. **A site changed underneath a sitting** (a sync renames it while the diver edits its notes). Save keeps the new name and writes the notes. Pinned in Task 6.
2. **A site deleted while its sitting is open** (another device). Save fails, nothing is written, the page stays unlocked with the notes intact and says the save failed. Pinned in Task 1 (writer throws) and Task 8 (page reports).
3. **Notes typed and typed back.** The sitting is clean: Save is disabled and nothing is written. Pinned in Task 7.
4. **A library site this profile edits** (editor or owner). Save goes through `SiteRepository.updateSite` with the acting diver, so the library stamping and private-notes handling run as they do from the form. Pinned in Task 6.
5. **The diver hid the Notes card.** Unlocked, Notes is a dashed chip in the strip; tapping it shows the card open, and after Save the card is hidden again. Pinned in Task 8.

## Preparation

- [ ] The worktree is initialised (`git submodule update --init --recursive`, `flutter pub get`). Generate code, unfiltered, in the background: `dart run build_runner build --delete-conflicting-outputs`. Wait for it to finish.
- [ ] `git fetch origin main` and confirm the branch contains `c536fe0e944` (#4677): `git merge-base --is-ancestor c536fe0e944 HEAD`.
- [ ] Run `flutter analyze` on the whole repository and confirm it is clean.
- [ ] Commit the approved design note and this plan:

```bash
git add docs/design/specs/2026-11-17-unified-editing-phase-2-sites-design.md docs/design/plans/2026-11-17-unified-editing-sites-1-shared-host.md
git commit -m "docs(sites): unified editing phase 2 design note and plan 1"
```

## File Structure

New, shared:

| File | Responsibility |
| --- | --- |
| `lib/core/services/change_log/record_sitting_writer.dart` | `writeRecordSitting<T>`: one change log operation and one transaction around a sitting's read, apply, write and held writes |
| `lib/shared/widgets/record_editing/record_edit_pane_header.dart` | `RecordEditPaneHeader`, moved from the dive feature |
| `lib/shared/widgets/record_editing/record_fold_pencil.dart` | `RecordFoldPencil`: the dot and pencil on a folded section's header row |
| `lib/shared/widgets/record_editing/record_edit_host.dart` | `RecordEditHost<W, T>`: the page wiring every record page needs |

New, sites (`lib/features/dive_sites/...`):

| File | Responsibility |
| --- | --- |
| `presentation/editing/unlock_site_editing_flag.dart` | `kUnlockSiteEditing` |
| `presentation/editing/site_edit_fields.dart` | `siteDescriptionField`, `siteNotesField` |
| `presentation/editing/site_markdown_card_editor.dart` | `SiteMarkdownCardEditor`: one Markdown field of the site, bound to the sitting |
| `presentation/editing/site_edit_cards.dart` | `siteEditCards`: the site's `EditCard`s by section |
| `data/services/site_edit_save_service.dart` | `SiteEditSaveService.save` |
| `presentation/providers/site_edit_save_provider.dart` | `siteEditSaveServiceProvider` |
| `presentation/pages/site_detail_page_editing.dart` | `part of 'site_detail_page.dart'`: the site page's use of the host |

Modified:

| File | Change |
| --- | --- |
| `lib/features/dive_log/data/services/dive_edit_save_service.dart` | `save` and `create` run inside `writeRecordSitting` / `runRecordSitting` |
| `lib/features/dive_log/presentation/pages/dive_detail_page_editing.dart` | Shrinks to the dive's own parts on top of `RecordEditHost<DiveDetailPage, Dive>` |
| `lib/features/dive_log/presentation/pages/dive_detail_page*.dart` | Six reach-ins to the mixin's private fields use the host's public names |
| `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list.dart` | The fold row's pencil is `RecordFoldPencil` |
| `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_embedded_editing_header.dart` | Deleted (moved) |
| `lib/features/change_log/presentation/change_log_labels.dart` | Card names per table: `dive_sites` named through `SiteDetailSectionId` |
| `lib/features/dive_sites/presentation/pages/site_detail_page.dart` | `unlockEditing` parameter; the content state mixes in the host; Description and Notes headers become `RecordCardHeader` and are framed |
| `lib/features/dive_sites/presentation/widgets/site_detail_section_list.dart` | Shows a hidden card the sitting brought in; fold row pencil and unfold while open |
| `lib/core/router/app_router.dart` | `onExit: confirmLeaveRecordSitting` on `/sites` and `/sites/:siteId` |
| `test/architecture/markdown_notes_adoption_test.dart` | Lists the new Markdown card editor |

---

### Task 1: The shared sitting writer

**Files:**
- Create: `lib/core/services/change_log/record_sitting_writer.dart`
- Modify: `lib/features/dive_log/data/services/dive_edit_save_service.dart`
- Test: `test/core/services/change_log/record_sitting_writer_test.dart`

**Interfaces:**
- Produces:
  - `Future<R> runRecordSitting<R>({required String table, required String recordId, required Iterable<String> changedCardIds, required Future<R> Function() body})`: `ChangeLogScope.run(DatabaseService.instance.databaseOrNull, source: ChangeLogSource.manual, label: RecordEditLabel.encode(table: table, id: recordId, cardIds: changedCardIds), body: () => DatabaseService.instance.database.transaction(body))`.
  - `Future<({T before, T after})?> writeRecordSitting<T>({required String table, required String recordId, required Iterable<String> changedCardIds, required Future<T?> Function() read, required T Function(T stored) apply, required Future<void> Function(T stored, T merged) write, Future<void> Function()? writeFirst, Future<void> Function()? alsoWrite, bool alsoWriteIsAChange = false})`, inside `runRecordSitting`. The sequence is exactly the body of today's `DiveEditSaveService.save`: read (null throws `StateError('$table $recordId no longer exists')`), apply, and when `merged == stored` return null unless `alsoWriteIsAChange` and there is a held write, in which case run `writeFirst` then `alsoWrite` and return `(before: stored, after: stored)`; otherwise `writeFirst`, `write(stored, merged)`, `alsoWrite`, and return `(before: stored, after: merged)`.

- [ ] **Step 1: Write the failing tests.** A test database (`setUpTestDatabase()`, `addTearDown(SyncCoordinator.reset)`) with one `dive_sites` row `s1` named `Lake`. The record type is the site's name, read with `SELECT name FROM dive_sites WHERE id = ?` and written with `UPDATE dive_sites SET name = ? WHERE id = ?`. Settle the log with `ChangeLogRepository().settleAll()` before reading `change_log_operations`.
  - `one operation labelled with the record and its cards`: apply `(_) => 'Pond'`, cards `['notes', 'description']`; the name is `Pond`; exactly one operation, `source == 'manual'`, `label == 'record_edit:dive_sites:s1:description,notes'`; the result is `(before: 'Lake', after: 'Pond')`.
  - `nothing changed writes nothing`: apply returns the stored name; the result is null and no operation remains.
  - `a held change alone is written`: apply returns the stored name, `alsoWriteIsAChange: true`, `alsoWrite` writes `city = 'X'`; the city is `X` and the result is `(before: 'Lake', after: 'Lake')`.
  - `writeFirst runs before the record and alsoWrite after`: each callback appends to a list; the list is `['first', 'write', 'also']`.
  - `a failing held write rolls everything back`: `alsoWrite` throws; the call throws and the name is still `Lake`.
  - `a record that has gone throws`: `read` returns null; throws `StateError` whose message contains `dive_sites s1 no longer exists`.
- [ ] **Step 2:** Run `flutter test test/core/services/change_log/record_sitting_writer_test.dart`. Expected: fails to compile (`writeRecordSitting` not defined).
- [ ] **Step 3: Implement both functions** in `record_sitting_writer.dart` as the Interfaces block says. Top-level functions, with a doc comment that the scope goes outside the transaction it covers, as `ChangeLogScope` requires.
- [ ] **Step 4:** Run the test file. Expected: all pass.
- [ ] **Step 5: Move `DiveEditSaveService` onto it.** `save` becomes `writeRecordSitting<Dive>(table: 'dives', recordId: diveId, ...)` with `read: () => _diveRepo.getDiveById(diveId)`, and a `write` that calls `_diveRepo.updateDive(merged)` then the trip stretch (`diveSaveTouchesTrip`, `stretchToCoverDives`) into a local the method returns with the result; a null result stays null. `create` keeps its body and runs it through `runRecordSitting(table: 'dives', recordId: dive.id, ...)`. Signatures, return types and doc comments unchanged.
- [ ] **Step 6:** Run `flutter analyze lib/core/services/change_log lib/features/dive_log/data/services`. Expected: no issues. (The dive save service's own tests are not changed and run in the pre-push hook.)
- [ ] **Step 7: Commit**

```bash
git add lib/core/services/change_log/record_sitting_writer.dart lib/features/dive_log/data/services/dive_edit_save_service.dart test/core/services/change_log/record_sitting_writer_test.dart
git commit -m "refactor(editing): one shared writer for a sitting's transaction and History entry"
```

### Task 2: History names a site's cards

**Files:**
- Modify: `lib/features/change_log/presentation/change_log_labels.dart`
- Test: `test/features/change_log/presentation/change_log_labels_test.dart`

**Interfaces:**
- Produces: the private `_recordCardName(AppLocalizations l, String table, String cardId)` used by `_recordEditLabel` in place of its `dives`-only lookup: `dives` as today (sections, and `diveHeaderCardId` as `diveLog_detail_section_header`); `dive_sites` through `SiteDetailSectionId.values.asNameMap()` and `localizedDisplayName`; any other table, or an unknown id, as written.

- [ ] **Step 1: Write the failing tests** in the existing file, beside the `record_edit:dives:` cases:
  - `changeLogStoredLabel(l, 'record_edit:dive_sites:s1:description,notes')` equals `l.changeLog_label_recordEdit([SiteDetailSectionId.description.localizedDisplayName(l), SiteDetailSectionId.notes.localizedDisplayName(l)].join(l.changeLog_label_recordEditSeparator))`.
  - `record_edit:dive_sites:s1:notes,zzz` names Notes and shows `zzz` as written.
  - `record_edit:dives:notes` is unchanged (still the dive's Notes title).
- [ ] **Step 2:** Run `flutter test test/features/change_log/presentation/change_log_labels_test.dart`. Expected: the two site cases fail (ids shown raw).
- [ ] **Step 3:** Implement `_recordCardName` and use it in `_recordEditLabel`. Build each name map once at the top level, as `_diveSectionsByName` is.
- [ ] **Step 4:** Run the test file. Expected: all pass.
- [ ] **Step 5: Commit**

```bash
git add lib/features/change_log/presentation/change_log_labels.dart test/features/change_log/presentation/change_log_labels_test.dart
git commit -m "feat(history): name a site sitting's cards"
```

### Task 3: The pane header and the fold pencil become shared

**Files:**
- Create: `lib/shared/widgets/record_editing/record_edit_pane_header.dart` (moved with `git mv` from `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_embedded_editing_header.dart`)
- Create: `lib/shared/widgets/record_editing/record_fold_pencil.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page_editing.dart` (the one user of the header)
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list.dart` (`_foldSection`'s `trailing`)
- Test: `test/shared/widgets/record_editing/record_edit_pane_header_test.dart`, `test/shared/widgets/record_editing/record_fold_pencil_test.dart`

**Interfaces:**
- Produces:
  - `RecordEditPaneHeader({required String title, required bool canSave, required bool isSaving, required bool isBusy, required VoidCallback onCancel, required VoidCallback onSave, required Widget menu})`: the class renamed, its body and doc comment unchanged except "dive" becomes "record".
  - `RecordFoldPencil({required String title, required bool isChanged, required VoidCallback onOpen})`: the `Row` the dive's `_foldSection` builds today (a `RecordChangedDot` when changed, then the primary-coloured 18 px `Icons.edit_outlined` `IconButton` with tooltip `recordEdit_editCardTooltip(title)`).

- [ ] **Step 1: Write the failing tests.**
  - Pane header: Cancel and Save call back; Save is disabled when `canSave` is false, and when `isBusy`; Cancel is disabled while `isSaving`; the title and the `menu` widget are shown.
  - Fold pencil: the dot shows only when `isChanged`; tapping the pencil calls `onOpen`; the tooltip is `recordEdit_editCardTooltip('Notes')`.
- [ ] **Step 2:** Run both test files. Expected: compile failure.
- [ ] **Step 3:** `git mv` the header, rename the class, create `RecordFoldPencil`, and switch the dive page's two users to them.
- [ ] **Step 4:** Run both test files. Expected: pass. Run `flutter analyze lib/shared/widgets/record_editing lib/features/dive_log/presentation`. Expected: no issues.
- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/record_editing/record_edit_pane_header.dart lib/shared/widgets/record_editing/record_fold_pencil.dart lib/features/dive_log/presentation/pages/dive_detail_page_editing.dart lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list.dart test/shared/widgets/record_editing/record_edit_pane_header_test.dart test/shared/widgets/record_editing/record_fold_pencil_test.dart
git status --short   # the old header path must show as deleted and staged
git commit -m "refactor(editing): the pane's editing header and the fold pencil are shared"
```

### Task 4: `RecordEditHost`

**Files:**
- Create: `lib/shared/widgets/record_editing/record_edit_host.dart`
- Test: `test/shared/widgets/record_editing/record_edit_host_test.dart`

**Interfaces:**
- Consumes: `RecordEditPaneHeader` (Task 3); `RecordEditController`, `RecordEditScope`, `RecordEditBar`, `RecordEditLeaveGuard`, `cancelSitting`, `RecordSittingExitBlocker`, `recordSittingPageOf`, `AddStrip`, `AddStripLayout`, `RecordEditShortcutTarget(s)`, `appExitGuardProvider` (phase 1).
- Produces: `mixin RecordEditHost<W extends ConsumerStatefulWidget, T> on ConsumerState<W>`, with:
  - Supplied by the record page (abstract unless a default is given):
    - `String get hostRecordId` (the record the page shows) and `String recordIdOf(T record)`.
    - `bool get isCreating` (default false).
    - `Future<void> saveSitting(EditSession<T> session)`: the record's own write; throws when nothing could be written.
    - `Future<T?> rereadStored(ProviderContainer container, T stored)`: for `RecordEditController.reread`.
    - `Iterable<EditCard<T>> get hostEditCards`: asked for `invalidCards` in their order.
    - `void onSittingStart(EditSession<T> session, ProviderContainer container)` (default does nothing). The container, not the page's `ref`: a held write can run after the page has gone.
    - `bool get offersEditing` (default true): false on a page that offers no editing (the site page with the switch off, in the pane, or for a reader). While false, the shortcut target's `isCurrent` is false and its unlock does nothing, and the page never unlocks.
    - `T? get storedForUnlock`: the stored record the unlock key starts from, or null.
    - `String editingTitle(T record)`.
    - `List<AddStripEntry> addStripEntries(T working)`.
    - `Widget? belowStrip(T shown)` (default null): what is pinned under the strip while unlocked.
    - `bool get isShortcutTargetInView` (default true): narrows the shortcut target's `isCurrent` beyond "mounted and its route current".
    - `Future<void> saveNewRecord()` and `Future<void> cancelNewRecord()` (default `throw UnimplementedError()`): used in place of save and cancel while `isCreating`.
    - `String get operationLogName` (for example `'dive $diveId'`).
  - Provided:
    - `RecordEditController<T> get editController` (created on first use) and `RecordEditController<T>? get maybeEditController`.
    - `bool get isSittingOpen`.
    - `T shownRecord(T stored)`: the working copy, or the record just saved, when it is `stored`'s own; else `stored`.
    - `T? justSavedRecord` (read and write): set by `saveSitting` once its write commits.
    - `bool sittingEndedByLeave` (read and write): set while a leave the app asked about discards the sitting.
    - `void onEditChanged()`: called on every controller change; the default `setState`s when mounted. Overrides call `super`.
    - `void followStored(ProviderListenable<AsyncValue<T?>> provider)`: call from `build`; the listener the dive's `followStoredDive` is today (skip loading, skip null, clear `justSavedRecord`, only the sitting's own record).
    - `Widget lockButton(T shown, {bool compact = false})`.
    - `Widget editingPaneRow(T record, {required Widget menu})` using `RecordEditPaneHeader`.
    - `Widget editPane({required Widget header, required T shown, required Widget content})`.
    - `Widget editScaffold({required T record, required T shown, required PreferredSizeWidget lockedBar, required Widget content, List<Widget> unlockedActions = const []})`.
    - `Future<void> saveAndReport()` and `Future<void> cancelOrLeave()` (save and cancel as the bar, the pane header and the keys run them).
    - `initState` registers the shortcut target; `didUpdateWidget` clears `justSavedRecord` and locks when `hostRecordId` changed; `disposeEditing()` (called by the page's `dispose`) removes the target, disposes the exit blocker and the controller.
  - Behaviour is the dive mixin's today, member for member; the dive-only parts (the open-sitting slot, the flight warning, the embedded site) are not in it.

- [ ] **Step 1: Write the failing tests** with a fake record (`_Note(id, title, text)`, value equality), a `StateProvider<_Note?>` standing for the stored record, and a test page `_NotePage(noteId, {bool embedded = false})` whose state mixes in `RecordEditHost<_NotePage, _Note>`, has one card (`text`, an `EditField` on `text`, editor a `TextField` bound to it), records `saveSitting` calls and can fail on demand. Each test sets `appExitGuardProvider` and `recordEditShortcutTargetsProvider` through the `ProviderScope` it builds.
  - `locked shows the lock and no edit bar`.
  - `unlocking swaps the bar and titles it`: the `RecordEditBar` shows `editingTitle`.
  - `a change enables Save, and Save writes the sitting and locks`: `saveSitting` was called once with a session whose `changedCardIds` is `{'text'}`; the page is locked; the card shows the saved text before the provider is updated (`justSavedRecord`).
  - `a failed save stays unlocked and says so`: a `SnackBar` with `recordEdit_saveFailed`; still unlocked with the change.
  - `Back with changes asks, and discarding locks`: the discard dialog appears; after Discard the page is locked.
  - `a stored change follows into an untouched card`: change the provider's title while unlocked with a change to `text`; the shown title is the new one, the text change stays.
  - `another record locks the sitting`: rebuild with a different `noteId`; locked.
  - `while unlocked the app asks before leaving`: `appExitGuardProvider.mayLeave()` shows the discard dialog when dirty, and returns true at once when clean.
  - `the pane uses the pane header`: `embedded: true` builds `editPane` with `editingPaneRow`; unlocked, `RecordEditPaneHeader` is shown and no `RecordEditBar`.
  - `the strip lists what the page offers`: `addStripEntries` returning one entry shows one chip while unlocked and none while locked.
  - `the save key saves the page in view`: with the target registered, `recordEditShortcutTargetsProvider.current` is this page.
  - `a page that offers no editing takes no keys`: with `offersEditing` false, `recordEditShortcutTargetsProvider.current` is null, and the target's `unlock` leaves the page locked.
- [ ] **Step 2:** Run `flutter test test/shared/widgets/record_editing/record_edit_host_test.dart`. Expected: compile failure.
- [ ] **Step 3:** Implement the mixin by moving the generic members of `_DiveDetailPageEditing` (`dive_detail_page_editing.dart`) into it, renamed as the Interfaces block says, with `Dive` replaced by `T`, `diveProvider(...)` replaced by the supplied members, and `_addStripEntries`, the flight warning, the drop slot and the embedded-site checks left out. Keep each moved doc comment, reworded from the dive to the record.
- [ ] **Step 4:** Run the test file. Expected: all pass.
- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/record_editing/record_edit_host.dart test/shared/widgets/record_editing/record_edit_host_test.dart
git commit -m "feat(editing): RecordEditHost, the page wiring every record page shares"
```

### Task 5: The dive page moves onto the host

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page_editing.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (the `with` list; `dispose`; `followStoredDive()` call)
- Modify: `dive_detail_page_unlock_open.dart`, `dive_detail_page_creating.dart` (the reach-ins: `_editController`, `_endedByLeave`, `_justSaved`)
- Test: none new. The proof is the dive page's existing unlock and new-dive tests, unchanged, which the pre-push hook runs as affected tests.

**Interfaces:**
- Consumes: `RecordEditHost<DiveDetailPage, Dive>` (Task 4).
- Produces: `_DiveDetailPageEditing on ConsumerState<DiveDetailPage>, RecordEditHost<DiveDetailPage, Dive>` holding only: the drop slot (`openDiveSittingProvider`, `_tellOpenSitting`) in an `onEditChanged` override that also calls `_noteSittingEnded()`; `saveSitting` (today's `_saveSitting` body, setting `justSavedRecord`); `rereadStored` (`diveProvider`); `hostEditCards` (`diveEditCards.values`); `onSittingStart` (`startDiveSitting(session, container.read)`); `addStripEntries` (today's `_addStripEntries`); `belowStrip` (the `FlightWindowWarningBanner`); `isShortcutTargetInView` (the `embeddedSiteId` check); `editingTitle` (today's `_editingTitle`); `storedForUnlock` (`ref.read(diveProvider(diveId)).value`, through `shownRecord`); `operationLogName`; `didUpdateWidget` locking when the pane hands its place to a site; `saveNewRecord` and `cancelNewRecord` forwarding to `_saveNewDive` and `_cancelNewDive`; `followStoredDive()` as `followStored(diveProvider(diveId))`.
- `shownDive` goes: its four call sites (`dive_detail_page.dart`, `dive_detail_page_bars.dart`, `dive_detail_page_unlock_open.dart` and the editing mixin) call `shownRecord`.

- [ ] **Step 1:** Rewrite `_DiveDetailPageEditing` as the Interfaces block says, and add `RecordEditHost<DiveDetailPage, Dive>` to the state's `with` list before `_DiveDetailPageEditing`.
- [ ] **Step 2:** Replace the six reach-ins with `maybeEditController`, `sittingEndedByLeave` and `justSavedRecord`. `grep -n "_editController\|_endedByLeave\|_justSaved" lib/features/dive_log/presentation/pages/` prints nothing.
- [ ] **Step 3:** Run `flutter analyze lib/features/dive_log lib/shared/widgets/record_editing`. Expected: no issues.
- [ ] **Step 4:** Run `flutter test test/shared/widgets/record_editing/record_edit_host_test.dart`. Expected: pass. Do not run the dive page's tests by hand; they are unchanged and the hook runs them.
- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/pages/
git commit -m "refactor(dive-log): the dive page edits through RecordEditHost"
```

### Task 6: The site's save service

**Files:**
- Create: `lib/features/dive_sites/data/services/site_edit_save_service.dart`
- Create: `lib/features/dive_sites/presentation/providers/site_edit_save_provider.dart`
- Test: `test/features/dive_sites/data/services/site_edit_save_service_test.dart`

**Interfaces:**
- Consumes: `writeRecordSitting` (Task 1); `SiteRepository.getSiteById`, `SiteRepository.updateSite(site, {classification, actingDiverId})`.
- Produces:
  - `class SiteEditSaveService { SiteEditSaveService(SiteRepository sites); Future<({DiveSite before, DiveSite after})?> save({required String siteId, required DiveSite Function(DiveSite stored) apply, required Iterable<String> changedCardIds, String? actingDiverId, Future<void> Function()? writeFirst, Future<void> Function()? alsoWrite, bool alsoWriteIsAChange = false}) }`: `writeRecordSitting<DiveSite>(table: 'dive_sites', ...)`, writing with `updateSite(merged, actingDiverId: actingDiverId)` and no classification (types and tags are not cards yet).
  - `final siteEditSaveServiceProvider = Provider<SiteEditSaveService>((ref) => SiteEditSaveService(ref.watch(siteRepositoryProvider)));`

- [ ] **Step 1: Write the failing tests** (test database as Task 1; a diver `me` and a site `s1` named `Lake`, notes `Calm`, inserted through `SiteRepository.createSite`):
  - `writes the notes as one History entry`: apply sets notes `Choppy`, cards `['notes']`; stored notes are `Choppy`; one operation, label `record_edit:dive_sites:s1:notes`.
  - `a field the sitting did not touch keeps its newer value`: rename the stored site to `Pond` through the repository after taking `apply` from a session started on `Lake`, then save notes; the stored name is `Pond` and the notes are `Choppy`.
  - `unchanged returns null and writes nothing`.
  - `a site that has gone throws`: delete `s1`, then save; throws `StateError`; no operation remains.
  - `passes the acting diver to the repository`: a `SiteRepository` subclass that records `actingDiverId` from `updateSite`; it is `me`.
- [ ] **Step 2:** Run the test file. Expected: compile failure.
- [ ] **Step 3:** Implement the service and the provider.
- [ ] **Step 4:** Run the test file. Expected: all pass.
- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_sites/data/services/site_edit_save_service.dart lib/features/dive_sites/presentation/providers/site_edit_save_provider.dart test/features/dive_sites/data/services/site_edit_save_service_test.dart
git commit -m "feat(sites): save a site's editing sitting as one History entry"
```

### Task 7: The site's first cards: Description and Notes

**Files:**
- Create: `lib/features/dive_sites/presentation/editing/unlock_site_editing_flag.dart`
- Create: `lib/features/dive_sites/presentation/editing/site_edit_fields.dart`
- Create: `lib/features/dive_sites/presentation/editing/site_markdown_card_editor.dart`
- Create: `lib/features/dive_sites/presentation/editing/site_edit_cards.dart`
- Modify: `test/architecture/markdown_notes_adoption_test.dart` (add the editor to `editors` with the token `'MarkdownNotesField('`; do not run the guard by hand)
- Test: `test/features/dive_sites/presentation/editing/site_markdown_card_editor_test.dart`

**Interfaces:**
- Produces:
  - `const bool kUnlockSiteEditing = bool.fromEnvironment('UNLOCK_SITE_EDITING');`
  - `final siteDescriptionField = EditField<DiveSite, String>(id: 'description', cardId: SiteDetailSectionId.description.name, read: (s) => s.description, write: (s, v) => s.copyWith(description: v));` and `siteNotesField` the same for `notes`.
  - `class SiteMarkdownCardEditor extends StatefulWidget { const SiteMarkdownCardEditor({super.key, required EditSession<DiveSite> session, required EditField<DiveSite, String> field, String? placeholder}); }`: `DiveNotesCardEditor` without annotations: a `MarkdownNotesField` with `autofocus: true`, its controller following the sitting (`replaceTextKeepingCaret`) and `onChanged` writing `session.set(field, text)`.
  - `final Map<SiteDetailSectionId, EditCard<DiveSite>> siteEditCards`: `description` (title `diveSites_detail_section_description`, leading `Icons.description`, `isEmpty: (_) => false`, editor with placeholder `diveSites_edit_field_description_hint`) and `notes` (title `diveSites_detail_section_notes`, leading `Icons.notes`, `isEmpty: (_) => false`).

- [ ] **Step 1: Write the failing tests** for `SiteMarkdownCardEditor`, over a session started on a site with notes `Calm`:
  - `shows the sitting's value`: the field reads `Calm`.
  - `typing writes through`: enter `Calm sea`; `session.valueOf(siteNotesField)` is `Calm sea` and `changedCardIds` is `{'notes'}`.
  - `typing it back leaves the sitting clean`: enter `Calm sea`, then `Calm`; `session.isDirty` is false.
  - `follows a stored change it has not touched`: `session.rebase(site.copyWith(notes: 'Flat'))`; the field reads `Flat`.
- [ ] **Step 2:** Run the test file. Expected: compile failure.
- [ ] **Step 3:** Create the four files as the Interfaces block says, and add the guard entry.
- [ ] **Step 4:** Run the test file. Expected: all pass.
- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_sites/presentation/editing/ test/features/dive_sites/presentation/editing/site_markdown_card_editor_test.dart test/architecture/markdown_notes_adoption_test.dart
git commit -m "feat(sites): Description and Notes cards for in-place editing, behind a switch"
```

### Task 8: The site page on the host, behind the switch

**Files:**
- Create: `lib/features/dive_sites/presentation/pages/site_detail_page_editing.dart` (`part of 'site_detail_page.dart'`)
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page.dart`
- Modify: `lib/features/dive_sites/presentation/widgets/site_detail_section_list.dart`
- Modify: `lib/core/router/app_router.dart`
- Test: `test/features/dive_sites/presentation/pages/site_detail_page_unlock_harness.dart`, `test/features/dive_sites/presentation/pages/site_detail_page_unlock_test.dart`

**Interfaces:**
- Consumes: `RecordEditHost` (Task 4), `RecordFoldPencil` (Task 3), `siteEditSaveServiceProvider` (Task 6), `siteEditCards`, `kUnlockSiteEditing` (Task 7).
- Produces:
  - `SiteDetailPage({..., this.unlockEditing = kUnlockSiteEditing})`, passed to `_SiteDetailContent`. Editing is offered when `unlockEditing && !embedded && _canEditSite(ref, site)`. The pane and library readers come in later plans.
  - `mixin _SiteDetailPageEditing on ConsumerState<_SiteDetailContent>, RecordEditHost<_SiteDetailContent, DiveSite>`:
    - `hostRecordId` is `widget.siteId`; `recordIdOf` is `site.id`.
    - `saveSitting`: reads `siteEditSaveServiceProvider`, `siteListNotifierProvider.notifier` and the acting diver (`validatedCurrentDiverIdProvider.future`) before the write; calls `save(siteId: session.stored.id, apply: session.applyTo, changedCardIds: session.changedCardIds, actingDiverId: ...)`; sets `justSavedRecord` from the result; then refreshes the site list, guarded and logged, so a failed refresh does not read as a failed save.
    - `rereadStored`: invalidates and reads `siteProvider(stored.id)`.
    - `hostEditCards`: `siteEditCards.values`.
    - `storedForUnlock`: `ref.read(siteProvider(widget.siteId)).value`.
    - `editingTitle`: `l10n.recordEdit_editingTitle(site.name)`.
    - `addStripEntries`: for each section in `settings.siteDetailSections` with a card in `siteEditCards`, hidden by the diver, not open and not added: an `AddStripEntry(cardId, label: localizedDisplayName, hidden: true, changed: ...)`. (Description and Notes are never empty, so only hidden ones are offered.)
    - `operationLogName`: `'site ${widget.siteId}'`.
    - `offersEditing`: `widget.unlockEditing && !widget.embedded && _canEditSite(ref, widget.site)`, the library role read without watching (`_libraryAccess(ref, site, watch: false)`). `build` watches the same through `_canEditSite` to decide whether to show the lock.
  - In `_SiteDetailContentState.build`, when editing is offered: `followStored(siteProvider(widget.siteId))`; the cards and the header are built from `shownRecord(widget.site)`; the full page returns `editScaffold(record: site, shown: shown, lockedBar: <today's AppBar with lockButton(shown) before Edit>, content: body)`. Not offered: today's tree exactly.
  - `_buildDescriptionSection` and `_buildNotesSection` draw their title row with `RecordCardHeader(title: ..., leading: Icon(..., size: 20, color: colorScheme.primary))`, which locked is the same row as today. When editing is offered, `_sectionCards` wraps their builders in `RecordCardFrame<DiveSite>(card: siteEditCards[id]!, child: ...)`.
  - `_sectionCards` also builds a card the diver hid while the sitting has it open or added (`editController.addedCardIds`).
  - `SiteDetailSectionList({..., Set<SiteDetailSectionId> alsoShown = const {}})`: a section in `alsoShown` is shown though hidden. In the list layout it reads `RecordEditScope.maybeOf<DiveSite>(context)`: a section with a card in `siteEditCards` gets `RecordFoldPencil` as its fold row's `trailing` while unlocked and not open, opens with `controller.openCard`, and is unfolded while open without writing the fold setting.
  - `app_router.dart`: `onExit: confirmLeaveRecordSitting` on the `/sites` route and its `:siteId` route.

- [ ] **Step 1: Write the harness and the failing tests.** The harness pumps `SiteDetailPage(siteId: 's1', unlockEditing: true)` in a `ProviderScope` overriding `siteProvider('s1')` with a `StateProvider`-backed site (`Blue Hole`, description `Wall`, notes `Calm`, `diverId: 'me'`), `validatedCurrentDiverIdProvider` with `me`, `settingsProvider` with the default site sections, and `siteEditSaveServiceProvider` with a `FakeSiteSave implements SiteEditSaveService` that records calls and can fail. Phone width (600 by 900), sizes restored in `addTearDown`.
  - `with the switch off there is no lock`: `SiteDetailPage(siteId: 's1')`; no `Icons.lock_outline`; the Edit button is there; `recordEditShortcutTargetsProvider.current` is null.
  - `locked shows no pencil`: with the switch on, the lock is there and no `RecordPencilIcon`.
  - `unlocking titles the bar and marks Description and Notes`: `Editing Blue Hole`; two `RecordPencilIcon`s.
  - `editing Notes and saving writes one sitting and locks`: open Notes, type `Choppy`, Save; one call with cards `['notes']` and `apply(stored).notes == 'Choppy'`; locked; the Notes card reads `Choppy`.
  - `a failed save stays unlocked and says so`: the fake throws; `recordEdit_saveFailed` snack bar; still unlocked; Notes still `Choppy`.
  - `Cancel with changes asks first`.
  - `a rename underneath keeps the notes being edited`: unlocked with Notes changed, set the stored site's name to `Pond`; the header shows `Pond`; Save's `apply(stored)` keeps `Pond` and has notes `Choppy`.
  - `a hidden Notes card is offered in the strip, and hidden again after Save`: settings with Notes hidden; unlocked, one dashed chip `Notes`; tap it; the Notes card is open; type and Save; the Notes card is gone again.
  - `in the list layout the fold row has the pencil and opening unfolds it`: `siteDetailLayout` list, Notes folded; unlocked, the fold row shows `RecordFoldPencil`; tapping it shows the editor; the saved fold state is unchanged.
  - `the pane offers no lock yet`: `embedded: true`; no lock.
  - `a library site this profile only reads offers no lock`: a site with `sharedLibraryId` and the role overridden to reader; no lock.
- [ ] **Step 2:** Run `flutter test test/features/dive_sites/presentation/pages/site_detail_page_unlock_test.dart`. Expected: compile failure, then failures.
- [ ] **Step 3:** Implement as the Interfaces block says. `_buildDescriptionSection` and `_buildNotesSection` stay in `site_detail_page.dart`: the Markdown guard counts their `MarkdownNotesView` uses there.
- [ ] **Step 4:** Run the test file. Expected: all pass. Run `flutter analyze lib/features/dive_sites lib/core/router`. Expected: no issues.
- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_sites/presentation/pages/site_detail_page.dart lib/features/dive_sites/presentation/pages/site_detail_page_editing.dart lib/features/dive_sites/presentation/widgets/site_detail_section_list.dart lib/core/router/app_router.dart test/features/dive_sites/presentation/pages/site_detail_page_unlock_harness.dart test/features/dive_sites/presentation/pages/site_detail_page_unlock_test.dart
git commit -m "feat(sites): unlock a site page to edit Description and Notes in place, behind a switch"
```

### Task 9: Push and open the pull request

- [ ] **Step 1:** `dart format` on every changed Dart file; `flutter analyze` on the whole repository. Expected: clean.
- [ ] **Step 2:** Push in the background (`git push -u origin HEAD`), and touch no `lib/` or `test/` file while it runs: the hook tests the working tree. If the hook's affected tests fail (above all the dive page's unlock tests), fix the cause, commit the fix on its own, and push again.
- [ ] **Step 3:** Run `/code-review` with `--max-findings all`, fix every valid finding, and push again.
- [ ] **Step 4:** Screenshots of the site page with `--dart-define=UNLOCK_SITE_EDITING=true` on a database copy (`SUBMERSION_DB_PATH`): locked, unlocked, Notes open with a change, in light mode at phone and desktop widths; and the same page with the switch off as the "before". Capture through window control (never `flutter test ... -d macos`), and attach them through the project's current secret screenshot gist, as the contributing guide's screenshot section describes.
- [ ] **Step 5:** Open the PR with `gh pr create` from the repository's template: title `feat(sites): shared editing host, and Description and Notes edited in place behind a switch`; the body says `Refs #4527`, summarises the extraction (dive page unchanged) and the switch, and embeds the screenshots. Then bind it and turn Auto-fix on.
