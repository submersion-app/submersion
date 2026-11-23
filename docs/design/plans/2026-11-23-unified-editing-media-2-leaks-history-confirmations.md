# Unified editing, media library, plan 2: leaks, History and storage confirmations

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the three places where a shipped lock can still be written
past (the site page's bulk Set category, Manifest mode in a sitting's
picker, the species page's Files and URL tabs), remove the two immediate
write paths no caller reaches, file the folder watcher's relinks in History
as automatic, and make three one-tap storage and settings writes ask first.

**Architecture:** The site's Set category becomes a held change of the
site's Media sitting, beside its adds and unlinks in
`record_media_sitting.dart`, written by the sitting's Save. The photo
picker reads `MediaHoldScope` to drop Manifest mode, and gains a
gallery-only form for the species page. The PDF viewer and the species tag
picker lose their immediate branches. `MediaRepairService.apply` picks its
change log scope from its source. Three dialogs are added at the call sites;
the reconnect sheet reuses the Advanced section's dialog, moved to a file
both import.

**Tech Stack:** Flutter, Riverpod, Drift; the media sitting helpers in
`lib/features/media/presentation/editing/` and
`lib/core/services/change_log/change_log_scope.dart`.

**Spec:** [docs/design/specs/2026-11-22-unified-editing-media-library-design.md](../specs/2026-11-22-unified-editing-media-library-design.md)
(the media library part of [the pattern](../specs/2026-11-14-unified-editing-pattern-design.md)).
Read its "Decisions", "Design: the leaks in shipped locks", "Design: History
for the folder watcher", "Design: confirmations on storage and settings",
"Left for later", "Testing" and plan 2 under "Design: the plans" before
starting.

## Global Constraints

- Never write an em-dash, or an en-dash or double hyphen as sentence
  punctuation, in code, comments, tests, commits or the PR.
- Nothing written to the repo or GitHub names the tools used to write it:
  no tool attribution and no co-author trailers.
- The PR says `Refs #4527`.
- Goes live as it merges: no build switch.
- No table or column is added; the change log policy does not change.
- Every new string goes into all 11 locales (`lib/l10n/arb/app_*.arb`),
  translated, then `flutter gen-l10n`. This plan adds the seven strings
  named in Tasks 4, 5, 9 and 10, and no others.
- Store and settings actions stay available while everything is locked
  (plan 10): none of the new confirmations checks a lock.
- If a held write cannot run inside the sitting's Save, stop and raise it
  with Eric. Do not write it at once instead.
- Keep every file under 800 lines. `photo_picker_page.dart` is at 760: the
  new hint widget lives in its own file.
- Run only the test files you wrote or changed, by path. Never a folder,
  never the whole suite; the pre-push hook runs the rest.
- Never run `build_runner` with `--build-filter`.
- Run `dart format` on changed files before each commit. Stage explicit
  paths; never `git add -A`, never a bare `git stash`, never rebase.
- Never launch a dev build of the app (it can open the diver's real log or
  sync). Screenshots come from headless widget tests.
- Commit only on this branch; push and open the PR only with Eric's say-so.

## Parallel work and shared code

Plan 1 of the same note (the library's bulk mode) is built at the same time
in another worktree, in `media_selection_bar.dart`, `gear_gallery_view.dart`,
`media_library_filter_sheet.dart`, the media repository and the unlink
service. This plan touches none of those.

**Shared code this plan changes:**

- `lib/features/media/presentation/editing/record_media_sitting.dart`: used
  by the dive, site, gear and trip sittings. Additive: a held category map
  that defaults to empty and an optional writer that only the site's
  factory sets, so every other sitting is unchanged.
- `lib/core/constants/feature_flags.dart`: one comment line on
  `lightroomUiEnabled`.
- `lib/l10n/arb/app_*.arb` and the generated `app_localizations*.dart`.
  Whichever plan merges second merges main in (never rebase), keeps main's
  locale files, adds its own strings again and runs `flutter gen-l10n`.

Nothing under `lib/shared/`, the change log, the router or the media
repository changes.

## Review Focus

1. **A URL tab left in Manifest mode opens on links in a sitting.** The URL
   tab's mode survives between picker sessions (`UrlTabNotifier.startSession`
   keeps it). A picker opened from a dive, site or gear sitting after
   Media, Import was left in Manifest shows the links form and the hint,
   never the Manifest panel. Test in Task 4.
2. **A photo given a category and then unlinked in the same sitting** writes
   no category and does not fail the Save: the unlink wins. Test in Task 2.
3. **A category set back to the stored one leaves nothing to save.** Picking
   Underwater for photos already Underwater, or picking Parking then the
   stored category again, leaves the Media card unchanged and Save
   disabled. Test in Task 2.
4. **Re-upload asks only for a real downgrade.** Original for an uploaded
   original, and any level for a photo whose original is not uploaded (a
   rendition only, or nothing yet), queues at once with no dialog. Test in
   Task 10.
5. **A cancelled confirmation leaves its page usable.** Cancel on the
   reconnect sheet's Stop keeping copies leaves the sheet open with every
   choice enabled and calls no detach; Cancel on a watched folder's removal
   leaves the folder listed. Tests in Task 8 and Task 9.

---

### Task 0: Before screenshots

**Files:**
- Create (scratch, not committed): a throwaway golden harness in the
  session scratchpad, copied into `test/` only while capturing, then
  deleted

- [ ] **Step 1: Capture the screens as they are today**

Headless captures, phone width (390 x 844), light and dark, named
`<nn>-<screen>-<theme>-before.png` and saved outside the repo:

1. A locked site page's attachments card in Select with two photos checked
   (Set category shows).
2. The photo picker's URL tab opened from a dive sitting (the Links and
   Manifest switch shows).
