# Equipment Transfer and Safe Profile Deletion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an owner transfer equipment to another diver profile, and keep gear other profiles use when its owner's profile is deleted (issue #2852).

**Architecture:** A pure function expands picked items into transfer units (same-owner connected components over the installed-on and assembly links). `EquipmentTransferService` is the one writer of `equipment.diver_id`: it rewrites the owner, fixes up shares by delete plus insert, moves linked dive computers and transmitters, and logs `transferred` events, all in one transaction. Profile deletion runs a new Step 0a that hands each kept unit to its heir through the same service before any other delete step. The UI adds "Transfer to..." on the item page and as a bulk action, one dialog, and a line in the delete-profile dialog and snackbar.

**Tech Stack:** Flutter, Riverpod, Drift (SQLite), flutter_test, ARB l10n (11 locales).

**Spec:** `docs/design/specs/2026-10-03-equipment-transfer-and-overlap-design.md` (sections "PR 3"). Read it before starting any task.

## Global Constraints

- Shown only when two or more diver profiles exist (`hasMultipleDiversProvider`), and transfer only to the owner (`canShareEquipment`, which excludes ownerless items).
- Shares sync insert-only: a share fix-up deletes and tombstones the old row and inserts a new id. Never update `equipment_shares.diver_id` in place.
- Every changed synced row is marked pending with `SyncRepository.markRecordPending(entityType:, recordId:, localUpdatedAt:)`; every deleted synced row is tombstoned with `logDeletions`. Entity types: `equipment`, `equipmentShares`, `equipmentOwnershipEvents`, `diveComputers`, `transmitters`.
- The share fix-up writes no `shared` or `unshared` events; each moved item gets exactly one `transferred` event.
- Past dives (`dive_equipment`, `dive_tanks`) are never touched by a transfer.
- No Undo for a transfer.
- New strings go into all 11 ARB files (ar, de, en, es, fr, he, hu, it, nl, pt, zh). ARB files are feature-grouped: insert next to a neighbouring key of the same group. Plural branches use `one{...{count}...}`, never `=1{1 ...}`.
- No em dashes or en dashes as punctuation in code, comments, strings or commits. No attribution lines in commits.
- `dart format .`, `flutter analyze`, the affected tests and `flutter test test/architecture/` before each commit that adds a `lib/` file.

## Refinements to the spec found while planning

1. **Units are same-owner connected components.** The spec says "walk up, then down". With assemblies that share a part (A contains P, B contains P, all one owner), walking up from A and down again misses B, and the transfer would split B from its part. The plan takes the connected component over both link types, restricted to the owner's items, which includes B. It is a superset of the spec's walk and equal to it for trees.
2. **Snackbar names.** Joining several heir names needs a locale-aware list format the app does not have. The delete snackbar names the heir when there is one ("handed to Anna") and says "handed to the profiles that use it" when there are several.
3. **Registry switch.** One switch, "Also move linked dive computers and transmitters", with the labels as its subtitle, instead of a sentence that embeds a list.

## Review Focus

1. **A profile deleted that owns gear shared with the profile also being kept as trips/sites heir.** The gear heir and the trips/sites heir are chosen by different rules and may differ; both handovers must run and neither may undo the other. Pinned in Task 5.
2. **Transfer of an item whose unit includes a retired item or an item in the old owner's equipment set.** Retired items move with their unit (they are still the owner's); set membership is left alone. Pinned in Task 2.
3. **A transmitter whose serial clashes with the target's.** It stays with the old owner, the result counts it, and on profile deletion it is deleted as before. Pinned in Tasks 3 and 5.
4. **Transferring to the profile that already has a share.** Its share row is removed with a tombstone (it becomes the owner) and no `unshared` event is written. Pinned in Task 2.
5. **The detail page after a transfer without "Keep access".** The item is no longer visible to the old owner, so the page leaves like after a delete instead of showing a stale or broken page. Pinned in Task 8.

---

## File Structure

| File | Responsibility |
| --- | --- |
| Create `lib/features/equipment/domain/services/transfer_unit.dart` | Pure unit expansion: `TransferUnitGraph`, `transferUnits()` |
| Create `lib/features/equipment/domain/services/transmitter_transfer_clash.dart` | Pure clash rule for a transmitter moving to a profile |
| Create `lib/features/equipment/data/services/equipment_transfer_service.dart` | Preview, transfer, in-transaction transfer, kept units and heirs |
| Create `lib/features/equipment/data/services/equipment_transfer_models.dart` | `EquipmentTransferPreview`, `EquipmentTransferResult`, `KeptUnit` |
| Create `lib/features/equipment/presentation/providers/equipment_transfer_providers.dart` | `equipmentTransferServiceProvider` |
| Create `lib/features/equipment/presentation/widgets/equipment_transfer_dialog.dart` | The dialog, returns an `EquipmentTransferRequest` |
| Create `lib/features/equipment/presentation/widgets/equipment_bulk_transfer.dart` | `transferEquipmentToProfile()`: dialog, service call, snackbar |
| Modify `lib/features/transmitters/data/repositories/transmitter_repository.dart` | Public `rescanDivesForTransmitters(ids)` |
| Modify `lib/features/equipment/presentation/pages/equipment_detail_page.dart` | Overflow "Transfer to..." for the owner |
| Modify `lib/features/equipment/presentation/widgets/equipment_list_content.dart` | Bulk "Transfer to..." |
| Modify `lib/features/divers/data/repositories/diver_repository.dart` | Step 0a, `DeleteDiverResult` fields, `keptEquipmentCount` passthrough |
| Modify `lib/features/divers/presentation/widgets/delete_diver_dialog.dart` | Optional kept-gear line |
| Modify `lib/features/settings/presentation/pages/diver_profile_hub_page.dart` | Pass the count to the dialog; snackbar sentence |
| Modify `lib/l10n/arb/app_*.arb` (11) | New strings |

---

### Task 1: Transfer unit expansion (pure)

**Files:**
- Create: `lib/features/equipment/domain/services/transfer_unit.dart`
- Test: `test/features/equipment/domain/services/transfer_unit_test.dart`

**Interfaces:**
- Produces:
  - `class TransferUnitGraph { const TransferUnitGraph({required Map<String, String?> ownerOf, required Map<String, String> hostOf, required List<({String parent, String component})> componentEdges}); }`
  - `List<Set<String>> transferUnits(TransferUnitGraph graph, Iterable<String> picked, {required String ownerId})`: disjoint units, each containing at least one picked item owned by `ownerId`; picked items not owned by `ownerId` (or unknown) appear in no unit. Units are ordered by first appearance in `picked`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/services/transfer_unit.dart';

