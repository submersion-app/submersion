import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

const _index = 'idx_certifications_buddy_id';

Future<bool> _hasIndex(AppDatabase db) async {
  final rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'index' AND name = ?",
        variables: [const Variable<String>(_index)],
      )
      .get();
  return rows.isNotEmpty;
}

void main() {
  test('v245 is at or below the current schema version and in the ladder', () {
    // Relaxed once v247 (Explore derived metrics) landed on top; the newest
    // rung owns the exact assertion.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(245));
    expect(AppDatabase.migrationVersions, contains(245));
    expect(AppDatabase.migrationStepCount(244), greaterThanOrEqualTo(1));
  });

  test('a fresh database indexes certifications by buddy', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await _hasIndex(db), isTrue);
  });

  test('a database stranded before v245 gains the index', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('''
          CREATE TABLE certifications (
            id TEXT NOT NULL PRIMARY KEY,
            buddy_id TEXT,
            name TEXT NOT NULL,
            agency TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);
    expect(await _hasIndex(db), isTrue);
  });
}
