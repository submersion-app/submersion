import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/services/sync/crypto/sync_envelope.dart';
import 'package:submersion/features/backup/data/services/backup_note_stamp.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('backup_note_stamp_test');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  /// A minimal plaintext database standing in for a VACUUM INTO copy.
  String makeCopy([String name = 'copy.db']) {
    final path = p.join(dir.path, name);
    final db = sqlite3.sqlite3.open(path);
    db.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
    db.close();
    return path;
  }

  bool hasInfoTable(String path) {
    final db = sqlite3.sqlite3.open(path, mode: sqlite3.OpenMode.readOnly);
    try {
      return db.select(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
        [backupInfoTable],
      ).isNotEmpty;
    } finally {
      db.close();
    }
  }

  group('normalizeBackupNote', () {
    test('trims and turns blank into null', () {
      expect(normalizeBackupNote(null), isNull);
      expect(normalizeBackupNote('   '), isNull);
      expect(normalizeBackupNote('  Before trip \n'), 'Before trip');
    });

    test('keeps a note at the limit unchanged', () {
      final atLimit = 'a' * maxBackupNoteLength;
      expect(normalizeBackupNote(atLimit), atLimit);
    });

    test('caps at the limit without splitting an emoji', () {
      final long = '${'a' * (maxBackupNoteLength - 1)}\u{1F42C}tail';
      final capped = normalizeBackupNote(long)!;
      expect(capped.runes.last, 0x1F42C);
      expect(capped.length, maxBackupNoteLength - 1 + 2);
    });
  });

  group('stamp and read', () {
    test('a stamped note reads back', () async {
      final path = makeCopy();
      stampBackupNote(path, 'Before the Cozumel trip');
      expect(await readBackupNote(path), 'Before the Cozumel trip');
    });

    test('quotes and SQL text are stored verbatim', () async {
      final path = makeCopy();
      const note = "Diver's log; DROP TABLE dives; -- \"x\"";
      stampBackupNote(path, note);
      expect(await readBackupNote(path), note);
      final db = sqlite3.sqlite3.open(path);
      expect(db.select('SELECT COUNT(*) AS c FROM dives').single['c'], 0);
      db.close();
    });

    test('stamping no note removes an inherited table', () async {
      final path = makeCopy();
      stampBackupNote(path, 'Old note');
      stampBackupNote(path, null);
      expect(hasInfoTable(path), isFalse);
      expect(await readBackupNote(path), isNull);
    });

    test('restamping replaces the inherited note', () async {
      final path = makeCopy();
      stampBackupNote(path, 'Old note');
      stampBackupNote(path, 'New note');
      expect(await readBackupNote(path), 'New note');
    });

    test('a blank note stamps no table', () {
      final path = makeCopy();
      stampBackupNote(path, '   ');
      expect(hasInfoTable(path), isFalse);
    });

    test('stamping a missing file throws', () {
      expect(
        () => stampBackupNote(p.join(dir.path, 'missing.db'), 'x'),
        throwsA(anything),
      );
    });
  });

  group('readBackupNote never throws', () {
    test('missing file', () async {
      expect(await readBackupNote(p.join(dir.path, 'missing.db')), isNull);
    });

    test('a file that is not a database', () async {
      final path = p.join(dir.path, 'garbage.db');
      File(path).writeAsStringSync('not a database');
      expect(await readBackupNote(path), isNull);
    });

    test('an encrypted backup artifact', () async {
      final path = p.join(dir.path, 'enc.sbe');
      File(
        path,
      ).writeAsBytesSync([...SyncEnvelope.magic, ...List.filled(256, 0)]);
      expect(await readBackupNote(path), isNull);
    });

    test('a database without the table', () async {
      expect(await readBackupNote(makeCopy()), isNull);
    });
  });

  group('exportAndStampBackup', () {
    /// Stands in for DatabaseService.backup: copies [source] to the path.
    Future<void> Function(String) copyOf(String source) =>
        (path) async => File(source).copySync(path);

    test(
      'an automatic copy of a restored, noted database has no note',
      () async {
        final live = makeCopy('live.db');
        stampBackupNote(live, 'Inherited from a restored backup');
        final dest = p.join(dir.path, 'auto.db');

        await exportAndStampBackup(dest, export: copyOf(live));

        expect(hasInfoTable(dest), isFalse);
        expect(await readBackupNote(dest), isNull);
      },
    );

    test('a noted copy reads back its own note', () async {
      final live = makeCopy('live.db');
      stampBackupNote(live, 'Inherited');
      final dest = p.join(dir.path, 'manual.db');

      await exportAndStampBackup(dest, export: copyOf(live), note: 'Mine');

      expect(await readBackupNote(dest), 'Mine');
    });

    test(
      'keeps a raw fallback copy SQLite cannot open when there is no note',
      () async {
        // DatabaseService.backup falls back to a raw byte copy when the live
        // file will not open; that copy may be the only one that survives.
        final raw = p.join(dir.path, 'unopenable.db');
        File(raw).writeAsBytesSync(List<int>.generate(8192, (i) => i % 251));
        final dest = p.join(dir.path, 'fallback.db');

        await exportAndStampBackup(dest, export: copyOf(raw));

        expect(File(dest).readAsBytesSync(), File(raw).readAsBytesSync());
      },
    );

    test('a note that cannot be stamped fails the backup', () async {
      final raw = p.join(dir.path, 'unopenable.db');
      File(raw).writeAsBytesSync(List<int>.generate(8192, (i) => i % 251));

      await expectLater(
        exportAndStampBackup(
          p.join(dir.path, 'noted.db'),
          export: copyOf(raw),
          note: 'Typed by the diver',
        ),
        throwsA(anything),
      );
    });
  });
}
