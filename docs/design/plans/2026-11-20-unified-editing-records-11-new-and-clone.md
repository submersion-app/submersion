# Unified Editing, Phase 3, Plan 11: New Records and Clones for Every Type Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A new document, species, buddy, dive centre, certification, course, gear item, equipment set and trip, and a clone of a gear item or a set, open on the record's own page, already unlocked, behind `kUnlockRecordEditing` (issue #4527, phase 3). The essential card and the starter set are laid out open; seeds and prefills are changes; Save creates the record and everything the sitting holds in one transaction and one History entry; Cancel leaves without creating anything, asking first once something was entered. With the switch off every opener, route and pane opens the form exactly as today.

**Architecture:** As phase 2's new site (`site_detail_page_creating.dart`, `site_new_sitting.dart`): a new record is a sitting whose stored record is a **seed**, in memory only, with a fresh id and the defaults every new record of its type gets. What only a new record's page does (open on the seed, leave once the sitting ends, Save, Cancel, hand the record on) is type-neutral in the site's code, so it is lifted once into a shared mixin, `RecordCreating<W, T>` on `RecordEditHost`, and a shared writer, `createRecordSitting`. Each type then adds a `create` to its save service, a `<type>_new_sitting.dart` (seed, laid-out cards, prefill), a part file `<type>_detail_page_creating.dart` mixing `RecordCreating` into its page state, and `new<Type>Page` / `new<Type>Pane` / `openNew<Type>` route helpers choosing the page or the form by the switch.

**Tech Stack:** Flutter, Riverpod 3, go_router, drift (test database through `setUpTestDatabase`), `flutter gen-l10n` (no new strings expected).

**Spec:** [docs/design/specs/2026-11-18-unified-editing-phase-3-records-design.md](../specs/2026-11-18-unified-editing-phase-3-records-design.md): "Design: a new record" (the starter sets, decision 8; seeds; defaults; clone; on Save), "Rules every phase 3 type follows" (records created from a picker; hosts and routes), each type's section, and the test line "A new record and a clone per type: seeds and prefills are changes, Cancel asks, Save creates and returns the id to the picker." The models are phase 1's plan 8 (`2026-11-17-unified-editing-8-new-dive.md`, whose thirteen calls Eric confirmed) and phase 2's plan 6 (`2026-11-19-unified-editing-sites-6-new-site.md`). Plans 1 to 10 of phase 3 shipped every page, card id, save service and harness named here.

## Questions for Eric

**Eric chose every recommended answer, and confirmed every call, on 2026-11-20** ("Yes, as recommended"), and asked for the plan to be built here, natively.

Each with the recommended answer first. The plan is written on the recommended answers; a different answer changes the tasks named.

1. **Four pull requests, not one.** Nine types, two clones and about forty openers are too much for one review. Recommended: **A** the shared pieces, documents and species (Tasks 1 to 6); **B** buddies, dive centres, certifications, courses (Tasks 7 to 12); **C** gear items and equipment sets, with both clones (Tasks 13 to 18); **D** trips (Tasks 19 to 23). Each is green and switched off on its own; B, C and D need A merged and are independent of each other, so they can be built one after another or side by side. Other ways: one PR for all; or two (A with B, C with D).
2. **One shared creating piece for the nine types, built in A.** `RecordCreating` and `createRecordSitting` (Tasks 1 and 2), tested alone on a fake record type, as `RecordEditHost` was. The dive's and the site's new-record code stay as they are (both shipped and switched on); moving them onto the shared piece is left for a follow-up. The other way is to copy the site's part file into each of the nine pages, about 3,500 lines.
3. **Where a Save ends, and what the openers get.** Recommended: each new page leaves with what its form returns today, so no picker changes: the Buddy itself for a buddy (`BuddyPicker` and `showBuddyPickSheet` expect one), the new id for every other type, and the id too where the form returns nothing (species, certifications) or navigates away (a course's `context.go('/courses/<id>')`, which today throws away the stack under it, a dive's sitting included). An opener on the type's own list or map that ignores the result today (the phone Add buttons, the empty states, the centre map's Add, the certification wallet's Add, the buddy list's Import from contacts) then opens the new record, locked, as a new site does (phase 2 plan 6, Question 1). Every other opener returns where it was, as today. A clone replaces the page it was opened from with the clone, as both forms do. The other way: every opener as today.
4. **Cancel of a record never saved, every type.** Recommended: as a new dive and a new site: an untouched new record leaves without asking; one with anything entered or seeded asks; either way nothing is written. The species form, the course form and the full-page centre form ask nothing today; their pages will.
5. **Quick adds inside pickers and the device lists.** Recommended: every path that pushes a type's new address today opens the new page through that same address, with no change at the call site: the buddy picker and pick sheet, the centre on a dive's Details card and in bulk edit, the trip on a dive's Details card and in bulk edit, the passport Pack card's New trip, the course picker, the certification picker on a course, the Documents card, the dive computer list's and the transmitter list's Add by hand, and the transmitter setup. Paths that write a record directly stay as they are: a species from the sightings picker and the reef tier, a buddy from the photo people picker, the buddy card exchange, Add to my gear from a foreign passport or gear tag, Save gear as set, the centre's online import, cylinders from tanks. Two pickers drop what they create today (the course picker on a dive, the certification picker on a course): kept as today here, with linking the new record into the opener's sitting as a follow-up issue. The other way for those two: link it in this plan.
6. **A new trip shows the Overview only, in the prepare shape, whatever its dates.** The trip page needs a stored trip in a dozen places (its stats, its story, the gear, cylinder, weather and dive tabs all read by id; two of them throw), and the Overview's shape is chosen from the stored dates. Recommended: while creating, the tab bar is hidden and the Overview is the prepare page (header, Plan, Vessel for a liveaboard, Notes, Documents), as the form offers; the six tabs and the story appear once it is saved. The other way: all six tabs while creating, each made to work on a trip with no row (gear packed, checklists, scans), a much larger Task 21.
7. **A trip from selected dives.** Recommended: its draft's name, dates, location, resort and parent are changes of the header block; the selected dives are assigned at Save inside the same transaction, as the form assigns them, and are shown nowhere before Save, as today; the candidate-dives question is not asked for a draft, and is asked at Save for a new trip without one, as today. The other way (needs Question 6's other answer): the dives shown on the Dives tab as held additions, each one takeable out.
8. **Clone extras become prefills (the note's call).** A gear clone's service clocks (without a baseline), its set memberships and its document copies are held and written with the clone in the one Save; a failure fails the Save, which leaves the page unlocked with everything entered. Today they are copied after the item, best effort, with `equipment_clone_partialCopy`. Set memberships have no card on the gear page: recommended, held and written with the clone and shown nowhere, as today. The other way: a row on Details while creating, naming the sets (one new string).
9. **Which cards a new record offers.** Recommended: the starter set is laid out (the note's table), and the strip offers every other card that edits the record's own values or lists. Left out until the record exists: calculated cards, and cards that act on stored data through the record's id. Per type: a buddy's Gear (lending), Photos and Card details; a centre's Dives and Gear kept here; a certification's Currency (no rule matches a certification not stored) and Training course; a course's Requirements (progress and creditable dives read the stored course) and Training dives; a species' Photos, Statistics, Where seen and Sightings; a gear item's Dive computer, Transmitter, Twin set, Condition findings, Parts, Photos, Observations, Components, Service history, Exposure, Condition trend, History and the passport cards (Legacy files only on a clone that carries document copies); a document's expiry status; nothing on a set. The other way: every card, each made to work without a row.
10. **A document's type and owner from its opener are seeds.** The filtered list's type, the medical page's `medicalClearance`, and the owner a locked page's Documents section passes (`?ownerKind=&ownerId=`) are changes: their card shows its dot, Save is enabled at once, Cancel asks. The other way: part of the starting record, so an untouched one leaves without asking. A document added from an unlocked record's Documents card is created as Personal with its owner shown fixed (the note's call, unchanged).

## Calls made in this plan, for Eric to check

Each follows a call Eric confirmed for a new dive (plan 8) or a new site (phase 2 plan 6), or the phase 3 note.

1. **Save is disabled until something is entered**; a seed or a clone's prefill is an entry.
2. **The bar's title is today's form title**: `documents_edit_newTitle`, `marineLife_speciesEdit_addTitle`, `buddies_title_add`, `diveCenters_title_add`, `certifications_edit_appBar_add`, `courses_title_new`, `trips_edit_appBar_add`, `equipment_edit_appBar_newTitle` and `_cloneTitle`, `equipment_setEdit_appBar_newTitle` and `_cloneTitle`. No new string.
3. **The unlocked bar of a new record has no menu**: every operation acts on a stored record.
4. **Defaults are the starting record, not changes** (the note): a document's reminder lead (30 days) and, for insurance, primary when the diver has no primary insurance; a trip's type (shore), dates (now to seven days on, as the form), sharing by default (`shareByDefaultProvider`) and divers sharing (one); a certification's and a course's agency (PADI) and a course's start (today); a species' category (fish); a gear item's type (regulator), status (active), currency (`defaultCurrencyProvider`) and reminders (7, 14, 30 days); a set's figure (shown). A gear item has no sharing default, so a new one is shared with no one, as today. A default read asynchronously is in the seed before the sitting opens.
5. **Nothing is written before Save**: no row, no child row, no change log operation. A record created from a picker during the sitting (a tag, a location, a buddy) stays created after Cancel, as on every sitting.
6. **One Save is one transaction and one History entry**, labelled `RecordEditLabel.encode(table: <table>, id: <new id>, cardIds: <changed cards>)`, source manual, reading "Added". A Save that fails writes nothing and leaves the page unlocked with every entry; a second Save creates the record once. This replaces the trip form's create retry (`_createdTripId`) and ends the course form's second course after a failed certification link.
7. **What a form writes after creating is written inside the Save** (the note): a buddy's certifications, a course's earned certifications, a gear item's first location and its clone extras, a set's default and geofences, a trip's sharing, liveaboard details, generated itinerary (a new liveaboard whose sitting holds no days) and draft dives. A failure in any fails the Save. Today several are separate or best effort (`equipment_edit_locationFailed`, the set's geofences).
8. **What runs after the commit, best effort, as the forms do:** document reminders re-armed; a gear item's "hidden by the current view" offer (`offerViewRevealingSavedItem`, on a full page too, as the form); list refreshes and provider invalidations.
9. **A clone copies what its form copies**: `equipmentCloneSeed` and `equipmentSetCloneSeed` as they stand, the active diver's own tags and own place only, a set's members only where the diver can see them; a source the diver cannot see opens as not found; a profile switch before Save drops a set clone, as today. A gear clone's clocks merge with the clocks `createEquipment` attaches for the type, by kind, as `copyExtras` does.
10. **A new gear item's type is never locked**; Add part's parent, `?type=` and `?serial=` are seeds, the parent dropped at Save when it may not hold the type, as `_parentIdToSave` does.
11. **Panes**: `?mode=new` opens the new page in the list pane and in table mode wherever a `createBuilder` exists today (buddies, centres, certifications, courses, documents, trips, gear); the sets list keeps opening the full page (it has no create pane); species are full page only. A full page asked for while the pane would show it is not redirected while creating.
12. **The Documents card's Add, during a sitting**, pushes the new document page with the owner shown fixed; its Save creates the document as Personal and returns it, and only the link is held in the owner's sitting, as today.
13. **No rules run after creating**: none of the nine forms runs them today.

