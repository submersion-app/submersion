import 'package:submersion/core/services/database_service.dart';

/// Reads `PRAGMA user_version` from a backup file on disk.
typedef SchemaVersionReader = int? Function(String path, {String? keyHex});

int? _read(String path, {String? keyHex}) =>
    DatabaseService.getStoredSchemaVersion(path, keyHex: keyHex);

/// The schema version a backup file actually holds, or null when the file
/// cannot be opened at all.
///
/// Used to check a candidate before the schema-mismatch screen offers it: the
/// registry records what a copy CLAIMED to hold, and only opening the copy
/// proves the claim (issue #1589).
///
/// Tries [keyHex] first. A pre-migration copy of a protected database is
/// SQLCipher ciphertext, and the security gate has already run by the time a
/// mismatch is raised, so the key is available. The keyless retry covers the
/// install that turned protection ON after that copy was taken, where the
/// file on disk is still plaintext; it is pointless when there was no key to
/// fail with, so it is skipped in that case.
///
/// [DatabaseService.getStoredSchemaVersion] opens read-WRITE, which is what
/// lets SQLite roll back a hot journal, but also means a copy in a read-only
/// location cannot be probed. Every candidate reaching here was written by
/// this app into its own resolved backups directory, so that is not the
/// normal case; when it does happen the failure lands on the safe side and no
/// restore is offered rather than one that cannot run.
///
/// Never throws. A file that will not open is reported as null, which every
/// caller treats as "do not offer this".
int? probeBackupSchemaVersion(
  String path, {
  required String? keyHex,
  SchemaVersionReader read = _read,
  void Function(String message)? onDiagnostic,
}) {
  try {
    return read(path, keyHex: keyHex);
  } catch (e) {
    onDiagnostic?.call('Candidate backup did not open with the live key: $e');
  }
  if (keyHex == null) return null;
  try {
    return read(path);
  } catch (e) {
    onDiagnostic?.call('Candidate backup did not open unkeyed either: $e');
    return null;
  }
}
