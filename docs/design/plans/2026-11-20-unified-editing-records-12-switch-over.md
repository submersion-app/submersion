# Unified Editing, Phase 3, Plan 12: The Records Switch-Over Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn unlock-to-edit on for every build and make it the only way to edit or create a document, species, buddy, dive centre, certification, course, GPS track, underwater track, gear item, passport, equipment set or trip: `kUnlockRecordEditing` goes with every branch on it, the Edit pencils go, the old edit and new addresses open the pages (unlocked, or on a new record), and the nine forms are deleted with the files only they used, their tests (each case accounted for) and their strings. This ends phase 3 of issue #4527.

**Architecture:** As phase 2's plan 7 (#4765) did for sites, across nine types. Part A turns the switch on: each type's `unlockEditing` parameters (pages, `*_edit_routes.dart` helpers, satellites, the gallery, `DocumentsSection`) and the pages' `hostsEditing` overrides go, each reader keeping the branch it took with the switch on; the router's old `edit` builders go, leaving their redirects; the pencils go; then the switch file. The forms are then unreachable but still compile, so Parts B and C delete them type by type, each case of their tests first found pinned by a test of the card, sitting or page that owns the behaviour now (or added there). Part D moves the site's sharing onto the shared `RecordSharingSitting`, which plan 9 placed here.

**Tech Stack:** Flutter, Riverpod 3, go_router 17, drift (test database through `setUpTestDatabase`), `flutter gen-l10n` with 11 ARB locales.

**Spec:** `docs/design/specs/2026-11-18-unified-editing-phase-3-records-design.md`: "Design: rules every phase 3 type follows" (Hosts and routes), "Design: what happens to the forms", "Delivery" item 12. The model is `docs/design/plans/2026-11-19-unified-editing-sites-7-switch-over.md` and its "After the build". Plans 1 to 11 of phase 3 shipped every name used here (the last pieces: #4791, #4795, #4799, #4805, #4807).

## Questions for Eric

The plan is written to the recommended answer of each; a different answer changes only the task named.

1. **One PR or several.** Part A changes about 32 lib files and the roughly 52 test files that pass `unlockEditing`; Parts B and C delete about 8,300 lines of forms and about 70 test files (about 350 form cases to account for) and about 115 strings. **Recommended:** four PRs, stacked as plan 11's were (each cut from the previous one's head, base `main`): A switch on (Tasks 1 to 9), B the six smaller forms (Tasks 10 to 12), C gear item, set and trip forms (Tasks 13 to 15), D the site's sharing (Tasks 16 and 17). Between A and B the forms are in the tree but nothing reaches them, so no type ships with its form reachable (the note's anti-goal). The other way: one PR, as phase 2 did, at about four times phase 2's size.
2. **The Edit pencils.** Every phase 3 page still shows a pencil beside the lock (plans 2 to 11 kept it, "Edit stays until the switch-over"); with the switch on it unlocks as the lock does. **Recommended:** the pencils go from every page's locked bar and every pane header, as phases 1 and 2 did: the lock is the one way in. The other way: keep the pencil as a second unlock control. (Task 4.)
3. **Edit controls outside the pages.** Two lists offer an Edit of their own: the species manage page's row pencil and the certification wallet's "Edit" sheet item. Both push the old address, which now opens the page unlocked. **Recommended:** keep both, pushing `/species/<id>?mode=edit` and `/certifications/<id>?mode=edit` directly, since a list row has no lock to tap. The other way: remove them, so a row opens the page locked. (Task 4.)
4. **The site's sharing onto the shared sitting** (plan 9's Question 11 placed it here). The shared `ItemSharesSharingAdapter` also rewrites stray share rows that a sync race left beside the Everyone flag, with the next Save that changes something; the site's own sitting does not. **Recommended:** move it (Part D) and let sites gain that upkeep, as trips have it. The other way: the site keeps an adapter that never asks for a rewrite. (Task 16.)
5. **Plan 11's three follow-up issues were never opened** (linking a record created from the course and certification pickers; the trip fill sheet's "new centre" that creates nothing; moving the dive and site new-record code onto `RecordCreating`). **Recommended:** I open them as issues with Part A's PR, and build none of them here. The other way: fold any into this plan.
6. **Where the manual test runs.** Phase 2's was run on the iOS Simulator with a copy of your database in the simulator's own container. A simulator that once had Submersion installed may still hold its keychain items (iOS keeps them after an app is deleted), and the "iPhone Air" simulator has Submersion installed now. **Recommended:** I create two throwaway simulators, an "iPhone 17 Pro" and an "iPad Pro 11-inch (M5)" on iOS 26.5, so nothing in them has ever signed in to a cloud store, put a copy of your database in each app container, run Task 8 on both (phone layout and the list panes), and delete the simulators and the copies afterwards. Never a macOS dev build while your sync is set up. The other way: an empty database with test records I create by hand (no copy of your log leaves its folder, but the paths with real gear, trips and passports get thin data). (Task 8.)
7. **Which paths by hand.** **Recommended:** Task 8's list: each type's lock, unlock, a card change, Save with one History entry and its revert, Cancel, a new record and the clones, the old addresses, the panes on the iPad, the passports and the cylinder board as satellites, and buddy merge. Not tried by hand, left to their tests: an NFC tag scan and label printing (no NFC in the simulator), Lightroom (behind `lightroomUiEnabled`), the dive computer's clock sync and auto-download (no computer). Tell me any path to add or drop. (Task 8.)

