import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/sync/changeset_log/sync_temp_dir.dart';
import 'package:submersion/features/backup/data/services/backup_database_adapter.dart';
import 'package:submersion/features/backup/data/services/backup_saf_port.dart';

/// True iff [ref] is a SAF document/tree URI rather than a filesystem path.
/// Only Android's picker produces these, so it doubles as the platform branch:
/// non-`content://` refs always take the pre-existing filesystem path.
bool isSafRef(String ref) => ref.startsWith('content://');

/// Where a written backup landed and how big it turned out.
///
/// The size travels with the ref because a SAF ref is a `content://` URI with
/// no `File.length()` to ask, and the artifact's size cannot be inferred from
/// the live database file: the export is compacted and folds in rows that were
/// still in the WAL.
class BackupWriteResult {
  const BackupWriteResult(this.ref, this.sizeBytes);

  /// A filesystem path or a `content://` document URI.
  final String ref;
  final int sizeBytes;
}

/// Where a backup is written. Two implementations: a filesystem directory
/// (default sandbox, desktop, Apple bookmarked dirs) and an Android SAF tree.
abstract class BackupTarget {
  /// Writes a backup named [fileName] using [adapter] to produce the bytes.
  Future<BackupWriteResult> write(
    BackupDatabaseAdapter adapter,
    String fileName,
  );

  /// Writes an already-materialized file at [sourcePath] into the target as
  /// [fileName] (e.g. an encrypted `.sbe` produced off to the side). Returns
  /// the stored ref: a filesystem path or a `content://` document URI.
  Future<String> writeSource(String sourcePath, String fileName);
}

/// Filesystem target. Delegates to [BackupDatabaseAdapter.backup] verbatim so
/// existing behavior (and its tests) are unchanged.
class FilesystemBackupTarget implements BackupTarget {
  const FilesystemBackupTarget(this.dir);

  final String dir;

  @override
  Future<BackupWriteResult> write(
    BackupDatabaseAdapter adapter,
    String fileName,
  ) async {
    final dest = p.join(dir, fileName);
    await adapter.backup(dest);
    return BackupWriteResult(dest, await File(dest).length());
  }

  @override
  Future<String> writeSource(String sourcePath, String fileName) async {
    final dest = p.join(dir, fileName);
    await File(sourcePath).copy(dest);
    return dest;
  }
}

/// Android SAF target. Streams a backup into the persisted tree via the port.
class SafBackupTarget implements BackupTarget {
  const SafBackupTarget(this.treeUri, this.port, {this.tempDir});

  final String treeUri;
  final BackupSafPort port;

  /// Where the export is staged before being streamed out. Injectable for
  /// tests; defaults to the shared sync temp dir.
  final Future<Directory> Function()? tempDir;

  /// Exports the database to a staging file first, then streams THAT.
  ///
  /// The port can only stream a filesystem path, so handing it the live
  /// database path was the obvious shape -- and wrong twice over. It streams
  /// `<db>` alone, which under WAL omits every committed row still in the
  /// sidecar; and when database password protection is on it writes SQLCipher
  /// ciphertext into an artifact that is portable plaintext by contract.
  /// Going through [BackupDatabaseAdapter.backup] gets both right, at the cost
  /// of one temporary copy.
  @override
  Future<BackupWriteResult> write(
    BackupDatabaseAdapter adapter,
    String fileName,
  ) async {
    final dir = await (tempDir?.call() ?? resolveSyncTempDir());
    // Per-invocation prefix so a foreground backup and the scheduled
    // background one cannot collide on the shared temp dir.
    final staged = p.join(dir.path, '${const Uuid().v4()}-$fileName');
    try {
      await adapter.backup(staged);
      final sizeBytes = await File(staged).length();
      final ref = await port.writeBackup(
        treeUri: treeUri,
        fileName: fileName,
        sourcePath: staged,
      );
      return BackupWriteResult(ref, sizeBytes);
    } finally {
      // Never leave a plaintext copy of the whole library in the temp dir,
      // including when the stream above threw.
      final file = File(staged);
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {
        // Best-effort: a stranded temp file is swept by the next run.
      }
    }
  }

  @override
  Future<String> writeSource(String sourcePath, String fileName) =>
      port.writeBackup(
        treeUri: treeUri,
        fileName: fileName,
        sourcePath: sourcePath,
      );
}

/// A resolved target plus a release callback. The callback arms/releases Apple
/// security-scoped access for filesystem targets; it is a no-op for SAF and the
/// default location.
class BackupTargetLease {
  const BackupTargetLease(this.target, this._release);

  final BackupTarget target;
  final Future<void> Function() _release;

  Future<void> release() => _release();
}
