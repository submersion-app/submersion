# Unified editing, media library plan 1: the library's bulk mode

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every bulk write from the Media screen's Library and Gear
selection bars deliberate and one labelled History entry: Move to dive
asks first, naming the count and the dive, and refuses a dive that is open
for editing; Move, Unlink and the Gear tab's Remove each write one labelled
change log operation; deleting a smart album asks first.

**Architecture:** The History scopes open in the data layer: the media
repository's `reassignMediaToDive` runs in its own `ChangeLogScope.bulk`,
and `MediaUnlinkService` gains two labelled entry points, one for the
Library's Unlink and one for the Gear tab's Remove, so the other callers of
the deletion coordinator and of `unlinkFromEquipment` (import Undo, the
orphan sweep, sittings, check-ins) keep their History as it is. Move to
dive's flow (pick, sitting check, confirmation, write) moves out of the
selection bar into a helper of its own. The dive picker gains an entry point
that hands back the picked row, so the confirmation can name the dive
without reading it again.

**Tech Stack:** Flutter, Riverpod, Drift; `ChangeLogScope`
(`lib/core/services/change_log/change_log_scope.dart`), the shared
selection bar (`lib/shared/selection/`).

**Spec:** [docs/design/specs/2026-11-22-unified-editing-media-library-design.md](../specs/2026-11-22-unified-editing-media-library-design.md),
"Design: the library's bulk mode" and plan 1 under "Design: the plans",
within [the pattern](../specs/2026-11-14-unified-editing-pattern-design.md)
(issue #4527).

## Global Constraints

- Never write an em-dash, or an en-dash or double hyphen as sentence
  punctuation, in code, comments, tests, strings, commits or the PR.
- Nothing written to the repo or GitHub names the tools used to write it:
  no tool attribution and no co-author trailers.
- The PR says `Refs #4527`. Goes live as it merges: no build switch.
- No library lock, Unlock or sitting (decision 1). Select, Share, Edit tags
  and the tile tap are unchanged.
- Every bulk write is one `ChangeLogScope.bulk` operation with a label that
  names it. If one cannot run inside one operation, stop and raise it with
  Eric. Do not split the entry silently.
- Do not reuse `diveDropAnswer` for Move: Move refuses an open dive and
  writes to a locked one, the opposite of a drop. The hint is a string of
  its own and does not speak of changes (the sitting may have none).
- Every new string goes into every `lib/l10n/arb/app_*.arb` file (12
  locales), translated, then `flutter gen-l10n`; commit the generated
  `app_localizations*.dart` with them.
- Dates shown follow the active diver's settings (`unitFormatterProvider`).
- Keep every file under 800 lines.
- Run only the test files you wrote or changed, by path. Never a folder,
  never the whole suite; the pre-push hook runs the rest.
- Never run `build_runner` with `--build-filter`.
- `dart format` changed files before each commit. Stage explicit paths.
- Never launch a dev build of the app. Screenshots come from headless widget
  tests under plain `flutter test`.
- Commit only on this branch; push and open the PR only with Eric's say-so.

## Parallel work and shared code

Plan 2 (leaks, History and storage confirmations) is built at the same time
in a sibling worktree and touches different source files. Stay inside this
plan's files. Whichever plan merges second merges main in (never rebase),
takes main's `lib/l10n/arb/` files, adds its own strings again and runs
`flutter gen-l10n`.

**Shared code this plan changes** (each change additive and small):

- `lib/core/services/change_log/change_log_scope.dart`: three constants on
  `ChangeLogLabels`.
- `lib/features/change_log/presentation/change_log_labels.dart`: three arms
  in `changeLogStoredLabel`.
- `lib/features/media/presentation/widgets/dive_picker_sheet.dart`: a second
  entry point and a public row label; `showDivePickerSheet`'s callers are
  unchanged.
- `lib/l10n/arb/*`: new keys only, plus their generated output.

No router, `lib/shared/` or change log policy change.

## Choices for Eric to confirm

The note left these to the builder; the plan makes the calls below.

1. **No Undo after Move.** The confirmation guards it, and the History entry
   reverts the whole move. (Edit tags keeps its Undo.)
2. **A move is filed under the new dive only.** The change log settles a
   media row under the dive it is on when the log settles, so the old
   dive's History does not list the move. Changing that is change log work,
   outside this plan.
3. **The hint comes before the confirmation.** A dive open for editing is
   caught right after the dive is picked, and checked again at Move.
4. **The wording** of the Move confirmation, the hint, the album
   confirmation and the three History labels (Tasks 1, 5 and 6).

## Review Focus

1. **A dive opens for editing while the confirmation is up.** The diver
   picks a dive, then (desktop, another pane) unlocks it before tapping
   Move. Expected: Move is refused with the hint, nothing is written, the
   selection stays. Test in Task 5.
2. **A mixed selection.** Photos from two dives plus one on no dive (a
   site-only or gear-only row) moved together. Expected: every row lands on
   the chosen dive in one operation; a row on no dive never trips the
   sitting check. Tests in Task 2 and Task 5.
3. **A stale sitting.** The provider still names a dive whose session was
   disposed (the page went without clearing it). Expected: Move is allowed,
   as for a locked dive. A session being saved (frozen) still refuses. Test
   in Task 5.
4. **A one-item Unlink.** The coordinator deletes a single row through
   `deleteMedia`, not `deleteMultipleMedia`. Expected: still one labelled
   operation. Test in Task 3.
5. **A write that throws.** Move's repository write fails. Expected: a
   snackbar says so, the selection stays, and no operation in History has
   events. A failed album delete keeps today's "Could not delete album".
   Tests in Task 5 and Task 6.

---

### Task 0: Before screenshots

**Files:**
- Create (scratch, not committed): a throwaway golden harness in the session
  scratchpad, copied into `test/` only while capturing, then deleted.

- [ ] **Step 1: Capture the entry points as they are today**

Headless captures of: the Library selection bar with two items selected and
the dive picker open over it (Move to dive), and the filter sheet's Load
album list with two albums (its delete icons). Phone (390 x 844) and
desktop (1280 x 800), light and dark. Save outside the repo as
`<nn>-<screen>-<width>-<theme>-before.png`. The Move confirmation, the
refusal hint and the album confirmation are new, so they get after shots
only (Task 7).

- [ ] **Step 2: Check nothing is staged**

Run: `git status --short`
Expected: no new or changed file under `lib/` or `test/`.

---

### Task 1: Three History labels

**Files:**
- Modify: `lib/core/services/change_log/change_log_scope.dart` (`ChangeLogLabels`)
- Modify: `lib/features/change_log/presentation/change_log_labels.dart`
- Modify: every `lib/l10n/arb/app_*.arb`, then generated output
- Test: `test/features/change_log/presentation/change_log_labels_test.dart`

**Interfaces:**
- Produces, for Tasks 2 and 3:

```dart
// On ChangeLogLabels:
static const moveMedia = 'move_media';
static const unlinkMedia = 'unlink_media';
static const removeGearPhotos = 'remove_gear_photos';
```

- New keys (English shown; translate for every locale):
  `changeLog_label_moveMedia` "Moved to another dive",
  `changeLog_label_unlinkMedia` "Unlinked from the library",
  `changeLog_label_removeGearPhotos` "Removed gear photos". Each with an
  `@` description naming the History entry it labels.

- [ ] **Step 1: Write the failing test**

In `change_log_labels_test.dart`, beside the existing stored-label cases:

```dart
test('the media library bulk actions read as themselves', () {
  // `l` is the file's AppLocalizationsEn().
  expect(changeLogStoredLabel(l, ChangeLogLabels.moveMedia),
      'Moved to another dive');
  expect(changeLogStoredLabel(l, ChangeLogLabels.unlinkMedia),
      'Unlinked from the library');
  expect(changeLogStoredLabel(l, ChangeLogLabels.removeGearPhotos),
      'Removed gear photos');
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/change_log/presentation/change_log_labels_test.dart`
Expected: FAIL (the constants do not exist).

- [ ] **Step 3: Add the constants, the strings in all locales, the three
  `changeLogStoredLabel` arms; run `flutter gen-l10n`**

- [ ] **Step 4: Run the test to verify it passes**

Same command. Expected: PASS, every existing case included.

- [ ] **Step 5: Commit** (`feat(media): History labels for the library's bulk actions`)

---

### Task 2: Move writes one labelled operation

**Files:**
- Modify: `lib/features/media/data/repositories/media_repository.dart`
  (`reassignMediaToDive`, about `:2581-2601`)
- Test: `test/features/media/data/media_reassign_history_test.dart` (new)

**Interfaces:**
- Consumes: `ChangeLogLabels.moveMedia` (Task 1).
- Produces: `reassignMediaToDive(List<String> mediaIds, String newDiveId)`
  unchanged in signature; its writes now run in
  `ChangeLogScope.bulk(DatabaseService.instance.databaseOrNull, label:
  ChangeLogLabels.moveMedia, ...)`, outside its transaction. Empty
  `mediaIds` returns before opening a scope. Inside another scope (the
  agent writer, `write_applier.dart:198-210`) it joins that operation.

- [ ] **Step 1: Write the failing tests**

Model the setup on `media_reassign_test.dart` (dives `d1`, `d2`; media
`m1`, `m2` on `d1`, `m3` on no dive) and the label reads on
`transmitter_key_delete_history_test.dart` (`settleAll`, then select from
`change_log_operations`; clear setup's operations first):

- `a move is one entry in History, labelled as a move`: move `m1`, `m2`,
  `m3` to `d2`; expect operation labels `[ChangeLogLabels.moveMedia]`, and
  all three rows on `d2`.
- `a move is filed under the dive the items moved to`: after the move,
  `SELECT DISTINCT root_table, root_id FROM change_log_events` holds
  `('dives', 'd2')` and no `('dives', 'd1')`. This pins the note's
  "History placement": the old dive's History does not list the move. If
  the built change log files it under neither dive, stop and raise it.
- `a move inside another operation is part of it`: inside
  `ChangeLogScope.bulk(db, label: ChangeLogLabels.bulkEdit, ...)`, expect
  labels `[ChangeLogLabels.bulkEdit]`.
- `moving nothing writes no entry`: `reassignMediaToDive([], 'd2')`; no
  operation rows.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/media/data/media_reassign_history_test.dart`
Expected: the first and third FAIL (no label / a trigger-logged operation
with a null label).

- [ ] **Step 3: Wrap the body in the scope**

- [ ] **Step 4: Run the new file and `test/features/media/data/media_reassign_test.dart`**

Expected: PASS, the existing reassign cases unchanged.

- [ ] **Step 5: Commit** (`feat(media): a move to a dive is one labelled History entry`)

---

### Task 3: Labelled Unlink and Gear Remove in the unlink service

**Files:**
- Modify: `lib/features/media/data/services/media_unlink_service.dart`
- Test: `test/features/media/data/media_unlink_history_test.dart` (new)

**Interfaces:**
- Consumes: `ChangeLogLabels.unlinkMedia`, `ChangeLogLabels.removeGearPhotos`.
- Produces, for Task 4:

```dart
/// The Library's Unlink: every link of every row goes, as the injected
/// [deleteMedia] does, as one labelled History entry.
Future<void> unlinkFromLibrary(List<String> mediaIds);

/// The Gear tab's Remove: [unlinkFromEquipment] as one labelled entry.
Future<EquipmentUnlinkOutcome> removeGearPhotos(List<String> mediaIds);
```

Each opens `ChangeLogScope.bulk(DatabaseService.instance.databaseOrNull,
...)` around the existing work; empty ids return before opening a scope.
`unlinkFromEquipment`, `unlinkFromDive`, `unlinkFromSite` and their callers
are unchanged.

- [ ] **Step 1: Write the failing tests**

Real test database; the service built as
`MediaUnlinkService(repository: MediaRepository(), deleteMedia: (ids) =>
MediaRepository().deleteMultipleMedia(ids), gearPhotos: GearPhotoRepository())`
(mirror `media_unlink_delete_test.dart` and `gear_photo_repository_test.dart`
for rows and an equipment item whose `cover_media_id` names a photo).
Each media row's `filePath` is a real file under `Directory.systemTemp`
(`p.join`), created in setUp.

- `unlinking from the library is one entry in History`: two rows; labels
  `[ChangeLogLabels.unlinkMedia]`; both rows gone; both files still exist.
- `unlinking one item is still one labelled entry`: one row (the coordinator
  takes its single-row path in the app; here the injected delete); labels
  `[ChangeLogLabels.unlinkMedia]`.
- `removing gear photos is one entry in History`: one gear photo a dive
  still holds (kept, `equipment_id` cleared), one held by nothing (deleted),
  the item's cover naming the second; labels
  `[ChangeLogLabels.removeGearPhotos]`; the cover cleared; the files exist.
- `the other unlink paths keep their History`: `unlinkFromEquipment` called
  directly files no `remove_gear_photos` label.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/media/data/media_unlink_history_test.dart`
Expected: FAIL (methods not defined).

- [ ] **Step 3: Add the two methods**

- [ ] **Step 4: Run the new file and `test/features/media/data/media_unlink_delete_test.dart`**

Expected: PASS.

- [ ] **Step 5: Commit** (`feat(media): Unlink and gear Remove are one labelled History entry each`)

---

### Task 4: The Library's Unlink and the Gear tab's Remove use them

**Files:**
- Modify: `lib/features/media/presentation/widgets/media_selection_bar.dart`
  (`_unlinkSelected`)
- Modify: `lib/features/media/presentation/pages/gear_gallery_view.dart`
  (`_removeSelected`)
- Test: `test/features/media/presentation/media_selection_test.dart`
- Test: `test/features/media/presentation/pages/gear_gallery_view_test.dart`

**Interfaces:**
- Consumes: `unlinkFromLibrary`, `removeGearPhotos` (Task 3), through
  `mediaUnlinkServiceProvider`.
- The confirmations and their wording are unchanged.

- [ ] **Step 1: Write the failing tests**

- `media_selection_test.dart`: `host` takes an optional `unlinkService`
  override for `mediaUnlinkServiceProvider`. New case `confirming unlink goes
  through the library's labelled unlink`: a `_RecordingUnlinkService`
  overriding `unlinkFromLibrary` records the ids; select two, Unlink,
  confirm; expect the recorded ids and `coordinator.deleted` empty. The
  existing unlink cases keep their assertions on `coordinator.deleted`
  (the real service's `deleteMedia` reads the overridden coordinator).
- `gear_gallery_view_test.dart`: `_RecordingUnlink` also overrides
  `removeGearPhotos`, recording into a second list. New case `Remove goes
  through the gear tab's labelled remove`: expect the ids in that list.
  Existing Remove cases keep theirs (`removeGearPhotos` in the fake also
  records into `calls`).

- [ ] **Step 2: Run both files to verify the new cases fail**

- [ ] **Step 3: Call `ref.read(mediaUnlinkServiceProvider).unlinkFromLibrary(ids)`
  and `.removeGearPhotos(ids)`**

Update `_unlinkSelected`'s doc comment: the coordinator is still the
destructive path, now reached through the service's labelled entry.

- [ ] **Step 4: Run both files to verify they pass**

- [ ] **Step 5: Commit** (`feat(media): the Library's Unlink and the Gear tab's Remove file one entry`)

---

### Task 5: Move to dive asks first and refuses an open dive

**Files:**
- Modify: `lib/features/media/presentation/widgets/dive_picker_sheet.dart`
- Create: `lib/features/media/presentation/helpers/media_move_to_dive.dart`
- Modify: `lib/features/media/presentation/widgets/media_selection_bar.dart`
  (`_moveToDive` goes; the action calls the helper)
- Modify: every `lib/l10n/arb/app_*.arb`, then generated output
- Test: `test/features/media/presentation/helpers/media_move_to_dive_test.dart` (new)
- Test: `test/features/media/presentation/widgets/media_selection_bar_move_test.dart` (new)
- Test: `test/features/media/presentation/media_selection_test.dart`
  (the existing `Move to dive opens the picker and reassigns` taps Move in
  the confirmation; its assertions are unchanged)

**Interfaces:**
- Consumes: `openDiveSittingProvider`, `OpenDiveSitting`
  (`features/dive_log/presentation/providers/open_dive_sitting_provider.dart`);
  `reassignMediaToDive` (Task 2); `unitFormatterProvider`.
- Produces:

```dart
// dive_picker_sheet.dart
/// As [showDivePickerSheet], resolving to the picked row.
Future<DivePickerRow?> showDivePickerRowSheet(BuildContext context);
/// '#42 Blue Hole': the number, then the dive's name or its site's.
/// Was the sheet's private _label; the sheet uses it for its rows.
String divePickerRowLabel(DivePickerRow dive);
// showDivePickerSheet stays, as showDivePickerRowSheet(...).then((r) => r?.id).

// media_move_to_dive.dart
/// Whether a move of items now on [fromDiveIds] to [targetDiveId] would
/// change a dive that is open for editing. A disposed session is not open;
/// a frozen one (being saved) is.
bool moveTouchesOpenDive({
  required OpenDiveSitting? open,
  required String targetDiveId,
  required Iterable<String?> fromDiveIds,
});

/// The Library's Move to dive: pick, check, confirm, write.
Future<BulkActionOutcome> moveMediaToDive(
  BuildContext context,
  WidgetRef ref,
  List<MediaItem> items,
);
```

`moveMediaToDive`, in order: picker dismissed is `cancelled`. The sitting
check runs on the picked row; refused shows the hint snackbar and returns
`cancelled` (nothing was attempted, the selection stays). Otherwise the
confirmation; Cancel is `cancelled`. The sitting check runs again after
Move is tapped (a dive may have opened meanwhile); refused as before. Then
`reassignMediaToDive`; a throw shows `media_library_moveFailed` in the error
colour and returns `failed`; success is `completed`.

The confirmation is an `AlertDialog` (key `ValueKey('move_to_dive_confirm')`):
title `media_library_moveConfirmTitle(count)`, content
`media_library_moveConfirmBody(dive)` where `dive` is
`divePickerRowLabel(row)` and `units.formatDate(row.dateTime)` joined by
", " (the label left out when empty), actions Cancel
(`common_action_cancel`) and Move (`media_library_moveConfirmAction`). No
Undo afterwards (History's revert is the way back; see the questions to
Eric).

- New keys (English shown; translate for every locale):
  - `media_library_moveConfirmTitle`: "Move {count, plural, =1{1 item} other{{count} items}}?"
  - `media_library_moveConfirmBody`: "They move to {dive} and leave the dive they are on now. Site and gear links stay as they are."
  - `media_library_moveConfirmAction`: "Move"
  - `media_library_moveDiveOpenHint`: "A dive in this move is open for editing. Save, cancel or lock it, then try again."
  - `media_library_moveFailed`: "Could not move the items"

- [ ] **Step 1: Write the failing tests**

`media_move_to_dive_test.dart`, `moveTouchesOpenDive` (sessions built as in
`open_dive_sitting_provider_test.dart`):

```dart
test('no open dive never refuses', () => expect(
    moveTouchesOpenDive(open: null, targetDiveId: 'd2',
        fromDiveIds: ['d1', null]), isFalse));
test('the target open, with no changes, refuses', ...);      // open d2 -> true
test('a source dive open refuses', ...);                       // open d1, from d1 -> true
test('another dive open does not refuse', ...);                // open d9 -> false
test('a row on no dive never matches', ...);                   // from [null] -> false
test('a dive being saved still refuses', ...);                 // frozen d2 -> true
test('a disposed sitting is not open', ...);                   // disposed d2 -> false
```

`media_selection_bar_move_test.dart` pumps `MediaSelectionBar` directly, as
`media_selection_bar_tags_test.dart` does, with a recording
`MediaRepository` fake (`reassigned`, optional `reassignError`), the
`_FakeDiveRepo` row shape from `media_selection_test.dart` (dive `dive-2`,
number 2, 12 Jun 2026), the diver id overrides, and
`openDiveSittingProvider.overrideWith(...)` per case. Items `a` and `b` on
`d1`, `c` on no dive. Cases:

- `picking a dive asks, naming the count and the dive`: tap Move to dive,
  tap `#2`; expect `Move 3 items?` and a body containing `#2`; nothing
  reassigned yet.
- `Cancel writes nothing and keeps the selection`.
- `Move writes and ends the mode`: `reassigned == (['a','b','c'], 'dive-2')`.
- `a dive open for editing with no changes is refused`: sitting on
  `dive-2`, fresh `EditSession`; after picking, the hint text shows, no
  confirmation dialog, nothing reassigned, the selection kept.
- `the dive the items are on, open, is refused`: sitting on `d1`.
- `a locked dive is moved to`: provider null; Move writes.
- `a dive opened while the confirmation is up is refused`: open the
  confirmation, then set `openDiveSittingProvider` (through the
  `ProviderScope`'s container) to `dive-2`, tap Move; hint shows, nothing
  reassigned.
- `a move that fails says so and keeps the selection`: `reassignError` set;
  `Could not move the items` shows; selection kept.

- [ ] **Step 2: Run both new files to verify they fail**

Run: `flutter test test/features/media/presentation/helpers/media_move_to_dive_test.dart test/features/media/presentation/widgets/media_selection_bar_move_test.dart`
Expected: FAIL (helper not defined; no confirmation).

- [ ] **Step 3: Add the picker entry point and label, the strings in all
  locales (`flutter gen-l10n`), the helper, and point the bar's Move action
  at it**

- [ ] **Step 4: Run the two new files, `media_selection_test.dart`,
  `media_selection_bar_web_test.dart`, and the dive picker's existing tests
  (`grep -rl showDivePickerSheet test` for their paths)**

Expected: PASS.

- [ ] **Step 5: Commit** (`feat(media): Move to dive asks first and refuses a dive open for editing`)

---

### Task 6: Deleting a smart album asks first

**Files:**
- Modify: `lib/features/media/presentation/widgets/media_library_filter_sheet.dart`
  (`_loadAlbum`'s delete button, `_deleteAlbum`, about `:284-329`)
- Modify: every `lib/l10n/arb/app_*.arb`, then generated output
- Test: `test/features/media/presentation/media_smart_album_test.dart`

**Interfaces:**
- `_deleteAlbum(MediaSmartAlbum album)` (was `String id`): pops the album
  list as today, then an `AlertDialog` (key
  `ValueKey('smart_album_delete_confirm')`): title
  `media_smartAlbum_deleteConfirmTitle(album.name)`, content
  `media_smartAlbum_deleteConfirmBody`, actions Cancel and Delete
  (`common_action_delete`, in the error colour). Delete runs the repository
  delete and keeps today's failure snackbar.
- New keys: `media_smartAlbum_deleteConfirmTitle`: "Delete \"{name}\"?";
  `media_smartAlbum_deleteConfirmBody`: "Only the saved filter goes. No
  photos or videos change."

- [ ] **Step 1: Write the failing tests**

- `deleting an album asks first, naming it`: tap the delete icon; expect
  `Delete "Blue Hole video"?` (the fixture album's name) and `repo.deleted`
  empty.
- `cancelling keeps the album`: Cancel; `repo.deleted` empty.
- The existing `deleting an album from the list calls the repository` and
  `a delete that fails says so instead of failing silently` tap Delete in
  the dialog before their assertions, which are unchanged.

- [ ] **Step 2: Run the file to verify the new cases fail**

Run: `flutter test test/features/media/presentation/media_smart_album_test.dart`

- [ ] **Step 3: Add the strings in all locales, `flutter gen-l10n`, the
  confirmation**

- [ ] **Step 4: Run the file to verify it passes**

- [ ] **Step 5: Commit** (`feat(media): deleting a smart album asks first`)

---

### Task 7: After screenshots, review, and the question to Eric

- [ ] **Step 1: After screenshots**

With the Task 0 harness: the Move confirmation (two items, dive `#2`), the
refusal hint snackbar, the album delete confirmation, and the Task 0 entry
points again. Phone and desktop, light and dark. `pngquant` them. Delete the
harness from `test/`.

- [ ] **Step 2: Format and analyze**

Run: `dart format` on every changed file, then `flutter analyze` on the
changed files. Expected: no issues.

- [ ] **Step 3: Review**

Run the code-review skill on the branch with `--max-findings all`; fix every
valid finding test-first, one commit each.

- [ ] **Step 4: Write "After the build" below and commit it**

- [ ] **Step 5: Ask Eric whether to push and open the PR** (`Refs #4527`,
  screenshots through the project's highest-numbered secret gist). Do not
  push until he says so.

## After the build

Built natively on 2026-11-22 (commits f06b8b5 to the branch head). What
changed from this plan:

- **History placement is confirmed.** A move is filed under the new dive
  only; two of Task 2's tests passed before the scope existed, because the
  triggers already root a media row at its live dive and an outer scope
  already captures trigger rows. They stay as pins.
- **The media store drains after the entry closes.** The review found that
  the deletion coordinator awaited the worker's whole drain (uploads
  included) inside the Unlink and Remove scopes, filing every queued upload
  under them. The coordinator gained `deferDrain` (no kick, cached copies
  purged as final), and `MediaUnlinkService` gained the injected
  `deleteMediaUndrained` and `drainDeletes`: the labelled methods delete
  undrained inside the scope and drain once it has closed. Fakes that
  override `deleteMultipleMedia` take the new parameter.
- **Gear Remove is one transaction.** A delete that fails leaves no photo
  half removed and the cover as it was.
- **Unlink says when it fails** ("Could not unlink the items"), and Unlink
  and Move log the cause.
- **Wording changed after review:** the Unlink title is a plural ("Unlink 1
  item?"), and the Move body counts its items and holds for items on no
  dive: "The items move to {dive}, off any dive they are on now. Site and
  gear links stay as they are."
- **Tests run:** only the files written or changed; the dive picker's own
  test and the selection bar's web test are left to the pre-push hook.
- **Shared code beyond the plan's list:**
  `lib/features/media_store/data/media_deletion_coordinator.dart`
  (`deferDrain`) and `lib/features/media/presentation/providers/media_providers.dart`
  (the unlink service's wiring).
