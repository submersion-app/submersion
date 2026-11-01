# Gear Lent to Buddies Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a Person place link to a buddy, lend gear from the item or the buddy page, list the gear on the buddy page, and take it back.

**Architecture:** One nullable column, `equipment_locations.buddy_id`, following the `dive_center_id` pattern from #3869. Lending reuses the Move flow through a new `BuddyPick` case of `LocationPick`, resolved to a place only on confirm. Returning is a new `EquipmentReturnFlow` beside `EquipmentMoveFlow`, driven by pure functions over the existing move log.

**Tech Stack:** Flutter, Dart, Drift, Riverpod, go_router, `flutter gen-l10n`.

**Spec:** `docs/design/specs/2026-11-01-gear-lent-to-buddies-design.md`

## Global Constraints

- Schema v334, renumbered if another PR ships it first. Never add a rung or table to `database.dart` beyond the version and `migrationVersions` entry.
- Every unlink clears the link by hand, stamps `updated_at` and marks the place pending, inside the caller's transaction: a local SET NULL reaches no peer.
- A status never changes without the diver confirming.
- Strings in all 11 ARB files, translated, not English copies. Use the `one{{count} ...} other{{count} ...}` plural form, never `=1` with a digit.
- No em-dashes anywhere. No mention of any AI tool in repo or GitHub text.
- Stage explicit paths. The screenshot harness and goldens are never committed.
- RED checks one file per run. Do not overlap local test runs.

## Review Focus

- An item with no move before the loan: Returned sends it to No location and still offers Active.
- A buddy with both an archived and an active linked place: the section lists gear at both, and a new lend picks the active one.
- A merge of two buddies who each hold gear, then Undo: every place gets its own original link back.
- A peer on an older build edits a linked place: the link survives, because the key is omitted.
- Lending gear already at this buddy's other place: the picker leaves it out, and it is not moved twice.

---

### Task 1: Column, entity, repository

**Files:**
- Modify: `lib/core/database/tables/equipment_location_tables.dart`, `lib/core/database/database.dart`, `lib/core/database/migrations/helpers/equipment_location_migrations.dart`, `lib/core/database/migrations/ladder/rungs_v231_onward.dart`, `lib/core/database/migrations/before_open_child_columns.dart`
- Modify: `lib/features/equipment/domain/entities/equipment_location.dart`, `lib/features/equipment/data/repositories/equipment_location_repository.dart`
- Modify: `test/features/equipment/presentation/widgets/equipment_location_edit_dialog_test.dart` (its fake overrides `createLocation`)
- Test: `test/core/database/migration_v334_equipment_location_buddy_test.dart`, `test/features/equipment/domain/entities/equipment_location_test.dart`, `test/features/equipment/data/repositories/equipment_location_repository_test.dart`

**Interfaces:**
- Produces: `EquipmentLocation.buddyId`, `copyWith(buddyId:, clearBuddyId:)`; `createLocation(..., String? buddyId)`; `updateLocation` carries it; `Future<EquipmentLocation> findOrCreateForBuddy({required String? diverId, required String buddyId, required String name})`; migration helper `_assertEquipmentLocationBuddyColumn()`.

- [ ] **Step 1: Write failing tests.** Model the migration test on `migration_v331_equipment_location_center_test.dart`: column added, idempotent, existing places unchanged. Repository: `create, update and clear the buddy link`; `findOrCreateForBuddy reuses the linked active place`, `prefers the most recently updated of several`, `skips an archived link and creates a Person place named after the buddy`, `ignores a linked place of another kind`.
- [ ] **Step 2: Run each file alone, confirm RED.**
- [ ] **Step 3: Implement.** `TextColumn get buddyId => text().nullable().references(Buddies, #id, onDelete: KeyAction.setNull)();`. Helper uses `_addColumnIfMissing('equipment_locations', 'buddy_id', 'TEXT REFERENCES buddies(id) ON DELETE SET NULL')`; add `'buddies'` to the parent list the table rebuild checks. Rung `if (from < 334)`. Bump `currentSchemaVersion` and add `334` with a comment to `migrationVersions`. Re-assert from `before_open_child_columns.dart`. Run `dart run build_runner build --delete-conflicting-outputs`.
- [ ] **Step 4: Run the three test files and `test/core/database`, confirm GREEN.**
- [ ] **Step 5: Commit** `feat(equipment): link a person place to a buddy`.

