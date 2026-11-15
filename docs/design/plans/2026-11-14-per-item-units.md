# Per-item units for equipment fields Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in one session (no subagents). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let every unit-bearing equipment number carry its own unit (a psi gauge for a metric diver), saved in a new `equipment_attributes.value_unit` column, with cylinder cubic feet meaning gas capacity everywhere and old mis-saved cylinder volumes repaired.

**Architecture:** Storage stays canonical metric in `value_num`; `value_unit` only says which unit the item's own spec reads in. One pure helper module resolves "the unit in force" for a row and converts to and from it; the form, the detail page, the passport readers and the CSV all go through it. A v368 rung adds the column and repairs cylinder volumes, and the same repair repeats after each sync apply.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod, the repo's sync serializer and MCP agent-access layer.

**Spec:** `docs/design/specs/2026-11-14-per-item-units-design.md`

## Global Constraints

- Schema version **368**: planned as 366, renumbered at merge after main took 364 to 367. Re-check open PRs before pushing and renumber if taken.
- `value_unit` stored values: `bar`, `psi`, `dual`, `kilograms`, `pounds`, `liters`, `cubicFeet`, `meters`, `feet`. `NULL` means follow the diver's settings. Unknown or mismatched values read as `NULL`.
- `dual` is valid only on `gauge_max_pressure_bar`.
- No picker, and always litres, on `diluent_cylinder_l` and `o2_cylinder_l`. No picker on `thicknessMm`, `durationH`, `none`.
- Cylinder volume (`volume_l` on a tank) in cubic feet is rated gas capacity via `ratedCapacityCuft` / `volumeLitersFromCapacity` (`lib/core/services/export/csv/codec/tank_capacity.dart`); no working pressure means the assumed 200 bar (`assumedWorkingPressureBar`), shown with "~" as `formatTankVolume` does.
- Changing the unit relabels the typed figure; it never converts it.
- Repair: tank `volume_l` rows with `value_num > 80` are rewritten as `volumeLitersFromCapacity(value_num / 28.3168, workingPressureBar)`. No `updated_at` or `hlc` stamp. Repeated after each sync apply.
- New columns and tables never go in `database.dart`'s ladder body; tables in `lib/core/database/tables/`, rung helpers in `lib/core/database/migrations/helpers/` as part files, backstop in `before_open_child_columns.dart` (not `before_open.dart`, at its line cap).
- No em-dashes anywhere. No emojis. `dart format .` before each commit. Never run the full test suite locally.
- Every new user-visible string goes in all 11 ARB files, feature-grouped next to a neighbouring key.

## Review Focus

1. **Diver changes their settings after picking a unit**: a bar gauge stays bar when the diver switches to imperial, while untouched fields follow. Pinned in Task 1 and Task 4.
2. **A unit picked with no number** (pick psi, then clear or not yet type the value) survives the save and is invisible on the detail page. Pinned in Task 2 and Task 5.
3. **Older sync peer omits `valueUnit`**: the unit set here is kept; a peer that sends an explicit null clears it. Pinned in Task 3.
4. **Typing a working pressure keystroke by keystroke** ("3", "30", "300", "3000 psi") after an 80 cu ft volume: the volume field keeps reading 80 and the stored litres follow the final pressure, with no drift through preset matches. Pinned in Task 5.
5. **Locale decimal comma**: relabelling "7,5 kg" to lbs keeps 7.5 as the figure in a comma locale. Pinned in Task 5.

---

### Task 1: Unit resolution helpers

**Files:**
- Create: `lib/features/equipment/presentation/utils/equipment_attribute_item_units.dart`
- Test: `test/features/equipment/presentation/utils/equipment_attribute_item_units_test.dart`

