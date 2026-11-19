# Unified editing, phase 3, plan 2: species and documents Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A species page and a document page open locked and edit in place, every card of each held in one sitting written as one History entry, behind `kUnlockRecordEditing` (issue #4527, phase 3). Both edit forms stay until the switch-over plan; new records and the Documents card's Add are plan 11's.

**Architecture:** Each page's state mixes in `RecordEditHost` and `RecordOpenUnlocked` (both shipped), as the site page does, with its cards built as `EditCard`s keyed by the card ids plan 1 shipped (`SpeciesCardId`, `DocumentCardId`). A species sitting is over the stored `Species`; its tagged and added photos are held writes. A document sitting is over a small `DocumentRecord` (the row, its pages and its tags), because `DocumentRepository.save` already writes those three in one transaction. Each type gets a save service on `writeRecordSitting`, so the sitting is one transaction and one History entry. Whole-record operations run through `RecordEditController.runOperation`.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), drift, go_router, `flutter gen-l10n`.

**Spec:** [docs/design/specs/2026-11-18-unified-editing-phase-3-records-design.md](../specs/2026-11-18-unified-editing-phase-3-records-design.md), sections "Design: species", "Design: documents", "Design: rules every phase 3 type follows", "Values shown nowhere today" (the document's reminder lead) and "Testing"; on top of plan 1 ([2026-11-19-unified-editing-records-1-shared.md](2026-11-19-unified-editing-records-1-shared.md)).

## Global Constraints

- Phase 2's plans 6 and 7 may still change `lib/shared/widgets/record_editing/`. So merge origin/main before each task, and adapt to any renamed names. Bring main in with a merge (never a rebase or a force-push) and run a whole-repo `flutter analyze` after each merge.
- Built on the names already shipped: `RecordEditHost` (`hostsEditing`, `offersEditing`, `saveSitting`, `rereadStored`, `hostEditCards`, `storedForUnlock`, `editingTitle`, `addStripEntries`, `followStored`, `shownRecord`, `justSavedRecord`, `editScaffold`, `lockButton`, `saveLabel`, `beforeSave`), `RecordOpenUnlocked` (`openUnlockedOf`, `onOpenedSittingEnded`, `openUnlockedOnce`, `noteOpenedSittingEnded`), `RecordCardFrame`, `RecordCardHeader`, `EditCard`, `EditField`, `SittingList`, `writeRecordSitting`, `RecordSittingRefusal`, `recordOperationBlockOf`, `recordOperationRunnerOf`, `recordOperationReason`, `recordOperationCaption`, `confirmLeaveRecordSitting`, `kUnlockRecordEditing`, `SpeciesCardId`, `DocumentCardId`, and for photos `record_media_sitting.dart` (`mediaAfterCommit`, `undoMediaOnFailure`) and `MediaImportService` (`prepareForDive`, `prepareForSite`, `writePrepared`).
- With `kUnlockRecordEditing` false (the default) both pages, their routes and the documents list look and behave exactly as today: no existing test changes its expectations. Each page takes `unlockEditing` as a parameter that defaults to the switch, so tests can turn it on.
- A locked page writes nothing on any tap. History labels are `record_edit:species:<id>:<cards>` and `record_edit:documents:<id>:<cards>`, source "manual".
- Only what changed is written: each sitting's changes are applied to the record as stored at Save (`EditSession.applyTo`), and a field census test proves every column survives a change made underneath on a card the diver did not touch.
- Rules move from the forms unchanged (listed per task). Units follow the active diver's settings.
- New strings only where a task names one; each goes into all eleven ARB files, translated, then `flutter gen-l10n`.
- Never use em-dashes, and never en-dashes, double hyphens or spaced hyphens as prose punctuation, in code, comments, commits or the PR. Commits, the PR and files follow the repository guide's Attribution section.
- Imports grouped dart, flutter, packages, local. `dart format` changed files before each commit.
- Test runs: only the test files a task writes or changes, by path. Never a folder, never the whole suite, never `test/architecture/` or tagged `test/shared/` guards by hand: the pre-push hook runs them.
- Never `--build-filter` build_runner. Never let a debug build open `~/Documents/Submersion/submersion.db`.

## Review Focus

1. **A built-in species renamed in a sitting.** The editor shows and edits the stored English text; once it differs from the catalogue's, the page shows it as stored in every locale (`species_display.dart`), as the form does today. Pinned in Task 2.
2. **Photos tagged and photos added in one sitting, then Cancel.** Nothing is tagged, no photo is imported, no sighting is created on a dive. Pinned in Tasks 3 and 4.
3. **A card document (a certification card) unlocked.** Its owner and type cannot be changed, and it offers no title, expiry or reminder. Pinned in Task 7.
4. **A document's tags that could not be read when the sitting started.** The tags field reads only and Save leaves the stored tags as they are. Pinned in Task 6.
5. **A document page added while another device edits the document's title.** Save keeps the new title and adds the page. Pinned in Task 6 (census) and Task 8.

## Preparation

- [ ] The worktree is initialised (`git submodule update --init --recursive`, `flutter pub get`); generate code unfiltered in the background if fresh: `dart run build_runner build --delete-conflicting-outputs`.
- [ ] `git fetch origin main`, merge it, and run `flutter analyze` on the whole repository. Expected: clean.
- [ ] Commit this plan: `git add docs/design/plans/2026-11-19-unified-editing-records-2-documents-species.md && git commit -m "docs(editing): phase 3 plan 2, species and documents"`.

## File Structure

New, species (`lib/features/marine_life/...`):

| File | Responsibility |
| --- | --- |
| `data/services/species_edit_save_service.dart` | `SpeciesEditSaveService`, `speciesEditSaveServiceProvider` |
| `presentation/editing/species_edit_fields.dart` | The species' `EditField`s |
| `presentation/editing/species_edit_cards.dart` | `speciesEditCards`: header, description, photos |
| `presentation/editing/species_header_card_editor.dart` | Names, category, taxonomy class, the online lookup |
| `presentation/editing/species_photos_sitting.dart` | Photos tagged and added in the sitting, held |
| `presentation/pages/species_detail_page_editing.dart` | `part`: the page's use of the host |
| `presentation/pages/species_edit_routes.dart` | `speciesEditRedirect` |

New, documents (`lib/features/documents/...`):

| File | Responsibility |
| --- | --- |
| `presentation/editing/document_record.dart` | `DocumentRecord`: the row, its pages, its tags |
| `presentation/providers/document_record_provider.dart` | `documentRecordProvider` |
| `data/services/document_edit_save_service.dart` | `DocumentEditSaveService`, `documentEditSaveServiceProvider` |
| `presentation/editing/document_edit_fields.dart` | The document's `EditField`s and its rules |
| `presentation/editing/document_edit_cards.dart` | `documentEditCards`: pages, details |
| `presentation/editing/document_details_card_editor.dart` | The Details editor |
| `presentation/editing/document_pages_card_editor.dart` | The Pages editor (`DocumentPageStrip` over the sitting) |
| `presentation/pages/document_detail_page_editing.dart` | `part`: the page's use of the host |
| `presentation/pages/document_edit_routes.dart` | `documentEditRedirect`, `documentEditPane` |

Modified: `species_detail_page.dart` (a stateful page on the host), `species_tag_picker_page.dart` (a choose-only mode), `species_photo_import_helper.dart` (a prepare-only path), `document_detail_page.dart`, `document_details_panel.dart` (the reminder row; opens while its card is open), `documents_page.dart` (the pane's `editBuilder`), `app_router.dart` (redirects, `?mode=edit`, `onExit`), and `test/architecture/markdown_notes_adoption_test.dart` (two new Markdown editors; not run by hand).

---

### Task 1: The species save service and fields

**Files:**
- Create: `lib/features/marine_life/data/services/species_edit_save_service.dart`, `lib/features/marine_life/presentation/editing/species_edit_fields.dart`
- Test: `test/features/marine_life/data/services/species_edit_save_service_test.dart`

**Interfaces:**
- Produces:
  - `class SpeciesEditSaveService { SpeciesEditSaveService(SpeciesRepository species); Future<({Species before, Species after})?> save({required String speciesId, required Species Function(Species stored) apply, required Iterable<String> changedCardIds, Future<void> Function()? alsoWrite, bool alsoWriteIsAChange = false}) }`: `writeRecordSitting<Species>(table: 'species', ..., read: () => species.getSpeciesById(speciesId), write: (_, merged) => species.updateSpecies(merged))`. `final speciesEditSaveServiceProvider = Provider<SpeciesEditSaveService>((ref) => SpeciesEditSaveService(ref.watch(speciesRepositoryProvider)));`
  - In `species_edit_fields.dart`: `speciesCommonNameField` (`String`, card `header`), `speciesScientificNameField`, `speciesCategoryField` (`SpeciesCategory`), `speciesTaxonomyClassField`, all on `SpeciesCardId.header.name`; `speciesDescriptionField` (card `description`). The nullable ones take `String?` and store an empty or blank value as null. `Species.copyWith` cannot clear a field, so each `write` builds the `Species` through one private `_with(Species s, {...})` that copies every field, as the form's save does today.
- Consumes: `writeRecordSitting` (shipped).

- [ ] **Step 1: Write the failing tests** (test database; one species `manta`, common name `Manta`, scientific `Mobula birostris`, description `Big`):
  - `writes the changed names as one History entry`: apply sets the common name to `Giant manta`, cards `['header']`; stored common name is `Giant manta`; one operation labelled `record_edit:species:manta:header`.
  - `a field the sitting did not touch keeps its newer value` (census): rename the stored species' scientific name to `Mobula alfredi` after taking `apply` from a session started before it, then save a description change; both values are stored. One assertion per column `updateSpecies` writes (common name, scientific name, category, taxonomy class, description).
  - `clearing the scientific name stores null`: the field set to `''`; stored `scientificName` is null.
  - `unchanged returns null and writes nothing`; `a species that has gone throws` (`StateError`, no operation left).
- [ ] **Step 2:** Run `flutter test test/features/marine_life/data/services/species_edit_save_service_test.dart`. Expected: fails to compile.
- [ ] **Step 3:** Implement as the Interfaces block says.
- [ ] **Step 4:** Run the test file. Expected: all pass.
- [ ] **Step 5: Commit** `feat(marine-life): save a species' editing sitting as one History entry`.

### Task 2: The species page on the host, header and description

**Files:**
- Create: `lib/features/marine_life/presentation/editing/species_edit_cards.dart`, `species_header_card_editor.dart`, `lib/features/marine_life/presentation/pages/species_detail_page_editing.dart` (part)
- Modify: `lib/features/marine_life/presentation/pages/species_detail_page.dart`, `test/architecture/markdown_notes_adoption_test.dart` (the description editor's `MarkdownNotesField(`)
- Test: `test/features/marine_life/presentation/pages/species_detail_page_unlock_harness.dart`, `species_detail_page_unlock_test.dart`

**Interfaces:**
- Produces:
  - `SpeciesDetailPage({required String speciesId, bool unlockEditing = kUnlockRecordEditing, bool openUnlocked = false})`, now a `ConsumerStatefulWidget` whose state mixes in `RecordEditHost<SpeciesDetailPage, Species>` and `RecordOpenUnlocked`. `hostsEditing => widget.unlockEditing`. With it false the page builds today's tree.
  - `final Map<SpeciesCardId, EditCard<Species>> speciesEditCards`: `header` (`isEmpty: (_) => false`, `isValid`: the common name is not blank, as the form's validator), `description` (`isEmpty: (s) => (s.description ?? '').trim().isEmpty`, editor a `MarkdownNotesField` bound to `speciesDescriptionField`), `photos` (Task 3).
  - `SpeciesHeaderCardEditor({required EditSession<Species> session})`: common name (with the form's error `marineLife_speciesEdit_commonNameError` while blank), "Look up online" (`showSpeciesLookupSheet(context, initialQuery:)`; a `SpeciesLookupChosen` sets the common name, scientific name, taxonomy class and category through their fields, each a change of `header`), scientific name, category dropdown, taxonomy class. The editors edit the stored text, not the translation.
  - In the part: `saveSitting` calls `speciesEditSaveServiceProvider.save(speciesId: session.stored.id, apply: session.applyTo, changedCardIds: session.changedCardIds, alsoWrite:, alsoWriteIsAChange: session.hasHeldChanges)` (held writes from Tasks 3 and 4), sets `justSavedRecord`, then refreshes `speciesListNotifierProvider` guarded; `rereadStored` invalidates and reads `speciesProvider`; `editingTitle` is `recordEdit_editingTitle(species.localizedCommonName(l10n))`; `addStripEntries` offers Description while it is empty and not open; `followStored(speciesProvider(speciesId))` in `build`.
  - The header block and the Description card are wrapped in `RecordCardFrame<Species>` while editing is offered; the header gets a `RecordCardHeader`-style pencil row only while unlocked, so the locked page is unchanged. The Description card is built while it is open or added, even when empty.
  - The bar: the lock beside Edit, as on the site page (Edit stays until the switch-over).
  - Statistics, Where seen and Sightings are calculated: while unlocked each fades under `RecordCardFade` labelled `recordEdit_calculated`, as the site's calculated cards do.
- Consumes: Task 1.

- [ ] **Step 1: Write the harness and the failing tests.** The harness pumps `SpeciesDetailPage(speciesId: 'manta', unlockEditing: true)` with `speciesProvider('manta')` backed by a `StateProvider`, the insights, photos, where-seen and sightings providers overridden to empty, and `speciesEditSaveServiceProvider` overridden by a `FakeSpeciesSave` that records calls and can fail. Tests:
  - `with the switch off there is no lock`; `locked, no tap writes` (tap the header, the description, the photo buttons' places; the fake has no calls).
  - `unlocking marks the header and the description, and fades the calculated cards`.
  - `editing the description and saving writes one sitting and locks`.
  - `a blank common name stops Save and says why`: clear it; Save; `recordEdit_fixInvalid`; no call.
  - `the lookup fills the names, taxonomy and category as changes of the header`: a fake lookup sheet seam returns a `SpeciesLookupChosen`; `changedCardIds == {'header'}` and the four values are set.
  - `a built-in species edits its stored English name` (Review Focus 1): built-in `manta` under German; the editor reads the English stored name; after Save with a new name, the header shows the new name.
  - `an empty description is offered in the strip`; `a rename underneath keeps the description being edited`.
  - `Cancel with changes asks first`.
- [ ] **Step 2:** Run the two test files by path. Expected: compile failure, then failures.
- [ ] **Step 3:** Implement as the Interfaces block says; add the editor to the Markdown guard's list.
- [ ] **Step 4:** Run them, and `species_detail_page_suggest_test.dart` and `species_detail_page_stats_error_test.dart` unchanged. Expected: all pass.
- [ ] **Step 5: Commit** `feat(marine-life): unlock a species page to edit its names and description in place, behind a switch`.

### Task 3: Photos tagged in the sitting

**Files:**
- Create: `lib/features/marine_life/presentation/editing/species_photos_sitting.dart`
- Modify: `lib/features/media/presentation/pages/species_tag_picker_page.dart`, `lib/features/media/presentation/widgets/species_photos_section.dart`, `species_detail_page.dart`, `species_edit_cards.dart`
- Test: `test/features/marine_life/presentation/editing/species_photos_sitting_test.dart`, `test/features/media/presentation/pages/species_tag_picker_page_test.dart` (existing; add cases), `species_detail_page_unlock_test.dart`

**Interfaces:**
- Produces:
  - `SpeciesTagPickerPage({required String speciesId, bool chooseOnly = false, Set<String> alreadyChosen = const {}})`: with `chooseOnly` its confirm writes nothing and pops a `SpeciesTagChoice(mediaIds)`; `alreadyChosen` are left out of the candidates as tagged ones are. Without it, as today.
  - In `species_photos_sitting.dart`: `const String speciesTagsKey = 'species.tags'`; `void holdSpeciesTags(EditSession<Species> session, Iterable<String> mediaIds, ProviderRead read)`: adds to the held set (kept in the session's notes) and holds one change on card `photos` whose write is `speciesTaggingService.tagPhotos(mediaIds: held, speciesId:)`; `Set<String> heldSpeciesTags(EditSession<Species> session)`; `void releaseSpeciesTag(EditSession<Species> session, String mediaId)` (the held set without it; empty releases the change).
  - The Photos card: locked, its buttons are hidden (the page passes no callbacks); unlocked, Tag photos opens the picker with `chooseOnly: true` and holds the choice; the grid shows the held photos with the changed dot and a remove button each, ahead of the stored ones.
- Consumes: `SpeciesTaggingService.tagPhotos` (it also creates the sightings a dive photo needs), Task 2's `saveSitting` (its `alsoWrite` runs the held writes).

- [ ] **Step 1: Write the failing tests**:
  - Sitting: `holding tags is a change of Photos`; `releasing the last one is no change`; `the held write tags every held photo for the species` (a fake tagging service records the call).
  - Picker: `choose-only writes nothing and returns the choice`; `photos already chosen are not offered again`.
  - Page: `Tag photos while locked is not offered`; `tagged in a sitting, Save tags them once` (the fake save runs `alsoWrite`; the fake tagging service saw one call); `Cancel tags nothing` (Review Focus 2).
- [ ] **Step 2:** Run the three files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them, and `species_photos_section_test.dart` unchanged. Expected: all pass.
- [ ] **Step 5: Commit** `feat(marine-life): photos tagged on a species page wait for Save`.

### Task 4: Photos added in the sitting

**Files:**
- Modify: `lib/features/media/presentation/helpers/species_photo_import_helper.dart`, `species_photos_sitting.dart`, `species_detail_page_editing.dart`
- Test: `test/features/media/presentation/helpers/species_photo_import_helper_test.dart` (existing; add cases), `species_photos_sitting_test.dart`, `species_detail_page_unlock_test.dart`

**Interfaces:**
- Produces:
  - `SpeciesPhotoImportHelper.preparePhotosForSpecies(BuildContext, WidgetRef, {required String speciesId, pick}) -> Future<List<HeldSpeciesImport>?>`: the same picker and review page as `importPhotosForSpecies`, but the review's confirm prepares each resolved photo for its dive or site (`MediaImportService.prepareForDive` with `DiveGalleryLookup.correctedForDive`, as `importResolved` does, and `prepareForSite`) and returns them, writing nothing. A photo that cannot be prepared is reported on the review page as today. Equipment targets are prepared as `importResolved` does for them.
  - `HeldSpeciesImport({required PreparedMedia prepared, required MediaAttachTarget target})`.
  - `void holdSpeciesImports(EditSession<Species> session, List<HeldSpeciesImport> imports, ProviderRead read)`: holds one change on `photos` whose write is `writePrepared` for all held imports, then `tagPhotos` for the rows it wrote; what the import leaves for after the commit (uploads) goes into `mediaAfterCommit`, and what it did outside the database is taken back on failure (`undoMediaOnFailure`), as the dive's and site's Media cards do.
  - The page's Add photos, unlocked, calls `preparePhotosForSpecies` and holds the result; the grid shows the held imports as pending tiles with the changed dot and a remove button.
- Consumes: Task 3's photos sitting; Task 2's save path runs `mediaAfterCommit` after the commit, guarded.

- [ ] **Step 1: Write the failing tests**:
  - Helper: `prepare-only writes no media row and returns the prepared photos` (fake import service records prepare and write calls); `a photo that cannot be prepared is reported and left out`.
  - Sitting: `the held write writes the prepared rows, then tags them`; `a failing write takes back what it did outside the database`.
  - Page: `added in a sitting, Save imports and tags them once`; `Cancel imports nothing and creates no sighting` (Review Focus 2).
- [ ] **Step 2:** Run the three files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them. Expected: all pass.
- [ ] **Step 5: Commit** `feat(marine-life): photos added on a species page wait for Save`.

### Task 5: Species routes and operations

**Files:**
- Create: `lib/features/marine_life/presentation/pages/species_edit_routes.dart`
- Modify: `species_detail_page.dart` (menu), `species_detail_page_editing.dart`, `lib/core/router/app_router.dart`
- Test: `species_detail_page_unlock_test.dart`, `test/core/router/app_router_test.dart` (existing; add a case)

**Interfaces:**
- Produces:
  - `String? speciesEditLocation(String speciesId, {bool unlockEditing = kUnlockRecordEditing})`: `/species/$speciesId?mode=edit` with the switch, else null; `speciesEditRedirect(context, state)` for the `editSpecies` route. The `speciesDetail` route passes `openUnlocked: state.uri.queryParameters['mode'] == 'edit'`. Both species routes get `onExit: confirmLeaveRecordSitting`.
  - The menu gains Delete for a custom species (`!species.isBuiltIn`), as the manage page allows it: through `recordOperationRunnerOf(editController, record: 'species $id')` while editing is offered (disabled under `recordOperationCaption` while locked or with unsaved changes); it asks `isSpeciesInUse` first and shows `marineLife_species_delete_inUseError` when in use, else the manage page's confirmation, then `SpeciesListNotifier.deleteSpecies` and leaves the page. History, Open in Connections and Suggest for catalog work locked.
- Consumes: `RecordOpenUnlocked` (Task 2).

- [ ] **Step 1: Write the failing tests**:
  - `opened with mode=edit, the page is unlocked`.
  - `the edit address opens the page unlocked with the switch on` (router: `speciesEditLocation` for `manta` is `/species/manta?mode=edit`, null with the switch off).
  - `locked, Delete is disabled under "Unlock to use these"`; `unlocked with nothing to save, Delete asks, deletes and leaves`; `a species in use is not deleted and says why`; `a built-in species offers no Delete`.
  - `Suggest for catalog works while locked`.
- [ ] **Step 2:** Run the two files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them. Expected: all pass.
- [ ] **Step 5: Commit** `feat(marine-life): species edit address, delete as a whole-record operation`.

### Task 6: The document record, its provider and save service

**Files:**
- Create: `lib/features/documents/presentation/editing/document_record.dart`, `lib/features/documents/presentation/providers/document_record_provider.dart`, `lib/features/documents/data/services/document_edit_save_service.dart`
- Test: `test/features/documents/data/services/document_edit_save_service_test.dart`, `test/features/documents/presentation/providers/document_record_provider_test.dart`

**Interfaces:**
- Produces:
  - `@immutable class DocumentRecord { const DocumentRecord({required Document document, required List<DocumentPage> pages, required List<String>? tagIds}); }` with `copyWith` and value equality (`listEquals` for pages; tags compared as sets). `tagIds` null means the tags could not be read: they are not offered and not written. `String get id => document.id`.
  - `final documentRecordProvider = FutureProvider.family<DocumentRecord?, String>`: `getById`, `getPages(id, withBytes: false)`, and the tag ids from `tagLinkRepositoryProvider(TagScope.documents).getTagsFor(id)` (a failed tag read logs and gives null); refreshed on `watchChanges()` and the tag links' changes.
  - `class DocumentEditSaveService { DocumentEditSaveService(DocumentRepository documents, TagLinkRepository tags); Future<({DocumentRecord before, DocumentRecord after})?> save({required String documentId, required DocumentRecord Function(DocumentRecord stored) apply, required Iterable<String> changedCardIds}) }`: `writeRecordSitting(table: 'documents', read: <the provider's read, uncached>, write: (stored, merged) => documents.save(merged.document, merged.pages, tagIds: <merged.tagIds when they differ from stored's and are not null, else null>, notify: false))`. After the commit, best effort and logged, the reminder is re-armed as `DocumentMutations` does (`notificationSchedulerProvider.updateForDocument`); a failure there does not read as a failed save. `documentEditSaveServiceProvider`.
- Consumes: `DocumentRepository.save` (one transaction: row, other primaries cleared, pages, tags).

- [ ] **Step 1: Write the failing tests** (test database, diver `d1`, one insurance document `doc` with title `Travel`, one page, tag `t1`):
  - Provider: `reads the row, its pages without bytes, and its tags`; `a failed tag read gives null tags`.
  - Service: `writes a title change as one History entry` (label `record_edit:documents:doc:details`); `a field the sitting did not touch keeps its newer value` (census: one assertion per column `save` writes, each changed underneath while the sitting changes another); `a page added underneath survives a details save`; `unchanged tags are not written` (a spy `TagLinkRepository` sees no `replaceTags`); `null tags leave the stored tags alone` (Review Focus 4); `marking it primary clears another primary insurance in the same entry`; `a document that has gone throws`.
- [ ] **Step 2:** Run the two files. Expected: fail to compile.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them. Expected: all pass.
- [ ] **Step 5: Commit** `feat(documents): save a document's editing sitting as one History entry`.

### Task 7: The document page on the host: Details

**Files:**
- Create: `lib/features/documents/presentation/editing/document_edit_fields.dart`, `document_edit_cards.dart`, `document_details_card_editor.dart`, `lib/features/documents/presentation/pages/document_detail_page_editing.dart` (part)
- Modify: `lib/features/documents/presentation/pages/document_detail_page.dart`, `lib/features/documents/presentation/widgets/document_details_panel.dart`, `test/architecture/markdown_notes_adoption_test.dart`
- Test: `test/features/documents/presentation/pages/document_detail_page_unlock_harness.dart`, `document_detail_page_unlock_test.dart`, `test/features/documents/presentation/editing/document_edit_fields_test.dart`

**Interfaces:**
- Produces:
  - Fields on `DocumentRecord`, card `details`: owner, type, title, issuer, reference number, emergency phone, phone, primary, issue date, expiry date, reminder lead, notes; tags (`List<String>`, `equals` as sets). Each blank text stores null where the form's `_text` does.
  - Rules in `document_edit_fields.dart`, each a pure function the editor and the census both use: `bool documentOwnerLocked(Document d)` and `bool documentTypeLocked(Document d)` (a certification card); `List<DocumentType> documentTypeChoices(Document d)` (the form's `_typeChoices`); `bool documentHasTitleExpiryAndReminder(Document d)` (not a card); `bool documentKeepsPhonesAndPrimary(Document d)` (insurance); `int? storedReminderLead(int days)` (the default stored as null). Changing the type away from insurance clears the phones and primary; to a card is not offered.
  - `DocumentDetailsCardEditor({required EditSession<DocumentRecord> session})`: the form's fields (reusing `DocumentOwnerField`, `DocumentFormFields`, `ScopedTagsField`, `MarkdownNotesField`) bound to the sitting; the owner picker is `showDocumentOwnerPicker`; tags read only when `tagIds` is null.
  - `DocumentDetailPage({..., bool unlockEditing = kUnlockRecordEditing, bool openUnlocked = false, VoidCallback? onSittingEnded})`, its state on `RecordEditHost<DocumentDetailPage, DocumentRecord>` and `RecordOpenUnlocked`. It reads `documentRecordProvider` for the sitting and `documentEntryProvider` for the owner label as today; `followStored(documentRecordProvider(id))`. The page uses `editScaffold` in both hosts (its pane is a `Scaffold` today).
  - The details card (`DocumentDetailsCard`) is wrapped in `RecordCardFrame<DocumentRecord>` while editing is offered, and gains a Reminder row when an expiry is set and the reminder is not the default (spec, "Values shown nowhere today"), shown locked too, with the switch on only. Its label and value are the form's reminder dropdown label and option text, so no new string. On the narrow layout the details panel opens while the Details card is open, and the panel's own toggle is hidden while unlocked.
  - `editingTitle` uses `documentDisplayTitle`.
- Consumes: Task 6.

- [ ] **Step 1: Write the failing tests**:
  - Fields: `a certification card locks its owner and type and has no title, expiry or reminder` (Review Focus 3); `leaving insurance clears the phones and primary`; `the default reminder is stored as none`; `tags compare as sets`.
  - Page (harness pumping `DocumentDetailPage(documentId: 'doc', unlockEditing: true)` over overridden providers and a `FakeDocumentSave`): `with the switch off there is no lock`; `locked, no tap writes`; `editing the title and saving writes one sitting`; `the reminder row shows when set`; `on a narrow window the details open with their card`; `a card document's editor offers no owner, type, title, expiry or reminder change`; `tags that could not be read are shown read only`; `Cancel with changes asks first`.
- [ ] **Step 2:** Run the three files. Expected: failures.
- [ ] **Step 3:** Implement; add the editor to the Markdown guard's list.
- [ ] **Step 4:** Run them, and `document_detail_layout_test.dart`, `document_detail_delete_menu_test.dart`, `document_details_panel_test.dart` unchanged. Expected: all pass.
- [ ] **Step 5: Commit** `feat(documents): unlock a document page to edit its details in place, behind a switch`.

### Task 8: The document's Pages card

**Files:**
- Create: `lib/features/documents/presentation/editing/document_pages_card_editor.dart`
- Modify: `document_edit_cards.dart`, `document_detail_page.dart`
- Test: `test/features/documents/presentation/editing/document_pages_card_editor_test.dart`, `document_detail_page_unlock_test.dart`

**Interfaces:**
- Produces:
  - A `pages` field on `DocumentRecord` (card `pages`, `List<DocumentPage>`).
  - `DocumentPagesCardEditor({required EditSession<DocumentRecord> session, DocumentPageCapture? capture})`: `DocumentPageStrip(pages:, cardSlots: insurance or card, onChanged: <set the field>, onAdd: <the form's _addPage, moved here as a function both use>)`. Captured pages carry their bytes in the sitting until Save.
  - On the read page the viewer shows the sitting's pages. While unlocked, a Pages header row (`RecordCardHeader` titled `documents_pages_title`, with the pencil) sits above the viewer, and the open editor sits under it; locked, the page is unchanged. A document with no pages offers Pages in the strip.
- Consumes: Task 6, Task 7.

- [ ] **Step 1: Write the failing tests**:
  - Editor: `adding a page is a change of Pages`; `reordering is a change; reordering back is none`; `removing a page`.
  - Page: `a page added and saved is written with the sitting` (the fake save's `apply(stored).pages` has two pages); `a document with no pages offers Pages in the strip`; `a page added while the title changes underneath keeps both` (Review Focus 5); `locked, the page shows no Pages header`.
- [ ] **Step 2:** Run the two files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them, and `document_edit_page_test.dart` unchanged (the form uses the moved add function). Expected: all pass.
- [ ] **Step 5: Commit** `feat(documents): a document's pages are edited in place`.

### Task 9: Document hosts, routes and Delete

**Files:**
- Create: `lib/features/documents/presentation/pages/document_edit_routes.dart`
- Modify: `document_detail_page.dart`, `document_detail_page_editing.dart`, `lib/features/documents/presentation/pages/documents_page.dart`, `lib/core/router/app_router.dart`
- Test: `document_detail_page_unlock_test.dart`, `test/features/documents/presentation/pages/documents_pages_test.dart` (existing; add a case), `test/core/router/app_router_test.dart`

**Interfaces:**
- Produces:
  - `String? documentEditLocation(String id, {bool unlockEditing = kUnlockRecordEditing})` and `documentEditRedirect`; `Widget documentEditPane(BuildContext, String id, void Function(String) onSaved, VoidCallback onCancel, {bool unlockEditing = kUnlockRecordEditing})`: with the switch the page opened unlocked in the pane (`openUnlocked: true, onSittingEnded: onCancel`), else today's `DocumentEditPage`. `documents_page.dart`'s `editBuilder` uses it; its `createBuilder` stays the form (plan 11).
  - The `documentDetail` route passes `openUnlocked` from `?mode=edit`; `editDocument` redirects with the switch on; `/documents` and its `:documentId` route get `onExit: confirmLeaveRecordSitting`. The desktop redirect into the pane keeps `&mode=edit`, as the site page's does.
  - Delete runs through `recordOperationRunnerOf` while editing is offered, keeping its confirmation and its leave; History works locked.
- Consumes: Tasks 6 to 8.

- [ ] **Step 1: Write the failing tests**:
  - `opened with mode=edit, the page is unlocked`; `the pane's edit mode opens the page unlocked, not the form, and Cancel returns to view`; `the edit address opens the page unlocked with the switch on` (router); `locked, Delete is disabled under "Unlock to use these"`; `unlocked and clean, Delete asks and deletes`; `with the switch off the pane still opens the form`.
- [ ] **Step 2:** Run the three files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them. Expected: all pass.
- [ ] **Step 5: Commit** `feat(documents): document edit addresses and pane open the page unlocked; delete as a whole-record operation`.

### Task 10: Push and open the pull request

- [ ] **Step 1:** Merge origin/main once more; whole-repo `flutter analyze`; `dart format` every changed file. Expected: clean.
- [ ] **Step 2:** Push in the background (`git push -u origin HEAD`), touching no `lib/` or `test/` file while it runs. Fix any hook failure in its own commit.
- [ ] **Step 3:** `/code-review xhigh --fix --max-findings all`; fix every valid finding test first; push again.
- [ ] **Step 4:** Screenshots from headless widget-test goldens with the switch on (never `flutter test ... -d macos`): the species page locked, unlocked with the header open, and with photos held; the document page locked and unlocked (wide, and narrow with the details open), and the Pages editor; light and dark for the unlocked bars; attached through the project's current secret screenshot gist.
- [ ] **Step 5:** `gh pr create` from the template, title `feat(editing): species and documents edit in place, behind a switch`, body with `Refs #4527` and the screenshots; bind it and turn Auto-fix on.
