# Streaming Replace-Adopt (iCloud OOM #358 follow-up) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `SyncService.adoptReplacedLibrary` apply an epoch-stamped cloud library in bounded memory so a fresh iOS device (0 dives) no longer OOM-crashes when it silently auto-adopts a large library (#358, still reproducing on v1.5.5.107).

**Architecture:** Mirror the already-shipped streaming base apply (`_applyRemoteBaseFile`). Assemble each epoch device's base into a temp file with `BasePartFileSink` (one 8 MB part in memory at a time), then in a single deferred-FK transaction stream every base file's `data` rows through `BaseJsonStreamReader` in `exportedAt` order, **upserting** in 500-row batches while collecting the set of cloud ids as a side effect, then **delete** local rows whose id is not in that set (via a new bounded id-only enumeration `recordIdsFor`), then repair FKs. This drops both RAM sinks the current path has: the decoded cloud `restored` map and the full local `exportData()` snapshot. Changesets stamped with the epoch stay in memory (they are small deltas), exactly as today.

**Tech Stack:** Dart/Flutter, Drift ORM (SQLite), existing sync primitives `BasePartFileSink`, `BaseJsonStreamReader`, `ChangesetCodec`, `SyncDataSerializer`.

## Global Constraints

- No wire-format change. Old monolithic-JSON bases and ssv1 part-sliced bases both already import; do not force any republish.
- Behavioral parity is the contract: the streaming adopt MUST produce a byte-identical synced-entity database to the current in-memory adopt for the same inputs. A parity test enforces this (Task 3).
- Adopt processes only the `data` section of each payload (base + changesets); it ignores `deletions`. This matches the current `_collectEpochPayloads` union (it reads `payload.data` only). Do not start applying deletions — that would be a behavior change outside this fix's scope.
- `upsertRecord` is an unconditional `insertOnConflictUpdate` (verified). Therefore applying rows in ascending `exportedAt` order (last write wins) is equivalent to the current "latest-export-wins `restored` map." Do not add conditional/LWW logic to the adopt apply.
- All apply work happens inside `_serializer.applyInDeferredFkTransaction(...)`; any throw rolls the whole adopt back (local library preserved). Base files are validated by `BasePartFileSink` (per-part + whole-file SHA-256) and `BaseJsonStreamReader`'s truncation guard BEFORE any local row is deleted.
- `dart format .` (whole repo) and `flutter analyze` must be clean before any commit. Run the targeted test files listed per task, not whole directories.
- Synced entity set is the 38 keys of `SyncService.entityHasUpdatedAt` (sync_service.dart:1215-1255), locked by the existing structural test. `recordIdsFor` and the delete loop must cover exactly these.

---

## File Structure

- `lib/core/services/sync/sync_data_serializer.dart` — add `recordIdsFor(String entityType) -> Future<Set<String>>` (bounded, id-only projection; emits the same id form `deleteRecord` consumes, including composite `a|b`).
- `lib/core/services/sync/sync_service.dart` — the bulk of the change:
  - keep the current in-memory union/delete/upsert as a `@visibleForTesting` reference (`debugAdoptInMemory`) and keep in-memory collection as `debugCollectEpochPayloadsInMemory` (test-only; production stops calling it);
  - add streaming production path: `_collectEpochBaseSources`, `_adoptApplyStreaming`, and `@visibleForTesting debugAdoptStreaming`;
  - rewrite `adoptReplacedLibrary` to use the streaming path and clean up temp files.
- `test/core/services/sync/sync_data_serializer_record_ids_test.dart` — new unit test for `recordIdsFor`.
- `test/core/services/sync/sync_adopt_streaming_parity_test.dart` — new parity test (streaming adopt == in-memory adopt, byte-identical DB), the safety net.

---

## Task 1: Bounded local id enumeration `recordIdsFor`

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (add method near `deleteRecord` at :1206; reuse existing `_compositeId`/`_splitCompositeId` conventions)
- Test: `test/core/services/sync/sync_data_serializer_record_ids_test.dart` (create)

