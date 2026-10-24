// Issue #3503: with the switch on, the "Keep" number is a ceiling on the
// whole shared cloud folder, counting every device's backups.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_attribution.dart';
import 'package:submersion/features/backup/data/services/backup_pin_markers.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/unused_backup_database_adapter.dart';

class _Device extends SyncRepository {
  _Device(this.deviceId);

  final String deviceId;

  @override
  Future<String> getDeviceId() async => deviceId;

  @override
  Future<String?> getSyncAccountId() async => 'acct';
}

final _stamp = DateFormat('yyyy-MM-dd_HHmmss');

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

  Future<void> switchOn([String account = 'acct']) =>
      preferences.setCrossDeviceRetentionAccount(account);

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

    test('orphan markers are removed', () async {
      eight();
      final gone = seed(20);
      pinOn(gone, 'dev-B');
      await cloud.deleteFile(gone);
      final marker = pinMarkerName(
        backupFilename: gone,
        pinningDeviceId: 'dev-B',
      );
      final s = service();

      await s.applyCrossDeviceRetention(
        (await s.previewCrossDeviceRetention(5))!,
      );

      expect(has(marker), isFalse);
    });

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

  test('crossDeviceRetentionAccountKey is the copy account', () async {
    expect(await service().crossDeviceRetentionAccountKey(), 'acct');
    expect(await service().crossDeviceRetentionActive(), isFalse);
    await switchOn();
    expect(await service().crossDeviceRetentionActive(), isTrue);
  });
}
