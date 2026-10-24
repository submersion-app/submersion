// Issue #3503: with the switch on, the "Keep" number is a ceiling on the
// whole shared cloud folder, counting every device's backups.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/cloud_storage/deferred_write_provider.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_attribution.dart';
import 'package:submersion/features/backup/data/services/backup_pin_markers.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/unused_backup_database_adapter.dart';

class _Device extends SyncRepository {
  _Device(this.deviceId, {this.account = 'acct'});

  final String deviceId;
  final String? account;
  var deviceIdReads = 0;

  @override
  Future<String> getDeviceId() async {
    deviceIdReads++;
    return deviceId;
  }

  @override
  Future<String?> getSyncAccountId() async => account;
}

final _stamp = DateFormat('yyyy-MM-dd_HHmmss');

/// A backend that defers writes (as Git does) and whose push fails.
class _FailingPushCloud extends FakeCloudStorageProvider
    implements DeferredWriteProvider {
  @override
  Future<void> flush({Duration? timeout}) async =>
      throw StateError('push failed (test)');
}

/// Answers "not there" whenever it cannot tell, as Google Drive's
/// `fileExists` does on any error.
class _DriveLikeCloud extends FakeCloudStorageProvider {
  @override
  Future<bool> fileExists(String fileId) async =>
      failDeletes ? false : super.fileExists(fileId);
}

