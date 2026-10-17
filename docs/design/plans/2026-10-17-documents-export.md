# Documents Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Export every document of the active diver into one ZipCrypto
password-protected ZIP with folders by filed-under record and a
`manifest.csv`, and give a dive one label everywhere (#3391).

**Architecture:** A pure domain layer plans the archive (paths, sanitizing,
collisions) and the manifest rows; a small ZipCrypto writer in
`lib/core/services/export/zip/` writes entries to a file one at a time; a
data-layer exporter reads page bytes per document and feeds the writer with
progress and cancellation; a presentation flow asks destination, then
password, shows progress and delivers via share or save. The dive label is a
domain value built from raw parts in SQL and formatted in presentation.

**Tech Stack:** Flutter, Riverpod, Drift, `archive` 4.0.9 (test oracle only),
`dart:io` raw Deflate (`ZLibCodec(raw: true)`), `csv` 6
(`ListToCsvConverter`), `share_plus` 13, `file_picker` 12.

**Spec:** `docs/design/specs/2026-10-17-documents-export-design.md`

## Global Constraints

- Only the active diver's documents (`validatedCurrentDiverIdProvider`).
- Encryption always on, ZipCrypto only; no AES, no option.
- Password: printable ASCII only (0x20 to 0x7E), minimum 8 characters, typed
  twice, never stored or logged.
- No ZIP64, no data descriptor (bit 3) on any entry; general-purpose flags
  are bit 0 (encrypted) and bit 11 (UTF-8 names). Methods: 8 (Deflate) or 0.
- ZIP file name: `<localized prefix> <yyyy-MM-dd>.zip`, prefix
  "Submersion documents" in English.
- Dates in folder names and the manifest are `yyyy-MM-dd`; on screen they use
  `UnitFormatter.formatDate` (the diver's format).
- Dive label on screen: `#142 · Blue Hole · 12 Oct 2026`; no number:
  `Blue Hole · 12 Oct 2026`; no site: `#142 · 12 Oct 2026`. Separator is
  `' · '`. Folder form: `#142 Blue Hole 2026-10-12` (single spaces).
- Every new user-visible string goes in all 11 ARB files under
  `lib/l10n/arb/`, then `flutter gen-l10n`.
- Paths via `p.join`; temp space via `Directory.systemTemp.createTemp`.
- No em dashes anywhere; no tool attribution in commits.
- Before each commit: `dart format .`, `flutter analyze`, the task's tests;
  after adding `lib/` files also `flutter test test/architecture/`.

## Review Focus

1. A title or record name that is all invalid characters, or empty after
   sanitizing (`"???"`, `"..."`): it must still produce a usable, non-empty
   segment (`_`), never an empty path segment. Test in Task 3.
2. Two documents with the same title in one folder, differing only by case
   (`Permit.pdf`, `permit.pdf`): must become `Permit.pdf` and `permit (2).pdf`
   so case-insensitive file systems do not overwrite. Test in Task 3.
3. A document filed under a record that was deleted (owner label null for a
   non-personal kind): it goes under the localized "Unknown" folder and is not
   dropped. Test in Task 3.
4. Cancel pressed while a file is mid-write, and an exception thrown by a page
   read: no temp file remains either way. Tests in Task 5.
5. A page whose stored `fileName` has no extension: the extension comes from
   `mimeType` (`image/jpeg` gives `.jpg`, `application/pdf` gives `.pdf`,
   unknown gives `.bin`). Test in Task 3.

---

### Task 1: One dive label (#3391)

**Files:**
- Create: `lib/features/documents/domain/dive_owner_label.dart`
- Modify: `lib/features/documents/data/repositories/document_repository.dart`
  (`DocumentListEntry`, `_entries` SQL)
- Modify: `lib/features/documents/data/repositories/document_owner_options_repository.dart`
  (`labelFor`, new `diveLabel`)
- Modify: `lib/features/documents/presentation/providers/document_providers.dart`
  (`allDocumentsProvider`, `documentEntryProvider`)
- Modify: `lib/features/documents/presentation/providers/document_owner_providers.dart`
  (`documentOwnerLabelProvider`)
- Test: `test/features/documents/domain/dive_owner_label_test.dart`,
  `test/features/documents/data/repositories/document_repository_test.dart`,
  `test/features/documents/data/repositories/document_owner_options_repository_test.dart`,
  `test/features/documents/presentation/widgets/document_widgets_test.dart`

**Interfaces:**
- Produces:
  - `class DiveOwnerLabel extends Equatable { final int? number; final String? siteName; final DateTime date; }`
  - `String DiveOwnerLabel.display(String formattedDate)` (on-screen form)
  - `String DiveOwnerLabel.folderName()` (ISO date form)
  - `DocumentListEntry` gains `final DiveOwnerLabel? dive;` as an optional
    named constructor parameter, and
    `DocumentListEntry withOwnerLabel(String? label)`.
  - `Future<DiveOwnerLabel?> DocumentOwnerOptionsRepository.diveLabel(String diveId)`
  - `List<DocumentListEntry> resolveDiveOwnerLabels(List<DocumentListEntry> entries, String Function(DateTime) formatDate)`
    in `document_providers.dart` (dive entries get
    `ownerLabel = dive.display(formatDate(dive.date))`; others unchanged).

- [ ] **Step 1: Write failing domain tests** in `dive_owner_label_test.dart`:
  - `display` with number, site: `DiveOwnerLabel(number: 142, siteName: 'Blue Hole', date: DateTime.utc(2026, 10, 12)).display('12 Oct 2026')` equals `'#142 · Blue Hole · 12 Oct 2026'`.
  - no number gives `'Blue Hole · 12 Oct 2026'`; no site gives `'#142 · 12 Oct 2026'`; blank site (`'  '`) treated as no site.
  - `folderName()` gives `'#142 Blue Hole 2026-10-12'`, and `'Blue Hole 2026-10-12'` with no number.
- [ ] **Step 2: Run** `flutter test test/features/documents/domain/dive_owner_label_test.dart`. Expected: FAIL (file missing).
- [ ] **Step 3: Implement `DiveOwnerLabel`.** `date` is wall-clock-as-UTC (from `wallClockUtcFromMillis`); ISO via `DateFormat('yyyy-MM-dd')`.
- [ ] **Step 4: Run** the same test. Expected: PASS.
- [ ] **Step 5: Write failing repository tests:**
  - `document_repository_test.dart`: a document filed under dive `v1` (number 142, site "Blue Hole", named "Night dive") yields an entry whose `dive` equals `DiveOwnerLabel(number: 142, siteName: 'Blue Hole', date: <its wall-clock date>)`; the dive's `name` no longer appears in `ownerLabel`. The existing site case (`'Bonaire'`) stays green, with `dive` null.
  - `document_owner_options_repository_test.dart`: `diveLabel('v1')` returns the parts; an unknown id returns null. Replace the existing `labelFor(dive)` expectation: `labelFor` is now for non-dive kinds and asserts `owner.kind != DocumentOwnerKind.dive`.
- [ ] **Step 6: Run** both repository tests. Expected: FAIL.
- [ ] **Step 7: Implement.** In `_entries`, drop `dv.name, '#' || dv.dive_number` from the `COALESCE`, add `dv.dive_number AS dive_number, dv.dive_date_time AS dive_date_time, dvs.name AS dive_site_name` with `LEFT JOIN dive_sites dvs ON dvs.id = dv.site_id`, and build `dive` when `d.dive_id` resolved. `diveLabel` runs the same three columns for one id. Remove `_diveLabel` from `labelFor`; `_dives` (picker) is unchanged.
- [ ] **Step 8: Run** both repository tests. Expected: PASS.
- [ ] **Step 9: Write failing presentation tests** in `document_widgets_test.dart`:
  - `DocumentOwnerField` for a dive owner, with `documentOwnerOptionsRepositoryProvider` overridden by a fake whose `diveLabel` returns number 142, site Blue Hole, 12 Oct 2026, shows `'#142 · Blue Hole · ' + UnitFormatter(settings).formatDate(date)`.
  - `resolveDiveOwnerLabels` sets the dive entry's label and leaves a site entry's `'Bonaire'` alone.
- [ ] **Step 10: Run** them. Expected: FAIL.
- [ ] **Step 11: Implement.** `documentOwnerLabelProvider` branches: dive kind reads `diveLabel` and formats with `UnitFormatter(ref.watch(settingsProvider)).formatDate`; other kinds call `labelFor`. `allDocumentsProvider` and `documentEntryProvider` pass their results through `resolveDiveOwnerLabels` with the same formatter.
- [ ] **Step 12: Run** `flutter test test/features/documents/`. Expected: all PASS.
- [ ] **Step 13: Commit** `fix(documents): one dive label for File under, list and detail`.

### Task 2: ZipCrypto writer

**Files:**
- Create: `lib/core/services/export/zip/zip_crypto_writer.dart`
- Test: `test/core/services/export/zip/zip_crypto_writer_test.dart`

**Interfaces:**
- Produces:
  - `class ZipCryptoWriter { ZipCryptoWriter(RandomAccessFile out, {required String password, Random? random}); }`
    `password` must be printable ASCII (`ArgumentError` otherwise).
  - `Future<void> addFile(String name, Uint8List data, {required DateTime modified})`
  - `Future<void> close()` writes the central directory and end record, then
    closes `out`.
  - `static bool isValidPassword(String password)`: length at least 8, every
    code unit 0x20 to 0x7E.

ZipCrypto (APPNOTE 6.3.x section 6.1): keys `0x12345678, 0x23456789,
0x34567890`; `update(c)`: `k0 = crc32(k0, c)`, `k1 = (k1 + (k0 & 0xff)) * 134775813 + 1` (32-bit),
`k2 = crc32(k2, k1 >> 24)`; stream byte `t = (k2 | 2) & 0xffff`,
`((t * (t ^ 1)) >> 8) & 0xff`. Each entry: init keys with the password,
encrypt a 12-byte header (11 random bytes, last byte = CRC-32 high byte),
then the raw-Deflate output; compressed size includes the 12 bytes. Use
Stored when Deflate does not shrink the data.

- [ ] **Step 1: Write failing tests:**
  - round trip: write `a.txt` ("hello"), `Dives/#142 Blue Hole 2026-10-12/scan.jpg` (4 KB random), and an empty file; `ZipDecoder().decodeBytes(bytes, password: 'correct horse')` returns all three with identical content and names.
  - wrong password: decoding with `'wrong password'` does not yield the original content (throws or differs).
  - every local and central header has flag bits 0 and 11 set, bit 3 clear (read the uint16 at offset 6 of each `PK\x03\x04`).
  - a name with `é` round-trips as UTF-8.
  - `isValidPassword`: `'abcdefgh'` true, `'abc'` false, `'pässwörd'` false, `'tab\there12'` false.
  - constructing with an invalid password throws `ArgumentError`.
- [ ] **Step 2: Run** `flutter test test/core/services/export/zip/zip_crypto_writer_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** using `getCrc32` from `archive` for CRCs and `ZLibCodec(raw: true, level: 6)` for Deflate; DOS date and time from `modified`; random from `Random.secure()` unless injected.
- [ ] **Step 4: Run** the test. Expected: PASS. Also, once, unzip the round-trip output with the system tool: `unzip -P 'correct horse' -t <file>` reports `No errors detected`.
- [ ] **Step 5: Commit** `feat(export): ZipCrypto ZIP writer`.

### Task 3: Archive layout

**Files:**
- Create: `lib/features/documents/domain/document_archive_layout.dart`
- Test: `test/features/documents/domain/document_archive_layout_test.dart`

**Interfaces:**
- Produces:
  - `String sanitizeArchiveSegment(String raw)`
  - `class ArchiveDocumentInput { final Document document; final String displayTitle; final String kindFolder; final String? recordFolder; final List<DocumentPage> pages; }`
    (`recordFolder` null means "put directly in `kindFolder`" for personal, or
    the caller passes the localized Unknown label for a missing record).
  - `class ArchiveNames { final String front; final String back; final String Function(int n) page; }`
  - `class ArchiveFileEntry { final String path; final String documentId; final String pageId; }`
  - `class DocumentArchivePlan { final List<ArchiveFileEntry> files; final Map<String, String> pathsByPageId; }`
    (`pathsByPageId` maps page id to its path, used by the manifest).
  - `DocumentArchivePlan planDocumentArchive(List<ArchiveDocumentInput> docs, ArchiveNames names)`
  - `String archiveExtension(DocumentPage page)`

Paths use `/` (ZIP separator, not `p.join`). Order: inputs in the given
order, pages by `pageIndex`.

- [ ] **Step 1: Write failing tests:**
  - sanitize: `'a<b>c:d"e/f\\g|h?i*j'` gives `'a_b_c_d_e_f_g_h_i_j'`; control characters become `_`; `'Notes. '` gives `'Notes'`; `'CON'` gives `'CON_'` (also `'nul'` gives `'nul_'`); `'???'` gives `'___'`; `'...'` and `''` give `'_'`; a 300-character name is cut to 120 characters.
  - one page: `Personal/DAN insurance 2026.pdf`.
  - card faces: `Certifications/PADI Advanced Open Water/PADI AOW card - front.jpg` and `- back.jpg`.
  - three-page booking: `- page 1.pdf`, `- page 2.pdf`, `- page 3.pdf`.
  - collisions: two "Permit" PDFs and one "permit" PDF in one folder give `Permit.pdf`, `Permit (2).pdf`, `permit (3).pdf`.
  - missing record: `recordFolder: 'Unknown'` under `Dives` gives `Dives/Unknown/...`.
  - extension: stored `fileName` `'scan'` with `image/jpeg` gives `.jpg`; `application/pdf` gives `.pdf`; `application/x-foo` gives `.bin`; `'IMG_1.HEIC'` keeps `.HEIC`.
  - a document with no pages contributes no file.
- [ ] **Step 2: Run** the test. Expected: FAIL.
- [ ] **Step 3: Implement.** Collision check compares lower-cased full paths; suffix goes before the extension.
- [ ] **Step 4: Run** the test. Expected: PASS.
- [ ] **Step 5: Commit** `feat(documents): plan the export archive layout`.

### Task 4: Manifest CSV

**Files:**
- Create: `lib/features/documents/domain/document_manifest.dart`
- Test: `test/features/documents/domain/document_manifest_test.dart`

**Interfaces:**
- Consumes: `ArchiveDocumentInput`, `DocumentArchivePlan` (Task 3).
- Produces:
  - `class ManifestLabels { final List<String> headers; final String Function(DocumentType) type; final String Function(DocumentOwnerKind) kind; final String front; final String back; }`
  - `String buildDocumentManifestCsv(List<ArchiveDocumentInput> docs, DocumentArchivePlan plan, ManifestLabels labels)`

Columns in order (14): Title, Type, Filed under (kind), Filed under, Issuer,
Reference number, Issue date, Expiry date, Notes, Emergency phone, Phone,
Page, Side, Path in ZIP. One row per page; one row with empty Page, Side and
Path for a document with no pages. Output starts with a UTF-8 BOM (`'U+FEFF'`
built in code, not typed into the source) and uses CRLF line endings
(`ListToCsvConverter` default).

- [ ] **Step 1: Write failing tests:**
  - header row equals the 14 labels; first character is the BOM.
  - a two-page card yields two rows with Side front and back and the paths from the plan.
  - a no-page document yields one row with empty Page, Side and Path.
  - dates are `2026-10-12`; null dates are empty.
  - notes containing a comma, a quote and a newline round-trip through `CsvToListConverter`.
  - Emergency phone and Phone are filled for insurance only.
- [ ] **Step 2: Run** the test. Expected: FAIL.
- [ ] **Step 3: Implement** with `ListToCsvConverter`.
- [ ] **Step 4: Run** the test. Expected: PASS.
- [ ] **Step 5: Commit** `feat(documents): export manifest CSV`.

### Task 5: Archive exporter

**Files:**
- Create: `lib/features/documents/data/services/document_archive_exporter.dart`
- Test: `test/features/documents/data/services/document_archive_exporter_test.dart`

**Interfaces:**
- Consumes: `DocumentRepository.getPages(String documentId, {bool withBytes})`,
  `ZipCryptoWriter` (Task 2), `DocumentArchivePlan` (Task 3).
- Produces:
  - `class DocumentExportCancelled implements Exception {}`
  - `class DocumentArchiveExporter { DocumentArchiveExporter(DocumentRepository repo); }`
  - `Future<void> write({required DocumentArchivePlan plan, required String manifestCsv, required String password, required String outputPath, required DateTime now, void Function(int done, int total)? onProgress, bool Function()? isCancelled})`

Reads `getPages(documentId, withBytes: true)` once per document (not per
page), writes `manifest.csv` first, then each planned file, calling
`onProgress(done, total)` after each with `total = files + 1`. Checks
`isCancelled` before each entry; on cancel or any error deletes
`outputPath` and rethrows (`DocumentExportCancelled` for cancel). Deflate
and encryption of one entry run in `Isolate.run` so the UI isolate stays
free; the writer's per-entry work is split accordingly (a top-level
`encodeZipCryptoEntry` function the writer and the isolate share is fine).

- [ ] **Step 1: Write failing tests** (in-memory database helper used by `document_repository_test.dart`):
  - two documents (one two-page card, one PDF) produce a ZIP that `ZipDecoder` opens with the password, containing `manifest.csv` plus the three planned paths with the stored bytes.
  - progress callbacks are `(1,4), (2,4), (3,4), (4,4)`.
  - `isCancelled` returning true after the first entry throws `DocumentExportCancelled` and `File(outputPath).existsSync()` is false.
  - a repository fake whose `getPages` throws: the error propagates and no output file remains.
- [ ] **Step 2: Run** the test. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the test. Expected: PASS.
- [ ] **Step 5: Commit** `feat(documents): write the documents archive`.

### Task 6: Share a file by path

**Files:**
- Modify: `lib/core/services/export/shared/file_export_utils.dart`
- Test: the existing test for this file (`test/core/services/export/shared/file_export_utils_test.dart`, or the file that covers `canShareFiles`)

**Interfaces:**
- Produces: `Future<String?> shareFileAtPath(String path, String fileName, String mimeType, {required String dialogTitle, Rect? sharePositionOrigin})`.
  Shares the existing file directly (no copy into Documents). Where
  `canShareFiles` is false, reads the bytes and calls `saveBytesToFile`;
  returns null when that dialog is cancelled.

- [ ] **Step 1: Write failing tests** using the existing share and picker fakes: with `debugCanShareFiles = true` the share platform receives one `XFile` whose path is the given path; with `false` the picker's `saveFile` receives the file's bytes and `fileName`. Restore `debugCanShareFiles` in `addTearDown`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(export): share an existing file by path`.

### Task 7: Export flow, sheet and progress

**Files:**
- Create: `lib/features/documents/presentation/widgets/document_export_sheet.dart`
- Create: `lib/features/documents/presentation/widgets/document_export_progress_dialog.dart`
- Create: `lib/features/documents/presentation/helpers/document_export_flow.dart`
- Modify: all 11 `lib/l10n/arb/app_*.arb`, then `flutter gen-l10n`
- Test: `test/features/documents/presentation/widgets/document_export_sheet_test.dart`,
  `test/features/documents/presentation/helpers/document_export_flow_test.dart`

**Interfaces:**
- Consumes: Tasks 1 to 6; `showExportDestinationSheet` from
  `lib/shared/widgets/export_destination_sheet.dart`; `saveBytesToFile`;
  `shareFileAtPath`; `DocumentRepository.getAllForDiver`, `getPages(withBytes: false)`.
- Produces:
  - `Future<String?> showDocumentExportSheet(BuildContext context, {required int documentCount, required int fileCount})` returns the password, null when dismissed.
  - `Future<void> exportAllDocuments(BuildContext context, WidgetRef ref)`: the whole flow, used by both entry points.

l10n keys (English values):
`documents_export_action` "Export all documents",
`documents_export_title` "Export documents",
`documents_export_summary` "{documents} documents, {files} files" (plural-safe ICU),
`documents_export_password` "Password",
`documents_export_confirmPassword` "Confirm password",
`documents_export_passwordTooShort` "Use at least 8 characters",
`documents_export_passwordCharacters` "Use only letters A to Z, digits, spaces and common symbols, so the ZIP opens on every computer",
`documents_export_passwordMismatch` "Passwords do not match",
`documents_export_note` "This password cannot be recovered. The ZIP opens by double-clicking on a computer, not on a phone. The protection keeps out casual snooping but is not strong encryption, and file and folder names stay readable without the password.",
`documents_export_start` "Export",
`documents_export_progress` "File {done} of {total}",
`documents_export_nothing` "There are no documents to export",
`documents_export_done` "Documents exported",
`documents_export_failed` "Export failed: {error}",
`documents_export_cancelled` "Export cancelled",
`documents_export_fileNamePrefix` "Submersion documents",
`documents_export_unknownRecord` "Unknown",
`documents_export_front` "front", `documents_export_back` "back",
`documents_export_page` "page {n}",
and the 14 manifest headers as `documents_export_manifest_<column>`
(`title`, `type`, `kind`, `filedUnder`, `issuer`, `reference`, `issueDate`,
`expiryDate`, `notes`, `emergencyPhone`, `phone`, `page`, `side`, `path`).
Translate each into the other 10 locales.

Flow order: load entries for the active diver; none gives the
`documents_export_nothing` snackbar and returns. Ask destination
(`showExportDestinationSheet`, title `documents_export_title`); dismissed
returns. Load page metadata, build inputs (kind folder from
`documentOwnerKindLabel`; record folder from `DiveOwnerLabel.folderName()`
for dives, the owner label otherwise, `documents_export_unknownRecord` when a
non-personal label is null; display title from `documentDisplayTitle`).
Show the sheet; dismissed returns. Create a temp dir, run the exporter
under the non-dismissible progress dialog (LinearProgressIndicator,
`documents_export_progress`, Cancel button). Deliver: share via
`shareFileAtPath`, save via `saveBytesToFile` with mime `application/zip`.
Snackbar `done`, `cancelled` or `failed`. Delete the temp dir in `finally`.

- [ ] **Step 1: Write failing sheet tests:** Export disabled until both fields valid; `'short'` shows `passwordTooShort`; `'pässwörd1'` shows `passwordCharacters`; mismatched shows `passwordMismatch`; valid matching returns the password; the summary and note texts are shown; fields are obscured with a visibility toggle.
- [ ] **Step 2: Write failing flow tests** (overrides for the repository, the current diver, a fake share platform and a fake file picker): no documents gives the `nothing` snackbar and no destination sheet; Save to file passes a ZIP whose name matches `Submersion documents \d{4}-\d{2}-\d{2}\.zip` and which `ZipDecoder` opens with the typed password; the temp directory is gone afterwards.
- [ ] **Step 3: Run** both. Expected: FAIL.
- [ ] **Step 4: Add the ARB keys** in all 11 locales and run `flutter gen-l10n`.
- [ ] **Step 5: Implement** the sheet, progress dialog and flow.
- [ ] **Step 6: Run** both tests and `flutter test test/l10n test/architecture`. Expected: PASS.
- [ ] **Step 7: Commit** `feat(documents): export all documents flow`.

### Task 8: Entry points

**Files:**
- Modify: `lib/features/documents/presentation/pages/documents_page.dart`
- Modify: `lib/features/transfer/presentation/pages/transfer_page.dart` (`_ExportSectionContent`)
- Modify: ARB files for `transfer_export_documentsTitle` "Documents" and
  `transfer_export_documentsSubtitle` "All your documents as a password-protected ZIP" (11 locales)
- Test: `test/features/documents/presentation/pages/documents_pages_test.dart`,
  the transfer page test that lists the export rows

Documents page: a `PopupMenuButton` with one item
(`documents_export_action`, icon `Icons.archive_outlined`) in the app bar
when `showAppBar` is true; when false (master-detail), a compact header row
with the title and the same menu, modelled on
`course_list_content.dart`'s `_buildCompactAppBar`. Transfer: a new `ListTile`
in the first export card after CSV, icon `Icons.folder_zip_outlined`, calling
`exportAllDocuments`.

- [ ] **Step 1: Write failing tests:** the Documents page (narrow and wide) shows the menu and its item opens the destination sheet; the Transfer export section shows the Documents row.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the tests plus `flutter test test/features/documents test/features/transfer test/architecture`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(documents): export entry points on Documents and Transfer`.

### Task 9: Final verification

- [ ] **Step 1:** `dart format .`, `flutter analyze` (no issues).
- [ ] **Step 2:** `flutter test test/features/documents test/core/services/export test/features/transfer test/architecture test/shared test/l10n`. Expected: all PASS.
- [ ] **Step 3:** In the running macOS app, export a library with a card, a multi-page PDF and a dive document; double-click the ZIP in Finder, enter the password, check the folders, file names and that `manifest.csv` opens in a spreadsheet.
