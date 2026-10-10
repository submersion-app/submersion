import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/backup/data/services/backup_note_stamp.dart';

/// A restored backup brings its note table into the live database. Opening the
/// database drops it, so a raw byte copy taken later (the pre-migration and
/// pre-downgrade safety copies) can never carry an old note forward.
void main() {
  test('opening a database that holds a backup note table drops it', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE $backupInfoTable '
            '(key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)',
          );
          raw.execute(
            "INSERT INTO $backupInfoTable (key, value) VALUES ('note', 'Old')",
          );
        },
      ),
    );
    addTearDown(db.close);

    final rows = await db
        .customSelect(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
          variables: [Variable.withString(backupInfoTable)],
        )
        .get();

    expect(rows, isEmpty);
  });
}
