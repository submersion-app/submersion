import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/backup/domain/exceptions/backup_failed_exception.dart';

void main() {
  group('BackupFailedException.fromError', () {
    test('classifies ENOSPC (28) as diskFull', () {
      const fse = FileSystemException(
        'copy failed',
        '/tmp/f.db',
        OSError('No space left on device', 28),
      );
      final e = BackupFailedException.fromError(
        fse,
        StackTrace.empty,
        debugIsWindows: false,
      );
      expect(e.cause, BackupFailureCause.diskFull);
      expect(e.userMessage, contains('disk space'));
    });

    test('classifies EACCES (13) as permissionDenied', () {
      const fse = FileSystemException(
        'open failed',
        '/tmp/f.db',
        OSError('Permission denied', 13),
      );
      final e = BackupFailedException.fromError(
        fse,
        StackTrace.empty,
        debugIsWindows: false,
      );
      expect(e.cause, BackupFailureCause.permissionDenied);
      expect(e.userMessage, contains('access'));
    });

    test('classifies EPERM (1) as permissionDenied', () {
      const fse = FileSystemException(
        'open failed',
        '/tmp/f.db',
        OSError('Operation not permitted', 1),
      );
      final e = BackupFailedException.fromError(
        fse,
        StackTrace.empty,
        debugIsWindows: false,
      );
      expect(e.cause, BackupFailureCause.permissionDenied);
    });

    test('wraps unclassified errors as unknown', () {
      final err = StateError('something odd');
      final e = BackupFailedException.fromError(err, StackTrace.empty);
      expect(e.cause, BackupFailureCause.unknown);
      expect(e.technicalDetails, contains('something odd'));
    });

    test('preserves original error in technicalDetails', () {
      const fse = FileSystemException(
        'copy failed',
        '/tmp/f.db',
        OSError('No space left on device', 28),
      );
      final e = BackupFailedException.fromError(
        fse,
        StackTrace.empty,
        debugIsWindows: false,
      );
      expect(e.technicalDetails, contains('No space left on device'));
    });

    test('classifies Win32 ERROR_DISK_FULL (112) as diskFull', () {
      const fse = FileSystemException(
        'copy failed',
        'C:\\Users\\x\\f.db',
        OSError('There is not enough space on the disk.', 112),
      );
      final e = BackupFailedException.fromError(
        fse,
        StackTrace.empty,
        debugIsWindows: true,
      );
      expect(e.cause, BackupFailureCause.diskFull);
    });

    test('classifies Win32 ERROR_HANDLE_DISK_FULL (39) as diskFull', () {
      const fse = FileSystemException(
        'copy failed',
        'C:\\Users\\x\\f.db',
        OSError('The disk is full.', 39),
      );
      final e = BackupFailedException.fromError(
        fse,
        StackTrace.empty,
        debugIsWindows: true,
      );
      expect(e.cause, BackupFailureCause.diskFull);
    });

    test('classifies Win32 ERROR_ACCESS_DENIED (5) as permissionDenied', () {
      const fse = FileSystemException(
        'open failed',
        'C:\\Users\\x\\f.db',
        OSError('Access is denied.', 5),
      );
      final e = BackupFailedException.fromError(
        fse,
        StackTrace.empty,
        debugIsWindows: true,
      );
      expect(e.cause, BackupFailureCause.permissionDenied);
    });

    test('classifies ENOENT (2) as sourceMissing on POSIX', () {
      const fse = FileSystemException(
        'open failed',
        '/tmp/f.db',
        OSError('No such file or directory', 2),
      );
      final e = BackupFailedException.fromError(
        fse,
        StackTrace.empty,
        debugIsWindows: false,
      );
      expect(e.cause, BackupFailureCause.sourceMissing);
    });

    test('classifies Win32 ERROR_FILE_NOT_FOUND (2) as sourceMissing', () {
      const fse = FileSystemException(
        'open failed',
        'C:\\Users\\x\\f.db',
        OSError('The system cannot find the file specified.', 2),
      );
      final e = BackupFailedException.fromError(
        fse,
        StackTrace.empty,
        debugIsWindows: true,
      );
      expect(e.cause, BackupFailureCause.sourceMissing);
    });

    test('classifies Win32 ERROR_PATH_NOT_FOUND (3) as sourceMissing', () {
      const fse = FileSystemException(
        'open failed',
        'C:\\Users\\x\\f.db',
        OSError('The system cannot find the path specified.', 3),
      );
      final e = BackupFailedException.fromError(
        fse,
        StackTrace.empty,
        debugIsWindows: true,
      );
      expect(e.cause, BackupFailureCause.sourceMissing);
    });

    test(
      'POSIX EIO (5) on non-Windows is NOT misclassified as permissionDenied',
      () {
        const fse = FileSystemException(
          'read failed',
          '/tmp/f.db',
          OSError('Input/output error', 5),
        );
        final e = BackupFailedException.fromError(
          fse,
          StackTrace.empty,
          debugIsWindows: false,
        );
        // EIO is not in the POSIX classifier table → falls through to unknown,
        // does not leak Win32 ERROR_ACCESS_DENIED guidance.
        expect(e.cause, BackupFailureCause.unknown);
      },
    );

    test(
      'POSIX ENOTEMPTY (39) on non-Windows is NOT misclassified as diskFull',
      () {
        const fse = FileSystemException(
          'rmdir failed',
          '/tmp/dir',
          OSError('Directory not empty', 39),
        );
        final e = BackupFailedException.fromError(
          fse,
          StackTrace.empty,
          debugIsWindows: false,
        );
        expect(e.cause, BackupFailureCause.unknown);
      },
    );

    test(
      'POSIX EHOSTDOWN (112) on non-Windows is NOT misclassified as diskFull',
      () {
        const fse = FileSystemException(
          'net op failed',
          '/tmp/f.db',
          OSError('Host is down', 112),
        );
        final e = BackupFailedException.fromError(
          fse,
          StackTrace.empty,
          debugIsWindows: false,
        );
        expect(e.cause, BackupFailureCause.unknown);
      },
    );

    test('FileSystemException with null osError falls through to unknown', () {
      const fse = FileSystemException('some error', '/tmp/f.db');
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
    const e = BackupFailedException(
      cause: BackupFailureCause.sourceMissing,
      userMessage: 'Dive log file not found.',
      technicalDetails: 'file /tmp/f.db does not exist',
    );
    expect(e.cause, BackupFailureCause.sourceMissing);
  });

  test('toString embeds cause and user message for logs', () {
    const e = BackupFailedException(
      cause: BackupFailureCause.diskFull,
      userMessage: 'Disk is full.',
      technicalDetails: 'ENOSPC',
    );
    final s = e.toString();
    expect(s, contains('BackupFailureCause.diskFull'));
    expect(s, contains('Disk is full.'));
  });
}
