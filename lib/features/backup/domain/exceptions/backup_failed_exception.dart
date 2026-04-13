import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;

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

  /// [debugIsWindows] is a test seam: pass `true` to run the classifier
  /// against Win32 error codes without relying on the host platform.
  /// Production callers should leave it null so `Platform.isWindows` is used.
  factory BackupFailedException.fromError(
    Object error,
    StackTrace stack, {
    @visibleForTesting bool? debugIsWindows,
  }) {
    final details = _formatDetails(error, stack);
    if (error is FileSystemException) {
      final code = error.osError?.errorCode;
      final classified = _classifyFileSystemCode(
        code,
        isWindows: debugIsWindows ?? Platform.isWindows,
      );
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

  /// Maps an [OSError.errorCode] to a [BackupFailureCause] + user message.
  ///
  /// Win32 and POSIX errno spaces overlap (e.g. POSIX `EIO=5` vs Win32
  /// `ERROR_ACCESS_DENIED=5`), so the caller must indicate which namespace
  /// the code came from. Unknown codes return `null` so the caller can fall
  /// back to the generic `unknown` cause.
  static (BackupFailureCause, String)? _classifyFileSystemCode(
    int? code, {
    required bool isWindows,
  }) {
    if (code == null) return null;
    const diskFull = (
      BackupFailureCause.diskFull,
      'Not enough free disk space to back up your data.',
    );
    const permissionDenied = (
      BackupFailureCause.permissionDenied,
      'The app could not access the backup folder.',
    );
    const sourceMissing = (
      BackupFailureCause.sourceMissing,
      'The dive log file could not be found.',
    );

    if (isWindows) {
      switch (code) {
        case 112: // ERROR_DISK_FULL
        case 39: // ERROR_HANDLE_DISK_FULL
          return diskFull;
        case 5: // ERROR_ACCESS_DENIED
          return permissionDenied;
        case 2: // ERROR_FILE_NOT_FOUND
        case 3: // ERROR_PATH_NOT_FOUND
          return sourceMissing;
      }
      return null;
    }
    switch (code) {
      case 28: // ENOSPC
        return diskFull;
      case 1: // EPERM
      case 13: // EACCES
        return permissionDenied;
      case 2: // ENOENT
        return sourceMissing;
    }
    return null;
  }

  static String _formatDetails(Object error, StackTrace stack) =>
      '${error.toString()}\n$stack';

  @override
  String toString() => 'BackupFailedException($cause): $userMessage';
}
