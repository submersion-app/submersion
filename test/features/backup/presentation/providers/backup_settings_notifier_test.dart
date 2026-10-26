import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
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

  group('Settings > Data health state', () {
    test('recordScheduledFailure persists and shows the failure', () async {
      await notifier.recordScheduledFailure('disk full');

      expect(notifier.state.lastScheduledFailureAt, isNotNull);
      expect(notifier.state.lastScheduledFailureMessage, 'disk full');
      expect(prefs.getSettings().lastScheduledFailureMessage, 'disk full');
    });

    test('reloadFromDisk picks up a write made outside the notifier', () async {
      // The WorkManager isolate writes through its own BackupPreferences.
      await prefs.setLastScheduledFailure(DateTime(2026, 10, 17), 'offline');
      expect(notifier.state.lastScheduledFailureAt, isNull);

      await notifier.reloadFromDisk();

      expect(notifier.state.lastScheduledFailureMessage, 'offline');
    });
  });

  test(
    'setCrossDeviceRetentionAccount persists and shows the switch',
    () async {
      await notifier.setCrossDeviceRetentionAccount('acct');
      expect(notifier.state.crossDeviceRetentionFor('acct'), isTrue);
      expect(prefs.getSettings().crossDeviceRetentionFor('acct'), isTrue);

      await notifier.setCrossDeviceRetentionAccount(null);
      expect(notifier.state.crossDeviceRetentionAccount, isNull);
    },
  );

  group('the backup folder and the cloud copy are independent', () {
    test('cloud backup starts disabled', () {
      expect(notifier.state.cloudBackupEnabled, isFalse);
    });

    test('turning the copy on keeps the chosen folder', () async {
      await notifier.setBackupLocation('/custom/path');
      await notifier.setCloudBackupEnabled(true);

      expect(notifier.state.cloudBackupEnabled, isTrue);
      expect(notifier.state.backupLocation, '/custom/path');
      expect(prefs.getSettings().backupLocation, '/custom/path');
    });

    test('choosing a folder keeps the cloud copy on', () async {
      await notifier.setCloudBackupEnabled(true);
      await notifier.setBackupLocation('/custom/path');

      expect(notifier.state.cloudBackupEnabled, isTrue);
      expect(prefs.getSettings().cloudBackupEnabled, isTrue);
    });

    test('a bookmarked folder keeps the cloud copy on', () async {
      await notifier.setCloudBackupEnabled(true);
      await notifier.setBackupLocationWithBookmark('/icloud/dir', [9]);

      expect(notifier.state.cloudBackupEnabled, isTrue);
      expect(notifier.state.backupLocation, '/icloud/dir');
    });

    test('a SAF folder keeps the cloud copy on', () async {
      await notifier.setCloudBackupEnabled(true);
      await notifier.setSafBackupLocation('content://tree/1', 'Backups');

      expect(notifier.state.cloudBackupEnabled, isTrue);
      expect(notifier.state.backupLocation, 'content://tree/1');
    });

    test('turning the copy off and on again keeps the folder', () async {
      await notifier.setBackupLocation('/custom/path');
      await notifier.setNoCopy();
      await notifier.setCopyFollowsSync();

      expect(notifier.state.cloudBackupEnabled, isTrue);
      expect(notifier.state.backupLocation, '/custom/path');
    });

    test(
      'useDefaultBackupLocation clears the folder, bookmark and label',
      () async {
        await notifier.setCloudBackupEnabled(true);
        await notifier.setBackupLocationWithBookmark('/icloud/dir', [1, 2]);
        await prefs.setBackupLocationLabel('Backups');

        await notifier.useDefaultBackupLocation();

        expect(notifier.state.backupLocation, isNull);
        expect(prefs.getBackupLocationBookmark(), isNull);
        expect(prefs.backupLocationLabel, isNull);
        expect(notifier.state.cloudBackupEnabled, isTrue);
      },
    );
  });

  group('setBackupLocationWithBookmark', () {
    test('persists both the path and the security-scoped bookmark', () async {
      await notifier.setBackupLocationWithBookmark('/icloud/dir', [1, 2, 3]);

      expect(notifier.state.backupLocation, '/icloud/dir');
      expect(prefs.getSettings().backupLocation, '/icloud/dir');
      expect(prefs.getBackupLocationBookmark(), [1, 2, 3]);
    });

    test('accepts a null bookmark (desktop bare-path case)', () async {
      await notifier.setBackupLocationWithBookmark('/desktop/dir', null);

      expect(prefs.getSettings().backupLocation, '/desktop/dir');
      expect(prefs.getBackupLocationBookmark(), isNull);
    });
  });

  group('copy destination', () {
    test('starts as the same account as sync', () {
      expect(notifier.state.copyAccountId, isNull);
      expect(notifier.state.copyAccountKind, isNull);
    });

    test('setCopyTo stores the row and turns the copy on', () async {
      await notifier.setCopyTo(_row('acct-b', AccountKind.s3));

      expect(notifier.state.cloudBackupEnabled, isTrue);
      final read = prefs.getSettings();
      expect(read.copyAccountId, 'acct-b');
      expect(read.copyAccountKind, AccountKind.s3);
      expect(read.cloudBackupEnabled, isTrue);
    });

    test('setCopyFollowsSync clears the row and keeps the copy on', () async {
      await notifier.setCopyTo(_row('acct-b', AccountKind.dropbox));

      await notifier.setCopyFollowsSync();

      final read = prefs.getSettings();
      expect(read.copyAccountId, isNull);
      expect(read.copyAccountKind, isNull);
      expect(read.cloudBackupEnabled, isTrue);
    });

    test('setNoCopy turns the copy off and clears the row', () async {
      await notifier.setCopyTo(_row('acct-b', AccountKind.dropbox));

      await notifier.setNoCopy();

      final read = prefs.getSettings();
      expect(read.cloudBackupEnabled, isFalse);
      expect(read.copyAccountId, isNull);
      expect(notifier.state.copyAccountId, isNull);
    });

    test('pinCopyTo stores the row without turning the copy on', () async {
      await notifier.pinCopyTo(_row('acct-c', AccountKind.icloud));

      final read = prefs.getSettings();
      expect(read.copyAccountId, 'acct-c');
      expect(read.copyAccountKind, AccountKind.icloud);
      expect(read.cloudBackupEnabled, isFalse);
    });
  });
}

ConnectedAccount _row(String id, AccountKind kind) => ConnectedAccount(
  id: id,
  kind: kind,
  label: id,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
