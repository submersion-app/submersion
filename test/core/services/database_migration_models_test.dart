import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_migration_models.dart';

ExistingDatabaseInfo _sized(int bytes) => ExistingDatabaseInfo(
  path: 'submersion.db',
  userCount: 0,
  diveCount: 0,
  siteCount: 0,
  tripCount: 0,
  buddyCount: 0,
  fileSize: bytes,
);

void main() {
  group('ExistingDatabaseInfo.formattedFileSize', () {
    test('shows bytes below one kilobyte', () {
      expect(_sized(512).formattedFileSize, '512 B');
    });

    test('shows kilobytes below one megabyte', () {
      expect(_sized(1536).formattedFileSize, '1.5 KB');
    });

    test('shows megabytes from one megabyte up', () {
      expect(_sized(3 * 1024 * 1024).formattedFileSize, '3.0 MB');
    });
  });

  test('MigrationResult carries its paths on success and its message on '
      'failure', () {
    final ok = MigrationResult.success(oldPath: 'a', newPath: 'b');
    final failed = MigrationResult.failure('no');

    expect((ok.success, ok.oldPath, ok.newPath), (true, 'a', 'b'));
    expect((failed.success, failed.errorMessage), (false, 'no'));
  });
}
