# Unified Editing, Phase 3, Plan 12: The Records Switch-Over Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn unlock-to-edit on for every build and make it the only way to edit or create a document, species, buddy, dive centre, certification, course, GPS track, underwater track, gear item, passport, equipment set or trip: `kUnlockRecordEditing` goes with every branch on it, the Edit pencils go, the old edit and new addresses open the pages (unlocked, or on a new record), and the nine forms are deleted with the files only they used, their tests (each case accounted for) and their strings. This ends phase 3 of issue #4527.

**Architecture:** As phase 2's plan 7 (#4765) did for sites, across nine types. Part A turns the switch on: each type's `unlockEditing` parameters (pages, `*_edit_routes.dart` helpers, satellites, the gallery, `DocumentsSection`) and the pages' `hostsEditing` overrides go, each reader keeping the branch it took with the switch on; the router's old `edit` builders go, leaving their redirects; the pencils go; then the switch file. The forms are then unreachable but still compile, so Parts B and C delete them type by type, each case of their tests first found pinned by a test of the card, sitting or page that owns the behaviour now (or added there). Part D moves the site's sharing onto the shared `RecordSharingSitting`, which plan 9 placed here.

**Tech Stack:** Flutter, Riverpod 3, go_router 17, drift (test database through `setUpTestDatabase`), `flutter gen-l10n` with 11 ARB locales.

