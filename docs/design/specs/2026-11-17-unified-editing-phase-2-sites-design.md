# Unified editing, phase 2: dive sites

Issue: #4527 (the whole pattern). This note is phase 2 of
[the unified editing pattern](2026-11-14-unified-editing-pattern-design.md),
which it does not repeat: the rule, the bar, the card states, the Add strip,
saving, cancelling, leaving, whole-record operations and History all apply to
sites as written there. This note says what is different for sites, and how
the site edit form goes away.

Phase 1 ended with PR #4677 (plan 11, merged 2026-11-17). Its eleven plans are
`docs/design/plans/2026-11-14-unified-editing-1-skeleton.md` to
`2026-11-17-unified-editing-11-switch-over.md`.

## Why

A site is a record the diver keeps, so it follows the same rule as a dive:
**nothing recorded changes without unlocking.** Today the site page writes at
once in several places (features, expected species, media, documents, the
catalogue offer) while most fields sit behind an Edit button on a separate
2,691-line form whose six groups do not match the page's cards. After phase 1
the two record types a diver touches most would behave differently. Phase 2
makes them the same, and turns the page wiring phase 1 wrote for dives into a
shared piece that phase 3 (about ten more record types) can use as it stands.

## Goals

- The site page opens locked everywhere it is shown: the full page, the site
  list's pane, and a site opened inside the dive list's pane.
- Every change to a site is made in a sitting: one Save, one History entry,
  Cancel undoes all of it.
- A new site, and a duplicate, open on the site page itself, already
  unlocked. No form survives for creating or editing one site.
- A library reader suggests changes through the same page and the same bar.
- The page wiring that phase 1 wrote for dives becomes a shared host, used by
  the dive page and the site page alike.

## Non-goals

- Changing merge. It stays a form of its own (see "Merge").
- Changing the catalogue review page (`/sites/catalogue-review`), which works
  through many sites at once. It is a deliberate mode, like bulk edit.
- Changing the built-in catalogue's own page (`/sites/catalogue/:id`). It
  writes nothing but "Add to my sites", which creates a record.
- Changing how the owner reviews suggestions (`SuggestionInboxPage`).
- Changing the site list, the map page, import or the site picker, beyond
  where they open a new site.
- Redesigning the read layout of the site page, beyond the one "Shared with"
  line below.
- Any change to the dive page's behaviour. Moving it onto the shared host must
  leave it exactly as it is.

## Anti-goals

Those of the pattern, plus:

- A second way to fill in a new site (a duplicate form beside the new-site
  page).
- A reader's sitting that writes the library site itself.
- The dive page behaving differently after it moves onto the shared host.
- A rule that the form ran (filling place names, the altitude lookup) lost on
  the way to the cards.

## Current state (for orientation)

- **Site page.** `lib/features/dive_sites/presentation/pages/site_detail_page.dart`
  (2,536 lines). Above the sections, not configurable: the map preview (when
  the site has coordinates), `SiteDetailHeader` (name, rating stars, place
  with flag, chips for types, difficulty and water type, the catalogue credit
  line and `SiteCatalogueOfferLine`), and `SharedByBanner`. Then
  `SiteDetailSectionList`, one card per `SiteDetailSectionId`
  (`lib/core/constants/site_detail_sections.dart`), in the diver's order with
  hidden cards left out (`settings.siteDetailSections`). Cards left out when
  empty: dive photos, seascape, features, reef health and tide (no
  coordinates, or fresh water for tide), altitude, tags, difficulty, hazards,
  access.
- **Three hosts.** The full page (`/sites/:siteId`), the site list's
  `MasterDetailScaffold` pane (`site_list_page.dart:116`, `:284`), and the dive
  list's pane, where `DiveDetailPage` hands its place to
  `SiteDetailPage(embedded: true)` (`dive_detail_page.dart:454`). The full page
  menu has no Delete today; the pane menu does.
