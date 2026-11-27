# Shared site library documents: design

Issue: #4713. Release: v1.8.7. Builds on the shared dive-site library (#2567,
[design](2026-10-12-shared-dive-site-library-design.md)).

## Problem

A diving club uses a Shared Site Library as the common catalogue for the people
who organise club dives. The site fields travel, but the papers that go with a
site (access maps and directions, local regulations, safety and emergency
procedures) stay with whoever attached them. Organisers still pass those files
around by hand, so the library is not yet the single place to prepare a club
dive.

## Outcome

A document on a library site's Documents card can be shared with the library.
Every connected member's device downloads it with the library's next sync, so it
opens offline at the site. Editors and owners add, change and remove shared
documents; readers open and export them. Each document can stay private, and a
private document on a library site behaves exactly as it does today.

## Goals, non-goals, anti-goals

Goals:

- Share Documents-card records (`documents` with embedded `document_pages`) on
  library sites, including their page files.
- Follow the library's roles, merge rules, encryption, backups, key rotation,
  member removal and storage measurement, as library sites do.
- A per-document choice between shared and private.

Non-goals:

- Media-card attachments (photos and linked document files). They are links to
  files on one device and stay personal. A diver who wants to share such a PDF
  adds it as a Document.
- Suggestions for documents. Readers cannot propose a new document or an edit to
  one; suggestions stay limited to site fields.
- Expiry reminders for shared documents.
- Downloading on first open. Every connected device holds every shared document.

Anti-goals (a failure even if it works):

- A document the diver kept private reaching other members.
- A shared document appearing, or reminding, in fifty members' personal
  Documents lists and home panels.
- Older app versions in the same club losing data or being cut off from the
  library.
- A member's private documents being deleted because a library site left this
  device.

## Decisions taken in design

| Question | Decision |
| --- | --- |
| Which attachments | Documents-card records only |
| Default on a library site | Shared. Types `receipt`, `insurance`, `medicalClearance`, `certificationCard` and `booking` start private. Documents already on a personal site start private when the site is pushed to a library. |
| Choice | A "Share with <library>" switch on the document, editable by editors and owners |
| Permissions | Editors and owners add, edit, re-page and remove shared documents. Readers view and export them, and may still attach private documents of their own. |
| Download | With every library sync, so every connected device holds every file |
| Local model | Approach 1: a shared document is a `documents` row with `sharedLibraryId` set and `diverId` null, mirroring library sites |
| Delete and leave | Shared documents follow their site: kept as the diver's private copies on a site kept as a personal copy, removed with a removed site |
| Backups | Include shared document records and the page files they need, by reference; page bytes stay in `pages/` |
| Personal lists and reminders | Shared documents show on their site's card only; the Documents page gains a Library filter; no expiry reminders |

## Approaches considered

1. **Library rows in the existing `documents` tables (chosen).** A
   `sharedLibraryId` column, `diverId` made nullable, a `shared_document_states`
   table for clocks. Every document screen works unchanged because these are
   real `Document` rows. The cost is the same personal-sync boundary guards
   library sites have, and wiring into the library's rotation, backup, restore,
   removal and measurement paths.
2. **Separate `shared_documents` tables.** Personal sync stays untouched, but
   every document screen (viewer, export, page strip, details, tags) would need
   a second data source, and the two copies would drift apart.
3. **Documents inside the site's JSON file.** Rejected: one clock for the whole
   list, so two editors adding documents at once lose one, and page bytes
   inflate a file re-downloaded on every change.

## Storage layout

Two new folders inside the library, beside `sites/`:

| Path | Written by | Content |
| --- | --- | --- |
| `documents/document-<id>.json` | editors and owners | the document file (below) |
| `pages/<fileId>.bin` | editors and owners | one page's bytes; `fileId` is a fresh random UUID per page version |

Both are sealed under the library key when the library is encrypted, with the
path as the AEAD binding, like every other library file.

`SharedLibraryLayout.formatVersion` stays 2. The new folders are additive, as
`removed-` member files were: an older app lists only `sites/` and never sees
them. `reservedFolders` gains `documents` and `pages` for new connects; an
existing library whose prefix already starts with either keeps working (the
check applies when a prefix is chosen, not to libraries already connected).

### Document file

```json
{
  "id": "…",
  "siteId": "…",
  "formatVersion": 2,
  "deleted": false,
  "fields": {
    "type": "map", "title": "Shore access", "issuer": null,
    "referenceNumber": null, "issueDate": null, "expiryDate": null,
    "notes": "…",
    "tags": ["Access"],
    "pages": [
      { "id": "…", "pageIndex": 0, "side": null, "fileName": "access.pdf",
        "mimeType": "application/pdf", "sizeBytes": 812345,
        "fileId": "…", "sha256": "…" }
    ]
  },
  "clocks": {
    "title": { "hlc": "…", "memberId": "…", "sig": "…" },
    "deleted": { "hlc": "…", "memberId": "…", "sig": "…" }
  }
}
```

