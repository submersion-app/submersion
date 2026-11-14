// Issue #4535: Keep all, and Back up now's "Keep this backup", which records
// the new backup pinned and writes its cross-device pin marker (#3503).

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_attribution.dart';
import 'package:submersion/features/backup/data/services/backup_pin_markers.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/data/services/cross_device_retention.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/mock_channels.dart';

/// Writes a small file where the backup goes, so the service can size it.
class _Adapter implements BackupDatabaseAdapter {
  @override
  Future<void> backup(String destinationPath, {String? note}) async {
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
  AppDatabase get database => throw UnimplementedError('no queries here');

  @override
  String? get databaseKeyHex => null;
}

/// A device with an id and a sync account, so a cloud copy it makes is
/// "here" and its pin markers carry its tag.
class _PinningDevice extends SyncRepository {
  _PinningDevice(this.deviceId);

  final String deviceId;

  @override
  Future<String> getDeviceId() async => deviceId;

  @override
  Future<String?> getSyncAccountId() async => 'acct';
}

/// The shared fake, with a hook that runs as each file is uploaded.
class _WatchedFolder extends FakeCloudStorageProvider {
  void Function(String filename)? onUpload;

  @override
  Future<UploadResult> uploadFile(
    Uint8List data,
    String filename, {
    String? folderId,
  }) {
    onUpload?.call(filename);
    return super.uploadFile(data, filename, folderId: folderId);
  }
}

void main() {
  late Directory temp;
  late BackupPreferences preferences;
  late _WatchedFolder folder;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    temp = Directory.systemTemp.createTempSync('keep_backup_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => switch (call.method) {
            'getTemporaryDirectory' => p.join(temp.path, 'tmp'),
            'getApplicationDocumentsDirectory' => temp.path,
            _ => null,
          },
        );
  });

  tearDownAll(() {
    clearPathAndShareChannelMocks();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = BackupPreferences(await SharedPreferences.getInstance());
    folder = _WatchedFolder();
  });

  BackupService local() =>
      BackupService(dbAdapter: _Adapter(), preferences: preferences);

  BackupService device(String id) => BackupService(
    dbAdapter: _Adapter(),
    preferences: preferences,
    cloudProvider: folder,
    syncRepository: _PinningDevice(id),
  );

  test('keep all removes nothing', () async {
    for (var i = 0; i < 12; i++) {
      await preferences.addRecord(
        BackupRecord(
          id: 'r$i',
          filename: 'backup_$i.db',
          timestamp: DateTime(2025, 6, i + 1),
          sizeBytes: 1000,
          location: BackupLocation.local,
          diveCount: 5,
          siteCount: 2,
        ),
      );
    }

    await local().pruneOldBackups(BackupSettings.keepAllRetentionCount);

    expect(preferences.getHistory(), hasLength(12));
  });

  group('Keep this backup', () {
    test('a pinned backup is recorded pinned', () async {
      final record = await local().performBackup(pin: true);
      expect(record.pinned, isTrue);
      expect(preferences.getHistory().single.pinned, isTrue);
    });

    test('a backup is unpinned by default', () async {
      final record = await local().performBackup();
      expect(record.pinned, isFalse);
    });

    test('an automatic backup is never pinned', () async {
      final record = await local().performBackup(isAutomatic: true, pin: true);
      expect(record.pinned, isFalse);
    });

    test('a pinned backup outlives the prunes of later backups', () async {
      await preferences.setRetentionCount(1);
      final kept = await local().performBackup(pin: true);
      await local().performBackup(isAutomatic: true);
      await local().performBackup(isAutomatic: true);
      final ids = preferences.getHistory().map((r) => r.id);
      expect(ids, contains(kept.id));
      expect(ids, hasLength(2));
    });
  });

  group('Keep this backup with a cloud copy', () {
    setUp(() => preferences.setCloudBackupEnabled(true));

    test('writes this device\'s pin marker for this backup', () async {
      final record = await device('dev-A').performBackup(pin: true);
      expect(record.cloudFileId, isNotNull);
      final markers = [
        for (final f in await folder.listFiles()) ?parsePinMarker(f.name),
      ];
      expect(markers, hasLength(1));
      expect(markers.single.backupStem, backupStem(record.filename));
      expect(markers.single.deviceTag, deviceTag('dev-A'));
    });

    // The prune at the end of every backup also reconciles markers, but only
    // from a listing; the marker is written without one.
    test('writes the marker when the folder cannot be listed', () async {
      folder.failLists = true;
      final record = await device('dev-A').performBackup(pin: true);
      expect(record.cloudFileId, isNotNull);
      expect(
        folder.bytesOf(
          pinMarkerName(
            backupFilename: record.filename,
            pinningDeviceId: 'dev-A',
          ),
        ),
        isNotNull,
      );
    });

    // The marker is a network round trip: the backup's own bookkeeping is
    // written first, so a slow upload or an app kill cannot leave it stale.
    test('the backup is recorded as made before the marker uploads', () async {
      DateTime? lastBackupAtMarker;
      folder.onUpload = (name) {
        if (parsePinMarker(name) != null) {
          lastBackupAtMarker = preferences.getSettings().lastBackupTime;
        }
      };
      final record = await device('dev-A').performBackup(pin: true);
      // Stored to the millisecond.
      expect(
        lastBackupAtMarker?.millisecondsSinceEpoch,
        record.timestamp.millisecondsSinceEpoch,
      );
    });

    test('an unpinned backup writes no marker', () async {
      await device('dev-A').performBackup();
      final names = [for (final f in await folder.listFiles()) f.name];
      expect(names.where((n) => parsePinMarker(n) != null), isEmpty);
    });

    test('another device pruning across devices keeps it', () async {
      await preferences.setRetentionCount(1);
      final kept = await device('dev-A').performBackup(pin: true);
      await device('dev-A').performBackup(isAutomatic: true);
      await device('dev-A').performBackup(isAutomatic: true);

      // Device B has no record of the pin; only the marker tells it.
      final plan = planCrossDeviceRetention(
        listing: await folder.listFiles(),
        keepCount: 1,
        locallyPinnedStems: const {},
        locallyPinnedFileIds: const {},
        thisDeviceId: 'dev-B',
        now: DateTime.now(),
      );
      expect(
        plan.toDelete.map((c) => c.file.id),
        isNot(contains(kept.cloudFileId)),
      );
    });
  });
}
