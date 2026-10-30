# Documents: filing, gear files, viewing and storage

Date: 2026-10-13. Release: v1.8.2.

## Problem

Four gaps in the Documents library (issue #2613), reported together:

1. A document cannot be filed under, or moved to, a record from the
   Documents section. The edit page keeps the owner it was created with
   forever (`owner: _original?.owner ?? widget.owner`), so a document added
   from the Documents tab is always Personal.
2. Equipment paperwork does not appear in Documents. The gear page carries
   two cards both titled "Documents": the library card (#2613) and the older
   #1517 card, which links media-store files to the gear through
   `media.equipment_id`. Only the library feeds the Documents tab.
3. A PDF on the document detail page is boxed into a fixed 320 px
   `SizedBox` inside a `ListView`. It fills the top of the screen only, and
   the outer list wins every vertical drag, so the PDF cannot scroll.
4. Trips appear to have no documents. They do, but for a trip under way or
   finished the card is the last sliver of the Overview tab, below every day
   chapter.

Raised during design:

5. A certification card document shows the generic title "Certification
   card" instead of its certification's name.
6. Deleting documents (each page up to 10 MB) never shrinks the database
   file. SQLite moves freed pages to the freelist; only a `VACUUM` returns
   them, and the app runs one only during a one-time upgrade.

## Decisions

| Question | Decision |
| --- | --- |
| One owner or many links | One owner, reassignable. No schema or sync change. |
| Where refiling happens | The new/edit form only. |
| Old gear files | Converted into library documents. |
| When conversion runs | Each launch and after each successful sync. |
| Trip documents | Make the existing card findable (move it up). |
| PDF layout | The viewer fills the page; details collapse below or beside it. |
| Card document title | Derived from the certification's name at display time. |
| Reclaiming space | Automatic VACUUM at launch past a threshold, plus a manual button. |

## 1. Filed under

### Form

The new/edit form gains a **Filed under** field showing the owner: the
record's name ("Red Sea 2026") with its kind as the field's icon, or the
kind's label when there is no name (Personal, an unnumbered dive). It is
announced to screen readers as a button. Tapping it opens the owner picker
sheet. Opened from an owner page's Add document, the field starts
at that owner and can still be changed.

A certification card document (`DocumentType.certificationCard`) shows the
field read-only. Its id is derived from its certification
(`documentCertificationCardId`) and the certification page renders its front
and back images, so it cannot move.

### Owner picker sheet

One generic sheet, `DocumentOwnerPickerSheet`, returning a `DocumentOwner`:

- A row of kind choices: Personal and the eight owner kinds of
  `DocumentOwnerKind`.
- Below it, for a non-personal kind, a search field and the active diver's
  records of that kind, each as a label and optional subtitle. Dives read
  `#<number>` with the site name and date as subtitle; every other kind reads
  its name. Club library sites (#3324, `dive_sites.shared_library_id` set)
  are not offered: their rows belong to another library, so a personal
  document filed there would sync a link that other devices may lack.
- Choosing Personal, or a record, pops the sheet with that owner. The current
  owner is marked.

The rows come from `DocumentOwnerOptionsRepository.optionsFor(kind,
diverId:)`, one small query per kind returning `(id, label, subtitle)`. Eight
existing pickers were considered and rejected: they differ in signature, some
are multi-select and two are private to other features.

### Saving

`DocumentMutations.save` is unchanged. `documentToCompanion` writes every
owner column on each save, null except the current kind's, so moving a
document clears its old link. Sync, reminders and the Documents list grouping
need no change.

## 2. Certification card titles

A certification card document's title is its certification's name, wherever a
document title shows (Documents list tile, detail page app bar, owner
sections). It is derived, not stored:

- `documentDisplayTitle` takes the owner label as an optional argument and,
  for a card document, returns it ahead of the stored title and the type
  name. Callers that hold a `DocumentListEntry` pass `entry.ownerLabel`, which
  `_entries()` already joins from `certifications.name`.
- The form hides the Title field for a card document.
- No migration: every card document was created with an empty title
  (`document_migrations.dart`, `DocumentRepository` card upsert).

Renaming a certification renames its card with no extra write and no sync
traffic. List search already matches `ownerLabel`, so it needs no change.

## 3. Converting gear files

### Converter

`EquipmentFileConverter` (data layer, `features/documents`), one `run()`:

1. Select every `media` row with a non-null `equipment_id` whose equipment
   row exists. The diver is the equipment's `diver_id`.
2. Skip, without retrying, a row that can never convert: an extension
   `checkDocumentFile` rejects (`.gpx`), recognised from the file name, or a
   file already found over `kMaxDocumentPageBytes` (10 MB). The media table
   holds no size for a linked file, so an oversize file is only found by
   reading it; its media id then goes into the per-device preference
   `equipmentFileConversionSkipped`, so it is not re-read every launch.
3. Resolve the bytes through the media byte resolver the old viewer uses. A
   row whose bytes are unavailable on this device is left for a later run.
4. Run `checkDocumentFile` on the bytes actually read (an image is not
   expected, the old picker never offered one).
5. In one transaction:
   - If a document with id `documentEquipmentFileId(mediaId)` exists (a peer
     converted it and sync delivered it), insert nothing.
   - Otherwise insert the document and one page:
     - id `documentEquipmentFileId(mediaId)`, a UUIDv5 under
       `kDocumentNamespace` with key `equipmentFile:<mediaId>`; the page id is
       `documentEquipmentFilePageId(documentId)`.
     - owner: the equipment; type `receipt`; title: the file name without its
       extension; notes: the media caption, if any; `createdAt` from the media
       row, `updatedAt` now.
   - In both cases, delete the media row with the same steps as
     `MediaRepository.deleteMedia` (enrichment rows, row,
     `logDeletion('media', ...)`).
6. Notify a local change once if anything converted.

Deterministic ids mean two devices converting the same file produce the same
document, so sync merges instead of duplicating. The user's original file on
disk is never touched; only the link row goes away.

### When it runs

From a provider, after the database opens at startup and after each
successful sync (beside `galleryOriginBackfillProvider` in
`sync_providers.dart`). Runs are serialized so two never overlap. A failure is
logged and never shown.

### Gear page

- The old card's Attach document action is removed. The library card's Add
  document is the one way to add paperwork.
- The old card shows only while unconvertible files remain. It is retitled
  "Linked files" with the line "Too large, or a format Documents cannot
  hold", and its files open as before. With none left it is not shown.

### Trade-off

Converted files are copied into the synced database, where #1517 linked them
by reference. The same 10 MB per page cap that bounds every library document
applies.

## 4. Document detail layout

- The body becomes a `Column`: the pages viewer is `Expanded`, followed by a
  details panel. The fixed 320 px box and the outer `ListView` are removed.
- The details panel is collapsed by default to one line (type, expiry badge,
  filed under) and expands to the full details card, scrolling within itself
  when taller than half the page.
- At the master-detail breakpoint the details sit in a side column of fixed
  width beside the viewer instead.
- The PDF now owns its vertical drag: it scrolls and zooms in place. Swiping
  between a document's pages stays horizontal.

## 5. Trip documents

In `TripStoryView` (trips under way or finished), the Documents card moves
from the trailing slivers to directly after the stat strip, before the
under-way cards and day chapters, in both the normal layout and the layout
that opens at today. `TripPrepareOverview` (upcoming trips) already shows it
after the summary and notes, and is unchanged.

Reversed by #3711: on every trip the Documents card is again the last section,
after the day chapters and the notes.

## 6. Reclaiming database space

### Deciding, while the app runs

`DatabaseCompactionMonitor` reads `PRAGMA freelist_count` and `PRAGMA
page_size` on the normal connection:

- after a document delete,
- after a converter run that converted anything,
- once per session, after startup settles.

When reclaimable bytes are at least **50 MB and at least 25% of the file**,
and no backoff is in force, it sets the per-device preference
`compactDatabaseAtNextLaunch` (SharedPreferences, never synced: it describes
this device's file).

### Acting, at launch

`DatabaseService.initialize` gains two optional parameters: `compaction` (a
`DatabaseCompactionPrefs`, default null) and `onCompacting` (a callback). Null
`compaction` never compacts. Only the startup page's launch passes one, so the
headless background service (`background_service.dart`) and the reopen after
a database move never compact.

When `compaction` is passed and its request preference is set:

1. Clear the preference first, so a crash during the rewrite cannot bring the
   next launch back into it.
2. Before the background worker opens the file, on a connection of its own
   in a separate isolate (`Isolate.run`), run `VACUUM`, then
   `PRAGMA wal_checkpoint(TRUNCATE)` so the file shrinks. A separate isolate
   keeps the startup screen responsive during the rewrite.
3. Tell the startup page through `onCompacting`; it shows an
   indeterminate bar and "Optimizing storage...". (The existing migration
   progress bar only appears when a pre-check predicted a migration.)
4. On failure (busy lock, no space for the temporary copy), log a warning and
   record `compactDatabaseBackoffUntil` seven days ahead, during which the
   monitor does not schedule another. The database stays correct, only
   larger. Then the normal open continues.

When a pending migration runs its own VACUUM at the same launch, the
preference is cleared as satisfied, and step 2 is skipped.

### Settings > Storage

The Database row of the Storage usage page gains:

- a line "N MB reclaimable" whenever at least 1 MB is reclaimable;
- a Compact button with that line. It confirms ("Runs the next time
  Submersion starts. A large log may take a minute and needs free space about
  the size of the database.") and sets the preference, ignoring the threshold
  and the backoff;
- while scheduled, "Scheduled for next launch" with Cancel, and on desktop
  Quit now. Cancel withdraws the request and records the same seven-day
  backoff a failure does, so the app's own check does not schedule it
  straight back; Compact still works during it.

## Out of scope

- Linking one document to several records.
- A quick Move action on the detail page and bulk refiling in the list.
- PDFs attached as media to dives and sites (the same older mechanism).
- Pruning backups, each a full copy of the database.

## Testing

TDD throughout.

- `DocumentOwnerOptionsRepository`: each kind's rows, scoped to the diver,
  dive labels.
- Owner picker sheet and form field: choose, change, clear to Personal,
  prefilled from an owner page, locked for a card document; saving moves the
  document between owner sections and clears the old column.
- `documentDisplayTitle`: card document uses the certification name; others
  unchanged.
- `EquipmentFileConverter` against an in-memory database: converts a
  readable PDF and tombstones the media row; leaves an unreadable one;
  skips `.gpx` and an over-size file; a document already present (peer
  conversion) writes nothing but still deletes the media row; a second run is
  a no-op; deterministic ids.
- Gear page: one Documents card; "Linked files" only with unconvertible
  files.
- Document detail: the viewer is not height-capped (its height tracks the
  page), details collapse and expand, side column at the breakpoint.
- Trip story view: the Documents card precedes the first day chapter in both
  layouts.
- `DatabaseCompactionMonitor`: both threshold halves, backoff, preference
  set and not set.
- `DatabaseService` startup branch against a real temporary database file:
  compacts and shrinks the file, clears the preference first, skips without
  `compaction` prefs, records backoff on failure.
- Storage page: reclaimable line, Compact, Cancel (with its backoff).
- Screenshots before and after for the PR: Documents list, document detail
  with a PDF (phone and desktop), document form with Filed under and the
  picker, gear page, trip overview, Storage page.
