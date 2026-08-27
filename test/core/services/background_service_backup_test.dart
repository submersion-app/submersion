import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/background_service.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';

import '../../support/fake_cloud_storage_provider.dart';

/// Writes a stand-in backup file so the service has real bytes to upload.
class _FakeBackupDatabaseAdapter implements BackupDatabaseAdapter {
  @override
  Future<void> backup(String destinationPath) async {
    final file = File(destinationPath);
    await file.parent.create(recursive: true);
    await file.writeAsString('fake backup data');
  }

  @override
  Future<void> restore(
    String backupPath, {
    void Function(int, int)? onMigrationProgress,
  }) async {}

  @override
  Future<String> get databasePath async => '/fake/db/path';

  @override
  AppDatabase get database =>
      throw UnimplementedError('Fake database does not support queries');

  @override
  String? get databaseKeyHex => null;
}

/// An adapter whose backup always fails, modelling a full disk or an
/// unreadable database.
class _FailingBackupDatabaseAdapter extends _FakeBackupDatabaseAdapter {
  @override
  Future<void> backup(String destinationPath) async =>
      throw const FileSystemException('no space left on device');
}

/// A connected provider whose uploads fail: offline, expired token, or a
/// revoked scope. The local artifact still lands, so the backup "succeeds".
class _UploadFailingCloud extends FakeCloudStorageProvider {
  _UploadFailingCloud() : super(providerId: 'dropbox');

  @override
  Future<UploadResult> uploadFileFromPath(
    String sourcePath,
    String filename, {
    String? folderId,
  }) async => throw const CloudStorageException('network unreachable');
}

/// One recorded call to the notification seam.
typedef _Notification = ({bool success, String? error, bool cloudCopyMissing});

/// Per-file temp root, so the backup service's fixed `Submersion/Backups`
/// subtree does not collide with the other suites that mock path_provider the
/// same way. `flutter test` runs files in parallel isolates against one real
/// $TMPDIR, so sharing it let one suite truncate or encrypt another's artifact
/// mid-assert.
final _isolatedTempDir = Directory.systemTemp.createTempSync(
  'bg_svc_backup_test_',
);

