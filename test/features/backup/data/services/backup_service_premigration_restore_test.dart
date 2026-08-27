import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/security/database_encryption_migrator.dart';
import 'package:submersion/core/services/security/database_security_sidecar.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';

/// The live-database key an encrypted install would hold in memory.
const _liveKeyHex =
    '4a5f1c9d3e8b0726114d90ab63fe2d58c7093a41bb5e6f28d0c1a7935e4b8206';

/// Fake adapter that reports a live SQLCipher key, mirroring an install with
/// database password protection enabled.
class _FakeBackupDatabaseAdapter implements BackupDatabaseAdapter {
  _FakeBackupDatabaseAdapter({this.databaseKeyHex});

  @override
  final String? databaseKeyHex;

  String? lastRestorePath;
  int restoreCallCount = 0;

  @override
  Future<void> backup(String destinationPath) async {
    final file = File(destinationPath);
    await file.parent.create(recursive: true);
    await file.writeAsString('fake backup data');
  }

  @override
  Future<void> restore(
    String backupPath, {
    void Function(int, int)? onMigrationProgress,
  }) async {
    restoreCallCount++;
    lastRestorePath = backupPath;
  }

  @override
  Future<String> get databasePath async => '/fake/db/path';

  @override
  AppDatabase get database =>
      throw UnimplementedError('Fake database does not support direct queries');
}

class _SpySyncRepository extends SyncRepository {
  @override
  Future<String> getDeviceId() async => 'live-device-id';

  @override
  Future<String?> getLastAcceptedEpochId() async => null;