**Interfaces:**
- Produces: `Future<Set<String>> SyncDataSerializer.recordIdsFor(String entityType)` — returns every local row's id for `entityType`, in the exact string form `_recordIdForEntity` produces and `deleteRecord` accepts: plain `id` for most, `key` for `settings`, `diveId|equipmentId` for `diveEquipment`, `setId|equipmentId` for `equipmentSetItems`. Reads only id column(s) (never full rows), so it is bounded for `diveProfiles`/`tankPressureProfiles` (row-per-sample, millions of rows). Unknown entity type returns an empty set.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/services/sync/sync_data_serializer_record_ids_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import '../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async => setUpTestDatabase());
  tearDown(() => tearDownTestDatabase());

  test('recordIdsFor returns plain ids for a simple entity', () async {
    final s = SyncDataSerializer();
    await s.upsertRecord('diveSites', {
      'id': 'site-1', 'name': 'A', 'description': '', 'notes': '',
      'isShared': false, 'createdAt': 1000, 'updatedAt': 1000,
    });
    await s.upsertRecord('diveSites', {
      'id': 'site-2', 'name': 'B', 'description': '', 'notes': '',
      'isShared': false, 'createdAt': 1000, 'updatedAt': 1000,
    });
    expect(await s.recordIdsFor('diveSites'), {'site-1', 'site-2'});
  });

  test('recordIdsFor builds composite ids for diveEquipment', () async {
    final s = SyncDataSerializer();
    // Parents first (FK).
    await s.upsertRecord('dives', _dive('d1'));
    await s.upsertRecord('equipment', _equip('e1'));
    await s.upsertRecord('diveEquipment', {
      'diveId': 'd1', 'equipmentId': 'e1', 'createdAt': 1000,
    });
    expect(await s.recordIdsFor('diveEquipment'), {'d1|e1'});
  });

  test('recordIdsFor keys settings on key, unknown type is empty', () async {
    final s = SyncDataSerializer();
    await s.upsertRecord('settings', {'key': 'theme', 'value': 'dark', 'updatedAt': 1});
    expect(await s.recordIdsFor('settings'), {'theme'});
    expect(await s.recordIdsFor('notATable'), <String>{});
  });
}

Map<String, dynamic> _dive(String id) => {
  'id': id, 'diveNumber': 1, 'diveDateTime': 1700000000000, 'createdAt': 1000, 'updatedAt': 1000,
};
Map<String, dynamic> _equip(String id) => {
  'id': id, 'name': 'reg', 'category': 'regulator', 'createdAt': 1000, 'updatedAt': 1000,
};
```

(If `_dive`/`_equip` literals are missing required NOT NULL columns, copy a known-good record shape from `test/core/services/sync/sync_base_streaming_parity_test.dart` / `test/helpers/` — those seed real rows. The point of the test is the id form, not the column set.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/sync/sync_data_serializer_record_ids_test.dart`
Expected: FAIL — `recordIdsFor` is not defined.

- [ ] **Step 3: Implement `recordIdsFor`**

Add to `SyncDataSerializer` (next to `deleteRecord`). Use typed `selectOnly` id-only projections so only the key column(s) are read. Mirror `deleteRecord`'s entity→table switch exactly (sync_data_serializer.dart:1206) for the plain-`id` entities; the three special cases are spelled out:

```dart
/// Every local row id for [entityType], in the id form [deleteRecord] accepts
/// (plain id; `settings` -> key; composite `a|b` for the two junctions).
/// Id-only projection: never materializes full rows, so it is bounded even for
/// row-per-sample tables. Used by streaming adopt to delete locals absent from
/// the restored library. Unknown entity types yield an empty set.
Future<Set<String>> recordIdsFor(String entityType) async {
  Future<Set<String>> plain<T extends Table, R>(
    TableInfo<T, R> table,
    GeneratedColumn<String> idCol,
  ) async {
    final q = _db.selectOnly(table)..addColumns([idCol]);
    final rows = await q.get();
    return {for (final r in rows) r.read(idCol)!};
  }

  switch (entityType) {
    case 'settings':
      return plain(_db.settings, _db.settings.key);
    case 'diveEquipment':
      final q = _db.selectOnly(_db.diveEquipment)
        ..addColumns([_db.diveEquipment.diveId, _db.diveEquipment.equipmentId]);
      return {
        for (final r in await q.get())
          '${r.read(_db.diveEquipment.diveId)}|${r.read(_db.diveEquipment.equipmentId)}',
      };
    case 'equipmentSetItems':
      final q = _db.selectOnly(_db.equipmentSetItems)
        ..addColumns([_db.equipmentSetItems.setId, _db.equipmentSetItems.equipmentId]);
      return {
        for (final r in await q.get())
          '${r.read(_db.equipmentSetItems.setId)}|${r.read(_db.equipmentSetItems.equipmentId)}',
      };
    case 'divers':
      return plain(_db.divers, _db.divers.id);
    // ... one `case` per remaining entity in entityHasUpdatedAt, each
    //     `return plain(_db.<table>, _db.<table>.id);`
    //     Mirror the exact entity->_db.<table> mapping in deleteRecord (:1206).
    default:
      return <String>{};
  }
}
```