- `siteId` is fixed at share time and not a clocked field: a shared document
  never moves between sites. Moving one means unsharing it.
- `pages` and `tags` are each one clocked field and merge as a unit, as site
  child lists do.
- Fields that never travel: `diverId`, `reminderLeadDays` (a member's own
  reminder preference), `emergencyPhone`, `phone` and `isPrimary` (insurance
  only, and insurance starts private), `createdAt`, `updatedAt`, `hlc`.
- Unknown keys are preserved on round trip (`extra`), as `SiteDocument` does.
- Field signatures use their own domain tag, `ssl-doc-field:v1`, so a site
  field signature can never be replayed as a document field. The signed value
  of `pages` includes each page's `sha256`, which ties the page files to the
  signed document.

### Page files

- Named by a random UUID chosen when the page version is written, never by its
  content hash: a hash name would let anyone who can list the bucket confirm
  that a known PDF is in an encrypted library. *(Builder's call.)*
- A file is immutable once written: an upload whose name already exists is
  skipped. The page's `sha256` (of its plain bytes) lives in the signed
  `pages` field, and a downloaded file whose hash does not match is rejected
  and retried next sync.
- A page edit (a new scan) gets a new `fileId` and so a new file; the `pages`
  list changes clock.
- Garbage collection: an owner's sync deletes a page file that no document
  file and no retained backup references, and that is older than 30 days. The
  grace period covers a concurrent edit that references a file another member
  is about to drop.

## Sync

`SharedLibraryService._syncOnce` gains a documents pass after the site pull and
push (sites first, so a document's site exists locally before the document
merges). It reuses the site pass's shape:

1. **Pull.** List `documents/`; a file whose `modifiedTime` differs from its
   `shared_document_states.remoteModifiedTime` is downloaded, its signatures
   checked against the same `judged` keys the site pass uses, and merged per
   field. A document whose site is unknown locally (not yet pulled, or deleted)
   is handled as below (Documents of a deleted or unknown site).
2. **Fetch pages.** For each page the merged document names whose bytes are not
   held locally (by `sha256`), download `pages/<fileId>.bin`, verify the hash,
   and write the `document_pages` row. A document whose pages are not all
   fetched is not shown until they are (its row is written only when every page
   is held), so a member never opens a half-downloaded document.
3. **Push.** For each dirty document state, upload missing page files first,
   then the document file, then record the stamp. A permission error sets
   read-only and leaves it dirty.

`SharedLibrarySyncNotifier._hasLocalWork` also checks dirty document states.

### Documents of a deleted or unknown site

*(Builder's call.)* A document's visibility follows its site; deleting a site
writes no document tombstones (older editors could not write them anyway).

- **Site deleted in the library:** the document file is merged into its state
  row and its stamp stored, but no local row is kept. It does not re-download
  every sync.
- **Site unknown** (no `sites/` file at all after this sync's site pass): the
  stamp is stored and the document parked. When a site with that id later
  arrives, the stamps of its parked documents are cleared so they are read
  again.
- **Site undeleted:** its documents' stamps are cleared and they come back on
  the next pull. Private copies a member kept when the site left stay beside
  them, as their own documents.
- GC counts every non-deleted document file as a reference, whatever its
  site's state, so an undelete never finds its pages collected.

### Merge

`mergeSiteDocuments` is generalised (or a sibling written) for documents: the
greater HLC wins per field, a tie keeps local, a missing clock is oldest,
`deleted` is a clocked field. A deleted document is removed locally with no
personal tombstone.

### Local edits

A sibling of `LibraryEditStamper` stamps document fields: after the save commits
(as `site_repository_impl.dart` stamps after commit), it advances the member
clock past existing clocks for the changed fields and marks the state dirty.
Hook points: `DocumentEditSaveService` (sitting saves and create),
`DocumentRepository` page and tag writes, the sitting's attach and detach, and
the agent-access document writes.

## Local data model

One migration rung (v388), helpers in `lib/core/database/migrations/helpers/`
and a `beforeOpen` backstop in a part file (`before_open.dart` is at its line
limit).

- `documents.diver_id` becomes nullable by the repository's
  `_dropNotNullByRebuild` precedent (foreign keys off, transactional copy,
  indexes and triggers recreated).
- `documents` gains `shared_library_id TEXT NULL`. A shared document has it
  set and `diver_id` null.
- New table `shared_document_states` (not synced): `documentId` PK (no FK, so
  the tombstone can still go up after the row is gone), `libraryId`, `siteId`,
  `clocksJson`, `remoteModifiedTime`, `dirty`, `deleted`,
  `lastEditorMemberId`, `lastEditedAtMs`.
- `Document.diverId` becomes `String?` and `Document` gains
  `sharedLibraryId`. Callers that need a diver (primary insurance, clearance,
  reminders) only ever see personal documents.
- `SharedLibraryStore.deleteLibrary` and `clearRemoteStamps` also clear
  document states.

Tags on a shared document travel by name and resolve against the viewing
diver's vocabulary, created when missing, as site tags do.

### Personal-sync boundary

The same three guards library sites have, extended to documents:

1. Export skips `documents` rows with `shared_library_id` set, and their
   `document_pages` and `document_tags` rows (base export, incremental export,
   `_withPendingChildren`, writer clock seeds).
2. Merge ignores an incoming personal `documents`, `document_pages` or
   `document_tags` row whose local document is a library document.
3. Deleting a library document, its pages or its tag links logs no personal
   tombstone and marks nothing pending; `_applyRemoteDeletions` ignores a
   personal tombstone for one.

## Behaviour

### Visibility

- A site's Documents card lists the viewing diver's own documents on the site
  plus every shared document of a library the diver holds a membership for
  (`documentsForOwnerProvider` and `DocumentRepository.getForOwner` gain the
  library clause, the same membership fragment `VisibilityFilter` uses for
  sites).
- The Documents page lists personal documents as today and gains a "Library"
  filter that shows shared documents grouped by library. Global search follows
  the page.
- Reminders, the attention strip and the home panel ignore shared documents.

### Sharing and unsharing

- Adding a document on a library site (Documents card Add, or an owner picker
  naming a library site) creates it shared unless its type is one of
  `receipt`, `insurance`, `medicalClearance`, `certificationCard` and `booking`. Readers' new documents are always private and show no switch.
- The document's details card gains "Share with <library>" for documents on a
  library site, editable by editors and owners.
- **Share** turns a private document into a library row in place (same id,
  `diverId` cleared, `sharedLibraryId` set, every field clocked under the
  member, dirty state). Its personal-sync rows are tombstoned on the diver's
  other devices, which then receive it through the library, as a pushed site
  is. The same id on both sides means no duplicate.
- **Unshare** writes the library tombstone for the shared document and keeps a
  private copy for the member who unshared it, under a new deterministic id,
  as a detached site does. Other members lose it on their next sync. The
  confirmation says so.
- Changing a shared document's type to one of the private-by-default types
  does not unshare it, but the details card shows the switch next to the type
  so the editor sees it is still shared.

### Editing and removing

- On a library site, editors and owners edit a shared document like any
  document. Readers open it read-only: the details pencil, page editing and
  delete are hidden, and Export stays.
- The site card's unlink button on a shared document becomes "Remove from
  library" (held until Save in the sitting, then a library tombstone). A
  shared document cannot be moved to another owner: the owner field is locked
  while it is shared.
- Deleting a shared document from its detail page writes the library
  tombstone.

### Pushing a personal site

Its documents stay private (decided). The Share switch then appears on each.

### Delete, leave and member removal

When a library site leaves this device (library tombstone, leave, or a member
removed), `SiteDetacher`:

- **Keeps the site** as a personal copy when any dive or plan links to it, or
  when the diver has private documents on it (new: today those private
  documents would be deleted and tombstoned on every device of the diver). The
  site's shared documents are kept on the copy as the diver's private
  documents under new deterministic ids, so they are not lost to an organiser
  who relied on them.
- **Removes the site** otherwise, with its shared documents, logging no
  personal tombstones.

A shared document's library tombstone on its own removes it locally, with no
personal tombstone.

### Attribution

The document detail page of a shared document shows the library name and "Last
edited by <name>, <date>", from the newest clock, as the site header does. The
card tile's subtitle shows the library name for shared documents and "Only you"
for private documents on a library site.

## Library maintenance paths

- **Transport:** folders and listers for `documents/` (JSON) and `pages/`
  (`.bin`, a new lister since `_listKind` takes JSON only); `_place` cases;
  `sealableFiles()` lists both, so `snapshot()`, `_finishRewrite` and the
  encryption service rewrite them. Page writes skip the read-back verification
  `writeSite` does, since the hash checks the content.
- **Key rotation:** covered by `sealableFiles()`. An older owner app rotating
  the key leaves the new folders under the old key; the existing
  previous-keys file still opens them, and a newer owner's sync re-seals them
  (the `mismatched` path).
- **Encryption turned on or off by an older owner app:** the new folders stay
  in their old form. *(Builder's call.)* Any newer editor or owner device that
  opens a `documents/` or `pages/` file in the wrong form re-writes it in the
  library's current form during its sync, not only owners as for site files,
  so a library turned off by an older owner does not depend on a newer owner
  still holding the old key. Readers cannot write those folders and do not
  try.
- **Backup (decided: by reference):** the archive includes `documents/` but
  not `pages/`; each document file already names its pages' `fileId` and
  `sha256`. The header gains `documentCount`, and the backup index entry lists
  the `fileId`s the backup needs, so GC can keep them without opening zips.
  Retained backups are the ones in the storage index, pinned ones included.
  `LibraryBackupArchive.isLibraryFile` accepts the new path. An older app
  refuses such a backup as "not a backup"; the restore error names the newer
  app. A backup kept only on a device, whose page files have since been
  collected, restores the documents it can and reports how many it could not.
- **Restore:** `_restoreDocuments` re-stamps every field with fresh clocks, as
  `_restoreSites` does, skips (and counts) a document whose page files are no
  longer in `pages/`, and tombstones shared documents made since the backup. A backup with no
  `documentCount` (made by an older app) leaves shared documents alone: it
  neither restores nor tombstones any. *(Builder's call.)*
- **Storage measurement:** `measureBytes` walks both folders.
- **Health:** no change.

## Screens

- **Site detail, Documents card:** shared and private documents in one list,
  each tile's subtitle naming the library or "Only you"; "Remove from library"
  for shared documents in the open card; for readers the card is no longer
  labelled "Only you" as a whole (`siteReaderPrivateCards` drops `documents`),
  and only their own private documents are editable.
- **Document detail:** library name and attribution line; read-only for
  readers; "Share with <library>" switch in the details card; locked owner
  field while shared; unshare confirmation.
- **Documents page:** Library filter.

All new text is localised in English and the ten other locales.

## Constraints

- Files over 800 lines (`shared_library_service.dart`, `_transport.dart`,
  `_store.dart`, `_models.dart`, `document_repository.dart`,
  `site_detail_page.dart`, `sync_service.dart`, `sync_data_serializer.dart`)
  take new logic in part or companion files.
- Tables and migrations stay under the 800-line test limit.
- Every page is at most 10 MB (`kMaxDocumentPageBytes`).
- Mixed app versions in one club keep working: format version unchanged, new
  folders additive.

## Testing

- Document file codec: round trip, unknown keys kept, missing clocks oldest,
  private fields never written.
- Merge: random edit sequences over two or three members on a shared fake
  provider converge, including page-list and tag-list edits and delete or
  undelete.
- Signatures: a site field signature does not verify as a document field;
  a tampered page file is rejected by hash.
- Sync: pages fetched before the document is shown; a document whose site is
  unknown retries; reader devices never upload; read-only detection.
- Share and unshare: ids, clocks, personal tombstones on share, private copy on
  unshare, other members lose it.
- Defaults: new document on a library site shared, `receipt`, `insurance`, `medicalClearance`, `certificationCard` and `booking`
  private, reader always private, push leaves documents private.
- Delete, leave, removal: site kept for private documents; shared documents
  become private copies on a kept site; removed with a removed site; no
  personal tombstones for library rows.
- Personal-sync guards: the two-device convergence harness with a shared
  document, asserting it is never exported, overwritten or tombstoned.
- Migration: v388 from a v387 database keeps every document and page and its
  foreign keys.
- Maintenance: key rotation rewrites both folders; a backup holds document
  files but no page files; restore brings a deleted shared document back with
  its pages; GC keeps a file a document or a retained backup references, or a
  young one, and deletes an old unreferenced one; a device-only backup with
  collected pages restores what it can and reports the rest; an older
  app's backup leaves documents alone on restore.
- Deleted and unknown sites: a document of a deleted site is not re-downloaded
  each sync; a parked document appears when its site arrives; undelete brings
  documents back with their pages.
- Encryption form: a newer editor re-seals a document file left plain by an
  older owner turning encryption on, and re-writes one left sealed after an
  older owner turned it off.
- Widget tests: card tiles by role, reader read-only detail, share switch and
  unshare confirmation, Library filter.

## Left to the builder

- Exact part-file boundaries and whether the merge is generalised or a sibling.
- The deterministic id scheme for unshared and detached copies (UUID v5 like
  `detachedSiteId`).
- The page-fetch batch size and the order of document pulls inside a sync.