- **Site edit form.** `site_edit_page.dart` and `widgets/edit_sections/`. Six
  groups: Identity, Type & Tags, Location, Dive info, Access & Safety, Life &
  Notes. It serves create, edit, duplicate (`/sites/new?duplicateOf=`), merge
  (`SiteMergePage` is a 14-line wrapper), the embedded pane, and suggest mode
  for a library reader. Its unsaved check is a `_hasChanges` flag, not a
  comparison.
- **Saving.** `SiteListNotifier.updateSite` writes every column from a
  `DiveSite` built fresh from the form, in one transaction with the types and
  tags (`site_repository_impl.dart:330-400`), except `catalogueId`,
  `catalogueAnswers` and `sharedLibraryId`, which it never writes. After it,
  in separate writes with no shared transaction: sharing
  (`itemSharesRepository.setSharing`), expected species
  (`siteExpectedSpeciesNotifier.setSpecies`, delete all then add each), a
  duplicate's features (`copyFeatures`), and the rules run after creating.
- **History.** `dive_sites` is already a change log root. Its child tables
  (`site_features`, `site_species`, `site_site_types`, `site_tags`,
  `site_shares`, `site_hides`, `library_site_notes`) are logged under it. Both
  of the page's menus already have a History item.
- **Photos.** The site's photo viewer (`SiteMediaViewerPage`) already has its
  own lock from phase 1 (plan 10).

## Approaches

1. **Extract the shared host first, then build sites on it.** The first plan
   lifts the type-free part of the dive page's wiring into a shared host and
   moves the dive page onto it, with the dive page's tests proving nothing
   moved. Sites are then built on that host. Cost: the first plan touches
   shipped dive code. Gain: phase 3 gets the page wiring as it stands.
2. **Copy the dive wiring into a site mixin now, and generalise in phase 3.**
   No risk to dives today. Cost: about 500 lines in two copies that can drift
   apart until phase 3.
3. **Make the site page a variant of the dive page's section list.** Dropped:
   the two pages share little beyond the card frame (sites have the pinned map,
   the catalogue line and three hosts).

**Picked: 1**, by Eric.

## Decisions

Made by Eric, in the order they were made:

1. A duplicate opens the new-site page, unlocked and prefilled from the
   original, over keeping a duplicate form beside merge. Merge is the only
   site form left.
2. The catalogue offer's Review is held in the sitting, like the dive page's
   site suggestion card, over a whole-record operation.
3. A library reader's note to the owner is asked for in a dialog at Send, over
   a reader-only card on the page.
4. A new site's starter set is Location, Depth and Notes, over Location alone.
5. Sharing with other profiles is edited in the header block's editor, and the
   locked page shows a "Shared with" line under the header for the owner, over
   leaving sharing invisible on the locked page.
6. A new site's seeds (a name from the picker, a point from the map, a
   duplicate's values) are changes: the card shows its dot, Save is enabled at
   once, and Cancel asks first, over seeds that count as the starting record.
7. Build approach 1: extract the shared host first.
8. An attachment owns its details (category, display size), over holding
   them in the site's sitting. The PDF viewer gets a lock of its own, like the
   photo viewer, and Edit details leaves the site's Media card.
9. A document with no viewer opens a small details page for that attachment,
   which opens locked, over keeping an Edit details sheet on the card for
   such documents.
10. For a site that has coordinates and no altitude, the found altitude is
    offered as a suggestion on the Altitude card and is a change only when
    tapped, over filling it on unlock or never looking it up.

