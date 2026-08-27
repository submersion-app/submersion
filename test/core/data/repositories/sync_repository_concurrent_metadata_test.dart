import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';

import '../../../helpers/test_database.dart';

void main() {
  group('SyncRepository.getOrCreateMetadata concurrency', () {
    late SyncRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = SyncRepository();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    // Reproduces the fresh-DB launch race: the launch reconcile
    // (getDeviceId) and the Cloud Sync page (getLastSyncTime) both call
    // getOrCreateMetadata before the 'global' row exists. A non-idempotent
    // insert makes the loser throw SqliteException(1555) UNIQUE constraint
    // failed, which the page surfaces as "Failed to load sync state".
    test('concurrent seed inserts do not throw a UNIQUE constraint', () async {
      final results = await Future.wait(
        List.generate(8, (_) => repository.getOrCreateMetadata()),
      );

      // Every caller resolves to the same seeded row (first writer wins).
      final deviceIds = results.map((m) => m.deviceId).toSet();
      expect(deviceIds, hasLength(1));
      expect(deviceIds.single, isNotEmpty);
    });
  });
}
