import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/windows_app_data_migration.dart';

/// These tests exercise the pure directory-move core on the host filesystem so
/// the behaviour is covered on the POSIX CI matrix. The Windows-only decision
/// of WHICH roots to migrate lives in migrateWindowsAppDataDirectories and is
/// guarded by Platform.isWindows.
void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('win_appdata_migration_test_');
  });

  tearDown(() {
    // Re-open anything a test locked with chmod so the tree can be removed.
    // Shelled out rather than walked in Dart: a 000 directory cannot be
    // listed, so a recursive Dart walk throws before it can unlock anything.
    if (!Platform.isWindows) {
      Process.runSync('chmod', ['-R', 'u+rwX', root.path]);
    }
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  String legacyPath() => p.join(root.path, 'Eric Griffin', 'submersion');
  String targetPath() => p.join(root.path, 'Submersion', 'submersion');

  Future<AppDataMigrationReport> migrate({
    Future<Directory> Function(Directory, String)? rename,
  }) {
    return migrateCompanyDirectory(
      rootPath: root.path,
      legacyCompany: 'Eric Griffin',
      company: 'Submersion',
      product: 'submersion',
      rename: rename,
    );
  }

  void seedLegacy() {
    Directory(p.join(legacyPath(), 'logs')).createSync(recursive: true);
    File(p.join(legacyPath(), 'shared_preferences.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync('{"unit_system":"metric"}');
    File(
      p.join(legacyPath(), 'logs', 'submersion-debug.log'),
    ).writeAsStringSync('line one');
  }

  group('migrateCompanyDirectory', () {
    test(
      'moves the legacy company directory onto the new company name',
      () async {
        seedLegacy();

        final report = await migrate();

        expect(report.outcome, AppDataMigrationOutcome.moved);
        expect(Directory(targetPath()).existsSync(), isTrue);
        expect(Directory(legacyPath()).existsSync(), isFalse);
      },
    );

    test('carries nested file contents across the move', () async {
      seedLegacy();

      await migrate();

      expect(
        File(
          p.join(targetPath(), 'shared_preferences.json'),
        ).readAsStringSync(),
        '{"unit_system":"metric"}',
      );
      expect(
        File(
          p.join(targetPath(), 'logs', 'submersion-debug.log'),
        ).readAsStringSync(),
        'line one',
      );
    });

    test('does nothing when there is no legacy directory', () async {
      final report = await migrate();

      expect(report.outcome, AppDataMigrationOutcome.noLegacyData);
      expect(Directory(targetPath()).existsSync(), isFalse);
    });

    test(
      'leaves both directories untouched when the target already has data',
      () async {
        seedLegacy();
        File(p.join(targetPath(), 'shared_preferences.json'))
          ..createSync(recursive: true)
          ..writeAsStringSync('{"unit_system":"imperial"}');

        final report = await migrate();

        expect(report.outcome, AppDataMigrationOutcome.targetAlreadyPopulated);
        expect(Directory(legacyPath()).existsSync(), isTrue);
        expect(
          File(
            p.join(targetPath(), 'shared_preferences.json'),
          ).readAsStringSync(),
          '{"unit_system":"imperial"}',
        );
      },
    );

    test('replaces an empty target directory rather than refusing', () async {
      seedLegacy();
      Directory(targetPath()).createSync(recursive: true);

      final report = await migrate();

      expect(report.outcome, AppDataMigrationOutcome.moved);
      expect(
        File(
          p.join(targetPath(), 'shared_preferences.json'),
        ).readAsStringSync(),
        '{"unit_system":"metric"}',
      );
    });

    test('is a no-op when the legacy and target names are identical', () async {
      seedLegacy();

      final report = await migrateCompanyDirectory(
        rootPath: root.path,
        legacyCompany: 'Eric Griffin',
        company: 'Eric Griffin',
        product: 'submersion',
      );

      expect(report.outcome, AppDataMigrationOutcome.notNeeded);
      expect(Directory(legacyPath()).existsSync(), isTrue);
    });

    test(
      'copies the tree when rename fails, keeping the legacy directory',
      () async {
        seedLegacy();

        final report = await migrate(
          rename: (_, _) => Future<Directory>.error(
            const FileSystemException('cross-device link'),
          ),
        );

        expect(report.outcome, AppDataMigrationOutcome.copied);
        expect(
          File(
            p.join(targetPath(), 'logs', 'submersion-debug.log'),
          ).readAsStringSync(),
          'line one',
        );
        // The legacy tree is deliberately retained. The target is complete, so
        // the next launch no-ops on it; keeping the source buys a manual
        // recovery path at the cost of some disk.
        expect(Directory(legacyPath()).existsSync(), isTrue);
        // Staging is promoted by rename, never left lying around.
        expect(Directory('${targetPath()}.migrating').existsSync(), isFalse);
      },
    );

    test('reports failure without deleting the legacy directory', () async {
      seedLegacy();
      // A FILE where the new company directory needs to be, so creating the
      // target parent cannot succeed.
      File(
        p.join(root.path, 'Submersion'),
      ).writeAsStringSync('not a directory');

      final report = await migrate();

      expect(report.outcome, AppDataMigrationOutcome.failed);
      expect(report.error, isNotNull);
      expect(Directory(legacyPath()).existsSync(), isTrue);
      expect(
        File(
          p.join(legacyPath(), 'shared_preferences.json'),
        ).readAsStringSync(),
        '{"unit_system":"metric"}',
      );
    });

    // A copy is not atomic. If it lands directly in the real target and then
    // fails, the next launch sees a populated target, reports
    // targetAlreadyPopulated, and never retries -- so the app runs on a partial
    // copy while the real settings sit stranded in the legacy directory.
    // Copying via a staging directory keeps the target all-or-nothing.
    test(
      'leaves no partial target when the copy fails mid-tree',
      () async {
        seedLegacy();
        final locked = Directory(p.join(legacyPath(), 'locked'))
          ..createSync(recursive: true);
        File(p.join(locked.path, 'inner.json')).writeAsStringSync('{}');
        Process.runSync('chmod', ['000', locked.path]);

        final report = await migrate(
          rename: (_, _) => Future<Directory>.error(
            const FileSystemException('cross-device'),
          ),
        );

        expect(report.outcome, AppDataMigrationOutcome.failed);
        expect(
          Directory(targetPath()).existsSync(),
          isFalse,
          reason: 'a half-copied target would be mistaken for a finished one',
        );
        expect(Directory(legacyPath()).existsSync(), isTrue);
      },
      skip: Platform.isWindows
          ? 'chmod-based failure injection is POSIX-only'
          : null,
    );

    test(
      'retries on the next run after a failed copy',
      () async {
        seedLegacy();
        final locked = Directory(p.join(legacyPath(), 'locked'))
          ..createSync(recursive: true);
        Process.runSync('chmod', ['000', locked.path]);

        await migrate(
          rename: (_, _) => Future<Directory>.error(
            const FileSystemException('cross-device'),
          ),
        );

        // Whatever blocked the copy clears, and the second attempt succeeds.
        Process.runSync('chmod', ['755', locked.path]);
        final second = await migrate();

        expect(second.outcome, AppDataMigrationOutcome.moved);
        expect(
          File(
            p.join(targetPath(), 'shared_preferences.json'),
          ).readAsStringSync(),
          '{"unit_system":"metric"}',
        );
      },
      skip: Platform.isWindows
          ? 'chmod-based failure injection is POSIX-only'
          : null,
    );

    test('reports the paths it considered', () async {
      seedLegacy();

      final report = await migrate();

      expect(report.legacyPath, legacyPath());
      expect(report.targetPath, targetPath());
    });
  });

  group('migrateWindowsAppDataDirectories', () {
    // Skipped at the TEST level, not the assertion level: the call itself would
    // migrate the developer's real %APPDATA% / %LOCALAPPDATA% on a Windows box.
    test(
      'does nothing off Windows',
      () async {
        expect(await migrateWindowsAppDataDirectories(), isEmpty);
      },
      skip: Platform.isWindows
          ? 'would touch the real %APPDATA% tree on this machine'
          : null,
    );
  });
}
