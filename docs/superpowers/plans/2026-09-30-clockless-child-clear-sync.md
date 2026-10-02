# Clockless Child Clear Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A column cleared to `null` on a parent-gated child row (a dive's tanks, gear links, events and the rest) reaches peers, without letting a re-applied base or an omitted key wipe a value.

**Architecture:** The merge keeps applying each child through its existing null-dropping upsert. When the peer's copy carries a strictly newer `hlc` than the local row (or the local row has none), the merge collects the keys the copy explicitly sets to `null`, and a new serializer pass writes those nulls with a targeted `UPDATE` after the batch. Five writers that set a child value without restamping the row get a fresh clock in the same statement, so the new rule cannot erase their values.

**Tech Stack:** Flutter, Dart 3, Drift (SQLite), flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-30-clockless-child-clear-sync-design.md`

## Global Constraints

- Scope is exactly `SyncDataSerializer.parentGatedChildEntities` (25 types). Media (`clockGuardedEntities`) is not touched.
- A remote copy with no `hlc` never clears. A local row with a NULL `hlc` counts as older than any stamped remote.
- A key the remote omits is never cleared; only an explicit `null` is.
- No wire-format change and no compatibility-floor bump.
- None of the 25 `upsertRecord`/`upsertRecords` arms change. Do NOT add `.toCompanion(false)` to any clockless arm (#474).
- Writers are fixed by adding `hlc: Value(await <syncRepository>.issueRowClock())` to the same statement; do not add `markRecordPending('dives', ...)` for a child-only change (#1769).
- No em-dashes or en-dashes as punctuation anywhere (code, comments, commits). No emojis. No mention of Claude or Anthropic in commits or PR text.
- Paths in tests are built with `p.join`, never string concatenation. A test that changes process-wide state restores it in `addTearDown`.
- Imports grouped dart, flutter, packages, local. Run `dart format .` before every commit.
- Every commit message ends with a blank line and `Refs #2644` (the final PR body uses `Closes #2644`).

## Review Focus

1. **A clear write that fails after the upsert already consumed the peer's clock.** Expected: the payload rolls back and is re-applied next sync, never "applied" with the clear lost. Pinned in Task 3 (`a failing clear rolls the payload back`).
2. **A peer's newer copy that nulls a NOT NULL, key, or `hlc` column** (malformed or legacy payload). Expected: ignored, no exception, row intact. Pinned in Task 2.
3. **A row this device has pending (unpublished edit) receiving a newer copy with nulls.** Expected: the ordinary resolution already decides whether the remote row applies; a clear is only written when the row itself was applied from the remote. Pinned in Task 3 (`a pending local row that keeps its own fields is not cleared`).
4. **The parent-deletion guard nulling a nullable reference** (`recordToApply[ref.field] = null` when the parent is tombstoned). Expected: with a newer copy the reference is cleared, which matches the set-null FK semantics. No new test: existing `sync_service` parent-guard tests cover the upsert, and the clear agrees with it.
5. **A future column whose Drift JSON key is not the camel-case form of its SQL name.** Expected: the pin test in Task 1 fails loudly, naming the table and key. Pinned in Task 1.

---

## File Structure

| File | Responsibility |
|---|---|
| Create `lib/core/services/sync/child_column_clears.dart` | Pure rules: is a copy newer, which keys it clears, JSON key to SQL column mapping. No database access. |
| Modify `lib/core/services/sync/sync_data_serializer.dart` | New `clearChildColumns` next to `writeFactGroup`; doc comment on `upsertRecord`. |
| Modify `lib/core/services/sync/sync_service.dart` | `_mergeEntity` collects clears for applied parent-gated rows and calls `clearChildColumns` after the batch. |
| Modify five writers (Tasks 4 to 7) | Stamp a fresh `hlc` in the statement that sets the child value. |
| Create `test/core/services/sync/child_column_clears_test.dart` | Pure rules and the all-tables JSON key pin. |
| Create `test/core/services/sync/clear_child_columns_test.dart` | The serializer pass against a real test database. |
| Create `test/core/services/sync/child_clear_merge_test.dart` | The merge rule through `performSync`. |
| Create `test/helpers/peer_pull.dart` | `pullPeerPayload`: publish a peer's payload to a fake cloud and run one real `performSync` (Tasks 3 and 8). |
| Create `test/helpers/clock_expectations.dart` | `expectFresherClock`: a writer restamped the row (Tasks 4 to 7). |
| Writer and end-to-end tests | Listed per task. |

---

### Task 1: Pure clear rules

**Files:**
- Create: `lib/core/services/sync/child_column_clears.dart`
- Test: `test/core/services/sync/child_column_clears_test.dart`

