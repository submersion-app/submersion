import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';

import '../../../helpers/test_database.dart';

void main() {
  group('SyncRepository error handling', () {
    late SyncRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = SyncRepository();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('methods that rethrow throw on database error', () async {
      await DatabaseService.instance.database.close();
      DatabaseService.instance.resetForTesting();

      await expectLater(repository.getOrCreateMetadata(), throwsA(anything));
      await expectLater(
        repository.updateLastSyncTime(DateTime.now()),
        throwsA(anything),
      );
      await expectLater(repository.setCloudProvider(null), throwsA(anything));
      await expectLater(
        repository.setRemoteFileId('file-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.markRecordPending(
          entityType: 'dives',
          recordId: 'test-id',
          localUpdatedAt: 0,
        ),
        throwsA(anything),
      );
      await expectLater(
        repository.markRecordSynced(entityType: 'dives', recordId: 'test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.markRecordConflict(
          entityType: 'dives',
          recordId: 'test-id',
          conflictDataJson: '{}',
          localUpdatedAt: 0,
        ),
        throwsA(anything),
      );
      await expectLater(repository.getPendingRecords(), throwsA(anything));
      await expectLater(repository.getConflictRecords(), throwsA(anything));
      await expectLater(repository.clearPendingRecords(), throwsA(anything));
      await expectLater(
        repository.clearConflict(entityType: 'dives', recordId: 'test-id'),
        throwsA(anything),
      );
      await expectLater(repository.clearAllSyncRecords(), throwsA(anything));
      await expectLater(
        repository.logDeletion(entityType: 'dives', recordId: 'test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.getDeletionsSince(DateTime.now()),
        throwsA(anything),
      );
      await expectLater(repository.getAllDeletions(), throwsA(anything));
      await expectLater(repository.clearOldDeletions(), throwsA(anything));
      await expectLater(repository.clearAllDeletions(), throwsA(anything));
      await expectLater(repository.resetSyncState(), throwsA(anything));
    });

    test(
      'methods that return defaults return correct values on error',
      () async {
        await DatabaseService.instance.database.close();
        DatabaseService.instance.resetForTesting();

        // getPendingCount returns 0 on error
        expect(await repository.getPendingCount(), equals(0));

        // getConflictCount returns 0 on error
        expect(await repository.getConflictCount(), equals(0));
      },
    );
  });
}
