# Equipment Assemblies PR 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish issue #1487: when an assembly's template changes, offer to replay the change on the past dives that carry it; add a replace action for a part; carry assemblies and gear provenance through the full UDDF logbook round trip; and list components in the CSV and Excel equipment exports.

**Architecture:** A pure `GearHistoryRewrite` rule (add, remove, replace a part) turns one dive's provenance rows into the rows after the change, so the repository's `rewriteAssemblyOnPastDives` is a loop over the dives that carry the assembly, each written through the diff writer PR 2 added. One dialog asks "from now on" or "also update N past dives" at the three moments the template changes. UDDF gains two private-block sections, `<components>` and `<gearlinks>` keyed by dive reference, mirrored by two parsers and two import phases that resolve references through the existing id maps. CSV and Excel gain one column fed by the components index.

**Tech Stack:** Flutter, Dart 3 sealed classes and patterns, Drift (SQLite), Riverpod 3, Equatable, `xml` package builders and parsers, `flutter gen-l10n` ARB localisation, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-09-equipment-assemblies-design.md`, section 2 "Swap with history", section 6 "UDDF" and "CSV and Excel", Testing and Delivery item 3. PR 1 (#1696) delivered the template and PR 2 (#1716) the dive side; both are on main at 0ccd4859605.

## Global Constraints

- No schema change. Everything here writes tables and columns that exist since v203.
- No em-dashes anywhere. No mention of the AI tool or its vendor in any file or commit message. No emojis.
- Every new user-visible string gets a key in all **11** ARB files under `lib/l10n/arb/` (`ar`, `de`, `en`, `es`, `fr`, `he`, `hu`, `it`, `nl`, `pt`, `zh`), inserted with the scratchpad helper or by hand inside the `equipment_components_` block, followed by `flutter gen-l10n`, with the regenerated `app_localizations*.dart` committed. Placeholders without `@` metadata generate `Object` parameters in alphabetical order; a plural generates a `num`.
- Sync bookkeeping follows the repository it lives in: the dive repository marks pending and logs deletions inline through `_writeGearDiff`; the component repository marks the row pending after each write and calls `SyncEventBus.notifyLocalChange()`.
- UDDF references keep the existing prefixes: `equip_<id>`, `set_<id>`, `dive_<id>`. Rows with no provenance are not written to `<gearlinks>`; the standard `<equipmentused>` list already carries them.
- Scope is the full logbook round trip (`UddfFullExportService`, `UddfFullImportService`, `UddfEntityImporter`) and the import wizard, which routes UDDF through the same services. The dives-only exporter writes no gear at all today, so it carries no assemblies either; that is issue #1718, named in the PR body as a known limit.
- Run `dart format .` before every commit; stage explicit paths; run specific test files, not whole directories, except in the final task. `*.mocks.dart` are gitignored generated files: after any change to a repository's public signature, rerun codegen or the analyzer reports an invalid override.
- TDD: every task writes the failing test first and shows it fail.

## Decisions this plan makes

- `<gearlinks>` is one top-level section in the private block keyed by dive reference, the shape `<datasources>` already uses, rather than a per-dive inline `<applicationdata>`: the full export's dive builder writes no inline block today and the importer already records each dive's `sourceUuid`.
- Replace is a new row action on the Components card that opens the picker in single-select mode and keeps the row's role and order.
- The dialog appears once per batch: adding three parts from the picker asks once and applies the answer to all three.
- `ImportRepositories` gains an optional `equipmentComponentRepository`; the importer constructs the default when it is absent so existing callers keep compiling.

## File map

| Path | Responsibility |
| --- | --- |
| `lib/features/equipment/domain/entities/gear_history_rewrite.dart` | `GearHistoryRewrite` sealed class with `GearPartAdded`, `GearPartRemoved`, `GearPartReplaced` and the pure `applyTo` |
| `lib/features/dive_log/data/repositories/dive_repository_impl.dart` | `diveIdsWithEquipment`, `rewriteAssemblyOnPastDives` |
| `lib/features/equipment/data/repositories/equipment_component_repository.dart` | `replaceComponent` |
| `lib/features/equipment/presentation/widgets/assembly_history_dialog.dart` | `showAssemblyHistoryDialog`, `AssemblyHistoryChange`, `AssemblyHistoryChoice` |
| `lib/features/equipment/presentation/widgets/component_picker_sheet.dart` | dialog before add; single-select replace mode |
| `lib/features/equipment/presentation/widgets/components_card.dart` | dialog before remove; replace action |
| `lib/core/services/export/uddf/uddf_export_builders.dart` | `<components>` and `<gearlinks>` writers |
| `lib/core/services/export/uddf/uddf_full_export_service.dart`, `lib/core/services/export/export_service.dart`, `lib/features/settings/presentation/providers/export_providers.dart` | thread `components` into the full export |
| `lib/core/services/export/uddf/uddf_import_parsers.dart`, `uddf_full_import_service.dart`, `lib/core/services/export/models/uddf_import_result.dart` | parse both sections |
| `lib/features/dive_import/data/services/uddf_entity_importer.dart` | `_importComponents`, set id mapping, dive gear provenance |
| `lib/features/equipment/domain/services/components_index.dart` | `namesByParent` |
| `lib/core/services/export/csv/csv_export_service.dart`, `lib/core/services/export/excel/excel_export_service.dart` | `Components` column |

---

### Task 1: The pure rewrite rule

**Files:**
- Create: `lib/features/equipment/domain/entities/gear_history_rewrite.dart`
- Test: `test/features/equipment/domain/entities/gear_history_rewrite_test.dart`

**Interfaces:**
- Consumes: `GearProvenance`, `GearExpander.subtreeIds`.
- Produces:
  - `sealed class GearHistoryRewrite { List<GearProvenance> applyTo(List<GearProvenance> rows, String assemblyId); }`
  - `class GearPartAdded extends GearHistoryRewrite { final String partId; }`
  - `class GearPartRemoved extends GearHistoryRewrite { final String partId; }`
  - `class GearPartReplaced extends GearHistoryRewrite { final String oldPartId; final String newPartId; }`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/equipment/domain/entities/gear_history_rewrite_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/gear_history_rewrite.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';

void main() {
  const onDive = [
    GearProvenance(equipmentId: 'reg', viaSetId: 'winter'),
    GearProvenance(equipmentId: 'hose', viaEquipmentId: 'reg', viaSetId: 'winter'),
    GearProvenance(equipmentId: 'mask'),
  ];
  List<String> ids(List<GearProvenance> rows) =>
      rows.map((r) => r.equipmentId).toList();
  GearProvenance row(List<GearProvenance> rows, String id) =>
      rows.firstWhere((r) => r.equipmentId == id);

  group('GearPartAdded', () {
    test('appends the part under the assembly with the assembly set', () {
      final next = const GearPartAdded('first').applyTo(onDive, 'reg');
      expect(ids(next), ['reg', 'hose', 'mask', 'first']);
      expect(row(next, 'first').viaEquipmentId, 'reg');
      expect(row(next, 'first').viaSetId, 'winter');
    });

    test('a loose row already on the dive adopts the assembly', () {
      final next = const GearPartAdded('mask').applyTo(onDive, 'reg');
      expect(ids(next), ['reg', 'hose', 'mask']);
      expect(row(next, 'mask').viaEquipmentId, 'reg');
      expect(row(next, 'mask').viaSetId, 'winter');
    });

    test('a row under another parent is left alone', () {
      const rows = [
        GearProvenance(equipmentId: 'reg'),
        GearProvenance(equipmentId: 'hose', viaEquipmentId: 'other'),
      ];
      expect(const GearPartAdded('hose').applyTo(rows, 'reg'), rows);
    });

    test('a dive without the assembly is unchanged', () {
      expect(const GearPartAdded('first').applyTo(onDive, 'kit'), onDive);
    });
  });

  group('GearPartRemoved', () {
    test('drops the row under the assembly and its subtree', () {
      const rows = [
        GearProvenance(equipmentId: 'reg'),
        GearProvenance(equipmentId: 'hose', viaEquipmentId: 'reg'),
        GearProvenance(equipmentId: 'clip', viaEquipmentId: 'hose'),
        GearProvenance(equipmentId: 'mask'),
      ];
      expect(ids(const GearPartRemoved('hose').applyTo(rows, 'reg')), ['reg', 'mask']);
    });

    test('a same item under another parent is left alone', () {
      const rows = [
        GearProvenance(equipmentId: 'reg'),
        GearProvenance(equipmentId: 'hose', viaEquipmentId: 'other'),
      ];
      expect(const GearPartRemoved('hose').applyTo(rows, 'reg'), rows);
    });
  });

  group('GearPartReplaced', () {
    test('re-keys the row in place, keeping provenance and children', () {
      const rows = [
        GearProvenance(equipmentId: 'reg', viaSetId: 'winter'),
        GearProvenance(equipmentId: 'hose', viaEquipmentId: 'reg', viaSetId: 'winter'),
        GearProvenance(equipmentId: 'clip', viaEquipmentId: 'hose'),
      ];
      final next = const GearPartReplaced(oldPartId: 'hose', newPartId: 'newhose')
          .applyTo(rows, 'reg');
      expect(ids(next), ['reg', 'newhose', 'clip']);
      expect(row(next, 'newhose').viaEquipmentId, 'reg');
      expect(row(next, 'newhose').viaSetId, 'winter');
      expect(row(next, 'clip').viaEquipmentId, 'newhose');
    });

    test('a new part already on the dive adopts the assembly and the old row goes', () {
      const rows = [
        GearProvenance(equipmentId: 'reg', viaSetId: 'winter'),
        GearProvenance(equipmentId: 'hose', viaEquipmentId: 'reg', viaSetId: 'winter'),
        GearProvenance(equipmentId: 'newhose'),
      ];
      final next = const GearPartReplaced(oldPartId: 'hose', newPartId: 'newhose')
          .applyTo(rows, 'reg');
      expect(ids(next), ['reg', 'newhose']);
      expect(row(next, 'newhose').viaEquipmentId, 'reg');
      expect(row(next, 'newhose').viaSetId, 'winter');
    });

    test('without the old row under the assembly nothing changes', () {
      expect(
        const GearPartReplaced(oldPartId: 'first', newPartId: 'x').applyTo(onDive, 'reg'),
        onDive,
      );
    });
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/equipment/domain/entities/gear_history_rewrite_test.dart`
Expected: compile error, `gear_history_rewrite.dart` not found.

- [ ] **Step 3: Write the rule**

