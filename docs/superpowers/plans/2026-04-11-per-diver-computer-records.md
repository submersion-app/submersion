# Per-Diver Computer Records Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow multiple diver profiles to each have their own dive computer record for the same physical device. Cascade-delete diver data when a profile is deleted so orphaned records never exist. Clean up historical orphans with a one-time migration.

**Architecture:** Three changes: (1) `deleteDiver` cascade-deletes associated data instead of nullifying `diverId`, (2) `resolveKnownComputer` uses a diver-scoped lookup so each diver gets their own computer record, (3) migration v64 reassigns historical orphaned records to the sole diver (or deletes them when multiple divers exist). The `claimComputer` method added in the initial fix is removed -- no orphans means no claiming.

**Tech Stack:** Drift ORM (SQLite), Riverpod, Flutter

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Modify | `lib/features/divers/data/repositories/diver_repository.dart:195-273` | Cascade-delete diver data |
| Modify | `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart:101-119` | Diver-scoped `findByBluetoothAddress`, remove `claimComputer` |
| Modify | `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart:119-147` | Simplified diver-scoped resolution |
| Modify | `lib/features/dive_log/presentation/providers/dive_computer_providers.dart:23-37` | Revert `savedComputersByAddressProvider` to diver-scoped |
| Modify | `lib/core/database/database.dart:1310,1315-1377,2960` | v64 migration + bump schema version |
| Modify | `test/features/dive_log/data/repositories/dive_computer_repository_impl_test.dart` | Tests for diver-scoped lookup, remove claimComputer tests |
| Modify | `test/features/import_wizard/data/adapters/dive_computer_adapter_test.dart` | Tests for simplified resolution |
| Create | `test/core/database/migration_v64_test.dart` | Tests for orphan cleanup migration |
| Modify | `test/features/divers/data/repositories/diver_repository_error_test.dart` | Update for cascade deletion |

---

### Task 1: Cascade-delete diver data in `deleteDiver`

**Files:**
- Modify: `lib/features/divers/data/repositories/diver_repository.dart:195-273`

Replace the 11 `UPDATE ... SET diver_id = NULL` statements with `DELETE`
statements. Handle FK cleanup for tables whose children don't CASCADE.

The deletion order matters due to FK constraints:

1. Null out cross-diver FK references to this diver's entities (dive_computers
   referenced from other divers' dive_profiles/dive_data_sources/dives)
2. Delete dives (cascades: profiles, tanks, data_sources, equipment, weights,
   sightings, tags, buddies, events, photos, pressure profiles, gas switches)
3. Delete trip children without CASCADE (liveaboard_detail_records, trip_itinerary_days)
4. Delete remaining entities (trips, dive_sites, equipment, equipment_sets,
   buddies, certifications, dive_centers, tags, dive_types, dive_computers)
5. Delete diver_settings and the diver itself

Tables with `onDelete: CASCADE` already defined (`courses`, `view_configs`,
`field_presets`) are auto-deleted when the diver row is removed.

- [ ] **Step 1: Write failing test**

In `test/features/divers/data/repositories/diver_repository_error_test.dart`
(or a new test file if needed), add a test that verifies diver deletion
cascades to associated records. The exact test setup depends on the test
helpers available in the diver repository test file. The test should:

1. Insert a diver
2. Insert a dive, dive computer, dive site, and equipment owned by that diver
3. Delete the diver
4. Verify all associated records are deleted (not just nullified)

```dart
test('deleteDiver cascade-deletes associated data', () async {
  await insertDiver('diver-1');
  await insertComputer(id: 'comp-1', diverId: 'diver-1');
  // Insert dive, site, equipment as needed per test helpers

  await repository.deleteDiver('diver-1');

  // Verify computer is DELETED, not orphaned.
  final computers = await db.select(db.diveComputers).get();
  expect(computers, isEmpty);
});
```

- [ ] **Step 2: Implement cascade deletion**

Replace the `deleteDiver` method body (lines 200-244) with:

