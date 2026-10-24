import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/features/backup/data/services/backup_attribution.dart';
import 'package:submersion/features/backup/data/services/backup_pin_markers.dart';
import 'package:submersion/features/backup/data/services/cloud_backup_history.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';

CloudFileInfo _file(
  String name, {
  String? id,
  DateTime? modified,
  int? sizeBytes = 2048,
}) => CloudFileInfo(
  id: id ?? 'id-$name',
  name: name,
  modifiedTime: modified ?? DateTime(2026, 1, 1),
  sizeBytes: sizeBytes,
);

BackupRecord _tracked({
  required String id,
  required String filename,
  required DateTime timestamp,
  String? cloudFileId,
}) => BackupRecord(
  id: id,
  filename: filename,
  timestamp: timestamp,
  sizeBytes: 100,
  location: cloudFileId == null ? BackupLocation.local : BackupLocation.both,
  localPath: '/backups/$filename',
  cloudFileId: cloudFileId,
  diveCount: 4,
  siteCount: 2,
);

void main() {
  group('backupRecordFromCloudFile', () {
    test('maps an attributed backup to a cloud-only record', () {
      final name = buildBackupFilename(
        timestamp: '2026-03-14_093015',
        deviceId: 'old-install',
      );
      final record = backupRecordFromCloudFile(
        _file(name, id: 'dbx-1', sizeBytes: 5000),
      );

      expect(record, isNotNull);
      expect(record!.id, 'cloud:dbx-1');
      expect(record.filename, name);
      expect(record.cloudFileId, 'dbx-1');
      expect(record.localPath, isNull);
      expect(record.location, BackupLocation.cloud);
      expect(record.sizeBytes, 5000);
      expect(record.pinned, isFalse);
      // Counts lived only in the lost record; inventing zeros would misreport.
      expect(record.diveCount, isNull);
      expect(record.siteCount, isNull);
    });

    test('takes the timestamp from the name, not the upload time', () {
      final record = backupRecordFromCloudFile(
        _file(
          'submersion_backup_2026-03-14_093015.sbe',
          modified: DateTime(2026, 3, 20),
        ),
      );
      expect(record!.timestamp, DateTime(2026, 3, 14, 9, 30, 15));
    });

    test('falls back to the modified time when the name has no date', () {
      final modified = DateTime(2026, 5, 2, 7);
      final record = backupRecordFromCloudFile(
        _file('submersion_backup_renamed.db', modified: modified),
      );
      expect(record!.timestamp, modified);
    });

    test('an unknown size is reported as zero', () {
      final record = backupRecordFromCloudFile(
        _file('submersion_backup_2026-03-14_093015.db', sizeBytes: null),
      );
      expect(record!.sizeBytes, 0);
    });

    test('ignores files that are not backups', () {
      for (final name in [
        'submersion_sync_device.json',
        'submersion_backup_2026-03-14_093015.db.tmp',
        '.submersion_backup_2026-03-14_093015.db.tmp',
        'notes.txt',
      ]) {
        expect(backupRecordFromCloudFile(_file(name)), isNull, reason: name);
      }
    });
  });

  group('mergeCloudBackups', () {
    test('returns the history unchanged when the cloud has nothing', () {
      final history = [
        _tracked(id: 'a', filename: 'a.db', timestamp: DateTime(2026, 2, 1)),
      ];
      expect(mergeCloudBackups(history, const []), history);
    });

    test('adds cloud backups the history has no record of', () {
      final merged = mergeCloudBackups(const [], [
        _file('submersion_backup_2026-03-14_093015.db', id: 'x'),
      ]);
      expect(merged.single.id, 'cloud:x');
      expect(merged.single.location, BackupLocation.cloud);
    });

    test('skips a cloud file a record already points at', () {
      final history = [
        _tracked(
          id: 'a',
          filename: 'submersion_backup_2026-03-14_093015.db',
          timestamp: DateTime(2026, 3, 14),
          cloudFileId: 'x',
        ),
      ];
      final merged = mergeCloudBackups(history, [
        _file('submersion_backup_2026-03-14_093015.db', id: 'x'),
      ]);
      expect(merged, history);
    });

    test('skips an encrypted cloud copy of a tracked plaintext backup', () {
      // Sync encryption uploads `X.sbe` for a local `X.db`; the record keeps
      // the local name, so only the stem ties the two together.
      final history = [
        _tracked(
          id: 'a',
          filename: 'submersion_backup_2026-03-14_093015.db',
          timestamp: DateTime(2026, 3, 14),
        ),
      ];
      final merged = mergeCloudBackups(history, [
        _file('submersion_backup_2026-03-14_093015.sbe', id: 'other-id'),
      ]);
      expect(merged, history);
    });

    test('a file listed twice becomes one row', () {
      // A legacy Drive file with two parents is returned by two of the
      // duplicate-folder queries.
      final file = _file('submersion_backup_2026-03-14_093015.db', id: 'x');
      expect(mergeCloudBackups(const [], [file, file]), hasLength(1));
    });

    test('sorts the merged list newest first', () {
      final history = [
        _tracked(
          id: 'mid',
          filename: 'submersion_backup_2026-02-01_120000.db',
          timestamp: DateTime(2026, 2, 1, 12),
        ),
      ];
      final merged = mergeCloudBackups(history, [
        _file('submersion_backup_2026-01-01_120000.db', id: 'old'),
        _file('submersion_backup_2026-03-01_120000.db', id: 'new'),
      ]);
      expect(merged.map((r) => r.id), ['cloud:new', 'mid', 'cloud:old']);
    });
  });

  // Review of #3541: a same-named backup in another account does not hide
  // this account's file.
  test('a name match only counts within the listed account', () {
    final elsewhere = BackupRecord(
      id: 'r1',
      filename: 'submersion_backup_2026-10-19_101500.db',
      timestamp: DateTime(2026, 10, 19),
      sizeBytes: 1,
      location: BackupLocation.cloud,
      cloudFileId: 'other-id',
      cloudAccountId: 'acct-a',
    );
    final merged = mergeCloudBackups(
      [elsewhere],
      [
        CloudFileInfo(
          id: 'f1',
          name: 'submersion_backup_2026-10-19_101500.sbe',
          modifiedTime: DateTime(2026, 10, 19),
        ),
      ],
      accountId: 'acct-b',
    );
    expect(merged.map((r) => r.cloudFileId), containsAll(['other-id', 'f1']));
  });

  test('rows from a listing note the account they were listed from', () {
    final merged = mergeCloudBackups(const [], [
      CloudFileInfo(
        id: 'f1',
        name: 'submersion_backup_2026-10-19_101500.db',
        modifiedTime: DateTime(2026, 10, 19),
      ),
    ], accountId: 'acct-b');
    expect(merged.single.cloudAccountId, 'acct-b');
  });

  group('markPinnedOnAnotherDevice (#3503)', () {
    const name = 'submersion_backup_2026-10-01_090000.db';
    final row = backupRecordFromCloudFile(_file(name))!;
    CloudFileInfo marker(String device) =>
        _file(pinMarkerName(backupFilename: name, pinningDeviceId: device));

    test('marks a row another device has pinned', () {
      final rows = markPinnedOnAnotherDevice(
        [row],
        [_file(name), marker('dev-B')],
        thisDeviceId: 'dev-A',
      );
      expect(rows.single.pinnedOnAnotherDevice, isTrue);
    });

    test('ignores this device\'s own marker', () {
      final rows = markPinnedOnAnotherDevice(
        [row],
        [_file(name), marker('dev-A')],
        thisDeviceId: 'dev-A',
      );
      expect(rows.single.pinnedOnAnotherDevice, isFalse);
    });

    test('leaves this device\'s own history rows pinnable', () {
      final own = _tracked(
        id: 'own',
        filename: name,
        timestamp: DateTime(2026, 10, 1, 9),
        cloudFileId: 'id-$name',
      );
      final rows = markPinnedOnAnotherDevice(
        [own],
        [_file(name), marker('dev-B')],
        thisDeviceId: 'dev-A',
      );
      expect(rows.single.pinnedOnAnotherDevice, isFalse);
    });

    test('leaves a row pinned here alone', () {
      final pinned = row.copyWith(pinned: true);
      final rows = markPinnedOnAnotherDevice(
        [pinned],
        [_file(name), marker('dev-B')],
        thisDeviceId: 'dev-A',
      );
      expect(rows.single, pinned);
    });

    test('is never written to the stored record', () {
      final marked = row.copyWith(pinnedOnAnotherDevice: true);
      expect(marked.toJson().containsKey('pinnedOnAnotherDevice'), isFalse);
    });
  });
}
