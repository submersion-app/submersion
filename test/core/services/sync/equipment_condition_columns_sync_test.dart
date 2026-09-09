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

  Map<String, dynamic> equipment(String id, {String? parent}) => {
    'id': id,
    'name': id,
    'type': 'o2Cell',
    'status': 'active',
    'purchaseCurrency': 'USD',
    'notes': '',
    'isActive': true,
    'createdAt': 1000,
    'updatedAt': 1000,
    'parentEquipmentId': ?parent,
  };

  test(
    'equipment.parentEquipmentId round-trips and tolerates omission',
    () async {
      await serializer.upsertRecord('equipment', equipment('unit'));
      await serializer.upsertRecord(
        'equipment',
        equipment('cell', parent: 'unit'),
      );
      final row = await serializer.fetchRecord('equipment', 'cell');
      expect(row!['parentEquipmentId'], 'unit');

      // An older peer republishes a row without the key: it still applies.
      await serializer.upsertRecord('equipment', equipment('orphan'));
      expect(
        (await serializer.fetchRecord(
          'equipment',
          'orphan',
        ))!['parentEquipmentId'],
        isNull,
      );
    },
  );

  test('service ledger rows carry exposureIntervals', () async {
    final reg = await serializer.fetchRecord(
      'serviceKinds',
      'regulator-service',
    );
    expect(reg!['exposureIntervals'], '{"coldDives":50}');

    await serializer.upsertRecord('equipment', equipment('r1'));
    await serializer.upsertRecord('serviceSchedules', {
      'id': 's1',
      'equipmentId': 'r1',
      'serviceKindId': 'regulator-service',
      'exposureIntervals': '{"coldDives":25.0}',
      'enabled': true,
      'createdAt': 1000,
      'updatedAt': 1000,
    });
    expect(
      (await serializer.fetchRecord(
        'serviceSchedules',
        's1',
      ))!['exposureIntervals'],
      '{"coldDives":25.0}',
    );
  });

  test('dive tanks carry regulatorEquipmentId', () async {
    await serializer.upsertRecord('equipment', equipment('reg'));
    await serializer.upsertRecord('dives', {
      'id': 'd1',
      'diveDateTime': 1000,
      'createdAt': 1000,
      'updatedAt': 1000,
    });
    await serializer.upsertRecord('diveTanks', {
      'id': 't1',
      'diveId': 'd1',
      'o2Percent': 32.0,
      'hePercent': 0.0,
      'tankOrder': 0,
      'tankRole': 'backGas',
      'regulatorEquipmentId': 'reg',
    });
    expect(
      (await serializer.fetchRecord(
        'diveTanks',
        't1',
      ))!['regulatorEquipmentId'],
      'reg',
    );
  });
}
