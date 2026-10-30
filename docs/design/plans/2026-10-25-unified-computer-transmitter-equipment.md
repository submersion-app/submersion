# One Equipment Entry per Dive Computer and Transmitter: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (this repo's build-feature workflow runs it natively, in one session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make each dive computer and transmitter one Equipment item that carries every control, with discovery and downloads creating the item.

**Architecture:** `dive_computers` and `transmitters` stay as device records behind an Equipment item, linked by `dive_computers.equipment_id` and `transmitters.transmitter_equipment_id`, which become always-set. One database-level heal (`ensureDeviceGearLinks`) guarantees the links at upgrade, on every open and after every sync, minting replacement items on a tombstone-avoiding id chain. The Equipment detail page gains a Dive computer section and a Transmitter section; the two lists read Equipment items.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod, go_router, flutter_test.

**Spec:** `docs/design/specs/2026-10-25-unified-computer-transmitter-equipment-design.md` (issue #3676)

## Global Constraints

- Schema version becomes **315** (`AppDatabase.currentSchemaVersion`); if another PR takes 315 first, renumber and say so in the rung comment, as the existing rungs do.
- Rung body in `lib/core/database/migrations/ladder/rungs_v231_onward.dart`; `database.dart` gets only the version bump and the `migrationVersions` entry.
- `before_open.dart` is at the 800-line guard: any new backstop goes in a part file.
- No `lib/` file over 800 lines; `equipment_detail_page.dart` (1163) and `device_detail_page.dart` (1055) get no inline additions.
- Every synced write is staged (`markRecordPending`, `logDeletion`) wherever existing code at that seam stages; the heal is the exception and is HLC-neutral by design (Task 3).
- New user-facing strings go in `lib/l10n/arb/app_en.arb` (and are regenerated); placeholder name format: "Transmitter {serial}".
- Paths in tests via `p.join`; tests restore any global state they replace.
- No em-dashes anywhere, no AI attribution anywhere.
- Before committing each task: `dart format .`, `flutter analyze`, the task's tests; after adding `lib/` files also `test/architecture/` and `test/shared/`.

## Review Focus

1. **A device-backed item's type is changed** (Dive Computer to Mask): the computer must not point at a mask. Expected: the type field is locked on an item that has a device record. Test in Task 8.
2. **An older peer deletes a gear twin after this device upgraded:** the tombstone arrives, SQLite nulls `equipment_id`, and the next heal must mint the next id in the chain, never the tombstoned one. Test in Task 3.
3. **Two current devices heal the same unlinked computer independently:** both must produce the same equipment id, so sync converges. Test in Task 3.
4. **A serial that only differs by formatting** ("004A21F" vs "4a21f"): registrar, linker, heal and nudge all go through `normalizeTransmitterSerial`, so one item, never two. Test in Task 5.
5. **"Connect and download" on a hand-added item finds a device already registered to another item:** must not rebind silently. Test in Task 10.

---

### Task 0: Before screenshots

**Files:** none (scratchpad only)

- [ ] **Step 1:** Launch the app with the `run` skill on macOS desktop width. Capture, light mode: Dive Computers list, a computer's detail page, the Equipment detail page of that computer's gear item, Settings > Manage > Transmitters (with its Unassigned section if the data has one), a transmitter edit page. Repeat the list and both detail pages at phone width.
- [ ] **Step 2:** Save as `<nn>-<screen>-before[-phone].png` in the scratchpad. No commit.

---

### Task 1: Gear identity: re-mint chain and matching fallback

**Files:**
- Modify: `lib/core/database/dive_computer_gear_identity.dart`
- Test: `test/core/database/dive_computer_gear_identity_test.dart`

**Interfaces:**
- Produces:
  - `const String kDeviceGearRemintNamespace` (a new frozen UUID literal; pick one and never change it).
  - `String nextGearRemintId(String deviceKey, String replacedItemId)`: UUIDv5 of `'submersion:device-gear-remint:$deviceKey:$replacedItemId'` in that namespace.
  - `String gearIdAvoiding(String firstId, String deviceKey, bool Function(String id) isTombstoned)`: returns `firstId` if not tombstoned, else follows `nextGearRemintId` until an id is not tombstoned. Pure; bounded loop (stop after 64 steps and return the last id, logging is the caller's job).
  - `String transmitterGearSeedId(String? diverId, String normalizedSerial)`: UUIDv5 in a second new frozen namespace `kTransmitterGearNamespace` of `'submersion:transmitter-gear:${diverId ?? ''}:$normalizedSerial'`.
  - `String autoTransmitterRowId(String? diverId, String normalizedSerial)`: same scheme, namespace `kAutoTransmitterRowNamespace`.
  - `matchGearTwin` keeps its signature; behaviour change below.

- [ ] **Step 1: Write the failing tests**

```dart
group('gearIdAvoiding', () {
  test('returns the first id when it was never deleted', () {
    expect(gearIdAvoiding('a', 'c1', (_) => false), 'a');
  });
  test('skips a tombstoned id deterministically', () {
    final second = nextGearRemintId('c1', 'a');
    expect(gearIdAvoiding('a', 'c1', (id) => id == 'a'), second);
    expect(gearIdAvoiding('a', 'c1', (id) => id == 'a'), second); // stable
  });
  test('follows the chain past two deletions', () {
    final second = nextGearRemintId('c1', 'a');
    final third = nextGearRemintId('c1', second);
    expect(gearIdAvoiding('a', 'c1', {'a', second}.contains), third);
  });
});

group('matchGearTwin serial fallback', () {
  const blankSerialTeric = GearTwinCandidate(id: 'g1', diverId: 'd', brand: 'Shearwater', model: 'Teric');
  test('a serial-bearing computer adopts the one same-model item with a blank serial', () {
    expect(matchGearTwin(manufacturer: 'Shearwater', model: 'Teric', serialNumber: '1234', diverId: 'd', candidates: [blankSerialTeric])?.id, 'g1');
  });
  test('an item with a different serial is never adopted', () {
    const other = GearTwinCandidate(id: 'g2', diverId: 'd', brand: 'Shearwater', model: 'Teric', serialNumber: '9999');
    expect(matchGearTwin(manufacturer: 'Shearwater', model: 'Teric', serialNumber: '1234', diverId: 'd', candidates: [other]), isNull);
  });
  test('a serial match still wins over a blank-serial model match', () {
    const exact = GearTwinCandidate(id: 'g3', diverId: 'd', brand: 'Shearwater', model: 'Teric', serialNumber: '1234');
    expect(matchGearTwin(manufacturer: 'Shearwater', model: 'Teric', serialNumber: '1234', diverId: 'd', candidates: [blankSerialTeric, exact])?.id, 'g3');
  });
  test('two blank-serial same-model items are ambiguous', () {
    const twin = GearTwinCandidate(id: 'g4', diverId: 'd', brand: 'Shearwater', model: 'Teric');
    expect(matchGearTwin(manufacturer: 'Shearwater', model: 'Teric', serialNumber: '1234', diverId: 'd', candidates: [blankSerialTeric, twin]), isNull);
  });
});
```

- [ ] **Step 2: Run** `flutter test test/core/database/dive_computer_gear_identity_test.dart`. Expected: FAIL (undefined `gearIdAvoiding`, and the fallback tests return null).
- [ ] **Step 3: Implement.** In `matchGearTwin`, when `wantSerial` is non-empty and the serial tier returns null, run the existing exact and `computerNamesAgree` tiers over `sameDiver` filtered to candidates whose normalized serial is empty. Update the doc comment: callers pass computer-type items of any status except `wanted`.
- [ ] **Step 4: Run** the same test file. Expected: PASS, including the pre-existing tests.
- [ ] **Step 5: Commit** `feat(equipment): gear id re-mint chain and serial fallback matching`.

---

### Task 2: Schema v315: `transmitters.is_configured`

**Files:**
- Modify: `lib/core/database/tables/cylinder_tables.dart` (Transmitters), `lib/core/database/database.dart` (version 315, `migrationVersions` entry with comment), `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (v315 block: column only for now; Task 4 adds the data steps), a new before-open part file for the column backstop (follow how `_assertDiveCenterClosedColumn` is wired), `lib/features/transmitters/domain/entities/transmitter.dart`, `lib/features/transmitters/data/repositories/transmitter_repository.dart` (`_companion`, `_map`)
- Test: `test/core/database/migration_v315_device_gear_test.dart` (create), `test/features/transmitters/domain/transmitter_test.dart` (extend or create)

**Interfaces:**
- Produces:
  - Drift column `BoolColumn get isConfigured => boolean().withDefault(const Constant(true))();` (SQL `is_configured`, synced, additive; follow v313 `isPermanentlyClosed` for older-payload handling).
  - `Transmitter.isConfigured` (bool, default `true`, in constructor, `copyWith`, `props`).
  - `bool get Transmitter.isSetUp => isConfigured && (equipmentId != null || (volumeL ?? 0) > 0);`
  - `static Set<String> Transmitter.setUpSerials(Iterable<Transmitter>)`: like `knownSerials`, only rows where `isSetUp`.

- [ ] **Step 1: Write failing tests**: `v315 is the current schema version and in the ladder`; `upgrading from v314 adds is_configured defaulting to 1 on existing rows` (raw v314 fixture with one transmitters row; after open, `SELECT is_configured` is 1); `the column is additive, so the sync floor does not move` (`minimumCompatibleSchemaVersion` unchanged); entity: `isSetUp is false when not configured`, `isSetUp is false with no cylinder link and no volume`, `isSetUp is true with a volume and no link`, `setUpSerials skips not-set-up rows`.
- [ ] **Step 2: Run** both files. Expected: FAIL.
- [ ] **Step 3: Implement** the column, rung `if (from < 315)` column assert plus `reportProgress`, backstop, entity field and getters, repository mapping. The `migrationVersions` comment records the known cost of keeping the floor: a peer still on v314 ignores `is_configured` and so treats an auto-created row as configured (its downloads would name tanks "Transmitter <serial>") until it updates. Run codegen (`bash scripts/setup.sh` is the permitted wrapper if `build_runner` is refused).
- [ ] **Step 4: Run** the two tests plus `test/core/database` and `test/core/services/sync`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(transmitters): is_configured column (schema v315)`.

---

### Task 3: The device gear heal

**Files:**
- Create: `lib/core/database/device_gear_heal.dart`
- Test: `test/core/database/device_gear_heal_test.dart`

**Interfaces:**
- Consumes: Task 1 identity functions; Task 2 column.
- Produces:
  - `Future<bool> isEquipmentTombstoned(DatabaseConnectionUser db, String id)`: a `deletion_log` row with `entity_type = 'equipment'` and `record_id = id`.
  - `Future<String> liveGearId(DatabaseConnectionUser db, String firstId, String deviceKey)`: async version of `gearIdAvoiding` over the deletion log.
  - `String transmitterGearDeviceKey(String? diverId, String normalizedSerial) => 'tx:${diverId ?? ''}:$normalizedSerial';` the chain key every transmitter mint uses (Tasks 3, 4 and 5).
  - `Future<DeviceGearHealResult> ensureDeviceGearLinks(DatabaseConnectionUser db)` where `typedef DeviceGearHealResult = ({int computersLinked, int computerItemsMinted, int transmittersLinked, int transmitterItemsMinted});`

Behaviour of `ensureDeviceGearLinks` (PRAGMA-guarded like `backfillDiveComputerGearTwins`; HLC-neutral: no HLC, nothing marked pending, because every input is synced and every id is derived, so each device produces identical rows; document this in the file header the way v175 does):

1. Computers whose `equipment_id` is null or names no `equipment` row: candidates are `equipment` rows with `type = 'computer' AND status != 'wanted'`, excluding items already linked from another computer; `matchGearTwin`; on no match, `liveGearId(db, diveComputerGearId(computerId), computerId)` and `INSERT OR IGNORE` an Active item (name, brand, model, serial from the computer; same column list as v175). On adoption through the blank-serial fallback, set the item's `serial_number` to the computer's. `UPDATE dive_computers SET equipment_id`. For a minted item only, `INSERT OR IGNORE INTO dive_equipment` for the computer's dives (union of `dives.computer_id` and `dive_data_sources.computer_id`, as v175 pass 2).
2. Transmitter rows whose `transmitter_equipment_id` is null or dangling: with a normalized serial, candidates are `type = 'transmitter' AND status != 'wanted'` of the same diver whose normalized serial equals it, exactly one; else mint at `liveGearId(db, transmitterGearSeedId(diverId, serial), transmitterGearDeviceKey(diverId, serial))` (no serial: seed `nextGearRemintId('tx-row', rowId)` keyed on the row id) named the row's label, serial set, type `transmitter`. Update the row. Fill a blank item serial from the row.

- [ ] **Step 1: Write failing tests** (raw in-memory DB opened at current schema; seed rows with SQL):
  - `links a computer whose twin was deleted to the one matching blank-serial item`
  - `mints an item for a computer with nothing to match and links its dives`
  - `never mints at a tombstoned id` (insert `deletion_log` for `diveComputerGearId(c1)`; minted id equals `nextGearRemintId('c1', diveComputerGearId('c1'))`)
  - `an older peer deleting the re-minted item leads to the next id` (tombstone both; expect the third id)
  - `two databases heal the same unlinked computer to the same id` (two in-memory DBs, same seed, same result id)
  - `a Retired item is adopted and a Wanted one is not`
  - `an item already linked to another computer is not adopted`
  - `a transmitter row with no item adopts the one same-serial item, matching through normalization` ("004A21F" row, "4a21f" item)
  - `a transmitter row with no item mints one carrying its serial and label`
  - `running twice changes nothing the second time` (result counts all 0)
  - `writes no hlc and marks nothing pending`
- [ ] **Step 2: Run** `flutter test test/core/database/device_gear_heal_test.dart`. Expected: FAIL (file missing).
- [ ] **Step 3: Implement** in `device_gear_heal.dart`.
- [ ] **Step 4: Run** the test. Expected: PASS.
- [ ] **Step 5: Commit** `feat(equipment): heal dive computers and transmitters without an item`.

---

### Task 4: The v315 data steps, open-time and post-sync heal

**Files:**
- Create: `lib/core/database/device_gear_upgrade.dart`
- Modify: `rungs_v231_onward.dart` (v315 block), the Task 2 before-open part file (call `ensureDeviceGearLinks` on every open, after the column assert), `lib/core/services/sync/sync_service.dart` (call `ensureDeviceGearLinks(_db)` once at the end of a successful `_performSyncRun`, best-effort with a logged warning, then `SyncEventBus.notifyLocalChange()` if anything changed)
- Test: `test/core/database/migration_v315_device_gear_test.dart` (extend), `test/core/database/device_gear_upgrade_test.dart`

**Interfaces:**
- Consumes: Task 3.
- Produces, all `DatabaseConnectionUser`-scoped, HLC-neutral, PRAGMA-guarded:
  - `Future<void> alignComputerNamesAndNotes(DatabaseConnectionUser db)`: for each linked pair, the name of the row with the larger `updated_at` is written to both; notes: blank item takes the computer's; both non-blank and different: item notes become `'$itemNotes\n\n$computerNotes'`; equal: nothing.
  - `Future<int> registerUnassignedSerials(DatabaseConnectionUser db)`: for each (diver, normalized serial) on `dive_tanks` joined to `dives` with no transmitters row of that diver and serial, insert an item (id `liveGearId(db, transmitterGearSeedId(diverId, serial), transmitterGearDeviceKey(diverId, serial))`, name `'Transmitter $serial'`, type `transmitter`, serial set) and a row (id `autoTransmitterRowId`, `is_configured = 0`, role from the most recent `dive_tanks.tank_role` carrying the serial, else `backGas`, label = item name). Returns rows created. Note: the rung cannot read l10n, so the stored name is the English literal; the runtime registrar (Task 5) uses the localized string.
  - `Future<void> linkTransmitterGearToDives(DatabaseConnectionUser db)`: `INSERT OR IGNORE INTO dive_equipment` (dive, item) for every dive whose tanks carry a row's normalized serial (normalize in Dart, set-based insert per item).

Rung order inside `if (from < 315)`: column assert, `ensureDeviceGearLinks`, `alignComputerNamesAndNotes`, `registerUnassignedSerials`, `linkTransmitterGearToDives`. Only `ensureDeviceGearLinks` runs on open and after sync; the other three are ladder-only.

- [ ] **Step 1: Write failing tests:** v314 fixture end to end: `upgrade links a computer whose twin was deleted`, `upgrade appends differing computer notes below the item's`, `upgrade takes the later-updated name for both`, `upgrade registers an unassigned serial as a not-configured row with its item`, `upgrade puts transmitter items on the dives that carry them`, `upgrade leaves a set-up row's item and cylinder alone`; unit: `alignComputerNamesAndNotes keeps equal notes once`, `registerUnassignedSerials skips a serial another diver registered only for that diver`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the tests, then `test/core/database` and `test/core/services/sync`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(equipment): v315 upgrade and heal on open and after sync`.

---

### Task 5: Runtime registration: resolver, binding, transmitter registrar and gear linker

**Files:**
- Modify: `lib/features/equipment/data/services/dive_computer_gear_resolver.dart` (step 2 and step 4 use `liveGearId`; candidates `type = computer`, `status != wanted`, not linked to another computer; fallback serial write), `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` (`createComputer` keeps a non-null `computer.equipmentId` that names a live item instead of resolving)
- Create: `lib/features/transmitters/data/services/transmitter_auto_registrar.dart`, `lib/features/transmitters/data/services/transmitter_gear_linker.dart`
- Modify: `lib/features/dive_computer/data/services/transmitter_registry_matcher.dart` (`fromEntries` skips `!isConfigured`), `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart` (after dives are written: registrar, then linker, then the notice), `lib/features/dive_computer/data/services/reparse_service.dart` (registrar and linker after a reparse), `lib/features/transmitters/data/repositories/transmitter_repository.dart`
- Test: `test/features/equipment/data/services/dive_computer_gear_resolver_test.dart` (extend), `test/features/transmitters/data/services/transmitter_auto_registrar_test.dart`, `test/features/transmitters/data/services/transmitter_gear_linker_test.dart`, `test/features/dive_computer/data/services/transmitter_registry_matcher_test.dart` (extend), the adapter's existing test file (extend)

**Interfaces:**
- Produces:
  - `class TransmitterAutoRegistrar { Future<Set<String>> registerNewSerials(Iterable<String> serials, {required String? diverId, required String Function(String serial) nameFor}); }`: normalizes, skips serials with any row for the diver, adopts the one same-serial transmitter item (status not wanted) or mints at `liveGearId(db, transmitterGearSeedId(diverId, serial), transmitterGearDeviceKey(diverId, serial))`, inserts a row at `autoTransmitterRowId` with `isConfigured: false`, role from the dive tank (as Task 4), all staged (`markRecordPending`). Returns the normalized serials it registered.
  - `class TransmitterGearLinker { Future<void> linkSerials(Iterable<String> serials, {required String? diverId}); }`: adds each serial's item to every dive of the diver whose tanks carry it, through `DiveRepository.bulkAddEquipment`.
  - `Future<Set<String>> TransmitterRepository.serialsNeedingSetup(String? diverId)`: normalized serials of rows where `!isSetUp`.
  - `Future<String?> TransmitterRepository.itemIdForSerial(String serial, {String? diverId})`.
  - Notice: `ImportNoticeKind.unknownTransmitter` count = dives among the written dives carrying a serial in `serialsNeedingSetup` after registration.

- [ ] **Step 1: Write failing tests:** resolver `mints the next chain id when the derived twin was deleted`, `adopts a Retired same-serial item`, `createComputer keeps a preset equipmentId`; matcher `an unconfigured entry does not stamp its label or role`; registrar `creates one item and one unconfigured row per new serial`, `treats 004A21F and 4a21f as one serial`, `adopts the single existing same-serial item`, `skips a serial that already has a row`; linker `links the item to every dive carrying the serial and no others`; adapter `a download with a new serial creates its item, links it and raises the notice`, `a download of a set-up serial raises no notice`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** `nameFor` is `l10n.transmitters_autoName(serial)` at the adapter (new ARB key, "Transmitter {serial}"). Then find every other path that writes `dive_tanks.transmitter_serial` (`uddf_entity_importer.dart`, the universal import adapters, Garmin and Suunto cloud adapters; grep `transmitterSerial:`) and call the registrar and linker after its dives are written, with a test for each path that writes serials.
- [ ] **Step 4: Run** the tests plus `test/features/dive_computer`, `test/features/import_wizard`, `test/features/transmitters`, `test/features/equipment/data`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(transmitters): create a transmitter item for each new serial on download`.

---

### Task 6: The nudge

**Files:**
- Modify: `lib/features/data_quality/data/services/quality_context_builder.dart` (`_knownSerials` uses `Transmitter.setUpSerials`), `lib/features/data_quality/domain/detectors/unknown_transmitter_detector.dart` (version 3, doc comment), `lib/features/data_quality/domain/repairs/quality_repair_action.dart` (rename `AssignTransmitterRepair` to `SetUpTransmitterRepair(serial)`), `lib/features/data_quality/presentation/pages/data_quality_inbox_page.dart` and `widgets/quality_finding_card.dart` (the repair resolves `itemIdForSerial`, registering the serial through the registrar first when it has no row, then pushes `/equipment/<id>`)
- Test: the existing detector, context builder and inbox tests (extend)

- [ ] **Step 1: Write failing tests:** `an unconfigured transmitter on the dive raises the finding`, `a configured transmitter with a cylinder spec raises none`, `a configured transmitter with no cylinder raises it`, `the repair opens the transmitter's equipment page`, `the repair registers a serial with no row before opening it`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `test/features/data_quality`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(data-quality): nudge on transmitters with no cylinder set up`.

---

### Task 7: Delete and merge

**Files:**
- Modify: `lib/features/equipment/data/repositories/equipment_repository_impl.dart` (`deleteEquipment`: before the transaction, `DiveComputerRepository().deleteComputer` for each computer with `equipment_id = id`, and `TransmitterRepository().delete` for each row with `transmitter_equipment_id = id`; the existing `unlinkFromDeletedEquipment` still clears cylinder links), `dive_computer_repository_impl.dart` (`deleteComputer` deletes and tombstones transmitter rows with `dive_computer_id = id` and no serial), `lib/features/dive_log/data/repositories/dive_computer_merge_repository.dart` (move channel rows to the survivor, deleting any that would collide), the merge sheet's confirmation copy, `equipment_detail_page.dart` delete dialog content chosen by type (move the dialog into `lib/features/equipment/presentation/widgets/equipment_delete_dialog.dart` so the page does not grow)
- Test: `test/features/equipment/data/repositories/` (extend), the merge repository test (extend)

- [ ] **Step 1: Write failing tests:** `deleting a computer item deletes its registration and keeps its dives`, `deleting a transmitter item deletes its rows`, `deleting a computer deletes its channel-only transmitter rows and keeps their items`, `merging moves channel rows to the survivor`, `a colliding channel row is deleted on merge`, `the delete dialog for a computer item says the download history goes too`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** New ARB keys for the two dialog contents and the merge note.
- [ ] **Step 4: Run** the affected test directories. Expected: PASS.
- [ ] **Step 5: Commit** `feat(equipment): one delete for a device and its item`.

---

### Task 8: One name, one type

**Files:**
- Modify: `equipment_repository_impl.dart` (`updateEquipment` and `updateEquipmentWithTags`: in the same transaction write `name` and `notes` to `dive_computers` rows with `equipment_id = id`, and `label` to `transmitters` rows with `transmitter_equipment_id = id`, each staged), `equipment_edit_page.dart` (type dropdown disabled with a helper line when the item has a device record; new `initialType` parameter, read from `?type=` in the router), remove the old computer edit dialog from `device_detail_page.dart` (gone with Task 9)
- Test: repository test (extend), `test/features/equipment/presentation/pages/equipment_edit_page_test.dart` (extend)

- [ ] **Step 1: Write failing tests:** `renaming a computer item renames its computer`, `editing notes writes the computer's notes`, `renaming a transmitter item relabels its rows`, `the type field is locked for an item with a computer`, `?type=transmitter starts the form on Transmitter`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the tests. Expected: PASS.
- [ ] **Step 5: Commit** `feat(equipment): an item's name and notes are its device's`.

---

### Task 9: Dive computer section on the Equipment page

**Files:**
- Create: `lib/features/dive_computer/presentation/widgets/dive_computer_section.dart` (entry: `DiveComputerSection({required String equipmentId})`), plus split files for what moves out of `device_detail_page.dart`: `dive_computer_actions_card.dart`, `dive_computer_stats_card.dart`, `dive_computer_clock_sync_card.dart`, `dive_computer_info_card.dart` (manufacturer, model, serial, firmware, transmitters row, duplicate banner with Merge)
- Create provider: `computersForEquipmentProvider` (`FutureProvider.family<List<DiveComputer>, String>`, ordered by last download, newest first) in `dive_computer_providers.dart`
- Modify: `equipment_detail_page.dart` (one line: `if (equipment.type == EquipmentType.computer) DiveComputerSection(equipmentId: equipmentId)` after the details section, with its spacing)
- Delete: `device_detail_page.dart` once Task 11 removes its last route (the `_LinkedGearRow` goes with it; its misplaced doc comment problem disappears)
- Test: `test/features/dive_computer/presentation/widgets/dive_computer_section_test.dart`

- [ ] **Step 1: Write failing widget tests:** `a registered computer item shows download, re-import, reparse, connections, clock sync and stats`, `an unregistered computer item shows only Connect and download`, `two registrations show the duplicate banner with Merge`, `Connect and download pushes discovery bound to this item` (route `/dive-computers/discover?equipment=<id>`).
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement** by moving the existing card builders into the new widgets unchanged in behaviour; the section acts on the first of `computersForEquipmentProvider`.
- [ ] **Step 4: Run** the new test plus `test/features/dive_computer` and `test/features/equipment/presentation`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-computer): dive computer controls on its Equipment page`.

---

### Task 10: Connect and download binds to the item

**Files:**
- Modify: `app_router.dart` (`discover` reads `?equipment=`), `_DiveComputerDiscoveryWizardRoute` and `DiveComputerAdapter` (a `bindEquipmentId` constructor parameter; `ensureComputer` passes it as the new computer's `equipmentId`; when the discovered device resolves to an existing registration linked to a different item, return an `ImportNotice` of a new kind `deviceBelongsToOtherItem` carrying that item id, and do not rebind), the summary step (the notice offers "Open that item")
- Test: the adapter test file (extend)

- [ ] **Step 1: Write failing tests:** `a new device discovered from a hand-added item is created on that item`, `a device already registered to another item is not rebound and the notice names that item`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `test/features/import_wizard`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-computer): connect a hand-added computer item to its device`.

---

### Task 11: Transmitter section, the two lists, and routes

**Files:**
- Create: `lib/features/transmitters/presentation/widgets/transmitter_section.dart` (`TransmitterSection({required String equipmentId})`: keys, role, cylinder link and spec, Apply to existing dives, an Edit button opening `transmitter_setup_sheet.dart`), `lib/features/transmitters/presentation/widgets/transmitter_setup_sheet.dart` (the fields and validation of `TransmitterEditPage`, minus label and transmitter-gear pickers; saving writes role, cylinder link and spec to every row of the item with `isConfigured: true`; adding a key is part of the sheet)
- Create providers: `transmittersForEquipmentProvider` (family by equipment id); `computerItemsProvider` and `transmitterItemsProvider` (`FutureProvider<List<({EquipmentItem item, List<DiveComputer> computers})>>` and the transmitter equivalent, active diver, invalidated on equipment, computer and transmitter table changes)
- Modify: `device_list_page.dart` (reads `computerItemsProvider`; row shows item name, status, and dive count plus last download when registered; tap pushes `/equipment/<id>`; add menu offers discovery or `/equipment/new?type=computer`; selection bulk delete deletes the items), `transmitters_page.dart` (reads `transmitterItemsProvider`; Unassigned section removed; FAB pushes `/equipment/new?type=transmitter`), `equipment_detail_page.dart` (one line for `TransmitterSection`), `app_router.dart` (`:computerId` builder becomes a small resolver widget that replaces the location with `/equipment/<equipmentId>`, leaving the `download` child untouched; `/transmitters/new` redirects to `/equipment/new?type=transmitter`; `:transmitterId/edit` resolves to the row's item), the four `/dive-computers/<id>` call sites push `/equipment/<equipmentId>` directly
- Delete: `transmitter_edit_page.dart`, `device_detail_page.dart`, `getUnassignedSerials` callers and its provider if unused
- Test: `transmitter_section_test.dart`, `device_list_page_test.dart` and `transmitters_page_test.dart` (rewrite), a router test for the redirects

- [ ] **Step 1: Write failing tests:** `the Dive Computers list shows a hand-added computer item`, `tapping a computer opens its Equipment page`, `the Transmitters list shows an auto-created transmitter with No cylinder set up`, `saving the setup sheet configures every row of the item`, `/dive-computers/<id> lands on the item`, `/dive-computers/<id>/download still opens the download wizard`, `/transmitters/new lands on a new Transmitter item form`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** New ARB keys: "No cylinder set up", "Set up", "Add by hand", section titles.
- [ ] **Step 4: Run** `test/features/dive_computer`, `test/features/transmitters`, `test/features/equipment`, `test/core/router`, `test/architecture`, `test/shared`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(equipment): Dive Computers and Transmitters lists show Equipment items`.

---

### Task 12: Verify and after screenshots

- [ ] **Step 1:** `dart format .` then `flutter analyze` (no issues), then the full affected suites (`test/core/database`, `test/core/services/sync`, `test/features/{dive_computer,dive_log,equipment,transmitters,data_quality,import_wizard}`, `test/architecture`, `test/shared`), logging to the scratchpad and gating on zero `[E]` lines.
- [ ] **Step 2:** Launch with the `run` skill and capture the Task 0 screens again as `-after`, plus the Equipment page of an unregistered computer item and of an auto-created transmitter, light and dark for the two new sections, phone and desktop widths.
- [ ] **Step 3:** Send all screenshots in one SendUserFile call. No commit.
