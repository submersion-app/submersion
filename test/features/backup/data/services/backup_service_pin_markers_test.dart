// Issue #3503: a pin made on one device is mirrored into the shared cloud
// folder as a per-device marker, so other devices' retention can see it.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_pin_markers.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/data/services/cloud_backup_history.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/unused_backup_database_adapter.dart';

const _stem = 'submersion_backup_2026-10-01_090000__d0123456789abcdef';

class _Device extends SyncRepository {
  _Device(this.deviceId);

  final String deviceId;

  @override
  Future<String> getDeviceId() async => deviceId;

  @override
  Future<String?> getSyncAccountId() async => 'acct';
}

String _marker(String device, {String name = '$_stem.db'}) =>
    pinMarkerName(backupFilename: name, pinningDeviceId: device);

void main() {
  late BackupPreferences preferences;
  late FakeCloudStorageProvider cloud;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = BackupPreferences(await SharedPreferences.getInstance());
    cloud = FakeCloudStorageProvider();
  });

  BackupService service({String deviceId = 'dev-A'}) => BackupService(
    dbAdapter: UnusedBackupDatabaseAdapter(),
    preferences: preferences,
    cloudProvider: cloud,
    syncRepository: _Device(deviceId),
  );

  /// A history record whose cloud copy is [cloudName] in the fake folder.
  Future<BackupRecord> tracked({
    String cloudName = '$_stem.db',
    bool pinned = false,
  }) async {
    cloud.seedFile(cloudName, Uint8List.fromList([1, 2, 3]));
    final record = BackupRecord(
      id: 'r1',
      filename: '$_stem.db',
      timestamp: DateTime(2026, 10, 1, 9),
      sizeBytes: 3,
      location: BackupLocation.both,
      cloudFileId: cloudName,
      cloudAccountId: 'acct',
      localPath: '/backups/$_stem.db',
      pinned: pinned,
    );
    await preferences.addRecord(record);
    return record;
  }

  bool has(String name) => cloud.bytesOf(name) != null;

  test(
    'pinning a backup with a cloud copy writes this device\'s marker',
    () async {
      final record = await tracked();
      await service().pinBackup(record.id);
      expect(has(_marker('dev-A')), isTrue);
    },
  );

  test('unpinning deletes only this device\'s marker', () async {
    final record = await tracked();
    cloud.seedFile(_marker('dev-B'), Uint8List(0));
    await service().pinBackup(record.id);
    await service().unpinBackup(record.id);
    expect(has(_marker('dev-A')), isFalse);
    expect(has(_marker('dev-B')), isTrue);
  });

  test('a marker that cannot be written does not fail the pin', () async {
    final record = await tracked();
    cloud.failUploads = true;
    await service().pinBackup(record.id);
    expect(preferences.getHistory().single.pinned, isTrue);
  });

  test('no device id: no marker is written and the pin still holds', () async {
    final record = await tracked();
    await service(deviceId: '').pinBackup(record.id);
    expect(preferences.getHistory().single.pinned, isTrue);
    expect(cloud.operationLog.where((o) => o.startsWith('upload:')), isEmpty);
  });

  test('an .sbe cloud copy of an X.db record gets the X marker', () async {
    final record = await tracked(cloudName: '$_stem.sbe');
    await service().pinBackup(record.id);
    expect(has(_marker('dev-A', name: '$_stem.sbe')), isTrue);
    expect(_marker('dev-A', name: '$_stem.sbe'), _marker('dev-A'));
  });

  test('adopting a discovered cloud row writes the marker too', () async {
    cloud.seedFile('$_stem.db', Uint8List.fromList([1]));
    final s = service();
    final row = backupRecordFromCloudFile((await s.getCloudBackups()).single)!;
    await s.pinRecord(row);
    expect(has(_marker('dev-A')), isTrue);
  });

  group('reconcilePinMarkers', () {
    test('writes markers for pins made before this version', () async {
      await tracked(pinned: true);
      await service().reconcilePinMarkers();
      expect(has(_marker('dev-A')), isTrue);
    });

    test(
      'removes this device\'s markers for backups it no longer pins',
      () async {
        await tracked();
        cloud.seedFile(_marker('dev-A'), Uint8List(0));
        await service().reconcilePinMarkers();
        expect(has(_marker('dev-A')), isFalse);
      },
    );

    test('leaves other devices\' markers alone', () async {
      await tracked();
      cloud.seedFile(_marker('dev-B'), Uint8List(0));
      await service().reconcilePinMarkers();
      expect(has(_marker('dev-B')), isTrue);
    });

    test('a pin whose cloud copy is gone gets no marker', () async {
      await tracked(pinned: true);
      await cloud.deleteFile('$_stem.db');
      await service().reconcilePinMarkers();
      expect(has(_marker('dev-A')), isFalse);
    });

    test('a failed listing changes nothing', () async {
      await tracked(pinned: true);
      cloud.failLists = true;
      await service().reconcilePinMarkers();
      expect(has(_marker('dev-A')), isFalse);
    });
  });
}
