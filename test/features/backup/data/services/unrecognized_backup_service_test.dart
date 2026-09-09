import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/data/services/backup_attribution.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/data/services/backups_directory_access.dart';
import 'package:submersion/features/backup/data/services/unrecognized_backup_service.dart';

/// Composition, not scanning. `OrphanedBackupScan` already has its own tests
/// for classification and for the reclaim refusal; what is untested until here
/// is that the scan is pointed at the leased directory, told what this device's
/// history actually knows, and given this device's real sync identity.
void main() {
  const thisDevice = 'device-a';
  const otherDevice = 'device-b';

  late Directory backups;
  late int leasesReleased;

  setUp(() async {
    backups = await Directory.systemTemp.createTemp('unrecognized_backups');
    leasesReleased = 0;
  });

  tearDown(() async {
    if (backups.existsSync()) await backups.delete(recursive: true);
  });

  Future<String> writeBackup({
    required String timestamp,
    required String deviceId,
    int bytes = 1024,
  }) async {
    final path = p.join(
      backups.path,
      buildBackupFilename(timestamp: timestamp, deviceId: deviceId),
    );
    await File(path).writeAsBytes(List.filled(bytes, 0));
    return path;
  }

  UnrecognizedBackupService serviceFor({
    Set<String> knownPaths = const {},
    String? configuredLocation,
  }) => UnrecognizedBackupService(
    access: BackupsDirectoryAccess(
      configuredLocation: () async => configuredLocation,
      acquireLease: () async =>
          BackupDirLease(backups.path, () async => leasesReleased++),
    ),
    knownPaths: () async => knownPaths,
    thisDeviceId: () async => thisDevice,
  );

  test('lists a backup file the history has no record of', () async {
    await writeBackup(timestamp: '2026-09-01_1200', deviceId: thisDevice);

    final found = (await serviceFor().find())!;

    expect(found, hasLength(1));
    expect(found.single.ownership, BackupOwnership.thisDevice);
  });

  test('a file the history still knows about is not listed', () async {
    final known = await writeBackup(
      timestamp: '2026-09-01_1200',
      deviceId: thisDevice,
    );

    final found = (await serviceFor(knownPaths: {known}).find())!;

    expect(found, isEmpty);
  });

  test(
    'this device is read from the live sync identity, not the file',
    () async {
      await writeBackup(timestamp: '2026-09-01_1200', deviceId: otherDevice);

      final found = (await serviceFor().find())!;

      expect(found.single.ownership, BackupOwnership.otherDevice);
      expect(found.single.isReclaimable, isFalse);
    },
  );

  test('a location that cannot be enumerated reports null, not empty', () async {
    // Null is not zero, the same distinction slice A's StorageCategory.measure
    // draws. An empty list here would tell an Android SAF user their backup
    // folder holds nothing forgotten, when it was never readable at all.
    await writeBackup(timestamp: '2026-09-01_1200', deviceId: thisDevice);

    final found = await serviceFor(
      configuredLocation: 'content://com.android.providers/tree/primary%3AB',
    ).find();

    expect(found, isNull);
  });

  test('reclaiming deletes the file and reports the bytes freed', () async {
    final path = await writeBackup(
      timestamp: '2026-09-01_1200',
      deviceId: thisDevice,
      bytes: 2048,
    );
    final service = serviceFor();

    final freed = await service.reclaim((await service.find())!);

    expect(freed, 2048);
    expect(File(path).existsSync(), isFalse);
  });

  test('reclaiming runs inside a directory lease and releases it', () async {
    await writeBackup(timestamp: '2026-09-01_1200', deviceId: thisDevice);
    final service = serviceFor();
    final found = (await service.find())!;
    leasesReleased = 0;

    await service.reclaim(found);

    expect(leasesReleased, 1);
  });

  test('a pre-migration safety copy is never listed', () async {
    // Named by LiveDatabaseCopier as `<timestamp>-v<from>-v<to>.db`, with no
    // `submersion_backup_` prefix, so the scan's prefix gate excludes it. That
    // gate is the only thing standing between this page and offering to delete
    // the copy taken immediately before a schema migration, which is the one
    // file a failed migration needs. Pinned here because the pre-migration
    // writer logs "registration failed; .db is on disk" on its own error path,
    // so an unrecorded safety copy is a state the app produces deliberately.
    await File(
      p.join(backups.path, '20260901-120000000-v114-v115.db'),
    ).writeAsBytes(List.filled(1024, 0));

    expect(await serviceFor().find(), isEmpty);
  });

  group('knownBackupPaths', () {
    BackupRecord recordWith({String? localPath, String? cloudFileId}) =>
        BackupRecord(
          id: 'id',
          filename: 'submersion_backup_2026-09-01_1200__d0123456789abcdef.db',
          timestamp: DateTime.utc(2026, 9, 1),
          sizeBytes: 1024,
          location: cloudFileId == null
              ? BackupLocation.local
              : BackupLocation.cloud,
          localPath: localPath,
          cloudFileId: cloudFileId,
        );

    test('a record with a local file marks that path known', () {
      expect(knownBackupPaths([recordWith(localPath: '/backups/a.db')]), {
        '/backups/a.db',
      });
    });

    test('a cloud-only record contributes no local path', () {
      expect(knownBackupPaths([recordWith(cloudFileId: 'drive-1')]), isEmpty);
    });
  });

  group('knownPathsFromPreferences', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'a record whose file is unreachable still marks its path known',
      () async {
        // The distinction between the raw history and getValidatedBackupHistory,
        // which drops records whose file is missing and rewrites preferences to
        // match. A backups folder on an unmounted share or an unsynced cloud
        // folder is momentarily "missing" and would lose its records; when the
        // files came back they would be unattributed to any history, this
        // device's by name, and offered for deletion. The raw history is a
        // superset, which errs in the only safe direction.
        final preferences = BackupPreferences(
          await SharedPreferences.getInstance(),
        );
        await preferences.setHistory([
          BackupRecord(
            id: 'unreachable',
            filename: 'submersion_backup_2026-09-01_1200__d0123456789abcdef.db',
            timestamp: DateTime.utc(2026, 9, 1),
            sizeBytes: 1024,
            location: BackupLocation.local,
            localPath: '/volumes/unmounted/submersion_backup.db',
          ),
        ]);

        expect(await knownPathsFromPreferences(preferences), {
          '/volumes/unmounted/submersion_backup.db',
        });
      },
    );
  });
}
