# Unified editing, phase 3, plan 6: gear items, plain cards and collections Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A gear item opens locked and edits in place, every plain card and every collection on it held in one sitting written as one History entry, behind `kUnlockRecordEditing` (issue #4527, phase 3). That includes what the item page writes at once today: Mark purchased, sharing, moves and past moves, service clocks and service records, photos and the cover, check-ins, legacy files, documents and the dive computer's settings. The edit form stays until the switch-over plan; a new item and a clone are plan 11's; the passports, twin sets, components and condition findings are plan 7's.

**Architecture:** As plans 3 and 4: the page's state mixes in `RecordEditHost` and `RecordOpenUnlocked`, its cards are `EditCard`s keyed by `GearItemCardId` (shipped by plan 1), and a `GearItemEditSaveService` writes through `writeRecordSitting` with `EquipmentRepository.updateEquipment`, which already writes the row, its attributes, the service clock baselines and the device mirrors in one transaction. Each collection is a `SittingList` (tags, service clocks, service records, check-ins, legacy files) or an existing held piece (the move flow's plan and write split from plan 3, `RecordSharingSitting` with `EquipmentSharesSharingAdapter` from plan 1, `record_media_sitting.dart` with a new equipment writer, `holdDocumentLinks`). Writes to other records (the dive computer row, parts moved with the item, the status the move flow sets, places created for a buddy) are held writes in the same transaction, filed under the item by its History label. In-card whole-record operations are gated by `recordOperationReason`, as on the dive page.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), drift, go_router, `flutter gen-l10n`.

**Spec:** [docs/design/specs/2026-11-18-unified-editing-phase-3-records-design.md](../specs/2026-11-18-unified-editing-phase-3-records-design.md), sections "Design: gear items", "Design: rules every phase 3 type follows", "Values shown nowhere today" (the custom reminder) and "Testing"; on top of plans 1 to 4 ([records-1](2026-11-19-unified-editing-records-1-shared.md), [records-2](2026-11-19-unified-editing-records-2-documents-species.md), [records-3](2026-11-19-unified-editing-records-3-buddies-centres-certifications.md), [records-4](2026-11-19-unified-editing-records-4-courses.md)).

## Where plan 6 ends and plan 7 begins

The note's Delivery section gives plan 7 "the passports as satellites, twin sets, components, findings in the change log". So plan 6 takes every other card of the note's gear item table: Header block, Dive computer, Details (sharing included), Transmitter, Location, Service clocks (custom reminder included), Parts, Photos, Observations, Legacy files, Service history, Notes, Documents, and the whole-record operations Delete, Transfer, Replace a part, Apply to existing dives, and the dive computer's merge and re-parse all.

Plan 7 takes the Twin set, Components and Condition findings cards, the `equipment_findings` change log work, the two passport pages and the passport entry cards. Plan 6 adds optional parameters (`editing`, `readOnly`, `operationReason`) to `ServiceClocksCard` and `EquipmentLocationCard`, which the gear passport page also shows; that page passes none, so it is unchanged until plan 7 makes it a satellite.

Clone stays on the menu and keeps opening the form (`/equipment/new?cloneFrom=`), working locked: clone extras as prefills are plan 11's, so the note's "Clone extras become prefills" call is not touched here.

## Questions for Eric

The plan is written to the recommended answer of each; a different answer changes only the task named.

1. **Plan 7's cards in the meantime.** With the switch on and only plan 6 built, the Twin set, Components and Condition findings cards would still write at once. **Recommended:** with the switch on they offer no action, locked or unlocked, until plan 7 gives them editors (a `readOnly` flag each; with the switch off, unchanged). The passport entry cards keep opening the passports, which keep writing at once until plan 7. The other way: leave them writing at once under the switch until plan 7 lands. (Task 2.)
2. **Sharing on Details** (a call in the note). **Recommended:** on Details, where the "Shared with" row is today. The other way: on the header block, as a trip's is. (Task 4.)
3. **Replace a part, Apply to existing dives, and the dive computer's merge and re-parse all are whole-record operations** (a call in the note): each needs the unlock, keeps its confirmation, acts at once, and is disabled while the sitting has unsaved changes. **Recommended:** as the note says. Replace creates a new item and retires the old one, Apply rewrites dives, merge repoints dives and deletes computer rows, re-parse rewrites dives one by one; none is a value of this item. The other way: hold one or more of them until Save. (Tasks 5, 10.)
4. **The clock sync override is not in the database.** The confirmed call puts the computer's favourite, clock sync override and auto-download behind the item's lock, written with its sitting. Favourite and auto-download are `dive_computers` columns and go in the sitting's transaction and History entry. The clock sync override (and its "Check again") is a preference stored on this device only (`ClockSyncSettingsNotifier`, SharedPreferences), never synced or logged. **Recommended:** held in the sitting like the rest, written just after the commit (so a failed Save leaves it as it was), and not in the History entry, since History records only the database; "Check again" works locked, as it forgets a probe result rather than a value the diver set. The other way: leave the clock sync controls outside the lock, writing at once as today. (Task 5.)
5. **The transmitter page's serial copy** (a call in the note). Plan 6 owns the item's serial, on Details. **Recommended:** keep it: after a key saves, the transmitter page copies the key's serial onto an item that has none, and never overwrites one. With the item unlocked, a serial the diver typed in the sitting wins at Save; an untouched serial keeps the copied one (the field census). The other way: the copy stops, and the diver types the item's serial on Details. (No task: nothing changes.)
6. **Clock statuses while unlocked.** **Recommended:** the due, overdue and "counting since" rows stay as stored until Save; clocks added, changed, paused or removed in the sitting show in the open Service clocks editor with the changed dot, as plan 3's currency status does. The other way: a live preview from the held clocks and held service records. (Task 7.)
7. **One pull request.** This plan is about plan 3's size. **Recommended:** one PR, built and reviewed as one. The other way: two (Tasks 1 to 6, then 7 to 11), the second cut from the first once merged. (Task 12.)

## Calls made in this plan, for Eric to check