Composite form `'$a|$b'` matches `_compositeId` (`'$left|$right'`) and round-trips through `deleteRecord`'s `_splitCompositeId`. Confirm `TableInfo`/`GeneratedColumn`/`Table` are imported (Drift; `database.dart` already re-exports them in this file's existing imports — if not, import `package:drift/drift.dart`).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/sync/sync_data_serializer_record_ids_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Guard completeness, format, analyze, commit**

Add one assertion to the new test so a future entity can't silently miss a `case` (returns empty -> its stale local rows would never be deleted on adopt):

```dart
test('recordIdsFor has a case for every synced entity', () async {
  final s = SyncDataSerializer();
  for (final entity in SyncService.entityHasUpdatedAt.keys) {
    // Empty DB: every known entity returns an (empty) set without throwing;
    // a missing case also returns empty, so this is a smoke guard. The parity
    // test (Task 3) is the behavioral guard that ids actually round-trip.
    expect(await s.recordIdsFor(entity), isA<Set<String>>());
  }
});
```

Run: `dart format . && flutter analyze && flutter test test/core/services/sync/sync_data_serializer_record_ids_test.dart`
Then commit:
```bash
git add lib/core/services/sync/sync_data_serializer.dart test/core/services/sync/sync_data_serializer_record_ids_test.dart
git commit -m "feat(sync): bounded recordIdsFor id enumeration for streaming adopt (#358)"
```

---

## Task 2: Extract the in-memory adopt as a test reference seam

This is a pure refactor: production behavior is unchanged. It carves out the current union/delete/upsert body so the parity test (Task 3) can drive the in-memory algorithm directly on decoded payloads, and keeps the in-memory collection callable from tests only.

**Files:**
- Modify: `lib/core/services/sync/sync_service.dart` (`adoptReplacedLibrary` :1831-1948 and `_collectEpochPayloads` :1954)

**Interfaces:**
- Produces: `Future<_AdoptCounts> _applyAdoptInMemory(List<SyncPayload> payloads)` — the current union/delete/upsert (sync_service.dart:1885-1924 body), minus the transaction wrapper and minus re-baseline, returning nothing meaningful is fine (`void`/counts). It MUST run inside the caller's transaction.
- Produces: `@visibleForTesting Future<void> debugAdoptInMemory(List<SyncPayload> payloads)` — wraps `_applyAdoptInMemory` in `applyInDeferredFkTransaction`; no re-baseline (so the parity comparison sees only data effects).
- Produces: `@visibleForTesting Future<List<SyncPayload>> debugCollectEpochPayloadsInMemory(CloudStorageProvider provider, String folderId, String epochId)` — the renamed current `_collectEpochPayloads`.

- [ ] **Step 1: Move the union/delete/upsert body into `_applyAdoptInMemory`**

Cut the body currently inside `applyInDeferredFkTransaction` in `adoptReplacedLibrary` (the `cloudIds`/`restored` union at :1888-1901, the delete-not-in-cloud at :1904-1914, the upsert at :1917-1921, and `repairDanglingForeignKeys` at :1923) into:

