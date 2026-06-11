import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';

import '../../../helpers/test_database.dart';

/// Tests for the library-epoch anchor on sync metadata (restore Replace
/// mode). The epoch a device last accepted must round-trip through the
/// database and survive [SyncRepository.rebaselineAfterRestore] via the
/// caller-captured live value, never the backup's stale copy.
void main() {
  late SyncRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = SyncRepository();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  group('last accepted epoch', () {
    test('defaults to null and round-trips', () async {
      expect(await repo.getLastAcceptedEpochId(), isNull);
      await repo.setLastAcceptedEpochId('epoch-1');
      expect(await repo.getLastAcceptedEpochId(), 'epoch-1');
      await repo.setLastAcceptedEpochId(null);
      expect(await repo.getLastAcceptedEpochId(), isNull);
    });

    test(
      'rebaselineAfterRestore overwrites epoch with the preserved value',
      () async {
        await repo.setLastAcceptedEpochId('stale-from-backup');
        await repo.rebaselineAfterRestore(
          preserveDeviceId: 'device-1',
          preserveEpochId: 'live-epoch',
        );
        expect(await repo.getLastAcceptedEpochId(), 'live-epoch');
        expect(await repo.getDeviceId(), 'device-1');
      },
    );

    test('rebaselineAfterRestore with no epoch clears the stale one', () async {
      await repo.setLastAcceptedEpochId('stale-from-backup');
      await repo.rebaselineAfterRestore(preserveDeviceId: 'device-1');
      expect(await repo.getLastAcceptedEpochId(), isNull);
    });
  });
}