```dart
// lib/features/equipment/domain/entities/gear_history_rewrite.dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/services/gear_expander.dart';

/// One change to an assembly's template, replayed on a past dive's rows
/// (issue #1487, "also update N past dives"). Pure: [applyTo] takes the
/// dive's provenance rows and returns the rows after the change, so the
/// repository is a loop and the rules live in one tested place.
///
/// Every variant leaves a dive that does not carry the assembly unchanged,
/// and never touches a row that hangs under some other parent.
sealed class GearHistoryRewrite extends Equatable {
  const GearHistoryRewrite();

  List<GearProvenance> applyTo(List<GearProvenance> rows, String assemblyId);

  static GearProvenance? _assemblyRow(List<GearProvenance> rows, String id) {
    for (final r in rows) {
      if (r.equipmentId == id) return r;
    }
    return null;
  }
}

/// A part was added to the template.
class GearPartAdded extends GearHistoryRewrite {
  final String partId;
  const GearPartAdded(this.partId);

  @override
  List<GearProvenance> applyTo(List<GearProvenance> rows, String assemblyId) {
    final assembly = GearHistoryRewrite._assemblyRow(rows, assemblyId);
    if (assembly == null) return rows;
    final current = GearHistoryRewrite._assemblyRow(rows, partId);
    if (current == null) {
      return [
        ...rows,
        GearProvenance(
          equipmentId: partId,
          viaEquipmentId: assemblyId,
          viaSetId: assembly.viaSetId,
        ),
      ];
    }
    if (!current.isTopLevel) return rows;
    return [
      for (final r in rows)
        if (r.equipmentId == partId)
          r.copyWith(
            viaEquipmentId: assemblyId,
            viaSetId: r.viaSetId ?? assembly.viaSetId,
          )
        else
          r,
    ];
  }

  @override
  List<Object?> get props => [partId];
}

/// A part was removed from the template.
class GearPartRemoved extends GearHistoryRewrite {
  final String partId;
  const GearPartRemoved(this.partId);

  @override
  List<GearProvenance> applyTo(List<GearProvenance> rows, String assemblyId) {
    final under = rows.any(
      (r) => r.equipmentId == partId && r.viaEquipmentId == assemblyId,
    );
    if (!under) return rows;
    return GearExpander.removeSubtree(rows, partId);
  }

  @override
  List<Object?> get props => [partId];
}

/// One part was swapped for another on the template.
class GearPartReplaced extends GearHistoryRewrite {
  final String oldPartId;
  final String newPartId;
  const GearPartReplaced({required this.oldPartId, required this.newPartId});

  @override
  List<GearProvenance> applyTo(List<GearProvenance> rows, String assemblyId) {
    GearProvenance? old;
    for (final r in rows) {
      if (r.equipmentId == oldPartId && r.viaEquipmentId == assemblyId) old = r;
    }
    if (old == null) return rows;
    final existing = GearHistoryRewrite._assemblyRow(rows, newPartId);
    if (existing != null) {
      // The new part is already on the dive: it adopts the assembly and
      // the old row (with its subtree) goes, so the composite key holds.
      final adopted = [
        for (final r in rows)
          if (r.equipmentId == newPartId)
            r.copyWith(
              viaEquipmentId: assemblyId,
              viaSetId: old.viaSetId ?? r.viaSetId,
            )
          else
            r,
      ];
      return GearExpander.removeSubtree(adopted, oldPartId);
    }
    // Re-key in place: the row keeps its provenance and its children move
    // with it.
    return [
      for (final r in rows)
        if (r.equipmentId == oldPartId)
          GearProvenance(
            equipmentId: newPartId,
            viaEquipmentId: assemblyId,
            viaSetId: r.viaSetId,
          )
        else if (r.viaEquipmentId == oldPartId)
          r.copyWith(viaEquipmentId: newPartId)
        else
          r,
    ];
  }

  @override
  List<Object?> get props => [oldPartId, newPartId];
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/equipment/domain/entities/gear_history_rewrite_test.dart`
Expected: PASS, 9 tests.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/equipment/domain/entities/gear_history_rewrite.dart test/features/equipment/domain/entities/gear_history_rewrite_test.dart
git add lib/features/equipment/domain/entities/gear_history_rewrite.dart test/features/equipment/domain/entities/gear_history_rewrite_test.dart
git commit -m "feat(equipment): pure rewrite rule for an assembly change on past dives (#1487)

Add, remove and replace as one sealed rule over a dive's provenance
rows: a loose row adopts the assembly, a removed part takes its subtree,
a replacement re-keys in place or adopts an existing row."
```

---

### Task 2: Replay on past dives, and replace on the template

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (beside `replaceGearRows`)
- Modify: `lib/features/equipment/data/repositories/equipment_component_repository.dart` (beside `updateRole`)
- Test: `test/features/dive_log/data/repositories/dive_repository_assembly_history_test.dart`
- Test: `test/features/equipment/data/repositories/equipment_component_repository_test.dart` (existing file; add a group)

**Interfaces:**
- Consumes: `GearHistoryRewrite.applyTo`, `_provenanceOf`, `_writeGearDiff`, `_bumpDives`, `EquipmentComponentCycleException`, `wouldCreateCycle`.
- Produces:
  - `Future<List<String>> diveIdsWithEquipment(String equipmentId)` on `DiveRepository`
  - `Future<int> rewriteAssemblyOnPastDives(String assemblyId, GearHistoryRewrite rewrite)` returning the number of dives touched
  - `Future<EquipmentComponent> replaceComponent(String id, String newComponentId)` on `EquipmentComponentRepository`, keeping role and sort order, cycle-guarded, marking the row pending

- [ ] **Step 1: Write the failing repository tests**

```dart
// test/features/dive_log/data/repositories/dive_repository_assembly_history_test.dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart' as domain;
import 'package:submersion/features/equipment/domain/entities/gear_history_rewrite.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';

import '../../../../helpers/test_database.dart';

/// "Also update N past dives" (issue #1487): every dive carrying the
/// assembly is rewritten through the diff writer and re-stamped.
void main() {
  late AppDatabase db;
  late DiveRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DiveRepository();
    await db.into(db.divers).insert(
      DiversCompanion.insert(id: 'd1', name: 'd1', createdAt: 1, updatedAt: 1),
    );
    for (final id in ['reg', 'hose', 'first', 'newhose', 'mask']) {
      await db.into(db.equipment).insert(
        EquipmentCompanion.insert(
          id: id, name: id, type: 'regulator', createdAt: 1, updatedAt: 1,
          diverId: const Value('d1'),
        ),
      );
    }
    await db.into(db.equipmentSets).insert(
      EquipmentSetsCompanion.insert(id: 'winter', name: 'Winter', createdAt: 1, updatedAt: 1),
    );
    // Two dives with the assembly, one without.
    for (final id in ['a', 'b', 'c']) {
      await repo.createDive(domain.Dive(id: id, dateTime: DateTime(2026, 1, 1)));
    }
    await repo.replaceGearRows('a', const [
      GearProvenance(equipmentId: 'reg', viaSetId: 'winter'),
      GearProvenance(equipmentId: 'hose', viaEquipmentId: 'reg', viaSetId: 'winter'),
    ]);
    await repo.replaceGearRows('b', const [
      GearProvenance(equipmentId: 'reg'),
      GearProvenance(equipmentId: 'hose', viaEquipmentId: 'reg'),
      GearProvenance(equipmentId: 'mask'),
    ]);
    await repo.replaceGearRows('c', const [GearProvenance(equipmentId: 'mask')]);
  });

  tearDown(tearDownTestDatabase);

  Future<Map<String, DiveEquipmentData>> rowsOf(String diveId) async => {
    for (final r in await (db.select(db.diveEquipment)..where((t) => t.diveId.equals(diveId))).get())
      r.equipmentId: r,
  };

  Future<int> updatedAtOf(String diveId) async =>
      (await (db.select(db.dives)..where((t) => t.id.equals(diveId))).getSingle()).updatedAt;

  test('diveIdsWithEquipment lists the dives that carry the item', () async {
    expect(await repo.diveIdsWithEquipment('reg'), unorderedEquals(['a', 'b']));
    expect(await repo.diveIdsWithEquipment('newhose'), isEmpty);
  });

  test('an added part lands on every dive with the assembly, tagged with its set', () async {
    final before = await updatedAtOf('c');
    final touched = await repo.rewriteAssemblyOnPastDives('reg', const GearPartAdded('first'));
    expect(touched, 2);
    expect((await rowsOf('a'))['first']!.viaEquipmentId, 'reg');
    expect((await rowsOf('a'))['first']!.viaSetId, 'winter');
    expect((await rowsOf('b'))['first']!.viaSetId, isNull);
    expect((await rowsOf('c')).keys, ['mask']);
    expect(await updatedAtOf('c'), before);
  });

  test('a removed part leaves every dive and tombstones the rows', () async {
    await repo.rewriteAssemblyOnPastDives('reg', const GearPartRemoved('hose'));
    expect((await rowsOf('a')).keys, ['reg']);
    expect((await rowsOf('b')).keys, unorderedEquals(['reg', 'mask']));
    final tombstones = [
      for (final t in await db.select(db.deletionLog).get())
        if (t.entityType == 'diveEquipment') t.recordId,
    ];
    expect(tombstones, unorderedEquals(['a|hose', 'b|hose']));
  });

  test('a replaced part is re-keyed and each touched dive is re-stamped', () async {
    final before = await updatedAtOf('a');
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await repo.rewriteAssemblyOnPastDives(
      'reg',
      const GearPartReplaced(oldPartId: 'hose', newPartId: 'newhose'),
    );
    final a = await rowsOf('a');
    expect(a.keys, unorderedEquals(['reg', 'newhose']));
    expect(a['newhose']!.viaEquipmentId, 'reg');
    expect(a['newhose']!.viaSetId, 'winter');
    expect(await updatedAtOf('a'), greaterThan(before));
  });
}
```

For the component repository, open `test/features/equipment/data/repositories/equipment_component_repository_test.dart`, read its setup (it seeds equipment rows and constructs the repository), and add:

```dart
  group('replaceComponent', () {
    test('keeps role and order, swaps the component id, marks the row pending', () async {
      final row = await repository.addComponent(parentId: 'reg', componentId: 'hose', role: 'Primary');
      await repository.replaceComponent(row.id, 'newhose');
      final parts = await repository.getComponents('reg');
      expect(parts.single.componentEquipmentId, 'newhose');
      expect(parts.single.role, 'Primary');
      expect(parts.single.sortOrder, row.sortOrder);
      final pending = await db.select(db.syncRecords).get();
      expect(pending.map((r) => r.recordId), contains(row.id));
    });

    test('refuses a replacement that would close a cycle', () async {
      await repository.addComponent(parentId: 'kit', componentId: 'reg');
      final row = await repository.addComponent(parentId: 'reg', componentId: 'hose');
      expect(
        () => repository.replaceComponent(row.id, 'kit'),
        throwsA(isA<EquipmentComponentCycleException>()),
      );
    });
  });
```

Use the ids that file already seeds (read it first; substitute its names for `reg`, `hose`, `newhose`, `kit`, seeding extra rows the same way it does if needed).

- [ ] **Step 2: Run both to verify they fail**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_assembly_history_test.dart test/features/equipment/data/repositories/equipment_component_repository_test.dart`
Expected: compile errors, `diveIdsWithEquipment`, `rewriteAssemblyOnPastDives` and `replaceComponent` undefined.

- [ ] **Step 3: Add the two dive repository methods**