```dart
_log.info('Deleting diver: $id');

// Phase 1: Clear cross-diver FK references to this diver's computers.
// Other divers' dive_profiles or dive_data_sources may reference
// this diver's computer (e.g. from multi-computer consolidation).
await _db.customStatement('''
  UPDATE dive_profiles SET computer_id = NULL
  WHERE computer_id IN (SELECT id FROM dive_computers WHERE diver_id = ?)
''', [id]);
await _db.customStatement('''
  UPDATE dive_data_sources SET computer_id = NULL
  WHERE computer_id IN (SELECT id FROM dive_computers WHERE diver_id = ?)
''', [id]);
await _db.customStatement('''
  UPDATE dives SET computer_id = NULL
  WHERE computer_id IN (SELECT id FROM dive_computers WHERE diver_id = ?)
''', [id]);

// Phase 2: Delete dives. Most child tables CASCADE automatically
// (profiles, tanks, data_sources, equipment, weights, sightings,
// tags, buddies, events, photos, pressure_profiles, gas_switches).
await _db.customStatement(
  'DELETE FROM dives WHERE diver_id = ?',
  [id],
);

// Phase 3: Delete trip children (no CASCADE defined on FK).
await _db.customStatement('''
  DELETE FROM liveaboard_detail_records
  WHERE trip_id IN (SELECT id FROM trips WHERE diver_id = ?)
''', [id]);
await _db.customStatement('''
  DELETE FROM trip_itinerary_days
  WHERE trip_id IN (SELECT id FROM trips WHERE diver_id = ?)
''', [id]);

// Phase 4: Delete remaining diver-owned entities.
await _db.customStatement(
  'DELETE FROM dive_computers WHERE diver_id = ?', [id],
);
await _db.customStatement(
  'DELETE FROM trips WHERE diver_id = ?', [id],
);
await _db.customStatement(
  'DELETE FROM dive_sites WHERE diver_id = ?', [id],
);
await _db.customStatement(
  'DELETE FROM equipment_sets WHERE diver_id = ?', [id],
);
await _db.customStatement(
  'DELETE FROM equipment WHERE diver_id = ?', [id],
);
await _db.customStatement(
  'DELETE FROM buddies WHERE diver_id = ?', [id],
);
await _db.customStatement(
  'DELETE FROM certifications WHERE diver_id = ?', [id],
);
await _db.customStatement(
  'DELETE FROM dive_centers WHERE diver_id = ?', [id],
);
await _db.customStatement(
  'DELETE FROM tags WHERE diver_id = ?', [id],
);
await _db.customStatement(
  'DELETE FROM dive_types WHERE diver_id = ? AND is_built_in = 0', [id],
);
await _db.customStatement(
  'DELETE FROM import_presets WHERE diver_id = ?', [id],
);
```

Note: `dive_types` with `is_built_in = 1` have null diverId and are shared --
only delete custom types for this diver. `courses`, `view_configs`, and
`field_presets` have `onDelete: CASCADE` in the schema and auto-delete when
the diver row is removed.

Keep the existing diver_settings deletion and diver deletion below unchanged.

- [ ] **Step 3: Run tests**

Run: `flutter test test/features/divers/`
Expected: All tests PASS.

- [ ] **Step 4: Commit**

```
fix: cascade-delete diver data instead of orphaning it

When a diver profile is deleted, all associated records (dives,
computers, sites, equipment, buddies, etc.) are now deleted instead
of having their diverId set to NULL. This prevents orphaned records
that are invisible in the UI.

Cross-diver FK references (e.g. another diver's dive_profile
referencing this diver's computer via consolidation) are nullified
before deletion.

Resolves part of #196.
```

---

### Task 2: Diver-scoped `findByBluetoothAddress` and remove `claimComputer`

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart:101-119,258-296`
- Modify: `test/features/dive_log/data/repositories/dive_computer_repository_impl_test.dart`

Add an optional `diverId` parameter to `findByBluetoothAddress` and switch
from `getSingleOrNull()` to `.get()` so it doesn't throw when two divers
share a physical device. Remove `claimComputer` since orphans can no longer
be created.

- [ ] **Step 1: Write failing tests**

Replace the `claimComputer` test group with `findByBluetoothAddress` tests.
Uses the `insertDiver` and `insertComputer` helpers already in the file.

```dart
// ---------------------------------------------------------------------------
// findByBluetoothAddress - diver-scoped lookup
// ---------------------------------------------------------------------------

