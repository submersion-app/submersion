import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v159 adds `dive_data_sources.time_offset_seconds`: the number of seconds
/// consolidation shifted this source's own timeline by to land it on the
/// target dive's clock (issue #1177). Nullable, because null and 0 both mean
/// "this source is already on the dive's time base", and a nullable column
/// survives a payload from a pre-v159 writer that omits the key entirely.
void main() {
  test('v159 is in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(159));
    expect(AppDatabase.migrationVersions, contains(159));
  });

  test('a fresh database has dive_data_sources.time_offset_seconds', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('dive_data_sources')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('time_offset_seconds'));
  });

  test('the column is nullable and carries no default', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('dive_data_sources')")
        .get();
    final column = cols.firstWhere(
      (c) => c.read<String>('name') == 'time_offset_seconds',
    );
    // A NOT NULL column would reject inserts from every existing writer that
    // does not know about it, and a non-null default would claim an offset
    // was measured where none was.
    expect(column.read<int>('notnull'), 0);
    expect(column.read<String?>('dflt_value'), isNull);
  });

  test(
    'a database stranded before v159 gains the column via beforeOpen',
    () async {
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('''
          CREATE TABLE dive_data_sources (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            computer_id TEXT,
            is_primary INTEGER NOT NULL DEFAULT 0,
            imported_at INTEGER NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        },
      );
      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('dive_data_sources')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toSet();
      expect(names, contains('time_offset_seconds'));
    },
  );

  test('existing rows read back as null, not as a bogus offset', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('''
          CREATE TABLE dive_data_sources (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            computer_id TEXT,
            is_primary INTEGER NOT NULL DEFAULT 0,
            imported_at INTEGER NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        rawDb.execute(
          "INSERT INTO dive_data_sources "
          "(id, dive_id, is_primary, imported_at, created_at) "
          "VALUES ('src-1', 'dive-1', 0, 0, 0)",
        );
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    final row = await db
        .customSelect(
          "SELECT time_offset_seconds FROM dive_data_sources WHERE id = 'src-1'",
        )
        .getSingle();
    expect(row.read<int?>('time_offset_seconds'), isNull);
  });

  test('the assert is a no-op when the table is absent', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('CREATE TABLE unrelated (id TEXT)');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    await db.customSelect('SELECT 1').get();
  });
}
