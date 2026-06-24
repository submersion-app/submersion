import 'package:path/path.dart' as p;

import 'package:submersion/features/backup/data/services/backup_database_adapter.dart';
import 'package:submersion/features/backup/data/services/backup_saf_port.dart';

/// True iff [ref] is a SAF document/tree URI rather than a filesystem path.
/// Only Android's picker produces these, so it doubles as the platform branch:
/// non-`content://` refs always take the pre-existing filesystem path.
bool isSafRef(String ref) => ref.startsWith('content://');

/// Where a backup is written. Two implementations: a filesystem directory
/// (default sandbox, desktop, Apple bookmarked dirs) and an Android SAF tree.
abstract class BackupTarget {
  /// Writes a backup named [fileName] using [adapter] to produce the bytes.
  /// Returns the stored ref: a filesystem path or a `content://` document URI.
  Future<String> write(BackupDatabaseAdapter adapter, String fileName);
}

/// Filesystem target. Delegates to [BackupDatabaseAdapter.backup] verbatim so
/// existing behavior (and its tests) are unchanged.
class FilesystemBackupTarget implements BackupTarget {
  const FilesystemBackupTarget(this.dir);

  final String dir;

  @override
  Future<String> write(BackupDatabaseAdapter adapter, String fileName) async {
    final dest = p.join(dir, fileName);
    await adapter.backup(dest);
    return dest;
  }
}

/// Android SAF target. Streams the live DB into the persisted tree via the port.
class SafBackupTarget implements BackupTarget {
  const SafBackupTarget(this.treeUri, this.port);

  final String treeUri;
  final BackupSafPort port;

  @override
  Future<String> write(BackupDatabaseAdapter adapter, String fileName) async {
    final source = await adapter.databasePath;
    return port.writeBackup(
      treeUri: treeUri,
      fileName: fileName,
      sourcePath: source,
    );
  }
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