Import `gear_history_rewrite.dart`. Beside `replaceGearRows`:

```dart
  /// Ids of the dives that carry [equipmentId] as a gear row.
  Future<List<String>> diveIdsWithEquipment(String equipmentId) async {
    final rows =
        await (_db.selectOnly(_db.diveEquipment, distinct: true)
              ..addColumns([_db.diveEquipment.diveId])
              ..where(_db.diveEquipment.equipmentId.equals(equipmentId)))
            .get();
    return [for (final r in rows) r.read(_db.diveEquipment.diveId)!];
  }

  /// Replays a change to an assembly's template on every past dive that
  /// carries the assembly (issue #1487, "also update N past dives"). One
  /// transaction; each dive whose rows changed goes through the diff
  /// writer, so unchanged rows are neither tombstoned nor re-marked, and
  /// is re-stamped so sync carries it. Returns how many dives changed.
  Future<int> rewriteAssemblyOnPastDives(
    String assemblyId,
    GearHistoryRewrite rewrite,
  ) async {
    final diveIds = await diveIdsWithEquipment(assemblyId);
    if (diveIds.isEmpty) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final touched = <String>[];
    await _db.transaction(() async {
      for (final diveId in diveIds) {
        final rows = await _provenanceOf(diveId);
        final next = rewrite.applyTo(rows, assemblyId);
        if (next.length == rows.length &&
            [for (var i = 0; i < rows.length; i++) next[i] == rows[i]]
                .every((same) => same)) {
          continue;
        }
        await _writeGearDiff(diveId, next, now);
        touched.add(diveId);
      }
      if (touched.isNotEmpty) await _bumpDives(touched, now);
    });
    if (touched.isNotEmpty) SyncEventBus.notifyLocalChange();
    return touched.length;
  }
```

Check that `_bumpDives` is safe inside a transaction (read it: it updates `dives.updatedAt` and marks each pending; both are plain writes). If `selectOnly` does not accept `distinct:` in this Drift version, drop the argument and wrap the result in a `Set` before returning.

- [ ] **Step 4: Add replaceComponent**

Beside `updateRole` in the component repository:

```dart
  /// Swaps the component on one template row for [newComponentId], keeping
  /// the row's role and order (issue #1487). Cycle-guarded like an add.
  Future<EquipmentComponent> replaceComponent(
    String id,
    String newComponentId,
  ) async {
    final row = await (_db.select(
      _db.equipmentComponents,
    )..where((t) => t.id.equals(id))).getSingle();
    if (await wouldCreateCycle(
      parentId: row.parentEquipmentId,
      componentId: newComponentId,
    )) {
      throw EquipmentComponentCycleException(
        row.parentEquipmentId,
        newComponentId,
      );
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.equipmentComponents,
    )..where((t) => t.id.equals(id))).write(
      EquipmentComponentsCompanion(
        componentEquipmentId: Value(newComponentId),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: entityType,
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
    return getComponent(id);
  }
```

`getComponent(id)` is the single-row read that precedes `updateRole` (L196-199); use its real name. The unique `(parent, component)` constraint rejects a replacement that duplicates an existing part; let that surface as the same snackbar path the picker already has for any other failure.

- [ ] **Step 5: Run the tests and the neighbours**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_assembly_history_test.dart test/features/equipment/data/repositories/equipment_component_repository_test.dart test/features/dive_log/data/repositories/dive_repository_gear_provenance_test.dart`
Expected: PASS.

- [ ] **Step 6: Regenerate mocks, format and commit**

The dive repository's public surface changed, so run the codegen script (`sh <scratchpad>/codegen.sh <worktree>`, about three minutes) before `flutter analyze`; the generated mocks are ignored by git.

```bash
dart format lib/features/dive_log/data/repositories/dive_repository_impl.dart lib/features/equipment/data/repositories/equipment_component_repository.dart test/features/dive_log/data/repositories/dive_repository_assembly_history_test.dart test/features/equipment/data/repositories/equipment_component_repository_test.dart
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart lib/features/equipment/data/repositories/equipment_component_repository.dart test/features/dive_log/data/repositories/dive_repository_assembly_history_test.dart test/features/equipment/data/repositories/equipment_component_repository_test.dart
git commit -m "feat(dive-log): replay an assembly change on past dives; replace a part in place (#1487)

rewriteAssemblyOnPastDives loops the dives that carry the assembly
through the pure rule and the diff writer, re-stamping each one that
changed. The component repository can swap the item on a template row
while keeping its role and order."
```

---

### Task 3: The swap-with-history dialog and its strings

**Files:**
- Create: `lib/features/equipment/presentation/widgets/assembly_history_dialog.dart`
- Modify: all 11 ARB files; regenerate
- Test: `test/features/equipment/presentation/widgets/assembly_history_dialog_test.dart`

**Interfaces:**
- Produces:
  - `enum AssemblyHistoryChange { added, removed, replaced }`
  - `enum AssemblyHistoryChoice { futureOnly, alsoPast }`
  - `Future<AssemblyHistoryChoice?> showAssemblyHistoryDialog(BuildContext context, {required int pastDiveCount, required AssemblyHistoryChange change})` (null when dismissed)
  - ARB keys, all under the `equipment_components_` prefix: `historyTitle`, `historyOnDives` (plural on `count`), `historyAskAdded`, `historyAskRemoved`, `historyAskReplaced`, `historyFutureOnly`, `historyAlsoPast` (plural on `count`), `replace`, `pickerReplaceTitle`, `pickerReplaceConfirm`.

- [ ] **Step 1: Add the keys to all 11 locales and regenerate**

Insert inside the existing `equipment_components_` block (the helper finds it; by hand, keep the block contiguous).

`en`:
```
"equipment_components_historyTitle": "Update past dives?",
"equipment_components_historyOnDives": "{count, plural, =1{This assembly is on 1 logged dive.} other{This assembly is on {count} logged dives.}}",
"equipment_components_historyAskAdded": "Add the new part to those dives as well, or only from now on?",
"equipment_components_historyAskRemoved": "Remove the part from those dives as well, or only from now on?",
"equipment_components_historyAskReplaced": "Swap the part on those dives as well, or only from now on?",
"equipment_components_historyFutureOnly": "From now on",
"equipment_components_historyAlsoPast": "{count, plural, =1{Also update 1 dive} other{Also update {count} dives}}",
"equipment_components_replace": "Replace component",
"equipment_components_pickerReplaceTitle": "Replace with",
"equipment_components_pickerReplaceConfirm": "Replace",
```

`de`: "Vergangene Tauchgänge aktualisieren?"; "{count, plural, =1{Diese Baugruppe ist auf 1 protokollierten Tauchgang.} other{Diese Baugruppe ist auf {count} protokollierten Tauchgängen.}}"; "Das neue Teil auch dort hinzufügen oder nur ab jetzt?"; "Das Teil auch dort entfernen oder nur ab jetzt?"; "Das Teil auch dort tauschen oder nur ab jetzt?"; "Ab jetzt"; "{count, plural, =1{Auch 1 Tauchgang aktualisieren} other{Auch {count} Tauchgänge aktualisieren}}"; "Komponente ersetzen"; "Ersetzen durch"; "Ersetzen".
`fr`: "Mettre à jour les plongées passées ?"; "{count, plural, =1{Cet ensemble figure sur 1 plongée enregistrée.} other{Cet ensemble figure sur {count} plongées enregistrées.}}"; "Ajouter la nouvelle pièce à ces plongées aussi, ou seulement à partir de maintenant ?"; "Retirer la pièce de ces plongées aussi, ou seulement à partir de maintenant ?"; "Remplacer la pièce sur ces plongées aussi, ou seulement à partir de maintenant ?"; "À partir de maintenant"; "{count, plural, =1{Mettre aussi à jour 1 plongée} other{Mettre aussi à jour {count} plongées}}"; "Remplacer le composant"; "Remplacer par"; "Remplacer".
`es`: "¿Actualizar inmersiones pasadas?"; "{count, plural, =1{Este conjunto está en 1 inmersión registrada.} other{Este conjunto está en {count} inmersiones registradas.}}"; "¿Añadir la pieza nueva también a esas inmersiones o solo a partir de ahora?"; "¿Quitar la pieza también de esas inmersiones o solo a partir de ahora?"; "¿Cambiar la pieza también en esas inmersiones o solo a partir de ahora?"; "A partir de ahora"; "{count, plural, =1{Actualizar también 1 inmersión} other{Actualizar también {count} inmersiones}}"; "Reemplazar componente"; "Reemplazar por"; "Reemplazar".
`it`: "Aggiornare le immersioni passate?"; "{count, plural, =1{Questo assieme è su 1 immersione registrata.} other{Questo assieme è su {count} immersioni registrate.}}"; "Aggiungere la nuova parte anche a quelle immersioni o solo da ora in poi?"; "Rimuovere la parte anche da quelle immersioni o solo da ora in poi?"; "Sostituire la parte anche su quelle immersioni o solo da ora in poi?"; "Da ora in poi"; "{count, plural, =1{Aggiorna anche 1 immersione} other{Aggiorna anche {count} immersioni}}"; "Sostituisci componente"; "Sostituisci con"; "Sostituisci".
`nl`: "Eerdere duiken bijwerken?"; "{count, plural, =1{Dit samenstel staat op 1 gelogde duik.} other{Dit samenstel staat op {count} gelogde duiken.}}"; "Het nieuwe onderdeel ook aan die duiken toevoegen, of alleen vanaf nu?"; "Het onderdeel ook van die duiken verwijderen, of alleen vanaf nu?"; "Het onderdeel ook op die duiken vervangen, of alleen vanaf nu?"; "Vanaf nu"; "{count, plural, =1{Ook 1 duik bijwerken} other{Ook {count} duiken bijwerken}}"; "Onderdeel vervangen"; "Vervangen door"; "Vervangen".
`pt`: "Atualizar mergulhos anteriores?"; "{count, plural, =1{Este conjunto está em 1 mergulho registado.} other{Este conjunto está em {count} mergulhos registados.}}"; "Adicionar a nova peça também a esses mergulhos, ou só a partir de agora?"; "Remover a peça também desses mergulhos, ou só a partir de agora?"; "Trocar a peça também nesses mergulhos, ou só a partir de agora?"; "A partir de agora"; "{count, plural, =1{Atualizar também 1 mergulho} other{Atualizar também {count} mergulhos}}"; "Substituir componente"; "Substituir por"; "Substituir".
`hu`: "Frissíti a korábbi merüléseket?"; "{count, plural, =1{Ez az összeállítás 1 naplózott merülésen szerepel.} other{Ez az összeállítás {count} naplózott merülésen szerepel.}}"; "Az új részt azokhoz a merülésekhez is hozzáadja, vagy csak mostantól?"; "A részt azokról a merülésekről is eltávolítja, vagy csak mostantól?"; "A részt azokon a merüléseken is kicseréli, vagy csak mostantól?"; "Mostantól"; "{count, plural, =1{1 merülés frissítése is} other{{count} merülés frissítése is}}"; "Alkatrész cseréje"; "Csere erre"; "Csere".
`ar`: "تحديث الغطسات السابقة؟"; "{count, plural, =1{هذه التجميعة موجودة في غطسة مسجلة واحدة.} other{هذه التجميعة موجودة في {count} غطسات مسجلة.}}"; "إضافة الجزء الجديد إلى تلك الغطسات أيضًا، أم من الآن فصاعدًا فقط؟"; "إزالة الجزء من تلك الغطسات أيضًا، أم من الآن فصاعدًا فقط؟"; "تبديل الجزء في تلك الغطسات أيضًا، أم من الآن فصاعدًا فقط؟"; "من الآن فصاعدًا"; "{count, plural, =1{تحديث غطسة واحدة أيضًا} other{تحديث {count} غطسات أيضًا}}"; "استبدال المكوّن"; "استبدال بـ"; "استبدال".
`he`: "לעדכן צלילות קודמות?"; "{count, plural, =1{המכלול הזה נמצא בצלילה רשומה אחת.} other{המכלול הזה נמצא ב-{count} צלילות רשומות.}}"; "להוסיף את החלק החדש גם לצלילות האלה, או רק מעכשיו?"; "להסיר את החלק גם מהצלילות האלה, או רק מעכשיו?"; "להחליף את החלק גם בצלילות האלה, או רק מעכשיו?"; "מעכשיו"; "{count, plural, =1{לעדכן גם צלילה אחת} other{לעדכן גם {count} צלילות}}"; "החלפת רכיב"; "להחליף ב"; "החלפה".
`zh`: "更新过去的潜水？"; "{count, plural, =1{此组合出现在 1 次已记录的潜水中。} other{此组合出现在 {count} 次已记录的潜水中。}}"; "也将新部件添加到这些潜水，还是仅从现在起？"; "也从这些潜水中移除该部件，还是仅从现在起？"; "也在这些潜水中更换该部件，还是仅从现在起？"; "从现在起"; "{count, plural, =1{同时更新 1 次潜水} other{同时更新 {count} 次潜水}}"; "更换组件"; "更换为"; "更换".

Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing dialog test**

```dart
// test/features/equipment/presentation/widgets/assembly_history_dialog_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/presentation/widgets/assembly_history_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Future<AssemblyHistoryChoice?> open(
    WidgetTester tester, {
    required int count,
    required AssemblyHistoryChange change,
  }) async {
    AssemblyHistoryChoice? result;
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              opened = true;
              result = await showAssemblyHistoryDialog(
                context,
                pastDiveCount: count,
                change: change,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(opened, isTrue);
    return result;
  }

  testWidgets('names the count and the change, defaults to from now on', (tester) async {
    final future = open(tester, count: 3, change: AssemblyHistoryChange.added);
    await tester.pumpAndSettle();
    expect(find.text('Update past dives?'), findsOneWidget);
    expect(find.text('This assembly is on 3 logged dives.'), findsOneWidget);
    expect(find.textContaining('Add the new part'), findsOneWidget);
    await tester.tap(find.text('From now on'));
    await tester.pumpAndSettle();
    expect(await future, AssemblyHistoryChoice.futureOnly);
  });

  testWidgets('also update N returns alsoPast, singular at one', (tester) async {
    final future = open(tester, count: 1, change: AssemblyHistoryChange.replaced);
    await tester.pumpAndSettle();
    expect(find.text('This assembly is on 1 logged dive.'), findsOneWidget);
    await tester.tap(find.text('Also update 1 dive'));
    await tester.pumpAndSettle();
    expect(await future, AssemblyHistoryChoice.alsoPast);
  });

  testWidgets('dismissing returns null', (tester) async {
    final future = open(tester, count: 2, change: AssemblyHistoryChange.removed);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await future, isNull);
  });
}
```

The `open` helper cannot both await the dialog and drive it; restructure so `open` stores the future and returns it without awaiting (the sketch above already awaits only after tapping). If `AppLocalizations` has no `common_cancel`, use the existing `diveLog_edit_cancel` value "Cancel" for the third button.

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/features/equipment/presentation/widgets/assembly_history_dialog_test.dart`
Expected: compile error, `assembly_history_dialog.dart` not found.

