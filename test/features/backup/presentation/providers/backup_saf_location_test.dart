import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';

void main() {
  late BackupSettingsNotifier notifier;
  late BackupPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = BackupPreferences(await SharedPreferences.getInstance());
    notifier = BackupSettingsNotifier(prefs);
  });

  test(
    'setSafBackupLocation persists uri + label and disables cloud backup',
    () async {
      await notifier.setCloudBackupEnabled(true);
      await notifier.setSafBackupLocation('content://tree/1', 'Backups');

      expect(notifier.state.backupLocation, 'content://tree/1');
      expect(notifier.locationLabel, 'Backups');
      expect(notifier.state.cloudBackupEnabled, isFalse);
      expect(prefs.backupLocationLabel, 'Backups');
    },
  );

  test('locationLabel is null when no custom location is set', () {
    expect(notifier.locationLabel, isNull);
  });

  test('resetting the location to default clears the label', () async {
    await notifier.setSafBackupLocation('content://tree/1', 'Backups');
    await notifier.setBackupLocation(null);

    expect(notifier.locationLabel, isNull);
    expect(notifier.state.backupLocation, isNull);
  });
}
