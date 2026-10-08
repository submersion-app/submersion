# Custom Weight Names Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let each weight row on a dive and in a weight preset carry an optional free-text name ("Top pocket", "Light canister") beside its placement type (issue #956).

**Architecture:** A new `label TEXT NOT NULL DEFAULT ''` column on `dive_weights` and `weight_preset_entries` (schema v270), carried by the domain entities, every writer and copier, the Subsurface and UDDF importers, and the UDDF exporter. Sync is table-driven and needs no per-field code. The dive editor's weight row moves out of the 6,000-line page into its own widget that gains a second-line Name field; read-only views show `Name · Type` with the type muted.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod, flutter_test, ARB localization.

**Spec:** `docs/design/specs/2026-10-05-custom-weight-names-design.md`

## Global Constraints

- Column: `label TEXT NOT NULL DEFAULT ''` on both `dive_weights` and `weight_preset_entries`; empty string means "no name". Never nullable.
- Maximum length: 256 characters (grapheme clusters, the unit `TextField.maxLength` counts). Writers store `label.trim()` capped at 256.
- The placement type (`WeightType`) is unchanged and still required; a name never replaces it.
- No data rewrite: existing rows get `''`; existing `notes` values are left alone.
- Schema rung: v270 as shipped (after the notes below, #2939 took 264, #2381 265, #1039 266, #690 267 and #401 269; 268 is held by #3043). Written as v261 while main was at 260, renumbered to 262 when #767 shipped v261 (drop diver_settings.default_ceiling_source), then to 264 when #2030 shipped v263 (diver_settings.distance_unit) with 262 held by #2991. The Task 1 steps below show the v262 numbering (predecessor v261, relaxing the v261 test); at v270 the predecessor is v269 and the relaxed test is migration_v269_hidden_built_ins_test.dart. Renumber again at merge if another rung lands first. The rung is idempotent (column-existence check) and re-asserted in `beforeOpen`. `minimumCompatibleSchemaVersion` stays 240.
- Subsurface: `<weightsystem description>` goes to `label`, never `notes`, except Subsurface's stock placement names (`integrated`, `belt`, `ankle`, `backplate`, `backplate weight`, `clip-on`; trimmed, case-insensitive), which set the type alone.
- Read-only display: `Top pocket · Trim Weights`, the `· Trim Weights` part in `colorScheme.onSurfaceVariant`; an unnamed row renders exactly as before.
- Editor: an optional Name field on a second line under each `Type | amount | delete` row, hint "e.g. Top pocket", counter visible only in the last 20 characters before the limit.
- New ARB keys go into all 11 locales (`ar de en es fr he hu it nl pt zh`), inserted next to a neighbouring key of the same group (the ARB files are feature-grouped, not sorted).
- No em-dashes anywhere (code, comments, docs, commit messages). No emojis in code.
- Run `dart format .` before every commit. Imports grouped dart, flutter, packages, local.

## Review Focus

1. **A name-only edit to an existing weight saves.** `_writeWeightDiff` skips a row whose type, amount and notes match; a changed label must count as a change and mark the row pending. Pinned in Task 2.
2. **Typing an amount, then a name, in the same row keeps both.** The amount field does not rebuild its parent, so a callback holding the build-time weight would write back the old amount when the name changes. Pinned in Task 9.
3. **Deleting a middle row keeps every other row's name and amount on the right row.** Unkeyed `initialValue` fields slide their state onto the next row. Pinned in Task 9.
4. **An older peer's weight row without a `label` key.** A new row hydrates to `''`; an existing local row keeps its name. Pinned in Task 5.
5. **Whitespace-only and over-long names, and an emoji at the 256 boundary.** Whitespace-only stores `''`; over-long is cut at 256 grapheme clusters without splitting one. Pinned in Task 2.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `lib/core/database/tables/dive_tables.dart` (modify) | `DiveWeights.label` column |
| `lib/core/database/tables/weight_tables.dart` (modify) | `WeightPresetEntries.label` column |
| `lib/core/database/migrations/helpers/weight_migrations.dart` (modify) | `_assertWeightLabelColumns` idempotent DDL |
| `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (modify) | v262 rung |
| `lib/core/database/migrations/before_open.dart` (modify) | v262 backstop |
| `lib/core/database/database.dart` (modify) | `currentSchemaVersion`, `migrationVersions` |
| `lib/features/dive_log/domain/entities/weight_label.dart` (create) | `weightLabelMaxLength`, `normalizeWeightLabel` |
| `lib/features/dive_log/domain/entities/dive_weight.dart` (modify) | `label` field |
| `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (modify) | write/read/diff `label` |
| `lib/features/weight_presets/domain/entities/weight_preset.dart` (modify) | `WeightPresetEntry.label`, `WeightEntryDraft.label`, `toDiveWeights` |
| `lib/features/weight_presets/data/repositories/weight_preset_repository.dart` (modify) | write/read `label` |
| `lib/features/dive_log/domain/services/dive_merge_builder.dart` (modify) | carry `label` |
| `lib/features/dive_centers/domain/services/rental_memory_resolver.dart` (modify) | carry `label` |
| `lib/features/dive_log/data/services/bulk_dive_edit_service.dart` (modify) | undo restores `label` |
| `lib/features/universal_import/data/parsers/subsurface_xml_parser.dart` (modify) | description to `label` |
| `lib/features/dive_import/data/services/import_weight_mapper.dart` (create) | parsed weight map to `DiveWeight` |
| `lib/features/dive_import/data/services/uddf_entity_importer.dart` (modify) | use the mapper |
| `lib/core/services/export/uddf/uddf_export_builders.dart` (modify) | write `<label>` |
| `lib/core/services/export/uddf/uddf_full_import_service.dart` (modify) | read `<label>` |
| `lib/l10n/arb/app_*.arb` (modify, 11 files) | 3 new keys |
| `lib/features/dive_log/presentation/widgets/weight_name_text.dart` (create) | `weightDisplayName`, `WeightNameText` |
| `lib/features/dive_log/presentation/widgets/weight_label_field.dart` (create) | the Name text field |
| `lib/features/dive_log/presentation/widgets/dive_weight_entry_row.dart` (create) | one editable weight row |
| `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (modify) | use the row widget |
| `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (modify) | named rows in the weight card |
| `lib/features/dive_centers/presentation/widgets/rental_memory_card.dart` (modify) | named weights |
| `lib/features/weight_presets/presentation/pages/weight_preset_editor_page.dart` (modify) | Name field per row |
| `lib/features/dive_log/query/dive_child_query_entities.dart` (modify) | `weights.label` query field |
| `lib/features/query/presentation/query_label_lookup.dart` (modify) | label for the query field |

---

### Task 1: Schema v262, the `label` columns

**Files:**
- Modify: `lib/core/database/tables/dive_tables.dart` (class `DiveWeights`, after `notes`)
- Modify: `lib/core/database/tables/weight_tables.dart` (class `WeightPresetEntries`, after `notes`)
- Modify: `lib/core/database/migrations/helpers/weight_migrations.dart`
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (append after the v261 block)
- Modify: `lib/core/database/migrations/before_open.dart` (after the v259 usage_duration backstop; as shipped, the call lives in `before_open_child_columns.dart`, see Task 11)
- Modify: `lib/core/database/database.dart:235` and the end of `migrationVersions` (~line 1084)
- Modify: `test/core/database/migration_v261_drop_ceiling_source_test.dart` (relax the exact assertion)
- Test: `test/core/database/migration_v262_weight_labels_test.dart` (create)

**Interfaces:**
- Produces: Drift columns `DiveWeights.label` and `WeightPresetEntries.label` (`TextColumn`, default `''`); generated row classes `DiveWeight.label` / `WeightPresetEntryRow.label` (`String`) and companion fields `label: Value<String>`.

- [ ] **Step 1: Write the failing migration test**

Create `test/core/database/migration_v262_weight_labels_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v262: dive_weights.label and weight_preset_entries.label, a diver's
/// own name for a weight such as "Top pocket" (issue #956).
void main() {
  /// A v261 database whose weight tables lack the column, each with one row.
  NativeDatabase setupDb({int version = 261}) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute(
        'CREATE TABLE dive_weights (id TEXT NOT NULL PRIMARY KEY, '
        'dive_id TEXT NOT NULL, weight_type TEXT NOT NULL, '
        'amount_kg REAL NOT NULL, '
        "notes TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL)",
      );
      rawDb.execute(
        'CREATE TABLE weight_preset_entries (id TEXT NOT NULL PRIMARY KEY, '
        'preset_id TEXT NOT NULL, weight_type TEXT NOT NULL, '
        "amount_kg REAL NOT NULL, notes TEXT NOT NULL DEFAULT '', "
        'sort_order INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL)',
      );
      rawDb.execute(
        'INSERT INTO dive_weights '
        '(id, dive_id, weight_type, amount_kg, notes, created_at) '
        "VALUES ('w1', 'd1', 'belt', 4.0, 'from subsurface', 1)",
      );
      rawDb.execute(
        'INSERT INTO weight_preset_entries '
        '(id, preset_id, weight_type, amount_kg, created_at) '
        "VALUES ('e1', 'p1', 'trimWeights', 1.0, 1)",
      );
    },
  );

  test('v262 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 262);
    expect(AppDatabase.migrationVersions, contains(262));
    expect(AppDatabase.migrationStepCount(261), 1);
  });

  test('the columns are defaulted, so the sync floor does not move', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test('upgrading from v261 names nothing and keeps notes', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    final weight = await db
        .customSelect('SELECT notes, label FROM dive_weights')
        .getSingle();
    expect(weight.read<String>('label'), '');
    expect(weight.read<String>('notes'), 'from subsurface');
    final entry = await db
        .customSelect('SELECT label FROM weight_preset_entries')
        .getSingle();
    expect(entry.read<String>('label'), '');
  });

  test(
    'a database already stamped 262 without the columns gains them on open',
    () async {
      // A renumbered rung, or a restore of a file whose tables predate it:
      // the beforeOpen backstop adds what the ladder did not.
      final db = AppDatabase(setupDb(version: 262));
      addTearDown(db.close);
      final weight = await db
          .customSelect('SELECT label FROM dive_weights')
          .getSingle();
      expect(weight.read<String>('label'), '');
      final entry = await db
          .customSelect('SELECT label FROM weight_preset_entries')
          .getSingle();
      expect(entry.read<String>('label'), '');
    },
  );
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/database/migration_v262_weight_labels_test.dart`
Expected: FAIL (`currentSchemaVersion` is 261; `no such column: label`).

- [ ] **Step 3: Declare the columns**

In `lib/core/database/tables/dive_tables.dart`, class `DiveWeights`, directly after the `notes` getter:

```dart
  /// The diver's own name for this weight, e.g. "Top pocket" (issue #956).
  /// Empty when unnamed; the placement stays in [weightType].
  TextColumn get label => text().withDefault(const Constant(''))();
```

In `lib/core/database/tables/weight_tables.dart`, class `WeightPresetEntries`, directly after the `notes` getter:

```dart
  /// The diver's own name for this entry, copied to and from a dive's
  /// weights (issue #956). Empty when unnamed.
  TextColumn get label => text().withDefault(const Constant(''))();
```

- [ ] **Step 4: Add the idempotent DDL helper**

Append inside `extension WeightMigrations on AppDatabase` in `lib/core/database/migrations/helpers/weight_migrations.dart`:

```dart
  /// Idempotent DDL for the v262 weight name columns (issue #956) on
  /// dive_weights and weight_preset_entries. Called from the v262 rung and
  /// re-asserted in beforeOpen, so a database that arrives by restore or
  /// sync-adopt, or one a renumbered rung skipped, still gains them.
  Future<void> _assertWeightLabelColumns() async {
    for (final table in const ['dive_weights', 'weight_preset_entries']) {
      final cols = await customSelect("PRAGMA table_info('$table')").get();
      if (cols.isEmpty) continue;
      final names = cols.map((c) => c.read<String>('name')).toSet();
      if (names.contains('label')) continue;
      await customStatement(
        "ALTER TABLE $table ADD COLUMN label TEXT NOT NULL DEFAULT ''",
      );
    }
  }
```

- [ ] **Step 5: Add the rung, the backstop and the version**

Append after the v261 block in `lib/core/database/migrations/ladder/rungs_v231_onward.dart`:

```dart
    // v262: dive_weights.label and weight_preset_entries.label, a diver's
    // own name for a weight (issue #956). Defaulted columns, no backfill:
    // existing rows read '' (unnamed). Re-asserted in beforeOpen.
    if (from < 262) {
      await _assertWeightLabelColumns();
    }
    if (from < 262) await reportProgress();
```

In `lib/core/database/migrations/before_open.dart`, directly after the `await _assertTankUsageDurationColumn();` backstop (as shipped, both calls moved to `before_open_child_columns.dart` to keep `before_open.dart` under the 800-line guard):

```dart

    // v262 backstop: re-assert the weight name columns (issue #956).
    // Defaulted columns only, no backfill.
    await _assertWeightLabelColumns();
```

In `lib/core/database/database.dart` set `static const int currentSchemaVersion = 262;` and append to `migrationVersions` after `261,`:

```dart
    // v262: dive_weights.label and weight_preset_entries.label, a diver's own
    // name for a weight (issue #956). Additive defaulted columns, so the
    // floor stays: an older peer's payload omits the key and the row keeps
    // its local value or the '' default.
    262,
```

- [ ] **Step 6: Relax the v261 test**

In `test/core/database/migration_v261_drop_ceiling_source_test.dart`, replace the first test body with:

```dart
  test('v261 is at or below the current schema version and in the ladder', () {
    // Relaxed once v262 (weight names, #956) landed on top; the newest rung
    // owns the exact assertions.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(261));
    expect(AppDatabase.migrationVersions, contains(261));
    expect(
      AppDatabase.migrationStepCount(260),
      AppDatabase.migrationStepCount(261) + 1,
    );
  });
```

- [ ] **Step 7: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: completes; `database.g.dart` now has `label` on `DiveWeight` and `WeightPresetEntryRow`.

- [ ] **Step 8: Run the migration tests to verify they pass**

Run: `flutter test test/core/database/migration_v262_weight_labels_test.dart test/core/database/migration_v261_drop_ceiling_source_test.dart test/core/database/migration_v260_tank_shared_computers_test.dart`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
dart format .
git add lib/core/database test/core/database/migration_v262_weight_labels_test.dart test/core/database/migration_v261_drop_ceiling_source_test.dart
git commit -m "feat(dive-log): add weight label columns (schema v262)"
```

(Generated `*.g.dart` files are committed if the repo tracks them: check `git status` and add any changed `lib/core/database/*.g.dart`.)

---

### Task 2: Domain `label` and the dive repository

**Files:**
- Create: `lib/features/dive_log/domain/entities/weight_label.dart`
- Modify: `lib/features/dive_log/domain/entities/dive_weight.dart`
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (create batch ~1746, `_loadWeightsForDive` ~4720, `_writeWeightDiff` ~6372-6420, `_weightCompanion` ~7024)
- Test: `test/features/dive_log/domain/entities/weight_label_test.dart` (create)
- Test: `test/features/dive_log/domain/entities/dive_weight_test.dart` (create)
- Test: `test/features/dive_log/data/repositories/dive_repository_child_diff_test.dart` (add a group)

**Interfaces:**
- Consumes: Task 1 columns.
- Produces: `const int weightLabelMaxLength = 256;`, `String normalizeWeightLabel(String raw)`, `DiveWeight.label` (`String`, default `''`), `DiveWeight.copyWith({..., String? label})`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/dive_log/domain/entities/weight_label_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/weight_label.dart';

void main() {
  test('trims surrounding whitespace', () {
    expect(normalizeWeightLabel('  Top pocket \n'), 'Top pocket');
  });

  test('whitespace only is no name', () {
    expect(normalizeWeightLabel('   '), '');
  });

  test('keeps a name at the limit and cuts one past it', () {
    final atLimit = 'a' * weightLabelMaxLength;
    expect(normalizeWeightLabel(atLimit), atLimit);
    expect(normalizeWeightLabel('${atLimit}b'), atLimit);
  });

  test('never splits a grapheme cluster at the limit', () {
    // A flag is two code points (four UTF-16 units) but one character.
    final flag = String.fromCharCodes([0x1F1F3, 0x1F1F1]);
    final kept = '${'a' * (weightLabelMaxLength - 1)}$flag';
    expect(normalizeWeightLabel('${kept}zz'), kept);
  });
}
```

Create `test/features/dive_log/domain/entities/dive_weight_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';

void main() {
  const weight = DiveWeight(
    id: 'w1',
    diveId: 'd1',
    weightType: WeightType.trimWeights,
    amountKg: 2,
  );

  test('a weight is unnamed by default', () {
    expect(weight.label, '');
  });

  test('copyWith sets and clears the name', () {
    final named = weight.copyWith(label: 'Top pocket');
    expect(named.label, 'Top pocket');
    expect(named.copyWith(label: '').label, '');
    expect(named.copyWith(amountKg: 3).label, 'Top pocket');
  });

  test('the name takes part in equality', () {
    expect(weight.copyWith(label: 'Top pocket'), isNot(weight));
  });
}
```

In `test/features/dive_log/data/repositories/dive_repository_child_diff_test.dart`, give the `weight(...)` helper a `String label = ''` parameter passed as `label: label`, then add this group inside `main` after the `weights` group:

```dart
  group('weight names (#956)', () {
    test('createDive stores the name and getDiveById reads it', () async {
      final dive = await seed(
        weights: [weight('w1', WeightType.trimWeights, 2, label: 'Top pocket')],
      );
      expect(dive.weights.single.label, 'Top pocket');
      expect((await weightRows()).single.label, 'Top pocket');
    });

    test('a name-only edit is written and re-marked', () async {
      final dive = await seed(weights: [weight('w1', WeightType.belt, 4)]);
      await markEverythingSynced('diveWeights');

      await repo.updateDive(
        dive.copyWith(
          weights: [weight('w1', WeightType.belt, 4, label: '2nd pocket')],
        ),
      );

      expect(await pendingFor('diveWeights'), {'w1'});
      expect((await weightRows()).single.label, '2nd pocket');
    });

    test('clearing a name writes the empty name', () async {
      final dive = await seed(
        weights: [weight('w1', WeightType.belt, 4, label: 'Top pocket')],
      );
      await repo.updateDive(
        dive.copyWith(weights: [weight('w1', WeightType.belt, 4)]),
      );
      expect((await weightRows()).single.label, '');
    });

    test('the stored name is trimmed', () async {
      await seed(
        weights: [weight('w1', WeightType.belt, 4, label: '  Top pocket  ')],
      );
      expect((await weightRows()).single.label, 'Top pocket');
    });

    test('bulkAddWeights stores the name', () async {
      await seed();
      await repo.bulkAddWeights(['dv'], [
        weight('', WeightType.belt, 1, label: 'Light canister'),
      ]);
      expect((await weightRows()).single.label, 'Light canister');
    });
  });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/dive_log/domain/entities/weight_label_test.dart test/features/dive_log/domain/entities/dive_weight_test.dart test/features/dive_log/data/repositories/dive_repository_child_diff_test.dart`
Expected: FAIL to compile (`weight_label.dart` missing, no `label` parameter).

- [ ] **Step 3: Create the normalizer**

Create `lib/features/dive_log/domain/entities/weight_label.dart`:

```dart
import 'package:flutter/widgets.dart' show StringCharacters;

/// The longest name a weight row stores (issue #956), in characters as a
/// text field counts them (grapheme clusters).
const int weightLabelMaxLength = 256;

/// [raw] as a weight name is stored: trimmed, and cut to
/// [weightLabelMaxLength] characters without splitting one. Whitespace only
/// becomes '' (unnamed).
String normalizeWeightLabel(String raw) {
  final trimmed = raw.trim();
  final characters = trimmed.characters;
  if (characters.length <= weightLabelMaxLength) return trimmed;
  return characters.take(weightLabelMaxLength).toString().trimRight();
}
```

- [ ] **Step 4: Add `label` to `DiveWeight`**

Replace the body of `lib/features/dive_log/domain/entities/dive_weight.dart` with:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// Weight entry for a dive (supports multiple weight types per dive)
class DiveWeight extends Equatable {
  final String id;
  final String diveId;
  final WeightType weightType;
  final double amountKg;
  final String notes;

  /// The diver's own name for this weight, e.g. "Top pocket" (issue #956).
  /// Empty when unnamed; [weightType] still says where it is carried.
  final String label;

  const DiveWeight({
    required this.id,
    required this.diveId,
    required this.weightType,
    required this.amountKg,
    this.notes = '',
    this.label = '',
  });

  /// Create a copy with updated fields
  DiveWeight copyWith({
    String? id,
    String? diveId,
    WeightType? weightType,
    double? amountKg,
    String? notes,
    String? label,
  }) {
    return DiveWeight(
      id: id ?? this.id,
      diveId: diveId ?? this.diveId,
      weightType: weightType ?? this.weightType,
      amountKg: amountKg ?? this.amountKg,
      notes: notes ?? this.notes,
      label: label ?? this.label,
    );
  }

  @override
  List<Object?> get props => [id, diveId, weightType, amountKg, notes, label];
}
```

- [ ] **Step 5: Write and read `label` in the dive repository**

In `lib/features/dive_log/data/repositories/dive_repository_impl.dart` add the import
`import 'package:submersion/features/dive_log/domain/entities/weight_label.dart';`
in the local group, then:

1. In the create batch (`// Insert weights`, the `DiveWeightsCompanion(` with `notes: Value(weight.notes),`), add after `notes`:
   ```dart
                label: Value(normalizeWeightLabel(weight.label)),
   ```
2. In `_loadWeightsForDive`, add after `notes: row.notes,`:
   ```dart
              label: row.label,
   ```
3. In `_writeWeightDiff`, make the unchanged check include the name and write it on both branches:
   ```dart
      final label = normalizeWeightLabel(weight.label);
      if (current != null &&
          current.weightType == weight.weightType.name &&
          current.amountKg == weight.amountKg &&
          current.notes == weight.notes &&
          current.label == label) {
        continue;
      }
   ```
   and add `label: Value(label),` after `notes: Value(weight.notes),` in both the `update(...).write(DiveWeightsCompanion(...))` and the `insert(DiveWeightsCompanion(...))` calls.
4. In `_weightCompanion`, add after `notes: Value(w.notes),`:
   ```dart
    label: Value(normalizeWeightLabel(w.label)),
   ```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/features/dive_log/domain/entities/weight_label_test.dart test/features/dive_log/domain/entities/dive_weight_test.dart test/features/dive_log/data/repositories/dive_repository_child_diff_test.dart test/features/dive_log/data/repositories/dive_repository_bulk_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/features/dive_log/domain/entities/weight_label.dart lib/features/dive_log/domain/entities/dive_weight.dart lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/domain/entities/weight_label_test.dart test/features/dive_log/domain/entities/dive_weight_test.dart test/features/dive_log/data/repositories/dive_repository_child_diff_test.dart
git commit -m "feat(dive-log): store a name on each dive weight"
```

---

### Task 3: Weight presets carry the name

**Files:**
- Modify: `lib/features/weight_presets/domain/entities/weight_preset.dart`
- Modify: `lib/features/weight_presets/data/repositories/weight_preset_repository.dart` (~112, ~149, ~240, `_mapEntry` ~314)
- Modify: `lib/features/weight_presets/presentation/pages/weight_preset_editor_page.dart:127` (interim `label: ''`, replaced in Task 9)
- Modify: `test/features/weight_presets/weight_preset_repository_test.dart` (record literals at ~170, ~209)
- Test: `test/features/weight_presets/domain/entities/weight_preset_test.dart`, `test/features/weight_presets/weight_preset_repository_test.dart`

**Interfaces:**
- Consumes: `DiveWeight.label`, `normalizeWeightLabel` (Task 2).
- Produces: `WeightEntryDraft = ({WeightType weightType, double amountKg, String notes, String label})`; `WeightPresetEntry.label` (`String`, default `''`); `WeightPreset.toDiveWeights` copies `label`.

- [ ] **Step 1: Write the failing tests**

In `test/features/weight_presets/domain/entities/weight_preset_test.dart` add:

```dart
  test('toDiveWeights carries each entry\'s name', () {
    final named = WeightPreset(
      id: 'p2',
      displayName: 'Sidemount',
      createdAt: now,
      updatedAt: now,
      entries: const [
        WeightPresetEntry(
          id: 'e1',
          presetId: 'p2',
          weightType: WeightType.trimWeights,
          amountKg: 2,
          label: 'Top pocket',
        ),
      ],
    );
    final rows = named.toDiveWeights(diveId: 'dv', newId: () => 'n');
    expect(rows.single.label, 'Top pocket');
  });
```

In `test/features/weight_presets/weight_preset_repository_test.dart`, add `label: ''` to every `(weightType: ..., amountKg: ..., notes: ...)` record literal, then add:

```dart
  test('createFromWeights keeps each weight\'s name', () async {
    final preset = await repo.createFromWeights(
      diverId: diverId,
      displayName: 'Sidemount',
      weights: [
        _w(WeightType.trimWeights, 2).copyWith(label: 'Top pocket'),
        _w(WeightType.trimWeights, 1).copyWith(label: '  2nd pocket '),
      ],
    );
    expect(preset.entries.map((e) => e.label).toList(), [
      'Top pocket',
      '2nd pocket',
    ]);
    final reread = (await repo.getPresets(diverId: diverId)).single;
    expect(reread.entries.map((e) => e.label).toList(), [
      'Top pocket',
      '2nd pocket',
    ]);
  });

  test('updatePreset writes the entries\' names', () async {
    final preset = await repo.createFromWeights(
      diverId: diverId,
      displayName: 'Sidemount',
      weights: [_w(WeightType.trimWeights, 2)],
    );
    await repo.updatePreset(
      id: preset.id,
      displayName: 'Sidemount',
      entries: [
        (
          weightType: WeightType.trimWeights,
          amountKg: 2,
          notes: '',
          label: 'Top pocket',
        ),
      ],
    );
    final reread = (await repo.getPresets(diverId: diverId)).single;
    expect(reread.entries.single.label, 'Top pocket');
  });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/weight_presets`
Expected: FAIL to compile (no `label` on `WeightPresetEntry` or the record).

- [ ] **Step 3: Add `label` to the preset entity and draft**

In `lib/features/weight_presets/domain/entities/weight_preset.dart`:

- `toDiveWeights`: add `label: e.label,` after `notes: e.notes,`.
- `WeightEntryDraft`: add the field so it reads
  ```dart
  typedef WeightEntryDraft = ({
    WeightType weightType,
    double amountKg,
    String notes,
    String label,
  });
  ```
- `WeightPresetEntry`: add the field, constructor parameter and prop:
  ```dart
    /// The diver's own name for this entry (issue #956); '' when unnamed.
    final String label;
  ```
  constructor `this.label = '',` after `this.notes = '',`, and `label,` in `props` after `notes,`.

- [ ] **Step 4: Write and read `label` in the preset repository**

In `lib/features/weight_presets/data/repositories/weight_preset_repository.dart` add the import
`import 'package:submersion/features/dive_log/domain/entities/weight_label.dart';`, then:

- `createFromWeights`: the record becomes
  `(weightType: w.weightType, amountKg: w.amountKg, notes: w.notes, label: w.label),`
- In both `WeightPresetEntriesCompanion(` inserts (`createPreset` and `updatePreset`), add after `notes: Value(entries[i].notes),`:
  ```dart
                label: Value(normalizeWeightLabel(entries[i].label)),
  ```
- `_mapEntry`: add `label: row.label,` after `notes: row.notes,`.

In `lib/features/weight_presets/presentation/pages/weight_preset_editor_page.dart:127`, keep it compiling until Task 9 gives the editor a Name field:

```dart
          (
            weightType: r.type,
            amountKg: units.weightToKg(amount),
            notes: '',
            label: '',
          ),
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/weight_presets test/features/dive_log/presentation/pages/dive_edit_weight_preset_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/weight_presets test/features/weight_presets
git commit -m "feat(weight-presets): keep weight names in presets"
```

---

### Task 4: Copiers keep the name

**Files:**
- Modify: `lib/features/dive_log/domain/services/dive_merge_builder.dart:234-243`
- Modify: `lib/features/dive_centers/domain/services/rental_memory_resolver.dart:44-56`
- Modify: `lib/features/dive_log/data/services/bulk_dive_edit_service.dart:391-403`
- Test: `test/features/dive_log/domain/services/dive_merge_builder_test.dart`
- Test: `test/features/dive_centers/domain/services/rental_memory_resolver_test.dart`
- Test: `test/features/dive_log/data/services/bulk_dive_edit_service_test.dart`
- Test: `test/features/dive_log/data/services/dive_consolidation_service_test.dart`

**Interfaces:**
- Consumes: `DiveWeight.label`, `DiveWeight.copyWith` (Task 2).

- [ ] **Step 1: Write the failing tests**

`dive_merge_builder_test.dart`, next to `weights come from the first dive that has any`:

```dart
    test('merged weights keep their names', () {
      final a = dive('a', entry: DateTime.utc(2026, 7, 1, 9)).copyWith(
        weights: [
          const DiveWeight(
            id: 'w1',
            diveId: 'a',
            weightType: WeightType.trimWeights,
            amountKg: 2,
            label: 'Top pocket',
          ),
        ],
      );
      final b = dive('b', entry: DateTime.utc(2026, 7, 1, 10));
      final result = builder.build([a, b]);
      expect(result.mergedDive.weights.single.label, 'Top pocket');
    });
```

`rental_memory_resolver_test.dart`, give the `belt` constant `label: 'Rental belt'` and add to `weightsForNewDive copies type, amount and notes under fresh ids`:

```dart
    expect(copies.first.label, 'Rental belt');
    expect(copies.last.label, '');
```

`bulk_dive_edit_service_test.dart`, a new test after the replace-and-undo test:

```dart
  test('undo restores each weight\'s name', () async {
    await seed('d1');
    await diveRepo.bulkAddWeights(['d1'], [
      weight(3).copyWith(label: 'Top pocket'),
    ]);

    final snap = await service.apply(
      BulkEditRequest(
        diveIds: const ['d1'],
        ops: [
          WeightsOp(mode: BulkCollectionMode.replace, weights: [weight(9)]),
        ],
      ),
    );
    await service.undo(snap);

    final rows = await (db.select(
      db.diveWeights,
    )..where((t) => t.diveId.equals('d1'))).get();
    expect(rows.single.label, 'Top pocket');
  });
```

`dive_consolidation_service_test.dart`: find the existing test that consolidates a secondary carrying weights into a target with none (search the file for `diveWeights` or `weightRows`). Copy it as `'a consolidated weight keeps its name'`, seed the secondary's weight row with `label: const Value('Top pocket')` in its `DiveWeightsCompanion`, and after consolidating assert:

```dart
      final weights = await (db.select(
        db.diveWeights,
      )..where((t) => t.diveId.equals(targetDiveId))).get();
      expect(weights.single.label, 'Top pocket');
```

If the file has no such test, add one to `dive_consolidation_service_test.dart` using the file's own fixture helpers for a target and a secondary dive, inserting the secondary's weight with `db.into(db.diveWeights).insert(DiveWeightsCompanion.insert(id: 'sw1', diveId: secondaryId, weightType: 'trimWeights', amountKg: 2, createdAt: 1, label: const Value('Top pocket')))`.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/dive_log/domain/services/dive_merge_builder_test.dart test/features/dive_centers/domain/services/rental_memory_resolver_test.dart test/features/dive_log/data/services/bulk_dive_edit_service_test.dart test/features/dive_log/data/services/dive_consolidation_service_test.dart`
Expected: the merge, rental and bulk-undo name tests FAIL; the consolidation test PASSES already (it copies whole rows), which is the regression it pins.

- [ ] **Step 3: Copy with `copyWith` instead of field by field**

`dive_merge_builder.dart`, so future fields travel too:

```dart
    final mergedWeights = [
      for (final w in weightSource.weights)
        w.copyWith(id: idGen(), diveId: mergedId),
    ];
```

`rental_memory_resolver.dart`, `weightsForNewDive`:

```dart
  }) => [for (final w in weights) w.copyWith(id: newId(), diveId: diveId)];
```

`bulk_dive_edit_service.dart`, `_weightsFromRows`: add `label: r.label,` after `notes: r.notes,`.

- [ ] **Step 4: Run them to verify they pass**

Run: the Step 2 command.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/dive_log/domain/services/dive_merge_builder.dart lib/features/dive_centers/domain/services/rental_memory_resolver.dart lib/features/dive_log/data/services/bulk_dive_edit_service.dart test/features/dive_log/domain/services/dive_merge_builder_test.dart test/features/dive_centers/domain/services/rental_memory_resolver_test.dart test/features/dive_log/data/services/bulk_dive_edit_service_test.dart test/features/dive_log/data/services/dive_consolidation_service_test.dart
git commit -m "feat(dive-log): keep weight names through merge, rental memory and undo"
```

---

### Task 5: Sync round trip and older peers

**Files:**
- Test: `test/core/services/sync/sync_weight_label_test.dart` (create)

**Interfaces:**
- Consumes: `SyncDataSerializer.upsertRecord(String entityType, Map<String, dynamic> data)` and `fetchRecord(String entityType, String id)`; Task 1 columns.

No production change is expected: both tables are serialized by table, and `_withSchemaDefaults` / `_withLocalForOmitted` fill a key an older peer omits. These tests pin that.

- [ ] **Step 1: Write the tests**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// Weight names (issue #956) through the sync serializer: a named row
/// round-trips, and a row from a peer that predates the column (no `label`
/// key) neither throws nor wipes a local name.
void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    // The rows reference a dive and a preset this test never creates.
    await db.customStatement('PRAGMA foreign_keys = OFF');
  });

  tearDown(tearDownTestDatabase);

  Map<String, dynamic> weightRow({String? label}) => {
    'id': 'w1',
    'diveId': 'd1',
    'weightType': 'trimWeights',
    'amountKg': 2.0,
    'notes': '',
    'createdAt': 1,
    'label': ?label,
  };

  Map<String, dynamic> entryRow({String? label}) => {
    'id': 'e1',
    'presetId': 'p1',
    'weightType': 'trimWeights',
    'amountKg': 2.0,
    'notes': '',
    'sortOrder': 0,
    'createdAt': 1,
    'label': ?label,
  };

  for (final (type, row) in [
    ('diveWeights', weightRow),
    ('weightPresetEntries', entryRow),
  ]) {
    final id = type == 'diveWeights' ? 'w1' : 'e1';

    test('$type: a named row round-trips', () async {
      await serializer.upsertRecord(type, row(label: 'Top pocket'));
      final stored = await serializer.fetchRecord(type, id);
      expect(stored!['label'], 'Top pocket');
    });

    test('$type: a new row without the key arrives unnamed', () async {
      await serializer.upsertRecord(type, row());
      final stored = await serializer.fetchRecord(type, id);
      expect(stored!['label'], '');
    });

    test('$type: an older peer\'s copy keeps the local name', () async {
      await serializer.upsertRecord(type, row(label: 'Top pocket'));
      await serializer.upsertRecord(type, row()..['amountKg'] = 3.0);
      final stored = await serializer.fetchRecord(type, id);
      expect(stored!['amountKg'], 3.0);
      expect(stored['label'], 'Top pocket');
    });
  }
}
```

If the repo's Dart language version rejects null-aware map elements (`'label': ?label`), write `if (label != null) 'label': label,` instead.

- [ ] **Step 2: Run them**

Run: `flutter test test/core/services/sync/sync_weight_label_test.dart test/core/services/sync/sync_serializer_upsert_test.dart`
Expected: PASS. If "an older peer's copy keeps the local name" fails, the overlay does not cover this entity: read `_withLocalForOmitted` in `lib/core/services/sync/sync_data_serializer.dart`, add the entity the same way the others are covered, and re-run.

- [ ] **Step 3: Commit**

```bash
dart format .
git add test/core/services/sync/sync_weight_label_test.dart
git commit -m "test(sync): pin weight names across older peers"
```

---

### Task 6: Importers and the UDDF exporter

**Files:**
- Modify: `lib/features/universal_import/data/parsers/subsurface_xml_parser.dart:1215-1226`
- Create: `lib/features/dive_import/data/services/import_weight_mapper.dart`
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart:2528-2543`
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart:630-635`
- Modify: `lib/core/services/export/uddf/uddf_full_import_service.dart:1606-1608`
- Test: `test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart` (group `weights`)
- Test: `test/features/dive_import/data/services/import_weight_mapper_test.dart` (create)
- Test: `test/core/services/export/uddf/uddf_weight_labels_round_trip_test.dart` (create)

**Interfaces:**
- Consumes: `DiveWeight.label`, `normalizeWeightLabel`.
- Produces: parsed weight maps carry `'label': String`; `DiveWeight weightFromImportData(Map<String, dynamic> data, {required String id, required String diveId})`.

- [ ] **Step 1: Write the failing tests**

Subsurface, replace the last assertion of `parses weight amount and maps description to WeightType` (`expect(weights[0]['notes'], 'belt');`) with:

```dart
      // 'belt' is a stock Subsurface name: it sets the type, not a name.
      expect(weights[0]['label'], '');
      expect(weights[0].containsKey('notes'), isFalse);
```

and add to the same group:

```dart
    test('a custom description becomes the weight\'s name', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <weightsystem weight='2.0 kg' description='Top pocket' />
  <weightsystem weight='1.0 kg' description=' Clip-On ' />
  <weightsystem weight='3.0 kg' description='trim pocket left' />
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );
      final dive = result.entitiesOf(ImportEntityType.dives).first;
      final weights = dive['weights'] as List<Map<String, dynamic>>;
      expect(weights.map((w) => w['label']).toList(), [
        'Top pocket',
        '',
        'trim pocket left',
      ]);
      expect(weights[2]['type'], WeightType.trimWeights);
    });
```

Create `test/features/dive_import/data/services/import_weight_mapper_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_import/data/services/import_weight_mapper.dart';

void main() {
  test('maps a parsed weight, name included', () {
    final weight = weightFromImportData({
      'amount': 2.0,
      'type': WeightType.trimWeights,
      'notes': 'n',
      'label': '  Top pocket ',
    }, id: 'w1', diveId: 'd1');
    expect(weight.id, 'w1');
    expect(weight.diveId, 'd1');
    expect(weight.weightType, WeightType.trimWeights);
    expect(weight.amountKg, 2.0);
    expect(weight.notes, 'n');
    expect(weight.label, 'Top pocket');
  });

  test('missing keys fall back as before', () {
    final weight = weightFromImportData(const {}, id: 'w1', diveId: 'd1');
    expect(weight.weightType, WeightType.integrated);
    expect(weight.amountKg, 0.0);
    expect(weight.notes, '');
    expect(weight.label, '');
  });
}
```

Create `test/core/services/export/uddf/uddf_weight_labels_round_trip_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';

/// Weight names (issue #956) survive a full UDDF backup and restore.
void main() {
  final dive = Dive(
    id: 'dive-a',
    diveNumber: 1,
    dateTime: DateTime.utc(2026, 3, 1, 9),
    bottomTime: const Duration(minutes: 45),
    maxDepth: 25.0,
  );
  const weights = [
    DiveWeight(
      id: 'w1',
      diveId: 'dive-a',
      weightType: WeightType.trimWeights,
      amountKg: 2,
      label: 'Top pocket',
    ),
    DiveWeight(
      id: 'w2',
      diveId: 'dive-a',
      weightType: WeightType.belt,
      amountKg: 4,
    ),
  ];

  Future<List<Map<String, dynamic>>> restoredWeights() async {
    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: [dive],
      diveWeights: {'dive-a': weights},
    );
    final dives = (await UddfFullImportService().importAllDataFromUddf(
      xml,
    )).dives;
    return (dives.single['weights'] as List).cast<Map<String, dynamic>>();
  }

  test('a named weight comes back with its name', () async {
    final restored = await restoredWeights();
    expect(restored.map((w) => w['label']).toList(), ['Top pocket', '']);
  });

  test('an unnamed weight writes no label element', () async {
    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: [dive],
      diveWeights: {'dive-a': weights},
    );
    expect('<label>'.allMatches(xml).length, 1);
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart test/features/dive_import/data/services/import_weight_mapper_test.dart test/core/services/export/uddf/uddf_weight_labels_round_trip_test.dart`
Expected: FAIL (no `label` key; mapper file missing).

- [ ] **Step 3: Subsurface writes the name**

In `subsurface_xml_parser.dart` replace `_parseWeights` with:

```dart
  /// Parses `<weightsystem>` elements into weight maps with [WeightType] values.
  ///
  /// The description is the weight's name in Subsurface (issue #956), except
  /// its stock placement names, which only set the type: a stock 'belt' row
  /// would otherwise read "belt · Weight Belt".
  List<Map<String, dynamic>> _parseWeights(XmlElement dive) {
    final weights = <Map<String, dynamic>>[];
    for (final ws in dive.findElements('weightsystem')) {
      final amount = _parseDouble(ws.getAttribute('weight'));
      if (amount == null) continue;
      final description = (ws.getAttribute('description') ?? '').trim();
      final isStock = _stockWeightDescriptions.contains(
        description.toLowerCase(),
      );
      weights.add({
        'amount': amount,
        'type': _mapWeightType(description),
        'label': isStock ? '' : description,
      });
    }
    return weights;
  }

  /// Subsurface's built-in weight system names, current and older spellings.
  static const _stockWeightDescriptions = {
    'integrated',
    'belt',
    'ankle',
    'backplate',
    'backplate weight',
    'clip-on',
  };
```

- [ ] **Step 4: Extract the import mapper and use it**

Create `lib/features/dive_import/data/services/import_weight_mapper.dart`:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/domain/entities/weight_label.dart';

/// A parsed weight map (`amount`, `type`, `notes`, `label`, as the UDDF and
/// Subsurface readers produce it) as a [DiveWeight] for [diveId].
DiveWeight weightFromImportData(
  Map<String, dynamic> data, {
  required String id,
  required String diveId,
}) => DiveWeight(
  id: id,
  diveId: diveId,
  weightType: data['type'] as WeightType? ?? WeightType.integrated,
  amountKg: data['amount'] as double? ?? 0.0,
  notes: data['notes'] as String? ?? '',
  label: normalizeWeightLabel(data['label'] as String? ?? ''),
);
```

In `uddf_entity_importer.dart` import it and replace the `DiveWeight(...)` lambda body:

```dart
      final weights =
          weightsData
              ?.map(
                (w) => weightFromImportData(w, id: _uuid.v4(), diveId: diveId),
              )
              .toList() ??
          [];
```

Remove the `dive_weight.dart` import there only if `flutter analyze` reports it unused (the scalar fallback at ~2556 still builds a `DiveWeight`).

- [ ] **Step 5: UDDF writes and reads `<label>`**

`uddf_export_builders.dart`, after the `notes` element block:

```dart
                        if (weight.label.isNotEmpty) {
                          builder.element('label', nest: weight.label);
                        }
```

`uddf_full_import_service.dart`, after `weight['notes'] = ...;`:

```dart
          weight['label'] =
              UddfImportParsers.getElementText(weightElement, 'label') ?? '';
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: the Step 2 command plus `flutter test test/core/services/export/uddf test/features/universal_import/data/parsers`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/features/universal_import/data/parsers/subsurface_xml_parser.dart lib/features/dive_import/data/services/import_weight_mapper.dart lib/features/dive_import/data/services/uddf_entity_importer.dart lib/core/services/export/uddf/uddf_export_builders.dart lib/core/services/export/uddf/uddf_full_import_service.dart test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart test/features/dive_import/data/services/import_weight_mapper_test.dart test/core/services/export/uddf/uddf_weight_labels_round_trip_test.dart
git commit -m "feat(dive-import): import and export weight names"
```

---

### Task 7: Localization keys

**Files:**
- Modify: `lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb`
- Regenerated: `lib/l10n/arb/app_localizations*.dart`

**Interfaces:**
- Produces: `l10n.diveLog_edit_label_weightName`, `l10n.diveLog_edit_hint_weightName`, `l10n.query_weights_label`.

- [ ] **Step 1: Insert the keys with a script**

Write this to the scratchpad as `add_weight_name_keys.py` and run it with `python3.14` from the worktree root. It inserts each key on the line after its anchor key in every locale, so the feature grouping holds, and adds `@` metadata in `app_en.arb` only:

```python
import pathlib
import re

KEYS = {
    # anchor key -> list of (new key, {locale: text})
    "diveLog_edit_label_type": [
        ("diveLog_edit_label_weightName", {
            "en": "Name (optional)", "de": "Name (optional)",
            "es": "Nombre (opcional)", "fr": "Nom (facultatif)",
            "it": "Nome (facoltativo)", "nl": "Naam (optioneel)",
            "pt": "Nome (opcional)", "hu": "Név (nem kötelező)",
            "ar": "الاسم (اختياري)", "he": "שם (אופציונלי)",
            "zh": "名称（可选）",
        }),
        ("diveLog_edit_hint_weightName", {
            "en": "e.g. Top pocket", "de": "z. B. obere Tasche",
            "es": "p. ej., bolsillo superior", "fr": "p. ex. poche du haut",
            "it": "es. tasca superiore", "nl": "bijv. bovenste zak",
            "pt": "ex.: bolso superior", "hu": "pl. felső zseb",
            "ar": "مثال: الجيب العلوي", "he": "לדוגמה: כיס עליון",
            "zh": "例如：上方口袋",
        }),
    ],
    "query_weights_notes": [
        ("query_weights_label", {
            "en": "Name", "de": "Name", "es": "Nombre", "fr": "Nom",
            "it": "Nome", "nl": "Naam", "pt": "Nome", "hu": "Név",
            "ar": "الاسم", "he": "שם", "zh": "名称",
        }),
    ],
}
META = {
    "diveLog_edit_label_weightName": "Label of the optional name field under a weight row in the dive and weight preset editors",
    "diveLog_edit_hint_weightName": "Example name shown in the empty weight name field",
    "query_weights_label": "Field label in the query builder",
}

for path in sorted(pathlib.Path("lib/l10n/arb").glob("app_*.arb")):
    locale = path.stem.removeprefix("app_")
    lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        out.append(line)
        m = re.match(r'\s*"([^"@]+)":', line)
        if m and m.group(1) in KEYS:
            # Skip past this key's own @metadata line, if any.
            if i + 1 < len(lines) and lines[i + 1].lstrip().startswith(f'"@{m.group(1)}"'):
                i += 1
                out.append(lines[i])
            for key, texts in KEYS[m.group(1)]:
                if f'"{key}"' in "".join(lines):
                    continue
                out.append(f'  "{key}": "{texts[locale]}",\n')
                if locale == "en":
                    out.append(f'  "@{key}": {{"description": "{META[key]}"}},\n')
        i += 1
    path.write_text("".join(out), encoding="utf-8")
    print("OK", path)
```

If an anchor's `@` metadata spans several lines in some file (check `grep -n -A3 '"@diveLog_edit_label_type"' lib/l10n/arb/app_en.arb`), adjust the skip to the closing `},` line before running. Then check every file is valid JSON:

Run: `for f in lib/l10n/arb/*.arb; do python3.14 -c "import json,sys;json.load(open(sys.argv[1]))" "$f" || echo "BAD $f"; done`
Expected: no `BAD` lines.

- [ ] **Step 2: Regenerate and check**

Run: `flutter gen-l10n && grep -c "diveLog_edit_label_weightName\|diveLog_edit_hint_weightName\|query_weights_label" lib/l10n/arb/app_localizations_de.dart`
Expected: `3` or more.

- [ ] **Step 3: Commit**

```bash
git add lib/l10n/arb
git commit -m "feat(dive-log): add weight name strings"
```

---

### Task 8: Show names in read-only views

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/weight_name_text.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (`_buildWeightSection` ~4322, `_WeightDisplay` ~5979)
- Modify: `lib/features/dive_centers/presentation/widgets/rental_memory_card.dart:168-173`
- Test: `test/features/dive_log/presentation/widgets/weight_name_text_test.dart` (create)
- Test: `test/features/dive_log/presentation/pages/dive_detail_page_paired_sections_test.dart`
- Test: `test/features/dive_centers/presentation/widgets/rental_memory_card_test.dart`

**Interfaces:**
- Consumes: `DiveWeight.label`, `WeightType.localizedName(AppLocalizations)`.
- Produces: `String weightDisplayName(DiveWeight weight, AppLocalizations l10n)`; `class WeightNameText extends StatelessWidget { const WeightNameText(DiveWeight weight, {Key? key}); }`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/dive_log/presentation/widgets/weight_name_text_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/widgets/weight_name_text.dart';
import 'package:submersion/l10n/l10n_extension.dart';

import '../../../../helpers/test_app.dart';

void main() {
  const named = DiveWeight(
    id: 'w1',
    diveId: 'd1',
    weightType: WeightType.trimWeights,
    amountKg: 2,
    label: 'Top pocket',
  );
  const unnamed = DiveWeight(
    id: 'w2',
    diveId: 'd1',
    weightType: WeightType.belt,
    amountKg: 4,
  );

  test('weightDisplayName leads with the name', () {
    final en = l10nForLocaleTag('en');
    expect(weightDisplayName(named, en), 'Top pocket · Trim Weights');
    expect(weightDisplayName(unnamed, en), 'Weight Belt');
  });

  testWidgets('mutes the placement after a name', (tester) async {
    await tester.pumpWidget(
      testApp(locale: const Locale('en'), child: const WeightNameText(named)),
    );
    final rich = tester.widget<Text>(find.byType(Text)).textSpan! as TextSpan;
    final spans = rich.children!.cast<TextSpan>();
    expect(spans.first.text, 'Top pocket');
    expect(spans.last.text, ' · Trim Weights');
    final context = tester.element(find.byType(WeightNameText));
    expect(
      spans.last.style!.color,
      Theme.of(context).colorScheme.onSurfaceVariant,
    );
  });

  testWidgets('an unnamed weight shows its placement as before', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(locale: const Locale('en'), child: const WeightNameText(unnamed)),
    );
    expect(find.text('Weight Belt'), findsOneWidget);
  });
}
```

(`l10nForLocaleTag` is used by `test/features/query/presentation/query_labels_test.dart`; import it from wherever that file does, adjusting the import above.)

In `dive_detail_page_paired_sections_test.dart`, add a group after `Weights + Buoyancy pairing`:

```dart
  group('Weight names (#956)', () {
    testWidgets('a named weight shows its name before its placement', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final base = _diveWithGasAndWeights('weights-named');
      final dive = base.copyWith(
        weights: [
          base.weights.single.copyWith(label: 'Top pocket'),
          DiveWeight(
            id: 'w2',
            diveId: base.id,
            weightType: WeightType.trimWeights,
            amountKg: 1,
          ),
        ],
      );
      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: _settingsWithOrder([DiveDetailSectionId.weights]),
          extraOverrides: [
            ..._renderOverrides(dive.id, prefs),
            _buoyancyOverride(dive, buoyancyOutcome()),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Top pocket · Weight Belt', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Trim Weights'), findsOneWidget);
    });
  });
```

In `rental_memory_card_test.dart`, give the `belt` weight in `last` `label: 'Rental belt'` and add to `shows the last dive facts and the notes`:

```dart
    expect(find.text('Rental belt · Weight Belt 6.0 kg'), findsOneWidget);
    expect(find.text('Trim Weights 2.0 kg'), findsOneWidget);
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/weight_name_text_test.dart test/features/dive_log/presentation/pages/dive_detail_page_paired_sections_test.dart test/features/dive_centers/presentation/widgets/rental_memory_card_test.dart`
Expected: FAIL.

- [ ] **Step 3: Create the display helpers**

Create `lib/features/dive_log/presentation/widgets/weight_name_text.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/weight_planner/presentation/widgets/weight_enum_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A weight row's title as plain text: `Top pocket · Trim Weights` when the
/// diver named it (issue #956), otherwise its placement alone.
String weightDisplayName(DiveWeight weight, AppLocalizations l10n) {
  final type = weight.weightType.localizedName(l10n);
  final name = weight.label.trim();
  return name.isEmpty ? type : '$name · $type';
}

/// [weightDisplayName] with the placement muted, for lists where the name
/// leads. An unnamed weight renders exactly as its placement did before.
class WeightNameText extends StatelessWidget {
  final DiveWeight weight;

  const WeightNameText(this.weight, {super.key});

  @override
  Widget build(BuildContext context) {
    final type = weight.weightType.localizedName(context.l10n);
    final name = weight.label.trim();
    if (name.isEmpty) return Text(type);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: name),
          TextSpan(
            text: ' · $type',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Use them on the detail card**

In `dive_detail_page.dart` import `weight_name_text.dart`, change `_WeightDisplay` to carry a title widget:

```dart
class _WeightDisplay {
  final Widget title;
  final double amount;

  const _WeightDisplay({required this.title, required this.amount});
}
```

In `_buildWeightSection`, build new weights with `title: WeightNameText(weight)` and the legacy weight with `title: Text(dive.weightType?.localizedName(context.l10n) ?? context.l10n.diveLog_detail_section_weight)`, and render each row so a long name wraps and the amount stays on the first line:

```dart
            ...displayWeights.map(
              (weight) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: weight.title),
                    const SizedBox(width: 12),
                    Text(units.formatWeight(weight.amount)),
                  ],
                ),
              ),
            ),
```

- [ ] **Step 5: Use them on the rental memory card**

In `rental_memory_card.dart` import `weight_name_text.dart` and change the weight line to:

```dart
              for (final w in last.weights)
                Text(
                  '${weightDisplayName(w, l10n)} '
                  '${units.formatWeight(w.amountKg)}',
                  style: muted,
                ),
```

Remove the `weight_enum_display.dart` import there if analyze reports it unused.

- [ ] **Step 6: Run the tests to verify they pass**

Run: the Step 2 command.
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/features/dive_log/presentation/widgets/weight_name_text.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart lib/features/dive_centers/presentation/widgets/rental_memory_card.dart test/features/dive_log/presentation/widgets/weight_name_text_test.dart test/features/dive_log/presentation/pages/dive_detail_page_paired_sections_test.dart test/features/dive_centers/presentation/widgets/rental_memory_card_test.dart
git commit -m "feat(dive-log): show weight names on the dive and rental cards"
```

---

### Task 9: Edit names in the dive editor and the preset editor

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/weight_label_field.dart`
- Create: `lib/features/dive_log/presentation/widgets/dive_weight_entry_row.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (`_weightChild` ~5076, remove `_buildWeightEntryRow` ~5322)
- Modify: `lib/features/weight_presets/presentation/pages/weight_preset_editor_page.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_weight_entry_row_test.dart` (create)
- Test: `test/features/weight_presets/presentation/pages/weight_preset_editor_page_test.dart`

**Interfaces:**
- Consumes: `DiveWeight.copyWith(label:)`, `weightLabelMaxLength`, the Task 7 strings, `WeightEntryDraft.label`.
- Produces: `WeightLabelField({Key? key, TextEditingController? controller, String? initialValue, ValueChanged<String>? onChanged})`; `DiveWeightEntryRow({Key? key, required DiveWeight weight, required UnitFormatter units, required ValueChanged<DiveWeight> onChanged, required VoidCallback onRemove})`.

- [ ] **Step 1: Write the failing row tests**

Create `test/features/dive_log/presentation/widgets/dive_weight_entry_row_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_weight_entry_row.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

void main() {
  const units = UnitFormatter(AppSettings());

  /// Hosts rows the way the dive editor does: keyed by id, edits stored in
  /// place without a rebuild, removal rebuilding the list.
  Future<List<DiveWeight> Function()> pumpRows(
    WidgetTester tester,
    List<DiveWeight> initial,
  ) async {
    var weights = initial;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setState) => Form(
              child: Column(
                children: [
                  for (final w in weights)
                    DiveWeightEntryRow(
                      key: ValueKey(w.id),
                      weight: w,
                      units: units,
                      onChanged: (updated) => weights = [
                        for (final x in weights) x.id == updated.id ? updated : x,
                      ],
                      onRemove: () => setState(
                        () => weights = [
                          for (final x in weights)
                            if (x.id != w.id) x,
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return () => weights;
  }

  DiveWeight w(String id, double kg, {String label = ''}) => DiveWeight(
    id: id,
    diveId: 'd1',
    weightType: WeightType.trimWeights,
    amountKg: kg,
    label: label,
  );

  Finder nameField(int row) => find.widgetWithText(TextFormField, 'Name (optional)').at(row);

  testWidgets('shows the name under the type and amount', (tester) async {
    await pumpRows(tester, [w('a', 2, label: 'Top pocket')]);
    expect(find.text('Name (optional)'), findsOneWidget);
    expect(find.text('Top pocket'), findsOneWidget);
  });

  testWidgets('typing an amount then a name keeps both', (tester) async {
    final current = await pumpRows(tester, [w('a', 2)]);
    await tester.enterText(find.widgetWithText(TextFormField, '2'), '3');
    await tester.enterText(nameField(0), 'Top pocket');
    expect(current().single.amountKg, 3);
    expect(current().single.label, 'Top pocket');
  });

  testWidgets('deleting a middle row leaves the others on their own rows', (
    tester,
  ) async {
    final current = await pumpRows(tester, [
      w('a', 1, label: 'Top pocket'),
      w('b', 2, label: '2nd pocket'),
      w('c', 3, label: '3rd pocket'),
    ]);
    await tester.tap(find.byIcon(Icons.delete_outline).at(1));
    await tester.pump();

    expect(current().map((x) => x.id), ['a', 'c']);
    expect(find.text('2nd pocket'), findsNothing);
    expect(find.text('Top pocket'), findsOneWidget);
    expect(find.text('3rd pocket'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '3'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '2'), findsNothing);
  });

  testWidgets('the counter appears only near the limit', (tester) async {
    await pumpRows(tester, [w('a', 2)]);
    await tester.enterText(nameField(0), 'Top pocket');
    await tester.pump();
    expect(find.textContaining('/256'), findsNothing);
    await tester.enterText(nameField(0), 'x' * 240);
    await tester.pump();
    expect(find.text('240/256'), findsOneWidget);
  });
}
```

(If `find.widgetWithText(TextFormField, 'Name (optional)')` does not match because the label is not a `Text` descendant, use `find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == 'Name (optional)')` for `nameField`.)

In `weight_preset_editor_page_test.dart`, add a test that opens the editor for a new preset (copy the file's existing new-preset test setup), enters a preset name, an amount and `Top pocket` in the row's Name field, saves, and asserts the stored preset's `entries.single.label == 'Top pocket'`, plus a test that editing an existing preset whose entry has `label: 'Top pocket'` shows `Top pocket` in the field.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_weight_entry_row_test.dart test/features/weight_presets/presentation/pages/weight_preset_editor_page_test.dart`
Expected: FAIL (widgets missing).

- [ ] **Step 3: Create the Name field**

Create `lib/features/dive_log/presentation/widgets/weight_label_field.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/weight_label.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The optional name of a weight row (issue #956), shared by the dive editor
/// and the weight preset editor. The counter appears only in the last
/// [_counterThreshold] characters before [weightLabelMaxLength].
class WeightLabelField extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final ValueChanged<String>? onChanged;

  const WeightLabelField({
    super.key,
    this.controller,
    this.initialValue,
    this.onChanged,
  }) : assert(controller == null || initialValue == null);

  static const _counterThreshold = 20;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: l10n.diveLog_edit_label_weightName,
        hintText: l10n.diveLog_edit_hint_weightName,
        isDense: true,
      ),
      maxLength: weightLabelMaxLength,
      buildCounter:
          (
            context, {
            required currentLength,
            required isFocused,
            required maxLength,
          }) => currentLength < weightLabelMaxLength - _counterThreshold
          ? null
          : Text('$currentLength/$maxLength'),
      textCapitalization: TextCapitalization.sentences,
      onChanged: onChanged,
    );
  }
}
```

- [ ] **Step 4: Create the row widget**

Create `lib/features/dive_log/presentation/widgets/dive_weight_entry_row.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/widgets/weight_label_field.dart';
import 'package:submersion/features/weight_planner/presentation/widgets/weight_enum_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// One editable weight on a dive: placement, amount and remove on the first
/// line, the diver's optional name for it on the second (issue #956).
///
/// The row keeps its current value itself and hands every edit to
/// [onChanged]. The amount field does not rebuild the page while the diver
/// types, so a callback holding the weight from the last build would write
/// back a stale amount when the name changed next. Key each row by the
/// weight's id, so removing a row above this one does not hand its fields'
/// state to its neighbour.
class DiveWeightEntryRow extends StatefulWidget {
  final DiveWeight weight;
  final UnitFormatter units;
  final ValueChanged<DiveWeight> onChanged;
  final VoidCallback onRemove;

  const DiveWeightEntryRow({
    super.key,
    required this.weight,
    required this.units,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<DiveWeightEntryRow> createState() => _DiveWeightEntryRowState();
}

class _DiveWeightEntryRowState extends State<DiveWeightEntryRow> {
  late DiveWeight _current = widget.weight;

  @override
  void didUpdateWidget(DiveWeightEntryRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.weight != oldWidget.weight) _current = widget.weight;
  }

  void _update(DiveWeight next) {
    _current = next;
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = widget.units;
    // Display in the diver's unit, seeded at three decimals with trailing
    // zeros dropped, so a stored 0.65 kg is not snapped to 0.7 (#1609).
    final displayAmount = units.convertWeight(_current.amountKg);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<WeightType>(
                  initialValue: _current.weightType,
                  decoration: InputDecoration(
                    labelText: l10n.diveLog_edit_label_type,
                    isDense: true,
                  ),
                  isExpanded: true,
                  items: [
                    for (final type in WeightType.values)
                      DropdownMenuItem(
                        value: type,
                        child: Text(type.localizedName(l10n)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _update(_current.copyWith(weightType: value));
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: TextFormField(
                  initialValue: displayAmount > 0
                      ? formatRoundedForInput(displayAmount, 3)
                      : '',
                  decoration: InputDecoration(
                    labelText: units.weightSymbol,
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: numberInputFormatters(),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: numberValidator(context),
                  onChanged: (value) {
                    final displayValue = switch (readNumber(value)) {
                      NumberValue(:final value) => value,
                      NumberBlank() => 0.0, // an empty amount is 0 kg
                      // Keep the last readable amount; the error blocks save.
                      NumberInvalid() => null,
                    };
                    if (displayValue == null) return;
                    _update(
                      _current.copyWith(
                        amountKg: units.weightToKg(displayValue),
                      ),
                    );
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: widget.onRemove,
                tooltip: l10n.diveLog_edit_tooltip_removeWeight,
              ),
            ],
          ),
          const SizedBox(height: 8),
          WeightLabelField(
            initialValue: _current.label,
            onChanged: (value) => _update(_current.copyWith(label: value)),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Use the row in the dive editor**

In `dive_edit_page.dart` import `dive_weight_entry_row.dart`, then in `_weightChild` replace the `..._weights.asMap().entries.map(...)` spread with:

```dart
                for (final weight in _weights)
                  DiveWeightEntryRow(
                    key: ValueKey(weight.id),
                    weight: weight,
                    units: units,
                    onChanged: _replaceWeight,
                    onRemove: () => setState(() {
                      _markDirty();
                      _weights = [
                        for (final w in _weights)
                          if (w.id != weight.id) w,
                      ];
                    }),
                  ),
```

Add next to `_weightChild`:

```dart
  /// Stores an edited weight row in place. No setState: the row keeps its own
  /// fields current, and the Form's onChanged already marks the page dirty.
  void _replaceWeight(DiveWeight updated) {
    _weights = [for (final w in _weights) w.id == updated.id ? updated : w];
  }
```

Delete `_buildWeightEntryRow` entirely. Keep `_seedWeight` (still used for the weighting-feedback amount). Remove any import `flutter analyze` then reports unused.

- [ ] **Step 6: Add the Name field to the preset editor**

In `weight_preset_editor_page.dart`:

- `_Row` gains a label controller:
  ```dart
  class _Row {
    WeightType type;
    final TextEditingController amount;
    final TextEditingController label;
    _Row(this.type, this.amount, this.label);

    void dispose() {
      amount.dispose();
      label.dispose();
    }
  }
  ```
- Every `_Row(...)` construction passes a label controller: `_Row(WeightType.belt, TextEditingController(), TextEditingController())` for new rows, and `TextEditingController(text: e.label)` when loading `preset.entries`.
- Replace every `r.amount.dispose()` / `.amount.dispose()` with `r.dispose()` / `.dispose()`.
- `_save`: the draft becomes `(weightType: r.type, amountKg: units.weightToKg(amount), notes: '', label: r.label.text)`.
- `_buildRow`: wrap the existing `Row` in a `Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [<existing Row>, const SizedBox(height: 8), WeightLabelField(controller: row.label)])`, keep the outer `Padding`, and give it `key: ObjectKey(row)` so a deleted middle row does not pass its dropdown state on.
- Import `package:submersion/features/dive_log/presentation/widgets/weight_label_field.dart`.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_weight_entry_row_test.dart test/features/weight_presets test/features/dive_log/presentation/pages/dive_edit_weight_preset_test.dart test/features/dive_log/presentation/pages/dive_edit_rental_memory_test.dart test/features/dive_log/presentation/pages/dive_edit_locale_number_input_test.dart test/features/dive_log/presentation/pages/dive_edit_save_field_census_test.dart test/features/dive_log/presentation/pages/dive_edit_page_coverage_test.dart test/features/dive_log/presentation/pages/dive_edit_apply_last_dive_confirm_test.dart`
Expected: PASS. A failure in an existing editor test that finds fields by position (`find.byType(TextFormField).at(n)`) is the extra Name field shifting indices: update the finder to the field's label, not the behaviour.

- [ ] **Step 8: Commit**

```bash
dart format .
git add lib/features/dive_log/presentation/widgets/weight_label_field.dart lib/features/dive_log/presentation/widgets/dive_weight_entry_row.dart lib/features/dive_log/presentation/pages/dive_edit_page.dart lib/features/weight_presets/presentation/pages/weight_preset_editor_page.dart test/features/dive_log/presentation/widgets/dive_weight_entry_row_test.dart test/features/weight_presets/presentation/pages/weight_preset_editor_page_test.dart
git commit -m "feat(dive-log): name weights in the dive and preset editors"
```

(Add any existing editor test files you adjusted in Step 7.)

---

### Task 10: Query by weight name

**Files:**
- Modify: `lib/features/dive_log/query/dive_child_query_entities.dart:85`
- Modify: `lib/features/query/presentation/query_label_lookup.dart:548`
- Modify: `test/features/dive_log/query/dive_query_fixture.dart` (the `weight(...)` helper)
- Test: `test/features/dive_log/query/dive_query_semantics_test.dart`

**Interfaces:**
- Consumes: Task 1 column, Task 7 `query_weights_label`.

- [ ] **Step 1: Write the failing test**

In `dive_query_fixture.dart`, give `weight(...)` an optional `{String label = ''}` passed as `label: Value(label)` to `DiveWeightsCompanion.insert`, and seed `w1` with `label: 'Top pocket'`. Add to `dive_query_semantics_test.dart` next to the `weights[amount >= 2]` assertion:

```dart
    expect(await ids('weights[label ~ "pocket"]'), {'d1'});
    expect(await ids('weights[label ~ "canister"]'), isEmpty);
```

(`Value` needs `import 'package:drift/drift.dart'` in the fixture if it is not already imported.)

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_log/query/dive_query_semantics_test.dart`
Expected: FAIL (unknown field `label`).

- [ ] **Step 3: Add the field and its label**

`dive_child_query_entities.dart`, in `weightQueryEntity.fields` after `_text('weights', 'notes', 'notes'),`:

```dart
    _text('weights', 'label', 'label'),
```

`query_label_lookup.dart`, after the `query_weights_notes` case:

```dart
    case 'query_weights_label':
      return l10n.query_weights_label;
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/dive_log/query test/features/query test/core/query`
Expected: PASS (including `query_labels_test.dart`, which checks every `query_` key resolves).

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/dive_log/query/dive_child_query_entities.dart lib/features/query/presentation/query_label_lookup.dart test/features/dive_log/query/dive_query_fixture.dart test/features/dive_log/query/dive_query_semantics_test.dart
git commit -m "feat(query): filter dives by weight name"
```

---

### Task 11: Whole-branch verification

**Files:** none new.

- [ ] **Step 1: Format and analyze**

Run: `dart format . && flutter analyze`
Expected: no changes from format after the last commit; `No issues found!`. Fix any info-level lint too (CI treats infos as fatal).

- [ ] **Step 2: Architecture guards**

Run: `flutter test test/architecture/`
Expected: PASS (new files under `lib/` are scanned).

- [ ] **Step 3: Affected suites**

Run: `flutter test test/core/database test/core/services/sync test/core/services/export/uddf test/features/dive_log test/features/weight_presets test/features/dive_centers test/features/dive_import test/features/universal_import test/features/query`
Expected: PASS. Any failure: read it, fix the cause, re-run that file, then commit as `fix(<scope>): <what>`.

- [ ] **Step 4: Generated l10n is current**

Run: `flutter gen-l10n && git status --porcelain lib/l10n`
Expected: no output.

- [ ] **Step 5: Spec coverage check**

Walk the spec's Design sections 1 to 4 and confirm each bullet maps to a committed change or test above. Record any gap as a new task before opening the PR.
