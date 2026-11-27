# Shared site library documents Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, natively in one session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Documents-card records on a shared site library site can be shared with the library, synced to every connected member with their page files, under the library's roles, merge rules, encryption, backups and removal rules.

**Architecture:** A shared document is a `documents` row with `shared_library_id` set and `diver_id` null, mirroring library sites. It travels as `documents/document-<id>.json` (per-field clocks and signatures, generalised from `SiteDocument`) plus immutable `pages/<fileId>.bin` files. A documents pass runs inside `SharedLibraryService._syncOnce` after the site push, and every library maintenance path (rotation, backup, restore, GC, removal, measurement) learns the two new folders.

**Tech Stack:** Flutter, Dart, Drift (SQLite), Riverpod, the shared library `CloudStorageProvider` transport, `FakeCloudStorageProvider` in tests.

**Spec:** `docs/design/specs/2026-11-27-shared-library-site-documents-design.md`

## Global Constraints

- `SharedLibraryLayout.formatVersion` stays `2`; the new folders are additive.
- Folder and file names: `documents/document-<id>.json`, `pages/<fileId>.bin`; `fileId` is a fresh random UUID v4 per page version.
- Signature domain tag for document fields: `ssl-doc-field:v1` (site fields keep `ssl-field:v1`).
- Private-by-default types on a library site: `receipt`, `insurance`, `medicalClearance`, `certificationCard`, `booking`.
- Fields that never travel: `diverId`, `reminderLeadDays`, `emergencyPhone`, `phone`, `isPrimary`, `createdAt`, `updatedAt`, `hlc`.
- Clocked document fields: `type`, `title`, `issuer`, `referenceNumber`, `issueDate`, `expiryDate`, `notes`, `tags`, `pages`, plus `deleted`. `siteId` is fixed, not clocked.
- Page GC: an owner's sync deletes a page file referenced by no document file and no retained backup, and older than 30 days.
- Each page is at most `kMaxDocumentPageBytes` (10 MB); no new limit.
- Schema rung v388; `minimumCompatibleSchemaVersion` stays 386.
- No file in `lib/core/database/tables/**` or `lib/core/database/migrations/**` may pass 800 lines; files already over 800 lines (`shared_library_service.dart`, `shared_library_transport.dart`, `shared_library_store.dart`, `shared_library_models.dart`, `document_repository.dart`, `site_detail_page.dart`, `sync_service.dart`, `sync_data_serializer.dart`) take new logic in `part` or companion files only.
- All new UI text localised in `app_en.arb` and the ten other locales.
- Every path built with `p.join` in tests; no literal `/tmp`.
- No em-dashes in code, comments, docs, commits or PR text.
- Local test runs: only the test files a task writes or changes, by path. Never a folder.

## Review Focus

1. **A diver's private document on a library site after the site leaves the device.** Expected: kept, on the personal copy of the site, never tombstoned on the diver's other devices. Pinned in Task 11.
2. **A shared document whose page file is missing, truncated or tampered with in storage.** Expected: the document stays hidden (no half-rendered pages), the sync does not fail, and it retries next sync. Pinned in Task 8.
3. **Two editors changing the same shared document's pages at once.** Expected: one page list wins per clock, the loser's page file is not collected for 30 days, and both devices converge. Pinned in Task 8.
4. **A reader's device.** Expected: never uploads a document or page file, never re-seals one, never collects one, and shows shared documents read-only. Pinned in Tasks 8, 13 and 14.
5. **A personal sync peer sending a row whose id is a local shared document** (another device of the diver before it learns the document was shared). Expected: ignored; the library row is never overwritten or tombstoned. Pinned in Task 9.

---

### Task 0: Before screenshots

- [ ] **Step 1:** Before any code change, read the screenshot memory notes (`project_macos_background_screenshots_window_resize.md`, `feedback_no_in_process_pr_screenshots.md`, `project_pr_screenshot_upload_routes.md`) and capture by the route they allow: the site detail Documents card of a library site (editor and reader), a document detail page on it, and the Documents page, light and dark, phone and desktop. Save them in the scratchpad as `<nn>-<screen>-before[-dark][-phone].png`.

### Task 1: Schema: nullable diver, library column, document state table

**Files:**
- Modify: `lib/core/database/tables/document_tables.dart` (diverId nullable, `sharedLibraryId`)
- Modify: `lib/core/database/tables/shared_library_tables.dart` (new `SharedDocumentStates`)
- Modify: `lib/core/database/database.dart` (register table, `currentSchemaVersion = 388`, append to `migrationVersions`)
- Create: `lib/core/database/migrations/helpers/shared_document_migrations.dart` (`part of '../app_database_migrations.dart'`)
- Modify: `lib/core/database/migrations/app_database_migrations.dart` (part line)
- Modify: `lib/core/database/migrations/ladder/rungs_v340_onward.dart` (v388 rung)
- Modify: `lib/core/database/migrations/before_open_table_backstops.dart` (call the assert)
- Modify: `lib/features/documents/domain/entities/document.dart`, `lib/features/documents/data/repositories/document_row_mapper.dart`
- Test: `test/core/database/migrations/v388_shared_documents_test.dart`, `test/features/documents/domain/document_test.dart` (extend if present, else create)