void main() {
  TransferUnitGraph graph({
    Map<String, String?> owners = const {},
    Map<String, String> hosts = const {},
    List<({String parent, String component})> edges = const [],
  }) => TransferUnitGraph(ownerOf: owners, hostOf: hosts, componentEdges: edges);

  test('a lone item is its own unit', () {
    final g = graph(owners: {'light': 'bill'});
    expect(transferUnits(g, ['light'], ownerId: 'bill'), [
      {'light'},
    ]);
  });

  test('a picked installed part expands to its host and siblings', () {
    final g = graph(
      owners: {'ccr': 'bill', 'cell1': 'bill', 'cell2': 'bill'},
      hosts: {'cell1': 'ccr', 'cell2': 'ccr'},
    );
    expect(transferUnits(g, ['cell1'], ownerId: 'bill'), [
      {'ccr', 'cell1', 'cell2'},
    ]);
  });

  test('assembly components move with the assembly', () {
    final g = graph(
      owners: {'reg': 'bill', 'first': 'bill', 'second': 'bill'},
      edges: [
        (parent: 'reg', component: 'first'),
        (parent: 'reg', component: 'second'),
      ],
    );
    expect(transferUnits(g, ['reg'], ownerId: 'bill'), [
      {'reg', 'first', 'second'},
    ]);
  });

  test('a component another profile owns is a boundary', () {
    final g = graph(
      owners: {'reg': 'bill', 'octo': 'anna'},
      edges: [(parent: 'reg', component: 'octo')],
    );
    expect(transferUnits(g, ['reg'], ownerId: 'bill'), [
      {'reg'},
    ]);
  });

  test('an assembly another profile owns is not pulled in by its part', () {
    final g = graph(
      owners: {'kit': 'anna', 'mask': 'bill'},
      edges: [(parent: 'kit', component: 'mask')],
    );
    expect(transferUnits(g, ['mask'], ownerId: 'bill'), [
      {'mask'},
    ]);
  });

  test('two assemblies sharing a part form one unit', () {
    final g = graph(
      owners: {'a': 'bill', 'b': 'bill', 'p': 'bill'},
      edges: [
        (parent: 'a', component: 'p'),
        (parent: 'b', component: 'p'),
      ],
    );
    expect(transferUnits(g, ['a'], ownerId: 'bill'), [
      {'a', 'b', 'p'},
    ]);
  });

  test('items not owned by the owner are in no unit', () {
    final g = graph(owners: {'mask': 'anna', 'fin': 'bill'});
    expect(transferUnits(g, ['mask', 'fin', 'ghost'], ownerId: 'bill'), [
      {'fin'},
    ]);
  });

  test('two picked items of one unit give one unit', () {
    final g = graph(
      owners: {'ccr': 'bill', 'cell': 'bill', 'light': 'bill'},
      hosts: {'cell': 'ccr'},
    );
    expect(transferUnits(g, ['cell', 'ccr', 'light'], ownerId: 'bill'), [
      {'ccr', 'cell'},
      {'light'},
    ]);
  });

  test('a cycle in the links terminates', () {
    final g = graph(
      owners: {'a': 'bill', 'b': 'bill'},
      hosts: {'a': 'b', 'b': 'a'},
      edges: [(parent: 'a', component: 'b')],
    );
    expect(transferUnits(g, ['a'], ownerId: 'bill'), [
      {'a', 'b'},
    ]);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/equipment/domain/services/transfer_unit_test.dart`
Expected: FAIL, `transfer_unit.dart` does not exist.

- [ ] **Step 3: Implement**

```dart
/// Transfer units for equipment ownership changes (issue #2852).
///
/// A transfer never moves a lone installed part or a lone assembly
/// component: it moves the item's unit, every item of the same owner
/// connected to it through the installed-on link
/// (`equipment.parent_equipment_id`) or the assembly link
/// (`equipment_components`), in either direction. An item another profile
/// owns is a boundary: it is not moved and nothing is reached through it.
library;

/// The links and owners a unit is computed over.
class TransferUnitGraph {
  const TransferUnitGraph({
    required this.ownerOf,
    required this.hostOf,
    required this.componentEdges,
  });

  /// Owner by equipment id. An id missing here is unknown and never moves.
  final Map<String, String?> ownerOf;

  /// Host by installed item id (`parent_equipment_id`).
  final Map<String, String> hostOf;

  /// Assembly edges (`equipment_components`).
  final List<({String parent, String component})> componentEdges;
}

/// The disjoint units [picked] expands to for [ownerId], ordered by first
/// appearance in [picked]. Picked items [ownerId] does not own are in no
/// unit; the caller counts them as skipped.
List<Set<String>> transferUnits(
  TransferUnitGraph graph,
  Iterable<String> picked, {
  required String ownerId,
}) {
  final neighbours = <String, Set<String>>{};
  void link(String a, String b) {
    (neighbours[a] ??= {}).add(b);
    (neighbours[b] ??= {}).add(a);
  }

  graph.hostOf.forEach(link);
  for (final e in graph.componentEdges) {
    link(e.parent, e.component);
  }

  bool owned(String id) => graph.ownerOf[id] == ownerId;

  final units = <Set<String>>[];
  final seen = <String>{};
  for (final start in picked) {
    if (!owned(start) || seen.contains(start)) continue;
    final unit = <String>{};
    final queue = [start];
    while (queue.isNotEmpty) {
      final id = queue.removeLast();
      if (!owned(id) || !unit.add(id)) continue;
      queue.addAll(neighbours[id] ?? const <String>{});
    }
    seen.addAll(unit);
    units.add(unit);
  }
  return units;
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/equipment/domain/services/transfer_unit_test.dart`
Expected: PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/equipment/domain/services/transfer_unit.dart test/features/equipment/domain/services/transfer_unit_test.dart
git add lib/features/equipment/domain/services/transfer_unit.dart test/features/equipment/domain/services/transfer_unit_test.dart
git commit -m "feat(equipment): expand a transfer to the item's whole unit"
```

---

### Task 2: Transfer service core (owner, shares, events)

**Files:**
- Create: `lib/features/equipment/data/services/equipment_transfer_models.dart`
- Create: `lib/features/equipment/data/services/equipment_transfer_service.dart`
- Create: `lib/features/equipment/presentation/providers/equipment_transfer_providers.dart`
- Test: `test/features/equipment/data/services/equipment_transfer_service_test.dart`

**Interfaces:**
- Consumes: `TransferUnitGraph`, `transferUnits` (Task 1).
- Produces:
  - `class EquipmentTransferResult { const EquipmentTransferResult({int itemsMoved = 0, int skippedNotOwned = 0, int computersMoved = 0, int transmittersMoved = 0, int transmittersKept = 0}); EquipmentTransferResult operator +(EquipmentTransferResult other); }`
  - `class EquipmentTransferService` with:
    - `Future<EquipmentTransferResult> transfer({required List<String> equipmentIds, required String toDiverId, required String actingDiverId, bool keepAccess = true, bool moveRegistry = true})`
    - `Future<EquipmentTransferResult> transferUnitInTransaction({required Set<String> unit, required String fromDiverId, required String toDiverId, required bool keepAccess, required bool moveRegistry, required int now})`: no transaction of its own, no notify; returns `itemsMoved` and the registry counts (Task 3 fills those in).
    - `Future<TransferUnitGraph> loadGraph()`
  - `final equipmentTransferServiceProvider = Provider<EquipmentTransferService>((ref) => EquipmentTransferService());`

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';
import 'package:submersion/features/equipment/data/services/equipment_transfer_service.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late EquipmentTransferService service;

  Future<void> addDiver(String id) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(DiversCompanion.insert(id: id, name: id, createdAt: t, updatedAt: t));
  }

  Future<void> addItem(String id, String owner, {String? host, bool active = true}) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: id,
            name: id,
            type: 'other',
            createdAt: t,
            updatedAt: t,
            diverId: Value(owner),
            parentEquipmentId: Value(host),
            isActive: Value(active),
          ),
        );
  }

  Future<String?> ownerOf(String id) async =>
      (await (db.select(db.equipment)..where((t) => t.id.equals(id))).getSingle())
          .diverId;

  Future<Set<String>> pending(String entityType) async => {
    for (final r in await db
        .customSelect(
          'SELECT record_id FROM sync_records WHERE entity_type = ?',
          variables: [Variable<String>(entityType)],
        )
        .get())
      r.read<String>('record_id'),
  };

  Future<Set<String>> tombstones(String entityType) async => {
    for (final r in await db.select(db.deletionLog).get())
      if (r.entityType == entityType) r.recordId,
  };

  Future<List<EquipmentOwnershipEventRow>> events(String id) =>
      (db.select(db.equipmentOwnershipEvents)..where((t) => t.equipmentId.equals(id))).get();

  setUp(() async {
    db = await setUpTestDatabase();
    service = EquipmentTransferService();
    for (final d in ['bill', 'anna', 'tom']) {
      await addDiver(d);
    }
  });

  tearDown(tearDownTestDatabase);

  test('moves the whole unit and marks every item pending', () async {
    await addItem('ccr', 'bill');
    await addItem('cell', 'bill', host: 'ccr');
    final result = await service.transfer(
      equipmentIds: ['cell'],
      toDiverId: 'anna',
      actingDiverId: 'bill',
    );
    expect(result.itemsMoved, 2);
    expect(await ownerOf('ccr'), 'anna');
    expect(await ownerOf('cell'), 'anna');
    expect(await pending('equipment'), containsAll(['ccr', 'cell']));
  });

  test('writes one transferred event per item and no share events', () async {
    await addItem('light', 'bill');
    await service.transfer(equipmentIds: ['light'], toDiverId: 'anna', actingDiverId: 'bill');
    final rows = await events('light');
    expect(rows, hasLength(1));
    expect(rows.single.kind, 'transferred');
    expect(rows.single.fromDiverId, 'bill');
    expect(rows.single.toDiverId, 'anna');
    expect(await pending('equipmentOwnershipEvents'), {rows.single.id});
  });

  test('keepAccess adds a fresh share for the old owner', () async {
    await addItem('light', 'bill');
    await service.transfer(equipmentIds: ['light'], toDiverId: 'anna', actingDiverId: 'bill');
    final shares = await db.select(db.equipmentShares).get();
    expect(shares.map((s) => (s.equipmentId, s.diverId)), [('light', 'bill')]);
    expect(await pending('equipmentShares'), {shares.single.id});
  });

  test('without keepAccess the old owner gets no share', () async {
    await addItem('light', 'bill');
    await service.transfer(
      equipmentIds: ['light'],
      toDiverId: 'anna',
      actingDiverId: 'bill',
      keepAccess: false,
    );
    expect(await db.select(db.equipmentShares).get(), isEmpty);
  });

  test('the target share is deleted with a tombstone, other sharees stay', () async {
    await addItem('light', 'bill');
    await EquipmentShareRepository().shareMany(
      equipmentIds: ['light'],
      diverIds: ['anna', 'tom'],
      actingDiverId: 'bill',
    );
    final annaShare = (await (db.select(db.equipmentShares)
          ..where((t) => t.diverId.equals('anna')))
        .getSingle()).id;
    await service.transfer(
      equipmentIds: ['light'],
      toDiverId: 'anna',
      actingDiverId: 'bill',
      keepAccess: false,
    );
    final shares = await db.select(db.equipmentShares).get();
    expect(shares.map((s) => s.diverId), ['tom']);
    expect(await tombstones('equipmentShares'), contains(annaShare));
    final kinds = (await events('light')).map((e) => e.kind).toList();
    expect(kinds.where((k) => k == 'unshared'), isEmpty);
  });

  test('items the acting profile does not own are skipped', () async {
    await addItem('light', 'bill');
    await addItem('mask', 'tom');
    final result = await service.transfer(
      equipmentIds: ['light', 'mask'],
      toDiverId: 'anna',
      actingDiverId: 'bill',
    );
    expect(result.itemsMoved, 1);
    expect(result.skippedNotOwned, 1);
    expect(await ownerOf('mask'), 'tom');
  });

  test('a transfer to the current owner changes nothing', () async {
    await addItem('light', 'bill');
    final result = await service.transfer(
      equipmentIds: ['light'],
      toDiverId: 'bill',
      actingDiverId: 'bill',
    );
    expect(result.itemsMoved, 0);
    expect(await events('light'), isEmpty);
  });

  test('a retired item moves with its unit; dives and sets are untouched', () async {
    await addItem('ccr', 'bill');
    await addItem('oldcell', 'bill', host: 'ccr', active: false);
    final t = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.dives).insert(
      DivesCompanion.insert(id: 'd1', diverId: const Value('bill'), diveDateTime: t, createdAt: t, updatedAt: t),
    );
    await db.into(db.diveEquipment).insert(
      DiveEquipmentCompanion.insert(diveId: 'd1', equipmentId: 'ccr'),
    );
    await db.into(db.equipmentSets).insert(
      EquipmentSetsCompanion.insert(id: 's1', name: 'kit', createdAt: t, updatedAt: t, diverId: const Value('bill')),
    );
    await db.into(db.equipmentSetItems).insert(
      EquipmentSetItemsCompanion.insert(setId: 's1', equipmentId: 'ccr'),
    );
    await service.transfer(equipmentIds: ['ccr'], toDiverId: 'anna', actingDiverId: 'bill');
    expect(await ownerOf('oldcell'), 'anna');
    expect(await db.select(db.diveEquipment).get(), hasLength(1));
    expect(await db.select(db.equipmentSetItems).get(), hasLength(1));
  });

  test('a missing target rolls the whole transfer back', () async {
    await addItem('light', 'bill');
    await expectLater(
      service.transfer(equipmentIds: ['light'], toDiverId: 'ghost', actingDiverId: 'bill'),
      throwsA(anything),
    );
    expect(await ownerOf('light'), 'bill');
    expect(await events('light'), isEmpty);
    expect(await db.select(db.equipmentShares).get(), isEmpty);
  });
}
```

Before writing the set and dive inserts, check the generated companions' required fields (`EquipmentSetsCompanion.insert`, `EquipmentSetItemsCompanion.insert`) in `lib/core/database/tables/equipment_tables.dart` and adjust the named arguments to match; the assertions stay as written.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/equipment/data/services/equipment_transfer_service_test.dart`
Expected: FAIL, the service does not exist.

- [ ] **Step 3: Implement the models**

`lib/features/equipment/data/services/equipment_transfer_models.dart`:

```dart
/// Counts from one transfer, for the UI's result messages (issue #2852).
class EquipmentTransferResult {
  const EquipmentTransferResult({
    this.itemsMoved = 0,
    this.skippedNotOwned = 0,
    this.computersMoved = 0,
    this.transmittersMoved = 0,
    this.transmittersKept = 0,
  });

  final int itemsMoved;

  /// Picked items the acting profile does not own.
  final int skippedNotOwned;
  final int computersMoved;
  final int transmittersMoved;

  /// Transmitters left with the old owner because their serial or channel
  /// clashes with one the new owner already has.
  final int transmittersKept;

  EquipmentTransferResult operator +(EquipmentTransferResult other) =>
      EquipmentTransferResult(
        itemsMoved: itemsMoved + other.itemsMoved,
        skippedNotOwned: skippedNotOwned + other.skippedNotOwned,
        computersMoved: computersMoved + other.computersMoved,
        transmittersMoved: transmittersMoved + other.transmittersMoved,
        transmittersKept: transmittersKept + other.transmittersKept,
      );
}
```

(Task 3 adds the preview types and Task 4 `KeptUnit` to this file.)

- [ ] **Step 4: Implement the service core**

