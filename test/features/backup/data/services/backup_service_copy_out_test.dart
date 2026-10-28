// A backup from the history, resolved to a real file the diver can save or
// share (issue #3650): used in place, streamed out of a SAF folder, or
// downloaded from the cloud, and never added to the history.

import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/security/database_encryption_migrator.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_copy_guard.dart';
import 'package:submersion/features/backup/data/services/backup_crypto.dart';
import 'package:submersion/features/backup/data/services/backup_saf_port.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';

import '../../../../helpers/mock_channels.dart';
import '../../../../support/fake_cloud_storage_provider.dart';

const _liveKeyHex =
    '4a5f1c9d3e8b0726114d90ab63fe2d58c7093a41bb5e6f28d0c1a7935e4b8206';

class _Adapter implements BackupDatabaseAdapter {
  _Adapter({this.databaseKeyHex});

  @override
  final String? databaseKeyHex;

  @override
  Future<void> backup(String destinationPath, {String? note}) async {}

  @override
  Future<void> restore(
    String backupPath, {
    void Function(int, int)? onMigrationProgress,
  }) async {}

  @override
  Future<String> get databasePath async => '/noop';

  @override
  AppDatabase get database => throw UnimplementedError();
}

class _SafPort implements BackupSafPort {
  _SafPort({
    this.source,
    this.present = true,
    this.failAfterPartial = false,
    this.existsThrows = false,
  });

  /// Copied to the destination on a read.
  final String? source;
  final bool present;

  /// The existence check itself fails, as when the folder permission was
  /// revoked.
  final bool existsThrows;

  /// Writes a few bytes, then throws: a stream cut off part way.
  final bool failAfterPartial;

  @override
  Future<void> readBackup({
    required String documentUri,
    required String destPath,
  }) async {
    if (failAfterPartial) {
      await File(destPath).writeAsBytes([1, 2, 3]);
      throw PlatformException(code: 'READ_FAILED');
    }
    await File(source!).copy(destPath);
  }

  @override
  Future<bool> exists(String documentUri) async {
    if (existsThrows) throw PlatformException(code: 'PERMISSION_DENIED');
    return present;
  }

  @override
  Future<String> writeBackup({
    required String treeUri,
    required String fileName,
    required String sourcePath,
  }) => throw UnimplementedError();

  @override
  Future<bool> delete(String documentUri) async => true;

  @override
  Future<String?> resolveTree(String treeUri) async => null;
}

/// A download that writes part of the file and then fails.
class _PartialDownloadCloud extends FakeCloudStorageProvider {
  @override
  Future<void> downloadToFile(String fileId, String destinationPath) async {
    await File(destinationPath).writeAsBytes([1, 2, 3]);
    throw Exception('connection reset');
  }
}

class _Sync extends SyncRepository {
  _Sync(this.accountId);

  final String? accountId;

  @override
  Future<String?> getSyncAccountId() async => accountId;
}

final _isolatedTempDir = Directory.systemTemp.createTempSync('copy_out_pp_');