void main() {
  tearDownAll(() {
    if (_isolatedTempDir.existsSync()) {
      _isolatedTempDir.deleteSync(recursive: true);
    }
  });
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getTemporaryDirectory' ||
                methodCall.method == 'getApplicationDocumentsDirectory') {
              return _isolatedTempDir.path;
            }
            return null;
          },
        );
  });

  const log = LoggerService('BackgroundServiceTest');
  late FakeCloudStorageProvider cloud;
  late List<_Notification> notifications;

  setUp(() {
    cloud = FakeCloudStorageProvider(providerId: 'dropbox');
    notifications = [];
  });

  Future<void> record({
    required bool success,
    String? error,
    bool cloudCopyMissing = false,
  }) async {
    notifications.add((
      success: success,
      error: error,
      cloudCopyMissing: cloudCopyMissing,
    ));
  }

  /// Seeds an enabled, due backup configuration. `lastBackupTime` is left
  /// unset, which BackupSettings.isBackupDue treats as due.
  Future<SharedPreferences> seedPrefs({
    bool enabled = true,
    bool cloudBackupEnabled = true,
    String? lastProvider = 'dropbox',
    DateTime? lastBackupTime,
  }) async {
    SharedPreferences.setMockInitialValues(
      lastProvider == null ? {} : {'sync_last_provider': lastProvider},
    );
    final prefs = await SharedPreferences.getInstance();
    final preferences = BackupPreferences(prefs);
    await preferences.setEnabled(enabled);
    await preferences.setCloudBackupEnabled(cloudBackupEnabled);
    if (lastBackupTime != null) {
      await preferences.setLastBackupTime(lastBackupTime);
    }
    return prefs;
  }

  // The support fake's createFolder returns the folder name as its id.
  Future<List<CloudFileInfo>> uploadedBackups() => cloud.listFiles(
    folderId: 'Submersion Backups',
    namePattern: 'submersion_backup_',
  );

  Future<void> run(
    SharedPreferences prefs, {
    BackupDatabaseAdapter? dbAdapter,
  }) => runScheduledBackup(
    prefs: prefs,
    dbAdapter: dbAdapter ?? _FakeBackupDatabaseAdapter(),
    log: log,
    notify: record,
    instanceFor: (CloudProviderType type) => cloud,
  );

  group('when a backup runs', () {
    test(
      'it uploads to the cloud when the user turned cloud backup on',
      () async {
        final prefs = await seedPrefs();

        await run(prefs);

        expect(
          await uploadedBackups(),
          hasLength(1),
          reason:
              'issue #969: the background isolate built a BackupService with no '
              'cloud provider, so automatic backups never left the device',
        );
        final history = BackupPreferences(prefs).getHistory();
        expect(history.single.location, BackupLocation.both);
        expect(history.single.isAutomatic, isTrue);
        expect(notifications.single.success, isTrue);
        expect(notifications.single.cloudCopyMissing, isFalse);
      },
    );

    test('it stays local when the user has not enabled cloud backup', () async {
      final prefs = await seedPrefs(cloudBackupEnabled: false);

      await run(prefs);

      expect(await uploadedBackups(), isEmpty);
      expect(
        BackupPreferences(prefs).getHistory().single.location,
        BackupLocation.local,
      );
      expect(
        notifications.single.cloudCopyMissing,
        isFalse,
        reason: 'no cloud copy was ever asked for, so none is missing',
      );
    });

    test('it stays local when no cloud provider is connected', () async {
      final prefs = await seedPrefs(lastProvider: null);

      await run(prefs);

      expect(await uploadedBackups(), isEmpty);
      expect(
        BackupPreferences(prefs).getHistory().single.location,
        BackupLocation.local,
      );
    });
  });

  group('what the user is told', () {
    test('a cloud copy the user asked for but did not get is reported, not '
        'hidden behind a plain success', () async {
      cloud = _UploadFailingCloud();
      final prefs = await seedPrefs();

      await run(prefs);

      expect(await uploadedBackups(), isEmpty);
      expect(notifications.single.success, isTrue);
      expect(
        notifications.single.cloudCopyMissing,
        isTrue,
        reason:
            'the local backup succeeded, but claiming plain success would tell '
            'the user their off-device copy is safe when it is not',
      );
    });

    test('a failed backup reports the reason', () async {
      final prefs = await seedPrefs();

      await run(prefs, dbAdapter: _FailingBackupDatabaseAdapter());

      expect(notifications.single.success, isFalse);
      expect(notifications.single.error, contains('no space left on device'));
      expect(BackupPreferences(prefs).getHistory(), isEmpty);
    });
  });

  group('when no backup should run', () {
    test('automatic backups switched off: nothing happens at all', () async {
      final prefs = await seedPrefs(enabled: false);

      await run(prefs);

      expect(await uploadedBackups(), isEmpty);
      expect(BackupPreferences(prefs).getHistory(), isEmpty);
      expect(
        notifications,
        isEmpty,
        reason: 'a skipped run must not notify -- there is nothing to report',
      );
    });

    test('not yet due: the previous backup still stands', () async {
      final prefs = await seedPrefs(
        lastBackupTime: DateTime.now().subtract(const Duration(hours: 2)),
      );

      await run(prefs);

      expect(await uploadedBackups(), isEmpty);
      expect(BackupPreferences(prefs).getHistory(), isEmpty);
      expect(notifications, isEmpty);
    });

    test('due again once the frequency window has passed', () async {
      final prefs = await seedPrefs(
        lastBackupTime: DateTime.now().subtract(const Duration(days: 8)),
      );

      await run(prefs);

      expect(await uploadedBackups(), hasLength(1));
    });
  });

  test('with no notifier injected it falls back to the real notification '
      'service, which production relies on', () async {
    final prefs = await seedPrefs();

    // No `notify:` -- the default tear-off runs. On a desktop test host
    // showBackupNotification returns before touching the platform channel,
    // so this exercises the production wiring without mocking the plugin.
    await runScheduledBackup(
      prefs: prefs,
      dbAdapter: _FakeBackupDatabaseAdapter(),
      log: log,
      instanceFor: (CloudProviderType type) => cloud,
    );

    expect(await uploadedBackups(), hasLength(1));
    expect(notifications, isEmpty, reason: 'the fake was not wired in');
  });

  group('buildScheduledBackupService', () {
    test('injects the resolved cloud provider so the shared upload gate can '
        'see it', () async {
      final prefs = await seedPrefs();

      final service = await buildScheduledBackupService(
        prefs: prefs,
        dbAdapter: _FakeBackupDatabaseAdapter(),
        instanceFor: (CloudProviderType type) => cloud,
      );
      final backup = await service.performBackup(isAutomatic: true);

      expect(backup.location, BackupLocation.both);
      expect(backup.cloudFileId, isNotNull);
    });
  });
}
