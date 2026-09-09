import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/data/services/backups_directory_access.dart';

/// The scan and the reclaim both need the backups directory held open for the
/// whole operation, which is a different requirement from slice A's
/// measurement: on Apple platforms a custom location is only reachable while
/// its security-scoped bookmark lease is held, and a lease that outlives the
/// work leaks a scoped resource.
void main() {
  BackupDirLease countingLease(String path, void Function() onRelease) =>
      BackupDirLease(path, () async => onRelease());

  test('a SAF location has no directory to enumerate', () async {
    final access = BackupsDirectoryAccess(
      configuredLocation: () async =>
          'content://com.android.externalstorage.documents/tree/primary%3ABackups',
      acquireLease: () async =>
          fail('a content:// tree URI must not resolve to a filesystem lease'),
    );

    expect(await access.use((path) async => path), isNull);
  });

  test(
    'a filesystem location is handed to the body as its leased path',
    () async {
      final access = BackupsDirectoryAccess(
        configuredLocation: () async => null,
        acquireLease: () async => countingLease('/backups', () {}),
      );

      expect(await access.use((path) async => path), '/backups');
    },
  );

  test('the lease is released once the body completes', () async {
    var released = 0;
    final access = BackupsDirectoryAccess(
      configuredLocation: () async => null,
      acquireLease: () async => countingLease('/backups', () => released++),
    );

    await access.use((path) async => null);

    expect(released, 1);
  });

  test('the lease is released when the body throws', () async {
    var released = 0;
    final access = BackupsDirectoryAccess(
      configuredLocation: () async => null,
      acquireLease: () async => countingLease('/backups', () => released++),
    );

    await expectLater(
      access.use((path) async => throw const FileSystemException('boom')),
      throwsA(isA<FileSystemException>()),
    );

    expect(released, 1);
  });
}
