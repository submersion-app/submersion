import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/services/backup_bookmark_service.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/data/services/pre_migration_backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';

/// End-to-end guard for the startup path that upgrades a user's database when
/// their stored custom backup location has become unusable.
///
/// Reported from the field on Android: the backup location was a path
/// fabricated by file_picker from a Google Drive SAF tree
/// (`/storage/emulated/0/acc=2;doc=encoded=...`). That is not a content://
/// ref, so the scheme check for a SAF location does not catch it, and scoped
/// storage refuses to mkdir it (errno 13). Resolving it threw a bare
/// FileSystemException before the pre-migration safety copy ran, which escaped
/// the BackupFailedException handler and left the app permanently on the
/// terminal "Database upgrade failed" screen. There is no route back into
/// settings from that screen, so the location could never be corrected.
///
/// This exercises the same wiring StartupPage uses (lazy leased resolution
/// plus a sandbox fallback), so it fails if either the resolver stops
/// self-healing or the resolution moves back outside the guarded region.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late BackupPreferences prefs;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('pmbs_dead_loc_');
    // resolveDefaultBackupsDirectory() builds on the app documents directory.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => tmp.path,
        );
    SharedPreferences.setMockInitialValues({});
    prefs = BackupPreferences(await SharedPreferences.getInstance());
    BackupBookmarkService.debugSupportedOverride = false; // Android
  });

  tearDown(() async {
    BackupBookmarkService.debugSupportedOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await tmp.delete(recursive: true);
  });

  test(
    'unusable custom location still backs up and lets the migration proceed',
    () async {
      final livePath = p.join(tmp.path, 'submersion.db');
      final seed = sqlite3.sqlite3.open(livePath);
      try {
        seed.execute('PRAGMA user_version = 63');
        seed.execute('CREATE TABLE sentinel (id INTEGER PRIMARY KEY)');
        seed.execute('INSERT INTO sentinel VALUES (42)');
      } finally {
        seed.close();
      }

      // Stand-in for the fabricated Drive path: nesting under a regular file
      // makes create(recursive: true) fail in the host VM the way scoped
      // storage fails the real one.
      final blocker = File(p.join(tmp.path, 'not-a-directory'));
      await blocker.writeAsString('x');
      await prefs.setBackupLocation(
        p.join(blocker.path, 'acc=2;doc=encoded=JKazOe75G5_hCtZBVEzAmb0'),
      );

      // Mirrors StartupPage._runPreMigrationBackup's wiring.
      BackupDirLease? lease;
      final service = PreMigrationBackupService(
        livePathProvider: () async => livePath,
        backupsDirProvider: () async {
          lease = await BackupService.resolveBackupsDirectoryLeased(prefs);
          return lease!.path;
        },
        fallbackBackupsDirProvider:
            BackupService.resolveDefaultBackupsDirectory,
        preferences: prefs,
        clock: () => DateTime.utc(2026, 4, 12, 8, 12, 1),
        idGenerator: () => 'dead-location-id',
      );

      try {
        await service.backupIfMigrationPending(
          stored: 63,
          target: 64,
          appVersion: '1.6.0.1241',
        );
      } finally {
        await lease?.release();
      }

      // The safety copy landed in the always-writable sandbox default.
      final backupPath = p.join(
        tmp.path,
        'Submersion/Backups',
        '20260412-081201000-v63-v64.db',
      );
      expect(
        await File(backupPath).exists(),
        isTrue,
        reason: 'backup should fall back to the sandbox default',
      );
      expect(
        await File(backupPath).readAsBytes(),
        await File(livePath).readAsBytes(),
      );

      final records = prefs.getHistory();
      expect(records, hasLength(1));
      expect(records.single.type, BackupType.preMigration);

      // The dead location is cleared, so the next launch does not retry it.
      expect(prefs.getSettings().backupLocation, isNull);
    },
  );
}