3. The photo picker opened from a species page's Add photos (Gallery, Files
   and URL tabs).
4. The reconnect sheet with Stop keeping copies offered.
5. Media, Sources with one watched folder.
6. The viewer's Re-upload level menu open.

- [ ] **Step 2: Check nothing is staged**

Run: `git status --short`
Expected: no new or changed file under `lib/` or `test/`.

---

### Task 1: The folder watcher's relinks file as automatic

**Files:**
- Modify: `lib/features/media/data/services/repair/media_repair_service.dart:209-223`
- Test: `test/features/media/data/repair/media_repair_service_test.dart`
- Test: `test/features/media/data/repair/watched_folder_scanner_test.dart`

**Interfaces:**
- Produces: `MediaRepairService.apply` keeps its signature; with
  `source: RepairLogSource.watcher` it opens `ChangeLogScope.automatic`,
  with any other source `ChangeLogScope.bulk`. The label stays
  `ChangeLogLabels.mediaRepair` either way.

- [ ] **Step 1: Write the failing tests**

In `media_repair_service_test.dart`, beside "exact file proposal rewrites
the path and clears isOrphaned" and with the same proposal:

```dart
test('a watcher relink files as one automatic media repair', () async {
  // ...seed 'a', settle the log, clearLog(db), DELETE FROM change_log_operations
  await service().apply([proposal], source: RepairLogSource.watcher);
  await ChangeLogSettler(db).settle();
  final op = (await db.select(db.changeLogOperations).get()).single;
  expect(op.source, ChangeLogSource.automatic.name);
  expect(op.label, ChangeLogLabels.mediaRepair);
});

test('a reviewed relink (the wizard) stays manual', () async {
  // same, with no source argument
  expect(op.source, ChangeLogSource.manual.name);
  expect(op.label, ChangeLogLabels.mediaRepair);
});
```

In `watched_folder_scanner_test.dart`, beside "an exact hash match on a
missing row is auto-applied" (the daily pass and Scan now both run this
scanner):

```dart
test('an auto-applied relink files under automatic', () async {
  // ...as the auto-applied case, clearing the log before scan()
  final op = (await db.select(db.changeLogOperations).get()).single;
  expect(op.source, ChangeLogSource.automatic.name);
});
```

Follow `test/features/change_log/automatic_sources_test.dart` for the
settle, `clearLog` and operation read.

- [ ] **Step 2: Run them to see the watcher cases fail**

Run: `flutter test test/features/media/data/repair/media_repair_service_test.dart test/features/media/data/repair/watched_folder_scanner_test.dart`
Expected: the two watcher cases FAIL with `manual` where `automatic` is
expected; the wizard case passes.

- [ ] **Step 3: Pick the scope from the source in `apply`**

`source == RepairLogSource.watcher ? ChangeLogScope.automatic : ChangeLogScope.bulk`,
both with the same db, label and body. Update the doc comment: a watcher
pass and Scan now are matched and written without review, so they file as
automatic; the wizard's reviewed Re-link files as the diver's.

- [ ] **Step 4: Run the tests to see them pass**

