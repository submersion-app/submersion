import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('v74 adds GPS columns to dive_data_sources', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('dive_data_sources')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();

    expect(
      names,
      containsAll(<String>[
        'entry_latitude',
        'entry_longitude',
        'exit_latitude',
        'exit_longitude',
      ]),
    );
  });

  test('v73 -> v74 upgrade adds GPS columns to dive_data_sources', () async {
    // Minimal pre-v74 dive_data_sources table at user_version = 73 (no GPS
    // columns) so the v74 PRAGMA-guarded ALTER TABLE path runs.
    final native = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 73');
        rawDb.execute('''
          CREATE TABLE dive_data_sources (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            is_primary INTEGER NOT NULL DEFAULT 0,
            imported_at INTEGER NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
      },
    );
    final db = AppDatabase(native);
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('dive_data_sources')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(
      names,
      containsAll(<String>[
        'entry_latitude',
        'entry_longitude',
        'exit_latitude',
        'exit_longitude',
      ]),
    );
  });
}