**Interfaces:**
- Produces:
  - `enum AttributeUnit { bar, psi, dual, kilograms, pounds, liters, cubicFeet, meters, feet }` (stored as `.name`)
  - `List<AttributeUnit> attributeUnitChoices(EquipmentAttributeDef def)`: `[]` when no picker; pressure `[bar, psi]` plus `dual` for `gauge_max_pressure_bar`; mass `[kilograms, pounds]`; volume `[liters, cubicFeet]`; depth, length, short length, speed `[meters, feet]`.
  - `AttributeUnit? parseAttributeUnit(EquipmentAttributeDef def, String? stored)`: null unless `stored` is in `attributeUnitChoices(def)`.
  - `AttributeUnit attributeUnitInForce(EquipmentAttributeDef def, EquipmentAttribute? attr, UnitFormatter units)`: litres for the two rebreather keys; else the parsed row unit; else the diver's unit for the dimension (short length follows `units.heightIsMetric`, speed and length follow depth).
  - `AttributeUnit attributeTypingUnit(AttributeUnit inForce, UnitFormatter units)`: `dual` becomes the diver's pressure unit, everything else is itself.
  - `bool isCylinderGasVolume(EquipmentAttributeDef def, AttributeUnit unit)`: `def.key == EquipmentAttrKeys.volumeL && unit == AttributeUnit.cubicFeet`.
  - `double attributeValueIn(EquipmentAttributeDef def, AttributeUnit unit, double metric, {double? workingPressureBar})` and `double attributeMetricFromValue(EquipmentAttributeDef def, AttributeUnit unit, double value, {double? workingPressureBar})`: exact inverses; gas volume through the tank_capacity pair; speed is per minute (x60) and short length cm or in, matching `attributeDisplayFromMetric`.
  - `String attributeUnitLabel(EquipmentAttributeDef def, AttributeUnit unit, AppLocalizations l10n)`: the symbol (`bar`, `psi`, `kg`, `lbs`, `L`, `cuft`, `m`, `ft`, `cm`, `in`, `m/min`, `ft/min`), or `l10n.attr_unitDual` for `dual`.

- [ ] **Step 1: Write failing tests**, one group per function, including:
  - `attributeUnitChoices(gaugeDef)` equals `[bar, psi, dual]`; `workingPressureDef` equals `[bar, psi]`; `diluentCylinderDef`, `thicknessDef`, `burnTimeDef` are empty.
  - `parseAttributeUnit(workingPressureDef, 'dual')` is null; `parseAttributeUnit(dryWeightDef, 'psi')` is null; `parseAttributeUnit(gaugeDef, 'psi')` is `psi`.
  - `attributeUnitInForce(gaugeDef, attrWithUnit('bar'), imperialUnits)` is `bar`; with `valueUnit: null` and imperial it is `psi`; `diluentCylinderDef` with imperial is `liters`.
  - `attributeValueIn(gaugeDef, psi, 275.79)` is about 4000 (`closeTo(4000, 0.1)`); `attributeMetricFromValue(gaugeDef, psi, 4000)` is about 275.79.
  - `attributeMetricFromValue(tankVolumeDef, cubicFeet, 80, workingPressureBar: 206.8)` equals the AL80 preset litres (`TankPresets.matchByCapacity(80, 206.8)!.volumeLiters`); with no pressure it equals `80 * 28.3168 / 200`.
  - `attributeValueIn(hoseLengthDef, feet, 0.9144)` is `closeTo(36, 0.01)` (inches).
  - `attributeUnitLabel(gaugeDef, dual, l10n)` is `'Both'`.
- [ ] **Step 2: Run** `flutter test test/features/equipment/presentation/utils/equipment_attribute_item_units_test.dart`; expect compile FAIL.
- [ ] **Step 3: Implement** the file. Add `attr_unitDual` ("Both") to all 11 ARB files next to `attr_flagYes`, then `flutter gen-l10n`.
- [ ] **Step 4: Run** the test; expect PASS.
- [ ] **Step 5: Commit** `feat(equipment): resolve the unit an equipment number reads in`.

### Task 2: `value_unit` column, entity and repository

**Files:**
- Modify: `lib/core/database/tables/equipment_tables.dart` (EquipmentAttributes), `lib/core/database/database.dart:325` (version 368), `lib/core/database/migrations/ladder/rungs_v340_onward.dart`, `lib/core/database/migrations/before_open_child_columns.dart`
- Create: `lib/core/database/migrations/helpers/attribute_unit_migrations.dart` (part file, like `site_catalogue_id_migrations.dart`)
- Modify: `lib/features/equipment/domain/entities/equipment_attribute.dart`, `lib/features/equipment/data/repositories/equipment_repository_impl.dart` (`_mapAttributeRow`, `saveAttributes`), `lib/features/dive_log/data/repositories/dive_repository_impl.dart:10600`
- Regenerate: `lib/features/agent_access/data/resources/sql_column_notes.generated.dart` via `dart run tool/generate_sql_column_notes.dart`
- Test: `test/core/database/migration_v368_attribute_unit_test.dart`, `test/features/equipment/data/repositories/equipment_attribute_unit_test.dart`