Same command. Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
git add lib/features/media/data/services/repair/media_repair_service.dart test/features/media/data/repair/media_repair_service_test.dart test/features/media/data/repair/watched_folder_scanner_test.dart
git commit -m "fix(media): the folder watcher's relinks file in History as automatic"
```

---

### Task 2: A site's Media sitting holds a bulk category

**Files:**
- Modify: `lib/features/media/presentation/editing/record_media_sitting.dart`
- Test: `test/features/media/presentation/editing/record_media_sitting_test.dart`

**Interfaces:**
- Produces:
  - `SittingMedia.categories`: `Map<String, SiteAttachmentCategory?>`,
    default `const {}`, a held category per stored media id (a null value
    uncategorizes). `SittingMedia.isEmpty` also requires it empty.
  - `SittingMediaWriters.setCategories`: an optional named constructor
    parameter, `Future<void> Function(Map<String, SiteAttachmentCategory?> categories)?`,
    null by default. Only `SittingMediaWriters.forSite` sets it: it groups
    the map by category and calls
    `read(siteAttachmentRepositoryProvider).setSiteCategory(ids, category)`
    once per group.
  - `void setCategoryInSitting<T>(EditSession<T> session, List<MediaItem> stored, SiteAttachmentCategory? category)`:
    holds [category] for each of [stored] (the rows as stored, not as the
    sitting shows them). An id whose stored `siteCategory` equals
    [category] is dropped from the hold instead.
  - `unlinkMediaInSitting` also drops the unlinked ids from `categories`.
  - `mediaInSitting` returns each stored row with a held category as
    `row.copyWith(siteCategory: held)`, so the card groups it there.
  - `_write`: after the network media and before the unlinks, writes the
    held categories through `setCategories`; with categories held and no
    `setCategories`, throws `UnsupportedError('this sitting sets no category')`.

- [ ] **Step 1: Write the failing tests**

In `record_media_sitting_test.dart`, with `started()` given a recording
`setCategories` (`calls.add('categories $map')`) and `row` given a
`siteCategory`:

- `'a held category is written at Save and shown before it; Cancel writes nothing'`:
  `setCategoryInSitting(session, [s1, s2], SiteAttachmentCategory.parking)`;
  `session.changedCardIds == {'media'}`; `calls` empty;
  `mediaInSitting(session, stored)` has both rows with
  `siteCategory == parking`; after `runHeldWrites()`, `calls` is
  `['categories {s1: parking, s2: parking}']`. A second session disposed
  after holding writes nothing.
- `'a category set back to the stored one leaves nothing held'`: with s1
  stored as underwater, holding underwater for `[s1]` leaves
  `changedCardIds` empty; holding parking, then underwater, for `[s1]`
  also leaves it empty.
- `'an unlink wins over a held category'`: hold parking for `[s1, s2]`,
  unlink `{s2}`; after `runHeldWrites()`, `calls` is
  `['categories {s1: parking}', 'unlink [s2]']`.
- `'a sitting with no category writer refuses a held category at Save'`:
  a session started with `setCategories: null`, a held category, and
  `runHeldWrites()` throws `UnsupportedError`.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/media/presentation/editing/record_media_sitting_test.dart`
Expected: FAIL to compile (`setCategoryInSitting` and `setCategories` are
not defined).

- [ ] **Step 3: Implement the members listed under Interfaces**

- [ ] **Step 4: Run the tests to see them pass**

Same command. Expected: PASS, the existing cases included.

- [ ] **Step 5: Format, analyze, commit**

```bash
git add lib/features/media/presentation/editing/record_media_sitting.dart test/features/media/presentation/editing/record_media_sitting_test.dart
git commit -m "feat(media): a site's Media sitting can hold a bulk category"
```

---

### Task 3: The site page's Set category follows the lock

**Files:**
- Modify: `lib/features/media/presentation/widgets/site_media_section.dart:170-206`, `:334-357`
- Test: `test/features/media/presentation/widgets/site_media_section_test.dart`

**Interfaces:**
- Consumes: `setCategoryInSitting` and `mediaInSitting` from Task 2.
- Produces: no new public member. The `setCategory` `BulkAction` is offered
  only when `!_readOnly`, as Unlink is.

- [ ] **Step 1: Write the failing tests**

