// Issue #3651: the history rows name the device behind each backup by
// comparing tags against this device's id, so that id must follow the
// database. A restore reopens the database in place, and the id lives in it.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/unused_backup_database_adapter.dart';

class _Device extends SyncRepository {
  String deviceId = 'before-restore';

  @override
  Future<String> getDeviceId() async => deviceId;

  @override
  Future<String?> getSyncAccountId() async => 'acct';
}

void main() {
  test('a history refresh re-reads this device id', () async {
    SharedPreferences.setMockInitialValues({});
    final device = _Device();
    final container = ProviderContainer(
      overrides: [
        backupServiceProvider.overrideWithValue(
          BackupService(
            dbAdapter: UnusedBackupDatabaseAdapter(),
            preferences: BackupPreferences(
              await SharedPreferences.getInstance(),
            ),
            cloudProvider: FakeCloudStorageProvider(),
            syncRepository: device,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Both stay alive, as they do while the Backups page is open.
    final history = container.listen(backupHistoryProvider, (_, _) {});
    addTearDown(history.close);
    final id = container.listen(backupDeviceIdProvider, (_, _) {});
    addTearDown(id.close);

    await container.read(backupHistoryProvider.future);
    expect(
      await container.read(backupDeviceIdProvider.future),
      'before-restore',
    );

    device.deviceId = 'after-restore';
    container.invalidate(backupHistoryProvider);
    await container.read(backupHistoryProvider.future);

    expect(
      await container.read(backupDeviceIdProvider.future),
      'after-restore',
    );
  });
}
