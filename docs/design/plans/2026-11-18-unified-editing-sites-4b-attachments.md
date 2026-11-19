# Unified Editing, Phase 2, Plan 4b: Site Attachments Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A site attachment is a record with its own lock: the PDF viewer opened from a site opens locked and holds its details until Save, a document with no viewer opens a small details page that does the same, and the site's Media card loses its single Edit details.

**Architecture:** The photo viewer's sitting (`PhotoViewerEditing` over `PhotoRecord`, saved by `PhotoEditSaveService`) already holds category and display size (`photoSiteCategoryField`, `photoDisplaySizeField`) and already reads and writes any `media` row, documents included. Both document pages mix it in, with documents allowed to unlock; nothing new is added to the shared record editing pieces. Everything new is behind `kUnlockSiteEditing`, reached through `DocumentOpenHelper.open(attachmentLock: true)`, which only the site page passes, and only with the switch on.

**Tech Stack:** Flutter, Riverpod 3, drift (test database through `setUpTestDatabase`), `flutter gen-l10n` with 11 ARB locales.

**Spec:** `docs/design/specs/2026-11-17-unified-editing-phase-2-sites-design.md`, "Design: attachments", decisions 8 and 9, the "held, and what is not" table rows for Edit details and Set category, and the Delivery list item 4. Plans 1 to 4 (`docs/design/plans/2026-11-17-unified-editing-sites-1-shared-host.md` to `2026-11-18-unified-editing-sites-4-hosts.md`) shipped the names used here.

## Questions for Eric

The plan is written to the recommended answer of each; a different answer changes only the task named.

1. **Behind the switch?** Recommended: yes. The PDF viewer's lock and the details page come only with `kUnlockSiteEditing` on, like everything else in phase 2, so today's PDF viewer keeps its Edit details sheet until the switch-over plan. The alternative is to ship the PDF viewer's lock now, as the photo viewer's lock shipped in phase 1 without a switch. (Global Constraints, Tasks 2 to 4.)
2. **Open on phones.** The spec gives the details page Open and Share. On a phone, Open is the share sheet (that is what `DocumentOpenHelper.openExternally` does there), so the two buttons would do the same thing. Recommended: Open only on desktop (macOS, Windows, Linux), Share everywhere. (Task 3.)
3. **How the details page edits.** Recommended: the category and display size are the page's own fields, shown read only (disabled) while locked and editable in place while unlocked. The alternative is the PDF viewer's way, an Edit details button in the bar that opens the same sheet. The PDF viewer keeps the sheet either way, since the document fills its screen. (Task 3.)

## Global Constraints

- Everything new is reached only through `DocumentOpenHelper.open(..., attachmentLock: true)`, and only the site page passes `attachmentLock: true`, as `widget.unlockEditing` (its switch, `kUnlockSiteEditing`). With the switch off, the PDF viewer, the Media card and tapping a document behave exactly as today.
- Opened from a dive or a piece of gear (no `editableSiteId`), the PDF viewer offers no lock and no Edit details, as today.
- On a device that cannot change media (`deviceCapabilitiesProvider.mediaAttach` false, a browser), neither page offers a lock; the details read only.
- The attachment's lock is separate from the site's: its pages are routes of their own, so opening one from a site being edited does not end the site's sitting.
- The filename is never editable.
- Save writes the details as one History entry, through `PhotoEditSaveService.save` as the photo viewer does.
- New strings go into all 11 ARB files (ar, de, en, es, fr, he, hu, it, nl, pt, zh), with an `@key` description in `app_en.arb`, then `flutter gen-l10n`.
- Never an em-dash or en-dash as punctuation, in code, comments, commits or the PR. Nothing names Claude, Claude Code or Anthropic.
- Test commands name test FILES by path, never a folder, `test/architecture/` or `test/shared/`; the pre-push hook runs format, the whole-repo analyze and the guards.
- `dart format` the changed files before each commit.

## Review Focus

1. A document removed while its lock is open (deleted on another device): the sitting ends and says the document was removed, in document words, not "This photo was removed". Pinned in Task 2.
2. A site being edited, its Media card open, a PDF opened from it and closed again: the site's sitting is still open with its changes. Pinned in Task 4.
3. Leaving the details page with held changes (Back, the close button): asks first, as every sitting does. Pinned in Task 3.
4. Details set back to what is stored: nothing to save, Save disabled. Pinned in Task 2.
5. A browser: no lock on either page, the details page reads only. Pinned in Tasks 2 and 3.

## File Structure

