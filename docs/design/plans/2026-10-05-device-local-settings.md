# Device-local Notification and Appearance Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep notification settings, theme mode and the nav layout on each device instead of syncing them, without resetting anyone's current values, and document what syncs.

**Architecture:** One shared list (`device_local_fields.dart`) names the device-local `diver_settings` columns and `settings` keys. The sync serializer strips those columns from every row it exports or fetches, and on import refills them from this device (the local row, else a replace-adopt snapshot). Device-local `settings` keys are filtered on export and skipped on import. The settings repositories write device-local-only changes without stamping a sync clock or queuing the row.

**Tech Stack:** Flutter, Drift (SQLite), flutter_test.

**Spec:** `docs/design/specs/2026-10-05-device-local-settings-design.md`

## Global Constraints

- Device-local `diverSettings` wire keys: `notificationsEnabled`, `serviceReminderDays`, `reminderTime`, `tripServiceLeadDays`, `themeMode`.
- Device-local `settings` keys: `active_diver_id`, `nav_primary_ids`, `nav_rail_ids`, `nav_always_hide_labels`.
- Theme preset, accents, map style and language keep syncing.
- No schema change, no migration, no backfill.
- No Settings screen changes.
- No em-dashes anywhere (code, comments, docs, commits). No emojis.
- Imports grouped dart, flutter, packages, local; `dart format .` before each commit.
- Paths in tests via `p.join`, temp space via `Directory.systemTemp` (none expected here).
- Tests that replace process-wide state restore it (`DatabaseService.instance.resetForTesting()` / `tearDownTestDatabase` as the existing files do).
- Run `flutter test test/architecture/` after adding the new `lib/` file.

## Review Focus

1. A peer on an older build sends a full `diverSettings` row (all five columns, newer clock): local values must survive, synced columns must apply. Pinned in Task 3 (single and batch upsert).
2. A replace-adopt on this device (streaming: clear then refill): theme mode, reminders and BLE addresses must come back as they were. Pinned in Task 2 (BLE) and Task 3 (diver settings).
3. A save that changes theme mode together with a synced setting must still sync the synced setting. Pinned in Task 5 (mixed save).
4. A conflict card for a `diverSettings` row must not show device-local columns as differences: `fetchRecord` strips them like the remote side. Pinned in Task 3 (`fetchRecord` / `fetchRecords` omit).
5. Media upload quality keys and `share_new_records_by_default` must keep syncing (the device-local key list must stay targeted). Pinned by the existing tripwire test in `sync_device_local_settings_test.dart` and a synced-key check in Task 5.

---

## File Structure

- Create `lib/core/services/sync/device_local_fields.dart`: the two lists plus `isDeviceLocalColumn` and `withoutDeviceLocalColumns`. Single source of truth for serializer, sync service and repositories.
- Modify `lib/core/services/sync/sync_data_serializer.dart`: use the shared list; strip `diverSettings` on export/fetch; refill device-local columns on import; snapshot them on replace-adopt clear.
- Modify `lib/core/services/sync/sync_service.dart`: replace its private `_withoutDeviceLocalFields` with the shared function.
- Modify `lib/features/settings/data/repositories/diver_settings_repository.dart`: device-local-only save path.
- Modify `lib/features/settings/data/repositories/app_settings_repository.dart`: no sync queue for device-local keys.
- Modify `docs/guide/multi-device-sync.md`: new section.
- Tests: create `test/core/services/sync/device_local_fields_test.dart`, `test/core/services/sync/sync_device_local_columns_test.dart`; extend `test/core/services/sync/sync_device_local_settings_test.dart`, `test/features/settings/data/repositories/diver_settings_repository_partial_write_test.dart`, `test/features/settings/data/repositories/app_settings_repository_nav_test.dart`.

---

### Task 1: Shared device-local list

**Files:**
- Create: `lib/core/services/sync/device_local_fields.dart`
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (remove `_withoutDeviceLocalFields` near line 8398, `_deviceLocalSettingsKeys` near 8442, `_deviceLocalKeys` near 9032; update every caller)
- Modify: `lib/core/services/sync/sync_service.dart` (remove `_withoutDeviceLocalFields` near line 3504; callers near 3128 and 3736)
- Test: `test/core/services/sync/device_local_fields_test.dart`

**Interfaces:**
- Produces:
  - `const Map<String, Set<String>> deviceLocalSyncColumns` (entity type to wire keys)
  - `const Set<String> deviceLocalSettingsKeys`
  - `bool isDeviceLocalColumn(String entityType, String sqlName)`
  - `Map<String, dynamic> withoutDeviceLocalColumns(String entityType, Map<String, dynamic> data)` (returns `data` itself when nothing to strip)

This task is a refactor: the lists hold only today's entries (`bluetoothAddress`, `active_diver_id`). Tasks 3 and 4 add the new ones.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/device_local_fields.dart';

