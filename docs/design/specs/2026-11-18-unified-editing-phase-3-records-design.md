# Unified editing, phase 3: the other record pages

Issue: #4527 (the whole pattern). This note is phase 3 of
[the unified editing pattern](2026-11-14-unified-editing-pattern-design.md),
which it does not repeat: the rule, the bar, the card states, the Add strip,
saving, cancelling, leaving, whole-record operations and History all apply as
written there. It builds on
[phase 2](2026-11-17-unified-editing-phase-2-sites-design.md), which turned
the dive page's wiring into shared pieces, and it says only what is different
for each record type, and how each type's edit form goes away.

Phase 1 (dives) ended with PR #4677. Phase 2 (sites) is in progress: plans 1
and 2 merged (#4686, #4688), plan 3 is open (#4694), and plans 4 to 7 follow
(whole-record operations and hosts, the library reader, a new site and
duplicate, switch-over).

## Why

After phase 2 the two record types a diver touches most follow one rule:
**nothing recorded changes without unlocking.** Every other record with a page
of its own still does it its own way. Each has an Edit button that opens a
separate form (nine forms, about 8,300 lines between them), none of them on
the shared form parts, most with a private unsaved-changes flag and two with
none. And each page writes at once in places of its own: a buddy's favourite,
lending gear, a course requirement ticked, a fill logged on a cylinder, a trip
checklist item, a gear item moved, a track renamed. Several of these are one
tap with no confirmation and no undo.

Phase 3 brings every remaining record page onto the same pattern, so that the
rule holds wherever a diver looks at a record.

## Goals

- Every record type below opens locked wherever it is shown: full page, list
  pane, and the pages opened from it that edit its data.
- Every change to one of these records is made in a sitting: one Save, one
  History entry, Cancel undoes all of it. That includes the day-to-day
  logging on gear, trips and courses (pattern decision 4).
- A new record and a duplicate open on the record's own page, already
  unlocked. No form survives for creating or editing one record of these
  types.
- Nothing a diver records is invisible: a value that today is edited on a
  form but shown nowhere gains a row on its card when it is set.
- The shared pieces from phases 1 and 2 are used as they stand where they
  fit, and generalised once, in shared code, where they do not.

## Non-goals

- Changing merge (buddies). It keeps a form of its own (see "Merge").
- Changing bulk actions on the lists (equipment's retire, move, tag, share,
  transfer; bulk delete and hide on buddies, centres and trips), import,
  the buddy card exchange (`BuddySwapPage`, `BuddyCardPreviewPage`) or the
  tools under settings (`LinkBuddyNamesPage`, `RetypeOtherGearPage`). They are
  deliberate modes.
- The editors with no read page (phase 4): incidents, transmitters, cylinder
  configurations, checklist templates, pre-dive templates, presets, rules,
  the diver profile pages. Where a phase 3 page opens one of them, that editor
  is a different record and is not covered by the phase 3 record's lock.
- Equipment locations. They are a settings list (pattern, "Outside the
  rule"); their small read page keeps its archive and delete as they are.
- Redesigning any read layout, beyond the rows named under "Values shown
  nowhere today".
- The pre-dive session runner. Starting a session creates a record of its own.

## Anti-goals

Those of the pattern and of phase 2, plus:

- A satellite page (a passport, the cylinder board) that writes outside a
  sitting.
- A held write to another record (a dive's trip link, a lent item's place, a
  partner cylinder's fill) that Cancel leaves behind, or that a failed Save
  leaves half written.
- A phase 3 type released with its old form still reachable.

## Current state (for orientation)

The full survey, with line numbers, is in the session notes; this is the
shape of it. Every page below is a plain column of cards (trips: six fixed
tabs). None has a section-id enum, a configurable order or hidden cards: only
dives and sites have those. None of the forms uses `EditFormScaffold`,
`FormSection` or `FormRow`.

| Type | Read page | Form | Hosts | Writes at once on the page today |
| --- | --- | --- | --- | --- |
| Buddy | `buddy_detail_page.dart` (740) | `buddy_edit_page.dart` (1,024; create, edit, merge, pane) | full, list pane, table mode | favourite (bar and list row), lend gear, returned (all, or one row), documents |
| Dive centre | `dive_center_detail_page.dart` (941) | `dive_center_edit_page.dart` (1,126; create, edit, pane) | full, list pane, table mode | rental gear notes, documents |
| Certification | `certification_detail_page.dart` (1,049) | `certification_edit_page.dart` (1,299; create, edit, pane, staging for the buddy form) | full, list pane, table mode | currency events and preferences, documents |
| Course | `course_detail_page.dart` (768) | `course_edit_page.dart` (545; create, edit, pane; no unsaved check) | full, list pane, table mode | mark completed, requirements (add, apply template, tick, edit, delete, credit and uncredit dives), documents |
| Document | `document_detail_page.dart` (246) | `document_edit_page.dart` (498; create, edit, pane, owner fixed for a sitting) | full, list pane | none |
| Species | `species_detail_page.dart` (496) | `species_edit_page.dart` (328; no unsaved check) | full | tag photos, add photos |
| GPS track | `gps_track_detail_page.dart` (591) | none | full | trim, reset trim, split |
| Underwater track | `nav_track_detail_page.dart` (763) | none (align page holds then saves) | full, align page | rename, link, relink, unlink, set site, set device, update from file, correction |
| Trip | `trip_detail_page.dart` (580) and six tabs | `trip_edit_page.dart` (1,351; create from selected dives, edit at a section or a day, pane) | full, list pane, table mode; the cylinder board and the gallery are routes of their own | gear add, pack, unpack, put on board; itinerary generate and day edit; checklists (create, template, save as template, clear, rename, reorder, delete, items, sections, ticks); the menu's scan dives, scan photos and Lightroom (behind `lightroomUiEnabled`); the gallery's scan; documents; the board's fills, adjustments, edits, deletes, reorder and the forecast's planned dives |
| Gear item | `equipment_detail_page.dart` (1,111) | `equipment_edit_page.dart` (1,416; create, edit, clone, new part, type and serial from the device lists, pane) | full, list pane, table mode, passports | mark purchased, sharing, move and past moves, twin sets, service clocks and records, findings, parts (replace), components (rewrite dives), photos and cover, observations, legacy files, documents, transmitter apply; the dive computer controls (favourite, merge, re-parse all, clock sync, auto-download) |
| Equipment set | `equipment_set_detail_page.dart` (596) | `equipment_set_edit_page.dart` (759; create, edit, clone) | full, sets pane (the full detail page, with no edit or create builder) | show figure, set as default |
| Passports | `passport_page.dart` (195), `gear_passport_page.dart` (156) | none | full, from the item, from a tag scan, and from a foreign passport's "Add to my gear" | log fill (twin fills write the partner), edit and delete fills, track O2 clean, link a tag (which can release it from other items), pack for a trip; the gear passport also hosts the item's service clocks and location cards |

- **Saving.** Most writers write every column of a record built fresh from
  the form. Some are one transaction already: `DocumentRepository.save`,
  `EquipmentRepository.updateEquipment` (with attributes, and tags through
  `updateEquipmentWithTags`), `EquipmentSetRepository.updateSet`,
  `TripRepository.updateTrip` (with the parent check and slot-link clearing),
  `replaceBuddyCertifications`. Children and sharing are separate writes
  after the record (trip sharing and liveaboard details, buddy certifications,
  course certifications, set geofences and the dive rewrite).
  `updateCertification` writes the card images and refreshes the course's
  representative certification itself, but outside a transaction.
- **History.** Every type is a change log root, and every page's menu has a
  History item except the passports. Children logged under each root:
  equipment (attributes, components, location moves, observations, ownership
  events, shares, tags, service records and schedules, cylinder fills,
  pairings by the first cylinder), equipment sets (items, includes, weight
  presets, cylinder configurations, geofences), trips (checklists with items
  and sections, cylinders with events, packed equipment, hides, itinerary
  days, shares, liveaboard details), dive centres (gear notes),
  certifications (currency events and preferences), courses (requirements,
  requirement dives). Buddies, documents (pages and tags aside), species and
  both track tables have none. `equipment_findings` is excluded today.

## Approaches

The approach is the one phases 1 and 2 chose, so the question was only how to
cut phase 3.

1. **One note for all of phase 3, split into plans.** One design covers every
   type, so the shared generalisations (satellite pages, tabbed pages,
   sharing) are designed once, and the plans take the types in order.
2. **A note per group of types** (plain records, tracks, trips, equipment),
   each written when its turn comes. Smaller notes, but the shared pieces
   would be designed piecemeal, by whichever group needs them first.
3. **A note per type.** About ten short notes; the same drawback, more so.

**Picked: 1**, by Eric.

## Decisions

Made by Eric, in the order they were made. Three were made earlier for the
whole program and apply here: everything done on a record's page is held in
the sitting; a duplicate opens as a prefilled new record; merge gets a page of
its own.

1. One design note for all of phase 3, split into plans, over one note per
   group or per type.
2. Species joins phase 3 with the full lock (its tag photos and add photos
   become held), over leaving it in phase 4 with only the shared bar.
3. A buddy's Lend gear and All returned are held in the buddy's sitting and
   written with it, over a whole-record operation or leaving them outside the
   buddy's lock.
4. The passport pages get a lock of their own on the gear item's sitting:
   opened alone (from a tag scan) they open locked, and their own Unlock,
   Cancel and Save hold and write the item's changes as one History entry, so
   logging a fill after a scan is scan, unlock, log fill, Save; opened from an
   unlocked item page they join its sitting. Over making them read only.
5. A trip's Scan for dives, Scan photos and Lightroom are held in the trip's
   sitting, over whole-record operations.
6. One build switch for all of phase 3, turned on when the last type is done,
   over a switch per type or per group.
7. A value the form edits but no page shows is shown on its card when it is
   set, over editing it only.
8. The starter sets listed under "A new record", over essential cards only or
   every card open.
9. The trip's cylinder board gets a lock of its own on the trip's sitting, as
   the passports do, over following the trip page's lock only.

## Design: what is reused unchanged

From `lib/shared/widgets/record_editing/` and the change log services, as
phases 1 and 2 ship them:

- `EditSession<T>`, `EditField<T, V>`, `SittingList<T, E>` (with `sameIdSets`
  and `wroteChange` from phase 2 plan 3), `RecordEditController<T>`.
- `EditCard<T>`, `RecordCardFrame<T>`, `RecordCardHeader`, `RecordCardFade`,
  `RecordCardForm`, `RecordNumberRow`, `FieldTextBinding`, `AddStrip`,
  `AddStripLayout`, `RecordEditBar`, `RecordEditPaneHeader`.
- `RecordEditHost<W, T>`: the lock, the bar swap, the strip, the leave guard,
  the pane, `saveAndReport` and `followStored`.
- `RecordEditLeaveGuard`, `RecordSittingExitBlocker`,
  `confirmLeaveRecordSitting`, the operation gate, `RecordEditShortcuts`.
- `writeRecordSitting` and `runRecordSitting`
  (`lib/core/services/change_log/record_sitting_writer.dart`), with sync told
  once after the commit (phase 2 plan 3).
- `RecordSittingRefusal` (phase 2 plan 3): a held write the database refuses
  fails the whole Save with a message naming it.
- `RecordEditLabel`: a sitting is labelled `record_edit:<table>:<id>:<cards>`,
  and the change log settler pins it to the record it names whatever the
  table, so writes to other records in the same sitting appear in that
  record's History entry.
- The generic attachment sittings phase 2 plan 3 makes:
  `record_media_sitting.dart`, `record_document_links_sitting.dart` and
  `DocumentsSection<T>`.
- `AppExitGuard` and `MasterDetailScaffold`, which already ask before a
  selection or a create leaves unsaved work.

## Design: what is generalised

Each is a shared piece phase 3 needs and phases 1 and 2 did not. Each is
built in shared code once, by the first phase 3 plan that needs it. Phase 2's
plans 6 and 7 may still change `lib/shared/widgets/record_editing/` while
phase 3 builds (see "Delivery"), so each phase 3 plan brings main in before
each task and adapts to what they renamed.

- **Pages with no section list.** `RecordEditHost` takes its strip entries
  from the page, so it already works without a section enum. What each type
  adds is a small card-id list of its own (an enum per type, names the
  builder's), used for the strip order, the starter set and History's card
  names. The strip offers only empty cards: there is nothing hidden.
- **History's card names.** `change_log_labels.dart` gains a lookup for each
  phase 3 table, as phase 2 added `dive_sites`. Each type also gets a record
  title for its entries where `changeLogRecordTitle` has none.
- **Satellite pages.** The passports and the cylinder board (decisions 4 and
  9) are pages of the same record, with a subset of its cards, that can host
  a sitting of their own. A shared satellite host (on `RecordEditHost`) gives
  them: open locked, wherever they are opened from (a tag scan included);
  Unlock starts a sitting on the parent record with the parent's save
  service; Save writes it as one History entry on the parent.
  When the page is pushed from the parent page during a sitting, it receives
  that sitting (through `RecordEditScope`, as phase 1's fullscreen profile
  does) and shows Done in place of its own Cancel and Save; the parent's Save
  writes it. The parent page does not end its sitting while a satellite is
  on top.
- **Tabbed pages.** A trip's sitting spans its six tabs. The strip, pinned
  under the bar, offers the empty cards of the tab in view; switching tab
  keeps the sitting and every open card. The host gains a way for the page to
  say which cards are on the current tab (the builder decides the shape).
- **Sharing in a sitting.** Phase 2's `site_sharing_sitting.dart` is for
  sites. Trips (`itemSharesRepository.setSharing`) and gear items
  (`equipmentShareRepository.setShares`) need the same held list with a
  refusal for a profile that may not share. It becomes one shared sharing
  sitting over a small adapter per repository.
- **Writes to other records.** Several held writes change records other than
  the sitting's own (listed per type below). They run inside the sitting's
  transaction through `alsoWrite`, as the dive's site altitude does, and are
  in its History entry through the label. Nothing new is needed in the writer;
  each type's save service lists them.
- **The documents card's add.** In a sitting today, Add opens
  `DocumentEditPage(ownerFixed:, onSaved:)`, which creates the document at
  once, filed as Personal; only its link to the record is held, so a Cancel
  leaves a Personal document behind, as any record created from a picker
  survives Cancel. When the document form goes (see "Documents"), Add opens
  the document's new-record page with the owner shown fixed; its Save creates
  the document as Personal and returns it, and the link stays held in the
  owner's sitting. Behaviour does not change. This is a change to
  `DocumentsSection<T>`, after phase 2 plan 3.
- **The build switch.** One `kUnlockRecordEditing` (name the builder's), off
  by default and turned on with a `--dart-define`, read by every phase 3 page,
  route and opener (decision 6).

## Design: rules every phase 3 type follows

- **Cards.** A field is edited on the card that shows it; a field no card
  shows is edited on the card it belongs with, and that card gains a row for
  it when it is set (decision 7, listed under "Values shown nowhere today").
  Cards whose content is calculated fade and say "Calculated"; a card that
  shows only what was imported says "Imported".
- **The header block** is the part at the top of each page (avatar or
  logo, name, status chips). Its editor holds the record's name and the
  values its chips show, unless a card is named below.
- **Mixed cards.** Rows calculated inside an editable card (counts, due
  dates, "owned for") stay read only inside its open editor, as on the dive's
  Details card.
- **Units** in every editor follow the active diver's unit settings, as the
  forms do.
- **Validation** moves from each form into its cards' checks, keeping today's
  rules (listed per type). Save checks every card, open or closed.
- **Records created from a picker** during a sitting (a buddy, a dive centre,
  a site, a certification level, a location, a tag, a service kind, a
  document from the Documents card) are created at once and survive Cancel,
  as on dives. A link that pushes another record's new-record page (the
  passport Pack card's New trip, a part's Add part, the board's Log dive)
  leaves the sitting as it is; that record is the other page's.
- **Writes on viewing stay outside the rule**: the trip day weather backfill
  (`trip_day_weather`), and the passport id that `ensurePassportId` derives
  from the item's id when a passport opens.
- **Hosts and routes.** On each type: `/<type>/:id/edit` redirects to
  `/<type>/:id?mode=edit`, which opens the page unlocked; the list pane's
  `editBuilder` goes, in master-detail and in table mode (`TableModeLayout`,
  which buddies, centres, certifications, courses, trips and gear each have),
  and `&mode=edit` opens the pane unlocked; `/<type>/new`
  and the pane's `?mode=new` open the new-record page; each route gets
  `onExit: confirmLeaveRecordSitting`. Edit buttons on the pages and panes
  go. Links that open a form today at a section open the page unlocked with
  that card open (a trip's `section=planning`, `section=notes` and its
  `noteDay`).
- **Whole-record operations** (delete, transfer, split, and the others named
  per type) need the unlock, keep their confirmations, act at once, and are
  disabled while the sitting has unsaved changes. Menu items that change
  nothing (History, Open in Connections, export, share) and items that
  create another record (clone, duplicate) work while locked.
- **One-tap toggles on list rows** (the buddy favourite) show state only.

## Design: buddies

| Card | Its editor holds |
| --- | --- |
| Header block | Photo (including import from contacts), name (required), favourite |
| Contact | Email (format check), phone, social handle, country (its code derived as today), linked profile with its suggestion |
| Certifications | The buddy's certifications: add, edit, remove, each in a dialog holding a certification's fields (today's staging mode) |
| Statistics | The "exclude from rankings" switch; the statistics read only |
| Gear | Lend gear, All returned, Returned on one row (decision 3) |
| Notes | Notes |
| Documents | Add a new document, remove (unlink), as on a dive |

- Calculated: Shared dives, Photos (photos tagged with the buddy). Imported:
  Card details (from a received buddy card; the form never edited them).
- The Gear card builds nothing when nothing is lent; it is in the strip, so
  lending stays reachable once the menu's Lend item goes.
- **Rules.** Linking a profile is refused for the diver themselves and for a
  profile linked to another buddy
  (`BuddyProfileLinkRepository.assertLinkAllowed`, which throws
  `BuddyLinkRefused`; the form calls it before writing). The Contact card
  checks as the diver picks; the check runs again inside the Save, where a
  refusal becomes a `RecordSittingRefusal` with the same message as today
  (naming the other buddy when the profile is taken), so the Save fails
  whole.
- **Held writes.** The buddy row; the certifications through
  `replaceBuddyCertifications` (already one diffing transaction); the lends
  and returns (equipment location moves, and the status change the move flow
  offers, on the items lent), written to those items with the sitting.
- **Whole-record operations.** Delete. Share dives (a UDDF export) changes
  nothing and works locked. The menu's Lend item goes; lending is on the Gear
  card.
- **Merge** keeps a form of its own. Today it is `BuddyEditPage(mergeBuddies:)`
  inside `BuddyMergePage`. Before the form is deleted, merge moves to a page
  holding only what merge uses (the field cycling of
  `BuddyMergeFormController`), as site merge does in phase 2. Its behaviour
  does not change.

## Design: dive centres

| Card | Its editor holds |
| --- | --- |
| Header block | Logo, name (required), rating, street, city, state, postal code, country, affiliations, permanently closed |
| Map | Latitude and longitude, use my location, pick from map, look up from the address |
| Contact | Phone, email (format check), website, fill hours |
| Notes | Notes |
| Documents | Add a new document, remove (unlink) |
| Rental gear | Add, edit, delete gear notes (`dive_center_gear_notes`) |

- Calculated: Dives. `GearHereSection` (the diver's gear kept at the centre)
  reads only; it is changed by moving gear, on the gear item.
- The Map card is left out without coordinates today; it is in the strip, so
  coordinates can be added.
- **Rules.** Coordinates in range. Fill hours both or neither, closing
  strictly after opening (`fillHoursProblem`). An address edited while there
  are no coordinates looks them up after the field is left, as the form does:
  a change of the Map card, tracked, so Save waits for it.
- **Whole-record operations.** Delete (as today, it also clears the links to
  the centre from dives, trip cylinder events and locations, removes the gear
  notes, and deletes the centre's documents).

## Design: certifications

| Card | Its editor holds |
| --- | --- |
| Header block | Nothing of its own (its title, agency and badge come from Details) |
| Details | Credentials (agency and level, add recognition, remove), custom title, card number |
| Dates | Issue date, expiry date |
| Currency | Log a refresher or renewal, delete an event, the interval, mapping and mute preferences |
| Instructor | Instructor picker, name, number |
| Card photos | Front and back |
| Documents | Add a new document, remove (unlink); cards excluded, as today |
| Notes | Notes |

- Calculated: the status banner. Training course reads only: it is set from
  the course (see "Courses").
- The Currency card is absent when no currency rule applies to the
  certification; it is offered in the strip only when one does.
- **Rules**, as the form's: a title or a level is required; changing an
  agency drops a level that is not the agency's; removing the first
  credential promotes the next; picking an instructor fills the name and
  number.
- **Held writes.** The certification row (whose update also refreshes the
  linked course's representative certification); the currency events and
  preferences (a preference set on a collapsed rule group writes every
  certification in the group, as today); the card photos through
  `DocumentRepository.saveCardImages`. All inside the sitting's transaction;
  today `updateCertification` makes these writes with none.
- **Whole-record operations.** Delete. The wallet route reads only.
- **The staging mode** goes with the form: a buddy's certification is edited
  in the buddy's Certifications card dialog, which holds the same fields.

## Design: courses

| Card | Its editor holds |
| --- | --- |
| Status (the header block) | Name (required), mark completed (sets the completion date) |
| Details | Agency, start date, completed and completion date, location |
| Instructor | Instructor picker, name, number |
| Earned certifications | Which certifications the course earned |
| Requirements | Add, apply a template, edit, delete, tick a checklist item, credit a dive (picker or suggestion), uncredit |
| Notes | Notes |
| Documents | Add a new document, remove (unlink) |

- Calculated: Training dives (set from the dive's side, `dive_courses`). The
  Status card's state and duration, and the Requirements card's progress,
  read only.
- **Rules**, as the form's: switching completed on fills today's date; a start
  after the completion date pulls the completion date with it.
- **Held writes.** The course row (whose update also rewrites `course_id` on
  the course's dives, as today); the requirements and their credited dives;
  the earned certifications through `setCourseCertifications`, which can move
  a certification off another course. The writes to dives and certifications
  are written with the sitting. The Mark completed button goes from the
  bottom of the page to the Status card's editor.
- **Whole-record operations.** Delete. Export training log works locked.
- Applying a template twice appends twice, as today; that is not changed here.

## Design: documents

A document is a record of its own, attached to a dive, site, trip, buddy,
centre, certification, course or gear item, or to none.

| Card | Its editor holds |
| --- | --- |
| Pages | Add, reorder, remove pages; front and back slots for insurance and cards (`DocumentPageStrip`) |
| Details | Owner, type, title, issuer, reference number, phones and primary (insurance), issue and expiry dates, reminder lead, tags, notes |

- The title is shown in the bar today; it is edited on Details.
- Calculated: the expiry status.
- **Rules**, as the form's: a card document's owner and type are locked and
  it has no title, expiry or reminder; only insurance keeps phones and
  primary; a new insurance document is primary when the diver has no primary
  insurance; a reminder lead equal to the default is stored as none; tags are
  written only once they have loaded.
- **Saving.** `DocumentRepository.save` already writes the row, pages and tags
  in one transaction; the save service runs it inside the sitting writer.
- **Whole-record operations.** Delete.
- **The add from another record's Documents card** opens this page as a new
  record with the owner shown fixed; its Save creates the document as
  Personal, and the link to the owner is held in that record's sitting, as
  today (see "What is generalised").

## Design: species

| Card | Its editor holds |
| --- | --- |
| Header block | Common name (required) with the online lookup, scientific name, category, taxonomy class |
| Description | Description |
| Photos | Tag photos, add photos |

- Calculated: Statistics, Where seen, Sightings.
- **Rules.** The lookup fills the names, taxonomy and category, as the form's
  does, each a change of the header block.
- **Held writes.** The species row; photo tags (`media_species` rows on the
  photos) and added photos, written with the sitting.
- **Whole-record operations.** Delete joins the page's menu where the species
  manage page allows it today. Suggest for catalog (custom species only)
  sends a suggestion and works locked.
- A built-in species shows its translated name and description while the
  stored text equals the catalogue's (`species_display.dart`); the form
  edits the stored English text, and so do the editors. Nothing changes there.

## Design: GPS tracks and underwater tracks

Neither has a form today. Both are full pages (no list pane).

**GPS track**

| Card | Its editor holds |
| --- | --- |
| Header block | Name (the column exists; the bar shows a fixed "GPS track" and nothing edits it today) |
| Trim | Start and end of the trim, reset trim |

- Calculated: the statistics header, the dives on the track (matched by
  time, no stored link), the map.
- The trim panel already holds its bounds until Apply; Apply becomes a change
  of the sitting, written at Save.
- **Whole-record operations.** Split (it creates two tracks and deletes this
  one), delete (today only on the Tracks list; the page's menu gains it).
  GPX and KML share and save work locked.

**Underwater track**

| Card | Its editor holds |
| --- | --- |
| Header block | Name |
| Dive | Choose, change or unlink the dive |
| Site | Change site, with the anchor following as today (the site picker can create a site) |
| Device | Change or clear the device |
| Correction | Opens the align page |

- Calculated: statistics, recorder. The map reads only. Which route is
  primary for a dive is set from the dive's page, not here.
- **Held writes to other parts of the log**, as the repository does them
  today: linking copies the dive's owner and, when the route has none, its
  site and anchor; unlinking promotes a sibling route on that dive to
  primary.
- **The align page** holds its correction until Save, except that its 3D
  button saves the correction before opening the view. It follows the
  track's lock as the dive's fullscreen profile does: from a locked page it
  reads only and its 3D button saves nothing; during a sitting its Save
  becomes Done and the correction is a held change of the track's sitting,
  and the 3D views show the held correction without writing it.
- **Whole-record operations.** Update from file (ENC tracks only; it replaces
  the recorded points and the source file, keeping link, site, anchor, name,
  device and correction), delete (which also promotes a sibling route).
  Export CSV (ENC only) and the 3D views work locked.

## Design: trips

A trip's page has six fixed tabs, and the Overview changes shape on the
trip's first day (prepare before, story from then on). One sitting spans every
tab (see "Tabbed pages").

| Card | Tab | Its editor holds |
| --- | --- | --- |
| Header block (the page header with the trip's name and dates, and the prepare page's hero) | all | Name (required), trip type, start and end dates, return flight, part of trip, location, resort, the legacy liveaboard name, sharing |
| Plan | Overview | Dives per day, divers sharing cylinders, expected dives, expected runtime |
| Vessel | Overview | Liveaboard details: vessel name (required), operator, vessel type, cabin, capacity, embark, disembark |
| Notes | Overview | Notes, including the day passages |
| Day plan (the story's day page) | Overview | That day's note passage (the same notes field, at its heading). The itinerary notes and planned dives it also shows are edited on Itinerary days |
| Documents | Overview | Add a new document, remove (unlink) |
| Itinerary days | Itinerary | Generate or fill missing days; each day's type, port, notes, planned dives |
| Packed gear | Gear | Add (items, cylinders, a set's bundle, which can also add checklist items), unpack, put on board |
| Checklists | Checklist | Create, apply or replace a template, clear, rename, reorder, delete; items and sections; ticks |
| Dives | Dives | Scan for dives (decision 5); a dive the scan added in this sitting can be taken out before Save |
| Photos | Photos | Scan photos, and Lightroom while `lightroomUiEnabled` is on (decision 5) |

- Calculated: the hero's flags, duration and countdown, the summary rows
  (checklist, gear, itinerary), the totals, the day picker, the rhythm and
  conditions, weather, the cylinder summary, the flight countdown, the fill
  forecast, service alerts and scrubber margins.
- **The scans** are menu items today, and the Photos tab offers none. They
  move to the Dives and Photos cards' editors, and the menu items go. The
  gallery page (`/trips/:id/gallery`) has a Scan of its own; it follows the
  trip's lock as the dive's fullscreen profile does: from a locked trip it
  offers no scan, and during a sitting its scan is held in that sitting.
- **The Vessel card** shows on the prepare page too, for a liveaboard (today
  only on the story's trip page). The Plan card is on the prepare page only;
  from the trip's first day it is offered in the strip.
- **Day notes** are passages of the notes field under a heading for the day
  (`trip_day_notes.dart`). The day page's "Add day note" places the heading as
  the form does (`placeDayNoteIn`, `helpers/trip_day_note_editing.dart`), and
  the passage is edited where it shows; an added heading left empty is
  dropped at Save, as today.
- **The cylinder board** is a satellite page (decision 9): add cylinders,
  fill one or several (copying fills to passports), adjust, edit, delete,
  reorder, the ledger's delete, and the forecast strip's planned dives
  (which write the itinerary days). "Log dive" pushes the new-dive page and
  the unlinked-tanks sheet opens a dive's page; both are other records' pages.
  The record view's CSV export works locked.
- **Rules**, as the form's: the end date picker starts at the start date, and
  a new start after the end pulls the end with it; a trip that is one day
  long and of the day-trip type keeps its end on its start; the vessel name is
  required for a liveaboard; the integer fields (capacity included) take any
  integer and Save stores zero or less as empty; divers sharing defaults to
  one; the parent trip obeys `canChooseAsParent` and `writableParentId`;
  changing the parent clears foreign cylinder slot links on the trip's dives.
  Changing the type away from liveaboard removes the liveaboard details at
  Save.
- **At Save, as the form does:** when the dates changed, the candidate dives
  are found and the assignment dialog is asked before the transaction; the
  chosen dives join the sitting's writes. After the commit, best effort as
  today, plan days left outside the dates are removed
  (`deleteBarePlanDaysOutside`, which `updateTrip` runs on every update).
- **Held writes.** The trip row; sharing; liveaboard details; itinerary days;
  packed equipment and cylinders with their events; checklists, items and
  sections; and, to other records: the dives' trip link and cylinder slot
  links, the photos linked by a scan, the fills copied to passports.
- **Whole-record operations.** Delete for the owner; Remove from profile and
  Unhide otherwise. Export (a stub today) and Open in Connections work locked.
- **Creating another record works locked**: starting a pre-dive session, and
  a checklist's "Save as template".

## Design: gear items

| Card | Its editor holds |
| --- | --- |
| Header block | Name (required), type (locked when a device row names the item), tags, mark purchased (wanted gear) |
| Dive computer | The computer's favourite, clock sync override and auto-download; merge and re-parse all are whole-record operations (below) |
| Details | Status, parent (where the type takes one), brand, model, serial, spec attributes, colour and figure position, custom fields, purchase date, price and currency, purchase attributes, sharing |
| Transmitter | Opens the transmitter page (a different record); "Apply to existing dives" is a whole-record operation |
| Location | Move (with the parts, and the status the move offers), edit or delete a past move |
| Twin set | Pair, replace the partner, end, delete a pairing (tanks) |
| Service clocks | Add, override, pause, resume, remove a clock; log a service; custom reminder |
| Condition findings | Dismiss and restore a finding |
| Parts | Replace a part (whole-record operation, below); Add part pushes a new item's page |
| Photos | Import, choose the cover, unlink |
| Observations | Add, edit, delete, with their photos |
| Components | Add, replace, remove, change role, reorder |
| Legacy files | Unlink |
| Service history | Add, edit, delete a service record |
| Notes | Notes |
| Documents | Add a new document, remove (unlink) |

- Status always shows on Details; the header's chip (shown for inactive and
  wanted gear) reads from it.
- Calculated: the service banner, the dive, time and trip counts and "owned
  for" on Details, Exposure, Condition trend, History (with several divers),
  the passport entry cards. The dive computer's Connect (a download, a
  deliberate mode) and the unit configurations (cylinder configurations, a
  phase 4 editor) work locked.
- **Rules**, as the form's: changing the type re-checks the parent; only the
  type's catalogue attributes are kept; retired, sold and wanted make the item
  inactive; custom fields are de-duplicated by key; the inspection and hydro
  dates move service clocks (`applyBaselines`); the name and notes are
  mirrored to the dive computer row, and the name to the transmitters'
  labels.
- **Asked as the card actions ask today:** adding, replacing or removing a
  component asks whether logged dives change too ("also past"); the answer is
  taken when the change is made and applied at Save. A serial that changed
  triggers the transmitter rescan after the commit, best effort, as today.
- **Held writes.** The item row, attributes and tags (already one
  transaction); sharing; location moves; pairings; clocks, service records,
  findings dismissed, observations, components, photos and cover, documents;
  and, to other records: the dive computer's settings, the parts and lent
  items moved with it, the status set on several items by the move flow, the
  partner cylinder's pairing (and a clashing pairing a replace ends), the
  dives rewritten by a component change. Logging the dismissal of a finding
  needs `equipment_findings` in the change log (today excluded), as phase 1
  did for dive safety findings.
- **Whole-record operations.** Delete and Transfer (owner only); Replace a
  part (it retires the old part and creates a new one); the transmitter's
  "Apply to existing dives" (it rewrites dives); the dive computer's merge
  and re-parse all (as a dive's re-parse is). Clone opens a prefilled new item
  (see "A new record").
- **The transmitter page** is a phase 4 editor of a different record
  (transmitter keys). After a key saves, it copies the key's serial onto the
  item when the item has none, and never overwrites one. That one write
  stays as it is (see "Calls made in this note").

**Passports** (decision 4). The cylinder passport and the gear passport are
satellite pages of the item. Held: log a fill (a twin fill also writes the
partner cylinder's fill, with the sitting), edit and delete a fill, track O2
clean, link an existing tag (which re-keys fills and can release the tag
from retired or sold items, writes to those items, with the sitting), pack
and unpack for a trip (writes the trip's packed equipment, with the sitting;
its New trip pushes the new-trip page). The gear passport also shows the
item's Service clocks and Location cards, held as on the item page. Not
changes: writing the physical NFC tag and printing a label. A tag scan of
the diver's own tank imports the fill the tag carries before the page opens,
as today: that is an import, outside the rule. A foreign passport's "Add to
my gear" creates the item, then opens its passport, locked.

## Design: equipment sets

| Card | Its editor holds |
| --- | --- |
| Header block | Name (required), description, default, auto-apply on computer import |
| Figure | Show figure |
| Members | Items, grouped as today |
| Bundle | Included sets, weight presets, cylinder configurations |
| Geofences | Geofences |

- Calculated: the item count.
- Show figure is a stored, synced column on the set, so it is a change, held
  in the Figure card; the menu's Show and Hide figure go.
- **At Save**, on an existing set only (never on create or clone), as today:
  when the set's effective gear changed (its members, counting included
  sets) and logged dives carry it or a set that includes it, "Update past
  dives?" is asked before the transaction. Cancel returns to the sitting.
  Planned dives are always rewritten; the answer decides the logged ones
  ("Also update" rewrites them, "From now on" unlinks the set from them and
  keeps their gear). Those writes go with the sitting.
- **Held writes.** The set row, items, includes and bundle lists (one
  transaction today); default (which demotes the other sets); geofences; the
  dive rewrites and unlinks.
- **Whole-record operations.** Delete. Set as default leaves the menu: it is
  the header block's Default switch. Clone opens a prefilled new set.
- **Hosts.** The sets pane already shows the full set page; it gains the
  lock, `&mode=edit` and `?mode=new` like the item pane.

## Design: values shown nowhere today

Decision 7. Each gains a row, on the card that edits it, shown only when set:

| Type | Value | Row on |
| --- | --- | --- |
| Trip | Location, resort (today on list rows only) | Header block |
| Trip | Trip type other than liveaboard | Header block |
| Trip | Legacy liveaboard name | Header block |
| Trip | Sharing ("Shared with ...", owner only) | Header block |
| Trip | Expected dives, expected runtime (today only inside the gear alert's scrubber details) | Plan |
| Dive centre | Fill hours | Contact |
| Document | Reminder lead | Details |
| Gear item | Custom reminder | Service clocks |
| Equipment set | Auto-apply on computer import | Header block |
| GPS track | Name (the bar shows a fixed title) | Header block |
| Course | Instructor number or linked buddy, when there is no instructor name (the card shows only with a name today) | Instructor |
| Buddy | Excluded from rankings (shown today as a note) | Statistics, unchanged |

A course's name is shown only in the bar today; it is edited on the Status
card.

## Design: a new record

Every type except the tracks (created only by import) and the passports opens
a new record on its own page, as phase 2's new site does: a seed record in
memory with a fresh id, unlocked, `creating`.

| Type | Essential card | Starter set (decision 8) |
| --- | --- | --- |
| Buddy | Header block | Contact, Notes |
| Dive centre | Header block | Contact, Map |
| Certification | Details | Dates, Card photos |
| Course | Status | Details, Instructor |
| Document | Details | Pages |
| Species | Header block | Description |
| Trip | Header block | Notes, and Vessel for a liveaboard |
| Gear item | Header block | Details, Location |
| Equipment set | Header block | Members |

- **Seeds are changes**, as on a new site: a name or contact from the
  picker or from the phone's contacts, a trip from selected dives (its dates
  and those dives), a part's parent, a type (and a serial) from the dive
  computer and transmitter lists' "add by hand" and the transmitter setup.
  Each shows its dot, Save is enabled at once, and Cancel asks. A document
  added from another record's Documents card shows that owner fixed, but is
  created as Personal (see "Documents").
- **Defaults are not seeds**: what settings give every new record (sharing by
  default, a new insurance document as primary) is the starting record.
- **Clone and duplicate** (gear item, set) open the new-record page prefilled
  from the original, the prefills being changes. A gear item's clone extras
  (service clocks without a baseline, set memberships, documents and photos
  as new links) are prefills too, held until Save, where today they are
  copied after it, best effort.
- **On Save**, what the form does after creating runs inside the sitting: a
  gear item's first location; a new liveaboard trip's generated itinerary; a
  trip from selected dives assigns them; a new trip with dates asks the
  candidate dives question. A page pushed by a picker pops with the new id, as
  the forms do.

## Design: what happens to the forms

- Merge (buddies) moves to its own page first.
- When every type has its cards, its new-record page and its satellites, the
  switch-over plan turns the phase 3 switch on, removes the Edit buttons,
  makes the old addresses open the pages unlocked, and deletes the nine
  forms, the section widgets only they used, and their tests.
- Each form's test file moves to the card that owns the behaviour it covers;
  none is dropped without a replacement.

## Calls made in this note

Eric has not explicitly confirmed these. Correct any of them:

- Which card each field is edited on (the tables above), including the
  buddy's rankings switch on Statistics, fill hours on Contact, the course's
  name and Mark completed on Status, and sharing on Details for a gear item
  but on the header block for a trip.
- Buddy card details are "Imported" and not editable.
- The underwater track's align page follows the track's lock like the
  fullscreen profile, with no lock of its own, unlike the passports and the
  board.
- GPS trim is a held change; split and update from file are whole-record
  operations; the GPS page's menu gains Delete.
- Replace a part, the transmitter's "Apply to existing dives", and the dive
  computer's merge and re-parse all are whole-record operations.
- The dive computer's favourite, clock sync override and auto-download, shown
  on the item page, go behind the item's unlock and are written with its
  sitting (they are the dive computer record's own values). Confirmed by
  Eric on 2026-11-19, with phase 3 plan 1.
- The transmitter page, a phase 4 editor, keeps copying a key's serial onto
  an item that has none. It is the one write to an item made outside the
  item's sitting; it fills an empty value and never overwrites one.
- The trip gallery's Scan follows the trip's lock, like the fullscreen
  profile; the trip's scans move from the menu to the Dives and Photos cards.
- Set as default and Show figure are held changes on the set, not menu
  actions.
- A card left out when empty is offered in the strip, including the buddy's
  Gear card; the certification's Currency card only when a rule applies.
- A tag scan's fill import, the passport id minted on open and the trip day
  weather stay outside the rule.
- The species page gains Delete; the GPS page gains Delete.
- Clone extras become prefills, written with the new item, not after it.
- A trip's dates changed in a sitting ask the candidate dives question at
  Save.
- A trip's sitting spans its tabs; the strip shows the tab in view.
- The vessel card shows on the prepare page for a liveaboard.
- Logging a finding's dismissal adds `equipment_findings` to the change log.
- The phase 3 plans run in parallel with phase 2's plans 6 and 7, by Eric's
  decision of 2026-11-19 (this replaced "start after phase 2's switch-over").

## Left to the builder

- Names and file layout of the satellite host, the tab support and the shared
  sharing sitting.
- The order in which cards move from each form to card editors.
- How the trip's tabs tell the host which cards they hold.
- Wording of new strings. Every new string goes into all locales.
- If an action listed as held turns out to be impossible to hold, stop and
  raise it. Do not make it immediate silently.

## Testing

- The shared pieces made for phase 3 (satellite host, tabs, sharing sitting)
  are tested alone with a small fake record type, as `RecordEditHost` was.
- Each type: a locked page makes no repository write on any tap, in every
  host and on each satellite page.
- Each type: a sitting that changes several cards is one change log
  operation, and reverting it restores every value, including its writes to
  other records (a lent item's place, a dive's trip link, a partner
  cylinder's fill, a rewritten dive).
- Each type: a field census test, as for dives and sites: a value changed in
  storage during a sitting on a card the diver did not touch survives Save.
- A held write refused at Save (a profile link to another buddy, sharing
  refused) writes nothing and leaves the page unlocked.
- A Save that fails partway writes nothing, including the writes to other
  records.
- Satellite pages: opened alone, Save writes one History entry on the parent;
  pushed during the parent's sitting, their changes are saved or cancelled
  with it.
- A new record and a clone per type: seeds and prefills are changes, Cancel
  asks, Save creates and returns the id to the picker.
- Merge behaves as before from its own page.
- Each card editor has its own widget tests; each moved form test keeps its
  case.

## Delivery

Phase 3 lands as a series of pull requests, each referring to #4527, behind
one switch until the last (decision 6). By Eric's decision of 2026-11-19
("Build in parallel"), it runs in parallel with phase 2's plans 6 and 7
rather than after phase 2's switch-over. Those two plans may still change
`lib/shared/widgets/record_editing/`, the sitting writer and
`DocumentsSection<T>`, so every phase 3 plan merges origin/main before each
task and adapts to any names they renamed, and a phase 3 plan that needs a
piece phase 2 has not finished takes it after that phase 2 plan has merged. Plans are written one at a time,
each against the names the previous one shipped and what main holds then. A
likely order, for the plans to refine:

1. Shared pieces: the satellite host, tab support, the shared sharing sitting,
   History card names for every phase 3 table; the switch.
2. Documents and species (no satellites, few collections), proving the host on
   a page with no section list.
3. Buddies, dive centres, certifications (contact cards, rental notes,
   currency, the buddy's certifications and gear), and buddy merge to its own
   page.
4. Courses (requirements, credited dives, earned certifications).
5. GPS and underwater tracks, with the align page.
6. Gear items: plain cards and collections.
7. Gear items: the passports as satellites, twin sets, components, findings in
   the change log.
8. Equipment sets.
9. Trips: header, plan, vessel, notes and day notes, documents, itinerary.
10. Trips: gear, checklists, scans, and the cylinder board as a satellite.
11. New records and clones for every type.
12. Switch-over: the switch on, the old addresses redirected, the forms
    deleted.

One switch over twelve plans means the switch-over deletes nine forms at
once; each earlier plan keeps its type's form working until then.

No table or column is added. The change log gains `equipment_findings` as a
logged child of `equipment`, a change to its policy and generated triggers,
following phase 1's plan 9 and the existing conventions (tables under
`lib/core/database/tables/`, migrations under
`lib/core/database/migrations/`, nothing new in `database.dart`).

Pull requests that change anything visible carry screenshots. While the pages
are behind the switch, they come from a build with the switch on or from
headless widget-test goldens.