**Interfaces:**
- Produces: `Documents.diverId` nullable; `Documents.sharedLibraryId` (`TextColumn`, nullable); `DocumentPages.libraryFileId` (`TextColumn`, nullable: the `pages/<fileId>.bin` a shared page lives in); `DocumentPage.libraryFileId` (`String?`); table `SharedDocumentStates` (`@DataClassName('SharedDocumentStateRow')`) with `documentId` PK, `libraryId`, `siteId`, `clocksJson` default `'{}'`, `remoteModifiedTime` nullable, `dirty` default false, `deleted` default false, `parked` default false, `lastEditorMemberId`, `lastEditedAtMs`; `Document.diverId` is `String?`; `Document.sharedLibraryId` (`String?`); `Document.isShared => sharedLibraryId != null`; `copyWith` handles both (use the `_unset` sentinel for both nullable fields).
- Produces (migration extension): `Future<void> _assertSharedDocumentSchema()` on `AppDatabase`: calls `_dropNotNullByRebuild('documents', const {'diver_id': 'TEXT'})`, `_addMissingColumns('documents', {'shared_library_id': 'TEXT'})`, `_addMissingColumns('document_pages', {'library_file_id': 'TEXT'})`, and creates `shared_document_states` if missing. Idempotent; run by the v388 rung and by the backstop.