### Task 2: Sync and unlink paths

**Files:**
- Create: `lib/features/equipment/data/repositories/equipment_location_buddy_links.dart`
- Modify: `lib/core/services/sync/sync_service.dart`, `lib/features/buddies/data/repositories/buddy_repository.dart`, `lib/features/buddies/data/repositories/buddy_merge_repository.dart`, `lib/features/buddies/data/repositories/buddy_conversion_repository.dart`, `lib/features/divers/data/repositories/diver_repository.dart`
- Test: `test/core/services/sync/equipment_location_sync_test.dart`, `test/features/equipment/data/repositories/equipment_location_buddy_links_test.dart`, `test/features/buddies/data/repositories/buddy_merge_place_links_test.dart`, `test/features/divers/data/repositories/diver_delete_place_buddy_link_test.dart`

**Interfaces:**
- Consumes: `buddyId` from Task 1.
- Produces: `Future<void> clearEquipmentLocationBuddyLinks(AppDatabase db, SyncRepository sync, Iterable<String> buddyIds, {required int now})`; `Future<Map<String, String>> repointEquipmentLocationBuddyLinks(AppDatabase db, SyncRepository sync, {required List<String> fromBuddyIds, required String toBuddyId, required int now})` returning place id to previous buddy id; `Future<void> restoreEquipmentLocationBuddyLinks(AppDatabase db, SyncRepository sync, Map<String, String> previous, {required int now})`; `BuddyMergeSnapshot.placeOriginalBuddyIds`.

- [ ] **Step 1: Write failing tests.** Sync: with the key, with null, with no key, through both apply paths, and a missing buddy clears the link. Links: each helper stamps `updated_at` and marks pending, chunking past 500 ids. Merge: `moves links to the survivor`, `undo restores each place's own link`. Delete: `deleteBuddy`, `bulkDeleteBuddies` and the conversion undo keep the place and mark it pending. Diver delete: a surviving place's link clears.
- [ ] **Step 2: Run each file alone, confirm RED.**
- [ ] **Step 3: Implement.** Add `(field: 'buddyId', parent: 'buddies', nullable: true)` to the `equipmentLocations` parent list. Follow `clearEquipmentLocationCenterLinks` for the clear helper. Call it before the delete in `_deleteBuddyInner`, `_bulkDeleteBuddiesInner` and `_deleteIfUnlinked`, and in `diver_repository.dart` after `retireDiverEquipmentLocations` with `SELECT id FROM buddies WHERE diver_id = ?`. In `_mergeBuddiesInner` repoint beside `repointMediaPeopleForMerge`, before the duplicates are deleted. In `_undoMergeInner` restore after step 2 re-creates the buddies.
- [ ] **Step 4: Run those files and `test/features/buddies/data`, confirm GREEN.**
- [ ] **Step 5: Commit** `feat(equipment): keep buddy links across sync, delete and merge`.

### Task 3: Status offer and domain rules

**Files:**
- Modify: `lib/features/equipment/domain/services/location_status_offer.dart`, `test/features/equipment/domain/services/location_status_offer_test.dart`
- Create: `lib/features/equipment/domain/services/gear_with_buddy.dart`
- Test: `test/features/equipment/domain/services/gear_with_buddy_test.dart`

