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
    'equipmentSetGeofences + isDefault round-trip through the serializer',
    () async {
      await serializer.upsertRecord('equipmentSets', {
        'id': 's1',
        'name': 'Cold',
        'description': '',
        'isDefault': true,
        'createdAt': 1000,
        'updatedAt': 1000,
      });
      await serializer.upsertRecord('equipmentSetGeofences', {
        'id': 'g1',
        'setId': 's1',
        'label': 'Monterey',
        'latitude': 36.62,
        'longitude': -121.9,
        'radiusMeters': 24000,
        'createdAt': 1000,
        'updatedAt': 1000,
      });

      final fence = await serializer.fetchRecord('equipmentSetGeofences', 'g1');
      expect(fence, isNotNull);
      expect(fence!['setId'], 's1');
      expect(fence['radiusMeters'], 24000);

      // isDefault rides the equipmentSets row (no dedicated serializer change).
      final setRow = await serializer.fetchRecord('equipmentSets', 's1');
      expect(setRow!['isDefault'], anyOf(true, 1));

      await serializer.deleteRecord('equipmentSetGeofences', 'g1');
      expect(
        await serializer.fetchRecord('equipmentSetGeofences', 'g1'),
        isNull,
      );
    },
  );

  test('geofences round-trip through the batch fetch/upsert paths', () async {
    // The streaming/base sync paths use the batch variants (fetchRecords /
    // upsertRecords), distinct from the single-record CRUD above.
    await serializer.upsertRecord('equipmentSets', {
      'id': 's1',
      'name': 'Cold',
      'description': '',
      'isDefault': false,
      'createdAt': 1000,
      'updatedAt': 1000,
    });

    await serializer.upsertRecords('equipmentSetGeofences', [
      {
        'id': 'g1',
        'setId': 's1',
        'label': 'Monterey',
        'latitude': 36.62,
        'longitude': -121.9,
        'radiusMeters': 24000,
        'createdAt': 1000,
        'updatedAt': 1000,
      },
      {
        'id': 'g2',
        'setId': 's1',
        'label': 'Carmel',
        'latitude': 36.55,
        'longitude': -121.92,
        'radiusMeters': 10000,
        'createdAt': 1000,
        'updatedAt': 1000,
      },
    ]);

    final fetched = await serializer.fetchRecords('equipmentSetGeofences', [
      'g1',
      'g2',
    ]);
    expect(fetched.keys, containsAll(['g1', 'g2']));
    expect(fetched['g2']!['radiusMeters'], 10000);
  });
}
