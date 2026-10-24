# Several Regulators on One Tank Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a tank on a dive name any number of regulators, each counted the way the single tank regulator is (plus the dive counts and gear filters, which now see every tank regulator).

**Architecture:** `dive_tanks.regulator_equipment_id` stays the first regulator; a new nullable TEXT column `extra_regulator_ids` holds the rest as a JSON array. One Dart codec normalises the pair on every write, and one SQL helper file gives every raw-SQL reader the same "does this tank name this regulator" fragment (with `json_each`). The tank editor grows an "+ Add regulator" button and removable extra pickers.

**Tech Stack:** Flutter, Riverpod, Drift (SQLite, `json_each`), ARB l10n.

**Spec:** `docs/design/specs/2026-10-24-tank-extra-regulators-design.md`

## Global Constraints

- Schema: shipped as v312 (planned as v310 when main was at 309, renumbered after #3611 and #2151 took v310 and v311); additive nullable column, so `minimumCompatibleSchemaVersion` stays 308. Renumber again on merge if main moves.
- Never add a table or rung to `database.dart` beyond `currentSchemaVersion` and the `migrationVersions` entry; the rung goes in `migrations/ladder/rungs_v231_onward.dart`, the helper in `migrations/helpers/dive_migrations.dart`, the backstop in `migrations/before_open_table_backstops.dart` (`before_open.dart` is at the 800-line guard).
- Stored form of "no extras" is SQL NULL (never `[]`). The encoder returns null for an empty list; the decoder reads null, blank, `[]` and unreadable text as an empty list.
- Invariants on every write: no id twice, none equal to the first, no blank ids, and no extras while the first is null (the first extra is promoted).
- Every SQL read of `extra_regulator_ids` goes through `json_each` guarded by `json_valid`, so a bad value reads as no extras instead of failing the query.
- Copy (English): "Add regulator", "Regulator {number}", "Remove regulator", conflict field "Extra regulators". Translate into ar, de, es, fr, he, hu, it, nl, pt, zh.
- No em dashes anywhere. No mention of AI tools in commits or the PR.

## Review Focus

1. A tank whose first regulator is deleted while it has extras: the first extra must move up, not leave a null first with extras behind. (Task 6 test.)
2. The same regulator on two tanks of one dive: counted as one dive in the Dives row and gear filter. (Task 5 test.)
3. A malformed `extra_regulator_ids` value (a peer bug, hand-edited DB): every query still runs and treats it as empty. (Task 4 test.)
4. Promoting on None in the editor when extras exist: Regulator 2 becomes the first, and the saved tank has no duplicate. (Task 9 test.)
5. An extra regulator that is an assembly reaches its components' service clocks through `via_parent`, as the first does. (Task 4 test.)

---

### Task 1: Schema v312, the `extra_regulator_ids` column

**Files:**
- Modify: `lib/core/database/tables/dive_tables.dart` (after `regulatorEquipmentId`)
- Modify: `lib/core/database/database.dart` (`currentSchemaVersion`, `migrationVersions`)
- Modify: `lib/core/database/migrations/helpers/dive_migrations.dart`
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart`
- Modify: `lib/core/database/migrations/before_open_table_backstops.dart`
- Test: `test/core/database/migration_v312_tank_extra_regulators_test.dart`

**Interfaces:**
- Produces: Drift column `DiveTanks.extraRegulatorIds` (`TextColumn`, nullable), generated `DiveTank.extraRegulatorIds` (`String?`) and `DiveTanksCompanion.extraRegulatorIds`; helper `Future<void> _assertTankExtraRegulatorIds()` on `DiveMigrations`.

- [ ] **Step 1: Write the failing test** modelled on `migration_v309_media_document_tags_test.dart`: a raw v311 `dive_tanks` fixture (`id`, `dive_id`, `regulator_equipment_id`), then:
  - `'v312 is the current schema version and in the ladder'`: `currentSchemaVersion` >= 312, `migrationVersions` contains 312.
  - `'the floor does not move'`: `minimumCompatibleSchemaVersion` == 308.
  - `'upgrading from v311 adds the column and keeps the first regulator'`: after open, `PRAGMA table_info('dive_tanks')` has `extra_regulator_ids` (type TEXT, nullable) and the fixture row's `regulator_equipment_id` is unchanged, `extra_regulator_ids` IS NULL.
  - `'a database stamped v312 without the column heals in beforeOpen'`.
- [ ] **Step 2:** `flutter test test/core/database/migration_v312_tank_extra_regulators_test.dart`; expect FAIL (312 not in ladder).
- [ ] **Step 3: Implement.** Column doc comment: "v312: the regulators on this cylinder after the first (issue #3375), a JSON array of equipment ids; null means none. User-authored like [regulatorEquipmentId]; downloads and re-parses never write it." Helper is `_addColumnIfMissing('dive_tanks', 'extra_regulator_ids', 'TEXT')`. Rung `if (from < 312) { await _assertTankExtraRegulatorIds(); }` then `reportProgress()`, with a comment matching the v309 style. Add `312` to `migrationVersions` with a comment saying the column is additive and the floor stays. Backstop call in `_tableBackstopsFromV217`. Run codegen (`dart run build_runner b...` via the scratchpad script).
- [ ] **Step 4:** rerun the test, plus `test/core/database/migration_v309_media_document_tags_test.dart`; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-log): add dive_tanks.extra_regulator_ids (v312)`.

### Task 2: Domain, the regulator list on `DiveTank`

**Files:**
- Create: `lib/features/dive_log/domain/entities/tank_extra_regulators.dart`
- Modify: `lib/features/dive_log/domain/entities/dive.dart` (`DiveTank`)
- Test: `test/features/dive_log/domain/entities/tank_extra_regulators_test.dart`

**Interfaces:**
- Produces:
  - `List<String> decodeExtraRegulatorIds(String? text)`
  - `String? encodeExtraRegulatorIds(Iterable<String> ids)` (null when empty after normalising)
  - `({String? first, List<String> extras}) normalizeTankRegulators(String? first, Iterable<String> extras)`
  - `DiveTank.extraRegulatorIds` (`List<String>`, default `const []`), in the constructor, `copyWith(List<String>? extraRegulatorIds)` and `props`
  - `List<String> get DiveTank.regulatorIds` (first then extras)
  - `DiveTank DiveTank.withRegulators(List<String> ids)` (normalised; empty list clears both)

- [ ] **Step 1: Write the failing tests:**
  - decode: `null`, `''`, `'[]'`, `'not json'`, `'{"a":1}'` all give `[]`; `'["a","b"]'` gives `['a','b']`; non-strings in the array are dropped.
  - encode: `[]` gives `null`; `['a','a','']` gives `'["a"]'`.
  - normalize: `(null, ['a','b'])` gives `(first: 'a', extras: ['b'])`; `('a', ['a','b','b',''])` gives `(first: 'a', extras: ['b'])`; `(null, [])` gives `(first: null, extras: [])`.
  - `DiveTank(id: 't', regulatorEquipmentId: 'a', extraRegulatorIds: ['b']).regulatorIds == ['a','b']`.
  - `withRegulators(['b','c'])` gives first `'b'`, extras `['c']`; `withRegulators([])` gives first null, extras `[]`.
  - `copyWith(clearRegulatorEquipmentId: true)` keeps the extras untouched (normalising is the repository's job, so promotion is not silent here).
  - equality: two tanks differing only in extras are not equal.
- [ ] **Step 2:** run, expect FAIL (file missing).
- [ ] **Step 3: Implement.** Decoder mirrors `decodeSharedComputerIds` but never returns null. `withRegulators` calls `normalizeTankRegulators(null, ids)` and sets both fields through `copyWith` (with `clearRegulatorEquipmentId` when first is null).
- [ ] **Step 4:** run, expect PASS.
- [ ] **Step 5: Commit** `feat(dive-log): carry extra regulators on DiveTank`.

### Task 3: Write, read and rebuild paths

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (create ~1904, update branch ~2243, insert branch ~2284, row mappers ~4304/~4760, `_tankCompanion` ~7327)
- Modify: `lib/features/dive_log/data/services/bulk_dive_edit_service.dart` (`_tanksFromRows` ~398)
- Modify: `lib/features/dive_log/domain/services/sequential_tank_merge.dart` (`_fold` ~179)
- Modify: `lib/features/dive_planner/presentation/widgets/plan_tank_list.dart` (~714)
- Test: `test/features/dive_log/data/repositories/dive_tank_regulator_link_test.dart` (extend), `test/features/dive_log/domain/services/sequential_tank_merge_test.dart` (extend; find the existing file by name first), a bulk-undo test next to the existing `bulk_dive_edit_service` tests

**Interfaces:**
- Consumes: Task 1 column, Task 2 codec and fields.
- Produces: every repository write stores `normalizeTankRegulators(t.regulatorEquipmentId, t.extraRegulatorIds)`; every read fills `extraRegulatorIds` via `decodeExtraRegulatorIds`.

- [ ] **Step 1: Write the failing tests** in `dive_tank_regulator_link_test.dart`:
  - `'extra regulators survive create, read and update'`: three regulators, tank with first `r1`, extras `[r2, r3]`; read back equal; `updateDive` with `startPressure: 200` keeps them; `withRegulators([r1])` clears extras.
  - `'a write normalises the list'`: create with first null, extras `[r2, r2, r3]`; read back first `r2`, extras `[r3]`; the stored column is `'["r3"]'`; with extras `[]` the stored column IS NULL (raw `customSelect`).
  - merge: folding an earlier half with `(r1, [r2])` and a later half with `(r3, [])` gives `(r1, [r2])`; earlier with no regulator takes the later half's whole list.
  - bulk undo: `_tanksFromRows` through the service's public undo path restores the extras (follow the existing test that covers `regulatorEquipmentId` there; if none exists, assert on the restored dive after a bulk tank replace and undo).
  - rental memory: in `rental_memory_resolver_test.dart`, next to `expect(copy.regulatorEquipmentId, isNull)`, a source tank with extras gives `copy.extraRegulatorIds` empty (it builds fresh tanks, so this should already pass; it pins the behaviour).
- Not touched, checked during planning: dive split, consolidation, re-import, re-parse and transmitter writes never copy `regulator_equipment_id` (they create rows without it or update other columns in place), so they need no extras either. Duplicate dive goes through the entity, which carries the field.
- [ ] **Step 2:** run, expect FAIL.
- [ ] **Step 3: Implement.** One private helper in the repository, `({Value<String?> first, Value<String?> extras}) _regulatorValues(domain.DiveTank t)`, used by all four companion sites so they cannot drift. Merge: `earlier.regulatorEquipmentId != null || earlier.extraRegulatorIds.isNotEmpty ? earlier.regulatorIds : later.regulatorIds`, applied with `withRegulators`. Planner: pass `extraRegulatorIds: original?.extraRegulatorIds ?? const []`.
- [ ] **Step 4:** run those tests plus `flutter test test/features/dive_log/data test/features/dive_log/domain`; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-log): store and carry extra tank regulators`.

### Task 4: One SQL fragment for "this tank's regulators", and its readers

**Files:**
- Create: `lib/features/equipment/data/repositories/tank_regulator_sql.dart`
- Modify: `lib/features/equipment/data/repositories/dive_gear_usage_sql.dart`
- Modify: `lib/features/equipment/data/repositories/equipment_repository_impl.dart` (single exposure query ~1183/~1208, batched ~1563/~1590)
- Modify: `lib/features/equipment/data/services/equipment_transfer_service.dart` (~155)
- Test: `test/features/equipment/data/repositories/tank_regulator_sql_test.dart`, extend `dive_gear_usage_sql_test.dart`, `exposure_samples_query_test.dart`, `item_exposures_batch_test.dart`, `equipment_transfer_kept_units_test.dart`

**Interfaces:**
- Produces (all return SQL text; arguments are SQL expressions, never user input):
  - `String tankExtraRegulatorsJson(String tank)` gives `CASE WHEN json_valid($tank.extra_regulator_ids) THEN $tank.extra_regulator_ids END`
  - `String tankNamesRegulatorSql(String tank, String id)` gives `($tank.regulator_equipment_id = $id OR EXISTS (SELECT 1 FROM json_each(<json>) WHERE value = $id))`
  - `String tankNamesAnyRegulatorSql(String tank, String inList)` (same with `IN ($inList)`)
  - `String tankRegulatorDiveIdsSql(String id)` gives a `SELECT dive_id` subquery of dives with a tank naming `$id` (first or extra)
  - `String tankRegulatorIdsOfDiveSql(String diveId)` gives a `SELECT` of every regulator id on the dive's tanks (first and extras)

- [ ] **Step 1: Write the failing tests.**
  - `tank_regulator_sql_test.dart` against a test DB: tanks with `(r1, '["r2"]')`, `(null, 'not json')`, `(r3, NULL)`; `tankNamesRegulatorSql('t', '?1')` matches `r1`, `r2`, `r3` rows and nothing for `r9`; the malformed row raises no error; `tankRegulatorIdsOfDiveSql` returns `{r1, r2}` for the first dive.
  - gear usage: a dive whose tank has extra `r2` yields a row `(dive, r2, 'tankRegulator')`.
  - exposure single: `getExposureSamplesForEquipment('r2')` returns the dive with the tank's `o2_percent` as contact O2.
  - exposure batched: the same through the owners query, and an extra regulator that is an assembly reaches a component through `via_parent` (owner `component` with `parentId: r2`).
  - transfer: the heir lookup finds a dive whose tank lists the item only as an extra.
- [ ] **Step 2:** run, expect FAIL.
- [ ] **Step 3: Implement.** Gear usage gains a branch `SELECT t.dive_id, j.value, 'tankRegulator' FROM dive_tanks t, json_each(<json>) j WHERE 1 = 1${where('t.dive_id')}`; update its doc and the variable fan-out in `gearUsageForDives` (240 x 5 still under 999; adjust the comment). Exposure queries replace `regulator_equipment_id = X` with `tankNamesRegulatorSql`. Transfer adds `OR ${tankNamesAnyRegulatorSql(...)}` with one more set of variables.
- [ ] **Step 4:** run the five test files and `flutter test test/features/equipment test/features/data_quality`; expect PASS.
- [ ] **Step 5: Measure** (spec requirement). Before Step 3, write a throwaway timing test (never committed) that builds 3,000 dives with 2 tanks each, half with one extra regulator, and 40 regulators, then times the public batched exposure call for all 40 (median of 5 runs). Run it once before Step 3 and once after Step 4. Record both numbers in the scratchpad for the PR body, then delete the test.
- [ ] **Step 6: Commit** `feat(equipment): count extra tank regulators toward usage and exposure`.

### Task 5: Dive counts and the gear filters see tank regulators

**Files:**
- Modify: `lib/features/equipment/data/repositories/equipment_repository_impl.dart` (`getDiveCountForEquipment` ~1097)
- Modify: `lib/features/dive_log/query/dive_query_entity.dart` (`kDiveGearJoinSql` and its doc)
- Modify: `lib/features/equipment/query/equipment_query_entity.dart` (`_gearDiveLink`, the `dives` relation)
- Test: extend `test/features/equipment/data/repositories/equipment_repository_test.dart`; the query-language tests that cover `gear` and equipment `dives` (find with `grep -rln "kDiveGearJoinSql\|'gear'" test/features/dive_log/query test/features/equipment/query`)

**Interfaces:**
- Consumes: Task 4 `tankRegulatorDiveIdsSql`, `tankRegulatorIdsOfDiveSql`.

- [ ] **Step 1: Write the failing tests:**
  - `getDiveCountForEquipment(r1)` counts a dive whose tank's first regulator is `r1` (1); `getDiveCountForEquipment(r2)` counts a dive where `r2` is an extra (1); `r1` on two tanks of one dive counts 1.
  - the dives `gear` relation (a compiled `gear[...]` query matching the regulator's name, as the existing tests do) returns the dive for a first and an extra regulator.
  - the equipment `dives` relation and the `_gearDiveLink`-based field return the regulator for that dive.
- [ ] **Step 2:** run, expect FAIL.
- [ ] **Step 3: Implement** with `OR d.id IN (${tankRegulatorDiveIdsSql('?1')})` and `UNION ${tankRegulatorIdsOfDiveSql('{from}.id')}` / `UNION ${tankRegulatorDiveIdsSql('{r}.id')}`; these are compile-time strings, so make the query-entity constants `final` if string interpolation of a function call forbids `const`. Keep each relation's `tables` list (`dive_equipment`, `dive_tanks`).
- [ ] **Step 4:** run those tests plus `flutter test test/features/dive_log/query test/features/equipment/query test/architecture`; expect PASS.
- [ ] **Step 5: Commit** `feat(equipment): count tank regulators in dive counts and gear filters`.

### Task 6: Deleting a regulator cleans the lists

**Files:**
- Modify: `lib/features/equipment/data/repositories/cylinder_gear_links.dart`
- Test: extend the existing test of `clearCylinderGearLinks` (find with `grep -rln clearCylinderGearLinks test`), and `test/features/divers/data/repositories/diver_delete_fk_sync_test.dart`

**Interfaces:**
- Consumes: Task 2 codec, Task 4 `tankNamesAnyRegulatorSql`.

- [ ] **Step 1: Write the failing tests:**
  - deleting `r2` (an extra) leaves `(r1, [r3])`, stamps the tank's hlc and marks the tank pending.
  - deleting `r1` (the first) from `(r1, [r2, r3])` leaves `(r2, [r3])` (Review Focus 1).
  - deleting `r1` and `r2` together from `(r1, [r2])` leaves `(null, null)`.
  - diver delete: a kept item's dive whose tank lists a deleted regulator as an extra is cleaned and staged (follow the existing `regulatorEquipmentId` case in that file).
- [ ] **Step 2:** run, expect FAIL.
- [ ] **Step 3: Implement.** Select tanks matching `equipment_id IN`, `regulator_equipment_id IN` or the extras (`tankNamesAnyRegulatorSql` via `customSelect`), then for each tank naming a deleted regulator compute `normalizeTankRegulators` over its list minus the deleted ids and write first and extras with the same `clearedAt` hlc; keep the existing `equipment_id` bulk update.
- [ ] **Step 4:** run, expect PASS.
- [ ] **Step 5: Commit** `feat(equipment): remove deleted regulators from tank lists`.

### Task 7: Preset prefill fills the whole list

**Files:**
- Modify: `lib/features/equipment/data/repositories/equipment_repository_impl.dart` (`getLastRegulatorForPreset` ~1674, renamed)
- Modify: `lib/features/dive_log/presentation/widgets/tank_editor.dart` (`_prefillRegulatorFor` ~1187)
- Test: `test/features/equipment/data/last_regulator_lookup_test.dart`

**Interfaces:**
- Produces: `Future<List<String>> getLastRegulatorsForPreset(String presetName)` replacing `getLastRegulatorForPreset` (update every caller and mock).

- [ ] **Step 1: Update the tests to the new name and add:** newest tank `(r1, [r2])` returns `['r1','r2']`; a retired `r2` is dropped (`['r1']`); a newest tank whose regulators are all retired falls back to the next newest tank, as today.
- [ ] **Step 2:** run, expect FAIL.
- [ ] **Step 3: Implement.** Select candidate tanks of the preset with `regulator_equipment_id IS NOT NULL`, newest first; load the in-kit regulator ids (same status test as today) once; return the first candidate's `regulatorIds` filtered to in-kit, skipping candidates that filter to empty. The editor applies the list with `withRegulators` only while the tank has no regulator.
- [ ] **Step 4:** run, expect PASS.
- [ ] **Step 5: Commit** `feat(equipment): prefill every regulator from the last use of a preset`.

### Task 8: Sync conflicts name the extra regulators

**Files:**
- Modify: `lib/features/settings/presentation/conflicts/catalogue/dive_log_fields.dart`
- Modify: `lib/core/services/sync/conflict_reference.dart`
- Modify: `lib/features/settings/presentation/widgets/conflict_reference_labels.dart`
- Modify: `lib/l10n/arb/app_*.arb` (key `settings_conflict_field_extraRegulatorIds`, next to `settings_conflict_field_sharedComputerIds` in each file)
- Test: `test/core/services/sync/conflict_reference_resolver_test.dart`, `test/features/settings/presentation/widgets/conflict_reference_labels_test.dart`, and the catalogue coverage tests

**Interfaces:**
- Produces: catalogue entry `'extraRegulatorIds': ConflictField((l) => l.settings_conflict_field_extraRegulatorIds, FieldKind.opaque)`; resolver map `static const _listTargets = {'extraRegulatorIds': 'equipment'}`.

- [ ] **Step 1: Write the failing tests:** resolving a `diveTanks` record with `extraRegulatorIds: '["r2","r3"]'` yields two references with `field: 'extraRegulatorIds'`, `targetType: 'equipment'` and the regulators' names; malformed text yields none; `conflictReferenceLabel` for that field is `settings_conflict_ref_regulator` ("Regulator"); the coverage tests pass with the new catalogue key.
- [ ] **Step 2:** run, expect FAIL.
- [ ] **Step 3: Implement.** In `resolve`, a field in `_listTargets` decodes its value with `decodeExtraRegulatorIds` and resolves each id with `_resolveOne`. Add the ARB key in all 11 locales (English "Extra regulators"), then `flutter gen-l10n`.
- [ ] **Step 4:** run those tests plus `flutter test test/features/settings/presentation/conflicts test/l10n`; expect PASS.
- [ ] **Step 5: Commit** `feat(settings): name extra tank regulators in sync conflicts`.

### Task 9: Tank editor, "+ Add regulator" and the extra pickers

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/tank_editor.dart` (state, `_buildRegulatorPicker`, `_buildTank` ~451/~480). If the file passes 800 lines with this, move the regulator section into `lib/features/dive_log/presentation/widgets/tank_regulator_pickers.dart`.
- Modify: `lib/l10n/arb/app_*.arb` (`diveLog_tank_addRegulator`, `diveLog_tank_regulatorNumbered` with `{number}` int placeholder, `diveLog_tank_removeRegulator`, after `diveLog_tank_regulatorShowLeftKit`)
- Test: `test/features/dive_log/presentation/widgets/tank_editor_regulator_test.dart` (extend)

**Interfaces:**
- Consumes: Task 2 `regulatorIds`/`withRegulators`, Task 7 `getLastRegulatorsForPreset`.
- Produces: keys `Key('tank-add-regulator')`, `Key('tank-regulator-picker-<n>')` for extras (n starting at 2), `Key('tank-remove-regulator-<n>')`.

- [ ] **Step 1: Write the failing widget tests** (existing `_pump` harness, three regulators `reg-a`, `reg-b`, `reg-c`):
  - no regulator: `tank-add-regulator` absent.
  - one regulator: tapping add shows "Regulator 2"; choosing `reg-b` reports `extraRegulatorIds == ['reg-b']`.
  - the extra picker does not offer `reg-a` (already the first).
  - remove on Regulator 2 reports `extraRegulatorIds == []`.
  - setting the first to None with extras `[reg-b, reg-c]` reports first `reg-b`, extras `['reg-c']` and shows "Regulator 2" holding `reg-c` (Review Focus 4).
  - an added picker left empty is not reported in `extraRegulatorIds`.
  - add hidden when every offered regulator is already chosen.
  - preset prefill with a lookup returning `['reg-a','reg-b']` shows both.
- [ ] **Step 2:** run, expect FAIL.
- [ ] **Step 3: Implement.** State: `List<String?> _regulatorIds` (first then extras; a null entry is a just-added empty picker). Built tank uses `withRegulators(_regulatorIds.whereType<String>().toList())`. Each extra picker reuses the first picker's option rules (spare, left kit, labels) with the other chosen ids excluded; no None item on extras (remove instead). Remove button is an `IconButton(Icons.close)` with the `diveLog_tank_removeRegulator` tooltip. Add the ARB keys in all 11 locales, then `flutter gen-l10n`.
- [ ] **Step 4:** run the file plus `tank_editor_trip_cylinder_test.dart` and every `test/features/dive_log/presentation/widgets/tank_editor*`; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-log): add and remove extra regulators in the tank editor`.

### Task 10: Whole-branch checks and screenshots

- [ ] `dart format .`, `flutter analyze` (no issues), `flutter test test/architecture test/shared`, then `flutter test test/core/database test/core/services/sync test/features/dive_log test/features/equipment test/features/settings test/features/divers test/features/data_quality test/features/dive_planner`; all green (gate on the `[E]` count in the log, not a tail).
- [ ] After screenshots with the throwaway golden harness (not committed): one regulator with the add button, and three regulators, at phone (390) and desktop (900) widths, saved as `03-tank-editor-after-phone.png`, `04-tank-editor-after.png`, `05-tank-editor-three-after-phone.png`, `06-tank-editor-three-after.png`; delete the harness and its goldens.
