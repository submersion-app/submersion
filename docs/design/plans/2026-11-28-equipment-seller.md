# Equipment Seller Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (native, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a gear item's purchase record name its seller as a linked buddy, a linked dive centre, or a typed name, and list bought gear on the buddy's and centre's pages.

**Architecture:** Two nullable link columns on `equipment` (`seller_buddy_id`, `seller_dive_center_id`, SET NULL) sit beside the existing `retailer` attribute row, which always holds the seller's name. A pure domain resolver turns (item, buddies, centres) into a displayable seller; the repository holds the "at most one link" rule and the "retailer edited elsewhere clears the links" rule; delete and merge paths mirror the equipment location helpers.

**Tech Stack:** Flutter, Drift, Riverpod, the app's custom sync (`SyncDataSerializer`, `SyncService` FK map), ARB l10n (12 locales).

**Spec:** `docs/design/specs/2026-11-28-equipment-seller-design.md`

## Global Constraints

- Tables in `lib/core/database/tables/`, rungs and helpers in `lib/core/database/migrations/`; never in `database.dart` beyond bumping `currentSchemaVersion`.
- Schema version: the next free number at build time; re-check after every merge from main. Built as v397: open PRs claimed 394 to 396 when Task 1 ran, and main later took 394.
- No backfill: existing rows get no link, keep their `retailer` text.
- Every user-visible string in all 12 ARB files (`ar de en es fr he hu it ja nl pt zh`); `attrLabel_retailer` reads "Seller" in English.
- No em-dashes anywhere; no tool attribution in commits.
- Run only the test files written or changed, by path.

## Review Focus

1. A buddy renamed after linking, then re-picked in the editor: the link must stay (the repository must not read the refreshed name as a typed edit).
2. An item linked to a buddy, edited by an agent or import that changes only `retailer`: the links clear and the typed name shows.
3. A linked buddy deleted on this device: the item still shows the buddy's last name, and the sync row carries the cleared link.
4. A shared item viewed by another profile: the seller shows as plain text, never as a tappable link to a buddy that profile cannot open.
5. A centre with 80 bought items, and one with a wishlist item linked: 5 rows plus "Show all (80)", wishlist item absent.

Each line has its test in the owning task below.

---

### Task 1: Schema, entity and repository mapping

**Files:**
- Modify: `lib/core/database/tables/equipment_tables.dart` (two columns after `coverMediaId`)
- Create: `lib/core/database/migrations/helpers/equipment_seller_migrations.dart` (`part of '../app_database_migrations.dart'`)
- Modify: `lib/core/database/migrations/app_database_migrations.dart` (part line), `ladder/rungs_v340_onward.dart` (rung 397), `before_open_table_backstops.dart` (backstop), `lib/core/database/database.dart` (`currentSchemaVersion = 397`)
- Modify: `lib/features/equipment/domain/entities/equipment_item.dart`, `lib/features/equipment/data/repositories/equipment_repository_impl.dart` (create companion ~L391, update companion ~L549, raw-row read ~L1212, mapper ~L1954), `lib/features/equipment/presentation/editing/gear_item_edit_fields.dart` (`_with` passes both through)
- Test: `test/core/database/migrations/equipment_seller_migration_test.dart`, `test/features/equipment/domain/equipment_item_seller_test.dart`, `test/features/equipment/data/repositories/equipment_seller_repository_test.dart`

**Interfaces:**
- Produces: `EquipmentItem.sellerBuddyId`, `EquipmentItem.sellerDiveCenterId` (`String?`), `copyWith(sellerBuddyId:, sellerDiveCenterId:, clearSellerLinks: bool)`, both in `props`. Drift: `EquipmentData.sellerBuddyId`, `.sellerDiveCenterId`.
- Produces: `extension EquipmentSellerMigrations on AppDatabase { Future<void> _assertEquipmentSellerColumns() }`.