```dart
/// In-memory union/delete/upsert adopt (reference path). Caller provides the
/// open deferred-FK transaction. [localSnapshot] is the pre-adopt export used
/// for the delete-not-in-cloud pass. Kept as the parity reference for the
/// streaming path; production uses [_adoptApplyStreaming].
Future<void> _applyAdoptInMemory(
  List<SyncPayload> payloads,
  SyncPayload localSnapshot,
) async {
  final cloudIds = <String, Set<String>>{};
  final restored = <String, Map<String, Map<String, dynamic>>>{};
  for (final payload in payloads) {
    for (final entry in payload.data.toJson().entries) {
      final records = (entry.value as List).cast<Map<String, dynamic>>();
      for (final record in records) {
        final id = _recordIdForEntity(entry.key, record);
        if (id == null) continue;
        (cloudIds[entry.key] ??= <String>{}).add(id);
        (restored[entry.key] ??= {})[id] = record;
      }
    }
  }
  for (final entry in localSnapshot.data.toJson().entries) {
    final records = (entry.value as List).cast<Map<String, dynamic>>();
    for (final record in records) {
      final id = _recordIdForEntity(entry.key, record);
      if (id == null) continue;
      if (!(cloudIds[entry.key]?.contains(id) ?? false)) {
        await _serializer.deleteRecord(entry.key, id);
      }
    }
  }
  for (final entry in restored.entries) {
    for (final record in entry.value.values) {
      await _serializer.upsertRecord(entry.key, record);
    }
  }
  await _serializer.repairDanglingForeignKeys();
}
```

In `adoptReplacedLibrary`, replace the inlined body with:
```dart
await _serializer.applyInDeferredFkTransaction(
  () => _applyAdoptInMemory(payloads, localSnapshot),
);
```
(Keep payloads.sort + localSnapshot export + re-baseline exactly as they are.)

- [ ] **Step 2: Add the two `@visibleForTesting` seams**

```dart
@visibleForTesting
Future<void> debugAdoptInMemory(List<SyncPayload> payloads) async {
  final local = await _serializer.exportData(deviceId: 'adopt', deletions: const []);
  payloads.sort((a, b) => a.exportedAt.compareTo(b.exportedAt));
  await _serializer.applyInDeferredFkTransaction(
    () => _applyAdoptInMemory(payloads, local),
  );
}
```
Rename `_collectEpochPayloads` -> `debugCollectEpochPayloadsInMemory` and annotate `@visibleForTesting` (production references are removed in Task 4; until then `adoptReplacedLibrary` still calls it — keep the call working by referencing the new name).

- [ ] **Step 3: Verify no behavior change**

Run the existing epoch/adoption suites:
Run: `flutter test test/core/services/sync/sync_service_epoch_test.dart test/features/settings/presentation/providers/sync_providers_epoch_test.dart test/core/services/sync/changeset_reader_epoch_test.dart`
Expected: PASS (unchanged behavior).

- [ ] **Step 4: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/core/services/sync/sync_service.dart
git commit -m "refactor(sync): extract in-memory adopt as debug reference seam (#358)"
```

---

## Task 3: Streaming adopt core + parity test (the safety net)

**Files:**
- Modify: `lib/core/services/sync/sync_service.dart` (add streaming apply + seam)
- Test: `test/core/services/sync/sync_adopt_streaming_parity_test.dart` (create)

**Interfaces:**
- Produces: `Future<void> _adoptApplyStreaming({required List<String> baseFilePaths, required List<int> baseExportedAt, required List<SyncPayload> changesets})` — runs inside the caller's deferred-FK transaction. Single forward pass over the ordered units (base files + changesets, ascending `exportedAt`), batched upsert (500) per table, collecting `cloudIds` as it goes; then deletes local rows absent from `cloudIds` via `recordIdsFor`+`deleteRecord` over `entityHasUpdatedAt.keys`; then `repairDanglingForeignKeys`. `baseFilePaths[i]`'s export time is `baseExportedAt[i]`.
- Produces: `@visibleForTesting Future<void> debugAdoptStreaming(List<String> baseFilePaths, List<int> baseExportedAt, List<SyncPayload> changesets)` — wraps `_adoptApplyStreaming` in `applyInDeferredFkTransaction`; no re-baseline (parity sees only data effects).

- [ ] **Step 1: Write the failing parity test**

```dart
// test/core/services/sync/sync_adopt_streaming_parity_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

String _canonical(Map<String, dynamic> data) {
  final out = <String, dynamic>{};
  for (final k in data.keys.toList()..sort()) {
    final list = (data[k] as List).cast<Map<String, dynamic>>();
    out[k] = [...list]..sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b)));
  }
  return jsonEncode(out);
}
Future<String> _dump() async =>
    _canonical((await SyncDataSerializer().exportData(deviceId: 's', deletions: const [])).data.toJson());