void main() {
  late BackupPreferences preferences;
  late FakeCloudStorageProvider cloud;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = BackupPreferences(await SharedPreferences.getInstance());
    cloud = FakeCloudStorageProvider();
  });

  BackupService service() => BackupService(
    dbAdapter: UnusedBackupDatabaseAdapter(),
    preferences: preferences,
    cloudProvider: cloud,
    syncRepository: _Device('dev-A'),
  );

  /// Seeds a backup [daysAgo] old written by [device], returning its name.
  String seed(int daysAgo, {String device = 'dev-B'}) {
    final at = DateTime.now().subtract(Duration(days: daysAgo));
    final name =
        'submersion_backup_${_stamp.format(at)}__d${deviceTag(device)}.db';
    cloud.seedFile(name, Uint8List.fromList([1, 2, 3]), modified: at);
    return name;
  }

  void pinOn(String backup, String device) => cloud.seedFile(
    pinMarkerName(backupFilename: backup, pinningDeviceId: device),
    Uint8List(0),
  );

  bool has(String name) => cloud.bytesOf(name) != null;

  Future<void> switchOn([String account = 'acct']) async {
    await preferences.setCloudBackupEnabled(true);
    await preferences.setCrossDeviceRetentionAccount(account);
  }

  /// Eight backups 2 to 9 days old from three devices, newest first.
  List<String> eight() => [
    for (var d = 2; d <= 9; d++)
      seed(d, device: ['dev-A', 'dev-B', 'dev-C'][d % 3]),
  ];

  group('pruneOldBackups', () {
    test('with the switch on, prunes the folder across devices', () async {
      final names = eight();
      await switchOn();
      await service().pruneOldBackups(5);
      expect(
        [for (final n in names) has(n)],
        [...List.filled(5, true), ...List.filled(3, false)],
      );
    });

    test(
      'with the switch off, other devices\' backups are untouched',
      () async {
        final names = eight();
        await service().pruneOldBackups(5);
        expect(names.every(has), isTrue);
      },
    );

    test('a switch confirmed for another account does nothing', () async {
      final names = eight();
      await switchOn('other');
      await service().pruneOldBackups(5);
      expect(names.every(has), isTrue);
    });

    test('with cloud backup turned off, the rule does not run', () async {
      final names = eight();
      await switchOn();
      await preferences.setCloudBackupEnabled(false);
      await service().pruneOldBackups(5);
      expect(names.every(has), isTrue);
    });

    test('a failing rule does not fail the prune', () async {
      eight();
      await switchOn();
      cloud.failDeletes = true;
      await expectLater(service().pruneOldBackups(5), completes);
    });

    test(
      'per-device pruning keeps a cloud copy another device pinned',
      () async {
        final names = [seed(3, device: 'dev-A'), seed(4, device: 'dev-A')];
        for (final (i, n) in names.indexed) {
          await preferences.addRecord(
            BackupRecord(
              id: 'r$i',
              filename: n,
              timestamp: DateTime.now().subtract(Duration(days: 3 + i)),
              sizeBytes: 3,
              location: BackupLocation.cloud,
              cloudFileId: n,
              cloudAccountId: 'acct',
            ),
          );
        }
        pinOn(names[1], 'dev-B');

        await service().pruneOldBackups(1);

        expect(preferences.getHistory().map((r) => r.id), ['r0']);
        expect(has(names[1]), isTrue);
      },
    );
  });

  group('cloud round trips', () {
    int lists() => cloud.operationLog.where((o) => o == 'list').length;

    Future<void> addOwn(String name, int daysAgo, {bool pinned = false}) =>
        preferences.addRecord(
          BackupRecord(
            id: name,
            filename: name,
            timestamp: DateTime.now().subtract(Duration(days: daysAgo)),
            sizeBytes: 3,
            location: BackupLocation.cloud,
            cloudFileId: name,
            cloudAccountId: 'acct',
            pinned: pinned,
          ),
        );

    test('switch off, nothing pinned, nothing to prune: no listing', () async {
      await addOwn(seed(3, device: 'dev-A'), 3);
      await service().pruneOldBackups(5);
      expect(lists(), 0);
    });

    test('a prune reads the device id once', () async {
      final name = seed(3, device: 'dev-A');
      await addOwn(name, 3, pinned: true);
      final device = _Device('dev-A');
      await BackupService(
        dbAdapter: UnusedBackupDatabaseAdapter(),
        preferences: preferences,
        cloudProvider: cloud,
        syncRepository: device,
      ).pruneOldBackups(5);
      expect(device.deviceIdReads, 1);
    });

    test('a pin change is reconciled once, then not again', () async {
      final name = seed(3, device: 'dev-A');
      await addOwn(name, 3, pinned: true);
      await service().pruneOldBackups(5);
      expect(lists(), 1);
      expect(
        has(pinMarkerName(backupFilename: name, pinningDeviceId: 'dev-A')),
        isTrue,
      );
      cloud.operationLog.clear();
      await service().pruneOldBackups(5);
      expect(lists(), 0);
    });

    test('switch on: one listing to plan, one to re-check', () async {
      eight();
      await switchOn();
      await service().pruneOldBackups(5);
      expect(lists(), 2);
    });

    test('a pinned copy not yet listed gets its marker once it is', () async {
      final at = DateTime.now().subtract(const Duration(days: 3));
      final name =
          'submersion_backup_${_stamp.format(at)}__d${deviceTag('dev-A')}.db';
      await addOwn(name, 3, pinned: true);
      await service().pruneOldBackups(5);
      final marker = pinMarkerName(
        backupFilename: name,
        pinningDeviceId: 'dev-A',
      );
      expect(has(marker), isFalse);

      cloud.seedFile(name, Uint8List.fromList([1]), modified: at);
      await service().pruneOldBackups(5);
      expect(has(marker), isTrue);
    });

    test('an unreadable folder still frees the local copies', () async {
      final names = [seed(3, device: 'dev-A'), seed(4, device: 'dev-A')];
      for (final (i, n) in names.indexed) {
        await preferences.addRecord(
          BackupRecord(
            id: n,
            filename: n,
            timestamp: DateTime.now().subtract(Duration(days: 3 + i)),
            sizeBytes: 3,
            location: BackupLocation.both,
            cloudFileId: n,
            cloudAccountId: 'acct',
            localPath: '/nowhere/$n',
          ),
        );
      }
      cloud.authenticated = false;
      await service().pruneOldBackups(1);

      final old = preferences.getHistory().firstWhere((r) => r.id == names[1]);
      expect(old.localPath, isNull);
      expect(old.location, BackupLocation.cloud);
      expect(old.cloudFileId, names[1]);
      expect(has(names[1]), isTrue);
    });

    test('a failed listing keeps cloud copies for the next prune', () async {
      final names = [seed(3, device: 'dev-A'), seed(4, device: 'dev-A')];
      await addOwn(names[0], 3);
      await addOwn(names[1], 4);
      cloud.failLists = true;
      await service().pruneOldBackups(1);
      expect(preferences.getHistory(), hasLength(2));
      expect(names.every(has), isTrue);
    });
  });

  group('failures stay contained', () {
    test('a reconcile that cannot write leaves the state unrecorded', () async {
      final name = seed(3, device: 'dev-A');
      await preferences.addRecord(
        BackupRecord(
          id: name,
          filename: name,
          timestamp: DateTime.now().subtract(const Duration(days: 3)),
          sizeBytes: 3,
          location: BackupLocation.cloud,
          cloudFileId: name,
          cloudAccountId: 'acct',
          pinned: true,
        ),
      );
      cloud.failUploads = true;
      await service().reconcilePinMarkers();
      expect(preferences.getPinMarkersSynced(), isNull);
    });

    test(
      'an orphan marker that cannot be deleted does not fail apply',
      () async {
        eight();
        final gone = seed(20);
        final marker = pinMarkerName(
          backupFilename: gone,
          pinningDeviceId: 'dev-B',
        );
        cloud.seedFile(
          marker,
          Uint8List(0),
          modified: DateTime.now().subtract(const Duration(days: 20)),
        );
        await cloud.deleteFile(gone);
        final s = service();
        final plan = (await s.previewCrossDeviceRetention(5))!;
        cloud.failDeletes = true;
        expect(await s.applyCrossDeviceRetention(plan), 0);
        expect(has(marker), isTrue);
      },
    );

    test('a push that fails records nothing as gone', () async {
      cloud = _FailingPushCloud();
      final names = eight();
      await preferences.addRecord(
        BackupRecord(
          id: 'cloud-only',
          filename: names.last,
          timestamp: DateTime.now().subtract(const Duration(days: 9)),
          sizeBytes: 3,
          location: BackupLocation.cloud,
          cloudFileId: names.last,
          cloudAccountId: 'acct',
        ),
      );
      final s = service();
      final plan = (await s.previewCrossDeviceRetention(5))!;
      expect(await s.applyCrossDeviceRetention(plan), 0);
      expect(preferences.getHistory().single.id, 'cloud-only');
    });

    test('an unpin whose marker cannot be deleted still unpins', () async {
      final name = seed(3, device: 'dev-A');
      await preferences.addRecord(
        BackupRecord(
          id: 'r',
          filename: name,
          timestamp: DateTime.now().subtract(const Duration(days: 3)),
          sizeBytes: 3,
          location: BackupLocation.cloud,
          cloudFileId: name,
          cloudAccountId: 'acct',
        ),
      );
      final s = service();
      await s.pinBackup('r');
      cloud.failDeletes = true;
      await s.unpinBackup('r');
      expect(preferences.getHistory().single.pinned, isFalse);
    });

    test(
      'a local copy that cannot be deleted keeps its record for next time',
      () async {
        final dir = Directory.systemTemp.createTempSync('locked_backups_');
        addTearDown(() {
          Process.runSync('chmod', ['755', dir.path]);
          dir.deleteSync(recursive: true);
        });
        final names = [seed(3, device: 'dev-A'), seed(4, device: 'dev-A')];
        for (final (i, n) in names.indexed) {
          final local = File(p.join(dir.path, n))..writeAsStringSync('db');
          await preferences.addRecord(
            BackupRecord(
              id: n,
              filename: n,
              timestamp: DateTime.now().subtract(Duration(days: 3 + i)),
              sizeBytes: 3,
              location: BackupLocation.both,
              cloudFileId: n,
              cloudAccountId: 'acct',
              localPath: local.path,
            ),
          );
        }
        Process.runSync('chmod', ['555', dir.path]);
        cloud.authenticated = false;

        await service().pruneOldBackups(1);

        final old = preferences.getHistory().firstWhere(
          (r) => r.id == names[1],
        );
        expect(old.localPath, isNotNull);
        expect(old.location, BackupLocation.both);
      },
      skip: Platform.isWindows ? 'needs POSIX permissions' : false,
    );
  });

  group('preview and apply', () {
    test('a marker that appears after the preview saves that backup', () async {
      final names = eight();
      final s = service();
      final plan = (await s.previewCrossDeviceRetention(5))!;
      pinOn(names.last, 'dev-C');

      final removed = await s.applyCrossDeviceRetention(plan);

      expect(removed, 2);
      expect(has(names.last), isTrue);
      expect(has(names[5]), isFalse);
    });

    test('a failed re-listing deletes nothing', () async {
      final names = eight();
      final s = service();
      final plan = (await s.previewCrossDeviceRetention(5))!;
      cloud.failLists = true;

      expect(await s.applyCrossDeviceRetention(plan), 0);
      expect(names.every(has), isTrue);
    });

    test('a failed listing gives no preview', () async {
      eight();
      cloud.failLists = true;
      expect(await service().previewCrossDeviceRetention(5), isNull);
    });

    test('a file already deleted elsewhere counts as deleted', () async {
      final names = eight();
      final s = service();
      final plan = (await s.previewCrossDeviceRetention(5))!;
      await cloud.deleteFile(names.last);

      expect(await s.applyCrossDeviceRetention(plan), 3);
    });

    test('a delete that fails is not recorded as done', () async {
      cloud = _DriveLikeCloud();
      final names = eight();
      await preferences.addRecord(
        BackupRecord(
          id: 'cloud-only',
          filename: names.last,
          timestamp: DateTime.now().subtract(const Duration(days: 9)),
          sizeBytes: 3,
          location: BackupLocation.cloud,
          cloudFileId: names.last,
          cloudAccountId: 'acct',
          note: 'before the trip',
        ),
      );
      final s = service();
      final plan = (await s.previewCrossDeviceRetention(5))!;
      cloud.failDeletes = true;

      expect(await s.applyCrossDeviceRetention(plan), 0);
      expect(preferences.getHistory().single.note, 'before the trip');
    });

    test('orphan markers are removed', () async {
      eight();
      final gone = seed(20);
      final marker = pinMarkerName(
        backupFilename: gone,
        pinningDeviceId: 'dev-B',
      );
      cloud.seedFile(
        marker,
        Uint8List(0),
        modified: DateTime.now().subtract(const Duration(days: 20)),
      );
      await cloud.deleteFile(gone);
      final s = service();

      await s.applyCrossDeviceRetention(
        (await s.previewCrossDeviceRetention(5))!,
      );

      expect(has(marker), isFalse);
    });

    test(
      'an orphan marker whose backup arrives before apply is kept',
      () async {
        eight();
        final late = seed(20);
        final marker = pinMarkerName(
          backupFilename: late,
          pinningDeviceId: 'dev-B',
        );
        cloud.seedFile(
          marker,
          Uint8List(0),
          modified: DateTime.now().subtract(const Duration(days: 20)),
        );
        final bytes = cloud.bytesOf(late)!;
        await cloud.deleteFile(late);
        final s = service();
        final plan = (await s.previewCrossDeviceRetention(5))!;
        expect(plan.orphanMarkers.map((m) => m.name), [marker]);
        cloud.seedFile(late, bytes);

        await s.applyCrossDeviceRetention(plan);

        expect(has(marker), isTrue);
      },
    );

    test(
      'this device\'s record keeps its local copy, or goes when cloud-only',
      () async {
        final names = eight();
        await preferences.addRecord(
          BackupRecord(
            id: 'with-local',
            filename: names[7],
            timestamp: DateTime.now().subtract(const Duration(days: 9)),
            sizeBytes: 3,
            location: BackupLocation.both,
            cloudFileId: names[7],
            cloudAccountId: 'acct',
            localPath: '/backups/${names[7]}',
          ),
        );
        await preferences.addRecord(
          BackupRecord(
            id: 'cloud-only',
            filename: names[6],
            timestamp: DateTime.now().subtract(const Duration(days: 8)),
            sizeBytes: 3,
            location: BackupLocation.cloud,
            cloudFileId: names[6],
            cloudAccountId: 'acct',
          ),
        );
        final s = service();

        await s.applyCrossDeviceRetention(
          (await s.previewCrossDeviceRetention(5))!,
        );

        final history = preferences.getHistory();
        expect(history.map((r) => r.id), ['with-local']);
        expect(history.single.location, BackupLocation.local);
        expect(history.single.cloudFileId, isNull);
        expect(history.single.localPath, '/backups/${names[7]}');
      },
    );

    test('a pin in this device\'s history is kept', () async {
      final names = eight();
      await preferences.addRecord(
        BackupRecord(
          id: 'pinned',
          filename: names.last,
          timestamp: DateTime.now().subtract(const Duration(days: 9)),
          sizeBytes: 3,
          location: BackupLocation.cloud,
          cloudFileId: names.last,
          cloudAccountId: 'acct',
          pinned: true,
        ),
      );
      final plan = (await service().previewCrossDeviceRetention(5))!;
      expect(
        plan.toDelete.map((c) => c.file.name),
        isNot(contains(names.last)),
      );
      expect(plan.pinnedKept, 1);
    });

    test(
      'pre-migration and pre-downgrade copies are never candidates',
      () async {
        eight();
        for (final n in [
          '2026-01-01T000000Z-v300-v301.db',
          '2026-01-01T000000Z-v301-newer.db',
        ]) {
          cloud.seedFile(n, Uint8List(1), modified: DateTime(2026));
        }
        final plan = (await service().previewCrossDeviceRetention(1))!;
        expect(
          plan.toDelete.map((c) => c.file.name),
          everyElement(startsWith('submersion_backup_')),
        );
      },
    );
  });

  test(
    'an unknown account is keyed by the provider, never by nothing',
    () async {
      final s = BackupService(
        dbAdapter: UnusedBackupDatabaseAdapter(),
        preferences: preferences,
        cloudProvider: cloud,
        syncRepository: _Device('dev-A', account: null),
      );
      expect(await s.crossDeviceRetentionAccountKey(), 'provider:fake');
      await switchOn('');
      expect(await s.crossDeviceRetentionActive(), isFalse);
      await switchOn('provider:fake');
      expect(await s.crossDeviceRetentionActive(), isTrue);
    },
  );

  test('crossDeviceRetentionAccountKey is the copy account', () async {
    expect(await service().crossDeviceRetentionAccountKey(), 'acct');
    expect(await service().crossDeviceRetentionActive(), isFalse);
    await switchOn();
    expect(await service().crossDeviceRetentionActive(), isTrue);
  });
}