`lib/features/equipment/data/services/equipment_transfer_service.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';
import 'package:submersion/features/equipment/data/services/equipment_transfer_models.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_ownership_event.dart';
import 'package:submersion/features/equipment/domain/services/transfer_unit.dart';

export 'package:submersion/features/equipment/data/services/equipment_transfer_models.dart';

/// Changes equipment ownership between diver profiles (issue #2852). The
/// only writer of `equipment.diver_id` after creation, apart from diver
/// merge and sync apply. Profile deletion hands kept gear over through
/// [transferUnitInTransaction].
class EquipmentTransferService {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  static const _uuid = Uuid();

  /// Every item's owner and host and every assembly edge. Libraries hold a
  /// few hundred items, so one read beats walking the links query by query.
  Future<TransferUnitGraph> loadGraph() async {
    final items = await _db.select(_db.equipment).get();
    final edges = await _db.select(_db.equipmentComponents).get();
    return TransferUnitGraph(
      ownerOf: {for (final r in items) r.id: r.diverId},
      hostOf: {
        for (final r in items)
          if (r.parentEquipmentId case final host?) r.id: host,
      },
      componentEdges: [
        for (final e in edges)
          (parent: e.parentEquipmentId, component: e.componentEquipmentId),
      ],
    );
  }

  /// Transfers every unit [equipmentIds] expands to from [actingDiverId] to
  /// [toDiverId] in one transaction. Items [actingDiverId] does not own are
  /// skipped. A target that does not exist fails the foreign key and rolls
  /// the whole transfer back.
  Future<EquipmentTransferResult> transfer({
    required List<String> equipmentIds,
    required String toDiverId,
    required String actingDiverId,
    bool keepAccess = true,
    bool moveRegistry = true,
  }) async {
    if (toDiverId == actingDiverId) return const EquipmentTransferResult();
    final result = await _db.transaction(() async {
      final graph = await loadGraph();
      final picked = equipmentIds.toSet();
      final units = transferUnits(graph, picked, ownerId: actingDiverId);
      final covered = {for (final u in units) ...u};
      var total = EquipmentTransferResult(
        skippedNotOwned: picked.where((id) => !covered.contains(id)).length,
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final unit in units) {
        total += await transferUnitInTransaction(
          unit: unit,
          fromDiverId: actingDiverId,
          toDiverId: toDiverId,
          keepAccess: keepAccess,
          moveRegistry: moveRegistry,
          now: now,
        );
      }
      return total;
    });
    SyncEventBus.notifyLocalChange();
    return result;
  }

  /// Moves [unit] from [fromDiverId] to [toDiverId]. Runs inside the
  /// caller's transaction and notifies nobody.
  Future<EquipmentTransferResult> transferUnitInTransaction({
    required Set<String> unit,
    required String fromDiverId,
    required String toDiverId,
    required bool keepAccess,
    required bool moveRegistry,
    required int now,
  }) async {
    if (unit.isEmpty || fromDiverId == toDiverId) {
      return const EquipmentTransferResult();
    }
    final ids = unit.toList()..sort();
    for (final chunk in seriesIdChunks(ids)) {
      await (_db.update(_db.equipment)..where((t) => t.id.isIn(chunk))).write(
        EquipmentCompanion(diverId: Value(toDiverId), updatedAt: Value(now)),
      );
    }
    for (final id in ids) {
      await _markPending('equipment', id, now);
    }
    await _fixUpShares(ids, from: fromDiverId, to: toDiverId, keepAccess: keepAccess, now: now);
    final events = [
      for (final id in ids)
        EquipmentOwnershipEventsCompanion.insert(
          id: _uuid.v4(),
          equipmentId: id,
          kind: EquipmentOwnershipEventKind.transferred.name,
          fromDiverId: Value(fromDiverId),
          toDiverId: Value(toDiverId),
          occurredAt: now,
        ),
    ];
    await _db.batch((b) => b.insertAll(_db.equipmentOwnershipEvents, events));
    for (final e in events) {
      await _markPending(EquipmentShareRepository.eventsEntity, e.id.value, now);
    }
    return EquipmentTransferResult(itemsMoved: ids.length);
  }

  /// The new owner's share rows go (it owns the items now). The old owner
  /// gets a new share row when [keepAccess] is true. Shares apply
  /// insert-only on peers, so a row is never repointed in place.
  Future<void> _fixUpShares(
    List<String> ids, {
    required String from,
    required String to,
    required bool keepAccess,
    required int now,
  }) async {
    final targetShares = <String>[];
    for (final chunk in seriesIdChunks(ids)) {
      targetShares.addAll(
        await (_db.selectOnly(_db.equipmentShares)
              ..addColumns([_db.equipmentShares.id])
              ..where(
                _db.equipmentShares.equipmentId.isIn(chunk) &
                    _db.equipmentShares.diverId.equals(to),
              ))
            .map((r) => r.read(_db.equipmentShares.id)!)
            .get(),
      );
    }
    if (targetShares.isNotEmpty) {
      for (final chunk in seriesIdChunks(targetShares)) {
        await (_db.delete(_db.equipmentShares)..where((t) => t.id.isIn(chunk))).go();
      }
      await _syncRepository.logDeletions(
        entityType: EquipmentShareRepository.sharesEntity,
        recordIds: targetShares,
      );
    }
    if (!keepAccess) return;
    final added = [
      for (final id in ids)
        EquipmentSharesCompanion.insert(
          id: _uuid.v4(),
          equipmentId: id,
          diverId: from,
          createdAt: now,
        ),
    ];
    await _db.batch((b) => b.insertAll(_db.equipmentShares, added, mode: InsertMode.insertOrIgnore));
    for (final s in added) {
      await _markPending(EquipmentShareRepository.sharesEntity, s.id.value, now);
    }
  }

  Future<void> _markPending(String entityType, String id, int now) =>
      _syncRepository.markRecordPending(
        entityType: entityType,
        recordId: id,
        localUpdatedAt: now,
      );
}
```

Note on `insertOrIgnore`: the old owner cannot already hold a share on its own item (the share repository rejects self-shares), so nothing is ignored in practice; it only guards the unique index against a peer-synced oddity. If a row is ignored, its pending mark points at no row, which the sync export already tolerates for missing records; if the export does not tolerate it, select the ids that were actually inserted before marking.

`lib/features/equipment/presentation/providers/equipment_transfer_providers.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/services/equipment_transfer_service.dart';

final equipmentTransferServiceProvider = Provider<EquipmentTransferService>(
  (ref) => EquipmentTransferService(),
);
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/equipment/data/services/equipment_transfer_service_test.dart`
Expected: PASS (9 tests). If the missing-target test does not throw, foreign keys are off in the test database: check `setUpTestDatabase` and, if needed, verify the target exists at the start of `transfer` and throw `StateError('Unknown profile')` inside the transaction so the rollback assertion still holds.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/equipment test/features/equipment
flutter analyze lib/features/equipment test/features/equipment
flutter test test/architecture/
git add lib/features/equipment/data/services lib/features/equipment/presentation/providers/equipment_transfer_providers.dart test/features/equipment/data/services
git commit -m "feat(equipment): transfer equipment ownership between profiles"
```

---

### Task 3: Registry rows and preview

**Files:**
- Create: `lib/features/equipment/domain/services/transmitter_transfer_clash.dart`
- Modify: `lib/features/equipment/data/services/equipment_transfer_models.dart`
- Modify: `lib/features/equipment/data/services/equipment_transfer_service.dart`
- Modify: `lib/features/transmitters/data/repositories/transmitter_repository.dart`
- Test: `test/features/equipment/domain/services/transmitter_transfer_clash_test.dart`
- Test: `test/features/equipment/data/services/equipment_transfer_registry_test.dart`

**Interfaces:**
- Consumes: Task 2's service.
- Produces:
  - `typedef TransmitterKey = ({String id, String? serial, String? diveComputerId, int? channelIndex});`
  - `bool transmitterClashes(TransmitterKey moving, Iterable<TransmitterKey> targetOwned)`
  - In models: `class TransferRegistryRow { const TransferRegistryRow({required String id, required String label, bool clashes = false}); }` and `class EquipmentTransferPreview { const EquipmentTransferPreview({required List<String> unitIds, required int skippedNotOwned, required List<TransferRegistryRow> computers, required List<TransferRegistryRow> transmitters}); bool get hasRegistry; }`
  - Service: `Future<EquipmentTransferPreview> preview({required List<String> equipmentIds, required String actingDiverId, String? toDiverId})`
  - `TransmitterRepository.rescanDivesForTransmitters(Iterable<String> transmitterIds)`
  - `EquipmentTransferService.transfer` gains the registry move; `transferUnitInTransaction` returns `computersMoved`, `transmittersMoved`, `transmittersKept`, and records moved transmitter ids for the post-commit rescan.

- [ ] **Step 1: Write the failing clash tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/services/transmitter_transfer_clash.dart';

void main() {
  TransmitterKey key(String id, {String? serial, String? computer, int? channel}) =>
      (id: id, serial: serial, diveComputerId: computer, channelIndex: channel);

  test('same serial in another form clashes', () {
    expect(transmitterClashes(key('m', serial: '12-34ab'), [key('t', serial: '1234AB')]), isTrue);
  });

  test('different serials do not clash', () {
    expect(transmitterClashes(key('m', serial: 'A'), [key('t', serial: 'B')]), isFalse);
  });

  test('same computer and channel clash', () {
    expect(
      transmitterClashes(
        key('m', computer: 'c1', channel: 2),
        [key('t', computer: 'c1', channel: 2)],
      ),
      isTrue,
    );
  });

  test('no serial and no channel never clash', () {
    expect(transmitterClashes(key('m'), [key('t')]), isFalse);
  });

  test('a row never clashes with itself', () {
    expect(transmitterClashes(key('m', serial: 'A'), [key('m', serial: 'A')]), isFalse);
  });
}
```

Check what `normalizeTransmitterSerial` (`lib/features/dive_log/domain/services/transmitter_serial.dart`) does with `'12-34ab'` before relying on the first test's input; pick two spellings it maps to the same value.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/equipment/domain/services/transmitter_transfer_clash_test.dart`
Expected: FAIL, file missing.

- [ ] **Step 3: Implement the clash rule**

```dart
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';

/// A transmitter as the per-profile uniqueness rule sees it.
typedef TransmitterKey = ({
  String id,
  String? serial,
  String? diveComputerId,
  int? channelIndex,
});

/// Whether [moving] would break the new owner's transmitter uniqueness: the
/// same serial in canonical form, or the same computer and channel. The
/// same rule as `TransmitterRepository._checkConflicts` (issue #2852).
bool transmitterClashes(
  TransmitterKey moving,
  Iterable<TransmitterKey> targetOwned,
) {
  final serial = normalizeTransmitterSerial(moving.serial);
  final hasChannel =
      moving.diveComputerId != null && moving.channelIndex != null;
  for (final other in targetOwned) {
    if (other.id == moving.id) continue;
    if (serial != null && normalizeTransmitterSerial(other.serial) == serial) {
      return true;
    }
    if (hasChannel &&
        other.diveComputerId == moving.diveComputerId &&
        other.channelIndex == moving.channelIndex) {
      return true;
    }
  }
  return false;
}
```

- [ ] **Step 4: Run the clash tests to verify they pass**

