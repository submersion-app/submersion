import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/backup/domain/exceptions/backup_failed_exception.dart';

void main() {
  group('BackupFailedException.fromError', () {
    test('classifies ENOSPC (28) as diskFull', () {
      final fse = FileSystemException(
        'copy failed',
        '/tmp/f.db',
        const OSError('No space left on device', 28),
      );
      final e = BackupFailedException.fromError(fse, StackTrace.empty);
      expect(e.cause, BackupFailureCause.diskFull);
      expect(e.userMessage, contains('disk space'));
    });

    test('classifies EACCES (13) as permissionDenied', () {
      final fse = FileSystemException(
        'open failed',
        '/tmp/f.db',
        const OSError('Permission denied', 13),
      );
      final e = BackupFailedException.fromError(fse, StackTrace.empty);
      expect(e.cause, BackupFailureCause.permissionDenied);
      expect(e.userMessage, contains('access'));
    });

    test('classifies EPERM (1) as permissionDenied', () {
      final fse = FileSystemException(
        'open failed',
        '/tmp/f.db',
        const OSError('Operation not permitted', 1),
      );
      final e = BackupFailedException.fromError(fse, StackTrace.empty);
      expect(e.cause, BackupFailureCause.permissionDenied);
    });

    test('wraps unclassified errors as unknown', () {
      final err = StateError('something odd');
      final e = BackupFailedException.fromError(err, StackTrace.empty);
      expect(e.cause, BackupFailureCause.unknown);
      expect(e.technicalDetails, contains('something odd'));
    });

    test('preserves original error in technicalDetails', () {
      final fse = FileSystemException(
        'copy failed',
        '/tmp/f.db',
        const OSError('No space left on device', 28),
      );
      final e = BackupFailedException.fromError(fse, StackTrace.empty);
      expect(e.technicalDetails, contains('No space left on device'));
    });

    test('classifies Win32 ERROR_DISK_FULL (112) as diskFull', () {
      final fse = FileSystemException(
        'copy failed',
        'C:\\Users\\x\\f.db',
        const OSError('There is not enough space on the disk.', 112),
      );
      final e = BackupFailedException.fromError(fse, StackTrace.empty);
      expect(e.cause, BackupFailureCause.diskFull);
    });

    test('classifies Win32 ERROR_HANDLE_DISK_FULL (39) as diskFull', () {
      final fse = FileSystemException(
        'copy failed',
        'C:\\Users\\x\\f.db',
        const OSError('The disk is full.', 39),
      );
      final e = BackupFailedException.fromError(fse, StackTrace.empty);
      expect(e.cause, BackupFailureCause.diskFull);
    });

    test('classifies Win32 ERROR_ACCESS_DENIED (5) as permissionDenied', () {
      final fse = FileSystemException(
        'open failed',
        'C:\\Users\\x\\f.db',
        const OSError('Access is denied.', 5),
      );
      final e = BackupFailedException.fromError(fse, StackTrace.empty);
      expect(e.cause, BackupFailureCause.permissionDenied);
    });

    test('classifies ENOENT (2) as sourceMissing on POSIX', () {
      final fse = FileSystemException(
        'open failed',
        '/tmp/f.db',
        const OSError('No such file or directory', 2),
      );
      final e = BackupFailedException.fromError(fse, StackTrace.empty);
      expect(e.cause, BackupFailureCause.sourceMissing);
    });

    test('classifies Win32 ERROR_FILE_NOT_FOUND (2) as sourceMissing', () {
      final fse = FileSystemException(
        'open failed',
        'C:\\Users\\x\\f.db',
        const OSError('The system cannot find the file specified.', 2),
      );
      final e = BackupFailedException.fromError(fse, StackTrace.empty);
      expect(e.cause, BackupFailureCause.sourceMissing);
    });

    test('classifies Win32 ERROR_PATH_NOT_FOUND (3) as sourceMissing', () {
      final fse = FileSystemException(
        'open failed',
        'C:\\Users\\x\\f.db',
        const OSError('The system cannot find the path specified.', 3),
      );
      final e = BackupFailedException.fromError(fse, StackTrace.empty);
      expect(e.cause, BackupFailureCause.sourceMissing);
    });

    test('FileSystemException with null osError falls through to unknown', () {
      final fse = FileSystemException('some error', '/tmp/f.db');
      final e = BackupFailedException.fromError(fse, StackTrace.empty);
      expect(e.cause, BackupFailureCause.unknown);
    });

    test('unknown userMessage does not embed raw error.toString()', () {
      final err = StateError('internal detail with /tmp/path/file.db');
      final e = BackupFailedException.fromError(err, StackTrace.empty);
      // User message must not leak raw error details
      expect(e.userMessage, isNot(contains('/tmp/path/file.db')));
      expect(e.userMessage, isNot(contains('internal detail')));
      // But technical details must preserve them
      expect(
        e.technicalDetails,
        contains('internal detail with /tmp/path/file.db'),
      );
    });
  });

  test('sourceMissing is constructible directly', () {
    final e = BackupFailedException(
      cause: BackupFailureCause.sourceMissing,
      userMessage: 'Dive log file not found.',
      technicalDetails: 'file /tmp/f.db does not exist',
    );
    expect(e.cause, BackupFailureCause.sourceMissing);
  });
}