group('findByBluetoothAddress', () {
  test('returns computer matching address and diverId', () async {
    await insertDiver('diver-a');
    await insertDiver('diver-b');
    await insertComputer(
      id: 'comp-a',
      diverId: 'diver-a',
      bluetoothAddress: 'AA:BB:CC:DD:EE:FF',
    );
    await insertComputer(
      id: 'comp-b',
      diverId: 'diver-b',
      bluetoothAddress: 'AA:BB:CC:DD:EE:FF',
    );

    final result = await repository.findByBluetoothAddress(
      'AA:BB:CC:DD:EE:FF',
      diverId: 'diver-b',
    );

    expect(result?.id, equals('comp-b'));
    expect(result?.diverId, equals('diver-b'));
  });

  test('returns null when address exists but diverId does not match', () async {
    await insertDiver('diver-a');
    await insertComputer(
      id: 'comp-a',
      diverId: 'diver-a',
      bluetoothAddress: 'AA:BB:CC:DD:EE:FF',
    );

    final result = await repository.findByBluetoothAddress(
      'AA:BB:CC:DD:EE:FF',
      diverId: 'diver-other',
    );

    expect(result, isNull);
  });

  test('does not throw when multiple records share the same address', () async {
    await insertDiver('diver-a');
    await insertDiver('diver-b');
    await insertComputer(
      id: 'comp-a',
      diverId: 'diver-a',
      bluetoothAddress: 'AA:BB:CC:DD:EE:FF',
    );
    await insertComputer(
      id: 'comp-b',
      diverId: 'diver-b',
      bluetoothAddress: 'AA:BB:CC:DD:EE:FF',
    );

    // Without diverId filter, should return one (not throw).
    final result = await repository.findByBluetoothAddress('AA:BB:CC:DD:EE:FF');
    expect(result, isNotNull);
  });
});
```

- [ ] **Step 2: Implement diver-scoped `findByBluetoothAddress`**

Replace the method in `dive_computer_repository_impl.dart:101-119`:

```dart
/// Find a dive computer by its Bluetooth address.
///
/// When [diverId] is provided, returns only the record belonging to that
/// diver. When omitted, returns any matching record.
///
/// Returns `null` if no matching computer exists. Safe to call when
/// multiple divers each have a record for the same physical device.
Future<domain.DiveComputer?> findByBluetoothAddress(
  String address, {
  String? diverId,
}) async {
  try {
    final query = _db.select(_db.diveComputers)
      ..where((t) => t.bluetoothAddress.equals(address));

    if (diverId != null) {
      query.where((t) => t.diverId.equals(diverId));
    }

    final rows = await query.get();
    if (rows.isEmpty) return null;
    return _mapRowToComputer(rows.first);
  } catch (e, stackTrace) {
    _log.error(
      'Failed to find dive computer by bluetooth address: $address',
      error: e,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}
```

- [ ] **Step 3: Remove `claimComputer`**

Delete the `claimComputer` method entirely (added in the initial fix).

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/dive_log/data/repositories/dive_computer_repository_impl_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```
feat: diver-scoped findByBluetoothAddress, remove claimComputer

Adds optional diverId param to findByBluetoothAddress. Switches from
getSingleOrNull to .get() to avoid StateError when two divers have
records for the same physical device.

Removes claimComputer -- orphaned records are no longer possible now
that deleteDiver cascade-deletes associated data.
```

---

### Task 3: Simplified `resolveKnownComputer`

**Files:**
- Modify: `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart:119-147`
- Modify: `test/features/import_wizard/data/adapters/dive_computer_adapter_test.dart`

Replace the three-tier resolution (own, orphan, other-diver) with a single
diver-scoped lookup. If not found, `_computer` stays null and
`ensureComputer` will create a new record.

- [ ] **Step 1: Update tests**

In the `resolveKnownComputer()` test group:

1. **Keep**: `looks up computer by BLE address when computer is null` -- update
   mock to pass `diverId: diverId`.
2. **Keep**: `looks up computer by bluetoothClassic address` -- update mock to
   pass `diverId: diverId`.
3. **Keep**: `is a no-op for USB devices`.
4. **Remove**: `claims orphaned computer with null diverId` (no orphans possible).
5. **Remove**: `claims computer belonging to a different diver` (no claiming).
6. **Remove**: `does not claim when adapter diverId is empty`.
7. **Keep**: `is a no-op when computer is already set`.
8. **Add**: `leaves computer null when address belongs to different diver` -- verifies
   that a different diver's record is not used.

Updated test for BLE lookup (example):

```dart
test('looks up computer by BLE address when computer is null', () async {
  final discoveryAdapter = DiveComputerAdapter(
    importService: mockImportService,
    computerRepository: mockComputerRepo,
    diveRepository: mockDiveRepo,
    diverId: diverId,
  );

  final existingComputer = makeComputer(
    id: 'found-computer',
    diverId: diverId,
  );
  when(
    mockComputerRepo.findByBluetoothAddress(
      'AA:BB:CC:DD:EE:FF',
      diverId: diverId,
    ),
  ).thenAnswer((_) async => existingComputer);

  final device = DiscoveredDevice(
    id: 'device-1',
    name: 'Perdix 2',
    connectionType: DeviceConnectionType.ble,
    address: 'AA:BB:CC:DD:EE:FF',
    discoveredAt: DateTime(2026, 3, 20),
  );

  await discoveryAdapter.resolveKnownComputer(device);

  expect(discoveryAdapter.computer, equals(existingComputer));
  verify(
    mockComputerRepo.findByBluetoothAddress(
      'AA:BB:CC:DD:EE:FF',
      diverId: diverId,
    ),
  ).called(1);
});
```

New test:

```dart
test('leaves computer null when address belongs to different diver', () async {
  final discoveryAdapter = DiveComputerAdapter(
    importService: mockImportService,
    computerRepository: mockComputerRepo,
    diveRepository: mockDiveRepo,
    diverId: diverId,
  );

  when(
    mockComputerRepo.findByBluetoothAddress(
      'AA:BB:CC:DD:EE:FF',
      diverId: diverId,
    ),
  ).thenAnswer((_) async => null);

  final device = DiscoveredDevice(
    id: 'device-1',
    name: 'Perdix 2',
    connectionType: DeviceConnectionType.ble,
    address: 'AA:BB:CC:DD:EE:FF',
    discoveredAt: DateTime(2026, 3, 20),
  );

  await discoveryAdapter.resolveKnownComputer(device);

  expect(discoveryAdapter.computer, isNull);
});
```

- [ ] **Step 2: Implement simplified `resolveKnownComputer`**

Replace the method in `dive_computer_adapter.dart`:

```dart
/// Look up an existing computer by the discovered device's address.
///
/// Called before the download starts in discovery mode. If a matching
/// computer is found for the current diver, its [lastDiveFingerprint]
/// enables incremental download (only new dives). Does NOT create a
/// new computer record -- that happens in [ensureComputer] after the
/// download completes.
///
/// If the address belongs to a different diver's computer, it is
/// ignored and [ensureComputer] will create a new record for this diver.
Future<void> resolveKnownComputer(DiscoveredDevice device) async {
  if (computer != null) return;
  if (device.connectionType == DeviceConnectionType.ble ||
      device.connectionType == DeviceConnectionType.bluetoothClassic) {
    if (_diverId.isEmpty) return;
    final existing = await _computerRepository.findByBluetoothAddress(
      device.address,
      diverId: _diverId,
    );
    if (existing != null) {
      _computer = existing;
    }
  }
}
```

- [ ] **Step 3: Regenerate mocks and run tests**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/features/import_wizard/data/adapters/dive_computer_adapter_test.dart`
Expected: All tests PASS.

- [ ] **Step 4: Commit**

```
refactor: simplify resolveKnownComputer to single diver-scoped lookup

With cascade deletion preventing orphans and per-diver records,
resolution is now a single query: find by address + current diverId.
If not found, ensureComputer creates a new record.
```

---

### Task 4: Revert `savedComputersByAddressProvider` to diver-scoped

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/dive_computer_providers.dart:23-37`

With per-diver records, each diver has their own entries. Revert to
deriving from `allDiveComputersProvider` (filtered by current diver).

- [ ] **Step 1: Revert the provider**

```dart
/// Lookup map of saved dive computers keyed by Bluetooth address.
///
/// Used by the discovery wizard to show serial number and firmware version
/// for previously-downloaded devices during scan and confirm steps.
/// Scoped to the current diver since each diver has their own computer
/// records.
final savedComputersByAddressProvider =
    FutureProvider<Map<String, DiveComputer>>((ref) async {
      final computers = await ref.watch(allDiveComputersProvider.future);
      final map = <String, DiveComputer>{};
      for (final computer in computers) {
        if (computer.bluetoothAddress != null) {
          map[computer.bluetoothAddress!] = computer;
        }
      }
      return map;
    });
```

- [ ] **Step 2: Run analyze**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 3: Commit**

```
refactor: revert savedComputersByAddressProvider to diver-scoped

With per-diver computer records, the scan step only needs to show
recognition info for the current diver's own records.
```

---

### Task 5: v64 migration -- clean up orphaned records

**Files:**
- Modify: `lib/core/database/database.dart:1310,1315-1377,2960`
- Create: `test/core/database/migration_v64_test.dart`

Add a migration that deletes all historical orphaned records (null `diverId`)
across all tables. Going forward, cascade deletion in `deleteDiver` prevents
new orphans from being created.

**Tables to clean up** (the 11 that `deleteDiver` previously nullified):

`dives`, `trips`, `dive_sites`, `equipment`, `equipment_sets`, `buddies`,
`certifications`, `dive_centers`, `tags`, `dive_types` (custom only),
`dive_computers`, `import_presets`.

- [ ] **Step 1: Write migration test**

Create `test/core/database/migration_v64_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  group('Migration v64 - delete orphaned diver data', () {
    NativeDatabase _setupDb({
      required List<(String id, String name)> divers,
      List<(String id, String? diverId, String addr)> computers = const [],
      List<(String id, String? diverId)> dives = const [],
    }) {
      return NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 63');

          rawDb.execute('''
            CREATE TABLE divers (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              created_at INTEGER NOT NULL DEFAULT 0,
              updated_at INTEGER NOT NULL DEFAULT 0
            )
          ''');
          rawDb.execute('''
            CREATE TABLE dive_computers (
              id TEXT NOT NULL PRIMARY KEY,
              diver_id TEXT REFERENCES divers(id),
              name TEXT NOT NULL DEFAULT '',
              bluetooth_address TEXT,
              last_dive_fingerprint TEXT,
              last_download_timestamp INTEGER,
              dive_count INTEGER NOT NULL DEFAULT 0,
              is_favorite INTEGER NOT NULL DEFAULT 0,
              notes TEXT NOT NULL DEFAULT '',
              manufacturer TEXT, model TEXT, serial_number TEXT,
              firmware_version TEXT, connection_type TEXT,
              created_at INTEGER NOT NULL DEFAULT 0,
              updated_at INTEGER NOT NULL DEFAULT 0
            )
          ''');
          rawDb.execute('''
            CREATE TABLE dives (
              id TEXT NOT NULL PRIMARY KEY,
              diver_id TEXT REFERENCES divers(id),
              dive_date_time INTEGER NOT NULL DEFAULT 0,
              notes TEXT NOT NULL DEFAULT '',
              created_at INTEGER NOT NULL DEFAULT 0,
              updated_at INTEGER NOT NULL DEFAULT 0
            )
          ''');

          for (final d in divers) {
            rawDb.execute(
              "INSERT INTO divers (id, name) VALUES ('${d.$1}', '${d.$2}')",
            );
          }
          for (final c in computers) {
            final dv = c.$2 == null ? 'NULL' : "'${c.$2}'";
            rawDb.execute(
              "INSERT INTO dive_computers (id, diver_id, name, bluetooth_address)"
              " VALUES ('${c.$1}', $dv, 'Computer', '${c.$3}')",
            );
          }
          for (final d in dives) {
            final dv = d.$2 == null ? 'NULL' : "'${d.$2}'";
            rawDb.execute(
              "INSERT INTO dives (id, diver_id) VALUES ('${d.$1}', $dv)",
            );
          }
        },
      );
    }

    test('deletes orphaned records and preserves owned records', () async {
      final nativeDb = _setupDb(
        divers: [('sole-diver', 'Alice')],
        computers: [
          ('orphan-comp', null, 'AA:BB:CC:DD:EE:FF'),
          ('owned-comp', 'sole-diver', '11:22:33:44:55:66'),
        ],
        dives: [
          ('orphan-dive', null),
          ('owned-dive', 'sole-diver'),
        ],
      );

      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final comps = await db.customSelect(
        'SELECT id FROM dive_computers',
      ).get();
      expect(comps.map((r) => r.read<String>('id')), ['owned-comp']);

      final dvs = await db.customSelect(
        'SELECT id FROM dives',
      ).get();
      expect(dvs.map((r) => r.read<String>('id')), ['owned-dive']);
    });

    test('deletes orphaned records with multiple divers', () async {
      final nativeDb = _setupDb(
        divers: [('diver-a', 'Alice'), ('diver-b', 'Bob')],
        computers: [
          ('orphan-comp', null, 'AA:BB:CC:DD:EE:FF'),
          ('owned-comp', 'diver-a', '11:22:33:44:55:66'),
        ],
        dives: [
          ('orphan-dive', null),
          ('owned-dive', 'diver-b'),
        ],
      );

      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final comps = await db.customSelect(
        'SELECT id FROM dive_computers',
      ).get();
      expect(comps.map((r) => r.read<String>('id')), ['owned-comp']);

      final dvs = await db.customSelect(
        'SELECT id FROM dives',
      ).get();
      expect(dvs.map((r) => r.read<String>('id')), ['owned-dive']);
    });

    test('no-op when no orphaned records exist', () async {
      final nativeDb = _setupDb(
        divers: [('diver-a', 'Alice')],
        computers: [('owned-comp', 'diver-a', 'AA:BB:CC:DD:EE:FF')],
        dives: [('owned-dive', 'diver-a')],
      );

      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final comps = await db.customSelect(
        'SELECT id FROM dive_computers',
      ).get();
      expect(comps, hasLength(1));
    });
  });
}
```

- [ ] **Step 2: Implement the migration**

In `lib/core/database/database.dart`:

**a)** Bump `currentSchemaVersion` to `64`.

**b)** Add `64` to `migrationVersions` list.

**c)** Add migration block after the `from < 63` block:

```dart
if (from < 64) {
  // Delete orphaned records (diver_id = NULL) left by prior diver
  // deletions that nullified instead of cascade-deleting.
  // Delete dives first so child tables CASCADE automatically.
  await customStatement(
    'DELETE FROM dives WHERE diver_id IS NULL',
  );
  for (final table in [
    'trips',
    'dive_sites',
    'equipment',
    'equipment_sets',
    'buddies',
    'certifications',
    'dive_centers',
    'tags',
    'dive_computers',
    'import_presets',
  ]) {
    await customStatement(
      'DELETE FROM $table WHERE diver_id IS NULL',
    );
  }
}
if (from < 64) await reportProgress();
```

- [ ] **Step 3: Run migration tests**

Run: `flutter test test/core/database/migration_v64_test.dart`
Expected: All tests PASS.

- [ ] **Step 4: Commit**

```
feat: add v64 migration to delete orphaned diver data

