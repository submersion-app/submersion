# Unified Editing, Plan 1: Skeleton Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the shared unlock-to-edit pieces and prove them on the dive page with two real cards, Notes and Tags, behind a compile-time switch that is off by default (issue #4527).

**Architecture:** A generic `EditSession<T>` holds the stored record and the diver's pending changes field by field; a `RecordEditController<T>` adds lock state, open cards and Save. Shared widgets (card header, card frame, edit bar, Add strip, leave guard) read the controller from an inherited scope. The dive page creates one controller, wraps Notes and Tags in frames inside `DiveDetailSectionList`, and saves through a new `DiveEditSaveService` that applies only the changed values to the dive as stored at Save, inside one transaction and one change log operation.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), drift (SQLite), go_router, `flutter gen-l10n`.

**Spec:** `docs/design/specs/2026-11-14-unified-editing-pattern-design.md`. Read "The rule", "Design: the pattern" and "The working copy" before starting.

This is plan 1 of nine for phase 1. The others, in order: header block, Details, Environment and Altitude cards; Tanks, Equipment and Weights cards; the remaining cards, fullscreen profile and dropped files; whole-record operations, menus, the list pane and shortcuts; new dive; change log extension; photo viewer lock; switch-over.

## Not in this plan

Later plans own these. Do not build them here.

- Validation on Save (first plan with a required field).
- Calculated and imported cards fading back.
- The embedded (list pane) header and the selection-change check in `MasterDetailScaffold`.
- Hiding today's write controls on a locked page (favourite, add photo and the rest). With the switch on, the lock button sits beside the existing Edit button.
- Whole-record operations, side-by-side pairs, a new dive, the annotation pin in the Notes editor.
- The History icon beside the lock.
- Asking before a tab switch ends a sitting. This plan covers the back button, and removes the previous and next dive controls while unlocked.

## Global Constraints

- With `kUnlockEditing` false (the default), the dive page builds and behaves exactly as it does today. No existing test changes its expectations.
- Unlocking moves and resizes nothing on the page.
- Save writes inside one database transaction and one change log operation, source `ChangeLogSource.manual`, labelled with the changed cards.
- Only values changed during the sitting are written, applied to the dive as stored at Save. If the same value changed in both places the diver's value wins.
- Cancel discards every change to the dive. A tag created from the tag input during the sitting remains.
- Every card title is drawn by `RecordCardHeader` in `textTheme.titleMedium`.
- `dive_detail_page.dart` is 748 lines and the file limit is 800: new page code goes in the part file `dive_detail_page_editing.dart`.
- Settings are read with `settingsProvider.select(...)`, never the whole `AppSettings`.
- Every new string is added to all 11 ARB files (`en es fr de it nl pt hu ar he zh`) with a real translation in each, then regenerated with `flutter gen-l10n`. ARB files are grouped by feature: insert beside a neighbouring key of the same group.
- No em-dash characters anywhere (code, comments, docs, commit messages). No emojis. No mention of any AI tool in code, commits or pull requests.
- Imports are `package:submersion/...` (`always_use_package_imports`), with trailing commas.
- Tests put back any global state they set: `tester.view` sizes via `addTearDown`, the test database via `tearDownTestDatabase()`.
- Before each commit: `dart format .`, `flutter analyze`, the affected test files, plus `flutter test test/architecture/ test/shared/` when files under `lib/` were added. Never the whole suite. Do not pipe `flutter test` into `grep` or `tail` to judge the result; the pipe hides the exit code.
- Commits follow the repository style, for example `feat(dive-log): ...`. Do not push or open a pull request; that waits for Eric.

## Review Focus

1. **The stored dive changes during a sitting** (a sync lands). A card the diver has not touched shows the new value; a changed field keeps the diver's value; Save does not write the untouched value back. Pinned in Task 2, Task 8, Task 9 and Task 11.
2. **Save fails** (the dive was deleted on another device, or the database throws). Nothing is written, the page stays unlocked with the changes and dots intact, and an error is shown. Pinned in Task 3, Task 8 and Task 11.
3. **A change typed and then typed back.** The sitting is not dirty, Save is disabled and no History entry is written. Pinned in Task 2.
4. **A card added from the strip and then abandoned.** Closed with nothing entered, it returns to the strip. Cancelled, it leaves no trace. A hidden card that was edited is hidden again after Save. Pinned in Task 3, Task 10 and Task 11.
5. **Leaving mid-sitting by a route the back button does not cover** (the previous and next dive buttons, the arrow-key shortcuts). They are unavailable while unlocked. Pinned in Task 11.

## Preparation

- [ ] Initialise the worktree, per the development guide's "Git Worktrees" section: `git submodule update --init --recursive`, then `flutter pub get`, then `dart run build_runner build --delete-conflicting-outputs` (unfiltered; never `--build-filter`).
- [ ] Bring the branch up to date: `git fetch origin main` then `git merge origin/main`. The branch is behind main, and main has PR #4478, which fixes #4477 by keeping unchanged dive-type rows on save. Task 8's History assertions depend on it.
- [ ] Run `flutter analyze` on the whole repository and confirm it is clean before changing anything.

## File Structure

New, shared (`lib/shared/widgets/record_editing/`):

| File | Responsibility |
| --- | --- |
| `unlock_editing_flag.dart` | `kUnlockEditing`, the compile-time switch |
| `edit_field.dart` | `EditField<T, V>`: one editable value of a record |
| `edit_session.dart` | `EditSession<T>`: stored record plus pending changes |
| `edit_card.dart` | `EditCard<T>`: what a record type supplies per card |
| `record_edit_controller.dart` | `RecordEditController<T>` and `RecordEditScope<T>` |
| `record_card_header.dart` | `RecordCardHeader` and `RecordCardFrameScope` |
| `record_card_frame.dart` | `RecordCardFrame<T>` |
| `record_edit_bar.dart` | `RecordEditBar`, the unlocked app bar |
| `add_strip.dart` | `AddStrip`, `AddStripEntry` |
| `record_edit_leave_guard.dart` | `RecordEditLeaveGuard<T>`, `cancelSitting` |

New, dive:

| File | Responsibility |
| --- | --- |
| `lib/core/services/change_log/record_edit_label.dart` | Encode and decode a sitting's History label |
| `lib/features/dive_log/data/services/dive_edit_save_service.dart` | Save a sitting: one transaction, one operation |
| `lib/features/dive_log/presentation/providers/dive_edit_save_provider.dart` | Provider for the service |
| `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart` | The dive's fields and card registry |
| `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_notes_card_editor.dart` | Notes editor |
| `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_tags_card_editor.dart` | Tags editor |
| `lib/features/dive_log/presentation/pages/dive_detail_page_editing.dart` | Part file: the page's editing mixin |

Modified: `tag_repository.dart`, `dive_providers.dart`, `change_log_labels.dart`, `dive_detail_text_sections.dart`, `dive_detail_section_list.dart`, `section_fold.dart`, `dive_detail_page.dart`, the 11 ARB files, `test/architecture/markdown_notes_adoption_test.dart`.

Tests mirror the source paths under `test/`.

---

### Task 1: Saving a dive's tags keeps the links that did not change

> **Outcome:** not needed. Main made this change in PR #4478 (commit 01564ec9bd8), with its own tests, before this plan was carried out. Nothing was changed for this task.

`TagRepository.setTagsForDive` deletes every `dive_tags` row for the dive and inserts new ones under fresh ids, on every dive save. A notes-only edit therefore shows every tag as removed and added in History and creates sync tombstones. Weights, gear and custom fields are already written as diffs for the same reason.

**Files:**
- Modify: `lib/features/tags/data/repositories/tag_repository.dart:591-655` (`setTagsForDive`)
- Test: `test/features/tags/data/repositories/tag_repository_test.dart` (new `group`; the file already defines `insertTestDive` and `insertTestTag`)

**Interfaces:**
- Produces: `Future<void> setTagsForDive(String diveId, List<domain.Tag> tags)`, same signature, now a diff.

- [ ] **Step 1: Write the failing tests**

