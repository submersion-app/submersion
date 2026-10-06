# Transmitter Registry and Series Reassignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Downloaded cylinders get the right size, role and gear link from a per-diver transmitter registry, and a diver can move a pressure series to another cylinder in a way that survives re-parse.

**Architecture:** A new synced `transmitters` table maps a transmitter serial (or a computer plus channel index) to a snapshot cylinder spec. A pure matcher applies entries to `TankData` before the default preset fill, on download and on re-parse of new rows. A new `dive_tanks.source_tank_index` column records which parsed tank a row's computer data comes from; re-parse keys on it, and swap or reassign exchange it between rows.

**Tech Stack:** Flutter, Dart, Drift (SQLite), Riverpod, go_router, flutter_test, mockito. Schema rung v200.

**Spec:** `docs/superpowers/specs/2026-09-08-transmitter-registry-design.md` (read it first; every task argues from it).

**Deviations from the spec, deliberate:** the matcher operates on `TankData` rather than `DownloadedTank`, because only `TankData` carries the spec fields (working pressure, material, preset, gear link) that a matched entry writes; re-parse converts through `DiveParser.tankDataFrom` so both paths share one function. Re-parse keys existing rows on `(computerId, source_tank_index)` with a fallback to bare `tank_order` for rows from before v200 rather than on `computerId` alone. Consolidation carries `source_tank_index` through its existing whole-row copy, so no consolidation test is added; the exchange test in Task 8 covers the column's semantics.

## Global Constraints

- Schema rung is **v200**. Main shipped v199 (certifications) on 2026-09-08. Before taking the rung, re-run the ladder scan in Task 0 step 4; if anything else claims 200, take the next free number everywhere this plan says 200.
- No em-dashes (U+2014) anywhere: code, comments, tests, ARB files, commit messages. Use commas, colons or two sentences.
- No emojis in code, comments or documentation.
- No Claude, Claude Code or Anthropic mention in any commit message or file.
- Immutability: never mutate a list or object in place; return new ones.
- Every user-visible string goes through `context.l10n` and is added to all eleven ARB files in `lib/l10n/arb/` (en, ar, de, es, fr, he, hu, it, nl, pt, zh); run `flutter gen-l10n` and commit the generated `app_localizations*.dart` files.
- Everything displaying a volume or pressure uses the active diver's units via `UnitFormatter(settings)`.
- Transmitter serials are compared only through `normalizeTransmitterSerial` (`lib/features/dive_log/domain/services/transmitter_serial.dart`), never as raw strings.
- Every repository write calls `markRecordPending` and `SyncEventBus.notifyLocalChange()`; every delete logs a tombstone with `logDeletion`.
- A bare `build` token in a Bash command is refused by a permission rule in this repo. Put `dart run build_runner build --delete-conflicting-outputs` into a script file in the scratchpad directory and run the script, or run `./scripts/setup.sh`.
- Run `dart format .` before every commit. Run `flutter analyze` and read the exit status directly; never pipe it into `grep` or `tail` (the pipe hides the status).
- Test commands: `flutter test <path>`; never pipe `flutter test` into another command. Do not run two full-suite runs at once.
- Commit after every task with the message given in that task. Stage explicit paths, never `git add -A`.

## File Structure

New files:

| File | Responsibility |
| --- | --- |
| `lib/features/transmitters/domain/entities/transmitter.dart` | `Transmitter` entity, immutable, `copyWith` |
| `lib/features/transmitters/data/repositories/transmitter_repository.dart` | Drift CRUD, uniqueness, unassigned-serial query, apply-to-existing, per-computer counts |
| `lib/features/transmitters/presentation/providers/transmitter_providers.dart` | Repository and list providers, `loadTransmitterMatcher` |
| `lib/features/transmitters/presentation/pages/transmitters_page.dart` | Settings > Manage list page |
| `lib/features/transmitters/presentation/pages/transmitter_edit_page.dart` | Full-screen editor |
| `lib/features/dive_computer/data/services/transmitter_registry_matcher.dart` | `TransmitterMatcher` and `applyTransmitterRegistry` |
| `lib/features/dive_log/domain/services/tank_source_index.dart` | `kNoSourceTankIndex` and `effectiveSourceTankIndex` |
| `lib/features/dive_log/presentation/widgets/pickers/reassign_tank_picker.dart` | `showReassignTankPicker`, extracted from the inbox page |
| `lib/features/dive_log/presentation/widgets/tank_series_reassign_sheet.dart` | Swap and move-to sheet on the cylinders card |
| `lib/features/data_quality/domain/detectors/unknown_transmitter_detector.dart` | `unknown_transmitter` detector |
| `test/core/database/migration_v200_transmitters_test.dart` | Schema ladder test |
| Tests beside every new or changed unit, named in each task | |

Modified files, by task: `lib/core/database/database.dart`, `lib/core/data/repositories/sync_repository.dart`, `lib/core/services/sync/sync_data_serializer.dart`, `lib/core/services/sync/sync_service.dart`, `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` (`TankData`, `importProfile`), `lib/features/dive_computer/data/services/dive_parser.dart`, `lib/features/dive_computer/data/services/dive_import_service.dart`, `lib/features/dive_computer/data/services/reparse_service.dart`, `lib/features/dive_computer/presentation/providers/download_providers.dart`, `lib/features/dive_computer/presentation/providers/reparse_providers.dart`, `lib/features/dive_log/domain/entities/dive.dart`, `lib/features/dive_log/data/repositories/dive_repository_impl.dart`, `lib/features/dive_log/data/services/bulk_dive_edit_service.dart`, `lib/features/dive_log/data/repositories/tank_pressure_repository.dart`, `lib/features/data_quality/data/services/quality_repair_executor.dart`, `lib/features/equipment/domain/entities/equipment_item.dart`, `lib/features/equipment/domain/constants/equipment_attribute_catalog.dart`, `lib/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart`, `lib/core/router/app_router.dart`, `lib/features/settings/presentation/pages/settings_page.dart`, `lib/features/dive_computer/presentation/pages/device_detail_page.dart`, `lib/features/dive_log/presentation/widgets/cylinders_card.dart`, `lib/features/import_wizard/domain/models/import_notice.dart`, `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart`, `lib/features/import_wizard/presentation/widgets/import_summary_step.dart`, data-quality context, builder, registry, repairs, message and inbox files, and `lib/l10n/arb/*.arb`.

---

### Task 0: Worktree baseline and schema ladder scan

**Files:**
- Modify: nothing in the repo; this task prepares the worktree.

- [ ] **Step 1: Merge main into this branch**

Run from the worktree root `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/issue-1365-brainstorm-f1e2c7`:

```bash
git fetch origin && git merge --no-edit origin/main
```

Expected: a merge commit (the branch was two commits behind, both docs and features unrelated to tanks). If a conflict appears in `docs/superpowers/specs/`, keep this branch's version.

- [ ] **Step 2: Initialize the worktree**

```bash
git submodule update --init --recursive && flutter pub get
```

- [ ] **Step 3: Run code generation and localizations**

Write the scratchpad script `codegen.sh` containing:

```bash
#!/bin/zsh
set -e
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/issue-1365-brainstorm-f1e2c7
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
```

Run it with `zsh <scratchpad>/codegen.sh`. Expected: `lib/core/database/database.g.dart` exists afterward and `flutter analyze` exits 0.

- [ ] **Step 4: Re-run the schema ladder scan**

```bash
git show origin/main:lib/core/database/database.dart | grep -m1 "currentSchemaVersion = "
```

Expected: `199`. Then for every open PR:

```bash
for n in $(gh pr list --repo submersion-app/submersion --state open --limit 50 --json number -q '.[].number'); do c=$(gh pr diff $n --repo submersion-app/submersion 2>/dev/null | grep "^+.*currentSchemaVersion = " | sed 's/.*= //'); [ -n "$c" ] && echo "PR #$n claims $c"; done
```

Expected: no PR claims 200 (as of 2026-09-08 only stale claims of 192, 193 and 115 exist). If one does, use the next free number in place of 200 for the rest of this plan.

- [ ] **Step 5: Confirm the baseline suite compiles**

```bash
flutter test test/core/database/migration_v199_certification_credentials_test.dart
```

If the v199 test file has a different name, find it with `ls test/core/database/migration_v199_*`. Expected: PASS.

---

### Task 1: Schema v200, the transmitters table and dive_tanks.source_tank_index

**Files:**
- Modify: `lib/core/database/database.dart` (table class near `TankPresets` around line 2640; `@DriftDatabase(tables: [...])`; `currentSchemaVersion` at ~3511; `migrationVersions` tail at ~4026; `_hlcTables` at ~6870; helpers near `_assertDefaultPlannerWaterTypeColumn`; `onUpgrade` rungs at ~10577; `beforeOpen` backstop at ~10735)
- Modify: `test/core/database/migration_v199_*_test.dart` (relax the exact assertion)
- Create: `test/core/database/migration_v200_transmitters_test.dart`

**Interfaces:**
- Produces: Drift table `Transmitters` with data class `TransmitterRow` and companion `TransmittersCompanion`; column `DiveTanks.sourceTankIndex` (`int?`); helpers `_assertTransmitterTables()` and `_assertDiveTankSourceIndexColumn()`; `AppDatabase.currentSchemaVersion == 200`.

- [ ] **Step 1: Write the failing migration test**

Create `test/core/database/migration_v200_transmitters_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v200 adds the transmitter registry (issue #1365) and the parsed-tank
/// source index on dive_tanks (issue #1314).

Future<Set<String>> _tables(AppDatabase db) async {
  final rows = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  test('v200 is the current schema version and is in the ladder', () {
    // This is the newest rung, so it owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 200);
    expect(AppDatabase.migrationVersions, contains(200));
  });

  test('a fresh database has the transmitters table and the source index',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await _tables(db), contains('transmitters'));
    expect(
      await _columns(db, 'transmitters'),
      containsAll([
        'id',
        'diver_id',
        'transmitter_serial',
        'dive_computer_id',
        'channel_index',
        'label',
        'tank_role',
        'volume_l',
        'working_pressure_bar',
        'tank_material',
        'preset_name',
        'equipment_id',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );
    expect(await _columns(db, 'dive_tanks'), contains('source_tank_index'));
  });

  test('a database stranded before v200 gains both', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 199');
        rawDb.execute('''
          CREATE TABLE divers (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        rawDb.execute('''
          CREATE TABLE dive_tanks (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            tank_order INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    expect(await _tables(db), contains('transmitters'));
    expect(await _columns(db, 'dive_tanks'), contains('source_tank_index'));
  });

  test('deleting the linked gear nulls equipment_id, not the entry', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('g1', 'AL80', 'tank', 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO transmitters (id, label, tank_role, equipment_id, "
      "created_at, updated_at) VALUES ('t1', 'T1', 'backGas', 'g1', 1, 1)",
    );

    await db.customStatement("DELETE FROM equipment WHERE id = 'g1'");

    final row = await db
        .customSelect("SELECT equipment_id FROM transmitters WHERE id = 't1'")
        .getSingle();
    expect(row.read<String?>('equipment_id'), isNull);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/database/migration_v200_transmitters_test.dart`
Expected: FAIL (`currentSchemaVersion` is 199, no `transmitters` table).

- [ ] **Step 3: Add the table class**

In `lib/core/database/database.dart`, directly after the `TankPresets` table class (the comment `/// Custom tank presets` marks it), add:

```dart
/// Air-integration transmitter registry (issue #1365, v200). One row per
/// physical transmitter the diver owns or regularly rents, keyed on the serial
/// the computer reports, or on (dive computer, channel index) for parsers that
/// report no serial. The spec columns are a SNAPSHOT, like
/// [CylinderConfigItems]: picking a preset or a gear cylinder in the editor
/// copies its values here, and there is deliberately no FK to tank_presets.
/// Synced entity with its own hlc.
@DataClassName('TransmitterRow')
class Transmitters extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  // Normalized through normalizeTransmitterSerial before every write.
  TextColumn get transmitterSerial => text().nullable()();
  TextColumn get diveComputerId => text().nullable().references(
    DiveComputers,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get channelIndex => integer().nullable()();
  TextColumn get label => text()();
  TextColumn get tankRole => text()(); // TankRole.name
  RealColumn get volumeL => real().nullable()();
  RealColumn get workingPressureBar => real().nullable()();
  TextColumn get tankMaterial => text().nullable()(); // TankMaterial.name
  TextColumn get presetName => text().nullable()();
  TextColumn get equipmentId => text().nullable().references(
    Equipment,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

- [ ] **Step 4: Add the dive_tanks column**

In the `DiveTanks` table class, directly after `transmitterSerial`, add:

```dart
  // Which parsed tank index this row's computer-owned data (pressure series,
  // serial, start and end pressure) comes from (v200, issue #1314). Download
  // and re-parse write it equal to the index; null on rows written before
  // v200 means "same as tankOrder"; -1 (kNoSourceTankIndex) means the row
  // takes no parsed tank, which is what a reassignment leaves behind.
  IntColumn get sourceTankIndex => integer().nullable()();
```

- [ ] **Step 5: Register the table, bump the version, add the rung**

In `@DriftDatabase(tables: [...])`, after `WeightPresetEntries,` add `Transmitters,`.

Change `static const int currentSchemaVersion = 199;` to `200`.

In `migrationVersions`, after `199,` add:

```dart
    // v200: transmitters registry table (issue #1365) and
    // dive_tanks.source_tank_index (issue #1314).
    200,
```

Add both helpers next to `_assertDefaultPlannerWaterTypeColumn`:

```dart
  /// Transmitter registry (issue #1365, v200). Idempotent so a database that
  /// arrives by restore or sync-adopt (never runs onUpgrade) also gets it.
  Future<void> _assertTransmitterTables() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS transmitters (
        id TEXT NOT NULL PRIMARY KEY,
        diver_id TEXT REFERENCES divers(id),
        transmitter_serial TEXT,
        dive_computer_id TEXT REFERENCES dive_computers(id) ON DELETE SET NULL,
        channel_index INTEGER,
        label TEXT NOT NULL,
        tank_role TEXT NOT NULL,
        volume_l REAL,
        working_pressure_bar REAL,
        tank_material TEXT,
        preset_name TEXT,
        equipment_id TEXT REFERENCES equipment(id) ON DELETE SET NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        hlc TEXT
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transmitters_serial '
      'ON transmitters(transmitter_serial)',
    );
  }

  /// Idempotent DDL for dive_tanks.source_tank_index (v200, issue #1314).
  Future<void> _assertDiveTankSourceIndexColumn() async {
    final cols = await customSelect("PRAGMA table_info('dive_tanks')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (names.contains('source_tank_index')) return;
    await customStatement(
      'ALTER TABLE dive_tanks ADD COLUMN source_tank_index INTEGER',
    );
  }
```

In `onUpgrade`, after the `if (from < 199) await reportProgress();` line, add:

```dart
        // v200: transmitter registry (issue #1365) and the parsed-tank source
        // index on dive_tanks (issue #1314). No backfill: null means
        // "same as tank_order".
        if (from < 200) {
          await _assertTransmitterTables();
          await _assertDiveTankSourceIndexColumn();
        }
        if (from < 200) await reportProgress();
```

In `beforeOpen`, after the v199 backstop call (or after `_assertDefaultPlannerWaterTypeColumn()` if 199 has none), add:

```dart
        // v200 backstop: re-assert the transmitter table and the source index
        // column, same restore/sync-adopt reasoning.
        await _assertTransmitterTables();
        await _assertDiveTankSourceIndexColumn();
```

In `_hlcTables`, after `'weight_presets',` add `'transmitters',`.

- [ ] **Step 6: Relax the v199 test**

```bash
sed -i '' 's/expect(AppDatabase.currentSchemaVersion, 199);/expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(199));/' test/core/database/migration_v199_*_test.dart
```

If the v199 test already uses `greaterThanOrEqualTo`, nothing changes.

- [ ] **Step 7: Regenerate and run the tests**

Run the scratchpad `codegen.sh`, then:

Run: `flutter test test/core/database/migration_v200_transmitters_test.dart test/core/database/migration_v199_*_test.dart test/core/services/sync/hlc_column_test.dart`
Expected: the v200 and v199 tests PASS; `hlc_column_test` PASSES (it checks every `_hlcTables` entry has a nullable `hlc`). `sync_hlc_target_registration_test` will fail until Task 2; that is expected.

- [ ] **Step 8: Commit**

```bash
dart format lib/core/database/database.dart test/core/database
git add lib/core/database/database.dart lib/core/database/database.g.dart test/core/database/migration_v200_transmitters_test.dart test/core/database/migration_v199_*_test.dart
git commit -m "feat(db): add transmitters table and dive_tanks.source_tank_index (v200)"
```

---

### Task 2: Sync registration for transmitters

**Files:**
- Modify: `lib/core/data/repositories/sync_repository.dart:88` (`hlcTargets`)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (field ~282, constructor ~368, `toJson` ~449, `fromJson` ~533, registry tuple ~924, `_safeExport` call ~1532, `_exportTransmitters` beside `_exportWeightPresets` ~5820, and the seven `case` switches at ~2028, ~2352, ~3029, ~3939, ~4341, ~4576, ~4941)
- Modify: `lib/core/services/sync/sync_service.dart` (`mergeOrder` ~1387, `entityHasUpdatedAt` ~2228, `parentRefs` ~2462)
- Modify: `test/core/services/sync/sync_parent_refs_completeness_test.dart` (both maps)

**Interfaces:**
- Produces: sync entity type string `'transmitters'`, merged after `diveComputers`.

- [ ] **Step 1: Run the guard tests to see them fail**

Run: `flutter test test/core/services/sync/sync_hlc_target_registration_test.dart test/core/services/sync/sync_parent_refs_completeness_test.dart test/core/services/sync/sync_base_streaming_parity_test.dart`
Expected: FAIL, naming `transmitters` as an `hlc` table missing from `hlcTargets`.

- [ ] **Step 2: Register the hlc target**

In `sync_repository.dart` `hlcTargets`, after the `'weightPresets'` entry and its comment, add:

```dart
    'transmitters': (table: 'transmitters', pk: 'id'),
```

- [ ] **Step 3: Serializer edits**

In `sync_data_serializer.dart`, mirror every `weightPresets` site with a `transmitters` sibling placed directly after the `diveComputers` line of the same construct:

Field:
```dart
  final List<Map<String, dynamic>> transmitters;
```
Constructor default:
```dart
    this.transmitters = const [],
```
`toJson`:
```dart
    'transmitters': transmitters,
```
`fromJson`:
```dart
      transmitters: _parseList(json['transmitters']),
```
Registry tuple:
```dart
    (key: 'transmitters', table: _db.transmitters, blob: false, full: null),
```
`_safeExport` assembly:
```dart
      transmitters: await _safeExport(
        'transmitters',
        () => _exportTransmitters(hlcSince),
      ),
```
Export method, directly after `_exportWeightPresetEntries`:
```dart
  Future<List<Map<String, dynamic>>> _exportTransmitters(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.transmitters);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }
```
Single fetch:
```dart
      case 'transmitters':
        final row = await (_db.select(
          _db.transmitters,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
```
Batch fetch:
```dart
      case 'transmitters':
        final rows = await (_db.select(
          _db.transmitters,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
```
Single upsert:
```dart
      case 'transmitters':
        await _db
            .into(_db.transmitters)
            .insertOnConflictUpdate(
              TransmitterRow.fromJson(data).toCompanion(false),
            );
        return;
```
Batch upsert:
```dart
      case 'transmitters':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.transmitters,
            records
                .map((r) => TransmitterRow.fromJson(r).toCompanion(false))
                .toList(),
          ),
        );
        return;
```
Id projection:
```dart
      case 'transmitters':
        return plain(_db.transmitters, _db.transmitters.id);
```
Table lookup:
```dart
      case 'transmitters':
        return _db.transmitters;
```
Delete:
```dart
      case 'transmitters':
        await (_db.delete(
          _db.transmitters,
        )..where((t) => t.id.equals(recordId))).go();
        return;
```

- [ ] **Step 4: Sync service edits**

In `sync_service.dart` `mergeOrder`, directly after the `diveComputers` record (it must follow both `equipment` and `diveComputers`, its FK parents):

```dart
          (
            type: 'transmitters',
            records: data.transmitters,
            hasUpdatedAt: true,
          ),
```

In `entityHasUpdatedAt`, after `'diveComputers': true,` add `'transmitters': true,`.

In `parentRefs`, after the `diveComputers` entry add:

```dart
    // Both gear FKs are nullable: the registry entry outlives a deleted
    // cylinder or computer (set null), so a missing parent must not drop it.
    'transmitters': [
      (field: 'equipmentId', parent: 'equipment', nullable: true),
      (field: 'diveComputerId', parent: 'diveComputers', nullable: true),
    ],
```

- [ ] **Step 5: Completeness test maps**

In `test/core/services/sync/sync_parent_refs_completeness_test.dart`, add `'transmitters': 'transmitters',` to both the `syncedTables` map (after `'weight_preset_entries': 'weightPresetEntries',`) and the hlc-target map (after `'weight_presets': 'weightPresets',`).

- [ ] **Step 6: Run the guard suites**

Run: `flutter test test/core/services/sync/sync_hlc_target_registration_test.dart test/core/services/sync/sync_parent_refs_completeness_test.dart test/core/services/sync/sync_base_streaming_parity_test.dart test/core/services/sync/hlc_column_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format lib/core/data/repositories/sync_repository.dart lib/core/services/sync test/core/services/sync
git add lib/core/data/repositories/sync_repository.dart lib/core/services/sync/sync_data_serializer.dart lib/core/services/sync/sync_service.dart test/core/services/sync/sync_parent_refs_completeness_test.dart
git commit -m "feat(sync): register the transmitters entity"
```

---

### Task 3: Transmitter entity and repository

**Files:**
- Create: `lib/features/transmitters/domain/entities/transmitter.dart`
- Create: `lib/features/transmitters/data/repositories/transmitter_repository.dart`
- Create: `test/features/transmitters/data/repositories/transmitter_repository_test.dart`

**Interfaces:**
- Consumes: `Transmitters` table (Task 1), `normalizeTransmitterSerial`, `TankRole`, `TankMaterial` from `lib/core/constants/enums.dart`.
- Produces:
  - `class Transmitter` with fields `id, diverId, transmitterSerial, diveComputerId, channelIndex, label, role (TankRole), volumeL, workingPressureBar, material (TankMaterial?), presetName, equipmentId, createdAt, updatedAt`, getters `hasSerial`, `hasChannel`, and `copyWith`.
  - `class TransmitterConflictException implements Exception { final Transmitter existing; }`
  - `typedef UnassignedTransmitterSerial = ({String serial, int diveCount});`
  - `typedef ApplyToExistingResult = ({int tanksUpdated, int divesUpdated});`
  - `class TransmitterRepository` with `Stream<void> watchTransmittersChanges()`, `Stream<void> watchUnassignedChanges()`, `Future<List<Transmitter>> getForDiver(String? diverId)`, `Future<Transmitter?> getById(String id)`, `Future<Transmitter> create(Transmitter t)`, `Future<void> update(Transmitter t)`, `Future<void> delete(String id)`, `Future<List<UnassignedTransmitterSerial>> getUnassignedSerials(String? diverId)`, `Future<({int known, int unassigned})> serialCountsForComputer(String computerId, {String? diverId})`, `Future<ApplyToExistingResult> applyToExistingDives(Transmitter t)`.

- [ ] **Step 1: Write the failing repository tests**

Create `test/features/transmitters/data/repositories/transmitter_repository_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

import '../../../../helpers/test_database.dart';

Transmitter _entry({
  String id = 't1',
  String? diverId = 'diver-1',
  String? serial = '180777',
  String? computerId,
  int? channel,
  TankRole role = TankRole.oxygenSupply,
  double? volumeL = 2.0,
  String? equipmentId,
}) => Transmitter(
  id: id,
  diverId: diverId,
  transmitterSerial: serial,
  diveComputerId: computerId,
  channelIndex: channel,
  label: 'O2',
  role: role,
  volumeL: volumeL,
  workingPressureBar: 232,
  material: TankMaterial.steel,
  presetName: null,
  equipmentId: equipmentId,
  createdAt: DateTime.utc(2026, 9, 8),
  updatedAt: DateTime.utc(2026, 9, 8),
);

void main() {
  late TransmitterRepository repo;

  Future<void> seedDiverAndDive({
    String diveId = 'd1',
    String diverId = 'diver-1',
    String? computerId,
  }) async {
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT OR IGNORE INTO divers (id, name, created_at, updated_at) "
      "VALUES ('$diverId', 'A', 1, 1)",
    );
    if (computerId != null) {
      await db.customStatement(
        "INSERT OR IGNORE INTO dive_computers (id, name, connection_type, "
        "created_at, updated_at) VALUES ('$computerId', 'Perdix', 'ble', 1, 1)",
      );
    }
    await db.customStatement(
      "INSERT INTO dives (id, diver_id, dive_date_time, created_at, updated_at"
      "${computerId != null ? ', computer_id' : ''}) "
      "VALUES ('$diveId', '$diverId', 1, 1, 1"
      "${computerId != null ? ", '$computerId'" : ''})",
    );
  }

  Future<void> seedTank({
    required String id,
    required String diveId,
    String? serial,
    int order = 0,
    int? sourceIndex,
    String? computerId,
    double? volume,
    String role = 'backGas',
  }) async {
    final db = DatabaseService.instance.database;
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion(
            id: Value(id),
            diveId: Value(diveId),
            transmitterSerial: Value(serial),
            tankOrder: Value(order),
            sourceTankIndex: Value(sourceIndex),
            computerId: Value(computerId),
            volume: Value(volume),
            tankRole: Value(role),
          ),
        );
  }

  setUp(() async {
    await setUpTestDatabase();
    repo = TransmitterRepository();
  });

  tearDown(() async => tearDownTestDatabase());

  test('create normalizes the serial and round-trips every field', () async {
    await seedDiverAndDive();
    final created = await repo.create(_entry(serial: ' 180777 '));

    final loaded = await repo.getById(created.id);
    expect(loaded, isNotNull);
    expect(loaded!.transmitterSerial, '180777');
    expect(loaded.role, TankRole.oxygenSupply);
    expect(loaded.volumeL, 2.0);
    expect(loaded.workingPressureBar, 232);
    expect(loaded.material, TankMaterial.steel);
    expect(loaded.label, 'O2');
  });

  test('create refuses a second entry with the same serial for one diver',
      () async {
    await seedDiverAndDive();
    await repo.create(_entry());

    expect(
      () => repo.create(_entry(id: 't2', serial: ' 180777')),
      throwsA(isA<TransmitterConflictException>()),
    );
  });

  test('create refuses an entry with neither serial nor channel', () async {
    await seedDiverAndDive();
    expect(
      () => repo.create(_entry(serial: null)),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('create refuses a duplicate (computer, channel) key', () async {
    await seedDiverAndDive(computerId: 'c1');
    await repo.create(_entry(serial: null, computerId: 'c1', channel: 1));

    expect(
      () => repo.create(
        _entry(id: 't2', serial: null, computerId: 'c1', channel: 1),
      ),
      throwsA(isA<TransmitterConflictException>()),
    );
  });

  test('getForDiver returns only that diver, label order', () async {
    await seedDiverAndDive();
    await seedDiverAndDive(diveId: 'd2', diverId: 'diver-2');
    await repo.create(_entry(id: 'a', serial: '1'));
    await repo.create(_entry(id: 'b', serial: '2', diverId: 'diver-2'));

    final mine = await repo.getForDiver('diver-1');
    expect(mine.map((t) => t.id), ['a']);
  });

  test('getUnassignedSerials lists serials seen on dives with no entry',
      () async {
    await seedDiverAndDive();
    await seedDiverAndDive(diveId: 'd2');
    await seedTank(id: 'k1', diveId: 'd1', serial: '180777');
    await seedTank(id: 'k2', diveId: 'd2', serial: '180777', order: 0);
    await seedTank(id: 'k3', diveId: 'd2', serial: '109623', order: 1);
    await seedTank(id: 'k4', diveId: 'd2', serial: '000000', order: 2);
    await repo.create(_entry(serial: '109623'));

    final unassigned = await repo.getUnassignedSerials('diver-1');
    expect(unassigned, [(serial: '180777', diveCount: 2)]);
  });

  test('serialCountsForComputer splits known from unassigned', () async {
    await seedDiverAndDive(computerId: 'c1');
    await seedTank(id: 'k1', diveId: 'd1', serial: '180777', computerId: 'c1');
    await seedTank(
      id: 'k2',
      diveId: 'd1',
      serial: '109623',
      order: 1,
      computerId: 'c1',
    );
    await repo.create(_entry(serial: '180777'));

    final counts = await repo.serialCountsForComputer('c1', diverId: 'diver-1');
    expect(counts, (known: 1, unassigned: 1));
  });

  test('applyToExistingDives fills empty specs and only a backGas role',
      () async {
    await seedDiverAndDive();
    await seedDiverAndDive(diveId: 'd2');
    await seedTank(id: 'k1', diveId: 'd1', serial: '180777');
    await seedTank(
      id: 'k2',
      diveId: 'd2',
      serial: '180777',
      volume: 12,
      role: 'diluent',
    );
    await seedTank(id: 'k3', diveId: 'd2', serial: '109623', order: 1);
    final entry = await repo.create(_entry());

    final result = await repo.applyToExistingDives(entry);

    expect(result, (tanksUpdated: 2, divesUpdated: 2));
    final db = DatabaseService.instance.database;
    final k1 = await (db.select(db.diveTanks)..where((t) => t.id.equals('k1')))
        .getSingle();
    expect(k1.volume, 2.0);
    expect(k1.workingPressure, 232);
    expect(k1.tankMaterial, 'steel');
    expect(k1.tankRole, 'oxygenSupply');
    expect(k1.tankName, 'O2');
    final k2 = await (db.select(db.diveTanks)..where((t) => t.id.equals('k2')))
        .getSingle();
    expect(k2.volume, 12, reason: 'a reported volume is never overwritten');
    expect(k2.tankRole, 'diluent', reason: 'only backGas is replaced');
    expect(k2.workingPressure, 232);
    final k3 = await (db.select(db.diveTanks)..where((t) => t.id.equals('k3')))
        .getSingle();
    expect(k3.volume, isNull, reason: 'another serial is untouched');
  });

  test('applyToExistingDives matches a channel entry on the source index',
      () async {
    await seedDiverAndDive(computerId: 'c1');
    await seedTank(
      id: 'k1',
      diveId: 'd1',
      order: 0,
      sourceIndex: 1,
      computerId: 'c1',
    );
    final entry = await repo.create(
      _entry(serial: null, computerId: 'c1', channel: 1),
    );

    final result = await repo.applyToExistingDives(entry);

    expect(result.tanksUpdated, 1);
  });

  test('delete removes the row and logs a tombstone', () async {
    await seedDiverAndDive();
    final created = await repo.create(_entry());
    await repo.delete(created.id);

    expect(await repo.getById(created.id), isNull);
    final db = DatabaseService.instance.database;
    final tombstones = await db
        .customSelect(
          "SELECT COUNT(*) AS n FROM sync_deletions "
          "WHERE entity_type = 'transmitters' AND record_id = '${created.id}'",
        )
        .getSingle();
    expect(tombstones.read<int>('n'), 1);
  });
}
```

If the tombstone table is not named `sync_deletions`, look at how `test/features/cylinder_configs` asserts a `logDeletion` and use that table name.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/transmitters/data/repositories/transmitter_repository_test.dart`
Expected: FAIL to compile (no `Transmitter`, no repository).

- [ ] **Step 3: Write the entity**

Create `lib/features/transmitters/domain/entities/transmitter.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// One registered air-integration transmitter and the cylinder it feeds.
///
/// Identity is the transmitter serial the dive computer reports, or, for
/// parsers that report none, the (dive computer, channel index) pair. The
/// spec fields are a snapshot copied from a preset or a gear cylinder at edit
/// time; a later preset edit never rewrites an entry.
class Transmitter extends Equatable {
  final String id;
  final String? diverId;
  final String? transmitterSerial;
  final String? diveComputerId;
  final int? channelIndex;
  final String label;
  final TankRole role;
  final double? volumeL;
  final double? workingPressureBar;
  final TankMaterial? material;
  final String? presetName;
  final String? equipmentId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Transmitter({
    required this.id,
    this.diverId,
    this.transmitterSerial,
    this.diveComputerId,
    this.channelIndex,
    required this.label,
    this.role = TankRole.backGas,
    this.volumeL,
    this.workingPressureBar,
    this.material,
    this.presetName,
    this.equipmentId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasSerial =>
      transmitterSerial != null && transmitterSerial!.isNotEmpty;

  bool get hasChannel => diveComputerId != null && channelIndex != null;

  Transmitter copyWith({
    String? id,
    String? diverId,
    bool clearDiverId = false,
    String? transmitterSerial,
    bool clearTransmitterSerial = false,
    String? diveComputerId,
    bool clearDiveComputerId = false,
    int? channelIndex,
    bool clearChannelIndex = false,
    String? label,
    TankRole? role,
    double? volumeL,
    bool clearVolumeL = false,
    double? workingPressureBar,
    bool clearWorkingPressureBar = false,
    TankMaterial? material,
    bool clearMaterial = false,
    String? presetName,
    bool clearPresetName = false,
    String? equipmentId,
    bool clearEquipmentId = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Transmitter(
    id: id ?? this.id,
    diverId: clearDiverId ? null : (diverId ?? this.diverId),
    transmitterSerial: clearTransmitterSerial
        ? null
        : (transmitterSerial ?? this.transmitterSerial),
    diveComputerId: clearDiveComputerId
        ? null
        : (diveComputerId ?? this.diveComputerId),
    channelIndex: clearChannelIndex ? null : (channelIndex ?? this.channelIndex),
    label: label ?? this.label,
    role: role ?? this.role,
    volumeL: clearVolumeL ? null : (volumeL ?? this.volumeL),
    workingPressureBar: clearWorkingPressureBar
        ? null
        : (workingPressureBar ?? this.workingPressureBar),
    material: clearMaterial ? null : (material ?? this.material),
    presetName: clearPresetName ? null : (presetName ?? this.presetName),
    equipmentId: clearEquipmentId ? null : (equipmentId ?? this.equipmentId),
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Timestamps are excluded: they churn on every write and would defeat
  /// Riverpod's equality-based rebuild suppression. Mirrors CylinderConfig.
  @override
  List<Object?> get props => [
    id,
    diverId,
    transmitterSerial,
    diveComputerId,
    channelIndex,
    label,
    role,
    volumeL,
    workingPressureBar,
    material,
    presetName,
    equipmentId,
  ];
}
```

- [ ] **Step 4: Write the repository**

Create `lib/features/transmitters/data/repositories/transmitter_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

/// Thrown when an entry would share a serial (per diver) or a
/// (computer, channel) key with [existing].
class TransmitterConflictException implements Exception {
  final Transmitter existing;
  const TransmitterConflictException(this.existing);

  @override
  String toString() =>
      'TransmitterConflictException: conflicts with ${existing.label}';
}

/// A serial seen on downloaded tanks that has no registry entry.
typedef UnassignedTransmitterSerial = ({String serial, int diveCount});

/// Outcome of [TransmitterRepository.applyToExistingDives].
typedef ApplyToExistingResult = ({int tanksUpdated, int divesUpdated});

class TransmitterRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();

  static const String _entity = 'transmitters';

  Stream<void> watchTransmittersChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.transmitters));

  /// Ticks when either the registry or the tanks it is matched against change.
  Stream<void> watchUnassignedChanges() => _db.tableUpdates(
    TableUpdateQuery.onAllTables([_db.transmitters, _db.diveTanks]),
  );

  Future<List<Transmitter>> getForDiver(String? diverId) async {
    final query = _db.select(_db.transmitters)
      ..orderBy([(t) => OrderingTerm.asc(t.label)]);
    if (diverId != null) {
      query.where((t) => t.diverId.equals(diverId));
    }
    final rows = await query.get();
    return rows.map(_map).toList();
  }

  Future<Transmitter?> getById(String id) async {
    final row = await (_db.select(
      _db.transmitters,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _map(row);
  }

  Future<Transmitter> create(Transmitter t) async {
    final normalized = _normalized(t).copyWith(
      id: t.id.isEmpty ? _uuid.v4() : t.id,
    );
    await _checkConflicts(normalized);
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.transmitters)
        .insert(_companion(normalized, now: now, createdAt: now));
    await _syncRepository.markRecordPending(
      entityType: _entity,
      recordId: normalized.id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
    return normalized.copyWith(
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  Future<void> update(Transmitter t) async {
    final normalized = _normalized(t);
    await _checkConflicts(normalized);
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.transmitters,
    )..where((r) => r.id.equals(normalized.id))).write(
      _companion(normalized, now: now),
    );
    await _syncRepository.markRecordPending(
      entityType: _entity,
      recordId: normalized.id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.transmitters)..where((t) => t.id.equals(id))).go();
    await _syncRepository.logDeletion(entityType: _entity, recordId: id);
    SyncEventBus.notifyLocalChange();
  }

  /// Distinct normalized serials on the diver's downloaded tanks with no
  /// registry entry, with how many dives each appears on. Rows whose serial
  /// normalizes to null (blank, all zeros) are skipped.
  Future<List<UnassignedTransmitterSerial>> getUnassignedSerials(
    String? diverId,
  ) async {
    final known = {
      for (final t in await getForDiver(diverId))
        if (t.hasSerial) t.transmitterSerial!,
    };
    final rows = await _db
        .customSelect(
          'SELECT dt.transmitter_serial AS serial, dt.dive_id AS dive_id '
          'FROM dive_tanks dt JOIN dives d ON d.id = dt.dive_id '
          'WHERE dt.transmitter_serial IS NOT NULL '
          'AND (? IS NULL OR d.diver_id = ?)',
          variables: [Variable<String>(diverId), Variable<String>(diverId)],
          readsFrom: {_db.diveTanks, _db.dives},
        )
        .get();
    final divesBySerial = <String, Set<String>>{};
    for (final row in rows) {
      final serial = normalizeTransmitterSerial(row.read<String>('serial'));
      if (serial == null || known.contains(serial)) continue;
      divesBySerial.putIfAbsent(serial, () => {}).add(row.read<String>('dive_id'));
    }
    final out = [
      for (final e in divesBySerial.entries)
        (serial: e.key, diveCount: e.value.length),
    ]..sort((a, b) => a.serial.compareTo(b.serial));
    return out;
  }

  /// How many distinct serials seen on [computerId]'s dives have an entry,
  /// and how many do not.
  Future<({int known, int unassigned})> serialCountsForComputer(
    String computerId, {
    String? diverId,
  }) async {
    final knownSerials = {
      for (final t in await getForDiver(diverId))
        if (t.hasSerial) t.transmitterSerial!,
    };
    final rows = await _db
        .customSelect(
          'SELECT DISTINCT dt.transmitter_serial AS serial '
          'FROM dive_tanks dt JOIN dives d ON d.id = dt.dive_id '
          'WHERE dt.transmitter_serial IS NOT NULL '
          'AND (dt.computer_id = ? OR d.computer_id = ?)',
          variables: [Variable<String>(computerId), Variable<String>(computerId)],
          readsFrom: {_db.diveTanks, _db.dives},
        )
        .get();
    final seen = {
      for (final row in rows)
        if (normalizeTransmitterSerial(row.read<String>('serial'))
            case final s?)
          s,
    };
    final known = seen.where(knownSerials.contains).length;
    return (known: known, unassigned: seen.length - known);
  }

  /// Retroactive fill for the tanks that carry [t]'s key: empty size,
  /// working pressure, material, preset, gear link and name are filled; the
  /// role is replaced only while it is still the uninformed backGas default.
  /// One transaction; a failure leaves no half-applied dive.
  Future<ApplyToExistingResult> applyToExistingDives(Transmitter t) async {
    final candidates = await _tanksForEntry(t);
    if (candidates.isEmpty) return (tanksUpdated: 0, divesUpdated: 0);
    final now = DateTime.now().millisecondsSinceEpoch;
    final touchedDives = <String>{};
    var tanks = 0;
    await _db.transaction(() async {
      for (final row in candidates) {
        final hasVolume = row.volume != null && row.volume! > 0;
        final companion = DiveTanksCompanion(
          volume: !hasVolume && t.volumeL != null
              ? Value(t.volumeL)
              : const Value.absent(),
          workingPressure: row.workingPressure == null && t.workingPressureBar != null
              ? Value(t.workingPressureBar)
              : const Value.absent(),
          tankMaterial: row.tankMaterial == null && t.material != null
              ? Value(t.material!.name)
              : const Value.absent(),
          presetName: row.presetName == null && t.presetName != null
              ? Value(t.presetName)
              : const Value.absent(),
          equipmentId: row.equipmentId == null && t.equipmentId != null
              ? Value(t.equipmentId)
              : const Value.absent(),
          tankName: (row.tankName == null || row.tankName!.isEmpty) &&
                  t.label.isNotEmpty
              ? Value(t.label)
              : const Value.absent(),
          tankRole: row.tankRole == TankRole.backGas.name &&
                  t.role != TankRole.backGas
              ? Value(t.role.name)
              : const Value.absent(),
        );
        if (companion == const DiveTanksCompanion()) continue;
        await (_db.update(
          _db.diveTanks,
        )..where((d) => d.id.equals(row.id))).write(companion);
        await _syncRepository.markRecordPending(
          entityType: 'diveTanks',
          recordId: row.id,
          localUpdatedAt: now,
        );
        touchedDives.add(row.diveId);
        tanks++;
      }
    });
    if (tanks > 0) SyncEventBus.notifyLocalChange();
    return (tanksUpdated: tanks, divesUpdated: touchedDives.length);
  }

  Future<List<DiveTank>> _tanksForEntry(Transmitter t) async {
    if (t.hasSerial) {
      final rows = await (_db.select(_db.diveTanks)
            ..where((d) => d.transmitterSerial.isNotNull()))
          .get();
      return rows
          .where(
            (r) =>
                normalizeTransmitterSerial(r.transmitterSerial) ==
                t.transmitterSerial,
          )
          .toList();
    }
    if (!t.hasChannel) return const [];
    final rows = await _db
        .customSelect(
          'SELECT dt.id AS id FROM dive_tanks dt '
          'JOIN dives d ON d.id = dt.dive_id '
          'WHERE (dt.computer_id = ? OR d.computer_id = ?) '
          'AND COALESCE(dt.source_tank_index, dt.tank_order) = ?',
          variables: [
            Variable<String>(t.diveComputerId),
            Variable<String>(t.diveComputerId),
            Variable<int>(t.channelIndex),
          ],
          readsFrom: {_db.diveTanks, _db.dives},
        )
        .get();
    final ids = rows.map((r) => r.read<String>('id')).toList();
    if (ids.isEmpty) return const [];
    return (_db.select(_db.diveTanks)..where((d) => d.id.isIn(ids))).get();
  }

  Transmitter _normalized(Transmitter t) {
    final serial = normalizeTransmitterSerial(t.transmitterSerial);
    final channelComplete = t.diveComputerId != null && t.channelIndex != null;
    if (serial == null && !channelComplete) {
      throw ArgumentError(
        'A transmitter needs a serial or a dive computer plus channel index',
      );
    }
    return t.copyWith(
      transmitterSerial: serial,
      clearTransmitterSerial: serial == null,
      label: t.label.trim(),
    );
  }

  Future<void> _checkConflicts(Transmitter t) async {
    final siblings = await getForDiver(t.diverId);
    for (final other in siblings) {
      if (other.id == t.id) continue;
      final serialClash =
          t.hasSerial && other.transmitterSerial == t.transmitterSerial;
      final channelClash = t.hasChannel &&
          other.diveComputerId == t.diveComputerId &&
          other.channelIndex == t.channelIndex;
      if (serialClash || channelClash) {
        throw TransmitterConflictException(other);
      }
    }
  }

  TransmittersCompanion _companion(
    Transmitter t, {
    required int now,
    int? createdAt,
  }) => TransmittersCompanion(
    id: Value(t.id),
    diverId: Value(t.diverId),
    transmitterSerial: Value(t.transmitterSerial),
    diveComputerId: Value(t.diveComputerId),
    channelIndex: Value(t.channelIndex),
    label: Value(t.label),
    tankRole: Value(t.role.name),
    volumeL: Value(t.volumeL),
    workingPressureBar: Value(t.workingPressureBar),
    tankMaterial: Value(t.material?.name),
    presetName: Value(t.presetName),
    equipmentId: Value(t.equipmentId),
    createdAt: createdAt != null ? Value(createdAt) : const Value.absent(),
    updatedAt: Value(now),
  );

  Transmitter _map(TransmitterRow r) => Transmitter(
    id: r.id,
    diverId: r.diverId,
    transmitterSerial: r.transmitterSerial,
    diveComputerId: r.diveComputerId,
    channelIndex: r.channelIndex,
    label: r.label,
    role: TankRole.values.firstWhere(
      (e) => e.name == r.tankRole,
      orElse: () => TankRole.backGas,
    ),
    volumeL: r.volumeL,
    workingPressureBar: r.workingPressureBar,
    material: r.tankMaterial == null
        ? null
        : TankMaterial.values.firstWhere(
            (e) => e.name == r.tankMaterial,
            orElse: () => TankMaterial.aluminum,
          ),
    presetName: r.presetName,
    equipmentId: r.equipmentId,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt),
  );
}
```

Notes for the implementer:
- `DiveTank` inside this file is Drift's generated row class for `DiveTanks` (there is no `@DataClassName` on that table). Do not import the domain `DiveTank`.
- The `companion == const DiveTanksCompanion()` check relies on Drift companions being value-equal; every `Value.absent()` field compares equal, so an all-absent companion means nothing to write.
- The `dives` table's column for the diver is `diver_id` and for the computer `computer_id`; confirm with `grep -n "diverId\|computerId" lib/core/database/database.dart | sed -n 1,20p` before relying on the raw SQL.
- The `seedDiverAndDive` helper in the test inserts into `dives` with the minimum NOT NULL columns; if the insert fails, add the columns the error names with literal defaults.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/transmitters/data/repositories/transmitter_repository_test.dart`
Expected: PASS (10 tests).

- [ ] **Step 6: Commit**

```bash
dart format lib/features/transmitters test/features/transmitters
git add lib/features/transmitters test/features/transmitters
git commit -m "feat(transmitters): entity and repository for the transmitter registry"
```

---

### Task 4: Carry equipmentId, tankName and sourceTankIndex through the tank data path

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` (`TankData` at ~2295; `importProfile` tank insert at ~1419)
- Modify: `lib/features/dive_computer/data/services/dive_parser.dart:66-88`
- Modify: `lib/features/dive_log/domain/entities/dive.dart:1043-1171` (`DiveTank`)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (mappers at ~3578 and ~3973, `_tankCompanion` at ~5811, the update-branch insert at ~1688)
- Modify: `lib/features/dive_log/data/services/bulk_dive_edit_service.dart:364`
- Modify: `lib/features/dive_computer/data/services/downloaded_tank_defaults.dart` (copy the new fields)
- Create: `lib/features/dive_log/domain/services/tank_source_index.dart`
- Test: `test/features/dive_log/data/repositories/dive_repository_source_tank_index_test.dart`, `test/features/dive_computer/data/services/dive_parser_tank_data_test.dart`

**Interfaces:**
- Produces: `TankData.equipmentId`, `TankData.tankName`, `TankData.copyWith(...)`; `DiveParser.tankDataFrom(DownloadedTank)` (static); `DiveTank.sourceTankIndex` (`int?`) with `clearSourceTankIndex` on `copyWith`; `kNoSourceTankIndex = -1`; `effectiveSourceTankIndex({int? sourceTankIndex, required int tankOrder, required bool hasSeries})`.

- [ ] **Step 1: Write the failing tests**

Create `lib/features/dive_log/domain/services/tank_source_index.dart` test first, at `test/features/dive_log/domain/services/tank_source_index_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/services/tank_source_index.dart';

void main() {
  test('an explicit index wins', () {
    expect(
      effectiveSourceTankIndex(sourceTankIndex: 2, tankOrder: 0, hasSeries: true),
      2,
    );
  });

  test('a legacy row with a series resolves to its order', () {
    expect(
      effectiveSourceTankIndex(
        sourceTankIndex: null,
        tankOrder: 1,
        hasSeries: true,
      ),
      1,
    );
  });

  test('a legacy row without a series takes no parsed tank', () {
    expect(
      effectiveSourceTankIndex(
        sourceTankIndex: null,
        tankOrder: 1,
        hasSeries: false,
      ),
      kNoSourceTankIndex,
    );
  });
}
```

Create `test/features/dive_computer/data/services/dive_parser_tank_data_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/data/services/dive_parser.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';

void main() {
  test('tankDataFrom copies every DownloadedTank field', () {
    const tank = DownloadedTank(
      index: 1,
      o2Percent: 32,
      hePercent: 0,
      startPressure: 200,
      endPressure: 50,
      volumeLiters: 11.1,
      role: 'deco',
      transmitterSerial: '180777',
    );

    final data = DiveParser.tankDataFrom(tank);

    expect(data.index, 1);
    expect(data.o2Percent, 32);
    expect(data.startPressure, 200);
    expect(data.endPressure, 50);
    expect(data.volumeLiters, 11.1);
    expect(data.role, 'deco');
    expect(data.transmitterSerial, '180777');
    expect(data.equipmentId, isNull);
    expect(data.tankName, isNull);
  });

  test('copyWith replaces only the given fields', () {
    final data = DiveParser.tankDataFrom(
      const DownloadedTank(index: 0, o2Percent: 21),
    );

    final changed = data.copyWith(equipmentId: 'g1', tankName: 'O2');

    expect(changed.equipmentId, 'g1');
    expect(changed.tankName, 'O2');
    expect(changed.index, 0);
    expect(changed.o2Percent, 21);
  });
}
```

Create `test/features/dive_log/data/repositories/dive_repository_source_tank_index_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart' as domain;

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = DiveRepository();
  });
  tearDown(tearDownTestDatabase);

  test('sourceTankIndex round-trips through create and read', () async {
    await repo.createDive(
      domain.Dive(
        id: 'd1',
        dateTime: DateTime.utc(2026, 9, 8, 10),
        tanks: const [
          domain.DiveTank(
            id: 'tA',
            gasMix: domain.GasMix(o2: 21, he: 0),
            order: 0,
            sourceTankIndex: 1,
          ),
          domain.DiveTank(
            id: 'tB',
            gasMix: domain.GasMix(o2: 100, he: 0),
            order: 1,
          ),
        ],
      ),
    );

    final dive = await repo.getDiveById('d1');
    final byId = {for (final t in dive!.tanks) t.id: t};
    expect(byId['tA']!.sourceTankIndex, 1);
    expect(byId['tB']!.sourceTankIndex, isNull);
  });
}
```

Use the same `DiveRepository` constructor and `createDive`/`getDiveById` names that `test/features/data_quality/repairs/tank_pressure_repairs_test.dart` uses; if `getDiveById` is named differently there, copy that name.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_log/domain/services/tank_source_index_test.dart test/features/dive_computer/data/services/dive_parser_tank_data_test.dart test/features/dive_log/data/repositories/dive_repository_source_tank_index_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Add tank_source_index.dart**

```dart
/// Sentinel for a dive_tanks.source_tank_index that takes no parsed tank: the
/// row a series reassignment left behind. Re-parse never matches it, so the
/// row stays a pressureless cylinder instead of re-acquiring its old series.
const int kNoSourceTankIndex = -1;

/// The parsed tank index a row's computer-owned data comes from.
///
/// Rows written before v200 carry null; those with a pressure series were
/// keyed on tank order by the old re-parse path, and those without one own no
/// parsed tank at all.
int effectiveSourceTankIndex({
  required int? sourceTankIndex,
  required int tankOrder,
  required bool hasSeries,
}) {
  if (sourceTankIndex != null) return sourceTankIndex;
  return hasSeries ? tankOrder : kNoSourceTankIndex;
}
```

- [ ] **Step 4: Extend TankData**

In `dive_computer_repository_impl.dart`, add to `TankData` after `transmitterSerial`:

```dart
  /// Gear cylinder the transmitter registry linked this tank to, if any.
  final String? equipmentId;

  /// Display name from the transmitter registry's label, if any.
  final String? tankName;
```

Add both to the constructor as `this.equipmentId, this.tankName,` and append a `copyWith`:

```dart
  TankData copyWith({
    int? index,
    double? o2Percent,
    double? hePercent,
    double? startPressure,
    double? endPressure,
    double? volumeLiters,
    double? workingPressure,
    String? material,
    String? presetName,
    String? role,
    String? transmitterSerial,
    String? equipmentId,
    String? tankName,
  }) => TankData(
    index: index ?? this.index,
    o2Percent: o2Percent ?? this.o2Percent,
    hePercent: hePercent ?? this.hePercent,
    startPressure: startPressure ?? this.startPressure,
    endPressure: endPressure ?? this.endPressure,
    volumeLiters: volumeLiters ?? this.volumeLiters,
    workingPressure: workingPressure ?? this.workingPressure,
    material: material ?? this.material,
    presetName: presetName ?? this.presetName,
    role: role ?? this.role,
    transmitterSerial: transmitterSerial ?? this.transmitterSerial,
    equipmentId: equipmentId ?? this.equipmentId,
    tankName: tankName ?? this.tankName,
  );
```

In `importProfile`'s tank insert (the `DiveTanksCompanion(` inside `batch.insert`), after `transmitterSerial: Value(tank.transmitterSerial),` add:

```dart
                equipmentId: Value.absentIfNull(tank.equipmentId),
                tankName: Value.absentIfNull(tank.tankName),
                // The parsed index this row's computer data comes from
                // (issue #1314); re-parse keys on it.
                sourceTankIndex: Value(tank.index),
```

In `downloaded_tank_defaults.dart`, the `TankData(` built inside `applyDefaultPresetToTanks` must also pass `equipmentId: tank.equipmentId, tankName: tank.tankName,` so the preset fill does not drop them. Replace that constructor call with `tank.copyWith(volumeLiters: preset.volumeLiters, workingPressure: tank.workingPressure ?? preset.workingPressureBar, material: tank.material ?? preset.material.name, presetName: tank.presetName ?? preset.name)`.

- [ ] **Step 5: DiveParser.tankDataFrom**

Replace `parseTanks` in `dive_parser.dart` with:

```dart
  /// Convert a downloaded dive's tank data to TankData.
  List<TankData> parseTanks(DownloadedDive dive) =>
      dive.tanks.map(tankDataFrom).toList();

  /// One [DownloadedTank] as the repository's [TankData]. Shared with the
  /// re-parse path so both apply the transmitter registry to the same shape.
  static TankData tankDataFrom(DownloadedTank tank) => TankData(
    index: tank.index,
    o2Percent: tank.o2Percent,
    hePercent: tank.hePercent,
    startPressure: tank.startPressure,
    endPressure: tank.endPressure,
    volumeLiters: tank.volumeLiters,
    role: tank.role,
    transmitterSerial: tank.transmitterSerial,
  );
```

- [ ] **Step 6: DiveTank.sourceTankIndex**

In `dive.dart` `DiveTank`, after `transmitterSerial` add:

```dart
  /// Parsed tank index this row's computer-owned data comes from (v200). Null
  /// on rows from before v200 means "same as order"; [kNoSourceTankIndex]
  /// means the row takes no parsed tank. Computer-owned identity, like
  /// [computerId] and [transmitterSerial]: user edits never rewrite it.
  final int? sourceTankIndex;
```

Constructor: `this.sourceTankIndex,` after `this.transmitterSerial,`. `copyWith`: add params `int? sourceTankIndex, bool clearSourceTankIndex = false,` and the assignment `sourceTankIndex: clearSourceTankIndex ? null : (sourceTankIndex ?? this.sourceTankIndex),`. `props`: add `sourceTankIndex` after `transmitterSerial`. Import `tank_source_index.dart` for the doc reference or drop the bracket reference.

- [ ] **Step 7: Mappers**

In `dive_repository_impl.dart`, at both row-to-entity sites that have `transmitterSerial: t.transmitterSerial,` add the line `sourceTankIndex: t.sourceTankIndex,` directly after. In `_tankCompanion`, after `transmitterSerial: Value(t.transmitterSerial),` add `sourceTankIndex: Value(t.sourceTankIndex),`. At the update-branch insert near line 1688 (the one under the comment `computerId and transmitterSerial are computer-owned identity`), add `sourceTankIndex: Value(tank.sourceTankIndex),` after its `transmitterSerial:` line. In `bulk_dive_edit_service.dart` after `transmitterSerial: r.transmitterSerial,` add `sourceTankIndex: r.sourceTankIndex,`.

Run `grep -rn "transmitterSerial: " lib --include=*.dart` is refused by the shell glob; use `grep -rn "transmitterSerial: " lib | grep -v test` and check every mapper that builds a domain `DiveTank` or a `DiveTanksCompanion` from a full row now carries `sourceTankIndex` too (UDDF importers build tanks without it, which is correct: file imports have no parsed index).

- [ ] **Step 8: Run tests**

Run: `flutter test test/features/dive_log/domain/services/tank_source_index_test.dart test/features/dive_computer/data/services/dive_parser_tank_data_test.dart test/features/dive_log/data/repositories/dive_repository_source_tank_index_test.dart test/features/dive_computer/data/services/downloaded_tank_defaults_test.dart`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
dart format lib test
git add lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart lib/features/dive_computer/data/services/dive_parser.dart lib/features/dive_log/domain/entities/dive.dart lib/features/dive_log/data/repositories/dive_repository_impl.dart lib/features/dive_log/data/services/bulk_dive_edit_service.dart lib/features/dive_computer/data/services/downloaded_tank_defaults.dart lib/features/dive_log/domain/services/tank_source_index.dart test/features/dive_log/domain/services/tank_source_index_test.dart test/features/dive_computer/data/services/dive_parser_tank_data_test.dart test/features/dive_log/data/repositories/dive_repository_source_tank_index_test.dart
git commit -m "feat(tanks): carry equipment link, name and parsed source index through tank data"
```

---

### Task 5: The transmitter registry matcher

**Files:**
- Create: `lib/features/dive_computer/data/services/transmitter_registry_matcher.dart`
- Test: `test/features/dive_computer/data/services/transmitter_registry_matcher_test.dart`

**Interfaces:**
- Consumes: `Transmitter` (Task 3), `TankData.copyWith` (Task 4), `normalizeTransmitterSerial`.
- Produces:
  - `class TransmitterMatcher { const TransmitterMatcher.empty(); factory TransmitterMatcher.fromEntries(List<Transmitter>); Transmitter? match({required String? serial, required String? computerId, required int index}); bool get isEmpty; }`
  - `List<TankData> applyTransmitterRegistry(List<TankData> tanks, TransmitterMatcher matcher, {required String? computerId})`
  - `typedef TransmitterMatcherLoader = Future<TransmitterMatcher> Function();`

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_computer/data/services/transmitter_registry_matcher.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

Transmitter _entry({
  String id = 'e1',
  String? serial = '180777',
  String? computerId,
  int? channel,
  TankRole role = TankRole.oxygenSupply,
  double? volumeL = 2.0,
  double? workingPressureBar = 232,
  TankMaterial? material = TankMaterial.steel,
  String? presetName,
  String? equipmentId = 'g1',
  String label = 'O2',
  DateTime? updatedAt,
}) => Transmitter(
  id: id,
  transmitterSerial: serial,
  diveComputerId: computerId,
  channelIndex: channel,
  label: label,
  role: role,
  volumeL: volumeL,
  workingPressureBar: workingPressureBar,
  material: material,
  presetName: presetName,
  equipmentId: equipmentId,
  createdAt: DateTime.utc(2026, 9, 1),
  updatedAt: updatedAt ?? DateTime.utc(2026, 9, 1),
);

void main() {
  test('a serial match applies role, gear, name and fills empty specs', () {
    final matcher = TransmitterMatcher.fromEntries([_entry()]);
    const tank = TankData(
      index: 0,
      o2Percent: 100,
      startPressure: 200,
      endPressure: 170,
      transmitterSerial: '180777',
      role: 'backGas',
    );

    final out = applyTransmitterRegistry([tank], matcher, computerId: 'c1');

    expect(out.single.role, 'oxygenSupply');
    expect(out.single.equipmentId, 'g1');
    expect(out.single.tankName, 'O2');
    expect(out.single.volumeLiters, 2.0);
    expect(out.single.workingPressure, 232);
    expect(out.single.material, 'steel');
    expect(out.single.startPressure, 200, reason: 'pressures untouched');
    expect(out.single.o2Percent, 100, reason: 'gas untouched');
  });

  test('a serial padded with whitespace still matches', () {
    final matcher = TransmitterMatcher.fromEntries([_entry()]);
    const tank = TankData(index: 0, o2Percent: 21, transmitterSerial: ' 180777 ');

    final out = applyTransmitterRegistry([tank], matcher, computerId: null);

    expect(out.single.role, 'oxygenSupply');
  });

  test('a computer-reported volume is kept over the entry', () {
    final matcher = TransmitterMatcher.fromEntries([_entry()]);
    const tank = TankData(
      index: 0,
      o2Percent: 21,
      volumeLiters: 12,
      transmitterSerial: '180777',
    );

    final out = applyTransmitterRegistry([tank], matcher, computerId: null);

    expect(out.single.volumeLiters, 12);
    expect(out.single.role, 'oxygenSupply');
  });

  test('the (computer, channel) fallback matches only that computer', () {
    final matcher = TransmitterMatcher.fromEntries([
      _entry(serial: null, computerId: 'c1', channel: 1, role: TankRole.diluent),
    ]);
    const tank = TankData(index: 1, o2Percent: 21);

    expect(
      applyTransmitterRegistry([tank], matcher, computerId: 'c1').single.role,
      'diluent',
    );
    expect(
      applyTransmitterRegistry([tank], matcher, computerId: 'c2').single.role,
      isNull,
    );
  });

  test('the serial wins over a conflicting channel entry', () {
    final matcher = TransmitterMatcher.fromEntries([
      _entry(id: 'a', serial: '180777', role: TankRole.oxygenSupply),
      _entry(id: 'b', serial: null, computerId: 'c1', channel: 0, role: TankRole.deco),
    ]);
    const tank = TankData(index: 0, o2Percent: 21, transmitterSerial: '180777');

    final out = applyTransmitterRegistry([tank], matcher, computerId: 'c1');

    expect(out.single.role, 'oxygenSupply');
  });

  test('two tanks on one serial (Teric twins) both get the entry', () {
    final matcher = TransmitterMatcher.fromEntries([_entry()]);
    const tanks = [
      TankData(index: 0, o2Percent: 31, transmitterSerial: '180777'),
      TankData(index: 1, o2Percent: 32, transmitterSerial: '180777'),
    ];

    final out = applyTransmitterRegistry(tanks, matcher, computerId: null);

    expect(out.map((t) => t.role), ['oxygenSupply', 'oxygenSupply']);
  });

  test('an unmatched tank is returned unchanged', () {
    final matcher = TransmitterMatcher.fromEntries([_entry()]);
    const tank = TankData(index: 0, o2Percent: 21, transmitterSerial: '999');

    final out = applyTransmitterRegistry([tank], matcher, computerId: null);

    expect(out.single, same(tank));
  });

  test('the most recently updated duplicate wins', () {
    final matcher = TransmitterMatcher.fromEntries([
      _entry(id: 'old', role: TankRole.deco, updatedAt: DateTime.utc(2026, 1, 1)),
      _entry(id: 'new', role: TankRole.stage, updatedAt: DateTime.utc(2026, 2, 1)),
    ]);

    expect(matcher.match(serial: '180777', computerId: null, index: 0)!.id, 'new');
  });

  test('an empty matcher is a no-op', () {
    const tank = TankData(index: 0, o2Percent: 21, transmitterSerial: '180777');
    final out = applyTransmitterRegistry(
      [tank],
      const TransmitterMatcher.empty(),
      computerId: null,
    );
    expect(out.single, same(tank));
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_computer/data/services/transmitter_registry_matcher_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

Create `lib/features/dive_computer/data/services/transmitter_registry_matcher.dart`:

```dart
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

/// Loads the active diver's registry as a matcher, at import time rather than
/// provider build time so an entry saved a moment ago applies to the next
/// download. A failed load degrades to [TransmitterMatcher.empty].
typedef TransmitterMatcherLoader = Future<TransmitterMatcher> Function();

/// The diver's transmitter registry, indexed for the two lookups an import
/// makes: by normalized serial, then by (dive computer, channel index).
///
/// When sync has landed two entries with the same key, the most recently
/// updated one wins; the manage page shows both so the diver can delete one.
class TransmitterMatcher {
  final Map<String, Transmitter> _bySerial;
  final Map<(String, int), Transmitter> _byChannel;

  const TransmitterMatcher.empty() : _bySerial = const {}, _byChannel = const {};

  const TransmitterMatcher._(this._bySerial, this._byChannel);

  factory TransmitterMatcher.fromEntries(List<Transmitter> entries) {
    final ordered = [...entries]
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    final bySerial = <String, Transmitter>{};
    final byChannel = <(String, int), Transmitter>{};
    for (final entry in ordered) {
      final serial = normalizeTransmitterSerial(entry.transmitterSerial);
      if (serial != null) bySerial[serial] = entry;
      if (entry.hasChannel) {
        byChannel[(entry.diveComputerId!, entry.channelIndex!)] = entry;
      }
    }
    return TransmitterMatcher._(bySerial, byChannel);
  }

  bool get isEmpty => _bySerial.isEmpty && _byChannel.isEmpty;

  Transmitter? match({
    required String? serial,
    required String? computerId,
    required int index,
  }) {
    final normalized = normalizeTransmitterSerial(serial);
    if (normalized != null) {
      final hit = _bySerial[normalized];
      if (hit != null) return hit;
    }
    if (computerId != null) return _byChannel[(computerId, index)];
    return null;
  }
}

/// Apply the registry to downloaded tanks. Runs BEFORE the default-preset
/// fill so a matched entry claims its tank and the preset only fills back-gas
/// tanks nobody claimed.
///
/// A matched entry always sets the role, gear link, preset name and name; it
/// fills volume, working pressure and material only when the computer
/// reported none (a Suunto that knows its own size keeps it). Gas mix,
/// pressures and serial are never touched. Returns a new list; unmatched
/// tanks are returned as the same instance.
List<TankData> applyTransmitterRegistry(
  List<TankData> tanks,
  TransmitterMatcher matcher, {
  required String? computerId,
}) {
  if (matcher.isEmpty) return List.unmodifiable(tanks);
  return List.unmodifiable(
    tanks.map((tank) {
      final entry = matcher.match(
        serial: tank.transmitterSerial,
        computerId: computerId,
        index: tank.index,
      );
      if (entry == null) return tank;
      final hasVolume = tank.volumeLiters != null && tank.volumeLiters! > 0;
      return tank.copyWith(
        role: entry.role.name,
        equipmentId: entry.equipmentId,
        presetName: entry.presetName,
        tankName: entry.label.isEmpty ? null : entry.label,
        volumeLiters: hasVolume ? tank.volumeLiters : entry.volumeL,
        workingPressure: tank.workingPressure ?? entry.workingPressureBar,
        material: tank.material ?? entry.material?.name,
      );
    }),
  );
}
```

`TankData.copyWith` treats null as "keep", so `equipmentId: entry.equipmentId` with a null entry link leaves the tank's null in place, which is the intended result.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/dive_computer/data/services/transmitter_registry_matcher_test.dart`
Expected: PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_computer/data/services test/features/dive_computer/data/services
git add lib/features/dive_computer/data/services/transmitter_registry_matcher.dart test/features/dive_computer/data/services/transmitter_registry_matcher_test.dart
git commit -m "feat(dive-computer): transmitter registry matcher"
```

---

### Task 6: Apply the registry on download

**Files:**
- Modify: `lib/features/dive_computer/data/services/dive_import_service.dart` (typedef block at ~235, constructor at ~247, `_loadDefaultTankPreset` at ~266, `ImportResult` at ~155, `importDives` at ~283 and ~315, `_importNewDive` at ~532 and ~557, `importSingleDiveAsNew` at ~612, `resolveConflict` at ~727)
- Create: `lib/features/transmitters/presentation/providers/transmitter_providers.dart` (repository provider and `loadTransmitterMatcher` only; list providers come in Task 10)
- Modify: `lib/features/dive_computer/presentation/providers/download_providers.dart:32-43`
- Test: `test/features/dive_computer/data/services/dive_import_service_test.dart` (new group), `test/features/dive_computer/presentation/providers/download_transmitter_matcher_test.dart`

**Interfaces:**
- Consumes: `TransmitterMatcher`, `applyTransmitterRegistry`, `TransmitterMatcherLoader` (Task 5), `TransmitterRepository` (Task 3).
- Produces: `DiveImportService(transmitterMatcherForImports: TransmitterMatcherLoader?)`; `ImportResult.unmatchedTransmitterSerials` (`List<String>`, normalized, distinct, sorted); `DiveImportService.unmatchedTransmitterSerials` getter (serials seen since the service was created, for the single-dive entry points); `transmitterRepositoryProvider`; `Future<TransmitterMatcher> loadTransmitterMatcher(Ref ref)`.

- [ ] **Step 1: Write the failing tests**

In `test/features/dive_computer/data/services/dive_import_service_test.dart`, inside the existing group that defines `importedTanks()` and `diveWithPressureOnlyTank()` (around line 930), add a sibling helper and a nested group. First, next to `diveWithPressureOnlyTank()`, add a variant that gives the tank a serial: copy `diveWithPressureOnlyTank()` to `diveWithSerialTank(String serial)` and pass `transmitterSerial: serial` to its `DownloadedTank`. Then add:

```dart
    group('transmitter registry', () {
      Transmitter entry() => Transmitter(
        id: 'e1',
        transmitterSerial: '180777',
        label: 'O2',
        role: TankRole.oxygenSupply,
        volumeL: 2.0,
        workingPressureBar: 232,
        material: TankMaterial.steel,
        equipmentId: 'g1',
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      );

      test('a matched serial sets role, gear and size before the preset',
          () async {
        service = DiveImportService(
          repository: mockComputerRepo,
          diveRepository: mockDiveRepo,
          defaultTankPresetForImports: () async => al80,
          transmitterMatcherForImports: () async =>
              TransmitterMatcher.fromEntries([entry()]),
        );

        await service.importDives(
          dives: [diveWithSerialTank('180777')],
          computer: computer,
        );

        final tank = importedTanks().single;
        expect(tank.role, 'oxygenSupply');
        expect(tank.equipmentId, 'g1');
        expect(tank.tankName, 'O2');
        expect(tank.volumeLiters, 2.0, reason: 'registry, not the AL80 preset');
        expect(tank.presetName, isNull);
      });

      test('an unmatched serial still gets the default preset and is reported',
          () async {
        service = DiveImportService(
          repository: mockComputerRepo,
          diveRepository: mockDiveRepo,
          defaultTankPresetForImports: () async => al80,
          transmitterMatcherForImports: () async =>
              TransmitterMatcher.fromEntries([entry()]),
        );

        final result = await service.importDives(
          dives: [diveWithSerialTank('999')],
          computer: computer,
        );

        expect(importedTanks().single.volumeLiters, al80.volumeLiters);
        expect(result.unmatchedTransmitterSerials, ['999']);
      });

      test('a loader that throws degrades to no mapping', () async {
        service = DiveImportService(
          repository: mockComputerRepo,
          diveRepository: mockDiveRepo,
          transmitterMatcherForImports: () async => throw StateError('db'),
        );

        final result = await service.importDives(
          dives: [diveWithSerialTank('180777')],
          computer: computer,
        );

        expect(result.imported, 1);
        expect(importedTanks().single.role, isNot('oxygenSupply'));
      });

      test('applies on the import-as-new path and remembers the serial',
          () async {
        service = DiveImportService(
          repository: mockComputerRepo,
          diveRepository: mockDiveRepo,
          transmitterMatcherForImports: () async =>
              TransmitterMatcher.fromEntries([entry()]),
        );

        await service.importSingleDiveAsNew(
          diveWithSerialTank('180777'),
          computerId: computer.id,
        );
        await service.importSingleDiveAsNew(
          diveWithSerialTank('555'),
          computerId: computer.id,
        );

        expect(service.unmatchedTransmitterSerials, ['555']);
      });
    });
```

Add the imports the file lacks: `transmitter_registry_matcher.dart`, `transmitter.dart`, and `enums.dart`.

Create `test/features/dive_computer/presentation/providers/download_transmitter_matcher_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  test('loadTransmitterMatcher indexes the active diver entries', () async {
    final repo = TransmitterRepository();
    await repo.create(
      Transmitter(
        id: 'e1',
        diverId: null,
        transmitterSerial: '180777',
        label: 'O2',
        role: TankRole.oxygenSupply,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);

    final matcher = await loadTransmitterMatcher(container.read(_probe));

    expect(
      matcher.match(serial: '180777', computerId: null, index: 0)?.id,
      'e1',
    );
  });
}

/// Exposes a Ref for the loader under test.
final _probe = Provider<Ref>((ref) => ref);
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_computer/data/services/dive_import_service_test.dart test/features/dive_computer/presentation/providers/download_transmitter_matcher_test.dart`
Expected: FAIL to compile (`transmitterMatcherForImports` unknown).

- [ ] **Step 3: DiveImportService changes**

Add to `ImportResult` a field, constructor param and default:

```dart
  /// Normalized transmitter serials on the imported tanks that matched no
  /// registry entry, distinct and sorted, so the wizard can point the diver
  /// at the registry (issue #1365).
  final List<String> unmatchedTransmitterSerials;
```
`this.unmatchedTransmitterSerials = const [],`

Below the `DefaultTankPresetLoader` typedef, import `transmitter_registry_matcher.dart` (it exports `TransmitterMatcherLoader`). Add the field, constructor param and loader:

```dart
  final TransmitterMatcherLoader? _transmitterMatcherForImports;
  final Set<String> _unmatchedSerials = {};
```
Constructor: `TransmitterMatcherLoader? transmitterMatcherForImports,` and `_transmitterMatcherForImports = transmitterMatcherForImports;`

```dart
  /// Serials seen on tanks imported through this service that matched no
  /// registry entry. Accumulated across the per-dive entry points so the
  /// wizard can report them once at the end.
  List<String> get unmatchedTransmitterSerials =>
      _unmatchedSerials.toList()..sort();

  /// The diver's transmitter registry, or an empty matcher when none is
  /// configured or the load fails: a download must never fail because the
  /// registry could not be read.
  Future<TransmitterMatcher> _loadTransmitterMatcher() async {
    final loader = _transmitterMatcherForImports;
    if (loader == null) return const TransmitterMatcher.empty();
    try {
      return await loader();
    } catch (e, st) {
      _log.warning('Transmitter registry unavailable, importing without it', e, st);
      return const TransmitterMatcher.empty();
    }
  }
```

If the file has no `_log`, use the same logger the file already uses for `_importNewDive` warnings (search for `.warning(` in the file and copy its receiver).

In `importDives`, next to `final defaultTankPreset = await _loadDefaultTankPreset();` add `final transmitterMatcher = await _loadTransmitterMatcher();` and pass `transmitterMatcher: transmitterMatcher` at each `_importNewDive(` call inside the loop (the three sites the preset is passed to). At the end of `importDives`, construct the `ImportResult` with `unmatchedTransmitterSerials: unmatchedTransmitterSerials`.

`_importNewDive` gains `TransmitterMatcher? transmitterMatcher,` and replaces the tank conversion with:

```dart
    // Registry first so a matched entry claims its tank; the default preset
    // then fills only the back-gas tanks nobody claimed.
    final parsedTanks = _parser.parseTanks(dive);
    final matchedTanks = transmitterMatcher == null
        ? parsedTanks
        : applyTransmitterRegistry(
            parsedTanks,
            transmitterMatcher,
            computerId: computerId,
          );
    if (transmitterMatcher != null) {
      for (final tank in parsedTanks) {
        final serial = normalizeTransmitterSerial(tank.transmitterSerial);
        if (serial == null) continue;
        final hit = transmitterMatcher.match(
          serial: serial,
          computerId: computerId,
          index: tank.index,
        );
        if (hit == null) _unmatchedSerials.add(serial);
      }
    }
    final tanks = defaultTankPreset == null
        ? matchedTanks
        : applyDefaultPresetToTanks(matchedTanks, defaultTankPreset);
```

`importSingleDiveAsNew` and the `importAsNew` branch of `resolveConflict` pass `transmitterMatcher: await _loadTransmitterMatcher(),` beside their `defaultTankPreset:` argument.

- [ ] **Step 4: Provider loader**

Create `lib/features/transmitters/presentation/providers/transmitter_providers.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_computer/data/services/transmitter_registry_matcher.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';

final transmitterRepositoryProvider = Provider<TransmitterRepository>(
  (ref) => TransmitterRepository(),
);

/// The active diver's registry as a matcher. Read at import time, not at
/// provider build time, so an entry saved a moment ago applies to the very
/// next download or re-parse.
@visibleForTesting
Future<TransmitterMatcher> loadTransmitterMatcher(Ref ref) async {
  final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
  final entries = await ref.read(transmitterRepositoryProvider).getForDiver(diverId);
  return TransmitterMatcher.fromEntries(entries);
}
```

In `download_providers.dart` `diveImportServiceProvider`, after the `defaultTankPresetForImports:` line add:

```dart
    transmitterMatcherForImports: () => loadTransmitterMatcher(ref),
```

and import `transmitter_providers.dart`.

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/dive_computer/data/services/dive_import_service_test.dart test/features/dive_computer/presentation/providers/download_transmitter_matcher_test.dart test/features/dive_computer/presentation/providers/download_default_tank_preset_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/dive_computer lib/features/transmitters test/features/dive_computer
git add lib/features/dive_computer/data/services/dive_import_service.dart lib/features/transmitters/presentation/providers/transmitter_providers.dart lib/features/dive_computer/presentation/providers/download_providers.dart test/features/dive_computer/data/services/dive_import_service_test.dart test/features/dive_computer/presentation/providers/download_transmitter_matcher_test.dart
git commit -m "feat(dive-computer): apply the transmitter registry on download"
```

---

### Task 7: Re-parse keys on the source index and applies the registry to new rows

**Files:**
- Modify: `lib/features/dive_computer/data/services/reparse_service.dart` (constructor at ~35, `_carryOverTanks` at ~677-773)
- Modify: `lib/features/dive_computer/presentation/providers/reparse_providers.dart:13-21`
- Test: `test/features/dive_computer/data/services/reparse_service_test.dart` (new tests in the existing `DiveTanks carry-over` area)

**Interfaces:**
- Consumes: `TransmitterMatcherLoader`, `applyTransmitterRegistry`, `DiveParser.tankDataFrom`, `effectiveSourceTankIndex`, `loadTransmitterMatcher`.
- Produces: `ReparseService(transmitterMatcherLoader: TransmitterMatcherLoader?)`.

- [ ] **Step 1: Write the failing tests**

In `reparse_service_test.dart`, after the test named `'DiveTanks carry-over: writes the transmitter serial on both an existing tank and a new one'`, add (reuse that file's `insertDive`, `insertComputer`, `insertSource`, `makeParsedDive` helpers):

```dart
    test('DiveTanks carry-over: a swapped row keeps the swapped transmitter',
        () async {
      // Row tank-0 sits at order 0 but takes parsed tank 1 (a reassignment,
      // issue #1314); row tank-1 takes parsed tank 0. Re-parse must honor
      // source_tank_index, not tank_order, or the swap is silently undone.
      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
      );
      await db.into(db.diveTanks).insert(
        const DiveTanksCompanion(
          id: Value('tank-0'),
          diveId: Value('dive-1'),
          computerId: Value('comp-1'),
          o2Percent: Value(100.0),
          tankOrder: Value(0),
          sourceTankIndex: Value(1),
          tankName: Value('O2'),
        ),
      );
      await db.into(db.diveTanks).insert(
        const DiveTanksCompanion(
          id: Value('tank-1'),
          diveId: Value('dive-1'),
          computerId: Value('comp-1'),
          o2Percent: Value(21.0),
          tankOrder: Value(1),
          sourceTankIndex: Value(0),
          tankName: Value('Dil'),
        ),
      );

      final parsed = makeParsedDive(
        tanks: [
          pigeon.TankInfo(
            index: 0,
            gasMixIndex: 0,
            startPressureBar: 200.0,
            endPressureBar: 100.0,
            transmitterSerial: 111111,
          ),
          pigeon.TankInfo(
            index: 1,
            gasMixIndex: 1,
            startPressureBar: 210.0,
            endPressureBar: 180.0,
            transmitterSerial: 222222,
          ),
        ],
        gasMixes: [
          pigeon.GasMix(index: 0, o2Percent: 21.0, hePercent: 0.0),
          pigeon.GasMix(index: 1, o2Percent: 100.0, hePercent: 0.0),
        ],
      );

      await service.applyParsedUpdate(
        diveId: 'dive-1',
        sourceRowId: 'src-1',
        parsed: parsed,
        descriptorVendor: null,
        descriptorProduct: null,
        descriptorModel: null,
        libdivecomputerVersion: null,
      );

      final tanks = await (db.select(db.diveTanks)
            ..where((t) => t.diveId.equals('dive-1'))
            ..orderBy([(t) => OrderingTerm.asc(t.tankOrder)]))
          .get();
      expect(tanks, hasLength(2));
      expect(tanks[0].transmitterSerial, '222222');
      expect(tanks[0].startPressure, 210.0);
      expect(tanks[0].tankName, 'O2');
      expect(tanks[1].transmitterSerial, '111111');
      expect(tanks[1].startPressure, 200.0);
    });

    test('DiveTanks carry-over: a new row gets the registry entry and its '
        'source index', () async {
      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
      );
      final registry = TransmitterMatcher.fromEntries([
        Transmitter(
          id: 'e1',
          transmitterSerial: '109623',
          label: 'Dil',
          role: TankRole.diluent,
          volumeL: 3.0,
          equipmentId: 'g1',
          createdAt: DateTime.utc(2026, 9, 1),
          updatedAt: DateTime.utc(2026, 9, 1),
        ),
      ]);
      service = ReparseService(
        db: db,
        transmitterMatcherLoader: () async => registry,
      );

      final parsed = makeParsedDive(
        tanks: [
          pigeon.TankInfo(
            index: 0,
            gasMixIndex: 0,
            startPressureBar: 200.0,
            endPressureBar: 100.0,
            transmitterSerial: 109623,
          ),
        ],
        gasMixes: [pigeon.GasMix(index: 0, o2Percent: 21.0, hePercent: 0.0)],
      );

      await service.applyParsedUpdate(
        diveId: 'dive-1',
        sourceRowId: 'src-1',
        parsed: parsed,
        descriptorVendor: null,
        descriptorProduct: null,
        descriptorModel: null,
        libdivecomputerVersion: null,
      );

      final tank = await (db.select(db.diveTanks)
            ..where((t) => t.diveId.equals('dive-1')))
          .getSingle();
      expect(tank.tankRole, 'diluent');
      expect(tank.volume, 3.0);
      expect(tank.equipmentId, 'g1');
      expect(tank.tankName, 'Dil');
      expect(tank.sourceTankIndex, 0);
    });

    test('DiveTanks carry-over: an existing row is not rewritten by the '
        'registry', () async {
      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
      );
      await db.into(db.diveTanks).insert(
        const DiveTanksCompanion(
          id: Value('tank-0'),
          diveId: Value('dive-1'),
          o2Percent: Value(21.0),
          tankOrder: Value(0),
          tankRole: Value('backGas'),
        ),
      );
      service = ReparseService(
        db: db,
        transmitterMatcherLoader: () async => TransmitterMatcher.fromEntries([
          Transmitter(
            id: 'e1',
            transmitterSerial: '109623',
            label: 'Dil',
            role: TankRole.diluent,
            createdAt: DateTime.utc(2026, 9, 1),
            updatedAt: DateTime.utc(2026, 9, 1),
          ),
        ]),
      );

      await service.applyParsedUpdate(
        diveId: 'dive-1',
        sourceRowId: 'src-1',
        parsed: makeParsedDive(
          tanks: [
            pigeon.TankInfo(
              index: 0,
              gasMixIndex: 0,
              startPressureBar: 200.0,
              endPressureBar: 100.0,
              transmitterSerial: 109623,
            ),
          ],
          gasMixes: [pigeon.GasMix(index: 0, o2Percent: 21.0, hePercent: 0.0)],
        ),
        descriptorVendor: null,
        descriptorProduct: null,
        descriptorModel: null,
        libdivecomputerVersion: null,
      );

      final tank = await (db.select(db.diveTanks)
            ..where((t) => t.id.equals('tank-0')))
          .getSingle();
      expect(tank.tankRole, 'backGas', reason: 'user columns are not touched');
      expect(tank.transmitterSerial, '109623');
    });
```

Add imports for `transmitter_registry_matcher.dart`, `transmitter.dart` and `enums.dart` at the top of the test file. Because the `insertDive` helper may insert the `dives` row without a `computer_id`, the tank rows above carry `computerId` themselves.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_computer/data/services/reparse_service_test.dart`
Expected: the three new tests FAIL (unknown named parameter, and the swap test sees `tanks[0].transmitterSerial == '111111'`).

- [ ] **Step 3: Constructor and loader**

In `reparse_service.dart` add imports for `dive_parser.dart`, `transmitter_registry_matcher.dart`, `tank_source_index.dart`, and `dive_computer_repository_impl.dart` (for `TankData`). Add:

```dart
  /// The diver's transmitter registry, read per re-parsed dive so an entry
  /// saved a moment ago applies. Null (or a failing load) means no mapping.
  final TransmitterMatcherLoader? _transmitterMatcherLoader;
```

Constructor param `TransmitterMatcherLoader? transmitterMatcherLoader,` assigned in the initializer list as `_transmitterMatcherLoader = transmitterMatcherLoader`. Add:

```dart
  Future<TransmitterMatcher> _loadMatcher() async {
    final loader = _transmitterMatcherLoader;
    if (loader == null) return const TransmitterMatcher.empty();
    try {
      return await loader();
    } catch (_) {
      return const TransmitterMatcher.empty();
    }
  }
```

- [ ] **Step 4: Rewrite `_carryOverTanks`**

Replace the body from `final existingByOrder = ...` through the end of the `for (final tank in resolveParsedTanks(...)) { ... }` loop with:

```dart
    final matcher = await _loadMatcher();
    final parsedTanks = applyTransmitterRegistry(
      resolveParsedTanks(
        parsed,
        trimAtSurfacing: trimTankPressureAtSurfacing,
      ).map(DiveParser.tankDataFrom).toList(),
      matcher,
      computerId: computerId,
    );

    // Which existing row takes parsed tank [index]. A row's source index wins
    // (a reassignment, issue #1314); rows from before v200 carry null and
    // fall back to their order, as the old path did. A row marked
    // kNoSourceTankIndex takes nothing.
    final matchedIds = <String>{};
    dynamic existingFor(int index) {
      for (final t in existingTanks) {
        if (matchedIds.contains(t.id)) continue;
        if (t.computerId != computerId) continue;
        if (t.sourceTankIndex == index) return t;
      }
      for (final t in existingTanks) {
        if (matchedIds.contains(t.id)) continue;
        if (t.sourceTankIndex == null && t.tankOrder == index) return t;
      }
      return null;
    }

    final newTankOrders = <int>{};
    for (final tank in parsedTanks) {
      newTankOrders.add(tank.index);
      final existing = existingFor(tank.index);
      if (existing != null) {
        matchedIds.add(existing.id);
        tankIdsByIndex[tank.index] = existing.id;
        // Update existing tank: overwrite computer fields, preserve user fields
        await (db.update(
          db.diveTanks,
        )..where((t) => t.id.equals(existing.id))).write(
          DiveTanksCompanion(
            // Computers report pressure, not cylinder size: a volume the
            // parse lacks was entered by the diver (or filled from the
            // default preset), so only overwrite it with a reported one.
            // Zero means "unreported" throughout the tank code.
            volume: (tank.volumeLiters ?? 0) > 0
                ? Value(tank.volumeLiters)
                : const Value.absent(),
            workingPressure: const Value.absent(),
            startPressure: Value(tank.startPressure),
            endPressure: Value(tank.endPressure),
            o2Percent: Value(tank.o2Percent),
            hePercent: Value(tank.hePercent),
            // The transmitter serial is computer-owned and written
            // unconditionally, so a re-parse is how a tank downloaded
            // before the serial was stored gains it (and a parse that stops
            // reporting one clears the stale value).
            transmitterSerial: Value(tank.transmitterSerial),
            // A legacy row gains its explicit source index here; a row that
            // already has one keeps it.
            sourceTankIndex: existing.sourceTankIndex == null
                ? Value(tank.index)
                : const Value.absent(),
            // tankName, presetName, equipmentId, tankRole, tankMaterial
            // are user-authored -- NOT touched, so the registry is not
            // applied to an existing row either.
          ),
        );
      } else {
        // New tank: insert with defaults, registry applied.
        final newTankId = _uuid.v4();
        tankIdsByIndex[tank.index] = newTankId;
        await db
            .into(db.diveTanks)
            .insert(
              DiveTanksCompanion(
                id: Value(newTankId),
                diveId: Value(diveId),
                computerId: Value(computerId),
                volume: Value(tank.volumeLiters),
                workingPressure: Value.absentIfNull(tank.workingPressure),
                tankMaterial: Value.absentIfNull(tank.material),
                presetName: Value.absentIfNull(tank.presetName),
                equipmentId: Value.absentIfNull(tank.equipmentId),
                tankName: Value.absentIfNull(tank.tankName),
                startPressure: Value(tank.startPressure),
                endPressure: Value(tank.endPressure),
                o2Percent: Value(tank.o2Percent),
                hePercent: Value(tank.hePercent),
                tankOrder: Value(tank.index),
                tankRole: Value(tank.role ?? 'backGas'),
                transmitterSerial: Value(tank.transmitterSerial),
                sourceTankIndex: Value(tank.index),
              ),
            );
      }
    }

    // Delete tanks that exist in DB but were neither matched nor kept by
    // order (the pre-v200 rule, so manual rows on a re-parsed dive behave as
    // before).
    for (final existing in existingTanks) {
      if (matchedIds.contains(existing.id)) continue;
      if (!newTankOrders.contains(existing.tankOrder)) {
        await (db.delete(
          db.diveTanks,
        )..where((t) => t.id.equals(existing.id))).go();
      }
    }
```

Replace `dynamic existingFor` with the Drift row type if the analyzer's `avoid_dynamic_calls` lint complains: the row class is `DiveTank` from `database.dart` (Drift's, not the domain one; this file does not import the domain entity, so the bare name resolves correctly).

The `resolveGasSwitches` and `_replaceTankPressureProfiles` calls below already take `tankIdsByIndex`, so series follow the remap automatically.

- [ ] **Step 5: Provider**

In `reparse_providers.dart`, add `transmitterMatcherLoader: () => loadTransmitterMatcher(ref),` to the `ReparseService(` construction and import `transmitter_providers.dart`.

- [ ] **Step 6: Run the reparse suites**

Run: `flutter test test/features/dive_computer/data/services/reparse_service_test.dart test/features/dive_computer/data/services/reparse_service_series_test.dart test/features/dive_computer/data/services/reparse_service_surfacing_test.dart`
Expected: PASS, including every pre-existing carry-over test.

- [ ] **Step 7: Commit**

```bash
dart format lib/features/dive_computer test/features/dive_computer
git add lib/features/dive_computer/data/services/reparse_service.dart lib/features/dive_computer/presentation/providers/reparse_providers.dart test/features/dive_computer/data/services/reparse_service_test.dart
git commit -m "feat(reparse): key tank carry-over on the source index and apply the registry to new rows"
```

---

### Task 8: Exchange tank sources (swap and reassign that survive re-parse)

**Files:**
- Modify: `lib/features/dive_log/data/repositories/tank_pressure_repository.dart:152-173`
- Modify: `lib/features/data_quality/data/services/quality_repair_executor.dart` (add `exchangeTankSources`, keep `swapPressureSeries` and `reassignPressureSeries`)
- Modify: `test/features/data_quality/repairs/tank_pressure_repairs_test.dart` (reassign expectations)
- Test: `test/features/dive_log/data/repositories/tank_pressure_repository_exchange_test.dart`

**Interfaces:**
- Consumes: `DiveTanks.sourceTankIndex`, `effectiveSourceTankIndex`, `TankPressureSeriesRepository.swapTanks`.
- Produces: `TankPressureRepository.exchangeTankSources({required String diveId, required String tankIdA, required String tankIdB})`; `QualityRepairExecutor.exchangeTankSources({required String diveId, required String tankIdA, required String tankIdB}) -> Future<RepairResult>` (no finding involved).

- [ ] **Step 1: Write the failing tests**

Create `test/features/dive_log/data/repositories/tank_pressure_repository_exchange_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart' as domain;
import 'package:submersion/features/dive_log/domain/services/tank_source_index.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository diveRepo;
  late TankPressureRepository tankRepo;

  setUp(() async {
    await setUpTestDatabase();
    diveRepo = DiveRepository();
    tankRepo = TankPressureRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<void> seed({bool withSourceIndex = true}) async {
    await diveRepo.createDive(
      domain.Dive(
        id: 'd1',
        dateTime: DateTime.utc(2026, 7, 1, 10),
        tanks: [
          domain.DiveTank(
            id: 'tA',
            name: 'O2',
            gasMix: const domain.GasMix(o2: 100, he: 0),
            order: 0,
            startPressure: 200,
            endPressure: 170,
            transmitterSerial: '111',
            sourceTankIndex: withSourceIndex ? 0 : null,
          ),
          domain.DiveTank(
            id: 'tB',
            name: 'Dil',
            gasMix: const domain.GasMix(o2: 21, he: 0),
            order: 1,
            startPressure: 210,
            endPressure: 120,
            transmitterSerial: '222',
            sourceTankIndex: withSourceIndex ? 1 : null,
          ),
          const domain.DiveTank(
            id: 'tC',
            name: 'Stage',
            gasMix: domain.GasMix(o2: 50, he: 0),
            order: 2,
            startPressure: 200,
          ),
        ],
      ),
    );
    await tankRepo.insertTankPressures('d1', {
      'tA': [
        (timestamp: 0, pressure: 200.0),
        (timestamp: 600, pressure: 170.0),
      ],
      'tB': [(timestamp: 0, pressure: 210.0)],
    });
  }

  Future<Map<String, dynamic>> row(String id) async {
    final db = DatabaseService.instance.database;
    final r = await (db.select(db.diveTanks)..where((t) => t.id.equals(id)))
        .getSingle();
    return {
      'src': r.sourceTankIndex,
      'serial': r.transmitterSerial,
      'start': r.startPressure,
      'end': r.endPressure,
      'name': r.tankName,
    };
  }

  test('swap exchanges the computer bundle and the series, not the names',
      () async {
    await seed();
    await tankRepo.exchangeTankSources(diveId: 'd1', tankIdA: 'tA', tankIdB: 'tB');

    expect(await row('tA'), {
      'src': 1,
      'serial': '222',
      'start': 210.0,
      'end': 120.0,
      'name': 'O2',
    });
    expect(await row('tB'), {
      'src': 0,
      'serial': '111',
      'start': 200.0,
      'end': 170.0,
      'name': 'Dil',
    });
    final byTank = await tankRepo.getTankPressuresForDive('d1');
    expect(byTank['tA']!.map((p) => p.pressure), [210.0]);
    expect(byTank['tB']!.map((p) => p.pressure), [200.0, 170.0]);
  });

  test('legacy rows without a source index get explicit ones', () async {
    await seed(withSourceIndex: false);
    await tankRepo.exchangeTankSources(diveId: 'd1', tankIdA: 'tA', tankIdB: 'tB');

    expect((await row('tA'))['src'], 1);
    expect((await row('tB'))['src'], 0);
  });

  test('moving onto a manual tank leaves the source with no parsed tank',
      () async {
    await seed();
    await tankRepo.exchangeTankSources(diveId: 'd1', tankIdA: 'tB', tankIdB: 'tC');

    expect((await row('tC'))['src'], 1);
    expect((await row('tC'))['serial'], '222');
    expect((await row('tB'))['src'], kNoSourceTankIndex);
    expect((await row('tB'))['serial'], isNull);
    expect((await row('tB'))['start'], 200.0, reason: 'tC had a manual fill');
    final byTank = await tankRepo.getTankPressuresForDive('d1');
    expect(byTank.containsKey('tB'), isFalse);
    expect(byTank['tC'], hasLength(1));
  });

  test('exchange is its own inverse', () async {
    await seed();
    await tankRepo.exchangeTankSources(diveId: 'd1', tankIdA: 'tA', tankIdB: 'tB');
    await tankRepo.exchangeTankSources(diveId: 'd1', tankIdA: 'tA', tankIdB: 'tB');

    expect((await row('tA'))['serial'], '111');
    expect((await row('tB'))['serial'], '222');
    final byTank = await tankRepo.getTankPressuresForDive('d1');
    expect(byTank['tA'], hasLength(2));
  });
}
```

In `test/features/data_quality/repairs/tank_pressure_repairs_test.dart`, change the reassign test's expectations: reassigning `tB` onto `tA` now exchanges, so `tA` ends with `tB`'s single point and `tB` with `tA`'s two:

```dart
    final byTank = await tankRepo.getTankPressuresForDive('d1');
    expect(byTank['tA']!, hasLength(1));
    expect(byTank['tB']!, hasLength(2));
```

The old merge behaviour was lossy on undo (undoing moved all three points back); the exchange is its own inverse, which is what the executor's undo closure already assumes.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_log/data/repositories/tank_pressure_repository_exchange_test.dart test/features/data_quality/repairs/tank_pressure_repairs_test.dart`
Expected: FAIL (`exchangeTankSources` undefined; the reassign test still sees the merge).

- [ ] **Step 3: Implement the exchange**

In `tank_pressure_repository.dart` add the import for `tank_source_index.dart` and `dart:async` is not needed. Replace `reassignTankPressureSeries` and `swapTankPressureSeries` bodies with delegation, and add the exchange:

```dart
  /// Move the pressure series of [fromTankId] onto [toTankId]. Since v200 this
  /// is an exchange: the target's previous bundle comes back to the source so
  /// nothing is orphaned and the operation is its own inverse. No
  /// transaction/notify -- the repair executor owns those.
  Future<void> reassignTankPressureSeries({
    required String diveId,
    required String fromTankId,
    required String toTankId,
  }) => exchangeTankSources(diveId: diveId, tankIdA: fromTankId, tankIdB: toTankId);

  /// Exchange the pressure series of two tanks (swapped-transmitter repair).
  Future<void> swapTankPressureSeries({
    required String diveId,
    required String tankIdA,
    required String tankIdB,
  }) => exchangeTankSources(diveId: diveId, tankIdA: tankIdA, tankIdB: tankIdB);

  /// Exchange the computer-owned bundle of two tank rows on one dive: the
  /// parsed source index, transmitter serial, start and end pressure, and
  /// the packed pressure series. User-authored columns (name, role, size,
  /// gear, preset, gas mix) stay with their row.
  ///
  /// A row without an explicit source index is resolved first
  /// ([effectiveSourceTankIndex]) so that re-parse keeps honoring the result:
  /// a legacy row that had a series takes its order, one that had none takes
  /// [kNoSourceTankIndex]. The exchange is its own inverse.
  Future<void> exchangeTankSources({
    required String diveId,
    required String tankIdA,
    required String tankIdB,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final a = await (_db.select(_db.diveTanks)..where((t) => t.id.equals(tankIdA)))
        .getSingle();
    final b = await (_db.select(_db.diveTanks)..where((t) => t.id.equals(tankIdB)))
        .getSingle();
    final aHasSeries = await _hasSeries(diveId, tankIdA);
    final bHasSeries = await _hasSeries(diveId, tankIdB);
    final aIndex = effectiveSourceTankIndex(
      sourceTankIndex: a.sourceTankIndex,
      tankOrder: a.tankOrder,
      hasSeries: aHasSeries,
    );
    final bIndex = effectiveSourceTankIndex(
      sourceTankIndex: b.sourceTankIndex,
      tankOrder: b.tankOrder,
      hasSeries: bHasSeries,
    );

    await (_db.update(_db.diveTanks)..where((t) => t.id.equals(tankIdA))).write(
      DiveTanksCompanion(
        sourceTankIndex: Value(bIndex),
        transmitterSerial: Value(b.transmitterSerial),
        startPressure: Value(b.startPressure),
        endPressure: Value(b.endPressure),
      ),
    );
    await (_db.update(_db.diveTanks)..where((t) => t.id.equals(tankIdB))).write(
      DiveTanksCompanion(
        sourceTankIndex: Value(aIndex),
        transmitterSerial: Value(a.transmitterSerial),
        startPressure: Value(a.startPressure),
        endPressure: Value(a.endPressure),
      ),
    );
    await _tankSeries.swapTanks(diveId, tankIdA, tankIdB, now: now);
    await _syncRepository.markRecordPending(
      entityType: 'diveTanks',
      recordId: tankIdA,
      localUpdatedAt: now,
    );
    await _syncRepository.markRecordPending(
      entityType: 'diveTanks',
      recordId: tankIdB,
      localUpdatedAt: now,
    );
    await _touchDive(diveId, now);
  }

  Future<bool> _hasSeries(String diveId, String tankId) async {
    final row = await (_db.selectOnly(_db.tankPressureSeries)
          ..addColumns([_db.tankPressureSeries.id.count()])
          ..where(
            _db.tankPressureSeries.diveId.equals(diveId) &
                _db.tankPressureSeries.tankId.equals(tankId),
          ))
        .getSingle();
    return row.read(_db.tankPressureSeries.id.count())! > 0;
  }
```

`_db`, `_tankSeries` and `_syncRepository` are the names the file already uses (see `_touchDive`); if `_syncRepository` is named differently there, use that name.

- [ ] **Step 4: Executor method**

In `quality_repair_executor.dart`, after `reassignPressureSeries`, add a finding-free variant for the cylinders card:

```dart
  /// Exchange two tanks' computer bundles from the dive page, outside any
  /// finding. Same write, notify and undo contract as [swapPressureSeries];
  /// the targeted rescan lets a twin-tank finding clear itself.
  Future<RepairResult> exchangeTankSources({
    required String diveId,
    required String tankIdA,
    required String tankIdB,
  }) async {
    Future<void> run() async {
      await _db.transaction(
        () => _tankRepo.exchangeTankSources(
          diveId: diveId,
          tankIdA: tankIdA,
          tankIdB: tankIdB,
        ),
      );
      SyncEventBus.notifyLocalChange();
      scheduleQualityScan([diveId]);
    }

    await run();
    return RepairResult.applied(run);
  }
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/dive_log/data/repositories/tank_pressure_repository_exchange_test.dart test/features/data_quality/repairs/tank_pressure_repairs_test.dart test/features/dive_log/data/repositories/tank_pressure_repository_series_writes_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/dive_log/data/repositories lib/features/data_quality/data/services test/features/dive_log test/features/data_quality
git add lib/features/dive_log/data/repositories/tank_pressure_repository.dart lib/features/data_quality/data/services/quality_repair_executor.dart test/features/dive_log/data/repositories/tank_pressure_repository_exchange_test.dart test/features/data_quality/repairs/tank_pressure_repairs_test.dart
git commit -m "feat(tanks): exchange tank sources so swap and reassign survive re-parse (#1314)"
```

---

### Task 9: Typed cylinder attributes on EquipmentItem and a type filter on the picker

**Files:**
- Modify: `lib/features/equipment/domain/constants/equipment_attribute_catalog.dart:54-72` (keys) and `:221-247` (tank entry)
- Modify: `lib/features/equipment/domain/entities/equipment_item.dart:74-88`
- Modify: `lib/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart`
- Test: `test/features/equipment/domain/entities/equipment_item_tank_attrs_test.dart`

**Interfaces:**
- Produces: `EquipmentAttrKeys.volumeL == 'volume_l'`, `EquipmentAttrKeys.workingPressureBar == 'working_pressure_bar'`, `EquipmentAttrKeys.tankMaterial == 'tank_material'`; `EquipmentItem.volumeL`, `.workingPressureBar` (`double?`), `.tankMaterial` (`TankMaterial?`, mapping the choice key `carbon_composite` to `TankMaterial.carbonFiber`); `EquipmentPickerSheet(typeFilter: EquipmentType?)`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

EquipmentItem _tank(List<EquipmentAttribute> attrs) => EquipmentItem(
  id: 'g1',
  name: 'AL80',
  type: EquipmentType.tank,
  attributes: attrs,
  createdAt: DateTime.utc(2026, 9, 1),
  updatedAt: DateTime.utc(2026, 9, 1),
);

void main() {
  test('reads volume, working pressure and material from attributes', () {
    final item = _tank([
      EquipmentAttribute(key: EquipmentAttrKeys.volumeL, valueNum: 11.1),
      EquipmentAttribute(key: EquipmentAttrKeys.workingPressureBar, valueNum: 207),
      EquipmentAttribute(key: EquipmentAttrKeys.tankMaterial, valueText: 'carbon_composite'),
    ]);

    expect(item.volumeL, 11.1);
    expect(item.workingPressureBar, 207);
    expect(item.tankMaterial, TankMaterial.carbonFiber);
  });

  test('missing attributes read as null', () {
    final item = _tank(const []);
    expect(item.volumeL, isNull);
    expect(item.workingPressureBar, isNull);
    expect(item.tankMaterial, isNull);
  });
}
```

Match `EquipmentItem`'s and `EquipmentAttribute`'s real constructors (open both files; `EquipmentAttribute` may require `equipmentId` and `isCustom`). Adjust the helper to pass whatever is `required`; do not change the assertions.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/equipment/domain/entities/equipment_item_tank_attrs_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

In `EquipmentAttrKeys` add:

```dart
  // Cylinder specs (issue #1365): read by the transmitter registry editor.
  static const volumeL = 'volume_l';
  static const workingPressureBar = 'working_pressure_bar';
  static const tankMaterial = 'tank_material';
```

In the `EquipmentType.tank` catalog entry, replace the three string literals `'volume_l'`, `'working_pressure_bar'`, `'tank_material'` with the constants.

In `EquipmentItem`, after `liftCapacityKg`, add:

```dart
  /// Cylinder specs (curated tank attributes). Null when unspecified.
  double? get volumeL => attrNum(EquipmentAttrKeys.volumeL);
  double? get workingPressureBar => attrNum(EquipmentAttrKeys.workingPressureBar);

  /// The catalog stores the choice key ('aluminum', 'steel',
  /// 'carbon_composite'); the enum name for the last one differs.
  TankMaterial? get tankMaterial => switch (attrText(EquipmentAttrKeys.tankMaterial)) {
    'aluminum' => TankMaterial.aluminum,
    'steel' => TankMaterial.steel,
    'carbon_composite' => TankMaterial.carbonFiber,
    _ => null,
  };
```

Check the `TankMaterial` enum in `lib/core/constants/enums.dart` for the exact carbon value name (`carbonFiber` or `carbonComposite`) and use that.

In `equipment_picker_sheet.dart` add `final EquipmentType? typeFilter;` with a constructor param `this.typeFilter,` and, where the list named `available` is computed, append `.where((e) => typeFilter == null || e.type == typeFilter)` before `.toList()`.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/equipment/domain/entities/equipment_item_tank_attrs_test.dart test/features/equipment`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/equipment lib/features/dive_log/presentation/widgets/pickers test/features/equipment
git add lib/features/equipment/domain/constants/equipment_attribute_catalog.dart lib/features/equipment/domain/entities/equipment_item.dart lib/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart test/features/equipment/domain/entities/equipment_item_tank_attrs_test.dart
git commit -m "feat(equipment): typed cylinder attributes and a type filter on the gear picker"
```

---

### Task 10: Localized strings for every surface in this plan

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` (template, with `@` metadata for placeholder keys) and `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`
- Generated: `lib/l10n/arb/app_localizations*.dart`

No tests of its own; the CI l10n gate fails if the generated files are stale, and every later widget test asserts on the English text below.

- [ ] **Step 1: Add the English keys**

Append to `app_en.arb`, before the final `}` (keep the file's existing key groups; put the `settings_` keys beside `settings_manage_tankPresets`, the `universalImport_` keys beside `universalImport_summary_noticeNoTankPressureBody`, the `dataQuality_` keys beside their siblings, and the rest as one new block):

```json
  "settings_manage_transmitters": "Transmitters",
  "settings_manage_transmitters_subtitle": "Link air-integration transmitters to cylinders",
  "transmitters_title": "Transmitters",
  "transmitters_add": "Add transmitter",
  "transmitters_header_assigned": "Assigned transmitters",
  "transmitters_header_unassigned": "Seen in downloads, not assigned",
  "transmitters_empty": "No transmitters yet. Add one, or assign a serial after your next download.",
  "transmitters_action_assign": "Assign",
  "transmitters_action_edit": "Edit transmitter",
  "transmitters_action_delete": "Delete transmitter",
  "transmitters_action_apply": "Apply to existing dives",
  "transmitters_apply_title": "Apply to existing dives?",
  "transmitters_apply_content": "{tanks} cylinders on {dives} dives carry this transmitter. Empty size, material, name and gear fields will be filled, and a role still set to Back Gas will be replaced.",
  "@transmitters_apply_content": {
    "placeholders": {
      "tanks": { "type": "int" },
      "dives": { "type": "int" }
    }
  },
  "transmitters_apply_done": "Updated {tanks} cylinders on {dives} dives",
  "@transmitters_apply_done": {
    "placeholders": {
      "tanks": { "type": "int" },
      "dives": { "type": "int" }
    }
  },
  "transmitters_apply_nothing": "No cylinders carry this transmitter",
  "transmitters_delete_title": "Delete transmitter?",
  "transmitters_delete_content": "Future downloads from {label} will use the default preset again.",
  "@transmitters_delete_content": {
    "placeholders": {
      "label": { "type": "String" }
    }
  },
  "transmitters_channel": "{computer}, channel {channel}",
  "@transmitters_channel": {
    "placeholders": {
      "computer": { "type": "String" },
      "channel": { "type": "int" }
    }
  },
  "transmitters_serial": "Transmitter {serial}",
  "@transmitters_serial": {
    "placeholders": {
      "serial": { "type": "String" }
    }
  },
  "transmitters_dives": "{count, plural, =1{1 dive} other{{count} dives}}",
  "@transmitters_dives": {
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "transmitters_edit_title": "Edit transmitter",
  "transmitters_new_title": "New transmitter",
  "transmitters_field_label": "Label",
  "transmitters_field_serial": "Transmitter serial",
  "transmitters_field_computer": "Dive computer (when no serial is reported)",
  "transmitters_field_channel": "Channel",
  "transmitters_field_role": "Role",
  "transmitters_field_gear": "Cylinder from gear",
  "transmitters_field_material": "Material",
  "transmitters_gear_none": "None",
  "transmitters_validation_key": "Enter a transmitter serial, or pick a dive computer and channel",
  "transmitters_validation_positive": "Enter a value greater than zero",
  "transmitters_validation_duplicate": "Already assigned to {label}",
  "@transmitters_validation_duplicate": {
    "placeholders": {
      "label": { "type": "String" }
    }
  },
  "transmitters_saved": "Transmitter saved",
  "diveComputer_detail_transmitters": "Transmitters",
  "diveComputer_detail_transmittersSummary": "{known} known, {unassigned} unassigned",
  "@diveComputer_detail_transmittersSummary": {
    "placeholders": {
      "known": { "type": "int" },
      "unassigned": { "type": "int" }
    }
  },
  "diveLog_tank_assignTransmitter": "Assign transmitter",
  "diveLog_tank_reassignSeries": "Reassign pressure series",
  "diveLog_reassignSheet_title": "Pressure series",
  "diveLog_reassignSheet_swap": "Swap",
  "diveLog_reassignSheet_moveTo": "Move to",
  "diveLog_reassignSheet_readings": "{count, plural, =1{1 reading} other{{count} readings}}",
  "@diveLog_reassignSheet_readings": {
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "diveLog_reassignSheet_noSeries": "No pressure series",
  "diveLog_reassignSheet_applied": "Pressure series reassigned",
  "universalImport_summary_noticeUnknownTransmitterTitle": "Unassigned transmitters",
  "universalImport_summary_noticeUnknownTransmitterBody": "One or more transmitters in this download are not assigned to a cylinder. Assign them so future downloads get the right size and role.",
  "universalImport_summary_noticeAssignTransmitters": "Assign transmitters",
  "dataQuality_detector_unknown_transmitter": "Unassigned transmitter",
  "dataQuality_msg_unknownTransmitter": "Transmitter {serial} is not assigned to a cylinder",
  "@dataQuality_msg_unknownTransmitter": {
    "placeholders": {
      "serial": { "type": "String" }
    }
  },
  "dataQuality_repairLabel_assignTransmitter": "Assign transmitter"
```

- [ ] **Step 2: Add the ten translations**

Add the same keys (values only, no `@` blocks) to each locale file. Keep the ICU plural and placeholder syntax exactly.

`app_de.arb`:
```json
  "settings_manage_transmitters": "Sender",
  "settings_manage_transmitters_subtitle": "Luftintegrations-Sender mit Flaschen verknüpfen",
  "transmitters_title": "Sender",
  "transmitters_add": "Sender hinzufügen",
  "transmitters_header_assigned": "Zugewiesene Sender",
  "transmitters_header_unassigned": "In Downloads gesehen, nicht zugewiesen",
  "transmitters_empty": "Noch keine Sender. Füge einen hinzu oder weise nach dem nächsten Download eine Seriennummer zu.",
  "transmitters_action_assign": "Zuweisen",
  "transmitters_action_edit": "Sender bearbeiten",
  "transmitters_action_delete": "Sender löschen",
  "transmitters_action_apply": "Auf vorhandene Tauchgänge anwenden",
  "transmitters_apply_title": "Auf vorhandene Tauchgänge anwenden?",
  "transmitters_apply_content": "{tanks} Flaschen in {dives} Tauchgängen tragen diesen Sender. Leere Felder für Größe, Material, Name und Ausrüstung werden gefüllt, und eine noch auf Rückengas gesetzte Rolle wird ersetzt.",
  "transmitters_apply_done": "{tanks} Flaschen in {dives} Tauchgängen aktualisiert",
  "transmitters_apply_nothing": "Keine Flasche trägt diesen Sender",
  "transmitters_delete_title": "Sender löschen?",
  "transmitters_delete_content": "Künftige Downloads von {label} verwenden wieder die Standardvorlage.",
  "transmitters_channel": "{computer}, Kanal {channel}",
  "transmitters_serial": "Sender {serial}",
  "transmitters_dives": "{count, plural, =1{1 Tauchgang} other{{count} Tauchgänge}}",
  "transmitters_edit_title": "Sender bearbeiten",
  "transmitters_new_title": "Neuer Sender",
  "transmitters_field_label": "Bezeichnung",
  "transmitters_field_serial": "Seriennummer des Senders",
  "transmitters_field_computer": "Tauchcomputer (wenn keine Seriennummer gemeldet wird)",
  "transmitters_field_channel": "Kanal",
  "transmitters_field_role": "Rolle",
  "transmitters_field_gear": "Flasche aus der Ausrüstung",
  "transmitters_field_material": "Material",
  "transmitters_gear_none": "Keine",
  "transmitters_validation_key": "Gib eine Seriennummer ein oder wähle Tauchcomputer und Kanal",
  "transmitters_validation_positive": "Gib einen Wert größer als null ein",
  "transmitters_validation_duplicate": "Bereits {label} zugewiesen",
  "transmitters_saved": "Sender gespeichert",
  "diveComputer_detail_transmitters": "Sender",
  "diveComputer_detail_transmittersSummary": "{known} bekannt, {unassigned} nicht zugewiesen",
  "diveLog_tank_assignTransmitter": "Sender zuweisen",
  "diveLog_tank_reassignSeries": "Druckverlauf neu zuordnen",
  "diveLog_reassignSheet_title": "Druckverläufe",
  "diveLog_reassignSheet_swap": "Tauschen",
  "diveLog_reassignSheet_moveTo": "Verschieben nach",
  "diveLog_reassignSheet_readings": "{count, plural, =1{1 Messwert} other{{count} Messwerte}}",
  "diveLog_reassignSheet_noSeries": "Kein Druckverlauf",
  "diveLog_reassignSheet_applied": "Druckverlauf neu zugeordnet",
  "universalImport_summary_noticeUnknownTransmitterTitle": "Nicht zugewiesene Sender",
  "universalImport_summary_noticeUnknownTransmitterBody": "Ein oder mehrere Sender in diesem Download sind keiner Flasche zugewiesen. Weise sie zu, damit künftige Downloads die richtige Größe und Rolle erhalten.",
  "universalImport_summary_noticeAssignTransmitters": "Sender zuweisen",
  "dataQuality_detector_unknown_transmitter": "Nicht zugewiesener Sender",
  "dataQuality_msg_unknownTransmitter": "Sender {serial} ist keiner Flasche zugewiesen",
  "dataQuality_repairLabel_assignTransmitter": "Sender zuweisen"
```

`app_fr.arb`:
```json
  "settings_manage_transmitters": "Émetteurs",
  "settings_manage_transmitters_subtitle": "Associer les émetteurs de pression aux bouteilles",
  "transmitters_title": "Émetteurs",
  "transmitters_add": "Ajouter un émetteur",
  "transmitters_header_assigned": "Émetteurs associés",
  "transmitters_header_unassigned": "Vus dans les téléchargements, non associés",
  "transmitters_empty": "Aucun émetteur pour le moment. Ajoutez-en un, ou associez un numéro de série après votre prochain téléchargement.",
  "transmitters_action_assign": "Associer",
  "transmitters_action_edit": "Modifier l'émetteur",
  "transmitters_action_delete": "Supprimer l'émetteur",
  "transmitters_action_apply": "Appliquer aux plongées existantes",
  "transmitters_apply_title": "Appliquer aux plongées existantes ?",
  "transmitters_apply_content": "{tanks} bouteilles sur {dives} plongées portent cet émetteur. Les champs vides de taille, matériau, nom et équipement seront remplis, et un rôle encore réglé sur Gaz fond sera remplacé.",
  "transmitters_apply_done": "{tanks} bouteilles mises à jour sur {dives} plongées",
  "transmitters_apply_nothing": "Aucune bouteille ne porte cet émetteur",
  "transmitters_delete_title": "Supprimer l'émetteur ?",
  "transmitters_delete_content": "Les prochains téléchargements de {label} utiliseront de nouveau le préréglage par défaut.",
  "transmitters_channel": "{computer}, canal {channel}",
  "transmitters_serial": "Émetteur {serial}",
  "transmitters_dives": "{count, plural, =1{1 plongée} other{{count} plongées}}",
  "transmitters_edit_title": "Modifier l'émetteur",
  "transmitters_new_title": "Nouvel émetteur",
  "transmitters_field_label": "Libellé",
  "transmitters_field_serial": "Numéro de série de l'émetteur",
  "transmitters_field_computer": "Ordinateur de plongée (si aucun numéro de série n'est transmis)",
  "transmitters_field_channel": "Canal",
  "transmitters_field_role": "Rôle",
  "transmitters_field_gear": "Bouteille de l'équipement",
  "transmitters_field_material": "Matériau",
  "transmitters_gear_none": "Aucune",
  "transmitters_validation_key": "Saisissez un numéro de série, ou choisissez un ordinateur et un canal",
  "transmitters_validation_positive": "Saisissez une valeur supérieure à zéro",
  "transmitters_validation_duplicate": "Déjà associé à {label}",
  "transmitters_saved": "Émetteur enregistré",
  "diveComputer_detail_transmitters": "Émetteurs",
  "diveComputer_detail_transmittersSummary": "{known} connus, {unassigned} non associés",
  "diveLog_tank_assignTransmitter": "Associer l'émetteur",
  "diveLog_tank_reassignSeries": "Réattribuer la courbe de pression",
  "diveLog_reassignSheet_title": "Courbes de pression",
  "diveLog_reassignSheet_swap": "Échanger",
  "diveLog_reassignSheet_moveTo": "Déplacer vers",
  "diveLog_reassignSheet_readings": "{count, plural, =1{1 mesure} other{{count} mesures}}",
  "diveLog_reassignSheet_noSeries": "Aucune courbe de pression",
  "diveLog_reassignSheet_applied": "Courbe de pression réattribuée",
  "universalImport_summary_noticeUnknownTransmitterTitle": "Émetteurs non associés",
  "universalImport_summary_noticeUnknownTransmitterBody": "Un ou plusieurs émetteurs de ce téléchargement ne sont associés à aucune bouteille. Associez-les pour que les prochains téléchargements aient la bonne taille et le bon rôle.",
  "universalImport_summary_noticeAssignTransmitters": "Associer les émetteurs",
  "dataQuality_detector_unknown_transmitter": "Émetteur non associé",
  "dataQuality_msg_unknownTransmitter": "L'émetteur {serial} n'est associé à aucune bouteille",
  "dataQuality_repairLabel_assignTransmitter": "Associer l'émetteur"
```

`app_es.arb`:
```json
  "settings_manage_transmitters": "Transmisores",
  "settings_manage_transmitters_subtitle": "Vincular transmisores de presión con botellas",
  "transmitters_title": "Transmisores",
  "transmitters_add": "Añadir transmisor",
  "transmitters_header_assigned": "Transmisores asignados",
  "transmitters_header_unassigned": "Vistos en descargas, sin asignar",
  "transmitters_empty": "Aún no hay transmisores. Añade uno o asigna un número de serie tras tu próxima descarga.",
  "transmitters_action_assign": "Asignar",
  "transmitters_action_edit": "Editar transmisor",
  "transmitters_action_delete": "Eliminar transmisor",
  "transmitters_action_apply": "Aplicar a inmersiones existentes",
  "transmitters_apply_title": "¿Aplicar a inmersiones existentes?",
  "transmitters_apply_content": "{tanks} botellas en {dives} inmersiones llevan este transmisor. Se rellenarán los campos vacíos de tamaño, material, nombre y equipo, y se sustituirá un rol que siga en Gas de fondo.",
  "transmitters_apply_done": "{tanks} botellas actualizadas en {dives} inmersiones",
  "transmitters_apply_nothing": "Ninguna botella lleva este transmisor",
  "transmitters_delete_title": "¿Eliminar transmisor?",
  "transmitters_delete_content": "Las próximas descargas de {label} volverán a usar el preajuste predeterminado.",
  "transmitters_channel": "{computer}, canal {channel}",
  "transmitters_serial": "Transmisor {serial}",
  "transmitters_dives": "{count, plural, =1{1 inmersión} other{{count} inmersiones}}",
  "transmitters_edit_title": "Editar transmisor",
  "transmitters_new_title": "Nuevo transmisor",
  "transmitters_field_label": "Etiqueta",
  "transmitters_field_serial": "Número de serie del transmisor",
  "transmitters_field_computer": "Ordenador de buceo (si no se informa el número de serie)",
  "transmitters_field_channel": "Canal",
  "transmitters_field_role": "Rol",
  "transmitters_field_gear": "Botella del equipo",
  "transmitters_field_material": "Material",
  "transmitters_gear_none": "Ninguna",
  "transmitters_validation_key": "Introduce un número de serie o elige un ordenador y un canal",
  "transmitters_validation_positive": "Introduce un valor mayor que cero",
  "transmitters_validation_duplicate": "Ya asignado a {label}",
  "transmitters_saved": "Transmisor guardado",
  "diveComputer_detail_transmitters": "Transmisores",
  "diveComputer_detail_transmittersSummary": "{known} conocidos, {unassigned} sin asignar",
  "diveLog_tank_assignTransmitter": "Asignar transmisor",
  "diveLog_tank_reassignSeries": "Reasignar serie de presión",
  "diveLog_reassignSheet_title": "Series de presión",
  "diveLog_reassignSheet_swap": "Intercambiar",
  "diveLog_reassignSheet_moveTo": "Mover a",
  "diveLog_reassignSheet_readings": "{count, plural, =1{1 lectura} other{{count} lecturas}}",
  "diveLog_reassignSheet_noSeries": "Sin serie de presión",
  "diveLog_reassignSheet_applied": "Serie de presión reasignada",
  "universalImport_summary_noticeUnknownTransmitterTitle": "Transmisores sin asignar",
  "universalImport_summary_noticeUnknownTransmitterBody": "Uno o más transmisores de esta descarga no están asignados a una botella. Asígnalos para que las próximas descargas tengan el tamaño y el rol correctos.",
  "universalImport_summary_noticeAssignTransmitters": "Asignar transmisores",
  "dataQuality_detector_unknown_transmitter": "Transmisor sin asignar",
  "dataQuality_msg_unknownTransmitter": "El transmisor {serial} no está asignado a ninguna botella",
  "dataQuality_repairLabel_assignTransmitter": "Asignar transmisor"
```

`app_it.arb`:
```json
  "settings_manage_transmitters": "Trasmettitori",
  "settings_manage_transmitters_subtitle": "Collega i trasmettitori di pressione alle bombole",
  "transmitters_title": "Trasmettitori",
  "transmitters_add": "Aggiungi trasmettitore",
  "transmitters_header_assigned": "Trasmettitori assegnati",
  "transmitters_header_unassigned": "Visti nei download, non assegnati",
  "transmitters_empty": "Nessun trasmettitore. Aggiungine uno o assegna un numero di serie dopo il prossimo download.",
  "transmitters_action_assign": "Assegna",
  "transmitters_action_edit": "Modifica trasmettitore",
  "transmitters_action_delete": "Elimina trasmettitore",
  "transmitters_action_apply": "Applica alle immersioni esistenti",
  "transmitters_apply_title": "Applicare alle immersioni esistenti?",
  "transmitters_apply_content": "{tanks} bombole in {dives} immersioni portano questo trasmettitore. I campi vuoti di dimensione, materiale, nome e attrezzatura verranno compilati e un ruolo ancora impostato su Gas di fondo verrà sostituito.",
  "transmitters_apply_done": "Aggiornate {tanks} bombole in {dives} immersioni",
  "transmitters_apply_nothing": "Nessuna bombola porta questo trasmettitore",
  "transmitters_delete_title": "Eliminare il trasmettitore?",
  "transmitters_delete_content": "I prossimi download da {label} useranno di nuovo il preset predefinito.",
  "transmitters_channel": "{computer}, canale {channel}",
  "transmitters_serial": "Trasmettitore {serial}",
  "transmitters_dives": "{count, plural, =1{1 immersione} other{{count} immersioni}}",
  "transmitters_edit_title": "Modifica trasmettitore",
  "transmitters_new_title": "Nuovo trasmettitore",
  "transmitters_field_label": "Etichetta",
  "transmitters_field_serial": "Numero di serie del trasmettitore",
  "transmitters_field_computer": "Computer subacqueo (se il numero di serie non viene riportato)",
  "transmitters_field_channel": "Canale",
  "transmitters_field_role": "Ruolo",
  "transmitters_field_gear": "Bombola dall'attrezzatura",
  "transmitters_field_material": "Materiale",
  "transmitters_gear_none": "Nessuna",
  "transmitters_validation_key": "Inserisci un numero di serie oppure scegli computer e canale",
  "transmitters_validation_positive": "Inserisci un valore maggiore di zero",
  "transmitters_validation_duplicate": "Già assegnato a {label}",
  "transmitters_saved": "Trasmettitore salvato",
  "diveComputer_detail_transmitters": "Trasmettitori",
  "diveComputer_detail_transmittersSummary": "{known} noti, {unassigned} non assegnati",
  "diveLog_tank_assignTransmitter": "Assegna trasmettitore",
  "diveLog_tank_reassignSeries": "Riassegna serie di pressione",
  "diveLog_reassignSheet_title": "Serie di pressione",
  "diveLog_reassignSheet_swap": "Scambia",
  "diveLog_reassignSheet_moveTo": "Sposta su",
  "diveLog_reassignSheet_readings": "{count, plural, =1{1 lettura} other{{count} letture}}",
  "diveLog_reassignSheet_noSeries": "Nessuna serie di pressione",
  "diveLog_reassignSheet_applied": "Serie di pressione riassegnata",
  "universalImport_summary_noticeUnknownTransmitterTitle": "Trasmettitori non assegnati",
  "universalImport_summary_noticeUnknownTransmitterBody": "Uno o più trasmettitori di questo download non sono assegnati a una bombola. Assegnali perché i prossimi download abbiano dimensione e ruolo corretti.",
  "universalImport_summary_noticeAssignTransmitters": "Assegna trasmettitori",
  "dataQuality_detector_unknown_transmitter": "Trasmettitore non assegnato",
  "dataQuality_msg_unknownTransmitter": "Il trasmettitore {serial} non è assegnato a nessuna bombola",
  "dataQuality_repairLabel_assignTransmitter": "Assegna trasmettitore"
```

`app_nl.arb`:
```json
  "settings_manage_transmitters": "Zenders",
  "settings_manage_transmitters_subtitle": "Koppel drukzenders aan flessen",
  "transmitters_title": "Zenders",
  "transmitters_add": "Zender toevoegen",
  "transmitters_header_assigned": "Toegewezen zenders",
  "transmitters_header_unassigned": "Gezien in downloads, niet toegewezen",
  "transmitters_empty": "Nog geen zenders. Voeg er een toe, of wijs na je volgende download een serienummer toe.",
  "transmitters_action_assign": "Toewijzen",
  "transmitters_action_edit": "Zender bewerken",
  "transmitters_action_delete": "Zender verwijderen",
  "transmitters_action_apply": "Toepassen op bestaande duiken",
  "transmitters_apply_title": "Toepassen op bestaande duiken?",
  "transmitters_apply_content": "{tanks} flessen in {dives} duiken dragen deze zender. Lege velden voor inhoud, materiaal, naam en uitrusting worden ingevuld, en een rol die nog op Ruggas staat wordt vervangen.",
  "transmitters_apply_done": "{tanks} flessen bijgewerkt in {dives} duiken",
  "transmitters_apply_nothing": "Geen enkele fles draagt deze zender",
  "transmitters_delete_title": "Zender verwijderen?",
  "transmitters_delete_content": "Toekomstige downloads van {label} gebruiken weer de standaardvoorinstelling.",
  "transmitters_channel": "{computer}, kanaal {channel}",
  "transmitters_serial": "Zender {serial}",
  "transmitters_dives": "{count, plural, =1{1 duik} other{{count} duiken}}",
  "transmitters_edit_title": "Zender bewerken",
  "transmitters_new_title": "Nieuwe zender",
  "transmitters_field_label": "Label",
  "transmitters_field_serial": "Serienummer van de zender",
  "transmitters_field_computer": "Duikcomputer (als er geen serienummer wordt gemeld)",
  "transmitters_field_channel": "Kanaal",
  "transmitters_field_role": "Rol",
  "transmitters_field_gear": "Fles uit uitrusting",
  "transmitters_field_material": "Materiaal",
  "transmitters_gear_none": "Geen",
  "transmitters_validation_key": "Voer een serienummer in, of kies een duikcomputer en kanaal",
  "transmitters_validation_positive": "Voer een waarde groter dan nul in",
  "transmitters_validation_duplicate": "Al toegewezen aan {label}",
  "transmitters_saved": "Zender opgeslagen",
  "diveComputer_detail_transmitters": "Zenders",
  "diveComputer_detail_transmittersSummary": "{known} bekend, {unassigned} niet toegewezen",
  "diveLog_tank_assignTransmitter": "Zender toewijzen",
  "diveLog_tank_reassignSeries": "Drukreeks opnieuw toewijzen",
  "diveLog_reassignSheet_title": "Drukreeksen",
  "diveLog_reassignSheet_swap": "Wisselen",
  "diveLog_reassignSheet_moveTo": "Verplaatsen naar",
  "diveLog_reassignSheet_readings": "{count, plural, =1{1 meting} other{{count} metingen}}",
  "diveLog_reassignSheet_noSeries": "Geen drukreeks",
  "diveLog_reassignSheet_applied": "Drukreeks opnieuw toegewezen",
  "universalImport_summary_noticeUnknownTransmitterTitle": "Niet-toegewezen zenders",
  "universalImport_summary_noticeUnknownTransmitterBody": "Een of meer zenders in deze download zijn niet aan een fles toegewezen. Wijs ze toe zodat toekomstige downloads de juiste inhoud en rol krijgen.",
  "universalImport_summary_noticeAssignTransmitters": "Zenders toewijzen",
  "dataQuality_detector_unknown_transmitter": "Niet-toegewezen zender",
  "dataQuality_msg_unknownTransmitter": "Zender {serial} is niet aan een fles toegewezen",
  "dataQuality_repairLabel_assignTransmitter": "Zender toewijzen"
```

`app_pt.arb`:
```json
  "settings_manage_transmitters": "Transmissores",
  "settings_manage_transmitters_subtitle": "Associar transmissores de pressão a cilindros",
  "transmitters_title": "Transmissores",
  "transmitters_add": "Adicionar transmissor",
  "transmitters_header_assigned": "Transmissores atribuídos",
  "transmitters_header_unassigned": "Vistos em downloads, não atribuídos",
  "transmitters_empty": "Ainda não há transmissores. Adicione um ou atribua um número de série após o próximo download.",
  "transmitters_action_assign": "Atribuir",
  "transmitters_action_edit": "Editar transmissor",
  "transmitters_action_delete": "Excluir transmissor",
  "transmitters_action_apply": "Aplicar a mergulhos existentes",
  "transmitters_apply_title": "Aplicar a mergulhos existentes?",
  "transmitters_apply_content": "{tanks} cilindros em {dives} mergulhos carregam este transmissor. Campos vazios de tamanho, material, nome e equipamento serão preenchidos, e uma função ainda definida como Gás de fundo será substituída.",
  "transmitters_apply_done": "{tanks} cilindros atualizados em {dives} mergulhos",
  "transmitters_apply_nothing": "Nenhum cilindro carrega este transmissor",
  "transmitters_delete_title": "Excluir transmissor?",
  "transmitters_delete_content": "Os próximos downloads de {label} voltarão a usar a predefinição padrão.",
  "transmitters_channel": "{computer}, canal {channel}",
  "transmitters_serial": "Transmissor {serial}",
  "transmitters_dives": "{count, plural, =1{1 mergulho} other{{count} mergulhos}}",
  "transmitters_edit_title": "Editar transmissor",
  "transmitters_new_title": "Novo transmissor",
  "transmitters_field_label": "Rótulo",
  "transmitters_field_serial": "Número de série do transmissor",
  "transmitters_field_computer": "Computador de mergulho (quando nenhum número de série é informado)",
  "transmitters_field_channel": "Canal",
  "transmitters_field_role": "Função",
  "transmitters_field_gear": "Cilindro do equipamento",
  "transmitters_field_material": "Material",
  "transmitters_gear_none": "Nenhum",
  "transmitters_validation_key": "Informe um número de série ou escolha um computador e um canal",
  "transmitters_validation_positive": "Informe um valor maior que zero",
  "transmitters_validation_duplicate": "Já atribuído a {label}",
  "transmitters_saved": "Transmissor salvo",
  "diveComputer_detail_transmitters": "Transmissores",
  "diveComputer_detail_transmittersSummary": "{known} conhecidos, {unassigned} não atribuídos",
  "diveLog_tank_assignTransmitter": "Atribuir transmissor",
  "diveLog_tank_reassignSeries": "Reatribuir série de pressão",
  "diveLog_reassignSheet_title": "Séries de pressão",
  "diveLog_reassignSheet_swap": "Trocar",
  "diveLog_reassignSheet_moveTo": "Mover para",
  "diveLog_reassignSheet_readings": "{count, plural, =1{1 leitura} other{{count} leituras}}",
  "diveLog_reassignSheet_noSeries": "Sem série de pressão",
  "diveLog_reassignSheet_applied": "Série de pressão reatribuída",
  "universalImport_summary_noticeUnknownTransmitterTitle": "Transmissores não atribuídos",
  "universalImport_summary_noticeUnknownTransmitterBody": "Um ou mais transmissores deste download não estão atribuídos a um cilindro. Atribua-os para que os próximos downloads tenham o tamanho e a função corretos.",
  "universalImport_summary_noticeAssignTransmitters": "Atribuir transmissores",
  "dataQuality_detector_unknown_transmitter": "Transmissor não atribuído",
  "dataQuality_msg_unknownTransmitter": "O transmissor {serial} não está atribuído a nenhum cilindro",
  "dataQuality_repairLabel_assignTransmitter": "Atribuir transmissor"
```

`app_hu.arb`:
```json
  "settings_manage_transmitters": "Jeladók",
  "settings_manage_transmitters_subtitle": "Nyomásjeladók hozzárendelése palackokhoz",
  "transmitters_title": "Jeladók",
  "transmitters_add": "Jeladó hozzáadása",
  "transmitters_header_assigned": "Hozzárendelt jeladók",
  "transmitters_header_unassigned": "Letöltésekben látott, nincs hozzárendelve",
  "transmitters_empty": "Még nincs jeladó. Adj hozzá egyet, vagy rendelj hozzá sorozatszámot a következő letöltés után.",
  "transmitters_action_assign": "Hozzárendelés",
  "transmitters_action_edit": "Jeladó szerkesztése",
  "transmitters_action_delete": "Jeladó törlése",
  "transmitters_action_apply": "Alkalmazás meglévő merülésekre",
  "transmitters_apply_title": "Alkalmazod a meglévő merülésekre?",
  "transmitters_apply_content": "{tanks} palack {dives} merülésben viseli ezt a jeladót. Az üres méret-, anyag-, név- és felszerelésmezők kitöltődnek, és a még Hátgázra állított szerep lecserélődik.",
  "transmitters_apply_done": "{tanks} palack frissítve {dives} merülésben",
  "transmitters_apply_nothing": "Egyetlen palack sem viseli ezt a jeladót",
  "transmitters_delete_title": "Törlöd a jeladót?",
  "transmitters_delete_content": "A(z) {label} jövőbeli letöltései ismét az alapértelmezett sablont használják.",
  "transmitters_channel": "{computer}, {channel}. csatorna",
  "transmitters_serial": "{serial} jeladó",
  "transmitters_dives": "{count, plural, =1{1 merülés} other{{count} merülés}}",
  "transmitters_edit_title": "Jeladó szerkesztése",
  "transmitters_new_title": "Új jeladó",
  "transmitters_field_label": "Címke",
  "transmitters_field_serial": "Jeladó sorozatszáma",
  "transmitters_field_computer": "Búvárkomputer (ha nincs sorozatszám)",
  "transmitters_field_channel": "Csatorna",
  "transmitters_field_role": "Szerep",
  "transmitters_field_gear": "Palack a felszerelésből",
  "transmitters_field_material": "Anyag",
  "transmitters_gear_none": "Nincs",
  "transmitters_validation_key": "Adj meg egy sorozatszámot, vagy válassz komputert és csatornát",
  "transmitters_validation_positive": "Nullánál nagyobb értéket adj meg",
  "transmitters_validation_duplicate": "Már hozzá van rendelve: {label}",
  "transmitters_saved": "Jeladó mentve",
  "diveComputer_detail_transmitters": "Jeladók",
  "diveComputer_detail_transmittersSummary": "{known} ismert, {unassigned} nincs hozzárendelve",
  "diveLog_tank_assignTransmitter": "Jeladó hozzárendelése",
  "diveLog_tank_reassignSeries": "Nyomásgörbe áthelyezése",
  "diveLog_reassignSheet_title": "Nyomásgörbék",
  "diveLog_reassignSheet_swap": "Csere",
  "diveLog_reassignSheet_moveTo": "Áthelyezés ide",
  "diveLog_reassignSheet_readings": "{count, plural, =1{1 mérés} other{{count} mérés}}",
  "diveLog_reassignSheet_noSeries": "Nincs nyomásgörbe",
  "diveLog_reassignSheet_applied": "Nyomásgörbe áthelyezve",
  "universalImport_summary_noticeUnknownTransmitterTitle": "Hozzá nem rendelt jeladók",
  "universalImport_summary_noticeUnknownTransmitterBody": "A letöltés egy vagy több jeladója nincs palackhoz rendelve. Rendeld hozzá őket, hogy a jövőbeli letöltések a helyes méretet és szerepet kapják.",
  "universalImport_summary_noticeAssignTransmitters": "Jeladók hozzárendelése",
  "dataQuality_detector_unknown_transmitter": "Hozzá nem rendelt jeladó",
  "dataQuality_msg_unknownTransmitter": "A(z) {serial} jeladó nincs palackhoz rendelve",
  "dataQuality_repairLabel_assignTransmitter": "Jeladó hozzárendelése"
```

`app_zh.arb`:
```json
  "settings_manage_transmitters": "发射器",
  "settings_manage_transmitters_subtitle": "将气瓶压力发射器关联到气瓶",
  "transmitters_title": "发射器",
  "transmitters_add": "添加发射器",
  "transmitters_header_assigned": "已分配的发射器",
  "transmitters_header_unassigned": "下载中出现但未分配",
  "transmitters_empty": "还没有发射器。添加一个，或在下次下载后分配序列号。",
  "transmitters_action_assign": "分配",
  "transmitters_action_edit": "编辑发射器",
  "transmitters_action_delete": "删除发射器",
  "transmitters_action_apply": "应用到现有潜水",
  "transmitters_apply_title": "应用到现有潜水？",
  "transmitters_apply_content": "{dives} 次潜水中的 {tanks} 个气瓶带有此发射器。空白的容量、材质、名称和装备字段将被填充，仍为背气的用途将被替换。",
  "transmitters_apply_done": "已更新 {dives} 次潜水中的 {tanks} 个气瓶",
  "transmitters_apply_nothing": "没有气瓶带有此发射器",
  "transmitters_delete_title": "删除发射器？",
  "transmitters_delete_content": "今后从 {label} 的下载将重新使用默认预设。",
  "transmitters_channel": "{computer}，通道 {channel}",
  "transmitters_serial": "发射器 {serial}",
  "transmitters_dives": "{count, plural, =1{1 次潜水} other{{count} 次潜水}}",
  "transmitters_edit_title": "编辑发射器",
  "transmitters_new_title": "新发射器",
  "transmitters_field_label": "标签",
  "transmitters_field_serial": "发射器序列号",
  "transmitters_field_computer": "潜水电脑（未报告序列号时使用）",
  "transmitters_field_channel": "通道",
  "transmitters_field_role": "用途",
  "transmitters_field_gear": "来自装备的气瓶",
  "transmitters_field_material": "材质",
  "transmitters_gear_none": "无",
  "transmitters_validation_key": "请输入发射器序列号，或选择潜水电脑和通道",
  "transmitters_validation_positive": "请输入大于零的值",
  "transmitters_validation_duplicate": "已分配给 {label}",
  "transmitters_saved": "发射器已保存",
  "diveComputer_detail_transmitters": "发射器",
  "diveComputer_detail_transmittersSummary": "{known} 个已知，{unassigned} 个未分配",
  "diveLog_tank_assignTransmitter": "分配发射器",
  "diveLog_tank_reassignSeries": "重新分配压力曲线",
  "diveLog_reassignSheet_title": "压力曲线",
  "diveLog_reassignSheet_swap": "交换",
  "diveLog_reassignSheet_moveTo": "移动到",
  "diveLog_reassignSheet_readings": "{count, plural, =1{1 个读数} other{{count} 个读数}}",
  "diveLog_reassignSheet_noSeries": "没有压力曲线",
  "diveLog_reassignSheet_applied": "压力曲线已重新分配",
  "universalImport_summary_noticeUnknownTransmitterTitle": "未分配的发射器",
  "universalImport_summary_noticeUnknownTransmitterBody": "此次下载中有一个或多个发射器未分配到气瓶。分配后，今后的下载将获得正确的容量和用途。",
  "universalImport_summary_noticeAssignTransmitters": "分配发射器",
  "dataQuality_detector_unknown_transmitter": "未分配的发射器",
  "dataQuality_msg_unknownTransmitter": "发射器 {serial} 未分配到气瓶",
  "dataQuality_repairLabel_assignTransmitter": "分配发射器"
```

`app_ar.arb`:
```json
  "settings_manage_transmitters": "أجهزة الإرسال",
  "settings_manage_transmitters_subtitle": "ربط أجهزة إرسال الضغط بالأسطوانات",
  "transmitters_title": "أجهزة الإرسال",
  "transmitters_add": "إضافة جهاز إرسال",
  "transmitters_header_assigned": "أجهزة إرسال معيّنة",
  "transmitters_header_unassigned": "ظهرت في التنزيلات ولم تُعيّن",
  "transmitters_empty": "لا توجد أجهزة إرسال بعد. أضف واحدًا، أو عيّن رقمًا تسلسليًا بعد التنزيل التالي.",
  "transmitters_action_assign": "تعيين",
  "transmitters_action_edit": "تعديل جهاز الإرسال",
  "transmitters_action_delete": "حذف جهاز الإرسال",
  "transmitters_action_apply": "تطبيق على الغطسات الحالية",
  "transmitters_apply_title": "تطبيق على الغطسات الحالية؟",
  "transmitters_apply_content": "{tanks} أسطوانة في {dives} غطسة تحمل جهاز الإرسال هذا. ستُملأ حقول الحجم والمادة والاسم والمعدات الفارغة، وسيُستبدل الدور الذي ما زال مضبوطًا على غاز الظهر.",
  "transmitters_apply_done": "تم تحديث {tanks} أسطوانة في {dives} غطسة",
  "transmitters_apply_nothing": "لا توجد أسطوانة تحمل جهاز الإرسال هذا",
  "transmitters_delete_title": "حذف جهاز الإرسال؟",
  "transmitters_delete_content": "ستستخدم التنزيلات القادمة من {label} الإعداد الافتراضي مجددًا.",
  "transmitters_channel": "{computer}، القناة {channel}",
  "transmitters_serial": "جهاز الإرسال {serial}",
  "transmitters_dives": "{count, plural, =1{غطسة واحدة} other{{count} غطسة}}",
  "transmitters_edit_title": "تعديل جهاز الإرسال",
  "transmitters_new_title": "جهاز إرسال جديد",
  "transmitters_field_label": "التسمية",
  "transmitters_field_serial": "الرقم التسلسلي لجهاز الإرسال",
  "transmitters_field_computer": "كمبيوتر الغوص (عند عدم الإبلاغ عن رقم تسلسلي)",
  "transmitters_field_channel": "القناة",
  "transmitters_field_role": "الدور",
  "transmitters_field_gear": "أسطوانة من المعدات",
  "transmitters_field_material": "المادة",
  "transmitters_gear_none": "لا شيء",
  "transmitters_validation_key": "أدخل رقمًا تسلسليًا، أو اختر كمبيوتر غوص وقناة",
  "transmitters_validation_positive": "أدخل قيمة أكبر من صفر",
  "transmitters_validation_duplicate": "معيّن بالفعل إلى {label}",
  "transmitters_saved": "تم حفظ جهاز الإرسال",
  "diveComputer_detail_transmitters": "أجهزة الإرسال",
  "diveComputer_detail_transmittersSummary": "{known} معروف، {unassigned} غير معيّن",
  "diveLog_tank_assignTransmitter": "تعيين جهاز إرسال",
  "diveLog_tank_reassignSeries": "إعادة تعيين سلسلة الضغط",
  "diveLog_reassignSheet_title": "سلاسل الضغط",
  "diveLog_reassignSheet_swap": "تبديل",
  "diveLog_reassignSheet_moveTo": "نقل إلى",
  "diveLog_reassignSheet_readings": "{count, plural, =1{قراءة واحدة} other{{count} قراءة}}",
  "diveLog_reassignSheet_noSeries": "لا توجد سلسلة ضغط",
  "diveLog_reassignSheet_applied": "تمت إعادة تعيين سلسلة الضغط",
  "universalImport_summary_noticeUnknownTransmitterTitle": "أجهزة إرسال غير معيّنة",
  "universalImport_summary_noticeUnknownTransmitterBody": "جهاز إرسال واحد أو أكثر في هذا التنزيل غير معيّن لأسطوانة. عيّنها لتحصل التنزيلات القادمة على الحجم والدور الصحيحين.",
  "universalImport_summary_noticeAssignTransmitters": "تعيين أجهزة الإرسال",
  "dataQuality_detector_unknown_transmitter": "جهاز إرسال غير معيّن",
  "dataQuality_msg_unknownTransmitter": "جهاز الإرسال {serial} غير معيّن لأسطوانة",
  "dataQuality_repairLabel_assignTransmitter": "تعيين جهاز إرسال"
```

`app_he.arb`:
```json
  "settings_manage_transmitters": "משדרים",
  "settings_manage_transmitters_subtitle": "קישור משדרי לחץ למיכלים",
  "transmitters_title": "משדרים",
  "transmitters_add": "הוספת משדר",
  "transmitters_header_assigned": "משדרים משויכים",
  "transmitters_header_unassigned": "נראו בהורדות, לא משויכים",
  "transmitters_empty": "אין משדרים עדיין. הוסיפו אחד, או שייכו מספר סידורי אחרי ההורדה הבאה.",
  "transmitters_action_assign": "שיוך",
  "transmitters_action_edit": "עריכת משדר",
  "transmitters_action_delete": "מחיקת משדר",
  "transmitters_action_apply": "החלה על צלילות קיימות",
  "transmitters_apply_title": "להחיל על צלילות קיימות?",
  "transmitters_apply_content": "{tanks} מיכלים ב-{dives} צלילות נושאים משדר זה. שדות ריקים של נפח, חומר, שם וציוד ימולאו, ותפקיד שעדיין מוגדר כגז גב יוחלף.",
  "transmitters_apply_done": "עודכנו {tanks} מיכלים ב-{dives} צלילות",
  "transmitters_apply_nothing": "אף מיכל אינו נושא משדר זה",
  "transmitters_delete_title": "למחוק את המשדר?",
  "transmitters_delete_content": "הורדות עתידיות מ-{label} ישתמשו שוב בהגדרה המוגדרת כברירת מחדל.",
  "transmitters_channel": "{computer}, ערוץ {channel}",
  "transmitters_serial": "משדר {serial}",
  "transmitters_dives": "{count, plural, =1{צלילה אחת} other{{count} צלילות}}",
  "transmitters_edit_title": "עריכת משדר",
  "transmitters_new_title": "משדר חדש",
  "transmitters_field_label": "תווית",
  "transmitters_field_serial": "מספר סידורי של המשדר",
  "transmitters_field_computer": "מחשב צלילה (כשלא מדווח מספר סידורי)",
  "transmitters_field_channel": "ערוץ",
  "transmitters_field_role": "תפקיד",
  "transmitters_field_gear": "מיכל מהציוד",
  "transmitters_field_material": "חומר",
  "transmitters_gear_none": "ללא",
  "transmitters_validation_key": "הזינו מספר סידורי, או בחרו מחשב צלילה וערוץ",
  "transmitters_validation_positive": "הזינו ערך גדול מאפס",
  "transmitters_validation_duplicate": "כבר משויך ל-{label}",
  "transmitters_saved": "המשדר נשמר",
  "diveComputer_detail_transmitters": "משדרים",
  "diveComputer_detail_transmittersSummary": "{known} מוכרים, {unassigned} לא משויכים",
  "diveLog_tank_assignTransmitter": "שיוך משדר",
  "diveLog_tank_reassignSeries": "שיוך מחדש של סדרת הלחץ",
  "diveLog_reassignSheet_title": "סדרות לחץ",
  "diveLog_reassignSheet_swap": "החלפה",
  "diveLog_reassignSheet_moveTo": "העברה אל",
  "diveLog_reassignSheet_readings": "{count, plural, =1{קריאה אחת} other{{count} קריאות}}",
  "diveLog_reassignSheet_noSeries": "אין סדרת לחץ",
  "diveLog_reassignSheet_applied": "סדרת הלחץ שויכה מחדש",
  "universalImport_summary_noticeUnknownTransmitterTitle": "משדרים לא משויכים",
  "universalImport_summary_noticeUnknownTransmitterBody": "משדר אחד או יותר בהורדה זו אינם משויכים למיכל. שייכו אותם כדי שהורדות עתידיות יקבלו את הנפח והתפקיד הנכונים.",
  "universalImport_summary_noticeAssignTransmitters": "שיוך משדרים",
  "dataQuality_detector_unknown_transmitter": "משדר לא משויך",
  "dataQuality_msg_unknownTransmitter": "משדר {serial} אינו משויך למיכל",
  "dataQuality_repairLabel_assignTransmitter": "שיוך משדר"
```

- [ ] **Step 3: Regenerate and verify**

Run `flutter gen-l10n`, then `flutter analyze` (read its exit status directly). Then confirm no key is missing from any locale:

```bash
for f in lib/l10n/arb/app_*.arb; do n=$(grep -c '"transmitters_saved"' "$f"); echo "$f $n"; done
```

Expected: every line ends in `1`. Also confirm no em-dash slipped in:

```bash
grep -c $'\xe2\x80\x94' lib/l10n/arb/app_en.arb
```

Expected: the count you saw before this task (this plan adds none).

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/arb
git commit -m "i18n: strings for the transmitter registry and series reassignment"
```

---

### Task 11: Providers, the Transmitters manage page, the editor, routes and the Settings tile

**Files:**
- Modify: `lib/features/transmitters/presentation/providers/transmitter_providers.dart` (add list providers)
- Modify: `lib/features/transmitters/data/repositories/transmitter_repository.dart` (add `previewApplyToExistingDives`)
- Create: `lib/features/transmitters/presentation/pages/transmitters_page.dart`
- Create: `lib/features/transmitters/presentation/pages/transmitter_edit_page.dart`
- Modify: `lib/core/router/app_router.dart` (after the `/tank-presets` GoRoute at ~1328)
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (after the Tank Presets `ListTile` at ~2450)
- Test: `test/features/transmitters/presentation/pages/transmitters_page_test.dart`, `test/features/transmitters/presentation/pages/transmitter_edit_page_test.dart`

**Interfaces:**
- Consumes: `TransmitterRepository`, `Transmitter`, `validatedCurrentDiverIdProvider`, `tankPresetsProvider`, `EquipmentPickerSheet(typeFilter:)`, `EquipmentItem.volumeL/workingPressureBar/tankMaterial`, `equipmentItemProvider`, `TankRoleDisplay`/`TankMaterialDisplay` extensions in `lib/features/dive_log/presentation/widgets/tank_enum_display.dart`, `builtInTankPresetName`, `UnitFormatter`, `parseUserDecimal`/`formatRoundedForInput` from `lib/core/utils/number_input.dart`.
- Produces: `transmittersProvider` (`FutureProvider<List<Transmitter>>`), `unassignedTransmitterSerialsProvider`, `transmitterProvider(id)`, `transmitterComputerSummaryProvider(computerId)`; routes `/transmitters`, `/transmitters/new` (query `serial`), `/transmitters/:transmitterId/edit`; `TransmittersPage`, `TransmitterEditPage({String? transmitterId, String? initialSerial})`.

- [ ] **Step 1: Write the failing page tests**

Create `test/features/transmitters/presentation/pages/transmitters_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/pages/transmitters_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

Future<void> _seed() async {
  final db = DatabaseService.instance.database;
  await db.customStatement(
    "INSERT INTO divers (id, name, created_at, updated_at) "
    "VALUES ('diver-1', 'A', 1, 1)",
  );
  await db.customStatement(
    "INSERT INTO dives (id, diver_id, dive_date_time, created_at, updated_at) "
    "VALUES ('d1', 'diver-1', 1, 1, 1)",
  );
  await db.customStatement(
    "INSERT INTO dive_tanks (id, dive_id, transmitter_serial, tank_order) "
    "VALUES ('k1', 'd1', '555', 0)",
  );
}

final _pushed = <String>[];

Widget _buildPage(MockCurrentDiverIdNotifier diverIdNotifier, SharedPreferences prefs) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const TransmittersPage()),
      GoRoute(
        path: '/transmitters/new',
        builder: (context, state) {
          _pushed.add(state.uri.toString());
          return const Scaffold(body: Text('NEW_PAGE'));
        },
      ),
      GoRoute(
        path: '/transmitters/:transmitterId/edit',
        builder: (context, state) {
          _pushed.add(state.uri.toString());
          return const Scaffold(body: Text('EDIT_PAGE'));
        },
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      currentDiverIdProvider.overrideWith((ref) => diverIdNotifier),
      validatedCurrentDiverIdProvider.overrideWith((ref) async => 'diver-1'),
    ].cast(),
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      routerConfig: router,
    ),
  );
}

void main() {
  late MockCurrentDiverIdNotifier diverIdNotifier;
  late SharedPreferences prefs;

  setUp(() async {
    _pushed.clear();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    await _seed();
    diverIdNotifier = MockCurrentDiverIdNotifier();
    await diverIdNotifier.setCurrentDiver('diver-1');
  });
  tearDown(tearDownTestDatabase);

  testWidgets('lists entries with size in the diver units and unassigned serials',
      (tester) async {
    await TransmitterRepository().create(
      Transmitter(
        id: 'e1',
        diverId: 'diver-1',
        transmitterSerial: '180777',
        label: 'O2',
        role: TankRole.oxygenSupply,
        volumeL: 2.0,
        workingPressureBar: 232,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    );

    await tester.pumpWidget(_buildPage(diverIdNotifier, prefs));
    await tester.pumpAndSettle();

    expect(find.text('Assigned transmitters'), findsOneWidget);
    expect(find.text('O2'), findsOneWidget);
    expect(find.textContaining('Transmitter 180777'), findsOneWidget);
    expect(find.textContaining('232 bar'), findsOneWidget);
    expect(find.text('Seen in downloads, not assigned'), findsOneWidget);
    expect(find.textContaining('Transmitter 555'), findsOneWidget);
    expect(find.text('1 dive'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('Assign opens the editor with the serial prefilled', (tester) async {
    await tester.pumpWidget(_buildPage(diverIdNotifier, prefs));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Assign'));
    await tester.pumpAndSettle();

    expect(_pushed, ['/transmitters/new?serial=555']);
  });

  testWidgets('the FAB opens a blank editor', (tester) async {
    await tester.pumpWidget(_buildPage(diverIdNotifier, prefs));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(_pushed, ['/transmitters/new']);
  });

  testWidgets('delete asks first and removes the entry', (tester) async {
    await TransmitterRepository().create(
      Transmitter(
        id: 'e1',
        diverId: 'diver-1',
        transmitterSerial: '180777',
        label: 'O2',
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    );
    await tester.pumpWidget(_buildPage(diverIdNotifier, prefs));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete transmitter?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('O2'), findsNothing);
    expect(await TransmitterRepository().getById('e1'), isNull);
  });

  testWidgets('apply to existing dives confirms with counts and updates',
      (tester) async {
    await TransmitterRepository().create(
      Transmitter(
        id: 'e1',
        diverId: 'diver-1',
        transmitterSerial: '555',
        label: 'Stage',
        role: TankRole.stage,
        volumeL: 11.1,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    );
    await tester.pumpWidget(_buildPage(diverIdNotifier, prefs));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.playlist_add_check));
    await tester.pumpAndSettle();
    expect(find.text('Apply to existing dives?'), findsOneWidget);
    expect(find.textContaining('1 cylinders on 1 dives'), findsOneWidget);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(find.text('Updated 1 cylinders on 1 dives'), findsOneWidget);
    final db = DatabaseService.instance.database;
    final row = await (db.select(db.diveTanks)..where((t) => t.id.equals('k1')))
        .getSingle();
    expect(row.volume, 11.1);
    expect(row.tankRole, 'stage');
  });
}
```

Create `test/features/transmitters/presentation/pages/transmitter_edit_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/pages/transmitter_edit_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

Widget _buildPage(
  MockCurrentDiverIdNotifier diverIdNotifier,
  SharedPreferences prefs, {
  String? transmitterId,
  String? initialSerial,
  MockSettingsNotifier? settings,
}) {
  final router = GoRouter(
    initialLocation: '/edit',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const Scaffold(body: Text('LIST'))),
      GoRoute(
        path: '/edit',
        builder: (context, state) => TransmitterEditPage(
          transmitterId: transmitterId,
          initialSerial: initialSerial,
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      settingsProvider.overrideWith((ref) => settings ?? MockSettingsNotifier()),
      currentDiverIdProvider.overrideWith((ref) => diverIdNotifier),
      validatedCurrentDiverIdProvider.overrideWith((ref) async => 'diver-1'),
    ].cast(),
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      routerConfig: router,
    ),
  );
}

void main() {
  late MockCurrentDiverIdNotifier diverIdNotifier;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    await DatabaseService.instance.database.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('diver-1', 'A', 1, 1)",
    );
    diverIdNotifier = MockCurrentDiverIdNotifier();
    await diverIdNotifier.setCurrentDiver('diver-1');
  });
  tearDown(tearDownTestDatabase);

  testWidgets('prefills the serial and saves a new entry for the diver',
      (tester) async {
    await tester.pumpWidget(_buildPage(diverIdNotifier, prefs, initialSerial: '555'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, '555'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('transmitter_label')), 'Stage');
    await tester.enterText(find.byKey(const Key('transmitter_volume')), '11.1');
    await tester.enterText(find.byKey(const Key('transmitter_working_pressure')), '207');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await TransmitterRepository().getForDiver('diver-1');
    expect(saved.single.transmitterSerial, '555');
    expect(saved.single.label, 'Stage');
    expect(saved.single.volumeL, closeTo(11.1, 0.01));
    expect(saved.single.workingPressureBar, 207);
    expect(find.text('LIST'), findsOneWidget);
    // Saved from an Assign flow: the snackbar offers the retroactive apply.
    expect(find.text('Apply to existing dives'), findsOneWidget);
  });

  testWidgets('refuses an entry with neither serial nor channel', (tester) async {
    await tester.pumpWidget(_buildPage(diverIdNotifier, prefs));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('transmitter_label')), 'T1');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('Enter a transmitter serial, or pick a dive computer and channel'),
      findsOneWidget,
    );
    expect(await TransmitterRepository().getForDiver('diver-1'), isEmpty);
  });

  testWidgets('refuses a duplicate serial naming the existing entry',
      (tester) async {
    await TransmitterRepository().create(
      Transmitter(
        id: 'e1',
        diverId: 'diver-1',
        transmitterSerial: '555',
        label: 'Stage',
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    );
    await tester.pumpWidget(_buildPage(diverIdNotifier, prefs, initialSerial: '555'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('transmitter_label')), 'Other');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Already assigned to Stage'), findsOneWidget);
  });

  testWidgets('shows volume in cubic feet and stores liters', (tester) async {
    final settings = MockSettingsNotifier();
    await settings.setVolumeUnit(VolumeUnit.cubicFeet);
    await settings.setPressureUnit(PressureUnit.psi);
    await TransmitterRepository().create(
      Transmitter(
        id: 'e1',
        diverId: 'diver-1',
        transmitterSerial: '555',
        label: 'AL80',
        volumeL: 11.1,
        workingPressureBar: 207,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    );

    await tester.pumpWidget(
      _buildPage(diverIdNotifier, prefs, transmitterId: 'e1', settings: settings),
    );
    await tester.pumpAndSettle();

    // 11.1 L at 207 bar is 81.1 cuft; 207 bar is 3002 psi.
    expect(find.widgetWithText(TextFormField, '81.1'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '3002'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/transmitters/presentation`
Expected: FAIL to compile.

- [ ] **Step 3: List providers**

Append to `transmitter_providers.dart` (add `import 'package:submersion/core/providers/provider.dart';` for `invalidateSelfWhen`, and the entity import):

```dart
/// The active diver's registry entries, label order. Self-invalidates on
/// table changes so a sync write refreshes the page.
final transmittersProvider = FutureProvider<List<Transmitter>>((ref) async {
  final repository = ref.watch(transmitterRepositoryProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  ref.invalidateSelfWhen(repository.watchTransmittersChanges());
  return repository.getForDiver(diverId);
});

/// Serials seen on the diver's downloaded tanks that have no entry yet.
final unassignedTransmitterSerialsProvider =
    FutureProvider<List<UnassignedTransmitterSerial>>((ref) async {
      final repository = ref.watch(transmitterRepositoryProvider);
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      ref.invalidateSelfWhen(repository.watchUnassignedChanges());
      return repository.getUnassignedSerials(diverId);
    });

final transmitterProvider = FutureProvider.family<Transmitter?, String>((
  ref,
  id,
) async {
  final repository = ref.watch(transmitterRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchTransmittersChanges());
  return repository.getById(id);
});

/// Known versus unassigned serials seen on one computer's dives, for the
/// detail page row.
final transmitterComputerSummaryProvider =
    FutureProvider.family<({int known, int unassigned}), String>((
      ref,
      computerId,
    ) async {
      final repository = ref.watch(transmitterRepositoryProvider);
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      ref.invalidateSelfWhen(repository.watchUnassignedChanges());
      return repository.serialCountsForComputer(computerId, diverId: diverId);
    });
```

- [ ] **Step 4: The manage page**

Create `lib/features/transmitters/presentation/pages/transmitters_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_computer/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings > Manage > Transmitters. Follows the dive roles page: extended
/// FAB to add, inline edit and delete icons, no app-bar plus.
class TransmittersPage extends ConsumerWidget {
  const TransmittersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(transmittersProvider);
    final unassigned = ref.watch(unassignedTransmitterSerialsProvider);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.transmitters_title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          tooltip: l10n.common_action_back,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/transmitters/new'),
        tooltip: l10n.transmitters_add,
        icon: const Icon(Icons.add),
        label: Text(l10n.transmitters_add),
      ),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('${l10n.common_label_error}: $e')),
        data: (list) {
          final pending = unassigned.valueOrNull ?? const [];
          if (list.isEmpty && pending.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.transmitters_empty, textAlign: TextAlign.center),
              ),
            );
          }
          return ListView(
            children: [
              if (list.isNotEmpty) ...[
                _header(context, l10n.transmitters_header_assigned),
                ...list.map((t) => _EntryTile(entry: t, units: units)),
              ],
              if (pending.isNotEmpty) ...[
                if (list.isNotEmpty) const Divider(),
                _header(context, l10n.transmitters_header_unassigned),
                ...pending.map((u) => _UnassignedTile(item: u)),
              ],
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile({required this.entry, required this.units});

  final Transmitter entry;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final specs = <String>[
      entry.role.localizedName(l10n),
      if (entry.volumeL != null)
        units.formatTankVolume(entry.volumeL, entry.workingPressureBar, cuftDecimals: 1),
      if (entry.workingPressureBar != null)
        units.formatPressure(entry.workingPressureBar!),
      if (entry.material != null) entry.material!.localizedName(l10n),
    ];
    return ListTile(
      leading: Icon(MdiIcons.divingScubaTank, color: Theme.of(context).colorScheme.secondary),
      title: Text(entry.label),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.hasSerial)
            Text(l10n.transmitters_serial(entry.transmitterSerial!))
          else
            _ChannelLabel(entry: entry),
          Text(specs.join(' • ')),
        ],
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.playlist_add_check),
            tooltip: l10n.transmitters_action_apply,
            onPressed: () => _applyToExisting(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.transmitters_action_edit,
            onPressed: () => context.push('/transmitters/${entry.id}/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.transmitters_action_delete,
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _applyToExisting(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(transmitterRepositoryProvider);
    // Preview the counts with a dry run: the repository's matcher is the
    // same one the write uses, so the numbers cannot disagree.
    final preview = await repo.previewApplyToExistingDives(entry);
    if (!context.mounted) return;
    if (preview.tanksUpdated == 0) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.transmitters_apply_nothing)));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.transmitters_apply_title),
        content: Text(
          dialogContext.l10n.transmitters_apply_content(
            preview.tanksUpdated,
            preview.divesUpdated,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.common_action_apply),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final result = await repo.applyToExistingDives(entry);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.transmitters_apply_done(result.tanksUpdated, result.divesUpdated),
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${l10n.common_label_error}: $e')),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.transmitters_delete_title),
        content: Text(dialogContext.l10n.transmitters_delete_content(entry.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text(dialogContext.l10n.common_action_delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(transmitterRepositoryProvider).delete(entry.id);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${l10n.common_label_error}: $e')),
      );
    }
  }
}

/// "Perdix, channel 2" for a fallback-keyed entry.
class _ChannelLabel extends ConsumerWidget {
  const _ChannelLabel({required this.entry});
  final Transmitter entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final computer = ref
        .watch(diveComputerByIdProvider(entry.diveComputerId!))
        .valueOrNull;
    return Text(
      context.l10n.transmitters_channel(
        computer?.name ?? entry.diveComputerId!,
        entry.channelIndex! + 1,
      ),
    );
  }
}

class _UnassignedTile extends StatelessWidget {
  const _UnassignedTile({required this.item});
  final UnassignedTransmitterSerial item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      leading: const Icon(Icons.sensors),
      title: Text(l10n.transmitters_serial(item.serial)),
      subtitle: Text(l10n.transmitters_dives(item.diveCount)),
      trailing: FilledButton.tonal(
        onPressed: () => context.push(
          Uri(path: '/transmitters/new', queryParameters: {'serial': item.serial})
              .toString(),
        ),
        child: Text(l10n.transmitters_action_assign),
      ),
    );
  }
}
```

The page shows channel indices one-based ("channel 1" for index 0), matching how Shearwater labels T1 to T4. Use whatever provider `device_detail_page.dart` watches for one computer (`diveComputerByIdProvider` from the file it imports) and fix the import path accordingly.

Add to `TransmitterRepository` (Task 3 file) the dry-run used above:

```dart
  /// The counts [applyToExistingDives] would report, without writing.
  Future<ApplyToExistingResult> previewApplyToExistingDives(Transmitter t) async {
    final candidates = await _tanksForEntry(t);
    return (
      tanksUpdated: candidates.length,
      divesUpdated: candidates.map((r) => r.diveId).toSet().length,
    );
  }
```

- [ ] **Step 5: The editor**

Create `lib/features/transmitters/presentation/pages/transmitter_edit_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_computer/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Full-screen editor for one registry entry. Picking a gear cylinder or a
/// preset copies its specs into the fields (snapshot rule); the fields stay
/// editable afterward.
class TransmitterEditPage extends ConsumerStatefulWidget {
  final String? transmitterId;
  final String? initialSerial;

  const TransmitterEditPage({super.key, this.transmitterId, this.initialSerial});

  bool get isEditing => transmitterId != null;

  @override
  ConsumerState<TransmitterEditPage> createState() => _TransmitterEditPageState();
}

class _TransmitterEditPageState extends ConsumerState<TransmitterEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  final _labelController = TextEditingController();
  final _serialController = TextEditingController();
  final _channelController = TextEditingController();
  final _volumeController = TextEditingController();
  final _workingPressureController = TextEditingController();

  TankRole _role = TankRole.backGas;
  TankMaterial? _material;
  String? _computerId;
  String? _presetName;
  String? _equipmentId;
  String? _equipmentName;
  Transmitter? _existing;
  bool _loading = false;
  String? _keyError;
  String? _duplicateError;

  @override
  void initState() {
    super.initState();
    _serialController.text = widget.initialSerial ?? '';
    if (widget.isEditing) _load();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _serialController.dispose();
    _channelController.dispose();
    _volumeController.dispose();
    _workingPressureController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entry = await ref
        .read(transmitterRepositoryProvider)
        .getById(widget.transmitterId!);
    if (!mounted) return;
    final settings = ref.read(settingsProvider);
    final units = UnitFormatter(settings);
    setState(() {
      _existing = entry;
      _loading = false;
      if (entry == null) return;
      _labelController.text = entry.label;
      _serialController.text = entry.transmitterSerial ?? '';
      _computerId = entry.diveComputerId;
      _channelController.text = entry.channelIndex == null
          ? ''
          : '${entry.channelIndex! + 1}';
      _role = entry.role;
      _material = entry.material;
      _presetName = entry.presetName;
      _equipmentId = entry.equipmentId;
      _fillSpecFields(units, settings, entry.volumeL, entry.workingPressureBar);
    });
    if (entry?.equipmentId != null) {
      final gear = await ref.read(equipmentItemProvider(entry!.equipmentId!).future);
      if (mounted) setState(() => _equipmentName = gear?.name);
    }
  }

  /// Show liters or cubic feet (gas capacity at working pressure), and bar or
  /// psi, per the diver's units. The same conversion the tank editor uses.
  void _fillSpecFields(
    UnitFormatter units,
    AppSettings settings,
    double? volumeL,
    double? workingPressureBar,
  ) {
    if (volumeL != null) {
      final cuft = workingPressureBar != null
          ? volumeL * workingPressureBar / 28.3168
          : null;
      _volumeController.text = settings.volumeUnit == VolumeUnit.cubicFeet && cuft != null
          ? formatRoundedForInput(cuft, 1)
          : formatRoundedForInput(volumeL, 1);
    } else {
      _volumeController.text = '';
    }
    _workingPressureController.text = workingPressureBar != null
        ? formatRoundedForInput(units.convertPressure(workingPressureBar), 0)
        : '';
  }

  void _applyPreset(TankPresetEntity preset) {
    final settings = ref.read(settingsProvider);
    setState(() {
      _presetName = preset.name;
      _material = preset.material;
      _fillSpecFields(
        UnitFormatter(settings),
        settings,
        preset.volumeLiters,
        preset.workingPressureBar,
      );
    });
  }

  void _applyGear(EquipmentItem item) {
    final settings = ref.read(settingsProvider);
    setState(() {
      _equipmentId = item.id;
      _equipmentName = item.name;
      if (item.tankMaterial != null) _material = item.tankMaterial;
      if (item.volumeL != null || item.workingPressureBar != null) {
        _fillSpecFields(
          UnitFormatter(settings),
          settings,
          item.volumeL,
          item.workingPressureBar,
        );
      }
    });
  }

  Future<void> _pickGear() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => EquipmentPickerSheet(
          scrollController: scrollController,
          selectedEquipmentIds: {if (_equipmentId != null) _equipmentId!},
          typeFilter: EquipmentType.tank,
          onEquipmentSelected: (item) {
            _applyGear(item);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    setState(() {
      _keyError = null;
      _duplicateError = null;
    });
    final serialText = _serialController.text.trim();
    final channel = parseUserInt(_channelController.text);
    final hasChannel = _computerId != null && channel != null && channel >= 1;
    if (serialText.isEmpty && !hasChannel) {
      setState(() => _keyError = l10n.transmitters_validation_key);
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final settings = ref.read(settingsProvider);
    final units = UnitFormatter(settings);
    final pressureDisplay = parseUserDecimal(_workingPressureController.text);
    final workingPressureBar = pressureDisplay == null
        ? null
        : units.pressureToBar(pressureDisplay);
    final volumeDisplay = parseUserDecimal(_volumeController.text);
    double? volumeL;
    if (volumeDisplay != null) {
      volumeL = settings.volumeUnit == VolumeUnit.cubicFeet &&
              workingPressureBar != null &&
              workingPressureBar > 0
          ? (volumeDisplay * 28.3168) / workingPressureBar
          : volumeDisplay;
    }

    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    final now = DateTime.now();
    final entry = Transmitter(
      id: _existing?.id ?? _uuid.v4(),
      diverId: _existing?.diverId ?? diverId,
      transmitterSerial: serialText.isEmpty ? null : serialText,
      diveComputerId: hasChannel ? _computerId : null,
      channelIndex: hasChannel ? channel - 1 : null,
      label: _labelController.text.trim(),
      role: _role,
      volumeL: volumeL,
      workingPressureBar: workingPressureBar,
      material: _material,
      presetName: _presetName,
      equipmentId: _equipmentId,
      createdAt: _existing?.createdAt ?? now,
      updatedAt: now,
    );

    final repo = ref.read(transmitterRepositoryProvider);
    try {
      if (_existing != null) {
        await repo.update(entry);
      } else {
        await repo.create(entry);
      }
    } on TransmitterConflictException catch (e) {
      setState(
        () => _duplicateError = l10n.transmitters_validation_duplicate(e.existing.label),
      );
      return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.common_label_error}: $e')),
      );
      return;
    }
    if (!mounted) return;
    // A serial assigned straight after a download is the moment the diver
    // most wants the dives just imported fixed too, so offer the retroactive
    // apply once here (spec section 5). Edits never apply automatically.
    final offerApply = _existing == null && widget.initialSerial != null;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.transmitters_saved),
        action: !offerApply
            ? null
            : SnackBarAction(
                label: l10n.transmitters_action_apply,
                onPressed: () async {
                  final result = await repo.applyToExistingDives(entry);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.transmitters_apply_done(
                          result.tanksUpdated,
                          result.divesUpdated,
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  String? _positive(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final value = parseUserDecimal(text);
    if (value == null || value <= 0) return context.l10n.transmitters_validation_positive;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final presets = ref.watch(tankPresetsProvider);
    final computers = ref.watch(diveComputersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? l10n.transmitters_edit_title : l10n.transmitters_new_title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          tooltip: l10n.common_action_close,
        ),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: Text(l10n.common_action_save),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    key: const Key('transmitter_label'),
                    controller: _labelController,
                    decoration: InputDecoration(labelText: l10n.transmitters_field_label),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('transmitter_serial'),
                    controller: _serialController,
                    decoration: InputDecoration(
                      labelText: l10n.transmitters_field_serial,
                      errorText: _duplicateError ?? _keyError,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: computers.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (e, st) => Text('${l10n.common_label_error}: $e'),
                          data: (list) => DropdownButtonFormField<String?>(
                            key: const Key('transmitter_computer'),
                            initialValue: _computerId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: l10n.transmitters_field_computer,
                              isDense: true,
                            ),
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text(l10n.transmitters_gear_none),
                              ),
                              ...list.map(
                                (c) => DropdownMenuItem<String?>(
                                  value: c.id,
                                  child: Text(c.name),
                                ),
                              ),
                            ],
                            onChanged: (id) => setState(() => _computerId = id),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          key: const Key('transmitter_channel'),
                          controller: _channelController,
                          decoration: InputDecoration(
                            labelText: l10n.transmitters_field_channel,
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<TankRole>(
                    key: const Key('transmitter_role'),
                    initialValue: _role,
                    decoration: InputDecoration(labelText: l10n.transmitters_field_role),
                    items: [
                      for (final role in TankRole.values)
                        DropdownMenuItem(value: role, child: Text(role.localizedName(l10n))),
                    ],
                    onChanged: (role) => setState(() => _role = role ?? _role),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    key: const Key('transmitter_gear'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.transmitters_field_gear),
                    subtitle: Text(_equipmentName ?? l10n.transmitters_gear_none),
                    trailing: _equipmentId == null
                        ? const Icon(Icons.chevron_right)
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() {
                              _equipmentId = null;
                              _equipmentName = null;
                            }),
                          ),
                    onTap: _pickGear,
                  ),
                  const SizedBox(height: 8),
                  presets.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, st) => Text('${l10n.common_label_error}: $e'),
                    data: (list) {
                      final matching = _presetName == null
                          ? null
                          : list.where((p) => p.name == _presetName).firstOrNull;
                      return DropdownButtonFormField<TankPresetEntity?>(
                        key: ValueKey(matching?.id ?? 'no-preset'),
                        initialValue: matching,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: l10n.diveLog_tank_label_tankPreset,
                          isDense: true,
                        ),
                        items: [
                          DropdownMenuItem<TankPresetEntity?>(
                            value: null,
                            child: Text(l10n.diveLog_tank_selectPreset),
                          ),
                          ...list.map(
                            (p) => DropdownMenuItem<TankPresetEntity?>(
                              value: p,
                              child: Text(
                                p.isBuiltIn
                                    ? builtInTankPresetName(l10n, p.name) ?? p.displayName
                                    : p.displayName,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (p) {
                          if (p != null) {
                            _applyPreset(p);
                          } else {
                            setState(() => _presetName = null);
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: const Key('transmitter_volume'),
                          controller: _volumeController,
                          decoration: InputDecoration(
                            labelText: l10n.diveLog_tank_label_volume,
                            suffixText: settings.volumeUnit == VolumeUnit.cubicFeet
                                ? units.volumeSymbol
                                : 'L',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: _positive,
                          onChanged: (_) => setState(() => _presetName = null),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          key: const Key('transmitter_working_pressure'),
                          controller: _workingPressureController,
                          decoration: InputDecoration(
                            labelText: l10n.diveLog_tank_label_workingPressure,
                            suffixText: units.pressureSymbol,
                          ),
                          keyboardType: TextInputType.number,
                          validator: _positive,
                          onChanged: (_) => setState(() => _presetName = null),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<TankMaterial?>(
                    key: const Key('transmitter_material'),
                    initialValue: _material,
                    decoration: InputDecoration(labelText: l10n.transmitters_field_material),
                    items: [
                      DropdownMenuItem<TankMaterial?>(
                        value: null,
                        child: Text(l10n.transmitters_gear_none),
                      ),
                      for (final m in TankMaterial.values)
                        DropdownMenuItem<TankMaterial?>(
                          value: m,
                          child: Text(m.localizedName(l10n)),
                        ),
                    ],
                    onChanged: (m) => setState(() => _material = m),
                  ),
                ],
              ),
            ),
    );
  }
}
```

Find the provider that lists the diver's computers by reading `lib/features/dive_computer/presentation/pages/device_list_page.dart` (the `ref.watch(...)` that feeds its list) and use that name in place of `diveComputersProvider`, with the matching import. `builtInTankPresetName` lives where `tank_editor.dart` imports it from; copy that import. `AppSettings` is the type `settingsProvider` exposes; import it from wherever `tank_editor.dart` gets it.

- [ ] **Step 6: Routes and Settings tile**

In `app_router.dart`, after the `/tank-presets` GoRoute block, add:

```dart
          // Transmitter registry (issue #1365)
          GoRoute(
            path: '/transmitters',
            name: 'transmitters',
            builder: (context, state) => const TransmittersPage(),
            routes: [
              GoRoute(
                path: 'new',
                name: 'newTransmitter',
                builder: (context, state) => TransmitterEditPage(
                  initialSerial: state.uri.queryParameters['serial'],
                ),
              ),
              GoRoute(
                path: ':transmitterId/edit',
                name: 'editTransmitter',
                builder: (context, state) => TransmitterEditPage(
                  transmitterId: state.pathParameters['transmitterId'],
                ),
              ),
            ],
          ),
```

Add the two page imports beside the tank preset page imports (line ~133).

In `settings_page.dart`, after the Tank Presets `ListTile` and its `const Divider(height: 1),`, add:

```dart
                ListTile(
                  leading: const Icon(Icons.sensors),
                  title: Text(context.l10n.settings_manage_transmitters),
                  subtitle: Text(
                    context.l10n.settings_manage_transmitters_subtitle,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/transmitters'),
                ),
                const Divider(height: 1),
```

- [ ] **Step 7: Run the tests**

Run: `flutter test test/features/transmitters test/features/settings/presentation/pages`
Expected: PASS. If a settings page test enumerates the Manage tiles by count, update that count.

- [ ] **Step 8: Commit**

```bash
dart format lib/features/transmitters lib/core/router lib/features/settings test/features/transmitters
git add lib/features/transmitters lib/core/router/app_router.dart lib/features/settings/presentation/pages/settings_page.dart test/features/transmitters test/features/settings
git commit -m "feat(transmitters): manage page, editor and Settings entry for the transmitter registry"
```

---

### Task 12: Transmitters row on the dive computer detail page

**Files:**
- Modify: `lib/features/dive_computer/presentation/pages/device_detail_page.dart` (info card children at ~262, and a new widget beside `_LinkedGearRow` at ~860)
- Test: `test/features/dive_computer/presentation/pages/device_detail_page_transmitters_test.dart`

**Interfaces:**
- Consumes: `transmitterComputerSummaryProvider` (Task 11).

- [ ] **Step 1: Write the failing test**

Copy the scaffolding of `test/features/dive_computer/presentation/pages/device_detail_page_gear_twin_test.dart` (its `_buildTestWidget`, `_MockDiveComputerNotifier` and computer fixture) into the new file, add a `/transmitters` route returning `const Scaffold(body: Text('TRANSMITTERS_PAGE'))`, override `transmitterComputerSummaryProvider('comp-1')` and add:

```dart
  testWidgets('shows known and unassigned counts and opens the registry',
      (tester) async {
    await tester.pumpWidget(
      _buildTestWidget(
        computer: _computer,
        summary: (known: 3, unassigned: 1),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Transmitters'), findsOneWidget);
    expect(find.text('3 known, 1 unassigned'), findsOneWidget);

    await tester.tap(find.text('3 known, 1 unassigned'));
    await tester.pumpAndSettle();
    expect(find.text('TRANSMITTERS_PAGE'), findsOneWidget);
  });

  testWidgets('hides the row when the computer has seen no serials',
      (tester) async {
    await tester.pumpWidget(
      _buildTestWidget(
        computer: _computer,
        summary: (known: 0, unassigned: 0),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Transmitters'), findsNothing);
  });
```

where `_buildTestWidget` takes `required ({int known, int unassigned}) summary` and adds `transmitterComputerSummaryProvider('comp-1').overrideWith((ref) async => summary)` to the overrides.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_computer/presentation/pages/device_detail_page_transmitters_test.dart`
Expected: FAIL (`Transmitters` text not found).

- [ ] **Step 3: Implement**

In `device_detail_page.dart`, after `if (computer.equipmentId != null) _LinkedGearRow(equipmentId: computer.equipmentId!),` add `_TransmittersRow(computerId: computer.id),` and, after `_LinkedGearRow`, add:

```dart
/// Known versus unassigned transmitter serials seen on this computer's dives,
/// linking to the registry. Absent until the computer has reported a serial.
class _TransmittersRow extends ConsumerWidget {
  const _TransmittersRow({required this.computerId});

  final String computerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = ref.watch(transmitterComputerSummaryProvider(computerId)).valueOrNull;
    if (summary == null || summary.known + summary.unassigned == 0) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () => context.push('/transmitters'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.l10n.diveComputer_detail_transmitters,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.diveComputer_detail_transmittersSummary(
                    summary.known,
                    summary.unassigned,
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

Import `transmitter_providers.dart`.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/dive_computer/presentation/pages`
Expected: PASS (the gear-twin test keeps passing; the new provider defaults to loading and renders nothing there).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_computer/presentation/pages test/features/dive_computer/presentation/pages
git add lib/features/dive_computer/presentation/pages/device_detail_page.dart test/features/dive_computer/presentation/pages/device_detail_page_transmitters_test.dart
git commit -m "feat(dive-computer): transmitters summary row on the detail page"
```

---

### Task 13: Transmitter caption and Assign chip on the cylinders card

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/cylinders_card.dart` (`build` at 42, `_tankRow` subtitle at ~154)
- Test: `test/features/dive_log/presentation/widgets/cylinders_card_test.dart` (new group)

**Interfaces:**
- Consumes: `transmittersProvider` (Task 11), `normalizeTransmitterSerial`, `DiveTank.transmitterSerial`.

- [ ] **Step 1: Write the failing tests**

In `cylinders_card_test.dart`, extend `_buildCard` with `List<Transmitter> registry = const []` and add `transmittersProvider.overrideWith((ref) async => registry)` to its overrides. Also wrap the returned `testApp` in a `GoRouter`-free way: the Assign chip uses `context.push`, so switch `_buildCard` to a `MaterialApp.router` with two routes (`/` for the card and `/transmitters/new` returning `const Scaffold(body: Text('NEW_PAGE'))`) following the tank-presets page test pattern, keeping every existing test green. Then add:

```dart
  group('transmitter caption', () {
    Dive diveWithSerial(String? serial) => _dive.copyWith(
      tanks: [
        _dive.tanks.first.copyWith(transmitterSerial: serial),
      ],
    );

    testWidgets('shows the serial under a downloaded tank', (tester) async {
      await tester.pumpWidget(_buildCard(dive: diveWithSerial('180777')));
      await tester.pumpAndSettle();

      expect(find.text('Transmitter 180777'), findsOneWidget);
      expect(find.text('Assign transmitter'), findsOneWidget);
    });

    testWidgets('no chip once the serial has a registry entry', (tester) async {
      await tester.pumpWidget(
        _buildCard(
          dive: diveWithSerial('180777'),
          registry: [
            Transmitter(
              id: 'e1',
              transmitterSerial: '180777',
              label: 'O2',
              createdAt: DateTime.utc(2026, 9, 1),
              updatedAt: DateTime.utc(2026, 9, 1),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Transmitter 180777'), findsOneWidget);
      expect(find.text('Assign transmitter'), findsNothing);
    });

    testWidgets('no caption without a serial', (tester) async {
      await tester.pumpWidget(_buildCard(dive: diveWithSerial(null)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Transmitter '), findsNothing);
    });

    testWidgets('the chip opens the editor with the serial', (tester) async {
      await tester.pumpWidget(_buildCard(dive: diveWithSerial('180777')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Assign transmitter'));
      await tester.pumpAndSettle();

      expect(find.text('NEW_PAGE'), findsOneWidget);
    });
  });
```

`_dive` is whatever fixture the file already builds its dive from; name it accordingly.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_log/presentation/widgets/cylinders_card_test.dart`
Expected: the new tests FAIL (no caption).

- [ ] **Step 3: Implement**

In `cylinders_card.dart` `build`, read the registry beside the other providers:

```dart
    final knownSerials = {
      for (final t in ref.watch(transmittersProvider).valueOrNull ?? const <Transmitter>[])
        if (t.transmitterSerial != null) t.transmitterSerial!,
    };
```

Pass `knownSerials: knownSerials` into `_tankRow` (add `required Set<String> knownSerials` to its signature). In `_tankRow`, compute before the `return ListTile(`:

```dart
    final serial = normalizeTransmitterSerial(tank.transmitterSerial);
    final serialKnown = serial != null && knownSerials.contains(serial);
```

and in the subtitle `Column` children, after the MOD/MND `Text`, add:

```dart
          if (serial != null)
            Row(
              children: [
                Text(
                  context.l10n.transmitters_serial(serial),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (!serialKnown) ...[
                  const SizedBox(width: 8),
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(context.l10n.diveLog_tank_assignTransmitter),
                    onPressed: () => context.push(
                      Uri(
                        path: '/transmitters/new',
                        queryParameters: {'serial': serial},
                      ).toString(),
                    ),
                  ),
                ],
              ],
            ),
```

Set `isThreeLine: true` on the `ListTile` when `serial != null`. Import `go_router`, `transmitter_providers.dart`, `transmitter.dart` and `transmitter_serial.dart`.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/dive_log/presentation/widgets/cylinders_card_test.dart`
Expected: PASS, old and new.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_log/presentation/widgets test/features/dive_log/presentation/widgets
git add lib/features/dive_log/presentation/widgets/cylinders_card.dart test/features/dive_log/presentation/widgets/cylinders_card_test.dart
git commit -m "feat(dive-log): show the transmitter serial and an assign chip on the cylinders card"
```

---

### Task 14: Unassigned-transmitter notice in the import summary

**Files:**
- Modify: `lib/features/import_wizard/domain/models/import_notice.dart`
- Modify: `lib/features/import_wizard/data/adapters/import_notice_grouper.dart:44-47`
- Modify: `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart:639-646`
- Modify: `lib/features/import_wizard/presentation/widgets/import_summary_step.dart` (`_NoticeCard` at ~417)
- Test: `test/features/import_wizard/presentation/widgets/import_summary_step_test.dart` (notices group), `test/features/import_wizard/data/adapters/dive_computer_adapter_test.dart` if one exists, else a new focused test

**Interfaces:**
- Consumes: `ImportResult.unmatchedTransmitterSerials` and `DiveImportService.unmatchedTransmitterSerials` (Task 6).
- Produces: `ImportNoticeKind.unknownTransmitter`.

- [ ] **Step 1: Write the failing widget tests**

In the `ImportSummaryStep - notices` group add:

```dart
    testWidgets('explains unassigned transmitters with an action', (tester) async {
      await pumpWithNotices(tester, const [
        ImportNotice(kind: ImportNoticeKind.unknownTransmitter, affectedDives: 3),
      ], dives: 3);

      expect(find.text('Unassigned transmitters'), findsOneWidget);
      expect(find.textContaining('not assigned to a cylinder'), findsOneWidget);
      expect(find.text('Affects 3 dives'), findsOneWidget);
      expect(find.text('Assign transmitters'), findsOneWidget);
    });
```

Check how `_buildWidget` in that file hosts the step; if it is a plain `MaterialApp`, the action button's `context.push` needs a router. Wrap with a `GoRouter` whose `/transmitters` route renders `const Scaffold(body: Text('TRANSMITTERS_PAGE'))`, then extend the test with a tap on `Assign transmitters` and `expect(find.text('TRANSMITTERS_PAGE'), findsOneWidget)`.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/import_wizard/presentation/widgets/import_summary_step_test.dart`
Expected: FAIL to compile (`unknownTransmitter` unknown).

- [ ] **Step 3: Implement**

`import_notice.dart`, add to the enum:

```dart
  /// A downloaded tank carried a transmitter serial with no registry entry,
  /// so size and role came from the default preset rather than the diver's
  /// own cylinder (issue #1365).
  unknownTransmitter,
```

`import_notice_grouper.dart` `_kindFor` is exhaustive over `ImportWarningCode`; no change needed there, since this notice is produced by the dive computer adapter directly, not from a parser warning. Leave `_kindFor` alone.

`dive_computer_adapter.dart`, replace the final `return UnifiedImportResult(` with:

```dart
    final unmatched = _importService.unmatchedTransmitterSerials;
    return UnifiedImportResult(
      importedCounts: {ImportEntityType.dives: imported},
      consolidatedCount: consolidated,
      updatedCount: updated,
      skippedCount: skipped,
      importedDiveIds: importedDiveIds,
      notices: [
        if (unmatched.isNotEmpty && importedDiveIds.isNotEmpty)
          ImportNotice(
            kind: ImportNoticeKind.unknownTransmitter,
            affectedDives: _divesCarrying(unmatched, importedDiveIds.length),
          ),
      ],
    );
```

and add the helper to the adapter:

```dart
  /// How many of this run's downloaded dives carry an unmatched serial,
  /// clamped to the imported count like the grouper does.
  int _divesCarrying(List<String> unmatched, int importedDives) {
    final set = unmatched.toSet();
    var n = 0;
    for (final dive in _downloadedDives) {
      final hit = dive.tanks.any(
        (t) => set.contains(normalizeTransmitterSerial(t.transmitterSerial)),
      );
      if (hit) n++;
    }
    return n > importedDives ? importedDives : n;
  }
```

Import `import_notice.dart` and `transmitter_serial.dart`.

`import_summary_step.dart` `_NoticeCard`: extend the switch and add an optional action:

```dart
    final (title, body, action) = switch (notice.kind) {
      ImportNoticeKind.noTankPressure => (
        l10n.universalImport_summary_noticeNoTankPressureTitle,
        l10n.universalImport_summary_noticeNoTankPressureBody,
        null,
      ),
      ImportNoticeKind.unknownTransmitter => (
        l10n.universalImport_summary_noticeUnknownTransmitterTitle,
        l10n.universalImport_summary_noticeUnknownTransmitterBody,
        (
          label: l10n.universalImport_summary_noticeAssignTransmitters,
          route: '/transmitters',
        ),
      ),
    };
```

and, after the "Affects N dives" `Text` in the card's column, add:

```dart
                  if (action != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FilledButton.tonal(
                        onPressed: () => context.push(action.route),
                        child: Text(action.label),
                      ),
                    ),
                  ],
```

Import `go_router`.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/import_wizard`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/import_wizard test/features/import_wizard
git add lib/features/import_wizard/domain/models/import_notice.dart lib/features/import_wizard/data/adapters/dive_computer_adapter.dart lib/features/import_wizard/presentation/widgets/import_summary_step.dart test/features/import_wizard
git commit -m "feat(import): notice for unassigned transmitters after a download"
```

---

### Task 15: The unknown_transmitter data-quality finding

**Files:**
- Modify: `lib/features/data_quality/domain/entities/dive_quality_context.dart:47-74`
- Modify: `lib/features/data_quality/data/services/quality_context_builder.dart` (cache beside `_ppO2MaxByDiver`, construction at ~111)
- Create: `lib/features/data_quality/domain/detectors/unknown_transmitter_detector.dart`
- Modify: `lib/features/data_quality/domain/detectors/quality_detector_registry.dart:14-26`
- Modify: `lib/features/data_quality/domain/repairs/quality_repair_action.dart` (new class after `GoToDiveRepair`; new `case`)
- Modify: `lib/features/data_quality/presentation/widgets/quality_finding_card.dart:73-94`
- Modify: `lib/features/data_quality/presentation/widgets/quality_finding_message.dart` (`detectorTitle` and the detail switch)
- Modify: `lib/features/data_quality/presentation/pages/data_quality_inbox_page.dart:306-311`
- Modify: `lib/features/transmitters/data/repositories/transmitter_repository.dart` (targeted rescan on create and update)
- Modify: `test/features/data_quality/helpers/quality_test_helpers.dart` (`makeContext` gains `knownTransmitterSerials`)
- Test: `test/features/data_quality/domain/detectors/unknown_transmitter_detector_test.dart`, `test/features/data_quality/domain/repairs/quality_repair_action_test.dart` (or the file that already tests `repairOptionsFor`)

**Interfaces:**
- Produces: `DiveQualityContext.knownTransmitterSerials` (`Set<String>`, default empty); `UnknownTransmitterDetector` (`id 'unknown_transmitter'`, `version 1`, `QualityCategory.tank`); `AssignTransmitterRepair(String serial)`.

- [ ] **Step 1: Write the failing tests**

Add `Set<String> knownTransmitterSerials = const {}` to `makeContext` in `quality_test_helpers.dart` and pass it through. Create the detector test:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/domain/detectors/unknown_transmitter_detector.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/repairs/quality_repair_action.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart' as domain;

import '../../helpers/quality_test_helpers.dart';

domain.DiveTank _tank({String id = 't1', String? serial, int order = 0}) =>
    domain.DiveTank(
      id: id,
      gasMix: const domain.GasMix(o2: 21, he: 0),
      order: order,
      transmitterSerial: serial,
    );

void main() {
  const det = UnknownTransmitterDetector();

  test('flags a serial with no registry entry, once per serial', () {
    final ctx = makeContext(
      dive: makeTestDive(
        tanks: [
          _tank(id: 'a', serial: '180777'),
          _tank(id: 'b', serial: '0180777', order: 1),
          _tank(id: 'c', serial: '109623', order: 2),
        ],
      ),
      knownTransmitterSerials: {'109623'},
    );

    final out = det.detect(ctx);

    expect(out, hasLength(1));
    expect(out.single.severity, QualitySeverity.info);
    expect(out.single.category, QualityCategory.tank);
    expect(out.single.params['serial'], '180777');
    expect(out.single.params['tankId'], 'a');
  });

  test('is silent when every serial is known or absent', () {
    final ctx = makeContext(
      dive: makeTestDive(tanks: [_tank(serial: '109623'), _tank(id: 'm', order: 1)]),
      knownTransmitterSerials: {'109623'},
    );
    expect(det.detect(ctx), isEmpty);
  });

  test('the finding id is stable across rescans', () {
    final ctx = makeContext(
      dive: makeTestDive(tanks: [_tank(serial: '180777')]),
    );
    expect(det.detect(ctx).single.id, det.detect(ctx).single.id);
  });

  test('offers an assign repair carrying the serial', () {
    final ctx = makeContext(dive: makeTestDive(tanks: [_tank(serial: '180777')]));
    final repairs = repairOptionsFor(det.detect(ctx).single);

    expect(repairs.first, isA<AssignTransmitterRepair>());
    expect((repairs.first as AssignTransmitterRepair).serial, '180777');
    expect(repairs.last, isA<GoToDiveRepair>());
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/data_quality/domain/detectors/unknown_transmitter_detector_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Context field and builder cache**

In `DiveQualityContext` add the constructor param `this.knownTransmitterSerials = const {},` and the field:

```dart
  /// Normalized serials of the diver's registered transmitters (issue #1365),
  /// so a detector can tell a downloaded tank nobody has assigned yet.
  final Set<String> knownTransmitterSerials;
```

In `QualityContextBuilder` add a constructor param `TransmitterRepository? transmitterRepository` stored as `_transmitterRepo` (default `TransmitterRepository()`), a cache `final Map<String, Set<String>> _knownSerialsByDiver = {};` cleared in `buildAll` beside `_ppO2MaxByDiver.clear()`, and:

```dart
  /// The diver's registered serials, resolved once per batch. '' stands for
  /// the null diver, like the ppO2 cache.
  Future<Set<String>> _knownSerials(String? diverId) async {
    final key = diverId ?? '';
    final cached = _knownSerialsByDiver[key];
    if (cached != null) return cached;
    Set<String> value;
    try {
      final entries = await _transmitterRepo.getForDiver(diverId);
      value = {
        for (final t in entries)
          if (t.transmitterSerial != null) t.transmitterSerial!,
      };
    } catch (_) {
      value = const {};
    }
    _knownSerialsByDiver[key] = value;
    return value;
  }
```

and pass `knownTransmitterSerials: await _knownSerials(dive.diverId),` in the `DiveQualityContext(` construction.

- [ ] **Step 4: Detector**

```dart
import 'package:submersion/features/data_quality/domain/detectors/quality_detector.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';

/// A downloaded tank reports a transmitter serial the diver has not assigned
/// to a cylinder, so its size and role came from the default preset (issue
/// #1365). Informational: the repair is to register the transmitter.
class UnknownTransmitterDetector extends QualityDetector {
  const UnknownTransmitterDetector();

  @override
  String get id => 'unknown_transmitter';
  @override
  int get version => 1;
  @override
  QualityCategory get category => QualityCategory.tank;

  @override
  List<QualityFinding> detect(DiveQualityContext ctx) {
    final out = <QualityFinding>[];
    final seen = <String>{};
    final ordered = [...ctx.tanks]..sort((a, b) => a.order.compareTo(b.order));
    for (final tank in ordered) {
      final serial = normalizeTransmitterSerial(tank.transmitterSerial);
      if (serial == null || ctx.knownTransmitterSerials.contains(serial)) continue;
      if (!seen.add(serial)) continue;
      out.add(
        make(
          ctx,
          discriminator: serial,
          severity: QualitySeverity.info,
          params: {'serial': serial, 'tankId': tank.id},
        ),
      );
    }
    return out;
  }
}
```

Register it: add `UnknownTransmitterDetector(),` after `TankAssignmentDetector(),` in `kQualityDetectors`, with the import.

- [ ] **Step 5: Repair, labels, message, navigation**

`quality_repair_action.dart`, after `GoToDiveRepair`:

```dart
/// Navigate to the transmitter editor prefilled with [serial].
class AssignTransmitterRepair extends QualityRepairAction {
  const AssignTransmitterRepair(this.serial);
  final String serial;
}
```

and a new arm before `case 'tank_assignment':`:

```dart
    case 'unknown_transmitter':
      final serial = p['serial'] as String?;
      return [
        if (serial != null) AssignTransmitterRepair(serial),
        GoToDiveRepair(diveId),
      ];
```

`quality_finding_card.dart` label switch: `AssignTransmitterRepair() => l10n.dataQuality_repairLabel_assignTransmitter,`.

`quality_finding_message.dart`: in `detectorTitle` add `'unknown_transmitter' => l10n.dataQuality_detector_unknown_transmitter,`; in the detail switch add:

```dart
      case 'unknown_transmitter':
        detail = l10n.dataQuality_msg_unknownTransmitter(
          (p['serial'] as String?) ?? '',
        );
```

`data_quality_inbox_page.dart`, before the `GoToDiveRepair` case:

```dart
      case AssignTransmitterRepair(:final serial):
        if (context.mounted) {
          context.push(
            Uri(path: '/transmitters/new', queryParameters: {'serial': serial})
                .toString(),
          );
        }
```

Findings clear themselves: `QualityFindingsRepository.applyScanResults` deletes any finding the detector no longer produces, and the wizard already schedules a scan of imported dives. Saving an entry does not rescan by itself, so in `TransmitterRepository.create` (Task 3) add, after `notifyLocalChange()`, a targeted rescan of the dives carrying the new serial:

```dart
    final affected = (await _tanksForEntry(normalized)).map((r) => r.diveId).toSet();
    if (affected.isNotEmpty) scheduleQualityScan(affected);
```

importing `quality_scan_service.dart`. Do the same at the end of `update`.

- [ ] **Step 6: Run tests**

Run: `flutter test test/features/data_quality test/features/transmitters`
Expected: PASS. If a test enumerates `kQualityDetectors` by count or ids, add `unknown_transmitter` to it.

- [ ] **Step 7: Commit**

```bash
dart format lib/features/data_quality lib/features/transmitters test/features/data_quality
git add lib/features/data_quality lib/features/transmitters/data/repositories/transmitter_repository.dart test/features/data_quality
git commit -m "feat(data-quality): flag downloaded tanks whose transmitter is unassigned"
```

---

### Task 16: The pressure series reassignment sheet on the cylinders card

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/pickers/reassign_tank_picker.dart` (moved from the inbox page)
- Create: `lib/features/dive_log/presentation/widgets/tank_series_reassign_sheet.dart`
- Modify: `lib/features/data_quality/presentation/pages/data_quality_inbox_page.dart` (delete `showReassignTankPicker` at ~720, import the new file)
- Modify: `lib/features/dive_log/presentation/widgets/cylinders_card.dart` (action row at the bottom of the card)
- Test: `test/features/dive_log/presentation/widgets/tank_series_reassign_sheet_test.dart`, `cylinders_card_test.dart` (one test)

**Interfaces:**
- Consumes: `QualityRepairExecutor.exchangeTankSources` (Task 8), `tankPressuresProvider`, `showReassignTankPicker`, `RepairResult`.
- Produces: `Future<void> showTankSeriesReassignSheet(BuildContext context, WidgetRef ref, {required Dive dive, required Map<String, List<TankPressurePoint>> tankPressures})`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/dive_log/presentation/widgets/tank_series_reassign_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart' as domain;
import 'package:submersion/features/dive_log/presentation/widgets/tank_series_reassign_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository diveRepo;
  late TankPressureRepository tankRepo;

  setUp(() async {
    await setUpTestDatabase();
    diveRepo = DiveRepository();
    tankRepo = TankPressureRepository();
    await diveRepo.createDive(
      domain.Dive(
        id: 'd1',
        dateTime: DateTime.utc(2026, 7, 1, 10),
        tanks: const [
          domain.DiveTank(
            id: 'tA',
            name: 'O2',
            gasMix: domain.GasMix(o2: 100, he: 0),
            order: 0,
            startPressure: 200,
            endPressure: 170,
            transmitterSerial: '111',
            sourceTankIndex: 0,
          ),
          domain.DiveTank(
            id: 'tB',
            name: 'Dil',
            gasMix: domain.GasMix(o2: 21, he: 0),
            order: 1,
            startPressure: 210,
            endPressure: 120,
            transmitterSerial: '222',
            sourceTankIndex: 1,
          ),
        ],
      ),
    );
    await tankRepo.insertTankPressures('d1', {
      'tA': [(timestamp: 0, pressure: 200.0), (timestamp: 600, pressure: 170.0)],
      'tB': [(timestamp: 0, pressure: 210.0)],
    });
  });
  tearDown(tearDownTestDatabase);

  Widget host() => testAppInShell(
    overrides: [settingsProvider.overrideWith((ref) => MockSettingsNotifier())],
    child: Consumer(
      builder: (context, ref, _) => ElevatedButton(
        onPressed: () async {
          final dive = await diveRepo.getDiveById('d1');
          final pressures = await tankRepo.getTankPressuresForDive('d1');
          if (!context.mounted) return;
          await showTankSeriesReassignSheet(
            context,
            ref,
            dive: dive!,
            tankPressures: pressures,
          );
        },
        child: const Text('OPEN'),
      ),
    ),
  );

  testWidgets('lists each series against its tank and swaps two tanks',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    expect(find.text('Pressure series'), findsOneWidget);
    expect(find.text('O2'), findsOneWidget);
    expect(find.text('Dil'), findsOneWidget);
    expect(find.textContaining('200 bar'), findsOneWidget);
    expect(find.text('2 readings'), findsOneWidget);
    expect(find.text('Transmitter 111'), findsOneWidget);

    await tester.tap(find.text('Swap'));
    await tester.pumpAndSettle();

    expect(find.text('Pressure series reassigned'), findsOneWidget);
    final db = DatabaseService.instance.database;
    final a = await (db.select(db.diveTanks)..where((t) => t.id.equals('tA')))
        .getSingle();
    expect(a.transmitterSerial, '222');
    expect(a.sourceTankIndex, 1);
  });

  testWidgets('undo from the snackbar restores the original', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Swap'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    final db = DatabaseService.instance.database;
    final a = await (db.select(db.diveTanks)..where((t) => t.id.equals('tA')))
        .getSingle();
    expect(a.transmitterSerial, '111');
  });
}
```

If the undo label in `dataQuality_action_undo` is not "Undo", use its English value.

In `cylinders_card_test.dart` add one test to the existing set: with `tankPressures` containing two tank ids from one computer, `expect(find.text('Reassign pressure series'), findsOneWidget)`; with one, `findsNothing`.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_log/presentation/widgets/tank_series_reassign_sheet_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Extract the picker**

Move `showReassignTankPicker` verbatim from `data_quality_inbox_page.dart` into `lib/features/dive_log/presentation/widgets/pickers/reassign_tank_picker.dart` with the imports it needs (`flutter/material.dart`, `flutter_riverpod`, `dive_providers.dart` for `diveProvider`, `l10n_extension.dart`), and import that file from the inbox page.

- [ ] **Step 4: The sheet**

Create `lib/features/dive_log/presentation/widgets/tank_series_reassign_sheet.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/data_quality/data/services/quality_repair_executor.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/tank_pressure_series.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/reassign_tank_picker.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Lets the diver move a transmitter's pressure series to another cylinder
/// (issue #1314). Two tanks get a Swap; more get a per-row Move to. The
/// change is an exchange of the rows' computer bundles, so it survives
/// re-parse and is undone by the snackbar action.
Future<void> showTankSeriesReassignSheet(
  BuildContext context,
  WidgetRef ref, {
  required Dive dive,
  required Map<String, List<TankPressurePoint>> tankPressures,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _ReassignSheet(
      dive: dive,
      tankPressures: tankPressures,
      onExchange: (a, b) => _exchange(context, ref, dive.id, a, b),
    ),
  );
}

Future<void> _exchange(
  BuildContext context,
  WidgetRef ref,
  String diveId,
  String tankIdA,
  String tankIdB,
) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final result = await QualityRepairExecutor().exchangeTankSources(
      diveId: diveId,
      tankIdA: tankIdA,
      tankIdB: tankIdB,
    );
    final undo = result.undo;
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.diveLog_reassignSheet_applied),
        action: undo == null
            ? null
            : SnackBarAction(
                label: l10n.dataQuality_action_undo,
                onPressed: () => unawaited(undo()),
              ),
      ),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('${l10n.common_label_error}: $e')),
    );
  }
}

class _ReassignSheet extends ConsumerWidget {
  const _ReassignSheet({
    required this.dive,
    required this.tankPressures,
    required this.onExchange,
  });

  final Dive dive;
  final Map<String, List<TankPressurePoint>> tankPressures;
  final Future<void> Function(String tankIdA, String tankIdB) onExchange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final tanks = [...dive.tanks]..sort((a, b) => a.order.compareTo(b.order));
    final withSeries = tanks
        .where((t) => (tankPressures[t.id] ?? const []).isNotEmpty)
        .toList();
    final twoOnly = withSeries.length == 2 && tanks.length == 2;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.diveLog_reassignSheet_title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final (index, tank) in tanks.indexed)
              _row(context, ref, l10n, theme, units, index, tank, twoOnly),
            if (twoOnly) ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton.icon(
                  icon: const Icon(Icons.swap_vert),
                  label: Text(l10n.diveLog_reassignSheet_swap),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await onExchange(withSeries[0].id, withSeries[1].id);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    ThemeData theme,
    UnitFormatter units,
    int index,
    DiveTank tank,
    bool twoOnly,
  ) {
    final points = tankPressures[tank.id] ?? const <TankPressurePoint>[];
    final serial = normalizeTransmitterSerial(tank.transmitterSerial);
    final title = tank.name != null && tank.name!.isNotEmpty
        ? tank.name!
        : l10n.diveLog_tank_title(index + 1);
    final subtitle = points.isEmpty
        ? l10n.diveLog_reassignSheet_noSeries
        : '${units.formatPressure(points.first.pressure)} → '
            '${units.formatPressure(points.last.pressure)}, '
            '${l10n.diveLog_reassignSheet_readings(points.length)}'
            '${serial != null ? ', ${l10n.transmitters_serial(serial)}' : ''}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.show_chart),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: twoOnly || points.isEmpty
          ? null
          : TextButton(
              child: Text(l10n.diveLog_reassignSheet_moveTo),
              onPressed: () async {
                final target = await showReassignTankPicker(
                  context,
                  ref,
                  diveId: dive.id,
                  excludeTankId: tank.id,
                );
                if (target == null || !context.mounted) return;
                Navigator.of(context).pop();
                await onExchange(tank.id, target);
              },
            ),
    );
  }
}
```

Import `app_localizations.dart` for the `AppLocalizations` parameter type. The subtitle's arrow is the same character the cylinders card already uses for its pressure range; if the analyzer or the repo's lint rejects it, use the word "to".

- [ ] **Step 5: Card entry point**

In `cylinders_card.dart` `build`, after the tank rows inside the `Column`, add:

```dart
            if (_canReassign(dive, tankPressures))
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  icon: const Icon(Icons.swap_vert),
                  label: Text(context.l10n.diveLog_tank_reassignSeries),
                  onPressed: () => showTankSeriesReassignSheet(
                    context,
                    ref,
                    dive: dive,
                    tankPressures: tankPressures ?? const {},
                  ),
                ),
              ),
```

and the helper:

```dart
  /// Two or more of this dive's tanks carry a series from one computer.
  static bool _canReassign(
    Dive dive,
    Map<String, List<TankPressurePoint>>? tankPressures,
  ) {
    if (tankPressures == null) return false;
    final byComputer = <String?, int>{};
    for (final tank in dive.tanks) {
      if ((tankPressures[tank.id] ?? const []).isEmpty) continue;
      byComputer[tank.computerId] = (byComputer[tank.computerId] ?? 0) + 1;
    }
    return byComputer.values.any((n) => n >= 2);
  }
```

- [ ] **Step 6: Run tests**

Run: `flutter test test/features/dive_log/presentation/widgets test/features/data_quality/presentation`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format lib/features/dive_log/presentation lib/features/data_quality/presentation test/features/dive_log/presentation
git add lib/features/dive_log/presentation/widgets/pickers/reassign_tank_picker.dart lib/features/dive_log/presentation/widgets/tank_series_reassign_sheet.dart lib/features/data_quality/presentation/pages/data_quality_inbox_page.dart lib/features/dive_log/presentation/widgets/cylinders_card.dart test/features/dive_log/presentation/widgets/tank_series_reassign_sheet_test.dart test/features/dive_log/presentation/widgets/cylinders_card_test.dart
git commit -m "feat(dive-log): reassign pressure series from the cylinders card (#1314)"
```

---

### Task 17: Whole-project verification

**Files:** none new.

- [ ] **Step 1: Format and analyze**

```bash
dart format .
```

then run `flutter analyze` on its own and read the exit status directly. Expected: `No issues found!` and exit 0. Infos count as failures in CI; fix every one.

- [ ] **Step 2: Localization gate**

```bash
flutter gen-l10n && git status --short lib/l10n
```

Expected: no output from `git status` (generated files are committed and current).

- [ ] **Step 3: Full test suite, once**

```bash
flutter test
```

Expected: all tests pass. Do not pipe the output. If a pre-existing test fails on a count of Manage tiles, quality detectors or sync entities, update the count in that test and note it in the commit.

- [ ] **Step 4: Ladder re-check before pushing**

```bash
git fetch origin && git merge-base --is-ancestor origin/main HEAD && echo up-to-date
```

If not up to date, merge `origin/main`, re-run the scan from Task 0 step 4, renumber the rung if 200 was taken (scalar, `migrationVersions`, both rungs, both backstops, the v200 test file name and its assertions), regenerate, and re-run the full suite.

- [ ] **Step 5: Commit any fixups**

```bash
git add -u
git commit -m "chore: format and test fixups for the transmitter registry"
```

Only if step 1 or 3 changed files. Then the branch is ready for a pull request titled `feat: transmitter registry and re-parse-proof series reassignment (#1365, #1314)` whose body summarizes the spec's six sections; no attribution lines of any kind.