**Interfaces:**
- Produces: `typedef GearWithBuddy = ({EquipmentItem item, EquipmentLocation place});`; `List<GearWithBuddy> gearWithBuddy(String buddyId, List<EquipmentItem> items, Map<String, EquipmentLocation> currentPlaces)`, sorted with `sortedByText`; `String? placeBeforeLoan(List<EquipmentLocationMove> movesNewestFirst, Map<String, EquipmentLocation> places, String buddyId)`; `DateTime notBeforeCurrentMove(DateTime movedAt, DateTime currentMoveAt)`.

- [ ] **Step 1: Write failing tests.** `offeredStatusAfterMove`: Loaned Out to `other` and to null gives Active; every other status gives null there. `gearWithBuddy`: lists linked gear by name, counts an archived place, leaves out other buddies. `placeBeforeLoan`: skips every place linked to the buddy, returns the first other place; null for a null move, no prior move, an archived place, or a place missing from `places`. `notBeforeCurrentMove`: earlier returns `currentMoveAt`, later returns `movedAt`.
- [ ] **Step 2: Run, confirm RED.**
- [ ] **Step 3: Implement.** Split `case other` and `case null` to return `current == EquipmentStatus.loaned ? EquipmentStatus.active : null`, and update the doc comment.
- [ ] **Step 4: Run, confirm GREEN.**
- [ ] **Step 5: Commit** `feat(equipment): offer Active when loaned gear moves off a person`.

### Task 4: Strings

**Files:**
- Modify: all 11 `lib/l10n/arb/app_*.arb`, generated `lib/l10n/arb/app_localizations*.dart`

**Interfaces:**
- Produces: `equipment_location_picker_lendToBuddy` "Lend to a buddy"; `equipment_locations_buddyLabel` "Buddy"; `equipment_locations_buddyNone` "None"; `equipment_locations_buddyClear` "Remove buddy"; `equipment_location_withBuddy(name)` "With {name}"; `buddies_action_lendGear` "Lend gear"; `buddies_gear_title(name)` "Gear with {name}"; `buddies_gear_returned` "Returned"; `buddies_gear_allReturned` "All returned"; `equipment_location_return_title(count)` "Return {count} item(s)"; `equipment_location_return_to(place)` "Back to {place}"; `equipment_location_return_eachToOwn` "Each item goes back where it was"; `equipment_location_return_confirm` "Mark returned"; `equipment_location_returned(count)` "{count} item(s) returned".

- [ ] **Step 1: Add keys by group,** anchoring on a neighbouring key in each file, translated. `@` metadata in `app_en.arb`.
- [ ] **Step 2: Run `flutter gen-l10n`, then `flutter analyze lib/l10n`.** Expected: no issues.
- [ ] **Step 3: Commit** `feat(equipment): strings for lending gear to buddies`.

### Task 5: Lending through Move

**Files:**
- Create: `lib/features/buddies/presentation/widgets/buddy_pick_sheet.dart`
- Modify: `lib/features/equipment/presentation/widgets/equipment_location_picker_sheet.dart`, `lib/features/equipment/presentation/widgets/move_equipment_sheet.dart`, `lib/features/equipment/presentation/widgets/equipment_location_field.dart`, `lib/features/equipment/presentation/widgets/location_move_edit_dialog.dart`
- Test: `test/features/buddies/presentation/widgets/buddy_pick_sheet_test.dart`, `test/features/equipment/presentation/widgets/equipment_location_picker_sheet_test.dart`, `test/features/equipment/presentation/widgets/move_equipment_sheet_test.dart`

**Interfaces:**
- Consumes: `findOrCreateForBuddy`, Task 4 strings.
- Produces: `class BuddyPick extends LocationPick { final Buddy buddy; }`; `showEquipmentLocationPickerSheet(context, ref, {bool offerBuddies = false})`; `Future<Buddy?> showBuddyPickSheet(BuildContext, WidgetRef)`; `showMoveEquipmentFlow(context, ref, {required items, Buddy? lendTo})`; `showMoveEquipmentSheet(..., LocationPick? initialPick)`.

