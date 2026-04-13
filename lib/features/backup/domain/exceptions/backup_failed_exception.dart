import 'dart:io';

enum BackupFailureCause {
  diskFull,
  permissionDenied,
  sourceMissing,
  renameFailed,
  unknown,
}

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
    if (error is FileSystemException) {
      final code = error.osError?.errorCode;
      switch (code) {
        case 28: // ENOSPC
          return BackupFailedException(
            cause: BackupFailureCause.diskFull,
            userMessage: 'Not enough free disk space to back up your data.',
            technicalDetails: '${error.toString()}\n$stack',
          );
        case 13: // EACCES
        case 1: // EPERM
          return BackupFailedException(
            cause: BackupFailureCause.permissionDenied,
            userMessage: 'The app could not access the backup folder.',
            technicalDetails: '${error.toString()}\n$stack',
          );
      }
    }
    return BackupFailedException(
      cause: BackupFailureCause.unknown,
      userMessage: 'Backup failed: ${error.toString()}',
      technicalDetails: '${error.toString()}\n$stack',
    );
  }

  @override
  String toString() => 'BackupFailedException($cause): $userMessage';
}
