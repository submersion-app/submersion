import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/storage/restore_temp_sweep.dart';

void main() {
  late Directory temp;
  final now = DateTime(2026, 10, 17, 12);

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('restore_temp_sweep_test');
  });

  tearDown(() async {
    if (temp.existsSync()) await temp.delete(recursive: true);
  });

  // Ages come from the modification time alone here, so a test can backdate
  // a file with setLastModified; the default also weighs the time the file
  // was created (see the last test).
  RestoreTempSweep build() => RestoreTempSweep(
    temporaryDirectory: () async => temp,
    touchedAt: (stat) => stat.modified,
  );

  Future<File> write(String relative, int bytes, Duration age) async {
    final file = File(p.join(temp.path, relative));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(List<int>.filled(bytes, 0));
    await file.setLastModified(now.subtract(age));
    return file;
  }

  test('deletes an old downloaded backup left in temp', () async {
    final db = await write(
      'submersion_backup_2026-10-01_101500.db',
      300,
      const Duration(days: 3),
    );
    final sbe = await write(
      'submersion_backup_2026-10-01_101500__d0a1b2c3d.sbe',
      200,
      const Duration(days: 3),
    );

    final report = await build().run(now: now);

    expect(db.existsSync(), isFalse);
    expect(sbe.existsSync(), isFalse);
    expect(report.filesDeleted, 2);
    expect(report.bytesReclaimed, 500);
  });

  test('deletes old restore copies and pre-migration copies', () async {
    final restoreCopy = await write(
      'restore-0b9d2f7e-6c1a-4d3e-9f2b-1a2b3c4d5e6f-submersion_backup_2026-10-01_101500.db',
      100,
      const Duration(days: 3),
    );
    final preMigration = await write(
      '20261001-101500123-v120-v121.db',
      50,
      const Duration(days: 3),
    );

    final report = await build().run(now: now);

    expect(restoreCopy.existsSync(), isFalse);
    expect(preMigration.existsSync(), isFalse);
    expect(report.bytesReclaimed, 150);
  });

  test(
    'deletes the decrypted, staged and export copies a kill left behind',
    () async {
      const uuid = '0b9d2f7e-6c1a-4d3e-9f2b-1a2b3c4d5e6f';
      final leftovers = [
        // The plaintext copy of an encrypted backup, made for validation.
        await write('restore_$uuid.db', 10, const Duration(days: 3)),
        // Backup staging and SAF target copies.
        await write(
          '$uuid-submersion_backup_2026-10-01_101500.db',
          10,
          const Duration(days: 3),
        ),
        await write('export_$uuid.db', 10, const Duration(days: 3)),
        await write('reenc_$uuid.sbe', 10, const Duration(days: 3)),
      ];

      final report = await build().run(now: now);

      for (final f in leftovers) {
        expect(f.existsSync(), isFalse, reason: f.path);
      }
      expect(report.filesDeleted, leftovers.length);
    },
  );

  test('matches a pre-downgrade copy name', () async {
    // Shared from the history under its own name (issue #3650).
    final bare = await write(
      '20261028-101500123-v300-newer.db',
      100,
      const Duration(days: 3),
    );
    final restoreCopy = await write(
      'restore-0b9d2f7e-6c1a-4d3e-9f2b-1a2b3c4d5e6f-20261028-101500123-v300-newer.db',
      100,
      const Duration(days: 3),
    );

    await build().run(now: now);

    expect(bare.existsSync(), isFalse);
    expect(restoreCopy.existsSync(), isFalse);
  });

  test('matches a safety copy wrapped as .sbe', () async {
    // "Encrypt existing backups" wraps pre-update copies too, and a shared
    // one goes out under that name (issue #3650).
    final bare = await write(
      '20261012-081200000-v300-v301.sbe',
      100,
      const Duration(days: 3),
    );
    final staged = await write(
      'restore-0b9d2f7e-6c1a-4d3e-9f2b-1a2b3c4d5e6f-20261028-101500123-v300-newer.sbe',
      100,
      const Duration(days: 3),
    );

    await build().run(now: now);

    expect(bare.existsSync(), isFalse);
    expect(staged.existsSync(), isFalse);
  });

  test('keeps a backup-named file younger than 24 hours', () async {
    // The share sheet exports under the same name into the same folder.
    final fresh = await write(
      'submersion_backup_2026-10-17_110000.db',
      300,
      const Duration(hours: 2),
    );

    final report = await build().run(now: now);

    expect(fresh.existsSync(), isTrue);
    expect(report.filesDeleted, 0);
  });

  test('ignores files in subfolders and names that do not match', () async {
    final others = [
      await write('notes.db', 10, const Duration(days: 9)),
      await write(
        p.join('picked', 'submersion_backup_x.db'),
        10,
        const Duration(days: 9),
      ),
      await write('submersion_backup_x.txt', 10, const Duration(days: 9)),
      await write('ssv1_base.db', 10, const Duration(days: 9)),
    ];

    final report = await build().run(now: now);

    for (final f in others) {
      expect(f.existsSync(), isTrue, reason: f.path);
    }
    expect(report.filesDeleted, 0);
  });

  test('dry run counts without deleting', () async {
    final db = await write(
      'submersion_backup_2026-10-01_101500.db',
      300,
      const Duration(days: 3),
    );

    final report = await build().run(now: now, dryRun: true);

    expect(report.bytesReclaimed, 300);
    expect(db.existsSync(), isTrue);
  });

  test('a missing temp folder reclaims nothing', () async {
    await temp.delete(recursive: true);
    expect((await build().run(now: now)).filesDeleted, 0);
  });

  test('a copy that kept an old modification time is not old', () async {
    // File.copy keeps the source's modification time on Apple platforms, so
    // a restore copy made a minute ago can look as old as its backup. Its
    // creation (status change) time is when the copy was made.
    final copy = await write(
      'restore-0b9d2f7e-6c1a-4d3e-9f2b-1a2b3c4d5e6f-submersion_backup_x.db',
      10,
      const Duration(days: 10),
    );

    final report = await RestoreTempSweep(
      temporaryDirectory: () async => temp,
    ).run(now: DateTime.now());

    expect(copy.existsSync(), isTrue);
    expect(report.filesDeleted, 0);
  });
}
