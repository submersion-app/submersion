# Unified editing, phase 3, plan 9: trips (header, plan, vessel, notes, documents, itinerary) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A trip opens locked and edits in place across its six tabs, behind `kUnlockRecordEditing` (issue #4527, phase 3): the header block, Plan, Vessel, Notes with the day passages, Documents and the itinerary days, held in one sitting and written as one History entry, with the candidate dives question asked at Save when the dates changed. The edit form stays until the switch-over plan; a new trip and a trip from selected dives are plan 11's.

**Architecture:** As plans 3 and 4: the page's state mixes in `RecordEditHost`, `RecordOpenUnlocked` and, first of any page, plan 1's `RecordEditTabs`; its cards are `EditCard`s keyed by `TripCardId` (shipped by plan 1), and a `TripEditSaveService` writes through `writeRecordSitting` with `TripRepository.updateTrip`, which already checks the parent and clears foreign cylinder slot links in its transaction. The vessel (a 0 or 1 row list over `liveaboard_details`) and the itinerary days are `SittingList`s written with the repositories' existing writers; sharing is plan 1's `RecordSharingSitting` with `ItemSharesSharingAdapter`, its first use. The page lifts the tab controller out of `TripDetailTabs`, so the host can say which tab is in view and bring another forward.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), drift, go_router, `flutter gen-l10n`.

**Spec:** [docs/design/specs/2026-11-18-unified-editing-phase-3-records-design.md](../specs/2026-11-18-unified-editing-phase-3-records-design.md), sections "Design: trips", "Design: what is generalised" (tabbed pages, sharing in a sitting), "Design: rules every phase 3 type follows", "Values shown nowhere today" (the trip rows) and "Testing"; on top of plans 1 to 4 ([records-1](2026-11-19-unified-editing-records-1-shared.md), [records-2](2026-11-19-unified-editing-records-2-documents-species.md), [records-3](2026-11-19-unified-editing-records-3-buddies-centres-certifications.md), [records-4](2026-11-19-unified-editing-records-4-courses.md)).

## Where plan 9 ends and plan 10 begins

The note's Delivery list gives plan 9 the header, plan, vessel, notes and day notes, documents and itinerary, and plan 10 the gear, checklists, scans and the cylinder board. Drawn on the code:

- **Plan 9:** the trip page on the host with all six tabs wired (tab in view, keep-alive, a refused card's tab brought forward); the cards `header`, `plan`, `vessel`, `notes` (with the story day page's Day plan as its frame there) and `documents` on Overview, and `itineraryDays` on Itinerary; the menu's whole-record operations; the hosts and routes.
- **Plan 10:** the cards `packedGear`, `cylinders`, `checklists`, `dives` and `photos`; the menu's Scan for dives, Scan photos and Lightroom moving to the Dives and Photos cards, and the Overview empty state's scan; the gallery's Scan; the cylinder board as a satellite, including its forecast strip's planned dives, which write itinerary days and must go through this plan's `tripItineraryDays` list.
- **Meanwhile (Question 8):** with the switch on, plan 10's parts offer no action on the trip page, so a locked trip page writes nothing on any tap.

## Questions for Eric

The plan is written to the recommended answer of each; a different answer changes only the task named.

1. **Where the header block sits on a page of tabs** (awkward in the code: the page is a fixed column of banner, tab row and tab view, and the header block is on every tab). **Recommended:** a header block row above the tab row, on every tab. Locked, it shows only the values shown nowhere today, when set (trip type other than liveaboard, location, resort, the legacy liveaboard name, "Shared with" for the owner), and draws nothing when none is set; the name and dates stay where they are (bar, pane header, hero). Unlocked, it always shows with its pencil, and its editor opens in place there, at most half the page's height with its own scroll, the tab view below it. The other way: the header block is the top of the Overview tab only (the prepare page's hero, the story's Trip page dates line), so its editor scrolls with Overview, and the other tabs offer no header. (Task 3.)
2. **Sharing on the header block** (a call in the note). **Recommended:** yes, the "Shared with" row and `ItemSharingField` in the header editor, as the form had it. The other way: a Sharing card of its own on Overview. (Task 3.)
3. **A trip's dates changed in a sitting ask the candidate dives question at Save** (a call in the note). **Recommended:** yes: Save, then (only when the start or end date differs from the stored trip) the dialog is asked before anything is written; the chosen dives are assigned in the same transaction and History entry, so Cancel or a failed Save assigns none and a revert takes them back off; dismissing the dialog saves with no dives, as today. The other way: ask after the Save has committed, as the form does, as a second History entry. (Task 7.)
4. **A trip's sitting spans its tabs; the strip shows the tab in view** (a call in the note; plan 1 built it). **Recommended:** yes. The other way: the strip offers every tab's empty cards, and picking one on another tab moves there. (Task 2.)
5. **The Vessel card shows on the prepare page for a liveaboard** (a call in the note). **Recommended:** yes, after the summary card and before Notes; today it is on the story's Trip page only. The other way: the prepare page offers Vessel only in the strip. (Task 4.)
6. **The trip day weather stays outside the rule** (a call in the note): the backfill keeps writing `trip_day_weather` on viewing, locked or not. **Recommended:** yes. (No task: nothing changes.)
7. **Which card each field is edited on** (a call in the note). **Recommended, as the note's table:** header block: name, trip type, start and end dates, return flight, part of trip, location, resort, the legacy liveaboard name, sharing; Plan: dives per day, divers sharing cylinders, expected dives, expected runtime; Vessel: vessel name, operator, vessel type, cabin, capacity, embark and disembark ports; Notes: the notes, with the day passages. Worth a look: the return flight drives the under way flight countdown, and the legacy liveaboard name sits on the header block although Vessel names the boat. (Tasks 3, 4.)
8. **Plan 10's parts while only plan 9 is built.** **Recommended:** with the switch on, the Gear and Checklist tabs offer no action (no Add, unpack, put on board, checklist edits or ticks), and the menu's scans and the Overview empty state's scan are not offered, as plan 6 made plan 7's cards read only. Starting a pre-dive session (another record) and Open board stay; the board page itself is unchanged until plan 10 makes it a satellite. With the switch off nothing changes. The other way: leave them writing at once under the switch until plan 10. (Task 2.)
9. **Day notes on the story's day page.** **Recommended:** the day page's Day plan is the Notes card's frame there: its editor holds that day's passage only, written back into the notes under the day's heading (the heading placed as the form places it, and left out while the passage is empty, so adding a heading alone is no change). The other way: Add day note opens the whole Notes editor on the Trip page with the caret under the day's heading, as the form did. (Task 5.)
10. **The Plan row and Add day note on a locked page** (they open the form today). **Recommended:** a tap unlocks with that card open (the Plan card, or the day's Day plan), the same as their addresses do (`section=planning`, `noteDay`). The other way: locked, the Plan row is read only and the day page offers no note button until the page is unlocked. (Tasks 4, 5, 8.)
11. **Site sharing onto `RecordSharingSitting`.** Plan 1 said the site moves onto the shared sharing sitting in the first phase 3 plan written after phase 2's plan 7 merged; plans 3 to 8 did not take it. **Recommended:** not in plan 9 (it changes merged site code and phase 2's tests); it goes in plan 12, the switch-over. The other way: plan 9 moves it, as `ItemSharesSharingAdapter`'s first user. (No task.)
12. **One PR** (recommended) or two (header, plan, vessel, notes and documents; then itinerary and the dates question).

