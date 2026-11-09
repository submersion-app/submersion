import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';

import '../../../helpers/test_database.dart';

/// cylinderPairings (issue #4242) is a clocked link between two equipment
/// rows, wired like equipmentComponents: surrogate id, own hlc, both
/// cylinders as non-null parent refs.
void main() {
  late SyncDataSerializer serializer;

  setUp(() async {
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });
  tearDown(tearDownTestDatabase);

  Map<String, dynamic> pairingJson(
    String id, {
    String a = 'A',
    String b = 'B',
    int pairedOn = 1767225600000,
    int? unpairedOn,
  }) => {
    'id': id,
    'cylinderAId': a,
    'cylinderBId': b,
    'pairedOn': pairedOn,
    'unpairedOn': unpairedOn,
    'createdAt': 1000,
    'updatedAt': 1000,
    'hlc': null,
  };

  Future<void> insertCylinder(String id) =>
      serializer.upsertRecord('equipment', {
        'id': id,
        'name': id,
        'type': 'tank',
        'status': 'active',
        'purchaseCurrency': 'USD',
        'notes': '',
        'isActive': true,
        'createdAt': 1000,
        'updatedAt': 1000,
      });

  test('round-trips through upsertRecord, fetchRecord, deleteRecord', () async {
    await insertCylinder('A');
    await insertCylinder('B');
    await serializer.upsertRecord(
      'cylinderPairings',
      pairingJson('p1', unpairedOn: 1789000000000),
    );

    final row = await serializer.fetchRecord('cylinderPairings', 'p1');
    expect(row, isNotNull);
    expect(row!['cylinderAId'], 'A');
    expect(row['cylinderBId'], 'B');
    expect(row['pairedOn'], 1767225600000);
    expect(row['unpairedOn'], 1789000000000);

    await serializer.deleteRecord('cylinderPairings', 'p1');
    expect(await serializer.fetchRecord('cylinderPairings', 'p1'), isNull);
  });

  test('round-trips through the batch paths and recordIdsFor', () async {
    await insertCylinder('A');
    await insertCylinder('B');
    await insertCylinder('C');
    await serializer.upsertRecords('cylinderPairings', [
      pairingJson('p1', unpairedOn: 1767312000000),
      pairingJson('p2', b: 'C', pairedOn: 1767312000000),
    ]);
    final fetched = await serializer.fetchRecords('cylinderPairings', [
      'p1',
      'p2',
    ]);
    expect(fetched.keys, containsAll(['p1', 'p2']));
    expect(
      await serializer.recordIdsFor('cylinderPairings'),
      containsAll(['p1', 'p2']),
    );
  });

  test('a full export carries the pairings', () async {
    await insertCylinder('A');
    await insertCylinder('B');
    await serializer.upsertRecord('cylinderPairings', pairingJson('p1'));
    final payload = await serializer.exportData(
      deviceId: 'dev',
      deletions: const [],
    );
    final data = payload.data;
    expect(data.cylinderPairings.map((r) => r['id']), ['p1']);
    final back = SyncData.fromJson(data.toJson());
    expect(back.cylinderPairings.single['cylinderBId'], 'B');
  });

  test('is registered as a clocked entity after its parents', () {
    expect(SyncService.entityHasUpdatedAt['cylinderPairings'], isTrue);
    final refs = SyncService.parentRefs['cylinderPairings']!;
    expect(
      refs.map((r) => '${r.field}:${r.parent}:${r.nullable}'),
      unorderedEquals([
        'cylinderAId:equipment:false',
        'cylinderBId:equipment:false',
      ]),
    );
  });

  test('deleting a cylinder tombstones its pairings for peers', () async {
    await insertCylinder('A');
    await insertCylinder('B');
    await serializer.upsertRecord('cylinderPairings', pairingJson('p1'));
    await EquipmentRepository().deleteEquipment('B');

    expect(await serializer.fetchRecord('cylinderPairings', 'p1'), isNull);
    final tombstones = await DatabaseService.instance.database
        .customSelect(
          'SELECT record_id FROM deletion_log WHERE entity_type = ?',
          variables: [Variable.withString('cylinderPairings')],
        )
        .get();
    expect(tombstones.map((r) => r.read<String>('record_id')), ['p1']);
  });
}