## Calls made in this plan, for Eric to check

Each follows phase 2's plan 7, which you confirmed for sites, or the phase 3 note.

1. **The old addresses stay** and always redirect: `/<type>/:id/edit` to `/<type>/:id?mode=edit` for buddies, dive centres, certifications, courses, documents, species, gear items and sets; `/trips/:id/edit` keeps its `section` and `noteDay` (the trip page opens unlocked at that card). The routes keep no builder, as `editSite` has none.
2. **The list panes keep their `editBuilder` slot**, as the site list does: it builds the page unlocked (`<type>EditPane`), so `&mode=edit` and table mode's edit keep opening the record unlocked in the pane. The note's "the editBuilder goes" is read as "the form's builder goes".
3. **The buddy favourite star** on the list rows, the picker and the bar shows state only (`BuddyFavoriteButton` loses `readOnly` and its write); the favourite is set on the header block.
4. **Dead code goes with the switch**: `openTripEdit`, each `readOnly` or `onEdit...` parameter that every remaining caller now passes the same value to, and each immediate writer that only a switch-off branch called. A widget parameter still given both values (a widget the dive page also uses, such as the rental notes card) stays.
5. **Four equipment files only the forms use are deleted** with them: `unsaved_changes_scope.dart`, `equipment_location_field.dart`, `data/services/initial_location.dart` and `helpers/equipment_set_history_save.dart`, with their tests. Everything else the forms import is used by a card editor, the merge page or a page.
6. **Strings only the deleted code used are removed** from all 11 ARB files, by plan 7's rule: a key goes only if `lib/` referenced it before the deletion and references it no more. The survey expects about 115 of the forms' own keys plus the pencils' tooltips.
7. **Every old form test is accounted for**: each case is found pinned by a test of the card, sitting or page that owns the behaviour now, or a case is added there (watched failing against a mutation of the behaviour first) before the old file goes. Plans 4, 6, 8 and 9 already mapped their forms' edit cases and plan 11 the create cases; Parts B and C confirm those and map the rest. The per-case table is written into this plan's "After the build".
8. **No open issue is closed** by this plan: none of the 142 open issues is about the old forms (#1987, a buddy name prefilled from an empty picker search, is not done by the new page either, and stays open). Every PR says `Refs #4527`, which stays open for phase 4.

## Not in this plan

- Phase 4 (editors with no read page).
- Plan 11's three follow-ups (Question 5) and phase 2's left-open minors.
- Moving the dive and site pages onto `RecordCreating`.

## Global Constraints

- Every single-record edit of these types is a sitting: one Save, one transaction, one change log operation, as plans 1 to 11 built. Nothing here changes what a sitting holds or writes, except Part D's sharing upkeep (Question 4).
- Buddy merge (`/buddies/merge`, `BuddyMergePage`) builds and merges exactly as today.
- No file over 800 lines. `app_router.dart` (2,803) and any page already over must not grow.
- **Shared files.** Part A changes `lib/shared/widgets/record_editing/` only by deleting `unlock_record_editing_flag.dart`. Part D adds nothing under `lib/shared/`.
- Anything that acts after an `await` checks `mounted`, and reads `ref` and `context` before its first `await`.
- Every value shown or typed follows the active diver's units.
- Never an em-dash or en-dash as punctuation; nothing names the coding assistant or its maker.
- Test commands name test FILES by path, at most 15 per run, never a folder, `test/architecture/` or `test/shared/` as a folder. The architecture guards (`markdown_notes_adoption_test.dart` and `number_parsing_single_source_test.dart` name form paths) are edited but run by the pre-push hook, not by hand.
- `dart format` the changed files before each commit. Merge `origin/main` before each push and run the whole-repo `flutter analyze` after each merge.

## Review Focus

1. **An old bookmark to a deleted record** (`/buddies/<gone>/edit`, and each other type's): the redirect lands on the page, which shows not found, stays locked and throws nothing. Test in Task 5.
2. **A trip's old address with a section or a day** (`/trips/<id>/edit?section=planning`, `?section=notes`, a `noteDay` pair, and a malformed `noteDay`): the page opens unlocked at that card, or unlocked with no card for the malformed one. Test in Task 5.
3. **The list panes on a wide screen** (`?selected=<id>&mode=edit` for each list with a pane, the equipment sets pane, and table mode's edit): the record opens unlocked in the pane, with no pencil; its Cancel with changes asks. Test in Task 5.
4. **A document added from another record's Documents card during a sitting**: always the document's new-record page now; its Save creates the document as Personal and the link stays held, so a Cancel of the owner leaves the document and no link. Test in Task 1.
5. **A buddy's star on a list row, the picker and the bar**: a tap writes nothing. Test in Task 4.

## Preparation

- Worktree: `git submodule update --init --recursive`, `flutter pub get`, branch from `origin/main` at or after `ca2fc04` (#4807).
- Before any code changes, take the "before" pictures by the widget-golden route (headless `flutter test`, as plans 2 to 11 did): each type's locked bar with its lock and pencil at phone and desktop width, a list pane header with its pencil (buddies, gear, trips), and one form (the trip form) as the old address opened it with the switch off.

## File Structure

| Files | Change |
| --- | --- |
| `lib/shared/widgets/record_editing/unlock_record_editing_flag.dart` | Deleted (Task 5) |
| Each type's `*_detail_page.dart`, `*_detail_page_editing.dart` and parts (documents, species, buddies, dive centres, certifications, courses, GPS track, underwater track and align page, gear item, both passports, sets, trip, cylinder board, gallery, photos tab) | `unlockEditing` and the `hostsEditing` override go; each reader keeps its switch-on branch (Tasks 1 to 3) |
| Each type's `*_edit_routes.dart` (buddies, centres, certifications, courses, documents, species, equipment, sets, trips) | `unlockEditing` goes; `<type>EditLocation` returns `String`; the form branches go (Tasks 1 to 3) |
| `lib/features/documents/presentation/widgets/documents_section.dart` | Always the new-record page (Task 1) |
| `lib/features/trips/presentation/helpers/trip_edit_navigation.dart` | `openTripEdit` goes; `TripEditSection` and the note-day helpers stay (Task 3) |
| `lib/features/buddies/presentation/widgets/buddy_favorite_button.dart` and its four callers | Shows state only (Task 4) |
| `lib/core/router/app_router.dart` | The nine `edit` builders go, their redirects stay (Task 5) |
| `docs/user/{buddies-and-dive-centers,certifications-and-courses,equipment,trips,marine-life-and-photos,gear-tags}.md` | Describe the lock (Task 6) |
| The nine forms | Deleted (Tasks 10, 11, 13, 14) |
| `lib/features/equipment/presentation/widgets/{unsaved_changes_scope,equipment_location_field}.dart`, `lib/features/equipment/data/services/initial_location.dart`, `lib/features/equipment/presentation/helpers/equipment_set_history_save.dart` | Deleted with their tests (Tasks 13, 14) |
| `lib/features/dive_sites/presentation/editing/site_sharing_sitting.dart` | Reduced to a `RecordSharingSitting` and the library rule (Task 16) |

---

## Part A: the switch on (PR A)

### Task 1: Documents, species, buddies, dive centres, certifications and courses without the switch

**Files:**
- Modify: the six types' detail pages, `*_detail_page_editing.dart` parts and `*_edit_routes.dart`; `documents_section.dart`; `species_manage_page.dart` and `certification_wallet_page.dart` (only the pushed address, Question 3)
- Test: each type's `*_edit_routes_test.dart`, `*_detail_page_unlock_harness.dart`, `*_detail_page_unlock_test.dart`, `*_detail_page_new_test.dart`, and every other test file under these six features that passes `unlockEditing:` (find them with `grep -rln "unlockEditing" test/features/{documents,marine_life,buddies,dive_centers,certifications,courses}`)

**Interfaces:**
- Produces, for `<type>` in `document`, `species`, `buddy`, `diveCenter`, `certification`, `course`: `String <type>EditLocation(String id)` (never null), `<type>EditPane(...)` building `<Type>DetailPage(... openUnlocked: true ...)` as its switch-on branch did, `new<Type>Page(...)`, `new<Type>Pane(...)`, `openNew<Type>(...)` with `openCreated` always true; each without `unlockEditing`.
- Produces: each `<Type>DetailPage` constructor without `unlockEditing`; its state no longer overrides `hostsEditing` (the host's default is `true`), and each of its `hostsEditing` or `host != null` reads keeps its switch-on value, the read itself going where it becomes constant.
- Produces: `DocumentsSection` without `unlockEditing`; its add is always `_addOnNewPage`.

- [ ] **Step 1: Change the tests first**: drop every `unlockEditing:` argument; delete each case that pinned the switch off (a route helper answering null or building a form, a page with `unlockEditing: false`) where a switch-on case pins the same entry, and list each deleted case in "After the build". Add Review Focus 4 to `test/features/documents/presentation/widgets/documents_section_test.dart` (create it if missing): `in a sitting, Add opens the new-document page and holds the link`: the owner's sitting unlocked, Add, the new page shows the owner fixed, Save, then the owner's Cancel: the document is stored as Personal and no link row exists.
- [ ] **Step 2: Run** the changed files by path, at most 15 per run. Expected: compile failures for the removed parameter.
- [ ] **Step 3: Implement**: remove the parameters and each switch-off branch as the Interfaces say; the routes files stop importing the forms (`app_router.dart` still builds them until Task 5).
- [ ] **Step 4: Run** the same files. Expected: all pass.
- [ ] **Step 5: Commit** `feat(editing): documents, species, buddies, centres, certifications and courses always edit in place`.

### Task 2: Tracks, gear items, passports and sets without the switch

**Files:**
- Modify: `gps_track_detail_page*.dart`, `nav_track_detail_page*.dart`, `nav_track_align_page.dart`, `nav_track_edit_cards.dart`, `equipment_detail_page*.dart`, `equipment_edit_routes.dart`, `passport_page.dart`, `gear_passport_page.dart`, `open_item_passport.dart`, `equipment_set_detail_page*.dart`, `equipment_set_edit_routes.dart`, `equipment_list_page.dart` (only if an argument goes)
- Test: every test file under `test/features/{gps_log,nav_track,equipment,cylinder_passports,gear_passports}` that passes `unlockEditing:`

**Interfaces:**
- Produces: `gearItemEditLocation(String id)` and `equipmentSetEditLocation(String id)` returning `String`; `gearItemEditPane`, `newGearItemPage`, `newGearItemPane`, `openNewGearItem` and the set's equivalents without `unlockEditing`; `EquipmentSetPaneEditBuilder equipmentSetsPaneEditBuilder()` no longer nullable. (Check each name against `equipment_edit_routes.dart` and `equipment_set_edit_routes.dart`; the names there win.)
- Produces: `GpsTrackDetailPage`, `NavTrackDetailPage`, `NavTrackAlignPage`, `EquipmentDetailPage`, `PassportPage`, `GearPassportPage`, `EquipmentSetDetailPage` without `unlockEditing`. The align page keeps only its switch-on reading: read only unless joined (`_readOnly => _joined == null`), and no 3D save from a locked page.

- [ ] **Step 1: Change the tests first**, as Task 1 Step 1 (no new case).
- [ ] **Step 2: Run** them. Expected: compile failures.
- [ ] **Step 3: Implement**, as Task 1 Step 3.
- [ ] **Step 4: Run** the same files. Expected: all pass.
- [ ] **Step 5: Commit** `feat(editing): tracks, gear, passports and sets always edit in place`.

### Task 3: Trips without the switch

**Files:**
- Modify: `trip_detail_page*.dart`, `trip_cylinder_board_page*.dart`, `trip_gallery_page.dart`, `trip_photos_tab.dart`, `open_trip_cylinder_board.dart`, `trip_edit_routes.dart`, `trip_list_page.dart` (only if an argument goes), `trip_overview_summary_card.dart`, `trip_edit_navigation.dart` (`openTripEdit` goes)
- Test: every test file under `test/features/trips` that passes `unlockEditing:`, and `bulk_dive_edit_new_trip_prefill_test.dart` (the selection's New trip now opens the trip page on a draft; plan 11's `trip_detail_page_new_test.dart` pins the draft, so the case is rewritten to assert the page, not deleted)

**Interfaces:**
- Produces: `String tripEditLocation(String tripId, {TripEditSection? section, TripNoteDay? noteDay})`; `tripEditPane`, `newTripPage(Object? extra)`, `newTripPane`, `openNewTrip` without `unlockEditing`.
- Produces: `TripDetailPage`, `TripCylinderBoardPage`, `TripGalleryPage` without `unlockEditing`. `TripDetailTabs.onEditPlan` and `onEditDayNote` lose the form branch; a parameter every caller now gives the same value goes (call 4).

- [ ] **Step 1: Change the tests first**, as Task 1 Step 1; the gallery's switch-off cases (a Scan from a locked trip) are deleted where the gallery's unlock cases pin that a locked trip offers no scan.
- [ ] **Step 2: Run** them. Expected: compile failures.
- [ ] **Step 3: Implement**, as Task 1 Step 3, and delete `openTripEdit` with its test cases.
- [ ] **Step 4: Run** the same files. Expected: all pass.
- [ ] **Step 5: Commit** `feat(trips): a trip always edits in place`.

### Task 4: No Edit pencils; the buddy star shows state only

**Files:**
- Modify: the locked bars and pane headers holding a pencil: `buddy_detail_page.dart`, `buddy_detail_page_header.dart`, `dive_center_detail_page_editing.dart`, `dive_center_detail_page_body.dart`, `certification_detail_page.dart`, `course_detail_page.dart`, `document_detail_page.dart` (`_edit` goes), `species_detail_page.dart`, `trip_detail_page.dart`, `equipment_detail_page.dart`, `equipment_set_detail_page_sections.dart` (the pencil, and the empty set's "Add equipment" button, which pushed the form: it now unlocks with Members open); `buddy_favorite_button.dart` and its callers (`buddy_list_tile.dart`, `compact_buddy_list_tile.dart`, `dense_buddy_list_tile.dart`, `buddy_picker.dart`)
- Test: each type's `*_detail_page_unlock_test.dart`; `test/features/buddies/presentation/widgets/buddy_favorite_button_test.dart` (create if missing); the list-tile tests that tapped the star

**Interfaces:**
- Produces: `BuddyFavoriteButton({Key? key, required String buddyId, required bool isFavorite})`: the `readOnly: true` rendering it has today, always; the `toggleFavorite` call goes.

- [ ] **Step 1: Write the failing tests:**
  - In each of the nine `*_detail_page_unlock_test.dart` files: `the locked bar has the lock and no Edit pencil` (full page, and the pane header where the type has a pane): no `Icons.edit`/`Icons.edit_outlined` button and no button with the type's edit tooltip.
  - `equipment_set_detail_page_unlock_test.dart`: `an empty set's Add equipment unlocks with Members open`.
  - Review Focus 5, `buddy_favorite_button_test.dart`: `a tap writes nothing`: the star in a list tile, the picker and the bar; tap; `BuddyListNotifier.toggleFavorite` is never called (a fake notifier records calls) and the star is unchanged.
  - Question 3: `species_manage_page_test.dart` `the row's Edit opens the species unlocked` (the pushed location is `/species/<id>?mode=edit`); `certification_wallet_page_test.dart` the same for the wallet's Edit.
- [ ] **Step 2: Run** those files. Expected: the new cases fail on the pencils, the star's write and the pushed address.
- [ ] **Step 3: Implement**: remove each pencil and the code only it reached; the star loses `readOnly` and its write; the two row Edits push `?mode=edit`.
- [ ] **Step 4: Run** the same files. Expected: all pass.
- [ ] **Step 5: Commit** `feat(editing): the lock is the one way in on every record page`.

### Task 5: The old addresses open the pages; the switch file goes

**Files:**
- Delete: `lib/shared/widgets/record_editing/unlock_record_editing_flag.dart`
- Modify: `lib/core/router/app_router.dart` (the nine `edit` routes keep only `redirect`; the nine form imports go), `test/shared/widgets/record_editing/record_card_ids_test.dart` (its case 'the switch is off by default' goes)
- Test: `test/core/router/app_router_test.dart`, each type's `*_edit_routes_test.dart`, `trip_detail_page_unlock_test.dart`, and the list page tests named in Step 1

**Interfaces:**
- Produces: `GoRoute(path: 'edit', name: 'edit<Type>', redirect: <type>EditRedirect)` with no builder, for `editBuddy`, `editDiveCenter`, `editCertification`, `editCourse`, `editDocument`, `editEquipment`, `editEquipmentSet`, `editTrip`, and `GoRoute(path: ':speciesId/edit', name: 'editSpecies', redirect: speciesEditRedirect)`.

- [ ] **Step 1: Write the failing tests:**
  - `app_router_test.dart`: `every old edit address opens the page unlocked`: for each of the nine routes, the route has no builder, and `<type>EditLocation('x1')` is `/<path>/x1?mode=edit`; the cases that cast an edit route's page to a form now cast to the detail page.
  - Review Focus 1, in each `*_detail_page_unlock_test.dart`: `an old edit address for a deleted record shows not found, locked` (a router at `/<path>/gone/edit`).
  - Review Focus 2, `trip_detail_page_unlock_test.dart`: `the old address opens unlocked at its section or day` (`?section=planning` opens Plan, `?section=notes` opens Notes, a `noteDay` pair opens that Day plan, a malformed `noteDay` opens unlocked with no card).
  - Review Focus 3, in `buddy_list_page_test`, `dive_center_list_page_test`, `certification_list_page_test`, `course_list_page_test`, `documents_pages_test`, `trip_list_page_test`, `equipment_list_page_test`: `the pane's edit address opens the record unlocked, with no pencil` (master-detail `?selected=<id>&mode=edit`, and table mode's edit where the list has one; the equipment sets pane too), and `its Cancel with a change asks first`. Each case in these files that expected a form now expects the page.
- [ ] **Step 2: Run** those files. Expected: the new cases fail on the builders.
- [ ] **Step 3: Implement**: drop the nine builders and the form imports; delete the switch file and its test case; `grep -rn "kUnlockRecordEditing\|unlockEditing" lib test` must print nothing outside `dive_sites` and `dive_log` (which carry their own names).
- [ ] **Step 4: Run** the same files, then `flutter analyze` on the whole repo. Expected: all pass; no issues (the forms still compile, unreferenced).
- [ ] **Step 5: Sweep dead code** (call 4): for each parameter and writer the switch-off branches fed, `grep` its remaining callers; remove what every caller now gives one value, keeping widgets the dive or site pages still drive both ways. Run the touched widgets' test files. Commit `refactor(editing): drop what only the switch-off pages used`.
- [ ] **Step 6: Commit** `feat(editing): old edit addresses open the record unlocked; the phase 3 switch is gone`.

### Task 6: User docs describe the lock

**Files:**
- Modify: `docs/user/buddies-and-dive-centers.md` (lines 18 and 114, "open the edit form"), `docs/user/certifications-and-courses.md`, `docs/user/equipment.md` (line 172, "open its edit form"), `docs/user/trips.md` (lines 38, 132, 136, the pencil icon), `docs/user/marine-life-and-photos.md` (lines 30 to 39), `docs/user/gear-tags.md` (line 73, "on its edit")

- [ ] **Step 1:** Rewrite each passage in `dive-sites.md`'s words: a new record opens on its own page, unlocked, with a card for each part; to change one, open it and tap the lock (in the top bar on a phone, in the pane's header on desktop), open the cards with their pencils, tap **Done**, then **Save**; **Cancel** discards. Check every other passage in those files that names a field "on the form".
- [ ] **Step 2:** `python3.14 scripts/check_docs_links.py`. Expected: passes.
- [ ] **Step 3: Commit** `docs(editing): describe unlocking a record in the user guide`.

### Task 7: Push through the hook and fix what it finds

- [ ] **Step 1: Merge `origin/main`**, then `flutter analyze` on the whole repo. Expected: no issues.
- [ ] **Step 2: Push** the branch (no pull request yet). The hook runs the affected tests: tests that pumped a phase 3 page with the default, which was the switch off, fail here.
- [ ] **Step 3: For each failing file**, by path: a case that pinned a switch-off control (a pencil, a form, an immediate write on a locked page) is deleted where an unlock test pins the same control with the lock (listed in "After the build"), otherwise rewritten to unlock first. Run the files fixed, at most 15 per run, then push again until the hook passes. Touch no lib/ or test/ file while a push runs.
- [ ] **Step 4: Commit** each round as `test(editing): unlock first where tests assumed the switch off`.

### Task 8: Try every path by hand

On the route Question 6 settles (recommended: two simulators created for this test, a copy of the database in each app container, nothing signed in to a cloud store). Never on the live database, and never a dev build on Eric's macOS account while his sync is set up. A failure found here gets a test that fails first, then the fix, before the pull request.

- [ ] **Each type** (document, species, buddy, dive centre, certification, course, GPS track, underwater track, gear item, set, trip): opens locked, the lock in the bar (phone) or the pane header (iPad), no pencil; unlock, change two cards, Save: one History entry; revert it from History and every value returns; Cancel with a change asks and Discard writes nothing.
- [ ] **New records**: each type's Add (phone and iPad pane), a buddy and a centre from a dive's pickers (the dive gets them), a trip from selected dives, a gear item's Clone and Add part, a set's Clone; Cancel untouched leaves without asking.
- [ ] **Satellites**: a cylinder passport and a gear passport opened alone (own lock, Save writes one entry on the item) and from an unlocked item (Done); the cylinder board from a locked and an unlocked trip; the align page from an unlocked track.
- [ ] **Buddy merge** from the list's selection: cycle a field, Merge, Undo.
- [ ] **Old addresses** through the iPad's router: `/buddies/<id>/edit` (and each type's), `/trips/<id>/edit?section=planning`, a deleted record's address.
- [ ] **Not tried by hand** (Question 7): NFC scan and labels, Lightroom, a dive computer's sync settings: named in the PR.
- [ ] **Record** each result in the PR's Test Plan; delete the simulators and the database copies.

### Task 9: PR A

- [ ] **Step 1:** "After" pictures by the widget-golden route, matching Preparation's: each locked bar with the lock alone, a pane header, `/trips/<id>/edit` landing unlocked. Attach before and after through the project's current secret screenshot gist (`gh gist list --limit 1000 | grep "PR screenshots: submersion-app/submersion"`, the highest number; roll over at 75 MB).
- [ ] **Step 2:** `/code-review` with `--max-findings all`; fix every valid finding, test first.
- [ ] **Step 3:** `gh pr create`, title `feat(editing): unlock to edit every record, everywhere (Unified Editing, phase 3)`, body `Refs #4527`, the Test Plan from Task 8, the screenshots; open Question 5's three issues and link them. Turn Auto-fix on.

---

## Part B: the six smaller forms (PR B, cut from A's head)

### Task 10: Delete the document, species and course forms

**Files:**
- Delete: `document_edit_page.dart`, `species_edit_page.dart`, `course_edit_page.dart`, and the old tests in the table below
- Modify: `test/architecture/markdown_notes_adoption_test.dart` (its entries naming these forms; not run by hand), the ARB files and `flutter gen-l10n` (call 6), `document_page_capture.dart` (its comment naming the certification form, in Task 11)

- [ ] **Step 1: List** each old file's cases (`grep -n "test(\|testWidgets("`) into "After the build" as you go.
- [ ] **Step 2: For each case**, find the passing case that pins it in the files the table names; where none does, write one there, watch it fail against a mutation of the behaviour, then pass. Run each touched file by path, at most 15 per run.
- [ ] **Step 3: Delete** the three forms and their old tests.
- [ ] **Step 4: Remove the strings** only the deleted code used from all 11 ARB files (a script listing `l10n.<key>` in the deleted files and grepping the rest of `lib/`, as phase 2 did); `flutter gen-l10n`.
- [ ] **Step 5: Run** `flutter analyze` on the whole repo. Expected: no issues. Then the files of Step 2, by path.
- [ ] **Step 6: Commit** `feat(editing): the document, species and course forms are gone`.

### Task 11: Delete the buddy, dive centre and certification forms

**Files:**
- Delete: `buddy_edit_page.dart`, `dive_center_edit_page.dart`, `certification_edit_page.dart` (with the staging mode only the buddy form used), and the old tests in the table below
- Modify: `test/architecture/markdown_notes_adoption_test.dart`, `test/architecture/number_parsing_single_source_test.dart` (the dive centre form's entry), `buddy_merge_form_controller.dart` and `document_page_capture.dart` (comments naming the forms), the ARB files

- [ ] **Steps 1 to 6** as Task 10. Commit `feat(editing): the buddy, dive centre and certification forms are gone`.

### Task 12: PR B

- [ ] Merge `origin/main` (A merged or not), whole-repo analyze, push through the hook, `/code-review --max-findings all` and every valid finding fixed, `gh pr create` with `Refs #4527` and "No visible UI change" ticked (the forms are unreachable since A), Auto-fix on.

## Part C: gear items, sets and trips (PR C, cut from B's head)

### Task 13: Delete the gear item and set forms

**Files:**
- Delete: `equipment_edit_page.dart`, `equipment_set_edit_page.dart`, `widgets/unsaved_changes_scope.dart`, `widgets/equipment_location_field.dart`, `data/services/initial_location.dart`, `helpers/equipment_set_history_save.dart` (call 5), and the old tests in the table below, with `equipment_location_field_test.dart`, `initial_location_test.dart`, `equipment_set_history_save_test.dart`, and the `EquipmentLocationField` case of `location_picker_callers_test.dart`
- Modify: the ARB files

- [ ] **Steps 1 to 6** as Task 10. Commit `feat(equipment): the gear item and set forms are gone`.

### Task 14: Delete the trip form

**Files:**
- Delete: `trip_edit_page.dart` and the old tests in the table below
- Modify: `test/architecture/markdown_notes_adoption_test.dart`, the ARB files

- [ ] **Steps 1 to 6** as Task 10. Commit `feat(trips): the trip form is gone`.

### Task 15: PR C

- [ ] As Task 12; the body says `Refs #4527` (call 8).

## Part D: the site's sharing on the shared sitting (PR D, cut from main)

### Task 16: Site sharing through `RecordSharingSitting`

**Files:**
- Modify: `lib/features/dive_sites/presentation/editing/site_sharing_sitting.dart`, `site_sitting_start.dart`, `site_new_sitting.dart`, `site_header_card_editor.dart`, `site_detail_page.dart`
- Test: `test/features/dive_sites/presentation/editing/site_sharing_sitting_test.dart`, `site_new_sitting_test.dart`, `site_header_card_editor_test.dart`, `site_detail_page_collections_test.dart`, `test/features/dive_sites/data/services/site_edit_save_census_test.dart`

**Interfaces:**
- Produces: `final siteSharing = RecordSharingSitting<DiveSite, ItemSharing>(key: siteSharingKey, cardId: siteHeaderCardId, recordIdOf: (site) => site.id)`, as `tripSharing` is built.
- Produces: `Future<void> loadSiteSharing(EditSession<DiveSite> session, ProviderRead read, {String? actingDiverId})`: a library site reads nothing (as today), else `siteSharing.load(session, ItemSharesSharingAdapter(read(itemSharesRepositoryProvider), SharedItemKind.site), actingDiverId: actingDiverId, newRecordSharing: ItemSharing(everyone: session.stored.isShared))`. `siteSharingInSitting`, `siteSharingLoaded`, `siteSharingUnread` and `setSiteSharing` go; callers use `siteSharing.inSitting`, `.loaded`, `.unread`, `.set`.

- [ ] **Step 1: Write the failing test** in `site_sharing_sitting_test.dart`: `stray share rows beside Everyone are rewritten with the next Save that changes something` (Question 4): a site stored as everyone with a stray row for `other`; change the notes, Save: the row is gone; a Save with no change writes nothing. The file's other cases move to the new names with their assertions unchanged.
- [ ] **Step 2: Run** the five files. Expected: compile failures, then the new case fails.
- [ ] **Step 3: Implement** as the Interfaces say.
- [ ] **Step 4: Run** the five files. Expected: all pass.
- [ ] **Step 5: Commit** `refactor(sites): a site's sharing uses the shared sharing sitting`.

### Task 17: PR D

- [ ] Merge `origin/main`, whole-repo analyze, push through the hook, `/code-review --max-findings all` with every valid finding fixed, `gh pr create` with `Refs #4527` and "No visible UI change" ticked, Auto-fix on.

---

## The old tests and where their behaviour lives now

Counts are `test(`/`testWidgets(` matches. "Plan N" means that plan's table already maps the case; Step 2 confirms it. Files marked *mixed* keep their other cases and only the form cases change (in Tasks 5 and 7 for routing and lists, in Parts B and C for the rest).

| Old test | Cases | Pinned now by |
| --- | --- | --- |
| `document_edit_page_test` | 20 | Plan 2 (`document_edit_fields_test`, `record_document_links_sitting_test`, `document_pages_card_editor_test`, `document_detail_page_unlock_test`); create cases plan 11 (`document_new_sitting_test`, `document_detail_page_new_test`) |
| `document_tags_ui_test` (*mixed*), `documents_pages_test` (*mixed*) | 4, 18 | `document_edit_fields_test` (tags written once loaded), `documents_pages_test` itself |
| `species_edit_page_test` | 5 | Plan 11 (`species_detail_page_new_test`), plan 2 (`species_detail_page_unlock_test`, lookup) |
| `course_edit_agency_test`, `_embedded_save_test`, `_date_range_test`, `_certifications_test`, `_instructor_test` | 2, 2, 2, 3, 4 | Plan 4's table (`course_card_editors_test`, `course_certifications_sitting_test`, `instructor_card_editor_test`, `course_detail_page_unlock_test`); create cases plan 11 |
| `buddy_edit_photo_test`, `buddy_edit_cert_fields_test`, `buddy_edit_country_test`, `buddy_social_handle_test`, `buddy_edit_keeps_card_fields_test`, `buddy_edit_linked_profile_test`, `buddy_contact_import_test`, `buddy_picker_navigation_render_test` | 5, 5, 5, 3, 1, 5, 3, 2 | `buddy_contact_card_editor_test`, `buddy_certification_dialog_test`, `buddy_certifications_card_editor_test`, `buddy_edit_fields_test`, `buddy_detail_page_unlock_test`, `buddy_detail_page_new_test` (plan 11 for photo, contacts and picker cases). Plan 3 left no table: most cases are mapped here |
| `buddy_rankings_form_detail_test` (*mixed*) | 7 | Its detail cases stay; form cases to `buddy_detail_page_unlock_test` (rankings switch on Statistics) |
| `dive_center_edit_page_fill_hours_test`, `_logo_test`, `_closed_test` | 8, 3, 2 | `dive_center_header_card_editor_test`, `dive_center_edit_fields_test` (`fillHoursProblem`), `dive_center_detail_page_unlock_test`; create cases plan 11 |
| `certification_edit_custom_entries_test`, `certification_photo_pick_test`, `_instructor_test`, `_name_field_test`, `_credentials_test`, `_agency_level_test`, `_page_staging_test`, `_hidden_tab_test`, `_embedded_header_test` | 6, 3, 6, 15, 5, 14, 2, 2, 1 | `certification_card_editors_test`, `certification_edit_fields_test`, `instructor_card_editor_test`, `buddy_certification_dialog_test` (staging), `certification_detail_page_unlock_test`; create cases plan 11. Plan 3 left no table |
| `equipment_edit_advanced_test`, `_price_locale_test`, `_colour_test`, `_tags_test`, `_type_order_test`, `_save_navigation_test`, `_hidden_by_view_test`, `_device_type_test`, `_service_section_test`, `_wanted_test`, `_parent_picker_test` | 8, 5, 4, 7, 1, 3, 6, 5, 2, 3, 7 | Plan 6's table (`gear_item_header_editor_test`, `gear_item_details_editor_test`, `gear_item_edit_fields_test`, `equipment_detail_page_unlock_test`); create cases plan 11 |
| `equipment_edit_clone_test` | 18 | Plan 11 (`gear_item_new_sitting_test`, `equipment_detail_page_new_test`) |
| `equipment_set_edit_page_test`, `_discard_test`, `_folds_test`, `_figure_test`, `_assembly_parts_test`, `_history_test` | 12, 7, 2, 11, 3, 6 | Plan 8's table (`equipment_set_members_editor_test`, `equipment_set_card_editors_test`, `equipment_set_detail_page_unlock_test`); create cases plan 11 |
| `equipment_set_edit_clone_test` | 9 | Plan 11 (`equipment_set_detail_clone_test`, `equipment_set_detail_page_new_test`) |
| `equipment_set_arrangement_test` (*mixed*), `equipment_set_detail_unshared_test` (*mixed*) | 3, 2 | Their page cases stay; form cases to `equipment_set_members_editor_test` |
| `trip_edit_page_test` | 79 | Plan 9's table (edit cases), plan 11 (New Trip group, defaults, sharing, save flow) |
| `trip_edit_page_part_of_test`, `_type_change_test`, `_draft_test`, `_retry_test` | 2, 1, 2, 1 | Plan 9 (part of, type change), plan 11 (draft); the retry case is form only (call 6 of plan 11) |
| `*_edit_routes_test` (nine), `app_router_test`, the list page tests, `trip_list_page_new_trip_test`, `bulk_dive_edit_new_trip_prefill_test` (*mixed*) | | Tasks 1 to 5 and 7 |
| `equipment_location_field_test`, `initial_location_test`, `equipment_set_history_save_test` | | Deleted with their files (call 5); the first location is plan 11's held move (`gear_item_new_sitting_test`), the history replay plan 8's `beforeSave` (`equipment_set_detail_page_unlock_test`) |

---

## After the build

(Filled in while building: names, decisions made while building, and the per-case table: old file, old case, Pinned / Added / Form only, where.)