Deletes all records with null diverId across all tables. These
orphans were created by prior diver deletions that nullified
diverId instead of cascade-deleting.

Resolves #196.
```

---

### Task 6: Type-to-confirm diver deletion dialog

**Files:**
- Modify: `lib/features/divers/presentation/pages/diver_detail_page.dart:782-806`
- Modify: `lib/l10n/arb/app_en.arb` (and all locale files for the changed key)

Replace the simple confirmation dialog with a type-to-confirm dialog,
following the pattern from `ResetDatabaseDialog`. The user must type
"Delete [name]" (case-sensitive) before the Delete button becomes enabled.

Update the dialog content text from "unassigned" to reflect that all data
will be permanently deleted.

- [ ] **Step 1: Update localization string**

In `lib/l10n/arb/app_en.arb`, change the delete dialog content (line 3486):

From:
```json
"divers_detail_deleteDialogContent": "Are you sure you want to delete {name}? All associated dive logs will be unassigned.",
```

To:
```json
"divers_detail_deleteDialogContent": "This will permanently delete {name} and all associated data including dive logs, dive computers, equipment, certifications, and sites.",
```

Add a new key for the confirmation hint:
```json
"divers_detail_deleteDialogConfirmHint": "Type \"Delete {name}\" to confirm",
```

With placeholder metadata:
```json
"@divers_detail_deleteDialogConfirmHint": {
  "placeholders": {
    "name": {
      "type": "String"
    }
  }
},
```

- [ ] **Step 2: Replace `_showDeleteConfirmation` with type-to-confirm dialog**

Replace the method in `diver_detail_page.dart:782-806` with a `StatefulWidget`
dialog, following the `ResetDatabaseDialog` pattern. The confirmation text
is `"Delete [diver.name]"` (case-sensitive).

```dart
Future<bool> _showDeleteConfirmation(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => _DeleteDiverDialog(diverName: diver.name),
      ) ??
      false;
}
```

Add a new private `StatefulWidget` class in the same file (or nearby):

```dart
class _DeleteDiverDialog extends StatefulWidget {
  const _DeleteDiverDialog({required this.diverName});

