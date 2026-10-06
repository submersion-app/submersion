# CCR Equipment Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver record which rebreather was used on a dive, reuse named diluent/bailout cylinder configurations instead of re-entering them, and track rebreather-specific service clocks.

**Architecture:** Three independent phases. Phase 1 adds `EquipmentType.rebreather` plus a data-driven attribute catalog entry — no schema migration, because equipment attributes are KV rows in the existing `equipment_attributes` table. Phase 3 adds three built-in `ServiceKind` rows to the idempotent seed SQL; `ServiceDueEngine` already computes hours-based clocks and needs no changes. Phase 2 adds two new synced tables (`cylinder_configs`, `cylinder_config_items`) at schema v139, with a pure `CylinderConfigApplier` service that merges a configuration into a dive's cylinders without ever overwriting gas mixes.

**Tech Stack:** Flutter 3.x, Drift ORM (SQLite), Riverpod, go_router, `flutter_test`, `drift/native` in-memory databases for repository and migration tests.

**Spec:** `docs/superpowers/specs/2026-08-05-ccr-equipment-design.md`
**Issue:** [#804](https://github.com/submersion-app/submersion/issues/804)
**Worktree:** `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/feat-804-ccr-equipment`, branch `worktree-feat-804-ccr-equipment`

## Global Constraints

- **Run all commands from the worktree root.** Do not `cd` to the main checkout. Its `.dart_tool` and Drift codegen are separate and stale relative to this branch.
- **Never run bare `git stash` / `git stash pop`.** The stash stack is shared across worktrees. Use a temporary WIP commit instead.
- **`dart format .`** (whole project, not just changed files) must run before every commit. The pre-push hook runs `dart format --set-exit-if-changed`.
- **`flutter analyze`** must be clean. Never pipe it through `tail`/`head` — that masks the exit code. Infos are treated as fatal in CI.
- **No emojis** in code, comments, or documentation.
- **Immutability:** entities are `Equatable` with `copyWith`. Never mutate.
- **Units:** every displayed volume, pressure, depth, and mass routes through the existing `UnitFormatter` and respects the active diver's unit settings. Store metric internally.
- **Localization:** there are **11 ARB files** in `lib/l10n/arb/` (en + 10 others). Every new user-facing string needs a key in all 11, followed by `flutter gen-l10n` (or `flutter pub get`) to regenerate `app_localizations*.dart`.
- **Attribute keys, choice keys, and service-kind slugs are stable identifiers persisted in the database.** They are never translated and never renamed after merge.
- **Schema version:** Phase 2 claims **v139**. Before implementing Task 12, re-run `grep -n "currentSchemaVersion = " lib/core/database/database.dart` on a fresh merge of `origin/main`. Main was at 137 and PR #603 claimed 138 as of 2026-08-05. If main has advanced past 138, renumber to the next free value everywhere the number appears and relax any pre-existing exact-latest migration tripwire to `greaterThanOrEqualTo`.
- **Codegen:** after any change to `lib/core/database/database.dart`, run `dart run build_runner build --delete-conflicting-outputs`. Analyze will fail on undefined generated getters otherwise.
- **Commit messages:** no `Co-Authored-By` line, no Claude Code session URL, no generated-with attribution.

## Test code depth in this plan

Tasks carrying novel logic — the attribute catalog, the seed SQL, the merge
algorithm, the migration, the repository, the apply service — ship **complete
test bodies**. Write them as given.

Tasks 12, 13, 14, and 16 are registration and UI wiring against patterns
already established in this codebase. They list **named tests with their exact
assertions described**, plus a "read this file first" step naming the precedent
to copy. Write the bodies in the precedent file's style. If a precedent's
fixture helper is named differently from what this plan suggests, the
precedent wins — do not introduce a parallel helper.

## File structure

```
lib/core/constants/enums.dart                      EquipmentType.rebreather
lib/core/database/database.dart                    2 tables, v139 migration,
                                                   seed SQL hours column
lib/core/router/app_router.dart                    2 routes
lib/core/services/sync/                            2 entity registrations
lib/l10n/arb/app_*.arb  (11 files)                 ~35 new keys

lib/features/equipment/
  domain/constants/equipment_attribute_catalog.dart   rebreather attributes
  presentation/utils/equipment_attribute_l10n.dart    18 resolver arms
  presentation/widgets/service_clocks_card.dart       hours-source caption
  presentation/pages/equipment_detail_page.dart       mounts configs card

lib/features/cylinder_configs/                     NEW FEATURE
  domain/entities/cylinder_config.dart             the config
  domain/entities/cylinder_config_item.dart        one cylinder in it
  domain/services/cylinder_config_applier.dart     pure merge algorithm
  data/repositories/cylinder_config_repository.dart   persistence + sync
  data/services/cylinder_config_apply_service.dart    plan -> dive_tanks
  presentation/providers/cylinder_config_providers.dart
  presentation/pages/cylinder_config_list_page.dart
  presentation/pages/cylinder_config_edit_page.dart
  presentation/widgets/cylinder_config_item_editor.dart
  presentation/widgets/apply_configuration_menu.dart
  presentation/widgets/unit_configurations_card.dart

lib/features/dive_log/
  presentation/widgets/cylinders_card.dart         hosts the apply menu
```

The merge algorithm is deliberately isolated from persistence: the applier is
pure and exhaustively unit-tested, while the apply service only translates its
output into writes. That split is what makes the "never overwrite gas" rule
testable without a database fixture.

---

# Phase 1 — `EquipmentType.rebreather`

No schema migration. Tasks 1-4.

---

### Task 1: Add the `rebreather` equipment type

**Files:**
- Modify: `lib/core/constants/enums.dart:4-27` (the `EquipmentType` enum)
- Test: `test/features/equipment/domain/equipment_attribute_catalog_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `EquipmentType.rebreather`, whose `.name` serializes to the string `'rebreather'` in `equipment.type`, and whose `displayName` is `'Rebreather'`.

- [ ] **Step 1: Write the failing test**

Append to `test/features/equipment/domain/equipment_attribute_catalog_test.dart`:

```dart
  test('rebreather is a distinct equipment type with a stable name', () {
    expect(EquipmentType.values, contains(EquipmentType.rebreather));
    expect(EquipmentType.rebreather.name, 'rebreather');
    expect(EquipmentType.rebreather.displayName, 'Rebreather');
  });
```

If the file's existing imports do not already include it, add:

```dart
import 'package:submersion/core/constants/enums.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/equipment/domain/equipment_attribute_catalog_test.dart`
Expected: compile error, `The getter 'rebreather' isn't defined for the type 'EquipmentType'`.

- [ ] **Step 3: Add the enum value**

In `lib/core/constants/enums.dart`, insert `rebreather` after `tank` in the `EquipmentType` enum so related breathing-system types sit together:

```dart
enum EquipmentType {
  regulator('Regulator'),
  bcd('BCD'),
  wetsuit('Wetsuit'),
  drysuit('Drysuit'),
  fins('Fins'),
  mask('Mask'),
  computer('Dive Computer'),
  transmitter('Transmitter'),
  tank('Tank'),
  rebreather('Rebreather'),
  weights('Weights'),
  light('Light'),
  camera('Camera'),
  smb('SMB'),
  reel('Reel'),
  knife('Knife'),
  hood('Hood'),
  gloves('Gloves'),
  boots('Boots'),
  other('Other');

  final String displayName;
  const EquipmentType(this.displayName);
}
```

Do **not** reorder any existing value. `EquipmentType` values persist as raw strings in `equipment.type` (`lib/core/database/database.dart:872`), so ordinal position is not persisted, but several UI dropdowns iterate `EquipmentType.values` and reordering would silently reshuffle them.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/equipment/domain/equipment_attribute_catalog_test.dart`
Expected: PASS

- [ ] **Step 5: Verify nothing else broke**

Run: `flutter analyze`
Expected: no issues. Watch specifically for non-exhaustive `switch` warnings on `EquipmentType` — if any appear, they are real: add a `rebreather` arm to each reported switch before continuing.

Run: `flutter test test/features/equipment/`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
dart format .
git add -A
git commit -m "Add rebreather equipment type (#804)"
```

---

### Task 2: Add rebreather attributes to the catalog

**Files:**
- Modify: `lib/features/equipment/domain/constants/equipment_attribute_catalog.dart`
- Test: `test/features/equipment/domain/equipment_attribute_catalog_test.dart`

**Interfaces:**
- Consumes: `EquipmentType.rebreather` (Task 1).
- Produces: eight `EquipmentAttributeDef` entries reachable via `EquipmentAttributeCatalog.attributesFor(EquipmentType.rebreather)` and `EquipmentAttributeCatalog.defFor(key)`. Attribute keys: `unit_type`, `mount_configuration`, `scrubber_type`, `scrubber_duration_h`, `o2_cell_count`, `diluent_cylinder_l`, `o2_cylinder_l`, `depth_rating_m`.

- [ ] **Step 1: Write the failing test**

Append to `test/features/equipment/domain/equipment_attribute_catalog_test.dart`:

```dart
  group('rebreather attributes', () {
    test('exposes the curated rebreather keys plus the universal ones', () {
      final keys = EquipmentAttributeCatalog.attributesFor(
        EquipmentType.rebreather,
      ).map((d) => d.key).toList();

      expect(keys, [
        'unit_type',
        'mount_configuration',
        'scrubber_type',
        'scrubber_duration_h',
        'o2_cell_count',
        'diluent_cylinder_l',
        'o2_cylinder_l',
        'depth_rating_m',
        'buoyancy_kg',
        'dry_weight_kg',
      ]);
    });

    test('unit_type covers both CCR and SCR variants', () {
      final def = EquipmentAttributeCatalog.defFor('unit_type');
      expect(def, isNotNull);
      expect(def!.kind, AttributeKind.choice);
      expect(def.choiceKeys, [
        'eccr',
        'mccr',
        'hccr',
        'scr_cmf',
        'scr_pascr',
        'scr_escr',
      ]);
    });

    test('onboard cylinder attributes carry the volume dimension', () {
      for (final key in ['diluent_cylinder_l', 'o2_cylinder_l']) {
        final def = EquipmentAttributeCatalog.defFor(key);
        expect(def, isNotNull, reason: key);
        expect(def!.kind, AttributeKind.number, reason: key);
        expect(def.dimension, AttributeDimension.volumeL, reason: key);
      }
    });

    test('scrubber duration is dimensionless hours, not a unit-converted '
        'quantity', () {
      final def = EquipmentAttributeCatalog.defFor('scrubber_duration_h');
      expect(def!.kind, AttributeKind.number);
      expect(def.dimension, AttributeDimension.none);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/equipment/domain/equipment_attribute_catalog_test.dart`
Expected: FAIL — `attributesFor` returns only the two universal attributes, so the first expectation fails on list equality, and `defFor('unit_type')` returns null.

- [ ] **Step 3: Add the catalog entry**

In `lib/features/equipment/domain/constants/equipment_attribute_catalog.dart`, add a `rebreather` entry to the `_byType` map. Place it immediately after the `EquipmentType.tank` entry to mirror the enum ordering:

```dart
    EquipmentType.rebreather: [
      EquipmentAttributeDef(
        key: 'unit_type',
        kind: AttributeKind.choice,
        choiceKeys: [
          'eccr',
          'mccr',
          'hccr',
          'scr_cmf',
          'scr_pascr',
          'scr_escr',
        ],
      ),
      EquipmentAttributeDef(
        key: 'mount_configuration',
        kind: AttributeKind.choice,
        choiceKeys: ['back', 'chest', 'sidemount'],
      ),
      EquipmentAttributeDef(
        key: 'scrubber_type',
        kind: AttributeKind.choice,
        choiceKeys: ['axial', 'radial'],
      ),
      // Rated scrubber duration in hours. Dimensionless: hours are hours in
      // every market, so there is nothing for UnitFormatter to convert.
      EquipmentAttributeDef(
        key: 'scrubber_duration_h',
        kind: AttributeKind.number,
      ),
      EquipmentAttributeDef(key: 'o2_cell_count', kind: AttributeKind.number),
      EquipmentAttributeDef(
        key: 'diluent_cylinder_l',
        kind: AttributeKind.number,
        dimension: AttributeDimension.volumeL,
      ),
      EquipmentAttributeDef(
        key: 'o2_cylinder_l',
        kind: AttributeKind.number,
        dimension: AttributeDimension.volumeL,
      ),
      EquipmentAttributeDef(
        key: 'depth_rating_m',
        kind: AttributeKind.number,
        dimension: AttributeDimension.depthM,
      ),
    ],
```

Note that `depth_rating_m` is deliberately reused verbatim from the `camera` entry. It is the same concept with the same dimension, so it shares one label key and needs no new ARB entry. `_byKey` is built by folding over `_byType`, and later duplicates simply overwrite earlier identical ones, so no change is needed there.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/equipment/domain/equipment_attribute_catalog_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "Add rebreather attribute catalog entry (#804)"
```

---

### Task 3: Localize the rebreather attributes

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and the 10 sibling `app_*.arb` files
- Modify: `lib/features/equipment/presentation/utils/equipment_attribute_l10n.dart`
- Test: `test/features/equipment/domain/equipment_attribute_catalog_test.dart`

**Interfaces:**
- Consumes: the eight attribute keys and eleven choice keys from Task 2.
- Produces: `attributeLabel(l10n, key)` and `attributeChoiceLabel(l10n, key, option)` return real translations rather than falling back to the raw key.

Seven new label keys are needed. `depth_rating_m` already exists (`app_en.arb:13737`) and is reused.

- [ ] **Step 1: Write the failing test**

This test guards the invariant that matters: every curated key resolves to something other than itself. Append to `test/features/equipment/domain/equipment_attribute_catalog_test.dart`:

```dart
  testWidgets('every rebreather attribute and choice resolves to a label',
      (tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context)!;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final defs = EquipmentAttributeCatalog.attributesFor(
      EquipmentType.rebreather,
    );
    for (final def in defs) {
      expect(
        attributeLabel(l10n, def.key),
        isNot(def.key),
        reason: 'missing attrLabel_${def.key}',
      );
      for (final option in def.choiceKeys) {
        expect(
          attributeChoiceLabel(l10n, def.key, option),
          isNot(option),
          reason: 'missing attrChoice_${def.key}_$option',
        );
      }
    }
  });