- `lib/features/media/presentation/editing/photo_viewer_editing.dart` (modify): documents may unlock where a page says so; a removed document says so in its own words.
- `lib/features/media/presentation/editing/attachment_details_hold.dart` (create): holding a category and size in a photo sitting, shared by three pages.
- `lib/features/media/presentation/widgets/attachment_details_fields.dart` (create): the category and display size fields, out of the sheet, so the details page shows them too.
- `lib/features/media/presentation/widgets/attachment_details_sheet.dart` (modify): built from those fields.
- `lib/features/media/presentation/pages/document_viewer_page.dart` (modify): the PDF viewer's lock.
- `lib/features/media/presentation/pages/attachment_details_page.dart` (create): the details page.
- `lib/features/media/presentation/helpers/document_open_helper.dart` (modify): `attachmentLock` routing, and `share` lifted out of the PDF viewer.
- `lib/features/media/presentation/pages/site_media_viewer_page.dart` (modify): uses the shared hold.
- `lib/features/media/presentation/widgets/site_media_section.dart` and `site_attachment_groups.dart` (modify): no Edit details on a page that edits in place.
- `lib/features/dive_sites/presentation/pages/site_detail_page.dart` and `lib/features/dive_sites/presentation/editing/site_attachment_card_editors.dart` (modify): pass `attachmentLock`.

---

### Task 1: Documents in the photo sitting

**Files:**
- Modify: `lib/features/media/presentation/editing/photo_viewer_editing.dart`
- Create: `lib/features/media/presentation/editing/attachment_details_hold.dart`
- Modify: `lib/features/media/presentation/pages/site_media_viewer_page.dart:89-99` (`_holdDetails` goes)
- Modify: `lib/l10n/arb/app_*.arb` (11 files)
- Test: `test/features/media/presentation/editing/attachment_details_hold_test.dart` (create)

