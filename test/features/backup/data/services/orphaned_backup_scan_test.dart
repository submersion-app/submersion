import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/backup/data/services/backup_attribution.dart';
import 'package:submersion/features/backup/data/services/orphaned_backup_scan.dart';

void main() {
  const thisDevice = '9f8e7d6c-1111-2222-3333-444455556666';
  const otherDevice = '0a1b2c3d-1111-2222-3333-444455556666';

  late Directory backups;

  setUp(() async {
    backups = await Directory.systemTemp.createTemp('orphan_backup_test');
  });

  tearDown(() async {
    if (backups.existsSync()) await backups.delete(recursive: true);
  });

  Future<String> writeBackup({
    required String deviceId,
    required String timestamp,
    int bytes = 100,
    String extension = '.db',
  }) async {
    // buildBackupFilename always yields `.db`; BackupService names the
    // encrypted artifact by swapping the extension on the same stem, so the
    // fixture does the same rather than asking the generator for it.
    final plaintext = buildBackupFilename(
      timestamp: timestamp,
      deviceId: deviceId,
    );
    final name = extension == '.db'
        ? plaintext
        : '${p.basenameWithoutExtension(plaintext)}$extension';
    final file = File(p.join(backups.path, name));
    await file.writeAsBytes(List<int>.filled(bytes, 0));
    return file.path;
  }

  Future<String> writeRaw(String name, {int bytes = 100}) async {
    final file = File(p.join(backups.path, name));
    await file.writeAsBytes(List<int>.filled(bytes, 0));
    return file.path;
  }

  OrphanedBackupScan build({Set<String> known = const {}}) =>
      OrphanedBackupScan(
        backupsDirectory: () async => backups.path,
        knownPaths: () async => known,
        thisDeviceId: () async => thisDevice,
      );

  test('a backup still in the history is not unrecognized', () async {
    final path = await writeBackup(
      deviceId: thisDevice,
      timestamp: '2026-08-31_120000',
    );

    final found = await build(known: {path}).find();

    expect(found, isEmpty);
  });

  test('this device\'s forgotten backup is reclaimable', () async {
    final path = await writeBackup(
      deviceId: thisDevice,
      timestamp: '2026-08-31_120000',
      bytes: 512,
    );

    final found = await build().find();

    expect(found, hasLength(1));
    expect(found.single.path, path);
    expect(found.single.sizeBytes, 512);
    expect(found.single.ownership, BackupOwnership.thisDevice);
    expect(found.single.isReclaimable, isTrue);
  });

  test('another device\'s backup is listed but never reclaimable', () async {
    // The hazard: in a shared Dropbox or Drive folder this file is absent from
    // our history because it was never ours, not because it was forgotten.
    await writeBackup(deviceId: otherDevice, timestamp: '2026-08-31_120000');

    final found = await build().find();

    expect(found, hasLength(1));
    expect(found.single.ownership, BackupOwnership.otherDevice);
    expect(found.single.isReclaimable, isFalse);
  });

  test('a legacy backup is listed but never reclaimable', () async {
    await writeRaw('submersion_backup_2026-08-31_120000.db');

    final found = await build().find();

    expect(found.single.ownership, BackupOwnership.unattributed);
    expect(found.single.isReclaimable, isFalse);
  });

  test('encrypted backups are scanned too', () async {
    await writeBackup(
      deviceId: thisDevice,
      timestamp: '2026-08-31_120000',
      extension: '.sbe',
    );

    final found = await build().find();

    expect(found.single.isReclaimable, isTrue);
  });

  test('non-backup files in the folder are ignored entirely', () async {
    await writeRaw('holiday_photos.zip');
    await writeRaw('notes.txt');
    await writeRaw('.hidden_backup.db.tmp');

    final found = await build().find();

    expect(found, isEmpty);
  });

  test('an in-progress write is not mistaken for a finished backup', () async {
    // LiveDatabaseCopier writes to `.<filename>.tmp` beside the target, so a
    // partially written backup carries the real prefix one character in. The
    // name must not start with the prefix for the scan to claim it, and the
    // extension is `.tmp` rather than `.db`, so two independent gates exclude
    // it. Listing one would offer a backup that is still being written.
    await writeRaw(
      '.${buildBackupFilename(timestamp: '2026-09-01_1200', deviceId: thisDevice)}.tmp',
    );

    expect(await build().find(), isEmpty);
  });

  test('bytes freed are measured at delete time, not at scan time', () async {
    // The size on an UnrecognizedBackup is whatever the listing saw, and the
    // page it feeds can sit open for as long as the user reads it. A cloud
    // client rewriting the file in that window would make the freed figure a
    // number the app made up rather than one it measured.
    final path = await writeBackup(
      deviceId: thisDevice,
      timestamp: '2026-09-01_1200',
      bytes: 100,
    );
    final scan = build();
    final found = await scan.find();

    await File(path).writeAsBytes(List<int>.filled(4096, 0));

    expect(await scan.reclaim(found), 4096);
  });

  group('reclaim re-derives its own permission to delete', () {
    // isReclaimable reads a field computed when the directory was listed.
    // Re-reading it is not a re-check, so these three cases hand reclaim an
    // entry that claims to be reclaimable and confirm it decides for itself.
    UnrecognizedBackup claiming(String path) => UnrecognizedBackup(
      path: path,
      sizeBytes: 100,
      modified: DateTime(2026, 9, 1),
      ownership: BackupOwnership.thisDevice,
    );

    test('a file outside the backups directory is refused', () async {
      final elsewhere = await Directory.systemTemp.createTemp('not_backups');
      addTearDown(() async {
        if (elsewhere.existsSync()) await elsewhere.delete(recursive: true);
      });
      final outsider = File(
        p.join(
          elsewhere.path,
          buildBackupFilename(
            timestamp: '2026-09-01_1200',
            deviceId: thisDevice,
          ),
        ),
      );
      await outsider.writeAsBytes(List<int>.filled(100, 0));

      expect(await build().reclaim([claiming(outsider.path)]), 0);
      expect(outsider.existsSync(), isTrue);
    });

    test('a name tagged for another device is refused', () async {
      final path = await writeBackup(
        deviceId: otherDevice,
        timestamp: '2026-09-01_1200',
      );

      expect(await build().reclaim([claiming(path)]), 0);
      expect(File(path).existsSync(), isTrue);
    });

    test(
      'nothing is deleted when the directory cannot be enumerated',
      () async {
        final path = await writeBackup(
          deviceId: thisDevice,
          timestamp: '2026-09-01_1200',
        );
        final scan = OrphanedBackupScan(
          backupsDirectory: () async => null,
          knownPaths: () async => const {},
          thisDeviceId: () async => thisDevice,
        );

        expect(await scan.reclaim([claiming(path)]), 0);
        expect(File(path).existsSync(), isTrue);
      },
    );
  });

  test('a directory that cannot be enumerated yields nothing', () async {
    final scan = OrphanedBackupScan(
      backupsDirectory: () async => null,
      knownPaths: () async => const {},
      thisDeviceId: () async => thisDevice,
    );

    expect(await scan.find(), isEmpty);
  });

  group('reclaim', () {
    test('deletes this device\'s files and reports the bytes', () async {
      final path = await writeBackup(
        deviceId: thisDevice,
        timestamp: '2026-08-31_120000',
        bytes: 700,
      );
      final scan = build();
      final found = await scan.find();

      final bytes = await scan.reclaim(found);

      expect(bytes, 700);
      expect(File(path).existsSync(), isFalse);
    });

    test('refuses another device\'s file even when handed one', () async {
      // Defence in depth. The UI never offers these, but reclaim is the last
      // gate before an irreversible delete, so it re-checks rather than
      // trusting its caller.
      final path = await writeBackup(
        deviceId: otherDevice,
        timestamp: '2026-08-31_120000',
      );
      final scan = build();
      final found = await scan.find();

      final bytes = await scan.reclaim(found);

      expect(bytes, 0);
      expect(File(path).existsSync(), isTrue);
    });

    test('refuses a legacy file even when handed one', () async {
      final path = await writeRaw('submersion_backup_2026-08-31_120000.db');
      final scan = build();
      final found = await scan.find();

      final bytes = await scan.reclaim(found);

      expect(bytes, 0);
      expect(File(path).existsSync(), isTrue);
    });

    test('reclaims only the safe files from a mixed selection', () async {
      final mine = await writeBackup(
        deviceId: thisDevice,
        timestamp: '2026-08-31_120000',
        bytes: 300,
      );
      final theirs = await writeBackup(
        deviceId: otherDevice,
        timestamp: '2026-08-31_130000',
        bytes: 900,
      );
      final scan = build();

      final bytes = await scan.reclaim(await scan.find());

      expect(bytes, 300);
      expect(File(mine).existsSync(), isFalse);
      expect(File(theirs).existsSync(), isTrue);
    });
  });
}
