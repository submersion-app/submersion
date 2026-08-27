import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' show OpenMode;

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/security/database_encryption_migrator.dart';
import 'package:submersion/core/services/security/database_locked_exception.dart';
import 'package:submersion/core/services/security/database_security_sidecar.dart';
import 'package:submersion/core/services/security/database_security_service.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';

/// Proves the encryption lifecycle end to end on a real device: encrypted
/// opens, the export choreography, and the key derivation.
///
/// Host `flutter test` used to load the system SQLite with no cipher, which
/// made this the ONLY place real SQLCipher ran. That is no longer true --
/// sqlite3 3.x bundles a prebuilt SQLCipher through its build hook, so the
/// host suite links the cipher too (see sqlcipher_setup_test.dart). This
/// remains on-device coverage for the real platform storage stack.
///
/// Single testWidgets body on purpose: a second app launch in one
/// integration-test file hangs on macOS.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const testKdf = KdfParams(m: 64, t: 1, p: 1);

  testWidgets('full encryption lifecycle against real SQLCipher', (
    tester,
  ) async {
    final tmp = await Directory.systemTemp.createTemp('dbsec_integration');
    addTearDown(() => tmp.delete(recursive: true));
    final dbPath = '${tmp.path}/submersion.db';

    // 0. Cipher is linked: raw open answers cipher_version.
    final probe = DatabaseService.openRaw(
      dbPath,
      mode: OpenMode.readWriteCreate,
    );
    expect(
      probe.select('PRAGMA cipher_version'),
      isNotEmpty,
      reason: 'the sqlite3 build hook must have selected the SQLCipher build',
    );
    probe.execute('CREATE TABLE t (v TEXT)');
    probe.execute("INSERT INTO t VALUES ('dive-1')");
    probe.execute('PRAGMA user_version = 7');
    probe.close();
    expect(isEncryptedDatabaseFile(dbPath), false);

    // 1. Security + key derivation from the sidecar credential.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final svc = DatabaseSecurityService.instance;
    svc.resetForTesting();
    await svc.configure(prefs: prefs);
    await svc.enableSecurity(
      password: 'correct-horse',
      dbPath: dbPath,
      kdf: testKdf,
    );
    final mlk = await Keyslots.tryUnwrap(
      file: (await DatabaseSecuritySidecar.read(dbPath))!,
      secret: 'correct-horse',
    );
    expect(mlk, isNotNull, reason: 'password must unwrap the sidecar');
    final keyHex = await DatabaseSecurityService.deriveDbKeyHex(mlk!);

    // 2. Encrypt in place with the REAL exporter.
    await DatabaseEncryptionMigrator().encryptInPlace(
      dbPath: dbPath,
      keyHex: keyHex,
    );
    expect(isEncryptedDatabaseFile(dbPath), true);

    // 3. Keyless and wrong-key opens fail as DatabaseLockedException; the
    //    keyed open works and user_version survived the export.
    expect(
      () => DatabaseService.getStoredSchemaVersion(dbPath),
      throwsA(
        isA<DatabaseLockedException>().having(
          (e) => e.wrongKey,
          'wrongKey',
          false,
        ),
      ),
    );
    expect(
      () => DatabaseService.getStoredSchemaVersion(dbPath, keyHex: 'ff' * 32),
      throwsA(
        isA<DatabaseLockedException>().having(
          (e) => e.wrongKey,
          'wrongKey',
          true,
        ),
      ),
    );
    expect(DatabaseService.getStoredSchemaVersion(dbPath, keyHex: keyHex), 7);
    final keyed = DatabaseService.openRaw(dbPath, keyHex: keyHex);
    expect(keyed.select('SELECT v FROM t').first.values.first, 'dive-1');
    keyed.close();

    // 4. Portable backup: decrypt-export produces a plaintext file.
    final backupPath = '${tmp.path}/backup.db';
    await sqlcipherExport(
      sourcePath: dbPath,
      targetPath: backupPath,
      sourceKeyHex: keyHex,
      targetKeyHex: null,
    );
    expect(isEncryptedDatabaseFile(backupPath), false);
    expect(DatabaseService.getStoredSchemaVersion(backupPath), 7);

    // 5. Decrypt in place round-trips.
    await DatabaseEncryptionMigrator().decryptInPlace(
      dbPath: dbPath,
      keyHex: keyHex,
    );
    expect(isEncryptedDatabaseFile(dbPath), false);
    expect(DatabaseService.getStoredSchemaVersion(dbPath), 7);
    final plain = DatabaseService.openRaw(dbPath);
    expect(plain.select('SELECT v FROM t').first.values.first, 'dive-1');
    plain.close();

    svc.resetForTesting();
  });
}