Run: `flutter test test/features/equipment/domain/services/transmitter_transfer_clash_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing registry and preview tests**

`test/features/equipment/data/services/equipment_transfer_registry_test.dart`, with the same `setUp`, `addDiver`, `addItem` and `pending` helpers as Task 2's test, plus:

```dart
  Future<void> addComputer(String id, String owner, {String? gear}) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.diveComputers).insert(
      DiveComputersCompanion.insert(
        id: id,
        name: id,
        createdAt: t,
        updatedAt: t,
        diverId: Value(owner),
        equipmentId: Value(gear),
      ),
    );
  }

  Future<void> addTransmitter(
    String id,
    String owner, {
    String? serial,
    String? cylinder,
    String? item,
  }) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.transmitters).insert(
      TransmittersCompanion.insert(
        id: id,
        label: id,
        tankRole: 'backGas',
        createdAt: t,
        updatedAt: t,
        diverId: Value(owner),
        transmitterSerial: Value(serial),
        equipmentId: Value(cylinder),
        transmitterEquipmentId: Value(item),
      ),
    );
  }

  Future<String?> computerOwner(String id) async =>
      (await (db.select(db.diveComputers)..where((t) => t.id.equals(id))).getSingle()).diverId;
  Future<String?> transmitterOwner(String id) async =>
      (await (db.select(db.transmitters)..where((t) => t.id.equals(id))).getSingle()).diverId;

  test('moves a linked dive computer and transmitters', () async {
    await addItem('perdix', 'bill');
    await addItem('tank', 'bill');
    await addComputer('c1', 'bill', gear: 'perdix');
    await addTransmitter('tx1', 'bill', serial: 'A1', cylinder: 'tank');
    final result = await service.transfer(
      equipmentIds: ['perdix', 'tank'],
      toDiverId: 'anna',
      actingDiverId: 'bill',
    );
    expect(result.computersMoved, 1);
    expect(result.transmittersMoved, 1);
    expect(await computerOwner('c1'), 'anna');
    expect(await transmitterOwner('tx1'), 'anna');
    expect(await pending('diveComputers'), {'c1'});
    expect(await pending('transmitters'), {'tx1'});
  });

  test('moveRegistry false leaves registry rows with the old owner', () async {
    await addItem('perdix', 'bill');
    await addComputer('c1', 'bill', gear: 'perdix');
    await service.transfer(
      equipmentIds: ['perdix'],
      toDiverId: 'anna',
      actingDiverId: 'bill',
      moveRegistry: false,
    );
    expect(await computerOwner('c1'), 'bill');
  });

  test('a clashing transmitter stays and is counted', () async {
    await addItem('tank', 'bill');
    await addTransmitter('tx1', 'bill', serial: 'A1', cylinder: 'tank');
    await addTransmitter('tx2', 'anna', serial: 'A1');
    final result = await service.transfer(
      equipmentIds: ['tank'],
      toDiverId: 'anna',
      actingDiverId: 'bill',
    );
    expect(result.transmittersKept, 1);
    expect(await transmitterOwner('tx1'), 'bill');
  });

  test('preview lists the unit, registry rows and clashes', () async {
    await addItem('ccr', 'bill');
    await addItem('cell', 'bill', host: 'ccr');
    await addItem('mask', 'tom');
    await addComputer('c1', 'bill', gear: 'ccr');
    await addTransmitter('tx1', 'bill', serial: 'A1', item: 'cell');
    await addTransmitter('tx2', 'anna', serial: 'A1');
    final p = await service.preview(
      equipmentIds: ['cell', 'mask'],
      actingDiverId: 'bill',
      toDiverId: 'anna',
    );
    expect(p.unitIds.toSet(), {'ccr', 'cell'});
    expect(p.skippedNotOwned, 1);
    expect(p.computers.map((c) => c.id), ['c1']);
    expect(p.transmitters.single.id, 'tx1');
    expect(p.transmitters.single.clashes, isTrue);
  });

  test('preview without a target reports no clashes', () async {
    await addItem('tank', 'bill');
    await addTransmitter('tx1', 'bill', serial: 'A1', cylinder: 'tank');
    await addTransmitter('tx2', 'anna', serial: 'A1');
    final p = await service.preview(equipmentIds: ['tank'], actingDiverId: 'bill');
    expect(p.transmitters.single.clashes, isFalse);
  });
```

Check `TransmittersCompanion.insert` and `DiveComputersCompanion.insert` required fields against `cylinder_tables.dart` and `dive_profile_tables.dart` and adjust argument names; assertions stay.

- [ ] **Step 6: Run to verify failure**

Run: `flutter test test/features/equipment/data/services/equipment_transfer_registry_test.dart`
Expected: FAIL (no `preview`, registry counts are 0).

- [ ] **Step 7: Implement the preview types, the registry move and the rescan hook**

Append to `equipment_transfer_models.dart`:

```dart
/// A dive computer or transmitter linked to a unit, for the dialog.
class TransferRegistryRow {
  const TransferRegistryRow({
    required this.id,
    required this.label,
    this.clashes = false,
  });

  final String id;
  final String label;

  /// A transmitter that clashes with one the chosen target owns, so it
  /// stays with the old owner.
  final bool clashes;
}

/// What a transfer would do, for the dialog before it is confirmed.
class EquipmentTransferPreview {
  const EquipmentTransferPreview({
    required this.unitIds,
    required this.skippedNotOwned,
    required this.computers,
    required this.transmitters,
  });

  /// Every item that would move, picked ones included.
  final List<String> unitIds;
  final int skippedNotOwned;
  final List<TransferRegistryRow> computers;
  final List<TransferRegistryRow> transmitters;

  bool get hasRegistry => computers.isNotEmpty || transmitters.isNotEmpty;
}
```

In the service, add a field `final List<String> _movedTransmitters = [];` reset at the start of `transfer`, and these members:

```dart
  Future<EquipmentTransferPreview> preview({
    required List<String> equipmentIds,
    required String actingDiverId,
    String? toDiverId,
  }) async {
    final graph = await loadGraph();
    final picked = equipmentIds.toSet();
    final units = transferUnits(graph, picked, ownerId: actingDiverId);
    final unitIds = {for (final u in units) ...u}.toList()..sort();
    final computers = await _linkedComputers(unitIds, actingDiverId);
    final transmitters = await _linkedTransmitters(unitIds, actingDiverId);
    final targetKeys = toDiverId == null
        ? const <TransmitterKey>[]
        : await _transmitterKeysOf(toDiverId);
    return EquipmentTransferPreview(
      unitIds: unitIds,
      skippedNotOwned: picked.where((id) => !unitIds.contains(id)).length,
      computers: [
        for (final c in computers) TransferRegistryRow(id: c.id, label: c.name),
      ],
      transmitters: [
        for (final t in transmitters)
          TransferRegistryRow(
            id: t.id,
            label: t.label,
            clashes: transmitterClashes(_keyOf(t), targetKeys),
          ),
      ],
    );
  }

  Future<List<DiveComputer>> _linkedComputers(List<String> unitIds, String owner) async => [
    for (final chunk in seriesIdChunks(unitIds))
      ...await (_db.select(_db.diveComputers)
            ..where((t) => t.equipmentId.isIn(chunk) & t.diverId.equals(owner)))
          .get(),
  ];

  Future<List<TransmitterRow>> _linkedTransmitters(List<String> unitIds, String owner) async {
    final byId = <String, TransmitterRow>{};
    for (final chunk in seriesIdChunks(unitIds)) {
      for (final r in await (_db.select(_db.transmitters)
            ..where(
              (t) =>
                  t.diverId.equals(owner) &
                  (t.equipmentId.isIn(chunk) | t.transmitterEquipmentId.isIn(chunk)),
            ))
          .get()) {
        byId[r.id] = r;
      }
    }
    return byId.values.toList();
  }

  Future<List<TransmitterKey>> _transmitterKeysOf(String diverId) async => [
    for (final r in await (_db.select(_db.transmitters)
          ..where((t) => t.diverId.equals(diverId)))
        .get())
      _keyOf(r),
  ];

  TransmitterKey _keyOf(TransmitterRow r) => (
    id: r.id,
    serial: r.transmitterSerial,
    diveComputerId: r.diveComputerId,
    channelIndex: r.channelIndex,
  );

  /// Moves the unit's dive computers and transmitters, leaving a
  /// transmitter that clashes with the target's.
  Future<EquipmentTransferResult> _moveRegistry(
    List<String> unitIds, {
    required String from,
    required String to,
    required int now,
  }) async {
    final computers = await _linkedComputers(unitIds, from);
    for (final c in computers) {
      await (_db.update(_db.diveComputers)..where((t) => t.id.equals(c.id))).write(
        DiveComputersCompanion(diverId: Value(to), updatedAt: Value(now)),
      );
      await _markPending('diveComputers', c.id, now);
    }
    final targetKeys = await _transmitterKeysOf(to);
    var moved = 0;
    var kept = 0;
    for (final t in await _linkedTransmitters(unitIds, from)) {
      final key = _keyOf(t);
      if (transmitterClashes(key, targetKeys)) {
        kept++;
        continue;
      }
      await (_db.update(_db.transmitters)..where((r) => r.id.equals(t.id))).write(
        TransmittersCompanion(diverId: Value(to), updatedAt: Value(now)),
      );
      await _markPending('transmitters', t.id, now);
      targetKeys.add(key);
      _movedTransmitters.add(t.id);
      moved++;
    }
    return EquipmentTransferResult(
      computersMoved: computers.length,
      transmittersMoved: moved,
      transmittersKept: kept,
    );
  }
```

`_transmitterKeysOf` must return a growable list (it does: a list literal). In `transferUnitInTransaction`, before the final `return`, add:

```dart
    final registry = moveRegistry
        ? await _moveRegistry(ids, from: fromDiverId, to: toDiverId, now: now)
        : const EquipmentTransferResult();
    return EquipmentTransferResult(itemsMoved: ids.length) + registry;
```

At the start of `transfer`, `_movedTransmitters.clear();`. After `SyncEventBus.notifyLocalChange();` in `transfer`:

```dart
    if (_movedTransmitters.isNotEmpty) {
      await TransmitterRepository().rescanDivesForTransmitters(_movedTransmitters);
    }
```

Add `takeMovedTransmitters()` for the deletion path (Task 5), which returns and clears the list:

```dart
  /// Transmitters moved since the last call, for a caller that ran
  /// [transferUnitInTransaction] itself and rescans after its commit.
  List<String> takeMovedTransmitters() {
    final ids = List<String>.of(_movedTransmitters);
    _movedTransmitters.clear();
    return ids;
  }
```

In `TransmitterRepository`:

```dart
  /// Queues a rescan of the dives each of [transmitterIds] matches, after
  /// a change of owner (issue #2852): which profile's registry knows the
  /// serial decides the unknown-transmitter finding.
  Future<void> rescanDivesForTransmitters(Iterable<String> transmitterIds) async {
    for (final id in transmitterIds.toSet()) {
      final t = await getById(id);
      if (t != null) await _rescanAffectedDives(t);
    }
  }
```

- [ ] **Step 8: Run all transfer tests**

Run: `flutter test test/features/equipment/data/services/ test/features/equipment/domain/services/transmitter_transfer_clash_test.dart test/features/transmitters/`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
dart format lib/features/equipment lib/features/transmitters test/features/equipment
flutter analyze lib/features/equipment lib/features/transmitters test/features/equipment
flutter test test/architecture/
git add lib/features/equipment lib/features/transmitters test/features/equipment
git commit -m "feat(equipment): move linked computers and transmitters with transferred gear"
```

---

### Task 4: Kept units and heirs for profile deletion

**Files:**
- Modify: `lib/features/equipment/data/services/equipment_transfer_models.dart`
- Modify: `lib/features/equipment/data/services/equipment_transfer_service.dart`
- Test: `test/features/equipment/data/services/equipment_transfer_kept_units_test.dart`

**Interfaces:**
- Produces:
  - `class KeptUnit { const KeptUnit({required Set<String> unit, required String heirId}); }`
  - `Future<List<KeptUnit>> keptUnitsForDiver(String diverId)`: every unit of `diverId`'s gear that another profile needs, with its heir.
  - `Future<int> keptEquipmentCount(String diverId)`: the number of items in those units.

- [ ] **Step 1: Write the failing tests**

Same helpers as Task 2's test, plus `addDive(String id, String owner, int entryMs)` (inserting `DivesCompanion.insert(id:, diverId: Value(owner), diveDateTime: entryMs, createdAt:, updatedAt:, entryTime: Value(entryMs))`) and `link(String dive, String item)` (inserting `DiveEquipmentCompanion.insert`).

