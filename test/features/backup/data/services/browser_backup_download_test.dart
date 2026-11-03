import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/backup/data/services/browser_backup_download.dart';

import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// A browser's backups are downloads (issue #4121), and before a restore
/// the library downloads first, as a file restore backs up first.
void main() {
  test('backup names carry the time they were taken', () {
    final at = DateTime(2026, 11, 2, 9, 5);
    expect(browserBackupFileName(at), 'submersion-backup-20261102-0905.db');
    expect(
      browserBackupFileName(at, prefix: 'submersion-backup-before-restore'),
      'submersion-backup-before-restore-20261102-0905.db',
    );
  });

  group('downloadLibraryBeforeRestore', () {
    late List<String> saved;

    setUp(() async {
      await setUpTestDatabase();
      saved = [];
    });
    tearDown(() => DatabaseService.instance.resetForTesting());

    Future<void> run() => downloadLibraryBeforeRestore(
      clock: () => DateTime(2026, 11, 2, 9, 5),
      readImage: () async => Uint8List.fromList([1]),
      save: (bytes, name) async => saved.add(name),
    );

    test('downloads a library that holds dives', () async {
      final db = DatabaseService.instance.database;
      await seedDivers(db, ['d1']);
      await seedDive(db, 'dive-1', diver: 'd1');

      await run();

      expect(saved, ['submersion-backup-before-restore-20261102-0905.db']);
    });

    test('skips a library with nothing to lose', () async {
      await run();
      expect(saved, isEmpty);
    });
  });
}