SyncService _svc() =>
    SyncService(syncRepository: SyncRepository(), serializer: SyncDataSerializer());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async { await setUpTestDatabase(); SharedPreferences.setMockInitialValues({}); });
  tearDown(() => tearDownTestDatabase());

  test('streaming adopt equals in-memory adopt, byte-for-byte', () async {
    // Build TWO cloud payloads (base older, changeset newer) so latest-wins is
    // exercised, spanning a parent, a clockless child, a junction, and a BLOB.
    final dives = DiveRepository();
    await dives.createDive(createTestDiveWithBottomTime(id: 'd1', diveNumber: 1));
    await dives.createDive(createTestDiveWithBottomTime(id: 'd2', diveNumber: 2));
    final ser = SyncDataSerializer();
    await ser.upsertRecord('diveSites', {
      'id': 'site-1', 'name': 'Old', 'description': '', 'notes': '',
      'isShared': false, 'createdAt': 1000, 'updatedAt': 1000,
    });
    final base = await ser.exportData(deviceId: 'peer', deletions: const []);
    // Newer changeset: rename site-1, add site-2.
    await ser.upsertRecord('diveSites', {
      'id': 'site-1', 'name': 'NEW NAME', 'description': '', 'notes': '',
      'isShared': false, 'createdAt': 1000, 'updatedAt': 2000,
    });
    await ser.upsertRecord('diveSites', {
      'id': 'site-2', 'name': 'Second', 'description': '', 'notes': '',
      'isShared': false, 'createdAt': 1000, 'updatedAt': 2000,
    });
    final changeset = await ser.exportData(deviceId: 'peer', deletions: const []);
    // Force ordering base < changeset regardless of clock granularity.
    final baseP = base; final csP = changeset; // exportedAt already increasing

    // Seed a DIFFERENT local library: a stale dive 'd-stale' (not in cloud) must
    // be deleted; 'd1' overlaps and must end up as the cloud version.
    Future<void> seedLocal() async {
      final d = DiveRepository();
      await d.createDive(createTestDiveWithBottomTime(id: 'd1', diveNumber: 99));
      await d.createDive(createTestDiveWithBottomTime(id: 'd-stale', diveNumber: 7));
    }

    // Phase A: in-memory reference.
    await tearDownTestDatabase(); await setUpTestDatabase();
    await seedLocal();
    await _svc().debugAdoptInMemory([csP, baseP]); // unsorted on purpose
    final ref = await _dump();

    // Phase B: streaming. Base goes to a temp file; changeset stays in memory.
    await tearDownTestDatabase(); await setUpTestDatabase();
    await seedLocal();
    final tmpDir = await Directory.systemTemp.createTemp('adopt_parity');
    final tmp = File('${tmpDir.path}/base.json');
    await tmp.writeAsBytes(utf8.encode(SyncDataSerializer().serializePayload(baseP)));
    await _svc().debugAdoptStreaming([tmp.path], [baseP.exportedAt], [csP]);
    final got = await _dump();
    await tmpDir.delete(recursive: true);

    expect(got, ref, reason: 'streaming adopt must equal in-memory adopt');
    // Spot checks: stale gone, overlap is cloud version, latest-wins applied.
    final decoded = jsonDecode(got) as Map<String, dynamic>;
    final siteNames = [
      for (final s in (decoded['diveSites'] as List)) (s as Map)['name'],
    ];
    expect(siteNames, containsAll(['NEW NAME', 'Second']));
    expect(siteNames, isNot(contains('Old')));
  });
}
```

- [ ] **Step 2: Add a throwing stub so the test compiles and RED is meaningful**

```dart
@visibleForTesting
Future<void> debugAdoptStreaming(
  List<String> baseFilePaths, List<int> baseExportedAt, List<SyncPayload> changesets,
) async => throw UnimplementedError('debugAdoptStreaming');
```

Run: `flutter test test/core/services/sync/sync_adopt_streaming_parity_test.dart`
Expected: FAIL — `UnimplementedError`.

- [ ] **Step 3: Implement `_adoptApplyStreaming` + real `debugAdoptStreaming`**

```dart
/// Streaming replace-adopt apply (production path). Runs inside the caller's
/// deferred-FK transaction. Upserts every restored row in exportedAt order,
/// collecting cloud ids as it goes, then deletes local rows absent from that
/// set, then repairs FKs. Bounded memory: one 500-row batch + the cloud id sets
/// (ids only). Equivalent to [_applyAdoptInMemory] because upsertRecord is an
/// unconditional overwrite (ascending order => latest export wins) and
/// delete-not-in-cloud is order-independent. Parity is asserted by
/// sync_adopt_streaming_parity_test.dart.
Future<void> _adoptApplyStreaming({
  required List<String> baseFilePaths,
  required List<int> baseExportedAt,
  required List<SyncPayload> changesets,
}) async {
  final cloudIds = <String, Set<String>>{};

  // Ordered apply units: each base file and each changeset, by exportedAt asc.
  final units = <({int at, String? file, SyncPayload? cs})>[
    for (var i = 0; i < baseFilePaths.length; i++)
      (at: baseExportedAt[i], file: baseFilePaths[i], cs: null),
    for (final c in changesets) (at: c.exportedAt, file: null, cs: c),
  ]..sort((a, b) => a.at.compareTo(b.at));

  Future<void> upsertRow(String table, Map<String, dynamic> rec) async {
    final id = _recordIdForEntity(table, rec);
    if (id != null) (cloudIds[table] ??= <String>{}).add(id);
    await _serializer.upsertRecord(table, rec);
  }

  for (final unit in units) {
    if (unit.cs != null) {
      for (final entry in unit.cs!.data.toJson().entries) {
        for (final rec in (entry.value as List).cast<Map<String, dynamic>>()) {
          await upsertRow(entry.key, rec);
        }
      }
      continue;
    }
    // Base file: stream data rows in 500-row batches per table.
    const batchSize = 500;
    String? currentTable;
    var batch = <Map<String, dynamic>>[];
    Future<void> flush() async {
      final t = currentTable;
      if (t == null || batch.isEmpty) return;
      for (final rec in batch) {
        await upsertRow(t, rec);
      }
      batch = <Map<String, dynamic>>[];
    }
    await BaseJsonStreamReader().parse(
      File(unit.file!).openRead(),
      wantRows: (section, table) =>
          section == 'data' && entityHasUpdatedAt.containsKey(table),
      onRow: (section, table, rowBytes) async {
        if (table != currentTable) {
          await flush();
          currentTable = table;
        }
        batch.add(jsonDecode(utf8.decode(rowBytes)) as Map<String, dynamic>);
        if (batch.length >= batchSize) await flush();
      },
    );
    await flush();
  }

  // Delete local rows the restored library does not contain.
  for (final entity in entityHasUpdatedAt.keys) {
    final cloud = cloudIds[entity] ?? const <String>{};
    for (final localId in await _serializer.recordIdsFor(entity)) {
      if (!cloud.contains(localId)) {
        await _serializer.deleteRecord(entity, localId);
      }
    }
  }

  await _serializer.repairDanglingForeignKeys();
}

