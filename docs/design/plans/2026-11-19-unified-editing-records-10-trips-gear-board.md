# Unified editing, phase 3, plan 10: trips (gear, checklists, scans, and the cylinder board as a satellite) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the trip page behind `kUnlockRecordEditing` (issue #4527, phase 3). The Gear, Checklist, Dives and Photos tabs, which plan 9 left read only, are held in the trip's sitting: packing and unpacking, putting a tank on board, a set's bundle, rental cylinders, every checklist change and tick, Scan for dives (a dive it added can be taken out before Save), Scan photos and Lightroom. The gallery's Scan follows the trip's lock. The cylinder board becomes a satellite page of the trip: pushed from an unlocked trip it joins the sitting, otherwise it has its own lock, and its Save is one History entry on the trip. The edit form stays until plan 12; new trips are plan 11's.

**Architecture:** As plans 7 and 9. The trip page's sitting code (what `onSittingStart` loads, `beforeSave`, `saveSitting`) moves out of the page's part file into a mixin, `TripSittingHost`, which the trip page and the board both use, so the board opened alone saves exactly as the trip page does: one `writeRecordSitting` labelled `record_edit:trips:<id>:<cards>`. Each collection is a `SittingList` over the domain rows (packed gear, cylinder slots, cylinder events, checklists, sections, items), written at Save as a diff through the repositories' existing writers, which now take the sitting's ids. The writers that read the database partway through (`appendCylinders`, the set bundle, the next sort order, a template's rows) get pure counterparts over the held lists, and the repository versions call the same functions. Scanned dives are one held write; scanned photos ride phase 2's media sitting (`record_media_sitting.dart`) with a trip writer. The board folds its state, ledger and forecast from the held lists.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), drift, go_router, `flutter gen-l10n`.