```dart
  test('a shared item goes to its earliest sharee', () async {
    await addItem('light', 'bill');
    final shares = EquipmentShareRepository();
    await shares.shareMany(equipmentIds: ['light'], diverIds: ['tom'], actingDiverId: 'bill');
    await db.update(db.equipmentShares).write(const EquipmentSharesCompanion(createdAt: Value(1)));
    await shares.shareMany(equipmentIds: ['light'], diverIds: ['anna'], actingDiverId: 'bill');
    final kept = await service.keptUnitsForDiver('bill');
    expect(kept.single.unit, {'light'});
    expect(kept.single.heirId, 'tom');
  });

  test('an unshared item on another profile dive goes to the latest such dive', () async {
    await addItem('reg', 'bill');
    await addDive('d1', 'anna', 1000);
    await addDive('d2', 'tom', 2000);
    await addDive('d3', 'bill', 3000);
    await link('d1', 'reg');
    await link('d2', 'reg');
    await link('d3', 'reg');
    final kept = await service.keptUnitsForDiver('bill');
    expect(kept.single.heirId, 'tom');
  });

  test('a cylinder or regulator on another profile tank counts', () async {
    await addItem('tank', 'bill');
    await addItem('reg', 'bill');
    await addDive('d1', 'anna', 1000);
    await db.into(db.diveTanks).insert(
      DiveTanksCompanion.insert(
        id: 'dt1',
        diveId: 'd1',
        equipmentId: const Value('tank'),
        regulatorEquipmentId: const Value('reg'),
      ),
    );
    final kept = await service.keptUnitsForDiver('bill');
    expect({for (final k in kept) ...k.unit}, {'tank', 'reg'});
    expect(kept.every((k) => k.heirId == 'anna'), isTrue);
  });

  test('the whole unit is kept when one of its items is needed', () async {
    await addItem('ccr', 'bill');
    await addItem('cell', 'bill', host: 'ccr');
    await addDive('d1', 'anna', 1000);
    await link('d1', 'cell');
    final kept = await service.keptUnitsForDiver('bill');
    expect(kept.single.unit, {'ccr', 'cell'});
    expect(await service.keptEquipmentCount('bill'), 2);
  });

  test('unused, unshared gear and gear only on own dives is not kept', () async {
    await addItem('spare', 'bill');
    await addItem('fins', 'bill');
    await addDive('d1', 'bill', 1000);
    await link('d1', 'fins');
    expect(await service.keptUnitsForDiver('bill'), isEmpty);
    expect(await service.keptEquipmentCount('bill'), 0);
  });
```

Check `DiveTanksCompanion.insert`'s regulator column name (`regulatorEquipmentId`) in `dive_tables.dart`.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/equipment/data/services/equipment_transfer_kept_units_test.dart`
Expected: FAIL, no `keptUnitsForDiver`.

- [ ] **Step 3: Implement**

Append to models:

```dart
/// A unit of a deleted profile's gear another profile needs, and who gets
/// it (issue #2852).
class KeptUnit {
  const KeptUnit({required this.unit, required this.heirId});

  final Set<String> unit;
  final String heirId;
}
```

In the service:

```dart
  /// The units of [diverId]'s gear another profile needs, each with its
  /// heir: the profile holding the unit's earliest share, else the owner of
  /// the most recent other-profile dive that uses any item of the unit. A
  /// unit with neither is not kept. Read-only, safe inside a transaction.
  Future<List<KeptUnit>> keptUnitsForDiver(String diverId) async {
    final graph = await loadGraph();
    final owned = [
      for (final e in graph.ownerOf.entries)
        if (e.value == diverId) e.key,
    ]..sort();
    final kept = <KeptUnit>[];
    for (final unit in transferUnits(graph, owned, ownerId: diverId)) {
      final heir = await _heirFor(unit.toList(), diverId);
      if (heir != null) kept.add(KeptUnit(unit: unit, heirId: heir));
    }
    return kept;
  }

  Future<int> keptEquipmentCount(String diverId) async => [
    for (final k in await keptUnitsForDiver(diverId)) k.unit.length,
  ].fold<int>(0, (a, b) => a + b);

  Future<String?> _heirFor(List<String> unit, String deleted) async {
    final marks = List.filled(unit.length, '?').join(', ');
    final vars = [for (final id in unit) Variable.withString(id)];
    final share = await _db.customSelect(
      'SELECT diver_id FROM equipment_shares '
      'WHERE equipment_id IN ($marks) AND diver_id != ? '
      'ORDER BY created_at ASC, id ASC LIMIT 1',
      variables: [...vars, Variable.withString(deleted)],
    ).getSingleOrNull();
    if (share != null) return share.read<String>('diver_id');
    final dive = await _db.customSelect(
      'SELECT d.diver_id FROM dives d '
      'WHERE d.diver_id IS NOT NULL AND d.diver_id != ? AND d.id IN ('
      '  SELECT dive_id FROM dive_equipment WHERE equipment_id IN ($marks) '
      '  UNION SELECT dive_id FROM dive_tanks WHERE equipment_id IN ($marks) '
      '  UNION SELECT dive_id FROM dive_tanks '
      '    WHERE regulator_equipment_id IN ($marks)) '
      'ORDER BY COALESCE(d.entry_time, d.dive_date_time) DESC, d.id ASC '
      'LIMIT 1',
      variables: [Variable.withString(deleted), ...vars, ...vars, ...vars],
    ).getSingleOrNull();
    return dive?.read<String>('diver_id');
  }
```

A unit larger than SQLite's variable limit (999 on old builds, 32766 on current) is not a realistic library; if `seriesIdChunks` documents a smaller limit, assert `unit.length * 3 + 1` stays under it and fall back to querying per chunk.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/equipment/data/services/equipment_transfer_kept_units_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/equipment test/features/equipment
flutter analyze lib/features/equipment test/features/equipment
git add lib/features/equipment/data/services test/features/equipment/data/services
git commit -m "feat(equipment): find a deleted profile's gear others need and who gets it"
```

---

### Task 5: Hand kept gear over when a profile is deleted

**Files:**
- Modify: `lib/features/divers/data/repositories/diver_repository.dart` (class `DeleteDiverResult` near line 38; `deleteDiverWithReassignment` near line 468, Step 0 near line 497)
- Test: `test/features/divers/data/repositories/diver_delete_keeps_equipment_test.dart`

**Interfaces:**
- Consumes: `keptUnitsForDiver`, `transferUnitInTransaction`, `takeMovedTransmitters` (Tasks 2 to 4).
- Produces:
  - `DeleteDiverResult` gains `final int keptEquipmentCount;` (default 0), `final List<String> keptEquipmentHeirNames;` (default `const []`), and `bool get hasKeptEquipment => keptEquipmentCount > 0;`.
  - `DiverRepository({..., EquipmentTransferService? equipmentTransferService})`.
  - `Future<int> keptEquipmentCount(String diverId)` on `DiverRepository`, delegating to the service.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  Future<void> addDiver(String id, {bool isDefault = false}) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.divers).insert(
      DiversCompanion.insert(id: id, name: id, createdAt: t, updatedAt: t, isDefault: Value(isDefault)),
    );
  }

  Future<void> addItem(String id, String owner, {String? host}) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.equipment).insert(
      EquipmentCompanion.insert(
        id: id, name: id, type: 'other', createdAt: t, updatedAt: t,
        diverId: Value(owner), parentEquipmentId: Value(host),
      ),
    );
  }

  Future<void> addDive(String id, String owner, int at) async {
    await db.into(db.dives).insert(
      DivesCompanion.insert(id: id, diverId: Value(owner), diveDateTime: at, createdAt: at, updatedAt: at),
    );
  }

  Future<String?> ownerOf(String id) async =>
      (await (db.select(db.equipment)..where((t) => t.id.equals(id))).getSingleOrNull())?.diverId;

  setUp(() async {
    db = await setUpTestDatabase();
    await addDiver('bill');
    await addDiver('anna', isDefault: true);
    await addDiver('tom');
  });

  tearDown(tearDownTestDatabase);

  test('shared gear survives and lands on the sharee; others keep access', () async {
    await addItem('light', 'bill');
    final shares = EquipmentShareRepository();
    await shares.shareMany(equipmentIds: ['light'], diverIds: ['tom'], actingDiverId: 'bill');
    await db.update(db.equipmentShares).write(const EquipmentSharesCompanion(createdAt: Value(1)));
    await shares.shareMany(equipmentIds: ['light'], diverIds: ['anna'], actingDiverId: 'bill');
    final result = await DiverRepository().deleteDiverWithReassignment('bill');
    expect(await ownerOf('light'), 'tom');
    final left = await db.select(db.equipmentShares).get();
    expect(left.map((s) => s.diverId), ['anna']);
    expect(result.keptEquipmentCount, 1);
    expect(result.keptEquipmentHeirNames, ['tom']);
  });

  test('gear on another profile dive survives and stays on that dive', () async {
    await addItem('reg', 'bill');
    await addDive('d1', 'tom', 1000);
    await db.into(db.diveEquipment).insert(DiveEquipmentCompanion.insert(diveId: 'd1', equipmentId: 'reg'));
    await DiverRepository().deleteDiverWithReassignment('bill');
    expect(await ownerOf('reg'), 'tom');
    expect(await db.select(db.diveEquipment).get(), hasLength(1));
  });

  test('unused, unshared gear is still deleted', () async {
    await addItem('spare', 'bill');
    final result = await DiverRepository().deleteDiverWithReassignment('bill');
    expect(await ownerOf('spare'), isNull);
    expect(result.hasKeptEquipment, isFalse);
  });

  test('a moved dive computer keeps its links on other profiles dives', () async {
    await addItem('perdix', 'bill');
    await addDive('d1', 'tom', 1000);
    await db.into(db.diveEquipment).insert(DiveEquipmentCompanion.insert(diveId: 'd1', equipmentId: 'perdix'));
    final t = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.diveComputers).insert(
      DiveComputersCompanion.insert(
        id: 'c1', name: 'c1', createdAt: t, updatedAt: t,
        diverId: const Value('bill'), equipmentId: const Value('perdix'),
      ),
    );
    await (db.update(db.dives)..where((d) => d.id.equals('d1'))).write(
      const DivesCompanion(computerId: Value('c1')),
    );
    await DiverRepository().deleteDiverWithReassignment('bill');
    final c = await (db.select(db.diveComputers)..where((r) => r.id.equals('c1'))).getSingleOrNull();
    expect(c?.diverId, 'tom');
    final d = await (db.select(db.dives)..where((r) => r.id.equals('d1'))).getSingle();
    expect(d.computerId, 'c1');
  });

  test('a clashing transmitter is deleted as before', () async {
    await addItem('tank', 'bill');
    await addDive('d1', 'tom', 1000);
    await db.into(db.diveTanks).insert(
      DiveTanksCompanion.insert(id: 'dt1', diveId: 'd1', equipmentId: const Value('tank')),
    );
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final (id, owner) in [('tx1', 'bill'), ('tx2', 'tom')]) {
      await db.into(db.transmitters).insert(
        TransmittersCompanion.insert(
          id: id, label: id, tankRole: 'backGas', createdAt: t, updatedAt: t,
          diverId: Value(owner), transmitterSerial: const Value('A1'),
          equipmentId: Value(id == 'tx1' ? 'tank' : null),
        ),
      );
    }
    await DiverRepository().deleteDiverWithReassignment('bill');
    final ids = (await db.select(db.transmitters).get()).map((r) => r.id);
    expect(ids, ['tx2']);
    expect(await ownerOf('tank'), 'tom');
  });

  test('trips and sites still go to the default profile alongside the gear handover', () async {
    await addItem('light', 'bill');
    await EquipmentShareRepository().shareMany(equipmentIds: ['light'], diverIds: ['tom'], actingDiverId: 'bill');
    final t = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.trips).insert(
      TripsCompanion.insert(
        id: 'trip1', name: 'trip', startDate: t, endDate: t, createdAt: t, updatedAt: t,
        diverId: const Value('bill'), isShared: const Value(true),
      ),
    );
    final result = await DiverRepository().deleteDiverWithReassignment('bill');
    expect(result.reassignedToDiverId, 'anna');
    expect(result.reassignedTripsCount, 1);
    expect(await ownerOf('light'), 'tom');
  });

  test('events read a deleted profile afterwards', () async {
    await addItem('light', 'bill');
    await EquipmentShareRepository().shareMany(equipmentIds: ['light'], diverIds: ['tom'], actingDiverId: 'bill');
    await DiverRepository().deleteDiverWithReassignment('bill');
    final transferred = await (db.select(db.equipmentOwnershipEvents)
          ..where((e) => e.kind.equals('transferred')))
        .getSingle();
    expect(transferred.fromDiverId, isNull);
    expect(transferred.toDiverId, 'tom');
  });
```