**Interfaces:**
- Produces: `EquipmentAttribute.valueUnit` (`String?`, in props, `curated(...)` param, `copyWith(valueUnit:, clearValueUnit:)`); `bool get hasContent => hasValue || valueUnit != null`; `_assertAttributeValueUnitColumn()` extension method.

- [ ] **Step 1: Write failing tests**, modelled on `migration_v363_site_catalogue_id_test.dart`: v368 in `migrationVersions`, floor below 368; upgrading from 367 adds `value_unit` and leaves rows NULL. Repository: saving a curated `gauge_max_pressure_bar` with `valueNum: 275.79, valueUnit: 'psi'` reads back with `valueUnit == 'psi'`; saving one with `valueUnit: 'psi'` and no number keeps the row; changing only the unit counts as a change (row re-stamped, marked pending).
- [ ] **Step 2: Run** both tests; expect FAIL.
- [ ] **Step 3: Implement.** Column `TextColumn get valueUnit => text().nullable()();` with a `///` doc comment (the column notes generator reads it). Rung comment states nullable, no backfill, floor unchanged, re-asserted in beforeOpen. `saveAttributes` filters on `hasContent` and compares `valueUnit` in `unchanged`. Run `dart run build_runner build --delete-conflicting-outputs` unfiltered (never `--build-filter`).
- [ ] **Step 4: Run** the two tests plus `test/core/database/` migration tests matching `migration_v36*`; expect PASS.
- [ ] **Step 5: Commit** `feat(equipment): store a per-item unit on equipment attributes`.

### Task 3: Sync keeps a unit an older peer omits

**Files:**
- Test: `test/core/services/sync/attribute_value_unit_sync_test.dart` (model: `legacy_last_service_date_sync_test.dart`)
- Modify only if a test fails: `lib/core/services/sync/sync_data_serializer.dart` (`equipmentAttributes` cases)

**Interfaces:**
- Consumes: `EquipmentAttribute.valueUnit` from Task 2.

