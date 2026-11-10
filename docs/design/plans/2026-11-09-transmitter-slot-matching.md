# Transmitter Slot Matching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> to implement this plan task-by-task, inline. Steps use checkbox (`- [ ]`)
> syntax for tracking.

**Goal:** "Apply to existing dives" can also fill serial-less cylinders
imported from a Shearwater Cloud UDDF, matched by the T slot the diver picks
in the Apply dialog.

**Architecture:** The UDDF parser ties each `T<n>` ref to its cylinder by
begin pressure and records the slot on the parsed tank. At Apply time a new
`TransmitterSlotMatcher` re-parses each candidate dive's stored original file
(through a finder factored out of `DiveResyncOrchestrator`), pairs parsed and
stored cylinders by pressures and gas, and returns stored cylinder ids per
slot. A new stateful `TransmitterApplyDialog` shows the per-slot counts; the
repository writes serial matches plus the chosen slot's ids through one pure
fill function shared with the preview.

**Tech Stack:** Flutter, Riverpod, Drift (SQLite), `xml`, ARB l10n.

**Spec:** `docs/design/specs/2026-11-09-transmitter-slot-matching-design.md`

## Global Constraints

- No schema, sync-serializer or registry change.
- Slot matching runs only from the Apply dialog, only on cylinders with a null
  (or blank, per `normalizeTransmitterSerial`) serial, only on dives attributed
  to a computer the serial was seen on, never on a dive where any cylinder
  already carries this serial.
- Fill rules are unchanged: size, working pressure, material, preset, gear
  link and name only where empty; role only where `backGas` (and the entry's
  role differs) or name-derived.
- A slot label is tied to a cylinder only by begin-pressure evidence, never by
  order.
- Preview counts and write counts come from the same function and the same
  cylinder ids.
- Every new string in all 11 ARB files (`lib/l10n/arb/app_*.arb`), then
  `flutter gen-l10n`.
- No em-dashes anywhere. `dart format .` before each commit.
- Files under 800 lines; new logic goes in new files.

## Review Focus

1. A sidemount Cloud dive where T3's first sample precedes T2's: T2 and T3
   must still land on their own cylinders (Task 1 test).
2. Two cylinders with identical begin pressure: no slot label for either, and
   routing falls back to today's order (Task 1 test).
3. A dive edited after import so its pressures no longer match the file: that
   cylinder is skipped, not mis-paired (Task 5 test).
4. Applying the same slot twice: the second preview offers zero for that slot
   (Task 4 and Task 6 tests).
5. A UDDF cylinder on a channel-only entry's computer: no longer matched by
   channel (Task 3 test).

---

### Task 1: Tie `T<n>` refs to cylinders by begin pressure

**Files:**
- Create: `lib/core/services/export/uddf/uddf_tank_ref_router.dart`
- Modify: `lib/core/services/export/uddf/uddf_full_import_service.dart`
  (the `fallbackTankIndices` / `fallbackRefToIndex` block near line 2466 and
  the ref routing near line 2604)
- Test: `test/core/services/export/uddf/uddf_tank_ref_router_test.dart`,
  `test/core/services/export/uddf/uddf_full_import_tank_data_test.dart`

**Interfaces:**
- Produces: `class UddfTankRefRouter { UddfTankRefRouter(List<Map<String, dynamic>> tanks); int? indexFor(String ref, double firstPressureBar); void writeSlots(); }`
  and the parsed-tank key `kUddfSourceSlotKey = 'sourceSlot'` (int, 1-based).

- [ ] **Step 1: Write failing router tests** in
  `uddf_tank_ref_router_test.dart`. Tanks are maps like
  `{'startPressure': 132.9}` (no `uddfTankId`).
  - `ties each ref to the cylinder whose begin pressure equals its first reading`:
    tanks `[{start 132.93}, {start 147.27}]`; call `indexFor('T3', 147.27)`
    then `indexFor('T2', 132.93)`; expect `1` then `0`; after `writeSlots()`,
    `tanks[0]['sourceSlot'] == 2`, `tanks[1]['sourceSlot'] == 3`.
  - `repeated ref returns the same index`: second `indexFor('T2', 100.0)`
    returns the first call's index.
  - `ambiguous pressure gives no slot and falls back to first-seen order`:
    tanks `[{start 200.0}, {start 200.0}]`; `indexFor('T2', 200.0) == 0`,
    `indexFor('T1', 200.0) == 1`; after `writeSlots()` neither map has
    `sourceSlot`.
  - `non-T ref routes but gives no slot`: `indexFor('tank_a', 132.93)` returns
    the paired index, no `sourceSlot` written.
  - `more refs than cylinders returns null`.
  - `cylinders with a uddfTankId are never fallback targets`.
