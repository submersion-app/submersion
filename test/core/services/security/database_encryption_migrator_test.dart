import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/security/database_encryption_migrator.dart';

void main() {
  late Directory tmp;
  late String dbPath;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('migrator_test');
    dbPath = '${tmp.path}/submersion.db';
    File(dbPath).writeAsStringSync('ORIGINAL');
    File('$dbPath-wal').writeAsStringSync('WAL');
    File('$dbPath-shm').writeAsStringSync('SHM');
  });

  tearDown(() => tmp.delete(recursive: true));

  Future<void> fakeExporter({
    required String sourcePath,
    required String targetPath,
    String? sourceKeyHex,
    String? targetKeyHex,
  }) async {
    File(targetPath).writeAsStringSync('EXPORTED:${targetKeyHex ?? "plain"}');
  }

  test(
    'encryptInPlace swaps the exported file in and cleans sidecars',
    () async {
      final migrator = DatabaseEncryptionMigrator(exporter: fakeExporter);
      await migrator.encryptInPlace(dbPath: dbPath, keyHex: 'aa');
      expect(File(dbPath).readAsStringSync(), 'EXPORTED:aa');
      expect(File('$dbPath-wal').existsSync(), false);
      expect(File('$dbPath-shm').existsSync(), false);
      expect(File('$dbPath.reencrypt-staging').existsSync(), false);
      expect(File('$dbPath.pre-reencrypt').existsSync(), false);
    },
  );

  test('failure during export leaves the original untouched', () async {
    Future<void> failingExporter({
      required String sourcePath,
      required String targetPath,
      String? sourceKeyHex,
      String? targetKeyHex,
    }) async {
      throw StateError('boom');
    }

    final migrator = DatabaseEncryptionMigrator(exporter: failingExporter);
    await expectLater(
      migrator.encryptInPlace(dbPath: dbPath, keyHex: 'aa'),
      throwsStateError,
    );
    expect(File(dbPath).readAsStringSync(), 'ORIGINAL');
    expect(File('$dbPath-wal').existsSync(), true);
    expect(File('$dbPath.reencrypt-staging').existsSync(), false);
  });

  test('decryptInPlace produces a plaintext-target export', () async {
    final migrator = DatabaseEncryptionMigrator(exporter: fakeExporter);
    await migrator.decryptInPlace(dbPath: dbPath, keyHex: 'aa');
    expect(File(dbPath).readAsStringSync(), 'EXPORTED:plain');
  });
}
