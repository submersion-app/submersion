import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show OpenMode, SqliteException;

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/security/database_locked_exception.dart';
import 'package:submersion/core/services/security/database_security_sidecar.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';

void main() {
  test('cipherKeyPragma formats a raw-key pragma', () {
    expect(DatabaseService.cipherKeyPragma('ab01'), 'PRAGMA key = "x\'ab01\'"');
  });

  test(
    'getStoredSchemaVersion still works keyless on a plaintext db',
    () async {
      final tmp = await Directory.systemTemp.createTemp('dbsvc_key');
      addTearDown(() => tmp.delete(recursive: true));
      final path = '${tmp.path}/plain.db';
      final db = DatabaseService.openRaw(path, mode: OpenMode.readWriteCreate);
      db.execute('PRAGMA user_version = 42');
      db.close();
      expect(DatabaseService.getStoredSchemaVersion(path), 42);
    },
  );

  /// Writes bytes that are not a plaintext SQLite header — what an encrypted
  /// database AND a corrupt plaintext database both look like.
  void writeNonSqliteHeader(String path) {
    File(
      path,
    ).writeAsBytesSync(List<int>.generate(4096, (i) => (i * 37 + 11) % 256));
  }

  test('encrypted-looking file with a corroborating sidecar throws '
      'DatabaseLockedException', () async {
    final tmp = await Directory.systemTemp.createTemp('dbsvc_key');
    addTearDown(() => tmp.delete(recursive: true));
    final path = '${tmp.path}/enc.db';
    writeNonSqliteHeader(path);
    // The sidecar is the corroboration that this install has security
    // material, so the unreadable file is encrypted rather than corrupt.
    await DatabaseSecuritySidecar.write(
      path,
      const KeyslotFile(version: 1, libraryKeyId: 'kid-1', slots: []),
    );
    expect(
      () => DatabaseService.getStoredSchemaVersion(path),
      throwsA(
        isA<DatabaseLockedException>().having(
          (e) => e.wrongKey,
          'wrongKey',
          false,
        ),
      ),
    );
  });

  test('unreadable file with a supplied key throws DatabaseLockedException '
      'with wrongKey', () async {
    final tmp = await Directory.systemTemp.createTemp('dbsvc_key');
    addTearDown(() => tmp.delete(recursive: true));
    final path = '${tmp.path}/enc.db';
    writeNonSqliteHeader(path);
    // Supplying a key IS the corroboration: we believed it was encrypted and
    // the key was rejected. No sidecar needed.
    expect(
      () => DatabaseService.getStoredSchemaVersion(path, keyHex: 'ff' * 32),
      throwsA(
        isA<DatabaseLockedException>().having(
          (e) => e.wrongKey,
          'wrongKey',
          true,
        ),
      ),
    );
  });

  test('corrupt plaintext file with no security material rethrows so the '
      'corruption-recovery flow handles it', () async {
    final tmp = await Directory.systemTemp.createTemp('dbsvc_key');
    addTearDown(() => tmp.delete(recursive: true));
    final path = '${tmp.path}/corrupt.db';
    writeNonSqliteHeader(path);
    // No sidecar, no key: a corrupt plaintext database looks identical to an
    // encrypted one at the header. Routing it to the lock screen would strand
    // the user there — no password can ever unwrap a sidecar that is absent.
    expect(
      () => DatabaseService.getStoredSchemaVersion(path),
      throwsA(
        allOf(isA<SqliteException>(), isNot(isA<DatabaseLockedException>())),
      ),
    );
  });
}