Check `TripsCompanion.insert` required fields in `lib/core/database/tables/trip_tables.dart` and adjust names. Close `main()` with `}`.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/divers/data/repositories/diver_delete_keeps_equipment_test.dart`
Expected: FAIL (gear deleted, result has no kept fields).

- [ ] **Step 3: Implement**

`DeleteDiverResult`:

```dart
class DeleteDiverResult {
  final int reassignedTripsCount;
  final int reassignedSitesCount;
  final String? reassignedToDiverId;
  final String? reassignedToDiverName;

  /// Items of the deleted profile's gear other profiles needed, handed to
  /// them instead of deleted (issue #2852).
  final int keptEquipmentCount;

  /// The profiles that received kept gear, in handover order, no repeats.
  final List<String> keptEquipmentHeirNames;

  const DeleteDiverResult({
    required this.reassignedTripsCount,
    required this.reassignedSitesCount,
    this.reassignedToDiverId,
    this.reassignedToDiverName,
    this.keptEquipmentCount = 0,
    this.keptEquipmentHeirNames = const [],
  });

  bool get hasReassignments =>
      reassignedTripsCount > 0 || reassignedSitesCount > 0;

  bool get hasKeptEquipment => keptEquipmentCount > 0;
}
```

Constructor: add `EquipmentTransferService? equipmentTransferService` and a field `final EquipmentTransferService _equipmentTransfer;` initialised `equipmentTransferService ?? EquipmentTransferService()`, following how `_importedFileReclaimer` is initialised.

In `deleteDiverWithReassignment`, declare beside `reassignedTrips`:

```dart
      var keptEquipment = 0;
      final keptHeirIds = <String>[];
