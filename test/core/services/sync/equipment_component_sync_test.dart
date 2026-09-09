import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/test_database.dart';

/// equipmentComponents is a clocked child of equipment (issue #1487), wired
/// exactly like equipmentAttributes: surrogate id, own hlc, table-backed
/// export descriptor, no composite-id branch.
void main() {
  late SyncDataSerializer serializer;

  setUp(() async {
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });
  tearDown(tearDownTestDatabase);

  Map<String, dynamic> componentJson(
    String id, {
    String parent = 'reg',
    String component = 'hose',
    String role = 'Primary',
  }) => {
    'id': id,
    'parentEquipmentId': parent,
    'componentEquipmentId': component,
    'role': role,
    'sortOrder': 0,
    'createdAt': 1000,
    'updatedAt': 1000,
    'hlc': null,
  };

  Future<void> insertEquipment(String id) =>
      serializer.upsertRecord('equipment', {
        'id': id,
        'name': id,
        'type': 'regulator',
        'status': 'active',
        'purchaseCurrency': 'USD',
        'notes': '',
        'isActive': true,
        'createdAt': 1000,
        'updatedAt': 1000,
      });

  test('round-trips through upsertRecord, fetchRecord, deleteRecord', () async {
    await insertEquipment('reg');
    await insertEquipment('hose');
    await serializer.upsertRecord('equipmentComponents', componentJson('c1'));

    final row = await serializer.fetchRecord('equipmentComponents', 'c1');
    expect(row, isNotNull);
    expect(row!['parentEquipmentId'], 'reg');
    expect(row['componentEquipmentId'], 'hose');
    expect(row['role'], 'Primary');

    await serializer.deleteRecord('equipmentComponents', 'c1');
    expect(await serializer.fetchRecord('equipmentComponents', 'c1'), isNull);
  });

  test('round-trips through the batch paths and recordIdsFor', () async {
    await insertEquipment('reg');
    await insertEquipment('hose');
    await insertEquipment('first');
    await serializer.upsertRecords('equipmentComponents', [
      componentJson('c1'),
      componentJson('c2', component: 'first'),
    ]);
    final fetched = await serializer.fetchRecords('equipmentComponents', [
      'c1',
      'c2',
    ]);
    expect(fetched.keys, containsAll(['c1', 'c2']));
    expect(
      await serializer.recordIdsFor('equipmentComponents'),
      containsAll(['c1', 'c2']),
    );
  });

  test('is registered as a clocked entity after its parent', () {
    expect(SyncService.entityHasUpdatedAt['equipmentComponents'], isTrue);
    final refs = SyncService.parentRefs['equipmentComponents']!;
    expect(
      refs.map((r) => '${r.field}:${r.parent}:${r.nullable}'),
      unorderedEquals([
        'parentEquipmentId:equipment:false',
        'componentEquipmentId:equipment:false',
      ]),
    );
  });

  test(
    'the gear junctions declare the provenance columns as nullable refs',
    () {
      for (final entity in ['diveEquipment', 'divePlanEquipment']) {
        final refs = SyncService.parentRefs[entity]!;
        expect(
          refs.map((r) => '${r.field}:${r.parent}:${r.nullable}'),
          containsAll([
            'viaEquipmentId:equipment:true',
            'viaSetId:equipmentSets:true',
          ]),
          reason: entity,
        );
      }
    },
  );
}
