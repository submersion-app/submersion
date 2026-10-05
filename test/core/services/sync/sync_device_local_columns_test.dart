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

    Future<DiveComputer> storedComputer(String id) => (db.select(
      db.diveComputers,
    )..where((t) => t.id.equals(id))).getSingle();

    test('upsertRecord keeps the local address', () async {
      final local = await seedComputer();
      await serializer.upsertRecord('diveComputers', {
        ...local,
        'name': 'Perdix 2',
        'bluetoothAddress': 'CC:DD',
        'updatedAt': (local['updatedAt'] as int) + 1000,
      });
      final row = await storedComputer('c1');
      expect(row.name, 'Perdix 2');
      expect(row.bluetoothAddress, 'AA:BB');
    });

    test('upsertRecords keeps the local address', () async {
      final local = await seedComputer();
      await serializer.upsertRecords('diveComputers', [
        {...local, 'bluetoothAddress': null},
      ]);
      expect((await storedComputer('c1')).bluetoothAddress, 'AA:BB');
    });

    test('a replace-adopt clear and refill keeps the local address', () async {
      final local = await seedComputer();
      await serializer.deleteAllRecords('diveComputers');
      await serializer.upsertRecords('diveComputers', [
        withoutKeys(local, {'bluetoothAddress'}),
      ]);
      expect((await storedComputer('c1')).bluetoothAddress, 'AA:BB');
    });

    test('a computer new to this device has no address', () async {
      final local = await seedComputer();
      await serializer.upsertRecord('diveComputers', {
        ...local,
        'id': 'c2',
        'bluetoothAddress': 'EE:FF',
      });
      expect((await storedComputer('c2')).bluetoothAddress, isNull);
    });
  });
}

Map<String, dynamic> withoutKeys(Map<String, dynamic> row, Set<String> keys) =>
    {...row}..removeWhere((key, _) => keys.contains(key));