```

As the first statement inside `await _db.transaction(() async {`, before `// Step 0`:

```dart
        // Step 0a: Hand over the gear other profiles need (issue #2852),
        // before anything below selects this diver's rows: every later step
        // matches `diver_id = id`, so a moved item, dive computer or
        // transmitter is out of their reach, and the media plan keeps the
        // moved gear's media.
        final handoverAt = DateTime.now().millisecondsSinceEpoch;
        for (final kept in await _equipmentTransfer.keptUnitsForDiver(id)) {
          final moved = await _equipmentTransfer.transferUnitInTransaction(
            unit: kept.unit,
            fromDiverId: id,
            toDiverId: kept.heirId,
            keepAccess: false,
            moveRegistry: true,
            now: handoverAt,
          );
          keptEquipment += moved.itemsMoved;
          if (!keptHeirIds.contains(kept.heirId)) keptHeirIds.add(kept.heirId);
        }
```

After the transaction commits (next to `_applyMediaCascade`), rescan moved transmitters' dives:

```dart
      final movedTransmitters = _equipmentTransfer.takeMovedTransmitters();
      if (movedTransmitters.isNotEmpty) {
        await TransmitterRepository().rescanDivesForTransmitters(movedTransmitters);
      }
```

When building the returned `DeleteDiverResult`, resolve names from rows already loaded in `allDiversRows`:

```dart
        keptEquipmentCount: keptEquipment,
        keptEquipmentHeirNames: [
          for (final heirId in keptHeirIds)
            for (final r in allDiversRows)
              if (r.id == heirId) r.name,
        ],
```

Add the passthrough:

```dart
  /// How many items of [diverId]'s gear a delete would keep for other
  /// profiles, for the delete confirmation (issue #2852).
  Future<int> keptEquipmentCount(String diverId) =>
      _equipmentTransfer.keptEquipmentCount(diverId);
```

`transferUnitInTransaction` records moved transmitter ids in the service's list, which `takeMovedTransmitters` drains; the delete is the only caller of this service instance during the transaction.

- [ ] **Step 4: Run the new and existing deletion tests**

Run: `flutter test test/features/divers/data/repositories/`
Expected: PASS, including `diver_delete_equipment_shares_test.dart` (its scenario has `bcd` shared with `wife` and deletes `wife`, which owns `mask` shared with `owner`: `mask` is now kept and moves to `owner`; if an existing assertion there expects `mask` gone, it is asserting the old behaviour that #2852 fixes. Update that assertion to expect `mask` owned by `owner` and say so in the commit message).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/divers test/features/divers
flutter analyze lib/features/divers test/features/divers
git add lib/features/divers test/features/divers
git commit -m "feat(divers): keep gear other profiles use when a profile is deleted"
```

---

### Task 6: Strings in all 11 locales

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and the 10 other `app_*.arb` files
- Regenerate: `flutter gen-l10n` (or the command `scripts/setup.sh` uses)

**Interfaces:**
- Produces these keys (English values; translate into ar, de, es, fr, he, hu, it, nl, pt, zh, keeping placeholders and plural categories valid for each locale):

| Key | English |
| --- | --- |
| `equipment_transfer_action` | `Transfer to...` |
| `equipment_transfer_dialogTitle` | `Transfer to` |
| `equipment_transfer_dialogBody` | `The profile you choose becomes the owner. Past dives keep this gear.` |
| `equipment_transfer_alsoMoves` | `Also moves:` |
| `equipment_transfer_keepAccess` | `Keep access for me` |
| `equipment_transfer_keepAccessHint` | `It stays shared with you, so you can still use it.` |
| `equipment_transfer_moveRegistry` | `Also move linked dive computers and transmitters` |
| `equipment_transfer_transmitterClash` | `{label} stays with you: {profile} already has a transmitter with this serial or channel.` |
| `equipment_transfer_confirm` | `Transfer` |
| `equipment_transfer_done` | `{count, plural, one{Transferred {count} item to {name}} other{Transferred {count} items to {name}}}` |
| `equipment_transfer_doneSkipped` | `{count, plural, one{Transferred {count} item to {name}, skipped {skipped} you do not own} other{Transferred {count} items to {name}, skipped {skipped} you do not own}}` |
| `divers_delete_keptEquipment_dialogLine` | `{count, plural, one{{count} piece of gear in use by other profiles will be kept and handed to them.} other{{count} pieces of gear in use by other profiles will be kept and handed to them.}}` |
| `divers_delete_keptEquipment_toOne` | `{count, plural, one{{count} piece of gear handed to {name}.} other{{count} pieces of gear handed to {name}.}}` |
| `divers_delete_keptEquipment_toMany` | `{count, plural, one{{count} piece of gear handed to the profiles that use it.} other{{count} pieces of gear handed to the profiles that use it.}}` |

Each key gets an `@key` description and `placeholders` block (`count` int, `skipped` int, `name`, `label`, `profile` String). Place the `equipment_transfer_*` keys after the `equipment_sharing_*` group and the `divers_delete_*` keys after `divers_delete_reassigned_snackbar`, in every file.

- [ ] **Step 1:** Add the keys to all 11 files (script it with python3.14 so each file's own line endings and grouping are kept; check `git diff --numstat` shows only additions).
- [ ] **Step 2:** Regenerate localizations and confirm the generated methods' parameter order (placeholders map order) for `equipment_transfer_done(count, name)`, `equipment_transfer_doneSkipped(count, name, skipped)` and `divers_delete_keptEquipment_toOne(count, name)`.
- [ ] **Step 3:** Run `flutter analyze lib/l10n` and the l10n guard tests: `flutter test test/l10n/` (if present) and `test/architecture/`.
- [ ] **Step 4: Commit**

```bash
git add lib/l10n
git commit -m "feat(equipment): strings for equipment transfer and kept gear"
```

---

### Task 7: Transfer dialog

**Files:**
- Create: `lib/features/equipment/presentation/widgets/equipment_transfer_dialog.dart`
- Test: `test/features/equipment/presentation/widgets/equipment_transfer_dialog_test.dart`

**Interfaces:**
- Consumes: `EquipmentTransferPreview`, `TransferRegistryRow`, `equipmentTransferServiceProvider`, strings from Task 6, `equipmentRowLabelsOf`, `equipmentRepositoryProvider.getEquipmentByIds`.
- Produces:
  - `typedef EquipmentTransferRequest = ({String toDiverId, bool keepAccess, bool moveRegistry});`
  - `Future<EquipmentTransferRequest?> showEquipmentTransferDialog(BuildContext context, {required List<String> equipmentIds, required String activeDiverId, required List<Diver> profiles})`

Behaviour:
- Title `equipment_transfer_dialogTitle`, body `equipment_transfer_dialogBody`.
- A `RadioListTile<String>` per profile in `profiles` (the caller passes every profile except the active one).
- When the preview's `unitIds` has more items than `equipmentIds`, an "Also moves:" line followed by the extra items' row titles (`equipmentRowLabelsOf(...)[id]!.title`), one per line.
- `SwitchListTile` "Keep access for me" with the hint as subtitle, initially on.
- When `preview.hasRegistry`, a `SwitchListTile` "Also move linked dive computers and transmitters" with the labels joined by `, ` as subtitle, initially on; under it, for each transmitter with `clashes` (from the preview refreshed for the chosen profile), `equipment_transfer_transmitterClash(label, profileName)` in `bodySmall` with `colorScheme.onSurfaceVariant`.
- Cancel pops `null`; Transfer is disabled until a profile is chosen and pops the request.
- The preview is loaded on open (`toDiverId: null`) and again whenever the chosen profile changes; while it loads, the extra sections keep the previous preview (no flicker to empty).

- [ ] **Step 1: Write the failing widget tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/equipment/data/services/equipment_transfer_service.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_transfer_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_transfer_dialog.dart';

import '../../../../helpers/test_app.dart';

class _FakeService extends EquipmentTransferService {
  _FakeService(this.byTarget);
  final Map<String?, EquipmentTransferPreview> byTarget;

  @override
  Future<EquipmentTransferPreview> preview({
    required List<String> equipmentIds,
    required String actingDiverId,
    String? toDiverId,
  }) async => byTarget[toDiverId] ?? byTarget[null]!;
}

void main() {
  final profiles = [
    Diver(id: 'anna', name: 'Anna', createdAt: DateTime(2026), updatedAt: DateTime(2026)),
    Diver(id: 'tom', name: 'Tom', createdAt: DateTime(2026), updatedAt: DateTime(2026)),
  ];

  const plain = EquipmentTransferPreview(
    unitIds: ['light'],
    skippedNotOwned: 0,
    computers: [],
    transmitters: [],
  );

  Future<Future<EquipmentTransferRequest?>> open(
    WidgetTester tester,
    Map<String?, EquipmentTransferPreview> previews,
  ) async {
    late Future<EquipmentTransferRequest?> result;
    await tester.pumpWidget(
      testApp(
        overrides: [
          equipmentTransferServiceProvider.overrideWithValue(_FakeService(previews)),
        ],
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => result = showEquipmentTransferDialog(
              context,
              equipmentIds: const ['light'],
              activeDiverId: 'bill',
              profiles: profiles,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('Transfer is disabled until a profile is chosen', (tester) async {
    await open(tester, {null: plain});
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Transfer'));
    expect(button.onPressed, isNull);
  });

  testWidgets('returns the choice with keep access on by default', (tester) async {
    final result = await open(tester, {null: plain});
    await tester.tap(find.text('Tom'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Transfer'));
    await tester.pumpAndSettle();
    expect(await result, (toDiverId: 'tom', keepAccess: true, moveRegistry: true));
  });

  testWidgets('keep access can be turned off', (tester) async {
    final result = await open(tester, {null: plain});
    await tester.tap(find.text('Anna'));
    await tester.tap(find.text('Keep access for me'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Transfer'));
    await tester.pumpAndSettle();
    expect((await result)!.keepAccess, isFalse);
  });

  testWidgets('the registry switch shows only with linked rows', (tester) async {
    await open(tester, {null: plain});
    expect(find.text('Also move linked dive computers and transmitters'), findsNothing);
  });

  testWidgets('a clashing transmitter is explained for the chosen profile', (tester) async {
    const withTx = EquipmentTransferPreview(
      unitIds: ['tank'],
      skippedNotOwned: 0,
      computers: [],
      transmitters: [TransferRegistryRow(id: 'tx1', label: 'Back gas')],
    );
    const clash = EquipmentTransferPreview(
      unitIds: ['tank'],
      skippedNotOwned: 0,
      computers: [],
      transmitters: [TransferRegistryRow(id: 'tx1', label: 'Back gas', clashes: true)],
    );
    await open(tester, {null: withTx, 'anna': clash});
    expect(find.text('Also move linked dive computers and transmitters'), findsOneWidget);
    expect(find.textContaining('stays with you'), findsNothing);
    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Back gas stays with you: Anna'), findsOneWidget);
  });
}
```

The "Also moves" line needs `equipmentRepositoryProvider`; the tests above use single-item units, so the dialog must not read the repository when `unitIds` adds nothing. Add one more test with `unitIds: ['ccr', 'cell']` and `equipmentRepositoryProvider` overridden with a fake whose `getEquipmentByIds` returns two `EquipmentItem`s, asserting the extra item's name appears under "Also moves:" (build the fake on the repository class the provider exposes; see `equipment_list_content_test.dart` for how existing tests fake it).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/equipment/presentation/widgets/equipment_transfer_dialog_test.dart`
Expected: FAIL, file missing.

- [ ] **Step 3: Implement**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/equipment/data/services/equipment_transfer_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_transfer_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_row_labels_of.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the owner chose in the transfer dialog (issue #2852).
typedef EquipmentTransferRequest = ({
  String toDiverId,
  bool keepAccess,
  bool moveRegistry,
});

/// Asks which profile receives [equipmentIds] and how; null when cancelled.
/// [profiles] is every profile except [activeDiverId].
Future<EquipmentTransferRequest?> showEquipmentTransferDialog(
  BuildContext context, {
  required List<String> equipmentIds,
  required String activeDiverId,
  required List<Diver> profiles,
}) => showDialog<EquipmentTransferRequest>(
  context: context,
  builder: (_) => _EquipmentTransferDialog(
    equipmentIds: equipmentIds,
    activeDiverId: activeDiverId,
    profiles: profiles,
  ),
);

class _EquipmentTransferDialog extends ConsumerStatefulWidget {
  const _EquipmentTransferDialog({
    required this.equipmentIds,
    required this.activeDiverId,
    required this.profiles,
  });

  final List<String> equipmentIds;
  final String activeDiverId;
  final List<Diver> profiles;

  @override
  ConsumerState<_EquipmentTransferDialog> createState() =>
      _EquipmentTransferDialogState();
}

class _EquipmentTransferDialogState
    extends ConsumerState<_EquipmentTransferDialog> {
  String? _target;
  bool _keepAccess = true;
  bool _moveRegistry = true;
  EquipmentTransferPreview? _preview;
  List<EquipmentItem> _extraItems = const [];
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  /// Reloads the preview for the chosen profile. Only the latest request
  /// lands, so a slow answer for an earlier choice cannot overwrite it.
  Future<void> _loadPreview() async {
    final request = ++_request;
    final preview = await ref
        .read(equipmentTransferServiceProvider)
        .preview(
          equipmentIds: widget.equipmentIds,
          actingDiverId: widget.activeDiverId,
          toDiverId: _target,
        );
    final extraIds = [
      for (final id in preview.unitIds)
        if (!widget.equipmentIds.contains(id)) id,
    ];
    final extras = extraIds.isEmpty
        ? const <EquipmentItem>[]
        : await ref.read(equipmentRepositoryProvider).getEquipmentByIds(extraIds);
    if (!mounted || request != _request) return;
    setState(() {
      _preview = preview;
      _extraItems = extras;
    });
  }

  String _nameOf(String id) => widget.profiles
      .firstWhere((p) => p.id == id, orElse: () => widget.profiles.first)
      .name;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final preview = _preview;
    final labels = equipmentRowLabelsOf(context, ref, _extraItems);
    final registry = [
      for (final r in [...?preview?.computers, ...?preview?.transmitters]) r.label,
    ];
    final note = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return AlertDialog(
      title: Text(l10n.equipment_transfer_dialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.equipment_transfer_dialogBody),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _target,
              onChanged: (v) {
                setState(() => _target = v);
                _loadPreview();
              },
              child: Column(
                children: [
                  for (final p in widget.profiles)
                    RadioListTile<String>(
                      value: p.id,
                      title: Text(p.name),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            if (_extraItems.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(l10n.equipment_transfer_alsoMoves, style: theme.textTheme.titleSmall),
              for (final item in _extraItems)
                Text(labels[item.id]?.title ?? item.name),
            ],
            SwitchListTile(
              value: _keepAccess,
              onChanged: (v) => setState(() => _keepAccess = v),
              title: Text(l10n.equipment_transfer_keepAccess),
              subtitle: Text(l10n.equipment_transfer_keepAccessHint),
              contentPadding: EdgeInsets.zero,
            ),
            if (preview?.hasRegistry ?? false) ...[
              SwitchListTile(
                value: _moveRegistry,
                onChanged: (v) => setState(() => _moveRegistry = v),
                title: Text(l10n.equipment_transfer_moveRegistry),
                subtitle: Text(registry.join(', ')),
                contentPadding: EdgeInsets.zero,
              ),
              if (_target case final target?)
                for (final t in preview!.transmitters)
                  if (t.clashes)
                    Text(
                      l10n.equipment_transfer_transmitterClash(t.label, _nameOf(target)),
                      style: note,
                    ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: _target == null
              ? null
              : () => Navigator.of(context).pop((
                  toDiverId: _target!,
                  keepAccess: _keepAccess,
                  moveRegistry: _moveRegistry,
                )),
          child: Text(l10n.equipment_transfer_confirm),
        ),
      ],
    );
  }
}
```

If this Flutter version has no `RadioGroup` (check `flutter --version` and how `linked_profile_field.dart` builds its radio rows), use `RadioListTile`'s `groupValue`/`onChanged` the way that file does. If the generated `equipment_transfer_transmitterClash` takes `(label, profile)` in a different order, follow the generated signature.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/equipment/presentation/widgets/equipment_transfer_dialog_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/equipment test/features/equipment
flutter analyze lib/features/equipment test/features/equipment
flutter test test/architecture/
git add lib/features/equipment/presentation/widgets/equipment_transfer_dialog.dart test/features/equipment/presentation/widgets/equipment_transfer_dialog_test.dart
git commit -m "feat(equipment): transfer dialog"
```

---

### Task 8: Transfer from the item page and the list

**Files:**
- Create: `lib/features/equipment/presentation/widgets/equipment_bulk_transfer.dart`
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page.dart` (`_buildMenuItems` near line 400, both `PopupMenuButton`s near lines 302 and 386, `_handleMenuAction` near line 986, `_isOwner` near line 316)
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_content.dart` (`_bulkActions` near line 514)
- Test: `test/features/equipment/presentation/widgets/equipment_bulk_transfer_test.dart`
- Test: extend `test/features/equipment/presentation/pages/equipment_detail_sharing_test.dart` and `test/features/equipment/presentation/widgets/equipment_list_content_test.dart`

**Interfaces:**
- Consumes: `showEquipmentTransferDialog`, `equipmentTransferServiceProvider`, `canShareEquipment`, `hasMultipleDiversProvider`.
- Produces: `Future<({BulkActionOutcome outcome, bool keptAccess})> transferEquipmentToProfile(BuildContext context, WidgetRef ref, {required List<String> equipmentIds, required String? activeDiverId})`.

- [ ] **Step 1: Write the failing tests**

`equipment_bulk_transfer_test.dart`: with a fake service (as in Task 7, plus an overridden `transfer` that records its arguments and returns `EquipmentTransferResult(itemsMoved: 2)` or `(itemsMoved: 1, skippedNotOwned: 1)`), `allDiversProvider` overridden with Bill, Anna and Tom, a button that calls `transferEquipmentToProfile(context, ref, equipmentIds: ['a', 'b'], activeDiverId: 'bill')`:
- choosing Anna and confirming calls `transfer(equipmentIds: ['a', 'b'], toDiverId: 'anna', actingDiverId: 'bill', keepAccess: true, moveRegistry: true)` and shows "Transferred 2 items to Anna";
- the skipped variant shows "Transferred 1 item to Anna, skipped 1 you do not own";
- a throwing `transfer` shows the existing "try again" text and returns `BulkActionOutcome.failed`;
- cancelling returns `BulkActionOutcome.cancelled` and never calls `transfer`;
- Bill does not appear in the dialog's profile list.

`equipment_detail_sharing_test.dart`: following the file's existing setup for an owner and a sharee,
- as the owner with two profiles, the overflow menu contains "Transfer to...";
- as a sharee, it does not;
- with one profile, it does not;
- after a transfer with "Keep access" off, the page leaves (non-embedded: route is `/equipment`; embedded: `onDeleted` is called).

`equipment_list_content_test.dart`: with two profiles, selecting only owned items enables the "Transfer to..." bulk action; selecting a shared-with-me item disables it; with one profile it is absent.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/equipment/presentation/`
Expected: the new tests FAIL.

- [ ] **Step 3: Implement the shared flow**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_transfer_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_transfer_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/bulk_action.dart';

/// "Transfer to..." from the item page or the list (issue #2852): asks for
/// the profile, transfers what [activeDiverId] owns and reports the result.
/// `keptAccess` tells the item page whether it can stay open.
Future<({BulkActionOutcome outcome, bool keptAccess})> transferEquipmentToProfile(
  BuildContext context,
  WidgetRef ref, {
  required List<String> equipmentIds,
  required String? activeDiverId,
}) async {
  const cancelled = (outcome: BulkActionOutcome.cancelled, keptAccess: true);
  if (equipmentIds.isEmpty || activeDiverId == null) return cancelled;
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final divers = await ref.read(allDiversProvider.future);
  final others = [
    for (final d in divers)
      if (d.id != activeDiverId) d,
  ];
  if (!context.mounted || others.isEmpty) return cancelled;
  final request = await showEquipmentTransferDialog(
    context,
    equipmentIds: equipmentIds,
    activeDiverId: activeDiverId,
    profiles: others,
  );
  if (request == null) return cancelled;
  final name = others.firstWhere((d) => d.id == request.toDiverId).name;
  try {
    final result = await ref
        .read(equipmentTransferServiceProvider)
        .transfer(
          equipmentIds: equipmentIds,
          toDiverId: request.toDiverId,
          actingDiverId: activeDiverId,
          keepAccess: request.keepAccess,
          moveRegistry: request.moveRegistry,
        );
    if (messenger.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.skippedNotOwned == 0
                ? l10n.equipment_transfer_done(result.itemsMoved, name)
                : l10n.equipment_transfer_doneSkipped(
                    result.itemsMoved,
                    name,
                    result.skippedNotOwned,
                  ),
          ),
        ),
      );
    }
    return (outcome: BulkActionOutcome.completed, keptAccess: request.keepAccess);
  } catch (_) {
    if (messenger.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.common_error_tryAgain)));
    }
    return (outcome: BulkActionOutcome.failed, keptAccess: true);
  }
}
```

Follow the generated argument order of `equipment_transfer_done`/`doneSkipped` from Task 6.

- [ ] **Step 4: Wire the item page**

- Add `bool _canTransfer(WidgetRef ref, EquipmentItem equipment)`: `ref.watch(hasMultipleDiversProvider)` and the active diver known (`validatedCurrentDiverIdProvider.hasValue`) and `canShareEquipment(equipment, activeDiver.value)`.
- `_buildMenuItems(context, canDelete:, canTransfer:)`: insert before the delete item:

```dart
      if (canTransfer)
        PopupMenuItem(
          value: 'transfer',
          child: ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: Text(context.l10n.equipment_transfer_action),
            contentPadding: EdgeInsets.zero,
          ),
        ),
```

- Pass `canTransfer: _canTransfer(ref, equipment)` at both `PopupMenuButton` call sites (computed in `build` and `_buildEmbeddedHeader` beside `canDelete`).
- In `_handleMenuAction`:

```dart
      case 'transfer':
        final activeDiverId = await ref.read(validatedCurrentDiverIdProvider.future);
        if (!context.mounted) break;
        final done = await transferEquipmentToProfile(
          context,
          ref,
          equipmentIds: [equipmentId],
          activeDiverId: activeDiverId,
        );
        // Without kept access the item is no longer this profile's to see,
        // so leave as after a delete.
        if (done.outcome == BulkActionOutcome.completed && !done.keptAccess && context.mounted) {
          if (embedded) {
            onDeleted?.call();
          } else {
            context.go('/equipment');
          }
        }
```

- [ ] **Step 5: Wire the list**

After the `share` action inside `if (multipleDivers)` (turn the single element into a spread `...[ ... ]`):

```dart
        BulkAction(
          id: 'transfer',
          icon: Icons.swap_horiz,
          label: context.l10n.equipment_transfer_action,
          isEnabled: (ids) =>
              everyChecked(ids, (e) => canShareEquipment(e, activeDiverId)),
          onInvoke: () async {
            final done = await transferEquipmentToProfile(
              context,
              ref,
              equipmentIds: _selectedIds.toList(),
              activeDiverId: activeDiverId,
            );
            if (done.outcome == BulkActionOutcome.completed) _selection.exit();
            return done.outcome;
          },
        ),
```

Check how the share action's `onInvoke` result exits the selection (`SelectionAppBar` may exit on `completed` itself); if it does, drop the explicit `_selection.exit()`.

- [ ] **Step 6: Run to verify pass**

Run: `flutter test test/features/equipment/`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format lib/features/equipment test/features/equipment
flutter analyze lib/features/equipment test/features/equipment
flutter test test/architecture/
git add lib/features/equipment test/features/equipment
git commit -m "feat(equipment): transfer gear from the item page and the list"
```

---

### Task 9: Delete-profile dialog line and snackbar

**Files:**
- Modify: `lib/features/divers/presentation/widgets/delete_diver_dialog.dart`
- Modify: `lib/features/settings/presentation/pages/diver_profile_hub_page.dart` (`_showDeleteConfirmation` near line 413)
- Test: `test/features/divers/presentation/widgets/delete_diver_dialog_test.dart` (extend or create)
- Test: the hub page's delete test (find it with `grep -rln "_showDeleteConfirmation\|DeleteDiverDialog" test/`)

**Interfaces:**
- Consumes: `DiverRepository.keptEquipmentCount`, `DeleteDiverResult.hasKeptEquipment`, `keptEquipmentHeirNames`, Task 6 strings.
- Produces: `DeleteDiverDialog({required String diverName, int keptEquipmentCount = 0})` and `DeleteDiverDialog.show(context, {required String diverName, int keptEquipmentCount = 0})`; a pure `String deleteDiverSnackbarText(AppLocalizations l10n, DeleteDiverResult result)` in `lib/features/divers/presentation/widgets/delete_diver_snackbar_text.dart`.

- [ ] **Step 1: Write the failing tests**

Dialog: with `keptEquipmentCount: 5` the text "5 pieces of gear in use by other profiles will be kept and handed to them." is shown; with `0` it is not.

Snackbar text (pure function, `lookupAppLocalizations(const Locale('en'))`):

```dart
  test('trips and sites only', () {
    expect(
      deleteDiverSnackbarText(l10n, const DeleteDiverResult(
        reassignedTripsCount: 2, reassignedSitesCount: 1, reassignedToDiverName: 'Anna')),
      'Diver deleted. 2 shared trips and 1 shared site reassigned to Anna.',
    );
  });

  test('kept gear to one profile', () {
    expect(
      deleteDiverSnackbarText(l10n, const DeleteDiverResult(
        reassignedTripsCount: 0, reassignedSitesCount: 0,
        keptEquipmentCount: 3, keptEquipmentHeirNames: ['Tom'])),
      'Diver deleted. 3 pieces of gear handed to Tom.',
    );
  });

  test('kept gear to several profiles, with trips', () {
    expect(
      deleteDiverSnackbarText(l10n, const DeleteDiverResult(
        reassignedTripsCount: 1, reassignedSitesCount: 0, reassignedToDiverName: 'Anna',
        keptEquipmentCount: 1, keptEquipmentHeirNames: ['Tom', 'Anna'])),
      'Diver deleted. 1 shared trip and 0 shared sites reassigned to Anna. '
      '1 piece of gear handed to the profiles that use it.',
    );
  });

  test('nothing kept or reassigned', () {
    expect(
      deleteDiverSnackbarText(l10n, const DeleteDiverResult(reassignedTripsCount: 0, reassignedSitesCount: 0)),
      'Diver deleted',
    );
  });
```

`settings_profileHub_deleted` is "Diver deleted" with no full stop, so the implementation joins with `'. '` after a sentence that does not end in punctuation and `' '` otherwise.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/divers/presentation/ test/features/settings/presentation/pages/`
Expected: new tests FAIL.

- [ ] **Step 3: Implement**

Dialog: add the field and parameter; in `content`, after the existing body text:

```dart
          if (widget.keptEquipmentCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              context.l10n.divers_delete_keptEquipment_dialogLine(widget.keptEquipmentCount),
              style: theme.textTheme.bodyMedium,
            ),
          ],
```

Snackbar text:

```dart
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The message after a profile delete: what went to whom (issues #2594,
/// #2852).
String deleteDiverSnackbarText(AppLocalizations l10n, DeleteDiverResult result) {
  final first = result.hasReassignments
      ? l10n.divers_delete_reassigned_snackbar(
          result.reassignedTripsCount,
          result.reassignedSitesCount,
          result.reassignedToDiverName ?? '',
        )
      : l10n.settings_profileHub_deleted;
  if (!result.hasKeptEquipment) return first;
  final heirs = result.keptEquipmentHeirNames;
  final kept = heirs.length == 1
      ? l10n.divers_delete_keptEquipment_toOne(result.keptEquipmentCount, heirs.single)
      : l10n.divers_delete_keptEquipment_toMany(result.keptEquipmentCount);
  final joiner = RegExp(r'[.!?。]$').hasMatch(first.trimRight()) ? ' ' : '. ';
  return '${first.trimRight()}$joiner$kept';
}
```

The character class ends with the CJK full stop (U+3002) as a literal character. A backslash-u escape typed through the Write or Edit tool is decoded on the way in, so write that line with a python3.14 script that uses `chr(0x3002)` and check the file afterwards.

Hub page `_showDeleteConfirmation`:

```dart
    final keptCount = await ref
        .read(diverRepositoryProvider)
        .keptEquipmentCount(diver.id)
        .catchError((_) => 0);
    if (!context.mounted) return;
    final confirmed = await DeleteDiverDialog.show(
      context,
      diverName: diver.name,
      keptEquipmentCount: keptCount,
    );
    if (confirmed && context.mounted) {
      final result = await ref
          .read(diverListNotifierProvider.notifier)
          .deleteDiver(diver.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(deleteDiverSnackbarText(context.l10n, result))),
        );
      }
    }
```

A failed count only drops the advisory line; the delete itself still keeps the gear. Check `diverRepositoryProvider` is the provider name used in `diver_providers.dart` (line 29 reads `ref.watch(diverRepositoryProvider)`).

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/divers/ test/features/settings/presentation/pages/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/divers lib/features/settings test/features/divers test/features/settings
flutter analyze lib/features/divers lib/features/settings test/features/divers test/features/settings
flutter test test/architecture/
git add lib/features/divers lib/features/settings test/features/divers test/features/settings
git commit -m "feat(divers): say which gear a profile delete keeps and who gets it"
```

---

### Task 10: Sync round trip

**Files:**
- Test: `test/core/services/sync/equipment_transfer_sync_test.dart`

**Interfaces:**
- Consumes: the service; the two-device harness in `test/core/services/sync/equipment_sharing_sync_test.dart`.

- [ ] **Step 1: Write the tests** by copying the device setup from `equipment_sharing_sync_test.dart`:
  - Device A shares `light` with Anna, syncs to B; A transfers `light` to Anna with keep access; after sync, B has `light` owned by Anna, exactly one share row (Bill), no share row for Anna, and one `transferred` event.
  - Device A deletes Bill, whose `light` is shared with Tom; after sync, B has `light` owned by Tom, no `divers` row for Bill, and the transferred event with a null from side.
- [ ] **Step 2: Run**

Run: `flutter test test/core/services/sync/equipment_transfer_sync_test.dart`
Expected: PASS. A failure here is a real bug in Tasks 2 or 5 (a missing pending mark or tombstone): fix it there with its own test, not in this file.

- [ ] **Step 3: Commit**

```bash
dart format test/core/services/sync/equipment_transfer_sync_test.dart
git add test/core/services/sync/equipment_transfer_sync_test.dart
git commit -m "test(equipment): transfer and kept-gear handover converge on a peer"
```

---

### Task 11: Whole-branch checks

- [ ] **Step 1:** `dart format .` and confirm `git status` shows no unformatted change left.
- [ ] **Step 2:** `flutter analyze` (whole project; infos are fatal in CI).
- [ ] **Step 3:** `flutter test test/architecture/`.
- [ ] **Step 4:** Affected suites: `flutter test test/features/equipment test/features/divers test/features/settings test/features/transmitters test/core/services/sync`.
- [ ] **Step 5:** Commit any formatting fix as `chore: format`.