Add `group('setTagsForDive keeps unchanged links', ...)`. Read link rows with `(db.select(db.diveTags)..where((t) => t.diveId.equals('d1'))).get()`.

```dart
test('an unchanged tag keeps its link row', () async {
  await insertTestDive(id: 'd1', diverId: 'diver1');
  await insertTestTag(id: 't1', name: 'sharks', diverId: 'diver1');
  await insertTestTag(id: 't2', name: 'drift', diverId: 'diver1');
  final t1 = (await repository.getTagById('t1'))!;
  final t2 = (await repository.getTagById('t2'))!;
  await repository.setTagsForDive('d1', [t1]);
  final before = await linkRows('d1');

  await repository.setTagsForDive('d1', [t1, t2]);

  final after = await linkRows('d1');
  expect(after, hasLength(2));
  expect(after.map((r) => r.id), contains(before.single.id));
});

test('a removed tag deletes only its own link row', ...);
// set [t1, t2], then [t2]: one row left, and it has the id t2's row had before.

test('the same tags again write nothing', ...);
// set [t1, t2], read dives.updatedAt, set [t2, t1] (other order):
// link row ids unchanged AND dives.updatedAt unchanged.

test('a tag listed twice is linked once', ...);
// set [t1, t1]: one row.
```

If `getTagById` is not the repository's name for reading one tag, use the name the file's existing tests use.

- [ ] **Step 2: Run them and confirm they fail**

Run: `flutter test test/features/tags/data/repositories/tag_repository_test.dart`
Expected: the first three new tests fail (row ids differ, `updatedAt` moved); the duplicate test passes already.

- [ ] **Step 3: Rewrite `setTagsForDive` as a diff**

Read the existing rows. Desired = the tag ids in `tags`, deduplicated. Delete rows whose `tagId` is not desired, calling `_syncRepository.logDeletion(entityType: 'diveTags', recordId: row.id)` for each. Insert a row with a fresh uuid for each desired id that has no row, calling `markRecordPending` as today. Bump `dives.updatedAt`, mark the dive pending and call `SyncEventBus.notifyLocalChange()` only when at least one row was deleted or inserted. Keep the logging and the `try`/`rethrow`.

- [ ] **Step 4: Run the tag tests and the callers' tests**

Run: `flutter test test/features/tags/`
Expected: PASS.
Run: `flutter test test/features/dive_log/data/repositories/` (the dive repository calls this on create and update).
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/tags/data/repositories/tag_repository.dart test/features/tags/data/repositories/tag_repository_test.dart
git commit -m "fix(tags): keep unchanged tag links when a dive's tags are saved"
```

---

### Task 2: `EditField` and `EditSession`

Pure Dart, no widgets, no Riverpod.

**Files:**
- Create: `lib/shared/widgets/record_editing/edit_field.dart`
- Create: `lib/shared/widgets/record_editing/edit_session.dart`
- Test: `test/shared/widgets/record_editing/edit_session_test.dart`

**Interfaces:**
- Produces:

```dart
@immutable
class EditField<T, V> {
  const EditField({
    required this.id,
    required this.cardId,
    required this.read,
    required this.write,
    this.equals,
  });
  final String id;       // unique within a record type, e.g. 'notes'
  final String cardId;   // the card that owns it
  final V Function(T record) read;
  final T Function(T record, V value) write;
  final bool Function(V a, V b)? equals; // null means ==
  bool same(V a, V b);
}

class EditSession<T> extends ChangeNotifier {
  EditSession(T stored);
  T get stored;
  T get working;                         // stored with every pending change applied
  bool get isDirty;
  Set<String> get changedCardIds;
  V valueOf<V>(EditField<T, V> field);   // pending value, else the stored one
  void set<V>(EditField<T, V> field, V value);
  void rebase(T stored);
  T applyTo(T fresh);
}
```

- [ ] **Step 1: Write the failing tests**

Use a small test record so the tests do not depend on `Dive`:

```dart
class _Rec {
  const _Rec({this.notes = '', this.tags = const [], this.depth = 0});
  final String notes; final List<String> tags; final int depth;
  _Rec copyWith({String? notes, List<String>? tags, int? depth}) => ...;
  // == and hashCode over all three (listEquals for tags)
}
final notes = EditField<_Rec, String>(id: 'notes', cardId: 'notes',
    read: (r) => r.notes, write: (r, v) => r.copyWith(notes: v));
final tags = EditField<_Rec, List<String>>(id: 'tags', cardId: 'tags',
    read: (r) => r.tags, write: (r, v) => r.copyWith(tags: v),
    equals: (a, b) => a.toSet().containsAll(b) && b.toSet().containsAll(a));
final depth = EditField<_Rec, int>(id: 'depth', cardId: 'details', ...);
```

Tests, one behaviour each:

```dart
test('a new session is clean and working equals stored', ...);
test('set changes working, marks dirty and names the card', () {
  final s = EditSession(const _Rec(notes: 'a'));
  s.set(notes, 'b');
  expect(s.working.notes, 'b');
  expect(s.isDirty, isTrue);
  expect(s.changedCardIds, {'notes'});
  expect(s.valueOf(notes), 'b');
});
test('setting a value back to the stored one clears the change', () {
  final s = EditSession(const _Rec(notes: 'a'))..set(notes, 'b')..set(notes, 'a');
  expect(s.isDirty, isFalse);
  expect(s.changedCardIds, isEmpty);
});
test('equals decides sameness: tags in another order are not a change', ...);
test('rebase: an untouched field follows the new stored record', () {
  final s = EditSession(const _Rec(notes: 'a', depth: 10))..set(notes, 'b');
  s.rebase(const _Rec(notes: 'a', depth: 25));
  expect(s.working.depth, 25);
  expect(s.working.notes, 'b');
});
test('rebase: a pending change equal to the new stored value is dropped', () {
  final s = EditSession(const _Rec(notes: 'a'))..set(notes, 'b');
  s.rebase(const _Rec(notes: 'b'));
  expect(s.isDirty, isFalse);
});
test('applyTo writes only the pending changes onto a fresh record', () {
  final s = EditSession(const _Rec(notes: 'a', depth: 10))..set(notes, 'b');
  final merged = s.applyTo(const _Rec(notes: 'a', depth: 99, tags: ['x']));
  expect(merged.notes, 'b');
  expect(merged.depth, 99);
  expect(merged.tags, ['x']);
});
test('listeners are told on a change and not on a no-op', ...);
// count notifications: set(notes,'b') -> 1; set(notes,'b') again -> still 1.
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/shared/widgets/record_editing/edit_session_test.dart`
Expected: FAIL, the files do not exist.

- [ ] **Step 3: Implement both classes**

Keep pending changes in an insertion-ordered map from field id to the field and its value. `working` and `applyTo` fold the pending writes over the base record. `set` removes the entry when `field.same(value, field.read(stored))`. `rebase` replaces `stored`, then drops entries that now equal it. Notify only when the set of pending changes, a pending value or `stored` actually changed.

- [ ] **Step 4: Run and confirm they pass**

Run: `flutter test test/shared/widgets/record_editing/edit_session_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/record_editing/edit_field.dart lib/shared/widgets/record_editing/edit_session.dart test/shared/widgets/record_editing/edit_session_test.dart
git commit -m "feat(shared): add the edit session that holds a record's pending changes"
```

---

### Task 3: `EditCard`, `RecordEditController`, `RecordEditScope`

**Files:**
- Create: `lib/shared/widgets/record_editing/edit_card.dart`
- Create: `lib/shared/widgets/record_editing/record_edit_controller.dart`
- Create: `lib/shared/widgets/record_editing/unlock_editing_flag.dart`
- Test: `test/shared/widgets/record_editing/record_edit_controller_test.dart`

**Interfaces:**
- Consumes: `EditSession<T>` (Task 2).
- Produces:

```dart
// unlock_editing_flag.dart
const bool kUnlockEditing = bool.fromEnvironment('UNLOCK_EDITING');