**Spec:** `docs/design/specs/2026-11-18-unified-editing-phase-3-records-design.md`: "Design: rules every phase 3 type follows" (Hosts and routes), "Design: what happens to the forms", "Delivery" item 12. The model is `docs/design/plans/2026-11-19-unified-editing-sites-7-switch-over.md` and its "After the build". Plans 1 to 11 of phase 3 shipped every name used here (the last pieces: #4791, #4795, #4799, #4805, #4807).

## Questions for Eric

The plan is written to the recommended answer of each; a different answer changes only the task named.

*Eric chose the recommended answer to every question, and accepted every call, on 2026-11-20 ("Yes, as recommended").*

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
| `document_edit_page_test` | 20 | `document_pages_card_editor_test`, `document_detail_page_unlock_test`, `document_edit_save_service_test`, `document_repository_test`, `document_widgets_test`, `document_owner_field_test`, `document_edit_fields_test`; create cases plan 11 (`document_new_sitting_test`, `document_detail_page_new_test`). Part B added the cases plan 2 left out (the lazy strip, type fields, page slots and limits, owners, a Pages save) |
| `document_tags_ui_test` (*mixed*), `documents_pages_test` (*mixed*) | 4, 18 | The form case: `document_detail_page_unlock_test` (a tag typed into Details, added in Part B) and `document_edit_save_service_test` (changed tags are written); the other cases stay in `document_tags_ui_test` and `documents_pages_test` |
| `species_edit_page_test` | 5 | Plan 11 (`species_detail_page_new_test`), plan 2 (`species_detail_page_unlock_test`, lookup), `species_edit_save_service_test`, `record_edit_host_test` |
| `course_edit_agency_test`, `_embedded_save_test`, `_date_range_test`, `_certifications_test`, `_instructor_test` | 2, 2, 2, 3, 4 | Plan 4's table (`course_card_editors_test`, `course_certifications_sitting_test`, `instructor_card_editor_test`, `course_detail_page_unlock_test`), `course_edit_save_service_test`; create cases plan 11 |
| `buddy_edit_photo_test`, `buddy_edit_cert_fields_test`, `buddy_edit_country_test`, `buddy_social_handle_test`, `buddy_edit_keeps_card_fields_test`, `buddy_edit_linked_profile_test`, `buddy_contact_import_test`, `buddy_picker_navigation_render_test` | 5, 5, 5, 3, 1, 5, 3, 2 | `buddy_contact_card_editor_test`, `buddy_header_card_editor_test` and `buddy_country_field_test` (both new in Part B), `buddy_certifications_card_editor_test`, `buddy_certifications_sitting_test`, `buddy_merge_page_test`, `buddy_edit_save_service_test`, `buddy_profile_link_repository_test`, `buddy_detail_page_unlock_test`, `buddy_detail_page_new_test`, `app_router_test`; `buddy_social_handle_test` keeps its detail page case, and `buddy_picker_navigation_render_test` now pushes the new-buddy page. Plan 3 left no table: every case is mapped in "After the build" |
| `buddy_rankings_form_detail_test` (*mixed*; renamed `buddy_rankings_merge_detail_test`) | 7 | Its detail and merge cases stay; the other form cases to `buddy_detail_page_new_test` (a new buddy), `buddy_detail_page_unlock_test` (the Statistics switch, on and off) and `buddy_edit_save_service_test` (an exclusion kept) |
| `dive_center_edit_page_fill_hours_test`, `_logo_test`, `_closed_test` | 8, 3, 2 | `dive_center_edit_fields_test` (`fillHoursProblem`), `dive_center_detail_page_unlock_test`, `dive_center_detail_page_new_test`, `dive_center_edit_save_service_test`, and `dive_center_header_card_editor_test` (logo and closed switch, added in Part B; it held only the rating stars before); create cases plan 11 |
| `certification_edit_custom_entries_test`, `certification_photo_pick_test`, `_instructor_test`, `_name_field_test`, `_credentials_test`, `_agency_level_test`, `_page_staging_test`, `_hidden_tab_test`, `_embedded_header_test` | 6, 3, 6, 15, 5, 14, 2, 2, 1 | `certification_details_custom_entries_test` and `certification_details_levels_test` (the custom entries and agency level files, re-pointed at the Details editor), `certification_photo_pick_test` (rewritten), `certification_card_editors_test`, `certification_edit_fields_test`, `certification_edit_save_service_test`, `certification_unknown_id_test`, `instructor_card_editor_test`, `buddy_certification_dialog_test` (staging), `certification_detail_page_unlock_test`, `certification_detail_page_new_test`, `record_edit_leave_guard_test` (the hidden tab, PR #4829); create cases plan 11. Two cases are form only. Plan 3 left no table |
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

### Part A (built 2026-11-20)

**Decisions made while building.**

- **Pencils went with each page's switch branches** (Tasks 1 to 3), not in a separate Task 4 pass: removing a pencil's switch-off branch left only an unlock button beside the lock. Task 4 then added the cases that pin "the lock and no Edit pencil" on every page and pane; they caught the document and species pencils, which Task 1 had missed.
- **Host references are non-null.** Each page's content widget had a nullable `host` (null meant the switch was off); it is now required, and every `host?.`, `host != null` and `_editing` branch keeps its switch-on side.
- **The empty equipment set's "Add equipment" button is gone**, not turned into an unlock: it only ever showed with the switch off, and the Members card always shows its pencil.
- **The buddy star shows state only everywhere**: `BuddyFavoriteButton` lost `readOnly` and its write. A tap on a list row's star now opens the buddy, as a tap on the row does.
- **The underwater track's read cards lost their actions** (Choose or Change dive, site and device): only the switch-off page passed them. `NavTrackActionCard` lost `actionLabel`, `onAction` and `actionKey`.
- **The align page lost its own Save** and the save before 3D: it edits only in its track's sitting (Done) and reads only otherwise.
- **The GPS page lost its trim mode** (Trim and Reset trim in the menu, the trim panel's Apply); the Trim card holds trims.
- **The trip page lost the menu's scans** (they are on the Dives and Photos cards), `openTripEdit` and the `onEditPlan` chain through `TripDetailTabs`, `TripOverviewTab`, `TripPrepareOverview` and `TripOverviewSummaryCard`, and the gallery's immediate scan.
- **`openNewRecord` lost `openCreated`**, which only the switch-off openers passed (shared code).
- **Thirty strings went** (Task 5's sweep), by plan 7's rule: the pencils' tooltips, the set menu's figure and default items, the gallery scan's messages, the GPS trim item, the track rename and the course's Mark completed dialog.
- **The write-at-once modes stay for a follow-up PR** (decided 2026-11-20). About fourteen widgets (the buddy Gear card, rental gear, certification currency, course requirements, the sharing row and others) still keep a mode that writes at once, and `scanForTripDives` stays; no page reaches them now, but their own tests still drive them. Removing them, and rewriting those tests to the sitting, is its own PR after Part D, so Part A stays the switch-over alone. The PR A review (2026-11-20) found more of the same for that PR: `BuddyListNotifier.toggleFavorite`, `trimTrackProvider`, `EquipmentSetListNotifier.setShowFigure`, `EquipmentHeaderStatus`'s Mark purchased (`offerPurchase` is always false) and `trip_scan_actions.dart`'s `scanGalleryForTripPhotos` and `scanLightroomForTrip`, each kept alive only by its own tests; and `RecordEditHost.hostsEditing`, which no page overrides now, so its branches in the shared host are dead (shared code, outside Part A's constraint).
- **The write-at-once sweep is held for Eric** (call 4): about 14 widgets (`CourseRequirementsSection`, `RentalGearSection`, `CertificationCurrencySection`, `ServiceClocksCard`, `ServiceHistorySection`, `ObservationsCard`, `EquipmentPhotosSection`, `EquipmentLocationCard`, `EquipmentDocumentsSection`, `EquipmentSharingRow`, `BuddyGearSection`, `EquipmentHeaderStatus`'s `offerPurchase`, `DocumentDetailsPanel`'s `showReminder` and others) keep a write-at-once mode no caller reaches, and some helpers have no caller left (`showLendGearFlow`, `showEquipmentReturnFlow`, `scanGalleryForTripPhotos`, `scanLightroomForTrip`, `SpeciesPhotoImportHelper.importPhotosForSpecies`, `StoredRequirementActions`, `trimTrackProvider`). Their own widget tests exercise those modes and the sheets they share with the held paths, so removing them means porting those tests.
- **The hook round** (Task 7) found 159 failing cases in 24 files that pumped a page with the switch's old default. Record operations unlock first; the align page test works through its track's sitting; the board and ledger tests hold their changes until Save; the stars only show. A case that pinned a write-at-once action, a pencil, a form or a moved menu item went where an unlock, sitting or card editor test pins the held behaviour (table below).
- **Review Focus**: 1 by `test/core/router/old_edit_address_deleted_record_test.dart` (all nine types); 2 by `trip_edit_routes_test` ("the old address ... lands on ..."); 3 by the list tests' pane and table-mode cases (now the page) and each unlock test's "the pane header has the lock and no Edit pencil"; 4 by `documents_section_test` "the owner's Cancel keeps the Personal document and links nothing"; 5 by `buddy_favorite_button_test`, `buddy_detail_page_test` and the three list tile tests.

**Test cases removed in Part A** (switch-off, write-at-once, pencil or form cases; each one's held or locked behaviour is pinned by the type's unlock, sitting or card editor tests):

| Test file | Case removed |
| --- | --- |
| `buddies/presentation/pages/buddy_detail_page_unlock_test.dart` | with the switch off there is no lock and the star toggles |
| `buddies/presentation/pages/buddy_detail_page_unlock_test.dart` | the menu offers Lend with the switch off |
| `dive_centers/presentation/pages/dive_center_detail_page_unlock_test.dart` | with the switch off there is no lock |
| `dive_centers/presentation/pages/dive_center_detail_page_unlock_test.dart` | with the switch off, Delete is offered as before |
| `certifications/presentation/pages/certification_detail_page_unlock_test.dart` | with the switch off there is no lock |
| `certifications/presentation/pages/certification_detail_page_unlock_test.dart` | with the switch off, Delete is offered as before |
| `courses/presentation/pages/course_detail_page_unlock_test.dart` | with the switch off there is no lock and Mark completed stays |
| `courses/presentation/pages/course_detail_page_unlock_test.dart` | with the switch off, Delete is offered as before |
| `documents/presentation/pages/document_detail_page_unlock_test.dart` | with the switch off there is no lock |
| `marine_life/presentation/pages/species_detail_page_unlock_test.dart` | with the switch off there is no lock |
| `documents/presentation/pages/documents_pages_test.dart` | on a wide screen, Edit opens the editor in the detail pane |
| `buddies/presentation/widgets/buddy_favorite_button_test.dart` | BuddyFavoriteButton tap target: meets the 48x48 minimum on touch platforms |
| `buddies/presentation/widgets/buddy_favorite_button_test.dart` | BuddyFavoriteButton tap target: keeps a 32x32 floor on pointer-driven desktop |
| `gps_log/presentation/pages/gps_track_detail_page_unlock_test.dart` | with the switch off there is no lock and the menu offers Trim |
| `nav_track/presentation/pages/nav_track_detail_page_unlock_test.dart` | with the switch off there is no lock and Choose dive links at |
| `equipment/presentation/pages/equipment_detail_page_unlock_test.dart` | with the switch off there is no lock and the page is as |
| `equipment/presentation/pages/equipment_detail_page_unlock_test.dart` | with the switch off the chip still buys in one tap |
| `equipment/presentation/pages/equipment_set_detail_page_unlock_test.dart` | with the switch off there is no lock and the menu is |
| `equipment/presentation/pages/equipment_set_detail_page_unlock_test.dart` | the empty Members card keeps Add Equipment with the switch |
| `equipment/presentation/pages/equipment_set_detail_page_unlock_test.dart` | the empty Members card has no Add Equipment button with the |
| `cylinder_passports/presentation/pages/passport_page_unlock_test.dart` | with the switch off the page is as before |
| `gear_passports/presentation/pages/gear_passport_page_unlock_test.dart` | with the switch off there is no lock |
| `equipment/presentation/pages/equipment_set_edit_routes_test.dart` | with the switch off the pane has no edit mode |
| `equipment/presentation/pages/equipment_edit_routes_test.dart` | with the switch off the pane opens the form |
| `trips/presentation/pages/trip_detail_page_unlock_test.dart` | with the switch off there is no lock and the menu is |
| `trips/presentation/pages/trip_detail_page_unlock_test.dart` | with the switch off the Gear and Checklist tabs offer their |
| `trips/presentation/pages/trip_detail_page_photos_test.dart` | with the switch off the Photos tab offers no scan |
| `trips/presentation/pages/trip_detail_page_dives_test.dart` | with the switch off the Dives tab offers no scan |
| `trips/presentation/pages/trip_edit_routes_test.dart` | with the switch off the pane opens the form |
| `trips/presentation/widgets/overview/trip_overview_summary_card_test.dart` | Plan goes to the handler when one is given (#2880) |
| `trips/presentation/helpers/trip_edit_navigation_test.dart` | in the pane, switches the pane to edit mode |
| `trips/presentation/helpers/trip_edit_navigation_test.dart` | as a page, pushes the edit page |
| `trips/presentation/helpers/trip_edit_navigation_test.dart` | as a page, opens the notes at the day |
| `trips/presentation/helpers/trip_edit_navigation_test.dart` | in the pane, opens the notes at the day |
| `trips/presentation/pages/trip_gallery_page_test.dart` | shows camera icon button in app bar |
| `shared/widgets/record_editing/record_card_ids_test.dart` | the switch is off by default |
| `core/router/app_router_test.dart` | trip edit (#2880): openTripEdit pushes the editTrip route |
| `core/router/app_router_test.dart` | trip edit (#2880): editTrip opens the form at the section in the URL |
| `shared/widgets/record_editing/open_new_record_test.dart` | not asked to open what it created, it stays |
| `nav_track/presentation/pages/nav_track_align_page_test.dart` | "Open 3D" saves the in-progress correction before navigating (item 22): pinned the other way by nav_track_align_page_unlock_test 'the 3D button previews the page's correction and writes nothing' |
| `nav_track/presentation/pages/nav_track_detail_page_test.dart` | the site card keeps its label readable |
| `nav_track/presentation/pages/nav_track_detail_page_test.dart` | tapping the action opens the site picker |
| `nav_track/presentation/pages/nav_track_detail_page_test.dart` | picking an existing site in the picker assigns it to the |
| `nav_track/presentation/pages/nav_track_detail_page_test.dart` | creating a new site in the picker pushes /sites/new and assigns the |
| `nav_track/presentation/pages/nav_track_detail_page_test.dart` | creating a new site seeds the form with the route anchor and keeps a |
| `nav_track/presentation/pages/nav_track_detail_page_test.dart` | "Choose dive" pre-selects the sole time-overlapping dive (#2394) |
| `nav_track/presentation/pages/nav_track_detail_page_test.dart` | tapping "Choose dive" and picking one links the route to it |
| `nav_track/presentation/pages/nav_track_detail_page_test.dart` | rename saves the trimmed new name through the repository |
| `nav_track/presentation/pages/nav_track_detail_page_test.dart` | the unlink item only appears for a linked route, and calls |
| `nav_track/presentation/pages/nav_track_detail_page_test.dart` | change device opens the picker and persists the chosen equipment |
| `nav_track/presentation/pages/nav_track_detail_page_test.dart` | change device, choosing "no equipment", clears both fields |
| `nav_track/presentation/pages/nav_track_detail_page_test.dart` | group: on a narrow phone in German (#2692) |
| `nav_track/presentation/pages/nav_track_detail_page_test.dart` | "Change dive" still offers and marks a linked dive that is no longer |
| `nav_track/presentation/pages/nav_track_detail_page_test.dart` | the linked dive card offers a "Change dive" action that re-links to |
| `nav_track/presentation/pages/nav_track_detail_page_test.dart` | "Change dive" writes nothing when the same dive is picked |
| `trips/presentation/pages/trip_cylinder_board_page_test.dart` | a failed slot delete says so and keeps the slot |
| `trips/presentation/pages/trip_cylinder_board_page_test.dart` | a failed reorder says so and puts the slots back |
| `trips/presentation/pages/trip_cylinder_board_page_test.dart` | adding waits until the slots on the trip are known |
| `trips/presentation/pages/trip_cylinder_board_page_test.dart` | saving a day writes its plan to the itinerary |
| `trips/presentation/pages/trip_cylinder_board_page_test.dart` | clearing the plan returns a planned day to blank |
| `trips/presentation/pages/trip_cylinder_board_page_test.dart` | two quick drops never show the older order in between |
| `trips/presentation/pages/trip_cylinder_board_page_test.dart` | a failure before the delete dialog says so |
| `trips/presentation/pages/trip_cylinder_board_page_test.dart` | a failed plan save says so and frees the strip |
| `trips/presentation/pages/trip_cylinder_board_page_test.dart` | the plan count reads as dives to a screen reader |
| `trips/presentation/pages/trip_cylinder_board_page_test.dart` | cancel writes nothing (the forecast strip plan sheet; held in a sitting: trip_cylinder_board_page_unlock_test) |
| `trips/presentation/widgets/cylinders/trip_cylinder_ledger_view_test.dart` | deleting a fill removes its passport copy |
| `trips/presentation/widgets/cylinders/trip_cylinder_ledger_view_test.dart` | a failed delete says so and keeps the entry |
| `trips/presentation/widgets/cylinders/trip_cylinder_ledger_view_test.dart` | a failed passport cleanup keeps the fill to delete again |
| `trips/presentation/pages/trip_detail_page_test.dart` | as a page, opens the edit page at Planning |
| `trips/presentation/pages/trip_detail_page_test.dart` | in the pane, edits in the pane at Planning |
| `trips/presentation/pages/trip_detail_page_test.dart` | app bar edit button pushes to edit route |
| `trips/presentation/pages/trip_detail_page_test.dart` | as a page, opens the edit page at the day note |
| `trips/presentation/pages/trip_detail_page_test.dart` | in the pane, edits the day note in the pane |
| `trips/presentation/pages/trip_detail_page_test.dart` | embedded edit button navigates to edit mode |
| `trips/presentation/pages/trip_detail_page_test.dart` | should display edit icon button |
| `trips/presentation/pages/trip_detail_page_test.dart` | overflow menu runs scan actions |
| `trips/presentation/pages/trip_detail_page_sharing_test.dart` | the owner sees no Shared with row on the page (#3766; reversed by decision 7: the header block shows Shared with to the owner, pinned by trip_header_card_editor_test) |
| `buddies/presentation/pages/buddy_detail_page_test.dart` | Lend gear (issue #3790): reachable from the menu with no gear (embedded, full page): Lend is on the Gear card, pinned by buddy_gear_section_test and buddy_detail_page_unlock_test |
| `cylinder_passports/presentation/pages/passport_page_test.dart` | a failure to track O2 cleaning says so |
| `cylinder_passports/presentation/pages/passport_page_mint_and_delete_test.dart` | a fill deleted from the history is gone |
| `cylinder_passports/presentation/pages/passport_page_mint_and_delete_test.dart` | a double tap on Track O2 cleaning makes one schedule |
| `equipment/presentation/pages/equipment_detail_sharing_test.dart` | tapping Shared with lists the other profiles |
| `equipment/presentation/pages/equipment_set_detail_show_figure_test.dart` | the menu turns the figure on and saves it |
| `equipment/presentation/pages/equipment_set_detail_show_figure_test.dart` | toggling the figure keeps the set |
| `equipment/presentation/pages/equipment_set_detail_show_figure_test.dart` | with the figure on, the menu offers to hide it |
| `equipment/presentation/pages/equipment_set_detail_show_figure_test.dart` | (file deleted: its three cases were the menu's Show and Hide figure, now the Figure card's, pinned by equipment_set_detail_page_unlock_test and equipment_set_card_editors_test) |
| `equipment/presentation/pages/equipment_set_detail_default_test.dart` | offers "Set as default" only when not already default |
| `equipment/presentation/pages/equipment_set_detail_geofence_test.dart` | "Set as default" action promotes the set |
| `gps_log/gps_track_edit_mode_test.dart` | Trim shows a range scrubber and an Apply action (the menu Trim is gone; the Trim card holds trims, pinned by gps_track_detail_page_unlock_test) |
| `gps_log/gps_track_edit_mode_test.dart` | Trim does not warn, because it is reversible |
| `gps_log/gps_track_edit_mode_test.dart` | Reset trim is absent when the track has no bounds (the menu offers no Trim at all: gps_track_detail_page_unlock_test "locked, no tap writes and the menu offers no Trim") |
| `gps_log/gps_track_edit_mode_test.dart` | Reset trim appears once the track has bounds (Reset trim is the Trim card's: "Reset trim is a change of Trim") |
| `gps_log/gps_track_edit_apply_test.dart` | Apply without dragging does not clear an existing trim (the Trim card: "opening the Trim editor and closing it changes nothing") |
| `gps_log/gps_track_edit_apply_test.dart` | Apply without dragging preserves the visible span |
| `gps_log/gps_track_edit_apply_test.dart` | Reset trim still clears both bounds ("Reset trim is a change of Trim") |

### Parts B and C

**Part B: where each old case lives now** (built 2026-11-21). These tables cover Part B only; Part C adds its own below them. Each table is one old test file that Part B deleted, re-pointed or trimmed, with every case by its name before Part B (a group's name leads its cases). `Now` is one of:

- **Pinned**: a test from before Part B already covered it. A case a trimmed file keeps reads "Kept in this file".
- **Added**: a test written or changed in Part B, named with its commit. Each was seen failing against a mutation of the code first.
- **Re-pointed**: the same case now pumps the in-place editor.
- **Form only**: it tested something only the deleted widget had.

Paths are under `test/features/` unless they start with `test/`. A file named without its folder was named with it earlier in the same table.

#### `documents/presentation/pages/document_edit_page_test.dart` (deleted)

| Old case | Now | Where |
| --- | --- | --- |
| stored page content (issue #3847): opening reads only the images the strip builds | Added | `documents/presentation/editing/document_pages_card_editor_test` "a long document reads only the pages the strip builds" (d9fc168) |
| stored page content (issue #3847): saving an edit leaves the stored pages untouched | Pinned | `documents/data/services/document_edit_save_service_test` "a page added underneath survives a details save"; `documents/data/repositories/document_repository_test` "a page without bytes keeps its stored content" |
| insurance shows the phones and the primary toggle | Added | `documents/presentation/widgets/document_widgets_test` "insurance shows its insurer, phones and primary; a permit its issuer and none of them" (ab5e5aa) |
| a first insurance starts as the primary one | Pinned | `documents/presentation/editing/document_new_sitting_test` "a first insurance seeds primary, a second does not"; `documents/presentation/pages/document_detail_page_new_test` "an insurance is saved primary only as the first (has one: false)" |
| a second insurance does not take over the primary | Pinned | The same two cases (has one: true) |
| closing the pane with changes asks before discarding | Pinned | `documents/presentation/pages/document_detail_page_unlock_test` "Cancel with changes asks first"; `document_detail_page_new_test` "an entry asks before leaving" |
| a permit has no phones or primary toggle | Added | `document_widgets_test`, the insurance and permit case above (ab5e5aa) |
| a card shows Front and Back slots and no expiry | Added | `document_pages_card_editor_test` "an insurance and a certification card have Front and Back slots; a permit has none" (ab5e5aa, the card added in a11957a); no expiry: `document_widgets_test` "insurance shows its insurer, phones and primary; a permit its issuer and none of them" (a11957a) and `document_detail_page_new_test` "a card document has no title, expiry or reminder" |
| card faces are stored first, Front then Back, whatever order they were added in | Added | `document_pages_card_editor_test` "card faces are kept Front then Back, whatever order they are added in" (ab5e5aa) |
| adding a file page and saving persists it | Added | `document_edit_save_service_test` "a Pages change saves the sitting's pages, the new one with its bytes and the removed one gone" (55eaf88); the editor: `document_pages_card_editor_test` "adding a page is a change of Pages" |
| a file over the limit shows the limit and adds nothing | Added | `document_pages_card_editor_test` "a file over the limit says so and adds nothing" (ab5e5aa) |
| an unsupported file names its type | Added | `document_pages_card_editor_test` "an unsupported file names its type and adds nothing" (ab5e5aa) |
| removing a page then saving deletes it | Added | `document_edit_save_service_test`, the Pages change case above (55eaf88); the editor: `document_pages_card_editor_test` "removing a page is a change, and nothing is written" |
| editing keeps the owner it was filed under | Pinned | `document_edit_save_service_test` "a $column changed underneath keeps its newer value" (owner) |
| a dive owner shows its number, site and date (#3391) | Added | `documents/presentation/widgets/document_owner_field_test` "a dive shows its number, site and date" (3b1a1ee) |
| Filed under: a personal document can be filed under a trip | Added | `document_detail_page_unlock_test` "a document refiled under a trip in Details saves that owner and names it" (3b1a1ee) |
| Filed under: moving to Personal clears the old owner column | Added | `document_edit_save_service_test` "a document filed under a trip moved to Personal clears its trip" (55eaf88) |
| Filed under: a new document starts where it was opened from | Pinned | `document_new_sitting_test` "a type and an owner from the opener are changes of Details" |
| Filed under: a card document cannot be moved | Added | `document_detail_page_unlock_test` "a card document's editor offers no owner, type, title or expiry change" now checks the owner field is locked (3b1a1ee); the rule: `documents/presentation/editing/document_edit_fields_test` "a certification card locks its owner and type and has no title, expiry or reminder" |
| ownerFixed hides the owner field (issue #4527) | Pinned | `document_detail_page_new_test` "a fixed owner is not offered, and is saved as Personal"; the refiling case above finds the field when the owner is not fixed |

#### `documents/presentation/document_tags_ui_test.dart` (trimmed)

| Old case | Now | Where |
| --- | --- | --- |
| the edit page saves a tag typed into its Tags field | Added | `documents/presentation/pages/document_detail_page_unlock_test` "a tag typed into Details is saved with the sitting" (3b1a1ee); the write: `documents/data/services/document_edit_save_service_test` "changed tags are written" |
| the detail page shows the tags, and a tap filters the list | Pinned | Kept in this file; it pumps the detail page |
| the list shows tags, filters by them and searches them | Pinned | Kept in this file; it pumps the list page |
| a filter on a tag that no longer exists does not hide the list | Pinned | Kept in this file; it pumps the list page |

#### `marine_life/presentation/pages/species_edit_page_test.dart` (deleted)

| Old case | Now | Where |
| --- | --- | --- |
| a lookup fills name, scientific name, category and class | Pinned | `marine_life/presentation/pages/species_detail_page_unlock_test` "the lookup fills the names, taxonomy and category as changes of the header"; `marine_life/presentation/pages/species_detail_page_new_test` "a lookup fills the header as changes" |
| saving: an edit saves while nothing listens to the species list | Pinned | `species_detail_page_unlock_test` "editing the description and saving writes one sitting" and "photos added are queued for upload even if the page goes" (a save outlives the page) |
| saving: a new species saves while nothing listens to the list | Pinned | `species_detail_page_new_test` "Save waits for the first entry, and the name is required". The list provider race was the form's own: the page reads its save service before it awaits |
| saving: clearing the optional fields blanks them on the row | Added | `marine_life/data/services/species_edit_save_service_test` "clearing the taxonomy class and the description stores null" (55eaf88), beside "clearing the scientific name stores null" |
| saving: reports a species deleted under the editor instead of a save | Pinned | `species_edit_save_service_test` "a species that has gone throws"; `test/shared/widgets/record_editing/record_edit_host_test` "a failed save stays unlocked and says so" |

#### `courses/presentation/pages/course_edit_agency_test.dart` (deleted)

| Old case | Now | Where |
| --- | --- | --- |
| course editor offers every agency, including FFESSM | Pinned | `courses/presentation/editing/course_card_editors_test` "the Details editor offers every agency, including FFESSM" |
| course and certification editors offer the same agencies | Pinned | `course_card_editors_test` "the course and certification Details editors offer the same agencies" |

#### `courses/presentation/pages/course_edit_certifications_test.dart` (deleted)

| Old case | Now | Where |
| --- | --- | --- |
| ticking two certifications links both to the course | Added | `courses/presentation/editing/course_certifications_sitting_test` "the field's choices are held as the certifications they name, and a removal drops only that one" (ad1015f); the write: "ticking two certifications holds both, written at Save" |
| removing a certification chip unlinks it on save | Added | The same case (ad1015f); the write: "removing one unlinks it at Save" |
| the field stays inert until the course set has loaded | Pinned | `course_certifications_sitting_test` "the field stays inert until the sitting's list has loaded" |

#### `courses/presentation/pages/course_edit_date_range_test.dart` (deleted)

| Old case | Now | Where |
| --- | --- | --- |
| start date can be set more than one year in the future | Pinned | `courses/presentation/editing/course_card_editors_test` "the start date can be set more than one year ahead" |
| completion date picker opens when the start date is in the future | Pinned | `course_card_editors_test` "the completion date picker opens when the start date is in the future" |

#### `courses/presentation/pages/course_edit_embedded_save_test.dart` (deleted)

| Old case | Now | Where |
| --- | --- | --- |
| embedded header Save persists edits to an existing course | Pinned | `courses/presentation/pages/course_detail_page_unlock_test` "the pane's Save updates the course" |
| embedded header Save updates the existing course instead of creating one | Pinned | `course_detail_page_unlock_test` "the pane's Save creates no course" |

#### `courses/presentation/pages/course_edit_instructor_test.dart` (deleted)

| Old case | Now | Where |
| --- | --- | --- |
| picking a credentialed buddy fills instructor name and number fields | Pinned | `buddies/presentation/editing/instructor_card_editor_test` "picking a credentialed buddy fills name and number" |
| switching to a non-credentialed buddy clears the instructor number | Pinned | `instructor_card_editor_test` "switching to a buddy without a credential clears the number" |
| a buddy with no credential still appears in the instructor dropdown | Pinned | `instructor_card_editor_test` "a buddy with no credential is still offered" |
| saving persists instructorId through to the repository | Added | `courses/data/services/course_edit_save_service_test` "the instructor picked on a new course is written" (55eaf88), beside "the instructor picked is written" |

#### `dive_centers/presentation/pages/dive_center_edit_page_fill_hours_test.dart` (deleted)

| Old case | Now | Where |
| --- | --- | --- |
| fillHoursProblem: neither time is fine | Pinned | `dive_centers/presentation/pages/dive_center_detail_page_unlock_test` "website and closed in one sitting save as one entry" (a centre with no fill hours passes the check at Save) |
| fillHoursProblem: one time alone is not | Added | `dive_centers/presentation/editing/dive_center_edit_fields_test` "fill hours with only a closing are a problem" (b9e4dc7), beside "fill hours with only an opening are a problem" |
| fillHoursProblem: closing must follow opening | Added | `dive_center_edit_fields_test` "both fill hours in order are fine" and "closing at the opening time is a problem" (b9e4dc7), beside "closing before opening is a problem" |
| the fill hours save with a new center | Added | `dive_centers/presentation/pages/dive_center_detail_page_new_test` "fill hours picked on a new centre show and are created" (b9e4dc7) |
| one time alone blocks the save | Added | `dive_center_detail_page_new_test` "one fill hour alone says so and stops the Save" (b9e4dc7) |
| editing keeps the fill hours | Pinned | `dive_centers/data/services/dive_center_edit_save_service_test` "a $column changed underneath keeps its newer value" (fill hours) |
| clear removes the fill hours | Added | `dive_center_detail_page_unlock_test` "Clear removes the fill hours with the Save" (b9e4dc7) |
| hours that close before they open block the save | Added | `dive_center_detail_page_unlock_test` "stored fill hours that close before they open stop a Save of another card" (b9e4dc7) |

#### `dive_centers/presentation/pages/dive_center_edit_page_logo_test.dart` (deleted)

| Old case | Now | Where |
| --- | --- | --- |
| an existing logo is shown and saved unchanged | Added | `dive_centers/presentation/editing/dive_center_header_card_editor_test` "a stored logo shows in the editor" (b9e4dc7); the save: `dive_centers/data/services/dive_center_edit_save_service_test` "a $column changed underneath keeps its newer value" (logo) and "unchanged returns null and writes nothing" |
| tapping the logo offers Remove, and remove clears it on save | Added | `dive_center_header_card_editor_test` "Remove Photo clears the logo in the sitting, with no contacts offered" (b9e4dc7) |
| a center with no logo shows the store icon | Added | `dive_center_header_card_editor_test` "with no logo the editor shows the store icon" (b9e4dc7) |

#### `dive_centers/presentation/pages/dive_center_edit_page_closed_test.dart` (deleted)

| Old case | Now | Where |
| --- | --- | --- |
| a closed center opens with the switch on | Added | `dive_centers/presentation/editing/dive_center_header_card_editor_test` "a closed centre opens with the switch on and its hint" (b9e4dc7) |
| flipping only the switch saves it | Pinned | `dive_centers/presentation/pages/dive_center_detail_page_unlock_test` "website and closed in one sitting save as one entry" |

#### `buddies/presentation/pages/buddy_edit_cert_fields_test.dart` (deleted)

| Old case | Now | Where |
| --- | --- | --- |
| shows the Certifications section with existing certs and an Add button | Added | `buddies/presentation/editing/buddy_certifications_card_editor_test` "with none it says so, and Add holds a new certification" (8e84c0f) for Add; the listed certs: `buddies/presentation/pages/buddy_detail_page_unlock_test` "edited in the dialog, Done, then the buddy's Cancel writes nothing" |
| saving unrelated edits does not clobber certs added after the form loaded (dirty-flag gate) | Pinned | `buddies/presentation/editing/buddy_certifications_sitting_test` "one added underneath is left as it is" |
| new buddy shows an empty Certifications section with an Add button | Added | `buddy_certifications_card_editor_test` "with none it says so, and Add holds a new certification" (8e84c0f) |
| merge mode hides the Certifications section (survivor inherits the union at the repository level) | Pinned | `buddies/presentation/pages/buddy_merge_page_test` "the merge page builds no linked profile or certifications section" |
| merge mode starts with a social handle one of them has | Added | `buddy_merge_page_test` "the merge starts with a social handle one of them has" (ea399d4) |

#### `buddies/presentation/pages/buddy_edit_country_test.dart` (deleted)

| Old case | Now | Where |
| --- | --- | --- |
| the field shows the stored country | Added | `buddies/presentation/editing/buddy_contact_card_editor_test` "the stored country shows below the social handle, and a country typed is held" (40feb48) |
| the field sits after the social handle | Added | The same case (40feb48) |
| typing offers matching countries | Added | `buddies/presentation/widgets/buddy_country_field_test` (new) "typing offers the countries that contain it" (40feb48) |
| saving stores the country and the code read from it | Added | The Contact editor case above holds a typed country (40feb48); the write: `buddies/data/services/buddy_edit_save_service_test` "the country code follows a changed country" |
| submitting the field takes the first suggestion | Added | `buddy_country_field_test` "submitting takes the first suggestion" (40feb48) |

#### `buddies/presentation/pages/buddy_edit_keeps_card_fields_test.dart` (deleted)

| Old case | Now | Where |
| --- | --- | --- |
| saving an edit keeps the buddy card fields | Added | `buddies/data/services/buddy_edit_save_service_test` "a received card's details survive a save" now checks the last dive too, with a census case for it, "a $column changed underneath keeps its newer value" (card last dive) (8e84c0f) |

#### `buddies/presentation/pages/buddy_edit_linked_profile_test.dart` (deleted)

| Old case | Now | Where |
| --- | --- | --- |
| shows the suggestion when the name matches a profile and links on tap | Added | `buddies/presentation/editing/buddy_contact_card_editor_test` "Link takes the suggested profile into the sitting" (40feb48); `buddies/data/services/buddy_edit_save_service_test` "a link to a free profile is written" (8e84c0f) |
| Not now hides the suggestion without saving a link | Added | `buddy_contact_card_editor_test` "Not now hides the suggestion and changes nothing" (40feb48) |
| no suggestion when the profile is already linked in this list | Pinned | `buddies/data/repositories/buddy_profile_link_repository_test` "returns null when the profile is already linked in this list" |
| refuses a link another buddy already holds | Pinned | `buddy_contact_card_editor_test` "a profile taken by another buddy is refused when picked"; `buddy_edit_save_service_test` "a linked profile taken by another buddy refuses the whole save" |
| a linked buddy shows the profile name and can clear it | Added | `buddy_contact_card_editor_test` "a linked buddy shows its profile, and clearing unlinks it" (40feb48) |

#### `buddies/presentation/pages/buddy_edit_photo_test.dart` (deleted)

| Old case | Now | Where |
| --- | --- | --- |
| the edit page shows a tappable ProfileAvatar, not a stub | Added | `buddies/presentation/editing/buddy_header_card_editor_test` (new) "a stored photo shows, with the camera badge on it" (ea399d4) |
| the avatar is wrapped in a tap target | Added | `buddy_header_card_editor_test` "with no photo it shows the initials and the sheet offers no Remove" taps the photo control (ea399d4) |
| an initial photo from a contact import is shown | Added | `buddy_header_card_editor_test` "with no photo it shows the initials and the sheet offers no Remove" (ea399d4) |
| tapping the avatar opens the source sheet | Added | The same case (ea399d4) |
| choosing Remove clears a photo carried in from a contact | Added | `buddy_header_card_editor_test` "Remove Photo clears the photo in the sitting" (ea399d4) |

#### `buddies/presentation/pages/buddy_social_handle_test.dart` (trimmed)

| Old case | Now | Where |
| --- | --- | --- |
| the detail page shows the social handle | Pinned | Kept in this file; it pumps the detail page |
| the edit page saves the social handle and has no card fields | Added | `buddies/presentation/editing/buddy_contact_card_editor_test` "a social handle typed is held as a change of Contact" (40feb48); card fields kept: `buddies/data/services/buddy_edit_save_service_test` "a received card's details survive a save" |
| editing only the social handle counts as an unsaved change | Added | The same Contact editor case: Contact is the only changed card (40feb48) |

#### `buddies/presentation/pages/buddy_rankings_form_detail_test.dart` (trimmed, and renamed `buddy_rankings_merge_detail_test.dart`)

| Old case | Now | Where |
| --- | --- | --- |
| the form: a new buddy starts ranked and can be excluded | Pinned | `buddies/presentation/pages/buddy_detail_page_new_test` "a new buddy starts ranked and can be excluded" |
| the form: an unrelated edit keeps the exclusion | Added | `buddies/presentation/pages/buddy_detail_page_unlock_test` "an excluded buddy opens with the switch on, and turning it off saves" (ea399d4); the save: `buddies/data/services/buddy_edit_save_service_test` "a $column changed underneath keeps its newer value" (rankings exclusion) |
| the form: turning it off ranks the buddy again | Added | `buddy_detail_page_unlock_test`, the same case (ea399d4) |
| the form: a merge starts ranked when any buddy is ranked | Pinned | Kept in this file, now in the group "the merge"; it pumps the merge form |
| the form: a merge starts excluded when every buddy is excluded | Pinned | Kept in this file, as above |
| the detail page: says so when the buddy is left out | Pinned | Kept in this file |
| the detail page: says nothing for a ranked buddy | Pinned | Kept in this file |

#### `buddies/presentation/widgets/buddy_contact_import_test.dart` (deleted)

| Old case | Now | Where |
| --- | --- | --- |
| the new-buddy route carries the imported name through extra | Pinned | `test/core/router/app_router_test` "a new buddy opens the page"; `buddies/presentation/pages/buddy_detail_page_new_test` "a seed from contacts is a change, a photo alone included" |
| an imported contact photo reaches the edit form | Added | `buddy_detail_page_new_test` "the route extra reads as a seed" now checks a photo and a phone in the extra (ea399d4); shown by `buddies/presentation/editing/buddy_header_card_editor_test` "a stored photo shows, with the camera badge on it" (ea399d4) |
| a contact with no photo still imports its name | Added | `buddy_detail_page_new_test` "the route extra reads as a seed" (the name kept, no photo); the initials: `buddy_header_card_editor_test` "with no photo it shows the initials and the sheet offers no Remove" (ea399d4) |

#### `buddies/presentation/widgets/buddy_picker_navigation_render_test.dart` (re-pointed in place)

| Old case | Now | Where |
| --- | --- | --- |
| Add New Buddy pushed from inside the bulk-edit dialog renders the real new-buddy page on top, and the dialog/sheet reappear intact once it is saved and popped | Re-pointed | This file, at the new-buddy page (ea399d4); the name said `BuddyEditPage` before |
| Add New Buddy pushed with no dialog involved (single-dive-edit style) still shows the real new-buddy page on top: the root-navigator fix does not regress this flow | Re-pointed | This file, as above (ea399d4) |

#### `certification_agencies/presentation/certification_edit_custom_entries_test.dart` (re-pointed)

Now `certification_agencies/presentation/certification_details_custom_entries_test.dart`, pumping the Details editor over a sitting (169b7c7).

| Old case | Now | Where |
| --- | --- | --- |
| custom agencies appear before Other, with an add action | Re-pointed | Same name |
| Add custom agency creates and selects the new agency | Re-pointed | Same name |
| a quick-created agency clears a built-in level | Re-pointed | Same name |
| Add custom certification creates a ranked rung under PADI | Re-pointed | Same name |
| a duplicate name keeps the dialog open with an error | Re-pointed | Same name |
| an unknown stored agency renders and survives a save | Re-pointed | Now "an unknown stored agency renders and is left as it is"; the save: `certifications/data/certification_unknown_id_test` "unknown stored ids survive load and save" |

#### `certifications/presentation/pages/certification_edit_agency_level_test.dart` (re-pointed)

Now `certifications/presentation/editing/certification_details_levels_test.dart`, pumping the Details editor over a sitting (169b7c7).

| Old case | Now | Where |
| --- | --- | --- |
| agency dropdown appears above level dropdown | Re-pointed | Same name |
| selecting CMAS restricts levels to CMAS grades + specialties | Re-pointed | Same name |
| switching agency resets an incompatible level | Re-pointed | Same name |
| switching agency keeps a compatible (specialty) level | Re-pointed | Same name |
| PADI offers Master Instructor (issue #3194) | Re-pointed | Same name |
| SDI offers Master Instructor (issue #3194) | Re-pointed | Same name |
| existing record with out-of-catalog level renders and survives save | Re-pointed | Now "a stored level outside its agency's catalog renders and is left as it is"; the save: `certifications/data/certification_unknown_id_test` "unknown stored ids survive load and save" |
| certification dropdown shows group headers | Re-pointed | Same name |
| group headers are not selectable | Re-pointed | Same name |
| closed dropdown shows Not specified, not a group header | Re-pointed | Same name |
| TDI shows its own five course categories, not Progression/Specialties (issue #3072) | Re-pointed | Same name |
| a legacy ambiguous TDI level (techDiver) renders under the Specialties catch-all, not headerless after Professional (issue #3072) | Re-pointed | Same name |
| a diver's own custom level under TDI still renders, under a catch-all Specialties group (issue #3072) | Re-pointed | Same name |
| IART shows its own five course categories, not Progression/Specialties (issue #3357) | Re-pointed | Same name |
| a diver's own custom level under IART still renders, under a catch-all Specialties group (issue #3357) | Re-pointed | Same name |

#### `certifications/certification_photo_pick_test.dart` (rewritten)

It now tests `pickCertificationCardPhoto` on its own, as the Card photos editor calls it (0f8b70e).

| Old case | Now | Where |
| --- | --- | --- |
| a cancelled pick leaves the card photo unset | Added | This file, "a cancelled pick returns no photo" (0f8b70e) |
| a successful pick applies the encoded photo to the card | Added | This file, "a successful pick returns the photo encoded to the stored size" (0f8b70e); the photo reaching the sitting: `certifications/presentation/editing/certification_card_editors_test` "Card photos sets only Card photos" |
| an undecodable pick reports an error and stores nothing | Added | This file, "an undecodable pick says so and returns no photo" (0f8b70e) |

#### `certifications/presentation/pages/certification_edit_credentials_test.dart` (deleted)

| Old case | Now | Where |
| --- | --- | --- |
| starts with a single credential row | Added | `certifications/presentation/editing/certification_card_editors_test` "one recognition has no remove button; adding one gives each row its own" (169b7c7) |
| "Add another recognition" appends an equal-rank row | Added | The same case (169b7c7); "Details sets only Details" holds the added row |
| removing the second row returns to a single row | Added | The same case taps Remove on the second row and is back to one row with no remove button (169b7c7, the removal added in a11957a); the rule: `certifications/presentation/editing/certification_edit_fields_test` "removing the first credential promotes the next" and "the last credential is not removed" |
| a second recognition is saved to additionalCredentials | Pinned | `certification_card_editors_test` "Details sets only Details"; `certification_edit_fields_test` "the credentials field writes row 0 as the agency and level"; `certifications/data/services/certification_edit_save_service_test` "a $column changed underneath keeps its newer value" (additional credentials) |
| an existing multi-credential card prefills every row | Added | `certification_card_editors_test` "a stored card with two recognitions shows a row each" (169b7c7) |

#### `certifications/presentation/pages/certification_edit_embedded_header_test.dart` (deleted)

| Old case | Now | Where |
| --- | --- | --- |
| a narrow pane moves Cancel and Save below the title | Form only | The pane's header is now `RecordEditPaneHeader`, whose title keeps to one line with an ellipsis, so the buttons never move below it and the wrap of #3358 cannot happen |

#### `certifications/presentation/pages/certification_edit_hidden_tab_test.dart` (deleted)

| Old case | Now | Where |
| --- | --- | --- |
| a hidden tab lets Back leave without a discard dialog | Added | PR #4829 (open, not on this branch): `test/shared/widgets/record_editing/record_edit_leave_guard_test` "with changes in a hidden tab, back leaves and asks nothing", with the fix in `RecordEditLeaveGuard` |
| a shown tab still asks before discarding | Pinned | `test/shared/widgets/record_editing/record_edit_leave_guard_test` "unlocked with changes: back asks, and Keep editing stays"; `certifications/presentation/pages/certification_detail_page_unlock_test` "Cancel with changes asks first". PR #4829 adds "with changes in the tab on screen, back still asks" |

#### `certifications/presentation/pages/certification_edit_instructor_test.dart` (deleted)

| Old case | Now | Where |
| --- | --- | --- |
| picking a credentialed buddy fills instructor name and number fields | Pinned | `buddies/presentation/editing/instructor_card_editor_test` "picking a credentialed buddy fills name and number" |
| switching to a non-credentialed buddy clears the instructor number | Pinned | `instructor_card_editor_test` "switching to a buddy without a credential clears the number" |
| editing the name text after picking does not clear the selection | Added | `instructor_card_editor_test` "typing the name after a pick keeps the buddy picked" (0f8b70e) |
| selecting None keeps the text fields contents | Pinned | `instructor_card_editor_test` "clearing the pick keeps the text"; `certifications/presentation/editing/certification_edit_fields_test` "clearing the instructor keeps the text" |
| saving passes instructorId through to the repository | Pinned | `certification_edit_fields_test` "one instructor pick is one change of Instructor"; `certifications/data/repositories/certification_repository_test` "persists and reads back instructorId"; `certifications/data/services/certification_edit_save_service_test` "a $column changed underneath keeps its newer value" (instructor id) |
| loading an existing cert with instructorId pre-selects the dropdown | Added | `instructor_card_editor_test` "a stored instructor opens picked" (0f8b70e) |

#### `certifications/presentation/pages/certification_edit_name_field_test.dart` (deleted)

| Old case | Now | Where |
| --- | --- | --- |
| Certification title field: is labelled as the certification title | Added | `certifications/presentation/editing/certification_card_editors_test` "Details opens on the stored values, under the title's label and helper" (169b7c7) |
| Certification title field: is blank for a new certification | Added | `certification_card_editors_test` "a new certification's title stays blank when a level is picked" (169b7c7) |
| Certification title field: is never auto-filled when a certification is picked | Added | The same case (169b7c7) |
| Certification title field: a manually entered name survives an agency change | Pinned | `certification_card_editors_test` "Details sets only Details" |
| Certification title field: shows blank when editing a cert with a derived name | Added | `certification_card_editors_test`, group "a derived title", "shows blank, and opening it changes nothing" (4a3aaa6, with the behaviour it pins) |
| Validation: rejects a save with neither certification nor name | Pinned | `certifications/presentation/pages/certification_detail_page_unlock_test` "a certification with neither title nor level cannot be saved"; `buddies/presentation/editing/buddy_certification_dialog_test` "neither title nor level keeps it open" |
| Validation: accepts a save with a certification and no name | Pinned | `certification_detail_page_unlock_test` "editing the card number and saving writes one sitting and locks" |
| Validation: accepts a save with a name and no certification | Pinned | `certifications/presentation/pages/certification_detail_page_new_test` "Save waits for the first entry, then pops the id" |
| Form interactions and coverage: loading an existing certification prefills the form | Added | `certification_card_editors_test` "Details opens on the stored values, under the title's label and helper" (169b7c7) |
| Form interactions and coverage: staging mode works with initial certification | Pinned | `buddy_certification_dialog_test` "Done returns the edited certification" |
| Form interactions and coverage: date pickers work | Added | `certification_card_editors_test` "Dates sets the issue date from the picker" (169b7c7) |
| Form interactions and coverage: notes field is editable | Pinned | `certification_detail_page_unlock_test` "notes added from the strip are saved" |
| Form interactions and coverage: unsaved changes dialog shows when popping with changes | Pinned | `certification_detail_page_unlock_test` "Cancel with changes asks first"; `test/shared/widgets/record_editing/record_edit_leave_guard_test` "unlocked with changes: back asks, and Keep editing stays" |
| Form interactions and coverage: instructor picker works | Pinned | `buddies/presentation/editing/instructor_card_editor_test` "picking a credentialed buddy fills name and number"; `certification_card_editors_test` "Instructor sets only Instructor" |
| Form interactions and coverage: saving an existing certification updates it | Pinned | `certification_detail_page_unlock_test` "editing the card number and saving writes one sitting and locks" |

#### `certifications/presentation/pages/certification_edit_page_staging_test.dart` (deleted)

| Old case | Now | Where |
| --- | --- | --- |
| staging mode returns a Certification via onStaged without persisting | Added | `buddies/presentation/editing/buddy_certification_dialog_test` "Done returns the edited certification" now checks the buddy is kept, and "Done with nothing changed returns it as it was" (0f8b70e). The dialog has no repository, so it writes nothing |
| constructor asserts against mixing staging and by-id modes | Form only | It tested the deleted widget's constructor |

