import 'package:submersion_saf/submersion_saf.dart';

/// Narrow seam over [SubmersionSaf] so backup logic is unit-testable with a
/// fake (no native channel). Android-only in practice; callers gate on platform
/// by checking whether the stored location is a `content://` ref.
abstract class BackupSafPort {
  Future<String> writeBackup({
    required String treeUri,
    required String fileName,
    required String sourcePath,
  });
  Future<void> readBackup({
    required String documentUri,
    required String destPath,
  });
  Future<bool> delete(String documentUri);
  Future<bool> exists(String documentUri);
  Future<String?> resolveTree(String treeUri);
}

/// Default [BackupSafPort] that delegates to the [SubmersionSaf] platform channel.
class MethodChannelBackupSafPort implements BackupSafPort {
  const MethodChannelBackupSafPort();

  @override
  Future<String> writeBackup({
    required String treeUri,
    required String fileName,
    required String sourcePath,
  }) => SubmersionSaf.writeBackup(
    treeUri: treeUri,
    fileName: fileName,
    sourcePath: sourcePath,
  );

  @override
  Future<void> readBackup({
    required String documentUri,
    required String destPath,
  }) => SubmersionSaf.readBackup(documentUri: documentUri, destPath: destPath);

  @override
  Future<bool> delete(String documentUri) => SubmersionSaf.delete(documentUri);

  @override
  Future<bool> exists(String documentUri) => SubmersionSaf.exists(documentUri);

  @override
  Future<String?> resolveTree(String treeUri) =>
      SubmersionSaf.resolveTree(treeUri);
}
