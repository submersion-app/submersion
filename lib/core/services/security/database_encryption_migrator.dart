import 'dart:io';

import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/database/sqlcipher_setup.dart';

typedef SqlcipherExporter =
    Future<void> Function({
      required String sourcePath,
      required String targetPath,
      String? sourceKeyHex,
      String? targetKeyHex,
    });

/// Real exporter: SQLCipher's canonical re-key path. Opens the source raw,
/// ATTACHes the target with the new key ('' = plaintext), copies everything
/// with sqlcipher_export, and carries user_version over explicitly —
/// sqlcipher_export does NOT copy it.
///
/// Opens sqlite3 directly (not via DatabaseService.openRaw) so this file has
/// no import of database_service.dart — DatabaseService imports the migrator
/// for restore re-encryption, and the import must stay one-way.
Future<void> sqlcipherExport({
  required String sourcePath,
  required String targetPath,
  String? sourceKeyHex,
  String? targetKeyHex,
}) async {
  // readWriteCreate (the default), unlike the sibling export in
  // database_snapshot.dart, which deliberately drops the create flag. A
  // connection's open flags apply to every database it ATTACHes, so without
  // create the ATTACH below cannot bring the target file into existence and
  // the export fails before it starts.
  final db = sqlite3.sqlite3.open(sourcePath);
  try {
    if (sourceKeyHex != null) {
      db.execute(cipherKeyPragma(sourceKeyHex));
    }
    // Path is single-quote escaped; the key is an inline literal because a
    // bound parameter would be treated as a text passphrase, not a raw key.
    final escapedPath = targetPath.replaceAll("'", "''");
    final keyLiteral = targetKeyHex == null ? "''" : '"x\'$targetKeyHex\'"';
    db.execute("ATTACH DATABASE '$escapedPath' AS target KEY $keyLiteral");
    db.execute("SELECT sqlcipher_export('target')");
    final v = db.select('PRAGMA user_version').first.values.first as int;
    db.execute('PRAGMA target.user_version = $v');
    db.execute('DETACH DATABASE target');
  } finally {
    db.close();
  }
}

/// Re-encrypts the database file in place via export-to-staging plus an
/// atomic-rename swap (same choreography as DatabaseService.restore). The
/// database must be CLOSED (strict) before calling either method.
///
/// Crash safety: the WAL/SHM sidecars are deleted only after the export
/// succeeded and the original has been renamed aside, so an interrupted run
/// leaves either the untouched original or the fully-swapped result — the
/// startup header probe reconciles the prefs flag with whichever state the
/// file actually landed in.
class DatabaseEncryptionMigrator {
  final SqlcipherExporter exporter;

  DatabaseEncryptionMigrator({this.exporter = sqlcipherExport});

  Future<void> encryptInPlace({
    required String dbPath,
    required String keyHex,
  }) => _reencrypt(dbPath: dbPath, sourceKeyHex: null, targetKeyHex: keyHex);

  Future<void> decryptInPlace({
    required String dbPath,
    required String keyHex,
  }) => _reencrypt(dbPath: dbPath, sourceKeyHex: keyHex, targetKeyHex: null);

  Future<void> _reencrypt({
    required String dbPath,
    required String? sourceKeyHex,
    required String? targetKeyHex,
  }) async {
    final stagingPath = '$dbPath.reencrypt-staging';
    final asidePath = '$dbPath.pre-reencrypt';
    await _deleteIfExists(stagingPath);

    try {
      await exporter(
        sourcePath: dbPath,
        targetPath: stagingPath,
        sourceKeyHex: sourceKeyHex,
        targetKeyHex: targetKeyHex,
      );
    } catch (_) {
      await _deleteIfExists(stagingPath);
      rethrow;
    }

    // Swap: original aside (never deleted first), WAL/SHM dropped (they
    // belong to the pre-swap file and would corrupt the new one), staging in.
    await _deleteIfExists(asidePath);
    final dbFile = File(dbPath);
    try {
      await dbFile.rename(asidePath);
      await _deleteIfExists('$dbPath-wal');
      await _deleteIfExists('$dbPath-shm');
      await File(stagingPath).rename(dbPath);
    } catch (_) {
      if (!await dbFile.exists() && await File(asidePath).exists()) {
        await File(asidePath).rename(dbPath);
      }
      await _deleteIfExists(stagingPath);
      rethrow;
    }

    // Success: drop the aside best-effort (a stranded copy is harmless and
    // gets swept by the next re-encryption at this path).
    try {
      await _deleteIfExists(asidePath);
    } catch (_) {}
  }

  Future<void> _deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