- [ ] **Step 4: Write the dialog**

```dart
// lib/features/equipment/presentation/widgets/assembly_history_dialog.dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// What just changed on the template, for the dialog's wording.
enum AssemblyHistoryChange { added, removed, replaced }

/// The diver's answer: keep past dives as they were, or rewrite them too.
enum AssemblyHistoryChoice { futureOnly, alsoPast }

/// Asks whether a template change should also be applied to the past dives
/// that carry the assembly (issue #1487, "swap with history"). Callers skip
/// it when [pastDiveCount] is zero. Returns null when dismissed.
Future<AssemblyHistoryChoice?> showAssemblyHistoryDialog(
  BuildContext context, {
  required int pastDiveCount,
  required AssemblyHistoryChange change,
}) {
  final l10n = context.l10n;
  final ask = switch (change) {
    AssemblyHistoryChange.added => l10n.equipment_components_historyAskAdded,
    AssemblyHistoryChange.removed =>
      l10n.equipment_components_historyAskRemoved,
    AssemblyHistoryChange.replaced =>
      l10n.equipment_components_historyAskReplaced,
  };
  return showDialog<AssemblyHistoryChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.equipment_components_historyTitle),
      content: Text(
        '${l10n.equipment_components_historyOnDives(pastDiveCount)} $ask',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.diveLog_edit_cancel),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(AssemblyHistoryChoice.alsoPast),
          child: Text(l10n.equipment_components_historyAlsoPast(pastDiveCount)),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(AssemblyHistoryChoice.futureOnly),
          child: Text(l10n.equipment_components_historyFutureOnly),
        ),
      ],
    ),
  );
}
```

The two sentences are joined with a space rather than a third key because both are complete sentences in every locale above.

- [ ] **Step 5: Run the test**

Run: `flutter test test/features/equipment/presentation/widgets/assembly_history_dialog_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 6: Format and commit**

```bash
dart format lib/features/equipment/presentation/widgets/assembly_history_dialog.dart test/features/equipment/presentation/widgets/assembly_history_dialog_test.dart
git add lib/features/equipment/presentation/widgets/assembly_history_dialog.dart test/features/equipment/presentation/widgets/assembly_history_dialog_test.dart lib/l10n/arb
git commit -m "feat(equipment): the swap-with-history dialog (#1487)

Asks whether a template change also applies to the past dives that
carry the assembly, defaulting to from now on."
```

---

### Task 4: Wire the dialog into add, remove and a new replace action

**Files:**
- Modify: `lib/features/equipment/presentation/widgets/component_picker_sheet.dart` (`showComponentPicker` L14-32, `ComponentPickerSheet` L38-46, `_confirm` L74-103, the checkbox rows and confirm label further down)
- Modify: `lib/features/equipment/presentation/widgets/components_card.dart` (`onRemove` L116, `_ComponentsList` L131-191, `_PartTile` L193-271)
- Test: `test/features/equipment/presentation/widgets/components_card_test.dart` (existing; add cases)
- Test: `test/features/equipment/presentation/widgets/component_picker_sheet_test.dart` (existing; add cases)

**Interfaces:**
- Consumes: `showAssemblyHistoryDialog`, `EquipmentRepository.getDiveCountForEquipment`, `DiveRepository.rewriteAssemblyOnPastDives`, `EquipmentComponentRepository.replaceComponent`, `diveRepositoryProvider`, `equipmentRepositoryProvider`.
- Produces:
  - `showComponentPicker(context, {required String parentId, EquipmentComponent? replacing})`: with `replacing`, single-select, title `pickerReplaceTitle`, confirm `pickerReplaceConfirm`, and the row being replaced is not excluded from the candidates' exclusion list (its item is, since it is a current part).
  - A shared helper in `components_card.dart`, top level, used by both files:
    `Future<AssemblyHistoryChoice?> askAssemblyHistory(BuildContext context, WidgetRef ref, {required String assemblyId, required AssemblyHistoryChange change})` which reads the dive count and returns `futureOnly` without a dialog when it is zero.
  - Card row action "Replace component" (`Icons.swap_horiz`).

- [ ] **Step 1: Write the failing widget tests**

Read both existing test files first for their fakes and pump helpers. The card test subclasses `EquipmentComponentRepository` and overrides `removeComponent`, `updateRole`, `reorder`, `distinctRoles` (L18-29) and overrides the providers at L66-70. Extend that fake with `replaceComponent` recording `(id, newId)`, add a fake `EquipmentRepository` subclass overriding `getDiveCountForEquipment` to return a configurable count, and a fake `DiveRepository` subclass overriding `rewriteAssemblyOnPastDives` to record `(assemblyId, rewrite)` and return the count. Override `equipmentRepositoryProvider` and `diveRepositoryProvider` with them. Then add to the card test:

```dart
  testWidgets('removing a part on an assembly with past dives asks, and also-past replays', (tester) async {
    dives.count = 2;
    await pump(tester);
    await tester.tap(find.byTooltip('Remove component').first);
    await tester.pumpAndSettle();
    expect(find.text('Update past dives?'), findsOneWidget);
    await tester.tap(find.text('Also update 2 dives'));
    await tester.pumpAndSettle();
    expect(repo.removed, ['c1']);
    expect(dives.rewrites.single.$1, 'reg');
    expect(dives.rewrites.single.$2, const GearPartRemoved('hose'));
  });

  testWidgets('with no past dives there is no dialog', (tester) async {
    dives.count = 0;
    await pump(tester);
    await tester.tap(find.byTooltip('Remove component').first);
    await tester.pumpAndSettle();
    expect(find.text('Update past dives?'), findsNothing);
    expect(repo.removed, ['c1']);
    expect(dives.rewrites, isEmpty);
  });

  testWidgets('from now on removes the part and leaves past dives alone', (tester) async {
    dives.count = 2;
    await pump(tester);
    await tester.tap(find.byTooltip('Remove component').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('From now on'));
    await tester.pumpAndSettle();
    expect(repo.removed, ['c1']);
    expect(dives.rewrites, isEmpty);
  });

  testWidgets('cancelling the dialog changes nothing', (tester) async {
    dives.count = 2;
    await pump(tester);
    await tester.tap(find.byTooltip('Remove component').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.removed, isEmpty);
  });

  testWidgets('replace opens the single-select picker', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Replace component').first);
    await tester.pumpAndSettle();
    expect(find.text('Replace with'), findsOneWidget);
    expect(find.text('Replace'), findsOneWidget);
  });
