// Issue #4572: scheduled (background) backups on Android never pruned. The
// prune listed the cloud folder before it deleted anything, so a cloud call
// that stalled in the WorkManager isolate, or a worker the OS stopped while
// it waited, left every old backup on the device. This device's own copies
// now go before any cloud call, and the listing gives up after a time limit.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/data/services/extra_copy_destination.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/extra_cloud_copy.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/unused_backup_database_adapter.dart';

class _Device extends SyncRepository {
  @override
  Future<String> getDeviceId() async => 'dev-A';

  @override
  Future<String?> getSyncAccountId() async => 'acct';
}

/// Notes which local files were still on disk when the folder was listed,
/// then lists normally.
class _WatchingCloud extends FakeCloudStorageProvider {
  List<String> watched = const [];
  List<String>? presentAtListing;

  @override
  Future<List<CloudFileInfo>> listFiles({
    String? folderId,
    String? namePattern,
  }) {
    presentAtListing ??= [
      for (final path in watched)
        if (File(path).existsSync()) path,
    ];
    return super.listFiles(folderId: folderId, namePattern: namePattern);
  }
}

/// Signed in, but never answers the sign-in check: the silent sign-in a
/// headless isolate cannot finish.
class _StalledSignInCloud extends FakeCloudStorageProvider {
  @override
  Future<bool> isAuthenticated() => Completer<bool>().future;
}

