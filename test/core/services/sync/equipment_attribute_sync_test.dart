import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

void main() {
  late SyncDataSerializer serializer;

  setUp(() async {
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });
  tearDown(tearDownTestDatabase);

  Map<String, dynamic> attrJson(String id, {String attrKey = 'thickness_mm'}) =>
      {
        'id': id,
        'equipmentId': 'eq1',
        'attrKey': attrKey,
        'isCustom': false,
        'valueText': '5/4',
        'valueNum': 5.0,
        'sortOrder': 0,
        'createdAt': 1000,
        'updatedAt': 1000,
        'hlc': null,
      };

  Future<void> insertParentEquipment() => serializer.upsertRecord('equipment', {
    'id': 'eq1',
    'name': 'Suit',
    'type': 'wetsuit',
    'status': 'active',
    'purchaseCurrency': 'USD',
    'notes': '',
    'isActive': true,
    'createdAt': 1000,
    'updatedAt': 1000,
  });

  test('equipmentAttributes round-trip through the serializer', () async {
    await insertParentEquipment();
    await serializer.upsertRecord(
      'equipmentAttributes',
      attrJson('attr_eq1_thickness_mm'),
    );

    final row = await serializer.fetchRecord(
      'equipmentAttributes',
      'attr_eq1_thickness_mm',
    );
    expect(row, isNotNull);
    expect(row!['equipmentId'], 'eq1');
    expect(row['valueNum'], 5.0);
    expect(row['valueText'], '5/4');

    await serializer.deleteRecord(
      'equipmentAttributes',
      'attr_eq1_thickness_mm',
    );
    expect(
      await serializer.fetchRecord(
        'equipmentAttributes',
        'attr_eq1_thickness_mm',
      ),
      isNull,
    );
  });

  test('equipmentAttributes round-trip through batch fetch/upsert', () async {
    await insertParentEquipment();
    await serializer.upsertRecords('equipmentAttributes', [
      attrJson('a1'),
      attrJson('a2', attrKey: 'size'),
    ]);
    final fetched = await serializer.fetchRecords('equipmentAttributes', [
      'a1',
      'a2',
    ]);
    expect(fetched.keys, containsAll(['a1', 'a2']));

    final ids = await serializer.recordIdsFor('equipmentAttributes');
    expect(ids, containsAll(['a1', 'a2']));
  });
}
