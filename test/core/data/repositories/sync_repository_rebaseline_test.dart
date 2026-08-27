import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';

import '../../../helpers/test_database.dart';

/// Regression tests for the restore-breaks-sync bug.
///
/// A database restore replaces the whole DB, so `sync_metadata` (device id,
/// HLC clock, last-sync timestamp, cursors) and the deletion log revert to the
/// backup's stale snapshot. The merge gates on the persisted `lastSync`
/// (`localUpdatedAt > lastSyncMs` flags spurious conflicts), so a rewound
/// baseline stalls sync and lets a peer's still-live copy keep resurrecting
/// deletes. [SyncRepository.rebaselineAfterRestore] clears that baseline while
/// preserving the live device identity, so the next sync does a clean full
/// reconcile of the restored data.
void main() {
  late SyncRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = SyncRepository();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  group('rebaselineAfterRestore', () {
    test('clears the rewound baseline (lastSync + tombstones) and preserves '
        'the live device id', () async {
      // The state a restored DB lands in: a metadata row already exists (the
      // backup has one) carrying a stale lastSync, plus a leftover tombstone
      // from the backup snapshot.
      await repo.getOrCreateMetadata();
      await repo.updateLastSyncTime(DateTime.fromMillisecondsSinceEpoch(1000));
      await repo.logDeletion(entityType: 'dives', recordId: 'old-tombstone');
      expect(await repo.getLastSyncTime(), isNotNull);
      expect(await repo.getAllDeletions(), isNotEmpty);

      await repo.rebaselineAfterRestore(preserveDeviceId: 'device-LIVE');

      expect(
        await repo.getLastSyncTime(),
        isNull,
        reason:
            'lastSync must be cleared so the next sync does a full reconcile '
            'instead of replaying a rewound baseline',
      );
      expect(
        await repo.getAllDeletions(),
        isEmpty,
        reason: "the backup's stale tombstones must be cleared",
      );
      expect(
        await repo.getDeviceId(),
        'device-LIVE',
        reason:
            'the live device identity must survive the restore rather than be '
            "replaced by the backup's device id",
      );
    });

    test(
      'keeps the current device id when no preserve id is supplied',
      () async {
        final original = await repo.getDeviceId();
        await repo.rebaselineAfterRestore();
        expect(await repo.getDeviceId(), original);
        expect(await repo.getLastSyncTime(), isNull);
      },
    );
  });

  group('setDeviceId validation', () {
    test('rejects an empty or blank device id', () async {
      // A blank id would corrupt the per-device sync file name and HLC node id.
      await expectLater(repo.setDeviceId(''), throwsArgumentError);
      await expectLater(repo.setDeviceId('   '), throwsArgumentError);
    });

    test('persists a valid device id', () async {
      await repo.setDeviceId('device-XYZ');
      expect(await repo.getDeviceId(), 'device-XYZ');
    });
  });
}