```

Add these imports to the file if absent:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
```

Pinning `locale: const Locale('en')` on the `MaterialApp` is required. Without it the host locale leaks in and the test resolves against whatever locale the machine happens to have.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/equipment/domain/equipment_attribute_catalog_test.dart`
Expected: FAIL — `attributeLabel` falls through its switch to `_ => key`, so `attributeLabel(l10n, 'unit_type')` returns `'unit_type'`.

- [ ] **Step 3: Add the English ARB entries**

In `lib/l10n/arb/app_en.arb`, add after `"attrLabel_dry_weight_kg"`:

```json
  "attrLabel_unit_type": "Unit type",
  "attrLabel_mount_configuration": "Mount",
  "attrLabel_scrubber_type": "Scrubber type",
  "attrLabel_scrubber_duration_h": "Scrubber duration (h)",
  "attrLabel_o2_cell_count": "O2 cells",
  "attrLabel_diluent_cylinder_l": "Diluent cylinder",
  "attrLabel_o2_cylinder_l": "O2 cylinder",
  "attrChoice_unit_type_eccr": "Electronic CCR (eCCR)",
  "attrChoice_unit_type_mccr": "Manual CCR (mCCR)",
  "attrChoice_unit_type_hccr": "Hybrid CCR (hCCR)",
  "attrChoice_unit_type_scr_cmf": "SCR - constant mass flow",
  "attrChoice_unit_type_scr_pascr": "SCR - passive addition",
  "attrChoice_unit_type_scr_escr": "SCR - electronically controlled",
  "attrChoice_mount_configuration_back": "Back mount",
  "attrChoice_mount_configuration_chest": "Chest mount",
  "attrChoice_mount_configuration_sidemount": "Sidemount",
  "attrChoice_scrubber_type_axial": "Axial",
  "attrChoice_scrubber_type_radial": "Radial"