@visibleForTesting
Future<void> debugAdoptStreaming(
  List<String> baseFilePaths, List<int> baseExportedAt, List<SyncPayload> changesets,
) => _serializer.applyInDeferredFkTransaction(
      () => _adoptApplyStreaming(
        baseFilePaths: baseFilePaths,
        baseExportedAt: baseExportedAt,
        changesets: changesets,
      ),
    );
```

Ensure imports at top of sync_service.dart include `dart:io` (File), `dart:convert` (jsonDecode/utf8) — already present for `_applyRemoteBaseFile` — and `BaseJsonStreamReader` (already imported).

- [ ] **Step 4: Run the parity test to GREEN**

Run: `flutter test test/core/services/sync/sync_adopt_streaming_parity_test.dart`
Expected: PASS. If `got != ref`, diff the canonical dumps — most likely cause is a missing `recordIdsFor` case (stale local row not deleted) or an entity present in the payload but absent from `entityHasUpdatedAt` (would be skipped on the base-file pass but applied via the changeset path — keep both paths gated on `entityHasUpdatedAt` to match: change the changeset loop to also skip tables absent from `entityHasUpdatedAt`).

- [ ] **Step 5: Add a >500-row batch-boundary parity case**

Add a second test mirroring Step 1 but seeding 600 dives into the base payload (no changeset), asserting streaming == in-memory across the batch boundary (copy the 600-dive loop from `sync_base_streaming_parity_test.dart`).

Run: `flutter test test/core/services/sync/sync_adopt_streaming_parity_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/core/services/sync/sync_service.dart test/core/services/sync/sync_adopt_streaming_parity_test.dart
git commit -m "feat(sync): streaming replace-adopt apply with parity test (#358)"
```

---

## Task 4: Wire production `adoptReplacedLibrary` to the streaming path

**Files:**
- Modify: `lib/core/services/sync/sync_service.dart` (`adoptReplacedLibrary` :1831, add `_collectEpochBaseSources`)

**Interfaces:**
- Produces: `Future<({List<String> baseFilePaths, List<int> baseExportedAt, List<SyncPayload> changesets})?> _collectEpochBaseSources(CloudStorageProvider provider, String folderId, String epochId)` — for each device whose manifest carries `epochId`: assemble its base to a temp file (`BasePartFileSink`/`_fetchBaseToFile`-style; reuse the same assemble call as `ChangesetReader._fetchBaseToFile`), read its `exportedAt` via a scalar-only `BaseJsonStreamReader` pass, and decode its post-base changesets into memory. Skips a device whose base parts are not all present (matches current). Returns `null`/empties when nothing current-format exists (caller then runs `_recoverUnreadableEpoch`).

- [ ] **Step 1: Implement `_collectEpochBaseSources`** (mirror `debugCollectEpochPayloadsInMemory` device discovery at :1959-2004, but assemble to files instead of `parts.add`):

```dart
Future<({List<String> baseFilePaths, List<int> baseExportedAt, List<SyncPayload> changesets})>
_collectEpochBaseSources(
  CloudStorageProvider provider, String folderId, String epochId,
) async {
  final files = await provider.listFiles(
    folderId: folderId, namePattern: ChangesetLogLayout.prefix,
  );
  final byName = {for (final f in files) f.name: f};
  final deviceIds = <String>{
    for (final f in files)
      if (ChangesetLogLayout.deviceIdOf(f.name) != null)
        ChangesetLogLayout.deviceIdOf(f.name)!,
  };
  final baseFilePaths = <String>[];
  final baseExportedAt = <int>[];
  final changesets = <SyncPayload>[];
  for (final deviceId in deviceIds) {
    final manifestFile = byName[ChangesetLogLayout.manifestName(deviceId)];
    if (manifestFile == null) continue;
    SyncManifest manifest;
    try {
      manifest = SyncManifest.fromBytes(await provider.downloadFile(manifestFile.id));
    } catch (_) { continue; }
    if (manifest.epochId != epochId) continue;
    final baseSeq = manifest.baseSeq;
    if (baseSeq == null) continue;
    final partCount = manifest.basePartCount ?? 0;
    if (partCount <= 0) continue;
    final path = await _baseSink.assemble(
      name: 'ssv1_adopt_${deviceId}_$baseSeq',
      partCount: partCount,
      wholeChecksum: manifest.baseChecksum,
      partChecksums: manifest.basePartChecksums,
      downloadPart: (i) async {
        final pf = byName[ChangesetLogLayout.basePartName(deviceId, baseSeq, i)];
        if (pf == null) return null;
        return provider.downloadFile(pf.id);
      },
    );
    if (path == null) continue; // base incomplete/corrupt -> skip device
    var exportedAt = 0;
    await BaseJsonStreamReader().parse(
      File(path).openRead(),
      onScalar: (key, raw) async {
        if (key == 'exportedAt') {
          exportedAt = (jsonDecode(utf8.decode(raw)) as num?)?.toInt() ?? 0;
        }
      },
      wantRows: (_, _) => false, // scalars only
    );
    baseFilePaths.add(path);
    baseExportedAt.add(exportedAt);
    for (var seq = baseSeq + 1; seq <= manifest.headSeq; seq++) {
      final cf = byName[ChangesetLogLayout.changesetName(deviceId, seq)];
      if (cf == null) break;
      changesets.add(_changesetCodec.decodeChangeset(await provider.downloadFile(cf.id)));
    }
  }
  return (baseFilePaths: baseFilePaths, baseExportedAt: baseExportedAt, changesets: changesets);
}
```

Add a `BasePartFileSink _baseSink = BasePartFileSink();` field to `SyncService` (import already used by ChangesetReader; add `import '.../base_part_file_sink.dart';`). Confirm `_changesetCodec`, `ChangesetLogLayout`, `SyncManifest` are already imported in sync_service.dart (they are — used by `_collectEpochPayloads`).

- [ ] **Step 2: Rewrite `adoptReplacedLibrary` to use it**

Replace the collection + apply (current :1849-1924) with:
```dart
final folderId = await provider.getOrCreateSyncFolder();
final sources = await _collectEpochBaseSources(provider, folderId, marker.epochId);
if (sources.baseFilePaths.isEmpty) {
  if (await _recoverUnreadableEpoch(provider, marker)) {
    return const SyncResult(
      status: SyncResultStatus.success,
      message: 'The previous library could not be read; re-established this '
          'backend from this device\'s library.',
    );
  }
  return const SyncResult(
    status: SyncResultStatus.error,
    message: 'The replaced library is still uploading. Try again shortly.',
  );
}
try {
  await _serializer.applyInDeferredFkTransaction(
    () => _adoptApplyStreaming(
      baseFilePaths: sources.baseFilePaths,
      baseExportedAt: sources.baseExportedAt,
      changesets: sources.changesets,
    ),
  );
} finally {
  for (final p in sources.baseFilePaths) {
    await _baseSink.deleteQuietly(p);
  }
}
// Re-baseline (unchanged):
await _syncRepository.resetSyncState(clearDeletionLog: true);
await _syncRepository.setLastAcceptedEpochId(marker.epochId);
await store.setLastAccepted(marker);
SyncClock.instance.reset();
_log.info('Adopted replaced library (epoch ${marker.epochId})');
return const SyncResult(status: SyncResultStatus.success, message: 'Adopted the restored library');
```
Keep the surrounding `try/catch` (the `Failed to adopt` handler at :1937). Note the empty-set guard now keys on `baseFilePaths.isEmpty` (a current-format base is required; the previous code's `payloads.isEmpty` had the same effect because a payload required a base).

- [ ] **Step 3: Verify epoch + convergence integration tests**

Run: `flutter test test/core/services/sync/sync_service_epoch_test.dart test/features/settings/presentation/providers/sync_providers_epoch_test.dart test/core/services/sync/changeset_reader_epoch_test.dart test/core/services/sync/changeset_sync_convergence_test.dart`
Expected: PASS. These exercise silent auto-adopt (diveCount==0) and manual adopt; they now run the streaming path end to end. Fix any test that constructed `_collectEpochPayloads` expectations by pointing it at `debugCollectEpochPayloadsInMemory` or the new sources shape.

- [ ] **Step 4: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/core/services/sync/sync_service.dart
git commit -m "feat(sync): adopt replaced library via bounded streaming (fixes #358)"
```