- [ ] **Step 1: Write failing tests.** Picker: row shows with `offerBuddies: true`, hidden by default, and returns `BuddyPick`. Sheet: lists `allBuddiesProvider`, filters by search, Add New Buddy returns the new buddy. Move: a `BuddyPick` shows the buddy's name, confirm calls `findOrCreateForBuddy` with the buddy, cancel never calls it, the status prompt offers Loaned Out. Field and move edit dialog: no row.
- [ ] **Step 2: Run each file alone, confirm RED.**
- [ ] **Step 3: Implement.** In `_MoveEquipmentSheet` pass `offerBuddies: true`, seed `_pick` from `initialPick`, render `BuddyPick` with `Icons.person_outline` and the buddy's name. In `showMoveEquipmentFlow` resolve `BuddyPick` to a place inside the same `try` as `flow.run`, with `validatedCurrentDiverIdProvider`. The two other callers add `BuddyPick() =>` arms that keep their current value. Follow `_BuddySelectionSheet` for the push to `/buddies/new`, including its comment on a covered route.
- [ ] **Step 4: Run those files, confirm GREEN.**
- [ ] **Step 5: Commit** `feat(equipment): lend gear to a buddy from the move sheet`.

### Task 6: Place dialog, place page, item card

**Files:**
- Modify: `lib/features/equipment/presentation/widgets/equipment_location_edit_dialog.dart`, `lib/features/equipment/presentation/pages/equipment_location_detail_page.dart`, `lib/features/equipment/presentation/widgets/equipment_location_card.dart`
- Test: `test/features/equipment/presentation/widgets/equipment_location_edit_dialog_test.dart`, `test/features/equipment/presentation/pages/equipment_location_detail_buddy_row_test.dart`, `test/features/equipment/presentation/widgets/equipment_location_card_test.dart`

**Interfaces:**
- Consumes: `showBuddyPickSheet`, `buddyByIdProvider`, Task 4 strings.
- Produces: keys `equipment_location_buddy`, `equipment_location_buddy_clear`, `equipment_location_buddy_row`.

- [ ] **Step 1: Write failing tests.** Dialog: field appears only for Person, name fills only when blank or still the last pick, a kind change clears the link, an unchanged Other keeps it, saving with no buddy works. Place page: row opens `/buddies/:id`, absent when unlinked or unavailable. Card: "With Anna" uses the buddy's current name and opens the buddy; unlinked and unavailable keep the place name and no tap; history rows keep the place name.
- [ ] **Step 2: Run each file alone, confirm RED.**
- [ ] **Step 3: Implement,** mirroring `_centerField`, `_pickCenter` and the `centerId` save rule with `_buddyId`, and `_CenterRow` for the place page.
- [ ] **Step 4: Run those files, confirm GREEN.**
- [ ] **Step 5: Commit** `feat(equipment): show the buddy on places and items`.

### Task 7: Return flow

**Files:**
- Create: `lib/features/equipment/data/services/equipment_return_flow.dart`, `lib/features/equipment/presentation/widgets/return_equipment_sheet.dart`
- Modify: `lib/features/equipment/presentation/widgets/move_equipment_sheet.dart` (share the prompt helper)
- Test: `test/features/equipment/data/services/equipment_return_flow_test.dart`, `test/features/equipment/presentation/widgets/return_equipment_sheet_test.dart`

**Interfaces:**
- Consumes: `placeBeforeLoan`, `notBeforeCurrentMove`, `partsOf`, `getMovesFor`, `getCurrentLocationIds`, `recordMoves`.
- Produces: `EquipmentReturnFlow({moves, askMoveParts, askStatus, setStatus, onStatusFailed}).run({required List<EquipmentItem> items, required String buddyId, required Map<String, EquipmentLocation> places, required DateTime movedAt, String note = ''}) -> Future<int>`; `Future<int?> showEquipmentReturnFlow(BuildContext, WidgetRef, {required List<EquipmentItem> items, required String buddyId})`.

