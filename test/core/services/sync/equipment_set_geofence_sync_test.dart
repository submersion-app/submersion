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
}