## Not in this plan

- Plan 12: the switch on, the old addresses redirected, the forms and their Edit buttons deleted, the moved form tests.
- Creating a record anywhere but its page (Question 5's direct writers, imports, the agent).
- New tracks and passports (created only by import, a scan or adoption).
- Moving the dive's and the site's new-record code onto the shared piece (Question 2).
- The trip cylinder fill sheet's "new centre", which today closes the picker and creates nothing: a bug of its own, for its own issue.

## Global Constraints

- Behind `kUnlockRecordEditing`: with it off, every route, pane builder and opener named here builds or pushes exactly what it does today. Each helper takes `{bool unlockEditing = kUnlockRecordEditing}` so tests choose.
- Calls 5 and 6 hold for every type. The record's repository create runs before the sitting's held writes: they point at it.
- Every value shown or typed follows the active diver's units, as each card already does.
- No file over 800 lines grows except by the lines its task names; `certification_detail_page.dart` (981) and `dive_center_detail_page.dart` (858) are already over. New page code goes in each page's new part file `<type>_detail_page_creating.dart`.
- **Shared files.** Tasks 1 and 2 change `lib/shared/widgets/record_editing/` and `lib/core/services/change_log/record_sitting_writer.dart`, additively only (new members with defaults, nothing renamed). Merge origin/main before each task; if phase 2 or another phase 3 plan has changed them, adapt to their names.
- Existing strings only (call 2). Should one be needed after all (Question 8's other answer), it goes into all 11 ARB files with an `@key` description in `app_en.arb`, then `flutter gen-l10n`.
- Never an em-dash, an en-dash, a double hyphen or a spaced hyphen as prose punctuation; nothing names the coding assistant or its maker.
- Test commands name test FILES by path, never a folder. `dart format` the changed files before each commit.

### The standard tests

Each type's tasks name these by their letter; each is written for that type, with its title, starter cards and leave result.

- **S1** `creates the <type> with its id, as one History entry`: one change log operation, source manual, whose label decodes to the table, the id and the changed cards, holding the insert.
- **S2** `held writes run after the row, in the same entry`: an `alsoWrite` that reads the row back (not null) and writes a child; both in the one operation.
- **S3** `a held write that throws leaves nothing`: no row, no child, no change log operation once the log settles.
- **S4** `an empty id or one already stored is refused`, with nothing written.
- **P1** `a new <type> opens unlocked with its starter cards open`: `RecordEditBar` titled as call 2, the essential and starter editors open, no menu button.
- **P2** `Save waits for the first entry` (an opener with no seed).
- **P3** `an untouched new <type> leaves without asking`; `an entry asks before leaving`: Keep editing stays, Discard leaves with nothing created.
- **P4** `Save creates the <type> and leaves with <result>`: full page pops it (Question 3); embedded calls `onCreated(id)`.
- **P5** `a Save that fails keeps everything`: `recordEdit_saveFailed`, the bar and every entry stay; a second Save makes one more create with the same id.
- **P6** `the cards a new <type> leaves out are neither shown nor offered` (Question 9).
- **P7** `nothing is written before Save`: open, type, Cancel, Discard: the fake save's `creates` and `calls` are empty.
- **R1** `new<Type>Page` with the switch on is the page with its request; off, the form with the same arguments; the new route's `onExit` is `confirmLeaveRecordSitting`.
- **R2** `new<Type>Pane` on is the page, embedded, whose `onCreated` is the pane's `onSaved`; off, the form.
- **R3** `Add on a phone opens the new <type> once created` (switch on): a router whose new address pops `'n1'` at once leaves the location at the record's page (Question 3); with the switch off, as today.

## Review Focus

1. A trip with no stored row: no provider read throws and no error or spinner stands in for the page, full page and pane, with every Overview card the strip offers opened. Pinned in Task 21.
2. A Save that fails after the row is inserted (a held write throws): no row, no children, no History, every other record as it was (a draft's dives still on their old trips, a set's demoted default still default), and the retry creates once. Pinned in Tasks 14, 17 and 19 beyond S3.
3. A gear clone of a tank whose type attaches a hydro clock: one hydro clock after Save, the clone's, without a baseline. Pinned in Task 14.
4. A picker gets what it expects: the buddy picker a `Buddy` it can select, the dive's Details card a centre id and a trip id it reads back into the dive's sitting, the passport Pack card a trip id it packs for. Pinned in Tasks 8, 9 and 22.
5. A default read asynchronously (insurance primary, sharing by default, the default currency) is in the seed before the sitting opens: no dot, Save still disabled, and a first insurance saved primary while a second is not. Pinned in Tasks 3, 14 and 20.

## File Structure

Shared (Part A):
- `lib/core/services/change_log/record_sitting_writer.dart` (modify): `createRecordSitting`.
- `lib/shared/widgets/record_editing/record_sharing_sitting.dart` (modify): a new record's sharing is the seed's, unread.
- `lib/shared/widgets/record_editing/record_creating.dart` (create): `RecordCreating`.
- `lib/shared/widgets/record_editing/open_new_record.dart` (create): `openNewRecord`.

Per type (`<f>` its feature folder, `<x>` its file stem):
- `lib/features/<f>/data/services/<x>_edit_save_service.dart` (modify): `create`.
- `lib/features/<f>/presentation/editing/<x>_new_sitting.dart` (create): the request, the seed, the laid-out cards, the prefill.
- `lib/features/<f>/presentation/pages/<x>_detail_page_creating.dart` (create, a part of the page): the page's `RecordCreating` hooks.
- `lib/features/<f>/presentation/pages/<x>_detail_page.dart` (modify): the `.new<Type>` constructor and its fields, the part directive, the mixin, a `newRecordWaiting` check at the top of `build`, the record read through `shownStored`, menu actions empty while creating, left-out cards (Question 9).
- `lib/features/<f>/presentation/pages/<x>_edit_routes.dart` (modify): `new<Type>Page`, `new<Type>Pane`, `openNew<Type>`.
- `lib/core/router/app_router.dart` (modify): each new route's builder and `onExit`.
- The test harness beside each page's unlock tests (modify): `Fake<Type>Save.create` and `pumpNew<Type>Page`.

---

## Part A: the shared pieces, documents and species (PR 1)

### Task 1: `createRecordSitting` and a new record's sharing

**Files:**
- Modify: `lib/core/services/change_log/record_sitting_writer.dart`, `lib/shared/widgets/record_editing/record_sharing_sitting.dart`
- Test: `test/core/services/change_log/record_sitting_writer_test.dart`, `test/shared/widgets/record_editing/record_sharing_sitting_test.dart`

**Interfaces:**
- Produces: `Future<T> createRecordSitting<T>({required String table, required String recordId, required Iterable<String> changedCardIds, required Future<bool> Function() isStored, required Future<void> Function() insert, Future<void> Function()? alsoWrite, required Future<T?> Function() readBack, required T created})`. Inside `runRecordSitting` with the same table, id and cards: throws `StateError` when `recordId` is empty or `isStored()` is true, before any write; then `insert`, then `alsoWrite`; returns `readBack()` or, when that is null, `created`.
- Produces: `RecordSharingSitting.load(session, adapter, {String? actingDiverId, S? newRecordSharing})`. For `session.isNew` it keeps the adapter and remembers `newRecordSharing` as read, reading nothing (no row exists); asserts it is given.

- [ ] **Step 1: Write the failing tests.** In `record_sitting_writer_test.dart`, a group `createRecordSitting` on the test database with a small table already used there (the dive sites table, as `SiteEditSaveService.create` does): S1, S2, S3, S4, and `the read-back copy is returned, else the created one`. In `record_sharing_sitting_test.dart`: `a new record's sharing is the seed's, read from nowhere`: an adapter whose `read` throws; `load` on `EditSession(..., isNew: true)` with `newRecordSharing: everyone` leaves it as read, not unread, and a `set` to none holds a change.
- [ ] **Step 2: Run** `flutter test test/core/services/change_log/record_sitting_writer_test.dart test/shared/widgets/record_editing/record_sharing_sitting_test.dart`. Expected: compile failure (`createRecordSitting`, `newRecordSharing` undefined).
- [ ] **Step 3: Implement** both, each with a doc comment naming issue #4527, phase 3, plan 11.
- [ ] **Step 4: Run** the same files. Expected: all pass.
- [ ] **Step 5: Commit** `feat(editing): a shared writer creates a record as one sitting, and a new record's sharing starts from its seed`.

### Task 2: `RecordCreating` and `openNewRecord`

**Files:**
- Create: `lib/shared/widgets/record_editing/record_creating.dart`, `lib/shared/widgets/record_editing/open_new_record.dart`
- Test: `test/shared/widgets/record_editing/record_creating_test.dart` (a fake record type and page, as `record_edit_host_test.dart` builds one), `test/shared/widgets/record_editing/open_new_record_test.dart`

**Interfaces:**
- Produces `mixin RecordCreating<W extends ConsumerStatefulWidget, T> on RecordEditHost<W, T>`, mixed in after the page's own editing mixin, so its overrides win while creating and call `super` otherwise. The behaviour is the site's `_SiteDetailPageCreating` and `_NewSiteLoader`, made generic. The page supplies:
  - `bool get isCreating` (already on the host).
  - `Future<T?> makeNewRecordSeed(ProviderRead read, String id)`: the seed, or null when a clone's source is gone; a throw is a failed read.
  - `List<String> newRecordLaidOut(T seed)`.
  - `Future<void> applyNewRecordPrefill(EditSession<T> session)`, default nothing: tracked by the mixin, so Save waits for it.
  - `Future<T> createRecord(EditSession<T> session)`: the type's save service `create`.
  - `Future<void> afterRecordCreated(T created)`, default nothing: run after the commit, guarded (a throw is logged, never a failed Save).
  - `String newRecordTitle(BuildContext context)`, `String get newRecordLeaveLocation` (where a full page with nothing under it goes), `bool get newRecordEmbedded`, `void Function(String id)? get onNewRecordCreated`, `VoidCallback? get onNewRecordCancelled`.
  - `({String title, String body}) newRecordUnavailable(BuildContext context, {required bool failed})`: the page's not-found and failed-read texts.
  - `Object? newRecordResult(T created)`, default `recordIdOf(created)`; `void leaveCreated(T created)`, default `onNewRecordCreated(id)` when embedded, else a pop with `newRecordResult`, else `go(newRecordLeaveLocation)`.
- It provides: `String get newRecordId` (`const Uuid().v4()`, made once); `T? get newRecordSeed`; `Widget? newRecordWaiting(BuildContext context)` (loading, unavailable, or handing on with Back held, else null); `T? shownStored(T? stored)` (the seed while creating, else `stored`).
- It overrides, while creating: `hostRecordId` (the new id), `storedForUnlock` (the seed), `editingTitle`, `saveSitting` (runs `createRecord`, keeps the created record, then refreshes nothing itself), `saveNewRecord` (save; `recordEdit_fixInvalid`, a `RecordSittingRefusal`'s message or `recordEdit_saveFailed`; then `afterRecordCreated`, then `leaveCreated` unless the page has gone), `cancelNewRecord` (`cancelSitting`, then leave), and `onEditChanged` (a sitting that ends without a create while the page is current leaves, as Cancel does; one ended by the app's leave check does not).
- On the first frame with a seed it calls `editController.unlock(seed, laidOut: newRecordLaidOut(seed))`, then `applyNewRecordPrefill`, as `_openNewSite`.
- Produces: `Future<void> openNewRecord(BuildContext context, {required String newLocation, required String Function(String id) recordLocation, Object? extra})`: pushes [newLocation] and, given an id back, pushes `recordLocation(id)`.

- [ ] **Step 1: Write the failing tests** in `record_creating_test.dart`, on a fake page whose fake save records `creates`: P1 to P5 and P7 for the fake; `a prefill is a change and Save waits for it` (a prefill on a `Completer`: Save tapped before it completes creates with the prefilled value); `a seed that is gone shows the unavailable text and no bar`; `a seed whose read fails says so`; `a sitting ended by locking leaves, one ended by the leave check does not`; `afterRecordCreated that throws still leaves with the record`; `a pane create calls onCreated and never pops`; `Back is held while the created record is handed on`. In `open_new_record_test.dart`: `an id back opens the record`; `nothing back stays`.
- [ ] **Step 2: Run** `flutter test test/shared/widgets/record_editing/record_creating_test.dart test/shared/widgets/record_editing/open_new_record_test.dart`. Expected: compile failure.
- [ ] **Step 3: Implement** both files, with library doc comments naming issue #4527 and the site's part file they generalise.
- [ ] **Step 4: Run** the same files, and unchanged `test/shared/widgets/record_editing/record_edit_host_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(editing): one shared piece opens a record not yet created on its own page`.

### Task 3: A new document: service, seed, page

**Files:**
- Modify: `lib/features/documents/data/services/document_edit_save_service.dart`, `lib/features/documents/presentation/pages/document_detail_page.dart`
- Create: `lib/features/documents/presentation/editing/document_new_sitting.dart`, `lib/features/documents/presentation/pages/document_detail_page_creating.dart`
- Modify: `test/features/documents/presentation/pages/document_detail_page_unlock_harness.dart`
- Test: `test/features/documents/data/services/document_edit_save_service_test.dart`, `test/features/documents/presentation/editing/document_new_sitting_test.dart` (create), `test/features/documents/presentation/pages/document_detail_page_new_test.dart` (create)

**Interfaces:**
- Produces: `Future<Document> DocumentEditSaveService.create({required Document document, required List<DocumentPage> pages, required List<String> tagIds, required Iterable<String> changedCardIds, Future<void> Function()? alsoWrite})` through `createRecordSitting`; the insert is `DocumentRepository.save` with the given id (it inserts a given id) and `notify: false`.
- Produces: `class NewDocumentRequest { const NewDocumentRequest({this.owner, this.type, this.shownOwner}); final DocumentOwner? owner; final DocumentType? type; final DocumentOwner? shownOwner; }`: `owner` and `type` are seeds (Question 10); `shownOwner` is shown fixed while the document is created as Personal (call 12). `NewDocumentRequest.fromQuery(Map<String, String>)` reads `ownerKind`, `ownerId` and `type` as the route does today.
- Produces: `Future<Document> newDocumentSeed(ProviderRead read, {required String id, DocumentType? type})`: the diver, Personal, `type ?? DocumentType.other`, the default reminder lead, and for insurance `isPrimary` when `hasPrimaryInsurance` is false (call 4); `List<String> newDocumentLaidOut` = `[details, pages]`; `void applyNewDocumentPrefill(EditSession<Document> session, NewDocumentRequest request)`: the owner and type through the Details card's own setters.
- Produces: `DocumentDetailPage.newDocument({Key? key, NewDocumentRequest request = const NewDocumentRequest(), bool embedded = false, void Function(String id)? onCreated, VoidCallback? onCreateCancelled})`; `afterRecordCreated` re-arms reminders as `saveSitting` does; the owner field hidden while `shownOwner` is set, as the form's `ownerFixed`.

- [ ] **Step 1: Write the failing tests.** Service: S1 to S4, and `pages and tags are written with the row`. Sitting: `a seed is Personal, other, with the default lead`; Review Focus 5: `a first insurance seeds primary, a second does not`, neither a change; `a type from the list and an owner from a page are changes of Details`. Page: P1 to P7 with result the id; `a card document from the request has no title, expiry or reminder`; `a shown owner is shown fixed and saved as Personal`.
- [ ] **Step 2: Run** the three files. Expected: compile failure.
- [ ] **Step 3: Implement** the service method, the sitting file, the part file and the page's changes; `FakeDocumentSave.create` and `pumpNewDocumentPage` in the harness.
- [ ] **Step 4: Run** the three files and unchanged `document_detail_page_unlock_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(documents): a new document opens unlocked on the document page, behind the switch`.

### Task 4: Documents: routes, pane, the Documents card and the openers

**Files:**
- Modify: `lib/features/documents/presentation/pages/document_edit_routes.dart`, `lib/core/router/app_router.dart` (the `newDocument` route), `lib/features/documents/presentation/pages/documents_page.dart` (`createBuilder`, the phone FAB), `lib/features/documents/presentation/widgets/documents_section.dart` (`_addInSitting`, and the locked Add)
- Test: `test/core/router/app_router_test.dart`, `test/features/documents/presentation/pages/documents_pages_test.dart`, `test/features/documents/presentation/widgets/documents_section_test.dart`

**Interfaces:**
- Produces: `Widget newDocumentPage(Map<String, String> query, {bool unlockEditing = kUnlockRecordEditing})`, `Widget newDocumentPane(BuildContext, void Function(String) onSaved, VoidCallback onCancel, {DocumentType? initialType, bool unlockEditing = kUnlockRecordEditing})`, `Future<void> openNewDocument(BuildContext context, {DocumentType? type, bool unlockEditing = kUnlockRecordEditing})` (Question 3: the documents list's phone FAB opens the new document).
- Changes `DocumentsSection._addInSitting` under the switch: pushes `DocumentDetailPage.newDocument(request: NewDocumentRequest(shownOwner: <the owner>), onCreated:)`; `onCreated` reads the document back and `attachDocument`s it, as today. The locked Add keeps pushing `/documents/new?ownerKind=&ownerId=`; the medical page's push is unchanged (it reaches the page through the route).

- [ ] **Step 1: Write the failing tests**: R1, R2 (with `initialType` carried), R3 for the FAB; `the card's Add in a sitting opens the new page with the owner shown, and its document is linked once created` (switch on); `Cancel on that page links nothing and creates nothing`; with the switch off, the existing form case passes unchanged.
- [ ] **Step 2: Run** the three files. Expected: the new cases fail.
- [ ] **Step 3: Implement** the helpers, the route, the pane, the FAB and the card's add.
- [ ] **Step 4: Run** the three files and `test/features/settings/presentation/pages/medical_info_edit_page_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(documents): /documents/new, the pane and the Documents card open the new document page behind the switch`.

### Task 5: A new species

**Files:**
- Modify: `lib/features/marine_life/data/repositories/species_repository.dart` (`createSpecies` takes an optional `id`), `lib/features/marine_life/data/services/species_edit_save_service.dart`, `lib/features/marine_life/presentation/pages/species_detail_page.dart`, `lib/features/marine_life/presentation/pages/species_edit_routes.dart`, `lib/core/router/app_router.dart` (`newSpecies`), `lib/features/marine_life/presentation/pages/species_manage_page.dart` (FAB)
- Create: `lib/features/marine_life/presentation/editing/species_new_sitting.dart`, `lib/features/marine_life/presentation/pages/species_detail_page_creating.dart`
- Modify: `test/features/marine_life/presentation/pages/species_detail_page_unlock_harness.dart` (`FakeSpeciesSave` has no `noSuchMethod`, so it gains `create`)
- Test: `test/features/marine_life/data/services/species_edit_save_service_test.dart`, `test/features/marine_life/presentation/pages/species_detail_page_new_test.dart` (create), `test/core/router/app_router_test.dart`, `test/features/marine_life/presentation/pages/species_manage_page_test.dart`

**Interfaces:**
- Produces: `createSpecies({String? id, ...})` (an empty or absent id makes one, as today); `Future<Species> SpeciesEditSaveService.create({required Species species, required Iterable<String> changedCardIds, Future<void> Function()? alsoWrite})`; `Species newSpeciesSeed({required String id})` (category fish, custom); laid out `[header, description]`; `SpeciesDetailPage.newSpecies({Key? key})`; `Widget newSpeciesPage({bool unlockEditing = kUnlockRecordEditing})`; the manage FAB through `openNewRecord` (Question 3).
- The online lookup works while creating as on a stored species: each filled value a change of the header block.

- [ ] **Step 1: Write the failing tests**: S1 to S4; P1 to P7 (result the id; P6: no Photos, Statistics, Where seen, Sightings, no Delete or Suggest); `a lookup fills the header as changes`; R1; R3 for the manage FAB; `createSpecies keeps an id it is given`.
- [ ] **Step 2: Run** the four files. Expected: compile failure.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the four files and unchanged `species_detail_page_unlock_test.dart` and `species_edit_page_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(species): a new species opens unlocked on the species page, behind the switch`.

### Task 6: Part A to a green PR

- [ ] **Step 1:** Merge origin/main; `flutter analyze` the whole repository; fix anything the merge broke in its own commit.
- [ ] **Step 2:** Run the code review (`code-review` skill, `--max-findings all`) on the branch; fix every valid finding, shared code included, each fix with its test; rerun only the changed test files.
- [ ] **Step 3:** Screenshots from headless widget goldens with the switch on (light and dark, phone and desktop): a new document, one from a Documents card with its owner shown, a new species; "before" from the forms on origin/main. Attach through the project's highest-numbered secret PR screenshot gist.
- [ ] **Step 4:** Push; open the PR (`Refs #4527`; names the shared files changed and that the switch stays off); bind it, turn Auto-fix on.

### As built (Part A)

Built natively on 2026-11-20. Where the code differs from the tasks above, the code is right, and Parts B to D use its names:

- `makeNewRecordSeed` takes a `RecordSeedRead` (the same function type as `ProviderRead`, declared in shared code, which may not import the equipment feature where `ProviderRead` lives).
- `afterRecordCreated(T)` became `captureAfterRecordCreated()`, returning the work as a closure made before Save, so it runs once the record exists even if the page has gone, and never reads the page's `ref` late (review fix).
- Every type's `createRecord` passes `alsoWrite: heldWritesForCreate(session)`, which runs the writes held before the record, then the rest, as a new site's create does (review fix).
- `newRecordUnavailable(context, {Object? error})` takes the seed's error (null when the source has gone), in place of `failed`.
- `openNewRecord` takes `idOf` (default `poppedId`) for a page that pops its record rather than its id (the buddy's, Question 3).
- `DocumentEditSaveService.create` takes the whole `DocumentRecord` (row, pages, tags); `NewDocumentRequest` has `ownerFixed: bool` in place of `shownOwner`, as the form's `ownerFixed` shows no owner; `newDocumentSeed` takes no type (the opener's type is a change).
- `DocumentsSection` and the route helpers take `unlockEditing` so tests can turn the switch on. No "added" snack bar on a new document or species: the page leaves to its opener or the record, as a new site does.
- A document's expiry status stays shown while creating: it is calculated from the working copy and reads nothing by id.

## Part B: buddies, dive centres, certifications, courses (PR 2)

### Task 7: A new buddy: service, seed, page

**Files:**
- Modify: `lib/features/buddies/data/services/buddy_edit_save_service.dart`, `lib/features/buddies/presentation/pages/buddy_detail_page.dart`
- Create: `lib/features/buddies/presentation/editing/buddy_new_sitting.dart`, `lib/features/buddies/presentation/pages/buddy_detail_page_creating.dart`
- Modify: `test/features/buddies/presentation/pages/buddy_detail_page_unlock_harness.dart`
- Test: `test/features/buddies/data/services/buddy_edit_save_service_test.dart`, `test/features/buddies/presentation/pages/buddy_detail_page_new_test.dart` (create)

**Interfaces:**
- Produces: `Future<Buddy> BuddyEditSaveService.create({required Buddy buddy, required Iterable<String> changedCardIds, Future<void> Function()? alsoWrite})`: `assertLinkAllowed` inside, a refusal a `RecordSittingRefusal` as in `save`; then `createBuddy`, then the held writes (certifications through `replaceBuddyCertifications`).
- Produces: `class NewBuddySeed { name, email, phone, photo }` with `NewBuddySeed.fromRouteExtra(Object?)` (today's `extra` map); `Future<Buddy> newBuddySeed(RecordSeedRead read, {required String id})` (the active diver, ranked, not a favourite); laid out `[header, contact, notes]`; `applyNewBuddyPrefill` puts each given value, the photo alone included, on its card's field.
- Produces: `BuddyDetailPage.newBuddy({Key? key, NewBuddySeed? seed, bool embedded = false, onCreated, onCreateCancelled})`; `newRecordResult` is the created `Buddy` (Question 3).

- [ ] **Step 1: Write the failing tests.** Service: S1 to S4; `a profile already linked to another buddy is refused, nothing written`; `certifications staged in the sitting are created for the new buddy`. Page: P1 to P7 (result the `Buddy`; P6: no Gear, Photos or Card details; Statistics offered with its switch and no figures); `a seed from contacts is a change of the header and Contact, a photo alone included`; `a new buddy starts ranked and can be excluded`.
- [ ] **Step 2: Run** both files. Expected: compile failure.
- [ ] **Step 3: Implement**, with `FakeBuddySave.create` and `pumpNewBuddyPage`.
- [ ] **Step 4: Run** both files and unchanged `buddy_detail_page_unlock_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(buddies): a new buddy opens unlocked on the buddy page, behind the switch`.

### Task 8: Buddies: routes, pane, openers

**Files:**
- Modify: `lib/features/buddies/presentation/pages/buddy_edit_routes.dart`, `lib/core/router/app_router.dart` (`newBuddy`, still on the root navigator), `lib/features/buddies/presentation/pages/buddy_list_page.dart` (both `createBuilder`s, the FAB), `lib/features/buddies/presentation/widgets/buddy_list_content.dart` (empty state, Import from contacts)
- Test: `test/core/router/app_router_test.dart`, `test/features/buddies/presentation/pages/buddy_list_page_test.dart`, `test/features/buddies/presentation/widgets/buddy_pick_sheet_test.dart`, `test/features/buddies/presentation/widgets/buddy_contact_import_test.dart`

**Interfaces:**
- Produces: `Widget newBuddyPage(Object? extra, {bool unlockEditing = kUnlockRecordEditing})`, `Widget newBuddyPane(...)`, `Future<void> openNewBuddy(BuildContext context, {NewBuddySeed? seed, bool unlockEditing = kUnlockRecordEditing})`.

- [ ] **Step 1: Write the failing tests**: R1, R2, R3 (FAB, empty state); `contacts import opens the new buddy page seeded, then the buddy`; Review Focus 4: `Add New Buddy in the pick sheet returns the buddy just created` with the switch on; with it off the existing cases pass unchanged.
- [ ] **Step 2: Run** the four files. Expected: the new cases fail.
- [ ] **Step 3: Implement.** `BuddyPicker` and `showBuddyPickSheet` are unchanged: they get a `Buddy` either way.
- [ ] **Step 4: Run** the four files and `test/features/buddies/presentation/widgets/buddy_picker_navigation_render_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(buddies): /buddies/new, the pane and the list's Add open the new buddy page behind the switch`.

### Task 9: A new dive centre

**Files:**
- Modify: `lib/features/dive_centers/data/services/dive_center_edit_save_service.dart`, `lib/features/dive_centers/presentation/pages/dive_center_detail_page.dart`, `dive_center_edit_routes.dart`, `dive_center_list_page.dart`, `dive_center_map_page.dart`, `lib/features/dive_centers/presentation/widgets/dive_center_list_content.dart`, `lib/core/router/app_router.dart`
- Create: `lib/features/dive_centers/presentation/editing/dive_center_new_sitting.dart`, `lib/features/dive_centers/presentation/pages/dive_center_detail_page_creating.dart`
- Modify: `test/features/dive_centers/presentation/pages/dive_center_detail_page_unlock_harness.dart`
- Test: `test/features/dive_centers/data/services/dive_center_edit_save_service_test.dart`, `test/features/dive_centers/presentation/pages/dive_center_detail_page_new_test.dart` (create), `test/core/router/app_router_test.dart`, `test/features/dive_centers/presentation/pages/dive_center_list_page_test.dart`, `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_trip_rows_test.dart`

**Interfaces:**
- Produces: `Future<DiveCenter> DiveCenterEditSaveService.create({required DiveCenter center, ...})` (row, then rental gear notes); `DiveCenter newDiveCenterSeed(RecordSeedRead read, {required String id})`; laid out `[header, contact, map]`; `DiveCenterDetailPage.newDiveCenter(...)`; `newDiveCenterPage`, `newDiveCenterPane`, `openNewDiveCenter` (FAB, empty state, map's Add; Question 3).
- The page's sections keyed by `widget.centerId` (Dives, Gear kept here, Rental gear, Documents) take `hostRecordId` while creating; Dives and Gear kept here are left out (Question 9).

- [ ] **Step 1: Write the failing tests**: S1 to S4; P1 to P7 (result the id); `an address typed with no coordinates looks them up, and Save waits for it` (`FakeLocations`); `fill hours both or neither, closing after opening`; R1, R2, R3 for FAB and map; Review Focus 4: `a new centre from a dive's Details card is read back into the dive's sitting` (switch on).
- [ ] **Step 2: Run** the five files. Expected: compile failure.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the five files and unchanged `dive_center_detail_page_unlock_test.dart` and `dive_center_edit_page_fill_hours_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(dive-centers): a new dive centre opens unlocked on its page, behind the switch`.

### Task 10: A new certification

**Files:**
- Modify: `lib/features/certifications/data/services/certification_edit_save_service.dart`, `lib/features/certifications/presentation/pages/certification_detail_page.dart` (constructor and branch only: it is over 800), `certification_edit_routes.dart`, `certification_list_page.dart`, `certification_wallet_page.dart`, `lib/features/certifications/presentation/widgets/certification_list_content.dart`, `lib/core/router/app_router.dart`
- Create: `lib/features/certifications/presentation/editing/certification_new_sitting.dart`, `lib/features/certifications/presentation/pages/certification_detail_page_creating.dart`
- Modify: `test/features/certifications/presentation/pages/certification_detail_page_unlock_harness.dart`
- Test: `test/features/certifications/data/services/certification_edit_save_service_test.dart`, `test/features/certifications/presentation/pages/certification_detail_page_new_test.dart` (create), `test/core/router/app_router_test.dart`, `test/features/certifications/presentation/pages/certification_list_page_test.dart`, `test/features/certifications/presentation/pages/certification_wallet_page_test.dart`

**Interfaces:**
- Produces: `Future<Certification> CertificationEditSaveService.create({required Certification certification, ...})`: the row with its card images (`createCertification` saves them), then currency events and preferences held, all inside; `Certification newCertificationSeed(RecordSeedRead read, {required String id})` (agency PADI, no level, the active diver, no buddy); laid out `[details, dates, cardPhotos]`; `CertificationDetailPage.newCertification(...)`; `newCertificationPage`, `newCertificationPane`, `openNewCertification` (FAB, empty state, wallet; Question 3).

- [ ] **Step 1: Write the failing tests**: S1 to S4; `card photos are written with the row`; P1 to P7 (result the id; P6: no Currency, no Training course); `a title or a level is required`; `a second recognition is saved with the first`; `picking an instructor fills the name and number`; R1, R2, R3 for FAB and wallet.
- [ ] **Step 2: Run** the five files. Expected: compile failure.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the five files and unchanged `certification_detail_page_unlock_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(certifications): a new certification opens unlocked on its page, behind the switch`.

### Task 11: A new course

**Files:**
- Modify: `lib/features/courses/data/services/course_edit_save_service.dart`, `lib/features/courses/presentation/pages/course_detail_page.dart`, `course_edit_routes.dart`, `course_list_page.dart`, `lib/features/courses/presentation/widgets/course_list_content.dart`, `course_summary_widget.dart`, `lib/core/router/app_router.dart`
- Create: `lib/features/courses/presentation/editing/course_new_sitting.dart`, `lib/features/courses/presentation/pages/course_detail_page_creating.dart`
- Modify: `test/features/courses/presentation/pages/course_detail_page_unlock_harness.dart`
- Test: `test/features/courses/data/services/course_edit_save_service_test.dart`, `test/features/courses/presentation/pages/course_detail_page_new_test.dart` (create), `test/core/router/app_router_test.dart`, `test/features/courses/presentation/pages/course_list_page_test.dart`

**Interfaces:**
- Produces: `Future<Course> CourseEditSaveService.create({required Course course, ...})`: the row, then earned certifications (`setCourseCertifications`, which can move a certification off another course, inside); `Course newCourseSeed(RecordSeedRead read, {required String id})` (agency PADI, start today, the active diver); laid out `[status, details, instructor]`; `CourseDetailPage.newCourse(...)`; `newCoursePage`, `newCoursePane`, `openNewCourse` (FAB, empty state, summary Add; Question 3: the page pops the id, the opener opens the course).

- [ ] **Step 1: Write the failing tests**: S1 to S4; `a certification moved off another course moves with the create`; P1 to P7 (result the id; P6: no Requirements, no Training dives); `switching completed on fills today, a start after the completion pulls it along`; `a start more than a year ahead can be set`; R1, R2, R3 for FAB and summary; `a new course from the dive's course picker leaves the dive page under it` (the form's `go` threw it away).
- [ ] **Step 2: Run** the four files. Expected: compile failure.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the four files and unchanged `course_detail_page_unlock_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(courses): a new course opens unlocked on the course page, behind the switch`.

### Task 12: Part B to a green PR

As Task 6, with screenshots of a new buddy (and one from contacts), a new centre, a new certification and a new course.

## Part C: gear items and equipment sets (PR 3)

### Task 13: `GearItemEditSaveService.create`

**Files:**
- Modify: `lib/features/equipment/data/services/gear_item_edit_save_service.dart`, `test/features/equipment/presentation/pages/equipment_detail_page_unlock_harness.dart` (`FakeGearItemSave.create`)
- Test: `test/features/equipment/data/services/gear_item_edit_save_service_test.dart`

**Interfaces:**
- Produces: `Future<EquipmentItem> GearItemEditSaveService.create({required EquipmentItem item, required List<String> tagIds, required Iterable<String> changedCardIds, Future<void> Function()? alsoWrite})`: `createEquipmentWithTags` (or `createEquipment` with no tags), which attaches the type's clocks and baselines as today, then the held writes (first location, sharing, documents, a clone's extras from Task 14), through `createRecordSitting`.

- [ ] **Step 1: Write the failing tests**: S1 to S4; `tags typed on a new item are written with it`; `the type's clocks are attached in the same entry`; `a first location held as a move is one move, in the same entry`.
- [ ] **Step 2: Run** the file. Expected: compile failure.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** it. Expected: all pass.
- [ ] **Step 5: Commit** `feat(equipment): the gear item save service creates an item, its first place and a clone's extras as one sitting`.

### Task 14: A new gear item's sitting: request, seed, clone

**Files:**
- Create: `lib/features/equipment/presentation/editing/gear_item_new_sitting.dart`
- Modify: `lib/features/equipment/presentation/editing/gear_item_service_sitting.dart` (the clocks list's write, on a new item, updates a clock `createEquipment` attached of the same kind rather than adding a second, as `copyExtras` does: call 9)
- Test: `test/features/equipment/presentation/editing/gear_item_new_sitting_test.dart` (create), `test/features/equipment/presentation/editing/gear_item_service_sitting_test.dart`

**Interfaces:**
- Produces: `class NewGearItemRequest { const NewGearItemRequest({this.type, this.serial, this.parentId, this.cloneFromId}); ...; factory NewGearItemRequest.fromQuery(Map<String, String> query); }` (`type`, `serial`, `parent`, `cloneFrom`, as the route reads them).
- Produces: `Future<EquipmentItem> newGearItemSeed(RecordSeedRead read, {required String id})` (call 4); `typedef GearCloneSource = ({EquipmentItem item, List<String> ownTagIds, String? ownPlaceId, List<ServiceClock> clocks, List<String> setIds, List<MediaItem> documents});` and `Future<GearCloneSource?> readGearClone(RecordSeedRead read, String itemId)` (null when the diver cannot see it); `List<String> newGearItemLaidOut({NewGearItemRequest? request, GearCloneSource? clone})` (`[header, details, location]`, plus `serviceClocks` and `legacyFiles` when a clone carries them); `Future<void> applyNewGearItemPrefill(EditSession<EquipmentItem> session, {NewGearItemRequest? request, GearCloneSource? clone, required String cloneName})`: the type, serial and parent through the header and Details setters; a clone's fields from `equipmentCloneSeed`, its own tags, its own place as the first move, its clocks without a baseline on the clocks list, its set memberships and document copies through `EditSession.holdChange` (Question 8). Tracked, so Save waits.

- [ ] **Step 1: Write the failing tests** (the last two on the test database, through the real `GearItemEditSaveService.create`): `a seed is a regulator, active, in the default currency, with no dot`; `a type and a serial from the device lists are changes`; `a part's parent is a change and is dropped for a type that cannot be fitted`; `a clone is named as a copy, with no serial, owner or passport id`; `a sharee's clone leaves the owner's tags and place behind`; `a quick Save waits for the clone's tags`; `a clone the diver cannot see reads null`; Review Focus 3: `a clone of a tank keeps one hydro clock, the clone's, without a baseline`; Review Focus 2: `a failed set membership leaves no item, clock, move or tag`.
- [ ] **Step 2: Run** both files. Expected: compile failure.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** it. Expected: all pass.
- [ ] **Step 5: Commit** `feat(equipment): a new gear item's seed, the device lists' and Add part's seeds and a clone's copy, as changes`.

### Task 15: The new gear item page

**Files:**
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page.dart`, `lib/features/equipment/presentation/editing/gear_item_sitting_host.dart` (sharing loads for a new item, `newRecordSharing: none`), `lib/features/equipment/presentation/editing/gear_item_header_editor.dart` (no type lock while creating)
- Create: `lib/features/equipment/presentation/pages/equipment_detail_page_creating.dart`
- Test: `test/features/equipment/presentation/pages/equipment_detail_page_new_test.dart` (create)

**Interfaces:**
- Produces: `EquipmentDetailPage.newItem({Key? key, NewGearItemRequest request = const NewGearItemRequest(), bool embedded = false, onCreated, onCreateCancelled})`; `captureAfterRecordCreated` runs `offerViewRevealingSavedItem` (call 8); a clone's `leaveCreated` replaces the page with `/equipment/<id>` (Question 3); title `equipment_edit_appBar_cloneTitle` for a clone.

- [ ] **Step 1: Write the failing tests**: P1 to P7 (result the id; P6 as Question 9); `the type is never locked`; `a Wanted item saved under the default view offers the Wanted view`; `a new item under Service Due offers the default view`; `a clone opens titled Clone, prefilled, and its Save replaces the page with the clone`; `a clone whose source is gone opens as not found`; `a clone keeps its form when the source changes after it opened`.
- [ ] **Step 2: Run** the file. Expected: compile failure.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** it and unchanged `equipment_detail_page_unlock_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(equipment): a new gear item and a clone open unlocked on the item page, behind the switch`.

### Task 16: Gear items: routes, pane, openers

**Files:**
- Modify: `lib/features/equipment/presentation/pages/equipment_edit_routes.dart`, `lib/core/router/app_router.dart` (`newEquipment`, with `onExit`), `lib/features/equipment/presentation/pages/equipment_list_page.dart` (both `createBuilder`s, the phone and table-mode FABs), `lib/features/equipment/presentation/widgets/equipment_list_content.dart` (empty state)
- Test: `test/core/router/app_router_test.dart`, `test/features/equipment/presentation/pages/equipment_list_page_test.dart`, `test/features/dive_computer/presentation/pages/device_list_page_test.dart`, `test/features/transmitters/presentation/pages/transmitters_page_test.dart`, `test/features/equipment/presentation/widgets/children_card_test.dart`

**Interfaces:**
- Produces: `Widget newGearItemPage(Map<String, String> query, {bool unlockEditing = kUnlockRecordEditing})`, `Widget newGearItemPane(...)`, `Future<void> openNewGearItem(BuildContext context, {bool unlockEditing = kUnlockRecordEditing})`. Clone, Add part, the device lists, the transmitter setup and the dashboard chip keep pushing the address.

- [ ] **Step 1: Write the failing tests**: R1 (each query parameter carried), R2, R3; with the switch on: `Add by hand opens a new Dive Computer item`, `the transmitters FAB opens a new Transmitter item`, `Add part opens a new part fitted to this host`.
- [ ] **Step 2: Run** the five files. Expected: the new cases fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the five files and `test/features/equipment/presentation/pages/equipment_detail_page_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(equipment): /equipment/new, the pane and the list's Add open the new item page behind the switch`.

### Task 17: A new equipment set and a clone

**Files:**
- Modify: `lib/features/equipment/data/services/equipment_set_edit_save_service.dart`, `lib/features/equipment/presentation/pages/equipment_set_detail_page.dart`, `equipment_set_edit_routes.dart`, `lib/core/router/app_router.dart` (`newEquipmentSet`), `equipment_list_page.dart` (phone FAB only), `equipment_set_list_page.dart`, `lib/features/equipment/presentation/widgets/equipment_set_list_content.dart`
- Create: `lib/features/equipment/presentation/editing/equipment_set_new_sitting.dart`, `lib/features/equipment/presentation/pages/equipment_set_detail_page_creating.dart`
- Modify: `test/features/equipment/presentation/pages/equipment_set_detail_page_unlock_harness.dart` (real database: `pumpNewSetPage`)
- Test: `test/features/equipment/data/services/equipment_set_edit_save_service_test.dart`, `test/features/equipment/presentation/pages/equipment_set_detail_page_new_test.dart` (create), `test/core/router/app_router_test.dart`, `test/features/equipment/presentation/pages/equipment_set_detail_clone_test.dart`

**Interfaces:**
- Produces: `Future<EquipmentSet> EquipmentSetEditSaveService.create({required EquipmentSet set, required List<SetGeofence> geofences, required Iterable<String> changedCardIds, Future<void> Function()? alsoWrite})`: `createSet`, the default (demoting the diver's other default) and each geofence inside; never the "Update past dives?" question (the note).
- Produces: `Future<EquipmentSet> newEquipmentSetSeed(RecordSeedRead read, {required String id})`; `Future<EquipmentSet?> readSetClone(RecordSeedRead read, String setId)` (`equipmentSetCloneSeed`, members the diver can see); laid out `[header, members]`, plus `bundle` for a clone that carries one; `EquipmentSetDetailPage.newSet({String? cloneFromId})`; `newEquipmentSetPage`, `openNewEquipmentSet` (FAB, empty state). A profile switch before Save ends the clone's sitting and leaves (call 9).

- [ ] **Step 1: Write the failing tests**: S1 to S4; Review Focus 2: `a failed geofence leaves the old default default`; P1 to P7 (result the id); `a new default set with a geofence saves both`; `a new set saves with the figure on`; `a clone opens named as a copy and saving leaves the source as it was`; `a clone keeps only the gear the diver can see`; `a profile switch before Save drops the clone`; `another diver's set is not cloned`; R1, R3; with the switch on, `a saved clone takes the source page's place, and in the split view is selected`.
- [ ] **Step 2: Run** the four files. Expected: compile failure.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the four files and unchanged `equipment_set_detail_page_unlock_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(equipment): a new set and a clone open unlocked on the set page, behind the switch`.

### Task 18: Part C to a green PR

As Task 6, with screenshots of a new item, one from Add by hand, a clone, a new set and a set clone.

### As built (Part C)

Built natively on 2026-11-20. Where the code differs from the tasks above, the code is right:

- A clone's extras (clocks without a baseline, set memberships, document copies) are one held write of the clone that runs the existing `EquipmentCloneService.copyExtras` inside the Save and fails it when any step fails, rather than prefilled card by card. Its clocks therefore show on the card only once saved, as with the form. The write reads the created row's diver, which Save may have read when the seed could not.
- A clone's place is held as the item's first move through the Location card's own `holdGearItemMove`, so the card shows it and a move made by hand replaces it. Its tags start empty with `SittingList.loadNone` (no read, which a tracked prefill must not wait for) and take the source's own.
- A clock added to a new item, of a kind `createEquipment` attaches itself at Save, takes that clock's place (`clockMergedInto`, keeping its baseline when the added one sets none) instead of making a second.
- A new item's page shows the header, Details, Location, Service clocks (not for wanted gear), Notes and Documents; the stored item's body is built only for a stored item.
- `RecordCreating` asks for the seed one microtask after `initState`, so a seed may read the page's context (the clone's localized name).
- `EquipmentSetEditSaveService.create` takes the set with its geofences on the record. A profile switch before Save drops a set clone's sitting.
- No transmitter rescan after a create: the rescan finds registry entries naming the item, and none can name a new item's id at Save; the entry that later names it rescans on its own save.

## Part D: trips (PR 4)

### Task 19: `TripEditSaveService.create`

**Files:**
- Modify: `lib/features/trips/data/services/trip_edit_save_service.dart`, `test/features/trips/presentation/pages/trip_detail_page_unlock_harness.dart` (`FakeTripSave.create`)
- Test: `test/features/trips/data/services/trip_edit_save_service_test.dart`

**Interfaces:**
- Produces: `Future<Trip> TripEditSaveService.create({required Trip trip, required Iterable<String> changedCardIds, required String? actingDiverId, List<String> draftDiveIds = const [], Set<String> draftSourceTripIds = const {}, Future<void> Function()? alsoWrite})`: `createTrip` (its parent check inside), the held writes (sharing, vessel, itinerary, notes), the generated itinerary for a liveaboard whose sitting held no days (`ItineraryDay.generateForTrip`), then `assignDivesToTrip(draftDiveIds, id, oldTripIds: draftSourceTripIds)`, all in the one entry.

- [ ] **Step 1: Write the failing tests**: S1 to S4; `a new liveaboard gets its generated days once`; `a liveaboard with days in the sitting gets no generated ones`; `a draft's dives move to the new trip`; Review Focus 2: `a failed vessel write leaves the dives on their old trips and no trip`; `a parent the diver may not write is refused`.
- [ ] **Step 2: Run** the file. Expected: compile failure.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** it. Expected: all pass.
- [ ] **Step 5: Commit** `feat(trips): the trip save service creates a trip, its days and a draft's dives as one sitting`.

### Task 20: A new trip's sitting: seed and draft

**Files:**
- Create: `lib/features/trips/presentation/editing/trip_new_sitting.dart`
- Modify: `lib/features/trips/presentation/editing/trip_sitting_host.dart` (`loadTripSitting`: sharing from the seed for a new trip)
- Test: `test/features/trips/presentation/editing/trip_new_sitting_test.dart` (create)

**Interfaces:**
- Produces: `Future<Trip> newTripSeed(RecordSeedRead read, {required String id})` (call 4: shore, now to seven days on, divers sharing one) and its sharing `Future<ItemSharing> newTripSharing(RecordSeedRead read)`; `List<String> newTripLaidOut(Trip working)` (`[header, notes]`, plus `vessel` for a liveaboard); `void applyNewTripPrefill(EditSession<Trip> session, TripDraft? draft)` (name, dates, location, resort, parent through the header block's setters; the dives kept for Save, Question 7).

- [ ] **Step 1: Write the failing tests**: `a seed is shore, eight calendar days, shared by default, with no dot`; Review Focus 5: `sharing by default arrives before the sitting opens`; `a draft's values are changes of the header block`; `a draft's parent the diver cannot choose is dropped`.
- [ ] **Step 2: Run** the file. Expected: compile failure.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** it and unchanged `test/features/trips/presentation/editing/trip_sitting_host_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(trips): a new trip's seed and a draft from selected dives, as changes`.

### Task 21: The new trip page

**Files:**
- Modify: `lib/features/trips/presentation/pages/trip_detail_page.dart`, `trip_detail_page_editing.dart` (`beforeSave`: the candidate question for a new trip without a draft, never for a draft)
- Create: `lib/features/trips/presentation/pages/trip_detail_page_creating.dart`
- Test: `test/features/trips/presentation/pages/trip_detail_page_new_test.dart` (create)

**Interfaces:**
- Produces: `TripDetailPage.newTrip({Key? key, TripDraft? draft, bool embedded = false, onCreated, onCreateCancelled})`. While creating (Question 6): no tab bar, the Overview in the prepare shape built on the working trip, and no read of `tripWithStatsProvider`, `tripStoryProvider` or any tab's provider; the Plan card offered, the Vessel card shown for a liveaboard.

- [ ] **Step 1: Write the failing tests**: P1 to P7 (result the id; P6: no tab bar, no story, no menu); Review Focus 1: `a new trip builds with no stored row, every offered card opened` (the harness's providers for the new id throwing, as the real ones do); `changing the type to liveaboard lays out Vessel, and its name is required`; `a new trip with dates asks the candidate dives at Save, and the picked ones join it`; `dismissing the question assigns nothing`; `no active diver saves without asking`; `a draft is not asked about, and its dives join the trip`.
- [ ] **Step 2: Run** the file. Expected: compile failure.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** it and unchanged `trip_detail_page_unlock_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(trips): a new trip opens unlocked on the trip page, behind the switch`.

### Task 22: Trips: routes, pane, openers

**Files:**
- Modify: `lib/features/trips/presentation/pages/trip_edit_routes.dart`, `lib/core/router/app_router.dart` (`newTrip`, with `onExit`), `trip_list_page.dart`, `lib/features/trips/presentation/widgets/trip_list_content.dart`, `trip_summary_widget.dart`
- Test: `test/core/router/app_router_test.dart`, `test/features/trips/presentation/pages/trip_list_page_test.dart`, `test/features/dive_log/presentation/widgets/dive_list_new_trip_test.dart`, `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_trip_rows_test.dart`, `test/features/cylinder_passports/presentation/widgets/passport_trip_card_test.dart`

**Interfaces:**
- Produces: `Widget newTripPage(Object? extra, {bool unlockEditing = kUnlockRecordEditing})` (a `TripDraft` or nothing), `Widget newTripPane(...)`, `Future<void> openNewTrip(BuildContext context, {bool unlockEditing = kUnlockRecordEditing})` (FAB, empty state, summary Add). `newTripFromSelection`, `newTripForDiveEdit` and the Pack card are unchanged: they push the address and already take the id.

- [ ] **Step 1: Write the failing tests**: R1 (a draft carried), R2, R3; with the switch on, Review Focus 4: `New trip from selected dives opens the trip it created`, `a trip created from a dive's Details card is read into the dive's sitting`, `New trip on the Pack card packs for the trip it creates`.
- [ ] **Step 2: Run** the five files. Expected: the new cases fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the five files and `test/features/dive_log/presentation/pages/bulk_dive_edit_new_trip_prefill_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(trips): /trips/new, the pane and the list's Add open the new trip page behind the switch`.

### Task 23: Part D to a green PR

As Task 6, with screenshots of a new trip, a new liveaboard and a trip from selected dives.

### As built (Part D)

Built natively on 2026-11-20. Where the code differs from the tasks above, the code is right:

- `TripEditSaveService.create` takes the trip, its changed cards, the draft's dive ids and the held writes; no `actingDiverId` (the row carries `isShared`, and the sharing write is the sitting's own) and no source trips (they are invalidated after commit). It assigns the draft's dives, then generates a liveaboard's days over the dates as stored then, when the sitting held none. A parent that is a side trip itself is dropped, as the form's create drops it.
- `RecordCreating` gained `beforeCreate(session)`, asked only when the Save would write and before what follows a create is captured: Save on a new record skips `beforeSave`. The trip's is `TripSittingHost.askDivesInDates`, shared with the stored path; a trip made from selected dives (any draft) is never asked, as the form.
- A new trip keeps the diver it was opened for (the active one at Save only when the seed had none), like every other type.
- The page shows its header block, a "Part of" line for its larger trip (`PartOfTripLink.toParent`), and `TripPrepareOverview(tabRows: false)`: the hero from the working dates, the Plan row alone, a liveaboard's Vessel (laid out open as the type changes to it), Notes and Documents. No tab bar, no `PartOfTripLink` by id, no `SharedByBanner`; its sitting loads only its sharing, its vessel (none) and its document links. In a pane its header is the editing row alone.
- `newTripPage(extra)`, `newTripPane` and `openNewTrip` as in the other parts; the summary widget has no Add. The selection, a dive's Details trip row, the trip picker's quick add and the Pack card push `/trips/new` as before and take the popped id, pinned against the real page.

## The forms' create tests

The forms stay until plan 12, so nothing is deleted here. Each create case named by plans 6, 8 and 9 for plan 11, and each found since, has its counterpart: documents (`document_edit_page_test.dart`'s create cases) in Tasks 3 and 4; species (`species_edit_page_test.dart`) in Task 5; buddies (`buddy_edit_cert_fields_test`, `buddy_rankings_form_detail_test`, `buddy_edit_photo_test`, `buddy_contact_import_test`, `buddy_pick_sheet_test`) in Tasks 7 and 8; centres (`dive_center_edit_page_fill_hours_test`, the list and Details card cases) in Task 9; certifications (`certification_edit_name_field_test`, `_credentials_test`, `_instructor_test`, `certification_photo_pick_test`) in Task 10; courses (`course_edit_agency_test`, `course_edit_date_range_test`) in Task 11; gear (`equipment_edit_clone_test.dart` all cases, `_device_type_test`, `_hidden_by_view_test`, `_parent_picker_test`, `_tags_test`, `_advanced_test`'s currency cases) in Tasks 13 to 16; sets (`equipment_set_edit_clone_test.dart` all cases, `equipment_set_edit_page_test`'s new-set cases, `_discard_test`'s new set) in Task 17; trips (`trip_edit_page_test.dart`'s New Trip group, defaults, sharing and save flow, `trip_edit_page_draft_test.dart`, `trip_edit_page_retry_test.dart`) in Tasks 19 to 22. A form case with no counterpart (the trip form's create retry, made needless by call 6) is named in its PR.

## After the plan

- Plan 12 inherits: the nine forms, their create builders behind the switch, and every `unlockEditing` parameter added here.
- Follow-up issues to open with Part B and Part A's PRs: linking a record created from the course picker and the certification picker (Question 5), the trip fill sheet's new centre that creates nothing, and moving the dive and site new-record code onto `RecordCreating` (Question 2).