- [ ] Step 1: Failing tests. Migration: a v396 database upgraded to 397 has both columns, nullable, existing rows null; running the assert twice is a no-op. Entity: `copyWith(clearSellerLinks: true)` nulls both; equality differs when a link differs. Repository: create then read back an item with `sellerBuddyId: 'b1'` round-trips; update to `sellerDiveCenterId: 'c1'` with `clearSellerLinks` round-trips; `getAllEquipment` (raw-row path) returns the links.
- [ ] Step 2: Run them; expect FAIL (unknown getters / missing columns).
- [ ] Step 3: Implement. Columns: `TextColumn get sellerBuddyId => text().nullable().references(Buddies, #id, onDelete: KeyAction.setNull)();` and the same for `DiveCenters`. Assert helper uses `_addColumnIfMissing('equipment', 'seller_buddy_id', 'TEXT REFERENCES buddies (id) ON DELETE SET NULL')` (and `seller_dive_center_id` / `dive_centers`), guarded by `_tableExists('equipment')`. Rung comment names issue #5140; floor does not move. Run build_runner (unfiltered, background).
- [ ] Step 4: Run the three test files; expect PASS. `flutter analyze`.
- [ ] Step 5: Commit `feat(equipment): seller link columns on equipment (#5140)`.

### Task 2: Seller resolver and the repository's seller rules

**Files:**
- Create: `lib/features/equipment/domain/entities/equipment_seller.dart`
- Create: `lib/features/equipment/data/repositories/equipment_seller_rules.dart`
- Modify: `equipment_repository_impl.dart` (`createEquipment`, `updateEquipment` call the rules)
- Test: `test/features/equipment/domain/equipment_seller_test.dart`, `test/features/equipment/data/repositories/equipment_seller_rules_test.dart`

**Interfaces:**
- Produces: `enum EquipmentSellerKind { buddy, diveCenter, typed }`; `class EquipmentSeller { kind, String? id, String name }`; `EquipmentSeller? resolveEquipmentSeller(EquipmentItem item, {required Map<String, Buddy> buddies, required Map<String, DiveCenter> centers})`.
- Produces: `Future<EquipmentItem> applySellerRules(AppDatabase db, {required EquipmentItem? stored, required EquipmentItem next})` throwing `ArgumentError` when both links are set.

- [ ] Step 1: Failing resolver tests: linked buddy present gives kind buddy with the buddy's CURRENT name (snapshot "Anna", buddy now "Anna B." gives "Anna B."); linked id missing from the map gives kind typed with the snapshot; no link and blank retailer gives null; centre likewise. Failing rules tests: both links set throws; `stored` linked to b1 with retailer "Anna", `next` same link with retailer "Lars" clears both links (Review Focus 2); `next` same link, retailer equal to buddy b1's current DB name "Anna B." keeps the link (Review Focus 1); retailer unchanged keeps links; a link change with any retailer keeps the new link.
- [ ] Step 2: Run; expect FAIL.
- [ ] Step 3: Implement. Rules: if `next` links equal `stored` links, `next.retailer != stored.retailer`, and `next.retailer` differs from the linked target's current name (one `select` on buddies or dive_centers), return `next.copyWith(clearSellerLinks: true)`. Call it at the top of `createEquipment` (stored null: only the both-set check) and inside `updateEquipment` before the write, reading the stored row.
- [ ] Step 4: Run; PASS. Analyze.
- [ ] Step 5: Commit `feat(equipment): seller resolver and link rules (#5140)`.

### Task 3: Delete, merge, conversion and diver delete paths

**Files:**
- Create: `lib/features/equipment/data/repositories/equipment_seller_links.dart`
- Modify: `lib/features/buddies/data/repositories/buddy_repository.dart` (~L480), `buddy_merge_repository.dart` (~L404 repoint, ~L594 restore on undo, ~L676 clear), `buddy_conversion_repository.dart` (~L313), `lib/features/divers/data/repositories/diver_repository.dart` (~L979, ~L985), `lib/features/dive_log/data/repositories/dive_parent_links.dart` (~L60)
- Test: `test/features/equipment/data/repositories/equipment_seller_links_test.dart` plus one assertion added to each existing caller's test file that already covers `clearEquipmentLocation*Links`

