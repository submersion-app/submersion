# Unified editing, sites, plan 3: the collections Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hold every change to a site's collections in the sitting, written with the site in one transaction and one History entry: site types (header block), tags, expected species, features (on the fullscreen map), media, documents, sharing with other profiles (with the "Shared with" line on the locked page), and the catalogue offer's Review (issue #4527, phase 2). Still behind `kUnlockSiteEditing`.

**Architecture:** Plans 1 and 2 (PRs #4686, #4688) put the site page on `RecordEditHost<_SiteDetailContent, DiveSite>` with every plain column on a card. Collections are not columns of `DiveSite`, so each becomes a held change on its card: `SittingList<DiveSite, E>` for types, tags, species and features; the dive's media and document-link sittings, made generic over the record type, for media and documents; small held changes for sharing and the catalogue link. The site save starts passing the sitting's held writes, as the dive's does, and stamps a library site's changed collections only after the commit. A held write that is refused throws `RecordSittingRefusal`, which rolls the whole Save back and names what was refused.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), drift (SQLite), `flutter gen-l10n` (one new string).

**Spec:** [docs/design/specs/2026-11-17-unified-editing-phase-2-sites-design.md](../specs/2026-11-17-unified-editing-phase-2-sites-design.md), sections "The site page's cards", "What is held, and what is not", "Attachments" (the Media card's part) and "Saving".

## Global Constraints

- Built on the names plans 1 and 2 shipped: `RecordEditHost` (`onSittingStart`, `saveSitting`, `addStripEntries`), `SiteEditSaveService.save(..., writeFirst, alsoWrite, alsoWriteIsAChange)`, `siteEditCards`, `siteHeaderCard`, `SiteHeaderCardEditor`, `_SiteDetailPageEditing._framed`, `siteSittingFields`, `site_location_rules.dart` (`moveSiteTo`, `scheduleAltitudeAfterMove`). This branch stacks on PR #4688; rebase onto `origin/main` once #4686 and #4688 merge, before the first push.
- With `kUnlockSiteEditing` false the site page looks and behaves exactly as today, and so do the dive page and every other `DocumentsSection` owner: no existing test changes its expectations. Where a shared piece changes type (the media and document-link sittings), the dive's tests pass unchanged; that is the proof nothing moved.
- With the switch on, the locked page writes nothing on any tap: the collections' add, edit, remove and Review controls appear only in an open card's editor.
- Not held, as on a dive: a site type created from "manage types" and a tag created in the tag picker exist at once and survive Cancel.
- An attachment's own details (category, display size) are the attachment's record, not the site's: the Media card's Edit details and the bulk Set category stay as they are in this plan (plan 4 gives attachments their lock).
- Library stamps (`LibraryEditStamper.stamp`) for anything the sitting writes run only after the commit, best effort, as plan 1's `stampLibraryEdit` does.
- One new string, in every ARB file, then `flutter gen-l10n`: `diveSites_edit_catalogueRefused` ("The catalogue record has changed or is linked to another site. Nothing was saved."), translated for each locale. Added in Task 8.
- Never use em-dashes or en-dashes as punctuation. Commits, the PR and files follow the repository guide's Attribution section.
- Test runs: only the test files a task writes or changes, by literal path, at most 15 per run. Never a folder, never the whole suite, never guards by hand: the pre-push hook runs them.
- Never `--build-filter` build_runner.

## Review Focus

1. **A sync changes a collection mid-sitting** (a tag or feature added on another device after the sitting loaded). Save keeps it: each list writes only the difference between what it loaded and the diver's list. Pinned in Task 2 (types and tags, which go through `replaceTypes`/`replaceTags` and so need the merge) and Task 4 (features).
2. **A held write fails after the row was written** (the catalogue link refused, sharing refused). Nothing is written, the page stays unlocked with the sitting intact, and the snack bar names what was refused. Pinned in Tasks 1, 7 and 8.
3. **Cancel after adding photos, a document, species, features and tags.** Nothing is in the database afterwards; the media rows were never written. Pinned in Task 9.
4. **The fullscreen map opened while locked, or from a card other than Features while unlocked.** It places nothing, and a feature tapped there offers no Edit. Pinned in Task 4.
5. **A library site's collections changed in a sitting.** The library store is stamped only once the sitting has committed, and not at all when the Save fails. Pinned in Task 1.

## Preparation

- [ ] On branch `ericgriffin/unified-editing-sites-3-collections` (cut from plan 2's head). Generate code unfiltered in the background if the worktree is fresh: `dart run build_runner build --delete-conflicting-outputs`.
- [ ] `flutter analyze` on the whole repository is clean.
- [ ] Commit this plan: `git add docs/design/plans/2026-11-17-unified-editing-sites-3-collections.md && git commit -m "docs(sites): unified editing phase 2 plan 3"`.

## File Structure

New:

| File | Responsibility |
| --- | --- |
| `lib/shared/widgets/record_editing/record_sitting_refusal.dart` | `RecordSittingRefusal`: a held write the database refused, with its message |
| `lib/features/dive_sites/presentation/editing/site_sitting_start.dart` | `startSiteSitting`, `siteLibraryFields`: what a site sitting loads as it starts, and which library fields its held writes touched |
| `lib/features/dive_sites/presentation/editing/site_classification_sitting.dart` | `siteTypesList`, `siteTagsList` |
| `lib/features/dive_sites/presentation/editing/site_species_sitting.dart` | `siteSpeciesList` |
| `lib/features/dive_sites/presentation/editing/site_features_sitting.dart` | `siteFeaturesList` |
| `lib/features/dive_sites/presentation/editing/site_sharing_sitting.dart` | Sharing held on the header block |
| `lib/features/dive_sites/presentation/editing/site_catalogue_sitting.dart` | The offer's Review held on the header block |
| `lib/features/dive_sites/presentation/editing/site_collection_card_editors.dart` | Tags, Expected species, Features editors |
| `lib/features/dive_sites/presentation/editing/site_attachment_card_editors.dart` | Media and Documents editors |
| `lib/features/media/presentation/editing/record_media_sitting.dart` | The dive's media sitting, generic over the record type (moved) |
| `lib/features/documents/presentation/editing/record_document_links_sitting.dart` | The dive's document-link sitting, generic over the record type (moved) |

Moved away (their content goes to the generic files above): `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_media_sitting.dart`, `dive_document_links_sitting.dart`.

Modified, by task: see each task's Files block.

---

### Task 1: Held writes reach the site's Save; refusals and library stamps

**Files:**
- Create: `lib/shared/widgets/record_editing/record_sitting_refusal.dart`, `lib/features/dive_sites/presentation/editing/site_sitting_start.dart`
- Modify: `lib/shared/widgets/record_editing/record_edit_host.dart` (`saveAndReport`), `lib/features/dive_sites/data/services/site_edit_save_service.dart`, `lib/features/dive_sites/presentation/pages/site_detail_page_editing.dart` (`saveSitting`, `onSittingStart`)
- Test: `test/shared/widgets/record_editing/record_edit_host_test.dart` (existing; add a case), `test/features/dive_sites/data/services/site_edit_save_service_test.dart` (existing; add cases)

**Interfaces:**
- Produces:
  - `class RecordSittingRefusal implements Exception { const RecordSittingRefusal(this.message); final String Function(AppLocalizations l10n) message; }`. `RecordEditHost.saveAndReport` shows `error.message(l10n)` when `controller.saveError` is one, else `recordEdit_saveFailed` as now.
  - `SiteEditSaveService(SiteRepository sites, {LibraryEditStamper? stamper})`; `save(...)` gains `Set<String> Function()? heldLibraryFields`. After the commit (with the existing `stampLibraryEdit`, in the same guarded block) it stamps `heldLibraryFields()` on the site through `stamper.stamp(siteId, fields, actingDiverId:)` when non-empty, then calls `SyncEventBus.notifyLocalChange()` once.
  - `site_sitting_start.dart`:
    - `void startSiteSitting(EditSession<DiveSite> session, ProviderRead read)`: empty here; each later task adds its load, as `startDiveSitting` does.
    - `void noteSiteLibraryFields(EditSession<DiveSite> session, Set<String> fields)`: a held write records the library fields it touched (note key `'site.libraryFields'`).
    - `Set<String> siteLibraryFields(EditSession<DiveSite> session)` and `void clearSiteLibraryFields(EditSession<DiveSite> session)`.
  - `saveSitting` clears the noted fields, then calls `service.save` with `writeFirst`, `alsoWrite`, `alsoWriteIsAChange` exactly as the dive page passes them (`dive_detail_page_editing.dart:169-173`) and `heldLibraryFields: () => siteLibraryFields(session)`. `onSittingStart` calls `startSiteSitting(session, container.read)`.

- [ ] **Step 1: Write the failing tests.**
  - Host: `a refused held write shows its own message`: a fake record type whose save throws `RecordSittingRefusal((_) => 'Refused here')`; after Save the snack bar reads `Refused here`, the controller is still unlocked.
  - Save service (test database, a fake `LibraryEditStamper` recording calls):
    - `held writes run in the sitting's transaction`: `alsoWrite` inserts a `site_tags` row then throws; afterwards the row change and the tag are both absent.
    - `held library fields are stamped after the commit`: `heldLibraryFields` returns `{'features'}`; the fake records one `stamp(siteId, {'features'})`, made after `save`'s transaction has committed (the fake reads the site row's new value).
    - `a failed save stamps nothing`: `alsoWrite` throws; the fake records no call.
- [ ] **Step 2:** Run both files. Expected: compile failures (`RecordSittingRefusal`, `heldLibraryFields` undefined).
- [ ] **Step 3:** Implement as the Interfaces block says.
- [ ] **Step 4:** Run both files and `test/features/dive_sites/presentation/pages/site_detail_page_unlock_test.dart`. Expected: pass.
- [ ] **Step 5: Commit** `feat(sites): the site's Save runs its held writes, stamps the library after the commit, and names a refusal`.

### Task 2: Site types on the header block, tags on their card

**Files:**
- Create: `presentation/editing/site_classification_sitting.dart`
- Modify: `presentation/editing/site_header_card_editor.dart` (types), `presentation/editing/site_collection_card_editors.dart` (create; tags), `presentation/editing/site_edit_cards.dart`, `presentation/editing/site_sitting_start.dart`, `presentation/widgets/site_detail_header.dart` (`types` override), `presentation/widgets/site_tags_card.dart` (`tags` override), `presentation/pages/site_detail_page.dart`
- Test: `test/features/dive_sites/presentation/editing/site_classification_sitting_test.dart`, `test/features/dive_sites/presentation/editing/site_header_card_editor_test.dart` (existing; add cases), `test/features/dive_sites/presentation/editing/site_collection_card_editors_test.dart`

**Interfaces:**
- Consumes: Task 1's `noteSiteLibraryFields`, `startSiteSitting`.
- Produces:
  - `final siteTypesList = SittingList<DiveSite, SiteTypeEntity>(key: 'site.types', cardId: siteHeaderCardId, ...)` and `final siteTagsList = SittingList<DiveSite, Tag>(key: 'site.tags', cardId: SiteDetailSectionId.tags.name, ...)`. `read`: `SiteClassificationRepository`'s reads behind `siteTypesForSiteProvider` / `tagsForSiteProvider`. `same`: equal id sets. `write`: the ids stored now, less those loaded and removed, plus those added, through `replaceTypes` / `replaceTags(siteId, ids, notify: false)`; then `noteSiteLibraryFields(session, {'siteTypes'})` / `{'tags'}`. (`replaceTypes` replaces the whole set, so the merge is what keeps a type a sync added meanwhile.) A `SittingList`'s `read` and `write` see only the record, so each constructs its repository as `diveSightingsList` constructs `SpeciesRepository()`; Tasks 3 and 4 do the same.
  - `startSiteSitting` loads both.
  - Header editor: the form's type chips (`TypeTagsSection`'s `FilterChip` wrap through `visibleBuiltIns`, with its "manage types" link) bound to `siteTypesList`.
  - `SiteTagsCardEditor({required EditSession<DiveSite> session})`: `TagFormBlock(scope: TagScope.sites)` bound to `siteTagsList`, as `DiveTagsCardEditor`.
  - `siteEditCards[tags]`: `isEmpty: (_) => false` (locked, `SiteTagsCard` decides, as `EditCard.isEmptyInSitting`'s rule says) with `isEmptyInSitting: (s) => siteTagsList.current(s)?.isEmpty ?? false` (not offered before the list has loaded). The page's tags section decides presence from the sitting's list once changed, else from `tagsForSiteProvider` as today.
  - `SiteDetailHeader({..., List<SiteTypeEntity>? types})` and `SiteTagsCard({..., List<Tag>? tags})`: when given, shown instead of the provider's. The page passes `siteTypesList.current(session)` / `siteTagsList.current(session)` while the list `isChanged`.

- [ ] **Step 1: Write the failing tests.**
  - Sitting (test database): `types write only the difference` (load `{a, b}`, set `{b, c}`, then store `{a, b, d}` underneath; Save leaves `{b, c, d}`); the same for tags; `writing notes the library field`.
  - Header editor: `tapping a type chip holds it and dots the header`; `the header shows the sitting's types while changed`.
  - Tags editor: `adding a tag holds it`; `a tag created in the picker survives Cancel` (the tag row exists after `cancelSitting`).
- [ ] **Step 2:** Run the three files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the three files. Expected: pass.
- [ ] **Step 5: Commit** `feat(sites): hold site types and tags in the sitting`.

### Task 3: Expected species

**Files:**
- Create: `presentation/editing/site_species_sitting.dart`
- Modify: `presentation/editing/site_collection_card_editors.dart`, `presentation/editing/site_edit_cards.dart`, `presentation/editing/site_sitting_start.dart`, `lib/features/marine_life/presentation/widgets/site_marine_life_section.dart` (`species` override, `onEdit`), `presentation/pages/site_detail_page.dart`
- Test: `test/features/dive_sites/presentation/editing/site_species_sitting_test.dart`, `test/features/dive_sites/presentation/editing/site_collection_card_editors_test.dart`

**Interfaces:**
- Produces:
  - `final siteSpeciesList = SittingList<DiveSite, SiteSpeciesEntry>(key: 'site.species', cardId: SiteDetailSectionId.marineLife.name, read: getExpectedSpeciesForSite, same: equal speciesId sets, write: ...)`. `write` removes loaded entries the diver dropped that are still stored (`removeExpectedSpecies(..., stampLibrary: false)`) and adds new species (`addExpectedSpecies(..., stampLibrary: false)`, which throws when the profile may not edit, failing the Save); then notes `{'species'}`. This replaces `setSpecies`'s delete-all-then-add for the sitting.
  - `SiteSpeciesCardEditor({required EditSession<DiveSite> session})`: the list as the section draws it, an Add button opening `SpeciesPickerDialog(initialSelection:)`, and a remove per row. Picked ids not yet in the list become entries built from `SpeciesRepository.getAllSpecies(ids:)` (fresh id, `speciesName`, `category`).
  - `SiteMarineLifeSection({..., List<SiteSpeciesEntry>? species})`: shown instead of the provider's when given. On a page that hosts editing it is `readOnly` (its pencil is the card's).
  - `siteEditCards[marineLife]`: `isEmpty: (_) => false` (always on the page today).

- [ ] **Step 1: Write the failing tests.** Sitting: `removing and adding writes only the difference`; `a species added on another device meanwhile survives`; `a refused add fails the Save` (a library site this profile reads: the held write throws, nothing written). Editor: `picking species holds them and dots the card`; `the section shows the sitting's species while changed`.
- [ ] **Step 2:** Run. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run. Expected: pass.
- [ ] **Step 5: Commit** `feat(sites): hold expected species in the sitting`.

### Task 4: Features, and the fullscreen map that obeys the lock

**Files:**
- Create: `presentation/editing/site_features_sitting.dart`
- Modify: `lib/features/dive_sites/domain/entities/site_feature.dart` (value equality), `lib/features/dive_sites/data/repositories/site_feature_repository.dart` (`stampLibrary` on add, update, delete), `presentation/editing/site_collection_card_editors.dart`, `presentation/editing/site_edit_cards.dart`, `presentation/editing/site_sitting_start.dart`, `lib/features/site_scape/presentation/site_features_section.dart`, `lib/features/site_scape/presentation/site_feature_marker_layer.dart`, `presentation/pages/site_detail_page.dart` (`_showFullscreenMap`, the preview map), `presentation/pages/site_detail_page_fullscreen_scape.dart`
- Test: `test/features/dive_sites/presentation/editing/site_features_sitting_test.dart`, `test/features/dive_sites/presentation/editing/site_collection_card_editors_test.dart`, `test/features/dive_sites/presentation/pages/site_fullscreen_scape_lock_test.dart`

**Interfaces:**
- Produces:
  - `SiteFeature` gains `operator ==` and `hashCode` over every field.
  - `addFeature`, `updateFeature`, `deleteFeature` gain `bool stampLibrary = true`; false skips `_libraryStamper.stamp` only.
  - `final siteFeaturesList = SittingList<DiveSite, SiteFeature>(key: 'site.features', cardId: SiteDetailSectionId.features.name, read: getFeaturesForSite, write: ...)`. `write`, as `diveSightingsList` writes: a loaded feature dropped and still on the site is deleted, a loaded one changed is updated, one the sitting added (an id not loaded) is added under the repository's own id; all with `stampLibrary: false`; then notes `{'features'}`.
  - Functions over the sitting: `void addFeatureInSitting(EditSession<DiveSite> session, SiteFeature feature)`, `void updateFeatureInSitting(...)`, `void removeFeatureInSitting(EditSession<DiveSite> session, String id)`.
  - `SiteFeatureMarkerLayer({required String siteId, List<SiteFeature>? features, bool readOnly = false, ValueChanged<SiteFeature>? onEdit})`: `features` drawn instead of the provider's; `readOnly` offers no Edit in the info sheet; `onEdit` replaces `editSiteFeature`. With none given it behaves as today (the site map page).
  - `SiteFeaturesSection({..., List<SiteFeature>? features, ValueChanged<SiteFeature>? onTapFeature})`: rows tap `onTapFeature` when given, else today's behaviour when `onAddFeature` is set, else nothing.
  - `_FullscreenSiteScapePage({..., EditSession<DiveSite>? session, bool readOnly = false})`, following `FullscreenProfilePage`: listens to `session`; with a live session, a tap places into the sitting (`showSiteFeatureSheet`, then `addFeatureInSitting`) and markers draw `siteFeaturesList.current(session)` with `onEdit` going to the sitting; with `readOnly`, or a session that has ended, it places nothing and offers no Edit.
  - `SiteFeaturesCardEditor({required EditSession<DiveSite> session})`: the feature rows (tap: `showSiteFeatureSheet(existing:)`, then update or remove in the sitting) and "Add on the map", which pushes the fullscreen page with `session`.
  - Where the page opens the fullscreen map other than from the Features editor (the seascape card, the terrain button, the preview map), and on the preview map's marker layer: `readOnly: true` while the page hosts editing. With the switch off, unchanged.
  - `siteEditCards[features]`: `isEmpty: (site) => !site.hasCoordinates`, `offeredWhenEmpty: (s) => s.working.hasCoordinates`.

- [ ] **Step 1: Write the failing tests.**
  - Sitting (test database): `add, change and remove write the difference`; `a feature added on another device meanwhile survives`; `writes skip the library stamp and note it`.
  - Editor: `editing a feature in the sheet holds it`; `removing holds it`; the card's read rows show the sitting's list while changed.
  - Fullscreen: `opened from a locked page it places nothing` (a tap on the map shows no sheet; a marker's info sheet has no Edit); `opened from the Features editor a placed feature goes to the sitting` (the sheet's Save adds it to `siteFeaturesList.current`, no row written); `the session ending makes it read only`.
  - Strip: `features are not offered without coordinates`.
- [ ] **Step 2:** Run the three files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the three files and `test/features/site_scape/presentation/site_feature_marker_layer_test.dart` if it exists. Expected: pass.
- [ ] **Step 5: Commit** `feat(sites): hold features in the sitting; the fullscreen map obeys the lock`.

### Task 5: The media and document-link sittings, generic over the record

**Files:**
- Create: `lib/features/media/presentation/editing/record_media_sitting.dart`, `lib/features/documents/presentation/editing/record_document_links_sitting.dart`
- Delete: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_media_sitting.dart`, `dive_document_links_sitting.dart` (content moved)
- Modify: every importer of the two (`dive_edit_cards.dart`, `dive_detail_page_editing.dart`, `dive_media_section.dart`, `dive_media_card_editor.dart`, `documents_section.dart` and their tests' imports), `lib/features/documents/data/repositories/document_repository.dart`, `lib/features/media/presentation/helpers/media_hold.dart` (`networkPreview` carries `siteId`)
- Test: the existing tests of the two moved files (moved beside them, assertions unchanged), `test/features/documents/data/repositories/document_repository_test.dart` (existing; add a case)

**Interfaces:**
- Produces, each function now generic `<T>` over `EditSession<T>`, names unchanged:
  - Media: `holdSittingMedia<T>(EditSession<T> session, SittingMediaWriters writers, {required String cardId})` (the card id is kept with the writers, used by the held change); `SittingMediaWriters` gains a constructor-supplied `unlink`, with `SittingMediaWriters.forDive(ProviderRead read)` (today's `.read`, `unlinkFromDive`) and `SittingMediaWriters.forSite(ProviderRead read)` (`MediaUnlinkService.unlinkFromSite`, the same deletion coordinator with `holdRemoteDelete: true`; `replace` unused for sites and throws `UnsupportedError`). `sittingMedia`, `addMediaToSitting`, `unlinkMediaInSitting`, `replaceLinkInSitting`, `mediaAfterCommit`, `undoMediaOnFailure`, `mediaInSitting`, `mediaKey`: same behaviour, generic.
  - Documents: `holdDocumentLinks<T>(EditSession<T> session, ProviderRead read, {required DocumentOwnerKind kind, required String cardId})`; the held write sets the owner through `DocumentRepository.setOwner(kind, ids, ownerId)` and re-reads `getForOwner(DocumentOwner(kind, id))`. `attachDocument`, `detachDocument`, `documentsInSitting`, `sittingDocumentLinks`, `documentLinksKey`: same, generic.
  - `DocumentRepository.setOwner(DocumentOwnerKind kind, List<String> documentIds, String? ownerId)`: `setDiveOwner`'s rule for any owner column in `kDocumentOwnerColumns` (sets that column, clears the others; null leaves the document personal). `setDiveOwner` delegates to it.
  - `DocumentsSection<T>({..., EditSession<T>? editing})` reads `RecordEditScope.maybeOf<T>`; the dive's callers write `DocumentsSection<Dive>`. Other owners (trips, gear) are unchanged: with no scope of their type they behave as now.
  - `networkPreview` sets `siteId: request.siteId` as well as `diveId`.
- The dive passes `cardId: DiveDetailSectionId.media.name` / `.documents.name` and `kind: DocumentOwnerKind.dive`.

- [ ] **Step 1: Write the failing test.** Repository: `setOwner moves documents to a site and back to personal`. Move the two sittings' existing tests beside the new files, changing only imports.
- [ ] **Step 2:** Run the repository test and the two moved test files. Expected: compile failures.
- [ ] **Step 3:** Move and generalise; update every importer.
- [ ] **Step 4:** Run the moved tests, the repository test, and the dive's `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_media_card_editor_test.dart` and `test/features/documents/presentation/widgets/documents_section_test.dart` (by path; skip one that does not exist). Expected: pass, assertions unchanged.
- [ ] **Step 5: Commit** `refactor(media): the media and document-link sittings are generic over the record`.

### Task 6: The site's Media and Documents cards

**Files:**
- Create: `presentation/editing/site_attachment_card_editors.dart`
- Modify: `lib/features/media/data/services/media_import_service.dart` (`prepareForSite`), `lib/features/media/presentation/helpers/site_media_import_helper.dart` (`onHold`), `lib/features/media/presentation/providers/files_tab_providers.dart` and `lib/features/media/presentation/widgets/files_tab.dart` (hold for a site), `lib/features/media/presentation/widgets/site_media_section.dart` (`editing`), `presentation/editing/site_edit_cards.dart`, `presentation/editing/site_sitting_start.dart`, `presentation/pages/site_detail_page.dart`, `presentation/pages/site_detail_page_editing.dart` (`saveSitting`: `undoMediaOnFailure`, `mediaAfterCommit`)
- Test: `test/features/media/data/services/media_import_service_test.dart` (existing; add a case), `test/features/dive_sites/presentation/editing/site_attachment_card_editors_test.dart`

**Interfaces:**
- Consumes: Task 5's generic sittings.
- Produces:
  - `MediaImportService.prepareForSite({required List<AssetInfo> selectedAssets, required String siteId}) -> Future<List<PreparedMedia>>`: what `importPhotosForSite` would write, deduplicated the same way, each under a fresh id, no enrichment. Writes nothing.
  - `SiteMediaImportHelper.importPhotosForSite({..., MediaHoldSink? onHold})`: with `onHold`, the picker opens with it (`showPhotoPicker(onHold:)`), and a returned selection is prepared (`prepareForSite`) and handed to `onHold` as `HeldMediaRow`s instead of written.
  - The Files tab holds for a `SiteAttachTarget` as it does for a dive: `FilesTabNotifier.heldSiteRows(String siteId)` builds the rows `commit(target: SiteAttachTarget)` would write, without writing.
  - `SiteMediaSection({..., EditSession<DiveSite>? editing})`: as `DiveMediaSection` does, a `RecordEditScope<DiveSite>` above it with no `editing` makes it read only (no add, no unlink); with `editing` it shows `mediaInSitting(editing, stored)`, its adds go through `addMediaToSitting` (photos via `onHold`, documents via `DocumentOpenHelper.pickAndAttach(siteId:, onHold:)`) and its unlink through `unlinkMediaInSitting`. A held row cannot be opened, checked for Set category, or given Edit details until saved. Edit details and Set category on stored rows stay as today, locked or not.
  - `SiteMediaCardEditor` and `SiteDocumentsCardEditor({required EditSession<DiveSite> session})`: `SiteMediaSection(editing:)` and `DocumentsSection<DiveSite>(owner: DocumentOwner(DocumentOwnerKind.site, id), editing:)` under a `ListenableBuilder`.
  - `startSiteSitting` calls `holdSittingMedia(session, SittingMediaWriters.forSite(read), cardId: 'media')` and `holdDocumentLinks(session, read, kind: DocumentOwnerKind.site, cardId: 'documents')`.
  - `saveSitting` wraps `service.save` in `undoMediaOnFailure(session, ...)` and, after the commit, runs each of `mediaAfterCommit(session)`, guarded, as the dive's follow-up does.
  - `siteEditCards[media]` and `[documents]`: `isEmpty: (_) => false`.

- [ ] **Step 1: Write the failing tests.**
  - `prepareForSite leaves out photos already on the site and writes nothing`.
  - Editors: `added photos show as held tiles and write nothing until Save` (a fake `MediaHoldSink` source); `unlinking a stored attachment holds it`; `a held row cannot be opened`; `the locked page's Media card offers no add or unlink`; `attaching a document holds it on the Documents card`; `Save writes the media rows and the document's site owner in one History entry` (test database; one change log operation, its label naming the site and the Media and Documents cards).
- [ ] **Step 2:** Run both files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run both files. Expected: pass.
- [ ] **Step 5: Commit** `feat(sites): hold media and documents in the sitting`.

### Task 7: Sharing on the header block, and the "Shared with" line

**Files:**
- Create: `presentation/editing/site_sharing_sitting.dart`
- Modify: `presentation/editing/site_header_card_editor.dart`, `presentation/editing/site_sitting_start.dart`, `presentation/pages/site_detail_page.dart` (the line), `test/features/dive_sites/data/services/site_edit_save_census_test.dart` (`is_shared`'s reason)
- Test: `test/features/dive_sites/presentation/editing/site_sharing_sitting_test.dart`, `test/features/dive_sites/presentation/editing/site_header_card_editor_test.dart`, `test/features/dive_sites/presentation/pages/site_detail_page_sharing_unlock_test.dart`

**Interfaces:**
- Produces:
  - `void loadSiteSharing(EditSession<DiveSite> session, ProviderRead read)` (from `startSiteSitting`): reads `itemSharesRepository.storedProfileIds(SharedItemKind.site, id)` into the sitting as an `ItemSharing`, as the form's `_loadSharing` builds it, tracked; a failed read is noted, as the form's `_sharingUnread`.
  - `ItemSharing? siteSharingInSitting(EditSession<DiveSite> session)`, `bool siteSharingUnread(EditSession<DiveSite> session)`.
  - `void setSiteSharing(EditSession<DiveSite> session, ItemSharing next, {required String? actingDiverId})`: holds `'site.sharing'` on `siteHeaderCardId` (released when equal to the loaded value); its write calls `setSharing(SharedItemKind.site, id, next, actingDiverId:)` and throws `RecordSittingRefusal(sharingRefusedMessage)` when it returns false. Written after the row, so its `is_shared` stands.
  - Header editor: the form's `ItemSharingField`, offered under the form's condition (two or more divers, not a library site), `mayShare` as the form's `_mayShare`, read only while the sharing is unread.
  - The locked page, while it hosts editing, shows under the header for the owner the form's read row (`SharingTile`) when the site is shared with other profiles, under the same offering condition. With the switch off nothing changes, so `site_detail_page_sharing_test.dart`'s "the owner sees no Shared with row on the page" stands until plan 7.
  - Census: `is_shared` stays in `notASittingValue`, reason "written by the sharing held change".

- [ ] **Step 1: Write the failing tests.** Sitting: `choosing other profiles holds the change and dots the header`; `choosing the loaded value releases it`; `a refused share fails the Save with the sharing message` (`setSharing` returns false: nothing written, the row's other change rolled back). Header editor: `the sharing field is not offered with one diver` and `not for a library site`. Page (switch on): `the owner sees who the site is shared with`; `not shown when shared with no one`.
- [ ] **Step 2:** Run the three files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the three files and the census test. Expected: pass.
- [ ] **Step 5: Commit** `feat(sites): hold sharing on the header block; show who a site is shared with`.

### Task 8: The catalogue offer's Review, held

**Files:**
- Create: `presentation/editing/site_catalogue_sitting.dart`
- Modify: `lib/features/dive_sites/data/repositories/site_catalogue_fill_repository.dart` (`stampLibrary`), `lib/features/dive_sites/presentation/widgets/site_catalogue_offer_line.dart` (`onReviewed`), `presentation/editing/site_header_card_editor.dart`, `presentation/widgets/site_detail_header.dart`, `lib/l10n/arb/*.arb` (`diveSites_edit_catalogueRefused`)
- Test: `test/features/dive_sites/presentation/editing/site_catalogue_sitting_test.dart`, `test/features/dive_sites/presentation/widgets/site_catalogue_offer_line_test.dart` (existing; add cases)

**Interfaces:**
- Produces:
  - `applyFill` and `updateAnswers` gain `bool stampLibrary = true`; false skips their library stamp and notify only, and `CatalogueFillWrite` gains `Set<String> stamped` (the fields it would have stamped).
  - `void holdCatalogueReview(EditSession<DiveSite> session, CataloguePair pair, CatalogueComparisonResult result, {required String? actingDiverId, String? bodyOfWater})` (`bodyOfWater` as `CatalogueGapService.apply` works it out, `catalogueSeaInDiversLanguage`, when the field is chosen):
    - `ComparisonApply(fields)`: each chosen field is set on its card through the sitting, value for value as `applyFill`'s `_companion` writes it from `pair.record` (position through `moveSiteTo` then `scheduleAltitudeAfterMove` when the altitude is empty, as `apply`'s altitude follow-up; site types added to `siteTypesList`). Then held change `'site.catalogue'` on `siteHeaderCardId`, `beforeRecord: true`: `applyFill(siteId, record, fields: const {}, declined: pair.fields.difference(fields), stampLibrary: false)` (it works the offer out from the row as stored before the sitting's write, and only links and records the answers), throwing `RecordSittingRefusal((l) => l.diveSites_edit_catalogueRefused)` unless the outcome is `applied`, and noting `stamped`.
    - `ComparisonNotSame`, `ComparisonNoThanks`: the held change calls `updateAnswers` with `answerNotSame` / `declineAll`'s change, `stampLibrary: false`.
    - `ComparisonKept`: nothing.
  - `SiteCatalogueOfferLine({required DiveSite site, void Function(CataloguePair, CatalogueComparisonResult)? onReviewed, bool reviewable = true})`: with `onReviewed`, the comparison's result goes to it instead of the service; `reviewable: false` shows the line without Review. While the page hosts editing, the locked header passes `reviewable: false`, and the header block's editor shows the line with `onReviewed` holding the result. After a held Review the line is hidden for the rest of the sitting.

- [ ] **Step 1: Write the failing tests.**
  - Sitting (test database, a catalogue record offering position, depth and types): `applying fills the chosen fields on their cards` (location and depth dotted, types held, nothing written); `Save links the record and fills the fields in one History entry`; `a record claimed by another site meanwhile fails the Save with the catalogue message` (nothing written, page unlocked); `not the same and no thanks write only the answers at Save`.
  - Offer line: `with onReviewed the result is handed over and nothing is written`; `not reviewable shows no Review`.
- [ ] **Step 2:** Run both files. Expected: failures.
- [ ] **Step 3:** Add the string to every ARB file, run `flutter gen-l10n`, implement.
- [ ] **Step 4:** Run both files. Expected: pass.
- [ ] **Step 5: Commit** `feat(sites): hold the catalogue offer's Review in the sitting`.

### Task 9: One sitting, one History entry; Cancel leaves nothing

**Files:**
- Test: `test/features/dive_sites/presentation/pages/site_detail_page_collections_test.dart` (on plan 1's harness, with a test database)

**Interfaces:**
- Consumes: every card of Tasks 2 to 8. Adds no production code; a failure here is fixed in the owning task's files.

- [ ] **Step 1: Write the tests.**
  - `a sitting that changes several collections is one History entry and reverts as one`: unlocked, change a type, a tag, a species, a feature, sharing, attach a document and add a held photo; Save; exactly one change log operation, labelled for the site; reverting it restores every collection (the media row and the document's owner included). Before reverting, the page, locked again, shows the saved types, tags, species and features (the providers behind them follow the writes).
  - `Cancel after changing every collection writes nothing`: the same changes, then Cancel and confirm; every table as before, no `media` row added.
  - `the locked page makes no write on any collection's tap`: with the switch on and the site locked, tap the tags card, the species card, the features rows, the preview map's markers and the Media card; no repository write (a counting fake or row counts).
- [ ] **Step 2:** Run the file. Expected: pass; a failure is a defect in the owning task, fixed there with its own failing test first.
- [ ] **Step 3: Commit** `test(sites): a collections sitting is one History entry, and Cancel leaves nothing`.

### Task 10: Push, review, screenshots, PR

- [ ] **Step 1:** `git fetch origin main`; if #4686 and #4688 have merged, `git rebase origin/main` and run `flutter analyze` on the whole repository.
- [ ] **Step 2:** `dart format` changed files; whole-repo `flutter analyze` clean; push in the background (`git push -u origin HEAD`), touching no `lib/` or `test/` file meanwhile; fix what the hook finds, each fix its own commit.
- [ ] **Step 3:** `/code-review` with `--max-findings all`; fix every valid finding; push.
- [ ] **Step 4:** Headless screenshots as plans 1 and 2 took them (switch on, throwaway golden test, deleted after): the header block open with types and sharing, the locked header with the "Shared with" line, the Tags, Expected species and Features editors open, the Media card with held tiles; phone and desktop widths, light mode. Attach through the project's current screenshot gist.
- [ ] **Step 5:** `gh pr create` from the template, `Refs #4527`, base `main` once #4686 and #4688 have merged (until then base on plan 2's branch and say so); bind it and turn Auto-fix on.
