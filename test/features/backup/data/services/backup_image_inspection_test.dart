import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/scratch_database.dart';
import 'package:submersion/features/backup/data/services/backup_image_inspection.dart';
import 'package:submersion/features/backup/data/services/backup_note_stamp.dart';

/// A browser restore checks a backup held in memory the way the native
/// restore checks a file (issue #4121): Submersion's tables, the schema it
/// was written at, and the note stamped into it.
void main() {
  Future<Uint8List> image({
    bool submersion = true,
    int version = 300,
    String? note,
    bool wal = false,
  }) async {
    final bytes = await withScratchDatabase((db) async {
      db.execute(
        submersion
            ? 'CREATE TABLE dives (id TEXT)'
            : 'CREATE TABLE recipes (id TEXT)',
      );
      if (note != null) {
        db.execute('CREATE TABLE $backupInfoTable (key TEXT, value TEXT)');
        db.execute(
          "INSERT INTO $backupInfoTable (key, value) VALUES ('note', ?)",
          [note],
        );
      }
      db.execute('PRAGMA user_version = $version');
    });
    if (!wal) return bytes;
    return Uint8List.fromList(bytes)
      ..[18] = 2
      ..[19] = 2;
  }

  test(
    'reads the schema version and the note of a Submersion backup',
    () async {
      final info = await inspectBackupImage(
        await image(version: 327, note: 'Before the trip'),
      );
      expect(info.hasSubmersionTables, isTrue);
      expect(info.schemaVersion, 327);
      expect(info.note, 'Before the trip');
    },
  );

  test(
    'a database without the dive tables is not a Submersion backup',
    () async {
      final info = await inspectBackupImage(await image(submersion: false));
      expect(info.hasSubmersionTables, isFalse);
      expect(info.note, isNull);
    },
  );

  test('a copy of a WAL-mode database reads as well', () async {
    final info = await inspectBackupImage(await image(wal: true));
    expect(info.hasSubmersionTables, isTrue);
  });

  test('bytes that are not SQLite throw', () async {
    await expectLater(
      inspectBackupImage(Uint8List.fromList(List.filled(4096, 9))),
      throwsA(anything),
    );
  });
}