## Calls made in this plan, for Eric to check

1. **The Overview layout holds for the sitting.** Prepare or story is chosen from the trip as stored (the controller's `layoutRecord`), so moving the start date across today in a sitting does not swap the page under the diver; it changes at Save.
2. **The Plan card from the trip's first day** is offered in the strip on the story's Trip page (the note), and placed after the Vessel card when added.
3. **The vessel is a 0 or 1 row `SittingList` over `liveaboard_details`**, written with `LiveaboardDetailsRepository.createOrUpdate`. The Vessel card shows while the working type is liveaboard. The save service removes the stored details (`deleteByTripId`) when the saved type is not liveaboard, in the same entry, whether or not the Vessel card was touched; switching back to liveaboard before Save keeps what the card holds.
4. **A liveaboard with no vessel details** (older data) refuses any Save until a vessel name is given, its Vessel card brought into view, as the form refused. The card shows on such a trip while unlocked, empty.
5. **Itinerary days are held** in one `SittingList`, written with the existing `saveAll` (new days, keeping the sitting's ids) and `updateDay` (changed days); no day is deleted in a sitting, as today. No new repository writer, so the agent write coverage guard is not touched.
6. **The day editor stays a bottom sheet**: `showItineraryDayEditSheet` gains a `hold` callback; in a sitting its Save hands the edited day back instead of writing (plan 3's `holdOnly` for rental notes). Its rules are unchanged (rest day forces 0, at most 12, blank stores null).
7. **Generate and Fill in missing days in a sitting** add the missing days of the working dates and type to the sitting's list, and the tab draws the sitting's days.
8. **Plan days left outside the dates** are removed at Save inside the sitting, after the held writes, best effort as today: `updateTrip` gains `dropBarePlanDays` (default true, so every other caller is unchanged), the save service passes false and runs `deleteBarePlanDaysOutside` last itself, so a revert restores them.
9. **Order at Save:** the trip row (parent check, slot links), then sharing, the vessel, the itinerary days, documents, the chosen candidate dives, then the details removal for a non-liveaboard and the bare day prune. History label `record_edit:trips:<id>:<cards>`, source "manual".
10. **The candidate dives question asks once per Save.** Its answer is a held write under one key, replaced each time it is asked and released when the dates are back to stored.
11. **Whole-record operations:** Delete for the owner, Remove from profile and Unhide otherwise, through `recordOperationRunnerOf`; History, Open in Connections, Export (a stub) and the map button work locked.
12. **An open card survives a tab change** (plan 1's keep-alive), and a refused Save brings the card's tab forward; the header block is on every tab and never moves the page.

## Global Constraints

- Plans 5 (tracks, PR #4776), 6 (gear, branch `ericgriffin/unified-editing-phase-3-6-gear-d275f5`) and 8 (sets, branch `ericgriffin/unified-editing-phase-3-8-sets-9ac70e`) run in parallel. **The one file all of them touch is `lib/core/router/app_router.dart`**: this plan changes only the `/trips` routes there (`onExit` on `/trips` and `:tripId`, the `edit` redirect), with its routing code in a new `trip_edit_routes.dart`. None of the four changes `lib/shared/`. Merge origin/main before each task with a merge (never a rebase or a force-push), adapt to any renamed names, and run a whole-repo `flutter analyze` after each merge.
- Built on the names already shipped: `RecordEditHost` (`beforeSave`, `saveAndReport`, `followStored`, `lockButton`, `editPane`, `editController.unlock`, `openCard`, `layoutRecord`), `RecordOpenUnlocked`, `RecordEditTabs` (`tabOfCard`, `tabInView`, `showTab`, `addStripEntriesOnEveryTab`), `RecordEditKeepAlive<T>`, `EditCard`, `RecordCardFrame`, `RecordCardFade`, `RecordCardPencil`, `RecordNumberRow` (`integer: true`), `AddStripEntry`, `EditSession` (`set`, `valueOf`, `applyTo`, `holdWrite`, `releaseWrite`, `remember`, `recall`, `changedCardIds`, `runHeldWrites`), `EditField`, `FieldTextBinding`, `SittingList`, `writeRecordSitting`, `RecordSittingRefusal`, `RecordSharingSitting`, `ItemSharesSharingAdapter`, `recordOperationRunnerOf`, `recordOperationBlockOf`, `DocumentsSection<T>(owner:, editing:)`, `holdDocumentLinks`, `confirmLeaveRecordSitting`, `TripCardId` with `localizedDisplayName` and `tab`, `SharingTile`.
- With `kUnlockRecordEditing` false (the default) the trip page, its list pane, table mode and routes look and behave exactly as today: no existing test changes its expectations. The page takes `unlockEditing` defaulting to the switch.
- A locked page writes nothing on any tap, on any tab. Writes to other tables in the sitting (sharing, liveaboard details, itinerary days, document links, dives assigned) are in the one History entry.
- Only what changed is written: the sitting's changes go onto the trip as stored at Save (`EditSession.applyTo`), with a field census test. `Trip.copyWith` can clear its nullable fields.
- Rules move from the form unchanged: the name is required (trimmed); the end date picker starts at the start date; a start after the end pulls the end with it; Day trip collapses the end onto the start, and a one-day Day trip's end is locked; the return flight is a date and a time stored as wall-clock-as-UTC, with a clear button; part of trip is hidden on a trip with side trips and obeys `canChooseAsParent` and `writableParentId`; the vessel name is required for a liveaboard; the integer fields (capacity included) take any integer and store zero or less as empty; divers sharing stores blank or zero or less as one; text is trimmed and blank stores null. Dates show in the active diver's format.
- No new strings are expected: every label comes from the form or the read page (the type row shows the type's name with its icon). A task that finds one missing names it, and it goes into all eleven ARB files, translated, then `flutter gen-l10n`.
- `trip_detail_page.dart` (580 lines) and `app_router.dart` do not grow past 800: editing goes in `part` files and `trip_edit_routes.dart`.
- Never use em-dashes, and never en-dashes, double hyphens or spaced hyphens as prose punctuation, in code, comments, commits or the PR. Commits, the PR and files follow the repository guide's Attribution section.
- Imports grouped dart, flutter, packages, local. `dart format` changed files before each commit. Anything acting after an `await` checks `mounted` and reads `ref` and `context` before its first `await`.
- Test runs: only the test FILES a task writes or changes, by path. Never a folder, never the whole suite, never `test/architecture/` or `test/shared/` by hand: the pre-push hook runs them.
- Never `--build-filter` build_runner. Never let a debug build open `~/Documents/Submersion/submersion.db`; screenshots come from headless widget goldens.

## Review Focus

1. **The trip shortened in a sitting with an itinerary day edited outside the new dates.** Save writes the edited day, then drops only the bare plan days outside the dates, in one entry; reverting it restores the dropped days and the dates. Pinned in Task 6.
2. **A liveaboard made a resort trip, then Cancel; then again with Save.** Cancel keeps the vessel details; Save removes them in the same entry, and a revert brings them back. Pinned in Task 4.
3. **A Save refused for a card on another tab** (the Vessel card's missing name while the Itinerary tab is in view): the page moves to Overview and the Vessel card shows itself; nothing is written. Pinned in Task 4.
4. **Dates changed, dives chosen, then the Save fails.** Nothing is assigned; the next Save asks again, once; with the dates put back, no question and no assignment. Pinned in Task 7.
5. **Locked with the switch on, no tap writes on any tab**: no Generate, day cards open no sheet, the Gear and Checklist tabs offer no action, the menu offers no scan, and the Plan row and Add day note only unlock (Question 10). Pinned in Task 2, with the itinerary in Task 6.

## Form test accounting

The form stays until the switch-over plan, so no test is deleted here. Each case about editing an existing trip gets its counterpart in this plan; cases about a new trip or a draft are plan 11's.

| Form test (`test/features/trips/presentation/pages/`) | Case | Counterpart |
| --- | --- | --- |
| `trip_edit_page_test.dart` | name, dates, location, resort, liveaboard name, notes fields displayed; Edit title; loads existing data | Task 3, `the header editor shows every header value`; Task 4 and 5 editors |
| | Save in the bar is the only save action | none needed: the shared `RecordEditBar` |
| | validation error when the name is empty | Task 3, `a blank name cannot be saved` |
| | a fractional expected dive count blocks save | Task 4, `a fractional expected dive count refuses the Save` |
| | the day heading placed with the caret under it; the added heading alone is not a change; a save for another reason leaves the empty heading out; words under the heading are saved with it; a tap that only moves the caret is not a change; untouched Notes saved as loaded | Task 5, one case each |
| | opens at the top; with Planning below the fold; scrolls Planning into view | Task 8, `opened at section=planning, the Plan card is open and in view` |
| | duration counts calendar days across a spring-forward | Task 3, `the editor's duration counts calendar days across a spring-forward` |
| | type selector describes the type; Day Trip collapses dates; keeps end on a moved start; locks the end; a stored multi-day Day Trip keeps its end editable; leaving Day Trip keeps the dates | Task 1 rules and Task 3 editor, one case each |
| | sharing: hidden with one diver; un-share asks; unchanged stores no share change; a refused change says who may change it; an owner save clears stale share rows; a failed read never unshares; locked for another profile, while switching, while unreadable; open for the owner | Task 3, one case each (the refusal now fails the whole Save, as every phase 3 sharing does) |
| | vessel fields shown for a liveaboard; vessel required; vessel type selection | Task 4, one case each |
| | start and end date pickers open; end picker opens at the start date | Task 3, one case each |
| | save existing trip calls updateTrip | Task 1, service cases |
| | Add Trip title; new trip defaults; sharing default for a new trip; save new trip calls addTrip | plan 11 |
| `trip_edit_page_part_of_test.dart` | choosing a larger trip saves it; a trip with side trips cannot become one | Task 3, one case each |
| `trip_edit_page_type_change_test.dart` | a liveaboard made a resort trip keeps its itinerary | Task 4, `a liveaboard made a resort trip keeps its itinerary and loses its vessel` |
| `trip_edit_page_draft_test.dart`, `trip_edit_page_retry_test.dart` | draft and create retry | plan 11 |

## Preparation

- [ ] The worktree is initialised (`git submodule update --init --recursive`, `flutter pub get`); generate code unfiltered in the background if fresh: `dart run build_runner build --delete-conflicting-outputs`.
- [ ] `git fetch origin main`, merge it, and run `flutter analyze` on the whole repository. Expected: clean.
- [ ] Before any code changes, take the "before" goldens (headless widget tests, switch off): the trip page at phone and desktop width on the prepare Overview of a liveaboard, the story's Trip page, a day page with a day note, and the Itinerary tab.

## File Structure

New (`lib/features/trips/...`):

| File | Responsibility |
| --- | --- |
| `data/services/trip_edit_save_service.dart` | `TripEditSaveService`, provider |
| `presentation/editing/trip_edit_fields.dart` | Fields and the form's rules, pure |
| `presentation/editing/trip_header_card_editor.dart` | The header block's editor and its locked rows |
| `presentation/editing/trip_overview_card_editors.dart` | Plan, Vessel, Notes and Day plan editors |
| `presentation/editing/trip_vessel_sitting.dart` | `tripVesselDetails` list |
| `presentation/editing/trip_itinerary_sitting.dart` | `tripItineraryDays` list, pure edits |
| `presentation/editing/trip_edit_cards.dart` | `tripEditCards`, `tripOptionalCards` |
| `presentation/pages/trip_detail_page_editing.dart` | `part`: the page's use of the host and tabs |
| `presentation/pages/trip_detail_page_menu.dart` | `part`: the menu and its operations, moved out |
| `presentation/pages/trip_edit_routes.dart` | Redirect, pane, open at a card |

Modified: `trip_detail_page.dart`, `trip_detail_tabs.dart`, `trip_overview_tab.dart`, `overview/trip_prepare_overview.dart`, `overview/trip_overview_summary_card.dart`, `story/trip_story_view.dart`, `story/trip_story_trip_page.dart`, `story/trip_story_day_page.dart`, `story/trip_story_day_plan.dart`, `story/trip_vessel_section.dart`, `trip_itinerary_tab.dart`, `itinerary/itinerary_day_card.dart`, `itinerary/trip_itinerary_generate_button.dart`, `itinerary_day_edit_sheet.dart`, `trip_gear_tab.dart` and the checklist panel (`readOnly` only, Question 8), `helpers/trip_day_note_editing.dart`, `trip_repository.dart` (`dropBarePlanDays`), `trip_list_page.dart`, `app_router.dart`, `test/architecture/markdown_notes_adoption_test.dart` (new Markdown editors; not run by hand).

---

### Task 1: The trip save service and fields

**Files:**
- Create: `lib/features/trips/data/services/trip_edit_save_service.dart`, `lib/features/trips/presentation/editing/trip_edit_fields.dart`
- Modify: `lib/features/trips/data/repositories/trip_repository.dart` (`updateTrip` gains `dropBarePlanDays`)
- Test: `test/features/trips/data/services/trip_edit_save_service_test.dart`, `test/features/trips/presentation/editing/trip_edit_fields_test.dart`

**Interfaces:**
- Produces:
  - `Future<void> TripRepository.updateTrip(Trip trip, {String? actingDiverId, bool dropBarePlanDays = true})`: false skips the bare plan day cleanup, nothing else.
  - `class TripEditSaveService { TripEditSaveService(TripRepository trips, ItineraryDayRepository days, LiveaboardDetailsRepository vessels); Future<({Trip before, Trip after})?> save({required String tripId, required Trip Function(Trip stored) apply, required Iterable<String> changedCardIds, required String? actingDiverId, Future<void> Function()? alsoWrite, bool alsoWriteIsAChange = false}) }`: `writeRecordSitting<Trip>(table: 'trips', read: getTripById, write: (_, merged) => updateTrip(merged, actingDiverId:, dropBarePlanDays: false))`, then inside the same sitting after `alsoWrite`: `vessels.deleteByTripId` when the merged type is not liveaboard and the stored type was (Call 3), then `days.deleteBarePlanDaysOutside(merged dates)` in a try that logs (Call 8). `tripEditSaveServiceProvider`.
  - Fields, card `header`: `tripNameField` (`String`, trimmed), `tripTypeField` (`TripType`), `tripDatesField` (`({DateTime start, DateTime end})`, one value so a start that pulls the end is one change), `tripReturnFlightField` (`DateTime?`), `tripParentField` (`String?`), `tripLocationField`, `tripResortField`, `tripLiveaboardNameField` (`String?`, blank stores null); card `plan`: `tripDivesPerDayField`, `tripExpectedDivesField`, `tripExpectedRuntimeField` (`int?`, zero or less stores null), `tripDiversSharingField` (`int`, blank or zero or less stores 1); card `notes`: `tripNotesField` (`String`, trimmed at Save).
  - Rules, pure: `bool tripNameValid(String)`; `({DateTime start, DateTime end}) tripStartPicked(DateTime start, {required DateTime end, required TripType type})` (Day trip or a start after the end puts the end on the start); `({DateTime start, DateTime end}) tripTypePicked(TripType type, ({DateTime start, DateTime end}) dates)` (Day trip collapses); `bool tripEndLocked(TripType type, ({DateTime start, DateTime end}) dates)` (Day trip of one calendar day); `DateTime tripReturnFlightAt(DateTime date, TimeOfDay time)` (UTC wall clock); `int? tripPositiveOrNull(num? value)`; `String tripTypeDescription(AppLocalizations, TripType)` (moved from the form, which keeps a call to it).
- Consumes: `writeRecordSitting`.

- [ ] **Step 1: Write the failing tests** (test database; trip `t1` "Red Sea", liveaboard, 2026-06-01 to 2026-06-08, vessel details `MV Blue`, three itinerary days one of which is a bare plan day on 2026-06-08, two dives of `me`):
  - Service: `writes a location change as one History entry` (label `record_edit:trips:t1:header`); census `a field the sitting did not touch keeps its newer value`, one assertion per column `updateTrip` writes (name, dates, location, resort, liveaboard name, notes, type, return flight, expected dives, runtime, divers sharing, dives per day, parent); `clearing the return flight stores null`; `a type made resort removes the vessel details in the same entry` (Review Focus 2); `the end moved to 2026-06-07 drops the bare day of 2026-06-08 in the same entry, and reverting restores it` (Review Focus 1); `a parent chosen clears foreign slot links on the trip's dives`; `unchanged returns null`; `a trip that has gone throws`.
  - Repository: `updateTrip with dropBarePlanDays false keeps a bare day outside the dates`.
  - Fields: `a start after the end pulls the end`; `a Day trip keeps its end on a moved start`; `choosing Day trip collapses the dates`; `leaving Day trip keeps the dates`; `a one-day Day trip locks its end`; `a stored multi-day Day trip keeps its end editable`; `the return flight is wall clock as UTC`; `zero and below store null`; `divers sharing blank or zero stores one`; `a blank name is invalid`.
- [ ] **Step 2:** Run the two files and `trip_repository_test.dart`. Expected: fail to compile.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them. Expected: all pass.
- [ ] **Step 5: Commit** `feat(trips): save a trip's editing sitting as one History entry`.

### Task 2: The trip page on the host, across its tabs

**Files:**
- Create: `trip_edit_cards.dart`, `trip_detail_page_editing.dart` (part), `trip_detail_page_menu.dart` (part)
- Modify: `trip_detail_page.dart`, `trip_detail_tabs.dart`, `trip_overview_tab.dart`, `trip_prepare_overview.dart`, `trip_story_trip_page.dart`, `trip_gear_tab.dart`, the checklist panel, `test/architecture/markdown_notes_adoption_test.dart`
- Test: `test/features/trips/presentation/pages/trip_detail_page_unlock_harness.dart`, `trip_detail_page_unlock_test.dart`

**Interfaces:**
- Produces:
  - `class TripDetailPage extends ConsumerStatefulWidget { const TripDetailPage({required String tripId, bool embedded = false, VoidCallback? onDeleted, bool unlockEditing = kUnlockRecordEditing, bool openUnlocked = false, TripEditSection? openSection, TripNoteDay? openNoteDay, VoidCallback? onSittingEnded}) }` on `RecordEditHost<TripDetailPage, Trip>`, `RecordOpenUnlocked` and `RecordEditTabs` (with `SingleTickerProviderStateMixin`). It owns the `TabController` (six tabs, back to Overview when `tripId` changes, as the keyed `DefaultTabController` did) and the story's `ValueNotifier<TripStorySelection?>`, and redraws when the index changes. `tabOfCard(id)`: `TripCardId.values.byName(id).tab?.index`; `showTab` animates the controller; `followStored(tripByIdProvider(id))`; `editingTitle`: `recordEdit_editingTitle(trip.name)`; `rereadStored` invalidates `tripByIdProvider` and `tripWithStatsProvider`. Its bar and pane header take `host.lockButton`; with the switch on the Edit buttons unlock. `saveSitting` passes the active diver as `actingDiverId`.
  - `TripDetailTabs({required TripWithStats tripWithStats, TabController? controller, ValueNotifier<TripStorySelection?>? storySelection, ...})`: with a controller it uses it and wraps each tab view in `RecordEditKeepAlive<Trip>`; without one, as today.
  - `tripEditCards` (`Map<TripCardId, EditCard<Trip>>`) gains a card per task; this task adds `notes` (`MarkdownNotesField` over `tripNotesField`; `isEmpty`: blank) and `documents` (`DocumentsSection<Trip>(owner:, editing:)`, links held by `holdDocumentLinks` in `onSittingStart`). `tripOptionalCards`: notes here; plan and vessel follow in Task 4.
  - The Overview chooses prepare or story from `editController.layoutRecord ?? stored` (Call 1).
  - The menu moves into `trip_detail_page_menu.dart`; with the switch on, Delete, Remove and Unhide run through `recordOperationRunnerOf` and are disabled locked under "Unlock to use these"; History, Open in Connections and Export work locked; Scan for dives, Scan photos and Lightroom are not offered (Question 8).
  - `TripGearTab` and the checklist panel take `readOnly` (switch on): no Add, unpack, put on board, checklist edits or ticks; the pre-dive session button and Open board stay. `TripOverviewTab`'s empty state offers no scan with the switch on.
- Consumes: Task 1.

- [ ] **Step 1: Write the failing tests** (harness: a trip with notes, a document, packed gear and a checklist; recording fakes for every trip repository):
  - `with the switch off there is no lock and the menu is unchanged`; `locked, no tap on any tab writes` (Review Focus 5: each tab visited, every button tapped; the fakes record nothing); `notes and a document detach in one sitting save as one entry and lock`; `empty Notes is offered in the strip on Overview and not on Itinerary` (Question 4); `an open Notes card survives a visit to the Itinerary tab`; `with the switch on the menu has no scans, and Delete is disabled locked`; `unlocked and clean, Delete asks and deletes`; `the Gear and Checklist tabs offer no action with the switch on` (Question 8); `a start date moved past today in a sitting keeps the prepare page until Save` (Call 1); `Cancel with changes asks first`.
- [ ] **Step 2:** Run the test file. Expected: fails.
- [ ] **Step 3:** Implement; add the notes editor to the Markdown guard's list.
- [ ] **Step 4:** Run it, and unchanged `trip_detail_page_test.dart`, `trip_detail_page_sharing_test.dart`, `trip_detail_side_trip_delete_test.dart`, `trip_detail_checklist_test.dart`, `trip_detail_tabs_test.dart`, `trip_overview_tab_test.dart`, `trip_prepare_overview_test.dart`, `trip_story_trip_page_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(trips): unlock a trip page to edit it in place, behind a switch`.

### Task 3: The header block, with sharing

**Files:**
- Create: `lib/features/trips/presentation/editing/trip_header_card_editor.dart`
- Modify: `trip_edit_cards.dart`, `trip_detail_page_editing.dart`, `trip_detail_page.dart`
- Test: `test/features/trips/presentation/editing/trip_header_card_editor_test.dart`, `trip_detail_page_unlock_test.dart`

**Interfaces:**
- Produces:
  - `const tripSharing = RecordSharingSitting<Trip, ItemSharing>(key: 'trip.sharing', cardId: 'header', recordIdOf: <id>)`, loaded in `onSittingStart` with `ItemSharesSharingAdapter(repository, SharedItemKind.trip)` when there are two or more profiles.
  - `TripHeaderRows({required Trip trip, EditSession<Trip>? session})`: the locked rows (Question 1): the type's icon and name when not liveaboard, location, resort, legacy liveaboard name, and `SharingTile` for the owner over the sitting's sharing or `itemSharingProvider`; nothing when none is set.
  - `TripHeaderCardEditor({required EditSession<Trip> session})`: the type's `SegmentedButton` with its description, name (required), `PartOfTripField` (hidden when `hasSideTripsProvider`), start and end date tiles (`showAppDatePicker`, bounds as the form; the end locked by `tripEndLocked`), the duration in calendar days, the return flight tile with clear, location, resort, legacy liveaboard name, and `ItemSharingField` over `tripSharing` (locked while unread, for another profile, or while the profile is unknown, as the form's `_mayShare`). Inside a `ConstrainedBox` of half the page's height with its own scroll.
  - The `header` card: `isEmpty` false, `isValid`: `tripNameValid`; its frame wraps `TripHeaderRows` above the tab row, on every tab (`tabOfCard` null). Shown locked only when it has a row.
- Consumes: Tasks 1 and 2.

- [ ] **Step 1: Write the failing tests**:
  - Editor: `the header editor shows every header value`; `each value sets only the header card`; `choosing Day Trip collapses the dates`; `a Day Trip keeps its end on a moved start`; `a one-day Day Trip locks its end`; `a stored multi-day Day Trip keeps its end editable`; `leaving Day Trip keeps the dates`; `the type selector describes the selected type`; `the editor's duration counts calendar days across a spring-forward`; `tapping start date opens the date picker`; `the end date picker opens at the start date`; `choosing a larger trip sets the parent`; `a trip with side trips offers no larger trip`.
  - Sharing (as the form's cases): `hidden with one diver`; `un-sharing asks first`; `unchanged sharing holds nothing`; `a stale share row is rewritten by the owner's Save`; `a failed read never unshares at Save`; `locked for another profile, naming the owner`; `locked while the profile is switching`; `locked while the profile cannot be read`; `open for the owner`; `a refused change fails the whole Save with the sharing message and writes nothing`.
  - Page: `locked, the header shows location, resort and the type only when set` (and nothing for a liveaboard with none); `name, dates and sharing in one sitting save as one entry`; `a blank name cannot be saved`; `the header editor opens above the tab row on every tab`.
- [ ] **Step 2:** Run the two files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them, and unchanged `trip_detail_page_sharing_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(trips): a trip's header and sharing wait for Save`.

### Task 4: Plan and Vessel

**Files:**
- Create: `trip_overview_card_editors.dart` (Plan, Vessel), `trip_vessel_sitting.dart`
- Modify: `trip_edit_cards.dart`, `trip_detail_page_editing.dart`, `trip_overview_summary_card.dart`, `trip_prepare_overview.dart`, `trip_story_trip_page.dart`, `trip_vessel_section.dart`
- Test: `test/features/trips/presentation/editing/trip_overview_card_editors_test.dart`, `trip_vessel_sitting_test.dart`, `trip_detail_page_unlock_test.dart`, `trip_overview_summary_card_test.dart` (existing; add cases)

**Interfaces:**
- Produces:
  - `final tripVesselDetails = SittingList<Trip, LiveaboardDetails>(key: 'trip.vessel', cardId: 'vessel', read: <getByTripId as 0 or 1 rows>, write: (trip, loaded, current) => <createOrUpdate(current.single) when trip is liveaboard and current is not empty>)`. `LiveaboardDetails tripVesselDraft(String tripId, {DateTime? now})` for a trip with none.
  - `TripPlanCardEditor({required EditSession<Trip> session})`: four `RecordNumberRow`s (`integer: true`) for dives per day, divers sharing, expected dives, expected runtime, with the form's labels and hints. The Plan card shows on the prepare page in the summary card's Plan row place; read, it shows the row as today plus expected dives and runtime when set (decision 7). From the first day it is in `tripOptionalCards` on the story's Trip page (Call 2).
  - `TripVesselCardEditor({required EditSession<Trip> session})`: vessel name (required), operator, vessel type dropdown (the form's four), cabin, capacity (`RecordNumberRow`, integer), embark and disembark ports, each setting the one row of `tripVesselDetails`. The `vessel` card shows while the working type is liveaboard, on the prepare page after the summary card (Question 5) and on the story's Trip page as today; `isValid`: a vessel name while liveaboard (Call 4). `TripVesselSection` takes the sitting's row when there is one.
  - The summary card's Plan row, with the switch on: unlocked, opens the Plan card; locked, unlocks with it open (Question 10).
- Consumes: Tasks 1 to 3.

- [ ] **Step 1: Write the failing tests**:
  - Editors: `the Plan editor's rows set only the plan card`; `a fractional expected dive count refuses the Save`; `vessel fields are shown for a liveaboard`; `the vessel type selection is held`; `capacity of zero stores empty`.
  - Vessel list: `a trip with no details reads none`; `a changed vessel is written with createOrUpdate at Save`; `nothing is written for a trip that is no longer a liveaboard`.
  - Page: `the Vessel card shows on the prepare page for a liveaboard` (Question 5); `a vessel name and the plan in one sitting save as one entry`; `the vessel name is required for a liveaboard`; `a Save refused for the vessel name while Itinerary is in view moves to Overview and shows the card` (Review Focus 3); `a liveaboard made a resort trip, then Cancel: the details stay`; `the same, then Save: the details go in the same entry, and reverting restores them` (Review Focus 2); `a liveaboard made a resort trip keeps its itinerary and loses its vessel`; `expected dives and runtime show on the Plan card when set`; `from the first day, Plan is offered in the strip`.
  - Summary card: `locked with the switch on, the Plan row unlocks with the Plan card open`; with the switch off, its existing cases unchanged.
- [ ] **Step 2:** Run the four files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them, and unchanged `trip_vessel_section_test.dart`, `liveaboard_details_repository_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(trips): a trip's plan and vessel wait for Save`.

### Task 5: Day notes on the story's day page

**Files:**
- Modify: `trip_overview_card_editors.dart` (Day plan), `helpers/trip_day_note_editing.dart`, `trip_story_view.dart`, `trip_story_day_page.dart`, `trip_story_day_plan.dart`, `trip_detail_page_editing.dart`
- Test: `test/features/trips/presentation/helpers/trip_day_note_editing_test.dart` (existing; add cases), `test/features/trips/presentation/editing/trip_overview_card_editors_test.dart`, `trip_detail_page_unlock_test.dart`

**Interfaces:**
- Produces:
  - `String withDayPassage(DayNotePlacement placement, String passage)`: the placement's text with the day's passage replaced by `passage`, then `placement.toSave(...)`, so an empty passage under a heading the placement added leaves the notes as they were (Question 9).
  - `TripDayPlanCardEditor({required EditSession<Trip> session, required TripNoteDay day})`: on open, `placeDayNoteIn(working notes, day, l10n)` kept in the session (`remember`, keyed by the day's date); one text field holding the passage, caret at its end; each edit sets `tripNotesField` to `withDayPassage`. The day page's Day plan sits in a `notes` card frame, shown while unlocked even when it has no content.
  - The day page's note button, with the switch on: unlocked, opens the `notes` card; locked, unlocks with it open (Question 10).
- Consumes: Tasks 1 and 2.

- [ ] **Step 1: Write the failing tests**:
  - Helper: `a passage written under an added heading keeps the heading`; `an empty passage leaves the notes as they were`; `a passage replaced under an existing heading changes only that passage`.
  - Editor and page (the form's cases): `the day heading is placed with the caret under it`; `the added heading alone is not a change` (Save disabled); `a Save for another reason leaves the empty heading out`; `words under the heading are saved with it`; `a tap that only moves the caret is not a change`; `untouched notes are saved as they were loaded`; `the day passage and the trip page's Notes are one change of Notes`; `locked, Add day note unlocks with the Day plan open`.
- [ ] **Step 2:** Run the three files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them, and unchanged `trip_story_day_page_test.dart`, `trip_story_day_page_trip_notes_test.dart`, `trip_day_notes_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(trips): a day's note on the trip story waits for Save`.

### Task 6: The itinerary held in the sitting

**Files:**
- Create: `lib/features/trips/presentation/editing/trip_itinerary_sitting.dart`
- Modify: `trip_itinerary_tab.dart`, `itinerary_day_card.dart`, `trip_itinerary_generate_button.dart`, `itinerary_day_edit_sheet.dart`, `trip_edit_cards.dart`, `trip_detail_page_editing.dart`
- Test: `test/features/trips/presentation/editing/trip_itinerary_sitting_test.dart`, `trip_itinerary_tab_test.dart`, `itinerary_day_card_test.dart`, `trip_itinerary_generate_button_test.dart` (existing; add cases), `trip_detail_page_unlock_test.dart`

**Interfaces:**
- Produces:
  - `final tripItineraryDays = SittingList<Trip, ItineraryDay>(key: 'trip.itinerary', cardId: 'itineraryDays', read: <getByTripId>, write: (trip, loaded, current) => <saveAll(days in current not in loaded), then updateDay(each day in both that differs)>)` (Call 5).
  - Pure: `List<ItineraryDay> withMissingDays(List<ItineraryDay> days, Trip working)` (`ItineraryDay.generateForTrip` over the working dates and type, the dates not covered); `List<ItineraryDay> withDayEdited(List<ItineraryDay> days, ItineraryDay edited)`.
  - `showItineraryDayEditSheet(..., void Function(ItineraryDay edited)? hold)`: with `hold`, Save validates as today and hands the day back without writing.
  - `TripItineraryTab({required String tripId, EditSession<Trip>? editing, bool readOnly = false})`: with a session it draws the sitting's days (numbered through `numberItineraryDays` with the working trip), the generate button adds to the list, a day tap opens the sheet in hold mode; `readOnly` (locked with the switch on) offers no generate and no sheet; neither, as today. The tab sits in the `itineraryDays` card frame.
- Consumes: Tasks 1 and 2.

- [ ] **Step 1: Write the failing tests**:
  - Sitting: `missing days follow the working dates and type`; `a day edited twice is one change`; `new days keep the sitting's ids at Save`; `a changed day is written with updateDay, an unchanged one not at all`.
  - Tab, card, button: `locked with the switch on, no generate and no sheet` (Review Focus 5); `in a sitting, generate writes nothing until Save`; `in a sitting, a day saved in the sheet writes nothing until Save`; `a rest day still forces zero dives in hold mode`; with the switch off, the existing cases unchanged.
  - Page: `days generated and a day edited save as one entry with the header`; `the same, then Cancel: nothing written`; `the end moved earlier with a non-bare day edited outside the new dates: Save keeps the edited day, drops the bare one, one entry, and reverting restores both` (Review Focus 1); `dates widened in a sitting offer the new missing days`.
- [ ] **Step 2:** Run the five files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them, and unchanged `itinerary_day_repository_test.dart`, `itinerary_dive_row_test.dart`, `trip_itinerary_open_at_today_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(trips): a trip's itinerary days wait for Save`.

### Task 7: The candidate dives question at Save

**Files:**
- Modify: `trip_detail_page_editing.dart`
- Test: `trip_detail_page_unlock_test.dart`

**Interfaces:**
- Produces: the page's `beforeSave` override: when the working dates differ from the stored ones and the active diver is known, `findCandidateDivesForTrip(tripId, working start, working end, diverId)`; with candidates, `showDiveAssignmentDialog`; the chosen ids are held under `trip.assignDives` (`session.holdWrite`, replacing any earlier answer), whose write is `TripRepository.assignDivesToTrip(ids, tripId)`; no candidates, or the dates back to stored, release it (Call 10). Always returns true: dismissing the dialog saves with no dives. After a Save that assigned dives, the "N dives added" snackbar and the old trips' providers invalidated, as the form.
- Consumes: Tasks 1 and 3.

- [ ] **Step 1: Write the failing tests**: `dates changed: the dialog is asked once and the chosen dives are assigned in the same entry` (Question 3); `reverting the entry takes them back off`; `dismissing the dialog saves the dates with no dives`; `unchanged dates ask nothing`; `a failed Save assigns nothing and the next Save asks again` (Review Focus 4); `dates put back after a refused Save assign nothing`; `Cancel after the question assigns nothing`.
- [ ] **Step 2:** Run the test file. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run it, and unchanged `test/features/trips/presentation/widgets/dive_assignment_dialog_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(trips): changing a trip's dates asks about its dives at Save`.

### Task 8: Trip hosts, routes and opening at a card

**Files:**
- Create: `lib/features/trips/presentation/pages/trip_edit_routes.dart`
- Modify: `trip_detail_page.dart`, `trip_detail_page_editing.dart`, `trip_list_page.dart`, `helpers/trip_edit_navigation.dart`, `app_router.dart`
- Test: `trip_detail_page_unlock_test.dart`, `test/features/trips/presentation/pages/trip_list_page_test.dart`, `test/features/trips/presentation/helpers/trip_edit_navigation_test.dart` (existing; add cases), `test/core/router/app_router_test.dart`

**Interfaces:**
- Produces: `String? tripEditLocation(String tripId, {TripEditSection? section, TripNoteDay? noteDay, bool unlockEditing = kUnlockRecordEditing})` (`/trips/<id>?mode=edit` with the same `section`, `noteDate` and `noteDay` query, else null); `String? tripEditRedirect(BuildContext, GoRouterState)`; `Widget tripEditPane(BuildContext, String id, void Function(String) onSaved, VoidCallback onCancel, {VoidCallback? onDeleted, TripEditSection? section, TripNoteDay? noteDay, bool unlockEditing = kUnlockRecordEditing})` (the page unlocked with the switch, `onSittingEnded: onCancel`; else the form), used by both `editBuilder`s; `createBuilder` and `/trips/new` stay the form. The detail route passes `openUnlocked`, `openSection` and `openNoteDay` from the query; once opened unlocked the page opens the `plan` card, or for a note day selects that day in the story and opens `notes` (Task 5's Day plan). `openTripEdit` with the switch on unlocks the page it is called from instead of navigating. `/trips` and `:tripId` get `onExit: confirmLeaveRecordSitting`; the gallery and cylinder board routes are unchanged (plan 10).
- Consumes: Tasks 2 to 6.

- [ ] **Step 1: Write the failing tests**: `opened with mode=edit, the page is unlocked`; `opened at section=planning, the Plan card is open and in view`; `opened at a note day, that day is shown with its Day plan open`; `the pane's and table mode's edit open the page unlocked, Cancel returns to view`; `the pane's Save updates the trip and creates none`; `the edit address redirects with its query with the switch on, not off`; `with the switch off the pane opens the form`; `leaving with changes asks first`.
- [ ] **Step 2:** Run the four files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them. Expected: all pass.
- [ ] **Step 5: Commit** `feat(trips): edit addresses and panes open the trip page unlocked`.

### Task 9: Push, open the pull request, track it to green

- [ ] **Step 1:** Merge origin/main once more; whole-repo `flutter analyze`; `dart format` every changed file. Expected: clean.
- [ ] **Step 2:** Push in the background (`git push -u origin HEAD`), touching no `lib/` or `test/` file while it runs. Fix any hook failure in its own commit.
- [ ] **Step 3:** `/code-review xhigh --fix --max-findings all`; fix every valid finding test first; push again.
- [ ] **Step 4:** Screenshots from headless widget-test goldens with the switch on (never `flutter test ... -d macos`): the page locked (before and after) on the prepare Overview of a liveaboard with its header rows; unlocked with the header editor open, the Plan and Vessel editors open, a day page's Day plan editor, the Itinerary tab holding a generated day; light and dark for the unlocked bar; phone and desktop for the pane. Attached through the project's current secret screenshot gist.
- [ ] **Step 5:** `gh pr create` from the template, title `feat(editing): trips edit in place (header, plan, vessel, notes, itinerary), behind a switch`, body with `Refs #4527` and the screenshots; bind it, turn Auto-fix on, and follow it until every check is green, fixing each failure and review comment as it comes.