  final String diverName;

  @override
  State<_DeleteDiverDialog> createState() => _DeleteDiverDialogState();
}

class _DeleteDiverDialogState extends State<_DeleteDiverDialog> {
  final _controller = TextEditingController();
  bool _isConfirmed = false;

  String get _confirmationText => 'Delete ${widget.diverName}';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final confirmed = _controller.text.trim() == _confirmationText;
    if (confirmed != _isConfirmed) {
      setState(() => _isConfirmed = confirmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(context.l10n.divers_detail_deleteDialogTitle),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.divers_detail_deleteDialogContent(widget.diverName),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: context.l10n.divers_detail_deleteDialogConfirmHint(
                widget.diverName,
              ),
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.divers_detail_cancelButton),
        ),
        FilledButton(
          onPressed: _isConfirmed
              ? () => Navigator.of(context).pop(true)
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          child: Text(context.l10n.divers_detail_deleteButton),
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: Update other locale files**

Update the same key in all `app_*.arb` files. The content string and new
confirm hint key must be present in every locale. Use the English text as
a placeholder for non-English locales (they can be translated later).

- [ ] **Step 4: Run codegen and verify**

Run: `flutter gen-l10n` (or `flutter pub get` if gen-l10n runs automatically)
Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 5: Commit**

```
feat: type-to-confirm diver profile deletion

Replace the simple delete confirmation with a type-to-confirm dialog
matching the database reset pattern. Users must type "Delete [name]"
(case-sensitive) before the button activates.

Updated dialog text to reflect that all associated data is permanently
deleted, not just unassigned.
```

---

### Task 7: Regenerate mocks and full test pass

**Files:**
- Regenerate all `.mocks.dart` files

- [ ] **Step 1: Regenerate mocks**

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 2: Format code**

Run: `dart format lib/ test/`

- [ ] **Step 3: Run full test suite**

Run: `flutter test`
Expected: All tests PASS.

- [ ] **Step 4: Run analyze**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 5: Commit**

```
chore: regenerate mocks and format code
```
