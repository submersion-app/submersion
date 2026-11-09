# Transmitter Slot Matching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in one session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Record the physical Shearwater transmitter slot on every tank that
knows it, and let "Apply to existing dives" fill file-imported tanks that have
no serial by computer, slot and date (issue #4347).

**Architecture:** A fork patch makes libdivecomputer report the slot; it rides
the existing transmitter-serial path through the Pigeon bridge into a new
synced, computer-owned `dive_tanks.transmitter_slot` column. Shearwater Cloud
UDDF and `.db` imports fill the same column, and a backfill fills it for dives
already stored. A pure slot timeline resolves which serial held a slot on a
date; the Apply dialog previews serial and slot matches separately and passes
the exact slot tank ids it showed to the write.

**Tech Stack:** C (libdivecomputer fork), Pigeon 22, Kotlin/JNI, Swift, C/C++
(Linux, Windows), Flutter/Dart, Drift, Riverpod.

**Spec:** `docs/design/specs/2026-11-09-transmitter-slot-matching-design.md`

## Global Constraints

- Slot values in Dart and in `dive_tanks.transmitter_slot`: 0 based, T1 = 0 to
  T4 = 3, null for unknown. In C (`dc_tank_t`, `libdc_tank_t`, JNI): slot + 1,
  0 = unknown, so a zero-initialised struct means unknown.
- Shearwater parser indices 4 and 5 (HP CCR sensors) report unknown.
- Schema: `currentSchemaVersion` 347 to 348; `minimumCompatibleSchemaVersion`
  does not move. No rung or table code in `database.dart` beyond the
  `migrationVersions` entry.
- `transmitter_slot` is computer-owned: the tank editor and `updateDive`'s
  existing-row branch never write it; every copy or edit preserves it.
- Apply never writes a serial. Fill-only rules and role rules are unchanged.
- The snackbar Apply in `transmitter_edit_page.dart` and the agent-access write
  stay serial/channel only (no slot matches without the confirming dialog).
- New user-visible strings go in every ARB under `lib/l10n/arb/`; dates use the
  app's locale-aware date formatting.
- No em-dashes anywhere. No file over 800 lines. `dart format .` before each
  commit. Any new `lib/` file: run `test/architecture/` and `test/shared/`.
- Fork commits go on a branch of the fork; pushing the fork needs the user's
  explicit OK (separate repository).

## Review Focus

1. A file-imported dive dated exactly at a download that observed the slot
   resolves to that download's serial. One earlier the same day, after a
   download showing another serial, counts as "changed hands": the swap could
   have been that morning (tests in Task 8).
2. A Shearwater Cloud dive whose stored tank count no longer equals the file's
   (a tank deleted or added by hand): the backfill skips the dive and writes
   nothing (test in Task 10).
3. One transmitter paired to two Shearwater computers: each computer has its
   own timeline; a slot on one never resolves a dive on the other (test in
   Task 9).
4. Opening the dialog twice: the second open parses nothing again (memo test
   in Task 10).
5. A file-imported tank with a slot on a computer with no Bluetooth
   observations (HP CCR, or a computer never downloaded): no candidate, no
   crash, counted nowhere (test in Task 9).

---

### Task 1: Fork patch: report the physical slot

**Files:**
- Modify (submodule `packages/libdivecomputer_plugin/third_party/libdivecomputer`, new branch `transmitter-slot` off `submersion-patches`):
  `include/libdivecomputer/parser.h` (dc_tank_t, after `serial`),
  `src/parser.c` (beside the `serial` reset in `dc_parser_get_field`),
  `src/shearwater_predator_parser.c` (`shearwater_predator_tank_t` :130-140,
  reset loop :272-283, compaction :746-755, DC_FIELD_TANK :822),
  `doc/man/dc_parser_get_field.3`
- Modify: `packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h:290-298` (`libdc_tank_t`), `packages/libdivecomputer_plugin/macos/Classes/libdc_download.c:628`
- Create: `packages/libdivecomputer_plugin/patches/0010-tank-transmitter-slot.patch`
- Test: `packages/libdivecomputer_plugin/test/native/test_tank_transmitter_serial.c`

**Interfaces:**
- Produces: `dc_tank_t.slot` and `libdc_tank_t.slot` (`unsigned int`, slot + 1, 0 unknown).

- [ ] **Step 1: Extend the native test.** In `test_tank_transmitter_serial.c`, for the Petrel 3 fixture assert each active tank's `slot` is non-zero and that the tank with serial 123086 and the one with 109623 report distinct slots in 1..4; assert slots past `tank_count` read 0.
- [ ] **Step 2: Run** `cmake -B build/test test/native && cmake --build build/test && ctest --test-dir build/test --output-on-failure` from `packages/libdivecomputer_plugin`. Expected: compile error, no member `slot`.
- [ ] **Step 3: Implement.** Add `unsigned int slot;` to `dc_tank_t` with a "Submersion patch (tank transmitter slot)" comment; reset it to 0 in `parser.c` next to `serial`; add `slot` to `shearwater_predator_tank_t`, reset to 0 in the :272 loop, set `parser->tank[n].slot = i < 4 ? i + 1 : 0` during compaction; copy it in DC_FIELD_TANK. Add `unsigned int slot;` to `libdc_tank_t` and copy `tk.slot` in `extract_dive_fields`.
- [ ] **Step 4: Run** the ctest command. Expected: PASS. Pin the exact slot values the fixture yields in the test.
- [ ] **Step 5: Commit the fork** on branch `transmitter-slot` ("Report the physical transmitter slot on each tank"); write `git diff <base> HEAD > ../../patches/0010-tank-transmitter-slot.patch`; bump the submodule pointer. Ask the user before pushing the fork branch and opening its PR.
- [ ] **Step 6: Commit** the app side: `feat(dive-computer): report the transmitter slot from libdivecomputer`.

### Task 2: Plugin bridge to Dart

**Files:**
- Modify: `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart:163-188` (TankInfo), then regenerate.
- Modify: `linux/dive_converter.c:184-208`, `windows/dive_converter.cc:193-222`, `android/src/main/cpp/libdc_jni.cpp:1225-1245` (array 7 to 8, index 7 = slot), `android/.../DiveComputerHostApiImpl.kt:732`, `android/.../SerialDownloadRunner.kt:210`, `darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift:906` (all under `packages/libdivecomputer_plugin`).
- Test: `packages/libdivecomputer_plugin/test/native/test_dive_converter.c:183-196`

**Interfaces:**
- Produces: `pigeon.TankInfo.transmitterSlot` (`int?`, 0 based; native 0 maps to null, n to n - 1).

- [ ] **Step 1:** Add `final int? transmitterSlot;` (trailing, nullable, documented) to TankInfo.
- [ ] **Step 2:** Run `dart run pigeon --input pigeons/dive_computer_api.dart` in `packages/libdivecomputer_plugin`. Expected: all six generated outputs change.
- [ ] **Step 3:** Extend `test_tank_fields` in `test_dive_converter.c` to assert the Linux converter maps slot 0 to null and 3 to 2; run ctest, expect FAIL.
- [ ] **Step 4:** Update every converter (the same `x == 0 ? null : x - 1` rule) and the JNI array. Run ctest, expect PASS; run `flutter analyze packages/libdivecomputer_plugin`.
- [ ] **Step 5: Commit** `feat(dive-computer): carry the transmitter slot through the plugin bridge`.

### Task 3: Schema v348 column

**Files:**
- Modify: `lib/core/database/tables/dive_tables.dart` (after `sourceTankIndex` :294, with a `//` comment), `lib/core/database/database.dart:318` and `migrationVersions` (entry 348), `lib/core/database/migrations/ladder/rungs_v340_onward.dart` (after v347), `lib/core/database/migrations/before_open_child_columns.dart`
- Create: `lib/core/database/migrations/helpers/tank_transmitter_slot_migrations.dart` (part file, `_assertTankTransmitterSlotColumn()` via `_addColumnIfMissing('dive_tanks', 'transmitter_slot', 'INTEGER')`, plus `assertTankTransmitterSlotColumnForTest()`); register it as a `part` beside `cylinder_pairing_migrations.dart`.
- Modify: `lib/features/settings/presentation/conflicts/catalogue/dive_log_fields.dart:567-570` (`'transmitterSlot'`, `FieldKind.number`), every `lib/l10n/arb/app_*.arb` (`settings_conflict_field_transmitterSlot`, en "Transmitter slot")
- Regenerate: build_runner, `flutter gen-l10n`, `dart run tool/generate_sql_column_notes.dart`
- Test: create `test/core/database/migration_v348_tank_transmitter_slot_test.dart` (template `migration_v345_twin_set_test.dart`)

- [ ] **Step 1:** Write the migration test: `currentSchemaVersion >= 348`, `migrationVersions` contains 348, `minimumCompatibleSchemaVersion` is not 348, upgrade from a `user_version = 347` fixture leaves `columnsOf(db, 'dive_tanks')` containing `transmitter_slot`, and the beforeOpen backstop re-adds a dropped column.
- [ ] **Step 2:** Run it. Expected: FAIL.
- [ ] **Step 3:** Implement the column, rung (`if (from < 348) await _assertTankTransmitterSlotColumn();` plus `reportProgress`), backstop, catalogue entry and ARB keys; regenerate.
- [ ] **Step 4:** Run the new test, `test/core/database/`, `test/features/settings/presentation/conflicts/conflict_field_catalogue_coverage_test.dart`, `test/features/agent_access/data/resources/schema_resource_test.dart`, `test/core/services/sync/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-log): add the dive_tanks transmitter_slot column`.

### Task 4: DiveTank carries the slot everywhere

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive_tank.dart` (field, constructor, `copyWith` with `clearTransmitterSlot`, props)
- Modify: `dive_repository_impl.dart` (createDive :2428, updateDive new-row insert :2809, row mappers :5129 and :5592, `_tankCompanion` :8502 mirroring `sourceTankIndex`; NOT the existing-row update :2733-2770), `tank_role_repair_repository.dart:132-142`, `tank_pressure_repository.dart:354-372` (swap the slot with the bundle), `sequential_tank_merge.dart:182` (`earlier ?? later`), `tank_editor.dart:471-477`, `plan_tank_list.dart:762-764`, `planned_dive_fill_service.dart:206,211-229` (beside the serial)
- Test: `test/features/dive_log/data/repositories/dive_repository_source_tank_index_test.dart` (add cases), `tank_pressure_repository_exchange_test.dart`, the sequential merge test, the tank editor test

**Interfaces:**
- Produces: `DiveTank.transmitterSlot` (`int?`), `copyWith({int? transmitterSlot, bool clearTransmitterSlot = false})`.

- [ ] **Step 1:** Tests: `createDive` then read returns `transmitterSlot: 2`; `updateDive` that edits volume keeps a stored slot of 2 even when the edited entity passes null; `exchangeTankSources` swaps slots 0 and 1; the sequential fold keeps the earlier non-null slot; saving the tank editor keeps the slot.
- [ ] **Step 2:** Run them. Expected: FAIL (no such field).
- [ ] **Step 3:** Implement at each site listed.
- [ ] **Step 4:** Run the tests plus `test/features/dive_log/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-log): carry the transmitter slot on every tank copy`.

### Task 5: Downloads and re-parse write the slot

**Files:**
- Modify: `lib/features/dive_computer/domain/entities/downloaded_dive.dart:397-448` (DownloadedTank), `parsed_tank_resolver.dart:226-250`, `dive_parser.dart:74-86` (`tankDataFrom`), `dive_computer_repository_impl.dart` (`TankData` :3108-3200, insert :2044-2049), `reparse_service.dart` (`_carryOverTanks` update :1076-1095 writes it unconditionally like the serial; insert :1101-1126)
- Test: `test/features/dive_computer/data/services/parsed_tank_resolver_test.dart`, `reparse_service_test.dart`

**Interfaces:**
- Consumes: `pigeon.TankInfo.transmitterSlot` (Task 2), `DiveTank.transmitterSlot` (Task 4).
- Produces: `DownloadedTank.transmitterSlot`, `TankData.transmitterSlot` (`int?`).

- [ ] **Step 1:** Tests: the resolver copies `TankInfo(transmitterSlot: 1)` onto its DownloadedTank and gives sensorless gas cylinders null; a re-parse of a dive whose stored tank has slot null writes the parsed slot onto the existing row.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement along the serial's path.
- [ ] **Step 4:** Run the tests plus `test/features/dive_computer/` and `test/architecture/child_write_restamps_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-computer): store the transmitter slot on downloaded tanks`.

### Task 6: UDDF import and export

**Files:**
- Create: `lib/core/services/export/uddf/uddf_transmitter_slot.dart` with `int? shearwaterSlotFromRef(String? ref)` (`^T([1-4])$` after trim, case-insensitive, returns n - 1).
- Modify: `uddf_full_import_service.dart` (after a waypoint ref resolves through the fallback map at :2604-2616, set `tanks[tankIdx]['transmitterSlot'] ??= slot` when that tank has no `uddfTankId`; read `<transmitterslot>` beside `<transmitterserial>` :2394-2401), `uddf_export_builders.dart:2035-2043` (write `<transmitterslot>` when non-null), `lib/features/dive_import/data/services/uddf_entity_importer.dart:3702` (`transmitterSlot: t['transmitterSlot'] as int?`), `dive_reimport_service.dart:478-518` (write the slot on matched and new rows when the map has one; absent otherwise)
- Test: create `test/core/services/export/uddf/uddf_transmitter_slot_test.dart`

- [ ] **Step 1:** Tests: `shearwaterSlotFromRef('T1') == 0`, `('t4') == 3`, `('T5')`, `('tank_1')`, `(null)` are null; importing `test/dives/006_ccr_petrel3_shearwater-cloud-export.uddf` gives tanks with slots `[0, 1]`; a file whose `<tankdata>` carry ids gives null slots; export then import of a tank with slot 2 keeps 2; a resync of a dive with a stored slot-less tank writes the slot.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the new test and `test/core/services/export/uddf/`, `test/features/dive_import/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(import): keep the Shearwater transmitter slot from UDDF refs`.

### Task 7: Shearwater Cloud `.db` import

**Files:**
- Modify: `lib/features/universal_import/data/services/shearwater_dive_mapper.dart` (`mapTanks` :187-219 emits `transmitterSlot` from `DiveTransmitter.TankIndex` when 0..3, else from `Name` via `shearwaterSlotFromRef`; `mergeWithParsedDive` :472, before the gas-switch step, copies onto each mapped tank the normalised non-zero serial of the parsed tank with the same `transmitterSlot`)
- Confirm the `.db` import's tanks reach `UddfEntityImporter._buildTanks` (Task 6 maps the key); if another builder is used, map it there.
- Test: `test/features/universal_import/data/services/shearwater_dive_mapper_metadata_test.dart`

- [ ] **Step 1:** Tests: `DiveTransmitter {'TankIndex': 1, 'Name': 'T2'}` gives slot 1; no TankIndex, `Name: 'T3'` gives 2; merging a ParsedDive whose tank has `transmitterSlot: 1, transmitterSerial: 109623` sets that serial on the slot-1 tank only; a parsed tank with no matching slot sets nothing.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the test and `test/features/universal_import/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(import): read transmitter slot and serial from Shearwater Cloud databases`.

### Task 8: Slot timeline (pure)

**Files:**
- Create: `lib/features/transmitters/domain/services/transmitter_slot_timeline.dart`
- Test: create `test/features/transmitters/domain/services/transmitter_slot_timeline_test.dart`

**Interfaces:**
- Produces:
  - `class SlotObservation { final String computerId; final int slot; final DateTime date; final String serial; }`
  - `class SlotResolution { final String? serial; final bool olderThanFirstDownload; final bool changedHands; final DateTime? firstDownload; }`
  - `class TransmitterSlotTimeline { factory TransmitterSlotTimeline(Iterable<SlotObservation> observations); SlotResolution resolve(String computerId, int slot, DateTime date); }`

Rule: prev = latest observation with date <= D, next = earliest with date >= D,
both for (computerId, slot). Both present and serials differ: `changedHands`,
serial null. Both present and equal: that serial. Only next: next's serial,
`olderThanFirstDownload` true, `firstDownload` = next.date. Only prev: prev's
serial. Neither: all null/false.

- [ ] **Step 1:** Tests for each branch, plus: an observation on exactly D resolves to it; two computers with the same slot never mix; serials compare normalised (`normalizeTransmitterSerial`).
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement (sorted list per key, binary search or linear scan).
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5: Commit** `feat(transmitters): resolve which transmitter held a slot on a date`.

### Task 9: Slot preview and apply in the repository

**Files:**
- Create: `lib/features/transmitters/domain/entities/transmitter_slot_preview.dart`
- Create: `lib/features/transmitters/data/repositories/transmitter_slot_queries.dart` (the SQL, keeping `transmitter_repository.dart` under 800 lines)
- Modify: `lib/features/transmitters/data/repositories/transmitter_repository.dart` (`applyToExistingDives` gains `{Set<String> slotTankIds = const {}}`)
- Test: create `test/features/transmitters/data/repositories/transmitter_slot_match_test.dart`

**Interfaces:**
- Consumes: `TransmitterSlotTimeline` (Task 8).
- Produces:
  - `class SlotCandidate { final String tankId; final String diveId; final String computerId; final bool olderThanFirstDownload; final DateTime? firstDownload; }`
  - `class TransmitterSlotPreview { final List<SlotCandidate> candidates; final Set<String> changedHandsDiveIds; final Set<String> noSlotDiveIds; Set<String> tankIds({required bool includeOlder}); Set<String> diveIds({required bool includeOlder}); }`
  - `Future<TransmitterSlotPreview> TransmitterRepository.previewSlotMatches(Transmitter t)` (empty for an entry with no serial)
  - `Future<Set<String>> TransmitterRepository.computersForSerial(String serial)`
  - `Future<ApplyToExistingResult> applyToExistingDives(Transmitter t, {Set<String> slotTankIds = const {}})`

Candidate query: tanks with normalised serial null, `transmitter_slot` not
null, `EXISTS (SELECT 1 FROM tank_pressure_series s WHERE s.tank_id = dt.id)`,
`COALESCE(dt.computer_id, d.computer_id)` in the entry's computers, plus
`d.dive_date_time`. Observations: tanks with serial and slot on those
computers. `noSlotDiveIds`: dives on those computers with a series tank that
has neither serial nor slot. Apply re-reads `slotTankIds` and skips any that
gained a serial; the fill companion is the existing one.

- [ ] **Step 1:** Tests: a Cloud tank (slot 1, no serial, series) on the entry's computer after a download showing the serial in slot 1 is a candidate; the same tank without a series is not; a tank with another serial is never written even if its id is passed; a slot changed hands between two downloads lands in `changedHandsDiveIds`; a dive older than every download is flagged with that download's date; `tankIds(includeOlder: false)` drops it; two computers sharing the serial keep separate timelines (Review Focus 3); a slot tank on a computer with no observations is no candidate (Review Focus 5); apply with ids writes size and role and never a serial.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the test and `test/features/transmitters/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(transmitters): match file-imported tanks by computer slot`.

### Task 10: Backfill for stored dives

**Files:**
- Modify: `lib/features/dive_import/data/services/dive_resync_orchestrator.dart` (extract `Future<Map<String, dynamic>?> sourceEntryFor(String diveId)` from `resync`, which then uses it)
- Create: `lib/features/transmitters/data/services/transmitter_slot_backfill.dart`
- Create: `lib/features/transmitters/data/services/transmitter_slot_backfill_memo.dart` (SharedPreferences string list `transmitter_slot_backfill_done_v1` of data source ids and dive ids; local, unsynced)
- Test: create `test/features/transmitters/data/services/transmitter_slot_backfill_test.dart`

**Interfaces:**
- Consumes: `RawDiveParseFn`, `resolveParsedTanks`, `computerTankIndex`, `DiveResyncOrchestrator.sourceEntryFor`.
- Produces: `class TransmitterSlotBackfill { TransmitterSlotBackfill({required RawDiveParseFn parseRaw, DiveResyncOrchestrator? files, TransmitterSlotBackfillMemo? memo}); Future<int> run(Set<String> computerIds, {void Function(int done, int total)? onProgress}); }` returning tanks written.

Raw pass: tanks with a serial and no slot on those computers whose source has
`raw_data`; parse, resolve, match by `computerTankIndex(row) == tank.index`
and equal normalised serial, write the slot. File pass: dives on those
computers whose primary source has an `importedFileId` in format `uddf` or
`shearwaterDb` and whose series tanks have no slot; `sourceEntryFor`, then pair
the entry's tanks with stored rows ordered `tank_order, rowid` only when the
counts match; write slot (and, for `shearwaterDb`, the serial). Each write
stages the row and restamps `hlc` as reparse does. `MissingPluginException`
or `PlatformException('UNSUPPORTED')` from `parseRaw` skips the raw pass. Every
processed source or dive goes into the memo, slot found or not.

- [ ] **Step 1:** Tests: a download whose stored tank lacks a slot gets it from a fake `parseRaw`; a Cloud dive with a stored UDDF fixture gets slots `[0, 1]`; a Cloud dive whose stored tank count differs is skipped and untouched (Review Focus 2); a second `run` calls `parseRaw` zero times (Review Focus 4); `parseRaw` throwing `MissingPluginException` still runs the file pass; `resync` behaves as before (existing orchestrator tests).
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the test, `test/features/dive_import/`, `test/architecture/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(transmitters): learn transmitter slots for dives already stored`.

### Task 11: Apply dialog

**Files:**
- Create: `lib/features/transmitters/presentation/widgets/transmitter_apply_dialog.dart` (StatefulWidget: switch "include older", counts recomputed from the previews)
- Modify: `lib/features/transmitters/presentation/widgets/transmitter_key_widgets.dart:63-125` (`applyTransmitterSetupToExistingDives`: progress dialog while `TransmitterSlotBackfill.run(computers)` then previews; nothing-to-apply snackbar when serial and slot are both empty; confirm dialog; apply each key with the slot tank ids the dialog returns)
- Modify: `lib/features/transmitters/presentation/providers/transmitter_providers.dart` (a `transmitterSlotBackfillProvider`)
- Modify: every `lib/l10n/arb/app_*.arb`, keys:
  - `transmitters_apply_reading` "Reading transmitter slots from your dives"
  - `transmitters_apply_bySerial` "{dives} dives by serial"
  - `transmitters_apply_bySlot` "{dives} dives by slot on {computer}"
  - `transmitters_apply_olderNote` "{older} of them are from before your first download on {date}, assuming the transmitter sat in the same slot then"
  - `transmitters_apply_includeOlder` "Include dives from before the first download"
  - `transmitters_apply_changedHands` "{dives} dives skipped: another transmitter used this slot around then"
  - `transmitters_apply_noSlotInfo` "{dives} dives have no slot information"
- Test: `test/features/transmitters/presentation/widgets/transmitter_section_test.dart` (fake repository overrides gain the new methods), create `test/features/transmitters/presentation/widgets/transmitter_apply_dialog_test.dart`

- [ ] **Step 1:** Widget tests: the dialog shows the serial and slot lines and the older note with the date; turning the switch off drops the older dives from the totals line (`transmitters_apply_content`); Apply returns exactly `preview.tankIds(includeOlder: switchValue)`; with no slot candidates the dialog looks as it does today (no switch, no slot lines).
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement; run `flutter gen-l10n`.
- [ ] **Step 4:** Run the widget tests, `test/features/transmitters/`, `test/architecture/`, `test/shared/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(transmitters): preview slot matches in the apply dialog`.

### Task 12: Whole-branch verification

- [ ] `dart format .`, then `flutter analyze` on the whole repo: no issues.
- [ ] Run `test/features/transmitters/`, `test/features/dive_log/`, `test/features/dive_computer/`, `test/features/dive_import/`, `test/features/universal_import/`, `test/core/`, `test/architecture/`, `test/shared/`: all pass.
- [ ] Native ctest from Task 1: pass.
- [ ] After screenshots of the Apply dialog (phone and desktop) on a scratch DB.
