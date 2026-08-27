import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/security/database_security_sidecar.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('sidecar_test');
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  test('pathFor puts submersion.keys next to the database file', () {
    expect(
      DatabaseSecuritySidecar.pathFor('/a/b/submersion.db'),
      '/a/b/submersion.keys',
    );
  });

  test('read returns null when no sidecar exists', () async {
    final dbPath = '${tmp.path}/submersion.db';
    expect(await DatabaseSecuritySidecar.read(dbPath), isNull);
  });

  test('write then read round-trips the keyslot file', () async {
    final dbPath = '${tmp.path}/submersion.db';
    const file = KeyslotFile(version: 1, libraryKeyId: 'kid-1', slots: []);
    await DatabaseSecuritySidecar.write(dbPath, file);
    final back = await DatabaseSecuritySidecar.read(dbPath);
    expect(back, isNotNull);
    expect(back!.libraryKeyId, 'kid-1');
    expect(back.version, 1);
  });

  test('delete removes the sidecar and is a no-op when absent', () async {
    final dbPath = '${tmp.path}/submersion.db';
    const file = KeyslotFile(version: 1, libraryKeyId: 'kid-1', slots: []);
    await DatabaseSecuritySidecar.write(dbPath, file);
    await DatabaseSecuritySidecar.delete(dbPath);
    expect(await DatabaseSecuritySidecar.read(dbPath), isNull);
    await DatabaseSecuritySidecar.delete(dbPath); // must not throw
  });

  group('isEncryptedDatabaseFile', () {
    test('false for missing file', () {
      expect(isEncryptedDatabaseFile('${tmp.path}/nope.db'), false);
    });

    test('false for a plaintext SQLite header', () {
      final f = File('${tmp.path}/plain.db');
      f.writeAsBytesSync([
        ...'SQLite format 3'.codeUnits,
        0,
        ...List.filled(100, 0),
      ]);
      expect(isEncryptedDatabaseFile(f.path), false);
    });

    test('true for random (encrypted-looking) bytes', () {
      final f = File('${tmp.path}/enc.db');
      f.writeAsBytesSync(
        Uint8List.fromList(List.generate(1024, (i) => (i * 37 + 11) % 256)),
      );
      expect(isEncryptedDatabaseFile(f.path), true);
    });

    test('false for a short/empty file', () {
      final f = File('${tmp.path}/tiny.db')..writeAsBytesSync([1, 2, 3]);
      expect(isEncryptedDatabaseFile(f.path), false);
    });
  });
}