void main() {
  tearDownAll(() {
    if (_isolatedTempDir.existsSync()) {
      _isolatedTempDir.deleteSync(recursive: true);
    }
  });
  TestWidgetsFlutterBinding.ensureInitialized();

  late BackupPreferences prefs;
  late Directory tmp;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => _isolatedTempDir.path,
        );
  });
  tearDownAll(clearPathAndShareChannelMocks);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = BackupPreferences(await SharedPreferences.getInstance());
    tmp = await Directory.systemTemp.createTemp('copy_out_');
    // Each test starts with an empty temp folder, so "nothing left behind"
    // means nothing at all.
    for (final e in _isolatedTempDir.listSync()) {
      e.deleteSync(recursive: true);
    }
  });
  tearDown(() => tmp.delete(recursive: true));

  String writeDb(String name) {
    final path = p.join(tmp.path, name);
    final db = sqlite3.sqlite3.open(path);
    try {
      db.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
      db.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
    } finally {
      db.close();
    }
    return path;
  }

  Future<String> writeProtectedDb(String name) async {
    final path = writeDb(name);
    await DatabaseEncryptionMigrator().encryptInPlace(
      dbPath: path,
      keyHex: _liveKeyHex,
    );
    return path;
  }

  Future<String> wrapAsSbe(String plainPath, String name) async {
    final mlk = SecretKey(List<int>.generate(32, (i) => (i * 5 + 2) % 256));
    const keyId = '6fa459ea-ee8a-3ca4-894e-db77e160355e';
    final slots = KeyslotFile(
      version: 1,
      libraryKeyId: keyId,
      slots: [
        await Keyslots.createSlot(
          type: 'passphrase',
          secret: 'pass',
          mlk: mlk,
          kdf: const KdfParams(m: 1024, t: 3, p: 1),
        ),
      ],
    );
    final out = p.join(tmp.path, name);
    await BackupCrypto.encryptFile(
      inPath: plainPath,
      outPath: out,
      mlk: mlk,
      libraryKeyId: keyId,
      keyslotBytes: slots.toJsonBytes(),
    );
    return out;
  }

  BackupRecord record({
    String filename = 'submersion_backup_2026-10-27.db',
    String? localPath,
    String? cloudFileId,
    String? cloudAccountId,
    BackupType type = BackupType.manual,
    BackupLocation location = BackupLocation.local,
  }) => BackupRecord(
    id: 'r1',
    filename: filename,
    timestamp: DateTime(2026, 10, 27, 19, 42),
    sizeBytes: 1,
    location: location,
    localPath: localPath,
    cloudFileId: cloudFileId,
    cloudAccountId: cloudAccountId,
    type: type,
  );

  BackupService service({
    BackupSafPort? safPort,
    FakeCloudStorageProvider? cloud,
    String? syncAccountId,
    String? keyHex,
  }) => BackupService(
    dbAdapter: _Adapter(databaseKeyHex: keyHex),
    preferences: prefs,
    safPort: safPort,
    cloudProvider: cloud,
    syncRepository: _Sync(syncAccountId),
  );

  List<String> tempNames() =>
      _isolatedTempDir.listSync().map((e) => p.basename(e.path)).toList();

  group('prepareBackupCopy', () {
    test('local record is used in place', () async {
      final path = writeDb('local.db');

      final copy = await service().prepareBackupCopy(
        record(localPath: path),
        purpose: BackupCopyPurpose.share,
      );

      expect(copy.path, path);
      expect(copy.isTemp, isFalse);
    });

    test(
      'saf record is streamed to temp under its own name for a share',
      () async {
        final source = writeDb('saf_source.db');

        final copy = await service(safPort: _SafPort(source: source))
            .prepareBackupCopy(
              record(localPath: 'content://tree/doc/1'),
              purpose: BackupCopyPurpose.share,
            );

        expect(p.basename(copy.path), 'submersion_backup_2026-10-27.db');
        expect(copy.isTemp, isTrue);
        expect(
          await File(copy.path).readAsBytes(),
          await File(source).readAsBytes(),
        );
      },
    );

    test('saf record gets a restore- name for a save', () async {
      final source = writeDb('saf_source.db');

      final copy = await service(safPort: _SafPort(source: source))
          .prepareBackupCopy(
            record(localPath: 'content://tree/doc/1'),
            purpose: BackupCopyPurpose.save,
          );

      final name = p.basename(copy.path);
      expect(name, startsWith('restore-'));
      expect(name, endsWith('-submersion_backup_2026-10-27.db'));
      expect(copy.isTemp, isTrue);
    });

    test('saf record whose document is gone throws not found', () async {
      await expectLater(
        service(safPort: _SafPort(present: false)).prepareBackupCopy(
          record(localPath: 'content://tree/doc/1'),
          purpose: BackupCopyPurpose.share,
        ),
        throwsA(isA<BackupException>()),
      );
      expect(tempNames(), isEmpty);
    });

    for (final (label, port) in [
      ('is gone', _SafPort(present: false)),
      ('cannot be checked', _SafPort(existsThrows: true)),
    ]) {
      test('a saf document that $label falls back to the cloud copy', () async {
        // As a missing plain local file does: the cloud copy is the same
        // backup.
        final cloud = FakeCloudStorageProvider();
        final upload = await cloud.uploadFile(
          Uint8List.fromList([9, 8, 7]),
          'submersion_backup_2026-10-27.db',
        );

        final copy = await service(safPort: port, cloud: cloud)
            .prepareBackupCopy(
              record(
                localPath: 'content://tree/doc/1',
                cloudFileId: upload.fileId,
                location: BackupLocation.both,
              ),
              purpose: BackupCopyPurpose.share,
            );

        expect(await File(copy.path).readAsBytes(), [9, 8, 7]);
      });
    }

    test(
      'a saf read that fails after the check falls back to the cloud copy',
      () async {
        // The document went, or the grant was revoked, between the existence
        // check and the read.
        final cloud = FakeCloudStorageProvider();
        final upload = await cloud.uploadFile(
          Uint8List.fromList([6, 5, 4]),
          'submersion_backup_2026-10-27.db',
        );

        final copy =
            await service(
              safPort: _SafPort(failAfterPartial: true),
              cloud: cloud,
            ).prepareBackupCopy(
              record(
                localPath: 'content://tree/doc/1',
                cloudFileId: upload.fileId,
                location: BackupLocation.both,
              ),
              purpose: BackupCopyPurpose.share,
            );

        expect(await File(copy.path).readAsBytes(), [6, 5, 4]);
        expect(tempNames(), ['submersion_backup_2026-10-27.db']);
      },
    );

    test(
      'a saf check that fails with no cloud copy surfaces its own error',
      () async {
        // "Not found" would send the diver looking for a file that is still
        // there; the revoked grant is the real cause.
        await expectLater(
          service(safPort: _SafPort(existsThrows: true)).prepareBackupCopy(
            record(localPath: 'content://tree/doc/1'),
            purpose: BackupCopyPurpose.share,
          ),
          throwsA(isA<PlatformException>()),
        );
      },
    );

    test('a saf stream cut off part way leaves nothing in temp', () async {
      await expectLater(
        service(safPort: _SafPort(failAfterPartial: true)).prepareBackupCopy(
          record(localPath: 'content://tree/doc/1'),
          purpose: BackupCopyPurpose.share,
        ),
        throwsA(isA<PlatformException>()),
      );
      expect(tempNames(), isEmpty);
    });

    test('cloud-only record is downloaded under its own name', () async {
      final cloud = FakeCloudStorageProvider();
      final bytes = Uint8List.fromList(List<int>.generate(64, (i) => i));
      final upload = await cloud.uploadFile(
        bytes,
        'submersion_backup_2026-10-20.sbe',
      );

      final copy = await service(cloud: cloud).prepareBackupCopy(
        record(
          filename: 'submersion_backup_2026-10-20.sbe',
          cloudFileId: upload.fileId,
          location: BackupLocation.cloud,
        ),
        purpose: BackupCopyPurpose.share,
      );

      expect(p.basename(copy.path), 'submersion_backup_2026-10-20.sbe');
      expect(copy.isTemp, isTrue);
      expect(await File(copy.path).readAsBytes(), bytes);
    });

    test(
      'a cloud copy stored encrypted under a .db name goes out as .sbe',
      () async {
        // With sync encryption on, a local X.db is uploaded as X.sbe while the
        // record keeps the .db name; the bytes that come back are an envelope.
        final cloud = FakeCloudStorageProvider();
        final sbe = await wrapAsSbe(writeDb('plain.db'), 'envelope.sbe');
        final upload = await cloud.uploadFile(
          await File(sbe).readAsBytes(),
          'submersion_backup_2026-10-20.sbe',
        );
        final cloudRecord = record(
          filename: 'submersion_backup_2026-10-20.db',
          cloudFileId: upload.fileId,
          location: BackupLocation.cloud,
        );

        final shared = await service(
          cloud: cloud,
        ).prepareBackupCopy(cloudRecord, purpose: BackupCopyPurpose.share);
        final saved = await service(
          cloud: cloud,
        ).prepareBackupCopy(cloudRecord, purpose: BackupCopyPurpose.save);

        expect(p.basename(shared.path), 'submersion_backup_2026-10-20.sbe');
        expect(shared.fileName, 'submersion_backup_2026-10-20.sbe');
        expect(p.basename(saved.path), startsWith('restore-'));
        expect(saved.fileName, 'submersion_backup_2026-10-20.sbe');
      },
    );

    test('a failed re-download keeps an earlier share copy', () async {
      // The receiving app may not have read the first copy yet.
      final cloud = FakeCloudStorageProvider();
      final upload = await cloud.uploadFile(
        Uint8List.fromList([4, 5, 6]),
        'submersion_backup_2026-10-20.db',
      );
      final cloudRecord = record(
        filename: 'submersion_backup_2026-10-20.db',
        cloudFileId: upload.fileId,
        location: BackupLocation.cloud,
      );
      final first = await service(
        cloud: cloud,
      ).prepareBackupCopy(cloudRecord, purpose: BackupCopyPurpose.share);

      await expectLater(
        service(
          cloud: _PartialDownloadCloud(),
        ).prepareBackupCopy(cloudRecord, purpose: BackupCopyPurpose.share),
        throwsA(isA<Exception>()),
      );

      expect(await File(first.path).readAsBytes(), [4, 5, 6]);
      expect(tempNames(), ['submersion_backup_2026-10-20.db']);
    });

    test(
      'a share copy that cannot take its name leaves nothing in temp',
      () async {
        final cloud = FakeCloudStorageProvider();
        final upload = await cloud.uploadFile(
          Uint8List.fromList([1, 2, 3]),
          'submersion_backup_2026-10-20.db',
        );
        // A folder holds the share copy's name, so the final move fails.
        Directory(
          p.join(_isolatedTempDir.path, 'submersion_backup_2026-10-20.db'),
        ).createSync();

        await expectLater(
          service(cloud: cloud).prepareBackupCopy(
            record(
              filename: 'submersion_backup_2026-10-20.db',
              cloudFileId: upload.fileId,
              location: BackupLocation.cloud,
            ),
            purpose: BackupCopyPurpose.share,
          ),
          throwsA(isA<FileSystemException>()),
        );
        expect(tempNames(), ['submersion_backup_2026-10-20.db']);
      },
    );

    test('failed cloud download leaves nothing in temp', () async {
      await expectLater(
        service(cloud: _PartialDownloadCloud()).prepareBackupCopy(
          record(cloudFileId: 'f1', location: BackupLocation.cloud),
          purpose: BackupCopyPurpose.share,
        ),
        throwsA(isA<Exception>()),
      );
      expect(tempNames(), isEmpty);
    });

    test(
      'cloud copy in another account throws BackupCopyInOtherAccountException',
      () async {
        await expectLater(
          service(
            cloud: FakeCloudStorageProvider(),
            syncAccountId: 'mine',
          ).prepareBackupCopy(
            record(
              cloudFileId: 'f1',
              cloudAccountId: 'theirs',
              location: BackupLocation.cloud,
            ),
            purpose: BackupCopyPurpose.share,
          ),
          throwsA(isA<BackupCopyInOtherAccountException>()),
        );
      },
    );

    test('missing everywhere throws BackupException', () async {
      await expectLater(
        service().prepareBackupCopy(
          record(localPath: p.join(tmp.path, 'gone.db')),
          purpose: BackupCopyPurpose.share,
        ),
        throwsA(isA<BackupException>()),
      );
    });

    test('encrypted sbe is returned byte for byte', () async {
      final sbe = await wrapAsSbe(writeDb('plain.db'), 'b.sbe');
      final before = await File(sbe).readAsBytes();

      final copy = await service().prepareBackupCopy(
        record(filename: 'b.sbe', localPath: sbe),
        purpose: BackupCopyPurpose.share,
      );

      expect(await File(copy.path).readAsBytes(), before);
    });

    test('history is unchanged after preparing a copy', () async {
      final path = writeDb('local.db');
      final cloud = FakeCloudStorageProvider();
      final upload = await cloud.uploadFile(
        Uint8List.fromList([1, 2, 3]),
        'c.db',
      );
      final svc = service(cloud: cloud);

      await svc.prepareBackupCopy(
        record(localPath: path),
        purpose: BackupCopyPurpose.save,
      );
      await svc.prepareBackupCopy(
        record(
          filename: 'c.db',
          cloudFileId: upload.fileId,
          location: BackupLocation.cloud,
        ),
        purpose: BackupCopyPurpose.share,
      );

      expect(prefs.getHistory(), isEmpty);
    });

    test('discard deletes a temp copy and never an in-place one', () async {
      final path = writeDb('local.db');
      final source = writeDb('saf_source.db');

      final inPlace = await service().prepareBackupCopy(
        record(localPath: path),
        purpose: BackupCopyPurpose.save,
      );
      final temp = await service(safPort: _SafPort(source: source))
          .prepareBackupCopy(
            record(localPath: 'content://tree/doc/1'),
            purpose: BackupCopyPurpose.save,
          );
      await inPlace.discard();
      await temp.discard();

      expect(File(path).existsSync(), isTrue);
      expect(File(temp.path).existsSync(), isFalse);
    });
  });

  group('isDeviceLockedSafetyCopy', () {
    test('true for a SQLCipher pre-update copy', () async {
      final path = await writeProtectedDb('pre.db');

      expect(
        await service().isDeviceLockedSafetyCopy(
          record(localPath: path, type: BackupType.preMigration),
        ),
        isTrue,
      );
    });

    test('true for a SQLCipher pre-downgrade copy', () async {
      final path = await writeProtectedDb('newer.db');

      expect(
        await service().isDeviceLockedSafetyCopy(
          record(localPath: path, type: BackupType.preDowngrade),
        ),
        isTrue,
      );
    });

    test('false for a plain pre-update copy', () async {
      final path = writeDb('pre.db');

      expect(
        await service().isDeviceLockedSafetyCopy(
          record(localPath: path, type: BackupType.preMigration),
        ),
        isFalse,
      );
    });

    test('false for a manual backup, whatever its header', () async {
      final path = await writeProtectedDb('manual.db');

      expect(
        await service().isDeviceLockedSafetyCopy(record(localPath: path)),
        isFalse,
      );
    });

    test('an sbe pre-update copy follows the current protection', () async {
      final sbe = await wrapAsSbe(writeDb('pre.db'), 'pre.sbe');
      final pre = record(localPath: sbe, type: BackupType.preMigration);

      expect(
        await service(keyHex: _liveKeyHex).isDeviceLockedSafetyCopy(pre),
        isTrue,
      );
      expect(await service().isDeviceLockedSafetyCopy(pre), isFalse);
    });

    test('false for a SAF or cloud-only safety copy', () async {
      expect(
        await service().isDeviceLockedSafetyCopy(
          record(
            localPath: 'content://tree/doc/1',
            type: BackupType.preMigration,
          ),
        ),
        isFalse,
      );
      expect(
        await service().isDeviceLockedSafetyCopy(
          record(
            cloudFileId: 'f1',
            location: BackupLocation.cloud,
            type: BackupType.preMigration,
          ),
        ),
        isFalse,
      );
    });
  });
}
