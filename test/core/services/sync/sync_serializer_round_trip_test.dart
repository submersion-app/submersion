import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/test_database.dart';
import '../../../helpers/mock_providers.dart';

void main() {
  group('Sync serializer symmetry', () {
    setUp(() async {
      await setUpTestDatabase();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test(
      'a dive survives export -> serialize -> deserialize with valid checksum',
      () async {
        // Seed one dive. If the first run fails on a foreign-key requirement
        // (e.g. a diver must exist), insert that prerequisite first — the red
        // run will tell you exactly what is missing.
        final dive = createTestDiveWithBottomTime(
          id: 'dive-rt-1',
          diveNumber: 7,
        );
        await DiveRepository().createDive(dive);

        final serializer = SyncDataSerializer();
        final repo = SyncRepository();
        final deviceId = await repo.getDeviceId();
        final deletions = await repo.getAllDeletions();

        final payload = await serializer.exportData(
          deviceId: deviceId,
          since: null,
          lastSyncTimestamp: null,
          deletions: deletions,
        );
        final json = serializer.serializePayload(payload);
        final restored = serializer.deserializePayload(json);

        expect(
          serializer.validateChecksum(payload),
          isTrue,
          reason:
              'a locally built payload (rawDataJson == null) must validate '
              'via the re-serialization fallback',
        );
        expect(
          serializer.validateChecksum(restored),
          isTrue,
          reason: 'checksum should validate after a clean round-trip',
        );
        expect(
          json,
          contains('dive-rt-1'),
          reason: 'the seeded dive must appear in the exported payload',
        );
      },
    );
  });
}
