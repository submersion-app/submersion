# Cylinder Terminology, Cylinder Search and Preset Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One word per language for the cylinder concept, equipment search that finds items by any type name and by cylinder synonyms, a "Manage presets" entry in the tank editor's preset field, and Duplicate on built-in presets.

**Architecture:** The rename edits ARB values only (keys, enums, tables and routes keep their names), plus the English Dart `displayName`s that feed exports. Search adds one `TextSearchExpansion` to `equipmentQueryEntity`, mirroring `kDiveTypeTranslatedTextSearch`, so the equipment list and Global Search both gain it. The preset features are small widget changes on `TankPresetDropdown`, `TankPresetsPage` and `TankPresetEditPage`.

**Tech Stack:** Flutter, Riverpod, go_router, Drift, gen-l10n ARB files (11 locales).

**Spec:** `docs/design/specs/2026-11-27-cylinder-terminology-design.md` (issue #5106, closes #800)

## Global Constraints

- English user-visible text says "cylinder" for the cylinder concept, never "tank" or "bottle", except the allowlist: `enum_profileEvent_suunto_tankPressureAlarm`, `enum_profileEvent_suunto_tankPressureNotification`, `enum_profileEvent_suunto_tankPressureWarning`, `media_perdixOverlay_labelTank`, and the new `equipment_searchWords_*` keys. ("Hydrotank" and "Bottlenose" do not match a word-boundary regex and need no entry.)
- Locale words: es botella, fr bloc, he בלון, pt cilindro, de Flasche, nl Fles; it bombola, hu palack, ar أسطوانة, zh 气瓶, ja タンク unchanged.
- Special English wording: `enum_equipmentType_tank` "Cylinder", `enum_equipmentType_tankBand` "Cylinder Band", `enum_tankRole_pony` "Pony", `trips_cylinders_bottle` "Cylinder {label}", `trips_cylinders_fill_bottle` and `settings_conflict_field_bottleLabel` "Cylinder number".
- No ARB key renames, no enum, table, column or route renames. Export column headers (`Tank Volume (L)` and kin) stay; exported enum values change.
- Every new ARB key goes in all 11 files; run `flutter gen-l10n` after ARB edits. Translations identical to English go in `test/l10n/kept_english_values.dart` if `arb_parity_test` asks.
- `app_en.arb` has compact one-line entries that `json.dumps` would reflow: edit ARB values line by line (replace the value of the exact `"key": ` line), never by load-and-dump. The other locale files round-trip, but use the same line edit.
- No em-dashes or en-dashes as punctuation anywhere. No attribution in commits.
- Run only the test files you change, by path; never a folder or the suite.

## Review Focus

1. A saved equipment search typed before the change ("AL80", `type = tank`) returns the same items after it: Task 1 asserts `type = tank` still parses and a name match is unchanged.
2. A one- or two-letter plain word must not suddenly match every type through the expansion more than the existing LIKE already does: Task 1 asserts a blank term yields no values and "zzz" none.
3. An older CSV export with type "Tank", "Tank Band" and role "Pony Bottle" re-imports to the same enums: Task 3 tests all three.
4. Choosing "Manage presets" must not change the tank's preset or mark the dive edited: Task 2 asserts `onPresetChanged` is not called.
5. A duplicated preset saves without the diver touching a field, and the built-in stays unchanged: Task 4 asserts both.

---

### Task 0: Before screenshots

Taken before any code changes, per the project's screenshot rules. Read the memory notes on macOS screenshots first (fresh DB via `SUBMERSION_DB_PATH`, installed app and other dev builds checked with `ps`, every step time-boxed, app killed by PID after).

- [ ] **Step 1:** Build this commit and capture: equipment list with a cylinder and its Type menu, dive editor cylinder card with the preset dropdown open, dive detail cylinders section, Settings > Tank Presets, equipment search for "tank" (no results today). Phone (430 wide) and desktop width for the dropdown. Save to the scratchpad as `<nn>-<screen>-before[-phone].png`.

### Task 1: Equipment type text search

**Files:**
- Create: `lib/features/equipment/query/equipment_type_text_search.dart`
- Modify: `lib/features/equipment/query/equipment_query_entity.dart` (add `textSearchExpansions`)
- Modify: all 11 `lib/l10n/arb/app_*.arb` (two new keys)
- Test: `test/features/equipment/query/equipment_type_text_search_test.dart` (new), `test/features/equipment/query/equipment_query_entity_test.dart`

**Interfaces:**
- Produces: `Set<String> equipmentTypeNamesMatching(String term)` (enum `.name`s) and `const kEquipmentTypeTextSearch = TextSearchExpansion(sql: '{r}.type IN ({values})', values: equipmentTypeNamesMatching)`.
- New ARB keys: `equipment_searchWords_cylinder` (en `"tank, bottle, stage, pony"`), `equipment_searchWords_tankBand` (en `"tank band, cam band"`). Each locale lists its own words, comma separated; the dropped label word goes in (es `tanque`, fr `bouteille`, he `מיכל`, pt `garrafa`, de and nl `tank`).

- [ ] **Step 1: Write the failing unit tests** in the new test file, mirroring `dive_type_text_search_test.dart`:
  - `'cylinder'`, `'Cylinder'`, `'tank'`, `'bottle'`, `'stage'`, `'pony'` each contain `'tank'` in the result.
  - `'Flasche'` and `'botella'` contain `'tank'`.
  - `'regulator'` contains `'regulator'`; `'bcd'` contains `'bcd'`.
  - `'cam band'` contains `'tankBand'`.
  - `''`, `'   '`, `'zzznope'`, `'%'` give an empty set.
- [ ] **Step 2: Run** `flutter test test/features/equipment/query/equipment_type_text_search_test.dart`. Expected: compile failure (file missing).
- [ ] **Step 3: Implement.** Build once, at load, a map from each `EquipmentType` to its folded words: `type.localizedName(l10n)` (from `equipment_enum_display.dart`) for every `AppLocalizations.supportedLocales`, plus the split, trimmed search words of the two new keys for `tank` and `tankBand`. Match with `foldForSearch(term.trim())` and `contains`, as `builtInDiveTypeIdsMatching` does. Add the ARB keys to all 11 files and run `flutter gen-l10n`. Add `textSearchExpansions: const [kEquipmentTypeTextSearch]` to `equipmentQueryEntity`.
- [ ] **Step 4: Add the SQL-level tests** to `equipment_query_entity_test.dart` using its existing setup (item `'tank'` has type `'cylinder'` there; add an item named `AL80` with type `'tank'`): plain text `tank` finds `AL80`; plain text `regulator` finds the regulators; `type = tank` still parses and finds `AL80`; plain text `AL80` still finds `AL80` only.
- [ ] **Step 5: Run** both test files. Expected: PASS.
- [ ] **Step 6: Commit** `feat(equipment): find equipment by type name and cylinder words`.

### Task 2: Manage presets in the preset dropdown

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/tank_preset_dropdown.dart`
- Modify: 11 ARB files (`diveLog_tank_managePresets`, en `"Manage presets"`)
- Test: `test/features/dive_log/presentation/widgets/tank_preset_dropdown_manage_test.dart` (new)

**Interfaces:**
- Produces: a `_ManageEntry` subtype of `_PresetChoice`, rendered last after a `DropdownMenuItem` divider-styled separator, keyed `Key('tank-preset-manage')`, icon `Icons.settings_outlined`. On choose: `setState(() => _generation++)` (so the field falls back to `presetName`) and `context.push('/tank-presets')`. Neither callback fires.

- [ ] **Step 1: Write the failing widget test** with a `GoRouter` whose `/tank-presets` route builds a `Text('presets-page')`: open the dropdown, tap `Key('tank-preset-manage')`, settle; expect `find.text('presets-page')`, expect `onPresetChanged` and `onCylinderChosen` never called; pop back and expect the field still shows the original preset label.
- [ ] **Step 2: Run it.** Expected: FAIL (no such key).
- [ ] **Step 3: Implement** as in Interfaces; add the ARB key in all locales; `flutter gen-l10n`.
- [ ] **Step 4: Run** the new test and `test/features/dive_log/presentation/widgets/tank_editor_preset_cylinders_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-log): manage presets from the cylinder preset field`.

### Task 3: Export names and import aliases

**Files:**
- Modify: `lib/core/constants/app_enums.dart` (`tankBand('Cylinder Band')`, `tank('Cylinder')`, `pony('Pony')`)
- Modify: the importer reading equipment types and tank roles by display name (`enumByDisplayName` callers in `lib/core/constants/enum_display_lookup.dart` and its CSV users)
- Test: the existing CSV equipment/dive round-trip test files that cover these enums (find with `grep -rln "Pony Bottle\|'Tank'" test/core/services/export`), plus a new case in `test/core/constants/enum_display_lookup_test.dart` (create if missing)

**Interfaces:**
- Produces: legacy aliases `{'tank band': EquipmentType.tankBand}` and `{'pony bottle': TankRole.pony}` honoured by the import lookup (a `legacyNames` map parameter or a per-enum table; builder's choice). `'Tank'` already resolves through the `.name` fallback.

- [ ] **Step 1: Write failing tests:** lookup of `'Tank'`, `'Tank Band'`, `'tank band'` resolve to `tank` and `tankBand`; `'Pony Bottle'` to `TankRole.pony`; `'Cylinder'`, `'Cylinder Band'`, `'Pony'` resolve too.
- [ ] **Step 2: Run.** Expected: the legacy cases fail once the display names change (change them first, then run).
- [ ] **Step 3: Implement** the aliases.
- [ ] **Step 4: Run** the lookup test and the round-trip tests found above; update any expected export cell that asserted the old English names.
- [ ] **Step 5: Commit** `feat(equipment): export cylinder names and keep reading the old ones`.

### Task 4: Duplicate a built-in preset

**Files:**
- Modify: `lib/core/router/app_router.dart` (`newTankPreset` route reads `state.uri.queryParameters['from']`)
- Modify: `lib/features/tank_presets/presentation/pages/tank_preset_edit_page.dart` (`TankPresetEditPage({this.presetId, this.duplicateFromId})`)
- Modify: `lib/features/tank_presets/presentation/pages/tank_presets_page.dart` (copy button on built-in rows)
- Modify: 11 ARB files: `tankPresets_duplicatePreset` (en `"Duplicate"`), `tankPresets_duplicateName` (en `"{name} (copy)"`, placeholder `name` String)
- Test: `test/features/tank_presets/presentation/pages/tank_presets_page_test.dart`, `tank_preset_edit_page_test.dart`

**Interfaces:**
- Produces: route `/tank-presets/new?from=<presetId>`; button `Key('tank-preset-duplicate-<preset.name>')`, `Icons.copy_outlined`, tooltip `tankPresets_duplicatePreset`, placed between the star and the show switch on built-in rows only.
- Behaviour: with `duplicateFromId`, the page loads the source like `_loadPreset` but leaves `_existingPreset` null, names the draft `tankPresets_duplicateName(<localized built-in name>)`, and the sitting opens on that filled form so Save works without an edit.

- [ ] **Step 1: Write failing tests:** presets page shows the duplicate button on AL80 and not on a custom preset, and tapping it pushes `/tank-presets/new?from=<al80 id>`; edit page with `duplicateFromId` shows "AL80 (copy)" and AL80's volume and pressure, Save is enabled immediately, saving creates a custom preset and the built-in is unchanged.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** Check how `RecordEditorHost.openEditor` takes its baseline; if an unchanged new record cannot save, open the sitting on the empty draft and fill after, so the filled form counts as the edit.
- [ ] **Step 4: Run** both test files. Expected: PASS.
- [ ] **Step 5: Commit** `feat(tank-presets): duplicate a built-in preset`.

### Task 5: English wording and the guard

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` (about 170 values and the `@` descriptions that define the word)
- Modify: user-visible English literals in Dart:
  - Swap the word in place (no app language available there, or an English fallback the UI replaces): `lib/features/planner/domain/services/plan_engine.dart` issue messages, `lib/features/dive_planner/data/services/plan_calculator_service.dart` 427 and 438, the `'Tank N'` fallbacks in `dive_repository_impl.dart`, `profile_markers_service.dart` (two) and `dive_gas_switch_sitting.dart`, `DiveField.tankCount` in `lib/core/constants/dive_field.dart`, `lib/features/settings/presentation/widgets/settings_list_content.dart` subtitle, `lib/core/constants/dive_detail_sections.dart` description.
  - Move into ARB: the weight prediction term labelled `'tank'` (`weight_prediction_card.dart` maps it like `'water'`; new key `tools_weight_cylinderTerm`, en `"Cylinders"`), and the gas consumption `Semantics` label in `gas_consumption_calculator.dart` (new keys `gasCalculators_consumption_semantics` with placeholders `volume`, `volumeSymbol`, `pressure`, `pressureSymbol`, and `gasCalculators_consumption_semanticsExceeds`, en `"Warning: exceeds cylinder capacity"`). Any further literal the guard's Dart sweep finds is handled by the same rule.
