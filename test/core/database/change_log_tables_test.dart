import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

import '../../helpers/test_database.dart';

const _logTables = [
  'change_log_context',
  'change_log_events',
  'change_log_fields',
  'change_log_operations',
];

const _logIndexes = [
  'idx_change_log_events_settled',
  'idx_change_log_events_operation',
  'idx_change_log_events_record',
  'idx_change_log_operations_feed',
  'idx_change_log_operations_root',
];

Future<Set<String>> _schemaNames(AppDatabase db) async {
  final rows = await db.customSelect('SELECT name FROM sqlite_master').get();
  return {for (final r in rows) r.read<String>('name')};
}

Future<int> _contextRows(AppDatabase db) async {
  final row = await db
      .customSelect('SELECT COUNT(*) AS c FROM change_log_context')
      .getSingle();
  return row.read<int>('c');
}

/// A database file without the log tables, stamped at [userVersion] and
/// closed, ready to reopen.
Future<File> _databaseWithoutLogTables(int userVersion) async {
  final dir = Directory.systemTemp.createTempSync('change_log_tables');
  addTearDown(() => dir.deleteSync(recursive: true));
  final file = File(p.join(dir.path, 'submersion.db'));

  final before = AppDatabase(
    NativeDatabase(file, setup: registerAppSqlFunctions),
  );
  addTearDown(before.close);
  await before.customSelect('SELECT 1').get();
  for (final table in _logTables) {
    await before.customStatement('DROP TABLE IF EXISTS $table');
  }
  await before.customStatement('PRAGMA user_version = $userVersion');
  await before.close();
  return file;
}

void main() {
  group('change_log_fields', () {
    late AppDatabase db;

    setUp(() => db = createTestDatabase());
    tearDown(() => db.close());

    test('keep every SQLite type', () async {
      final bytes = Uint8List.fromList([0, 1, 2, 255]);
      final values = <String, Object?>{
        'text': '028',
        'int': 28,
        'real': 1.5,
        'null': null,
        'blob': bytes,
      };

      for (final entry in values.entries) {
        await db.customStatement(
          'INSERT INTO change_log_fields '
          '(event_id, column_name, old_value, new_value) VALUES (1, ?, ?, ?)',
          [entry.key, entry.value, entry.value],
        );
      }

      Future<Object?> read(String column) async {
        final row = await db
            .customSelect(
              'SELECT old_value, new_value, typeof(old_value) AS t '
              'FROM change_log_fields WHERE column_name = ?',
              variables: [Variable.withString(column)],
            )
            .getSingle();
        expect(row.data['old_value'], row.data['new_value']);
        return row.data['old_value'];
      }

      expect(
        await read('text'),
        isA<String>().having((v) => v, 'value', '028'),
      );
      expect(await read('int'), isA<int>().having((v) => v, 'value', 28));
      expect(await read('real'), isA<double>().having((v) => v, 'value', 1.5));
      expect(await read('null'), isNull);
      expect(await read('blob'), bytes);
    });
  });

  test('a fresh database has one context row', () async {
    final db = createTestDatabase();
    addTearDown(db.close);

    expect(await _contextRows(db), 1);
    final row = await db
        .customSelect('SELECT * FROM change_log_context')
        .getSingle();
    expect(row.data['id'], 1);
    expect(row.data['operation_id'], isNull);
    expect(row.data['suppressed_until'], isNull);
    expect(row.data['trigger_hash'], isNull);
  });

  test('a v327 database upgrades to the new tables', () async {
    expect(AppDatabase.migrationVersions, contains(328));
    expect(
      AppDatabase.migrationStepCount(327),
      AppDatabase.migrationStepCount(328) + 1,
    );
    final file = await _databaseWithoutLogTables(327);

    final after = AppDatabase(
      NativeDatabase(file, setup: registerAppSqlFunctions),
    );
    addTearDown(after.close);

    expect(await _schemaNames(after), containsAll(_logTables));
    expect(await _contextRows(after), 1);
  });

  test('a restored database missing the tables gets them on open', () async {
    final file = await _databaseWithoutLogTables(
      AppDatabase.currentSchemaVersion,
    );

    final after = AppDatabase(
      NativeDatabase(file, setup: registerAppSqlFunctions),
    );
    addTearDown(after.close);

    final names = await _schemaNames(after);
    expect(names, containsAll(_logTables));
    expect(names, containsAll(_logIndexes));
    expect(await _contextRows(after), 1);
  });

  test('the log tables stay out of sync', () async {
    final db = createTestDatabase();
    addTearDown(db.close);

    final logTables = db.allTables.where(
      (t) => _logTables.contains(t.actualTableName),
    );
    expect(logTables, hasLength(_logTables.length));
    for (final table in logTables) {
      expect(
        table.$columns.map((c) => c.name),
        isNot(contains('hlc')),
        reason: table.actualTableName,
      );
    }
  });
}
