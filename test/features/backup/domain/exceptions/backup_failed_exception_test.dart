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