  @override
  Future<void> rebaselineAfterRestore({
    String? preserveDeviceId,
    String? preserveEpochId,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late BackupPreferences preferences;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async => Directory.systemTemp.path,
        );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = BackupPreferences(await SharedPreferences.getInstance());
    tempDir = await Directory.systemTemp.createTemp('premigration_restore_');
  });

  tearDown(() => tempDir.delete(recursive: true));

  /// Writes a Submersion-shaped database at [name] and encrypts it in place
  /// with [_liveKeyHex]: byte-for-byte what `PreMigrationBackupService`
  /// copies on an install with database protection enabled.
  Future<String> writeEncryptedPreMigrationCopy(String name) async {
    final path = '${tempDir.path}/$name';
    final db = sqlite3.sqlite3.open(path);
    db.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
    db.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
    db.execute("INSERT INTO dives VALUES ('dive-1')");
    db.execute('PRAGMA user_version = 63');
    db.close();

    await DatabaseEncryptionMigrator().encryptInPlace(
      dbPath: path,
      keyHex: _liveKeyHex,
    );
    return path;
  }

  BackupRecord recordFor(String path, BackupType type) => BackupRecord(
    id: 'record-1',
    filename: path.split(Platform.pathSeparator).last,
    timestamp: DateTime.utc(2026, 4, 12),
    sizeBytes: File(path).lengthSync(),
    location: BackupLocation.local,
    localPath: path,
    isAutomatic: true,
    type: type,
    fromSchemaVersion: 63,
    toSchemaVersion: 64,
  );

  test('the fixture really is SQLCipher ciphertext', () async {
    final path = await writeEncryptedPreMigrationCopy('enc.db');
    expect(isEncryptedDatabaseFile(path), isTrue);
  });

  group('validateBackupFile', () {
    test('rejects a SQLCipher-encrypted .db by default', () async {
      final path = await writeEncryptedPreMigrationCopy('enc.db');
      final service = BackupService(
        dbAdapter: _FakeBackupDatabaseAdapter(databaseKeyHex: _liveKeyHex),
        preferences: preferences,
      );

      final result = await service.validateBackupFile(path);

      expect(result.isValid, isFalse);
    });

    test('accepts a SQLCipher-encrypted .db when live encryption is '
        'allowed and the live key opens it', () async {
      final path = await writeEncryptedPreMigrationCopy('enc.db');
      final service = BackupService(
        dbAdapter: _FakeBackupDatabaseAdapter(databaseKeyHex: _liveKeyHex),
        preferences: preferences,
      );

      final result = await service.validateBackupFile(
        path,
        allowLiveDatabaseEncryption: true,
      );

      expect(result.isValid, isTrue, reason: result.error);
      expect(result.sizeBytes, greaterThan(0));
    });

    test(
      'rejects an encrypted copy when the install holds no live key',
      () async {
        final path = await writeEncryptedPreMigrationCopy('enc.db');
        final service = BackupService(
          dbAdapter: _FakeBackupDatabaseAdapter(),
          preferences: preferences,
        );

        final result = await service.validateBackupFile(
          path,
          allowLiveDatabaseEncryption: true,
        );

        expect(result.isValid, isFalse);
        expect(result.error, contains('protected'));
      },
    );

    test('names corruption as well as encryption when there is no key to tell '
        'them apart', () async {
      // A corrupt plaintext copy and a SQLCipher one are identical at the
      // header, and the keyslot sidecar that would corroborate "encrypted"
      // lives next to the LIVE database, never in the backups directory.
      // With no key to settle it, the report must not assert either story.
      final path = '${tempDir.path}/corrupt.db';
      await File(path).writeAsString('this is not a sqlite database');
      final service = BackupService(
        dbAdapter: _FakeBackupDatabaseAdapter(),
        preferences: preferences,
      );

      final result = await service.validateBackupFile(
        path,
        allowLiveDatabaseEncryption: true,
      );

      expect(result.isValid, isFalse);
      expect(result.error, contains('corrupt'));
      expect(result.error, contains('protected'));
    });

    test(
      'rejects an encrypted copy when the live key is the wrong one',
      () async {
        final path = await writeEncryptedPreMigrationCopy('enc.db');
        final service = BackupService(
          dbAdapter: _FakeBackupDatabaseAdapter(databaseKeyHex: 'ff' * 32),
          preferences: preferences,
        );

        final result = await service.validateBackupFile(
          path,
          allowLiveDatabaseEncryption: true,
        );

        expect(result.isValid, isFalse);
      },
    );

    test(
      'still rejects a corrupt plaintext .db when live encryption is allowed',
      () async {
        final path = '${tempDir.path}/corrupt.db';
        await File(path).writeAsString('this is not a sqlite database');
        final service = BackupService(
          dbAdapter: _FakeBackupDatabaseAdapter(databaseKeyHex: _liveKeyHex),
          preferences: preferences,
        );

        final result = await service.validateBackupFile(
          path,
          allowLiveDatabaseEncryption: true,
        );

        expect(result.isValid, isFalse);
      },
    );
  });

  group('restoreFromBackup', () {
    test('restores an encrypted pre-migration backup', () async {
      final path = await writeEncryptedPreMigrationCopy('enc.db');
      final adapter = _FakeBackupDatabaseAdapter(databaseKeyHex: _liveKeyHex);
      final service = BackupService(
        dbAdapter: adapter,
        preferences: preferences,
        syncRepository: _SpySyncRepository(),
      );

      await service.restoreFromBackup(recordFor(path, BackupType.preMigration));

      expect(adapter.restoreCallCount, 1);
      expect(adapter.lastRestorePath, path);
    });

    test(
      'still rejects an encrypted artifact offered as a manual backup',
      () async {
        final path = await writeEncryptedPreMigrationCopy('enc.db');
        final adapter = _FakeBackupDatabaseAdapter(databaseKeyHex: _liveKeyHex);
        final service = BackupService(
          dbAdapter: adapter,
          preferences: preferences,
          syncRepository: _SpySyncRepository(),
        );

        await expectLater(
          service.restoreFromBackup(recordFor(path, BackupType.manual)),
          throwsA(isA<BackupException>()),
        );
        expect(adapter.restoreCallCount, 0);
      },
    );
  });
}