// edit_card.dart
@immutable
class EditCard<T> {
  const EditCard({
    required this.id,
    required this.title,
    required this.isEmpty,
    required this.editorBuilder,
  });
  final String id;
  final String Function(BuildContext context) title;
  final bool Function(T record) isEmpty;   // true: the page leaves the card out
  final Widget Function(BuildContext context, EditSession<T> session) editorBuilder;
}

// record_edit_controller.dart
typedef RecordSave<T> = Future<void> Function(EditSession<T> session);

class RecordEditController<T> extends ChangeNotifier {
  RecordEditController({required this.onSave});
  final RecordSave<T> onSave;
  bool get isUnlocked;
  EditSession<T>? get session;        // non-null exactly while unlocked
  bool get isDirty;                   // false while locked
  bool get isSaving;
  Object? get saveError;              // the last failed save; cleared by the next save and by lock
  Set<String> get openCardIds;
  Set<String> get addedCardIds;       // cards brought in from the Add strip this sitting
  void unlock(T stored);
  void lock();
  void openCard(String cardId);
  void closeCard(String cardId);
  void addCard(String cardId);        // adds and opens
  void storedChanged(T stored);       // rebases the session; ignored while locked or saving
  Future<bool> save();
}

class RecordEditScope<T> extends InheritedNotifier<RecordEditController<T>> {
  const RecordEditScope({super.key, required RecordEditController<T> controller, required super.child});
  static RecordEditController<T>? maybeOf<T>(BuildContext context);
}
```

- [ ] **Step 1: Write the failing tests**

Reuse the `_Rec` record and `notes` field from Task 2 (copy them into this file).

```dart
test('starts locked with no session', ...);
test('unlock creates a clean session; lock drops it with open and added cards', ...);
test('the controller notifies when the session changes', ...);
// unlock, listen, session.set(notes,'b') -> at least one notification, isDirty true.
test('addCard adds and opens; closing it unchanged removes it from added', () {
  final c = RecordEditController<_Rec>(onSave: (_) async {})..unlock(const _Rec());
  c.addCard('tags');
  expect(c.addedCardIds, {'tags'});
  expect(c.openCardIds, {'tags'});
  c.closeCard('tags');
  expect(c.addedCardIds, isEmpty);
});
test('closing an added card that has a change keeps it added', ...);
// addCard('notes'), session.set(notes,'x'), closeCard('notes') -> addedCardIds {'notes'}.
test('save calls onSave once, then locks', ...);
test('save while a save is running does nothing', () async {
  final gate = Completer<void>(); var calls = 0;
  final c = RecordEditController<_Rec>(onSave: (_) { calls++; return gate.future; })
    ..unlock(const _Rec())..session!.set(notes, 'b');
  final first = c.save(); final second = c.save();
  expect(c.isSaving, isTrue);
  gate.complete();
  expect(await first, isTrue); expect(await second, isFalse);
  expect(calls, 1);
});
test('a failed save stays unlocked, keeps the changes and records the error', () async {
  final c = RecordEditController<_Rec>(onSave: (_) async => throw StateError('gone'))
    ..unlock(const _Rec())..session!.set(notes, 'b');
  expect(await c.save(), isFalse);
  expect(c.isUnlocked, isTrue);
  expect(c.session!.valueOf(notes), 'b');
  expect(c.saveError, isA<StateError>());
  expect(c.isSaving, isFalse);
});
test('save with no changes locks without calling onSave', ...);
test('storedChanged rebases while unlocked and is ignored while locked', ...);
testWidgets('RecordEditScope.maybeOf returns the controller and rebuilds dependents', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/shared/widgets/record_editing/record_edit_controller_test.dart`
Expected: FAIL, the files do not exist.

- [ ] **Step 3: Implement**

The controller listens to its session and forwards notifications; it removes the listener and disposes the session in `lock` and in `dispose`.

- [ ] **Step 4: Run and confirm they pass**

Run: `flutter test test/shared/widgets/record_editing/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/record_editing/ test/shared/widgets/record_editing/record_edit_controller_test.dart
git commit -m "feat(shared): add the record edit controller and its scope"
```

---

### Task 4: Strings, card header and card frame

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and the ten other `app_*.arb` files, then the generated `app_localizations*.dart`
- Create: `lib/shared/widgets/record_editing/record_card_header.dart`
- Create: `lib/shared/widgets/record_editing/record_card_frame.dart`
- Test: `test/shared/widgets/record_editing/record_card_frame_test.dart`

**Interfaces:**
- Consumes: `EditCard<T>`, `RecordEditController<T>`, `RecordEditScope<T>` (Task 3).
- Produces:

```dart
// record_card_header.dart
@immutable
class RecordCardFrameData {
  const RecordCardFrameData({required this.isOpen, required this.isChanged,
      required this.onOpen, required this.onDone});
  final bool isOpen; final bool isChanged;
  final VoidCallback onOpen; final VoidCallback onDone;
}
class RecordCardFrameScope extends InheritedWidget {
  const RecordCardFrameScope({super.key, required this.data, required super.child});
  final RecordCardFrameData data;
  static RecordCardFrameData? maybeOf(BuildContext context);
}
class RecordCardHeader extends StatelessWidget {
  const RecordCardHeader({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;   // what the card shows at the right while reading
}

// record_card_frame.dart
class RecordCardFrame<T> extends StatelessWidget {
  const RecordCardFrame({super.key, required this.card, required this.child});
  final EditCard<T> card;
  final Widget child;       // the card's read widget
}
```

New strings (English value, then the description to store under `@key`). Put the `recordEdit_` keys after the last `forms_` key in each ARB file, and `changeLog_label_recordEdit*` beside the other `changeLog_label_` keys:

| Key | English | Description |
| --- | --- | --- |
| `recordEdit_unlockTooltip` | `Unlock to edit` | Tooltip of the lock button in a record page's top bar. |
| `recordEdit_editingTitle` | `Editing {name}` | Top bar title while a record is unlocked. `name` is the record's title, a String. |
| `recordEdit_editCardTooltip` | `Edit {card}` | Tooltip of the pencil on a card. `card` is the card's title, a String. |
| `recordEdit_unsavedChanges` | `Unsaved changes` | Spoken label of the dot on a card that has changes not yet saved. |
| `recordEdit_hiddenCard` | `{card}, hidden` | Spoken label of an Add strip chip for a card the diver has hidden. `card` is a String. |
| `recordEdit_saveFailed` | `Couldn't save your changes. Nothing was changed.` | Message shown when saving an unlocked record fails. |
| `changeLog_label_recordEdit` | `Edited: {cards}` | History label of one editing sitting. `cards` is a list of card titles already joined, a String. |
| `changeLog_label_recordEditSeparator` | `, ` | Separator between card titles in the line above. Copy each locale's value from `settings_conflict_fieldListSeparator`. |

Reuse existing keys for the rest: `forms_cancel`, `forms_save`, `common_action_done`, `common_action_add`.

- [ ] **Step 1: Add the strings to all 11 ARB files and regenerate**

Run: `flutter gen-l10n`
Then: `flutter test test/l10n/`
Expected: PASS (key parity, no untranslated values, no duplicate keys).

- [ ] **Step 2: Write the failing widget tests**

Pump with a real controller and a fake card:

```dart
final card = EditCard<_Rec>(
  id: 'notes',
  title: (_) => 'Notes',
  isEmpty: (_) => false,
  editorBuilder: (_, session) => const Text('EDITOR', key: ValueKey('editor')),
);
Widget host(RecordEditController<_Rec>? c) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: c == null ? frame : RecordEditScope<_Rec>(controller: c, child: frame)),
);
// frame = RecordCardFrame<_Rec>(card: card, child: Card(child: Column(children: [
//   RecordCardHeader(title: 'Notes', trailing: Text('3 tags')), Text('READ')])))
```

```dart
testWidgets('with no controller above it the card is unchanged', ...);
// finds 'READ' and '3 tags'; no pencil (find.byIcon(Icons.edit_outlined) nothing); no RecordCardFrameScope.
testWidgets('locked: the card is unchanged', ...);
testWidgets('unlocked: the header shows a pencil and keeps its trailing text', ...);
// find.byTooltip('Edit Notes') one; '3 tags' still found; 'READ' found.
testWidgets('unlocking does not change the card height', (tester) async {
  // pump locked, read tester.getSize(find.byType(Card)); controller.unlock; pump; same size.
});
testWidgets('tapping the header opens the editor in place', ...);
// tap find.text('Notes'); pump -> ValueKey('editor') found, 'READ' not found,
// find.text('Done') found, controller.openCardIds == {'notes'}.
testWidgets('Done closes the card back to its read layout', ...);
testWidgets('a changed card shows the dot open and closed', ...);
// session.set(notes,'b'); find.bySemanticsLabel('Unsaved changes') one, in both states.
testWidgets('an open card has the accent outline', ...);
// the open Card's shape is a RoundedRectangleBorder whose side.color is colorScheme.primary and width 2.
```

- [ ] **Step 3: Run and confirm they fail**

Run: `flutter test test/shared/widgets/record_editing/record_card_frame_test.dart`
Expected: FAIL.

- [ ] **Step 4: Implement the header and the frame**

`RecordCardHeader` with no `RecordCardFrameScope` above it draws `Row(mainAxisAlignment: spaceBetween)` of the title in `textTheme.titleMedium` and `trailing`, which is what the Tags card draws today. Inside a scope: the dot (8 px circle, `StatusColors.of(context).warn.accent`, wrapped in `Semantics(label: l10n.recordEdit_unsavedChanges)`) follows the title when `isChanged`; when closed the pencil (`Icons.edit_outlined`, `colorScheme.primary`, tooltip `recordEdit_editCardTooltip(title)`) follows `trailing` and the whole row is an `InkWell` calling `onOpen`; when open `trailing` is not drawn and a `TextButton` labelled `common_action_done` calls `onDone`. The pencil must not make the row taller than the title alone: give it `visualDensity: VisualDensity.compact` and zero padding and check the height test.

`RecordCardFrame<T>`: with no controller in scope, or locked, return `child` untouched. Unlocked and closed: `RecordCardFrameScope` around `child`. Open: a `Card` with the accent outline, `Padding(16)`, a `Column` of `RecordCardHeader(title: card.title(context))` inside the scope, `Divider()`, and `card.editorBuilder(context, controller.session!)`.

- [ ] **Step 5: Run and confirm they pass**

Run: `flutter test test/shared/widgets/record_editing/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/arb lib/shared/widgets/record_editing test/shared/widgets/record_editing/record_card_frame_test.dart
git commit -m "feat(shared): add the record card header and frame"
```

---

### Task 5: Edit bar, Add strip and leave guard

**Files:**
- Create: `lib/shared/widgets/record_editing/record_edit_bar.dart`
- Create: `lib/shared/widgets/record_editing/add_strip.dart`
- Create: `lib/shared/widgets/record_editing/record_edit_leave_guard.dart`
- Test: `test/shared/widgets/record_editing/record_edit_bar_test.dart`
- Test: `test/shared/widgets/record_editing/add_strip_test.dart`
- Test: `test/shared/widgets/record_editing/record_edit_leave_guard_test.dart`

**Interfaces:**
- Consumes: `RecordEditController<T>` (Task 3); `showDiscardDialog` (`lib/shared/widgets/forms/discard_dialog.dart`); `AppBarTextAction` (`lib/shared/widgets/app_bar_text_action.dart`).
- Produces:

```dart
class RecordEditBar extends StatelessWidget implements PreferredSizeWidget {
  const RecordEditBar({super.key, required this.title, required this.canSave,
      required this.isSaving, required this.onCancel, required this.onSave});
  final String title; final bool canSave; final bool isSaving;
  final VoidCallback onCancel; final VoidCallback onSave;
}

@immutable
class AddStripEntry {
  const AddStripEntry({required this.cardId, required this.label, this.hidden = false});
  final String cardId; final String label; final bool hidden;
}
class AddStrip extends StatelessWidget {
  const AddStrip({super.key, required this.entries, required this.onAdd});
  final List<AddStripEntry> entries; final ValueChanged<String> onAdd;
}

/// Locks the record, asking first when it has unsaved changes. False means the diver kept editing.
Future<bool> cancelSitting<T>(BuildContext context, RecordEditController<T> controller);

class RecordEditLeaveGuard<T> extends StatelessWidget {
  const RecordEditLeaveGuard({super.key, required this.controller, required this.child});
  final RecordEditController<T> controller; final Widget child;
}
```

- [ ] **Step 1: Write the failing tests**

```dart
// record_edit_bar_test.dart
testWidgets('shows Cancel, the title and Save', ...);
testWidgets('Save is disabled when canSave is false', ...);
// tap 'Save' -> onSave not called.
testWidgets('Save and Cancel call back', ...);
testWidgets('Save is busy and inert while saving', ...);
testWidgets('there is no back arrow', ...);  // find.byType(BackButton) nothing
testWidgets('the bar background is opaque', ...);
// tester.widget<AppBar>(...).backgroundColor!.a == 1.0, in ThemeData.light() and ThemeData.dark().

// add_strip_test.dart
testWidgets('renders nothing for no entries', ...);
// tester.getSize(find.byType(AddStrip)).height == 0
testWidgets('one chip per entry, in order, and a tap reports its card id', ...);
// keys ValueKey('addStrip_tags'); tap -> onAdd('tags').
testWidgets('a hidden entry is announced as hidden', ...);
// find.bySemanticsLabel('Buddies, hidden') one.
testWidgets('the strip scrolls sideways instead of wrapping', ...);
// 12 entries at 320 px wide: no overflow exception, one row (all chips share a dy).

// record_edit_leave_guard_test.dart: a two-route Navigator; the second route is the guarded page.
testWidgets('locked: back pops', ...);
testWidgets('unlocked with no changes: back pops and locks', ...);
testWidgets('unlocked with changes: back asks; Keep editing stays', ...);
testWidgets('unlocked with changes: back asks; Discard pops and locks', ...);
testWidgets('cancelSitting with changes asks, and Discard locks', ...);
testWidgets('cancelSitting with no changes locks at once', ...);
```

The dialog's button texts are `forms_discard_keepEditing` and `forms_discard_discard`; read them through `AppLocalizations` in the test, do not hard-code English.

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/shared/widgets/record_editing/`
Expected: the three new files FAIL.

- [ ] **Step 3: Implement**

`RecordEditBar`: an `AppBar` with `automaticallyImplyLeading: false`, `leadingWidth` wide enough for the word, `leading: AppBarTextAction(label: l10n.forms_cancel, onPressed: isSaving ? null : onCancel)`, `title: Text(title)`, `actions: [AppBarTextAction(label: l10n.forms_save, onPressed: canSave && !isSaving ? onSave : null, busy: isSaving)]`. Background: `Color.alphaBlend(colorScheme.primary.withValues(alpha: 0.14), colorScheme.surface)`. A 2 px `colorScheme.primary` line along the bottom.

`AddStrip`: `SizedBox.shrink()` for no entries. Otherwise a horizontally scrolling row on `colorScheme.surface` with a bottom hairline: the word `common_action_add` in `labelMedium`, then an `ActionChip` per entry keyed `ValueKey('addStrip_${entry.cardId}')`. A hidden entry draws a dashed outline (a small `CustomPainter` over the chip's rounded rectangle) and is wrapped in `Semantics(label: l10n.recordEdit_hiddenCard(entry.label))`.

`RecordEditLeaveGuard`: a `ListenableBuilder` on the controller around `PopScope(canPop: !controller.isDirty, onPopInvokedWithResult: ...)`. When the pop was refused it calls `cancelSitting` and, if that returned true, pops. When the pop went through and the controller is unlocked, it locks.

- [ ] **Step 4: Run and confirm they pass**

Run: `flutter test test/shared/widgets/record_editing/` then `flutter test test/architecture/ test/shared/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/record_editing test/shared/widgets/record_editing
git commit -m "feat(shared): add the edit bar, the Add strip and the leave guard"
```

---

### Task 6: A sitting's History label

**Files:**
- Create: `lib/core/services/change_log/record_edit_label.dart`
- Modify: `lib/features/change_log/presentation/change_log_labels.dart:36-63` (`changeLogStoredLabel`)
- Test: `test/core/services/change_log/record_edit_label_test.dart`
- Test: `test/features/change_log/presentation/change_log_labels_test.dart` (exists; add to it)

**Interfaces:**
- Produces:

```dart
abstract final class RecordEditLabel {
  /// 'record_edit:dives:notes,tags'. Card ids are sorted so the label is stable.
  static String encode({required String table, required Iterable<String> cardIds});
  /// Null for any label this class did not write.
  static ({String table, List<String> cardIds})? decode(String label);
}
```

- [ ] **Step 1: Write the failing tests**

```dart
test('encode sorts the card ids', () {
  expect(RecordEditLabel.encode(table: 'dives', cardIds: ['tags', 'notes']),
      'record_edit:dives:notes,tags');
});
test('decode reverses encode', ...);
test('decode returns null for other labels', () {
  expect(RecordEditLabel.decode('bulk_edit'), isNull);
  expect(RecordEditLabel.decode('Perdix 2'), isNull);
  expect(RecordEditLabel.decode('record_edit:dives'), isNull);
});

// change_log_labels_test.dart, with AppLocalizations for 'en' (lookupAppLocalizations(const Locale('en')))
test('a dive sitting is shown as Edited: with the card titles', () {
  final label = RecordEditLabel.encode(table: 'dives', cardIds: ['notes', 'tags']);
  expect(changeLogStoredLabel(l, label), 'Edited: Notes, Tags');
});
test('an unknown card id is shown as written', ...);
// 'record_edit:dives:notes,zzz' -> 'Edited: Notes, zzz'
test('a known stored label still translates', ...);
// ChangeLogLabels.bulkEdit -> l.changeLog_label_bulkEdit
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/core/services/change_log/record_edit_label_test.dart test/features/change_log/presentation/change_log_labels_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

In `changeLogStoredLabel`, decode first. For table `'dives'` map each id through `DiveDetailSectionId.values.asNameMap()[id]?.localizedDisplayName(l) ?? id` (`lib/core/constants/dive_detail_sections.dart:166`), join with `l.changeLog_label_recordEditSeparator`, and return `l.changeLog_label_recordEdit(joined)`. Any other table shows the ids as written.

- [ ] **Step 4: Run and confirm they pass**

Run: the same command as Step 2.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/change_log/record_edit_label.dart lib/features/change_log/presentation/change_log_labels.dart test/core/services/change_log/record_edit_label_test.dart test/features/change_log/presentation/change_log_labels_test.dart
git commit -m "feat(change-log): label an editing sitting with the cards it changed"
```

---

### Task 7: The dive list refreshes after a write made elsewhere

`PaginatedDiveListNotifier.updateDive` both writes and refreshes. The save service writes inside its own transaction, so it needs the refresh alone.

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/dive_providers.dart:1385-1409`
- Test: `test/features/dive_log/presentation/providers/dive_providers_test.dart` (add a test beside the existing `updateDive` ones)

**Interfaces:**
- Produces, on `PaginatedDiveListNotifier`:

```dart
/// Refreshes the list and every provider that depends on a dive, after
/// [after] was written by something other than [updateDive].
Future<void> refreshAfterWrite({required domain.Dive? before, required domain.Dive after});
```

- [ ] **Step 1: Write the failing test**

Follow the setup the file's existing `updateDive` test uses. Load the first page, write a changed dive straight through the repository, call `refreshAfterWrite(before: old, after: changed)`, and expect the list's summary for that id to show the changed value and `diveProvider(id)` to return the changed dive.

- [ ] **Step 2: Run and confirm it fails**

Run: `flutter test test/features/dive_log/presentation/providers/dive_providers_test.dart`
Expected: FAIL, `refreshAfterWrite` is not defined.

- [ ] **Step 3: Extract the method**

Move everything in `updateDive` after `await _repository.updateDive(dive);` into `refreshAfterWrite`, with `oldDive` as `before` and `dive` as `after`. `updateDive` becomes: read the old dive, write, `await refreshAfterWrite(before: oldDive, after: dive)`.

- [ ] **Step 4: Run and confirm it passes**

Run: `flutter test test/features/dive_log/presentation/providers/`
Expected: PASS, including every existing test.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/providers/dive_providers.dart test/features/dive_log/presentation/providers/dive_providers_test.dart
git commit -m "refactor(dive-log): split the list refresh out of updateDive"
```

---

### Task 8: `DiveEditSaveService`

**Files:**
- Create: `lib/features/dive_log/data/services/dive_edit_save_service.dart`
- Create: `lib/features/dive_log/presentation/providers/dive_edit_save_provider.dart`
- Test: `test/features/dive_log/data/services/dive_edit_save_service_test.dart`

**Interfaces:**
- Consumes: `DiveRepository.getDiveById`, `DiveRepository.updateDive` (`dive_repository_impl.dart:978`, `:2697`); `ChangeLogScope.run` (`lib/core/services/change_log/change_log_scope.dart:78`); `RecordEditLabel.encode` (Task 6); `DatabaseService.instance.database` and `.databaseOrNull`.
- Produces:

```dart
class DiveEditSaveService {
  DiveEditSaveService(this._diveRepo);
  /// Applies [apply] to the dive as stored now and writes the result.
  /// Returns the dive before and after, or null when [apply] changed nothing.
  /// Throws [StateError] when the dive no longer exists.
  Future<({Dive before, Dive after})?> save({
    required String diveId,
    required Dive Function(Dive stored) apply,
    required Iterable<String> changedCardIds,
  });
}

final diveEditSaveServiceProvider = Provider<DiveEditSaveService>(
  (ref) => DiveEditSaveService(ref.watch(diveRepositoryProvider)),
);
```

- [ ] **Step 1: Write the failing tests**

Database tests: `setUpTestDatabase()` in `setUp`, `tearDownTestDatabase()` in `tearDown` (`test/helpers/test_database.dart`). Change log helpers come from `test/core/database/change_log/change_log_support.dart` (`logEvents`, `logFields`, `clearLog`, `insertDiver`). Settle with `ChangeLogRepository().settleAll()` before reading operations. Configure the clock as `change_log_revert_edit_test.dart:23-35` does.

Build the fixture through the repository so it is a real, rich dive: `await DiveRepository().createDive(Dive(...))` with notes `'Calm'`, two tags, one tank, one weight, one piece of gear, one dive type and one custom field. Then `settleAll()` and `clearLog(db)`.

```dart
test('a notes-only save records exactly one changed field', () async {
  final result = await service.save(
    diveId: dive.id,
    apply: (stored) => stored.copyWith(notes: 'Current'),
    changedCardIds: ['notes'],
  );
  expect(result!.before.notes, 'Calm');
  expect(result.after.notes, 'Current');

  final events = await logEvents(db);
  expect(events, hasLength(1));
  expect(events.single['table_name'], 'dives');
  expect(await logFields(db, events.single['id']! as int), {'notes': ('Calm', 'Current')});
});
```

If that test finds more than one event, the extra `table_name` values name a writer in `updateDive` that is not a diff. Stop and report it; do not loosen the assertion. Use the column names `logEvents` actually returns.

```dart
test('one sitting is one operation, labelled with its cards', () async {
  await service.save(diveId: dive.id,
      apply: (s) => s.copyWith(notes: 'Current', tags: [s.tags.first]),
      changedCardIds: ['tags', 'notes']);
  await ChangeLogRepository().settleAll();
  final op = (await operations(db)).single;
  expect(op.source, ChangeLogSource.manual.name);
  expect(op.label, 'record_edit:dives:notes,tags');
});

test('changes are applied to the dive as stored at save time', () async {
  // Something else changes the stored dive after the sitting began.
  await DiveRepository().updateDive(dive.copyWith(rating: 5));
  await service.save(diveId: dive.id,
      apply: (stored) => stored.copyWith(notes: 'Current'), changedCardIds: ['notes']);
  final saved = (await DiveRepository().getDiveById(dive.id))!;
  expect(saved.notes, 'Current');
  expect(saved.rating, 5);
});

test('apply that changes nothing writes nothing and returns null', () async {
  expect(await service.save(diveId: dive.id, apply: (s) => s, changedCardIds: []), isNull);
  expect(await logEvents(db), isEmpty);
});

test('a dive that no longer exists throws and writes nothing', () async {
  await DiveRepository().deleteDive(dive.id);
  await clearLog(db);
  await expectLater(
    service.save(diveId: dive.id, apply: (s) => s.copyWith(notes: 'x'), changedCardIds: ['notes']),
    throwsStateError);
  expect(await logEvents(db), isEmpty);
});

test('a write the repository rejects leaves the dive unchanged', () async {
  // updateDive throws ArgumentError for a tank with an empty id (dive_repository_impl.dart:2701-2713).
  await expectLater(
    service.save(diveId: dive.id,
        apply: (s) => s.copyWith(notes: 'Current', tanks: [s.tanks.first.copyWith(id: '')]),
        changedCardIds: ['notes']),
    throwsArgumentError);
  expect((await DiveRepository().getDiveById(dive.id))!.notes, 'Calm');
  expect(await logEvents(db), isEmpty);
});

test('reverting the operation restores the old values', () async {
  await service.save(diveId: dive.id,
      apply: (s) => s.copyWith(notes: 'Current', tags: []), changedCardIds: ['notes', 'tags']);
  await ChangeLogRepository().settleAll();
  // Revert through ChangeLogRevertService the way change_log_revert_edit_test.dart does.
  final reverted = (await DiveRepository().getDiveById(dive.id))!;
  expect(reverted.notes, 'Calm');
  expect(reverted.tags.map((t) => t.id).toSet(), dive.tags.map((t) => t.id).toSet());
});
```

`dive` in these tests is the dive read back with `getDiveById` after `createDive`, so it carries everything the repository stores. `operations(db)` is a local helper copied from `change_log_settler_test.dart:11`; the operation's `source` column holds `ChangeLogSource.manual.name`.

In this plan the transaction holds one read and one `updateDive`, which is already atomic on its own, so there is nothing after the write that could fail and be rolled back. The first later plan that adds a write after `updateDive` adds the test that a failure there undoes the dive write too.

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/data/services/dive_edit_save_service_test.dart`
Expected: FAIL, the service does not exist.

- [ ] **Step 3: Implement**

The change log scope goes outside and the transaction inside, as `bulk_dive_edit_service.dart:44-160` does and as the scope's own doc comment requires:

```dart
Future<({Dive before, Dive after})?> save({...}) {
  return ChangeLogScope.run(
    DatabaseService.instance.databaseOrNull,
    source: ChangeLogSource.manual,
    label: RecordEditLabel.encode(table: 'dives', cardIds: changedCardIds),
    body: () => _db.transaction(() async {
      final stored = await _diveRepo.getDiveById(diveId);
      if (stored == null) throw StateError('Dive $diveId no longer exists');
      final merged = apply(stored);
      if (merged == stored) return null;
      await _diveRepo.updateDive(merged);
      return (before: stored, after: merged);
    }),
  );
}
```

`_db` is `DatabaseService.instance.database`, the convention every repository and service here uses. An operation left with no events is removed by the settler (`change_log_settler.dart:638`), so the early `return null` leaves nothing behind.

- [ ] **Step 4: Run and confirm they pass**

Run: `flutter test test/features/dive_log/data/services/dive_edit_save_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/data/services/dive_edit_save_service.dart lib/features/dive_log/presentation/providers/dive_edit_save_provider.dart test/features/dive_log/data/services/dive_edit_save_service_test.dart
git commit -m "feat(dive-log): save an editing sitting in one transaction and one History entry"
```

---

### Task 9: The dive's Notes and Tags cards

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart`
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_notes_card_editor.dart`
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_tags_card_editor.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_text_sections.dart:13-112` (the two title rows)
- Modify: `test/architecture/markdown_notes_adoption_test.dart` (the `editors` map)
- Test: `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards_test.dart`

**Interfaces:**
- Consumes: `EditField`, `EditSession`, `EditCard` (Tasks 2 and 3); `RecordCardHeader` (Task 4); `MarkdownNotesField` (`lib/shared/widgets/markdown_notes/markdown_notes_field.dart:18`); `TagFormBlock` (`lib/features/tags/presentation/widgets/tag_form_block.dart:13`).
- Produces:

```dart
// dive_edit_cards.dart
final EditField<Dive, String> diveNotesField;      // id 'notes', cardId 'notes'
final EditField<Dive, List<Tag>> diveTagsField;    // id 'tags', cardId 'tags'; equal when the tag id sets are equal
/// Cards the dive page can edit, by section. Card ids are the section's `name`.
final Map<DiveDetailSectionId, EditCard<Dive>> diveEditCards;   // notes and tags

// editors
class DiveNotesCardEditor extends StatefulWidget {
  const DiveNotesCardEditor({super.key, required this.session});
  final EditSession<Dive> session;
}
class DiveTagsCardEditor extends StatelessWidget {
  const DiveTagsCardEditor({super.key, required this.session});
  final EditSession<Dive> session;
}
```

- [ ] **Step 1: Write the failing tests**

```dart
test('the registry holds notes and tags, with ids equal to the section names', () {
  expect(diveEditCards.keys, {DiveDetailSectionId.notes, DiveDetailSectionId.tags});
  expect(diveEditCards[DiveDetailSectionId.notes]!.id, 'notes');
});
test('notes is never empty; tags is empty with no tags', () {
  final dive = createTestDiveWithBottomTime();
  expect(diveEditCards[DiveDetailSectionId.notes]!.isEmpty(dive), isFalse);
  expect(diveEditCards[DiveDetailSectionId.tags]!.isEmpty(dive), isTrue);
});
test('the tags field treats the same tags in another order as unchanged', ...);
test('writing a field changes only that field', () {
  final dive = createTestDiveWithBottomTime().copyWith(notes: 'a');
  final changed = diveNotesField.write(dive, 'b');
  expect(changed, dive.copyWith(notes: 'b'));
});

testWidgets('typing in the Notes editor changes the session', (tester) async {
  final session = EditSession<Dive>(dive.copyWith(notes: 'Calm'));
  await pumpEditor(tester, DiveNotesCardEditor(session: session));
  expect(find.text('Calm'), findsOneWidget);
  await tester.enterText(find.byType(TextField), 'Calm, then current');
  expect(session.valueOf(diveNotesField), 'Calm, then current');
  expect(session.changedCardIds, {'notes'});
});
testWidgets('untouched Notes text follows a rebase; edited text does not', (tester) async {
  final session = EditSession<Dive>(dive.copyWith(notes: 'Calm'));
  await pumpEditor(tester, DiveNotesCardEditor(session: session));
  session.rebase(dive.copyWith(notes: 'From another device'));
  await tester.pump();
  expect(find.text('From another device'), findsOneWidget);

  await tester.enterText(find.byType(TextField), 'Mine');
  session.rebase(dive.copyWith(notes: 'Theirs'));
  await tester.pump();
  expect(find.text('Mine'), findsOneWidget);
});
testWidgets('removing a tag in the Tags editor changes the session', ...);
// session with two tags; tap the delete icon of the first chip; valueOf(diveTagsField) has one tag.
testWidgets('the locked Notes and Tags cards look as they did', ...);
// Pump DiveNotesSection and DiveTagsSection with no RecordEditScope: the titles are found in
// titleMedium, the tag count text is found, and there is no pencil.
```

`pumpEditor` wraps the editor in `ProviderScope` (with `...await getBaseOverrides()` from `test/helpers/mock_providers.dart`), `MaterialApp` with the localisation delegates, and a `Scaffold`. `createTestDiveWithBottomTime` is in the same helper file.

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the fields, registry and editors**

`diveEditCards[notes]`: title `l10n.diveLog_detail_section_notes`, `isEmpty: (_) => false`, editor `DiveNotesCardEditor`. `diveEditCards[tags]`: title `l10n.diveLog_detail_section_tags`, `isEmpty: (d) => d.tags.isEmpty`, editor `DiveTagsCardEditor`.

`DiveNotesCardEditor` owns a `TextEditingController` seeded from `session.valueOf(diveNotesField)` and builds `MarkdownNotesField(controller:, autofocus: true, onChanged: (v) => session.set(diveNotesField, v))`. It listens to the session: when notes has no pending change and the controller's text differs from the stored notes, it sets the text. No `onAnnotate` in this plan.

`DiveTagsCardEditor` is a `ListenableBuilder` on the session around `TagFormBlock(label: l10n.diveLog_edit_section_tags, selectedTags: session.valueOf(diveTagsField), onTagsChanged: (tags) => session.set(diveTagsField, tags), scope: TagScope.dives)`.

- [ ] **Step 4: Move the two card titles onto `RecordCardHeader`**

In `DiveTagsSection` replace the title `Row` with `RecordCardHeader(title: l10n.diveLog_detail_section_tags, trailing: <the existing count Text>)`. In `DiveNotesSection` replace the title `Text` with `RecordCardHeader(title: l10n.diveLog_detail_section_notes)`.

- [ ] **Step 5: Register the Notes editor with the Markdown guard**

Add to the `editors` map in `test/architecture/markdown_notes_adoption_test.dart`:

```dart
'lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_notes_card_editor.dart':
    'MarkdownNotesField(',
```

- [ ] **Step 6: Run and confirm they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/ test/architecture/ test/shared/`
Expected: PASS, including the existing Notes and Tags section tests.
Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_markdown_notes_test.dart test/features/dive_log/presentation/pages/dive_detail_tag_chip_tap_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_detail test/features/dive_log/presentation/widgets/dive_detail/editing test/architecture/markdown_notes_adoption_test.dart
git commit -m "feat(dive-log): add in-place editors for the Notes and Tags cards"
```

---

### Task 10: The section list frames editable cards

**Files:**
- Modify: `lib/shared/widgets/section_fold.dart:16-77` (add `trailing`)
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list.dart:96-183` (`build`) and `:362-383` (`_foldSection`)
- Test: `test/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list_editing_test.dart`
- Test: `test/shared/widgets/section_fold_test.dart` (exists; add to it)

**Interfaces:**
- Consumes: `RecordEditScope.maybeOf<Dive>` (Task 3), `RecordCardFrame<Dive>` (Task 4), `diveEditCards` (Task 9).
- Produces: `SectionFold({..., this.trailing})`, `final Widget? trailing`, drawn between the title and the chevron and not part of the header's tap target. `DiveDetailSectionList`'s constructor is unchanged; it reads the controller from the scope.

- [ ] **Step 1: Write the failing tests**

Pump `DiveDetailSectionList` under `RecordEditScope<Dive>` with a real controller, using the settings helpers in `dive_detail_page_section_config_test.dart:88-147` as the model for visible sections, layout and the always-render overrides. Restrict visible sections to notes and tags so the test stays small.

```dart
testWidgets('no scope: the list builds as before', ...);
// no RecordCardFrame anywhere.
testWidgets('unlocked: Notes and Tags are framed and other sections are not', ...);
// find.byType(RecordCardFrame<Dive>) two; a third visible section (customFields) has no pencil.
testWidgets('a dive with no tags shows no Tags card until it is added', (tester) async {
  // dive.tags empty, unlocked: KeyedSubtree ValueKey('diveSection_tags') not found.
  controller.addCard('tags'); await tester.pump();
  // ValueKey('diveSection_tags') found, the Tags editor is open, and it sits above Notes
  // (tester.getTopLeft dy), which is the default section order.
});
testWidgets('a hidden section added from the strip is shown for the sitting', ...);
// settings: notes visible false. Unlocked: no Notes. addCard('notes'): Notes editor open.
// controller.lock(): Notes gone again; the settings notifier saw no setDiveDetailSections call.
testWidgets('list layout: the pencil is on the fold row and the row still folds', (tester) async {
  // layout list, notes folded. Unlocked: find.byTooltip('Edit Notes') on the fold row.
  // Tap the fold row title: the notifier's setDiveDetailSectionExpanded(notes, true) was called.
});
testWidgets('list layout: the pencil opens a folded section without saving the unfold', ...);
// Tap the pencil: Notes editor found; setDiveDetailSectionExpanded was NOT called.
// controller.lock(): the section is folded again.

// section_fold_test.dart
testWidgets('trailing is drawn and its tap does not toggle the fold', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list_editing_test.dart test/shared/widgets/section_fold_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

In `build`: `final edit = RecordEditScope.maybeOf<Dive>(context);` and `final added = edit?.addedCardIds ?? const <String>{};`.
- `visible` also includes a section whose `id.name` is in `added`, unless it is hidden for gauge mode.
- Where a section's content is built, in both the folding branch and the detailed branch: if `_sectionContent` returned null and `added` contains the id, use `const SizedBox.shrink()` as the content. Then, if `diveEditCards[id]` exists, wrap the content in `RecordCardFrame<Dive>(card: card, child: content)`.
- The pair branch is not touched: Notes and Tags are in no pair.
- While the Notes card is open its read widget, which carries `notesKey`, is not mounted. `_scrollToNotes` (`dive_detail_page.dart:182-212`) already does nothing when the key has no context, so leave it.

In `_foldSection`: `isExpanded` is the saved value or `edit.openCardIds.contains(id.name)`. `trailing` is a pencil `IconButton` (same icon and tooltip as `RecordCardHeader`'s) calling `edit.openCard(id.name)`, present when the controller is unlocked, the section has a card and the card is not open.

- [ ] **Step 4: Run and confirm they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/ test/shared/widgets/section_fold_test.dart`
Expected: PASS.
Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_page_section_config_test.dart`
Expected: PASS, unchanged.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/section_fold.dart lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list.dart test/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list_editing_test.dart test/shared/widgets/section_fold_test.dart
git commit -m "feat(dive-log): frame editable cards in the dive section list"
```

---

### Task 11: The dive page unlocks, behind the switch

**Files:**
- Create: `lib/features/dive_log/presentation/pages/dive_detail_page_editing.dart` (`part of 'dive_detail_page.dart';`)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (constructor `:112-135`, state mixins `:141`, `build` `:368-481`, `_buildContent` `:483-634`, `_DiveShortcuts` `:713-744`)
- Test: `test/features/dive_log/presentation/pages/dive_detail_page_unlock_test.dart`

**Interfaces:**
- Consumes: everything above.
- Produces: `DiveDetailPage({..., this.unlockEditing = kUnlockEditing})`, `final bool unlockEditing`. Editing is offered only when `unlockEditing && !embedded`.

The mixin, in the part file:

```dart
mixin _DiveDetailPageEditing on ConsumerState<DiveDetailPage> {
  late final RecordEditController<Dive> editController =
      RecordEditController<Dive>(onSave: _saveSitting);
  bool get editingOffered => widget.unlockEditing && !widget.embedded;
  Future<void> _saveSitting(EditSession<Dive> session);
  Widget lockButton(Dive dive);
  PreferredSizeWidget editBar(BuildContext context, Dive dive);
  List<AddStripEntry> addStripEntries(BuildContext context, Dive working,
      List<DiveDetailSectionConfig> sections);
  void disposeEditing();
}
```

- [ ] **Step 1: Write the failing tests**

Pump the page standalone at `Size(700, 1000)` as `dive_detail_tag_chip_tap_test.dart:41-92` does (a `GoRouter` with a parent route so back has somewhere to go, `...await getBaseOverrides()`, `diveProvider(dive.id)` and `diveDataSourcesProvider(dive.id)` overridden). Override `diveEditSaveServiceProvider` with a fake that records its calls:

```dart
class _FakeSave implements DiveEditSaveService {
  final calls = <({Dive merged, List<String> cards})>[];
  Object? failWith;
  @override
  Future<({Dive before, Dive after})?> save({required String diveId,
      required Dive Function(Dive stored) apply, required Iterable<String> changedCardIds}) async {
    if (failWith != null) throw failWith!;
    final merged = apply(stored);       // `stored` is a field the test sets
    calls.add((merged: merged, cards: changedCardIds.toList()));
    return (before: stored, after: merged);
  }
}
```

The fixture dive has notes `'Calm'` and no tags.

```dart
testWidgets('switch off: no lock button, and the page is as before', ...);
// DiveDetailPage(diveId:, unlockEditing: false): find.byTooltip('Unlock to edit') nothing.
testWidgets('embedded: no lock button even with the switch on', ...);
testWidgets('unlock swaps the bar and moves nothing', (tester) async {
  final before = tester.getTopLeft(find.text('Calm'));
  await tester.tap(find.byTooltip('Unlock to edit')); await tester.pump();
  expect(find.text('Cancel'), findsOneWidget);
  expect(find.widgetWithText(AppBarTextAction, 'Save'), findsOneWidget);
  expect(find.byType(DiveNavButtons), findsNothing);
  // The strip appears above the scroll view, so compare positions inside the scroll view:
  // the Notes text is at the same offset from the scroll view's top as before.
});
testWidgets('the strip offers Tags for a dive with none', ...);
// find.byKey(ValueKey('addStrip_tags')) one; no 'addStrip_notes'.
testWidgets('a note edit is saved and the page locks', (tester) async {
  // unlock; tap the Notes header; enterText 'Calm, then current'; tap Save; pumpAndSettle.
  expect(fake.calls.single.merged.notes, 'Calm, then current');
  expect(fake.calls.single.cards, ['notes']);
  expect(find.byTooltip('Unlock to edit'), findsOneWidget);   // locked again
});
testWidgets('Cancel with changes asks, and Discard leaves the dive as it was', ...);
// fake.calls empty; 'Calm' shown; locked.
testWidgets('Cancel with no changes locks at once', ...);
testWidgets('typing a change and typing it back disables Save again', ...);
// open Notes, enterText 'Calm!', Save enabled; enterText 'Calm', Save disabled, no dot.
testWidgets('a card added from the strip and cancelled leaves no trace', ...);
// tap addStrip_tags, Cancel (no changes, so no dialog): locked, no Tags card;
// unlock again: addStrip_tags is back.
testWidgets('back with changes asks before leaving', ...);
testWidgets('a failed save stays unlocked and says so', (tester) async {
  fake.failWith = StateError('gone');
  // edit notes, Save, pump.
  expect(find.text("Couldn't save your changes. Nothing was changed."), findsOneWidget);
  expect(find.text('Cancel'), findsOneWidget);
  expect(find.bySemanticsLabel('Unsaved changes'), findsOneWidget);
});
testWidgets('a stored change mid-sitting reaches an untouched card', (tester) async {
  // unlock; add and edit Tags only. Then make diveProvider(dive.id) return the dive with
  // notes 'From another device' and invalidate it; pump.
  expect(find.text('From another device'), findsOneWidget);
  // Save: fake.calls.single.cards == ['tags'].
});
testWidgets('arrow keys do not change dive while unlocked', ...);
// unlock; send LogicalKeyboardKey.arrowRight; the router location is unchanged.
```

Read the page's strings through `AppLocalizations` where the test file can; the English literals above show which string is meant.

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_page_unlock_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the mixin**

- `_saveSitting`: call `ref.read(diveEditSaveServiceProvider).save(diveId: widget.diveId, apply: session.applyTo, changedCardIds: session.changedCardIds)`; when the result is not null, `await ref.read(paginatedDiveListProvider.notifier).refreshAfterWrite(before: result.before, after: result.after)`.
- `lockButton`: `IconButton(icon: const Icon(Icons.lock_outline), tooltip: l10n.recordEdit_unlockTooltip, onPressed: () => editController.unlock(dive))`.
- `editBar`: `RecordEditBar(title: l10n.recordEdit_editingTitle(diveTitle(context, dive)), canSave: editController.isDirty, isSaving: editController.isSaving, onCancel: () => cancelSitting(context, editController), onSave: ...)`. `onSave` awaits `editController.save()` and, when it returns false and the page is still mounted, shows `l10n.recordEdit_saveFailed` through the app's messenger (the `app_scaffold_messenger_adoption` guard forbids a plain `ScaffoldMessenger`; use what the page's other messages use).
- `addStripEntries`: for each configured section in order that has an entry in `diveEditCards`, skip it when it is hidden for gauge mode or already in `editController.addedCardIds`; otherwise add an entry when the section is hidden by the diver (`!config.visible`, `hidden: true`) or when the card `isEmpty(working)`. The label is `id.localizedDisplayName(l10n)`.
- `disposeEditing`: dispose the controller. Call it from the state's `dispose`.

- [ ] **Step 4: Wire the page**

- Add `unlockEditing` to the constructor and `_DiveDetailPageEditing` to the state's mixins.
- In `build`, when `editingOffered`: `ref.listen(diveProvider(diveId), (_, next) { final dive = next.valueOrNull; if (dive != null) editController.storedChanged(dive); });`.
- In `_buildContent`, when `editingOffered`, build inside a `ListenableBuilder` on `editController`:
  - `shown` is `editController.session?.working ?? dive`; pass `shown` to `DiveDetailSectionList`. The header block keeps `dive`.
  - Wrap `content` in `RecordEditScope<Dive>(controller: editController, child: content)`.
  - `Scaffold.appBar` is `editBar(context, dive)` when unlocked, else today's `AppBar` with `lockButton(dive)` inserted before the Edit button.
  - `Scaffold.body` is a `Column` of `AddStrip(entries: ..., onAdd: editController.addCard)` (only when unlocked) and `Expanded(child: content)`.
  - Wrap the `Scaffold` in `RecordEditLeaveGuard<Dive>(controller: editController, child: ...)`.
- `_DiveShortcuts` takes an `enabled` flag; the page passes `!editController.isUnlocked`, and with it false the bindings map is empty.
- When `editingOffered` is false, every one of these branches is skipped and the widget tree is what it is today.

- [ ] **Step 5: Run and confirm they pass**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_page_unlock_test.dart`
Expected: PASS.
Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_page_test.dart test/features/dive_log/presentation/pages/dive_detail_page_section_config_test.dart`
Expected: PASS, unchanged.

- [ ] **Step 6: Format, analyse, run the guards**

Run: `dart format .`
Run: `flutter analyze`
Expected: no issues.
Run: `flutter test test/architecture/ test/shared/ test/l10n/`
Expected: PASS.
Run: `wc -l lib/features/dive_log/presentation/pages/dive_detail_page.dart`
Expected: 800 or fewer.

- [ ] **Step 7: Try it in the app**

Run the macOS app with `--dart-define=UNLOCK_EDITING=true` against its own database (set `SUBMERSION_DB_PATH` to a copy; a debug build migrates the database it opens, so never point it at the live one). Check on a real dive: unlock, edit Notes, add a tag from the strip, Save, then open the dive's History and confirm one entry reading "Edited: Notes, Tags" with the old and new notes. Check Cancel with changes. Check the unlocked bar is legible in light and dark and on the Tropical theme, where the primary colour equals the app bar background. Capture screenshots of locked, unlocked, a card open and the strip, in light and dark, for the pull request.

- [ ] **Step 8: Commit**

```bash
git add lib/features/dive_log/presentation/pages/dive_detail_page.dart lib/features/dive_log/presentation/pages/dive_detail_page_editing.dart test/features/dive_log/presentation/pages/dive_detail_page_unlock_test.dart
git commit -m "feat(dive-log): unlock the dive page to edit Notes and Tags in place, behind a switch"
```

---

## Pull requests

One, referring to #4527 with `Refs #4527` (it does not close it). Task 1 was to be a pull request of its own, but main already carries that change.

- Tasks 2 to 11, with the design and its mockup (`docs/design/specs/2026-11-14-unified-editing-pattern-design.md`, `docs/design/specs/assets/2026-11-14-unified-editing-pattern-mockup.html`) and this plan. It touches `lib/**/presentation/` and `lib/shared/widgets/`, so it carries screenshots, with a line saying the page is unreachable without the build switch. Task 11 Step 7 was carried out by rendering the page to images in a widget test instead of a live run; the images are the screenshots.

Pushing and opening them waits for Eric's go-ahead.
