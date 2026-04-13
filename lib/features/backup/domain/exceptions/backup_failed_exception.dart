import 'dart:io';

enum BackupFailureCause { diskFull, permissionDenied, sourceMissing, unknown }

/// Thrown by PreMigrationBackupService when a backup cannot be completed.
///
/// Always carries a user-facing message safe to display, plus raw technical
/// details (stack, error.toString) for support escalation.
class BackupFailedException implements Exception {
  final BackupFailureCause cause;
  final String userMessage;
  final String technicalDetails;

  const BackupFailedException({
    required this.cause,
    required this.userMessage,
    required this.technicalDetails,
  });

  factory BackupFailedException.fromError(Object error, StackTrace stack) {
    final details = _formatDetails(error, stack);
    if (error is FileSystemException) {
      final code = error.osError?.errorCode;
      final classified = _classifyFileSystemCode(code);
      if (classified != null) {
        return BackupFailedException(
          cause: classified.$1,
          userMessage: classified.$2,
          technicalDetails: details,
        );
      }
    }
    return BackupFailedException(
      cause: BackupFailureCause.unknown,
      userMessage:
          'An unexpected error occurred while backing up your data. '
          'Open Technical details below and share them with support if '
          'the problem persists.',
      technicalDetails: details,
    );
  }

  static (BackupFailureCause, String)? _classifyFileSystemCode(int? code) {
    if (code == null) return null;
    switch (code) {
      // POSIX ENOSPC + Win32 ERROR_DISK_FULL / ERROR_HANDLE_DISK_FULL
      case 28:
      case 112:
      case 39:
        return (
          BackupFailureCause.diskFull,
          'Not enough free disk space to back up your data.',
        );
      // POSIX EACCES, EPERM + Win32 ERROR_ACCESS_DENIED
      case 13:
      case 1:
      case 5:
        return (
          BackupFailureCause.permissionDenied,
          'The app could not access the backup folder.',
        );
      // POSIX ENOENT + Win32 ERROR_FILE_NOT_FOUND / ERROR_PATH_NOT_FOUND
      case 2:
      case 3:
        return (
          BackupFailureCause.sourceMissing,
          'The dive log file could not be found.',
        );
    }
    return null;
  }

  static String _formatDetails(Object error, StackTrace stack) =>
      '${error.toString()}\n$stack';

  @override
  String toString() => 'BackupFailedException($cause): $userMessage';
}
