import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/security/database_encryption_migrator.dart';
import 'package:submersion/core/services/security/database_security_key_store.dart';
import 'package:submersion/core/services/security/database_security_service.dart';

import '../../../helpers/security_test_kdf.dart';
import '../../../support/fake_keychain_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late String dbPath;
  late InMemoryKeychain keychain;

  final svc = DatabaseSecurityService.instance;

  /// Re-wires the singleton against the SAME keychain and prefs, simulating
  /// an app relaunch (in-memory state gone, keychain and prefs survive).
  Future<void> relaunch() async {
    svc.resetForTesting();
    await svc.configure(
      prefs: await SharedPreferences.getInstance(),
      keyStore: DatabaseSecurityKeyStore(storage: keychain),
    );
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('dbsec_test');
    dbPath = '${tmp.path}/submersion.db';
    keychain = InMemoryKeychain();
    SharedPreferences.setMockInitialValues({});
    await relaunch();
  });

  tearDown(() async => tmp.delete(recursive: true));

  test('deriveDbKeyHex matches independently computed vector', () async {
    final mlk = SecretKey(List<int>.generate(32, (i) => i + 1));
    final hex = await DatabaseSecurityService.deriveDbKeyHex(mlk);
    expect(hex, hasLength(64));
    // Vector computed with tool/compute_db_key_vector.dart (standalone
    // cryptography-package HKDF, info 'sdb:v1:dbkey', empty salt).
    expect(
      hex,
      '60a1eecb5ba31858d0e65f584f44b73960331c449d888310a4e19e7112d34b2f',
    );
  });

  test(
    'enableSecurity creates credentials without enabling app lock',
    () async {
      final recovery = await svc.enableSecurity(
        password: 'hunter2',
        dbPath: dbPath,
        kdf: testKdf,
      );
      expect(recovery.split('-'), hasLength(8));
      expect(svc.appLockEnabled, false);
      expect(svc.isUnlocked, true);
      expect(File('${tmp.path}/submersion.keys').existsSync(), true);
    },
  );

  test('setAppLockEnabled changes only the UI gate', () async {
    await svc.enableSecurity(password: 'pw', dbPath: dbPath, kdf: testKdf);

    await svc.setAppLockEnabled(true);
    expect(svc.appLockEnabled, true);

    await svc.setAppLockEnabled(false);
    expect(svc.appLockEnabled, false);
    expect(svc.isUnlocked, true);
    expect(File('${tmp.path}/submersion.keys').existsSync(), true);
  });

  test('enableSecurity throws when a sidecar already exists', () async {
    await svc.enableSecurity(password: 'pw', dbPath: dbPath, kdf: testKdf);
    expect(
      () => svc.enableSecurity(password: 'pw2', dbPath: dbPath, kdf: testKdf),
      throwsStateError,
    );
  });

  test(
    'unlockWithSecret accepts password and recovery code, rejects junk',
    () async {
      final recovery = await svc.enableSecurity(
        password: 'hunter2',
        dbPath: dbPath,
        kdf: testKdf,
      );
      await relaunch();
      expect(await svc.unlockWithSecret('wrong', dbPath: dbPath), false);
      expect(svc.isUnlocked, false);
      expect(await svc.unlockWithSecret('hunter2', dbPath: dbPath), true);
      expect(svc.isUnlocked, true);
      await relaunch();
      expect(await svc.unlockWithSecret(recovery, dbPath: dbPath), true);
    },
  );

  test('tryLoadCachedKey restores unlock across service resets', () async {
    await svc.enableSecurity(password: 'pw', dbPath: dbPath, kdf: testKdf);
    await relaunch();
    expect(await svc.tryLoadCachedKey(), true);
    expect(svc.isUnlocked, true);
  });

  test('tryLoadCachedKey returns false with an empty keychain', () async {
    expect(await svc.tryLoadCachedKey(), false);
    expect(svc.isUnlocked, false);
  });

  test('databaseKeyHex is null until encryption is enabled', () async {
    await svc.enableSecurity(password: 'pw', dbPath: dbPath, kdf: testKdf);
    expect(svc.databaseKeyHex, isNull); // app lock only — no DB key exposed
    await svc.preferences.setDbEncryptionEnabled(true);
    await svc.refreshDerivedKey();
    expect(svc.databaseKeyHex, hasLength(64));
  });

  test('changePassword rewraps; old password stops working', () async {
    await svc.enableSecurity(password: 'old', dbPath: dbPath, kdf: testKdf);
    await svc.changePassword(
      currentSecret: 'old',
      newPassword: 'new',
      dbPath: dbPath,
      kdf: testKdf,
    );
    await relaunch();
    expect(await svc.unlockWithSecret('old', dbPath: dbPath), false);
    expect(await svc.unlockWithSecret('new', dbPath: dbPath), true);
  });

  test('regenerateRecoveryCode invalidates the old code', () async {
    final oldCode = await svc.enableSecurity(
      password: 'pw',
      dbPath: dbPath,
      kdf: testKdf,
    );
    final newCode = await svc.regenerateRecoveryCode(
      currentSecret: 'pw',
      dbPath: dbPath,
      kdf: testKdf,
    );
    expect(newCode, isNot(oldCode));
    await relaunch();
    expect(await svc.unlockWithSecret(oldCode, dbPath: dbPath), false);
    expect(await svc.unlockWithSecret(newCode, dbPath: dbPath), true);
  });

  test('disableSecurity clears everything when encryption is off', () async {
    await svc.enableSecurity(password: 'pw', dbPath: dbPath, kdf: testKdf);
    await svc.disableSecurity(dbPath: dbPath);
    expect(svc.appLockEnabled, false);
    expect(svc.isUnlocked, false);
    expect(File('${tmp.path}/submersion.keys').existsSync(), false);
    await relaunch();
    expect(await svc.tryLoadCachedKey(), false);
  });

  test('disableSecurity throws while encryption is enabled', () async {
    await svc.enableSecurity(password: 'pw', dbPath: dbPath, kdf: testKdf);
    await svc.preferences.setDbEncryptionEnabled(true);
    expect(() => svc.disableSecurity(dbPath: dbPath), throwsStateError);
  });

  group('encryption orchestration', () {
    DatabaseEncryptionMigrator fakeMigrator(List<String> calls) {
      return DatabaseEncryptionMigrator(
        exporter:
            ({
              required String sourcePath,
              required String targetPath,
              String? sourceKeyHex,
              String? targetKeyHex,
            }) async {
              calls.add('export:${targetKeyHex != null}');
              File(targetPath).writeAsStringSync('ENC');
            },
      );
    }

    test('enableEncryption: migrates, flips flag, derives key', () async {
      await svc.enableSecurity(password: 'pw', dbPath: dbPath, kdf: testKdf);
      File(dbPath).writeAsStringSync('PLAIN');
      final calls = <String>[];
      final phases = <String>[];
      await svc.enableEncryption(
        migrator: fakeMigrator(calls),
        onPhase: phases.add,
        dbPathOverride: dbPath,
        skipReopenForTesting: true,
      );
      expect(calls, ['export:true']);
      expect(svc.encryptionEnabled, true);
      expect(svc.databaseKeyHex, hasLength(64));
      expect(phases, containsAllInOrder(['backup', 'encrypt']));
      expect(File(dbPath).readAsStringSync(), 'ENC');
    });

    test('enableEncryption is a no-op when already enabled', () async {
      await svc.enableSecurity(password: 'pw', dbPath: dbPath, kdf: testKdf);
      await svc.preferences.setDbEncryptionEnabled(true);
      final calls = <String>[];
      await svc.enableEncryption(
        migrator: fakeMigrator(calls),
        dbPathOverride: dbPath,
        skipReopenForTesting: true,
      );
      expect(calls, isEmpty);
    });

    test('disableEncryption reverses and clears the derived key', () async {
      await svc.enableSecurity(password: 'pw', dbPath: dbPath, kdf: testKdf);
      await svc.setAppLockEnabled(true);
      File(dbPath).writeAsStringSync('PLAIN');
      final calls = <String>[];
      await svc.enableEncryption(
        migrator: fakeMigrator(calls),
        dbPathOverride: dbPath,
        skipReopenForTesting: true,
      );
      calls.clear();
      await svc.disableEncryption(
        migrator: fakeMigrator(calls),
        dbPathOverride: dbPath,
        skipReopenForTesting: true,
      );
      expect(calls, ['export:false']);
      expect(svc.encryptionEnabled, false);
      expect(svc.databaseKeyHex, isNull);
      expect(svc.isUnlocked, true);
      expect(File('${tmp.path}/submersion.keys').existsSync(), true);
    });

    test('disableEncryption clears credentials when no tier remains', () async {
      await svc.enableSecurity(password: 'pw', dbPath: dbPath, kdf: testKdf);
      File(dbPath).writeAsStringSync('PLAIN');
      final calls = <String>[];
      await svc.enableEncryption(
        migrator: fakeMigrator(calls),
        dbPathOverride: dbPath,
        skipReopenForTesting: true,
      );

      await svc.disableEncryption(
        migrator: fakeMigrator(calls),
        dbPathOverride: dbPath,
        skipReopenForTesting: true,
      );

      expect(svc.encryptionEnabled, false);
      expect(svc.appLockEnabled, false);
      expect(svc.isUnlocked, false);
      expect(File('${tmp.path}/submersion.keys').existsSync(), false);
    });

    test('enableEncryption throws when locked', () async {
      expect(
        () => svc.enableEncryption(
          dbPathOverride: dbPath,
          skipReopenForTesting: true,
        ),
        throwsStateError,
      );
    });
  });
}
