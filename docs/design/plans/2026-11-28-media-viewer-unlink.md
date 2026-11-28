# Media Viewer Unlink Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An unlocked photo or video in the media viewer offers Unlink, scoped to the screen the viewer came from, held until Save.

**Architecture:** A new `photo_viewer_unlink.dart` holds the scope enum, the offer rule and the held change (`EditSession.holdChange` under `photo:unlink`, card `unlink`), whose write runs the existing `SittingMediaWriters` unlink for the scope inside `PhotoEditSaveService.save`'s transaction. `PhotoViewerEditing` gains the confirm-and-hold entry point and a post-save hook; `MediaViewerPage` takes the scope, shows the action, the held strip and the dimming in a new part file, and drops a saved unlink from its pager.

**Tech Stack:** Flutter, Riverpod, Drift, flutter_test with the test database harness.

**Spec:** `docs/design/specs/2026-11-28-media-viewer-unlink-design.md`

## Global Constraints

- Never touch a user's original file; only the existing `MediaUnlinkService` paths and `mediaDeletionCoordinatorProvider.deleteMultipleMedia(ids, holdRemoteDelete: true)` delete.
- Nothing is written before Save; Cancel, Undo and the discard check keep the item.
- No Unlink while locked or in the browser build (`DeviceCapabilities.mediaAttach` false).
- Unlink is offered only when the item has the scope's link (dive: `diveId`, site: `siteId`, gear: `equipmentId`; library: always).
- Labels: "Unlink from dive", "Unlink from site", "Unlink from gear", "Unlink" (library). Strip: "Will be unlinked from this dive when you save", "... from this site ...", "... from this gear item ...", "Will be removed from your library when you save". Undo button "Undo".
- Every new ARB key is translated in every locale (`lib/l10n/arb/app_*.arb`), inserted beside a neighbouring key of its feature group. No em-dashes anywhere.
- `media_viewer_page.dart` is at 776 lines: new viewer code goes in a new part file, never in that file beyond a few wiring lines.
- Run only the test files written or changed, by path.

## Review Focus

1. A held unlink and then Cancel, Escape, close or step: the discard question appears, and discarding keeps the item and writes nothing. (Task 3 test `discarding a held unlink keeps the photo`.)
2. A dive-scoped unlink of a photo the site still uses: Save keeps the row with `diveId` null, and the dive viewer drops it. (Task 2 test `dive scope keeps a site-linked row`.)
3. A library-scoped viewer is a static snapshot: after Save the item leaves the pager, the next one shows, the last item falls back to the previous one, and an only item pops the viewer. (Task 3 tests.)
4. Our own unlink deletes the row the viewer follows: no "photo was deleted while you were editing" snackbar may appear after a successful Save. (Task 3 test `no gone message after its own unlink`.)
5. A Save refused (photo moved to another dive meanwhile): the unlink stays held, nothing is written. (Task 2 test `a moved photo refuses the unlink`.)

---

### Task 1: Scope, offer rule, writers and the held change

**Files:**
- Create: `lib/features/media/presentation/editing/photo_viewer_unlink.dart`
- Modify: `lib/features/media/presentation/editing/photo_edit_fields.dart` (constants beside `photoFileCardId` and `photoRelinkKey`)
- Modify: `lib/features/media/presentation/editing/record_media_sitting.dart` (add `SittingMediaWriters.forLibrary`)
- Modify: `lib/features/media/data/services/media_unlink_service.dart` (add `unlinkEverywhere`)
- Test: `test/features/media/presentation/editing/photo_viewer_unlink_test.dart`
- Test: `test/features/media/data/media_unlink_delete_test.dart` (add one test)

