# Twin Set Gear Item Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a tank gear item be worn as a twin set, so its icon, the Equipment Set figure and the role picked for a dive follow from it (issue #4641).

**Architecture:** A new `twin_set` choice on the existing `worn_as` tank attribute. Readers: an item-aware icon helper, the figure composer's zone and doubles rules, the tank and transmitter editors' pick defaults, and the cylinder-from-tank proposal.

**Tech Stack:** Flutter, Riverpod, Drift attribute rows (no schema change), ARB l10n.

**Spec:** `docs/design/specs/2026-11-16-twin-set-gear-item-design.md`

## Global Constraints

- No schema bump: the mark is an `equipment_attributes` row (`worn_as` = `twin_set`).
- Classification keeps reading dive tank roles only (`backmountRoles`).
- A pick default never rewrites another dive and never unsets a role.
- New l10n key `attrChoice_worn_as_twin_set` in all 11 ARB files, reusing each locale's `enum_tankRole_twinSet` wording.
- No em-dashes anywhere; `dart format .` before each commit.

## Review Focus

- An item worn as a twin set that is also paired (#4242) on the dive date: the pairing question decides; "this cylinder" leaves Back Gas (Task 3 test).
- A dive tank already Twin Set, picking a twin set item: no change notification, role untouched (Task 3 test).
- An Equipment Set with a twin set item and a second back tank: the composer still draws one doubles piece, never two (Task 2 test).
- A dive whose linked tank role is Back Gas for a twin set item: the role wins, single tank drawn (Task 2 test).
- Making cylinders from mixed Twin Set and Back Gas tanks of one size: two proposals, not one (Task 4 test).

---

### Task 1: The choice key, its label and the item icon

**Files:**
- Modify: `lib/features/equipment/domain/constants/equipment_attribute_catalog.dart` (worn_as choiceKeys, constant)
- Modify: `lib/features/equipment/domain/entities/equipment_item.dart` (getter)
- Modify: `lib/features/equipment/presentation/utils/equipment_attribute_l10n.dart`
- Modify: `lib/features/equipment/presentation/utils/equipment_type_icon.dart`
- Modify: `lib/l10n/arb/app_*.arb` (11 files), then `flutter gen-l10n`
- Modify: item call sites of `equipmentTypeIcon(item.type)`: equipment_avatar, equipment_set_detail_page, set_equipment_checkbox_row, children_card, component_picker_sheet, equipment_picker_sheet, dive_gear_tree_view, bulk_gear_rows, refine_gas_equipment_group, nav_track_equipment_picker_sheet, trip_packed_item_row, gear_passport_header, diver_figure (tray)
- Test: `test/features/equipment/presentation/utils/equipment_item_icon_test.dart` (new), `test/features/equipment/domain/entities/equipment_item_twin_set_test.dart` (new)

**Interfaces:**
- Produces: `const String kWornAsTwinSet = 'twin_set';` (catalog file); `bool EquipmentItem.isWornAsTwinSet`; `IconData equipmentIconFor(EquipmentType type, {String? wornAs})`; `IconData equipmentItemIcon(EquipmentItem item)`.

- [ ] Step 1: tests. `isWornAsTwinSet` true for a tank with worn_as `twin_set`, false for `back`, unset, and a non-tank. `equipmentItemIcon` returns `SubmersionIcons.tankTwinSet` for that tank and `MdiIcons.divingScubaTank` for a back tank; `equipmentIconFor(EquipmentType.bcd, wornAs: 'twin_set')` is the BCD icon. Catalog: worn_as choiceKeys == `['back', 'twin_set', 'sidemount_left', 'sidemount_right', 'stage']`.
- [ ] Step 2: run, expect FAIL.
- [ ] Step 3: implement; add the ARB key (en: "Twin set") and the l10n switch arm; swap each item call site to `equipmentItemIcon` (figure tray: `equipmentIconFor(type, wornAs: attributes[wornAs])`).
- [ ] Step 4: run the new tests plus `figure_position_test.dart` (its "every worn_as choice has zones" test fails until Task 2), `flutter analyze`.
- [ ] Step 5: commit with Task 2.

### Task 2: The figure draws it as doubles

**Files:**
- Modify: `lib/features/equipment/figure/domain/figure_position.dart` (`wornAsZones`)
- Modify: `lib/features/equipment/figure/domain/figure_composer.dart` (`_mergeDoubles`)
- Test: `test/features/equipment/figure/domain/figure_position_test.dart`, `test/features/equipment/figure/domain/figure_composer_preference_test.dart`

**Interfaces:**
- Consumes: `kWornAsTwinSet`.

- [ ] Step 1: tests. `wornAsZones('twin_set') == [FigureZone.backTank]`. Composer: one tank worn as `twin_set`, no role: placed in backTank with pieceIds `['tank_doubles_back']`. Same tank with `tankRole: TankRole.backGas`: pieces are not doubles. Twin set tank plus a second `back` tank: exactly one placed item has `tank_doubles_back`, the other has no pieces.
- [ ] Step 2: run, expect FAIL.
- [ ] Step 3: in `_mergeDoubles`, a single back tank is doubles when `tankRole == twinSet`, or `tankRole == null` and `attributes[wornAs] == kWornAsTwinSet`.
- [ ] Step 4: run both files, PASS.
- [ ] Step 5: commit `feat(equipment): mark a tank item as worn as a twin set`.

### Task 3: Picking it sets the Twin Set role

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/tank_editor.dart` (`_useOwnCylinder`)
- Modify: `lib/features/transmitters/presentation/pages/transmitter_edit_page.dart` (role default)
- Test: `test/features/dive_log/presentation/widgets/tank_editor_own_cylinder_test.dart`, the transmitter edit page test that covers suit inflation

**Interfaces:**
- Consumes: `EquipmentItem.isWornAsTwinSet`.

- [ ] Step 1: tests, modelled on "a cylinder marked for suit inflation sets the role (#4243)": a twin set item sets `TankRole.twinSet`; a tank already Twin Set stays Twin Set; a paired twin set item where the dialog answers "this cylinder" ends Back Gas; transmitter page picks Twin Set for a twin set item when Role was not touched.
- [ ] Step 2: run, expect FAIL.
- [ ] Step 3: next to the suit inflation default, `else if (item.isWornAsTwinSet && _role != TankRole.twinSet)` sets Twin Set; it runs only after the pairing question returned "this cylinder" or there is no pair, so in the paired case skip it when a pair was offered. Transmitter page: `else if (item.isWornAsTwinSet) role = TankRole.twinSet`.
- [ ] Step 4: run, PASS.
- [ ] Step 5: commit `feat(dive-log): picking a twin set gear item sets the Twin Set role`.

### Task 4: A cylinder made from a Twin Set tank is worn as a twin set

**Files:**
- Modify: `lib/features/equipment/domain/services/cylinder_spec_attributes.dart` (`twinSet` param)
- Modify: `lib/features/equipment/domain/services/tank_cylinder_matching.dart` (`CylinderProposal.twinSet`, `_sameRow`)
- Modify: `lib/features/equipment/data/services/cylinder_from_tank_service.dart`
- Test: `test/features/equipment/domain/services/cylinder_spec_attributes_test.dart`, `test/features/equipment/domain/services/tank_cylinder_matching_test.dart`

- [ ] Step 1: tests. `cylinderSpecAttributes(twinSet: true)` holds a worn_as `twin_set` row; `proposeCylinders` with a 24 L Twin Set tank and a 24 L Back Gas tank gives two proposals, the Twin Set one with `twinSet: true`.
- [ ] Step 2: run, expect FAIL.
- [ ] Step 3: implement; the service passes `twinSet: proposal.twinSet`.
- [ ] Step 4: run, PASS, plus `test/architecture/`.
- [ ] Step 5: commit `feat(equipment): a cylinder made from a Twin Set tank is worn as a twin set`.

### Task 5: Hide the pairing card for a twin set item

**Files:**
- Modify: `lib/features/cylinder_passports/presentation/widgets/twin_set_card.dart`
- Test: `test/features/cylinder_passports/presentation/widgets/twin_set_card_test.dart`

- [ ] Step 1: tests. A cylinder worn as `twin_set` with no pairings renders nothing (no `twinSet_title` text); with a past pairing it still renders the card.
- [ ] Step 2: run, expect FAIL.
- [ ] Step 3: in `build`, return `SizedBox.shrink()` when `cylinder.isWornAsTwinSet && pairings.isEmpty`.
- [ ] Step 4: run, PASS.
- [ ] Step 5: commit `feat(cylinder-passports): hide the pairing card for a twin set item`.