void main() {
  group('withoutDeviceLocalColumns', () {
    test('drops the device-local keys of the entity type', () {
      final stripped = withoutDeviceLocalColumns('diveComputers', {
        'id': 'c1',
        'name': 'Perdix',
        'bluetoothAddress': 'AA:BB',
      });
      expect(stripped, {'id': 'c1', 'name': 'Perdix'});
    });

    test('returns the same map when there is nothing to strip', () {
      final data = {'id': 'c1', 'name': 'Perdix'};
      expect(identical(withoutDeviceLocalColumns('diveComputers', data), data),
          isTrue);
      final dive = {'id': 'd1', 'bluetoothAddress': 'kept'};
      expect(identical(withoutDeviceLocalColumns('dives', dive), dive), isTrue,
          reason: 'only the listed entity type loses the key');
    });
  });

  test('isDeviceLocalColumn matches SQL column names', () {
    expect(isDeviceLocalColumn('diveComputers', 'bluetooth_address'), isTrue);
    expect(isDeviceLocalColumn('diveComputers', 'name'), isFalse);
    expect(isDeviceLocalColumn('dives', 'bluetooth_address'), isFalse);
  });

  test('active_diver_id is a device-local settings key', () {
    expect(deviceLocalSettingsKeys, contains('active_diver_id'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/sync/device_local_fields_test.dart`
Expected: FAIL, `device_local_fields.dart` does not exist.

- [ ] **Step 3: Create the shared file**

```dart
import 'package:submersion/core/services/sync/child_column_clears.dart';

/// Columns a synced row never carries, by entity type and wire (JSON) key,
/// because their value belongs to one device rather than to the library.
///
/// Export strips them, import refills them from this device, and a save that
/// changes only these columns stamps no sync clock (issue #2947).
const Map<String, Set<String>> deviceLocalSyncColumns = {
  // A host's BLE identifier for a computer; another host's never applies.
  'diveComputers': {'bluetoothAddress'},
};

/// Keys of the key/value `settings` table that stay on this device.
///
/// Rule for a new key: "is this answer the same across all of one user's
/// devices?" If not, add it here. Keys known to sync on purpose:
/// `share_new_records_by_default`, the media upload quality keys,
/// `gas_blender_prefs`, `equipment_arrangement`.
const Set<String> deviceLocalSettingsKeys = {
  // Each device auto-creates its own owner diver at first launch.
  'active_diver_id',
};

/// Whether the SQL column [sqlName] of [entityType]'s table is device-local.
bool isDeviceLocalColumn(String entityType, String sqlName) =>
    deviceLocalSyncColumns[entityType]?.contains(columnJsonKey(sqlName)) ??
    false;

/// [data] without the device-local keys of [entityType]; [data] itself when
/// it carries none.
Map<String, dynamic> withoutDeviceLocalColumns(
  String entityType,
  Map<String, dynamic> data,
) {
  final keys = deviceLocalSyncColumns[entityType];
  if (keys == null || !keys.any(data.containsKey)) return data;
  return {
    for (final entry in data.entries)
      if (!keys.contains(entry.key)) entry.key: entry.value,
  };
}
```

- [ ] **Step 4: Point the serializer and sync service at it**

In `sync_data_serializer.dart`, add `import 'package:submersion/core/services/sync/device_local_fields.dart';` with the other `core/services/sync` imports, then:
- Delete `_withoutDeviceLocalFields` (and its doc comment), `_deviceLocalSettingsKeys` (move nothing; its audit comment now lives on `deviceLocalSettingsKeys`), and `_deviceLocalKeys` (with its doc comment).
- `_withoutDeviceLocalFields(row.toJson())` and `_withoutDeviceLocalFields(r.toJson())` in the `diveComputers` cases of `fetchRecord`, `fetchRecords` and `_exportDiveComputers` become `withoutDeviceLocalColumns('diveComputers', row.toJson())` / `(..., r.toJson())`.
- `_withoutDeviceLocalFields(data, entityType: entityType)` in `upsertRecord` and `_withoutDeviceLocalFields(record, entityType: entityType)` in `upsertRecords` become `withoutDeviceLocalColumns(entityType, data)` / `(entityType, record)`.
- `_deviceLocalKeys[entityType]` in `_buildRowKeys` becomes `deviceLocalSyncColumns[entityType]`, and its doc reference `[_withoutDeviceLocalFields]` becomes `[withoutDeviceLocalColumns]`.
- Every `_deviceLocalSettingsKeys` (the `settings` cases of `upsertRecord`, `upsertRecords`, `deleteAllRecords`, `_exportSettings`, and the `[_deviceLocalSettingsKeys]` doc references) becomes `deviceLocalSettingsKeys`.

In `sync_service.dart`, add the same import, delete `_withoutDeviceLocalFields`, and replace its two calls with `withoutDeviceLocalColumns(entityType, record)` and `withoutDeviceLocalColumns(entityType, _parseConflictData(match.conflictData!))`.

Verify nothing references the old names:

Run: `grep -rn "_withoutDeviceLocalFields\|_deviceLocalKeys\|_deviceLocalSettingsKeys" lib test`
Expected: no output (the test comment in `sync_device_local_settings_test.dart` near line 121 mentions `_deviceLocalSettingsKeys`; change it to `deviceLocalSettingsKeys`).

- [ ] **Step 5: Run tests**

Run: `flutter analyze lib/core/services/sync test/core/services/sync/device_local_fields_test.dart && flutter test test/core/services/sync/device_local_fields_test.dart test/core/services/sync/sync_device_local_settings_test.dart test/core/services/sync/sync_serializer_fetch_record_test.dart test/architecture/`
Expected: no analyzer issues; all PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/core/services/sync test/core/services/sync
git add lib/core/services/sync/device_local_fields.dart lib/core/services/sync/sync_data_serializer.dart lib/core/services/sync/sync_service.dart test/core/services/sync/device_local_fields_test.dart test/core/services/sync/sync_device_local_settings_test.dart
git commit -m "refactor(sync): keep the device-local field lists in one shared file"
```

---

### Task 2: Import refills device-local columns from this device

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (`upsertRecord`, `upsertRecords`, `deleteAllRecords`, new private helpers next to `_withLocalForOmitted`)
- Test: `test/core/services/sync/sync_device_local_columns_test.dart` (create)

**Interfaces:**
- Consumes: `deviceLocalSyncColumns`, `withoutDeviceLocalColumns` (Task 1); `syncRecordId(String entityType, Map<String, dynamic> record)` from `sync_record_overlay.dart`.
- Produces (private to the serializer): `Future<Map<String, Map<String, dynamic>>> _deviceLocalValuesHere(String entityType, [Iterable<String>? ids])`, `Future<List<Map<String, dynamic>>> _withDeviceLocalFromHere(String entityType, List<Map<String, dynamic>> records)`, field `final Map<String, Map<String, Map<String, dynamic>>> _adoptKeptDeviceLocal`.

Today an incoming `diveComputers` row is stripped of `bluetoothAddress`, `fromJson` reads the missing key as null, and the full-row upsert writes NULL over this host's address. These tests should fail before Step 3. If the first test passes, stop and report: something else already preserves the address and the design note in the spec is wrong.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// Columns listed in deviceLocalSyncColumns belong to this device: an
/// incoming row, from any peer and through any write path, never changes
/// them (issue #2947).
void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });

  tearDown(tearDownTestDatabase);

  group('diveComputers.bluetoothAddress', () {
    Future<Map<String, dynamic>> seedComputer() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.customStatement(
        'INSERT INTO dive_computers (id, name, bluetooth_address, created_at, '
        "updated_at) VALUES ('c1', 'Perdix', 'AA:BB', $now, $now)",
      );
      final row = await (db.select(
        db.diveComputers,
      )..where((t) => t.id.equals('c1'))).getSingle();
      return row.toJson();
    }

    Future<String?> storedAddress() async => (await (db.select(
      db.diveComputers,
    )..where((t) => t.id.equals('c1'))).getSingle()).bluetoothAddress;

    test('upsertRecord keeps the local address', () async {
      final local = await seedComputer();
      await serializer.upsertRecord('diveComputers', {
        ...local,
        'name': 'Perdix 2',
        'bluetoothAddress': 'CC:DD',
        'updatedAt': (local['updatedAt'] as int) + 1000,
      });
      final row = await (db.select(
        db.diveComputers,
      )..where((t) => t.id.equals('c1'))).getSingle();
      expect(row.name, 'Perdix 2');
      expect(row.bluetoothAddress, 'AA:BB');
    });

    test('upsertRecords keeps the local address', () async {
      final local = await seedComputer();
      await serializer.upsertRecords('diveComputers', [
        {...local, 'bluetoothAddress': null},
      ]);
      expect(await storedAddress(), 'AA:BB');
    });

    test('a replace-adopt clear and refill keeps the local address', () async {
      final local = await seedComputer();
      await serializer.deleteAllRecords('diveComputers');
      await serializer.upsertRecords('diveComputers', [
        withoutAddress(local),
      ]);
      expect(await storedAddress(), 'AA:BB');
    });

    test('a computer new to this device has no address', () async {
      final local = await seedComputer();
      await serializer.upsertRecord('diveComputers', {
        ...local,
        'id': 'c2',
        'bluetoothAddress': 'EE:FF',
      });
      final row = await (db.select(
        db.diveComputers,
      )..where((t) => t.id.equals('c2'))).getSingle();
      expect(row.bluetoothAddress, isNull);
    });
  });
}

Map<String, dynamic> withoutAddress(Map<String, dynamic> row) =>
    {...row}..remove('bluetoothAddress');
```

Before running, check `dive_computers` has no other NOT NULL column without a default: `grep -n "class DiveComputers" -A40 lib/core/database/tables/*.dart`. Add any such column to the INSERT.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/sync/sync_device_local_columns_test.dart`
Expected: the first three tests FAIL with `bluetoothAddress` null; the fourth PASSES.

- [ ] **Step 3: Implement the refill and the adopt snapshot**

In `sync_data_serializer.dart`, next to `_rowKeys`, add the field:

```dart
  /// Device-local columns [deleteAllRecords] read before a replace-adopt
  /// cleared their table, by entity type and record id. The refill consumes
  /// an entry when its row comes back, so this device keeps its own values.
  final Map<String, Map<String, Map<String, dynamic>>> _adoptKeptDeviceLocal =
      {};
```

Next to `_withLocalForOmitted`, add:

```dart
  /// The device-local columns ([deviceLocalSyncColumns]) of [entityType]'s
  /// rows on this device, by record id; every row when [ids] is null.
  Future<Map<String, Map<String, dynamic>>> _deviceLocalValuesHere(
    String entityType, [
    Iterable<String>? ids,
  ]) async {
    final keys = deviceLocalSyncColumns[entityType];
    if (keys == null) return const {};
    final List<Map<String, dynamic>> rows;
    switch (entityType) {
      case 'diveComputers':
        final query = _db.select(_db.diveComputers);
        if (ids != null) query.where((t) => t.id.isIn(ids));
        rows = [for (final row in await query.get()) row.toJson()];
      default:
        throw StateError('No device-local column read for $entityType');
    }
    return {
      for (final row in rows)
        row['id'] as String: {for (final key in keys) key: row[key]},
    };
  }

  /// Fills each device-local column of [records] with this device's value:
  /// the row it holds, else what a replace-adopt cleared, else nothing (a row
  /// new here takes the column default). Stripping the wire values is not
  /// enough on its own: [_buildRowKeys] leaves these columns out, so
  /// [_withLocalForOmitted] would not refill them and the full-row upsert
  /// would write their defaults over this device's values.
  Future<List<Map<String, dynamic>>> _withDeviceLocalFromHere(
    String entityType,
    List<Map<String, dynamic>> records,
  ) async {
    if (!deviceLocalSyncColumns.containsKey(entityType)) return records;
    final ids = {
      for (final record in records) ?syncRecordId(entityType, record),
    };
    if (ids.isEmpty) return records;
    final here = await _deviceLocalValuesHere(entityType, ids);
    final kept = _adoptKeptDeviceLocal[entityType];
    final filled = <Map<String, dynamic>>[];
    for (final record in records) {
      final id = syncRecordId(entityType, record);
      final values = id == null ? null : (here[id] ?? kept?.remove(id));
      filled.add(values == null ? record : {...record, ...values});
    }
    return filled;
  }
```

In `upsertRecord`, after the strip and rename, before `_withSchemaDefaults`:

```dart
    data = _withRenamedKeys(
      entityType,
      withoutDeviceLocalColumns(entityType, data),
    );
    data = (await _withDeviceLocalFromHere(entityType, [data])).single;
    data = _withSchemaDefaults(
      entityType,
      (await _withLocalForOmitted(entityType, [data])).single,
    );
```

In `upsertRecords`:

```dart
    records = await _withLocalForOmitted(
      entityType,
      await _withDeviceLocalFromHere(entityType, [
        for (final record in records)
          _withRenamedKeys(
            entityType,
            withoutDeviceLocalColumns(entityType, record),
          ),
      ]),
    );
```

At the top of `deleteAllRecords`, before the `switch`:

```dart
    if (deviceLocalSyncColumns.containsKey(entityType)) {
      _adoptKeptDeviceLocal[entityType] = Map.of(
        await _deviceLocalValuesHere(entityType),
      );
    }
```

(`Map.of` because `_deviceLocalValuesHere` may return a const map, and the refill removes entries.)

Add a sentence to the `deleteAllRecords` doc comment: "Device-local columns ([deviceLocalSyncColumns]) of the cleared rows are remembered first, so the refill keeps this device's values."

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/sync/sync_device_local_columns_test.dart test/core/services/sync/sync_serializer_fetch_record_test.dart`
Then the adopt and merge suites most likely to notice: `flutter test test/core/services/sync/ --name "adopt|parity|omit|overlay"`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/core/services/sync test/core/services/sync
git add lib/core/services/sync/sync_data_serializer.dart test/core/services/sync/sync_device_local_columns_test.dart
git commit -m "fix(sync): keep a dive computer's local Bluetooth address when a peer's row is applied"
```

---

### Task 3: Notification settings and theme mode stay on the device

**Files:**
- Modify: `lib/core/services/sync/device_local_fields.dart` (add `diverSettings`)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (`diverSettings` cases of `fetchRecord` near 2635 and `fetchRecords` near 3193, `_exportDiverSettings` near 7449, `_deviceLocalValuesHere`)
- Test: `test/core/services/sync/sync_device_local_columns_test.dart` (extend), `test/core/services/sync/device_local_fields_test.dart` (extend)

**Interfaces:**
- Consumes: Task 1 lists, Task 2 `_deviceLocalValuesHere` / `_withDeviceLocalFromHere`.
- Produces: `deviceLocalSyncColumns['diverSettings']` = the five keys in Global Constraints.

- [ ] **Step 1: Write the failing tests**

Add to `device_local_fields_test.dart`:

```dart
  test('the notification settings and theme mode are device-local', () {
    expect(deviceLocalSyncColumns['diverSettings'], {
      'notificationsEnabled',
      'serviceReminderDays',
      'reminderTime',
      'tripServiceLeadDays',
      'themeMode',
    });
    expect(isDeviceLocalColumn('diverSettings', 'theme_mode'), isTrue);
    expect(isDeviceLocalColumn('diverSettings', 'theme_preset'), isFalse);
    expect(isDeviceLocalColumn('diverSettings', 'map_style'), isFalse);
    expect(isDeviceLocalColumn('diverSettings', 'locale'), isFalse);
  });
```

Add a group to `sync_device_local_columns_test.dart` (new imports: `package:flutter/material.dart` for `ThemeMode`/`TimeOfDay`, `package:submersion/core/data/repositories/sync_repository.dart`, `package:submersion/core/services/database_service.dart`, `package:submersion/core/services/sync/sync_service.dart`, `package:submersion/features/settings/data/repositories/diver_settings_repository.dart`, `package:submersion/features/settings/presentation/providers/settings_providers.dart`, `../../../helpers/changeset_test_helpers.dart`, `../../../helpers/fake_cloud_storage_provider.dart`):

```dart
  group('diverSettings notification settings and theme mode', () {
    const deviceLocal = {
      'notificationsEnabled',
      'serviceReminderDays',
      'reminderTime',
      'tripServiceLeadDays',
      'themeMode',
    };

    /// This device's choices, all different from the column defaults.
    Future<Map<String, dynamic>> seedSettings() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.divers).insert(
            DiversCompanion.insert(
              id: 'd1',
              name: 'Test Diver',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await DiverSettingsRepository().createSettingsForDiver(
        'd1',
        settings: const AppSettings().copyWith(
          themeMode: ThemeMode.dark,
          notificationsEnabled: false,
          serviceReminderDays: [3],
          reminderTime: const TimeOfDay(hour: 6, minute: 15),
          tripServiceLeadDays: 21,
        ),
      );
      return (await storedRow()).toJson();
    }

    /// What a peer on an older build sends: every column, its own values.
    Map<String, dynamic> olderPeerRow(Map<String, dynamic> local) => {
          ...local,
          'themeMode': 'light',
          'notificationsEnabled': true,
          'serviceReminderDays': '[30]',
          'reminderTime': '20:00',
          'tripServiceLeadDays': 2,
          'gfHigh': 70,
          'updatedAt': (local['updatedAt'] as int) + 1000,
        };

    void expectLocalValuesKept(DiverSetting row) {
      expect(row.themeMode, 'dark');
      expect(row.notificationsEnabled, isFalse);
      expect(row.serviceReminderDays, '[3]');
      expect(row.reminderTime, '06:15');
      expect(row.tripServiceLeadDays, 21);
    }

    test('fetchRecord and fetchRecords omit them', () async {
      final local = await seedSettings();
      final id = local['id'] as String;
      final single = await serializer.fetchRecord('diverSettings', id);
      expect(single!.keys.toSet().intersection(deviceLocal), isEmpty);
      expect(single, contains('gfHigh'));
      final batch = await serializer.fetchRecords('diverSettings', [id]);
      expect(batch[id]!.keys.toSet().intersection(deviceLocal), isEmpty);
    });

    test('the synced payload omits them', () async {
      await seedSettings();
      final cloud = FakeCloudStorageProvider();
      final deviceId = await SyncRepository().getDeviceId();
      await SyncService(
        syncRepository: SyncRepository(),
        serializer: SyncDataSerializer(),
        cloudProvider: cloud,
      ).performSync();
      final payload = await cloudBasePayload(cloud, deviceId);
      final exported = payload!.data.diverSettings.single;
      expect(exported.keys.toSet().intersection(deviceLocal), isEmpty);
      expect(exported, contains('themePreset'));
      expect(exported, contains('mapStyle'));
      expect(exported, contains('locale'));
    });

    test('upsertRecord of an older peer row keeps them and applies the rest',
        () async {
      final local = await seedSettings();
      await serializer.upsertRecord('diverSettings', olderPeerRow(local));
      final row = await storedRow();
      expectLocalValuesKept(row);
      expect(row.gfHigh, 70);
    });

    test('upsertRecords of an older peer row keeps them', () async {
      final local = await seedSettings();
      await serializer.upsertRecords('diverSettings', [olderPeerRow(local)]);
      final row = await storedRow();
      expectLocalValuesKept(row);
      expect(row.gfHigh, 70);
    });

    test('a replace-adopt clear and refill keeps them', () async {
      final local = await seedSettings();
      await serializer.deleteAllRecords('diverSettings');
      await serializer.upsertRecords('diverSettings', [
        withoutDeviceLocalKeys(olderPeerRow(local), deviceLocal),
      ]);
      final row = await storedRow();
      expectLocalValuesKept(row);
      expect(row.gfHigh, 70);
    });

    test('a settings row new to this device takes the defaults', () async {
      final local = await seedSettings();
      await (db.delete(db.diverSettings)).go();
      await serializer.upsertRecord('diverSettings', olderPeerRow(local));
      final row = await storedRow();
      expect(row.themeMode, 'system');
      expect(row.gfHigh, 70);
    });
  });
```

Add helpers to the file (outside `main`, and `storedRow` inside `main` after `serializer`):

```dart
  Future<DiverSetting> storedRow() => (db.select(
    db.diverSettings,
  )..where((t) => t.diverId.equals('d1'))).getSingle();
```

```dart
Map<String, dynamic> withoutDeviceLocalKeys(
  Map<String, dynamic> row,
  Set<String> keys,
) => {...row}..removeWhere((key, _) => keys.contains(key));
```

The sync-payload test calls `performSync`, which uses `DatabaseService.instance`; `setUpTestDatabase` already wires it, and `tearDownTestDatabase` resets it. If `cloudBasePayload` needs a different deviceId lookup, copy exactly what `sync_device_local_settings_test.dart` does.

The "new to this device" test expects `'system'` for `themeMode` (the column default) and must not assert the notification defaults by literal; read them from `DiverSettings` defaults only if needed.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/sync/device_local_fields_test.dart test/core/services/sync/sync_device_local_columns_test.dart`
Expected: the new tests FAIL (columns present in fetch/export; local values overwritten), except "new to this device".

- [ ] **Step 3: Add the columns and strip them on export and fetch**

In `device_local_fields.dart`, add to `deviceLocalSyncColumns`:

```dart
  // Reminders follow the OS notification permission, which is per device,
  // and the theme mode follows where the device is used.
  'diverSettings': {
    'notificationsEnabled',
    'serviceReminderDays',
    'reminderTime',
    'tripServiceLeadDays',
    'themeMode',
  },
```

In `sync_data_serializer.dart`:
- `fetchRecord`, `case 'diverSettings':` return `row == null ? null : withoutDeviceLocalColumns('diverSettings', row.toJson());`
- `fetchRecords`, `case 'diverSettings':` return `{for (final r in rows) r.id: withoutDeviceLocalColumns('diverSettings', r.toJson())};`
- `_exportDiverSettings`: map rows through `withoutDeviceLocalColumns('diverSettings', r.toJson())` (keep any existing transform; read the method first).
- `_deviceLocalValuesHere`: add

```dart
      case 'diverSettings':
        final query = _db.select(_db.diverSettings);
        if (ids != null) query.where((t) => t.id.isIn(ids));
        rows = [for (final row in await query.get()) row.toJson()];
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/sync/device_local_fields_test.dart test/core/services/sync/sync_device_local_columns_test.dart`
Then every test that mentions diver settings and sync: `flutter test $(grep -rl "diverSettings" test/core/services/sync | tr '\n' ' ')`
Expected: all PASS. A failure that compares a full exported `diverSettings` row now needs the five keys removed from its expectation; change the expectation only when the failing key is one of the five.

- [ ] **Step 5: Commit**

```bash
dart format lib/core/services/sync test/core/services/sync
git add lib/core/services/sync/device_local_fields.dart lib/core/services/sync/sync_data_serializer.dart test/core/services/sync/device_local_fields_test.dart test/core/services/sync/sync_device_local_columns_test.dart
git commit -m "feat(settings): keep notification settings and theme mode on each device"
```

(Add any sync test files changed in Step 4 to the `git add`.)

---

### Task 4: Nav layout stays on the device

**Files:**
- Modify: `lib/core/services/sync/device_local_fields.dart`
- Test: `test/core/services/sync/sync_device_local_settings_test.dart` (extend), `test/core/services/sync/device_local_fields_test.dart` (extend)

**Interfaces:**
- Consumes: `deviceLocalSettingsKeys` (Task 1), already used by every `settings` path in the serializer.
- Produces: the three nav keys in `deviceLocalSettingsKeys`.

- [ ] **Step 1: Write the failing tests**

In `device_local_fields_test.dart`:

```dart
  test('the nav layout keys are device-local settings keys', () {
    expect(deviceLocalSettingsKeys, containsAll(<String>[
      'nav_primary_ids',
      'nav_rail_ids',
      'nav_always_hide_labels',
    ]));
  });
```

In `sync_device_local_settings_test.dart`, inside the group:

```dart
    test('the nav layout keys are not in the synced payload', () async {
      final repo = AppSettingsRepository();
      await repo.setNavPrimaryIds(['dives', 'sites']);
      await repo.setNavRailIds(['dives', 'equipment']);
      await repo.setNavAlwaysHideLabels(true);
      await repo.setRawSetting(
        MediaUploadQualityPolicy.photoQualityKey,
        'balanced',
      );

      final deviceId = await SyncRepository().getDeviceId();
      await buildService().performSync();

      final payload = await cloudBasePayload(cloud, deviceId);
      final exportedKeys = payload!.data.settings
          .map((s) => s['key'])
          .toSet();
      expect(exportedKeys, contains(MediaUploadQualityPolicy.photoQualityKey));
      expect(
        exportedKeys.intersection({
          'nav_primary_ids',
          'nav_rail_ids',
          'nav_always_hide_labels',
        }),
        isEmpty,
      );
    });

    test('importing a nav layout key does not overwrite the local value',
        () async {
      final serializer = SyncDataSerializer();
      final repo = AppSettingsRepository();
      await repo.setNavAlwaysHideLabels(true);
      await serializer.upsertRecord('settings', {
        'key': 'nav_always_hide_labels',
        'value': 'false',
        'updatedAt': 9999999999999,
      });
      await serializer.upsertRecords('settings', [
        {
          'key': 'nav_always_hide_labels',
          'value': 'false',
          'updatedAt': 9999999999999,
        },
      ]);
      expect(await repo.getNavAlwaysHideLabels(), isTrue);
    });

    test('a replace-adopt clear keeps the nav layout keys', () async {
      final repo = AppSettingsRepository();
      await repo.setNavPrimaryIds(['dives', 'sites']);
      await SyncDataSerializer().deleteAllRecords('settings');
      expect(await repo.getNavPrimaryIdsRaw(), ['dives', 'sites']);
    });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/sync/device_local_fields_test.dart test/core/services/sync/sync_device_local_settings_test.dart`
Expected: the new tests FAIL.

- [ ] **Step 3: Add the keys**

In `device_local_fields.dart`:

```dart
const Set<String> deviceLocalSettingsKeys = {
  // Each device auto-creates its own owner diver at first launch.
  'active_diver_id',
  // The nav layout depends on the screen it is shown on (issue #2947).
  'nav_primary_ids',
  'nav_rail_ids',
  'nav_always_hide_labels',
};
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/sync/device_local_fields_test.dart test/core/services/sync/sync_device_local_settings_test.dart test/shared/widgets/nav/ test/features/settings/data/repositories/app_settings_repository_nav_test.dart`
Expected: all PASS. If a nav or sync test asserted that a nav key syncs, it encoded the old decision: update it to the new one and say so in the commit body.

- [ ] **Step 5: Commit**

```bash
dart format lib/core/services/sync test/core/services/sync
git add lib/core/services/sync/device_local_fields.dart test/core/services/sync/device_local_fields_test.dart test/core/services/sync/sync_device_local_settings_test.dart
git commit -m "feat(settings): keep the navigation layout on each device"
```

---

### Task 5: Device-local saves stamp no sync clock

**Files:**
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart` (`updateSettingsForDiver`, near line 282)
- Modify: `lib/features/settings/data/repositories/app_settings_repository.dart` (`_setIdList` near 104, `setRawSetting` near 334)
- Test: `test/features/settings/data/repositories/diver_settings_repository_partial_write_test.dart`, `test/features/settings/data/repositories/app_settings_repository_nav_test.dart`

**Interfaces:**
- Consumes: `isDeviceLocalColumn`, `deviceLocalSettingsKeys` (Task 1, entries from Tasks 3 and 4).

- [ ] **Step 1: Write the failing tests**

In `diver_settings_repository_partial_write_test.dart` (add `import 'package:flutter/material.dart' show ThemeMode, TimeOfDay;`):

```dart
  test('a device-local change stamps no clock and queues nothing', () async {
    final settings = await repository.createSettingsForDiver('d1');
    final before = await storedRow();
    final pendingBefore = await SyncRepository().getPendingRecords();

    await repository.updateSettingsForDiver(
      'd1',
      settings.copyWith(
        themeMode: ThemeMode.dark,
        notificationsEnabled: false,
        reminderTime: const TimeOfDay(hour: 6, minute: 15),
      ),
      previous: settings,
    );

    final after = await storedRow();
    expect(after.themeMode, 'dark');
    expect(after.notificationsEnabled, isFalse);
    expect(after.reminderTime, '06:15');
    expect(after.updatedAt, before.updatedAt);
    expect(after.hlc, before.hlc);
    expect(
      (await SyncRepository().getPendingRecords()).length,
      pendingBefore.length,
    );
  });

  test('a change mixing device-local and synced columns stamps and queues',
      () async {
    final settings = await repository.createSettingsForDiver('d1');
    final before = await storedRow();

    await repository.updateSettingsForDiver(
      'd1',
      settings.copyWith(themeMode: ThemeMode.dark, gfLow: 40),
      previous: settings,
    );

    final after = await storedRow();
    expect(after.themeMode, 'dark');
    expect(after.gfLow, 40);
    expect(after.hlc, isNot(before.hlc));
    final pending = await SyncRepository().getPendingRecords();
    expect(
      pending.where(
        (r) => r.entityType == 'diverSettings' && r.recordId == after.id,
      ),
      isNotEmpty,
    );
  });
```

`createSettingsForDiver` may itself queue the row; the first test compares counts before and after the update, so that does not matter.

In `app_settings_repository_nav_test.dart` (add `import 'package:submersion/core/data/repositories/sync_repository.dart';`):

```dart
  group('device-local keys are not queued for sync', () {
    Future<Set<String>> pendingSettingsKeys() async => {
          for (final r in await SyncRepository().getPendingRecords())
            if (r.entityType == 'settings') r.recordId,
        };

    test('nav layout writes queue nothing', () async {
      await repo.setNavPrimaryIds(['dives']);
      await repo.setNavRailIds(['dives']);
      await repo.setNavAlwaysHideLabels(true);
      expect(
        (await pendingSettingsKeys()).intersection({
          'nav_primary_ids',
          'nav_rail_ids',
          'nav_always_hide_labels',
        }),
        isEmpty,
      );
      expect(await repo.getNavAlwaysHideLabels(), isTrue);
    });

    test('a synced key is still queued', () async {
      await repo.setRawSetting('share_new_records_by_default', 'true');
      expect(await pendingSettingsKeys(), contains('share_new_records_by_default'));
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/settings/data/repositories/diver_settings_repository_partial_write_test.dart test/features/settings/data/repositories/app_settings_repository_nav_test.dart`
Expected: "stamps no clock" and "nav layout writes queue nothing" FAIL; the mixed and synced-key tests PASS.

- [ ] **Step 3: Implement**

In `diver_settings_repository.dart`, import `package:submersion/core/services/sync/device_local_fields.dart` (with the other `core/services/sync` import), and in `updateSettingsForDiver` after `if (changed.isEmpty) return;`:

```dart
      // A device-local value never syncs (issue #2947). Stamping the row
      // for one would republish this device's copy of every synced column
      // with a newer clock, which could undo a peer's change, so only the
      // value is written.
      if (changed.keys.every(
        (name) => isDeviceLocalColumn('diverSettings', name),
      )) {
        await (_db.update(
          _db.diverSettings,
        )..where((t) => t.diverId.equals(diverId))).write(
          RawValuesInsertable<DiverSetting>(changed),
        );
        _log.info('Updated device-local settings for diver: $diverId');
        return;
      }
```

Update the method's doc comment: after "...when none does.", add "A change to device-local columns alone ([deviceLocalSyncColumns]) is written without a new clock and queues nothing."

In `app_settings_repository.dart`, import the same file, and in both `_setIdList` and `setRawSetting`, between the insert and `markRecordPending`:

```dart
      // A device-local key never syncs (issue #2947); queuing it would only
      // publish a changeset that carries nothing.
      if (deviceLocalSettingsKeys.contains(key)) return;
```

Update `_setIdList`'s doc comment: "Writes a JSON-encoded list of strings and, unless the key is device-local, marks it pending for sync."

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/settings/ test/shared/widgets/nav/`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/settings test/features/settings
git add lib/features/settings/data/repositories/diver_settings_repository.dart lib/features/settings/data/repositories/app_settings_repository.dart test/features/settings/data/repositories/diver_settings_repository_partial_write_test.dart test/features/settings/data/repositories/app_settings_repository_nav_test.dart
git commit -m "feat(settings): save device-local settings without a sync clock"
```

---

### Task 6: Document what syncs

**Files:**
- Modify: `docs/guide/multi-device-sync.md`

- [ ] **Step 1: Verify the labels**

Run: `grep -nE '"settings_section_(notifications|appearance|security|data)_title"|"settings_navCustomization_title"|"settings_appearance_(theme|mapStyle|language|themePreset)[A-Za-z]*"' lib/l10n/arb/app_en.arb`
and `grep -rn "displayZoom\|homeCards\|Home layout\|detector" lib/l10n/arb/app_en.arb | head -20`
Use the exact English labels found (for example "Navigation layout", "App Security", "Map Style").

- [ ] **Step 2: Add the section**

Insert after the "Sync Options" section, matching the page's HTML-in-Markdown style (`&mdash;` is not allowed; use commas, colons or parentheses):

```markdown
## What Syncs and What Stays on Each Device

Most settings follow you to every device. A few describe the device itself
(its screen, its notification permission, how it connects to things), so each
device keeps its own.

**Stays on each device:**

| Setting | Where |
|---------|-------|
| Service reminders: on/off, reminder days, reminder time, trip lead time | Settings &rarr; Notifications |
| Theme mode (Light, Dark, System default) | Settings &rarr; Appearance |
| Navigation layout: tab order and "Always hide labels" | Settings &rarr; Appearance &rarr; Navigation layout |
| The active diver | Settings &rarr; Diver Profile |
| App lock and database encryption | Settings &rarr; App Security |
| The Cloud Sync connection and its sync options | Settings &rarr; Cloud Sync |
| Backup settings and the database location | Settings &rarr; Data |
| Display zoom and the home dashboard card order | Where you set them |
| Dive computer Bluetooth pairing and clock sync | Dive computer details |
| Sign-ins to connected services | Each service's settings |

**Syncs to every device:** everything else in Settings, including units,
language, theme preset and accent colours, map style, decompression and
safety settings, and the defaults for new dives.

Changing a per-device setting on one device never changes it on another, and
a sync never overwrites it.
```

Adjust each row's label and location to what Step 1 found; drop a row whose setting cannot be confirmed in the UI. Check "home dashboard card order" and "data quality detector toggles" against the UI and add the detector row if a user-visible toggle exists.

- [ ] **Step 3: Check for forbidden characters**

Run: `perl -CSD -ne '$c++ while /\x{2014}/g; END { print $c+0, "\n" }' docs/guide/multi-device-sync.md` and the same on `git show HEAD:docs/guide/multi-device-sync.md` (pipe it into the perl command)
Expected: equal counts (no new em-dashes).

- [ ] **Step 4: Commit**

```bash
git add docs/guide/multi-device-sync.md
git commit -m "docs(sync): list which settings sync and which stay on each device"
```

---

### Task 7: Whole-branch verification

- [ ] **Step 1:** `dart format .` (expect no changes beyond this branch's files).
- [ ] **Step 2:** `flutter analyze` (expect "No issues found").
- [ ] **Step 3:** `flutter test test/architecture/`.
- [ ] **Step 4:** `flutter test test/core/services/sync/ test/features/settings/ test/shared/widgets/nav/` (one run; check the exit status directly, not through a pipe).
- [ ] **Step 5:** Commit any formatting fix as `chore: format`.