**Interfaces:**
- Produces:
  - `enum ViewerUnlinkScope { dive, site, gear, library }`
  - `bool viewerOffersUnlink(ViewerUnlinkScope? scope, MediaItem item)`
  - `SittingMediaWriters viewerUnlinkWriters(ViewerUnlinkScope scope, ProviderRead read)`: dive `forDive`, site `forSite`, gear `forEquipment`, library `forLibrary`.
  - `const photoUnlinkKey = 'photo:unlink';` and `const photoUnlinkCardId = 'unlink';`
  - `void holdViewerUnlink(EditSession<PhotoRecord> session, SittingMediaWriters writers)`: `holdChange(photoUnlinkKey, cardId: photoUnlinkCardId, write: () => writers.unlink([session.stored.item.id]))`, and `remember`s `writers.drainDeletes` under a private key.
  - `bool viewerUnlinkHeld(EditSession<PhotoRecord>? session)`: false for null or disposed.
  - `void undoViewerUnlink(EditSession<PhotoRecord> session)`: `releaseWrite(photoUnlinkKey)`.
  - `Future<void> Function()? viewerUnlinkDrain(EditSession<PhotoRecord> session)`: the remembered drain, or null when no unlink is held.
  - `Future<void> MediaUnlinkService.unlinkEverywhere(List<String> ids)`: `deleteMedia(ids)` then `clearCoversNaming(ids)`, no change log scope of its own (it runs inside the photo save's).

- [ ] **Step 1: Write the failing tests** in `photo_viewer_unlink_test.dart`:
  - `offers unlink only when the item has the scope's link`: dive scope true for `MediaItem(diveId: 'd1')`, false with no dive; site needs `siteId`; gear needs `equipmentId`; library true for an item with no links; a null scope is false.
  - `holding marks the sitting changed with the unlink card`: after `holdViewerUnlink`, `session.isDirty`, `session.changedCardIds` contains `'unlink'`, `viewerUnlinkHeld(session)` true.
  - `undo drops only the unlink`: with a pin change set (`photoPinField`) and the unlink held, `undoViewerUnlink` leaves `isDirty` true, `viewerUnlinkHeld` false.
  - `the held write unlinks the sitting's photo`: a fake `SittingMediaWriters` whose `unlink` records ids; `await session.runHeldWrites()` records `['p1']`.
  - In `media_unlink_delete_test.dart`, `unlinkEverywhere deletes the row and clears a gear cover naming it`, following that file's existing setup.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/media/presentation/editing/photo_viewer_unlink_test.dart test/features/media/data/media_unlink_delete_test.dart`
Expected: FAIL, `photo_viewer_unlink.dart` and `unlinkEverywhere` not defined.

- [ ] **Step 3: Implement** the Produces list. `SittingMediaWriters.forLibrary(read)` is `_app` with `unlinkFrom: (service, ids) => service.unlinkEverywhere(ids)` and the `replace` that throws `UnsupportedError('a library viewer relinks no media')`.

- [ ] **Step 4: Run the tests to verify they pass** (same command). Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/media/presentation/editing/photo_viewer_unlink.dart lib/features/media/presentation/editing/photo_edit_fields.dart lib/features/media/presentation/editing/record_media_sitting.dart lib/features/media/data/services/media_unlink_service.dart test/features/media/presentation/editing/photo_viewer_unlink_test.dart test/features/media/data/media_unlink_delete_test.dart
git commit -m "feat(media): held unlink for the photo viewer's sitting"
```

### Task 2: Saving a held unlink, and the History name

**Files:**
- Modify: `lib/features/media/presentation/editing/photo_viewer_editing.dart`
- Create: `lib/features/media/presentation/widgets/viewer_unlink_confirm.dart`
- Modify: `lib/features/change_log/presentation/change_log_labels.dart` (`_photoChangeName`)
- Modify: `lib/l10n/arb/app_*.arb` (all locales), then `flutter gen-l10n`
- Test: `test/features/media/presentation/pages/media_viewer_unlink_save_test.dart`

**Interfaces:**
- Consumes: Task 1.
- Produces, on `PhotoViewerEditing`:
  - `ViewerUnlinkScope? get unlinkScope => null;` (overridden by `MediaViewerPage`)
  - `bool get photoUnlinkHeld => viewerUnlinkHeld(photoSitting);`
  - `bool get photoEditable => photoUnlocked && !photoUnlinkHeld;`
  - `bool canUnlinkPhoto(MediaItem item)`: unlocked, not held, `viewerOffersUnlink(unlinkScope, item)`.
  - `Future<void> unlinkPhotoHeld(MediaItem item)`: `confirmViewerUnlink`, then (sitting still open, same photo) `holdViewerUnlink(sitting, viewerUnlinkWriters(scope, ref.read))`.
  - `void undoPhotoUnlink()`
  - `void onPhotoUnlinked(String mediaId) {}`: called once after a save that carried the unlink succeeds.
- Produces, in `viewer_unlink_confirm.dart`: `Future<bool> confirmViewerUnlink(BuildContext context, WidgetRef ref, ViewerUnlinkScope scope, String mediaId)`. Dive: `media_diveMediaSection_unlinkSelectedTitle(1)` / `...Content(1)` / `media_diveMediaSection_unlinkButton`; site: `media_siteMediaSection_unlinkSelectedTitle(1)` / `...Content(1)` / `media_diveMediaSection_unlinkButton`; gear: `confirmRemoveGearPhotos(context, 1)`; library: `media_library_unlinkConfirmTitle(1)` / `media_library_unlinkConfirmBody` / `media_library_unlinkSelected`. Dive, site and library append `media_library_unlinkMetadataNote(n)` when `idsWithUserMetadataAtRisk`, `idsWithUserMetadataAtRiskForSite` or `idsWithUserMetadata` return ids. The confirm button has key `ValueKey('viewer_unlink_confirm')`.
- New ARB keys: `media_viewer_unlinkFromDive`, `media_viewer_unlinkFromSite`, `media_viewer_unlinkFromGear`, `media_viewer_unlink`, `media_viewer_unlinkHeldDive`, `media_viewer_unlinkHeldSite`, `media_viewer_unlinkHeldGear`, `media_viewer_unlinkHeldLibrary`, `media_viewer_unlinkUndo`, `media_editCard_unlink` ("Unlink"), with the English values from Global Constraints.

- [ ] **Step 1: Write the failing tests** in `media_viewer_unlink_save_test.dart`, on `media_viewer_unlock_harness.dart` (`seedViewerData`, `pumpViewerApp`, `tapUnlock`, `photoController`), driving the hold through `photoController(tester).session` and `holdViewerUnlink` (the UI comes in Task 3):
  - `dive scope deletes a dive-only photo on Save`: `p2` gone from `MediaRepository().getMediaById`, one History entry whose label decodes with card `unlink`.
  - `dive scope keeps a site-linked row`: seed `ps` with `diveId: 'd1', siteId: 's1'`; after Save its row exists with `diveId` null and `siteId` `'s1'`.
  - `held edits are written with the unlink`: a pin set before the hold on `ps` (kept) is stored after Save.
  - `a moved photo refuses the unlink`: move `p2` to another dive in the database after unlocking; Save shows `media_viewer_movedWhileEditing`, `p2` still exists, `eventCount` unchanged.
  - `the History entry names Unlink`: `changeLogRecordEditLabel` (the function holding `_photoChangeName`) renders "Unlink".

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/media/presentation/pages/media_viewer_unlink_save_test.dart`
Expected: FAIL on the missing API.

- [ ] **Step 3: Implement.** In `_savePhotoSitting`, read `viewerUnlinkDrain(session)` and the photo id before `service.save`; after the commit, run the drain in the existing best-effort loop (logged, never failing the save). In `savePhotoAndReport`, note `photoUnlinkHeld` and the id before `controller.save()`; when `saved` is true and it was held, call `onPhotoUnlinked(id)`. Add `photoUnlinkCardId => l.media_editCard_unlink` to `_photoChangeName`. Add the ARB keys in every locale; run `flutter gen-l10n`.

- [ ] **Step 4: Run to verify they pass** (same command). Expected: PASS.

- [ ] **Step 5: Commit** (explicit paths: the two lib files, `change_log_labels.dart`, every `lib/l10n/arb/app_*.arb` and generated `app_localizations*.dart`, the test).

```bash
git commit -m "feat(media): save a held unlink from the photo viewer"
```

### Task 3: The viewer's action, strip, dimming and step after Save

**Files:**
- Modify: `lib/features/media/presentation/widgets/media_viewer_toolbar.dart` (an `onUnlinkMedia` / `unlinkLabel` pair)
- Create: `lib/features/media/presentation/widgets/media_viewer_unlink_strip.dart`
- Create: `lib/features/media/presentation/pages/media_viewer_unlink.dart` (`part of 'media_viewer_page.dart'`)
- Modify: `lib/features/media/presentation/pages/media_viewer_page.dart` (field, part directive, `_pageableMedia` filter, strip in the Stack, `photoEditable` at the `identificationsEditable` gate)
- Modify: `lib/features/media/presentation/pages/media_viewer_chrome.dart` (`writeControls: photoEditable`, the unlink callback)
- Modify: `lib/features/media/presentation/pages/media_viewer_bottom_metadata.dart` call site (`photoLocked: !photoEditable`)
- Modify: `test/features/media/presentation/pages/media_viewer_unlock_harness.dart` (`pumpViewer` takes `ViewerUnlinkScope? unlinkScope`)
- Test: `test/features/media/presentation/pages/media_viewer_unlink_test.dart`
- Test: `test/features/media/presentation/widgets/media_viewer_toolbar_test.dart` (add tests)

**Interfaces:**
- Consumes: Task 2's mixin API.
- Produces:
  - `MediaViewerPage({..., ViewerUnlinkScope? unlinkScope})`, overriding `unlinkScope`.
  - `MediaViewerToolbar({..., void Function()? onUnlinkMedia, String? unlinkLabel})`: action id `'unlink'` (button key `viewer_unlink`, menu key `viewer_menu_unlink`), icon `Icons.link_off`, priority 10, drawn only while `editBar != null` and not `readOnly`.
  - `MediaViewerUnlinkStrip({required String message, required VoidCallback onUndo})`: key `ValueKey('viewer_unlink_strip')`, Undo key `ValueKey('viewer_unlink_undo')`, a warning-toned bar from the theme's `colorScheme` (`tertiaryContainer` / `onTertiaryContainer`), bottom of the photo above the panel.
  - In the part file: `String _unlinkLabelFor(ViewerUnlinkScope)`, `String _unlinkHeldMessageFor(ViewerUnlinkScope)`, `Set<String> _unlinkedIds`, the `onPhotoUnlinked` override (adds the id; pops the viewer when nothing pageable is left, else lets the index clamp), and the dimming (`Opacity(0.45)` around the held item's page).

- [ ] **Step 1: Write the failing tests.** Toolbar test: `unlink shows only in the editing bar` (absent with `editBar` null, present with it, absent when `readOnly`). Viewer tests (`media_viewer_unlink_test.dart`):
  - `no unlink while locked`; `no unlink for a dive scope on a photo with no dive` (open `lib` with dive scope).
  - `confirming holds the unlink`: tap `viewer_unlink`, then `viewer_unlink_confirm`; the strip shows the dive message, `viewer_species` is gone, the Save button is enabled.
  - `Undo drops the hold`: strip gone, Save disabled again.
  - `discarding a held unlink keeps the photo`: Cancel, confirm discard; `p2` still stored, `eventCount` unchanged.
  - `Save steps to the next item` (library scope over `p1..p3` at `p2`: after Save the indicator reads `2 / 2` and `p3` is shown); `the last item falls back` (at `p3`: shows `p2`); `an only item closes the viewer` (pushed with `pushedFrom`, list `[lib]`: after Save the page below shows).
  - `no gone message after its own unlink`: after Save, `find.text(l10n.media_viewer_photoGoneWhileEditing)` finds nothing.
  - `a video unlinks too`: seed a `fileType: 'video'` item and run the hold and Save.
  - `the browser build offers no unlink`: `pumpViewer(browser: true)`.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/media/presentation/pages/media_viewer_unlink_test.dart test/features/media/presentation/widgets/media_viewer_toolbar_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** the Produces list and the wiring. `_pageableMedia` also skips `_unlinkedIds`. The chrome passes `onUnlinkMedia: canUnlinkPhoto(currentItem) ? () => unawaited(unlinkPhotoHeld(currentItem)) : null` and the scope's label.

- [ ] **Step 4: Run to verify they pass** (same command, plus `test/features/media/presentation/pages/media_viewer_unlock_test.dart` since the harness changed). Expected: PASS.

- [ ] **Step 5: Commit** (explicit paths).

```bash
git commit -m "feat(media): unlink from the unlocked media viewer"
```

### Task 4: Every entry point passes its scope

**Files:**
- Modify: `lib/features/media/presentation/pages/media_viewer_launcher.dart`: `openMediaViewer` gains `ViewerUnlinkScope? unlinkScope`; add `void openLibraryMediaViewer(BuildContext, List<MediaItem>, String)` (a `MediaViewerOpener`) passing `ViewerUnlinkScope.library`.
- Modify: `media_library_view.dart` and `media_map_content.dart`: default `openViewer = openLibraryMediaViewer`.
- Modify, scope dive: `photo_viewer_page.dart`, `trip_photo_viewer_page.dart`, `species_photo_viewer_page.dart`, `dive_species_photo_viewer_page.dart`, `buddies/.../buddy_photos_section.dart`, `species_id/.../species_review_page.dart`, `marine_life/.../species_crop_strip.dart`.
- Modify: `site_media_viewer_page.dart`: `attachments` passes site, `divePhotos` passes dive.
- Modify, scope gear: `equipment_photos_section.dart`, `check_in_photos_row.dart`, `observations_card.dart`, `gear_gallery_view.dart`.
- Test: `test/features/media/presentation/pages/media_viewer_wrappers_test.dart` (add one test per wrapper family), `site_media_viewer_page_test.dart` (two).

**Interfaces:**
- Consumes: `MediaViewerPage.unlinkScope`, `openMediaViewer(unlinkScope:)`.

- [ ] **Step 1: Write the failing tests**: each wrapper (dive, trip, species, site attachments, site dive photos) builds a `MediaViewerPage` whose `unlinkScope` is the table's; `openLibraryMediaViewer` pushes one with `library`; a gear call site (`gear_gallery_view`) pushes one with `gear`.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/media/presentation/pages/media_viewer_wrappers_test.dart test/features/media/presentation/pages/site_media_viewer_page_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** the scope at each call site.

- [ ] **Step 4: Run to verify they pass** (same command). Expected: PASS.

- [ ] **Step 5: Commit** (explicit paths).

```bash
git commit -m "feat(media): each viewer entry point names what Unlink unlinks from"
```

### Task 5: Finish

- [ ] `dart format .`, `flutter analyze` (whole repo, clean), and the test files changed in Tasks 1 to 4 by path.
- [ ] After screenshots with `test/_pr_shots/viewer_unlink_shots_test.dart --dart-define=STAGE=after`; copy the PNGs to the scratchpad; delete `test/_pr_shots/`; confirm `git status` shows nothing under it.
