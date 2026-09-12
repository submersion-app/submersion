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

  test('serviceKinds carry the v154 default price over the wire', () async {
    await serializer.upsertRecord('serviceKinds', {
      'id': 'k-priced',
      'name': 'Disinfect',
      'applicableTypes': '[]',
      'defaultCost': 12.5,
      'defaultCurrency': 'EUR',
      'autoAttach': false,
      'isBuiltIn': false,
      'createdAt': 1000,
      'updatedAt': 1000,
    });

    final row = await serializer.fetchRecord('serviceKinds', 'k-priced');
    expect(row!['defaultCost'], 12.5);
    expect(row['defaultCurrency'], 'EUR');
  });

  test('a payload omitting defaultCost leaves it null, not absent', () async {
    // Direction that matters for cross-version peers: an older build knows
    // nothing about these columns and simply does not send them.
    await serializer.upsertRecord('serviceKinds', {
      'id': 'k-legacy',
      'name': 'Legacy kind',
      'applicableTypes': '[]',
      'autoAttach': false,
      'isBuiltIn': false,
      'createdAt': 1000,
      'updatedAt': 1000,
    });

    final row = await serializer.fetchRecord('serviceKinds', 'k-legacy');
    expect(row!.containsKey('defaultCost'), isTrue);
    expect(row['defaultCost'], isNull);
  });

  test('serviceSchedules carry the v154 default price over the wire', () async {
    await serializer.upsertRecord('equipment', {
      'id': 'e-priced',
      'name': 'JJ-CCR',
      'type': 'rebreather',
      'status': 'active',
      'purchaseCurrency': 'EUR',
      'notes': '',
      'isActive': true,
      'createdAt': 1000,
      'updatedAt': 1000,
    });
    await serializer.upsertRecord('serviceSchedules', {
      'id': 's-priced',
      'equipmentId': 'e-priced',
      'serviceKindId': 'hydro',
      'defaultCost': 45.0,
      'defaultCurrency': 'EUR',
      'enabled': true,
      'createdAt': 1000,
      'updatedAt': 1000,
    });

    final row = await serializer.fetchRecord('serviceSchedules', 's-priced');
    expect(row!['defaultCost'], 45.0);
    expect(row['defaultCurrency'], 'EUR');
  });

  test(
    'serviceSchedules carry the v213 baseline set time over the wire',
    () async {
      // The set time is what lets a baseline outrank the records logged
      // before it; a serializer that dropped it would quietly turn every
      // synced baseline back into a legacy one (any record wins).
      await serializer.upsertRecord('equipment', {
        'id': 'e-baseline',
        'name': 'Reg',
        'type': 'regulator',
        'status': 'active',
        'purchaseCurrency': 'USD',
        'notes': '',
        'isActive': true,
        'createdAt': 1000,
        'updatedAt': 1000,
      });
      await serializer.upsertRecord('serviceSchedules', {
        'id': 's-single',
        'equipmentId': 'e-baseline',
        'serviceKindId': 'regulator-service',
        'anchorDate': 1719792000000,
        'anchorSetAt': 1757660000000,
        'enabled': true,
        'createdAt': 1000,
        'updatedAt': 1000,
      });
      await serializer.upsertRecords('serviceSchedules', [
        {
          'id': 's-batch',
          'equipmentId': 'e-baseline',
          'serviceKindId': 'hydro',
          'anchorDate': 1719792000000,
          'anchorSetAt': 1757660000001,
          'enabled': true,
          'createdAt': 1000,
          'updatedAt': 1000,
        },
      ]);

      final single = await serializer.fetchRecord(
        'serviceSchedules',
        's-single',
      );
      expect(single!['anchorDate'], 1719792000000);
      expect(single['anchorSetAt'], 1757660000000);
      final batch = await serializer.fetchRecords('serviceSchedules', [
        's-batch',
      ]);
      expect(batch['s-batch']!['anchorSetAt'], 1757660000001);

      final payload = await serializer.exportData(
        deviceId: 'test-device',
        deletions: const [],
      );
      final exported = payload.data.serviceSchedules.firstWhere(
        (s) => s['id'] == 's-single',
      );
      expect(exported['anchorSetAt'], 1757660000000);
    },
  );

  test('a schedule from a peer without the set time stays legacy', () async {
    // An older build sends no anchorSetAt: the baseline must land with a
    // null set time (the pre-v213 rule), not a default that would stamp it.
    await serializer.upsertRecord('equipment', {
      'id': 'e-old-peer',
      'name': 'Reg',
      'type': 'regulator',
      'status': 'active',
      'purchaseCurrency': 'USD',
      'notes': '',
      'isActive': true,
      'createdAt': 1000,
      'updatedAt': 1000,
    });
    await serializer.upsertRecord('serviceSchedules', {
      'id': 's-old-peer',
      'equipmentId': 'e-old-peer',
      'serviceKindId': 'regulator-service',
      'anchorDate': 1719792000000,
      'enabled': true,
      'createdAt': 1000,
      'updatedAt': 1000,
    });

    final row = await serializer.fetchRecord('serviceSchedules', 's-old-peer');
    expect(row!['anchorDate'], 1719792000000);
    expect(row['anchorSetAt'], isNull);
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