void main() {
  late BackupPreferences preferences;
  late Directory dir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = BackupPreferences(await SharedPreferences.getInstance());
    dir = await Directory.systemTemp.createTemp('prune_local_first_');
    addTearDown(() => dir.delete(recursive: true));
  });

  BackupService service(
    CloudStorageProvider cloud, {
    Duration cloudListingTimeout = const Duration(minutes: 5),
  }) => BackupService(
    dbAdapter: UnusedBackupDatabaseAdapter(),
    preferences: preferences,
    cloudProvider: cloud,
    syncRepository: _Device(),
    copyAccountId: 'acct',
    cloudListingTimeout: cloudListingTimeout,
  );

  /// Seeds an automatic backup [daysAgo] old with a local file, and a cloud
  /// copy in [cloud] when [inCloud].
  Future<BackupRecord> seed(
    int daysAgo, {
    FakeCloudStorageProvider? cloud,
    bool inCloud = true,
  }) async {
    final name = 'submersion_backup_d$daysAgo.db';
    final local = p.join(dir.path, name);
    await File(local).writeAsString('backup $daysAgo');
    if (inCloud) cloud!.seedFile(name, Uint8List.fromList([1, 2, 3]));
    final record = BackupRecord(
      id: 'r$daysAgo',
      filename: name,
      timestamp: DateTime.now().subtract(Duration(days: daysAgo)),
      sizeBytes: 3,
      location: inCloud ? BackupLocation.both : BackupLocation.local,
      diveCount: 1,
      siteCount: 1,
      cloudFileId: inCloud ? name : null,
      cloudAccountId: inCloud ? 'acct' : null,
      localPath: local,
      isAutomatic: true,
    );
    await preferences.addRecord(record);
    return record;
  }

  test('local copies are gone before the cloud folder is listed', () async {
    final cloud = _WatchingCloud();
    final records = [for (var d = 1; d <= 4; d++) await seed(d, cloud: cloud)];
    cloud.watched = [for (final r in records) r.localPath!];

    await service(cloud).pruneOldBackups(2);

    expect(
      cloud.presentAtListing,
      [records[0].localPath, records[1].localPath],
      reason:
          'the two pruned backups lost their local copy before the listing; '
          'the two kept ones were untouched',
    );
    expect(preferences.getHistory().map((r) => r.id), ['r2', 'r1']);
    expect(cloud.fileCount, 2);
  });

  test(
    'a stalled sign-in check still prunes this device: local copies go, '
    'local-only backups go, and the cloud copies wait for the next prune',
    () async {
      final cloud = _StalledSignInCloud();
      final kept = [await seed(1, cloud: cloud), await seed(2, cloud: cloud)];
      final cloudBacked = await seed(3, cloud: cloud);
      final localOnly = await seed(4, inCloud: false);

      await service(
        cloud,
        cloudListingTimeout: const Duration(milliseconds: 20),
      ).pruneOldBackups(2);

      for (final r in kept) {
        expect(File(r.localPath!).existsSync(), isTrue);
      }
      expect(File(cloudBacked.localPath!).existsSync(), isFalse);
      expect(File(localOnly.localPath!).existsSync(), isFalse);

      final history = preferences.getHistory();
      expect(history.map((r) => r.id), containsAll(['r1', 'r2', 'r3']));
      expect(
        history.map((r) => r.id),
        isNot(contains('r4')),
        reason: 'a local-only backup has nothing in the cloud to wait for',
      );
      final held = history.singleWhere((r) => r.id == 'r3');
      expect(held.localPath, isNull);
      expect(held.location, BackupLocation.cloud);
      expect(
        cloud.fileCount,
        3,
        reason: 'without a listing no cloud copy goes this round',
      );
    },
  );

  test('a listing that never answers gives up after the time limit', () async {
    final cloud = FakeCloudStorageProvider();
    await seed(1, cloud: cloud);
    final old = await seed(2, cloud: cloud);
    cloud.hangOperations = true;

    await service(
      cloud,
      cloudListingTimeout: const Duration(milliseconds: 20),
    ).pruneOldBackups(1);

    expect(File(old.localPath!).existsSync(), isFalse);
    expect(
      preferences.getHistory().singleWhere((r) => r.id == 'r2').location,
      BackupLocation.cloud,
    );
  });

  test('a backup whose only other copy is an extra copy loses its local '
      'copy, its extra copy and its record', () async {
    final extra = FakeCloudStorageProvider();
    await seed(1, inCloud: false);
    const name = 'submersion_backup_extra.db';
    final local = p.join(dir.path, name);
    await File(local).writeAsString('backup extra');
    extra.seedFile(name, Uint8List.fromList([1, 2, 3]));
    await preferences.addRecord(
      BackupRecord(
        id: 'extra',
        filename: name,
        timestamp: DateTime.now().subtract(const Duration(days: 5)),
        sizeBytes: 3,
        location: BackupLocation.local,
        diveCount: 1,
        siteCount: 1,
        localPath: local,
        isAutomatic: true,
        extraCloudCopies: const [
          ExtraCloudCopy(accountId: 'extra-row', fileId: name),
        ],
      ),
    );

    await BackupService(
      dbAdapter: UnusedBackupDatabaseAdapter(),
      preferences: preferences,
      syncRepository: _Device(),
      extraCopies: [ExtraCopyDestination('extra-row', extra)],
    ).pruneOldBackups(1);

    expect(File(local).existsSync(), isFalse);
    expect(extra.fileCount, 0);
    expect(preferences.getHistory().map((r) => r.id), ['r1']);
  });

  test('a file a kept backup still uses stays, though the backup made in '
      'the same second is pruned', () async {
    final cloud = FakeCloudStorageProvider();
    final kept = await seed(1, cloud: cloud);
    // A second backup in the same second: same filename, same local path.
    await preferences.addRecord(
      BackupRecord(
        id: 'twin',
        filename: kept.filename,
        timestamp: kept.timestamp.subtract(const Duration(milliseconds: 1)),
        sizeBytes: 3,
        location: BackupLocation.local,
        diveCount: 1,
        siteCount: 1,
        localPath: kept.localPath,
        isAutomatic: true,
      ),
    );

    await service(cloud).pruneOldBackups(1);

    expect(File(kept.localPath!).existsSync(), isTrue);
    expect(preferences.getHistory().map((r) => r.id), ['r1']);
  });

  test('two pruned backups that share a file both let it go', () async {
    final cloud = FakeCloudStorageProvider();
    await seed(1, cloud: cloud);
    final old = await seed(2, cloud: cloud);
    await preferences.addRecord(
      old.copyWith(
        id: 'twin',
        timestamp: old.timestamp.subtract(const Duration(milliseconds: 1)),
      ),
    );

    await service(cloud).pruneOldBackups(1);

    expect(File(old.localPath!).existsSync(), isFalse);
    expect(preferences.getHistory().map((r) => r.id), ['r1']);
  });
}