```

(`repo`, `dives`, `pump`, `c1`, `reg`, `hose` are whatever that file names its fake, its fixture row id, the assembly id and the part id; match them.) In the picker test, add:

```dart
  testWidgets('adding on an assembly with past dives asks once and replays each part', (tester) async {
    dives.count = 3;
    await pumpPicker(tester);
    await tester.tap(find.text('Long hose'));
    await tester.tap(find.text('First stage'));
    await tester.tap(find.textContaining('Add 2'));
    await tester.pumpAndSettle();
    expect(find.text('Update past dives?'), findsOneWidget);
    await tester.tap(find.text('Also update 3 dives'));
    await tester.pumpAndSettle();
    expect(repo.added.map((a) => a.componentId), ['hose', 'first']);
    expect(dives.rewrites.map((r) => r.$2), [
      const GearPartAdded('hose'),
      const GearPartAdded('first'),
    ]);
  });

  testWidgets('replace mode selects one, replaces the row and replays', (tester) async {
    dives.count = 1;
    await pumpPicker(tester, replacing: existingRow);
    await tester.tap(find.text('Long hose'));
    await tester.tap(find.text('First stage'));
    // Single select: the second tap moved the selection.
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Also update 1 dive'));
    await tester.pumpAndSettle();
    expect(repo.replaced.single, (existingRow.id, 'first'));
    expect(
      dives.rewrites.single.$2,
      GearPartReplaced(oldPartId: existingRow.componentEquipmentId, newPartId: 'first'),
    );
  });
```

Match names to that file's fakes and fixtures (it already fakes the component repository and overrides `activeEquipmentProvider` and `equipmentComponentsIndexProvider`).

- [ ] **Step 2: Run both to verify they fail**

Run: `flutter test test/features/equipment/presentation/widgets/components_card_test.dart test/features/equipment/presentation/widgets/component_picker_sheet_test.dart`
Expected: compile errors on `replacing:` and `replaceComponent`, then the dialog assertions.

- [ ] **Step 3: The shared helper and the card**

In `components_card.dart` add imports for `assembly_history_dialog.dart`, `gear_history_rewrite.dart`, `dive_repository_provider.dart` (`diveRepositoryProvider`, at `lib/features/dive_log/presentation/providers/dive_repository_provider.dart`), and add a top-level function:

```dart
/// Asks the swap-with-history question when [assemblyId] is on at least one
/// dive; with none there is nothing to ask and the answer is from now on.
Future<AssemblyHistoryChoice?> askAssemblyHistory(
  BuildContext context,
  WidgetRef ref, {
  required String assemblyId,
  required AssemblyHistoryChange change,
}) async {
  final count = await ref
      .read(equipmentRepositoryProvider)
      .getDiveCountForEquipment(assemblyId);
  if (count == 0) return AssemblyHistoryChoice.futureOnly;
  if (!context.mounted) return null;
  return showAssemblyHistoryDialog(
    context,
    pastDiveCount: count,
    change: change,
  );
}
```

Replace `onRemove: (part) => repository.removeComponent(part.id),` with `onRemove: (part) => _remove(context, ref, part),` and add to the card:

```dart
  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    EquipmentComponent part,
  ) async {
    final choice = await askAssemblyHistory(
      context,
      ref,
      assemblyId: equipmentId,
      change: AssemblyHistoryChange.removed,
    );
    if (choice == null) return;
    await ref.read(equipmentComponentRepositoryProvider).removeComponent(part.id);
    if (choice == AssemblyHistoryChoice.alsoPast) {
      await ref
          .read(diveRepositoryProvider)
          .rewriteAssemblyOnPastDives(
            equipmentId,
            GearPartRemoved(part.componentEquipmentId),
          );
    }
  }
```

Add `onReplace` alongside `onRemove` through `_ComponentsList` and `_PartTile`, and in `_PartTile`'s trailing row insert before the delete button:

```dart
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: l10n.equipment_components_replace,
            onPressed: onReplace,
          ),