**Interfaces:**
- Consumes: `Hlc` from `lib/core/services/sync/hlc.dart` (`implements Comparable<Hlc>`); `SyncDataSerializer.parentGatedTables` (public, `@visibleForTesting`).
- Produces:
  - `bool isNewerChildCopy({required Hlc? remote, required Hlc? local})`
  - `Set<String> explicitlyClearedKeys({required Map<String, dynamic> remote, required Map<String, dynamic> local})`
  - `String columnJsonKey(String sqlName)`
  - `Map<String, String> clearableColumns(TableInfo<Table, Object?> table, {required List<String> keyColumns})` (JSON key to SQL column name)

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/child_column_clears.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// A peer's explicit null on a parent-gated child used to be dropped by the
/// upsert (#2644). These are the rules that decide when it is a deliberate
/// clear and which column it names.
void main() {
  group('isNewerChildCopy', () {
    final base = Hlc(1000, 0, 'a');
    final later = Hlc(2000, 0, 'b');

    test('a copy with no clock is never newer', () {
      expect(isNewerChildCopy(remote: null, local: base), isFalse);
      expect(isNewerChildCopy(remote: null, local: null), isFalse);
    });

    test('a stamped copy beats an unstamped local row', () {
      expect(isNewerChildCopy(remote: base, local: null), isTrue);
    });

    test('strictly newer only', () {
      expect(isNewerChildCopy(remote: later, local: base), isTrue);
      expect(isNewerChildCopy(remote: base, local: base), isFalse);
      expect(isNewerChildCopy(remote: base, local: later), isFalse);
    });
  });

  test('explicitlyClearedKeys: an explicit null over a value, nothing else', () {
    final cleared = explicitlyClearedKeys(
      remote: {'a': null, 'b': null, 'c': 1},
      local: {'a': 'x', 'b': null, 'c': 2, 'd': 'kept'},
    );
    // b was already null, c is a value, d is omitted by the remote.
    expect(cleared, {'a'});
  });

  test('columnJsonKey is the camel-case form of the SQL name', () {
    expect(columnJsonKey('transmitter_serial'), 'transmitterSerial');
    expect(columnJsonKey('o2_percent'), 'o2Percent');
    expect(columnJsonKey('id'), 'id');
  });

  group('against the schema', () {
    late AppDatabase db;

    setUp(() async {
      db = await setUpTestDatabase();
    });
    tearDown(() async {
      await tearDownTestDatabase();
    });

    test('clearable tank columns: nullable, not key, not clock', () {
      final cols = clearableColumns(db.diveTanks, keyColumns: const ['id']);
      expect(cols['transmitterSerial'], 'transmitter_serial');
      expect(cols['computerId'], 'computer_id');
      expect(cols.containsKey('hlc'), isFalse);
      expect(cols.containsKey('id'), isFalse);
      expect(cols.containsKey('diveId'), isFalse, reason: 'NOT NULL');
      expect(cols.containsKey('o2Percent'), isFalse, reason: 'NOT NULL');
    });

    test('every parent-gated table: toJson keys are the camel-case column '
        'names', () async {
      await db.customStatement('PRAGMA foreign_keys = OFF');
      for (final MapEntry(key: type, value: tableName)
          in SyncDataSerializer.parentGatedTables.entries) {
        final table = db.allTables.firstWhere(
          (t) => t.actualTableName == tableName,
        );
        // One minimal row: each NOT NULL column without a default gets a
        // placeholder of its SQL type.
        final info = await db
            .customSelect(
              'SELECT * FROM pragma_table_info(?)',
              variables: [Variable.withString(tableName)],
            )
            .get();
        final names = <String>[];
        final values = <Object?>[];
        for (final c in info) {
          final notNull = (c.data['notnull'] as int? ?? 0) == 1;
          if (!notNull || c.data['dflt_value'] != null) continue;
          final sqlType = (c.data['type'] as String? ?? '').toUpperCase();
          names.add('"${c.read<String>('name')}"');
          values.add(switch (sqlType) {
            final t when t.contains('INT') => 0,
            final t when t.contains('REAL') => 0.0,
            final t when t.contains('BLOB') => Uint8List(0),
            _ => 'x',
          });
        }
        await db.customStatement(
          'INSERT INTO "$tableName" (${names.join(', ')}) '
          'VALUES (${names.map((_) => '?').join(', ')})',
          values,
        );
        final row = await db
            .customSelect('SELECT * FROM "$tableName" LIMIT 1')
            .getSingle();
        final data = table.map(row.data) as DataClass;
        expect(
          data.toJson().keys.toSet(),
          {for (final c in table.$columns) columnJsonKey(c.$name)},
          reason: '$type ($tableName): a JSON key is not the camel-case '
              'form of its column, so a peer clear would miss it',
        );
      }
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/sync/child_column_clears_test.dart`
Expected: FAIL to compile, `child_column_clears.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/core/services/sync/child_column_clears.dart`:

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/services/sync/hlc.dart';

/// Whether a peer's copy of a parent-gated child is newer than the local
/// row, so the nulls it carries are deliberate clears (#2644).
///
/// A copy with no clock never is: it is this device's own base re-applied,
/// or a peer from before v210, and its nulls may only mean "not known
/// there". A local row with no clock was never stamped (every row from
/// before v210, and rows a download inserted), so any stamped copy is newer.
bool isNewerChildCopy({required Hlc? remote, required Hlc? local}) =>
    remote != null && (local == null || remote.compareTo(local) > 0);

/// The keys [remote] sets to null explicitly while [local] holds a value.
/// A key [remote] omits is not a clear: an older peer may simply not know
/// the column (the #474 overlay rule).
Set<String> explicitlyClearedKeys({
  required Map<String, dynamic> remote,
  required Map<String, dynamic> local,
}) => {
  for (final e in remote.entries)
    if (e.value == null && local[e.key] != null) e.key,
};

/// The key Drift's generated `toJson` uses for the SQL column [sqlName]: its
/// camel-case form (`transmitter_serial` becomes `transmitterSerial`). A
/// test pins this for every parent-gated table.
String columnJsonKey(String sqlName) {
  final parts = sqlName.split('_');
  return [
    parts.first,
    for (final part in parts.skip(1))
      if (part.isNotEmpty) '${part[0].toUpperCase()}${part.substring(1)}',
  ].join();
}

/// The columns of [table] a peer's null may clear, keyed by JSON key:
/// nullable, not one of [keyColumns], and not the row clock. Anything else
/// in a payload is ignored, so a malformed copy can neither fail on a
/// NOT NULL column nor move a row's key.
Map<String, String> clearableColumns(
  TableInfo<Table, Object?> table, {
  required List<String> keyColumns,
}) => {
  for (final c in table.$columns)
    if (c.$nullable && c.$name != 'hlc' && !keyColumns.contains(c.$name))
      columnJsonKey(c.$name): c.$name,
};
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/sync/child_column_clears_test.dart`
Expected: PASS. If the pin test fails on a key mismatch, do NOT loosen it: report the table and key; the fix is an explicit override map in `child_column_clears.dart`, pinned by the same test. If instead a seed `INSERT` fails (a CHECK constraint rejecting a placeholder), give that one column a valid placeholder in the test, keyed by table and column name, and keep every table in the loop.

- [ ] **Step 5: Run the architecture guards (a new lib/ file)**

Run: `flutter test test/architecture`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/core/services/sync/child_column_clears.dart test/core/services/sync/child_column_clears_test.dart
git add lib/core/services/sync/child_column_clears.dart test/core/services/sync/child_column_clears_test.dart
git commit -m "feat(sync): rules for a peer's deliberate clear on a child row

Refs #2644"
```

---

### Task 2: Serializer clear pass

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (add `clearChildColumns` directly after `writeFactGroup`, which ends near line 1689; add an import; extend the `upsertRecord` doc comment near line 3850)
- Test: `test/core/services/sync/clear_child_columns_test.dart`

**Interfaces:**
- Consumes: `clearableColumns` from Task 1; the existing private `_parentGatedKeyColumns` and public `parentGatedTables` in the same class.
- Produces: `Future<void> SyncDataSerializer.clearChildColumns(String entityType, Map<String, Set<String>> clears)`, where `clears` maps a sync record id (a composite key joined with `|`, as `parentGatedRecordId` builds it) to JSON keys.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// The write half of #2644: a peer's deliberate clears land as NULL on the
/// named nullable columns, and nothing else is touched.
void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    // Placeholder parents; this exercises the column write, not FKs.
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement(
      "INSERT INTO dive_tanks (id, dive_id, volume, working_pressure, "
      "transmitter_serial, hlc) "
      "VALUES ('t1', 'd1', 11.1, 232.0, 'SER-1', '1000:0:a')",
    );
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<Map<String, dynamic>> tank() async =>
      (await serializer.fetchRecord('diveTanks', 't1'))!;

  test('nulls the named nullable columns and leaves the rest', () async {
    await serializer.clearChildColumns('diveTanks', {
      't1': {'transmitterSerial', 'volume'},
    });
    final row = await tank();
    expect(row['transmitterSerial'], isNull);
    expect(row['volume'], isNull);
    expect(row['workingPressure'], 232.0);
    expect(row['hlc'], '1000:0:a');
  });

  test('ignores NOT NULL, key, clock and unknown keys', () async {
    await serializer.clearChildColumns('diveTanks', {
      't1': {'o2Percent', 'id', 'diveId', 'hlc', 'noSuchColumn'},
    });
    final row = await tank();
    expect(row['id'], 't1');
    expect(row['diveId'], 'd1');
    expect(row['hlc'], '1000:0:a');
    expect(row['transmitterSerial'], 'SER-1');
  });

  test('a composite-key child is matched on both key columns', () async {
    await db.customStatement(
      "INSERT INTO dive_equipment (dive_id, equipment_id, via_set_id) "
      "VALUES ('d1', 'e1', 's1'), ('d1', 'e2', 's1')",
    );
    await serializer.clearChildColumns('diveEquipment', {
      'd1|e1': {'viaSetId'},
    });
    final rows = await db
        .customSelect(
          'SELECT equipment_id, via_set_id FROM dive_equipment '
          'ORDER BY equipment_id',
        )
        .get();
    expect(rows.map((r) => r.read<String?>('via_set_id')), [null, 's1']);
  });

  test('an entity outside the parent-gated set is a no-op', () async {
    await serializer.clearChildColumns('dives', {
      't1': {'transmitterSerial'},
    });
    expect((await tank())['transmitterSerial'], 'SER-1');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/sync/clear_child_columns_test.dart`
Expected: FAIL to compile, `clearChildColumns` is not defined.

- [ ] **Step 3: Write the implementation**

Add to the imports of `sync_data_serializer.dart`, in the `package:submersion/core/services/sync/...` block (alphabetical, before `sync_fact_groups.dart`):

```dart
import 'package:submersion/core/services/sync/child_column_clears.dart';
```

Insert directly after the closing `}` of `writeFactGroup`:

```dart
  /// Writes a peer's deliberate clears on parent-gated children (#2644).
  ///
  /// The upsert that applied each row builds with nullToAbsent, so a null it
  /// carries never lands. The merge collects the keys a strictly newer copy
  /// set to null (see isNewerChildCopy) and hands them here; [clears] maps a
  /// sync record id to those JSON keys. Only nullable columns outside the
  /// row's key are written, so a malformed payload can neither fail on a
  /// NOT NULL column nor move a row.
  ///
  /// A junction applied lowest-id-per-pair can keep a local id over the
  /// remote one; its clear then matches no row. Those junctions carry no
  /// nullable user columns worth clearing.
  Future<void> clearChildColumns(
    String entityType,
    Map<String, Set<String>> clears,
  ) async {
    final tableName = parentGatedTables[entityType];
    if (tableName == null || clears.isEmpty) return;
    final table = _db.allTables.firstWhere(
      (t) => t.actualTableName == tableName,
    );
    final keys = _parentGatedKeyColumns[entityType] ?? const ['id'];
    final clearable = clearableColumns(table, keyColumns: keys);
    for (final MapEntry(key: recordId, value: jsonKeys) in clears.entries) {
      final columns = {for (final k in jsonKeys) ?clearable[k]};
      if (columns.isEmpty) continue;
      final keyValues = keys.length == 1 ? [recordId] : recordId.split('|');
      if (keyValues.length != keys.length) continue;
      // customUpdate, not customStatement, so Drift's query streams rebuild
      // (the same reason as writeFactGroup).
      await _db.customUpdate(
        'UPDATE "$tableName" '
        'SET ${columns.map((c) => '"$c" = NULL').join(', ')} '
        'WHERE ${keys.map((k) => '"$k" = ?').join(' AND ')}',
        variables: [for (final v in keyValues) Variable.withString(v)],
        updates: {table},
        updateKind: UpdateKind.update,
      );
    }
  }
```

Then extend the `upsertRecord` doc comment. Replace its last paragraph's final sentence:

```dart
  /// write (e.g. the consolidation `computerId` backfill). Do NOT add
  /// `.toCompanion(false)` to a clockless case -- it reintroduces that clobber.
```

with:

```dart
  /// write (e.g. the consolidation `computerId` backfill). Do NOT add
  /// `.toCompanion(false)` to a clockless case -- it reintroduces that clobber.
  /// A parent-gated child's deliberate clear lands afterwards instead, through
  /// [clearChildColumns], and only from a copy whose clock is strictly newer
  /// (#2644).
```

(The two `--` lines are pre-existing text; leave them as they are and add no new ones.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/sync/clear_child_columns_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/core/services/sync/sync_data_serializer.dart test/core/services/sync/clear_child_columns_test.dart
git add lib/core/services/sync/sync_data_serializer.dart test/core/services/sync/clear_child_columns_test.dart
git commit -m "feat(sync): write a peer's cleared child columns

Refs #2644"
```

---

### Task 3: Merge collects and writes clears

**Files:**
- Create: `test/helpers/peer_pull.dart`
- Modify: `lib/core/services/sync/sync_service.dart` (`_mergeEntity`: next to `final toUpsert` near line 3015, the clockless `factGroups.isEmpty` block near lines 3202-3207, after the `for (final w in factWrites)` loop near line 3400; a new private helper directly above `_extractHlc` near line 3536; one import)
- Modify: `docs/superpowers/specs/2026-09-30-clockless-child-clear-sync-design.md` (failure-handling sentence, Step 6)
- Test: `test/core/services/sync/child_clear_merge_test.dart`

**Interfaces:**
- Consumes: `isNewerChildCopy`, `explicitlyClearedKeys` (Task 1); `SyncDataSerializer.clearChildColumns` (Task 2).
- Produces:
  - `Future<SyncResult> pullPeerPayload(FakeCloudStorageProvider cloud, SyncData data, {String peerId = 'peer-b'})` in `test/helpers/peer_pull.dart` (used again in Task 8).
  - Behavior: after `performSync`, a parent-gated child whose remote copy is newer has the remote's explicit nulls written.

- [ ] **Step 1: Create the shared peer-pull helper**

`test/helpers/peer_pull.dart` (the payload shape is the one `child_hlc_test.dart` builds inline):

```dart
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import 'changeset_test_helpers.dart';
import 'fake_cloud_storage_provider.dart';

/// Publishes [data] as peer [peerId]'s base in [cloud], then runs one real
/// performSync on the current test database, so the rows go through the
/// same merge a real pull does.
Future<SyncResult> pullPeerPayload(
  FakeCloudStorageProvider cloud,
  SyncData data, {
  String peerId = 'peer-b',
}) async {
  await seedPeerBaseFromPayload(
    cloud,
    peerId,
    SyncPayload(
      version: syncFormatVersion,
      exportedAt: 9000,
      deviceId: peerId,
      checksum: sha256
          .convert(utf8.encode(jsonEncode(data.toJson())))
          .toString(),
      data: data,
      deletions: const {},
    ),
  );
  return SyncService(
    syncRepository: SyncRepository(),
    serializer: SyncDataSerializer(),
    cloudProvider: cloud,
  ).performSync();
}
```

- [ ] **Step 2: Write the failing test**

`test/core/services/sync/child_clear_merge_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/peer_pull.dart';
import '../../../helpers/test_database.dart';

/// A peer that clears a column on a child row (a re-parse dropping a stale
/// transmitter serial, a split clearing computer_id) used to leave the old
/// value everywhere else: the upsert drops nulls (#2644). A copy whose clock
/// is strictly newer now writes its explicit nulls; a tie, a missing clock
/// or an omitted key still leaves the local value alone.
void main() {
  late AppDatabase db;
  late FakeCloudStorageProvider cloud;
  late Map<String, dynamic> local;
  late Hlc localHlc;

  setUp(() async {
    db = await setUpTestDatabase();
    cloud = FakeCloudStorageProvider();
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await db.customStatement(
      "INSERT INTO dive_tanks (id, dive_id, volume, transmitter_serial) "
      "VALUES ('t1', 'd1', 11.1, 'SER-1')",
    );
    await SyncRepository().markRecordPending(
      entityType: 'diveTanks',
      recordId: 't1',
      localUpdatedAt: 1,
    );
    local = (await SyncDataSerializer().fetchRecord('diveTanks', 't1'))!;
    localHlc = Hlc.parse(local['hlc'] as String);
    // This device has published; what follows is a peer's payload.
    await SyncRepository().clearAllSyncRecords();
  });
  tearDown(() => DatabaseService.instance.resetForTesting());

  Future<Map<String, dynamic>> pull(Map<String, dynamic> theirs) async {
    final result = await pullPeerPayload(cloud, SyncData(diveTanks: [theirs]));
    expect(result.status, isNot(SyncResultStatus.error));
    return (await SyncDataSerializer().fetchRecord('diveTanks', 't1'))!;
  }

  Hlc shifted(int ms) =>
      Hlc(localHlc.physicalTime + ms, localHlc.counter, 'peer-b');

  Future<void> dropLocalClock() => db.customStatement(
    "UPDATE dive_tanks SET hlc = NULL WHERE id = 't1'",
  );

  test('a strictly newer copy clears the column it sets to null', () async {
    final row = await pull({
      ...local,
      'transmitterSerial': null,
      'hlc': shifted(1000).toString(),
    });
    expect(row['transmitterSerial'], isNull);
    expect(row['volume'], 11.1, reason: 'only the explicit null clears');
  });

  test('a stamped copy clears a row that has no clock yet', () async {
    await dropLocalClock();
    final row = await pull({
      ...local,
      'transmitterSerial': null,
      'hlc': shifted(1000).toString(),
    });
    expect(row['transmitterSerial'], isNull);
  });

  test('an exact tie (own base re-applied) keeps the value', () async {
    final row = await pull({...local, 'transmitterSerial': null});
    expect(row['transmitterSerial'], 'SER-1');
  });

  test('a copy with no clock keeps the value', () async {
    final row = await pull({
      ...local,
      'transmitterSerial': null,
      'hlc': null,
    });
    expect(row['transmitterSerial'], 'SER-1');
  });

  test('an omitted key keeps the value', () async {
    final theirs = {...local, 'hlc': shifted(1000).toString()}
      ..remove('transmitterSerial');
    final row = await pull(theirs);
    expect(row['transmitterSerial'], 'SER-1');
  });

  test('a strictly older copy is skipped, clears included', () async {
    final row = await pull({
      ...local,
      'transmitterSerial': null,
      'hlc': shifted(-1000).toString(),
    });
    expect(row['transmitterSerial'], 'SER-1');
  });

  test('a pending local row that keeps its own fields is not cleared',
      () async {
    // An unpublished local edit with no clock to order it against the
    // peer's: the merge keeps the local fields, so no clear may land either.
    await SyncRepository().markRecordPending(
      entityType: 'diveTanks',
      recordId: 't1',
      localUpdatedAt: 2,
    );
    await dropLocalClock();
    final row = await pull({
      ...local,
      'transmitterSerial': null,
      'hlc': shifted(1000).toString(),
    });
    expect(row['transmitterSerial'], 'SER-1');
  });
}
```

Before relying on the last test, read how `_mergeEntity` treats a pending row whose local clock is NULL (search `pendingUnorderable` in `sync_service.dart`). If that row is skipped earlier with `continue` rather than through `pendingUnorderable`, keep the test and adjust only its comment to name the branch that keeps the row; the expectation (`SER-1`) holds either way.

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/core/services/sync/child_clear_merge_test.dart`
Expected: the first two tests FAIL (`transmitterSerial` is still `'SER-1'`); the other five PASS already, since they pin today's behavior.

- [ ] **Step 4: Write the implementation**

In `sync_service.dart`, add the import in the `package:submersion/core/services/sync/...` block:

```dart
import 'package:submersion/core/services/sync/child_column_clears.dart';
```

Next to `final toUpsert = <Map<String, dynamic>>[];` in `_mergeEntity`, add:

```dart
    // A parent-gated child's deliberate clears, by record id: written after
    // the batched upsert, which drops nulls (#2644).
    final childClears = <String, Set<String>>{};
```

In the clockless branch, replace:

```dart
          if (factGroups.isEmpty) {
            if (!rowFromRemote) continue;
            toUpsert.add(recordToApply);
            applied += 1;
            continue;
          }
```

with:

```dart
          if (factGroups.isEmpty) {
            if (!rowFromRemote) continue;
            toUpsert.add(recordToApply);
            applied += 1;
            final cleared = _childClears(entityType, recordToApply, local);
            if (cleared.isNotEmpty) childClears[recordId] = cleared;
            continue;
          }
```

Directly after the closing `}` of the `for (final w in factWrites) { ... }` loop, add:

```dart
    // Rethrown for the same reason as the fact writes: the batch has already
    // written each row with the peer's clock, so a swallowed failure would
    // leave the row looking applied, the next copy would tie, and the clear
    // would be lost for good. Throwing rolls the payload back so the
    // changeset is re-applied next sync.
    if (!batchFailed && childClears.isNotEmpty) {
      try {
        await _serializer.clearChildColumns(entityType, childClears);
      } catch (e, stackTrace) {
        _log.error(
          'Failed to write cleared columns for $entityType; rolling back the '
          'payload so the changeset is re-applied next sync',
          error: e,
          stackTrace: stackTrace,
        );
        rethrow;
      }
    }
```

Directly above `Hlc? _extractHlc(Map<String, dynamic>? data) => ...`, add:

```dart
  /// The keys a parent-gated child's [remote] copy clears on [local]: its
  /// explicit nulls, when the copy's clock is strictly newer (#2644). Empty
  /// for anything else, including a row this device does not have yet.
  Set<String> _childClears(
    String entityType,
    Map<String, dynamic> remote,
    Map<String, dynamic>? local,
  ) {
    if (local == null ||
        !SyncDataSerializer.parentGatedChildEntities.contains(entityType)) {
      return const {};
    }
    if (!isNewerChildCopy(
      remote: _extractHlc(remote),
      local: _extractHlc(local),
    )) {
      return const {};
    }
    return explicitlyClearedKeys(remote: remote, local: local);
  }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/core/services/sync/child_clear_merge_test.dart test/core/services/sync/child_hlc_test.dart`
Expected: PASS (all).

- [ ] **Step 6: Pin the rollback and align the spec**

Append inside `main()` of `child_clear_merge_test.dart`:

```dart
  test('a failing clear rolls the payload back', () async {
    // Makes the clear pass itself fail after the upsert has landed.
    await db.customStatement(
      'CREATE TEMP TRIGGER fail_clear BEFORE UPDATE OF transmitter_serial '
      'ON dive_tanks WHEN NEW.transmitter_serial IS NULL '
      "BEGIN SELECT RAISE(ABORT, 'boom'); END",
    );
    addTearDown(
      () => db.customStatement('DROP TRIGGER IF EXISTS fail_clear'),
    );
    await pullPeerPayload(
      cloud,
      SyncData(
        diveTanks: [
          {
            ...local,
            'transmitterSerial': null,
            'hlc': shifted(1000).toString(),
          },
        ],
      ),
    );
    final row = (await SyncDataSerializer().fetchRecord('diveTanks', 't1'))!;
    // Rolled back: the peer's clock did not land, so the next sync re-pulls
    // the changeset and the clear still wins then.
    expect(row['hlc'], local['hlc']);
    expect(row['transmitterSerial'], 'SER-1');
  });
```

Run: `flutter test test/core/services/sync/child_clear_merge_test.dart`
Expected: PASS. The sync itself reports an error status here, which is the point; the test asserts only the database state. If `row['hlc']` equals the peer's clock instead, this path is not wrapped in a transaction: stop and report it rather than weakening the assertion.

In the spec, replace:

```
If it throws, the
  batch counts as failed, the same accounting as a failed upsert.
```

with:

```
If it throws, the
  failure is rethrown so the payload rolls back and is re-applied next sync,
  the same handling as the media fact writes: the upsert already wrote the
  peer's clock, so counting the batch failed would lose the clear.
```

- [ ] **Step 7: Run the sync suites**

Run: `flutter test test/core/services/sync test/integration/sync test/features/dive_log/integration/consolidation_sync_roundtrip_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
dart format lib/core/services/sync/sync_service.dart test/core/services/sync/child_clear_merge_test.dart test/helpers/peer_pull.dart
git add lib/core/services/sync/sync_service.dart test/core/services/sync/child_clear_merge_test.dart test/helpers/peer_pull.dart docs/superpowers/specs/2026-09-30-clockless-child-clear-sync-design.md
git commit -m "fix(sync): a newer peer copy clears a child column it set to null

Refs #2644"
```

---

### Task 4: Consolidation stamps the tank computer backfill

**Files:**
- Create: `test/helpers/clock_expectations.dart`
- Modify: `lib/features/dive_log/data/services/dive_consolidation_service.dart:116-119`
- Test: `test/features/dive_log/data/services/dive_consolidation_service_test.dart`

**Interfaces:**
- Consumes: `SyncRepository.issueRowClock()` (`Future<String>`), through the service's existing field `final _sync = SyncRepository();`.
- Produces: `void expectFresherClock(String? before, String? after)` in `test/helpers/clock_expectations.dart` (used by Tasks 4 to 7).

- [ ] **Step 1: Create the clock expectation helper**

`test/helpers/clock_expectations.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/hlc.dart';

/// A write that sets a child value must give the row a clock newer than the
/// one it had, or a peer's newer copy of the row (still without the value)
/// clears it again under the clock-gated clear rule (#2644).
void expectFresherClock(String? before, String? after) {
  expect(after, isNotNull, reason: 'the write must stamp the row');
  if (before != null) {
    expect(
      Hlc.parse(after!).compareTo(Hlc.parse(before)),
      greaterThan(0),
      reason: 'the write must restamp the row, not keep its old clock',
    );
  }
}
```

- [ ] **Step 2: Write the failing test**

Add to `dive_consolidation_service_test.dart`, directly after the test `scenario 4: stamps pre-existing target children with the primary computer on first consolidation`, and add `import '../../../../helpers/clock_expectations.dart';` to the imports:

```dart
    test('the tank computer backfill carries a fresh clock (#2644)', () async {
      await seedDive(
        't',
        entry: DateTime.utc(2026, 7, 1, 9),
        computerId: 'comp-t',
        serial: 'SER-T',
        tanks: [tank('tank-t1', o2: 21)],
      );
      await seedDive(
        's',
        entry: DateTime.utc(2026, 7, 1, 9, 1),
        computerId: 'comp-s',
        serial: 'SER-S',
      );
      final before = await (db.select(
        db.diveTanks,
      )..where((t) => t.id.equals('tank-t1'))).getSingle();

      await service.apply(targetDiveId: 't', secondaryDiveIds: ['s']);

      final after = await (db.select(
        db.diveTanks,
      )..where((t) => t.id.equals('tank-t1'))).getSingle();
      expect(after.computerId, 'comp-t');
      expectFresherClock(before.hlc, after.hlc);
    });
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/dive_log/data/services/dive_consolidation_service_test.dart --plain-name "fresh clock (#2644)"`
Expected: FAIL (`after.hlc` is null or unchanged). If it passes, some other step in `apply` already restamps the tank: stop and report which, since the fix would then be unnecessary.

- [ ] **Step 4: Write the implementation**

In `dive_consolidation_service.dart`, replace:

```dart
        await (_db.update(_db.diveTanks)..where(
              (t) => t.diveId.equals(targetDiveId) & t.computerId.isNull(),
            ))
            .write(DiveTanksCompanion(computerId: Value(targetRow.computerId)));
```

with:

```dart
        // With a fresh clock, like the events below: a peer's newer copy of
        // the tank, still without a computer, would otherwise clear it
        // (#2644).
        await (_db.update(_db.diveTanks)..where(
              (t) => t.diveId.equals(targetDiveId) & t.computerId.isNull(),
            ))
            .write(
              DiveTanksCompanion(
                computerId: Value(targetRow.computerId),
                hlc: Value(await _sync.issueRowClock()),
              ),
            );
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/data/services/dive_consolidation_service_test.dart test/features/dive_log/integration/consolidation_sync_roundtrip_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/dive_log/data/services/dive_consolidation_service.dart test/features/dive_log/data/services/dive_consolidation_service_test.dart test/helpers/clock_expectations.dart
git add lib/features/dive_log/data/services/dive_consolidation_service.dart test/features/dive_log/data/services/dive_consolidation_service_test.dart test/helpers/clock_expectations.dart
git commit -m "fix(consolidation): stamp the tank computer backfill with a fresh clock

Refs #2644"
```

---

### Task 5: Computer merge stamps re-pointed tanks and sources

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_computer_merge_repository.dart:313-317` (`_repointDiveOwnedTables`)
- Test: `test/features/dive_log/data/repositories/dive_computer_merge_repository_test.dart`

**Interfaces:**
- Consumes: `expectFresherClock` (Task 4); the repository's field `final SyncRepository _syncRepository;`.
- Produces: nothing new.

- [ ] **Step 1: Write the failing test**

Add `import '../../../../helpers/clock_expectations.dart';` to the imports, and inside `main()` add:

```dart
  test('re-pointed tanks and data sources carry a fresh clock (#2644)',
      () async {
    await insertComputer(id: 'a');
    await insertComputer(id: 'b', name: 'ssss');
    await insertDive('d1', computerId: 'b');
    await insertDataSource('ds1', diveId: 'd1', computerId: 'b');
    await insertTank('t1', diveId: 'd1', computerId: 'b');
    Future<String?> hlcOf(String table, String id) async => (await db
            .customSelect(
              'SELECT hlc FROM $table WHERE id = ?',
              variables: [Variable.withString(id)],
            )
            .getSingle())
        .read<String?>('hlc');
    final tankBefore = await hlcOf('dive_tanks', 't1');
    final sourceBefore = await hlcOf('dive_data_sources', 'ds1');

    await repository.mergeComputers(survivorId: 'a', duplicateIds: ['b']);

    expectFresherClock(tankBefore, await hlcOf('dive_tanks', 't1'));
    expectFresherClock(sourceBefore, await hlcOf('dive_data_sources', 'ds1'));
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/dive_computer_merge_repository_test.dart --plain-name "fresh clock (#2644)"`
Expected: FAIL (the `hlc` is null or unchanged).

- [ ] **Step 3: Write the implementation**

In `_repointDiveOwnedTables`, replace:

```dart
    await (_db.update(_db.diveDataSources)
          ..where((t) => t.computerId.isIn(fromIds)))
        .write(db.DiveDataSourcesCompanion(computerId: Value(toId)));
    await (_db.update(_db.diveTanks)..where((t) => t.computerId.isIn(fromIds)))
        .write(db.DiveTanksCompanion(computerId: Value(toId)));
```

with:

```dart
    // Fresh clocks on the moved sources and tanks, like the events below:
    // this is an edit to them, and a peer's newer copy still naming the old
    // computer, or none, must not win over it (#2644).
    final repointedAt = await _syncRepository.issueRowClock();
    await (_db.update(_db.diveDataSources)
          ..where((t) => t.computerId.isIn(fromIds)))
        .write(
          db.DiveDataSourcesCompanion(
            computerId: Value(toId),
            hlc: Value(repointedAt),
          ),
        );
    await (_db.update(_db.diveTanks)..where((t) => t.computerId.isIn(fromIds)))
        .write(
          db.DiveTanksCompanion(
            computerId: Value(toId),
            hlc: Value(repointedAt),
          ),
        );
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/data/repositories/dive_computer_merge_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_log/data/repositories/dive_computer_merge_repository.dart test/features/dive_log/data/repositories/dive_computer_merge_repository_test.dart
git add lib/features/dive_log/data/repositories/dive_computer_merge_repository.dart test/features/dive_log/data/repositories/dive_computer_merge_repository_test.dart
git commit -m "fix(dive-computer): stamp tanks and sources a computer merge re-points

Refs #2644"
```

---

### Task 6: Orphan relink stamps the relinked sources

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart:545-548` (`_relinkOrphanedRows`)
- Test: `test/features/dive_log/data/repositories/dive_computer_repository_impl_test.dart` (group `createComputer relinking`)

**Interfaces:**
- Consumes: `expectFresherClock` (Task 4); the repository's field `final SyncRepository _syncRepository = SyncRepository();`.
- Produces: nothing new.

- [ ] **Step 1: Write the failing test**

Add `import '../../../../helpers/clock_expectations.dart';` to the imports, and inside the `createComputer relinking` group add:

```dart
    test('relinked sources carry a fresh clock (#2644)', () async {
      final oldId = await insertComputer(
        manufacturer: 'Shearwater',
        model: 'Perdix',
        serialNumber: 'SN-12345',
      );
      final diveId = await insertDive(computerId: oldId);
      await insertDataSource(
        diveId: diveId,
        computerId: oldId,
        isPrimary: true,
        computerModel: 'Shearwater Perdix',
        computerSerial: 'SN-12345',
        sourceFormat: 'dive_computer',
      );
      await repository.deleteComputer(oldId);
      Future<DiveDataSourcesData> source() => (db.select(
        db.diveDataSources,
      )..where((t) => t.diveId.equals(diveId))).getSingle();
      final before = await source();

      final created = await repository.createComputer(newComputer());

      final after = await source();
      expect(after.computerId, created.id);
      expectFresherClock(before.hlc, after.hlc);
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/dive_computer_repository_impl_test.dart --plain-name "fresh clock (#2644)"`
Expected: FAIL (the `hlc` is null or unchanged).

- [ ] **Step 3: Write the implementation**

In `_relinkOrphanedRows`, replace:

```dart
      await _db.customStatement(
        'UPDATE dive_data_sources SET computer_id = ? WHERE id IN ($sourcePh)',
        [computerId, ...sourceIds],
      );
```

with:

```dart
      // With a fresh clock: a peer's newer copy of the source, still
      // orphaned, would otherwise clear the link again (#2644).
      await _db.customStatement(
        'UPDATE dive_data_sources SET computer_id = ?, hlc = ? '
        'WHERE id IN ($sourcePh)',
        [computerId, await _syncRepository.issueRowClock(), ...sourceIds],
      );
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/data/repositories/dive_computer_repository_impl_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart test/features/dive_log/data/repositories/dive_computer_repository_impl_test.dart
git add lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart test/features/dive_log/data/repositories/dive_computer_repository_impl_test.dart
git commit -m "fix(dive-computer): stamp data sources an orphan relink reattaches

Refs #2644"
```

---

### Task 7: Download stamps the tank pressure fill

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart:1840-1852` (the `cleanSeriesEndpoints` fill inside `importProfile`)
- Test: `test/features/dive_log/data/repositories/dive_computer_multi_transmitter_pressure_test.dart`

**Interfaces:**
- Consumes: `expectFresherClock` (Task 4); the same `_syncRepository` field as Task 6.
- Produces: nothing new.

- [ ] **Step 1: Write the failing test**

Add `import '../../../../helpers/clock_expectations.dart';` to the imports, and inside `main()` add:

```dart
  test('a tank pressure filled from its series carries a clock (#2644)',
      () async {
    final computerId = await insertComputer();

    final diveId = await repository.importProfile(
      computerId: computerId,
      profileStartTime: DateTime(2026, 8, 15, 16, 27),
      points: const [
        ProfilePointData(timestamp: 0, depth: 0.0, tankPressures: [192.6]),
        ProfilePointData(timestamp: 1200, depth: 5.0, tankPressures: [162.7]),
      ],
      durationSeconds: 1800,
      maxDepth: 27.2,
      tanks: const [TankData(index: 0, o2Percent: 21.0)],
    );

    final tank = (await tanksFor(diveId)).single;
    expect(tank.startPressure, 192.6);
    expectFresherClock(null, tank.hlc);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/dive_computer_multi_transmitter_pressure_test.dart --plain-name "carries a clock (#2644)"`
Expected: FAIL (`tank.hlc` is null: the fill writes no clock and the insert stamped none).

- [ ] **Step 3: Write the implementation**

In the fill, replace the companion:

```dart
                DiveTanksCompanion(
                  startPressure: tank.startPressure == null
                      ? Value(endpoints.start)
                      : const Value.absent(),
                  endPressure: tank.endPressure == null
                      ? Value(endpoints.end)
                      : const Value.absent(),
                ),
```

with:

```dart
                DiveTanksCompanion(
                  startPressure: tank.startPressure == null
                      ? Value(endpoints.start)
                      : const Value.absent(),
                  endPressure: tank.endPressure == null
                      ? Value(endpoints.end)
                      : const Value.absent(),
                  // The tank was inserted with no clock; without one, any
                  // peer's stamped copy is newer and could clear these
                  // pressures (#2644).
                  hlc: Value(await _syncRepository.issueRowClock()),
                ),
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/data/repositories/dive_computer_multi_transmitter_pressure_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart test/features/dive_log/data/repositories/dive_computer_multi_transmitter_pressure_test.dart
git add lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart test/features/dive_log/data/repositories/dive_computer_multi_transmitter_pressure_test.dart
git commit -m "fix(dive-computer): stamp tank pressures a download fills from its series

Refs #2644"
```

---

### Task 8: End to end, the issue's two cases

A peer is modelled in one database: the origin's real write produces the copy it would publish; the local row is then rewound to what a peer still holds (old value, old clock, nothing pending), and the published copy is pulled through `performSync`. Nothing pending on the rewound row matters: a pending row with no clock keeps its own fields, and a real peer has nothing pending for it.

**Files:**
- Test: `test/features/dive_computer/data/services/reparse_service_sync_test.dart`
- Test: `test/features/dive_log/data/services/dive_split_service_test.dart`

**Interfaces:**
- Consumes: `pullPeerPayload` (Task 3); the merge rule (Task 3).
- Produces: nothing new.

- [ ] **Step 1: Write the reparse test**

In `reparse_service_sync_test.dart`, add these imports:

```dart
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/peer_pull.dart';
```

and inside `main()`:

```dart
  test('a transmitter serial the re-parse clears is cleared on a peer '
      '(#2644)', () async {
    await seedPublishedDive();
    await db.customStatement(
      "UPDATE dive_tanks SET transmitter_serial = '111111' WHERE id = 'kept'",
    );
    final watermark = await publishEverything();
    final published = (await serializer.fetchRecord('diveTanks', 'kept'))!;

    // parsedDive() reports no transmitter serial for tank 0.
    await reparse();

    final sent = (await nextChangeset(watermark)).data.diveTanks.singleWhere(
      (t) => t['id'] == 'kept',
    );
    expect(sent.containsKey('transmitterSerial'), isTrue);
    expect(sent['transmitterSerial'], isNull);

    // A peer still holding the tank as it was published.
    await db.customUpdate(
      'UPDATE dive_tanks SET transmitter_serial = ?, hlc = ? WHERE id = ?',
      variables: [
        Variable.withString('111111'),
        Variable<String>(published['hlc'] as String?),
        Variable.withString('kept'),
      ],
    );
    await db.customStatement('DELETE FROM sync_records');

    final result = await pullPeerPayload(
      FakeCloudStorageProvider(),
      SyncData(diveTanks: [sent]),
    );
    expect(result.status, isNot(SyncResultStatus.error));
    final onPeer = (await serializer.fetchRecord('diveTanks', 'kept'))!;
    expect(onPeer['transmitterSerial'], isNull);
  });
```

- [ ] **Step 2: Write the split test**

In `dive_split_service_test.dart`, add these imports:

```dart
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/peer_pull.dart';
```

and inside `main()`, directly after the test `a deduped shared tank stays behind with attribution cleared while a clone carries the departing pressures`:

```dart
  test('the computer a split clears on a shared tank is cleared on a peer '
      '(#2644)', () async {
    await insertDive('dive-1', computerId: 'dc-a');
    await insertSource('src-a', 'dive-1', 'dc-a', isPrimary: true);
    await insertSource('src-b', 'dive-1', 'dc-b', isPrimary: false);
    await insertProfileSeriesRow('dive-1', 'dc-a', isPrimary: true);
    await insertProfileSeriesRow('dive-1', 'dc-b', isPrimary: false);
    final sharedTank = await insertTank('dive-1', 'dc-b');
    await insertTankPressureSeriesRow('dive-1', sharedTank, 'dc-a');
    await insertTankPressureSeriesRow('dive-1', sharedTank, 'dc-b');
    final serializer = SyncDataSerializer();
    final published = (await serializer.fetchRecord('diveTanks', sharedTank))!;

    await service.split(diveId: 'dive-1', sourceId: 'src-b');

    // What the split publishes for the tank: it is marked pending, so the
    // next changeset carries this row.
    final sent = (await serializer.fetchRecord('diveTanks', sharedTank))!;
    expect(sent['computerId'], isNull);

    // A peer still holding the tank as it was before the split.
    await db.customUpdate(
      'UPDATE dive_tanks SET computer_id = ?, hlc = ? WHERE id = ?',
      variables: [
        Variable.withString('dc-b'),
        Variable<String>(published['hlc'] as String?),
        Variable.withString(sharedTank),
      ],
    );
    await db.customStatement('DELETE FROM sync_records');

    final result = await pullPeerPayload(
      FakeCloudStorageProvider(),
      SyncData(diveTanks: [sent]),
    );
    expect(result.status, isNot(SyncResultStatus.error));
    final onPeer = (await serializer.fetchRecord('diveTanks', sharedTank))!;
    expect(onPeer['computerId'], isNull);
  });
```

- [ ] **Step 3: Run the tests**

Run: `flutter test test/features/dive_computer/data/services/reparse_service_sync_test.dart test/features/dive_log/data/services/dive_split_service_test.dart`
Expected: PASS (Task 3 is already in).

- [ ] **Step 4: Red check against the merge rule**

Copy `lib/core/services/sync/sync_service.dart` to the scratchpad as a backup. In it, make `_childClears` return `const {}` on its first line, then rerun Step 3's command.
Expected: both new tests FAIL (the old value survives on the peer). Restore the file from the backup copy (never with `git checkout`, which would also discard uncommitted work) and rerun Step 3's command: PASS.

- [ ] **Step 5: Commit**

```bash
dart format test/features/dive_computer/data/services/reparse_service_sync_test.dart test/features/dive_log/data/services/dive_split_service_test.dart
git add test/features/dive_computer/data/services/reparse_service_sync_test.dart test/features/dive_log/data/services/dive_split_service_test.dart
git commit -m "test(sync): a re-parse's and a split's child clears reach a peer

Refs #2644"
```

---

### Task 9: Whole-branch verification

**Files:** none new.

- [ ] **Step 1: Format and analyze**

Run: `dart format .` then `flutter analyze`
Expected: no changes from format (everything was formatted per task); analyze reports `No issues found!`. CI treats infos as fatal, so fix any info too.

- [ ] **Step 2: Architecture guards**

Run: `flutter test test/architecture`
Expected: PASS.

- [ ] **Step 3: Full suite, once**

Check the RAM-disk temp space first: `df -h /Volumes/fltmp` (the suite hangs silently if it is full). Then run `flutter test` with no path, and read the exit status directly (do not pipe it through `grep`, which hides the status).
Expected: exit 0. A sync-apply change touches every entity's consumers, so the targeted suites are not enough.

- [ ] **Step 4: Em-dash scan of the branch diff**

Run: `git diff main...HEAD | grep -nP '^\+.*[\x{2013}\x{2014}]'`
Expected: no output (the pattern matches an added line containing an en-dash or em-dash; a numeric range would be allowed, but none is expected here).

- [ ] **Step 5: Report**

Stop here and report to the user with the full-suite result. Opening the PR, and filing the separate issue for the undo paths that restore an older `hlc`, happen only when the user asks.