- [ ] **Step 1: Write failing tests**: a local gauge row with `value_unit = 'psi'`; apply a payload row for the same id with a newer clock and no `valueUnit` key (debugApplyPayload and debugApplyBaseFile); the unit stays `psi` and the number updates. A payload with `"valueUnit": null` clears it. A payload with `"valueUnit": "bar"` sets it.
- [ ] **Step 2: Run**; expect the omission cases to PASS already (`_withLocalForOmitted`, #2553) and confirm the base-file path. If any case fails, route that path through the same overlay.
- [ ] **Step 3: Commit** `test(sync): an older peer keeps an attribute's unit`.

### Task 4: Display in the item's unit

**Files:**
- Modify: `lib/features/equipment/presentation/utils/equipment_attribute_units.dart` (`formatAttributeValue`), `lib/features/equipment/presentation/pages/equipment_detail_page.dart` (both call sites pass `workingPressureBar: equipment.workingPressureBar`), `lib/features/cylinder_passports/presentation/widgets/passport_spec_card.dart`, `lib/features/cylinder_passports/presentation/utils/print_passport_labels.dart`
- Test: `test/features/equipment/presentation/utils/equipment_attribute_units_test.dart` (extend), the passport card and label tests that exist

**Interfaces:**
- Produces: `formatAttributeValue(attr, def, units, l10n, {double? workingPressureBar})`.
- Consumes: Task 1 helpers.

- [ ] **Step 1: Write failing tests**: gauge `275.79` with `valueUnit: 'psi'` and metric diver formats `'4000 psi'` (no grouping: `formatAttributeNumberForEditing` renders input-style text); `dual` with a metric diver formats `'300 bar / 4351 psi'`, imperial diver `'4351 psi / 300 bar'`; tank volume 11.1 L, 207 bar, imperial diver formats `'80 cuft'` (preset), no pressure formats with `'~'`; diluent cylinder 3 L, imperial diver formats `'3 L'`; untouched depth rating follows the diver. Passport card and labels show working pressure `'3000 psi'` for a cylinder whose `working_pressure_bar` row has `valueUnit: 'psi'`, for a metric diver.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement.** Number branch resolves the unit in force; gas volume delegates to `units.formatTankVolume`-equivalent text via `ratedCapacityCuft` (0 decimals, "~" without pressure); `dual` renders the diver's unit first. Passport card and labels format their two rows through `formatAttributeValue` with the item's attributes.
- [ ] **Step 4: Run** the tests; expect PASS.
- [ ] **Step 5: Commit** `feat(equipment): show an item's specs in its own units`.

### Task 5: Unit picker on the edit form

**Files:**
- Create: `lib/features/equipment/presentation/widgets/equipment_number_attribute_field.dart`
- Modify: `lib/features/equipment/presentation/widgets/equipment_attribute_form_section.dart` (number case delegates), `lib/features/equipment/presentation/pages/equipment_edit_page.dart:1247` (`hasContent`)
- Test: `test/features/equipment/presentation/widgets/equipment_number_attribute_field_test.dart`, extend `equipment_attribute_form_section_test.dart`

**Interfaces:**
- Produces: `EquipmentNumberAttributeField({required EquipmentAttributeDef def, required EquipmentAttribute? current, required UnitFormatter units, double? workingPressureBar, required void Function(EquipmentAttribute) onChanged, required VoidCallback onCleared, required EquipmentAttribute Function() base})`, a StatefulWidget owning a `TextEditingController`, keyed `ValueKey('attr-field-<key>')` as today; its picker keyed `ValueKey('attr-unit-<key>')`.
- Consumes: Task 1 helpers; the section passes `values[EquipmentAttrKeys.workingPressureBar]?.valueNum` as `workingPressureBar`.

- [ ] **Step 1: Write failing widget tests**:
  - A field with choices shows a compact dropdown suffix with the unit in force; the label has no "(bar)".
  - Typing `4000` with psi picked on a metric diver emits `valueNum closeTo(275.79, 0.01)`, `valueUnit: 'psi'`.
  - With `300` typed in bar, picking psi keeps the text `300` and emits `valueNum closeTo(20.68, 0.01)`, `valueUnit: 'psi'` (relabel).
  - Picking the diver's own unit still stores it (`valueUnit: 'bar'` for a metric diver).
  - Clearing the number with a unit set emits the attribute with `valueNum == null` and the unit kept (not `onCleared`); with no unit set it calls `onCleared`.
  - Gauge picker offers Both; with Both on a metric diver, typing 300 emits `valueNum 300`, `valueUnit: 'dual'`.
  - Tank volume in cu ft: `80` with `workingPressureBar: 206.8` emits the AL80 preset litres; rebuilding with `workingPressureBar` stepping 0.2, 2.07, 20.7, 206.8 (Review Focus 4) leaves the text `80` and the final emit equals the AL80 litres.
  - In a `de` locale, `7,5` kg relabelled to lbs keeps text `7,5` and emits `valueNum closeTo(3.402, 0.001)` (Review Focus 5).
  - Diluent cylinder shows no picker and reads litres for an imperial diver.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement.** Read numbers with `readNumber` (diver locale), seed with `formatRoundedForInput` (1 decimal; mass 2; litres per `tankVolumeLiterDecimals`). On `didUpdateWidget`, when `isCylinderGasVolume` and `workingPressureBar` changed and the text parses, re-emit the volume from the text. The edit page saves rows with `hasContent`.
- [ ] **Step 4: Run** both widget tests plus `test/features/equipment/presentation/pages/equipment_edit_page*`; expect PASS.
- [ ] **Step 5: Commit** `feat(equipment): pick the unit of each equipment number`.

### Task 6: Equipment CSV gas capacity

**Files:**
- Modify: `lib/core/services/export/csv/codec/csv_attribute_codec.dart` (`formatAttributePair`, `parseAttributePair`, `_toMetric`), `lib/core/services/export/csv/csv_equipment_writer.dart:99`, `lib/features/universal_import/data/parsers/submersion_csv/submersion_equipment_csv_parser.dart:125`
- Test: `test/core/services/export/csv/codec/csv_attribute_codec_test.dart` (extend), the equipment CSV round-trip test

**Interfaces:**
- Produces: `const cylinderGasCapacitySymbol = 'cuft gas'`; `formatAttributePair(attr, units, {double? workingPressureBar})`; `parseAttributePair(pair, {dateFormat, type, double? workingPressureBar})`.

- [ ] **Step 1: Write failing tests**: My units, imperial, tank 11.1 L at 206.8 bar writes `volume=80 cuft gas`; reading `volume=80 cuft gas` with `workingPressureBar: 206.8` gives the AL80 litres; reading the old `volume=0.392 cuft` still gives `closeTo(11.1, 0.03)` L; rebreather `diluent_cylinder=3 L` for an imperial diver; a full row round trip where `working_pressure` appears after `volume` in the cell still resolves (the parser pre-scans the working pressure).
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement.** The parser parses all pairs once to find `working_pressure_bar`, then passes it to each `parseAttributePair`.
- [ ] **Step 4: Run**; expect PASS.
- [ ] **Step 5: Commit** `feat(equipment): write cylinder volume as gas capacity in the CSV`.

### Task 7: Repair mis-saved cylinder volumes

**Files:**
- Create: `lib/core/database/cylinder_volume_repair.dart`
- Modify: `lib/core/database/migrations/helpers/attribute_unit_migrations.dart` (`_repairCylinderVolumeCubicFeet`, guarded by `_columnExists('equipment_attributes', 'value_num')`), `rungs_v340_onward.dart` (v368, after the column), `lib/core/database/change_log/change_log_rewrites.dart` (`'equipment_attributes.value_num': 368`, no value repair, since the rewrite depends on the key and item type), `lib/core/services/sync/sync_service.dart` (`_repairLegacyPeerRows`, notify `equipmentAttributes` when > 0)
- Test: `test/core/database/migration_v368_cylinder_volume_test.dart`, `test/core/services/sync/legacy_cylinder_volume_sync_test.dart`

**Interfaces:**
- Produces: `Future<int> repairCylinderVolumeCubicFeet(DatabaseConnectionUser db)`: selects curated `volume_l` rows above 80 on `equipment.type = 'tank'` with the item's `working_pressure_bar`, writes `volumeLitersFromCapacity(value_num / 28.3168, wp)` by id, stamps nothing, returns the count.

- [ ] **Step 1: Write failing tests**: 2265.3 L with 206.8 bar becomes the AL80 litres; 2265.3 L with no pressure becomes `closeTo(11.33, 0.01)`; 12 L and 50 L untouched; a non-tank `capacity_l` of 200 untouched; running twice changes nothing more; `updated_at` and `hlc` unchanged. Sync: applying a peer row of 2265.3 L repairs it (debugApplyPayload and debugApplyBaseFile).
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the two tests plus `test/core/database/migration_v358_dive_rating_scale_test.dart` and `test/features/change_log/`; expect PASS.
- [ ] **Step 5: Commit** `fix(equipment): repair cylinder volumes saved as water cubic feet`.

### Task 8: Agent access

**Files:**
- Modify: `lib/features/agent_access/data/documents/gear_documents.dart` (`value_unit`), `lib/features/agent_access/data/writes/families/equipment_item_rules.dart` (codec field `value_unit`, `attributeDocuments`, `attributeProblem`, the list-to-attributes builder), the agent schema docs that describe attribute fields
- Test: the existing equipment item write and gear document tests (extend)

**Interfaces:**
- Consumes: Task 1 `parseAttributeUnit`, `attributeUnitChoices`.

- [ ] **Step 1: Write failing tests**: gear document carries `value_unit`; a write without the `value_unit` key keeps the stored unit; an explicit null clears it; `value_unit: 'dual'` on `working_pressure_bar` is refused with a message naming the allowed values; a row with `value_unit: 'psi'` and no number is accepted on the gauge.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run**; expect PASS.
- [ ] **Step 5: Commit** `feat(agent-access): read and write an equipment attribute's unit`.

### Task 9: Whole-branch checks

- [ ] `dart format .`; `flutter analyze` (whole repo) clean.
- [ ] `flutter test test/architecture/ test/shared/` and every test file touched above; all PASS.
- [ ] Scan the diff for em-dashes (U+2014) and en-dashes used as punctuation.
