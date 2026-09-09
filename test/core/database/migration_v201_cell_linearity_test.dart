import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v201 adds the O2 cell linearity link (issue #986):
/// pre_dive_checklist_template_items.source_item_id, plus
/// pre_dive_session_items.source_item_id and .source_value_number.
///
/// Numbered 201 rather than 200 because the transmitter registry branch
/// (issue #1365) already holds v200 while this branch is open, and a rung at
/// or below the shipped version never runs its onUpgrade step.

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  test('v201 is the current schema version and is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, 201);
    expect(AppDatabase.migrationVersions, contains(201));
  });

  test('a fresh database has all three linearity columns', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(
      await _columns(db, 'pre_dive_checklist_template_items'),
      contains('source_item_id'),
    );
    final sessionItemColumns = await _columns(db, 'pre_dive_session_items');
    expect(sessionItemColumns, contains('source_item_id'));
    expect(sessionItemColumns, contains('source_value_number'));
  });

  test('a database stranded before v201 gains the columns', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 200');
        rawDb.execute('''
          CREATE TABLE pre_dive_checklist_template_items (
            id TEXT NOT NULL PRIMARY KEY,
            template_id TEXT NOT NULL,
            title TEXT NOT NULL,
            item_type TEXT NOT NULL DEFAULT 'check',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        rawDb.execute('''
          CREATE TABLE pre_dive_session_items (
            id TEXT NOT NULL PRIMARY KEY,
            session_id TEXT NOT NULL,
            title TEXT NOT NULL,
            item_type TEXT NOT NULL DEFAULT 'check',
            state TEXT NOT NULL DEFAULT 'pending',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    expect(
      await _columns(db, 'pre_dive_checklist_template_items'),
      contains('source_item_id'),
    );
    final sessionItemColumns = await _columns(db, 'pre_dive_session_items');
    expect(sessionItemColumns, contains('source_item_id'));
    expect(sessionItemColumns, contains('source_value_number'));
  });

  test('the columns round-trip a link and a frozen air reading', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await db.customStatement(
      'INSERT INTO pre_dive_sessions '
      '(id, template_name, started_at, created_at, updated_at) '
      "VALUES ('s1', 'CCR Build', 1, 1, 1)",
    );
    await db.customStatement(
      'INSERT INTO pre_dive_session_items '
      '(id, session_id, title, item_type, source_item_id, '
      'source_value_number, value_number, created_at, updated_at) '
      "VALUES ('o2', 's1', 'Cell 1 mV in O2', 'cellLinearity', 'air1', "
      '10.1, 48.0, 1, 1)',
    );

    final row = await db
        .customSelect(
          'SELECT source_item_id, source_value_number FROM '
          "pre_dive_session_items WHERE id = 'o2'",
        )
        .getSingle();
    expect(row.read<String>('source_item_id'), 'air1');
    expect(row.read<double>('source_value_number'), 10.1);
  });
}