```

Match the surrounding style: these keys carry no `@` description entries.

- [ ] **Step 4: Translate into the other 10 locales**

Add the same 18 keys to every other `app_*.arb` file with real translations. Rules that matter:

- `eCCR`, `mCCR`, `hCCR`, `SCR`, `CCR` are international abbreviations. Keep them verbatim in every locale; translate only the surrounding words.
- `O2` stays `O2` everywhere.
- `app_ar.arb` and `app_he.arb` are RTL. Write natural RTL text; do not insert directional control characters.

Confirm the file count first:

```bash
ls lib/l10n/arb/*.arb | wc -l   # must print 11
```

- [ ] **Step 5: Add the resolver arms**

In `lib/features/equipment/presentation/utils/equipment_attribute_l10n.dart`, add to the `attributeLabel` switch, before the `_ => key` fallback:

```dart
  'unit_type' => l10n.attrLabel_unit_type,
  'mount_configuration' => l10n.attrLabel_mount_configuration,
  'scrubber_type' => l10n.attrLabel_scrubber_type,
  'scrubber_duration_h' => l10n.attrLabel_scrubber_duration_h,
  'o2_cell_count' => l10n.attrLabel_o2_cell_count,
  'diluent_cylinder_l' => l10n.attrLabel_diluent_cylinder_l,
  'o2_cylinder_l' => l10n.attrLabel_o2_cylinder_l,
```

And to the `attributeChoiceLabel` switch, before its fallback:

```dart
      'unit_type_eccr' => l10n.attrChoice_unit_type_eccr,
      'unit_type_mccr' => l10n.attrChoice_unit_type_mccr,
      'unit_type_hccr' => l10n.attrChoice_unit_type_hccr,
      'unit_type_scr_cmf' => l10n.attrChoice_unit_type_scr_cmf,
      'unit_type_scr_pascr' => l10n.attrChoice_unit_type_scr_pascr,
      'unit_type_scr_escr' => l10n.attrChoice_unit_type_scr_escr,
      'mount_configuration_back' => l10n.attrChoice_mount_configuration_back,
      'mount_configuration_chest' => l10n.attrChoice_mount_configuration_chest,
      'mount_configuration_sidemount' =>
        l10n.attrChoice_mount_configuration_sidemount,
      'scrubber_type_axial' => l10n.attrChoice_scrubber_type_axial,
      'scrubber_type_radial' => l10n.attrChoice_scrubber_type_radial,
```

`depth_rating_m` needs no new arm — it is already in the switch at line 31.

- [ ] **Step 6: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: `lib/l10n/arb/app_localizations*.dart` regenerate with the new getters.

Run this from the **worktree root**. Generated l10n written from the main checkout lands in the wrong tree.

- [ ] **Step 7: Run test to verify it passes**

Run: `flutter test test/features/equipment/domain/equipment_attribute_catalog_test.dart`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "Localize rebreather equipment attributes (#804)"
```

---

### Task 4: Verify the rebreather round-trips through the equipment UI

**Files:**
- Test: `test/features/equipment/data/equipment_attribute_repository_test.dart`

**Interfaces:**
- Consumes: `EquipmentType.rebreather`, the catalog entry, `EquipmentAttribute.curated`.
- Produces: nothing new. This task proves Phase 1 is genuinely usable before moving on.

The attribute methods live on `EquipmentRepository`
(`lib/features/equipment/data/repositories/equipment_repository_impl.dart`),
not on a separate attribute repository. The exact signatures are
`Future<void> saveAttributes(String equipmentId, List<EquipmentAttribute> desired)`
(line 815) and
`Future<List<EquipmentAttribute>> getAttributesForEquipment(String equipmentId)`
(line 782). Note that `saveAttributes` filters out attributes where
`hasValue` is false, so an attribute with neither `valueText` nor `valueNum`
is silently dropped by design.

- [ ] **Step 1: Write the test**

Append to `test/features/equipment/data/equipment_attribute_repository_test.dart`, following the fixture setup already used by the tests in that file:

```dart
  test('a rebreather item persists and reloads its curated attributes',
      () async {
    const equipmentId = 'rb-1';
    await repository.saveAttributes(equipmentId, [
      EquipmentAttribute.curated(
        equipmentId: equipmentId,
        key: 'unit_type',
        valueText: 'eccr',
      ),
      EquipmentAttribute.curated(
        equipmentId: equipmentId,
        key: 'scrubber_duration_h',
        valueNum: 3.0,
      ),
      EquipmentAttribute.curated(
        equipmentId: equipmentId,
        key: 'o2_cell_count',
        valueNum: 3,
      ),
    ]);

    final loaded = await repository.getAttributesForEquipment(equipmentId);
    final byKey = {for (final a in loaded) a.key: a};

    expect(byKey['unit_type']!.valueText, 'eccr');
    expect(byKey['scrubber_duration_h']!.valueNum, 3.0);
    expect(byKey['o2_cell_count']!.valueNum, 3);

    // Curated ids are deterministic so independent devices converge.
    expect(byKey['unit_type']!.id, 'attr_${equipmentId}_unit_type');
  });
```

If the existing tests in this file name the repository variable or setup helper differently, follow that file's conventions rather than introducing new ones. Read the top of the file first.

- [ ] **Step 2: Run the test**

Run: `flutter test test/features/equipment/data/equipment_attribute_repository_test.dart`
Expected: PASS immediately. Phase 1 added no storage code — the attribute table is type-agnostic, and this test proves it.

If it fails, the failure is real and belongs to Task 2's catalog wiring. Fix before continuing.

- [ ] **Step 3: Manual smoke check**

Run: `flutter run -d macos`

Verify by hand:
1. Equipment tab, add item, type dropdown offers **Rebreather**.
2. Selecting it shows the eight attribute fields with translated labels.
3. `Unit type` offers all six choices with readable names.
4. `Diluent cylinder` and `O2 cylinder` display in the diver's configured volume unit.
5. Save, reopen the item, values persist.

- [ ] **Step 4: Run the full equipment suite**

Run: `flutter test test/features/equipment/`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "Add rebreather attribute persistence test (#804)"
```

---

# Phase 3 — Rebreather service kinds

Depends on Phase 1 (needs `'rebreather'` for `applicable_types`). Tasks 5-7. Sequenced before Phase 2 because it is small, mechanical, and gated on Phase 1 alone.

---

### Task 5: Add an hours column to the built-in service kind seed

**Files:**
- Modify: `lib/core/database/database.dart:2113-2141` (`kSeedBuiltInServiceKindsSql`)
- Test: `test/core/database/service_ledger_schema_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `kSeedBuiltInServiceKindsSql` gains an `hours` column in its inline `SELECT`, so built-in kinds can carry a `default_interval_hours`.

The current SQL hardcodes `NULL` for `default_interval_hours` because no built-in has ever needed one. This task changes the shape without changing any existing kind's behavior — a pure refactor, verified by a test that pins the existing kinds first.

- [ ] **Step 1: Write the characterization test**

Append to `test/core/database/service_ledger_schema_test.dart`:

```dart
  test('existing built-in service kinds keep null hour intervals', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final rows = await db
        .customSelect(
          'SELECT id, default_interval_days, default_interval_dives, '
          'default_interval_hours FROM service_kinds WHERE is_built_in = 1',
        )
        .get();
    final byId = {for (final r in rows) r.read<String>('id'): r};

    expect(byId.keys, containsAll(<String>[
      'hydro',
      'vip',
      'o2-clean',
      'regulator-service',
      'computer-battery',
      'transmitter-battery',
      'bcd-inspection',
      'drysuit-seals',
      'general-service',
    ]));

    expect(byId['hydro']!.read<int?>('default_interval_days'), 1825);
    expect(byId['hydro']!.read<double?>('default_interval_hours'), isNull);
    expect(
      byId['regulator-service']!.read<int?>('default_interval_dives'),
      100,
    );
    expect(
      byId['general-service']!.read<int?>('default_interval_days'),
      isNull,
    );
  });
```

- [ ] **Step 2: Run test to verify it passes**

Run: `flutter test test/core/database/service_ledger_schema_test.dart`
Expected: PASS. This is a characterization test — it pins current behavior so the refactor in Step 3 cannot change it silently.

- [ ] **Step 3: Add the hours column to the seed SQL**

In `lib/core/database/database.dart`, replace `kSeedBuiltInServiceKindsSql` with:

```dart
/// Built-in service kinds: identical on every device, stable slug ids
/// (service_schedules.service_kind_id references them), INSERT OR IGNORE
/// so re-running is a no-op. Intervals per tech-diving convention.
const String kSeedBuiltInServiceKindsSql = '''
  INSERT OR IGNORE INTO service_kinds
    (id, diver_id, name, applicable_types, default_interval_days,
     default_interval_dives, default_interval_hours, auto_attach,
     is_built_in, created_at, updated_at)
  SELECT t.id, NULL, t.name, t.types, t.days, t.dives, t.hours, t.auto, 1,
         n.now_ms, n.now_ms
  FROM (
    SELECT 'hydro' AS id, 'Hydrostatic test' AS name, '["tank"]' AS types,
           1825 AS days, NULL AS dives, NULL AS hours, 1 AS auto
    UNION ALL SELECT 'vip', 'Visual inspection (VIP)', '["tank"]',
           365, NULL, NULL, 1
    UNION ALL SELECT 'o2-clean', 'O2 clean', '["tank"]', 365, NULL, NULL, 0
    UNION ALL SELECT 'regulator-service', 'Regulator service',
           '["regulator"]', 365, 100, NULL, 1
    UNION ALL SELECT 'computer-battery', 'Computer battery', '["computer"]',
           730, NULL, NULL, 1
    UNION ALL SELECT 'transmitter-battery', 'Transmitter battery',
           '["transmitter"]', 365, NULL, NULL, 1
    UNION ALL SELECT 'bcd-inspection', 'BCD/wing inspection', '["bcd"]',
           365, NULL, NULL, 1
    UNION ALL SELECT 'drysuit-seals', 'Drysuit seals', '["drysuit"]',
           730, NULL, NULL, 0
    UNION ALL SELECT 'general-service', 'General service', '[]',
           NULL, NULL, NULL, 0
  ) t
  CROSS JOIN (SELECT CAST(strftime('%s','now') AS INTEGER) * 1000 AS now_ms) n
''';
```

Every row gained an `hours` position between `dives` and `auto`. The first `SELECT` declares the column alias; the `UNION ALL` rows are positional. Getting the column count wrong on any single row is a SQLite error at seed time, which surfaces as a database that fails to open — so count them.

- [ ] **Step 4: Run test to verify it still passes**

Run: `flutter test test/core/database/service_ledger_schema_test.dart`
Expected: PASS, unchanged. If any assertion now fails, a positional column slipped.

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "Allow built-in service kinds to declare hour intervals (#804)"
```

---

### Task 6: Seed the three rebreather service kinds

**Files:**
- Modify: `lib/core/database/database.dart` (`kSeedBuiltInServiceKindsSql`)
- Test: `test/core/database/service_ledger_schema_test.dart`

**Interfaces:**
- Consumes: the `hours` column from Task 5; `'rebreather'` from Task 1.
- Produces: built-in service kind slugs `scrubber-repack`, `o2-cell-replacement`, `rebreather-annual`, all with `applicable_types = '["rebreather"]'` and `auto_attach = 1`.

- [ ] **Step 1: Write the failing test**

Append to `test/core/database/service_ledger_schema_test.dart`:

```dart
  test('rebreather built-in service kinds seed with the expected clocks',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final rows = await db
        .customSelect(
          "SELECT id, name, applicable_types, default_interval_days, "
          "default_interval_hours, auto_attach FROM service_kinds "
          "WHERE id IN ('scrubber-repack', 'o2-cell-replacement', "
          "'rebreather-annual')",
        )
        .get();
    final byId = {for (final r in rows) r.read<String>('id'): r};

    expect(byId.length, 3);

    final scrubber = byId['scrubber-repack']!;
    expect(scrubber.read<double?>('default_interval_hours'), 3.0);
    expect(scrubber.read<int?>('default_interval_days'), isNull);
    expect(scrubber.read<int>('auto_attach'), 1);

    final cells = byId['o2-cell-replacement']!;
    expect(cells.read<int?>('default_interval_days'), 365);
    expect(cells.read<double?>('default_interval_hours'), isNull);

    final annual = byId['rebreather-annual']!;
    expect(annual.read<int?>('default_interval_days'), 365);

    for (final row in byId.values) {
      expect(row.read<String>('applicable_types'), '["rebreather"]');
    }
  });

  test('re-running the built-in seed is a no-op', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await db.customStatement(kSeedBuiltInServiceKindsSql);
    await db.customStatement(kSeedBuiltInServiceKindsSql);

    final count = await db
        .customSelect(
          "SELECT COUNT(*) AS c FROM service_kinds "
          "WHERE id = 'scrubber-repack'",
        )
        .getSingle();
    expect(count.read<int>('c'), 1);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/database/service_ledger_schema_test.dart`
Expected: FAIL — `expect(byId.length, 3)` gets 0.

- [ ] **Step 3: Add the three rows**

In `kSeedBuiltInServiceKindsSql`, insert before the `general-service` row so the catch-all stays last:

```sql
    UNION ALL SELECT 'scrubber-repack', 'Scrubber repack', '["rebreather"]',
           NULL, NULL, 3.0, 1
    UNION ALL SELECT 'o2-cell-replacement', 'O2 cell replacement',
           '["rebreather"]', 365, NULL, NULL, 1
    UNION ALL SELECT 'rebreather-annual', 'Rebreather annual service',
           '["rebreather"]', 365, NULL, NULL, 1
```

The column order is `id, name, types, days, dives, hours, auto`. Scrubber repack is hours-only: a scrubber is consumed by loop time, not by the calendar.

3.0 hours is a deliberately conservative default across the 2-6 hour range real units are rated for. The diver overrides it per unit on the schedule, which is exactly what `ServiceSchedule.intervalHours` is for.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/database/service_ledger_schema_test.dart`
Expected: PASS

- [ ] **Step 5: Verify existing databases pick the kinds up**

The seed already runs from both `onCreate` (`database.dart:4169`) and the v122 `beforeOpen` backstop (`database.dart:3675`), and `INSERT OR IGNORE` makes it idempotent. No new migration is needed. Prove it against an upgraded database:

```dart
  test('a database created before the rebreather kinds gains them on reopen',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await db.customStatement(
      "DELETE FROM service_kinds WHERE id = 'scrubber-repack'",
    );
    expect(
      (await db
              .customSelect(
                "SELECT COUNT(*) AS c FROM service_kinds "
                "WHERE id = 'scrubber-repack'",
              )
              .getSingle())
          .read<int>('c'),
      0,
    );

    await db.customStatement(kSeedBuiltInServiceKindsSql);

    expect(
      (await db
              .customSelect(
                "SELECT COUNT(*) AS c FROM service_kinds "
                "WHERE id = 'scrubber-repack'",
              )
              .getSingle())
          .read<int>('c'),
      1,
    );
  });
```

Run: `flutter test test/core/database/service_ledger_schema_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "Seed rebreather service kinds for scrubber, cells, and annual (#804)"
```

---

### Task 7: Document the loop-time approximation in the UI

**Files:**
- Modify: `lib/features/equipment/presentation/widgets/service_clocks_card.dart`
- Modify: all 11 `lib/l10n/arb/app_*.arb` files
- Test: `test/features/equipment/presentation/` (add `service_clocks_hours_caption_test.dart`)

**Interfaces:**
- Consumes: the `scrubber-repack` kind from Task 6.
- Produces: a caption on hours-based clocks reading "Counted from logged dive time" (English).

`ServiceDueEngine` sums dive **duration** for hours-based clocks (`service_due_engine.dart:59-61`). That approximates rebreather loop time but excludes pre-breathe and surface loop time. A diver trusting a scrubber clock deserves to know what it counts.

- [ ] **Step 1: Read the widget first**

Run: `cat lib/features/equipment/presentation/widgets/service_clocks_card.dart`

Find where an hours-based `ServiceClockStatus` renders its remaining value. Match the file's existing text style and theme usage rather than inventing new patterns.

- [ ] **Step 2: Write the failing test**

Create `test/features/equipment/presentation/service_clocks_hours_caption_test.dart`. Build the widget with one hours-based clock and one days-based clock, then assert:

```dart
    expect(find.text('Counted from logged dive time'), findsOneWidget);
```

Construct the fixture with a `ServiceSchedule` carrying `intervalHours: 3.0` and a `ServiceKind` with `id: 'scrubber-repack'`. Pin `locale: const Locale('en')` on the host `MaterialApp` — an unpinned locale makes this test machine-dependent.

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/equipment/presentation/service_clocks_hours_caption_test.dart`
Expected: FAIL — `findsNothing` where one widget was expected.

- [ ] **Step 4: Add the ARB key**

To `lib/l10n/arb/app_en.arb`:

```json
  "serviceClockHoursSource": "Counted from logged dive time"
```

Translate into the other 10 ARB files, then run `flutter gen-l10n`.

- [ ] **Step 5: Render the caption**

In `service_clocks_card.dart`, show `l10n.serviceClockHoursSource` beneath the remaining-hours figure, only when the clock's effective interval is hours-based. Use the same muted caption treatment the file already uses for secondary text.

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/features/equipment/presentation/service_clocks_hours_caption_test.dart`
Expected: PASS

- [ ] **Step 7: Run the full equipment suite**

Run: `flutter test test/features/equipment/`
Expected: all pass. If other widget tests in this directory now fail on text-finder counts, they are asserting against the card's rendered text and need their expectations updated — a known consequence of adding text to a shared widget.

- [ ] **Step 8: Commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "Caption hours-based service clocks with their data source (#804)"
```

---

# Phase 2 — Cylinder configurations

Schema v139. Tasks 8-16. The largest phase; depends on Phase 1 only for the optional owning-unit link.

---

### Task 8: Domain entities

**Files:**
- Create: `lib/features/cylinder_configs/domain/entities/cylinder_config.dart`
- Create: `lib/features/cylinder_configs/domain/entities/cylinder_config_item.dart`
- Test: `test/features/cylinder_configs/domain/entities/cylinder_config_test.dart`

**Interfaces:**
- Consumes: `TankRole` and `TankMaterial` from `lib/core/constants/enums.dart`.
- Produces:
  - `CylinderConfig({required String id, String? diverId, String? equipmentId, required String name, String description = '', int sortOrder = 0, List<CylinderConfigItem> items = const [], required DateTime createdAt, required DateTime updatedAt})` with `copyWith` and `bool get isOwnedByUnit`.
  - `CylinderConfigItem({required String id, required String configId, int sortOrder = 0, String? label, required TankRole tankRole, double? volumeL, double? workingPressureBar, TankMaterial? tankMaterial, double o2Percent = 21, double hePercent = 0, double? defaultStartPressureBar, required DateTime createdAt, required DateTime updatedAt})` with `copyWith`.

- [ ] **Step 1: Write the failing test**

Create `test/features/cylinder_configs/domain/entities/cylinder_config_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';

void main() {
  final now = DateTime.utc(2026, 8, 5);

  CylinderConfigItem item({
    String id = 'i1',
    TankRole role = TankRole.bailout,
    double o2 = 21,
  }) => CylinderConfigItem(
    id: id,
    configId: 'c1',
    tankRole: role,
    o2Percent: o2,
    createdAt: now,
    updatedAt: now,
  );

  test('a config with an equipmentId is owned by a unit', () {
    final owned = CylinderConfig(
      id: 'c1',
      name: 'JJ trimix',
      equipmentId: 'rb-1',
      createdAt: now,
      updatedAt: now,
    );
    expect(owned.isOwnedByUnit, isTrue);

    final generic = owned.copyWith(clearEquipmentId: true);
    expect(generic.isOwnedByUnit, isFalse);
    expect(generic.name, 'JJ trimix');
  });

  test('items default to air and back gas is not assumed', () {
    final i = item();
    expect(i.o2Percent, 21);
    expect(i.hePercent, 0);
    expect(i.tankRole, TankRole.bailout);
    expect(i.volumeL, isNull);
    expect(i.tankMaterial, isNull);
  });

  test('equality is by value, so provider rebuilds are stable', () {
    expect(item(), equals(item()));
    expect(item(o2: 32), isNot(equals(item())));
  });

  test('copyWith replaces the item list wholesale', () {
    final config = CylinderConfig(
      id: 'c1',
      name: 'Doubles + 50',
      createdAt: now,
      updatedAt: now,
      items: [item(id: 'a')],
    );
    final updated = config.copyWith(items: [item(id: 'a'), item(id: 'b')]);
    expect(config.items.length, 1);
    expect(updated.items.length, 2);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/cylinder_configs/domain/entities/cylinder_config_test.dart`
Expected: FAIL — the files do not exist.

- [ ] **Step 3: Write the entities**

Create `lib/features/cylinder_configs/domain/entities/cylinder_config_item.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// One cylinder in a reusable configuration. The cylinder spec is a snapshot,
/// not a reference: a tank preset may populate volume/pressure/material at
/// edit time, but the config then owns those values. A configuration records
/// what the diver actually dives, so later edits to a preset must not rewrite
/// its meaning.
class CylinderConfigItem extends Equatable {
  final String id;
  final String configId;
  final int sortOrder;

  /// Free-text label such as "Bailout 1" or "AL80 EAN50". Maps to
  /// dive_tanks.tank_name when applied.
  final String? label;

  final TankRole tankRole;
  final double? volumeL;
  final double? workingPressureBar;
  final TankMaterial? tankMaterial;
  final double o2Percent;
  final double hePercent;
  final double? defaultStartPressureBar;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CylinderConfigItem({
    required this.id,
    required this.configId,
    this.sortOrder = 0,
    this.label,
    required this.tankRole,
    this.volumeL,
    this.workingPressureBar,
    this.tankMaterial,
    this.o2Percent = 21,
    this.hePercent = 0,
    this.defaultStartPressureBar,
    required this.createdAt,
    required this.updatedAt,
  });

  CylinderConfigItem copyWith({
    String? id,
    String? configId,
    int? sortOrder,
    String? label,
    bool clearLabel = false,
    TankRole? tankRole,
    double? volumeL,
    bool clearVolumeL = false,
    double? workingPressureBar,
    bool clearWorkingPressureBar = false,
    TankMaterial? tankMaterial,
    bool clearTankMaterial = false,
    double? o2Percent,
    double? hePercent,
    double? defaultStartPressureBar,
    bool clearDefaultStartPressureBar = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CylinderConfigItem(
    id: id ?? this.id,
    configId: configId ?? this.configId,
    sortOrder: sortOrder ?? this.sortOrder,
    label: clearLabel ? null : (label ?? this.label),
    tankRole: tankRole ?? this.tankRole,
    volumeL: clearVolumeL ? null : (volumeL ?? this.volumeL),
    workingPressureBar: clearWorkingPressureBar
        ? null
        : (workingPressureBar ?? this.workingPressureBar),
    tankMaterial: clearTankMaterial
        ? null
        : (tankMaterial ?? this.tankMaterial),
    o2Percent: o2Percent ?? this.o2Percent,
    hePercent: hePercent ?? this.hePercent,
    defaultStartPressureBar: clearDefaultStartPressureBar
        ? null
        : (defaultStartPressureBar ?? this.defaultStartPressureBar),
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  List<Object?> get props => [
    id,
    configId,
    sortOrder,
    label,
    tankRole,
    volumeL,
    workingPressureBar,
    tankMaterial,
    o2Percent,
    hePercent,
    defaultStartPressureBar,
  ];
}
```

Create `lib/features/cylinder_configs/domain/entities/cylinder_config.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';

/// A named, reusable set of cylinders. When [equipmentId] is set the config
/// reads as "a configuration for this rebreather"; when null it is a generic
/// gas plan any dive can use. Deleting the owning unit sets the column null
/// rather than cascading, demoting the config instead of destroying it.
class CylinderConfig extends Equatable {
  final String id;
  final String? diverId;
  final String? equipmentId;
  final String name;
  final String description;
  final int sortOrder;
  final List<CylinderConfigItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CylinderConfig({
    required this.id,
    this.diverId,
    this.equipmentId,
    required this.name,
    this.description = '',
    this.sortOrder = 0,
    this.items = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOwnedByUnit => equipmentId != null;

  CylinderConfig copyWith({
    String? id,
    String? diverId,
    bool clearDiverId = false,
    String? equipmentId,
    bool clearEquipmentId = false,
    String? name,
    String? description,
    int? sortOrder,
    List<CylinderConfigItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CylinderConfig(
    id: id ?? this.id,
    diverId: clearDiverId ? null : (diverId ?? this.diverId),
    equipmentId: clearEquipmentId ? null : (equipmentId ?? this.equipmentId),
    name: name ?? this.name,
    description: description ?? this.description,
    sortOrder: sortOrder ?? this.sortOrder,
    items: items ?? this.items,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  List<Object?> get props => [
    id,
    diverId,
    equipmentId,
    name,
    description,
    sortOrder,
    items,
  ];
}
```

`createdAt` and `updatedAt` are deliberately excluded from `props` on both entities, matching `EquipmentSet`. Timestamps churn on every write and would defeat Riverpod's equality-based rebuild suppression.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/cylinder_configs/domain/entities/cylinder_config_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "Add cylinder configuration domain entities (#804)"
```

---

### Task 9: The merge algorithm

**Files:**
- Create: `lib/features/cylinder_configs/domain/services/cylinder_config_applier.dart`
- Test: `test/features/cylinder_configs/domain/services/cylinder_config_applier_test.dart`

**Interfaces:**
- Consumes: `CylinderConfigItem` (Task 8), `TankRole`, `TankMaterial`.
- Produces:
  - `class ExistingTank` — the applier's input view of a `dive_tanks` row: `({String id, TankRole tankRole, double? volumeL, double? workingPressureBar, TankMaterial? tankMaterial, double? startPressureBar, String? tankName, int tankOrder})`.
  - `sealed class CylinderConfigOp` with subtypes `InsertTank` and `FillTank`.
  - `class CylinderConfigPlan { List<CylinderConfigOp> ops; int insertedCount; int keptCount; }`
  - `CylinderConfigApplier.plan({required List<ExistingTank> existing, required List<CylinderConfigItem> items}) -> CylinderConfigPlan`

This is the highest-risk code in the plan and the reason it is a pure service: no database, no `DateTime.now()`, mirroring `ServiceDueEngine`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/cylinder_configs/domain/services/cylinder_config_applier_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/cylinder_configs/domain/services/cylinder_config_applier.dart';

void main() {
  final now = DateTime.utc(2026, 8, 5);
  const applier = CylinderConfigApplier();

  CylinderConfigItem cfg({
    required String id,
    required TankRole role,
    int order = 0,
    double o2 = 21,
    double he = 0,
    double? volume,
    double? pressure,
    TankMaterial? material,
    double? startPressure,
    String? label,
  }) => CylinderConfigItem(
    id: id,
    configId: 'c1',
    sortOrder: order,
    tankRole: role,
    o2Percent: o2,
    hePercent: he,
    volumeL: volume,
    workingPressureBar: pressure,
    tankMaterial: material,
    defaultStartPressureBar: startPressure,
    label: label,
    createdAt: now,
    updatedAt: now,
  );

  ExistingTank tank({
    required String id,
    required TankRole role,
    double? volume,
    double? pressure,
    TankMaterial? material,
    double? startPressure,
    String? name,
    int order = 0,
  }) => ExistingTank(
    id: id,
    tankRole: role,
    volumeL: volume,
    workingPressureBar: pressure,
    tankMaterial: material,
    startPressureBar: startPressure,
    tankName: name,
    tankOrder: order,
  );

  test('an empty dive gets every cylinder inserted, in sort order', () {
    final plan = applier.plan(
      existing: const [],
      items: [
        cfg(id: 'b', role: TankRole.oxygenSupply, order: 1),
        cfg(id: 'a', role: TankRole.diluent, order: 0),
        cfg(id: 'c', role: TankRole.bailout, order: 2),
      ],
    );

    expect(plan.insertedCount, 3);
    expect(plan.keptCount, 0);
    expect(plan.ops.whereType<FillTank>(), isEmpty);

    final inserts = plan.ops.whereType<InsertTank>().toList();
    expect(
      inserts.map((o) => o.item.tankRole),
      [TankRole.diluent, TankRole.oxygenSupply, TankRole.bailout],
    );
    expect(inserts.map((o) => o.tankOrder), [0, 1, 2]);
  });

  test('inserted tank order continues after the existing maximum', () {
    final plan = applier.plan(
      existing: [tank(id: 't1', role: TankRole.diluent, order: 7)],
      items: [
        cfg(id: 'a', role: TankRole.diluent, order: 0),
        cfg(id: 'b', role: TankRole.bailout, order: 1),
      ],
    );

    final inserts = plan.ops.whereType<InsertTank>().toList();
    expect(inserts, hasLength(1));
    expect(inserts.single.tankOrder, 8);
  });

  test('a downloaded gas mix is never overwritten', () {
    final plan = applier.plan(
      existing: [tank(id: 't1', role: TankRole.diluent)],
      items: [cfg(id: 'a', role: TankRole.diluent, o2: 18, he: 45)],
    );

    expect(plan.insertedCount, 0);
    expect(plan.keptCount, 1);

    final fill = plan.ops.whereType<FillTank>().single;
    expect(fill.tankId, 't1');
    // No gas fields on FillTank at all: overwriting is not expressible.
    expect(fill.volumeL, isNull);
    expect(fill.workingPressureBar, isNull);
  });

  test('only null columns are filled on a claimed tank', () {
    final plan = applier.plan(
      existing: [
        tank(
          id: 't1',
          role: TankRole.bailout,
          volume: 11.1,
          name: 'Downloaded',
        ),
      ],
      items: [
        cfg(
          id: 'a',
          role: TankRole.bailout,
          volume: 5.7,
          pressure: 207,
          material: TankMaterial.aluminum,
          startPressure: 200,
          label: 'Bailout 1',
        ),
      ],
    );

    final fill = plan.ops.whereType<FillTank>().single;
    expect(fill.volumeL, isNull, reason: 'already 11.1, must not be touched');
    expect(fill.tankName, isNull, reason: 'already named');
    expect(fill.workingPressureBar, 207);
    expect(fill.tankMaterial, TankMaterial.aluminum);
    expect(fill.startPressureBar, 200);
  });

  test('duplicate roles claim one existing tank each, then insert', () {
    final plan = applier.plan(
      existing: [tank(id: 't1', role: TankRole.bailout, order: 0)],
      items: [
        cfg(id: 'a', role: TankRole.bailout, order: 0, pressure: 207),
        cfg(id: 'b', role: TankRole.bailout, order: 1, pressure: 232),
      ],
    );

    expect(plan.keptCount, 1);
    expect(plan.insertedCount, 1);
    expect(plan.ops.whereType<FillTank>().single.tankId, 't1');
    expect(
      plan.ops.whereType<InsertTank>().single.item.workingPressureBar,
      232,
    );
  });

  test('two existing tanks of one role are both claimed before inserting', () {
    final plan = applier.plan(
      existing: [
        tank(id: 't1', role: TankRole.bailout, order: 0),
        tank(id: 't2', role: TankRole.bailout, order: 1),
      ],
      items: [
        cfg(id: 'a', role: TankRole.bailout, order: 0),
        cfg(id: 'b', role: TankRole.bailout, order: 1),
      ],
    );

    expect(plan.keptCount, 2);
    expect(plan.insertedCount, 0);
    expect(
      plan.ops.whereType<FillTank>().map((o) => o.tankId),
      ['t1', 't2'],
    );
  });

  test('extra existing tanks the config does not mention are left alone', () {
    final plan = applier.plan(
      existing: [
        tank(id: 't1', role: TankRole.diluent),
        tank(id: 't2', role: TankRole.stage),
      ],
      items: [cfg(id: 'a', role: TankRole.diluent)],
    );

    expect(plan.keptCount, 1);
    expect(plan.insertedCount, 0);
    expect(plan.ops.whereType<FillTank>().map((o) => o.tankId), ['t1']);
  });

  test('a claimed tank needing no fill produces no FillTank op', () {
    final plan = applier.plan(
      existing: [
        tank(
          id: 't1',
          role: TankRole.diluent,
          volume: 3,
          pressure: 232,
          material: TankMaterial.steel,
          startPressure: 200,
          name: 'Dil',
        ),
      ],
      items: [cfg(id: 'a', role: TankRole.diluent, volume: 3, pressure: 232)],
    );

    expect(plan.keptCount, 1);
    expect(plan.ops, isEmpty);
  });

  test('an empty config is a no-op', () {
    final plan = applier.plan(
      existing: [tank(id: 't1', role: TankRole.diluent)],
      items: const [],
    );
    expect(plan.ops, isEmpty);
    expect(plan.insertedCount, 0);
    expect(plan.keptCount, 0);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/cylinder_configs/domain/services/cylinder_config_applier_test.dart`
Expected: FAIL — the file does not exist.

- [ ] **Step 3: Write the applier**

Create `lib/features/cylinder_configs/domain/services/cylinder_config_applier.dart`:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';

/// The applier's read-only view of an existing dive_tanks row.
class ExistingTank {
  final String id;
  final TankRole tankRole;
  final double? volumeL;
  final double? workingPressureBar;
  final TankMaterial? tankMaterial;
  final double? startPressureBar;
  final String? tankName;
  final int tankOrder;

  const ExistingTank({
    required this.id,
    required this.tankRole,
    this.volumeL,
    this.workingPressureBar,
    this.tankMaterial,
    this.startPressureBar,
    this.tankName,
    this.tankOrder = 0,
  });
}

sealed class CylinderConfigOp {
  const CylinderConfigOp();
}

/// Create a new dive_tanks row from [item] at [tankOrder].
class InsertTank extends CylinderConfigOp {
  final CylinderConfigItem item;
  final int tankOrder;

  const InsertTank({required this.item, required this.tankOrder});
}

/// Fill columns that are NULL on an existing dive_tanks row. Every field here
/// is nullable and null means "leave this column alone".
///
/// There are deliberately no o2Percent or hePercent fields. dive_tanks
/// defaults them to 21.0 and 0.0, so a tank reading air is indistinguishable
/// from a tank nobody filled in -- there is no null to test against, and
/// therefore no honest way to detect "unset". Omitting the fields makes
/// overwriting a gas mix unexpressible rather than merely discouraged.
class FillTank extends CylinderConfigOp {
  final String tankId;
  final double? volumeL;
  final double? workingPressureBar;
  final TankMaterial? tankMaterial;
  final double? startPressureBar;
  final String? tankName;

  const FillTank({
    required this.tankId,
    this.volumeL,
    this.workingPressureBar,
    this.tankMaterial,
    this.startPressureBar,
    this.tankName,
  });

  bool get isEmpty =>
      volumeL == null &&
      workingPressureBar == null &&
      tankMaterial == null &&
      startPressureBar == null &&
      tankName == null;
}

class CylinderConfigPlan {
  final List<CylinderConfigOp> ops;
  final int insertedCount;
  final int keptCount;

  const CylinderConfigPlan({
    required this.ops,
    required this.insertedCount,
    required this.keptCount,
  });
}

/// Merges a cylinder configuration into a dive's existing cylinders.
///
/// Pure: no database, no DateTime.now(). Callers persist the returned ops.
/// Mirrors ServiceDueEngine so the merge rules can be tested exhaustively
/// without a database fixture.
class CylinderConfigApplier {
  const CylinderConfigApplier();

  CylinderConfigPlan plan({
    required List<ExistingTank> existing,
    required List<CylinderConfigItem> items,
  }) {
    final ordered = [...items]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final claimed = <String>{};
    final ops = <CylinderConfigOp>[];
    var inserted = 0;
    var kept = 0;

    var nextOrder = existing.isEmpty
        ? 0
        : existing.map((t) => t.tankOrder).reduce((a, b) => a > b ? a : b) + 1;

    for (final item in ordered) {
      // First unclaimed existing tank with the same role. Roles are not
      // unique -- a CCR diver routinely carries two bailout cylinders -- so
      // claiming greedily in order is what makes "config has 2 bailouts,
      // dive already has 1" resolve to keep-one-add-one.
      ExistingTank? match;
      for (final tank in existing) {
        if (tank.tankRole == item.tankRole && !claimed.contains(tank.id)) {
          match = tank;
          break;
        }
      }

      if (match == null) {
        ops.add(InsertTank(item: item, tankOrder: nextOrder));
        nextOrder++;
        inserted++;
        continue;
      }

      claimed.add(match.id);
      kept++;

      final fill = FillTank(
        tankId: match.id,
        volumeL: match.volumeL == null ? item.volumeL : null,
        workingPressureBar: match.workingPressureBar == null
            ? item.workingPressureBar
            : null,
        tankMaterial: match.tankMaterial == null ? item.tankMaterial : null,
        startPressureBar: match.startPressureBar == null
            ? item.defaultStartPressureBar
            : null,
        tankName: match.tankName == null ? item.label : null,
      );
      if (!fill.isEmpty) ops.add(fill);
    }

    return CylinderConfigPlan(
      ops: ops,
      insertedCount: inserted,
      keptCount: kept,
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/cylinder_configs/domain/services/cylinder_config_applier_test.dart`
Expected: all 9 PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "Add cylinder configuration merge algorithm (#804)"
```

---

### Task 10: Drift tables and schema v139

**Files:**
- Modify: `lib/core/database/database.dart` (table classes, `@DriftDatabase` tables list, `currentSchemaVersion`, `migrationVersions`, `onUpgrade`, `beforeOpen`)
- Test: `test/core/database/migration_v139_cylinder_configs_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: Drift tables `CylinderConfigs` and `CylinderConfigItems`, reachable as `db.cylinderConfigs` and `db.cylinderConfigItems`; `_assertCylinderConfigSchema()`.

- [ ] **Step 1: Re-check the schema version**

Run:

```bash
git fetch origin main
git log origin/main --oneline -1
grep -n "currentSchemaVersion = " lib/core/database/database.dart
```

If `origin/main` has advanced past 138, merge it and claim the next free number instead of 139, substituting it everywhere below. Also relax any pre-existing migration test asserting an exact latest version to `greaterThanOrEqualTo`.

- [ ] **Step 2: Write the failing test**

Create `test/core/database/migration_v139_cylinder_configs_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('v139 is in the migration ladder', () {
    expect(
      AppDatabase.currentSchemaVersion,
      greaterThanOrEqualTo(139),
    );
    expect(AppDatabase.migrationVersions, contains(139));
  });

  test('a fresh database has both cylinder config tables', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final configCols = await db
        .customSelect("PRAGMA table_info('cylinder_configs')")
        .get();
    expect(
      configCols.map((c) => c.read<String>('name')).toSet(),
      containsAll([
        'id',
        'diver_id',
        'equipment_id',
        'name',
        'description',
        'sort_order',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );

    final itemCols = await db
        .customSelect("PRAGMA table_info('cylinder_config_items')")
        .get();
    expect(
      itemCols.map((c) => c.read<String>('name')).toSet(),
      containsAll([
        'id',
        'config_id',
        'sort_order',
        'label',
        'tank_role',
        'volume_l',
        'working_pressure_bar',
        'tank_material',
        'o2_percent',
        'he_percent',
        'default_start_pressure_bar',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );
  });

  test('deleting the owning equipment demotes the config, not deletes it',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement('PRAGMA foreign_keys = ON');

    final now = DateTime.now().millisecondsSinceEpoch;
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('rb-1', 'JJ', 'rebreather', $now, $now)",
    );
    await db.customStatement(
      "INSERT INTO cylinder_configs "
      "(id, equipment_id, name, description, sort_order, "
      " created_at, updated_at) "
      "VALUES ('c1', 'rb-1', 'Trimix', '', 0, $now, $now)",
    );

    await db.customStatement("DELETE FROM equipment WHERE id = 'rb-1'");

    final rows = await db
        .customSelect(
          "SELECT id, equipment_id FROM cylinder_configs WHERE id = 'c1'",
        )
        .get();
    expect(rows, hasLength(1), reason: 'config must survive unit deletion');
    expect(rows.single.read<String?>('equipment_id'), isNull);
  });

  test('deleting a config cascades to its items', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement('PRAGMA foreign_keys = ON');

    final now = DateTime.now().millisecondsSinceEpoch;
    await db.customStatement(
      "INSERT INTO cylinder_configs "
      "(id, name, description, sort_order, created_at, updated_at) "
      "VALUES ('c1', 'Doubles', '', 0, $now, $now)",
    );
    await db.customStatement(
      "INSERT INTO cylinder_config_items "
      "(id, config_id, sort_order, tank_role, o2_percent, he_percent, "
      " created_at, updated_at) "
      "VALUES ('i1', 'c1', 0, 'backGas', 21, 0, $now, $now)",
    );

    await db.customStatement("DELETE FROM cylinder_configs WHERE id = 'c1'");

    final items = await db
        .customSelect('SELECT id FROM cylinder_config_items')
        .get();
    expect(items, isEmpty);
  });

  test('a database stranded below v139 self-heals via the schema assert',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await db.customStatement('DROP TABLE IF EXISTS cylinder_config_items');
    await db.customStatement('DROP TABLE IF EXISTS cylinder_configs');

    await db.assertCylinderConfigSchemaForTest();

    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name LIKE 'cylinder_config%'",
        )
        .get();
    expect(tables.map((t) => t.read<String>('name')).toSet(), {
      'cylinder_configs',
      'cylinder_config_items',
    });
  });
}
```

Both foreign-key tests explicitly enable `PRAGMA foreign_keys = ON`. Drift's in-memory default leaves them off, which would let both tests pass vacuously — the exact trap that has masked insert-order bugs on this codebase before.

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/core/database/migration_v139_cylinder_configs_test.dart`
Expected: FAIL — `currentSchemaVersion` is 137, and the tables do not exist.

- [ ] **Step 4: Add the Drift table classes**

In `lib/core/database/database.dart`, add after the `TankPresets` class:

```dart
/// A named, reusable set of cylinders. equipment_id set means "a config for
/// this rebreather"; null means a generic gas plan. ON DELETE SET NULL
/// demotes a config when its unit is deleted rather than destroying a
/// painstakingly entered bailout plan.
class CylinderConfigs extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get equipmentId => text().nullable().references(
    Equipment,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One cylinder in a configuration. The spec columns are a SNAPSHOT: a tank
/// preset may populate them at edit time, but there is deliberately no FK to
/// tank_presets. A config records what the diver actually dives, so a later
/// edit to a preset must not rewrite the meaning of a saved config.
class CylinderConfigItems extends Table {
  TextColumn get id => text()();
  TextColumn get configId => text().references(
    CylinderConfigs,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get label => text().nullable()();
  TextColumn get tankRole => text()(); // TankRole.name
  RealColumn get volumeL => real().nullable()();
  RealColumn get workingPressureBar => real().nullable()();
  TextColumn get tankMaterial => text().nullable()(); // TankMaterial.name
  RealColumn get o2Percent => real().withDefault(const Constant(21.0))();
  RealColumn get hePercent => real().withDefault(const Constant(0.0))();
  RealColumn get defaultStartPressureBar => real().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

Register both in the `@DriftDatabase(tables: [...])` annotation, next to `TankPresets`.

- [ ] **Step 5: Add the schema assert and wire the migration**

Add alongside the other `_assert*Schema` methods:

```dart
  /// v139: cylinder configuration tables. CREATE TABLE IF NOT EXISTS, so this
  /// is safe to call from both onUpgrade and the beforeOpen backstop
  /// (parallel-branch version-collision self-heal).
  Future<void> _assertCylinderConfigSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS cylinder_configs (
        id TEXT NOT NULL PRIMARY KEY,
        diver_id TEXT REFERENCES divers (id),
        equipment_id TEXT REFERENCES equipment (id) ON DELETE SET NULL,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        hlc TEXT
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS cylinder_config_items (
        id TEXT NOT NULL PRIMARY KEY,
        config_id TEXT NOT NULL
          REFERENCES cylinder_configs (id) ON DELETE CASCADE,
        sort_order INTEGER NOT NULL DEFAULT 0,
        label TEXT,
        tank_role TEXT NOT NULL,
        volume_l REAL,
        working_pressure_bar REAL,
        tank_material TEXT,
        o2_percent REAL NOT NULL DEFAULT 21.0,
        he_percent REAL NOT NULL DEFAULT 0.0,
        default_start_pressure_bar REAL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        hlc TEXT
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cylinder_configs_equipment '
      'ON cylinder_configs (equipment_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cylinder_config_items_config '
      'ON cylinder_config_items (config_id)',
    );
  }

  /// Test hook for the stranded-database self-heal path.
  Future<void> assertCylinderConfigSchemaForTest() =>
      _assertCylinderConfigSchema();
```

Then:
1. Set `static const int currentSchemaVersion = 139;`
2. Append `139` to `migrationVersions`.
3. In `onUpgrade`, after the highest existing block:

```dart
        if (from < 139) {
          await _assertCylinderConfigSchema();
          await reportProgress();
        }
```

4. In the `beforeOpen` backstop, alongside the other asserts:

```dart
        await _assertCylinderConfigSchema();
```

- [ ] **Step 6: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `database.g.dart` gains `CylinderConfig`/`CylinderConfigItem` data classes and `db.cylinderConfigs` / `db.cylinderConfigItems` accessors.

The generated Drift row classes will be named `CylinderConfig` and `CylinderConfigItem` — colliding with the domain entities from Task 8. Every file importing both must alias one, exactly as the codebase already does elsewhere: `import '.../cylinder_config.dart' as domain;`.

- [ ] **Step 7: Run test to verify it passes**

Run: `flutter test test/core/database/migration_v139_cylinder_configs_test.dart`
Expected: all 5 PASS.

- [ ] **Step 8: Run the database suite**

Run: `flutter test test/core/database/`
Expected: all pass. If a pre-existing test asserts an exact latest schema version, relax it to `greaterThanOrEqualTo(N)` plus `contains(N)`.

- [ ] **Step 9: Commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "Add cylinder configuration tables at schema v139 (#804)"
```

---

### Task 11: Repository

**Files:**
- Create: `lib/features/cylinder_configs/data/repositories/cylinder_config_repository.dart`
- Test: `test/features/cylinder_configs/data/cylinder_config_repository_test.dart`

**Interfaces:**
- Consumes: Drift tables (Task 10), domain entities (Task 8).
- Produces `CylinderConfigRepository` with:
  - `Future<List<domain.CylinderConfig>> getAllConfigs({String? diverId, bool includeItems = false})`
  - `Future<List<domain.CylinderConfig>> getConfigsForEquipment(String equipmentId)`
  - `Future<domain.CylinderConfig?> getConfigById(String id, {bool includeItems = true})`
  - `Future<String> createConfig({String? diverId, String? equipmentId, required String name, String description = ''})`
  - `Future<void> updateConfig(domain.CylinderConfig config)`
  - `Future<void> deleteConfig(String id)`
  - `Future<void> saveItems(String configId, List<domain.CylinderConfigItem> items)`

- [ ] **Step 1: Read the pattern to follow**

Run: `cat lib/features/equipment/data/repositories/equipment_set_repository_impl.dart`

Copy its structure exactly: `AppDatabase get _db => DatabaseService.instance.database;`, a `SyncRepository` field, a `const Uuid()` field, `SyncEventBus.notifyLocalChange()` after every write, and deletion-log registration on delete.

- [ ] **Step 2: Write the failing tests**

Create `test/features/cylinder_configs/data/cylinder_config_repository_test.dart`. Follow the fixture pattern in `test/features/equipment/data/repositories/` for standing up an in-memory `AppDatabase` through `DatabaseService` — read one of those files first and copy its `setUp`/`tearDown` verbatim rather than inventing a new fixture.

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/cylinder_configs/data/repositories/cylinder_config_repository.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart'
    as domain;

void main() {
  late AppDatabase db;
  late CylinderConfigRepository repository;
  final now = DateTime.utc(2026, 8, 5);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.customStatement('PRAGMA foreign_keys = ON');
    DatabaseService.instance.setDatabaseForTest(db);
    repository = CylinderConfigRepository();
  });

  tearDown(() async {
    await db.close();
  });

  domain.CylinderConfigItem item({
    required String id,
    required String configId,
    TankRole role = TankRole.bailout,
    int order = 0,
    double o2 = 21,
  }) => domain.CylinderConfigItem(
    id: id,
    configId: configId,
    sortOrder: order,
    tankRole: role,
    o2Percent: o2,
    createdAt: now,
    updatedAt: now,
  );

  test('creates a config and reads it back', () async {
    final id = await repository.createConfig(
      diverId: 'd1',
      name: 'JJ trimix',
      description: 'Bottom 18/45',
    );

    final loaded = await repository.getConfigById(id);
    expect(loaded, isNotNull);
    expect(loaded!.name, 'JJ trimix');
    expect(loaded.description, 'Bottom 18/45');
    expect(loaded.equipmentId, isNull);
    expect(loaded.isOwnedByUnit, isFalse);
  });

  test('getConfigsForEquipment returns only that unit\'s configs', () async {
    final ts = now.millisecondsSinceEpoch;
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('rb-1', 'JJ', 'rebreather', $ts, $ts)",
    );
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('rb-2', 'rEvo', 'rebreather', $ts, $ts)",
    );

    await repository.createConfig(equipmentId: 'rb-1', name: 'A');
    await repository.createConfig(equipmentId: 'rb-1', name: 'B');
    await repository.createConfig(equipmentId: 'rb-2', name: 'C');
    await repository.createConfig(name: 'Generic');

    final forUnit = await repository.getConfigsForEquipment('rb-1');
    expect(forUnit.map((c) => c.name).toSet(), {'A', 'B'});
  });

  test('getAllConfigs with includeItems hydrates items in sort order',
      () async {
    final id = await repository.createConfig(name: 'Doubles + 50');
    await repository.saveItems(id, [
      item(id: 'i2', configId: id, role: TankRole.deco, order: 1, o2: 50),
      item(id: 'i1', configId: id, role: TankRole.backGas, order: 0),
    ]);

    final configs = await repository.getAllConfigs(includeItems: true);
    final config = configs.single;
    expect(config.items.map((i) => i.tankRole), [
      TankRole.backGas,
      TankRole.deco,
    ]);
    expect(config.items.last.o2Percent, 50);
  });

  test('saveItems replaces the item set and renumbers sort_order', () async {
    final id = await repository.createConfig(name: 'Config');
    await repository.saveItems(id, [
      item(id: 'i1', configId: id, order: 0),
      item(id: 'i2', configId: id, order: 1),
      item(id: 'i3', configId: id, order: 2),
    ]);

    // Drop the middle item; the survivors renumber from list position.
    await repository.saveItems(id, [
      item(id: 'i3', configId: id, order: 99),
      item(id: 'i1', configId: id, order: 99),
    ]);

    final config = await repository.getConfigById(id);
    expect(config!.items.map((i) => i.id), ['i3', 'i1']);
    expect(config.items.map((i) => i.sortOrder), [0, 1]);
  });

  test('saveItems writes deletion-log tombstones for removed items',
      () async {
    final id = await repository.createConfig(name: 'Config');
    await repository.saveItems(id, [
      item(id: 'i1', configId: id, order: 0),
      item(id: 'i2', configId: id, order: 1),
    ]);

    await repository.saveItems(id, [item(id: 'i1', configId: id, order: 0)]);

    final tombstones = await db
        .customSelect(
          "SELECT record_id FROM deletion_log "
          "WHERE entity_type = 'cylinderConfigItems'",
        )
        .get();
    expect(
      tombstones.map((r) => r.read<String>('record_id')),
      contains('i2'),
      reason: 'without a tombstone the row resurrects on the next sync pull',
    );
  });

  test('deleteConfig removes its items', () async {
    final id = await repository.createConfig(name: 'Config');
    await repository.saveItems(id, [item(id: 'i1', configId: id)]);

    await repository.deleteConfig(id);

    expect(await repository.getConfigById(id), isNull);
    final rows = await db
        .customSelect('SELECT id FROM cylinder_config_items')
        .get();
    expect(rows, isEmpty);
  });

  test('a config for a deleted unit survives as a generic gas plan',
      () async {
    final ts = now.millisecondsSinceEpoch;
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('rb-1', 'JJ', 'rebreather', $ts, $ts)",
    );
    final id = await repository.createConfig(
      equipmentId: 'rb-1',
      name: 'Trimix',
    );

    await db.customStatement("DELETE FROM equipment WHERE id = 'rb-1'");

    final loaded = await repository.getConfigById(id);
    expect(loaded, isNotNull);
    expect(loaded!.equipmentId, isNull);
    expect(loaded.isOwnedByUnit, isFalse);
  });
}
```

Two details that are easy to get wrong. First, `PRAGMA foreign_keys = ON` is mandatory — Drift's in-memory default leaves them off, which would make the last test pass vacuously whether or not `ON DELETE SET NULL` is wired. Second, if `DatabaseService` exposes a differently-named test hook than `setDatabaseForTest`, use whatever the existing equipment repository tests use; do not add a new hook.

The tombstone test matters most. Child rows deleted without a deletion-log entry resurrect on the next sync pull — this codebase has hit that exact data-loss bug before.

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/features/cylinder_configs/data/cylinder_config_repository_test.dart`
Expected: FAIL — the repository does not exist.

- [ ] **Step 4: Write the repository**

Create `lib/features/cylinder_configs/data/repositories/cylinder_config_repository.dart`, modeled on `EquipmentSetRepository`. Requirements:

- `saveItems` runs in a single `_db.transaction`, deletes rows absent from the incoming list, registers a deletion-log tombstone for each via `_syncRepository`, then upserts the rest with `sortOrder` renumbered `0..n-1` from list position.
- Every public write ends with `SyncEventBus.notifyLocalChange()`.
- `getAllConfigs` orders by `sortOrder` then `name`; items order by `sortOrder`.
- Map `tankRole` and `tankMaterial` via `.name` on write and a `values.firstWhere(... orElse: ...)` lookup on read, so an unknown persisted string degrades to a sensible default rather than throwing.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/cylinder_configs/data/cylinder_config_repository_test.dart`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "Add cylinder configuration repository (#804)"
```

---

### Task 12: Sync registration

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (14 sites)
- Modify: `lib/core/services/sync/sync_service.dart` (4 sites)
- Test: `test/core/services/sync/cylinder_config_sync_test.dart`

**Interfaces:**
- Consumes: Drift tables (Task 10).
- Produces: sync entity keys `'cylinderConfigs'` (top-level) and `'cylinderConfigItems'` (HLC child of `cylinderConfigs`).

- [ ] **Step 1: Enumerate the sites to mirror**

Run:

```bash
grep -n "equipmentAttributes" lib/core/services/sync/sync_data_serializer.dart
grep -n "equipmentAttributes" lib/core/services/sync/sync_service.dart
```

`equipmentAttributes` is the closest precedent: a synced HLC child of a parent entity. As of this writing the serializer sites are at lines 227, 299, 372, 446, 665-666, 1164-1165, 1551-1553, 1923-1925, 2220-2222, 2739-2742, 3451-3452, 3672-3673, 3835-3837, 4318; the service sites are 1149-1150, 1819, 2021. **Re-run the greps** — these shift with every merge.

Add an arm for each of the two new entities at every one of those sites.

- [ ] **Step 2: Write the failing test**

Create `test/core/services/sync/cylinder_config_sync_test.dart` following the existing sync round-trip tests. Cover:

```dart
  test('a config and its items export and re-import intact', ...);
  test('a newer HLC on an incoming item wins over the local row', ...);
  test('a deleted item stays deleted after a pull (tombstone honored)', ...);
  test('cylinderConfigs merges before cylinderConfigItems', ...);
```

The merge-order test is the one that catches a real failure: importing a child before its parent violates the foreign key and silently drops the row on a fixture with foreign keys off.

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/core/services/sync/cylinder_config_sync_test.dart`
Expected: FAIL — the entity keys are unknown to the serializer.

- [ ] **Step 4: Register both entities**

Mirror `equipmentAttributes` at every site. Specifics that differ:

- **`mergeOrder`**: `cylinderConfigs` after `equipment` (its `equipment_id` FK parent); `cylinderConfigItems` immediately after `cylinderConfigs`.
- **`parentRefs`**: `cylinderConfigItems` declares `cylinderConfigs` as its parent, keyed on `config_id`.
- **`entityHasUpdatedAt`**: `true` for both.
- **`_hlcTables` / `_hlcTargets`**: register both tables.
- **`_baseTables`** (streaming base export): register both, or a full base restore silently omits every configuration.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/core/services/sync/cylinder_config_sync_test.dart`
Expected: all PASS.

- [ ] **Step 6: Run the full sync suite**

Run: `flutter test test/core/services/sync/`
Expected: all pass. Sync tests are the most interconnected in the codebase; a missed registration site usually surfaces here rather than in the new file.

- [ ] **Step 7: Commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "Register cylinder configurations as synced entities (#804)"
```

---

### Task 13: Providers

**Files:**
- Create: `lib/features/cylinder_configs/presentation/providers/cylinder_config_providers.dart`
- Test: `test/features/cylinder_configs/presentation/cylinder_config_providers_test.dart`

**Interfaces:**
- Consumes: `CylinderConfigRepository` (Task 11).
- Produces:
  - `cylinderConfigRepositoryProvider` — `Provider<CylinderConfigRepository>`
  - `cylinderConfigsProvider` — `FutureProvider<List<domain.CylinderConfig>>`, active diver scoped, items included
  - `cylinderConfigsForEquipmentProvider` — `FutureProvider.family<List<domain.CylinderConfig>, String>`
  - `cylinderConfigProvider` — `FutureProvider.family<domain.CylinderConfig?, String>`

- [ ] **Step 1: Read the pattern**

Run: `cat lib/features/equipment/presentation/providers/equipment_set_providers.dart`

Import Riverpod through the project barrel `package:submersion/core/providers/provider.dart`, not `flutter_riverpod` directly — the codebase standardizes on the barrel for Riverpod 3 compatibility.

- [ ] **Step 2: Write the failing test**

Create `test/features/cylinder_configs/presentation/cylinder_config_providers_test.dart`:

```dart
  test('cylinderConfigsProvider returns the active diver\'s configs', ...);
  test('cylinderConfigsForEquipmentProvider filters by unit', ...);
  test('invalidating the list provider refetches', ...);
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/cylinder_configs/presentation/cylinder_config_providers_test.dart`
Expected: FAIL — the providers do not exist.

- [ ] **Step 4: Write the providers**

Follow `equipment_set_providers.dart` exactly for diver scoping and invalidation.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/cylinder_configs/presentation/cylinder_config_providers_test.dart`
Expected: PASS

- [ ] **Step 6: Check for broken consumer tests**

Run: `flutter test`
Expected: all pass. Adding a provider dependency to an existing widget breaks consumer tests that do not override it, and `flutter analyze` will **not** catch this. The full suite is the only reliable check.

- [ ] **Step 7: Commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "Add cylinder configuration providers (#804)"
```

---

### Task 14: Configuration list and edit pages

**Files:**
- Create: `lib/features/cylinder_configs/presentation/pages/cylinder_config_list_page.dart`
- Create: `lib/features/cylinder_configs/presentation/pages/cylinder_config_edit_page.dart`
- Create: `lib/features/cylinder_configs/presentation/widgets/cylinder_config_item_editor.dart`
- Modify: `lib/core/router/app_router.dart` (near the `equipmentSets` route, line ~482)
- Modify: all 11 `lib/l10n/arb/app_*.arb`
- Test: `test/features/cylinder_configs/presentation/cylinder_config_edit_page_test.dart`

**Interfaces:**
- Consumes: providers (Task 13), entities (Task 8), `TankRole`, `TankMaterial`, `TankPreset`.
- Produces: routes `cylinderConfigs` (`/gear/cylinder-configs`) and `cylinderConfigEdit` (`/gear/cylinder-configs/:id`).

- [ ] **Step 1: Read the sibling pages**

Run:

```bash
cat lib/features/equipment/presentation/pages/equipment_set_list_page.dart
cat lib/features/equipment/presentation/pages/equipment_set_edit_page.dart
sed -n 470,500p lib/core/router/app_router.dart
```

Match their scaffold, app bar, empty state, and route registration style.

- [ ] **Step 2: Add the ARB keys**

To `app_en.arb`, then all 10 others, then `flutter gen-l10n`:

```json
  "cylinderConfigsTitle": "Cylinder configurations",
  "cylinderConfigsEmpty": "No configurations yet",
  "cylinderConfigsEmptyBody": "Save a diluent and bailout setup once, then apply it to any dive.",
  "cylinderConfigNew": "New configuration",
  "cylinderConfigName": "Name",
  "cylinderConfigForUnit": "For unit",
  "cylinderConfigNoUnit": "Generic gas plan",
  "cylinderConfigAddCylinder": "Add cylinder",
  "cylinderConfigCylinderRole": "Role",
  "cylinderConfigStartPressure": "Start pressure",
  "cylinderConfigLabel": "Label",
  "cylinderConfigDeleteTitle": "Delete configuration?",
  "cylinderConfigDeleteBody": "This does not change any dive it was already applied to."
```

- [ ] **Step 3: Write the failing widget test**

Create `test/features/cylinder_configs/presentation/cylinder_config_edit_page_test.dart`:

```dart
  testWidgets('adding a cylinder appends a row with a role selector', ...);
  testWidgets('reordering cylinders renumbers sort order', ...);
  testWidgets('choosing a tank preset fills volume and pressure', ...);
  testWidgets('saving with an empty name shows a validation error', ...);
```

Pin `locale: const Locale('en')` on the host `MaterialApp`.

- [ ] **Step 4: Run tests to verify they fail**

Run: `flutter test test/features/cylinder_configs/presentation/cylinder_config_edit_page_test.dart`
Expected: FAIL — the pages do not exist.

- [ ] **Step 5: Build the pages**

Requirements:

- **List page**: configs grouped by owning unit, generic ones under a "Gas plans" heading. Empty state uses `cylinderConfigsEmpty*`. FAB creates a new config.
- **Edit page**: name field (required), optional owning-unit dropdown populated from equipment of type `rebreather`, and a `ReorderableListView` of cylinder rows.
- **Item editor row**: role dropdown from `TankRole.values`; O2 and He percent fields; a "From preset" button that fills `volumeL` / `workingPressureBar` / `tankMaterial` from a chosen `TankPreset` and then leaves them freely editable; optional start pressure; optional label.
- Volumes and pressures render and parse through `UnitFormatter` against the diver's unit settings.
- Dispose every `TextEditingController` the page creates.

- [ ] **Step 6: Register the routes**

In `app_router.dart`, add sibling routes next to `equipmentSets`. Register them as **siblings**, not nested children — nesting a route under a shared widget in this codebase produces a doubled page.

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/features/cylinder_configs/presentation/cylinder_config_edit_page_test.dart`
Expected: all PASS.

- [ ] **Step 8: Commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "Add cylinder configuration list and edit pages (#804)"
```

---

### Task 15: Apply a configuration to a dive

**Files:**
- Create: `lib/features/cylinder_configs/presentation/widgets/apply_configuration_menu.dart`
- Create: `lib/features/cylinder_configs/data/services/cylinder_config_apply_service.dart`
- Modify: `lib/features/dive_log/presentation/widgets/cylinders_card.dart`
- Modify: all 11 `lib/l10n/arb/app_*.arb`
- Test: `test/features/cylinder_configs/data/cylinder_config_apply_service_test.dart`
- Test: `test/features/cylinder_configs/presentation/apply_configuration_menu_test.dart`

**Interfaces:**
- Consumes: `CylinderConfigApplier` (Task 9), `CylinderConfigRepository` (Task 11), providers (Task 13).
- Produces: `CylinderConfigApplyService.applyToDive({required String diveId, required String configId}) -> Future<CylinderConfigPlan>` — persists the plan and returns it so the caller can report counts.

- [ ] **Step 1: Add the ARB keys**

To all 11 ARB files, then `flutter gen-l10n`:

```json
  "applyConfiguration": "Apply configuration",
  "applyConfigurationGasPlans": "Gas plans",
  "applyConfigurationResult": "Added {added} cylinders, kept {kept}",
  "applyConfigurationNothingToDo": "This dive already matches the configuration"
```

`applyConfigurationResult` takes placeholders, so it needs an `@applyConfigurationResult` block in `app_en.arb` declaring both as `num` with `plural` handling. Follow an existing pluralized key in that file for the exact shape.

- [ ] **Step 2: Write the failing service test**

Create `test/features/cylinder_configs/data/cylinder_config_apply_service_test.dart`. Reuse the same in-memory fixture as Task 11.

```dart
  // Helper: seed a dive plus a config, returning (diveId, configId).
  Future<String> seedConfig() async {
    final id = await configRepository.createConfig(name: 'JJ trimix');
    await configRepository.saveItems(id, [
      item(id: 'i1', configId: id, role: TankRole.diluent, order: 0, o2: 18,
          he: 45, volume: 3, pressure: 232),
      item(id: 'i2', configId: id, role: TankRole.oxygenSupply, order: 1,
          o2: 100, volume: 3, pressure: 232),
      item(id: 'i3', configId: id, role: TankRole.bailout, order: 2, o2: 21,
          volume: 11.1, pressure: 207),
    ]);
    return id;
  }

  test('applying to a dive with no cylinders inserts all of them', () async {
    final diveId = await seedDive();
    final configId = await seedConfig();

    final plan = await service.applyToDive(
      diveId: diveId,
      configId: configId,
    );

    expect(plan.insertedCount, 3);
    expect(plan.keptCount, 0);

    final tanks = await db
        .customSelect(
          "SELECT tank_role, o2_percent, he_percent, tank_order "
          "FROM dive_tanks WHERE dive_id = '$diveId' ORDER BY tank_order",
        )
        .get();
    expect(tanks.map((t) => t.read<String>('tank_role')), [
      'diluent',
      'oxygenSupply',
      'bailout',
    ]);
    expect(tanks.first.read<double>('o2_percent'), 18);
    expect(tanks.first.read<double>('he_percent'), 45);
  });

  test('applying preserves a downloaded diluent gas mix', () async {
    final diveId = await seedDive();
    final configId = await seedConfig();

    // A Shearwater download already supplied the diluent as air.
    await db.customStatement(
      "INSERT INTO dive_tanks "
      "(id, dive_id, tank_role, o2_percent, he_percent, tank_order) "
      "VALUES ('t1', '$diveId', 'diluent', 21, 0, 0)",
    );

    final plan = await service.applyToDive(
      diveId: diveId,
      configId: configId,
    );

    expect(plan.keptCount, 1);
    expect(plan.insertedCount, 2);

    final diluent = await db
        .customSelect(
          "SELECT o2_percent, he_percent, volume, working_pressure "
          "FROM dive_tanks WHERE id = 't1'",
        )
        .getSingle();
    expect(diluent.read<double>('o2_percent'), 21,
        reason: 'downloaded gas must never be overwritten');
    expect(diluent.read<double>('he_percent'), 0);
    // Null spec columns ARE filled from the config.
    expect(diluent.read<double?>('volume'), 3);
    expect(diluent.read<double?>('working_pressure'), 232);
  });

  test('applying twice is idempotent (second run adds nothing)', () async {
    final diveId = await seedDive();
    final configId = await seedConfig();

    await service.applyToDive(diveId: diveId, configId: configId);
    final second = await service.applyToDive(
      diveId: diveId,
      configId: configId,
    );

    expect(second.insertedCount, 0);
    expect(second.keptCount, 3);

    final count = await db
        .customSelect(
          "SELECT COUNT(*) AS c FROM dive_tanks WHERE dive_id = '$diveId'",
        )
        .getSingle();
    expect(count.read<int>('c'), 3);
  });

  test('applying fills only null columns on a claimed tank', () async {
    final diveId = await seedDive();
    final configId = await seedConfig();

    await db.customStatement(
      "INSERT INTO dive_tanks "
      "(id, dive_id, tank_role, o2_percent, he_percent, volume, "
      " tank_name, tank_order) "
      "VALUES ('t1', '$diveId', 'bailout', 21, 0, 5.7, 'My AL40', 0)",
    );

    await service.applyToDive(diveId: diveId, configId: configId);

    final tank = await db
        .customSelect(
          "SELECT volume, working_pressure, tank_name "
          "FROM dive_tanks WHERE id = 't1'",
        )
        .getSingle();
    expect(tank.read<double?>('volume'), 5.7, reason: 'already set');
    expect(tank.read<String?>('tank_name'), 'My AL40', reason: 'already set');
    expect(tank.read<double?>('working_pressure'), 207, reason: 'was null');
  });

  test('inserted tanks continue the existing tank_order', () async {
    final diveId = await seedDive();
    final configId = await seedConfig();

    await db.customStatement(
      "INSERT INTO dive_tanks "
      "(id, dive_id, tank_role, o2_percent, he_percent, tank_order) "
      "VALUES ('t1', '$diveId', 'stage', 50, 0, 4)",
    );

    await service.applyToDive(diveId: diveId, configId: configId);

    final orders = await db
        .customSelect(
          "SELECT tank_order FROM dive_tanks WHERE dive_id = '$diveId' "
          "ORDER BY tank_order",
        )
        .get();
    expect(orders.map((r) => r.read<int>('tank_order')), [4, 5, 6, 7]);
  });
```

Provide `seedDive()` as a helper inserting one minimal `dives` row and returning its id, and `item(...)` as in Task 11 with the extra `he`, `volume`, and `pressure` named parameters wired to `hePercent`, `volumeL`, and `workingPressureBar`.

The idempotency test is the one that catches a real bug: a second apply must find every role already claimed and insert nothing.

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/features/cylinder_configs/data/cylinder_config_apply_service_test.dart`
Expected: FAIL — the service does not exist.

- [ ] **Step 4: Write the apply service**

Create `cylinder_config_apply_service.dart`. It:

1. Loads the dive's `dive_tanks` rows and maps them to `ExistingTank`.
2. Loads the config with items.
3. Calls `const CylinderConfigApplier().plan(...)`.
4. In one transaction, executes each op: `InsertTank` inserts a new `dive_tanks` row (new UUID, `diveId`, all item fields, `tankOrder` from the op); `FillTank` writes only the non-null fields of the op.
5. Calls `SyncEventBus.notifyLocalChange()`.
6. Returns the plan.

The service must never write `o2Percent` or `hePercent` on a `FillTank` — `FillTank` has no such fields, so this is structurally impossible. Do not add them.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/cylinder_configs/data/cylinder_config_apply_service_test.dart`
Expected: all PASS.

- [ ] **Step 6: Write the failing menu test**

Create `test/features/cylinder_configs/presentation/apply_configuration_menu_test.dart`:

```dart
  testWidgets('configs are grouped by owning unit with a Gas plans section',
      ...);
  testWidgets('choosing a config shows the added/kept summary', ...);
  testWidgets('the menu is hidden when the diver has no configs', ...);
```

- [ ] **Step 7: Build the menu and wire it into the cylinders card**

`apply_configuration_menu.dart` is a `PopupMenuButton` (or equivalent) that lists configs grouped by owning unit, with generic ones under `applyConfigurationGasPlans`. On selection it calls the apply service, invalidates the dive's tank providers, and shows a snackbar with `applyConfigurationResult` (or `applyConfigurationNothingToDo` when both counts are zero).

Capture the `ScaffoldMessengerState` **before** the `await`, and do not let the snackbar's action closure capture a `BuildContext` that may be disposed. This trap has produced a real crash in this codebase.

Add the menu to `cylinders_card.dart` beside the existing add-cylinder affordance.

- [ ] **Step 8: Run tests to verify they pass**

Run: `flutter test test/features/cylinder_configs/`
Expected: all PASS.

- [ ] **Step 9: Run the dive log suite**

Run: `flutter test test/features/dive_log/`
Expected: all pass. `cylinders_card.dart` is shared, so text-finder counts in its consumer tests may need updating.

- [ ] **Step 10: Commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "Apply cylinder configurations to dives with a conservative merge (#804)"
```

---

### Task 16: Configurations card on the rebreather detail page

**Files:**
- Create: `lib/features/cylinder_configs/presentation/widgets/unit_configurations_card.dart`
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page.dart`
- Test: `test/features/cylinder_configs/presentation/unit_configurations_card_test.dart`

**Interfaces:**
- Consumes: `cylinderConfigsForEquipmentProvider` (Task 13).
- Produces: nothing consumed downstream. This closes the issue's "configurations for each CCR" phrasing by making them reachable from the unit.

- [ ] **Step 1: Read the sibling card**

Run: `cat lib/features/equipment/presentation/widgets/service_clocks_card.dart`

Match its card chrome, empty state, and provider-watching style.

- [ ] **Step 2: Write the failing test**

Create `test/features/cylinder_configs/presentation/unit_configurations_card_test.dart`:

```dart
  testWidgets('lists the unit\'s configurations with cylinder counts', ...);
  testWidgets('shows an empty state with an add action when there are none',
      ...);
  testWidgets('the card is absent for non-rebreather equipment', ...);
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/features/cylinder_configs/presentation/unit_configurations_card_test.dart`
Expected: FAIL — the widget does not exist.

- [ ] **Step 4: Build the card and mount it**

The card lists each config with its name and cylinder count, tapping through to the edit page, plus an add action that pre-fills the owning unit. Render it in `equipment_detail_page.dart` only when the item's type is `EquipmentType.rebreather`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/cylinder_configs/presentation/unit_configurations_card_test.dart`
Expected: all PASS.

- [ ] **Step 6: Full verification**

```bash
dart format .
flutter analyze
flutter test
```

Expected: analyze clean, all tests pass. Report actual output; do not claim success without it.

If the suite is slow or flaky, note that `test/features/media/` and the backup tests have known pre-existing flakiness under full-suite runs. Re-run any failure in isolation before treating it as caused by this work.

- [ ] **Step 7: Manual smoke check**

Run: `flutter run -d macos`

1. Create a rebreather with attributes; confirm the Configurations card appears.
2. Add a config: diluent, O2 supply, two bailouts with distinct mixes.
3. Open a dive with no cylinders, apply the config, confirm four cylinders with correct roles and gases.
4. Apply the same config again, confirm nothing is added.
5. On a downloaded CCR dive that already has a diluent, apply the config and confirm the existing gas mix is unchanged and the summary reads "kept 1".
6. Delete the rebreather; confirm the config survives under "Gas plans".

- [ ] **Step 8: Commit**

```bash
dart format .
git add -A
git commit -m "Show cylinder configurations on the rebreather detail page (#804)"
```

---

## Verification checklist

Before opening a PR:

- [ ] `dart format .` produces no changes
- [ ] `flutter analyze` is clean, unpiped, with no infos
- [ ] `flutter test` passes in full
- [ ] All 11 ARB files contain every new key, and `flutter gen-l10n` produces no diff
- [ ] `grep -n "currentSchemaVersion = " lib/core/database/database.dart` still shows a value above current `origin/main`
- [ ] Manual smoke check from Task 16 Step 7 completed on macOS
- [ ] PR description contains no Claude Code attribution line and no session URL
