import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/providers/cross_device_retention_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/unused_backup_database_adapter.dart';

class _Device extends SyncRepository {
  @override
  Future<String> getDeviceId() async => 'dev-A';

  @override
  Future<String?> getSyncAccountId() async => 'acct';
}

void main() {
  test(
    'turning cloud backup off turns the active switch off (#3503)',
    () async {
      SharedPreferences.setMockInitialValues({
        'backup_cloud_enabled': true,
        'backup_retention_all_devices_account': 'acct',
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          backupServiceProvider.overrideWithValue(
            BackupService(
              dbAdapter: UnusedBackupDatabaseAdapter(),
              preferences: BackupPreferences(prefs),
              cloudProvider: FakeCloudStorageProvider(),
              syncRepository: _Device(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(
        crossDeviceRetentionActiveProvider,
        (_, _) {},
      );
      addTearDown(sub.close);
      expect(
        await container.read(crossDeviceRetentionActiveProvider.future),
        isTrue,
      );

      await container
          .read(backupSettingsProvider.notifier)
          .setCloudBackupEnabled(false);

      expect(
        await container.read(crossDeviceRetentionActiveProvider.future),
        isFalse,
      );
    },
  );
}
