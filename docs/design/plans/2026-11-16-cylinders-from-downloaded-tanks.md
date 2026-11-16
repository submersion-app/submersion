# Cylinders from Downloaded Tanks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Offer to create cylinder Equipment items from a downloaded dive's tanks (summary card and per-tank action), linked to the tanks and never duplicating an owned cylinder.

**Architecture:** A pure matcher groups unlinked, unmatched tanks into cylinder proposals. A data service creates the items, links the tanks, writes corrected specs back and adds the gear in one transaction. A family provider over the import's new dive ids feeds a summary tile; one review sheet serves the tile and a per-tank menu on the Tanks card.

**Tech Stack:** Flutter, Riverpod, Drift, flutter_test with `setUpTestDatabase()`.

**Spec:** `docs/design/specs/2026-11-16-cylinders-from-downloaded-tanks-design.md`

## Global Constraints

- Matching: volume differs by less than 0.2 L; working pressure, when both have one, by less than 2 bar; material, when both have one, equal.
- Owned cylinders: `activeEquipmentProvider` items of type `EquipmentType.tank` (shared gear included; retired, sold and wanted already excluded) minus status `lost`. Spares count.
- Suit inflation: a `TankRole.suitInflation` tank matches only `isSuitInflationCylinder` items; any other tank only items that are not. Created items from such a tank get `cylinder_use = suit_inflation`.
- Twin pairs: any `CylinderPairing` (dates ignored, the conservative reading) whose two cylinders are both owned matches a tank whose volume is within 0.2 L of `twinPairVolume`, with `twinPairWorkingPressure` and material compared as above.
- Grouping key: volume rounded to 0.1 L, working pressure rounded to the nearest bar (or absent), material (or absent), suit inflation flag.
- Cylinders per group: the most tanks of that key on any single dive. On each dive, that dive's tanks of the key are assigned in `order` to cylinder 1, 2, and so on.
- Names: the first tank's `name`; else `TankPresets.matchAnyBySpecs(...)?.displayName`; else "<volume in diver's units> <material>" built in the UI. With N > 1 cylinders: "<name> 1" ... "<name> N".
- Every volume and pressure shown or typed follows the active diver's units; stored values stay metric.
- Every new string goes into all ARB files (feature-grouped; insert beside a neighbouring key of the same group), then `flutter gen-l10n`.
- No schema change. Sync: each written `dive_tanks` row gets `SyncRepository.markRecordPending(entityType: 'diveTanks', ...)`; then one `SyncEventBus.notifyLocalChange()`.
- Per-tank menu visible only when `canAssign` in `CylindersCard` (not offered, or unlocked with nothing unsaved, #4527).
- No em-dashes anywhere; no file over 800 lines.

## Review Focus

1. A first full-history download (hundreds of dives on one or two cylinders) must produce a handful of rows, not hundreds. Task 1 pins 40 dives on one AL80 to one row with 40 dives.
2. A dive with two identical sidemount tanks must make two cylinders, each linked to one tank per dive, not both tanks to cylinder 1. Task 1 and Task 3 pin it.
3. Imperial diver edits a row: cu ft input must convert back with the row's working pressure, and an untouched field must keep the original liters exactly (no round trip drift). Task 5 pins it.
4. The sheet confirming after the diver already linked a tank elsewhere (stale proposal) must not overwrite a non-null `equipment_id`. Task 3 pins it.
5. A tank with a volume but no working pressure or material must still match and group (absent fields compare as wildcards for matching, as a distinct "absent" for grouping). Task 1 pins it.

---

### Task 1: Matching and grouping (pure domain)

**Files:**
- Create: `lib/features/equipment/domain/services/tank_cylinder_matching.dart`
- Test: `test/features/equipment/domain/services/tank_cylinder_matching_test.dart`

**Interfaces:**
- Produces:
  - `class TankRef { final String diveId; final DiveTank tank; }` (const constructor, value equality not needed)
  - `class CylinderProposal { final double volumeL; final double? workingPressureBar; final TankMaterial? material; final bool suitInflation; final String? suggestedName; final List<List<TankRef>> tanksByCylinder; int get cylinderCount; int get diveCount; List<TankRef> get allTanks; }`
  - `bool cylinderMatchesTank(EquipmentItem item, DiveTank tank)`
  - `bool pairMatchesTank(EquipmentItem a, EquipmentItem b, DiveTank tank)`
  - `List<CylinderProposal> proposeCylinders(List<TankRef> tanks, {required List<EquipmentItem> owned, required List<(EquipmentItem, EquipmentItem)> ownedPairs})`: skips tanks with `equipmentId != null` or no positive volume, and tanks any owned item or pair matches; groups the rest; orders rows by `diveCount` descending.
  - `CylinderProposal proposalForTank(TankRef ref)`: one cylinder, one tank, no matching or volume filter (per-tank "Add to my gear").

- [ ] **Step 1: Write the failing tests**

Tests (build `DiveTank`s and `EquipmentItem`s with curated `volume_l` / `working_pressure_bar` / `tank_material` / `cylinder_use` attributes):
- `matches within 0.2 L and 2 bar`: item 11.1 L / 207 bar aluminum vs tank 11.0 / 207 / aluminum is true; vs 10.8 L is false; vs 207 bar tank at 232 bar is false.
- `absent pressure or material is a wildcard`: tank 11.1 L with null pressure and material matches the item.
- `material mismatch does not match`: steel tank vs aluminum item is false.
- `suit inflation matches only suit inflation`: suitInflation tank vs breathing item false; vs `cylinder_use = suit_inflation` item true; backGas tank vs suit item false.
- `twin pair matches combined volume`: two 12 L / 232 bar steel items vs a 24 L tank is true via `pairMatchesTank`; `proposeCylinders` with that pair in `ownedPairs` returns no row for the 24 L tank.
- `skips linked, volumeless and matched tanks`.
- `40 dives on one AL80 is one row`: 40 dives each with one 11.1 L tank, `owned` empty: one proposal, `cylinderCount == 1`, `diveCount == 40`.
- `sidemount pair makes two cylinders`: 3 dives each with two 11.1 L tanks (orders 0 and 1) and 1 dive with one: one row, `cylinderCount == 2`, `tanksByCylinder[0]` holds the order-0 tank of each dive (4 refs), `tanksByCylinder[1]` the order-1 tanks (3 refs).
- `suggestedName`: tank `name` "Blue 12" wins; else 11.1 L / 207 bar aluminum gives "AL80"; else null.
- `proposalForTank` returns one cylinder for a tank an owned item matches.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/equipment/domain/services/tank_cylinder_matching_test.dart`
Expected: FAIL (file not found / undefined names).

- [ ] **Step 3: Implement the file per the Interfaces and Global Constraints.**

- [ ] **Step 4: Run to verify they pass.** Same command, expected PASS.

- [ ] **Step 5: Commit** `feat(equipment): match and group dive tanks into cylinder proposals`

### Task 2: Shared cylinder spec attributes

**Files:**
- Create: `lib/features/equipment/domain/services/cylinder_spec_attributes.dart`
- Modify: `lib/features/cylinder_passports/data/services/passport_adoption_service.dart` (replace `_specAttributes` body with a call)
- Test: `test/features/equipment/domain/services/cylinder_spec_attributes_test.dart`

**Interfaces:**
- Produces: `List<EquipmentAttribute> cylinderSpecAttributes({double? volumeL, double? workingPressureBar, TankMaterial? material, String? valveChoice, bool suitInflation = false})`: curated attributes with `equipmentId: ''`; material through `tankMaterialChoiceKey`; `cylinder_use = suit_inflation` only when `suitInflation`.

- [ ] **Step 1: Failing test** `writes curated keys`: volume 11.1, pressure 207, carbonFiber, suitInflation true gives keys `volume_l` (11.1), `working_pressure_bar` (207), `tank_material` ('carbon_composite'), `cylinder_use` ('suit_inflation'); all null args give an empty list.
- [ ] **Step 2: Run, expect FAIL.** `flutter test test/features/equipment/domain/services/cylinder_spec_attributes_test.dart`
- [ ] **Step 3: Implement; make `PassportAdoptionService` use it** (passing `valveChoice: valveChoiceKey(v)`).
- [ ] **Step 4: Run the new test and** `flutter test test/features/cylinder_passports/data/services/passport_adoption_service_test.dart`; expect PASS.
- [ ] **Step 5: Commit** `refactor(equipment): share cylinder spec attributes with passport adoption`

### Task 3: Create, link and unlink service

**Files:**
- Create: `lib/features/equipment/data/services/cylinder_from_tank_service.dart`
- Test: `test/features/equipment/data/services/cylinder_from_tank_service_test.dart`

**Interfaces:**
- Consumes: `CylinderProposal`, `TankRef` (Task 1); `cylinderSpecAttributes` (Task 2); `EquipmentRepository.createEquipment(..., notify: false)` and `.transaction`; `DiveRepository.bulkAddEquipment(diveIds, [id])`.
- Produces:
  - `class CylinderDraft { final CylinderProposal proposal; final String name; final double volumeL; final double? workingPressureBar; final TankMaterial? material; }`
  - `class CylinderFromTankService { CylinderFromTankService({EquipmentRepository? equipment, DiveRepository? dives}); Future<List<EquipmentItem>> create(List<CylinderDraft> drafts, {required String? diverId}); Future<void> linkTank({required String diveId, required String tankId, required String equipmentId}); Future<void> unlinkTank(String tankId); }`
  - `create` names items `name` when `cylinderCount == 1`, else `"$name ${i + 1}"`; links each `tanksByCylinder[i]` tank to item i only where `equipment_id IS NULL` at write time; when the draft's volume, pressure or material differ from the proposal's, writes them onto those tanks with `presetName: TankPresets.matchAnyBySpecs(...)?.name`; gear via `bulkAddEquipment`. One transaction, then `SyncEventBus.notifyLocalChange()`.

- [ ] **Step 1: Failing tests** (real DB via `setUpTestDatabase()`, dives and tanks inserted directly):
  - `creates one item linked to every dive`: proposal over 3 dives, unchanged draft: one tank item with the three attributes; each tank's `equipment_id` is it; each dive's `dive_equipment` has it; tank `volume` unchanged.
  - `two cylinders split by tank order`: sidemount proposal from Task 1's fixture: items "AL80 1" and "AL80 2"; order-0 tanks link to the first.
  - `corrected spec is written back`: draft volume 12.0, 232 bar, steel: the tanks now hold 12.0 / 232 / 'steel' and `presetName` is the matching preset's name or null.
  - `never overwrites an existing link`: a tank given an `equipment_id` after the proposal was built keeps it.
  - `marks tanks pending for sync`: `sync_records` (or the table `markRecordPending` writes) has a `diveTanks` row per linked tank.
  - `linkTank adds gear, unlinkTank clears only the link`.
- [ ] **Step 2: Run, expect FAIL.** `flutter test test/features/equipment/data/services/cylinder_from_tank_service_test.dart`
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(equipment): create cylinders from dive tanks and link them`

### Task 4: Proposals provider

**Files:**
- Create: `lib/features/equipment/presentation/providers/cylinder_proposal_providers.dart`
- Test: `test/features/equipment/presentation/providers/cylinder_proposal_providers_test.dart`

**Interfaces:**
- Consumes: `ImportedDiveIds` (from `site_match_review_notifier.dart`), `DiveRepository.getDivesByIdsWithoutSamples`, `activeEquipmentProvider`, `cylinderPairingRepositoryProvider` `.getAll()`, `proposeCylinders`.
- Produces: `final importCylinderProposalsProvider = FutureProvider.autoDispose.family<List<CylinderProposal>, ImportedDiveIds>`; `final cylinderFromTankServiceProvider = Provider<CylinderFromTankService>`. Re-evaluates when equipment or `dive_tanks` change (`ref.invalidateSelfWhen`), so the tile disappears once nothing is left.

- [ ] **Step 1: Failing test** with a `ProviderContainer` over the test DB: two imported dives with an 11.1 L tank and no gear give one proposal with `diveCount == 2`; after inserting an owned 11.1 L aluminum tank item, re-reading gives none.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(equipment): provide cylinder proposals for an import`

### Task 5: Review sheet

**Files:**
- Create: `lib/features/equipment/presentation/widgets/cylinders_from_tanks_sheet.dart`
- Create: `lib/features/equipment/domain/services/tank_volume_input.dart`
- Modify: every `lib/l10n/arb/app_*.arb`
- Test: `test/features/equipment/presentation/widgets/cylinders_from_tanks_sheet_test.dart`, `test/features/equipment/domain/services/tank_volume_input_test.dart`

**Interfaces:**
- Consumes: `CylinderProposal`, `CylinderDraft`, `cylinderFromTankServiceProvider`, `settingsProvider` / `UnitFormatter`.
- Produces:
  - `String tankVolumeInputText(double liters, double? workingPressureBar, VolumeUnit unit)` and `double? tankVolumeFromInput(String text, {required String initialText, required double initialLiters, required double? workingPressureBar, required VolumeUnit unit})`: cu ft only with a working pressure (rated cuft from `TankPresets.matchBySpecs` when it matches, else ideal gas, as `tank_editor.dart` does); unchanged text returns `initialLiters`.
  - `Future<int?> showCylindersFromTanksSheet(BuildContext context, List<CylinderProposal> proposals)`: resolves to the number of items created, or null when cancelled; shows a SnackBar "Added N cylinders to your gear" on success.
- ARB keys (English values): `cylindersFromTanks_title` "Add cylinders to your gear"; `cylindersFromTanks_onDives` "{count, plural, =1{on 1 dive} other{on {count} dives}}"; `cylindersFromTanks_add` "{count, plural, =1{Add 1 cylinder} other{Add {count} cylinders}}"; `cylindersFromTanks_added` "{count, plural, =1{Added 1 cylinder to your gear} other{Added {count} cylinders to your gear}}"; `cylindersFromTanks_summary` "{count, plural, =1{1 tank isn't in your gear} other{{count} tanks aren't in your gear}}"; `cylindersFromTanks_review` "Review"; `cylindersFromTanks_name` "Name". Reuse existing volume, working pressure and material labels from the tank editor's keys. Every `=1{...}` branch says the number through `{count}` where the locale's `one` category covers more than 1 (fr, pt), per the plural guard.

- [ ] **Step 1: Failing tests**:
  - `tankVolumeInputText` / `tankVolumeFromInput`: metric round trip; imperial 11.1 L / 207 bar shows "80"; unchanged "80" returns 11.1 exactly; "100" at 207 bar returns 100 * 28.3168 / 207.
  - Widget: two proposals render two rows with names and "on 40 dives"; unticking one changes the button to "Add 1 cylinder"; tapping it calls a fake service's `create` with one draft carrying the edited name.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement; add ARB keys to all locales with translations; run `flutter gen-l10n`.**
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(equipment): review sheet for cylinders from dive tanks`

### Task 6: Download summary tile

**Files:**
- Create: `lib/features/import_wizard/presentation/widgets/import_cylinders_tile.dart`
- Modify: `lib/features/import_wizard/presentation/providers/import_wizard_providers.dart` (add `ImportSourceType get sourceType => _adapter.sourceType;` to the notifier)
- Modify: `lib/features/import_wizard/presentation/widgets/import_summary_step.dart` (place the tile directly after the data-quality tile)
- Test: `test/features/import_wizard/presentation/widgets/import_cylinders_tile_test.dart`

**Interfaces:**
- Consumes: `importCylinderProposalsProvider`, `showCylindersFromTanksSheet`.
- Produces: `class ImportCylindersTile extends ConsumerWidget { const ImportCylindersTile({super.key, required this.importedDiveIds}); }` styled like the data-quality tile (`ListTile` dense, `TileSubtitleAction` "Review", leading icon from the tank icon the Tanks card uses). Count shown is the number of tanks across proposals. Rendered only when `sourceType == ImportSourceType.diveComputer` and `importedDiveIds` is non-empty.

- [ ] **Step 1: Failing widget tests** (override `importCylinderProposalsProvider`): with one proposal over 2 tanks it shows "2 tanks aren't in your gear" and Review opens the sheet; with none it renders nothing.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement and wire into the summary.**
- [ ] **Step 4: Run the new test and** `flutter test test/features/import_wizard/presentation/widgets/import_summary_step_test.dart`; expect PASS.
- [ ] **Step 5: Commit** `feat(import-wizard): offer cylinders for a download's unmatched tanks`

### Task 7: Per-tank menu on the Tanks card

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/tank_gear_menu.dart`
- Modify: `lib/features/dive_log/presentation/widgets/own_cylinder_picker_sheet.dart` (`showOwnCylinderPicker(BuildContext context, {bool hideSpare = true, String? title, String? hint})`, defaults unchanged)
- Modify: `lib/features/dive_log/presentation/widgets/cylinders_card.dart` (trailing becomes the check-in chip and the menu; the menu keeps its room when `!canAssign` with the same Opacity/IgnorePointer/ExcludeSemantics pattern as Assign)
- Modify: every ARB (`diveLog_tank_gearMenu` "Cylinder options", `diveLog_tank_addToGear` "Add to my gear", `diveLog_tank_linkCylinder` "Link to a cylinder I own", `diveLog_tank_linkCylinderHint` "Links this tank to the cylinder. The tank keeps its recorded size.", `diveLog_tank_unlinkCylinder` "Unlink cylinder")
- Test: `test/features/dive_log/presentation/widgets/tank_gear_menu_test.dart`

**Interfaces:**
- Consumes: `proposalForTank`, `showCylindersFromTanksSheet`, `showOwnCylinderPicker`, `cylinderFromTankServiceProvider`.
- Produces: `class TankGearMenu extends ConsumerWidget { const TankGearMenu({super.key, required this.dive, required this.tank}); }`: `PopupMenuButton` keyed `Key('tank-gear-menu-${tank.id}')`; unlinked tank offers Add and Link; linked tank offers Unlink.

- [ ] **Step 1: Failing widget tests**: unlinked tank shows Add and Link, not Unlink; linked shows only Unlink; Unlink calls the fake service's `unlinkTank(tank.id)`; Link with a picked item calls `linkTank`; in `CylindersCard`, a locked offered dive hides the menu (opacity 0, ignored).
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement; ARB keys in all locales; `flutter gen-l10n`.**
- [ ] **Step 4: Run the new test and** `flutter test test/features/dive_log/presentation/widgets/cylinders_card_test.dart`; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-log): add, link or unlink a tank's cylinder from the Tanks card`

### Task 8: Whole-branch checks

- [ ] `dart format .` then `flutter analyze` (whole repo): no issues.
- [ ] `flutter test test/architecture/ test/shared/` plus every test file this plan touched: PASS.
- [ ] Scan the diff for em-dashes (U+2014): `git diff origin/main | python3.14 -c "import sys; print(sys.stdin.read().count(chr(0x2014)))"` prints 0.