```

with the card passing `onReplace: (part) => showComponentPicker(context, parentId: equipmentId, replacing: part)`.

- [ ] **Step 4: The picker**

`showComponentPicker` gains `EquipmentComponent? replacing` and passes it to the sheet. In the sheet: with `replacing` set, `_selected` holds at most one id (a tap replaces the selection), the title reads `pickerReplaceTitle`, the confirm button reads `pickerReplaceConfirm`. `_confirm` becomes:

```dart
  Future<void> _confirm() async {
    if (_selected.isEmpty || _saving) return;
    final replacing = widget.replacing;
    final choice = await askAssemblyHistory(
      context,
      ref,
      assemblyId: widget.parentId,
      change: replacing == null
          ? AssemblyHistoryChange.added
          : AssemblyHistoryChange.replaced,
    );
    if (choice == null || !mounted) return;
    setState(() => _saving = true);
    final repository = ref.read(equipmentComponentRepositoryProvider);
    final dives = ref.read(diveRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final cycleText = context.l10n.equipment_components_cycleError;
    var popped = false;
    try {
      final ids = _selected.toList();
      if (replacing != null) {
        await repository.replaceComponent(replacing.id, ids.single);
        if (choice == AssemblyHistoryChoice.alsoPast) {
          await dives.rewriteAssemblyOnPastDives(
            widget.parentId,
            GearPartReplaced(
              oldPartId: replacing.componentEquipmentId,
              newPartId: ids.single,
            ),
          );
        }
      } else {
        for (final id in ids) {
          await repository.addComponent(parentId: widget.parentId, componentId: id);
          if (choice == AssemblyHistoryChoice.alsoPast) {
            await dives.rewriteAssemblyOnPastDives(widget.parentId, GearPartAdded(id));
          }
        }
      }
      popped = true;
      if (mounted) Navigator.of(context).pop();
    } on EquipmentComponentCycleException {
      messenger.showSnackBar(SnackBar(content: Text(cycleText)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (!popped && mounted) setState(() => _saving = false);
    }
  }
```

Import `assembly_history_dialog.dart`, `gear_history_rewrite.dart`, `dive_repository_provider.dart` and `components_card.dart` (for `askAssemblyHistory`; if that creates an import cycle the analyzer dislikes, move the helper into `assembly_history_dialog.dart` instead and import that from both).

- [ ] **Step 5: Run the widget tests and their neighbours**

Run: `flutter test test/features/equipment/presentation/widgets/components_card_test.dart test/features/equipment/presentation/widgets/component_picker_sheet_test.dart test/features/equipment/presentation/widgets/assembly_history_dialog_test.dart test/features/equipment/presentation/widgets/component_role_dialog_test.dart`
Expected: PASS.

- [ ] **Step 6: Format and commit**

```bash
dart format lib/features/equipment/presentation/widgets test/features/equipment/presentation/widgets
git add lib/features/equipment/presentation/widgets/component_picker_sheet.dart lib/features/equipment/presentation/widgets/components_card.dart lib/features/equipment/presentation/widgets/assembly_history_dialog.dart test/features/equipment/presentation/widgets/components_card_test.dart test/features/equipment/presentation/widgets/component_picker_sheet_test.dart
git commit -m "feat(equipment): ask about past dives when a template changes; replace a part (#1487)

Adding, removing or replacing a part on an assembly that is on logged
dives asks once whether to replay the change on them. Replace is a new
row action that opens the picker single-select and keeps the row's role
and order."
```

---

### Task 5: UDDF export of components and gear links

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart` (`buildApplicationData` L878-895 parameters, `hasData` L900-915, the `equipmentsets` block L1343-1372 as the place to add both sections after)
- Modify: `lib/core/services/export/uddf/uddf_full_export_service.dart` (parameters L56-70, the call L441-458)
- Modify: `lib/core/services/export/export_service.dart` (`exportAllDataToUddf` and `saveAllDataToUddfFile` pass-through)
- Modify: `lib/features/settings/presentation/providers/export_providers.dart` (L513 and L1124 calls; load components beside `equipmentSets`)
- Test: `test/core/services/export/uddf/uddf_export_builders_test.dart` (existing; add a group)

**Interfaces:**
- Consumes: `EquipmentComponent`, `Dive.gear`, `GearLink`.
- Produces: `buildApplicationData(..., List<EquipmentComponent>? components, List<Dive>? gearLinkDives)` writing

```xml
<components>
  <component parent="equip_REG" component="equip_HOSE" order="0">
    <role>Primary hose</role>
  </component>
</components>
<gearlinks>
  <dive ref="dive_D1">
    <link item="equip_HOSE" via="equip_REG" set="set_WINTER"/>
  </dive>
</gearlinks>
```

  (`<role>` omitted when blank; `via` and `set` attributes omitted when null; a dive with no provenance rows gets no `<dive>` element; the sections are omitted when empty). `UddfFullExportService.exportAllDataToUddf` gains `List<EquipmentComponent>? components` and passes `gearLinkDives: dives`.

- [ ] **Step 1: Write the failing builders test**

Read the existing test's helper that runs a builder and parses the XML (its first 60 lines), then add:

```dart
  group('assemblies in the private block (#1487)', () {
    final t0 = DateTime(2026, 1, 1);
    final part = EquipmentComponent(
      id: 'c1', parentEquipmentId: 'reg', componentEquipmentId: 'hose',
      role: 'Primary hose', sortOrder: 0, createdAt: t0, updatedAt: t0,
    );
    const reg = EquipmentItem(id: 'reg', name: 'Reg', type: EquipmentType.regulator);
    const hose = EquipmentItem(id: 'hose', name: 'Hose', type: EquipmentType.hose);
    final dive = Dive(
      id: 'd1',
      dateTime: DateTime(2026, 3, 1),
      gear: gearLinksFor(const [reg, hose], const [
        GearProvenance(equipmentId: 'reg', viaSetId: 'winter'),
        GearProvenance(equipmentId: 'hose', viaEquipmentId: 'reg', viaSetId: 'winter'),
      ]),
    );

    test('writes components with prefixed refs, role and order', () {
      final xml = buildApplicationDataXml(components: [part]);
      final component = xml.findAllElements('component').single;
      expect(component.getAttribute('parent'), 'equip_reg');
      expect(component.getAttribute('component'), 'equip_hose');
      expect(component.getAttribute('order'), '0');
      expect(component.findElements('role').single.innerText, 'Primary hose');
    });

    test('writes gear links per dive, only for rows with provenance', () {
      final loose = Dive(id: 'd2', dateTime: DateTime(2026, 3, 2), gear: looseGear(const [reg]));
      final xml = buildApplicationDataXml(gearLinkDives: [dive, loose]);
      final dives = xml.findAllElements('gearlinks').single.findElements('dive').toList();
      expect(dives.single.getAttribute('ref'), 'dive_d1');
      final links = dives.single.findElements('link').toList();
      expect(links, hasLength(2));
      expect(links[1].getAttribute('item'), 'equip_hose');
      expect(links[1].getAttribute('via'), 'equip_reg');
      expect(links[1].getAttribute('set'), 'set_winter');
      expect(links[0].getAttribute('via'), isNull);
    });

    test('omits both sections when there is nothing to write', () {
      final xml = buildApplicationDataXml(gearLinkDives: [
        Dive(id: 'd2', dateTime: DateTime(2026, 3, 2), gear: looseGear(const [reg])),
      ]);
      expect(xml.findAllElements('components'), isEmpty);
      expect(xml.findAllElements('gearlinks'), isEmpty);
    });
  });
```

`buildApplicationDataXml` is a small local helper: an `XmlBuilder`, a root element, `UddfExportBuilders.buildApplicationData(builder, components: ..., gearLinkDives: ...)`, then `XmlDocument.parse(builder.buildDocument().toXmlString())`. Note `hasData` must also count the two new inputs, or the block is skipped entirely.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/services/export/uddf/uddf_export_builders_test.dart`
Expected: compile error, no `components` parameter.

- [ ] **Step 3: Write the two sections**

Add the parameters `List<EquipmentComponent>? components, List<Dive>? gearLinkDives` to `buildApplicationData`, extend `hasData` with `(components?.isNotEmpty ?? false) || (gearLinkDives?.any((d) => d.gear.any((g) => !g.isTopLevel || g.viaSetId != null)) ?? false)`, and after the `equipmentsets` block:

```dart
            // Assembly templates (issue #1487): one element per
            // equipment_components row, refs prefixed like every other
            // private-block reference.
            if (components != null && components.isNotEmpty) {
              builder.element(
                'components',
                nest: () {
                  for (final c in components) {
                    builder.element(
                      'component',
                      attributes: {
                        'parent': 'equip_${c.parentEquipmentId}',
                        'component': 'equip_${c.componentEquipmentId}',
                        'order': '${c.sortOrder}',
                      },
                      nest: () {
                        if (c.role.isNotEmpty) {
                          builder.element('role', nest: c.role);
                        }
                      },
                    );
                  }
                },
              );
            }

            // Gear provenance per dive: the assembly a row was attached
            // through and the set applied. The standard <equipmentused>
            // list already names the items, so a row with neither is
            // omitted here.
            final linkDives = [
              for (final d in gearLinkDives ?? const <Dive>[])
                if (d.gear.any((g) => !g.isTopLevel || g.viaSetId != null)) d,
            ];
            if (linkDives.isNotEmpty) {
              builder.element(
                'gearlinks',
                nest: () {
                  for (final d in linkDives) {
                    builder.element(
                      'dive',
                      attributes: {'ref': 'dive_${d.id}'},
                      nest: () {
                        for (final g in d.gear) {
                          if (g.isTopLevel && g.viaSetId == null) continue;
                          builder.element(
                            'link',
                            attributes: {
                              'item': 'equip_${g.item.id}',
                              if (g.viaEquipmentId != null)
                                'via': 'equip_${g.viaEquipmentId}',
                              if (g.viaSetId != null) 'set': 'set_${g.viaSetId}',
                            },
                          );
                        }
                      },
                    );
                  }
                },
              );
            }
```

Import `equipment_component.dart` in the builders file.

- [ ] **Step 4: Thread components through the full export**

`UddfFullExportService.exportAllDataToUddf` gains `List<EquipmentComponent>? components,` beside `equipmentSets` and passes `components: components, gearLinkDives: dives,` at the `buildApplicationData` call. `ExportService.exportAllDataToUddf` and `saveAllDataToUddfFile` gain and forward the same parameter (read their signatures near L224-300). In `export_providers.dart`, at both UDDF sites (L513 and L1124), load `final components = await EquipmentComponentRepository().getAllComponents();` beside the sets (the file constructs repositories the same way for sets; follow its pattern, or read `equipmentComponentRepositoryProvider` through `_ref` if the provider is in scope) and pass `components: components`.

- [ ] **Step 5: Run the builders test and the export suites**

Run: `flutter test test/core/services/export/uddf/uddf_export_builders_test.dart test/core/services/export/uddf/uddf_full_export_raw_data_test.dart test/core/services/export/uddf/uddf_owner_insurance_export_test.dart test/core/services/export/uddf/uddf_dives_export_raw_data_test.dart`
Expected: PASS.

- [ ] **Step 6: Format and commit**

```bash
dart format lib/core/services/export lib/features/settings/presentation/providers/export_providers.dart test/core/services/export/uddf/uddf_export_builders_test.dart
git add lib/core/services/export/uddf/uddf_export_builders.dart lib/core/services/export/uddf/uddf_full_export_service.dart lib/core/services/export/export_service.dart lib/features/settings/presentation/providers/export_providers.dart test/core/services/export/uddf/uddf_export_builders_test.dart
git commit -m "feat(export): UDDF carries assembly templates and gear provenance (#1487)

The private block gains <components> (one per template row) and
<gearlinks> keyed by dive reference (one per row with provenance); the
standard equipment list is untouched so other readers see nothing new."
```

---

### Task 6: UDDF import of both sections, through the full restore and the wizard

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_import_parsers.dart` (beside `parseEquipmentSet` L674)
- Modify: `lib/core/services/export/uddf/uddf_full_import_service.dart` (the private-block `equipment` parse L262-280, the dive loop at L885-900 where `sourceUuid` is set)
- Modify: `lib/features/universal_import/data/services/payload_merger.dart` (`_namespaced` L138-190, `_rewriteAliases` L232-268)
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart` (`ImportRepositories` L60-105 gains an optional `equipmentComponentRepository`; `import` L290-440: a components phase after equipment, a set id map from `_importEquipmentSets` L1203-1250, gear links in `_importDives` L1545-1562 and the `Dive(` at L1817 / `gear:` at L1854)
- Test: `test/core/services/export/uddf/uddf_full_import_service_test.dart` (existing; add a group)
- Test: `test/features/universal_import/data/services/payload_merger_test.dart` (existing; add two cases)
- Test: `test/core/services/export/uddf/uddf_assemblies_round_trip_test.dart`

**Why the rows ride on the entity maps:** the import wizard (`UddfImportParser` in `lib/features/universal_import/data/parsers/`) flattens `UddfImportResult` into per-entity `Map<String, dynamic>` lists and `universal_adapter.dart` rebuilds the result from those lists, so any side field on the result (the way `dataSourcesByDiveRef` is carried today) is dropped on the wizard path. Attaching each `<component>` to its parent equipment map as `components` and each dive's `<link>` rows to the dive map as `gearLinks` means both paths, restore and wizard, reach the entity importer with the data in place and neither the wizard parser nor the adapter changes. The multi-file merger is the one wizard piece that must learn the two nested lists, because it prefixes every `uddfId`-style reference with the file id and rewrites folded references.

**Interfaces:**
- Produces:
  - `UddfImportParsers.parseComponent(XmlElement)` returning `{parentRef, componentRef, role, sortOrder}`; `UddfImportParsers.parseGearLinks(XmlElement gearlinks)` returning `Map<String, List<Map<String, String?>>>` keyed by the `dive` element's `ref`, each entry `{itemRef, viaRef, setRef}`.
  - On each equipment map: `components: List<Map<String, dynamic>>` of `{componentRef, role, sortOrder}` (only when non-empty). On each dive map: `gearLinks: List<Map<String, String?>>` (only when non-empty).
  - `ImportRepositories.equipmentComponentRepository` (optional).
  - Import order: equipment, components (parent must be selected; both ends must be in `equipmentIdMapping`; cycle exceptions logged and skipped), sets (now filling `setIdMapping` from each set's `uddfId`), dives (provenance from the dive map's `gearLinks` through the two maps).

- [ ] **Step 1: Write the failing parse test**

Add to the full-import test, using its existing `importAllDataFromUddf` call style:

```dart
  group('assemblies in the private block (#1487)', () {
    const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<uddf version="3.2.0">
  <applicationdata><submersion version="1.0">
    <equipment>
      <item id="equip_reg"><name>Reg</name><type>regulator</type></item>
      <item id="equip_hose"><name>Hose</name><type>hose</type></item>
    </equipment>
    <equipmentsets>
      <set id="set_winter"><name>Winter</name><items><itemref>equip_reg</itemref></items></set>
    </equipmentsets>
    <components>
      <component parent="equip_reg" component="equip_hose" order="0"><role>Primary hose</role></component>
    </components>
    <gearlinks>
      <dive ref="dive_d1">
        <link item="equip_reg" set="set_winter"/>
        <link item="equip_hose" via="equip_reg" set="set_winter"/>
      </dive>
    </gearlinks>
  </submersion></applicationdata>
  <profiledata><repetitiongroup>
    <dive id="dive_d1">
      <informationbeforedive><datetime>2026-03-01T10:00:00</datetime></informationbeforedive>
      <informationafterdive><greatestdepth>18</greatestdepth><diveduration>2400</diveduration></informationafterdive>
    </dive>
  </repetitiongroup></profiledata>
</uddf>''';

    test('attaches components to the parent item and gear links to the dive', () async {
      final result = await UddfFullImportService().importAllDataFromUddf(xml);
      final reg = result.equipment.firstWhere((e) => e['uddfId'] == 'equip_reg');
      final hose = result.equipment.firstWhere((e) => e['uddfId'] == 'equip_hose');
      final components = reg['components'] as List;
      expect(components, hasLength(1));
      expect(components.single['componentRef'], 'equip_hose');
      expect(components.single['role'], 'Primary hose');
      expect(components.single['sortOrder'], 0);
      expect(hose.containsKey('components'), isFalse);

      final links = result.dives.single['gearLinks'] as List;
      expect(links, hasLength(2));
      expect(links[1]['itemRef'], 'equip_hose');
      expect(links[1]['viaRef'], 'equip_reg');
      expect(links[1]['setRef'], 'set_winter');
      expect(links[0]['viaRef'], isNull);
    });
  });
```

(If that file's fixtures need `<generator>` or `<diver>` elements to parse at all, copy the minimal envelope from one of its existing cases. Confirm the equipment map key for the `id` attribute is `uddfId` at `uddf_import_parsers.dart` L782.)

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/services/export/uddf/uddf_full_import_service_test.dart`
Expected: FAIL, `components` is null on the reg map.

- [ ] **Step 3: Parsers and the full-import wiring**

Parsers, beside `parseEquipmentSet`:

```dart
  /// One `<component>` of the private `<components>` block (issue #1487).
  static Map<String, dynamic> parseComponent(XmlElement element) => {
    'parentRef': element.getAttribute('parent') ?? '',
    'componentRef': element.getAttribute('component') ?? '',
    'role': getElementText(element, 'role') ?? '',
    'sortOrder': int.tryParse(element.getAttribute('order') ?? '') ?? 0,
  };

  /// The private `<gearlinks>` block: per dive ref, the rows that carry
  /// provenance.
  static Map<String, List<Map<String, String?>>> parseGearLinks(
    XmlElement gearlinks,
  ) => {
    for (final dive in gearlinks.findElements('dive'))
      if (dive.getAttribute('ref') case final ref? when ref.isNotEmpty)
        ref: [
          for (final link in dive.findElements('link'))
            if (link.getAttribute('item') case final item? when item.isNotEmpty)
              {
                'itemRef': item,
                'viaRef': link.getAttribute('via'),
                'setRef': link.getAttribute('set'),
              },
        ],
  };
```

(`getElementText` is whatever the parsers file names its text helper; match it.) Full import: after the private-block `equipment` section is parsed and before dives, attach components to their parents:

```dart
        // Assembly templates ride on the parent item's map so the wizard's
        // flattening keeps them (issue #1487).
        final componentsSection = submersionElement
            .findElements('components')
            .firstOrNull;
        if (componentsSection != null) {
          final byParent = <String, List<Map<String, dynamic>>>{};
          for (final element in componentsSection.findElements('component')) {
            final data = UddfImportParsers.parseComponent(element);
            final parentRef = data['parentRef'] as String;
            if (parentRef.isEmpty || (data['componentRef'] as String).isEmpty) {
              continue;
            }
            byParent.putIfAbsent(parentRef, () => []).add({
              'componentRef': data['componentRef'],
              'role': data['role'],
              'sortOrder': data['sortOrder'],
            });
          }
          for (final item in equipment) {
            final parts = byParent[item['uddfId']];
            if (parts != null) item['components'] = parts;
          }
        }
        final gearLinksSection = submersionElement
            .findElements('gearlinks')
            .firstOrNull;
        if (gearLinksSection != null) {
          gearLinksByDiveRef = UddfImportParsers.parseGearLinks(gearLinksSection);
        }
```

with `var gearLinksByDiveRef = <String, List<Map<String, String?>>>{};` declared beside the other collections near L227, and in the dive loop right after `diveData['sourceUuid'] = diveId;`:

```dart
      final links = gearLinksByDiveRef[diveId];
      if (links != null && links.isNotEmpty) diveData['gearLinks'] = links;
```

The `sourceUuid` block guards on a non-empty `diveId`; put the two lines inside that same guard. `UddfImportResult` does not change.

- [ ] **Step 4: Run the parse test**

Run: `flutter test test/core/services/export/uddf/uddf_full_import_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing merger tests**

Add to `payload_merger_test.dart`, matching its `payloadWith` helper and `FilePayload` usage:

```dart
    test('namespaces nested component and gear link refs per file', () {
      final a = payloadWith(
        equipment: [
          {
            'uddfId': 'equip_reg', 'name': 'Reg', 'type': 'regulator',
            'components': [
              {'componentRef': 'equip_hose', 'role': 'Primary', 'sortOrder': 0},
            ],
          },
          {'uddfId': 'equip_hose', 'name': 'Hose', 'type': 'hose'},
        ],
        dives: [
          {
            'dateTime': DateTime(2026, 1, 1, 9),
            'gearLinks': [
              {'itemRef': 'equip_hose', 'viaRef': 'equip_reg', 'setRef': 'set_w'},
              {'itemRef': 'equip_reg', 'viaRef': null, 'setRef': null},
            ],
          },
        ],
      );
      final merged = merger.merge([
        FilePayload(fileId: 'f0', fileName: 'a.uddf', payload: a),
      ]);
      final reg = merged.entitiesOf(ImportEntityType.equipment)[0];
      expect((reg['components'] as List)[0]['componentRef'], 'f0:equip_hose');
      final links = merged.entitiesOf(ImportEntityType.dives)[0]['gearLinks'] as List;
      expect(links[0]['itemRef'], 'f0:equip_hose');
      expect(links[0]['viaRef'], 'f0:equip_reg');
      expect(links[0]['setRef'], 'f0:set_w');
      expect(links[1]['viaRef'], isNull);
    });

    test('rewrites folded equipment inside components and gear links', () {
      final a = payloadWith(
        equipment: [
          {'uddfId': 'h1', 'name': 'Hose', 'type': 'hose'},
        ],
      );
      final b = payloadWith(
        equipment: [
          {'uddfId': 'h2', 'name': 'Hose', 'type': 'hose'},
          {
            'uddfId': 'r2', 'name': 'Reg', 'type': 'regulator',
            'components': [
              {'componentRef': 'h2', 'role': '', 'sortOrder': 0},
            ],
          },
        ],
        dives: [
          {
            'dateTime': DateTime(2026, 2, 1, 9),
            'gearLinks': [
              {'itemRef': 'h2', 'viaRef': 'r2', 'setRef': null},
            ],
          },
        ],
      );
      final merged = merger.merge([
        FilePayload(fileId: 'f0', fileName: 'a.uddf', payload: a),
        FilePayload(fileId: 'f1', fileName: 'b.uddf', payload: b),
      ]);
      final reg = merged
          .entitiesOf(ImportEntityType.equipment)
          .firstWhere((e) => e['name'] == 'Reg');
      expect((reg['components'] as List)[0]['componentRef'], 'f0:h1');
      final links = merged.entitiesOf(ImportEntityType.dives)[0]['gearLinks'] as List;
      expect(links[0]['itemRef'], 'f0:h1');
      expect(links[0]['viaRef'], 'f1:r2');
    });
```

- [ ] **Step 6: Run them to verify they fail**

Run: `flutter test test/features/universal_import/data/services/payload_merger_test.dart`
Expected: FAIL, refs still unprefixed.

- [ ] **Step 7: Teach the merger the two nested lists**

In `_namespaced`, after the dives block, add an equipment block and extend the dives block:

```dart
    if (type == ImportEntityType.equipment) {
      item['components'] = _mapRefs(
        item['components'],
        ['componentRef'],
        (ref) => '$fileId:$ref',
      );
    }
    if (type == ImportEntityType.dives) {
      item['gearLinks'] = _mapRefs(
        item['gearLinks'],
        ['itemRef', 'viaRef', 'setRef'],
        (ref) => '$fileId:$ref',
      );
    }
```

with a helper that copies a list of maps, rewriting the named string fields and leaving nulls alone, returning the input untouched when it is not a list:

```dart
  /// A copy of [value] (a list of maps) with each of [fields] rewritten by
  /// [rewrite] when it is a non-empty string; anything else passes through.
  static Object? _mapRefs(
    Object? value,
    List<String> fields,
    String Function(String ref) rewrite,
  ) {
    if (value is! List) return value;
    return [
      for (final entry in value)
        if (entry is Map<String, dynamic>)
          {
            ...entry,
            for (final field in fields)
              if (entry[field] case final String ref when ref.isNotEmpty)
                field: rewrite(ref),
          }
        else
          entry,
    ];
  }
```

Remove the key again when `_mapRefs` returns null so a map without the list does not gain a `null` entry (`if (item['components'] == null) item.remove('components');`, same for `gearLinks`). In `_rewriteAliases`, inside the dives loop add `dive['gearLinks'] = _mapRefs(dive['gearLinks'], ['itemRef', 'viaRef', 'setRef'], resolve);` and add a loop over `entities[ImportEntityType.equipment]` doing `item['components'] = _mapRefs(item['components'], ['componentRef'], resolve);` (with the same null clean-up).

- [ ] **Step 8: Run the merger tests**

Run: `flutter test test/features/universal_import/data/services/payload_merger_test.dart`
Expected: PASS.

- [ ] **Step 9: Write the failing round-trip test**

Model it on `test/core/services/export/uddf/uddf_raw_data_round_trip_test.dart` (its `buildRepositories()` at L35-49 and `createTestDiver()` at L51-64 are top-level and importable; its restore at L160-176):

```dart
// test/core/services/export/uddf/uddf_assemblies_round_trip_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart' as domain;
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';

import '../../../../helpers/test_database.dart';
import 'uddf_raw_data_round_trip_test.dart' show buildRepositories, createTestDiver;

/// Export a logbook with a nested assembly on a dive applied from a set,
/// restore it onto a clean database, and find the same shape (issue #1487).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  test('components and gear provenance survive export and import', () async {
    final diverId = await createTestDiver();
    final equipment = EquipmentRepository();
    final reg = await equipment.createEquipment(const EquipmentItem(id: '', name: 'Reg', type: EquipmentType.regulator));
    final first = await equipment.createEquipment(const EquipmentItem(id: '', name: 'First', type: EquipmentType.firstStage));
    final hose = await equipment.createEquipment(const EquipmentItem(id: '', name: 'Hose', type: EquipmentType.hose));
    final components = EquipmentComponentRepository();
    await components.addComponent(parentId: reg.id, componentId: first.id, role: 'First stage');
    await components.addComponent(parentId: first.id, componentId: hose.id, role: 'LP hose');
    final sets = EquipmentSetRepository();
    await sets.createSet(EquipmentSet(id: 'winter', diverId: diverId, name: 'Winter', equipmentIds: [reg.id], createdAt: DateTime.now(), updatedAt: DateTime.now()));
    final dives = DiveRepository();
    await dives.createDive(domain.Dive(
      id: 'd1', diverId: diverId, dateTime: DateTime(2026, 3, 1),
      gear: gearLinksFor([reg, first, hose], [
        GearProvenance(equipmentId: reg.id, viaSetId: 'winter'),
        GearProvenance(equipmentId: first.id, viaEquipmentId: reg.id, viaSetId: 'winter'),
        GearProvenance(equipmentId: hose.id, viaEquipmentId: first.id, viaSetId: 'winter'),
      ]),
    ));

    final xml = await UddfFullExportService().exportAllDataToUddf(
      dives: await dives.getAllDives(),
      equipment: await equipment.getAllEquipment(),
      equipmentSets: await sets.getAllSets(),
      components: await components.getAllComponents(),
    );

    await tearDownTestDatabase();
    db = await setUpTestDatabase();
    final restoredDiverId = await createTestDiver();
    final parsed = await ExportService().importAllDataFromUddf(xml);
    await UddfEntityImporter().import(
      data: parsed,
      selections: UddfImportSelections.selectAll(parsed),
      repositories: buildRepositories(),
      diverId: restoredDiverId,
    );

    final byName = {for (final e in await EquipmentRepository().getAllEquipment()) e.name: e.id};
    final rows = await EquipmentComponentRepository().getAllComponents();
    expect(rows, hasLength(2));
    expect(rows.firstWhere((r) => r.parentEquipmentId == byName['Reg']).componentEquipmentId, byName['First']);
    expect(rows.firstWhere((r) => r.parentEquipmentId == byName['First']).role, 'LP hose');

    final restored = (await DiveRepository().getAllDives()).single;
    final gear = {for (final g in restored.gear) g.item.name: g};
    expect(gear['Hose']!.viaEquipmentId, byName['First']);
    expect(gear['First']!.viaEquipmentId, byName['Reg']);
    final setId = (await EquipmentSetRepository().getAllSets()).single.id;
    expect(gear['Reg']!.viaSetId, setId);
    expect(gear['Hose']!.viaSetId, setId);
  });
}
```

Match the real names of `getAllEquipment`, `getAllSets`, `createSet` and `UddfImportSelections.selectAll` (if there is no `selectAll`, build the selections from index ranges the way the raw-data test's `UddfImportSelections(dives: {0})` does), and the export service's required parameters (read `exportAllDataToUddf`'s signature at L56-70; pass empty lists for anything required).

- [ ] **Step 10: Run it to verify it fails**

Run: `flutter test test/core/services/export/uddf/uddf_assemblies_round_trip_test.dart`
Expected: FAIL, no component rows after import and null provenance.

- [ ] **Step 11: The entity importer**

`ImportRepositories`: add `final EquipmentComponentRepository? equipmentComponentRepository;` and `this.equipmentComponentRepository,` to the constructor. In `import`, after `_importEquipment` (L323-331) and before `_importServiceRecords`, add:

```dart
    await _importComponents(
      data.equipment,
      selections.equipment,
      repositories.equipmentComponentRepository ??
          EquipmentComponentRepository(),
      equipmentIdMapping,
    );
```

with

```dart
  /// Assembly template rows (issue #1487), carried on each parent item's
  /// map as `components`. The parent must have been selected and both ends
  /// must be in [equipmentIdMapping]; a row that would close a cycle is
  /// logged and skipped, never thrown, since one bad edge must not cost
  /// the logbook. Rows are inserted in exported order so the appended
  /// sort_order matches.
  Future<int> _importComponents(
    List<Map<String, dynamic>> equipment,
    Set<int> selected,
    EquipmentComponentRepository repository,
    Map<String, String> equipmentIdMapping,
  ) async {
    var count = 0;
    for (final (index, item) in equipment.indexed) {
      if (!selected.contains(index)) continue;
      final parts = item['components'];
      if (parts is! List) continue;
      final parentId = equipmentIdMapping[item['uddfId']];
      if (parentId == null) continue;
      final sorted = [
        for (final p in parts)
          if (p is Map<String, dynamic>) p,
      ]..sort((a, b) => ((a['sortOrder'] as int?) ?? 0).compareTo((b['sortOrder'] as int?) ?? 0));
      for (final part in sorted) {
        final componentId = equipmentIdMapping[part['componentRef']];
        if (componentId == null) continue;
        try {
          await repository.addComponent(
            parentId: parentId,
            componentId: componentId,
            role: part['role'] as String? ?? '',
          );
          count++;
        } on EquipmentComponentCycleException {
          _log.warning('Skipped a component row that would close a cycle');
        }
      }
    }
    return count;
  }
```

(Confirm at `_importEquipment` L575 that the mapping is keyed by each map's `uddfId`, and that `selections.equipment` is a `Set<int>` of indices; use the file's logger field name.) `_importEquipmentSets` gains `Map<String, String> setIdMapping` and records `setIdMapping[setData['uddfId'] as String] = newId;` when `uddfId` is present. Declare `final setIdMapping = <String, String>{};` beside the other maps and pass it to both sets and dives. `_importDives` gains `required Map<String, String> setIdMapping`; after `linkedEquipment` is resolved (L1688) add:

```dart
      final links = diveData['gearLinks'];
      final provenance = <GearProvenance>[
        if (links is List)
          for (final link in links)
            if (link is Map && equipmentIdMapping[link['itemRef']] case final itemId?)
              GearProvenance(
                equipmentId: itemId,
                viaEquipmentId: equipmentIdMapping[link['viaRef']],
                viaSetId: setIdMapping[link['setRef']],
              ),
      ];
```

and replace `gear: looseGear(linkedEquipment),` with `gear: gearLinksFor(linkedEquipment, provenance),`. A `viaRef` whose item was not imported resolves to null, so that row lands loose rather than dangling. Import `gear_provenance.dart` and `equipment_component_repository.dart`.

- [ ] **Step 12: Run the round trip and the importer suites**

Run: `flutter test test/core/services/export/uddf/uddf_assemblies_round_trip_test.dart test/core/services/export/uddf/uddf_raw_data_round_trip_test.dart test/features/dive_import/data/services/uddf_entity_importer_test.dart test/core/services/export/uddf/uddf_full_import_service_test.dart test/features/import_wizard/data/adapters/universal_adapter_test.dart`
Expected: PASS. The entity importer and adapter tests are mock-based; if `ImportRepositories` mocks need regeneration, rerun codegen.

- [ ] **Step 13: Format and commit**

```bash
dart format lib/core/services/export lib/features/dive_import lib/features/universal_import/data/services/payload_merger.dart test/core/services/export/uddf test/features/universal_import/data/services/payload_merger_test.dart
git add lib/core/services/export/uddf/uddf_import_parsers.dart lib/core/services/export/uddf/uddf_full_import_service.dart lib/features/universal_import/data/services/payload_merger.dart lib/features/dive_import/data/services/uddf_entity_importer.dart test/core/services/export/uddf/uddf_full_import_service_test.dart test/features/universal_import/data/services/payload_merger_test.dart test/core/services/export/uddf/uddf_assemblies_round_trip_test.dart
git commit -m "feat(import): UDDF restores assembly templates and gear provenance (#1487)

Components ride on the parent item's map and gear links on the dive's,
so the restore and the import wizard both reach the entity importer
with them in place; the multi-file merger namespaces the nested refs."
```

---

### Task 7: The Components column in CSV and Excel

**Files:**
- Modify: `lib/features/equipment/domain/services/components_index.dart` (add `namesByParent`)
- Modify: `lib/core/services/export/csv/csv_export_service.dart` (`generateEquipmentCsvContent` L245, `exportEquipmentToCsv` L64, `saveEquipmentCsvToFile` L351)
- Modify: `lib/core/services/export/excel/excel_export_service.dart` (`_buildEquipmentSheet` L359, `exportToExcel` L32, `saveExcelToFile` L135)
- Modify: `lib/core/services/export/export_service.dart` (the CSV and Excel pass-throughs)
- Modify: `lib/features/settings/presentation/providers/export_providers.dart` (L233-241, L567-589, L673-695, L981-993)
- Test: `test/features/equipment/presentation/providers/components_index_test.dart` (existing; add a case)
- Test: `test/core/services/export/csv/csv_export_service_test.dart` and `test/core/services/export/excel/excel_export_service_test.dart` (existing; add a case each)

**Interfaces:**
- Produces: `Map<String, List<String>> ComponentsIndex.namesByParent(Map<String, EquipmentItem> itemsById)`; `generateEquipmentCsvContent(List<EquipmentItem> equipment, {Map<String, List<String>> componentNames = const {}})` with a `Components` column after `Attributes` listing names joined by `; `; the Excel sheet gains the same column after `Status`; `exportToExcel` and `saveExcelToFile` gain `Map<String, List<String>> componentNames = const {}`; the facade forwards; the providers compute the map from `EquipmentComponentRepository().getAllComponents()` and the equipment list.

- [ ] **Step 1: Write the failing tests**

Index test:

```dart
  test('namesByParent lists each assembly\'s parts by name in order', () {
    final index = ComponentsIndex.fromRows([edge('reg', 'first', order: 0), edge('reg', 'hose', order: 1)]);
    final names = index.namesByParent({
      'first': const EquipmentItem(id: 'first', name: 'First stage', type: EquipmentType.firstStage),
      'hose': const EquipmentItem(id: 'hose', name: 'Long hose', type: EquipmentType.hose),
    });
    expect(names, {'reg': ['First stage', 'Long hose']});
  });
```

CSV test (read its fixtures; it already has equipment cases around `generateEquipmentCsvContent`):

```dart
  test('equipment CSV lists an assembly\'s components (#1487)', () {
    final csv = service.generateEquipmentCsvContent(
      const [EquipmentItem(id: 'reg', name: 'Reg', type: EquipmentType.regulator)],
      componentNames: const {'reg': ['First stage', 'Long hose']},
    );
    final lines = csv.trim().split('\n');
    expect(lines.first.split(','), contains('Components'));
    expect(lines[1], contains('First stage; Long hose'));
  });
```

Excel test (read how it opens the workbook and finds the Equipment sheet; assert the header row contains `Components` and the data row contains the joined names).

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/equipment/presentation/providers/components_index_test.dart test/core/services/export/csv/csv_export_service_test.dart test/core/services/export/excel/excel_export_service_test.dart`
Expected: compile errors on `namesByParent` and `componentNames`.

- [ ] **Step 3: Implement**

Index:

```dart
  /// Each assembly's part names in template order, for the exports.
  Map<String, List<String>> namesByParent(Map<String, EquipmentItem> itemsById) => {
    for (final e in byParent.entries)
      e.key: [
        for (final edge in e.value)
          itemsById[edge.componentEquipmentId]?.name ?? edge.componentEquipmentId,
      ],
  };
```

(import `equipment_item.dart`). CSV: add `'Components',` to `headers` after `'Attributes'` and, in the row builder, `componentNames[item.id]?.join('; ') ?? ''` at the same position. Excel: add `'Components'` after `'Status'` in `headers` and `componentNames[item.id]?.join('; ') ?? ''` after `item.status.displayName` in `rowData`; thread `componentNames` through `_buildEquipmentSheet`, `exportToExcel` and `saveExcelToFile`. Facade: `generateEquipmentCsvContent`, `exportEquipmentToCsv`, `saveEquipmentCsvToFile`, `exportToExcel`, `saveExcelToFile` gain and forward `componentNames`. Providers: at each of the four sites compute

```dart
      final componentNames = ComponentsIndex.fromRows(
        await EquipmentComponentRepository().getAllComponents(),
      ).namesByParent({for (final e in equipment) e.id: e});
```

and pass `componentNames: componentNames`.

- [ ] **Step 4: Run the tests and the export provider suites**

Run: `flutter test test/features/equipment/presentation/providers/components_index_test.dart test/core/services/export/csv/csv_export_service_test.dart test/core/services/export/excel/excel_export_service_test.dart test/features/settings/presentation/providers/uddf_export_options_test.dart test/features/settings/presentation/providers/export_maintenance_log_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/core/services/export lib/features/equipment/domain/services/components_index.dart lib/features/settings/presentation/providers/export_providers.dart test/core/services/export test/features/equipment/presentation/providers/components_index_test.dart
git add lib/features/equipment/domain/services/components_index.dart lib/core/services/export/csv/csv_export_service.dart lib/core/services/export/excel/excel_export_service.dart lib/core/services/export/export_service.dart lib/features/settings/presentation/providers/export_providers.dart test/features/equipment/presentation/providers/components_index_test.dart test/core/services/export/csv/csv_export_service_test.dart test/core/services/export/excel/excel_export_service_test.dart
git commit -m "feat(export): equipment CSV and Excel list an assembly's components (#1487)"
```

---

### Task 8: Whole-project verification

- [ ] **Step 1: Codegen, format, analyze, l10n**

Rerun the codegen script (repository signatures changed in Tasks 2 and 6), then:

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter gen-l10n && git status --short lib/l10n/arb
```

Expected: no changes, `No issues found!`, empty status.

- [ ] **Step 2: Full suite, in the background**

Run `flutter test` with output redirected to a file (never piped through `grep`), in the background with a long timeout. Expected: 0 failures. Rerun any single flaky file alone before calling it a regression.

- [ ] **Step 3: Commit anything the checks touched and report**

Stage by path and commit as `style: format and analyzer fixes for assemblies PR 3` if needed. Report the commits, the test counts, and for the PR body: the dialog and replace action, the two UDDF sections and the round trip, the CSV and Excel column, and the known limit that the dives-only UDDF export carries no gear and so no provenance (issue #1718). That closes the three-PR delivery in the spec; the macOS smoke with screenshots is still pending for all three.