**Spec:** [docs/design/specs/2026-11-18-unified-editing-phase-3-records-design.md](../specs/2026-11-18-unified-editing-phase-3-records-design.md), sections "Design: trips" (the Packed gear, Checklists, Dives and Photos rows, "The scans", "The cylinder board", "Held writes", "Creating another record works locked"), "Design: what is generalised" (satellite pages, tabbed pages), "Design: rules every phase 3 type follows", "Calls made in this note" and "Testing"; on top of [records-1](2026-11-19-unified-editing-records-1-shared.md) (satellite host, tabs) and [records-9](2026-11-19-unified-editing-records-9-trips.md) (the trip's sitting).

## Where plan 10 starts

Plan 9 (#4781, merged) built the trip's sitting across its six tabs and left plan 10:

- `TripCardId.packedGear`, `cylinders`, `checklists`, `dives` and `photos`, defined with their tabs and History names, with no entry in `tripEditCards`.
- `TripGearTab.readOnly`, `TripChecklistsPanel.readOnly`, `TripChecklistBlock.readOnly` and a nullable `ChecklistItemTile.onToggle`, set from `trip_detail_tabs.dart` whenever the page hosts editing (`editsInPlace`), locked or not.
- The menu's three scans and the Overview empty state's scan, not offered with the switch on.
- The board (`/trips/:id/cylinders`) and the gallery (`/trips/:id/gallery`), unchanged and still writing at once, pushed by URL.
- `tripItineraryDays(repository)`, the held itinerary, which the board's forecast strip must write through.

Plan 9's names are kept and nothing it settled is reopened.

## Where plan 10 meets plan 7 (gear passports, not merged)

Plan 10 does not depend on plan 7 and is not based on it. They meet in three places, all safe in either merge order:

- **Packing.** Plan 7's passport Pack card holds `trip_equipment` in the gear item's sitting; plan 10's Packed gear holds it in the trip's. Both write through `TripEquipmentRepository.pack` and `unpack`, idempotent per trip and item, so whichever sitting saves last decides a pair and neither duplicates a row. Plan 10 holds packed gear as a list of `EquipmentItem`, compared by id (`sameIdSets`), as plan 7's `gearItemTripsList` holds trips.
- **The board's fills write passports.** A board fill on an owned cylinder is copied to the cylinder's passport (`TripFillPassportCopier`), with an id derived from the event's (`tripFillPassportCopyId`). In plan 10 the copy is written inside the trip's sitting and named in the trip's History entry; the `cylinder_fills` row still rolls up to the gear item in the change log, so reverting either entry reaches it. A passport sitting (plan 7's `gearItemFillsList`) open on the same cylinder at the time keeps its own fills; the derived id means no copy is ever duplicated.
- **`app_router.dart`.** Both add `onExit` lines to different routes.

`lib/shared/` is not changed by plan 10. If plan 7 merges first and its `GearItemSittingHost` shape differs from Task 1's `TripSittingHost`, nothing has to change: the two are independent mixins.

## Questions for Eric

The plan is written to the recommended answer of each; a different answer changes only the task named.

1. **The gallery's Scan follows the trip's lock** (a call in the note). **Recommended:** yes, as the dive's fullscreen profile does: inside the app the gallery is pushed with the trip's sitting (no lock or Done bar of its own); from a locked trip, or opened by its address, it offers no Scan; during a sitting its Scan holds the photos in that sitting, and they show in the grid marked as not saved. With the switch off, unchanged. The other way: the gallery gets its own lock as the board does, or its Scan keeps writing at once. (Task 8.)
2. **The scans move from the menu to the Dives and Photos cards** (a call in the note). **Recommended:** yes. Locked, the Dives tab and the Photos tab show their Scan buttons (and the Overview's empty state its scan); a tap unlocks the page with that card open and starts the scan, as plan 9's Plan row unlocks with the Plan card open. The other way: locked, no Scan is shown until the page is unlocked. (Tasks 6, 7.)
3. **A dive the scan added in this sitting can be taken out before Save** (the note). **Recommended:** yes: each dive the sitting added is marked and has a Take out action; its photos held in the sitting go with it. A dive already on the trip is not taken off here (that is the dive's own trip field). Photos a scan added can be taken out the same way; stored photos are not unlinked from the trip page. The other way: no taking out, only Cancel. (Tasks 6, 7.)
4. **Lightroom stays behind `lightroomUiEnabled`, held in the sitting** (the note). **Recommended:** yes, through the dive page's in-sitting variant (`prepareForDive`), dive by dive. Confident matches are held as photos; ambiguous matches make no pending suggestion from a sitting, as on the dive page, where the menu's scan today writes suggestions at once. The other way: the trip's Lightroom scan keeps writing its suggestions at once, outside the sitting, holding only the confident matches. (Task 7.)
5. **The cylinder board's lock** (decision 9 settled "its own lock on the trip's sitting"; asked again because the code makes it a route of its own). **Recommended:** as decision 9: pushed from an unlocked trip (Open board, a slot row, the under way cylinders card) it joins the sitting and shows Done; pushed from a locked trip, or opened by its address, it opens locked with its own Unlock, Cancel and Save, writing one History entry on the trip, and the trip page under it follows the stored trip. Inside the app it is pushed as a satellite (`pushRecordSatellite`) instead of by URL; the route stays for links. The other way: it follows the trip page's lock only, with no lock of its own, as the gallery. (Task 5.)
6. **Which card each piece is edited on** (a call in the note). **Recommended:** Packed gear: Add (items, tanks, a set's bundle), unpack, put on board. Cylinders (the Gear tab's cylinder section and the whole board): add rental cylinders, fill one or several, adjust, edit, delete, reorder, the ledger's delete. Itinerary days: the board strip's planned dives (they are the days' value). Checklists: everything on the Checklist tab, a set bundle's lead item included. Dives: Scan for dives. Photos: Scan photos and Lightroom. History names each so: a set's bundle that adds tanks and a lead item is Packed gear, Cylinders and Checklists. (Tasks 2 to 7.)
7. **Ticks are held** (the note puts them on the Checklists card). **Recommended:** yes: ticking an item needs the page unlocked and is written at Save with the rest, as every change on a record's page is. Worth a look, since a diver on a boat ticks items one at a time: the other way is ticks that work locked and write at once, outside the rule, as the trip day weather does. (Task 2.)
8. **What the board and the Gear tab calculate while unlocked.** **Recommended:** the board folds its slots' state (pressure, mix, status), the ledger and the fill forecast from the sitting's slots, fills and planned dives, since those are the values being edited (plan 7's Question 7 did the same for the passport's current fill); the Gear tab's service alerts and scrubber margins stay as stored until Save. The other way: the board shows the stored state until Save, its held fills listed apart. (Tasks 4, 5.)
9. **Log dive from a slot.** **Recommended:** offered on a slot that is stored, locked or unlocked (it pushes another record's new page and leaves the sitting as it is); a slot added in the sitting offers it after Save, since a dive cannot link a slot that does not exist yet; a slot deleted in the sitting offers none. (Task 5.)
10. **One PR** (recommended, the size of plan 7) or two (Tasks 1 to 4, then 5 to 8).

## Calls made in this plan, for Eric to check

1. **The Gear, Checklist, Dives and Photos tabs are edited in place while the page is unlocked**, with no pencil or open card, as plan 9 built the Itinerary tab: they are whole tabs of lists. Each tab's content is framed by its card for the changed dot and a refused Save.
2. **One mixin for the trip's sitting**, `TripSittingHost`, shared by the trip page and the board, as plan 7 did for the gear item's pages.
3. **Writers that read the database partway through get pure counterparts.** `appendCylinders`'s skipping and next sort order, a set bundle's slot drafts and lead item, a checklist's next sort order and a template's rows are computed over the held lists in the sitting, and the repository methods are refactored to call the same functions, so the two cannot drift. No new repository write method: existing ones take the sitting's ids (`createChecklist(id:)`, `createSection(id:)`), so the agent write coverage baseline does not move.
4. **Save writes a diff**, by id, of each held list against what was read when the sitting started. A row another device added meanwhile is never touched; a row changed in the sitting is written whole.
5. **Order at Save** (after plan 9's trip row, sharing, vessel, itinerary and documents): checklists, sections and items created, then changed, then deleted, then reordered; packed gear packed and unpacked; cylinder slots created and changed; cylinder events created and changed with their passport copies; events then slots deleted; slots reordered; dives assigned (the scan's, then the dates question's); photos written. Uploads wait for the commit.
6. **The passport copy moves inside the transaction.** Today it runs after the events commit, best effort. In a sitting it is a held write: a copy that fails (a passport id the gear has lost meanwhile) fails the whole Save, writes nothing and leaves the page unlocked, rather than leaving a fill with no copy.
7. **A template applied in a sitting** dates its items from the working start date, so dates moved in the same sitting are honoured. Its rows are read when it is applied; a template changed later in the sitting is not re-read.
8. **Save as template** builds the template from the checklist as the page shows it (held rows included) and creates it at once: it is another record and survives Cancel. Starting a pre-dive session works locked and reads the stored trip.
9. **The dates question and the scan never offer the same dive twice.** Plan 9's `beforeSave` question leaves out dives the scan holds; the scan uses the working dates and leaves out dives already held.
10. **The photo scan matches the dives the sitting holds**: the trip's stored dives plus those the scan added, less those taken out.
11. **The board's CSV export** reads the stored record, locked or unlocked, as the record view does today; held changes are not in it until Save.
12. **The board's planned dives** go through `tripItineraryDays` with a pure `withPlannedDives` that does what `ItineraryDayRepository.setPlannedDives` does (every day of the date, the dive day and rest swap, a new day when none), so the strip and the Itinerary tab edit one held list.

## Global Constraints

- Plan 7 (passports, branch `ericgriffin/unified-editing-phase-3-7-gear-9c6420`) runs in parallel. **The one file both touch is `lib/core/router/app_router.dart`**: this plan changes only the `/trips/:tripId/cylinders` route (its `onExit`). Merge origin/main before each task with a merge (never a rebase or a force-push), adapt to any renamed names, and run a whole-repo `flutter analyze` after each merge.
- Built on the names shipped: plan 9's `TripCardId`, `tripEditCards`, `tripOptionalCards`, `TripCardSlots` and `TripCardSlotsScope` (`frame`, `session`, `openCard`), `tripItineraryDays`, `TripEditSaveService.save` (`alsoWrite`, `alsoWriteIsAChange`), `_TripDetailPageEditing` (`beforeSave`, `saveSitting`, `_assignDivesKey`); the shared `RecordEditHost` (`joinedSitting`, `pushSatellite`, `finishJoinedSitting`, `editScaffold`, `lockButton`, `editController.unlock`, `openCard`), `RecordEditTabs`, `pushRecordSatellite`, `RecordSatelliteBar`, `RecordEditScope`, `EditSession` (`holdWrite`, `holdChange`, `releaseWrite`, `remember`, `recall`, `isHeld`, `changedCardIds`, `runHeldWrites`), `SittingList` and `SittingList.withSession`, `sameIdSets`, `writeRecordSitting`, `RecordSittingRefusal`, `confirmLeaveRecordSitting`; the media sitting's `holdSittingMedia`, `addMediaToSitting`, `unlinkMediaInSitting`, `mediaInSitting`, `mediaAfterCommit`, `undoMediaOnFailure`, `MediaImportService.prepareForDive` and `runLightroomScanInSitting`'s pieces.
- With `kUnlockRecordEditing` false (the default) the trip page, its tabs, the board, the gallery, the add sheets and their routes look and behave exactly as today: no existing test changes its expectations. Pages and sheets take `unlockEditing` defaulting to the switch, or a nullable hold callback.
- A locked page writes nothing on any tap, on any tab, on the board and on the gallery. Creating another record (a pre-dive session, Save as template, Log dive) and the CSV export work locked.
- Sync: no table or column changes. Every table written is already tracked and rolls up to the trip (`trip_equipment`, `trip_cylinders`, `trip_cylinder_events`, `trip_checklists`, `trip_checklist_sections`, `trip_checklist_items`, `trip_itinerary_days`) or is pinned to the trip's entry by its label (`dives`, `dive_tanks`, `media`, `cylinder_fills`, `equipment_attributes`). Each task that writes a synced table in a new path adds a case to that table's sync test or names the existing case that covers it.
- New strings, expected: `trips_sitting_notSaved` ("Not saved yet") and `trips_sitting_takeOut` ("Take out"), in all eleven ARB files, translated, then `flutter gen-l10n`. A task that finds another missing names it the same way.
- No file passes 800 lines. `trip_detail_page.dart` does not grow; the board's editing goes in a `part` file; `trip_cylinder_fill_sheet.dart` (604) and `trip_checklist_block.dart` (490) take their hold mode in small helpers if they would pass 700.
- Never use em-dashes, and never en-dashes, double hyphens or spaced hyphens as prose punctuation, in code, comments, commits or the PR. Commits, the PR and files follow the repository guide's Attribution section.
- Imports grouped dart, flutter, packages, local. `dart format` changed files before each commit. Anything acting after an `await` checks `mounted` and reads `ref` and `context` before its first `await`.
- Test runs: only the test FILES a task writes or changes, by path. Never a folder, never the whole suite, never `test/architecture/` or `test/shared/` by hand: the pre-push hook runs them.
- Never `--build-filter` build_runner. Never let a debug build open `~/Documents/Submersion/submersion.db`; screenshots come from headless widget goldens.

## Review Focus

1. **A fill logged on the board while another device logs a fill on the same slot before Save.** Save writes the sitting's fill and keeps the other device's; the board after Save folds both, in time order. Pinned in Task 4.
2. **A tank put on board, filled, then the slot deleted, all in one sitting.** Save writes no slot, no event and no passport copy; the tank stays packed as it was stored. Pinned in Task 4.
3. **A dive scanned in, its photos scanned, then the dive taken out.** Save assigns no dive and writes none of its photos; the other dives' photos are written. Pinned in Task 7.
4. **Planned dives set on the board strip for a day the Itinerary tab edited in the same sitting.** One held day carries both changes; Save writes it once; the forecast and the tab agree before Save. Pinned in Task 5.
5. **A checklist created from a template, an item ticked and a section deleted, then Cancel; then the same with Save.** Cancel writes nothing (no empty checklist left behind, as the template path's rollback ensures today); Save writes it all in one entry, and a revert removes the checklist with its sections and items. Pinned in Task 2.

## Test accounting

No form owns these tabs, so no form test moves. Every existing test of the tabs, sheets, board and gallery keeps passing unchanged with the switch off: `trip_gear_tab_test.dart`, `trip_gear_add_set_bundle_test.dart`, `add_trip_cylinders_sheet_test.dart`, `trip_detail_tabs_test.dart`, `trip_detail_checklist_test.dart`, `trip_checklists_panel_test.dart`, `trip_checklist_block_test.dart`, `trip_checklist_block_real_db_test.dart`, `checklist_item_tile_test.dart`, `checklist_item_edit_sheet_test.dart`, `save_as_template_dialog_test.dart`, `apply_template_sheet_test.dart`, `start_session_sheet_test.dart`, `trip_cylinder_board_page_test.dart`, the seven cylinder sheet and view tests, `trip_scan_actions_test.dart`, `trip_detail_page_test.dart`, `trip_gallery_page_test.dart`, `trip_photo_section_test.dart`, `trip_photo_section_lightroom_test.dart`, `trip_dives_tab_test.dart`, `trip_overview_tab_test.dart`. Plan 9's `the Gear and Checklist tabs offer no action with the switch on` and `with the switch on the menu has no scans` (`trip_detail_page_unlock_test.dart`) are replaced by Tasks 2, 3, 6 and 7's held cases; its `locked, no tap on any tab writes` stays and gains the board and gallery.

## Preparation

- [ ] The worktree is initialised (`git submodule update --init --recursive`, `flutter pub get`); generate code unfiltered in the background if fresh: `dart run build_runner build --delete-conflicting-outputs`.
- [ ] `git fetch origin main`, merge it, and run `flutter analyze` on the whole repository. Expected: clean.
- [ ] Before any code changes, take the "before" goldens (headless widget tests, switch on, as plan 9 left the page): the Gear tab of an upcoming liveaboard with packed gear and cylinders, the Checklist tab with two checklists, the Dives and Photos tabs, the board, and the gallery, at phone and desktop width.

## File Structure

New:

| File | Responsibility |
| --- | --- |
| `lib/features/trips/presentation/editing/trip_sitting_host.dart` | `TripSittingHost`: what a sitting on a trip loads and how it saves, for the trip page and the board |
| `lib/features/trips/presentation/editing/trip_checklists_sitting.dart` | The held checklists, sections and items, their pure edits and their write |
| `lib/features/checklists/domain/services/checklist_rows.dart` | Pure: a template's rows for a checklist, the next sort order |
| `lib/features/trips/presentation/editing/trip_gear_sitting.dart` | The held packed gear and cylinder slots, their pure edits and their write |
| `lib/features/trips/domain/services/trip_cylinder_append.dart` | Pure: which drafts join a board, at which sort order; a bundle's lead item |
| `lib/features/trips/presentation/editing/trip_cylinder_events_sitting.dart` | The held cylinder events with their passport copy notes, their write, and the folded state, ledger and forecast of a sitting |
| `lib/features/trips/presentation/pages/trip_cylinder_board_page_editing.dart` | `part`: the board on the host |
| `lib/features/trips/presentation/editing/trip_dives_sitting.dart` | The held scan: dives added, taken out |
| `lib/features/trips/presentation/editing/trip_photos_sitting.dart` | The trip's photo and Lightroom scans held per dive |

Modified: `trip_detail_page.dart`, `trip_detail_page_editing.dart`, `trip_edit_cards.dart`, `trip_detail_tabs.dart`, `trip_gear_tab.dart`, `trip_gear_add_sheet.dart`, `add_trip_cylinders_sheet.dart`, `trip_set_bundle.dart`, `trip_cylinder_repository.dart` (calls the pure append), the board page and its sheets (`trip_cylinder_fill_sheet.dart`, `trip_cylinder_adjust_sheet.dart`, `trip_cylinder_edit_sheet.dart`, `trip_cylinder_slot_card.dart`, `trip_cylinder_ledger_view.dart`, `trip_fill_forecast_strip.dart`), `trip_cylinders_summary_card.dart`, `trip_checklists_panel.dart`, `trip_checklist_block.dart`, `checklist_item_edit_sheet.dart`, `save_as_template_dialog.dart`, `trip_checklists_repository.dart` (`createChecklist(id:)`), `trip_checklist_section_repository.dart` and `trip_checklist_repository.dart` (`createSection(id:)`, pure rows, `saveAsTemplate(rows:)`), `trip_dives_tab.dart`, `trip_photos_tab.dart`, `trip_photo_section.dart`, `trip_overview_tab.dart`, `trip_gallery_page.dart`, `record_media_sitting.dart` (`SittingMediaWriters.forTrip`), `app_router.dart`, the eleven ARB files.

---

### Task 1: One sitting host for the trip's pages

**Files:**
- Create: `lib/features/trips/presentation/editing/trip_sitting_host.dart`
- Modify: `trip_detail_page.dart`, `trip_detail_page_editing.dart`
- Test: `test/features/trips/presentation/editing/trip_sitting_host_test.dart`

**Interfaces:**
- Produces: `mixin TripSittingHost<W extends ConsumerStatefulWidget> on ConsumerState<W>, RecordEditHost<W, Trip>`, holding what plan 9 put in the page's part that is not the page's: `recordIdOf`, `storedForUnlock` (from `tripByIdProvider(hostRecordId)`), `editingTitle`, `rereadStored`, `onSittingStart` (sharing, vessel, itinerary, documents; Tasks 2 to 7 add theirs here), `beforeSave` (the dates question) and `saveSitting` (the save service, the dives notice). The page's part keeps only what is the page's: `hostsEditing`, `openUnlockedOf`, `onEditChanged`, `hostEditCards`, the tabs and the slots.
- Consumes: plan 9's names.

- [ ] **Step 1: Write the failing test** with a bare host on a fake page: `unlock loads every held list the trip page loads`; `Save writes one entry labelled record_edit:trips:<id>:<cards>`; `a changed date asks the dives question once`.
- [ ] **Step 2:** Run the test file. Expected: fails to compile.
- [ ] **Step 3:** Move the code; the trip page mixes in `TripSittingHost`.
- [ ] **Step 4:** Run it, and unchanged `trip_detail_page_unlock_test.dart` and `trip_detail_page_dates_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `refactor(trips): one sitting host for a trip's pages`.

### Task 2: Checklists held

**Files:**
- Create: `trip_checklists_sitting.dart`, `checklist_rows.dart`
- Modify: `trip_checklists_repository.dart`, `trip_checklist_section_repository.dart`, `trip_checklist_repository.dart`, `trip_checklists_panel.dart`, `trip_checklist_block.dart`, `checklist_item_edit_sheet.dart`, `save_as_template_dialog.dart`, `trip_edit_cards.dart`, `trip_detail_tabs.dart`, `trip_sitting_host.dart`
- Test: `test/features/trips/presentation/editing/trip_checklists_sitting_test.dart`, `test/features/checklists/domain/services/checklist_rows_test.dart`, `trip_checklist_repository_test.dart`, `trip_checklists_panel_test.dart`, `trip_checklist_block_test.dart` (existing; add cases), `trip_detail_page_unlock_test.dart`

**Interfaces:**
- Produces:
  - Pure (`checklist_rows.dart`): `({List<TripChecklistSection> sections, List<TripChecklistItem> items, int skipped}) checklistRowsFromTemplate({required ChecklistTemplate template, required List<ChecklistTemplateSection> sections, required List<ChecklistTemplateItem> items, required String checklistId, required DateTime tripStart, required List<TripChecklistItem> existing, required String Function() newId})`, what `applyTemplate` adds today (its skipping included); `int nextSortOrder(Iterable<int> taken)`. `applyTemplate` and `replaceWithTemplate` call it.
  - `TripChecklistsRepository.createChecklist({required String tripId, required String name, String? id})`, `TripChecklistSectionRepository.createSection({..., String? id})` and its `TripChecklistRepository` delegate: a given id is kept. `saveAsTemplate({..., ({List<TripChecklistSection> sections, List<TripChecklistItem> items})? rows})`: with rows it builds from them (Call 8).
  - `final tripChecklists = SittingList<Trip, TripChecklist>`, `tripChecklistSections = SittingList<Trip, TripChecklistSection>`, `tripChecklistItems = SittingList<Trip, TripChecklistItem>`, all card `checklists`, keys `trip.checklists`, `trip.checklistSections`, `trip.checklistItems`. One held write, `trip.checklists.write`, writes all three as one diff in Call 5's order; each list's own `write` is null.
  - Pure edits over the three lists, each returning the next lists: `checklistAdded`, `checklistFromTemplate`, `checklistReplacedWithTemplate`, `checklistCleared`, `checklistRenamed`, `checklistsReordered`, `checklistDeleted`, `itemSaved` (add or edit, a new section title making a section), `itemDeleted`, `itemTicked` (sets `completedAt` from `clock.now()`, clears it on untick), `itemMoved`, `sectionAdded`, `sectionRenamed`, `sectionsReordered`, `sectionDeleted` (moving its items or deleting them).
  - `TripChecklistsPanel`, `TripChecklistBlock` and `showChecklistItemEditSheet` gain `EditSession<Trip>? editing`: with a session they draw the held rows and every action holds through the pure edits; the sheet's Save hands the item back. `readOnly` stays for locked. The tab is framed as the `checklists` card. Ticks are held (Question 7). The pre-dive session button and Save as template work locked.
- Consumes: Task 1.

- [ ] **Step 1: Write the failing tests:**
  - Pure: `template rows date items from the given start`; `rows already on the checklist are skipped`; `the repository's applyTemplate adds what the pure rows say` (real test database).
  - Sitting: one case per pure edit; `a checklist added and deleted in one sitting writes nothing`; `Save writes created, changed, deleted and reordered rows in one entry`; `a row another device added during the sitting survives Save`; `a tick sets completed_at, an untick clears it`.
  - Widgets: `in a sitting, every action writes nothing until Save` (panel, block, sheet); `locked with the switch on, no tap writes`; with the switch off, the existing cases unchanged.
  - Page: `a checklist from a template, a tick and a section deleted: Cancel writes nothing; Save writes one entry and a revert removes them` (Review Focus 5); `Save as template from a held checklist creates the template at once`; `the pre-dive session starts locked`.
- [ ] **Step 2:** Run the six files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them, and unchanged `trip_checklist_block_real_db_test.dart`, `checklist_item_tile_test.dart`, `save_as_template_dialog_test.dart`, `apply_template_sheet_test.dart`, `trip_checklist_cascade_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(trips): a trip's checklists wait for Save`.

### Task 3: Packed gear and cylinder slots held on the Gear tab

**Files:**
- Create: `trip_gear_sitting.dart`, `trip_cylinder_append.dart`
- Modify: `trip_cylinder_repository.dart`, `trip_set_bundle.dart`, `trip_gear_tab.dart`, `trip_gear_add_sheet.dart`, `add_trip_cylinders_sheet.dart`, `trip_edit_cards.dart`, `trip_detail_tabs.dart`, `trip_sitting_host.dart`
- Test: `test/features/trips/presentation/editing/trip_gear_sitting_test.dart`, `test/features/trips/domain/services/trip_cylinder_append_test.dart`, `trip_gear_tab_test.dart`, `trip_gear_add_set_bundle_test.dart`, `add_trip_cylinders_sheet_test.dart`, `trip_cylinder_repository_test.dart` (existing; add cases), `trip_detail_page_unlock_test.dart`

**Interfaces:**
- Produces:
  - Pure: `List<TripCylinder> cylindersToAppend(List<TripCylinder> board, List<TripCylinder> drafts, {required String Function() newId})` (tanks already on the board skipped, sort orders after the last, ids given); `TripChecklistItem? bundleLeadItem(SetBundle bundle, {required String checklistId, required List<TripChecklistItem> items, required String Function() newId})`. `appendCylinders` and `applySetBundleToTrip` call them.
  - `final tripPackedGear = SittingList<Trip, EquipmentItem>(key: 'trip.packedGear', cardId: 'packedGear', read: <tripGear>, write: <pack added ids, unpack removed>, same: sameIdSets)`; `final tripCylinderSlots = SittingList<Trip, TripCylinder>(key: 'trip.cylinders', cardId: 'cylinders', ...)`, written with the events in Task 4 (its `write` is the cylinders writer's slot half: `createCylinders` for new ids, `updateCylinder` for changed, `reorderCylinders` when the order differs; deletes in Task 4).
  - Pure edits: `gearPacked`, `gearUnpacked`, `putOnBoard` (adds the slot from `tripCylinderDraftFromEquipment`, removes the item from packed gear), `cylindersAdded`.
  - `showTripGearAddSheet(..., EditSession<Trip>? editing)` and `showAddTripCylindersSheet(..., void Function(List<TripCylinder>)? hold)`: in a sitting, Add holds items, tanks and a set's bundle; a bundle's lead item goes into Task 2's held items, the checklist picked from the held checklists. `TripGearTab(trip:, readOnly:, editing:)` draws the held packed gear and slots; unpack and put on board hold. The packed list is framed as `packedGear`, the cylinder section as `cylinders`. Service alerts and scrubber margins stay as stored (Question 8).
- Consumes: Tasks 1 and 2.

- [ ] **Step 1: Write the failing tests:**
  - Pure: `a tank already on the board is not added again`; `appended slots follow the last sort order`; `a lead item already listed is not added again`; `appendCylinders gives what the pure function says` (real database).
  - Sitting: `pack and unpack the same item write nothing`; `put on board moves a tank from packed gear to the board`; `Save packs, unpacks and creates slots with the sitting's ids in one entry`.
  - Widgets: `in a sitting, Add, unpack and put on board write nothing until Save`; `a set's bundle holds gear, slots and its lead item on the chosen held checklist`; `rental cylinders are held with the next sort order`; `locked with the switch on, no tap writes`; switch off unchanged.
  - Page: `packed gear, a tank put on board and a set bundle save as one entry, History naming Packed gear, Cylinders and Checklists`; `Cancel writes nothing`.
- [ ] **Step 2:** Run the seven files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them, and unchanged `trip_equipment_repository_test.dart`, `trip_set_bundle_test.dart`, `trip_gear_split_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(trips): a trip's packed gear and cylinders wait for Save`.

### Task 4: Cylinder events held, with their passport copies

**Files:**
- Create: `trip_cylinder_events_sitting.dart`
- Modify: `trip_gear_sitting.dart`, `trip_cylinder_fill_sheet.dart`, `trip_cylinder_adjust_sheet.dart`, `trip_cylinder_edit_sheet.dart`, `trip_cylinder_slot_card.dart`, `trip_cylinder_ledger_view.dart`, `trip_sitting_host.dart`
- Test: `test/features/trips/presentation/editing/trip_cylinder_events_sitting_test.dart`, `trip_cylinder_fill_sheet_test.dart`, `trip_cylinder_adjust_sheet_test.dart`, `trip_cylinder_edit_sheet_test.dart`, `trip_cylinder_ledger_view_test.dart` (existing; add cases)

**Interfaces:**
- Produces:
  - `final tripCylinderEvents = SittingList<Trip, TripCylinderEvent>(key: 'trip.cylinderEvents', cardId: 'cylinders', ...)`, with a copy note per new or edited fill (`({String? diverId, String? stationName, bool stationResolved})`, kept by `session.remember` under the event's id).
  - One held write, `trip.cylinders.write`, for slots and events together, in Call 5's order: `createCylinders`, `updateCylinder`; `createEvents`, `updateEvent`, each fill then `TripFillPassportCopier.afterSave` with its note (Call 6); `deleteEvent(id, alongside: copier.afterDelete)`; `deleteCylinder` (it clears the dive tank links and deletes its events); `reorderCylinders`. Events of a slot deleted in the sitting are not written.
  - Pure edits: `fillsLogged`, `fillEdited`, `adjusted`, `eventDeleted`, `slotEdited`, `slotDeleted` (drops its held events), `slotsReordered`.
  - Folded views: `List<TripCylinderState> tripCylinderStatesIn(EditSession<Trip> session, List<TripCylinderTankUse> uses)` through `foldCylinderState`, and `tripCylinderLedgerIn(session)`, ordered as `tripCylinderLedgerProvider` orders.
  - The fill, adjust and edit sheets and the delete confirmation gain a hold callback; with it, Save validates as today and hands the rows back (the fill sheet's retry bookkeeping is not used); the ledger's delete holds.
- Consumes: Task 3.

- [ ] **Step 1: Write the failing tests:**
  - Sitting: `a fill logged and edited in one sitting is one created event`; `Save writes slots, events and the fill's passport copy in one entry, and a revert takes back the copy`; `a rental slot's fill has no copy`; `a refused copy fails the Save and writes nothing` (Call 6); `a tank put on board, filled and its slot deleted writes nothing` (Review Focus 2); `a fill another device logged on the slot during the sitting survives Save and folds in time order` (Review Focus 1); `a slot deleted at Save clears its dive tank links`; `the folded state follows the held fills`.
  - Sheets: `with a hold callback, Save hands the rows back and writes nothing`; `the fill sheet's checks are unchanged in hold mode`; switch off unchanged.
- [ ] **Step 2:** Run the five files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them, and unchanged `trip_cylinder_repository_test.dart`, `trip_fill_saver_test.dart`, `trip_fill_passport_copy_test.dart`, `trip_cylinder_state_fold_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(trips): a trip's cylinder fills and adjustments wait for Save`.

### Task 5: The cylinder board as a satellite of the trip

**Files:**
- Create: `trip_cylinder_board_page_editing.dart` (part)
- Modify: `trip_cylinder_board_page.dart`, `trip_fill_forecast_strip.dart`, `trip_itinerary_sitting.dart`, `trip_gear_tab.dart`, `trip_cylinders_summary_card.dart`, `app_router.dart`
- Test: `test/features/trips/presentation/pages/trip_cylinder_board_page_unlock_test.dart`, `trip_itinerary_sitting_test.dart` (existing; add cases), `test/core/router/app_router_test.dart`

**Interfaces:**
- Produces:
  - `TripCylinderBoardPage({required String tripId, RecordEditController<Trip>? joined, bool unlockEditing = kUnlockRecordEditing})`, on `RecordEditHost<TripCylinderBoardPage, Trip>` and `TripSittingHost`. `joinedSitting => widget.joined`; `hostEditCards`: `cylinders`, `itineraryDays`. `editScaffold` with the board's title, its lock button, Add cylinders and Fill several (unlocked only). Each slot's menu and the ledger hold through Task 4; reorder holds. The board, ledger and record views read the folded views while unlocked, the providers while locked. Log dive on a stored slot only (Question 9); the CSV export reads the stored record (Call 11).
  - Pure: `List<ItineraryDay> withPlannedDives(List<ItineraryDay> days, Trip trip, DateTime date, int? planned, {required String Function() newId})`, what `setPlannedDives` does (Call 12). The strip, in a sitting, sets `tripItineraryDays` through it; the forecast is computed (`computeFillForecast`) from the sitting's trip, days and folded states (Question 8).
  - Entry points (Open board, a slot row, the under way cylinders card), on a page that edits in place, push the board with `pushRecordSatellite<Trip, void>`: joined while the trip is unlocked, with its own lock otherwise. The route stays for links and gains `onExit: confirmLeaveRecordSitting`.
- Consumes: Tasks 1, 3 and 4; plan 9's `tripItineraryDays`.

- [ ] **Step 1: Write the failing tests:**
  - Pure: `withPlannedDives` sets every day of the date, swaps dive day and rest, adds a day where there is none, adds nothing for a null plan, and `matches setPlannedDives on a real database`.
  - Board: `with the switch off it is unchanged`; `opened alone it opens locked and no tap writes`; `alone: unlock, fill, Save writes one entry on the trip, and the trip page under it follows`; `pushed from an unlocked trip it joins, shows Done, and the trip's Save writes its fills`; `pushed from a locked trip it has its own lock`; `a planned dive set on the strip and the Itinerary tab's edit of that day are one held day, written once, and the forecast agrees before Save` (Review Focus 4); `Log dive is offered on a stored slot and not on a held one`; `the export works locked`; `leaving with changes asks first`.
  - Router: `the board's route asks before leaving unsaved changes`.
- [ ] **Step 2:** Run the three files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them, and unchanged `trip_cylinder_board_page_test.dart`, `trip_fill_forecast_providers_test.dart`, `fill_forecast_test.dart`, `itinerary_day_repository_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(trips): the cylinder board edits as a satellite of its trip`.

### Task 6: Scan for dives on the Dives card

**Files:**
- Create: `trip_dives_sitting.dart`
- Modify: `trip_dives_tab.dart`, `trip_overview_tab.dart`, `trip_sitting_host.dart` (the dates question leaves out held dives), `trip_edit_cards.dart`, `trip_detail_tabs.dart`, the eleven ARB files
- Test: `test/features/trips/presentation/editing/trip_dives_sitting_test.dart`, `trip_dives_tab_test.dart` (existing; add cases), `trip_detail_page_unlock_test.dart`, `trip_detail_page_dates_test.dart`

**Interfaces:**
- Produces:
  - `TripScannedDives` held under `trip.scannedDives` (card `dives`) as a held change whose write is `TripRepository.assignDivesToTrip(ids, tripId)`; `List<Dive> scannedDivesOf(session)`, `void holdScannedDives(session, List<DiveCandidate> chosen)`, `void takeOutScannedDive(session, String diveId)` (also drops the dive's held photos, Task 7). Released when empty.
  - `Future<void> scanForTripDivesInSitting(BuildContext, WidgetRef, EditSession<Trip>)`: as `scanForTripDives`, over the working dates, leaving out dives already held (Call 9); the chosen are held, not assigned.
  - `TripDivesTab(tripId:, editing:, onScan:)`: draws the stored dives and the held ones marked `trips_sitting_notSaved` with `trips_sitting_takeOut`; a Scan for dives button. Locked with the switch on, Scan unlocks with the `dives` card and scans (Question 2); the Overview empty state's scan does the same.
- Consumes: Task 1.

- [ ] **Step 1: Write the failing tests:** `in a sitting, the scan assigns nothing until Save`; `Save assigns the held dives in one entry with the rest, and a revert takes them off`; `a dive taken out is not assigned`; `the scan leaves out dives already held`; `locked, Scan unlocks with the Dives card and scans`; `the dates question leaves out dives the scan holds` (Call 9); `the old trips are refreshed and the notice shown after Save`; switch off unchanged.
- [ ] **Step 2:** Add the two strings to all eleven ARB files, translated; `flutter gen-l10n`. Run the four files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them, and unchanged `trip_scan_actions_test.dart`, `trip_repository_dive_scan_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(trips): scanning for a trip's dives waits for Save`.

### Task 7: Scan photos and Lightroom on the Photos card

**Files:**
- Create: `trip_photos_sitting.dart`
- Modify: `record_media_sitting.dart` (`SittingMediaWriters.forTrip`), `trip_photos_tab.dart`, `trip_photo_section.dart`, `trip_dives_sitting.dart`, `trip_sitting_host.dart`, `trip_edit_cards.dart`, `trip_detail_tabs.dart`
- Test: `test/features/trips/presentation/editing/trip_photos_sitting_test.dart`, `trip_photo_section_test.dart`, `trip_photo_section_lightroom_test.dart` (existing; add cases), `trip_detail_page_unlock_test.dart`

**Interfaces:**
- Produces:
  - `SittingMediaWriters.forTrip(ProviderRead read)`: as `forDive`, writing prepared rows (each carries its dive); no unlink or relink from a trip sitting. Held with `holdSittingMedia(session, ..., cardId: 'photos')` in `onSittingStart`; `saveSitting` wraps the save in `undoMediaOnFailure` and runs `mediaAfterCommit` after it, as the dive page does.
  - `Future<void> scanTripPhotosInSitting(BuildContext, WidgetRef, EditSession<Trip>)`: `TripMediaScanner.scanGalleryForTrip` over the sitting's dives (Call 10) and the photos already held, `showScanResultsDialog` as today, then `prepareForDive` per chosen dive and `addMediaToSitting`. `Future<void> scanLightroomForTripInSitting(...)`: dive by dive, the in-sitting Lightroom variant; no pending suggestions (Question 4).
  - `TripPhotoSection(tripId:, editing:, onScanPressed:, onLightroomScanPressed:)` shows `mediaInSitting` with the held photos marked and taken out with `unlinkMediaInSitting`. Locked with the switch on, Scan unlocks with the `photos` card and scans (Question 2). Lightroom only while `lightroomUiEnabled`.
- Consumes: Tasks 1 and 6.

- [ ] **Step 1: Write the failing tests:** `in a sitting, scanned photos are written at Save with the rest, one entry`; `Cancel writes no media and queues no upload`; `a failed Save writes no media`; `uploads are queued after the commit`; `a dive scanned in, its photos held, then the dive taken out: neither is written, the other dives' photos are` (Review Focus 3); `a held photo taken out is not written`; `the photo scan includes dives the scan holds`; `Lightroom in a sitting holds its confident matches and suggests nothing`; `locked, Scan unlocks with the Photos card and scans`; switch off unchanged.
- [ ] **Step 2:** Run the four files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them, and unchanged `trip_media_scanner_test.dart`, `media_import_service_test.dart`, `lightroom_scan_helper_test.dart`, `trip_scan_actions_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(trips): scanning a trip's photos waits for Save`.

### Task 8: The gallery follows the trip's lock

**Files:**
- Modify: `trip_gallery_page.dart`, `trip_photo_section.dart`
- Test: `trip_gallery_page_test.dart` (existing; add cases), `trip_detail_page_unlock_test.dart`

**Interfaces:**
- Produces: `TripGalleryPage({required String tripId, String? initialMediaId, EditSession<Trip>? session})`: with an open session its Scan runs `scanTripPhotosInSitting` and the grid shows the held photos marked; with none (locked, or opened by its address) it offers no Scan while the switch is on (Question 1). It listens to the session and drops its Scan when the session ends. On a page that edits in place, View all and a thumbnail push it with the sitting's session (read once from `TripCardSlotsScope`), not by URL. The route is unchanged: the gallery holds no sitting of its own, and its address opens it with no Scan.
- Consumes: Task 7.

- [ ] **Step 1: Write the failing tests:** `with the switch off its Scan writes as today`; `opened from a locked trip it offers no Scan`; `opened by its address it offers no Scan`; `pushed during a sitting its Scan holds the photos in it, and the trip's Save writes them`; `the trip's Cancel drops them`; `locked, no tap on the gallery writes` (added to the page's every-tab case).
- [ ] **Step 2:** Run the two files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them. Expected: all pass.
- [ ] **Step 5: Commit** `feat(trips): the trip gallery's scan follows the trip's lock`.

### Task 9: Push, open the pull request, track it to green

- [ ] **Step 1:** Merge origin/main once more; whole-repo `flutter analyze`; `dart format` every changed file. Expected: clean.
- [ ] **Step 2:** Push in the background (`git push -u origin HEAD`), touching no `lib/` or `test/` file while it runs. Fix any hook failure in its own commit.
- [ ] **Step 3:** `/code-review xhigh --fix --max-findings all`; fix every valid finding test first; push again.
- [ ] **Step 4:** Screenshots from headless widget-test goldens with the switch on (never `flutter test ... -d macos`): before (as plan 9 left them) and after, the Gear tab, the Checklist tab, the Dives and Photos tabs holding scanned rows, the board joined and alone (locked and unlocked), and the gallery during a sitting; light and dark for the board's unlocked bar; phone and desktop for the board and the Gear tab. Attached through the project's current secret screenshot gist.
- [ ] **Step 5:** `gh pr create` from the template, title `feat(editing): trip gear, checklists, scans and the cylinder board edit in place, behind a switch`, body with `Refs #4527` and the screenshots; bind it, turn Auto-fix on, and follow it until every check is green, fixing each failure and review comment as it comes.

## As built

Eric approved every question and call as recommended (2026-11-19). Where the build departs from the tasks above:

- **Tabs edited in place (Call 1).** The Gear, Checklist, Dives and Photos tabs, like plan 9's Itinerary tab, are edited in place while the page is unlocked with no card frame, so `tripEditCards` gains no entry for them; their changes are held changes of their card ids, which History names. A locked tab's Scan reaches the sitting through `TripCardSlots.unlockAt(id)`, which unlocks the page and brings the card's tab forward, since opening a card that has no frame would leave it in the controller's open cards.
- **Task 2.** The checklists are held as one value, `TripChecklistsHeld` (checklists, sections, items), in one `SittingList` (`tripChecklistsList`) with one diff write (`writeTripChecklists`), rather than three lists. The widgets reach it through a small interface, `TripChecklistWrites`, with `RepositoryTripChecklistWrites` (today's writes) and `HeldTripChecklistWrites`. `createItem` gained `keepSortOrder`, `createSectionRow` an `id`; `ChecklistRows` is the typedef `saveAsTemplate(rows:)` takes. A locked checklist's menu offers only Save as template.
- **Task 3.** The board is held as one value, `TripCylindersHeld` (slots, events, the dive tank uses read for folding, and the fills' copy notes), in one `SittingList` (`tripCylindersList`), shared by the Gear tab and the board; its write (`writeTripCylinders`) covers Task 4's events too. The set bundle is `applySetBundle`, which takes closures for the board and the checklists (it replaced `applySetBundleToTrip`), so no `bundleLeadItem` was needed. The Gear tab and its add sheet write through `TripGearWrites` (`RepositoryTripGearWrites`, `HeldTripGearWrites`).
- **Task 4.** `TripBoardHold` carries the board sheets' hold callbacks. The ledger's order is `orderTripLedger`, shared with `tripCylinderLedgerProvider`.
- **Task 5.** The forecast's arithmetic is `tripFillForecastOf`, shared by `tripFillForecastProvider` and the held board, with the day's dive rounds from `tripDiveRoundsOnProvider` (keyed by trip and day); the held board sets its own timer for the forecast's next refresh, as the stored provider does. The board's `hostEditCards` is empty (drawn in place, as above); in a sitting its Add and Fill several sit in a row above the board, since a joined board's bar is the satellite bar with Done only. The entry points go through `openTripCylinderBoard`; the router test covers the board route's `onExit`.
- **Task 6.** The scanned dives are one held change (`trip.scannedDives`) whose write is `assignDivesToTrip`; the notice after Save counts them with the dates question's. The menu's loading dialog is shared as `TripScanLoadingDialog`.
- **Task 7.** `runLightroomScanForDivesInSitting` loops a trip's dives; `TripHeldPhotos` shows the held photos on the Photos tab and in the gallery. The in-sitting photo scan joined the demo seal coverage list.
- **Task 8.** The gallery is handed the trip page's controller (`sitting`), not its session, so it drops its Scan when the sitting ends underneath.
- **Review fixes.** Reordering keeps the sort orders the rows held, in their new order (`reorderedSortOrders`), so a row moved and moved back is no change; new sections are created in their held order. A section deleted in a sitting records where its items went (`itemsMovedOnDelete`), so an item stored there meanwhile follows them. The menu's scans and the sitting's share their find-and-choose steps (`chooseTripDives`, `chooseTripPhotos`); a second photo scan in a sitting leaves out the photos it holds, and after a Save that linked photos the site review the menu's scan offers is offered. The checklists read takes a trip's sections in one query (`getSectionsForTrip`).