- [ ] **Step 1: Write the failing migration test** `v388 makes documents.diver_id nullable and keeps every row`: build a v387 database with a diver, a document, two pages and a document tag; run migration; assert `PRAGMA table_info('documents')` reports `diver_id` notnull 0, `shared_library_id` exists, the document, both pages and the tag link survive with identical values, `PRAGMA foreign_key_check` returns no rows, and `shared_document_states` exists. Second test `v388 is idempotent`: run `_assertSharedDocumentSchema` twice; no error, same schema.
- [ ] **Step 2: Run it**: `flutter test test/core/database/migrations/v388_shared_documents_test.dart`. Expected: FAIL (column still NOT NULL).
- [ ] **Step 3: Implement** the table changes, the helper, the rung (`if (from < 388) await _assertSharedDocumentSchema(); if (from < 388) await reportProgress();` with a comment naming issue #4713), the backstop call, the entity and mapper fields. Then fix every compile error from `Document.diverId` becoming nullable: callers that need a diver (`_clearOtherPrimaries`, `primaryInsuranceByDiver`, clearance supersession, notification payloads) use `doc.diverId!` only where the document is provably personal, or skip shared documents. Run `dart run build_runner build --delete-conflicting-outputs` in the background.
- [ ] **Step 4: Run** the migration test and `test/features/documents/domain/document_test.dart` (add `copyWith clears sharedLibraryId with null`). Expected: PASS. Run `flutter analyze`. Expected: no issues.
- [ ] **Step 5: Commit** `feat(shared-library): schema for shared site documents`.

### Task 2: Generic clocked records for merge and signatures

**Files:**
- Create: `lib/core/services/shared_library/clocked_record.dart`
- Modify: `lib/core/services/shared_library/site_document.dart`, `site_document_merge.dart`, `crypto/field_signatures.dart`
- Test: `test/core/services/shared_library/crypto/field_signature_domains_test.dart`; existing `site_document_merge_test.dart`, `site_document_test.dart` must stay green unchanged.

**Interfaces:**
- Produces: `abstract class ClockedRecord` with `String get id`, `bool get deleted`, `Map<String, Object?> get fields`, `Map<String, FieldClock> get clocks`, `Map<String, Object?> get extra`, `String get signatureDomain`, `ClockedRecord withContent({required bool deleted, required Map<String, Object?> fields, required Map<String, FieldClock> clocks, required Map<String, Object?> extra})`, and `static const deletedField = 'deleted'`.
- Produces: `class SiteDocument extends ClockedRecord` (`signatureDomain => 'ssl-field:v1'`; `withContent` returns `SiteDocument`; `SiteDocument.deletedField` kept as an alias).
- Produces: `MergeOutcome<T extends ClockedRecord>` (`merged`, `remoteWon`, `localWon`, `needsUpload`, `changesLocal`) and `MergeOutcome<T> mergeClockedRecords<T extends ClockedRecord>({required T local, required T remote})`; `SiteMergeOutcome` becomes `typedef SiteMergeOutcome = MergeOutcome<SiteDocument>` and `mergeSiteDocuments` delegates.
- Produces: `fieldSignatureMessage({required String domain, required String libraryId, required String recordId, ...})`; `signOwnFields`, `dropUnverified`, `dropUnverifiedAll`, `carryHeld` become generic `<T extends ClockedRecord>` and read the domain from the record. Site behaviour and message bytes are unchanged (`domain: 'ssl-field:v1'`, `recordId` = site id).

- [ ] **Step 1: Write failing tests** in `field_signature_domains_test.dart`: `a site field signature does not verify as a document field` (sign a `SiteDocument` field, copy its clocks and values into a `_TestDocRecord` whose `signatureDomain` is `ssl-doc-field:v1`, `dropUnverified` against an empty local drops the field); `site signature bytes are unchanged` (`fieldSignatureMessage(domain: 'ssl-field:v1', libraryId: 'L', recordId: 's1', field: 'name', hlc: h, memberId: 'm', value: 'Reef')` equals a fixed byte string captured from the current implementation before the change).
- [ ] **Step 2: Run** `flutter test test/core/services/shared_library/crypto/field_signature_domains_test.dart`. Expected: FAIL (no `domain` parameter).
- [ ] **Step 3: Implement** the base class and generalisation. `dropUnverified` builds its result with `remote.withContent(...)`.
- [ ] **Step 4: Run** the new test plus `site_document_merge_test.dart`, `site_document_test.dart`, `crypto/` signature test files that exist, `held_edits_test.dart`, `push_integrity_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `refactor(shared-library): clocked records shared by sites and documents`.

### Task 3: Library document record codec

**Files:**
- Create: `lib/core/services/shared_library/library_document_record.dart`
- Test: `test/core/services/shared_library/library_document_record_test.dart`

**Interfaces:**
- Produces: `class LibraryDocumentRecord extends ClockedRecord` with `final String siteId`, `signatureDomain => 'ssl-doc-field:v1'`, `static const fieldNames = ['type','title','issuer','referenceNumber','issueDate','expiryDate','notes','tags','pages']`, `static const listFields = {'tags','pages'}`, `static const neverTravels = {'diverId','reminderLeadDays','emergencyPhone','phone','isPrimary','createdAt','updatedAt','hlc'}`, `factory fromJson(Map<String,dynamic>)`, `Map<String,dynamic> toJson()`, `static Uint8List encode(LibraryDocumentRecord)`, `static LibraryDocumentRecord decode(Uint8List)`, `copyWith({bool? deleted, Map<String,Object?>? fields, Map<String,FieldClock>? clocks})`.
- Produces: `class LibraryPageRef` with `id`, `pageIndex`, `side` (`String?`), `fileName`, `mimeType`, `sizeBytes`, `fileId`, `sha256`; `fromJson`/`toJson`; `static List<LibraryPageRef> listFrom(Object? raw)` that skips malformed entries and any whose `fileId` fails `SharedLibraryTransport.isSafeFileId`.

- [ ] **Step 1: Write failing tests**: `round trip keeps fields, clocks and siteId`; `unknown top-level keys survive a round trip`; `a key in neverTravels is dropped on read and never written`; `a document without siteId or id throws FormatException`; `LibraryPageRef.listFrom skips an entry with an unsafe fileId`; `toJson writes formatVersion 2`.
- [ ] **Step 2: Run** the test file. Expected: FAIL.
- [ ] **Step 3: Implement** following `SiteDocument`'s shape.
- [ ] **Step 4: Run** the test file. Expected: PASS.
- [ ] **Step 5: Commit** `feat(shared-library): library document record codec`.

### Task 4: Document state in the library store

**Files:**
- Create: `lib/core/services/shared_library/shared_library_store_documents.dart` (`part of 'shared_library_store.dart'`, extension `SharedLibraryStoreDocuments`)
- Modify: `lib/core/services/shared_library/shared_library_store.dart` (part line; `deleteLibrary` and `clearRemoteStamps` also clear `shared_document_states`)
- Modify: `lib/core/services/shared_library/shared_library_models.dart` only to add `SharedDocumentState` if it fits; otherwise create `lib/core/services/shared_library/shared_document_state.dart`
- Test: `test/core/services/shared_library/shared_library_store_documents_test.dart`

**Interfaces:**
- Produces: `class SharedDocumentState` (`documentId`, `libraryId`, `siteId`, `clocks` (`Map<String, FieldClock>`), `remoteModifiedTime`, `dirty`, `deleted`, `parked`, `lastEditorMemberId`, `lastEditedAtMs`, `copyWith`).
- Produces on `SharedLibraryStore`: `Future<SharedDocumentState?> getDocumentState(String documentId)`, `Future<List<SharedDocumentState>> dirtyDocuments(String libraryId)`, `Future<Map<String, SharedDocumentState>> documentStates(String libraryId)`, `Future<void> putDocumentState(SharedDocumentState s)`, `Future<void> deleteDocumentState(String documentId)`, `Future<void> clearDocumentStampsForSite(String siteId)` (clears `remoteModifiedTime` and `parked` for that site's documents), `Stream<List<SharedDocumentState>> watchDocumentStates(String libraryId)`.

- [ ] **Step 1: Write failing tests**: put then get round-trips clocks; `dirtyDocuments` returns only dirty rows of that library; `clearDocumentStampsForSite` clears only that site's rows; `deleteLibrary` removes the library's document states; `clearRemoteStamps` clears document stamps too.
- [ ] **Step 2: Run** the file. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the file and `shared_library_store_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(shared-library): store document clocks and dirty flags`.

### Task 5: Transport for document and page files

**Files:**
- Create: `lib/core/services/shared_library/shared_library_transport_documents.dart` (`part of 'shared_library_transport.dart'`, extension `SharedLibraryTransportDocuments`)
- Modify: `lib/core/services/shared_library/shared_library_transport.dart` (part line; cached `_documents` and `_pages` folder ids; `_place` cases; `sealableFiles({bool withPages = true})` lists both folders; `snapshot()` calls `sealableFiles(withPages: false)`)
- Modify: `lib/core/services/shared_library/shared_library_models.dart` (`documentsDir = 'documents'`, `pagesDir = 'pages'`, `documentFile(id)`, `pageFile(fileId)`; add both to `reservedFolders`)
- Modify: `lib/core/services/shared_library/shared_library_transport_measure.dart` (walk both folders)
- Modify: the prefix check that uses `reservedFolders` so a library already connected under such a prefix still opens (only new connects are refused)
- Test: `test/core/services/shared_library/shared_library_transport_documents_test.dart`

**Interfaces:**
- Produces: `Future<List<CloudFileInfo>> listDocuments()`, `static String documentIdOf(CloudFileInfo f)`, `Future<LibraryDocumentRecord> readDocument(String fileId)`, `Future<DateTime?> writeDocument(LibraryDocumentRecord doc)` (same read-back rule as `writeSite`), `Future<List<CloudFileInfo>> listPageFiles()` (names ending `.bin`), `static String pageFileIdOf(CloudFileInfo f)`, `Future<Uint8List> readPageFile(String fileId)` (opened plain bytes), `Future<void> writePageFile(String pageFileId, Uint8List plain)` (sealed by path; skipped when a file of that name exists; no read-back), `Future<void> deletePageFile(String storageFileId)`.

- [ ] **Step 1: Write failing tests** on `FakeCloudStorageProvider`: write then read a document round-trips; `writeDocument` refuses an unsafe id with `ArgumentError`; a page written twice uploads once (count uploads on the fake); in an encrypted library a page file's stored bytes are sealed and `readPageFile` opens them; `sealableFiles()` lists `documents/...` and `pages/...`; `snapshot()` holds `documents/...` but no `pages/...`; `measureBytes` counts both folders; `writeRaw('pages/x.bin', ...)` does not throw.
- [ ] **Step 2: Run** the file. Expected: FAIL.
- [ ] **Step 3: Implement.** Page listing needs its own lister because `_listKind` accepts only `.json`.
- [ ] **Step 4: Run** the file and `shared_library_transport_test.dart`, `library_id_safety_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(shared-library): transport for shared documents and page files`.

### Task 6: Bridge between document rows and library records

**Files:**
- Create: `lib/core/services/shared_library/library_document_bridge.dart`
- Test: `test/core/services/shared_library/library_document_bridge_test.dart`

**Interfaces:**
- Consumes: `LibraryDocumentRecord`, `LibraryPageRef`, `SharedDocumentState`, `DocumentRepository`.
- Produces: `class LibraryDocumentBridge` with `Future<LibraryDocumentRecord> build(String documentId, SharedDocumentState state)` (fields from the row, pages from `document_pages` with each page's `sha256` of its bytes and its stored `fileId`; throws `StateError` when the row is gone and the state is not deleted, as the site bridge does) and `Future<void> apply(LibraryDocumentRecord doc, {required String libraryId, required String vocabularyDiverId, required Map<String, Uint8List> pageBytesBySha, Set<String>? fields})` (upserts the `documents` row with `sharedLibraryId = libraryId`, `diverId = null`, owner `siteId = doc.siteId`; replaces pages and tags; tags resolve by name against `vocabularyDiverId`, created when missing; never marks anything pending or logs tombstones).

- [ ] **Step 1: Write failing tests**: `build` reads every clocked field and a page list whose `sha256` matches the bytes; `build` twice gives the same `fileId`; a re-scanned page gets a new `fileId`; `apply` creates a library row with null diver and the site owner; `apply` with `fields: {'title'}` changes only the title; tags resolve case-insensitively against the diver's vocabulary; `apply` marks nothing pending (no new `pending_changes` rows) and logs no tombstones when it replaces pages.
- [ ] **Step 2: Run** the file. Expected: FAIL.
- [ ] **Step 3: Implement.** `build` gives a page with no `libraryFileId` a fresh UUID v4 and persists it, so the next build reuses it; `apply` writes the ref's `fileId` into `libraryFileId`. A page whose bytes change (`_replacePages` with new bytes) clears its `libraryFileId`.
- [ ] **Step 4: Run** the file. Expected: PASS.
- [ ] **Step 5: Commit** `feat(shared-library): bridge shared document rows and library files`.

### Task 7: Stamping, sharing and unsharing

**Files:**
- Create: `lib/core/services/shared_library/library_document_stamper.dart`
- Modify: `lib/features/documents/data/services/document_edit_save_service.dart` (stamp after commit), `lib/features/documents/data/repositories/document_repository.dart` via a new companion `document_library_rules.dart` for the default-sharing rule
- Modify: `lib/features/agent_access/data/writes/families/media_writes.dart` or the agent document write family that saves documents (stamp after commit)
- Test: `test/core/services/shared_library/library_document_stamper_test.dart`, `test/features/documents/domain/document_library_rules_test.dart`

**Interfaces:**
- Produces: `class LibraryDocumentStamper` with `Future<void> stamp(String documentId, Set<String> fields, {String? actingDiverId})`, `Future<bool> mayEdit(String documentId, {String? actingDiverId})` (false for readers and read-only libraries), `Future<void> share(String documentId, {required String libraryId, String? actingDiverId})` (in place: clears `diverId`, sets `sharedLibraryId`, logs personal tombstones for the document, its pages and tag links via `SyncRepository.logDeletions`, clocks every field, dirty state), `Future<String> unshare(String documentId, {required String actingDiverId})` (writes `deleted` with a fresh clock, dirty; creates a private copy under `unsharedDocumentId(documentId, actingDiverId)` with pages and tags, marked pending for personal sync; returns the copy's id).
- Produces: `String unsharedDocumentId(String documentId, String diverId)` (UUID v5, namespace distinct from `detachedSiteId`).
- Produces: `bool startsPrivateOnLibrarySite(DocumentType t)` (true for the five private types), `Future<String?> libraryOfSite(String siteId)`.
- Produces: on create through `DocumentEditSaveService.create`, when the owner is a library site, the acting diver is an editor or owner, and `!startsPrivateOnLibrarySite(type)`, the new document is shared before the method returns.

- [ ] **Step 1: Write failing tests**: `stamp advances clocks past existing ones and marks dirty`; `stamp on a personal document does nothing`; `share keeps the id, clears the diver and tombstones the personal rows`; `unshare tombstones the library record and leaves a private copy with the same pages`; `unsharedDocumentId is deterministic`; `a new map on a library site is shared`, `a new receipt, insurance, medical clearance, certification card or booking on a library site is private`, `a reader's new document on a library site is private`, `a document on a pushed site stays private` (push via `SharedSitePublisher.push`).
- [ ] **Step 2: Run** both files. Expected: FAIL.
- [ ] **Step 3: Implement.** Stamping runs after the sitting commits (a rollback does not undo store writes).
- [ ] **Step 4: Run** both files and `shared_site_publisher_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(shared-library): share, unshare and stamp site documents`.

### Task 8: The documents pass in library sync

**Files:**
- Create: `lib/core/services/shared_library/shared_library_document_sync.dart` (`part of 'shared_library_service.dart'`)
- Modify: `lib/core/services/shared_library/shared_library_service.dart` (constructor takes `LibraryDocumentBridge`, call the pass after the site push and before suggestions; counts join `pulled`/`pushed`)
- Modify: `lib/core/services/shared_library/shared_library_sync_parts.dart` (`_authorsValues`, `_claimUnattributed`, `_editedSince` generic over `ClockedRecord` where they are not already)
- Modify: `lib/features/shared_library/presentation/providers/shared_library_providers.dart` (wire the bridge)
- Modify: `lib/features/shared_library/presentation/providers/shared_library_sync_notifier.dart` (`_hasLocalWork` also checks `dirtyDocuments`)
- Test: `test/core/services/shared_library/shared_library_document_sync_test.dart`

**Interfaces:**
- Consumes: Tasks 2 to 7.
- Produces: `Future<({int pulled, int pushed, bool readOnly})> _syncDocuments(SharedLibraryTransport t, SharedLibrary library, {required String diverId, required _JudgedRoles judged, required Map<String, String> pendingKeys, required Map<String, LibrarySigningKey> localKeys, required bool holdWrites, required bool readOnly, required SharedLibraryRole role})`.

Pass order and rules (the spec's Sync section; all of these are this task's to implement):
1. List `documents/`; changed = stamp differs. Read each, `dropUnverifiedAll` with the same `judged` keys, merge with `mergeClockedRecords`.
2. Site rule: local site row with this `sharedLibraryId` exists, apply; site state `deleted`, store stamp and merged clocks, keep no row; no site file listed this sync, store stamp, `parked = true`. When the site pass creates or undeletes a site, it calls `clearDocumentStampsForSite(siteId)` (add that call in `_mergeRemote`).
3. Pages: for each `LibraryPageRef` whose `sha256` is not held locally, `readPageFile`, verify SHA-256, collect. If any page is missing or fails its hash, do not apply the record and do not store its stamp (retry next sync); log a warning.
4. Push: dirty states, skip when `readOnly` or the role is reader; `build`, upload page files missing from `listPageFiles()`, then `_authorsValues` / `carryHeld` / claim / sign as the site push does, `writeDocument`, record the stamp. A permission error sets read-only.
5. Wrong form: when the role is editor or owner and `!holdWrites`, rewrite every `t.mismatched` entry whose path starts with `documents/` or `pages/` (owners already rewrite all paths).
6. GC (owners only, `!holdWrites`): referenced = every `fileId` named by any non-deleted document file listed this sync plus every `fileId` in the backup index entries (Task 12 adds them; read an absent list as none); delete page files not referenced whose `modifiedTime` is more than 30 days before `_now()`.

- [ ] **Step 1: Write failing tests** using two or three `device(...)` services on one `FakeCloudStorageProvider` (extend the harness in `shared_library_service_test.dart` into a shared helper under `test/core/services/shared_library/support/` if it is not one already):
  - `an editor's shared document reaches a reader with every page`;
  - `a reader's device never uploads a document or page file` (fake upload count unchanged after the reader edits locally);
  - `a page file with the wrong bytes keeps the document hidden and retries` (corrupt the stored page; reader shows nothing; fix the file; next sync shows it);
  - `concurrent page edits converge` (two editors re-page the same document between syncs; after each syncs twice, both hold the same page list; the losing page file still exists);
  - `a document of a deleted site is not re-downloaded each sync` (count downloads across two syncs);
  - `a parked document appears when its site arrives`;
  - `undeleting a site brings its documents back with their pages`;
  - `GC deletes an unreferenced page file older than 30 days and keeps a young one and a referenced one` (inject `now`);
  - `a document field signed by an unknown member is not applied`;
  - `the sync notifier sees a dirty document as local work`.
- [ ] **Step 2: Run** the file. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the file plus `shared_library_service_test.dart`, `held_edits_test.dart`, `push_integrity_test.dart`, `unreadable_files_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(shared-library): sync shared documents and their pages`.

### Task 9: Personal-sync boundary for library documents

**Files:**
- Create: `lib/core/services/sync/library_document_guards.dart` (helpers: `Future<Set<String>> libraryDocumentIds(AppDatabase db)`, memoised per export like `librarySiteIds`)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (base export, `_exportDocuments`, `_exportDocumentPages`, `_exportDocumentTags`, incremental export, `_withPendingChildren`: skip library documents and their children)
- Modify: `lib/core/services/sync/sync_service.dart` (`_mergeEntity` ignores incoming `documents`, `documentPages`, `documentTags` rows whose local document is a library document; `_applyRemoteDeletions` ignores tombstones for them)
- Modify: `lib/core/data/repositories/sync_repository.dart` (`_personalOnly` leaves library documents out of writer clock seeds)
- Modify: `lib/features/documents/data/repositories/document_repository.dart` (`_deleteIds` and `_replacePages` log no tombstones and mark nothing pending for library documents; `setOwner` and `reassignOwner` refuse library documents)
- Test: `test/core/services/sync/library_document_boundary_test.dart`

**Interfaces:**
- Consumes: Task 1 columns.
- Produces: no new public API beyond the guard helper.

- [ ] **Step 1: Write failing tests** with the two-device convergence harness the library-site boundary tests use (find it with `grep -rln "sharedLibraryId" test/core/services/sync`): `a library document is never exported`; `a peer's personal row with a library document's id is ignored`; `a peer's tombstone for a library document is ignored`; `deleting a library document logs no personal tombstone`; `sharing a personal document tombstones it on the diver's other device, which then holds no copy until the library delivers it`.
- [ ] **Step 2: Run** the file. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the file and the existing library-site boundary test file(s) found in Step 1. Expected: PASS.
- [ ] **Step 5: Commit** `feat(sync): keep shared library documents out of personal sync`.

### Task 10: Library-aware document queries

**Files:**
- Create: `lib/features/documents/data/repositories/document_library_queries.dart` (companion to the repository)
- Modify: `lib/features/documents/data/repositories/document_repository.dart` (`getForOwner` delegates its library clause here), `lib/features/documents/presentation/providers/document_providers.dart` (`documentsForOwnerProvider` includes shared documents of the diver's libraries; new `sharedLibraryDocumentsProvider`)
- Test: `test/features/documents/data/document_library_queries_test.dart`

**Interfaces:**
- Produces: `Future<List<Document>> getForOwner(DocumentOwner owner, {String? diverId})` returns the diver's own plus shared documents whose `shared_library_id` is in the diver's memberships (reuse `VisibilityFilter`'s membership SQL fragment); `Future<List<DocumentListEntry>> getSharedForDiver(String diverId)` (shared documents of the diver's libraries, owner label = site name, grouped by library name); `final sharedLibraryDocumentsProvider = FutureProvider<List<DocumentListEntry>>`.
- Reminders, `attentionDocumentsProvider`, the home panel and `getAllForDiver` stay diver-only (assert, do not change).

- [ ] **Step 1: Write failing tests**: `a site's documents include shared ones for a member`; `a non-member profile on the same device does not see them`; `another profile's private document on the site is not shown`; `getAllForDiver leaves shared documents out`; `getRemindingForDiver leaves a shared document with an expiry out`.
- [ ] **Step 2: Run** the file. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the file. Expected: PASS.
- [ ] **Step 5: Commit** `feat(documents): show shared library documents on their site`.

### Task 11: Delete, leave and member removal

**Files:**
- Modify: `lib/core/services/shared_library/site_detacher.dart`
- Modify: `lib/features/dive_sites/data/repositories/site_repository_impl.dart` only through a small companion if the site's private-document check needs a query (`hasPrivateDocuments(siteId)` in `document_library_queries.dart`)
- Modify: `lib/core/services/shared_library/shared_library_membership_service.dart` (`_releaseLocalRows` also deletes document states of the library)
- Modify: `lib/core/services/shared_library/shared_site_publisher.dart` (`_deleteFromLibrary` leaves shared documents' files alone; the documents follow the site per the spec)
- Test: `test/core/services/shared_library/site_detacher_documents_test.dart`

**Interfaces:**
- Produces: `detachOrRemove` keeps the site when `hasLinks(siteId)` or the owner diver has a private document on it. On keep, each shared document of the site becomes a private document of `ownerDiverId` under `detachedDocumentId(documentId)` (UUID v5) with its pages and tags, marked pending; the library rows are deleted with no tombstones. On remove, shared documents are deleted with no tombstones, and the diver's private documents are never deleted (they force a keep).
- Produces: `String detachedDocumentId(String documentId)`.

- [ ] **Step 1: Write failing tests**: `a library site with only a private document is kept as a personal copy holding it`; `the private document is not tombstoned`; `a kept site's shared documents become private copies with their pages`; `a removed site's shared documents leave no personal tombstones`; `leaving a library removes its document states`; `a second device that detached first is relinked, not duplicated` (deterministic ids).
- [ ] **Step 2: Run** the file. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the file, `site_detacher_test.dart`, `shared_library_membership_service_test.dart`, `member_removal_sync_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(shared-library): shared documents follow their site on delete and leave`.

### Task 12: Backups by reference and restore

**Files:**
- Modify: `lib/core/services/shared_library/backup/library_backup_archive.dart` (`_kindFile` accepts `documents/document-<id>.json`; header `documentCount` (`int?`, absent on older backups))
- Modify: `lib/core/services/shared_library/backup/library_backup_service.dart` (count documents; write each backup's referenced page `fileId`s into its index entry as `pageFileIds`)
- Modify: `lib/core/services/shared_library/backup/library_restore_service.dart` (new `_restoreDocuments` in a part or companion file)
- Modify: `lib/core/services/shared_library/backup/library_backup_record.dart` if the index entry type lives there
- Test: `test/core/services/shared_library/backup/library_backup_documents_test.dart`

**Interfaces:**
- Produces: `LibraryBackupHeader.documentCount` (`int?`); backup index entry field `pageFileIds` (`List<String>`); `Future<Set<String>> retainedPageFileIds()` on the backup service, read by Task 8's GC.
- Restore rules: re-stamp every field with fresh clocks under the restoring owner and sign; skip (and count in the result) a document whose page files are not in `pages/`; tombstone shared documents created since the backup; a backup with `documentCount == null` touches no document.

- [ ] **Step 1: Write failing tests**: `a backup holds document files and no page files`; `its index entry lists the pages it needs`; `restore brings back a deleted shared document with its pages`; `restore tombstones a document made after the backup`; `restore of an older-app backup leaves shared documents alone`; `a device-only backup whose page files were collected restores the rest and reports the count`; `GC keeps a page file only a retained backup references`.
- [ ] **Step 2: Run** the file. Expected: FAIL.
- [ ] **Step 3: Implement.** Extend the archive's restore error copy to name a newer app when an unknown kind appears (existing `notABackup` path).
- [ ] **Step 4: Run** the file and the files in `test/core/services/shared_library/backup/` that this task changed behaviour for (by path). Expected: PASS.
- [ ] **Step 5: Commit** `feat(shared-library): back up and restore shared documents by reference`.

### Task 13: Encryption form of the new folders

**Files:**
- Modify: `lib/core/services/shared_library/library_encryption_service.dart` only if `_rewriteAll` needs `withPages: true` passed explicitly
- Test: `test/core/services/shared_library/library_encryption_documents_test.dart`

**Interfaces:**
- Consumes: Task 5 `sealableFiles(withPages: true)`, Task 8 rewrite rule.

- [ ] **Step 1: Write failing tests**: `turning encryption on seals document and page files`; `changing the passphrase re-seals them`; `turning it off writes them plain`; `a document file left plain by an older owner turning encryption on is re-sealed by an editor's sync` (write the file plain with `writeRaw`); `a document file left sealed after an older owner turned encryption off is re-written plain by an editor holding the old key`; `a reader's sync re-writes nothing`.
- [ ] **Step 2: Run** the file. Expected: FAIL for the editor cases.
- [ ] **Step 3: Implement** what fails.
- [ ] **Step 4: Run** the file and `library_encryption_service_test.dart`, `encryption_state_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(shared-library): keep shared documents in the library's encryption form`.

### Task 14: Screens

**Files:**
- Modify: `lib/features/documents/presentation/widgets/document_tile.dart` (subtitle: library name for shared, "Only you" for private on a library site; parameter `libraryLabel`)
- Modify: `lib/features/documents/presentation/widgets/documents_section.dart` (per-tile role: shared documents show "Remove from library" in the open card for editors and owners, no button for readers; readers can still add private documents)
- Modify: `lib/features/documents/presentation/editing/record_document_links_sitting.dart` (detaching a shared document records an unshare-or-remove instead of `setOwner(null)`; "Remove from library" writes the library tombstone on Save)
- Modify: `lib/features/dive_sites/presentation/editing/site_reader_sitting.dart` (`siteReaderPrivateCards` drops `'documents'`)
- Modify: `lib/features/documents/presentation/editing/document_details_card_editor.dart`, `document_edit_fields.dart` (`documentOwnerLocked` true while shared; "Share with <library>" switch for documents on a library site, shown to editors and owners; turning it off asks for confirmation naming the library, then calls `unshare`)
- Modify: `lib/features/documents/presentation/pages/document_detail_page.dart` and `document_detail_page_editing.dart` (read-only for readers: no pencil, no page edit, no delete; Export stays; attribution line "Last edited by <name>, <date>" and the library name for shared documents)
- Modify: the type field in `document_edit_fields.dart`: on a shared document whose type is changed to one of the private-by-default types, the switch sits beside the type and stays on (the type change does not unshare)
- Modify: `lib/features/documents/presentation/pages/documents_page.dart` (a "Shared libraries" filter chip that lists `sharedLibraryDocumentsProvider`)
- Modify: `lib/l10n/arb/app_en.arb` and the ten other locale files; regenerate
- Test: `test/features/documents/presentation/shared_documents_card_test.dart`, `test/features/documents/presentation/shared_document_detail_test.dart`, `test/features/documents/presentation/documents_page_library_filter_test.dart`

**Interfaces:**
- Consumes: Tasks 7, 10. Role from `libraryRoleProvider(libraryId)` and `libraryConnectedHereProvider(libraryId)`.
- New l10n keys (English values): `documents_libraryShare_switch` "Share with {library}", `documents_libraryShare_hint` "Every member of the library can open it", `documents_libraryShare_onlyYou` "Only you", `documents_libraryShare_removeFromLibrary` "Remove from library", `documents_libraryShare_unshareTitle` "Stop sharing with {library}?", `documents_libraryShare_unshareBody` "Other members lose this document on their next sync. You keep a private copy.", `documents_libraryShare_unshareConfirm` "Stop sharing", `documents_libraryShare_lastEdited` "Last edited by {name}, {date}", `documents_filter_sharedLibraries` "Shared libraries".

- [ ] **Step 1: Write failing widget tests**: card on a library site lists a shared and a private document with "Brest Dive Club" and "Only you" subtitles; an editor's open card offers "Remove from library" on the shared one; a reader's open card offers no remove on the shared one and still offers Add; a reader's detail page has no pencil or delete and has Export; the share switch is on for a shared map and turning it off shows the confirmation text; the owner field is locked while shared; the Documents page chip lists shared documents and the default list does not. Check each at phone width (390) and desktop width (1280), and with a 60-character title and library name.
- [ ] **Step 2: Run** the three files. Expected: FAIL.
- [ ] **Step 3: Implement** and add l10n in all eleven locales; run `flutter gen-l10n`.
- [ ] **Step 4: Run** the three files and `test/features/documents/presentation/` files this task changed (by path). Expected: PASS.
- [ ] **Step 5: Commit** `feat(documents): share site documents with a shared site library`.

### Task 15: Finish

- [ ] **Step 1:** `dart format .`, `flutter analyze` (no issues).
- [ ] **Step 2:** After screenshots of the site Documents card (editor and reader), the document detail page (shared, reader), the share switch and confirmation, and the Documents page filter, light and dark, phone and desktop.
- [ ] **Step 3:** Update `docs/design/specs/2026-10-12-shared-dive-site-library-design.md`'s "Out of scope" line to point at this design for documents.
- [ ] **Step 4: Commit** `docs(shared-library): note shared documents in the library design`.