- Create: `test/l10n/english_cylinder_terminology_test.dart`
- Modify: widget and unit tests that find the old English text (find with `grep -rln` for each old value under `test/` and `integration_test/`)

- [ ] **Step 1: Write the guard test:** every non-`@` value in `app_en.arb` must not match `RegExp(r'\b(tanks?|bottles?)\b', caseSensitive: false)` unless its key is in the allowlist (Global Constraints). Second test in the same file: the special wordings above are exact.
- [ ] **Step 2: Run it.** Expected: FAIL listing about 170 keys.
- [ ] **Step 3: Rewrite** each listed English value by hand, keeping placeholders, plural and select syntax intact; then the Dart literals above; add the three new keys to all locales; `flutter gen-l10n`.
- [ ] **Step 4: Run** the guard, `test/l10n/arb_parity_test.dart`, `test/l10n/localization_test.dart`, and every test file updated for the new text. Expected: PASS.
- [ ] **Step 5: Commit** `feat(l10n): say cylinder everywhere in English`.

### Task 6: Other languages

**Files:** `lib/l10n/arb/app_{es,fr,he,pt,de,nl,it,hu,ar,zh,ja}.arb`

- [ ] **Step 1:** For each locale, list the values containing the dropped word(s) (es tanque, fr bouteille, he מיכל, pt garrafa, de and nl leftover Tank, ja/it/hu/ar/zh stragglers from the counts in the spec work) and the values whose English source changed in Task 5.
- [ ] **Step 2:** Rewrite each by hand with the locale's word, fixing gender and agreement (es la botella, fr le bloc, he בלון is masculine). Leave values where the dropped word means something else.
- [ ] **Step 3:** `flutter gen-l10n`; run `test/l10n/arb_parity_test.dart`, `test/l10n/arb_diacritics_test.dart`, `test/l10n/localization_test.dart`, and the locale terminology tests (`german_sac_terminology_test.dart`, `french_ndl_tts_terminology_test.dart`). Expected: PASS.
- [ ] **Step 4: Commit** `feat(l10n): one cylinder word per language`.

### Task 7: User guides and wrap-up

- [ ] **Step 1:** `grep -rn -i "\btank" docs/user` and update the labels the guides quote to the new English wording; mention the Manage presets entry and Duplicate where presets are described.
- [ ] **Step 2:** `dart format .`, `flutter analyze` (whole repo, no issues), and the architecture guards only if new `lib/` files fail the hook.
- [ ] **Step 3: Commit** `docs(user): cylinder wording and preset management`.
- [ ] **Step 4:** After screenshots of the Task 0 screens, same names with `after`.