1. **Mark purchased in a sitting** sets Status to Active, and the purchase date to today when it has none, with no question (today it asks none either); the dots and History name Details, which owns both values.
2. **A blank name is refused after trimming.** The form refused only an empty field, so a name of spaces saved as an empty name.
3. **Log service from a clock** adds a held service record, so the change is named Service history, the card that owns the record.
4. **A new check-in's photos** are held with the check-in and written after its row; its near-miss action is offered only once the check-in is saved (it opens the near-miss form, another record).
5. **Deleting a check-in and unlinking its photos** become one write. Today the photos are unlinked in a second step whose failure is swallowed.
6. **A check-in started from a dive** (the dive page's sheet) keeps writing at once: it is the dive's tool, as plan 3 left the rental note sheet on the dive.
7. **Moving to a buddy** creates the "with <buddy>" place at Save, inside the sitting, as plan 3's lend does; a Cancel leaves no place behind. The place is its own History record, as today.
8. **Download, Connect, the unit configurations and Add part work locked**: a download is a deliberate mode, configurations are a phase 4 editor, Add part opens another record's new page.
9. **The detail page shrinks below 800 lines**: its read sections move into a `part` file, as the course page's did.
10. **After Save** the page does what the notifiers do after a write today: refreshes the equipment lists, re-evaluates the service clocks and reschedules service reminders, schedules the condition findings refresh, and rescans the transmitter's dives when the serial changed (best effort, as the form).

## Global Constraints

- Plan 5 (tracks, branch `ericgriffin/unified-editing-phase-3-5-tracks-d7ab96`) is built in parallel. **The one file both plans touch is `lib/core/router/app_router.dart`**: this plan changes only the gear item routes there. This plan changes nothing under `lib/shared/`. Merge origin/main before each task with a merge (never a rebase or a force-push), adapt to any renamed names, and run a whole-repo `flutter analyze` after each merge.
- Built on the names already shipped: `RecordEditHost`, `RecordOpenUnlocked`, `EditCard`, `RecordCardFrame`, `RecordCardFade`, `RecordCardPencil`, `AddStripEntry`, `EditSession` (`set`, `valueOf`, `applyTo`, `holdWrite`, `holdChange`, `releaseWrite`, `track`, `remember`, `recall`, `changedCardIds`, `runHeldWrites`), `EditField`, `FieldTextBinding`, `SittingList` (`load`, `current`, `set`, `wroteChange`) with `sameIdSets`, `writeRecordSitting`, `RecordSittingRefusal`, `recordOperationRunnerOf`, `recordOperationBlockOf`, `recordOperationReason`, `DocumentsSection<T>(owner:, editing:)`, `holdDocumentLinks`, `RecordSharingSitting`, `EquipmentSharesSharingAdapter`, `record_media_sitting.dart` (`holdSittingMedia`, `addMediaToSitting`, `unlinkMediaInSitting`, `mediaInSitting`, `mediaAfterCommit`, `undoMediaOnFailure`), `EquipmentMoveFlow.plan` / `write`, `confirmLeaveRecordSitting`, `GearItemCardId` with `localizedDisplayName`.
- With `kUnlockRecordEditing` false (the default) the gear item page, its list pane, table mode, routes and the gear passport page look and behave exactly as today: no existing test changes its expectations. The page takes `unlockEditing` defaulting to the switch.
- A locked page writes nothing on any tap. History label: `record_edit:equipment:<id>:<cards>`, source "manual". Writes to other tables in the sitting (attributes, tags, shares, moves, places, schedules, service records, observations, media, documents, the dive computer row, other items' status) are in that one entry.
- Only what changed is written: the sitting's changes are applied to the item as stored at Save (`EditSession.applyTo`), with a field census test. `EquipmentItem.copyWith` cannot clear brand, model, serial, dates, price or reminders, so the fields build the item through one private `_with` that copies every field, as plans 3 and 4 did.
- Rules move from the form unchanged (listed in Task 1). Units follow the active diver's settings; dates show in their format; prices are read in their decimal convention (`readNumber`).
- No new strings are expected: every label comes from the form or the read page. A task that finds one missing names it, and it goes into all eleven ARB files, translated, then `flutter gen-l10n`.
- `equipment_detail_page.dart` (1,111 lines) and `app_router.dart` do not grow: the page's read sections and editing go in `part` files and the page ends under 800 lines; the routes go in `equipment_edit_routes.dart`, the router gaining only references to it. No other file passes 800.
- Never use em-dashes, and never en-dashes, double hyphens or spaced hyphens as prose punctuation, in code, comments, commits or the PR. Commits, the PR and files follow the repository guide's Attribution section.
- Imports grouped dart, flutter, packages, local. `dart format` changed files before each commit. Anything acting after an `await` checks `mounted` and reads `ref` and `context` before its first `await`.
- Test runs: only the test FILES a task writes or changes, by path. Never a folder, never the whole suite, never `test/architecture/` or `test/shared/` by hand: the pre-push hook runs them.
- Never `--build-filter` build_runner. Never let a debug build open `~/Documents/Submersion/submersion.db`.

## Review Focus

1. **A Move with its parts and a status change, then Cancel.** Nothing moved, no status changed, no "with <buddy>" place created. With Save, the item and its parts move, their status is set, the place is created, all in one entry, and reverting it restores every place and status. Pinned in Task 6.
2. **A new check-in with a photo, then Save.** The check-in row is written before its photo row, in one entry; with Cancel, neither exists. Pinned in Task 9.
3. **The cover photo unlinked in the sitting, or a photo imported in the sitting chosen as the cover.** At Save the cover is cleared with the unlink, or set after the new photo's row exists; with Cancel the stored cover and photos stay. Pinned in Task 8.
4. **A service logged from a clock, then Cancel.** No record, and the item's last service date unchanged. With Save, one entry, the last service date refreshed and the reminders rescheduled. Pinned in Task 7.
5. **The type changed to one the chosen parent cannot hold.** The parent is cleared at once and attributes outside the new type's catalogue are dropped at Save; an item a dive computer or transmitter names cannot change type at all. Pinned in Tasks 1 and 3.

## Form test accounting

The form stays until the switch-over plan, so no test is deleted here. Each edit case gets its counterpart; cases about a new item or a clone go to plan 11.

| Form test (`test/features/equipment/presentation/pages/`) | Case | Counterpart |
| --- | --- | --- |
| `equipment_edit_device_type_test.dart` | type locked for an item with a computer | Task 3, `the type is locked for an item a computer names` |
| | an item with no device keeps its type editable | Task 3, `an item with no device can change type` |
| | locked while the device lookup loads | Task 3, `the type stays locked while the device lookup loads` |
| | `?type=transmitter`; a serial handed over | plan 11 |
| `equipment_edit_hidden_by_view_test.dart` | a master-detail edit to Wanted offers the Wanted view | Task 11, `a pane Save that hides the item offers its view` |
| | an Active item the view shows gets no hint | Task 11, `a pane Save the view still shows says nothing` |
| | a routed edit returns to the item and confirms | Task 11, `a full page Save stays on the item` |
| | a failed visibility check still saves | Task 11, `a failed visibility check still saves` |
| | a Wanted item saved under the default view; a new item under Service Due | plan 11 |
| `equipment_edit_parent_picker_test.dart` | an O2 cell offers rebreathers and saves its parent | Task 4, `an O2 cell offers rebreathers as its parent` |
| | switching type drops a parent the new type cannot use | Task 1, `a type the parent cannot hold clears the parent` |
| | saving while the active list loads keeps the parent | Task 4, `the parent stays while the candidates load` |
| | a regulator shows no parent picker | Task 4, `a regulator shows no parent picker` |
| | a part added from its host; deep-linked parents | plan 11 |
| `equipment_edit_save_navigation_test.dart` | Save stores the item and returns | Task 11, `the pane's Save updates the item and returns to view` |
| | a unit picked with no number yet is saved (#4534) | Task 4, `a unit picked with no number yet is kept` |
| | Save in the app bar is the only save | none needed: the bar is the shared `RecordEditBar` |
| `equipment_edit_service_section_test.dart` | the legacy Service Settings section is gone | Task 4, `the Details editor has no legacy service section` |
| | saving preserves the frozen legacy interval | Task 1, census (`serviceIntervalDays`, `lastServiceDate`) |
| `equipment_edit_tags_test.dart` | the Tags field shows the stored tags | Task 3, `the header editor shows the stored tags` |
| | removing a tag and saving writes the new set | Task 3, `a tag removed is written at Save` |
| | disabled until they arrive; a failed read keeps it locked | Task 3, `the tags field is inert until the sitting's list has loaded` |
| | a save leaves the stored tags alone | Task 3, `untouched tags are not written` |
| | suggestions list equipment tags only | Task 3, `tag suggestions are equipment tags only` |
| | a tag typed on a new item | plan 11 |
| `equipment_edit_type_order_test.dart` | every type alphabetically per locale | Task 3, `the type list is alphabetical in each locale` |
| `equipment_edit_wanted_test.dart` | a wanted item loads as Wanted, relabelled and trimmed | Task 4, `a wanted item's Details editor is relabelled and trimmed` |
| | switching to Wanted and back keeps its fields | Task 4, `Wanted and back keeps the serial and parent` |
| | saving as Wanted stores isActive false | Task 1, `Wanted, Retired and Sold store the item inactive` |
| `equipment_edit_clone_test.dart` | all cases | plan 11 |

## Preparation

- [ ] The worktree is initialised (`git submodule update --init --recursive`, `flutter pub get`); generate code unfiltered in the background if fresh: `dart run build_runner build --delete-conflicting-outputs`.
- [ ] `git fetch origin main`, merge it, and run `flutter analyze` on the whole repository. Expected: clean.
- [ ] Before any code changes, take the "before" goldens (headless widget tests, switch off): the gear item page locked at phone and desktop width, for a regulator with clocks, photos, check-ins and service records, and for a dive computer item.

## File Structure

New (`lib/features/equipment/...`):

| File | Responsibility |
| --- | --- |
| `data/services/gear_item_edit_save_service.dart` | `GearItemEditSaveService`, provider |
| `presentation/editing/gear_item_edit_fields.dart` | Fields and the form's rules |
| `presentation/editing/gear_item_header_editor.dart` | Header block editor, tags list |
| `presentation/editing/gear_item_details_editor.dart` | Details editor, the item's sharing sitting |
| `presentation/editing/gear_item_edit_cards.dart` | `gearItemEditCards`, `gearItemOptionalCards` |
| `presentation/editing/gear_item_location_sitting.dart` | Held moves and past move edits |
| `presentation/editing/gear_item_service_sitting.dart` | Held clocks and service records |
| `presentation/editing/gear_item_media_sitting.dart` | Held photos, cover, legacy files |
| `presentation/editing/gear_item_check_ins_sitting.dart` | Held check-ins with their photos |
| `presentation/pages/equipment_detail_page_editing.dart` | `part`: the page's use of the host |
| `presentation/pages/equipment_detail_page_sections.dart` | `part`: the read sections moved out of the page |
| `presentation/pages/equipment_edit_routes.dart` | Redirect, pane, pane location |

New (`lib/features/dive_computer/presentation/editing/dive_computer_settings_sitting.dart`): the computer's held favourite, auto-download and clock sync override.

Modified: `equipment_detail_page.dart`, `equipment_list_page.dart`, `equipment_header_status.dart`, `equipment_sharing_row.dart`, `equipment_location_card.dart`, `location_move_edit_dialog.dart`, `move_equipment_sheet.dart`, `service_clocks_card.dart`, `service_schedule_dialogs.dart`, `service_history_section.dart`, `service_record_dialog.dart`, `equipment_photos_section.dart`, `gear_photo_import_helper.dart`, `observations_card.dart`, `equipment_observation_sheet.dart`, `check_in_photos_row.dart`, `equipment_documents_section.dart`, `children_card.dart`, `components_card.dart`, `condition_findings_card.dart` and `twin_set_card.dart` (`readOnly` only, Question 1), `dive_computer_section.dart`, `dive_computer_controls.dart` and its cards, `transmitter_section.dart`, `media_import_service.dart` (`prepareForEquipment`), `record_media_sitting.dart` (`SittingMediaWriters.forEquipment`), the photo picker's hold path, `app_router.dart`, `test/architecture/markdown_notes_adoption_test.dart` (new Markdown editor; not run by hand).

---

### Task 1: The save service and fields

**Files:**
- Create: `lib/features/equipment/data/services/gear_item_edit_save_service.dart`, `lib/features/equipment/presentation/editing/gear_item_edit_fields.dart`
- Test: `test/features/equipment/data/services/gear_item_edit_save_service_test.dart`, `test/features/equipment/presentation/editing/gear_item_edit_fields_test.dart`

**Interfaces:**
- Produces:
  - `class GearItemEditSaveService { GearItemEditSaveService(EquipmentRepository equipment, GearPhotoRepository photos); Future<({EquipmentItem before, EquipmentItem after})?> save({required String equipmentId, required EquipmentItem Function(EquipmentItem stored) apply, required Iterable<String> changedCardIds, Future<void> Function()? alsoWrite, bool alsoWriteIsAChange = false}) }`: `writeRecordSitting<EquipmentItem>(table: 'equipment', read: () => getEquipmentById(id), write: (_, merged) => updateEquipment(merged, notify: false))`, its `alsoWrite` running the held writes and then, when the merged item's `coverMediaId` differs from the stored one, `GearPhotoRepository.setCover` (last, so a photo imported in the sitting exists first; Review Focus 3). `gearItemEditSaveServiceProvider`.
  - Fields, card `header`: `gearNameField` (`String`, trimmed), `gearTypeField` (`EquipmentType`); card `details`: `gearStatusField` (`EquipmentStatus`; applying it also sets `isActive`), `gearParentField` (`String?`), `gearBrandField`, `gearModelField`, `gearSerialField` (`String?`, blank stores null), `gearAttributeEditsField` (`Map<String, EquipmentAttribute?>`, catalogue attributes by key, only those the sitting touched; null removes), `gearCustomFieldsField` (`List<EquipmentAttribute>`), `gearPurchaseDateField` (`DateTime?`), `gearPriceField` (`({double? price, String currency})`, one field so the pair is one change); card `serviceClocks`: `gearCustomReminderField` (`({bool? enabled, List<int>? days})`); card `photos`: `gearCoverField` (`String?`); card `notes`: `gearNotesField` (`String`, trimmed).
  - Rules, pure, moved from the form: `bool gearNameValid(String name)` (trimmed, not empty; Call 2); `bool gearIsActive(EquipmentStatus status)` (false for retired, sold, wanted); `EquipmentStatus gearShownStatus(EquipmentItem item)` (a legacy inactive row with a status that is not sold or wanted shows as Retired, #636); `String? gearParentAfterType(EquipmentType type, String? parentId, List<EquipmentItem> candidates)` (kept only when an active candidate of a type `parentTypesFor(type)` allows has that id); `List<EquipmentAttribute> gearAttributesToSave(EquipmentType type, List<EquipmentAttribute> catalogue, List<EquipmentAttribute> custom)` (only the type's catalogue keys with content, then custom fields de-duplicated by trimmed key, first wins, sort order re-packed; `keepStrayColorAsCustom` on the way in); `List<int> gearReminderDaysToggled(List<int> days, int day)` (at least one stays); `String gearCurrencyOrDefault(String typed, String fallback)`.
- Consumes: `writeRecordSitting`.

- [ ] **Step 1: Write the failing tests** (test database; regulator `g1` "Apex", owned by `d1`, brand Apex, serial `A1`, a spec attribute, a custom field "Hose" = "blue", purchase date and price, notes; a dive computer row naming `g1`):
  - Service: `writes a brand change as one History entry` (label `record_edit:equipment:g1:details`); census `a field the sitting did not touch keeps its newer value`, one assertion per column `updateEquipment` writes (name, type, brand, model, serial, status, isActive, purchase date, price, currency, notes, reminders, parent, `lastServiceDate`, `serviceIntervalDays`) and `an attribute the sitting did not touch keeps its newer value`; `the name is mirrored to the dive computer in the same entry`; `a new cover is set after the held writes`; `unchanged returns null`; `an item that has gone throws`.
  - Fields: `Wanted, Retired and Sold store the item inactive`; `a legacy inactive Active row shows as Retired`; `a type the parent cannot hold clears the parent` (Review Focus 5); `attributes outside the new type's catalogue are dropped`; `custom fields are de-duplicated by key, first wins`; `a stray colour on a type without one is kept as a custom field`; `the last reminder day cannot be removed`; `a name of spaces is invalid`.
- [ ] **Step 2:** Run the two files. Expected: fail to compile.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them. Expected: all pass.
- [ ] **Step 5: Commit** `feat(equipment): save a gear item's editing sitting as one History entry`.

### Task 2: The gear item page on the host

**Files:**
- Create: `gear_item_edit_cards.dart`, `equipment_detail_page_editing.dart` (part), `equipment_detail_page_sections.dart` (part)
- Modify: `equipment_detail_page.dart`, `components_card.dart`, `condition_findings_card.dart`, `twin_set_card.dart`, `test/architecture/markdown_notes_adoption_test.dart`
- Test: `test/features/equipment/presentation/pages/equipment_detail_page_unlock_harness.dart`, `equipment_detail_page_unlock_test.dart`

**Interfaces:**
- Produces:
  - `class EquipmentDetailPage extends ConsumerStatefulWidget { const EquipmentDetailPage({required String equipmentId, bool embedded = false, VoidCallback? onDeleted, bool unlockEditing = kUnlockRecordEditing, bool openUnlocked = false, VoidCallback? onSittingEnded}) }` on `RecordEditHost<EquipmentDetailPage, EquipmentItem>` and `RecordOpenUnlocked`; `followStored(equipmentItemProvider(id))`; `editingTitle`: `recordEdit_editingTitle(item.name)`; `rereadStored` invalidates `equipmentItemProvider`; `onSittingStart` loads every list the later tasks add; `saveSitting` as the course page's, reading providers before the write, then Call 10's refreshes (`afterGearItemSave(ProviderContainer, {required EquipmentItem before, required EquipmentItem after})`, in the editing part). Its bar and embedded header take `host.lockButton`; Edit unlocks, as the certification page.
  - `gearItemEditCards` (`Map<GearItemCardId, EditCard<EquipmentItem>>`), filled by Tasks 3 to 9; this task adds `notes` (`isEmpty`: blank; `MarkdownNotesField` over `gearNotesField`) and `documents` (`DocumentsSection<EquipmentItem>`, links held by `holdDocumentLinks` with `DocumentOwnerKind.equipment`). `gearItemOptionalCards`: notes.
  - Faded as calculated while unlocked: the service banner, the Dives, Time, Trips and Owned for rows inside Details (read only in its editor), Exposure, Condition trend, the equipment History card, the passport entry cards. The unit configurations card works locked and unlocked.
  - `ComponentsCard`, `ConditionFindingsCard` and `TwinSetCard` gain `bool readOnly = false`: no action offered, links to other items kept. The page passes `readOnly: true` whenever `unlockEditing` is on (Question 1).
- Consumes: Task 1.

- [ ] **Step 1: Write the failing tests** (harness: a fake save recording calls, as plan 4's; the item `g1`, recording repository fakes for every collection the later tasks hold):
  - `with the switch off there is no lock and the page is as before`; `locked, no tap writes` (every card's buttons, a recording fake for each repository records nothing); `notes and documents in one sitting save as one entry and lock`; `empty Notes is offered in the strip`; `the documents card holds a detach until Save`; `the Dives, Trips and Owned for rows fade as calculated`; `with the switch on, Components, Condition findings and Twin set offer no action`; `Cancel with changes asks first`.
- [ ] **Step 2:** Run the two files. Expected: failures.
- [ ] **Step 3:** Implement; move the read sections into the sections part; add the notes editor to the Markdown guard's list.
- [ ] **Step 4:** Run them, and unchanged `equipment_detail_page_test.dart`, `equipment_detail_label_column_test.dart`, `equipment_detail_count_rows_test.dart`, `equipment_detail_rollup_test.dart`, `equipment_detail_passport_card_test.dart`, `components_card_test.dart`, `condition_findings_card_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(equipment): unlock a gear item page to edit it in place, behind a switch`.

### Task 3: The header block

**Files:**
- Create: `gear_item_header_editor.dart`
- Modify: `gear_item_edit_cards.dart`, `equipment_header_status.dart`, `equipment_detail_page_editing.dart`
- Test: `test/features/equipment/presentation/editing/gear_item_header_editor_test.dart`, `equipment_detail_page_unlock_test.dart`, `equipment_header_status_test.dart` (existing; add cases)

**Interfaces:**
- Produces:
  - `final gearItemTagsList = SittingList<EquipmentItem, Tag>(key: 'equipment.tags', cardId: 'header', read: <tags of the item>, write: (item, loaded, current) => EquipmentTagRepository().replaceTags(item.id, ids of current, notify: false), same: (a, b) => sameIdSets(a, b, (t) => t.id))`.
  - `GearItemHeaderEditor({required EditSession<EquipmentItem> session})`: the name (`equipment_edit_nameLabel`, its error while invalid), the type dropdown (sorted by localised name; disabled with `equipment_edit_typeLockedHelper` while `equipmentHasDeviceProvider` is true or loading; a pick sets the type and, through `gearParentAfterType`, the parent), `EquipmentTagsField` over the sitting's tags (inert until loaded), and for wanted gear Mark purchased (Call 1: sets `gearStatusField` to Active, `gearPurchaseDateField` to today when null).
  - `header` card: `isEmpty` false, `isValid`: `gearNameValid`. Closed, the chips and `EquipmentHeaderStatus` read the working item and the sitting's tags. `EquipmentHeaderStatus` gains `bool offerPurchase = true`; the page passes false with the switch on.
- Consumes: Tasks 1 and 2.

- [ ] **Step 1: Write the failing tests**: editor: `the type is locked for an item a computer names`; `an item with no device can change type`; `the type stays locked while the device lookup loads`; `the type list is alphabetical in each locale` (each supported locale); `the header editor shows the stored tags`; `tag suggestions are equipment tags only`; `Mark purchased sets Active and today's date, keeping a set date`. Page: `a tag removed is written at Save`; `the tags field is inert until the sitting's list has loaded`; `untouched tags are not written`; `Mark purchased, then Cancel: still wanted`; header status: `with the switch on the chip offers no purchase`.
- [ ] **Step 2:** Run the three files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them, and unchanged `equipment_tag_chips_test.dart`, `equipment_detail_tags_test.dart`, `equipment_detail_wanted_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(equipment): a gear item's name, type, tags and purchase wait for Save`.

### Task 4: Details, with sharing

**Files:**
- Create: `gear_item_details_editor.dart`
- Modify: `gear_item_edit_cards.dart`, `equipment_sharing_row.dart`, `equipment_detail_page_editing.dart`, `equipment_detail_page_sections.dart`
- Test: `test/features/equipment/presentation/editing/gear_item_details_editor_test.dart`, `test/features/equipment/presentation/widgets/equipment_sharing_row_test.dart` (create), `equipment_detail_page_unlock_test.dart`

**Interfaces:**
- Produces:
  - `const gearItemSharing = RecordSharingSitting<EquipmentItem, Set<String>>(key: 'equipment.sharing', cardId: 'details', recordIdOf: <id>)`, loaded in `onSittingStart` with `EquipmentSharesSharingAdapter` and the active diver, only when the item has an owner and there are two or more profiles.
  - `GearItemDetailsEditor({required EditSession<EquipmentItem> session})`: status (`gearShownStatus` first), the parent dropdown (only when not wanted and `parentTypesFor(type)` is not empty; candidates from `activeEquipmentProvider`, the stored parent kept while they load), brand and model, `EquipmentAttributeFormSection` for spec and appearance over `gearAttributeEditsField`, the figure position field, serial (not for wanted gear), the purchase date, price and currency (the expected price label for wanted gear), the purchase attributes, `EquipmentCustomFieldsSection` over `gearCustomFieldsField`; the Dives, Time, Trips and Owned for rows read only; the sharing row.
  - `EquipmentSharingRow` gains `EditSession<EquipmentItem>? editing`: in a sitting the owner's checklist sets `gearItemSharing` (`actingDiverId` the active diver); the row shows the sitting's set with the changed dot. Locked with the switch on it offers no edit; switch off, unchanged.
- Consumes: Tasks 1 to 3.

- [ ] **Step 1: Write the failing tests**: editor: `an O2 cell offers rebreathers as its parent`; `the parent stays while the candidates load`; `a regulator shows no parent picker`; `a unit picked with no number yet is kept`; `the Details editor has no legacy service section`; `a wanted item's Details editor is relabelled and trimmed` (expected price, no serial, no parent); `Wanted and back keeps the serial and parent`; `calculated rows are read only inside the editor`. Sharing row: `the owner's tap opens the checklist`; `a sharee sees it read only`; `in a sitting a share is held until Save`; `locked with the switch on, no tap writes`. Page: `brand, a spec attribute and a share in one sitting are one entry`; `a share another device made impossible fails the Save with the sharing message and writes nothing`.
- [ ] **Step 2:** Run the three files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them, and unchanged `equipment_detail_installed_in_test.dart`, `equipment_detail_item_units_test.dart`, `equipment_detail_sharing_test.dart`, `equipment_attribute_form_section_test.dart`, `equipment_custom_fields_section_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(equipment): a gear item's details and sharing wait for Save`.

### Task 5: The dive computer card

**Files:**
- Create: `lib/features/dive_computer/presentation/editing/dive_computer_settings_sitting.dart`
- Modify: `dive_computer_section.dart`, `dive_computer_controls.dart`, `dive_computer_auto_download_card.dart`, `dive_computer_clock_sync_card.dart`, the actions card and merge banner, `gear_item_edit_cards.dart`, `equipment_detail_page_editing.dart`
- Test: `test/features/dive_computer/presentation/editing/dive_computer_settings_sitting_test.dart`, `dive_computer_section_test.dart` (existing; add cases), `equipment_detail_page_unlock_test.dart`

**Interfaces:**
- Produces:
  - `typedef DiveComputerSettings = ({bool favourite, bool autoDownloadDisabled, ClockSyncOverride? clockSync});`
  - `DiveComputerSettings? heldDiveComputerSettings(EditSession<EquipmentItem> session)`; `void holdDiveComputerSettings(EditSession<EquipmentItem> session, {required DiveComputer computer, required DiveComputerSettings stored, required DiveComputerSettings next, String? diverId})`: back to `stored` releases; otherwise a `holdChange('equipment.diveComputer', cardId: 'diveComputer')` whose write calls `setFavoriteComputer` and `setAutoDownloadDisabled` for what differs; the clock sync override is remembered and written by `afterGearItemSave` once the commit is done (Question 4).
  - `DiveComputerControls` gains `EditSession<EquipmentItem>? editing` and `String? operationReason`: in a sitting the star and the auto-download switch and the clock sync override read and set the held settings; merge (header and banner) and re-parse all are disabled with `operationReason` and run through `recordOperationRunnerOf`; download, re-import and Connect work locked; "Check again" works locked. `DiveComputerSection` passes them through.
  - The `diveComputer` card: `isEmpty` false; shown only for a computer item, as today.
- Consumes: Task 2.

- [ ] **Step 1: Write the failing tests**: sitting: `a favourite set back to stored releases the change`; `the write sets favourite and auto-download only where they differ`. Section: `locked with the switch on, the star and switch write nothing`; `merge and re-parse all are disabled under "Unlock to use these"`; `unlocked and clean, re-parse all asks and runs`; `download works locked`. Page: `favourite and a brand change are one entry, and reverting restores the favourite`; `a clock sync override is written after the commit, and not on Cancel`; `a failed Save leaves the clock sync override as it was`.
- [ ] **Step 2:** Run the three files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them, and unchanged `dive_computer_controls_test.dart`, `dive_computer_controls_auto_download_test.dart`, `dive_computer_controls_clock_sync_test.dart`, `dive_computer_controls_merge_test.dart`, `dive_computer_controls_reparse_all_test.dart`, `equipment_detail_computer_placement_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(equipment): a dive computer's settings on its item wait for Save`.

### Task 6: Location: moves and past moves held

**Files:**
- Create: `gear_item_location_sitting.dart`
- Modify: `equipment_location_card.dart`, `move_equipment_sheet.dart`, `location_move_edit_dialog.dart`, `gear_item_edit_cards.dart`, `equipment_detail_page_editing.dart`
- Test: `test/features/equipment/presentation/editing/gear_item_location_sitting_test.dart`, `equipment_location_card_test.dart`, `move_equipment_sheet_test.dart`, `location_move_edit_dialog_test.dart` (existing; add cases), `equipment_detail_page_unlock_test.dart`

**Interfaces:**
- Produces:
  - `class HeldGearItemMove { const HeldGearItemMove({required LocationPick pick, required EquipmentMovePlan plan, String? diverId}); }`. `Future<HeldGearItemMove?> planGearItemMove(BuildContext, WidgetRef, EquipmentItem item)`: the move sheet, then `EquipmentMoveFlow.plan` (parts and status questions asked now, `setStatus` a no-op), writing nothing; a buddy pick plans the person kind, as `planLendGear`.
  - `final gearItemMovesList = SittingList<EquipmentItem, EquipmentLocationMove>(key: 'equipment.moveHistory', cardId: 'location', read: <moves of the item>, write: <updateMove for changed rows, deleteMove for removed>)`: past moves edited and deleted.
  - `void holdGearItemMove(EditSession<EquipmentItem> session, HeldGearItemMove move)` (a second move replaces the first held one); `Future<void> writeGearItemMove(HeldGearItemMove move)`: the place found or created for a buddy (`findOrCreateForBuddy`), then `EquipmentMoveFlow.write`, inside the sitting (Call 7).
  - `showLocationMoveEditDialog` gains `void Function(EquipmentLocationMove? edited)? onHold` (null `edited`: deleted): with it, Save and Delete hand back and write nothing; Delete still asks first.
  - `EquipmentLocationCard` gains `EditSession<EquipmentItem>? editing` and `bool readOnly = false`: in a sitting the current place and history are the sitting's (the held move first, with the changed dot); locked with the switch on, no Move and rows open nothing.
- Consumes: Task 2; plan 3's `EquipmentMoveFlow.plan` / `write`.

- [ ] **Step 1: Write the failing tests**: sitting: `planning a move asks the parts and status questions and writes nothing`; `a held move to a buddy creates the place only at write`. Card and dialog: `in a sitting Move holds and shows the new place first`; `a past move edited or deleted in a sitting writes nothing until Save`; `locked with the switch on, no tap writes`. Page: `a move with parts and a status change, then Cancel: nothing moved, no place created` (Review Focus 1); `the same, then Save: one entry, and reverting restores every place and status` (Review Focus 1).
- [ ] **Step 2:** Run the five files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them, and unchanged `equipment_location_card_buddy_test.dart`, `equipment_move_flow_test.dart`, `lend_gear_flow_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(equipment): moving a gear item and editing its past moves wait for Save`.

### Task 7: Service clocks and service history held

**Files:**
- Create: `gear_item_service_sitting.dart`
- Modify: `service_clocks_card.dart`, `service_schedule_dialogs.dart`, `service_history_section.dart`, `service_record_dialog.dart`, `gear_item_edit_cards.dart`, `equipment_detail_page_editing.dart`, `equipment_detail_page_sections.dart`
- Test: `test/features/equipment/presentation/editing/gear_item_service_sitting_test.dart`, `service_clocks_interactions_test.dart`, `service_history_section_test.dart` (existing; add cases), `equipment_detail_page_unlock_test.dart`

**Interfaces:**
- Produces:
  - `final gearItemClocksList = SittingList<EquipmentItem, ServiceSchedule>(key: 'equipment.clocks', cardId: 'serviceClocks', read: <schedules of the item>, write: <createSchedule / updateSchedule with notify false, deleteSchedule for removed>)`. New clocks get their uuid in the sitting.
  - `final gearItemServiceRecordsList = SittingList<EquipmentItem, ServiceRecord>(key: 'equipment.serviceRecords', cardId: 'serviceHistory', read: <records of the item>, write: <ServiceRecordRepository createRecord / updateRecord / deleteRecord>)`; the repository's last service date refresh runs inside the sitting.
  - `showServiceKindPicker` gains `Set<String>? attachedKindIds` and `Future<ServiceSchedule?> Function(ServiceSchedule)? onCreate`; `showScheduleOverrideDialog` gains `List<ServiceRecord>? records` (the sitting's, for `baselineInEffect`) and `void Function(ServiceSchedule)? onSave`. With them, nothing is written; without, as today.
  - `ServiceClocksCard` gains `EditSession<EquipmentItem>? editing`, `bool readOnly = false`: in a sitting add, override, pause, resume and remove change `gearItemClocksList`; the status rows stay as stored (Question 6), held clocks listed with the changed dot; Log service adds to `gearItemServiceRecordsList` (Call 3); the custom reminder controls (override on, off or default, and the 7, 14 and 30 day chips) set `gearCustomReminderField`. Closed, a set custom reminder shows as a row (the note's "Values shown nowhere today"). Locked with the switch on: nothing offered.
  - `ServiceHistorySection` gains `EditSession<EquipmentItem>? editing`, `bool readOnly = false`: add, edit, delete held, the delete asking nothing (as plan 3's held removals).
- Consumes: Task 2.

- [ ] **Step 1: Write the failing tests**: sitting: `a clock added in the sitting is created at Save with its interval`; `pause and resume back to stored write nothing`; `the override dialog judges the baseline by the sitting's records`. Cards: `in a sitting each clock action writes nothing until Save`; `the kind picker leaves out kinds the sitting attached`; `a set custom reminder shows a row`; `locked with the switch on, no tap writes`. Page: `a service logged from a clock, then Cancel: no record, last service date unchanged` (Review Focus 4); `the same, then Save: one entry, last service date refreshed, reminders rescheduled` (Review Focus 4); `a clock removed and a record edited are one entry, and reverting restores both`.
- [ ] **Step 2:** Run the four files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them, and unchanged `service_clocks_card_test.dart`, `service_clocks_card_unconfigured_test.dart`, `service_schedule_override_dialog_test.dart`, `service_record_dialog_prefill_test.dart`, `equipment_detail_service_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(equipment): service clocks, reminders and service records on a gear item wait for Save`.

### Task 8: Photos, the cover and legacy files held

**Files:**
- Create: `gear_item_media_sitting.dart`
- Modify: `media_import_service.dart`, `record_media_sitting.dart`, the photo picker's hold path, `gear_photo_import_helper.dart`, `equipment_photos_section.dart`, `equipment_documents_section.dart`, `gear_item_edit_cards.dart`, `equipment_detail_page_editing.dart`
- Test: `test/features/media/data/services/media_import_service_prepare_equipment_test.dart` (create), `record_media_sitting_test.dart`, `equipment_photos_section_test.dart`, `equipment_documents_section_test.dart`, `gear_photo_import_helper_test.dart` (existing; add cases), `equipment_detail_page_unlock_test.dart`

**Interfaces:**
- Produces:
  - `Future<List<PreparedMedia>> MediaImportService.prepareForEquipment({required List<AssetInfo> selectedAssets, required String equipmentId, String? observationId, Set<String> ignoringMediaIds = const {}})`: what `importPhotosForEquipment` would write, under fresh ids, writing nothing (as `prepareForSite`).
  - `factory SittingMediaWriters.forEquipment(ProviderRead read)`: as `forSite`, unlinking through `unlinkFromEquipment` (deletes held for the commit), relinking unsupported.
  - The picker's hold path (`showPhotoPicker(onHold:)`, gallery and Files tabs) accepts `EquipmentAttachTarget`; `GearPhotoImportHelper.holdPhotos({required BuildContext context, required WidgetRef ref, required String equipmentId, String? observationId, required MediaHoldSink onHold})`.
  - The photos card: `holdSittingMedia(session, SittingMediaWriters.forEquipment(read), cardId: 'photos')` in `onSittingStart`; `EquipmentPhotosSection` gains `EditSession<EquipmentItem>? editing`, `bool readOnly = false`: import holds, unlink holds (an unlinked cover clears `gearCoverField`), the cover sets `gearCoverField`; the grid draws `mediaInSitting`. The page's Save runs through `undoMediaOnFailure` and then `mediaAfterCommit`.
  - `final gearItemLegacyFilesList = SittingList<EquipmentItem, MediaItem>(key: 'equipment.legacyFiles', cardId: 'legacyFiles', read: <the item's non-photo media>, write: <the removed ids through the equipment writers' unlink>)`; `EquipmentDocumentsSection` gains `editing` and `readOnly` the same way.
- Consumes: Tasks 1 and 2.

- [ ] **Step 1: Write the failing tests**: service: `prepareForEquipment writes nothing and skips photos already linked`; writers: `the equipment writers unlink from the item, holding deletes for the commit`. Cards: `in a sitting import, unlink and cover write nothing until Save`; `unlinking the cover clears it in the sitting`; `a legacy file removed in a sitting stays until Save`; `locked with the switch on, no tap writes`. Page: `a photo imported and chosen as the cover: the cover is written after the photo` (Review Focus 3); `the cover unlinked, then Cancel: cover and photo kept` (Review Focus 3); `a failed Save takes back nothing outside the database and leaves the page unlocked`.
- [ ] **Step 2:** Run the six files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them. Expected: all pass.
- [ ] **Step 5: Commit** `feat(equipment): a gear item's photos, cover and linked files wait for Save`.

### Task 9: Check-ins held, with their photos

**Files:**
- Create: `gear_item_check_ins_sitting.dart`
- Modify: `observations_card.dart`, `equipment_observation_sheet.dart`, `check_in_photos_row.dart`, `gear_item_edit_cards.dart`, `equipment_detail_page_editing.dart`
- Test: `test/features/equipment/presentation/editing/gear_item_check_ins_sitting_test.dart`, `observations_card_test.dart`, `equipment_observation_sheet_test.dart`, `check_in_photos_row_test.dart` (existing; add cases), `equipment_detail_page_unlock_test.dart`

**Interfaces:**
- Produces:
  - `class HeldCheckIn { const HeldCheckIn({required EquipmentObservation observation, List<PreparedMedia> addedPhotos = const [], Set<String> removedPhotoIds = const {}}); }` with value equality.
  - `final gearItemCheckInsList = SittingList<EquipmentItem, HeldCheckIn>(key: 'equipment.checkIns', cardId: 'observations', read: <the item's observations, no held photos>, write: ...)`: for each check-in new or changed, `create` or `update`, then its added photos through the equipment writers' `writeRows`, then its removed photos through `unlink`; for each removed check-in, `delete` and the unlink of its photos (Call 5). Then `scheduleConditionFindingsRefresh` after the commit.
  - `showEquipmentObservationSheet` gains `HeldCheckIn? held` and `void Function(HeldCheckIn? result)? onHold` (null: deleted); with it, a new check-in's id is minted for the sitting, `CheckInPhotosRow` holds through `GearPhotoImportHelper.holdPhotos` with that `observationId`, and nothing is written; the near-miss action is offered only for a stored check-in (Call 4). `confirmDeleteObservation` in a sitting asks nothing.
  - `ObservationsCard` gains `EditSession<EquipmentItem>? editing`, `bool readOnly = false`: the rows are the sitting's, held ones with the changed dot.
- Consumes: Task 8's writers and `holdPhotos`.

- [ ] **Step 1: Write the failing tests**: sitting: `a new check-in's row is written before its photos` (Review Focus 2); `a removed check-in's photos are unlinked in the same write`. Sheet and card: `in a sitting Save writes nothing and hands back the check-in`; `a held check-in's photo is held, not linked`; `a held check-in offers no near-miss action`; `locked with the switch on, no tap writes`. Page: `a new check-in with a photo, then Save: one entry` (Review Focus 2); `the same, then Cancel: no row and no media row` (Review Focus 2); `an edited check-in and a brand change are one entry, and reverting restores the check-in`.
- [ ] **Step 2:** Run the five files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them, and unchanged `observation_near_miss_action_test.dart`, `observation_status_chip_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(equipment): check-ins and their photos on a gear item wait for Save`.

### Task 10: Parts and Transmitter: operations and links

**Files:**
- Modify: `children_card.dart`, `transmitter_section.dart`, `equipment_detail_page_sections.dart`
- Test: `children_card_test.dart`, `transmitter_section_test.dart` (existing; add cases), `equipment_detail_page_unlock_test.dart`

**Interfaces:**
- Produces: `ChildrenCard` and `TransmitterSection` gain `String? operationReason` and `RecordOperationRunner? runOperation`: Replace and Apply to existing dives are disabled with the reason, and with a runner they run through it (keeping their confirmations); Add part, Open, the key rows and Set up work locked (Call 8). The page passes `recordOperationReason(l10n, recordOperationBlockOf(...))` and `recordOperationRunnerOf(...)` with the switch on.
- Consumes: Task 2.

- [ ] **Step 1: Write the failing tests**: `locked, Replace is disabled under "Unlock to use these"`; `unlocked with unsaved changes, Replace is disabled`; `unlocked and clean, Replace asks and replaces`; `Add part works locked`; the same three for Apply to existing dives; `a key row opens the transmitter page locked`.
- [ ] **Step 2:** Run the three files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them, and unchanged `transmitter_apply_dialog_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(equipment): replacing a part and applying a transmitter are whole-record operations`.

### Task 11: Hosts, routes, Delete and Transfer

**Files:**
- Create: `lib/features/equipment/presentation/pages/equipment_edit_routes.dart`
- Modify: `equipment_detail_page.dart`, `equipment_detail_page_editing.dart`, `equipment_list_page.dart`, `app_router.dart`
- Test: `equipment_detail_page_unlock_test.dart`, `test/features/equipment/presentation/pages/equipment_edit_routes_test.dart` (create), `equipment_list_page_test.dart` (existing; add cases)

**Interfaces:**
- Produces: `String? gearItemEditLocation(String id, {bool unlockEditing = kUnlockRecordEditing})` (`/equipment/<id>?mode=edit`, else null); `String? gearItemEditRedirect(BuildContext, GoRouterState)`; `String gearItemPaneLocation(String id, {bool openUnlocked = false})` (`/equipment?selected=<id>`, with `&mode=edit` when unlocked), used by the page's wide-screen redirect; `Widget gearItemEditPane(BuildContext, String id, void Function(String) onSaved, VoidCallback onCancel, {VoidCallback? onDeleted, bool unlockEditing = kUnlockRecordEditing})`, used by both `editBuilder`s (master-detail and table mode); `createBuilder` and `/equipment/new` stay the form. The detail route passes `openUnlocked` from `?mode=edit`; `/equipment` and `:equipmentId` get `onExit: confirmLeaveRecordSitting`. Delete and Transfer run through `recordOperationRunnerOf` (owner only, as today; leaving after Transfer without kept access, as today); History, Open in Connections and Clone work locked. A pane Save whose item the list's view now hides offers that view, as the form's `_viewRevealing` does.
- Consumes: Tasks 2 to 10.

- [ ] **Step 1: Write the failing tests**: `opened with mode=edit, the page is unlocked`; `on a wide screen, mode=edit moves into the pane unlocked`; `the pane's and table mode's edit open the page unlocked, Cancel returns to view`; `the pane's Save updates the item and returns to view`; `a pane Save that hides the item offers its view`; `a pane Save the view still shows says nothing`; `a full page Save stays on the item`; `a failed visibility check still saves`; `the edit address redirects with the switch on, not off`; `locked, Delete and Transfer are disabled under "Unlock to use these"`; `unlocked and clean, Delete asks and deletes`; `Clone works locked`; `with the switch off the pane opens the form`.
- [ ] **Step 2:** Run the three files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them, and unchanged `equipment_list_tab_switch_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(equipment): edit addresses and panes open the gear item unlocked; delete and transfer as whole-record operations`.

### Task 12: Push, open the pull request, track it to green

- [ ] **Step 1:** Merge origin/main once more; whole-repo `flutter analyze`; `dart format` every changed file. Expected: clean.
- [ ] **Step 2:** Push in the background (`git push -u origin HEAD`), touching no `lib/` or `test/` file while it runs. Fix any hook failure in its own commit.
- [ ] **Step 3:** `/code-review xhigh --fix --max-findings all`; fix every valid finding test first; push again.
- [ ] **Step 4:** Screenshots from headless widget-test goldens with the switch on (never `flutter test ... -d macos`): the page locked (before and after) and unlocked, with the Header, Details, Location (a held move), Service clocks (a held clock and the custom reminder row), Photos and Observations editors open, and a dive computer item with its card open; light and dark for the unlocked bar; phone and desktop for the pane. Attached through the project's current secret screenshot gist.
- [ ] **Step 5:** `gh pr create` from the template, title `feat(editing): gear items edit in place, behind a switch`, body with `Refs #4527` and the screenshots; bind it, turn Auto-fix on, and follow it until every check is green, fixing each failure and review comment as it comes.
