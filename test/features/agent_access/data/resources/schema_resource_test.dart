import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/agent_access/data/resources/schema_resource.dart';
import 'package:submersion/features/agent_access/data/resources/sql_column_notes.generated.dart';
import 'package:submersion/features/agent_access/data/sql/sql_denied_set.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';

import '../../../../../tool/generate_sql_column_notes.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late String text;

  setUpAll(() async {
    db = createTestDatabase();
    text = await SchemaResource().read(
      AgentToolContext(db: db, clientName: null),
    );
  });
  tearDownAll(() => db.close());

  test('states the storage conventions', () {
    expect(text, contains('metric'));
    expect(text, contains('do not shift'));
    expect(text, contains('SELECT DISTINCT'));
    expect(text, contains('active profile'));
  });

  test('lists every readable table', () async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_schema WHERE type = 'table'")
        .get();
    for (final row in rows) {
      final table = row.read<String>('name');
      if (sqlTableReadable(table)) expect(text, contains('## $table\n'));
    }
  });

  test('names no denied table or column anywhere', () {
    for (final name in [...kSqlDeniedTables, ...kSqlDeniedColumns]) {
      expect(text, isNot(contains(sqlNamePattern(name))), reason: name);
    }
  });

  test('gives each column its type and keys', () {
    expect(text, contains('- `id` (text, primary key, required)'));
    expect(text, contains('`diver_id` (text, joins divers.id)'));
  });

  test('every note names a column that exists', () async {
    final rows = await db.customSelect('''
      SELECT m.name AS tbl, x.name AS col
      FROM sqlite_schema m, pragma_table_xinfo(m.name) x
      WHERE m.type = 'table'
    ''').get();
    final columns = {
      for (final row in rows)
        '${row.read<String>('tbl')}.${row.read<String>('col')}',
    };
    final strays = [
      for (final MapEntry(key: table, value: notes) in kSqlColumnNotes.entries)
        for (final column in notes.keys)
          if (!columns.contains('$table.$column')) '$table.$column',
    ];
    expect(strays, isEmpty);
  });

  test('a note reaches its column', () {
    final table = kSqlColumnNotes.keys.first;
    final column = kSqlColumnNotes[table]!.keys.first;
    expect(text, contains(kSqlColumnNotes[table]![column]));
  });

  test('the notes file matches the table sources', () {
    expect(
      // A Windows checkout can hold this file with CRLF line endings.
      File(kSqlColumnNotesPath).readAsStringSync().replaceAll('\r\n', '\n'),
      renderSqlColumnNotes(readSqlColumnNotes(Directory(kSqlTablesPath))),
      reason: 'Run dart run tool/generate_sql_column_notes.dart',
    );
  });
}
