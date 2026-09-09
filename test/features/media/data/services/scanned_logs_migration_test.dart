import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/media/data/services/scanned_logs_migration.dart';

/// Coverage for [ScannedLogsMigration], the one-time move of scanned logbook
/// pages from `<documents>/scanned_logs/` into
/// `<documents>/Submersion/scanned_logs/` (issue #1645).
///
/// The filesystem half runs against a real temp tree so the behaviour is
/// covered on the POSIX CI matrix; the row half is a recording callback so
/// these tests need no database.
void main() {
  late Directory docs;
  late List<(String from, String to)> relinked;
  late Future<int> Function(String from, String to) relocateRows;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('scanned_logs_migration_');
    relinked = [];
    relocateRows = (from, to) async {
      relinked.add((from, to));
      return 1;
    };
  });

  tearDown(() {
    if (!Platform.isWindows) {
      Process.runSync('chmod', ['-R', 'u+rwX', docs.path]);
    }
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  String legacyPath() => p.join(docs.path, 'scanned_logs');
  String targetPath() => p.join(docs.path, 'Submersion', 'scanned_logs');

  File seedLegacy(String name, List<int> bytes) =>
      File(p.join(legacyPath(), name))
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);

  ScannedLogsMigration migration({
    Future<Directory> Function()? documentsDirectory,
    Future<int> Function(String from, String to)? relocate,
  }) => ScannedLogsMigration(
    documentsDirectory: documentsDirectory ?? () async => docs,
    relocateRows: relocate ?? relocateRows,
  );

  test('no legacy folder is a no-op that creates nothing', () async {
    final report = await migration().run();

    expect(report.outcome, ScannedLogsMigrationOutcome.noLegacyData);
    expect(report.moved, 0);
    expect(Directory(targetPath()).existsSync(), isFalse);
  });

  test(
    'moves every page, relinks its rows, and removes the legacy folder',
    () async {
      seedLegacy('1.jpg', [1, 2, 3]);
      seedLegacy('2.jpg', [4, 5, 6]);

      final report = await migration().run();

      expect(report.outcome, ScannedLogsMigrationOutcome.migrated);
      expect(report.moved, 2);
      expect(report.skipped, 0);
      expect(report.failed, 0);
      expect(File(p.join(targetPath(), '1.jpg')).readAsBytesSync(), [1, 2, 3]);
      expect(File(p.join(targetPath(), '2.jpg')).readAsBytesSync(), [4, 5, 6]);
      expect(Directory(legacyPath()).existsSync(), isFalse);
      expect(relinked.toSet(), {
        (p.join(legacyPath(), '1.jpg'), p.join(targetPath(), '1.jpg')),
        (p.join(legacyPath(), '2.jpg'), p.join(targetPath(), '2.jpg')),
      });
    },
  );

  test(
    'a page already at the destination with different bytes is skipped',
    () async {
      seedLegacy('1.jpg', [1, 2, 3]);
      File(p.join(targetPath(), '1.jpg'))
        ..createSync(recursive: true)
        ..writeAsBytesSync([9, 9, 9]);

      final report = await migration().run();

      expect(report.moved, 0);
      expect(report.skipped, 1);
      // Neither copy is touched and no row is pointed at the wrong bytes.
      expect(File(p.join(targetPath(), '1.jpg')).readAsBytesSync(), [9, 9, 9]);
      expect(File(p.join(legacyPath(), '1.jpg')).readAsBytesSync(), [1, 2, 3]);
      expect(relinked, isEmpty);
      // The legacy folder still holds a page, so it stays.
      expect(Directory(legacyPath()).existsSync(), isTrue);
    },
  );

  test('an identical page already at the destination is a resumed move: rows '
      'are relinked and the legacy copy is removed', () async {
    // A previous launch copied the file and was interrupted before it
    // deleted the source. Treating that as "skip" would strand the legacy
    // folder forever.
    seedLegacy('1.jpg', [1, 2, 3]);
    File(p.join(targetPath(), '1.jpg'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);

    final report = await migration().run();

    expect(report.moved, 1);
    expect(report.skipped, 0);
    expect(File(p.join(legacyPath(), '1.jpg')).existsSync(), isFalse);
    expect(Directory(legacyPath()).existsSync(), isFalse);
    expect(relinked, [
      (p.join(legacyPath(), '1.jpg'), p.join(targetPath(), '1.jpg')),
    ]);
  });

  test(
    'a row relink failure leaves that page in place and moves the rest',
    () async {
      seedLegacy('bad.jpg', [1]);
      seedLegacy('good.jpg', [2]);

      final report = await migration(
        relocate: (from, to) async {
          if (p.basename(from) == 'bad.jpg') throw StateError('db closed');
          relinked.add((from, to));
          return 1;
        },
      ).run();

      expect(report.outcome, ScannedLogsMigrationOutcome.migrated);
      expect(report.moved, 1);
      expect(report.failed, 1);
      // The failed page is exactly where it was, so the next launch retries it
      // and its rows still resolve meanwhile.
      expect(File(p.join(legacyPath(), 'bad.jpg')).readAsBytesSync(), [1]);
      expect(File(p.join(targetPath(), 'bad.jpg')).existsSync(), isFalse);
      expect(File(p.join(targetPath(), 'good.jpg')).readAsBytesSync(), [2]);
      expect(Directory(legacyPath()).existsSync(), isTrue);
    },
  );

  test('subdirectories inside the legacy folder are left alone', () async {
    seedLegacy('1.jpg', [1]);
    Directory(p.join(legacyPath(), 'nested')).createSync();

    final report = await migration().run();

    expect(report.moved, 1);
    expect(Directory(p.join(legacyPath(), 'nested')).existsSync(), isTrue);
    expect(Directory(legacyPath()).existsSync(), isTrue);
  });

  test('never throws: a documents lookup failure is reported', () async {
    final report = await migration(
      documentsDirectory: () async => throw StateError('no path provider'),
    ).run();

    expect(report.outcome, ScannedLogsMigrationOutcome.failed);
    expect(report.error, isA<StateError>());
  });

  test('never throws: an unwritable destination is reported', () async {
    seedLegacy('1.jpg', [1]);
    Directory(p.join(docs.path, 'Submersion')).createSync();
    Process.runSync('chmod', ['555', p.join(docs.path, 'Submersion')]);

    final report = await migration().run();

    expect(report.outcome, ScannedLogsMigrationOutcome.failed);
    expect(report.moved, 0);
    expect(File(p.join(legacyPath(), '1.jpg')).existsSync(), isTrue);
    expect(relinked, isEmpty);
  }, skip: Platform.isWindows ? 'chmod is POSIX only' : false);
}