- [ ] **Step 2: Run** `flutter test test/core/services/export/uddf/uddf_tank_ref_router_test.dart`;
  expected FAIL (file missing).
- [ ] **Step 3: Implement `UddfTankRefRouter`.** Candidates are the indices
  without `uddfTankId`, unclaimed. Pairing: exactly one unclaimed candidate
  with `(startPressure - firstPressureBar).abs() < 0.01`; else the next
  unclaimed candidate in list order (today's behaviour). Slot recorded only
  for a pressure-paired ref matching `^T(\d+)$` (trim, case-insensitive).
  `writeSlots()` sets `tanks[i][kUddfSourceSlotKey]`.
- [ ] **Step 4: Replace** the `fallbackTankIndices` / `fallbackRefToIndex` /
  `nextFallbackTankIndex` logic in `uddf_full_import_service.dart` with one
  `UddfTankRefRouter`, call `indexFor(tankRef, pressure)` in the unmatched-ref
  branch (keep the debug log when it returns null), and `router.writeSlots()`
  after the waypoint loop.
- [ ] **Step 5: Add import tests** to `uddf_full_import_tank_data_test.dart`
  using an inline UDDF with six bare `<tankdata>` (two with pressures, four
  `0/0`) and waypoints where `ref="T3"` appears before `ref="T2"`:
  - `a later transmitter reporting first keeps each pressure series on its own cylinder`:
    the cylinder whose begin pressure is T2's first reading gets T2's samples.
  - `Shearwater refs record the slot on each parsed cylinder`: tanks carry
    `sourceSlot` 2 and 3.
  - Existing fixture `test/dives/006_ccr_petrel3_shearwater-cloud-export.uddf`:
    slots 1 and 2.
- [ ] **Step 6: Run** the two test files plus
  `test/core/services/export/uddf/` whole; expected PASS.
- [ ] **Step 7: Commit** `feat(import): tie UDDF transmitter refs to cylinders by begin pressure`

### Task 2: UDDF cylinders keep their list position as `tank_order`

**Files:**
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart:3670-3701`
- Test: `test/features/dive_import/data/services/uddf_entity_importer_test.dart`

- [ ] **Step 1: Failing test** `cylinders without a tankorder keep their file position`:
  import a two-cylinder UDDF with no `<tankorder>`; stored `tank_order`s are
  `[0, 1]`. A file with `<tankorder>` keeps its own values.
- [ ] **Step 2: Run, expect FAIL** (both 0).
- [ ] **Step 3: Implement**: map `processedTanks` with its index and use
  `t['order'] as int? ?? index`.
- [ ] **Step 4: Run** the importer tests; expect PASS.
- [ ] **Step 5: Commit** `fix(import): keep UDDF cylinder order instead of storing every cylinder as 0`

### Task 3: Channel matching skips file-imported cylinders

**Files:**
- Modify: `lib/features/transmitters/data/repositories/transmitter_repository.dart`
  (`_tanksForEntry`, channel branch)
- Test: `test/features/transmitters/data/repositories/transmitter_repository_test.dart`

- [ ] **Step 1: Failing test** `a channel entry does not match a file-imported cylinder`:
  seed computer `c1`, dive `d1` (computer `c1`) with a primary
  `dive_data_sources` row whose `source_file_format = 'uddf'`, and a cylinder
  with `sourceIndex: null`, `computerId: null`, `order: 0`; entry
  `channel: 0, computerId: 'c1', serial: null`; preview counts 0. Companion
  test: a downloaded cylinder (`sourceIndex: 0`) on a dive whose source has no
  file format still matches.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement**: add to the channel SQL
  `AND NOT (dt.source_tank_index IS NULL AND dt.computer_id IS NULL AND EXISTS (SELECT 1 FROM dive_data_sources s WHERE s.dive_id = d.id AND s.is_primary = 1 AND s.source_file_format IS NOT NULL))`.
  A pre-v200 download (no `source_tank_index`) has no file format, so it
  keeps matching.
- [ ] **Step 4: Run** the repository tests; PASS.
- [ ] **Step 5: Commit** `fix(transmitters): stop channel entries matching file-imported cylinders`

### Task 4: One fill function for preview and write

**Files:**
- Create: `lib/features/transmitters/data/services/transmitter_tank_fill.dart`
- Modify: `transmitter_repository.dart` (`previewApplyToExistingDives`,
  `applyToExistingDives`)
- Test: `test/features/transmitters/data/services/transmitter_tank_fill_test.dart`,
  repository test

**Interfaces:**
- Produces: `DiveTanksCompanion? transmitterFillFor(DiveTank row, Transmitter t)`
  (null when nothing would change). The role and `roleSource` rules move here
  verbatim from `applyToExistingDives`.
- Produces on the repository:
  `Future<ApplyToExistingResult> previewApplyToExistingDives(Transmitter t, {Iterable<String> slotTankIds = const []})` and
  `Future<ApplyToExistingResult> applyToExistingDives(Transmitter t, {Iterable<String> slotTankIds = const []})`.
  Slot ids are loaded, re-filtered to serial-less rows, de-duplicated against
  the serial matches, and run through the same loop.

- [ ] **Step 1: Failing unit tests** for `transmitterFillFor`: empty volume
  filled; set volume kept; `backGas` replaced by `sidemountLeft`; diver-set
  role kept; name-derived role replaced and `roleSource` cleared; fully
  filled row returns null.
- [ ] **Step 2: Failing repository tests**:
  `preview counts only cylinders the fill would change` (one filled, one
  empty: preview `tanksUpdated == 1`);
  `slot ids are filled with the same rules and never gain the serial`;
  `a slot id that gained a serial since the preview is skipped`;
  `the second preview after applying a slot counts zero`.
- [ ] **Step 3: Run, expect FAIL.**
- [ ] **Step 4: Implement** both, with the mix fixer staying in the write
  path as today.
- [ ] **Step 5: Run** repository, fill and `test/features/data_quality/`
  (it calls `applyToExistingDives`); PASS.
- [ ] **Step 6: Commit** `feat(transmitters): count only the cylinders an apply would change`

### Task 5: Shared stored-file dive finder

**Files:**
- Create: `lib/features/dive_import/data/services/stored_source_dive_finder.dart`
- Modify: `lib/features/dive_import/data/services/dive_resync_orchestrator.dart`
- Test: `test/features/dive_import/data/services/stored_source_dive_finder_test.dart`;
  existing `dive_resync_orchestrator_test.dart` must stay green unchanged.

**Interfaces:**
- Produces:
  `class StoredSourceDiveFinder { StoredSourceDiveFinder({required AppDatabase db, ImportedFileRepository? importedFiles, ImportParser Function(ImportFormat)? parserFor}); Future<StoredSourceLookup> find(String diveId); Future<Map<String, Map<String, dynamic>>> findMany(Iterable<String> diveIds); }`
  with `class StoredSourceLookup { final Map<String, dynamic>? parsedDive; final DiveResyncFailure? failure; }`.
  `findMany` parses each stored file once, returns only dives found, and
  swallows per-dive failures.

- [ ] **Step 1: Failing tests**: `find` returns `noStoredFile`,
  `unsupportedFormat`, `storedFileMissing`, `noMatchingDive`,
  `ambiguousDiver` as the orchestrator does today (move the matching cases
  from the orchestrator test's setup); `findMany parses a shared file once`
  (counting fake parser).
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Move** the lookup, parse, diver-key filter and scoring loop
  out of `DiveResyncOrchestrator.resync` into `find`; the orchestrator calls
  `find` and keeps the demo gate and `applyReimport`.
- [ ] **Step 4: Run** both test files; PASS.
- [ ] **Step 5: Commit** `refactor(import): share the stored-file dive lookup with resync`

### Task 6: `TransmitterSlotMatcher`

**Files:**
- Create: `lib/features/transmitters/data/services/transmitter_slot_matcher.dart`
- Modify: `lib/features/transmitters/presentation/providers/transmitter_providers.dart`
  (add `transmitterSlotMatcherProvider`)
- Test: `test/features/transmitters/data/services/transmitter_slot_matcher_test.dart`

**Interfaces:**
- Consumes: `StoredSourceDiveFinder.findMany`, `kUddfSourceSlotKey`,
  `transmitterFillFor`.
- Produces:
  `class SlotComputer { final String computerId; final String computerName; }`
  `class SlotCandidates { final SlotComputer computer; final Map<int, List<String>> tankIdsBySlot; int divesFor(int slot); }`
  `Future<List<SlotComputer>> computersWithCandidates(Transmitter t)` (SQL
  only: spec section 3 items 1 and 2) and
  `Future<List<SlotCandidates>> resolve(Transmitter t)` (parses). Only
  cylinders `transmitterFillFor` would change are kept.

- [ ] **Step 1: Failing tests** with a real in-memory DB and a fake finder:
  - `offers nothing for an entry without a serial`.
  - `finds the computers the serial was downloaded on`.
  - `skips a dive that already carries the serial`, `a dive on another
    computer`, `a dive without a stored UDDF file`, `another diver's dive`.
  - `pairs parsed and stored cylinders by pressures and gas` (two cylinders,
    slots 2 and 3, mapped to the right ids).
  - `skips a cylinder whose pressures were edited after import`.
  - `skips a cylinder that pairs with two stored cylinders`.
  - `skips cylinders the fill would not change`.
  - One integration test with the real UDDF parser and a stored file built
    from the Task 1 inline UDDF.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** Pairing tolerance: 0.05 bar on start and end
  pressure, 0.1 on O2 and He percent; a stored null pressure never pairs.
  Computer name from `dive_computers.name`.
- [ ] **Step 4: Run; PASS.** Also `test/architecture/`.
- [ ] **Step 5: Commit** `feat(transmitters): find file-imported cylinders by computer slot`

### Task 7: The Apply dialog

**Files:**
- Create: `lib/features/transmitters/presentation/widgets/transmitter_apply_dialog.dart`
- Modify: `lib/features/transmitters/presentation/widgets/transmitter_key_widgets.dart`
  (`applyTransmitterSetupToExistingDives`), all 11 `lib/l10n/arb/app_*.arb`
- Test: `test/features/transmitters/presentation/widgets/transmitter_apply_dialog_test.dart`,
  `transmitter_section_test.dart` (fake repository gains the new optional
  parameter and a fake slot matcher override)

**Interfaces:**
- Produces: `class TransmitterApplyDialog extends ConsumerStatefulWidget { const TransmitterApplyDialog({required List<Transmitter> keys, required ApplyToExistingResult serialPreview, required List<SlotComputer> slotComputers}); }`
  popping `Map<String, List<String>>?` (computer id to chosen slot's tank
  ids; empty map for "no slot"; null for cancel).
- New ARB keys (English):
  - `transmitters_apply_slot_label`: `Slot on {computer}`
  - `transmitters_apply_slot_none`: `Don't match by slot`
  - `transmitters_apply_slot_option`: `T{slot}: {dives, plural, =1{1 dive} other{{dives} dives}}`
  - `transmitters_apply_slot_reading`: `Reading imported files`
  - `transmitters_apply_slot_intro`: `Cylinders imported from a file have no serial. Pick the slot this transmitter sat in to fill them too.`
  - `transmitters_apply_summary`: `{serialDives} dives by serial, {slotDives} by slot`
  - `transmitters_apply_nothing_to_fill`: `No cylinder needs this transmitter's setup`

- [ ] **Step 1: Failing widget tests**:
  - `shows today's content when no computer has slot candidates`.
  - `shows a slot row per computer with a progress indicator until resolved`.
  - `each slot option shows its dive count and a zero option is disabled`.
  - `picking a slot updates the summary`.
  - `confirming returns the chosen slot's tank ids`.
  - `opens with slot rows even when the serial preview is zero`.
  - `the nothing SnackBar uses the new wording when both routes are empty`.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** Use a `DropdownButtonFormField<int?>` per
  computer (phone-width safe). `resolve` starts in `initState` for each serial
  key; results merge by computer id. `applyTransmitterSetupToExistingDives`
  shows the dialog when serial tanks > 0 or `computersWithCandidates` is
  non-empty, passes the chosen ids to `applyToExistingDives(key,
  slotTankIds: ...)` for the key whose computers they came from, and sums the
  done counts.
- [ ] **Step 4: Translate** the seven keys into ar, de, es, fr, he, hu, it,
  nl, pt, zh; `flutter gen-l10n`.
- [ ] **Step 5: Run** the transmitters presentation tests and the l10n
  staleness check (`test/l10n/` if present); PASS.
- [ ] **Step 6: Commit** `feat(transmitters): pick a slot in the apply dialog to fill file-imported cylinders`

### Task 8: Verify and capture

- [ ] `dart format .`, `flutter analyze` (whole repo), `test/architecture/`,
  `test/shared/`, `test/features/transmitters/`,
  `test/features/dive_import/`, `test/core/services/export/uddf/`.
- [ ] After screenshots with the untracked `test/zz_shots/` harness (never
  staged): dialog with slot rows light, dark and phone; nothing SnackBar.
- [ ] Delete `test/zz_shots/` before the PR.