- [ ] **Step 1: Write failing tests.** Flow: each item returns to its own previous place; mixed destinations; no prior move gives No location and still offers Active; Loaned Out offered Active once across several destinations, with a Service shop destination too; Active and other statuses get no prompt; a return dated before the loan lands at the loan's `moved_at`, per item with mixed loan dates; a part at the same buddy asks the parts prompt and goes to its own previous place; a part elsewhere is not asked about; a failed status write calls `onStatusFailed` and still returns the count. Sheet: date defaults to today, shows "Back to {place}" for one destination and the each-to-own line for several.
- [ ] **Step 2: Run each file alone, confirm RED.**
- [ ] **Step 3: Implement.** Filter `partsOf` to parts whose current place links to the buddy. Group by `(destination, effective movedAt)` and call `recordMoves` per group. Offer Active directly, never through `offeredStatusAfterMove`. Sheet uses `showAppDatePicker` and `resolveMovedAt` with no time.
- [ ] **Step 4: Run those files, confirm GREEN.**
- [ ] **Step 5: Commit** `feat(equipment): return gear to where it was before a loan`.

### Task 8: Buddy page

**Files:**
- Create: `lib/features/buddies/presentation/widgets/buddy_gear_section.dart`, `lib/features/equipment/presentation/widgets/lend_gear_flow.dart`
- Modify: `lib/features/buddies/presentation/pages/buddy_detail_page.dart`
- Test: `test/features/buddies/presentation/widgets/buddy_gear_section_test.dart`, `test/features/equipment/presentation/widgets/lend_gear_flow_test.dart`, `test/features/buddies/presentation/pages/buddy_detail_page_test.dart`

**Interfaces:**
- Consumes: `gearWithBuddy`, `itemsAtPlaces`, `equipmentLocationMovesProvider`, `showEquipmentReturnFlow`, `showMoveEquipmentFlow(lendTo:)`.
- Produces: `BuddyGearSection(buddy:)`; `Future<void> showLendGearFlow(BuildContext, WidgetRef, Buddy)`.

- [ ] **Step 1: Write failing tests.** Section: lists linked gear by name with type and "Since {date}"; the Loaned Out status shows only for Loaned Out items; place name only when several places link to the buddy; archived place counted; builds nothing when empty; row opens the item; Returned runs the flow for one item; All returned appears from two rows and runs it for all. Flow: the picker gets gear already at this buddy in `selectedEquipmentIds`, confirm opens the Move sheet with `BuddyPick`, cancel does nothing. Page: Lend gear in both menus, reachable with no gear.
- [ ] **Step 2: Run each file alone, confirm RED.**
- [ ] **Step 3: Implement.** `Card` with `Padding(all: 16)` and the bold `titleMedium` title used by `_buildNotesSection`. Insert between the stats and Notes with its own `SizedBox`, inside the section so an empty list leaves no gap. Add a `'lend'` value to both `PopupMenuButton`s. Keep `buddy_detail_page.dart` under 800 lines.
- [ ] **Step 4: Run those files, confirm GREEN.**
- [ ] **Step 5: Commit** `feat(buddies): list and lend gear from the buddy page`.

### Task 9: Docs and final checks

**Files:**
- Modify: `docs/user/equipment.md`, `docs/user/buddies-and-dive-centers.md`

- [ ] **Step 1: Document** lending to a buddy, the buddy page section, returning gear, and recording family gear by answering No, in the Locations section and the buddies page.
- [ ] **Step 2: Run** `dart format .`, whole-repo `flutter analyze`, `test/architecture/`, `test/shared/`, `test/features/equipment`, `test/features/buddies`, `test/core/database`, `test/core/services/sync`. Expected: no issues, all pass.
- [ ] **Step 3: Commit** `docs(user): lending gear to buddies`.