**Interfaces:**
- Produces: in `PhotoViewerEditing`, `bool get unlocksDocuments => false;` (a page that edits a document's details overrides it to true); `canUnlock(item, stored)` becomes `editingOffered && stored != null && (unlocksDocuments || !item.isDocument)`. `_lockAsGone` picks `l10n.media_viewer_documentGoneWhileEditing` for a document, as it picks the video message for a video.
- Produces: `void holdAttachmentDetails(EditSession<PhotoRecord>? sitting, SiteAttachmentCategory? category, AttachmentDisplaySize? size)` in `attachment_details_hold.dart`: sets `photoSiteCategoryField` and `photoDisplaySizeField`; does nothing for a null, disposed or frozen sitting (the body `_holdDetails` has today).
- Produces: ARB key `media_viewer_documentGoneWhileEditing`, en "This document was removed. Your changes were not saved." (the photo message's wording), translated in the other ten.

- [ ] **Step 1: Write the failing tests** in `attachment_details_hold_test.dart`, on an `EditSession<PhotoRecord>` over a stored document record:
  - `holds the category and the size in the sitting`: after `holdAttachmentDetails(session, SiteAttachmentCategory.siteMap, AttachmentDisplaySize.large)`, `session.valueOf(photoSiteCategoryField)` is `siteMap`, `session.valueOf(photoDisplaySizeField)` is `large`, and `session.changedCardIds` is `{photoDetailsCardId}`.
  - `a frozen sitting is left as it is`: `session.freeze()` first; both values stay as stored.
  - `no sitting is no write`: `holdAttachmentDetails(null, ...)` returns without throwing.
- [ ] **Step 2: Run, and watch them fail** (no such function).
  `flutter test test/features/media/presentation/editing/attachment_details_hold_test.dart`
- [ ] **Step 3: Implement** the function, the two `PhotoViewerEditing` changes and the ARB key (then `flutter gen-l10n`). `SiteMediaViewerPage` calls `holdAttachmentDetails(photoSitting, category, size)` in place of `_holdDetails`.
- [ ] **Step 4: Run the new test and the viewer's own:** both pass, and the site viewer's held Edit details still saves.
  `flutter test test/features/media/presentation/editing/attachment_details_hold_test.dart test/features/media/presentation/pages/site_media_viewer_unlock_test.dart`
- [ ] **Step 5: Commit** `refactor(media): a document's details can be held in the photo sitting`.

### Task 2: The PDF viewer's lock

**Files:**
- Modify: `lib/features/media/presentation/pages/document_viewer_page.dart`
- Modify: `lib/features/media/presentation/helpers/document_open_helper.dart`
- Modify: `lib/l10n/arb/app_*.arb` (11 files)
- Modify: `test/features/media/data/repositories/species_photo_fixtures.dart` (`insertTestMedia` gains `String? originalFilename`, written to the row)
- Test: `test/features/media/presentation/pages/document_viewer_unlock_test.dart` (create), `test/features/media/presentation/helpers/document_open_helper_test.dart`

**Interfaces:**
- Consumes: Task 1's `unlocksDocuments`, `canUnlock`, `holdAttachmentDetails`; `PhotoViewerEditing`'s `followStoredPhoto`, `unlockPhoto`, `photoEditScope`, `cancelPhotoSitting`, `savePhotoAndReport`, `shownItem`, `disposePhotoEditing`.
- Produces: `DocumentViewerPage({required MediaItem item, String? editableSiteId, bool attachmentLock = false})`. With `attachmentLock` and an `editableSiteId` the page has the lock; otherwise it is exactly today's page.
- Produces: `DocumentOpenHelper.open(context, ref, item, {String? editableSiteId, bool attachmentLock = false})`; a PDF passes `attachmentLock` on to the viewer.
- Produces: `static Future<void> DocumentOpenHelper.share(BuildContext buttonContext, WidgetRef ref, MediaItem item)`, the body of `_DocumentViewerPageState._share` moved out unchanged, so Task 3 shares the same way.
- Produces: the lock button's key `ValueKey('document_unlock')`; ARB key `media_documentViewer_editing`, en "Editing document".

The page's state mixes in `PhotoViewerEditing<DocumentViewerPage>`, with `unlocksDocuments => true`, `editingOffered => widget.attachmentLock && widget.editableSiteId != null && super.editingOffered`, and `onPhotoLocked() {}`. Locked, the bar is today's title and Share, with the lock (`Icons.lock_outline`, tooltip `recordEdit_unlockTooltip`) where Edit details was, enabled when `canUnlock(widget.item, stored)`. Unlocked, the bar is `RecordEditBar(title: media_documentViewer_editing, canSave, isSaving, onCancel: cancelPhotoSitting, onSave: savePhotoAndReport, actions: [Edit details])`, whose Edit details opens `showAttachmentDetailsSheet(item: shownItem(widget.item, const []), siteId: widget.editableSiteId!, onHold: (c, s) => holdAttachmentDetails(photoSitting, c, s))`. The `Scaffold` goes inside `photoEditScope(child: ...)`, so Back and the close button ask first with changes.

- [ ] **Step 1: Write the failing tests** in `document_viewer_unlock_test.dart`, on the test database as `site_media_viewer_unlock_test.dart` is (`setUpTestDatabase`, `insertTestSite('s1', ...)`, `insertTestMedia(id: 'doc1', siteId: 's1', fileType: 'document', originalFilename: 'reef-map.pdf')`, `pumpViewerApp`, `settleViewer`, `eventCount`), opening `DocumentViewerPage(item: <doc1 as stored>, editableSiteId: 's1', attachmentLock: true)`:
  - `locked: the lock and Share, no Edit details, nothing written`: `find.byKey(ValueKey('document_unlock'))` one; `find.byTooltip('Edit details')` none; `eventCount` unchanged.
  - `unlocked: held details, one entry on Save`: unlock; `RecordEditBar` shows with "Editing document"; Edit details, pick "Site map", Done; the stored row's `siteCategory` is still null; Save; it is `SiteAttachmentCategory.siteMap`, the bar is gone, and `eventCount` rose by the events of one operation (as the site viewer's test reads it).
  - `Cancel with held details asks first`: hold a category, tap Cancel; the discard dialog shows; Keep editing keeps the bar.
  - `details set back to what is stored leave nothing to save` (Review Focus 4): hold "Site map", then hold "Uncategorized" again; Save is disabled.
  - `a document removed while unlocked ends the sitting in document words` (Review Focus 1): unlock, delete `doc1` from the database; the bar is gone and "This document was removed. Your changes were not saved." shows.
  - `opened from a dive it offers no lock`: no `editableSiteId`; no `document_unlock`, no Edit details.
  - `a browser offers no lock` (Review Focus 5): `pumpViewerApp(browser: true)`; no `document_unlock`, no Edit details.
  - `without attachmentLock it is today's viewer`: `editableSiteId: 's1'` only; Edit details shows and no lock (today's `document_viewer_page_test.dart` keeps covering what it does).
  - In `document_open_helper_test.dart`, `a PDF with attachmentLock opens the viewer locked`: `open(..., editableSiteId: 's1', attachmentLock: true)` pushes a `DocumentViewerPage` whose `attachmentLock` is true.
- [ ] **Step 2: Run them; they fail** (no `attachmentLock`).
  `flutter test test/features/media/presentation/pages/document_viewer_unlock_test.dart test/features/media/presentation/helpers/document_open_helper_test.dart`
- [ ] **Step 3: Implement** the page, the helper's parameter and `share`, the fixture's `originalFilename`, and the ARB key (then `flutter gen-l10n`).
- [ ] **Step 4: Run them with today's viewer test; all pass.**
  `flutter test test/features/media/presentation/pages/document_viewer_unlock_test.dart test/features/media/presentation/helpers/document_open_helper_test.dart test/features/media/presentation/pages/document_viewer_page_test.dart`
- [ ] **Step 5: Commit** `feat(media): the PDF viewer opened from a site has the attachment's own lock`.

### Task 3: The details page for a document with no viewer

**Files:**
- Create: `lib/features/media/presentation/widgets/attachment_details_fields.dart`
- Modify: `lib/features/media/presentation/widgets/attachment_details_sheet.dart`
- Create: `lib/features/media/presentation/pages/attachment_details_page.dart`
- Modify: `lib/features/media/presentation/helpers/document_open_helper.dart`
- Modify: `lib/l10n/arb/app_*.arb` (11 files)
- Test: `test/features/media/presentation/pages/attachment_details_page_test.dart` (create), `test/features/media/presentation/widgets/attachment_details_sheet_test.dart` (unchanged, proving the sheet still behaves on the extracted fields), `test/features/media/presentation/helpers/document_open_helper_test.dart`

**Interfaces:**
- Consumes: Task 1 and Task 2's names; `DocumentOpenHelper.share` and `openExternally`.
- Produces: `AttachmentDetailsFields({required SiteAttachmentCategory? category, required AttachmentDisplaySize? size, ValueChanged<SiteAttachmentCategory?>? onCategory, ValueChanged<AttachmentDisplaySize?>? onSize})`: the sheet's two dropdowns, the size's "Default (X)" label following the category; a null callback draws its dropdown disabled. The sheet keeps its own state and is built from it, unchanged to the diver.
- Produces: `AttachmentDetailsPage({required MediaItem item, required String siteId, bool? showOpen})`, `showOpen` defaulting to `HostPlatform.isDesktop` (Question 2; tests pass it).
- Produces: `DocumentOpenHelper.open` with `attachmentLock` and an `editableSiteId` pushes `AttachmentDetailsPage(item: item, siteId: editableSiteId)` as a `fullscreenDialog` for a document that is not a PDF; without them, today's external open.
- Produces: ARB keys `media_attachmentDetails_editing` en "Editing attachment", `media_attachmentDetails_open` en "Open".

The page mixes in `PhotoViewerEditing<AttachmentDetailsPage>` as the PDF viewer does (`unlocksDocuments => true`). Locked: an `AppBar` titled `media_siteAttachment_detailsTitle`, with the lock (`ValueKey('document_unlock')`) and Share (`DocumentOpenHelper.share`); the body is the filename with its extension, `AttachmentDetailsFields` with no callbacks over the stored record, and Open (`DocumentOpenHelper.openExternally`) where `showOpen`. Unlocked (Question 3): `RecordEditBar(title: media_attachmentDetails_editing, ...)` as in Task 2, with no actions, and the fields' callbacks set the sitting through `holdAttachmentDetails`, the values shown from the sitting. Inside `photoEditScope`.

- [ ] **Step 1: Write the failing tests** in `attachment_details_page_test.dart`, on the test database as Task 2 (`insertTestMedia(id: 'doc2', siteId: 's1', fileType: 'document', originalFilename: 'briefing.docx')`), page opened with `showOpen: true` unless the test says otherwise:
  - `locked: the name, the details read only, Open and Share`: "briefing.docx" shows; both dropdowns are disabled (`onChanged` null); `media_attachmentDetails_open` and the Share tooltip show; `document_unlock` shows.
  - `unlocked: the details change in place, held until Save`: unlock; pick Category "Site map"; the stored row is unchanged; Save; it is `siteMap` and the page is locked again.
  - `Back with held changes asks first` (Review Focus 3): hold a category, `tester.binding.handlePopRoute()`; the discard dialog shows.
  - `Open is not offered where it would be Share`: `showOpen: false`; no Open.
  - `a browser reads only` (Review Focus 5): `browser: true`; no `document_unlock`; dropdowns disabled.
  - In `document_open_helper_test.dart`: `a document with no viewer and attachmentLock opens its details page`: a `briefing.docx` item, `open(..., editableSiteId: 's1', attachmentLock: true)`; `AttachmentDetailsPage` shows, and the unavailable-on-device message from `openExternally` does not.
- [ ] **Step 2: Run them; they fail** (no page).
  `flutter test test/features/media/presentation/pages/attachment_details_page_test.dart test/features/media/presentation/helpers/document_open_helper_test.dart`
- [ ] **Step 3: Implement** the fields widget (and the sheet on it), the page, the helper's routing, and the ARB keys (then `flutter gen-l10n`).
- [ ] **Step 4: Run them with the sheet's users; all pass.**
  `flutter test test/features/media/presentation/pages/attachment_details_page_test.dart test/features/media/presentation/helpers/document_open_helper_test.dart test/features/media/presentation/widgets/attachment_details_sheet_test.dart test/features/media/presentation/pages/document_viewer_unlock_test.dart test/features/media/presentation/pages/site_media_viewer_unlock_test.dart test/features/media/presentation/pages/document_viewer_page_test.dart`
- [ ] **Step 5: Commit** `feat(media): a document with no viewer opens a details page with its own lock`.

### Task 4: The site page opens its attachments under their lock

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page.dart` (the media card's `onOpenDocument`)
- Modify: `lib/features/dive_sites/presentation/editing/site_attachment_card_editors.dart`
- Modify: `lib/features/media/presentation/widgets/site_media_section.dart`
- Modify: `lib/features/media/presentation/widgets/site_attachment_groups.dart` (`onEditDetails` becomes nullable; null draws no Edit details menu on a large card)
- Test: `test/features/media/presentation/widgets/site_media_section_test.dart`, `test/features/dive_sites/presentation/editing/site_attachment_card_editors_test.dart`, `test/features/dive_sites/presentation/pages/site_detail_page_unlock_test.dart`

**Interfaces:**
- Consumes: `DocumentOpenHelper.open(attachmentLock:)` from Tasks 2 and 3.
- Produces: the site page's Media card calls `DocumentOpenHelper.open(context, ref, item, editableSiteId: site.id, attachmentLock: widget.unlockEditing)`; the open card's editor (`SiteMediaCardEditor`), built only on a page that edits in place, passes `attachmentLock: true`.
- Produces: `SiteMediaSection` on a page that edits in place (`RecordEditScope.maybeOf<DiveSite>(context) != null`, the test it already makes for `_readOnly`) offers no single Edit details: no `editDetails` bulk action, and `SiteAttachmentGroups(onEditDetails: null)`. Set category stays, locked or unlocked. With no scope (the switch off), as today.

- [ ] **Step 1: Write the failing tests:**
  - In `site_media_section_test.dart`, `on a page that edits in place Edit details is gone, Set category stays`: the section under a `RecordEditScope<DiveSite>` (a locked `RecordEditController<DiveSite>`), one large-card attachment; enter selection, check one; `find.byKey(ValueKey('selection_action_editDetails'))` none and `selection_action_setCategory` one; out of selection, the large card has no `media_siteAttachment_moreOptions` menu.
  - In `site_attachment_card_editors_test.dart`, `the open Media card opens a document under its lock`: tapping a `briefing.docx` tile in `SiteMediaCardEditor` shows `AttachmentDetailsPage` (override `photoRecordProvider('doc2')` with its record, or the test database as Task 3).
  - In `site_detail_page_unlock_test.dart`, `opening a PDF from the open Media card keeps the site's sitting` (Review Focus 2): unlock, type in Notes, open the Media card (`mediaForSiteProvider('s1')` overridden with one `reef-map.pdf` item), tap it; `DocumentViewerPage` shows with `attachmentLock` true; close it; the site's `RecordEditBar` is still there and "Choppy" still shows.
- [ ] **Step 2: Run them; they fail.**
  `flutter test test/features/media/presentation/widgets/site_media_section_test.dart test/features/dive_sites/presentation/editing/site_attachment_card_editors_test.dart test/features/dive_sites/presentation/pages/site_detail_page_unlock_test.dart`
- [ ] **Step 3: Implement** the two call sites, the section's test and the nullable `onEditDetails`.
- [ ] **Step 4: Run them; they pass.** Same command.
- [ ] **Step 5: Commit** `feat(sites): attachments open under their own lock, and Edit details leaves the Media card`.

### Finish

- [ ] `/code-review` at the agreed level with `--max-findings all`, every valid finding fixed.
- [ ] Open the PR: `Refs #4527`; screenshots of the PDF viewer locked and unlocked and the details page locked and unlocked, phone and desktop widths (a new screen, so after shots only; no colour changes), through the project's secret gist, taken as headless goldens from a throwaway test in the scratchpad that is never committed; Auto-fix on.
