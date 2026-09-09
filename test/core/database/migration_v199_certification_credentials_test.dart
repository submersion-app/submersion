import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v199 adds certifications.additional_credentials -- the JSON array of extra
/// (agency, level) pairs one card grants (e.g. an FFESSM N1 that is also a
/// CMAS 1-star).

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  test('v199 is the current schema version and is in the ladder', () {
    // Renumbered from 197: main landed the planner salinity (197) and
    // planner water-type (198) rungs while this branch was open, and a
    // rung at or below the shipped version never runs its onUpgrade step.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(199));
    expect(AppDatabase.migrationVersions, contains(199));
  });

  test('a fresh database has certifications.additional_credentials', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(
      await _columns(db, 'certifications'),
      contains('additional_credentials'),
    );
  });

  test('a database stranded before v199 gains the column', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 198');
        rawDb.execute('''
          CREATE TABLE certifications (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            agency TEXT NOT NULL,
            level TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    expect(
      await _columns(db, 'certifications'),
      contains('additional_credentials'),
    );
  });

  test('the column round-trips a JSON credential list', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await db.customStatement(
      "INSERT INTO certifications "
      "(id, name, agency, level, additional_credentials, created_at, updated_at) "
      "VALUES ('c1', 'Niveau 1', 'ffessm', 'ffessmN1', "
      "'[{\"agency\":\"cmas\",\"level\":\"cmas1StarDiver\"}]', 1, 1)",
    );

    final row = await db
        .customSelect(
          "SELECT additional_credentials FROM certifications WHERE id = 'c1'",
        )
        .getSingle();
    expect(
      row.read<String>('additional_credentials'),
      '[{"agency":"cmas","level":"cmas1StarDiver"}]',
    );
  });
}