Proposed in the conversation and not corrected (see also "Calls made in this
note" at the end):

- Features, expected species, media and documents become held card edits.
  Features are edited on the fullscreen map, which obeys the site's lock as
  the dive's fullscreen profile does.
- Delete, remove from profile, unhide, add to library and delete from library
  become whole-record operations.
- All three hosts get the lock.

## Design: what sites reuse unchanged

From `lib/shared/widgets/record_editing/`, as phase 1 shipped them:

- `EditSession<T>` and `EditField<T, V>`: the working copy, field by field,
  with `holdChange`, `holdWrite`, `remember`, `track` and `rebase`.
- `SittingList<T, E>`: a held list of rows (species, features, media links,
  sharing).
- `RecordEditController<T>`: lock, open and added cards, the layout hold,
  invalid input, `save`, `runOperation`, `retake`, `creating`.
- `EditCard<T>`, `RecordCardFrame<T>`, `RecordCardHeader`, `RecordCardFade`,
  `RecordCardForm`, `RecordNumberRow`, `FieldTextBinding`.
- `AddStrip`, `AddStripLayout`.
- `RecordEditBar`.
- `RecordEditLeaveGuard`, `cancelSitting`, `RecordSittingExitBlocker`,
  `confirmLeaveRecordSitting`, `recordSittingPageOf`.
- The operation gate: `recordOperationBlockOf`, `recordOperationRunnerOf`,
  `recordOperationReason`, `recordOperationCaption`, `RecordOperationButton`.
- `RecordEditShortcuts` and its targets.
- `RecordEditLabel` (`lib/core/services/change_log/record_edit_label.dart`):
  a site sitting is labelled `record_edit:dive_sites:<id>:<cards>`. The change
  log settler already pins such an operation to the record it names, whatever
  the table.
- `AppExitGuard` and `MasterDetailScaffold`, which already ask before changing
  selection or creating while a sitting holds unsaved work.
- The photo viewer's lock (`SiteMediaViewerPage`), untouched.

## Design: what is generalised

Each of these is written for dives today and becomes shared. The dive page
moves onto each one in the same plan that makes it, and behaves exactly as
before.

- **The page host.** `_DiveDetailPageEditing`
  (`dive_detail_page_editing.dart`, 515 lines) holds, for dives only, the
  parts every record page needs: creating the controller and its
  `RecordSittingExitBlocker`, registering the shortcut target, following the
  stored record into the sitting (`followStoredDive`), the lock button, the
  editing title, `editScaffold` (bar, strip, scope, leave guard) and
  `editPane` with its pane header, `_saveAndReport` (the snack bars for
  invalid input and a failed save, and locking a sitting left on another
  record), `_justSaved` (the saved record shown until it is read back), and
  `_addStripEntries`. These move to a shared `RecordEditHost<T>` under
  `lib/shared/widgets/record_editing/` (name is the builder's), configured by
  what a record type supplies: its cards, its section order and visibility,
  whether each card is on the page, how to read the stored record, its save,
  its title, and whether it is creating. What stays in the dive mixin: the
  open-sitting slot for dropped files (`openDiveSittingProvider`), the
  flight-window warning under the strip, the new-dive path, and the embedded
  site handover (`embeddedSiteId`).
- **The pane's editing header.** `DiveDetailEmbeddedEditingHeader` has nothing
  dive-specific in its shape (Cancel, title, menu, Save). It becomes a shared
  `RecordEditPaneHeader` and both panes use it.
- **The sitting writer.** `DiveEditSaveService.save` and `.create` each open a
  `ChangeLogScope` with the source "manual" and a `RecordEditLabel`, run one
  transaction, re-read the stored record inside it, apply the sitting, decide
  whether anything changed, and run the held writes before and after the
  record. That frame becomes a shared function (for example
  `writeSitting<T>`), with the record's own read and write passed in. The dive
  service and the new `SiteEditSaveService` both use it.
- **History's card names.** `change_log_labels.dart` names a sitting's cards
  only for `dives` (through `DiveDetailSectionId`) and `media`. It gains a
  lookup per table, and `dive_sites` names its cards through
  `SiteDetailSectionId` plus the header block.
- **The documents card in a sitting.** `DocumentsSection` takes
  `EditSession<Dive>? editing` and reads `RecordEditScope<Dive>`. It becomes
  generic over the record type (or takes the scope it needs from its owner), so
  the site's Documents card holds attach and remove as the dive's does.
- **The build switch.** Phase 1's `kUnlockEditing` is gone. Phase 2 adds
  `kUnlockSiteEditing` (off by default, turned on with a `--dart-define`), read
  only by the site page, the site routes and the places that open a new site.

## Design: the site page's cards

A field is edited on the card that shows it. Section ids are
`SiteDetailSectionId` values. The **header block** is the part above the
sections: `SiteDetailHeader`, the catalogue line and `SharedByBanner`. The map
preview is not a card; it reads only.

| Card | Its editor holds |
| --- | --- |
| Header block | Name (required, with the similar-name hint), site types, water type, sharing with other profiles; the catalogue offer's Review (held) |
| `description` | Description |
| `location` | Latitude and longitude, Use my location, Pick from map, Look up from coordinates, country (with its code), region, city, island, body of water |
| `altitude` | Altitude |
| `depth` | Minimum and maximum depth |
| `difficulty` | Difficulty |
| `rating` | Rating |
| `hazards` | Hazards |
| `access` | Parking, access notes, entry methods (with the entry-history suggestion), exit methods, mooring number |
| `features` | Add, move, edit and delete features, on the fullscreen map |
| `marineLife` | Expected species |
| `media` | Add photos, add a document attachment, unlink |
| `documents` | Attach, remove |
| `tags` | Tags |
| `notes` | Notes |

Cards with nothing to edit fade back when unlocked, labelled "Calculated":
`diveStatistics`, `divePhotos`, `tide`, `seascape`, `reefHealth`.

Notes on the table:

- Site types and water type show only as chips in the header today, and
  difficulty and rating show both as header chips and on their own cards. Each
  is edited in one place: types and water type on the header block, difficulty
  and rating on their cards.
- `features`, `seascape`, `reefHealth` and `tide` are left out until the site
  has coordinates. Features are not offered in the Add strip without
  coordinates, since there is nowhere to place one (`offeredWhenEmpty`).
- Units in every editor follow the active diver's settings, as the form does.
- **Sharing becomes visible.** The locked page gains one line under the
  header for the owner when the site is shared with other profiles ("Shared
  with Alex, Sam"). It is offered only with two or more divers in the logbook
  and never on a library site, as the form offers it today. The test that pins
  "the owner sees no Shared with row" changes.

## Design: rules that span cards

The form keeps these in widget state. They become functions of the sitting,
each keeping today's behaviour. A rule that changes a value on another card
gives that card its changed dot.

| Change | Effect |
| --- | --- |
| Coordinates set by Use my location or Pick from map | Fill the empty place fields (country, region, city, body of water) from a reverse lookup (`mergeLocationDetails`) |
| Look up from coordinates | Fills empty place fields, and asks before replacing ones that differ |
| Coordinates changed in the sitting | After the same one-second pause, looks up the elevation and fills an empty altitude; tracked work, so Save waits for it. A filled altitude is a change of `altitude` |
| A site with coordinates and no altitude, coordinates untouched | Nothing is filled. The Altitude card (a chip in the strip, or its open editor) offers the elevation found for the coordinates as a suggestion, "Use 12 m (from these coordinates)", as the dive header offers its "from profile" values. Tapping it makes the change. The lookup runs once per sitting (`EditSession.firstTime`), and only when the card is shown or opened, so unlocking alone neither waits on the network nor dirties the sitting |
| Country | Keeps its country code with it |
| Coordinates cleared | `features` leaves the strip; existing features are kept |

Nothing is looked up at Save, as today.

## Design: what is held, and what is not

Every action the site page performs in place today:

| Today | Becomes |
| --- | --- |
| Every form field | Held, on the card named above |
| Add, edit, move, delete a feature (fullscreen map, feature sheet) | Held: `features` editor. The fullscreen map opened from a locked page places nothing and its features read only; opened during a sitting its changes go to the sitting |
| Edit expected species | Held: `marineLife` editor |
| Add photos, add a document attachment, unlink media | Held: `media` editor, as the dive's media card |
| Edit details of one attachment (category, display size), from the card or the PDF viewer | The attachment's own lock, not the site's (see "Attachments"). It leaves the card |
| Set category on several checked attachments | A bulk edit: a deliberate mode with its own confirmation, outside the site's sitting, available locked or unlocked, as dive bulk edit is |
| Attach or remove a document | Held: `documents` editor, as the dive's |
| Catalogue offer, Review: fill fields, link the record, "not the same", "no thanks" | Held: the header block. Filled fields are changes of their cards; the link and the answers are a held change written with the sitting (through the fill repository, since `updateSite` never writes the link) |
| Delete | Whole-record operation, in the menu of every host (the full page gains it) |
| Remove from profile, unhide | Whole-record operations |
| Add to library, delete from library | Whole-record operations, keeping their confirmations |
| Duplicate | Not a change: creates another record, works while locked |
| Merge (from the list) | Not on the page; unchanged |
| History, display options, folds, the 3D views | Not changes; work while locked |
| Suggest changes (reader) | Becomes the reader's unlock (see "A library reader") |
| Connect on this device (library not connected) | Unchanged, works while locked |

Not held, and unaffected by Cancel, as on a dive: a site type created from the
type picker's "manage types", and a tag created from the tag picker. Creating
a record is outside the rule.

Written with the sitting, in its one transaction and History entry: the site
row, types and tags (as today), sharing, expected species, features, the media
and document links, the catalogue link and answers. After the commit, best
effort and outside the entry, as on a dive: anything that leaves the database
(a media file's own bookkeeping, remote blobs) and cache refreshes.

## Design: a library reader

A diver's site can belong to a shared site library (issue #2567). A reader
cannot edit it, but can suggest changes; notes and rating are the reader's own.

- **The unlock reads "Suggest changes"** (the existing
  `sharedLibrary_suggest_title`), in place of the lock, and the unlocked bar's
  title says so. The detail page's separate "Suggest changes" button goes.
- **Cards in a reader's sitting.** The cards a suggestion can carry (the site
  row's shared fields, types and tags) get pencils. Notes and rating get
  pencils and say "Only you". Features and expected species fade, labelled
  "Library". Media and documents are the reader's own attachments and are held
  like anyone's. Sharing is not offered.
- **Save reads "Send".** Tapping it opens a small dialog with an optional note
  to the owner, then:
  - the private changes (notes, rating, the reader's attachments) are written
    as one History entry, in one transaction, as any sitting;
  - the changed shared fields, types and tags go to
    `SuggestionService.propose` with the note. The site itself is untouched.
  - The snack bar says what happened, as today ("sent", "saved privately",
    "nothing changed").
- **Cancel** discards both.
- The catalogue offer's Review is not offered in a reader's sitting: a fill
  writes the library site, which a reader cannot do (`applyFill` and
  `updateAnswers` refuse it). The offer line reads only.
- Whether the sitting edits or suggests is decided again at Send, from the
  role as stored then (as `_libraryRoleNow` reads it), however the sitting was
  opened. `?suggest=1` only chooses how the page unlocks. Today's
  `_suggestModeAtSave` trusts `?suggest=1` without asking the role
  (`site_edit_page.dart:2093`); the new check does not, so an editor who
  arrives by that address edits rather than suggests. A library not connected
  on this device offers no unlock at all (see "Calls made in this note").
- Whole-record operations follow the role as today: a reader may remove the
  site from their profile; delete from library is for editors and owners
  (`canDeleteLibrarySite`, `shared_item_policy.dart:86`).

## Design: hosts and routes

- **Full page** (`/sites/:siteId`): `RecordEditHost` with the locked bar
  (name, terrain, History beside the lock where there is room, the lock or
  "Suggest changes", the menu) and `RecordEditBar` when unlocked.
- **Site list pane** (`/sites?selected=`): the embedded header carries the same
  lock, and the shared pane header when unlocked. The pane no longer swaps to
  an edit widget: `editBuilder` goes, and `&mode=edit` opens the page
  unlocked.
- **Inside the dive list's pane** (`/dives?selected=<dive>&site=<site>`): the
  same lock and the same sitting. Its back arrow (`onClose`) back to the dive
  is a leave: with unsaved changes it asks first. `&mode=edit` there opens the
  site unlocked.
- **Routes.** `/sites/:siteId/edit` redirects to `/sites/:siteId?mode=edit`,
  which opens the page unlocked; `?suggest=1` on it opens a reader's sitting.
  `/sites/new` opens the new-site page. Each site route gets
  `onExit: confirmLeaveRecordSitting`, as the dive routes did.
- **Links that open the edit form today** lose it (the Edit buttons on the
  page and the pane) or point at the unlocked page (the site summary, the map
  page, the list's empty state).

## Design: a new site

- **The page** is the site page itself, built from a seed: a `DiveSite` that
  exists only in memory, with a fresh id and nothing else set, as plan 8's new
  dive is. The sitting is `creating`.
- **Essential card:** the header block (name is required). **Starter set:**
  Location, Depth, Notes, laid out open. Every other card is a chip in the
  strip. Calculated cards are not shown until the site exists.
- **Seeds are changes.** A name from the picker, a point from the map, and the
  place names its reverse lookup brings are applied after unlock through the
  cards' own functions, so each card shows its dot, Save is enabled at once,
  and Cancel asks before discarding. Cards holding a seed are laid out open.
- **Defaults are not seeds.** What settings give every new site (sharing with
  other profiles by default, `site_edit_page.dart:265-277`) is part of the
  starting record, as a new dive's default cylinder is in plan 8: no dot, and
  nothing for Cancel to ask about.
- **Duplicate** (`/sites/new?duplicateOf=<id>`) opens the same page. The
  original's values, types, tags, expected species, features and sharing
  (copied today for issue #3575) are prefills in the same way: changes, laid
  out open on their cards, held until Save. Nothing is written until Save.
- **Save** creates the site through `SiteEditSaveService.create` (insert, then
  the held writes, in one transaction and one change log operation), runs what
  the form runs after creating (`rulesAfterCreate`), and shows the site
  locked. A page pushed by the site picker (`pickOrCreateSite`) pops with the
  new id, as the form does, so the dive's sitting receives it. The site is
  created at that moment and survives a Cancel of the dive's sitting, as
  today.
- **Cancel** leaves without creating anything, asking first when there is a
  change (which includes a seed).
- **Where it opens:** `/sites/new` (full page) and the list pane's
  `?mode=new`. The list's add button, the empty state, the map page and the
  site picker's "Create" all use these, unchanged.

## Design: attachments

A site attachment is a `media` row of its own, so, like a photo in phase 1, it
is a record with its own lock, wherever it is opened from. Its details are
category and display size. Plan 10 already made both of them `EditField`s of
the photo sitting (`PhotoRecord`) for `SiteMediaViewerPage`; that work is
reused, not repeated.

- **Photos** keep the photo viewer's lock as shipped.
- **PDF documents.** `DocumentViewerPage` (opened from the site page with
  `editableSiteId`) gets the same lock: it opens locked, with no Edit details;
  Unlock gives the shared Cancel and Save bar, the details are held, and Save
  writes them as one History entry. It uses the shared session, controller,
  bar and leave check, and the photo viewer's sitting and save service where
  they fit (`PhotoViewerEditing`, `PhotoEditSaveService`); the builder decides
  how much of them it takes as they stand. Opened from a dive, where it offers
  no Edit details today, it offers no unlock.
- **Documents with no viewer** (a Word file, a spreadsheet). Tapping one opens
  a small details page for that attachment: its name, Open, Share, and the
  details, read only. It opens locked; Unlock edits the details on the same
  terms as the PDF viewer.
- **The site's Media card** keeps add and unlink (held in the site's
  sitting) and the bulk Set category (a bulk edit). Its single Edit details
  goes.
- The attachment's lock is separate from the site's. Opening an attachment
  from a site that is being edited does not end the site's sitting.

## Design: merge

Merge stays its own form. Today it is `SiteEditPage(mergeSiteIds:)`, sharing
the form's sections and adding `merge_field_extras.dart`. Before the form is
deleted, merge moves to a page of its own, holding only what merge uses, as
bulk dive edit was moved out of the dive form in plan 11. The field widgets in
`widgets/edit_sections/` that both merge and the card editors need move to
files of their own, so neither depends on the other. Merge's behaviour does
not change.

## Design: saving

- **`SiteEditSaveService`** (new, beside `DiveEditSaveService`), on the shared
  sitting writer. Inside one `ChangeLogScope` (source "manual", label
  `record_edit:dive_sites:<id>:<cards>`) and one transaction: read the site as
  stored, apply the sitting's changed fields onto it (`EditSession.applyTo`),
  write the row and the classification through the repository's existing
  update path (which keeps library stamping, the owner-only sharing column and
  the sync stamp), then run the held changes.
- **Only what changed is written.** `updateSite` writes every column from the
  entity it is given. Because the entity is the stored site with only the
  sitting's changes applied, a field no card touched is carried through, and a
  sync that lands mid-sitting is not overwritten. A test asserts this for every
  column, as `dive_edit_save_field_census_test.dart` does for dives.
- **The separate writes join the transaction.** Sharing, expected species,
  features and the catalogue answers become held changes, so a failure rolls
  back the whole sitting. `setSpecies` writes each row in a loop today; it
  runs inside the sitting's transaction instead.
- **A refusal fails the whole Save.** Two held writes can be refused without
  throwing today: the catalogue fill, which works the offer out again from the
  stored row and can find the record claimed by another site, linked
  elsewhere since, or not the profile's to edit
  (`site_catalogue_fill_repository.dart:21-37`); and sharing, which
  `setSharing` refuses for a profile that may not share. Each is a separate
  write with its own snack bar today. In a sitting, a refusal counts as a
  failure: the transaction rolls back, nothing is written, the page stays
  unlocked, and the message names what was refused. Save is all or nothing,
  so the shared sitting writer never reports a partial save.
- A save that fails leaves the page unlocked with the sitting intact, as on a
  dive.
- After the commit: the site list and the dive list's site names are
  refreshed, guarded, so a failed refresh does not read as a failed save.

## Design: what happens to the edit form

- Merge moves out first (see "Merge").
- When every card has its editor and a new site opens on the page, the last
  phase 2 plan turns `kUnlockSiteEditing` on, removes the Edit buttons, makes
  the old addresses open the page unlocked, and deletes `site_edit_page.dart`,
  the section widgets only it used, and its tests.
- Each `site_edit_*` test file moves to the card that owns the behaviour it
  covers; none is dropped without a replacement. The suggest-mode tests move
  to the reader's sitting.

## Calls made in this note

Eric has not explicitly confirmed these. Correct any of them:

- Which card each field is edited on (the table under "The site page's
  cards"), including site types, water type and sharing on the header block,
  and difficulty and rating on their own cards.
- The five calculated cards, faded and labelled "Calculated".
- Features are not offered in the strip without coordinates.
- An altitude filled because the diver changed the coordinates is a change of
  the altitude card (the form filled it without marking the form changed; it
  was saved with it all the same).
- The bulk Set category on the Media card is a bulk edit, available whether
  the site is locked or not.
- The PDF viewer offers its lock only where it offers Edit details today
  (opened from a site).
- The full page's menu gains Delete as a whole-record operation (today it is
  only on the edit form and in the pane's menu).
- A library not connected on this device keeps its "Connect on this device"
  button and shows no lock until connected, since nothing can be edited or
  suggested before then.
- In a reader's sitting, features and species are labelled "Library", notes
  and rating "Only you", and the role is checked again at Send.
- The site inside the dive list's pane is a full host: its back arrow to the
  dive asks first with unsaved changes.
- `/sites/:id/edit` redirects to `/sites/:id?mode=edit`, as the dive's did.
- A site type or tag created from a picker during a sitting survives Cancel.
- A held write refused at Save fails the whole Save (see "Saving").
- In a reader's sitting the catalogue offer reads only.
- The editing or suggesting decision is taken from the stored role at Send,
  not from `?suggest=1`.
- Sharing by default is part of a new site's starting record; a duplicate's
  sharing is a prefill.

## Left to the builder

- Names and file layout of the shared host, the pane header and the sitting
  writer.
- The order in which cards move from the form to card editors.
- How the fullscreen map learns of the sitting (phase 1's fullscreen profile
  is the model).
- Wording of new strings ("Only you", "Library", "Send", the note dialog, the
  "Shared with" line). Every new string goes into all locales.
- If an action listed as held turns out to be impossible to hold, stop and
  raise it. Do not make it immediate silently.

## Testing

- The dive page's existing tests pass unchanged after it moves onto the shared
  host and the shared sitting writer. That is the proof the extraction moved
  nothing.
- The shared host is tested alone, with a small fake record type: lock, bar
  swap, strip, leave check, full page and pane.
- Each site card editor has its own widget tests.
- A locked site page makes no repository write on any tap, in all three hosts.
- A sitting that changes several cards produces exactly one change log
  operation, and reverting it restores every value, including features,
  species, sharing, the catalogue link and answers. It covers the media and
  document links too: those tables are not children of `dive_sites` (`media`
  hangs off `dives`, `documents` is its own root, `change_log_policy.dart:81`,
  `:373`), so they reach the site's entry through the label naming the site,
  not through parentage.
- A held write refused at Save (a catalogue fill claimed by another site,
  sharing refused) writes nothing and leaves the page unlocked.
- A Save that fails partway writes nothing and leaves the page unlocked.
- A value changed in storage during a sitting, on a card the diver did not
  touch, survives the Save; a field census test covers every site column.
- A reader's Send writes only the private fields to the row and proposes the
  rest; Cancel writes nothing.
- A new site and a duplicate: seeds and prefills are changes, Cancel asks,
  Save creates and returns the id to the site picker.
- Merge behaves exactly as before, from its own page.
- The PDF viewer and the document details page make no write while locked;
  unlocked, one Save writes the details as one History entry.
- For a site with coordinates and no altitude, unlocking leaves the sitting
  clean; the suggestion is a change only once tapped.

## Delivery

Phase 2 lands as a series of pull requests, each referring to #4527, with the
site's new behaviour behind `kUnlockSiteEditing` until the last. Each plan is
written against the names the previous one shipped. A likely order, for the
plans to refine:

1. The shared host, pane header, sitting writer and History card names; the
   dive page moved onto them unchanged; the site page on the host with
   Description and Notes editable, behind the switch.
2. The plain cards: the header block (without sharing and the catalogue
   offer), Location with its rules, Altitude, Depth, Difficulty, Rating,
   Hazards, Access.
3. The collections: types and tags, expected species, features on the
   fullscreen map, media, documents, sharing and the "Shared with" line, the
   catalogue offer.
4. Whole-record operations, the three hosts, routes and leave checks.
   Attachments: the PDF viewer's lock and the document details page (this can
   be a plan of its own if it grows).
5. A library reader's sitting.
6. A new site and duplicate.
7. Switch-over: merge to its own page, the switch on, the old addresses
   redirected, the form deleted.

No table or column is added. If History needs to log a site child table it
does not log today, that is a change to the change log policy and its
generated triggers, following phase 1's plan 9.

Pull requests that change anything visible carry screenshots. While the new
page is behind the switch, they come from a build with the switch on or from
headless widget-test goldens.
