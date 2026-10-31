import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/change_log/change_log_policy.dart';
import 'package:submersion/core/database/database.dart';

import '../../../helpers/test_database.dart';
import 'change_log_support.dart';

Object _firstValue(GeneratedColumn<Object> column) => switch (column.type) {
  DriftSqlType.bool => 1,
  DriftSqlType.int || DriftSqlType.bigInt || DriftSqlType.dateTime => 1,
  DriftSqlType.double => 1.5,
  DriftSqlType.blob => Uint8List.fromList([1, 2]),
  _ => 'first',
};

Object _secondValue(GeneratedColumn<Object> column) => switch (column.type) {
  DriftSqlType.bool => 0,
  DriftSqlType.int || DriftSqlType.bigInt || DriftSqlType.dateTime => 2,
  DriftSqlType.double => 2.5,
  DriftSqlType.blob => Uint8List.fromList([3, 4]),
  _ => 'second',
};

/// Writes to every logged table with its triggers installed. A trigger that
/// compiles but fails when it fires would fail a diver's save, so this is
/// what protects saves, and it needs no list of tables to keep up to date.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement('PRAGMA ignore_check_constraints = ON');
  });
  tearDown(() => db.close());

  test('every logged table has tests here', () {
    final logged = changeLogTables.entries
        .where((e) => e.value != ChangeLogClass.excluded)
        .map((e) => e.key)
        .toSet();
    expect(
      db.allTables.map((t) => t.actualTableName).toSet(),
      containsAll(logged),
    );
  });

  for (final tableName in changeLogTables.keys) {
    if (changeLogTables[tableName] == ChangeLogClass.excluded) continue;

    test('$tableName writes through its triggers', () async {
      final table = db.allTables.singleWhere(
        (t) => t.actualTableName == tableName,
      );
      final columns = table.$columns.cast<GeneratedColumn<Object>>();
      final tracked = changeLogTables[tableName] == ChangeLogClass.tracked;
      final ignored = changeLogIgnoredColumns(tableName);
      final keys = {for (final c in table.$primaryKey) c.name};

      final row = {for (final c in columns) c.name: _firstValue(c)};
      if (row.containsKey('key') && keys.contains('key')) {
        row['key'] = 'share_new_records_by_default';
      }
      await db.customStatement(
        'INSERT INTO "$tableName" (${row.keys.map((c) => '"$c"').join(', ')}) '
        'VALUES (${row.keys.map((_) => '?').join(', ')})',
        row.values.toList(),
      );

      // Some tables are seeded, so every write names this row.
      final where = keys.map((c) => '"$c" = ?').join(' AND ');
      final keyValues = [for (final c in keys) row[c]];

      for (final column in columns) {
        if (keys.contains(column.name)) continue;
        await clearLog(db);
        await db.customStatement(
          'UPDATE "$tableName" SET "${column.name}" = ? WHERE $where',
          [_secondValue(column), ...keyValues],
        );
        final events = await logEvents(db);
        if (tracked && !ignored.contains(column.name)) {
          expect(events, hasLength(1), reason: column.name);
          final fields = await logFields(db, events.single['id']! as int);
          expect(fields.keys, [column.name]);
          expect(fields[column.name]!.$1, row[column.name]);
          expect(fields[column.name]!.$2, _secondValue(column));
        } else {
          expect(events, isEmpty, reason: column.name);
        }
      }

      await clearLog(db);
      await db.customStatement(
        'DELETE FROM "$tableName" WHERE $where',
        keyValues,
      );
      final events = await logEvents(db);
      expect(events, hasLength(1));
      expect(events.single['action'], 'D');
      expect(await logFields(db, events.single['id']! as int), isNotEmpty);
    });
  }
}
