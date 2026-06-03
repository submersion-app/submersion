import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/test_database.dart';
import '../../../helpers/mock_providers.dart';

void main() {
  group('Applying a received record (upsertRecord)', () {
    setUp(() async {
      await setUpTestDatabase();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test(
      'a deserialized dive can be applied on a device that lacks it',
      () async {
        final diveRepo = DiveRepository();

        // Produce the record exactly as a receiving device sees it: through a
        // full export -> serialize -> deserialize cycle.
        await diveRepo.createDive(
          createTestDiveWithBottomTime(id: 'dive-up-1'),
        );
        final serializer = SyncDataSerializer();
        final repo = SyncRepository();
        final payload = await serializer.exportData(
          deviceId: await repo.getDeviceId(),
          since: null,
          lastSyncTimestamp: null,
          deletions: await repo.getAllDeletions(),
        );
        final received = serializer.deserializePayload(
          serializer.serializePayload(payload),
        );
        final diveMap = received.data.dives.firstWhere(
          (d) => d['id'] == 'dive-up-1',
        );

        // Simulate the receiving device not having the dive yet.
        await diveRepo.deleteDive('dive-up-1');

        // Apply the received record (this is what _mergeEntity does). It
        // currently throws, and the caller masks the failure as a "conflict".
        await serializer.upsertRecord('dives', diveMap);

        expect(await diveRepo.getDiveById('dive-up-1'), isNotNull);
      },
    );
  });
}
