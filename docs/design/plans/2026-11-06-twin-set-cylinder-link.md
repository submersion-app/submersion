# Twin Set Cylinder Link Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> to implement this plan task-by-task, inline in this session (the
> build-feature workflow forbids subagents for implementation). Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let two cylinders be linked as a dated twin set pairing, record one
fill for both, edit fills, and pick a linked cylinder for a dive as one Twin
Set tank (issue #4242).

**Architecture:** A new synced `cylinder_pairings` table holds dated pairings
(whole calendar days, at most one pairing per cylinder on any day). Twin fills
are two ordinary `cylinder_fills` rows tied by a shared `filled_together_id`,
written by a small data service so repository writes stay the agent-covered
`create` / `update` / `delete`. A dive tank gains `twin_passport_id`, read by
the passport usage query. The UI adds a Twin set card, a twin switch and edit
mode in the fill sheet, tied delete and edit in the fill history, and a "twin
set or just this one" prompt in the tank editor.

**Tech Stack:** Flutter, Riverpod, Drift (SQLite), the app's sync serializer
and change log, flutter_test.

**Spec:** `docs/design/specs/2026-11-06-twin-set-cylinder-link-design.md`

## Global Constraints

- Schema version goes 342 to **343**; one rung. New table and nullable
  columns only, so the compatibility floor does not move.
- Pairing days are calendar days stored as epoch milliseconds of **UTC
  midnight of that calendar date**, built only through `calendarDay()` (Task
  1). A pairing covers `pairedOn <= day < unpairedOn` (open when
  `unpairedOn` is null). Never compare a pairing day with a raw instant.
- Every unit shown uses `UnitFormatter` from the diver's settings.
- Every new string goes in `app_en.arb` and all ten other ARBs (ar, de, es,
  fr, he, hu, it, nl, pt, zh). Arabic plurals need `two`, `few`, `many`.
  Run `flutter test test/l10n` after ARB edits.
- No em-dash characters anywhere (code, comments, strings, docs, commits).
- Files stay under 800 lines; `before_open.dart` is at the limit, so the new
  backstop goes in `before_open_table_backstops.dart`.
- Before each commit: `dart format .`, `flutter analyze` (whole repo),
  the task's tests, and `flutter test test/architecture test/shared` when a
  file under `lib/` was added.
- Commits: `feat(cylinder-passports): ...` / `feat(equipment): ...` /
  `feat(dive-log): ...`; no tool attribution.

## Review Focus

1. **Swap day.** A fill or dive dated on the day A moved from C to B must use
   B; the day before must use C. Pinned in Task 1 (`pairingOn` tests) and
   Task 8 (switch follows the date).
2. **Two open pairings after a sync merge** (linked on two devices offline).
   Every read must pick one deterministically and no screen shows two
   partners. Pinned in Task 4 (`resolvePairings` test).
3. **Partner deleted or its fill already gone.** Tied edit and delete must
   not ask, and must not throw. Pinned in Task 6 and Task 9.
4. **Cubic feet.** Combining two cylinders' volumes in the tank editor must
   add liters, then convert, never add cuft fields. Pinned in Task 10.
5. **Partner without a passport id.** A twin fill mints it inside the same
   transaction. Pinned in Task 6.

---

## File Structure

Create:
- `lib/features/cylinder_passports/domain/entities/cylinder_pairing.dart`:
  entity, `calendarDay`, `coversDay`, `partnerOf`.
- `lib/features/cylinder_passports/domain/services/pairing_rules.dart`: pure
  clash detection and deterministic resolution.
- `lib/features/cylinder_passports/data/repositories/cylinder_pairing_repository.dart`
- `lib/features/cylinder_passports/data/services/twin_fill_service.dart`
- `lib/features/cylinder_passports/presentation/providers/cylinder_pairing_providers.dart`
- `lib/features/cylinder_passports/presentation/widgets/twin_set_card.dart`
- `lib/features/cylinder_passports/presentation/widgets/twin_set_link_flow.dart`
  (picker, replace confirm, date prompts, mismatch warning)
- `lib/features/cylinder_passports/presentation/widgets/tied_fill_dialogs.dart`
- `lib/features/dive_log/presentation/widgets/twin_set_choice_dialog.dart`
- `lib/features/agent_access/data/writes/families/cylinder_pairing_writes.dart`
- `lib/core/database/migrations/helpers/cylinder_pairing_migrations.dart`
- Tests beside each, plus `test/core/database/migration_v343_twin_set_test.dart`
  and `test/core/services/sync/cylinder_pairings_sync_round_trip_test.dart`.

Modify (main ones): `cylinder_tables.dart`, `dive_tables.dart`,
`database.dart`, `rungs_v340_onward.dart`, `before_open_table_backstops.dart`,
sync and change-log registration files (Task 3), `cylinder_fill.dart`,
`cylinder_fill_repository.dart`, `log_fill_sheet.dart`,
`passport_fill_history_card.dart`, `passport_current_fill_card.dart`,
`blender_procedure_card.dart`, `passport_page.dart`,
`equipment_detail_page.dart`, `equipment_repository_impl.dart`,
`dive_tank.dart`, `dive_repository_impl.dart`, `sequential_tank_merge.dart`,
`passport_usage_repository.dart`, `tank_editor.dart`, `tank_row.dart`,
`dive_edit_page.dart`, agent access records/documents/catalog, the ARBs.

---

### Task 1: Pairing domain and day rules

**Files:**
- Create: `lib/features/cylinder_passports/domain/entities/cylinder_pairing.dart`
- Create: `lib/features/cylinder_passports/domain/services/pairing_rules.dart`
- Test: `test/features/cylinder_passports/domain/cylinder_pairing_test.dart`,
  `test/features/cylinder_passports/domain/pairing_rules_test.dart`

**Interfaces (produces):**
- `DateTime calendarDay(DateTime any)` returns
  `DateTime.utc(any.year, any.month, any.day)`.
- `class CylinderPairing extends Equatable` with `id`, `cylinderAId`,
  `cylinderBId`, `pairedOn` (DateTime, UTC midnight), `unpairedOn`
  (DateTime?), `createdAt`, `updatedAt`, `copyWith`, and:
  - `bool get isOpen`
  - `bool involves(String equipmentId)`
  - `String partnerOf(String equipmentId)` (throws `ArgumentError` when not
    involved)
  - `bool coversDay(DateTime day)`: `!day.isBefore(pairedOn) &&
    (unpairedOn == null || day.isBefore(unpairedOn))`, with `day` passed
    through `calendarDay` first.
- `pairing_rules.dart`:
  - `List<CylinderPairing> resolvePairings(Iterable<CylinderPairing> all)`:
    the deterministic view of stored rows. Sort by `pairedOn` descending
    then `id` ascending; walk them and drop any row that overlaps a row
    already kept for either of its cylinders. Every read goes through this.
  - `CylinderPairing? pairingOn(Iterable<CylinderPairing> resolved, String
    equipmentId, DateTime day)`.
  - `CylinderPairing? currentPairing(Iterable<CylinderPairing> resolved,
    String equipmentId)`: the open one.
  - `List<CylinderPairing> clashesWith(Iterable<CylinderPairing> resolved,
    {required String cylinderAId, required String cylinderBId, required
    DateTime pairedOn, DateTime? unpairedOn, String? ignoreId})`: rows of
    either cylinder whose day range overlaps the candidate's.
  - `bool rangesOverlap(DateTime aStart, DateTime? aEnd, DateTime bStart,
    DateTime? bEnd)` (half-open ranges, null end = open).

- [ ] **Step 1: Write the failing tests**

```dart
test('a pairing covers its start day and not its end day', () {
  final p = pairing(on: DateTime.utc(2026, 3, 3), off: DateTime.utc(2026, 9, 14));
  expect(p.coversDay(DateTime(2026, 3, 3, 23, 59)), isTrue);
  expect(p.coversDay(DateTime(2026, 9, 13, 8)), isTrue);
  expect(p.coversDay(DateTime(2026, 9, 14, 0, 1)), isFalse);
  expect(p.coversDay(DateTime(2026, 3, 2, 23, 59)), isFalse);
});
test('on a swap day the new pairing counts', () {
  final old = pairing(id: 'p1', a: 'A', b: 'C', on: d(2026, 1, 1), off: d(2026, 9, 14));
  final now = pairing(id: 'p2', a: 'A', b: 'B', on: d(2026, 9, 14));
  final r = resolvePairings([old, now]);
  expect(pairingOn(r, 'A', DateTime(2026, 9, 14, 10))!.partnerOf('A'), 'B');
  expect(pairingOn(r, 'A', DateTime(2026, 9, 13, 10))!.partnerOf('A'), 'C');
  expect(pairingOn(r, 'C', DateTime(2026, 9, 14, 10)), isNull);
});
test('two open pairings from two devices resolve to one, the same everywhere', () {
  final x = pairing(id: 'b', a: 'A', b: 'B', on: d(2026, 11, 1));
  final y = pairing(id: 'a', a: 'A', b: 'C', on: d(2026, 11, 1));
  expect(resolvePairings([x, y]).map((p) => p.id), ['a']);
  expect(resolvePairings([y, x]).map((p) => p.id), ['a']);
});
test('clashesWith finds an overlap on either cylinder', () { ... B's open pairing with D clashes with a new A+B from today ... });
test('rangesOverlap treats the end day as outside', () {
  expect(rangesOverlap(d(2026,1,1), d(2026,2,1), d(2026,2,1), null), isFalse);
  expect(rangesOverlap(d(2026,1,1), null, d(2025,1,1), d(2026,1,2)), isTrue);
});
```

(`pairing(...)` and `d(...)` are local test helpers; `d` returns
`DateTime.utc`.)

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/cylinder_passports/domain/`
Expected: FAIL, the files do not exist.

- [ ] **Step 3: Implement the entity and rules** as in Interfaces.
- [ ] **Step 4: Run the tests**, expect PASS.
- [ ] **Step 5: Commit** `feat(cylinder-passports): pairing days and rules for twin sets`

---

### Task 2: Schema v343

**Files:**
- Modify: `lib/core/database/tables/cylinder_tables.dart` (new
  `CylinderPairings` table; `CylinderFills.filledTogetherId`)
- Modify: `lib/core/database/tables/dive_tables.dart`
  (`DiveTanks.twinPassportId` next to `passportId` at :351)
- Modify: `lib/core/database/database.dart` (tables list, version 343,
  `migrationVersions` entry with a floor comment)
- Create: `lib/core/database/migrations/helpers/cylinder_pairing_migrations.dart`
- Modify: `lib/core/database/migrations/ladder/rungs_v340_onward.dart`,
  `lib/core/database/migrations/before_open_table_backstops.dart`,
  `lib/core/database/migrations/app_database_migrations.dart` (part list)
- Test: `test/core/database/migration_v343_twin_set_test.dart`

**Interfaces (produces):**
- Drift table `CylinderPairings` (`@DataClassName('CylinderPairingRow')`,
  SQL `cylinder_pairings`): `id` text PK, `cylinderAId` and `cylinderBId`
  text FK `Equipment.id` **ON DELETE CASCADE**, `pairedOn` int,
  `unpairedOn` int nullable, `createdAt` int, `updatedAt` int, `hlc` text
  nullable. Indexes `idx_cylinder_pairings_a (cylinder_a_id)` and
  `idx_cylinder_pairings_b (cylinder_b_id)`. No diver id (a pairing belongs
  to the two cylinders, spec "Shared gear").
- `cylinder_fills.filled_together_id` text nullable, index
  `idx_cylinder_fills_together (filled_together_id)`.
- `dive_tanks.twin_passport_id` text nullable, index
  `idx_dive_tanks_twin_passport_id (twin_passport_id)`.
- Extension `CylinderPairingMigrations on AppDatabase` with
  `_assertTwinSetSchema()`: creates the table and indexes and adds the two
  columns with `_addColumnIfMissing`, skipping when a parent table is
  missing (as `_assertCylinderFillsSchema` does).

- [ ] **Step 1: Write the failing migration test**: open a v342 database
  (follow `migration_v341_dive_plan_series_test.dart`), migrate, and assert
  the table, three indexes and two columns exist; assert running
  `_assertTwinSetSchema` twice is harmless; assert deleting an equipment
  row deletes its pairing rows.
- [ ] **Step 2: Run** `flutter test test/core/database/migration_v343_twin_set_test.dart`, expect FAIL.
- [ ] **Step 3: Implement** the table, columns, helper, rung
  (`if (from < 343) await _assertTwinSetSchema(); if (from < 343) await reportProgress();`)
  with a `// v343:` comment naming issue #4242, the backstop call, and the
  version bump. Run `dart run build_runner build --delete-conflicting-outputs`
  in the background and wait for `database.g.dart` to change.
- [ ] **Step 4: Run** the migration test and `flutter test test/core/database`, expect PASS.
- [ ] **Step 5: Commit** `feat(cylinder-passports): schema for twin set pairings (v343)`

---

### Task 3: Register `cylinder_pairings` for sync, change log and deletion

Follow the checklist in
`docs/design/plans/2026-09-25-trip-gas-logistics-pr1-data-sync.md:1556-2032`
using `equipmentComponents` as the closest model (a link between two
equipment rows).

**Files (each site where `equipmentComponents` / `equipment_components`
appears):**
- `lib/core/data/repositories/sync_repository.dart` `hlcTargets`
  (entity type `cylinderPairings`)
- `lib/core/services/sync/sync_data_serializer.dart`: field, constructor,
  `toJson`, `fromJson`, `_baseTables`, `_safeExport`, `fetchRecord`,
  `fetchRecords`, `upsertRecord`, `upsertRecords`, `recordIdsFor`,
  `_syncTableFor`, `deleteRecord`, `_exportCylinderPairings`
- `lib/core/services/sync/sync_service.dart`: `mergeOrder` (after
  `equipment`), `entityHasUpdatedAt`, `parentRefs`
  (`cylinderAId` and `cylinderBId` to `equipment`)
- `lib/core/services/sync/conflict_reference.dart` `_defaultTargets`
  (`cylinderAId`, `cylinderBId` to `equipment`)
- `lib/core/database/change_log/change_log_policy.dart`: `changeLogTables`
  (`tracked`) and `changeLogParents` (both cylinder columns to
  `equipment`)
- `lib/features/divers/data/repositories/diver_owned_rows.dart` and
  `diver_delete_steps.dart`: rows go with their cylinders (as
  `equipment_components` do)
- `lib/features/equipment/data/repositories/equipment_repository_impl.dart`
  `deleteEquipment` (:735): tombstone the item's pairings before the delete,
  as it does component rows (:771-779), because a cascade writes no
  tombstones.
- Test: `test/core/services/sync/cylinder_pairings_sync_round_trip_test.dart`
  (model on `equipment_component_sync_test.dart`)

- [ ] **Step 1: Write the failing round-trip test**: a pairing exported on
  one database is upserted on another with the same fields; a deleted
  pairing's tombstone removes it on the peer; deleting a cylinder logs a
  tombstone for its pairing.
- [ ] **Step 2: Run it and the sync guards**:
  `flutter test test/core/services/sync/ test/core/database/change_log/`,
  expect the new test and the registration guards to FAIL.
- [ ] **Step 3: Register** at every site above.
- [ ] **Step 4: Run** the same command, expect PASS.
- [ ] **Step 5: Commit** `feat(cylinder-passports): sync twin set pairings`

---

### Task 4: Pairing repository and providers

**Files:**
- Create: `lib/features/cylinder_passports/data/repositories/cylinder_pairing_repository.dart`
- Create: `lib/features/cylinder_passports/presentation/providers/cylinder_pairing_providers.dart`
- Test: `test/features/cylinder_passports/data/cylinder_pairing_repository_test.dart`

**Interfaces (produces):**
- `class PairingClash implements Exception { final List<CylinderPairing> clashes; }`
- `class CylinderPairingRepository` (sync like `CylinderFillRepository`:
  `markRecordPending` on writes, `logDeletion` on deletes,
  `SyncEventBus.notifyLocalChange()`), entity `'cylinderPairings'`:
  - `Stream<void> watchChanges()`
  - `Future<List<CylinderPairing>> getForCylinder(String equipmentId)`:
    resolved rows involving it, newest first.
  - `Future<List<CylinderPairing>> getAll()`
  - `Future<CylinderPairing?> pairingOn(String equipmentId, DateTime day)`
  - `Future<CylinderPairing> createPairing({required String cylinderAId,
    required String cylinderBId, required DateTime pairedOn, bool
    replace = false})`: in one transaction, reads both cylinders' resolved
    pairings and computes `clashesWith`. With `replace` false and any
    clash, throws `PairingClash`. With `replace` true, each clash that is
    open and started before `pairedOn` is ended on `pairedOn`; any other
    clash still throws `PairingClash`. Refuses `cylinderAId ==
    cylinderBId` with `ArgumentError`.
  - `Future<void> endPairing(String id, DateTime unpairedOn)`: refuses an
    end on or before `pairedOn` with `ArgumentError`, and an end that
    overlaps a later pairing of either cylinder with `PairingClash`.
  - `Future<void> deletePairing(String id)`
- Providers: `cylinderPairingRepositoryProvider`,
  `pairingsForCylinderProvider` (family by equipment id, refreshed by
  `watchChanges`), `pairingOnProvider` (family by `(equipmentId, day)`
  record), `currentPairingProvider` (family by equipment id).

- [ ] **Step 1: Write the failing tests** against a test database:
  create, read from both sides; `createPairing` with A already open with C
  throws `PairingClash` naming that pairing; with `replace: true` the C
  pairing ends on the new start day and the new one is open; a backdated
  start that lands inside a closed pairing throws even with `replace`;
  `endPairing` before the start throws; `deletePairing` logs a tombstone;
  `pairingOn` on a swap day returns the new pairing.
- [ ] **Step 2: Run** `flutter test test/features/cylinder_passports/data/cylinder_pairing_repository_test.dart`, expect FAIL.
- [ ] **Step 3: Implement** the repository and providers.
- [ ] **Step 4: Run**, expect PASS.
- [ ] **Step 5: Commit** `feat(cylinder-passports): twin set pairing repository`

---

### Task 5: Agent access for pairings and the new columns

Required by `test/architecture/agent_write_coverage_test.dart` (every
repository write reachable by an agent, the baseline must stay empty).

**Files:**
- Create: `lib/features/agent_access/data/writes/families/cylinder_pairing_writes.dart`
  (model on `equipment_component_writes.dart`): name and table
  `cylinder_pairings`; fields `cylinder_a_id`, `cylinder_b_id` (references
  `equipment`), `paired_on`, `unpaired_on` (dates); create calls
  `createPairing` (refusing with `BlockReason.invalidValue` naming the
  clash instead of throwing), an update that sets `unpaired_on` calls
  `endPairing`, delete calls `deletePairing`. Changing either cylinder
  after create is refused.
- Modify: `write_catalog.dart`, `record_repositories.dart`
  (`cylinderPairings`), `records/families/gear_records.dart` (a record
  entity scoped via either cylinder's equipment scope),
  `documents/gear_documents.dart` (`cylinderPairingDocument`; the fill
  document gains `filled_together_id`), and the dive tank document gains
  `twin_passport_id` where `passport_id` is documented.
- Modify: `test/architecture/agent_write_coverage_covered.dart`
  (`createPairing`, `endPairing`, `deletePairing` to `cylinder_pairings`).
- Regenerate `sql_column_notes.generated.dart` with the script named in its
  header.
- Test: `test/features/agent_access/data/writes/cylinder_pairing_writes_test.dart`

- [ ] **Step 1: Write the failing test**: an agent change set creates a
  pairing, ends it, and deletes it; a clashing create is blocked with a
  reason naming the existing partner.
- [ ] **Step 2: Run** it plus `flutter test test/architecture/agent_write_coverage_test.dart`, expect FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** both plus `flutter test test/features/agent_access`, expect PASS.
- [ ] **Step 5: Commit** `feat(agent-access): read and write twin set pairings`

---

### Task 6: Tied fills

**Files:**
- Modify: `lib/features/cylinder_passports/domain/entities/cylinder_fill.dart`
  (`filledTogetherId` field, `copyWith` with `clearFilledTogetherId`, props)
- Modify: `lib/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart`
  (map the column; add read `Future<CylinderFill?> tiedFillOf(CylinderFill fill)`:
  the other row with the same `filledTogetherId`, null when none)
- Create: `lib/features/cylinder_passports/data/services/twin_fill_service.dart`
- Test: `test/features/cylinder_passports/data/twin_fill_service_test.dart`

**Interfaces (produces):**
- `class TwinFillPartner { final String equipmentId; }`
- `class TwinFillService` (constructor takes optional
  `CylinderFillRepository` and `CylinderPassportRepository`):
  - `Future<({CylinderFill fill, CylinderFill partnerFill})> recordTwinFill(CylinderFill fill, {required String partnerEquipmentId})`:
    in one `_db.transaction`, `ensurePassportId(partnerEquipmentId,
    diverId: fill.diverId)`, mints one group id (`uuid.v4()`), creates
    `fill.copyWith(filledTogetherId: group)` and a partner copy with a new
    id, the partner's passport id and equipment id, every other field the
    same. Both go through `CylinderFillRepository.create`.
  - `Future<void> applyEdit(CylinderFill edited, {required bool toTied})`:
    updates `edited`; with `toTied`, copies `filledAt`, `o2Percent`,
    `hePercent`, `pressureBar`, `temperatureC`, `analyzer`,
    `stationName`, `notes` onto `tiedFillOf(edited)` when it exists.
  - `Future<void> delete(CylinderFill fill, {required bool tiedToo})`.
- `bool isEditableFill(CylinderFill f, {required Set<String> tripCopyIds})`:
  `f.source == FillSource.manual && !f.isSigned && !tripCopyIds.contains(f.id)`.
- Provider `tripCopyFillIdsProvider` (family by equipment id): the
  `tripFillPassportCopyId(event.id)` of every fill event on trip cylinders
  whose `equipmentId` is this cylinder (read through the trips
  repository).

- [ ] **Step 1: Write the failing tests**: `recordTwinFill` writes two rows
  with one shared group id, same gas, pressure, date, station, notes, each
  under its own passport and equipment id; a partner with no passport id
  gets one, and its fill is under it; `applyEdit(toTied: true)` changes
  both, `false` only one; `applyEdit` with the tied row already deleted
  updates one and does not throw; `delete(tiedToo: true)` removes both and
  logs two tombstones; `isEditableFill` is false for a signed fill, an
  `nfc` fill and a trip copy id.
- [ ] **Step 2: Run** `flutter test test/features/cylinder_passports/data/`, expect FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the same plus `test/core/services/sync/cylinder_fills_sync_round_trip_test.dart`, expect PASS.
- [ ] **Step 5: Commit** `feat(cylinder-passports): tie the two fills of a twin fill`

---

### Task 7: Twin set card and link flow

**Files:**
- Create: `twin_set_card.dart`, `twin_set_link_flow.dart` (both under
  `lib/features/cylinder_passports/presentation/widgets/`)
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page.dart`
  (show `TwinSetCard(equipmentId:)` for tanks right after
  `PassportEntryCard`, :246-249)
- Modify: `lib/features/cylinder_passports/presentation/pages/passport_page.dart`
  (a "Twin set with <partner>" line under the header when a pairing is
  current; tapping opens the partner's equipment page)
- Modify: ARBs
- Test: `test/features/cylinder_passports/presentation/widgets/twin_set_card_test.dart`,
  `twin_set_link_flow_test.dart`

**Behaviour (from the spec):**
- Card title "Twin set". No current pairing: "Not part of a twin set" and a
  "Link to a twin set partner" button. Current pairing: partner name
  (tappable to `/equipment/<id>`), "Since <date>", the partner's status
  when it is not active or spare, and buttons "Replace partner" and
  "Unlink". Below, "History": closed pairings, newest first, "<partner>,
  <from> to <to>", each with a delete action (confirm "Delete this pairing
  from the history? Fills and dives are not changed.").
- Link and Replace: pick a cylinder (`EquipmentType.tank`, not this one,
  status not retired, sold or lost; owned or shared with the active diver,
  through the existing visibility query), then a date (default today,
  `showAppDatePicker`, last date today), then:
  - when the two working pressures differ, a warning dialog ("<A> is rated
    232 bar and <B> 300 bar. A manifolded pair fills to one pressure.")
    with Continue / Cancel;
  - when `createPairing` throws `PairingClash` with open clashes that
    started before the date, the replace confirm naming each pairing that
    ends ("<B> is paired with <C>. Pair it with <A> instead? <C> will be
    left on its own."), then `createPairing(replace: true)`;
  - any other clash: a dialog naming it and nothing saved.
- Unlink: date prompt (default today, not before the start day), then
  `endPairing`.

- [ ] **Step 1: Write the failing widget tests** (repository faked through
  provider overrides): unlinked card shows the link button; linked card
  shows partner, since-date, Replace and Unlink; a sold partner shows
  "Sold"; history lists closed pairings newest first; link flow with a
  partner already paired shows the replace text naming both and calls
  `createPairing(replace: true)` on confirm; differing working pressures
  show the warning in the diver's pressure unit (psi case included); the
  picker leaves out this cylinder and a retired one but offers a spare.
- [ ] **Step 2: Run** them, expect FAIL.
- [ ] **Step 3: Implement** card, flow, page wiring, ARB strings.
- [ ] **Step 4: Run** them plus `test/features/equipment/presentation/pages/` and `test/features/cylinder_passports/presentation/pages/`, expect PASS.
- [ ] **Step 5: Commit** `feat(equipment): twin set card to link, swap and unlink cylinders`

---

### Task 8: Fill sheet: twin switch, warnings, edit mode, tag offers

**Files:**
- Modify: `lib/features/cylinder_passports/presentation/widgets/log_fill_sheet.dart`
- Modify: `passport_current_fill_card.dart`,
  `lib/features/gas_calculators/presentation/widgets/blender/blender_procedure_card.dart`,
  `lib/features/cylinder_passports/presentation/utils/write_fill_to_tag.dart`
- Modify: ARBs
- Test: `test/features/cylinder_passports/presentation/widgets/log_fill_sheet_test.dart`
  (extend), `passport_current_fill_card_test.dart` (extend)

**Interfaces:**
- `class LoggedFill { final CylinderFill fill; final CylinderFill? partnerFill; }`
- `showLogFillSheet(...)` returns `Future<LoggedFill?>` and gains
  `CylinderFill? editing`. `LogFillSheet` gains `final CylinderFill? editing`.
- `Future<void> offerWriteFillsToTags(BuildContext, WidgetRef, LoggedFill
  logged, {required String equipmentId})`: calls `offerWriteFillToTag` for
  this cylinder, then for the partner (`partnerFill.equipmentId`) when
  present. Both callers use it.

**Behaviour:**
- New fill on a cylinder with `pairingOn(equipmentId, _filledAt)`: a
  `SwitchListTile` keyed `log-fill-twin` "Both cylinders in the twin set
  (<partner>)", re-read whenever the date changes, hidden when there is no
  pairing that day. Default on, except when the partner's status is
  retired, sold, lost, loaned out or in service: default off and the label
  reads "<partner>, <status>".
- On save with the switch on: if the pressure is above either cylinder's
  working pressure, a warning dialog ("<pressure> is above <name>'s working
  pressure of <wp>.") with Save anyway / Back; then
  `TwinFillService.recordTwinFill`. Switch off or no pairing: today's
  single `create`.
- Edit mode (`editing != null`): title "Edit fill", fields prefilled from
  the fill in the diver's units, no switch. On save, when
  `tiedFillOf(editing)` exists, ask "Apply to <partner>'s fill too?" with
  Yes (default, filled button) / Only this one, then
  `TwinFillService.applyEdit`. Pops `LoggedFill(fill: edited)`.

- [ ] **Step 1: Write the failing tests**: switch shown and on with a
  pairing; hidden without; changing the date to before a swap shows the old
  partner's name; partner sold gives switch off and "<name>, Sold"; save
  with switch on calls `recordTwinFill` with the partner id; save with
  switch off calls `create` once; pressure above the partner's working
  pressure warns (psi settings case) and Back does not save; edit mode
  prefills, shows "Edit fill", hides the switch, and the apply-to-partner
  answer reaches `applyEdit(toTied:)`; the current fill card offers both
  tags after a twin fill (fake the offer function).
- [ ] **Step 2: Run** them, expect FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** them plus `test/features/gas_calculators`, expect PASS.
- [ ] **Step 5: Commit** `feat(cylinder-passports): log one fill for both cylinders of a twin set, and edit fills`

---

### Task 9: Fill history: filled with, edit, tied delete

**Files:**
- Modify: `lib/features/cylinder_passports/presentation/widgets/passport_fill_history_card.dart`
- Create: `lib/features/cylinder_passports/presentation/widgets/tied_fill_dialogs.dart`
- Modify: ARBs
- Test: `test/features/cylinder_passports/presentation/widgets/passport_fill_history_card_test.dart`

**Behaviour:**
- A tied fill's subtitle adds "Filled with <partner name>" (the tied row's
  equipment name; "another cylinder" when its equipment row is gone).
- Tapping an editable fill (`isEditableFill`) opens
  `showLogFillSheet(editing: fill)`. Other fills are not tappable.
- Delete of a tied fill whose tied row exists asks "Delete from both
  cylinders, or only this one?" with "Both cylinders" (filled, default) /
  "Only this one" / Cancel, then `TwinFillService.delete(tiedToo:)`.
  Otherwise the existing confirm.

- [ ] **Step 1: Write the failing tests**: tied fill shows "Filled with
  Double 12 B"; a signed fill and a trip copy are not tappable, a manual one
  opens the sheet in edit mode; tied delete offers both choices and each
  reaches `delete(tiedToo:)` with the right value; tied delete with the
  other row gone shows the plain confirm.
- [ ] **Step 2: Run**, expect FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** plus `test/features/cylinder_passports/presentation/pages/`, expect PASS.
- [ ] **Step 5: Commit** `feat(cylinder-passports): edit fills and keep twin fills together in the history`

---

### Task 10: Dives: twin set or just this cylinder

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive_tank.dart`
  (`twinPassportId`, copyWith with `clearTwinPassportId`, props)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart`
  (every `passportId: Value(tank.passportId)` and `passportId:
  t.passportId` site, :2317, :2658, :2696, :4987, :5449, gains the twin
  field), `lib/features/dive_log/domain/services/sequential_tank_merge.dart`
  (:181, same rule as `passportId`)
- Modify: `lib/features/cylinder_passports/data/repositories/passport_usage_repository.dart`
  (`WHERE d.id IN (SELECT t.dive_id FROM dive_tanks t WHERE t.passport_id = ?
  UNION SELECT t.dive_id FROM dive_tanks t WHERE t.twin_passport_id = ?)`)
- Create: `lib/features/dive_log/presentation/widgets/twin_set_choice_dialog.dart`
- Modify: `tank_editor.dart`, `edit_sections/tank_row.dart`,
  `dive_edit_page.dart`; ARBs
- Test: `test/features/dive_log/presentation/widgets/tank_editor_twin_set_test.dart`,
  `test/features/cylinder_passports/data/passport_usage_repository_test.dart`
  (extend), `test/features/dive_log/data/` round trip for the new field

**Interfaces:**
- `TankEditor` gains `final DateTime? diveDate` (the dive page passes
  `_entryDate`; null means today) and `onOwnCylinderUsed` keeps its
  signature; the twin path calls it once per cylinder.
- `enum TwinSetChoice { twinSet, single }`;
  `Future<TwinSetChoice?> showTwinSetChoiceDialog(BuildContext, {required
  String pickedName, required String partnerName, required String
  combinedVolume, String? partnerStatus})`: title "Use the twin set?",
  options "Twin set (<A> + <B>, <volume>)" and "Just <A>", partner status
  line when not active or spare. Null (dismissed) cancels the pick.

**Behaviour:** In `_useOwnCylinder`, when `pairingOn(item.id,
diveDate ?? now)` exists, load the partner item and ask. Twin set:
`_applyScannedSpec` with volume `item.volumeL + partner.volumeL` (liters,
then the existing cuft conversion), working pressure the lower of the two
(either alone when one is null), material and mix from the picked
cylinder; set `_role = TankRole.twinSet`; set `_twinPassportId` to the
partner's passport id (`ensurePassportId`); call `onOwnCylinderUsed` for
the item and the partner. Single, or no pairing: today's path and
`_twinPassportId = null`. `_currentTank()` writes `twinPassportId`.

- [ ] **Step 1: Write the failing tests**: picking a linked cylinder shows
  the dialog with "Twin set (Double 12 A + Double 12 B, 24 L)"; Twin set
  gives role twinSet, volume 24 L, working pressure the lower, both items
  passed to `onOwnCylinderUsed`, and `twinPassportId` set; with cuft
  settings the volume field shows the pair's gas capacity, not a sum of two
  cuft figures; Just A keeps today's result and no twin id; a dive dated
  before the pairing started shows no dialog; usage query counts a dive
  for the partner through `twin_passport_id`; the field survives a dive
  save and reload.
- [ ] **Step 2: Run** them, expect FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** them plus `flutter test test/features/dive_log/presentation/widgets/ test/features/dive_log/data/`, expect PASS.
- [ ] **Step 5: Commit** `feat(dive-log): use a twin set from a linked cylinder on a dive`

---

### Task 11: Whole-branch checks, after screenshots, cleanup

- [ ] **Step 1:** `flutter test test/l10n test/architecture test/shared test/core/database test/core/services/sync`, expect PASS.
- [ ] **Step 2:** Extend `test/tmp_shots/` with after shots: tank detail with
  the Twin set card (linked, with history), passport page header line, fill
  sheet with the switch, fill sheet in edit mode, tied delete dialog, fill
  history with "Filled with", the replace confirm, the tank editor choice
  dialog; light and dark for the card and the sheet. Copy the PNGs to the
  scratchpad.
- [ ] **Step 3:** Delete `test/tmp_shots/` and confirm `git status` shows no
  goldens.
- [ ] **Step 4:** `dart format .` and `flutter analyze`, expect no issues.
