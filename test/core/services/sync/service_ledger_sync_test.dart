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

  test(
    'export skips built-in kinds, includes custom kinds and schedules',
    () async {
      await serializer.upsertRecord('serviceKinds', {
        'id': 'custom-1',
        'name': 'Scrubber repack',
        'applicableTypes': '["other"]',
        'autoAttach': false,
        'isBuiltIn': false,
        'createdAt': 1000,
        'updatedAt': 1000,
      });
      await serializer.upsertRecord('equipment', {
        'id': 'e1',
        'name': 'AL80',
        'type': 'tank',
        'status': 'active',
        'purchaseCurrency': 'USD',
        'notes': '',
        'isActive': true,
        'createdAt': 1000,
        'updatedAt': 1000,
      });
      await serializer.upsertRecord('serviceSchedules', {
        'id': 's1',
        'equipmentId': 'e1',
        'serviceKindId': 'hydro',
        'enabled': true,
        'createdAt': 1000,
        'updatedAt': 1000,
      });

      final payload = await serializer.exportData(
        deviceId: 'test-device',
        deletions: const [],
      );
      expect(
        payload.data.serviceKinds.map((k) => k['id']),
        isNot(contains('hydro')), // built-in excluded
      );
      expect(
        payload.data.serviceKinds.map((k) => k['id']),
        contains('custom-1'),
      );
      expect(payload.data.serviceSchedules.map((s) => s['id']), contains('s1'));
    },
  );

  test('serviceSchedules round-trip through single-record CRUD', () async {
    await serializer.upsertRecord('equipment', {
      'id': 'e1',
      'name': 'AL80',
      'type': 'tank',
      'status': 'active',
      'purchaseCurrency': 'USD',
      'notes': '',
      'isActive': true,
      'createdAt': 1000,
      'updatedAt': 1000,
    });
    await serializer.upsertRecord('serviceSchedules', {
      'id': 's-remote',
      'equipmentId': 'e1',
      'serviceKindId': 'vip',
      'intervalDays': 400,
      'enabled': true,
      'createdAt': 1000,
      'updatedAt': 1000,
    });

    final row = await serializer.fetchRecord('serviceSchedules', 's-remote');
    expect(row, isNotNull);
    expect(row!['equipmentId'], 'e1');
    expect(row['intervalDays'], 400);

    await serializer.deleteRecord('serviceSchedules', 's-remote');
    expect(
      await serializer.fetchRecord('serviceSchedules', 's-remote'),
      isNull,
    );
  });

  test('serviceKinds round-trip through single-record CRUD', () async {
    await serializer.upsertRecord('serviceKinds', {
      'id': 'k-solo',
      'name': 'Solo kind',
      'applicableTypes': '[]',
      'autoAttach': false,
      'isBuiltIn': false,
      'createdAt': 1000,
      'updatedAt': 1000,
    });
    final row = await serializer.fetchRecord('serviceKinds', 'k-solo');
    expect(row, isNotNull);
    expect(row!['name'], 'Solo kind');

    await serializer.deleteRecord('serviceKinds', 'k-solo');
    expect(await serializer.fetchRecord('serviceKinds', 'k-solo'), isNull);
  });

  test('serviceSchedules round-trip through batch paths', () async {
    await serializer.upsertRecord('equipment', {
      'id': 'e1',
      'name': 'AL80',
      'type': 'tank',
      'status': 'active',
      'purchaseCurrency': 'USD',
      'notes': '',
      'isActive': true,
      'createdAt': 1000,
      'updatedAt': 1000,
    });
    await serializer.upsertRecords('serviceSchedules', [
      {
        'id': 'b1',
        'equipmentId': 'e1',
        'serviceKindId': 'hydro',
        'enabled': true,
        'createdAt': 1000,
        'updatedAt': 1000,
      },
      {
        'id': 'b2',
        'equipmentId': 'e1',
        'serviceKindId': 'vip',
        'enabled': false,
        'createdAt': 1000,
        'updatedAt': 1000,
      },
    ]);
    final rows = await serializer.fetchRecords('serviceSchedules', [
      'b1',
      'b2',
    ]);
    expect(rows.keys, containsAll(['b1', 'b2']));
    expect(rows['b2']!['enabled'], anyOf(false, 0));
  });

  test('serviceKinds round-trip through batch paths', () async {
    await serializer.upsertRecords('serviceKinds', [
      {
        'id': 'k1',
        'name': 'Custom A',
        'applicableTypes': '[]',
        'autoAttach': false,
        'isBuiltIn': false,
        'createdAt': 1000,
        'updatedAt': 1000,
      },
      {
        'id': 'k2',
        'name': 'Custom B',
        'applicableTypes': '[]',
        'autoAttach': true,
        'isBuiltIn': false,
        'createdAt': 1000,
        'updatedAt': 1000,
      },
    ]);
    final rows = await serializer.fetchRecords('serviceKinds', ['k1', 'k2']);
    expect(rows.keys, containsAll(['k1', 'k2']));
    expect(rows['k2']!['autoAttach'], anyOf(true, 1));
  });
}