Give `host()` an `EditSession<DiveSite>? editing` parameter passed to
`SiteMediaSection(editing: ...)`, with `holdSittingMedia` given recording
writers (as in Task 2's tests).

- Change `'on a page that edits in place Edit details is gone, Set category stays'`
  to `'a locked site page offers neither Edit details nor Set category'`:
  both `selection_action_editDetails` and `selection_action_setCategory`
  find nothing.
- `'in the open card Set category is held until Save'`: with `editing`,
  select both, Set category, Underwater: `notifier.categoryCalls` is empty,
  the session's `changedCardIds` is `{'media'}`, both tiles show under the
  Underwater heading, no "Updated 2 items" snackbar, selection ends. After
  `session.runHeldWrites()` the recording writer got both ids.
- `'Cancel on the open card discards a held category'`: hold as above,
  dispose the session, rebuild with `editing: null` under the scope: the
  tiles are back under their stored heading and nothing was written.
- The three existing Set category cases (no scope: the page that does not
  edit in place) stay as they are.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/media/presentation/widgets/site_media_section_test.dart`
Expected: the locked case FAILS (Set category found); the open card case
FAILS (`categoryCalls` has one call).

- [ ] **Step 3: Gate and hold Set category**

Offer the action under `if (!_readOnly)`. In `_setCategoryForSelected`,
with `widget.editing` set: hold through `setCategoryInSitting` with the
checked rows as stored (from `mediaForSiteProvider`, not the sitting's
view) and return `BulkActionOutcome.completed`; if the card closed while
the picker was up (`_readOnly` now), return `cancelled` and hold nothing,
as `_unlinkSelected` does. Without a sitting and without a scope, today's
immediate write stays.

- [ ] **Step 4: Run the tests to see them pass**

Same command. Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
git add lib/features/media/presentation/widgets/site_media_section.dart test/features/media/presentation/widgets/site_media_section_test.dart
git commit -m "fix(dive-sites): Set category is gone on a locked site page and held in the open card"
```

---

### Task 4: A sitting's picker offers no Manifest mode

**Files:**
- Create: `lib/features/media/presentation/widgets/import_elsewhere_hint.dart`
- Modify: `lib/features/media/presentation/widgets/url_tab.dart:156-176`
- Modify: `lib/l10n/arb/app_*.arb` (11 files) and the generated output
- Test: `test/features/media/presentation/widgets/url_tab_test.dart`

**Interfaces:**
- Produces:
  - `class ImportElsewhereHint extends StatelessWidget` with
    `const ImportElsewhereHint({super.key, required String message})`: one
    line, an `Icons.info_outline` and [message] in `bodySmall`,
    `onSurfaceVariant`. Task 5 uses it too.
  - String `media_photoPicker_feedElsewhereHint`: "To add a feed of
    photos, use Import on the Media screen."

- [ ] **Step 1: Write the failing tests**

In `url_tab_test.dart`, pumping `UrlTab` under
`MediaHoldScope(sink: (_) {}, child: ...)`:

- `'in a sitting there is no Manifest switch, and the hint shows'`: no
  `_ModeSegmentedControl` (find by the "Manifest" segment text), the hint
  text shows, the links form shows.
- `'in a sitting a tab left in Manifest mode shows the links form'`: set
  `urlTabNotifierProvider.notifier.setMode(UrlTabMode.manifest)` before
  pumping; `ManifestModePanel` finds nothing, the links field shows.
- `'outside a sitting the switch and Manifest mode are unchanged'`: no
  scope, the switch shows and Manifest mode shows `ManifestModePanel`
  (the existing "Manifest mode body renders the ManifestModePanel" case
  already covers this; keep it).

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/media/presentation/widgets/url_tab_test.dart`
Expected: the two sitting cases FAIL (the switch and the panel are found).

- [ ] **Step 3: Read the scope in `build`**

`final held = MediaHoldScope.maybeOf(context) != null;` With `held`: the
hint in place of `_ModeSegmentedControl`, and the links body whatever
`state.mode` says. Do not change the notifier's mode: it is the library's
to keep. Add the string to all 11 locales, run `flutter gen-l10n`.

- [ ] **Step 4: Run the tests to see them pass**

Same command. Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
git add lib/features/media/presentation/widgets/import_elsewhere_hint.dart lib/features/media/presentation/widgets/url_tab.dart lib/l10n/arb/ test/features/media/presentation/widgets/url_tab_test.dart
git commit -m "fix(media): a picker opened from a sitting offers no Manifest mode"
```

(`lib/l10n/arb/` names the folder only to stage its changed locale and
generated files; check `git status` first that nothing else changed there.)

---

### Task 5: The species page's picker shows its Gallery tab only

**Files:**
- Modify: `lib/features/media/presentation/pages/photo_picker_page.dart:29-122`, `:260-304`
- Modify: `lib/features/media/presentation/pages/photo_picker_launch.dart:16-50`
- Modify: `lib/features/media/presentation/helpers/species_photo_import_helper.dart:137-142`
- Modify: `lib/l10n/arb/app_*.arb` and the generated output
- Test: `test/features/media/presentation/pages/photo_picker_page_tab_shell_test.dart`
- Test (create): `test/features/media/presentation/helpers/species_photo_import_helper_test.dart`

**Interfaces:**
- Consumes: `ImportElsewhereHint` from Task 4.
- Produces:
  - `PhotoPickerPage.galleryOnly` and `showPhotoPicker(galleryOnly:)`:
    `bool`, default `false`. With it the page has no `TabBar`, shows
    `ImportElsewhereHint` above the Gallery body, and Done is always shown.
    `assert(!galleryOnly || initialFilePaths == null)`.
  - String `media_photoPicker_galleryOnlyHint`: "To add files or links,
    use Import on the Media screen."
  - `SpeciesPhotoImportHelper.preparePhotosForSpecies` opens the picker
    with `galleryOnly: true`.

- [ ] **Step 1: Write the failing tests**

In `photo_picker_page_tab_shell_test.dart`, with the file's stubs:

- `'gallery only: no tab bar, no Files or URL tab, the hint and Done show'`:
  `find.byType(TabBar)`, `FilesTab` and `UrlTab` find nothing; the
  gallery-only hint and the Done action show.

In the new `species_photo_import_helper_test.dart`: a button that calls
`SpeciesPhotoImportHelper.preparePhotosForSpecies(context, ref, speciesId: 'sp')`
with no `pick`, under the tab shell test's provider overrides; tap it and
expect `tester.widget<PhotoPickerPage>(find.byType(PhotoPickerPage)).galleryOnly`
to be `true`.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/media/presentation/pages/photo_picker_page_tab_shell_test.dart test/features/media/presentation/helpers/species_photo_import_helper_test.dart`
Expected: FAIL to compile (`galleryOnly` is not defined).

- [ ] **Step 3: Implement `galleryOnly`**

The tab controller keeps its three tabs (the Gallery load listens to it);
with `galleryOnly` the bar has no `bottom` and the body is the hint over
`_galleryTab(context)` instead of the `TabBarView`. Pass it through
`showPhotoPicker`; set it in `preparePhotosForSpecies`. Add the string to
all 11 locales, run `flutter gen-l10n`. Keep `photo_picker_page.dart` under
800 lines.

- [ ] **Step 4: Run the tests to see them pass**

Same command, plus the other picker tests that build the page:
`flutter test test/features/media/presentation/pages/photo_picker_page_dropped_files_test.dart test/features/media/presentation/pages/photo_picker_page_session_test.dart`.
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
git add lib/features/media/presentation/pages/photo_picker_page.dart lib/features/media/presentation/pages/photo_picker_launch.dart lib/features/media/presentation/helpers/species_photo_import_helper.dart lib/l10n/arb/ test/features/media/presentation/pages/photo_picker_page_tab_shell_test.dart test/features/media/presentation/helpers/species_photo_import_helper_test.dart
git commit -m "fix(marine-life): a species page's Add photos picker shows only its Gallery tab"
```

---

### Task 6: The PDF viewer loses its immediate Edit details

**Files:**
- Modify: `lib/features/media/presentation/pages/document_viewer_page.dart:24-65`, `:132-163`
- Modify: `lib/features/media/presentation/helpers/document_open_helper.dart:28-68`
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page.dart:612-620`
- Modify: `lib/features/dive_sites/presentation/editing/site_attachment_card_editors.dart:27-34`
- Test: `test/features/media/presentation/pages/document_viewer_page_test.dart`
- Test: `test/features/media/presentation/pages/document_viewer_unlock_test.dart`

**Interfaces:**
- Produces: `DocumentViewerPage` and `DocumentOpenHelper.open` lose
  `attachmentLock`. A PDF opened with an `editableSiteId` has its own lock
  (today's `attachmentLock: true` behaviour); without one it reads only. A
  non-PDF document with an `editableSiteId` opens `AttachmentDetailsPage`.
  Every caller that passed `editableSiteId` passed `attachmentLock: true`.

- [ ] **Step 1: Write the failing test and retire the immediate ones**

In `document_viewer_page_test.dart`, replace "Edit details shows only with
an editable site id" and "a second Edit details opens on the saved
category" (both exercise the immediate path) with:

```dart
testWidgets('locked, a site PDF offers the lock and no Edit details', ...
  // _editableHost(doc, editableSiteId: 'site-1')
  expect(find.byTooltip('Edit details'), findsNothing);
  expect(find.byKey(const ValueKey('document_unlock')), findsOneWidget);
```

In `document_viewer_unlock_test.dart`, drop the `attachmentLock` parameter
from `pumpDocument` and the page; remove "without attachmentLock a removed
document leaves the viewer" and "without attachmentLock it is today's
viewer" (the dive case, "opened from a dive it offers no lock", covers a
viewer with no site).

- [ ] **Step 2: Run them to see the new case fail**

Run: `flutter test test/features/media/presentation/pages/document_viewer_page_test.dart test/features/media/presentation/pages/document_viewer_unlock_test.dart`
Expected: the unlock test file FAILS to compile until the parameter goes;
the new case FAILS (Edit details found, no lock).

- [ ] **Step 3: Remove the flag and the immediate branch**

`_hasLock => widget.editableSiteId != null`; delete the `else if`
Edit details button in `_lockedBar`; drop `attachmentLock` from the
helper (its non-PDF branch tests `editableSiteId != null`) and from the two
site callers. Update the doc comments.

- [ ] **Step 4: Run the tests to see them pass**

Same command. Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
git add lib/features/media/presentation/pages/document_viewer_page.dart lib/features/media/presentation/helpers/document_open_helper.dart lib/features/dive_sites/presentation/pages/site_detail_page.dart lib/features/dive_sites/presentation/editing/site_attachment_card_editors.dart test/features/media/presentation/pages/document_viewer_page_test.dart test/features/media/presentation/pages/document_viewer_unlock_test.dart
git commit -m "refactor(media): the PDF viewer edits a site document only under its lock"
```

---

### Task 7: The species tag picker only chooses

**Files:**
- Modify: `lib/features/media/presentation/pages/species_tag_picker_page.dart:15-50`, `:186-205`
- Modify: `lib/features/marine_life/presentation/pages/species_detail_page_editing.dart:178-181`
- Test: `test/features/media/presentation/pages/species_tag_picker_page_test.dart`

**Interfaces:**
- Produces: `SpeciesTagPickerPage` loses `chooseOnly` and its `_busy`
  state; Confirm always pops a `SpeciesTagChoice`. It no longer reads
  `speciesTaggingServiceProvider`.

- [ ] **Step 1: Write the failing test and retire the immediate one**

Replace the case built with `const SpeciesTagPickerPage(speciesId: 'sp_x')`
(around line 81) that expects a `TagPhotosResult` with:

```dart
testWidgets('Confirm pops the choice and tags nothing', ...
  // speciesTaggingServiceProvider overridden with a fake recording tagPhotos
  // calls; pick two photos, Confirm
  expect(popped, isA<SpeciesTagChoice>());
  expect((popped as SpeciesTagChoice).items.map((m) => m.id), ['p1', 'p2']);
  expect(fakeTagging.tagPhotosCalls, isEmpty);
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/features/media/presentation/pages/species_tag_picker_page_test.dart`
Expected: FAIL (`tagPhotosCalls` has one call; a `TagPhotosResult` pops).

- [ ] **Step 3: Remove the flag and the tagging branch**

Delete `chooseOnly`, `_busy` and the `tagPhotos` call; `_confirm` keeps
only the choose path. Drop `chooseOnly: true` from the species page caller
and from the remaining test. Update the class comment.

- [ ] **Step 4: Run the tests to see them pass**

Same command. Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
git add lib/features/media/presentation/pages/species_tag_picker_page.dart lib/features/marine_life/presentation/pages/species_detail_page_editing.dart test/features/media/presentation/pages/species_tag_picker_page_test.dart
git commit -m "refactor(marine-life): the species tag picker hands its choice to the sitting"
```

---

### Task 8: The reconnect sheet asks before it stops keeping copies

**Files:**
- Create: `lib/features/media_store/presentation/widgets/stop_keeping_copies_dialog.dart`
- Modify: `lib/features/media_store/presentation/widgets/photos_advanced_section.dart:259-279`
- Modify: `lib/features/media_store/presentation/widgets/media_store_reconnect_sheet.dart:269-276`, `:340-353`
- Test: `test/features/media_store/presentation/widgets/media_store_reconnect_sheet_test.dart`

**Interfaces:**
- Produces: `Future<bool> confirmStopKeepingCopies(BuildContext context)`:
  the Advanced section's dialog as it is today (title and body
  `settings_photos_stopKeeping` and `settings_photos_stopKeepingBody`,
  Cancel, and the confirm button keyed `media-s3-disconnect-confirm`),
  true only on confirm. No new string.

- [ ] **Step 1: Write the failing tests**

In `media_store_reconnect_sheet_test.dart`:

- Change "stopping keeps nothing attached and closes" to tap
  `reconnect-detach`, then `media-s3-disconnect-confirm`; same
  expectations.
- Change "a refused detach says why and keeps the choices" the same way.
- Add `'Cancel on Stop keeping copies detaches nothing and keeps the choices'`:
  tap `reconnect-detach`, then Cancel: `fake.detachCalls == 0`,
  `reconnect-detach` still shows and is enabled
  (`tester.widget<ListTile>(...).enabled`).

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/media_store/presentation/widgets/media_store_reconnect_sheet_test.dart`
Expected: FAIL (no confirm button; detach already called).

- [ ] **Step 3: Move the dialog and ask in the sheet**

Move the dialog out of `_stopKeeping` into `confirmStopKeepingCopies`; the
Advanced section calls it. `_detachCopies` asks first and returns before
`setState(() => _busy = true)` unless confirmed (and still mounted).

- [ ] **Step 4: Run the tests to see them pass**

Same command, plus the Advanced section's:
`flutter test test/features/media_store/presentation/pages/photos_advanced_errors_test.dart test/features/media_store/presentation/pages/photos_videos_page_test.dart`.
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
git add lib/features/media_store/presentation/widgets/stop_keeping_copies_dialog.dart lib/features/media_store/presentation/widgets/photos_advanced_section.dart lib/features/media_store/presentation/widgets/media_store_reconnect_sheet.dart test/features/media_store/presentation/widgets/media_store_reconnect_sheet_test.dart
git commit -m "fix(media-store): the reconnect sheet asks before it stops keeping copies"
```

---

### Task 9: Removing a watched folder asks first

**Files:**
- Modify: `lib/features/media/presentation/pages/media_sources_section_view.dart:179-184`
- Modify: `lib/l10n/arb/app_*.arb` and the generated output
- Test: `test/features/media/presentation/media_sources_section_test.dart`

**Interfaces:**
- Produces: strings `media_sources_removeFolderTitle` ("Stop watching
  this folder?") and `media_sources_removeFolderBody` with a `{folder}`
  placeholder ("Submersion forgets the files it found in {folder}, so
  missing photos are no longer looked for there. No photo or file is
  deleted."). The confirm button is `common_action_remove`; the clear
  button gains the tooltip `common_action_remove`.

- [ ] **Step 1: Write the failing tests**

- Change "removing a root drops it from the list" to tap the clear button,
  see the title and the folder's path in the body, tap Remove; the root
  is gone and `removeRoot` ran once.
- Add `'Cancel keeps the watched folder'`: tap clear, then Cancel; the
  root still shows and `removeRoot` never ran.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/media/presentation/media_sources_section_test.dart`
Expected: FAIL (no dialog; the root is gone at once).

- [ ] **Step 3: Ask before `removeRoot`**

An `AlertDialog` with Cancel (`common_action_cancel`) and Remove; remove
only on true and while the tile is still mounted. Add both strings to all
11 locales, run `flutter gen-l10n`.

- [ ] **Step 4: Run the tests to see them pass**

Same command. Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
git add lib/features/media/presentation/pages/media_sources_section_view.dart lib/l10n/arb/ test/features/media/presentation/media_sources_section_test.dart
git commit -m "fix(media): removing a watched folder asks first"
```

---

### Task 10: Re-upload asks before it replaces an uploaded original

**Files:**
- Modify: `lib/features/media_store/presentation/widgets/media_reupload_menu.dart:30-64`
- Modify: `lib/l10n/arb/app_*.arb` and the generated output
- Test: `test/features/media_store/media_reupload_menu_test.dart`

**Interfaces:**
- Produces:
  - `bool reuploadDropsOriginal(MediaItem item, MediaUploadQuality level)`:
    `item.remoteUploadedAt != null && level != MediaUploadQuality.original`.
    (A compressed re-upload of an uploaded original clears its stamp and
    deletes the original object once no row uses it:
    `media_upload_pipeline.dart:306-318`.)
  - Strings `settings_mediaStorage_quality_downgradeTitle` ("Replace the
    full-quality copy?"), `settings_mediaStorage_quality_downgradeBody`
    with a `{level}` placeholder ("The original kept in your storage is
    replaced with a {level} copy. The photo on this device is kept."), and
    `settings_mediaStorage_quality_downgradeConfirm` ("Replace").

- [ ] **Step 1: Write the failing tests**

Give `host()` an item parameter. Then:

- `'a compressed level for an uploaded original asks; Replace queues it'`:
  item with `remoteUploadedAt` set, pick Balanced: the title and the body
  naming "Balanced" show, nothing recorded; tap Replace: one call with
  `balanced` and the queued snackbar.
- `'Cancel on the downgrade queues nothing'`: as above, Cancel: no call,
  no snackbar.
- `'Original, or a photo with no uploaded original, queues at once'`: the
  uploaded original with Original, and an item with only
  `remoteCompressedUploadedAt` with Small: each records one call and no
  dialog shows.
- The existing "picking a level calls the reupload provider" keeps its
  item with no uploaded original.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/media_store/media_reupload_menu_test.dart`
Expected: the two downgrade cases FAIL (no dialog; the call is made).

- [ ] **Step 3: Ask when `reuploadDropsOriginal`**

After the menu returns a level, and only when `reuploadDropsOriginal(item, level)`:
an `AlertDialog` with Cancel and Replace, the body naming `_qualityLabel(l10n, level)`;
return on anything but Replace or an unmounted anchor. Add the three
strings to all 11 locales, run `flutter gen-l10n`.

- [ ] **Step 4: Run the tests to see them pass**

Same command. Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
git add lib/features/media_store/presentation/widgets/media_reupload_menu.dart lib/l10n/arb/ test/features/media_store/media_reupload_menu_test.dart
git commit -m "fix(media-store): Re-upload asks before replacing an uploaded original"
```

---

### Task 11: The note on the Lightroom flag

**Files:**
- Modify: `lib/core/constants/feature_flags.dart:33-38`

- [ ] **Step 1: Add the note to the flag's comment**

One paragraph after "To re-enable once Adobe approves": before the flag is
turned on, the dive page's Lightroom suggestions row
(`lightroom_suggestions_row.dart`) must hold Accept and Dismiss in the
dive's Media card and be hidden while the dive is locked (issue #4527, the
media library design note, "Left for later").

- [ ] **Step 2: Analyze and commit**

Run: `dart analyze lib/core/constants/feature_flags.dart`
Expected: No issues found.

```bash
git add lib/core/constants/feature_flags.dart
git commit -m "docs(media): note what the Lightroom row needs before its flag is turned on"
```

---

### Task 12: After screenshots, review, and the question to Eric

- [ ] **Step 1: Capture the after shots**

The Task 0 screens and themes with the same harness, named `-after.png`,
plus: the open site card's Set category held (tiles under the new heading,
the bar's Save enabled), and each new dialog (watched folder, reconnect
sheet's Stop keeping copies, Re-upload downgrade).

- [ ] **Step 2: Check the strings and the whole branch**

Run: `flutter gen-l10n && git status --short lib/l10n` (expect no change),
then `flutter analyze` and `dart format --set-exit-if-changed lib test`.
Expected: no issues, no change.

- [ ] **Step 3: Review the branch**

Run the `code-review` skill on the branch with `--max-findings all`. Fix
every valid finding test-first, one commit per fix or per related group.
Re-run only the test files touched.

- [ ] **Step 4: Write "After the build" into this plan and commit it**

What changed from the plan, as the phase 4 plans do.

- [ ] **Step 5: Ask Eric before anything goes out**

Show the before and after shots and the review outcome, and ask whether to
push and open the PR.

- [ ] **Step 6: On his yes, push and open the PR**

Title: `fix(editing): close the media library's lock leaks, file the folder
watcher as automatic, and confirm storage changes (Unified Editing, media
library, plan 2)`. Body: what changed, `Refs #4527`, the design note and
this plan linked, the screenshots attached through the project's
highest-numbered secret gist (`PR screenshots: submersion-app/submersion (N)`,
pngquant first, `<pr>-<nn>-<screen>-<state>.png`, raw URLs pinned to the
gist commit). Bind the PR and report its checks.

## After the build

Built natively on 2026-11-22 (commits 5abaa9c to the branch head). What
changed from this plan:

- **Twelve locale files, not eleven.** `lib/l10n/arb/` holds ar, de, en,
  es, fr, he, hu, it, ja, nl, pt and zh; every new string is in all twelve.
  Only the English file carries description blocks, and a new key goes
  after its neighbour's block, never between a key and its own.
- **The PDF viewer lost its `_item` copy** along with the immediate Edit
  details: only that path reassigned it. Two more tests read
  `attachmentLock` and were updated: `document_open_helper_test.dart` and
  `site_detail_page_unlock_test.dart`.
- **The species page's picker test needs a URL tab notifier** with no
  database behind it: the picker clears the URL tab's staging as it opens,
  even in its gallery-only form.
- **The open card's held category has its own test file**,
  `site_media_section_category_hold_test.dart`, which keeps
  `site_media_section_test.dart` under 800 lines.
- **Review (code-review, high, all findings):** seven findings, five
  fixed, test-first where a behaviour changed:
  - A repair's History entry holds only its writes. The scope now opens
    around Stage B onward in `_applyInner`; the per-row hashing and
    bookmarks before it ran inside the scope, and a save made meanwhile
    was filed under the repair (as automatic, for a watcher pass).
  - A confirmed downgrade queues even if the Re-upload button went away
    while the dialog was up: the queue and the messenger are read first.
  - The downgrade warning reads the stamps as the attached store sees them
    (`stampsInStore`): an original uploaded to another store is never
    dropped by this device, so it does not ask.
  - The test file split above, and the open card's Cancel test now expects
    both tiles shown as stored.
  - Left as they are: a held category is written at Save even when the
    attachment's own lock saved another meanwhile (the card shows the held
    one, and Save writes what the card shows); and Set category's read of
    the stored list cannot be empty once rows were selectable (a reload
    keeps the previous value).
- **A second review (code-review, xhigh, all findings, on the PR):** three
  findings, all fixed test-first:
  - Re-upload no longer needs its button after the menu: the store id is
    read, the downgrade dialog hangs from the navigator, and the choice is
    queued even if the viewer's controls hid meanwhile.
  - A repair's cloud id lookup (PhotoKit) runs before its History entry
    opens, like the hashing and bookmarks.
  - `SittingMediaWriters.forSite` has a test of its one-write-per-category
    grouping, Uncategorized included.
- **A third review (code-review, xhigh, on the PR):** two nits. The test
  host for Re-upload no longer leaves a notifier undisposed. And, on Eric's
  call, where the Gallery tab is a file dialog (Windows, Linux) the species
  picker's hint names only links (`media_photoPicker_galleryOnlyLinksHint`,
  "To add links, use Import on the Media screen."): eight new strings in
  all.
