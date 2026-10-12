import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_attribution.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/data/services/cloud_backup_history.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/unused_backup_database_adapter.dart';

const _cloudName = 'submersion_backup_2026-03-14_093015.db';

void main() {
  late BackupPreferences preferences;
  late FakeCloudStorageProvider cloud;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = BackupPreferences(await SharedPreferences.getInstance());
    cloud = FakeCloudStorageProvider()
      ..seedFile(_cloudName, Uint8List.fromList(List.filled(64, 1)));
  });

  BackupService service() => BackupService(
    dbAdapter: UnusedBackupDatabaseAdapter(),
    preferences: preferences,
    cloudProvider: cloud,
  );

  group('getCloudBackups', () {
    test('lists the backups in the cloud folder', () async {
      final files = await service().getCloudBackups();
      expect(files.map((f) => f.name), [_cloudName]);
    });

    test('does not touch a provider that is signed out', () async {
      // A fresh install with a provider selected but not reconnected must not
      // turn opening the backup page into a failed request (issue #3214).
      cloud.authenticated = false;
      final files = await service().getCloudBackups();
      expect(files, isEmpty);
      expect(cloud.operationLog, isNot(contains('list')));
    });

    test('a failed listing is an empty list, not an error', () async {
      cloud.failLists = true;
      expect(await service().getCloudBackups(), isEmpty);
    });
  });

  group('pinRecord', () {
    test('pinning a cloud backup with no record adopts it as pinned', () async {
      final files = await service().getCloudBackups();
      final discovered = backupRecordFromCloudFile(files.single)!;

      await service().pinRecord(discovered);

      final stored = preferences.getHistory().single;
      expect(stored.id, discovered.id);
      expect(stored.cloudFileId, _cloudName);
      expect(stored.pinned, isTrue);
    });

    test('adopting two rows at once keeps both', () async {
      // The history write is read-modify-write, but SharedPreferences updates
      // its cache synchronously inside setString, so with no await between
      // the read and the write two adoptions cannot lose one another.
      cloud.seedFile(
        'submersion_backup_2026-03-15_093015.db',
        Uint8List.fromList(List.filled(64, 2)),
      );
      final rows = [
        for (final f in await service().getCloudBackups())
          backupRecordFromCloudFile(f)!,
      ];
      expect(rows, hasLength(2));

      await Future.wait([for (final r in rows) service().pinRecord(r)]);

      expect(
        preferences.getHistory().map((r) => r.id).toSet(),
        rows.map((r) => r.id).toSet(),
      );
    });

    test('a row whose cloud file is gone is not adopted', () async {
      // Another device deleted it after the page listed it; adopting it would
      // leave a pinned record that can never be restored or pruned.
      final files = await service().getCloudBackups();
      final stale = backupRecordFromCloudFile(files.single)!;
      await cloud.deleteFile(_cloudName);

      await service().pinRecord(stale);

      expect(preferences.getHistory(), isEmpty);
    });

    test('pinning a tracked record pins it in place', () async {
      final tracked = BackupRecord(
        id: 'tracked',
        filename: 'a.db',
        timestamp: DateTime(2026, 2, 1),
        sizeBytes: 10,
        location: BackupLocation.local,
        localPath: '/backups/a.db',
      );
      await preferences.addRecord(tracked);

      await service().pinRecord(tracked);

      final stored = preferences.getHistory();
      expect(stored, hasLength(1));
      expect(stored.single.pinned, isTrue);
    });

    test('an unknown record with no cloud copy is not resurrected', () async {
      // A local record that has since been pruned must not come back just
      // because a stale tile was tapped.
      final gone = BackupRecord(
        id: 'gone',
        filename: 'gone.db',
        timestamp: DateTime(2026, 2, 1),
        sizeBytes: 10,
        location: BackupLocation.local,
        localPath: '/backups/gone.db',
      );

      await service().pinRecord(gone);

      expect(preferences.getHistory(), isEmpty);
    });
  });

  group('deleteBackup on a cloud-only row', () {
    test('deletes the cloud file', () async {
      final files = await service().getCloudBackups();
      await service().deleteBackup(backupRecordFromCloudFile(files.single)!);
      expect(await cloud.fileExists(_cloudName), isFalse);
    });

    test('a failed cloud delete is reported, not swallowed', () async {
      // The cloud file is all there is: removing the (absent) record and
      // reporting success would leave the row to reappear on the next visit.
      final files = await service().getCloudBackups();
      cloud.failDeletes = true;
      await expectLater(
        service().deleteBackup(backupRecordFromCloudFile(files.single)!),
        throwsA(isA<CloudStorageException>()),
      );
    });
  });

  group('mayBeAnotherDevicesCopy', () {
    const thisDevice = 'this-device';

    BackupService withDevice(String deviceId) => BackupService(
      dbAdapter: UnusedBackupDatabaseAdapter(),
      preferences: preferences,
      cloudProvider: cloud,
      syncRepository: _FixedDeviceIdSyncRepository(deviceId),
    );

    BackupRecord cloudOnly(String filename) => BackupRecord(
      id: 'cloud:$filename',
      filename: filename,
      timestamp: DateTime(2026, 3, 14),
      sizeBytes: 10,
      location: BackupLocation.cloud,
      cloudFileId: filename,
    );

    test('a cloud-only backup another device wrote may be its copy', () async {
      final name = buildBackupFilename(
        timestamp: '2026-03-14_093015',
        deviceId: 'old-install',
      );
      expect(
        await withDevice(thisDevice).mayBeAnotherDevicesCopy(cloudOnly(name)),
        isTrue,
      );
    });

    test('an unattributed cloud-only backup may be another copy', () async {
      expect(
        await withDevice(
          thisDevice,
        ).mayBeAnotherDevicesCopy(cloudOnly(_cloudName)),
        isTrue,
      );
    });

    test('a cloud-only backup this device wrote is not', () async {
      final name = buildBackupFilename(
        timestamp: '2026-03-14_093015',
        deviceId: thisDevice,
      );
      expect(
        await withDevice(thisDevice).mayBeAnotherDevicesCopy(cloudOnly(name)),
        isFalse,
      );
    });

    test('a backup with a local copy is this device\'s own', () async {
      final record = BackupRecord(
        id: 'local',
        filename: _cloudName,
        timestamp: DateTime(2026, 3, 14),
        sizeBytes: 10,
        location: BackupLocation.both,
        localPath: '/backups/$_cloudName',
        cloudFileId: 'x',
      );
      expect(
        await withDevice(thisDevice).mayBeAnotherDevicesCopy(record),
        isFalse,
      );
    });

    test('an unreadable device id errs on the side of warning', () async {
      final name = buildBackupFilename(
        timestamp: '2026-03-14_093015',
        deviceId: thisDevice,
      );
      final service = BackupService(
        dbAdapter: UnusedBackupDatabaseAdapter(),
        preferences: preferences,
        cloudProvider: cloud,
        syncRepository: _ThrowingDeviceIdSyncRepository(),
      );
      expect(await service.mayBeAnotherDevicesCopy(cloudOnly(name)), isTrue);
    });
  });
}

class _FixedDeviceIdSyncRepository extends SyncRepository {
  _FixedDeviceIdSyncRepository(this.deviceId);

  final String deviceId;

  @override
  Future<String> getDeviceId() async => deviceId;
}

class _ThrowingDeviceIdSyncRepository extends SyncRepository {
  @override
  Future<String> getDeviceId() async => throw StateError('no database');
}