**Interfaces:**
- Produces: `clearEquipmentSellerBuddyLinks(AppDatabase, SyncRepository, Iterable<String> buddyIds, {required int now})`, `clearEquipmentSellerCenterLinks(...)` with the same shape; `Future<Map<String, String>> repointEquipmentSellerBuddyLinks(AppDatabase, SyncRepository, {required List<String> fromBuddyIds, required String toBuddyId, required int now})`; `restoreEquipmentSellerBuddyLinks(AppDatabase, SyncRepository, Map<String, String> previous, {required int now})`.

- [ ] Step 1: Failing tests: clearing writes the target's current name into each linked item's `retailer` attribute (creating the row when absent), nulls the link, bumps `updated_at`, and marks each item pending as `equipment` (Review Focus 3); repoint moves links to the survivor and refreshes the snapshot to the survivor's name, returning previous ids; restore puts the ids and the previous snapshots back; chunks over 500 ids work.
- [ ] Step 2: Run; FAIL.
- [ ] Step 3: Implement, mirroring `equipment_location_buddy_links.dart` (chunk size 500). The retailer write uses the repository's attribute save path for one key so its tombstone and change-log rules apply. Wire every call site beside the existing location-link call.
- [ ] Step 4: Run the new file and each touched caller test file; PASS. Analyze.
- [ ] Step 5: Commit `feat(equipment): keep the seller through buddy and centre delete and merge (#5140)`.

### Task 4: Sync, conflicts, clone and fold

**Files:**
- Modify: `lib/core/services/sync/sync_service.dart` (~L3589 `'equipment'` FK list), `lib/core/services/sync/conflict_reference.dart` (`'sellerBuddyId': 'buddies'`, `'sellerDiveCenterId': 'diveCenters'`), `lib/features/settings/presentation/conflicts/catalogue/equipment_fields.dart` (labels), `lib/features/equipment/domain/services/equipment_clone_seed.dart`, `lib/features/equipment/data/services/equipment_item_fold.dart`
- Test: the existing tests of each file, extended

- [ ] Step 1: Failing tests: FK map lists both fields `nullable: true` under `equipment`; a pulled equipment row whose seller buddy is absent arrives with the link cleared; conflict field catalogue labels both; a clone copies both links when it copies `retailer`; folding `from` into `into` takes `from`'s links only when it also takes `from`'s retailer.
- [ ] Step 2: Run; FAIL.
- [ ] Step 3: Implement the entries and copies.
- [ ] Step 4: Run; PASS. Analyze.
- [ ] Step 5: Commit `feat(equipment): sync and conflict handling for seller links (#5140)`.

### Task 5: Seller field in the gear editor

**Files:**
- Create: `lib/features/equipment/presentation/widgets/equipment_seller_field.dart`
- Modify: `gear_item_edit_fields.dart` (new `gearSellerField`), `gear_item_details_editor.dart` (render it in place of the retailer text field), `lib/features/equipment/presentation/widgets/equipment_attribute_form_section.dart` (`Set<String> excludeKeys = const {}`), ARB files
- Test: `test/features/equipment/presentation/widgets/equipment_seller_field_test.dart`, `test/features/equipment/presentation/editing/gear_item_edit_fields_test.dart`, `gear_item_details_editor_test.dart`

**Interfaces:**
- Produces: `typedef GearSeller = ({String? buddyId, String? centerId, String name});` and `final gearSellerField = EditField<EquipmentItem, GearSeller>(id: 'seller', cardId: _details, ...)` whose write sets both links and the `retailer` attribute (blank name removes it).
- Produces: `EquipmentSellerField({required GearSeller value, required ValueChanged<GearSeller> onChanged})`, keys `ValueKey('gear-edit-seller')`, chip `ValueKey('gear-edit-seller-chip')`.