---

## Task 5: Full-suite verification

**Files:** none (verification only)

- [ ] **Step 1: Run the whole sync test area**

Run: `flutter test test/core/services/sync/ test/features/settings/presentation/providers/sync_providers_epoch_test.dart`
Expected: PASS. Confirm the two parity tests (base + adopt) and the structural `entityHasUpdatedAt` test pass.

- [ ] **Step 2: Whole-project format + analyze** (per repo CI: Analyze & Format checks the whole project)

Run: `dart format . && flutter analyze`
Expected: no changes, no issues.

- [ ] **Step 3: Commit any formatting and push the branch**

```bash
git add -A && git commit -m "chore(sync): formatting for streaming adopt (#358)" || true
git push -u origin worktree-fix-sync-adopt-oom-streaming-358
```

- [ ] **Step 4: Hand off for device verification**

Real-device check on the reporter's library is the final gate (cannot be unit-tested): a fresh iOS install with 0 dives, against an epoch-stamped large cloud library, must adopt without the ~20 s OOM restart. Note this in the PR as the remaining manual step.

---

## Self-Review notes

- **Spec coverage:** cloud-base OOM -> Task 3 streaming apply; full-local-export OOM -> dropped (Task 3 uses `recordIdsFor`, Task 4 drops `exportData` local snapshot); trigger unchanged (notifier still calls `adoptReplacedLibrary`); multi-device epoch + changesets + latest-wins -> `_adoptApplyStreaming` ordered units; partial-epoch skip + unreadable-epoch recovery -> Task 4 preserves `_recoverUnreadableEpoch`.
- **Behavioral equivalence rests on:** `upsertRecord` unconditional overwrite (verified) + delete-not-in-cloud order-independence + ignoring deletions (matches current). The parity test is the enforcement.
- **Out of scope (tracked follow-up):** write/publish side `BaseChunker.slice(fullBytes)` in changeset_writer still buffers a full base in memory when a desktop publishes a large library.
