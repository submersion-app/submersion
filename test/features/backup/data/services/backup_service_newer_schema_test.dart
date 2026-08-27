import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/crypto/encryption_key_store.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/sync_preferences.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_crypto.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';

import '../../../../support/fake_keychain_storage.dart';

const _fastKdf = KdfParams(m: 1024, t: 3, p: 1);
const _passphrase = 'correct horse battery staple';

class _FakeBackupDatabaseAdapter implements BackupDatabaseAdapter {
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
  }

  @override
  Future<String> get databasePath async => '/fake/db/path';

  @override
  AppDatabase get database =>
      throw UnimplementedError('Fake database does not support direct queries');

  @override
  String? get databaseKeyHex => null;
}

/// Restoring a backup written by a NEWER schema must be refused BEFORE the
/// database swap. The post-swap open guard would otherwise fire with the new
/// file already live, leaving the app with no working database (issue #1089).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late BackupPreferences preferences;
  late SyncPreferences syncPreferences;
  late EncryptionKeyStore keyStore;
  late _FakeBackupDatabaseAdapter adapter;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async => Directory.systemTemp.path,
        );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    preferences = BackupPreferences(prefs);
    syncPreferences = SyncPreferences(prefs);
    keyStore = EncryptionKeyStore(storage: InMemoryKeychain());
    adapter = _FakeBackupDatabaseAdapter();
    tempDir = await Directory.systemTemp.createTemp('newer_schema_');
  });

  tearDown(() => tempDir.delete(recursive: true));

  BackupService buildService() => BackupService(
    dbAdapter: adapter,
    preferences: preferences,
    encryptionKeyStore: keyStore,
    syncPreferences: syncPreferences,
  );

  /// A plaintext SQLite file that passes every existing deep-validation check
  /// (real SQLite, carries the expected Submersion tables) but declares
  /// [userVersion] as its schema.
  String craftDbFile(String name, int userVersion) {
    final path = '${tempDir.path}/$name';
    final db = sqlite3.sqlite3.open(path);
    db.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
    db.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
    db.execute("INSERT INTO dives VALUES ('dive-1')");
    db.execute('PRAGMA user_version = $userVersion');
    db.close();
    return path;
  }

  group('validateBackupFile', () {
    test('rejects a newer-schema backup', () async {
      final path = craftDbFile(
        'newer.db',
        AppDatabase.currentSchemaVersion + 1,
      );

      final result = await buildService().validateBackupFile(path);

      expect(result.isValid, isFalse);
      expect(result.error, contains('newer version of Submersion'));
    });

    test('accepts an equal-schema backup', () async {
      final path = craftDbFile('equal.db', AppDatabase.currentSchemaVersion);

      final result = await buildService().validateBackupFile(path);

      expect(result.isValid, isTrue, reason: result.error);
    });

    test('accepts an older-schema backup (the migration ladder handles it '
        'at restore)', () async {
      final path = craftDbFile(
        'older.db',
        AppDatabase.currentSchemaVersion - 1,
      );

      final result = await buildService().validateBackupFile(path);

      expect(result.isValid, isTrue, reason: result.error);
    });
  });

  group('restoreFromFile', () {
    test('refuses a newer-schema backup before any side effects', () async {
      final path = craftDbFile(
        'newer.db',
        AppDatabase.currentSchemaVersion + 1,
      );

      await expectLater(
        buildService().restoreFromFile(path),
        throwsA(isA<BackupNewerSchemaException>()),
      );
      expect(
        adapter.restoreCallCount,
        0,
        reason: 'the database swap must never have started',
      );
    });

    test('restores an older-schema backup normally (control)', () async {
      final path = craftDbFile(
        'older.db',
        AppDatabase.currentSchemaVersion - 1,
      );

      await buildService().restoreFromFile(path);

      expect(adapter.restoreCallCount, 1);
    });

    test('refuses an ENCRYPTED newer-schema backup after decrypting, before '
        'any side effects', () async {
      // Proves the check reads the MATERIALIZED PLAINTEXT: the ciphertext
      // has no readable user_version, so a check placed before decryption
      // would wave this through.
      final mlk = SecretKey(List<int>.generate(32, (i) => (i * 3 + 1) % 256));
      const keyId = '8f14e45f-ceea-467f-ab37-a10a8d5f4c11';
      final keyslots = KeyslotFile(
        version: 1,
        libraryKeyId: keyId,
        slots: [
          await Keyslots.createSlot(
            type: 'passphrase',
            secret: _passphrase,
            mlk: mlk,
            kdf: _fastKdf,
          ),
        ],
      );
      await keyStore.saveKey(
        libraryKeyId: keyId,
        mlkBytes: await mlk.extractBytes(),
      );
      await keyStore.saveKeyslotMirror(keyslots.toJsonBytes());
      await syncPreferences.setSyncEncryptionEnabled(true);

      final plain = craftDbFile(
        'newer_plain.db',
        AppDatabase.currentSchemaVersion + 1,
      );
      final encrypted = '${tempDir.path}/newer.sbe';
      await BackupCrypto.encryptFile(
        inPath: plain,
        outPath: encrypted,
        mlk: mlk,
        libraryKeyId: keyId,
        keyslotBytes: Uint8List.fromList(keyslots.toJsonBytes()),
      );

      await expectLater(
        buildService().restoreFromFile(
          encrypted,
          encryptionSecret: _passphrase,
        ),
        throwsA(isA<BackupNewerSchemaException>()),
      );
      expect(adapter.restoreCallCount, 0);
    });
  });
}