- [ ] Step 1: Failing tests: typing "An" lists buddy "Anna Berg" (label "Buddy") and centre "Anchor Dive" (label "Dive centre") from `allBuddiesProvider` / `allDiveCentersProvider`, plus "Keep \"An\" as typed"; picking the buddy shows the chip and emits `(buddyId: 'b1', centerId: null, name: 'Anna Berg')`; the chip's clear emits an empty typed seller and shows the text field; typing "Anna Berg" without picking stays typed; the details editor no longer renders `attr-field-retailer` and saves the picked link; the field shows on a wishlist item.
- [ ] Step 2: Run; FAIL.
- [ ] Step 3: Implement with `RawAutocomplete` (case-insensitive substring match on name, buddies first then centres, at most 8 suggestions). Strings: `equipment_seller_kindBuddy` "Buddy", `equipment_seller_kindDiveCenter` "Dive centre", `equipment_seller_keepTyped` "Keep \"{name}\" as typed", `equipment_seller_clear` "Clear seller"; `attrLabel_retailer` "Seller" in every locale.
- [ ] Step 4: Run; PASS. Analyze.
- [ ] Step 5: Commit `feat(equipment): pick a buddy or dive centre as the seller (#5140)`.

### Task 6: Seller row on the gear page

**Files:**
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page_sections.dart` (`_buildPurchaseAttributeRow` for `retailer`)
- Test: `test/features/equipment/presentation/pages/equipment_detail_page_test.dart`

- [ ] Step 1: Failing tests: a linked buddy shows its current name with a person icon and tapping pushes `/buddies/b1`; a linked centre pushes `/dive-centers/c1`; a typed seller is plain text; a link whose buddy is not in the current diver's list renders plain text with no tap target (Review Focus 4); label reads "Seller".
- [ ] Step 2: Run; FAIL.
- [ ] Step 3: Implement with `resolveEquipmentSeller` over `allBuddiesProvider` and `allDiveCentersProvider`.
- [ ] Step 4: Run; PASS. Analyze.
- [ ] Step 5: Commit `feat(equipment): show the seller on the gear page (#5140)`.

### Task 7: "Bought from" and "Bought here" blocks

**Files:**
- Create: `lib/features/equipment/domain/services/gear_bought_from.dart`, `lib/features/equipment/presentation/widgets/gear_bought_from_section.dart`
- Modify: `lib/features/buddies/presentation/pages/buddy_detail_page.dart` (after the gear card, not on create), `lib/features/dive_centers/presentation/pages/dive_center_detail_page_body.dart` (after `GearHereSection`, via `_calculated`), ARB files
- Test: `test/features/equipment/domain/gear_bought_from_test.dart`, `test/features/equipment/presentation/widgets/gear_bought_from_section_test.dart`

**Interfaces:**
- Produces: `List<EquipmentItem> gearBoughtFrom(List<EquipmentItem> items, {String? buddyId, String? centerId})` (excludes `EquipmentStatus.wanted`; newest `purchaseDate` first, undated last, then name); `GearBoughtFromSection({String? buddyId, String? centerId, required String title})` reading `allEquipmentProvider`.

- [ ] Step 1: Failing tests: ordering and the wishlist exclusion (Review Focus 5); 0 items builds nothing; 1 item shows name and "Bought 12 Mar 2025"; 80 items show 5 rows and "Show all (80)", which expands in place; a sold item shows its status label; tapping a row pushes `/equipment/<id>`; titles "Bought from Anna Berg" and "Bought here".
- [ ] Step 2: Run; FAIL.
- [ ] Step 3: Implement. Strings: `equipment_boughtFrom_title` "Bought from {name}", `equipment_boughtHere_title` "Bought here", `equipment_boughtFrom_showAll` "Show all ({count})". Reuse `equipment_rowLabel_purchased` for the date.
- [ ] Step 4: Run; PASS. Analyze.
- [ ] Step 5: Commit `feat(equipment): list gear bought from a buddy or dive centre (#5140)`.

### Task 8: Agent access and finish

**Files:**
- Modify: `lib/features/agent_access/data/documents/gear_documents.dart` (seller name, kind), tests beside it
- Test: existing agent gear document test

- [ ] Step 1: Failing test: a linked item's gear document reports `seller` with the resolved name and kind; an agent write changing only `retailer` on a linked item lands typed (covered by Task 2's rule, asserted end to end here).
- [ ] Step 2-4: Implement, run, analyze. `dart format .`.
- [ ] Step 5: Commit `feat(agent-access): report the gear seller (#5140)`.
